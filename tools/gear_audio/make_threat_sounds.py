#!/usr/bin/env python3
"""Synthesize the original headset threat cues (TASKS item 22, PR B).

Procedural, no samples or third-party sources. One sound per file, mono PCM16 44.1 kHz.
Deterministic (fixed seeds), so re-running reproduces identical bytes.
Usage: python3 tools/gear_audio/make_threat_sounds.py raid/audio/threat
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
    # one-pole low-pass
    alpha = 1.0 - np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x); acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc); y[i] = acc
    return y

def turret_servo_whine():
    d = 0.7; t = np.arange(int(d * SR)) / SR
    f = 520 + 380 * np.sin(np.pi * t / d) ** 0.7          # motor rises then settles
    ph = 2 * np.pi * np.cumsum(f) / SR
    tone = 0.55 * np.sin(ph) + 0.25 * np.sin(2 * ph) + 0.12 * np.sin(3.01 * ph)
    gear_tick = 0.18 * np.sign(np.sin(2 * np.pi * 38 * t)) * (np.sin(ph * 0.5) > 0.6)
    return (tone + lowpass(gear_tick, 2500)) * env(len(t), 0.03, 0.15)

def turret_warmup_tone():
    d = 0.9; t = np.arange(int(d * SR)) / SR
    f = 700 * (2.2 ** (t / d))                              # rising charge, 0.9 s = turret warmup
    ph = 2 * np.pi * np.cumsum(f) / SR
    pulse = 0.5 + 0.5 * np.sign(np.sin(2 * np.pi * (6 + 18 * t / d) * t))
    tone = (0.5 * np.sin(ph) + 0.2 * np.sin(2 * ph)) * (0.55 + 0.45 * pulse)
    return tone * env(len(t), 0.02, 0.06)

def turret_shot():
    rng = np.random.default_rng(22)
    d = 0.45; n = int(d * SR); t = np.arange(n) / SR
    crack = rng.standard_normal(n) * np.exp(-t * 55)
    thump = np.sin(2 * np.pi * (140 * np.exp(-t * 9)) * t) * np.exp(-t * 14)
    tail = lowpass(rng.standard_normal(n), 900) * np.exp(-t * 9) * 2.5
    return (0.55 * lowpass(crack, 6000) + 0.7 * thump + 0.35 * tail) * env(n, 0.001, 0.08)

def live_cable_crackle():
    rng = np.random.default_rng(7)
    d = 1.0; n = int(d * SR); t = np.arange(n) / SR
    hum = 0.18 * np.sin(2 * np.pi * 60 * t) + 0.1 * np.sin(2 * np.pi * 180 * t)
    sparks = np.zeros(n)
    for start in np.sort(rng.uniform(0, d - 0.06, 14)):
        i = int(start * SR); m = int(rng.uniform(0.008, 0.05) * SR)
        burst = rng.standard_normal(m) * np.exp(-np.arange(m) / (m / 4)) * rng.uniform(0.4, 1.0)
        sparks[i:i + m] += burst
    buzz = 0.25 * np.sign(np.sin(2 * np.pi * 120 * t)) * (0.4 + 0.6 * rng.random(n) ** 3)
    return (hum + lowpass(buzz, 3000) + 0.6 * lowpass(sparks, 7000)) * env(n, 0.04, 0.12)

SOUNDS = {"turret_servo_whine": turret_servo_whine, "turret_warmup_tone": turret_warmup_tone,
          "turret_shot": turret_shot, "live_cable_crackle": live_cable_crackle}

def write(path, x):
    x = x / max(1e-9, np.max(np.abs(x))) * 0.7          # peak -3.1 dBFS
    data = (np.clip(x, -1, 1) * 32767).astype("<i2").tobytes()
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data)

if __name__ == "__main__":
    out = Path(sys.argv[1]); out.mkdir(parents=True, exist_ok=True)
    for name, fn in SOUNDS.items():
        write(out / f"{name}.wav", fn()); print("wrote", out / f"{name}.wav")
