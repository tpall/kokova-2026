# Kõkõva 900 (2026) — live weather along the route.
#
# Open-Meteo, 16-day daily + hourly forecast, no API key. The route is flat and
# coastal, so the numbers that decide the race are wind direction relative to
# travel and overnight rain, not elevation.
#
# Run: Rscript weather_forecast.R

suppressPackageStartupMessages({
  library(dplyr)
  library(tibble)
  library(purrr)
  library(tidyr)
  library(readr)
  library(httr2)
  library(jsonlite)
})

source("R/plan.R")

OUT_MD   <- file.path(DIR_REPORTS, "weather_forecast.md")
OUT_JSON <- file.path(DIR_OUTPUT,  "weather_forecast.json")

NIGHT_START_H       <- 23      # nights are short in August; riders roll late
NIGHT_END_H         <- 6
NIGHT_RAIN_ALERT_MM <- 3
GUST_ALERT_MS       <- 14      # exposed coastal roads get unpleasant here
# Only show waypoints near where the rider is expected to be on a given date,
# using an even split of the route over the control time.
RACE_DAYS_CONTROL       <- RACE_LIMIT_D
RELEVANCE_BUFFER_BEHIND <- 120
RELEVANCE_BUFFER_AHEAD  <- 320

# route_deg is baked into the CSV by prepare_route.R, so this script never
# parses the track.
waypoints <- read_csv(WAYPOINTS_CSV, show_col_types = FALSE)
stopifnot("route_deg" %in% names(waypoints))

TOTAL_KM        <- max(waypoints$km)
PACE_KM_PER_DAY <- TOTAL_KM / RACE_DAYS_CONTROL
RACE_START_DATE <- as.Date(RACE_START)

day_window <- function(date) {
  n <- as.integer(as.Date(date) - RACE_START_DATE) + 1L
  if (n < 1) return(c(0, Inf))
  c((n - 1) * PACE_KM_PER_DAY - RELEVANCE_BUFFER_BEHIND,
    min(n * PACE_KM_PER_DAY, TOTAL_KM) + RELEVANCE_BUFFER_AHEAD)
}

# ── Fetch ─────────────────────────────────────────────────────────────────────

fetch_forecast <- function(lat, lon, ele) {
  body <- request("https://api.open-meteo.com/v1/forecast") |>
    req_url_query(
      latitude = lat, longitude = lon, elevation = ele,
      wind_speed_unit = "ms",
      daily = paste(c("temperature_2m_max", "temperature_2m_min",
                      "precipitation_sum", "precipitation_probability_max",
                      "wind_speed_10m_max", "wind_gusts_10m_max",
                      "wind_direction_10m_dominant", "weather_code"), collapse = ","),
      hourly = paste(c("temperature_2m", "precipitation",
                       "wind_speed_10m", "wind_gusts_10m", "wind_direction_10m"), collapse = ","),
      forecast_days = 16, timezone = TZ) |>
    req_retry(max_tries = 3, backoff = ~5) |>
    req_perform() |>
    resp_body_json()

  # Open-Meteo returns ragged series — precipitation_probability_max stops short
  # of the 16th day while the other daily fields run the full length. Pad so the
  # columns bind into one tibble.
  pad <- function(x, n) {
    v <- unlist(lapply(x, function(z) if (is.null(z)) NA_real_ else z))
    if (length(v) < n) c(v, rep(NA_real_, n - length(v))) else v[seq_len(n)]
  }

  nd <- length(body$daily$time)
  daily <- tibble(
    date       = as.Date(unlist(body$daily$time)),
    tmin       = pad(body$daily$temperature_2m_min, nd),
    tmax       = pad(body$daily$temperature_2m_max, nd),
    precip_mm  = pad(body$daily$precipitation_sum, nd),
    precip_pct = pad(body$daily$precipitation_probability_max, nd),
    wind_ms    = pad(body$daily$wind_speed_10m_max, nd),
    gust_ms    = pad(body$daily$wind_gusts_10m_max, nd),
    wind_deg   = pad(body$daily$wind_direction_10m_dominant, nd),
    wcode      = pad(body$daily$weather_code, nd)
  )

  nh <- length(body$hourly$time)
  hourly <- tibble(
    # The explicit format matters: without it as.POSIXct drops the time and
    # every hour collapses to 00:00, which destroys the night aggregation.
    ts       = as.POSIXct(unlist(body$hourly$time), format = "%Y-%m-%dT%H:%M", tz = TZ),
    temp     = pad(body$hourly$temperature_2m, nh),
    precip   = pad(body$hourly$precipitation, nh),
    wind_ms  = pad(body$hourly$wind_speed_10m, nh),
    gust_ms  = pad(body$hourly$wind_gusts_10m, nh),
    wind_deg = pad(body$hourly$wind_direction_10m, nh)
  )
  list(daily = daily, hourly = hourly)
}

