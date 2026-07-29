# Kõkõva 900 · 2026 — Project

Race planning for Kõkõva 900, a self-supported single-stage bikepacking race
around Estonia's western islands. Same shape as the `TBR-2026` project: R
scripts fetch live data and render markdown reports that are committed
alongside them.

## Race facts

- **Start / finish:** Tallinn, Hundipea (Kakaoladu) — Fri 14 Aug 2026, 21:00 EEST.
  First 11 km neutralised behind the race director (~30 min); drafting allowed
  to km 39 (Türisalu descent)
- **Time limit:** 7 days → Fri 21 Aug 2026, 21:00
- **Route:** 986.3 km including ferry legs (941.5 km actually ridden — manual
  says "941"), ~4000 m climbing per the manual
- **Surface (measured, `data/surface.csv`):** ~51% asphalt, ~42% gravel, ~4%
  dirt; the opening leg is 53% asphalt (manual: "about 50% paved"), Hiiumaa is
  the only majority-gravel section (58%)
- **Track:** `data/kokova_2026_900_final_[123].gpx` (organiser's final
  RideWithGPS exports, renamed — originals had `:`/`()` in the names, which
  break make prerequisites); `prepare_route.R` merges them into
  `data/kokova_2026_900_final.gpx`, which is what everything else reads
- **Checkpoints:** CP1 Paluküla, Hiiumaa km 221.9 (staffed: kitchen, showers,
  tools — also where 900/500 riders commit to a distance; the part 1/2 file
  split is here, not at a ferry). CP2 Kallaste bus stop, Muhu km 669.8
  (unstaffed). Manual kms (200/633) count ridden km only
- **Manuals:** `data/kokova_2026_race_manual_{eng,est}.pdf`
- **Organiser:** https://www.panepanepane.ee/k6k6va
- **Field:** 120 places, solo or pairs, fully self-supported

## Ferries — the defining constraint

Three crossings. Two are frequent; one decides the race.

| km | Crossing | Frequency in race window | Duration | Operator | Data source |
|---:|----------|--------------------------|---------:|----------|-------------|
| 172.7 | Rohuküla → Heltermaa | ~11/day, 06:30–23:00 | 75 min | TS Laevad | praamid.ee published timetable |
| 368.4 | **Sõru → Triigi** | **2–3/day** | 35 min | Kihnu Veeteed | veeteed.com booking API |
| 692.2 | Kuivastu → Virtsu | ~26/day, 05:00–22:50 | 27 min | TS Laevad | praamid.ee published timetable |

Sõru–Triigi is the only link between Hiiumaa and Saaremaa. In the race window it
runs 08:15 / 11:00 / 18:30, and **from Tue 18 Aug only 08:15 and 17:30** — a
9.25 h gap. Missing the evening sailing on the first full day costs ~13.75 h.
Everything upstream of km 368.4 is really a race against one of these departures.

The final route sharpened this: 173 km of Hiiumaa now sit between Heltermaa and
Sõru (the beta had 112), so the Saturday 18:30 sailing is only reachable off the
**06:30 Rohuküla boat** at mid-pack pace — the 08:30 boat leaves 8.5 h for
173 km of mostly gravel. The morning Rohuküla ferry, not the Sõru quay, is the
race's real gate; `race_strategy.md` works this out against the live timetable.

## Route weather outlook (gpsweather/)

`make route-outlook` (part of `daily`, runs in the GA after the ferry refresh):
vendored copy of the generic `~/Projects/gps-weather` engine (see
`gpsweather/VENDORED.md` — develop there, re-copy here). Ensemble weather ×
calibrated-rider Monte Carlo over the merged track + live sailings →
`reports/route_outlook.md` + `output/route_outlook.json`: ferry-catch odds,
exposure quantiles, 6-h conditions timeline. Before ~1 Aug the start is beyond
the 15-day ECMWF horizon and the report says so instead of failing.

## Scripts

```
R/         code
data/      route definition: the track, and geometry derived from it
output/    machine-readable results (JSON), regenerated every run
reports/   the human-facing markdown
```

| File | Purpose |
|---|---|
| `R/plan.R` | Shared parameters, GPX → track pipeline, ferry definitions, rider profiles, pacing simulation. Sourced by the others. |
| `R/prepare_route.R` | **Needs the three GPX parts.** Merges them into `data/kokova_2026_900_final.gpx` and regenerates `data/waypoints.csv` + `data/route_directions.csv`. Run once per new track. |
| `R/ferry_schedule.R` | Fetches all three timetables → `output/ferries.json`, `reports/ferry_plan.md` |
| `R/weather_forecast.R` | Open-Meteo 16-day forecast → `output/weather_forecast.json`, `reports/weather_forecast.md` |
| `R/weather_outlook.R` | ERA5 climatology for 14–21 Aug → `output/weather_outlook.json`, `reports/weather_outlook.md` |
| `data/waypoints.csv` | 24 waypoints: km, coordinates, elevation, type (incl. the two CPs), direction of travel. **Names and kms are hand-authored** — `prepare_route.R` recomputes only `route_deg` and warns if a km disagrees with the coordinates. |
| `data/route_directions.csv` | Distance-weighted travel-direction histogram, 1° bins, ferry legs excluded |
| `R/resupply.R` | **Needs the merged track.** Overpass query along the route → `data/resupply.csv`. Slow and throttled; manual. |
| `R/surface.R` | **Needs the merged track** + cached Geofabrik extract. OSM surface every 250 m → `data/surface.csv`. |
| `R/athlete.R` | Rider constants — FTP, zones, current form, and the measured history of TBR 2026 and Kõkõva 2025. Every figure names its source. |
| `R/race_strategy.R` | Pacing + ferries + fitness → `reports/race_strategy.md` |
| `R/resupply_plan.R` | Resupply gaps, opening hours, fuelling → `reports/resupply.md` |
| `R/recon_ride.R` | One-off plan for the 29–31 Jul mainland recon → `reports/recon_ride.md` |

