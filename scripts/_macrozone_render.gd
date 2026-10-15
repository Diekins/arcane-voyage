extends Node2D
## Harness de RENDER (não-produção) p/ preview PNG de macro-zona contínua com o MOTOR DE PRODUÇÃO + Y-SORT NATIVO
## (GODOT-CONTINUOUS-WORLD-YSORT-1): y_sort_enabled na raiz+zonas, props no grupo z=0, ordem por Y GLOBAL.
## Main DESTACADO (não dispara _ready → não toca o save). Cluster por env AV_RENDER_CLUSTER (starter|khet|L).
## "L" = layout NÃO-horizontal (Caverna ABAIXO) com um marcador "Errante" provando a sobreposição na curva.
## Rodar:  AV_RENDER_CLUSTER=L godot --path godot res://scenes/_MacroZoneRender.tscn

func _ready() -> void:
	var main = load("res://scripts/Main.gd").new()
	main.set("_macro_mode", true)               # ativa o caminho y-sort
	main.set("_suppress_internal_borders", true)
	var which := "starter"
	if OS.has_environment("AV_RENDER_CLUSTER"):
		which = OS.get_environment("AV_RENDER_CLUSTER")
	# AV_RENDER_CANONICAL=1 → modo CANÔNICO (bosses PRESENTES via _dispatch, gate off). Default = sandbox (sem boss).
	var canonical := OS.has_environment("AV_RENDER_CANONICAL")
	main.set("_macro_canonical", canonical)
	main.set("_macro_sandbox", not canonical)
	# layout: clusters reais (starter/khet/forest) vêm do CONTRATO (_macro_cluster_layout); "L" = hardcode do YSORT-1.
	var layout: Array = []
	if which == "L":
		layout = [
			{"id": "starter_village", "offset": Vector2(0, 0)},
			{"id": "plains", "offset": Vector2(2400, 0)},
			{"id": "cave", "offset": Vector2(0, 1600)},   # Caverna ABAIXO da Vila → offset.y>0 (a curva)
		]
	elif which == "merged":
		layout = main._merged_world_layout()   # Fase C: todos os clusters graduados num só espaço (world_pos)
	else:
		if not (which in ["starter", "khet", "forest"]):
			which = "starter"
		layout = main._macro_cluster_layout(which)
	# normaliza offsets p/ min-corner (0,0) — o merged tem world_pos negativo (forest ao norte)
	var minc := Vector2(INF, INF)
	for e in layout:
		minc = minc.min(e["offset"])
	if minc.x != INF:
		for e in layout:
			e["offset"] = (e["offset"] as Vector2) - minc
	var bbox := Vector2.ZERO
	self.y_sort_enabled = true                   # raiz y-sortada (igual à macro de produção)
	for entry in layout:
		var id: String = str(entry["id"])
		var sz: Vector2 = main._region_world_size(id)
		if sz.x <= 0.0 or sz.y <= 0.0:
			continue
		var off: Vector2 = entry["offset"]
		var zone := Node2D.new()
		zone.position = off
		zone.y_sort_enabled = true
		add_child(zone)
		main.set("_region_node", zone)
		main._build_topdown_map(id, sz)
		main._dispatch_region_builder(id, sz)
		for child in zone.get_children():
			if child is CanvasItem and child.z_index >= 0:
				child.z_index = 0
				child.z_as_relative = true
		bbox.x = max(bbox.x, off.x + sz.x)
		bbox.y = max(bbox.y, off.y + sz.y)
	# MOBS visíveis (CONTENT-1): pass offset-aware → mobs na raiz (self) em coords globais, z=0 (y-sort)
	if which != "L":
		for entry in layout:
			var mid: String = str(entry["id"])
			var moff: Vector2 = entry["offset"]
			main.set("_mob_build_offset", moff)
			main.set("_region_node", self)
			main._build_mobs(mid)
		main.set("_mob_build_offset", Vector2.ZERO)
	# marcador "Errante" (azul, alto) na CURVA do L p/ provar a sobreposição: props ao sul desenham por cima dele,
	# ao norte por baixo (y-sort por Y global). Filho da raiz y-sortada, z=0.
	if which == "L":
		var hero := Node2D.new()
		hero.position = Vector2(360, 1500)   # perto da costura Vila/Caverna
		hero.y_sort_enabled = false
		add_child(hero)
		var body := Polygon2D.new()
		body.polygon = PackedVector2Array([Vector2(-16, -64), Vector2(16, -64), Vector2(16, 0), Vector2(-16, 0)])
		body.color = Color("3fa7ff")
		hero.add_child(body)
		var tag := Label.new()
		tag.text = "Errante"
		tag.position = Vector2(-24, -84)
		hero.add_child(tag)
	# borda do mundo inteiro
	var t := 36.0
	for r in [Rect2(0, 0, bbox.x, t), Rect2(0, bbox.y - t, bbox.x, t), Rect2(0, 0, t, bbox.y), Rect2(bbox.x - t, 0, t, bbox.y)]:
		var b := ColorRect.new()
		b.size = r.size; b.position = r.position; b.color = Color(0.05, 0.06, 0.08, 0.85); b.z_index = -17
		add_child(b)
	var vp := get_viewport().get_visible_rect().size
	var cam := Camera2D.new()
	cam.position = bbox * 0.5
	cam.zoom = Vector2.ONE * min(vp.x / bbox.x, vp.y / bbox.y) * 0.96
	add_child(cam)
	cam.make_current()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var suffix := "ysort_L" if which == "L" else ("merged_world" if which == "merged" else ("forest_vertical" if which == "forest" else (which + ("_graduated" if canonical else "_continuous"))))
	var out := ProjectSettings.globalize_path("res://docs/previews/macrozone_%s_render.png" % suffix)
	img.save_png(out)
	print("[MacroZoneRender] cluster=%s salvo: %s | bbox=%s" % [which, out, str(bbox)])
	get_tree().quit(0)
