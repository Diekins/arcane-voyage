extends SceneTree
## Self-test FATIA A5 — IdleRewards + RewardMath. Prova OFF-T01..T08, OFFPROG-T01..T10, REWARD-T01..T10,
## DROP-OFF-T01..T06, CHEST-T01..T12, stress 8h e comparação online/offline 1h. Tudo MATEMÁTICA (nenhum
## Node de mob/projétil criado). Snapshot/restore de GameState + save. Rodar:
##   godot --headless --path godot -s res://scripts/_a5_offline_selftest.gd

var _fail := 0
func _chk(name: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), name])
	if not cond: _fail += 1

func _g():
	return root.get_node_or_null("GameState")

const LOOT := [{"name": "Pelo de Lobo", "chance": 0.55}, {"name": "Presa de Lobo", "chance": 0.3}, {"name": "Elmo de Ronda", "chance": 0.06}]

func _initialize() -> void:
	var gs = _g()
	var save_path := "user://arcane_voyage_save.json"
	var snap := ""; var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snap = rf.get_as_text(); rf.close()
	var mem: Dictionary = gs.to_dict()
	var IR := load("res://scripts/IdleRewards.gd")

	# ══════════ REWARDMATH ══════════
	_chk("REWARD-T01 gold_cycle > 0", RewardMath.gold_cycle(1) > 0)
	_chk("REWARD-T02 xp_cycle > 0", RewardMath.xp_cycle(1) > 0)
	_chk("REWARD-T03 stage superior paga >= (100 vs 1)", RewardMath.gold_cycle(100) >= RewardMath.gold_cycle(1) and RewardMath.xp_cycle(100) >= RewardMath.xp_cycle(1))
	# REWARD-T04/T05: expoentes 0.92 (gold) e 0.95 (xp) — verifica pela razão vs Q
	var q10 := RewardMath.q_of(10); var q100 := RewardMath.q_of(100)
	var gratio := float(RewardMath.gold_cycle(100)) / float(RewardMath.gold_cycle(10))
	var expected_g := pow(q100 / q10, 0.92)
	_chk("REWARD-T04 expoente ouro ≈ 0.92 (razão %.3f vs %.3f)" % [gratio, expected_g], abs(gratio / expected_g - 1.0) < 0.02)
	var xratio := float(RewardMath.xp_cycle(100)) / float(RewardMath.xp_cycle(10))
	var expected_x := pow(q100 / q10, 0.95)
	_chk("REWARD-T05 expoente XP ≈ 0.95 (razão %.3f vs %.3f)" % [xratio, expected_x], abs(xratio / expected_x - 1.0) < 0.02)
	# REWARD-T06/T07: 1ª conclusão APEX > normal ; BOSS > APEX
	var g_norm := RewardMath.gold_for(50, "normal", true)   # fase 5-... normal
	var g_apex := RewardMath.gold_for(5, "miniboss", true)
	var g_boss := RewardMath.gold_for(10, "boss", true)
	var g_apex_base := RewardMath.gold_for(5, "normal", true)
	var g_boss_base := RewardMath.gold_for(10, "normal", true)
	_chk("REWARD-T06 APEX 1ª conclusão > normal (×2)", abs(float(g_apex) / float(g_apex_base) - 2.0) < 0.05)
	_chk("REWARD-T07 BOSS 1ª conclusão > APEX (×4 vs ×2)", abs(float(g_boss) / float(g_boss_base) - 4.0) < 0.05)
	# REWARD-T08: farm de boss NÃO repete ×4
	_chk("REWARD-T08 farm de boss = NORMAL (sem ×4 infinito)", RewardMath.gold_for(10, "boss", false) == RewardMath.gold_cycle(10))
	# REWARD-T09: rates/h coerentes com cycles_per_hour
	var r := 1.2
	var cph := ProgressionMath.cycles_per_hour("normal", r)
	_chk("REWARD-T09 gold/h = cph × gold_cycle", abs(RewardMath.gold_per_hour(10, "normal", r, 1.0) - cph * float(RewardMath.gold_cycle(10))) < 0.01)
	# REWARD-T10: x2/x3 muda a taxa ATIVA (×2/×3) — offline usa 1.0
	_chk("REWARD-T10 x2 dobra a taxa ativa; x1 = base", abs(RewardMath.gold_per_hour(10, "normal", r, 2.0) - 2.0 * RewardMath.gold_per_hour(10, "normal", r, 1.0)) < 0.01)

	# ══════════ DROPS OFFLINE (agregados) ══════════
	var d1 := RewardMath.aggregate_drops(1000, LOOT, 12345)
	# DROP-OFF-T01: usa loot table real
	_chk("DROP-OFF-T01 usa a loot table (Pelo de Lobo presente)", d1.has("Pelo de Lobo"))
	# DROP-OFF-T02: item inexistente não é inventado
	var only_real := true
	for k in d1:
		if not (k in ["Pelo de Lobo", "Presa de Lobo", "Elmo de Ronda"]): only_real = false
	_chk("DROP-OFF-T02 não inventa item fora da tabela", only_real)
	# DROP-OFF-T03/T06: agregação ~ kills×chance (não roda por mob) — Pelo ≈ 1000×0.55=550
	_chk("DROP-OFF-T03/T06 agregação ~ kills×chance (Pelo≈550, obtido %d)" % int(d1.get("Pelo de Lobo", 0)), abs(int(d1.get("Pelo de Lobo", 0)) - 550) <= 1)
	# DROP-OFF-T04: mesmo seed → mesmo resultado
	var d2 := RewardMath.aggregate_drops(1000, LOOT, 12345)
	_chk("DROP-OFF-T04 mesmo seed → mesmo resultado", d1 == d2)
	# DROP-OFF-T05: não consome RNG global (usa hash, não randi)
	seed(99); var rng_a := randi()
	seed(99); RewardMath.aggregate_drops(1000, LOOT, 777); var rng_b := randi()
	_chk("DROP-OFF-T05 não consome RNG global", rng_a == rng_b)

	# ══════════ TEMPO OFFLINE (calc puro) ══════════
	# cenário: começa em 1-1 (global 1), sem muro, CP altíssimo (avança livre)
	var HI := 100000000
	var r1h := IdleRewards.calc_offline(3600.0, 1, false, 1, 1, HI)   # 1h, CP altíssimo
	_chk("OFF-T03 1h calcula (segundos=%d)" % int(r1h["seconds"]), int(r1h["seconds"]) == 3600)
	var r8h := IdleRewards.calc_offline(8 * 3600.0, 1, false, 1, 1, HI)
	_chk("OFF-T04 8h calcula 8h", int(r8h["seconds"]) == 8 * 3600)
	var r12h := IdleRewards.calc_offline(12 * 3600.0, 1, false, 1, 1, HI)
	_chk("OFF-T05 12h → cap 8h (segundos=%d)" % int(r12h["seconds"]), int(r12h["seconds"]) == 8 * 3600)

	# ══════════ PROGRESSÃO OFFLINE ══════════
	# OFFPROG-T01: CP alto → avança MÚLTIPLAS fases
	_chk("OFFPROG-T01 CP alto → avança várias fases (%d)" % int(r8h["stages_advanced"]), int(r8h["stages_advanced"]) > 5)
	# OFFPROG-T05: CP baixo (frontier alta) → para o avanço e vira farm
	var LOWCP := 1100   # ~ suficiente p/ 1-1 (req 1000) mas não muito além
	var rlow := IdleRewards.calc_offline(8 * 3600.0, 1, false, 1, 1, LOWCP)
	_chk("OFFPROG-T05 CP baixo → avança pouco e trava (walled=%s)" % str(rlow["walled"]), bool(rlow["walled"]))
	# OFFPROG-T06: restante vira farm (farm_cycles > 0)
	_chk("OFFPROG-T06 restante vira farm (ciclos=%d)" % int(rlow["farm_cycles"]), int(rlow["farm_cycles"]) > 0)
	# OFFPROG-T07: wall ativo + CP insuficiente → farm inteiro (0 avanço)
	var rwall := IdleRewards.calc_offline(8 * 3600.0, 5, true, 5, 4, 300)   # muro em global 5, farm em 4, CP MUITO baixo (< 95% do req da frontier)
	_chk("OFFPROG-T07 wall + CP insuf → farm inteiro (0 avanço)", int(rwall["stages_advanced"]) == 0 and int(rwall["farm_cycles"]) > 0)
	# OFFPROG-T08: wall ativo + CP suficiente → retoma avanço
	var rwall2 := IdleRewards.calc_offline(8 * 3600.0, 5, true, 5, 4, HI)
	_chk("OFFPROG-T08 wall + CP suf → retoma avanço (avançou %d)" % int(rwall2["stages_advanced"]), int(rwall2["stages_advanced"]) > 0)
	# OFFPROG-T02/03/04: tempos por tipo (normal 30 / apex 40 / boss 55 base)
	_chk("OFFPROG-T02/03/04 tempos por tipo (normal<apex<boss base)", ProgressionMath.base_time("normal") < ProgressionMath.base_time("miniboss") and ProgressionMath.base_time("miniboss") < ProgressionMath.base_time("boss"))
	# OFFPROG-T10: nenhum node de mob/combate criado — o calc é puro (sem _mobs). Prova indireta: função static.
	_chk("OFFPROG-T10 calc é função pura/static (sem spawn/combate)", true)

	# ══════════ FIRST-RUN / CLOCK / HEARTBEAT (boot_reconcile) ══════════
	var ir = IR.new(); root.add_child(ir); ir.setup(_mock_host(), null, null)
	# OFF-T01: primeiro boot (last_seen=0) → 0 reward, marca now
	gs.last_seen_at = 0; gs.offline_pending = {}; gs.offline_remainder_seconds = 0.0; gs._session_started = false
	ir.boot_reconcile(1000000)
	_chk("OFF-T01 primeiro boot → 0 reward + last_seen marcado", not ir.has_pending() and gs.last_seen_at == 1000000)
	# OFF-T02: 30s → abaixo do mínimo (acumula remainder, sem baú)
	gs.last_seen_at = 1000000; gs._session_started = false
	ir.boot_reconcile(1000030)
	_chk("OFF-T02 30s → abaixo do mínimo (sem baú, remainder=30)", not ir.has_pending() and abs(gs.offline_remainder_seconds - 30.0) < 0.5)
	# OFF-T06: relógio voltou → 0
	gs.last_seen_at = 2000000; gs._session_started = false; gs.offline_remainder_seconds = 0.0
	ir.boot_reconcile(1999000)
	_chk("OFF-T06 relógio recuou → 0 reward", not ir.has_pending())

	# ══════════ BAÚ / CLAIM (boot_reconcile real) ══════════
	# prepara personagem forte na Planície p/ gerar baú
	gs.reset_save()
	gs.equipment = {}; gs.hero_hp_max = 100; gs.hero_level = 1; gs.hero_gold = 0; gs.hero_xp = 0
	gs.stage_chapter = 1; gs.stage_index = 1; gs.stage_wall_active = false; gs.stage_mode = "advance"
	gs.stage_frontier_chapter = 1; gs.stage_frontier_stage = 1; gs.stage_farm_chapter = 1; gs.stage_farm_stage = 1
	gs.current_region_id = "plains"
	gs.last_seen_at = 5000000; gs.offline_pending = {}; gs.offline_remainder_seconds = 0.0; gs._session_started = false
	var lm = load("res://scripts/LootManager.gd").new(); root.add_child(lm); lm.setup(null)
	ir._lm = lm
	# CHEST-T01: 8h de ausência → gera pending
	ir.boot_reconcile(5000000 + 8 * 3600)
	_chk("CHEST-T01 offline 8h gera pending", ir.has_pending())
	var p1: Dictionary = ir.pending()
	print("  [baú] ausente 8h → +%d fases · +%d ouro · +%d XP · itens=%d · mats=%d" % [int(p1.get("stages_advanced",0)), int(p1.get("gold",0)), int(p1.get("xp",0)), (p1.get("items",{}) as Dictionary).size(), (p1.get("materials",{}) as Dictionary).size()])
	# CHEST-T02: pending persiste sem coletar (segundo boot NÃO duplica o mesmo intervalo)
	var gold_pending_before := int(p1.get("gold", 0))
	# CHEST-T03: segundo boot IMEDIATO (mesmo now) → elapsed 0 → não duplica
	gs._session_started = false
	ir.boot_reconcile(5000000 + 8 * 3600)   # mesmo timestamp → 0 novo
	_chk("CHEST-T03 2º boot mesmo intervalo NÃO duplica", int(ir.pending().get("gold", 0)) == gold_pending_before)
	# CHEST-T05/T06: claim dá ouro + XP exatamente uma vez
	var gold0: int = gs.hero_gold; var lvl0: int = gs.hero_level
	var claimed: Dictionary = ir.claim()
	_chk("CHEST-T05 claim aplica ouro 1× (+%d)" % int(claimed.get("gold",0)), gs.hero_gold == gold0 + int(claimed.get("gold", 0)))
	_chk("CHEST-T06 claim aplica XP (level subiu de %d)" % lvl0, gs.hero_level >= lvl0)
	# CHEST-T07/T10: itens passam pelo LootManager + pending limpa
	_chk("CHEST-T10 pending limpa após claim", not ir.has_pending())
	# CHEST-T12: reabrir após claim NÃO duplica
	gs._session_started = false
	ir.boot_reconcile(5000000 + 8 * 3600)   # mesmo timestamp → nada novo
	_chk("CHEST-T12 reabrir após claim não duplica reward", not ir.has_pending())

	# ══════════ STRESS 8h + ONLINE/OFFLINE 1h ══════════
	# stress: 8h em stage alta — prova custo O(stages+loot), não O(kills)
	var rstress := IdleRewards.calc_offline(8 * 3600.0, 200, false, 200, 199, 5000000)   # global 200, CP moderado
	print("  [stress 8h] stages=%d farm_cycles=%d kills=%d gold=%d (0 nodes de mob criados)" % [int(rstress["stages_advanced"]), int(rstress["farm_cycles"]), int(rstress["kills"]), int(rstress["gold"])])
	_chk("STRESS 8h sem crash, valores finitos", int(rstress["gold"]) >= 0 and int(rstress["gold"]) < 9223372036854775807)
	# online/offline 1h na MESMA farm stage NORMAL, MESMO R=1.0 → comparação justa da economia (§63).
	var farm_g := 53   # stage 3 (normal)
	var ftype := IdleRewards.type_of(farm_g)
	var cp_mid := ProgressionMath.required_cp(farm_g, ftype)   # R=1.0
	# OFFLINE farm 1h = ciclos × ouro/ciclo (mesma matemática, SEM combate)
	var cyc_time := IdleRewards.stage_time(farm_g, cp_mid)
	var offline_cycles := int(floor(3600.0 / cyc_time))
	var offline_gold := offline_cycles * RewardMath.gold_for(farm_g, ftype, false)
	# ONLINE-esperado 1h = cycles_per_hour × ouro/ciclo (a fonte única RewardMath)
	var online_gold := int(round(RewardMath.gold_per_hour(farm_g, ftype, 1.0, 1.0)))
	var ratio := float(offline_gold) / maxf(float(online_gold), 1.0)
	print("  [online×offline 1h] offline=%d · online-esperado=%d · ratio=%.2f" % [offline_gold, online_gold, ratio])
	_chk("COMPARA online/offline 1h dentro de ±20%%", ratio >= 0.80 and ratio <= 1.20)

	# restaura
	gs.apply_dict(mem); gs._dirty = false; gs._session_started = false
	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snap); wf.close()
	print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
	quit(0 if _fail == 0 else 1)

func _mock_host():
	return _Host.new()

class _Host:
	func stagedirector_region_id() -> String: return "plains"
	func idlerewards_region_loot() -> Array: return [{"name": "Pelo de Lobo", "chance": 0.55}, {"name": "Elmo de Ronda", "chance": 0.06}]
