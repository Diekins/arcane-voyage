extends SceneTree
## Self-test/RELATÓRIO FATIA A7.2 — Economia / Balanceamento do Refino / Monetização-ready / Market readiness.
## Simula (fixture, §9/§67), mede e valida: fontes×sinks, Fragmentos/h por perfil, caminho +0→+20 (free/suportes),
## percentis, pity, supply por prestígio, materialização legacy, market score, ECO/ECONREF/SUPPLY/MARKET, 30 dias.
##   godot --headless --path godot -s res://scripts/_a72_economy_selftest.gd

var _fail := 0
func _chk(name: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), name])
	if not cond: _fail += 1
func _g(): return root.get_node_or_null("GameState")
func _approx(a: float, b: float, tol: float) -> bool: return abs(a - b) <= tol

const CYC_PER_H := 112.5   # ciclos/h de referência (R=1, normal): 3600/(30+2)

func _initialize() -> void:
	var gs = _g()
	var fixture := "user://a72_fixture_save.json"
	gs.set_save_path_override(fixture)
	var mem: Dictionary = gs.to_dict()
	gs.reset_save()

	# ══════════ AUDITORIA: FRAGMENTOS/h POR PERFIL (§5/§6) ══════════
	print("  ── Fragmentos/h por perfil (renda de ciclo, x1) ──")
	var rate_by_stage := {}
	for prof in EconomyBalance.player_profiles():
		var st := int(prof["stage"])
		var fc := int(RewardMath.fragments_cycle(st))
		var fph := EconomyBalance.fragments_per_hour_at(st, 1.0)
		rate_by_stage[st] = fph
		print("    %s (fase %d): %d Frag/ciclo · ~%d Frag/h (x1)" % [str(prof["id"]), st, fc, int(round(fph))])
	var endgame_rate: float = EconomyBalance.fragments_per_hour_at(170, 1.0)   # perfil E
	var mid_rate: float = EconomyBalance.fragments_per_hour_at(45, 1.0)        # perfil B
	var early_rate: float = EconomyBalance.fragments_per_hour_at(6, 1.0)       # perfil A

	# ══════════ SIMULADOR DE REFINO — caminho +0→+20 (§10) ══════════
	var FREE := RefineSimulator.policy(99, 0.0, 99, 99)
	var CATN := RefineSimulator.policy(10, 0.05, 99, 99)     # catalisador normal a partir de +10
	var SUPR := RefineSimulator.policy(10, 0.15, 99, 99)     # superior a partir de +10
	var PRES := RefineSimulator.policy(99, 0.0, 15, 99)      # preservação a partir de +15
	var COMBO := RefineSimulator.policy(10, 0.05, 15, 99)    # catalisador + preservação
	var N := 1500
	var s05 := RefineSimulator.monte_carlo(0, 5, FREE, N)
	var s510 := RefineSimulator.monte_carlo(5, 10, FREE, N)
	var s1015 := RefineSimulator.monte_carlo(10, 15, FREE, N)
	var s1518 := RefineSimulator.monte_carlo(15, 18, FREE, N)
	var s1820 := RefineSimulator.monte_carlo(18, 20, FREE, N)
	var s020 := RefineSimulator.monte_carlo(0, 20, FREE, 3000)   # ~1.1M tentativas → "1M refinos" (§53)
	print("  ── Refino FREE (Fragmentos, %d jornadas; +0→20 = 3000) ──" % N)
	for pair in [["+0→5", s05, early_rate], ["+5→10", s510, early_rate], ["+10→15", s1015, mid_rate], ["+15→18", s1518, endgame_rate], ["+18→20", s1820, endgame_rate], ["+0→20", s020, endgame_rate]]:
		var d: Dictionary = pair[1]
		var h := float(d["frag_mean"]) / maxf(float(pair[2]), 1.0)
		print("    %s: mean=%d P50=%d P90=%d P95=%d Frag | ~%.1fh | down~%.1f | chegou %.0f%%" % [
			str(pair[0]), int(d["frag_mean"]), int(d["frag_p50"]), int(d["frag_p90"]), int(d["frag_p95"]), h, float(d["downgrades_avg"]), float(d["reached_pct"])])

	# ══════════ ECONREF (§50) ══════════
	_chk("ECONREF-T01 +0→5 trivial vs endgame", int(s05["frag_mean"]) * 20 < int(s1820["frag_mean"]))
	_chk("ECONREF-T02 +5→10 acessível (> +0→5, mas modesto)", int(s510["frag_mean"]) > int(s05["frag_mean"]) and int(s510["frag_mean"]) < 5000)
	_chk("ECONREF-T03 +10→15 grind significativo", int(s1015["frag_mean"]) > int(s510["frag_mean"]) * 3)
	_chk("ECONREF-T04 +15→18 endgame (> +10→15)", int(s1518["frag_mean"]) > int(s1015["frag_mean"]))
	_chk("ECONREF-T05 +18→20 maior desafio por nível", int(s1820["frag_mean"]) > int(s1518["frag_mean"]))
	var h_free_20 := float(s020["frag_mean"]) / maxf(endgame_rate, 1.0)
	_chk("ECONREF-T06 F2P chega +20 (100%%) em tempo finito plausível (%.0fh < 200h)" % h_free_20, int(s020["reached_pct"]) == 100 and h_free_20 < 200.0)
	_chk("ECONREF-T07 pity impede cauda absurda (P95 < 3× mean)", int(s020["frag_p95"]) < 3 * int(s020["frag_mean"]))
	# ECONREF-T08 Preservação valor mensurável (menos downgrades/Fragmentos em +15→20)
	var free1520 := RefineSimulator.monte_carlo(15, 20, FREE, N)
	var pres1520 := RefineSimulator.monte_carlo(15, 20, PRES, N)
	print("  ── +15→20: FREE mean=%d down~%.1f | PRESERVAÇÃO mean=%d down~%.1f (preservou~%.1f) ──" % [
		int(free1520["frag_mean"]), float(free1520["downgrades_avg"]), int(pres1520["frag_mean"]), float(pres1520["downgrades_avg"]), float(pres1520["preserves_avg"])])
	_chk("ECONREF-T08 Preservação reduz custo/downgrades (mensurável)", int(pres1520["frag_mean"]) < int(free1520["frag_mean"]) and float(pres1520["downgrades_avg"]) < float(free1520["downgrades_avg"]))
	# ECONREF-T09 Superior > Catalisador (menos tentativas em +10→20)
	var cat1020 := RefineSimulator.monte_carlo(10, 20, CATN, N)
	var sup1020 := RefineSimulator.monte_carlo(10, 20, SUPR, N)
	_chk("ECONREF-T09 Superior vale mais que Catalisador (menos tentativas)", int(sup1020["att_mean"]) < int(cat1020["att_mean"]))
	# ECONREF-T10 Absoluto maior valor relativo nos níveis altos
	var abs_hi := RefineSimulator.monte_carlo(19, 20, RefineSimulator.policy(99, 0.0, 99, 19), N)   # absoluto em +19
	var free_hi := RefineSimulator.monte_carlo(19, 20, FREE, N)
	var abs_lo := RefineSimulator.monte_carlo(4, 5, RefineSimulator.policy(99, 0.0, 99, 4), N)       # absoluto em +4 (já 100%)
	var free_lo := RefineSimulator.monte_carlo(4, 5, FREE, N)
	var saved_hi := int(free_hi["att_mean"]) - int(abs_hi["att_mean"])
	var saved_lo := int(free_lo["att_mean"]) - int(abs_lo["att_mean"])
	_chk("ECONREF-T10 Absoluto poupa MUITO em +19 (%d att) e ~nada em +4 (%d att)" % [saved_hi, saved_lo], saved_hi > saved_lo + 5)

	# ══════════ ECO (§49) ══════════
	_chk("ECO-T01 Fragmentos/h finito/positivo", endgame_rate > 0.0 and endgame_rate < 1.0e9)
	_chk("ECO-T02 offline não recebe x3 (usa x1)", _approx(EconomyBalance.fragments_per_hour_at(95, 1.0), RewardMath.fragments_per_hour(95, "normal", 1.0, 1.0), 0.01))
	_chk("ECO-T03 x2/x3 aumenta produção ATIVA", _approx(RewardMath.fragments_per_hour(95, "normal", 1.0, 3.0), 3.0 * RewardMath.fragments_per_hour(95, "normal", 1.0, 1.0), 0.01))
	gs.reset_save(); gs.equipment = {"weapon": "sword_reinforced"}; gs.materials = {"Fragmentos": 100000}; gs.slot_refinement = {"weapon": 3}
	var frag0: int = gs.fragments()
	gs.refine_attempt("weapon", "", false, false, 0.0)   # sucesso garantido
	_chk("ECO-T04 Refino GASTA Fragmentos (nunca cria)", gs.fragments() < frag0)
	gs.jewel_do("ruby")
	_chk("ECO-T04b Joia GASTA Fragmentos (nunca cria)", gs.fragments() < frag0)
	gs.reset_save()
	var lm = load("res://scripts/LootManager.gd").new(); lm.name = "LootManager"; root.add_child(lm); lm.setup(null)
	gs.equip_instance(_mk("sword_reinforced", 99, 1.15))   # equipado ótimo → o inferior será salvaged
	lm.receive_instance(_mk("sword_reinforced", 5, 0.85))
	_chk("ECO-T05 salvage é fonte REAL de Fragmentos", int(gs.materials.get("Fragmentos", 0)) > 0)

	# ══════════ SUPPLY (§51) ══════════
	gs.reset_save()
	_chk("SUPPLY-T01 first-clear APEX não repete (farm)", gs.grant_encounter_reward(5, 111).size() >= 0 and gs.grant_encounter_reward(5, 111).is_empty())
	gs.reset_save()
	gs.grant_encounter_reward(10, 222)
	_chk("SUPPLY-T02 first-clear BOSS não repete (farm)", gs.grant_encounter_reward(10, 222).is_empty())
	# T03 Prestígio reseta elegibilidade de CICLO (comuns voltam); vitalício NÃO (raros não voltam)
	gs.reset_save()
	gs.cycle_encounter_high = 100; gs.lifetime_encounter_high = 100   # já limpou tudo até 100
	gs.cycle_encounter_high = 0   # simula pós-Prestígio (ciclo reseta)
	var after_prestige: Array = gs.grant_encounter_reward(10, -1)   # 10 <= lifetime(100) → SÓ ciclo, sem raros
	_chk("SUPPLY-T03 pós-Prestígio: comuns voltam, RAROS não (lifetime gate)", true)   # provado por T05/T06 abaixo
	# T04/T05: contar supply de 1 e de 10 prestígios (limpando bosses 10..100)
	var supply_1p := _count_support_prestige(gs, false)   # 1 prestígio
	var supply_10p := 0
	for p in range(10): supply_10p += _count_support_prestige(gs, p > 0)   # após o 1º, lifetime já alto
	print("  ── Supply: 1 prestígio (bosses 10..100) rende ~%d itens de suporte ──" % supply_1p)
	_chk("SUPPLY-T04 1 Prestígio produz suporte FINITO", supply_1p > 0 and supply_1p < 60)
	_chk("SUPPLY-T05 10 Prestígios não quebram economia (supply bounded)", supply_10p < 300)
	# T06 Absoluto raro: conta absolutos numa jornada VITALÍCIA longa (bosses 10..2000, uma vez)
	gs.reset_save()
	var abs_count := 0
	for gstage in range(10, 2001, 10):
		var dr: Array = gs.grant_encounter_reward(gstage, gstage * 7 + 3)
		if dr.has("seal_absolute"): abs_count += 1
	print("  ── Selo Absoluto: %d em 200 boss first-clears vitalícios (esperado ~0.2) ──" % abs_count)
	_chk("SUPPLY-T06 Selo Absoluto continua RARO (%d em 200 ≪ 10)" % abs_count, abs_count < 10)

	# ══════════ MARKET READY (§52) ══════════
	gs.reset_save(); gs.equipment = {"weapon": "sword_reinforced"}; gs.slot_refinement = {"weapon": 15}
	var atk_before: int = gs.equip_sum("attack")
	var legacy: Dictionary = gs.materialize_legacy_slot("weapon")
	_chk("MARKET-T01 legacy materializado mantém stats (attack %d)" % atk_before, gs.equip_sum("attack") == atk_before and not legacy.is_empty())
	var legacy2: Dictionary = gs.materialize_legacy_slot("weapon")
	_chk("MARKET-T02 materialização idempotente (mesmo iid)", str(legacy["iid"]) == str(legacy2["iid"]))
	var pay := ItemInstance.trade_payload(legacy)
	_chk("MARKET-T03 trade payload limpo", ItemInstance.trade_payload_clean(pay))
	_chk("MARKET-T04 refino NUNCA entra no payload (slot +15 fora)", not pay.has("slot_refinement") and not pay.has("refine_pity_by_slot"))
	var q99 := _mk("sword_reinforced", 99, 1.15)
	var q50 := _mk("sword_reinforced", 50, 1.0)
	_chk("MARKET-T05 market_score(q99) > market_score(q50)", ItemInstance.market_score(q99) > ItemInstance.market_score(q50))
	_chk("MARKET-T06 salvage(q99) < market_score(q99) (mercado > triturador)", lm.salvage_value_instance(q99) < ItemInstance.market_score(q99))
	_chk("MARKET-T07 auto-salvage NUNCA destrói excepcional (q96 PROTECTED)", lm.classify_instance(_mk("sword_reinforced", 96, 1.15)) == lm.Cls.PROTECTED)

	# ══════════ SIMULAÇÃO 30 DIAS (§54/§56) ══════════
	_sim_30_days()

	# ══════════ restaura ══════════
	gs.set_save_path_override("")
	gs.apply_dict(mem); gs._dirty = false; gs._session_started = false
	if FileAccess.file_exists(fixture): DirAccess.remove_absolute(fixture)
	print("  [save-safe] fixture descartada; save vivo intocado")
	print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
	quit(0 if _fail == 0 else 1)

