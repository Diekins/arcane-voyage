extends SceneTree
## Self-test FATIA A1 — INTEGRAÇÃO REAL: tica o AutoPlay contra o ADAPTER REAL do Main.gd (não um mock),
## com um PlayerController real e mobs-stub, provando a fiação de ponta a ponta:
##   autoplay_acquire_nearest → _select_enemy → _auto_target travado → autoplay_has_target/in_range.
## Não constrói a região inteira (HUD/janela) — injeta _player + _mobs direto (sandbox), como os outros
## self-tests fazem. Save snapshot/restore. Rodar:
##   godot --headless --path godot -s res://scripts/_autoplay_integration_selftest.gd

## Mob-stub mínimo: só o que o alvejamento do Main exige (_target_alive: is_instance_valid + is_alive()).
class StubMob extends Node2D:
	var alive := true
	var mob_name := "Stub"
	var hp := 10
	var max_hp := 10
	func is_alive() -> bool: return alive

func _initialize() -> void:
	var ok := true
	var save_path := "user://arcane_voyage_save.json"
	var snapshot := ""
	var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snapshot = rf.get_as_text(); rf.close()

	# Main em sandbox (sem _ready/HUD): só os campos que o adapter A1 lê.
	var main = load("res://scripts/Main.gd").new()
	main.set("_title_open", false)
	main.set("_inv_open", false)
	main.set("_shop_open", false)
	main.set("_stash_open", false)
	main.set("_mastery_open", false)
	main.set("_dialog", null)
	main.set("_current_boss", null)

	# Player real (dispara _ready → cria ActorAnimator; set_move_target/is_manual_moving reais).
	var p := Node2D.new()
	p.set_script(load("res://scripts/PlayerController.gd"))
	p.position = Vector2(500, 500)
	root.add_child(p)
	main.set("_player", p)

	# Dois mobs: um perto (600,500 → 100px), um longe (1500,500 → 1000px). Espera-se travar o PERTO.
	var near := StubMob.new(); near.position = Vector2(600, 500); near.mob_name = "Perto"
	var far := StubMob.new(); far.position = Vector2(1500, 500); far.mob_name = "Longe"
	root.add_child(near); root.add_child(far)
	main.set("_mobs", [far, near])   # ordem embaralhada de propósito (o mais próximo deve vencer)

	# (1) pode combater (herói vivo, sem menus)
	var canf: bool = main.call("autoplay_can_fight")
	print("  (1) autoplay_can_fight: %s  %s" % [str(canf), ("OK" if canf else "✗")])
	if not canf: ok = false

	# (2) aquisição real: pega o mob mais PRÓXIMO e trava como _auto_target
	var acq: bool = main.call("autoplay_acquire_nearest")
	var locked = main.get("_auto_target")
	var acq_ok: bool = acq and locked == near
	print("  (2) acquire_nearest trava o mais próximo: %s  %s" % [str(acq_ok), ("OK" if acq_ok else "✗")])
	if not acq_ok: ok = false

	# (3) has_target + in_range coerentes (near está a 100px; alcance melee ATTACK_RANGE ~=... in_range talvez false)
	var has_t: bool = main.call("autoplay_has_target")
	print("  (3) autoplay_has_target após aquisição: %s  %s" % [str(has_t), ("OK" if has_t else "✗")])
	if not has_t: ok = false

	# (4) AutoPlay real ticando contra o Main real: com alvo já travado, NÃO deve re-adquirir nem quebrar;
	#     estado deve refletir APPROACHING/FIGHTING (tem alvo).
	var ap = load("res://scripts/AutoPlay.gd").new()
	root.add_child(ap)
	ap.setup(main)
	ap.tick(0.1)
	var st = ap.get_state()
	var tick_ok: bool = (st == ap.St.APPROACHING or st == ap.St.FIGHTING) and main.get("_auto_target") == near
	print("  (4) AutoPlay.tick com alvo travado → APPROACHING/FIGHTING, mantém alvo: %s  %s" % [str(tick_ok), ("OK" if tick_ok else "✗")])
	if not tick_ok: ok = false

	# (5) alvo "morre" (some) → adapter solta e AutoPlay readquire o outro (far) na próxima busca
	near.alive = false
	# o auto-attack legado do Main soltaria; aqui simulamos via release + deixamos o AutoPlay readquirir
	main.call("autoplay_release")
	var released: bool = main.get("_auto_target") == null
	# só o far continua vivo → AutoPlay deve travá-lo (está a 1000px, dentro do AUTOPLAY_ACQUIRE_RADIUS=1800)
	for i in range(4): ap.tick(0.1)
	var re_ok: bool = released and main.get("_auto_target") == far
	print("  (5) alvo morto → solta e readquire o próximo vivo: %s  %s" % [str(re_ok), ("OK" if re_ok else "✗")])
	if not re_ok: ok = false

	# (6) ambos mortos → aguarda sem erro, sem travar o Auto (SEARCHING, sem alvo)
	far.alive = false
	main.call("autoplay_release")
	for i in range(6): ap.tick(0.1)
	var wait_ok: bool = ap.enabled and main.get("_auto_target") == null and ap.get_state() == ap.St.SEARCHING
	print("  (6) todos mortos → SEARCHING aguardando, sem erro: %s  %s" % [str(wait_ok), ("OK" if wait_ok else "✗")])
	if not wait_ok: ok = false

	# limpeza + save-safe
	ap.free()
	for n in [p, near, far]:
		if n.get_parent() != null: n.get_parent().remove_child(n)
		n.free()
	main.free()
	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snapshot); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
