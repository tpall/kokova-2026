# Kõkõva 900 · 2026 — mandriringi luuresõit

> Genereeritud **2026-07-26 20:58 EEST** · plaan sõiduks **K 29.07 21:00**

## Miks

Kogu võistlusplaan sõltub sellest, kas laupäevane 18:30 Sõru praam tuleb kätte.
Murdepunkt on **16,5–17,2 km/h sõidukiirust** — ja ainus number, mis meil on (18,5 km/h), pärineb möödunud aasta rajalt: teine Eesti ots, viis korda rohkem tõusu, praame ei olnud.

**Treeninguandmetes ei ole ühtegi sõitu sellel pinnasel võistlusvarustusega.** See sõit teeb sellest mõõdetud numbri.

Ja teiseks: TBR lõppes tagumise rummu purunemisega. Koormatud veoülekande shakedown ei ole valikuline.

## Marsruut — raja mandriosa, mõlemad suunad

| Etapp | Rajal | Pikkus |
|-------|-------|-------:|
| Väljasõit: Tallinn Hundipea → Rohuküla | km 0 → 181,6 | 182 km |
| Ühendus: Rohuküla → Haapsalu | rajaväline | ~12 km |
| Tagasitee: Haapsalu → Tallinn | km 798,2 → 984,6 | 186 km |
| **Kokku** | | **~380 km** |

Haapsalu on rajal alles tagasiteel — väljasõit lõpeb Rohuküla sadamas, linnast 12 km lääne pool.
Nii saab mõlemad mandrilõigud õiges sõidusuunas läbi, ilma praamipiletita.

## ⏱️ Peamine mõõtmine: väljasõit stardib 21:00

Sõida kolmapäeva õhtul **kell 21:00**, sama kellaaeg mis võistlusel. Siis on öö, pimedus, poed kinni ja väsimus samas faasis.

**Sihtaeg Rohukülla: N 30.07 08:15** — see on 08:30 praam miinus 15 min pardaleminekut, ehk 11,2 tundi stardist.
See nõuab **16,1 km/h elapsed** (kõik peatused sees).

| Kui jõuad | Siis võistlusel | Tähendus |
|-----------|-----------------|----------|
| enne 08:15 | 08:30 praam | Sõru 18:30 on mugavalt käes |
| 08:15–09:45 | 10:00 praam | Sõru 18:30 käes, aga Hiiumaal ei tohi peatuda |
| pärast 09:45 | 11:30 või hiljem | **Sõru 18:30 läinud, kaotad 13,4 h** |

## Mida kirja panna

Need neli numbrit lähevad otse mudelisse ja teevad kogu ülejäänud plaani usaldusväärseks:

| Number | Kust | Mille jaoks |
|--------|------|-------------|
| Elapsed aeg Tallinn → Rohuküla | kell | Kas 08:30 värav on üldse realistlik |
| Sõiduaeg (moving) ja sellest sõidukiirus | Garmin | `moving_kmh` mudelis — praegu oletus |
| Peatustele kulunud aeg | elapsed − moving | `push_frac` mudelis — praegu oletus |
| Keskmine ja NP võimsus | Garmin | Kas 120–130 W avaetapi siht on õige |

Lisaks: **proovi läbi 90 g süsivesikuid tunnis.** Treeninguprojektis ei ole ühtegi logitud toidukogust — see siht on praegu puhas teooria ja võistlus oleks esimene kord.

## Öine varustus väljasõidul

Öösel on lahti ainult ööpäevaringsed. Väljasõidul on neid 12, viimane km 130,3 (Krooning Risti tankla).

**Pärast seda on 51 km Rohukülani ilma garanteeritud varustuseta rajal.** Sama kehtib võistlusel.

Ainus väljapääs sellel lõigul on **Haapsalu, ~6 km rajast kõrval km 179,8 juures** (24/7 tanklad ja Rannarootsi Selver).
Ta ei ole varustusandmetes, sest Overpassi päring korjab ainult 1,5 km rajast — linnad, millest rada mööda hiilib, jäävad nähtamatuks.
Võistlusel on see 12 km edasi-tagasi vahetult enne praami; luuresõidul on see lihtsalt hea teada.

| km | Tüüp | Nimi | Lahtiolek |
|---:|------|------|-----------|
| 15,1 | fuel | Neste | 24/7 |
| 15,6 | fuel | Alexela | 24/7 |
| 15,6 | convenience | Circle K | 24/7 |
| 17,3 | fuel | Circle K automaat | 24/7 |
| 20,0 | fuel | Jetoil | 24/7 |
| 26,2 | fuel | Alexela | 24/7 |
| 27,2 | fuel | Circle K Tabasalu Automaat | 24/7 |
| 69,4 | fuel | Circle K | 24/7 |
| 69,4 | convenience | Circle K | 24/7 |
| 69,6 | fuel | Alexela | 24/7 |
| 69,6 | kiosk | Alexela Paus | 24/7 |
| 130,3 | fuel | Krooning Risti tankla | 24/7 |

Pane kirja, mis **tegelikult** lahti oli — OSM-i lahtiolekuajad on raporti nõrgim koht ja sinu tähelepanekud parandavad neid päris andmetega.

## Kuidas see nädalasse istub

Plaanis oli sellel nädalal 11 h, back-to-back 4,5 h + 3 h ja varustuse shakedown. See sõit katab kõik kolm korraga ja teeb seda päris rajal.

| Päev | Sisu | Maht |
|------|------|-----:|
| K 29.07, 21:00 | Väljasõit Tallinn → Rohuküla, öö läbi, täiskoormaga | 182 km |
| N 30.07 | Rohuküla → Haapsalu, maga välja, hinda varustust | ~12 km |
| N 30.07 või R 31.07 | Tagasitee Haapsalu → Tallinn | 186 km |

Kaks järjestikust pikka päeva täiskoormaga on täpselt see, mida TBR-i debrief nõudis (durability, power-after-fatigue) — ja 380 km on piisav, et väsimus oleks päris.

Kui kolmapäevast on aega ainult ühele päevale, tee **väljasõit**. See on ainus osa, mis mõõdab praamiväravat.
Tagasitee on väärtuslik durability jaoks, aga seda saab asendada.

## Pärast sõitu

Uuenda `R/plan.R` profiili „Taavi 2026 ootus" mõõdetud numbritega ja jooksuta `make strategy`.
Kogu praamivärava analüüs arvutatakse siis päris andmete pealt, mitte oletuse pealt.

---

Generaator [`R/recon_ride.R`](../R/recon_ride.R) · strateegia [`race_strategy.md`](race_strategy.md) · varustus [`resupply.md`](resupply.md)

