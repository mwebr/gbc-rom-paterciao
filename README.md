# ENKA @ Ballhaus West — Game Boy Color promo

Promo cartridge for ENKA @ Ballhaus West (Hirschstraße 18, Karlsruhe), Thursday 29.10.2026, 18:00.
64 KiB ROM, MBC5, Game Boy Color only: `enka.gbc`. Classic house soundtrack from boot. In-game text is German.

## How it plays (about a minute)

1. **Title** — animated ENKA logo, START DRÜCKEN.
2. **Choose your DJs** — fighting-game style select: one big portrait at a time, left/right slides to the next. Pick four of six. Sima, Pater, João and da:sypoda lock in; the big names are busy.
3. **Dig the crates** — a record slot machine; stop the three crates with A. Jackpot: house classics.
4. **Loading party...**
5. **Bike ride** — from Karlsruhe Hauptbahnhof through the real streets (OpenStreetMap) to Ballhaus West,
   Hirschstraße 18. Yellow trams run on the tram lines, ICE trains behind the station, the zoo is fenced off,
   street names pop up as you ride and an arrow points the way.
6. **Inside Ballhaus West** — walk past the dance floor to the decks.
7. **Tech setup** — sound check on the turntables: 8 scratches (Left/Right).
8. **Ending** — the ENKA logo over a night scene at Ballhaus West, the line-up and your time. START plays again.

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
- `tools/art2.py` — walking sprites, trams/trains, club interior, DJ portraits, record sleeves
- `tools/osm/` — OpenStreetMap extract of the area

Map data © OpenStreetMap contributors, available under the Open Database License (ODbL).
