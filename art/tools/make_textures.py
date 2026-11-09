"""Ball face atlas and the tier-burst star. Pillow only, drawn at 2x and downsampled.

    python3 art/tools/make_textures.py      # writes assets/sprites/ball_faces.png, star.png
"""
import math, os
from PIL import Image, ImageDraw

INK = (10, 10, 20, 255)          # palette ink, Midnight Ink #0A0A14
WHITE = (255, 255, 255, 255)
BLUSH = (255, 140, 170, 150)
MOUTH = (120, 30, 50, 255)
TONGUE = (255, 110, 130, 255)
S = 2  # supersample
CELL = 512 * S
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "sprites")


def ell(d, cx, cy, rx, ry, fill, outline=None, width=0):
    d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=fill, outline=outline, width=width)


def eye(d, cx, cy, r, look=(0, 0)):
    ell(d, cx, cy, r * 0.8, r, INK)
    ell(d, cx - r * 0.25 + look[0], cy - r * 0.4 + look[1], r * 0.28, r * 0.3, WHITE)
    ell(d, cx + r * 0.25 + look[0], cy + r * 0.25 + look[1], r * 0.12, r * 0.12, WHITE)


def arc_line(d, cx, cy, rx, ry, a0, a1, w, col=INK):
    pts = [(cx + rx * math.cos(math.radians(a)), cy + ry * math.sin(math.radians(a)))
           for a in range(a0, a1 + 1, 3)]
    d.line(pts, fill=col, width=w, joint="curve")
    for p in (pts[0], pts[-1]):
        ell(d, p[0], p[1], w / 2, w / 2, col)


def calm(d, ox):
    c = CELL / 2
    for sx in (-1, 1):
        eye(d, ox + c + sx * 110 * S, c - 20 * S, 52 * S)
        ell(d, ox + c + sx * 175 * S, c + 70 * S, 48 * S, 26 * S, BLUSH)
    arc_line(d, ox + c, c + 55 * S, 70 * S, 45 * S, 20, 160, 18 * S)


def shocked(d, ox):
    c = CELL / 2
    for sx in (-1, 1):
        ell(d, ox + c + sx * 115 * S, c - 30 * S, 82 * S, 92 * S, WHITE, INK, 12 * S)
        ell(d, ox + c + sx * 115 * S, c - 25 * S, 30 * S, 34 * S, INK)
        ell(d, ox + c + sx * 105 * S, c - 38 * S, 10 * S, 10 * S, WHITE)
        arc_line(d, ox + c + sx * 120 * S, c - 120 * S, 70 * S, 40 * S, 200, 340, 16 * S)
    ell(d, ox + c, c + 125 * S, 52 * S, 66 * S, MOUTH, INK, 12 * S)


def happy(d, ox):
    c = CELL / 2
    for sx in (-1, 1):
        arc_line(d, ox + c + sx * 110 * S, c - 5 * S, 58 * S, 58 * S, 200, 340, 22 * S)
        ell(d, ox + c + sx * 180 * S, c + 70 * S, 50 * S, 28 * S, BLUSH)
    # big open D grin
    d.chord([ox + c - 120 * S, c - 20 * S, ox + c + 120 * S, c + 200 * S], 0, 180, fill=MOUTH, outline=INK, width=12 * S)
    d.chord([ox + c - 60 * S, c + 110 * S, ox + c + 60 * S, c + 210 * S], 180, 360, fill=TONGUE)
    d.rectangle([ox + c - 95 * S, c + 88 * S, ox + c + 95 * S, c + 112 * S], fill=WHITE)


def faces():
    im = Image.new("RGBA", (CELL * 3, CELL), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for i, f in enumerate((calm, shocked, happy)):
        f(d, i * CELL)
    im.resize((512 * 3, 512), Image.LANCZOS).save(os.path.join(OUT, "ball_faces.png"))


def star():
    n = 256 * S
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = n / 2
    def pts(r_out, r_in):
        out = []
        for k in range(10):
            r = r_out if k % 2 == 0 else r_in
            a = -math.pi / 2 + k * math.pi / 5
            out.append((c + r * math.cos(a), c + r * math.sin(a)))
        return out
    d.polygon(pts(c * 0.96, c * 0.45), fill=(255, 159, 46, 255))      # Neon Orange #FF9F2E
    d.polygon(pts(c * 0.78, c * 0.36), fill=(255, 216, 77, 255))      # Costume Yellow #FFD84D
    ell(d, c - c * 0.12, c - c * 0.15, c * 0.12, c * 0.09, (255, 255, 230, 255))
    im.resize((256, 256), Image.LANCZOS).save(os.path.join(OUT, "star.png"))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    faces()
    star()
    print("ok")
