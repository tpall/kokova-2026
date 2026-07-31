# Kõkõva 900 · 2026 — mandriringi luuresõit

> Genereeritud **2026-07-31 17:19 EEST** · plaan sõiduks **N 30.07 21:00**

## Miks

Kogu võistlusplaan sõltub sellest, kas laupäevane 18:30 Sõru praam tuleb kätte — ja lõplikul rajal tähendab see 06:30 Rohuküla praami: Hiiumaad on praamide vahel nüüd 173 km ja hilisemad praamid nõuavad seal esigrupi tempot.
Murdepunkt on **~19,5–20,5 km/h avaetapi sõidukiirust** (täpne arv graafiku vastu: `race_strategy.md`) — ja ainus number, mis meil on (18,5 km/h kogu sõidu peale), pärineb möödunud aasta rajalt: teine Eesti ots, kaks korda rohkem tõusu, praame ei olnud.

**Treeninguandmetes ei ole ühtegi sõitu sellel pinnasel võistlusvarustusega.** See sõit teeb sellest mõõdetud numbri.

Ja teiseks: TBR lõppes tagumise rummu purunemisega. Koormatud veoülekande shakedown ei ole valikuline.

## Marsruut — raja mandriosa, mõlemad suunad

| Etapp | Rajal | Pikkus |
|-------|-------|-------:|
| Väljasõit: Tallinn Hundipea → Rohuküla | km 0 → 172,7 | 173 km |
| Ühendus: Rohuküla → Haapsalu | rajaväline | ~12 km |
| Tagasitee: Haapsalu → Tallinn | km 790,4 → 986,3 | 196 km |
| **Kokku** | | **~381 km** |

Haapsalu on rajal alles tagasiteel — väljasõit lõpeb Rohuküla sadamas, linnast 12 km lääne pool.
Nii saab mõlemad mandrilõigud õiges sõidusuunas läbi, ilma praamipiletita.

## ⏱️ Peamine mõõtmine: väljasõit stardib 21:00

Sõida neljapäeva õhtul **kell 21:00**, sama kellaaeg mis võistlusel. Siis on öö, pimedus, poed kinni ja väsimus samas faasis.

Külmetuse reegel enne starti: ainult kaelast-ülal sümptomid ja needki taandumas. Haigena mõõdetud tempo on vale number — see alahindab su võistlusvormi ja teeb kogu praamivärava analüüsi pessimistlikuks. Pigem lükka veel päev edasi kui sõida poolhaigena.

**Sihtaeg Rohukülla: R 31.07 06:15** — see on 06:30 praam miinus 15 min pardaleminekut, ehk 9,2 tundi stardist.
See nõuab **18,7 km/h elapsed** (kõik peatused sees). Võistlusel on esimesed 11 km neutraliseeritud (~30 min), nii et päris rajal on latt isegi veidi leebem kui omapäi sõites.

**Kui stardid hoopis hommikul** (nt kui enesetunne on hommikul sõidukorras ja tahad kohe minna): mõõt on seesama, ainult kellaajast lahti — **173 km kuni 9,2 tunniga** ehk 18,7 km/h elapsed. Päevasel sõidul on poed lahti ja valge; loe tulemus paari protsendi võrra optimistlikuks võistluse öise versiooni suhtes ja jäta meelde, et öine 24/7-punktide kontroll jääb siis tegemata.

| Kui jõuad | Siis võistlusel | Tähendus |
|-----------|-----------------|----------|
| enne 06:15 | 06:30 praam | Plaan A: Hiiumaa ühe hooga, Sõru 18:30 käes |
| 06:15–08:15 | 08:30 praam | Sõru 18:30 nõuab Hiiumaal ~20 km/h — sisuliselt plaan B |
| pärast 08:15 | 10:00 või hiljem | **Plaan B: maga Hiiumaal, pühapäeva 08:15 Sõru praam (−13,8 h)** |

## Mida kirja panna

Need neli numbrit lähevad otse mudelisse ja teevad kogu ülejäänud plaani usaldusväärseks:

