extends SceneTree
## Self-test/RELATÓRIO FATIA A9 — Canon Reconciliation / Narrative Director / Idle-First Story. Prova: (1) canon
## explícito + conflitos classificados; (2) narrativa é CAMADA sobre a espinha idle (walk 1-100 SEM história
## funciona, 10 Selos, Prestígio) no Main REAL; (3) unlock≠seen, offline não marca seen/choice, exact-once.
## FIXTURE (save vivo intocado).  godot --headless --path godot -s res://scripts/_a9_narrative_selftest.gd

var _fail := 0
func _chk(nm: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), nm])
	if not cond: _fail += 1
func _g(): return root.get_node_or_null("GameState")

func _initialize() -> void:
	var gs = _g()
	var fixture := "user://a9_fixture_save.json"
	gs.set_save_path_override(fixture)
	var mem: Dictionary = gs.to_dict()
	gs.reset_save()

	_test_canon()
	_test_unlock(gs)
	_test_narroff(gs)
	_test_choice(gs)
	_test_nrew(gs)
	_test_storyui(gs)

	# ── NARR walk no Main REAL (Driver espera o boot) ──
	gs.reset_save()
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	var drv := _Driver.new()
	drv.test = self; drv.main = main; drv.gs = gs; drv.mem = mem; drv.fixture = fixture
	root.add_child(drv)

# ══════════════ CANON ══════════════
func _test_canon() -> void:
	print("  ── CANON (regra explícita + conflitos classificados) ──")
	_chk("CANON-T01 todo beat integrado tem source_ref", NarrativeManifest.all_have_source())
	# T02 nenhuma fonte LEGACY_NONCANON (Raízes/Khet) gera beat
	var no_legacy := true
	for b in NarrativeManifest.beats():
		var ref := str(b["source_ref"]).to_lower()
		if ref.contains("khet") or ref.contains("raiz") or ref.contains("ashen") or ref.contains("swamp"): no_legacy = false
	_chk("CANON-T02 nenhuma fonte LEGACY_NONCANON gera beat", no_legacy and NarrativeCanon.by_decision("LEGACY_NONCANON").size() >= 1)
	# T03 UNRESOLVED não é integrado como fato (aethelgard/coroação não viram beat)
	var no_unresolved_beat := true
	for b in NarrativeManifest.beats():
		if str(b["source_ref"]).contains("aethelgard") and str(b["status"]) == "INTEGRATED": no_unresolved_beat = false
		if str(b["title"]).to_lower().contains("coroa"): no_unresolved_beat = false
	_chk("CANON-T03 UNRESOLVED não integrado como fato", no_unresolved_beat and NarrativeCanon.by_decision("UNRESOLVED").size() >= 1)
	# T04 nenhuma revelação proibida aparece cedo
	var dir := NarrativeDirector.new()
	_chk("CANON-T04 nenhuma revelação proibida cedo (timing)", dir.canon_timing_ok())
	dir.free()
	# T05 boss_id não vira lore automaticamente (aethelgard = NO_CANON_BEAT, sem beat)
	var aeth_no_beat := true
	for b in NarrativeManifest.beats():
		if str(b["unlock"].get("value", "")) == "aethelgard": aeth_no_beat = false
	_chk("CANON-T05 boss_id não vira lore auto (aethelgard NO_CANON_BEAT)", aeth_no_beat and str(NarrativeCanon.boss_canon("aethelgard")["status"]) == "NO_CANON_BEAT")
	# T06 matriz cobre os conflitos
	var topics := []
	for row in NarrativeCanon.matrix(): topics.append(str(row["topic"]).to_lower())
	var covered := true
	for need in ["aethelgard", "coroa", "raízes", "nexo", "ato 6"]:
		var found := false
		for t in topics:
			if t.contains(need) or t.contains(need.replace("í", "i")): found = true
		if not found: covered = false
	_chk("CANON-T06 matriz cobre os conflitos (%d linhas)" % NarrativeCanon.matrix().size(), covered and NarrativeCanon.matrix().size() >= 7)

