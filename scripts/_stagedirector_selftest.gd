extends SceneTree
## Self-test FATIA A2 — StageDirector (progressão automática por fases). Exercita a máquina de progressão
## com um HOST-MOCK (região + persistência em memória), dirigindo por EVENTOS DE MORTE (mockados, §32). Cobre
## A2-T01..T16 + a sequência longa 1-1 → 2-1 sem intervenção. Sem janela/render/combate real. Rodar:
##   godot --headless --path godot -s res://scripts/_stagedirector_selftest.gd

## Host-mock: região controlável + persistência em memória (imita GameState.set_stage_progress / save).
class MockHost:
	var region := "plains"
	var saved := {"chapter": 1, "stage": 1, "stage_kills": 0, "highest_global": 1}
	func stagedirector_region_id() -> String: return region
	func stagedirector_load() -> Dictionary: return saved.duplicate()
	func stagedirector_persist(c: int, s: int, k: int, hg: int) -> void:
		saved = {"chapter": c, "stage": s, "stage_kills": k, "highest_global": hg}

var _fail := 0
func _chk(name: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), name])
	if not cond: _fail += 1

## Mata N mobs normais VÁLIDOS (young_wolf) com dedup_keys únicos, avançando o timer de transição entre fases.
func _kill_normal(sd, n: int) -> void:
	for i in range(n):
		sd.notify_kill("young_wolf", false, "n%d_%d_%d" % [sd.chapter, sd.stage, i])

## Avança o cronômetro de transição (0.6s) além do limite.
func _pass_transition(sd) -> void:
	sd.tick(1.0)

