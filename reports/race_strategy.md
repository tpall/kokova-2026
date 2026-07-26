# Kõkõva 900 · 2026 — võistlusstrateegia

> Genereeritud **2026-07-26 20:41 EEST** · rajamudel [`R/plan.R`](../R/plan.R) · sportlase andmed [`R/athlete.R`](../R/athlete.R)

**Start** R 14.08 21:00 Hundipea · **limiit** 7 päeva → R 21.08 21:00 · **rada** 985 km, ~1580 m tõusu

## Lühidalt

Rada on lauge. Kogu tõus 985 km peale on 1580 m — vähem kui TBR-i ühel päeval.
Sinu 2026. aasta suurim on-bike piiraja, tõusudel püsiva võimsuse hoidmine, siin praktiliselt ei rakendu.

Selle võistluse otsustab **Sõru praam kilomeetril 316,5**. Ja praeguse vormiga jääd sellest napilt maha.

## ⚠️ Kriitiline: laupäevane Sõru praam

Mudel paneb sind Sõrule **L 15.08 18:48**. Laupäevane õhtune praam väljub **18:30**.

Sa jääd sellest maha **34 minutiga** — ja järgmine väljumine on pühapäeva 08:15, seega ootamist **13,4 tundi**.

Lõpetad **K 19.08 12:17** (111 h). 2025. aasta sõidukiirusega oleks see **T 18.08 12:27** (87 h) — mõlemad on selle sama 2026. aasta raja ja praamigraafiku mudelist, mitte võrdlus möödunud aasta tulemusega.

> **2025. aasta rada oli täiesti teine.** Möödunud aasta Kõkõva läks Lääne-Virumaale ja Lõuna-Eestisse
> (idapikkus 25,6–27,6°, GPX-i järgi ~8 200 m tõusu, praame ei olnud); tänavune läheb läände ja saartele
> (21,9–24,7°, ~1 580 m, kolm praami). Kattuvust ei ole. Möödunud aasta **89,8 h ei ole seega võrreldav lõpuaeg** —
> üle kanduvad ainult sportlase enda näitajad: sõidukiirus, kui kaua ta enne esimest und sõidab, kui vähe ta magab
> ja kui aeglaselt võimsus langeb.

### Mis tempot see nõuab

Murdepunkt on leitud mudelit ennast läbi lastes, seega arvestab ka praamiootusi. Sõidukiirus, millega laupäevane 18:30 praam just napilt kätte tuleb:

| Peatuste distsipliin avaetapil | Nõutav sõidukiirus |
|--------------------------------|-------------------:|
| praegune eeldus (10% peatusi) | **17,2 km/h** |
| 2025. aasta distsipliin (6%) | **16,5 km/h** |
| peaaegu ei peatu (3%) | **16,0 km/h** |

Sinu 2025. aasta sõidukiirus oli 18,5 km/h, praegune ootus 16,5 km/h. Peatuste kärpimine 10%-lt 6%-le langetab nõutava kiiruse 0,7 km/h võrra — see on **tasuta kiirus**, mille eest ei pea jalgadega maksma.

### Kuidas see praam kätte saada

Ainus tee Hiiumaale on Rohuküla praam, seega iga Sõru väljumine tähendab konkreetset viimast Rohuküla praami.

| Sõru väljumine | Viimane Rohuküla praam | Heltermaal | Tallinn→Rohuküla nõutav tempo | Heltermaa→Sõru nõutav tempo |
|----------------|------------------------|------------|------------------------------:|----------------------------:|
| L 15.08 18:30 | L 15.08 08:30 | 09:45 | 16,1 km/h | 13,2 km/h |

Tempod on **elapsed**, mitte sõidutempo — sisaldavad kõiki peatusi. Sinu 2025. aasta avaetapp oli 349 km 17,9 tunniga, mis teeb 19,6 km/h elapsed. See on täpselt see number, mida siin vaja.

