#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
make_breaths.py — CAMADA 3 ("respiros do mundo"): one-shots CURTOS, raros, por FAMÍLIA de região.
Os leitos (camadas 1-2) dizem "o lugar existe"; os respiros dizem "algo aconteceu".
NÃO são loops. Subtis, contemplativos. Saem em godot/assets/audio/ambient/breaths/<chave>_1.ogg.

Chaves = famílias do WorldAmbience: coast / forest / desert / cave_stone.
Cada um: gota/estalo/rajada/rangido — curto, com envelope (ataque+decay), normalizado moderado
(o player toca a -14 dB + atenuação por distância). Conteúdo curto → encoder Ogg/Vorbis ok.
Requer numpy + soundfile.
"""
import os
import numpy as np
import soundfile as sf

SR = 44100
OUTDIR = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio", "ambient", "breaths")


def _norm(x, peak):
    p = float(np.max(np.abs(x)))
    return x * (peak / p) if p > 0 else x


def _bump(f, fc, bw):
    e = np.zeros_like(f)
    nz = f > 0
    e[nz] = np.exp(-((np.log(f[nz]) - np.log(fc)) / bw) ** 2)
    return e


def _shaped_noise(n, env, rng):
    ph = rng.uniform(0.0, 2.0 * np.pi, size=env.shape)
    return np.fft.irfft(env * np.exp(1j * ph), n=n)


def _gauss(t, c, w):
    return np.exp(-((t - c) / w) ** 2)


def coast_creak(rng):   # madeira rangendo ao longe (stick-slip grave/resonante)
    n = int(1.2 * SR)
    t = np.arange(n) / SR
    f = np.fft.rfftfreq(n, 1.0 / SR)
    env = _bump(f, 230.0, 0.5) + 0.5 * _bump(f, 470.0, 0.4)   # ressonância amadeirada
    sig = _shaped_noise(n, env, rng)
    amp = 0.5 * _gauss(t, 0.30, 0.10) + _gauss(t, 0.60, 0.13) + 0.6 * _gauss(t, 0.88, 0.09)  # stick-slip
    amp *= np.clip(1.0 - (t - 1.0) / 0.2, 0.0, 1.0)   # fade final
    return _norm(sig * amp, 0.62)


def forest_crack(rng):  # galho estalando distante (transiente curto médio-agudo)
    n = int(0.30 * SR)
    t = np.arange(n) / SR
    f = np.fft.rfftfreq(n, 1.0 / SR)
    env = _bump(f, 1500.0, 0.85)
    sig = _shaped_noise(n, env, rng)
    amp = np.exp(-t / 0.045)                      # ataque imediato + decaimento rápido
    amp += 0.35 * np.exp(-np.abs(t - 0.06) / 0.02)  # um segundo estalinho
    return _norm(sig * amp, 0.78)


def desert_gust(rng):   # rajada curta de vento / areia
    n = int(1.7 * SR)
    t = np.arange(n) / SR
    f = np.fft.rfftfreq(n, 1.0 / SR)
    env = _bump(f, 750.0, 1.1) + 0.3 * _bump(f, 2600.0, 0.6)   # corpo + grão de areia
    sig = _shaped_noise(n, env, rng)
    x = t / (n / SR)
    amp = np.sin(np.pi * np.clip(x, 0, 1)) ** 1.5             # sobe e desce (rajada)
    return _norm(sig * amp, 0.58)


def cave_drip(rng):     # gota isolada (plip com glide de pitch + eco curto da caverna)
    n = int(0.55 * SR)
    t = np.arange(n) / SR
    def plip(t0, gain):
        tt = t - t0
        m = tt >= 0
        fr = 1100.0 * np.exp(-np.clip(tt, 0, None) / 0.05) + 600.0   # glide 1700→600 Hz
        ph = 2.0 * np.pi * np.cumsum(np.where(m, fr, 0.0)) / SR
        a = np.where(m, np.exp(-np.clip(tt, 0, None) / 0.035), 0.0)
        return gain * np.sin(ph) * a
    sig = plip(0.0, 1.0) + plip(0.16, 0.4)   # gota + eco fraco
    return _norm(sig, 0.7)


def main():
    os.makedirs(OUTDIR, exist_ok=True)
    jobs = {
        "coast": (coast_creak, 3),
        "forest": (forest_crack, 5),
        "desert": (desert_gust, 7),
        "cave_stone": (cave_drip, 11),
    }
    for key, (fn, seed) in jobs.items():
        sig = fn(np.random.default_rng(seed)).astype(np.float32)
        path = os.path.join(OUTDIR, key + "_1.ogg")
        sf.write(path, sig, SR, format="OGG", subtype="VORBIS")
        dur = len(sig) / SR
        print("%-12s -> %s  (%.2fs, %.0fKB)" % (key, os.path.basename(path), dur, os.path.getsize(path) / 1024.0))


if __name__ == "__main__":
    main()
