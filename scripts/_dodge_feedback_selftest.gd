extends SceneTree
## Self-test POLISH_PASS_02A — esquiva que paga + telegraph saliente. Verifica (save-safe, puro VFX/leitura): (1) o
## telegraph constrói o CONTORNO novo (_outline) sem quebrar; (2) ★ a HITBOX é IDÊNTICA (as static in_line/in_cone
## seguem corretas = a saliência NÃO mexeu na geometria/alinhamento); (3) o _process roda e o fill ACENDE (alpha sobe)
## ao longo do windup; (4) as funções de feedback existem e `_spawn_dodge_spark` roda sem erro (cria nós de VFX); (5)
## o cooldown anti-spam existe (`_dodge_fb_t`); (6) save intocado (nada aqui salva). Rodar:
##   godot --headless --path godot -s res://scripts/_dodge_feedback_selftest.gd

func _initialize() -> void:
	var ok := true
	var save_path := "user://arcane_voyage_save.json"
	var snap := ""; var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snap = rf.get_as_text(); rf.close()

	# ── (1) o telegraph constrói o contorno ──
	var tele = load("res://scripts/AttackTelegraph.gd").new()
	root.add_child(tele)   # dispara _ready → cria _poly + _outline
	tele.configure("line", Vector2.RIGHT, 200.0, 30.0, 70.0)
	tele.begin(0.4)        # reconstrói a forma (line) + ativa
	var outline = tele.get("_outline")
	var poly = tele.get("_poly")
	var build_ok: bool = outline != null and poly != null and outline.points.size() >= 4 and poly.polygon.size() >= 4
	print("  (1) telegraph constrói contorno (_outline pts=%d, _poly pts=%d)  %s" % [outline.points.size() if outline != null else -1, poly.polygon.size() if poly != null else -1, ("OK" if build_ok else "✗")])
	if not build_ok: ok = false

	# ── (2) ★ HITBOX IDÊNTICA (a saliência NÃO mexeu na geometria): in_line/in_cone static seguem corretas ──
	var origin := Vector2(100, 100); var aim := Vector2.RIGHT
	var on_line: bool = AttackTelegraph.in_line(Vector2(220, 105), origin, aim, 200.0, 30.0)   # dentro da faixa
	var off_line: bool = AttackTelegraph.in_line(Vector2(220, 200), origin, aim, 200.0, 30.0)  # fora (y longe)
	var in_cone: bool = AttackTelegraph.in_cone(Vector2(160, 100), origin, aim, 120.0, 70.0)   # à frente, no leque
	var off_cone: bool = AttackTelegraph.in_cone(Vector2(40, 100), origin, aim, 120.0, 70.0)   # atrás (fora)
	var hitbox_ok: bool = on_line and not off_line and in_cone and not off_cone
	print("  (2) HITBOX intacta: in_line dentro=%s/fora=%s · in_cone frente=%s/atrás=%s  %s" % [str(on_line), str(not off_line), str(in_cone), str(not off_cone), ("OK" if hitbox_ok else "✗")])
	if not hitbox_ok: ok = false

	# ── (3) o _process roda e o fill ACENDE (alpha sobe ao carregar) ──
	var a_start: float = poly.color.a
	for i in range(6):
		tele._process(0.05)   # avança o windup
	var a_mid: float = poly.color.a
	var lit_ok: bool = a_mid > a_start and a_mid <= 1.0 and outline.default_color.a > 0.0
	print("  (3) acende: fill a %0.2f→%0.2f · contorno a=%0.2f  %s" % [a_start, a_mid, outline.default_color.a, ("OK" if lit_ok else "✗")])
	if not lit_ok: ok = false

	# ── (4) funções de feedback existem + _spawn_dodge_spark roda (cria nós) ──
	var main = load("res://scripts/Main.gd").new()
	var host := Node2D.new(); root.add_child(host); main.set("_region_node", host)
	var has_funcs: bool = main.has_method("_on_perfect_dodge") and main.has_method("_spawn_dodge_spark")
	var before := host.get_child_count()
	main._spawn_dodge_spark(Vector2(400, 300))   # anel + 4 faíscas = 5 nós
	var made := host.get_child_count() - before
	var fb_ok: bool = has_funcs and made >= 5
	print("  (4) feedback: funcs presentes=%s · _spawn_dodge_spark criou %d nós  %s" % [str(has_funcs), made, ("OK" if fb_ok else "✗")])
	if not fb_ok: ok = false

	# ── (5) cooldown anti-spam existe ──
	var cd_ok: bool = typeof(main.get("_dodge_fb_t")) == TYPE_FLOAT
	print("  (5) cooldown anti-spam (_dodge_fb_t) presente=%s  %s" % [str(cd_ok), ("OK" if cd_ok else "✗")])
	if not cd_ok: ok = false

	tele.queue_free(); host.free()
	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snap); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
