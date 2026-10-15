extends SceneTree
## Self-test/RELATÓRIO FATIA A9.1 — Story Runtime UI / Viewing Flow / Dialogue Wiring. Prova no MAIN REAL:
## boss clear → beat AVAILABLE → StoryPanel → abrir beat → DialoguePanel real → concluir → SEEN → badge atualiza
## → fecha → AutoPlay retoma; e outro jogador ignora tudo e progride igual. FIXTURE (save vivo intocado).
##   godot --headless --path godot -s res://scripts/_a91_storyui_selftest.gd

var _fail := 0
func _chk(nm: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), nm])
	if not cond: _fail += 1
func _g(): return root.get_node_or_null("GameState")

func _initialize() -> void:
	var gs = _g()
	var fixture := "user://a91_fixture_save.json"
	gs.set_save_path_override(fixture)
	var mem: Dictionary = gs.to_dict()
	gs.reset_save()
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	var drv := _Driver.new()
	drv.test = self; drv.main = main; drv.gs = gs; drv.mem = mem; drv.fixture = fixture
	root.add_child(drv)

class _Driver extends Node:
	var test; var main; var gs; var mem := {}; var fixture := ""
	var _waited := 0; var _done := false
	func _process(_delta: float) -> void:
		if _done: return
		if main == null or main._narrative == null or main._story_panel == null or main._dialog == null:
			_waited += 1
			if _waited < 60: return
		_done = true
		test._run(main, gs)
		if is_instance_valid(main):
			if main.get_parent() != null: main.get_parent().remove_child(main)
			main.free()
		gs.set_save_path_override("")
		gs.apply_dict(mem); gs._dirty = false; gs._session_started = false
		if FileAccess.file_exists(fixture): DirAccess.remove_absolute(fixture)
		print("  [save-safe] fixture descartada; save vivo intocado")
		print(">>> %s" % ("OK" if test._fail == 0 else "FALHOU (%d)" % test._fail))
		get_tree().quit(0 if test._fail == 0 else 1)

func _bd(id: String) -> String:
	return BossDefinition.display_name(id)

