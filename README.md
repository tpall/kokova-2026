# Kõkõva 900 · 2026

Raja-, ilma- ja praamiplaan Kõkõva 900 jaoks.
Start **reedel 14. augustil 2026 kell 21:00** Tallinnas Hundipeal, limiit 7 päeva,
rada ~985 km (millest ~954 km sõidetakse, ülejäänu on praamid).

## Raportid

| Fail | Sisu |
|------|------|
| [`ferry_plan.md`](ferry_plan.md) | Kõigi kolme praamiliini graafikud võistlusaknas, Sõru värava analüüs ja soovituslikud väljumised nelja tempoprofiili kohta |
| [`weather_outlook.md`](weather_outlook.md) | Kliimaülevaade 14.–21. augustiks ERA5 põhjal (2016–2025): temperatuur, sadu, tuuleroos ja oodatav vastutuule osakaal |
| [`weather_forecast.md`](weather_forecast.md) | Elav 16-päevane prognoos rajapunktides — täitub, kui start jõuab prognoosiaknasse (~30. juuli) |

## Uuendamine

```sh
Rscript ferry_schedule.R     # praamid.ee + veeteed.com
Rscript weather_forecast.R   # Open-Meteo prognoos
Rscript weather_outlook.R    # ERA5 kliima (aeglane, ~1 min)
```

Vajalikud R-pakid: `dplyr`, `tibble`, `purrr`, `tidyr`, `readr`, `xml2`, `httr2`, `jsonlite`.
Ükski allikas ei nõua API võtit.

## Peamine järeldus

Rada on lauge — kolm praami ja tuul otsustavad rohkem kui reljeef.

**Sõru → Triigi (km 316,5) on ainus ühendus Hiiumaalt Saaremaale ja sõidab võistlusaknas
kaks kuni kolm korda päevas.** 15.–16. augustil on väljumised 08:15, 11:00 ja 18:30;
alates 18. augustist ainult 08:15 ja 17:30. Õhtusest praamist mahajäämine maksab
ligi 14 tundi. Praktikas tähendab see, et Rohuküla praamile tuleb jõuda
laupäeva hommikul — `ferry_plan.md` tabel näitab iga Sõru väljumise kohta viimast
Rohuküla praami, millega sinna veel jõuab.

## Andmeallikad

- [praamid.ee](https://www.praamid.ee) — TS Laevad, Rohuküla–Heltermaa ja Kuivastu–Virtsu
- [veeteed.com](https://www.veeteed.com) — Kihnu Veeteed, Sõru–Triigi (elav broneerimisinventuur koos vabade rattakohtadega)
- [Open-Meteo](https://open-meteo.com) — prognoos ja ERA5 reanalüüs
- [panepanepane.ee/k6k6va](https://www.panepanepane.ee/k6k6va) — korraldaja

Rada: `kokova_2026_900_beta.kmz`. Fail on märgitud BETA-ks, seega lõplik versioon
võib muutuda — pärast uut KMZ-i jooksuta kõik kolm skripti uuesti.
