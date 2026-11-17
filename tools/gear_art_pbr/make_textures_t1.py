#!/usr/bin/env python3
"""Shared T1 ("worn canvas") PBR set for gear art wave E1-A (Padded Vest, Shell Cap).
Original art, deterministic. Same conventions as the T3 set (make_textures.py): EXTERNAL jpgs
next to the .gltf models, VRAM-compressed with mipmaps on import:
raid/assets/gear/t1/textures/t1_<set>_{base,orm,normal}.jpg (ORM: R=AO, G=rough, B=metal;
OpenGL +Y normals) + the t1_decals sheet.
Size policy (E1 plan, <= 2048): only the hero fabric's albedo is 2048; ORM / normal maps are
authored at 2048 and downsampled to 1024 (fine weave detail lives in the albedo + mip chain),
normals saved at q90 (the T3 2048 normal at q95 was 3.4 MB on its own).
Run: python3 tools/gear_art_pbr/make_textures_t1.py"""
import os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "gear_parts_pbr"))
import make_textures as pf  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT = os.path.join(ROOT, "raid", "assets", "gear", "t1", "textures")
os.makedirs(OUT, exist_ok=True)
fbm, scratches, srgb, rng = pf.fbm, pf.scratches, pf.srgb, pf.rng

def blur(a, r):
    return np.asarray(Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(r)), np.float32) / 255

def _img(a, mode="RGB"):
    return Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), mode)

