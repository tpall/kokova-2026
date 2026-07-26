# Kõkõva 900 (2026) — ferry schedules for the three crossings on the route.
#
#   Rohuküla → Heltermaa   TS Laevad       praamid.ee   (published timetable)
#   Sõru     → Triigi      Kihnu Veeteed   veeteed.com  (live booking inventory)
#   Kuivastu → Virtsu      TS Laevad       praamid.ee   (published timetable)
#
# Writes ferries.json (machine-readable) and ferry_plan.md (the human report,
# including the recommended sailing for each rider profile).
#
# Run: Rscript ferry_schedule.R

suppressPackageStartupMessages({
  library(dplyr)
  library(tibble)
  library(purrr)
  library(tidyr)
  library(xml2)
  library(httr2)
  library(jsonlite)
})

source("R/plan.R")

OUT_JSON <- file.path(DIR_OUTPUT,  "ferries.json")
OUT_MD   <- file.path(DIR_REPORTS, "ferry_plan.md")

UA <- "kokova-2026-route-planner/1.0 (+https://www.panepanepane.ee/k6k6va)"

# Dates we care about: the race window plus a day either side.
WINDOW <- seq(as.Date(RACE_START) - 1, as.Date(RACE_END) + 1, by = "day")

DAY_LETTER <- c("E", "T", "K", "N", "R", "L", "P")   # Mon..Sun, Estonian

# ── praamid.ee: published timetables ──────────────────────────────────────────
# Each route page carries one table per validity period, in the same order as
# the period labels in the period picker. Cells read like "E06:30" — the weekday
# letter is repeated inside every cell, which is what makes the grid parseable
# without tracking column positions.

MONTHS_EN <- c(january = 1, february = 2, march = 3, april = 4, may = 5, june = 6,
               july = 7, august = 8, september = 9, october = 10, november = 11, december = 12)

parse_period <- function(label) {
  # "13. july - 16. august 2026"
  m <- regmatches(label, regexec(
    "^([0-9]{1,2})\\. ([a-z]+) *(?:([0-9]{4}))? *[-–] *([0-9]{1,2})\\. ([a-z]+) *([0-9]{4})$",
    tolower(trimws(label))))[[1]]
  if (length(m) != 7) return(NULL)
  y2 <- as.integer(m[7])
  y1 <- if (nzchar(m[4])) as.integer(m[4]) else y2
  list(from = as.Date(sprintf("%d-%02d-%02d", y1, MONTHS_EN[[m[3]]], as.integer(m[2]))),
       to   = as.Date(sprintf("%d-%02d-%02d", y2, MONTHS_EN[[m[6]]], as.integer(m[5]))))
}

praamid_timetable <- function(url, port) {
  html  <- request(url) |>
    req_user_agent(UA) |>
    req_retry(max_tries = 3, backoff = ~5) |>
    req_perform() |>
    resp_body_string() |>
    read_html()

  nodes <- xml_find_all(html, paste0(
    "//*[self::h1 or self::h2 or self::h3 or self::h4 or self::h5",
    " or self::table or self::li or self::button or self::option]"))

  in_section <- FALSE; periods <- character(0); tno <- 0L
  out <- list()

  for (n in nodes) {
    tag <- xml_name(n)
    txt <- trimws(gsub("[[:space:]]+", " ", xml_text(n)))

    if (tag %in% c("h1", "h2", "h3", "h4", "h5")) {
      if (grepl("Planned departures", txt, fixed = TRUE)) {
        in_section <- grepl(port, txt, fixed = TRUE)
        periods <- character(0); tno <- 0L
      }
    } else if (tag %in% c("li", "button", "option")) {
      if (grepl("^[0-9]{1,2}\\. [a-z]+ *[0-9]{0,4} *[-–] *[0-9]{1,2}\\. [a-z]+ [0-9]{4}$",
                tolower(txt))) {
        periods <- c(periods, txt)
      }
    } else if (tag == "table" && in_section) {
      tno <- tno + 1L
      if (tno > length(periods)) next
      p <- parse_period(periods[tno])
      if (is.null(p)) next
      cells <- trimws(gsub("[[:space:]]+", " ", xml_text(xml_find_all(n, ".//td|.//th"))))
      hits  <- regmatches(cells, regexec("^([ETKNRLP])([0-2][0-9]:[0-5][0-9])$", cells))
      hits  <- Filter(function(h) length(h) == 3, hits)
      if (!length(hits)) next
      out[[length(out) + 1]] <- tibble(
        period_from = p$from,
        period_to   = p$to,
        day         = vapply(hits, `[`, "", 2),
        time        = vapply(hits, `[`, "", 3)
      )
    }
  }
  bind_rows(out) |> distinct()
}

