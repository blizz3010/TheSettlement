# Item 12 rollout: hand-painted-style tileable textures + normal maps for the raid props
# (relay lever, loot caches, cargo containers, cargo stacks). Same recipe as item 11 pass 3
# (make_textures.py): tint x painted pattern, detail in the normal map rather than geometry.
#   python3 tools/blender_midstyle/make_textures_rollout.py /workspace/settlement_rollout/tex
import sys, os, math
import numpy as np
from PIL import Image, ImageDraw, ImageFont
sys.argv = sys.argv[:1] + [sys.argv[1] if len(sys.argv) > 1 else "/workspace/settlement_rollout/tex"]
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_textures as MT
from make_textures import fnoise, grid, hexc, wood, scratches
OUT = sys.argv[1]; os.makedirs(OUT, exist_ok=True); MT.OUT = OUT
save_rgb, save, save_n = MT.save_rgb, MT.save, MT.save_n
FONT_B, FONT_S = MT.FONT_B, MT.FONT_S
FONT_STENCIL = "/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-Bold.ttf"
if not os.path.exists(FONT_STENCIL): FONT_STENCIL = FONT_B

def painted_steel(name, tint, seed, n=1024, chip=1.0, rust_amt=1.0, primer="#3b3a34"):
    """Roller-painted steel: soft mottling, fine scratches through to bare metal,
    chipped spots showing dark primer, rust blooms that streak downward (v = up)."""
    yy, xx = grid(n)
    mott = fnoise(n, 90, 90, seed) * .035 + fnoise(n, 8, 8, seed + 1) * .02 + fnoise(n, 3, 40, seed + 7) * .015
    chips = np.clip((fnoise(n, 6, 6, seed + 2) + .6 * fnoise(n, 28, 28, seed + 3)) - 2.6, 0, 1)
    chips = np.clip(chips * 7 * chip, 0, 1)
    sc = scratches(n, seed + 4, 90, 1.0); sc = np.clip(sc * .8, 0, 1)
    rust = np.clip(fnoise(n, 14, 14, seed + 5) - 1.9, 0, 1) * 1.8 * rust_amt
    # streaks: smear rust downward (rows increase downward in image = -v)
    streak = rust.copy()
    for k in range(1, 40, 3): streak = np.maximum(streak, np.roll(rust, k, 0) * (1 - k / 40) * .55)
    streak *= (.6 + .4 * np.clip(fnoise(n, 2, 30, seed + 6), -1, 1))
    streak = np.clip(streak, 0, 1)
    base = (1 + mott)[..., None] * hexc(tint)
    rgb = base * (1 - chips[..., None]) + hexc(primer) * (1 + .1 * fnoise(n, 4, 4, seed + 8))[..., None] * chips[..., None]
    rgb = rgb * (1 - .55 * sc[..., None]) + hexc("#9a9a94") * .55 * sc[..., None]
    rc = hexc("#7a3f22") * (.85 + .3 * np.clip(fnoise(n, 3, 3, seed + 9), -1, 1))[..., None]
    rgb = rgb * (1 - .75 * streak[..., None]) + rc * .75 * streak[..., None]
    save_rgb(name, rgb)
    save_n(name, .25 * fnoise(n, 3, 3, seed + 10) - 1.6 * chips - .7 * sc + .4 * rust + .15 * mott * 10, 1.4)

