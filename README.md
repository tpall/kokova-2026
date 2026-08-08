# Kõkõva 900 · 2026

Raja-, ilma- ja praamiplaan Kõkõva 900 jaoks.
Start **reedel 14. augustil 2026 kell 21:00** Tallinnas Hundipeal, limiit 7 päeva,
rada **986,3 km** (millest ~941 km sõidetakse, ülejäänud ~45 km on kolm praami).

## Raportid

| Fail | Sisu |
|------|------|
| [`reports/ferry_plan.md`](reports/ferry_plan.md) | Kõigi kolme praamiliini graafikud võistlusaknas, Sõru värava analüüs ja soovituslikud väljumised nelja tempoprofiili kohta |
| [`reports/weather_outlook.md`](reports/weather_outlook.md) | Kliimaülevaade 14.–21. augustiks ERA5 põhjal (2016–2025): temperatuur, sadu, tuuleroos ja oodatav vastutuule osakaal |
| [`reports/weather_forecast.md`](reports/weather_forecast.md) | Elav 16-päevane prognoos rajapunktides — start on prognoosiaknas alates ~4. augustist |
| [`reports/race_strategy.md`](reports/race_strategy.md) | Võistlusstrateegia: vorm, võimsus, uni ja see, millist tempot Sõru praam nõuab |
| [`reports/resupply.md`](reports/resupply.md) | Varustuspunktid, lahtiolekuajad, ööpäevaringsete vahed ja toitlustus |
| [`reports/recon_ride.md`](reports/recon_ride.md) | Mandriringi luuresõit — **sõidetud 30.07**: plaan, mõõdetud tulemus ja õppetunnid |

## Peamine järeldus

Rada on lauge — kolm praami ja tuul otsustavad rohkem kui reljeef.

**Sõru → Triigi (km 368) on ainus ühendus Hiiumaalt Saaremaale ja sõidab võistlusaknas
kaks kuni kolm korda päevas.** 15.–16. augustil on väljumised 08:15, 11:00 ja 18:30;
alates 18. augustist ainult 08:15 ja 17:30. Õhtusest praamist mahajäämine maksab
ligi 14 tundi.

Lõplikul rajal on Heltermaa ja Sõru vahel **173 km Hiiumaad** (beetarajal oli 112),
ja see muutis värava olemust: **06:30 Rohuküla praam on ainus, millelt õhtune Sõru
praam veel realistlikult kätte tuleb** (nõuab Hiiumaal 16,5 km/h elapsed). 08:30
praamilt nõuaks Hiiumaa 20,4 km/h, 10:00 praamilt ei jõua keegi. Vt `race_strategy.md`.

**Luuresõit 30.07 langetas otsuse plaan A kasuks** — 157 km uksest Rohuküla kaini
veidi üle 7 tunni (Edge'i keskmine 21,8 km/h, täiskoormaga, vastutuulega), mis
tähendab võistlusel Rohukülla ~05:05 ehk 06:15 sihtajast ~70 min varem.

## Struktuur

```
R/         skriptid
data/      rada: organisaatori GPX, tuletatud geomeetria ja varustuspunktid
output/    masinloetavad tulemused (JSON)
reports/   inimloetavad raportid (Markdown)
```

`data/` on ainus koht, kust midagi käsitsi hooldatakse: `waypoints.csv` punktide
nimed on käsitsi pandud. Kõik `output/` ja `reports/` sisu genereeritakse.

## Uuendamine

Käivita projekti juurkaustast:

```sh
make daily      # praamid + prognoos + strateegia (see, mida CI iga päev teeb)
make outlook    # ERA5 kliimaülevaade (aeglane, ~1 min; muutub harva)
make route      # tuletatud rajageomeetria, kui rajafail on uuenenud
make resupply   # varustuspunktid OSM-ist (aeglane, ~10 min; ainult raja muutudes)
make recon      # luuresõidu plaan
make all        # kõik ülalolev
```

Või otse, samuti juurkaustast: `Rscript R/ferry_schedule.R`.

Vajalikud R-pakid: `dplyr`, `tibble`, `purrr`, `tidyr`, `readr`, `xml2`,
`httr2`, `jsonlite`. Ükski allikas ei nõua API võtit.

Uue rajafaili saabudes jooksuta esmalt `make route`, seejärel ülejäänu, ja kontrolli
`TOTAL_ROUTE_KM` väärtust failis `R/plan.R`.

## Andmeallikad

- [praamid.ee](https://www.praamid.ee) — TS Laevad, Rohuküla–Heltermaa ja Kuivastu–Virtsu
- [veeteed.com](https://www.veeteed.com) — Kihnu Veeteed, Sõru–Triigi (elav broneerimisinventuur koos vabade rattakohtadega)
- [Open-Meteo](https://open-meteo.com) — prognoos ja ERA5 reanalüüs
- [panepanepane.ee/k6k6va](https://www.panepanepane.ee/k6k6va) — korraldaja

Rada: **`data/kokova_2026_900_final.gpx`** (korraldaja lõplik GPX, 986,3 km).
Varasem `kokova_2026_900_beta.kmz` on eemaldatud — see ei olnud lihtsalt ebatäpne,
vaid **eksitav**: mõlemad on ~985 km, nii et pikkuse järgi viga ei näe, aga beeta
paigutas Sõru km 316,5 juurde ja lõplik km 368 juurde. Iga beetarajal arvutatud
praaminumber on kehtetu. Kiire kontroll, kummalt rajalt number pärineb: Rohuküla
on lõplikul rajal km 173, beetal km 182.
