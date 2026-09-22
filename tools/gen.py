#!/usr/bin/env python3
"""Generates graphics, tables and music data for the ENKA promo ROM.

Writes into build/gen/:
  tiles0.2bpp / tiles1.2bpp   VRAM bank 0 / bank 1 tile data
  *.2bpp                      per-screen tile sets
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
    "<NEXT>": [".....", "XXXXX", ".XXX.", "..X..", ".....", ".....", "....."],
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
# VRAM layout
#   bank 0, tiles 0..SCENE_BASE-1: font, UI, shared sprites (always loaded)
#   bank 0, tiles SCENE_BASE..255: per-screen set (logo / decks / overworld sprites)
#   bank 1, tiles 0..255: 2x font, or overworld background tiles
# --------------------------------------------------------------------------
defs = []


def tileset_add(tiles, index, t):
    """Add tile t (dedup), return its VRAM index. `index` maps bytes -> vram index."""
    key = tile_bytes(t)
    if key not in index:
        index[key] = tiles[0] + len(tiles[1])
        tiles[1].append(t)
    return index[key]


# --- fixed bank 0 ------------------------------------------------------------
bank0 = [blank(8, 8)]
charmap_small = {" ": 0}
for ch in FONT_ORDER:
    charmap_small[ch] = len(bank0)
    bank0.append(render(FONT[ch], 1, 1, 0, 1, 8, 8, lambda y: 3))


def add_fixed(name, rows):
    defs.append((name, len(bank0)))
    bank0.append(parse_sprite(rows) if isinstance(rows[0], str) else rows)


add_fixed("TILE_CHECKER", [[1 if ((x // 4) + (y // 4)) % 2 == 0 else 2 for x in range(8)] for y in range(8)])
add_fixed("TILE_BAR_EMPTY", ["11111111", "........", "........", "........", "........", "........", "........", "11111111"])
add_fixed("TILE_BAR_FULL", ["11111111", "33333333", "33333333", "33333333", "22222222", "22222222", "22222222", "11111111"])

# text box frame
TB_TL = ["........", "........", "..333333", ".3333333", ".33.....", ".33.....", ".33.....", ".33....."]
TB_T = ["........", "........", "33333333", "33333333", "........", "........", "........", "........"]
TB_L = [".33....."] * 8
TB_BL = [".33.....", ".33.....", ".33.....", ".33.....", ".3333333", "..333333", "........", "........"]
TB_B = ["........", "........", "........", "........", "33333333", "33333333", "........", "........"]


def mirror(rows):
    return [r[::-1] for r in rows]


for name, rows in [("TB_TL", TB_TL), ("TB_T", TB_T), ("TB_TR", mirror(TB_TL)), ("TB_L", TB_L),
                   ("TB_R", mirror(TB_L)), ("TB_BL", TB_BL), ("TB_B", TB_B), ("TB_BR", mirror(TB_BL))]:
    add_fixed("TILE_" + name, rows)

if len(bank0) % 2:
    bank0.append(blank(8, 8))

EMPTY8 = ["........"] * 8
SPRITES = {
    "SPR_CURSOR": ["3.......", "33......", "333.....", "3333....", "3331....", "331.....", "31......", "1......."] + EMPTY8,
    "SPR_SPARK0": ["........", "........", "........", "...3....", "........", "........", "........", "........"] + EMPTY8,
    "SPR_SPARK1": ["........", "........", "...2....", "..232...", "...2....", "........", "........", "........"] + EMPTY8,
    "SPR_SPARK2": ["...1....", "...2....", "..121...", "1223221.", "..121...", "...2....", "...1....", "........"] + EMPTY8,
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

SCENE_BASE = len(bank0)
defs.append(("SCENE_BASE", SCENE_BASE))


def new_scene():
    return [SCENE_BASE, []], {}


# --- scene: ENKA logo ----------------------------------------------------------
def logo_color(y):
    if y < 13:
        return 3
    if y == 13 or y in (17, 20, 23, 26):
        return 1
    return 2


scene_logo, idx = new_scene()
logo_img = blank(128, 32)
for i, ch in enumerate("ENKA"):
    g = render(LOGO[ch], 4, 1, 0, 3, 32, 32, logo_color)
    for y in range(32):
        for x in range(32):
            logo_img[y][i * 32 + x] = g[y][x]
logo_map = [tileset_add(scene_logo, idx, t) for t in cut(logo_img)]

# --- scene: turntable deck, 72x64 px -------------------------------------------
# colours: 0 = background, 1 = plinth/silver, 2 = vinyl/dark, 3 = label/accent
DECK_W, DECK_H = 72, 64
DECK_CX, DECK_CY, DECK_R = 30, 32, 27
deck = blank(DECK_W, DECK_H)
for y in range(DECK_H):
    for x in range(DECK_W):
        if min(x, DECK_W - 1 - x) + min(y, DECK_H - 1 - y) < 3:
            continue
        c = 2 if x in (0, DECK_W - 1) or y in (0, DECK_H - 1) else 1
        d = math.hypot(x + 0.5 - DECK_CX, y + 0.5 - DECK_CY)
        a = math.degrees(math.atan2(y + 0.5 - DECK_CY, x + 0.5 - DECK_CX)) % 360
        if d <= DECK_R:
            c = 2
            if 12 < d < DECK_R - 1 and int(d) % 3 == 0 and (x + y) % 2 == 0:
                c = 1
            if d <= 10:
                c = 3
            if d <= 1.6:
                c = 1
        elif DECK_R + 1 < d <= DECK_R + 3 and int(a) % 20 < 6:
            c = 3
        deck[y][x] = c


def draw_line(img, x0, y0, x1, y1, w, c):
    n = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
    for i in range(n + 1):
        t = i / n
        px, py = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
        for dy in range(w):
            for dx in range(w):
                img[int(py) + dy][int(px) + dx] = c


def draw_rect(img, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            img[y][x] = c


for y in range(3, 16):
    for x in range(57, 70):
        d = math.hypot(x + 0.5 - 63.5, y + 0.5 - 9.5)
        if d <= 5.5:
            deck[y][x] = 2
        if d <= 2:
            deck[y][x] = 3
draw_line(deck, 63, 9, 57, 38, 2, 2)
draw_rect(deck, 53, 38, 58, 44, 3)
draw_rect(deck, 54, 39, 57, 43, 2)
draw_rect(deck, 3, 55, 9, 59, 3)
draw_line(deck, 67, 24, 67, 58, 2, 2)
draw_rect(deck, 64, 44, 70, 47, 3)

scene_deck, idx = new_scene()
deck_map = [tileset_add(scene_deck, idx, t) for t in cut(deck)]

# --- scene: overworld sprites (16x16 = two 8x16 halves) --------------------------
BIKE_D = [
    ".....111111.....", "....11111111....", "....13333331....", "....13133131....", "....13333331....",
    ".....133331.....", "....12222221....", "...3122222213...", "..311111111113..", "....12222221....",
    "....11222211....", "....1.1111.1....",
]
BIKE_D0 = ["................"] + BIKE_D + ["....1..11.......", "......1111......", ".......11......."]
BIKE_D1 = ["................"] + BIKE_D + [".......11..1....", "......1111......", ".......11......."]
BIKE_U = [
    ".....111111.....", "....11111111....", "....11111111....", "....11111111....", "....31111113....",
    ".....133331.....", "....12222221....", "...3122222213...", "...3122222213...", "....12222221....",
    "....11111111....", "....1.1111.1....",
]
BIKE_U0 = ["................"] + BIKE_U + ["....1..11.......", "......1111......", ".......11......."]
BIKE_U1 = ["................"] + BIKE_U + [".......11..1....", "......1111......", ".......11......."]
BIKE_L = [
    "................", ".....11111......", "....1111111.....", "....3131111.....", "....3333111.....",
    ".....33311......", ".....12221......", "....1222221.....", "..331222221.....", "..2.1222221.....",
    "..2..111111.....", ".121..11...111..",
]
BIKE_L0 = BIKE_L + ["1.2.1..1..1...1.", "1.2.1.111.1.2.1.", "1...1.....1...1.", ".111.......111.."]
BIKE_L1 = BIKE_L + ["1.2.1.1...1...1.", "1.2.1..11.1.2.1.", "1...1.....1...1.", ".111.......111.."]
PERSON = [
    "................", "......1111......", ".....111111.....", ".....133331.....", ".....313313.....",
    ".....133331.....", "......1331......", "....11222211....", "...1222222221...", "...3122222213...",
    "...3122222213...", "....12222221....", "....11111111....", "....111..111....", "....11....11....",
    "....11....11....",
]
WORKER = [
    "................", "......2222......", ".....222222.....", "....22222222....", ".....313313.....",
    ".....133331.....", "......1331......", "....11222211....", "...1222222221...", "...3122222213...",
    "...3122222213...", "....12222221....", "....11111111....", "....111..111....", "....11....11....",
    "....11....11....",
]
BOUNCER = [
    "................", "......1111......", ".....111111.....", ".....133331.....", ".....111111.....",
    ".....133331.....", "......1331......", "...1112222111...", "..122222222221..", "..122222222221..",
    "..312222222213..", "...1222222221...", "...1111111111...", "....111..111....", "....11....11....",
    "...111....111...",
]
GOAT = [
    "................", "...1.1..........", "...1.1..........", "..12221.........", ".1212221........",
    ".12222211111111.", ".311222222222221", ".33.122222222221", "...1222222222221", "...1222222222221",
    "...1111111111111", "...1.1.....1.1..", "...1.1.....1.1..", "...1.1.....1.1..", "..11.11...11.11.",
    "................",
]

# tram, 48x16, drawn procedurally: 1 = outline, 2 = body, 3 = windows
tram = blank(48, 16)
for y in range(2, 15):
    for x in range(0, 48):
        if (x < 2 and y < 4) or (x < 1 and y > 12):
            continue
        edge = y in (2, 14) or x in (0, 47)
        c = 1 if edge else 2
        if 4 <= y <= 8 and 3 <= x <= 45:
            c = 1 if x % 8 in (2, 3) or y in (4, 8) else 3
        if y == 11:
            c = 3 if 2 <= x <= 45 else c
        tram[y][x] = c
for x in range(18, 30):
    tram[0][x] = 1 if x in (18, 29) or x % 3 == 0 else 0
    tram[1][x] = 1 if x in (20, 27) else 0
for cx in (8, 38):
    for x in range(cx - 3, cx + 3):
        tram[15][x] = 1

scene_ow, idx = new_scene()


def add_sprite16(name, rows, scene):
    """16x16 sprite -> 4 consecutive tiles: left half (top, bottom), right half (top, bottom)."""
    px = parse_sprite(rows) if isinstance(rows[0], str) else rows
    left = [r[:8] for r in px]
    right = [r[8:] for r in px]
    defs.append((name, scene[0] + len(scene[1])))
    scene[1] += [left[:8], left[8:], right[:8], right[8:]]


for name, rows in [("SPR_BIKE_D0", BIKE_D0), ("SPR_BIKE_D1", BIKE_D1), ("SPR_BIKE_U0", BIKE_U0),
                   ("SPR_BIKE_U1", BIKE_U1), ("SPR_BIKE_L0", BIKE_L0), ("SPR_BIKE_L1", BIKE_L1),
                   ("SPR_PERSON", PERSON), ("SPR_WORKER", WORKER), ("SPR_BOUNCER", BOUNCER), ("SPR_GOAT", GOAT)]:
    assert len(rows) == 16 and all(len(r) == 16 for r in rows), name
    add_sprite16(name, rows, scene_ow)
defs.append(("SPR_TRAM", scene_ow[0] + len(scene_ow[1])))
for i in range(3):
    add_sprite16(f"_tram{i}", [r[i * 16:i * 16 + 16] for r in tram], scene_ow)

for name, sc in [("logo", scene_logo), ("deck", scene_deck), ("overworld sprites", scene_ow)]:
    assert SCENE_BASE + len(sc[1]) <= 256, (name, len(sc[1]))

# --------------------------------------------------------------------------
# Bank 1: 2x font (16x16 per glyph, 4 tiles: TL TR BL BR)
# --------------------------------------------------------------------------
bigfont = [blank(8, 8) for _ in range(4)]  # glyph base 0 = space
charmap_big = {" ": 0}
for ch in FONT_ORDER:
    img = render(FONT[ch], 2, 2, 0, 2, 16, 16, lambda y: 3 if y < 8 else 2)
    tl, tr, bl, br = cut(img)
    charmap_big[ch] = len(bigfont)
    bigfont += [tl, tr, bl, br]
assert len(bigfont) <= 256, len(bigfont)

# --------------------------------------------------------------------------
# Overworld: Karlsruhe, from the Marktplatz pyramid to Ballhaus West @ Europaplatz
# 16x16 metatiles, map is 16x16 metatiles = 256x256 px (no streaming needed)
# --------------------------------------------------------------------------
OW_MAP = [
    "TTTTTTTTTTTTTTTT",
    "TRRRRRRRRRRTPP:T",
    "TWDWWDWWDWWKPP:T",
    "T:::::X:::::S:oT",
    "T:::::Xw:::::@:T",
    "TTTTTTTTT|TT,,,T",
    "TRRRRRR,,|,RRR,T",
    "TWWDWWW,,|,WDW,T",
    "----------------",
    "T==============T",
    "TbbbbbE::.,..,.T",
    "TFFFFF:d:.,..,.T",
    "THHOHH:::T.,g,.T",
    "T:k:::::.T,..,.T",
    "T::::::::TT.,..T",
    "TTTTTTTTTTTTTTTT",
]
NPC_TYPES = {"o": 0, "w": 1, "d": 2, "g": 3, "k": 4}   # oma, worker, doener guy, goat, bouncer
NPC_GROUND = {"g": "."}
EVENTS = {"S": 1, "E": 2, "D": 3, "K": 4, "X": 5, "O": 31}
SOLID = set("TRWPbFHSEDKXO")
OW_PAL = {".": 1, "T": 1, ",": 7, ":": 2, "=": 2, "|": 2, "-": 2, "R": 3, "W": 3, "D": 3,
          "P": 4, "b": 5, "F": 5, "H": 5, "O": 5, "S": 6, "E": 6, "K": 6, "X": 6}


def mt_new(c=0):
    return [[c] * 16 for _ in range(16)]


def mt_grass():
    m = mt_new(0)
    for x, y in [(2, 3), (10, 1), (12, 9), (4, 11), (8, 6), (13, 13)]:
        m[y][x] = m[y][x + 2] = 1
        m[y + 1][x + 1] = 1
    return m


def mt_cobble(mortar=1):
    m = mt_new(0)
    for y in range(16):
        for x in range(16):
            if y % 4 == 3 or (x + (4 if (y // 4) % 2 else 0)) % 8 == 7:
                m[y][x] = mortar
    return m


def mt_road(vertical=False):
    m = mt_new(1)
    for x, y in [(3, 2), (11, 4), (6, 12), (13, 10), (1, 9)]:
        m[y][x] = 2
    for i in range(16):
        m[0][i] = m[15][i] = 2
        if (i // 4) % 2 == 0:
            m[7][i] = m[8][i] = 3
    if vertical:
        m = [list(r) for r in zip(*m)]
    return m


def mt_tracks():
    m = mt_cobble()
    for y in range(3, 13):
        for x in range(16):
            if x % 4 in (1, 2):
                m[y][x] = 1
    for x in range(16):
        m[4][x] = m[10][x] = 3
        m[5][x] = m[11][x] = 2
    return m


def mt_tree():
    m = mt_grass()
    for y in range(16):
        for x in range(16):
            d = math.hypot(x + 0.5 - 8, y + 0.5 - 6.5)
            if d <= 7:
                m[y][x] = 2 if x + y > 17 else 1
                if d > 6:
                    m[y][x] = 3
                if (x, y) in ((5, 3), (6, 3), (5, 4), (9, 5)):
                    m[y][x] = 0
    for y in range(12, 16):
        for x in range(6, 10):
            m[y][x] = 3 if x in (6, 9) else 2
    return m


def mt_flowers():
    m = mt_grass()
    for i, (x, y) in enumerate([(3, 3), (11, 5), (6, 10), (12, 12)]):
        petal = 1 if i % 2 == 0 else 2
        for dx, dy in [(0, -1), (-1, 0), (1, 0), (0, 1)]:
            m[y + dy][x + dx] = petal
        m[y][x] = 3 if petal == 1 else 1
    return m


def mt_roof():
    m = mt_new(1)
    for y in range(16):
        for x in range(16):
            if y % 4 == 3 or y == 15:
                m[y][x] = 2
            elif (x + (2 if (y // 4) % 2 else 0)) % 4 == 0 and y % 4 == 1:
                m[y][x] = 2
    return m


def mt_wall():
    m = mt_new(0)
    draw_rect(m, 4, 3, 11, 10, 2)
    draw_rect(m, 5, 4, 10, 9, 3)
    draw_rect(m, 7, 4, 8, 9, 2)
    draw_rect(m, 5, 6, 10, 6, 2)
    for x in range(16):
        m[15][x] = 2
    return m


def mt_door():
    m = mt_new(0)
    draw_rect(m, 4, 2, 11, 15, 2)
    draw_rect(m, 5, 3, 10, 15, 1)
    draw_rect(m, 6, 5, 9, 7, 3)
    m[10][9] = 0
    for x in range(16):
        if x < 4 or x > 11:
            m[15][x] = 2
    return m


def mt_sign():
    m = mt_cobble(3)
    draw_rect(m, 7, 9, 8, 15, 3)
    draw_rect(m, 1, 1, 14, 9, 1)
    draw_rect(m, 2, 2, 13, 8, 2)
    for x in range(3, 13):
        if x % 3 != 2:
            m[4][x] = 3
        if x % 4 != 3 and x < 10:
            m[6][x] = 3
    return m


def mt_barrier():
    m = mt_cobble(3)
    for y in range(3, 9):
        for x in range(16):
            m[y][x] = 1 if ((x + y) // 3) % 2 else 2
    for y in range(9, 15):
        for x in (2, 3, 12, 13):
            m[y][x] = 3
    draw_rect(m, 2, 0, 3, 2, 1)
    return m


def mt_bh_roof():
    m = mt_new(1)
    for y in range(16):
        for x in range(16):
            if y % 4 == 3:
                m[y][x] = 0
    return m


def mt_bh_wall():
    m = mt_new(0)
    for y in range(16):
        for x in range(16):
            if y % 4 == 3 and x % 2 == 0:
                m[y][x] = 1
    draw_rect(m, 5, 4, 10, 8, 1)
    draw_rect(m, 6, 5, 9, 7, 2)
    return m


def mt_bh_door():
    m = mt_new(0)
    draw_rect(m, 3, 1, 12, 15, 2)
    draw_rect(m, 4, 2, 11, 15, 1)
    draw_rect(m, 7, 2, 8, 15, 0)
    draw_rect(m, 5, 4, 6, 6, 3)
    draw_rect(m, 9, 4, 10, 6, 3)
    m[10][6] = m[10][9] = 3
    return m


def pyramid_img():
    m = [[0] * 32 for _ in range(32)]
    for y in range(2, 32):
        hw = (y - 2) * 15 / 29 + 1
        for x in range(32):
            dx = x + 0.5 - 16
            if abs(dx) <= hw:
                c = 1 if dx < 0 else 2
                if abs(dx) > hw - 1.2 or y == 31:
                    c = 3
                elif dx < 0 and y % 5 == 0:
                    c = 2
                m[y][x] = c
    return m


def facade_img():
    """'BALLHAUS' / 'WEST' in neon (colour 2) with purple glow (1) on the dark wall."""
    m = [[0] * 80 for _ in range(16)]
    for text, row, x0 in (("BALLHAUS", 0, 8), ("WEST", 8, 24)):
        for i, ch in enumerate(text):
            g = render(FONT[ch], 1, 1, 0, 1, 8, 8, lambda y: 2)
            for y in range(8):
                for x in range(8):
                    if g[y][x]:
                        m[row + y][x0 + i * 8 + x] = g[y][x]
    return m


METATILES = {
    ".": mt_grass(), "T": mt_tree(), ",": mt_flowers(), ":": mt_cobble(), "=": mt_road(),
    "|": mt_road(True), "-": mt_tracks(), "R": mt_roof(), "W": mt_wall(), "D": mt_door(),
    "S": mt_sign(), "E": mt_sign(), "K": mt_sign(), "X": mt_barrier(), "b": mt_bh_roof(),
    "H": mt_bh_wall(), "O": mt_bh_door(),
}
BIG = {"P": pyramid_img(), "F": facade_img()}

ow_tiles = [0, []]
ow_idx = {}
ow_map = [0] * 1024
ow_attr = [0] * 1024
ow_coll = [0] * 256
npcs = []
start = None
origin = {}
for y, row in enumerate(OW_MAP):
    assert len(row) == 16, row
    for x, ch in enumerate(row):
        if ch in BIG and ch not in origin:
            origin[ch] = (x, y)
for y, row in enumerate(OW_MAP):
    for x, ch in enumerate(row):
        ground = ch
        if ch in NPC_TYPES:
            npcs.append((x, y, NPC_TYPES[ch]))
            ground = NPC_GROUND.get(ch, ":")
        elif ch == "@":
            start = (x, y)
            ground = ":"
        if ground in BIG:
            ox, oy = origin[ground]
            src = BIG[ground]
            img = [r[(x - ox) * 16:(x - ox) * 16 + 16] for r in src[(y - oy) * 16:(y - oy) * 16 + 16]]
        else:
            img = METATILES[ground]
        for i, t in enumerate(cut(img)):
            pos = (y * 2 + i // 2) * 32 + x * 2 + i % 2
            ow_map[pos] = tileset_add(ow_tiles, ow_idx, t)
            ow_attr[pos] = 0x08 | OW_PAL[ground]
        coll = 0x80 if ground in SOLID else 0
        coll |= EVENTS.get(ground, 0)
        if ch in NPC_TYPES:
            coll = 0x80 | (16 + len(npcs) - 1)
        ow_coll[y * 16 + x] = coll
assert len(ow_tiles[1]) <= 256, len(ow_tiles[1])
assert start

with open(os.path.join(OUT, "tiles0.2bpp"), "wb") as f:
    f.write(b"".join(tile_bytes(t) for t in bank0))
for name, tiles in [("logo", scene_logo[1]), ("deck", scene_deck[1]), ("owspr", scene_ow[1]),
                    ("bigfont", bigfont), ("owtiles", ow_tiles[1])]:
    with open(os.path.join(OUT, f"{name}.2bpp"), "wb") as f:
        f.write(b"".join(tile_bytes(t) for t in tiles))

defs += [("OW_START_X", start[0]), ("OW_START_Y", start[1]), ("OW_NUM_NPCS", len(npcs)),
         ("CH_0", charmap_small["0"]), ("CH_COLON", charmap_small[":"]), ("CH_NEXT", charmap_small["<NEXT>"]), ("CH_HEART", charmap_small["<3"])]


def charmap_lines(name, cmap):
    lines = [f"NEWCHARMAP {name}"]
    for ch, v in cmap.items():
        lines.append(f'CHARMAP "{ch}", {v}')
    return lines


with open(os.path.join(OUT, "gfx_defs.inc"), "w") as f:
    f.write("; generated by tools/gen.py\n")
    for n, v in defs:
        if not n.startswith("_"):
            f.write(f"DEF {n} EQU {v}\n")
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

OW_BG = [
    [WHITE, rgb(21, 21, 24), rgb(12, 12, 16), rgb(3, 3, 10)],          # 0 text box
    [rgb(18, 27, 10), rgb(10, 21, 6), rgb(4, 13, 4), rgb(1, 5, 2)],    # 1 grass, trees
    [rgb(24, 23, 21), rgb(17, 16, 15), rgb(9, 9, 10), rgb(31, 31, 28)],  # 2 cobble, road, tracks
    [rgb(29, 26, 20), rgb(27, 9, 7), rgb(14, 5, 4), rgb(4, 6, 10)],    # 3 houses
    [rgb(24, 23, 21), rgb(24, 11, 8), rgb(16, 6, 4), rgb(7, 3, 2)],    # 4 pyramid (red sandstone)
    [rgb(5, 3, 10), rgb(14, 5, 20), rgb(31, 8, 24), WHITE],            # 5 Ballhaus West (neon)
    [rgb(24, 23, 21), rgb(29, 6, 4), WHITE, rgb(17, 16, 15)],          # 6 signs, barrier
    [rgb(18, 27, 10), rgb(29, 8, 8), rgb(31, 26, 6), rgb(10, 6, 3)],   # 7 flowers
]
SKIN = rgb(31, 24, 18)
INK = rgb(2, 2, 4)
OW_OBJ = [
    [0, INK, rgb(28, 6, 6), SKIN],                       # 0 player
    [0, rgb(15, 15, 17), rgb(18, 8, 22), SKIN],          # 1 oma
    [0, INK, rgb(4, 20, 8), SKIN],                       # 2 doener guy
    [0, INK, rgb(31, 16, 0), SKIN],                      # 3 worker
    [0, INK, rgb(7, 7, 9), SKIN],                        # 4 bouncer
    [0, rgb(8, 6, 4), rgb(24, 21, 16), WHITE],           # 5 goat
    [0, rgb(4, 4, 6), rgb(28, 5, 5), rgb(24, 28, 31)],   # 6 tram
    [0, INK, rgb(28, 6, 6), SKIN],
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
    w('SECTION "Tile sets", ROMX\n')
    for label, name in [("LogoTiles", "logo"), ("DeckTiles", "deck"), ("OwSprTiles", "owspr"),
                        ("BigFontTiles", "bigfont"), ("OwTiles", "owtiles")]:
        w(f'{label}:\n    INCBIN "{name}.2bpp"\n{label}End:\n')
    w("\nLogoMap:\n" + db(logo_map) + "\n")
    w("DeckMap:\n" + db(deck_map, 9) + "\n")
    w("OwMap:\n" + db(ow_map, 32) + "\n")
    w("OwAttr:\n" + db(ow_attr, 32) + "\n")
    w("OwNpcs:\n" + "\n".join(f"    db {x * 16}, {y * 16}, {t}" for x, y, t in npcs) + "\n\n")
    w('SECTION "OwColl", ROMX, ALIGN[8]\nOwColl:\n' + db(ow_coll) + "\n\n")
    w('SECTION "Palettes", ROMX\nDefaultPalettes:\n' + dw([c for p in BG + OBJ for c in p]) + "\n")
    w("OwPalettes:\n" + dw([c for p in OW_BG + OW_OBJ for c in p]) + "\n")
    DECK = [NAVY, rgb(18, 18, 22), rgb(2, 2, 5)]
    w("DeckPalettes:\n" + dw(DECK + [rgb(31, 10, 24)] + DECK + [rgb(8, 28, 31)]) + "\n")
    w("RainbowHi:\n" + dw(RAINBOW_HI) + "\n")
    w("RainbowLo:\n" + dw(RAINBOW_LO) + "\n")
    w("FlashTab:\n" + dw(FLASH) + "\n\n")
    w('SECTION "SineTab", ROM0, ALIGN[8]\nSineTab:\n' + db(SINE) + "\n\n")
    w('SECTION "FadeTab", ROM0, ALIGN[8]\nFadeTab:\n' + db([c for row in FADE for c in row]) + "\n\n")
    w('SECTION "Song", ROMX\n')
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

print(f"fixed bank0: {SCENE_BASE}, logo: {len(scene_logo[1])}, deck: {len(scene_deck[1])}, "
      f"ow sprites: {len(scene_ow[1])}, bigfont: {len(bigfont)}, ow tiles: {len(ow_tiles[1])}, npcs: {len(npcs)}")
