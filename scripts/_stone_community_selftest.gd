extends SceneTree
## Self-test THE_STONE_BUILD_04 — as primeiras Testemunhas (comunidade). Main DESTACADO + snapshot/restore do save.
## Verifica: 4 novas Testemunhas no terraço (+ a Vigia = 5); cada uma com serviço [E] nível 1 e poucas falas;
## estão no alto (terraço); não-bloqueantes; interação same-level (player nv0 não fala com Testemunha nv1).
## Rodar:  godot --headless --path godot -s res://scripts/_stone_community_selftest.gd

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

	# (1) 4 novas Testemunhas (av_stone_witness) + a Vigia (av_stone_vigia) = comunidade de 5
	var witnesses: Array = []
	_collect(host, "av_stone_witness", witnesses)
	var vigia: Array = []
	_collect(host, "av_stone_vigia", vigia)
	var community := witnesses.size() >= 4 and vigia.size() >= 1
	print("  comunidade: %d Testemunhas + %d Vigia (esperado >=4 e >=1)  %s" % [witnesses.size(), vigia.size(), ("OK" if community else "✗")])
	if not community: ok = false

	# (2) cada nova Testemunha = serviço [E] nv1 com 1..5 falas; e estão no alto (terraço, y<160)
	var svcs: Array = main.get("_services")
	var ids := ["stone_obs", "stone_rep", "stone_jov", "stone_sil"]
	var svc_ok := true
	for id in ids:
		var found: Dictionary = {}
		for s in svcs:
			if str((s as Dictionary).get("id", "")) == id: found = s
		var good: bool = not found.is_empty() and int(found.get("level", -1)) == 1
		var msg: Array = found.get("msg", [])
		good = good and msg.size() >= 3 and msg.size() <= 5   # spec BUILD_04 finalizado: 3 a 5 falas cada
		good = good and (found.get("pos", Vector2.ZERO) as Vector2).y < 160.0
		if not good: svc_ok = false; print("    ✗ %s (falas=%d): %s" % [id, msg.size(), str(found)])
	print("  cada Testemunha: serviço nv1 + 3..5 falas + no terraço (y<160): %s  %s" % [str(svc_ok), ("OK" if svc_ok else "✗")])
	if not svc_ok: ok = false

	# (3) não-bloqueantes (nenhum blocker de qualquer nível cobre a posição delas)
	var bl_all: Array = []
	for k in (main.get("_blockers_by_level") as Dictionary):
		bl_all.append_array((main.get("_blockers_by_level") as Dictionary)[k])
	var nonblock := true
	for w in witnesses:
		for b in bl_all:
			if (b as Rect2).has_point((w as Node2D).position): nonblock = false
	print("  Testemunhas não-bloqueantes (NPC): %s  %s" % [str(nonblock), ("OK" if nonblock else "✗")])
	if not nonblock: ok = false

	# (4) interação same-level: player na pos do Observador → nv1 fala, nv0 não
	player.position = Vector2(1842, 138)
	main.set("_floor_level", 1)
	var i1: Dictionary = main._nearest_interaction()
	main.set("_floor_level", 0)
	var i0: Dictionary = main._nearest_interaction()
	var inter: bool = str(i1.get("kind", "")) == "service" and str((i1.get("ref", {}) as Dictionary).get("id", "")) == "stone_obs" and str(i0.get("kind", "")) != "service"
	print("  (4) interação same-level (Observador nv1 fala; nv0 não): %s  %s" % [str(inter), ("OK" if inter else "✗")])
	if not inter: ok = false

	if player.get_parent() != null: player.get_parent().remove_child(player)
	player.free(); host.free()
	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snapshot); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)

func _collect(n: Node, meta: String, out: Array) -> void:
	for c in n.get_children():
		if c is Node2D and c.has_meta(meta):
			out.append(c)
		_collect(c, meta, out)
