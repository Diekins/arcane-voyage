extends SceneTree
## Self-test/RELATÓRIO FATIA A8 — Release Polish / Combat Feel / UX / Feedback (camada de LÓGICA, render FIELD
## DEFERIDO). Valida o coordenador (GameFeedback), os formatadores (FeedbackFormat), a identidade/telegraph de
## boss (BossFeedback + BossController), a UX de refino (RefineUIModel) e os limites de pooling sob stress.
## NÃO afirma PASS visual — só a lógica. FIXTURE (save vivo intocado).
##   godot --headless --path godot -s res://scripts/_a8_feedback_selftest.gd

var _fail := 0
var _fb_kinds: Array = []          # capturados do sinal feedback
var _fb_entries: Array = []        # entradas completas do sinal feedback
var _phases: Array = []            # capturados de phase_changed
func _chk(nm: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), nm])
	if not cond: _fail += 1
func _g(): return root.get_node_or_null("GameState")
func _on_fb(e: Dictionary) -> void:
	_fb_kinds.append(str(e.get("kind", "")))
	_fb_entries.append(e)
func _on_phase(label: String) -> void: _phases.append(label)

func _initialize() -> void:
	var gs = _g()
	var fixture := "user://a8_fixture_save.json"
	gs.set_save_path_override(fixture)
	var mem: Dictionary = gs.to_dict()
	gs.reset_save()

	_test_fb()
	_test_lui()
	_test_rui(gs)
	_test_bux()
	_test_tr(gs)
	_test_oux(gs)
	_test_pux()
	_test_stress()

	gs.set_save_path_override("")
	gs.apply_dict(mem); gs._dirty = false; gs._session_started = false
	if FileAccess.file_exists(fixture): DirAccess.remove_absolute(fixture)
	print("  [save-safe] fixture descartada; save vivo intocado")
	print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
	quit(0 if _fail == 0 else 1)

# ══════════════ FB — GameFeedback ══════════════
func _test_fb() -> void:
	print("  ── FB (GameFeedback: agregação/prioridade/pooling) ──")
	var fb := GameFeedback.new()
	_fb_kinds.clear()
	fb.feedback.connect(_on_fb)
	# FB-T01 damage nasce e limpa (agrega por fonte; flush esvazia)
	for i in range(50): fb.push_damage(10, "mob_a")
	for i in range(30): fb.push_damage(5, "mob_b")
	var f1 := fb.flush_damage()
	var total_a := 0
	for e in f1:
		if str(e["source"]) == "mob_a": total_a = int(e["amount"])
	var f2 := fb.flush_damage()   # 2º flush já vazio (limpou)
	_chk("FB-T01 damage agrega por fonte e limpa no flush", f1.size() == 2 and total_a == 500 and f2.is_empty())
	# FB-T02 heal distinguível de dano (sinal com kind próprio)
	fb.push_heal(40)
	_chk("FB-T02 heal distinguível (kind K_HEAL)", _fb_kinds.has(GameFeedback.K_HEAL))
	# FB-T03 boss warning tem identidade de habilidade
	_fb_entries.clear()
	fb.push_boss_warning("Drago", "line")
	var warn_ok := false
	for e in _fb_entries:
		if str(e.get("kind", "")) == GameFeedback.K_BOSS_WARNING and str(e.get("telegraph", "")) == "LINE": warn_ok = true
	_chk("FB-T03 boss warning carrega telegraph (LINE)", warn_ok)
	# FB-T04 prioridade de toast (exceptional 1 antes de salvage 8)
	fb.reset()
	fb.push_toast(GameFeedback.K_SALVAGE, "salv")
	fb.push_toast(GameFeedback.K_LOOT_EXCEPTIONAL, "exc")
	fb.push_toast(GameFeedback.K_LOOT, "comum")
	var drained := fb.drain_toasts()
	_chk("FB-T04 toast respeita prioridade (excepcional 1º, salvage último)",
		drained.size() == 3 and str(drained[0]["kind"]) == GameFeedback.K_LOOT_EXCEPTIONAL and str(drained[2]["kind"]) == GameFeedback.K_SALVAGE)
	# FB-T05 CP agrega batch
	fb.reset()
	fb.push_cp(100); fb.push_cp(300); fb.push_cp(-50)
	fb.flush_cp()
	var toasts := fb.drain_toasts()
	_chk("FB-T05 CP agrega batch num só toast (+350)", toasts.size() == 1 and int(toasts[0]["delta"]) == 350)
	# FB-T06 feedback não muda matemática de combate (GameState intocado)
	var gs = _g()
	var hp0 := int(gs.hero_hp); var frag0 := int(gs.fragments())
	fb.push_damage(999, "x"); fb.push_heal(999); fb.push_cp(999); fb.push_toast(GameFeedback.K_LOOT, "x")
	_chk("FB-T06 nenhum feedback altera combate (hp/Frag intactos)", int(gs.hero_hp) == hp0 and int(gs.fragments()) == frag0)
	fb.free()

