# Kõkõva 900 (2026) — mainland recon ride, 30 July – 1 August.
#
# This ride exists to measure one number. The whole race plan turns on whether
# the rider makes the Saturday 18:30 Sõru ferry, and on the final route that
# means the 06:30 Rohuküla boat: 173 km of Hiiumaa now sits between the
# ferries, so the later boats demand front-group gravel paces. The break-even
# opening speed sits around 19.5–20.5 km/h moving (race_strategy.md computes it
# against the live timetable), and the only figure we have (20.5 km/h on the
# opening push, 2025) was set on last year's course — a different part of
# Estonia with twice the climbing and no ferries. Nothing in the training data
# says what he does on *this* surface with race kit aboard.
#
# It also discharges the other debt from TBR 2026: that race ended on a rear-hub
# failure, so a loaded drivetrain shakedown is not optional.
#
# Run: make recon   (or  Rscript R/recon_ride.R)

suppressPackageStartupMessages({
  library(dplyr)
  library(tibble)
  library(purrr)
  library(readr)
})

source("R/plan.R")
source("R/athlete.R")

OUT_MD <- file.path(DIR_REPORTS, "recon_ride.md")

# Thursday — slipped a day from the original Wednesday plan (head cold on the
# 29th; a sick all-nighter measures the wrong number and deepens the cold two
# weeks before the start). 21:00 deliberately mirrors the race start — same
# clock, same darkness, same shut shops. The day labels below derive from DEP,
# so a further slip is this one line.
DEP <- as.POSIXct("2026-07-30 21:00:00", tz = TZ)

# Weekday names in the genitive, for running text ("neljapäeva õhtul").
ET_WDAY_GEN <- c("esmaspäeva", "teisipäeva", "kolmapäeva", "neljapäeva",
                 "reede", "laupäeva", "pühapäeva")
DEP_WD <- ET_WDAY_GEN[as.integer(format(DEP, "%u"))]

# The mainland is ridden twice by the race: outbound to the Rohuküla quay, and
# inbound from Virtsu back to Tallinn past Haapsalu. Riding both makes a loop.
OUT_END    <- FERRIES$km_from[FERRIES$leg == "ROH-HEL"]   # 172.7, Rohuküla
HAAPSALU_KM <- 790.4                                       # where the return leg passes it (2.9 km off)
LINK_KM    <- 12                                           # Rohuküla → Haapsalu by road
RETURN_KM  <- TOTAL_ROUTE_KM - HAAPSALU_KM

resupply <- read_csv(file.path(DIR_DATA, "resupply.csv"), show_col_types = FALSE) |>
  filter(detour_m <= 700)

# The ferry gate, restated as a target for this ride: on the final route the
# race plan depends on the 06:30 Rohuküla sailing (the later boats leave too few
# hours for 173 km of Hiiumaa), so the recon aims at the same clock on the
# morning after departure.
GATE_FERRY <- as.POSIXct(format(DEP + 86400, "%Y-%m-%d 06:30:00"), tz = TZ)
gate_h     <- as.numeric(difftime(GATE_FERRY - 0.25 * 3600, DEP, units = "hours"))
gate_kmh   <- OUT_END / gate_h

# What is open on the outbound leg during the night, at a range of paces. This is
# the same question the race asks, and the recon can ground-truth it.
night_stock <- resupply |>
  filter(km <= OUT_END, kind %in% c("supermarket", "convenience", "general", "kiosk", "fuel")) |>
  arrange(km)

is247 <- grepl("24/7", night_stock$hours, fixed = TRUE)
night_stock$open247 <- ifelse(is.na(is247), FALSE, is247)

last247 <- night_stock |> filter(open247) |> slice(n())
gap_after_last <- OUT_END - last247$km

