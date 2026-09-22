# ENKA @ Ballhaus West — Game Boy Color promo

Promo cartridge for ENKA @ Ballhaus West, Thursday 29.10.2026, with DJs Sima and Pater João.
32 KiB ROM, no MBC, Game Boy Color only: `enka.gbc`.

Screens: animated title with house music, menu (line-up, date + venue, turntables you can scratch, visualizer, music on/off).

## Build

Needs Python 3 and [RGBDS](https://github.com/gbdev/rgbds) 1.0:

```sh
mkdir -p tools/rgbds
curl -sL https://github.com/gbdev/rgbds/releases/download/v1.0.4/rgbds-linux-x86_64.tar.xz | tar -xJ -C tools/rgbds
./build.sh
```

Or point `RGBDS=/path/to/bin/` at an existing install.

- `src/main.asm` — program and sound driver
- `tools/gen.py` — generates font, logo, sprites, turntable graphics, palettes and the song
