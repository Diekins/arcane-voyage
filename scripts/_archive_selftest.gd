extends SceneTree
## Self-test THE_GREAT_ARCHIVE_BUILD_01 — a câmara "a Permanência". Verifica: (1) constrói (portal→Cidadela +
## paredes que encerram); (2) SEM combate (0 configs de mob = a hunt acabou); (3) EXATAMENTE 1 marcador legível
## (archive_name); (4) a marca mostra o nome legível + a conexão com a Pedra (repetir/carregar) SEM explicar; (5) a
## Cidadela tem a escada→Arquivo. Save-safe. Rodar:  godot --headless --path godot -s res://scripts/_archive_selftest.gd

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
	if gs != null: gs.call("set_story_flag", "archive_reached")
	main._build_great_archive(Vector2(1500, 950))

	# ── (1) construiu: portal de volta + paredes (blockers) que encerram a câmara ──
	var back_ok := false
	for p in (main.get("_portals") as Array):
		if str((p as Dictionary).get("target", "")) == "khet_citadel": back_ok = true
	var blk: Array = main.get("_blockers_by_level").get(0, [])
	var build_ok: bool = back_ok and blk.size() >= 5
	print("  (1) construiu: portal→Cidadela=%s paredes(blockers)=%d  %s" % [str(back_ok), blk.size(), ("OK" if build_ok else "✗")])
	if not build_ok: ok = false

	# ── (2) SEM combate: a câmara não tem configs de mob (a hunt acabou; a descoberta começa) ──
	var no_combat: bool = main._mob_configs("great_archive").size() == 0
	print("  (2) SEM combate (0 mob configs): %s  %s" % [str(no_combat), ("OK" if no_combat else "✗")])
	if not no_combat: ok = false

	# ── (3) EXATAMENTE 1 marcador legível (a tragédia depende do 99,999% inútil) ──
	var markers := []
	for s in (main.get("_services") as Array):
		if str((s as Dictionary).get("kind", "")) == "future_exit": markers.append(s)
	var one_marker: bool = markers.size() == 1 and str((markers[0] as Dictionary).get("id", "")) == "archive_name"
	print("  (3) exatamente 1 marcador legível (archive_name): n=%d  %s" % [markers.size(), ("OK" if one_marker else "✗")])
	if not one_marker: ok = false

	# ── (4) a marca MOSTRA o nome + a conexão com a Pedra (repetir/carregar) sem NPC/exposição ──
	var shows := false
	if not markers.is_empty():
		var txt := ""
		for line in (markers[0] as Dictionary).get("msg", []): txt += str(line) + " "
		shows = ("Imen" in txt) and ("repete" in txt or "carrega" in txt) and ("silêncio" in txt or "pedra" in txt)
	print("  (4) marca mostra nome legível + fio com a Pedra (repetir): %s  %s" % [str(shows), ("OK" if shows else "✗")])
	if not shows: ok = false

	# ── (5) a Cidadela tem a escada→Arquivo (a trilogia leva até aqui) ──
	host.free()
	var ch := Node2D.new(); root.add_child(ch); main.set("_region_node", ch)
	main.set("_services", []); main.set("_portals", []); main.set("_blockers", []); main.set("_blockers_by_level", {}); main.set("_npcs", []); main.set("_mobs", []); main.set("_chests", [])
	if gs != null: gs.call("set_story_flag", "citadel_reached")
	main._build_khet_citadel(Vector2(2400, 1500))
	var to_archive := false
	for p in (main.get("_portals") as Array):
		if str((p as Dictionary).get("target", "")) == "great_archive": to_archive = true
	print("  (5) Cidadela → escada para o Arquivo: %s  %s" % [str(to_archive), ("OK" if to_archive else "✗")])
	if not to_archive: ok = false

	ch.free()
	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snap); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
