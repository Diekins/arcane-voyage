extends SceneTree
## Self-test READ-ONLY do cluster INICIAL contínuo (GODOT-CONTINUOUS-WORLD-STARTER-CLUSTER-1, Plano B).
## Instancia Main DESTACADO (NUNCA add_child → _ready de produção NÃO roda → NÃO toca o save) e replica o laço
## de build de load_macro_zone(MACRO_ZONE_STARTER) p/ Vila→Planície→Caverna (regiões PROCEDURAIS), verificando:
## tamanhos resolvem por _region_world_size, o chão+props montam via _build_topdown_map+_dispatch_region_builder,
## blockers globalizam dentro da faixa-x da zona, z dos props>=0, e os BOSSES ficam SUPRIMIDOS sob _macro_mode.
## Rodar:  godot --headless --path godot -s res://scripts/_starter_cluster_selftest.gd

func _initialize() -> void:
	var ok := true
	var main = load("res://scripts/Main.gd").new()   # DESTACADO: _ready não dispara
	main.set("_macro_mode", true)
	main.set("_macro_sandbox", true)                 # GRADUATION-1: guards de boss agora keyam em _macro_sandbox (sem Lobo/Golem)
	main.set("_suppress_internal_borders", true)
	var members: Array = main.MACRO_ZONE_STARTER
	var cursor := 0.0
	var bbox := Vector2.ZERO
	var built := []
	var all_blockers := []
	var total_nodes := 0
	for id in members:
		var sz: Vector2 = main._region_world_size(str(id))   # fonte única (procedural via match)
		if sz.x <= 0.0 or sz.y <= 0.0:
			print("  ✗ FALHA: tamanho inválido p/ %s" % id); ok = false; continue
		var off := Vector2(cursor, 0)
		var zone := Node2D.new()
		zone.position = off
		main.set("_region_node", zone)
		var blk_before: int = (main.get("_blockers") as Array).size()
		main._build_topdown_map(str(id), sz)         # chão procedural (bordas internas suprimidas)
		main._dispatch_region_builder(str(id), sz)   # props/npcs/serviços/portais (boss suprimido)
		var blk: Array = main.get("_blockers")
		var bad_blk := 0
		for i in range(blk_before, blk.size()):
			var r: Rect2 = blk[i]
			var g := Rect2(r.position + off, r.size)
			all_blockers.append(g)
			if g.position.x < off.x - 64 or g.position.x > off.x + sz.x + 64:
				bad_blk += 1
		var neg_z := 0
		var prop_z := 0
		for child in zone.get_children():
			if child is CanvasItem:
				if child.z_index < 0:
					neg_z += 1
				else:
					child.z_index = int(child.z_index + off.y)
					prop_z += 1
		var nodes := zone.get_child_count()
		total_nodes += nodes
		built.append({"id": id, "size": sz, "off": off, "nodes": nodes, "bad_blk": bad_blk})
		print("  ✓ %s  size=%s off=%s  nós=%d (chão/borda z<0=%d, props z>=0=%d)  blockers_novos=%d bad=%d" % [
			id, str(sz), str(off), nodes, neg_z, prop_z, blk.size() - blk_before, bad_blk])
		if nodes <= 0: print("    ✗ zona sem nós!"); ok = false
		if bad_blk > 0: print("    ✗ %d blockers fora da faixa-x da zona!" % bad_blk); ok = false
		cursor += sz.x
		bbox.x = off.x + sz.x
		bbox.y = max(bbox.y, sz.y)
	# BOSS SUPPRESSION: sob _macro_mode nenhum boss deve ter sido criado
	var boss_leak := main.get("_current_boss") != null or main.get("_wolf") != null or main.get("_golem") != null
	print("------")
	print("  boss suprimido? %s (current_boss=%s wolf=%s golem=%s)" % [
		str(not boss_leak), str(main.get("_current_boss")), str(main.get("_wolf")), str(main.get("_golem"))])
	if boss_leak: print("    ✗ BOSS VAZOU na macro-zona!"); ok = false
	print("  RESULTADO: %d/%d regiões | bbox=%s | blockers globais=%d | nós totais=%d" % [
		built.size(), members.size(), str(bbox), all_blockers.size(), total_nodes])
	if built.size() != members.size(): ok = false
	if bbox.x < 4000.0: ok = false   # Vila(2200)+Planície(2400)+Caverna(1800) encostadas ≈ 6400 de largura
	print("  >>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
