# ENKA @ Ballhaus West — Game Boy Color promo

Promo cartridge for ENKA @ Ballhaus West (Hirschstraße 18, Karlsruhe), Thursday 29.10.2026, 18:00.
64 KiB ROM, MBC5, Game Boy Color only: `enka.gbc`. Classic house soundtrack from boot.

## How it plays (about a minute)

1. **Title** — ENKA, date, 18:00, venue. Line-up: ???. Press START.
2. **Setup 1/2** — book two DJs. Not everyone on the list makes the cut.
3. **Setup 2/2** — warm up the decks: 8 scratches (Left/Right), Up/Down switches deck, A starts/stops a platter.
4. **Loading party...**
5. **Bike ride** — from Karlsruhe Hauptbahnhof through the real streets to Ballhaus West.
   The map is generated from OpenStreetMap data; street names pop up as you ride, the arrow points the way.
6. **Ending** — night scene at Ballhaus West, the line-up and your time. START plays again.

## Build

Needs Python 3 and [RGBDS](https://github.com/gbdev/rgbds) 1.0:

```sh
mkdir -p tools/rgbds
curl -sL https://github.com/gbdev/rgbds/releases/download/v1.0.4/rgbds-linux-x86_64.tar.xz | tar -xJ -C tools/rgbds
./build.sh
```

Or point `RGBDS=/path/to/bin/` at an existing install.

- `src/main.asm` — screens, text box, overworld, ending
- `src/sound.asm` — music driver and sound effects
- `src/text.asm` — all dialogue and on-screen text
- `tools/gen.py` — generates fonts, logo, turntables, sprites, palettes and the song
- `tools/osmmap.py`, `tools/owbuild.py`, `tools/owart.py` — OpenStreetMap extract → 16×16 block map in the
  style of the Game Boy Color Pokémon games (original tiles)
- `tools/ending.py` — the ending illustration
- `tools/osm/` — OpenStreetMap extract of the area

Map data © OpenStreetMap contributors, available under the Open Database License (ODbL).
