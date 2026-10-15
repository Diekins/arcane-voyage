#!/usr/bin/env python3
"""Fatia os source sheets 4x4 do Player Archetypes Pack 1 (Codex) nas strips do ActorAnimator.

GODOT-PLAYER-ARCHETYPE-SPRITES-1 + correção visual (GODOT-PLAYER-ARCHETYPE-SPRITES-FIX-1).
Cada fonte é 1254x1254, 4 linhas x 4 colunas:
  row 0 = down/front | row 1 = left | row 2 = right | row 3 = up/back.
O ActorAnimator espera STRIPS HORIZONTAIS de quadros quadrados (lado = altura):
  <key>.png      = down   (row 0)
  <key>_side.png = right  (row 2)  -> o flip horizontal cobre a esquerda (side_faces_left=false)
  <key>_up.png   = up     (row 3)
Cada strip vira 256x64 (4 quadros de 64x64). row 1 (left) é ignorada de propósito (usamos flip).

CORREÇÕES DESTE PASS:
 * SÓ usa *_alpha.png (rejeita *_magenta.png) — os _magenta são a fonte com chroma key cru.
 * LIMPA magenta residual (chroma key opaco que sobrou nos _alpha): pixels magenta -> alpha 0.
 * Resize PREMULTIPLICADO (premultiplied alpha) p/ não criar halo rosa nas bordas ao reduzir.
 * Normaliza ANCORAGEM: recorta o conteúdo (bbox), escala por LINHA p/ altura consistente, e
   ancora os PÉS numa baseline fixa (y=61, igual ao Errante) + centraliza no eixo X. Assim
   down/side/up ficam do mesmo tamanho, colados no chão (sem flutuar) e com flip simétrico.

Idempotente. NÃO toca em tools/map-editor/ nem nos bancos do Studio.
Uso:  python godot/tools/art/slice_archetype_sheets.py [--contact CAMINHO.png]
"""
import os
import sys
import numpy as np
from PIL import Image

GRID = 4            # 4x4
FRAME = 64          # quadro final (hero tier = 64px, igual ao errante)
ROWS = {"down": 0, "side": 2, "up": 3}   # qual linha vira cada strip (left/row1 = flip do right)
TARGET_BODY = 50    # altura-alvo do CORPO (tronco+pernas, sem a arma) no quadro de 64 -> tamanho
                    # consistente entre direções mesmo quando a arma (lança/cajado/arco) estica o
                    # conteúdo de forma diferente. Deixa folga no topo p/ a coroa de cabelo do up.
BASELINE = 61       # Y dos PÉS no quadro de 64 (Errante = 61) -> personagem colado no chão

# Pasta com as sheets-fonte (*_alpha.png), fora do repositório: defina ARCANE_ARCHETYPES_SRC.
SRC_DIR = os.environ.get("ARCANE_ARCHETYPES_SRC", "./player_archetypes_pack_1")
OUT_DIR = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", "assets", "actors", "hero"))

MAP = {
    "wanderer_sword_shield_4dir_alpha.png": "player_wanderer_sword",
    "wanderer_archer_4dir_alpha.png":       "player_wanderer_archer",
    "wanderer_mage_4dir_alpha.png":         "player_wanderer_mage",
    "wanderer_spearman_4dir_alpha.png":     "player_wanderer_spearman",
}


def strip_magenta(arr):
    """Zera o alpha dos pixels de chroma key magenta (g muito menor que r e b, ambos altos).
    Conservador o bastante p/ não comer roxo/púrpura legítimo (min(r,b)-g > 60)."""
    r = arr[..., 0].astype(np.int16); g = arr[..., 1].astype(np.int16); b = arr[..., 2].astype(np.int16)
    mag = (r > 80) & (b > 80) & ((np.minimum(r, b) - g) > 60)
    arr[mag, 3] = 0
    return arr


def resize_premult(im, size):
    """Resize com alpha PREMULTIPLICADO p/ não vazar a cor de pixels transparentes (sem halo rosa)."""
    a = np.asarray(im).astype(np.float32)
    al = a[..., 3:4] / 255.0
    pm = np.concatenate([a[..., :3] * al, a[..., 3:4]], axis=2).astype(np.uint8)
    pim = Image.fromarray(pm, "RGBA").resize(size, Image.LANCZOS)
    b = np.asarray(pim).astype(np.float32)
    al2 = b[..., 3:4] / 255.0
    safe = np.where(al2 > 0.0, al2, 1.0)
    rgb = np.clip(b[..., :3] / safe, 0, 255)
    return Image.fromarray(np.concatenate([rgb, b[..., 3:4]], axis=2).astype(np.uint8), "RGBA")


