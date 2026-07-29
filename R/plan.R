# Kõkõva 900 (2026) — shared parameters, route pipeline and ferry-aware pacing model.
#
# Sourced by ferry_plan.R and weather_forecast.R. Running it standalone prints a
# route summary and the predicted ferry connections for each rider profile.

suppressPackageStartupMessages({
  library(dplyr)
  library(tibble)
  library(purrr)
  library(readr)
  library(xml2)
})

invisible(Sys.setlocale("LC_TIME", "C"))

# ── Race facts ────────────────────────────────────────────────────────────────

TZ           <- "Europe/Tallinn"
RACE_START   <- as.POSIXct("2026-08-14 21:00:00", tz = TZ)
RACE_LIMIT_D <- 7
RACE_END     <- RACE_START + RACE_LIMIT_D * 86400   # Fri 21 Aug 21:00

# The first 11 km out of Hundipea are neutralised behind the race director at
# 20–25 km/h (manual p. 2), so every profile covers them in the same half hour.
NEUTRAL_KM <- 11
NEUTRAL_H  <- 0.5

# All paths are relative to the project root — scripts are run from there, either
# directly (`Rscript R/ferry_schedule.R`) or via the Makefile.
DIR_DATA    <- "data"      # route definition: the track, and geometry derived from it
DIR_OUTPUT  <- "output"    # machine-readable results, regenerated on every run
DIR_REPORTS <- "reports"   # the human-facing markdown

# The organiser ships the final route as three RideWithGPS parts (renamed from
# "N-3_(900…)_KÕKÕVA-26.gpx" — the originals carry ":" and "()", which break
# make prerequisites). prepare_route.R concatenates them into TRACK_FILE, and
# that merged file is what everything else reads — resupply.R, surface.R and
# the vendored gpsweather engine — so the daily job never parses the ~20 500
# track points, and outlook.py gets the single GPX path it expects.
GPX_PARTS            <- file.path(DIR_DATA, sprintf("kokova_2026_900_final_%d.gpx", 1:3))
TRACK_FILE           <- file.path(DIR_DATA, "kokova_2026_900_final.gpx")
WAYPOINTS_CSV        <- file.path(DIR_DATA, "waypoints.csv")
ROUTE_DIRECTIONS_CSV <- file.path(DIR_DATA, "route_directions.csv")
TOTAL_ROUTE_KM       <- 986.3   # includes the ferry legs; refresh via prepare_route.R

# ── Route geometry ────────────────────────────────────────────────────────────
# The final track's parts split at CP1 (Paluküla) and at the Kuivastu quay, not
# at the ferries: Rohuküla–Heltermaa and Sõru–Triigi are drawn straight across
# the water inside the track, interpolated at ~100 m steps, and only
# Kuivastu–Virtsu is a real gap between parts (6.7 km in one step). All three
# are declared in FERRIES so the pacing model never "rides" across water — and
# route_directions.csv drops the two drawn crossings by km range, because no
# step-length filter can tell a 100 m step at sea from one on land.

haversine <- function(lat1, lon1, lat2, lon2) {
  R <- 6371000; p <- pi / 180
  a <- sin((lat2 - lat1) * p / 2)^2 +
       cos(lat1 * p) * cos(lat2 * p) * sin((lon2 - lon1) * p / 2)^2
  2 * R * asin(pmin(1, sqrt(a)))
}

read_track <- function(gpx = TRACK_FILE) {
  x  <- read_xml(gpx)
  ns <- xml_ns(x)
  pt <- xml_find_all(x, "//d1:trkpt", ns)
  trk <- tibble(
    lon = as.numeric(xml_attr(pt, "lon")),
    lat = as.numeric(xml_attr(pt, "lat")),
    ele = xml_double(xml_find_first(pt, "./d1:ele", ns))
  )
  step <- c(0, haversine(head(trk$lat, -1), head(trk$lon, -1),
                         tail(trk$lat, -1), tail(trk$lon, -1)))
  trk |>
    mutate(step = step, km = cumsum(step) / 1000)
}

# Direction of travel at a given km, averaged over a window of the track. The
# route is a loop around flat, exposed coastline, so whether the wind is on the
# nose or the back matters more than any climb on it — this is what lets the
# forecast be reported as head/tail/cross wind instead of a bare bearing.

bearing <- function(lat1, lon1, lat2, lon2) {
  p <- pi / 180
  y <- sin((lon2 - lon1) * p) * cos(lat2 * p)
  x <- cos(lat1 * p) * sin(lat2 * p) - sin(lat1 * p) * cos(lat2 * p) * cos((lon2 - lon1) * p)
  (atan2(y, x) / p) %% 360
}

route_bearing <- function(trk, km, window_km = 10) {
  vapply(km, function(k) {
    seg <- trk |> filter(km >= k - window_km / 2, km <= k + window_km / 2)
    if (nrow(seg) < 2) return(NA_real_)
    # Average unit vectors so the mean of e.g. 350° and 10° comes out as 0°.
    b <- bearing(head(seg$lat, -1), head(seg$lon, -1), tail(seg$lat, -1), tail(seg$lon, -1))
    w <- tail(seg$step, -1)
    p <- pi / 180
    (atan2(sum(sin(b * p) * w), sum(cos(b * p) * w)) / p) %% 360
  }, numeric(1))
}

