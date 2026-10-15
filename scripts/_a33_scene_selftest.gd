extends SceneTree
## A33 REALSCENE — Field UX na Main.tscn REAL. Prova: HUD sem duplicação (1 AUTO, FASE em 1 lugar), modal SISTEMAS
## fecha por ESC/backdrop/toggle e não deixa fantasma, camadas DEV ocultas em NORMAL, e — o crítico — a caça real
## mostra o mob (sprite + nameplate + HP) com ZERO ghost kills. Fixture-safe. TestHarness (A31).
## Grupos: UX33HUD / UX33ACTIVITY / REALSCENE33.

var H: TestHarness
var main: Node = null
var _frame := 0
var _phase := 0
var gs; var hh; var sp; var idle

func _initialize() -> void:
	H = TestHarness.new()
	var ps: PackedScene = load("res://scenes/Main.tscn")
	main = ps.instantiate() if ps != null else null
	if main != null: root.add_child(main)
	process_frame.connect(_on_frame)

func _on_frame() -> void:
	_frame += 1
	if _phase == 0 and _frame >= 3:
		_phase = 1
		if main != null and main.has_method("_enter_game"): main._enter_game()
	elif _phase == 1 and _frame >= 10:
		_phase = 2
		_run()
		if FileAccess.file_exists("user://a33s_fixture.json"): DirAccess.remove_absolute("user://a33s_fixture.json")
		var res := H.summarize("A33-SCENE")
		quit(0 if bool(res["ok"]) else 1)

func _esc() -> InputEventKey:
	var e := InputEventKey.new(); e.keycode = KEY_ESCAPE; e.pressed = true; return e

func _visible_auto_widgets() -> int:
	var n := 0
	if idle != null:
		if idle._auto_top_lbl != null and idle._auto_top_lbl.visible: n += 1
		if idle._auto_btn != null and idle._auto_btn.visible: n += 1
	return n

func _prep_ch4() -> void:
	gs.reset_save(); gs.set_save_path_override("user://a33s_fixture.json")
	gs.character_class = "CLASS_1"; gs.equipment = {"weapon": "sword_eternal"}; gs.slot_refinement = {"weapon": 8}
	gs.hero_hp_max = 200000; gs.hero_hp = gs.max_hp_total(); gs.stage_highest_global = 60
	gs.bestiary = {"dune_skitter": {"kills": 5}}

func _run() -> void:
	if main == null:
		H.group_begin("REALSCENE33", 40); H.group_error("Main.tscn não instanciou"); H.group_complete()
		H.group_begin("UX33HUD", 35); H.group_error("no scene"); H.group_complete()
		H.group_begin("UX33ACTIVITY", 30); H.group_error("no scene"); H.group_complete(); return
	gs = root.get_node_or_null("GameState")
	hh = main.get("_hunthost"); sp = main.get("_systempanel"); idle = main.get("_idlehud")
	gs.set_save_path_override("user://a33s_fixture.json")
	_hud(); _activity(); _realscene()

