# ENKA @ Ballhaus West — Game Boy Color promo

Promo cartridge for ENKA @ Ballhaus West (Europaplatz, Karlsruhe), Thursday 29.10.2026.
32 KiB ROM, no MBC, Game Boy Color only: `enka.gbc`. Classic house soundtrack from boot.

## How it plays (about a minute)

1. **Title** — ENKA, date, venue. Line-up: ???. Press START.
2. **Setup 1/3** — pick the start time (Up/Down, A).
3. **Setup 2/3** — book two DJs. Not everyone on the list makes the cut.
4. **Setup 3/3** — warm up the decks: 8 scratches (Left/Right), Up/Down switches deck, A starts/stops a platter.
5. **Loading party...**
6. **Bike ride** — from the Marktplatz pyramid to Ballhaus West. D-pad rides, A talks/reads.
   Mind the roadworks and the tram.
7. **Ending** — your picks, your time, tram bumps. START plays again.

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
- `tools/gen.py` — generates font, logo, turntables, city map, sprites, palettes and the song