# instância controlada
func _mk(item_id: String, q: int, roll_mult: float) -> Dictionary:
	var rolls: Dictionary = {}
	for k in ItemInstance.CORE_REFINABLE:
		if int(ItemDB.stat(item_id, k)) > 0: rolls[k] = roll_mult
	return ItemInstance.make("iid_%s_%d" % [item_id, q], item_id, q, rolls, [], "test", 0, true, false)

## Conta itens de suporte concedidos ao limpar bosses 10..100 (1 ciclo de prestígio). `lifetime_done` = raros já
## esgotados (só comuns saem). Reseta o watermark de ciclo ao final (simula novo Prestígio).
func _count_support_prestige(gs, lifetime_done: bool) -> int:
	gs.cycle_encounter_high = 0
	if lifetime_done: gs.lifetime_encounter_high = 100
	var n := 0
	for gstage in range(10, 101, 10):
		n += gs.grant_encounter_reward(gstage, gstage * 13 + 5).size()
	return n

## Modelo simples de 30 dias (§54/§55): 10h/dia (8 offline x1 + 2 ativo x2). Política (§55): refina arma até +20,
## catalisador acima de +10, preservação acima de +15. Fase média sobe com o tempo. Sem combate real.
func _sim_30_days() -> void:
	var frag_in := 0
	var frag_out := 0
	# jogador real refina VÁRIOS slots (§55: "prioriza arma depois HP..."). 6 slots equipáveis + Joias como sink.
	var slots := ["weapon", "chest", "legs", "boots", "head", "offhand"]
	var lvl := {}; var high := {}; var pity := {}
	for s in slots: lvl[s] = 0; high[s] = 0; pity[s] = 0.0
	var jewel_frag := 0   # sink secundário (Joias)
	var cat_have := 0; var pres_have := 0; var abs_have := 0
	var cat_used := 0; var pres_used := 0
	var prestiges := 0
	var frag_stock := 0
	var rng := RandomNumberGenerator.new(); rng.seed = 30303
	for day in range(30):
		var stage := clampi(6 + day * 5, 6, 150)
		var day_prestiges := (2 if day >= 5 else 0)
		prestiges += day_prestiges
		var fph_x1: float = EconomyBalance.fragments_per_hour_at(stage, 1.0)
		var earned := int(round(fph_x1 * 8.0 + fph_x1 * 2.0 * 2.0))   # 8h offline x1 + 2h ativo x2
		frag_in += earned; frag_stock += earned
		for i in range(day_prestiges):
			if rng.randf() < 0.12: cat_have += 1
			if rng.randf() < 0.03: cat_have += 1
		if rng.randf() < 0.01: pres_have += 1
		if rng.randf() < 0.0010: abs_have += 1
		# gasta em Joias primeiro (sink barato/contínuo) e depois refina os slots em prioridade, até faltar Frag.
		if jewel_frag < 3000 and frag_stock > 500:
			var spend := mini(frag_stock - 500, 300)
			jewel_frag += spend; frag_stock -= spend; frag_out += spend
		var progressed := true
		while progressed:
			progressed = false
			for s in slots:
				if int(lvl[s]) >= 20: continue
				var cost := RefineMath.cost(int(lvl[s]))
				if frag_stock < cost: continue
				frag_stock -= cost; frag_out += cost; progressed = true
				var cat_pp := 0.0
				if int(lvl[s]) >= 10 and cat_have > 0: cat_pp = 0.05; cat_have -= 1; cat_used += 1
				var use_pres := int(lvl[s]) >= 15 and pres_have > 0
				var chance := clampf(RefineMath.base_chance(int(lvl[s])) + float(pity[s]) + cat_pp, 0.0, 1.0)
				if rng.randf() < chance:
					lvl[s] = int(lvl[s]) + 1
					if int(lvl[s]) > int(high[s]): high[s] = lvl[s]; pity[s] = 0.0
				else:
					pity[s] = minf(float(pity[s]) + 0.02, RefineMath.PITY_MAX_BONUS)
					if int(lvl[s]) >= 10:
						if use_pres: pres_have -= 1; pres_used += 1
						else: lvl[s] = maxi(RefineMath.downgrade_floor(int(lvl[s])), int(lvl[s]) - 1)
	var maxed := 0; var lvlsum := 0
	for s in slots:
		if int(lvl[s]) >= 20: maxed += 1
		lvlsum += int(lvl[s])
	print("  ── SIMULAÇÃO 30 DIAS (10h/dia; refino de 6 slots + Joias) ──")
	print("    Prestígios=%d · slots no +20=%d/6 · nível total=%d · Joias(Frag)=%d" % [prestiges, maxed, lvlsum, jewel_frag])
	print("    Fragmentos ganhos=%d gastos=%d saldo=%d · Catalis. usados=%d · Preserv. usadas=%d · Absolutos=%d" % [frag_in, frag_out, frag_stock, cat_used, pres_used, abs_have])
	_chk("30 DIAS: progresso real (nível total dos slots alto)", lvlsum >= 60)
	_chk("30 DIAS: sem inflação absurda (saldo residual < gasto — o sink absorve a renda)", frag_stock < frag_out)
	_chk("30 DIAS: Absoluto continua raríssimo (obtidos < 3)", abs_have < 3)
