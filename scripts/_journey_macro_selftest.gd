extends SceneTree
## Self-test READ-ONLY da JORNADA MACRO (GODOT-CONTINUOUS-WORLD-MERGE-CONTROLLED-1): Vila → Bosque de Cinza →
## Coração das Raízes → Ninho da Raiz Ancestral, no mundo mesclado. Main DESTACADO; não grava save.
## Valida: (a) boot roteia cada região da jornada p/ cluster graduado; (b) progressão espacial monotônica ao NORTE;
## (c) cadeia abutida (gap 0 em cada junção); (d) corredor de travessia (x=1100) sem VÃO e com crossing LIVRE em
## cada costura; (e) marco "Trilha das Raízes" presente.
## Rodar:  godot --headless --path godot -s res://scripts/_journey_macro_selftest.gd

const JOURNEY := ["starter_village", "ashen_grove", "deep_grove", "ancient_root_nest"]

func _initialize() -> void:
	var ok := true
	var main = load("res://scripts/Main.gd").new()
	var layout: Array = main._merged_world_layout()
	var rects := {}
	for e in layout:
		rects[str(e["id"])] = Rect2(e["offset"], main._region_world_size(str(e["id"])))

	# (a) boot routing: cada região da jornada pertence a um cluster graduado (→ merged no boot)
	var route_ok := true
	for r in JOURNEY:
		if main._cluster_of_region(r) == "":
			route_ok = false
	print("  (a) boot roteia toda a jornada p/ merged: %s" % str(route_ok))
	if not route_ok: ok = false; print("    ✗ alguma região da jornada não roteia p/ cluster graduado")

	# (b) progressão monotônica ao NORTE (center.y estritamente DECRESCENTE de Vila→Ninho)
	var prev_y := INF
	var mono := true
	var centers := []
	for r in JOURNEY:
		var c: float = (rects[r] as Rect2).position.y + (rects[r] as Rect2).size.y * 0.5
		centers.append(int(c))
		if c >= prev_y: mono = false
		prev_y = c
	print("  (b) centros Y (Vila→Ninho)=%s | monotônico ao norte=%s" % [str(centers), str(mono)])
	if not mono: ok = false; print("    ✗ progressão espacial não é monotônica ao norte")

	# (c) cadeia abutida (gap 0 em cada junção sucessiva: top de N == bottom de N+1)
	var abut_ok := true
	for i in range(JOURNEY.size() - 1):
		var south: Rect2 = rects[JOURNEY[i]]        # mais ao sul (y maior)
		var north: Rect2 = rects[JOURNEY[i + 1]]    # mais ao norte (y menor)
		var gap: float = abs(south.position.y - (north.position.y + north.size.y))   # south.top vs north.bottom
		if gap > 0.5: abut_ok = false; print("    ✗ gap %s↔%s = %.1f" % [JOURNEY[i], JOURNEY[i+1], gap])
	print("  (c) cadeia abutida (gap 0 em todas as junções): %s" % str(abut_ok))
	if not abut_ok: ok = false

	# build merged (ground+props+blockers) p/ checar corredor
	main.set("_macro_mode", true); main.set("_macro_canonical", true); main.set("_macro_sandbox", false)
	main.set("_suppress_internal_borders", true); main.set("_blockers", []); main.set("_macro_zone_rects", [])
	var macro := Node2D.new(); macro.y_sort_enabled = true; root.add_child(macro)
	for e in layout:
		var id: String = str(e["id"])
		var off: Vector2 = e["offset"]
		var sz: Vector2 = main._region_world_size(id)
		var zone := Node2D.new(); zone.position = off; zone.y_sort_enabled = true; macro.add_child(zone)
		main.set("_region_node", zone)
		var blk_before: int = (main.get("_blockers") as Array).size()
		main._build_topdown_map(id, sz); main._dispatch_region_builder(id, sz)
		var blk: Array = main.get("_blockers")
		for i in range(blk_before, blk.size()):
			blk[i] = Rect2((blk[i] as Rect2).position + off, (blk[i] as Rect2).size)
		(main.get("_macro_zone_rects") as Array).append({"region": id, "rect": Rect2(off, sz)})
	main.set("_region_node", macro)
	var blockers: Array = main.get("_blockers")

	# (d) corredor x=1100 de Vila(800) ao Ninho(~-3200): 0 VÃO + crossing livre em cada costura
	var gate_x := 1100.0
	var y0: float = (rects["starter_village"] as Rect2).position.y + 200.0   # dentro da Vila
	var y1: float = (rects["ancient_root_nest"] as Rect2).position.y + 200.0  # dentro do Ninho
	var voids := 0
	var samples := 0
	var yy := y0
	while yy >= y1:
		samples += 1
		if main._macro_region_at(Vector2(gate_x, yy)) == "":
			voids += 1
		yy -= 100.0
	# crossing livre em cada costura (3 junções): existe x em {1000,1100,1200} com 3 pontos s/ blocker
	var seams := [0.0, -1300.0, -2600.0]
	var seams_clear := 0
	for sy in seams:
		var clear := false
		for cx in [1000.0, 1100.0, 1200.0]:
			var blocked := false
			for dy in [-40.0, 0.0, 40.0]:
				var pt := Vector2(cx, sy + dy)
				for b in blockers:
					if (b as Rect2).has_point(pt): blocked = true; break
				if blocked: break
			if not blocked: clear = true; break
		if clear: seams_clear += 1
	print("  (d) corredor: %d amostras, %d vão | costuras com crossing livre: %d/3" % [samples, voids, seams_clear])
	if voids != 0: ok = false; print("    ✗ corredor tem VÃO")
	if seams_clear != 3: ok = false; print("    ✗ alguma costura sem crossing livre (bloqueada)")

	# (e) marco narrativo
	main.set("_macro_zone_nodes", {"starter_village": Node2D.new(), "ashen_grove": Node2D.new(), "deep_grove": Node2D.new()})
	main.set("_services", [])
	main._build_macro_narrative_seams()
	var marker := false
	for s in (main.get("_services") as Array):
		if str(s.get("id", "")) == "trail_of_roots": marker = true
	print("  (e) marco 'Trilha das Raízes' presente: %s" % str(marker))
	if not marker: ok = false; print("    ✗ marco ausente")

	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
