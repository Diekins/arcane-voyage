#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
generate_map_manifest.py  (GODOT-MAP-MANIFEST-PILOT-GENERATOR-1, Fase 2 do pipeline runtime->Map Editor)

Gera manifests JSON v1 (schema de godot/docs/GODOT-MAP-EDITOR-SYNC-PILOT-AUDIT-1.md) para regioes do runtime
Godot, a partir de SPECS EXPLICITAS (valores reais de Main.gd) — SEM introspeccao fragil dos builders.

- READ-ONLY em relacao ao runtime: NAO toca Main.gd / saves / assets / gameplay / tools/map-editor.
- Reexecutavel: rodar de novo regenera os JSONs identicos.
- Expansivel: para uma regiao nova, adicione um dict em REGIONS (mesma estrutura) e rode.

Uso:
    python3 godot/tools/generate_map_manifest.py
Saida:
    godot/data/map_manifest/<region_id>.json   (1 arquivo por regiao)

As formulas de blocker espelham os helpers de Main.gd (documentadas no audit, secoes 2/3):
    palm:     Rect(x-tw, y-6, 2*tw, 14)            tw = h*0.09
    altar:    Rect(x-26, y-12, 52, 16)
    cactus:   Rect(x-w*0.6, y-8, w*1.2, 16)        w  = h*0.26
    dry_rock: Rect(x-r, y-r*0.5, 2*r, r)
    tent:     Rect(x-hw*0.55, y-h*0.30, hw*1.1, h*0.30)   hw = w/2
    wagon:    Rect(x-48, y-26, 96, 30)
    scatter solids: indice par -> cactus(h=42+(i%3)*8); impar -> dry_rock(r=24). softs -> sem blocker.
