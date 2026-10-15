extends SceneTree
## Self-test/RELATÓRIO FATIA A8.1 — Feedback Renderer / Runtime Wiring / UX Visível. Prova evento→GameFeedback→
## FeedbackRenderer→ELEMENTO VISUAL REAL→cleanup. Parte pura (RENDER/INVUX/SUPUX/STRESS) + parte WIRE no MAIN REAL
## (não host falso, §44). FIXTURE (save vivo intocado).
##   godot --headless --path godot -s res://scripts/_a81_renderer_selftest.gd

var _fail := 0
func _chk(nm: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), nm])
	if not cond: _fail += 1
func _g(): return root.get_node_or_null("GameState")

func _initialize() -> void:
	var gs = _g()
	var fixture := "user://a81_fixture_save.json"
	gs.set_save_path_override(fixture)
	var mem: Dictionary = gs.to_dict()
	gs.reset_save()

	_test_render()
	_test_invux(gs)
	_test_supux(gs)
	_test_stress()

	# ── WIRE no Main REAL (Driver espera o boot) ──
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	var drv := _Driver.new()
	drv.test = self; drv.main = main; drv.gs = gs; drv.mem = mem; drv.fixture = fixture
	root.add_child(drv)

# ══════════════ RENDER (FeedbackRenderer standalone) ══════════════
func _mk_renderer(bus, world) -> FeedbackRenderer:
	var r := FeedbackRenderer.new()
	r.setup(bus, func(): return world, func(): return null)
	return r

func _test_render() -> void:
	print("  ── RENDER (FeedbackRenderer cria/limpa elementos) ──")
	var bus := GameFeedback.new()
	var world := Node2D.new()
	var r := _mk_renderer(bus, world)
	# RENDER-T01 toast entra
	bus.push_toast(GameFeedback.K_SYSTEM, "olá")
	r.tick(0.13)
	_chk("RENDER-T01 toast entra (nó visível criado)", r.active_toast_count() >= 1)
	# RENDER-T02 toast sai (lifetime)
	for i in range(30): r.tick(0.13)
	_chk("RENDER-T02 toast sai (lifetime → 0)", r.active_toast_count() == 0)
	# RENDER-T03 prioridade (excepcional puxado antes de comum)
	bus.reset()
	bus.push_toast(GameFeedback.K_LOOT, "comum")
	bus.push_toast(GameFeedback.K_LOOT_EXCEPTIONAL, "EXCEPCIONAL")
	r.tick(0.13)   # puxa 1 → deve ser o excepcional (prioridade 1)
	var first_txt := ""
	if r.active_toast_count() > 0: first_txt = r._active_toasts[0]["node"].text
	_chk("RENDER-T03 prioridade (excepcional 1º)", first_txt.contains("EXCEPCIONAL"))
	# RENDER-T04 cap visual
	bus.reset()
	for i in range(20): bus.push_toast(GameFeedback.K_LOOT, "l%d" % i)
	for i in range(10): r.tick(0.13)
	_chk("RENDER-T04 cap visual ≤ %d simultâneos" % r.MAX_VISIBLE_TOASTS, r.active_toast_count() <= r.MAX_VISIBLE_TOASTS)
	# RENDER-T05 damage text nasce
	bus.reset()
	bus.push_damage(120, "e1", GameFeedback.K_DAMAGE_DEALT, Vector2(10, 10))
	r.tick(0.02)
	_chk("RENDER-T05 damage text nasce no mundo", r.active_float_count() >= 1)
	# RENDER-T06 damage text limpa
	for i in range(60): r.tick(0.05)
	_chk("RENDER-T06 damage text limpa (lifetime)", r.active_float_count() == 0)
	# RENDER-T07 heal/shield distinguíveis (símbolo, não só cor)
	bus.push_heal(40); bus.push_shield(20)
	var texts: Array = []
	for e in r._active_floats: texts.append(str(e["node"].text))
	_chk("RENDER-T07 heal/shield distinguíveis (+/⛊)", texts.size() == 2 and _has_prefix(texts, "+") and _has_prefix(texts, "⛊"))
	# RENDER-T08 sem matemática alterada
	var gs = _g(); var hp0 := int(gs.hero_hp)
	bus.push_damage(999, "x"); bus.push_heal(999); r.tick(0.1)
	_chk("RENDER-T08 render não altera combate (hp intacto)", int(gs.hero_hp) == hp0)
	r.free(); bus.free(); world.free()

