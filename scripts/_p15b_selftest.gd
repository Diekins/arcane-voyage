extends SceneTree
## Self-test do P1.5-B (Horizontes Naturais). Main DESTACADO + snapshot/restore do user://save. Confirma:
## _region_biome mapeia só os 4 autorizados; ao construir uma região autorizada, a borda vira GRADIENTE de horizonte
## (>4 ColorRects com meta av_horizon) em vez da faixa-vazio; região NÃO autorizada mantém a borda antiga (0 horizonte).
## Rodar:  godot --headless --path godot -s res://scripts/_p15b_selftest.gd

const AUTH := {"saltwind_shore": "costa", "cave": "caverna", "swamp": "pantano", "khet_sar_sands": "deserto"}
const NOT_AUTH := ["old_road", "ashen_grove"]   # Estrada/Floresta = NÃO autorizados → borda antiga

func _initialize() -> void:
	var ok := true
	var save_path := "user://arcane_voyage_save.json"
	var snapshot := ""
	var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snapshot = rf.get_as_text(); rf.close()

	var main = load("res://scripts/Main.gd").new()
	main.set("_macro_sandbox", false)

	# --- _region_biome: mapeamento correto + não-autorizados retornam "" ---
	for rid in AUTH.keys():
		var got := str(main._region_biome(rid))
		var pass_b: bool = got == AUTH[rid]
		print("  _region_biome(%s) = '%s'  %s" % [rid, got, ("OK" if pass_b else "✗ esperado '%s'" % AUTH[rid])])
		if not pass_b: ok = false
	for rid in NOT_AUTH:
		var got2 := str(main._region_biome(rid))
		if got2 != "": ok = false; print("  ✗ _region_biome(%s)='%s' (deveria ser vazio)" % [rid, got2])

	# helper: conta ColorRects com meta av_horizon no region_node
	# (construção real chama _add_map_borders → _add_horizon_borders nos autorizados)
	for rid in AUTH.keys():
		var host := Node2D.new(); root.add_child(host)
		main.set("_region_node", host); main.set("_services", []); main.set("_npcs", [])
		main._build_topdown_map(rid, main._region_world_size(rid))   # chão+bordas (onde a borda é desenhada)
		var hcount := _count_horizon(host)
		var void_count := _count_void_band(host)
		print("  %-16s horizonte=%d  faixa-vazio=%d" % [rid, hcount, void_count])
		if hcount <= 4: ok = false; print("    ✗ %s: sem borda-horizonte (esperado gradiente >4)" % rid)
		if void_count > 0: ok = false; print("    ✗ %s: ainda tem faixa-vazio escura" % rid)
		host.queue_free()

	for rid in NOT_AUTH:
		var host2 := Node2D.new(); root.add_child(host2)
		main.set("_region_node", host2); main.set("_services", []); main.set("_npcs", [])
		main._build_topdown_map(rid, main._region_world_size(rid))   # chão+bordas
		var hcount2 := _count_horizon(host2)
		print("  %-16s (NÃO-autorizado) horizonte=%d (deve ser 0)" % [rid, hcount2])
		if hcount2 != 0: ok = false; print("    ✗ %s: recebeu horizonte indevidamente" % rid)
		host2.queue_free()

	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snapshot); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)

func _count_horizon(node: Node) -> int:
	var n := 0
	for c in node.get_children():
		if c is ColorRect and c.has_meta("av_horizon"): n += 1
	return n

## faixa-vazio = ColorRect z=-17 com a cor escura antiga exata (0.05,0.06,0.08,0.85) e SEM meta horizonte
func _count_void_band(node: Node) -> int:
	var n := 0
	for c in node.get_children():
		if c is ColorRect and not c.has_meta("av_horizon") and c.z_index == -17:
			var col: Color = c.color
			if abs(col.r - 0.05) < 0.01 and abs(col.a - 0.85) < 0.01: n += 1
	return n
