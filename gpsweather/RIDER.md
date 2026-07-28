# rider.json — the performance model input

The rider file is what turns a route + weather into *your* forecast: it places
you at a (position, time) distribution so the app can report the conditions
you will actually meet. It is also the most elusive input — so it degrades
gracefully. Every field is optional; `outlook.py` without `--rider` runs a
generic loaded bikepacker.

Keys starting with `_` are ignored by the loader — use `_provenance` to record
where the numbers came from and when.

## Three ways to get one

**Tier 0 — nothing.** Omit `--rider`. Generic defaults (see table). Timing
will be generic too; weather-along-route is still meaningful because the
ensemble×rider spread covers a wide pace range.

**Tier 1 — estimate (5 minutes).** A minimal file goes a long way:

```json
{
 "_provenance": "hand estimate, Jan 2027: FTP 240 -> power 0.65x, mass weighed, crr from surface table",
 "power_w": 160,
 "mass_kg": 90,
 "crr": 0.012,
 "daily_ride_h": 13,
 "sleep_h": 6,
 "stop_min_per_100km": 90
}
```

**Tier 2 — calibrate from your own rides (`calibrate_rider.py`).** Point it at
real multi-day ride data; it measures what can be measured and is explicit
about the rest:

```
# best: original FITs with a power meter
python calibrate_rider.py --fit-glob "rides/*.fit" --mass 95 --out rider.json

# no power meter: per-second track CSV + an FTP bound for the power/crr ridge
python calibrate_rider.py track.csv --ftp 240 --out rider.json
```

| mode | measured | assumed |
|---|---|---|
| FIT + power meter | power, fatigue, night factor, crr (that terrain), stops, sleep, daily hours, descent caps | cda (degenerate at bike speeds), ramp shape, wet chill |
| CSV speed-only | stops, sleep, daily hours, descent caps; (power, crr) as a ridge pinned by `--ftp` | cda, fatigue/night only weakly, ramp shape, wet chill |

## Field reference

Defaults are the engine's; units in the name where not stated. `sample_riders`
perturbs the ⚄-marked fields per Monte Carlo draw (the file is the *center* of
the rider distribution, not a fixed script).

| field | default | meaning / how to obtain |
|---|---|---|
| `power_w` ⚄ | 150 | Sustainable propulsive power on the flat, all day. Meter: rested intercept of per-day median power. Estimate: 0.6–0.7 × FTP. |
| `mass_kg` | 95 | Loaded system mass. Weigh it — not identifiable from ride data. |
| `cda` ⚄ | 0.36 | m². Assumed: ~0.32 (drops, compact bags) to 0.45 (upright, wide bags). Not identifiable at bikepacking speeds — would need a dedicated test. |
| `crr` ⚄ | 0.008 | **Terrain-specific — the least transferable number.** Power-balance measured: ~0.005 race asphalt, 0.010–0.013 loaded paved touring, 0.015–0.020 good gravel, 0.025–0.040 rough tracks. Recalibrate per surface or override with `--crr`. |
| `drivetrain_eff` | 0.97 | Leave alone. |
| `daily_ride_h` ⚄ | 14 | Awake budget (moving + stops) before the model sleeps. From past multi-day rides. |
| `sleep_h` ⚄ | 5 | Per night. Racers 1.5–5, tourers 7–9. |
| `stop_min_per_100km` ⚄ | 45 | Steady-state overhead: resupply, meals, faff. Hugely personal — measured range spans 30 (disciplined racer) to 140+ (measured for Taavi at TBR). |
| `stop_min_per_100km_fresh` ⚄ | none | Fresh-phase stop rate; enables the ramp. Fresh riders stop far less (measured 35 vs 140). Omit for a flat rate. |
| `stop_ramp_delay_h` | 10 | Ride-hours at the fresh rate before ramping. Shape is heuristic; endpoints are measurable. |
| `stop_ramp_h` | 12 | Ramp duration up to the steady rate. |
| `fatigue_per_100h` | 0.80 | Power multiplier after 100 ride-hours (exponential decay). Meter-measured 0.63 for Taavi; without a meter leave the default. |
| `night_power_factor` | 0.92 | Power in darkness relative to day. Meter-measurable when there is night riding. |
| `day_descent_cap_ms` | 15 | Descending is caution-limited, not physics-limited: q90 of observed descent speed. |
| `night_descent_cap_ms` | 8 | Same, in darkness. |
| `walk_speed_ms` | 1.2 | Hike-a-bike fallback on unrideable grades. |
| `wet_chill_c` | 4.0 | HEURISTIC extra cooling when soaked. Uncalibrated so far. |

## What matters most

Sensitivity, in the order it moves multi-day results: `crr` (through speed,
and it silently changes with surface), the stop rates (arrival times — this is
where day-vs-night ferry cutoffs are won), `daily_ride_h`/`sleep_h` (the
duty-cycle structure of day 2+), `power_w`, then everything else. `cda` starts
to matter on fast flat routes in wind — exactly where its assumed value is
weakest; treat windy flat forecasts with that in mind.

Reference example: `data/rider_taavi.json` (TBR 2026 power-meter calibration +
Kõkõva 2025 surface/stop measurements; provenance inline).
