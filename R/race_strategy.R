# Kõkõva 900 (2026) — race strategy.
#
# Pulls together the pacing model, the real ferry timetable and the rider's own
# measured history into one plan. The organising question is not "how fast can
# he ride" but "which Sõru ferry does he make", because that single decision is
# worth more than a day of pacing.
#
# Run: make strategy   (or  Rscript R/race_strategy.R)

suppressPackageStartupMessages({
  library(dplyr)
  library(tibble)
  library(purrr)
  library(readr)
  library(jsonlite)
})

source("R/plan.R")
source("R/athlete.R")

OUT_MD <- file.path(DIR_REPORTS, "race_strategy.md")

FERRIES_JSON <- file.path(DIR_OUTPUT, "ferries.json")
if (!file.exists(FERRIES_JSON)) stop("Run `make ferry` first — need ", FERRIES_JSON)

sailings <- fromJSON(FERRIES_JSON)$sailings |>
  as_tibble() |>
  mutate(depart = as.POSIXct(depart, format = "%Y-%m-%dT%H:%M:%S%z", tz = TZ),
         date   = as.Date(depart, tz = TZ))

waypoints <- read_csv(WAYPOINTS_CSV, show_col_types = FALSE)

# ── Simulate every profile ────────────────────────────────────────────────────

sims <- PROFILES |> split(seq_len(nrow(PROFILES))) |> map(~ simulate(.x, sailings))
names(sims) <- PROFILES$profile

ferry_of <- function(sim, leg) {
  r <- sim$log |> filter(event == "ferry", grepl(leg, detail, fixed = TRUE))
  if (!nrow(r)) return(NULL)
  r[1, ]
}

me      <- sims[["Taavi 2026 ootus"]]
me_2025 <- sims[["Taavi 2025 tempo"]]

sor_leg    <- ferry_of(me, "Sõru→Triigi")
sor_wait_h <- as.numeric(difftime(sor_leg$until - FERRIES$crossing_min[2] * 60,
                                  sor_leg$time, units = "hours"))

# ── The Sõru gate, for this rider specifically ────────────────────────────────
# Work backwards from each Saturday sailing to the last Rohuküla ferry that
# still reaches it, at the rider's own modelled pace.

HEL_TO_SOR <- FERRIES$km_from[FERRIES$leg == "SOR-TRI"] - FERRIES$km_to[FERRIES$leg == "ROH-HEL"]
TAL_TO_ROH <- FERRIES$km_from[FERRIES$leg == "ROH-HEL"]
BOARD_BUF  <- 0.25

prof_me   <- PROFILES |> filter(profile == "Taavi 2026 ootus")
eff_push  <- prof_me$moving_kmh * (1 - prof_me$push_frac)

roh <- sailings |> filter(leg == "ROH-HEL") |> arrange(depart) |>
  mutate(arrive_hel = depart + FERRIES$crossing_min[FERRIES$leg == "ROH-HEL"] * 60)

sor_sat <- sailings |>
  filter(leg == "SOR-TRI", date == as.Date("2026-08-15")) |>
  arrange(depart)

# For each Saturday Sõru sailing: the latest Rohuküla ferry that still works,
# and the elapsed pace from the Tallinn start that each option demands.
# Options needing a superhuman opening pace are dropped — the early Saturday
# sailings are only reachable off the Friday 22:00 Rohuküla ferry, which leaves
# one hour after the start.
MAX_PLAUSIBLE_KMH <- 30

gate <- map_dfr(seq_len(nrow(sor_sat)), function(i) {
  s <- sor_sat[i, ]
  need_hel <- s$depart - (HEL_TO_SOR / eff_push + BOARD_BUF) * 3600
  cand <- roh |> filter(arrive_hel <= need_hel)
  if (!nrow(cand)) return(tibble())
  last <- cand[nrow(cand), ]
  tibble(
    sor_dep = s$depart,
    roh_dep = last$depart,
    hel_arr = last$arrive_hel,
    # pace needed from the 21:00 start to be at the Rohuküla quay 15 min early
    tal_kmh = TAL_TO_ROH / as.numeric(difftime(last$depart - BOARD_BUF * 3600,
                                               RACE_START, units = "hours")),
    hii_kmh = HEL_TO_SOR / as.numeric(difftime(s$depart - BOARD_BUF * 3600,
                                               last$arrive_hel, units = "hours"))
  )
}) |>
  filter(tal_kmh <= MAX_PLAUSIBLE_KMH)

