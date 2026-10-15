extends SceneTree
## Self-test READ-ONLY do A3 EARLY-GAME-HARDENING-1. Main DESTACADO + instâncias DESCARTÁVEIS de GameState (nunca
## o autoload real) — NÃO grava save. Cobre: (a) histerese do region-by-position (ida-e-volta na borda não oscila);
## (b) boss-por-região coerente; (c) compat de save (sem cluster_pos boota com defaults) + round-trip do schema;
## (d) safe-spawn (santuário) dentro do hub.
## Rodar:  godot --headless --path godot -s res://scripts/_hardening_selftest.gd

func _initialize() -> void:
	var ok := true
	var main = load("res://scripts/Main.gd").new()
	var hyst: float = main.MACRO_REGION_HYST

	# montagem das rects do starter (sem build pesado): só offsets/sizes
	var members := []
	for entry in main._macro_cluster_layout("starter"):
		var id: String = str(entry["id"])
		members.append({"id": id, "offset": entry["offset"], "size": main._region_world_size(id)})
	var rects := {}
	for m in members:
		rects[str(m["id"])] = Rect2(m["offset"], m["size"])

	# helper local: replica EXATA da decisão do _macro_region_tick (região-at + histerese grow(-HYST))
	var region_at := func(p: Vector2) -> String:
		for m in members:
			if (rects[str(m["id"])] as Rect2).has_point(p):
				return str(m["id"])
		return ""
	var sim := func(path: Array, start_region: String) -> int:
		var cur := start_region
		var flips := 0
		for p in path:
			var cand: String = region_at.call(p)
			if cand != "" and cand != cur and (rects[cand] as Rect2).grow(-hyst).has_point(p):
				cur = cand
				flips += 1
		return flips

	# (a) HISTERESE — seam village|plains em x=2200, y=800 (dentro da faixa comum)
	# wobble só dentro de ±50 da costura: NÃO deve flipar
	var wobble := []
	for x in [2160, 2240, 2180, 2230, 2200, 2210, 2190]:
		wobble.append(Vector2(x, 800))
	var wobble_flips: int = sim.call(wobble, "starter_village")
	# travessia DEEP ida-e-volta: village(1000) → plains-deep(2400) → village-deep(1000) = 2 flips, sem extras
	var deep := []
	for x in [1000, 2100, 2200, 2250, 2280, 2400, 2300, 2250, 2210, 2140, 2000, 1000]:
		deep.append(Vector2(x, 800))
	var deep_flips: int = sim.call(deep, "starter_village")
	print("  (a) histerese: wobble_flips=%d (esperado 0) | deep_ida-volta_flips=%d (esperado 2)" % [wobble_flips, deep_flips])
	if wobble_flips != 0: ok = false; print("    ✗ histerese oscilou na borda")
	if deep_flips != 2: ok = false; print("    ✗ travessia profunda não deu exatamente 2 trocas")

	# (b) BOSS-POR-REGIÃO — montagem canônica (replica; _macro_sandbox=false → bosses nascem) + lookup
	main.set("_macro_mode", true); main.set("_macro_canonical", true); main.set("_macro_sandbox", false)
	main.set("_suppress_internal_borders", true)
	var macro := Node2D.new(); macro.y_sort_enabled = true; root.add_child(macro)
	var bosses := []   # [{region, node}]
	for m in members:
		var zone := Node2D.new(); zone.position = m["offset"]; zone.y_sort_enabled = true; macro.add_child(zone)
		main.set("_region_node", zone)
		var boss_before = main.get("_current_boss")
		main._build_topdown_map(str(m["id"]), m["size"])
		main._dispatch_region_builder(str(m["id"]), m["size"])
		if main.get("_current_boss") != null and main.get("_current_boss") != boss_before:
			bosses.append({"region": str(m["id"]), "node": main.get("_current_boss")})
	var lookup := func(region: String) -> bool:
		for b in bosses:
			if str(b["region"]) == region and is_instance_valid(b["node"]):
				return true
		return false
	var plains_boss: bool = lookup.call("plains")
	var cave_boss: bool = lookup.call("cave")
	var village_boss: bool = lookup.call("starter_village")
	print("  (b) boss-por-região: plains=%s cave=%s village=%s" % [str(plains_boss), str(cave_boss), str(village_boss)])
	if not (plains_boss and cave_boss and not village_boss): ok = false; print("    ✗ boss-por-região incoerente")

	# (c) COMPAT DE SAVE — instância DESCARTÁVEL (não o autoload). Sem cluster_pos → defaults; round-trip do schema.
	var gs1 = load("res://scripts/GameState.gd").new()
	gs1.apply_dict({})   # save "antigo" sem os campos novos
	var compat_ok: bool = (gs1.cluster_pos == [] and gs1.cluster_id == "")
	var gs2 = load("res://scripts/GameState.gd").new()
	gs2.cluster_pos = [123.0, 456.0]; gs2.cluster_id = "starter"
	var d: Dictionary = gs2.to_dict()
	var gs3 = load("res://scripts/GameState.gd").new()
	gs3.apply_dict(d)
	var rt_ok: bool = (gs3.cluster_pos.size() == 2 and float(gs3.cluster_pos[0]) == 123.0 and gs3.cluster_id == "starter")
	print("  (c) save-compat: antigo→defaults=%s | round-trip=%s" % [str(compat_ok), str(rt_ok)])
	if not compat_ok: ok = false; print("    ✗ save sem cluster_pos não caiu no default")
	if not rt_ok: ok = false; print("    ✗ round-trip do schema falhou")

	# (d) SAFE-SPAWN — hub = 1º membro (Vila); centro dentro do rect do hub
	var hub = members[0]
	var safe: Vector2 = hub["offset"] + (hub["size"] as Vector2) * 0.5
	var safe_ok := (str(hub["id"]) == "starter_village") and (rects["starter_village"] as Rect2).has_point(safe)
	print("  (d) safe-spawn: hub=%s dentro-do-hub=%s | nós-montados=%d" % [str(hub["id"]), str(safe_ok), macro.get_child_count()])
	if not safe_ok: ok = false; print("    ✗ santuário não é o hub/Vila")

	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
