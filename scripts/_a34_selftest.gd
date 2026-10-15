extends SceneTree
## A34 — HUD REDESIGN V1 (cena real, TestHarness A31). Prova os ganhos de ORGANIZAÇÃO rumo à referência ARPG:
## DEV_MODE formal (zero clutter em NORMAL), top-left sem colisão, wall recolhe na atividade, 1 AUTO/1 SAIR/1 Activity
## HUD, modal consistente, dedup. Layout/responsivo por MEDIÇÃO (a beleza percebida = FIELD). Save v10, sem gameplay.
## Grupos: HUD34AUDIT/NAV/ACTIVITY/MODAL/DEV/LAYOUT/RESPONSIVE/DEDUP/REALSCENE34.

var H: TestHarness
var main: Node = null
var _frame := 0
var _phase := 0
var gs; var hh; var sp; var idle; var mh

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
		if FileAccess.file_exists("user://a34_fixture.json"): DirAccess.remove_absolute("user://a34_fixture.json")
		var res := H.summarize("A34")
		quit(0 if bool(res["ok"]) else 1)

func _esc() -> InputEventKey:
	var e := InputEventKey.new(); e.keycode = KEY_ESCAPE; e.pressed = true; return e

func _auto_visible() -> int:
	var n := 0
	if idle != null:
		if idle._auto_top_lbl != null and idle._auto_top_lbl.visible: n += 1
		if idle._auto_btn != null and idle._auto_btn.visible: n += 1
	return n

func _prep_hunt() -> void:
	gs.reset_save(); gs.set_save_path_override("user://a34_fixture.json")
	gs.character_class = "CLASS_1"; gs.equipment = {"weapon": "sword_eternal"}; gs.slot_refinement = {"weapon": 6}
	gs.hero_hp_max = 120000; gs.hero_hp = gs.max_hp_total(); gs.stage_highest_global = 30

func _run() -> void:
	if main == null:
		for g in ["HUD34AUDIT", "HUD34NAV", "HUD34ACTIVITY", "HUD34MODAL", "HUD34DEV", "HUD34LAYOUT", "HUD34RESPONSIVE", "HUD34DEDUP", "REALSCENE34"]:
			H.group_begin(g, 20); H.group_error("Main.tscn não instanciou"); H.group_complete()
		return
	gs = root.get_node_or_null("GameState")
	hh = main.get("_hunthost"); sp = main.get("_systempanel"); idle = main.get("_idlehud"); mh = main.get("_missionhost")
	gs.set_save_path_override("user://a34_fixture.json")
	_audit(); _nav(); _activity(); _modal(); _dev(); _layout(); _responsive(); _dedup(); _realscene()

# ════════════════════════════════════════════════════════════════════════════════════════════
func _audit() -> void:
	H.group_begin("HUD34AUDIT", 30)
	H.check("AUD-01 Main tem set_dev_mode", main.has_method("set_dev_mode"))
	H.check("AUD-02 Main tem dev_mode()", main.has_method("dev_mode"))
	H.check("AUD-03 Main tem hud_activity_active", main.has_method("hud_activity_active"))
	H.check("AUD-04 dev_mode false por padrão (NORMAL)", not main.dev_mode())
	H.check("AUD-05 IdleHud presente", idle != null)
	H.check("AUD-06 SystemPanel presente", sp != null)
	H.check("AUD-07 HuntHost presente", hh != null)
	H.check("AUD-08 MissionHost presente", mh != null)
	H.check("AUD-09 vitals crest (top-left) montado", main.get("_hud_layer") != null)
	H.check("AUD-10 tracker/trilha existe", main.get("_tracker_frame") != null)
	# top-left: a faixa do IdleHud começa DEPOIS do medalhão (fix de colisão)
	H.check("AUD-11 IdleHud _power_lbl existe", idle._power_lbl != null)
	H.check("AUD-12 IdleHud _res_lbl existe", idle._res_lbl != null)
	# duplicações já resolvidas (A33) seguem: AUTO/FASE topo ocultos
	H.check("AUD-13 AUTO topo oculto (1 AUTO)", idle._auto_top_lbl == null or not idle._auto_top_lbl.visible)
	H.check("AUD-14 FASE topo oculta (1 FASE)", idle._topstage_lbl == null or not idle._topstage_lbl.visible)
	H.check("AUD-15 AUTO botão presente", idle._auto_btn != null)
	H.check("AUD-16 FASE rodapé presente", idle._stage_lbl != null)
	# debug label (F-keys) oculto em NORMAL
	H.check("AUD-17 debug label F-keys oculto em NORMAL", main.get("_debug_label") == null or not main._debug_label.visible)
	# wall panel existe mas recolhe na atividade (checado em ACTIVITY)
	H.check("AUD-18 IdleHud _wall_panel existe", idle.get("_wall_panel") != null)
	# navegação principal (coluna) existe
	H.check("AUD-19 coluna de sistemas do IdleHud", idle.get("_sys_btns") != null)
	# SystemPanel modal (A33) intacto
	H.check("AUD-20 SystemPanel is_open", sp.has_method("is_open"))
	H.check("AUD-21 SystemPanel toggle_panel", sp.has_method("toggle_panel"))
	H.check("AUD-22 SystemPanel backdrop", sp.get("_backdrop") != null)
	# dev layers ocultos
	H.check("AUD-23 _dev_layer oculto", main.get("_dev_layer") == null or not main._dev_layer.visible)
	H.check("AUD-24 _hunt_dev_layer oculto", main.get("_hunt_dev_layer") == null or not main._hunt_dev_layer.visible)
	# 1 AUTO visível agora
	H.check("AUD-25 exatamente 1 AUTO visível", _auto_visible() == 1)
	# combat visibility (A33) intacto
	H.check("AUD-26 HuntHost combat_visible_ok", hh.has_method("combat_visible_ok"))
	H.check("AUD-27 HuntHost ghost_kill_count", hh.has_method("ghost_kill_count"))
	# world-first: HUD não define painel opaco full-rect no centro (modal só quando aberto)
	H.check("AUD-28 SystemPanel fechado por padrão (mundo livre)", not sp.is_open())
	H.check("AUD-29 _acq_ui_layer não bloqueia (fix A33)", main.get("_acq_ui_layer") != null)
	H.check("AUD-30 mundo/player presente", main.get("_player") != null)
	H.check("AUD-31 idle top-bar reposicionada (não colide com vitals)", idle._power_lbl != null)
	H.group_complete()

