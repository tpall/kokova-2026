"""Route weather outlook: any GPX/KMZ + rider (+ ferries) -> markdown/JSON.

This is the app's daily product: given a track, a start time and a calibrated
rider, sample the ensemble x rider uncertainty and report the weather the
rider will actually meet — a timeline of conditions at the (position, time)
distribution, cumulative exposure (kit numbers), ferry-catch odds and the
finish spread. Nothing here is route-specific.

Long-range note: only ECMWF's ensemble reaches 15 days; ICON stops at ~7.5 and
its members would be NaN beyond that, so the default model set is ECMWF-only.
If the start (or the finish tail) lies beyond the forecast horizon the report
says so loudly instead of failing — cron-safe before the window opens.
"""

import argparse
import json
from datetime import datetime, timezone
from zoneinfo import ZoneInfo

import numpy as np

from routewx_multiday import (Rider, build_route, exposure, fetch_weather_cube,
                              load_cube, load_ferries, load_gpx, sample_riders,
                              save_cube, simulate, ferry_report)


def load_track_any(path: str):
    """GPX via load_gpx; KMZ/KML via the kmz2gpx reader, concatenated."""
    if path.lower().endswith((".kmz", ".kml")):
        from kmz2gpx import linestrings, read_kml
        pts = [p for _, seg in linestrings(read_kml(path)) for p in seg]
        lat = np.array([p[0] for p in pts])
        lon = np.array([p[1] for p in pts])
        ele = np.array([p[2] if p[2] is not None else np.nan for p in pts])
        if np.isnan(ele).all():
            ele = np.zeros_like(lat)
        else:
            i = np.arange(len(ele))
            good = ~np.isnan(ele)
            ele = np.interp(i, i[good], ele[good])
        return lat, lon, ele
    return load_gpx(path)


