extends SceneTree
## Self-test THE_HOMESTEAD_BUILD_03 — As Raízes da Morada (o continuar). Verifica: (1) constrói (gesto bater o ferro
## + descoberta as contas penduradas); (2) a descoberta mostra a vida compartilhada (nomes de quem foi/ficou:
## Yalla/Kesh); (3) o gesto "bater o ferro" tem a posição da bigorna. Dorn/Sila aprofundados = grep no source. Save-safe.
## Rodar:  godot --headless --path godot -s res://scripts/_raizes_selftest.gd

func _initialize() -> void:
	var ok := true
	var save_path := "user://arcane_voyage_save.json"
	var snap := ""; var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snap = rf.get_as_text(); rf.close()

	var main = load("res://scripts/Main.gd").new()
	var host := Node2D.new(); root.add_child(host); main.set("_region_node", host)
	main.set("_services", [])
	main._build_raizes_da_morada()

	var ges := {}; var disc := {}
	for s in (main.get("_services") as Array):
		var id := str((s as Dictionary).get("id", ""))
		if id == "forja_bater": ges = s
		if id == "contas_penduradas": disc = s

	# ── (1) constrói: gesto + descoberta ──
	var c1: bool = not ges.is_empty() and not disc.is_empty()
	print("  (1) Raízes constrói: gesto(bater o ferro)=%s descoberta(contas)=%s  %s" % [str(not ges.is_empty()), str(not disc.is_empty()), ("OK" if c1 else "✗")])
	if not c1: ok = false

	# ── (2) a descoberta mostra a vida compartilhada (nomes de quem foi/ficou) ──
	var disc_ok := false
	if not disc.is_empty():
		var txt := ""
		for line in (disc as Dictionary).get("msg", []): txt += str(line) + " "
		disc_ok = ("Yalla" in txt) and ("Kesh" in txt) and ("ficou e de quem foi" in txt) and ("não risca" in txt)
	print("  (2) descoberta mostra a vida compartilhada (Yalla/Kesh/quem ficou e foi): %s  %s" % [str(disc_ok), ("OK" if disc_ok else "✗")])
	if not disc_ok: ok = false

	# ── (3) o gesto tem a posição da bigorna (p/ a faísca) ──
	var ges_ok: bool = not ges.is_empty() and (ges as Dictionary).get("anvil", Vector2.ZERO) != Vector2.ZERO
	print("  (3) gesto 'bater o ferro' tem a bigorna: %s  %s" % [str(ges_ok), ("OK" if ges_ok else "✗")])
	if not ges_ok: ok = false

	host.free()
	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snap); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