expand_praamid <- function(tt, leg_code, dates) {
  map_dfr(dates, function(d) {
    letter <- DAY_LETTER[as.integer(format(d, "%u"))]
    rows <- tt |> filter(period_from <= d, period_to >= d, day == letter)
    if (!nrow(rows)) return(tibble())
    tibble(
      leg     = leg_code,
      date    = d,
      depart  = as.POSIXct(paste(d, rows$time), tz = TZ),
      bikes   = NA_integer_,
      vessel  = NA_character_
    )
  }) |> arrange(depart) |> distinct()
}

# ── veeteed.com: live booking inventory ───────────────────────────────────────
# The public booking API exposes each sailing together with remaining capacity,
# so this also tells us how many bicycle spots are still free — worth watching
# on Sõru–Triigi, where one sailing carries the whole field.

veeteed_sailings <- function(leg_code, dates) {
  map_dfr(dates, function(d) {
    resp <- try(
      request(sprintf("https://www.veeteed.com/api/sailPackage/inventory/%s/%s/",
                      leg_code, format(d, "%Y-%m-%d"))) |>
        req_user_agent(UA) |>
        req_headers(Accept = "application/json", Referer = "https://www.veeteed.com/") |>
        req_retry(max_tries = 3, backoff = ~5) |>
        req_perform() |>
        resp_body_json(),
      silent = TRUE)
    if (inherits(resp, "try-error") || is.null(resp$availabilities)) return(tibble())
    map_dfr(resp$availabilities, function(s) {
      bike <- keep(s$availableInventoryClasses, ~ .x$inventoryClass == "BICYCLE")
      tibble(
        leg    = leg_code,
        date   = d,
        depart = as.POSIXct(paste(format(d, "%Y-%m-%d"), substr(s$departureTime, 1, 5)), tz = TZ),
        bikes  = if (length(bike)) as.integer(bike[[1]]$amount) else NA_integer_,
        vessel = s$vesselTitle %||% NA_character_
      )
    })
  }) |> arrange(depart) |> distinct()
}

# ── Collect all three legs ────────────────────────────────────────────────────

cat("Fetching Rohuküla → Heltermaa from praamid.ee ...\n")
tt_roh <- praamid_timetable("https://www.praamid.ee/en/hiiumaa-mainland", "Rohuküla")
s_roh  <- expand_praamid(tt_roh, "ROH-HEL", WINDOW)

cat("Fetching Kuivastu → Virtsu from praamid.ee ...\n")
tt_kui <- praamid_timetable("https://www.praamid.ee/en/muhu-saaremaa-%e2%86%94-mainland/", "Kuivastu")
s_kui  <- expand_praamid(tt_kui, "KUI-VIR", WINDOW)

cat("Fetching Sõru → Triigi from veeteed.com ...\n")
s_sor  <- veeteed_sailings("SOR-TRI", WINDOW)

sailings <- bind_rows(s_roh, s_sor, s_kui) |> arrange(leg, depart)
stopifnot(nrow(s_roh) > 0, nrow(s_sor) > 0, nrow(s_kui) > 0)

cat(sprintf("Sailings in window: ROH-HEL %d, SOR-TRI %d, KUI-VIR %d\n",
            nrow(s_roh), nrow(s_sor), nrow(s_kui)))

write_json(list(
  generated_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  race_start    = format(RACE_START, "%Y-%m-%dT%H:%M:%S%z"),
  ferries       = FERRIES,
  sailings      = sailings |> mutate(depart = format(depart, "%Y-%m-%dT%H:%M:%S%z"))
), OUT_JSON, auto_unbox = TRUE, pretty = TRUE)
cat("Wrote", OUT_JSON, "\n")

