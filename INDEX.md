# Kõkõva 900 · 2026 🚴

**Start:** R 14.08.2026 21:00, Tallinn Hundipea → **Finiš:** Tallinn · **986,3 km** · limiit 7 päeva

Võistlusnädala avaleht. Puuduta dokumenti, et avada. Working Copys **tõmba WiFi peal `pull`** — praami- ja ilmaraportid uuenevad iga päev, ülejäänu on staatiline.

---

## 🎯 Operatiivne plaan — konservatiivne

**Sõidame `gps-weather` prognoosi järgi, mitte siinse R-mudeli järgi.** Kaks mudelit ei ole nõus (vt allpool); valitud on ettevaatlikum, sest võistlus ise on selle test.

| | |
|---|---|
| **Baasplaan** | **Plaan B — pühapäeva 08:15 Sõru praam** |
| Plaan A (L 18:30 Sõru) | **upside, mitte eeldus** — 31% ka siis, kui 06:30 kätte saad |
| Avaöö | **sõida läbi ja püüa 06:30 Rohuküla praam** — see on ainus, mis plaani A elus hoiab |
| Finiš | q50 **93 h** → T 18.08 ~18:00 (q10 82 h · q90 104 h) |

Avaetapi surve tasub end ära ka plaani B puhul: see ostab värava, mitte ülesõidu.

| Avaetapi tempo | 06:30 praam | L 18:30 Sõru |
|---|---:|---:|
| tavatempo | 57% | 18% |
| +10% | 82% | 24% |
| **+15%** | **89%** | **27%** |
| +20% | 94% | 31% |

## ⛴️ Praamid — ahel, mis võistluse otsustab

| Praam | Saabumine q50 | Väljumised |
|---|---|---|
| Rohuküla→Heltermaa (km 173) | L 06:22 | **57% 06:30** · 43% 08:30 |
| Sõru→Triigi (km 368) | P 01:14 | 18% L 18:30 · **82% P 08:15** |
| Kuivastu→Virtsu (km 692) | E 13:45 | tihe graafik, ootamine ~0,3 h |

**Kui jääd 08:30 praamile, on laupäevane 18:30 Sõru praam matemaatiliselt läbi — 100% jõuab alles pühapäeva 08:15 praamile.** See on ainus number, mille mõlemad mudelid ühtemoodi ütlevad.

Kui saad 06:30 praami: 31% jõuab 18:30-ks, 69% mitte. Otsusta Heltermaal kella, mitte enesetunde järgi — Sõruni on **173 km ja 10,5 h**, ehk 16,5 km/h elapsed valdavalt kruusal.

## ☀️ Ilm — ei ole probleem

Rasked numbrid: vihm q50 **3,7 h / 2,4 mm** · tundub külmim **12,9 °C** · iilid q90 **11,4 m/s** · külma-märja tunde **0,0 igal kvantiilil**.

Ainus lipp: **q90 vastutuul +5,1 m/s laupäeva pärastlõunal** — täpselt Hiiumaa lõigul, mis Sõru otsustab. Halva tuule stsenaariumis ei ole 18:30 üldse sinu otsustada.

Riietus on otsustatud: külmumisohtu selles prognoosis ei ole. Uuenda prognoosi enne starti.

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
