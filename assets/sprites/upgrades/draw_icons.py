#!/usr/bin/env python3
"""Draws the 512x512 upgrade card icons from code (Pillow). Run from the repo root:
    python3 assets/sprites/upgrades/draw_icons.py [id ...]
No text anywhere. Chunky shapes, a thick Midnight Ink sticker outline, Cool Arcade palette.
The disc behind the object says the kind: cyan normal, orange burst strong, pink dots joke,
violet sparkle curse (curses look tempting)."""
import json
import math
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(ROOT, "../../../data/tools"))
from upgrades_table import UPGRADES  # noqa: E402

S = 1024          # drawn at 2x, saved at 512
W = 16            # inner ink line
OUTLINE = 22      # sticker outline around the whole object
PAL = {c["key"]: c["hex"] for c in json.load(open(os.path.join(ROOT, "../../../art/palettes/cool_arcade.json")))["colours"]}


def col(key, a=255):
    h = PAL.get(key, key).lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def mix(a, b, t):
    a, b = col(a), col(b)
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


INK = col("ink")
WHITE = col("cloud")
GOLD = col("jeff_yellow")
ORANGE = col("magma")
PINK = col("comb")
BROWN = col("boots_brown")
PEACH = col("clay")
TEAL = col("grass")
BLUE = col("jeans_blue")
SLATE = col("stone")
PLUM = col("topsoil")
VIOLET = col("sky4")
INDIGO = col("sky5")
CYAN = col("sky2")
AQUA = col("sky1")
LASER = col("sky3")
DARK = col("hat_black")
FROG = (150, 205, 80, 255)   # frog skin from scenes/curses/frog.tscn (not player green)


class Pen:
    def __init__(self):
        self.img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    def ell(self, cx, cy, rx, ry=None, fill=WHITE, w=W):
        ry = rx if ry is None else ry
        self.d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=fill, outline=INK if w else None, width=w)

    def rect(self, x0, y0, x1, y1, r=30, fill=WHITE, w=W):
        self.d.rounded_rectangle((x0, y0, x1, y1), radius=r, fill=fill, outline=INK if w else None, width=w)

    def poly(self, pts, fill=WHITE, w=W):
        self.d.polygon(pts, fill=fill)
        if w:
            self.line(pts + [pts[0]], INK, w)

    def line(self, pts, fill=INK, w=W):
        self.d.line(pts, fill=fill, width=w, joint="curve")
        for p in (pts[0], pts[-1]):
            self.d.ellipse((p[0] - w / 2, p[1] - w / 2, p[0] + w / 2, p[1] + w / 2), fill=fill)

    def fat(self, pts, fill, w):
        """A thick stroke with an ink edge (springs, strings, legs)."""
        self.line(pts, INK, w + 2 * W)
        self.line(pts, fill, w)

    def shine(self, cx, cy, rx, ry=None, a=150):
        ry = rx if ry is None else ry
        self.d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=(255, 255, 255, a))

    def star(self, cx, cy, r, fill=GOLD, points=5, inner=0.45, rot=-90, w=W):
        pts = []
        for i in range(points * 2):
            rr = r if i % 2 == 0 else r * inner
            a = math.radians(rot + i * 180 / points)
            pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
        self.poly(pts, fill, w)

    def sparkle(self, cx, cy, r, fill=WHITE):
        self.star(cx, cy, r, fill, points=4, inner=0.28, rot=0, w=0)

    def arcs(self, cx, cy, r, a0, a1, n=3, gap=40, w=W):
        for i in range(n):
            rr = r + i * gap
            self.d.arc((cx - rr, cy - rr, cx + rr, cy + rr), a0, a1, fill=INK, width=w)


