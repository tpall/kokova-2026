# Kõkõva 900 (2026) — climatological outlook for the race window.
#
# The start is 14 August, so for most of the planning season the live 16-day
# forecast is empty. This fills that gap from ERA5 reanalysis (Open-Meteo
# archive): what mid-August actually does on this route, across the last decade.
#
# The headline number it produces is the expected share of the loop ridden into
# a headwind — computed by crossing the observed wind rose with the distribution
# of travel directions along the track, weighted by distance.
#
# Run: Rscript weather_outlook.R

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

OUT_MD   <- file.path(DIR_REPORTS, "weather_outlook.md")
OUT_JSON <- file.path(DIR_OUTPUT,  "weather_outlook.json")

YEARS   <- 2016:2025
MD_FROM <- "08-14"
MD_TO   <- "08-21"

# One request per anchor per year; keep the anchor list short enough that the
# whole run stays under a couple of minutes against the free archive API.
ANCHOR_KM <- c(0, 172.7, 195.2, 368.4, 438.7, 527, 692.2, 763.7)

# Both route geometry inputs come from the committed CSVs written by
# prepare_route.R, so this script never touches the track itself.
waypoints <- read_csv(WAYPOINTS_CSV, show_col_types = FALSE)
stopifnot("route_deg" %in% names(waypoints))
anchors   <- waypoints |> filter(km %in% ANCHOR_KM)

# ── ERA5 archive ──────────────────────────────────────────────────────────────

fetch_year <- function(lat, lon, year) {
  body <- request("https://archive-api.open-meteo.com/v1/archive") |>
    req_url_query(
      latitude = lat, longitude = lon,
      start_date = sprintf("%d-%s", year, MD_FROM),
      end_date   = sprintf("%d-%s", year, MD_TO),
      wind_speed_unit = "ms",
      hourly = paste(c("temperature_2m", "precipitation",
                       "wind_speed_10m", "wind_direction_10m"), collapse = ","),
      timezone = TZ) |>
    req_retry(max_tries = 3, backoff = ~5) |>
    req_perform() |>
    resp_body_json()

  n <- length(body$hourly$time)
  num <- function(x) unlist(lapply(x, function(z) if (is.null(z)) NA_real_ else z))[seq_len(n)]
  tibble(
    year     = year,
    ts       = as.POSIXct(unlist(body$hourly$time), format = "%Y-%m-%dT%H:%M", tz = TZ),
    temp     = num(body$hourly$temperature_2m),
    precip   = num(body$hourly$precipitation),
    wind_ms  = num(body$hourly$wind_speed_10m),
    wind_deg = num(body$hourly$wind_direction_10m)
  )
}

cat(sprintf("Fetching ERA5 for %d anchors x %d years ...\n", nrow(anchors), length(YEARS)))
obs <- anchors |>
  select(km, name, lat, lon, route_deg) |>
  rowwise() |>
  mutate(d = list(map_dfr(YEARS, ~ fetch_year(lat, lon, .x)))) |>
  ungroup() |>
  unnest(d)
cat("Hours fetched:", nrow(obs), "\n")

# ── Aggregates ────────────────────────────────────────────────────────────────

by_year <- obs |>
  mutate(date = as.Date(ts, tz = TZ)) |>
  group_by(km, name, year, date) |>
  summarise(tmax = max(temp, na.rm = TRUE), tmin = min(temp, na.rm = TRUE),
            rain = sum(precip, na.rm = TRUE), wind = mean(wind_ms, na.rm = TRUE),
            .groups = "drop")

per_point <- by_year |>
  group_by(km, name) |>
  summarise(tmax_med  = median(tmax), tmin_med = median(tmin),
            tmax_p90  = quantile(tmax, 0.9), tmin_p10 = quantile(tmin, 0.1),
            wet_share = mean(rain >= 1),
            rain_med  = median(rain), rain_p90 = quantile(rain, 0.9),
            wind_med  = median(wind), wind_p90 = quantile(wind, 0.9),
            .groups = "drop") |>
  arrange(km)

OCTANT <- c("P", "KI", "I", "KA", "L", "E", "LÄ", "LO")
oct_of <- function(deg) (floor((deg %% 360) / 45 + 0.5) %% 8) + 1

wind_rose <- obs |>
  filter(!is.na(wind_deg)) |>
  mutate(oct = OCTANT[oct_of(wind_deg)]) |>
  count(oct) |>
  mutate(share = n / sum(n)) |>
  arrange(desc(share))

# ── Expected headwind share of the loop ───────────────────────────────────────
# Travel direction is distance-weighted over the whole track, so a long straight
# on Saaremaa counts for more than a short zigzag. Crossing that with the wind
# rose gives the share of the ride spent on the nose for a typical mid-August.

# Travel direction is binned to whole degrees, not to the eight compass points.
# Binning both sides to octants puts the ±45° boundary exactly on a bin centre,
# which pushes the two neighbouring octants into "vastu" while leaving only the
# single opposing octant as "päri" — a closed loop then reports 37% headwind and
# 13% tailwind instead of the ~25/25 it must be by symmetry.
dir_deg <- read_csv(ROUTE_DIRECTIONS_CSV, show_col_types = FALSE) |>
  mutate(share = km / sum(km))

