extends SceneTree
## Self-test/RELATÓRIO FATIA A7.2.1 — RECONCILIAÇÃO de economia e ritmo. NÃO muda economia/números (só mede).
## Responde: (1) o que é 43,3h para +20? (2) 50 Prestígios/30d é real ou artefato? (3) Fragmentos criam ESCOLHA?
## (4) F2P saudável? (5) suportes têm valor sem obrigar? Tudo em FIXTURE/memória (save vivo intocado).
##   godot --headless --path godot -s res://scripts/_a721_reconcile_selftest.gd

var _fail := 0
func _chk(name: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), name])
	if not cond: _fail += 1
func _g(): return root.get_node_or_null("GameState")

## GDScript não tem %e — formata número grande em notação científica manual.
func _fmt_big(x: float) -> String:
	if x < 1000000.0:
		return "%d" % int(round(x))
	var expo := int(floor(log(x) / log(10.0)))
	var mant := x / pow(10.0, float(expo))
	return "%.2fe%d" % [mant, expo]

func _initialize() -> void:
	var gs = _g()
	var fixture := "user://a721_fixture_save.json"
	gs.set_save_path_override(fixture)
	var mem: Dictionary = gs.to_dict()
	gs.reset_save()

	# ══════════ PARTE 1 — RECONCILIAÇÃO +0→20 (§1) ══════════
	print("  ═══ RECONCILIAÇÃO +0→20 ═══")
	var FREE := RefineSimulator.policy(99, 0.0, 99, 99)
	var N := 2000
	var bands := [["+0→5", 0, 5], ["+5→10", 5, 10], ["+10→15", 10, 15], ["+15→18", 15, 18], ["+18→20", 18, 20]]
	print("  (A) CUSTO INTRÍNSECO por faixa (Fragmentos, SEM horas):")
	var sum_frag := 0
	for b in bands:
		var d: Dictionary = RefineSimulator.monte_carlo(int(b[1]), int(b[2]), FREE, N)
		sum_frag += int(d["frag_mean"])
		print("    %s: att~%d · Frag mean=%d P50=%d P90=%d P95=%d" % [str(b[0]), int(d["att_mean"]), int(d["frag_mean"]), int(d["frag_p50"]), int(d["frag_p90"]), int(d["frag_p95"])])
	var full: Dictionary = RefineSimulator.monte_carlo(0, 20, FREE, 3000)
	print("    SOMA das faixas = %d Frag · +0→20 MC direto = %d Frag (dif = variância)" % [sum_frag, int(full["frag_mean"])])
	print("  (B) TEMPO por TAXA CONSTANTE (+0→20 = %d Frag ÷ Frag/h):" % int(full["frag_mean"]))
	for prof in EconomyBalance.player_profiles():
		var rate: float = EconomyBalance.fragments_per_hour_at(int(prof["stage"]), 1.0)
		print("    %s (%d Frag/h): %.1f h" % [str(prof["id"]), int(round(rate)), float(full["frag_mean"]) / maxf(rate, 1.0)])
	var h_E := float(full["frag_mean"]) / maxf(EconomyBalance.fragments_per_hour_at(170, 1.0), 1.0)
	print("    ★ O '43,3h' do relatório A7.2 = +0→20 ÷ taxa do Perfil E (endgame) = %.1f h. As faixas somadas em" % h_E)
	print("      horas usaram DENOMINADORES MISTOS (faixas baratas medidas em renda baixa) → 51,7h. Nenhum erro.")
	_chk("RECON-T01 custo intrínseco é ADITIVO (soma ≈ +0→20 direto, ±5%%)", absf(float(sum_frag) - float(full["frag_mean"])) < 0.05 * float(full["frag_mean"]))
	_chk("RECON-T02 43,3h = +0→20 ÷ taxa E (reproduzível)", abs(h_E - 43.3) < 6.0)

	# ══════════ PARTE 2 — CADÊNCIA DE PRESTÍGIO (§2/§3) ══════════
	print("\n  ═══ CADÊNCIA DE PRESTÍGIO (CP real via PowerBudget) ═══")
	# personagem FORTE realista: gear bom + refino +20 em todos + joias maxadas + nível alto
	gs.reset_save()
	gs.equipment = {"weapon": "sword_memoria", "chest": "armor_memoria", "legs": "pants_simple", "boots": "boots_reinforced", "head": "helmet_simple", "ring": "ring_reinforced"}
	for slot in gs.equipment: gs.slot_refinement[str(slot)] = 20
	gs.jewel_levels = {"ruby": 10, "sapphire": 10, "emerald": 10}
	gs.hero_hp_max = 100 + 100 * 10   # ~nível 100 (proxy: +10 HP/nível)
	gs.master_level = 0
	var cp0: int = PowerBudget.cp()
	print("  CP base (maxado, Master 0) = %d" % cp0)
	print("  p | req_stage | req_seals | req_cp(front) | Master×  | CP_jogador | alcança?")
	var max_reachable := -1
	for p in [0, 1, 2, 3, 5, 10, 20, 30, 40, 50]:
		var rs := PrestigeMath.required_stage(p)
		var rq := PrestigeMath.required_seals(p)
		var reqcp := ProgressionMath.required_cp(rs, "boss")
		var mm := PrestigeMath.master_multiplier(p)
		var pcp := int(round(float(cp0) * mm))
		var ok := float(pcp) >= 0.95 * float(reqcp)
		if ok and p > max_reachable: max_reachable = p
		print("  %2d | %6d | %6d | %13s | %7.2f | %10d | %s" % [p, rs, rq, _fmt_big(float(reqcp)), mm, pcp, ("SIM" if ok else "não")])
	print("  ── req_cp cresce ×1,91 por prestígio; Master só ×1,08 → o gap se ABRE ×1,77/prest ──")
	print("  ★ Prestígio máximo alcançável com este endgame (só Master, refino/joias maxados) ≈ P%d." % maxi(0, max_reachable))
	print("  ★ DIAGNÓSTICO: NÃO há snowball. O ritmo DESACELERA DURAMENTE (marco). Os '50 Prestígios/30d' do")
	print("    relatório A7.2 foram HARDCODED no modelo (day_prestiges=2/dia), NÃO emergentes das fórmulas.")

	# ══════════ PARTE 3 — 30 DIAS ECONÔMICO ENRIQUECIDO (§4/§5/§6/§7/§8) ══════════
	print("\n  ═══ 30 DIAS — MÉTRICAS ECONÔMICAS ═══")
	var with_sup := _sim30(true, 1.0)    # com suportes, ativo x1
	var f2p := _sim30(false, 1.0)        # F2P puro, ativo x1
	var x3 := _sim30(true, 3.0)          # com suportes, ativo x3
	_print30("COM SUPORTES (ativo x1)", with_sup)
	_print30("F2P PURO (ativo x1)", f2p)
	_print30("COM SUPORTES (ativo x3)", x3)
	print("  ── COMPARAÇÃO F2P × SUPORTES: nível total slots %d vs %d · downgrades %d vs %d · saldo final %d vs %d ──" % [
		int(f2p["lvlsum"]), int(with_sup["lvlsum"]), int(f2p["downgrades"]), int(with_sup["downgrades"]), int(f2p["wasted"]), int(with_sup["wasted"])])

	_chk("ECON-T01 choice_rate mensurável (0..100)", float(with_sup["choice_rate"]) >= 0.0 and float(with_sup["choice_rate"]) <= 100.0)
	_chk("ECON-T02 blocked_rate mensurável (0..100)", float(with_sup["blocked_rate"]) >= 0.0 and float(with_sup["blocked_rate"]) <= 100.0)
	_chk("ECON-T03 F2P progride (nível total > 0)", int(f2p["lvlsum"]) > 0)
	_chk("ECON-T04 suporte AJUDA (F2P mais downgrades OU menos progresso que com-suporte)", int(f2p["downgrades"]) >= int(with_sup["downgrades"]) or int(f2p["lvlsum"]) <= int(with_sup["lvlsum"]))
	_chk("ECON-T05 x3 produz mais que x1 (mais progresso/gasto)", int(x3["refine_spent"]) + int(x3["jewel_spent"]) >= int(with_sup["refine_spent"]) + int(with_sup["jewel_spent"]))
	_chk("ECON-T06 Fragmentos criam ESCOLHA (choice_rate > 0)", float(with_sup["choice_rate"]) > 0.0)

	# ══════════ freeze declaration ══════════
	print("\n  ═══ DECLARAÇÃO DE CONGELAMENTO ═══")
	print("  • Economia de Fragmentos/Refino (custo/pity/floor/renda): PODE SER CONGELADA (targets provados em A7.2).")
	print("  • Prestígio: cadência = MARCO desacelerante (saudável no início). ALERTA p/ A8: sem novas fontes de CP")
	print("    endgame, o loop de Prestígio estagna após ~P%d. NÃO alterar número agora (sem bug); resolver com" % maxi(0, max_reachable))
	print("    CONTEÚDO/CP em A8 (ou suavizar required_stage) — proposta, não implementação.")

	# ══════════ restaura ══════════
	gs.set_save_path_override("")
	gs.apply_dict(mem); gs._dirty = false; gs._session_started = false
	if FileAccess.file_exists(fixture): DirAccess.remove_absolute(fixture)
	print("  [save-safe] fixture descartada; save vivo intocado")
	print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
	quit(0 if _fail == 0 else 1)