def ellpts(cx, cy, rx, ry, a0=0, a1=360, n=40):
    return [(cx + rx * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
             cy + ry * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


# --- reusable things -------------------------------------------------------------------------

def boot(p, x, y, s=1.0, fill=BROWN, sole=DARK, laces=True, flip=False):
    """A chunky boot, toe pointing right (left if flip); (x, y) = bottom of the heel."""
    f = -1 if flip else 1
    X = lambda dx: x + f * dx * s
    Y = lambda dy: y - dy * s
    shaft = [(X(0), Y(40)), (X(0), Y(330)), (X(170), Y(330)), (X(170), Y(150)), (X(300), Y(140)),
             (X(360), Y(110)), (X(370), Y(40))]
    p.poly(shaft, fill)
    p.rect(min(X(-10), X(385)), Y(55), max(X(-10), X(385)), Y(-10), r=int(28 * s), fill=sole)
    p.rect(min(X(-15), X(185)), Y(360), max(X(-15), X(185)), Y(300), r=int(22 * s), fill=mix("boots_brown", "cloud", 0.35))
    if laces:
        for i in range(3):
            yy = Y(270 - i * 50)
            p.line([(X(110), yy), (X(175), yy - 18 * s)], WHITE, int(14 * s))
    p.shine(X(70), Y(250), 22 * s, 50 * s, 110)


def shoe(p, x, y, s=1.0, fill=LASER, sole=WHITE, flip=False):
    """A round trainer, toe right; (x, y) = bottom of the heel."""
    f = -1 if flip else 1
    X = lambda dx: x + f * dx * s
    Y = lambda dy: y - dy * s
    pts = [(X(0), Y(30)), (X(0), Y(150)), (X(30), Y(190)), (X(130), Y(190)), (X(170), Y(130)),
           (X(270), Y(110)), (X(310), Y(70)), (X(310), Y(30))]
    p.poly(pts, fill)
    p.rect(min(X(-12), X(322)), Y(48), max(X(-12), X(322)), Y(-8), r=int(26 * s), fill=sole)
    p.line([(X(120), Y(150)), (X(150), Y(110))], WHITE, int(14 * s))
    p.line([(X(160), Y(140)), (X(195), Y(105))], WHITE, int(14 * s))
    p.shine(X(55), Y(130), 18 * s, 36 * s, 110)


def ball(p, cx, cy, r):
    """The game's beach ball: white with orange, cyan, pink wedges."""
    p.ell(cx, cy, r, fill=WHITE)
    for i, c in enumerate((ORANGE, CYAN, PINK)):
        a0 = i * 120 - 90
        p.d.pieslice((cx - r + W / 2, cy - r + W / 2, cx + r - W / 2, cy + r - W / 2), a0, a0 + 60, fill=c)
    p.ell(cx, cy, r, fill=None)
    p.ell(cx, cy, r * 0.18, fill=WHITE, w=W - 4)
    p.shine(cx - r * 0.4, cy - r * 0.45, r * 0.18, r * 0.12, 160)


def flame(p, x, y, s=1.0, down=True):
    f = 1 if down else -1
    outer = [(x - 70 * s, y), (x + 70 * s, y), (x + 40 * s, y + f * 120 * s), (x + 10 * s, y + f * 90 * s),
             (x, y + f * 200 * s), (x - 20 * s, y + f * 100 * s), (x - 45 * s, y + f * 130 * s)]
    p.poly(outer, ORANGE)
    inner = [(x - 35 * s, y + f * 10 * s), (x + 35 * s, y + f * 10 * s), (x, y + f * 120 * s)]
    p.poly(inner, GOLD, w=0)


def spring(p, x, y0, y1, rx=70, n=5, fill=SLATE):
    pts = []
    for i in range(n * 2 + 1):
        pts.append((x + (rx if i % 2 else -rx), y0 + (y1 - y0) * i / (n * 2)))
    p.fat(pts, fill, 30)


def speed_lines(p, x, y, n=3, length=160, gap=55, w=22):
    for i in range(n):
        yy = y + (i - (n - 1) / 2) * gap
        p.line([(x - length + abs(i - 1) * 40, yy), (x, yy)], INK, w)


def face(p, cx, cy, r, mood="happy"):
    p.ell(cx - r * 0.3, cy - r * 0.1, r * 0.1, r * 0.14, fill=INK, w=0)
    p.ell(cx + r * 0.3, cy - r * 0.1, r * 0.1, r * 0.14, fill=INK, w=0)
    if mood == "happy":
        p.d.arc((cx - r * 0.35, cy - r * 0.1, cx + r * 0.35, cy + r * 0.45), 20, 160, fill=INK, width=W)
    elif mood == "o":
        p.ell(cx, cy + r * 0.3, r * 0.14, r * 0.18, fill=INK, w=0)


def music_note(p, x, y, s=1.0, fill=INK):
    p.ell(x, y, 44 * s, 34 * s, fill=fill, w=0)
    p.line([(x + 36 * s, y - 5 * s), (x + 36 * s, y - 170 * s)], fill, int(20 * s))
    p.d.polygon([(x + 36 * s, y - 170 * s), (x + 110 * s, y - 120 * s), (x + 100 * s, y - 95 * s),
                 (x + 36 * s, y - 130 * s)], fill=fill)


def cloud(p, cx, cy, s=1.0, fill=WHITE):
    for dx, dy, r in ((-150, 30, 110), (0, -40, 150), (150, 30, 115), (60, 60, 110), (-60, 60, 110)):
        p.ell(cx + dx * s, cy + dy * s, r * s, fill=fill, w=0)
    # ink edge: draw again as an outline-only silhouette is handled by the sticker outline


# --- the icons -------------------------------------------------------------------------------

def i_big_boot(p):
    boot(p, 220, 820, 1.55)


def i_spring_shoes(p):
    spring(p, 330, 600, 860, 70)
    spring(p, 640, 600, 860, 70)
    shoe(p, 160, 600, 0.95)
    shoe(p, 480, 600, 0.95, fill=ORANGE)
    p.arcs(512, 900, 330, 200, 340, n=1)


def i_lucky_sock(p):
    pts = [(380, 150), (640, 150), (640, 600), (720, 660), (760, 760), (700, 860), (560, 880),
           (360, 800), (380, 640)]
    p.poly(pts, WHITE)
    for i, c in enumerate((PINK, GOLD, PINK, GOLD)):
        y = 230 + i * 95
        p.d.rectangle((380 + W / 2, y, 640 - W / 2, y + 48), fill=c)
    p.d.polygon([(560, 880), (700, 860), (760, 760), (720, 660), (620, 700)], fill=PINK)
    p.poly(pts, None)
    p.rect(360, 120, 660, 200, r=30, fill=WHITE)
    # four-leaf clover
    for dx, dy in ((-45, -45), (45, -45), (-45, 45), (45, 45)):
        p.ell(250 + dx, 600 + dy, 55, fill=TEAL)
    p.fat([(250, 640), (230, 760)], TEAL, 18)
    p.sparkle(800, 300, 70, GOLD)
    p.sparkle(180, 330, 45, WHITE)


def i_trampoline_tee(p):
    for x in (250, 774):
        p.fat([(x, 640), (x - 40, 880)], DARK, 26)
    p.ell(512, 640, 300, 90, fill=DARK)
    p.ell(512, 630, 250, 60, fill=LASER, w=W - 4)
    ball(p, 512, 360, 170)


def i_helium_ball(p):
    p.fat([(512, 690), (480, 780), (540, 860), (500, 940)], WHITE, 10)
    p.poly([(480, 640), (544, 640), (560, 700), (464, 700)], ORANGE)
    ball(p, 512, 400, 290)
    for x in (150, 874):
        p.line([(x, 720), (x, 520)], INK, 22)
        p.line([(x, 520), (x - 40, 580)], INK, 22)
        p.line([(x, 520), (x + 40, 580)], INK, 22)


def i_sweatband(p):
    p.ell(512, 520, 360, 230, fill=WHITE)
    p.ell(512, 520, 260, 140, fill=None)
    p.d.ellipse((512 - 260 + W, 520 - 140 + W, 512 + 260 - W, 520 + 140 - W), fill=(0, 0, 0, 0))
    for rx_ry, c in (((330, 200), ORANGE),):
        pass
    p.d.arc((152, 290, 872, 750), 160, 380, fill=ORANGE, width=50)
    p.ell(512, 520, 360, 230, fill=None)
    p.ell(512, 520, 260, 140, fill=None)
    for x, y, s in ((300, 180, 1.0), (720, 200, 0.8), (800, 380, 0.6)):
        p.poly([(x, y - 80 * s), (x + 45 * s, y + 10 * s), (x, y + 50 * s), (x - 45 * s, y + 10 * s)], AQUA)


def i_rocket_boots(p):
    flame(p, 300, 720, 1.2)
    boot(p, 210, 720, 1.25, fill=LASER, sole=SLATE)
    p.rect(150, 450, 260, 700, r=40, fill=SLATE)
    p.poly([(150, 450), (205, 360), (260, 450)], ORANGE)


def i_super_strength(p):
    p.rect(330, 470, 694, 554, r=30, fill=SLATE)
    for x, c in ((260, DARK), (764, DARK)):
        p.rect(x - 70, 300, x + 70, 724, r=50, fill=c)
        p.shine(x - 30, 380, 18, 50, 110)
    for x in (140, 884):
        p.rect(x - 40, 380, x + 40, 644, r=30, fill=DARK)
    p.star(512, 330, 90, GOLD)


def i_running_start(p):
    p.rect(470, 120, 554, 210, r=20, fill=SLATE)
    p.rect(440, 80, 584, 140, r=25, fill=ORANGE)
    p.ell(512, 540, 330, fill=SLATE)
    p.ell(512, 540, 270, fill=WHITE)
    for i in range(12):
        a = math.radians(i * 30)
        r0 = 225 if i % 3 else 200
        p.line([(512 + r0 * math.cos(a), 540 + r0 * math.sin(a)), (512 + 250 * math.cos(a), 540 + 250 * math.sin(a))], INK, 18)
    p.d.pieslice((302, 330, 722, 750), -90, 30, fill=col("magma", 140))
    p.line([(512, 540), (512, 340)], INK, 26)
    p.line([(512, 540), (660, 620)], PINK, 26)
    p.ell(512, 540, 34, fill=INK, w=0)


def i_coachs_whistle(p):
    p.fat([(300, 320), (200, 160), (512, 90), (820, 160), (740, 330)], PINK, 22)
    p.ell(560, 600, 230, fill=GOLD)
    p.rect(180, 410, 600, 560, r=40, fill=GOLD)
    p.ell(560, 600, 230, fill=None)
    p.d.rectangle((420, 420 + W / 2, 600, 552 - W / 2), fill=GOLD)
    p.ell(560, 600, 110, fill=DARK)
    p.shine(470, 480, 50, 26, 130)


def i_super_cape(p):
    pts = [(380, 170), (644, 170), (760, 520), (860, 860), (700, 800), (560, 880), (420, 790), (240, 870), (300, 520)]
    p.poly(pts, PINK)
    p.poly([(380, 170), (644, 170), (600, 260), (424, 260)], mix("comb", "ink", 0.3))
    p.rect(340, 120, 684, 200, r=40, fill=GOLD)
    p.star(512, 520, 140, GOLD)


def i_propeller_cap(p):
    p.d.pieslice((222, 380, 802, 960), 180, 360, fill=LASER)
    p.d.arc((222, 380, 802, 960), 180, 360, fill=INK, width=W)
    p.line([(222, 670), (802, 670)], INK, W)
    p.poly([(700, 640), (930, 690), (920, 740), (700, 720)], BLUE)
    p.d.pieslice((232 + W, 390 + W, 792 - W, 950 - W), 225, 315, fill=GOLD)
    p.fat([(512, 390), (512, 280)], SLATE, 22)
    p.poly([(512, 260), (180, 210), (170, 290)], ORANGE)
    p.poly([(512, 260), (844, 310), (854, 230)], PINK)
    p.ell(512, 260, 40, fill=GOLD)


def i_foam_finger(p):
    p.rect(330, 560, 760, 900, r=90, fill=GOLD)
    p.rect(440, 110, 600, 640, r=80, fill=GOLD)
    p.rect(260, 560, 420, 720, r=70, fill=GOLD)
    p.rect(330, 650, 760, 900, r=90, fill=None)
    p.shine(490, 260, 26, 90, 130)
    p.rect(300, 860, 790, 960, r=30, fill=ORANGE)
    p.star(760, 330, 80, PINK)


def i_giant_foot(p):
    # the sole of an enormous bare foot, footprint style
    p.ell(530, 600, 250, 330, fill=PEACH)
    p.ell(560, 360, 230, 170, fill=PEACH)
    p.d.ellipse((530 - 250 + W, 600 - 330 + W, 530 + 250 - W, 600 + 330 - W), fill=PEACH)
    p.d.ellipse((560 - 230 + W, 360 - 170 + W, 560 + 230 - W, 360 + 170 - W), fill=PEACH)
    for x, y, r in ((360, 150, 85), (500, 110, 62), (615, 115, 54), (715, 145, 48), (795, 200, 42)):
        p.ell(x, y, r, fill=PEACH)
    p.ell(540, 760, 150, 110, fill=mix("clay", "magma", 0.35), w=0)
    p.shine(400, 470, 50, 110, 110)


def i_knee_pads(p):
    p.fat([(470, 60), (470, 500), (560, 760)], BLUE, 170)
    shoe(p, 470, 940, 1.15, LASER)
    p.ell(480, 480, 190, 170, fill=ORANGE)
    p.ell(480, 480, 110, 95, fill=GOLD)
    p.shine(420, 420, 40, 26, 160)
    p.arcs(480, 480, 230, 150, 210, n=2, gap=55)
    p.arcs(480, 480, 230, -30, 30, n=2, gap=55)


def i_wind_up_key(p):
    p.rect(470, 420, 554, 900, r=30, fill=GOLD)
    p.rect(400, 820, 624, 900, r=30, fill=ORANGE)
    for dx in (-1, 1):
        p.ell(512 + dx * 190, 300, 170, 150, fill=GOLD)
        p.ell(512 + dx * 190, 300, 70, 60, fill=(0, 0, 0, 0))
    p.ell(512, 360, 80, fill=ORANGE)
    p.d.arc((150, 130, 874, 700), 200, 250, fill=INK, width=24)
    p.d.arc((150, 130, 874, 700), 290, 340, fill=INK, width=24)


def i_dad_strength(p):
    # big coffee mug with steam, a hammer behind
    p.fat([(200, 880), (720, 200)], BROWN, 46)
    p.rect(600, 140, 860, 300, r=30, fill=SLATE)
    p.d.arc((560, 420, 820, 720), -90, 90, fill=INK, width=W * 4)
    p.d.arc((560 + W, 420 + W, 820 - W, 720 - W), -90, 90, fill=WHITE, width=W * 2)
    p.rect(260, 380, 680, 860, r=60, fill=WHITE)
    p.rect(260 + W, 560, 680 - W, 640, r=0, fill=ORANGE, w=0)
    p.star(470, 720, 70, GOLD)
    for x in (360, 470, 580):
        p.fat([(x, 330), (x - 30, 260), (x + 10, 190), (x - 20, 130)], WHITE, 14)
    p.shine(320, 480, 22, 60, 130)


def i_slingshot_buddy(p):
    p.fat([(512, 920), (512, 600)], BROWN, 70)
    p.fat([(512, 620), (300, 300)], BROWN, 64)
    p.fat([(512, 620), (724, 300)], BROWN, 64)
    p.fat([(300, 300), (512, 760), (724, 300)], PINK, 18)
    ball(p, 512, 740, 120)


def i_moon_gravity(p):
    p.ell(470, 560, 320, fill=mix("cloud", "stone", 0.35))
    for cx, cy, r in ((380, 460, 70), (580, 640, 90), (420, 720, 40), (610, 420, 45)):
        p.ell(cx, cy, r, fill=SLATE, w=W - 4)
    p.shine(340, 380, 60, 40, 120)
    p.d.arc((100, 240, 940, 900), 200, 330, fill=INK, width=20)
    ball(p, 830, 240, 100)
    p.sparkle(170, 200, 60, GOLD)
    p.sparkle(860, 820, 50, GOLD)


def i_cannon_leg(p):
    p.poly([(140, 340), (640, 460), (640, 700), (140, 640)], DARK)
    p.rect(600, 400, 720, 760, r=50, fill=DARK)
    p.ell(330, 720, 160, fill=BROWN)
    p.ell(330, 720, 50, fill=GOLD)
    for i in range(6):
        a = math.radians(i * 60)
        p.line([(330 + 55 * math.cos(a), 720 + 55 * math.sin(a)), (330 + 145 * math.cos(a), 720 + 145 * math.sin(a))], INK, 18)
    p.shine(260, 440, 80, 26, 90)
    for dx, dy, r in ((800, 520, 110), (880, 410, 70), (900, 640, 80)):
        p.ell(dx, dy, r, fill=WHITE)
    p.star(830, 530, 70, GOLD)


def i_pogo_legs(p):
    p.fat([(512, 140), (512, 900)], SLATE, 40)
    p.fat([(330, 230), (694, 230)], ORANGE, 44)
    p.rect(400, 470, 624, 560, r=30, fill=LASER)
    spring(p, 512, 600, 860, 80, 4, GOLD)
    p.ell(512, 920, 70, 30, fill=DARK)
    p.arcs(512, 940, 260, 200, 340, n=2, gap=50)


def i_tornado_spin(p):
    rows = [(512, 220, 330, 70), (530, 340, 270, 60), (500, 450, 210, 55), (530, 560, 160, 50),
            (500, 660, 110, 40), (520, 750, 70, 32), (510, 830, 40, 24)]
    for cx, cy, rx, ry in rows:
        p.ell(cx, cy, rx, ry, fill=mix("sky1", "stone", 0.3))
        p.d.arc((cx - rx + 20, cy - ry + 10, cx + rx - 20, cy + ry - 10), 20, 160, fill=WHITE, width=12)
    ball(p, 820, 300, 90)


def i_jetpack(p):
    for x in (360, 664):
        flame(p, x, 760, 1.3)
        p.rect(x - 110, 260, x + 110, 780, r=80, fill=SLATE)
        p.poly([(x - 110, 320), (x, 140), (x + 110, 320)], ORANGE)
        p.rect(x - 110, 600, x + 110, 680, r=0, fill=LASER)
        p.shine(x - 50, 420, 22, 80, 120)
    p.rect(440, 400, 584, 620, r=30, fill=DARK)


def i_volcano_boots(p):
    p.poly([(150, 880), (400, 330), (620, 330), (874, 880)], BROWN)
    p.poly([(400, 330), (620, 330), (590, 420), (540, 380), (500, 460), (450, 390), (420, 430)], ORANGE)
    p.rect(120, 840, 904, 920, r=30, fill=DARK)
    for cx, cy, r in ((512, 200, 80), (380, 130, 50), (650, 120, 60)):
        p.ell(cx, cy, r, fill=ORANGE)
        p.ell(cx - r * 0.2, cy - r * 0.2, r * 0.4, fill=GOLD, w=0)
    p.shine(330, 700, 30, 80, 90)


def i_kangaroo_tail(p):
    # a big tapering tail on a spring: chain of circles along a curve
    fur = mix("boots_brown", "clay", 0.45)
    pts = [(200 + 620 * t + 90 * math.sin(t * 3.0), 200 + 560 * t * t + 80 * math.sin(t * 2.5)) for t in [i / 24 for i in range(25)]]
    for i, (x, y) in enumerate(pts):
        r = 150 - i * 4.6
        p.ell(x, y, r, fill=INK, w=0)
    for i, (x, y) in enumerate(pts):
        r = 150 - i * 4.6 - W
        p.ell(x, y, r, fill=fur, w=0)
    p.ell(pts[-1][0], pts[-1][1], 50, fill=mix("clay", "cloud", 0.5))
    for i in (3, 9, 15):
        x, y = pts[i]
        p.shine(x - 40, y - 50, 30, 18, 110)
    spring(p, 560, 640, 900, 60, 3, SLATE)


def i_turbo_fan(p):
    p.rect(170, 150, 854, 834, r=120, fill=SLATE)
    p.ell(512, 492, 300, fill=AQUA)
    for i, c in enumerate((LASER, PINK, ORANGE)):
        a = i * 120 - 30
        pts = [(512, 492)] + ellpts(512, 492, 280, 280, a, a + 70, 12)
        p.poly(pts, c)
    p.ell(512, 492, 300, fill=None)
    for x in range(272, 760, 80):
        p.line([(x, 220), (x, 764)], col("cloud", 170), 10)
    p.ell(512, 492, 60, fill=GOLD)
    p.rect(330, 820, 694, 900, r=30, fill=DARK)


def i_thunder_hat(p):
    cloud(p, 512, 400, 1.6, mix("stone", "ink", 0.25))
    p.poly([(560, 520), (420, 740), (520, 740), (440, 950), (680, 660), (570, 660), (650, 520)], GOLD)
    p.ell(430, 360, 30, 40, fill=WHITE, w=0)
    p.ell(600, 360, 30, 40, fill=WHITE, w=0)
    p.line([(380, 290), (470, 320)], INK, 20)
    p.line([(650, 290), (560, 320)], INK, 20)


def i_tiny_hat(p):
    p.ell(512, 610, 330, 300, fill=PEACH)
    face(p, 512, 640, 300)
    p.shine(380, 450, 60, 40, 110)
    p.rect(450, 230, 574, 290, r=10, fill=DARK)
    p.rect(470, 150, 554, 260, r=10, fill=DARK)
    p.d.rectangle((470 + W / 2, 220, 554 - W / 2, 240), fill=PINK)
    p.sparkle(660, 170, 50, GOLD)


def i_extra_shoes(p):
    shoe(p, 110, 500, 0.95, ORANGE)
    shoe(p, 520, 500, 0.95, LASER)
    shoe(p, 110, 870, 0.95, PINK)
    shoe(p, 520, 870, 0.95, GOLD)


def i_mustache(p):
    pts = [(512, 470)]
    for side in (1, -1):
        pass
    right = [(512, 470), (640, 400), (780, 430), (880, 520), (900, 430), (950, 470), (920, 600), (800, 640),
             (660, 600), (512, 560)]
    left = [(1024 - x, y) for x, y in right]
    p.poly(left[::-1] + right[1:], DARK)
    p.shine(650, 470, 60, 18, 90)
    p.shine(374, 470, 60, 18, 90)
    p.ell(512, 420, 90, 70, fill=PEACH)


def i_honk_horn_shoes(p):
    shoe(p, 120, 880, 1.15, PINK)
    p.poly([(470, 300), (780, 140), (820, 470)], GOLD)
    p.ell(800, 300, 70, 170, fill=GOLD)
    p.ell(800, 300, 40, 120, fill=DARK, w=0)
    p.ell(340, 360, 150, fill=ORANGE)
    p.shine(290, 310, 40, 30, 140)
    for a in (-35, 0, 35):
        r = math.radians(a)
        p.line([(820 + 100 * math.cos(r), 300 + 100 * math.sin(r)), (820 + 170 * math.cos(r), 300 + 170 * math.sin(r))], INK, 24)


def i_confetti_kick(p):
    rnd = random.Random(4)
    for _ in range(26):
        x, y = rnd.uniform(380, 940), rnd.uniform(80, 560)
        c = rnd.choice((PINK, GOLD, CYAN, ORANGE, WHITE))
        if rnd.random() < 0.5:
            p.ell(x, y, 26, fill=c, w=8)
        else:
            a = rnd.uniform(0, math.pi)
            dx, dy = 40 * math.cos(a), 40 * math.sin(a)
            p.poly([(x - dx, y - dy), (x + dx, y + dy), (x + dx + 16, y + dy + 16), (x - dx + 16, y - dy + 16)], c, w=8)
    p.poly([(140, 900), (360, 440), (560, 640)], PINK)
    for t in (0.35, 0.65):
        a = (140 + (360 - 140) * t, 900 + (440 - 900) * t)
        b = (140 + (560 - 140) * t, 900 + (640 - 900) * t)
        p.line([a, b], GOLD, 24)
    p.ell(460, 540, 140, 40, fill=GOLD)


def i_balloon_animal_ball(p):
    c = PINK
    for (x0, y0, x1, y1, w) in ((330, 470, 690, 470, 120), (330, 470, 290, 760, 90), (420, 470, 450, 760, 90),
                                 (620, 470, 590, 760, 90), (690, 470, 730, 760, 90), (690, 470, 760, 260, 110),
                                 (330, 470, 220, 320, 70)):
        p.fat([(x0, y0), (x1, y1)], c, w)
    p.ell(800, 230, 110, 90, fill=c)
    p.ell(840, 140, 50, 80, fill=c)
    p.ell(760, 140, 50, 80, fill=c)
    p.ell(830, 220, 16, 22, fill=INK, w=0)
    p.shine(470, 440, 80, 20, 140)
    ball(p, 260, 820, 110)


def i_opera_kick(p):
    p.ell(470, 560, 330, 340, fill=PEACH)
    p.ell(470, 650, 170, 200, fill=DARK)
    p.ell(470, 760, 100, 60, fill=PINK, w=0)
    p.ell(370, 400, 40, 26, fill=INK, w=0)
    p.ell(570, 400, 40, 26, fill=INK, w=0)
    p.line([(310, 330), (420, 350)], INK, 22)
    p.line([(630, 330), (520, 350)], INK, 22)
    music_note(p, 800, 420, 1.1, INDIGO)
    music_note(p, 860, 760, 0.8, PINK)


def i_rubber_chicken(p):
    body = [(180, 700), (300, 560), (520, 520), (620, 380), (640, 200), (720, 170), (760, 230), (730, 420),
            (700, 600), (560, 760), (360, 800)]
    p.poly(body, GOLD)
    p.poly([(760, 200), (880, 230), (770, 260)], ORANGE)
    for x, y in ((690, 150), (720, 130), (750, 150)):
        p.ell(x, y, 30, fill=PINK)
    p.ell(710, 210, 18, fill=INK, w=0)
    p.fat([(420, 790), (400, 900)], ORANGE, 22)
    p.fat([(520, 770), (540, 900)], ORANGE, 22)
    p.poly([(180, 700), (110, 610), (220, 640)], GOLD)
    p.shine(350, 640, 70, 24, 120)


def i_duck_floatie(p):
    p.ell(512, 640, 400, 240, fill=GOLD)
    p.ell(512, 620, 200, 90, fill=AQUA)
    p.d.arc((112, 400, 912, 880), 30, 150, fill=ORANGE, width=50)
    p.ell(512, 640, 400, 240, fill=None)
    p.ell(760, 330, 150, fill=GOLD)
    p.poly([(880, 320), (990, 350), (880, 390)], ORANGE)
    p.ell(790, 290, 22, fill=INK, w=0)
    p.shine(280, 520, 80, 30, 140)


def i_googly_eyes(p):
    for cx, cy, r, px, py in ((330, 520, 230, 60, 90), (720, 480, 200, -40, 100)):
        p.ell(cx, cy, r, fill=WHITE)
        p.ell(cx + px, cy + py, r * 0.48, fill=INK, w=0)
        p.shine(cx - r * 0.45, cy - r * 0.45, r * 0.16, r * 0.1, 200)


def i_kiss_the_frog(p):
    p.ell(512, 600, 380, 270, fill=FROG)
    for dx in (-210, 210):
        p.ell(512 + dx, 360, 120, fill=FROG)
        p.ell(512 + dx, 360, 72, fill=WHITE)
        p.ell(512 + dx + 10, 375, 36, fill=INK, w=0)
        p.shine(512 + dx - 25, 330, 18, 12, 230)
    p.ell(512, 690, 120, 70, fill=PINK)
    p.line([(400, 690), (624, 690)], INK, 16)
    p.ell(300, 620, 50, 30, fill=col("comb", 170), w=0)
    p.ell(724, 620, 50, 30, fill=col("comb", 170), w=0)
    p.poly([(400, 260), (430, 150), (470, 220), (512, 130), (554, 220), (594, 150), (624, 260)], GOLD)
    heart(p, 820, 230, 70)


def heart(p, x, y, r, fill=PINK):
    p.ell(x - r * 0.5, y, r * 0.6, fill=fill, w=0)
    p.ell(x + r * 0.5, y, r * 0.6, fill=fill, w=0)
    p.d.polygon([(x - r * 1.05, y + r * 0.2), (x + r * 1.05, y + r * 0.2), (x, y + r * 1.4)], fill=fill)


def i_banana_peel(p):
    pale = mix("cloud", "jeff_yellow", 0.45)
    p.ell(512, 840, 330, 70, fill=col("ink", 60), w=0)
    p.poly([(440, 560), (450, 300), (512, 220), (574, 300), (584, 560)], pale)
    p.rect(485, 150, 539, 250, r=14, fill=BROWN)
    # three floppy flaps drooping from the middle
    p.poly([(450, 470), (330, 520), (220, 640), (170, 800), (250, 820), (320, 690), (440, 600)], GOLD)
    p.poly([(574, 470), (694, 520), (804, 640), (854, 800), (774, 820), (704, 690), (584, 600)], GOLD)
    p.poly([(450, 520), (574, 520), (590, 700), (560, 840), (464, 840), (434, 700)], GOLD)
    p.shine(480, 640, 18, 70, 140)
    for x, y in ((260, 760), (800, 760)):
        p.ell(x, y, 16, fill=BROWN, w=0)


def i_sneeze(p):
    p.ell(400, 540, 330, fill=PEACH)
    for cx in (290, 510):
        p.line([(cx - 55, 400), (cx + 5, 430), (cx - 55, 460)] if cx < 400 else [(cx + 55, 400), (cx - 5, 430), (cx + 55, 460)], INK, 22)
    p.ell(400, 560, 110, 90, fill=mix("clay", "magma", 0.3))
    p.ell(360, 600, 22, 16, fill=INK, w=0)
    p.ell(440, 600, 22, 16, fill=INK, w=0)
    p.ell(400, 740, 120, 50, fill=DARK)
    p.shine(260, 360, 50, 30, 120)
    rnd = random.Random(7)
    for _ in range(14):
        a = rnd.uniform(-0.6, 0.6)
        d = rnd.uniform(230, 420)
        p.ell(500 + d * math.cos(a), 640 + d * math.sin(a), rnd.uniform(18, 36), fill=AQUA, w=8)
    for cx, cy, r in ((830, 520, 90), (880, 660, 75), (800, 760, 65)):
        p.ell(cx, cy, r, fill=WHITE)


def i_shoelaces_tied(p):
    shoe(p, 80, 820, 1.0, LASER, flip=False)
    shoe(p, 944, 820, 1.0, ORANGE, flip=True)
    p.fat([(240, 680), (512, 560), (780, 680)], WHITE, 16)
    for dx in (-1, 1):
        p.ell(512 + dx * 120, 470, 110, 70, fill=WHITE)
        p.ell(512 + dx * 120, 470, 50, 24, fill=(0, 0, 0, 0))
    p.ell(512, 480, 50, fill=WHITE)
    p.sparkle(512, 260, 70, GOLD)


def i_too_much_lunch(p):
    for i, y in enumerate((800, 640, 480)):
        p.rect(220, y - 30, 804, y + 60, r=40, fill=mix("magma", "cloud", 0.55))
        p.d.rectangle((240, y - 60, 784, y - 26), fill=TEAL)
        p.rect(240, y - 75, 784, y - 25, r=20, fill=None, w=0)
        p.rect(250, y - 110, 774, y - 50, r=20, fill=PINK)
    p.ell(512, 300, 300, 110, fill=mix("magma", "cloud", 0.55))
    p.d.pieslice((212, 190, 812, 410), 180, 360, fill=mix("magma", "cloud", 0.3))
    p.d.arc((212, 190, 812, 410), 180, 360, fill=INK, width=W)
    p.sparkle(860, 170, 60, GOLD)


def i_butterfly(p):
    for dx in (-1, 1):
        p.ell(512 + dx * 200, 380, 200, 220, fill=PINK)
        p.ell(512 + dx * 170, 700, 140, 160, fill=GOLD)
        p.ell(512 + dx * 220, 360, 70, fill=WHITE, w=10)
        p.ell(512 + dx * 170, 720, 50, fill=ORANGE, w=10)
    p.rect(470, 280, 554, 860, r=40, fill=DARK)
    p.ell(512, 240, 70, fill=DARK)
    p.fat([(490, 190), (420, 80)], DARK, 10)
    p.fat([(534, 190), (604, 80)], DARK, 10)
    p.ell(420, 80, 24, fill=DARK, w=0)
    p.ell(604, 80, 24, fill=DARK, w=0)


def i_hiccups(p):
    p.poly([(300, 340), (724, 340), (660, 900), (364, 900)], col("cloud", 230))
    p.d.polygon([(318, 440), (706, 440), (660 - 6, 900 - W), (364 + 6, 900 - W)], fill=ORANGE)
    p.poly([(300, 340), (724, 340), (660, 900), (364, 900)], None)
    for cx, cy, r in ((430, 700, 30), (560, 600, 40), (470, 520, 24), (600, 800, 26)):
        p.ell(cx, cy, r, fill=WHITE, w=8)
    for cx, cy, r in ((560, 230, 70), (700, 130, 50), (420, 170, 40)):
        p.ell(cx, cy, r, fill=AQUA)
        p.shine(cx - r * 0.35, cy - r * 0.35, r * 0.25, r * 0.18, 220)
    p.fat([(640, 360), (760, 160)], PINK, 24)


# --- disc, outline, compose -------------------------------------------------------------------

DISC = {"normal": ("sky2", "sky1"), "strong": ("magma", "jeff_yellow"), "joke": ("comb", "clay"), "curse": ("sky5", "sky4")}


def disc(kind):
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c0, c1 = DISC[kind]
    r = 480
    for i in range(40):   # soft radial light from the top left
        t = i / 39
        rr = r * (1 - t * 0.75)
        cx, cy = 512 - 90 * t, 512 - 110 * t
        d.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), fill=mix(c0, c1, t * 0.8))
    if kind == "strong":
        for i in range(16):
            a0 = math.radians(i * 22.5)
            a1 = math.radians(i * 22.5 + 10)
            d.polygon([(512, 512), (512 + 700 * math.cos(a0), 512 + 700 * math.sin(a0)),
                       (512 + 700 * math.cos(a1), 512 + 700 * math.sin(a1))], fill=col("jeff_yellow", 150))
    if kind == "joke":
        rnd = random.Random(2)
        for _ in range(30):
            x, y = rnd.uniform(60, 964), rnd.uniform(60, 964)
            rr = rnd.uniform(14, 30)
            d.ellipse((x - rr, y - rr, x + rr, y + rr), fill=col("cloud", 120))
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).ellipse((512 - r, 512 - r, 512 + r, 512 + r), fill=255)
    img.putalpha(ImageChops.multiply(img.getchannel("A"), mask))
    d = ImageDraw.Draw(img)
    d.ellipse((512 - r, 512 - r, 512 + r, 512 + r), outline=INK, width=20)
    if kind == "curse":
        p = Pen()
        p.img, p.d = img, d
        rnd = random.Random(11)
        for x, y, s in ((150, 200, 70), (870, 170, 60), (880, 860, 75), (130, 820, 55), (512, 70, 40), (950, 520, 40)):
            p.sparkle(x, y, s, GOLD if rnd.random() < 0.5 else WHITE)
    return img


