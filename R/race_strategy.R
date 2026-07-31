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

SURFACE_CSV <- file.path(DIR_DATA, "surface.csv")
surface <- if (file.exists(SURFACE_CSV)) read_csv(SURFACE_CSV, show_col_types = FALSE) else NULL

surf_share <- function(from, to) {
  if (is.null(surface)) return(NULL)
  d <- surface |> filter(km > from, km <= to)
  if (!nrow(d)) return(NULL)
  # "asfalt (eeldus)" and friends — surfaces inferred from the road class when
  # the way carries no tag — count with their parent class here.
  d |> mutate(klass = sub(" \\(eeldus\\)$", "", klass)) |>
    count(klass) |> mutate(pct = 100 * n / sum(n)) |>
    select(klass, pct) |> tidyr::pivot_wider(names_from = klass, values_from = pct)
}

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

sor_leg  <- ferry_of(me, "Sõru→Triigi")
sor_2025 <- ferry_of(me_2025, "Sõru→Triigi")

# What missing the Saturday evening sailing actually costs: the departure gap
# to the next boat out of Sõru.
SAT_EVENING <- sailings |>
  filter(leg == "SOR-TRI", date == as.Date("2026-08-15")) |>
  arrange(depart) |> slice(n()) |> pull(depart)
GAP_H <- sailings |>
  filter(leg == "SOR-TRI", depart > SAT_EVENING) |>
  summarise(h = as.numeric(difftime(min(depart), SAT_EVENING, units = "hours"))) |>
  pull(h)

# ── The Sõru gate, for this rider specifically ────────────────────────────────
# Work backwards from each Saturday sailing to the last Rohuküla ferry that
# still reaches it, at the rider's own modelled pace. The whole run to Sõru
# happens before the first sleep, so the opening-push speed is the one in play.

HEL_TO_SOR <- FERRIES$km_from[FERRIES$leg == "SOR-TRI"] - FERRIES$km_to[FERRIES$leg == "ROH-HEL"]
TAL_TO_ROH <- FERRIES$km_from[FERRIES$leg == "ROH-HEL"]
RIDDEN_KM  <- TOTAL_ROUTE_KM - sum(FERRIES$km_to - FERRIES$km_from)
BOARD_BUF  <- 0.25

prof_me   <- PROFILES |> filter(profile == "Taavi 2026 ootus")
eff_push  <- prof_me$push_kmh * (1 - prof_me$push_frac)

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
  # A candidate Rohuküla ferry that departs before the race start shows up as a
  # negative pace; drop it along with the superhuman ones.
  filter(tal_kmh > 0, tal_kmh <= MAX_PLAUSIBLE_KMH)

# ── Break-even opening speed ──────────────────────────────────────────────────
# The actionable number is not "ride faster" in the abstract but the opening
# moving speed that just makes the Saturday evening sailing, at a given stop
# discipline. Bisection runs on push_kmh because the whole Tallinn → Sõru run
# happens before the first sleep — moving_kmh never enters it. Solved on the
# simulation itself so it accounts for the ferry waits, the neutralised start
# and the Hiiumaa leg rather than assuming a clean run.

