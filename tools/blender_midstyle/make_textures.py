# Item 11 detail pass 2: hand-painted-style tileable textures + normal maps (numpy + PIL).
# Output goes outside the Godot project; build_midstyle.py writes the ones it uses next to the
# glTF files.   python3 tools/blender_midstyle/make_textures.py /workspace/settlement_midstyle/tex2
import sys, os, math
import numpy as np
from PIL import Image, ImageDraw, ImageFont

OUT = sys.argv[1] if len(sys.argv) > 1 else "/workspace/settlement_midstyle/tex2"
os.makedirs(OUT, exist_ok=True)
FONT_B = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FONT_S = "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"
FONT_H = "/usr/share/fonts/truetype/sand-box/google/Courier Prime/CourierPrime-Regular.ttf"
if not os.path.exists(FONT_H): FONT_H = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf"

def hexc(h):
    h = h.lstrip('#'); return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)])

def fnoise(n, sx, sy, seed):
    """Periodic (tileable) smooth noise via FFT filtering; sx/sy = feature size in px at 512."""
    r = np.random.default_rng(seed); w = r.standard_normal((n, n)); k = n / 512
    fy = np.fft.fftfreq(n)[:, None]; fx = np.fft.fftfreq(n)[None, :]
    out = np.real(np.fft.ifft2(np.fft.fft2(w) * np.exp(-((fx * sx * k) ** 2 + (fy * sy * k) ** 2) * 6.0)))
    out -= out.mean(); return out / (out.std() + 1e-9)

def grid(n): yy, xx = np.mgrid[0:n, 0:n] / n; return yy, xx

def save_rgb(name, rgb):
    Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8), 'RGB').save(os.path.join(OUT, name + ".png"))

def save(name, tint, pattern, extra=None):
    rgb = pattern[..., None] * hexc(tint)[None, None, :]
    if extra is not None: rgb = extra(rgb)
    save_rgb(name, rgb)

def save_n(name, h, strength=2.0):
    """Tangent-space normal map (OpenGL/glTF +Y) from a tileable height field."""
    n = h.shape[0]
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * .5 * strength * n / 512
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * .5 * strength * n / 512
    nx, ny, nz = -dx, dy, np.ones_like(h)
    l = np.sqrt(nx * nx + ny * ny + nz * nz)
    save_rgb(name + "_n", np.stack([nx / l * .5 + .5, ny / l * .5 + .5, nz / l * .5 + .5], -1))

def wood(n, seed, ring=10, contrast=1.0, knots=3):
    yy, xx = grid(n)
    streak = fnoise(n, 70, 3, seed); warp = fnoise(n, 120, 40, seed + 1)
    # knots: local ring distortion around a few points (wrapped so it still tiles)
    r = np.random.default_rng(seed + 9); kd = np.zeros((n, n))
    for _ in range(knots):
        cx, cy = r.random(), r.random(); dxk = (xx - cx + .5) % 1 - .5; dyk = (yy - cy + .5) % 1 - .5
        d = np.sqrt((dxk * .35) ** 2 + dyk ** 2); kd += np.exp(-(d / .03) ** 2) * 1.0 + .02 / (d + .02) * .25
    rings = np.sin(2 * np.pi * (yy * ring + warp * .35 + kd * .6))
    rings = np.sign(rings) * np.abs(rings) ** .5
    fleck = fnoise(n, 6, 2, seed + 2)
    knot_dark = np.clip(np.exp(-0) * 0, 0, 0)
    p = 1.0 + contrast * (.08 * streak + .06 * rings + .03 * fleck) - .25 * np.clip(kd - .6, 0, 1)
    h = .5 * streak + .35 * rings + .15 * fleck - .6 * np.clip(kd - .6, 0, 1)
    return p, h

