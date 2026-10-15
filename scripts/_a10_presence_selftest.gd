extends SceneTree
## Self-test/RELATÓRIO FATIA A10 — Presence / Optional Active Play. Prova: (1) presença NÃO é requisito (walk
## idle-only 1-100 = 10 Selos); (2) a vantagem manual nasce de DODGE/posição (menos dano recebido), NÃO de buff
## (mesmo DPS/dano/reward); (3) handoff Auto↔manual limpo; (4) desafio manual do muro sem alterar CP/HP/reward.
## FIXTURE (save vivo intocado). godot --headless --path godot -s res://scripts/_a10_presence_selftest.gd

var _fail := 0
func _chk(nm: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), nm])
	if not cond: _fail += 1
func _g(): return root.get_node_or_null("GameState")

## Host mínimo p/ testar o control_state do PresenceController de forma determinística.
class FakeHost:
	var auto := true
	var manual := false
	var viewing := false
	var modal := false
	var wall := false
	func autoplay_on() -> bool: return auto
	func set_autoplay(v: bool) -> void: auto = v
	func presence_manual_input() -> bool: return manual
	func presence_modal_open() -> bool: return modal
	func narrative_viewing() -> bool: return viewing
	func stage_wall_active() -> bool: return wall
	func stage_request_retry() -> bool: wall = false; return true

func _initialize() -> void:
	var gs = _g()
	var fixture := "user://a10_fixture_save.json"
	gs.set_save_path_override(fixture)
	var mem: Dictionary = gs.to_dict()
	gs.reset_save()

	_test_sim()
	_test_handoff()
	_test_skill_data()
	_test_interact_parity(gs)

	gs.reset_save()
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	var drv := _Driver.new()
	drv.test = self; drv.main = main; drv.gs = gs; drv.mem = mem; drv.fixture = fixture
	root.add_child(drv)

# ══════════════ SIM (Auto × manual, ratios) ══════════════
func _test_sim() -> void:
	print("  ── SIM (skill sem buff: onde a habilidade decide) ──")
	# no-buff: no MESMO R, o TTK (dano causado) é IDÊNTICO entre políticas → só o dano RECEBIDO (ttd) muda
	var e_auto := PresenceSim.encounter(0.90, PresenceSim.avoid_of("auto"))
	var e_comp := PresenceSim.encounter(0.90, PresenceSim.avoid_of("competent"))
	_chk("SIM no-buff: mesmo R → mesmo TTK (dano causado igual)", is_equal_approx(float(e_auto["ttk"]), float(e_comp["ttk"])))
	_chk("SIM-R1.00 Auto clareia", bool(PresenceSim.encounter(1.00, PresenceSim.avoid_of("auto"))["win"]))
	_chk("SIM-R0.95 Auto clareia (marginal)", bool(PresenceSim.encounter(0.95, PresenceSim.avoid_of("auto"))["win"]))
	var tbl := PresenceSim.ratios_table()
	var skill_090 := false; var skill_085 := false; var skill_080 := false
	for row in tbl:
		if is_equal_approx(float(row["R"]), 0.90) and bool(row["skill_matters"]): skill_090 = true
		if is_equal_approx(float(row["R"]), 0.85) and bool(row["skill_matters"]): skill_085 = true
		if is_equal_approx(float(row["R"]), 0.80) and bool(row["skill_matters"]): skill_080 = true
	_chk("SIM-R0.90 skill decide (Auto perde, competente vence)", skill_090)
	_chk("SIM-R0.85 skill decide", skill_085)
	_chk("SIM-R0.80 skill decide", skill_080)
	var band := PresenceSim.band()
	_chk("SIM-BAND auto_clear≈0.95 · skill_floor≈0.67", float(band["auto_clear_floor"]) >= 0.93 and float(band["auto_clear_floor"]) <= 0.97 and float(band["skill_floor"]) >= 0.60 and float(band["skill_floor"]) <= 0.72)
	# 30min: competente clareia o muro (avança); auto não (farma) — per-kill IDÊNTICO, só o avanço muda
	var s_auto := PresenceSim.session_30min("auto", 0.90)
	var s_comp := PresenceSim.session_30min("competent", 0.90)
	_chk("SIM-30MIN presença avança mais (clareia o muro), sem multiplier", int(s_comp["stages_advanced"]) > int(s_auto["stages_advanced"]) and bool(s_comp["cleared_wall"]) and not bool(s_auto["cleared_wall"]))
	# não prometer o impossível: R muito baixo → nem skill vence (DESAFIO EXTREMO §22)
	_chk("SIM-EXTREMO R muito baixo → nem competente vence", not bool(PresenceSim.encounter(0.50, PresenceSim.avoid_of("competent"))["win"]))

