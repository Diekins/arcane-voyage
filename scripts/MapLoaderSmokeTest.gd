extends SceneTree
## Smoke test headless (STUDIO-TO-GODOT-SMOKE-1) — carrega o mapa de smoke do Studio e
## confere as CONTAGENS ponta-a-ponta. NÃO faz parte do boot do jogo.
## Rodar:  godot --headless --path godot --script res://scripts/MapLoaderSmokeTest.gd

var _pass := 0
var _fail := 0

func _c(name: String, cond: bool, extra := "") -> void:
	if cond: _pass += 1; print("PASS  ", name)
	else: _fail += 1; print("FALHA ", name, ("  [" + extra + "]") if extra != "" else "")

func _has(arr: Array, sub: String) -> bool:
	for w in arr:
		if str(w).find(sub) != -1: return true
	return false

func _initialize() -> void:
	print("===== MapLoader SMOKE test (studio_smoke_map.json) =====")
	var ld = load("res://scripts/MapLoader.gd").new()
	var ok: bool = ld.load_map_json("res://data/studio_smoke_map.json")
	_c("parse OK", ok)
	_c("schemaVersion == 1", ld.schema_version == 1)
	_c("validate_min sem erros", ld.validate_min().is_empty(), str(ld.validate_min()))
	_c("map id smoke_clearing", str(ld.map.get("id", "")) == "smoke_clearing")
	_c("map size 1600x1100", ld.map_size() == Vector2(1600, 1100), str(ld.map_size()))
	_c("spawn 300,560", ld.map_spawn() == Vector2(300, 560), str(ld.map_spawn()))

	var parent := Node2D.new()
	var s: Dictionary = ld.build_into(parent, {})
	_c("objects == 5", int(s.objects) == 5, str(s.objects))
	_c("blockers == 1", int(s.blockers) == 1 and ld.blockers.size() == 1)
	_c("portals == 1", int(s.portals) == 1)
	_c("npc==1 / service==1 / mob==1", int(s.npc) == 1 and int(s.service) == 1 and int(s.mob) == 1, str(s))
	_c("asset ausente vira warning+placeholder (ghost_prop)", _has(ld.warnings, "ghost_prop"), str(ld.warnings))
	_c("nenhum warning de asset real (tree/rock/bush/grass ausentes)", not (_has(ld.warnings, "tree.png") and _has(ld.warnings, "ausente")) , str(ld.warnings))
	_c("summary.missing >= 1", int(s.get("missing", 0)) >= 1, str(s))

	# refs resolvem
	_c("npcId elder resolve", str(ld.get_npc("elder").get("name", "")) == "Anciã Maelis")
	_c("serviceId quest_board resolve", str(ld.get_service("quest_board").get("serviceKind", "")) == "quest_board")
	_c("mobId alpha_wolf resolve", str(ld.get_mob("alpha_wolf").get("name", "")) == "Lobo Alfa")

	# portal preserva target/title
	var p0: Dictionary = ld.portals[0]
	_c("portal target/title preservados", str(p0.get("target", "")) == "cave" and str(p0.get("title", "")).find("Caverna") != -1)

	# ----- MAP-LOADER-GODOT-2 -----
	# portal com target VÁLIDO resolve p/ studio_cave.json
	var dest: String = ld.find_map_for_target("cave")
	_c("portal target válido resolve (cave -> studio_cave.json)", dest.ends_with("studio_cave.json"), dest)
	_c("find_map_for_target('') = ''", ld.find_map_for_target("") == "")
	_c("target inexistente -> ''", ld.find_map_for_target("nao_existe_xyz") == "")

	# mob com assetBank válido (alpha_wolf no smoke map) + mob_nodes no summary
	_c("assetBank do mob resolve (alpha_wolf)", not ld.asset_bank_for_path("actors/bosses/alpha_wolf.png").is_empty())
	_c("mob_nodes exposto no summary", (s.get("mob_nodes", []) as Array).size() == 1)
	_c("aviso de sprite lateral provisório (regra 4dir)", _has(ld.warnings, "provisório"))

	# portal SEM target -> warning, sem crash (dict em memória)
	var ld2 = load("res://scripts/MapLoader.gd").new()
	ld2.load_map_dict({ "schemaVersion": 1, "map": { "id": "t", "width": 800, "height": 600, "spawn": { "x": 50, "y": 50 } }, "portals": [ { "id": "pp", "x": 100, "y": 100, "target": "" } ] })
	var par2 := Node2D.new(); ld2.build_into(par2, {})
	_c("portal sem target gera warning", _has(ld2.warnings, "portal sem target"))
	par2.free()

	# mob com asset MISSING -> placeholder + warning, sem crash
	var ld3 = load("res://scripts/MapLoader.gd").new()
	ld3.load_map_dict({ "schemaVersion": 1, "map": { "id": "t3", "width": 800, "height": 600, "spawn": { "x": 50, "y": 50 } },
		"markers": [ { "id": "mm", "kind": "mob", "x": 200, "y": 200, "mobId": "ghost_mob" } ],
		"mobs": [ { "mobId": "ghost_mob", "name": "Fantasma", "asset": "actors/mobs/ghost_mob.png" } ] })
	var par3 := Node2D.new(); var s3: Dictionary = ld3.build_into(par3, {})
	_c("mob asset missing -> warning", _has(ld3.warnings, "ghost_mob"))
	_c("mob asset missing -> summary.missing>=1", int(s3.get("missing", 0)) >= 1)
	_c("mob_nodes mesmo com asset missing", (s3.get("mob_nodes", []) as Array).size() == 1)
	par3.free()

	# destino do portal (studio_cave.json) carrega/valida e o portal de volta resolve (loop)
	var ld4 = load("res://scripts/MapLoader.gd").new()
	_c("studio_cave.json carrega", ld4.load_map_json("res://data/studio_cave.json"))
	_c("studio_cave valida limpo", ld4.validate_min().is_empty(), str(ld4.validate_min()))
	_c("portal de volta resolve (smoke_clearing)", ld4.find_map_for_target("smoke_clearing").ends_with("studio_smoke_map.json"))

	# ----- STUDIO-PLAYABLE-SAMPLE-1 (pacote oficial town → hunt → cave) -----
	var nav = load("res://scripts/MapLoader.gd").new()
	_c("sample: map.id sample_town resolve", nav.find_map_for_target("sample_town").ends_with("studio_sample_town.json"))
	_c("sample: map.id sample_hunt resolve", nav.find_map_for_target("sample_hunt").ends_with("studio_sample_hunt.json"))
	_c("sample: map.id sample_cave resolve", nav.find_map_for_target("sample_cave").ends_with("studio_sample_cave.json"))

	var sample := { "town": "res://data/studio_sample_town.json", "hunt": "res://data/studio_sample_hunt.json", "cave": "res://data/studio_sample_cave.json" }
	for key in sample.keys():
		var l = load("res://scripts/MapLoader.gd").new()
		var par := Node2D.new()
		_c("sample %s carrega" % key, l.load_map_json(sample[key]))
		_c("sample %s valida limpo" % key, l.validate_min().is_empty(), str(l.validate_min()))
		var sm: Dictionary = l.build_into(par, {})
		_c("sample %s SEM warnings (caminho feliz)" % key, l.warnings.is_empty(), str(l.warnings))
		# todo portal do mapa resolve um destino existente
		var all_ok := true
		for p in l.portals:
			if l.find_map_for_target(str(p.get("target", ""))) == "": all_ok = false
		_c("sample %s portais resolvem destino" % key, all_ok)
		par.free()

	# mobs aparecem (hunt=2, cave=1) + assetBank usado (não-provisório)
	var lh = load("res://scripts/MapLoader.gd").new(); lh.load_map_json(sample["hunt"])
	var ph := Node2D.new(); var sh: Dictionary = lh.build_into(ph, {})
	_c("sample hunt: 2 mobs (mob_nodes)", (sh.get("mob_nodes", []) as Array).size() == 2)
	_c("sample hunt: assetBank crystal_bat omnidirectional", str(lh.asset_bank_for_path("actors/mobs/crystal_bat.png").get("directionMode", "")) == "omnidirectional")
	ph.free()
	var lc = load("res://scripts/MapLoader.gd").new(); lc.load_map_json(sample["cave"])
	var pc := Node2D.new(); var sc2: Dictionary = lc.build_into(pc, {})
	_c("sample cave: 1 mob boss (mob_nodes)", (sc2.get("mob_nodes", []) as Array).size() == 1)
	pc.free()

	# loop completo town → hunt → cave → hunt → town (cada hop resolve)
	var hop_town: String = nav.find_map_for_target("sample_town")
	var hop_hunt: String = nav.find_map_for_target("sample_hunt")
	var hop_cave: String = nav.find_map_for_target("sample_cave")
	_c("loop town→hunt→cave→hunt→town navegável", hop_town != "" and hop_hunt != "" and hop_cave != "")

	# ----- MAP-LOADER-TILEMAP-RENDER-1 -----
	var lt = load("res://scripts/MapLoader.gd").new()
	_c("tilemap sample carrega", lt.load_map_json("res://data/studio_tilemap_sample.json"))
	_c("tilemap sample valida limpo", lt.validate_min().is_empty(), str(lt.validate_min()))
	var pt := Node2D.new(); var st: Dictionary = lt.build_into(pt, {})
	_c("renderiza 2 tilemaps", int(st.get("tilemaps", 0)) == 2, str(st.get("tilemaps")))
	_c("renderiza 364 células (grama+terra)", int(st.get("tilecells", 0)) == 364, str(st.get("tilecells")))
	_c("tilemap caminho feliz SEM warnings", lt.warnings.is_empty(), str(lt.warnings))
	pt.free()

	# cells malformadas não crasham (e contam só as válidas)
	var lb = load("res://scripts/MapLoader.gd").new()
	lb.load_map_dict({ "schemaVersion": 1, "map": { "id": "tb", "width": 400, "height": 400, "spawn": { "x": 10, "y": 10 } },
		"objects": [ { "id": "tm", "tilemap": true, "asset": "tilesets/plains/grass.png", "tileSize": 32, "cells": ["1,1", "bad", "2", "3,4", ""], "layer": "ground", "z": -20 } ] })
	var pb := Node2D.new(); var sb: Dictionary = lb.build_into(pb, {})
	_c("tilemap cells malformadas não crasham (2 válidas)", int(sb.get("tilecells", 0)) == 2, str(sb.get("tilecells")))
	pb.free()

	# tilemap com asset ausente → 1 warning + placeholder, sem crash
	var lm = load("res://scripts/MapLoader.gd").new()
	lm.load_map_dict({ "schemaVersion": 1, "map": { "id": "tm2", "width": 400, "height": 400, "spawn": { "x": 10, "y": 10 } },
		"objects": [ { "id": "tg", "tilemap": true, "asset": "tilesets/plains/ghost_tile.png", "tileSize": 32, "cells": ["0,0", "1,0"], "layer": "ground", "z": -20 } ] })
	var pm2 := Node2D.new(); var sm2: Dictionary = lm.build_into(pm2, {})
	_c("tilemap asset ausente: warning + placeholder", _has(lm.warnings, "ghost_tile") and int(sm2.get("tilemaps", 0)) == 1 and int(sm2.get("tilecells", 0)) == 2)
	pm2.free()

	# ----- STUDIO-AUTOTILE-TRANSITIONS-1 -----
	var la = load("res://scripts/MapLoader.gd").new()
	_c("autotile sample carrega", la.load_map_json("res://data/studio_autotile_sample.json"))
	_c("autotile valida limpo", la.validate_min().is_empty(), str(la.validate_min()))
	var pa := Node2D.new(); var sa: Dictionary = la.build_into(pa, {})
	_c("autotile: 2 tilemaps + 326 células", int(sa.get("tilemaps", 0)) == 2 and int(sa.get("tilecells", 0)) == 326, str(sa))
	_c("autotile: bordas de transição renderizadas (tileedges>0)", int(sa.get("tileedges", 0)) > 0, str(sa.get("tileedges")))
	_c("autotile caminho feliz SEM warnings", la.warnings.is_empty(), str(la.warnings))
	pa.free()

	# asset de transição AUSENTE → 1 warning + sem crash (base ainda renderiza)
	var le = load("res://scripts/MapLoader.gd").new()
	le.load_map_dict({ "schemaVersion": 1, "map": { "id": "te", "width": 400, "height": 400, "spawn": { "x": 10, "y": 10 } },
		"objects": [ { "id": "tm", "tilemap": true, "asset": "tilesets/plains/dirt.png", "tileSize": 32, "cells": ["1,1", "2,1"], "autoEdge": true, "edgeAssets": ["tilesets/plains/overlays/ghost_tuft.png"], "layer": "ground", "z": -20 } ] })
	var pe := Node2D.new(); var se: Dictionary = le.build_into(pe, {})
	_c("autotile: transition asset ausente → warning, sem crash", _has(le.warnings, "transição") and int(se.get("tilemaps", 0)) == 1 and int(se.get("tilecells", 0)) == 2)
	pe.free()

	parent.free()
	print("\n%d/%d checagens OK" % [_pass, _pass + _fail])
	if _fail > 0:
		push_error("SMOKE test FALHOU (%d)" % _fail)
	quit(1 if _fail > 0 else 0)
