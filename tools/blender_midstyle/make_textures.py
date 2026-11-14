# Item 11 detail pass: small hand-painted-style tileable textures (numpy + PIL).
# Output goes outside the Godot project; build_midstyle.py packs them into the .glb files.
#   python3 tools/blender_midstyle/make_textures.py /workspace/settlement_midstyle/tex
import sys, os, math
import numpy as np
from PIL import Image, ImageDraw, ImageFont

OUT = sys.argv[1] if len(sys.argv) > 1 else "/workspace/settlement_midstyle/tex"
os.makedirs(OUT, exist_ok=True)
FONT_B = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FONT_S = "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"
FONT_M = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf"

def hexc(h):
    h = h.lstrip('#'); return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)])

def fnoise(n, sx, sy, seed):
    """Periodic (tileable) smooth noise via FFT filtering; sx/sy = feature size in px."""
    r = np.random.default_rng(seed)
    w = r.standard_normal((n, n))
    fy = np.fft.fftfreq(n)[:, None]; fx = np.fft.fftfreq(n)[None, :]
    filt = np.exp(-((fx * sx) ** 2 + (fy * sy) ** 2) * 6.0)
    out = np.real(np.fft.ifft2(np.fft.fft2(w) * filt))
    out -= out.mean(); out /= (out.std() + 1e-9)
    return out

def save(name, tint, pattern, extra=None):
    rgb = np.clip(pattern[..., None] * hexc(tint)[None, None, :], 0, 1)
    if extra is not None: rgb = extra(rgb)
    Image.fromarray((rgb * 255).astype(np.uint8), 'RGB').save(os.path.join(OUT, name + ".png"))

N = 512
yy, xx = np.mgrid[0:N, 0:N] / N

def wood(seed, ring=10, contrast=1.0):
    streak = fnoise(N, 70, 3, seed)          # long streaks along U (x)
    warp = fnoise(N, 120, 40, seed + 1)
    rings = np.sin(2 * np.pi * (yy * ring + warp * .35))
    rings = np.sign(rings) * np.abs(rings) ** .5
    fleck = fnoise(N, 6, 2, seed + 2)
    p = 1.0 + contrast * (.075 * streak + .055 * rings + .025 * fleck)
    return p

def paint(seed):
    grain = fnoise(N, 60, 3, seed) * .025
    brush = fnoise(N, 90, 6, seed + 1) * .03
    mott = fnoise(N, 60, 60, seed + 2) * .03
    scuff = np.clip(fnoise(N, 8, 8, seed + 3) - 2.3, 0, 1) * .25
    return 1.0 + grain + brush + mott + scuff

def weave(seed, n_threads=64, amp=.07, twill=False):
    if twill:
        t = np.sin(2 * np.pi * (xx + yy) * n_threads)
        p = 1 + amp * t
    else:
        a = np.sin(2 * np.pi * xx * n_threads); b = np.sin(2 * np.pi * yy * n_threads)
        p = 1 + amp * np.where((np.floor(xx * n_threads) + np.floor(yy * n_threads)) % 2 == 0, a, b)
    p += fnoise(N, 80, 80, seed) * .035 + fnoise(N, 4, 40, seed + 1) * .02
    return p

def metal(seed, spots=0.0):
    p = 1 + fnoise(N, 50, 50, seed) * .06 + fnoise(N, 6, 6, seed + 1) * .03
    if spots: p -= np.clip(fnoise(N, 14, 14, seed + 2) - 1.4, 0, 1) * spots
    return p

def stone(seed):
    p = 1 + fnoise(N, 70, 70, seed) * .07 + fnoise(N, 3, 3, seed + 1) * .05
    p -= np.clip(fnoise(N, 4, 4, seed + 2) - 2.0, 0, 1) * .3
    return p

def paper(seed, lines=0, line_col=None):
    p = 1 + fnoise(N, 60, 60, seed) * .025 + fnoise(N, 2, 18, seed + 1) * .012
    return p

