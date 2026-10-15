extends SceneTree
## Self-test THE_HOMESTEAD_BUILD_02 — O Limiar (a outra metade da Morada). Verifica: (1) constrói (arco/blockers +
## descoberta [E] + gesto [E]); (2) a descoberta mostra os sinais (marcas/estrada/pedra) sem explicar; (3) o gesto
## "deixar sua marca" existe (com o poste p/ riscar). Tomás aprofundado é conferido por grep no source. Save-safe.
## Rodar:  godot --headless --path godot -s res://scripts/_limiar_selftest.gd

func _initialize() -> void:
	var ok := true
	var save_path := "user://arcane_voyage_save.json"
	var snap := ""; var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snap = rf.get_as_text(); rf.close()

	var main = load("res://scripts/Main.gd").new()
	var host := Node2D.new(); root.add_child(host); main.set("_region_node", host)
	main.set("_services", []); main.set("_npcs", []); main.set("_blockers", []); main.set("_blockers_by_level", {})
	main._build_limiar(Vector2(1100, 1450))

	# ── (1) constrói: arco (blockers) + os 2 markers ──
	var disc := {}; var ges := {}
	for s in (main.get("_services") as Array):
		var id := str((s as Dictionary).get("id", ""))
		if id == "limiar": disc = s
		if id == "limiar_mark": ges = s
	var blk: Array = main.get("_blockers_by_level").get(0, [])
	var c1: bool = not disc.is_empty() and not ges.is_empty() and blk.size() >= 3
	print("  (1) Limiar constrói: descoberta=%s gesto=%s blockers(arco/pedra)=%d  %s" % [str(not disc.is_empty()), str(not ges.is_empty()), blk.size(), ("OK" if c1 else "✗")])
	if not c1: ok = false

	# ── (2) a descoberta mostra os sinais (marcas / estrada / pedra) ──
	var disc_ok := false
	if not disc.is_empty():
		var txt := ""
		for line in (disc as Dictionary).get("msg", []): txt += str(line) + " "
		disc_ok = ("marcas" in txt) and ("estrada" in txt) and ("pedra" in txt) and ("passou" in txt)
	print("  (2) descoberta mostra os sinais (marcas/estrada/pedra/passou): %s  %s" % [str(disc_ok), ("OK" if disc_ok else "✗")])
	if not disc_ok: ok = false

	# ── (3) o gesto "deixar sua marca" existe (com o poste p/ riscar) ──
	var ges_ok: bool = not ges.is_empty() and (ges as Dictionary).get("post") != null
	print("  (3) gesto 'deixar sua marca' existe (com o poste): %s  %s" % [str(ges_ok), ("OK" if ges_ok else "✗")])
	if not ges_ok: ok = false

	host.free()
	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snap); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
