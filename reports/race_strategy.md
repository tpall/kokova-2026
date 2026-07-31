# Kõkõva 900 · 2026 — võistlusstrateegia

> Genereeritud **2026-07-31 17:22 EEST** · rajamudel [`R/plan.R`](../R/plan.R) · sportlase andmed [`R/athlete.R`](../R/athlete.R)

**Start** R 14.08 21:00 Hundipea · **limiit** 7 päeva → R 21.08 21:00 · **rada** 986 km (942 km sõitu + 45 km praame), ~4000 m tõusu

## Lühidalt

Lõplik rada on beetast lühem (942 km sõitu), aga juhendi ~4000 m tõusuga läks beeta „lauge raja" lubadus kaduma — 4,2 m/km on siiski TBR-i mõõdupuuga endiselt tasandik, nii et tõusudel püsiva võimsuse hoidmine ei ole ka siin piiraja.

Selle võistluse otsustab **Sõru praam kilomeetril 368,4** — see sõidab võistlusaknas 2–3 korda päevas ja laupäevaõhtusest mahajäämine maksab 13,8 h.
Ja lõplik rada muutis värava olemust: Heltermaa ja Sõru vahel on nüüd 173 km Hiiumaad, mitte 112. Varane Rohuküla praam ei ole enam mugavusküsimus — see on ainus tee õhtusele Sõru praamile.

## Laupäevane Sõru praam — ja mida iga Rohuküla praam tegelikult nõuab

Beeta-rajal viisid kõik kolm hommikust Rohuküla praami samale 18:30 Sõru praamile ja vahe oli ainult Sõru kai peal ootamises.
Lõplikul rajal jätab iga hilisem praam sama Hiiumaa jaoks vähem tunde:

| Rohuküla praam | Nõutav tempo stardist | Heltermaal | Aega Sõru 18:30-ni | Nõutav tempo Hiiumaal |
|----------------|----------------------:|------------|-------------------:|----------------------:|
| **06:30** | 18,7 km/h elapsed | 07:45 | 10,5 h | 16,5 km/h elapsed |
| **08:30** | 15,4 km/h elapsed | 09:45 | 8,5 h | 20,4 km/h elapsed |
| **10:00** | 13,5 km/h elapsed | 11:15 | 7,0 h | 24,7 km/h elapsed |

**06:30 praam on ainus, mille Hiiumaa-nõue (16,5 km/h elapsed, valdavalt kruusal) on sinu jaoks teostatav.** 08:30 praamilt nõuab Hiiumaa 20,4 km/h — esigrupi number — ja 10:00 praamilt ei jõua 18:30-ks enam keegi.
Juhend ütleb sama viisakamalt: kahe esimese hommikuse praamiga saabujad „peaksid jõudma" — see tingiv kõneviis teeb 08:30 praamil rasket tööd.

### Kus sina selles tabelis oled

Luurega kalibreeritud mudel (21,5 km/h avaetapil, 7% peatusi) toob su Rohukülla kell **05:35** — **40 min varu** 06:15 sihi peale.
2025. aasta vormi profiil (20,5 km/h, 6% peatusi) annab **05:53** — **22 min varu** 06:15 sihi peale. Kaks sõltumatut numbrit, sama vastus.
Mõõdetud alus: 30.07 luure — 157 km uksest Rohuküla kaini lõplikul rajal, Edge'i keskmine 21,8 km/h ([`recon_ride.md`](recon_ride.md)). Fail läks kaotsi ja tempo jäi mällu; võimsuse ja peatuste jaotuse mõõdab võistlus ise.

### Murdepunkt — avaetapi sõidutempo, mis 18:30 praami veel püüab

| Peatuste distsipliin | Vajalik sõidutempo avaetapil |
|----------------------|-----------------------------:|
| praegune eeldus (10% peatusi) | **20,0 km/h** |
| 2025. aasta distsipliin (6%) | **19,1 km/h** |
| peaaegu ei peatu (3%) | **18,5 km/h** |

Bisektsioon simulatsioonil endal — neutraliseeritud start, päris praamigraafik ja Hiiumaa lõik kõik sees. Võrdluseks: mudeli praegune eeldus on 21,5 km/h, 2025. aasta mõõdetud avaetapp 20,5 km/h.

