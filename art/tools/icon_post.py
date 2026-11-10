#!/usr/bin/env python3
"""Finish the raw icon renders: fit, ink outline, drop shadow, 512x512.

  python3 art/tools/icon_post.py RAW_DIR OUT_DIR [--only a,b]
  python3 art/tools/icon_post.py --sheet OUT_DIR SHEET_PREFIX      (contact sheets of 12, to check the family)

Every icon gets the same treatment so the 44 read as one set: the render is cropped to its silhouette and scaled
to fill the same box, a round Midnight Ink outline is grown from the alpha, and a soft shadow sits under it.
Works at 2x and scales down, so the outline is smooth.
"""
import math, os, sys
from PIL import Image, ImageChops, ImageDraw, ImageFilter

OUT = 512
S = 2                      # supersample
FILL = 428                 # the silhouette's longest side, in final pixels
OUTLINE = 7                # ink width, final pixels
INK = (10, 10, 20)         # palette: Midnight Ink
LIFT = 10                  # the object sits this much above centre, leaving room for the shadow


def grow(mask, r):
    """Round dilation: the lighter of the mask shifted round a circle (and a half circle, to fill)."""
    out = mask.copy()
    for rad, n in ((r, 32), (r * 0.5, 12)):
        for i in range(n):
            a = 2 * math.pi * i / n
            out = ImageChops.lighter(out, ImageChops.offset(mask, round(rad * math.cos(a)), round(rad * math.sin(a))))
    return out


def finish(src, dst):
    raw = Image.open(src).convert("RGBA")
    box = raw.getchannel("A").point(lambda a: 255 if a > 10 else 0).getbbox()
    raw = raw.crop(box)
    k = FILL * S / max(raw.size)
    raw = raw.resize((max(1, round(raw.width * k)), max(1, round(raw.height * k))), Image.LANCZOS)
    n = OUT * S
    x, y = (n - raw.width) // 2, (n - raw.height) // 2 - LIFT * S
    y = max(OUTLINE * S + 4, min(y, n - raw.height - (OUTLINE + 22) * S))
    art = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    art.paste(raw, (x, y))
    alpha = art.getchannel("A")

    ink = grow(alpha.point(lambda a: 255 if a > 96 else 0), OUTLINE * S).filter(ImageFilter.GaussianBlur(S * 0.6))
    shadow = Image.new("L", (n, n), 0)
    w, base = raw.width * 0.42, y + raw.height
    ImageDraw.Draw(shadow).ellipse((n / 2 - w, base - 9 * S, n / 2 + w, base + 19 * S), fill=110)
    shadow = shadow.filter(ImageFilter.GaussianBlur(7 * S))

    out = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    out = Image.alpha_composite(out, Image.merge("RGBA", [Image.new("L", (n, n), c) for c in INK] + [shadow]))
    out = Image.alpha_composite(out, Image.merge("RGBA", [Image.new("L", (n, n), c) for c in INK] + [ink]))
    out = Image.alpha_composite(out, art)
    out.resize((OUT, OUT), Image.LANCZOS).save(dst, optimize=True)


def sheet(icons, prefix, bg=(238, 248, 255), cell=320, cols=4, per=12):
    names = sorted(f for f in os.listdir(icons) if f.endswith(".png"))
    for page in range(0, len(names), per):
        chunk = names[page:page + per]
        rows = math.ceil(len(chunk) / cols)
        im = Image.new("RGB", (cols * cell, rows * cell), bg)
        for i, f in enumerate(chunk):
            ic = Image.open(os.path.join(icons, f)).convert("RGBA").resize((cell - 24, cell - 24), Image.LANCZOS)
            im.paste(ic, (i % cols * cell + 12, i // cols * cell + 12), ic)
        im.save("%s%d.png" % (prefix, page // per + 1))


def main():
    a = sys.argv[1:]
    if a and a[0] == "--sheet":
        return sheet(a[1], a[2])
    only = a[a.index("--only") + 1].split(",") if "--only" in a else None
    os.makedirs(a[1], exist_ok=True)
    for f in sorted(os.listdir(a[0])):
        if f.endswith(".png") and (not only or f[:-4] in only):
            finish(os.path.join(a[0], f), os.path.join(a[1], f))


main()
