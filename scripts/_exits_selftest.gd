extends SceneTree
## Self-test READ-ONLY do EXITS-1 (saídas externas globalizadas). Main DESTACADO; NÃO executa a transição real
## (load_region/save) — cobre só a GEOMETRIA/ALVO: após montar cada cluster, sobrevivem SÓ portais com target
## EXTERNO ao cluster, com pos GLOBAL dentro do envelope, target ∈ RUNTIME_REGIONS; nenhum interno remanescente.
## Rodar:  godot --headless --path godot -s res://scripts/_exits_selftest.gd

func _initialize() -> void:
	var ok := true
	var main = load("res://scripts/Main.gd").new()
	main.set("_macro_mode", true)
	main.set("_suppress_internal_borders", true)
	var runtime_regions: Array = main.RUNTIME_REGIONS

	for cluster in ["starter", "khet", "forest"]:
		# reset de estado entre clusters
		main.set("_portals", [])
		main.set("_blockers", [])
		var macro := Node2D.new()
		macro.y_sort_enabled = true
		root.add_child(macro)
		var members := []
		var bbox := Vector2.ZERO
		var internal_removed := 0
		for entry in main._macro_cluster_layout(cluster):
			var id: String = str(entry["id"])
			var off: Vector2 = entry["offset"]
			var sz: Vector2 = main._region_world_size(id)
			var zone := Node2D.new()
			zone.position = off
			zone.y_sort_enabled = true
			macro.add_child(zone)
			main.set("_region_node", zone)
			var por_before: int = (main.get("_portals") as Array).size()
			main._build_topdown_map(id, sz)
			main._dispatch_region_builder(id, sz)
			var por: Array = main.get("_portals")
			for i in range(por_before, por.size()):
				por[i]["pos"] = por[i]["pos"] + off   # globaliza (igual ao runtime)
			members.append({"id": id, "off": off, "sz": sz})
			bbox.x = max(bbox.x, off.x + sz.x)
			bbox.y = max(bbox.y, off.y + sz.y)
		# filtro interno×externo (igual ao runtime)
		var member_ids := {}
		for m in members:
			member_ids[str(m["id"])] = true
		var all_por: Array = main.get("_portals")
		var ext := []
		for p in all_por:
			if member_ids.has(str(p.get("target", ""))):
				internal_removed += 1
			else:
				ext.append(p)
		# asserts sobre os externos sobreviventes
		var bad_internal := 0
		var bad_pos := 0
		var bad_target := 0
		var targets := []
		for p in ext:
			var tgt := str(p.get("target", ""))
			targets.append(tgt)
			if member_ids.has(tgt):
				bad_internal += 1
			var pos: Vector2 = p["pos"]
			if pos.x < -80 or pos.x > bbox.x + 80 or pos.y < -80 or pos.y > bbox.y + 80:
				bad_pos += 1
			if not (tgt in runtime_regions):
				bad_target += 1
		print("  %s: externos=%d %s | internos removidos=%d | fora-do-envelope=%d | target-inválido=%d" % [
			cluster, ext.size(), str(targets), internal_removed, bad_pos, bad_target])
		if ext.is_empty(): ok = false; print("    ✗ cluster sem saída externa")
		if bad_internal > 0: ok = false; print("    ✗ portal INTERNO vazou como saída")
		if bad_pos > 0: ok = false; print("    ✗ pos de saída fora do envelope (não globalizada)")
		if bad_target > 0: ok = false; print("    ✗ target de saída fora de RUNTIME_REGIONS")
		if internal_removed == 0: print("    (nota: cluster sem portais internos a remover)")

	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
