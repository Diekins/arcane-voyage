extends SceneTree
## Self-test KHETSAR_HUNT_REGION_02 — A Colunata Soterrada (irmã da Garganta, escola OPOSTA). Verifica: (1) constrói
## (portal-volta + descobertas + MUITOS blockers de pilares); (2) bestiário sweeper/zoner×2/line-raro/apex; (3) a
## LINGUAGEM (guardião=cone, olho=ranged, núcleo=circle, sopro=line, apex=cone→circle); (4) PREDOMÍNIO de
## sweepers+zoners com line RARÍSSIMO (inverso da Garganta). Save-safe. Rodar:
##   godot --headless --path godot -s res://scripts/_colonnade_selftest.gd

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
	main.set("_region_node", host)
	main.set("_services", []); main.set("_portals", []); main.set("_blockers", [])
	main.set("_blockers_by_level", {}); main.set("_npcs", []); main.set("_mobs", []); main.set("_chests", [])
	var gs = root.get_node_or_null("GameState")
	if gs != null: gs.call("set_story_flag", "colonnade_reached")   # pré-seta → sem popup

	main._build_khet_colonnade(Vector2(2100, 1400))

	# ── (1) construiu: portal de volta + descobertas + MUITOS pilares (cover) ──
	var back_ok := false
	for p in (main.get("_portals") as Array):
		if str((p as Dictionary).get("target", "")) == "khet_sar_sands": back_ok = true
	var marks := 0
	for s in (main.get("_services") as Array):
		if str((s as Dictionary).get("kind", "")) == "future_exit" and str((s as Dictionary).get("id", "")).begins_with("colon_"): marks += 1
	var blockers: Array = main.get("_blockers_by_level").get(0, [])
	var build_ok: bool = back_ok and marks >= 2 and blockers.size() >= 14   # pilares + tombadas + ídolo = muita cobertura
	print("  (1) construiu: portal-volta=%s descobertas=%d cover(blockers)=%d  %s" % [str(back_ok), marks, blockers.size(), ("OK" if build_ok else "✗")])
	if not build_ok: ok = false

	# ── (2) bestiário ──
	var by_id := {}
	for c in main._mob_configs("khet_colonnade"): by_id[str(c.get("id", ""))] = c
	var want := ["guardiao_coluna", "olho_de_po", "nucleo_de_sal", "sopro_areia", "colonnade_apex"]
	var missing := []
	for id in want:
		if not by_id.has(id): missing.append(id)
	print("  (2) bestiário (sweeper/zoner×2/line-raro/apex): %s  %s" % [("todos" if missing.is_empty() else str(missing)), ("OK" if missing.is_empty() else "✗")])
	if not missing.is_empty(): ok = false

	# ── (3) LINGUAGEM ──
	var shapes := {}; var cycles := {}
	for id in want:
		if not by_id.has(id): continue
		var m := Node2D.new(); m.set_script(load("res://scripts/Mob.gd"))
		main._apply_combat_language(m, by_id[id])
		shapes[id] = str(m.get("telegraph_shape")); cycles[id] = _shapes_of(m.get("telegraph_cycle"))
		m.free()
	var lang_ok: bool = shapes.get("guardiao_coluna") == "cone" and shapes.get("nucleo_de_sal") == "circle" \
		and shapes.get("sopro_areia") == "line" and cycles.get("colonnade_apex") == ["cone", "circle"] \
		and bool(by_id["olho_de_po"].get("ranged", false))
	print("  (3) linguagem: guardião=%s núcleo=%s sopro=%s apex=%s olho.ranged=%s  %s" % [
		shapes.get("guardiao_coluna"), shapes.get("nucleo_de_sal"), shapes.get("sopro_areia"),
		str(cycles.get("colonnade_apex")), str(by_id["olho_de_po"].get("ranged", false)), ("OK" if lang_ok else "✗")])
	if not lang_ok: ok = false

	# ── (4) PREDOMÍNIO de sweepers+zoners; line RARÍSSIMO (inverso da Garganta) ──
	var sweeper_zoner := int((by_id["guardiao_coluna"]["spawns"] as Array).size()) + int((by_id["olho_de_po"]["spawns"] as Array).size()) + int((by_id["nucleo_de_sal"]["spawns"] as Array).size())
	var line_spawns := int((by_id["sopro_areia"]["spawns"] as Array).size())
	var dom_ok: bool = sweeper_zoner >= 8 and line_spawns <= 2 and sweeper_zoner >= 4 * line_spawns
	print("  (4) predomínio sweeper+zoner=%d vs line(raro)=%d  %s" % [sweeper_zoner, line_spawns, ("OK" if dom_ok else "✗")])
	if not dom_ok: ok = false

	host.free()
	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snap); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
