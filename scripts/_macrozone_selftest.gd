extends SceneTree
## Self-test READ-ONLY do builder offset-aware da macro-zona (GODOT-CONTINUOUS-WORLD-MACROZONE-1).
## Instancia Main DESTACADO (NUNCA add_child → _ready de produção NÃO roda → NÃO toca o save) e replica o
## laço de build de load_macro_zone() p/ as 3 regiões Khet, verificando: manifestos resolvem, blockers
## globalizam (x dentro do offset da zona), z dos props >= 0, contagem de nós cresce. NÃO escreve nada.
## Rodar:  godot --headless --path godot -s res://scripts/_macrozone_selftest.gd

func _initialize() -> void:
	var ok := true
	var main = load("res://scripts/Main.gd").new()   # DESTACADO: _ready não dispara
	main.set("_suppress_internal_borders", true)
	var members: Array = main.MACRO_ZONE_KHET
	var cursor := 0.0
	var bbox := Vector2.ZERO
	var built := []
	var all_blockers := []
	var total_nodes := 0
	for id in members:
		var mr: Dictionary = main._manifest_for(str(id))
		if mr.is_empty() or not mr.has("size"):
			print("  ✗ FALHA: manifesto ausente/sem size: %s" % id); ok = false; continue
		var sz := Vector2(float(mr["size"][0]), float(mr["size"][1]))
		var off := Vector2(cursor, 0)
		var zone := Node2D.new()
		zone.position = off
		main.set("_region_node", zone)
		var blk_before: int = (main.get("_blockers") as Array).size()
		main._build_manifest_ground(str(id), sz)
		main._build_from_manifest(str(id))
		var blk: Array = main.get("_blockers")
		# globaliza os novos blockers (igual ao load_macro_zone)
		var bad_blk := 0
		for i in range(blk_before, blk.size()):
			var r: Rect2 = blk[i]
			var g := Rect2(r.position + off, r.size)
			all_blockers.append(g)
			# verifica que o blocker globalizado cai dentro da faixa-x da zona (folga p/ props nas bordas)
			if g.position.x < off.x - 64 or g.position.x > off.x + sz.x + 64:
				bad_blk += 1
		# z-bump (off.y=0 no layout horizontal → no-op, mas exercita o caminho)
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
		built.append({"id": id, "size": sz, "off": off, "nodes": nodes, "neg_z": neg_z, "prop_z": prop_z, "bad_blk": bad_blk})
		print("  ✓ %s  size=%s off=%s  nós=%d (chão/borda z<0=%d, props z>=0=%d)  blockers_novos=%d bad=%d" % [
			id, str(sz), str(off), nodes, neg_z, prop_z, blk.size() - blk_before, bad_blk])
		if nodes <= 0: print("    ✗ zona sem nós!"); ok = false
		if bad_blk > 0: print("    ✗ %d blockers fora da faixa-x da zona!" % bad_blk); ok = false
		cursor += sz.x
		bbox.x = off.x + sz.x
		bbox.y = max(bbox.y, sz.y)
	print("------")
	print("  RESULTADO: %d/%d regiões | bbox=%s | blockers globais=%d | nós totais=%d" % [
		built.size(), members.size(), str(bbox), all_blockers.size(), total_nodes])
	if built.size() != members.size(): ok = false
	if bbox.x < 2000.0: ok = false   # 3 regiões Khet encostadas devem dar largura ~3000+
	print("  >>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
