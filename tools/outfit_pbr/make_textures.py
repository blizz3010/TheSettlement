#!/usr/bin/env python3
"""Default settler outfit PBR set (shirt, work pants, boots). Original art, deterministic.
Worn in the world, so EXTERNAL files next to the .gltf models, imported VRAM-compressed:
raid/assets/outfit/textures/outfit_<set>_{base,orm,normal}.jpg (ORM: R=AO, G=rough, B=metal;
OpenGL +Y normals). Helpers from tools/gear_parts_pbr/make_textures.py.
Run: python3 tools/outfit_pbr/make_textures.py"""
import os, sys
import numpy as np
from PIL import Image, ImageFilter
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "gear_parts_pbr"))
import make_textures as pf  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT = os.path.join(ROOT, "raid", "assets", "outfit", "textures")
os.makedirs(OUT, exist_ok=True)
fbm, scratches, srgb, rng = pf.fbm, pf.scratches, pf.srgb, pf.rng

def blur(a, r):
    return np.asarray(Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(r)), np.float32) / 255

def save(name, base, rough, metal, height, strength, ao=None, q=90):
    n0, n1 = base.shape[:2]
    if ao is None: ao = np.ones((n0, n1))
    Image.fromarray((np.clip(base, 0, 1) * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, name + "_base.jpg"), quality=q)
    orm = np.stack([np.clip(ao, 0, 1), np.clip(rough, 0, 1), np.clip(metal, 0, 1)], -1)
    Image.fromarray((orm * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, name + "_orm.jpg"), quality=q)
    Image.fromarray((pf.normal_from_height(height, strength) * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, name + "_normal.jpg"), quality=94)
    print("TEX", name, n0, n1)

def knit(name, col, seed, n=2048, rib=False):
    """Single jersey (V-shaped knit stitches in columns) or 2x2 rib; heathered yarn, pilling, fade."""
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    if rib:
        col_w = 10.0
        cols = np.sin(np.pi * x / col_w) ** 2
        loops = 0.75 + 0.25 * np.sin(np.pi * y / 5.0) ** 2
        h = cols * loops
    else:
        col_w, row_h = 6.0, 5.0
        cx = (x % col_w) / col_w; cy = (y % row_h) / row_h
        v = np.abs(cx - 0.5) * 2.0                       # 0 centre .. 1 edge
        leg = np.clip(1.0 - np.abs(v - (1.0 - cy)) * 3.0, 0, 1)   # the V of each loop
        h = 0.35 + 0.65 * leg
    r = rng(seed); heather = blur(r.random((n, n)), 0.8)
    fade = fbm(n, seed + 1, 6, 3); pill = np.clip(fbm(n, seed + 2, 4, 64) - 0.7, 0, 1) * 3
    wear = np.clip(fbm(n, seed + 3, 5, 6) - 0.6, 0, 1) * 1.8
    c = srgb(col)[None, None, :]
    base = c * (0.78 + 0.30 * h[..., None]) * (0.86 + 0.24 * heather[..., None]) * (0.9 + 0.18 * fade[..., None])
    base = base + 0.05 * pill[..., None] + 0.06 * wear[..., None]
    save(name, base, 0.86 + 0.06 * (1 - h) + 0.04 * pill, np.zeros((n, n)), h * 0.9 + 0.2 * heather + 0.2 * pill, 2.6, 0.80 + 0.2 * h)

def twill(name, col, seed, n=2048, period=12):
    """Cotton canvas 2/1 twill (diagonal wale), washed fade, knee/seat wear, dust."""
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    d = (x + y) % period / period
    wale = np.sin(np.pi * d) ** 1.4
    cross = 0.85 + 0.15 * np.sin(np.pi * (x - y) / 3.0) ** 2
    h = wale * cross
    r = rng(seed); slub = blur(r.random((n, n)), 1.2)
    fade = fbm(n, seed + 1, 6, 3); dust = fbm(n, seed + 2, 5, 6)
    wear = np.clip(fbm(n, seed + 3, 5, 5) - 0.58, 0, 1) * 2.0
    c = srgb(col)[None, None, :]
    # Weave contrast lives mostly in the normal map; a strong albedo wale moires at distance.
    base = c * (0.92 + 0.10 * h[..., None]) * (0.9 + 0.14 * slub[..., None]) * (0.86 + 0.22 * fade[..., None])
    base = base + 0.08 * wear[..., None] * srgb("#b8a888")[None, None, :] + 0.06 * np.clip(dust - 0.55, 0, 1)[..., None]
    save(name, base, 0.82 + 0.08 * (1 - h) - 0.04 * wear, np.zeros((n, n)), h * 0.9 + 0.25 * slub, 2.4, 0.82 + 0.18 * h)