| Number | Kust | Mille jaoks |
|--------|------|-------------|
| Elapsed aeg Tallinn → Rohuküla | kell | Kas 06:30 värav on üldse realistlik |
| Sõiduaeg (moving) ja sellest sõidukiirus | Garmin | `moving_kmh` mudelis — praegu oletus |
| Peatustele kulunud aeg | elapsed − moving | `push_frac` mudelis — praegu oletus |
| Keskmine ja NP võimsus | Garmin | Kas 120–130 W avaetapi siht on õige |

Lisaks: **proovi läbi 90 g süsivesikuid tunnis.** Treeninguprojektis ei ole ühtegi logitud toidukogust — see siht on praegu puhas teooria ja võistlus oleks esimene kord.

## Öine varustus väljasõidul

Öösel on lahti ainult ööpäevaringsed. Väljasõidul on neid 14, viimane km 121,3 (Krooning Risti tankla).

**Pärast seda on 51 km Rohukülani ilma garanteeritud varustuseta rajal.** Sama kehtib võistlusel.

Ainus väljapääs sellel lõigul on **Haapsalu, ~6 km rajast kõrval km 170,9 juures** (24/7 tanklad ja Rannarootsi Selver).
Ta ei ole varustusandmetes, sest Overpassi päring korjab ainult 1,5 km rajast — linnad, millest rada mööda hiilib, jäävad nähtamatuks.
Võistlusel on see 12 km edasi-tagasi vahetult enne praami; luuresõidul on see lihtsalt hea teada.

| km | Tüüp | Nimi | Lahtiolek |
|---:|------|------|-----------|
| 0,2 | fuel | Paljassaare Tankla | 24/7 |
| 1,1 | fuel | Circle K | 24/7 |
| 5,9 | fuel | Neste | 24/7 |
| 6,5 | fuel | Alexela | 24/7 |
| 6,5 | convenience | Circle K | 24/7 |
| 8,1 | fuel | Circle K automaat | 24/7 |
| 10,8 | fuel | Jetoil | 24/7 |
| 16,6 | fuel | Alexela | 24/7 |
| 17,5 | fuel | Circle K Tabasalu Automaat | 24/7 |
| 60,4 | fuel | Circle K | 24/7 |
| 60,4 | convenience | Circle K | 24/7 |
| 60,6 | fuel | Alexela | 24/7 |
| 60,6 | kiosk | Alexela Paus | 24/7 |
| 121,3 | fuel | Krooning Risti tankla | 24/7 |

Pane kirja, mis **tegelikult** lahti oli — OSM-i lahtiolekuajad on raporti nõrgim koht ja sinu tähelepanekud parandavad neid päris andmetega.

## Kuidas see nädalasse istub

Plaanis oli sellel nädalal 11 h, back-to-back 4,5 h + 3 h ja varustuse shakedown. See sõit katab kõik kolm korraga ja teeb seda päris rajal.

| Päev | Sisu | Maht |
|------|------|-----:|
| N 30.07 21:00 | Väljasõit Tallinn → Rohuküla, öö läbi, täiskoormaga | 173 km |
| R 31.07 | Rohuküla → Haapsalu, maga välja, hinda varustust | ~12 km |
| R 31.07 või L 01.08 | Tagasitee Haapsalu → Tallinn | 196 km |

Kaks järjestikust pikka päeva täiskoormaga on täpselt see, mida TBR-i debrief nõudis (durability, power-after-fatigue) — ja 381 km on piisav, et väsimus oleks päris.

Kui nädalast jätkub ainult üheks päevaks, tee **väljasõit**. See on ainus osa, mis mõõdab praamiväravat.
Tagasitee on väärtuslik durability jaoks, aga seda saab asendada.

## Tulemus — sõidetud N 30.07, start ~13.15

**157 km uksest Rohuküla sadamani mööda lõplikku rada, veidi üle 7 tunni.** Edge'i viimane meeles olev keskmine oli 21,8 km/h — see väli on taimeripõhine ehk sisuliselt sõidukeskmine; väheste lühikeste peatustega teeb see elapsed-tempoks ~21,0–21,8 km/h. Täiskoormaga, päeval, päev pärast külmetust.

Võistlustõlge: puuduv Hundipea algus lisab ~0,9 h (11 km neutraliseeritult + ~5 km oma tempoga), ehk **~8,1 h stardist kaini** — Rohukülas ~05:05, 06:15 sihtajast ~70 min varem. Ka päevase sõidu optimismi maha arvates on 06:30 praam varuga käes.