def scratches(n, seed, count=40, amp=.12):
    im = Image.new('L', (n, n), 0); d = ImageDraw.Draw(im); r = np.random.default_rng(seed)
    for _ in range(count):
        x, y = r.random() * n, r.random() * n; a = r.normal(0, .25); L = r.uniform(.04, .18) * n
        d.line([(x, y), (x + math.cos(a) * L, y + math.sin(a) * L)], fill=int(r.uniform(90, 200)), width=1)
    return np.asarray(im).astype(float) / 255 * amp

def make_all():
    H = 1024; M = 512
    for name, tint, seed, ring, con, n in (("walnut", "#6a4e37", 1, 9, 1.0, H), ("walnut_dark", "#463529", 2, 12, 1.0, M),
                                          ("oak", "#8a6342", 3, 7, 1.0, H), ("timber_light", "#a67c55", 4, 6, 1.2, M),
                                          ("timber_mid", "#83603f", 5, 8, 1.2, M), ("crate_pine", "#a98559", 6, 5, 1.3, H)):
        p, h = wood(n, seed, ring, con)
        if name == "oak": s = scratches(n, 33, 60); p = p + s * .8; h = h - s * 2
        save(name, tint, p); save_n(name, h, 2.5)
    # painted timber: brush strokes, faint grain through the paint, chips showing the wood beneath
    for name, tint, seed in (("teal_paint", "#56716b", 7), ("teal_panel", "#6b867d", 8)):
        n = H; wp, wh = wood(n, seed + 40, 7, 1.0, 1)
        brush = fnoise(n, 90, 6, seed + 1); grain = fnoise(n, 60, 3, seed)
        chips = np.clip((fnoise(n, 7, 7, seed + 3) + .5 * fnoise(n, 30, 30, seed + 4)) - 2.4, 0, 1)
        chips = np.clip(chips * 6, 0, 1)
        p = 1 + .03 * brush + .025 * grain + .03 * fnoise(n, 60, 60, seed + 2)
        rgb = p[..., None] * hexc(tint) * (1 - chips[..., None]) + (wp[..., None] * hexc("#8d6a48")) * chips[..., None]
        rgb = rgb * (1 + .1 * np.clip(chips * 0, 0, 1))[..., None]
        save_rgb(name, rgb); save_n(name, .6 * brush + .3 * grain - 2.0 * chips, 1.6)
    yy, xx = grid(H)
    def weave(n, threads, amp, seed, twill=False):
        yy, xx = grid(n)
        if twill:
            t = np.sin(2 * np.pi * (xx + yy) * threads); hh = t
        else:
            a = np.sin(2 * np.pi * xx * threads); b = np.sin(2 * np.pi * yy * threads)
            hh = np.where((np.floor(xx * threads) + np.floor(yy * threads)) % 2 == 0, a, b)
        p = 1 + amp * hh + fnoise(n, 80, 80, seed) * .035 + fnoise(n, 4, 40, seed + 1) * .02
        return p, hh
    for name, tint, thr, amp, seed, tw, n in (("linen", "#ddd0ae", 140, .06, 9, False, H), ("wool_indigo", "#46557c", 170, .09, 10, True, H),
                                              ("wool_cream", "#e6dabd", 170, .06, 11, True, M), ("burlap", "#a88f62", 48, .16, 19, False, M),
                                              ("tomato", "#b33a2c", 90, .05, 26, False, M), ("drape_ochre", "#b9853a", 160, .06, 34, True, H),
                                              ("ribbon_red", "#aa4b33", 120, .05, 21, False, M)):
        p, hh = weave(n, thr, amp, seed, tw); save(name, tint, p); save_n(name, hh, 1.2 if n == H else 1.6)
    n = M
    for name, tint, seed, sp in (("bronze", "#a98048", 12, .2), ("brass", "#b48d4e", 13, .15), ("iron", "#717a80", 14, 0)):
        p = 1 + fnoise(n, 50, 50, seed) * .06 + fnoise(n, 6, 6, seed + 1) * .03 - np.clip(fnoise(n, 14, 14, seed + 2) - 1.4, 0, 1) * sp
        save(name, tint, p, extra=(lambda rgb, s=seed: rust(rgb, s + 1, n)) if name == "iron" else None)
    st = 1 + fnoise(n, 70, 70, 16) * .07 + fnoise(n, 3, 3, 17) * .05 - np.clip(fnoise(n, 4, 4, 18) - 2.0, 0, 1) * .3
    save("stone", "#a59d8d", st); save_n("stone", fnoise(n, 20, 20, 16) + .4 * fnoise(n, 3, 3, 17), 3.0)
    save("paper", "#e4d7b4", 1 + fnoise(n, 60, 60, 17) * .025 + fnoise(n, 2, 18, 18) * .012)
    save("paper_brown", "#c9a77a", 1 + fnoise(n, 60, 60, 19) * .04 + fnoise(n, 2, 18, 20) * .02)
    tw = 1 + fnoise(n, 2, 30, 20) * .08 + np.sin(2 * np.pi * (grid(n)[1] * 3 + grid(n)[0] * 60)) * .09
    save("twine", "#bba57a", tw)
    bc = 1 + fnoise(n, 40, 40, 22) * .05 + fnoise(n, 3, 3, 23) * .04 + np.clip(fnoise(n, 50, 50, 24) - 1.2, 0, 1) * .25
    save("bookcloth_teal", "#3f6660", bc, extra=lambda rgb: ink_stains(rgb, 25, n)); save_n("bookcloth_teal", fnoise(n, 3, 3, 23), 1.5)
    lt = 1 + fnoise(n, 30, 30, 24) * .07 + fnoise(n, 3, 3, 25) * .04
    save("leather_rust", "#7a3d2a", lt); save_n("leather_rust", fnoise(n, 5, 5, 26) - np.abs(fnoise(n, 12, 12, 27)) * .8, 2.0)
    for name, tint, seed in (("leaf_green", "#4f6b35", 27), ("glass_green", "#3e6a4e", 28), ("glass_amber", "#8a5a22", 29), ("ink_black", "#2e2c28", 30), ("chalk_blue", "#8fa6c8", 32), ("terracotta", "#a5583a", 35), ("fern", "#56783a", 36)):
        save(name, tint, 1 + fnoise(n, 60, 30, seed) * .06)
    save("cork", "#a07a50", 1 + fnoise(n, 3, 3, 31) * .12)
    save("thread_gold", "#f0d38a", np.ones((64, 64)))
    save("thread_white", "#f2eee2", np.ones((64, 64)))
    page_edges(); end_grain(); spiral(); tape(); ruled(); pattern_paper(); labels()

