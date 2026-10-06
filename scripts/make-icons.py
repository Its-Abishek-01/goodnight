"""Draws the GoodNight icon and Play Store graphics with Pillow.

    python scripts/make-icons.py

Writes the Android launcher icons (legacy PNGs plus an adaptive icon with a
themed/monochrome layer) and store/icon-512.png, store/feature-graphic.png.
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / 'android/app/src/main/res'
STORE = ROOT / 'store'

TOP = (42, 40, 110)      # indigo, close to the app's seed colour 0xFF3F3D8F
BOTTOM = (16, 15, 46)
MOON = (255, 224, 150)
STAR = (255, 243, 210)
SS = 4                   # supersampling for smooth edges

DENSITIES = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}


def gradient(w, h):
    img = Image.new('RGB', (w, h))
    px = img.load()
    for y in range(h):
        t = y / max(h - 1, 1)
        c = tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM))
        for x in range(w):
            px[x, y] = c
    return img


def star(draw, cx, cy, r, fill):
    """Four-pointed sparkle."""
    k = r * 0.28
    draw.polygon([(cx, cy - r), (cx + k, cy - k), (cx + r, cy), (cx + k, cy + k),
                  (cx, cy + r), (cx - k, cy + k), (cx - r, cy), (cx - k, cy - k)], fill=fill)


def emblem(size, moon=MOON, stars=STAR):
    """Moon and two stars on a transparent square, art inside the middle ~60%."""
    s = size * SS
    img = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    # Crescent: a disc minus an offset disc.
    mask = Image.new('L', (s, s), 0)
    d = ImageDraw.Draw(mask)
    r = s * 0.25
    cx, cy = s * 0.46, s * 0.52
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    off = r * 0.62
    d.ellipse([cx - r + off, cy - r - off * 0.55, cx + r + off, cy + r - off * 0.55], fill=0)
    img.paste(Image.new('RGBA', (s, s), moon + (255,)), (0, 0), mask)
    # Two stars: the two of you.
    d = ImageDraw.Draw(img)
    star(d, s * 0.68, s * 0.36, s * 0.075, stars + (255,))
    star(d, s * 0.76, s * 0.55, s * 0.045, stars + (255,))
    return img.resize((size, size), Image.LANCZOS)


def glow(art, radius):
    a = art.split()[3].filter(ImageFilter.GaussianBlur(radius))
    g = Image.new('RGBA', art.size, MOON + (0,))
    g.putalpha(a.point(lambda v: v * 0.35))
    return g


def full_icon(size, rounded):
    bg = gradient(size, size).convert('RGBA')
    art = emblem(size)
    bg.alpha_composite(glow(art, size * 0.04))
    bg.alpha_composite(art)
    if rounded:
        m = Image.new('L', (size * SS, size * SS), 0)
        ImageDraw.Draw(m).rounded_rectangle([0, 0, size * SS - 1, size * SS - 1],
                                            radius=size * SS * 0.22, fill=255)
        bg.putalpha(m.resize((size, size), Image.LANCZOS))
    return bg


def adaptive_foreground(px):
    # 108dp canvas; round masks keep a circle of 66dp. Shrink the emblem so
    # the small star stays inside that circle.
    inner = round(px * 0.88)
    out = Image.new('RGBA', (px, px), (0, 0, 0, 0))
    out.paste(emblem(inner), ((px - inner) // 2, (px - inner) // 2))
    return out


def write_android():
    for name, scale in DENSITIES.items():
        d = RES / f'mipmap-{name}'
        d.mkdir(parents=True, exist_ok=True)
        full_icon(round(48 * scale), rounded=True).save(d / 'ic_launcher.png')
        adaptive_foreground(round(108 * scale)).save(d / 'ic_launcher_foreground.png')
    anydpi = RES / 'mipmap-anydpi-v26'
    anydpi.mkdir(exist_ok=True)
    (anydpi / 'ic_launcher.xml').write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background" />\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
        '    <monochrome android:drawable="@mipmap/ic_launcher_foreground" />\n'
        '</adaptive-icon>\n', encoding='utf-8')
    (RES / 'values/ic_launcher_background.xml').write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        '    <color name="ic_launcher_background">#%02X%02X%02X</color>\n'
        '</resources>\n' % TOP, encoding='utf-8')


def font(size, bold=False):
    for name in (['segoeuib.ttf', 'arialbd.ttf', 'DejaVuSans-Bold.ttf'] if bold
                 else ['segoeui.ttf', 'arial.ttf', 'DejaVuSans.ttf']):
        for base in ('C:/Windows/Fonts', '/usr/share/fonts/truetype/dejavu', '/Library/Fonts'):
            p = Path(base) / name
            if p.exists():
                return ImageFont.truetype(str(p), size)
    return ImageFont.load_default()


def write_store():
    STORE.mkdir(exist_ok=True)
    full_icon(512, rounded=False).save(STORE / 'icon-512.png')

    w, h = 1024, 500
    img = gradient(w, h).convert('RGBA')
    art = emblem(420)
    layer = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    layer.paste(art, (40, 40), art)
    img.alpha_composite(glow(layer, 18))
    img.alpha_composite(layer)
    d = ImageDraw.Draw(img)
    d.text((470, 150), 'GoodNight', font=font(96, bold=True), fill=(255, 255, 255))
    d.text((474, 268), 'A sleep pact for two', font=font(44), fill=MOON)
    d.text((474, 330), 'Agree on bedtimes. Keep the streak.', font=font(30), fill=(200, 200, 230))
    img.convert('RGB').save(STORE / 'feature-graphic.png')


if __name__ == '__main__':
    write_android()
    write_store()
    print('Icons written to', RES, 'and', STORE)
