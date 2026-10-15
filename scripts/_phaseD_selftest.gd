extends SceneTree
## Self-test READ-ONLY da FASE D (cull por proximidade no mundo mesclado). Main DESTACADO; render-only, não grava.
## Com o Errante no centro da Vila: cull é GEOGRÁFICO (por distância real ao rect, não por cluster). Vila+Planície
## (perto) ATIVAS; Caverna (leste distante) e Bosque de Cinza (norte distante) CULLED. Valida _zone_dist_to + raio.
## (Obs.: o sul da coluna da floresta encosta no norte da Vila por world_pos → pode ficar ativo — é correto.)
## Rodar:  godot --headless --path godot -s res://scripts/_phaseD_selftest.gd

func _initialize() -> void:
	var ok := true
	var main = load("res://scripts/Main.gd").new()
	var radius: float = main.CONTINUOUS_CULL_RADIUS

	# rects de mundo do layout mesclado
	var layout: Array = main._merged_world_layout()
	var rects := {}
	for e in layout:
		rects[str(e["id"])] = Rect2(e["offset"], main._region_world_size(str(e["id"])))

	# Errante no centro da Vila
	var village: Rect2 = rects["starter_village"]
	var p: Vector2 = village.position + village.size * 0.5

	var active := []
	var culled := []
	for id in rects.keys():
		var d: float = main._zone_dist_to(p, rects[id])
		if d <= radius:
			active.append(str(id))
		else:
			culled.append(str(id))
	print("  raio=%.0f | player@Vila | ATIVAS=%s | CULLED=%s" % [radius, str(active), str(culled)])

	# cull GEOGRÁFICO: perto ativa, longe culled (independe de cluster). Pós SEAM-TRAIL: o Bosque (ashen) agora
	# ENCOSTA ao norte da Vila → fica ATIVO; o fim da trilha (Ninho, norte distante) e a Caverna (leste) = CULLED.
	if not ("starter_village" in active): ok = false; print("    ✗ Vila deveria estar ativa")
	if not ("plains" in active): ok = false; print("    ✗ Planície (vizinha) deveria estar ativa")
	if not ("ashen_grove" in active): ok = false; print("    ✗ Bosque (encostado à Vila) deveria estar ATIVO")
	if not ("cave" in culled): ok = false; print("    ✗ Caverna (leste distante) deveria estar CULLED")
	if not ("ancient_root_nest" in culled): ok = false; print("    ✗ Ninho (norte distante) deveria estar CULLED")
	if culled.is_empty(): ok = false; print("    ✗ cull não removeu nenhuma zona")
	# auto-consistência: dentro do rect → distância 0
	if main._zone_dist_to(p, village) != 0.0:
		ok = false; print("    ✗ _zone_dist_to dentro do rect != 0")

	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
