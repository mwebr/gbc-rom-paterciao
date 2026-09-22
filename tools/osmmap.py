"""Rasterise the OpenStreetMap extract (Karlsruhe Hbf -> Europaplatz) into a grid of
16x16 metatile cells, one cell = CELL_M metres.

Result: grid of cell kinds + building ids + street-name zones + start / goal cells.
Map data (c) OpenStreetMap contributors, ODbL.
"""
import json
import math
import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "osm", "karlsruhe_hbf_europaplatz.json")

# crop (north-west corner and size) and scale
LAT0, LON0 = 49.0112, 8.3895
LAT1, LON1 = 48.9918, 8.4052
CELL_M = 20
SUB = 10                              # raster pixels per cell (2 m per pixel)
M_PER_LAT = 111210.0
M_PER_LON = 111320.0 * math.cos(math.radians(49.0))

W = int((LON1 - LON0) * M_PER_LON / CELL_M)
H = int((LAT0 - LAT1) * M_PER_LAT / CELL_M)

HBF = (48.99311, 8.40221)
HBF_FRONT = (48.99440, 8.40221)       # Bahnhofplatz, in front of the main entrance
BALLHAUS = (49.00937, 8.39152)        # Hirschstrasse 18

# cell kinds
GRASS, TREE, PAVE, PLAZA, ROAD, TRAM, RAILS, WATER, BUILDING = range(9)

ROAD_W = {"motorway": 20, "trunk": 20, "primary": 18, "secondary": 15, "tertiary": 12,
          "residential": 10, "unclassified": 10, "living_street": 8, "service": 6}
PATH_W = {"footway": 4, "path": 4, "cycleway": 4, "steps": 4, "track": 4}
GREEN_LANDUSE = {"grass", "forest", "meadow", "recreation_ground", "village_green", "cemetery", "allotments"}
GREEN_LEISURE = {"park", "garden", "playground", "pitch", "dog_park"}
GREEN_NATURAL = {"wood", "scrub", "grassland", "heath"}


def to_px(lat, lon):
    return ((lon - LON0) * M_PER_LON / CELL_M * SUB, (LAT0 - lat) * M_PER_LAT / CELL_M * SUB)