def q(a, qs=(0.1, 0.5, 0.9)):
    return [float(np.quantile(a, x)) for x in qs]


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("track", help="route GPX, KMZ or KML")
    ap.add_argument("--start", required=True, help="ISO8601 UTC, e.g. 2026-08-14T18:00")
    ap.add_argument("--rider", help="rider JSON (calibrate_tbr.py output)")
    ap.add_argument("--ferries", help="ferries JSON (legs + sailings)")
    ap.add_argument("--riders", type=int, default=12)
    ap.add_argument("--days", type=int, default=15)
    ap.add_argument("--spacing-km", type=float, default=25.0)
    ap.add_argument("--models", default="ecmwf_ifs025_ensemble",
                    help="comma-separated ensemble models (equal horizons!)")
    ap.add_argument("--tz", default="Europe/Tallinn", help="display timezone")
    ap.add_argument("--label", default="Route weather outlook")
    ap.add_argument("--cache", help="npz cube cache")
    ap.add_argument("--out-md")
    ap.add_argument("--out-json")
    ap.add_argument("--seed", type=int, default=0)
    a = ap.parse_args()

    tz = ZoneInfo(a.tz)
    loc = lambda epoch: datetime.fromtimestamp(epoch, tz)

    lat, lon, ele = load_track_any(a.track)
    route = build_route(lat, lon, ele)

    import os
    if a.cache and os.path.exists(a.cache):
        cube = load_cube(a.cache)
    else:
        cube = fetch_weather_cube(route, spacing_km=a.spacing_km,
                                  forecast_days=a.days,
                                  models=a.models.split(","))
        if a.cache:
            save_cube(cube, a.cache)

    rider_kw = {}
    if a.rider:
        with open(a.rider) as fh:
            rider_kw = {k: v for k, v in json.load(fh).items()
                        if not k.startswith("_")}
    rider = Rider(**rider_kw)
    ferries = load_ferries(a.ferries, route) if a.ferries else []

    start = (datetime.fromisoformat(a.start).replace(tzinfo=timezone.utc)
             .timestamp())
    horizon = cube.t0 + (cube.n_t - 1) * cube.dt

    rng = np.random.default_rng(a.seed)
    draws = sample_riders(rider, a.riders, rng)
    trajs = [simulate(route, cube, r, start, ferries) for r in draws]

    exs = [exposure(t) for t in trajs]
    pooled = {k: np.concatenate([e[k] for e in exs]) for k in exs[0]}
    finish = np.concatenate([t.finish_t for t in trajs])

    # Horizon honesty: how much of the ride the forecast actually covers.
    beyond_start = start > horizon
    cover_frac = float(np.mean(finish <= horizon))
    warn = []
    if beyond_start:
        warn.append(f"START IS {int((start - horizon) / 3600)} h BEYOND the "
                    f"forecast horizon — weather below is a horizon-edge "
                    f"placeholder, NOT a forecast.")
    elif cover_frac < 1.0:
        warn.append(f"Forecast horizon covers the full ride in only "
                    f"{cover_frac:.0%} of realisations; later hours are "
                    f"clamped to the horizon edge.")

    # Timeline: pool (segment arrival, conditions) over all realisations into
    # 6-h blocks of race time — the app's core table: conditions where the
    # rider actually is, with position uncertainty folded in.
    A = {k: np.concatenate([getattr(t, k) for t in trajs], axis=1)
         for k in ("arrive_t", "temp", "precip", "headwind", "apparent")}
    seg_km = np.tile(route.seg_mid_s[:, None] / 1000.0, (1, A["arrive_t"].shape[1]))
    t_end = float(np.quantile(finish, 0.9))
    blocks = []
    for b0 in np.arange(start, min(t_end, start + 7 * 86400), 6 * 3600.0):
        m = (A["arrive_t"] >= b0) & (A["arrive_t"] < b0 + 6 * 3600.0)
        if m.sum() < 50:
            continue
        blocks.append({
            "from_local": loc(b0).strftime("%a %H:%M"),
            "km": q(seg_km[m]),
            "temp_c": q(A["temp"][m]),
            "apparent_q10_c": float(np.quantile(A["apparent"][m], 0.1)),
            "rain_share": float((A["precip"][m] > 0.2).mean()),
            "headwind_ms": q(A["headwind"][m]),
            "beyond_horizon": bool(b0 > horizon),
        })

    rep = {
        "generated_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "label": a.label,
        "track": a.track,
        "route_km": round(route.total_km, 1),
        "ascent_m": round(route.total_ascent_m),
        "start_local": loc(start).isoformat(),
        "members": cube.n_members,
        "rider_draws": a.riders,
        "warnings": warn,
        "rider": {k: rider_kw.get(k) for k in
                  ("power_w", "crr", "daily_ride_h", "sleep_h",
                   "stop_min_per_100km", "stop_min_per_100km_fresh")},
        "finish_h": q((finish - start) / 3600.0),
        "finish_local_q50": loc(float(np.quantile(finish, 0.5))).isoformat(),
        "exposure": {k: q(v) for k, v in pooled.items()},
        "ferries": ferry_report(ferries, trajs) if ferries else [],
        "timeline_6h": blocks,
    }

    if a.out_json:
        with open(a.out_json, "w") as f:
            json.dump(rep, f, indent=1, ensure_ascii=False)

    md = [f"# {a.label}",
          "",
          f"Generated {rep['generated_utc']} · route {rep['route_km']} km / "
          f"{rep['ascent_m']} m · start {loc(start):%a %d %b %H:%M %Z} · "
          f"{cube.n_members} weather members × {a.riders} rider draws",
          ""]
    for w in warn:
        md += [f"> **⚠ {w}**", ""]
    f10, f50, f90 = rep["finish_h"]
    md += [f"**Finish:** q10 {f10:.0f} h / q50 {f50:.0f} h / q90 {f90:.0f} h "
           f"→ median {loc(float(np.quantile(finish, .5))):%a %H:%M}", ""]
    if ferries:
        md += ["## Ferries", ""]
        for row in rep["ferries"]:
            md += [f"**{row['ferry']}** — arrive q50 "
                   f"{row['arrive_q50'][11:16]} ({row['arrive_q50'][:10]}), "
                   f"wait q50 {row['wait_h_q50']:.1f} h", ""]
            for c in row["catches"]:
                md.append(f"- {c['share']:.0%} board {c['depart'][:16].replace('T', ' ')}")
            md.append("")
    md += ["## Exposure (pooled, q10/q50/q90)", ""]
    for k in ("moving_h", "sleep_h", "ferry_wait_h", "rain_h", "rain_mm",
              "cold_wet_h", "night_h", "night_rain_h", "min_apparent_c",
              "mean_headwind_ms", "max_gust_ms"):
        v = rep["exposure"][k]
        md.append(f"- {k}: {v[0]:.1f} / {v[1]:.1f} / {v[2]:.1f}")
    md += ["", "## Timeline (6-h blocks, conditions at the rider's likely position)", "",
           "| from | km q10/50/90 | temp °C q10/50/90 | feels ≥ | rain | headwind m/s |",
           "|---|---|---|---|---|---|"]
    for b in blocks:
        flag = " ⚠" if b["beyond_horizon"] else ""
        md.append(f"| {b['from_local']}{flag} "
                  f"| {b['km'][0]:.0f}/{b['km'][1]:.0f}/{b['km'][2]:.0f} "
                  f"| {b['temp_c'][0]:.0f}/{b['temp_c'][1]:.0f}/{b['temp_c'][2]:.0f} "
                  f"| {b['apparent_q10_c']:.0f} °C "
                  f"| {b['rain_share']:.0%} "
                  f"| {b['headwind_ms'][0]:+.1f}/{b['headwind_ms'][1]:+.1f}/{b['headwind_ms'][2]:+.1f} |")
    md += ["", "*feels ≥ = q10 cyclist-relative apparent temperature (bike speed + "
           "wind airflow); rain = share of realisations in >0.2 mm/h at that hour; "
           "⚠ = block beyond forecast horizon.*", ""]

    text = "\n".join(md)
    if a.out_md:
        with open(a.out_md, "w") as f:
            f.write(text)
    print(text)


if __name__ == "__main__":
    main()
