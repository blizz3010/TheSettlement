#!/usr/bin/env python3
"""Synthesize the original raid loot cues (TASKS item 13).

Procedural, no samples or third-party sources. One sound per file, mono PCM16 44.1 kHz.
Deterministic (fixed seeds), so re-running reproduces identical bytes.
Usage: python3 tools/loot_audio/make_loot_sounds.py raid/audio/loot
"""
import sys, wave
from pathlib import Path
import numpy as np

SR = 44100

def env(n, attack, release):
    e = np.ones(n)
    a = max(1, int(attack * SR)); r = max(1, int(release * SR))
    e[:a] = np.linspace(0, 1, a)
    e[-r:] *= np.linspace(1, 0, r)
    return e

def lowpass(x, cutoff):
    alpha = 1.0 - np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x); acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc); y[i] = acc
    return y

def click(n, at, length, rng, cutoff, gain):
    out = np.zeros(n); i = int(at * SR); m = int(length * SR)
    burst = rng.standard_normal(m) * np.exp(-np.arange(m) / (m / 5)) * gain
    out[i:i + m] += lowpass(burst, cutoff)[: max(0, min(m, n - i))]
    return out

def loot_cache_open():
    """Metal latch snap, then a short hinge creak and a lid thump (0.75 s)."""
    rng = np.random.default_rng(13)
    d = 0.75; n = int(d * SR); t = np.arange(n) / SR
    latch = click(n, 0.0, 0.03, rng, 6500, 1.0) + click(n, 0.045, 0.025, rng, 5000, 0.7)
    creak_t = np.clip((t - 0.09) / 0.38, 0, 1)
    f = 310 + 140 * np.sin(np.pi * creak_t) + 25 * np.sin(2 * np.pi * 11 * t)
    ph = 2 * np.pi * np.cumsum(f) / SR
    creak = (0.30 * np.sign(np.sin(ph)) * (np.sin(np.pi * creak_t) ** 2)) * ((t > 0.09) & (t < 0.47))
    thump = np.sin(2 * np.pi * (95 * np.exp(-(t - 0.5).clip(0) * 6)) * t) * np.exp(-(t - 0.5).clip(0) * 18) * (t > 0.5)
    return (0.8 * latch + lowpass(creak, 2200) + 0.75 * thump) * env(n, 0.001, 0.08)

def loot_pickup():
    """Soft canvas rustle with a small parts rattle (0.42 s)."""
    rng = np.random.default_rng(29)
    d = 0.42; n = int(d * SR); t = np.arange(n) / SR
    rustle = lowpass(rng.standard_normal(n), 2600) * np.sin(np.pi * np.clip(t / 0.3, 0, 1)) * (t < 0.3) * 1.6
    rattle = np.zeros(n)
    for at in (0.12, 0.17, 0.205, 0.24):
        rattle += click(n, at, 0.012, rng, 8000, rng.uniform(0.35, 0.6))
    tone = 0.12 * np.sin(2 * np.pi * 1850 * t) * np.exp(-(t - 0.12).clip(0) * 30) * (t > 0.12)
    return (0.55 * rustle + rattle + tone) * env(n, 0.01, 0.07)

def loot_drop():
    """Dull bundle hitting the ground (0.38 s)."""
    rng = np.random.default_rng(41)
    d = 0.38; n = int(d * SR); t = np.arange(n) / SR
    thud = np.sin(2 * np.pi * (120 * np.exp(-t * 7)) * t) * np.exp(-t * 16)
    dirt = lowpass(rng.standard_normal(n), 1400) * np.exp(-t * 22) * 1.4
    return (0.9 * thud + 0.5 * dirt) * env(n, 0.002, 0.06)

SOUNDS = {"loot_cache_open": loot_cache_open, "loot_pickup": loot_pickup, "loot_drop": loot_drop}

def write(path, x):
    x = x / max(1e-9, np.max(np.abs(x))) * 0.7          # peak -3.1 dBFS
    data = (np.clip(x, -1, 1) * 32767).astype("<i2").tobytes()
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data)

if __name__ == "__main__":
    out = Path(sys.argv[1]); out.mkdir(parents=True, exist_ok=True)
    for name, fn in SOUNDS.items():
        write(out / f"{name}.wav", fn()); print("wrote", out / f"{name}.wav")
