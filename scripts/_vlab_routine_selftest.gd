extends SceneTree
## Self-test VERTICALITY FASE 4 MÍNIMA — NPC roteirizado sobe/desce entre andares SOZINHO (waypoint-stair). Main
## DESTACADO + snapshot/restore do save. Prova a rotina nv0→escada→nv1→ponto alto→escada→nv0, a interação
## same-level com NPC EM MOVIMENTO, colisão por nível e default 0. Rodar:
##   godot --headless --path godot -s res://scripts/_vlab_routine_selftest.gd

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
	player.position = Vector2(150, 620)
	root.add_child(player)
	main.set("_player", player)

	main._build_vlab(main._region_world_size("vlab"))

	var rns: Array = main.get("_routine_npcs")
	var have_rn: bool = rns.size() >= 1
	print("  NPC roteirizado registrado: %s  %s" % [str(have_rn), ("OK" if have_rn else "✗")])
	if not have_rn:
		print(">>> FALHOU"); quit(1); return
	var rn: Dictionary = rns[0]
	var node: Node2D = rn["node"]

	# (1) começa no nível 0
	var start0: bool = int(rn["floor_level"]) == 0
	print("  (1) NPC começa no nível 0: %s  %s" % [str(start0), ("OK" if start0 else "✗")])
	if not start0: ok = false

	# simula a rotina e captura a sequência
	var up := false; var l1wp := false; var gate_up := false; var gate_down := false; var down := false; var returned := false
	for k in range(1400):
		main._stair_npc_tick(0.1)
		var lvl := int(rn["floor_level"])
		var npos: Vector2 = node.position
		if lvl == 1: up = true
		if up and lvl == 1 and npos.distance_to(Vector2(650, 410)) < 18.0 and not l1wp:
			l1wp = true
			# (5) interação só same-level com o NPC EM MOVIMENTO: player na pos do NPC
			player.position = npos
			main.set("_floor_level", 1)
			var i1: Dictionary = main._nearest_interaction()
			main.set("_floor_level", 0)
			var i0: Dictionary = main._nearest_interaction()
			gate_up = str(i1.get("kind", "")) == "npc" and str((i1.get("ref", {}) as Dictionary).get("name", "")) == "Andarilho da Vigília"
			gate_down = str(i0.get("kind", "")) != "npc"
		if up and lvl == 0 and l1wp: down = true
		if down and node.position.distance_to(Vector2(250, 640)) < 26.0: returned = true

	# (2) subiu / (3) chegou ao waypoint do nv1
	print("  (2) NPC SOBE a escada → nível 1: %s  %s" % [str(up), ("OK" if up else "✗")])
	if not up: ok = false
	print("  (3) NPC alcança o waypoint do nível 1: %s  %s" % [str(l1wp), ("OK" if l1wp else "✗")])
	if not l1wp: ok = false
	# (5) interação same-level (NPC em trânsito/no alto)
	print("  (5) player nv0 NÃO interage c/ NPC nv1; nv1 SIM: nv1=%s nv0-bloqueado=%s  %s" % [str(gate_up), str(gate_down), ("OK" if (gate_up and gate_down) else "✗")])
	if not (gate_up and gate_down): ok = false
	# (6) desceu / (7) voltou ao nível 0
	print("  (6) NPC DESCE de volta → nível 0: %s  %s" % [str(down), ("OK" if down else "✗")])
	if not down: ok = false
	print("  (7) NPC retorna ao waypoint do nível 0: %s  %s" % [str(returned), ("OK" if returned else "✗")])
	if not returned: ok = false

	# (8) colisão por nível continua correta (muro só nv0); (9) default 0 legado
	var bl0: Array = (main.get("_blockers_by_level") as Dictionary).get(0, [])
	var bl1: Array = (main.get("_blockers_by_level") as Dictionary).get(1, [])
	var coll: bool = _hit(bl0, Vector2(280, 350)) and not _hit(bl1, Vector2(280, 350))
	var def0: bool = main._on_floor({}) and not main._on_floor({"level": 1})
	print("  (8/9) colisão por nível OK + default-0 legado: %s  %s" % [str(coll and def0), ("OK" if (coll and def0) else "✗")])
	if not (coll and def0): ok = false

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
