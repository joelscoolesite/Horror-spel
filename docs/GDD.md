# Game Design Document — *Something's Inside* (werktitel)

> Psychologische horror, low-poly PS1-stijl, first-person, gemaakt in **Godot 4**.
> Je bent een kind. Elke dag is hetzelfde. Elke nacht wordt het erger.

Dingen gemarkeerd met 💡 zijn ideeën die Claude heeft toegevoegd, die kan je makkelijk schrappen of aanpassen.

---

## 1. Samenvatting

| | |
|---|---|
| **Genre** | Psychologische horror, "loop"-game |
| **Perspectief** | First-person 3D, PS1-stijl (low-poly, korrelig, wiebelende textures) |
| **Engine** | Godot 4.x |
| **Platform** | Windows (PC) |
| **Taal in de game** | Engels |
| **Lengte** | 5 dagen / 5 nachten, ongeveer 30–60 minuten |
| **Setting** | Een klein appartement (alles op één verdieping) + korte schoolscène |
| **Eindes** | Meerdere, afhankelijk van je keuzes |

**De kern in één zin:** je denkt dat er iets in je huis is, maar het echte monster is wat slaaptekort, angst en eenzaamheid met je hoofd doen.

---

## 2. Het verhaal

### Wat de speler ziet
Je bent een kind (ongeveer 13–14) dat alleen in een appartement woont met een ouder die bijna nooit thuis is (werkt nachtdiensten 💡). Je hebt een vaste routine: opstaan, brood smeren, naar school, thuis gamen, spullen bestellen, nieuws checken, lichten uit, slapen.

Maar elke nacht word je wakker met het gevoel: **"Something is inside my house."**

### Wat er echt aan de hand is (geheim voor de speler)
Het zit in je hoofd. Het kind slaapt steeds slechter, voelt zich alleen, en de angst wordt een dwang: je *moet* checken. Elke kast. Elke nacht. En hoe meer je checkt, hoe erger het wordt.

Dit is het belangrijkste thema van de game:
**Checken voelt veilig, maar houdt de angst in stand.** 💡
De "goede" route is niet het monster verslaan, maar stoppen met checken en hulp vragen.

De speler hoeft dit niet meteen door te hebben. De hints zitten verstopt in de dag (zie §5).

---

## 3. De game-loop

Elke "dag" bestaat uit dezelfde stukken:

```
OCHTEND ──► SCHOOL ──► MIDDAG/AVOND ──► SLAPEN ──► NACHT ──► (volgende dag)
(speelbaar)  (korte    (speelbaar)        (overgang)  (speelbaar,
              scène)                                    de horror)
```

### Ochtend (speelbaar, ~2 min)
- Wakker worden in je kamer, wekker zet je uit.
- Naar de keuken, **brood smeren** (klein interactief taakje).
- **Lunch maken** — dit is optioneel en je "vergeet" het steeds makkelijker (zie §5).
- Tas pakken, deur uit.

### School (korte scène, ~1 min)
- Geen hele school om rond te lopen. Eén klaslokaal of gang, een paar zinnen dialoog, een fade.
- Elke dag klopt er iets meer *niet*: iets in je ooghoek, een klasgenoot die te lang naar je kijkt, het bord met rare tekst.
- 💡 Soms een **keuze**: de leraar/mentor vraagt *"Are you okay? You look tired."* — Je kan antwoorden met *"I'm fine."* of iets eerlijkers. Dit telt mee voor het einde.

### Middag/avond (speelbaar, ~3 min)
- Op de bank een **game spelen** (een simpel minigame-tje op de TV 💡).
- Op je laptop iets **bestellen op "Amazin"** (nep-webshop, want geen echte merken 💡).
- Het **nieuws checken** op je telefoon of laptop.
- Alle **lichten uitdoen** en naar bed.
- 💡 Je kan ook ervoor kiezen om lang door te gamen in plaats van op tijd naar bed te gaan. Dat telt mee.

### Nacht (speelbaar, 5–10 min, het echte horror-gedeelte)
- Je wordt wakker. De wekker geeft een tijd aan. Tekst: *"Something is inside my house."*
- Je stapt uit bed en loopt (langzaam!) door het appartement.
- Kasten openen, lichten checken, terug naar bed.
- Elke nacht gebeurt er meer (zie §6).

---

## 4. Besturing & mechanics

### Basis
| Actie | Toets |
|---|---|
| Lopen | `W A S D` |
| Rondkijken | Muis |
| Interactie | `E` of linkermuisknop |
| Zaklamp (telefoon) aan/uit | `F` |
| Hurken | `Ctrl` |

