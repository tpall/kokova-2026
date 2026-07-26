# Kõkõva 900 (2026) — rider constants.
#
# Everything here is measured, not assumed, and every figure names its source in
# /Users/taavi/Projects/training-plan/. Where a number does not exist, the entry
# says so rather than carrying a plausible guess into the race plan.
#
# Sourced by race_strategy.R and resupply_plan.R.

suppressPackageStartupMessages({
  library(tibble)
})

ATHLETE <- list(
  # ── Physiology ──────────────────────────────────────────────────────────────
  ftp_w        = 247,    # intervals.icu retest 27 Jun 2026 (was 237 W at TBR)
  weight_kg    = 76.8,   # last manual entry 14 May 2026
  lthr         = 150,    # lactate-threshold HR, cycling
  hr_max       = 170,    # highest HR actually recorded on any 2026 activity
  hr_rest      = 46,
  age          = 52,
  # Garmin cycling-ability profile, 12 Jun 2026: ENDURANCE_SPECIALIST —
  # aerobic endurance 88, aerobic capacity 67, anaerobic 25.
  profile_type = "endurance specialist",

  # ── Current form, as of the last data (24 Jul 2026) ─────────────────────────
  # The two numbers point in opposite directions and both matter.
  chronic_load     = 323,   # Garmin 28-day chronic load
  chronic_peak     = 833,   # 2026 peak, 18 Apr
  hrv_recent       = 61,    # weekly average, 22–24 Jul; 2026 mean is 59.8
  days_off_bike    = 13,    # last ride 13 Jul
  training_status  = "DETRAINING",
  longest_ride_since_race_km = 61.7,   # 11 Jul, 2.4 h

  # ── Kõkõva 2025: the best capability data, NOT a time prediction ────────────
  # A ~937 km self-supported ride, 15–19 Aug 2025, off a 20:48 start. Same
  # event and same format, but a completely different course: 2025 ran through
  # Lääne-Virumaa and southern Estonia (lon 25.6–27.6 E, ~8 200 m of climbing in
  # the GPX), 2026 runs west and out to the islands (lon 21.9–24.7 E, ~1 580 m).
  # The longitude ranges do not even touch — there is no route overlap at all,
  # and 2025 had no ferries.
  #
  # So the transferable figures are the rider ones: moving speed, how long he
  # rides before first sleeping, how little he sleeps, how slowly his power
  # decays. The 89.8 h elapsed is NOT transferable and must not be used as a
  # target time. If anything the 18.5 km/h understates flat-terrain capability —
  # it was set on five times the climbing — but the 2026 route is 60%
  # forest/gravel, which cuts the other way. That tension is the single largest
  # uncertainty in the whole plan.
  y2025 = list(
    km            = 936.7,
    ascent_m      = 5749,   # Garmin barometric; the GPX route totals ~8 200 m
    ferries       = 0,      # unlike 2026, nothing to wait for
    riding_h      = 50.6,
    elapsed_h     = 89.8,
    stopped_h     = 39.1,
    moving_kmh    = 18.5,
    overall_kmh   = 10.4,
    sleep_h       = 14.8,   # watch-measured, across the whole event
    leg1_km       = 349.3,  # ridden straight off the start, no sleep
    leg1_h        = 17.85,
    power_decay   = -0.08   # 118 → 109 W avg over the first three long legs
  ),

  # ── TBR 2026: what a hard multi-day looks like when it goes wrong ───────────
  # DNF at km 819 on a rear-hub failure, not on fitness. The pacing and rest
  # numbers still stand as lessons.
  tbr = list(
    dnf_km          = 819,
    elapsed_h       = 126.4,
    moving_h        = 80.5,
    stopped_h       = 45.9,   # field median over the same distance: 33.8 h
    stopped_median  = 33.8,
    power_decay     = -0.27,  # 115 → 84 W avg, D1 to D5
    sleep_stopped_h = 36.8,   # time spent stopped to sleep
    sleep_actual_h  = 22.2,   # of which actually asleep — 60% efficiency
    kcal_per_day    = 6150    # Garmin daily total, D1–D5
  ),

  # ── Fuelling ────────────────────────────────────────────────────────────────
  # UNTESTED. The 90 g/h is a plan target written for TBR 2027; the training
  # project contains no logged intake of any kind — every nutrition entry is
  # zero and every hydration entry is 0.0 ml. Treat as a target to rehearse
  # before the race, not as a known tolerance.
  carb_g_h_target  = 90,
  fluid_ml_h       = c(500, 750),
  carbs_tested     = FALSE,
  # Estimated sweat loss at TBR was 345–502 ml/h in Balkan heat; August in
  # Estonia is milder (median day max 20–22 °C per weather_outlook.md), so the
  # lower end is the sensible planning figure.
  sweat_ml_h_tbr   = c(345, 502)
)

# Power zones from FTP 247 (tbr-2027-taavi-pall.json).
ZONES <- tribble(
  ~zone, ~lo, ~hi,
  "Z1",     0, 136,
  "Z2",   138, 185,
  "Z3",   188, 222,
  "Z4",   225, 259,
  "Z5",   262, 296
)
