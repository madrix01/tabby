"""Draws the extra characters in the same format as ../../characters/*.svg:
flat filled paths (one per colour, overlapping shapes merged into one outline) + ink-coloured eyes and mouth.
Two evolution lines: Mochi 41 -> Mochiko 43 -> Mochimaru 44, Nimbo 42 -> Cumulo 45 -> Seraphluff 46.
Writes character_41..46.svg next to this file; then rebuild the catalog (cd ../compiler && npm run build).

    python3 -m venv .venv && .venv/bin/pip install shapely && .venv/bin/python make.py
"""
import math
import os

from shapely.affinity import rotate, scale
from shapely.geometry import LineString, Point, box
from shapely.ops import unary_union

INK = '#2b2a33'
HERE = os.path.dirname(os.path.abspath(__file__))


def ellipse(cx, cy, rx, ry):
    return scale(Point(cx, cy).buffer(1, 64), rx, ry)


def stroke(points, width):
    return LineString(points).buffer(width / 2, 32)


def arc(cx, cy, r, a0, a1, n=48):
    return [(cx + r * math.cos(math.radians(a)), cy - r * math.sin(math.radians(a))) for a in (a0 + (a1 - a0) * k / n for k in range(n + 1))]


def path(geom, fill):
    rings = []
    for poly in getattr(geom, 'geoms', [geom]):
        for ring in [poly.exterior, *poly.interiors]:
            pts = list(ring.simplify(0.4).coords)
            rings.append('M' + ' L'.join(f'{x:.1f} {y:.1f}' for x, y in pts) + 'Z')
    return f'<path d="{" ".join(rings)}" fill="{fill}" fill-rule="evenodd"/>'


def eye(cx, cy, r):
    return f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{r:.1f}" fill="{INK}"/>'


def smile(cx, cy, w):
    return path(stroke(arc(cx, cy - w * .9, w * 1.15, 235, 305), w * .32), INK)


def write(n, parts):
    svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 600 600" width="300" height="300">' + ''.join(parts) + '</svg>'
    with open(os.path.join(HERE, f'character_{n}.svg'), 'w') as f:
        f.write(svg + '\n')


# 41 Mochi: pale-blue dumpling dome, bun top-knot with a leaf, nub arms, two round feet
body = unary_union([
    ellipse(300, 430, 205, 235).intersection(box(0, 0, 600, 430)),                    # top half of the dome
    ellipse(300, 430, 205, 42),                                                      # rounded underside
    ellipse(248, 468, 44, 30), ellipse(352, 468, 44, 30),                             # feet
    stroke([(118, 372), (100, 430)], 38), ellipse(98, 448, 32, 27),                   # left arm + hand
    stroke([(482, 372), (500, 430)], 38), ellipse(502, 448, 32, 27),                  # right arm + hand
])
knot = unary_union([ellipse(262, 212, 46, 40), ellipse(338, 212, 46, 40), ellipse(300, 182, 44, 42), ellipse(300, 222, 50, 24)])
crease = stroke([(304, 168), (292, 186), (288, 210), (296, 236)], 8)
leaf = rotate(ellipse(392, 150, 54, 19), -22, origin=(392, 150)).union(stroke([(338, 176), (352, 166)], 7))
write(41, [path(leaf, '#8fd19e'), path(body, '#bcd5ec'), path(knot, '#cfe1f3'), path(crease, '#9dbcdf'),
           eye(236, 402, 16), eye(364, 402, 16), smile(300, 446, 18)])

# 42 Nimbo: cream cloud with a halo behind it, a little curl on top, nub arms, two round feet
cloud = unary_union([ellipse(300, 340, 175, 120)] + [Point(300 + 175 * math.cos(t), 330 - 118 * math.sin(t)).buffer(64, 48)
                     for t in (math.radians(a) for a in (10, 45, 80, 115, 150, 172))] + [
    ellipse(252, 468, 42, 30), ellipse(348, 468, 42, 30),
    stroke([(140, 380), (126, 432)], 36), ellipse(124, 450, 31, 27),
    stroke([(460, 380), (474, 432)], 36), ellipse(476, 450, 31, 27),
])
halo = stroke(arc(300, 300, 205, 18, 162), 22)
curl = stroke([(322, 196), (334, 162), (356, 138), (384, 130)], 22)
write(42, [path(halo, '#b79e6c'), path(cloud, '#e9dcc0'), path(curl, '#f4ecdb'),
           eye(246, 336, 16), eye(354, 336, 16), smile(300, 378, 18)])

def leaf(cx, cy, rx, ry, angle, stem_from):
    return rotate(ellipse(cx, cy, rx, ry), angle, origin=(cx, cy)).union(stroke([stem_from, (cx - rx * .7 * math.cos(math.radians(angle)), cy + rx * .7 * math.sin(math.radians(angle)))], 7))


def mirror(points):
    return [(600 - x, y) for x, y in points]