def bbox(sub, athr=20):
    """BBox do CORPO do personagem dentro de um sub-array. Usa a MAIOR sequência contígua de linhas
    com conteúdo (ignora blobs desconexos — ex.: a SOMBRA chapada no rodapé do perfil/side, que o jogo
    já desenha por conta própria). Sem isso, a sombra inflava a bbox e bagunçava escala/ancoragem.
    Linha 'com conteúdo' = >=3 px opacos (ignora aura/anti-alias de 1-2 px). None se vazio."""
    al = sub[..., 3]
    dens = (al > athr).sum(axis=1)
    ne = dens >= 3
    best = (0, -1); cur = None
    for i, v in enumerate(ne):
        if v and cur is None:
            cur = i
        elif not v and cur is not None:
            if (i - 1 - cur) > (best[1] - best[0]):
                best = (cur, i - 1)
            cur = None
    if cur is not None and (len(ne) - 1 - cur) > (best[1] - best[0]):
        best = (cur, len(ne) - 1)
    y0, y1 = best
    if y1 < y0:
        return None
    xs = np.where((al[y0:y1 + 1, :] > athr).any(axis=0))[0]
    if len(xs) == 0:
        return None
    return (int(xs.min()), y0, int(xs.max()), y1)


def cell_bounds(side, col, row):
    """Limites (x0,y0,x1,y1) da célula (col,row) numa fonte side x side, bordas float arredondadas."""
    step = side / GRID
    return (round(col * step), round(row * step), round((col + 1) * step), round((row + 1) * step))


def row_cells(arr, row):
    """[(sub_array, bbox_local)] das 4 colunas de uma linha."""
    side = arr.shape[0]
    out = []
    for col in range(GRID):
        x0, y0, x1, y1 = cell_bounds(side, col, row)
        sub = arr[y0:y1, x0:x1]
        out.append((sub, bbox(sub)))
    return out


def repair_up_head(tight):
    """A arte-fonte de COSTAS (up) vem com o TOPO DA CABEÇA cortado na borda da célula (o Codex
    desenhou o personagem alto demais). Como os pixels não existem, RECONSTRUÍMOS uma coroa de cabelo
    arredondada por cima: detecta o trecho de cabelo (cor quente) na 1ª linha e estende a textura pra
    cima num domo elíptico (afunilando). Só age se o topo for cabelo (não domeia ponta de arma).
    Recebe/retorna PIL RGBA em resolução de FONTE (antes do resize)."""
    a = np.asarray(tight).copy()
    h, w = a.shape[:2]
    op = a[0, :, 3] > 20
    if op.sum() < 4:
        return tight                      # nada colado no topo → não havia corte
    # runs contíguos de opacos na 1ª linha
    runs = []; s = None
    for x in range(w):
        if op[x] and s is None: s = x
        elif not op[x] and s is not None: runs.append((s, x - 1)); s = None
    if s is not None: runs.append((s, w - 1))
    # escolhe o run de CABELO (quente: r>=b) mais largo
    best = None
    for s0, e0 in runs:
        seg = a[0, s0:e0 + 1, :3].astype(int)
        r, g, b = seg[:, 0].mean(), seg[:, 1].mean(), seg[:, 2].mean()
        if r >= b and r > 45 and (e0 - s0 + 1) >= 4:
            if best is None or (e0 - s0) > (best[1] - best[0]): best = (s0, e0)
    if best is None:
        return tight
    s0, e0 = best; cx = (s0 + e0) / 2.0; hw = (e0 - s0 + 1) / 2.0
    dome = max(3, int(round(hw * 0.7)))   # altura da coroa (proporcional à largura da cabeça)
    out = np.zeros((h + dome, w, 4), a.dtype)
    out[dome:, :, :] = a
    for d in range(1, dome + 1):
        half = hw * float(np.sqrt(max(0.0, 1.0 - (d / dome) ** 2)))
        x0 = int(round(cx - half)); x1 = int(round(cx + half))
        srcrow = a[min(d, h - 1)]         # espelha a textura do cabelo de baixo pra cima
        y = dome - d
        for x in range(max(0, x0), min(w, x1 + 1)):
            px = srcrow[x]
            if px[3] < 20:
                px = a[0, x]
            if px[3] < 20:
                px = a[0, int(round(cx))]
            shade = 0.93 if d >= dome - 1 else 1.0   # leve sombra no topo do crânio
            out[y, x] = [int(px[0] * shade), int(px[1] * shade), int(px[2] * shade), 255]
    return Image.fromarray(out, "RGBA")