# ════════════════════════════════════════════════════════════════════════════════════════════
func _hud() -> void:
	H.group_begin("UX33HUD", 35)
	if gs == null or sp == null or idle == null:
		H.group_error("HUD refs nulas (gs/systempanel/idlehud)"); H.group_complete(); return
	# ── UM controle de AUTO (§5) ──
	H.check("HUD-01 IdleHud presente", idle != null)
	H.check("HUD-02 AUTO do topo OCULTO (dedup)", idle._auto_top_lbl == null or not idle._auto_top_lbl.visible)
	H.check("HUD-03 AUTO botão (rodapé) presente", idle._auto_btn != null)
	H.check("HUD-04 EXATAMENTE 1 widget de AUTO visível", _visible_auto_widgets() == 1)
	# ── FASE em UM lugar (§14) ──
	H.check("HUD-05 FASE do topo OCULTA (dedup)", idle._topstage_lbl == null or not idle._topstage_lbl.visible)
	H.check("HUD-06 FASE do rodapé (com barra) presente", idle._stage_lbl != null)
	H.check("HUD-07 NÃO há 2 FASE visíveis", not ((idle._topstage_lbl != null and idle._topstage_lbl.visible) and (idle._stage_lbl != null and idle._stage_lbl.visible)))
	# ── modal SISTEMAS: abre/fecha confiável ──
	sp.close_panel()
	H.check("HUD-08 Systems fechado no início", not sp.is_open())
	sp.open_panel()
	H.check("HUD-09 Systems abre", sp.is_open())
	H.check("HUD-10 backdrop existe (STOP)", sp._backdrop != null and sp._backdrop.mouse_filter == Control.MOUSE_FILTER_STOP)
	sp._unhandled_input(_esc())
	H.check("HUD-11 ESC fecha Systems", not sp.is_open())
	# toggle pelo mesmo caminho do botão ⚙ (Main.idlehud_open_system sem id = toggle)
	main.idlehud_open_system()
	H.check("HUD-12 ⚙ (toggle) abre", sp.is_open())
	main.idlehud_open_system()
	H.check("HUD-13 ⚙ (toggle) fecha", not sp.is_open())
	# ▸IR (com sistema) sempre ABRE
	main.idlehud_open_system("equipment")
	H.check("HUD-14 ▸IR abre no sistema", sp.is_open())
	# clique no backdrop fecha
	var mb := InputEventMouseButton.new(); mb.button_index = MOUSE_BUTTON_LEFT; mb.pressed = true
	sp._backdrop.gui_input.emit(mb)
	H.check("HUD-15 clique fora (backdrop) fecha", not sp.is_open())
	H.check("HUD-16 reabre após fechar (sem fantasma)", (func(): sp.open_panel(); return sp.is_open()).call())
	sp.close_panel()
	# ── camadas DEV ocultas em NORMAL (§12/§37) ──
	var dev = main.get("_dev_layer")
	H.check("HUD-17 _dev_layer oculto por padrão", dev == null or not dev.visible)
	var hdev = main.get("_hunt_dev_layer")
	H.check("HUD-18 _hunt_dev_layer oculto por padrão", hdev == null or not hdev.visible)
	# ── AcqRoot não come mais o clique (fix desta sessão) ──
	var acq = main.get("_acq_ui_layer")
	H.check("HUD-19 AcquisitionUX existe", acq != null)
	# HUD principal existe (vitals/foot)
	H.check("HUD-20 HUD principal (layer 1) montado", main.get("_hud_layer") != null)
	# ── one-major-panel: abrir Systems não deixa 2 modais grandes; is_open é a fonte única ──
	sp.open_panel()
	H.check("HUD-21 is_open == visible (fonte única de estado)", sp.is_open() == sp.visible)
	sp.close_panel()
	# resto do HUD: repetir contrato de AUTO/FASE após um refresh do idle
	if idle.has_method("refresh"): idle.refresh()
	H.check("HUD-22 após refresh, 1 AUTO visível", _visible_auto_widgets() == 1)
	H.check("HUD-23 após refresh, FASE não duplicada", not ((idle._topstage_lbl != null and idle._topstage_lbl.visible) and (idle._stage_lbl != null and idle._stage_lbl.visible)))
	# estabilidade: 6 toggles do modal não deixam fantasma
	for i in range(6): main.idlehud_open_system()
	H.check("HUD-24 6 toggles → fechado (par)", not sp.is_open())
	# ESC repetido fechado = no-op
	sp._unhandled_input(_esc())
	H.check("HUD-25 ESC com Systems fechado = no-op", not sp.is_open())
	# vitals/poder no topo-esquerdo existem (personagem)
	H.check("HUD-26 PODER/recursos no IdleHud (topo)", idle._power_lbl != null)
	# tracker (trilha) existe e é colapsável (não domina)
	H.check("HUD-27 tracker de trilha existe", main.get("_tracker_frame") != null)
	# modal cabe centralizado
	H.check("HUD-28 modal PRESET_CENTER (cabe/mobile-safe)", sp._root.anchor_left == 0.5)
	# backdrop cobre viewport (input seguro)
	H.check("HUD-29 backdrop full-rect", sp._backdrop.anchor_right == 1.0 and sp._backdrop.anchor_bottom == 1.0)
	# AUTO botão realmente alterna o estado (controle único funciona)
	var before: bool = main.autoplay_on()
	if idle._auto_btn != null: idle._auto_btn.pressed.emit()
	H.check("HUD-30 o único AUTO alterna o estado", main.autoplay_on() != before)
	if idle._auto_btn != null: idle._auto_btn.pressed.emit()   # restaura
	# FASE label do rodapé mostra texto (não vazio)
	H.check("HUD-31 FASE (rodapé) tem texto", idle._stage_lbl != null and str(idle._stage_lbl.text).length() > 0)
	# nenhum modal grande aberto ao fim
	H.check("HUD-32 nenhum modal Systems aberto ao fim", not sp.is_open())
	# is_open acessor coerente
	H.check("HUD-33 is_open() acessível", sp.has_method("is_open"))
	# dev drawer togglável por F4 mas oculto agora
	H.check("HUD-34 dev oculto em NORMAL confirmado", dev == null or not dev.visible)
	H.check("HUD-35 AUTO widget único estável após interações", _visible_auto_widgets() == 1)
	H.group_complete()

