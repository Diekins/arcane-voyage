extends SceneTree
## Self-test READ-ONLY da FASE B (graduação DATA-DRIVEN + múltiplos clusters). Main DESTACADO; não grava save.
## (1) _graduated_clusters() vem do JSON (graduated:true) = [starter, forest], khet NÃO; (2) _cluster_of_region
## roteia membros de starter→starter, forest→forest, khet→"" (legado), externa→""; (3) FOREST monta canônico
## (mobs + elite presentes, region-by-position, saída externa).
## Rodar:  godot --headless --path godot -s res://scripts/_phaseB_selftest.gd

func _initialize() -> void:
	var ok := true
	var main = load("res://scripts/Main.gd").new()

	# (1) data-driven
	var grad: Array = main._graduated_clusters()
	var has_starter := "starter" in grad
	var has_forest := "forest" in grad
	var has_khet := "khet" in grad
	print("  (1) graduados=%s | starter=%s forest=%s khet=%s" % [str(grad), str(has_starter), str(has_forest), str(has_khet)])
	if not (has_starter and has_forest and not has_khet): ok = false; print("    ✗ graduação data-driven incorreta")

	# (2) roteamento
	var c_village: String = main._cluster_of_region("starter_village")
	var c_plains: String = main._cluster_of_region("plains")
	var c_ashen: String = main._cluster_of_region("ashen_grove")
	var c_nest: String = main._cluster_of_region("ancient_root_nest")
	var c_khet: String = main._cluster_of_region("khet_dune_overlook")
	var c_swamp: String = main._cluster_of_region("swamp")
	print("  (2) rota: village=%s plains=%s ashen=%s nest=%s | khet=%s swamp=%s" % [c_village, c_plains, c_ashen, c_nest, c_khet, c_swamp])
	if not (c_village == "starter" and c_plains == "starter"): ok = false; print("    ✗ starter não roteia")
	if not (c_ashen == "forest" and c_nest == "forest"): ok = false; print("    ✗ forest não roteia")
	if not (c_khet == "" and c_swamp == ""): ok = false; print("    ✗ região não-graduada roteou")

	# (3) FOREST canônico: monta + mobs (elite presente, pois canonical NÃO suprime) + saída externa
	main.set("_macro_mode", true); main.set("_macro_canonical", true); main.set("_macro_sandbox", false)
	main.set("_suppress_internal_borders", true)
	var macro := Node2D.new(); macro.y_sort_enabled = true; root.add_child(macro)
	var members := []
	for entry in main._macro_cluster_layout("forest"):
		var id: String = str(entry["id"])
		var off: Vector2 = entry["offset"]
		var sz: Vector2 = main._region_world_size(id)
		var zone := Node2D.new(); zone.position = off; zone.y_sort_enabled = true; macro.add_child(zone)
		main.set("_region_node", zone)
		var por_before: int = (main.get("_portals") as Array).size()
		main._build_topdown_map(id, sz); main._dispatch_region_builder(id, sz)
		var por: Array = main.get("_portals")
		for i in range(por_before, por.size()): por[i]["pos"] = por[i]["pos"] + off
		members.append({"id": id, "off": off, "sz": sz})
	main.set("_region_node", macro)
	for m in members:
		main.set("_mob_build_offset", m["off"]); main._build_mobs(str(m["id"]))
	main.set("_mob_build_offset", Vector2.ZERO)
	# mobs presentes + elite (root_matriarch) presente no canônico
	var mob_ids := []
	for mob in (main.get("_mobs") as Array): mob_ids.append(str(mob.get("mob_id")))
	var elite_present := "root_matriarch" in mob_ids
	# saídas externas (target fora do forest)
	var member_ids := {}
	for m in members: member_ids[str(m["id"])] = true
	var ext := 0
	for p in (main.get("_portals") as Array):
		if not member_ids.has(str(p.get("target", ""))): ext += 1
	print("  (3) forest canônico: mobs=%d | elite(root_matriarch)=%s | saídas externas=%d" % [(main.get("_mobs") as Array).size(), str(elite_present), ext])
	if (main.get("_mobs") as Array).size() <= 0: ok = false; print("    ✗ sem mobs no forest canônico")
	if not elite_present: ok = false; print("    ✗ elite/mini-boss NÃO presente no forest canônico (deveria, gate off)")
	if ext <= 0: ok = false; print("    ✗ forest sem saída externa")

	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
