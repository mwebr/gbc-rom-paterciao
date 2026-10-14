"""More original art: walking sprites, trams/trains, the Ballhaus West interior,
DJ portraits and record sleeves for the crate-digging slot machine."""
import math


def rgb(r, g, b):
    return (r & 31) | ((g & 31) << 5) | ((b & 31) << 10)


def P(rows, w=16):
    assert all(len(r) == w for r in rows), [r for r in rows if len(r) != w]
    return [[0 if c == "." else int(c) for c in r] for r in rows]


def blank(w, h, c=0):
    return [[c] * w for _ in range(h)]


def rect(img, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            img[y][x] = c


def disc(img, cx, cy, r, c, ry=None):
    ry = ry or r
    for y in range(len(img)):
        for x in range(len(img[0])):
            if ((x + 0.5 - cx) / r) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1:
                img[y][x] = c


# --------------------------------------------------------------------------
# walking player (1 outline, 2 cap/jacket, 3 skin)  -- 16x16
# --------------------------------------------------------------------------
_WD = [
    ".....111111.....", "....12222221....", "...1222222221...", "...1111111111...", "...1333333331...",
    "...1313333131...", "....13333331....", "....11222211....", "...1322222231...", "...1322222231...",
    "...1122222211...", "....11111111....",
]
WALK_D0 = P(_WD + ["....11111111....", "....111..111....", "....11....11....", "................"])
WALK_D1 = P(_WD + ["....11111111....", "....111..111....", "....111...11....", ".....1.........."])
_WU = [
    ".....111111.....", "....12222221....", "...1222222221...", "...1222222221...", "...1111111111...",
    "...1111111111...", "....11111111....", "....11222211....", "...1322222231...", "...1322222231...",
    "...1122222211...", "....11111111....",
]
WALK_U0 = P(_WU + ["....11111111....", "....111..111....", "....11....11....", "................"])
WALK_U1 = P(_WU + ["....11111111....", "....111..111....", "....11...111....", "..........1....."])
_WL = [
    "......111111....", ".....12222221...", "....1222222221..", "...11111111111..", "....133331111...",
    "....313331111...", ".....1333111....", ".....1122211....", ".....1322221....", ".....1322221....",
    ".....1122211....", ".....1111111....",
]
WALK_L0 = P(_WL + [".....1111111....", ".....11..111....", ".....11...11....", "................"])
WALK_L1 = P(_WL + [".....1111111....", "......111.11....", ".....11....11...", "................"])

# --------------------------------------------------------------------------
# Karlsruhe tram (yellow) and an ICE-style train: 1 outline, 2 body, 3 windows/light
# --------------------------------------------------------------------------


def tram_h():
    m = blank(32, 16)
    for y in range(2, 15):
        for x in range(0, 32):
            if (x < 2 and y < 4) or (x > 29 and y < 4):
                continue
            edge = y in (2, 14) or x in (0, 31)
            c = 1 if edge else 2
            if 4 <= y <= 8 and 2 <= x <= 29:
                c = 1 if x % 7 in (0, 1) or y in (4, 8) else 3
            if y == 11:
                c = 1
            m[y][x] = c
    for x in range(11, 21):
        m[0][x] = 1 if x in (11, 20) or x % 3 == 0 else 0
        m[1][x] = 1 if x in (13, 18) else 0
    for cx in (6, 25):
        for x in range(cx - 2, cx + 3):
            m[15][x] = 1
    return m


def tram_v():
    m = blank(16, 32)
    for y in range(0, 32):
        for x in range(1, 15):
            if (y < 2 or y > 29) and x in (1, 14):
                continue
            edge = x in (1, 14) or y in (0, 31)
            c = 1 if edge else 2
            if x in (2, 13) and 2 <= y <= 29 and y % 6 < 4:
                c = 3                       # side windows seen from above
            m[y][x] = c
    for y in range(11, 21):                 # pantograph
        m[y][7] = m[y][8] = 1 if y % 3 else 2
    rect(m, 4, 1, 11, 2, 3)                 # windscreens
    rect(m, 4, 29, 11, 30, 3)
    return m


def train_car(front):
    m = blank(32, 16)
    for y in range(3, 15):
        for x in range(32):
            if front and x < 6 and y < 3 + (6 - x):
                continue
            edge = y in (3, 14) or x == 31 or (front and x == 0) or (not front and x == 0)
            c = 1 if edge else 3
            if y in (10, 11):
                c = 2                       # red stripe
            if 5 <= y <= 7 and 4 <= x <= 29 and x % 5 != 0:
                c = 1
            m[y][x] = c
    if front:
        for y in range(3, 9):
            x = 6 - (y - 3)
            if 0 <= x < 32:
                m[y][x] = 1
        rect(m, 2, 6, 5, 8, 1)
    for cx in (7, 24):
        for x in range(cx - 2, cx + 3):
            m[15][x] = 1
    return m


# --------------------------------------------------------------------------
# Ballhaus West interior (10 x 9 blocks = one screen)
# --------------------------------------------------------------------------
CLUB_TEXT, CLUB_WALL, CLUB_WOOD, CLUB_DANCE, CLUB_BAR, CLUB_DECKS, CLUB_SPEAKER, CLUB_NEON = range(8)
CLUB_BG = [
    [rgb(31, 31, 31), rgb(26, 26, 28), rgb(12, 12, 16), rgb(3, 3, 8)],
    [rgb(7, 3, 13), rgb(12, 5, 19), rgb(31, 8, 24), rgb(1, 0, 3)],       # walls
    [rgb(22, 13, 7), rgb(16, 9, 5), rgb(9, 5, 3), rgb(2, 1, 1)],         # wooden floor
    [rgb(31, 8, 24), rgb(8, 28, 31), rgb(31, 28, 6), rgb(14, 6, 31)],    # dance floor (cycled)
    [rgb(24, 14, 8), rgb(12, 6, 3), rgb(6, 22, 10), rgb(30, 28, 22)],    # bar
    [rgb(22, 22, 26), rgb(3, 3, 5), rgb(31, 4, 4), rgb(31, 31, 31)],     # decks
    [rgb(9, 9, 11), rgb(2, 2, 3), rgb(17, 17, 20), rgb(28, 28, 30)],     # speakers
    [rgb(12, 5, 19), rgb(31, 8, 24), rgb(8, 28, 31), rgb(31, 31, 31)],   # ENKA poster
]
CLUB_MAP = [
    "WWWWPQWWWW",
    "WSVTMNTVSW",
    "WZ.BBBB.ZW",
    "W.cdcdcd.R",
    "W.dcdcdc.R",
    "W.cdcdcd.R",
    "W........R",
    "W........W",
    "WWWWeeWWWW",
]
CLUB_START = (4, 7)


def club_metatiles(font_glyph):
    mts = {}

    def wall():
        m = blank(16, 16)
        for y in range(16):
            for x in range(16):
                if x % 8 == 7:
                    m[y][x] = 1
        for x in range(16):
            m[11][x] = m[12][x] = 2        # neon strip
            m[15][x] = 3
        return m

    mts["W"] = (wall(), CLUB_WALL, True)
    mts["V"] = (wall(), CLUB_WALL, True)
    edge = blank(16, 16, 3)
    rect(edge, 0, 0, 15, 1, 1)
    mts["X"] = (edge, CLUB_WALL, True)

    def poster(text):
        m = blank(16, 16)
        rect(m, 0, 1, 15, 14, 1)
        rect(m, 1, 2, 14, 13, 0)
        for i, ch in enumerate(text):
            g = font_glyph(ch)
            for y in range(8):
                for x in range(8):
                    if g[y][x] == 3:
                        m[4 + y][i * 8 + x] = 3
                    elif g[y][x] == 1:
                        m[4 + y][i * 8 + x] = 2
        return m

    mts["P"] = (poster("EN"), CLUB_NEON, True)
    mts["Q"] = (poster("KA"), CLUB_NEON, True)

    def speaker(top):
        m = blank(16, 16, 1)
        rect(m, 1, 0 if not top else 1, 14, 15 if top else 14, 0)
        disc(m, 8, 9 if top else 7, 5.5, 1)
        disc(m, 8, 9 if top else 7, 4, 2)
        disc(m, 8, 9 if top else 7, 1.5, 3)
        return m

    mts["S"] = (speaker(True), CLUB_SPEAKER, True)
    mts["Z"] = (speaker(False), CLUB_SPEAKER, True)

    def turntable():
        m = blank(16, 16)
        rect(m, 0, 1, 15, 15, 0)
        rect(m, 0, 1, 15, 1, 1)
        disc(m, 7, 8, 6.5, 1)
        disc(m, 7, 8, 2, 2)
        m[8][7] = 3
        for y in range(3, 10):
            m[y][13] = 1
        m[10][12] = m[11][12] = 3
        return m

    def mixer(left):
        m = blank(16, 16, 1)
        rect(m, 0, 1, 15, 15, 1)
        for kx in ((3, 7, 11) if left else (4, 8, 12)):
            for ky in (4, 7):
                m[ky][kx] = 3
            m[10][kx] = 2
        for x in range(2, 14):
            m[13][x] = 0
        rect(m, (9 if left else 4), 12, (10 if left else 5), 14, 3)
        return m

    mts["T"] = (turntable(), CLUB_DECKS, True)
    mts["M"] = (mixer(True), CLUB_DECKS, True)
    mts["N"] = (mixer(False), CLUB_DECKS, True)

    def booth():
        m = blank(16, 16, 1)
        rect(m, 0, 0, 15, 2, 0)
        for x in range(16):
            m[8][x] = 2 if x % 4 < 2 else 1
        rect(m, 0, 15, 15, 15, 1)
        return m

    mts["B"] = (booth(), CLUB_DECKS, True)

    def wood():
        m = blank(16, 16)
        for y in range(16):
            for x in range(16):
                if y % 4 == 3:
                    m[y][x] = 1
                elif x == (5 if (y // 4) % 2 else 12) and y % 4 != 3:
                    m[y][x] = 1
        m[6][3] = m[13][9] = 2
        return m

    mts["."] = (wood(), CLUB_WOOD, False)

    def dance(flip):
        m = blank(16, 16)
        cols = (0, 1, 2, 3) if not flip else (2, 3, 0, 1)
        for q, c in enumerate(cols):
            qx, qy = (q % 2) * 8, (q // 2) * 8
            rect(m, qx, qy, qx + 7, qy + 7, c)
        return m

    mts["c"] = (dance(False), CLUB_DANCE, False)
    mts["d"] = (dance(True), CLUB_DANCE, False)

    def bar():
        m = blank(16, 16)
        rect(m, 0, 0, 5, 15, 1)
        rect(m, 1, 0, 4, 15, 0)
        for y in (2, 9):
            rect(m, 9, y, 10, y + 4, 2)
            m[y][9] = 3
            rect(m, 12, y + 2, 13, y + 4, 3)
        for y in range(16):
            m[y][15] = 1
        return m

    mts["R"] = (bar(), CLUB_BAR, True)

    def mat():
        m = blank(16, 16, 2)
        for y in range(16):
            for x in range(16):
                if (x + y) % 4 == 0:
                    m[y][x] = 3
        return m

    mts["e"] = (mat(), CLUB_WALL, False)
    return mts


# --------------------------------------------------------------------------
# DJ portraits, 64x64, fighting-game select style, lit from the right.
# Colours: 0 background (doubles as the face shadow), 1 outline/shirt, 2 hair or accent, 3 skin,
# 4 second hair colour (only below tile row 3, drawn with the portrait's second palette)
# --------------------------------------------------------------------------
PORTRAITS = [
    # key, name, background, hair/accent, skin, second hair colour (or None)
    ("sima", "SIMA", rgb(4, 13, 14), rgb(7, 7, 12), rgb(27, 20, 15), None),
    ("guetta", "DAVID GUETTA", rgb(16, 4, 11), rgb(30, 25, 12), rgb(29, 22, 17), None),
    ("pater", "PATER", rgb(17, 7, 3), rgb(20, 12, 5), rgb(30, 23, 18), None),
    ("tiesto", "TIESTO", rgb(5, 7, 19), rgb(10, 8, 6), rgb(29, 22, 17), None),
    ("joao", "JO~O", rgb(14, 10, 2), rgb(18, 10, 4), rgb(28, 19, 12), None),
    ("sypoda", "DA:SYPODA", rgb(10, 4, 17), rgb(29, 11, 11), rgb(30, 23, 18), rgb(19, 7, 3)),
]
PORTRAIT_SPLIT = 3          # tile rows above use palette A, rows below palette B
CX, CY = 32.5, 30.0


def head(x, y, g=0.0):
    dy = y + 0.5 - CY
    rx = 13.5 + g - max(0.0, dy - 3) * 0.42
    ry = 17.0 + g
    return rx > 0 and ((x + 0.5 - CX) / rx) ** 2 + (dy / ry) ** 2 <= 1


def ell(m, cx, cy, rx, ry, c, only=None):
    for y in range(64):
        for x in range(64):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1:
                if only is None or m[y][x] in only:
                    m[y][x] = c


def line(m, x0, y0, x1, y1, c, w=1):
    n = max(abs(x1 - x0), abs(y1 - y0)) * 2 + 1
    for i in range(n + 1):
        t = i / n
        x, y = round(x0 + (x1 - x0) * t), round(y0 + (y1 - y0) * t)
        for k in range(w):
            if 0 <= y + k < 64:
                m[y + k][x] = c


def base(m, eyes=True, mouth=True):
    for y in range(48, 64):                         # shoulders
        for x in range(64):
            if abs(x + 0.5 - CX) <= 15 + (y - 48) * 1.9:
                m[y][x] = 1
    for y in range(38, 54):                         # neck + neckline
        for x in range(25, 41):
            m[y][x] = 3
    for y in range(52, 58):
        for x in range(64):
            if abs(x + 0.5 - CX) <= 8 - (y - 52) * 1.4:
                m[y][x] = 3
    for y in range(38, 58):
        for x in range(64):
            if m[y][x] == 3 and (x < 30 or y < 43):
                m[y][x] = 0
    for y in range(64):                             # head + outline
        for x in range(64):
            if head(x, y):
                m[y][x] = 3
            elif head(x, y, 1.3):
                m[y][x] = 1
    for y in range(64):                             # shadow side, light from the right
        for x in range(64):
            if m[y][x] == 3 and x + 0.5 < CX - 9.5 + max(0, y - 36) * 0.9:
                m[y][x] = 0
    ell(m, 47.3, 31, 2.6, 5, 1)                     # ear
    ell(m, 47.3, 31, 1.6, 4, 3)
    m[30][47] = m[31][47] = m[32][46] = 0
    # brows
    line(m, 20, 22, 29, 25, 1, 2)
    line(m, 36, 25, 45, 22, 1, 2)
    if eyes:
        for ex in (25, 40):
            line(m, ex - 4, 28, ex + 4, 28, 1)      # upper lid
            rect(m, ex - 1, 28, ex + 1, 30, 1)      # pupil
            line(m, ex - 3, 31, ex + 3, 31, 0)      # lower lid
        m[29][24] = 3                               # catch lights (skin tone)
        m[29][39] = 3
    # nose: shadow on the left of the bridge, tip
    for y in range(31, 37):
        m[y][31] = 0
    line(m, 31, 37, 34, 38, 1)
    m[37][35] = 1
    line(m, 31, 39, 34, 39, 0)
    if mouth:
        line(m, 28, 44, 38, 44, 1)
        m[43][39] = 1
        line(m, 30, 46, 35, 46, 0)


def portrait(key):
    m = blank(64, 64)
    base(m, eyes=key not in ("guetta", "sypoda"), mouth=key != "joao")
    if key == "sypoda":                             # brows hidden by the fringe
        for y in range(21, 28):
            for x in range(18, 48):
                if m[y][x] == 1 and head(x, y):
                    m[y][x] = 3
    if key == "sima":
        for y in range(64):                         # short hair, side part
            for x in range(64):
                if head(x, y, 3.2) and (y < 19 - (x - 20) * 0.08 or (y < 32 and (x < 20 or x > 46))):
                    m[y][x] = 2
        line(m, 24, 9, 36, 16, 1)                   # part / strands
        line(m, 30, 8, 44, 15, 1)
        for x0 in (18, 35):                         # glasses
            rect(m, x0, 24, x0 + 12, 25, 1)
            rect(m, x0, 32, x0 + 12, 33, 1)
            rect(m, x0, 24, x0 + 1, 33, 1)
            rect(m, x0 + 11, 24, x0 + 12, 33, 1)
        rect(m, 30, 26, 35, 27, 1)
        line(m, 47, 26, 49, 26, 1)
        line(m, 43, 26, 45, 26, 3)
    elif key == "guetta":
        for y in range(64):                         # long blond hair
            for x in range(64):
                inside = head(x, y, 4.5) or (y >= 30 and y < 52 and abs(x + 0.5 - CX) < 20 - (y - 30) * 0.05)
                if inside and not head(x, y, 0.5) or (head(x, y, 2) and y < 20):
                    if y < 20 or x < 19 or x > 46:
                        m[y][x] = 2
        for x in range(22, 44, 4):                  # strands
            line(m, x, 8, x - 3, 19, 1)
        for x0 in (19, 34):                         # shades
            for y in range(24, 33):
                for x in range(x0, x0 + 12):
                    if not (y > 30 and (x == x0 or x == x0 + 11)):
                        m[y][x] = 1
            line(m, x0 + 3, 26, x0 + 6, 25, 2)       # shine
        rect(m, 30, 26, 34, 27, 1)
        line(m, 28, 44, 37, 44, 1)
        line(m, 37, 44, 39, 42, 1)
    elif key == "pater":
        for y in range(64):                         # hair combed back
            for x in range(64):
                if head(x, y, 2.6) and y < 21:
                    m[y][x] = 2
        for x in (22, 27, 33, 38, 43):
            line(m, x, 18, x + 2, 8, 1)
        ell(m, 34, 6, 6.5, 5, 1)                    # bun
        ell(m, 34, 6, 5.2, 3.8, 2)
        line(m, 30, 6, 38, 6, 1)
        for y in range(36, 52):                     # beard
            for x in range(64):
                if head(x, y, 1.0) and m[y][x] in (0, 3) and (y > 41 or x < 22 or x > 43):
                    m[y][x] = 2
        line(m, 27, 41, 39, 41, 2, 2)               # moustache
        line(m, 29, 44, 37, 44, 1)
        for y in range(43, 51, 2):
            for x in range(20 + (y % 4), 46, 4):
                if m[y][x] == 2:
                    m[y][x] = 0
    elif key == "tiesto":
        for y in range(64):                         # short crop
            for x in range(64):
                if head(x, y, 2.4) and (y < 18 or (y < 27 and (x < 20 or x > 45))):
                    m[y][x] = 2
        for x in range(21, 46, 3):
            m[17][x] = 1
        line(m, 18, 49, 46, 49, 2, 2)               # headphones round the neck
        for cx in (16, 49):
            ell(m, cx, 51, 5, 6, 1)
            ell(m, cx, 51, 3.8, 4.8, 2)
            ell(m, cx, 51, 1.8, 2.6, 1)
    elif key == "joao":                     # short, tousled
        for y in range(64):
            for x in range(64):
                fringe = 20 + (2 if (x // 4) % 2 else 0) - (2 if x > 38 else 0)
                if head(x, y, 4.6) and (y < fringe or (y < 27 and (x < 20 or x > 45))):
                    m[y][x] = 2
        for tx, ty in ((21, 10), (27, 8), (34, 7), (41, 9), (46, 13)):  # tufts on top
            for k in range(5):
                for x in range(tx - 3 + k * 3 // 5, tx + 2 - k // 3):
                    if m[ty - k][x] == 0:
                        m[ty - k][x] = 2
        for y in range(64):                         # outline the hair
            for x in range(64):
                if m[y][x] == 2 and y < 26 and any(0 <= y + dy < 64 and m[y + dy][x + dx] == 0
                                                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    m[y][x] = 1
        for x0, y0 in ((24, 12), (30, 9), (37, 11), (42, 14), (21, 16)):     # strands
            line(m, x0, y0, x0 - 2, y0 + 4, 1)
        line(m, 27, 42, 39, 42, 1)                  # laughing mouth
        rect(m, 29, 43, 37, 45, 0)
        line(m, 28, 43, 28, 43, 1)
        line(m, 38, 43, 38, 43, 1)
        line(m, 30, 46, 36, 46, 1)
        m[41][26] = m[41][40] = 1
    elif key == "sypoda":
        # colour 4 = red-brown hair: second palette, only in tile rows 3+ (the cap stays above y 24)
        for y in range(24, 62):                     # ponytail behind the left shoulder
            for x in range(64):
                cx = 17 - (y - 24) * 0.12 + math.sin((y - 24) / 6) * 1.5
                wdt = 3.6 - max(0, y - 46) * 0.2
                if abs(x + 0.5 - cx) <= wdt and not head(x, y, 1.3) and (m[y][x] == 0 or y >= 47):
                    m[y][x] = 1 if abs(x + 0.5 - cx) > wdt - 1 else 4
        for y in range(36, 60, 4):
            line(m, 15, y, 18, y + 2, 1)
        for y in range(64):                         # cap crown
            for x in range(64):
                d = ((x + 0.5 - CX) / 16.5) ** 2 + ((y + 0.5 - 20) / 17) ** 2
                if y < 19 and d <= 1:
                    m[y][x] = 2 if ((x + 0.5 - CX) / 15.3) ** 2 + ((y + 0.5 - 20) / 15.8) ** 2 <= 1 else 1
        for y in range(18, 24):                     # brim, tilted towards us
            w = 21 - abs(y - 20.5) * 1.5
            for x in range(64):
                if abs(x + 0.5 - CX) <= w:
                    m[y][x] = 1 if (y in (18, 23) or abs(x + 0.5 - CX) > w - 1) else 2
        def digit5(x0, y0):
            rect(m, x0, y0, x0 + 4, y0 + 1, 3)
            rect(m, x0, y0, x0 + 1, y0 + 4, 3)
            rect(m, x0, y0 + 4, x0 + 4, y0 + 5, 3)
            rect(m, x0 + 3, y0 + 5, x0 + 4, y0 + 7, 3)
            rect(m, x0, y0 + 7, x0 + 4, y0 + 8, 3)
        digit5(26, 7)
        digit5(34, 7)
        for y in range(24, 29):                     # red-brown fringe under the brim
            for x in range(18, 48):
                edge = 27 + ((x // 3) % 2)
                if y <= edge and head(x, y, 1.0):
                    m[y][x] = 4
            for x in range(18, 48):
                if head(x, y, 1.0) and m[y][x] != 4 and y <= 29 and m[y - 1][x] == 4:
                    m[y][x] = 1
        for y in range(24, 37):                     # side strands in front of the ears
            for x in (18, 19, 20, 45, 46):
                if head(x, y, 1.3):
                    m[y][x] = 4 if x in (19, 46) or y < 34 else 1
        for ex in (25, 40):                         # eyes looking down
            line(m, ex - 4, 30, ex - 1, 32, 1)
            line(m, ex - 1, 32, ex + 2, 32, 1)
            line(m, ex + 2, 32, ex + 4, 31, 1)
            m[33][ex - 2] = m[33][ex] = m[33][ex + 2] = 1
        line(m, 29, 44, 37, 44, 1)                  # smile
        m[43][28] = m[43][38] = 1
        ell(m, 48, 39.5, 2.2, 2.6, 1)               # hoop
        ell(m, 48, 39.5, 1.2, 1.6, 0)
    return m



# --------------------------------------------------------------------------
# record sleeves for the slot machine, 32x32: palette per sleeve
# --------------------------------------------------------------------------
SLEEVES = [
    # key, label (<= 6), palette
    ("house", "HOUSE", [rgb(31, 24, 6), rgb(3, 2, 2), rgb(24, 12, 2), rgb(31, 31, 24)]),
    ("disco", "DISCO", [rgb(14, 5, 22), rgb(3, 1, 6), rgb(18, 18, 22), rgb(31, 31, 31)]),
    ("techno", "TECHNO", [rgb(2, 3, 6), rgb(4, 10, 16), rgb(6, 28, 31), rgb(31, 31, 31)]),
    ("soul", "SOUL", [rgb(30, 27, 20), rgb(8, 2, 2), rgb(28, 4, 6), rgb(31, 31, 31)]),
    ("acid", "ACID", [rgb(2, 2, 2), rgb(1, 1, 1), rgb(31, 28, 2), rgb(31, 31, 31)]),
    ("italo", "ITALO", [rgb(31, 14, 20), rgb(4, 2, 6), rgb(31, 24, 4), rgb(31, 31, 31)]),
]
JACKPOT = 0


def sleeve(key):
    m = blank(32, 32)
    for i in range(32):                      # sleeve edge
        m[0][i] = m[31][i] = m[i][0] = m[i][31] = 1
    if key == "house":                       # record sliding out of a golden sleeve
        disc(m, 20, 16, 11, 1)
        for r in (9, 7):
            for y in range(32):
                for x in range(32):
                    if abs(math.hypot(x + 0.5 - 20, y + 0.5 - 16) - r) < 0.5:
                        m[y][x] = 2
        disc(m, 20, 16, 4, 2)
        disc(m, 20, 16, 1, 3)
        rect(m, 1, 1, 8, 30, 0)
        for y in range(1, 31):
            m[y][8] = 1
        for (x, y) in ((4, 5), (3, 12), (5, 20), (4, 26)):
            m[y][x] = 3
    elif key == "disco":                     # mirror ball
        for y in range(1, 6):
            m[y][16] = 3
        disc(m, 16, 17, 10, 2)
        for y in range(32):
            for x in range(32):
                if m[y][x] == 2 and (x % 4 == 0 or y % 4 == 0):
                    m[y][x] = 1
        for (x, y) in ((12, 12), (13, 13), (19, 20), (22, 11)):
            m[y][x] = 3
    elif key == "techno":                    # grid horizon
        for y in range(16, 31):
            for x in range(1, 31):
                if (y - 16) in (0, 2, 5, 9, 14) or ((x - 16) * 16) % max(1, (y - 14)) == 0 and y > 17:
                    m[y][x] = 2
        disc(m, 16, 12, 6, 1)
        disc(m, 16, 12, 5, 3)
        rect(m, 1, 15, 30, 15, 2)
    elif key == "soul":                      # heart
        for y in range(32):
            for x in range(32):
                u, v = (x + 0.5 - 16) / 10, (16 - (y + 0.5)) / 10 + 0.2
                if (u * u + v * v - 0.6) ** 3 - u * u * v ** 3 <= 0:
                    m[y][x] = 2
        m[10][11] = m[11][11] = m[10][12] = 3
    elif key == "acid":                      # smiley
        disc(m, 16, 16, 12, 2)
        for ex in (12, 20):
            rect(m, ex - 1, 10, ex, 14, 1)
        for x in range(9, 24):
            y = 19 + int(((x - 16) / 7.5) ** 2 * -3 + 3)
            m[y][x] = 1
            m[y + 1][x] = 1
    elif key == "italo":                     # sunset + palm
        disc(m, 16, 20, 9, 2)
        rect(m, 1, 20, 30, 30, 1)
        for y in range(21, 30, 2):
            for x in range(1, 31):
                if (x + y) % 5 == 0:
                    m[y][x] = 2
        for y in range(8, 22):               # palm trunk
            m[y][23 - (y - 8) // 5] = 1
        for dx in range(-6, 7):              # fronds
            m[8 + abs(dx) // 2][23 + dx] = 1
    return m
