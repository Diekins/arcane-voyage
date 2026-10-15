extends SceneTree
## Self-test VERTICALITY FASE 3 — a SUBIDA da Pedra virou verticalidade REAL. Main DESTACADO + snapshot/restore do save.
## Prova: base = nível 0 (plano legado); mirante = TERRAÇO nível 1 (contêiner z alto); escada troca o andar SEM teleporte;
## colisão same-level (muro da base não bloqueia o terraço e vice-versa); interação (Vigia) só same-level; z não estoura.
## Rodar:  godot --headless --path godot -s res://scripts/_stone_vertical_selftest.gd

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
	var player := Node2D.new()
	player.set_script(load("res://scripts/PlayerController.gd"))
	player.position = Vector2(300, 500)
	root.add_child(player)
	main.set("_player", player)

	main._build_stone_arrival(main._region_world_size("deep_dunes"))
	var fc: Dictionary = main.get("_floor_containers")
	var bl0: Array = (main.get("_blockers_by_level") as Dictionary).get(0, [])
	var bl1: Array = (main.get("_blockers_by_level") as Dictionary).get(1, [])
	var terr: Node2D = fc.get(1, null)

	# (estrutura) modo vertical; terraço = contêiner nível 1 (z alto, < 4096); base NÃO é contêiner (plano legado)
	var struct: bool = bool(main.get("_vertical_mode")) and terr != null and terr.z_index == 2000 and terr.z_index < 4096 and terr.y_sort_enabled and not fc.has(0)
	print("  estrutura: vertical=%s terraço z=%d base=plano-legado(sem contêiner 0)=%s  %s" % [str(bool(main.get("_vertical_mode"))), (terr.z_index if terr != null else -1), str(not fc.has(0)), ("OK" if struct else "✗")])
	if not struct: ok = false

	# (colisão same-level) muro da base (nv0) só no 0; limiar do terraço (nv1) só no 1 — não vaza entre andares
	var wall0 := _blk(bl0, Vector2(2200, 165)) and not _blk(bl1, Vector2(2200, 165))   # parede 3 da subida = nível 0
	var thr1 := _blk(bl1, Vector2(2000, 106)) and not _blk(bl0, Vector2(2000, 106))     # limiar fechado = nível 1
	print("  colisão same-level (muro base só nv0, limiar terraço só nv1): %s  %s" % [str(wall0 and thr1), ("OK" if (wall0 and thr1) else "✗")])
	if not (wall0 and thr1): ok = false

	# (1) player começa no NÍVEL 0
	main.set("_floor_level", 0)
	var start0: bool = int(main.get("_floor_level")) == 0
	print("  (1) começa no nível 0 (base): %s  %s" % [str(start0), ("OK" if start0 else "✗")])
	if not start0: ok = false

	# (meio SEM engatar) estar no corpo da escada SEM ter entrado pela base NÃO troca de nível (latch idle)
	main.set("_floor_level", 0)
	player.position = Vector2(1770, 176)   # feet (1770,190): no corpo da escada, mas não engatou pela base
	main._vertical_tick(0.016)
	var midclimb: bool = int(main.get("_floor_level")) == 0
	print("  (meio) no corpo da escada SEM engatar pela base → ainda nível 0: %s  %s" % [str(midclimb), ("OK" if midclimb else "✗")])
	if not midclimb: ok = false

	# (2) SUBIR DE VERDADE: engata na BASE (lower_entry) e só então CRISTA no topo
	player.position = Vector2(1770, 210)   # feet (1770,224): na lower_entry (base) → engata "from_lo"
	main._vertical_tick(0.016)
	var latched_lo: bool = int(main.get("_floor_level")) == 0   # engatou, mas ainda não trocou
	player.position = Vector2(1770, 132)   # feet (1770,146): cruzou o topo (<=150) JÁ engatado → cristou
	main._vertical_tick(0.016)
	var up: bool = int(main.get("_floor_level")) == 1 and player.get_parent() == terr and int(player.get("floor_level")) == 1
	print("  (2) SOBE só após engatar na base + cristar no topo (latch=%s): %s  %s" % [str(latched_lo), str(up), ("OK" if (up and latched_lo) else "✗")])
	if not (up and latched_lo): ok = false

	# (4) interação só same-level: a Vigia (nv1) só responde no terraço
	player.position = Vector2(2010, 132)   # sobre a Vigia
	main.set("_floor_level", 1)
	var iv1: Dictionary = main._nearest_interaction()
	main.set("_floor_level", 0)
	var iv0: Dictionary = main._nearest_interaction()
	var inter: bool = str(iv1.get("kind", "")) == "service" and str((iv1.get("ref", {}) as Dictionary).get("id", "")) == "stone_vigia" and str(iv0.get("kind", "")) != "service"
	print("  (4) Vigia (nv1) só interage same-level: %s  %s" % [str(inter), ("OK" if inter else "✗")])
	if not inter: ok = false

	# (3) DESCER DE VERDADE: engata no TOPO (upper_entry) e só então volta pro nível 0 ao chegar no pé
	main.set("_floor_level", 1)   # re-sincroniza: o jogador está fisicamente no terraço (o passo (4) só mexeu no int p/ testar o gate)
	player.position = Vector2(1770, 131); main._vertical_tick(0.016)   # feet (1770,145): upper_entry → engata "from_hi"
	var still1: bool = int(main.get("_floor_level")) == 1
	player.position = Vector2(1770, 214); main._vertical_tick(0.016)   # feet (1770,228) >= pé(224) JÁ engatado → desce
	var down: bool = int(main.get("_floor_level")) == 0 and player.get_parent() != terr
	print("  (3) DESCE só após engatar no topo + chegar ao pé (eng=%s): %s  %s" % [str(still1), str(down), ("OK" if (down and still1) else "✗")])
	if not (down and still1): ok = false

	# (★ NÃO troca por lado errado) engatar pela base e tentar "descer" pelo pé NÃO deve trocar (latch errado)
	main.set("_floor_level", 0)
	player.position = Vector2(1770, 210); main._vertical_tick(0.016)   # engata from_lo (base)
	player.position = Vector2(1770, 230); main._vertical_tick(0.016)   # vai pro pé (>=224) mas está engatado p/ SUBIR → não desce/troca
	var no_wrong: bool = int(main.get("_floor_level")) == 0
	print("  (★) engatado p/ subir, ir ao pé NÃO troca de nível (sem lado errado): %s  %s" % [str(no_wrong), ("OK" if no_wrong else "✗")])
	if not no_wrong: ok = false

	# (6) z não estoura + (7) default 0 legado
	main.set("_floor_level", 0)
	var zok: bool = terr.z_index < 4096 and main._on_floor({}) and not main._on_floor({"level": 1})
	print("  (6/7) z não estoura (terraço z<4096) + default-0 legado: %s  %s" % [str(zok), ("OK" if zok else "✗")])
	if not zok: ok = false

	if player.get_parent() != null: player.get_parent().remove_child(player)
	player.free(); host.free()
	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snapshot); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)

func _blk(blockers: Array, p: Vector2) -> bool:
	for b in blockers:
		if (b as Rect2).has_point(p):
			return true
	return false