def make_all():
    save("walnut", "#6a4e37", wood(1, 9))
    save("walnut_dark", "#463529", wood(2, 12))
    save("oak", "#8a6342", wood(3, 7))
    save("timber_light", "#a67c55", wood(4, 6, 1.2))
    save("timber_mid", "#83603f", wood(5, 8, 1.2))
    save("crate_pine", "#a98559", wood(6, 5, 1.3))
    save("teal_paint", "#56716b", paint(7))
    save("teal_panel", "#6b867d", paint(8))
    save("linen", "#ddd0ae", weave(9, 96, .06))
    save("wool_indigo", "#46557c", weave(10, 110, .09, twill=True))
    save("wool_cream", "#e6dabd", weave(11, 110, .06, twill=True))
    save("bronze", "#a98048", metal(12, .25))
    save("brass", "#b48d4e", metal(13, .2))
    save("iron", "#717a80", metal(14, .0), extra=lambda rgb: rust(rgb, 15))
    save("stone", "#a59d8d", stone(16))
    save("paper", "#e4d7b4", paper(17))
    save("paper_core", "#b9a67e", paper(18))
    save("burlap", "#a88f62", weave(19, 40, .16))
    save("twine", "#bba57a", 1 + fnoise(N, 2, 30, 20) * .08 + np.sin(2 * np.pi * (xx * 3 + yy * 60)) * .07)
    save("ribbon_red", "#aa4b33", weave(21, 120, .05))
    save("bookcloth_teal", "#3f6660", 1 + fnoise(N, 40, 40, 22) * .05 + fnoise(N, 3, 3, 23) * .04)
    save("leather_rust", "#7a3d2a", 1 + fnoise(N, 30, 30, 24) * .07 + fnoise(N, 3, 3, 25) * .04)
    save("tomato", "#b33a2c", weave(26, 90, .05))
    save("leaf_green", "#4f6b35", weave(27, 90, .05))
    save("glass_green", "#3e6a4e", 1 + fnoise(N, 90, 30, 28) * .06)
    save("glass_amber", "#8a5a22", 1 + fnoise(N, 90, 30, 29) * .06)
    save("ink_black", "#2e2c28", 1 + fnoise(N, 40, 40, 30) * .05)
    save("cork", "#a07a50", 1 + fnoise(N, 3, 3, 31) * .12)
    save("thread_gold", "#e2c27a", np.ones((N, N)))
    save("chalk_blue", "#8fa6c8", 1 + fnoise(N, 5, 5, 32) * .06)
    page_edges(); end_grain(); spiral(); tape(); ruled(); labels()

def rust(rgb, seed):
    m = np.clip(fnoise(N, 12, 12, seed) - .9, 0, 1)[..., None]
    m = np.clip(m * 1.6, 0, .85)
    return rgb * (1 - m) + hexc("#8a4a2a")[None, None, :] * (.9 + .2 * fnoise(N, 3, 3, seed + 1)[..., None]) * m

def page_edges():
    # Page block edge: fine horizontal lines (pages), slight yellowing.
    p = 1 + .07 * np.sin(2 * np.pi * yy * 140) + fnoise(N, 80, 4, 40) * .03
    save("page_edge", "#e2d3ad", p)

def end_grain():
    r = np.hypot(xx - .5, yy - .5)
    w = fnoise(N, 40, 40, 41) * .015
    p = 1 + .08 * np.sin(2 * np.pi * (r + w) * 22) + fnoise(N, 3, 3, 42) * .03 - np.clip(r - .45, 0, 1) * 1.2
    save("end_grain", "#b38a5f", p)

def spiral():
    # Rolled-plan end: a paper spiral around a darker core.
    ang = np.arctan2(yy - .5, xx - .5); r = np.hypot(xx - .5, yy - .5)
    s = np.sin(2 * np.pi * (r * 16 - ang / (2 * np.pi)))
    p = .93 + .09 * (s > .55) * -1.0 + .04 * s
    p = np.where(r < .2, .72, p)
    save("plan_end", "#e4d7b4", p)

