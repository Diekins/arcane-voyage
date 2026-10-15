extends SceneTree
## Self-test THE_STONE_BUILD_02 — A SUBIDA (1ª travessia vertical). Main DESTACADO + snapshot/restore do user://save.
## Verifica (via _blockers, colisão = ponto-pé): TRAILHEAD aberto no pé com muros aos lados; ZIGUE-ZAGUE de 3 paredes
## com brecha ALTERNADA (oeste→leste→oeste); CAMINHO transitável conectando trailhead→mirante pelos vãos; LIMIAR no
## topo FECHADO (sem brecha = habitantes inalcançáveis); casas VISTAS além do limiar (janelas y<60). Save-safe. Rodar:
##   godot --headless --path godot -s res://scripts/_stone_ascent_selftest.gd

func _initialize() -> void:
	var ok := true
	var save_path := "user://arcane_voyage_save.json"
	var snapshot := ""
	var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snapshot = rf.get_as_text(); rf.close()

	var main = load("res://scripts/Main.gd").new()
	main.set("_macro_sandbox", true)
	var host := Node2D.new(); root.add_child(host)
	main.set("_region_node", host)
	main.set("_services", []); main.set("_npcs", []); main.set("_portals", [])
	main.set("_chests", []); main.set("_blockers", [])

	var size: Vector2 = main._region_world_size("deep_dunes")
	main._build_stone_arrival(size)
	var bl: Array = main.get("_blockers")

	# (1) TRAILHEAD: pé murado nos lados + brecha aberta
	var th := _open(bl, Vector2(2050.0, 332.0)) and _blk(bl, Vector2(1700.0, 332.0)) and _blk(bl, Vector2(2300.0, 332.0))
	print("  trailhead (brecha aberta + muros nos lados): %s  %s" % [str(th), ("OK" if th else "✗")])
	if not th: ok = false

	# (2) ZIGUE-ZAGUE: 3 paredes, brecha alternada oeste→leste→oeste
	var w1 := _blk(bl, Vector2(2200.0, 299.0)) and _open(bl, Vector2(1700.0, 299.0))   # parede 1, brecha OESTE
	var w2 := _blk(bl, Vector2(1800.0, 233.0)) and _open(bl, Vector2(2300.0, 233.0))   # parede 2, brecha LESTE
	var w3 := _blk(bl, Vector2(2200.0, 165.0)) and _open(bl, Vector2(1770.0, 165.0))   # parede 3 leste; a brecha agora é o CORREDOR da escada (x1730-1810)
	print("  zigue-zague alternado (O/L/O): w1=%s w2=%s w3=%s  %s" % [str(w1), str(w2), str(w3), ("OK" if (w1 and w2 and w3) else "✗")])
	if not (w1 and w2 and w3): ok = false

	# (3) CAMINHO transitável: cada waypoint da serpentina trailhead→mirante está ABERTO
	var path := [Vector2(2050.0, 340.0), Vector2(1750.0, 322.0), Vector2(1750.0, 300.0), Vector2(2230.0, 260.0), Vector2(2230.0, 233.0), Vector2(1770.0, 200.0), Vector2(1750.0, 165.0), Vector2(2000.0, 130.0)]
	var walkable := true
	for p in path:
		if _blk(bl, p): walkable = false
	print("  caminho transitável até o mirante (8 waypoints abertos): %s  %s" % [str(walkable), ("OK" if walkable else "✗")])
	if not walkable: ok = false

	# (4) MIRANTE = TERRAÇO NÍVEL 1 (VERTICALITY F3): contêiner do andar 1 existe (z alto, < 4096); o LIMIAR fechado
	# agora é blocker do NÍVEL 1 (não vaza p/ o nível 0); e há uma ESCADA (stair zone) ligando 0↔1.
	var bl1: Array = (main.get("_blockers_by_level") as Dictionary).get(1, [])
	var terr: Node2D = (main.get("_floor_containers") as Dictionary).get(1, null)
	var sealed1: bool = _blk(bl1, Vector2(1700.0, 106.0)) and _blk(bl1, Vector2(2000.0, 106.0)) and _blk(bl1, Vector2(2300.0, 106.0))
	var sealed0_open: bool = _open(bl, Vector2(2000.0, 106.0))   # no nível 0 não há esse muro (não vaza entre andares)
	var terr_ok: bool = terr != null and terr.z_index > 1000 and terr.z_index < 4096 and terr.y_sort_enabled
	var has_stair: bool = false
	for z in (main.get("_stair_zones") as Array):
		if int((z as Dictionary).get("a", -9)) == 0 and int((z as Dictionary).get("b", -9)) == 1:
			has_stair = true
	print("  (4) terraço nv1 (contêiner z=%d) + limiar fechado SÓ nv1 + escada 0↔1: %s  %s" % [terr.z_index if terr != null else -1, str(sealed1 and sealed0_open and terr_ok and has_stair), ("OK" if (sealed1 and sealed0_open and terr_ok and has_stair) else "✗")])
	if not (sealed1 and sealed0_open and terr_ok and has_stair): ok = false

	# (5) GANHA VISÃO / casas VISTAS além do limiar: janelas acesas com y<60 (acima do alcance do jogador 60 e do limiar)
	var homes := 0
	for c in host.get_children():
		if c is CanvasItem and c.has_meta("av_stone_window") and (c as Node2D).position.y < 60.0:
			homes += 1
	print("  casas vistas além do limiar (janelas y<60): %d (esperado >=3)  %s" % [homes, ("OK" if homes >= 3 else "✗")])
	if homes < 3: ok = false

	# (6) visuais da subida materializados
	var asc := 0
	for c in host.get_children():
		if c is CanvasItem and c.has_meta("av_stone_ascent"): asc += 1
	print("  elementos da subida (av_stone_ascent): %d (esperado >0)  %s" % [asc, ("OK" if asc > 0 else "✗")])
	if asc <= 0: ok = false

	host.queue_free()
	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snapshot); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)

func _blk(blockers: Array, p: Vector2) -> bool:
	for b in blockers:
		if (b as Rect2).has_point(p):
			return true
	return false

func _open(blockers: Array, p: Vector2) -> bool:
	return not _blk(blockers, p)
