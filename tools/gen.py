#!/usr/bin/env python3
"""Generates graphics, tables and music data for the ENKA promo ROM.

Writes into build/gen/:
  tiles0.2bpp / tiles1.2bpp   VRAM bank 0 / bank 1 tile data
  gfx_defs.inc                tile index constants + charmaps
  data.inc                    ROM data sections (maps, palettes, tables, song)
"""
import colorsys
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "build", "gen")
os.makedirs(OUT, exist_ok=True)

# --------------------------------------------------------------------------
# Font (5x7)
# --------------------------------------------------------------------------
FONT = {
    "A": [".XXX.", "X...X", "X...X", "XXXXX", "X...X", "X...X", "X...X"],
    "B": ["XXXX.", "X...X", "X...X", "XXXX.", "X...X", "X...X", "XXXX."],
    "C": [".XXX.", "X...X", "X....", "X....", "X....", "X...X", ".XXX."],
    "D": ["XXXX.", "X...X", "X...X", "X...X", "X...X", "X...X", "XXXX."],
    "E": ["XXXXX", "X....", "X....", "XXXX.", "X....", "X....", "XXXXX"],
    "F": ["XXXXX", "X....", "X....", "XXXX.", "X....", "X....", "X...."],
    "G": [".XXX.", "X...X", "X....", "X.XXX", "X...X", "X...X", ".XXXX"],
    "H": ["X...X", "X...X", "X...X", "XXXXX", "X...X", "X...X", "X...X"],
    "I": [".XXX.", "..X..", "..X..", "..X..", "..X..", "..X..", ".XXX."],
    "J": ["..XXX", "...X.", "...X.", "...X.", "...X.", "X..X.", ".XX.."],
    "K": ["X...X", "X..X.", "X.X..", "XX...", "X.X..", "X..X.", "X...X"],
    "L": ["X....", "X....", "X....", "X....", "X....", "X....", "XXXXX"],
    "M": ["X...X", "XX.XX", "X.X.X", "X.X.X", "X...X", "X...X", "X...X"],
    "N": ["X...X", "X...X", "XX..X", "X.X.X", "X..XX", "X...X", "X...X"],
    "O": [".XXX.", "X...X", "X...X", "X...X", "X...X", "X...X", ".XXX."],
    "P": ["XXXX.", "X...X", "X...X", "XXXX.", "X....", "X....", "X...."],
    "Q": [".XXX.", "X...X", "X...X", "X...X", "X.X.X", "X..X.", ".XX.X"],
    "R": ["XXXX.", "X...X", "X...X", "XXXX.", "X.X..", "X..X.", "X...X"],
    "S": [".XXXX", "X....", "X....", ".XXX.", "....X", "....X", "XXXX."],
    "T": ["XXXXX", "..X..", "..X..", "..X..", "..X..", "..X..", "..X.."],
    "U": ["X...X", "X...X", "X...X", "X...X", "X...X", "X...X", ".XXX."],
    "V": ["X...X", "X...X", "X...X", "X...X", "X...X", ".X.X.", "..X.."],
    "W": ["X...X", "X...X", "X...X", "X.X.X", "X.X.X", "X.X.X", ".X.X."],
    "X": ["X...X", "X...X", ".X.X.", "..X..", ".X.X.", "X...X", "X...X"],
    "Y": ["X...X", "X...X", ".X.X.", "..X..", "..X..", "..X..", "..X.."],
    "Z": ["XXXXX", "....X", "...X.", "..X..", ".X...", "X....", "XXXXX"],
    # A with tilde (for JOAO -> JOÃO)
    "~": [".XX.X", "X.XX.", ".XXX.", "X...X", "XXXXX", "X...X", "X...X"],
    "0": [".XXX.", "X...X", "X..XX", "X.X.X", "XX..X", "X...X", ".XXX."],
    "1": ["..X..", ".XX..", "..X..", "..X..", "..X..", "..X..", ".XXX."],
    "2": [".XXX.", "X...X", "....X", "...X.", "..X..", ".X...", "XXXXX"],
    "3": ["XXXX.", "....X", "....X", ".XXX.", "....X", "....X", "XXXX."],
    "4": ["...X.", "..XX.", ".X.X.", "X..X.", "XXXXX", "...X.", "...X."],
    "5": ["XXXXX", "X....", "XXXX.", "....X", "....X", "X...X", ".XXX."],
    "6": [".XXX.", "X....", "X....", "XXXX.", "X...X", "X...X", ".XXX."],
    "7": ["XXXXX", "....X", "...X.", "..X..", ".X...", ".X...", ".X..."],
    "8": [".XXX.", "X...X", "X...X", ".XXX.", "X...X", "X...X", ".XXX."],
    "9": [".XXX.", "X...X", "X...X", ".XXXX", "....X", "....X", ".XXX."],
    ".": [".....", ".....", ".....", ".....", ".....", ".XX..", ".XX.."],
    ":": [".....", ".XX..", ".XX..", ".....", ".XX..", ".XX..", "....."],
    "!": ["..X..", "..X..", "..X..", "..X..", "..X..", ".....", "..X.."],
    "@": [".XXX.", "X...X", "X.XXX", "X.X.X", "X.XXX", "X....", ".XXXX"],
    "+": [".....", "..X..", "..X..", "XXXXX", "..X..", "..X..", "....."],
    "-": [".....", ".....", ".....", "XXXXX", ".....", ".....", "....."],
    "*": [".....", "X.X.X", ".XXX.", "XXXXX", ".XXX.", "X.X.X", "....."],
    "/": ["....X", "....X", "...X.", "..X..", ".X...", "X....", "X...."],
    ",": [".....", ".....", ".....", ".....", ".XX..", "..X..", ".X..."],
    "?": [".XXX.", "X...X", "....X", "...X.", "..X..", ".....", "..X.."],
    "&": [".XX..", "X..X.", "X.X..", ".X...", "X.X.X", "X..X.", ".XX.X"],
    "'": ["..X..", "..X..", ".X...", ".....", ".....", ".....", "....."],
    ">": [".X...", "..X..", "...X.", "....X", "...X.", "..X..", ".X..."],
    "<UP>": ["..X..", ".XXX.", "XXXXX", "..X..", "..X..", "..X..", "....."],
    "<DN>": [".....", "..X..", "..X..", "..X..", "XXXXX", ".XXX.", "..X.."],
    "<LT>": [".....", "..X..", ".X...", "XXXXX", ".X...", "..X..", "....."],
    "<RT>": [".....", "..X..", "...X.", "XXXXX", "...X.", "..X..", "....."],
    "<3": [".....", ".X.X.", "XXXXX", "XXXXX", ".XXX.", "..X..", "....."],
}
FONT_ORDER = list(FONT.keys())

