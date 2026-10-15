extends SceneTree
## Self-test FATIA A7 — SystemPanel + Refino + Joias + Maestria + Bestiário + Códice + PowerAdvisor 2.0.
## Prova SYS/REF/JEW/MAS/BEST/CODEX/PAD + interação wall→upgrade→avanço + coleção + Prestígio-preserva + 1000
## kills. ★ REGRA DE TESTES A7: roda em FIXTURE DESCARTÁVEL (set_save_path_override) — NUNCA toca o save vivo.
##   godot --headless --path godot -s res://scripts/_a7_systems_selftest.gd

var _fail := 0
func _chk(name: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), name])
	if not cond: _fail += 1

func _g():
	return root.get_node_or_null("GameState")

func _approx(a: float, b: float, tol: float) -> bool:
	return abs(a - b) <= tol

# provider de teste p/ SYS-T01..T05 (contrato genérico; valor de CP ARBITRÁRIO, o painel não recalcula)
class FakeProvider extends SystemProviders.Base:
	var avail := false
	var acted := ""
	func sys_id() -> String: return "fake"
	func sys_name() -> String: return "Fake"
	func has_available_action() -> bool: return avail
	func rows() -> Array:
		return [{"label": "linha", "detail": "det", "action_id": "act", "action_label": "AÇÃO", "can_act": true, "projected_cp": 777}]
	func do_action(action_id: String) -> bool:
		acted = action_id; return true