rel_share <- function(wind_deg) {
  d <- abs(((wind_deg - dir_deg$deg + 180) %% 360) - 180)
  tibble(vastu = sum(dir_deg$share[d <= 45]),
         kylg  = sum(dir_deg$share[d > 45 & d <= 135]),
         pari  = sum(dir_deg$share[d > 135]))
}

# Octant shares for display, but each octant's exposure is evaluated against the
# observed wind directions inside it, not against the octant centre.
exposure <- wind_rose |>
  rowwise() |>
  mutate(r = list(rel_share((match(oct, OCTANT) - 1) * 45))) |>
  ungroup() |>
  unnest(r)

# Expected exposure uses every observed hour, so no binning enters the headline.
expected <- obs |>
  filter(!is.na(wind_deg)) |>
  pull(wind_deg) |>
  round() |>
  table() |>
  (\(tb) tibble(deg = as.numeric(names(tb)), p = as.numeric(tb) / sum(tb)))() |>
  rowwise() |>
  mutate(r = list(rel_share(deg))) |>
  ungroup() |>
  unnest(r) |>
  summarise(vastu = sum(p * vastu), kylg = sum(p * kylg), pari = sum(p * pari))

dir_weight <- dir_deg |>
  mutate(oct = oct_of(deg)) |>
  group_by(oct) |>
  summarise(km = sum(km), share = sum(share), .groups = "drop")

write_json(list(generated_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
                years = YEARS, window = c(MD_FROM, MD_TO),
                per_point = per_point, wind_rose = wind_rose,
                direction_weight = dir_weight, expected_exposure = expected),
           OUT_JSON, auto_unbox = TRUE, pretty = TRUE)
cat("Wrote", OUT_JSON, "\n")

# ── Report ────────────────────────────────────────────────────────────────────

md <- c(
  "# Kõkõva 900 · 2026 — kliimaülevaade (14.–21. august)",
  "",
  sprintf("> Genereeritud **%s** · allikas ERA5 reanalüüs [Open-Meteo Archive](https://open-meteo.com) · aastad %d–%d",
          format(Sys.time(), "%Y-%m-%d %H:%M %Z", tz = TZ), min(YEARS), max(YEARS)),
  "",
  "Mida augusti keskpaik sellel rajal tavaliselt teeb. Elav prognoos on failis [`weather_forecast.md`](weather_forecast.md) — see täitub, kui start jõuab 16-päevasesse aknasse.",
  "",
  "## Tüüpiline päev punktide kaupa",
  "",
  "Mediaan üle kümne aasta; sulgudes harvem, aga arvestatav äärmus (max p90 / min p10).",
  "",
  "| km | Punkt | Max °C | Min °C | Vihmase päeva tõenäosus | Sadu mm (p90) | Tuul m/s (p90) |",
  "|---:|-------|-------:|-------:|------------------------:|--------------:|---------------:|")
for (i in seq_len(nrow(per_point))) {
  p <- per_point[i, ]
  md <- c(md, sprintf("| %.0f | %s | %.0f (%.0f) | %.0f (%.0f) | %.0f%% | %.1f (%.1f) | %.1f (%.1f) |",
                      p$km, p$name, p$tmax_med, p$tmax_p90, p$tmin_med, p$tmin_p10,
                      100 * p$wet_share, p$rain_med, p$rain_p90, p$wind_med, p$wind_p90))
}

md <- c(md, "",
  "## Tuuleroos — kust augusti keskel puhub",
  "",
  "| Suund | Osakaal tundidest | Selle tuulega rajast vastu | külg | päri |",
  "|-------|------------------:|---------------------------:|-----:|-----:|")
for (i in seq_len(nrow(exposure))) {
  e <- exposure[i, ]
  md <- c(md, sprintf("| %s | %.0f%% | %.0f%% | %.0f%% | %.0f%% |",
                      e$oct, 100 * e$share, 100 * e$vastu, 100 * e$kylg, 100 * e$pari))
}

md <- c(md, "",
  "## Oodatav tuuleekspositsioon kogu ringil",
  "",
  sprintf("Tuuleroosi ja rajasuundade ristkorrutis (kaugusega kaalutud): **%.0f%% vastutuult, %.0f%% külgtuult, %.0f%% pärituult**.",
          100 * expected$vastu, 100 * expected$kylg, 100 * expected$pari),
  "",
  "Ring on suletud, nii et vastu- ja pärituul enam-vähem tasakaalustuvad — aga rada pole sümmeetriline ja lõigud on pikad, nii et päev võib kergesti minna valesse otsa. Pikimad ühesuunalised lõigud:",
  "",
  "| Sõidusuund | Osa rajast |",
  "|------------|-----------:|")
for (i in order(-dir_weight$share)) {
  d <- dir_weight[i, ]
  md <- c(md, sprintf("| %s (%.0f°) | %.0f%% (%.0f km) |",
                      OCTANT[d$oct], (d$oct - 1) * 45, 100 * d$share, d$km))
}

md <- c(md, "", "---", "",
  "Generaator [`R/weather_outlook.R`](../R/weather_outlook.R) · toorandmed [`output/weather_outlook.json`](../output/weather_outlook.json) · ",
  "elav prognoos [`weather_forecast.md`](weather_forecast.md) · praamid [`ferry_plan.md`](ferry_plan.md)",
  "")

writeLines(md, OUT_MD)
cat("Wrote", OUT_MD, "\n")
