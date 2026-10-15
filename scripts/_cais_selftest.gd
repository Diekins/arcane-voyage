extends SceneTree
## Self-test THE_OTHER_SHORE_BUILD_02 / R02 — O Cais dos Ausentes. Verifica: (1) constrói (volta→Praia + saída
## future_exit ao Promontório + o Reparador + landmarks); (2) bestiário (caçador/marujo/caranguejo/Vigia); (3) a
## LINGUAGEM (caçador=line, marujo=cone, caranguejo=circle, Vigia=line→circle); (4) ANTI-CLIP (nenhum spawn em
## blocker); (5) hunt LEVE (apex < citadel); (6) a Praia leva ao Cais. Save-safe. Rodar:
##   godot --headless --path godot -s res://scripts/_cais_selftest.gd

func _shapes_of(cycle: Array) -> Array:
	var out := []
	for b in cycle: out.append(str((b as Dictionary).get("shape", "?")))
	return out

func _initialize() -> void:
	var ok := true
	var save_path := "user://arcane_voyage_save.json"
	var snap := ""; var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snap = rf.get_as_text(); rf.close()

	var main = load("res://scripts/Main.gd").new()
	var gs = root.get_node_or_null("GameState")
	if gs != null: gs.call("set_story_flag", "cais_ausentes_reached")

	# ── (1) constrói ──
	var h1 := Node2D.new(); root.add_child(h1); main.set("_region_node", h1)
	main.set("_services", []); main.set("_portals", []); main.set("_blockers", []); main.set("_blockers_by_level", {}); main.set("_npcs", []); main.set("_chests", []); main.set("_mobs", [])
	main._build_cais_dos_ausentes(Vector2(2200, 1300))
	var back_ok := false
	for p in (main.get("_portals") as Array):
		if str((p as Dictionary).get("target", "")) == "praia_das_velas": back_ok = true
	var prom := false
	for s in (main.get("_services") as Array):
		if str((s as Dictionary).get("id", "")) == "cais_promontorio": prom = true
	var rep := false
	for n in (main.get("_npcs") as Array):
		if str((n as Dictionary).get("name", "")) == "o Reparador": rep = true
	var blk: Array = main.get("_blockers_by_level").get(0, [])
	var c1: bool = back_ok and prom and rep and blk.size() >= 8
	print("  (1) constrói: volta→Praia=%s saída→Promontório=%s Reparador=%s landmarks(blk)=%d  %s" % [str(back_ok), str(prom), str(rep), blk.size(), ("OK" if c1 else "✗")])
	if not c1: ok = false

	# ── (2) bestiário + (3) linguagem ──
	var by_id := {}
	for c in main._mob_configs("cais_dos_ausentes"): by_id[str(c.get("id", ""))] = c
	var want := ["cacador_da_mare", "marujo_afogado", "caranguejo_ferrugem", "vigia_da_mare"]
	var missing := []
	for id in want:
		if not by_id.has(id): missing.append(id)
	print("  (2) bestiário (rusher/sweeper/zoner/apex): %s  %s" % [("todos" if missing.is_empty() else str(missing)), ("OK" if missing.is_empty() else "✗")])
	if not missing.is_empty(): ok = false
	var shapes := {}; var cyc := {}
	for id in want:
		if not by_id.has(id): continue
		var m := Node2D.new(); m.set_script(load("res://scripts/Mob.gd"))
		main._apply_combat_language(m, by_id[id])
		shapes[id] = str(m.get("telegraph_shape")); cyc[id] = _shapes_of(m.get("telegraph_cycle"))
		m.free()
	var lang_ok: bool = shapes.get("cacador_da_mare") == "line" and shapes.get("marujo_afogado") == "cone" \
		and shapes.get("caranguejo_ferrugem") == "circle" and cyc.get("vigia_da_mare") == ["line", "circle"]
	print("  (3) linguagem: caçador=%s marujo=%s caranguejo=%s Vigia=%s  %s" % [shapes.get("cacador_da_mare"), shapes.get("marujo_afogado"), shapes.get("caranguejo_ferrugem"), str(cyc.get("vigia_da_mare")), ("OK" if lang_ok else "✗")])
	if not lang_ok: ok = false

	# ── (4) ANTI-CLIP ──
	var clip := 0
	for c in main._mob_configs("cais_dos_ausentes"):
		for sp in (c["spawns"] as Array):
			for r in blk:
				if (r as Rect2).has_point(sp) or (r as Rect2).has_point(sp + Vector2(0, 16)): clip += 1
	print("  (4) ANTI-CLIP: spawns dentro de blocker=%d  %s" % [clip, ("OK" if clip == 0 else "✗")])
	if clip != 0: ok = false

	# ── (5) hunt LEVE (apex Vigia < citadel apex 760; mobs comuns < 205) ──
	var apex_hp := int(by_id["vigia_da_mare"]["hp"])
	var heavy := 0
	for c in main._mob_configs("cais_dos_ausentes"):
		if str(c["id"]) != "vigia_da_mare" and int(c["hp"]) >= 205: heavy += 1
	var light_ok: bool = apex_hp < 760 and heavy == 0
	print("  (5) hunt LEVE: apex hp=%d (<760) mobs-pesados=%d  %s" % [apex_hp, heavy, ("OK" if light_ok else "✗")])
	if not light_ok: ok = false
	h1.free()

	# ── (6) a Praia leva ao Cais ──
	var h2 := Node2D.new(); root.add_child(h2); main.set("_region_node", h2)
	main.set("_services", []); main.set("_portals", []); main.set("_blockers", []); main.set("_blockers_by_level", {}); main.set("_npcs", []); main.set("_chests", []); main.set("_mobs", [])
	if gs != null: gs.call("set_story_flag", "other_shore_reached")
	main._build_praia_das_velas(Vector2(2000, 1100))
	var to_cais := false
	for p in (main.get("_portals") as Array):
		if str((p as Dictionary).get("target", "")) == "cais_dos_ausentes": to_cais = true
	print("  (6) a Praia → o Cais dos Ausentes: %s  %s" % [str(to_cais), ("OK" if to_cais else "✗")])
	if not to_cais: ok = false
	h2.free()

	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snap); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