# ENKA logo letters (7x7, drawn at 4x)
LOGO = {
    "E": ["XXXXXXX", "XX.....", "XX.....", "XXXXXX.", "XX.....", "XX.....", "XXXXXXX"],
    "N": ["XX...XX", "XXX..XX", "XXXX.XX", "XX.XXXX", "XX..XXX", "XX...XX", "XX...XX"],
    "K": ["XX...XX", "XX..XX.", "XX.XX..", "XXXX...", "XX.XX..", "XX..XX.", "XX...XX"],
    "A": ["..XXX..", ".XX.XX.", "XX...XX", "XX...XX", "XXXXXXX", "XX...XX", "XX...XX"],
}


def blank(w, h):
    return [[0] * w for _ in range(h)]


def tile_bytes(t):
    out = bytearray()
    for row in t:
        lo = hi = 0
        for x, c in enumerate(row):
            if c & 1:
                lo |= 0x80 >> x
            if c & 2:
                hi |= 0x80 >> x
        out += bytes([lo, hi])
    return bytes(out)


def cut(img):
    h, w = len(img), len(img[0])
    tiles = []
    for ty in range(h // 8):
        for tx in range(w // 8):
            tiles.append([row[tx * 8:tx * 8 + 8] for row in img[ty * 8:ty * 8 + 8]])
    return tiles


def render(glyph, scale, ox, oy, sh, w, h, color_fn):
    """Glyph with a drop shadow (colour 1); body colour from color_fn(y)."""
    img = blank(w, h)
    pts = [(x, y) for y, r in enumerate(glyph) for x, ch in enumerate(r) if ch == "X"]
    for x, y in pts:
        for dy in range(scale):
            for dx in range(scale):
                img[oy + y * scale + dy + sh][ox + x * scale + dx + sh] = 1
    for x, y in pts:
        for dy in range(scale):
            for dx in range(scale):
                py = y * scale + dy
                img[oy + py][ox + x * scale + dx] = color_fn(py)
    return img


def parse_sprite(rows):
    return [[int(c) if c != "." else 0 for c in r] for r in rows]


# --------------------------------------------------------------------------
# Bank 0 tiles: small font, UI tiles, logo, sprites
# --------------------------------------------------------------------------
bank0 = [blank(8, 8)]
defs = []
charmap_small = {" ": 0}

for ch in FONT_ORDER:
    charmap_small[ch] = len(bank0)
    bank0.append(render(FONT[ch], 1, 1, 0, 1, 8, 8, lambda y: 3))

checker = [[1 if ((x // 4) + (y // 4)) % 2 == 0 else 2 for x in range(8)] for y in range(8)]
defs.append(("TILE_CHECKER", len(bank0)))
bank0.append(checker)
floor = blank(8, 8)
floor[0] = [3] * 8
floor[1] = [2] * 8
floor[3] = [1, 0] * 4
defs.append(("TILE_FLOOR", len(bank0)))
bank0.append(floor)


def logo_color(y):
    if y < 13:
        return 3
    if y == 13 or y in (17, 20, 23, 26):
        return 1
    return 2


logo_img = blank(128, 32)
for i, ch in enumerate("ENKA"):
    g = render(LOGO[ch], 4, 1, 0, 3, 32, 32, logo_color)
    for y in range(32):
        for x in range(32):
            logo_img[y][i * 32 + x] = g[y][x]
logo_map = []
seen = {}
for t in cut(logo_img):
    key = tile_bytes(t)
    if key not in seen:
        seen[key] = len(bank0)
        bank0.append(t)
    logo_map.append(seen[key])

# sprites (8x16 mode -> even tile index, two tiles each)
if len(bank0) % 2:
    bank0.append(blank(8, 8))

EMPTY8 = ["........"] * 8
SPRITES = {
    "SPR_CURSOR": [
        "3.......", "33......", "333.....", "3333....", "3331....", "331.....", "31......", "1.......",
    ] + EMPTY8,
    "SPR_SPARK0": ["........", "........", "........", "...3....", "........", "........", "........", "........"] + EMPTY8,
    "SPR_SPARK1": ["........", "........", "...2....", "..232...", "...2....", "........", "........", "........"] + EMPTY8,
    "SPR_SPARK2": ["...1....", "...2....", "..121...", "1223221.", "..121...", "...2....", "...1....", "........"] + EMPTY8,
    "SPR_NOTE": [
        "....33..", "....323.", "....3.33", "....3..3", "....3...", "....3...", "..333...", ".3223...",
        ".3221...", "..11....", "........", "........", "........", "........", "........", "........",
    ],
    "SPR_STAR0": ["........", "........", "........", "...3....", "........", "........", "........", "........"] + EMPTY8,
    "SPR_STAR1": ["........", "........", "...2....", "..232...", "...2....", "........", "........", "........"] + EMPTY8,
    # record rotation marker, dot centred on pixel (3,3)
    "SPR_DOT": ["........", "........", "..333...", "..333...", "..333...", "........", "........", "........"] + EMPTY8,
}
for name, rows in SPRITES.items():
    defs.append((name, len(bank0)))
    px = parse_sprite(rows)
    bank0.append(px[:8])
    bank0.append(px[8:])

# equalizer bar segments: 8 variants, fill height 2..16 (row 0 always empty = gap)
defs.append(("SPR_BAR", len(bank0)))
for v in range(8):
    h = (v + 1) * 2
    img = blank(8, 16)
    for y in range(16 - h, 16):
        if y == 0:
            continue
        img[y] = [3] + [2] * 6 + [1]
    bank0.append(img[:8])
    bank0.append(img[8:])


# turntable deck, 72x64 px (9x8 tiles)
# colours: 0 = background, 1 = plinth/silver, 2 = vinyl/dark, 3 = label/accent
DECK_W, DECK_H = 72, 64
DECK_CX, DECK_CY, DECK_R = 30, 32, 27
deck = blank(DECK_W, DECK_H)
for y in range(DECK_H):
    for x in range(DECK_W):
        corner = min(x, DECK_W - 1 - x) + min(y, DECK_H - 1 - y) < 3
        if corner:
            continue
        edge = x in (0, DECK_W - 1) or y in (0, DECK_H - 1)
        c = 2 if edge else 1
        d = math.hypot(x + 0.5 - DECK_CX, y + 0.5 - DECK_CY)
        a = math.degrees(math.atan2(y + 0.5 - DECK_CY, x + 0.5 - DECK_CX)) % 360
        if d <= DECK_R:
            c = 2
            if 12 < d < DECK_R - 1 and int(d) % 3 == 0 and (x + y) % 2 == 0:
                c = 1                                   # grooves
            if d <= 10:
                c = 3                                   # label
            if d <= 1.6:
                c = 1                                   # spindle
        elif d <= DECK_R + 3 and int(a) % 20 < 6 and d > DECK_R + 1:
            c = 3                                       # strobe dots on the platter rim
        deck[y][x] = c


def deck_line(x0, y0, x1, y1, w, c):
    n = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
    for i in range(n + 1):
        t = i / n
        px, py = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
        for dy in range(w):
            for dx in range(w):
                deck[int(py) + dy][int(px) + dx] = c


def deck_rect(x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            deck[y][x] = c


# tonearm: pivot, arm, headshell resting on the record
for y in range(3, 16):
    for x in range(57, 70):
        d = math.hypot(x + 0.5 - 63.5, y + 0.5 - 9.5)
        if d <= 5.5:
            deck[y][x] = 2
        if d <= 2:
            deck[y][x] = 3
deck_line(63, 9, 57, 38, 2, 2)
deck_rect(53, 38, 58, 44, 3)
deck_rect(54, 39, 57, 43, 2)
# start/stop button and pitch fader
deck_rect(3, 55, 9, 59, 3)
deck_line(67, 24, 67, 58, 2, 2)
deck_rect(64, 44, 70, 47, 3)

deck_map = []
for t in cut(deck):
    key = tile_bytes(t)
    if key not in seen:
        seen[key] = len(bank0)
        bank0.append(t)
    deck_map.append(seen[key])

assert len(bank0) <= 256, len(bank0)

# --------------------------------------------------------------------------
# Bank 1 tiles: 2x font (16x16 per glyph, 4 tiles: TL TR BL BR)
# --------------------------------------------------------------------------
bank1 = [blank(8, 8) for _ in range(4)]  # glyph base 0 = space
charmap_big = {" ": 0}
for ch in FONT_ORDER:
    img = render(FONT[ch], 2, 2, 0, 2, 16, 16, lambda y: 3 if y < 8 else 2)
    tl, tr, bl, br = cut(img)
    charmap_big[ch] = len(bank1)
    bank1 += [tl, tr, bl, br]
assert len(bank1) <= 256, len(bank1)

with open(os.path.join(OUT, "tiles0.2bpp"), "wb") as f:
    f.write(b"".join(tile_bytes(t) for t in bank0))
with open(os.path.join(OUT, "tiles1.2bpp"), "wb") as f:
    f.write(b"".join(tile_bytes(t) for t in bank1))


def charmap_lines(name, cmap):
    lines = [f"NEWCHARMAP {name}"]
    for ch, v in cmap.items():
        lines.append(f'CHARMAP "{ch}", {v}')
    return lines


with open(os.path.join(OUT, "gfx_defs.inc"), "w") as f:
    f.write("; generated by tools/gen.py\n")
    for n, v in defs:
        f.write(f"DEF {n} EQU {v}\n")
    f.write(f"DEF NUM_TILES0 EQU {len(bank0)}\n")
    f.write(f"DEF NUM_TILES1 EQU {len(bank1)}\n")
    f.write("\n".join(charmap_lines("small", charmap_small)) + "\n")
    f.write("\n".join(charmap_lines("big", charmap_big)) + "\n")
    f.write("SETCHARMAP small\n")

# --------------------------------------------------------------------------
# Palettes & tables
# --------------------------------------------------------------------------
def rgb(r, g, b):
    return (r & 31) | ((g & 31) << 5) | ((b & 31) << 10)


NAVY = rgb(3, 3, 10)
SHADOW = rgb(0, 0, 3)
WHITE = rgb(31, 31, 31)
BG = [
    [NAVY, SHADOW, rgb(18, 18, 26), WHITE],               # 0 text
    [NAVY, SHADOW, rgb(20, 4, 20), rgb(31, 20, 31)],      # 1 logo / big title (cycled)
    [NAVY, SHADOW, rgb(0, 18, 22), rgb(8, 31, 31)],       # 2 cyan
    [NAVY, SHADOW, rgb(20, 4, 14), rgb(31, 12, 24)],      # 3 pink
    [NAVY, SHADOW, rgb(22, 16, 0), rgb(31, 28, 6)],       # 4 yellow
    [NAVY, SHADOW, rgb(4, 20, 8), rgb(12, 31, 14)],       # 5 green
    [NAVY, rgb(6, 3, 14), rgb(12, 5, 22), WHITE],         # 6 border
    [NAVY, SHADOW, rgb(22, 10, 0), rgb(31, 20, 6)],       # 7 orange
]
OBJ = [
    [0, rgb(4, 2, 0), rgb(31, 18, 0), rgb(31, 31, 10)],   # 0 cursor
    [0, rgb(10, 10, 31), rgb(20, 22, 31), WHITE],         # 1 sparkle
    [0, rgb(6, 0, 6), rgb(31, 8, 20), rgb(31, 22, 28)],   # 2 notes
    [0, rgb(8, 8, 16), rgb(14, 14, 24), WHITE],           # 3 stars
    [0, rgb(0, 10, 2), rgb(4, 24, 6), rgb(18, 31, 18)],   # 4 bar green
    [0, rgb(12, 10, 0), rgb(28, 24, 0), rgb(31, 31, 18)], # 5 bar yellow
    [0, rgb(14, 5, 0), rgb(31, 14, 0), rgb(31, 26, 14)],  # 6 bar orange
    [0, rgb(12, 0, 2), rgb(31, 4, 6), rgb(31, 18, 20)],   # 7 bar red
]


def hsv(h, s, v):
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return rgb(round(r * 31), round(g * 31), round(b * 31))


RAINBOW_HI = [hsv(i / 32, 0.55, 1.0) for i in range(32)]
RAINBOW_LO = [hsv(i / 32, 0.95, 0.7) for i in range(32)]
FLASH = [rgb(round(3 + 9 * i / 8), round(3 + 1 * i / 8), round(10 + 8 * i / 8)) for i in range(9)]
SINE = [round(math.sin(2 * math.pi * i / 256) * 16) & 0xFF for i in range(256)]
FADE = [[round(c * (4 - k) / 4) for c in range(32)] for k in range(5)]


def db(vals, per=16):
    return "\n".join("    db " + ", ".join(f"${v:02X}" for v in vals[i:i + per]) for i in range(0, len(vals), per))


def dw(vals, per=8):
    return "\n".join("    dw " + ", ".join(f"${v:04X}" for v in vals[i:i + per]) for i in range(0, len(vals), per))


# --------------------------------------------------------------------------
# Music: classic house, A minor, 128 BPM with swing
# --------------------------------------------------------------------------
def nidx(midi):  # note index used by the driver
    return midi - 23


NOTE_MAX = 96
SQ_FREQ = [0] + [max(0, min(2047, round(2048 - 131072 / (440 * 2 ** ((m - 69) / 12)))))
                 for m in range(24, NOTE_MAX + 1)]
WAVE_FREQ = [0] + [max(0, min(2047, round(2048 - 65536 / (440 * 2 ** ((m - 69) / 12)))))
                   for m in range(24, NOTE_MAX + 1)]

# chord id -> 4 voices (arpeggiated on CH2), plus bass root
CHORDS = {
    1: ([60, 64, 67, 69], 45),  # Am7   (C E G A),  root A2
    2: ([60, 64, 65, 69], 41),  # Fmaj7 (C E F A),  root F2
    3: ([60, 62, 65, 69], 38),  # Dm7   (C D F A),  root D2
    4: ([59, 62, 64, 68], 40),  # E7    (B D E G#), root E2
}
PROG = [1, 2, 3, 4]

KICK, CHAT, OHAT, CLAP = 1, 2, 4, 8

STAB_R1 = [0, 3, 6, 10, 13]
STAB_R2 = [3, 6, 8, 11, 14]
BASS_A = {2: 0, 6: 0, 7: 12, 10: 0, 14: 0, 15: 7}
BASS_B = {2: 0, 3: 12, 6: 0, 9: 12, 10: 0, 13: 7, 14: 0}
LEAD = {  # breakdown melody, per chord
    1: {0: 76, 6: 74, 10: 72},
    2: {0: 72, 8: 69},
    3: {0: 69, 6: 72, 10: 74},
    4: {0: 71, 8: 68},
}


def bar(chord, kick=True, clap=True, ohat=True, chat=False, bass=None, stab=None, lead=False, roll=False):
    steps = []
    notes, root = CHORDS[chord]
    for s in range(16):
        d = 0
        if kick and s % 4 == 0:
            d |= KICK
        if clap and s in (4, 12):
            d |= CLAP
        if ohat and s % 4 == 2:
            d |= OHAT
        if chat:
            d |= CHAT
        if roll and s >= 8:
            d |= CLAP
        b = nidx(root + bass[s]) if bass and s in bass else 0
        st = chord if stab and s in stab else 0
        ld = nidx(LEAD[chord][s]) if lead and s in LEAD[chord] else 0
        steps.append((d, b, st, ld))
    return steps


song_intro, song_loop = [], []
for i in range(4):  # intro: drums only, clap comes in
    song_intro += bar(PROG[i], clap=i >= 2, stab=None)
for rep in range(2):  # A: full groove
    for c in PROG:
        song_loop += bar(c, bass=BASS_A, stab=STAB_R1)
for rep in range(2):  # B: busier hats, new stab/bass rhythm
    for c in PROG:
        song_loop += bar(c, chat=True, bass=BASS_B, stab=STAB_R2)
for i, c in enumerate(PROG):  # breakdown: no kick, lead melody, snare roll
    song_loop += bar(c, kick=False, clap=False, ohat=i < 3, stab=STAB_R1 if i < 3 else [0, 3, 6],
                     lead=True, roll=i == 3)

WAVE = [0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF, 0xFE, 0xDC, 0xBA, 0x98, 0xFF, 0xFF, 0x00, 0x00]

with open(os.path.join(OUT, "data.inc"), "w") as f:
    w = f.write
    w("; generated by tools/gen.py\n\n")
    w('SECTION "LogoMap", ROM0\nLogoMap:\n' + db(logo_map) + "\n\n")
    w('SECTION "DeckMap", ROM0\nDeckMap:\n' + db(deck_map, 9) + "\n\n")
    w('SECTION "Palettes", ROM0\nDefaultPalettes:\n' + dw([c for p in BG + OBJ for c in p]) + "\n")
    DECK = [NAVY, rgb(18, 18, 22), rgb(2, 2, 5)]
    w("DeckPalettes:\n" + dw(DECK + [rgb(31, 10, 24)] + DECK + [rgb(8, 28, 31)]) + "\n")
    w("RainbowHi:\n" + dw(RAINBOW_HI) + "\n")
    w("RainbowLo:\n" + dw(RAINBOW_LO) + "\n")
    w("FlashTab:\n" + dw(FLASH) + "\n\n")
    w('SECTION "SineTab", ROM0, ALIGN[8]\nSineTab:\n' + db(SINE) + "\n\n")
    w('SECTION "FadeTab", ROM0, ALIGN[8]\nFadeTab:\n' + db([c for row in FADE for c in row]) + "\n\n")
    w('SECTION "Song", ROM0\n')
    w("SqFreq:\n" + dw(SQ_FREQ) + "\n")
    w("WaveFreq:\n" + dw(WAVE_FREQ) + "\n")
    w("ChordTab:\n    db 0, 0, 0, 0\n")
    for cid in sorted(CHORDS):
        w("    db " + ", ".join(str(nidx(n)) for n in CHORDS[cid][0]) + "\n")
    w("WaveData:\n" + db(WAVE) + "\n")
    w("SongStart:\n")
    for s in song_intro:
        w("    db " + ", ".join(str(v) for v in s) + "\n")
    w("SongLoop:\n")
    for s in song_loop:
        w("    db " + ", ".join(str(v) for v in s) + "\n")
    w("SongEnd:\n")

print(f"deck tiles: {len(set(deck_map))}, bank0 tiles: {len(bank0)}, bank1 tiles: {len(bank1)}, logo tiles: {len(seen)}, "
      f"song steps: {len(song_intro) + len(song_loop)}")