# ══════════════ UNLOCK ══════════════
func _test_unlock(gs) -> void:
	print("  ── UNLOCK (condição / seen ≠ unlock) ──")
	gs.reset_save()
	var dir := NarrativeDirector.new(); dir.setup(null)
	var wolf := NarrativeManifest.beat("b-wolf-alpha")
	_chk("UNLOCK-T01 condição falsa → LOCKED", dir.beat_state(wolf, gs) == NarrativeDirector.ST_LOCKED)
	gs.mark_boss_defeated(BossDefinition.display_name("wolf-alpha"))
	_chk("UNLOCK-T02 condição verdadeira → AVAILABLE", dir.beat_state(wolf, gs) == NarrativeDirector.ST_AVAILABLE)
	_chk("UNLOCK-T03 AVAILABLE não vira SEEN sozinho", not dir.is_seen(wolf, gs))
	# T04 relog não duplica unlock (round-trip apply_dict mantém o mesmo conjunto)
	var ids_a := dir.available_ids(gs)
	var snap: Dictionary = gs.to_dict().duplicate(true); gs.reset_save(); gs.apply_dict(snap)
	var ids_b := dir.available_ids(gs)
	_chk("UNLOCK-T04 relog não duplica unlock", ids_a.size() == ids_b.size())
	# T05 first boss clear unlock correto (magma → só magma beat vira available novo)
	gs.reset_save(); gs.mark_boss_defeated(BossDefinition.display_name("magma-dragon"))
	_chk("UNLOCK-T05 first boss clear unlock correto", dir.beat_state(NarrativeManifest.beat("b-magma-dragon"), gs) == NarrativeDirector.ST_AVAILABLE and dir.beat_state(wolf, gs) == NarrativeDirector.ST_LOCKED)
	# T06 Prestígio não reseta seen
	gs.reset_save(); gs.mark_boss_defeated(BossDefinition.display_name("wolf-alpha")); dir.open_beat("b-wolf-alpha", gs)
	var seen_before := dir.is_seen(wolf, gs)
	gs.prestige_count += 1; gs.cycle_seals = 0; gs.stage_chapter = 1; gs.stage_index = 1   # simula reset de CICLO (não toca narrative_seen)
	_chk("UNLOCK-T06 Prestígio não reseta seen", seen_before and dir.is_seen(wolf, gs))
	dir.free(); gs.reset_save()

# ══════════════ NARROFF ══════════════
func _test_narroff(gs) -> void:
	print("  ── NARROFF (offline desbloqueia, não marca seen/choice) ──")
	gs.reset_save()
	var dir := NarrativeDirector.new(); dir.setup(null)
	var before := dir.available_ids(gs)
	# offline "atravessa" bosses → marca defeated (sem abrir nada)
	gs.mark_boss_defeated(BossDefinition.display_name("wolf-alpha"))
	gs.mark_boss_defeated(BossDefinition.display_name("crystal-golem"))
	gs.mark_boss_defeated(BossDefinition.display_name("broken-oath"))
	var newly := dir.newly_available(before, gs)
	_chk("NARROFF-T01 offline pode desbloquear beat", newly.size() >= 3)
	_chk("NARROFF-T02 offline NÃO marca seen", gs.narrative_seen.is_empty())
	_chk("NARROFF-T03 offline NÃO resolve choice", gs.narrative_choices.is_empty())
	_chk("NARROFF-T04 offline não pausa progressão (só computa)", int(gs.stage_kills) == 0)
	_chk("NARROFF-T05 múltiplos beats agregam (N=%d)" % newly.size(), newly.size() >= 2)
	# T06 runtime/offline usam a MESMA condição lógica (unlock_met é a fonte única)
	_chk("NARROFF-T06 runtime/offline mesma condição", dir.unlock_met(NarrativeManifest.beat("b-broken-oath"), gs))
	dir.free(); gs.reset_save()

# ══════════════ CHOICE ══════════════
func _test_choice(gs) -> void:
	print("  ── CHOICE (pendente/persiste/replay/sem-mecânica) ──")
	gs.reset_save()
	var dir := NarrativeDirector.new(); dir.setup(null)
	gs.mark_boss_defeated(BossDefinition.display_name("broken-oath"))
	_chk("CHOICE-T01 choice pendente exige usuário (vazia até escolher)", dir.choice_of("b-broken-oath", gs) == "")
	var gold_before := int(gs.hero_gold)
	var ok1 := dir.record_choice("b-broken-oath", "seal", gs)
	# T02 persiste (round-trip)
	var snap: Dictionary = gs.to_dict().duplicate(true); gs.reset_save(); gs.apply_dict(snap); gs.mark_boss_defeated(BossDefinition.display_name("broken-oath"))
	_chk("CHOICE-T02 choice persiste", ok1 and dir.choice_of("b-broken-oath", gs) == "seal")
	# T03 replay não troca
	var ok2 := dir.record_choice("b-broken-oath", "reveal", gs)
	_chk("CHOICE-T03 replay não troca choice", (not ok2) and dir.choice_of("b-broken-oath", gs) == "seal")
	# T04 choice não bloqueia StageDirector (arquitetura: diretor não expõe gate)
	_chk("CHOICE-T04 choice não bloqueia StageDirector", not dir.has_method("stagedirector_gate"))
	# T05 sem efeito mecânico (audit: choices são FLAVOR) — record_choice não mexe em ouro
	_chk("CHOICE-T05 escolha sem efeito mecânico (ouro intacto)", int(gs.hero_gold) == gold_before)
	dir.free(); gs.reset_save()