def tape():
    W, H = 1024, 192   # 10 cm of tape across U, full width across V
    im = Image.new('RGB', (W, H), (226, 186, 82)); d = ImageDraw.Draw(im)
    f = ImageFont.truetype(FONT_B, 54)
    for mm in range(0, 100, 2):
        x = int(mm / 100 * W)
        h = 70 if mm % 10 == 0 else (46 if mm % 5 == 0 else 28)
        d.rectangle([x, 0, x + 3, h], fill=(40, 34, 26)); d.rectangle([x, H - h, x + 3, H], fill=(40, 34, 26))
    for i, cm in enumerate(range(0, 10)):
        x = int(cm / 10 * W) + 18
        d.text((x, H // 2 - 30), str(cm + 1), font=f, fill=(150, 34, 26) if cm == 4 else (40, 34, 26))
    im.save(os.path.join(OUT, "tape.png"))

def ruled():
    # Ledger / guest-book pages: ruled blue lines, red margin, faint script scribbles.
    W = 512; im = Image.new('RGB', (W, W), (230, 220, 190)); d = ImageDraw.Draw(im)
    rng = np.random.default_rng(50)
    for k in range(18):
        y = 40 + k * 26; d.line([(0, y), (W, y)], fill=(150, 168, 190), width=2)
        if 1 <= k <= 15:
            x = 70
            while x < W - 40:
                w = int(rng.integers(20, 60)); d.line([(x, y - 6), (x + w, y - 6 + int(rng.integers(-2, 3)))], fill=(70, 62, 60), width=3); x += w + int(rng.integers(8, 16))
    d.line([(56, 0), (56, W)], fill=(180, 90, 80), width=2)
    im.save(os.path.join(OUT, "ruled.png"))
    # Blueprint-ish plan paper.
    im = Image.new('RGB', (W, W), (226, 216, 184)); d = ImageDraw.Draw(im)
    for k in range(0, W, 32): d.line([(k, 0), (k, W)], fill=(196, 196, 186), width=1); d.line([(0, k), (W, k)], fill=(196, 196, 186), width=1)
    d.rectangle([60, 80, 300, 260], outline=(70, 90, 130), width=4); d.rectangle([300, 140, 440, 260], outline=(70, 90, 130), width=4)
    d.line([(60, 300), (440, 300)], fill=(70, 90, 130), width=3); d.polygon([(60, 80), (180, 20), (300, 80)], outline=(70, 90, 130), width=4)
    im.save(os.path.join(OUT, "plan_paper.png"))

def labels():
    specs = {"label_nails": ("NAILS", "No.3 · 2 lb"), "label_linseed": ("LINSEED", "boiled oil"),
             "label_timber": ("TIMBER", "sample lot 7"), "label_rook": ("ROOK'S", "supplies"),
             "label_ledger": ("LEDGER", "stock & trade"), "label_guests": ("GUESTS", "register"),
             "label_spirit": ("LAMP", "spirit"), "label_hinge": ("HINGES", "pair · brass")}
    for name, (big, small) in specs.items():
        W, H = 256, 128
        im = Image.new('RGB', (W, H), (232, 220, 186)); d = ImageDraw.Draw(im)
        d.rectangle([6, 6, W - 7, H - 7], outline=(70, 52, 38), width=4)
        d.rectangle([14, 14, W - 15, H - 15], outline=(70, 52, 38), width=1)
        fb = ImageFont.truetype(FONT_S, 44 if len(big) < 7 else 36); fs = ImageFont.truetype(FONT_B, 20)
        bb = d.textbbox((0, 0), big, font=fb); d.text(((W - bb[2]) // 2, 22), big, font=fb, fill=(52, 38, 30))
        bb = d.textbbox((0, 0), small, font=fs); d.text(((W - bb[2]) // 2, 84), small, font=fs, fill=(110, 60, 40))
        a = np.asarray(im).astype(float) / 255
        a *= (1 + fnoise(W, 30, 30, sum(map(ord, name)) % 1000)[:H, :W, None] * .03)
        Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).save(os.path.join(OUT, name + ".png"))
    # One atlas (2 x 4 cells of 256 x 128) so every label on a prop shares a single material.
    atlas = Image.new('RGB', (512, 512))
    for i, key in enumerate(ATLAS):
        atlas.paste(Image.open(os.path.join(OUT, "label_" + key + ".png")), ((i % 2) * 256, (i // 2) * 128))
    atlas.save(os.path.join(OUT, "labels_atlas.png"))

ATLAS = ["nails", "linseed", "timber", "rook", "ledger", "guests", "spirit", "hinge"]

if __name__ == "__main__":
    make_all(); print("textures ->", OUT, len(os.listdir(OUT)))