def save(name, base, rough, metal, height, strength, ao=None, base_px=None, aux_px=None):
    n0, n1 = base.shape[:2]
    if ao is None: ao = np.ones((n0, n1))
    b = _img(base)
    if base_px and base_px != n1: b = b.resize((base_px, base_px * n0 // n1), Image.LANCZOS)
    b.save(os.path.join(OUT, name + "_base.jpg"), quality=90)
    orm = _img(np.stack([np.clip(ao, 0, 1), np.clip(rough, 0, 1), np.clip(metal, 0, 1)], -1))
    nrm = Image.fromarray((pf.normal_from_height(height, strength) * 255).astype(np.uint8), "RGB")
    if aux_px and aux_px != n1:
        orm = orm.resize((aux_px, aux_px * n0 // n1), Image.LANCZOS); nrm = nrm.resize((aux_px, aux_px * n0 // n1), Image.LANCZOS)
    orm.save(os.path.join(OUT, name + "_orm.jpg"), quality=88)
    nrm.save(os.path.join(OUT, name + "_normal.jpg"), quality=90)
    print("TEX", name, b.size, orm.size)

def canvas(name, col, seed, n=2048, period=8):
    """Heavy cotton duck canvas: plain weave with slubs, sun-faded crowns, sweat/oil stains,
    abrasion that lightens the weave, a few darned patches."""
    y, x = np.mgrid[0:n, 0:n]
    fx = (x % period) / period; fy = (y % period) / period
    over = ((x // period) + (y // period)) % 2 == 0
    weave = np.where(over, np.sin(np.pi * fx) ** 0.8, np.sin(np.pi * fy) ** 0.8)
    r = rng(seed)
    slub = blur(r.random((n // 8, n)).repeat(8, 0), 1.0)                 # thick/thin weft yarns
    fade = fbm(n, seed + 1, 6, 3); stain = np.clip(fbm(n, seed + 2, 5, 4) - 0.6, 0, 1) * 2.2
    abr = np.clip(fbm(n, seed + 3, 5, 9) - 0.6, 0, 1) * 2.4
    dust = fbm(n, seed + 4, 5, 7); fuzz = fbm(n, seed + 5, 4, 128)
    c = srgb(col)[None, None, :]
    base = c * (0.82 + 0.24 * weave[..., None]) * (0.92 + 0.12 * slub[..., None]) * (0.86 + 0.24 * fade[..., None])
    base = base * (1 - 0.22 * stain[..., None]) + 0.10 * abr[..., None] * srgb("#d8cdb0")[None, None, :]
    base = base + 0.05 * np.clip(dust - 0.55, 0, 1)[..., None] + 0.025 * fuzz[..., None]
    rough = 0.86 + 0.06 * (1 - weave) - 0.10 * stain + 0.03 * abr
    save(name, base, rough, np.zeros((n, n)), 0.9 * weave + 0.2 * slub - 0.25 * abr, 2.2, 0.84 + 0.16 * weave, base_px=2048, aux_px=1024)

def webbing(name, col, seed, n=1024):
    """Cotton webbing / binding tape: twill ribs across U, frayed lighter edges, grime."""
    y, x = np.mgrid[0:n, 0:n]
    rib = np.sin((x + y * 0.5) * np.pi / 5.0) ** 2 * 0.65 + np.sin(y * np.pi / 3.0) ** 2 * 0.35
    fine = fbm(n, seed, 5, 64); dirt = fbm(n, seed + 3, 4, 4); fray = np.clip(fbm(n, seed + 4, 4, 24) - 0.62, 0, 1) * 2
    base = srgb(col)[None, None, :] * (0.74 + 0.30 * rib[..., None]) * (0.86 + 0.18 * fine[..., None])
    base = base * (1 - 0.35 * np.clip(dirt - 0.55, 0, 1)[..., None] * 2) + 0.08 * fray[..., None]
    save(name, base, 0.84 + 0.08 * fine, np.zeros((n, n)), rib * 0.8 + 0.2 * fine, 2.0, 0.85 + 0.15 * rib, base_px=1024, aux_px=1024)

def steel(name, col, seed, n=1024):
    """Cheap zinc-plated steel hardware gone dull: speckle, white-rust bloom, bright wear."""
    r = rng(seed); spk = blur(r.random((n, n)), 0.6)
    bloom = np.clip(fbm(n, seed + 1, 5, 6) - 0.58, 0, 1) * 2.0
    wear = scratches(n, 50, seed + 2, length=(0.02, 0.1), width=(1, 2)) * 0.6
    base = srgb(col)[None, None, :] * (0.78 + 0.3 * spk[..., None]) * (1 - wear[..., None]) + srgb("#c9ccc8")[None, None, :] * wear[..., None]
    base = base * (1 - bloom[..., None] * 0.4) + srgb("#b8b4a6")[None, None, :] * bloom[..., None] * 0.4
    save(name, base, 0.48 + 0.15 * spk + 0.3 * bloom - 0.25 * wear, np.clip(0.85 - 0.6 * bloom + 0.15 * wear, 0, 1), 0.5 * spk - 0.6 * wear + 0.3 * bloom, 1.5, base_px=512, aux_px=512)

def decals(name, seed, w=1024, h=512):
    """T1 decal sheet. Regions (image px, origin top-left):
    A (0,0)-(1024,192): Padded Vest back stencil; B (0,192)-(512,512): Shell Cap woven label;
    C (512,192)-(1024,512): vest size/care label (sewn tag)."""
    img = Image.new("RGB", (w, h), (120, 108, 82)); d = ImageDraw.Draw(img)
    F = ImageFont.truetype(pf.FONT, 92); Fs = ImageFont.truetype(pf.FONT, 44); M = ImageFont.truetype(pf.MONO, 30)
    # A: hand-sprayed stencil on canvas (dark brown paint with overspray), canvas show-through
    d.rectangle([0, 0, w - 1, 191], fill=(124, 112, 86))
    d.text((40, 44), "SETTLER  ·  T1", font=F, fill=(54, 42, 30))
    # B: woven label, red border, cream ground
    d.rectangle([0, 192, 511, h - 1], fill=(214, 204, 178)); d.rectangle([8, 200, 503, h - 9], outline=(146, 52, 40), width=8)
    d.text((40, 236), "SHELL CAP", font=Fs, fill=(146, 52, 40)); d.text((40, 300), "PADDED  ·  ONE SIZE", font=M, fill=(70, 60, 48))
    d.text((40, 352), "SETTLEMENT", font=M, fill=(70, 60, 48)); d.text((40, 400), "WORKSHOP  No.1", font=M, fill=(70, 60, 48))
    # C: sewn care tag
    d.rectangle([512, 192, w - 1, h - 1], fill=(226, 220, 204))
    d.text((540, 210), "PADDED VEST", font=Fs, fill=(36, 34, 30))
    for i, t in enumerate(["COTTON DUCK / KAPOK FILL", "SIZE  M/L", "HAND WASH  AIR DRY", "PATCH, DON'T DISCARD"]):
        d.text((540, 272 + i * 52), t, font=M, fill=(48, 46, 40))
    base = np.asarray(img, np.float32) / 255.0
    yy, xx = np.mgrid[0:h, 0:w]
    weave = (np.sin(xx * np.pi / 2.0) ** 2 * 0.5 + np.sin(yy * np.pi / 2.0) ** 2 * 0.5)
    spray = blur((np.asarray(img.convert("L"), np.float32) / 255 < 0.3).astype(np.float32) * (yy < 192), 3.0)
    dirt = fbm(w, seed, 5, 4)[:h, :w]; scr = scratches(w, 40, seed + 1, width=(1, 2))[:h, :w]
    base = base * (0.86 + 0.12 * weave[..., None]) * (0.88 + 0.14 * dirt[..., None]) - 0.08 * spray[..., None] * (yy < 192)[..., None] + 0.04 * scr[..., None]
    rough = 0.86 + 0.06 * dirt
    hh = 0.5 * weave + 0.3 * dirt - 0.3 * scr
    save(name, base, rough, np.zeros((h, w)), hh, 1.6, base_px=1024, aux_px=512)

if __name__ == "__main__":
    canvas("t1_canvas", "#80745a", 801)        # faded khaki duck
    webbing("t1_webbing", "#5e5443", 802)      # dark natural cotton tape / binding
    steel("t1_steel", "#8d908b", 803)          # dull zinc-plated hardware
    decals("t1_decals", 804)
