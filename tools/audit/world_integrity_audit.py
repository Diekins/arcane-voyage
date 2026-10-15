#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GODOT-WORLD-INTEGRITY-AUDIT-1 — validador ESTÁTICO do mundo runtime (Main.gd).

Zero-risk: NÃO inicia o Godot, NÃO instancia GameState, NÃO toca o save do jogador.
Lê Main.gd textualmente + a pasta de sprites e valida invariantes de integridade.

Rodar:  python godot/tools/audit/world_integrity_audit.py

Checa:
  1. todo _build_portal(..., "<regiao>", ...) aponta p/ uma regiao em RUNTIME_REGIONS;
  2. todo mob com visual_key PRÓPRIO tem triplet .png/_side/_up em assets/actors/mobs/;
  3. placeholders intencionais da Costa (visual emprestado) sao ACEITOS (sem falhar);
  4. nenhuma ocorrencia de CANVAS_ITEM_Z_MAX (preserva o z-fix manual);
  5. o z-fix 4095/4090 continua presente;
  6. future_exit NAO transporta (_use_future_exit so mostra dialogo).
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.abspath(os.path.join(HERE, "..", ".."))
MAIN = os.path.join(GODOT, "scripts", "Main.gd")
MOBS = os.path.join(GODOT, "assets", "actors", "mobs")

# Mobs da Costa que reusam arte de outra regiao DE PROPÓSITO (assets proprios ainda nao existem).
# Sao aceitos como placeholder temporario ate o saltwind_shore_mob_sprite_pack_1 chegar.
COAST_BORROWED = {"grove_spider", "stone_sentinel", "scrap_colossus"}

# Mobs FRONT-ONLY por design: can_flip:false + simetricos; o ActorAnimator cai p/ a anim "move"
# (front) quando _side/_up nao existem (ActorAnimator._anim_for_dir). Nao e bug — vista unica proposital.
KNOWN_SINGLE_VIEW = {"crystal_bat"}

_passes = []
_fails = []
_warns = []


def ok(name):
    _passes.append(name)
    print(u"PASS  " + name)


def fail(name, extra=""):
    _fails.append(name)
    print(u"FALHA " + name + ((u"  [" + extra + u"]") if extra else u""))


def warn(name):
    _warns.append(name)
    print(u"AVISO " + name)


def read(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def main():
    if not os.path.isfile(MAIN):
        fail("Main.gd encontrado", MAIN)
        return 1
    src = read(MAIN)

    # ---- RUNTIME_REGIONS ----
    m = re.search(r'const\s+RUNTIME_REGIONS\s*:=\s*\[(.*?)\]', src, re.S)
    regions = set(re.findall(r'"([^"]+)"', m.group(1))) if m else set()
    if regions:
        ok("RUNTIME_REGIONS lido (%d regioes)" % len(regions))
    else:
        fail("RUNTIME_REGIONS lido")

    # ---- 1. portais apontam p/ regiao valida ----
    # _build_portal(POS, "target", "titulo", ...)  -> 2o argumento string = regiao destino
    portal_targets = re.findall(r'_build_portal\([^,]+,\s*"([^"]+)"', src)
    bad = [t for t in portal_targets if t not in regions]
    print(u"  -> %d chamadas de _build_portal; destinos: %s"
          % (len(portal_targets), ", ".join(sorted(set(portal_targets)))))
    if not bad:
        ok("todos os %d portais apontam p/ regiao em RUNTIME_REGIONS" % len(portal_targets))
    else:
        fail("portais com destino fantasma", ", ".join(sorted(set(bad))))

    # ---- 2/3. triplets de sprite por visual_key ----
    visuals = re.findall(r'"visual":\s*"([^"]+)"', src)
    visuals = sorted(set(visuals))
    print(u"  -> %d visual_keys distintos: %s" % (len(visuals), ", ".join(visuals)))
    missing_own = []
    single_view = []
    for v in visuals:
        triplet = [v + ".png", v + "_side.png", v + "_up.png"]
        have = all(os.path.isfile(os.path.join(MOBS, f)) for f in triplet)
        if have:
            continue
        if v in KNOWN_SINGLE_VIEW:
            # front-only por design; renderer cai p/ "move" (sem _side/_up). Aceito.
            single_view.append(v)
        else:
            missing_own.append(v)
    if not missing_own:
        ok("todo visual_key proprio tem triplet .png/_side/_up (ou e single-view por design)")
    else:
        fail("visual_key SEM triplet completo", ", ".join(missing_own))
    if single_view:
        warn("single-view por design (front-only, ok): %s" % ", ".join(single_view))

    # Costa: confirma que os 3 mobs ainda usam arte EMPRESTADA (placeholder intencional aceito).
    # Extrai o visual de cada id especifico (regex por-id, sem spanning).
    coast_ids = ["dune_skitter", "salt_husk", "tide_warden"]
    still_borrowed = []
    for cid in coast_ids:
        mm = re.search(r'"id":\s*"%s".*?"visual":\s*"([^"]+)"' % cid, src, re.S)
        if mm and mm.group(1) in COAST_BORROWED:
            still_borrowed.append(cid)
    if len(still_borrowed) == 3:
        ok("Costa: 3 placeholders intencionais aceitos (dune/salt/tide reusam arte ate o pack chegar)")
    else:
        warn("Costa: esperava 3 ids com arte emprestada, confirmei %d (%s)"
             % (len(still_borrowed), ", ".join(still_borrowed)))

    # ---- 4. sem CANVAS_ITEM_Z_MAX ----
    n_zmax = len(re.findall(r'CANVAS_ITEM_Z_MAX', src))
    # ocorrencias em COMENTARIO que dizem "SEM CANVAS_ITEM_Z_MAX" nao contam como uso real;
    # contamos so usos que nao estejam precedidos de "SEM " ou "sem ".
    real_uses = re.findall(r'(?<![Ss]em )CANVAS_ITEM_Z_MAX', src)
    # remove os que aparecem em linha de comentario (#)
    real_uses = [u for u in re.findall(r'^[^#\n]*CANVAS_ITEM_Z_MAX', src, re.M)]
    if not real_uses:
        ok("nenhum USO real de CANVAS_ITEM_Z_MAX (z-fix manual preservado)")
    else:
        fail("CANVAS_ITEM_Z_MAX usado em codigo", "%d ocorrencia(s)" % len(real_uses))

    # ---- 5. z-fix presente ----
    has_zfix = bool(re.search(r'\b40(95|90)\b', src))
    if has_zfix:
        ok("z-fix presente (z 4095/4090 ainda usado como teto manual)")
    else:
        warn("z-fix 4095/4090 nao encontrado — conferir manualmente")

    # ---- 6. future_exit nao transporta ----
    fe = re.search(r'func _use_future_exit\(svc\)[^\n]*\n((?:\t.*\n)+)', src)
    body = fe.group(1) if fe else ""
    transports = re.search(r'(_change_region|_load_region|_enter_region|_goto_region|change_region)', body)
    if body and not transports:
        ok("_use_future_exit NAO transporta (so mostra dialogo)")
    else:
        fail("_use_future_exit pode transportar", "revisar corpo")

    # ---- resumo ----
    print(u"\n===== RESUMO: %d PASS / %d FALHA / %d AVISO =====" % (len(_passes), len(_fails), len(_warns)))
    return 1 if _fails else 0


if __name__ == "__main__":
    sys.exit(main())