def sticker(obj):
    a = obj.getchannel("A").point(lambda v: 255 if v > 40 else 0)
    # Dilate by OUTLINE px: blur the mask and keep anything the blur touched (MaxFilter is too slow).
    grown = a.filter(ImageFilter.BoxBlur(OUTLINE)).point(lambda v: 255 if v > 8 else 0)
    grown = grown.filter(ImageFilter.GaussianBlur(1.5))
    base = Image.new("RGBA", (S, S), INK)
    base.putalpha(grown)
    shadow = Image.new("RGBA", (S, S), (10, 10, 20, 90))
    shadow.putalpha(grown.point(lambda v: v * 90 // 255).filter(ImageFilter.GaussianBlur(6)))
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    out.alpha_composite(shadow, (12, 18))
    out.alpha_composite(base)
    out.alpha_composite(obj)
    return out


def make(uid, kind):
    p = Pen()
    globals()["i_" + uid](p)
    img = disc(kind)
    img.alpha_composite(sticker(p.img))
    if kind == "curse":   # a glint on top so the curse still sparkles over the object
        q = Pen()
        q.img, q.d = img, ImageDraw.Draw(img)
        q.sparkle(760, 300, 60, WHITE)
    img = img.resize((512, 512), Image.LANCZOS)
    img.save(os.path.join(ROOT, uid + ".png"))


def main():
    want = set(sys.argv[1:])
    for row in UPGRADES:
        if not want or row[0] in want:
            make(row[0], row[2])
    print("drew", len(want) or len(UPGRADES), "icons")


if __name__ == "__main__":
    main()
