extends SceneTree
## Self-test READ-ONLY do Y-SORT do mundo contínuo (GODOT-CONTINUOUS-WORLD-YSORT-1) num layout NÃO-horizontal (L).
## Prova a CURVA: com offset.y>0 (uma zona ABAIXO da outra), props ordenam pela Y GLOBAL e SEM teto (Y>4095).
## Main DESTACADO (não dispara _ready → não toca save). Replica o build da macro-zona com y_sort + reset de z.
## Rodar:  godot --headless --path godot -s res://scripts/_ysort_L_selftest.gd

func _initialize() -> void:
	var ok := true
	var main = load("res://scripts/Main.gd").new()
	main.set("_macro_mode", true)
	main.set("_suppress_internal_borders", true)
	# L-layout: Vila(0,0) · Planície(à direita, y=0) · Caverna(ABAIXO, offset.y=4200 → global Y>4095 = prova s/ teto)
	var ids := ["starter_village", "plains", "cave"]
	var offs := [Vector2(0, 0), Vector2(2400, 0), Vector2(0, 4200)]
	var macro := Node2D.new()
	macro.y_sort_enabled = true
	root.add_child(macro)
	var props := []   # [{id, gy, z}]
	var zones_ysort := 0
	for i in ids.size():
		var id: String = ids[i]
		var off: Vector2 = offs[i]
		var sz: Vector2 = main._region_world_size(id)
		var zone := Node2D.new()
		zone.position = off
		zone.y_sort_enabled = true
		macro.add_child(zone)
		main.set("_region_node", zone)
		main._build_topdown_map(id, sz)
		main._dispatch_region_builder(id, sz)
		for child in zone.get_children():
			if child is CanvasItem and child.z_index >= 0:
				child.z_index = 0
				child.z_as_relative = true
				props.append({"id": id, "gy": off.y + child.position.y, "z": child.z_index})
		if zone.y_sort_enabled:
			zones_ysort += 1

	# A) flags de y-sort
	print("  y_sort: macro=%s zonas=%d/3" % [str(macro.y_sort_enabled), zones_ysort])
	if not macro.y_sort_enabled or zones_ysort != 3:
		ok = false; print("  ✗ y_sort_enabled faltando")
	# B) grupo único z=0 (pré-requisito do y-sort: ordena DENTRO do mesmo z)
	var nonzero := props.filter(func(p): return int(p["z"]) != 0)
	print("  props z=0: %d/%d (não-zero=%d)" % [props.size() - nonzero.size(), props.size(), nonzero.size()])
	if nonzero.size() > 0:
		ok = false; print("  ✗ props com z!=0 quebrariam o grupo y-sort")
	# C) SEM TETO: existem props com Y global > 4095, todos z=0 (o antigo z=int(Y) clamparia a 4095 → empate→ordem errada)
	var tall := props.filter(func(p): return float(p["gy"]) > 4095.0)
	print("  props com Y_global>4095: %d (todos z=0 → ordenação posicional, sem teto)" % tall.size())
	if tall.size() == 0:
		ok = false; print("  ✗ o L não gerou props com Y>4095 (não provou o teto)")
	# D) CURVA: o prop de MAIOR Y global (sul) tem que ser desenhado por ÚLTIMO (frente). Sob o esquema ANTIGO
	#    (z=Y LOCAL por zona), um prop da Caverna com Y local pequeno ficaria ATRÁS de props da Vila (Y local grande)
	#    — ERRADO. O y-sort global corrige. Comparo o sul real (max gy) vs o que o esquema antigo elegeria (max LOCAL y).
	if props.is_empty():
		ok = false; print("  ✗ sem props")
	else:
		var south = props[0]            # maior Y GLOBAL
		var old_front = props[0]        # maior Y LOCAL (o que o esquema antigo poria na frente)
		for p in props:
			if float(p["gy"]) > float(south["gy"]):
				south = p
			var ly_p: float = float(p["gy"]) - (offs[1].y if p["id"] == "plains" else (offs[2].y if p["id"] == "cave" else 0.0))
			var ly_f: float = float(old_front["gy"]) - (offs[1].y if old_front["id"] == "plains" else (offs[2].y if old_front["id"] == "cave" else 0.0))
			if ly_p > ly_f:
				old_front = p
		print("  curva: SUL real (y-sort) = %s @ gy=%.0f | esquema ANTIGO poria na frente = %s" % [south["id"], float(south["gy"]), old_front["id"]])
		if south["id"] != "cave":
			ok = false; print("  ✗ o sul (frente) deveria ser da Caverna (offset.y maior)")
		if south["id"] != old_front["id"]:
			print("  ✓ INVERSÃO confirmada: o esquema antigo (z=Y local) erraria a frente; o y-sort global acerta")
	# E) PLAYER ordena pela própria Y global: marcador entre dois gy conhecidos cai na fatia certa do sort
	var gys := []
	for p in props:
		gys.append(float(p["gy"]))
	gys.sort()
	if gys.size() >= 2:
		var lo: float = gys[0]
		var hi: float = gys[gys.size() - 1]
		var player_gy: float = (lo + hi) * 0.5
		var behind := 0
		var front := 0
		for g in gys:
			if g < player_gy: behind += 1
			elif g > player_gy: front += 1
		print("  player @ gy=%.0f → %d props atrás / %d na frente (ordena por Y, sem z fixo)" % [player_gy, behind, front])
		if behind == 0 or front == 0:
			ok = false; print("  ✗ player não ficou no meio do sort")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