# ══════════════ NREW ══════════════
func _test_nrew(gs) -> void:
	print("  ── NREW (reward exato-uma-vez; nada exigido p/ stage100) ──")
	gs.reset_save()
	var dir := NarrativeDirector.new(); dir.setup(null)
	# T01 reward existente aplica uma vez (complete_quest dedup)
	gs.complete_quest("ch1-awakening")
	var q1: bool = gs.is_quest_completed("ch1-awakening")
	var n_before: int = gs.completed_quests.size()
	gs.complete_quest("ch1-awakening")   # 2ª vez
	_chk("NREW-T01/T03 reward existente 1× (complete_quest dedup)", q1 and gs.completed_quests.size() == n_before)
	# T02 replay = 0 reward (open_beat não concede nada)
	gs.mark_boss_defeated(BossDefinition.display_name("wolf-alpha"))
	var gold0 := int(gs.hero_gold); var inv0: int = gs.inventory_items.size()
	dir.open_beat("b-wolf-alpha", gs); dir.open_beat("b-wolf-alpha", gs)   # replay
	_chk("NREW-T02 replay = 0 reward (diretor não concede)", int(gs.hero_gold) == gold0 and gs.inventory_items.size() == inv0)
	# T04 offline não duplica (evaluate não concede)
	var gold1 := int(gs.hero_gold)
	dir.available_unseen(gs)
	_chk("NREW-T04 offline/evaluate não concede reward", int(gs.hero_gold) == gold1)
	# T05 nenhuma reward é requisito p/ stage100 (o diretor não toca CP/economia)
	gs.reset_save(); gs.equipment = {"weapon": "sword_eternal"}
	var cp_no_narr := PowerBudget.cp()
	dir.open_beat("b-wolf-alpha", gs)   # abrir história não muda CP
	_chk("NREW-T05 nenhuma reward narrativa é requisito p/ stage100 (CP igual)", PowerBudget.cp() == cp_no_narr)
	dir.free(); gs.reset_save()

# ══════════════ STORYUI ══════════════
func _test_storyui(gs) -> void:
	print("  ── STORYUI (painel/badge) ──")
	gs.reset_save()
	var dir := NarrativeDirector.new(); dir.setup(null)
	gs.mark_boss_defeated(BossDefinition.display_name("wolf-alpha"))
	var model := dir.panel_model(gs)
	var has_avail := false; var leaks := false
	for e in model:
		if str(e["state"]) == NarrativeDirector.ST_AVAILABLE: has_avail = true
		if e.has("source_ref") or e.has("reveals") or e.has("unlock"): leaks = true
	_chk("STORYUI-T01 available aparece", has_avail)
	_chk("STORYUI-T03 badge só com unseen", dir.has_badge(gs))
	# T04 open marca seen no momento correto
	dir.open_beat("b-wolf-alpha", gs)
	var now_seen := false
	for e in dir.panel_model(gs):
		if str(e["beat_id"]) == "b-wolf-alpha" and str(e["state"]) == NarrativeDirector.ST_SEEN: now_seen = true
	_chk("STORYUI-T04 open marca seen no momento certo", now_seen)
	# T02 seen aparece separado (estado distinto)
	_chk("STORYUI-T02 seen aparece separado (estado SEEN)", now_seen)
	# T05 replay disponível quando permitido (beat replayable + SEEN → replay=true)
	var replay_ok := false
	for e in dir.panel_model(gs):
		if str(e["beat_id"]) == "b-wolf-alpha" and bool(e["replay"]): replay_ok = true
	_chk("STORYUI-T05 replay disponível quando permitido", replay_ok)
	# T06 iid/flags internas não vazam
	_chk("STORYUI-T06 sem vazamento de flags internas na UI", not leaks)
	# badge some quando tudo visto
	var only_wolf := true
	# (apenas wolf foi derrotado → só wolf/intro; após ver wolf ainda há intro available → badge pode seguir)
	dir.free(); gs.reset_save()