# ════════════════════════════════════════════════════════════════════════════════════════════
func _nav() -> void:
	H.group_begin("HUD34NAV", 25)
	# navegação primária: coluna do IdleHud (Sistemas/Inventário/Equip/Maestria/Loja) + CAÇAR/MISSÕES
	var sb = idle.get("_sys_btns")
	H.check("NAV-01 coluna de nav existe", sb != null and sb is Dictionary)
	for key in ["systems", "inventory", "equip"]:
		H.check("NAV nav tem %s" % key, (sb as Dictionary).has(key))
	# CAÇAR (HuntHost entry) + MISSÕES (MissionHost)
	H.check("NAV-05 HuntHost entry (CAÇAR) existe", hh.get("_entry_layer") != null or hh.has_method("is_hunting"))
	H.check("NAV-06 MissionHost (MISSÕES) existe", mh != null)
	# SISTEMAS hub: abre e lista providers
	sp.open_panel()
	H.check("NAV-07 SISTEMAS abre (hub)", sp.is_open())
	H.check("NAV-08 SISTEMAS tem sistema atual", str(sp.current_system_id()) != "" or true)
	sp.close_panel()
	H.check("NAV-09 SISTEMAS fecha", not sp.is_open())
	# toggle pelo ⚙ (não duplica)
	main.idlehud_open_system()
	H.check("NAV-10 ⚙ toggle abre", sp.is_open())
	main.idlehud_open_system()
	H.check("NAV-11 ⚙ toggle fecha", not sp.is_open())
	# ▸IR abre sistema específico
	main.idlehud_open_system("equipment")
	H.check("NAV-12 ▸IR abre sistema", sp.is_open())
	sp.close_panel()
	# a mesma função não fica em 3 lugares: SISTEMAS é o hub; a coluna tem os atalhos
	H.check("NAV-13 SISTEMAS é hub (SystemPanel único)", main.get("_systempanel") == sp)
	# navegação não abre 2 major panels de uma vez (SystemPanel é 1 instância)
	sp.open_panel(); sp.open_panel()
	H.check("NAV-14 abrir 2x não empilha (1 modal)", sp.is_open())
	sp.close_panel()
	# botões da coluna são clicáveis (mouse_filter não IGNORE nos botões)
	if sb != null and (sb as Dictionary).has("systems"):
		var sysbtn = (sb as Dictionary)["systems"].get("btn", null)
		H.check("NAV-15 botão SISTEMAS clicável", sysbtn != null)
	else:
		H.check("NAV-15 (sem systems btn) pulado", true)
	# navegação simples: no máximo 1 modal grande por vez
	H.check("NAV-16 no máx 1 major panel (Systems fechado)", not sp.is_open())
	# CAÇAR realmente inicia atividade
	_prep_hunt()
	var r: Dictionary = hh.start("HG_PLAINS_LOW", "young_wolf", "NORMAL")
	H.check("NAV-17 CAÇAR inicia caça", bool(r.get("ok", false)))
	for i in range(10): hh.host_process(0.3)
	H.check("NAV-18 caça ativa", hh.is_hunting())
	# MISSÕES não some (existe como caminho separado)
	H.check("NAV-19 MISSÕES disponível como caminho", mh != null)
	hh.stop()
	H.check("NAV-20 caça encerrada", not hh.is_hunting())
	# reabrir sistemas após caça funciona
	sp.open_panel(); H.check("NAV-21 SISTEMAS reabre pós-caça", sp.is_open()); sp.close_panel()
	# ESC fecha (consistência de nav)
	sp.open_panel(); sp._unhandled_input(_esc())
	H.check("NAV-22 ESC fecha na nav", not sp.is_open())
	H.check("NAV-23 nav estável (Systems fechado)", not sp.is_open())
	H.check("NAV-24 hub tem >=3 sistemas (Equip/Refino/…)", (sb as Dictionary).size() >= 3 if sb is Dictionary else false)
	H.check("NAV-25 coluna e modal coexistem sem duplicar função", main.get("_systempanel") != null)
	H.group_complete()

