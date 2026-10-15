extends SceneTree
## Self-test COMBAT_FEEL — ⚔️ ARENA DE TESTE DA ESQUIVA (DEV). Constrói a arena (_build_arena) num Main DESTACADO e
## prova: (1) os 2 BONECOS DE TREINO (arena_dummy) existem com os windups certos (0.4s comum / 0.2s rápido);
## (2) são SAVE-SAFE (xp/gold/loot = 0 + HP enorme → não morrem → _on_mob_died nunca toca progressão);
## (3) o GOLEM está presente mas em MODO ARENA — NÃO é boss (defeated NÃO ligado a _on_boss_defeated, _current_boss
## fica null) → matá-lo não toca save/recompensa; (4) attack_hero do Golem está ligado (→ _on_enemy_attack, onde mora
## o guard da esquiva). Snapshot/restore do save. Rodar:
##   godot --headless --path godot -s res://scripts/_arena_selftest.gd

func _initialize() -> void:
	var ok := true
	var save_path := "user://arcane_voyage_save.json"
	var snapshot := ""
	var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snapshot = rf.get_as_text(); rf.close()

	var main = load("res://scripts/Main.gd").new()
	var host := Node2D.new(); root.add_child(host)
	main.set("_region_node", host)
	main.set("_mobs", []); main.set("_blockers", []); main.set("_services", []); main.set("_npcs", [])
	main.set("_floor_level", 0)
	var player := Node2D.new()
	player.set_script(load("res://scripts/PlayerController.gd"))
	player.position = Vector2(220, 500)
	root.add_child(player)
	main.set("_player", player)

	main._build_arena(Vector2(1600, 1000))

	# ── (1) as 3 estações de FORMA (arena_dummy: line + cone + circle) ──
	var mobs: Array = main.get("_mobs")
	var dummies := []
	for m in mobs:
		if is_instance_valid(m) and str(m.get("mob_id")) == "arena_dummy":
			dummies.append(m)
	var shapes := {}
	for d in dummies:
		shapes[str(d.get("telegraph_shape"))] = true
	var three_shapes: bool = dummies.size() == 3 and shapes.has("line") and shapes.has("cone") and shapes.has("circle")
	print("  (1) 3 estações de forma (line+cone+circle): n=%d formas=%s  %s" % [dummies.size(), str(shapes.keys()), ("OK" if three_shapes else "✗")])
	if not three_shapes: ok = false

	# ── (2) SAVE-SAFE: xp/gold/loot zerados + HP enorme (não morrem na sessão) ──
	var safe := dummies.size() == 3
	for d in dummies:
		if int(d.get("xp_reward")) != 0 or int(d.get("gold_reward")) != 0: safe = false
		if (d.get("loot_table") as Array).size() != 0: safe = false
		if int(d.get("max_hp")) < 10000: safe = false
	print("  (2) bonecos save-safe (xp/gold/loot=0 + HP≥10000): %s  %s" % [str(safe), ("OK" if safe else "✗")])
	if not safe: ok = false

	# ── (3) GOLEM presente mas NÃO-boss (modo arena) ──
	var golem = main.get("_golem")
	var golem_present: bool = is_instance_valid(golem)
	var cur_boss = main.get("_current_boss")
	var not_region_boss: bool = cur_boss == null
	var defeat_unbound := true
	if golem_present:
		defeat_unbound = not golem.is_connected("defeated", Callable(main, "_on_boss_defeated"))
	print("  (3) Golem presente=%s + NÃO-boss (current_boss null=%s, defeated NÃO→_on_boss_defeated=%s)  %s" % [str(golem_present), str(not_region_boss), str(defeat_unbound), ("OK" if (golem_present and not_region_boss and defeat_unbound) else "✗")])
	if not (golem_present and not_region_boss and defeat_unbound): ok = false

	# ── (4) attack_hero do Golem ligado ao ponto de dano (guard da esquiva) ──
	# (lista de conexões em vez de is_connected: Callable.bind() pode não casar por igualdade exata)
	var atk_bound := false
	if golem_present:
		atk_bound = golem.get_signal_connection_list("attack_hero").size() > 0
	print("  (4) Golem.attack_hero → _on_enemy_attack (guard da esquiva ativo): %s  %s" % [str(atk_bound), ("OK" if atk_bound else "✗")])
	if not atk_bound: ok = false

	if player.get_parent() != null: player.get_parent().remove_child(player)
	player.free(); host.free()
	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snapshot); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
