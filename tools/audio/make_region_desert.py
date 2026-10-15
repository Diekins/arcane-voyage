#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
make_region_desert.py — leito REGIONAL da familia Deserto ABERTO (khet_sar_sands, khet_oasis,
khet_caravan_camp e demais mapeadas como "desert"). Fecha a 1a base sonora regional.

Direção (DESERT_AUDIO_DROPIN): AMPLO, SECO, DISTANTE. Deve reforcar ar quente / areia fina /
espaco aberto / distancia / solidao / travessia / CALOR PARADO — SEM tempestade de areia,
musica, tensao de combate, vazio tecnico, VENTO FRIO, UI ou loop obvio.

Como (mesma base, em CAMADAS periodicas via iFFT => loop sem costura):
  1) AR QUENTE (calor parado): leito warm low-mid (pink/brown), passa-baixa ~1.8 kHz =>
                               QUENTE (nao frio), amplo mas nao brilhante. Deriva quase NULA
                               (calor parado: o mais ESTATICO de todos os leitos => solidao/distancia).
  2) AREIA FINA (seco)       : sheen alto-medio (~3.5 kHz) FAINT, com leve shimmer lento =>
                               graos secos; band-limitado e baixo (sem rajada=tempestade,
                               sem chiado forte=UI, sem brilho=vento frio).
Mais aberto que a Caverna, mais SECO que a Costa (sem swell de agua), MENOS vivo que a Cidade
(sem murmurio), MENOS organico que a Floresta (sem folhas/vida). Warm + amplo + quase imovel.

NOTA: encoder Ogg/Vorbis do libsndfile estoura a pilha em >~16s => 16s (seamless). Requer numpy+soundfile.
"""
import os
import numpy as np
import soundfile as sf

SR = 44100
DURATION = 16.0
SEED = 113
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio", "ambient", "region_desert.ogg")

PEAK = 0.92
W_AIR, W_SAND = 1.0, 0.05   # areia bem FAINT => warm/calor parado domina (slot quente, abaixo da Floresta)


def _smoothstep(x):
    x = np.clip(x, 0.0, 1.0)
    return x * x * (3.0 - 2.0 * x)


def _noise_from_env(env, rng):
    phase = rng.uniform(0.0, 2.0 * np.pi, size=env.shape)
    return np.fft.irfft(env * np.exp(1j * phase), n=(len(env) - 1) * 2)


def _air_env(freqs):
    # ar QUENTE (nao frio): warm low-mid, amplo mas nao brilhante
    env = np.zeros_like(freqs)
    nz = freqs > 0
    env[nz] = (freqs[nz] / 100.0) ** (-1.1)
    env *= _smoothstep((freqs - 32.0) / (70.0 - 32.0))
    env /= np.sqrt(1.0 + (freqs / 1500.0) ** (2.0 * 2.2))   # passa-baixa morna (aberto, sem brilho frio)
    env[0] = 0.0
    return env


def _sand_env(freqs):
    # areia fina (seco): sheen alto-medio faint, band-limitado (sem chiado forte de UI)
    fc, bw = 3500.0, 0.6
    env = np.zeros_like(freqs)
    nz = freqs > 0
    env[nz] = np.exp(-((np.log(freqs[nz]) - np.log(fc)) / bw) ** 2)
    env /= np.sqrt(1.0 + (freqs / 6500.0) ** (2.0 * 2.0))
    env[0] = 0.0
    return env


def _heat_still(n, rng):
    """CALOR PARADO: deriva quase NULA (o mais estatico dos leitos), periodica em n. Solidao/distancia."""
    t = np.arange(n) / SR
    D = n / SR
    m = np.ones(n)
    for cycles, amp in [(1, 0.04), (2, 0.025)]:
        ph = rng.uniform(0.0, 2.0 * np.pi)
        m += amp * np.sin(2.0 * np.pi * cycles * t / D + ph)
    return m


def _sand_shimmer(n, rng):
    """Areia fina: shimmer LENTO e suave (graos), periodico em n. Sem rajada (sem tempestade)."""
    t = np.arange(n) / SR
    D = n / SR
    m = np.ones(n)
    for cycles, amp in [(2, 0.12), (3, 0.08), (5, 0.05)]:
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
        air = _layer(_air_env, n, rng) * _heat_still(n, rng)     # calor parado
        sand = _norm(_layer(_sand_env, n, rng) * _sand_shimmer(n, rng))  # graos secos
        return W_AIR * _norm(air) + W_SAND * sand

    stereo = np.stack([build_channel(rng), build_channel(rng)], axis=1)
    stereo *= (PEAK / float(np.max(np.abs(stereo))))

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    sf.write(OUT, stereo.astype(np.float32), SR, format="OGG", subtype="VORBIS")

    rms = float(np.sqrt(np.mean(stereo ** 2)))
    rms_db = 20.0 * np.log10(rms + 1e-12)
    size = os.path.getsize(OUT)
    print("region_desert.ogg gerado:")
    print("  path : %s" % os.path.normpath(OUT))
    print("  dur  : %.1fs | sr=%d | stereo | loop periodico (sem costura)" % (DURATION, SR))
    print("  peak : %.3f | RMS: %.1f dBFS | size: %.1f KB" % (PEAK, rms_db, size / 1024.0))
    print("  play : WorldAmbience regional a -20 dB. RMS efetivo ~ %.0f dBFS (amplo/seco/calor parado)" % (rms_db - 20.0))


if __name__ == "__main__":
    main()