def leather(name, col, seed, n=2048):
    """Oiled work-boot leather: pebble grain, creases, scuffed lighter toe, darker oil patches."""
    r = rng(seed)
    grain = blur(r.random((n, n)), 2.2); grain = (grain - grain.min()) / (np.ptp(grain) + 1e-6)
    fine = fbm(n, seed + 1, 4, 160)
    crease = scratches(n, 90, seed + 2, length=(0.04, 0.2), width=(1, 3)) * 0.7
    scuff = np.clip(fbm(n, seed + 3, 5, 7) - 0.56, 0, 1) * 2.2
    oil = np.clip(fbm(n, seed + 4, 5, 3) - 0.5, 0, 1) * 1.5
    c = srgb(col)[None, None, :]
    base = c * (0.82 + 0.26 * grain[..., None]) * (1 - 0.25 * oil[..., None]) + 0.10 * scuff[..., None] * srgb("#c9a07a")[None, None, :]
    base = base - 0.05 * crease[..., None]
    save(name, base, 0.52 + 0.18 * grain + 0.18 * scuff - 0.14 * oil, np.zeros((n, n)), 0.7 * grain + 0.15 * fine - 0.8 * crease, 2.2)

def rubber(name, col, seed, n=1024):
    """Vulcanised sole rubber with a lug tread (for the sole bottom/sides via world UVs)."""
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    lug = ((np.sin(x * np.pi / 40) > 0.2) ^ (np.sin(y * np.pi / 40 + 1.2) > 0.2)).astype(np.float32)
    lug = blur(lug, 2.0)
    dirt = fbm(n, seed, 5, 4); r = rng(seed); spk = blur(r.random((n, n)), 0.7)
    base = srgb(col)[None, None, :] * (0.8 + 0.25 * spk[..., None]) + 0.10 * np.clip(dirt - 0.5, 0, 1)[..., None] * srgb("#7a6a52")[None, None, :]
    save(name, base, 0.86 + 0.08 * spk, np.zeros((n, n)), 0.6 * lug + 0.3 * spk, 2.0, 0.75 + 0.25 * lug)

def cord(name, col, seed, n=512):
    """Braided lace / thread cord: diagonal braid along V."""
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    braid = np.sin(np.pi * ((x * 0.5 + y) % 16) / 16) ** 2 * 0.6 + np.sin(np.pi * ((y - x * 0.5) % 16) / 16) ** 2 * 0.4
    fine = fbm(n, seed, 4, 32)
    base = srgb(col)[None, None, :] * (0.72 + 0.36 * braid[..., None]) * (0.9 + 0.15 * fine[..., None])
    save(name, base, 0.85 + 0.08 * fine, np.zeros((n, n)), braid, 2.0, 0.8 + 0.2 * braid)

def brass(name, col, seed, n=512):
    """Aged brass hardware (eyelets, buttons, buckle): patina in recesses, bright worn highs."""
    r = rng(seed); spk = blur(r.random((n, n)), 0.8); pat = fbm(n, seed + 1, 5, 6)
    wear = scratches(n, 40, seed + 2, length=(0.02, 0.1), width=(1, 2)) * 0.6
    c = srgb(col)[None, None, :]
    base = c * (0.75 + 0.3 * spk[..., None]) * (1 - 0.35 * np.clip(pat - 0.5, 0, 1)[..., None] * 2) + 0.15 * wear[..., None]
    save(name, base, 0.42 + 0.2 * pat - 0.2 * wear, np.full((n, n), 0.9), 0.4 * spk - 0.5 * wear, 1.4)

if __name__ == "__main__":
    knit("outfit_knit", "#4a5661", 501)            # slate blue-grey jersey shirt (reads as cloth, not skin)
    knit("outfit_rib", "#363f47", 502, n=1024, rib=True)   # darker slate rib collar/cuffs
    twill("outfit_twill", "#545037", 503)          # washed olive-brown work canvas
    leather("outfit_leather", "#5b3b27", 504)      # oiled brown leather
    leather("outfit_belt", "#3d2a1e", 505, n=1024)
    rubber("outfit_rubber", "#2b2826", 506)
    cord("outfit_cord", "#9a7f58", 507)            # tan laces / contrast thread
    brass("outfit_brass", "#9b7b45", 508)