def make_all():
    H, M = 1024, 512
    painted_steel("paint_olive", "#66775e", 101)
    painted_steel("paint_sand", "#ad967a", 102, primer="#5a4a3a")
    painted_steel("paint_relay", "#5f735c", 103, chip=1.2)
    painted_steel("trim_dark", "#50555a", 104, n=M, chip=.6, primer="#2b2c2e")
    painted_steel("trim_brown", "#655444", 105, n=M, chip=.6, primer="#2e2620")
    painted_steel("drum_red", "#8c3b2c", 106, n=M, primer="#2b2620")
    painted_steel("drum_blue", "#3d5670", 107, n=M, primer="#232b33")
    painted_steel("drum_olive", "#55613f", 108, n=M, primer="#2b2c22")
    # bare worn steel and galvanised hardware
    for name, tint, seed in (("steel_bare", "#8f949a", 110), ("steel_galv", "#a4a8a6", 111)):
        n = M; p = 1 + fnoise(n, 40, 40, seed) * .06 + fnoise(n, 2, 60, seed + 1) * .04 - scratches(n, seed + 2, 120, .5)
        save(name, tint, p, extra=(lambda rgb, s=seed: rgb * .6 + MT.rust(rgb, s + 3, n) * .4) if name == "steel_bare" else None); save_n(name, fnoise(n, 2, 60, seed + 1) * .5, 1.0)
    # corrugation shading baked as a soft ramp is left to geometry; roof gets a normal-only corrugation
    n = H; yy, xx = grid(n)
    rib = np.sin(2 * np.pi * xx * 16)
    save_n("roof_ribs", np.abs(rib) ** .6 * 1.4 + .05 * fnoise(n, 4, 4, 120), 6.0)
    # rubber grip
    n = M; yy, xx = grid(n); knurl = np.sin(2 * np.pi * (xx + yy) * 40) * np.sin(2 * np.pi * (xx - yy) * 40)
    save("rubber_red", "#9c2e22", 1 + .06 * knurl + fnoise(n, 30, 30, 130) * .05); save_n("rubber_red", knurl, 2.0)
    save("rubber_black", "#2a2a2a", 1 + .05 * fnoise(n, 3, 3, 131) + fnoise(n, 30, 30, 132) * .05)
    # canvas tarp and webbing straps
    for name, tint, seed in (("canvas_olive", "#7d7f5e", 140), ("canvas_sand", "#c3b391", 141)):
        p, hh = weave(H, 110, .07, seed); p = p - .06 * np.clip(fnoise(H, 30, 30, seed + 3) - 1.0, 0, 1)
        save(name, tint, p); save_n(name, hh + 1.2 * fnoise(H, 40, 120, seed + 4), 1.4)
    for name, tint, seed in (("strap_yellow", "#c29a2c", 150), ("strap_orange", "#b8642a", 151), ("strap_dark", "#3f443c", 152)):
        n = M; yy, xx = grid(n); ribs = np.sin(2 * np.pi * xx * 60)
        edge = ((np.minimum(yy, 1 - yy)) < .05).astype(float)
        save(name, tint, 1 + .05 * ribs + .04 * fnoise(n, 30, 4, seed) - .12 * edge); save_n(name, ribs, 1.2)
    # cardboard: kraft with flute shadow, scuffs and a water stain
    n = H; yy, xx = grid(n)
    card = 1 + fnoise(n, 70, 70, 160) * .04 + fnoise(n, 2, 2, 161) * .03 - .07 * np.clip(fnoise(n, 50, 50, 162) - 1.3, 0, 1)
    save("cardboard", "#b88d5a", card); save_n("cardboard", np.sin(2 * np.pi * yy * 120) * .3 + fnoise(n, 3, 3, 163) * .3, 1.0)
    # pallet timber (rough sawn) and crate plywood
    p, h = wood(H, 170, 6, 1.4, 4); s = scratches(H, 171, 120, .1)
    save("pallet_pine", "#b39467", p - s * .8 - .05 * np.clip(fnoise(H, 6, 6, 172) - 1, 0, 1)); save_n("pallet_pine", h - s * 3 + .5 * fnoise(H, 2, 2, 173), 3.0)
    p, h = wood(H, 175, 4, .9, 1)
    save("plywood", "#c4a277", p); save_n("plywood", h, 1.5)
    hazard(); stencils(); dial()

def weave(n, threads, amp, seed):
    yy, xx = grid(n); a = np.sin(2 * np.pi * xx * threads); b = np.sin(2 * np.pi * yy * threads)
    hh = np.where((np.floor(xx * threads) + np.floor(yy * threads)) % 2 == 0, a, b)
    return 1 + amp * hh + fnoise(n, 80, 80, seed) * .035 + fnoise(n, 4, 40, seed + 1) * .02, hh