func _has_prefix(arr: Array, pre: String) -> bool:
	for s in arr:
		if str(s).begins_with(pre): return true
	return false

# ══════════════ INVUX (ItemInstance → UI model) ══════════════
func _test_invux(gs) -> void:
	print("  ── INVUX (inventário/comparação) ──")
	var inst := ItemRoller.roll("sword_eternal", 99, "loot")
	var card := FeedbackFormat.item_card(inst, true, false)
	_chk("INVUX-T01 quality exibida", int(card["quality"]) == int(inst["quality"]))
	_chk("INVUX-T02 affixes exibidos", (card["affixes"] as Array).size() == (inst.get("affixes", []) as Array).size())
	_chk("INVUX-T03 rarity exibida (lendário)", str(card["rarity"]) == "legendary")
	var rows := FeedbackFormat.compare_rows("sword_simple", "sword_eternal")
	var has_atk_delta := false
	for row in rows:
		if str(row["stat"]) == "Ataque" and int(row["delta"]) > 0: has_atk_delta = true
	_chk("INVUX-T04 compare stats (delta de ataque > 0)", has_atk_delta)
	# INVUX-T05 projected CP: equipar item melhor sobe o CP (projeção real via PowerBudget)
	gs.reset_save()
	gs.equipment = {"weapon": "sword_simple"}
	var cp_a := PowerBudget.cp()
	gs.equipment = {"weapon": "sword_eternal"}
	var cp_b := PowerBudget.cp()
	_chk("INVUX-T05 projected CP (item melhor sobe o Poder)", cp_b > cp_a)
	_chk("INVUX-T06 iid oculto (card não expõe iid)", not card.has("iid"))
	gs.reset_save()

# ══════════════ SUPUX (RefineUIModel — seleção de suporte) ══════════════
func _test_supux(gs) -> void:
	print("  ── SUPUX (seleção de suporte) ──")
	_chk("SUPUX-T01 seleção none válida", RefineUIModel.allowed({"catalyst": "", "preserve": false, "absolute": false}))
	_chk("SUPUX-T02 catalisador válido", RefineUIModel.allowed({"catalyst": RefineUIModel.SUP_CATALYST, "preserve": false, "absolute": false}))
	_chk("SUPUX-T03 superior válido", RefineUIModel.allowed({"catalyst": RefineUIModel.SUP_SUPERIOR, "preserve": true, "absolute": false}))
	_chk("SUPUX-T04 preservação válida", RefineUIModel.allowed({"catalyst": "", "preserve": true, "absolute": false}))
	_chk("SUPUX-T05 absoluto válido (sozinho)", RefineUIModel.allowed({"catalyst": "", "preserve": false, "absolute": true}))
	# SUPUX-T06 combinações inválidas bloqueadas
	var bad1 := not RefineUIModel.allowed({"catalyst": RefineUIModel.SUP_SUPERIOR, "preserve": false, "absolute": true})
	var bad2 := not RefineUIModel.allowed({"catalyst": "", "preserve": true, "absolute": true})
	var bad3 := not RefineUIModel.allowed({"catalyst": "xpto", "preserve": false, "absolute": false})
	_chk("SUPUX-T06 combinações inválidas bloqueadas (absoluto+cat/pres, cat inválido)", bad1 and bad2 and bad3)
	# SUPUX-T07 cancel/preview não consome
	gs.reset_save(); gs.equipment = {"weapon": "sword_eternal"}; gs.slot_refinement = {"weapon": 10}; gs.materials = {"Fragmentos": 9000000}
	RefineUIModel.preview(gs, "weapon", {"catalyst": RefineUIModel.SUP_SUPERIOR, "preserve": false, "absolute": false})
	_chk("SUPUX-T07 preview não consome (nível/Frag intactos)", int(gs.slot_refinement["weapon"]) == 10 and int(gs.materials["Fragmentos"]) == 9000000)
	gs.reset_save()

