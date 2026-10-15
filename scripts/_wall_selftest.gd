extends SceneTree
## Self-test FATIA A3 — MURO DE PROGRESSÃO (StageDirector). Prova WALL-T01..T14 + a simulação completa do
## muro (§39). Dirige a máquina por eventos mockados (morte/kill) e um CP injetável pelo host. Rodar:
##   godot --headless --path godot -s res://scripts/_wall_selftest.gd

## Host-mock: região + persistência em memória + CP controlável (p/ testar auto-exit) + contador de restat.
class MockHost:
	var region := "plains"
	var stage := {"chapter": 1, "stage": 1, "stage_kills": 0, "highest_global": 1,
		"mode": "advance", "wall_active": false, "fails": 0,
		"frontier_chapter": 1, "frontier_stage": 1, "farm_chapter": 1, "farm_stage": 1}
	var cp := 5   # CP baixo por padrão → NÃO auto-libera muro sem o teste subir explicitamente
	var restat_calls := 0
	func stagedirector_region_id() -> String: return region
	func stagedirector_load() -> Dictionary: return stage.duplicate()
	func stagedirector_persist(c: int, s: int, k: int, hg: int) -> void:
		stage["chapter"] = c; stage["stage"] = s; stage["stage_kills"] = k; stage["highest_global"] = hg
	func stagedirector_persist_wall(m: String, wa: bool, f: int, fc: int, fs: int, farmc: int, farms: int) -> void:
		stage["mode"] = m; stage["wall_active"] = wa; stage["fails"] = f
		stage["frontier_chapter"] = fc; stage["frontier_stage"] = fs
		stage["farm_chapter"] = farmc; stage["farm_stage"] = farms
	func stagedirector_player_cp() -> int: return cp
	func stagedirector_restat_mobs() -> void: restat_calls += 1

var _fail := 0
func _chk(name: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), name])
	if not cond: _fail += 1

var _kc := 0
func _kill_normal(sd, n: int) -> void:
	for i in range(n):
		_kc += 1
		sd.notify_kill("young_wolf", false, "k%d" % _kc)   # chave GLOBALMENTE única (como instance_id:deaths no jogo)

func _clear_stage(sd) -> void:
	# completa a fase corrente (normal): mata a cota + passa a transição
	_kill_normal(sd, sd.stage_quota())
	sd.tick(1.0)

