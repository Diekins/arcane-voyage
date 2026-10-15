extends SceneTree
## Self-test THE_STONE_BUILD_06 — a CISTERNA e o ARQUIVO DOS NOMES (o FUNDO da Pedra). Constrói a chegada REAL da
## Pedra (_build_stone_arrival, dentro de deep_dunes) e prova: a Guardiã dos Nomes existe no FUNDO (nv0, na câmara);
## o marcador do Arquivo existe (nv0, com texto); a câmara é ENCERRADA (paredes blocker) com UMA fenda de entrada;
## a interação same-level com a Guardiã; e a comunidade do TERRAÇO segue intacta (4 Testemunhas + Vigia). Main
## DESTACADO + snapshot/restore do save. Rodar:
##   godot --headless --path godot -s res://scripts/_stone_cistern_selftest.gd

func _initialize() -> void:
	var ok := true
	var save_path := "user://arcane_voyage_save.json"
	var snapshot := ""
	var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snapshot = rf.get_as_text(); rf.close()

	var main = load("res://scripts/Main.gd").new()
	main.set("_macro_sandbox", true)
	var host := Node2D.new(); root.add_child(host)
	main.set("_region_node", host)
	main.set("_services", []); main.set("_npcs", []); main.set("_portals", [])
	main.set("_chests", []); main.set("_blockers", [])
	main.set("_blockers_by_level", {}); main.set("_stair_zones", []); main.set("_floor_containers", {}); main.set("_routine_npcs", [])
	var player := Node2D.new()
	player.set_script(load("res://scripts/PlayerController.gd"))
	player.position = Vector2(1730, 614)
	root.add_child(player)
	main.set("_player", player)

	main._build_stone_arrival(main._region_world_size("deep_dunes"))

	var svcs: Array = main.get("_services")
	var guard: Dictionary = {}
	var archive: Dictionary = {}
	for s in svcs:
		var sid := str((s as Dictionary).get("id", ""))
		if sid == "stone_guard": guard = s
		if sid == "stone_archive": archive = s

	# (1) a Guardiã dos Nomes existe no FUNDO (nv0, dentro da câmara y>450) com 3..6 falas
	# (cap 5→6: stale pré-existente — a Guardiã foi aprofundada p/ 6 falas; NÃO é regressão do PEDRA_LEGACY_F5)
	var gpos: Vector2 = guard.get("pos", Vector2.ZERO)
	var guard_ok: bool = not guard.is_empty() and int(guard.get("level", -1)) == 0 \
		and gpos.y > 450.0 and gpos.x > 1660.0 and gpos.x < 2074.0 \
		and (guard.get("msg", []) as Array).size() >= 3 and (guard.get("msg", []) as Array).size() <= 6
	print("  (1) Guardiã dos Nomes no FUNDO (nv0, câmara, 3..6 falas): %s  %s" % [str(guard_ok), ("OK" if guard_ok else "✗")])
	if not guard_ok: ok = false

	# (2) o Arquivo dos Nomes (marcador) existe (nv0) com texto que carrega o significado
	var arc_ok: bool = not archive.is_empty() and int(archive.get("level", -1)) == 0 and (archive.get("msg", []) as Array).size() >= 2
	print("  (2) Arquivo dos Nomes (marcador nv0 + texto): %s  %s" % [str(arc_ok), ("OK" if arc_ok else "✗")])
	if not arc_ok: ok = false

	# (3) a câmara é ENCERRADA: parede sul/oeste bloqueiam, e a fenda de entrada (norte, x1812..1912) está ABERTA
	var bl0: Array = (main.get("_blockers_by_level") as Dictionary).get(0, [])
	var wall_south := _hit(bl0, Vector2(1900, 642))   # muro sul
	var wall_west := _hit(bl0, Vector2(1655, 548))    # muro oeste
	var wall_nw := _hit(bl0, Vector2(1740, 455))      # muro norte (parte oeste da fenda)
	var gap_open := not _hit(bl0, Vector2(1862, 455)) # a fenda de entrada está aberta
	var enclosed := wall_south and wall_west and wall_nw and gap_open
	print("  (3) câmara encerrada (sul/oeste/norte bloqueiam) + fenda de entrada aberta: %s  %s" % [str(enclosed), ("OK" if enclosed else "✗")])
	if not enclosed: ok = false

	# (4) interação same-level: player na pos da Guardiã (nv0) → fala com ela; com nv1 (terraço) NÃO
	player.position = gpos
	main.set("_floor_level", 0)
	var i0: Dictionary = main._nearest_interaction()
	main.set("_floor_level", 1)
	var i1: Dictionary = main._nearest_interaction()
	var inter: bool = str((i0.get("ref", {}) as Dictionary).get("id", "")) == "stone_guard" and str((i1.get("ref", {}) as Dictionary).get("id", "")) != "stone_guard"
	print("  (4) interação same-level (Guardiã fala no nv0; bloqueada no nv1): %s  %s" % [str(inter), ("OK" if inter else "✗")])
	if not inter: ok = false

	# (5) a comunidade do TERRAÇO segue intacta (4 Testemunhas + Vigia = 5 serviços nv1)
	var terrace := 0
	for s in svcs:
		if str((s as Dictionary).get("id", "")) in ["stone_obs", "stone_rep", "stone_jov", "stone_sil", "stone_vigia"]:
			terrace += 1
	var comm_ok: bool = terrace == 5
	print("  (5) comunidade do terraço intacta (4 + Vigia = 5): %d  %s" % [terrace, ("OK" if comm_ok else "✗")])
	if not comm_ok: ok = false

	if player.get_parent() != null: player.get_parent().remove_child(player)
	player.free(); host.free()
	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snapshot); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)

func _hit(blockers: Array, p: Vector2) -> bool:
	for b in blockers:
		if (b as Rect2).has_point(p):
			return true
	return false
