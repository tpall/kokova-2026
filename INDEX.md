# Kõkõva 900 · 2026 🚴

**Start:** R 14.08.2026 21:00, Tallinn Hundipea → **Finiš:** Tallinn · **986,3 km** · limiit 7 päeva

Võistlusnädala avaleht. Puuduta dokumenti, et avada. Working Copys **tõmba WiFi peal `pull`** — praami- ja ilmaraportid uuenevad iga päev, ülejäänu on staatiline.

---

## 🎯 Operatiivne plaan — konservatiivne

**Sõidame `gps-weather` prognoosi järgi, mitte siinse R-mudeli järgi.** Kaks mudelit ei ole nõus (vt allpool); valitud on ettevaatlikum, sest võistlus ise on selle test.

*Prognoos 08.08 (6 päeva ette). Vahe eelmisega on suur — vt hoiatust allpool.*

| | |
|---|---|
| **Baasplaan** | **Plaan B — pühapäeva 08:15 Sõru praam** |
| Plaan A (L 18:30 Sõru) | **upside, mitte eeldus** — 40% ka siis, kui 06:30 kätte saad |
| Avaöö | **sõida läbi ja püüa 06:30 Rohuküla praam** — see on ainus, mis plaani A elus hoiab |
| Finiš | q50 **94 h** → T 18.08 ~18:45 (q10 83 h · q90 105 h) |

Avaetapi surve tasub end ära ka plaani B puhul: see ostab värava, mitte ülesõitu.

| Avaetapi tempo | 06:30 praam | L 18:30 Sõru |
|---|---:|---:|
| tavatempo | 28% | 11% |
| +10% | 51% | 15% |
| **+15%** | **60%** | **16%** |
| +20% | 74% | 17% |

⚠️ **Prognoos halvenes ööpäevaga järsult.** 07.08 cube andis 06:30 praamile 57%,
08.08 cube annab **28%** — avaetapi vastutuul kasvas **+1,2 → +2,2 m/s**. Kogu vahe
on tuul, mitte mudel. Kuue päeva pealt on see veel liikuv number: **jooksuta uuesti
12.–13.08**, enne kui avaöö taktika lõplikult paika paned.

## ⛴️ Praamid — ahel, mis võistluse otsustab

| Praam | Saabumine q50 | Väljumised |
|---|---|---|
| Rohuküla→Heltermaa (km 173) | L 06:55 | 28% 06:30 · **72% 08:30** |
| Sõru→Triigi (km 368) | P 02:51 | 11% L 18:30 · **89% P 08:15** |
| Kuivastu→Virtsu (km 692) | E ~14:00 | tihe graafik, ootamine ~0,3 h |

**Kui jääd 08:30 praamile, on laupäevane 18:30 Sõru praam matemaatiliselt läbi — 100% jõuab alles pühapäeva 08:15 praamile.** See on ainus number, mis pole ühegi prognoosi ega mudeli juures liikunud.

Kui saad 06:30 praami: 40% jõuab 18:30-ks, 60% mitte. Otsusta Heltermaal kella, mitte enesetunde järgi — Sõruni on **173 km ja 10,5 h**, ehk 16,5 km/h elapsed valdavalt kruusal.

## ☀️ Ilm — ei ole probleem

Rasked numbrid (08.08 prognoos): vihm q50 **3,8 h / 2,5 mm** · tundub külmim **12,4 °C** · iilid q90 **11,6 m/s** · külma-märja tunde **0,0 igal kvantiilil**.

**Tuul on ainus, mis loeb — ja see on avaöö probleem.** Reede 21:00–03:00 vastutuul q50 **+2,4 m/s** (q90 +4,9), täpselt Rohuküla väravat sõites. Hiiumaal on tuul leebem (q50 ~+1,0).

Riietus on otsustatud: külmumisohtu selles prognoosis ei ole, isegi q10 juures on 9,8 °C. Vihma q90 venis 12,7 tunnini — vihmavarustus on ainus, mida tasub üle vaadata.

## 📄 Raportid

- **[Võistlusstrateegia →](reports/race_strategy.md)** — vorm, võimsus, uni, praamivärava tempoarvutus *(R-mudel: optimistlikum, vt lahkarvamust)*
- **[Praamiplaan →](reports/ferry_plan.md)** — kõigi kolme liini graafikud, Sõru värava analüüs
- **[Luuresõit 30.07 →](reports/recon_ride.md)** — mõõdetud tulemus, õppetunnid, söömise ja asendi järeldused
- **[Varustus →](reports/resupply.md)** — punktid, lahtiolekuajad, ööpäevaringsete vahed
- **[Elav prognoos →](reports/weather_forecast.md)** · *uueneb iga päev*
- **[Kliimaülevaade →](reports/weather_outlook.md)** — ERA5 taust 2016–2025
- **[Raja ülevaade →](reports/route_outlook.md)**
- **[Võistlusfaktid →](README.md)** — start, rada, andmeallikad

## ⚠️ Mudelite lahkarvamus — loe enne, kui numbrit usud

| | `kokova-2026` (R) | `gps-weather` (valitud) |
|---|---|---|
| Avaetapi eeldus | mõõdetud luuretempo 21,5 km/h | mitmepäeva-võimsus 167 W (öösel 142 W) |
| L 18:30 Sõru | **teostatav, plaan A** | **31% ka 06:30 pealt** |
| Hiiumaa maapind | tempo-eeldus | eraldi crr 0,0155 (58% kruusa) |

R-mudel tugineb 30.07 luuresõidule — see mõõtis **mandrit, mitte Hiiumaad**, ja mõõtis päevast tempot värskena. `gps-weather` lisab Hiiumaale maapinnatrahvi ja sõidab mitmepäeva-tempot. Kumbki ei ole veel valideeritud selle raja saareosal.

**Seetõttu on baasplaan konservatiivne.** Kui Hiiumaa läheb kergemalt kui mudel arvab, on 18:30 boonus, mitte päästetud plaan.

---

*Avaleht: `INDEX.md` (käsitsi). `reports/` genereeritakse (`make all`); prognoos uueneb CI-st. Konservatiivsed numbrid: `gps-weather` repo, `reports/kokova_2026_final_surface.md`, jooksutatud 07.08.2026.*
