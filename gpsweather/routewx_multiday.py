"""
routewx_multiday
================
Multi-day bikepacking pacing + probabilistic route weather exposure.

Design notes
------------
* Pace and weather are *causally* coupled: we integrate forward along the route,
  querying wind at the position/time the rider is actually at. Headwind slows the
  rider, which shifts every downstream arrival. No fixed-point iteration needed.

* Two independent uncertainty sources are sampled:
    - weather:  ensemble members from Open-Meteo /v1/ensemble
    - rider:    Monte Carlo over power, daily hours, sleep, stop overhead
  A "realisation" is one (rider draw, ensemble member) pair.

* Apparent temperature is computed from *relative* airflow (bike speed + wind
  component), not 10 m wind. This is the whole point for cold/wet night riding.

* The weather cube is fetched once onto a (waypoint x hour x member) grid.
  Simulation is then pure interpolation, so scanning many start times is cheap.

Dependencies: numpy, requests. (pandas optional, only for tidy output.)

Author's note: everything marked HEURISTIC is a modelling choice you should
calibrate against your own ride files, not a physical law.
"""

from __future__ import annotations

import math
import time as _time
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field, replace
from datetime import datetime, timezone, timedelta
from typing import Iterable, Sequence

import numpy as np
import requests

# --------------------------------------------------------------------------
# Constants
# --------------------------------------------------------------------------

G = 9.80665
ENSEMBLE_URL = "https://ensemble-api.open-meteo.com/v1/ensemble"

# Variables we pull. Note we do NOT ask for apparent_temperature: we compute a
# cyclist-specific one ourselves from relative airflow.
HOURLY_VARS = [
    "temperature_2m",
    "relative_humidity_2m",
    "precipitation",
    "wind_speed_10m",
    "wind_direction_10m",
    "wind_gusts_10m",
    "cloud_cover",
]

DEFAULT_MODELS = ["ecmwf_ifs025_ensemble", "icon_seamless_eps"]


# --------------------------------------------------------------------------
# Geometry
# --------------------------------------------------------------------------

def _haversine(lat1, lon1, lat2, lon2):
    """Great-circle distance in metres. Vectorised."""
    R = 6371008.8
    p1, p2 = np.radians(lat1), np.radians(lat2)
    dp = p2 - p1
    dl = np.radians(lon2 - lon1)
    a = np.sin(dp / 2) ** 2 + np.cos(p1) * np.cos(p2) * np.sin(dl / 2) ** 2
    return 2 * R * np.arcsin(np.sqrt(np.clip(a, 0, 1)))


def _bearing(lat1, lon1, lat2, lon2):
    """Initial bearing in degrees (0 = north, clockwise). Vectorised."""
    p1, p2 = np.radians(lat1), np.radians(lat2)
    dl = np.radians(lon2 - lon1)
    y = np.sin(dl) * np.cos(p2)
    x = np.cos(p1) * np.sin(p2) - np.sin(p1) * np.cos(p2) * np.cos(dl)
    return np.degrees(np.arctan2(y, x)) % 360.0


@dataclass
class Route:
    """A route resampled to uniform segment length."""
    lat: np.ndarray          # (n+1,) node latitudes
    lon: np.ndarray          # (n+1,)
    ele: np.ndarray          # (n+1,) metres
    s: np.ndarray            # (n+1,) cumulative distance, metres
    seg_len: np.ndarray      # (n,)
    seg_grade: np.ndarray    # (n,) rise/run
    seg_bearing: np.ndarray  # (n,) degrees
    seg_mid_s: np.ndarray    # (n,) mid-segment distance, metres
    seg_lat: np.ndarray      # (n,) mid-segment lat
    seg_lon: np.ndarray      # (n,)

    @property
    def total_km(self) -> float:
        return float(self.s[-1]) / 1000.0

    @property
    def total_ascent_m(self) -> float:
        d = np.diff(self.ele)
        return float(d[d > 0].sum())


