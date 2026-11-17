#!/usr/bin/env python3
"""Shared T3 ("dark ranger") PBR texture set for the gear art waves (E0 pilot: Warden Helm,
Bulwark Carrier). Original art, deterministic. Unlike the icon-only salvage/parts sets these
are worn in the world, so they ship as EXTERNAL files next to the .gltf models and import
VRAM-compressed (see the .import files): raid/assets/gear/t3/textures/t3_<set>_{base,orm,normal}.jpg
(ORM: R=AO, G=roughness, B=metallic; normal maps are OpenGL +Y, as glTF expects) plus the
t3_decals sheet. Helpers follow tools/gear_parts_pbr/make_textures.py (PR F).
Run: python3 tools/gear_art_pbr/make_textures.py"""
import os, sys, math
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "gear_parts_pbr"))
import make_textures as pf  # noqa: E402  (value_noise, fbm, scratches, normal_from_height, srgb)

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT = os.path.join(ROOT, "raid", "assets", "gear", "t3", "textures")
os.makedirs(OUT, exist_ok=True)
fbm, scratches, srgb, rng = pf.fbm, pf.scratches, pf.srgb, pf.rng

def blur(a, r):
    return np.asarray(Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(r)), np.float32) / 255

def save(name, base, rough, metal, height, strength, ao=None, q=92):
    n0, n1 = base.shape[:2]
    if ao is None: ao = np.ones((n0, n1))
    Image.fromarray((np.clip(base, 0, 1) * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, name + "_base.jpg"), quality=q)
    orm = np.stack([np.clip(ao, 0, 1), np.clip(rough, 0, 1), np.clip(metal, 0, 1)], -1)
    Image.fromarray((orm * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, name + "_orm.jpg"), quality=q)
    Image.fromarray((pf.normal_from_height(height, strength) * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, name + "_normal.jpg"), quality=95)
    print("TEX", name, n0, n1)