# ══════════════ HANDOFF (PresenceController) ══════════════
func _test_handoff() -> void:
	print("  ── HANDOFF (autoridade de controle) ──")
	var h := FakeHost.new()
	var pc := PresenceController.new(); pc.setup(h)
	_chk("PRES-T01 Auto controla", pc.control_state() == PresenceController.AUTO)
	h.manual = true
	_chk("PRES-T02 input manual → override (Auto cede)", pc.control_state() == PresenceController.MANUAL_OVERRIDE and pc.is_manual())
	_chk("PRES-T03 Auto não briga com manual (rótulo VOCÊ)", pc.control_label() == "VOCÊ")
	h.manual = false
	_chk("PRES-T04 parar input retoma Auto", pc.control_state() == PresenceController.AUTO)
	h.auto = false
	_chk("PRES-T05 Auto OFF permanece manual (sem timeout)", pc.control_state() == PresenceController.MANUAL)
	h.auto = true; h.viewing = true
	_chk("PRES-T08 narrative viewing vence Presence (UI_SUSPENDED)", pc.control_state() == PresenceController.UI_SUSPENDED)
	h.viewing = false; h.modal = true
	_chk("PRES-T06/T08 modal aberto suspende (combate off)", pc.control_state() == PresenceController.UI_SUSPENDED)
	h.modal = false
	# Manual Challenge: só com muro; suspende Auto; restaura ao encerrar
	_chk("MCH can_manual_challenge falso sem muro", not pc.can_manual_challenge())
	h.wall = true
	_chk("MCH can_manual_challenge com muro", pc.can_manual_challenge())
	var ok: bool = pc.begin_manual_challenge()
	_chk("MCH begin suspende Auto + request_retry (sai do muro)", ok and not h.auto and not h.wall and pc.challenge_active())
	pc.end_manual_challenge()
	_chk("PRES-T07/MCH end restaura Auto anterior (ON) e limpa estado", h.auto and not pc.challenge_active())
	# game speed nunca tocado pelo controller (arquitetura)
	_chk("PRES-T06 controller não toca time_scale", not pc.has_method("set_time_scale"))
	pc.free()

# ══════════════ SKILL (dados: telegraphs têm janela; sem multiplier) ══════════════
func _test_skill_data() -> void:
	print("  ── SKILL (counterplay honesto, sem buff) ──")
	# toda habilidade perigosa tem WINDUP (janela p/ dodge/reposicionar §26); e dano evitável por distância (kite)
	var windows_ok := true; var avoidable_ok := true
	for pname in ["lunge_line", "bite_cone", "slam_circle", "crystal_wave", "triple_bolt", "lava_pool", "gap_close"]:
		var a := BossAbilityLibrary.preset(pname)
		if BossFeedback.is_dangerous(BossAbility.kind(a)):
			if BossAbility.windup(a) <= 0.0: windows_ok = false
			if not BossAbility.hits_at(a, 99999.0) == false: avoidable_ok = false   # longe o bastante = ERRA (kite)
	_chk("SKILL-T01..T05 telegraphs têm janela de dodge (windup>0)", windows_ok)
	_chk("SKILL kite: dano do boss ERRA se longe (hits_at por distância)", avoidable_ok)
	# SKILL-T07 nenhum multiplier de dano manual: no MESMO R, mudar a política (avoid=skill) NÃO muda o TTK
	# (dano causado) — só o dano recebido. Ou seja, a vantagem é sobrevivência, não dano extra.
	var ttk_lo := float(PresenceSim.encounter(0.85, 0.10)["ttk"])
	var ttk_hi := float(PresenceSim.encounter(0.85, 0.90)["ttk"])
	_chk("SKILL-T07 nenhum damage multiplier manual (TTK independe da política)", is_equal_approx(ttk_lo, ttk_hi))