def load_gpx(path: str) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Minimal GPX reader -> (lat, lon, ele). Handles trkpt and rtept."""
    tree = ET.parse(path)
    root = tree.getroot()
    ns = {"g": root.tag.split("}")[0].strip("{")} if "}" in root.tag else {}
    tag = lambda t: f"g:{t}" if ns else t

    pts = root.findall(f".//{tag('trkpt')}", ns) or root.findall(f".//{tag('rtept')}", ns)
    if not pts:
        raise ValueError(f"No trkpt/rtept found in {path}")

    lat, lon, ele = [], [], []
    for p in pts:
        lat.append(float(p.get("lat")))
        lon.append(float(p.get("lon")))
        e = p.find(tag("ele"), ns)
        ele.append(float(e.text) if e is not None and e.text else np.nan)

    lat, lon, ele = np.array(lat), np.array(lon), np.array(ele)
    if np.isnan(ele).all():
        ele = np.zeros_like(lat)
        # Consider filling from Open-Meteo /v1/elevation if your GPX lacks ele.
    else:
        idx = np.arange(len(ele))
        good = ~np.isnan(ele)
        ele = np.interp(idx, idx[good], ele[good])
    return lat, lon, ele


def build_route(lat, lon, ele, seg_len_m: float = 1000.0,
                smooth_ele_m: float = 250.0) -> Route:
    """Resample to uniform segments and smooth elevation before differencing.

    Elevation smoothing matters a lot: raw GPX elevation noise inflates gradient
    variance and makes the power model produce nonsense speeds.
    """
    d = _haversine(lat[:-1], lon[:-1], lat[1:], lon[1:])
    s_raw = np.concatenate([[0.0], np.cumsum(d)])
    total = s_raw[-1]

    n = max(int(total // seg_len_m), 1)
    s_new = np.linspace(0.0, total, n + 1)

    lat_n = np.interp(s_new, s_raw, lat)
    lon_n = np.interp(s_new, s_raw, lon)
    ele_n = np.interp(s_new, s_raw, ele)

    # Moving-average smooth on elevation
    w = max(int(round(smooth_ele_m / seg_len_m)), 1)
    if w > 1:
        k = np.ones(w) / w
        ele_n = np.convolve(np.pad(ele_n, (w // 2, w // 2), mode="edge"), k, mode="same")
        ele_n = ele_n[w // 2: w // 2 + n + 1]

    seg_l = np.diff(s_new)
    seg_g = np.diff(ele_n) / np.maximum(seg_l, 1.0)
    seg_g = np.clip(seg_g, -0.25, 0.25)
    seg_b = _bearing(lat_n[:-1], lon_n[:-1], lat_n[1:], lon_n[1:])

    return Route(
        lat=lat_n, lon=lon_n, ele=ele_n, s=s_new,
        seg_len=seg_l, seg_grade=seg_g, seg_bearing=seg_b,
        seg_mid_s=0.5 * (s_new[:-1] + s_new[1:]),
        seg_lat=0.5 * (lat_n[:-1] + lat_n[1:]),
        seg_lon=0.5 * (lon_n[:-1] + lon_n[1:]),
    )


# --------------------------------------------------------------------------
# Weather cube
# --------------------------------------------------------------------------

@dataclass
class WeatherCube:
    """Ensemble forecast on a (waypoint x hour x member) grid."""
    wp_s: np.ndarray                  # (W,) route distance of each waypoint, metres
    t0: float                         # epoch seconds of first hour
    dt: float                         # seconds between steps (3600)
    n_t: int
    data: dict[str, np.ndarray]       # var -> (W, T, M)
    members: list[str]

    @property
    def n_members(self) -> int:
        return len(self.members)

    def sample(self, var: str, s_m: float, t_epoch: np.ndarray) -> np.ndarray:
        """Bilinear interpolation in (route distance, time) for each member.

        s_m      : scalar route distance
        t_epoch  : (M,) per-member clock, since members diverge in position/time
        returns  : (M,)
        """
        D = self.data[var]                       # (W, T, M)
        W, T, M = D.shape

        fs = np.interp(s_m, self.wp_s, np.arange(W))
        i0 = int(np.clip(np.floor(fs), 0, W - 1))
        i1 = min(i0 + 1, W - 1)
        a = float(fs - i0)

        ft = (np.asarray(t_epoch, dtype=float) - self.t0) / self.dt
        ft = np.clip(ft, 0, T - 1)
        j0 = np.floor(ft).astype(int)
        j1 = np.minimum(j0 + 1, T - 1)
        b = ft - j0

        k = np.arange(M)
        v00 = D[i0, j0, k]
        v01 = D[i0, j1, k]
        v10 = D[i1, j0, k]
        v11 = D[i1, j1, k]
        return ((1 - a) * ((1 - b) * v00 + b * v01)
                + a * ((1 - b) * v10 + b * v11))


def _repair_cube_data(data: dict[str, np.ndarray],
                      members: list[str]) -> list[str]:
    """Linear-fill NaNs along the time axis per (waypoint, member) series.

    Ensemble hourly output can contain nulls — coarser native model steps or a
    partially ingested run — and a single NaN cascades through the speed
    solver into nonsense (the bisection runs away to v_max). Repair by
    interpolation inside each series; drop members that remain NaN. Call
    AFTER wind is converted to u/v: components are linear, directions wrap.
    Mutates data in place, returns the surviving member list.
    """
    for arr in data.values():
        W, T, M = arr.shape
        if not np.isnan(arr).any():
            continue
        idx = np.arange(T)
        for w in range(W):
            for m in range(M):
                col = arr[w, :, m]
                bad = np.isnan(col)
                if bad.any() and (~bad).any():
                    col[bad] = np.interp(idx[bad], idx[~bad], col[~bad])
    dead = np.zeros(len(members), dtype=bool)
    for arr in data.values():
        dead |= np.isnan(arr).any(axis=(0, 1))
    if dead.any():
        keep = ~dead
        for v in data:
            data[v] = data[v][:, :, keep]
        members = [m for m, k in zip(members, keep) if k]
    return members


def _get_with_retry(sess: requests.Session, url: str, params: dict,
                    tries: int = 6, timeout: int = 60) -> requests.Response:
    """GET with backoff on 429/5xx. Open-Meteo's free tier rate-limits per
    minute, and an ensemble call counts as ~4 normal calls, so a route fetch
    can trip the limiter mid-way; honouring Retry-After and waiting is enough."""
    r = None
    for attempt in range(tries):
        r = sess.get(url, params=params, timeout=timeout)
        if r.status_code in (429, 500, 502, 503, 504) and attempt < tries - 1:
            wait = float(r.headers.get("Retry-After") or min(15 * 2 ** attempt, 120))
            _time.sleep(wait)
            continue
        break
    r.raise_for_status()
    return r


def save_cube(cube: WeatherCube, path: str) -> None:
    np.savez_compressed(path, wp_s=cube.wp_s, t0=cube.t0, dt=cube.dt,
                        n_t=cube.n_t, members=np.array(cube.members),
                        **{f"var_{k}": v for k, v in cube.data.items()})


def load_cube(path: str) -> WeatherCube:
    z = np.load(path)
    data = {k[4:]: z[k] for k in z.files if k.startswith("var_")}
    return WeatherCube(wp_s=z["wp_s"], t0=float(z["t0"]), dt=float(z["dt"]),
                       n_t=int(z["n_t"]), data=data,
                       members=[str(m) for m in z["members"]])


def _parse_members(block: dict, var: str) -> tuple[list[str], np.ndarray]:
    """Open-Meteo returns member-first keys like 'temperature_2m_member01'.
    With multiple models the suffix also carries the model name. Treat any key
    starting with the variable name as a member column."""
    keys = sorted(k for k in block if k.startswith(var))
    if not keys:
        raise KeyError(f"variable {var!r} missing from response")
    arr = np.array([np.asarray(block[k], dtype=float) for k in keys])  # (M, T)
    names = [k[len(var):].lstrip("_") or "member00" for k in keys]
    return names, arr.T                                                # (T, M)


def fetch_weather_cube(route: Route,
                       spacing_km: float = 25.0,
                       forecast_days: int = 10,
                       models: Sequence[str] = DEFAULT_MODELS,
                       chunk: int = 8,
                       session: requests.Session | None = None) -> WeatherCube:
    """Fetch the ensemble onto route waypoints.

    Cost note: Open-Meteo counts an ensemble call as ~4 normal calls, and the
    free tier is rate-limited. A 600 km route at 25 km spacing is 25 waypoints,
    which is fine; do NOT drop spacing to 5 km without caching to disk.
    """
    sess = session or requests.Session()

    step_m = spacing_km * 1000.0
    wp_s = np.arange(0.0, route.s[-1] + step_m, step_m)
    wp_s = np.clip(wp_s, 0, route.s[-1])
    wp_lat = np.interp(wp_s, route.s, route.lat)
    wp_lon = np.interp(wp_s, route.s, route.lon)

    per_var: dict[str, list[np.ndarray]] = {v: [] for v in HOURLY_VARS}
    members: list[str] | None = None
    times: np.ndarray | None = None

    for i in range(0, len(wp_s), chunk):
        la = wp_lat[i:i + chunk]
        lo = wp_lon[i:i + chunk]
        params = {
            "latitude": ",".join(f"{x:.4f}" for x in la),
            "longitude": ",".join(f"{x:.4f}" for x in lo),
            "hourly": ",".join(HOURLY_VARS),
            "models": ",".join(models),
            "forecast_days": forecast_days,
            "timeformat": "unixtime",
            "cell_selection": "nearest",
        }
        r = _get_with_retry(sess, ENSEMBLE_URL, params)
        payload = r.json()
        blocks = payload if isinstance(payload, list) else [payload]

        for blk in blocks:
            h = blk["hourly"]
            t = np.asarray(h["time"], dtype=float)
            if times is None:
                times = t
            for v in HOURLY_VARS:
                names, arr = _parse_members(h, v)
                if members is None:
                    members = names
                per_var[v].append(arr)

    assert times is not None and members is not None
    data = {v: np.stack(per_var[v], axis=0) for v in HOURLY_VARS}   # (W, T, M)

    # Convert wind speed/direction to u/v so interpolation is not circular.
    ws = data.pop("wind_speed_10m") / 3.6            # km/h -> m/s
    wd = np.radians(data.pop("wind_direction_10m"))
    data["wind_u"] = -ws * np.sin(wd)                # eastward component
    data["wind_v"] = -ws * np.cos(wd)                # northward component
    data["wind_gusts_10m"] = data["wind_gusts_10m"] / 3.6

    members = _repair_cube_data(data, members)

    dt = float(times[1] - times[0]) if len(times) > 1 else 3600.0
    return WeatherCube(wp_s=wp_s, t0=float(times[0]), dt=dt,
                       n_t=len(times), data=data, members=members)


ARCHIVE_URL = "https://archive-api.open-meteo.com/v1/archive"


def fetch_archive_cube(route: Route, start_date: str, end_date: str,
                       spacing_km: float = 25.0, chunk: int = 8,
                       session: requests.Session | None = None) -> WeatherCube:
    """Historical weather (ERA5 reanalysis) along the route as a 1-member cube.

    For backtests and post-trip analysis: same cube shape as the ensemble
    fetch, so simulate()/exposure() work unchanged — there is just no spread.
    Dates are ISO yyyy-mm-dd, inclusive.
    """
    sess = session or requests.Session()

    step_m = spacing_km * 1000.0
    wp_s = np.arange(0.0, route.s[-1] + step_m, step_m)
    wp_s = np.clip(wp_s, 0, route.s[-1])
    wp_lat = np.interp(wp_s, route.s, route.lat)
    wp_lon = np.interp(wp_s, route.s, route.lon)

    per_var: dict[str, list[np.ndarray]] = {v: [] for v in HOURLY_VARS}
    times: np.ndarray | None = None

    for i in range(0, len(wp_s), chunk):
        params = {
            "latitude": ",".join(f"{x:.4f}" for x in wp_lat[i:i + chunk]),
            "longitude": ",".join(f"{x:.4f}" for x in wp_lon[i:i + chunk]),
            "hourly": ",".join(HOURLY_VARS),
            "start_date": start_date,
            "end_date": end_date,
            "timeformat": "unixtime",
            "cell_selection": "nearest",
        }
        r = _get_with_retry(sess, ARCHIVE_URL, params)
        payload = r.json()
        for blk in payload if isinstance(payload, list) else [payload]:
            h = blk["hourly"]
            if times is None:
                times = np.asarray(h["time"], dtype=float)
            for v in HOURLY_VARS:
                per_var[v].append(np.asarray(h[v], dtype=float)[:, None])  # (T, 1)

    assert times is not None
    data = {v: np.stack(per_var[v], axis=0) for v in HOURLY_VARS}          # (W, T, 1)
    ws = data.pop("wind_speed_10m") / 3.6
    wd = np.radians(data.pop("wind_direction_10m"))
    data["wind_u"] = -ws * np.sin(wd)
    data["wind_v"] = -ws * np.cos(wd)
    data["wind_gusts_10m"] = data["wind_gusts_10m"] / 3.6

    members = _repair_cube_data(data, ["era5"])

    dt = float(times[1] - times[0]) if len(times) > 1 else 3600.0
    return WeatherCube(wp_s=wp_s, t0=float(times[0]), dt=dt,
                       n_t=len(times), data=data, members=members)


# --------------------------------------------------------------------------
# Rider
# --------------------------------------------------------------------------

@dataclass
class Rider:
    """Mean rider parameters. Monte Carlo perturbs these."""
    power_w: float = 150.0             # sustainable power on the flat, all-day
    mass_kg: float = 95.0              # rider + bike + kit + water
    cda: float = 0.36                  # m^2, loaded bikepacking position
    crr: float = 0.008                 # gravel-ish
    drivetrain_eff: float = 0.97

    daily_ride_h: float = 14.0         # awake-and-moving budget before sleep
    sleep_h: float = 5.0
    stop_min_per_100km: float = 45.0   # steady-state resupply/faff overhead
    # Fresh riders stop far less than their multi-day average (measured: 35 vs
    # 140 min/100km for Taavi). The rate holds at _fresh for stop_ramp_delay_h
    # ride-hours, then rises linearly to steady over stop_ramp_h. None = flat.
    stop_min_per_100km_fresh: float | None = None
    stop_ramp_delay_h: float = 10.0
    stop_ramp_h: float = 12.0
    fatigue_per_100h: float = 0.80     # power multiplier after 100 h on bike

    night_power_factor: float = 0.92   # HEURISTIC
    night_descent_cap_ms: float = 8.0  # m/s, cautious descending in the dark
    day_descent_cap_ms: float = 15.0
    walk_speed_ms: float = 1.2         # hike-a-bike fallback

    wet_chill_c: float = 4.0           # HEURISTIC: extra cooling when wet


def sample_riders(base: Rider, n: int, rng: np.random.Generator) -> list[Rider]:
    """Draw plausible rider variations. Widths are deliberately generous:
    self-supported multi-day pace is far more uncertain than most tools admit."""
    out = []
    for _ in range(n):
        stop = float(np.clip(
            rng.lognormal(np.log(base.stop_min_per_100km), 0.30), 10, 240))
        # Keep the fresh/steady ratio: the draw shifts the rider's overall
        # stopping style, not the shape of the ramp.
        fresh = (base.stop_min_per_100km_fresh * stop / base.stop_min_per_100km
                 if base.stop_min_per_100km_fresh is not None else None)
        out.append(replace(
            base,
            power_w=float(base.power_w * rng.normal(1.0, 0.10)),
            daily_ride_h=float(np.clip(rng.normal(base.daily_ride_h, 1.5), 6, 22)),
            sleep_h=float(np.clip(rng.normal(base.sleep_h, 1.0), 1.5, 9)),
            stop_min_per_100km=stop,
            stop_min_per_100km_fresh=fresh,
            cda=float(base.cda * rng.normal(1.0, 0.05)),
            crr=float(base.crr * rng.normal(1.0, 0.15)),
        ))
    return out


# --------------------------------------------------------------------------
# Ferries
# --------------------------------------------------------------------------

@dataclass
class Ferry:
    """A timetabled crossing. The route GPX must draw the water leg (straight
    bridge or traced path); segments with mid-distance inside [s_dep, s_arr]
    are treated as on-board, not ridden."""
    name: str
    s_dep: float               # route metres of departure terminal
    s_arr: float
    crossing_s: float
    departures: np.ndarray     # sorted epoch seconds
    tz: timezone | None = None # display timezone (from the timetable source)
    snap_off_m: tuple[float, float] | None = None  # terminal->route offsets

    @property
    def speed_ms(self) -> float:
        return max(self.s_arr - self.s_dep, 1.0) / self.crossing_s


def snap_to_route(route: Route, lat: float, lon: float) -> tuple[float, float]:
    """Nearest point on the route polyline -> (route distance m, offset m).

    Nearest node first, then projection onto the two adjacent segments in a
    local equirectangular frame — fine at harbour scale; don't use it to snap
    something hundreds of km off-route.
    """
    d = _haversine(route.lat, route.lon, lat, lon)
    i = int(np.argmin(d))
    best_s, best_off = float(route.s[i]), float(d[i])

    R = 6371008.8
    coslat = math.cos(math.radians(lat))
    px, py = math.radians(lon) * coslat * R, math.radians(lat) * R
    for j in (i - 1, i):
        if j < 0 or j + 1 >= len(route.lat):
            continue
        ax, ay = math.radians(route.lon[j]) * coslat * R, math.radians(route.lat[j]) * R
        bx, by = math.radians(route.lon[j + 1]) * coslat * R, math.radians(route.lat[j + 1]) * R
        vx, vy = bx - ax, by - ay
        L2 = vx * vx + vy * vy
        if L2 == 0:
            continue
        u = min(max(((px - ax) * vx + (py - ay) * vy) / L2, 0.0), 1.0)
        off = math.hypot(px - (ax + u * vx), py - (ay + u * vy))
        if off < best_off:
            best_off = off
            best_s = float(route.s[j] + u * (route.s[j + 1] - route.s[j]))
    return best_s, best_off


def load_ferries(path: str, route: Route | None = None,
                 max_snap_km: float = 5.0) -> list[Ferry]:
    """Read a ferries JSON:

        {"ferries":  [{"leg", "latlon_from": [lat, lon], "latlon_to": [lat, lon],
                       "km_from", "km_to", "crossing_min", ...}, ...],
         "sailings": [{"leg", "depart": "2026-08-14T08:15:00+0300", ...}, ...]}

    Terminal positions: latlon_from/latlon_to snapped to the route are
    preferred — they survive reroutes and work across GPX sources. km_from/
    km_to are the fallback and are only correct in the GPX's own distance
    frame. A terminal snapping further than max_snap_km from the route raises:
    that ferry isn't on this route (or the wrong file is loaded).
    """
    import json
    with open(path) as fh:
        spec = json.load(fh)

    by_leg: dict[str, list[datetime]] = {}
    for s in spec.get("sailings", []):
        by_leg.setdefault(s["leg"], []).append(datetime.fromisoformat(s["depart"]))

    out = []
    for fe in spec["ferries"]:
        name = fe.get("leg") or f'{fe.get("from", "?")}->{fe.get("to", "?")}'
        snap_off = None
        if route is not None and "latlon_from" in fe and "latlon_to" in fe:
            s_dep, off_d = snap_to_route(route, *fe["latlon_from"])
            s_arr, off_a = snap_to_route(route, *fe["latlon_to"])
            if max(off_d, off_a) > max_snap_km * 1000.0:
                raise ValueError(
                    f"ferry {name}: terminal snaps {max(off_d, off_a) / 1000:.1f} km "
                    f"off-route (limit {max_snap_km} km) — wrong route or ferry file?")
            if s_arr < s_dep:      # route rides this crossing opposite to from/to
                s_dep, s_arr = s_arr, s_dep
            snap_off = (off_d, off_a)
        elif "km_from" in fe and "km_to" in fe:
            s_dep, s_arr = fe["km_from"] * 1000.0, fe["km_to"] * 1000.0
        else:
            raise ValueError(f"ferry {name}: needs latlon_from/latlon_to "
                             f"(with a route) or km_from/km_to")

        deps = sorted(by_leg.get(fe["leg"], []))
        out.append(Ferry(
            name=name,
            s_dep=s_dep, s_arr=s_arr,
            crossing_s=fe["crossing_min"] * 60.0,
            departures=np.array([d.timestamp() for d in deps]),
            tz=deps[0].tzinfo if deps else None,
            snap_off_m=snap_off,
        ))
    out.sort(key=lambda f: f.s_dep)
    return out


# --------------------------------------------------------------------------
# Physics
# --------------------------------------------------------------------------

def solve_speed(power_w, mass_kg, grade, headwind_ms, cda, crr,
                rho=1.225, eff=0.97, v_cap=15.0, v_walk=1.2, iters=40):
    """Vectorised bisection for steady-state speed.

    Solves:  P*eff = v*(Crr*m*g*cos + m*g*sin) + 0.5*rho*CdA*(v+w)*|v+w|*v

    Using signed drag so tailwinds stronger than bike speed push rather than drag.
    Returns v in m/s. Falls back to walking pace on gradients too steep to ride.
    """
    theta = np.arctan(grade)
    f_const = crr * mass_kg * G * np.cos(theta) + mass_kg * G * np.sin(theta)
    target = power_w * eff

    def resid(v):
        rel = v + headwind_ms
        return v * f_const + 0.5 * rho * cda * rel * np.abs(rel) * v - target

    lo = np.full_like(np.asarray(headwind_ms, dtype=float), 0.05)
    hi = np.full_like(lo, 40.0)
    for _ in range(iters):
        mid = 0.5 * (lo + hi)
        f = resid(mid)
        hi = np.where(f > 0, mid, hi)
        lo = np.where(f > 0, lo, mid)
    v = 0.5 * (lo + hi)

    # Too steep / too slow to balance on a loaded bike -> push it.
    v = np.where(v < v_walk, v_walk, v)
    return np.minimum(v, v_cap)


def solar_elevation(lat_deg, lon_deg, t_epoch):
    """Approximate solar elevation in degrees. Good enough for day/night flags."""
    t = np.asarray(t_epoch, dtype=float)
    jd = t / 86400.0 + 2440587.5
    n = jd - 2451545.0
    L = np.radians((280.460 + 0.9856474 * n) % 360)
    g_ = np.radians((357.528 + 0.9856003 * n) % 360)
    lam = L + np.radians(1.915) * np.sin(g_) + np.radians(0.020) * np.sin(2 * g_)
    eps = np.radians(23.439 - 0.0000004 * n)
    dec = np.arcsin(np.sin(eps) * np.sin(lam))
    ra = np.arctan2(np.cos(eps) * np.sin(lam), np.cos(lam))
    gmst = (18.697374558 + 24.06570982441908 * n) % 24
    lst = np.radians((gmst * 15 + lon_deg) % 360)
    ha = lst - ra
    phi = np.radians(lat_deg)
    sin_alt = np.sin(phi) * np.sin(dec) + np.cos(phi) * np.cos(dec) * np.cos(ha)
    return np.degrees(np.arcsin(np.clip(sin_alt, -1, 1)))


def cyclist_apparent_temp(temp_c, rel_airspeed_ms, precip_mm_h, wet_chill_c):
    """Wind chill using RELATIVE airflow (bike speed + wind), not 10 m wind.

    Uses the JAG/TI wind chill formulation, which is defined for T <= 10 C and
    wind >= 4.8 km/h. Above that we return dry-bulb. The wet penalty is a crude
    stand-in for evaporative cooling through soaked kit — calibrate it.
    """
    v_kmh = np.maximum(rel_airspeed_ms * 3.6, 4.8)
    vp = v_kmh ** 0.16
    wc = 13.12 + 0.6215 * temp_c - 11.37 * vp + 0.3965 * temp_c * vp
    out = np.where(temp_c <= 10.0, wc, temp_c)
    wet = np.clip(precip_mm_h / 0.5, 0, 1) * wet_chill_c
    return out - np.where(temp_c <= 15.0, wet, 0.0)


# --------------------------------------------------------------------------
# Simulation
# --------------------------------------------------------------------------

@dataclass
class Trajectory:
    """Per-segment, per-member record of one rider draw."""
    arrive_t: np.ndarray       # (n_seg, M) epoch seconds at segment end
    speed: np.ndarray          # (n_seg, M) m/s
    move_s: np.ndarray         # (n_seg, M) moving seconds in segment
    temp: np.ndarray
    precip: np.ndarray         # mm/h
    headwind: np.ndarray       # m/s, +ve = headwind
    gust: np.ndarray
    apparent: np.ndarray
    dark: np.ndarray           # bool
    finish_t: np.ndarray       # (M,)
    sleep_s: np.ndarray        # (M,) total slept
    ferry_arrive_t: np.ndarray # (F, M) epoch at terminal
    ferry_wait: np.ndarray     # (F, M) seconds waited
    ferry_board_t: np.ndarray  # (F, M) departure boarded
    ferry_overrun: np.ndarray  # (F, M) bool: no sailing left in timetable


def simulate(route: Route, cube: WeatherCube, rider: Rider,
             start_epoch: float, ferries: Sequence[Ferry] = ()) -> Trajectory:
    """Forward-integrate one rider draw across all ensemble members at once."""
    M = cube.n_members
    n = len(route.seg_len)

    t = np.full(M, float(start_epoch))
    awake = np.zeros(M)
    ride_s = np.zeros(M)
    slept = np.zeros(M)

    F = len(ferries)
    on_ferry = np.full(n, -1)
    board_seg = {}
    for fi, f in enumerate(ferries):
        idx = np.where((route.seg_mid_s >= f.s_dep) & (route.seg_mid_s <= f.s_arr))[0]
        if len(idx) == 0:
            idx = np.array([min(int(np.searchsorted(route.seg_mid_s, f.s_dep)), n - 1)])
        on_ferry[idx] = fi
        board_seg[fi] = int(idx[0])
    f_arrive = np.zeros((F, M))
    f_wait = np.zeros((F, M))
    f_board = np.zeros((F, M))
    f_overrun = np.zeros((F, M), dtype=bool)

    rec = {k: np.empty((n, M)) for k in
           ("arrive_t", "speed", "move_s", "temp", "precip",
            "headwind", "gust", "apparent")}
    dark_rec = np.empty((n, M), dtype=bool)

    daily_budget = rider.daily_ride_h * 3600.0
    sleep_len = rider.sleep_h * 3600.0
    stop_s_per_m = (rider.stop_min_per_100km * 60.0) / 100_000.0
    fresh = rider.stop_min_per_100km_fresh
    stop_fresh_s_per_m = ((fresh * 60.0) / 100_000.0 if fresh is not None
                          else stop_s_per_m)
    ramp_t0 = rider.stop_ramp_delay_h * 3600.0
    ramp_len = max(rider.stop_ramp_h * 3600.0, 1.0)
    fatigue_k = -math.log(rider.fatigue_per_100h) / (100 * 3600.0)

    for i in range(n):
        s_mid = route.seg_mid_s[i]
        brg = math.radians(route.seg_bearing[i])

        fi = int(on_ferry[i])
        if fi >= 0:
            f = ferries[fi]
            if i == board_seg[fi]:
                f_arrive[fi] = t
                if len(f.departures):
                    j = np.searchsorted(f.departures, t)
                    over = j >= len(f.departures)
                    dep_t = np.where(over, t,
                                     f.departures[np.minimum(j, len(f.departures) - 1)])
                else:                      # no timetable -> board immediately
                    over = np.ones(M, dtype=bool)
                    dep_t = t
                wait = np.maximum(dep_t - t, 0.0)
                # HEURISTIC: a wait long enough for the full sleep block is
                # taken as the night's sleep (bivvy at the terminal).
                long_wait = wait >= sleep_len
                slept += np.where(long_wait, sleep_len, 0.0)
                awake = np.where(long_wait, 0.0, awake + wait)
                t = dep_t + f.crossing_s
                f_wait[fi], f_board[fi], f_overrun[fi] = wait, dep_t, over
            # On board: no riding, no stop overhead, sheltered from airflow.
            temp = cube.sample("temperature_2m", s_mid, t)
            rec["arrive_t"][i] = t
            rec["speed"][i] = f.speed_ms
            rec["move_s"][i] = 0.0
            rec["temp"][i] = temp
            rec["precip"][i] = np.maximum(cube.sample("precipitation", s_mid, t), 0.0)
            rec["headwind"][i] = 0.0
            rec["gust"][i] = cube.sample("wind_gusts_10m", s_mid, t)
            rec["apparent"][i] = temp
            dark_rec[i] = solar_elevation(route.seg_lat[i], route.seg_lon[i], t) < -3.0
            continue

        u = cube.sample("wind_u", s_mid, t)
        v_ = cube.sample("wind_v", s_mid, t)
        temp = cube.sample("temperature_2m", s_mid, t)
        prcp = np.maximum(cube.sample("precipitation", s_mid, t), 0.0)
        gust = cube.sample("wind_gusts_10m", s_mid, t)

        tail = u * math.sin(brg) + v_ * math.cos(brg)
        head = -tail

        alt = solar_elevation(route.seg_lat[i], route.seg_lon[i], t)
        is_dark = alt < -3.0

        power = rider.power_w * np.exp(-fatigue_k * ride_s)
        power = power * np.where(is_dark, rider.night_power_factor, 1.0)
        cap = np.where(is_dark, rider.night_descent_cap_ms, rider.day_descent_cap_ms)

        spd = solve_speed(power, rider.mass_kg, route.seg_grade[i], head,
                          rider.cda, rider.crr, eff=rider.drivetrain_eff,
                          v_cap=40.0, v_walk=rider.walk_speed_ms)
        spd = np.minimum(spd, np.where(route.seg_grade[i] < -0.01, cap, 40.0))

        dt_move = route.seg_len[i] / spd
        ramp = np.clip((ride_s - ramp_t0) / ramp_len, 0.0, 1.0)
        dt_stop = route.seg_len[i] * (stop_fresh_s_per_m
                                      + (stop_s_per_m - stop_fresh_s_per_m) * ramp)

        app = cyclist_apparent_temp(temp, np.abs(spd + head), prcp, rider.wet_chill_c)

        t = t + dt_move + dt_stop
        awake += dt_move + dt_stop
        ride_s += dt_move

        # Sleep when the daily budget is spent. Prefer to trigger in darkness,
        # but force it once 25% over budget so the schedule cannot run away.
        alt_now = solar_elevation(route.seg_lat[i], route.seg_lon[i], t)
        need = (awake > daily_budget) & ((alt_now < 0) | (awake > 1.25 * daily_budget))
        t = t + np.where(need, sleep_len, 0.0)
        slept += np.where(need, sleep_len, 0.0)
        awake = np.where(need, 0.0, awake)

        rec["arrive_t"][i] = t
        rec["speed"][i] = spd
        rec["move_s"][i] = dt_move
        rec["temp"][i] = temp
        rec["precip"][i] = prcp
        rec["headwind"][i] = head
        rec["gust"][i] = gust
        rec["apparent"][i] = app
        dark_rec[i] = is_dark

    return Trajectory(finish_t=t.copy(), sleep_s=slept, dark=dark_rec,
                      ferry_arrive_t=f_arrive, ferry_wait=f_wait,
                      ferry_board_t=f_board, ferry_overrun=f_overrun, **rec)


# --------------------------------------------------------------------------
# Exposure metrics
# --------------------------------------------------------------------------

def exposure(traj: Trajectory, cold_c: float = 5.0,
             rain_mm_h: float = 0.2, gust_ms: float = 15.0) -> dict[str, np.ndarray]:
    """Reduce a trajectory to per-member exposure metrics.

    These are the numbers that actually drive kit and sleep decisions, unlike
    an instantaneous '12 C, light rain' readout.
    """
    h = traj.move_s / 3600.0
    wet = traj.precip > rain_mm_h
    cold = traj.apparent < cold_c

    return {
        "duration_h": (traj.finish_t - traj.arrive_t[0] + traj.move_s[0]) / 3600.0,
        "moving_h": h.sum(axis=0),
        "sleep_h": traj.sleep_s / 3600.0,
        "rain_h": (h * wet).sum(axis=0),
        "rain_mm": (traj.precip * h).sum(axis=0),
        "cold_wet_h": (h * (wet & cold)).sum(axis=0),
        "sub_zero_h": (h * (traj.temp < 0)).sum(axis=0),
        "night_h": (h * traj.dark).sum(axis=0),
        "night_rain_h": (h * traj.dark * wet).sum(axis=0),
        "min_apparent_c": traj.apparent.min(axis=0),
        "mean_headwind_ms": (traj.headwind * h).sum(axis=0) / h.sum(axis=0),
        "max_gust_ms": traj.gust.max(axis=0),
        "high_gust_h": (h * (traj.gust > gust_ms)).sum(axis=0),
        "ferry_wait_h": traj.ferry_wait.sum(axis=0) / 3600.0,
    }


def misery_index(ex: dict[str, np.ndarray]) -> np.ndarray:
    """A single scalar for ranking start times. Weights are yours to argue with;
    this set is tuned for 'do not get hypothermic in the Baltics in shoulder
    season', which is a different objective from 'go fast'."""
    return (3.0 * ex["cold_wet_h"]
            + 1.5 * ex["night_rain_h"]
            + 1.0 * ex["rain_h"]
            + 2.0 * ex["sub_zero_h"]
            + 0.8 * ex["high_gust_h"]
            + 0.5 * np.maximum(ex["mean_headwind_ms"], 0) * ex["moving_h"])


