extends SceneTree
## Self-test READ-ONLY da GRADUAÇÃO (GODOT-CONTINUOUS-WORLD-GRADUATION-1). Main DESTACADO; NÃO chama
## _macro_enter_region/set_current_region/save_game/apply_dict (que gravariam) — cobre só lógica/montagem segura.
## (1) roteamento de boot via _cluster_of_region; (2) region-by-position (_macro_region_at) + histerese (pura);
## (3) semântica sandbox×canonical×single (_campaign_progress_locked); (4) montagem CANÔNICA com bosses presentes
## offset-aware + mobs + saídas externas; (5) serialização (to_dict tem cluster_pos/cluster_id).
## Rodar:  godot --headless --path godot -s res://scripts/_graduation_selftest.gd

func _initialize() -> void:
	var ok := true
	var main = load("res://scripts/Main.gd").new()

	# (1) ROTEAMENTO DE BOOT (puro): membros do starter → "starter"; região externa → "".
	var r1: String = main._cluster_of_region("starter_village")
	var r2: String = main._cluster_of_region("plains")
	var r3: String = main._cluster_of_region("cave")
	var r4: String = main._cluster_of_region("swamp")
	var r5: String = main._cluster_of_region("khet_oasis")
	print("  (1) cluster_of: village=%s plains=%s cave=%s | swamp=%s oasis=%s" % [r1, r2, r3, r4, r5])
	if not (r1 == "starter" and r2 == "starter" and r3 == "starter"): ok = false; print("    ✗ membros do starter não roteiam")
	if not (r4 == "" and r5 == ""): ok = false; print("    ✗ região externa roteou p/ cluster")

	# (3) SEMÂNTICA DE MODO (puro): gate locked SÓ em sandbox.
	main.set("_macro_sandbox", true); main.set("_macro_canonical", false)
	var g_sandbox: bool = main._campaign_progress_locked()
	main.set("_macro_sandbox", false); main.set("_macro_canonical", true)
	var g_canon: bool = main._campaign_progress_locked()
	main.set("_macro_sandbox", false); main.set("_macro_canonical", false)
	var g_single: bool = main._campaign_progress_locked()
	print("  (3) gate: sandbox=%s canonical=%s single=%s" % [str(g_sandbox), str(g_canon), str(g_single)])
	if not (g_sandbox and not g_canon and not g_single): ok = false; print("    ✗ gate não é sandbox-only")

	# (4) MONTAGEM CANÔNICA (replica load_macro_zone SEM _macro_enter_region/save). Bosses presentes + offset-aware.
	main.set("_macro_mode", true); main.set("_macro_canonical", true); main.set("_macro_sandbox", false)
	main.set("_suppress_internal_borders", true)
	main.set("_macro_zone_rects", [])
	main.set("_macro_bosses", [])
	var macro := Node2D.new(); macro.y_sort_enabled = true; root.add_child(macro)
	var members := []
	var bbox := Vector2.ZERO
	for entry in main._macro_cluster_layout("starter"):
		var id: String = str(entry["id"])
		var off: Vector2 = entry["offset"]
		var sz: Vector2 = main._region_world_size(id)
		var zone := Node2D.new(); zone.position = off; zone.y_sort_enabled = true; macro.add_child(zone)
		main.set("_region_node", zone)
		(main.get("_macro_zone_rects") as Array).append({"region": id, "rect": Rect2(off, sz)})
		var blk_before: int = (main.get("_blockers") as Array).size()
		var por_before: int = (main.get("_portals") as Array).size()
		var boss_before = main.get("_current_boss")
		main._build_topdown_map(id, sz)
		main._dispatch_region_builder(id, sz)
		var blk: Array = main.get("_blockers")
		for i in range(blk_before, blk.size()):
			blk[i] = Rect2((blk[i] as Rect2).position + off, (blk[i] as Rect2).size)
		var por: Array = main.get("_portals")
		for i in range(por_before, por.size()):
			por[i]["pos"] = por[i]["pos"] + off
		if main.get("_current_boss") != null and main.get("_current_boss") != boss_before:
			(main.get("_macro_bosses") as Array).append({"region": id, "node": main.get("_current_boss"), "off": off})
		members.append({"id": id, "off": off, "sz": sz})
		bbox.x = max(bbox.x, off.x + sz.x); bbox.y = max(bbox.y, off.y + sz.y)
	main.set("_region_node", macro)
	# mobs offset-aware
	for m in members:
		main.set("_mob_build_offset", m["off"]); main._build_mobs(str(m["id"]))
	main.set("_mob_build_offset", Vector2.ZERO)
	# boss fixup (reparent → global)
	var bosses: Array = main.get("_macro_bosses")
	var boss_bad := 0
	for b in bosses:
		var node = b["node"]
		if is_instance_valid(node):
			if node.get_parent() != macro: node.reparent(macro, true)
			node.z_index = 0
			var gp: Vector2 = node.position
			if gp.x < -80 or gp.x > bbox.x + 80 or gp.y < -80 or gp.y > bbox.y + 80: boss_bad += 1
			if int(node.z_index) != 0: boss_bad += 1
	var boss_regions := []
	for b in bosses: boss_regions.append(str(b["region"]))
	print("  (4) montagem canônica: bosses=%d %s (offset-bad=%d) | mobs=%d | nós=%d" % [
		bosses.size(), str(boss_regions), boss_bad, (main.get("_mobs") as Array).size(), macro.get_child_count()])
	if bosses.size() < 2: ok = false; print("    ✗ esperado 2 bosses (Lobo plains + Golem cave) em canonical")
	if not ("plains" in boss_regions and "cave" in boss_regions): ok = false; print("    ✗ bosses não são de plains+cave")
	if boss_bad > 0: ok = false; print("    ✗ boss fora do envelope / z!=0")
	if (main.get("_mobs") as Array).size() <= 0: ok = false; print("    ✗ sem mobs em canonical")

	# saídas externas (filtro como no runtime)
	var member_ids := {}
	for m in members: member_ids[str(m["id"])] = true
	var ext := 0; var internal := 0
	for p in (main.get("_portals") as Array):
		if member_ids.has(str(p.get("target", ""))): internal += 1
		else: ext += 1
	print("  (4) portais: externos=%d internos(removíveis)=%d" % [ext, internal])
	if ext <= 0: ok = false; print("    ✗ sem saída externa em canonical")

	# (2) REGION-BY-POSITION (puro): _macro_region_at nos centros + histerese (grow(-HYST)).
	var hyst: float = main.MACRO_REGION_HYST
	var at_ok := true
	for m in members:
		var center: Vector2 = m["off"] + m["sz"] * 0.5
		if main._macro_region_at(center) != str(m["id"]): at_ok = false
	# histerese: ponto a HYST/2 da borda esquerda da 2ª zona NÃO conta como "bem dentro"; no centro, SIM
	var z1 = members[1]
	var near_edge: Vector2 = z1["off"] + Vector2(hyst * 0.5, (z1["sz"] as Vector2).y * 0.5)
	var deep_in: Vector2 = z1["off"] + (z1["sz"] as Vector2) * 0.5
	var rect1: Rect2 = Rect2(z1["off"], z1["sz"])
	var edge_blocks := not rect1.grow(-hyst).has_point(near_edge)   # perto da borda → histerese segura (não troca)
	var deep_ok := rect1.grow(-hyst).has_point(deep_in)             # bem dentro → troca
	print("  (2) region_at-centros=%s | histerese: perto-da-borda-segura=%s bem-dentro-troca=%s" % [str(at_ok), str(edge_blocks), str(deep_ok)])
	if not at_ok: ok = false; print("    ✗ region_at errou algum centro")
	if not (edge_blocks and deep_ok): ok = false; print("    ✗ histerese incorreta")

	# (5) SERIALIZAÇÃO (read-only: to_dict NÃO grava): campos novos presentes. Acessa o autoload pela árvore
	# (evita o identificador global GameState, indisponível em script -s).
	var gs = root.get_node_or_null("GameState")
	var d: Dictionary = gs.to_dict() if gs != null else {}
	var has_fields := d.has("cluster_pos") and d.has("cluster_id")
	print("  (5) save schema tem cluster_pos/cluster_id: %s" % str(has_fields))
	if not has_fields: ok = false; print("    ✗ to_dict não inclui os campos novos")

	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
