extends SceneTree
## Self-test KHETSAR_HUNT_REGION_03 — A Cidadela Partida (capstone). Verifica: (1) constrói (portal→Colunata +
## descobertas + muralhas); (2) bestiário das DUAS escolas + apex; (3) MIX deliberado (line+cone+circle/ranged
## todos presentes); (4) apex = frase COMPLETA line→cone→circle (mais completo) + mais HP que os 2 apexes; (5)
## ANTI-CLIP (nenhum spawn dentro de muralha); (6) folga de leitura na entrada. Save-safe. Rodar:
##   godot --headless --path godot -s res://scripts/_citadel_selftest.gd

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
	var host := Node2D.new(); root.add_child(host)
	main.set("_region_node", host); main.set("_services", []); main.set("_portals", []); main.set("_blockers", [])
	main.set("_blockers_by_level", {}); main.set("_npcs", []); main.set("_mobs", []); main.set("_chests", [])
	var gs = root.get_node_or_null("GameState")
	if gs != null: gs.call("set_story_flag", "citadel_reached")
	main._build_khet_citadel(Vector2(2400, 1500))

	# ── (1) construiu ──
	var back_ok := false
	for p in (main.get("_portals") as Array):
		if str((p as Dictionary).get("target", "")) == "khet_colonnade": back_ok = true
	var marks := 0
	for s in (main.get("_services") as Array):
		if str((s as Dictionary).get("kind", "")) == "future_exit" and str((s as Dictionary).get("id", "")).begins_with("cit_"): marks += 1
	var blk: Array = main.get("_blockers_by_level").get(0, [])
	var build_ok: bool = back_ok and marks >= 2 and blk.size() >= 10
	print("  (1) construiu: portal→Colunata=%s descobertas=%d muralhas(blockers)=%d  %s" % [str(back_ok), marks, blk.size(), ("OK" if build_ok else "✗")])
	if not build_ok: ok = false

	# ── (2) bestiário das duas escolas + apex ──
	var by_id := {}
	for c in main._mob_configs("khet_citadel"): by_id[str(c.get("id", ""))] = c
	var want := ["citadel_raider", "necrofago_skitter", "citadel_warden", "citadel_eye", "nucleo_de_sal", "citadel_apex"]
	var missing := []
	for id in want:
		if not by_id.has(id): missing.append(id)
	print("  (2) bestiário completo (rusher/swarm/sweeper/ranged/circle/apex): %s  %s" % [("todos" if missing.is_empty() else str(missing)), ("OK" if missing.is_empty() else "✗")])
	if not missing.is_empty(): ok = false

	# ── (3) MIX deliberado: line + cone + circle/ranged TODOS presentes ──
	var shapes := {}; var cyc := {}
	for id in want:
		if not by_id.has(id): continue
		var mm := Node2D.new(); mm.set_script(load("res://scripts/Mob.gd"))
		main._apply_combat_language(mm, by_id[id])
		shapes[id] = str(mm.get("telegraph_shape")); cyc[id] = _shapes_of(mm.get("telegraph_cycle"))
		mm.free()
	var has_line: bool = shapes.get("citadel_raider") == "line" or shapes.get("necrofago_skitter") == "line"
	var has_cone: bool = shapes.get("citadel_warden") == "cone"
	var has_circle: bool = shapes.get("nucleo_de_sal") == "circle"
	var has_ranged: bool = bool(by_id["citadel_eye"].get("ranged", false))
	var mix_ok: bool = has_line and has_cone and has_circle and has_ranged
	print("  (3) MIX das 2 escolas: line=%s cone=%s circle=%s ranged=%s  %s" % [str(has_line), str(has_cone), str(has_circle), str(has_ranged), ("OK" if mix_ok else "✗")])
	if not mix_ok: ok = false

	# ── (4) apex = frase COMPLETA (3 palavras) + mais avançado que os outros apexes ──
	var apex_phrase: bool = cyc.get("citadel_apex") == ["line", "cone", "circle"]
	var apex_hp := int(by_id["citadel_apex"]["hp"])
	# hp dos apexes anteriores (maw=560, colonnade=640)
	var maw_hp := 0; var col_hp := 0
	for c in main._mob_configs("khet_sand_maw"):
		if str(c.get("id", "")) == "maw_apex_jackal": maw_hp = int(c["hp"])
	for c in main._mob_configs("khet_colonnade"):
		if str(c.get("id", "")) == "colonnade_apex": col_hp = int(c["hp"])
	var apex_ok: bool = apex_phrase and apex_hp > maw_hp and apex_hp > col_hp
	print("  (4) apex frase=%s (line→cone→circle) + mais avançado (hp %d > %d, %d)  %s" % [str(apex_phrase), apex_hp, maw_hp, col_hp, ("OK" if apex_ok else "✗")])
	if not apex_ok: ok = false

	# ── (5) ANTI-CLIP: nenhum spawn dentro de muralha (a disciplina do bug do apex da R02) ──
	var clip := 0
	for c in main._mob_configs("khet_citadel"):
		for sp in (c["spawns"] as Array):
			for r in blk:
				if (r as Rect2).has_point(sp) or (r as Rect2).has_point(sp + Vector2(0, 16)): clip += 1
	print("  (5) ANTI-CLIP: spawns dentro de muralha=%d  %s" % [clip, ("OK" if clip == 0 else "✗")])
	if clip != 0: ok = false

	# ── (6) folga de leitura na entrada (≥60px; melee ≥80) ──
	var spawn: Vector2 = main._region_spawn("khet_citadel")
	var nf := 999999.0
	for c in main._mob_configs("khet_citadel"):
		for sp in (c["spawns"] as Array):
			var d := spawn.distance_to(sp) - float(c["aggro"])
			if d < nf: nf = d
	print("  (6) folga de leitura na entrada: %.0fpx  %s" % [nf, ("OK" if nf >= 60.0 else "✗")])
	if nf < 60.0: ok = false

	host.free()
	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snap); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