def rust(rgb, seed, n):
    m = np.clip(np.clip(fnoise(n, 12, 12, seed) - .9, 0, 1) * 1.6, 0, .85)[..., None]
    return rgb * (1 - m) + hexc("#8a4a2a")[None, None, :] * (.9 + .2 * fnoise(n, 3, 3, seed + 1)[..., None]) * m

def ink_stains(rgb, seed, n):
    r = np.random.default_rng(seed); yy, xx = grid(n); m = np.zeros((n, n))
    for _ in range(2):
        cx, cy = r.random(), r.random(); d = np.sqrt(((xx - cx + .5) % 1 - .5) ** 2 + ((yy - cy + .5) % 1 - .5) ** 2)
        m = np.maximum(m, np.clip(1 - d / (.03 + .02 * fnoise(n, 10, 10, seed + 3) * .3), 0, 1))
    m = (m > .1).astype(float)[..., None] * .7
    return rgb * (1 - m) + hexc("#1d2430") * m

def page_edges():
    n = 512; yy, xx = grid(n)
    save("page_edge", "#e2d3ad", 1 + .08 * np.sin(2 * np.pi * yy * 140) + fnoise(n, 80, 4, 40) * .03 - .12 * np.clip(fnoise(n, 120, 30, 41) - 1, 0, 1))