**Plaan A on mängus.** Murdepunkt (~20 km/h avaetapil) sai mõõdetud tulemusega kaetud; mudel on uuendatud (`R/plan.R` profiil „Taavi 2026 ootus": push 21,5 km/h × 7% peatusi, öine derate sees).

Ja sõit ei lõppenud kai peal: samal õhtul veel ~68 km laagrisse (**päev 1 kokku ~225 km täiskoormaga**) ning 31.07 ~90 km koju — kokku ~315 km kahe päevaga. See on täpselt see back-to-back koormatud plokk, mida TBR-i debrief nõudis (durability, power-after-fatigue), sõidetud päris raja peal ja ümber. Laagri- ja kojusõit on kellaga Garmin Connectis kirjas (68 km täielik; 75 km enne aku tühjenemist), nii et selle osa pulss ja tempo on päris andmetena olemas.

Kaks kadu, mõlemad talutavad:
- **Avaetapi fail läks kaotsi** (Edge'i tegevus kogemata kustutatud) — elapsed-tempo jäi mällu, aga 157 km moving/stopped jaotus, pulss ja võimsus (120–130 W sihi kontroll) jäid saamata. Need mõõdab võistlus ise.
- **Süsivesikud jäid sihist maha, vesi mitte:** teada olev sissevõtt (4 saiakest, 0,5 L koolat, ~1 L pudelijooki 4–5 tl suhkruga) ≈ 32 g/h, koos kaasavõetuga maksimaalselt ~68 g/h — 90 g/h siht on endiselt proovimata. Vedelikku kokku ~2,6 L (sh 1,1 L vett, täidetud Keilas) ehk ~360 ml/h — jaheda päeva higimääraga (345–502 ml/h alumine ots) täpselt paras. Stardieelse nädala ainus lahtine treeningpunkt on seega söömine: üks 2–3 h sõit 90 g/h peal.

Distsipliini poolelt: Ristil möödus 24/7 Circle K-st peatumata (sai Coopi kõrval söödud oma saiake) — täpselt see peatuste režiim, mida võistlusplaan eeldab.

### Õppetunnid

1. **21,8 tuli vastutuulega.** Suurem osa avaetapist oli kerge-mõõdukas vastutuul ja false flat, jalad päev pärast külmetust poolest maast hapud — ja keskmine ikkagi 21,8. Vaikse ilmaga ja tervena on varu suurem; värava-järeldus muutub ainult kindlamaks. Raskeimad lõigud olid kruus ja pinnas enne ja pärast Keilat — kattub `surface.csv` pildiga.
2. **Söö kella, mitte enesetunde järgi.** Teisel päeval jäi Padise lõuna heaolutunde tõttu vahele — ja kaks tundi hiljem, pärast Tabasalut, tuli bonk: kaks batoonikest päästsid, aga viimased 10 km roomasid. Võistlusel: iga 45–60 min midagi, ka siis (eriti siis), kui tunne on hea. Täpselt seda 90 g/h proovisõit harjutabki.
3. **Asend ja iste vajavad enne starti tähelepanu.** 315 km ploki lõpuks ei püsinud hea sõiduasend ja tekkisid kerged istumishaavandid. Osa on lihtsalt madala baasi väsimus, aga kontrolli sel nädalal sadula kalle ja ette-taha asend ning kui 90 mm pikkus tundub ka värskena pikk, proovi 75–80 mm vart — koos proovisõiduga, mitte esimest korda võistlusel. Võistluskotti: istmekreem.
4. **29 °C juhtus ka Eestis.** Teise päeva lõpu tegi raskeks kuumus + vastutuul, mitte distants. Joomisplaani kuuma stsenaarium (500+ ml/h) vajab sama läbimõtlemist kui jaheda oma — 360 ml/h oli paras jahedale päevale, mitte augusti kuumalainele.

## Pärast sõitu

~~Uuenda `R/plan.R` profiili „Taavi 2026 ootus" mõõdetud numbritega ja jooksuta `make strategy`.~~ Tehtud 31.07 — praamivärava analüüs jookseb nüüd mõõdetud tempo pealt.

---

Generaator [`R/recon_ride.R`](../R/recon_ride.R) · strateegia [`race_strategy.md`](race_strategy.md) · varustus [`resupply.md`](resupply.md)