cat("Fetching forecasts from Open-Meteo for", nrow(waypoints), "waypoints ...\n")
fc <- waypoints |> rowwise() |> mutate(f = list(fetch_forecast(lat, lon, ele))) |> ungroup()

daily  <- fc |> mutate(d = map(f, "daily"))  |> select(-f) |> unnest(d)
hourly <- fc |> mutate(h = map(f, "hourly")) |> select(-f) |> unnest(h)

night <- hourly |>
  mutate(hour = as.integer(format(ts, "%H")),
         is_night = hour >= NIGHT_START_H | hour < NIGHT_END_H,
         # as.Date() on POSIXct defaults to UTC; pass tz so 00:00–01:59 local
         # does not roll back to the previous calendar day.
         night_date = if_else(hour < NIGHT_END_H,
                              as.Date(ts, tz = TZ) - 1, as.Date(ts, tz = TZ))) |>
  filter(is_night) |>
  group_by(name, km, night_date) |>
  # The last night in the window is truncated mid-way, leaving groups with no
  # readings at all; min() on those warns and returns Inf, so guard it.
  summarise(night_precip_mm = sum(precip, na.rm = TRUE),
            night_tmin      = if (all(is.na(temp))) NA_real_ else min(temp, na.rm = TRUE),
            night_hours_wet = sum(precip > 0, na.rm = TRUE),
            .groups = "drop") |>
  rename(date = night_date)

combined <- daily |>
  left_join(night, by = c("name", "km", "date")) |>
  mutate(wind_rel = wind_effect(route_deg, wind_deg))

write_json(list(generated_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
                waypoints = waypoints, forecast = combined),
           OUT_JSON, auto_unbox = TRUE, pretty = TRUE)
cat("Wrote", OUT_JSON, "(", nrow(combined), "rows )\n")

# ── Report ────────────────────────────────────────────────────────────────────

wcode_et <- function(code) case_when(
  code %in% 0:1   ~ "☀️ selge",
  code %in% 2:3   ~ "⛅ pilves",
  code %in% 45:48 ~ "🌫️ udu",
  code %in% 51:57 ~ "🌦️ uduvihm",
  code %in% 61:67 ~ "🌧️ vihm",
  code %in% 71:77 ~ "🌨️ lumi",
  code %in% 80:82 ~ "🌧️ hoovihm",
  code %in% 95:99 ~ "⛈️ äike",
  TRUE            ~ as.character(code))

compass <- function(deg) {
  # põhi, kirre, ida, kagu, lõuna, edel, lääs, loe
  pts <- c("P", "KI", "I", "KA", "L", "E", "LÄ", "LO")
  ifelse(is.na(deg), "—", pts[(floor((deg %% 360) / 45 + 0.5) %% 8) + 1])
}

race_dates <- seq(as.Date(RACE_START), as.Date(RACE_END), by = "day")
race_rows  <- combined |> filter(date %in% race_dates) |> arrange(date, km)
days_to    <- as.integer(as.Date(RACE_START) - Sys.Date())

md <- c(
  "# Kõkõva 900 · 2026 — ilmaprognoos rajal",
  "",
  sprintf("> Genereeritud **%s** · allikas [Open-Meteo](https://open-meteo.com) (16 päeva, tunniajaline lahutus)",
          format(Sys.time(), "%Y-%m-%d %H:%M %Z", tz = TZ)),
  "",
  sprintf("**Võistlusaken** %s → %s · **stardini %d päeva**",
          fmt_et(RACE_START), fmt_et(RACE_END), days_to),
  "",
  "Tuulesuund on antud rajasuuna suhtes: **vastu** (±45°), **külg**, **päri**.",
  "Rada on lauge ja lage — tuul on ainus reljeef, mis siin loeb.",
  "")