# ── Break-even opening speed ──────────────────────────────────────────────────
# The actionable number is not "ride faster" in the abstract but the moving
# speed that just makes the Saturday evening sailing, at a given stop discipline.
# Solved by bisection on the simulation itself so it accounts for the ferry
# waits rather than assuming a clean run.

SAT_EVENING <- sor_sat$depart[which(format(sor_sat$depart, "%H:%M") == "18:30")]

makes_evening <- function(moving_kmh, push_frac) {
  p <- prof_me
  p$moving_kmh <- moving_kmh
  p$push_frac  <- push_frac
  f <- ferry_of(simulate(p, sailings), "Sõru→Triigi")
  !is.null(f) && abs(as.numeric(difftime(f$until - FERRIES$crossing_min[2] * 60,
                                         SAT_EVENING, units = "mins"))) < 1
}

breakeven <- function(push_frac, lo = 12, hi = 26) {
  if (!makes_evening(hi, push_frac)) return(NA_real_)
  for (i in 1:24) {
    mid <- (lo + hi) / 2
    if (makes_evening(mid, push_frac)) hi <- mid else lo <- mid
  }
  round(hi, 1)
}

be <- tibble(
  push_frac = c(0.10, 0.06, 0.03),
  label     = c("praegune eeldus (10% peatusi)",
                "2025. aasta distsipliin (6%)",
                "peaaegu ei peatu (3%)"),
  need_kmh  = vapply(c(0.10, 0.06, 0.03), breakeven, numeric(1))
)

# ── What each Rohuküla sailing actually buys ─────────────────────────────────
# Every option below lands the same 18:30 Sõru sailing, so arriving at the quay
# earlier does not put the rider on Saaremaa earlier — it only lengthens the
# wait at Sõru. That wait is forced, which makes it the cheapest sleep on the
# route.
HIIUMAA_KMH <- 15    # elapsed pace Heltermaa → Sõru, gravel with kit

opts <- tibble(dep = as.POSIXct(paste("2026-08-15", c("06:30", "08:30", "10:00")), tz = TZ)) |>
  mutate(
    hel      = dep + FERRIES$crossing_min[FERRIES$leg == "ROH-HEL"] * 60,
    sor      = hel + (HEL_TO_SOR / HIIUMAA_KMH) * 3600,
    need_kmh = TAL_TO_ROH / as.numeric(difftime(dep - BOARD_BUF * 3600, RACE_START, units = "hours")),
    wait_h   = as.numeric(difftime(SAT_EVENING, sor, units = "hours")),
    dep_lbl  = format(dep, "%H:%M"),
    hel_lbl  = format(hel, "%H:%M"),
    sor_lbl  = format(sor, "%H:%M"),
    wait_lbl = ifelse(wait_h < 0, sprintf("**%s min hiljaks**", num_et(-wait_h * 60, 0)),
                      paste0(num_et(wait_h, 1), " h"))
  )

# ── Report ────────────────────────────────────────────────────────────────────

pct <- function(x) sprintf("%+.0f%%", 100 * x)

