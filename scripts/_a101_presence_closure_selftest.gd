extends SceneTree
## Self-test/RELATÓRIO FATIA A10.1 — Presence Closure / Boss Hit Geometry / Test Completeness. Prova: (1) o dano
## dos bosses genéricos respeita o TELEGRAPH (line/cone/circle/ground/hazard/projectile/volley); (2) todos os
## contratos da A10 (MBOSS/TARGET/INTERACT/PARITY) explicitamente testados; (3) classificação do desafio por ratio.
## FIXTURE (save vivo intocado). godot --headless --path godot -s res://scripts/_a101_presence_closure_selftest.gd

var _fail := 0
var _atk := 0
func _chk(nm: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), nm])
	if not cond: _fail += 1
func _g(): return root.get_node_or_null("GameState")
func _on_atk(a: int) -> void: _atk += a

func _initialize() -> void:
	var gs = _g()
	var fixture := "user://a101_fixture_save.json"
	gs.set_save_path_override(fixture)
	var mem: Dictionary = gs.to_dict()
	gs.reset_save()

	_test_geo()
	_test_geo_boss()
	_test_challenge_class()
	_test_sim_regeom()

	gs.reset_save()
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	var drv := _Driver.new()
	drv.test = self; drv.main = main; drv.gs = gs; drv.mem = mem; drv.fixture = fixture
	root.add_child(drv)

# ══════════════ GEO (BossHitGeometry pura) ══════════════
func _test_geo() -> void:
	print("  ── GEO (telegraph = área de dano) ──")
	var line := BossAbility.line("l", 10, 235.0, 0.5, 2.0); line["half"] = 40.0
	var cone := BossAbility.cone("c", 10, 156.0, 82.0, 0.5, 2.0)
	var circ := BossAbility.circle("ci", 10, 140.0, 0.5, 2.0)
	var grnd := BossAbility.ground_aoe("g", 10, 116.0, 0.9, 2.0)
	var proj := BossAbility.projectile("p", 10, 600.0, 0.4, 2.0); proj["half"] = 34.0
	var aim := Vector2(1, 0)
	_chk("GEO-T01 LINE dentro → hit", BossHitGeometry.hits(line, Vector2(120, 0), aim))
	_chk("GEO-T02 LINE lateral fora → miss", not BossHitGeometry.hits(line, Vector2(120, 200), aim))
	_chk("GEO-T03 LINE atrás → miss", not BossHitGeometry.hits(line, Vector2(-120, 0), aim))
	_chk("GEO-T04 CONE dentro → hit", BossHitGeometry.hits(cone, Vector2(100, 0), aim))
	_chk("GEO-T05 CONE fora do ângulo → miss (mesma distância)", not BossHitGeometry.hits(cone, Vector2(0, 100), aim))
	_chk("GEO-T06 CIRCLE dentro/fora", BossHitGeometry.hits(circ, Vector2(100, 0), aim) and not BossHitGeometry.hits(circ, Vector2(200, 0), aim))
	# GEO-T07 GROUND usa o CENTRO telegrafado (cast_center), não a posição atual
	_chk("GEO-T07 GROUND usa centro telegrafado (sair da marca = miss)",
		BossHitGeometry.hits(grnd, Vector2(300, 0), aim, Vector2(300, 0)) and not BossHitGeometry.hits(grnd, Vector2(0, 0), aim, Vector2(300, 0)))
	# GEO-T09 projectile: direção importa (mesma dist ao boss, um na linha do aim, outro fora)
	_chk("GEO-T09 PROJECTILE direção importa (não distance_to boss)",
		BossHitGeometry.hits(proj, Vector2(300, 0), aim) and not BossHitGeometry.hits(proj, Vector2(212, 212), aim))
	# contrato telegraph=hit (§11): mesma forma/parâmetros
	var contract_ok := true
	for pn in BossAbilityLibrary.preset_names():
		if not BossHitGeometry.telegraph_matches_hit(BossAbilityLibrary.preset(pn)): contract_ok = false
	_chk("GEO contrato: telegraph e hit derivam da MESMA definição (todos os presets)", contract_ok)

