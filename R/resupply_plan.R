# Kõkõva 900 (2026) — resupply and fuelling plan.
#
# Reads the OSM resupply points collected by resupply.R and answers the two
# questions that actually matter on this route: where are the gaps, and what is
# open when you get there. The second question dominates — the route spends
# ~500 km on islands where shops are village-sized and shut by evening, and the
# race starts at 21:00 on a Friday.
#
# Run: make strategy   (or  Rscript R/resupply_plan.R)

suppressPackageStartupMessages({
  library(dplyr)
  library(tibble)
  library(purrr)
  library(readr)
  library(jsonlite)
})

source("R/plan.R")
source("R/athlete.R")

OUT_MD      <- file.path(DIR_REPORTS, "resupply.md")
RESUPPLY_CSV <- file.path(DIR_DATA, "resupply.csv")
if (!file.exists(RESUPPLY_CSV)) stop("Run `make resupply` first — need ", RESUPPLY_CSV)

MAX_DETOUR_M <- 700    # further than this and it stops being a resupply, it's an excursion

# Only these actually restock a bikepacker. Cafés and restaurants feed you once
# but carry nothing forward, so they are listed separately.
STOCK_KINDS <- c("supermarket", "convenience", "general", "kiosk", "bakery", "fuel")

resupply <- read_csv(RESUPPLY_CSV, show_col_types = FALSE) |>
  filter(detour_m <= MAX_DETOUR_M) |>
  mutate(name = coalesce(name, "(nimetu)"))

stock <- resupply |> filter(kind %in% STOCK_KINDS) |> arrange(km)

# ── Opening hours ─────────────────────────────────────────────────────────────
# A deliberately partial parser for the OSM opening_hours grammar: weekday
# ranges and lists with clock intervals, plus 24/7. Anything with month rules,
# public holidays or other exotica is reported as unknown rather than guessed —
# a wrong "open" here would send the rider past the last real shop.

DAYS <- c("Mo", "Tu", "We", "Th", "Fr", "Sa", "Su")

parse_hours <- function(spec) {
  if (is.na(spec) || !nzchar(spec)) return(NULL)
  if (grepl("24/7", spec, fixed = TRUE)) {
    return(tibble(day = DAYS, open_h = 0, close_h = 24))
  }
  if (grepl("PH|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec|week|easter",
            spec, ignore.case = TRUE)) return(NULL)

  out <- list()
  for (rule in strsplit(spec, ";")[[1]]) {
    rule <- trimws(rule)
    if (!nzchar(rule) || grepl("off|closed", rule, ignore.case = TRUE)) next
    times <- regmatches(rule, gregexpr("([0-2]?[0-9]):([0-5][0-9])\\s*-\\s*([0-2]?[0-9]):([0-5][0-9])", rule))[[1]]
    if (!length(times)) next
    dpart <- trimws(sub("([0-2]?[0-9]:[0-5][0-9].*)$", "", rule))
    days <- if (!nzchar(dpart)) DAYS else {
      acc <- character(0)
      for (tok in strsplit(dpart, ",")[[1]]) {
        tok <- trimws(tok)
        if (grepl("^[A-Za-z]{2}-[A-Za-z]{2}$", tok)) {
          a <- match(substr(tok, 1, 2), DAYS); b <- match(substr(tok, 4, 5), DAYS)
          if (!is.na(a) && !is.na(b) && a <= b) acc <- c(acc, DAYS[a:b])
        } else if (tok %in% DAYS) acc <- c(acc, tok)
      }
      unique(acc)
    }
    if (!length(days)) next
    for (t in times) {
      p <- as.numeric(regmatches(t, gregexpr("[0-9]+", t))[[1]])
      out[[length(out) + 1]] <- tibble(day = days,
                                       open_h  = p[1] + p[2] / 60,
                                       close_h = ifelse(p[3] == 0 & p[4] == 0, 24, p[3] + p[4] / 60))
    }
  }
  if (!length(out)) return(NULL)
  bind_rows(out)
}

is_open_at <- function(spec, when) {
  h <- parse_hours(spec)
  if (is.null(h)) return(NA)
  d <- DAYS[as.integer(format(when, "%u"))]
  hh <- as.numeric(format(when, "%H")) + as.numeric(format(when, "%M")) / 60
  any(h$day == d & h$open_h <= hh & hh < h$close_h)
}

always_open <- vapply(stock$hours, \(s) {
  h <- parse_hours(s); !is.null(h) && all(h$open_h == 0 & h$close_h == 24)
}, logical(1))
stock$open247 <- always_open

# ── Gaps ──────────────────────────────────────────────────────────────────────

gaps <- stock |>
  arrange(km) |>
  mutate(next_km = lead(km), gap = next_km - km) |>
  filter(!is.na(gap)) |>
  arrange(desc(gap))

gaps247 <- stock |>
  filter(open247) |>
  arrange(km) |>
  mutate(next_km = lead(km), gap = next_km - km) |>
  filter(!is.na(gap)) |>
  arrange(desc(gap))

# ── When the rider passes ─────────────────────────────────────────────────────

