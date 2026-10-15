extends SceneTree
## Self-test FATIA A6 — Prestígio / Master Level / Selos de Ciclo. Prova PREST-T01..T09, SEAL-T01..T07,
## ELIG-T01..T06, RESET-T01..T10, KEEP-T01..T12, MASTER-T01..T07, múltiplos Prestígios (§57), 10-Prestígios
## matemático (§58), offline+Prestígio (§59), invariantes (§50) e migração v1..v5 (§48). Snapshot/restore de
## GameState + save. Nenhum Node de mob/combate criado. Rodar:
##   godot --headless --path godot -s res://scripts/_a6_prestige_selftest.gd

var _fail := 0
func _chk(name: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), name])
	if not cond: _fail += 1

func _g():
	return root.get_node_or_null("GameState")

func _approx(a: float, b: float, tol: float) -> bool:
	return abs(a - b) <= tol

class _Host:
	func stagedirector_region_id() -> String: return "plains"
	func idlerewards_region_loot() -> Array: return [{"name": "Pelo de Lobo", "chance": 0.55}, {"name": "Elmo de Ronda", "chance": 0.06}]
	func prestige_apply_reset() -> void: pass   # sem StageDirector vivo no bench

func _initialize() -> void:
	var gs = _g()
	var save_path := "user://arcane_voyage_save.json"
	var snap := ""; var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snap = rf.get_as_text(); rf.close()
	var mem: Dictionary = gs.to_dict()

	# ══════════ PREST (PrestigeMath puro) ══════════
	_chk("PREST-T01 P0 exige stage 100", PrestigeMath.required_stage(0) == 100)
	_chk("PREST-T02 P1 exige stage 120", PrestigeMath.required_stage(1) == 120)
	_chk("PREST-T03 P0 exige 10 Selos", PrestigeMath.required_seals(0) == 10)
	_chk("PREST-T04 P1 exige 12 Selos", PrestigeMath.required_seals(1) == 12)
	_chk("PREST-T05 Master0 multiplier = 1.0", _approx(PrestigeMath.master_multiplier(0), 1.0, 0.0001))
	_chk("PREST-T06 Master1 = 1.08", _approx(PrestigeMath.master_multiplier(1), 1.08, 0.0001))
	_chk("PREST-T07 Master5 ≈ 1.469", _approx(PrestigeMath.master_multiplier(5), 1.4693, 0.001))
	_chk("PREST-T08 Master10 ≈ 2.159", _approx(PrestigeMath.master_multiplier(10), 2.1589, 0.001))
	var mono := true
	for p in range(0, 20):
		if PrestigeMath.required_stage(p + 1) <= PrestigeMath.required_stage(p): mono = false
		if PrestigeMath.required_seals(p + 1) <= PrestigeMath.required_seals(p): mono = false
		if PrestigeMath.master_multiplier(p + 1) <= PrestigeMath.master_multiplier(p): mono = false
	_chk("PREST-T09 fórmulas monotônicas (stage/selos/mult)", mono)

	# ══════════ SEAL (watermark grant_cycle_seal) ══════════
	gs.cycle_seals = 0; gs.cycle_seal_high = 0
	var s1: bool = gs.grant_cycle_seal(10)
	_chk("SEAL-T01 1ª conclusão 1-10 → +1", s1 and gs.cycle_seals == 1)
	var s2: bool = gs.grant_cycle_seal(10)
	_chk("SEAL-T02 farm 1-10 → +0 adicional", (not s2) and gs.cycle_seals == 1)
	var s3: bool = gs.grant_cycle_seal(10)
	_chk("SEAL-T03 retry do mesmo boss não duplica", (not s3) and gs.cycle_seals == 1)
	var s4: bool = gs.grant_cycle_seal(20)
	_chk("SEAL-T04 2-10 → segundo Selo", s4 and gs.cycle_seals == 2)
	_chk("SEAL-T03b não-boss (fase 7) nunca gera Selo", (not gs.grant_cycle_seal(7)) and gs.cycle_seals == 2)
	# SEAL-T07: watermark persiste em save/load → reload não duplica
	var seal_dict: Dictionary = gs.to_dict()
	gs.cycle_seals = 0; gs.cycle_seal_high = 0
	gs.apply_dict(seal_dict)   # recarrega o estado salvo
	var s7: bool = gs.grant_cycle_seal(20)   # boss já creditada antes do "reload"
	_chk("SEAL-T07 reload não duplica Selo (watermark persistido)", (not s7) and gs.cycle_seals == 2)

	# SEAL-T05/T06 — OFFLINE real via IdleRewards.boot_reconcile (CP alto por Master alto → cruza boss-stages)
	var host := _Host.new()
	var ir = load("res://scripts/IdleRewards.gd").new(); root.add_child(ir); ir.setup(host, null, null)
	gs.reset_save()
	gs.current_region_id = "plains"
	gs.master_level = 12            # multiplica o CP (offense+HP) → avança offline por várias fases/bosses
	gs.stage_chapter = 1; gs.stage_index = 1; gs.stage_highest_global = 1
	gs.stage_wall_active = false; gs.stage_mode = "advance"
	gs.cycle_seals = 0; gs.cycle_seal_high = 0
	gs.last_seen_at = 9000000; gs.offline_pending = {}; gs.offline_remainder_seconds = 0.0; gs._session_started = false
	ir.boot_reconcile(9000000 + 8 * 3600)
	var seals_after_off := int(gs.cycle_seals)
	print("  [offline] Master12 8h → cruzou até fase %d-%d, Selos=%d" % [gs.stage_chapter, gs.stage_index, seals_after_off])
	_chk("SEAL-T05 offline conclui boss-stage(s) em avanço → gera Selo(s)", seals_after_off >= 1)
	# SEAL-T06: 2º boot offline enquanto NÃO avança (farm) → nenhum Selo novo
	gs.last_seen_at = 9500000; gs._session_started = false
	# força cenário de farm puro: já walled OU CP insuficiente p/ a frontier — usa o estado atual (deve estar walled)
	ir.boot_reconcile(9500000 + 8 * 3600)
	_chk("SEAL-T06 offline farm de boss NÃO gera Selo repetido", int(gs.cycle_seals) == seals_after_off)

	# ══════════ ELIG (PrestigeManager) ══════════
	var pm = load("res://scripts/PrestigeManager.gd").new(); root.add_child(pm); pm.setup(host)
	# base: P0
	gs.prestige_count = 0; gs.offline_pending = {}
	gs.stage_highest_global = 99; gs.cycle_seals = 10
	_chk("ELIG-T01 stage99 + 10 selos → indisponível", not pm.is_eligible())
	gs.stage_highest_global = 100; gs.cycle_seals = 9
	_chk("ELIG-T02 stage100 + 9 selos → indisponível", not pm.is_eligible())
	gs.stage_highest_global = 100; gs.cycle_seals = 10
	_chk("ELIG-T03 stage100 + 10 selos → disponível", pm.is_eligible())
	# ELIG-T04: baú pendente bloqueia execução (mesmo elegível)
	gs.offline_pending = {"gold": 500}
	_chk("ELIG-T04 pending offline → bloqueia execução", not bool(pm.can_execute().get("ok", false)) and pm.is_eligible())
	gs.offline_pending = {}
	# ELIG-T05: ouro não influencia
	gs.hero_gold = 0
	var elig_no_gold: bool = pm.is_eligible()
	gs.hero_gold = 999999999
	var elig_much_gold: bool = pm.is_eligible()
	gs.stage_highest_global = 50   # abaixo do req
	var inelig_much_gold: bool = pm.is_eligible()
	gs.stage_highest_global = 100
	_chk("ELIG-T05 ouro não influencia eligibility", elig_no_gold and elig_much_gold and not inelig_much_gold)
	# ELIG-T06: Fragmentos não influenciam
	gs.materials["Fragmentos"] = 0
	var elig_no_frag: bool = pm.is_eligible()
	gs.materials["Fragmentos"] = 999999
	var elig_much_frag: bool = pm.is_eligible()
	_chk("ELIG-T06 Fragmentos não influenciam eligibility", elig_no_frag and elig_much_frag)

	# ══════════ RESET + KEEP + INVARIANTES (execute_prestige) ══════════
	gs.reset_save()
	# personagem com estado NÃO-trivial p/ provar preservação
	gs.hero_level = 7; gs.hero_xp = 55; gs.hero_gold = 4321; gs.hero_hp_max = 160
	gs.materials = {"Fragmentos": 42, "Pelo de Lobo": 9}
	gs.equipment = {"weapon": "sword_simple"} if ItemDB.exists("sword_simple") else {}
	gs.backpack = [{"id": "sword_simple", "qty": 1}] if ItemDB.exists("sword_simple") else []
	gs.locked_items.assign(["sword_simple"] if ItemDB.exists("sword_simple") else [])   # Array[String] tipado
	gs.loot_overflow = [{"id": "sword_simple", "qty": 2}] if ItemDB.exists("sword_simple") else []
	gs.class_mastery = {"guard": {"xp": 10, "level": 2}}
	gs.proficiency = {"melee": {"xp": 20, "level": 3}}
	gs.completed_quests.assign(["ch1-awakening"]); gs.story_flags.assign(["black_roots_arc_cleared"])
	gs.game_speed = 3.0
	gs.current_region_id = "cave"; gs.cluster_id = "c1"; gs.cluster_pos = [12, 34]
	# torna elegível (P0)
	gs.prestige_count = 0; gs.master_level = 0
	gs.stage_chapter = 10; gs.stage_index = 10; gs.stage_kills = 17; gs.stage_highest_global = 100
	gs.stage_wall_active = true; gs.stage_mode = "farm"; gs.stage_fails = 2
	gs.stage_frontier_chapter = 10; gs.stage_frontier_stage = 10
	gs.stage_farm_chapter = 9; gs.stage_farm_stage = 9
	gs.cycle_seals = 10; gs.cycle_seal_high = 100; gs.lifetime_highest_stage = 100
	gs.offline_remainder_seconds = 123.0; gs.offline_pending = {}
	gs.last_seen_at = 1; gs._session_started = false   # false → o flush não re-carimba last_seen (determinístico)
	# snapshot KEEP
	var k_level: int = gs.hero_level; var k_xp: int = gs.hero_xp; var k_gold: int = gs.hero_gold
	var k_frag: int = int(gs.materials.get("Fragmentos", 0)); var k_mats: Dictionary = gs.materials.duplicate(true)
	var k_equip: Dictionary = gs.equipment.duplicate(true); var k_back: Array = gs.backpack.duplicate(true)
	var k_locked: Array = gs.locked_items.duplicate(true); var k_over: Array = gs.loot_overflow.duplicate(true)
	var k_mastery: Dictionary = gs.class_mastery.duplicate(true); var k_prof: Dictionary = gs.proficiency.duplicate(true)
	var k_quests: Array = gs.completed_quests.duplicate(true); var k_flags: Array = gs.story_flags.duplicate(true)
	var k_speed: float = gs.game_speed; var k_region: String = gs.current_region_id
	var k_lifetime: int = gs.lifetime_highest_stage

	var res: Dictionary = pm.execute_prestige(7000000)
	_chk("EXEC ok=true (elegível, sem pending)", bool(res.get("ok", false)))
	# RESET
	_chk("RESET-T01 stage → 1-1", gs.stage_chapter == 1 and gs.stage_index == 1)
	_chk("RESET-T02 stage_kills = 0", gs.stage_kills == 0)
	_chk("RESET-T03 wall = false", gs.stage_wall_active == false and gs.stage_mode == "advance")
	_chk("RESET-T04 failures = 0", gs.stage_fails == 0)
	_chk("RESET-T05 cycle seals reset", gs.cycle_seals == 0 and gs.cycle_seal_high == 0)
	_chk("RESET-T06 prestige +1", gs.prestige_count == 1)
	_chk("RESET-T07 master +1", gs.master_level == 1)
	_chk("RESET-T08 lifetime highest preservado (≥100)", gs.lifetime_highest_stage >= 100 and gs.lifetime_highest_stage == maxi(k_lifetime, 100))
	_chk("RESET-T09 offline remainder antigo limpo", gs.offline_remainder_seconds == 0.0)
	_chk("RESET-T10 last_seen atualizado (= now)", gs.last_seen_at == 7000000)
	_chk("RESET frontier/farm zerados", gs.stage_frontier_chapter == 1 and gs.stage_frontier_stage == 1 and gs.stage_farm_chapter == 1 and gs.stage_farm_stage == 1)
	# KEEP
	_chk("KEEP-T01 level idêntico", gs.hero_level == k_level)
	_chk("KEEP-T02 XP idêntico", gs.hero_xp == k_xp)
	_chk("KEEP-T03 gold idêntico", gs.hero_gold == k_gold)
	_chk("KEEP-T04 Fragmentos idênticos", int(gs.materials.get("Fragmentos", 0)) == k_frag)
	_chk("KEEP-T05 equipment idêntico", gs.equipment == k_equip)
	_chk("KEEP-T06 backpack idêntico", gs.backpack == k_back)
	_chk("KEEP-T07 materials idênticos", gs.materials == k_mats)
	_chk("KEEP-T08 locked idêntico", gs.locked_items == k_locked)
	_chk("KEEP-T09 overflow idêntico", gs.loot_overflow == k_over)
	_chk("KEEP-T10 mastery/proficiency idênticos", gs.class_mastery == k_mastery and gs.proficiency == k_prof)
	_chk("KEEP-T11 quests/flags idênticos", gs.completed_quests == k_quests and gs.story_flags == k_flags)
	_chk("KEEP-T12 game_speed idêntico", gs.game_speed == k_speed and gs.current_region_id == k_region)
	# INVARIANTES (§50)
	_chk("INV prestige/master/seals ≥ 0 · lifetime ≥ cycle", gs.prestige_count >= 0 and gs.master_level >= 0 and gs.cycle_seals >= 0 and gs.lifetime_highest_stage >= gs.stage_highest_global)

	# ══════════ MASTER (poder real) ══════════
	gs.reset_save()
	gs.equipment = {}; gs.hero_hp_max = 100; gs.hero_level = 1
	gs.master_level = 0
	var cp0: int = PowerBudget.cp()
	var exp0: float = float(CombatMath.player_profile("melee")["expected"])
	var hp0: int = gs.max_hp_total()
	seed(12345); var roll0: int = CombatMath.player_roll("melee")
	gs.master_level = 1
	var cp1: int = PowerBudget.cp()
	var exp1: float = float(CombatMath.player_profile("melee")["expected"])
	var hp1: int = gs.max_hp_total()
	seed(12345); var roll1: int = CombatMath.player_roll("melee")
	_chk("MASTER-T01 Master1 aumenta dano REAL (roll %d → %d)" % [roll0, roll1], roll1 > roll0)
	_chk("MASTER-T02 Master1 aumenta expected_damage (%.1f → %.1f)" % [exp0, exp1], _approx(exp1, exp0 * 1.08, 0.001))
	_chk("MASTER-T03 Master1 aumenta max HP (%d → %d)" % [hp0, hp1], hp1 == 108 and hp1 > hp0)
	_chk("MASTER-T04 PowerBudget CP aumenta (%d → %d)" % [cp0, cp1], cp1 > cp0)
	_chk("MASTER-T05 nenhum CP artificial (razão ≈ 1.08)", _approx(float(cp1) / maxf(float(cp0), 1.0), 1.08, 0.02))
	# MASTER-T06: arquétipos continuam coerentes — cada um escala pelo MESMO mult (sem misturar identidade)
	gs.master_level = 0
	var base_r: float = float(CombatMath.player_profile("ranged")["expected"])
	var base_m: float = float(CombatMath.player_profile("magic")["expected"])
	gs.master_level = 1
	var m1_r: float = float(CombatMath.player_profile("ranged")["expected"])
	var m1_m: float = float(CombatMath.player_profile("magic")["expected"])
	_chk("MASTER-T06 arquétipos coerentes (ranged/magic escalam ×1.08)", _approx(m1_r, base_r * 1.08, 0.001) and _approx(m1_m, base_m * 1.08, 0.001))
	# MASTER-T07: projeção PURA antes == CP real depois
	gs.master_level = 3
	var cp_before: int = PowerBudget.cp()
	var proj: int = PrestigeMath.projected_cp(cp_before, 3)
	gs.master_level = 4
	var cp_after: int = PowerBudget.cp()
	_chk("MASTER-T07 projeção (%d) == CP real após (%d)" % [proj, cp_after], abs(proj - cp_after) <= maxi(1, int(0.01 * float(cp_after))))

	# ══════════ MÚLTIPLOS PRESTÍGIOS (§57) ══════════
	gs.reset_save(); gs.equipment = {}; gs._session_started = false
	var ok_multi := true
	for p in range(0, 4):   # P0→P1→P2→P3
		var need_stage: int = PrestigeMath.required_stage(gs.prestige_count)
		var need_seals: int = PrestigeMath.required_seals(gs.prestige_count)
		if not (need_stage == 100 + 20 * p and need_seals == 10 + 2 * p): ok_multi = false
		gs.stage_highest_global = need_stage; gs.cycle_seals = need_seals; gs.offline_pending = {}
		var rr: Dictionary = pm.execute_prestige(7100000 + p)
		if not bool(rr.get("ok", false)): ok_multi = false
		if gs.prestige_count != p + 1 or gs.master_level != p + 1: ok_multi = false
		if gs.stage_chapter != 1 or gs.stage_index != 1: ok_multi = false
		if gs.lifetime_highest_stage < need_stage: ok_multi = false
	_chk("MULTI P0→P3 requisitos/reset/master/lifetime coerentes", ok_multi)
	# save/load roundtrip do estado A6
	var rt: Dictionary = gs.to_dict()
	var parsed = JSON.parse_string(JSON.stringify(rt))
	gs.master_level = 0; gs.prestige_count = 0; gs.cycle_seals = 99; gs.lifetime_highest_stage = 1
	gs.apply_dict(parsed)
	_chk("MULTI save/load roundtrip preserva Prestígio/Master/lifetime", gs.prestige_count == 4 and gs.master_level == 4 and gs.lifetime_highest_stage == int(rt["lifetime_highest_stage"]))

	# ══════════ 10 PRESTÍGIOS — MATEMÁTICO (§58) ══════════
	var math_ok := true
	for p in range(0, 11):
		var rs: int = PrestigeMath.required_stage(p)
		var rq: int = PrestigeMath.required_seals(p)
		var mm: float = PrestigeMath.master_multiplier(p)
		if rs <= 0 or rq <= 0: math_ok = false
		if is_nan(mm) or is_inf(mm) or mm < 1.0: math_ok = false
	_chk("MATH P0..P10 sem NaN/Inf/overflow, monotônico", math_ok and PrestigeMath.master_multiplier(10) > PrestigeMath.master_multiplier(0))

	# ══════════ OFFLINE + PRESTÍGIO (§59) ══════════
	gs.reset_save(); gs.equipment = {}; gs.current_region_id = "plains"
	gs.prestige_count = 0; gs.master_level = 0
	gs.stage_highest_global = 100; gs.cycle_seals = 10   # elegível
	# baú pendente presente → Prestígio bloqueado
	gs.offline_pending = {"gold": 1000, "xp": 500, "items": {}, "materials": {}}
	var blocked: bool = not bool(pm.can_execute().get("ok", false))
	# "claim" (esvazia o baú) → desbloqueia
	gs.offline_pending = {}
	var unblocked: bool = bool(pm.can_execute().get("ok", false))
	_chk("OFF+PREST baú bloqueia; claim desbloqueia", blocked and unblocked)
	gs._session_started = false
	var op_res: Dictionary = pm.execute_prestige(9900000)
	# novo ciclo em 1-1, Master1, last_seen = now
	var post_ok: bool = bool(op_res.get("ok", false)) and gs.master_level == 1 and gs.stage_chapter == 1 and gs.stage_index == 1 and gs.last_seen_at == 9900000
	# offline seguinte usa o novo Master (CP maior) — prova que o mult entrou no snapshot do próximo cálculo
	var cp_m1: int = PowerBudget.cp()
	gs.master_level = 0; var cp_m0: int = PowerBudget.cp(); gs.master_level = 1
	_chk("OFF+PREST novo ciclo 1-1/Master1/last_seen; offline usa CP novo", post_ok and cp_m1 > cp_m0)

	# ══════════ MIGRAÇÃO v1..v5 (§48) ══════════
	# v4 → v5: adiciona campos A6, preservando os v4. Selos derivados do highest (conservador).
	var v4 := {"schemaVersion": 4, "hero_gold": 777, "stage_chapter": 3, "stage_index": 4, "stage_highest_global": 34}
	var m45: Dictionary = SaveMigration.migrate_with(v4.duplicate(true), 4, 5, SaveMigration._steps())
	_chk("MIG v4→v5 adiciona campos A6 preservando v4", int(m45.get("schemaVersion", 0)) == 5 and int(m45.get("hero_gold", 0)) == 777 and m45.has("prestige_count") and m45.has("master_level") and m45.has("cycle_seals") and m45.has("lifetime_highest_stage"))
	_chk("MIG v4→v5 Selos derivados = floor((34-1)/10) = 3", int(m45.get("cycle_seals", -1)) == 3 and int(m45.get("cycle_seal_high", -1)) == 30 and int(m45.get("lifetime_highest_stage", 0)) == 34)
	# v1 → v5 (cadeia completa) preserva um campo antigo e chega em v5 com todos os campos
	var v1 := {"schemaVersion": 1, "hero_level": 9, "stage_chapter": 1, "stage_index": 1, "stage_highest_global": 1}
	var m15: Dictionary = SaveMigration.migrate_with(v1.duplicate(true), 1, 5, SaveMigration._steps())
	_chk("MIG v1→v5 cadeia preserva campos antigos + chega em v5", int(m15.get("schemaVersion", 0)) == 5 and int(m15.get("hero_level", 0)) == 9 and m15.has("stage_mode") and m15.has("locked_items") and m15.has("last_seen_at") and m15.has("prestige_count"))
	_chk("MIG v1→v5 P0 conservador (prestige=0, sem Prestígio grátis)", int(m15.get("prestige_count", -1)) == 0 and int(m15.get("cycle_seals", -1)) == 0)

	# ══════════ restaura ══════════
	gs.apply_dict(mem); gs._dirty = false; gs._session_started = false
	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snap); wf.close()
	else:
		if FileAccess.file_exists(save_path): DirAccess.remove_absolute(save_path)
	print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
	quit(0 if _fail == 0 else 1)
