#!/usr/bin/env python3
"""Validador READ-ONLY do Pacote 1 de chãos (Codex raws) — ASSET_INTAKE_PACKAGE_01_TILES.

Confere os 6 tiles 96x96 opacos contra os requisitos hard do intake. NÃO escreve nada, NÃO
importa no Godot, NÃO toca runtime/save/banco. Só LÊ os PNGs e reporta.

Checa por arquivo:
  * existe na pasta correta;
  * PNG abre/decodifica (válido);
  * dimensão == 96x96;
  * opaco (sem canal alpha, OU alpha == 255 em todos os pixels);
  * nome/pasta batem com o contrato.

Semântica de saída (para uso repetido durante a recepção):
  * arquivo AUSENTE      -> PENDENTE (não é erro: os raws ainda vão chegar)  -> não derruba o exit
  * arquivo PRESENTE ok  -> OK
  * arquivo PRESENTE ruim-> FALHOU (viola requisito hard)                     -> exit 1
  exit 0 se nenhum arquivo presente FALHOU (mesmo com pendentes); exit 1 se algum presente falhou.

Idempotente, read-only. NÃO toca tools/map-editor/ nem os bancos do Studio.
Uso:  python godot/tools/art/validate_floor_tiles.py
"""
import os
import sys

try:
    from PIL import Image
except ImportError:
    print("ERRO: Pillow (PIL) não encontrado. Instale com: pip install pillow")
    sys.exit(2)

EXPECT = 96  # dimensão obrigatória (tile_size do _build_ground_tiles)

# (subpasta sob assets/tilesets/, arquivo)
TILES = [
    ("cathedral_of_crystal", "cathedral_floor_96.png"),
    ("cathedral_of_crystal", "cathedral_floor_var_96.png"),
    ("veins", "veins_floor_96.png"),
    ("fendas", "fendas_floor_96.png"),
    ("iron_channels", "iron_channels_floor_96.png"),
    ("iron_channels", "iron_channels_channel_water_96.png"),
]

# raiz do projeto godot/ = dois níveis acima deste arquivo (godot/tools/art/ -> godot/)
GODOT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TILESETS = os.path.join(GODOT_ROOT, "assets", "tilesets")


def check_one(folder, name):
    """Retorna (status, detalhe) onde status in {'OK','PENDENTE','FALHOU'}."""
    path = os.path.join(TILESETS, folder, name)
    if not os.path.exists(path):
        return "PENDENTE", "ainda não chegou"
    try:
        with Image.open(path) as im:
            im.load()
            w, h = im.size
            mode = im.mode
            problems = []
            if (w, h) != (EXPECT, EXPECT):
                problems.append("dimensão %dx%d (esperado %dx%d)" % (w, h, EXPECT, EXPECT))
            # opacidade: sem alpha = ok; com alpha = todos os pixels devem ser 255
            if mode in ("RGBA", "LA") or ("transparency" in im.info):
                alpha = im.convert("RGBA").getchannel("A")
                lo, hi = alpha.getextrema()
                if lo < 255:
                    problems.append("alpha não-opaco (min=%d)" % lo)
            if problems:
                return "FALHOU", "; ".join(problems)
            return "OK", "%dx%d %s" % (w, h, mode)
    except Exception as e:  # PNG corrompido / ilegível
        return "FALHOU", "PNG inválido: %s" % e


def main():
    print("=== Validação READ-ONLY · Pacote 1 (chãos 96x96) ===")
    print("base: %s" % TILESETS)
    any_failed = False
    n_ok = n_pend = n_fail = 0
    for folder, name in TILES:
        status, detail = check_one(folder, name)
        if status == "OK":
            n_ok += 1
        elif status == "PENDENTE":
            n_pend += 1
        else:
            n_fail += 1
            any_failed = True
        print("  [%-8s] %-22s/%-32s %s" % (status, folder, name, detail))
    print("--- resumo: %d OK · %d PENDENTE · %d FALHOU ---" % (n_ok, n_pend, n_fail))
    if any_failed:
        print("⚠ algum tile presente violou requisito hard — NÃO plugar até corrigir.")
        sys.exit(1)
    if n_pend:
        print("(pendentes ainda não chegaram — rode de novo quando o Codex entregar.)")
    else:
        print("✓ todos os 6 presentes e válidos — liberado para wiring (após olho humano no F5).")
    sys.exit(0)


if __name__ == "__main__":
    main()