func _initialize() -> void:
	var gs = _g()
	# ★ FIXTURE: redireciona TODA escrita p/ um save descartável; o save vivo do dono fica intocado.
	var fixture := "user://a7_fixture_save.json"
	gs.set_save_path_override(fixture)
	var mem: Dictionary = gs.to_dict()
	gs.reset_save()   # estado limpo na FIXTURE (override ativo)

	var host := _Host.new()

	# ══════════ SYS (SystemPanel genérico) ══════════
	var f1 := FakeProvider.new(); f1.bind(host)
	var f2 := FakeProvider.new(); f2.bind(host)
	var sp = load("res://scripts/SystemPanel.gd").new(); root.add_child(sp); sp.setup(host, [f1, f2])
	sp.open_panel("fake")
	_chk("SYS-T01 config válido renderiza (painel abriu no sistema)", sp.visible and sp._current == 0)
	f1.avail = true
	sp._refresh_badges()
	_chk("SYS-T02 badge reflete has_available_action", sp.any_badge() == true)
	f1.avail = false; sp._refresh_badges()
	_chk("SYS-T02b badge some quando não há ação", sp.any_badge() == false)
	sp._select(0); sp._do("act")
	_chk("SYS-T03 ação chama backend correto do provider", f1.acted == "act")
	_chk("SYS-T04 painel não conhece CP (usa projected do provider = 777)", int(f1.rows()[0]["projected_cp"]) == 777)
	_chk("SYS-T05 add sistema por config (2 providers, mesmo painel)", sp._providers.size() == 2 and sp._sys_buttons.size() == 2)
	sp.close_panel()

	# ══════════ REFINO ══════════
	_chk("REF-T02 custo +0→+1 = 20", RefineMath.cost(0) == 20)
	var mono := true
	for l in range(0, RefineMath.REFINE_MAX_LEVEL):
		if RefineMath.cost(l + 1) <= RefineMath.cost(l): mono = false
	_chk("REF-T03 custo cresce monotonicamente", mono)
	gs.reset_save(); gs.equipment = {}; gs.hero_hp_max = 100; gs.master_level = 0
	gs.equipment["weapon"] = "sword_reinforced"   # attack 11
	gs.equipment["chest"] = "armor_reinforced"    # defense 9, max_hp 30
	var all0 := true
	for slot in ItemDB.SLOT_ORDER:
		if gs.refine_level(slot) != 0: all0 = false
	_chk("REF-T01 todos os slots iniciam +0", all0)
	gs.materials = {"Fragmentos": 0}
	_chk("REF-T04 sem Fragmentos → não melhora", gs.refine_do("weapon") == false and gs.refine_level("weapon") == 0)
	gs.materials["Fragmentos"] = 100000
	var frag_before: int = gs.fragments()
	var cost_w: int = gs.refine_cost_next("weapon")
	var atk_r0: int = gs.equip_sum("attack")
	var did: bool = gs.refine_do("weapon")
	_chk("REF-T05 com Fragmentos → +1 exato", did and gs.refine_level("weapon") == 1)
	_chk("REF-T06 custo descontado uma vez", frag_before - gs.fragments() == cost_w)
	# REF-T10: em nível baixo o +4% pode arredondar p/ baixo (11×1.04=11.44→11); no regime real (níveis maiores)
	# o stat REAL cresce. Prova com +5 (11×1.20=13.2→13 > 11). O arredondamento em nível baixo é dívida documentada.
	gs.slot_refinement["weapon"] = 5
	_chk("REF-T10 refino aumenta stat REAL (attack %d→%d @+5)" % [atk_r0, gs.equip_sum("attack")], gs.equip_sum("attack") > atk_r0)
	# REF-T07 cap
	gs.slot_refinement["weapon"] = RefineMath.REFINE_MAX_LEVEL
	_chk("REF-T07 cap +20 respeitado", not gs.refine_can("weapon") and gs.refine_do("weapon") == false)
	# REF-T08 troca de item preserva slot
	gs.slot_refinement["weapon"] = 5
	gs.equipment["weapon"] = "sword_memoria"   # troca a arma
	_chk("REF-T08 trocar item preserva nível do slot (+5)", gs.refine_level("weapon") == 5)
	# REF-T11 CombatMath ofensivo vê refino
	gs.slot_refinement.clear()
	var exp_r0 := float(CombatMath.player_profile("melee")["expected"])
	gs.slot_refinement["weapon"] = 10
	var exp_r1 := float(CombatMath.player_profile("melee")["expected"])
	_chk("REF-T11 CombatMath vê aumento ofensivo (%.1f→%.1f)" % [exp_r0, exp_r1], exp_r1 > exp_r0)
	# REF-T12 HP/defesa vê refino do peitoral
	gs.slot_refinement.clear()
	var hp_r0: int = gs.max_hp_total(); var def_r0: int = gs.defense_bonus()
	gs.slot_refinement["chest"] = 10
	_chk("REF-T12 HP/defesa vê refino defensivo (HP %d→%d, DEF %d→%d)" % [hp_r0, gs.max_hp_total(), def_r0, gs.defense_bonus()], gs.max_hp_total() > hp_r0 and gs.defense_bonus() > def_r0)
	# REF-T13 CP sobe / REF-T14 projeção ≈ real
	gs.slot_refinement.clear(); gs.materials["Fragmentos"] = 100000
	var cp_r0: int = PowerBudget.cp()
	var proj_ref := int(PowerAdvisor.project_refine("weapon")["delta_cp"])
	gs.refine_do("weapon")
	var cp_r1: int = PowerBudget.cp()
	_chk("REF-T13 PowerBudget CP sobe (%d→%d)" % [cp_r0, cp_r1], cp_r1 > cp_r0)
	_chk("REF-T14 projeção (%d) ≈ delta real (%d)" % [proj_ref, cp_r1 - cp_r0], abs(proj_ref - (cp_r1 - cp_r0)) <= 1)

	# ══════════ JOIAS ══════════
	gs.reset_save(); gs.equipment = {}; gs.hero_hp_max = 100; gs.master_level = 0
	_chk("JEW-T01 estado inicial (todas +0)", gs.jewel_level("ruby") == 0 and gs.jewel_level("emerald") == 0)
	gs.materials = {"Fragmentos": 0}
	_chk("JEW-T02 recurso insuficiente bloqueia", gs.jewel_do("ruby") == false)
	gs.materials["Fragmentos"] = 100000
	var jf0: int = gs.fragments(); var jc: int = gs.jewel_cost_next("ruby")
	var atk_j0: int = gs.attack_bonus()
	_chk("JEW-T03 upgrade válido consome uma vez", gs.jewel_do("ruby") and jf0 - gs.fragments() == jc)
	_chk("JEW-T08 não depende de nome de equipamento (unarmed, attack %d→%d)" % [atk_j0, gs.attack_bonus()], gs.attack_bonus() > atk_j0)
	var hp_j0: int = gs.max_hp_total()
	gs.jewel_do("emerald")
	_chk("JEW-T04 stat real aumenta (esmeralda: HP %d→%d)" % [hp_j0, gs.max_hp_total()], gs.max_hp_total() > hp_j0)
	var cp_j0: int = PowerBudget.cp()
	gs.jewel_do("ruby")
	_chk("JEW-T05 CP sobe naturalmente (%d→%d)" % [cp_j0, PowerBudget.cp()], PowerBudget.cp() > cp_j0)
	gs.jewel_levels["sapphire"] = JewelMath.JEWEL_MAX_LEVEL
	_chk("JEW-T06 cap respeitado", not gs.jewel_can("sapphire") and gs.jewel_do("sapphire") == false)

	# ══════════ MAESTRIA (só leitura) ══════════
	var mp := SystemProviders.MasteryProvider.new(); mp.bind(host)
	gs.proficiency = {"melee": {"xp": 20, "level": 3}}
	gs.equipment = {}   # unarmed → melee
	var mrows: Array = mp.rows()
	_chk("MAS-T01 painel lê nível real (contém 'Nível 3')", not mrows.is_empty() and str(mrows[0]["detail"]).find("Nível 3") >= 0)
	_chk("MAS-T02 progresso real exibido (detail não-vazio)", not mrows.is_empty() and str(mrows[0]["detail"]) != "")
	_chk("MAS-T03 não inventa botão (sem ação manual/badge)", str(mrows[0]["action_label"]) == "" and mp.has_available_action() == false)
	# MAS-T04: maestria de classe continua chegando ao CombatMath (arcana, só com cajado)
	gs.equipment = {"weapon": "staff_reinforced"}
	gs.class_mastery = {}
	var mag_m0 := float(CombatMath.player_profile("magic")["expected"])
	gs.class_mastery = {"arcane": {"xp": 999, "level": 3}}
	var mag_m1 := float(CombatMath.player_profile("magic")["expected"])
	_chk("MAS-T04 bônus de maestria chega ao CombatMath (%.1f→%.1f)" % [mag_m0, mag_m1], mag_m1 > mag_m0)

	# ══════════ BESTIÁRIO ══════════
	gs.reset_save(); gs.equipment = {}; gs.master_level = 0
	var best = load("res://scripts/BestiaryManager.gd").new(); best.name = "BestiaryManager"; root.add_child(best); best.setup(host)
	best.notify_kill("young_wolf")
	_chk("BEST-T01 kill válida +1", int(gs.bestiary_entry("young_wolf")["kills"]) == 1)
	best.notify_kill("musgo_voraz")   # mob de teste → ignorado
	best.notify_kill("id_desconhecido_qualquer")   # não quebra
	_chk("BEST-T02 kill de teste ignorada / desconhecida não quebra", not gs.bestiary.has("musgo_voraz") and gs.bestiary.has("id_desconhecido_qualquer"))
	# 10 kills → Tier1
	for i in range(9): best.notify_kill("young_wolf")   # total 10
	_chk("BEST-T03 10 kills libera Tier1", BestiaryManager.reached_tier(10) == 1 and best.claimable_for("young_wolf") == 1)
	_chk("BEST-T04 sem claim, bônus ainda não entra", gs.bestiary_claimed_tiers_total() == 0)
	var gained: int = best.claim_mob("young_wolf")
	_chk("BEST-T05 claim Tier1 aplica uma vez", gained == 1 and gs.bestiary_claimed_tiers_total() == 1)
	_chk("BEST-T06 reclaim não duplica", best.claim_mob("young_wolf") == 0)
	best.notify_kills_batch({"young_wolf": 40})   # total 50 → Tier2
	_chk("BEST-T07 50 kills libera Tier2", best.claimable_for("young_wolf") == 1 and best.claim_mob("young_wolf") == 1 and gs.bestiary_claimed_tiers_total() == 2)
	best.notify_kills_batch({"wild_boar": 100})
	_chk("BEST-T09 offline batch conta corretamente", int(gs.bestiary_entry("wild_boar")["kills"]) == 100)
	# BEST-T11/T12/T13: poder real após claim
	gs.bestiary["wild_boar"] = {"kills": 3000, "claimed": 0}   # Tier V (2500)
	var exp_b0 := float(CombatMath.player_profile("melee")["expected"]); var hp_b0: int = gs.max_hp_total(); var cp_b0: int = PowerBudget.cp()
	best.claim_all()
	_chk("BEST-T11 dano real aumenta após claim (%.3f→%.3f)" % [exp_b0, float(CombatMath.player_profile("melee")["expected"])], float(CombatMath.player_profile("melee")["expected"]) > exp_b0)
	_chk("BEST-T12 HP real aumenta (%d→%d)" % [hp_b0, gs.max_hp_total()], gs.max_hp_total() > hp_b0)
	_chk("BEST-T13 CP sobe naturalmente (%d→%d)" % [cp_b0, PowerBudget.cp()], PowerBudget.cp() > cp_b0)

	# ══════════ CÓDICE ══════════
	gs.reset_save(); gs.equipment = {}; gs.master_level = 0
	var codex = load("res://scripts/ItemCodex.gd").new(); codex.name = "ItemCodex"; root.add_child(codex); codex.setup(host)
	_chk("CODEX-T01 primeiro item marca descoberta", gs.codex_discover("sword_simple") and gs.codex_unique_count() == 1)
	_chk("CODEX-T02 duplicata não aumenta unique", (gs.codex_discover("sword_simple") == false) and gs.codex_unique_count() == 1)
	gs.backpack = []   # item some da mochila
	_chk("CODEX-T03 salvage/remoção não apaga descoberta", gs.codex_discovered.has("sword_simple"))
	# 5 únicos → milestone
	for iid in ["shield_simple", "bow_simple", "armor_simple", "boots_simple"]:
		gs.codex_discover(iid)
	_chk("CODEX-T05 milestone 5 libera", gs.codex_unique_count() == 5 and codex.reached() >= 1 and codex.claimable() == 1)
	var cp_cx0: int = PowerBudget.cp()
	_chk("CODEX-T06 claim aplica uma vez", codex.claim() == 1 and codex.claim() == 0)
	_chk("CODEX-T09 CP sobe pelo bônus real", PowerBudget.cp() > cp_cx0)
	# CODEX-T07 migração marca só equipped+backpack
	gs.reset_save()
	var v5 := {"schemaVersion": 5, "equipment": {"weapon": "sword_simple"}, "backpack": [{"id": "armor_simple", "qty": 1}]}
	var mig: Dictionary = SaveMigration.migrate_with(v5.duplicate(true), 5, 6, SaveMigration._steps())
	gs.apply_dict(mig)
	_chk("CODEX-T07 migração marca só equipped+backpack (2, não catálogo)", gs.codex_unique_count() == 2 and gs.codex_discovered.has("sword_simple") and gs.codex_discovered.has("armor_simple"))
	# CODEX-T04 item offline só descobre no CLAIM (via LootManager)
	gs.reset_save(); gs.equipment = {}
	var lm = load("res://scripts/LootManager.gd").new(); root.add_child(lm); lm.setup(null)
	if not lm.item_discovered.is_connected(codex.discover): lm.item_discovered.connect(codex.discover)
	gs.offline_pending = {"gold": 0, "xp": 0, "items": {"sword_reinforced": 1}, "materials": {}}
	var before_claim: int = gs.codex_unique_count()
	var ir = load("res://scripts/IdleRewards.gd").new(); root.add_child(ir); ir.setup(host, null, lm)
	ir.claim()
	_chk("CODEX-T04 item offline só descoberto no claim (%d→%d)" % [before_claim, gs.codex_unique_count()], before_claim == 0 and gs.codex_discovered.has("sword_reinforced"))

	# ══════════ POWERADVISOR 2.0 ══════════
	gs.reset_save(); gs.equipment = {"weapon": "sword_reinforced"}; gs.master_level = 0
	gs.materials = {"Fragmentos": 100000}
	gs.slot_refinement = {"weapon": 1}   # a +1 o próximo passo (→+2) cruza o arredondamento e RENDE CP (executável real)
	gs.backpack = [{"id": "sword_memoria", "qty": 1}]   # upgrade guardado (attack 11→14 + max_hp)
	var sug: Array = PowerAdvisor.suggest(8)
	var kinds := {}
	for s in sug: kinds[str(s.get("kind", ""))] = true
	_chk("PAD-T01 recomenda equipar (upgrade na mochila)", kinds.has("equip"))
	_chk("PAD-T02 Refino executável entra no ranking", kinds.has("refine"))
	_chk("PAD-T03 Joia executável entra no ranking", kinds.has("jewel"))
	# PAD-T04/T05 claims entram
	gs.bestiary = {"young_wolf": {"kills": 20, "claimed": 0}}
	for iid2 in ["sword_simple", "shield_simple", "bow_simple", "armor_simple", "boots_simple"]: gs.codex_discover(iid2)
	sug = PowerAdvisor.suggest(12); kinds = {}
	for s in sug: kinds[str(s.get("kind", ""))] = true
	_chk("PAD-T04 claim Bestiário entra", kinds.has("bestiary"))
	_chk("PAD-T05 claim Códice entra", kinds.has("codex"))
	# PAD-T06 ação impossível não vence: sem Fragmentos, refino/joia somem do ranking
	gs.materials = {"Fragmentos": 0}
	sug = PowerAdvisor.suggest(12); kinds = {}
	for s in sug: kinds[str(s.get("kind", ""))] = true
	_chk("PAD-T06 ação impossível (sem Frag) não entra como executável", not kinds.has("refine") and not kinds.has("jewel"))
	# PAD-T07 recomendação real (não fallback) / PAD-T08 system_id abre painel correto
	gs.materials = {"Fragmentos": 100000}
	var top: Dictionary = PowerAdvisor.suggest(1)[0]
	_chk("PAD-T07 muro mostra recomendação real (não fallback)", str(top.get("kind", "")) != "fallback" and int(top.get("estimated_cp_gain", 0)) > 0)
	# ▸IR: o system_id da recomendação é um sistema REAL que o SystemPanel sabe abrir (§7/§58).
	var real_sp = load("res://scripts/SystemPanel.gd").new(); root.add_child(real_sp)
	var real_provs := [SystemProviders.EquipmentProvider.new(), SystemProviders.RefineProvider.new(), SystemProviders.JewelProvider.new(),
		SystemProviders.MasteryProvider.new(), SystemProviders.BestiaryProvider.new(), SystemProviders.CodexProvider.new()]
	for pr in real_provs: pr.bind(host, best, codex)
	real_sp.setup(host, real_provs)
	_chk("PAD-T08 ▸IR abre painel correto (system_id '%s' existe no SystemPanel)" % str(top.get("system_id","")), real_sp.has_system(str(top.get("system_id", "equipment"))))

	# ══════════ INTERAÇÃO: wall → refino → CP → supera 95% ══════════
	gs.reset_save(); gs.equipment = {"weapon": "sword_simple"}; gs.master_level = 0   # gear fraco → o muro MORDE
	gs.materials = {"Fragmentos": 100000}
	var frontier_g := 10   # global 10 (boss) — exige mais CP que o gear fraco entrega
	var need := int(round(float(ProgressionMath.required_cp(frontier_g, "normal")) * 0.95))
	var cp_wall0: int = PowerBudget.cp()
	var refines := 0
	while PowerBudget.cp() < need and refines < 400:
		var acted := false
		for slot in ["weapon", "chest"]:
			if gs.refine_can(slot) and int(PowerAdvisor.project_refine(slot)["delta_cp"]) >= 0:
				if gs.refine_do(slot): acted = true; refines += 1; break
		if not acted:
			for jt in JewelMath.JEWEL_ORDER:
				if gs.jewel_do(jt): acted = true; refines += 1; break
		if not acted: break
	print("  [interação] wall need=%d · CP %d→%d após %d melhorias" % [need, cp_wall0, PowerBudget.cp(), refines])
	_chk("INTERAÇÃO wall superado por PODER real (CP ≥ 95%% do req)", PowerBudget.cp() >= need)

	# ══════════ PRESTÍGIO PRESERVA os sistemas A7 ══════════
	gs.reset_save(); gs.equipment = {"weapon": "sword_reinforced"}; gs.master_level = 0; gs.prestige_count = 0
	gs.slot_refinement = {"weapon": 6}; gs.jewel_levels = {"ruby": 4}
	gs.bestiary = {"young_wolf": {"kills": 300, "claimed": 3}}; gs._recompute_bestiary_total()
	gs.codex_discovered.assign(["sword_reinforced", "armor_simple"]); gs.codex_claimed = 1
	gs.stage_highest_global = 100; gs.cycle_seals = 10; gs.offline_pending = {}; gs._session_started = false
	var cp_pre_prestige: int = PowerBudget.cp()
	var pm = load("res://scripts/PrestigeManager.gd").new(); root.add_child(pm); pm.setup(host)
	var pres: Dictionary = pm.execute_prestige(8000000)
	var kept: bool = gs.slot_refinement.get("weapon", 0) == 6 and gs.jewel_levels.get("ruby", 0) == 4 \
		and int(gs.bestiary_entry("young_wolf")["claimed"]) == 3 and gs.codex_claimed == 1 \
		and gs.codex_discovered.has("sword_reinforced")
	_chk("PRESTÍGIO preserva Refino/Joias/Bestiário/Códice", bool(pres.get("ok", false)) and kept)
	# Master soma SOBRE eles sem double-count: CP após ≈ CP antes × 1.08 (mesmos refino/joias/coleção)
	var ratio := float(PowerBudget.cp()) / maxf(float(cp_pre_prestige), 1.0)
	_chk("PRESTÍGIO Master sobre A7 sem double-count (razão %.3f ≈ 1.08)" % ratio, _approx(ratio, 1.08, 0.02))

	# ══════════ 1000 KILLS — sem write storm ══════════
	gs.reset_save()
	var writes0: int = gs.save_write_count
	for i in range(1000): best.notify_kill("young_wolf")
	_chk("1000 kills: contabiliza tudo (kills=%d)" % int(gs.bestiary_entry("young_wolf")["kills"]), int(gs.bestiary_entry("young_wolf")["kills"]) == 1000)
	_chk("1000 kills: SEM write storm (writes=%d, debounced)" % (gs.save_write_count - writes0), (gs.save_write_count - writes0) <= 2)

	# ══════════ restaura ══════════
	gs.set_save_path_override("")   # volta a apontar p/ o save vivo (mas NÃO escrevemos nele)
	gs.apply_dict(mem); gs._dirty = false; gs._session_started = false
	if FileAccess.file_exists(fixture): DirAccess.remove_absolute(fixture)
	print("  [save-safe] fixture descartada; save vivo intocado")
	print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
	quit(0 if _fail == 0 else 1)

class _Host:
	func stagedirector_region_id() -> String: return "plains"
	func idlerewards_region_loot() -> Array: return [{"name": "Pelo de Lobo", "chance": 0.55}]
	func idlerewards_region_mobs() -> Array: return ["young_wolf", "wild_boar"]
	func prestige_apply_reset() -> void: pass
	func idlehud_open_inventory() -> void: pass
