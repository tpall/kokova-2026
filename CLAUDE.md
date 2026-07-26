# Kõkõva 900 · 2026 — Project

Race planning for Kõkõva 900, a self-supported single-stage bikepacking race
around Estonia's western islands. Same shape as the `TBR-2026` project: R
scripts fetch live data and render markdown reports that are committed
alongside them.

## Race facts

- **Start / finish:** Tallinn, Hundipea (Kakaoladu) — Fri 14 Aug 2026, 21:00 EEST
- **Time limit:** 7 days → Fri 21 Aug 2026, 21:00
- **Route:** ~985 km including ferry legs (~954 km actually ridden), ~1580 m climbing
- **Surface:** ~60% forest/gravel, ~39% paved, ~1% hike-a-bike
- **Track:** `data/kokova_2026_900_beta.kmz` (three LineStrings; "BETA" — expect a final version)
- **Organiser:** https://www.panepanepane.ee/k6k6va
- **Field:** 120 places, solo or pairs, fully self-supported

## Ferries — the defining constraint

Three crossings. Two are frequent; one decides the race.

| km | Crossing | Frequency in race window | Duration | Operator | Data source |
|---:|----------|--------------------------|---------:|----------|-------------|
| 181.6 | Rohuküla → Heltermaa | ~11/day, 06:30–22:00 | 75 min | TS Laevad | praamid.ee published timetable |
| 316.5 | **Sõru → Triigi** | **2–3/day** | 35 min | Kihnu Veeteed | veeteed.com booking API |
| 698.5 | Kuivastu → Virtsu | ~26/day, 05:00–22:50 | 27 min | TS Laevad | praamid.ee published timetable |

Sõru–Triigi is the only link between Hiiumaa and Saaremaa. In the race window it
runs 08:15 / 11:00 / 18:30, and **from Tue 18 Aug only 08:15 and 17:30** — a
9.25 h gap. Missing the evening sailing on the first full day costs ~13.75 h.
Everything upstream of km 316.5 is really a race against one of these departures.

## Scripts

```
R/         code
data/      route definition: the track, and geometry derived from it
output/    machine-readable results (JSON), regenerated every run
reports/   the human-facing markdown
```

| File | Purpose |
|---|---|
| `R/plan.R` | Shared parameters, KMZ → track pipeline, ferry definitions, rider profiles, pacing simulation. Sourced by the others. |
| `R/prepare_route.R` | **Needs the KMZ.** Regenerates `data/waypoints.csv` + `data/route_directions.csv`. Run once per new track. |
| `R/ferry_schedule.R` | Fetches all three timetables → `output/ferries.json`, `reports/ferry_plan.md` |
| `R/weather_forecast.R` | Open-Meteo 16-day forecast → `output/weather_forecast.json`, `reports/weather_forecast.md` |
| `R/weather_outlook.R` | ERA5 climatology for 14–21 Aug → `output/weather_outlook.json`, `reports/weather_outlook.md` |
| `data/waypoints.csv` | 21 waypoints: km, coordinates, elevation, type, direction of travel. **Names are hand-authored** — `prepare_route.R` preserves them. |
| `data/route_directions.csv` | Distance-weighted travel-direction histogram, 1° bins |
| `R/resupply.R` | **Needs the KMZ.** Overpass query along the route → `data/resupply.csv`. Slow and throttled; manual. |
| `R/athlete.R` | Rider constants — FTP, zones, current form, and the measured history of TBR 2026 and Kõkõva 2025. Every figure names its source. |
| `R/race_strategy.R` | Pacing + ferries + fitness → `reports/race_strategy.md` |
| `R/resupply_plan.R` | Resupply gaps, opening hours, fuelling → `reports/resupply.md` |

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

The KMZ is committed, but only `prepare_route.R` reads it. It derives
`waypoints.csv` (adding a `route_deg` column) and `route_directions.csv`, and
the other three scripts read those instead of the track. Reasons: the daily CI
job does not re-parse 19 000 track points on every run, and the geometry that
feeds the wind-exposure numbers is committed where it can be inspected and
diffed rather than recomputed silently.

`TOTAL_ROUTE_KM` in `R/plan.R` is a hardcoded constant for the same reason.

**When a new KMZ lands, run `prepare_route.R` first**, then the other scripts,
and check `TOTAL_ROUTE_KM` against its reported total. Waypoint names are
hand-curated — reverse geocoding returns bare municipality names for much of
Saaremaa — so `prepare_route.R` preserves the existing `name` and `km` columns
and only recomputes geometry.

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

## Modelling notes

- The KMZ encodes two of the three ferry crossings as a **gap between
  LineStrings**; the Sõru–Triigi crossing is drawn as a straight line inside
  segment 2. Both are declared in `FERRIES` so the pacing model never rides
  across water.
- The route is flat, so there is no gradient-based speed model as in TBR. Speed
  is a per-profile constant derated by a stop fraction. **Wind is the only
  terrain that matters**, so the weather reports classify it relative to the
  direction of travel (`wind_effect()` in `R/plan.R`).
- When computing wind exposure, bin travel direction to **whole degrees, not
  compass octants**. Binning both wind and travel to octants puts the ±45°
  boundary on a bin centre and reports 37% headwind / 13% tailwind for a closed
  loop, which is a discretisation artefact — it must be ~25/25 by symmetry.
- `LC_TIME` is pinned to `"C"` so the English praamid.ee pages parse regardless
  of host locale; use `fmt_et()` for anything user-facing.