# Wind direction in Open-Meteo is the direction the wind blows *from*. A rider
# heading 90° into a wind from 90° has it straight on the nose.
wind_effect <- function(route_deg, wind_from_deg) {
  d <- abs(((wind_from_deg - route_deg + 180) %% 360) - 180)
  case_when(
    is.na(d)  ~ "—",
    d <=  45  ~ "vastu",
    d <= 135  ~ "külg",
    TRUE      ~ "päri"
  )
}

# Ferry legs, keyed by the km at which the rider reaches the departure quay.
#
# `onboard` is a resupply column, not trivia. TS Laevad run a hot-food
# restaurant (Take Off) and an R-Kiosk on all five of their vessels, with no
# published restriction on early or late sailings — which makes the 75-minute
# Hiiumaa crossing the single best eating opportunity on the route, and the one
# resupply that is open at 06:30 on a Saturday when every island shop is shut.
# The race manual (p. 4) says supplies can be bought on all ferries, Soela
# included — but 35 minutes and a small vessel make it a top-up, not a meal.
FERRIES <- tribble(
  ~leg,       ~from,        ~to,          ~km_from, ~km_to, ~crossing_min, ~operator,        ~source,       ~onboard,
  "ROH-HEL",  "Rohuküla",   "Heltermaa",     172.7,  195.2,            75, "TS Laevad",      "praamid.ee",  "restoran + R-Kiosk",
  "SOR-TRI",  "Sõru",       "Triigi",        368.4,  383.1,            35, "Kihnu Veeteed",  "veeteed.com", "väike müük (juhend)",
  "KUI-VIR",  "Kuivastu",   "Virtsu",        692.2,  699.7,            27, "TS Laevad",      "praamid.ee",  "restoran + R-Kiosk"
)

# ── Rider profiles ────────────────────────────────────────────────────────────
# moving_kmh  — speed while actually turning the pedals (60% of the route is
#               forest/gravel, so this sits well below road-bike numbers)
# push_kmh    — moving speed on the opening leg, which the rider reports is
#               largely asphalt. The whole-race average understates it, and the
#               opening leg is the one that decides the ferry, so it gets its
#               own figure rather than a derating of a gravel number.
# stop_frac   — share of riding time lost to resupply, kit faff, punctures
# push_frac   — the same, but during the opening push before the first sleep,
#               when riders stop for almost nothing. This is not a refinement:
#               the opening push is what decides which Sõru ferry you make, and
#               a single whole-race stop fraction understates it badly. The
#               rider's own 2025 ride covered 349 km in 17.85 h elapsed off the
#               start — 19.6 km/h including stops against 18.5 km/h moving, so
#               barely 6% of that leg was spent stationary.
# sleep_h     — hours of sleep taken per night
# sleep_from  — clock hour at which the rider stops for the night
# first_night — TRUE if the rider sleeps during the first (21:00 start) night

PROFILES <- tribble(
  ~profile,      ~moving_kmh, ~push_kmh, ~stop_frac, ~push_frac, ~sleep_h, ~sleep_from, ~first_night,
  "Terav ots",          25.0,      28.0,       0.10,       0.04,      3.5,          3L,       FALSE,
  "Keskmik",            21.0,      23.5,       0.16,       0.07,      5.0,          2L,       FALSE,
  "Lõpetaja",           17.5,      19.5,       0.22,       0.12,      7.0,          1L,        TRUE,
  "Limiidi peal",       14.0,      15.5,       0.30,       0.18,      8.0,         23L,        TRUE,
  # Calibrated to the rider's own ~937 km Estonian ride of 15–19 Aug 2025:
  # 18.5 km/h moving, 39.1 h stopped, first night ridden straight through
  # (349 km off a 20:48 start). Same event, different course — 2025 was southern
  # and eastern Estonia with ~5× the climbing and no ferries — so these are
  # rider capability numbers, not a transferable finish time. See R/athlete.R.
  "Taavi 2025 tempo",   18.5,      20.5,       0.28,       0.06,      6.0,          2L,       FALSE,
  # Same shape, derated for the current detrained state: chronic load sits at
  # ~39% of the April peak with 13 days off the bike as of 26 Jul.
  "Taavi 2026 ootus",   16.5,      19.0,       0.32,       0.10,      6.0,          2L,       FALSE
)

# Estonian weekday abbreviations — LC_TIME is pinned to "C" so that parsing the
# English praamid.ee pages is locale-independent, which means %a would print
# "Fri" in a report that is otherwise in Estonian.
ET_WDAY <- c("esmasp.", "teisip.", "kolmap.", "neljap.", "reede", "laup.", "pühap.")
ET_ABBR <- c("E", "T", "K", "N", "R", "L", "P")

