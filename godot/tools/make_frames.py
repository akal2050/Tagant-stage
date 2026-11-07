"""TAGANT Animal Karaoke - sigil frame textures for the interface (9-slice PNGs).
Three families, all in the stage palette (oil black fill, salt-white lines, poppy-red sigils):
  heptagram  - double hairline frame, {7/3} heptagram sigils in the corners (the 5/7 system)
  arabesque  - single line + dotted inner line, a small vine scroll curling from each corner
  signal     - chamfered corners, instrument ticks, red index marks
Each family: panel.png, button.png, button_hover.png, button_pressed.png  (104x104, slice margin 32 px)
Usage: python make_frames.py <out folder>
"""
import sys, os, math
from PIL import Image, ImageDraw

S = 128          # texture size
SS = 4           # supersampling
M = 40           # 9-slice margin at 128 px
OUT = 104        # saved size: 9-slice margin = 32 px on screen
SALT = (244, 241, 232)
RED = (205, 40, 22)
FILL = (8, 4, 5)


def heptagram(d, cx, cy, r, col, w):
    pts = [(cx + r * math.sin(2 * math.pi * k / 7), cy - r * math.cos(2 * math.pi * k / 7)) for k in range(7)]
    order = [(k * 3) % 7 for k in range(8)]
    d.line([pts[i] for i in order], fill=col, width=w, joint="curve")
    d.ellipse([cx - r * 1.18, cy - r * 1.18, cx + r * 1.18, cy + r * 1.18], outline=col, width=max(1, w // 2))


def scroll(d, cx, cy, r, a0, sign, col, w):
    # logarithmic vine curl
    pts = []
    for i in range(60):
        t = i / 59.0
        ang = a0 + sign * t * 4.2
        rr = r * (1.0 - 0.82 * t)
        pts.append((cx + rr * math.cos(ang), cy + rr * math.sin(ang)))
    d.line(pts, fill=col, width=w, joint="curve")
    lx, ly = pts[-1]
    d.ellipse([lx - w * 1.6, ly - w * 1.6, lx + w * 1.6, ly + w * 1.6], fill=RED + (255,))


def frame(style, state):
    W = S * SS
    im = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    a_line = {"normal": 150, "hover": 235, "pressed": 255, "panel": 120}[state]
    fill_a = {"normal": 180, "hover": 200, "pressed": 235, "panel": 190}[state]
    fill = (150, 22, 14) if state == "pressed" else FILL
    line = SALT + (a_line,)
    red = RED + (255 if state != "panel" else 220,)
    m = 10 * SS
    if style == "mix":
        # signal chamfer + arabesque scrolls in two corners + instrument ticks, a single red index
        c = 16 * SS
        poly = [(m + c, m), (W - m - c, m), (W - m, m + c), (W - m, W - m - c), (W - m - c, W - m), (m + c, W - m), (m, W - m - c), (m, m + c)]
        d.polygon(poly, fill=fill + (fill_a,))
        d.line(poly + [poly[0]], fill=line, width=2 * SS)
        r = 13 * SS
        for (x, y, ix, iy, sg) in [(m + c * 0.5, m + c * 0.5, 1, 1, 1), (W - m - c * 0.5, W - m - c * 0.5, -1, -1, 1)]:
            scroll(d, x + ix * r * 0.55, y + iy * r * 0.55, r * 0.75, math.atan2(-iy, -ix), sg, line, 2 * SS)
        d.line([(W - m - c - 20 * SS, m), (W - m - c, m)], fill=red, width=4 * SS)
        for k in range(4):
            o = m + c + (k + 1) * 4 * SS
            d.line([(o, W - m - 1 * SS), (o, W - m - 5 * SS)], fill=line, width=1 * SS)
    elif style == "signal":
        c = 18 * SS
        poly = [(m + c, m), (W - m - c, m), (W - m, m + c), (W - m, W - m - c), (W - m - c, W - m), (m + c, W - m), (m, W - m - c), (m, m + c)]
        d.polygon(poly, fill=fill + (fill_a,))
        d.line(poly + [poly[0]], fill=line, width=2 * SS)
        for (x, y, dx, dy) in [(m + c, m, 1, 0), (W - m - c, W - m, -1, 0)]:
            d.line([(x, y), (x + dx * 22 * SS, y + dy * 22 * SS)], fill=red, width=5 * SS)
        for k in range(5):           # instrument ticks on the edges near the corners
            o = m + c + (k + 1) * 4 * SS
            d.line([(o, W - m - 1 * SS), (o, W - m - 5 * SS)], fill=line, width=1 * SS)
            d.line([(W - o, m + 1 * SS), (W - o, m + 5 * SS)], fill=line, width=1 * SS)
    else:
        d.rounded_rectangle([m, m, W - m, W - m], radius=4 * SS, fill=fill + (fill_a,))
        d.rounded_rectangle([m, m, W - m, W - m], radius=4 * SS, outline=line, width=2 * SS)
        if style == "heptagram":
            i = m + 5 * SS
            d.rounded_rectangle([i, i, W - i, W - i], radius=2 * SS, outline=SALT + (a_line // 2,), width=1 * SS)
            for (x, y) in [(m, m), (W - m, m), (W - m, W - m), (m, W - m)]:
                d.ellipse([x - 9 * SS, y - 9 * SS, x + 9 * SS, y + 9 * SS], fill=fill + (255,))
                heptagram(d, x, y, 7 * SS, red, 2 * SS)
        else:  # arabesque
            i = m + 5 * SS
            for t in range(i, W - i, 5 * SS):        # dotted inner line
                for (x, y) in [(t, i), (t, W - i), (i, t), (W - i, t)]:
                    d.ellipse([x - SS, y - SS, x + SS, y + SS], fill=SALT + (a_line // 2,))
            r = 16 * SS
            for (x, y, ix, iy, sg) in [(m, m, 1, 1, 1), (W - m, m, -1, 1, -1), (W - m, W - m, -1, -1, 1), (m, W - m, 1, -1, -1)]:
                cx, cy = x + ix * r * 0.95, y + iy * r * 0.95
                scroll(d, cx, cy, r * 0.9, math.atan2(-iy, -ix), sg, line, 2 * SS)
    return im.resize((OUT, OUT), Image.LANCZOS)


def main(out):
    for style in ["heptagram", "arabesque", "signal", "mix"]:
        os.makedirs(os.path.join(out, style), exist_ok=True)
        frame(style, "panel").save(os.path.join(out, style, "panel.png"))
        frame(style, "normal").save(os.path.join(out, style, "button.png"))
        frame(style, "hover").save(os.path.join(out, style, "button_hover.png"))
        frame(style, "pressed").save(os.path.join(out, style, "button_pressed.png"))
        print(style)
    icons(os.path.join(out, "icons"))


def icons(out):
    """Minimal line icons: thin chevrons for changing creature, glyphs for the non-numbered blocks."""
    os.makedirs(out, exist_ok=True)
    Z = 96 * SS
    def canvas():
        im = Image.new("RGBA", (Z, Z), (0, 0, 0, 0)); return im, ImageDraw.Draw(im)
    for name, sg in [("chevron_l", -1), ("chevron_r", 1)]:
        im, d = canvas()
        cx = Z / 2; h = 30 * SS; w = 13 * SS
        pts = [(cx - sg * w, Z / 2 - h), (cx + sg * w, Z / 2), (cx - sg * w, Z / 2 + h)]
        d.line(pts, fill=(0, 0, 0, 140), width=7 * SS, joint="curve")      # soft shadow for the sky
        d.line(pts, fill=SALT + (255,), width=3 * SS, joint="curve")
        d.ellipse([cx + sg * w - 3 * SS, Z / 2 - 3 * SS, cx + sg * w + 3 * SS, Z / 2 + 3 * SS], fill=RED + (255,))
        im.resize((48, 48), Image.LANCZOS).save(os.path.join(out, name + ".png"))
    im, d = canvas(); heptagram(d, Z / 2, Z / 2, 30 * SS, SALT + (255,), 3 * SS)
    im.resize((40, 40), Image.LANCZOS).save(os.path.join(out, "above.png"))
    im, d = canvas()
    for k in range(3):
        y = Z / 2 + (k - 1) * 18 * SS
        d.line([(Z / 2 + (t - 30) * SS, y + 6 * SS * math.sin(t / 5.0)) for t in range(0, 61)], fill=SALT + (255,), width=3 * SS)
    im.resize((40, 40), Image.LANCZOS).save(os.path.join(out, "frogs.png"))
    im, d = canvas()
    for i in range(3):
        for j in range(3):
            x = Z / 2 + (i - 1) * 20 * SS; y = Z / 2 + (j - 1) * 20 * SS; rr = (5 if (i + j) % 2 else 3) * SS
            d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=SALT + (255,))
    im.resize((40, 40), Image.LANCZOS).save(os.path.join(out, "cicadas.png"))


if __name__ == "__main__":
    main(sys.argv[1])
