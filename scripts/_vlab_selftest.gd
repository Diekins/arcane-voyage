extends SceneTree
## Self-test VERTICALITY FASE 1 — laboratório vertical `vlab` + primitivos. Main DESTACADO + snapshot/restore do save.
## Prova os 8 critérios: (1) chão nível 0; (2) escada sobe pro nível 1; (3) colisão só same-level; (4) passa POR
## BAIXO da ponte no 0; (5) passa POR CIMA no 1; (6) z não estoura (contêineres z pequenos); (7) default 0 = legado;
## (8) este próprio teste headless. Rodar:  godot --headless --path godot -s res://scripts/_vlab_selftest.gd

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
	main.set("_blockers_by_level", {}); main.set("_stair_zones", []); main.set("_floor_containers", {})

	# (7-pré) DEFAULT 0 = legado: _add_blocker sem nível cai no balde 0 E em _blockers
	main._add_blocker(Rect2(0, 0, 5, 5))
	var lvl0: Array = (main.get("_blockers_by_level") as Dictionary).get(0, [])
	var legacy_ok: bool = (main.get("_blockers") as Array).size() == 1 and lvl0.size() == 1
	print("  default-0 legado (_add_blocker sem nível → _blockers + balde 0): %s  %s" % [str(legacy_ok), ("OK" if legacy_ok else "✗")])
	if not legacy_ok: ok = false
	# reset p/ o build limpo
	main.set("_blockers", []); main.set("_blockers_by_level", {})

	# player REAL (PlayerController) na árvore (sem câmera; _set_floor_level guarda _camera null)
	var player := Node2D.new()
	player.set_script(load("res://scripts/PlayerController.gd"))
	player.position = Vector2(150, 620)
	root.add_child(player)
	main.set("_player", player)

	main._build_vlab(main._region_world_size("vlab"))

	var c0: Node2D = (main.get("_floor_containers") as Dictionary).get(0, null)
	var c1: Node2D = (main.get("_floor_containers") as Dictionary).get(1, null)
	var bl0: Array = (main.get("_blockers_by_level") as Dictionary).get(0, [])
	var bl1: Array = (main.get("_blockers_by_level") as Dictionary).get(1, [])

	# (1) chão nível 0: modo vertical, player no contêiner 0, nível 0
	var c1ok: bool = bool(main.get("_vertical_mode")) and c0 != null and c1 != null and player.get_parent() == c0 and int(main.get("_floor_level")) == 0
	print("  (1) começa no nível 0 (modo vertical, player no contêiner 0): %s  %s" % [str(c1ok), ("OK" if c1ok else "✗")])
	if not c1ok: ok = false

	# (6) z não estoura: contêineres com z pequeno (= nível), y_sort interno, c1 acima de c0
	var zok: bool = c0.z_index == 0 and c1.z_index == 1 and c0.z_index < 4096 and c1.z_index < 4096 and c0.y_sort_enabled and c1.y_sort_enabled and c1.z_index > c0.z_index
	print("  (6) desenho: c0.z=%d c1.z=%d (<4096, y_sort, c1>c0): %s  %s" % [c0.z_index, c1.z_index, str(zok), ("OK" if zok else "✗")])
	if not zok: ok = false

	# (3) colisão só same-level: muro do 0 bloqueia no 0 e NÃO no 1; parapeito da ponte bloqueia no 1 e NÃO no 0
	var wall_pt := Vector2(280, 350)         # dentro do muro nível 0 (250,250,60,200)
	var rail_pt := Vector2(600, 364)         # dentro do parapeito N da ponte nível 1 (480,360,340,10)
	var same_level: bool = _hit(bl0, wall_pt) and not _hit(bl1, wall_pt) and _hit(bl1, rail_pt) and not _hit(bl0, rail_pt)
	print("  (3) colisão same-level (muro só no 0, parapeito só no 1): %s  %s" % [str(same_level), ("OK" if same_level else "✗")])
	if not same_level: ok = false

	# (4)/(5) POR BAIXO no 0 e POR CIMA no 1: a passagem sob a ponte está aberta nos DOIS níveis (o deck é andável;
	# o que muda é o DESENHO — c1 sobre c0); e os parapeitos bounded no 1.
	var under_pt := Vector2(600, 410)        # sob/na ponte
	var under0: bool = not _hit(bl0, under_pt)    # nível 0: passa POR BAIXO (sem blocker do 0 ali)
	var over1: bool = not _hit(bl1, under_pt)     # nível 1: anda POR CIMA do deck (interior andável)
	print("  (4) passa POR BAIXO no nível 0 (passagem aberta): %s  %s" % [str(under0), ("OK" if under0 else "✗")])
	if not under0: ok = false
	print("  (5) anda POR CIMA no nível 1 (deck andável + parapeitos): %s  %s" % [str(over1 and _hit(bl1, Vector2(600,364)) and _hit(bl1, Vector2(600,464))), ("OK" if (over1 and _hit(bl1, Vector2(600,364)) and _hit(bl1, Vector2(600,464))) else "✗")])
	if not (over1 and _hit(bl1, Vector2(600,364)) and _hit(bl1, Vector2(600,464))): ok = false

	# (2) escada FÍSICA (chute x400..480, pé y580, topo y470): troca DEPENDENTE DO CAMINHO (latch).
	main.set("_floor_level", 0)
	player.position = Vector2(440, 510)      # feet (440,524): corpo da escada SEM engatar pela base → ainda nível 0
	main._vertical_tick(0.016)
	var midc: bool = int(main.get("_floor_level")) == 0
	print("  (2a) corpo da escada SEM engatar → ainda nível 0: %s  %s" % [str(midc), ("OK" if midc else "✗")])
	if not midc: ok = false
	player.position = Vector2(440, 570)      # feet (440,584): lower_entry (base) → engata "from_lo"
	main._vertical_tick(0.016)
	player.position = Vector2(440, 452)      # feet (440,466) <= topo (470) JÁ engatado → cristou
	main._vertical_tick(0.016)
	var up: bool = int(main.get("_floor_level")) == 1 and player.get_parent() == c1 and int(player.get("floor_level")) == 1
	print("  (2) SOBE só após engatar na base + cristar no topo: %s  %s" % [str(up), ("OK" if up else "✗")])
	if not up: ok = false
	# DESCE: engata no topo (upper_entry) e só então volta p/ nível 0 ao chegar no pé
	player.position = Vector2(440, 457); main._vertical_tick(0.016)   # feet (440,471): upper_entry → engata "from_hi"
	player.position = Vector2(440, 570); main._vertical_tick(0.016)   # feet (440,584) >= pé(580) JÁ engatado → desce
	var down: bool = int(main.get("_floor_level")) == 0 and player.get_parent() == c0
	print("  (2b) DESCE só após engatar no topo + chegar ao pé: %s  %s" % [str(down), ("OK" if down else "✗")])
	if not down: ok = false

	# (7) regiões antigas idênticas: _blockers (ativo legado) tem o muro do 0 e NÃO tem parapeito do 1
	var legacy_sep: bool = _hit(main.get("_blockers"), wall_pt) and not _hit(main.get("_blockers"), rail_pt)
	print("  (7) _blockers (legado) = só nível 0 (muro sim, parapeito não): %s  %s" % [str(legacy_sep), ("OK" if legacy_sep else "✗")])
	if not legacy_sep: ok = false

	# teardown imediato (free, não queue_free) p/ não processar frame extra com nós já liberados
	if player.get_parent() != null:
		player.get_parent().remove_child(player)
	player.free()
	host.free()
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