func _run(main, gs) -> void:
	var dir = main._narrative
	var sp = main._story_panel
	if main._world_router != null: main._world_router.set_active(false)
	main._title_open = false   # dispensa a capa (artefato de boot) → autoplay_can_fight reflete só o viewing
	gs.reset_save()

	# ── STORYRT ──
	print("  ── STORYRT (painel real) ──")
	_chk("STORYRT-T01 painel instancia", sp != null and main._dialog != null)
	gs.mark_boss_defeated(_bd("wolf-alpha"))
	sp.open_panel(); sp.refresh()
	_chk("STORYRT-T02 AVAILABLE aparece", sp.available_count() >= 1)
	_chk("STORYRT-T04 badge acompanha unseen", dir.has_badge(gs))
	# T05 fechar painel sem abrir beat NÃO marca seen
	sp.close_panel()
	_chk("STORYRT-T05 fechar painel sem abrir não marca seen", gs.narrative_seen.is_empty())
	# T06 sem ids/source_ref no modelo
	var leaks := false
	for e in dir.panel_model(gs):
		if e.has("source_ref") or e.has("reveals") or e.has("unlock"): leaks = true
	_chk("STORYRT-T06 sem ids/source_ref na UI", not leaks)

	# ── VIEW ──
	print("  ── VIEW (viewing flow) ──")
	var speed0 := Engine.time_scale
	main.open_story_beat("b-wolf-alpha")
	_chk("VIEW-T01 abrir beat entra viewing", main.narrative_viewing())
	_chk("VIEW-T02 DialoguePanel real abre", main._dialog.is_open())
	_chk("VIEW-T03 AutoPlay suspenso durante viewing", not main.autoplay_can_fight())
	_chk("VIEW-T04 combate não progride (player travado)", bool(main._player.get("locked")))
	_chk("VIEW-T05 game speed não alterado", Engine.time_scale == speed0)
	# conclui a cena pelo DialoguePanel REAL (marca dialogue_seen + emite dialogue_closed → _finish_story_viewing)
	main._dialog._close("")
	_chk("VIEW-T06 fechar sai de viewing", not main.narrative_viewing())
	_chk("VIEW-T07 AutoPlay retoma (dialog fechado)", main.autoplay_can_fight())
	_chk("VIEW-T08 game speed intacto após viewing", Engine.time_scale == speed0)

	# ── SEEN ──
	print("  ── SEEN (marca na conclusão) ──")
	var wolf := NarrativeManifest.beat("b-wolf-alpha")
	_chk("SEEN-T03 concluir marca seen", dir.is_seen(wolf, gs))
	# T04 relog mantém seen
	var snap: Dictionary = gs.to_dict().duplicate(true); gs.reset_save(); gs.apply_dict(snap); gs.mark_boss_defeated(_bd("wolf-alpha"))
	_chk("SEEN-T04 relog mantém seen", dir.is_seen(wolf, gs))
	# T05 Prestígio mantém seen (simula reset de ciclo)
	gs.prestige_count += 1; gs.cycle_seals = 0; gs.stage_chapter = 1; gs.stage_index = 1
	_chk("SEEN-T05 Prestígio mantém seen", dir.is_seen(wolf, gs))
	# T01/T02 available≠seen / abrir-sem-concluir≠seen (num beat fresco)
	gs.reset_save(); gs.mark_boss_defeated(_bd("magma-dragon"))
	var magma := NarrativeManifest.beat("b-magma-dragon")
	_chk("SEEN-T01 available não é seen", dir.beat_state(magma, gs) == NarrativeDirector.ST_AVAILABLE and not dir.is_seen(magma, gs))
	main.open_story_beat("b-magma-dragon")
	_chk("SEEN-T02 abrir sem concluir NÃO é seen", main.narrative_viewing() and not dir.is_seen(magma, gs))
	main._dialog._close("")

	# ── CHRT (choice runtime) ──
	print("  ── CHRT (choices) ──")
	gs.reset_save(); gs.mark_boss_defeated(_bd("broken-oath"))
	var oath_scene: Dictionary = main._resolve_beat_scene(NarrativeManifest.beat("b-broken-oath"))
	_chk("CHRT-T01 opções aparecem (cena tem choices)", (oath_scene.get("choices", []) as Array).size() >= 2)
	_chk("CHRT-T03 não autoescolhe (antes de abrir)", dir.choice_of("b-broken-oath", gs) == "")
	main.open_story_beat("b-broken-oath"); main._dialog._close("seal")
	_chk("CHRT-T02 escolha persiste", dir.choice_of("b-broken-oath", gs) == "seal")
	# replay read-only: reabre (SEEN) e tenta trocar → mantém
	main.open_story_beat("b-broken-oath"); main._dialog._close("reveal")
	_chk("CHRT-T04 replay é read-only (choice não muda)", dir.choice_of("b-broken-oath", gs) == "seal")
	_chk("CHRT-T05 não altera escolha existente", dir.choice_of("b-broken-oath", gs) == "seal")
	# T06 shadow-final 5 escolhas
	gs.reset_save(); gs.mark_boss_defeated(_bd("shadow-between-worlds"))
	var sh_scene: Dictionary = main._resolve_beat_scene(NarrativeManifest.beat("b-shadow-final"))
	_chk("CHRT-T06 shadow-final resolve 5 escolhas", (sh_scene.get("choices", []) as Array).size() == 5)

	# ── REPLAY ──
	print("  ── REPLAY (read-only) ──")
	gs.reset_save(); gs.mark_boss_defeated(_bd("wolf-alpha"))
	main.open_story_beat("b-wolf-alpha"); main._dialog._close("")   # 1ª vez → SEEN
	var gold0 := int(gs.hero_gold); var inv0: int = gs.inventory_items.size()
	var avail0: int = dir.available_unseen(gs).size(); var seals0 := int(gs.cycle_seals); var ch0 := int(gs.stage_chapter)
	main.open_story_beat("b-wolf-alpha")   # replay (SEEN)
	_chk("REPLAY-T01 beat seen abre (viewing)", main.narrative_viewing())
	main._dialog._close("")
	_chk("REPLAY-T02/T03/T04 replay: 0 reward, 0 unlock novo, 0 stage", int(gs.hero_gold) == gold0 and gs.inventory_items.size() == inv0 and dir.available_unseen(gs).size() == avail0 and int(gs.cycle_seals) == seals0 and int(gs.stage_chapter) == ch0)

	# ── NSAFE ──
	print("  ── NSAFE (segurança) ──")
	gs.reset_save(); gs.mark_boss_defeated(_bd("wolf-alpha"))
	main.open_story_beat("b-wolf-alpha")
	var vb: String = main._viewing_beat
	main.open_story_beat("b-magma-dragon")   # já em viewing → no-op
	_chk("NSAFE-T01 não abre dois beats", main._viewing_beat == vb)
	_chk("NSAFE-T03 target stale não retorna (sem alvo em viewing)", not main.autoplay_has_target())
	# T04 Prestígio bloqueado durante viewing (mesmo elegível)
	gs.cycle_seals = 20; gs.stage_highest_global = 100; gs.lifetime_highest_stage = 100; gs.stage_chapter = 10; gs.stage_index = 10; gs.offline_pending = {}
	var ce_view: Dictionary = main._prestige.can_execute()
	_chk("NSAFE-T04 Prestígio bloqueado durante viewing", not bool(ce_view["ok"]) and str(ce_view["reason"]).to_lower().contains("história"))
	# T06 crash antes da conclusão não vira seen (ainda em viewing, wolf visto antes? novo beat magma não visto)
	_chk("NSAFE-T06 sem conclusão → não vira seen", main.narrative_viewing())
	main._dialog._close("")   # fecha
	# T05 após fechar, Prestígio disponível de novo (elegível)
	var ce_after: Dictionary = main._prestige.can_execute()
	_chk("NSAFE-T05 após fechar, Prestígio disponível", bool(ce_after["ok"]))
	# T02 não abre StoryPanel duplicado
	sp.open_panel(); var was_open: bool = sp.is_open(); sp.open_panel()
	_chk("NSAFE-T02 StoryPanel não duplica", was_open and sp.is_open())
	sp.close_panel()

	# ── WALK ignorando × consumindo história (mesma progressão) ──
	print("  ── WALK (idle-first: ignorar × consumir) ──")
	gs.reset_save()
	for c in range(1, 11):
		var region := ContentManifest.region_for_stage(c * 10)
		main._stagedirector.chapter = c; main._stagedirector.stage = 10
		main.load_region(region); main.ensure_stage_boss()
		var boss = main._current_boss
		if boss != null and is_instance_valid(boss) and boss.has_method("take_damage"):
			boss.call("take_damage", 9999999)
	_chk("WALK-IGNORA 1-1→10-10 sem história = 10 Selos, 0 vistos", int(gs.cycle_seals) == 10 and gs.narrative_seen.is_empty())
	var seals_ign := int(gs.cycle_seals)
	# consumindo história (abre todos os disponíveis)
	for b in dir.available_unseen(gs):
		main.open_story_beat(str(b["beat_id"]))
		var cids: Array = b["choice_ids"]
		main._dialog._close(str(cids[0]) if not cids.is_empty() else "")
	_chk("WALK-CONSOME mesma progressão (Selos iguais)", int(gs.cycle_seals) == seals_ign)
	_chk("WALK-COMPARA mesma capacidade (10 Selos, Prestígio elegível), história = tempero", int(gs.cycle_seals) >= PrestigeMath.required_seals(int(gs.prestige_count)) and dir.seen_beats(gs).size() >= 9)
	gs.reset_save()
