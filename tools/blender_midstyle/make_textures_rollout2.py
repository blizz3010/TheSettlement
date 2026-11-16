# New tileable textures for item 12 rollout 2 (launchpad ship + request board).
#   python3 tools/blender_midstyle/make_textures_rollout2.py /workspace/settlement_rollout2/tex
import sys, os, math
import numpy as np
from PIL import Image, ImageDraw, ImageFont

OUT = sys.argv[1] if len(sys.argv) > 1 else "/workspace/settlement_rollout2/tex"
os.makedirs(OUT, exist_ok=True)

def hexc(h):
    h = h.lstrip('#'); return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)])

def fnoise(n, sx, sy, seed):
    r = np.random.default_rng(seed); w = r.standard_normal((n, n)); k = n / 512
    fy = np.fft.fftfreq(n)[:, None]; fx = np.fft.fftfreq(n)[None, :]
    out = np.real(np.fft.ifft2(np.fft.fft2(w) * np.exp(-((fx * sx * k) ** 2 + (fy * sy * k) ** 2) * 6.0)))
    out -= out.mean(); return out / (out.std() + 1e-9)

def grid(n):
    yy, xx = np.mgrid[0:n, 0:n] / n
    return yy, xx

def save_rgb(name, rgb):
    Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8), 'RGB').save(os.path.join(OUT, name + ".png"))

def save_n(name, h, strength=2.0):
    n = h.shape[0]
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * .5 * strength * n / 512
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * .5 * strength * n / 512
    nx, ny, nz = -dx, dy, np.ones_like(h)
    l = np.sqrt(nx * nx + ny * ny + nz * nz)
    rgb = np.stack([nx / l * .5 + .5, ny / l * .5 + .5, nz / l * .5 + .5], -1)
    save_rgb(name + "_n", rgb)

def panel_lines(n, count, width_px, seed=1):
    yy, xx = grid(n)
    h = np.zeros((n, n))
    # vertical and horizontal recessed lines, slightly irregular
    rng = np.random.default_rng(seed)
    for i in range(count):
        u = (i + .5) / count + rng.normal(0, 0.003)
        h += -np.exp(-((xx - (u % 1)) * n) ** 2 / (2 * width_px ** 2))
        h += -np.exp(-((yy - (u % 1)) * n) ** 2 / (2 * width_px ** 2))
    # wrap-aware second pass for the 0 seam
    h += -np.exp(-(np.minimum(xx, 1 - xx) * n) ** 2 / (2 * width_px ** 2)) * 0.6
    h += -np.exp(-(np.minimum(yy, 1 - yy) * n) ** 2 / (2 * width_px ** 2)) * 0.6
    return h

N = 512

# Ivory aircraft paint: warm cream, faint irregular panel gaps (not a tile grid),
# soft orange-peel, light grit in the recesses.
def sparse_panels(n, n_h, n_v, width_px, seed):
    yy, xx = grid(n)
    h = np.zeros((n, n))
    rng = np.random.default_rng(seed)
    # Irregular spacing, not a regular square grid, and no wrap-seam doubling.
    for u in np.linspace(0.08, 0.92, n_v) + rng.normal(0, 0.015, n_v):
        u = float(np.clip(u, 0.02, 0.98))
        w = width_px * rng.uniform(0.7, 1.3)
        h += -np.exp(-((xx - u) * n) ** 2 / (2 * w ** 2))
    for v in np.linspace(0.10, 0.90, n_h) + rng.normal(0, 0.02, n_h):
        v = float(np.clip(v, 0.02, 0.98))
        w = width_px * rng.uniform(0.7, 1.3)
        h += -np.exp(-((yy - v) * n) ** 2 / (2 * w ** 2))
    return h

h = fnoise(N, 28, 28, 11) * 0.010 + fnoise(N, 8, 8, 12) * 0.005
h += sparse_panels(N, 3, 4, 1.6, 13) * 0.016
yy, xx = grid(N)
riv = np.zeros((N, N))
rng = np.random.default_rng(16)
# A few faint rivets near the panel gaps, not a dense nail grid.
for _ in range(28):
    cy, cx = rng.uniform(0.05, 0.95, 2)
    d2 = ((xx - cx) * N) ** 2 + ((yy - cy) * N) ** 2
    riv += np.exp(-d2 / 3.5) * 0.012
h += riv
grime = np.clip(fnoise(N, 40, 18, 14) * 0.35 + 0.08, 0, 1)
base = (0.94 + h * 1.4 + fnoise(N, 6, 6, 15) * 0.02)[..., None] * hexc("e4d8c6")
base = base * (1 - 0.08 * grime[..., None] * hexc("5a4a38")[None, None, :] / (base + 1e-6))
base = base * (1 + h[..., None] * 0.35)
save_rgb("hull_ivory", base)
save_n("hull_ivory", h + riv, 1.15)

# Worn ochre livery / heat-stained accent: soft, not a tile grid.
h2 = fnoise(N, 24, 24, 21) * 0.012 + sparse_panels(N, 2, 3, 1.6, 22) * 0.012
fade = np.clip(0.55 + fnoise(N, 36, 20, 23) * 0.35, 0, 1)
och = (0.88 + h2 * 1.4)[..., None] * hexc("c49a58")
och = och * fade[..., None] + hexc("6a4e2c")[None, None, :] * (1 - fade[..., None]) * 0.28
save_rgb("hull_ochre", och)
save_n("hull_ochre", h2, 1.2)

# Warm pad concrete with radial-looking joints (tileable square joints) and grit.
h3 = fnoise(N, 32, 32, 31) * 0.02 + fnoise(N, 7, 7, 32) * 0.01
joints = panel_lines(N, 5, 3.4, 33) * 0.06
h3 += joints
conc = (0.88 + h3 * 3 + fnoise(N, 5, 5, 34) * 0.04)[..., None] * hexc("8a8576")
conc = conc + hexc("c4b89a") * np.clip(-joints, 0, 1)[..., None] * 0.08  # pale dust in joints
save_rgb("pad_concrete", conc)
save_n("pad_concrete", h3, 2.8)

# Dark petrol cockpit glass (mostly colour; slight mottling).
g = (0.85 + fnoise(N, 20, 14, 41) * 0.08)[..., None] * hexc("12353a")
save_rgb("glass_cockpit", g)

# Cream deck inlay — smoother, paler stone.
h4 = fnoise(N, 22, 22, 51) * 0.01 + panel_lines(N, 10, 1.6, 52) * 0.02
inl = (0.9 + h4 * 3)[..., None] * hexc("cfc3a6")
save_rgb("deck_inlay", inl)
save_n("deck_inlay", h4, 2.0)

# Notice paper with faint ruled lines and wear.
h5 = fnoise(N, 16, 16, 61) * 0.008
yy, xx = grid(N)
rules = (np.sin(yy * 22 * math.pi) > 0.92).astype(float) * 0.12
paper = (0.96 + h5 * 2)[..., None] * hexc("e6d5b0") - rules[..., None] * hexc("8b7b5e")
stain = np.clip(fnoise(N, 48, 48, 62) - 0.7, 0, 1)
paper = paper * (1 - stain[..., None] * 0.12)
save_rgb("notice_paper", paper)
print("wrote textures to", OUT)
