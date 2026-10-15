#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
make_region_cave_stone.py — leito REGIONAL da familia Caverna/Pedra (cave, swamp_pit).

Direção (CAVE_STONE_AUDIO_DROPIN): "o silencio virou pedra e distancia, nao vazio tecnico".
Casa com Cave Memory (a Memoria Petrificada). Deve reforcar frio mineral / profundidade /
pedra / ar parado / memoria petrificada / distancia subterranea — SEM soar como terror,
dungeon generica, suspense de boss, musica, vento externo, UI ou efeito magico.

Como (mesma base dos outros leitos, em CAMADAS periodicas via iFFT => loop sem costura):
  1) LEITO FECHADO : ruido grave/grave-medio brown, passa-alta suave, passa-baixa BAIXA
                     (~600 Hz) => fechado, dull, SEM agudo (nada de vento externo). = pedra/ar parado/frio.
  2) RESSONANCIA OCA: 3 bumps log-normal MUITO graves e NAO-harmonicos (58/91/137 Hz),
                     largos e faint => sensacao de cavidade de pedra (profundidade/distancia)
                     SEM virar tom/nota (nao-harmonico + largo = espaco, nao acorde => sem suspense).
  3) (sem camada de ar/agudo: caverna e FECHADA; o frio vem da AUSENCIA de calor, nao de agudo.)
Modulacao quase NULA (ar parado): deriva lenta e rasa so p/ nao ser loop morto. MENOS viva que a Cidade.

NOTA: encoder Ogg/Vorbis do libsndfile estoura a pilha em >~16s deste tipo => 16s (seamless,
sem evento => loop imperceptivel). Requer numpy+soundfile.
"""
import os
import numpy as np
import soundfile as sf

SR = 44100
DURATION = 16.0
SEED = 41
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio", "ambient", "region_cave_stone.ogg")

PEAK = 0.90
# leito fechado domina; ressonancia oca faint. SEM camada de agudo (fechada).
W_BED, W_HOLLOW = 1.0, 0.5
# alvo um pouco MAIS RESERVADO que a Cidade ("menos viva"): atenuacao final do mix
RESERVE = 0.80


def _smoothstep(x):
    x = np.clip(x, 0.0, 1.0)
    return x * x * (3.0 - 2.0 * x)


def _noise_from_env(env, rng):
    phase = rng.uniform(0.0, 2.0 * np.pi, size=env.shape)
    return np.fft.irfft(env * np.exp(1j * phase), n=(len(env) - 1) * 2)


def _bed_env(freqs):
    # grave/grave-medio brown, FECHADO (sem agudo => sem vento externo)
    env = np.zeros_like(freqs)
    nz = freqs > 0
    env[nz] = (freqs[nz] / 100.0) ** (-1.25)            # brown (mais escuro/frio que pink)
    env *= _smoothstep((freqs - 28.0) / (60.0 - 28.0))  # passa-alta suave (sub controlado, sem boom)
    env /= np.sqrt(1.0 + (freqs / 600.0) ** (2.0 * 3.0))  # passa-baixa BAIXA e ingreme (fechado)
    env[0] = 0.0
    return env


def _hollow_env(freqs):
    # cavidade de pedra: bumps MUITO graves, NAO-harmonicos, largos e faint (espaco, nao nota)
    env = np.zeros_like(freqs)
    nz = freqs > 0
    for fc, w, a in [(58.0, 0.55, 1.0), (91.0, 0.5, 0.7), (137.0, 0.5, 0.5)]:
        env[nz] += a * np.exp(-((np.log(freqs[nz]) - np.log(fc)) / w) ** 2)
    env /= np.sqrt(1.0 + (freqs / 320.0) ** (2.0 * 3.0))  # mantem tudo grave
    env[0] = 0.0
    return env


def _still_drift(n, rng):
    """Ar PARADO: deriva lenta e RASA, periodica em n (so p/ nao ser loop morto). Quase estatica."""
    t = np.arange(n) / SR
    D = n / SR
    m = np.ones(n)
    for cycles, amp in [(1, 0.05), (2, 0.03)]:
        ph = rng.uniform(0.0, 2.0 * np.pi)
        m += amp * np.sin(2.0 * np.pi * cycles * t / D + ph)
    return m


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
        bed = _layer(_bed_env, n, rng)
        hollow = _layer(_hollow_env, n, rng)
        mix = (W_BED * bed + W_HOLLOW * hollow) * _still_drift(n, rng)  # ar parado
        return mix * RESERVE

    stereo = np.stack([build_channel(rng), build_channel(rng)], axis=1)
    stereo *= (PEAK / float(np.max(np.abs(stereo))))

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    sf.write(OUT, stereo.astype(np.float32), SR, format="OGG", subtype="VORBIS")

    rms = float(np.sqrt(np.mean(stereo ** 2)))
    rms_db = 20.0 * np.log10(rms + 1e-12)
    size = os.path.getsize(OUT)
    print("region_cave_stone.ogg gerado:")
    print("  path : %s" % os.path.normpath(OUT))
    print("  dur  : %.1fs | sr=%d | stereo | loop periodico (sem costura)" % (DURATION, SR))
    print("  peak : %.3f | RMS: %.1f dBFS | size: %.1f KB" % (PEAK, rms_db, size / 1024.0))
    print("  play : WorldAmbience regional a -20 dB. RMS efetivo ~ %.0f dBFS (fechado/frio, < vivo q cidade)" % (rms_db - 20.0))


if __name__ == "__main__":
    main()