**Otsus: mine 08:30 Rohuküla praamile.** See annab Hiiumaal üle seitsme tunni 112 km jaoks — mugav varu.
10:00 praam jätab napilt seitse tundi, mis tähendab Hiiumaal sisuliselt mitte peatumist. 11:30 praamiga on 18:30 Sõru läinud.

## Vorm — kaks numbrit, mis näitavad vastassuunda

| Näitaja | Väärtus | Tähendus |
|---------|---------|----------|
| HRV nädala keskmine | 61 | Täielikult taastunud, üle enda 2026. aasta keskmise (59,8) |
| Kroonilne koormus | 323 | **39% aprilli tipust (833)** — Garmini staatus DETRAINING |
| Päevi rattata | 13 | Viimane sõit 13. juuli |
| Pikim sõit pärast TBR-i | 62 km | 11. juuli, 2,4 h |

Oled maksimaalselt värske ja samal ajal märkimisväärselt vormist väljas. Värskus on 19 päevaga taastatav osa;
aeroobne baas ei ole. Sellepärast on mudelis eraldi profiil „Taavi 2026 ootus" (16,5 km/h sõidus) eristatuna
2025. aasta tempost (18,5 km/h) — see vahe on täpselt see, mis Sõru praami maha jätab.

## Võimsus

FTP **247 W** (3,22 W/kg), lävipulss 150, maksimaalne mõõdetud pulss 170.

2025. aasta Kõkõval hoidsid keskmist 118 → 109 W ja langus kolme suure etapi jooksul oli ainult **-8%**.
TBR-il oli sama näitaja **-27%** (115 → 84 W) — aga see oli 27 000 m tõusuga rada kuumuses.
Tänavune rada on lauge ja ilm jahedam, seega vastupidavuse mõttes on 2025. aasta profiil õigem ootus —
kuigi ka see rada oli tänavusest viis korda mägisem.

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

**Plaan:** sõida esimene öö läbi. See ei ole kangelaslikkus — see on ainus viis olla laupäeva hommikul 08:30 Rohuküla praamil.
Seejärel kaks ööd 4–5 h, magamiskoht valitud enne peatumist, mitte otsitud pärast.

## Praamid ja päevakava

| km | Sündmus | Aeg (Taavi 2026 ootus) |
|---:|---------|------------------------|
| 182 | Rohuküla→Heltermaa L 15.08 10:00 (ootamine 0.8 h) | L 15.08 09:13 |
| 316 | Sõru→Triigi P 16.08 08:15 (ootamine 13.4 h) | L 15.08 18:48 |
| 524 | uni 6.0 h | E 17.08 02:00 |
| 698 | Kuivastu→Virtsu T 18.08 05:00 (ootamine 5.4 h) | E 17.08 23:34 |
| 936 | uni 6.0 h | K 19.08 02:00 |
| 985 | **Finiš** | **K 19.08 12:17** (111 h) |

Laevadel on toit: TS Laevade praamidel (Rohuküla–Heltermaa 75 min, Kuivastu–Virtsu 27 min) on restoran ja R-Kiosk.
**75-minutiline Hiiumaa ülesõit on raja parim söögikoht** ja ainus, mis on laupäeva hommikul lahti, kui saarepoed veel magavad.
Sõru–Triigi laeval Soela toitlustust ei õnnestunud kinnitada — ära arvesta sellega.

Varustuse ja lahtiolekuaegade detailid: [`resupply.md`](resupply.md). Ilm: [`weather_outlook.md`](weather_outlook.md).

## Varustus

TBR lõppes tagumise rummu purunemisega, sest kohapealt ei saanud **28H 27.5" Boost** ratast.
See oli logistikaviga, mitte vormiviga — ja Eesti saartel on varuosade olukord veelgi kehvem kui Bosnias.
Drivetrain shakedown enne starti on plaanis juba kirjas; tee see ära.

---

Generaator [`R/race_strategy.R`](../R/race_strategy.R) · praamigraafikud [`ferry_plan.md`](ferry_plan.md) · varustus [`resupply.md`](resupply.md)

