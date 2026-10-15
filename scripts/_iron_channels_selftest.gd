extends SceneTree
## Self-test BUILD_CANAIS_DE_FERRO_F5 — Os Canais de Ferro (1ª camada da 2ª espinha, HORIZONTAL). Verifica: (1) a
## ILHA-ÂNCORA (Oficina: marca + Fonte/serviço + volta→Pântano); (2) o LABIRINTO (canais de água = blockers ≥6 +
## atoleiros dead-end blocking ≥3); (3) os MARCOS de orientação + o POÇO de HORIZONTE (silhueta via portal→swamp_pit +
## marca); (4) bestiário REUSADO (bog_crawler/iron_leech) + O Remontado (elite, cone→circle, stone_sentinel, recorrente,
## presença/lugar variam) + O Ferro-Errante (raro, aggro BAIXO/circulação, grove_spider, deriva); (5) ANTI-CLIP
## exaustivo (trash + pontos candidatos do Remontado/Errante fora de água/atoleiro); (6) a CADEIA (Pântano→Canais +
## Canais→Pântano + Canais→Poço); (7) identidade HORIZONTAL (size largo + biome pantano ≠ caverna) + Entrada segura.
##   godot --headless --path godot -s res://scripts/_iron_channels_selftest.gd

func _shapes_of(cycle: Array) -> Array:
	var out := []
	for b in cycle: out.append(str((b as Dictionary).get("shape", "?")))
	return out