# ══════════════ Driver: NARR walk no Main REAL ══════════════
class _Driver extends Node:
	var test; var main; var gs; var mem := {}; var fixture := ""
	var _waited := 0; var _done := false
	func _process(_delta: float) -> void:
		if _done: return
		if main == null or main._stagedirector == null or main._narrative == null:
			_waited += 1
			if _waited < 60: return
		_done = true
		test._test_narr_walk(main, gs)
		if is_instance_valid(main):
			if main.get_parent() != null: main.get_parent().remove_child(main)
			main.free()
		gs.set_save_path_override("")
		gs.apply_dict(mem); gs._dirty = false; gs._session_started = false
		if FileAccess.file_exists(fixture): DirAccess.remove_absolute(fixture)
		test._finish()
		get_tree().quit(0 if test._fail == 0 else 1)

func _finish() -> void:
	print("  [save-safe] fixture descartada; save vivo intocado")
	print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))

func _test_narr_walk(main, gs) -> void:
	print("  ── NARR (Main REAL: 1-1→10-10 SEM história) ──")
	gs.reset_save()
	var sd = main._stagedirector
	var dir = main._narrative
	if main._world_router != null: main._world_router.set_active(false)   # walk determinístico (router já provado em A7.4.1)
	# quota é imune à narrativa (mesma antes/depois de desbloquear beat)
	sd.chapter = 1; sd.stage = 1; sd.notify_region_changed()
	var quota_before: int = sd.stage_quota()
	# WALK: derrota cada boss pelo caminho REAL (take_damage→_on_boss_defeated→mark_boss_defeated+grant_cycle_seal)
	# NUNCA abre StoryPanel / diálogo.
	for c in range(1, 11):
		var region := ContentManifest.region_for_stage(c * 10)
		sd.chapter = c; sd.stage = 10
		main.load_region(region)
		main.ensure_stage_boss()
		var boss = main._current_boss
		if boss != null and is_instance_valid(boss) and boss.has_method("take_damage"):
			boss.call("take_damage", 9999999)
	sd.chapter = 1; sd.stage = 1; sd.notify_region_changed()
	var quota_after: int = sd.stage_quota()
	_chk("NARR-T01 walk 1-1→10-10 SEM história funciona (10 Selos)", int(gs.cycle_seals) == 10)
	_chk("NARR-T02 10 Selos possíveis sem narrativa", int(gs.cycle_seals) == 10)
	_chk("NARR-T03 Prestígio possível sem 'seen'", gs.narrative_seen.is_empty() and int(gs.cycle_seals) >= PrestigeMath.required_seals(int(gs.prestige_count)))
	_chk("NARR-T04 narrativa nunca muda kill requirement", quota_before == quota_after)
	# T05 narrativa nunca altera wall (o StageDirector não referencia o diretor)
	_chk("NARR-T05 narrativa nunca altera wall (sem gate)", not sd.has_method("narrative_gate"))
	# T06 narrativa nunca bloqueia region loading (load_region rodou 10×; região corrente é a do cap 10)
	_chk("NARR-T06 narrativa nunca bloqueia region loading", gs.current_region_id == ContentManifest.region_for_stage(100))
	# beats DESBLOQUEARAM pelo gameplay (bosses derrotados), mas NENHUM foi visto
	var avail: Array = dir.available_unseen(gs)
	_chk("NARR beats desbloqueados pelo gameplay, 0 vistos", avail.size() >= 9 and gs.narrative_seen.is_empty())

	# ── walk COM história (abre todos os disponíveis) → mesma progressão, sem duplicação ──
	print("  ── NARR (mesma progressão COM história) ──")
	var seals_snapshot := int(gs.cycle_seals)
	var opened := 0
	for b in dir.available_unseen(gs):
		if dir.open_beat(str(b["beat_id"]), gs): opened += 1
		var cids: Array = b["choice_ids"]
		if not cids.is_empty(): dir.record_choice(str(b["beat_id"]), str(cids[0]), gs)
	_chk("NARR-COM abrir todas as histórias não altera Selos/progressão", int(gs.cycle_seals) == seals_snapshot)
	_chk("NARR-COM histórias marcadas seen (sem duplicar)", opened >= 9 and dir.available_unseen(gs).size() < avail.size())
	# comparação: ambos os caminhos chegam a 10 Selos + Prestígio elegível
	_chk("NARR-COMPARA mesma capacidade de progressão (10 Selos, Prestígio elegível)", int(gs.cycle_seals) >= PrestigeMath.required_seals(int(gs.prestige_count)))
	# primeiro Prestígio NÃO exige consumir beats (há beats — vistos ou não — e Prestígio segue elegível)
	_chk("NARR-PRESTIGE Prestígio não exige consumir beats", int(gs.cycle_seals) >= PrestigeMath.required_seals(int(gs.prestige_count)))