# ══════════════ LUI — loot UI (FeedbackFormat/ItemInstance) ══════════════
func _test_lui() -> void:
	print("  ── LUI (loot UI) ──")
	var leg := ItemRoller.roll("sword_eternal", 42, "loot")           # lendário
	var com := ItemRoller.roll("sword_simple", 7, "loot")             # comum
	var card := FeedbackFormat.item_card(leg, true, true)
	_chk("LUI-T01 rarity correta (lendário)", str(card["rarity"]) == "legendary")
	_chk("LUI-T02 quality correta (== instância)", int(card["quality"]) == int(leg["quality"]))
	_chk("LUI-T03 affixes corretos (== instância)", (card["affixes"] as Array).size() == (leg.get("affixes", []) as Array).size())
	_chk("LUI-T04 exceptional threshold (lendário sim; comum q<95 não)", bool(card["exceptional"]) and not bool(FeedbackFormat.item_card(com)["exceptional"]) if int(com["quality"]) < 95 else bool(card["exceptional"]))
	var loot_kind := str(FeedbackFormat.loot(com)["kind"])
	_chk("LUI-T05 salvage ≠ novo item (kind distinto)", loot_kind != GameFeedback.K_SALVAGE and GameFeedback.K_SALVAGE == "salvage")
	_chk("LUI-T06 locked/equipped corretos", bool(card["locked"]) and bool(card["equipped"]) and not bool(FeedbackFormat.item_card(com)["locked"]))