func _initialize() -> void:
	var SD := load("res://scripts/StageDirector.gd")

	# ════════ leva 1-1 → 1-2 → chega numa frontier e falha 3× ════════
	var h := MockHost.new()
	var sd = SD.new(); root.add_child(sd); sd.setup(h)
	_chk("start 1-1 modo advance", sd.stage_label() == "1-1" and sd.mode == sd.MODE_ADVANCE)
	_clear_stage(sd)   # 1-1 → 1-2
	_clear_stage(sd)   # 1-2 → 1-3
	_chk("progrediu p/ 1-3 (last mastered = 1-2)", sd.stage_label() == "1-3")

	# WALL-T01: morte 1 → failure 1
	sd.notify_player_defeated()
	_chk("WALL-T01 morte 1 → fails=1", sd.consecutive_fails == 1)
	# WALL-T02: morte reseta o progresso da tentativa (mata alguns antes)
	_kill_normal(sd, 5)
	var kills_mid: int = sd.stage_kills
	sd.notify_player_defeated()
	_chk("WALL-T02 morte reseta progresso da tentativa (%d → 0)" % kills_mid, kills_mid == 5 and sd.stage_kills == 0)
	# WALL-T03: morte 2 → failure 2 (a de cima já foi a 2ª)
	_chk("WALL-T03 fails=2 após 2ª morte", sd.consecutive_fails == 2)
	# WALL-T04: morte 3 → wall active
	sd.notify_player_defeated()
	_chk("WALL-T04 morte 3 → MURO ATIVO", sd.wall_active and sd.mode == sd.MODE_FARM)
	# WALL-T05: farma a última dominada (1-2), frontier = 1-3
	_chk("WALL-T05 farm na última dominada (1-2), frontier 1-3", sd.stage_label() == "1-2" and sd.frontier_label() == "1-3")
	# WALL-T07/T06: farma repete a MESMA fase, sem aumentar highest_global
	var hg_before: int = sd.highest_global
	_clear_stage(sd)   # completa 1 rodada de farm
	_chk("WALL-T06 farm completa e REPETE 1-2", sd.stage_label() == "1-2")
	_chk("WALL-T07 farm NÃO aumenta highest_global", sd.highest_global == hg_before)
	# WALL-T08: durante o farm o AutoPlay continua caçando (candidate_ok libera mob normal; NÃO o mob de teste)
	_chk("WALL-T08 AutoPlay caça no farm (candidate_ok young_wolf=true, mage_of_heaven=false)", sd.candidate_ok("young_wolf", false) == true and sd.candidate_ok("mage_of_heaven", false) == false)
	# WALL-T09: morte durante o farm NÃO conta falha nem re-entra muro (auto-revive segue; farm ininterrupto)
	var fails_farm: int = sd.consecutive_fails
	sd.notify_player_defeated()
	_chk("WALL-T09 morte no farm não conta falha nem re-wall (segue farmando %s)" % sd.stage_label(), sd.consecutive_fails == fails_farm and sd.wall_active and sd.stage_label() == "1-2")

	# WALL-T10: CP >= frontier_required×0.95 → libera nova tentativa automática (na próxima rodada de farm)
	h.cp = int(ceil(sd.frontier_required_cp() * 0.95))
	_clear_stage(sd)   # rodada de farm → checa auto-exit
	_chk("WALL-T10 CP≥95% libera nova tentativa (volta p/ frontier 1-3, advance)", sd.stage_label() == "1-3" and sd.mode == sd.MODE_ADVANCE and not sd.wall_active)
	# WALL-T12: vencer a frontier zera a série de falhas
	_chk("WALL-T12a fails zerados ao sair do muro", sd.consecutive_fails == 0)
	_clear_stage(sd)   # vence 1-3 → 1-4
	_chk("WALL-T12b venceu a frontier → 1-4, fails=0", sd.stage_label() == "1-4" and sd.consecutive_fails == 0)
	sd.free()

	# ════════ WALL-T11: retry MANUAL (mesmo abaixo de 95%) ════════
	var h2 := MockHost.new()
	var sd2 = SD.new(); root.add_child(sd2); sd2.setup(h2)
	_clear_stage(sd2); _clear_stage(sd2)   # chega em 1-3
	for i in range(3): sd2.notify_player_defeated()
	_chk("setup muro p/ retry manual", sd2.wall_active)
	h2.cp = 1   # CP miserável → auto-exit NÃO liberaria
	var retried: bool = sd2.request_retry()
	_chk("WALL-T11 retry manual funciona mesmo com CP baixo", retried and not sd2.wall_active and sd2.stage_label() == "1-3" and sd2.mode == sd2.MODE_ADVANCE)
	sd2.free()

	# ════════ WALL-T13: save/load preserva o muro ════════
	var h3 := MockHost.new()
	var sd3 = SD.new(); root.add_child(sd3); sd3.setup(h3)
	_clear_stage(sd3); _clear_stage(sd3)
	for i in range(3): sd3.notify_player_defeated()   # muro ativo, farm 1-2 / frontier 1-3
	var saved_snapshot: Dictionary = h3.stage.duplicate()
	sd3.free()
	# relog: novo StageDirector lendo o mesmo save
	var sd3b = SD.new(); root.add_child(sd3b); sd3b.setup(h3)
	_chk("WALL-T13 save/load preserva muro (ativo, farm 1-2, frontier 1-3)", sd3b.wall_active and sd3b.mode == sd3b.MODE_FARM and sd3b.stage_label() == "1-2" and sd3b.frontier_label() == "1-3")
	sd3b.free()

	# ════════ WALL-T14: stage != região (troca de região não desacopla o muro) ════════
	var h4 := MockHost.new()
	var sd4 = SD.new(); root.add_child(sd4); sd4.setup(h4)
	_clear_stage(sd4); _clear_stage(sd4)
	for i in range(3): sd4.notify_player_defeated()
	var frontier_before: String = sd4.frontier_label()
	h4.region = "cave"
	sd4.notify_region_changed()
	_chk("WALL-T14 troca de região mantém o muro (frontier %s intacta)" % frontier_before, sd4.wall_active and sd4.frontier_label() == frontier_before)
	sd4.free()

	# ════════ SIMULAÇÃO COMPLETA (§39): vence 2, trava, farma, fica forte, libera, vence ════════
	print("  ── simulação completa do muro ──")
	var h5 := MockHost.new()
	var sd5 = SD.new(); root.add_child(sd5); sd5.setup(h5)
	_clear_stage(sd5)  # 1-1 vence
	_clear_stage(sd5)  # 1-2 vence → 1-3
	print("    venceu até %s" % sd5.stage_label())
	# frontier 1-3 "difícil": morre 3×
	for i in range(3): sd5.notify_player_defeated()
	print("    3 falhas → muro: farm=%s frontier=%s" % [sd5.stage_label(), sd5.frontier_label()])
	var sim_wall: bool = sd5.wall_active
	# CP baixo: farma vários ciclos sem liberar
	h5.cp = 10
	var rounds := 0
	for i in range(5):
		_clear_stage(sd5); rounds += 1
	var still_walled: bool = sd5.wall_active and sd5.stage_label() == "1-2"
	print("    farmou %d ciclos, ainda em muro=%s (highest intacto=%d)" % [rounds, still_walled, sd5.highest_global])
	# fica forte (CP sobe) → próxima rodada de farm libera
	h5.cp = sd5.frontier_required_cp()
	_clear_stage(sd5)
	var released: bool = not sd5.wall_active and sd5.stage_label() == "1-3"
	print("    CP subiu → muro liberado, retoma %s" % sd5.stage_label())
	# vence a frontier e continua
	_clear_stage(sd5)
	var continued: bool = sd5.stage_label() == "1-4"
	print("    venceu a frontier → %s" % sd5.stage_label())
	_chk("SIM muro completo (trava→farm→libera→vence→continua)", sim_wall and still_walled and released and continued)
	# restat foi chamado nas transições (scaling por fase vivo)
	_chk("SIM restat_mobs chamado nas transições (%d)" % h5.restat_calls, h5.restat_calls > 0)
	sd5.free()

	print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
	quit(0 if _fail == 0 else 1)