def summarise(ex_list: Iterable[dict[str, np.ndarray]],
              quantiles=(0.1, 0.5, 0.9)) -> dict[str, dict[str, float]]:
    """Pool metrics across all (rider draw x ensemble member) realisations."""
    pooled: dict[str, list[np.ndarray]] = {}
    for ex in ex_list:
        for k, v in ex.items():
            pooled.setdefault(k, []).append(np.atleast_1d(v))
    out = {}
    for k, vs in pooled.items():
        a = np.concatenate(vs)
        out[k] = {f"q{int(q*100)}": float(np.quantile(a, q)) for q in quantiles}
        out[k]["mean"] = float(a.mean())
    return out


# --------------------------------------------------------------------------
# Start-window scan
# --------------------------------------------------------------------------

def scan_start_times(route: Route, cube: WeatherCube, base: Rider,
                     starts: Sequence[float], n_riders: int = 20,
                     seed: int = 0, ferries: Sequence[Ferry] = ()) -> list[dict]:
    """Evaluate every candidate departure time over the window.

    Returns one row per start time with quantiles of each exposure metric and
    of the misery index. Feed to R/ggplot as a heatmap of start time vs risk.
    """
    rng = np.random.default_rng(seed)
    riders = sample_riders(base, n_riders, rng)
    rows = []
    for st in starts:
        exs, mis = [], []
        for r in riders:
            tr = simulate(route, cube, r, st, ferries)
            ex = exposure(tr)
            exs.append(ex)
            mis.append(misery_index(ex))
        summ = summarise(exs)
        m = np.concatenate([np.atleast_1d(x) for x in mis])
        rows.append({
            "start_utc": datetime.fromtimestamp(st, timezone.utc).isoformat(),
            "start_epoch": st,
            "misery_q10": float(np.quantile(m, 0.1)),
            "misery_q50": float(np.quantile(m, 0.5)),
            "misery_q90": float(np.quantile(m, 0.9)),
            **{f"{k}_{q}": v for k, d in summ.items() for q, v in d.items()},
        })
    return rows


