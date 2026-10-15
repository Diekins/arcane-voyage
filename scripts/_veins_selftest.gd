extends SceneTree
## Self-test BUILD_VEIOS_F5 — Os Veios (L1 da masmorra vertical). Verifica: (1) constrói (portais ↑Caverna / ↡Catedral
## + 2 marcas de profundidade + o Lago placeholder + cobertura de mina via blockers); (2) farm reusa a ecologia da
## Caverna (bat/spider/slime/shard/shade) + 3 formas (line/circle); (3) elite-GATE Sentinela do Veio presente (1 de 2
## pontos, sempre) com frase cone→circle; (4) ANTI-CLIP (nenhum spawn dentro de escora/carrinho); (5) Entrada segura
## (folga ≥60 no spawn); (6) a CADEIA re-roteada: Caverna→Veios (boca repontada) + Veios→Catedral + Catedral→Veios; (7)
## fiação (size/spawn/biome). Save-safe (snapshot/restore). Rodar:
##   godot --headless --path godot -s res://scripts/_veins_selftest.gd

func _shapes_of(cycle: Array) -> Array:
	var out := []
	for b in cycle: out.append(str((b as Dictionary).get("shape", "?")))
	return out

func _initialize() -> void:
	seed(20260609)
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
	main._build_veins(Vector2(1900, 1300))

	# ── (1) construiu: portais + marcas + Lago placeholder + cobertura ──
	var up_ok := false; var down_ok := false
	for p in (main.get("_portals") as Array):
		var t := str((p as Dictionary).get("target", ""))
		if t == "cave": up_ok = true
		if t == "cathedral_of_crystal": down_ok = true
	var marks := 0; var lago := false
	for s in (main.get("_services") as Array):
		if str((s as Dictionary).get("kind", "")) == "future_exit" and str((s as Dictionary).get("id", "")).begins_with("veins_"): marks += 1
		if str((s as Dictionary).get("id", "")) == "veins_lago": lago = true
	var blk: Array = main.get("_blockers_by_level").get(0, [])
	var build_ok: bool = up_ok and down_ok and marks >= 3 and lago and blk.size() >= 8
	print("  (1) construiu: ↑Caverna=%s ↡Catedral=%s marcas=%d Lago=%s cobertura=%d  %s" % [str(up_ok), str(down_ok), marks, str(lago), blk.size(), ("OK" if build_ok else "✗")])
	if not build_ok: ok = false

	# ── (2) farm reusa a ecologia da Caverna + 3 formas ──
	var by_id := {}
	for c in main._mob_configs("veins"): by_id[str(c.get("id", ""))] = c
	var want := ["crystal_bat", "grove_spider", "green_slime", "living_shard", "crawling_shade"]
	var missing := []
	for id in want:
		if not by_id.has(id): missing.append(id)
	var shapes := {}
	for id in want:
		if not by_id.has(id): continue
		var mm := Node2D.new(); mm.set_script(load("res://scripts/Mob.gd"))
		main._apply_combat_language(mm, by_id[id]); shapes[id] = str(mm.get("telegraph_shape")); mm.free()
	var forms_ok: bool = shapes.get("crystal_bat") == "line" and shapes.get("living_shard") == "circle"
	var farm_ok: bool = missing.is_empty() and forms_ok
	print("  (2) farm reusa Caverna: %s + formas line(bat)=%s circle(shard)=%s  %s" % [("todos" if missing.is_empty() else str(missing)), str(shapes.get("crystal_bat") == "line"), str(shapes.get("living_shard") == "circle"), ("OK" if farm_ok else "✗")])
	if not farm_ok: ok = false

	# ── (3) elite-GATE: Sentinela do Veio SEMPRE presente (1 de 2 pontos) + frase cone→circle ──
	var elite_runs := 0; var pts := {}; var elite_cfg := {}
	for i in range(60):
		for c in main._mob_configs("veins"):
			if str(c.get("id", "")) == "veio_sentinel":
				elite_runs += 1; elite_cfg = c; pts[str((c["spawns"] as Array)[0])] = true
	var em := Node2D.new(); em.set_script(load("res://scripts/Mob.gd"))
	main._apply_combat_language(em, elite_cfg); var phrase := _shapes_of(em.get("telegraph_cycle")); em.free()
	var gate_ok: bool = elite_runs == 60 and pts.size() >= 1 and str(elite_cfg.get("visual", "")) == "stone_sentinel" and phrase == ["cone", "circle"]
	print("  (3) elite-GATE Sentinela do Veio: presença %d/60, pontos=%d, frase=%s  %s" % [elite_runs, pts.size(), str(phrase), ("OK" if gate_ok else "✗")])
	if not gate_ok: ok = false

	# ── (4) ANTI-CLIP: nenhum spawn (incl. os 2 pontos do elite) dentro de cobertura ──
	var clip := 0
	var allsp: Array = []
	for c in main._mob_configs("veins"):
		for sp in (c["spawns"] as Array): allsp.append(sp)
	for p in main.VEINS_SENTINEL_POINTS: allsp.append(p)
	for sp in allsp:
		for r in blk:
			if (r as Rect2).has_point(sp) or (r as Rect2).has_point(sp + Vector2(0, 16)): clip += 1
	print("  (4) ANTI-CLIP: spawns dentro de cobertura=%d  %s" % [clip, ("OK" if clip == 0 else "✗")])
	if clip != 0: ok = false

	# ── (5) Entrada segura (folga ≥60 no spawn) ──
	var spawn: Vector2 = main._region_spawn("veins")
	var nf := 999999.0
	for c in main._mob_configs("veins"):
		for sp in (c["spawns"] as Array):
			var d := spawn.distance_to(sp) - float(c["aggro"])
			if d < nf: nf = d
	print("  (5) Entrada folga=%.0fpx  %s" % [nf, ("OK" if nf >= 60.0 else "✗")])
	if nf < 60.0: ok = false

	# ── (6) a CADEIA re-roteada: a Caverna desce aos Veios (não direto à Catedral) + a Catedral volta aos Veios ──
	main.set("_region_node", Node2D.new()); root.add_child(main.get("_region_node"))
	main.set("_services", []); main.set("_portals", []); main.set("_blockers", []); main.set("_blockers_by_level", {})
	main.set("_macro_sandbox", true)   # pula o Golem no build da Caverna (harness sem cena completa) — só queremos os PORTAIS
	main._build_cave(Vector2(1800, 1200))
	var cave_to_veins := false
	for p in (main.get("_portals") as Array):
		if str((p as Dictionary).get("target", "")) == "veins": cave_to_veins = true
	main.set("_region_node", Node2D.new()); root.add_child(main.get("_region_node"))
	main.set("_services", []); main.set("_portals", []); main.set("_blockers", []); main.set("_blockers_by_level", {})
	main._build_cathedral_of_crystal(Vector2(2200, 1500))
	var cath_to_veins := false
	for p in (main.get("_portals") as Array):
		if str((p as Dictionary).get("target", "")) == "veins": cath_to_veins = true
	var chain_ok: bool = cave_to_veins and cath_to_veins
	print("  (6) cadeia re-roteada: Caverna→Veios=%s · Catedral→Veios=%s  %s" % [str(cave_to_veins), str(cath_to_veins), ("OK" if chain_ok else "✗")])
	if not chain_ok: ok = false

	# ── (7) fiação ──
	var sz: Vector2 = main._region_world_size("veins")
	var biome: String = main._region_biome("veins")
	var wire_ok: bool = sz == Vector2(1900, 1300) and spawn == Vector2(950, 250) and biome == "caverna"
	print("  (7) fiação: size=%s spawn=%s biome=%s  %s" % [str(sz), str(spawn), biome, ("OK" if wire_ok else "✗")])
	if not wire_ok: ok = false

	host.free()
	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snap); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