# ── Simulate each profile ─────────────────────────────────────────────────────

sims <- PROFILES |> split(seq_len(nrow(PROFILES))) |> map(~ simulate(.x, sailings))

# ── Markdown report ───────────────────────────────────────────────────────────

fmt_dt <- fmt_et

md <- c(
  "# Kõkõva 900 · 2026 — praamiplaan",
  "",
  sprintf("> Genereeritud **%s** · allikad [praamid.ee](https://www.praamid.ee) (TS Laevad) ja [veeteed.com](https://www.veeteed.com) (Kihnu Veeteed)",
          format(Sys.time(), "%Y-%m-%d %H:%M %Z", tz = TZ)),
  "",
  sprintf("**Start** %s Hundipea · **limiit** %d päeva → %s · **rada** ~%.0f km",
          fmt_dt(RACE_START), RACE_LIMIT_D, fmt_dt(RACE_END), 984.6),
  "",
  "## Ületuskohad rajal",
  "",
  "| km | Ületus | Kestus | Vedaja | Allikas |",
  "|---:|--------|-------:|--------|---------|"
)
for (i in seq_len(nrow(FERRIES))) {
  f <- FERRIES[i, ]
  md <- c(md, sprintf("| %.1f | %s → %s | %d min | %s | %s |",
                      f$km_from, f$from, f$to, f$crossing_min, f$operator, f$source))
}

# Per-leg timetables for the race window
for (i in seq_len(nrow(FERRIES))) {
  f  <- FERRIES[i, ]
  sl <- sailings |> filter(leg == f$leg, date >= as.Date(RACE_START), date <= as.Date(RACE_END))
  if (!nrow(sl)) next
  md <- c(md, "",
          sprintf("## %s → %s (km %.1f)", f$from, f$to, f$km_from),
          "",
          "| Kuupäev | Väljumised |",
          "|---------|------------|")
  for (d in sort(unique(sl$date))) {
    dd <- as.Date(d, origin = "1970-01-01")
    row <- sl |> filter(date == dd) |> arrange(depart)
    times <- format(row$depart, "%H:%M")
    if (!all(is.na(row$bikes))) {
      times <- sprintf("%s _(%s rattakohta)_", times, row$bikes)
    }
    md <- c(md, sprintf("| %s (%s) | %s |",
                        format(dd, "%a %d.%m"),
                        DAY_LETTER[as.integer(format(dd, "%u"))],
                        paste(times, collapse = " · ")))
  }
}

# ── Sõru gate ─────────────────────────────────────────────────────────────────
# Sõru–Triigi runs two or three times a day, so missing a sailing costs far more
# than the crossing itself. Everything upstream of km 316.5 is really a race
# against one of these departures — and since the only way onto Hiiumaa is the
# Rohuküla ferry, each Sõru sailing implies a last Rohuküla ferry you can be on.

HEL_TO_SOR_KM <- FERRIES$km_from[FERRIES$leg == "SOR-TRI"] -
                 FERRIES$km_to[FERRIES$leg == "ROH-HEL"]
PORT_BUFFER_H <- 0.25   # be at the quay this far ahead of departure

sor <- sailings |>
  filter(leg == "SOR-TRI", date >= as.Date(RACE_START), date <= as.Date(RACE_END)) |>
  arrange(depart) |>
  mutate(next_dep = lead(depart),
         penalty_h = as.numeric(difftime(next_dep, depart, units = "hours")))

roh <- sailings |> filter(leg == "ROH-HEL") |> arrange(depart) |>
  mutate(arrive_hel = depart + FERRIES$crossing_min[FERRIES$leg == "ROH-HEL"] * 60)

last_roh_for <- function(sor_dep, eff_kmh) {
  latest_hel <- sor_dep - (HEL_TO_SOR_KM / eff_kmh + PORT_BUFFER_H) * 3600
  cand <- roh |> filter(arrive_hel <= latest_hel)
  if (!nrow(cand)) return("—")
  fmt_dt(cand$depart[nrow(cand)])
}

