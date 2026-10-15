extends SceneTree
## Self-test COMBAT_FEEL_BUILD_01 — a ESQUIVA ("o segundo verbo"). Testa a mecânica no PlayerController (dash +
## i-frames + cooldown) chamando try_dodge()/_process() direto (headless não tem input), e o GUARD de i-frames no
## ÚNICO ponto de dano do Main (_on_enemy_attack): invulnerável → HP intacto. Save snapshot/restore. Rodar:
##   godot --headless --path godot -s res://scripts/_dodge_selftest.gd

func _tick(p: Node, n: int, dt: float) -> void:
	for i in range(n):
		p.call("_process", dt)

func _initialize() -> void:
	var ok := true
	var save_path := "user://arcane_voyage_save.json"
	var snapshot := ""
	var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snapshot = rf.get_as_text(); rf.close()

	# ───── PARTE A: a mecânica da esquiva no PlayerController ─────
	var p := Node2D.new()
	p.set_script(load("res://scripts/PlayerController.gd"))
	p.position = Vector2(500, 500)
	root.add_child(p)   # dispara _ready (cria o ActorAnimator)

	# (1) estado inicial: não-invulnerável, pode esquivar
	var init_ok: bool = (p.call("is_invulnerable") == false) and (p.call("can_dodge") == true)
	print("  (1) inicial: não-invulnerável + pode esquivar: %s  %s" % [str(init_ok), ("OK" if init_ok else "✗")])
	if not init_ok: ok = false

	# (2) try_dodge dispara → invulnerável + em dash
	var pos0: Vector2 = p.position
	var fired: bool = p.call("try_dodge")
	var inv_now: bool = p.call("is_invulnerable")
	var dodge_ok: bool = fired and inv_now
	print("  (2) try_dodge dispara → invulnerável: %s  %s" % [str(dodge_ok), ("OK" if dodge_ok else "✗")])
	if not dodge_ok: ok = false

	# (3) o dash DESLOCA o herói (facing=DOWN → y sobe) durante a janela do dash
	_tick(p, 4, 0.05)   # ~0.2s: cobre o DODGE_TIME (0.16)
	var moved: bool = p.position.distance_to(pos0) > 100.0
	print("  (3) o dash DESLOCA o herói (>100px): %s (%.0fpx)  %s" % [str(moved), p.position.distance_to(pos0), ("OK" if moved else "✗")])
	if not moved: ok = false

	# (4) os i-frames EXPIRAM (janela curta): após ~0.3s totais já não é invulnerável
	_tick(p, 4, 0.05)
	var inv_gone: bool = p.call("is_invulnerable") == false
	print("  (4) i-frames expiram (janela curta): %s  %s" % [str(inv_gone), ("OK" if inv_gone else "✗")])
	if not inv_gone: ok = false

	# (5) COOLDOWN: logo após, não pode re-esquivar; passado o cooldown, pode de novo
	var blocked_by_cd: bool = p.call("try_dodge") == false
	_tick(p, 16, 0.07)   # ~1.1s: passa o DODGE_COOLDOWN (0.85)
	var ready_again: bool = p.call("can_dodge") == true
	print("  (5) cooldown bloqueia, depois libera: bloqueado=%s liberou=%s  %s" % [str(blocked_by_cd), str(ready_again), ("OK" if (blocked_by_cd and ready_again) else "✗")])
	if not (blocked_by_cd and ready_again): ok = false

	# (6) locked (fala/loja) impede a esquiva
	p.set("locked", true)
	var locked_block: bool = p.call("can_dodge") == false and p.call("try_dodge") == false
	p.set("locked", false)
	print("  (6) locked impede esquiva: %s  %s" % [str(locked_block), ("OK" if locked_block else "✗")])
	if not locked_block: ok = false

	# ───── PARTE B: o GUARD de i-frames no ponto único de dano do Main ─────
	var main = load("res://scripts/Main.gd").new()
	main.set("_macro_sandbox", true)
	main.set("_region_node", null)   # _spawn_world_text vira no-op (sem tween fora da árvore); guard ainda retorna
	main.set("_floor_level", 0)
	main.set("_dialog", null)
	var p2 := Node2D.new()
	p2.set_script(load("res://scripts/PlayerController.gd"))
	p2.position = Vector2(800, 800)
	root.add_child(p2)
	main.set("_player", p2)

	var gs = root.get_node_or_null("GameState")
	var hp0 = gs.get("hero_hp") if gs != null else null
	p2.call("try_dodge")   # p2 invulnerável agora
	var inv_p2: bool = p2.call("is_invulnerable")
	main.call("_on_enemy_attack", 25, Node2D.new())   # golpe enquanto invulnerável → guard ANULA
	var hp1 = gs.get("hero_hp") if gs != null else null
	var iframe_blocks: bool = inv_p2 and (hp1 == hp0) and (hp0 != null) and int(hp0) > 0
	print("  (7) i-frames ANULAM o golpe no ponto de dano (HP %s→%s intacto): %s  %s" % [str(hp0), str(hp1), str(iframe_blocks), ("OK" if iframe_blocks else "✗")])
	if not iframe_blocks: ok = false

	# limpeza + save-safe
	for n in [p, p2]:
		if n.get_parent() != null: n.get_parent().remove_child(n)
		n.free()
	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snapshot); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