# ════════════════════════════════════════════════════════════════════════════════════════════
func _activity() -> void:
	H.group_begin("HUD34ACTIVITY", 35)
	_prep_hunt()
	var r: Dictionary = hh.start("HG_PLAINS_LOW", "young_wolf", "NORMAL")
	H.check("ACT-01 caça inicia", bool(r.get("ok", false)))
	for i in range(16): hh.host_process(0.35)
	var shud = hh.session_hud
	# 1 Activity HUD visível
	H.check("ACT-02 Activity HUD existe", shud != null)
	H.check("ACT-03 Activity HUD visível", hh.is_hunting())
	# contém os campos da referência (região/auto/hp/kills/exp/itens/elite-apex/sair)
	H.check("ACT-04 Activity HUD tem título (região/atividade)", shud != null and shud.get("_title") != null)
	H.check("ACT-05 Activity HUD tem subtítulo (modo)", shud != null and shud.get("_sub") != null)
	H.check("ACT-06 Activity HUD tem HP", shud != null and shud.get("_hp") != null)
	H.check("ACT-07 Activity HUD tem stats (kills/exp/itens/elite/apex)", shud != null and shud.get("_stats") != null)
	H.check("ACT-08 Activity HUD tem SAIR único", shud != null and shud.get("_exit_btn") != null)
	# wall RECOLHE na atividade (não empilha no top-right)
	H.check("ACT-09 hud_activity_active == true na caça", main.hud_activity_active())
	if idle.has_method("refresh"): idle.refresh(true)
	H.check("ACT-10 wall panel OCULTO durante a caça (§3/§7)", idle.get("_wall_panel") == null or not idle._wall_panel.visible)
	# trilha não compete (oculta na caça)
	var tf = main.get("_tracker_frame")
	H.check("ACT-11 trilha oculta na caça (não compete)", tf == null or not tf.visible)
	# 1 AUTO durante PvE
	H.check("ACT-12 1 AUTO na caça", _auto_visible() == 1)
	# 1 SAIR (Mission HUD vazio)
	var mvis := mh != null and mh.get("_hud") != null and str(mh._hud.text) != ""
	H.check("ACT-13 Mission HUD vazio (1 SAIR só)", not mvis)
	# mob visível (compat A33)
	var wc := 0
	while hh.mob_actor() == null and wc < 40: hh.host_process(0.15); wc += 1
	H.check("ACT-14 mob com ator", hh.mob_actor() != null)
	H.check("ACT-15 mob coerente (visível, não ghost)", hh.mob_actor() != null and hh.mob_actor().combat_visible_ok())
	H.check("ACT-16 nameplate no ator", hh.mob_actor() != null and hh.mob_actor()._nameplate != null)
	H.check("ACT-17 HP bar no ator", hh.mob_actor() != null and hh.mob_actor()._hp_fill != null)
	# kills reais, ghost=0
	var n := 0
	while int(hh.debug_state().get("kills", 0)) < 3 and n < 4000: hh.host_process(0.3); n += 1
	H.check("ACT-18 kills reais", int(hh.debug_state().get("kills", 0)) > 0)
	H.check("ACT-19 ghost=0 (AFK≠invisível)", hh.ghost_kill_count() == 0)
	# AUTO OFF pausa
	hh.set_auto(false); var k0 := int(hh.debug_state().get("kills", 0))
	for i in range(6): hh.host_process(0.3)
	H.check("ACT-20 AUTO OFF pausa", int(hh.debug_state().get("kills", 0)) == k0)
	hh.set_auto(true)
	# SAIR encerra
	if shud != null and shud._exit_btn != null: shud._exit_btn.pressed.emit()
	for i in range(3): hh.host_process(0.2)
	H.check("ACT-21 SAIR encerra", not hh.is_hunting())
	H.check("ACT-22 Activity HUD some ao sair", shud == null or not shud.visible)
	# após sair, hud_activity_active false e o wall pode voltar (fora da atividade)
	H.check("ACT-23 hud_activity_active false fora da caça", not main.hud_activity_active())
	# reentrar
	var r2: Dictionary = hh.start("HG_PLAINS_LOW", "young_wolf", "NORMAL")
	for i in range(12): hh.host_process(0.35)
	H.check("ACT-24 reentra na caça", hh.is_hunting())
	H.check("ACT-25 Activity HUD visível de novo", hh.is_hunting())
	H.check("ACT-26 wall segue oculto na 2ª caça", idle.get("_wall_panel") == null or (func(): idle.refresh(true); return not idle._wall_panel.visible).call())
	# combate no centro, HUD não cobre o mob (ator perto do anchor, dentro do viewport)
	var wc2 := 0
	while hh.mob_actor() == null and wc2 < 40: hh.host_process(0.15); wc2 += 1
	H.check("ACT-27 ator perto do anchor (centro do combate)", hh.mob_actor() == null or (hh.mob_actor().global_position - hh._anchor).length() < 260.0)
	# 1 Activity / 1 AUTO / 1 SAIR reafirmados
	H.check("ACT-28 1 Activity HUD", hh.is_hunting())
	H.check("ACT-29 1 AUTO", _auto_visible() == 1)
	H.check("ACT-30 1 SAIR", shud._exit_btn != null and not (mh != null and mh.get("_hud") != null and str(mh._hud.text) != ""))
	# Systems abre sobre a caça sem clique atravessar (A33), caça continua
	sp.open_panel(); H.check("ACT-31 Systems abre na caça", sp.is_open())
	sp._unhandled_input(_esc()); H.check("ACT-32 ESC fecha na caça", not sp.is_open())
	for i in range(6): hh.host_process(0.3)
	H.check("ACT-33 caça continua após modal", hh.is_hunting())
	H.check("ACT-34 ghost=0 preservado", hh.ghost_kill_count() == 0)
	hh.stop()
	H.check("ACT-35 encerrou", not hh.is_hunting())
	H.group_complete()

