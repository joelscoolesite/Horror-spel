# Something's Inside (werktitel)

Een psychologische horror-game in PS1-stijl, gemaakt in **Godot 4.7**.

Je bent een kind. Elke dag is hetzelfde: opstaan, brood smeren, naar school, gamen, slapen.
Maar elke nacht word je wakker met het gevoel dat er iets in je huis is. En elke nacht wordt het erger.

📄 Het volledige plan staat in [`docs/GDD.md`](docs/GDD.md).

## Status

**Speelbare demo:** dag 1 t/m 3 en nacht 1 t/m 3 (ongeveer 20–25 minuten).
Nacht 4 en 5 en de eindes komen nog.

## Spelen op Windows

1. Download **Godot 4.7** (de "Standard" versie, niet .NET) van [godotengine.org](https://godotengine.org/download/windows/). Uitpakken, geen installatie nodig.
2. Download dit project: op GitHub **Code → Download ZIP** (van deze branch) en pak het uit.
3. Start Godot → klik **Import** → kies het bestand `project.godot` in de map → **Import & Edit**.
4. Druk op **F5** (of het ▶-knopje rechtsboven) om te spelen.

> De eerste keer openen duurt even, omdat Godot alle textures en geluiden importeert.
>
> Als je `scenes/main.tscn` opent in de editor lijkt hij leeg. Dat klopt: het appartement,
> de meubels en de speler worden **door code** opgebouwd als de game start.

### Besturing

| Toets | Actie |
|---|---|
| `W A S D` | Lopen |
| Muis | Rondkijken |
| `E` | Iets doen (licht, taak, deur snel open) |
| Linkermuisknop vasthouden + muis omlaag | Kamerdeur **langzaam** opentrekken |
| `F` | Telefoonlicht |
| `Q` (vasthouden) | Luisteren |
| `Ctrl` | Bukken |
| `Spatie` (in bed) | Onder de deken |
| `1` `2` `3` | Keuzes maken |
| `Esc` | Pauze (hier zit ook de muisgevoeligheid) |
| `=` | **Debug-menu** |

### Debug-menu (toets `=`)

Hiermee kan je snel testen zonder alles opnieuw te spelen:

- **Springen** naar dag 1, 2 of 3: ochtend, school, avond of nacht
- **Spiegel traag**: zet de vertraging van je spiegelbeeld aan/uit
- **Info** aan/uit: FPS, dag, fase, verborgen stats, positie, kamer, batterij
- **Noclip** (door muren vliegen, Spatie = omhoog, Ctrl = omlaag) en **snel lopen**
- Lichten aan/uit, alle kasten open/dicht, TV op ruis, sfeer dag/nacht
- Schrikmomenten testen: gekras, voetstap achter je, schrik-effect
- Uitputting en Hulp ophogen/verlagen

Wil je het debug-menu uitzetten (bijv. als je de game aan vrienden geeft)?
Zet `ENABLED` op `false` bovenin `scripts/ui/debug_menu.gd`.

### Direct naar een bepaald moment (via Godot)

In Godot: **Project → Project Settings → General → Editor → Run → Main Run Args**, en zet daar bijv.:

```
-- --day=2 --phase=night
```

`phase` kan zijn: `morning`, `school`, `afternoon`, `night`. Speel dan `scenes/main.tscn` (F6).

## Hoe het project in elkaar zit

```
scenes/          menu.tscn (startscherm) en main.tscn (de game)
scripts/
  autoload/      Game (dag, stats, taken) en Sfx (geluid afspelen)
  world/         het appartement, meubels, deuren/kasten, lichtknoppen, TV
  player/        de speler
  story/         day_director.gd en night_director.gd  <- HIER STAAT HET VERHAAL
  ui/            HUD (teksten, keuzes), menu, PS1-nabewerking
shaders/         PS1-look (wiebelende vertices, dithering) en schermen
assets/          textures en geluiden (gegenereerd)
tools/           scripts om textures/geluiden te maken + test-hulpjes
docs/GDD.md      het design document
```

**Teksten of gebeurtenissen aanpassen?** Kijk in `scripts/story/`. Alle zinnen die het kind denkt staan daar.

**Eigen geluiden?** Zet een `.wav` met dezelfde naam in `assets/sounds/` (bijv. `scratch.wav`), dan gebruikt de game die.

**Textures/geluiden opnieuw maken:**
```
pip install numpy pillow
python tools/gen_textures.py
python tools/gen_sounds.py
```