def end_grain():
    n = 512; yy, xx = grid(n); r = np.hypot(xx - .5, yy - .5)
    p = 1 + .09 * np.sin(2 * np.pi * (r + fnoise(n, 40, 40, 41) * .015) * 22) + fnoise(n, 3, 3, 42) * .03 - np.clip(r - .45, 0, 1) * 1.2
    # a drying crack from the pith
    crack = (np.abs(np.arctan2(yy - .5, xx - .5) - .7) < .02) & (r < .4)
    save("end_grain", "#b38a5f", p - crack * .35)

def spiral():
    n = 512; yy, xx = grid(n); ang = np.arctan2(yy - .5, xx - .5); r = np.hypot(xx - .5, yy - .5)
    s = np.sin(2 * np.pi * (r * 16 - ang / (2 * np.pi)))
    save("plan_end", "#e4d7b4", np.where(r < .2, .72, .93 - .09 * (s > .55) + .04 * s))

def tape():
    W, Hh = 1024, 192
    im = Image.new('RGB', (W, Hh), (230, 190, 80)); d = ImageDraw.Draw(im); f = ImageFont.truetype(FONT_B, 64)
    for mm in range(0, 100, 2):
        x = int(mm / 100 * W); h = 74 if mm % 10 == 0 else (50 if mm % 5 == 0 else 30)
        d.rectangle([x, 0, x + 4, h], fill=(30, 26, 20)); d.rectangle([x, Hh - h, x + 4, Hh], fill=(30, 26, 20))
    for cm in range(10):
        d.text((int(cm / 10 * W) + 16, Hh // 2 - 36), str(cm + 1), font=f, fill=(170, 30, 22) if cm == 4 else (30, 26, 20))
    im.save(os.path.join(OUT, "tape.png"))

def ruled():
    W = 1024; im = Image.new('RGB', (W, W), (230, 220, 190)); d = ImageDraw.Draw(im); rng = np.random.default_rng(50)
    for k in range(18):
        y = 80 + k * 52; d.line([(0, y), (W, y)], fill=(140, 160, 190), width=3)
        if 1 <= k <= 15:
            x = 140
            while x < W - 80:
                w = int(rng.integers(40, 120)); d.line([(x, y - 12), (x + w, y - 12 + int(rng.integers(-4, 5)))], fill=(50, 44, 44), width=6); x += w + int(rng.integers(16, 32))
    d.line([(112, 0), (112, W)], fill=(180, 80, 70), width=4)
    d.ellipse([700, 760, 790, 830], outline=(60, 50, 70), width=3)  # a little ink blot
    im.save(os.path.join(OUT, "ruled.png"))
    im = Image.new('RGB', (W, W), (226, 216, 184)); d = ImageDraw.Draw(im)
    for k in range(0, W, 64): d.line([(k, 0), (k, W)], fill=(196, 196, 186), width=2); d.line([(0, k), (W, k)], fill=(196, 196, 186), width=2)
    c = (60, 82, 130)
    d.rectangle([120, 160, 600, 520], outline=c, width=8); d.rectangle([600, 280, 880, 520], outline=c, width=8)
    d.line([(120, 600), (880, 600)], fill=c, width=6); d.polygon([(120, 160), (360, 40), (600, 160)], outline=c, width=8)
    d.rectangle([300, 380, 380, 520], outline=c, width=6); d.text((140, 640), "WORKSHOP  12 x 8", font=ImageFont.truetype(FONT_B, 54), fill=c)
    im.save(os.path.join(OUT, "plan_paper.png"))

def pattern_paper():
    W = 512; im = Image.new('RGB', (W, W), (205, 172, 126)); d = ImageDraw.Draw(im)
    for k in range(0, W, 24): d.line([(30 + k % 48, 30), (30 + k % 48, 30)], fill=(0, 0, 0))
    for x0 in range(30, W - 30, 22): d.line([(x0, 34), (x0 + 12, 34)], fill=(60, 40, 30), width=4); d.line([(x0, W - 34), (x0 + 12, W - 34)], fill=(60, 40, 30), width=4)
    for y0 in range(30, W - 30, 22): d.line([(34, y0), (34, y0 + 12)], fill=(60, 40, 30), width=4); d.line([(W - 34, y0), (W - 34, y0 + 12)], fill=(60, 40, 30), width=4)
    d.line([(W // 2, 90), (W // 2, W - 90)], fill=(60, 40, 30), width=4); d.polygon([(W // 2, 70), (W // 2 - 18, 104), (W // 2 + 18, 104)], fill=(60, 40, 30))
    fb = ImageFont.truetype(FONT_S, 58); fs = ImageFont.truetype(FONT_H, 40)
    d.text((70, 150), "BACK", font=fb, fill=(50, 32, 24)); d.text((70, 230), "No. 14", font=fs, fill=(50, 32, 24)); d.text((70, 290), "cut 2", font=fs, fill=(150, 40, 30))
    im.save(os.path.join(OUT, "pattern_paper.png"))

ATLAS = ["nails", "linseed", "timber", "rook", "ledger", "guests", "spirit", "hinge", "price", "rope", "tailor", "key1", "key2", "key3", "post", "stamp"]
def labels():
    specs = {"nails": ("NAILS", "2 lb"), "linseed": ("LINSEED", "OIL"), "timber": ("4c", "per ft"),
             "rook": ("ROOK'S", "SUPPLIES"), "ledger": ("LEDGER", "1886"), "guests": ("GUESTS", ""),
             "spirit": ("LAMP", "SPIRIT"), "hinge": ("HINGES", "BRASS"), "price": ("3c", "each"),
             "rope": ("ROPE", "10 m"), "tailor": ("TAILOR", "& DYES"), "key1": ("1", ""), "key2": ("2", ""), "key3": ("3", ""),
             "post": ("POST", "OUT"), "stamp": ("PAID", "")}
    W, Hh = 512, 256; atlas = Image.new('RGB', (1024, 2048))
    for i, key in enumerate(ATLAS):
        big, small = specs[key]
        hand = key in ("timber", "price", "key1", "key2", "key3")
        im = Image.new('RGB', (W, Hh), (236, 224, 190) if not hand else (226, 206, 160)); d = ImageDraw.Draw(im)
        d.rectangle([10, 10, W - 11, Hh - 11], outline=(60, 44, 32), width=8)
        if not hand: d.rectangle([28, 28, W - 29, Hh - 29], outline=(60, 44, 32), width=2)
        size = 132 if len(big) <= 2 else (112 if len(big) <= 5 else (96 if len(big) <= 6 else 84))
        fb = ImageFont.truetype(FONT_H if hand else FONT_S, size if small else int(size * 1.25)); fs = ImageFont.truetype(FONT_B, 46)
        bb = d.textbbox((0, 0), big, font=fb); fsz = size if small else int(size * 1.25)
        while bb[2] - bb[0] > W - 80:
            fsz -= 6; fb = ImageFont.truetype(FONT_H if hand else FONT_S, fsz); bb = d.textbbox((0, 0), big, font=fb)
        y0 = 30 if small else (Hh - (bb[3] - bb[1])) // 2 - bb[1]
        d.text(((W - (bb[2] - bb[0])) // 2 - bb[0], y0), big, font=fb, fill=(40, 28, 22) if not hand else (40, 40, 70))
        if small:
            bb = d.textbbox((0, 0), small, font=fs); d.text(((W - (bb[2] - bb[0])) // 2 - bb[0], 172), small, font=fs, fill=(130, 50, 34))
        a = np.asarray(im).astype(float) / 255 * (1 + fnoise(512, 30, 30, i)[:Hh, :W, None] * .03)
        atlas.paste(Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)), ((i % 2) * W, (i // 2) * Hh))
    atlas.save(os.path.join(OUT, "labels_atlas.png"))

if __name__ == "__main__":
    make_all(); print("textures ->", OUT, len(os.listdir(OUT)))