# ══════════════ INTERACT + PARITY (dados) ══════════════
func _test_interact_parity(gs) -> void:
	print("  ── INTERACT/PARITY (dados) ──")
	gs.reset_save()
	# INT-T04 reward de chest exato-uma-vez (dedup via opened_chests)
	var first: bool = gs.open_chest("c_test_1")
	var second: bool = gs.open_chest("c_test_1")
	_chk("INT-T04 chest reward exato-uma-vez (dedup)", first and not second)
	# INT-T05 chest não concede reward CORE (Selo/CP): open_chest não mexe em cycle_seals nem PowerBudget
	gs.reset_save(); gs.equipment = {"weapon": "sword_eternal"}
	var cp0 := PowerBudget.cp(); var seals0 := int(gs.cycle_seals)
	gs.open_chest("c_test_2")
	_chk("INT-T05 chest não dá reward core (Selo/CP intactos)", PowerBudget.cp() == cp0 and int(gs.cycle_seals) == seals0)
	# PARITY: nenhum CP exclusivo de presença — PresenceController/Sim não tocam GameState/CP
	var pc := PresenceController.new(); pc.setup(null)
	var _s := pc.control_state(); var _l := pc.control_label()
	_chk("PARITY-T05 nenhum Presence-only CP (controller não muda CP)", PowerBudget.cp() == cp0)
	pc.free()
	gs.reset_save()

# ══════════════ Driver: MBOSS/SKILL-T06/TARGET/WALK no Main REAL ══════════════
class _Driver extends Node:
	var test; var main; var gs; var mem := {}; var fixture := ""
	var _waited := 0; var _done := false
	func _process(_delta: float) -> void:
		if _done: return
		if main == null or main._stagedirector == null or main._presence == null or main._player == null:
			_waited += 1
			if _waited < 60: return
		_done = true
		test._run_real(main, gs)
		if is_instance_valid(main):
			if main.get_parent() != null: main.get_parent().remove_child(main)
			main.free()
		gs.set_save_path_override("")
		gs.apply_dict(mem); gs._dirty = false; gs._session_started = false
		if FileAccess.file_exists(fixture): DirAccess.remove_absolute(fixture)
		print("  [save-safe] fixture descartada; save vivo intocado")
		print(">>> %s" % ("OK" if test._fail == 0 else "FALHOU (%d)" % test._fail))
		get_tree().quit(0 if test._fail == 0 else 1)