makes_evening <- function(push_kmh, push_frac) {
  p <- prof_me
  p$push_kmh  <- push_kmh
  p$push_frac <- push_frac
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

# ── What each Rohuküla sailing actually demands ──────────────────────────────
# On the beta route every morning boat funnelled into the same 18:30 Sõru
# sailing and the only question was how long you waited at the quay. The final
# route put 173 km of Hiiumaa between the ferries, so the question flips: each
# later Rohuküla boat leaves fewer hours for the same distance, and the pace it
# demands is what separates the options.

opts <- tibble(dep = as.POSIXct(paste("2026-08-15", c("06:30", "08:30", "10:00")), tz = TZ)) |>
  mutate(
    hel      = dep + FERRIES$crossing_min[FERRIES$leg == "ROH-HEL"] * 60,
    need_kmh = TAL_TO_ROH / as.numeric(difftime(dep - BOARD_BUF * 3600, RACE_START, units = "hours")),
    hii_h    = as.numeric(difftime(SAT_EVENING - BOARD_BUF * 3600, hel, units = "hours")),
    hii_kmh  = HEL_TO_SOR / hii_h,
    dep_lbl  = format(dep, "%H:%M"),
    hel_lbl  = format(hel, "%H:%M")
  )

# Modelled arrival at the Rohuküla quay: the neutralised 11 km, then the
# opening-push pace the rest of the way.
arr_at_roh <- function(p) {
  eff <- p$push_kmh * (1 - p$push_frac)
  RACE_START + (NEUTRAL_H + (TAL_TO_ROH - NEUTRAL_KM) / eff) * 3600
}
arr_roh  <- arr_at_roh(prof_me)
arr_2025 <- arr_at_roh(PROFILES |> filter(profile == "Taavi 2025 tempo"))

# Verdict against the quay target (first Saturday sailing minus boarding), so
# the narrative can never contradict the arithmetic.
roh_gate <- opts$dep[1] - BOARD_BUF * 3600
gate_lbl <- function(arr) {
  m <- as.numeric(difftime(roh_gate, arr, units = "mins"))
  if (m >= 0) sprintf("**%.0f min varu** %s sihi peale", m, format(roh_gate, "%H:%M"))
  else        sprintf("**%.0f min üle** %s sihi — praam läinud", -m, format(roh_gate, "%H:%M"))
}

# ── Report ────────────────────────────────────────────────────────────────────

pct <- function(x) sprintf("%+.0f%%", 100 * x)

md <- c(
  "# Kõkõva 900 · 2026 — võistlusstrateegia",
  "",
  sprintf("> Genereeritud **%s** · rajamudel [`R/plan.R`](../R/plan.R) · sportlase andmed [`R/athlete.R`](../R/athlete.R)",
          format(Sys.time(), "%Y-%m-%d %H:%M %Z", tz = TZ)),
  "",
  sprintf("**Start** %s Hundipea · **limiit** %d päeva → %s · **rada** %.0f km (%.0f km sõitu + %.0f km praame), ~4000 m tõusu",
          fmt_et(RACE_START), RACE_LIMIT_D, fmt_et(RACE_END),
          TOTAL_ROUTE_KM, RIDDEN_KM, TOTAL_ROUTE_KM - RIDDEN_KM),
  "",
  "## Lühidalt",
  "",
  sprintf("Lõplik rada on beetast lühem (%.0f km sõitu), aga juhendi ~4000 m tõusuga läks beeta „lauge raja\" lubadus kaduma — 4,2 m/km on siiski TBR-i mõõdupuuga endiselt tasandik, nii et tõusudel püsiva võimsuse hoidmine ei ole ka siin piiraja.",
          RIDDEN_KM),
  "",
  sprintf("Selle võistluse otsustab **Sõru praam kilomeetril %s** — see sõidab võistlusaknas 2–3 korda päevas ja laupäevaõhtusest mahajäämine maksab %s h.",
          num_et(FERRIES$km_from[FERRIES$leg == "SOR-TRI"], 1), num_et(GAP_H, 1)),
  sprintf("Ja lõplik rada muutis värava olemust: Heltermaa ja Sõru vahel on nüüd %s km Hiiumaad, mitte 112. Varane Rohuküla praam ei ole enam mugavusküsimus — see on ainus tee õhtusele Sõru praamile.",
          num_et(HEL_TO_SOR, 0)),
  "",
  "## Laupäevane Sõru praam — ja mida iga Rohuküla praam tegelikult nõuab",
  "",
  "Beeta-rajal viisid kõik kolm hommikust Rohuküla praami samale 18:30 Sõru praamile ja vahe oli ainult Sõru kai peal ootamises.",
  "Lõplikul rajal jätab iga hilisem praam sama Hiiumaa jaoks vähem tunde:",
  "",
  "| Rohuküla praam | Nõutav tempo stardist | Heltermaal | Aega Sõru 18:30-ni | Nõutav tempo Hiiumaal |",
  "|----------------|----------------------:|------------|-------------------:|----------------------:|",
  paste0(sprintf("| **%s** | %s km/h elapsed | %s | %s h | %s km/h elapsed |",
                 opts$dep_lbl, num_et(opts$need_kmh, 1), opts$hel_lbl,
                 num_et(opts$hii_h, 1), num_et(opts$hii_kmh, 1)), collapse = "\n"),
  "",
  sprintf("**06:30 praam on ainus, mille Hiiumaa-nõue (%s km/h elapsed, valdavalt kruusal) on sinu jaoks teostatav.** 08:30 praamilt nõuab Hiiumaa %s km/h — esigrupi number — ja 10:00 praamilt ei jõua 18:30-ks enam keegi.",
          num_et(opts$hii_kmh[1], 1), num_et(opts$hii_kmh[2], 1)),
  "Juhend ütleb sama viisakamalt: kahe esimese hommikuse praamiga saabujad „peaksid jõudma\" — see tingiv kõneviis teeb 08:30 praamil rasket tööd.",
  "",
  "### Kus sina selles tabelis oled",
  "",
  sprintf("Luurega kalibreeritud mudel (%s km/h avaetapil, %d%% peatusi) toob su Rohukülla kell **%s** — %s.",
          num_et(prof_me$push_kmh, 1), round(100 * prof_me$push_frac),
          format(arr_roh, "%H:%M"), gate_lbl(arr_roh)),
  sprintf("2025. aasta vormi profiil (%s km/h, 6%% peatusi) annab **%s** — %s. Kaks sõltumatut numbrit, sama vastus.",
          num_et(PROFILES$push_kmh[PROFILES$profile == "Taavi 2025 tempo"], 1),
          format(arr_2025, "%H:%M"), gate_lbl(arr_2025)),
  "Mõõdetud alus: 30.07 luure — 157 km uksest Rohuküla kaini lõplikul rajal, Edge'i keskmine 21,8 km/h ([`recon_ride.md`](recon_ride.md)). Fail läks kaotsi ja tempo jäi mällu; võimsuse ja peatuste jaotuse mõõdab võistlus ise.",
  "",
  "### Murdepunkt — avaetapi sõidutempo, mis 18:30 praami veel püüab",
  "",
  "| Peatuste distsipliin | Vajalik sõidutempo avaetapil |",
  "|----------------------|-----------------------------:|",
  paste0(sprintf("| %s | **%s km/h** |", be$label,
                 ifelse(is.na(be$need_kmh), "ei õnnestu", num_et(be$need_kmh, 1))),
         collapse = "\n"),
  "",
  sprintf("Bisektsioon simulatsioonil endal — neutraliseeritud start, päris praamigraafik ja Hiiumaa lõik kõik sees. Võrdluseks: mudeli praegune eeldus on %s km/h, 2025. aasta mõõdetud avaetapp %s km/h.",
          num_et(prof_me$push_kmh, 1),
          num_et(PROFILES$push_kmh[PROFILES$profile == "Taavi 2025 tempo"], 1)),
  "",
  "### Plaan A ja plaan B",
  "",
  "**Plaan A — luure näitab murdepunkti-tempot:** sõida esimene öö läbi, ole Rohukülas enne 06:15, Hiiumaa ühe hooga, 18:30 Sõru praam, maga Saaremaal.",
  sprintf("**Plaan B — ei näita:** ära põleta end 08:30 praami nimel, see ei osta midagi — 18:30 jääb ikka püüdmata. Võta Hiiumaa rahulikult, maga korralikult (CP1 Palukülas km %s on köök ja dušid) ja ole pühapäeva 08:15 Sõru praamil. Hind: %s h hiljem Saaremaal, aga puhanuna ja ilma end esimese ööpäevaga tühjaks sõitmata.",
          num_et(waypoints$km[waypoints$type == "cp"][1], 0), num_et(GAP_H, 1)),
  "Luure (30.07) langetas otsuse: **plaan A**. Plaan B jääb tagataskusse juhuks, kui võistlusnädal toob haiguse, tehnilise rikke või tõsise vastutuule — siis on tal endiselt täpne hind ja täpne ööbimiskoht.",
  "",
  "### Kuidas iga Sõru praam kätte saada",
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
  if (!is.null(surface)) {
    seg_bounds <- list(c(0,                  FERRIES$km_from[1]),
                       c(FERRIES$km_to[1],   FERRIES$km_from[2]),
                       c(FERRIES$km_to[2],   FERRIES$km_from[3]),
                       c(FERRIES$km_to[3],   TOTAL_ROUTE_KM))
    shares <- lapply(seg_bounds, \(b) surf_share(b[1], b[2]))
    scol   <- function(k) sapply(shares, \(x) num_et(x[[k]] %||% 0, 0))
    total  <- surf_share(0, TOTAL_ROUTE_KM)
    c(
    "## Teekate — mõõdetud, mitte oletatud",
    "",
    "OSM-i `surface` sildid iga 250 m tagant, lõikude kaupa; sildita teel tuletab klass teetüübist.",
    "",
    "| Lõik | Asfalt | Kruus | Pinnas | Teadmata |",
    "|------|-------:|------:|-------:|---------:|",
    paste0(sprintf("| %s | %s%% | %s%% | %s%% | %s%% |",
      c("Avaetapp (0 → Rohuküla)", "Hiiumaa", "Saaremaa + Muhu", "Tagasitee mandril"),
      scol("asfalt"), scol("kruus"), scol("pinnas"), scol("teadmata")),
      collapse = "\n"),
    "",
    sprintf("**Avaetapp on %s%% asfalti** — juhend ütleb sama („umbes 50%% kõvakattega\"). Kiireim lõik on ta igal juhul, eraldi `push_kmh` jääb.",
            scol("asfalt")[1]),
    sprintf("Kogu raja peale: %s%% asfalti, %s%% kruusa, %s%% pinnast. Hiiumaa on ainus lõik, kus kruus on enamuses (%s%%) — täpselt seal, kus kell kõige rohkem loeb.",
            num_et(total$asfalt %||% 0, 0), num_et(total$kruus %||% 0, 0),
            num_et(total$pinnas %||% 0, 0), scol("kruus")[2]),
    "", "") } else character(0),
  "## Võimsus",
  "",
  sprintf("FTP **%d W** (%s W/kg), lävipulss %d, maksimaalne mõõdetud pulss %d.",
          ATHLETE$ftp_w, num_et(ATHLETE$ftp_w / ATHLETE$weight_kg, 2), ATHLETE$lthr, ATHLETE$hr_max),
  "",
  sprintf("2025. aasta Kõkõval hoidsid keskmist %s ja langus kolme suure etapi jooksul oli ainult **%s**.",
          "118 → 109 W", pct(ATHLETE$y2025$power_decay)),
  sprintf("TBR-il oli sama näitaja **%s** (115 → 84 W) — aga see oli 27 000 m tõusuga rada kuumuses.",
          pct(ATHLETE$tbr$power_decay)),
  "Tänavune rada on laugem ja ilm jahedam, seega vastupidavuse mõttes on 2025. aasta profiil õigem ootus —",
  "ka see rada oli tänavusest (juhendi ~4000 m) kaks korda mägisem.",
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
  "**Plaan:** sõida esimene öö läbi. See ei ole kangelaslikkus — plaan A puhul on see ainus viis olla 06:30 Rohuküla praamil,",
  "ja plaan B puhul ostab sama öö korraliku une Hiiumaal. Seejärel kaks ööd 4–5 h, magamiskoht valitud enne peatumist, mitte otsitud pärast.",
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
  "Juhend kinnitab, et osta saab kõigil praamidel — ka Sõru–Triigi Soelal —, aga 35 min ja väike laev teevad sellest täienduse, mitte söögikoha.",
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
