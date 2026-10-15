extends SceneTree
## Self-test READ-ONLY dos offsets DATA-DRIVEN (GODOT-CONTINUOUS-WORLD-EDITOR-OFFSETS-1).
## Main DESTACADO (não dispara _ready → não toca save). Prova: (1) os 3 clusters montam A PARTIR DO CONTRATO
## (offsets == JSON); (2) abut sem gap/sobreposição na direção dominante; (3) forest tem offset.y>0 REAL e
## ordena por Y GLOBAL na coluna vertical (reusa a asserção do YSORT-1); (4) fallback p/ cluster fora do contrato.
## Rodar:  godot --headless --path godot -s res://scripts/_editor_offsets_selftest.gd

func _initialize() -> void:
	var ok := true
	var main = load("res://scripts/Main.gd").new()
	main.set("_macro_mode", true)
	main.set("_suppress_internal_borders", true)

	# contrato cru (p/ comparar que o layout SAI dele)
	var raw := {}
	var f := FileAccess.open("res://data/macro_clusters.json", FileAccess.READ)
	if f != null:
		raw = JSON.parse_string(f.get_as_text()); f.close()
	if typeof(raw) != TYPE_DICTIONARY or raw.is_empty():
		print("  ✗ contrato ausente/inválido"); ok = false

	for cluster in ["starter", "khet", "forest"]:
		var layout: Array = main._macro_cluster_layout(cluster)
		if layout.is_empty():
			print("  ✗ %s: layout vazio" % cluster); ok = false; continue
		# (1) offsets == contrato
		var members_raw: Array = raw.get(cluster, {}).get("members", [])
		var from_contract := (layout.size() == members_raw.size())
		for i in layout.size():
			if i < members_raw.size():
				var mo = members_raw[i].get("offset", [0, 0])
				var lo: Vector2 = layout[i]["offset"]
				if str(layout[i]["id"]) != str(members_raw[i].get("region", "")) or lo.x != float(mo[0]) or lo.y != float(mo[1]):
					from_contract = false
		# direção dominante (eixo com maior variação de offset)
		var dx := 0.0
		var dy := 0.0
		for e in layout:
			dx = max(dx, (e["offset"] as Vector2).x)
			dy = max(dy, (e["offset"] as Vector2).y)
		var dom_y := dy > dx
		# (2) abut: ordena pela direção dominante; consecutivos encostam (gap=0, sem sobreposição)
		var seq := layout.duplicate()
		seq.sort_custom(func(a, b): return ((a["offset"] as Vector2).y if dom_y else (a["offset"] as Vector2).x) < ((b["offset"] as Vector2).y if dom_y else (b["offset"] as Vector2).x))
		var abut_ok := true
		for i in range(1, seq.size()):
			var prev: Vector2 = seq[i - 1]["offset"]
			var cur: Vector2 = seq[i]["offset"]
			var psz: Vector2 = main._region_world_size(str(seq[i - 1]["id"]))
			var expected := (prev.y + psz.y) if dom_y else (prev.x + psz.x)
			var actual := cur.y if dom_y else cur.x
			if abs(actual - expected) > 0.5:
				abut_ok = false
				print("    ✗ gap/overlap em %s: %s→%s esperado %.0f, veio %.0f" % [cluster, seq[i - 1]["id"], seq[i]["id"], expected, actual])
		var max_oy := 0.0
		for e in layout:
			max_oy = max(max_oy, (e["offset"] as Vector2).y)
		print("  %s: %d regiões | from_contract=%s | dominante=%s | abut=%s | max offset.y=%.0f" % [
			cluster, layout.size(), str(from_contract), ("Y(vertical)" if dom_y else "X(horizontal)"), str(abut_ok), max_oy])
		if not from_contract: ok = false; print("    ✗ layout NÃO bate com o contrato")
		if not abut_ok: ok = false
		if cluster == "forest" and max_oy <= 0.0:
			ok = false; print("    ✗ forest deveria ter offset.y>0 (coluna vertical)")

	# (3) FOREST: build com y-sort + assert ordem por Y global (sul = ancient_root_nest, frente)
	var macro := Node2D.new()
	macro.y_sort_enabled = true
	root.add_child(macro)
	var props := []   # [{id, gy, z}]
	for entry in main._macro_cluster_layout("forest"):
		var id: String = str(entry["id"])
		var off: Vector2 = entry["offset"]
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
	var nonzero := props.filter(func(p): return int(p["z"]) != 0)
	if nonzero.size() > 0: ok = false; print("  ✗ forest: %d props z!=0" % nonzero.size())
	if not props.is_empty():
		var south = props[0]
		for p in props:
			if float(p["gy"]) > float(south["gy"]): south = p
		print("  forest y-sort: SUL (frente, maior Y global) = %s @ gy=%.0f | props=%d todos z=0" % [south["id"], float(south["gy"]), props.size()])
		# pós SEAM-TRAIL a coluna foi reordenada (ashen=entrada ao SUL, encosta na Vila; nest=fim ao norte)
		if south["id"] != "ashen_grove":
			ok = false; print("    ✗ o sul da coluna deveria ser ashen_grove (entrada do Bosque)")

	# (4) FALLBACK: cluster fora do contrato → []; lista const existe p/ fallback horizontal se o arquivo sumir
	var bogus: Array = main._macro_cluster_layout("nao_existe")
	var fb_khet: Array = main._macro_fallback_ids("khet")
	print("  fallback: cluster bogus→%d entradas | _macro_fallback_ids('khet')=%d" % [bogus.size(), fb_khet.size()])
	if not bogus.is_empty(): ok = false; print("    ✗ cluster desconhecido deveria dar layout vazio")
	if fb_khet.size() != 3: ok = false; print("    ✗ fallback const de khet quebrado")

	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