md <- c(
  "# Kõkõva 900 · 2026 — võistlusstrateegia",
  "",
  sprintf("> Genereeritud **%s** · rajamudel [`R/plan.R`](../R/plan.R) · sportlase andmed [`R/athlete.R`](../R/athlete.R)",
          format(Sys.time(), "%Y-%m-%d %H:%M %Z", tz = TZ)),
  "",
  sprintf("**Start** %s Hundipea · **limiit** %d päeva → %s · **rada** %.0f km, ~1580 m tõusu",
          fmt_et(RACE_START), RACE_LIMIT_D, fmt_et(RACE_END), TOTAL_ROUTE_KM),
  "",
  "## Lühidalt",
  "",
  "Rada on lauge. Kogu tõus 985 km peale on 1580 m — vähem kui TBR-i ühel päeval.",
  "Sinu 2026. aasta suurim on-bike piiraja, tõusudel püsiva võimsuse hoidmine, siin praktiliselt ei rakendu.",
  "",
  "Selle võistluse otsustab **Sõru praam kilomeetril 316,5** — see sõidab võistlusaknas 2–3 korda päevas ja õhtusest mahajäämine maksab 13,4 h.",
  "Avaetapi asfaldiga jõuad sinna välja; küsimus ei ole enam kas, vaid millise Rohuküla praamiga ja mida ooteajaga peale hakata.",
  "",
  "## Laupäevane Sõru praam — ja mida iga Rohuküla praam tegelikult ostab",
  "",
  "Avaetapp on sinu sõnul suuresti asfalt, mis on mudelis nüüd eraldi kiirusena sees.",
  "Sellega ei ole praamivärav enam piirav — aga see, millisele Rohuküla praamile jõuad, ei tähenda seda, mida ootaks.",
  "",
  "| Rohuküla praam | Nõutav tempo stardist | Heltermaal | Sõrus (15 km/h Hiiumaal) | Ootamine Sõrus |",
  "|----------------|----------------------:|------------|--------------------------|---------------:|",
  paste0(sprintf("| **%s** | %s km/h elapsed | %s | %s | %s |",
                 opts$dep_lbl, num_et(opts$need_kmh, 1), opts$hel_lbl,
                 opts$sor_lbl, opts$wait_lbl), collapse = "\n"),
  "",
  "**Kõik kolm esimest jõuavad samale 18:30 Sõru praamile.** Varem Rohukülla jõudmine ei too sind Saaremaale varem —",
  sprintf("see ainult pikendab ootamist Sõrus. 10:00 praam on juba kiivas: %s km/h Hiiumaal jätab sind %s minutit hiljaks.",
          num_et(HIIUMAA_KMH, 0), num_et(-opts$wait_h[3] * 60, 0)),
  "",
  sprintf("**Tegelik tähtaeg on %s Rohuküla praam.**", "08:30"),
  "",
  "### Ja siin on see, mida sellega peale hakata",
  "",
  sprintf("Kui jõuad 06:30 praamile, tekib Sõrus **%s tundi surnud aega**. See aeg on sunnitud — praam ei välju varem, ükskõik kui kiiresti sõidad.",
          num_et(opts$wait_h[1], 1)),
  "",
  sprintf("TBR-il seisid magamiseks %s h, et saada %s h und. Siin on uni **tasuta**: sa ootaksid niikuinii.",
          num_et(ATHLETE$tbr$sleep_stopped_h, 1), num_et(ATHLETE$tbr$sleep_actual_h, 1)),
  "",
  "| Variant | Triigis | Und selleks hetkeks | Hind |",
  "|---------|---------|---------------------|------|",
  sprintf("| 06:30 praam + uni Sõrus | 19:05 | **~%s h** | %s km/h avaetapil |",
          num_et(max(0, opts$wait_h[1] - 0.5), 1), num_et(opts$need_kmh[1], 1)),
  sprintf("| 08:30 praam, ei maga | 19:05 | 0 h | %s km/h avaetapil |", num_et(opts$need_kmh[2], 1)),
  "",
  "**Mõlemad jõuavad Triigisse kell 19:05.** Vahe on ainult selles, kas oled maganud.",
  sprintf("Kaks tundi kõvemat sõitu avaetapil ostab %s tundi und, mis muidu läheks ootamisele.",
          num_et(max(0, opts$wait_h[1] - 0.5), 1)),
  "",
  "### Kuidas see praam kätte saada",
  "",
  "Ainus tee Hiiumaale on Rohuküla praam, seega iga Sõru väljumine tähendab konkreetset viimast Rohuküla praami.",
  "",
  "| Sõru väljumine | Viimane Rohuküla praam | Heltermaal | Tallinn→Rohuküla nõutav tempo | Heltermaa→Sõru nõutav tempo |",
  "|----------------|------------------------|------------|------------------------------:|----------------------------:|")