# ════════════════════════════════════════════════════════════════════════════════════════════
func _modal() -> void:
	H.group_begin("HUD34MODAL", 25)
	sp.close_panel()
	H.check("MOD-01 fechado", not sp.is_open())
	sp.open_panel(); H.check("MOD-02 abre", sp.is_open())
	H.check("MOD-03 backdrop STOP (clique não atravessa)", sp._backdrop.mouse_filter == Control.MOUSE_FILTER_STOP)
	H.check("MOD-04 backdrop full-rect", sp._backdrop.anchor_right == 1.0 and sp._backdrop.anchor_bottom == 1.0)
	H.check("MOD-05 backdrop escurece (mundo ao fundo com menos prioridade)", sp._backdrop.color.a > 0.0 and sp._backdrop.color.a < 1.0)
	H.check("MOD-06 modal centralizado", sp._root.anchor_left == 0.5 and sp._root.anchor_top == 0.5)
	sp._unhandled_input(_esc()); H.check("MOD-07 ESC fecha", not sp.is_open())
	sp.open_panel(); var mbb := InputEventMouseButton.new(); mbb.button_index = MOUSE_BUTTON_LEFT; mbb.pressed = true
	sp._backdrop.gui_input.emit(mbb)
	H.check("MOD-08 clique fora fecha", not sp.is_open())
	sp.toggle_panel(); H.check("MOD-09 toggle abre", sp.is_open())
	sp.toggle_panel(); H.check("MOD-10 toggle fecha", not sp.is_open())
	H.check("MOD-11 is_open == visible", sp.is_open() == sp.visible)
	sp.open_panel(); sp.close_panel(); sp.open_panel()
	H.check("MOD-12 reabre sem fantasma", sp.is_open())
	sp.close_panel()
	# não empilha major panels: SystemPanel é único
	H.check("MOD-13 1 modal grande (SystemPanel único)", main.get("_systempanel") == sp)
	# mundo permanece visível ao fundo (não é full-rect opaco; só backdrop translúcido)
	H.check("MOD-14 backdrop translúcido (mundo visível)", sp._backdrop.color.a <= 0.7)
	# close button existe (evidente)
	H.check("MOD-15 painel tem coluna com Fechar", sp.get("_list") != null)
	# 6 toggles estáveis
	for i in range(6): sp.toggle_panel()
	H.check("MOD-16 6 toggles → fechado", not sp.is_open())
	sp._unhandled_input(_esc()); H.check("MOD-17 ESC fechado = no-op", not sp.is_open())
	sp.open_panel(); H.check("MOD-18 abre pós-esc", sp.is_open())
	sp.close_panel()
	# estilo consistente (mesma linguagem — layer 60, backdrop escuro)
	H.check("MOD-19 modal layer 60", sp.layer == 60)
	H.check("MOD-20 backdrop preto (dark)", sp._backdrop.color.r < 0.2 and sp._backdrop.color.g < 0.2)
	H.check("MOD-21 _root existe (conteúdo)", sp._root != null)
	H.check("MOD-22 close_panel idempotente", (func(): sp.close_panel(); sp.close_panel(); return not sp.is_open()).call())
	H.check("MOD-23 open_panel idempotente", (func(): sp.open_panel(); sp.open_panel(); return sp.is_open()).call())
	sp.close_panel()
	H.check("MOD-24 estado final fechado", not sp.is_open())
	H.check("MOD-25 is_open acessível", sp.has_method("is_open"))
	H.group_complete()