"""

import json
import os

SCHEMA_HEADER = {
    "version": 1,
    "source": "godot-runtime",
    "generated_from": "Main.gd",
    "generator": "godot/tools/generate_map_manifest.py",
    "coordinate_system": {"origin": "top-left", "x": "right", "y": "down", "unit": "px-world"},
    "interaction_radii": {"portal_E": 150, "portal_auto": 64, "interact_E": 140},
}


# ---------- blocker math (espelha os helpers de Main.gd) ----------
def _r(*v):
    return [round(x, 2) for x in v]

def palm_blocker(x, y, h):
    tw = h * 0.09
    return _r(x - tw, y - 6.0, 2.0 * tw, 14.0)

def altar_blocker(x, y):
    return _r(x - 26.0, y - 12.0, 52.0, 16.0)

def cactus_blocker(x, y, h):
    w = h * 0.26
    return _r(x - w * 0.6, y - 8.0, w * 1.2, 16.0)

def dry_rock_blocker(x, y, r):
    return _r(x - r, y - r * 0.5, 2.0 * r, r)

def tent_blocker(x, y, w, h):
    hw = w * 0.5
    return _r(x - hw * 0.55, y - h * 0.30, hw * 1.1, h * 0.30)

def wagon_blocker(x, y):
    return _r(x - 48.0, y - 26.0, 96.0, 30.0)

# blockers das regiões ANTIGAS (espelham os helpers de Main.gd; ver GODOT-MAP-MANIFEST-LEGACY-PROPS-BLOCKERS-1)
def tree_blocker(x, y):
    return _r(x - 12.0, y - 8.0, 24.0, 24.0)        # _add_tree (Planície/Pântano)

def dead_tree_blocker(x, y):
    return _r(x - 11.0, y + 2.0, 22.0, 22.0)        # _add_dead_tree (Bosques)

def column_blocker(x, y):
    return _r(x - 12.0, y + 2.0, 24.0, 20.0)        # _add_column (ruínas/monólitos)

def crystal_blocker(x, y, h):
    return _r(x - h * 0.3, y - h * 0.2, h * 0.6, h * 0.35)   # _add_crystal (Caverna)

# Decor das 9 regiões antigas (GODOT-MAP-MANIFEST-LEGACY-PROPS-BLOCKERS-1): posições normalizadas REAIS de
# Main.gd (scatter/_scatter_village_props). Bosques (painted) e Vila (sprites) = FAITHFUL; Planície/Caverna/
# Pântano/Poço/Ruínas = APPROX (layout do scatter procedural-fallback; o tileset real põe props equivalentes
# nas mesmas zonas). tree=_add_tree · dead_tree=_add_dead_tree · column=_add_column · crystal=_add_crystal · rock=_add_rock.
def _items(kind, norms, **prm):
    return [{"type": kind, "norm": list(n), "params": prm} for n in norms]

LEGACY_SCATTER = {
    # ---- FAITHFUL: Bosques (chão pintado → scatter blockers_only é o real) ----
    "ashen_grove": {"mode": "faithful", "items":
        _items("dead_tree", [[0.1, 0.18], [0.28, 0.12], [0.5, 0.14], [0.72, 0.12], [0.9, 0.24], [0.15, 0.78], [0.38, 0.86], [0.62, 0.82], [0.86, 0.78], [0.95, 0.5]])
        + _items("column", [[0.22, 0.42], [0.78, 0.58]])
        + _items("rock", [[0.58, 0.4], [0.35, 0.6]], r=24)},
    "deep_grove": {"mode": "faithful", "items":
        _items("dead_tree", [[0.08, 0.14], [0.26, 0.10], [0.74, 0.10], [0.92, 0.16], [0.06, 0.5], [0.94, 0.5], [0.10, 0.88], [0.90, 0.88]])
        + _items("column", [[0.20, 0.32], [0.80, 0.32], [0.20, 0.70], [0.80, 0.70]])
        + _items("rock", [[0.34, 0.20], [0.66, 0.20], [0.30, 0.82], [0.70, 0.82]], r=22)},
    "ancient_root_nest": {"mode": "faithful", "items":
        _items("dead_tree", [[0.10, 0.16], [0.30, 0.10], [0.70, 0.10], [0.90, 0.16], [0.06, 0.5], [0.94, 0.5], [0.12, 0.85], [0.88, 0.85]])
        + _items("column", [[0.24, 0.34], [0.76, 0.34], [0.24, 0.66], [0.76, 0.66]])
        + _items("rock", [[0.36, 0.16], [0.64, 0.16], [0.34, 0.80], [0.66, 0.80]], r=24)},
    # ---- APPROX: regiões com tileset (scatter procedural-fallback como layout representativo) ----
    "plains": {"mode": "approx", "items":
        _items("tree", [[0.1, 0.18], [0.28, 0.1], [0.5, 0.16], [0.72, 0.12], [0.9, 0.22], [0.14, 0.84], [0.4, 0.9], [0.64, 0.86], [0.86, 0.82], [0.95, 0.5]])
        + _items("rock", [[0.22, 0.4], [0.58, 0.62], [0.78, 0.34], [0.35, 0.52]], r=26)},
    "cave": {"mode": "approx", "items":
        _items("crystal", [[0.2, 0.3], [0.45, 0.2], [0.62, 0.42], [0.8, 0.28], [0.32, 0.72], [0.7, 0.76], [0.52, 0.86], [0.9, 0.6]], h=60)
        + _items("rock", [[0.15, 0.5], [0.55, 0.62], [0.85, 0.45], [0.4, 0.34]], r=32)},
    "swamp": {"mode": "approx", "items":
        _items("tree", [[0.12, 0.2], [0.34, 0.12], [0.56, 0.18], [0.78, 0.14], [0.9, 0.34], [0.16, 0.82], [0.44, 0.9], [0.68, 0.84], [0.88, 0.8]])
        + _items("rock", [[0.26, 0.42], [0.62, 0.6], [0.8, 0.46]], r=26)},
    "swamp_pit": {"mode": "approx", "items":
        _items("rock", [[0.12, 0.2], [0.88, 0.2], [0.12, 0.82], [0.88, 0.82], [0.5, 0.12], [0.5, 0.9]], r=28)},
    "old_road": {"mode": "approx", "items":
        _items("column", [[0.1, 0.15], [0.3, 0.1], [0.55, 0.16], [0.78, 0.12], [0.9, 0.3], [0.12, 0.85], [0.4, 0.9], [0.7, 0.85], [0.88, 0.82]])
        + _items("rock", [[0.25, 0.45], [0.6, 0.6], [0.82, 0.4], [0.45, 0.72]], r=24)},
    # ---- FAITHFUL: Vila (sprites reais de _scatter_village_props + blockers explícitos [dx,dy,w,h]) ----
    "starter_village": {"mode": "faithful", "items": [
        {"type": "sprite", "key": "guild_hall", "asset": "tilesets/starter_village/guild_hall.png", "norm": [0.16, 0.20], "blocker": [-130, -6, 260, 60]},
        {"type": "sprite", "key": "tavern", "asset": "tilesets/starter_village/tavern.png", "norm": [0.30, 0.16], "blocker": [-100, -6, 200, 56]},
        {"type": "sprite", "key": "house_red", "asset": "tilesets/starter_village/house_red.png", "norm": [0.84, 0.20], "blocker": [-90, -6, 180, 50]},
        {"type": "sprite", "key": "healer", "asset": "tilesets/starter_village/healer.png", "norm": [0.16, 0.80], "blocker": [-105, -6, 210, 48]},
        {"type": "sprite", "key": "bank", "asset": "tilesets/starter_village/bank.png", "norm": [0.84, 0.80], "blocker": [-92, -6, 184, 44]},
        {"type": "sprite", "key": "fountain", "asset": "tilesets/starter_village/fountain.png", "norm": [0.37, 0.38], "blocker": [-60, -18, 120, 70]},
        {"type": "sprite", "key": "spawn_shrine", "asset": "tilesets/starter_village/spawn_shrine.png", "norm": [0.63, 0.62], "blocker": [-48, -10, 96, 56]},
        {"type": "sprite", "key": "quest_board", "asset": "tilesets/starter_village/quest_board.png", "norm": [0.30, 0.36], "blocker": [-70, -4, 140, 36]},
        {"type": "sprite", "key": "hearth", "asset": "tilesets/starter_village/props/hearth.png", "norm": [0.68, 0.38], "blocker": [-48, -4, 96, 50]},
        {"type": "sprite", "key": "market", "asset": "tilesets/starter_village/props/market.png", "norm": [0.72, 0.74]},
        {"type": "sprite", "key": "cart", "asset": "tilesets/starter_village/props/cart.png", "norm": [0.70, 0.78], "blocker": [-58, -4, 116, 40]},
        {"type": "sprite", "key": "barrels", "asset": "tilesets/starter_village/props/barrels.png", "norm": [0.26, 0.62], "blocker": [-44, -4, 88, 44]},
        {"type": "sprite", "key": "fence", "asset": "tilesets/starter_village/props/fence.png", "norm": [0.26, 0.88], "blocker": [-70, -4, 140, 26]},
        {"type": "sprite", "key": "scarecrow", "asset": "tilesets/starter_village/props/scarecrow.png", "norm": [0.30, 0.90]},
        {"type": "sprite", "key": "signpost", "asset": "tilesets/starter_village/signpost.png", "norm": [0.40, 0.60]},
        {"type": "sprite", "key": "gate", "asset": "tilesets/starter_village/gate.png", "norm": [0.5, 0.90625], "blocker": [-152, -34, 92, 78], "blocker2": [60, -34, 92, 78]},
    ]},
}

# Decor das 9 regiões antigas: converte `legacy_scatter` (posições normalizadas + tipo) em props (placeholders)
# + blockers resolvidos. mode "faithful" (Vila=sprites reais; Bosques=blockers reais do scatter painted) vs
# "approx" (Planície/Caverna/Pântano/Poço/Ruínas = layout do scatter procedural-fallback; tilesets reais usam
# props equivalentes nas mesmas zonas). NÃO inventa: posições vêm de Main.gd.
def legacy_decor(region):
    sc = region.get("legacy_scatter") or LEGACY_SCATTER.get(region["id"])
    if not sc:
        return [], []
    W, H = region["size"]
    rid = region["id"]
    mode = sc.get("mode", "approx")
    approx = (mode != "faithful")
    props, blk = [], []
    if sc.get("water_blocker_inset"):
        ins = sc["water_blocker_inset"]
        blk.append({"from": "sea", "rect": _r(0, H - ins, W, ins), "notes": ["faixa de mar intransponível"]})
    i = 0
    for it in sc.get("items", []):
        i += 1
        t = it["type"]
        nx, ny = it["norm"]
        px, py = W * nx, H * ny
        prm = it.get("params", {})
        pid = "%s_%s_%d" % (rid, t if t != "sprite" else it.get("key", "prop"), i)
        if t == "sprite":   # Vila: sprite real (asset_key) + blocker explícito (offset dx,dy,w,h)
            props.append({"id": pid, "type": "sprite", "asset_key": it.get("asset", ""), "position": _r(px, py), "z_hint": "ysort"})
            b = it.get("blocker")
            if b:
                blk.append({"from": pid, "rect": _r(px + b[0], py + b[1], b[2], b[3])})
            b2 = it.get("blocker2")   # ex.: portão da Vila = 2 paredes laterais (boca central aberta)
            if b2:
                blk.append({"from": pid, "rect": _r(px + b2[0], py + b2[1], b2[2], b2[3])})
        else:               # procedural (tree/dead_tree/column/crystal/rock)
            props.append({"id": pid, "type": "procedural", "procedural_type": (t if t != "rock" else "dry_rock"),
                          "position": _r(px, py), "z_hint": "ysort", "blocker": "base", "approx": approx})
            if t == "tree": blk.append({"from": pid, "rect": tree_blocker(px, py)})
            elif t == "dead_tree": blk.append({"from": pid, "rect": dead_tree_blocker(px, py)})
            elif t == "column": blk.append({"from": pid, "rect": column_blocker(px, py)})
            elif t == "crystal": blk.append({"from": pid, "rect": crystal_blocker(px, py, prm.get("h", 60))})
            elif t == "rock": blk.append({"from": pid, "rect": dry_rock_blocker(px, py, prm.get("r", 26))})
    return props, blk

def scatter_blockers(size, solids_norm):
    """Resolve as posicoes/blockers dos 'solids' do scatter de deserto (par=cacto, impar=pedra seca)."""
    out = []
    for i, (nx, ny) in enumerate(solids_norm):
        px, py = size[0] * nx, size[1] * ny
        if i % 2 == 0:
            h = 42.0 + float(i % 3) * 8.0
            out.append({"from": "scatter:cactus", "pos": _r(px, py), "rect": cactus_blocker(px, py, h)})
        else:
            out.append({"from": "scatter:dry_rock", "pos": _r(px, py), "rect": dry_rock_blocker(px, py, 24.0)})
    return out


# Expande mobs com `spawns:[[x,y],...]` (espelha _mob_configs) em 1 entrada por spawn. REGRA id vs mob_id
# (GODOT-MAP-MANIFEST-FULL-GAME-EXPANSION-AND-EDITOR-ID-FIX-1):
#   - mob_id = TIPO/base da criatura (ex.: "dune_skitter") — o runtime usa p/ comportamento/visual/kill-quests;
#   - id     = identificador ÚNICO daquele spawn no mapa (region-prefixado, ex.: "saltwind_shore_dune_skitter_1")
#              — o Map Editor usa p/ casar objetos no round-trip (sem id único → "mob sumiu: undefined").
# Mantém defeat_flag/reward/elite/non_respawn/ranged/loot/etc. O runtime (_manifest_mob_configs) lê mob_id, então
# o formato do id NÃO afeta gameplay.
def expand_mobs(mobs, region_id):
    out = []
    for mb in (mobs or []):
        spawns = mb.get("spawns") or ([mb["position"]] if "position" in mb else [])
        base = mb.get("mob_id") or mb.get("id") or "mob"
        for i, sp in enumerate(spawns, 1):
            e = {k: v for k, v in mb.items() if k not in ("spawns", "position")}
            e["mob_id"] = base
            e["id"] = "%s_%s_%d" % (region_id, base, i)   # id ÚNICO region-prefixado por spawn
            e["position"] = [round(sp[0]), round(sp[1])]
            out.append(e)
    return out


def build_blockers(region):
    """Monta o array de blockers resolvidos a partir dos props nomeados + scatter."""
    blk = []
    for p in region.get("props", []):
        pt = p["procedural_type"]
        x, y = p["position"]
        prm = p.get("params", {})
        if pt == "palm":
            blk.append({"from": "palm", "pos": [x, y], "rect": palm_blocker(x, y, prm["h"])})
        elif pt == "salt_altar":
            blk.append({"from": "salt_altar", "pos": [x, y], "rect": altar_blocker(x, y)})
        elif pt == "tent":
            blk.append({"from": "tent", "pos": [x, y], "rect": tent_blocker(x, y, prm["w"], prm["h"])})
        elif pt == "wagon":
            blk.append({"from": "wagon", "pos": [x, y], "rect": wagon_blocker(x, y)})
        # campfire / water_ellipse -> sem blocker
    sc = region.get("scatter")
    if sc and sc.get("solids_norm"):
        blk.extend(scatter_blockers(region["size"], sc["solids_norm"]))
    # Costa (saltwind_shore): chão PINTADO + _scatter_coast_decor(blockers_only) → mar + pedras sólidas (r=26).
    if sc and sc.get("coast_rocks_norm"):
        W, H = region["size"]
        inset = sc.get("water_blocker_inset", 195)
        blk.append({"from": "sea", "pos": [0, H - inset], "rect": _r(0, H - inset, W, inset)})
        for nx, ny in sc["coast_rocks_norm"]:
            px, py = W * nx, H * ny
            blk.append({"from": "coast_rock", "pos": _r(px, py), "rect": dry_rock_blocker(px, py, 26.0)})
    return blk


# ---------- SPECS EXPLICITAS (valores reais de Main.gd) ----------
REGIONS = [
    {
        "id": "khet_oasis",
        "display_name": "Oásis de Khet-Sar",
        "client_side": True,
        "size": [1400, 900],
        "spawn": [240, 460],
        "ground": {
            "base_color": "#cdb083",
            "path_color_rgba": [0.66, 0.56, 0.36, 0.40],
            "path_band": {"axis": "horizontal", "center_y": 450, "height": 150},
        },
        "access": {
            "gate_flag": "caravan_camp_reached",
            "from_region": "khet_caravan_camp",
            "from_exit": "camp_to_oasis",
        },
        "portals": [
            {"id": "oasis_to_camp", "position": [130, 460], "target_region": "khet_caravan_camp",
             "target_spawn": [300, 300], "gate_flag": None, "draw_door": True,
             "label": "Trilha → Acampamento de Caravana"},
        ],
        "future_exits": [
            {"id": "khet_oasis_city_road", "position": [1280, 460], "label": "Estrada para a Cidade",
             "transports": False, "runtime_only": True,
             "notes": ["só texto; gancho da Cidade do Deserto", "NÃO é o khet_city_gate do Acampamento"]},
            {"id": "khet_oasis_salt_altar", "position": [700, 250], "label": "Altar de Sal",
             "transports": False, "runtime_only": True,
             "notes": ["texto muda por flag khet_oasis_salt_echo_cleansed", "ponto do mini-evento Eco do Sal"]},
        ],
        "npcs": [
            {"id": "nara", "name": "Peregrina Nara", "position": [870, 660], "sprite_key": "npcs/village/elder",
             "service": None, "wander": True,
             "runtime_only_fields": ["falas condicionais à flag khet_oasis_salt_echo_cleansed"],
             "notes": ["sprite = placeholder medieval da Vila (dívida visual)"]},
        ],
        "services": [],
        "mobs": [
            {"id": "khet_oasis_salt_echo", "name": "Eco do Sal", "visual": "crawling_shade",
             "position": [640, 175], "hp": 170, "aggro": 360, "respawn": 999999,
             "spawn_condition": "!flag:khet_oasis_salt_echo_cleansed", "runtime_only": True,
             "notes": ["focal do mini-evento; morte → flag + recompensa via _on_oasis_salt_echo_defeated"]},
            {"id": "khet_oasis_dune_skitter", "name": "Escaravelho de Sal", "visual": "dune_skitter",
             "position": [820, 185], "hp": 62, "aggro": 360, "respawn": 999999,
             "spawn_condition": "!flag:khet_oasis_salt_echo_cleansed", "runtime_only": True,
             "notes": ["escolta; reaparece no rebuild enquanto não-limpo; some após a flag"]},
        ],
        "chests": [],
        "props": [
            {"type": "procedural", "procedural_type": "water_ellipse", "position": [700, 480],
             "params": {"rx": 190, "ry": 110}, "z_hint": -17, "blocker": None,
             "notes": ["lago raso ATRAVESSÁVEL (sem blocker)"]},
            {"type": "procedural", "procedural_type": "palm", "position": [470, 360], "params": {"h": 150}, "z_hint": "ysort", "blocker": "trunk"},
            {"type": "procedural", "procedural_type": "palm", "position": [940, 360], "params": {"h": 168}, "z_hint": "ysort", "blocker": "trunk"},
            {"type": "procedural", "procedural_type": "palm", "position": [520, 640], "params": {"h": 138}, "z_hint": "ysort", "blocker": "trunk"},
            {"type": "procedural", "procedural_type": "palm", "position": [560, 300], "params": {"h": 120}, "z_hint": "ysort", "blocker": "trunk"},
            {"type": "procedural", "procedural_type": "salt_altar", "position": [700, 250], "z_hint": "ysort", "blocker": "base",
             "notes": ["= future_exit khet_oasis_salt_altar (interação [E])"]},
        ],
        "scatter": {
            "generator": "_scatter_desert_decor",
            "solids_norm": [[0.08, 0.16], [0.92, 0.16], [0.10, 0.86], [0.90, 0.86]],
            "softs_norm": [[0.50, 0.09], [0.06, 0.50], [0.94, 0.50], [0.30, 0.92]],
            "notes": ["solids = cactus/dry_rock alternados (blocker pequeno)", "softs = bones/dry_tuft/sand_patch (sem blocker)"],
        },
        "interactions": [
            {"id": "salt_echo_event", "trigger": "kill:khet_oasis_salt_echo",
             "effect": "set_flag:khet_oasis_salt_echo_cleansed + reward(45xp,25ouro,1 Pedra Rúnica)",
             "runtime_only": True, "notes": ["recompensa 1× idempotente; após limpo, mobs do oásis somem (→[])"]},
        ],
        "runtime_only": [
            "recompensa de chegada (flag khet_oasis_reached: +35XP/+20ouro/+1 Poção de Mana, 1×)",
            "evento Eco do Sal (mobs condicionais por flag + cleanse + texto dinâmico do altar/Nara)",
            "hook _on_oasis_salt_echo_defeated",
            "lago/palmeiras/altar são PROCEDURAIS (placeholders no editor até haver arte)",
        ],
        "notes": [
            "região client-side (fora de regions.json); nome via _region_display_name",
            "Cidade do Deserto continua apenas future_exit/texto (khet_oasis_city_road NÃO transporta)",
        ],
    },

    {
        "id": "khet_caravan_camp",
        "display_name": "Acampamento de Caravana",
        "client_side": True,
        "size": [1500, 1000],
        "spawn": [250, 520],
        "ground": {
            "base_color": "#c9a86a",
            "path_color_rgba": [0.72, 0.58, 0.36, 0.42],
            "path_band": {"axis": "horizontal", "center_y": 500, "height": 150},
        },
        "access": {
            "gate_flag": "khet_sar_sentinel_defeated",
            "from_region": "khet_sar_sands",
            "from_exit": "khet_deep_dunes",
            "notes": ["entrada via future_exit 'Dunas Profundas' em Khet-Sar (gated pela flag)"],
        },
        "portals": [
            {"id": "khet_camp_to_khet", "position": [130, 540], "target_region": "khet_sar_sands",
             "target_spawn": [360, 250], "gate_flag": None, "draw_door": True,
             "label": "Trilha → Areais de Khet-Sar"},
            {"id": "camp_to_oasis", "position": [700, 920], "target_region": "khet_oasis",
             "target_spawn": [240, 460], "gate_flag": "caravan_camp_reached", "draw_door": True,
             "label": "Trilha Sul → Oásis de Khet-Sar",
             "notes": ["target_spawn = spawn padrão do oásis (OASIS_SPAWN); gate trivial (sempre setada no camp)"]},
        ],
        "future_exits": [
            {"id": "khet_city_gate", "position": [1380, 300], "label": "Portões da Cidade",
             "transports": False, "runtime_only": True,
             "notes": ["só texto; gancho da Cidade do Deserto (Opção C); NÃO transporta ainda"]},
        ],
        "npcs": [
            {"id": "yalla", "name": "Mercadora Yalla", "position": [900, 460], "sprite_key": "npcs/village/merchant",
             "service": "merchant", "wander": False,
             "runtime_only_fields": ["painel de loja compartilhado; título diegético 'Balcão da Yalla' por região"],
             "notes": ["sprite = placeholder medieval (merchant)"]},
            {"id": "kesh", "name": "Ferreiro Kesh", "position": [1180, 470], "sprite_key": "npcs/village/blacksmith",
             "service": "blacksmith", "wander": False, "z_off": 24,
             "runtime_only_fields": ["painel de forja compartilhado; título 'Forja do Kesh'"],
             "notes": ["sprite = placeholder medieval (blacksmith); z_off +24 (na frente da tenda)"]},
            {"id": "imir", "name": "Guia Imir", "position": [520, 620], "sprite_key": "npcs/village/elder",
             "service": None, "wander": True,
             "notes": ["lore; sprite placeholder medieval"]},
        ],
        "services": [
            {"id": "camp_healer", "kind": "healer", "position": [1060, 760], "label": "[E] descansar à fogueira",
             "runtime_only_fields": ["restaura HP + mana; diálogo 'Braseiro dos Viajantes'"],
             "notes": ["âncora no prop fogueira (1060,720)"]},
        ],
        "mobs": [],
        "chests": [],
        "props": [
            {"type": "procedural", "procedural_type": "campfire", "position": [1060, 720], "z_hint": "ysort", "blocker": None},
            {"type": "procedural", "procedural_type": "tent", "position": [900, 340], "params": {"w": 150, "h": 120, "cloth": "#c98b54"}, "z_hint": "ysort", "blocker": "base"},
            {"type": "procedural", "procedural_type": "tent", "position": [1180, 360], "params": {"w": 130, "h": 108, "cloth": "#b9743f"}, "z_hint": "ysort", "blocker": "base"},
            {"type": "procedural", "procedural_type": "tent", "position": [520, 360], "params": {"w": 132, "h": 110, "cloth": "#c2a06a"}, "z_hint": "ysort", "blocker": "base"},
            {"type": "procedural", "procedural_type": "wagon", "position": [360, 760], "z_hint": "ysort", "blocker": "body"},
            {"type": "procedural", "procedural_type": "wagon", "position": [1280, 760], "z_hint": "ysort", "blocker": "body"},
        ],
        "scatter": {
            "generator": "_scatter_desert_decor",
            "solids_norm": [[0.087, 0.17], [0.96, 0.15], [0.10, 0.90], [0.95, 0.90], [0.07, 0.40]],
            "softs_norm": [[0.47, 0.18], [0.505, 0.95], [0.96, 0.56], [0.30, 0.93], [0.72, 0.93]],
            "notes": ["solids = cactus/dry_rock alternados (blocker pequeno)", "softs = bones/dry_tuft/sand_patch (sem blocker)"],
        },
        "interactions": [],
        "runtime_only": [
            "marco caravan_camp_reached (popup 1×, SEM recompensa material)",
            "identidade diegética de loja/forja por região (Balcão da Yalla / Forja do Kesh)",
            "healer restaura HP + mana (diálogo 'Braseiro dos Viajantes')",
            "tendas/carroças/fogueira são PROCEDURAIS (placeholders no editor até haver arte)",
        ],
        "notes": [
            "região client-side (fora de regions.json); nome via _region_display_name",
            "NPCs usam sprite medieval da Vila (dívida visual; reskin com Lote 1 de arte do deserto)",
        ],
    },

    # ===== ARCO LITORAL→DESERTO (GODOT-MAP-MANIFEST-DESERT-ARC-EXPANSION-2) =====

    {
        "id": "saltwind_shore",
        "display_name": "Costa do Sal-Vento",
        "client_side": True,
        "size": [2200, 1300],
        "spawn": [300, 650],
        "ground": {"base_color": "#cdb98a", "path_color_rgba": [0.92, 0.88, 0.74, 0.30], "painted": True,
                   "notes": ["chão PINTADO (ground_painted.png) — terrain-only; só base_color é representável no editor"]},
        "access": {"gate_flag": None, "from_region": "old_road", "from_exit": "COAST_FROM_OLD_ROAD(2030,650)"},
        "portals": [
            {"id": "coast_to_old_road", "label": "Trilha → Ruínas da Estrada Velha", "position": [170, 650],
             "target_region": "old_road", "target_spawn": [1900, 650], "gate_flag": None, "draw_door": False},
        ],
        "future_exits": [
            {"id": "coast_sea_gate", "label": "Cais Quebrado — Rota Marítima", "position": [1100, 1120],
             "transports": False, "runtime_only": True,
             "notes": ["[E] no barco encalhado = quest de reparo (ver interactions); com boat_repaired VIAJA p/ castaway_sandbar",
                       "target_doc open_sea documentado, não ativo"]},
        ],
        "npcs": [], "services": [],
        "mobs": [
            {"mob_id": "dune_skitter", "name": "Escaravelho das Dunas", "visual": "dune_skitter", "hp": 60, "aggro": 380, "respawn": 7,
             "spawns": [[840, 420], [1520, 420], [1040, 860], [1700, 760]]},
            {"mob_id": "salt_husk", "name": "Casca de Sal", "visual": "salt_husk", "hp": 175, "aggro": 460, "respawn": 16, "ranged": True,
             "spawns": [[1140, 470], [760, 980]]},
            {"mob_id": "tide_warden", "name": "Guardião da Maré", "visual": "tide_warden", "hp": 240, "aggro": 360, "respawn": 40, "elite": True,
             "notes": ["elite-lite (NÃO boss-system); RESPAWNA (40s); SEM flag de derrota"], "spawns": [[1100, 940]]},
        ],
        "chests": [
            {"id": "coast_wreck_cache", "position": [320, 320], "loot": {"gold": 50, "materials": {"Madeira de Naufrágio": 2, "Sal Cristalizado": 1}, "items": ["potion_minor"]}},
            {"id": "coast_tidal_strongbox", "position": [1880, 320], "loot": {"gold": 70, "materials": {"Sal Cristalizado": 2, "Concha Polida": 2}}},
        ],
        "props": [
            {"type": "sprite", "procedural_type": "boat", "position": [1210, 1130], "blocker": "approx",
             "notes": ["barco encalhado (sprite real assets/effects/boats/saltwind_boat.png), proa leste; marco visual"]},
            {"type": "procedural", "procedural_type": "anchor", "position": [820, 1070], "blocker": "approx", "notes": ["âncora quebrada (marco da rota antiga)"]},
            {"type": "procedural", "procedural_type": "driftwood", "position": [440, 390], "params": {"scale": 0.4}, "blocker": "approx"},
            {"type": "procedural", "procedural_type": "driftwood", "position": [1716, 520], "params": {"scale": 0.6}, "blocker": "approx"},
        ],
        "scatter": {
            "generator": "_scatter_coast_decor", "coast_rocks_norm": [[0.16, 0.20], [0.42, 0.16], [0.70, 0.18], [0.88, 0.30], [0.22, 0.68], [0.80, 0.66], [0.60, 0.78]],
            "driftwood_norm": [[0.20, 0.30, 0.4], [0.78, 0.40, 0.6]], "anchor": [820, 1070], "water_blocker_inset": 195,
            "notes": ["chão PINTADO + colisão: mar (faixa sul) + 7 pedras sólidas (r=26) + 2 destroços + âncora",
                      "driftwood/anchor têm blocker no runtime mas a fórmula exata não foi resolvida aqui (lacuna)"],
        },
        "interactions": [
            {"id": "boat_repair", "trigger": "interact:coast_sea_gate", "runtime_only": True,
             "requires": {"Madeira de Naufrágio": 5, "Sal Cristalizado": 3, "Concha Polida": 2},
             "effect": "consome materiais + set_flag:boat_repaired + reward(90xp,60ouro,1 Poção de Mana); DEPOIS [E] no barco VIAJA p/ castaway_sandbar",
             "notes": ["o 'combate' não existe aqui; é turn-in de materiais (Guardião da Maré NÃO precisa morrer)"]},
        ],
        "runtime_only": [
            "marco coast_route_found (popup 1× na 1ª chegada)",
            "quest de reparo do barco (boat_repaired) + recompensa 1× (ver interactions)",
            "gate de embarque: só viaja ao Banco com boat_repaired",
            "chão pintado + coast decor procedural (placeholders no editor)",
        ],
        "notes": [
            "região client-side; nome via _region_display_name",
            "início do arco litoral→deserto; fronteira leste do mundo conhecido",
        ],
    },

    {
        "id": "castaway_sandbar",
        "display_name": "Banco de Areia dos Náufragos",
        "client_side": True,
        "size": [1500, 950],
        "spawn": [260, 760],
        "ground": {"base_color": "#d3c197", "path_color_rgba": [0.86, 0.86, 0.78, 0.34], "path_band": {"axis": "horizontal", "center_y": 475, "height": 150}},
        "access": {"gate_flag": "boat_repaired", "from_region": "saltwind_shore", "from_exit": "coast_sea_gate(barco)"},
        "portals": [
            {"id": "sandbar_to_coast", "label": "Barco → Costa do Sal-Vento", "position": [150, 820],
             "target_region": "saltwind_shore", "target_spawn": [980, 980], "gate_flag": None, "draw_door": True,
             "notes": ["retorno surge na Costa LONGE do barco (anti-loop)"]},
            {"id": "sandbar_to_isle", "label": "Travessia → Ilha do Sal Partido", "position": [1360, 480],
             "target_region": "salt_split_isle", "target_spawn": [260, 600], "gate_flag": "sandbar_reached", "draw_door": True},
        ],
        "future_exits": [], "npcs": [], "services": [],
        "mobs": [
            {"mob_id": "dune_skitter", "name": "Escaravelho das Dunas", "visual": "dune_skitter", "hp": 60, "aggro": 380, "respawn": 7,
             "spawns": [[700, 400], [1050, 560], [820, 800], [1250, 360]]},
            {"mob_id": "salt_husk", "name": "Casca de Sal", "visual": "salt_husk", "hp": 175, "aggro": 460, "respawn": 16, "ranged": True,
             "spawns": [[1150, 480], [900, 800]]},
            {"mob_id": "tide_warden", "name": "Guardião da Maré", "visual": "tide_warden", "hp": 240, "aggro": 360, "respawn": 40, "elite": True,
             "notes": ["elite-lite; respawna; SEM flag"], "spawns": [[1280, 700]]},
        ],
        "chests": [
            {"id": "sandbar_castaway_cache", "position": [1320, 240], "loot": {"gold": 60, "materials": {"Madeira de Naufrágio": 2, "Concha Polida": 1}, "items": ["potion_mana"]}},
        ],
        "props": [],
        "scatter": {"generator": "_scatter_desert_decor",
                    "solids_norm": [[0.22, 0.4], [0.58, 0.62], [0.78, 0.34], [0.35, 0.52], [0.1, 0.18], [0.28, 0.1], [0.5, 0.16], [0.72, 0.12], [0.9, 0.22], [0.14, 0.84], [0.4, 0.9], [0.64, 0.86], [0.86, 0.82], [0.95, 0.5]],
                    "softs_norm": [[0.2, 0.3], [0.66, 0.46], [0.46, 0.76], [0.82, 0.66], [0.3, 0.66]],
                    "notes": ["scatter de deserto (else-branch): 14 solids cactus/dry_rock alternados + 5 softs sem colisão"]},
        "interactions": [],
        "runtime_only": [
            "marco sandbar_reached (popup 1× na 1ª chegada; ABRE o portal p/ a Ilha)",
            "gate de chegada: só acessível via barco da Costa com boat_repaired",
            "scatter de deserto procedural (placeholders no editor)",
        ],
        "notes": ["região client-side; 1ª escala pós-barco", "anti-loop: retornos com spawn-offset"],
    },

    {
        "id": "salt_split_isle",
        "display_name": "Ilha do Sal Partido",
        "client_side": True,
        "size": [1800, 1200],
        "spawn": [260, 600],
        "ground": {"base_color": "#c9c2ad", "path_color_rgba": [0.90, 0.90, 0.86, 0.36], "path_band": {"axis": "horizontal", "center_y": 600, "height": 150}},
        "access": {"gate_flag": "sandbar_reached", "from_region": "castaway_sandbar", "from_exit": "sandbar_to_isle"},
        "portals": [
            {"id": "isle_to_sandbar", "label": "Barco → Banco de Areia", "position": [150, 660],
             "target_region": "castaway_sandbar", "target_spawn": [550, 250], "gate_flag": None, "draw_door": True,
             "notes": ["retorno surge no Banco no NO (anti-loop)"]},
        ],
        "future_exits": [
            {"id": "salt_isle_horizon", "label": "Horizonte Aberto", "position": [1680, 900],
             "transports": False, "runtime_only": True,
             "notes": ["só texto; com salt_isle_cleared VIAJA p/ khet_sar_sands (gancho do arco desértico)"]},
        ],
        "npcs": [], "services": [],
        "mobs": [
            {"mob_id": "dune_skitter", "name": "Escaravelho das Dunas", "visual": "dune_skitter", "hp": 78, "aggro": 400, "respawn": 7,
             "spawns": [[640, 360], [900, 760], [1180, 360], [760, 980], [1240, 980]]},
            {"mob_id": "salt_husk", "name": "Casca de Sal", "visual": "salt_husk", "hp": 200, "aggro": 480, "respawn": 16, "ranged": True,
             "spawns": [[1020, 520], [700, 760]]},
            {"mob_id": "salt_split_warden", "name": "Guardião do Sal Partido", "visual": "tide_warden", "hp": 720, "aggro": 520, "respawn": 999999,
             "elite": True, "defeat_flag": "salt_isle_cleared", "non_respawn": True,
             "reward": "1×: +60 XP, +80 ouro, Núcleo Trincado x2 (via _on_salt_isle_boss_defeated)", "runtime_only": True,
             "notes": ["MINI-BOSS elite (mob+flag, NÃO boss-system); loot garantido; não respawna"], "spawns": [[1450, 600]]},
        ],
        "chests": [
            {"id": "salt_isle_cache", "position": [1560, 240], "loot": {"gold": 90, "materials": {"Sal Cristalizado": 3, "Madeira de Naufrágio": 2, "Núcleo Trincado": 1}, "items": ["potion_minor"]}},
        ],
        "props": [],
        "scatter": {"generator": "_scatter_desert_decor",
                    "solids_norm": [[0.22, 0.4], [0.58, 0.62], [0.78, 0.34], [0.35, 0.52], [0.1, 0.18], [0.28, 0.1], [0.5, 0.16], [0.72, 0.12], [0.9, 0.22], [0.14, 0.84], [0.4, 0.9], [0.64, 0.86], [0.86, 0.82], [0.95, 0.5]],
                    "softs_norm": [[0.2, 0.3], [0.66, 0.46], [0.46, 0.76], [0.82, 0.66], [0.3, 0.66]],
                    "notes": ["scatter de deserto (else-branch)"]},
        "interactions": [
            {"id": "salt_isle_boss", "trigger": "kill:salt_split_warden", "runtime_only": True,
             "effect": "set_flag:salt_isle_cleared + reward(60xp,80ouro,Núcleo Trincado x2) + abre o Horizonte → khet_sar_sands"},
        ],
        "runtime_only": [
            "marco salt_isle_reached (popup 1× na 1ª chegada)",
            "mini-boss salt_split_warden: flag salt_isle_cleared + recompensa 1× + não-respawn",
            "Horizonte Aberto vira viagem real (p/ khet_sar_sands) só com salt_isle_cleared",
            "scatter de deserto procedural",
        ],
        "notes": ["região client-side; 2ª escala marítima", "elite via mob+flag (não boss-system)"],
    },

    {
        "id": "khet_sar_sands",
        "display_name": "Areais de Khet-Sar",
        "client_side": True,
        "size": [2000, 1300],
        "spawn": [280, 650],
        "ground": {"base_color": "#d8b87a", "path_color_rgba": [0.80, 0.66, 0.42, 0.40], "path_band": {"axis": "horizontal", "center_y": 650, "height": 150}},
        "access": {"gate_flag": "salt_isle_cleared", "from_region": "salt_split_isle", "from_exit": "salt_isle_horizon"},
        "portals": [
            {"id": "khet_to_isle", "label": "Barco → Ilha do Sal Partido", "position": [160, 720],
             "target_region": "salt_split_isle", "target_spawn": [1300, 600], "gate_flag": None, "draw_door": True,
             "notes": ["retorno surge na Ilha LONGE do Horizonte (anti-loop)"]},
        ],
        "future_exits": [
            {"id": "khet_deep_dunes", "label": "Dunas Profundas", "position": [1820, 900],
             "transports": False, "runtime_only": True,
             "notes": ["com khet_sar_sentinel_defeated VIAJA p/ khet_caravan_camp (Acampamento); senão texto de bloqueio"]},
        ],
        "npcs": [], "services": [],
        "mobs": [
            {"mob_id": "khet_skitter", "name": "Escaravelho de Khet-Sar", "visual": "dune_skitter", "hp": 92, "aggro": 410, "respawn": 7,
             "spawns": [[640, 380], [1000, 760], [1300, 380], [820, 1040], [1500, 980]]},
            {"mob_id": "khet_dry_sentry", "name": "Sentinela Ressecada", "visual": "fallen_sentry", "hp": 220, "aggro": 500, "respawn": 16, "ranged": True,
             "spawns": [[1120, 520], [760, 820]]},
            {"mob_id": "khet_wind_shade", "name": "Sombra de Vento", "visual": "crawling_shade", "hp": 120, "aggro": 440, "respawn": 10,
             "spawns": [[1180, 980], [560, 620]]},
            {"mob_id": "khet_sar_sentinel", "name": "Sentinela de Khet-Sar", "visual": "hollow_watcher", "hp": 820, "aggro": 540, "respawn": 999999,
             "elite": True, "defeat_flag": "khet_sar_sentinel_defeated", "non_respawn": True,
             "reward": "1×: +70 XP, +95 ouro, Pedra Rúnica x2 (via _on_khet_sentinel_defeated)", "runtime_only": True,
             "notes": ["ELITE LEVE (mob+flag, NÃO boss-system); não respawna"], "spawns": [[1600, 650]]},
        ],
        "chests": [
            {"id": "khet_buried_cache", "position": [1720, 280], "loot": {"gold": 100, "materials": {"Pedra Rúnica": 2, "Fragmento de Cristal": 1, "Sal Cristalizado": 2}, "items": ["potion_mana"]}},
        ],
        "props": [],
        "scatter": {"generator": "_scatter_desert_decor",
                    "solids_norm": [[0.22, 0.4], [0.58, 0.62], [0.78, 0.34], [0.35, 0.52], [0.1, 0.18], [0.28, 0.1], [0.5, 0.16], [0.72, 0.12], [0.9, 0.22], [0.14, 0.84], [0.4, 0.9], [0.64, 0.86], [0.86, 0.82], [0.95, 0.5]],
                    "softs_norm": [[0.2, 0.3], [0.66, 0.46], [0.46, 0.76], [0.82, 0.66], [0.3, 0.66]],
                    "notes": ["scatter de deserto (else-branch)"]},
        "interactions": [
            {"id": "khet_sentinel", "trigger": "kill:khet_sar_sentinel", "runtime_only": True,
             "effect": "set_flag:khet_sar_sentinel_defeated + reward(70xp,95ouro,Pedra Rúnica x2) + abre as Dunas Profundas → khet_caravan_camp"},
        ],
        "runtime_only": [
            "marco khet_sar_reached (popup 1× na 1ª chegada)",
            "elite khet_sar_sentinel: flag khet_sar_sentinel_defeated + recompensa 1× + não-respawn",
            "Dunas Profundas viram viagem real (p/ khet_caravan_camp) só com a flag do elite",
            "scatter de deserto procedural",
        ],
        "notes": ["região client-side; 1ª região DESÉRTICA (novo continente)", "elite via mob+flag (não boss-system)"],
    },

    # ===== JOGO COMPLETO: regiões runtime-authored antigas (GODOT-MAP-MANIFEST-FULL-GAME-EXPANSION-AND-EDITOR-ID-FIX-1) =====
    # Extração FIEL de Main.gd (size/spawn/ground/portals/NPCs/services/mobs/chests). props/blockers dessas
    # regiões = scatter procedural / tilesets reais → NÃO extraídos neste passo (runtime_only/lacuna documentada).
    # Mobs em formato leve (mob_id/visual/name/hp/aggro/respawn/spawns); stats completos de combate vivem no
    # runtime. Bosses construídos fora de _mob_configs (_build_wolf/_build_golem) entram como runtime_only.

    {
        "id": "starter_village", "display_name": "Vila dos Novatos", "client_side": True,
        "size": [2200, 1600], "spawn": [1100, 950],
        "ground": {"base_color": "#3c6b34", "path_color_rgba": [0.55, 0.5, 0.4, 0.4], "notes": ["chão PINTADO (plaza.png/grama da Planície) — só base_color representável"]},
        "access": {"gate_flag": None, "from_region": None, "notes": ["HUB central do jogo (4 saídas cardeais)"]},
        "portals": [
            {"id": "village_gate", "label": "Portão → Planície dos Novatos", "position": [1100, 1450], "target_region": "plains", "target_spawn": None, "gate_flag": None, "draw_door": False},
            {"id": "village_to_swamp", "label": "Trilha Oeste → Pântano de Ferro", "position": [170, 800], "target_region": "swamp", "target_spawn": None, "gate_flag": "golem_defeated_or_lvl8", "draw_door": True, "notes": ["GATED no runtime: Golem de Cristal derrotado OU nível>=8"]},
            {"id": "village_to_east", "label": "Estrada Leste → Ruínas da Estrada Velha", "position": [2030, 800], "target_region": "old_road", "target_spawn": None, "gate_flag": None, "draw_door": True},
            {"id": "village_to_north", "label": "Trilha Norte → Bosque de Cinza", "position": [1100, 150], "target_region": "ashen_grove", "target_spawn": None, "gate_flag": None, "draw_door": True},
        ],
        "future_exits": [],
        "npcs": [
            {"id": "elder_maelis", "name": "Anciã Maelis", "position": [1100, 1080], "sprite_key": "npcs/village/elder", "service": None, "wander": True, "notes": ["guia do tutorial (fala dinâmica no runtime)"]},
            {"id": "guard_tomas", "name": "Guarda Tomas", "position": [1300, 1180], "sprite_key": "npcs/village/guard", "service": None, "wander": True},
            {"id": "farmer_bran", "name": "Fazendeiro Bran", "position": [560, 1180], "sprite_key": "npcs/village/farmer", "service": None, "wander": True},
            {"id": "merchant_sila", "name": "Mercadora Sila", "position": [1560, 1100], "sprite_key": "npcs/village/merchant", "service": "merchant", "wander": False},
            {"id": "blacksmith_dorn", "name": "Ferreiro Dorn", "position": [1496, 690], "sprite_key": "npcs/village/blacksmith", "service": "blacksmith", "wander": False, "z_off": 24},
        ],
        "services": [
            {"id": "village_healer", "kind": "healer", "position": [352, 1280], "label": "[E] descansar (curar)"},
            {"id": "village_board", "kind": "quest_board", "position": [660, 576], "label": "[E] ler o mural", "runtime_only_fields": ["mural de bounties/side-quests (runtime)"]},
            {"id": "village_shrine", "kind": "shrine", "position": [1386, 992], "label": "[E] tocar o santuário"},
            {"id": "village_stash", "kind": "stash", "position": [1276, 1248], "label": "[E] abrir o Baú do Errante", "runtime_only_fields": ["depósito permanente do jogador (player_stash)"]},
        ],
        "mobs": [], "chests": [], "props": [], "blockers": [],
        "interactions": [],
        "runtime_only": [
            "HUB seguro (sem boss/mob)", "tutorial/onboarding (Anciã Maelis)", "side-quests/bounties no mural",
            "loja (Sila)/forja (Dorn) compartilhadas", "Baú do Errante (stash) + santuário de surgimento",
            "props/blockers = _scatter_village_props + tileset pintado (não extraídos neste passo)",
        ],
        "notes": ["região client-side; HUB central; 4 saídas cardeais (sul Planície/oeste Pântano/leste Ruínas/norte Bosque)"],
    },

    {
        "id": "plains", "display_name": "Planície dos Novatos", "client_side": False,
        "size": [2400, 1600], "spawn": [520, 840],
        "ground": {"base_color": "#3c6b34", "path_color_rgba": [0.62, 0.52, 0.34, 0.5], "notes": ["tileset real (grass/dirt) — só base_color representável"]},
        "access": {"gate_flag": None, "from_region": "starter_village"},
        "portals": [
            {"id": "plains_to_cave", "label": "Entrada da Caverna", "position": [2180, 820], "target_region": "cave", "target_spawn": None, "gate_flag": None, "draw_door": False},
            {"id": "plains_to_village", "label": "Estrada → Vila dos Novatos", "position": [170, 840], "target_region": "starter_village", "target_spawn": [1100, 1320], "gate_flag": None, "draw_door": False},
        ],
        "future_exits": [],
        "npcs": [{"id": "aldric", "name": "Aldric Vaelor", "position": [980, 720], "sprite_key": "actors/npcs/aldric_vaelor", "service": None, "wander": False, "notes": ["NPC de campanha (Ato 1)"]}],
        "services": [],
        "mobs": [
            {"mob_id": "young_wolf", "name": "Lobo Jovem", "visual": "young_wolf", "hp": 30, "aggro": 320, "respawn": 6, "spawns": [[900, 520], [1750, 520], [1250, 1320], [2000, 1180], [720, 1260]]},
            {"mob_id": "wild_boar", "name": "Javali Bravio", "visual": "wild_boar", "hp": 48, "aggro": 300, "respawn": 7, "spawns": [[1500, 400], [650, 400], [2050, 560]]},
            {"mob_id": "road_bandit", "name": "Bandido de Estrada", "visual": "road_bandit", "hp": 75, "aggro": 420, "respawn": 14, "spawns": [[2080, 520]]},
            {"mob_id": "starving_wolf", "name": "Lobo Faminto", "visual": "young_wolf", "hp": 36, "aggro": 360, "respawn": 7, "spawns": [[1080, 700], [1380, 760], [1240, 640]]},
            {"mob_id": "elder_boar", "name": "Javali Ancião", "visual": "wild_boar", "hp": 120, "aggro": 280, "respawn": 16, "spawns": [[1500, 1100], [820, 900]]},
        ],
        "chests": [{"id": "plains_supply_cache_1", "position": [700, 1180], "loot": {"gold": 25, "materials": {"Couro Áspero": 2}, "items": ["potion_minor"]}}],
        "props": [], "blockers": [], "interactions": [],
        "runtime_only": ["BOSS Lobo Alfa @ (1480,1110) — construído em _build_wolf (fora de _mob_configs)", "Aldric = NPC de campanha (Ato 1)", "props/blockers = _scatter_plains_props + tileset (não extraídos)"],
        "notes": ["Ato 1; em regions.json; mobs com stats completos no runtime"],
    },

    {
        "id": "cave", "display_name": "Caverna Esquecida", "client_side": False,
        "size": [1800, 1200], "spawn": [440, 620],
        "ground": {"base_color": "#1b2030", "path_color_rgba": [0.4, 0.44, 0.55, 0.3], "notes": ["tileset real (cave_floor) — só base_color representável"]},
        "access": {"gate_flag": None, "from_region": "plains"},
        "portals": [{"id": "cave_to_plains", "label": "Saída para a Planície", "position": [250, 600], "target_region": "plains", "target_spawn": None, "gate_flag": None, "draw_door": False}],
        "future_exits": [], "npcs": [], "services": [],
        "mobs": [
            {"mob_id": "crystal_bat", "name": "Morcego Cristalino", "visual": "crystal_bat", "hp": 56, "aggro": 360, "respawn": 7, "spawns": [[720, 360], [1120, 920], [1500, 940]]},
            {"mob_id": "living_shard", "name": "Fragmento Vivo", "visual": "living_shard", "hp": 62, "aggro": 300, "respawn": 8, "spawns": [[980, 700], [1120, 430]]},
            {"mob_id": "crawling_shade", "name": "Sombra", "visual": "crawling_shade", "hp": 90, "aggro": 440, "respawn": 12, "spawns": [[1520, 350]]},
            {"mob_id": "grove_spider", "name": "Aranha do Mato", "visual": "grove_spider", "hp": 46, "aggro": 340, "respawn": 6, "spawns": [[640, 980], [1320, 820]]},
            {"mob_id": "green_slime", "name": "Gosma Verde", "visual": "green_slime", "hp": 38, "aggro": 280, "respawn": 6, "spawns": [[840, 300], [1200, 360]]},
            {"mob_id": "dusk_bat", "name": "Morcego da Penumbra", "visual": "crystal_bat", "hp": 30, "aggro": 380, "respawn": 6.5, "spawns": [[820, 420], [1180, 860], [1420, 880], [900, 1000]]},
            {"mob_id": "stone_sentinel", "name": "Sentinela de Pedra", "visual": "stone_sentinel", "hp": 140, "aggro": 300, "respawn": 18, "elite": True, "spawns": [[1640, 920]]},
        ],
        "chests": [], "props": [], "blockers": [], "interactions": [],
        "runtime_only": ["BOSS Golem de Cristal @ (1380,600) — construído em _build_golem (fora de _mob_configs)", "props/blockers = _scatter_cave_decor + tileset (não extraídos)"],
        "notes": ["Ato 2; em regions.json"],
    },

    {
        "id": "swamp", "display_name": "Pântano de Ferro", "client_side": False,
        "size": [2000, 1400], "spawn": [320, 700],
        "ground": {"base_color": "#2c352a", "path_color_rgba": [0.34, 0.30, 0.20, 0.45], "notes": ["tileset/manchas de lodo — só base_color representável"]},
        "access": {"gate_flag": "golem_defeated_or_lvl8", "from_region": "starter_village", "notes": ["gated pela saída oeste da Vila"]},
        "portals": [
            {"id": "swamp_to_village", "label": "Trilha → Vila dos Novatos", "position": [220, 700], "target_region": "starter_village", "target_spawn": [320, 800], "gate_flag": None, "draw_door": True},
            {"id": "swamp_to_pit", "label": "Buraco do Ferro-Velho", "position": [1520, 1060], "target_region": "swamp_pit", "target_spawn": None, "gate_flag": None, "draw_door": False, "notes": ["buraco que desce à subárea swamp_pit"]},
        ],
        "future_exits": [],
        "npcs": [],
        "services": [{"id": "swamp_spring", "kind": "swamp_spring", "position": [520, 760], "label": "[E] beber da Fonte de Água Férrea", "runtime_only_fields": ["cura PARCIAL 1× por visita (flag transiente, não persiste)"]}],
        "mobs": [
            {"mob_id": "bog_crawler", "name": "Lodo Rastejante", "visual": "green_slime", "hp": 55, "aggro": 300, "respawn": 7, "spawns": [[760, 520], [1180, 760], [900, 980]]},
            {"mob_id": "iron_leech", "name": "Sanguessuga de Ferro", "visual": "grove_spider", "hp": 38, "aggro": 380, "respawn": 6.5, "spawns": [[1340, 460], [1500, 700], [1280, 940], [1620, 520]]},
        ],
        "chests": [
            {"id": "swamp_sunken_cache", "position": [760, 980], "loot": {"gold": 35, "materials": {"Limo de Ferro": 2}, "items": ["potion_minor"]}},
            {"id": "swamp_root_hollow", "position": [1500, 360], "loot": {"gold": 25, "materials": {"Raiz Pútrida": 2}}},
        ],
        "props": [], "blockers": [], "interactions": [],
        "runtime_only": ["Fonte de Água Férrea (serviço swamp_spring, cura parcial 1×/visita)", "props/blockers = _scatter_swamp_decor (não extraídos)"],
        "notes": ["região de hunt pós-Caverna; sem boss; subárea swamp_pit pelo buraco"],
    },

    {
        "id": "swamp_pit", "display_name": "Poço do Ferro-Velho", "client_side": True,
        "size": [1000, 800], "spawn": [290, 400],
        "ground": {"base_color": "#181d1a", "path_color_rgba": [0.30, 0.27, 0.20, 0.3]},
        "access": {"gate_flag": None, "from_region": "swamp", "from_exit": "swamp_to_pit", "notes": ["subárea: só pelo buraco do Pântano"]},
        "portals": [{"id": "pit_to_swamp", "label": "Escada → subir ao Pântano", "position": [170, 400], "target_region": "swamp", "target_spawn": [1520, 980], "gate_flag": None, "draw_door": True}],
        "future_exits": [], "npcs": [], "services": [],
        "mobs": [
            {"mob_id": "scrap_colossus", "name": "Coloso de Ferro-Velho", "visual": "scrap_colossus", "hp": 170, "aggro": 340, "respawn": 20, "elite": True, "spawns": [[550, 440]]},
            {"mob_id": "iron_leech", "name": "Sanguessuga de Ferro", "visual": "grove_spider", "hp": 38, "aggro": 360, "respawn": 8, "spawns": [[320, 300], [340, 560]]},
        ],
        "chests": [{"id": "pit_colossus_hoard", "position": [820, 440], "loot": {"gold": 45, "materials": {"Núcleo Trincado": 1, "Limo de Ferro": 2}, "items": ["potion_minor"]}}],
        "props": [], "blockers": [], "interactions": [],
        "runtime_only": ["elite Coloso de Ferro-Velho (mob elite, NÃO boss-system; respawn 20s)", "props/blockers = _scatter_pit_decor (não extraídos)"],
        "notes": ["subárea client-side (arena do Coloso)"],
    },

    {
        "id": "old_road", "display_name": "Ruínas da Estrada Velha", "client_side": True,
        "size": [2200, 1300], "spawn": [320, 650],
        "ground": {"base_color": "#4a4636", "path_color_rgba": [0.55, 0.5, 0.4, 0.4], "notes": ["tileset real (ground_large) — só base_color representável"]},
        "access": {"gate_flag": None, "from_region": "starter_village", "from_exit": "village_to_east"},
        "portals": [
            {"id": "east_to_village", "label": "Trilha → Vila dos Novatos", "position": [220, 650], "target_region": "starter_village", "target_spawn": [1880, 800], "gate_flag": None, "draw_door": True},
            {"id": "old_road_to_coast", "label": "Rota Antiga ao Mar → Costa do Sal-Vento", "position": [2030, 650], "target_region": "saltwind_shore", "target_spawn": [300, 650], "gate_flag": None, "draw_door": False},
        ],
        "future_exits": [], "npcs": [], "services": [],
        "mobs": [
            {"mob_id": "ruin_raider", "name": "Salteador das Ruínas", "visual": "road_bandit", "hp": 70, "aggro": 400, "respawn": 12, "spawns": [[1100, 500], [1500, 820], [1750, 560]]},
            {"mob_id": "feral_hound", "name": "Cão Selvagem", "visual": "young_wolf", "hp": 40, "aggro": 360, "respawn": 7, "spawns": [[800, 900], [1000, 1050], [1250, 720]]},
            {"mob_id": "fallen_sentry", "name": "Sentinela Tombada", "visual": "fallen_sentry", "hp": 130, "aggro": 300, "respawn": 18, "elite": True, "spawns": [[1850, 650]]},
        ],
        "chests": [
            {"id": "road_milestone_cache", "position": [1600, 300], "loot": {"gold": 35, "materials": {"Pedra Rúnica": 2}, "items": ["potion_minor"]}},
            {"id": "road_toll_strongbox", "position": [1950, 1000], "loot": {"gold": 50, "materials": {"Bolsa de Moedas": 1, "Pedra Rúnica": 1}}},
        ],
        "props": [], "blockers": [], "interactions": [],
        "runtime_only": ["elite Sentinela Tombada (respawn 18s)", "props/blockers = _scatter_ruins_decor (não extraídos)", "leste leva ao arco litoral/deserto (Costa)"],
        "notes": ["região de hunt leste; ponte p/ o arco do deserto"],
    },

    {
        "id": "ashen_grove", "display_name": "Bosque de Cinza", "client_side": True,
        "size": [2200, 1300], "spawn": [700, 1120],
        "ground": {"base_color": "#23282a", "path_color_rgba": [0.4, 0.42, 0.38, 0.3], "notes": ["chão pintado (ground_painted) — só base_color representável"]},
        "access": {"gate_flag": None, "from_region": "starter_village", "from_exit": "village_to_north"},
        "portals": [
            {"id": "north_to_village", "label": "Trilha → Vila dos Novatos", "position": [700, 1200], "target_region": "starter_village", "target_spawn": [1100, 280], "gate_flag": None, "draw_door": True},
            {"id": "grove_north_seal", "label": "Raízes Negras → Coração do Bosque", "position": [1100, 250], "target_region": "deep_grove", "target_spawn": [900, 1090], "gate_flag": None, "draw_door": False},
        ],
        "future_exits": [], "npcs": [], "services": [],
        "mobs": [
            {"mob_id": "ash_wolf", "name": "Lobo de Cinza", "visual": "ash_wolf", "hp": 45, "aggro": 360, "respawn": 7, "spawns": [[700, 500], [1000, 760], [520, 820]]},
            {"mob_id": "veil_spider", "name": "Aranha Veladora", "visual": "veil_spider", "hp": 50, "aggro": 360, "respawn": 8, "spawns": [[1450, 520], [1650, 800], [1300, 900]]},
            {"mob_id": "moss_warden", "name": "Guardião de Musgo", "visual": "moss_warden", "hp": 140, "aggro": 300, "respawn": 18, "elite": True, "spawns": [[1100, 560]]},
        ],
        "chests": [
            {"id": "grove_hollow_cache", "position": [350, 400], "loot": {"gold": 35, "materials": {"Cinza Arcana": 2}, "items": ["potion_minor"]}},
            {"id": "grove_monolith_offering", "position": [1850, 350], "loot": {"gold": 45, "materials": {"Cinza Arcana": 1, "Núcleo Trincado": 1}}},
        ],
        "props": [], "blockers": [], "interactions": [],
        "runtime_only": ["elite Guardião de Musgo (respawn 18s)", "props/blockers = _scatter_grove_decor + chão pintado (não extraídos)", "norte abre p/ o Deep Grove"],
        "notes": ["região norte; início do arco das Raízes Negras"],
    },

    {
        "id": "deep_grove", "display_name": "Coração das Raízes Negras", "client_side": True,
        "size": [1800, 1300], "spawn": [900, 1090],
        "ground": {"base_color": "#15171a", "path_color_rgba": [0.26, 0.22, 0.26, 0.34], "notes": ["chão pintado — só base_color representável"]},
        "access": {"gate_flag": None, "from_region": "ashen_grove", "from_exit": "grove_north_seal"},
        "portals": [
            {"id": "deep_to_grove", "label": "Passagem → Bosque de Cinza", "position": [900, 1230], "target_region": "ashen_grove", "target_spawn": [1100, 360], "gate_flag": None, "draw_door": False},
            {"id": "deep_north_exit", "label": "Raízes Profundas → Ninho Ancestral", "position": [900, 130], "target_region": "ancient_root_nest", "target_spawn": [850, 1030], "gate_flag": None, "draw_door": False},
        ],
        "future_exits": [], "npcs": [], "services": [],
        "mobs": [
            {"mob_id": "dark_sprout", "name": "Broto Sombrio", "visual": "shadow_sprout", "hp": 60, "aggro": 360, "respawn": 7, "spawns": [[520, 820], [1300, 820], [720, 960]]},
            {"mob_id": "root_spider", "name": "Aranha de Raiz", "visual": "root_spider", "hp": 72, "aggro": 360, "respawn": 8, "spawns": [[450, 460], [1350, 460], [600, 640]]},
            {"mob_id": "hollow_watcher", "name": "Vigia Oco", "visual": "hollow_watcher", "hp": 165, "aggro": 300, "respawn": 18, "elite": True, "spawns": [[1400, 660], [400, 660]]},
            {"mob_id": "root_matriarch", "name": "Matriarca das Raízes", "visual": "root_matriarch", "hp": 280, "aggro": 360, "respawn": 60, "elite": True, "spawns": [[900, 560]], "notes": ["mini-boss (mob elite); respawn 60s"]},
        ],
        "chests": [
            {"id": "deep_root_reliquary", "position": [340, 980], "loot": {"gold": 55, "materials": {"Raiz Negra": 2}, "items": ["potion_minor"]}},
            {"id": "deep_buried_altar", "position": [1460, 360], "loot": {"gold": 70, "materials": {"Raiz Negra": 1, "Núcleo Trincado": 1}}},
        ],
        "props": [], "blockers": [], "interactions": [],
        "runtime_only": ["mini-boss Matriarca das Raízes (mob elite)", "elite Vigia Oco", "props/blockers = _scatter_deep_grove_decor (não extraídos)"],
        "notes": ["subárea norte do Bosque; arco das Raízes Negras"],
    },

    {
        "id": "ancient_root_nest", "display_name": "Ninho da Raiz Ancestral", "client_side": True,
        "size": [1700, 1200], "spawn": [850, 1030],
        "ground": {"base_color": "#100d10", "path_color_rgba": [0.30, 0.20, 0.14, 0.36], "notes": ["chão pintado — só base_color representável"]},
        "access": {"gate_flag": None, "from_region": "deep_grove", "from_exit": "deep_north_exit"},
        "portals": [{"id": "nest_to_deep", "label": "Passagem → Coração das Raízes", "position": [850, 1150], "target_region": "deep_grove", "target_spawn": [900, 240], "gate_flag": None, "draw_door": False}],
        "future_exits": [], "npcs": [], "services": [],
        "mobs": [
            {"mob_id": "hungry_root", "name": "Raiz Faminta", "visual": "hungry_root", "hp": 52, "aggro": 400, "respawn": 7, "spawns": [[480, 760], [1220, 760], [680, 920], [1020, 920]]},
            {"mob_id": "hollow_husk", "name": "Carapaça Oca", "visual": "hollow_husk", "hp": 195, "aggro": 300, "respawn": 18, "elite": True, "spawns": [[440, 520], [1260, 520]]},
            {"mob_id": "sap_eye", "name": "Olho de Seiva", "visual": "sap_eye", "hp": 96, "aggro": 460, "respawn": 12, "spawns": [[320, 380], [1380, 380]]},
            {"mob_id": "ancient_root_heart", "name": "Coração da Raiz Ancestral", "visual": "ancient_root_heart", "hp": 460, "aggro": 420, "respawn": 90, "elite": True, "defeat_flag": "(fechamento do arco das Raízes — _on_ancient_heart_defeated)", "runtime_only": True, "spawns": [[850, 360]], "notes": ["BOSS do arco (mob elite); derrota dispara fechamento no runtime"]},
        ],
        "chests": [
            {"id": "nest_marrow_cache", "position": [300, 980], "loot": {"gold": 80, "materials": {"Seiva Negra Cristalizada": 2}, "items": ["potion_minor"]}},
            {"id": "nest_ancient_reliquary", "position": [1400, 300], "loot": {"gold": 110, "materials": {"Fragmento da Raiz Ancestral": 1, "Núcleo de Raiz Negra": 1}}},
        ],
        "props": [], "blockers": [], "interactions": [],
        "runtime_only": ["BOSS Coração da Raiz Ancestral (mob elite + fechamento de arco)", "elite Carapaça Oca", "props/blockers = _scatter_ancient_nest_decor (não extraídos)"],
        "notes": ["fechamento do arco das Raízes Negras (subárea norte do Deep Grove)"],
    },
]


def main():
    here = os.path.dirname(os.path.abspath(__file__))            # godot/tools
    godot_root = os.path.dirname(here)                            # godot
    out_dir = os.path.join(godot_root, "data", "map_manifest")
    os.makedirs(out_dir, exist_ok=True)
    written = []
    for region in REGIONS:
        region = dict(region)                                     # copia rasa
        region["mobs"] = expand_mobs(region.get("mobs", []), region["id"])   # spawns → 1 entrada/posição (id único region-prefixado)
        base_blk = build_blockers(region)                        # blockers dos props/scatter de DESERTO (props originais)
        lprops, lblk = legacy_decor(region)                      # props/blockers das 9 regiões antigas (legacy_scatter)
        region["props"] = (region.get("props") or []) + lprops
        region["blockers"] = base_blk + lblk
        doc = dict(SCHEMA_HEADER)
        doc["region"] = region                                   # 1 região por arquivo (manifesto singular)
        path = os.path.join(out_dir, region["id"] + ".json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(doc, f, ensure_ascii=False, indent=2)
            f.write("\n")
        written.append(path)
        print("escrito:", os.path.relpath(path, godot_root),
              "| blockers:", len(region["blockers"]),
              "| props:", len(region["props"]),
              "| npcs:", len(region["npcs"]),
              "| mobs:", len(region["mobs"]))
    print("OK —", len(written), "manifest(s).")


if __name__ == "__main__":
    main()