In de nacht loopt het kind **langzaam**. Er is geen rennen tot de laatste nacht.

### Kasten en deuren langzaam openen
- Je pakt de deur vast (linkermuisknop ingedrukt houden) en **sleept met de muis** om hem open te trekken, zoals in *Amnesia*.
- Hoe langzamer je hem opentrekt, hoe stiller hij gaat. Snel trekken = piepend geluid.
- Tijdens het vasthouden: hartslaggeluid wordt luider, beeld gaat een beetje trillen ("grip versterken"-gevoel).

### Lichten aan/uit
- Lichtschakelaars in elke kamer.
- Nacht 1–2: werken gewoon.
- Nacht 3+: soms knipperen ze, gaan ze vanzelf uit, of doet een schakelaar het niet.

### Telefoon-zaklamp
- `F` = telefoonlicht aan.
- 💡 De batterij loopt leeg zolang het licht aan is. Je begint elke nacht met minder batterij (je vergeet hem op te laden, weer een "vergeten"-hint).

### Verstoppen onder de deken
- Als je in bed ligt kan je de deken over je hoofd trekken.
- Het scherm wordt bijna zwart, je hoort alleen nog geluiden. Je ademhaling wordt rustiger.
- Hiermee kan je een nacht **eerder beëindigen** zonder alles te checken (belangrijk voor het einde, zie §7).
- In nacht 5 is dit ook je manier om aan gevaar te ontsnappen.

### 💡 Extra nacht-acties (door Claude verzonnen)
- **Luisteren:** houd `Q` ingedrukt bij een deur. Je staat stil en hoort beter wat er achter zit. Soms is het niks, soms ademhaling, soms je eigen stem.
- **Voordeur checken:** kijk door het kijkgaatje en check of het slot dicht zit. Elke nacht zie je in de gang iets anders.
- **De spiegel in de badkamer:** vanaf nacht 3 beweegt je spiegelbeeld een fractie te laat.
- **Je ouder bellen/appen:** vanuit bed kan je een bericht sturen. De eerste nachten: geen antwoord. Dit is ook een route naar het goede einde.
- **Het pakketje:** wat je 's middags bestelt, staat 's nachts al voor de deur. Maar er zit iets anders in dan je besteld hebt.

---

## 5. Hints dat het "in je hoofd" zit

Deze vier dingen lopen door de hele game heen en worden elke dag sterker.

### A. De dag verandert subtiel
- **Nieuws:** dag 1 normaal nieuws. Dag 2 een klein berichtje over "sleep deprivation in teens". Dag 3 staat er een artikel over een inbraak in *jouw* straat. Dag 4 gaat het nieuws over *jou*. Dag 5 is de pagina leeg.
- **Amazin-bestelling:** dag 1 bestel je iets normaals. Later staan er dingen in je winkelwagen die jij er niet in hebt gezet (een slot, een nachtlampje, slaappillen, een tweede tandenborstel...).
- **De game op TV:** het poppetje in je game doet steeds meer wat jij 's nachts doet: kasten openen.

### B. Het vergeet-thema
- Dag 1: je vergeet je lunch te maken als je niet oplet.
- Dag 2: er ligt geen brood meer / je vergeet je sleutels.
- Dag 3: je telefoon is niet opgeladen.
- Dag 4: je weet niet meer welke dag het is (wekker/kalender kloppen niet).
- Dag 5: je bent vergeten hoe je kamer eruit zag. Er staan meubels die je niet kent.

### C. Onbetrouwbaar beeld
- Objecten staan niet meer op dezelfde plek als waar je ze liet.
- Schaduwen in hoeken die weg zijn als je ernaar kijkt.
- Vanaf nacht 4: de gang is langer dan hij hoort te zijn. Er is een deur die er nooit was.
- Beeld-effecten (PS1-shader): meer ruis, kleuren die wegtrekken, het scherm dat heel even "hapert".

### D. Stemmen en geluid
- Gefluister dat je net niet verstaat.
- Iemand die je naam roept vanuit een andere kamer (met de stem van je ouder 💡).
- Voetstappen die precies gelijk lopen met die van jou... en dan één stap te veel.
- De TV die ineens op ruis springt (nacht 2).

#### Gekras op de deur
Een langzaam, droog krassen, alsof iemand met nagels over hout gaat. Het wordt elke nacht erger:

| Nacht | Wat je hoort |
|---|---|
| 1–2 | Niks. |
| 3 | Je wordt **wakker van gekras** op je slaapkamerdeur. Het stopt zodra je uit bed stapt. Doe je de deur open: lege gang. |
| 4 | Het gekras komt nu van **binnenuit een kast**. Als je gaat luisteren (`Q`) stopt het, en dan hoor je iets zachtjes ademen. |
| 5 | Terwijl je onder de deken ligt krast het op je **deur, dan op de muur, dan op het bedframe**. Steeds dichterbij. Niet kijken. |

- Het geluid komt altijd uit een echte richting (3D-geluid), dus met een koptelefoon kan je horen *welke* deur het is.
- 💡 Soms krast het met hetzelfde ritme als een liedje dat overdag in je game op TV speelde.

#### Late voetstappen
Jouw eigen voetstappen, maar met een vertraging, alsof er iemand vlak achter je precies hetzelfde loopt.

| Nacht | Wat je hoort |
|---|---|
| 1 | Niks, je voetstappen klinken normaal. |
| 2 | Als je stilstaat hoor je **één voetstap te veel**. Maar één keer, zodat de speler denkt dat hij het zich inbeeldde. |
| 3 | De voetstappen lopen een **halve seconde achter** op die van jou. Sta je stil, dan lopen ze nog 2–3 stappen door. |
| 4 | Ze komen **dichterbij** bij elke stap die je zet. Draai je je om: niks. En dan stoppen ze ook. |
| 5 | Ze lopen niet meer jouw ritme, ze lopen **hun eigen tempo**. Iets sneller dan jij. |

- 💡 Op de vloer in de gang ligt een ander materiaal (bijv. laminaat vs. tapijt). Loop jij op tapijt, dan hoor je de late voetstappen toch op laminaat. Dat verraadt dat ze niet van jou zijn.

---

## 6. De 5 nachten uitgewerkt

De klok staat elke nacht later, alsof je steeds minder slaapt 💡:
**00:13 → 01:26 → 02:39 → 03:33 → 03:33 (blijft staan).**

### Nacht 1 — *"Nothing's there."*
- Je wordt wakker, voelt dat er iets is.
- Je checkt de kasten, één voor één, langzaam.
- **Er gebeurt niets.** Helemaal niets. Dat is het punt: de speler went aan het ritme en de rust.
- Terug naar bed.
- **Doel:** besturing leren, spanning opbouwen zonder payoff.

### Nacht 2 — *De TV*
- Zelfde als nacht 1, je denkt: *"Not this again."*
- Je checkt alle kasten. Niks.
- Op weg terug springt de **TV ineens aan op ruis**, keihard in de stilte.
- Je moet naar de woonkamer lopen en hem uitzetten.
- Als je bij de TV stilstaat: **één voetstap te veel** achter je.
- Terug naar bed.
- **Doel:** de eerste echte schrik. Nog steeds niks "echts" gezien.

### Nacht 3 — *De lichten*
- Je wordt wakker van **gekras op je slaapkamerdeur**. Het stopt zodra je uit bed stapt.
- Een van de kasten staat al op een kiertje als je wakker wordt.
- Je voetstappen klinken **een halve seconde te laat**, en lopen nog even door als jij stilstaat.
- De lichtschakelaar in de gang werkt niet → je moet je telefoonlicht gebruiken (en de batterij is niet vol).
- Het pakketje van Amazin staat voor de deur. 💡 Er zit jouw eigen lunchtrommel in, met een boterham die al dagen oud is.
- Je hoort je naam vanuit de badkamer. In de spiegel beweegt je spiegelbeeld een beetje te laat.
- **Doel:** de speler twijfelt voor het eerst aan wat echt is.

### Nacht 4 — *Het huis klopt niet*
- De gang is langer. Er is een extra deur.
- Achter de extra deur: jouw slaapkamer. Met iemand in bed. (Jij?) 💡
- De kasten gaan nu soms vanzelf een stukje open terwijl je ernaar kijkt.
- De late voetstappen komen bij elke stap **dichterbij**. Als je je omdraait: niks, en dan stoppen ze.
- **Gekras van binnenuit een kast.** Luister je (`Q`), dan stopt het en hoor je ademhaling. Doe je hem open: leeg.
- Als je te lang rondloopt gaan de lichten één voor één uit richting jou → je moet naar bed en **onder de deken**.
- **Doel:** de "regels" van nacht 1–3 breken. Verstoppen wordt belangrijk.

