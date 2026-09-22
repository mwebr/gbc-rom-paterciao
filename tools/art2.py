"""More original art: walking sprites, trams/trains, the Ballhaus West interior,
DJ avatars and record sleeves for the crate-digging slot machine."""
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
# DJ avatars, 32x32: 0 background, 1 outline/shirt, 2 hair, 3 skin
# --------------------------------------------------------------------------
AVATARS = [
    # key, name, background, hair colour, skin
    ("sima", "SIMA", rgb(10, 24, 24), rgb(3, 3, 5), rgb(27, 20, 15)),
    ("guetta", "DAVID GUETTA", rgb(28, 16, 22), rgb(30, 25, 12), rgb(29, 22, 17)),
    ("pater", "PATER", rgb(29, 18, 8), rgb(14, 8, 3), rgb(30, 23, 18)),
    ("tiesto", "TIESTO", rgb(12, 16, 29), rgb(6, 4, 2), rgb(29, 22, 17)),
    ("joao", "JO~O", rgb(31, 27, 10), rgb(17, 10, 4), rgb(28, 19, 12)),
    ("calvin", "CALVIN HARRIS", rgb(14, 26, 12), rgb(12, 7, 3), rgb(30, 23, 18)),
]


def avatar(key):
    m = blank(32, 32)
    # shoulders / shirt
    for y in range(24, 32):
        for x in range(32):
            if abs(x + 0.5 - 16) <= 7 + (y - 24) * 1.3:
                m[y][x] = 1
    rect(m, 14, 21, 17, 25, 3)              # neck
    disc(m, 16, 14, 8, 1, 9.5)              # head outline
    disc(m, 16, 14, 7, 3, 8.5)              # face
    disc(m, 7.8, 15, 1.6, 3, 2.4)           # ears
    disc(m, 24.2, 15, 1.6, 3, 2.4)
    for ex in (12, 19):                     # eyes
        m[14][ex] = m[15][ex] = 1
    m[19][14] = m[19][15] = m[19][16] = m[19][17] = 1   # mouth

    if key == "sima":                       # short black hair + glasses
        for y in range(4, 11):
            for x in range(8, 25):
                if ((x + 0.5 - 16) / 8.6) ** 2 + ((y + 0.5 - 12) / 8) ** 2 <= 1 and y <= 10 - (1 if x in (8, 24) else 0):
                    m[y][x] = 2
        rect(m, 8, 9, 9, 13, 2)
        rect(m, 23, 9, 24, 13, 2)
        for x0 in (10, 17):                 # glasses frames
            rect(m, x0, 12, x0 + 4, 12, 1)
            rect(m, x0, 16, x0 + 4, 16, 1)
            rect(m, x0, 12, x0, 16, 1)
            rect(m, x0 + 4, 12, x0 + 4, 16, 1)
        m[13][15] = m[13][16] = 1
    elif key == "pater":                    # brown hair pulled back into a man bun
        for y in range(5, 11):
            for x in range(8, 25):
                if ((x + 0.5 - 16) / 8.4) ** 2 + ((y + 0.5 - 12) / 7.5) ** 2 <= 1:
                    m[y][x] = 2
        disc(m, 16, 3.5, 4, 1)
        disc(m, 16, 3.5, 3, 2)
        m[3][15] = 1
        for x in (11, 13, 19, 21):          # combed-back strands
            m[8][x] = 1
        for x in range(12, 21):             # short beard line
            m[21][x] = 2 if x % 2 else 1
    elif key == "joao":                     # sunny boy: tousled brown hair, big smile
        for y in range(3, 11):
            for x in range(7, 26):
                if ((x + 0.5 - 16) / 9) ** 2 + ((y + 0.5 - 11) / 8) ** 2 <= 1:
                    m[y][x] = 2
        for x in (9, 12, 15, 18, 21, 23):   # curls on the forehead
            m[10][x] = 2
            m[11][x] = 2 if x % 2 else m[11][x]
        for x in (6, 26):
            m[6][x] = 2
        for x in range(12, 20):             # wide smile
            m[19][x] = 1
        m[18][12] = m[18][19] = 1
        m[20][14] = m[20][15] = m[20][16] = m[20][17] = 1
        for (sx, sy) in ((3, 3), (28, 2), (27, 27), (4, 26)):   # sun sparkles
            m[sy][sx] = 3
            m[sy - 1][sx] = m[sy + 1][sx] = m[sy][sx - 1] = m[sy][sx + 1] = 3
    elif key == "guetta":                   # long blond hair, shades
        for y in range(4, 24):
            for x in range(6, 27):
                d = ((x + 0.5 - 16) / 10) ** 2 + ((y + 0.5 - 12) / 11) ** 2
                if d <= 1 and (y < 9 or x < 9 or x > 23):
                    m[y][x] = 2
        rect(m, 10, 13, 22, 15, 1)
    elif key == "tiesto":                   # short dark hair, headphones
        for y in range(4, 10):
            for x in range(8, 25):
                if ((x + 0.5 - 16) / 8.6) ** 2 + ((y + 0.5 - 12) / 8) ** 2 <= 1:
                    m[y][x] = 2
        for y in range(4, 18):              # headband + cups
            m[y][7] = m[y][25] = 1
        for x in range(8, 25):
            m[3][x] = 1
        rect(m, 5, 13, 8, 19, 1)
        rect(m, 24, 13, 27, 19, 1)
    elif key == "calvin":                   # cap
        rect(m, 8, 5, 24, 9, 2)
        disc(m, 16, 8, 8.5, 2, 5)
        rect(m, 8, 10, 27, 10, 1)
        for y in range(5, 11):
            for x in range(6, 27):
                if m[y][x] == 2 and (y == 5 or x in (8, 24)):
                    m[y][x] = 1
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
