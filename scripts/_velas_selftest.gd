extends SceneTree
## Self-test THE_OTHER_SHORE_BUILD_01 / R01 — A Praia das Velas ("o Espelho", reconhecimento). Verifica: (1) constrói
## (barca de volta → Costa + a Observadora + o Farol); (2) SEM combate (0 mob configs = é chegada, não hunt); (3) o
## gesto do espelho [E] (velas_lookback) mostra "você virou a vela"; (4) a Costa tem a travessia → a Praia. Save-safe.
## Rodar:  godot --headless --path godot -s res://scripts/_velas_selftest.gd

func _initialize() -> void:
	var ok := true
	var save_path := "user://arcane_voyage_save.json"
	var snap := ""; var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snap = rf.get_as_text(); rf.close()

	var main = load("res://scripts/Main.gd").new()
	var gs = root.get_node_or_null("GameState")
	if gs != null:
		gs.call("set_story_flag", "other_shore_reached"); gs.call("set_story_flag", "coast_route_found")

	# ── A PRAIA: constrói + Observadora + gesto do espelho ──
	var h1 := Node2D.new(); root.add_child(h1); main.set("_region_node", h1)
	main.set("_services", []); main.set("_portals", []); main.set("_blockers", []); main.set("_blockers_by_level", {}); main.set("_npcs", []); main.set("_chests", []); main.set("_mobs", [])
	main._build_praia_das_velas(Vector2(2000, 1100))
	var back_ok := false
	for p in (main.get("_portals") as Array):
		if str((p as Dictionary).get("target", "")) == "saltwind_shore": back_ok = true
	var obs := false
	for n in (main.get("_npcs") as Array):
		if str((n as Dictionary).get("name", "")) == "a Observadora": obs = true
	var blk: Array = main.get("_blockers_by_level").get(0, [])
	var c1 := back_ok and obs and blk.size() >= 4
	print("  (1) Praia constrói: barca→Costa=%s Observadora=%s props(blockers)=%d  %s" % [str(back_ok), str(obs), blk.size(), ("OK" if c1 else "✗")])
	if not c1: ok = false

	# ── (2) SEM combate ──
	var no_combat: bool = (main._mob_configs("praia_das_velas") as Array).size() == 0
	print("  (2) SEM combate (é chegada, não hunt): %s  %s" % [str(no_combat), ("OK" if no_combat else "✗")])
	if not no_combat: ok = false

	# ── (3) o gesto do espelho mostra "você virou a vela" ──
	var look := {}
	for s in (main.get("_services") as Array):
		if str((s as Dictionary).get("id", "")) == "velas_lookback": look = s
	var shows := false
	if not look.is_empty():
		var txt := ""
		for line in (look as Dictionary).get("msg", []): txt += str(line) + " "
		shows = ("vela" in txt) and ("espera" in txt or "espera" in txt) and ("atravessou" in txt or "virou" in txt)
	print("  (3) gesto do espelho [E] (você virou a vela): %s  %s" % [str(shows), ("OK" if shows else "✗")])
	if not shows: ok = false

	# ── (4) a Costa tem a travessia → a Praia ──
	h1.free()
	var h2 := Node2D.new(); root.add_child(h2); main.set("_region_node", h2)
	main.set("_services", []); main.set("_portals", []); main.set("_blockers", []); main.set("_blockers_by_level", {}); main.set("_npcs", []); main.set("_chests", []); main.set("_mobs", [])
	main._build_saltwind_shore(Vector2(2200, 1300))
	var to_velas := false
	for p in (main.get("_portals") as Array):
		if str((p as Dictionary).get("target", "")) == "praia_das_velas": to_velas = true
	print("  (4) Costa → travessia para a Praia das Velas: %s  %s" % [str(to_velas), ("OK" if to_velas else "✗")])
	if not to_velas: ok = false
	h2.free()

	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snap); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