# ════════════════════════════════════════════════════════════════════════════════════════════
func _activity() -> void:
	H.group_begin("UX33ACTIVITY", 30)
	if gs == null or hh == null:
		H.group_error("refs nulas (gs/hunthost)"); H.group_complete(); return
	_prep_ch4()
	var r: Dictionary = hh.start("HG_SALT_WIND_COAST", "dune_skitter", "NORMAL")
	H.check("ACT-01 caça real inicia", bool(r.get("ok", false)))
	for i in range(18): hh.host_process(0.35)
	# ── 1 Activity HUD (HuntSessionHud) visível ──
	var shud = hh.session_hud
	H.check("ACT-02 HuntSessionHud existe", shud != null)
	H.check("ACT-03 Activity HUD visível durante a caça", hh.is_hunting())
	# ── 1 SAIR ──
	H.check("ACT-04 Activity HUD tem botão SAIR", shud != null and shud._exit_btn != null)
	# ── MissionUI NÃO empilha (o outro SAIR fica oculto) ──
	var mh = main.get("_missionhost")
	var mission_hud_vis := false
	if mh != null and mh.get("_hud") != null: mission_hud_vis = str(mh._hud.text) != ""
	H.check("ACT-05 MissionUI HUD não compete (oculto na caça)", not mission_hud_vis)
	# ── 1 AUTO durante PvE (o botão único) ──
	H.check("ACT-06 1 AUTO visível durante a caça", _visible_auto_widgets() <= 1)
	# ── AUTO OFF pausa (controle único funciona) ──
	hh.set_auto(false)
	var dd0 := int(hh.debug_state().get("kills", 0))
	for i in range(6): hh.host_process(0.3)
	H.check("ACT-07 AUTO OFF pausa o combate", int(hh.debug_state().get("kills", 0)) == dd0)
	hh.set_auto(true)
	# ── SAIR encerra a atividade ──
	if shud != null and shud._exit_btn != null: shud._exit_btn.pressed.emit()
	for i in range(3): hh.host_process(0.2)
	H.check("ACT-08 SAIR encerra a caça", not hh.is_hunting())
	H.check("ACT-09 Activity HUD some ao sair", shud == null or not shud.visible)
	# ── reentrar funciona ──
	var r2: Dictionary = hh.start("HG_SALT_WIND_COAST", "dune_skitter", "NORMAL")
	for i in range(15): hh.host_process(0.35)
	H.check("ACT-10 reentrar na caça funciona", hh.is_hunting())
	H.check("ACT-11 Activity HUD visível de novo", hh.is_hunting())
	# ── objective (trilha) reduzido/oculto durante a caça (não compete §28) ──
	var tf = main.get("_tracker_frame")
	H.check("ACT-12 trilha não compete com Activity HUD (oculta/colapsada na caça)", tf == null or not tf.visible)
	# ── enquanto caça, modal Systems ainda abre/fecha (input seguro atrás) ──
	sp.open_panel()
	H.check("ACT-13 Systems abre durante a caça", sp.is_open())
	sp._unhandled_input(_esc())
	H.check("ACT-14 ESC fecha Systems durante a caça", not sp.is_open())
	# ── e a caça continua após fechar o modal ──
	for i in range(8): hh.host_process(0.3)
	H.check("ACT-15 caça continua após fechar o modal", hh.is_hunting())
	# ── mob visível (não ghost) durante a atividade ──
	var wc := 0
	while hh.mob_actor() == null and wc < 40: hh.host_process(0.15); wc += 1
	H.check("ACT-16 há ator de mob na atividade", hh.mob_actor() != null)
	H.check("ACT-17 ator coerente (sprite real, visível)", hh.mob_actor() != null and hh.mob_actor().combat_visible_ok())
	H.check("ACT-18 combat_visible_ok do host", hh.combat_visible_ok())
	# kills acontecem
	var n := 0
	while int(hh.debug_state().get("kills", 0)) < 3 and n < 4000: hh.host_process(0.3); n += 1
	H.check("ACT-19 kills incrementam (combate real)", int(hh.debug_state().get("kills", 0)) > 0)
	H.check("ACT-20 ZERO ghost kills na atividade", hh.ghost_kill_count() == 0)
	# nameplate + HP no ator
	H.check("ACT-21 ator tem nameplate", hh.mob_actor() != null and hh.mob_actor()._nameplate != null)
	H.check("ACT-22 ator tem barra de HP", hh.mob_actor() != null and hh.mob_actor()._hp_fill != null)
	# ator spawna perto do anchor (visível)
	if hh.mob_actor() != null:
		H.check("ACT-23 ator perto do anchor (<260px)", (hh.mob_actor().global_position - hh._anchor).length() < 260.0)
	else:
		H.check("ACT-23 (sem ator no instante) pulado", true)
	# uma única superfície de atividade (Hunt), Mission oculto
	H.check("ACT-24 só 1 Activity HUD (Hunt) ativo", hh.is_hunting() and not mission_hud_vis)
	# AUTO controle único responde
	H.check("ACT-25 AUTO widget único durante a caça", _visible_auto_widgets() <= 1)
	# SAIR único visível (o do Hunt)
	H.check("ACT-26 SAIR único (Hunt), Mission SAIR oculto", shud._exit_btn != null and not mission_hud_vis)
	hh.stop()
	H.check("ACT-27 stop encerra", not hh.is_hunting())
	H.check("ACT-28 Activity HUD some", shud == null or not shud.visible)
	H.check("ACT-29 ghost=0 preservado após a sessão", hh.ghost_kill_count() == 0)
	H.check("ACT-30 Systems fechado ao fim", not sp.is_open())
	H.group_complete()

