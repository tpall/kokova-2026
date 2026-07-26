# Kõkõva 900 (2026) — mainland recon ride, 29–31 July.
#
# This ride exists to measure one number. The whole race plan turns on whether
# the rider makes the Saturday 18:30 Sõru ferry, the break-even for that sits at
# 16.5–17.2 km/h moving, and the only figure we have (18.5 km/h) was set on last
# year's course — a different part of Estonia with five times the climbing and
# no ferries. Nothing in the training data says what he does on *this* surface
# with race kit aboard.
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

# Wednesday of the rider's free block. 21:00 deliberately mirrors the race start
# — same clock, same darkness, same shut shops.
DEP <- as.POSIXct("2026-07-29 21:00:00", tz = TZ)

# The mainland is ridden twice by the race: outbound to the Rohuküla quay, and
# inbound from Virtsu back to Tallinn past Haapsalu. Riding both makes a loop.
OUT_END    <- FERRIES$km_from[FERRIES$leg == "ROH-HEL"]   # 181.6, Rohuküla
HAAPSALU_KM <- 798.2                                       # where the return leg passes it
LINK_KM    <- 12                                           # Rohuküla → Haapsalu by road
RETURN_KM  <- TOTAL_ROUTE_KM - HAAPSALU_KM

resupply <- read_csv(file.path(DIR_DATA, "resupply.csv"), show_col_types = FALSE) |>
  filter(detour_m <= 700)

# The ferry gate, restated as a target for this ride: the 08:30 Rohuküla sailing
# is the one the race plan depends on, so the recon should aim at the same clock.
GATE_FERRY <- as.POSIXct("2026-07-30 08:30:00", tz = TZ)
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
  "Kogu võistlusplaan sõltub sellest, kas laupäevane 18:30 Sõru praam tuleb kätte.",
  sprintf("Murdepunkt on **16,5–17,2 km/h sõidukiirust** — ja ainus number, mis meil on (%s km/h), pärineb möödunud aasta rajalt: teine Eesti ots, viis korda rohkem tõusu, praame ei olnud.",
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
  "Sõida kolmapäeva õhtul **kell 21:00**, sama kellaaeg mis võistlusel. Siis on öö, pimedus, poed kinni ja väsimus samas faasis.",
  "",
  sprintf("**Sihtaeg Rohukülla: %s** — see on 08:30 praam miinus 15 min pardaleminekut, ehk %s tundi stardist.",
          fmt_et(GATE_FERRY - 0.25 * 3600), num_et(gate_h, 1)),
  sprintf("See nõuab **%s km/h elapsed** (kõik peatused sees).", num_et(gate_kmh, 1)),
  "",
  "| Kui jõuad | Siis võistlusel | Tähendus |",
  "|-----------|-----------------|----------|",
  sprintf("| enne %s | 08:30 praam | Sõru 18:30 on mugavalt käes |", format(GATE_FERRY - 0.25 * 3600, "%H:%M")),
  "| 08:15–09:45 | 10:00 praam | Sõru 18:30 käes, aga Hiiumaal ei tohi peatuda |",
  "| pärast 09:45 | 11:30 või hiljem | **Sõru 18:30 läinud, kaotad 13,4 h** |",
  "",
  "## Mida kirja panna",
  "",
  "Need neli numbrit lähevad otse mudelisse ja teevad kogu ülejäänud plaani usaldusväärseks:",
  "",
  "| Number | Kust | Mille jaoks |",
  "|--------|------|-------------|",
  "| Elapsed aeg Tallinn → Rohuküla | kell | Kas 08:30 värav on üldse realistlik |",
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
  sprintf("**Pärast seda on %s km Rohukülani ilma garanteeritud varustuseta.** Sama kehtib võistlusel.",
          num_et(gap_after_last, 0)),
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
  sprintf("| K 29.07, 21:00 | Väljasõit Tallinn → Rohuküla, öö läbi, täiskoormaga | %s km |", num_et(OUT_END, 0)),
  "| N 30.07 | Rohuküla → Haapsalu, maga välja, hinda varustust | ~12 km |",
  sprintf("| N 30.07 või R 31.07 | Tagasitee Haapsalu → Tallinn | %s km |", num_et(RETURN_KM, 0)),
  "",
  sprintf("Kaks järjestikust pikka päeva täiskoormaga on täpselt see, mida TBR-i debrief nõudis (durability, power-after-fatigue) — ja %s km on piisav, et väsimus oleks päris.",
          num_et(OUT_END + LINK_KM + RETURN_KM, 0)),
  "",
  "Kui kolmapäevast on aega ainult ühele päevale, tee **väljasõit**. See on ainus osa, mis mõõdab praamiväravat.",
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
