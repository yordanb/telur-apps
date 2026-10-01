"""Proses gambar mockup (badge Endog buatan user) jadi icon launcher.

Input : Gemini_Generated_Image_snqjpcsnqjpcsnqj.jfif (badge oranye di atas latar krem)
Output: endog_gemini_icon.png   - icon legacy (badge di latar krem, full-bleed)
        endog_gemini_fg.png     - foreground adaptive (badge, transparan)
        endog_gemini_bg.png     - background adaptive (latar krem polos)

Tulisan kecil "RAMAH & TRADISIONAL" dihapus (ditimpa gradasi orange
sekelarnya); tulisan besar "ENDOG" dipertahankan.
"""
from PIL import Image

SRC = "Gemini_Generated_Image_snqjpcsnqjpcsnqj.jfif"
OUT = 1024

img = Image.open(SRC).convert("RGB")
w, h = img.size
px = img.load()


def whiteish(p):
    r, g, b = p
    return r > 185 and g > 178 and b > 165 and (max(p) - min(p)) < 70


# 1) Cari bounding box badge oranye (piksel jenuh)
minx, miny, maxx, maxy = w, h, 0, 0
for y in range(0, h, 2):
    for x in range(0, w, 2):
        r, g, b = px[x, y]
        if max(r, g, b) - min(r, g, b) > 55:
            minx, miny = min(minx, x), min(miny, y)
            maxx, maxy = max(maxx, x), max(maxy, y)
print(f"badge bbox: {(minx, miny, maxx, maxy)} dari {w}x{h}")

# 2) Deteksi pita-pita teks putih di INTERIOR badge (garis tepi badge juga
#    putih, jadi area deteksi dibatasi masuk 40px dari tepi) -> pita bawah = subtitle
ix0, ix1 = minx + 40, maxx - 40
bands = []
cur = None
for y in range(miny, maxy + 1):
    xs = [x for x in range(ix0, ix1 + 1) if whiteish(px[x, y])]
    if len(xs) > 4:
        if cur is None:
            cur = [y, y, xs[0], xs[-1]]
        else:
            cur[1] = y
            cur[2] = min(cur[2], xs[0])
            cur[3] = max(cur[3], xs[-1])
    else:
        if cur:
            bands.append(cur)
            cur = None
if cur:
    bands.append(cur)
print(f"pita teks putih: {bands}")

if not 2 <= len(bands) <= 8:
    raise SystemExit(
        f"ERROR: deteksi teks tidak masuk akal ({len(bands)} pita)")
# Pita tepi badge (garis putih atas/bawah) bukan teks - kecualikan.
# Subtitle = pita teks terakhir yang ada di tengah badge.
candidates = [b for b in bands if b[0] > miny + 60 and b[1] < maxy - 100]
if not candidates:
    raise SystemExit("ERROR: tidak ada pita subtitle terdeteksi")
sub = candidates[-1]                   # subtitle "RAMAH & TRADISIONAL"
if sub[1] - sub[0] > 90 or sub[3] - sub[2] > (ix1 - ix0):
    raise SystemExit(f"ERROR: pita subtitle tidak valid: {sub}")
print(f"subtitle dihapus: y {sub[0]}..{sub[1]}, x {sub[2]}..{sub[3]}")

# 3) Timpa subtitle: interpolasi horizontal per baris dari piksel bersih
#    di kiri & kanan teks -> gradasi orange mulus, jejak teks hilang.
work = img.copy()
wp = work.load()
py0 = max(miny, sub[0] - 5)
py1 = min(maxy, sub[1] + 5)
xa = max(ix0, sub[2] - 18)
xb = min(ix1, sub[3] + 18)
for y in range(py0, py1 + 1):
    left = px[xa - 6, y]
    right = px[xb + 6, y]
    span = (xb + 6) - (xa - 6)
    for x in range(xa, xb + 1):
        t = (x - (xa - 6)) / span
        wp[x, y] = tuple(
            int(round(left[i] + (right[i] - left[i]) * t)) for i in range(3))
print(f"subtitle ditimpa: y {py0}..{py1}, x {xa}..{xb}")

# 4) Warna latar krem = rata-rata 4 sudut asli
patches = []
for ox, oy in [(0, 0), (w - 32, 0), (0, h - 32), (w - 32, h - 32)]:
    for yy in range(oy, oy + 32, 4):
        for xx in range(ox, ox + 32, 4):
            patches.append(px[xx, yy])
beige = tuple(sum(c[i] for c in patches) // len(patches) for i in range(3))
print(f"latar krem: #{beige[0]:02X}{beige[1]:02X}{beige[2]:02X}")

# 5) Crop badge (tanpa subtitle), buat persegi, padding krem
badge = work.crop((minx, miny, maxx + 1, maxy + 1))
side = max(badge.size)
sq = Image.new("RGB", (side, side), beige)
sq.paste(badge, ((side - badge.size[0]) // 2, (side - badge.size[1]) // 2))

# 6) Legacy: badge besar di latar krem full-bleed
legacy = Image.new("RGB", (OUT, OUT), beige)
s = int(OUT * 0.88)
legacy.paste(sq.resize((s, s), Image.LANCZOS), ((OUT - s) // 2, (OUT - s) // 2))
legacy.convert("RGBA").save("endog_gemini_icon.png", "PNG")

# 7) Adaptive background: krem polos
Image.new("RGBA", (OUT, OUT), beige + (255,)).save(
    "endog_gemini_bg.png", "PNG")

# 8) Adaptive foreground: badge transparan, muat di area aman 66%
fg = Image.new("RGBA", (OUT, OUT), (0, 0, 0, 0))
s = int(OUT * 0.62)
fg.paste(sq.resize((s, s), Image.LANCZOS), ((OUT - s) // 2, (OUT - s) // 2))
fg.save("endog_gemini_fg.png", "PNG")

print("OK  endog_gemini_icon.png / endog_gemini_fg.png / endog_gemini_bg.png")
