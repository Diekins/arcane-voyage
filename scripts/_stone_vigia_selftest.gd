extends SceneTree
## Self-test THE_STONE_BUILD_03 — A VIGIA. Main DESTACADO + snapshot/restore do user://save.
## Verifica: a Vigia É presença (node av_stone_vigia) no MIRANTE (y<200, no alto); serviço [E] "stone_vigia" com
## as 5 FALAS APROVADAS exatas (abre em "Você chegou. Eu vi.", encerra em "...Pode descer."); ela NÃO bloqueia (NPC).
## Save-safe. Rodar:  godot --headless --path godot -s res://scripts/_stone_vigia_selftest.gd

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

	var size: Vector2 = main._region_world_size("deep_dunes")
	main._build_stone_arrival(size)

	# (1) A VIGIA é presença no MIRANTE (alto)
	var vnode: Node2D = null
	vnode = _find_meta(host, "av_stone_vigia")   # F3: a Vigia agora vive no contêiner do terraço (nível 1), não direto no host
	var present := vnode != null and vnode.position.y < 200.0
	print("  Vigia presente no mirante (y<200): %s  %s" % [str(present), ("OK" if present else "✗")])
	if not present: ok = false

	# (2) serviço [E] "stone_vigia" com as 5 falas aprovadas exatas
	var svcs: Array = main.get("_services")
	var svc: Dictionary = {}
	for s in svcs:
		if str((s as Dictionary).get("id", "")) == "stone_vigia":
			svc = s
	var has_svc := not svc.is_empty()
	print("  serviço [E] stone_vigia presente: %s  %s" % [str(has_svc), ("OK" if has_svc else "✗")])
	if not has_svc: ok = false
	if has_svc:
		var title := str(svc.get("title", ""))
		var msg: Array = svc.get("msg", [])
		var title_ok := title == "a Vigia"
		var count_ok := msg.size() == 5
		var open_ok := msg.size() > 0 and str(msg[0]) == "Você chegou. Eu vi."
		var close_ok := msg.size() == 5 and str(msg[4]).ends_with("Pode descer.")
		print("  título 'a Vigia': %s | 5 falas: %s | abre certo: %s | encerra certo: %s  %s" % [str(title_ok), str(count_ok), str(open_ok), str(close_ok), ("OK" if (title_ok and count_ok and open_ok and close_ok) else "✗")])
		if not (title_ok and count_ok and open_ok and close_ok): ok = false

	# (2b) a Vigia declara o NÍVEL correto (terraço = 1) — F2/F3: interação só same-level
	if has_svc:
		var lvl_ok: bool = int(svc.get("level", 0)) == 1
		print("  Vigia no nível 1 (terraço): %s  %s" % [str(lvl_ok), ("OK" if lvl_ok else "✗")])
		if not lvl_ok: ok = false

	# (3) a Vigia NÃO bloqueia (é NPC; o jogador pode chegar perto) — nenhum blocker (qualquer nível) cobre a posição dela
	var bl_all: Array = []
	for k in (main.get("_blockers_by_level") as Dictionary):
		bl_all.append_array((main.get("_blockers_by_level") as Dictionary)[k])
	var blocked := false
	if vnode != null:
		for b in bl_all:
			if (b as Rect2).has_point(vnode.position):
				blocked = true
	print("  Vigia não-bloqueante (NPC): %s  %s" % [str(not blocked), ("OK" if not blocked else "✗")])
	if blocked: ok = false

	host.queue_free()
	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snapshot); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)

func _find_meta(n: Node, meta: String) -> Node2D:
	for c in n.get_children():
		if c is Node2D and c.has_meta(meta):
			return c
		var deep := _find_meta(c, meta)
		if deep != null:
			return deep
	return null