if (nrow(race_rows) == 0) {
  first_visible <- as.Date(RACE_START) - 15
  md <- c(md,
    "## ⏳ Võistluspäevad ei mahu veel 16-päevasesse prognoosiaknasse",
    "",
    sprintf("Esimene võistluspäev jõuab prognoosi **%s**. Seniks vaata kliimapõhist ülevaadet failis [`weather_outlook.md`](weather_outlook.md).",
            fmt_et(first_visible, with_time = FALSE)),
    "",
    "### Jälgitavad punktid",
    "",
    "Rajasuund on sõidusuund selles punktis — vastutuul on tuul, mis puhub täpselt sealtsamast.",
    "",
    "| km | Punkt | Rajasuund |",
    "|---:|-------|----------:|")
  for (i in seq_len(nrow(waypoints))) {
    w <- waypoints[i, ]
    md <- c(md, sprintf("| %.0f | %s | %.0f° (%s) |",
                        w$km, w$name, w$route_deg, compass(w$route_deg)))
  }
} else {
  for (d in sort(unique(race_rows$date))) {
    win <- day_window(d)
    day <- race_rows |> filter(date == d, km >= win[1], km <= win[2]) |> arrange(km)
    if (!nrow(day)) next
    md <- c(md, "",
      sprintf("## %s", fmt_et(as.Date(d, origin = "1970-01-01"), with_time = FALSE)),
      "",
      "| km | Punkt | Min °C | Max °C | Sadu mm (%) | **Öine sadu** | Öö min °C | Tuul / puhang m/s | Suund | Rajale | Ilm |",
      "|---:|-------|-------:|-------:|------------:|--------------:|----------:|------------------:|-------|--------|-----|")
    for (i in seq_len(nrow(day))) {
      w <- day[i, ]
      md <- c(md, sprintf(
        "| %.0f | %s | %.0f | %.0f | %.1f (%.0f) | %s | %s | %.0f / %.0f | %s | **%s** | %s |",
        w$km, w$name, w$tmin, w$tmax, w$precip_mm, w$precip_pct,
        if (is.na(w$night_precip_mm)) "—" else sprintf("**%.1f** (%dh)", w$night_precip_mm, w$night_hours_wet),
        if (is.na(w$night_tmin)) "—" else sprintf("%.0f", w$night_tmin),
        w$wind_ms, w$gust_ms, compass(w$wind_deg), w$wind_rel, wcode_et(w$wcode)))
    }
  }

  headwind <- race_rows |> filter(wind_rel == "vastu", wind_ms >= 6) |> arrange(date, km)
  if (nrow(headwind)) {
    md <- c(md, "",
      "## 💨 Vastutuule lõigud (≥6 m/s)",
      "",
      "| Kuupäev | km | Punkt | Tuul m/s | Puhang | Suund |",
      "|---------|---:|-------|---------:|-------:|-------|")
    for (i in seq_len(nrow(headwind))) {
      w <- headwind[i, ]
      md <- c(md, sprintf("| %s | %.0f | %s | %.0f | %.0f | %s |",
        fmt_et(as.Date(w$date, origin = "1970-01-01"), with_time = FALSE),
        w$km, w$name, w$wind_ms, w$gust_ms, compass(w$wind_deg)))
    }
  }

  wet <- race_rows |> filter(!is.na(night_precip_mm), night_precip_mm >= NIGHT_RAIN_ALERT_MM)
  if (nrow(wet)) {
    md <- c(md, "",
      sprintf("## 🌧️ Ööd sajuga ≥ %.0f mm", NIGHT_RAIN_ALERT_MM),
      "",
      "Oluline bivaki- ja magamisvarustuse valikuks.",
      "",
      "| Öö | km | Punkt | Sadu mm | Märgi tunde | Öö min °C |",
      "|----|---:|-------|--------:|------------:|----------:|")
    for (i in seq_len(nrow(wet))) {
      w <- wet[i, ]
      md <- c(md, sprintf("| %s | %.0f | %s | %.1f | %d | %.0f |",
        fmt_et(as.Date(w$date, origin = "1970-01-01"), with_time = FALSE),
        w$km, w$name, w$night_precip_mm, w$night_hours_wet, w$night_tmin))
    }
  }

  gusty <- race_rows |> filter(gust_ms >= GUST_ALERT_MS)
  if (nrow(gusty)) {
    md <- c(md, "",
      sprintf("## 🌬️ Tugevad puhangud (≥ %d m/s)", GUST_ALERT_MS), "",
      "| Kuupäev | km | Punkt | Puhang m/s | Suund | Rajale |",
      "|---------|---:|-------|-----------:|-------|--------|")
    for (i in seq_len(nrow(gusty))) {
      w <- gusty[i, ]
      md <- c(md, sprintf("| %s | %.0f | %s | %.0f | %s | %s |",
        fmt_et(as.Date(w$date, origin = "1970-01-01"), with_time = FALSE),
        w$km, w$name, w$gust_ms, compass(w$wind_deg), w$wind_rel))
    }
  }
}

md <- c(md, "", "---", "",
  "Generaator [`R/weather_forecast.R`](../R/weather_forecast.R) · toorandmed [`output/weather_forecast.json`](../output/weather_forecast.json) · ",
  "kliimataust [`weather_outlook.md`](weather_outlook.md) · praamid [`ferry_plan.md`](ferry_plan.md)",
  "")

writeLines(md, OUT_MD)
cat("Wrote", OUT_MD, "\n")