md <- c(
  "# Kõkõva 900 · 2026 — mandriringi luuresõit",
  "",
  sprintf("> Genereeritud **%s** · plaan sõiduks **%s**",
          format(Sys.time(), "%Y-%m-%d %H:%M %Z", tz = TZ), fmt_et(DEP)),
  "",
  "## Miks",
  "",
  "Kogu võistlusplaan sõltub sellest, kas laupäevane 18:30 Sõru praam tuleb kätte — ja lõplikul rajal tähendab see 06:30 Rohuküla praami: Hiiumaad on praamide vahel nüüd 173 km ja hilisemad praamid nõuavad seal esigrupi tempot.",
  sprintf("Murdepunkt on **~19,5–20,5 km/h avaetapi sõidukiirust** (täpne arv graafiku vastu: `race_strategy.md`) — ja ainus number, mis meil on (%s km/h kogu sõidu peale), pärineb möödunud aasta rajalt: teine Eesti ots, kaks korda rohkem tõusu, praame ei olnud.",
          num_et(ATHLETE$y2025$moving_kmh, 1)),
  "",
  "**Treeninguandmetes ei ole ühtegi sõitu sellel pinnasel võistlusvarustusega.** See sõit teeb sellest mõõdetud numbri.",
  "",
  "Ja teiseks: TBR lõppes tagumise rummu purunemisega. Koormatud veoülekande shakedown ei ole valikuline.",
  "",
  "## Marsruut — raja mandriosa, mõlemad suunad",
  "",
  "| Etapp | Rajal | Pikkus |",
  "|-------|-------|-------:|",
  sprintf("| Väljasõit: Tallinn Hundipea → Rohuküla | km 0 → %s | %s km |",
          num_et(OUT_END, 1), num_et(OUT_END, 0)),
  sprintf("| Ühendus: Rohuküla → Haapsalu | rajaväline | ~%d km |", LINK_KM),
  sprintf("| Tagasitee: Haapsalu → Tallinn | km %s → %s | %s km |",
          num_et(HAAPSALU_KM, 1), num_et(TOTAL_ROUTE_KM, 1), num_et(RETURN_KM, 0)),
  sprintf("| **Kokku** | | **~%s km** |", num_et(OUT_END + LINK_KM + RETURN_KM, 0)),
  "",
  "Haapsalu on rajal alles tagasiteel — väljasõit lõpeb Rohuküla sadamas, linnast 12 km lääne pool.",
  "Nii saab mõlemad mandrilõigud õiges sõidusuunas läbi, ilma praamipiletita.",
  "",
  "## ⏱️ Peamine mõõtmine: väljasõit stardib 21:00",
  "",
  sprintf("Sõida %s õhtul **kell 21:00**, sama kellaaeg mis võistlusel. Siis on öö, pimedus, poed kinni ja väsimus samas faasis.", DEP_WD),
  "",
  "Külmetuse reegel enne starti: ainult kaelast-ülal sümptomid ja needki taandumas. Haigena mõõdetud tempo on vale number — see alahindab su võistlusvormi ja teeb kogu praamivärava analüüsi pessimistlikuks. Pigem lükka veel päev edasi kui sõida poolhaigena.",
  "",
  sprintf("**Sihtaeg Rohukülla: %s** — see on %s praam miinus 15 min pardaleminekut, ehk %s tundi stardist.",
          fmt_et(GATE_FERRY - 0.25 * 3600), format(GATE_FERRY, "%H:%M"), num_et(gate_h, 1)),
  sprintf("See nõuab **%s km/h elapsed** (kõik peatused sees). Võistlusel on esimesed 11 km neutraliseeritud (~30 min), nii et päris rajal on latt isegi veidi leebem kui omapäi sõites.",
          num_et(gate_kmh, 1)),
  "",
  sprintf("**Kui stardid hoopis hommikul** (nt kui enesetunne on hommikul sõidukorras ja tahad kohe minna): mõõt on seesama, ainult kellaajast lahti — **%s km kuni %s tunniga** ehk %s km/h elapsed. Päevasel sõidul on poed lahti ja valge; loe tulemus paari protsendi võrra optimistlikuks võistluse öise versiooni suhtes ja jäta meelde, et öine 24/7-punktide kontroll jääb siis tegemata.",
          num_et(OUT_END, 0), num_et(gate_h, 1), num_et(gate_kmh, 1)),
  "",
  "| Kui jõuad | Siis võistlusel | Tähendus |",
  "|-----------|-----------------|----------|",
  sprintf("| enne %s | 06:30 praam | Plaan A: Hiiumaa ühe hooga, Sõru 18:30 käes |", format(GATE_FERRY - 0.25 * 3600, "%H:%M")),
  "| 06:15–08:15 | 08:30 praam | Sõru 18:30 nõuab Hiiumaal ~20 km/h — sisuliselt plaan B |",
  "| pärast 08:15 | 10:00 või hiljem | **Plaan B: maga Hiiumaal, pühapäeva 08:15 Sõru praam (−13,8 h)** |",
  "",
  "## Mida kirja panna",
  "",
  "Need neli numbrit lähevad otse mudelisse ja teevad kogu ülejäänud plaani usaldusväärseks:",
  "",
  "| Number | Kust | Mille jaoks |",
  "|--------|------|-------------|",
  "| Elapsed aeg Tallinn → Rohuküla | kell | Kas 06:30 värav on üldse realistlik |",
  "| Sõiduaeg (moving) ja sellest sõidukiirus | Garmin | `moving_kmh` mudelis — praegu oletus |",
  "| Peatustele kulunud aeg | elapsed − moving | `push_frac` mudelis — praegu oletus |",
  "| Keskmine ja NP võimsus | Garmin | Kas 120–130 W avaetapi siht on õige |",
  "",
  sprintf("Lisaks: **proovi läbi %d g süsivesikuid tunnis.** Treeninguprojektis ei ole ühtegi logitud toidukogust — see siht on praegu puhas teooria ja võistlus oleks esimene kord.",
          ATHLETE$carb_g_h_target),
  "",
  "## Öine varustus väljasõidul",
  "",
  sprintf("Öösel on lahti ainult ööpäevaringsed. Väljasõidul on neid %d, viimane km %s (%s).",
          sum(night_stock$open247), num_et(last247$km, 1), last247$name),
  "",
  sprintf("**Pärast seda on %s km Rohukülani ilma garanteeritud varustuseta rajal.** Sama kehtib võistlusel.",
          num_et(gap_after_last, 0)),
  "",
  "Ainus väljapääs sellel lõigul on **Haapsalu, ~6 km rajast kõrval km 170,9 juures** (24/7 tanklad ja Rannarootsi Selver).",
  "Ta ei ole varustusandmetes, sest Overpassi päring korjab ainult 1,5 km rajast — linnad, millest rada mööda hiilib, jäävad nähtamatuks.",
  "Võistlusel on see 12 km edasi-tagasi vahetult enne praami; luuresõidul on see lihtsalt hea teada.",
  "",
  "| km | Tüüp | Nimi | Lahtiolek |",
  "|---:|------|------|-----------|")