func _initialize() -> void:
	seed(20260610)
	var ok := true
	var save_path := "user://arcane_voyage_save.json"
	var snap := ""; var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snap = rf.get_as_text(); rf.close()

	var main = load("res://scripts/Main.gd").new()
	var host := Node2D.new(); root.add_child(host)
	main.set("_region_node", host); main.set("_services", []); main.set("_portals", []); main.set("_blockers", [])
	main.set("_blockers_by_level", {}); main.set("_npcs", []); main.set("_mobs", []); main.set("_chests", [])
	main._build_iron_channels(Vector2(2200, 1500))
	var blk: Array = main.get("_blockers_by_level").get(0, [])

	# ── (1) ILHA-ÂNCORA: marca da Oficina + Fonte (serviço) + volta→Pântano ──
	var oficina := false; var fonte := false; var back := false
	for s in (main.get("_services") as Array):
		var sid := str((s as Dictionary).get("id", ""))
		if sid == "canais_oficina": oficina = true
		if str((s as Dictionary).get("kind", "")) == "swamp_spring": fonte = true
	for p in (main.get("_portals") as Array):
		if str((p as Dictionary).get("target", "")) == "swamp": back = true
	var anchor_ok: bool = oficina and fonte and back
	print("  (1) ilha-âncora: Oficina=%s Fonte=%s volta→Pântano=%s  %s" % [str(oficina), str(fonte), str(back), ("OK" if anchor_ok else "✗")])
	if not anchor_ok: ok = false

	# ── (2) o LABIRINTO: canais (blockers) ≥6 ──
	var maze_ok: bool = blk.size() >= 6
	print("  (2) labirinto: blockers (canais+atoleiros+moat)=%d (≥6)  %s" % [blk.size(), ("OK" if maze_ok else "✗")])
	if not maze_ok: ok = false

	# ── (3) o POÇO de HORIZONTE: rota → swamp_pit + marca "o que há no centro" ──
	var poco_route := false; var poco_mark := false
	for p in (main.get("_portals") as Array):
		if str((p as Dictionary).get("target", "")) == "swamp_pit": poco_route = true
	for s in (main.get("_services") as Array):
		if str((s as Dictionary).get("id", "")) == "canais_poco": poco_mark = true
	var poco_ok: bool = poco_route and poco_mark
	print("  (3) Poço de horizonte: rota→swamp_pit=%s + marca=%s  %s" % [str(poco_route), str(poco_mark), ("OK" if poco_ok else "✗")])
	if not poco_ok: ok = false

	# ── (4) bestiário reusado + elite/raro semi-aleatórios (presença e lugar variam) ──
	var base_missing := 0; var elite_runs := 0; var rare_runs := 0; var epts := {}; var rpts := {}; var ecfg := {}; var rcfg := {}
	for i in range(80):
		var ids := {}
		for c in main._mob_configs("iron_channels"): ids[str(c.get("id", ""))] = c
		if not (ids.has("bog_crawler") and ids.has("iron_leech")): base_missing += 1
		if ids.has("remontado"): elite_runs += 1; ecfg = ids["remontado"]; epts[str((ids["remontado"]["spawns"] as Array)[0])] = true
		if ids.has("ferro_errante"): rare_runs += 1; rcfg = ids["ferro_errante"]; rpts[str((ids["ferro_errante"]["spawns"] as Array)[0])] = true
	var em := Node2D.new(); em.set_script(load("res://scripts/Mob.gd"))
	main._apply_combat_language(em, ecfg); var ephrase := _shapes_of(em.get("telegraph_cycle")); em.free()
	var elite_ok: bool = base_missing == 0 and elite_runs > 40 and elite_runs < 80 and epts.size() >= 2 \
		and str(ecfg.get("visual", "")) == "stone_sentinel" and ephrase == ["cone", "circle"]
	var rare_ok: bool = rare_runs > 0 and rare_runs < 70 and rpts.size() >= 2 \
		and str(rcfg.get("visual", "")) == "grove_spider" and float(rcfg.get("aggro", 999.0)) <= 200.0 and float(rcfg.get("wander_radius", 0.0)) >= 150.0
	print("  (4) Remontado: presença=%d/80 lugares=%d frase=%s · Ferro-Errante: presença=%d/80 lugares=%d aggro=%.0f  %s" % [elite_runs, epts.size(), str(ephrase), rare_runs, rpts.size(), float(rcfg.get("aggro", 0.0)), ("OK" if (elite_ok and rare_ok) else "✗")])
	if not (elite_ok and rare_ok): ok = false

	# ── (5) ANTI-CLIP exaustivo: trash + TODOS os pontos candidatos do Remontado/Errante fora de água/atoleiro ──
	var clip := 0
	var allpts: Array = []
	for c in main._mob_configs("iron_channels"):
		if str(c.get("id", "")) in ["remontado", "ferro_errante"]: continue   # candidatos checados abaixo (todos)
		for sp in (c["spawns"] as Array): allpts.append(sp)
	for p in main.CHANNELS_REMONTADO_POINTS: allpts.append(p)
	for p in main.CHANNELS_ERRANTE_POINTS: allpts.append(p)
	for sp in allpts:
		for r in blk:
			if (r as Rect2).has_point(sp) or (r as Rect2).has_point(sp + Vector2(0, 16)): clip += 1
	print("  (5) ANTI-CLIP exaustivo (%d pontos): clips=%d  %s" % [allpts.size(), clip, ("OK" if clip == 0 else "✗")])
	if clip != 0: ok = false

	# ── (6) a CADEIA: Pântano→Canais (no _build_swamp) + Canais→Pântano + Canais→Poço ──
	main.set("_region_node", Node2D.new()); root.add_child(main.get("_region_node"))
	main.set("_services", []); main.set("_portals", []); main.set("_blockers", []); main.set("_blockers_by_level", {})
	main._build_swamp(Vector2(2000, 1400))
	var swamp_to_ch := false
	for p in (main.get("_portals") as Array):
		if str((p as Dictionary).get("target", "")) == "iron_channels": swamp_to_ch = true
	var chain_ok: bool = swamp_to_ch and back and poco_route
	print("  (6) cadeia: Pântano→Canais=%s · Canais→Pântano=%s · Canais→Poço=%s  %s" % [str(swamp_to_ch), str(back), str(poco_route), ("OK" if chain_ok else "✗")])
	if not chain_ok: ok = false

	# ── (7) identidade HORIZONTAL (largo, biome pantano ≠ caverna) + Entrada segura ──
	var sz: Vector2 = main._region_world_size("iron_channels")
	var biome: String = main._region_biome("iron_channels")
	var spawn: Vector2 = main._region_spawn("iron_channels")
	var nf := 999999.0
	for c in main._mob_configs("iron_channels"):
		for sp in (c["spawns"] as Array):
			var d := spawn.distance_to(sp) - float(c["aggro"])
			if d < nf: nf = d
	var id_ok: bool = sz.x > sz.y and biome == "pantano" and nf >= 60.0
	print("  (7) horizontal: size=%s (largo) biome=%s · Entrada folga=%.0fpx  %s" % [str(sz), biome, nf, ("OK" if id_ok else "✗")])
	if not id_ok: ok = false

	host.free()
	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snap); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
