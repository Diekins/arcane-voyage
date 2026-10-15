extends SceneTree
## Self-test READ-ONLY da micro-história "A Lamparina de Oren" (GODOT-MICRO-STORY-OREN-1). Main DESTACADO +
## snapshot/restore do user://save. Confirma, ao construir a Vila: (1) NPC "Lina" presente (passivo); (2) objeto
## [E] "A Rede de Oren" presente como future_exit (profundidade opcional); (3) SEM recompensa (sem chave "reward",
## XP/loot); (4) o marco de curiosidade "Aviso Desbotado" segue presente (coexistência).
## Rodar:  godot --headless --path godot -s res://scripts/_micro_oren_selftest.gd

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
	var host := Node2D.new()
	root.add_child(host)
	main.set("_region_node", host)
	main.set("_services", [])
	main.set("_npcs", [])
	main._dispatch_region_builder("starter_village", main._region_world_size("starter_village"))

	# (1) Lina (NPC) — nó nomeado sob a região
	var lina := false
	for c in host.get_children():
		if String(c.name).begins_with("Lina"):
			lina = true
	print("  (1) NPC 'Lina' presente (passivo): %s" % str(lina))
	if not lina: ok = false; print("    ✗ Lina não construída")

	# (2)+(3) Rede de Oren — future_exit, SEM reward
	var rede := {}
	var aviso := false
	for s in (main.get("_services") as Array):
		var id := str(s.get("id", ""))
		if id == "curio_a_rede_de_oren": rede = s
		if id == "curio_aviso_desbotado": aviso = true
	var rede_ok := not rede.is_empty() and str(rede.get("kind", "")) == "future_exit"
	var no_reward := not rede.has("reward")
	print("  (2) 'A Rede de Oren' future_exit: %s | (3) sem reward: %s | (4) Aviso Desbotado coexiste: %s" % [str(rede_ok), str(no_reward), str(aviso)])
	if not rede_ok: ok = false; print("    ✗ Rede de Oren ausente/!=future_exit")
	if not no_reward: ok = false; print("    ✗ a micro-história tem recompensa (deveria ser só mundo)")
	if not aviso: ok = false; print("    ✗ marco de curiosidade da Vila sumiu")

	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snapshot); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
