#!/usr/bin/env python3
"""Deterministic PBR texture sets for the mid-to-high poly salvage redo (original art).
Writes tools/salvage_pbr/out/<set>_{base,orm,normal}.png (ORM: R=AO 1, G=roughness, B=metallic)
and <label>_label_{base,orm,normal}.png decals with printed text. Run: python3 make_textures.py
Normal maps are OpenGL (+Y up), as glTF expects."""
import os, math
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
os.makedirs(OUT, exist_ok=True)
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
MONO = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf"

def rng(seed): return np.random.default_rng(seed)

def value_noise(n, cells, seed):
    """Tileable smooth noise in [0,1]."""
    r = rng(seed); g = r.random((cells, cells))
    x = np.linspace(0, cells, n, endpoint=False)
    i0 = np.floor(x).astype(int); f = x - i0; f = f * f * (3 - 2 * f); i1 = (i0 + 1) % cells
    a = g[np.ix_(i0, i0)]; b = g[np.ix_(i0, i1)]; c = g[np.ix_(i1, i0)]; d = g[np.ix_(i1, i1)]
    fx = f[None, :]; fy = f[:, None]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy

def fbm(n, seed, octaves=5, base=4):
    t = np.zeros((n, n)); amp = 1.0; s = 0.0
    for o in range(octaves):
        t += amp * value_noise(n, base * 2 ** o, seed + o); s += amp; amp *= 0.5
    return t / s

def scratches(n, count, seed, length=(0.03, 0.25), width=(1, 3), angle=None):
    """White-on-black scratch mask (tileable by wrapping)."""
    img = Image.new("L", (n * 3, n * 3), 0); d = ImageDraw.Draw(img); r = rng(seed)
    for _ in range(count):
        x, y = r.random() * n + n, r.random() * n + n
        a = r.random() * math.pi if angle is None else angle + r.normal(0, 0.25)
        L = r.uniform(*length) * n
        pts = [(x, y)]
        for k in range(6):
            a += r.normal(0, 0.08); x += math.cos(a) * L / 6; y += math.sin(a) * L / 6; pts.append((x, y))
        d.line(pts, fill=int(r.uniform(120, 255)), width=int(r.integers(width[0], width[1] + 1)))
    big = np.asarray(img, dtype=np.float32) / 255.0
    m = np.zeros((n, n), np.float32)
    for i in range(3):
        for j in range(3): m = np.maximum(m, big[i * n:(i + 1) * n, j * n:(j + 1) * n])
    return m

def normal_from_height(h, strength):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5 * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5 * strength
    nx, ny, nz = -dx, dy, np.ones_like(h)  # image rows go down; OpenGL +Y up
    l = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx / l, ny / l, nz / l], -1) * 0.5 + 0.5

def save(name, base, rough, metal, height, strength):
    n = base.shape[0]
    Image.fromarray((np.clip(base, 0, 1) * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, name + "_base.png"))
    orm = np.stack([np.ones((n, n)), np.clip(rough, 0, 1), np.clip(metal, 0, 1)], -1)
    Image.fromarray((orm * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, name + "_orm.png"))
    Image.fromarray((normal_from_height(height, strength) * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, name + "_normal.png"))
    print("TEX", name, n)

def srgb(hexcol):
    h = hexcol.lstrip("#"); return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])

def painted_metal(name, paint, seed, n=1024, wear=1.0, n_scr=150):
    """Powder-coated metal: paint with grime, chips and scratches showing bare steel."""
    grime = fbm(n, seed, 6, 3); fine = fbm(n, seed + 50, 4, 64)
    scr = scratches(n, int(n_scr * wear), seed + 7, width=(1, 2))
    chips = (fbm(n, seed + 90, 5, 16) > 0.80 - 0.03 * wear).astype(np.float32)
    chips = np.asarray(Image.fromarray((chips * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2)), np.float32) / 255
    bare = np.clip(scr * 0.9 + chips, 0, 1)
    p = srgb(paint)[None, None, :] * (0.82 + 0.25 * grime[..., None]) * (0.94 + 0.08 * fine[..., None])
    steel = srgb("#8a8d8f")[None, None, :] * (0.8 + 0.2 * fine[..., None])
    base = p * (1 - bare[..., None]) + steel * bare[..., None]
    base *= (1 - 0.25 * np.clip(fbm(n, seed + 3, 4, 2) - 0.55, 0, 1)[..., None] * 2)  # dirt patches
    rough = 0.62 + 0.18 * grime - 0.30 * bare + 0.05 * fine
    metal = 0.05 + 0.9 * bare
    height = 0.6 * fine - 1.4 * scr - 0.8 * chips
    save(name, base, rough, metal, height, 2.2)

def brushed_steel(name, tint, seed, n=512):
    r = rng(seed); lines = r.random((n, 1)) * np.ones((1, n))
    lines = np.asarray(Image.fromarray((lines * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6)), np.float32) / 255
    fine = fbm(n, seed + 1, 4, 32); scr = scratches(n, 90, seed + 2, width=(1, 1))
    base = srgb(tint)[None, None, :] * (0.78 + 0.18 * lines[..., None] + 0.08 * fine[..., None])
    rough = 0.30 + 0.12 * lines + 0.18 * scr
    metal = np.full((n, n), 0.95)
    save(name, base, rough, metal, 0.5 * lines - 0.8 * scr, 1.6)

def rubber(name, col, seed, n=512):
    fine = fbm(n, seed, 5, 48); scuff = scratches(n, 60, seed + 4, length=(0.02, 0.08), width=(2, 4))
    base = srgb(col)[None, None, :] * (0.85 + 0.2 * fine[..., None]) + 0.10 * scuff[..., None]
    save(name, base, 0.82 + 0.1 * fine - 0.15 * scuff, np.zeros((n, n)), 1.2 * fine - 0.6 * scuff, 3.0)

