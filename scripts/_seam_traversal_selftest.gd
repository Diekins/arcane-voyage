extends SceneTree
## Self-test READ-ONLY da COSTURA + TRAVESSIA Vila↔Bosque no mundo mesclado (GODOT-CONTINUOUS-WORLD-SEAM-TRAIL-1).
## Main DESTACADO; render-only, não grava save. Valida: (1) ashen ENCOSTA a Vila (gap=0) e cobre o portão norte;
## (2) travessia contínua sem VÃO (toda a linha do portão cruza de região em região, sem "" ); (3) costura visual
## (banda horizontal em y=0) criada; (4) marco narrativo (trilha + placa + lore future_exit "trail_of_roots").
## Rodar:  godot --headless --path godot -s res://scripts/_seam_traversal_selftest.gd

func _initialize() -> void:
	var ok := true
	var main = load("res://scripts/Main.gd").new()
	var layout: Array = main._merged_world_layout()
	var rects := {}
	for e in layout:
		rects[str(e["id"])] = Rect2(e["offset"], main._region_world_size(str(e["id"])))
	var village: Rect2 = rects["starter_village"]
	var ashen: Rect2 = rects["ashen_grove"]
	var gate_x: float = main.VILLAGE_TO_NORTH.x

	# (1) ENCOSTA (gap=0): ashen.bottom == village.top ; e cobre o portão em x
	var gap: float = abs((ashen.position.y + ashen.size.y) - village.position.y)
	var abut := gap < 0.5
	var xcov := (village.position.x <= gate_x and gate_x <= village.position.x + village.size.x
		and ashen.position.x <= gate_x and gate_x <= ashen.position.x + ashen.size.x)
	print("  (1) gap Vila↔Bosque=%.1f (abut=%s) | portão x=%.0f coberto pelos dois=%s" % [gap, str(abut), gate_x, str(xcov)])
	if not abut: ok = false; print("    ✗ ainda há vão entre Vila e Bosque")
	if not xcov: ok = false; print("    ✗ o portão norte não cai na sobreposição-x das duas zonas")

	# (2) TRAVESSIA sem vão: toda a linha do portão (sul→norte) cai em ALGUMA região
	main.set("_macro_zone_rects", [])
	for e in layout:
		(main.get("_macro_zone_rects") as Array).append({"region": str(e["id"]), "rect": rects[str(e["id"])]})
	var void_pts := 0
	var path := [200.0, 100.0, 1.0, 0.0, -1.0, -100.0, -300.0, -600.0]
	for y in path:
		if main._macro_region_at(Vector2(gate_x, y)) == "":
			void_pts += 1
	print("  (2) travessia portão: %d/%d pontos em VÃO (esperado 0)" % [void_pts, path.size()])
	if void_pts != 0: ok = false; print("    ✗ há VÃO na linha de travessia")

	# (3) COSTURA visual (banda horizontal em y≈0)
	var host := Node2D.new()
	root.add_child(host)
	main.set("_region_node", host)
	main.set("_blockers", [])
	var members := []
	for e in layout:
		members.append({"id": str(e["id"]), "offset": e["offset"], "size": main._region_world_size(str(e["id"]))})
	main._build_seam_connectors(members)
	var seam_at_gate := false
	for c in host.get_children():
		if c.name == "SeamConnectors":
			for band in c.get_children():
				if str(band.get_meta("axis")) == "h" and abs(float(band.get_meta("seam"))) < 0.5:
					seam_at_gate = true
	print("  (3) costura horizontal em y=0 (Vila↔Bosque) criada: %s" % str(seam_at_gate))
	if not seam_at_gate: ok = false; print("    ✗ sem banda de costura na junção Vila↔Bosque")

	# (4) MARCO NARRATIVO: trilha + placa + lore future_exit "trail_of_roots"
	main.set("_macro_zone_nodes", {"starter_village": Node2D.new(), "ashen_grove": Node2D.new()})
	main.set("_services", [])
	main._build_macro_narrative_seams()
	var trail_lore := false
	for s in (main.get("_services") as Array):
		if str(s.get("id", "")) == "trail_of_roots" and str(s.get("kind", "")) == "future_exit":
			trail_lore = true
	print("  (4) marco narrativo 'Trilha das Raízes' (lore [E], sem transporte/flag): %s" % str(trail_lore))
	if not trail_lore: ok = false; print("    ✗ marco narrativo não criado")

	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