def hazard():
    n = 512; yy, xx = grid(n); band = ((xx + yy) * 4) % 1 < .5
    rgb = np.where(band[..., None], hexc("#d8a82a"), hexc("#26241f")) * (1 + .05 * fnoise(n, 30, 30, 180))[..., None]
    chips = np.clip((fnoise(n, 6, 6, 181) + .6 * fnoise(n, 28, 28, 182)) - 2.0, 0, 1); chips = np.clip(chips * 6, 0, 1)
    rgb = rgb * (1 - chips[..., None]) + hexc("#5e5a52") * chips[..., None]
    save_rgb("hazard", rgb); save_n("hazard", -1.5 * chips, 1.4)

# Stencil / decal atlas: 2 x 8 cells of 512 x 256. Light-on-transparent is not possible in
# an opaque JPEG, so each cell carries its own painted background tint (set per cell).
ST_ATLAS = ["relay", "wx", "danger", "supply_w", "supply_s", "cargo_id", "plate", "fragile",
            "arrows", "fuel", "water", "kraft_label", "stack_id", "barcode", "class", "blank"]
def stencils():
    W, Hh = 512, 256; atlas = Image.new('RGB', (1024, Hh * 8))
    olive, sand, relayc = (102, 119, 94), (173, 150, 122), (95, 115, 92)
    specs = {
        "relay": (relayc, (232, 226, 200), "RELAY", "WX-STN 07"),
        "wx": ((40, 42, 44), (230, 200, 70), "PULL", "TO RESET"),
        "danger": ((222, 182, 52), (25, 24, 22), "DANGER", "400 V  KEEP CLEAR"),
        "supply_w": (olive, (236, 230, 205), "SUPPLY", "FIELD CACHE  W-3"),
        "supply_s": (sand, (60, 48, 38), "SUPPLY", "FIELD CACHE  S-9"),
        "cargo_id": (None, (236, 232, 214), "SETU 204417 2", "22G1"),
        "plate": ((150, 150, 144), (30, 30, 30), "MAX GROSS 30480 KG", "TARE 2200 KG  CU.CAP 33.2 M3"),
        "fragile": ((200, 162, 112), (150, 30, 24), "FRAGILE", "HANDLE WITH CARE"),
        "arrows": ((200, 162, 112), (40, 34, 30), "^ ^", "THIS WAY UP"),
        "fuel": ((140, 59, 44), (236, 226, 200), "FUEL", "UN 1202  KEEP DRY"),
        "water": ((61, 86, 112), (236, 232, 214), "WATER", "POTABLE  200 L"),
        "kraft_label": ((236, 230, 212), (30, 30, 30), "SETTLEMENT", "RATIONS x 24"),
        "stack_id": ((236, 230, 212), (30, 30, 30), "LOT 0419", "DEPOT 3  BAY C"),
        "barcode": ((236, 230, 212), (20, 20, 20), "", ""),
        "class": ((214, 120, 40), (20, 20, 20), "3", "FLAMMABLE"),
        "blank": ((200, 200, 200), (0, 0, 0), "", ""),
    }
    for i, key in enumerate(ST_ATLAS):
        bg, fg, big, small = specs[key]
        if key == "cargo_id": bg = None
        im = Image.new('RGB', (W, Hh), bg if bg else (90, 104, 84)); d = ImageDraw.Draw(im)
        if key == "plate":
            d.rectangle([8, 8, W - 9, Hh - 9], outline=(60, 60, 60), width=6)
            for cx, cy in ((26, 26), (W - 26, 26), (26, Hh - 26), (W - 26, Hh - 26)): d.ellipse([cx - 9, cy - 9, cx + 9, cy + 9], fill=(90, 90, 86))
        if key in ("kraft_label", "stack_id", "barcode"): d.rectangle([6, 6, W - 7, Hh - 7], outline=(40, 40, 40), width=4)
        if key == "barcode":
            r = np.random.default_rng(7); x = 40
            while x < W - 40:
                w = int(r.integers(3, 12)); d.rectangle([x, 40, x + w, 180], fill=(20, 20, 20)); x += w + int(r.integers(4, 10))
            d.text((150, 192), "0 41926 77310 4", font=ImageFont.truetype(FONT_B, 34), fill=(20, 20, 20))
        if key == "class":
            im = Image.new('RGB', (W, Hh), (214, 120, 40)); d = ImageDraw.Draw(im)
            d.polygon([(W // 2, 10), (W // 2 + 118, Hh // 2), (W // 2, Hh - 10), (W // 2 - 118, Hh // 2)], outline=(20, 20, 20), width=6)
        if key == "danger":
            d.polygon([(40, 200), (100, 70), (160, 200)], outline=fg, width=10); d.text((88, 105), "!", font=ImageFont.truetype(FONT_B, 80), fill=fg)
        if key == "arrows":
            for x0 in (150, 300):
                d.polygon([(x0, 40), (x0 - 44, 100), (x0 + 44, 100)], fill=fg); d.rectangle([x0 - 16, 100, x0 + 16, 150], fill=fg)
            d.line([(110, 160), (340, 160)], fill=fg, width=8); big = ""
        if big:
            size = 120 if len(big) <= 6 else (78 if len(big) <= 14 else 44)
            fb = ImageFont.truetype(FONT_STENCIL, size); bb = d.textbbox((0, 0), big, font=fb)
            while bb[2] - bb[0] > W - (200 if key == "danger" else 60):
                size -= 4; fb = ImageFont.truetype(FONT_STENCIL, size); bb = d.textbbox((0, 0), big, font=fb)
            x0 = (W - (bb[2] - bb[0])) // 2 - bb[0] + (80 if key == "danger" else 0)
            y0 = 22 if small else (Hh - (bb[3] - bb[1])) // 2 - bb[1]
            if key == "class": y0 = 40; x0 = (W - (bb[2] - bb[0])) // 2 - bb[0]
            d.text((x0, y0), big, font=fb, fill=fg)
            # stencil bridges: thin vertical gaps through the letters
            if key in ("relay", "supply_w", "supply_s", "cargo_id", "fuel", "water", "fragile"):
                for gx in range(x0 + 18, x0 + (bb[2] - bb[0]), 46): d.line([(gx, y0 + bb[1]), (gx, y0 + bb[3])], fill=bg if bg else (90, 104, 84), width=3)
        if small:
            fs = ImageFont.truetype(FONT_B, 36 if len(small) < 20 else 26); bb = d.textbbox((0, 0), small, font=fs)
            d.text(((W - (bb[2] - bb[0])) // 2 - bb[0], 182 if key != "class" else 196), small, font=fs, fill=fg)
        a = np.asarray(im).astype(float) / 255
        # worn paint: speckled loss and a soft fade, so the decals sit in the paint
        wear = np.clip(fnoise(512, 3, 3, 200 + i)[:Hh, :W] - 1.2, 0, 1)[..., None] * .5
        a = a * (1 + fnoise(512, 30, 30, 220 + i)[:Hh, :W, None] * .04)
        base = np.array(bg if bg else (90, 104, 84)) / 255
        a = a * (1 - wear) + base * wear
        atlas.paste(Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)), ((i % 2) * W, (i // 2) * Hh))
    atlas.save(os.path.join(OUT, "stencil_atlas.png"))

def dial():
    """Relay faceplate: quadrant scale OFF / ON with tick marks, on dark enamel."""
    n = 512; im = Image.new('RGB', (n, n), (44, 46, 44)); d = ImageDraw.Draw(im); c = n // 2
    d.ellipse([20, 20, n - 20, n - 20], fill=(214, 206, 180)); d.ellipse([46, 46, n - 46, n - 46], fill=(44, 46, 44))
    for k in range(-40, 41, 5):
        a = math.radians(k - 90); r0 = 168 if k % 20 else 150
        d.line([(c + r0 * math.cos(a), c + r0 * math.sin(a)), (c + 200 * math.cos(a), c + 200 * math.sin(a))], fill=(214, 206, 180), width=6 if k % 20 == 0 else 3)
    f = ImageFont.truetype(FONT_B, 40)
    d.text((68, 70), "OFF", font=f, fill=(210, 80, 60)); d.text((n - 140, 70), "ON", font=f, fill=(120, 190, 110))
    d.text((c - 90, n - 150), "RELAY 2", font=ImageFont.truetype(FONT_STENCIL, 46), fill=(214, 206, 180))
    a = np.asarray(im).astype(float) / 255 * (1 + fnoise(512, 30, 30, 240)[..., None] * .04)
    save_rgb("dial", a)

if __name__ == "__main__":
    make_all(); print("textures ->", OUT, len(os.listdir(OUT)))