### Plaan A ja plaan B

**Plaan A — luure näitab murdepunkti-tempot:** sõida esimene öö läbi, ole Rohukülas enne 06:15, Hiiumaa ühe hooga, 18:30 Sõru praam, maga Saaremaal.
**Plaan B — ei näita:** ära põleta end 08:30 praami nimel, see ei osta midagi — 18:30 jääb ikka püüdmata. Võta Hiiumaa rahulikult, maga korralikult (CP1 Palukülas km 222 on köök ja dušid) ja ole pühapäeva 08:15 Sõru praamil. Hind: 13,8 h hiljem Saaremaal, aga puhanuna ja ilma end esimese ööpäevaga tühjaks sõitmata.
Luure (30.07) langetas otsuse: **plaan A**. Plaan B jääb tagataskusse juhuks, kui võistlusnädal toob haiguse, tehnilise rikke või tõsise vastutuule — siis on tal endiselt täpne hind ja täpne ööbimiskoht.

### Kuidas iga Sõru praam kätte saada

Ainus tee Hiiumaale on Rohuküla praam, seega iga Sõru väljumine tähendab konkreetset viimast Rohuküla praami.

| Sõru väljumine | Viimane Rohuküla praam | Heltermaal | Tallinn→Rohuküla nõutav tempo | Heltermaa→Sõru nõutav tempo |
|----------------|------------------------|------------|------------------------------:|----------------------------:|
| L 15.08 18:30 | L 15.08 06:30 | 07:45 | 18,7 km/h | 16,5 km/h |

Tempod on **elapsed**, mitte sõidutempo — sisaldavad kõiki peatusi. Sinu 2025. aasta avaetapp oli 349 km 17,9 tunniga, mis teeb 19,6 km/h elapsed. See on täpselt see number, mida siin vaja.

## Vorm — kaks numbrit, mis näitavad vastassuunda

| Näitaja | Väärtus | Tähendus |
|---------|---------|----------|
| HRV nädala keskmine | 61 | 22.–24.07 seis — üle enda 2026. aasta keskmise (59,8) |
| Kroonilne koormus | 323 | **39% aprilli tipust (833)** — 24.07 seis, enne luureplokki |
| Pikim sõit pärast TBR-i | 225 km | 30. juuli: luure + laagrisõit ühe päevaga, täiskoormaga |
| Luureplokk 30.–31.07 | ~315 km | Kaks järjestikust koormatud päeva (225 + ~90 km) |

Detreening-lugu sai luureplokiga sisulise vastuse: 225 km päev pluss ~90 km järgmisel hommikul on täpselt see
back-to-back, mida TBR-i debrief nõudis, ja avaetapi tempo tuli 2025. aasta vormist *kõrgem*, mitte madalam.
Teine pool: Garmin küsis 225 km päeva järel **95 h taastumist** — sisuliselt skaala lagi. Tipptempo on alles, aga suure päeva hind on madala kroonilise koormuse pealt praegu maksimumilähedane.
Just seepärast jääb mitmepäevane püsikiirus mudelis (17,5 km/h) 2025. omast (18,5) allapoole — ja seepärast on järgmised kaks nädalat kerged: taastumine on nüüd treening.

## Teekate — mõõdetud, mitte oletatud

OSM-i `surface` sildid iga 250 m tagant, lõikude kaupa; sildita teel tuletab klass teetüübist.

| Lõik | Asfalt | Kruus | Pinnas | Teadmata |
|------|-------:|------:|-------:|---------:|
| Avaetapp (0 → Rohuküla) | 53% | 43% | 2% | 2% |
| Hiiumaa | 38% | 58% | 0% | 3% |
| Saaremaa + Muhu | 55% | 37% | 6% | 3% |
| Tagasitee mandril | 54% | 39% | 5% | 1% |