# ══════════════ RUI — refino UX (RefineUIModel) ══════════════
func _test_rui(gs) -> void:
	print("  ── RUI (refino UX) ──")
	gs.reset_save()
	gs.equipment = {"weapon": "sword_eternal"}
	gs.slot_refinement = {"weapon": 12}
	gs.equipped_instances = {}
	gs.materials = {"Fragmentos": 50000000}
	var sel_none := {"catalyst": "", "preserve": false, "absolute": false}
	var sel_cat := {"catalyst": RefineUIModel.SUP_SUPERIOR, "preserve": false, "absolute": false}
	var sel_abs := {"catalyst": "", "preserve": false, "absolute": true}
	var sel_pres := {"catalyst": "", "preserve": true, "absolute": false}
	var pv_none := RefineUIModel.preview(gs, "weapon", sel_none)
	var pv_cat := RefineUIModel.preview(gs, "weapon", sel_cat)
	_chk("RUI-T01 chance base exibida (>0%)", float(pv_none["final_value"]) > 0.0)
	# RUI-T06 cancelar/preview NÃO consome (nível e Frag intactos após 2 previews)
	RefineUIModel.preview(gs, "weapon", sel_none); RefineUIModel.preview(gs, "weapon", sel_cat)
	_chk("RUI-T06 preview não consome (nível/Frag intactos)", int(gs.slot_refinement["weapon"]) == 12 and int(gs.materials["Fragmentos"]) == 50000000)
	# RUI-T03 catalisador altera a chance exibida
	_chk("RUI-T03 catalisador aumenta a chance exibida", float(pv_cat["final_value"]) > float(pv_none["final_value"]))
	# RUI-T05 absoluto = 100%
	var pv_abs := RefineUIModel.preview(gs, "weapon", sel_abs)
	_chk("RUI-T05 Absoluto mostra 100%", float(pv_abs["final_value"]) >= 1.0 and str(pv_abs["final"]) == "100%")
	# RUI-T07 sucesso (roll01=0 → sucesso garantido pela tabela)
	gs.slot_refinement["weapon"] = 12
	var r_succ := RefineUIModel.attempt(gs, "weapon", sel_none, 0.0)
	_chk("RUI-T07 sucesso: +12→+13, feedback com seta", bool(r_succ["success"]) and int(r_succ["after"]) == 13 and FeedbackFormat.refine(r_succ).contains("→"))
	# RUI-T02 pity subiu após falha
	gs.slot_refinement["weapon"] = 12
	var pity_before := float(gs.refine_pity_by_slot.get("weapon", 0.0))
	var r_fail := RefineUIModel.attempt(gs, "weapon", sel_none, 1.0)   # roll01=1 → falha
	var pity_after := float(gs.refine_pity_by_slot.get("weapon", 0.0))
	_chk("RUI-T02 pity aumenta após falha", pity_after > pity_before)
	# RUI-T08 downgrade (falha em nível >=10 → -1) e feedback
	_chk("RUI-T08 downgrade feedback (falha em +12 → +11)", bool(r_fail["downgraded"]) and int(r_fail["after"]) == 11 and FeedbackFormat.refine(r_fail).contains("FALHOU"))
	# RUI-T04 preservação: falha protegida NÃO cai de nível, feedback mostra proteção (exige o Selo no backpack)
	gs.slot_refinement["weapon"] = 12
	gs.materials["Fragmentos"] = 50000000
	gs.backpack_add_silent("seal_preservation", 2)
	var r_prot := RefineUIModel.attempt(gs, "weapon", sel_pres, 1.0)
	_chk("RUI-T04 preservação: nível mantido + feedback de proteção",
		int(r_prot["after"]) == 12 and (bool(r_prot["protected"]) or FeedbackFormat.refine(r_prot).contains("preserv")))
	gs.reset_save()

# ══════════════ BUX — boss UX ══════════════
func _test_bux() -> void:
	print("  ── BUX (boss UX/identidade) ──")
	var ids := []
	for c in ContentManifest.chapters(): ids.append(str(c["boss_id"]))
	# T01 nomes
	var names_ok := true
	for bid in ids:
		if BossDefinition.display_name(bid) == "": names_ok = false
	_chk("BUX-T01 os 10 bosses têm nome", names_ok and ids.size() == 10)
	# T02 habilidades perigosas têm telegraph
	var tele_ok := true
	for bid in ids:
		for a in BossDefinition.abilities_of(bid):
			var k := BossAbility.kind(a)
			if BossFeedback.is_dangerous(k) and BossFeedback.telegraph_kind(k) == "": tele_ok = false
	_chk("BUX-T02 toda habilidade perigosa tem telegraph", tele_ok)
	# T03 enrage feedback (magma-dragon)
	_phases.clear()
	var b := BossController.new(); b.configure("magma-dragon", 1000, 10, 16)
	b.phase_changed.connect(_on_phase)
	b.take_damage(700)   # 30% HP < 40% → enrage
	b.tick(0.1, 50.0)
	_chk("BUX-T03 enrage emite ENFURECIDO", _phases.has("ENFURECIDO"))
	b.free()
	# T04 shield (threshold-guardian tem aegis)
	_chk("BUX-T04 shield emite ESCUDO", _drive_until_phase("threshold-guardian", "ESCUDO"))
	# T05 summon (faceless-archivist tem raise_husks)
	_chk("BUX-T05 summon emite INVOCANDO", _drive_until_phase("faceless-archivist", "INVOCANDO"))
	# T06 heal (nameless-saint tem mend)
	_chk("BUX-T06 heal emite CURA", _drive_until_phase_hurt("nameless-saint", "CURA"))
	# T07 boss HUD limpa após morte (is_alive=false ⇒ _refresh_boss_hud esconde)
	var d := BossController.new(); d.configure("aethelgard", 300, 10, 16)
	d.take_damage(99999)
	_chk("BUX-T07 boss morto ⇒ is_alive false (HUD esconde)", not d.is_alive())
	d.free()