sailings <- fromJSON(file.path(DIR_OUTPUT, "ferries.json"))$sailings |>
  as_tibble() |>
  mutate(depart = as.POSIXct(depart, format = "%Y-%m-%dT%H:%M:%S%z", tz = TZ))

prof <- PROFILES |> filter(profile == "Taavi 2026 ootus")
sim  <- simulate(prof, sailings)

# Reconstruct a km → clock-time mapping from the simulation log: between logged
# events the rider moves at the effective speed for that phase.
timeline <- sim$log |>
  select(km, time, until) |>
  bind_rows(tibble(km = TOTAL_ROUTE_KM, time = sim$finish, until = sim$finish)) |>
  arrange(km)

time_at_km <- function(k) {
  after <- timeline |> filter(km >= k) |> slice(1)
  before <- timeline |> filter(km <= k) |> slice(n())
  if (!nrow(before)) return(RACE_START + (k / (prof$moving_kmh * (1 - prof$push_frac))) * 3600)
  if (!nrow(after))  return(sim$finish)
  span_km <- after$km - before$km
  if (span_km <= 0) return(before$until)
  span_h <- as.numeric(difftime(after$time, before$until, units = "hours"))
  before$until + (k - before$km) / span_km * span_h * 3600
}

stock$pass_at <- as.POSIXct(vapply(stock$km, \(k) as.numeric(time_at_km(k)), numeric(1)),
                            origin = "1970-01-01", tz = TZ)
stock$open_when_passing <- vapply(seq_len(nrow(stock)),
                                  \(i) is_open_at(stock$hours[i], stock$pass_at[i]), logical(1))

# ── Report ────────────────────────────────────────────────────────────────────

kind_et <- c(supermarket = "toidupood", convenience = "väikepood", general = "külapood",
             kiosk = "kiosk", bakery = "pagariäri", fuel = "tankla",
             cafe = "kohvik", restaurant = "restoran", fast_food = "kiirtoit",
             drinking_water = "joogivesi", greengrocer = "juurvili", butcher = "lihapood")

md <- c(
  "# Kõkõva 900 · 2026 — varustus ja toitlustus",
  "",
  sprintf("> Genereeritud **%s** · allikas OpenStreetMap (Overpass) · %d punkti kuni %d m rajast",
          format(Sys.time(), "%Y-%m-%d %H:%M %Z", tz = TZ), nrow(resupply), MAX_DETOUR_M),
  "",
  "## Lühidalt",
  "",
  sprintf("Rajal on %d kohta, kust saab varu kaasa (poed, kioskid, tanklad). Neist **%d on ööpäevaringsed** — ja need on ainsad, mis öösel loevad.",
          nrow(stock), sum(stock$open247)),
  "",
  "Start on reedel kell 21:00. Esimesed ~10 tundi sõidad ajal, mil Eesti külapoed on kinni.",
  "Sama kordub igal ööl. Praktiline reegel: **osta enne kui vaja, mitte kui kõht tühi.**",
  "",
  local({
    g <- gaps247[1, ]
    last247 <- stock |> filter(open247, km <= g$km) |> slice(n())
    c(sprintf("### ⚠️ %.0f km ilma ühegi ööpäevaringse punktita", g$gap),
      "",
      sprintf("Kilomeetrist %s (%s) kuni kilomeetrini %s (%s) — see on **terve Saaremaa ja Muhu**.",
              num_et(g$km, 1), last247$name, num_et(g$next_km, 1),
              stock$name[stock$open247 & stock$km == g$next_km][1]),
      "",
      sprintf("Sellel lõigul on %d varustuspunkti, aga kõik lahtiolekuaegadega. Kui jõuad Triigi sadamasse laupäeva õhtul %s praamiga, on Saaremaa poed juba kinni ja avanevad alles hommikul.",
              sum(stock$km > g$km & stock$km < g$next_km),
              "18:30"),
      "",
      sprintf("**%s (km %s, %d m rajast, 24/7) on viimane garanteeritud punkt enne seda lõiku.** Lae seal täis — see ei ole soovitus, see on ainus koht.",
              last247$name, num_et(last247$km, 1), last247$detour_m))
  }),
  "",
  "## Laevakohvikud — raja usaldusväärseim toit",
  "",
  "| Ületus | Kestus | Pardal |",
  "|--------|-------:|--------|")
for (i in seq_len(nrow(FERRIES))) {
  f <- FERRIES[i, ]
  md <- c(md, sprintf("| %s → %s | %d min | %s |", f$from, f$to, f$crossing_min, f$onboard))
}
md <- c(md, "",
  "TS Laevade praamidel on restoran Take Off ja R-Kiosk, kõigil viiel laeval, ilma avaldatud kellaajapiiranguta.",
  "**75-minutiline Rohuküla–Heltermaa ülesõit on raja parim söögikoht** — soe toit, laud, ja see töötab ka kell 06:30 hommikul,",
  "kui ükski saarepood veel ei ava. Planeeri sinna päris eine, mitte batoon.",
  "",
  "Sõru–Triigi laeva Soela kohta toitlustust kinnitada ei õnnestunud. Ära arvesta.",
  "",
  "## Ööpäevaringsed punktid",
  "",
  "Öösel ja varahommikul on ainult need. Tanklad on Eestis selle raja peal seljatugi.",
  "",
  "| km | Detour | Tüüp | Nimi |",
  "|---:|-------:|------|------|")