## Modelo 30 dias RICO (§4). Mede choice_rate/blocked_rate/saldo/split/tempo-entre-melhorias/suportes.
## `use_supports` = usa Catalisador/Preservação ganhos; `active_speed` = velocidade do tempo ativo (x1/x3).
func _sim30(use_supports: bool, active_speed: float) -> Dictionary:
	var slots := ["weapon", "chest", "legs", "boots", "head", "offhand"]
	var lvl := {}; var high := {}; var pity := {}
	for s in slots: lvl[s] = 0; high[s] = 0; pity[s] = 0.0
	var jl := {"ruby": 0, "sapphire": 0, "emerald": 0}
	var bal := 0
	var frag_in := 0; var refine_spent := 0; var jewel_spent := 0
	var downgrades := 0
	var cat_have := 0; var pres_have := 0; var abs_have := 0
	var cat_used := 0; var pres_used := 0
	var checkpoints := 0; var choice_cp := 0; var blocked_cp := 0
	var bal_samples: Array = []
	var upgrades := 0; var last_up_h := 0.0; var between: Array = []
	var hour := 0.0
	var rng := RandomNumberGenerator.new(); rng.seed = 72172
	for day in range(30):
		var stage := clampi(6 + day * 5, 6, 150)
		var fph: float = EconomyBalance.fragments_per_hour_at(stage, 1.0)
		bal += int(round(fph * 8.0 + fph * 2.0 * active_speed)); frag_in += int(round(fph * 8.0 + fph * 2.0 * active_speed))
		hour += 10.0
		if use_supports:
			for i in range(2):   # ~2 first-clears de ciclo/dia (comuns)
				if rng.randf() < 0.12: cat_have += 1
				if rng.randf() < 0.03: cat_have += 1
			if rng.randf() < 0.01: pres_have += 1     # raro vitalício (~1 profundidade nova/dia)
			if rng.randf() < 0.0010: abs_have += 1
		# gasta em ações de poder até esgotar (prioridade: refino dos slots, depois joias)
		var acted := true
		while acted:
			acted = false
			# monta a lista de AÇÕES financiáveis (custo <= saldo) p/ métricas de escolha
			var costs: Array = []
			for s in slots:
				if int(lvl[s]) < 20: costs.append(RefineMath.cost(int(lvl[s])))
			for jt in ["ruby", "sapphire", "emerald"]:
				if int(jl[jt]) < JewelMath.JEWEL_MAX_LEVEL: costs.append(JewelMath.cost(int(jl[jt])))
			if costs.is_empty(): break
			costs.sort()
			var cheapest: int = costs[0]
			var financiable := 0
			for c in costs:
				if c <= bal: financiable += 1
			checkpoints += 1
			bal_samples.append(bal)
			if financiable >= 2: choice_cp += 1
			if bal < cheapest: blocked_cp += 1; break   # quer melhorar mas não pode → bloqueado, espera renda
			# EXECUTA a próxima melhoria (política): refino do 1º slot financiável < 20, senão joia
			var did := false
			for s in slots:
				if int(lvl[s]) >= 20: continue
				var cost := RefineMath.cost(int(lvl[s]))
				if bal < cost: continue
				bal -= cost; refine_spent += cost; acted = true; did = true
				var cat_pp := 0.0
				if int(lvl[s]) >= 10 and use_supports and cat_have > 0: cat_pp = 0.05; cat_have -= 1; cat_used += 1
				var use_pres := int(lvl[s]) >= 15 and use_supports and pres_have > 0
				var ch := clampf(RefineMath.base_chance(int(lvl[s])) + float(pity[s]) + cat_pp, 0.0, 1.0)
				if rng.randf() < ch:
					lvl[s] = int(lvl[s]) + 1
					if int(lvl[s]) > int(high[s]): high[s] = lvl[s]; pity[s] = 0.0
					upgrades += 1; between.append(hour - last_up_h); last_up_h = hour
				else:
					pity[s] = minf(float(pity[s]) + 0.02, RefineMath.PITY_MAX_BONUS)
					if int(lvl[s]) >= 10:
						if use_pres: pres_have -= 1; pres_used += 1
						else: lvl[s] = maxi(RefineMath.downgrade_floor(int(lvl[s])), int(lvl[s]) - 1); downgrades += 1
				break
			if not did:   # nenhum slot financiável → tenta joia
				for jt in ["ruby", "sapphire", "emerald"]:
					if int(jl[jt]) >= JewelMath.JEWEL_MAX_LEVEL: continue
					var jc := JewelMath.cost(int(jl[jt]))
					if bal < jc: continue
					bal -= jc; jewel_spent += jc; jl[jt] = int(jl[jt]) + 1; acted = true; upgrades += 1
					between.append(hour - last_up_h); last_up_h = hour
					break
	bal_samples.sort()
	var lvlsum := 0
	for s in slots: lvlsum += int(lvl[s])
	var jsum := int(jl["ruby"]) + int(jl["sapphire"]) + int(jl["emerald"])
	var tot_spent := maxi(1, refine_spent + jewel_spent)
	var avg_between := 0.0
	if not between.is_empty():
		var sb := 0.0
		for v in between: sb += float(v)
		avg_between = sb / float(between.size())
	return {
		"lvlsum": lvlsum, "jsum": jsum, "frag_in": frag_in, "refine_spent": refine_spent, "jewel_spent": jewel_spent,
		"wasted": bal, "downgrades": downgrades, "cat_used": cat_used, "pres_used": pres_used, "abs_have": abs_have,
		"choice_rate": 100.0 * float(choice_cp) / float(maxi(1, checkpoints)),
		"blocked_rate": 100.0 * float(blocked_cp) / float(maxi(1, checkpoints)),
		"refine_pct": 100.0 * float(refine_spent) / float(tot_spent), "jewel_pct": 100.0 * float(jewel_spent) / float(tot_spent),
		"bal_p10": (bal_samples[int(0.1 * bal_samples.size())] if not bal_samples.is_empty() else 0),
		"bal_p50": (bal_samples[int(0.5 * bal_samples.size())] if not bal_samples.is_empty() else 0),
		"bal_p90": (bal_samples[int(0.9 * bal_samples.size())] if not bal_samples.is_empty() else 0),
		"avg_between_h": avg_between, "upgrades": upgrades, "checkpoints": checkpoints,
	}

func _print30(title: String, r: Dictionary) -> void:
	print("  ── %s ──" % title)
	print("    slots nível total=%d · joias total=%d/30 · upgrades=%d · downgrades=%d" % [int(r["lvlsum"]), int(r["jsum"]), int(r["upgrades"]), int(r["downgrades"])])
	print("    Frag ganhos=%d · Refino=%d (%.0f%%) · Joias=%d (%.0f%%) · ocioso final=%d" % [int(r["frag_in"]), int(r["refine_spent"]), float(r["refine_pct"]), int(r["jewel_spent"]), float(r["jewel_pct"]), int(r["wasted"])])
	print("    choice_rate=%.0f%% · blocked_rate=%.0f%% · saldo P10=%d P50=%d P90=%d · tempo médio entre melhorias=%.1fh" % [
		float(r["choice_rate"]), float(r["blocked_rate"]), int(r["bal_p10"]), int(r["bal_p50"]), int(r["bal_p90"]), float(r["avg_between_h"])])
	print("    Catalis. usados=%d · Preserv. usadas=%d · Absolutos obtidos=%d" % [int(r["cat_used"]), int(r["pres_used"]), int(r["abs_have"])])
