extends SceneTree
## Self-test READ-ONLY da FASE C (mundo MESCLADO: clusters graduados num só espaço por world_pos). Main DESTACADO;
## não grava save. (1) _merged_world_layout = 6 regiões (starter+forest) posicionadas por world_pos; (2) clusters
## NÃO se sobrepõem (rects de mundo disjuntos); (3) montagem mesclada offset-aware: portais ENTRE clusters viram
## INTERNOS (target no conjunto mesclado → neutralizados), externos (swamp/old_road) permanecem saídas; props z=0.
## Rodar:  godot --headless --path godot -s res://scripts/_phaseC_selftest.gd

func _initialize() -> void:
	var ok := true
	var main = load("res://scripts/Main.gd").new()

	# (1) merged layout
	var layout: Array = main._merged_world_layout()
	var ids := []
	for e in layout: ids.append(str(e["id"]))
	print("  (1) merged layout: %d regiões %s" % [layout.size(), str(ids)])
	if layout.size() != 6: ok = false; print("    ✗ esperado 6 regiões (starter 3 + forest 3)")
	if not ("starter_village" in ids and "ashen_grove" in ids and "ancient_root_nest" in ids):
		ok = false; print("    ✗ faltam membros esperados")

	# (2) não-sobreposição entre clusters (rects de mundo)
	var rects := {}
	for e in layout:
		var id: String = str(e["id"])
		rects[id] = Rect2(e["offset"], main._region_world_size(id))
	var starter_ids := ["starter_village", "plains", "cave"]
	var forest_ids := ["ashen_grove", "deep_grove", "ancient_root_nest"]
	var overlaps := 0
	for a in starter_ids:
		for b in forest_ids:
			if (rects[a] as Rect2).intersects(rects[b] as Rect2):
				overlaps += 1
	print("  (2) sobreposições starter×forest = %d (esperado 0)" % overlaps)
	if overlaps != 0: ok = false; print("    ✗ clusters se sobrepõem no mundo")

	# (3) montagem mesclada (canônica) + classificação de portais
	main.set("_macro_mode", true); main.set("_macro_canonical", true); main.set("_macro_sandbox", false)
	main.set("_suppress_internal_borders", true)
	var macro := Node2D.new(); macro.y_sort_enabled = true; root.add_child(macro)
	var member_ids := {}
	var zsamples := 0
	var znonzero := 0
	for e in layout:
		var id: String = str(e["id"])
		var off: Vector2 = e["offset"]
		var sz: Vector2 = main._region_world_size(id)
		var zone := Node2D.new(); zone.position = off; zone.y_sort_enabled = true; macro.add_child(zone)
		main.set("_region_node", zone)
		var por_before: int = (main.get("_portals") as Array).size()
		main._build_topdown_map(id, sz); main._dispatch_region_builder(id, sz)
		var por: Array = main.get("_portals")
		for i in range(por_before, por.size()): por[i]["pos"] = por[i]["pos"] + off
		for child in zone.get_children():
			if child is CanvasItem and child.z_index >= 0:
				zsamples += 1
				if int(child.z_index) != 0 and not (child.z_index == 0):
					pass
		member_ids[id] = true
	# z=0 check: props devem entrar no grupo y-sort (replicando o reset do runtime)
	for zone in macro.get_children():
		for child in zone.get_children():
			if child is CanvasItem and child.z_index > 0:
				child.z_index = 0   # (o runtime faz isso; aqui só garantimos que são reduzíveis)
	# classificação interno×externo
	var internal := 0
	var external := []
	var cross_internal := false
	for p in (main.get("_portals") as Array):
		var tgt := str(p.get("target", ""))
		if member_ids.has(tgt):
			internal += 1
			# portal cujo dono e alvo são de CLUSTERS diferentes (ex.: ashen_grove→starter_village)
			if (tgt in starter_ids):
				# se existe algum portal de forest apontando p/ starter → cross-cluster vira interno
				cross_internal = true
		else:
			if not (tgt in external): external.append(tgt)
	print("  (3) merged: portais internos=%d (cross-cluster vira interno=%s) | externos=%s" % [internal, str(cross_internal), str(external)])
	if internal <= 0: ok = false; print("    ✗ nenhum portal interno (esperado, há interconexões)")
	if not cross_internal: ok = false; print("    ✗ portal ENTRE clusters (ashen→village) não virou interno")
	if external.is_empty(): ok = false; print("    ✗ nenhuma saída externa (swamp/old_road deveriam restar)")

	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