### Nacht 5 — *Het is er echt (of niet)*
- Nu kan het fout gaan. Er is een **gestalte** in het appartement (vaag, donker, altijd net buiten je zaklamp).
- Als hij je te dichtbij komt → game over, nacht opnieuw.
- De voetstappen lopen niet meer jouw ritme maar **hun eigen, snellere tempo**. Zo hoor je waar de gestalte is.
- Je kan: verstoppen onder de deken, lichten aandoen om hem te laten verdwijnen, en je moet een keuze maken (zie eindes).
- Onder de deken: **gekras op de deur → de muur → het bedframe**, steeds dichterbij. Blijf stil liggen tot het stopt.
- **Doel:** climax, alles komt samen.

---

## 7. Eindes

Er worden stilletjes twee dingen bijgehouden 💡 (de speler ziet deze getallen nooit):

| Stat | Gaat omhoog als je... | Gaat omlaag als je... |
|---|---|---|
| **Uitputting** | lang doorgamet, lunch vergeet, alles checkt, telefoon niet oplaadt | op tijd naar bed gaat, ontbijt eet, onder de deken blijft |
| **Hulp** | eerlijk antwoord geeft op school, je ouder appt, het nieuwsartikel over slaap leest | steeds "I'm fine." zegt, berichten negeert |

### Einde 1 — "Morning" (goed einde)
Hoge **Hulp**, niet te hoge **Uitputting**.
In nacht 5 bel je je ouder in plaats van de laatste kast open te doen. Dit keer neemt die op. Het scherm wordt licht. Je wordt wakker, zon komt binnen, er staat een lunch voor je klaar met een briefje.

### Einde 2 — "Check Again" (slecht einde)
Hoge **Uitputting**, lage **Hulp**.
Je opent de laatste kast. Binnenin: jij, die naar jou kijkt en zegt: *"Something is inside my house."* De game begint opnieuw bij dag 1, maar alles is iets donkerder. (Loop die nooit stopt.)

### Einde 3 — "Awake" (geheim einde) 💡
Je gaat in nacht 5 helemaal niet uit bed, je blijft de hele nacht onder de deken. Je hoort alles, maar kijkt niet. Na een lange stilte: de wekker gaat. Het is ochtend. Onduidelijk of het voorbij is.

---

## 8. Stijl: PS1-look

### Graphics
- **Lage resolutie:** game rendert op bijv. 320×240 en wordt opgeschaald → grote, scherpe pixels.
- **Vertex snapping:** modellen "wiebelen" een beetje als je beweegt (klassiek PS1-effect).
- **Affine texture mapping:** textures die een beetje vervormen.
- **Dithering + beperkt kleurenpalet.**
- **Mist (fog):** kort zichtveld, alles verder weg verdwijnt in het donker. Scheelt ook in hoeveel je hoeft te bouwen.
- **Low-poly modellen:** simpele vormen, lage-resolutie textures (64×64 of 128×128).

### Geluid (misschien wel het belangrijkste!)
- Heel **stil**. Koelkastgebrom, klok die tikt, verkeer ver weg.
- Hartslag en ademhaling van het kind die mee-reageren.
- Plotselinge harde geluiden (TV-ruis) werken juist omdat het verder zo stil is.

### De dag vs. de nacht
- **Dag:** warm licht, maar een beetje flets/overbelicht. Het voelt nooit helemaal "goed".
- **Nacht:** blauw/zwart, alleen licht van de telefoon, de wekker en straatlantaarns door het raam.

---

## 9. Het appartement (level)

Klein houden = haalbaar. Voorstel voor de plattegrond:

```
┌────────────┬──────────┬────────────┐
│            │          │            │
│ SLAAPKAMER │ BADKAMER │  KAMER     │
│  (jij)     │ (spiegel)│  OUDER     │
│  [kast]    │ [kastje] │  [kast]    │
├────┬───────┴──────────┴───────┬────┤
│    │          GANG             │    │
│    │   [gangkast]   [lichtknop]│    │
├────┴──────────────┬───────────┴────┤
│                   │                │
│   WOONKAMER       │    KEUKEN      │
│   [TV] [bank]     │  [koelkast]    │
│   [laptop]        │  [keukenkast]  │
│                   │                │
└────────┬──────────┴────────────────┘
       [VOORDEUR]
```

**Kasten om te checken:** slaapkamerkast, badkamerkastje, gangkast, kast in de kamer van je ouder, keukenkast (5 in totaal, één per nacht meer "fout").

---

## 10. Bouwplan (stap voor stap)