for (i in which(stock$open247)) {
  s <- stock[i, ]
  md <- c(md, sprintf("| %s | %d m | %s | %s |", num_et(s$km, 1), s$detour_m,
                      kind_et[s$kind] %||% s$kind, s$name))
}

md <- c(md, "",
  "## Pikimad vahed",
  "",
  "### Kõigi varustuspunktide vahel",
  "",
  "| Alates km | Kuni km | Vahe | Viimane punkt enne |",
  "|----------:|--------:|-----:|--------------------|")
for (i in seq_len(min(8, nrow(gaps)))) {
  g <- gaps[i, ]
  md <- c(md, sprintf("| %s | %s | **%.0f km** | %s (%s) |",
                      num_et(g$km, 1), num_et(g$next_km, 1), g$gap, g$name,
                      kind_et[g$kind] %||% g$kind))
}

md <- c(md, "",
  "### Ainult ööpäevaringsete vahel — see on öine reaalsus",
  "",
  "| Alates km | Kuni km | Vahe | Viimane punkt enne |",
  "|----------:|--------:|-----:|--------------------|")
for (i in seq_len(min(6, nrow(gaps247)))) {
  g <- gaps247[i, ]
  md <- c(md, sprintf("| %s | %s | **%.0f km** | %s |",
                      num_et(g$km, 1), num_et(g$next_km, 1), g$gap, g$name))
}

open_pass <- stock |> filter(!is.na(open_when_passing))
md <- c(md, "",
  "## Mis on lahti, kui sa mööda sõidad",
  "",
  sprintf("Mudeliprofiil „%s\". Lahtiolekuajad on OSM-ist ja %d punktil %d-st puuduvad või on masinloetamatud — need on tabelist väljas.",
          prof$profile, nrow(stock) - nrow(open_pass), nrow(stock)),
  "",
  sprintf("Neist, mille kohta andmed on: **%d lahti, %d kinni** kui sa möödud.",
          sum(open_pass$open_when_passing), sum(!open_pass$open_when_passing)),
  "",
  "Suletud punktid, mis muidu oleks olulised:",
  "",
  "| km | Möödud | Tüüp | Nimi | Lahtiolek |",
  "|---:|--------|------|------|-----------|")
# Beyond the Tallinn conurbation only — a supermarket shut at 22:05 in the
# suburbs is not a planning problem, one shut on Saaremaa is.
shut <- open_pass |>
  filter(!open_when_passing, km > 100,
         kind %in% c("supermarket", "convenience", "general", "kiosk", "bakery")) |>
  arrange(km) |> slice_head(n = 16)
for (i in seq_len(nrow(shut))) {
  s <- shut[i, ]
  md <- c(md, sprintf("| %s | %s | %s | %s | %s |", num_et(s$km, 1), fmt_et(s$pass_at),
                      kind_et[s$kind] %||% s$kind, s$name, s$hours))
}

md <- c(md, "",
  "## Toitlustus",
  "",
  sprintf("TBR-il kulutasid **~%d kcal päevas** (Garmini päevakogusumma, päevad 1–5). Kõkõva on lauge ja lühem, aga kordades kiirem tempo — arvesta 5000–6000 kcal/päevas.",
          ATHLETE$tbr$kcal_per_day),
  "",
  sprintf("Plaanitud sihiks on **%d g süsivesikuid tunnis** ja %d–%d ml vedelikku.",
          ATHLETE$carb_g_h_target, ATHLETE$fluid_ml_h[1], ATHLETE$fluid_ml_h[2]),
  "",
  "⚠️ **See number on testimata.** Treeninguprojektis ei ole ühtegi logitud toidu- ega joogikogust —",
  "kõik toitumiskirjed on nullid ja kõik hüdratsioonikirjed 0,0 ml. 90 g/h on plaan, mitte teadaolev taluvus.",
  "Enne starti on kaks pikka sõitu plaanis; **harjuta neil täpselt seda kogust**, muidu on võistlus esimene kord.",
  "",
  sprintf("Higikadu TBR-il oli hinnanguliselt %d–%d ml/h Balkani kuumuses. Augustikuu Eestis on mediaan päevamaksimum 20–22 °C,",
          ATHLETE$sweat_ml_h_tbr[1], ATHLETE$sweat_ml_h_tbr[2]),
  "seega planeeri alumise otsa järgi — aga tuul kuivatab ja janu tuleb hiljem kui vajadus.",
  "",
  "---",
  "",
  "Generaator [`R/resupply_plan.R`](../R/resupply_plan.R) · toorandmed [`data/resupply.csv`](../data/resupply.csv) · ",
  "strateegia [`race_strategy.md`](race_strategy.md) · praamid [`ferry_plan.md`](ferry_plan.md)",
  "")

writeLines(md, OUT_MD)
cat("Wrote", OUT_MD, "\n")