for (i in which(night_stock$open247)) {
  s <- night_stock[i, ]
  md <- c(md, sprintf("| %s | %s | %s | 24/7 |", num_et(s$km, 1), s$kind, coalesce(s$name, "(nimetu)")))
}

md <- c(md, "",
  "Pane kirja, mis **tegelikult** lahti oli — OSM-i lahtiolekuajad on raporti nõrgim koht ja sinu tähelepanekud parandavad neid päris andmetega.",
  "",
  "## Kuidas see nädalasse istub",
  "",
  "Plaanis oli sellel nädalal 11 h, back-to-back 4,5 h + 3 h ja varustuse shakedown. See sõit katab kõik kolm korraga ja teeb seda päris rajal.",
  "",
  "| Päev | Sisu | Maht |",
  "|------|------|-----:|",
  sprintf("| %s | Väljasõit Tallinn → Rohuküla, öö läbi, täiskoormaga | %s km |",
          fmt_et(DEP), num_et(OUT_END, 0)),
  sprintf("| %s | Rohuküla → Haapsalu, maga välja, hinda varustust | ~12 km |",
          fmt_et(DEP + 86400, with_time = FALSE)),
  sprintf("| %s või %s | Tagasitee Haapsalu → Tallinn | %s km |",
          fmt_et(DEP + 86400, with_time = FALSE), fmt_et(DEP + 2 * 86400, with_time = FALSE),
          num_et(RETURN_KM, 0)),
  "",
  sprintf("Kaks järjestikust pikka päeva täiskoormaga on täpselt see, mida TBR-i debrief nõudis (durability, power-after-fatigue) — ja %s km on piisav, et väsimus oleks päris.",
          num_et(OUT_END + LINK_KM + RETURN_KM, 0)),
  "",
  "Kui nädalast jätkub ainult üheks päevaks, tee **väljasõit**. See on ainus osa, mis mõõdab praamiväravat.",
  "Tagasitee on väärtuslik durability jaoks, aga seda saab asendada.",
  "",
  "## Pärast sõitu",
  "",
  "Uuenda `R/plan.R` profiili „Taavi 2026 ootus\" mõõdetud numbritega ja jooksuta `make strategy`.",
  "Kogu praamivärava analüüs arvutatakse siis päris andmete pealt, mitte oletuse pealt.",
  "",
  "---",
  "",
  "Generaator [`R/recon_ride.R`](../R/recon_ride.R) · strateegia [`race_strategy.md`](race_strategy.md) · varustus [`resupply.md`](resupply.md)",
  "")

writeLines(md, OUT_MD)
cat("Wrote", OUT_MD, "\n")
