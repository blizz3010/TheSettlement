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

# Ivory ceramic hull paint: warm cream, panel grooves, grimy edges, fine orange-peel.
h = fnoise(N, 28, 28, 11) * 0.012 + fnoise(N, 8, 8, 12) * 0.006
h += panel_lines(N, 8, 2.2, 13) * 0.045
# rivet bumps along the panel lines
yy, xx = grid(N)
riv = np.zeros((N, N))
for i in range(8):
    for j in range(16):
        cy = (i + .5) / 8; cx = (j + .5) / 16
        d2 = ((xx - cx) * N) ** 2 + ((yy - cy) * N) ** 2
        riv += np.exp(-d2 / 4.5) * 0.04
h += riv
grime = np.clip(fnoise(N, 40, 18, 14) * 0.5 + 0.15, 0, 1)
base = (0.92 + h * 4 + fnoise(N, 6, 6, 15) * 0.03)[..., None] * hexc("d9d0c0")
base = base * (1 - 0.18 * grime[..., None] * hexc("5a4a38")[None, None, :] / (base + 1e-6))
# slightly cooler in recesses
base = base * (1 + h[..., None] * 0.8)
save_rgb("hull_ivory", base)
save_n("hull_ivory", h + riv, 3.2)

# Worn ochre livery / heat-stained accent.
h2 = fnoise(N, 24, 24, 21) * 0.014 + panel_lines(N, 6, 2.0, 22) * 0.03
fade = np.clip(0.55 + fnoise(N, 36, 20, 23) * 0.35, 0, 1)
och = (0.85 + h2 * 3)[..., None] * hexc("b68a4a")
och = och * fade[..., None] + hexc("6a4e2c")[None, None, :] * (1 - fade[..., None]) * 0.35
save_rgb("hull_ochre", och)
save_n("hull_ochre", h2, 2.6)

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