def cordura(name, col, seed, n=2048, period=6):
    """500D nylon plain weave (~1 mm tow at the 0.35 m repeat), fade, fuzz, dust and grime."""
    y, x = np.mgrid[0:n, 0:n]
    fx = (x % period) / period; fy = (y % period) / period
    over = ((x // period) + (y // period)) % 2 == 0
    pw = np.sin(np.pi * fx) ** 0.7; pf_ = np.sin(np.pi * fy) ** 0.7
    weave = np.where(over, pw, pf_)
    r = rng(seed); jitter = blur(r.random((n, n)), 0.7)
    fade = fbm(n, seed + 1, 6, 3); dust = fbm(n, seed + 2, 5, 6); fuzz = fbm(n, seed + 3, 4, 96)
    scuff = np.clip(fbm(n, seed + 4, 5, 8) - 0.62, 0, 1) * 2.6
    scr = scratches(n, 70, seed + 5, length=(0.01, 0.06), width=(1, 2))
    c = srgb(col)[None, None, :]
    base = c * (0.80 + 0.30 * weave[..., None]) * (0.90 + 0.14 * jitter[..., None])
    base = base * (0.86 + 0.22 * fade[..., None])
    base = base + 0.10 * np.clip(dust - 0.55, 0, 1)[..., None] * srgb("#8c8068")[None, None, :] * 2
    base = base + 0.07 * scuff[..., None] + 0.05 * scr[..., None] + 0.03 * fuzz[..., None]
    rough = 0.80 + 0.08 * (1 - weave) + 0.06 * dust - 0.05 * scuff
    ao = 0.82 + 0.18 * weave
    save(name, base, rough, np.zeros((n, n)), 0.9 * weave + 0.15 * jitter - 0.3 * scr, 2.4, ao)

def shell_paint(name, col, seed, n=2048):
    """Matte textured shell coating (grit), mottling, scuffs and chips into dark composite."""
    r = rng(seed); grit = blur(r.random((n, n)), 1.1)
    mott = fbm(n, seed + 1, 6, 4); fine = fbm(n, seed + 2, 4, 128)
    chips = (fbm(n, seed + 3, 5, 24) > 0.835).astype(np.float32); chips = blur(chips, 1.0) * 0.7
    scr = scratches(n, 55, seed + 4, length=(0.02, 0.12), width=(1, 1)) * 0.45
    scuff = np.clip(fbm(n, seed + 5, 5, 10) - 0.6, 0, 1) * 2.2
    bare = np.clip(chips + 0.8 * scr, 0, 1)
    paint = srgb(col)[None, None, :] * (0.86 + 0.18 * mott[..., None]) * (0.93 + 0.10 * grit[..., None])
    comp = srgb("#2b2d2c")[None, None, :] * (0.8 + 0.3 * fine[..., None])
    base = paint * (1 - bare[..., None]) + comp * bare[..., None] + 0.06 * scuff[..., None]
    rough = 0.70 + 0.10 * grit - 0.15 * scuff + 0.05 * bare
    save(name, base, rough, np.zeros((n, n)), 0.8 * grit + 0.2 * fine - 1.2 * bare, 2.0)

def polymer(name, col, seed, n=1024):
    """Glass-filled nylon hardware: stippled moulding, worn edges lighter, scuffs."""
    r = rng(seed); stip = blur(r.random((n, n)), 1.4)
    grime = fbm(n, seed + 1, 5, 4); scr = scratches(n, 35, seed + 2, length=(0.02, 0.1), width=(1, 1)) * 0.6
    base = srgb(col)[None, None, :] * (0.85 + 0.25 * stip[..., None]) + 0.10 * scr[..., None] - 0.03 * grime[..., None]
    save(name, base, 0.55 + 0.15 * stip + 0.1 * grime - 0.2 * scr, np.zeros((n, n)), 0.7 * stip - 0.6 * scr, 2.4)

def loop_fabric(name, col, seed, n=1024):
    """Hook-and-loop panel: dense loop pile (fuzzy, very rough), lint and wear."""
    r = rng(seed); pile = blur(r.random((n, n)), 0.9) * 0.6 + 0.4 * blur(r.random((n, n)), 2.5)
    lint = np.clip(fbm(n, seed + 1, 5, 12) - 0.62, 0, 1) * 2.5; flat = np.clip(fbm(n, seed + 2, 4, 5) - 0.58, 0, 1) * 2
    base = srgb(col)[None, None, :] * (0.7 + 0.5 * pile[..., None]) + 0.12 * lint[..., None] * srgb("#9a927c")[None, None, :]
    base = base * (1 - 0.15 * flat[..., None])
    save(name, base, 0.92 - 0.1 * flat, np.zeros((n, n)), pile - 0.5 * flat, 3.2, 0.75 + 0.25 * pile)

def webbing(name, col, seed, n=1024):
    """Mil-spec webbing: ribs ACROSS the strap (U), weave along it (V); edges darker."""
    y, x = np.mgrid[0:n, 0:n]
    rib = np.sin(x * np.pi / 4.0) ** 2 * 0.6 + np.sin(y * np.pi / 3.0) ** 2 * 0.4
    fine = fbm(n, seed, 5, 64); dirt = fbm(n, seed + 3, 4, 4)
    base = srgb(col)[None, None, :] * (0.72 + 0.32 * rib[..., None]) * (0.85 + 0.2 * fine[..., None])
    base *= (1 - 0.3 * np.clip(dirt - 0.55, 0, 1)[..., None] * 2)
    save(name, base, 0.80 + 0.1 * fine, np.zeros((n, n)), rib * 0.8 + 0.2 * fine, 2.2, 0.85 + 0.15 * rib)

def steel(name, col, seed, n=1024):
    """Parkerized (phosphate) steel: dark grey-green, fine crystalline speckle, worn bright edges."""
    r = rng(seed); spk = blur(r.random((n, n)), 0.6)
    wear = scratches(n, 45, seed + 1, length=(0.02, 0.1), width=(1, 2)) * 0.6; grime = fbm(n, seed + 2, 5, 4)
    base = srgb(col)[None, None, :] * (0.8 + 0.3 * spk[..., None]) * (1 - wear[..., None]) + srgb("#9a9c9c")[None, None, :] * wear[..., None]
    save(name, base, 0.62 + 0.12 * spk - 0.35 * wear + 0.06 * grime, 0.75 + 0.25 * wear, 0.5 * spk - 0.6 * wear, 1.6)

def decals(name, seed, w=1024, h=512):
    """One decal sheet for both pilots. Regions (UV, origin top-left in image space):
    A (0,0)-(1024,192): Bulwark name tape; B (0,192)-(512,512): Warden rear patch with
    reflective strip; C (512,192)-(1024,512): carrier size/care label."""
    img = Image.new("RGB", (w, h), (40, 44, 42)); d = ImageDraw.Draw(img)
    F = ImageFont.truetype(pf.FONT, 96); Fs = ImageFont.truetype(pf.FONT, 44); M = ImageFont.truetype(pf.MONO, 30)
    # A: embroidered tape, khaki thread on ranger green
    d.rectangle([0, 0, w - 1, 191], fill=(52, 58, 53)); d.rectangle([6, 6, w - 7, 185], outline=(120, 116, 92), width=6)
    d.text((48, 40), "BULWARK  T3", font=F, fill=(176, 168, 132))
    # B: rear patch: dark, reflective strip, name
    d.rectangle([0, 192, 511, h - 1], fill=(36, 40, 39)); d.rectangle([6, 198, 505, h - 7], outline=(90, 94, 88), width=5)
    d.rectangle([24, 214, 487, 290], fill=(196, 200, 196))
    d.text((40, 318), "WARDEN", font=F, fill=(160, 160, 146)); d.text((44, 440), "HELM  III  REAR", font=M, fill=(120, 122, 112))
    # C: care label, off-white printed
    d.rectangle([512, 192, w - 1, h - 1], fill=(206, 200, 184))
    d.text((540, 210), "BULWARK CARRIER", font=Fs, fill=(30, 32, 30))
    for i, t in enumerate(["SIZE  M/L   PLATE 25x32", "SHELL 500D NYLON", "WIPE CLEAN  NO BLEACH", "SETTLEMENT FIELD SUPPLY"]):
        d.text((540, 272 + i * 52), t, font=M, fill=(40, 42, 40))
    base = np.asarray(img, np.float32) / 255.0
    stitch = np.zeros((h, w), np.float32); stitch[:192, :] = (np.sin(np.mgrid[0:192, 0:w][1] * np.pi / 2.5) ** 2) * 0.5
    dirt = fbm(w, seed, 5, 4)[:h, :w]; scr = scratches(w, 60, seed + 1, width=(1, 2))[:h, :w]
    base = base * (0.88 + 0.14 * dirt[..., None]) * (0.9 + 0.1 * stitch[..., None]) + 0.05 * scr[..., None]
    refl = np.zeros((h, w)); refl[214:291, 24:488] = 1
    rough = np.where(refl > 0, 0.35, 0.82) + 0.06 * dirt
    hh = np.zeros((w, w)); hh[:h, :w] = 0.5 * stitch + 0.3 * dirt - 0.4 * scr
    save(name, base, rough, np.zeros((h, w)), hh[:h, :w], 1.8)

if __name__ == "__main__":
    cordura("t3_cordura", "#3a403c", 701)
    shell_paint("t3_shell", "#3c4241", 702)
    polymer("t3_polymer", "#1b1d1d", 703)
    loop_fabric("t3_loop", "#3d433f", 704)
    webbing("t3_webbing", "#323834", 705)
    steel("t3_steel", "#3e423f", 706)
    decals("t3_decals", 707)
