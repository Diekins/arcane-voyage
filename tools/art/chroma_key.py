#!/usr/bin/env python3
"""Chroma-key MAGENTA (#FF00FF) → alpha, com despill anti-halo. Para os raws do Codex (Pacote 2+).

Remove o fundo magenta e mata a franja rosa das bordas anti-aliased (despill), preservando a arte.
NÃO redimensiona (os assets já vêm no tamanho final). Saída RGBA PNG.

Algoritmo por pixel (R,G,B):
  * é FUNDO se distância a (255,0,255) <= KEY_TOL  -> alpha 0.
  * borda anti-aliased (magenta-leaning: R>G e B>G): alpha parcial proporcional ao quanto ainda é magenta,
    e DESPILL (puxa R,B para perto de G) p/ tirar o halo rosa.
  * resto -> opaco, intacto.

Uso:  python godot/tools/art/chroma_key.py <in.png> <out.png>
Idempotente. Read-only sobre a entrada (só escreve out). NÃO toca runtime/save/banco.
"""
import sys
from PIL import Image

KEY_TOL = 90      # distância a magenta puro p/ considerar FUNDO total (alpha 0)
FRINGE = 60       # acima disso já é arte opaca; entre KEY_TOL..FRINGE = borda parcial


def dist_magenta(r, g, b):
    dr = 255 - r
    dg = g - 0
    db = 255 - b
    return (dr * dr + dg * dg + db * db) ** 0.5


def process(inp, outp):
    im = Image.open(inp).convert("RGB")
    w, h = im.size
    src = im.load()
    out = Image.new("RGBA", (w, h))
    dst = out.load()
    n_bg = n_fringe = 0
    for y in range(h):
        for x in range(w):
            r, g, b = src[x, y]
            d = dist_magenta(r, g, b)
            if d <= KEY_TOL:
                dst[x, y] = (0, 0, 0, 0)   # fundo
                n_bg += 1
            elif r > g and b > g:
                # borda magenta-leaning: despill (puxa R,B p/ G) + alpha parcial
                nr = min(r, g + (r - g) // 3)
                nb = min(b, g + (b - g) // 3)
                a = int(max(0, min(255, (d - KEY_TOL) / float(FRINGE) * 255)))
                if a >= 255:
                    dst[x, y] = (nr, g, nb, 255)
                else:
                    dst[x, y] = (nr, g, nb, a)
                    n_fringe += 1
            else:
                dst[x, y] = (r, g, b, 255)   # arte opaca
    out.save(outp)
    return w, h, n_bg, n_fringe


def main():
    if len(sys.argv) != 3:
        print("uso: python chroma_key.py <in.png> <out.png>")
        sys.exit(2)
    w, h, bg, fr = process(sys.argv[1], sys.argv[2])
    print("  %s -> %s  (%dx%d · fundo=%d px · borda_despill=%d px)" % (sys.argv[1].split("/")[-1], sys.argv[2].split("/")[-1], w, h, bg, fr))


if __name__ == "__main__":
    main()