**All paths in `R/plan.R` are relative to the project root, so scripts must be
run from there** — `make daily` or `Rscript R/ferry_schedule.R`, never from
inside `R/`.

### Makefile

`make daily` (ferry + forecast) is what CI runs; `make outlook` is manual;
`make route` rebuilds the derived geometry. Two things to keep in mind if you
edit it:

- The fetch targets are **`.PHONY` on purpose.** Their output depends on what
  the ferry operators and weather models say right now, not on any file, so
  timestamp logic would skip them exactly when they are needed — and after a
  fresh CI checkout every file carries the same mtime, which makes that skip
  unpredictable.
- `ROUTE` names only `waypoints.csv`, though `prepare_route.R` writes two files.
  A rule with two targets runs its recipe once per target, and grouped targets
  (`&:`) need make 4.3 while macOS ships 3.81.

### Route geometry is a build step

The three organiser GPX parts are committed, but only `prepare_route.R` reads
them. It writes the merged track plus `waypoints.csv` (refreshing `route_deg`)
and `route_directions.csv`, and the daily scripts read the CSVs instead of the
track. Reasons: the daily CI job does not re-parse 20 500 track points on every
run, and the geometry that feeds the wind-exposure numbers is committed where
it can be inspected and diffed rather than recomputed silently.

`TOTAL_ROUTE_KM` in `R/plan.R` is a hardcoded constant for the same reason.

**When a new track lands, run `prepare_route.R` first**, then the other
scripts, and check `TOTAL_ROUTE_KM` against its reported total. Waypoint names
and kms are hand-curated — reverse geocoding returns bare municipality names
for much of Saaremaa — so `prepare_route.R` keeps the rows as they are,
recomputes only `route_deg`, and warns when a waypoint's km no longer matches
where its coordinates sit on the track (the sign that the route moved and the
row needs hand-editing). A route change also invalidates `resupply.csv` and
`surface.csv` — rerun both (`make resupply surface`), since every km key in
them shifts.

## Data sources and their quirks

- **praamid.ee** publishes one table per validity period on the route pages, in
  the same order as the period picker. Every cell repeats the weekday letter
  (`E06:30`), which is what makes the grid parseable without tracking column
  positions. Only the English pages are scraped — the period labels there are
  machine-readable dates.
- **veeteed.com** exposes the live booking inventory at
  `/api/sailPackage/inventory/{leg}/{date}/`. Leg code for this route is
  `SOR-TRI`. The response carries remaining bicycle capacity per sailing, which
  is worth watching when the whole field targets one departure. There is no
  documented contract here — if it breaks, fall back to the site itself.
- **Open-Meteo** returns ragged series: `precipitation_probability_max` stops
  short of the other daily fields, so columns are padded before binding.
- **Overpass** is queried along a 1.5 km corridor (`RADIUS_M` in `R/resupply.R`).
  That is the main known blind spot in the resupply data: a town the route
  skirts is invisible. Haapsalu is the worked example — 6 km off the outbound
  leg at km 170.9, so it does not appear at all for the last ~51 km before the
  Rohuküla quay, even though it is the only real bail-out there (the return leg
  passes it again at km 790.4, 2.9 km off, where its eastern edge does make it
  into the data). Widen the radius or add a targeted query before trusting
  "no resupply" over a stretch that passes near a town.

## Modelling notes

- The final track draws **Rohuküla–Heltermaa and Sõru–Triigi straight across
  the water** (interpolated at ~100 m steps — no step-length filter can catch
  them); only Kuivastu–Virtsu is a real gap between parts (one 6.7 km step).
  All three are declared in `FERRIES` so the pacing model never rides across
  water, and `prepare_route.R`/`surface.R` drop the drawn crossings by km
  range.
- The route is gently rolling at most (~4000 m over 941 km), so there is no
  gradient-based speed model as in TBR. Speed is a per-profile constant derated
  by a stop fraction, plus the fixed neutralised opening (11 km in ~30 min,
  `NEUTRAL_KM`/`NEUTRAL_H`). **Wind is the only terrain that matters**, so the
  weather reports classify it relative to the direction of travel
  (`wind_effect()` in `R/plan.R`).
- When computing wind exposure, bin travel direction to **whole degrees, not
  compass octants**. Binning both wind and travel to octants puts the ±45°
  boundary on a bin centre and reports 37% headwind / 13% tailwind for a closed
  loop, which is a discretisation artefact — it must be ~25/25 by symmetry.
- `LC_TIME` is pinned to `"C"` so the English praamid.ee pages parse regardless
  of host locale; use `fmt_et()` for anything user-facing.
