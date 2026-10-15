#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
make_region_forest.py — leito REGIONAL da familia Floresta (ashen_grove, deep_grove,
ancient_root_nest).

Direção (FOREST_AUDIO_DROPIN): VIVA, mas CONTIDA. Densidade organica sob copa.
Deve reforcar folhas / ar entre galhos / pequenos movimentos distantes / sombra vegetal /
vida escondida / densidade organica — SEM floresta alegre generica, trilha musical, selva
caricatural, passaros repetitivos, UI ou terror.

Como (mesma base, em CAMADAS periodicas via iFFT => loop sem costura):
  1) SOMBRA VEGETAL  : ruido pink medio-grave, passa-baixa ~2.2 kHz (ABAFADO sob copa =>
                       contido, menos aberto que a Costa; nada de brilho de ceu aberto). Base organica.
  2) FOLHAS/AR       : banda alto-media (~2.6 kHz) com FLUTTER suave e irregular => folhas/ar
                       entre galhos; band-limitada e contida (sem chiado=UI, sem rajada=vento aberto).
  3) VIDA ESCONDIDA  : banda media (~800 Hz) com estimulo LENTO e irregular (varios LFOs
                       incomensuraveis) => pequenos movimentos distantes que ESTIMULAM sem virar
                       evento/passaro (sem tom, sem pulso claro). Faint.
Mais organica que o global, MENOS aberta que a Costa, MENOS grave que a Caverna. Viva mas contida.

NOTA: encoder Ogg/Vorbis do libsndfile estoura a pilha em >~16s => 16s (seamless). Requer numpy+soundfile.
"""
import os
import numpy as np
import soundfile as sf

SR = 44100
DURATION = 16.0
SEED = 89
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio", "ambient", "region_forest.ogg")

PEAK = 0.92
W_SHADE, W_LEAVES, W_LIFE = 1.0, 0.26, 0.30   # folhas mais contidas => mais escuro/sob-copa (gap claro p/ a Costa)


def _smoothstep(x):
    x = np.clip(x, 0.0, 1.0)
    return x * x * (3.0 - 2.0 * x)


def _noise_from_env(env, rng):
    phase = rng.uniform(0.0, 2.0 * np.pi, size=env.shape)
    return np.fft.irfft(env * np.exp(1j * phase), n=(len(env) - 1) * 2)


def _shade_env(freqs):
    # sombra vegetal: pink medio-grave, ABAFADO (passa-baixa baixa = contido sob copa)
    env = np.zeros_like(freqs)
    nz = freqs > 0
    env[nz] = (freqs[nz] / 100.0) ** (-1.0)
    env *= _smoothstep((freqs - 45.0) / (95.0 - 45.0))
    env /= np.sqrt(1.0 + (freqs / 2200.0) ** (2.0 * 2.5))   # copa abafa o topo
    env[0] = 0.0
    return env


def _leaves_env(freqs):
    # folhas/ar entre galhos: banda alto-media contida (sem chiado de UI)
    fc, bw = 2200.0, 0.7
    env = np.zeros_like(freqs)
    nz = freqs > 0
    env[nz] = np.exp(-((np.log(freqs[nz]) - np.log(fc)) / bw) ** 2)
    env /= np.sqrt(1.0 + (freqs / 4000.0) ** (2.0 * 2.0))   # corta o chiado mais alto (mais sob copa)
    env[0] = 0.0
    return env


def _life_env(freqs):
    # vida escondida: banda media (pequenos movimentos), sem tom/formante (sem passaro)
    fc, bw = 800.0, 0.85
    env = np.zeros_like(freqs)
    nz = freqs > 0
    env[nz] = np.exp(-((np.log(freqs[nz]) - np.log(fc)) / bw) ** 2)
    env[0] = 0.0
    return env


def _flutter(n, rng):
    """Folhas/ar: flutter suave e irregular, periodico em n. Gentil (sem rajada)."""
    t = np.arange(n) / SR
    D = n / SR
    m = np.ones(n)
    for cycles, amp in [(3, 0.16), (5, 0.11), (8, 0.07)]:
        ph = rng.uniform(0.0, 2.0 * np.pi)
        m += amp * np.sin(2.0 * np.pi * cycles * t / D + ph)
    return np.clip(m, 0.4, 1.7)


def _stir(n, rng):
    """Vida escondida: estimulo lento e IRREGULAR (LFOs incomensuraveis), periodico em n.
    Pequenos movimentos que estimulam sem virar evento/pulso reconhecivel."""
    t = np.arange(n) / SR
    D = n / SR
    m = np.ones(n)
    for cycles, amp in [(2, 0.20), (3, 0.14), (5, 0.10), (7, 0.07)]:
        ph = rng.uniform(0.0, 2.0 * np.pi)
        m += amp * np.sin(2.0 * np.pi * cycles * t / D + ph)
    return np.clip(m, 0.35, 1.7)


def _norm(x):
    p = float(np.max(np.abs(x)))
    return x / p if p > 0 else x


def _layer(env_fn, n, rng):
    freqs = np.fft.rfftfreq(n, 1.0 / SR)
    return _norm(_noise_from_env(env_fn(freqs), rng))


def main():
    rng = np.random.default_rng(SEED)
    n = int(round(DURATION * SR))

    def build_channel(rng):
        shade = _layer(_shade_env, n, rng)
        leaves = _norm(_layer(_leaves_env, n, rng) * _flutter(n, rng))
        life = _norm(_layer(_life_env, n, rng) * _stir(n, rng))
        return W_SHADE * shade + W_LEAVES * leaves + W_LIFE * life

    stereo = np.stack([build_channel(rng), build_channel(rng)], axis=1)
    stereo *= (PEAK / float(np.max(np.abs(stereo))))

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    sf.write(OUT, stereo.astype(np.float32), SR, format="OGG", subtype="VORBIS")

    rms = float(np.sqrt(np.mean(stereo ** 2)))
    rms_db = 20.0 * np.log10(rms + 1e-12)
    size = os.path.getsize(OUT)
    print("region_forest.ogg gerado:")
    print("  path : %s" % os.path.normpath(OUT))
    print("  dur  : %.1fs | sr=%d | stereo | loop periodico (sem costura)" % (DURATION, SR))
    print("  peak : %.3f | RMS: %.1f dBFS | size: %.1f KB" % (PEAK, rms_db, size / 1024.0))
    print("  play : WorldAmbience regional a -20 dB. RMS efetivo ~ %.0f dBFS (organica/contida)" % (rms_db - 20.0))


if __name__ == "__main__":
    main()