def to_cell(lat, lon):
    x, y = to_px(lat, lon)
    return int(x // SUB), int(y // SUB)


def ascii_name(n):
    rep = {"ß": "SS", "ä": "AE", "ö": "OE", "ü": "UE", "Ä": "AE", "Ö": "OE", "Ü": "UE", "é": "E"}
    s = "".join(rep.get(c, c) for c in n).upper()
    s = s.replace("STRASSE", "STR.") if len(s) > 18 else s
    return "".join(c for c in s if c.isalnum() or c in " .-")[:18]


def build():
    data = json.load(open(SRC))["layers"]
    size = (W * SUB, H * SUB)
    lay = {k: Image.new("L", size, 0) for k in ("green", "water", "road", "ped", "path", "rail", "tram")}
    draw = {k: ImageDraw.Draw(v) for k, v in lay.items()}
    bld = Image.new("I", size, 0)
    dbld = ImageDraw.Draw(bld)
    names = Image.new("I", size, 0)
    dnames = ImageDraw.Draw(names)
    name_list = [""]
    name_idx = {}

    def pts(g):
        return [to_px(la, lo) for la, lo in g]

    def poly(g):
        return len(g) >= 3 and g[0] == g[-1]

    for part in ("landuse", "leisure", "natural", "water"):
        for e in data.get(part, []):
            t, g = e["tags"], e["g"]
            if not poly(g):
                continue
            if (t.get("landuse") in GREEN_LANDUSE or t.get("leisure") in GREEN_LEISURE
                    or t.get("natural") in GREEN_NATURAL):
                draw["green"].polygon(pts(g), fill=255)
            if t.get("natural") == "water" or "water" in t or t.get("landuse") == "basin":
                draw["water"].polygon(pts(g), fill=255)
            if t.get("landuse") == "railway":
                draw["rail"].polygon(pts(g), fill=128)

    for e in data.get("railway", []):
        t, g = e["tags"], e["g"]
        if t.get("tunnel") == "yes" or t.get("layer", "0").startswith("-"):
            continue
        w = 5 * SUB / CELL_M * 2
        if t.get("railway") == "rail":
            draw["rail"].line(pts(g), fill=255, width=int(w))
        elif t.get("railway") == "tram":
            draw["tram"].line(pts(g), fill=255, width=int(w))

    for e in data.get("highway", []):
        t, g = e["tags"], e["g"]
        hw = t["highway"]
        if t.get("tunnel") == "yes" or t.get("covered") == "yes":
            continue
        if hw == "pedestrian" and poly(g) and t.get("area") == "yes":
            draw["ped"].polygon(pts(g), fill=255)
            continue
        if hw in ROAD_W or hw == "pedestrian":
            w = (ROAD_W.get(hw, 12)) * SUB / CELL_M
            (draw["ped"] if hw == "pedestrian" else draw["road"]).line(pts(g), fill=255, width=max(1, int(w)))
            if t.get("name"):
                n = ascii_name(t["name"])
                if n not in name_idx:
                    name_idx[n] = len(name_list)
                    name_list.append(n)
                dnames.line(pts(g), fill=name_idx[n], width=max(1, int(w * 1.6)))
        elif hw in PATH_W:
            draw["path"].line(pts(g), fill=255, width=max(1, int(PATH_W[hw] * SUB / CELL_M)))

    buildings = {}
    for e in data.get("building", []):
        g = e["g"]
        if not poly(g) or e["tags"].get("building") in ("roof", "carport"):
            continue
        bid = len(buildings) + 1
        buildings[bid] = e
        dbld.polygon(pts(g), fill=bid)

    # multipolygon relations (Hauptbahnhof, lakes, squares ...)
    for e in data.get("relations", []):
        t = e["tags"]
        if "building" in t:
            bid = len(buildings) + 1
            buildings[bid] = e
            for ring in e["outer"]:
                dbld.polygon(pts(ring), fill=bid)
            for ring in e["inner"]:
                dbld.polygon(pts(ring), fill=0)
            continue
        layer = None
        if t.get("natural") == "water" or "water" in t:
            layer = "water"
        elif (t.get("landuse") in GREEN_LANDUSE or t.get("leisure") in GREEN_LEISURE
              or t.get("natural") in GREEN_NATURAL):
            layer = "green"
        elif t.get("highway") == "pedestrian":
            layer = "ped"
        if layer:
            for ring in e["outer"]:
                draw[layer].polygon(pts(ring), fill=255)
            for ring in e["inner"]:
                draw[layer].polygon(pts(ring), fill=0)

    def frac(img, cx, cy, thr=128):
        box = img.crop((cx * SUB, cy * SUB, cx * SUB + SUB, cy * SUB + SUB))
        return sum(1 for v in box.getdata() if v >= thr) / (SUB * SUB)

    def majority(img, cx, cy):
        box = img.crop((cx * SUB, cy * SUB, cx * SUB + SUB, cy * SUB + SUB))
        cnt = {}
        for v in box.getdata():
            if v:
                cnt[v] = cnt.get(v, 0) + 1
        if not cnt:
            return 0, 0
        v, n = max(cnt.items(), key=lambda kv: kv[1])
        return v, n / (SUB * SUB)

    kind = [[PAVE] * W for _ in range(H)]
    bid_grid = [[0] * W for _ in range(H)]
    name_grid = [[0] * W for _ in range(H)]
    tram_dir = [[0] * W for _ in range(H)]
    for cy in range(H):
        for cx in range(W):
            b, bf = majority(bld, cx, cy)
            road = frac(lay["road"], cx, cy)
            ped = frac(lay["ped"], cx, cy)
            tram = frac(lay["tram"], cx, cy)
            if bf >= 0.35:
                k = BUILDING
                bid_grid[cy][cx] = b
            elif road + tram * 0.5 >= 0.35:
                k = TRAM if tram >= 0.2 else ROAD
            elif ped >= 0.35:
                k = PLAZA
            elif frac(lay["water"], cx, cy) >= 0.5:
                k = WATER
            elif frac(lay["rail"], cx, cy, 100) >= 0.3:
                k = RAILS
            elif frac(lay["path"], cx, cy) >= 0.2:
                k = PAVE
            elif frac(lay["green"], cx, cy) >= 0.4:
                k = GRASS
            else:
                k = PAVE
            kind[cy][cx] = k
            if k in (ROAD, TRAM, PLAZA):
                name_grid[cy][cx] = majority(names, cx, cy)[0]

    def neighbours(x, y, diag=False):
        d = ((1, 0), (-1, 0), (0, 1), (0, -1))
        if diag:
            d += ((1, 1), (-1, 1), (1, -1), (-1, -1))
        return [(x + dx, y + dy) for dx, dy in d if 0 <= x + dx < W and 0 <= y + dy < H]

    # block interiors: paved cells mostly surrounded by buildings become building too
    for _ in range(2):
        changes = []
        for cy in range(H):
            for cx in range(W):
                if kind[cy][cx] != PAVE:
                    continue
                nb = neighbours(cx, cy, True)
                blds = [bid_grid[y][x] for x, y in nb if kind[y][x] == BUILDING]
                near_street = any(kind[y][x] in (ROAD, TRAM, PLAZA) for x, y in neighbours(cx, cy))
                if len(blds) >= 5 and not near_street:
                    changes.append((cx, cy, max(set(blds), key=blds.count)))
        for cx, cy, b in changes:
            kind[cy][cx] = BUILDING
            bid_grid[cy][cx] = b

    # every street keeps a continuous, 4-connected centre line so the network stays rideable
    def trace(g):
        cells = []
        for (la0, lo0), (la1, lo1) in zip(g, g[1:]):
            x0, y0 = to_px(la0, lo0)
            x1, y1 = to_px(la1, lo1)
            x0, y0, x1, y1 = x0 / SUB, y0 / SUB, x1 / SUB, y1 / SUB
            n = int(max(abs(x1 - x0), abs(y1 - y0)) * 4) + 1
            prev = None
            for i in range(n + 1):
                cx = int(x0 + (x1 - x0) * i / n)
                cy = int(y0 + (y1 - y0) * i / n)
                if prev and cx != prev[0] and cy != prev[1]:
                    cells.append((cx, prev[1]))      # no diagonal steps
                cells.append((cx, cy))
                prev = (cx, cy)
        return cells

    tram_cells = set()
    for e in data.get("railway", []):
        if e["tags"].get("railway") == "tram" and e["tags"].get("tunnel") != "yes":
            tram_cells.update(trace(e["g"]))
    for e in data.get("highway", []):
        t = e["tags"]
        hw = t["highway"]
        if t.get("tunnel") == "yes" or t.get("covered") == "yes" or (hw == "service" and not t.get("name")):
            continue
        if hw not in ROAD_W and hw != "pedestrian":
            continue
        nid = name_idx.get(ascii_name(t["name"])) if t.get("name") else 0
        for cx, cy in trace(e["g"]):
            if 0 <= cx < W and 0 <= cy < H and kind[cy][cx] != WATER:
                if hw == "pedestrian":
                    kind[cy][cx] = PLAZA
                else:
                    kind[cy][cx] = TRAM if (cx, cy) in tram_cells else ROAD
                bid_grid[cy][cx] = 0
                if nid:
                    name_grid[cy][cx] = nid

    # tidy up: lone paved cells inside blocks -> building, lone building cells -> pavement
    for _ in range(2):
        for cy in range(H):
            for cx in range(W):
                nb = neighbours(cx, cy)
                nbld = [bid_grid[y][x] for x, y in nb if kind[y][x] == BUILDING]
                if kind[cy][cx] == PAVE and len(nbld) >= 3:
                    kind[cy][cx] = BUILDING
                    bid_grid[cy][cx] = nbld[0]
                elif kind[cy][cx] == BUILDING and len(nbld) == 0:
                    kind[cy][cx] = PAVE
                    bid_grid[cy][cx] = 0

    # parks get trees, keeping a clear lane next to paths and streets
    for cy in range(H):
        for cx in range(W):
            if kind[cy][cx] != GRASS:
                continue
            open_nb = any(kind[y][x] in (PAVE, PLAZA, ROAD, TRAM) for x, y in neighbours(cx, cy, True))
            if not open_nb and (cx * 3 + cy * 5) % 7 < 5:
                kind[cy][cx] = TREE

    # tram orientation per cell from the tram lines
    for e in data.get("railway", []):
        if e["tags"].get("railway") != "tram" or e["tags"].get("tunnel") == "yes":
            continue
        g = e["g"]
        for (la0, lo0), (la1, lo1) in zip(g, g[1:]):
            x0, y0 = to_px(la0, lo0)
            x1, y1 = to_px(la1, lo1)
            horiz = abs(x1 - x0) > abs(y1 - y0)
            n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
            for i in range(n + 1):
                px = x0 + (x1 - x0) * i / n
                py = y0 + (y1 - y0) * i / n
                cx, cy = int(px // SUB), int(py // SUB)
                if 0 <= cx < W and 0 <= cy < H:
                    tram_dir[cy][cx] = 1 if horiz else 2

    # special buildings
    def building_at(lat, lon):
        x, y = to_px(lat, lon)
        v = bld.getpixel((int(x), int(y)))
        if v:
            return v
        best, bd = 0, 1e9
        for dy in range(-30, 31, 2):
            for dx in range(-30, 31, 2):
                xx, yy = int(x + dx), int(y + dy)
                if 0 <= xx < size[0] and 0 <= yy < size[1]:
                    v = bld.getpixel((xx, yy))
                    if v and dx * dx + dy * dy < bd:
                        best, bd = v, dx * dx + dy * dy
        return best

    hbf_id = next((b for b, e in buildings.items() if e["tags"].get("name") == "Karlsruhe Hauptbahnhof"),
                  building_at(*HBF))
    ballhaus_id = building_at(*BALLHAUS)

    # start: nearest walkable cell to the Bahnhofplatz point
    def nearest(cell, ok):
        sx, sy = cell
        best, bd = None, 1e9
        for cy in range(H):
            for cx in range(W):
                if ok(cx, cy):
                    d = (cx - sx) ** 2 + (cy - sy) ** 2
                    if d < bd:
                        best, bd = (cx, cy), d
        return best

    walk = {PAVE, PLAZA, ROAD, TRAM, GRASS}
    # start: on Bahnhofplatz, just north of the middle of the station building
    hbf_cells = [(x, y) for y in range(H) for x in range(W) if bid_grid[y][x] == hbf_id]
    hx = sorted(x for x, _ in hbf_cells)[len(hbf_cells) // 2]
    hy = min(y for x, y in hbf_cells if x == hx)
    start = nearest((hx, hy - 1), lambda x, y: kind[y][x] in walk and y < hy)

    # Ballhaus entrance: its cell nearest to the address that touches a walkable cell
    def touches_walk(x, y):
        return any(0 <= x + dx < W and 0 <= y + dy < H and kind[y + dy][x + dx] in walk
                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))

    # Ballhaus West: the building cell nearest to Hirschstrasse 18 that touches the street;
    # it and its building neighbours on that block face become the club
    goal = nearest(to_cell(*BALLHAUS), lambda x, y: kind[y][x] == BUILDING and touches_walk(x, y))
    gx, gy = goal
    for x, y in [(gx, gy)] + neighbours(gx, gy):
        if kind[y][x] == BUILDING:
            bid_grid[y][x] = ballhaus_id
    return {
        "W": W, "H": H, "kind": kind, "bid": bid_grid, "names": name_grid, "name_list": name_list,
        "tram_dir": tram_dir, "hbf_id": hbf_id, "ballhaus_id": ballhaus_id, "start": start, "goal": goal,
        "buildings": buildings,
    }


if __name__ == "__main__":
    m = build()
    print(m["W"], m["H"], "start", m["start"], "goal", m["goal"], "names", len(m["name_list"]))
