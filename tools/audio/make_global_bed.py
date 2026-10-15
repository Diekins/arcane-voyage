#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
make_global_bed.py — gera o LEITO GLOBAL de áudio ambiente de Arcane Voyage.

Direção (AMBIENT_AUDIO_FIRST_DROPIN): "quase ar". NÃO é música, NÃO tem melodia,
NÃO tem batida, NÃO tem evento reconhecível. É vento/distância: ruído moldado,
dull, largo, confortável por longos períodos, que torna o silêncio INTENCIONAL
sem dominar nenhuma região (o WorldAmbience ainda toca isto bem baixo, -22 dB).

Truque de loop SEM COSTURA: o sinal é sintetizado no domínio da frequência
(rfft/irfft). A iFFT de um espectro é PERIÓDICA com período = tamanho do buffer,
então concatenar o buffer consigo mesmo é contínuo por construção — nenhum
crossfade, nenhuma emenda audível, e como é ruído band-limitado não há "evento".

Saída: godot/assets/audio/ambient/global_bed.ogg (Ogg Vorbis, estéreo).
Reexecutar regenera (semente fixa => determinístico). Requer numpy + soundfile.
"""
import os
import numpy as np
import soundfile as sf

SR = 44100
# NOTA: o encoder Ogg/Vorbis do libsndfile (soundfile) estoura a pilha em conteudo LONGO
# (>~16s deste leito de baixa-frequencia) -> usa-se 16s. Como o leito e ruido moldado SEM
# evento reconhecivel, o loop e imperceptivel mesmo curto (so a deriva lenta varia o nivel).
DURATION = 16.0          # s — seguro p/ o encoder; loop sem costura (sintese periodica)
SEED = 7                 # deterministico
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio", "ambient", "global_bed.ogg")

# --- forma do espectro (banda de "ar/vento de longe") ---
SLOPE = 1.15             # inclinação ~pink/brown: grave-dominante, sem chiado
HP_LO, HP_HI = 38.0, 80.0    # corta sub-rumble abaixo de ~40-80 Hz (sem retumbar em fone)
LP_FC = 1350.0           # rolloff de "distância" (dull, nada de agudo de UI)
LP_ORDER = 2.5
PEAK = 0.9               # normalização (o volume real "quase-mudo" é o -22 dB do player)


def _smoothstep(x):
    x = np.clip(x, 0.0, 1.0)
    return x * x * (3.0 - 2.0 * x)


def _shaped_noise(n, sr, rng):
    """Um canal de ruído moldado, periódico em n amostras (loop perfeito)."""
    freqs = np.fft.rfftfreq(n, 1.0 / sr)
    env = np.zeros_like(freqs)
    nz = freqs > 0
    # inclinação pink/brown
    env[nz] = (freqs[nz] / 100.0) ** (-SLOPE)
    # passa-alta suave (remove sub-rumble/DC)
    env *= _smoothstep((freqs - HP_LO) / (HP_HI - HP_LO))
    # passa-baixa tipo Butterworth (distância/dull)
    env /= np.sqrt(1.0 + (freqs / LP_FC) ** (2.0 * LP_ORDER))
    env[0] = 0.0  # sem DC
    # fase aleatória => textura sem estrutura tonal
    phase = rng.uniform(0.0, 2.0 * np.pi, size=freqs.shape)
    spec = env * np.exp(1j * phase)
    x = np.fft.irfft(spec, n=n)
    return x


def _slow_drift(n, sr, rng):
    """LFO MUITO lento e periódico em n (mantém o loop perfeito). Respiro do vento,
    nunca um evento: soma de poucas senoides com nº INTEIRO de ciclos no buffer."""
    t = np.arange(n) / sr
    D = n / sr
    lfo = np.ones(n)
    for cycles, amp in [(1, 0.10), (2, 0.05), (3, 0.035)]:
        ph = rng.uniform(0.0, 2.0 * np.pi)
        lfo += amp * np.sin(2.0 * np.pi * cycles * t / D + ph)
    return lfo  # ~[0.8, 1.2]


def main():
    rng = np.random.default_rng(SEED)
    n = int(round(DURATION * SR))

    # estéreo: dois ruídos independentes (campo largo e arejado), drift levemente distinto
    left = _shaped_noise(n, SR, rng) * _slow_drift(n, SR, rng)
    right = _shaped_noise(n, SR, rng) * _slow_drift(n, SR, rng)

    stereo = np.stack([left, right], axis=1)
    peak = float(np.max(np.abs(stereo)))
    if peak > 0:
        stereo *= (PEAK / peak)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    sf.write(OUT, stereo.astype(np.float32), SR, format="OGG", subtype="VORBIS")

    rms = float(np.sqrt(np.mean(stereo ** 2)))
    rms_db = 20.0 * np.log10(rms + 1e-12)
    size = os.path.getsize(OUT)
    print("global_bed.ogg gerado:")
    print("  path : %s" % os.path.normpath(OUT))
    print("  dur  : %.1fs | sr=%d | stereo | loop periodico (sem costura)" % (DURATION, SR))
    print("  peak : %.3f | RMS: %.1f dBFS | size: %.1f KB" % (PEAK, rms_db, size / 1024.0))
    print("  play : WorldAmbience a -22 dB (quase-mudo). RMS efetivo ~ %.0f dBFS" % (rms_db - 22.0))


if __name__ == "__main__":
    main()
