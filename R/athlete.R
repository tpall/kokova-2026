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

  # ── Current form ────────────────────────────────────────────────────────────
  # The Garmin load/HRV figures are from the 24 Jul sync and predate the recon
  # block — refresh them at the next sync; the ride facts below are current.
  chronic_load     = 323,   # Garmin 28-day chronic load, 24 Jul — pre-recon
  chronic_peak     = 833,   # 2026 peak, 18 Apr
  hrv_recent       = 61,    # weekly average, 22–24 Jul; 2026 mean is 59.8
  days_off_bike    = 0,     # recon block 30–31 Jul; before it, none since 13 Jul
  training_status  = "DETRAINING",   # 24 Jul label; the recon block will move it
  longest_ride_since_race_km = 225,  # 30 Jul: 157 km recon + 68 km on to camp, one day, loaded

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
  # it was set on twice the climbing (2026 manual: ~4000 m) — but the 2026
  # route is ~46% gravel/dirt, which cuts the other way. That tension was the
  # plan's largest uncertainty until the 30 Jul recon (below) measured the
  # opening leg on the actual track.
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

  # ── Recon 30 Jul 2026: the opening leg, measured on the final track ─────────
  # Front door → Rohuküla quay along the race route, ~13:15 start after a
  # proper lunch, loaded bike, 15 days out and a day after a head cold. THE
  # FILE IS GONE — the Edge 1040 activity was discarded by accident — so every
  # figure here is from memory and rounded, and there is no moving/stopped
  # split, no HR and no power. The elapsed pace is the number the ferry gate
  # runs on, and that one survived in the rider's head.
  recon = list(
    date        = as.Date("2026-07-30"),
    depart      = "~13:15",   # → quay ~20:25; all daylight, shops open throughout
    # Pre-ride lunch: 2 boiled potatoes + chicken half-leg with white sauce —
    # a real meal ~0 h before rolling. Race-day analogue exists: the organiser
    # serves dinner at 19:00, two hours before the 21:00 gun.
    km          = 157,    # door → quay on the final track (race: 172.7 from Hundipea)
    elapsed_h   = 7.2,    # "a little more than 7 hours"
    avg_kmh     = 21.8,   # the last average the rider saw on the Edge — that
                          # field is timer-based, i.e. essentially a moving
                          # average. With the few short stops the elapsed pace
                          # is ~21.0–21.8. Daytime with shops open — read a few
                          # % optimistic vs the race's night run either way.
    # Race translation: the missing Hundipea start adds the 11 km neutralised
    # roll (~0.5 h) plus ~5 km at own pace — call it +0.9 h. ~8.1 h gun-to-quay
    # lands ~05:05, roughly 70 min inside the 06:15 target for the 06:30 boat.
    stops       = "Keila Alexela 24h (shop stop), a few short pastry stops; rolled past Risti Circle K",
    # First logged intake ever (carbs_tested below): bought 4 × 70 g cinnamon
    # rolls (~160 g carbs) + 0.5 L regular cola (~53 g), plus ~1 L bottle with
    # 1 tsp hydration mix + 4–5 tsp sugar (~20 g). Carried 8 × 50 g Kalev bars
    # and trail mix, consumed amount not recorded. Known intake ≈ 32 g/h;
    # everything carried ≈ 68 g/h — short of the 90 g/h target either way.
    carb_g_h_est = c(32, 68),
    # First hydration log ever, too: ~2.6 L total (mix bottle + 0.5 L cola +
    # 1.1 L water, refilled in Keila) over 7.2 h ≈ 360 ml/h. That matches the
    # lower end of the TBR-measured sweat rate (345–502 ml/h), which is the
    # sensible figure for a cool Estonian day — drinking was adequate for the
    # conditions, unlike the carbs. In an August warm spell the 500+ ml/h end
    # of the band applies and remains unpractised.
    fluid_ml_h_est = 360,
    # The ride did not end at the quay: another ~68 km on to a campsite the
    # same evening (day 1 ≈ 225 km loaded), and ~90 km home on 31 Jul. Those
    # two legs ARE on record — watch-tracked, uploaded to Garmin Connect
    # (68 km full; 75 of the ~90 km, until the watch battery died) — so HR and
    # pace for them can be pulled at the next sync. Together the block is the
    # back-to-back loaded weekend the TBR debrief demanded (durability,
    # power-after-fatigue), ridden on and around the actual course.
    day1_total_km = 225,
    day2_km       = 90,   # ~75 km watch-recorded, remainder untracked
    # Garmin's recovery advisor asked for 95 h after day 1 — near its 96 h
    # ceiling. Read together with the pace: top-end speed is intact, but on
    # ~39% of peak chronic load a big day costs close to the maximum the
    # scale shows. This is the measured argument for keeping the multi-day
    # moving speed derated (17.5 vs 2025's 18.5) even though the opening push
    # came out faster than 2025.
    recovery_req_h = 95
    # Conditions and how it felt, day by day (memory):
    # D1: light-to-moderate headwind most of the way and false flat; hardest
    #     stretches were the gravel/dirt before and after Keila; legs already
    #     sour at halfway, the day after the cold. The 21.8 average carries
    #     all of that, which strengthens the gate conclusion — calm air and
    #     healthy legs only add margin. Coastal drop made the last km fast;
    #     the evening leg to camp felt fine.
    # D2: tailwind to Padise/Klooga-Ranna, then 29 °C and headwind home.
    #     Breakfast carried from Haapsalu: 2 sandwiches, ~100 g pancakes with
    #     orange jam (jam bought in a glass jar the day before), a banana,
    #     0.5 L cola. Madise: 0.5 L alcohol-free beer + 80 g snacks
    #     (~470 kcal/100 g). Feeling good, he SKIPPED the planned Padise
    #     lunch — and bonked after Tabasalu ~2 h later, rescued by 2 × 50 g
    #     bars; the last 10 km crawled. Textbook eat-by-clock-not-by-feel.
    # Position: by the end of day 2 he could no longer hold a good riding
    # position and picked up light saddle sores — flagged for a pre-race fit
    # check (the 90 mm stem may be long) and a chamois-cream line on the kit
    # list. Part of this is simply end-of-block fatigue on a low base.
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
  # The 90 g/h is a plan target written for TBR 2027. Until 30 Jul the training
  # project contained no logged intake of any kind; the recon above is the
  # first data point — an estimated 30–65 g/h, from memory — so the full-dose
  # target is still unrehearsed. Treat 90 g/h as a target, not a tolerance.
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