# 43 Mochiko: taller dome, bigger top-knot, two leaves, arms lifted a little
body = unary_union([
    ellipse(300, 440, 215, 265).intersection(box(0, 0, 600, 440)), ellipse(300, 440, 215, 46),
    ellipse(244, 480, 48, 32), ellipse(356, 480, 48, 32),
    stroke([(110, 366), (80, 412)], 40), ellipse(74, 428, 34, 29),
    stroke(mirror([(110, 366), (80, 412)]), 40), ellipse(526, 428, 34, 29),
])
knot = unary_union([ellipse(256, 190, 54, 46), ellipse(344, 190, 54, 46), ellipse(300, 152, 52, 50), ellipse(300, 204, 60, 26)])
crease = stroke([(306, 134), (292, 158), (288, 186), (296, 216)], 9)
leaves = leaf(404, 114, 60, 21, 25, (346, 150)).union(leaf(204, 124, 42, 16, -28, (252, 156)))
write(43, [path(leaves, '#8fd19e'), path(body, '#bcd5ec'), path(knot, '#cfe1f3'), path(crease, '#9dbcdf'),
           eye(232, 404, 17), eye(368, 404, 17), smile(300, 452, 20)])

# 44 Mochimaru: two-tier dumpling, arms up, a flower crown on the knot
base = ellipse(300, 455, 235, 190).intersection(box(0, 0, 600, 455)).union(ellipse(300, 455, 235, 48))
head = ellipse(300, 300, 165, 150)
body = unary_union([base, head, ellipse(240, 494, 52, 34), ellipse(360, 494, 52, 34),
                    stroke([(150, 330), (98, 276)], 40), ellipse(86, 258, 34, 30),
                    stroke(mirror([(150, 330), (98, 276)]), 40), ellipse(514, 258, 34, 30)])
sash = stroke(arc(300, 160, 250, 238, 302), 20).intersection(body)          # lighter band where the tiers meet
petals = unary_union([rotate(ellipse(300, 116, 26, 34), a, origin=(300, 146)) for a in range(0, 360, 72)])
leaves = leaf(408, 132, 62, 22, 22, (336, 150)).union(leaf(196, 136, 48, 18, -24, (262, 152)))
write(44, [path(leaves, '#8fd19e'), path(body, '#bcd5ec'), path(sash, '#d6e7f6'), path(petals, '#cfe1f3'), path(Point(300, 146).buffer(13, 32), '#f6c945'),
           eye(240, 302, 18), eye(360, 302, 18), smile(300, 352, 22)])

# 45 Cumulo: bigger cloud, small wings, wider halo, double curl
cloud = unary_union([ellipse(300, 348, 190, 128)] + [Point(300 + 190 * math.cos(t), 336 - 124 * math.sin(t)).buffer(70, 48)
                     for t in (math.radians(a) for a in (5, 35, 65, 95, 125, 155, 175))] + [
    ellipse(250, 480, 46, 32), ellipse(350, 480, 46, 32),
    stroke([(128, 392), (110, 442)], 38), ellipse(108, 458, 33, 28),
    stroke(mirror([(128, 392), (110, 442)]), 38), ellipse(492, 458, 33, 28),
])
wings = unary_union([ellipse(78, 296, 52, 40), ellipse(50, 254, 38, 30), ellipse(522, 296, 52, 40), ellipse(550, 254, 38, 30)])
halo = stroke(arc(300, 300, 228, 15, 165), 24)
curls = stroke([(318, 178), (330, 140), (356, 114), (388, 108)], 22).union(stroke([(286, 182), (270, 150), (248, 136)], 16))
write(45, [path(halo, '#b79e6c'), path(wings, '#d8c7a0'), path(cloud, '#e9dcc0'), path(curls, '#f4ecdb'),
           eye(242, 342, 17), eye(358, 342, 17), smile(300, 388, 20)])

# 46 Seraphluff: big cloud, feathered wings, a halo ring floating above
cloud = unary_union([ellipse(300, 360, 205, 132)] + [Point(300 + 205 * math.cos(t), 350 - 128 * math.sin(t)).buffer(76, 48)
                     for t in (math.radians(a) for a in (0, 30, 60, 90, 120, 150, 180))] + [
    ellipse(246, 496, 50, 34), ellipse(354, 496, 50, 34),
    stroke([(122, 432), (96, 472)], 40), ellipse(90, 488, 34, 29),
    stroke(mirror([(122, 432), (96, 472)]), 40), ellipse(510, 488, 34, 29),
])
feathers = [(70, 232, 96, 36, -38), (46, 282, 90, 32, -20), (40, 330, 74, 27, -4)]
wings = unary_union([rotate(ellipse(x, y, rx, ry), a, origin=(x, y)) for x, y, rx, ry, a in feathers]
                    + [rotate(ellipse(600 - x, y, rx, ry), -a, origin=(600 - x, y)) for x, y, rx, ry, a in feathers])
halo = ellipse(300, 84, 98, 28).difference(ellipse(300, 84, 74, 15))
curl = stroke([(318, 196), (332, 160), (360, 136), (392, 132)], 24)
write(46, [path(wings, '#d8c7a0'), path(cloud, '#e9dcc0'), path(curl, '#f4ecdb'), path(halo, '#c9ad6e'),
           eye(238, 352, 18), eye(362, 352, 18), smile(300, 400, 22)])
print('wrote characters 41-46')