# Estonian writes the decimal separator as a comma.
num_et <- function(x, digits = 1) sub("\\.", ",", sprintf(paste0("%.", digits, "f"), x))

fmt_et <- function(x, with_time = TRUE) {
  wd <- ET_ABBR[as.integer(format(x, "%u"))]
  paste0(wd, " ", format(x, if (with_time) "%d.%m %H:%M" else "%d.%m"))
}

# ── Pacing simulation ─────────────────────────────────────────────────────────
# Walks the route km by km. Riding advances the clock at the effective speed
# (moving speed derated by the stop fraction); at a ferry quay the rider waits
# for the next sailing in `sailings`, crosses, and continues. Sleep is taken at
# the profile's hour, but never while sitting in a ferry queue — a wait longer
# than the sleep allowance is used for sleeping instead.

next_sailing <- function(sailings, leg_code, after) {
  s <- sailings |>
    filter(leg == leg_code, depart >= after) |>
    arrange(depart)
  if (nrow(s) == 0) return(NULL)
  s[1, ]
}

simulate <- function(prof, sailings, total_km = TOTAL_ROUTE_KM) {
  trk_km   <- total_km
  # Stops are rare until the first sleep, then settle at the whole-race rate.
  eff_now  <- function(slept) {
    if (slept == 0L) prof$push_kmh * (1 - prof$push_frac)
    else             prof$moving_kmh * (1 - prof$stop_frac)
  }
  # The neutralised opening is the same half hour for everyone: the group rides
  # the first 11 km behind the race director, so no profile's own speed applies.
  now      <- RACE_START + NEUTRAL_H * 3600
  km       <- NEUTRAL_KM
  slept    <- 0                       # nights of sleep already taken
  log      <- list()

  ferry_km <- sort(FERRIES$km_from)

  repeat {
    # next event: a ferry quay, or the finish
    nxt_ferry <- ferry_km[ferry_km > km + 1e-6]
    target    <- if (length(nxt_ferry)) nxt_ferry[1] else trk_km
    leg_km    <- target - km

    # Ride to the target, inserting nights of sleep along the way.
    while (leg_km > 1e-6) {
      eff           <- eff_now(slept)
      hrs_to_target <- leg_km / eff
      # when does the next sleep start?
      d0        <- as.Date(now, tz = TZ)
      cand      <- as.POSIXct(sprintf("%s %02d:00:00", d0, prof$sleep_from), tz = TZ)
      if (cand <= now) cand <- cand + 86400
      night_idx <- slept + 1L
      skip_1st  <- (!prof$first_night && night_idx == 1L &&
                    as.numeric(difftime(cand, RACE_START, units = "hours")) < 12)
      if (skip_1st) {
        cand  <- cand + 86400
      }
      hrs_to_sleep <- as.numeric(difftime(cand, now, units = "hours"))

      if (hrs_to_sleep < hrs_to_target) {
        km      <- km + hrs_to_sleep * eff
        leg_km  <- target - km
        now     <- cand + prof$sleep_h * 3600
        slept   <- slept + 1L
        log[[length(log) + 1]] <- tibble(
          event = "sleep", km = km, time = cand, until = now, detail = sprintf("%.1f h", prof$sleep_h)
        )
      } else {
        now    <- now + hrs_to_target * 3600
        km     <- target
        leg_km <- 0
      }
    }

    if (km >= trk_km - 1e-6) break

    f <- FERRIES |> filter(abs(km_from - km) < 1e-6)
    s <- next_sailing(sailings, f$leg, now)
    if (is.null(s)) {
      log[[length(log) + 1]] <- tibble(event = "ferry_missed", km = km, time = now,
                                       until = now, detail = paste(f$from, "— no sailing in data"))
      break
    }
    wait_h <- as.numeric(difftime(s$depart, now, units = "hours"))
    log[[length(log) + 1]] <- tibble(
      event  = "ferry", km = km, time = now, until = s$depart + f$crossing_min * 60,
      detail = sprintf("%s→%s %s (ootamine %.1f h)", f$from, f$to,
                       fmt_et(s$depart), wait_h)
    )
    now <- s$depart + f$crossing_min * 60
    km  <- f$km_to
    # A long ferry wait doubles as a sleep opportunity.
    if (wait_h >= prof$sleep_h) slept <- slept + 1L
  }

  list(
    profile   = prof$profile,
    finish    = now,
    elapsed_h = as.numeric(difftime(now, RACE_START, units = "hours")),
    log       = bind_rows(log)
  )
}

# ── Standalone summary ────────────────────────────────────────────────────────

if (sys.nframe() == 0) {
  cat(sprintf("Route: %.1f km total (incl. ferry legs)\n", TOTAL_ROUTE_KM))
  cat(sprintf("Race:  %s → %s (%d days)\n",
              format(RACE_START, "%a %d %b %Y %H:%M"),
              format(RACE_END,   "%a %d %b %Y %H:%M"), RACE_LIMIT_D))
  print(FERRIES |> select(leg, from, to, km_from, crossing_min, source))
}