def plastic(name, col, seed, n=1024):
    grime = fbm(n, seed, 6, 3); fine = fbm(n, seed + 9, 4, 80)
    streak = np.clip(fbm(n, seed + 20, 4, 6) * np.linspace(0.4, 1.2, n)[:, None], 0, 1)  # rain streaks downwards
    scr = scratches(n, 120, seed + 5, width=(1, 2))
    base = srgb(col)[None, None, :] * (0.88 + 0.12 * fine[..., None]) - 0.22 * np.clip(streak - 0.45, 0, 1)[..., None] * srgb("#6a5c40")[None, None, :]
    base = base - 0.06 * scr[..., None]
    save(name, base, 0.42 + 0.25 * grime + 0.2 * scr, np.zeros((n, n)), 0.4 * fine - 0.9 * scr, 1.8)

def label(name, lines, paper, ink, accent, seed, w=1024, h=512, barcode=True, hazard=False):
    img = Image.new("RGB", (w, h), tuple(int(c * 255) for c in srgb(paper))); d = ImageDraw.Draw(img)
    a = tuple(int(c * 255) for c in srgb(accent)); k = tuple(int(c * 255) for c in srgb(ink))
    d.rectangle([0, 0, w, int(h * 0.22)], fill=a)
    f0 = ImageFont.truetype(FONT, int(h * 0.15)); f1 = ImageFont.truetype(FONT, int(h * 0.11)); f2 = ImageFont.truetype(MONO, int(h * 0.075))
    d.text((int(w * 0.04), int(h * 0.025)), lines[0], font=f0, fill=tuple(int(c * 255) for c in srgb(paper)))
    y = int(h * 0.28)
    for i, t in enumerate(lines[1:]):
        f = f1 if i == 0 else f2
        d.text((int(w * 0.04), y), t, font=f, fill=k); y += int(f.size * 1.35)
    if barcode:
        r = rng(seed); x = int(w * 0.70)
        while x < int(w * 0.96):
            bw = int(r.integers(2, 7)); d.rectangle([x, int(h * 0.58), x + bw, int(h * 0.90)], fill=k); x += bw + int(r.integers(2, 6))
    if hazard:
        for i in range(-4, 20):
            x0 = int(w * 0.70) + i * 26
            d.polygon([(x0, int(h * 0.26)), (x0 + 13, int(h * 0.26)), (x0 + 13 - 40, int(h * 0.52)), (x0 - 40, int(h * 0.52))], fill=(220, 170, 40) if i % 2 else k)
        d.rectangle([0, 0, int(w * 0.70) - 2, h], outline=None)
    d.rectangle([4, 4, w - 5, h - 5], outline=k, width=4)
    base = np.asarray(img, np.float32) / 255.0
    n_s = scratches(max(w, h), 70, seed + 3, width=(1, 3))[:h, :w]
    dirt = fbm(max(w, h), seed + 8, 5, 4)[:h, :w]
    worn = np.clip(n_s + np.clip(dirt - 0.62, 0, 1) * 2.5, 0, 1)
    base = base * (1 - 0.45 * worn[..., None]) + 0.45 * worn[..., None] * srgb("#4a4a42")[None, None, :]
    base *= (0.9 + 0.1 * dirt[..., None])
    rough = 0.55 + 0.25 * dirt + 0.15 * n_s
    Image.fromarray((np.clip(base, 0, 1) * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, name + "_base.png"))
    orm = np.stack([np.ones((h, w)), np.clip(rough, 0, 1), np.zeros((h, w))], -1)
    Image.fromarray((orm * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, name + "_orm.png"))
    hh = np.zeros((max(w, h), max(w, h))); hh[:h, :w] = 0.3 * dirt - 0.7 * n_s
    Image.fromarray((normal_from_height(hh, 1.5)[:h, :w] * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, name + "_normal.png"))
    print("TEX", name, w, h)

if __name__ == "__main__":
    # Survey drive: olive-grey powder-coated alloy case, black rubber corner bumpers, steel hardware.
    painted_metal("drive_case", "#59614f", 101)
    rubber("drive_rubber", "#22231f", 102)
    brushed_steel("steel", "#b9bcbd", 103)
    brushed_steel("gold", "#c9a04a", 105)
    brushed_steel("dark_steel", "#4a4d50", 106)
    label("drive_label", ["SURVEY DRIVE", "SD-4  SEALED  2 TB", "RELAY RIDGE GEO-SURVEY", "S/N 0417-RR-2219", "DO NOT OPEN IN FIELD"],
          "#e4dcc2", "#1d1f1c", "#2f5d52", 104)
    # Research core: dark anodised shield casing, hazard label.
    painted_metal("core_case", "#2c3036", 201, wear=0.8)
    label("core_label", ["RESEARCH CORE", "RC-7  SHIELDED", "GLASSKILN LAB 3", "HANDLE BY FRAME ONLY"], "#e8e4d8", "#1c1c1c", "#8a2f24", 202, hazard=True)
    # Sensor: weathered cream polymer dome, painted mast collar.
    plastic("sensor_dome", "#e2ddcf", 301)
    painted_metal("sensor_collar", "#4b5560", 302, wear=1.1)
    label("sensor_label", ["SENSOR HEAD", "SH-2  WX / SEISMIC", "MAST 06  WEST RIDGE"], "#f0ece0", "#202020", "#c9822a", 303, barcode=True)