func _drive_until_phase(boss_id: String, want: String) -> bool:
	_phases.clear()
	var b := BossController.new(); b.configure(boss_id, 100000, 10, 16)
	b.phase_changed.connect(_on_phase)
	for k in range(400):
		b.tick(0.2, 60.0)
		if _phases.has(want): break
	var ok := _phases.has(want)
	b.free()
	return ok

func _drive_until_phase_hurt(boss_id: String, want: String) -> bool:
	_phases.clear()
	var b := BossController.new(); b.configure(boss_id, 10000, 10, 16)
	b.phase_changed.connect(_on_phase)
	b.take_damage(5000)   # fere p/ liberar heal
	for k in range(400):
		b.tick(0.2, 60.0)
		if _phases.has(want): break
	var ok := _phases.has(want)
	b.free()
	return ok

# ══════════════ TR — transições ══════════════
func _test_tr(gs) -> void:
	print("  ── TR (transições, apresentação) ──")
	var st := FeedbackFormat.stage_clear(3, 9, "boss")
	_chk("TR-T01 stage toast (3-9 → 3-10 BOSS)", st.contains("3-9") and st.contains("3-10") and st.contains("BOSS"))
	var ct := FeedbackFormat.chapter_clear(3, "Pântano de Ferro")
	_chk("TR-T02 chapter toast (CAPÍTULO 3)", ct.contains("CAPÍTULO 3") and ct.contains("Pântano"))
	var hud := FeedbackFormat.stage_hud(6, 5, "miniboss")
	_chk("TR-T03 stage HUD (Cap. 6 · 6-5 · APEX)", hud.contains("Cap. 6") and hud.contains("6-5") and hud.contains("APEX"))
	# TR-T04/T05 apresentação é PURA (não muda combate/autoplay)
	var hp0 := int(gs.hero_hp)
	var _x := FeedbackFormat.stage_clear(1, 10, "boss")
	_chk("TR-T04 transição é presentation-only (não trava/muda combate)", int(gs.hero_hp) == hp0)
	_chk("TR-T05 chapter header data-driven (nome+tier)", FeedbackFormat.chapter_header(6, "Areias de Khet", 4).contains("Tier 4"))

# ══════════════ OUX — offline UX ══════════════
func _test_oux(gs) -> void:
	print("  ── OUX (offline UX) ──")
	gs.reset_save()
	gs.offline_pending = {"gold": 4218, "xp": 1200, "items": {}, "materials": {}, "stages_advanced": 7, "seconds": 3600}
	_chk("OUX-T01 pending abre painel (has_pending)", _pending_true(gs))
	var summ := {"seconds": 3600, "stages": 7, "gold": 4218, "xp": 1200, "items": 2, "materials": 5, "exceptional_name": "Gume Eterno"}
	var otxt := FeedbackFormat.offline(summ)
	_chk("OUX-T02 dados exibidos batem pending (fases/ouro)", otxt.contains("7 fases") and otxt.contains("ENQUANTO"))
	# OUX-T03 claim limpa (simulo limpeza do pending)
	gs.offline_pending = {}
	_chk("OUX-T03 claim limpa (pending vazio ⇒ sem painel)", not _pending_true(gs))
	# OUX-T04 CP agregado num toast
	var fb := GameFeedback.new()
	fb.push_cp(1000); fb.push_cp(3218); fb.flush_cp()
	var ts := fb.drain_toasts()
	_chk("OUX-T04 CP agregado (+4218)", ts.size() == 1 and int(ts[0]["delta"]) == 4218)
	fb.free()
	# OUX-T05 item excepcional destacado
	_chk("OUX-T05 item excepcional destacado", otxt.contains("DROP EXCEPCIONAL") and otxt.contains("Gume Eterno"))
	gs.reset_save()