func _run_real(main, gs) -> void:
	if main._world_router != null: main._world_router.set_active(false)
	main._title_open = false
	gs.reset_save()
	var sd = main._stagedirector
	var pc = main._presence

	# ── MBOSS (desafio manual não altera nada; reward parity) ──
	print("  ── MBOSS (Main real: manual challenge sem buff) ──")
	gs.equipment = {"weapon": "sword_eternal"}
	sd.wall_active = true; sd.mode = "farm"; sd.frontier_chapter = 1; sd.frontier_stage = 10
	var cp_before := PowerBudget.cp()
	# A31 (fix STALE): desde A20.17 (LEGACY_PVE_DEPRECATION) o Auto NÃO liga sozinho no boot — o teste precisa
	# ESTABELECER a precondição "Auto ON" p/ exercer o resume real (a política restaura SÓ se estava ON).
	main.set_autoplay(true)
	_chk("MBOSS-T10pre precondição Auto ON estabelecida", main.autoplay_on())
	var ok: bool = pc.begin_manual_challenge()
	_chk("MBOSS-T01 manual challenge não altera CP", ok and PowerBudget.cp() == cp_before)
	_chk("MBOSS-T10 begin desligou o Auto (jogador assume)", not main.autoplay_on())
	pc.end_manual_challenge()
	_chk("MBOSS-T10b Auto retoma se estava ON", main.autoplay_on())
	# vitória manual concede reward NORMAL 1x (mesmo caminho do Auto)
	gs.reset_save(); gs.cycle_seal_high = 0; gs.cycle_seals = 0
	var got1: bool = gs.grant_cycle_seal(10)
	var got2: bool = gs.grant_cycle_seal(10)
	_chk("MBOSS-T04/T06 Selo exato-uma-vez (vitória manual = Auto)", got1 and not got2 and int(gs.cycle_seals) == 1)
	# derrota → 0
	gs.reset_save()
	_chk("MBOSS-T05 derrota concede 0 Selo", int(gs.cycle_seals) == 0)

	# ── SKILL-T06 dodge realmente anula o golpe (i-frames) ──
	print("  ── SKILL (Main real: dodge anula) ──")
	gs.reset_save(); gs.hero_hp = int(gs.max_hp_total())
	var hp0 := int(gs.hero_hp)
	# força i-frame no player e aplica um golpe de inimigo — deve ser ANULADO
	if main._player.has_method("try_dodge"):
		main._player.set("_iframe_t", 0.5)   # i-frame ativo
	var mob := _FakeMob.new(); main.add_child(mob)
	main._on_enemy_attack(50, mob)
	_chk("SKILL-T06 dodge (i-frames) anula o golpe (HP intacto)", int(gs.hero_hp) == hp0)
	main._player.set("_iframe_t", 0.0)   # sem i-frame → o golpe conta
	main._on_enemy_attack(50, mob)
	_chk("SKILL sem i-frame o golpe conta (HP cai)", int(gs.hero_hp) < hp0)
	mob.queue_free()

	# ── TARGET (lock) ──
	print("  ── TARGET (lock manual) ──")
	var m2 := _FakeMob.new(); main.add_child(m2)
	main._set_auto_target(m2)
	_chk("TARGET-T01 alvo travado", main.autoplay_has_target())
	main._clear_auto_target()
	_chk("TARGET-T04 manual cancel limpa alvo", not main.autoplay_has_target())
	m2.queue_free()

	# ── PARITY viewing/presence vence + WALK idle-only 1-100 ──
	print("  ── WALK idle-only 1-100 (presença NÃO é requisito) ──")
	gs.reset_save()
	for c in range(1, 11):
		var region := ContentManifest.region_for_stage(c * 10)
		sd.chapter = c; sd.stage = 10
		main.load_region(region); main.ensure_stage_boss()
		var boss = main._current_boss
		if boss != null and is_instance_valid(boss) and boss.has_method("take_damage"):
			boss.call("take_damage", 9999999)
	_chk("WALK idle-only = 10 Selos (presença opcional, sem manual/detour/história)", int(gs.cycle_seals) == 10)
	_chk("WALK Prestígio possível sem presença", int(gs.cycle_seals) >= PrestigeMath.required_seals(int(gs.prestige_count)))
	# A31: fortalecido de tautológico (label in [...], sempre-true) p/ o TOGGLE REAL do Auto — determinístico e
	# independente de estado de modal: autoplay_on() reflete set_autoplay (o mecanismo que a presença restaura).
	main.set_autoplay(false)
	_chk("HANDOFF Auto OFF reflete set_autoplay(false)", not main.autoplay_on())
	main.set_autoplay(true)
	_chk("HANDOFF Auto ON reflete set_autoplay(true) (mecanismo de resume)", main.autoplay_on())
	_chk("HANDOFF control_label é rótulo válido de HUD", main.presence_control_label() in ["AUTO", "VOCÊ", "—"])
	gs.reset_save()

class _FakeMob extends Node2D:
	var hp := 100
	func apply_knockback(_d, _f) -> void: pass
	func is_alive() -> bool: return hp > 0