def body_band(tight, athr=20):
    """Acha o CORPO (tronco/cabeça/pernas = linhas LARGAS) dentro do recorte, separando-o da arma fina
    (lança/cajado/arco) que estica o conteúdo. Retorna (topo, base_pés, centro_x) — tudo relativo ao
    recorte. A base é os PÉS (fim das pernas); a arma acima/abaixo fica fora da medida (vira overhang)."""
    al = np.asarray(tight)[..., 3]
    dens = (al > athr).sum(axis=1)
    rows = np.where(dens >= 3)[0]
    if len(rows) == 0:
        return None
    mx = int(dens.max()); thr = max(15, int(0.30 * mx))   # "largo" = >=30% da maior linha
    wide = np.where(dens >= thr)[0]
    if len(wide) == 0:
        wide = rows
    bt, bb = int(wide.min()), int(wide.max())
    ys, xs = np.where(al[bt:bb + 1, :] > athr)
    cx = float(xs.mean()) if len(xs) else tight.width / 2.0   # centroide (pondera o corpo, não a arma)
    return bt, bb, cx


def build_strip(arr, row):
    """Strip 256x64 de uma linha. Escala POR DIREÇÃO normalizando o CORPO (não o conteúdo todo) p/
    TARGET_BODY → mesmo tamanho de corpo em down/side/up mesmo com armas de alcance diferente. Ancora
    os PÉS (base do corpo) na baseline; a arma (e a coroa de cabelo do up) viram overhang que só recorta
    nas bordas. Centraliza pelo CENTROIDE do corpo (flip simétrico). Uma escala só p/ os 4 quadros."""
    cells = row_cells(arr, row)
    tights = []
    for sub, bb in cells:
        if bb is None:
            tights.append(None); continue
        t = Image.fromarray(sub[bb[1]:bb[3] + 1, bb[0]:bb[2] + 1], "RGBA")
        if row == ROWS["up"]:
            t = repair_up_head(t)            # reconstrói a coroa de cabelo cortada na fonte (só up)
        tights.append(t)
    bands = [body_band(t) if t is not None else None for t in tights]
    body_hs = [(b[1] - b[0] + 1) for b in bands if b is not None]
    if not body_hs:
        return Image.new("RGBA", (FRAME * GRID, FRAME), (0, 0, 0, 0))
    scale = TARGET_BODY / max(body_hs)       # corpo mais alto da linha → TARGET_BODY (resto na mesma escala)
    strip = Image.new("RGBA", (FRAME * GRID, FRAME), (0, 0, 0, 0))
    for i, tight in enumerate(tights):
        if tight is None or bands[i] is None:
            continue
        bt, bb_, cx = bands[i]
        nw = max(1, round(tight.width * scale)); nh = max(1, round(tight.height * scale))
        frame = resize_premult(tight, (nw, nh))
        feet_y = int(round(bb_ * scale))                 # Y dos pés dentro do quadro escalado
        py = (BASELINE + 1) - feet_y                      # pés na baseline
        px = i * FRAME + int(round(FRAME / 2.0 - cx * scale))   # centroide do corpo no meio do quadro
        strip.paste(frame, (px, py), frame)
    return strip


def make_contact_sheet(strips, path):
    """Folha de contato (4 arquétipos x 3 direções) + linha-guia da baseline p/ QA. Fora de assets/."""
    n = len(strips)
    sheet = Image.new("RGBA", (FRAME * GRID, FRAME * n), (24, 26, 34, 255))
    for i, (_, strip) in enumerate(strips):
        sheet.paste(strip, (0, i * FRAME), strip)
    # linha vermelha na baseline de cada faixa (debug visual de ancoragem)
    px = sheet.load()
    for i in range(n):
        yb = i * FRAME + BASELINE
        for x in range(sheet.width):
            px[x, yb] = (220, 60, 60, 160)
    sheet.save(path)
    print("contact sheet:", path)


def main():
    contact = None
    if "--contact" in sys.argv:
        contact = sys.argv[sys.argv.index("--contact") + 1]
    os.makedirs(OUT_DIR, exist_ok=True)
    written, strips = [], []
    for src_name, key in MAP.items():
        assert "_alpha" in src_name and "_magenta" not in src_name, \
            "fonte inválida (use só *_alpha.png, nunca *_magenta.png): " + src_name
        src_path = os.path.join(SRC_DIR, src_name)
        if not os.path.exists(src_path):
            print("AUSENTE (pulando):", src_path); continue
        arr = np.asarray(Image.open(src_path).convert("RGBA")).copy()
        before = int((arr[..., 3] > 0).sum())
        arr = strip_magenta(arr)
        removed = before - int((arr[..., 3] > 0).sum())
        print("%-28s magenta removido: %d px" % (key, removed))
        for dname, row in ROWS.items():
            strip = build_strip(arr, row)
            out = os.path.join(OUT_DIR, key + ("" if dname == "down" else "_" + dname) + ".png")
            strip.save(out); written.append(out); strips.append((key + "_" + dname, strip))
            print("  OK", os.path.basename(out), strip.size)
    print("\n%d strips escritas em %s" % (len(written), OUT_DIR))
    if contact:
        make_contact_sheet(strips, contact)


if __name__ == "__main__":
    main()