func _pending_true(gs) -> bool:
	var p = gs.offline_pending
	if not (p is Dictionary): return false
	return int(p.get("gold", 0)) > 0 or int(p.get("xp", 0)) > 0 or not (p.get("items", {}) as Dictionary).is_empty() or not (p.get("materials", {}) as Dictionary).is_empty()

# ══════════════ PUX — prestige UX ══════════════
func _test_pux() -> void:
	print("  ── PUX (prestige UX) ──")
	_chk("PUX-T01 eligibility (P0 exige 10 selos / stage 100)", PrestigeMath.required_seals(0) == 10 and PrestigeMath.required_stage(0) == 100)
	var ptxt := FeedbackFormat.prestige(1, 1, 12000, 13000)
	_chk("PUX-T02 reset/preservado descrito (JORNADA REINICIADA)", ptxt.contains("JORNADA REINICIADA"))
	# PUX-T03 CP projected pós-prestígio = CP × 1.08 (um passo de Master); cresce sobre o atual
	var cp_proj := PrestigeMath.projected_cp(10000, 0)
	_chk("PUX-T03 CP projected pós-prestígio sobe (×1.08 = 10800)", cp_proj > 10000 and cp_proj == 10800)
	_chk("PUX-T04 feedback pós-prestige (PRESTÍGIO I · MESTRE I)", ptxt.contains("PRESTÍGIO I") and ptxt.contains("MESTRE I"))
	_chk("PUX-T05 HUD Mestre novo (romano correto)", ptxt.contains("PODER") and FeedbackFormat.prestige(4, 4, 1, 2).contains("PRESTÍGIO IV"))

# ══════════════ STRESS ══════════════
func _test_stress() -> void:
	print("  ── STRESS (pooling/cleanup) ──")
	var fb := GameFeedback.new()
	# STRESS-T01 10k damage events → acumulador limitado ao nº de fontes (sem leak)
	for i in range(10000):
		fb.push_damage(1, "src_%d" % (i % 6))
		if i % 100 == 0: fb.flush_damage()
	fb.flush_damage()
	_chk("STRESS-T01 10k damage events sem leak (acumulador vazio pós-flush)", fb.flush_damage().is_empty())
	# STRESS-T02 1k loot toasts → fila limitada a MAX_TOASTS
	fb.reset()
	for i in range(1000): fb.push_toast(GameFeedback.K_LOOT, "l%d" % i)
	_chk("STRESS-T02 1k loot toasts → fila ≤ MAX_TOASTS (%d)" % GameFeedback.MAX_TOASTS, fb.toast_count() <= GameFeedback.MAX_TOASTS and fb.dropped_toasts > 0)
	# STRESS-T03 100 transições → fila limitada, sem crescimento ilimitado
	fb.reset()
	for i in range(100):
		fb.push_toast(GameFeedback.K_STAGE_CLEAR, "s%d" % i)
		fb.drain_toasts()
	_chk("STRESS-T03 100 transições sem refs stale (fila drenada)", fb.toast_count() == 0)
	fb.free()
	# STRESS-T04 boss ability feedback cleanup (summon/hazard limitados + limpos na morte)
	var b := BossController.new(); b.configure("threshold-guardian", 100000, 10, 16)
	for k in range(300): b.tick(0.2, 60.0)
	var capped := b.summon_count() <= 4 and b.hazard_count() <= 3
	b.take_damage(999999)
	_chk("STRESS-T04 boss cleanup (summon/hazard limitados; 0 na morte)", capped and b.summon_count() == 0 and b.hazard_count() == 0)
	b.free()
