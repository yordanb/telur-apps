"""Generate launcher icons untuk aplikasi "Endog".

Usage:
    python generate_icon.py

Output (PNG 1024x1024):
    endog_icon.png           - icon legacy (gradasi oranye + telur)
    endog_fg.png             - foreground adaptive icon (telur, transparan)
    endog_bg.png             - background adaptive icon (gradasi oranye)

Icon dipakai oleh flutter_launcher_icons (lihat pubspec.yaml).
"""
import random
from PIL import Image, ImageDraw, ImageFilter

OUT = 1024
SS = 2                      # supersampling factor (render 2x, turun ke 1024)
TOP = (255, 183, 77)        # #FFB74D - gradasi atas (match tema oranye)
BOT = (239, 108, 0)         # #EF6C00 - gradasi bawah


def vgrad(size, top, bot):
    img = Image.new("RGB", (size, size))
    d = ImageDraw.Draw(img)
    for y in range(size):
        f = y / (size - 1)
        c = tuple(int(round(top[i] + (bot[i] - top[i]) * f)) for i in range(3))
        d.line([(0, y), (size, y)], fill=c)
    return img


def bbox_for(size, h_frac, cy_frac):
    """Kotak lingkaran dasar yang nanti di-squeeze jadi telur."""
    h = int(size * h_frac)
    w = int(h * 0.74)
    cy = int(size * cy_frac)
    cx = size // 2
    return (cx - w // 2, cy - h // 2, cx + w // 2, cy + h // 2)


def egg_mask(size, bbox):
    """Lingkaran yang di-squeeze horizontal makin ke atas -> bentuk telur."""
    base = Image.new("L", (size, size), 0)
    ImageDraw.Draw(base).ellipse(bbox, fill=255)
    out = Image.new("L", (size, size), 0)
    _x0, y0, _x1, y1 = bbox
    for y in range(y0, y1 + 1):
        t = (y - y0) / (y1 - y0)
        s = 0.58 + 0.42 * (t ** 1.5)          # atas 58% lebar, bawah 100%
        row = base.crop((0, y, size, y + 1))
        w = max(1, int(size * s))
        out.paste(row.resize((w, 1), Image.LANCZOS), ((size - w) // 2, y))
    return out


def egg_layer(size, bbox, mask):
    body = vgrad(size, (255, 254, 250), (253, 241, 219)).convert("RGBA")

    # bintik-bintik telur
    sp = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(sp)
    rnd = random.Random(7)
    x0, y0, x1, y1 = bbox
    placed = 0
    while placed < 30:
        x = rnd.randint(x0, x1)
        y = rnd.randint(y0, y1)
        if mask.getpixel((x, y)) > 220:
            r = rnd.randint(max(4, size // 220), max(8, size // 90))
            d.ellipse([x - r, y - r, x + r, y + r],
                      fill=(226, 190, 145, rnd.randint(150, 230)))
            placed += 1
    egg = Image.alpha_composite(body, sp)

    # highlight lembut kiri-atas
    hl = Image.new("L", (size, size), 0)
    ImageDraw.Draw(hl).ellipse(
        [int(size * 0.30), int(size * 0.22),
         int(size * 0.55), int(size * 0.46)], fill=70)
    hl = hl.filter(ImageFilter.GaussianBlur(size // 40))
    white = Image.new("RGBA", (size, size), (255, 255, 255, 255))
    white.putalpha(hl)
    egg = Image.alpha_composite(egg, white)

    egg.putalpha(mask)
    return egg


def build_legacy(size):
    bg = vgrad(size, TOP, BOT).convert("RGBA")
    bbox = bbox_for(size, 0.66, 0.55)
    mask = egg_mask(size, bbox)

    # bayangan lembut di bawah telur
    sh = Image.new("L", (size, size), 0)
    w = bbox[2] - bbox[0]
    h = bbox[3] - bbox[1]
    cx = size // 2
    ImageDraw.Draw(sh).ellipse(
        [cx - int(w * 0.55), bbox[3] - int(h * 0.10),
         cx + int(w * 0.55), bbox[3] + int(h * 0.14)], fill=110)
    sh = sh.filter(ImageFilter.GaussianBlur(size // 60))
    dark = Image.new("RGBA", (size, size), (150, 62, 0, 255))
    dark.putalpha(sh)
    bg = Image.alpha_composite(bg, dark)

    return Image.alpha_composite(bg, egg_layer(size, bbox, mask))


def build_fg(size):
    """Foreground adaptive icon: telur di area aman tengah (66%), transparan."""
    bbox = bbox_for(size, 0.54, 0.50)
    mask = egg_mask(size, bbox)
    return egg_layer(size, bbox, mask)


def main():
    big = OUT * SS
    outputs = {
        "endog_icon.png": build_legacy(big),
        "endog_fg.png": build_fg(big),
        "endog_bg.png": vgrad(big, TOP, BOT).convert("RGBA"),
    }
    for name, img in outputs.items():
        img = img.resize((OUT, OUT), Image.LANCZOS)
        img.convert("RGBA").save(name, "PNG")
        print(f"OK  {name}  {img.size}")


if __name__ == "__main__":
    main()