for (i in seq_len(nrow(gate))) {
  g <- gate[i, ]
  md <- c(md, sprintf("| %s | %s | %s | %s km/h | %s km/h |",
                      fmt_et(g$sor_dep), fmt_et(g$roh_dep), format(g$hel_arr, "%H:%M"),
                      num_et(g$tal_kmh, 1), num_et(g$hii_kmh, 1)))
}

md <- c(md, "",
  sprintf("Tempod on **elapsed**, mitte sõidutempo — sisaldavad kõiki peatusi. Sinu 2025. aasta avaetapp oli %.0f km %s tunniga, mis teeb %s km/h elapsed. See on täpselt see number, mida siin vaja.",
          ATHLETE$y2025$leg1_km, num_et(ATHLETE$y2025$leg1_h, 1),
          num_et(ATHLETE$y2025$leg1_km / ATHLETE$y2025$leg1_h, 1)),
  "",
  "**Otsus: mine 08:30 Rohuküla praamile.** See annab Hiiumaal üle seitsme tunni 112 km jaoks — mugav varu.",
  "10:00 praam jätab napilt seitse tundi, mis tähendab Hiiumaal sisuliselt mitte peatumist. 11:30 praamiga on 18:30 Sõru läinud.",
  "",
  "## Vorm — kaks numbrit, mis näitavad vastassuunda",
  "",
  "| Näitaja | Väärtus | Tähendus |",
  "|---------|---------|----------|",
  sprintf("| HRV nädala keskmine | %d | Täielikult taastunud, üle enda 2026. aasta keskmise (59,8) |", ATHLETE$hrv_recent),
  sprintf("| Kroonilne koormus | %d | **%.0f%% aprilli tipust (%d)** — Garmini staatus %s |",
          ATHLETE$chronic_load, 100 * ATHLETE$chronic_load / ATHLETE$chronic_peak,
          ATHLETE$chronic_peak, ATHLETE$training_status),
  sprintf("| Päevi rattata | %d | Viimane sõit 13. juuli |", ATHLETE$days_off_bike),
  sprintf("| Pikim sõit pärast TBR-i | %.0f km | 11. juuli, 2,4 h |", ATHLETE$longest_ride_since_race_km),
  "",
  "Oled maksimaalselt värske ja samal ajal märkimisväärselt vormist väljas. Värskus on 19 päevaga taastatav osa;",
  "aeroobne baas ei ole. Sellepärast on mudelis eraldi profiil „Taavi 2026 ootus\" (16,5 km/h sõidus) eristatuna",
  "2025. aasta tempost (18,5 km/h) — see vahe on täpselt see, mis Sõru praami maha jätab.",
  "",
  "## Võimsus",
  "",
  sprintf("FTP **%d W** (%s W/kg), lävipulss %d, maksimaalne mõõdetud pulss %d.",
          ATHLETE$ftp_w, num_et(ATHLETE$ftp_w / ATHLETE$weight_kg, 2), ATHLETE$lthr, ATHLETE$hr_max),
  "",
  sprintf("2025. aasta Kõkõval hoidsid keskmist %s ja langus kolme suure etapi jooksul oli ainult **%s**.",
          "118 → 109 W", pct(ATHLETE$y2025$power_decay)),
  sprintf("TBR-il oli sama näitaja **%s** (115 → 84 W) — aga see oli 27 000 m tõusuga rada kuumuses.",
          pct(ATHLETE$tbr$power_decay)),
  "Tänavune rada on lauge ja ilm jahedam, seega vastupidavuse mõttes on 2025. aasta profiil õigem ootus —",
  "kuigi ka see rada oli tänavusest viis korda mägisem.",
  "",
  "| Lõik | Keskmine | NP | Miks |",
  "|------|---------:|---:|------|",
  "| Avaetapp (0 → Sõru) | 120–130 W | 145–155 W | Ainus koht, kus tasub kulutada — praam ei oota |",
  "| Päev 2–3 | 105–115 W | 130–140 W | 2025. aasta tegelik püsitase |",
  "| Lõpuosa | 100–110 W | 125–135 W | Mandril, kui praamid on seljataga |",
  "",
  sprintf("Z2 on %d–%d W. Avaetapi 145–155 W NP on Z2 keskosa — see ei ole julge number, see on lihtsalt mitte-peatumine.",
          ZONES$lo[ZONES$zone == "Z2"], ZONES$hi[ZONES$zone == "Z2"]),
  "",
  "## Uni — sinu suurim ajakadu",
  "",
  sprintf("TBR-il seisid magamiseks **%s h**, et saada kätte **%s h** tegelikku und — %.0f%% efektiivsus.",
          num_et(ATHLETE$tbr$sleep_stopped_h, 1), num_et(ATHLETE$tbr$sleep_actual_h, 1),
          100 * ATHLETE$tbr$sleep_actual_h / ATHLETE$tbr$sleep_stopped_h),
  sprintf("Umbes **%s tundi** võistlusest kulus pikali, aga ärkvel. Kogu peatusaeg oli %s h vs välja mediaan %s h — vahe on praktiliselt seesama.",
          num_et(ATHLETE$tbr$sleep_stopped_h - ATHLETE$tbr$sleep_actual_h, 1),
          num_et(ATHLETE$tbr$stopped_h, 1), num_et(ATHLETE$tbr$stopped_median, 1)),
  "",
  sprintf("2025. aasta Kõkõval tegid vastupidist ja see töötas: läbi esimese öö (%.0f km), siis kokku ainult %s h und terve %.0f-tunnise võistluse peale. Rada oli teine, aga see on käitumine, mitte maastik — kandub üle.",
          ATHLETE$y2025$leg1_km, num_et(ATHLETE$y2025$sleep_h, 1), ATHLETE$y2025$elapsed_h),
  "",
  "**Plaan:** sõida esimene öö läbi. See ei ole kangelaslikkus — see on ainus viis olla laupäeva hommikul 08:30 Rohuküla praamil.",
  "Seejärel kaks ööd 4–5 h, magamiskoht valitud enne peatumist, mitte otsitud pärast.",
  "",
  "## Praamid ja päevakava",
  "",
  "| km | Sündmus | Aeg (Taavi 2026 ootus) |",
  "|---:|---------|------------------------|")