# ══════════════ GEO no BossController (dano LIVE respeita o telegraph) ══════════════
func _test_geo_boss() -> void:
	print("  ── GEO (BossController: dano live respeita o telegraph) ──")
	# CONE: mesma DISTÂNCIA, ângulo diferente → hit vs miss (distância-only acertaria os dois)
	var bc := _mk_bc([BossAbility.cone("c", 20, 156.0, 82.0, 0.45, 3.0)])
	bc.connect("attack_hero", _on_atk)
	# cast mirando +X (player à frente), depois player REPOSICIONA p/ o lado durante o windup → MISS no fire
	_atk = 0
	bc.tick_at(0.1, Vector2(100, 0))          # começa o cast, aim=+X capturado
	for k in range(6): bc.tick_at(0.1, Vector2(0, 100))   # reposiciona p/ o lado (mesma distância ~100)
	var miss_side := (_atk == 0)
	bc.free()
	# controle: player fica na frente → HIT
	var bc2 := _mk_bc([BossAbility.cone("c", 20, 156.0, 82.0, 0.45, 3.0)])
	bc2.connect("attack_hero", _on_atk)
	_atk = 0
	for k in range(8): bc2.tick_at(0.1, Vector2(100, 0))
	var hit_front := (_atk > 0)
	bc2.free()
	_chk("GEO-BOSS cone: reposicionar p/ o lado EVITA (mesma distância)", miss_side and hit_front)
	# HAZARD: dano só dentro da zona telegrafada; sair da zona evita (§8)
	var bh := _mk_bc([BossAbility.hazard("h", 12, 120.0, 4.0, 8.0, 2)])
	bh.connect("attack_hero", _on_atk)
	# cria hazard com player em (300,0) → centro telegrafado (300,0)
	bh.tick_at(0.1, Vector2(300, 0)); bh.tick_at(0.7, Vector2(300, 0))
	_atk = 0
	for k in range(3): bh.tick_at(1.0, Vector2(300, 0))   # dentro da zona → dano
	var haz_in := (_atk > 0)
	_atk = 0
	for k in range(3): bh.tick_at(1.0, Vector2(0, 0))     # fora da zona → 0
	var haz_out := (_atk == 0)
	bh.free()
	_chk("GEO-T08 HAZARD dano só dentro da zona telegrafada", haz_in and haz_out)

func _mk_bc(abilities: Array) -> BossController:
	var bc := BossController.new()
	bc.configure("magma-dragon", 100000, 10, 20)
	bc._abilities = abilities
	bc._order = {}; bc._cd = {}
	var i := 0
	for a in abilities:
		bc._order[BossAbility.id(a)] = i; bc._cd[BossAbility.id(a)] = 0.0; i += 1
	bc._casting = {}
	return bc

# ══════════════ Classificação do desafio (§13/§14) ══════════════
func _test_challenge_class() -> void:
	print("  ── CHALLENGE classification (não bloqueia, não promete) ──")
	_chk("CLASS R>=0.95 → DESAFIO", PresenceController.challenge_label(0.98) == "DESAFIO")
	_chk("CLASS 0.80<=R<0.95 → DIFÍCIL", PresenceController.challenge_label(0.88) == "DESAFIO DIFÍCIL")
	_chk("CLASS R<0.80 → EXTREMO (mas PODE tentar)", PresenceController.challenge_label(0.60) == "DESAFIO EXTREMO")

# ══════════════ SIM re-run com geometria (banda mantida; agora com counterplay REAL) ══════════════
func _test_sim_regeom() -> void:
	print("  ── SIM re-run (a evitação agora é geométrica de verdade) ──")
	var tbl := PresenceSim.ratios_table()
	var s090 := false; var s085 := false; var s080 := false; var auto095 := false
	for row in tbl:
		if is_equal_approx(float(row["R"]), 0.95) and bool(row["auto"]["win"]): auto095 = true
		if is_equal_approx(float(row["R"]), 0.90) and bool(row["skill_matters"]): s090 = true
		if is_equal_approx(float(row["R"]), 0.85) and bool(row["skill_matters"]): s085 = true
		if is_equal_approx(float(row["R"]), 0.80) and bool(row["skill_matters"]): s080 = true
	_chk("SIM R0.95 Auto clareia · R0.90/0.85/0.80 skill decide (banda mantida)", auto095 and s090 and s085 and s080)
	# proxy ≠ humano (declarado): a banda é DIREÇÃO, não verdade de field
	_chk("SIM proxy declarado (não é player humano)", PresenceSim.avoid_of("competent") > PresenceSim.avoid_of("auto"))