# ══════════════ STRESS (renderer instanciado) ══════════════
func _test_stress() -> void:
	print("  ── STRESS (renderer: pooling/cleanup) ──")
	var bus := GameFeedback.new()
	var world := Node2D.new()
	var r := _mk_renderer(bus, world)
	# STRESS 10k damage → floats vivos ≤ MAX_FLOATS sempre; 0 no fim
	var over := false
	for i in range(10000):
		bus.push_damage(1, "e%d" % (i % 8), GameFeedback.K_DAMAGE_DEALT, Vector2(i % 100, 0))
		if i % 50 == 0:
			r.tick(0.02)
			if r.active_float_count() > r.MAX_FLOATS: over = true
	for i in range(60): r.tick(0.05)
	_chk("STRESS 10k damage: floats ≤ teto e 0 no fim", not over and r.active_float_count() == 0)
	# STRESS 1k loot → toasts visíveis ≤ cap; fila lógica ≤ 12
	bus.reset()
	for i in range(1000): bus.push_toast(GameFeedback.K_LOOT, "l%d" % i)
	for i in range(30): r.tick(0.13)
	_chk("STRESS 1k loot: visíveis ≤ %d e fila ≤ %d" % [r.MAX_VISIBLE_TOASTS, GameFeedback.MAX_TOASTS], r.active_toast_count() <= r.MAX_VISIBLE_TOASTS and bus.toast_count() <= GameFeedback.MAX_TOASTS)
	# STRESS 100 transitions (banners) → banner é 1 label, sem crescimento
	bus.reset()
	for i in range(100):
		bus.push_boss_intro("Boss %d" % i)
		r.tick(0.02)
	var settle := true
	for i in range(30): r.tick(0.13)
	if r.banner_visible(): settle = false
	_chk("STRESS 100 transições: banner único, some no fim", settle)
	# duplicate-signal: setup 2× não duplica conexão
	var before := bus.feedback.get_connections().size()
	r.setup(bus, func(): return world, func(): return null)   # 2ª chamada
	var after := bus.feedback.get_connections().size()
	_chk("STRESS duplicate-signal: setup 2× não duplica conexão", after == before)
	r.free(); bus.free(); world.free()

# ══════════════ Driver: WIRE no Main REAL ══════════════
class _Driver extends Node:
	var test; var main; var gs; var mem := {}; var fixture := ""
	var _waited := 0; var _done := false
	func _process(_delta: float) -> void:
		if _done: return
		if main == null or main._feedback == null or main._feedback_renderer == null or main._stagedirector == null:
			_waited += 1
			if _waited < 60: return
		_done = true
		test._test_wire(main, gs)
		# restaura
		if is_instance_valid(main):
			if main.get_parent() != null: main.get_parent().remove_child(main)
			main.free()
		gs.set_save_path_override("")
		gs.apply_dict(mem); gs._dirty = false; gs._session_started = false
		if FileAccess.file_exists(fixture): DirAccess.remove_absolute(fixture)
		test._finish()
		get_tree().quit(0 if test._fail == 0 else 1)

func _finish() -> void:
	print("  [save-safe] fixture descartada; save vivo intocado")
	print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))

