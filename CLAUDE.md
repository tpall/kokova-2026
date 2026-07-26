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
- **Track:** `kokova_2026_900_beta.kmz` (three LineStrings; "BETA" — expect a final version)
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

| File | Purpose |
|---|---|
| `kokova_plan.R` | Shared parameters, KMZ → track pipeline, ferry definitions, rider profiles, pacing simulation. Sourced by the others. |
| `ferry_schedule.R` | Fetches all three timetables → `ferries.json`, `ferry_plan.md` |
| `weather_forecast.R` | Open-Meteo 16-day forecast → `weather_forecast.json`, `weather_forecast.md` |
| `weather_outlook.R` | ERA5 climatology for 14–21 Aug → `weather_outlook.json`, `weather_outlook.md` |
| `waypoints.csv` | 21 waypoints with km, coordinates, elevation, type |

Run any of them with `Rscript <file>` from the project root.

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
  direction of travel (`wind_effect()` in `kokova_plan.R`).
- When computing wind exposure, bin travel direction to **whole degrees, not
  compass octants**. Binning both wind and travel to octants puts the ±45°
  boundary on a bin centre and reports 37% headwind / 13% tailwind for a closed
  loop, which is a discretisation artefact — it must be ~25/25 by symmetry.
- `LC_TIME` is pinned to `"C"` so the English praamid.ee pages parse regardless
  of host locale; use `fmt_et()` for anything user-facing.