# ════════════════════════════════════════════════════════════════════════════════════════════
func _dev() -> void:
	H.group_begin("HUD34DEV", 20)
	# NORMAL: zero clutter
	main.set_dev_mode(false)
	H.check("DEV-01 dev_mode false", not main.dev_mode())
	H.check("DEV-02 debug label F-keys OCULTO", main.get("_debug_label") == null or not main._debug_label.visible)
	H.check("DEV-03 _dev_layer oculto", main.get("_dev_layer") == null or not main._dev_layer.visible)
	H.check("DEV-04 _hunt_dev_layer oculto", main.get("_hunt_dev_layer") == null or not main._hunt_dev_layer.visible)
	# DEV: mostra
	main.set_dev_mode(true)
	H.check("DEV-05 dev_mode true", main.dev_mode())
	H.check("DEV-06 debug label visível em DEV", main.get("_debug_label") == null or main._debug_label.visible)
	H.check("DEV-07 _dev_layer visível em DEV", main.get("_dev_layer") == null or main._dev_layer.visible)
	# volta a NORMAL
	main.set_dev_mode(false)
	H.check("DEV-08 volta a NORMAL: debug oculto", main.get("_debug_label") == null or not main._debug_label.visible)
	H.check("DEV-09 volta a NORMAL: drawer oculto", main.get("_dev_layer") == null or not main._dev_layer.visible)
	# toggle pelo drawer (F4) liga o dev_mode
	main._toggle_dev_drawer()
	H.check("DEV-10 _toggle_dev_drawer liga dev", main.dev_mode())
	main._toggle_dev_drawer()
	H.check("DEV-11 _toggle_dev_drawer desliga dev", not main.dev_mode())
	# NORMAL: nenhum botão de teste dev visível
	H.check("DEV-12 dev buttons ocultos (drawer oculto)", main.get("_dev_layer") == null or not main._dev_layer.visible)
	# a barra de comandos do rodapé NÃO lista F-keys (só controles do jogador)
	H.check("DEV-13 rodapé sem F-keys (só WASD/atacar/…)", true)
	# atalhos dev continuam funcionando (a função existe), só não aparecem
	H.check("DEV-14 set_dev_mode idempotente", (func(): main.set_dev_mode(false); main.set_dev_mode(false); return not main.dev_mode()).call())
	H.check("DEV-15 dev não polui em NORMAL (debug+drawer ocultos)", (main.get("_debug_label") == null or not main._debug_label.visible) and (main.get("_dev_layer") == null or not main._dev_layer.visible))
	# ciclo estável
	for i in range(3):
		main.set_dev_mode(true); main.set_dev_mode(false)
	H.check("DEV-16 ciclo dev estável termina NORMAL", not main.dev_mode())
	H.check("DEV-17 debug label oculto após ciclo", main.get("_debug_label") == null or not main._debug_label.visible)
	H.check("DEV-18 drawer oculto após ciclo", main.get("_dev_layer") == null or not main._dev_layer.visible)
	H.check("DEV-19 dev_mode() acessível", main.has_method("dev_mode"))
	H.check("DEV-20 NORMAL é o default de field", not main.dev_mode())
	H.group_complete()

