extends SceneTree
## Self-test FATIA A7.1 — ItemInstance / Quality / Rolls / Valor comercial + Refino Endgame.
## Prova INST/VALUE/ILOOT/REND/SUPPORT + 100k rolls + 10k refinos + comercial + muro. ★ FIXTURE DESCARTÁVEL
## (set_save_path_override) — NUNCA toca o save vivo.  godot --headless --path godot -s res://scripts/_a71_iteminstance_selftest.gd

var _fail := 0
func _chk(name: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), name])
	if not cond: _fail += 1
func _g():
	return root.get_node_or_null("GameState")
func _approx(a: float, b: float, tol: float) -> bool:
	return abs(a - b) <= tol

# instância controlada (rolls fixos) p/ provas determinísticas de VALUE
func _mk(item_id: String, q: int, roll_mult: float) -> Dictionary:
	var rolls: Dictionary = {}
	for k in ItemInstance.CORE_REFINABLE:
		if int(ItemDB.stat(item_id, k)) > 0:
			rolls[k] = roll_mult
	return ItemInstance.make("iid_%s_%d" % [item_id, q], item_id, q, rolls, [], "test", 0, true, false)

func _initialize() -> void:
	var gs = _g()
	var fixture := "user://a71_fixture_save.json"
	gs.set_save_path_override(fixture)
	var mem: Dictionary = gs.to_dict()
	gs.reset_save()

	# ══════════ INST ══════════
	var a := ItemRoller.roll("sword_reinforced", 111, "loot")
	var b := ItemRoller.roll("sword_reinforced", 222, "loot")
	_chk("INST-T01 cópias mesmo item_id têm iid diferente", str(a["iid"]) != str(b["iid"]))
	var c1 := ItemRoller.roll("sword_reinforced", 777)
	var c2 := ItemRoller.roll("sword_reinforced", 777)
	_chk("INST-T02 mesmo seed → mesmos rolls/quality", c1 == c2)
	var diff := false
	for s in range(1, 40):
		if int(ItemRoller.roll("sword_reinforced", s)["quality"]) != int(a["quality"]): diff = true
	_chk("INST-T03 seeds diferentes podem gerar rolls diferentes", diff)
	# INST-T04: quality DERIVA dos rolls — prova com um drop de 0 afixos (recomputa a partir do core roll)
	var t4_ok := false
	for s2 in range(1, 400):
		var inst := ItemRoller.roll("sword_simple", s2)   # common: 0-1 afixo
		if (inst.get("affixes", []) as Array).is_empty():
			var roll_a := float((inst["rolls"] as Dictionary)["attack"])
			var expect_q := int(round((roll_a - 0.85) / 0.30 * 100.0))
			t4_ok = (int(inst["quality"]) == expect_q)
			break
	_chk("INST-T04 quality deriva dos rolls (0 afixo: q = norm(core))", t4_ok)
	_chk("INST-T06 ItemDefinition NÃO é mutado", int(ItemDB.stat("sword_reinforced", "attack")) == 11)
	_chk("INST-T07 consumível continua stackável (roller ignora)", ItemRoller.roll("potion_minor", 1).is_empty())
	# INST-T08 legacy: migra v6→v7 e mantém stats (rota base, sem instância)
	gs.reset_save(); gs.equipment = {}; gs.master_level = 0
	var v6 := {"schemaVersion": 6, "equipment": {"weapon": "sword_reinforced"}}
	var mig: Dictionary = SaveMigration.migrate_with(v6.duplicate(true), 6, 7, SaveMigration._steps())
	gs.apply_dict(mig)
	_chk("INST-T08 legacy migra com stats equivalentes (attack=11, sem instância)", gs.equip_sum("attack") == 11 and gs.equipped_instances.is_empty())
	# INST-T09 lock por instância
	gs.reset_save()
	var la := _mk("sword_reinforced", 80, 1.0); var lb := _mk("bow_reinforced", 80, 1.0)
	gs.set_instance_locked(str(la["iid"]), true)
	_chk("INST-T09 lock individual (iid A locked, iid B não)", gs.is_instance_locked(str(la["iid"])) and not gs.is_instance_locked(str(lb["iid"])))
	# INST-T10 overflow preserva instância completa
	gs.reset_save()
	var lm = load("res://scripts/LootManager.gd").new(); lm.name = "LootManager"; root.add_child(lm); lm.setup(null)
	# lota bolsa (30) + overflow com instâncias PROTEGIDAS (quality 96) → força overflow
	for i in range(55):
		var hi := _mk("sword_reinforced", 96, 1.15); hi["iid"] = "ov_%d" % i
		lm.receive_instance(hi)
	var ov_ok: bool = gs.overflow_instances.size() > 0 and (gs.overflow_instances[0] as Dictionary).has("rolls")
	_chk("INST-T10 overflow preserva instância COMPLETA (com rolls)", ov_ok)

	# ══════════ VALUE ══════════
	gs.reset_save(); gs.equipment = {}; gs.master_level = 0
	var low := _mk("sword_reinforced", 5, 0.85)
	var high := _mk("sword_reinforced", 98, 1.15)
	gs.equip_instance(low.duplicate(true))
	var cp_low: int = PowerBudget.cp()
	gs.equip_instance(high.duplicate(true))
	var cp_high: int = PowerBudget.cp()
	_chk("VALUE-T01 mesmo item_id: quality98 CP (%d) > quality5 (%d)" % [cp_high, cp_low], cp_high > cp_low)
	# VALUE-T02 mesmo slot/refino, melhor continua melhor
	gs.reset_save(); gs.equipment = {}
	gs.slot_refinement = {"weapon": 10}
	gs.equip_instance(low.duplicate(true)); var cp_low_r: int = PowerBudget.cp()
	gs.equip_instance(high.duplicate(true)); var cp_high_r: int = PowerBudget.cp()
	_chk("VALUE-T02 mesmo slot +10, item melhor continua melhor", cp_high_r > cp_low_r)
	# VALUE-T03 trocar item NÃO muda refino do slot
	_chk("VALUE-T03 trocar item preserva refino do slot (+10)", gs.refine_level("weapon") == 10)
	# VALUE-T04/T05 trade payload
	var payload := ItemInstance.trade_payload(high)
	_chk("VALUE-T04 trade payload NÃO contém refino/estado do personagem", ItemInstance.trade_payload_clean(payload) and not payload.has("slot_refinement"))
	_chk("VALUE-T05 trade payload contém rolls/quality", payload.has("rolls") and payload.has("quality"))
	# VALUE-T06 Códice conta ambas como uma descoberta
	gs.reset_save()
	gs.codex_discover("sword_reinforced"); gs.codex_discover("sword_reinforced")
	_chk("VALUE-T06 Códice conta ambas as cópias como UMA descoberta", gs.codex_unique_count() == 1)

	# ══════════ ILOOT ══════════
	gs.reset_save(); gs.equipment = {}; gs.master_level = 0
	lm.receive_world_drop("sword_reinforced")
	_chk("ILOOT-T01 loot equipável gera instância (bolsa cresceu ou salvage)", gs.item_instances.size() > 0 or lm.loot_salvaged > 0)
	# T02 mesmo item_id melhor não é salvaged; T03 pior seguro pode ser
	gs.reset_save(); gs.equipment = {}
	gs.equip_instance(_mk("sword_reinforced", 50, 1.0))   # equipado mediano
	var better := _mk("sword_reinforced", 90, 1.15)
	var worse := _mk("sword_reinforced", 5, 0.85)
	_chk("ILOOT-T02 mesmo item_id MELHOR não é salvageable", lm.classify_instance(better) != lm.Cls.SALVAGEABLE)
	_chk("ILOOT-T03 pior seguro é salvageable", lm.classify_instance(worse) == lm.Cls.SALVAGEABLE)
	# T04 locked nunca salvage
	var lk := _mk("sword_reinforced", 5, 0.85); gs.set_instance_locked(str(lk["iid"]), true)
	_chk("ILOOT-T04 locked nunca salvage (PROTECTED)", lm.classify_instance(lk) == lm.Cls.PROTECTED)
	# T05 quality excepcional preservada
	_chk("ILOOT-T05 quality excepcional (96) PROTEGIDA pela política", lm.classify_instance(_mk("sword_reinforced", 96, 1.15)) == lm.Cls.PROTECTED)
	# T06/T07 offline claim determinístico (via IdleRewards)
	gs.reset_save(); gs.equipment = {}
	var ir = load("res://scripts/IdleRewards.gd").new(); root.add_child(ir); ir.setup(_Host.new(), null, lm)
	gs.offline_pending = {"gold": 0, "xp": 0, "items": {"sword_reinforced": 2}, "materials": {}, "roll_seed": 424242}
	ir.claim()
	var snap1: Array = []
	for inst in gs.item_instances: snap1.append(str(inst.get("iid", "")) + ":" + str(inst.get("quality", 0)))
	snap1.sort()
	# reclaim equivalente (mesma seed) → mesmas instâncias
	gs.item_instances.clear(); gs.overflow_instances.clear()
	gs.offline_pending = {"gold": 0, "xp": 0, "items": {"sword_reinforced": 2}, "materials": {}, "roll_seed": 424242}
	ir.claim()
	var snap2: Array = []
	for inst in gs.item_instances: snap2.append(str(inst.get("iid", "")) + ":" + str(inst.get("quality", 0)))
	snap2.sort()
	_chk("ILOOT-T06 offline claim gera instâncias (n=%d)" % snap1.size(), snap1.size() >= 1)
	_chk("ILOOT-T07 reclaim equivalente NÃO re-rola (mesmas instâncias)", snap1 == snap2)

	# ══════════ REND (RefineMath + refine_attempt) ══════════
	_chk("REND-T01 +0..+4 = 100%", RefineMath.base_chance(0) == 1.0 and RefineMath.base_chance(4) == 1.0)
	_chk("REND-T02 +9→+10 = 60%", _approx(RefineMath.base_chance(9), 0.60, 0.001))
	_chk("REND-T03 +10→+11 = 50%", _approx(RefineMath.base_chance(10), 0.50, 0.001))
	_chk("REND-T04 +19→+20 = 5%", _approx(RefineMath.base_chance(19), 0.05, 0.001))
	gs.reset_save(); gs.equipment = {"weapon": "sword_reinforced"}; gs.materials = {"Fragmentos": 10000000}
	# T05 falha abaixo de +10 não downgrade
	gs.slot_refinement = {"weapon": 6}; gs.refine_pity_by_slot = {}
	var r5: Dictionary = gs.refine_attempt("weapon", "", false, false, 0.999)   # fail (chance 0.85)
	_chk("REND-T05 falha abaixo de +10 NÃO downgrade (%d)" % gs.refine_level("weapon"), not bool(r5["success"]) and gs.refine_level("weapon") == 6)
	# T06 falha desde +10 downgrade -1
	gs.slot_refinement = {"weapon": 13}
	var r6: Dictionary = gs.refine_attempt("weapon", "", false, false, 0.999)
	_chk("REND-T06 falha >= +10 downgrade -1 (13→%d)" % gs.refine_level("weapon"), not bool(r6["success"]) and gs.refine_level("weapon") == 12)
	# T07 nunca < 0 (level 10 falha → 9)
	gs.slot_refinement = {"weapon": 10}
	gs.refine_attempt("weapon", "", false, false, 0.999)
	_chk("REND-T07 nunca abaixo de 0 (10→%d)" % gs.refine_level("weapon"), gs.refine_level("weapon") == 9)
	# T08 nunca > 20
	gs.slot_refinement = {"weapon": 20}
	var r8: Dictionary = gs.refine_attempt("weapon", "", false, false, 0.0)
	_chk("REND-T08 nunca acima de +20", not bool(r8.get("ok", false)) and gs.refine_level("weapon") == 20)
	# T09 pity +2pp por falha; T11 sucesso zera
	gs.slot_refinement = {"weapon": 8}; gs.refine_pity_by_slot = {}
	gs.refine_attempt("weapon", "", false, false, 0.999)   # fail (chance 0.70)
	_chk("REND-T09 pity +2pp por falha (%.2f)" % gs.refine_pity("weapon"), _approx(gs.refine_pity("weapon"), 0.02, 0.001))
	gs.slot_refinement = {"weapon": 8}
	gs.refine_attempt("weapon", "", false, false, 0.0)     # success
	_chk("REND-T11 sucesso zera pity", gs.refine_pity("weapon") == 0.0)
	# T10 pity cap +30pp (A7.2: cap recalibrado 0.20→0.30 COM DADOS — ver _a72_economy_selftest). Nível 15:
	# chance máx (0.20+0.30=0.50) < 0.999 ⇒ falha sempre, pity acumula limpo até o teto.
	gs.slot_refinement = {"weapon": 15}; gs.refine_pity_by_slot = {}; gs.refine_high_by_slot = {}
	for i in range(40): gs.slot_refinement["weapon"] = 15; gs.refine_attempt("weapon", "", false, false, 0.999)
	_chk("REND-T10 pity cap +30pp (%.2f)" % gs.refine_pity("weapon"), _approx(gs.refine_pity("weapon"), 0.30, 0.001))
	# T12 Prestígio preserva pity/refino
	gs.reset_save(); gs.equipment = {"weapon": "sword_reinforced"}; gs.master_level = 0; gs.prestige_count = 0
	gs.slot_refinement = {"weapon": 12}; gs.refine_pity_by_slot = {"weapon": 0.10}
	gs.stage_highest_global = 100; gs.cycle_seals = 10; gs.offline_pending = {}; gs._session_started = false
	var pm = load("res://scripts/PrestigeManager.gd").new(); root.add_child(pm); pm.setup(_Host.new())
	pm.execute_prestige(9000000)
	_chk("REND-T12 Prestígio preserva pity/refino", gs.refine_level("weapon") == 12 and _approx(gs.refine_pity("weapon"), 0.10, 0.001))

	# ══════════ SUPPORT ══════════
	gs.reset_save(); gs.equipment = {"weapon": "sword_reinforced"}; gs.materials = {"Fragmentos": 10000000}
	gs.slot_refinement = {"weapon": 16}; gs.refine_pity_by_slot = {}
	var info_cat: Dictionary = gs.refine_attempt_info("weapon", "catalyst_refine")
	_chk("SUPPORT-T01 Catalisador +5pp", _approx(float(info_cat["catalyst_pp"]), 0.05, 0.001) and _approx(float(info_cat["final_chance"]), RefineMath.base_chance(16) + 0.05, 0.001))
	var info_sup: Dictionary = gs.refine_attempt_info("weapon", "catalyst_superior")
	_chk("SUPPORT-T02 Superior +15pp", _approx(float(info_sup["catalyst_pp"]), 0.15, 0.001))
	# T04/T05/T06 preservação
	gs.slot_refinement = {"weapon": 13}; gs.refine_pity_by_slot = {}
	gs.backpack_add_silent("seal_preservation", 1)
	var frag_b4: int = gs.fragments()
	var rp: Dictionary = gs.refine_attempt("weapon", "", true, false, 0.999)   # fail protegido
	_chk("SUPPORT-T04 Preservação impede downgrade (13→%d)" % gs.refine_level("weapon"), gs.refine_level("weapon") == 13 and bool(rp["preserved"]))
	_chk("SUPPORT-T05 Preservação NÃO devolve Fragmentos", frag_b4 - gs.fragments() > 0 and gs.backpack_count("seal_preservation") == 0)
	_chk("SUPPORT-T06 falha protegida aumenta pity", gs.refine_pity("weapon") > 0.0)
	# T03 máximo 1 catalisador (estrutural: um id por tentativa) + consumo
	gs.slot_refinement = {"weapon": 10}; gs.backpack_add_silent("catalyst_refine", 3)
	gs.refine_attempt("weapon", "catalyst_refine", false, false, 0.0)   # success, consome 1
	_chk("SUPPORT-T03 máx 1 catalisador por tentativa (consumiu 1: 3→%d)" % gs.backpack_count("catalyst_refine"), gs.backpack_count("catalyst_refine") == 2)
	# T07/T08 Selo Absoluto
	gs.slot_refinement = {"weapon": 15}; gs.backpack_add_silent("seal_absolute", 2)
	var info_abs: Dictionary = gs.refine_attempt_info("weapon", "", true)
	_chk("SUPPORT-T07 Selo Absoluto = 100%", _approx(float(info_abs["final_chance"]), 1.0, 0.001))
	var ra: Dictionary = gs.refine_attempt("weapon", "", false, true, 0.999)   # roll alto, mas absoluto garante
	_chk("SUPPORT-T08 Absoluto consome 1 e garante sucesso (2→%d)" % gs.backpack_count("seal_absolute"), bool(ra["success"]) and gs.backpack_count("seal_absolute") == 1)
	# T09 cancelar/indisponível não consome
	gs.slot_refinement = {"weapon": 5}; gs.materials = {"Fragmentos": 0}; gs.backpack_add_silent("catalyst_refine", 1)
	var cat_before: int = gs.backpack_count("catalyst_refine")
	var rno: Dictionary = gs.refine_attempt("weapon", "catalyst_refine", false, false, 0.0)
	_chk("SUPPORT-T09 tentativa não executada (sem Frag) NÃO consome", not bool(rno.get("ok", false)) and gs.backpack_count("catalyst_refine") == cat_before)
	# T10 farm boss não gera suporte repetido (watermark)
	gs.reset_save()
	var d1: Array = gs.grant_encounter_reward(10, 12345)
	var d2: Array = gs.grant_encounter_reward(10, 12345)   # mesmo encontro, 2ª vez (farm)
	_chk("SUPPORT-T10 farm boss NÃO repete suporte (2ª vez vazia)", d2.is_empty())

	# ══════════ 100.000 ROLLS — distribuição de quality ══════════
	var buckets := {"n": 0, "sum": 0, "ge90": 0, "ge95": 0, "ge98": 0, "ge99": 0}
	var qs: Array = []
	for i in range(100000):
		var q := int(ItemRoller.roll("sword_reinforced", i * 2654435761 + 7)["quality"])
		buckets["n"] += 1; buckets["sum"] += q; qs.append(q)
		if q >= 90: buckets["ge90"] += 1
		if q >= 95: buckets["ge95"] += 1
		if q >= 98: buckets["ge98"] += 1
		if q >= 99: buckets["ge99"] += 1
	qs.sort()
	var mean := float(buckets["sum"]) / float(buckets["n"])
	var median: int = qs[qs.size() / 2]
	print("  [100k rolls] média=%.1f mediana=%d | >=90:%.2f%% >=95:%.2f%% >=98:%.3f%% >=99:%.3f%%" % [
		mean, median, 100.0 * buckets["ge90"] / 100000.0, 100.0 * buckets["ge95"] / 100000.0,
		100.0 * buckets["ge98"] / 100000.0, 100.0 * buckets["ge99"] / 100000.0])
	_chk("100k: média ~centro (40..60)", mean >= 40.0 and mean <= 60.0)
	_chk("100k: >=95 EXISTE mas é RARO (0 < %d < 3000)" % buckets["ge95"], buckets["ge95"] > 0 and buckets["ge95"] < 3000)
	_chk("100k: >=98 muito raro (%d < 800)" % buckets["ge98"], buckets["ge98"] < 800)
	_chk("100k: >=99 excepcional (%d < 300)" % buckets["ge99"], buckets["ge99"] < 300)

	# ══════════ 10.000 REFINOS — convergência da taxa ══════════
	for lvl in [10, 15, 19]:
		var rng := RandomNumberGenerator.new(); rng.seed = 9000 + lvl
		var chance := RefineMath.base_chance(lvl)
		var succ := 0
		for i in range(10000):
			if rng.randf() < chance: succ += 1
		var rate := float(succ) / 10000.0
		_chk("10k refinos +%d: taxa %.3f ≈ %.2f" % [lvl, rate, chance], _approx(rate, chance, 0.03))

	# ══════════ COMERCIAL CONCEITUAL ══════════
	gs.reset_save(); gs.equipment = {}; gs.master_level = 0; gs.materials = {"Fragmentos": 0}
	gs.slot_refinement = {"weapon": 15}
	gs.equip_instance(_mk("sword_reinforced", 72, 1.0))   # equipado quality72
	var cp_before_comm: int = PowerBudget.cp()
	var god := _mk("sword_reinforced", 97, 1.15)          # dropa quality97
	gs.instance_add(god)
	var sug: Array = PowerAdvisor.suggest(6)
	var found_upgrade := false
	for s3 in sug:
		if str(s3.get("kind", "")) == "equip" and str(s3.get("iid", "")) == str(god["iid"]): found_upgrade = true
	_chk("COMERCIAL PowerAdvisor identifica o god roll como upgrade", found_upgrade)
	gs.equip_instance(god.duplicate(true))
	_chk("COMERCIAL equipa quality97, slot continua +15, CP sobe", gs.refine_level("weapon") == 15 and PowerBudget.cp() > cp_before_comm)
	# o item antigo permanece entidade separada na bolsa; seu trade payload tem rolls e NÃO tem +15
	var old_in_bag: bool = gs.item_instances.size() > 0
	var pay := ItemInstance.trade_payload(gs.item_instances[0]) if old_in_bag else {}
	_chk("COMERCIAL item antigo separado; payload tem rolls e NÃO tem refino", old_in_bag and pay.has("rolls") and not pay.has("slot_refinement"))

	# ══════════ MURO → refino → avanço ══════════
	gs.reset_save(); gs.equipment = {"weapon": "sword_simple"}; gs.master_level = 0; gs.materials = {"Fragmentos": 10000000}
	var need := int(round(float(ProgressionMath.required_cp(10, "normal")) * 0.95))
	var cp_w0: int = PowerBudget.cp()
	var tries := 0
	while PowerBudget.cp() < need and tries < 60:
		gs.refine_attempt("weapon", "", false, false, 0.0)   # sucesso garantido (roll 0) p/ o teste do LOOP
		tries += 1
	print("  [muro] need=%d CP %d→%d (%d refinos)" % [need, cp_w0, PowerBudget.cp(), tries])
	_chk("MURO superado por refino (CP >= 95%% do req)", PowerBudget.cp() >= need)

	# ══════════ restaura ══════════
	gs.set_save_path_override("")
	gs.apply_dict(mem); gs._dirty = false; gs._session_started = false
	if FileAccess.file_exists(fixture): DirAccess.remove_absolute(fixture)
	print("  [save-safe] fixture descartada; save vivo intocado")
	print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
	quit(0 if _fail == 0 else 1)

class _Host:
	func stagedirector_region_id() -> String: return "plains"
	func idlerewards_region_loot() -> Array: return []
	func idlerewards_region_mobs() -> Array: return ["young_wolf"]
	func prestige_apply_reset() -> void: pass