Omdat je nog nooit Godot hebt gebruikt: **eerst iets heel kleins laten werken, dan uitbreiden.** Elke stap is een klein "af" ding.

### Fase 0 — Godot leren (1–2 weken)
- [ ] Godot 4 downloaden van godotengine.org (Windows, "Standard" versie, geen installatie nodig).
- [ ] Een beginnerstutorial volgen, bijv. Brackeys "How to make a Video Game – Godot Beginner Tutorial" of de officiële "Your first 3D game" in de Godot-docs.
- [ ] Snappen wat **nodes**, **scenes** en **scripts (GDScript)** zijn.

### Fase 1 — Rondlopen (eerste echte stap)
- [ ] Nieuw Godot-project aanmaken in deze repo.
- [ ] Een simpele kamer maken van blokken (CSG-boxes of MeshInstance3D).
- [ ] First-person speler: lopen met WASD, kijken met muis.
- [ ] ✅ **Klaar als:** je door een grijze kamer kan lopen.

### Fase 2 — De PS1-look
- [ ] Game laten renderen op lage resolutie (SubViewport of project-instelling).
- [ ] Een gratis PS1-shader toevoegen (zoek op "godot psx shader", er zijn er genoeg gratis op GitHub/godotshaders.com).
- [ ] Mist en donkere belichting.
- [ ] ✅ **Klaar als:** de grijze kamer er al eng uitziet.

### Fase 3 — Interactie
- [ ] Kijken naar een object → tekstje "E" verschijnt.
- [ ] Lichtschakelaar die een lamp aan/uit zet.
- [ ] Kastdeur die je met de muis langzaam opentrekt.
- [ ] Telefoon-zaklamp.
- [ ] ✅ **Klaar als:** je in één kamer een kast kan openen en het licht aan/uit kan doen.

### Fase 4 — Het appartement
- [ ] Hele plattegrond bouwen (nog met simpele blokken).
- [ ] Alle 5 kasten, lichtknoppen, bed, TV.
- [ ] Geluid toevoegen: voetstappen, deur-piep, sfeergeluid, gekras.
- [ ] Late voetstappen: bij elke stap van de speler dezelfde voetstap nog een keer afspelen, maar met vertraging (een `Timer` of `await get_tree().create_timer(0.5).timeout`) en vanaf een punt achter de speler (`AudioStreamPlayer3D`).

### Fase 5 — Nacht 1 & 2 speelbaar (= je eerste demo!)
- [ ] Wakker worden → tekst → kasten checken → terug naar bed.
- [ ] Nacht 2: TV springt op ruis.
- [ ] Een simpel "GameState"-script dat onthoudt welke nacht het is.
- [ ] ✅ **Klaar als:** een vriend het kan spelen en schrikt van de TV. 🎉

### Fase 6 — De dag
- [ ] Ochtend: brood smeren, lunch (optioneel).
- [ ] School-scène (één kamer + tekst).
- [ ] Middag: TV-game, Amazin, nieuws, lichten uit.

### Fase 7 — Nacht 3, 4, 5 + eindes
- [ ] Alle events uit §6.
- [ ] Stats (Uitputting/Hulp) bijhouden.
- [ ] De drie eindes.

### Fase 8 — Afwerken
- [ ] Menu (Start, Settings, Quit).
- [ ] Echte modellen/textures i.p.v. blokken.
- [ ] Laten testen door vrienden, dingen fixen.
- [ ] Eventueel op itch.io zetten.

---

## 11. Handige gratis bronnen

| Wat | Waar |
|---|---|
| Godot downloaden | godotengine.org |
| Officiële beginners-tutorial | docs.godotengine.org → "Getting started" |
| Gratis 3D-modellen (low-poly) | kenney.nl, quaternius.com, poly.pizza |
| PS1-shaders | godotshaders.com (zoek "psx" of "ps1") |
| Gratis geluiden | freesound.org, sonniss.com (gratis GDC-bundels) |
| Inspiratie (games) | *P.T.*, *The Exit 8*, *Anatomy*, *Fears to Fathom*, *Paratopic*, *Puppet Combo*-games |

---

## 12. Open vragen (nog samen te beslissen)

- Definitieve **naam** van de game?
- Heeft het kind een **naam**? (Belangrijk voor "iemand roept je naam".)
- Hoe ziet de **gestalte** in nacht 5 eruit? Lijkt die op iemand?
- Waar is de **ouder** eigenlijk? (Nachtdienst? Iets anders?)
- Welke **persoonlijke ervaringen** wil je erin verwerken? Hoe specifieker, hoe enger het wordt.