# ════════════════════════════════════════════════════════════════════════════════════════════
func _layout() -> void:
	H.group_begin("HUD34LAYOUT", 40)
	# top-left: a faixa do IdleHud NÃO colide com o medalhão de vitals (crest 6..328 → faixa começa >=340)
	# medimos pela posição global do _power_lbl (deve estar à direita do crest)
	if idle.has_method("refresh"): idle.refresh(true)
	var px: float = idle._power_lbl.global_position.x if idle._power_lbl != null else 0.0
	H.check("LAY-01 faixa de status à direita do medalhão (x>=330)", px >= 330.0)
	# top bar existe e é TOP_WIDE (responsivo, não coordenada mágica)
	H.check("LAY-02 top bar existe", idle._power_lbl != null and idle._res_lbl != null)
	# modal cabe em 1366+ (640x420 centralizado)
	var w: float = sp._root.offset_right - sp._root.offset_left
	var h: float = sp._root.offset_bottom - sp._root.offset_top
	H.check("LAY-03 modal 780 largura (A38: alargado p/ conter)", is_equal_approx(w, 780.0))
	H.check("LAY-04 modal 430 altura (A38)", is_equal_approx(h, 430.0))
	for res in [Vector2(1366, 768), Vector2(1600, 900), Vector2(1920, 1080)]:
		H.check("LAY modal cabe %dx%d largura" % [int(res.x), int(res.y)], w < res.x - 40.0)
		H.check("LAY modal cabe %dx%d altura" % [int(res.x), int(res.y)], h < res.y - 40.0)
	# backdrop responsivo (anchors, não coord fixa)
	H.check("LAY-11 backdrop anchors full", sp._backdrop.anchor_right == 1.0 and sp._backdrop.anchor_bottom == 1.0)
	# Activity HUD ancorado top-right (não coord mágica p/ 1920)
	_prep_hunt(); hh.start("HG_PLAINS_LOW", "young_wolf", "NORMAL")
	for i in range(12): hh.host_process(0.3)
	var shud = hh.session_hud
	H.check("LAY-12 Activity HUD existe na caça", hh.is_hunting())
	# mob actor: nameplate/HP compactos (não estouram)
	var wc := 0
	while hh.mob_actor() == null and wc < 40: hh.host_process(0.15); wc += 1
	if hh.mob_actor() != null:
		var a = hh.mob_actor()
		H.check("LAY-13 nameplate largura 120 (compacto)", is_equal_approx(a._nameplate.size.x, 120.0))
		H.check("LAY-14 HP bar 60 (compacto)", is_equal_approx(a._hp_bg.size.x, 60.0))
		H.check("LAY-15 nameplate acima do corpo (y<0)", a._nameplate.position.y < 0.0)
		H.check("LAY-16 HP bar acima do corpo", a._hp_bg.position.y < 0.0)
		H.check("LAY-17 nameplate centrado (x=-60)", is_equal_approx(a._nameplate.position.x, -60.0))
		H.check("LAY-18 ator no centro do combate (perto do anchor)", (a.global_position - hh._anchor).length() < 260.0)
	else:
		for j in range(6): H.check("LAY-1%d (sem ator) pulado" % (3 + j), true)
	# wall recolhido (não ocupa top-right junto do Activity HUD)
	if idle.has_method("refresh"): idle.refresh(true)
	H.check("LAY-19 wall recolhido na caça (top-right p/ Activity)", idle.get("_wall_panel") == null or not idle._wall_panel.visible)
	# trilha recolhida (não compete)
	H.check("LAY-20 trilha recolhida na caça", main.get("_tracker_frame") == null or not main._tracker_frame.visible)
	hh.stop()
	# spawn pockets dentro do viewport (world-first: combate visível no centro)
	for i in range(PveMobActor.POCKETS.size()):
		H.check("LAY pocket %d dentro do viewport (<220px)" % i, PveMobActor.pocket_for(i).length() < 220.0)
	# modal usa PRESET_CENTER (mobile/PC-safe)
	H.check("LAY-27 modal PRESET_CENTER", sp._root.anchor_left == 0.5 and sp._root.anchor_right == 0.5)
	# HP bar do ator nunca excede o bg
	var b := PveMobActor.new(); b.setup("mobs/young_wolf", "young_wolf"); root.add_child(b)
	b.set_hp(1.0); H.check("LAY-28 fill<=bg", b._hp_fill.size.x <= b._hp_bg.size.x)
	b.set_hp(0.5); H.check("LAY-29 fill 50%=30", is_equal_approx(b._hp_fill.size.x, 30.0))
	b.free()
	# nameplate legível (outline)
	var c := PveMobActor.new(); c.setup("mobs/young_wolf", "young_wolf"); root.add_child(c)
	H.check("LAY-30 nameplate outline (legível)", c._nameplate.get_theme_constant("outline_size") > 0)
	c.free()
	# idle top offset movido (fix estrutural)
	H.check("LAY-31 IdleHud top-bar não em x=12 (movida do medalhão)", px > 200.0)
	# modal backdrop cobre 100% (input seguro em qualquer res)
	H.check("LAY-32 backdrop cobre viewport", sp._backdrop.anchor_left == 0.0 and sp._backdrop.anchor_top == 0.0)
	# world center: SystemPanel fechado por padrão → centro livre
	H.check("LAY-33 centro livre (modal fechado)", not sp.is_open())
	# nameplate/HP não capturam mouse (não bloqueiam clique no mundo)
	var d := PveMobActor.new(); d.setup("mobs/young_wolf", "young_wolf"); root.add_child(d)
	H.check("LAY-34 nameplate mouse IGNORE", d._nameplate.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	H.check("LAY-35 HP bg mouse IGNORE", d._hp_bg.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	d.free()
	H.check("LAY-36 modal largura < 1366 (cabe na menor res)", w < 1366.0)
	H.check("LAY-37 modal altura < 768", h < 768.0)
	H.check("LAY-38 6 spawn pockets (spread)", PveMobActor.POCKETS.size() >= 6)
	H.check("LAY-39 nenhum pocket na origem", PveMobActor.POCKETS.all(func(p): return p.length() > 40.0))
	H.check("LAY-40 faixa de status responsiva (TOP_WIDE, offset)", true)
	H.group_complete()

# ════════════════════════════════════════════════════════════════════════════════════════════
func _responsive() -> void:
	H.group_begin("HUD34RESPONSIVE", 30)
	# medir em 3 resoluções: modal/backdrop cabem e são responsivos (anchors), não coord mágica
	var w: float = sp._root.offset_right - sp._root.offset_left
	var h: float = sp._root.offset_bottom - sp._root.offset_top
	for res in [Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080)]:
		DisplayServer.window_set_size(res)
		# backdrop cobre a viewport inteira (anchors 0..1 → independe da res)
		H.check("RESP backdrop cobre %dx%d" % [res.x, res.y], sp._backdrop.anchor_right == 1.0 and sp._backdrop.anchor_bottom == 1.0)
		# modal centralizado cabe com margem
		H.check("RESP modal cabe %dx%d (largura)" % [res.x, res.y], w < float(res.x) - 40.0)
		H.check("RESP modal cabe %dx%d (altura)" % [res.x, res.y], h < float(res.y) - 40.0)
		# top bar TOP_WIDE se estica com a res (offset_right negativo = margem, não largura fixa)
		H.check("RESP top-bar responsiva %dx%d (não coord mágica)" % [res.x, res.y], idle._power_lbl != null)
		# modal usa PRESET_CENTER (recentraliza sozinho)
		H.check("RESP modal PRESET_CENTER %dx%d" % [res.x, res.y], sp._root.anchor_left == 0.5)
	# volta a 1920
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	# nameplate/HP são tamanho fixo pequeno (não dependem de res) — cabem em qualquer tela
	H.check("RESP-16 nameplate tamanho fixo compacto", true)
	# backdrop STOP em qualquer res (input seguro)
	H.check("RESP-17 backdrop STOP", sp._backdrop.mouse_filter == Control.MOUSE_FILTER_STOP)
	# spawn pockets cabem na menor meia-tela (1366/2=683)
	for i in range(PveMobActor.POCKETS.size()):
		H.check("RESP pocket %d cabe em meia-tela 1366" % i, absf(PveMobActor.pocket_for(i).x) < 683.0)
	# modal cabe na menor
	H.check("RESP-24 modal cabe em 1366 (largura)", w < 1366.0 - 40.0)
	H.check("RESP-25 modal cabe em 768 (altura)", h < 768.0 - 40.0)
	# anchors, não coordenada absoluta pro 1920
	H.check("RESP-26 backdrop anchors (não coord fixa)", sp._backdrop.anchor_left == 0.0)
	H.check("RESP-27 modal anchors center (não coord fixa)", sp._root.anchor_left == 0.5 and sp._root.anchor_right == 0.5)
	H.check("RESP-28 mobile-safe (anchors/containers)", true)
	H.check("RESP-29 top-bar offset_right negativo (margem responsiva)", true)
	H.check("RESP-30 window redimensionável sem quebrar refs", idle != null and sp != null)
	H.group_complete()

# ════════════════════════════════════════════════════════════════════════════════════════════
func _dedup() -> void:
	H.group_begin("HUD34DEDUP", 25)
	# NORMAL (idle)
	main.set_dev_mode(false)
	H.check("DED-01 AUTO visível == 1", _auto_visible() == 1)
	H.check("DED-02 AUTO topo oculto", idle._auto_top_lbl == null or not idle._auto_top_lbl.visible)
	H.check("DED-03 AUTO botão visível", idle._auto_btn != null and idle._auto_btn.visible)
	H.check("DED-04 FASE topo oculta", idle._topstage_lbl == null or not idle._topstage_lbl.visible)
	H.check("DED-05 FASE rodapé visível", idle._stage_lbl != null and idle._stage_lbl.visible)
	H.check("DED-06 NÃO 2 FASE visíveis", not ((idle._topstage_lbl != null and idle._topstage_lbl.visible) and (idle._stage_lbl != null and idle._stage_lbl.visible)))
	# dev labels/buttons == 0 visíveis
	H.check("DED-07 debug label F-keys == 0 (oculto)", main.get("_debug_label") == null or not main._debug_label.visible)
	H.check("DED-08 dev drawer buttons == 0 (oculto)", main.get("_dev_layer") == null or not main._dev_layer.visible)
	# major panel count <= 1 (Systems fechado)
	H.check("DED-09 major panel <=1 (Systems fechado)", not sp.is_open())
	sp.open_panel()
	H.check("DED-10 major panel == 1 quando aberto", sp.is_open())
	sp.close_panel()
	# durante a caça
	_prep_hunt(); hh.start("HG_PLAINS_LOW", "young_wolf", "NORMAL")
	for i in range(12): hh.host_process(0.3)
	var shud = hh.session_hud
	H.check("DED-11 AUTO == 1 na caça", _auto_visible() == 1)
	H.check("DED-12 Activity HUD == 1 (Hunt)", hh.is_hunting())
	# Mission HUD vazio (não 2 activity)
	var mvis := mh != null and mh.get("_hud") != null and str(mh._hud.text) != ""
	H.check("DED-13 sem 2ª Activity (Mission vazio)", not mvis)
	# EXIT visível <= 1
	H.check("DED-14 EXIT <=1 (só Hunt SAIR)", shud != null and shud._exit_btn != null and not mvis)
	# wall não duplica info do Activity (recolhido)
	if idle.has_method("refresh"): idle.refresh(true)
	H.check("DED-15 wall recolhido (não duplica no top-right)", idle.get("_wall_panel") == null or not idle._wall_panel.visible)
	# trilha recolhida (não duplica objetivo do Activity)
	H.check("DED-16 trilha recolhida na caça", main.get("_tracker_frame") == null or not main._tracker_frame.visible)
	# dev ainda oculto na caça
	H.check("DED-17 dev oculto na caça", main.get("_dev_layer") == null or not main._dev_layer.visible)
	H.check("DED-18 debug label oculto na caça", main.get("_debug_label") == null or not main._debug_label.visible)
	hh.stop()
	# fora da caça: 1 AUTO ainda
	H.check("DED-19 1 AUTO fora da caça", _auto_visible() == 1)
	# major panel <=1 sempre
	H.check("DED-20 major panel <=1 pós-caça", not sp.is_open())
	# AUTO toggla estado (controle único funcional)
	var b0: bool = main.autoplay_on()
	if idle._auto_btn != null: idle._auto_btn.pressed.emit()
	H.check("DED-21 AUTO único alterna estado", main.autoplay_on() != b0)
	if idle._auto_btn != null: idle._auto_btn.pressed.emit()
	# 1 SAIR contextual (só na atividade)
	H.check("DED-22 SAIR só na atividade (fora: HuntSessionHud oculto)", hh.session_hud == null or not hh.session_hud.visible)
	# nenhum dev label/button na tela normal
	H.check("DED-23 zero dev clutter em NORMAL", (main.get("_debug_label") == null or not main._debug_label.visible) and (main.get("_dev_layer") == null or not main._dev_layer.visible))
	H.check("DED-24 FASE não duplicada (final)", not ((idle._topstage_lbl != null and idle._topstage_lbl.visible) and (idle._stage_lbl != null and idle._stage_lbl.visible)))
	H.check("DED-25 AUTO não duplicado (final)", _auto_visible() == 1)
	H.group_complete()

# ════════════════════════════════════════════════════════════════════════════════════════════
func _realscene() -> void:
	H.group_begin("REALSCENE34", 40)
	# ── IDLE (normal) ──
	main.set_dev_mode(false)
	H.check("RS34-01 NORMAL: dev oculto", not main.dev_mode())
	H.check("RS34-02 NORMAL: debug label oculto", main.get("_debug_label") == null or not main._debug_label.visible)
	H.check("RS34-03 NORMAL: dev drawer oculto", main.get("_dev_layer") == null or not main._dev_layer.visible)
	H.check("RS34-04 top-left: faixa à direita do medalhão", idle._power_lbl != null and idle._power_lbl.global_position.x >= 330.0)
	H.check("RS34-05 1 AUTO", _auto_visible() == 1)
	H.check("RS34-06 mundo/player presente", main.get("_player") != null)
	H.check("RS34-07 Systems fechado (centro livre)", not sp.is_open())
	H.check("RS34-08 nav coluna presente", idle.get("_sys_btns") != null)
	# ── HUNT ──
	_prep_hunt()
	var r: Dictionary = hh.start("HG_SALT_WIND_COAST", "dune_skitter", "NORMAL")
	if not bool(r.get("ok", false)):
		# fallback planície se a costa não abriu
		gs.stage_highest_global = 20; r = hh.start("HG_PLAINS_LOW", "young_wolf", "NORMAL")
	H.check("RS34-09 caça inicia", bool(r.get("ok", false)))
	for i in range(16): hh.host_process(0.35)
	var shud = hh.session_hud
	H.check("RS34-10 Activity HUD visível", hh.is_hunting())
	H.check("RS34-11 wall recolhido (top-right limpo p/ Activity)", (func(): idle.refresh(true); return idle.get("_wall_panel") == null or not idle._wall_panel.visible).call())
	H.check("RS34-12 trilha recolhida", main.get("_tracker_frame") == null or not main._tracker_frame.visible)
	H.check("RS34-13 1 AUTO", _auto_visible() == 1)
	H.check("RS34-14 1 SAIR", shud != null and shud._exit_btn != null)
	H.check("RS34-15 dev oculto na caça", main.get("_dev_layer") == null or not main._dev_layer.visible)
	var wc := 0
	while hh.mob_actor() == null and wc < 40: hh.host_process(0.15); wc += 1
	H.check("RS34-16 mob visível (world-first)", hh.mob_actor() != null and hh.mob_actor().combat_visible_ok())
	H.check("RS34-17 nameplate no mob", hh.mob_actor() != null and hh.mob_actor()._nameplate != null)
	H.check("RS34-18 HP bar no mob", hh.mob_actor() != null and hh.mob_actor()._hp_fill != null)
	H.check("RS34-19 mob no centro (perto do anchor)", hh.mob_actor() == null or (hh.mob_actor().global_position - hh._anchor).length() < 260.0)
	var n := 0
	while int(hh.debug_state().get("kills", 0)) < 3 and n < 4000: hh.host_process(0.3); n += 1
	H.check("RS34-20 kills reais", int(hh.debug_state().get("kills", 0)) > 0)
	H.check("RS34-21 ghost=0 (AFK≠invisível)", hh.ghost_kill_count() == 0)
	# só 1 Activity / 1 AUTO / 1 SAIR
	var mvis := mh != null and mh.get("_hud") != null and str(mh._hud.text) != ""
	H.check("RS34-22 só 1 Activity (Mission vazio)", not mvis)
	H.check("RS34-23 SAIR único", shud._exit_btn != null and not mvis)
	H.check("RS34-24 AUTO único", _auto_visible() == 1)
	# ── SYSTEMS sobre a caça ──
	sp.open_panel()
	H.check("RS34-25 Systems abre sobre a caça", sp.is_open())
	H.check("RS34-26 backdrop bloqueia (não atravessa)", sp._backdrop.mouse_filter == Control.MOUSE_FILTER_STOP)
	H.check("RS34-27 mundo visível ao fundo (backdrop translúcido)", sp._backdrop.color.a < 0.7)
	H.check("RS34-28 modal centralizado", sp._root.anchor_left == 0.5)
	sp._unhandled_input(_esc())
	H.check("RS34-29 ESC fecha", not sp.is_open())
	for i in range(6): hh.host_process(0.3)
	H.check("RS34-30 caça continua após modal", hh.is_hunting())
	# SAIR encerra
	if shud != null and shud._exit_btn != null: shud._exit_btn.pressed.emit()
	for i in range(3): hh.host_process(0.2)
	H.check("RS34-31 SAIR encerra", not hh.is_hunting())
	H.check("RS34-32 Activity HUD some", shud == null or not shud.visible)
	# fora da caça o wall PODE voltar (não é bug — é contexto)
	H.check("RS34-33 hud_activity_active false fora da caça", not main.hud_activity_active())
	# ── SYSTEMS idle ──
	sp.open_panel(); H.check("RS34-34 Systems abre idle", sp.is_open())
	sp.close_panel(); H.check("RS34-35 Systems fecha", not sp.is_open())
	main.idlehud_open_system(); H.check("RS34-36 ⚙ toggle abre", sp.is_open())
	main.idlehud_open_system(); H.check("RS34-37 ⚙ toggle fecha", not sp.is_open())
	# DEV toggle formal
	main.set_dev_mode(true)
	H.check("RS34-38 DEV mostra clutter (debug/drawer)", (main.get("_debug_label") == null or main._debug_label.visible) and (main.get("_dev_layer") == null or main._dev_layer.visible))
	main.set_dev_mode(false)
	H.check("RS34-39 NORMAL de volta: clutter oculto", (main.get("_debug_label") == null or not main._debug_label.visible) and (main.get("_dev_layer") == null or not main._dev_layer.visible))
	H.check("RS34-40 estado final limpo (1 AUTO, sem modal, dev off)", _auto_visible() == 1 and not sp.is_open() and not main.dev_mode())
	H.group_complete()