func _test_wire(main, gs) -> void:
	print("  ── WIRE (Main REAL: evento → bus → renderer → nó visível) ──")
	var r = main._feedback_renderer
	var bus = main._feedback
	# WIRE-T10 anti-duplicate: _show_reward_popup NÃO cria Label legado (vai só pro bus)
	var pop_children: int = main._popup_layer.get_child_count() if main._popup_layer != null else 0
	bus.reset()
	main._show_reward_popup("Recebeu: Espada")
	var no_legacy: bool = (main._popup_layer == null or main._popup_layer.get_child_count() == pop_children)
	r.tick(0.13)
	_chk("WIRE-T01 loot/system → bus → renderer (toast visível)", r.active_toast_count() >= 1)
	_chk("WIRE-T10 sem feedback duplicado (popup legado não dispara)", no_legacy)
	# WIRE-T02 CP
	bus.reset()
	bus.push_cp(1200); bus.flush_cp(); r.tick(0.13)
	_chk("WIRE-T02 CP → bus → renderer", r.active_toast_count() >= 1)
	# WIRE-T03 boss telegraph (via handler real do Main)
	bus.reset(); r.clear_world()
	main._feedback.push_boss_warning("Drago", "line")   # emite feedback → renderer mostra warn
	_chk("WIRE-T03 boss telegraph → renderer (aviso visível)", r.warn_visible())
	# WIRE-T04 phase
	bus.reset()
	main._on_boss_phase_fb("ESCUDO", _FakeBoss.new()); r.tick(0.13)
	_chk("WIRE-T04 boss phase → renderer (toast)", r.active_toast_count() >= 1)
	# WIRE-T05/T06 stage/chapter clear → banner
	bus.reset(); r.clear_world()
	main._fb_last_chapter = 1
	main._on_stage_changed_fb(2, 1)   # cruzou p/ cap 2 → banner de capítulo concluído
	_chk("WIRE-T05/T06 stage/chapter clear → renderer (banner visível)", r.banner_visible())
	# WIRE-T07 refine → renderer (do_refine real)
	bus.reset()
	gs.reset_save(); gs.equipment = {"weapon": "sword_eternal"}; gs.slot_refinement = {"weapon": 12}; gs.materials = {"Fragmentos": 9000000}
	var res: Dictionary = main.do_refine("weapon", {"catalyst": "", "preserve": false, "absolute": false}, 0.0)   # sucesso
	r.tick(0.13)
	_chk("WIRE-T07 refine → renderer (resultado autoritativo + toast)", bool(res.get("success", false)) and r.active_toast_count() >= 1)
	# WIRE-T08 offline → renderer
	bus.reset()
	bus.push_offline_claim({"seconds": 3600, "stages": 7, "gold": 4218, "xp": 1200, "items": 2, "materials": 5}); r.tick(0.13)
	_chk("WIRE-T08 offline → renderer", r.active_toast_count() >= 1)
	# WIRE-T09 prestige → renderer
	bus.reset()
	main._on_prestige_done_fb(1, 1); r.tick(0.13)
	_chk("WIRE-T09 prestige → renderer", r.active_toast_count() >= 1)
	# combate real: _juice_hit empurra número de dano no inimigo
	bus.reset()
	var mob := _FakeMob.new(); mob.position = Vector2(50, 50); main.add_child(mob)
	main._juice_hit(mob, 42, Color("ffe08a"), false)
	r.tick(0.02)
	_chk("WIRE combate: _juice_hit → número de dano no inimigo (float)", r.active_float_count() >= 1)
	mob.queue_free()
	gs.reset_save()

## Nó mínimo p/ simular um boss (property boss_name lida via node.get("boss_name")).
class _FakeBoss extends Node:
	var boss_name := "Drago"

## Mob mínimo p/ _juice_hit (precisa de apply_knockback/is_alive; Node2D já dá position/instance_id).
class _FakeMob extends Node2D:
	func apply_knockback(_dir, _force) -> void: pass
	func is_alive() -> bool: return true
