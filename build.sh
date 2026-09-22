#!/bin/sh
# Builds enka.gbc. Needs python3 and RGBDS 1.0 (bundled in tools/rgbds).
set -e
cd "$(dirname "$0")"
RGBDS=${RGBDS:-tools/rgbds/}
python3 tools/gen.py
${RGBDS}rgbasm -Weverything -Wno-unmapped-char -I src -I build/gen -o build/main.o src/main.asm
${RGBDS}rgblink -n build/enka.sym -m build/enka.map -o enka.gbc build/main.o
${RGBDS}rgbfix -C -v -p 0xFF -j -m 0x19 -t "ENKA PROMO" -k "EK" -l 0x33 enka.gbc
echo "built enka.gbc"