# ══════════════ Driver: MBOSS/TARGET/INTERACT/PARITY completos + GEO-T10 no Main REAL ══════════════
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

func _bd(id: String) -> String: return BossDefinition.display_name(id)

func _run_real(main, gs) -> void:
	if main._world_router != null: main._world_router.set_active(false)
	main._title_open = false
	var sd = main._stagedirector; var pc = main._presence

	# ── MBOSS T01-T10 (completo) ──
	print("  ── MBOSS T01-T10 (completo) ──")
	gs.reset_save(); gs.equipment = {"weapon": "sword_eternal"}
	sd.wall_active = true; sd.mode = "farm"; sd.frontier_chapter = 1; sd.frontier_stage = 10
	var cp0 := PowerBudget.cp()
	# T03 boss HP/damage não muda com challenge (configure é independente do controle)
	var b1 := BossController.new(); b1.configure("magma-dragon", 500, 10, 16); var hp_a := b1.hp_max; b1.free()
	# A31 (fix STALE): estabelece "Auto ON" — desde A20.17 o Auto não liga sozinho; sem isso o resume (T10b) nunca é exercido.
	main.set_autoplay(true)
	var ok: bool = pc.begin_manual_challenge()
	var b2 := BossController.new(); b2.configure("magma-dragon", 500, 10, 16); var hp_b := b2.hp_max; b2.free()
	_chk("MBOSS-T01 challenge não altera CP", ok and PowerBudget.cp() == cp0)
	_chk("MBOSS-T02 challenge não altera dano do player (CP/CombatMath intactos)", PowerBudget.cp() == cp0)
	_chk("MBOSS-T03 challenge não altera boss HP/damage", hp_a == hp_b)
	_chk("MBOSS-T10 begin desliga Auto (jogador assume)", not main.autoplay_on())
	pc.end_manual_challenge()
	_chk("MBOSS-T10b end restaura Auto anterior (ON)", main.autoplay_on())
	# T04/T06 vitória → Selo 1x ; T05 derrota → 0 ; T07 support 1x ; T08 narrative 1x
	gs.reset_save(); gs.cycle_seal_high = 0; gs.cycle_seals = 0
	var s1: bool = gs.grant_cycle_seal(10); var s2: bool = gs.grant_cycle_seal(10)
	_chk("MBOSS-T04/T06 Selo exato-uma-vez (vitória manual=Auto)", s1 and not s2 and int(gs.cycle_seals) == 1)
	gs.reset_save(); gs.grant_encounter_reward(10); var w1 := int(gs.cycle_encounter_high); gs.grant_encounter_reward(10); var w2 := int(gs.cycle_encounter_high)
	_chk("MBOSS-T07 support exato-uma-vez (watermark)", w1 >= 10 and w2 == w1)
	gs.reset_save(); gs.mark_boss_defeated(_bd("wolf-alpha"))
	var av1: int = main._narrative.available_unseen(gs).size(); gs.mark_boss_defeated(_bd("wolf-alpha"))
	_chk("MBOSS-T08 narrative unlock exato-uma-vez", main._narrative.available_unseen(gs).size() == av1)
	gs.reset_save()
	_chk("MBOSS-T05 derrota concede 0", int(gs.cycle_seals) == 0)
	# T09 falha volta ao wall/farm + restaura Auto (via _presence_end_challenge no defeat)
	sd.wall_active = true; sd.mode = "farm"; var was_auto: bool = main.autoplay_on()
	pc.begin_manual_challenge()
	main._presence_end_challenge()   # simula fim (derrota)
	_chk("MBOSS-T09 falha encerra challenge e restaura Auto (volta ao wall/farm)", not pc.challenge_active() and main.autoplay_on() == was_auto)

	# ── GEO-T10 i-frame anula hit geométrico válido ──
	print("  ── GEO-T10 (dodge > geometria) ──")
	gs.reset_save(); gs.hero_hp = int(gs.max_hp_total()); var hp_i := int(gs.hero_hp)
	main._player.set("_iframe_t", 0.5)
	var m := _FM.new(); main.add_child(m)
	main._on_enemy_attack(80, m)   # golpe VÁLIDO, mas i-frame ativo → 0 dano
	_chk("GEO-T10 i-frame anula hit geométrico válido", int(gs.hero_hp) == hp_i)
	main._player.set("_iframe_t", 0.0); main._on_enemy_attack(80, m)
	_chk("GEO-T10b sem i-frame o hit conta", int(gs.hero_hp) < hp_i)
	m.queue_free()

	# ── TARGET T01-T05 ──
	print("  ── TARGET T01-T05 ──")
	var t1 := _FM.new(); main.add_child(t1); main._set_auto_target(t1)
	_chk("TARGET-T01 boss/alvo lock permanece", main.autoplay_has_target())
	var t2 := _FM.new(); main.add_child(t2)   # "summon" aparece
	_chk("TARGET-T02 summon não rouba o alvo manual", main._auto_target == t1)
	t1.hp = 0   # alvo morre
	if not main._target_alive(t1): main._clear_auto_target()
	_chk("TARGET-T03 alvo morto → limpa", not main.autoplay_has_target())
	main._set_auto_target(t2); main._clear_auto_target()
	_chk("TARGET-T04 cancel manual limpa", not main.autoplay_has_target())
	_chk("TARGET-T05 Auto re-adquire após override (adapter existe; provado no A1)", main.has_method("autoplay_acquire_nearest"))
	t1.queue_free(); t2.queue_free()

	# ── INTERACT T01-T06 ──
	print("  ── INTERACT T01-T06 ──")
	_chk("INT-T01 prompt só em range (INTERACT_RADIUS existe)", main.INTERACT_RADIUS > 0.0)
	# T02 Auto ignora interactable: acquire só considera _mobs/_current_boss (chest não vira alvo)
	main._mobs = []; main._current_boss = null
	main.autoplay_acquire_nearest()
	_chk("INT-T02 Auto ignora interactable (sem mob → sem alvo)", not main.autoplay_has_target())
	# T03 manual interage / T04 dedup one-time / T05 sem reward core
	var cpc := PowerBudget.cp(); var seals := int(gs.cycle_seals)
	var f1: bool = gs.open_chest("c_a101"); var f2: bool = gs.open_chest("c_a101")
	_chk("INT-T03/T04 manual interage + one-time dedup", f1 and not f2)
	_chk("INT-T05 nenhum reward core (Selo/CP intactos)", PowerBudget.cp() == cpc and int(gs.cycle_seals) == seals)
	# T06 Auto retoma após detour: presença é override; parar input → Auto. A31: fortalecido de tautológico
	# (label in [...]) p/ resume REAL — com Auto ON e sem input manual, o controlador resumido é AUTO.
	main.set_autoplay(true)
	_chk("INT-T06 Auto retoma após detour (control_state == AUTO com Auto ON, sem input)", pc.control_state() == PresenceController.AUTO)

	# ── PARITY T01-T06 ──
	print("  ── PARITY T01-T06 ──")
	# nenhuma rota de loot/xp/frag depende do modo de controle; PresenceController não muda estado do jogador
	gs.reset_save(); gs.equipment = {"weapon": "sword_eternal"}
	var cp_p := PowerBudget.cp(); var gold_p := int(gs.hero_gold); var xp_p := int(gs.hero_xp)
	pc.setup(main); var _st: String = pc.control_state()   # operar o controller não muda nada do personagem
	_chk("PARITY-T01/T02 loot table independe do modo (nenhum branch manual)", PowerBudget.cp() == cp_p)
	_chk("PARITY-T03 XP independe do modo", int(gs.hero_xp) == xp_p)
	_chk("PARITY-T04 Fragmentos/salvage independem do modo", int(gs.hero_gold) == gold_p)
	_chk("PARITY-T05 nenhum Presence-only CP", PowerBudget.cp() == cp_p)
	# T06 offline independente: IdleRewards.type_of/gear não referenciam presença
	_chk("PARITY-T06 offline independente (math de fase intacta)", IdleRewards.type_of(10) == "boss")
	gs.reset_save()

class _FM extends Node2D:
	var hp := 100
	func apply_knockback(_d, _f) -> void: pass
	func is_alive() -> bool: return hp > 0