for (j in seq_len(nrow(me$log))) {
  e <- me$log[j, ]
  lbl <- if (e$event == "sleep") sprintf("uni %s", e$detail) else e$detail
  md <- c(md, sprintf("| %.0f | %s | %s |", e$km, lbl, fmt_et(e$time)))
}
md <- c(md, sprintf("| %.0f | **Finiš** | **%s** (%s h) |", TOTAL_ROUTE_KM, fmt_et(me$finish), num_et(me$elapsed_h, 0)))

md <- c(md, "",
  "Laevadel on toit: TS Laevade praamidel (Rohuküla–Heltermaa 75 min, Kuivastu–Virtsu 27 min) on restoran ja R-Kiosk.",
  "**75-minutiline Hiiumaa ülesõit on raja parim söögikoht** ja ainus, mis on laupäeva hommikul lahti, kui saarepoed veel magavad.",
  "Sõru–Triigi laeval Soela toitlustust ei õnnestunud kinnitada — ära arvesta sellega.",
  "",
  "Varustuse ja lahtiolekuaegade detailid: [`resupply.md`](resupply.md). Ilm: [`weather_outlook.md`](weather_outlook.md).",
  "",
  "## Varustus",
  "",
  "TBR lõppes tagumise rummu purunemisega, sest kohapealt ei saanud **28H 27.5\" Boost** ratast.",
  "See oli logistikaviga, mitte vormiviga — ja Eesti saartel on varuosade olukord veelgi kehvem kui Bosnias.",
  "Drivetrain shakedown enne starti on plaanis juba kirjas; tee see ära.",
  "",
  "---",
  "",
  "Generaator [`R/race_strategy.R`](../R/race_strategy.R) · praamigraafikud [`ferry_plan.md`](ferry_plan.md) · varustus [`resupply.md`](resupply.md)",
  "")

writeLines(md, OUT_MD)
cat("Wrote", OUT_MD, "\n")
