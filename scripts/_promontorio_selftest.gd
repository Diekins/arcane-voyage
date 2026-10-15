extends SceneTree
## Self-test THE_OTHER_SHORE_BUILD_03 / R03 — O Promontório do Espelho (a revelação). Verifica: (1) constrói
## (descer→Cais + a Pedra da Travessia + a vista + a Guardadora + landmarks); (2) SEM combate (0 mob configs);
## (3) a Pedra da Travessia mostra POUCOS nomes + o eco de Maro; (4) a vista mostra "a outra praia / duas praias".
## Save-safe. Rodar:  godot --headless --path godot -s res://scripts/_promontorio_selftest.gd

func _initialize() -> void:
	var ok := true
	var save_path := "user://arcane_voyage_save.json"
	var snap := ""; var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snap = rf.get_as_text(); rf.close()

	var main = load("res://scripts/Main.gd").new()
	var host := Node2D.new(); root.add_child(host); main.set("_region_node", host)
	main.set("_services", []); main.set("_portals", []); main.set("_blockers", []); main.set("_blockers_by_level", {}); main.set("_npcs", []); main.set("_chests", []); main.set("_mobs", [])
	var gs = root.get_node_or_null("GameState")
	if gs != null: gs.call("set_story_flag", "other_shore_arc_complete")
	main._build_promontorio_do_espelho(Vector2(1600, 1000))

	# ── (1) constrói ──
	var back_ok := false
	for p in (main.get("_portals") as Array):
		if str((p as Dictionary).get("target", "")) == "cais_dos_ausentes": back_ok = true
	var svcs: Array = main.get("_services")
	var pedra := {}; var vista := {}
	for s in svcs:
		var id := str((s as Dictionary).get("id", ""))
		if id == "prom_pedra": pedra = s
		if id == "prom_vista": vista = s
	var guard := false
	for n in (main.get("_npcs") as Array):
		if str((n as Dictionary).get("name", "")) == "a Guardadora das Velas": guard = true
	var blk: Array = main.get("_blockers_by_level").get(0, [])
	var c1: bool = back_ok and not pedra.is_empty() and not vista.is_empty() and guard and blk.size() >= 4
	print("  (1) constrói: descer→Cais=%s Pedra=%s vista=%s Guardadora=%s blockers=%d  %s" % [str(back_ok), str(not pedra.is_empty()), str(not vista.is_empty()), str(guard), blk.size(), ("OK" if c1 else "✗")])
	if not c1: ok = false

	# ── (2) SEM combate ──
	var no_combat: bool = (main._mob_configs("promontorio_do_espelho") as Array).size() == 0
	print("  (2) SEM combate (é revelação, não desafio): %s  %s" % [str(no_combat), ("OK" if no_combat else "✗")])
	if not no_combat: ok = false

	# ── (3) a Pedra da Travessia: poucos nomes + o eco de Maro (atravessou e chegou; não está aqui) ──
	var pedra_ok := false
	if not pedra.is_empty():
		var txt := ""
		for line in (pedra as Dictionary).get("msg", []): txt += str(line) + " "
		pedra_ok = ("Maro" in txt) and ("poucos" in txt) and ("lid" in txt) and ("milhares" in txt)
	print("  (3) Pedra da Travessia (poucos nomes/todos lidos + eco de Maro): %s  %s" % [str(pedra_ok), ("OK" if pedra_ok else "✗")])
	if not pedra_ok: ok = false

	# ── (4) a vista: a outra praia olhando de volta / duas praias ──
	var vista_ok := false
	if not vista.is_empty():
		var txt2 := ""
		for line in (vista as Dictionary).get("msg", []): txt2 += str(line) + " "
		vista_ok = ("outra praia" in txt2) and ("duas praias" in txt2) and ("fim do mar" in txt2)
	print("  (4) a vista (não há fim do mar; a outra praia olha de volta): %s  %s" % [str(vista_ok), ("OK" if vista_ok else "✗")])
	if not vista_ok: ok = false

	host.free()
	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snap); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