def ferry_report(ferries: Sequence[Ferry],
                 trajs: Sequence[Trajectory]) -> list[dict]:
    """Per-ferry arrival/wait stats and sailing-catch distribution, pooled
    across (rider draw x ensemble member) realisations.

    'catches' answers the operational question: which sailing do I make, with
    what probability — the number that decides whether to push or sleep."""
    rows = []
    for fi, f in enumerate(ferries):
        arr = np.concatenate([tr.ferry_arrive_t[fi] for tr in trajs])
        wait = np.concatenate([tr.ferry_wait[fi] for tr in trajs])
        board = np.concatenate([tr.ferry_board_t[fi] for tr in trajs])
        over = np.concatenate([tr.ferry_overrun[fi] for tr in trajs])

        def iso(epoch: float) -> str:
            return datetime.fromtimestamp(epoch, f.tz or timezone.utc).isoformat()

        vals, counts = np.unique(board[~over], return_counts=True)
        catches = [{"depart": iso(v), "share": float(c) / len(board)}
                   for v, c in zip(vals, counts)]
        rows.append({
            "ferry": f.name,
            "arrive_q10": iso(float(np.quantile(arr, 0.1))),
            "arrive_q50": iso(float(np.quantile(arr, 0.5))),
            "arrive_q90": iso(float(np.quantile(arr, 0.9))),
            "wait_h_q50": float(np.quantile(wait, 0.5)) / 3600.0,
            "wait_h_q90": float(np.quantile(wait, 0.9)) / 3600.0,
            "overrun_share": float(over.mean()),
            "catches": catches,
        })
    return rows


