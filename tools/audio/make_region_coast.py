#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
make_region_coast.py — leito REGIONAL da familia Costa (saltwind_shore, castaway_sandbar,
salt_split_isle).

Direção (COAST_AUDIO_DROPIN): LIMIAR / HORIZONTE / AR ABERTO. O oposto da Caverna (fechada).
Deve reforcar vento salgado / distancia / agua distante / madeira-barco em repouso / abertura /
SOLTAR — SEM soar como praia alegre, musica, porto movimentado, tempestade, UI ou loop obvio.

Como (mesma base, em CAMADAS periodicas via iFFT => loop sem costura):
  1) VENTO SALGADO ABERTO : ruido pink CLARO (inclinacao suave), passa-alta ~60 Hz, presenca
                            ate ~5 kHz mas dull no topo => ar aberto/vento; STEADY (sem rajada=>sem tempestade).
  2) AGUA DISTANTE        : banda ~150-700 Hz com SWELL lento e suave (cabos 2/3/4 ciclos) =>
                            surf de LONGE que respira (soltar), SEM ondas batendo (sem evento=>sem praia/porto).
  3) MADEIRA EM REPOUSO   : 2 ressonancias amadeiradas faint e ESTATICAS (~150/240 Hz) =>
                            estrutura de barco presente, em REPOUSO (sem rangido-evento).
Mais aberto/claro que global e caverna; respira (mais que a caverna), mas calmo (nao "vivo" como a cidade).

NOTA: encoder Ogg/Vorbis do libsndfile estoura a pilha em >~16s => 16s (seamless). Requer numpy+soundfile.
"""
import os
import numpy as np
import soundfile as sf

SR = 44100
DURATION = 16.0
SEED = 67
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio", "ambient", "region_coast.ogg")

PEAK = 0.92
W_WIND, W_WATER, W_WOOD = 1.0, 0.7, 0.14


def _smoothstep(x):
    x = np.clip(x, 0.0, 1.0)
    return x * x * (3.0 - 2.0 * x)


def _noise_from_env(env, rng):
    phase = rng.uniform(0.0, 2.0 * np.pi, size=env.shape)
    return np.fft.irfft(env * np.exp(1j * phase), n=(len(env) - 1) * 2)


def _wind_env(freqs):
    # ar aberto: pink claro, presenca ampla mas topo dull (sem chiado=UI, sem rajada=tempestade)
    env = np.zeros_like(freqs)
    nz = freqs > 0
    env[nz] = (freqs[nz] / 100.0) ** (-0.85)            # mais claro que global (mais "aberto")
    env *= _smoothstep((freqs - 55.0) / (110.0 - 55.0))  # passa-alta
    env /= np.sqrt(1.0 + (freqs / 4800.0) ** (2.0 * 2.0))  # passa-baixa alta e suave (ar, nao hiss)
    env[0] = 0.0
    return env


def _water_env(freqs):
    # surf distante: banda larga media-grave (sem agudo de respingo => sem praia)
    fc, bw = 340.0, 0.95
    env = np.zeros_like(freqs)
    nz = freqs > 0
    env[nz] = np.exp(-((np.log(freqs[nz]) - np.log(fc)) / bw) ** 2)
    env *= _smoothstep((freqs - 110.0) / (180.0 - 110.0))
    env /= np.sqrt(1.0 + (freqs / 900.0) ** (2.0 * 2.5))
    env[0] = 0.0
    return env


def _wood_env(freqs):
    # barco em repouso: ressonancias amadeiradas faint (estaticas, sem rangido-evento)
    env = np.zeros_like(freqs)
    nz = freqs > 0
    for fc, w, a in [(150.0, 0.45, 1.0), (240.0, 0.45, 0.6)]:
        env[nz] += a * np.exp(-((np.log(freqs[nz]) - np.log(fc)) / w) ** 2)
    env[0] = 0.0
    return env


def _swell(n, rng):
    """Surf de longe que RESPIRA (soltar): swell lento e suave, periodico em n. Sem onda batendo."""
    t = np.arange(n) / SR
    D = n / SR
    m = np.ones(n)
    for cycles, amp in [(2, 0.22), (3, 0.13), (4, 0.07)]:
        ph = rng.uniform(0.0, 2.0 * np.pi)
        m += amp * np.sin(2.0 * np.pi * cycles * t / D + ph)
    return np.clip(m, 0.5, 1.6)


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
        wind = _layer(_wind_env, n, rng)
        water = _norm(_layer(_water_env, n, rng) * _swell(n, rng))  # respira (soltar)
        wood = _layer(_wood_env, n, rng)
        return W_WIND * wind + W_WATER * water + W_WOOD * wood

    stereo = np.stack([build_channel(rng), build_channel(rng)], axis=1)
    stereo *= (PEAK / float(np.max(np.abs(stereo))))

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    sf.write(OUT, stereo.astype(np.float32), SR, format="OGG", subtype="VORBIS")

    rms = float(np.sqrt(np.mean(stereo ** 2)))
    rms_db = 20.0 * np.log10(rms + 1e-12)
    size = os.path.getsize(OUT)
    print("region_coast.ogg gerado:")
    print("  path : %s" % os.path.normpath(OUT))
    print("  dur  : %.1fs | sr=%d | stereo | loop periodico (sem costura)" % (DURATION, SR))
    print("  peak : %.3f | RMS: %.1f dBFS | size: %.1f KB" % (PEAK, rms_db, size / 1024.0))
    print("  play : WorldAmbience regional a -20 dB. RMS efetivo ~ %.0f dBFS (aberto/horizonte)" % (rms_db - 20.0))


if __name__ == "__main__":
    main()
