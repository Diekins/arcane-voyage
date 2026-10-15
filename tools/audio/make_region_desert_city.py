#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
make_region_desert_city.py — leito REGIONAL da Cidade do Deserto (khet_sar_city).

Direção (DESERT_CITY_AUDIO_DROPIN): "viva, mas nao performatica". Diapasao = VITALIDADE
indiferente (a cidade segue sem voce). Deve comunicar caldo distante / movimento humano
agregado / calor / tecidos / ar seco / trafego — SEM soar como musica, festa, feira
caricatural ou multidao obvia em loop. NADA de vozes/palavras reconheciveis, nada de
batida, nada de evento.

Como (mesma base do global_bed, em CAMADAS, todas periodicas via iFFT => loop sem costura):
  1) BASE QUENTE  : ruido pink/brown grave-medio = calor + ar seco + distancia.
  2) MURMURIO     : ruido na banda da FALA (~400-2200 Hz) BORRADO (sem tom, sem palavra)
                    modulado por uma DERIVA lenta e irregular (ebb de multidao = trafego),
                    presente mas em 2o plano (nao faz "show"). E o "movimento humano agregado".
  3) AR/TECIDOS   : leve sopro medio-agudo (~3-6 kHz), bem baixo = tecidos/ar seco, sem chiado.
Densidade > global_bed (banda mais larga), porem coerente com o player regional (-20 dB).

NOTA: o encoder Ogg/Vorbis do libsndfile (soundfile) estoura a pilha em conteudo >~16s
deste tipo => 16s. Como e textura sem evento, o loop e imperceptivel. Requer numpy+soundfile.
"""
import os
import numpy as np
import soundfile as sf

SR = 44100
DURATION = 16.0
SEED = 23
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio", "ambient", "region_desert_city.ogg")

PEAK = 0.92
# nivel relativo das camadas (mix): base quente domina, murmurio em 2o plano, ar faint
W_WARM, W_MURMUR, W_AIR = 1.0, 0.62, 0.16


def _smoothstep(x):
    x = np.clip(x, 0.0, 1.0)
    return x * x * (3.0 - 2.0 * x)


def _noise_from_env(env, rng):
    phase = rng.uniform(0.0, 2.0 * np.pi, size=env.shape)
    return np.fft.irfft(env * np.exp(1j * phase), n=(len(env) - 1) * 2)


def _warm_env(freqs):
    env = np.zeros_like(freqs)
    nz = freqs > 0
    env[nz] = (freqs[nz] / 100.0) ** (-1.05)            # inclinacao pink (calor)
    env *= _smoothstep((freqs - 35.0) / (75.0 - 35.0))  # passa-alta (sem rumble)
    env /= np.sqrt(1.0 + (freqs / 1100.0) ** (2.0 * 2.2))  # passa-baixa (distancia/dull)
    env[0] = 0.0
    return env


def _murmur_env(freqs):
    # bump log-normal na banda da fala, BORRADO e largo (sem formante/tom => sem palavra)
    fc, bw = 950.0, 0.9
    env = np.zeros_like(freqs)
    nz = freqs > 0
    env[nz] = np.exp(-((np.log(freqs[nz]) - np.log(fc)) / bw) ** 2)
    env *= _smoothstep((freqs - 280.0) / (430.0 - 280.0))      # corta grave (some na base)
    env /= np.sqrt(1.0 + (freqs / 2300.0) ** (2.0 * 3.0))      # corta agudo (sem sibilancia=palavra)
    env[0] = 0.0
    return env


def _air_env(freqs):
    fc, bw = 4200.0, 0.7
    env = np.zeros_like(freqs)
    nz = freqs > 0
    env[nz] = np.exp(-((np.log(freqs[nz]) - np.log(fc)) / bw) ** 2)
    env[0] = 0.0
    return env


def _crowd_drift(n, rng):
    """Deriva LENTA e irregular do murmurio (ebb de multidao/trafego). Periodica em n
    (ciclos inteiros no buffer) => loop perfeito. Lenta o bastante p/ ser ONDULAR, nao pulso."""
    t = np.arange(n) / SR
    D = n / SR
    m = np.ones(n)
    for cycles, amp in [(2, 0.18), (3, 0.12), (5, 0.08), (7, 0.05)]:
        ph = rng.uniform(0.0, 2.0 * np.pi)
        m += amp * np.sin(2.0 * np.pi * cycles * t / D + ph)
    return np.clip(m, 0.45, 1.6)


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
        warm = _layer(_warm_env, n, rng)
        murmur = _layer(_murmur_env, n, rng) * _crowd_drift(n, rng)  # movimento humano agregado
        murmur = _norm(murmur)
        air = _layer(_air_env, n, rng)
        mix = W_WARM * warm + W_MURMUR * murmur + W_AIR * air
        return mix

    left = build_channel(rng)
    right = build_channel(rng)   # canais independentes => campo largo (cidade ao redor)

    stereo = np.stack([left, right], axis=1)
    stereo *= (PEAK / float(np.max(np.abs(stereo))))

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    sf.write(OUT, stereo.astype(np.float32), SR, format="OGG", subtype="VORBIS")

    rms = float(np.sqrt(np.mean(stereo ** 2)))
    rms_db = 20.0 * np.log10(rms + 1e-12)
    size = os.path.getsize(OUT)
    print("region_desert_city.ogg gerado:")
    print("  path : %s" % os.path.normpath(OUT))
    print("  dur  : %.1fs | sr=%d | stereo | loop periodico (sem costura)" % (DURATION, SR))
    print("  peak : %.3f | RMS: %.1f dBFS | size: %.1f KB" % (PEAK, rms_db, size / 1024.0))
    print("  play : WorldAmbience regional a -20 dB. RMS efetivo ~ %.0f dBFS (denso > global)" % (rms_db - 20.0))


if __name__ == "__main__":
    main()