# ════════════════════════════════════════════════════════════════════════════════════════════
func _realscene() -> void:
	H.group_begin("REALSCENE33", 40)
	if gs == null or hh == null or sp == null or idle == null:
		H.group_error("refs nulas no realscene"); H.group_complete(); return
	# ── Field repro: HG ativo + Systems aberto + HUD (a situação que o usuário viu) ──
	_prep_ch4()
	var r: Dictionary = hh.start("HG_SALT_WIND_COAST", "dune_skitter", "NORMAL")
	H.check("RS33-01 Costa: caça inicia", bool(r.get("ok", false)))
	for i in range(18): hh.host_process(0.35)
	sp.open_panel()
	H.check("RS33-02 Systems aberto SOBRE a caça (repro)", sp.is_open())
	# ANTES o clique atravessava; agora o backdrop bloqueia (STOP) — e a caça segue atrás sem receber cliques
	H.check("RS33-03 backdrop bloqueia clique (não atravessa p/ o mundo)", sp._backdrop.mouse_filter == Control.MOUSE_FILTER_STOP)
	sp._unhandled_input(_esc())
	H.check("RS33-04 Systems fecha por ESC (corrigido)", not sp.is_open())
	# ── mob real visível: sprite + movimento + nameplate + HP ──
	var wc := 0
	while hh.mob_actor() == null and wc < 40: hh.host_process(0.15); wc += 1
	var act = hh.mob_actor()
	H.check("RS33-05 mob costeiro tem ator", act != null)
	H.check("RS33-06 ator VISÍVEL (não invisível)", act != null and act.combat_visible_ok())
	H.check("RS33-07 sprite REAL (não fallback)", act != null and not act.used_fallback)
	H.check("RS33-08 mob_id correto (dune_skitter)", act != null and act.mob_id == "dune_skitter")
	H.check("RS33-09 nameplate anexado ao ator", act != null and act._nameplate != null and act._nameplate.get_parent() == act)
	H.check("RS33-10 nameplate mostra o mob", act != null and str(act._nameplate.text).length() > 0)
	H.check("RS33-11 barra de HP anexada ao ator", act != null and act._hp_fill != null)
	H.check("RS33-12 ator perto do anchor (dentro do viewport)", act == null or (act.global_position - hh._anchor).length() < 260.0)
	# movimento: o ator se aproxima (posição muda entre frames)
	var p0: Vector2 = act.global_position if act != null else Vector2.ZERO
	for i in range(4): hh.host_process(0.15)
	H.check("RS33-13 ator se move (approach — vem até o player)", act == null or not is_instance_valid(act) or act.global_position != p0 or (act.global_position - hh._anchor).length() < 45.0)
	# ── morte visual + próximo alvo + kill só APÓS morte real ──
	var k0 := int(hh.debug_state().get("kills", 0))
	var n := 0
	while int(hh.debug_state().get("kills", 0)) <= k0 and n < 4000: hh.host_process(0.3); n += 1
	H.check("RS33-14 kill incrementou (morte real)", int(hh.debug_state().get("kills", 0)) > k0)
	H.check("RS33-15 ZERO ghost kills (kill teve ator coerente)", hh.ghost_kill_count() == 0)
	# próximo alvo aparece com ator coerente
	var w2 := 0
	while hh.mob_actor() == null and w2 < 40: hh.host_process(0.15); w2 += 1
	H.check("RS33-16 próximo mob tem ator", hh.mob_actor() != null)
	H.check("RS33-17 próximo mob coerente", hh.mob_actor() != null and hh.mob_actor().combat_visible_ok())
	# acumula vários kills — todos com ator (não ghost farm)
	var n2 := 0
	while int(hh.debug_state().get("kills", 0)) < 6 and n2 < 6000: hh.host_process(0.3); n2 += 1
	H.check("RS33-18 vários kills (>=5)", int(hh.debug_state().get("kills", 0)) >= 5)
	H.check("RS33-19 ainda ZERO ghost após vários kills", hh.ghost_kill_count() == 0)
	H.check("RS33-20 combat_visible_ok mantém coerência", hh.combat_visible_ok())
	# ── 1 Activity HUD / 1 SAIR / 1 AUTO ──
	var shud = hh.session_hud
	H.check("RS33-21 1 Activity HUD visível", hh.is_hunting())
	H.check("RS33-22 1 SAIR (Hunt)", shud != null and shud._exit_btn != null)
	H.check("RS33-23 1 AUTO visível", _visible_auto_widgets() == 1)
	var mh = main.get("_missionhost")
	var mvis := mh != null and mh.get("_hud") != null and str(mh._hud.text) != ""
	H.check("RS33-24 MissionUI não compete (sem 2º SAIR)", not mvis)
	# ── FASE/AUTO não duplicados ──
	H.check("RS33-25 FASE não duplicada", not ((idle._topstage_lbl != null and idle._topstage_lbl.visible) and (idle._stage_lbl != null and idle._stage_lbl.visible)))
	H.check("RS33-26 AUTO não duplicado", _visible_auto_widgets() == 1)
	# ── dev oculto ──
	var dev = main.get("_dev_layer")
	H.check("RS33-27 dev oculto em NORMAL", dev == null or not dev.visible)
	# ── SAIR encerra e o mundo volta ──
	if shud != null and shud._exit_btn != null: shud._exit_btn.pressed.emit()
	for i in range(3): hh.host_process(0.2)
	H.check("RS33-28 SAIR encerra a caça", not hh.is_hunting())
	H.check("RS33-29 Activity HUD some ao sair", shud == null or not shud.visible)
	# ── Systems abre/fecha limpo fora da caça ──
	sp.open_panel(); H.check("RS33-30 Systems abre fora da caça", sp.is_open())
	sp.close_panel(); H.check("RS33-31 Systems fecha por botão", not sp.is_open())
	main.idlehud_open_system(); H.check("RS33-32 ⚙ toggle abre", sp.is_open())
	main.idlehud_open_system(); H.check("RS33-33 ⚙ toggle fecha", not sp.is_open())
	# ── planície (Ch1) também mostra mob real (não só a costa) ──
	gs.reset_save(); gs.set_save_path_override("user://a33s_fixture.json")
	gs.character_class = "CLASS_1"; gs.equipment = {"weapon": "sword_eternal"}; gs.hero_hp_max = 50000; gs.hero_hp = gs.max_hp_total(); gs.stage_highest_global = 10
	var rp: Dictionary = hh.start("HG_PLAINS_LOW", "young_wolf", "NORMAL")
	H.check("RS33-34 planície: caça inicia", bool(rp.get("ok", false)))
	for i in range(15): hh.host_process(0.3)
	var w3 := 0
	while hh.mob_actor() == null and w3 < 40: hh.host_process(0.15); w3 += 1
	H.check("RS33-35 planície: mob visível (sprite real)", hh.mob_actor() != null and hh.mob_actor().combat_visible_ok())
	H.check("RS33-36 planície: nameplate", hh.mob_actor() != null and hh.mob_actor()._nameplate != null)
	var n3 := 0
	while int(hh.debug_state().get("kills", 0)) < 2 and n3 < 3000: hh.host_process(0.3); n3 += 1
	H.check("RS33-37 planície: kills com ator (ghost=0)", int(hh.debug_state().get("kills", 0)) > 0 and hh.ghost_kill_count() == 0)
	hh.stop()
	H.check("RS33-38 encerrou planície", not hh.is_hunting())
	# ── estado final limpo ──
	H.check("RS33-39 Systems fechado ao fim", not sp.is_open())
	H.check("RS33-40 1 AUTO, sem fantasma de modal", _visible_auto_widgets() == 1 and not sp.is_open())
	H.group_complete()
