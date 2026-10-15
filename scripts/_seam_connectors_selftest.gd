extends SceneTree
## Self-test READ-ONLY do A2 SEAM-CONNECTORS-1. Main DESTACADO; render-only (não toca save/blocker/layout).
## Verifica: as costuras INTERNAS do cluster recebem 1 faixa cada (posição correta, NÃO nas bordas externas);
## cada faixa tem SEAM_STRIPS tiras em z=-8; nenhum blocker novo é criado.
## Rodar:  godot --headless --path godot -s res://scripts/_seam_connectors_selftest.gd

func _initialize() -> void:
	var ok := true
	var main = load("res://scripts/Main.gd").new()

	for cluster in ["starter", "forest"]:
		var members := []
		var bbox := Vector2.ZERO
		for entry in main._macro_cluster_layout(cluster):
			var id: String = str(entry["id"])
			var off: Vector2 = entry["offset"]
			var sz: Vector2 = main._region_world_size(id)
			members.append({"id": id, "offset": off, "size": sz})
			bbox.x = max(bbox.x, off.x + sz.x)
			bbox.y = max(bbox.y, off.y + sz.y)
		# _region_node = nó na árvore p/ receber o container
		var host := Node2D.new()
		root.add_child(host)
		main.set("_region_node", host)
		main.set("_blockers", [])
		var blk_before: int = (main.get("_blockers") as Array).size()
		main._build_seam_connectors(members)
		var blk_after: int = (main.get("_blockers") as Array).size()
		# acha o container SeamConnectors
		var container: Node = null
		for c in host.get_children():
			if c.name == "SeamConnectors":
				container = c
		var bands := 0
		var bad_pos := 0
		var bad_strip := 0
		var seam_list := []
		if container != null:
			bands = container.get_child_count()
			for band in container.get_children():
				var axis := str(band.get_meta("axis"))
				var seam: float = float(band.get_meta("seam"))
				seam_list.append("%s@%.0f" % [axis, seam])
				# a costura tem que ser INTERNA (0 < seam < bbox no eixo) e não nas bordas externas
				var span := bbox.x if axis == "v" else bbox.y
				if seam <= 1.0 or seam >= span - 1.0:
					bad_pos += 1
				# tiras: SEAM_STRIPS ColorRects em z=-8
				if band.get_child_count() != main.SEAM_STRIPS:
					bad_strip += 1
				for st in band.get_children():
					if not (st is ColorRect) or int(st.z_index) != -8:
						bad_strip += 1
						break
		print("  %s: faixas=%d %s | bad_pos=%d bad_strip=%d | blockers %d→%d" % [
			cluster, bands, str(seam_list), bad_pos, bad_strip, blk_before, blk_after])
		# starter (3 zonas horizontais) e forest (3 zonas verticais) → 2 costuras internas cada
		if bands != 2: ok = false; print("    ✗ esperado 2 costuras internas")
		if bad_pos > 0: ok = false; print("    ✗ costura numa borda externa (deveria ser só interna)")
		if bad_strip > 0: ok = false; print("    ✗ tiras de faixa erradas (count/z)")
		if blk_after != blk_before: ok = false; print("    ✗ seam connector criou blocker (deveria ser render-only)")

	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
