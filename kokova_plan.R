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

# The KMZ is the organiser's unreleased BETA track and is not committed. Only
# prepare_route.R reads it; everything else uses the two derived CSVs below, so
# the repo is self-contained without the track file.
KMZ_FILE             <- "kokova_2026_900_beta.kmz"
WAYPOINTS_CSV        <- "waypoints.csv"
ROUTE_DIRECTIONS_CSV <- "route_directions.csv"
TOTAL_ROUTE_KM       <- 984.6   # includes the ferry legs; refresh via prepare_route.R

# ── Route geometry ────────────────────────────────────────────────────────────
# The KMZ holds three LineStrings. Two of the three ferry crossings appear as a
# gap between segments (the KML simply stops at one quay and resumes at the
# other); the Sõru–Triigi crossing is drawn as a straight line inside segment 2.
# Both kinds are marked as ferry legs below so the pacing model never "rides"
# across water.

haversine <- function(lat1, lon1, lat2, lon2) {
  R <- 6371000; p <- pi / 180
  a <- sin((lat2 - lat1) * p / 2)^2 +
       cos(lat1 * p) * cos(lat2 * p) * sin((lon2 - lon1) * p / 2)^2
  2 * R * asin(pmin(1, sqrt(a)))
}

read_track <- function(kmz = KMZ_FILE) {
  tmp <- tempfile(); dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  utils::unzip(kmz, exdir = tmp)
  kml <- read_xml(list.files(tmp, pattern = "\\.kml$", full.names = TRUE)[1])
  ns  <- xml_ns(kml)

  segs <- map(xml_find_all(kml, "//d1:Placemark", ns), function(p) {
    nm   <- xml_text(xml_find_first(p, ".//d1:name", ns))
    toks <- strsplit(trimws(xml_text(xml_find_first(p, ".//d1:coordinates", ns))), "\\s+")[[1]]
    m    <- do.call(rbind, lapply(strsplit(toks, ","), function(z) as.numeric(z[1:3])))
    tibble(seg = nm, lon = m[, 1], lat = m[, 2], ele = m[, 3])
  })

  trk <- bind_rows(segs)
  step <- c(0, haversine(head(trk$lat, -1), head(trk$lon, -1),
                         tail(trk$lat, -1), tail(trk$lon, -1)))
  # A jump between two consecutive points larger than this is a segment break,
  # i.e. a quay-to-quay ferry gap rather than a rideable stretch.
  step[step > 3000 & c(FALSE, diff(as.integer(factor(trk$seg))) != 0)] -> ferry_steps
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
FERRIES <- tribble(
  ~leg,       ~from,        ~to,          ~km_from, ~km_to, ~crossing_min, ~operator,        ~source,
  "ROH-HEL",  "Rohuküla",   "Heltermaa",     181.6,  204.2,            75, "TS Laevad",      "praamid.ee",
  "SOR-TRI",  "Sõru",       "Triigi",        316.5,  331.2,            35, "Kihnu Veeteed",  "veeteed.com",
  "KUI-VIR",  "Kuivastu",   "Virtsu",        698.5,  705.9,            27, "TS Laevad",      "praamid.ee"
)

# ── Rider profiles ────────────────────────────────────────────────────────────
# moving_kmh  — speed while actually turning the pedals (60% of the route is
#               forest/gravel, so this sits well below road-bike numbers)
# stop_frac   — share of riding time lost to resupply, kit faff, punctures
# sleep_h     — hours of sleep taken per night
# sleep_from  — clock hour at which the rider stops for the night
# first_night — TRUE if the rider sleeps during the first (21:00 start) night

PROFILES <- tribble(
  ~profile,      ~moving_kmh, ~stop_frac, ~sleep_h, ~sleep_from, ~first_night,
  "Terav ots",          25.0,       0.10,      3.5,          3L,       FALSE,
  "Keskmik",            21.0,       0.16,      5.0,          2L,       FALSE,
  "Lõpetaja",           17.5,       0.22,      7.0,          1L,        TRUE,
  "Limiidi peal",       14.0,       0.30,      8.0,         23L,        TRUE
)

# Estonian weekday abbreviations — LC_TIME is pinned to "C" so that parsing the
# English praamid.ee pages is locale-independent, which means %a would print
# "Fri" in a report that is otherwise in Estonian.
ET_WDAY <- c("esmasp.", "teisip.", "kolmap.", "neljap.", "reede", "laup.", "pühap.")
ET_ABBR <- c("E", "T", "K", "N", "R", "L", "P")

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
  eff_kmh  <- prof$moving_kmh * (1 - prof$stop_frac)
  now      <- RACE_START
  km       <- 0
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
      hrs_to_target <- leg_km / eff_kmh
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
        km      <- km + hrs_to_sleep * eff_kmh
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