**Avaetapp on 53% asfalti** — juhend ütleb sama („umbes 50% kõvakattega"). Kiireim lõik on ta igal juhul, eraldi `push_kmh` jääb.
Kogu raja peale: 51% asfalti, 42% kruusa, 4% pinnast. Hiiumaa on ainus lõik, kus kruus on enamuses (58%) — täpselt seal, kus kell kõige rohkem loeb.


## Võimsus

FTP **247 W** (3,22 W/kg), lävipulss 150, maksimaalne mõõdetud pulss 170.

2025. aasta Kõkõval hoidsid keskmist 118 → 109 W ja langus kolme suure etapi jooksul oli ainult **-8%**.
TBR-il oli sama näitaja **-27%** (115 → 84 W) — aga see oli 27 000 m tõusuga rada kuumuses.
Tänavune rada on laugem ja ilm jahedam, seega vastupidavuse mõttes on 2025. aasta profiil õigem ootus —
ka see rada oli tänavusest (juhendi ~4000 m) kaks korda mägisem.

| Lõik | Keskmine | NP | Miks |
|------|---------:|---:|------|
| Avaetapp (0 → Sõru) | 120–130 W | 145–155 W | Ainus koht, kus tasub kulutada — praam ei oota |
| Päev 2–3 | 105–115 W | 130–140 W | 2025. aasta tegelik püsitase |
| Lõpuosa | 100–110 W | 125–135 W | Mandril, kui praamid on seljataga |

Z2 on 138–185 W. Avaetapi 145–155 W NP on Z2 keskosa — see ei ole julge number, see on lihtsalt mitte-peatumine.

## Uni — sinu suurim ajakadu

TBR-il seisid magamiseks **36,8 h**, et saada kätte **22,2 h** tegelikku und — 60% efektiivsus.
Umbes **14,6 tundi** võistlusest kulus pikali, aga ärkvel. Kogu peatusaeg oli 45,9 h vs välja mediaan 33,8 h — vahe on praktiliselt seesama.

2025. aasta Kõkõval tegid vastupidist ja see töötas: läbi esimese öö (349 km), siis kokku ainult 14,8 h und terve 90-tunnise võistluse peale. Rada oli teine, aga see on käitumine, mitte maastik — kandub üle.

**Plaan:** sõida esimene öö läbi. See ei ole kangelaslikkus — plaan A puhul on see ainus viis olla 06:30 Rohuküla praamil,
ja plaan B puhul ostab sama öö korraliku une Hiiumaal. Seejärel kaks ööd 4–5 h, magamiskoht valitud enne peatumist, mitte otsitud pärast.

## Praamid ja päevakava

| km | Sündmus | Aeg (Taavi 2026 ootus) |
|---:|---------|------------------------|
| 173 | Rohuküla→Heltermaa L 15.08 06:30 (ootamine 0.9 h) | L 15.08 05:35 |
| 368 | Sõru→Triigi L 15.08 18:30 (ootamine 2.1 h) | L 15.08 16:24 |
| 521 | uni 6.0 h | P 16.08 02:00 |
| 692 | Kuivastu→Virtsu P 16.08 22:50 (ootamine 0.5 h) | P 16.08 22:21 |
| 732 | uni 6.0 h | E 17.08 02:00 |
| 946 | uni 6.0 h | T 18.08 02:00 |
| 986 | **Finiš** | **T 18.08 11:22** (86 h) |

Laevadel on toit: TS Laevade praamidel (Rohuküla–Heltermaa 75 min, Kuivastu–Virtsu 27 min) on restoran ja R-Kiosk.
**75-minutiline Hiiumaa ülesõit on raja parim söögikoht** ja ainus, mis on laupäeva hommikul lahti, kui saarepoed veel magavad.
Juhend kinnitab, et osta saab kõigil praamidel — ka Sõru–Triigi Soelal —, aga 35 min ja väike laev teevad sellest täienduse, mitte söögikoha.

Varustuse ja lahtiolekuaegade detailid: [`resupply.md`](resupply.md). Ilm: [`weather_outlook.md`](weather_outlook.md).

## Varustus

TBR lõppes tagumise rummu purunemisega, sest kohapealt ei saanud **28H 27.5" Boost** ratast.
See oli logistikaviga, mitte vormiviga — ja Eesti saartel on varuosade olukord veelgi kehvem kui Bosnias.
Drivetrain shakedown enne starti on plaanis juba kirjas; tee see ära.

---

Generaator [`R/race_strategy.R`](../R/race_strategy.R) · praamigraafikud [`ferry_plan.md`](ferry_plan.md) · varustus [`resupply.md`](resupply.md)