def to_dataframe(rows):
    import pandas as pd
    return pd.DataFrame(rows)


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------

def main():
    import argparse, json
    p = argparse.ArgumentParser(description="Multi-day route weather exposure")
    p.add_argument("gpx")
    p.add_argument("--start", help="ISO8601 UTC, e.g. 2026-08-14T05:00")
    p.add_argument("--window-h", type=float, default=72.0,
                   help="scan departures across this many hours")
    p.add_argument("--step-h", type=float, default=6.0)
    p.add_argument("--riders", type=int, default=20)
    p.add_argument("--days", type=int, default=10, help="forecast_days to fetch")
    p.add_argument("--spacing-km", type=float, default=25.0)
    p.add_argument("--rider", help="rider JSON (e.g. from calibrate_tbr.py); "
                                   "explicit flags below override its fields")
    p.add_argument("--power", type=float, default=None)
    p.add_argument("--mass", type=float, default=None)
    p.add_argument("--crr", type=float, default=None,
                   help="terrain override; calibrated crr is surface-specific")
    p.add_argument("--daily-h", type=float, default=None)
    p.add_argument("--sleep-h", type=float, default=None)
    p.add_argument("--out", help="write CSV here (requires pandas)")
    p.add_argument("--cache", help="npz path for the weather cube; loaded if it "
                                   "exists, written after a successful fetch")
    p.add_argument("--ferries", help="ferries JSON (legs + timetabled sailings); "
                                     "km markers must match the GPX distance frame")
    a = p.parse_args()

    lat, lon, ele = load_gpx(a.gpx)
    route = build_route(lat, lon, ele)
    print(f"route: {route.total_km:.0f} km, {route.total_ascent_m:.0f} m ascent, "
          f"{len(route.seg_len)} segments")

    import os
    if a.cache and os.path.exists(a.cache):
        cube = load_cube(a.cache)
        print(f"cube loaded from {a.cache}")
    else:
        cube = fetch_weather_cube(route, spacing_km=a.spacing_km, forecast_days=a.days)
        if a.cache:
            save_cube(cube, a.cache)
            print(f"cube cached to {a.cache}")
    print(f"cube: {len(cube.wp_s)} waypoints x {cube.n_t} hours x "
          f"{cube.n_members} members")

    if a.start:
        t0 = datetime.fromisoformat(a.start).replace(tzinfo=timezone.utc).timestamp()
    else:
        t0 = cube.t0 + 6 * 3600

    starts = np.arange(t0, t0 + a.window_h * 3600, a.step_h * 3600)
    rider_kw = {}
    if a.rider:
        with open(a.rider) as fh:
            rider_kw.update({k: v for k, v in json.load(fh).items()
                             if not k.startswith("_")})
    for key, val in (("power_w", a.power), ("mass_kg", a.mass), ("crr", a.crr),
                     ("daily_ride_h", a.daily_h), ("sleep_h", a.sleep_h)):
        if val is not None:
            rider_kw[key] = val
    rider = Rider(**rider_kw)
    print(f"rider: {rider.power_w:.0f} W, {rider.mass_kg:.0f} kg, crr {rider.crr}, "
          f"{rider.daily_ride_h:.1f} h/day, sleep {rider.sleep_h:.1f} h, "
          f"stops {rider.stop_min_per_100km:.0f} min/100km")

    ferries = load_ferries(a.ferries, route) if a.ferries else []
    for f in ferries:
        snap = (f"  [snapped, terminals {f.snap_off_m[0]:.0f}/{f.snap_off_m[1]:.0f} m "
                f"off-route]" if f.snap_off_m else "  [km markers, unverified frame]")
        print(f"ferry {f.name}: km {f.s_dep/1000:.1f}->{f.s_arr/1000:.1f}, "
              f"{len(f.departures)} sailings{snap}")

    t_start = _time.time()
    rows = scan_start_times(route, cube, rider, starts, n_riders=a.riders,
                            ferries=ferries)
    print(f"simulated {len(starts)} start times in {_time.time()-t_start:.1f}s")

    best = min(rows, key=lambda r: r["misery_q50"])
    print("\nbest departure (median misery):", best["start_utc"])
    for k in ("duration_h", "moving_h", "rain_h", "cold_wet_h",
              "night_rain_h", "min_apparent_c", "mean_headwind_ms", "ferry_wait_h"):
        print(f"  {k:>18}: q10={best[k+'_q10']:7.1f}  "
              f"q50={best[k+'_q50']:7.1f}  q90={best[k+'_q90']:7.1f}")

    if ferries:
        # Same seed as scan_start_times -> identical rider draws.
        riders = sample_riders(rider, a.riders, np.random.default_rng(0))
        trajs = [simulate(route, cube, r, best["start_epoch"], ferries)
                 for r in riders]
        print("\nferry report (best start, times local to timetable):")
        for row in ferry_report(ferries, trajs):
            print(f"  {row['ferry']}: arrive q10 {row['arrive_q10']}  "
                  f"q50 {row['arrive_q50']}  q90 {row['arrive_q90']}")
            print(f"    wait h q50={row['wait_h_q50']:.1f} q90={row['wait_h_q90']:.1f}"
                  f"  beyond-timetable share={row['overrun_share']:.0%}")
            for c in row["catches"]:
                print(f"    {c['share']:6.1%}  {c['depart']}")

    if a.out:
        to_dataframe(rows).to_csv(a.out, index=False)
        print(f"\nwrote {a.out}")


if __name__ == "__main__":
    main()