func _initialize() -> void:
	var SD := load("res://scripts/StageDirector.gd")

	# ════════ BLOCO 1 — start / contagem / transição / kill inválida / dupla contagem ════════
	var h := MockHost.new()
	var sd = SD.new(); root.add_child(sd); sd.setup(h)

	# A2-T01: start em 1-1, contador 0, tipo normal, RUNNING
	_chk("T01 start 1-1, kills=0, RUNNING", sd.stage_label() == "1-1" and sd.stage_kills == 0 and sd.get_state() == sd.St.RUNNING)

	# A2-T02: 19 kills → continua 1-1 (cota 1-1 = 20); 20ª completa (→ TRANSITIONING)
	_kill_normal(sd, 19)
	_chk("T02a 19 kills → ainda 1-1 (19/20)", sd.stage_label() == "1-1" and sd.stage_kills == 19)
	sd.notify_kill("young_wolf", false, "n_close")
	_chk("T02b 20ª kill → completa 1-1 (TRANSITIONING)", sd.get_state() == sd.St.TRANSITIONING)

	# A2-T03: transição 1-1 → 1-2 (após o delay)
	_pass_transition(sd)
	_chk("T03 transição 1-1 -> 1-2", sd.stage_label() == "1-2" and sd.stage_kills == 0 and sd.get_state() == sd.St.RUNNING)

	# A2-T04: kill INVÁLIDA (boss durante fase normal) NÃO conta
	var k_before: int = sd.stage_kills
	sd.notify_kill("lobo alfa", true, "")   # boss numa fase normal → inválido
	_chk("T04 kill inválida (boss em fase normal) não conta", sd.stage_kills == k_before)

	# A2-T05: dupla contagem — mesmo dedup_key 2× conta 1×
	var k2: int = sd.stage_kills
	sd.notify_kill("young_wolf", false, "dup_key")
	sd.notify_kill("young_wolf", false, "dup_key")   # repetida → ignorada
	_chk("T05 dupla contagem (mesma morte) conta 1×", sd.stage_kills == k2 + 1)

	# ════════ BLOCO 2 — mini-boss (fase 5) ════════
	# leva de 1-2 até 1-5. 1-2 cota=24, 1-3=26, 1-4=30, chega em 1-5 (miniboss).
	# completa a fase atual (1-2) e avança até 1-5.
	_kill_normal(sd, sd.stage_quota() - sd.stage_kills); _pass_transition(sd)   # 1-2 → 1-3
	_kill_normal(sd, sd.stage_quota()); _pass_transition(sd)                    # 1-3 → 1-4
	_kill_normal(sd, sd.stage_quota()); _pass_transition(sd)                    # 1-4 → 1-5
	# A2-T06: fase 5 é mini-boss (BOSS_STAGE), tipo miniboss
	_chk("T06 fase 1-5 é mini-boss", sd.stage_label() == "1-5" and sd.stage_type() == sd.T_MINIBOSS and sd.get_state() == sd.St.BOSS_STAGE)

	# A2-T07: mobs normais na fase 5 NÃO concluem o encontro de mini-boss
	sd.notify_kill("young_wolf", false, "mm1")
	sd.notify_kill("wild_boar", false, "mm2")
	_chk("T07 mobs normais não fecham mini-boss", sd.stage_label() == "1-5" and sd.get_state() == sd.St.BOSS_STAGE)

	# A2-T08: matar o ELITE designado (road_bandit) → completa 1-5 → 1-6
	sd.notify_kill("road_bandit", false, "elite1")
	_pass_transition(sd)
	_chk("T08 morte do mini-boss → 1-5 -> 1-6", sd.stage_label() == "1-6" and sd.get_state() == sd.St.RUNNING)

	# ════════ BLOCO 3 — boss (fase 10) + capítulo completa ════════
	# 1-6 → 1-10: completa 6,7,8,9 (cotas normais) então entra 1-10 (boss)
	for _i in range(4):
		_kill_normal(sd, sd.stage_quota()); _pass_transition(sd)
	# A2-T09: fase 10 é boss
	_chk("T09 fase 1-10 é boss", sd.stage_label() == "1-10" and sd.stage_type() == sd.T_BOSS and sd.get_state() == sd.St.BOSS_STAGE)

	# mobs normais não fecham o boss
	sd.notify_kill("young_wolf", false, "bm1")
	_chk("T09b mob normal não fecha boss", sd.stage_label() == "1-10")

	# A2-T10: morte do BOSS (is_boss) → capítulo 1 completa → 2-1
	sd.notify_kill("lobo alfa", true, "")
	_pass_transition(sd)
	_chk("T10 morte do boss → 1-10 -> 2-1 (cap. 2)", sd.stage_label() == "2-1" and sd.chapter == 2 and sd.stage == 1 and sd.get_state() == sd.St.RUNNING)

	# highest_global preservado no save
	_chk("T10b highest_global >= 11 persistido", h.saved.get("highest_global", 0) >= 11)

	sd.free()

	# ════════ BLOCO 4 — SAVE/LOAD + save antigo ════════
	# A2-T11: save/load restaura a fase e o contador
	var h2 := MockHost.new()
	h2.saved = {"chapter": 3, "stage": 7, "stage_kills": 5, "highest_global": 26}
	var sd2 = SD.new(); root.add_child(sd2); sd2.setup(h2)
	_chk("T11 save/load restaura 3-7 kills=5", sd2.stage_label() == "3-7" and sd2.stage_kills == 5)
	sd2.free()

	# A2-T12: save ANTIGO (sem campos de stage) → começa 1-1 sem erro
	var h3 := MockHost.new()
	h3.saved = {}   # save antigo: nenhum campo de fase
	var sd3 = SD.new(); root.add_child(sd3); sd3.setup(h3)
	_chk("T12 save antigo (sem campos) → 1-1, sem erro", sd3.stage_label() == "1-1" and sd3.stage_kills == 0)

	# ════════ BLOCO 5 — troca de região / candidatos / robustez ════════
	# A2-T13: mudança de região reconciliada (dedup limpo, conteúdo re-resolvido) sem resetar a fase
	h3.region = "cave"
	sd3.notify_region_changed()
	_chk("T13 troca de região reconcilia sem resetar fase", sd3.stage_label() == "1-1" and sd3._region_id == "cave")
	# na Caverna, o pool normal é outro: green_slime conta
	sd3.notify_kill("green_slime", false, "cave1")
	_chk("T13b pool da caverna conta (green_slime)", sd3.stage_kills == 1)

	# A2-T15: WASD/manual não corrompe — matar manualmente um mob válido conta igual (a fonte é o evento de morte)
	sd3.notify_kill("crystal_bat", false, "manual_kill")
	_chk("T15 kill manual de mob válido conta", sd3.stage_kills == 2)

	# candidate_ok: na fase normal o boss NÃO é candidato; um mob é
	_chk("T14a candidate_ok: mob normal permitido", sd3.candidate_ok("green_slime", false) == true)
	_chk("T14b candidate_ok: boss NÃO mirado em fase normal", sd3.candidate_ok("golem de cristal", true) == false)

	# A2-T16: zero candidatos / região desconhecida (fallback genérico) não crasha
	h3.region = "regiao_inexistente_xyz"
	sd3.notify_region_changed()
	sd3.notify_kill("qualquer_mob", false, "fb1")   # fallback: pool vazio → qualquer não-boss conta
	_chk("T16 região desconhecida (fallback) não crasha e conta", sd3.stage_kills >= 1)
	sd3.free()

	# ════════ BLOCO 6 — SEQUÊNCIA LONGA 1-1 → 2-1 (prova a máquina inteira) ════════
	var h4 := MockHost.new()
	var sd4 = SD.new(); root.add_child(sd4); sd4.setup(h4)
	var seq: Array = []
	seq.append(sd4.stage_label())
	var guard := 0
	while sd4.stage_label() != "2-1" and guard < 5000:
		guard += 1
		match sd4.stage_type():
			sd4.T_MINIBOSS:
				sd4.notify_kill("road_bandit", false, "seq_e%d" % guard)
			sd4.T_BOSS:
				sd4.notify_kill("lobo alfa", true, "")
			_:
				_kill_normal(sd4, sd4.stage_quota())
		if sd4.get_state() == sd4.St.TRANSITIONING:
			_pass_transition(sd4)
			seq.append(sd4.stage_label())
	print("  sequência: %s" % str(seq))
	var expected := ["1-1", "1-2", "1-3", "1-4", "1-5", "1-6", "1-7", "1-8", "1-9", "1-10", "2-1"]
	_chk("SEQ 1-1 → 2-1 completa e em ordem", seq == expected)
	sd4.free()

	print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
	quit(0 if _fail == 0 else 1)