gate_speeds <- PROFILES |>
  mutate(eff = moving_kmh * (1 - stop_frac)) |>
  filter(profile %in% c("Keskmik", "Lõpetaja"))

md <- c(md, "",
  sprintf("## ⚠️ Sõru värav — %.0f km Heltermaalt, 2–3 väljumist päevas", HEL_TO_SOR_KM),
  "",
  "See on raja ainus koht, kus graafikust mahajäämine maksab pool ööpäeva.",
  local({
    thin <- sor |> filter(date >= as.Date("2026-08-18"), date <= as.Date("2026-08-20"))
    gap  <- max(thin$penalty_h[!is.na(thin$penalty_h) & thin$penalty_h < 12])
    sprintf("Alates **17. augustist** kaob keskpäevane väljumine ja **18.–20. augustil jääb alles ainult %s** — vahe %s tundi.",
            paste(unique(format(thin$depart, "%H:%M")), collapse = " ja "),
            sub("\\.", ",", sprintf("%.2f", gap)))
  }),
  "",
  sprintf("Veerud näitavad viimast Rohuküla praami, millega vastavas tempos (%s) veel Sõrule jõuab; sisaldab %.0f min varu sadamas.",
          paste(sprintf("%s %.1f km/h", gate_speeds$profile, gate_speeds$eff), collapse = " / "),
          PORT_BUFFER_H * 60),
  "",
  paste0("| Sõru väljumine | Triigis | Kaotus kui maha jääd | ",
         paste(sprintf("Viimane Rohuküla praam (%s)", gate_speeds$profile), collapse = " | "), " |"),
  paste0("|----------------|---------|---------------------:|",
         paste(rep("---|", nrow(gate_speeds)), collapse = "")))

cross_sor <- FERRIES$crossing_min[FERRIES$leg == "SOR-TRI"]
for (i in seq_len(nrow(sor))) {
  s <- sor[i, ]
  md <- c(md, sprintf("| %s | %s | %s | %s |",
    fmt_dt(s$depart),
    format(s$depart + cross_sor * 60, "%H:%M"),
    if (is.na(s$penalty_h)) "—" else sprintf("%.1f h", s$penalty_h),
    paste(vapply(gate_speeds$eff, function(e) last_roh_for(s$depart, e), ""), collapse = " | ")))
}

md <- c(md, "",
  "## Soovituslikud praamid profiili kaupa",
  "",
  "Mudel: sõidukiirus miinus peatuste osakaal, öine uni profiili kellaajal, sadamas oodatakse järgmist väljumist.",
  "Parameetrid on `R/plan.R` failis (`PROFILES`).",
  "")

for (s in sims) {
  p <- PROFILES |> filter(profile == s$profile)
  md <- c(md, "",
    sprintf("### %s — %.1f km/h sõidus, %.1f h und, ~%.0f%% peatusi",
            s$profile, p$moving_kmh, p$sleep_h, 100 * p$stop_frac),
    "",
    sprintf("Lõpetab **%s** (%.0f h %.0f min, limiidini %.0f h).",
            fmt_dt(s$finish), floor(s$elapsed_h), (s$elapsed_h %% 1) * 60,
            as.numeric(difftime(RACE_END, s$finish, units = "hours"))),
    "",
    "| km | Sündmus | Aeg |",
    "|---:|---------|-----|")
  fl <- s$log |> filter(event %in% c("ferry", "ferry_missed"))
  for (j in seq_len(nrow(fl))) {
    e <- fl[j, ]
    md <- c(md, sprintf("| %.1f | %s | saabub %s |", e$km, e$detail, fmt_dt(e$time)))
  }
}

md <- c(md, "",
  "---",
  "",
  "Generaator [`R/ferry_schedule.R`](../R/ferry_schedule.R) · toorandmed [`output/ferries.json`](../output/ferries.json) · ",
  "rajamudel [`R/plan.R`](../R/plan.R)",
  "")

writeLines(md, OUT_MD)
cat("Wrote", OUT_MD, "\n")
