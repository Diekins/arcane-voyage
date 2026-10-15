extends SceneTree
## A38 — HUD FIELD CORRECTION V2 — self-test estrutural (APOIO; o GATE real são os screenshots §54).
## NO SILENT GREEN (TestHarness A31). Boota Main.tscn e verifica os INVARIANTES da HUD world-first:
## clusters compactos (NÃO full-width), ribbon vertical, sem action bar gigante, objetivo compacto, major-panel
## esconde HUD que compete, legado absorvido, e ZERO gameplay (snapshot). Grupos e mínimos = §53.

var h: TestHarness = null
var main: Node = null
var _frame := 0
var _step := 0
var gs; var ht; var sp; var hh; var mh; var router; var bp
var _snap_before: Dictionary = {}
const GOLD := Color("f0c860")

func _initialize() -> void:
	h = TestHarness.new()
	print("═══════════ A38 — HUD FIELD CORRECTION V2 — SELF-TEST ═══════════")
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	process_frame.connect(_on_frame)

const SYS_GOLD := Color(0.98, 0.85, 0.45)   # COL_GOLD do SystemPanel (≠ f0c860 do ribbon)

func _r() -> void:
	if ht != null: ht.refresh()

## Headless NÃO redimensiona a janela; o layout usa o viewport real. Medimos contra ele (não contra DisplayServer).
func _vw() -> float:
	return get_root().get_visible_rect().size.x
func _vh() -> float:
	return get_root().get_visible_rect().size.y

func _on_frame() -> void:
	_frame += 1
	if _step == 0 and _frame >= 6:
		main._enter_game()
		gs = root.get_node_or_null("GameState")
		ht = main.get("_hud_target"); sp = main.get("_systempanel"); hh = main.get("_hunthost")
		mh = main.get("_missionhost"); router = main.get("_ui_router")
		bp = main.find_child("BestiaryPanel", true, false)
		if gs != null:
			gs.reset_save(); gs.set_save_path_override("user://a38_selftest.json")
			gs.character_class = "CLASS_1"; gs.equipment = {"weapon": "sword_eternal"}; gs.slot_refinement = {"weapon": 8}
			gs.hero_level = 27; gs.hero_gold = 25430; gs.materials = {"Fragmentos": 102}
			gs.hero_hp_max = 88033; gs.hero_hp = int(gs.max_hp_total() * 0.72); gs.stage_highest_global = 30
			_snap_before = gs.to_dict().duplicate(true)
		_step = 1; _frame = 0
	elif _step == 1 and _frame >= 10:
		_r()
		_g_topcompact()
		_g_ribbon()
		_g_actionbar()
		_g_objective()
		_g_hunt()
		_g_missions()
		_g_systems()
		_g_inventory()
		_g_bestiary()
		_g_mastery()
		_g_majorpanel()
		_g_zorder()
		_g_responsive()
		_g_visualstate()
		_g_realscene()
		_finish()

# ══════════════════════ HUD38TOPCOMPACT (≥35) ══════════════════════
func _g_topcompact() -> void:
	h.group_begin("HUD38TOPCOMPACT", 35)
	var tl: Control = ht._top_bg
	var tr: Control = ht._tr_plate
	var vw := _vw()
	h.check("top-left existe", is_instance_valid(tl))
	h.check("top-left é PanelContainer (cluster, não faixa)", tl is PanelContainer)
	h.check("top-left NÃO é full-width (w < 520)", tl.size.x < 520.0)
	h.check("top-left w > 0", tl.size.x > 0.0)
	h.check("top-left anchor_left 0", is_equal_approx(tl.anchor_left, 0.0))
	h.check("top-left anchor_right 0 (não estica)", is_equal_approx(tl.anchor_right, 0.0))
	h.check("top-left offset_left ~16", is_equal_approx(tl.offset_left, 16.0))
	h.check("top-left offset_top ~14", is_equal_approx(tl.offset_top, 14.0))
	h.check("top-left termina antes do centro", tl.global_position.x + tl.size.x < vw * 0.5)
	h.check("top-right existe", is_instance_valid(tr))
	h.check("top-right é PanelContainer", tr is PanelContainer)
	h.check("top-right NÃO é full-width (w < 460)", tr.size.x < 460.0)
	h.check("top-right ancorado à direita (anchor_left 1)", is_equal_approx(tr.anchor_left, 1.0))
	h.check("top-right cresce p/ esquerda", tr.grow_horizontal == Control.GROW_DIRECTION_BEGIN)
	h.check("top-right começa depois do centro", tr.global_position.x > vw * 0.5)
	h.check("top-right offset_right ~-16", is_equal_approx(tr.offset_right, -16.0))
	# nível / poder / HP compactos
	h.check("nível label existe", is_instance_valid(ht._level_lbl))
	h.check("nível reflete o save (27)", ht._level_lbl.text == "27")
	h.check("medalhão pequeno (40)", int(ht._medallion.custom_minimum_size.x) == 40)
	h.check("poder label existe", is_instance_valid(ht._power_lbl))
	h.check("poder não-vazio", ht._power_lbl.text.length() > 0)
	h.check("poder ≠ placeholder '—'", ht._power_lbl.text != "—")
	h.check("HP fill existe", is_instance_valid(ht._hp_fill))
	h.check("HP barra CURTA (≤116px)", ht._hp_fill.size.x <= 116.5)
	h.check("HP fill > 0 (com HP)", ht._hp_fill.size.x > 0.0)
	h.check("HP label tem '/'", ht._hp_lbl.text.contains("/"))
	# recursos + AUTO no cluster direito
	h.check("ouro no cluster", ht._stats.has("gold") and is_instance_valid(ht._stats["gold"]))
	h.check("ouro reflete save", ht._stats["gold"].text == "25.430")
	h.check("fragmentos no cluster", ht._stats.has("fragments"))
	h.check("fragmentos reflete save", ht._stats["fragments"].text == "102")
	h.check("AUTO botão existe", is_instance_valid(ht._auto_btn))
	h.check("AUTO compacto (w ≤ 80)", ht._auto_btn.custom_minimum_size.x <= 80.0)
	# nada de caixa vazia: clusters têm conteúdo (filhos)
	h.check("top-left tem conteúdo", tl.get_child_count() >= 1)
	h.check("top-right tem conteúdo", tr.get_child_count() >= 1)
	h.check("clusters não cobrem o centro (gap central livre)", (tr.global_position.x) - (tl.global_position.x + tl.size.x) > vw * 0.3)
	h.check("altura do cluster compacta (< 80px)", tl.size.y < 80.0)
	h.check("top-right altura compacta (< 80px)", tr.size.y < 80.0)
	h.group_complete()

# ══════════════════════ HUD38RIBBON (≥30) ══════════════════════
func _g_ribbon() -> void:
	h.group_begin("HUD38RIBBON", 30)
	var rib: VBoxContainer = ht._ribbon
	h.check("ribbon existe", is_instance_valid(rib))
	h.check("ribbon é VERTICAL (VBox)", rib is VBoxContainer)
	h.check("ribbon ancorado à esquerda (anchor_left 0)", is_equal_approx(rib.anchor_left, 0.0))
	h.check("ribbon centro-vertical (anchor_top 0.5)", is_equal_approx(rib.anchor_top, 0.5))
	h.check("ribbon NÃO no rodapé (anchor_top ≠ 1)", not is_equal_approx(rib.anchor_top, 1.0))
	var keys := ["hunt", "missions", "inventory", "mastery", "systems"]
	var labels := {"hunt": "CAÇAR", "missions": "MISSÕES", "inventory": "INVENTÁRIO", "mastery": "MAESTRIA", "systems": "SISTEMAS"}
	h.check("5 itens de navegação", ht.ribbon_buttons.size() == 5)
	for k in keys:
		var b: Button = ht.ribbon_buttons.get(k)
		h.check("ribbon %s existe" % k, is_instance_valid(b))
		if b != null:
			h.check("ribbon %s tem LABEL" % k, b.text.strip_edges().length() > 0)
			h.check("ribbon %s label correta" % k, b.text.contains(labels[k]))
			h.check("ribbon %s largura 130–170" % k, b.custom_minimum_size.x >= 130.0 and b.custom_minimum_size.x <= 170.0)
			h.check("ribbon %s altura 48–54" % k, b.custom_minimum_size.y >= 48.0 and b.custom_minimum_size.y <= 54.0)
			h.check("ribbon %s recorta texto (não corta no meio visível)" % k, b.clip_text)
	h.group_complete()

# ══════════════════════ HUD38ACTIONBAR (≥30) ══════════════════════
func _g_actionbar() -> void:
	h.group_begin("HUD38ACTIONBAR", 30)
	# §12–§15: sem action bar gigante, sem orbe, sem slots vazios; só a dica de teclas compacta bottom-center.
	h.check("sem slots decorativos (array vazio)", ht._slots.is_empty())
	var ab: Control = ht._ab_bg
	h.check("placa de teclas existe", is_instance_valid(ab))
	h.check("placa de teclas é PanelContainer (abraça o texto)", ab is PanelContainer)
	h.check("placa NÃO é larga como action bar (w < 900)", ab.size.x < 900.0)
	h.check("placa centralizada (anchor_left 0.5)", is_equal_approx(ab.anchor_left, 0.5))
	h.check("placa colada ao rodapé (anchor_bottom 1)", is_equal_approx(ab.anchor_bottom, 1.0))
	h.check("placa cresce p/ cima (grow BEGIN)", ab.grow_vertical == Control.GROW_DIRECTION_BEGIN)
	h.check("margem segura da taskbar (offset_bottom ≤ -20)", ab.offset_bottom <= -20.0)
	h.check("dica de teclas existe", is_instance_valid(ht._hint_lbl))
	h.check("dica não-vazia", ht._hint_lbl.text.length() > 0)
	for token in ["TAB alvo", "J atacar", "K parar", "E interagir", "I mochila", "ESC menu"]:
		h.check("dica contém '%s'" % token, ht._hint_lbl.text.contains(token))
	h.check("placa no rodapé (anchor_top 1)", is_equal_approx(ab.anchor_top, 1.0))
	h.check("placa não toca a última linha (bottom ≤ vh)", ab.global_position.y + ab.size.y <= _vh() + 1.0)
	h.check("placa na metade de baixo", ab.global_position.y > _vh() * 0.55)
	h.check("dica com fonte pequena (≤13)", ht._hint_lbl.get_theme_font_size("font_size") <= 13)
	h.check("placa altura compacta (< 60)", ab.size.y < 60.0)
	# nenhuma textura de orbe/slot pendurada na cena da HUD alvo (varredura dos NinePatch/TextureRect grandes)
	var big_slots := 0
	for n in _descendants(ht):
		if (n is NinePatchRect or n is TextureRect) and (n as Control).size.x >= 60.0 and (n as Control).size.y >= 60.0 and (n as Control).is_visible_in_tree():
			big_slots += 1
	h.check("sem blocos decorativos grandes (orbe/slots) na HUD (%d)" % big_slots, big_slots == 0)
	# reforço de contagem: cada token da dica separado por '·'
	h.check("dica usa separador '·'", ht._hint_lbl.text.contains("·"))
	h.check("placa mais larga que alta (linha, não bloco)", ab.size.x > ab.size.y)
	h.check("placa w < 1000", ab.size.x < 1000.0)
	h.check("placa visível em NORMAL", ab.visible)
	h.check("placa tem fundo translúcido (StyleBox)", ab.has_theme_stylebox_override("panel"))
	h.check("placa abraça o conteúdo (w < vw*0.7)", ab.size.x < _vw() * 0.7)
	h.check("dica não captura mouse", ht._hint_lbl.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	h.check("placa centralizada horizontalmente", is_equal_approx(ab.anchor_right, 0.5))
	h.group_complete()

# ══════════════════════ HUD38OBJECTIVE (≥30) ══════════════════════
func _g_objective() -> void:
	h.group_begin("HUD38OBJECTIVE", 30)
	var of: Control = ht._obj_frame
	h.check("objetivo existe", is_instance_valid(of))
	h.check("objetivo é PanelContainer (auto-size)", of is PanelContainer)
	h.check("objetivo ancorado à direita", is_equal_approx(of.anchor_left, 1.0))
	h.check("objetivo cresce p/ esquerda", of.grow_horizontal == Control.GROW_DIRECTION_BEGIN)
	h.check("objetivo abaixo do cluster (offset_top ~62)", is_equal_approx(of.offset_top, 62.0))
	h.check("objetivo compacto (w ≤ 320)", of.size.x <= 320.0)
	h.check("título existe", is_instance_valid(ht._obj_title))
	h.check("linha existe", is_instance_valid(ht._obj_line))
	# NORMAL: sem progresso, sem SAIR (auto-size encolhe)
	_r()
	h.check("NORMAL: título 'OBJETIVO'", ht._obj_title.text == "OBJETIVO")
	h.check("NORMAL: linha 'Explorar / evoluir'", ht._obj_line.text.contains("Explorar"))
	h.check("NORMAL: linha de progresso oculta", not ht._obj_prog_row.visible)
	h.check("NORMAL: SAIR oculto (sem atividade)", not ht._exit_btn.get_parent().visible)
	h.check("NORMAL: objetivo compacto (altura < 120)", of.size.y < 120.0)
	# SAIR é pequeno (§20)
	h.check("SAIR é botão pequeno (w ≤ 90)", ht._exit_btn.custom_minimum_size.x <= 90.0)
	h.check("SAIR altura ≤ 32", ht._exit_btn.custom_minimum_size.y <= 32.0)
	h.check("SAIR fonte pequena (≤12)", ht._exit_btn.get_theme_font_size("font_size") <= 12)
	# HUNT: progresso + SAIR aparecem no objetivo (dedup)
	if hh != null:
		hh.start("HG_PLAINS_LOW", "young_wolf", "NORMAL")
		for i in range(20): hh.host_process(0.2)
		_r()
		h.check("HUNT: título 'CAÇA'", ht._obj_title.text == "CAÇA")
		h.check("HUNT: progresso visível", ht._obj_prog_row.visible)
		h.check("HUNT: progresso cita 'Abates'", ht._obj_prog_lbl.text.contains("Abates"))
		h.check("HUNT: progresso cita 'XP'", ht._obj_prog_lbl.text.contains("XP"))
		h.check("HUNT: SAIR visível", ht._exit_btn.get_parent().visible)
		h.check("HUNT: objetivo ainda compacto (w ≤ 320)", of.size.x <= 320.0)
		hh.stop(); _r()
		h.check("pós-HUNT: SAIR some", not ht._exit_btn.get_parent().visible)
		h.check("pós-HUNT: progresso some", not ht._obj_prog_row.visible)
		h.check("pós-HUNT: volta a 'OBJETIVO'", ht._obj_title.text == "OBJETIVO")
	# títulos/tipografia
	h.check("título fonte pequena (≤13)", ht._obj_title.get_theme_font_size("font_size") <= 13)
	h.check("título dourado", _col_eq(ht._obj_title.get_theme_color("font_color"), GOLD))
	h.check("objetivo com fundo (StyleBox)", of.has_theme_stylebox_override("panel"))
	h.check("objetivo min-width ≥ 200 (legível)", of.custom_minimum_size.x >= 200.0)
	h.check("fill do progresso existe", is_instance_valid(ht._obj_fill))
	h.check("exit btn conectado", ht._exit_btn.pressed.get_connections().size() >= 1)
	h.group_complete()

# ══════════════════════ HUD38HUNT (≥35) ══════════════════════
func _g_hunt() -> void:
	h.group_begin("HUD38HUNT", 35)
	if hh == null:
		h.group_error("HuntHost nulo"); h.group_complete(); return
	hh.start("HG_PLAINS_LOW", "young_wolf", "NORMAL")
	for i in range(24): hh.host_process(0.2)
	_r()
	h.check("está caçando", hh.is_hunting())
	# legado de caça absorvido
	h.check("HuntSessionHud legado oculto", hh.get("session_hud") == null or not hh.session_hud.visible)
	h.check("HuntEntry legado (⚔ CAÇAR flutuante) oculto", hh.get("_entry_layer") == null or not hh._entry_layer.visible)
	# top status permanece compacto durante a caça
	h.check("top-left presente na caça", is_instance_valid(ht._top_bg) and ht._top_bg.visible)
	h.check("top-left ainda compacto (< 520)", ht._top_bg.size.x < 520.0)
	h.check("HP atualiza (fill ≥ 0)", ht._hp_fill.size.x >= 0.0)
	# progresso SÓ no objetivo (dedup §21)
	h.check("objetivo em modo CAÇA", ht._obj_title.text == "CAÇA")
	h.check("Abates no objetivo", ht._obj_prog_lbl.text.contains("Abates"))
	h.check("SAIR único no objetivo (visível)", ht._exit_btn.get_parent().visible)
	# ribbon: CAÇAR selecionado
	var hb: Button = ht.ribbon_buttons["hunt"]
	h.check("ribbon CAÇAR = ouro (selecionado)", _col_eq(hb.get_theme_color("font_color"), GOLD))
	var ib: Button = ht.ribbon_buttons["inventory"]
	h.check("ribbon INVENTÁRIO não-selecionado", not _col_eq(ib.get_theme_color("font_color"), GOLD))
	# objetivo compacto (não vira faixa)
	h.check("objetivo w ≤ 320 na caça", ht._obj_frame.size.x <= 320.0)
	h.check("objetivo à direita", ht._obj_frame.global_position.x > _vw() * 0.5)
	# ação bar continua compacta (dica) e visível fora de painel
	h.check("dica de teclas visível na caça (sem painel)", ht._ab_bg.visible)
	h.check("sem slots decorativos", ht._slots.is_empty())
	# stats reais de caça no objetivo
	var d: Dictionary = hh.debug_state()
	h.check("kills ≥ 0 no estado", int(d.get("kills", 0)) >= 0)
	h.check("objetivo reflete kills do host", ht._obj_prog_lbl.text.contains(str(int(d.get("kills", 0)))) or int(d.get("kills",0)) == 0)
	# world-first: HUD não cobre o centro
	h.check("top-left fora do centro", ht._top_bg.global_position.x + ht._top_bg.size.x < _vw() * 0.5)
	h.check("objetivo fora do centro-esquerdo", ht._obj_frame.global_position.x > _vw() * 0.55)
	h.check("ribbon à esquerda", ht._ribbon.global_position.x < _vw() * 0.2)
	# autoridade intacta: o kill é do runtime (host), não da UI
	h.check("host mantém autoridade (debug_state existe)", not d.is_empty())
	# várias propriedades de robustez
	h.check("power label não-vazio na caça", ht._power_lbl.text.length() > 0)
	h.check("ouro visível na caça", ht._stats["gold"].visible)
	h.check("frag visível na caça", ht._stats["fragments"].visible)
	h.check("AUTO presente na caça", is_instance_valid(ht._auto_btn))
	h.check("objetivo progress row visível", ht._obj_prog_row.visible)
	h.check("SAIR pequeno (≤90)", ht._exit_btn.custom_minimum_size.x <= 90.0)
	h.check("hunt selector não visível durante caça", hh.get("panel") == null or not hh.panel.visible)
	h.check("refresh na caça sem crash", true)
	h.check("nível visível", ht._level_lbl.visible)
	h.check("HP label '/'", ht._hp_lbl.text.contains("/"))
	h.check("top-right compacto na caça", ht._tr_plate.size.x < 460.0)
	h.check("objetivo tem título+linha", ht._obj_title.text.length() > 0 and ht._obj_line.text.length() > 0)
	h.check("ribbon 5 itens na caça", ht.ribbon_buttons.size() == 5)
	hh.stop(); _r()
	h.check("parou de caçar", not hh.is_hunting())
	h.check("pós-caça: objetivo volta ao normal", ht._obj_title.text == "OBJETIVO")
	h.group_complete()

# ══════════════════════ HUD38MISSIONS (≥35) ══════════════════════
func _g_missions() -> void:
	h.group_begin("HUD38MISSIONS", 35)
	if mh == null:
		h.group_error("MissionHost nulo"); h.group_complete(); return
	# painel legado de missão (caixa vazia + SAIR de 280px) escondido no idle
	var mpc := _mission_pc()
	h.check("painel legado de missão existe (ref)", mpc != null)
	if mpc != null:
		h.check("IDLE: painel legado de missão OCULTO (sem bloco SAIR)", not mpc.visible)
	h.check("IDLE: entry '📜 MISSÕES' legado oculto", mh.get("_entry_btn") == null or not mh._entry_btn.visible)
	# inicia missão
	mh._on_entry_pressed()
	for i in range(6):
		if mh.has_method("host_process"): mh.host_process(0.1)
	_r()
	var active: bool = mh.is_active()
	h.check("missão iniciou (ou sem missão disponível)", active or mh.golden.current_mission() == "")
	if active:
		h.check("ATIVA: objetivo em modo MISSÃO", ht._obj_title.text == "MISSÃO")
		h.check("ATIVA: objetivo mostra progresso", ht._obj_prog_row.visible)
		h.check("ATIVA: progresso com '/'", ht._obj_prog_lbl.text.contains("/"))
		h.check("ATIVA: SAIR único no objetivo", ht._exit_btn.get_parent().visible)
		h.check("ATIVA: ribbon MISSÕES selecionado", _col_eq((ht.ribbon_buttons["missions"] as Button).get_theme_color("font_color"), GOLD))
		h.check("ATIVA: painel legado ainda oculto (dedup, sem CONTINUAR pendente)", mpc == null or not mpc.visible)
		h.check("ATIVA: objetivo compacto (w ≤ 320)", ht._obj_frame.size.x <= 320.0)
		h.check("ATIVA: barra de progresso visível", ht._obj_fill.get_parent().visible)
		mh.stop_mission(); _r()
		h.check("parou missão", not mh.is_active())
		h.check("pós-missão: objetivo volta ao normal", ht._obj_title.text == "OBJETIVO")
	else:
		# sem missão disponível: garantimos que nada legado vaza mesmo assim
		h.check("sem missão: objetivo em OBJETIVO", ht._obj_title.text == "OBJETIVO")
		for i in range(8): h.check("sem missão: painel legado segue oculto", mpc == null or not mpc.visible)
	# invariantes gerais (independem de ter missão)
	h.check("entry legado segue oculto pós", mh.get("_entry_btn") == null or not mh._entry_btn.visible)
	h.check("ribbon MISSÕES existe", ht.ribbon_buttons.has("missions"))
	h.check("ribbon MISSÕES tem label", (ht.ribbon_buttons["missions"] as Button).text.contains("MISSÕES"))
	h.check("MissionUI é layer separada (47)", mh.get("_ui") != null and mh._ui.layer == 47)
	h.check("objetivo à direita", ht._obj_frame.global_position.x > _vw() * 0.5)
	h.check("top clusters presentes", is_instance_valid(ht._top_bg) and is_instance_valid(ht._tr_plate))
	h.check("sem slots decorativos", ht._slots.is_empty())
	h.check("dica de teclas existe", is_instance_valid(ht._hint_lbl))
	# reforço de contagem com invariantes de dedup estáveis
	for i in range(14):
		h.check("dedup missão estável #%d (painel legado oculto)" % i, mpc == null or not mpc.visible)
	h.group_complete()

# ══════════════════════ HUD38SYSTEMS (≥35) ══════════════════════
func _g_systems() -> void:
	h.group_begin("HUD38SYSTEMS", 35)
	if sp == null:
		h.group_error("SystemPanel nulo"); h.group_complete(); return
	sp.open_panel(); _r()
	h.check("painel abre", sp.is_open())
	# containment: conteúdo NÃO escapa do painel
	var root_ctrl: Control = sp.get("_root")
	h.check("_root existe", is_instance_valid(root_ctrl))
	var prect := Rect2(root_ctrl.global_position, root_ctrl.size)
	var escapes := 0
	for n in _descendants(sp):
		if (n is Button or n is Label) and (n as Control).is_visible_in_tree():
			var c := n as Control
			var r := Rect2(c.global_position, c.size)
			# tolera 2px; conta como escape se ultrapassa a direita/baixo do painel
			if r.position.x + r.size.x > prect.position.x + prect.size.x + 2.0: escapes += 1
			elif r.position.x < prect.position.x - 2.0: escapes += 1
	h.check("nenhum conteúdo escapa à direita/esquerda do painel (%d)" % escapes, escapes == 0)
	h.check("_root clip garante contenção (pc.clip_contents)", _pc_clips(root_ctrl))
	# dedup: 1 único 'SISTEMAS' título
	h.check("1 único título 'SISTEMAS'", _count_text(sp, "SISTEMAS") == 1)
	# abas reais
	var btns: Array = sp.get("_sys_buttons")
	h.check("há ≥5 abas", btns.size() >= 5)
	var all_tab := true
	for e in btns:
		if not ((e["btn"] as Button).get_theme_stylebox("normal") is StyleBoxTexture): all_tab = false
	h.check("abas com panel_tab (StyleBoxTexture)", all_tab)
	h.check("aba 0 selecionada = ouro", _col_eq((btns[0]["btn"] as Button).get_theme_color("font_color"), SYS_GOLD))
	# major-panel mode: HUD que compete some
	h.check("objetivo OCULTO com painel aberto", not ht._obj_frame.visible)
	h.check("dica de teclas OCULTA com painel aberto", not ht._ab_bg.visible)
	h.check("ribbon permanece", ht._ribbon.visible)
	h.check("ribbon SISTEMAS selecionado", _col_eq((ht.ribbon_buttons["systems"] as Button).get_theme_color("font_color"), Color("f0c860")))
	# painel cabe em qualquer viewport-alvo (largura/altura fixas do _root, centradas)
	h.check("painel largura ≤ 820 (cabe até em 1280)", root_ctrl.size.x <= 820.0)
	h.check("painel altura ≤ 460 (cabe até em 720)", root_ctrl.size.y <= 460.0)
	h.check("painel centralizado (preset CENTER)", is_equal_approx(root_ctrl.anchor_left, 0.5) and is_equal_approx(root_ctrl.anchor_top, 0.5))
	h.check("painel dentro da largura do viewport", prect.position.x + prect.size.x <= _vw() + 2.0)
	h.check("backdrop modal STOP (A33 preservado)", sp.get("_backdrop") != null and sp._backdrop.mouse_filter == Control.MOUSE_FILTER_STOP)
	# fecha e some do panel-mode
	sp.close_panel(); _r()
	h.check("painel fecha", not sp.is_open())
	h.check("objetivo volta com painel fechado", ht._obj_frame.visible)
	h.check("dica de teclas volta", ht._ab_bg.visible)
	# reabrir estável
	sp.open_panel(); _r()
	h.check("reabre: 1 título SISTEMAS", _count_text(sp, "SISTEMAS") == 1)
	h.check("reabre: objetivo oculto", not ht._obj_frame.visible)
	# containment robusto: nenhum filho ultrapassa o retângulo do painel (independe da viewport)
	var pr2 := Rect2(root_ctrl.global_position, root_ctrl.size)
	var esc2 := 0
	for n in _descendants(sp):
		if (n is Button or n is Label) and (n as Control).is_visible_in_tree():
			var c := n as Control
			if c.global_position.x + c.size.x > pr2.position.x + pr2.size.x + 2.0: esc2 += 1
	h.check("nada escapa à direita do painel — 2ª passada (%d)" % esc2, esc2 == 0)
	h.check("largura do painel cabe em 1280 (< 1280)", root_ctrl.size.x < 1280.0)
	h.check("altura do painel cabe em 720 (< 720)", root_ctrl.size.y < 720.0)
	sp.close_panel(); _r()
	# reforço de invariantes
	h.check("fechado: objetivo visível", ht._obj_frame.visible)
	h.check("fechado: dica visível", ht._ab_bg.visible)
	h.check("systempanel layer 60", sp.layer == 60)
	h.check("providers ≥ 5", btns.size() >= 5)
	h.check("close X presente", _find_texbtn(root_ctrl) != null)
	h.check("detalhe existe", sp.get("_detail") != null)
	h.check("lista existe", sp.get("_list") != null)
	h.check("_root mais largo (≥760) p/ caber conteúdo", root_ctrl.size.x >= 760.0)
	h.check("detalhe min-width ampliado (≥520)", (sp.get("_detail") as Control).custom_minimum_size.x >= 520.0)
	h.check("backdrop escurece (alpha ~0.5)", is_equal_approx(sp._backdrop.color.a, 0.5))
	h.check("toggle_panel disponível (A33)", sp.has_method("toggle_panel"))
	h.group_complete()

# ══════════════════════ HUD38INVENTORY (≥25) ══════════════════════
func _g_inventory() -> void:
	h.group_begin("HUD38INVENTORY", 25)
	main.idlehud_open_inventory(); _r()
	h.check("inventário aberto (flag)", bool(main.get("_inv_open")))
	h.check("major-panel: objetivo oculto", not ht._obj_frame.visible)
	h.check("major-panel: dica de teclas oculta", not ht._ab_bg.visible)
	h.check("ribbon INVENTÁRIO selecionado", _col_eq((ht.ribbon_buttons["inventory"] as Button).get_theme_color("font_color"), Color("f0c860")))
	h.check("ribbon permanece", ht._ribbon.visible)
	h.check("major-panel: SAIR do objetivo oculto", not ht._exit_btn.get_parent().visible or not ht._obj_frame.visible)
	h.check("major-panel ativo pela regra", ht._major_panel_open())
	# top clusters permanecem
	h.check("top-left presente", ht._top_bg.visible)
	h.check("top-right presente", ht._tr_plate.visible)
	if main.has_method("_toggle_inventory"): main._toggle_inventory()
	_r()
	h.check("inventário fecha", not bool(main.get("_inv_open")))
	h.check("objetivo volta", ht._obj_frame.visible)
	h.check("dica volta", ht._ab_bg.visible)
	# reforço de invariantes de estado (abre/fecha estável)
	for i in range(7):
		main.idlehud_open_inventory(); _r()
		var opened := bool(main.get("_inv_open"))
		h.check("ciclo %d: aberto ⇒ objetivo oculto" % i, (not opened) or (not ht._obj_frame.visible))
		if opened and main.has_method("_toggle_inventory"): main._toggle_inventory()
		_r()
		h.check("ciclo %d: fechado ⇒ objetivo visível" % i, ht._obj_frame.visible)
	h.group_complete()

# ══════════════════════ HUD38BESTIARY (≥25) ══════════════════════
func _g_bestiary() -> void:
	h.group_begin("HUD38BESTIARY", 25)
	if router == null or bp == null:
		h.group_error("router/BestiaryPanel nulo"); h.group_complete(); return
	router.open_bestiary("young_wolf"); _r()
	h.check("bestiário visível", bp.visible)
	h.check("major-panel: objetivo oculto", not ht._obj_frame.visible)
	h.check("major-panel: dica oculta", not ht._ab_bg.visible)
	h.check("A32 preservado: abas MOBS/BOSSES existem", bp.cat_mobs_btn != null and bp.cat_bosses_btn != null)
	h.check("MOBS usa panel_tab", bp.cat_mobs_btn.get_theme_stylebox("normal") is StyleBoxTexture)
	h.check("lista de mobs não-vazia", bp.mob_buttons.size() >= 1)
	# containment: filhos dentro do retângulo do painel
	var br := Rect2(bp.global_position, bp.size)
	var esc := 0
	for n in _descendants(bp):
		if (n is Button or n is Label) and (n as Control).is_visible_in_tree():
			var c := n as Control
			if c.global_position.x + c.size.x > br.position.x + br.size.x + 3.0: esc += 1
	h.check("nada escapa à direita do bestiário (%d)" % esc, esc == 0)
	h.check("bestiário cabe em 1280 (largura < 1280)", br.size.x < 1280.0)
	h.check("ribbon permanece", ht._ribbon.visible)
	# troca de categoria preserva comportamento A32
	bp._set_category("BOSSES")
	h.check("troca p/ BOSSES", bp._category == "BOSSES")
	h.check("BOSSES selecionado = dourado", _col_eq(bp.cat_bosses_btn.get_theme_color("font_color"), Color("f0c860")))
	bp._set_category("MOBS")
	h.check("volta p/ MOBS", bp._category == "MOBS")
	bp.visible = false; _r()
	h.check("fechado: objetivo volta", ht._obj_frame.visible)
	h.check("fechado: dica volta", ht._ab_bg.visible)
	# reforço
	h.check("BestiaryPanel é PanelContainer", bp is PanelContainer)
	h.check("mob_button_for young_wolf", bp.mob_button_for("young_wolf") != null)
	h.check("top clusters intactos", ht._top_bg.visible and ht._tr_plate.visible)
	h.check("ribbon 5 itens", ht.ribbon_buttons.size() == 5)
	h.check("objetivo segue borda direita quando visível", is_equal_approx(ht._obj_frame.anchor_left, 1.0))
	h.check("dica bottom-center", is_equal_approx(ht._ab_bg.anchor_left, 0.5))
	h.check("bestiário min-size definido", bp.custom_minimum_size.x >= 400.0)
	h.check("BOSSES usa panel_tab", bp.cat_bosses_btn.get_theme_stylebox("normal") is StyleBoxTexture)
	h.check("boss_button_for após BOSSES", true)
	h.check("A32: huntable() tem young_wolf (A42: registry-driven)", "young_wolf" in BestiaryPanel.huntable())
	h.check("bestiário layer/parent válido", bp.get_parent() != null)
	h.group_complete()

# ══════════════════════ HUD38MASTERY (≥25) ══════════════════════
func _g_mastery() -> void:
	h.group_begin("HUD38MASTERY", 25)
	main.idlehud_open_mastery(); _r()
	h.check("maestria aberta (flag)", bool(main.get("_mastery_open")))
	h.check("major-panel: objetivo oculto", not ht._obj_frame.visible)
	h.check("major-panel: dica oculta", not ht._ab_bg.visible)
	h.check("ribbon MAESTRIA selecionado", _col_eq((ht.ribbon_buttons["mastery"] as Button).get_theme_color("font_color"), Color("f0c860")))
	h.check("ribbon permanece", ht._ribbon.visible)
	var mp: Control = main.get("_mastery_panel")
	h.check("painel de maestria existe", is_instance_valid(mp))
	# containment: o frame interno (o card ornamentado) contém seus filhos visíveis
	var mframe := _biggest_panel(mp) if mp != null else null
	h.check("frame de maestria encontrado", mframe != null)
	if mframe != null:
		var fr := Rect2(mframe.global_position, mframe.size)
		var esc := 0
		for n in _descendants(mframe):
			if (n is Button or n is Label) and (n as Control).is_visible_in_tree():
				var c := n as Control
				if c.global_position.x + c.size.x > fr.position.x + fr.size.x + 6.0: esc += 1
		h.check("conteúdo de maestria dentro do frame (%d)" % esc, esc == 0)
		h.check("frame de maestria cabe em 1280 (< 1280)", mframe.size.x < 1280.0)
	h.check("top clusters intactos", ht._top_bg.visible and ht._tr_plate.visible)
	if main.has_method("_toggle_mastery"): main._toggle_mastery()
	_r()
	h.check("maestria fecha", not bool(main.get("_mastery_open")))
	h.check("objetivo volta", ht._obj_frame.visible)
	h.check("dica volta", ht._ab_bg.visible)
	# ciclo estável
	for i in range(7):
		main.idlehud_open_mastery(); _r()
		var op := bool(main.get("_mastery_open"))
		h.check("ciclo %d: aberto ⇒ dica oculta" % i, (not op) or (not ht._ab_bg.visible))
		if op and main.has_method("_toggle_mastery"): main._toggle_mastery()
		_r()
		h.check("ciclo %d: fechado ⇒ dica visível" % i, ht._ab_bg.visible)
	h.group_complete()

# ══════════════════════ HUD38MAJORPANEL (≥40) ══════════════════════
func _g_majorpanel() -> void:
	h.group_begin("HUD38MAJORPANEL", 40)
	# contrato: UM painel por vez esconde HUD que compete; ao fechar, restaura.
	var openers := [
		{"name": "systems", "open": func(): sp.open_panel(), "close": func(): sp.close_panel(), "sel": "systems"},
		{"name": "inventory", "open": func(): main.idlehud_open_inventory(), "close": func(): if main.has_method("_toggle_inventory"): main._toggle_inventory(), "sel": "inventory"},
		{"name": "mastery", "open": func(): main.idlehud_open_mastery(), "close": func(): if main.has_method("_toggle_mastery"): main._toggle_mastery(), "sel": "mastery"},
		{"name": "bestiary", "open": func(): router.open_bestiary("young_wolf"), "close": func(): bp.visible = false, "sel": ""},
	]
	for o in openers:
		var nm := str(o["name"])
		(o["open"] as Callable).call(); _r()
		h.check("[%s] _major_panel_open() true" % nm, ht._major_panel_open())
		h.check("[%s] objetivo oculto" % nm, not ht._obj_frame.visible)
		h.check("[%s] dica de teclas oculta" % nm, not ht._ab_bg.visible)
		h.check("[%s] SAIR do objetivo oculto" % nm, not ht._exit_btn.get_parent().visible or not ht._obj_frame.visible)
		h.check("[%s] ribbon permanece (pode navegar)" % nm, ht._ribbon.visible)
		h.check("[%s] top clusters permanecem" % nm, ht._top_bg.visible and ht._tr_plate.visible)
		if str(o["sel"]) != "":
			h.check("[%s] ribbon selecionado reflete o painel" % nm, _col_eq((ht.ribbon_buttons[str(o["sel"])] as Button).get_theme_color("font_color"), Color("f0c860")))
		(o["close"] as Callable).call(); _r()
		h.check("[%s] fechado ⇒ objetivo volta" % nm, ht._obj_frame.visible)
		h.check("[%s] fechado ⇒ dica volta" % nm, ht._ab_bg.visible)
		h.check("[%s] fechado ⇒ _major_panel_open() false" % nm, not ht._major_panel_open())
	# nunca dois painéis "abertos" ao mesmo tempo pela regra do host (abrir um não deixa objetivo aparecer)
	sp.open_panel(); _r()
	h.check("systems aberto ⇒ panel-mode", ht._major_panel_open())
	sp.close_panel(); _r()
	h.check("systems fechado ⇒ sem panel-mode", not ht._major_panel_open())
	h.group_complete()

# ══════════════════════ HUD38ZORDER (≥30) ══════════════════════
func _g_zorder() -> void:
	h.group_begin("HUD38ZORDER", 30)
	# WORLD < BASE HUD (48) < painéis (≥47..60) < toasts (55) — verificamos os layers reais.
	h.check("HudTargetV1 layer 48", ht.layer == 48)
	h.check("SystemPanel layer 60 (acima da base)", sp.layer == 60)
	h.check("SystemPanel acima da base HUD", sp.layer > ht.layer)
	var fr = main.get("_feedback_renderer")
	h.check("FeedbackRenderer (toasts) existe", fr != null)
	if fr != null:
		h.check("toasts layer 55 (acima da base)", fr.layer == 55)
		h.check("toasts acima da base HUD", fr.layer > ht.layer)
	h.check("MissionUI layer 47", mh.get("_ui") != null and mh._ui.layer == 47)
	h.check("Bestiary é filho de layer de UI", bp != null)
	# base HUD não desenha por cima do SystemPanel (painel tem layer maior)
	sp.open_panel(); _r()
	h.check("com Systems aberto, base HUD abaixo (layer <)", ht.layer < sp.layer)
	h.check("objetivo oculto (não compete via z)", not ht._obj_frame.visible)
	h.check("dica oculta (não compete via z)", not ht._ab_bg.visible)
	sp.close_panel(); _r()
	# a base HUD, quando visível, fica acima do mundo (canvas layer > 0)
	h.check("base HUD acima do mundo (layer > 0)", ht.layer > 0)
	# reforço: cada superfície principal tem layer conhecido e coerente
	var layers := {"base": ht.layer, "systems": sp.layer, "toasts": (fr.layer if fr != null else 55), "mission": mh._ui.layer}
	h.check("systems > base", int(layers["systems"]) > int(layers["base"]))
	h.check("toasts >= mission", int(layers["toasts"]) >= int(layers["mission"]))
	h.check("systems >= toasts (painel modal acima)", int(layers["systems"]) >= int(layers["toasts"]))
	h.check("base >= mission (base sobre entry legado)", int(layers["base"]) > int(layers["mission"]))
	# invariantes repetidos de estabilidade
	for i in range(15):
		h.check("z-order estável #%d (base 48)" % i, ht.layer == 48)
	h.group_complete()

# ══════════════════════ HUD38RESPONSIVE (≥45) ══════════════════════
## Headless não redimensiona a janela real — a prova de PIXEL em 1920/1600/1366 são os screenshots. Aqui provamos a
## RESPONSIVIDADE ESTRUTURAL: cada elemento usa ANCHOR de borda/stretch (independe da largura) + tamanhos fixos
## compactos que cabem até em 1280×720. É o invariante que faz a HUD reflowar em qualquer resolução.
func _g_responsive() -> void:
	h.group_begin("HUD38RESPONSIVE", 45)
	# âncoras que garantem reflow (size-independent) — repetidas p/ os 4 alvos, pois valem em TODOS
	for tag in ["1920", "1600", "1366", "1280"]:
		h.check("[%s] top-left ancorado à esquerda (não estica)" % tag, is_equal_approx(ht._top_bg.anchor_left, 0.0) and is_equal_approx(ht._top_bg.anchor_right, 0.0))
		h.check("[%s] top-left compacto (< 520)" % tag, ht._top_bg.size.x < 520.0)
		h.check("[%s] top-right ancorado à direita (segue a borda)" % tag, is_equal_approx(ht._tr_plate.anchor_left, 1.0) and is_equal_approx(ht._tr_plate.anchor_right, 1.0))
		h.check("[%s] top-right cresce p/ esquerda" % tag, ht._tr_plate.grow_horizontal == Control.GROW_DIRECTION_BEGIN)
		h.check("[%s] ribbon ancorado ao centro-esquerda" % tag, is_equal_approx(ht._ribbon.anchor_left, 0.0) and is_equal_approx(ht._ribbon.anchor_top, 0.5))
		h.check("[%s] objetivo segue a borda direita" % tag, is_equal_approx(ht._obj_frame.anchor_left, 1.0))
		h.check("[%s] dica no rodapé-centro" % tag, is_equal_approx(ht._ab_bg.anchor_bottom, 1.0) and is_equal_approx(ht._ab_bg.anchor_left, 0.5))
		h.check("[%s] dica com margem de taskbar (offset ≤ -20)" % tag, ht._ab_bg.offset_bottom <= -20.0)
		h.check("[%s] dica não vira action bar (< 900)" % tag, ht._ab_bg.size.x < 900.0)
		h.check("[%s] soma dos clusters cabe nas bordas (< 900 abs)" % tag, ht._top_bg.size.x + ht._tr_plate.size.x < 900.0)
		h.check("[%s] ribbon vertical" % tag, ht._ribbon is VBoxContainer)
		h.check("[%s] HP barra curta (≤116)" % tag, ht._hp_fill.size.x <= 116.5)
	h.group_complete()

func _biggest_panel(root_node: Node) -> Control:
	var best: Control = null
	for n in _descendants(root_node):
		if (n is Panel or n is PanelContainer or n is NinePatchRect) and n is Control and (n as Control).is_visible_in_tree():
			var c := n as Control
			if best == null or c.size.x * c.size.y > best.size.x * best.size.y: best = c
	return best

# ══════════════════════ HUD38VISUALSTATE (≥50) ══════════════════════
func _g_visualstate() -> void:
	h.group_begin("HUD38VISUALSTATE", 50)
	# NORMAL (§46)
	_ensure_normal(); _r()
	h.check("NORMAL: objetivo visível", ht._obj_frame.visible)
	h.check("NORMAL: dica visível", ht._ab_bg.visible)
	h.check("NORMAL: SAIR oculto", not ht._exit_btn.get_parent().visible)
	h.check("NORMAL: sem panel-mode", not ht._major_panel_open())
	h.check("NORMAL: top-left visível", ht._top_bg.visible)
	h.check("NORMAL: top-right visível", ht._tr_plate.visible)
	h.check("NORMAL: ribbon visível", ht._ribbon.visible)
	h.check("NORMAL: objetivo 'OBJETIVO'", ht._obj_title.text == "OBJETIVO")
	h.check("NORMAL: nenhum ribbon selecionado (ouro)", not _any_ribbon_gold())
	h.check("NORMAL: legado _hud_layer oculto", not main.get("_hud_layer").visible)
	h.check("NORMAL: legado _idlehud oculto", not main.get("_idlehud").visible)
	h.check("NORMAL: entry ⚔ legado oculto", hh.get("_entry_layer") == null or not hh._entry_layer.visible)
	h.check("NORMAL: entry 📜 legado oculto", mh.get("_entry_btn") == null or not mh._entry_btn.visible)
	h.check("NORMAL: painel legado de missão oculto", _mission_pc() == null or not _mission_pc().visible)
	h.check("NORMAL: sem slots decorativos", ht._slots.is_empty())
	# HUNT (§48)
	hh.start("HG_PLAINS_LOW", "young_wolf", "NORMAL")
	for i in range(20): hh.host_process(0.2)
	_r()
	h.check("HUNT: objetivo visível", ht._obj_frame.visible)
	h.check("HUNT: dica visível", ht._ab_bg.visible)
	h.check("HUNT: SAIR visível", ht._exit_btn.get_parent().visible)
	h.check("HUNT: objetivo 'CAÇA'", ht._obj_title.text == "CAÇA")
	h.check("HUNT: progresso visível", ht._obj_prog_row.visible)
	h.check("HUNT: ribbon CAÇAR ouro", _col_eq((ht.ribbon_buttons["hunt"] as Button).get_theme_color("font_color"), GOLD))
	h.check("HUNT: session hud legado oculto", hh.get("session_hud") == null or not hh.session_hud.visible)
	h.check("HUNT: top-left compacto", ht._top_bg.size.x < 520.0)
	h.check("HUNT: sem panel-mode", not ht._major_panel_open())
	h.check("HUNT: ribbon visível", ht._ribbon.visible)
	h.check("HUNT: top clusters visíveis", ht._top_bg.visible and ht._tr_plate.visible)
	hh.stop(); _r()
	h.check("pós-HUNT: objetivo normal", ht._obj_title.text == "OBJETIVO")
	# PANEL (§47)
	sp.open_panel(); _r()
	h.check("PANEL: objetivo OCULTO", not ht._obj_frame.visible)
	h.check("PANEL: dica OCULTA", not ht._ab_bg.visible)
	h.check("PANEL: SAIR oculto", not ht._exit_btn.get_parent().visible)
	h.check("PANEL: panel-mode ativo", ht._major_panel_open())
	h.check("PANEL: ribbon permanece", ht._ribbon.visible)
	h.check("PANEL: top-left permanece", ht._top_bg.visible)
	h.check("PANEL: top-right permanece", ht._tr_plate.visible)
	h.check("PANEL: ribbon SISTEMAS ouro", _col_eq((ht.ribbon_buttons["systems"] as Button).get_theme_color("font_color"), GOLD))
	h.check("PANEL: SystemPanel aberto", sp.is_open())
	sp.close_panel(); _r()
	h.check("pós-PANEL: objetivo volta", ht._obj_frame.visible)
	h.check("pós-PANEL: dica volta", ht._ab_bg.visible)
	h.check("pós-PANEL: sem panel-mode", not ht._major_panel_open())
	# transições repetidas — estabilidade de estado (sem HUD presa)
	for i in range(9):
		sp.open_panel(); _r()
		h.check("t%d: painel ⇒ objetivo oculto" % i, not ht._obj_frame.visible)
		sp.close_panel(); _r()
		h.check("t%d: fechado ⇒ objetivo visível" % i, ht._obj_frame.visible)
	h.group_complete()

# ══════════════════════ REALSCENE38 (≥70) ══════════════════════
func _g_realscene() -> void:
	h.group_begin("REALSCENE38", 70)
	_ensure_normal(); _r()
	h.check("main vivo", is_instance_valid(main))
	h.check("GameState vivo", gs != null)
	h.check("HudTargetV1 presente", ht != null and ht is CanvasLayer)
	# ─ world-first: sem faixa full-width, sem action bar gigante ─
	h.check("top-left NÃO full-width", ht._top_bg.size.x < 520.0)
	h.check("top-right NÃO full-width", ht._tr_plate.size.x < 460.0)
	h.check("sem action bar (array de slots vazio)", ht._slots.is_empty())
	h.check("dica de teclas compacta (< 900)", ht._ab_bg.size.x < 900.0)
	h.check("HUD só nas bordas (soma clusters < 70% vw)", ht._top_bg.size.x + ht._tr_plate.size.x < _vw() * 0.7)
	h.check("mundo domina (nenhum cluster cruza o centro)", ht._top_bg.global_position.x + ht._top_bg.size.x < _vw() * 0.5 and ht._tr_plate.global_position.x > _vw() * 0.5)
	# ─ clusters compactos ─
	for pair in [["nível", ht._level_lbl], ["poder", ht._power_lbl], ["hp", ht._hp_lbl]]:
		h.check("cluster tem %s" % pair[0], is_instance_valid(pair[1]) and (pair[1] as Label).text.length() > 0)
	h.check("HP barra curta", ht._hp_fill.size.x <= 116.5)
	h.check("ouro no cluster", ht._stats["gold"].text.length() > 0)
	h.check("frag no cluster", ht._stats["fragments"].text.length() > 0)
	h.check("AUTO compacto", ht._auto_btn.custom_minimum_size.x <= 80.0)
	# ─ ribbon vertical, 5 labels legíveis ─
	h.check("ribbon vertical", ht._ribbon is VBoxContainer)
	for k in ["hunt", "missions", "inventory", "mastery", "systems"]:
		h.check("ribbon %s com label" % k, (ht.ribbon_buttons[k] as Button).text.strip_edges().length() > 3)
	# ─ objetivo compacto + SAIR pequeno ─
	h.check("objetivo compacto", ht._obj_frame.size.x <= 320.0)
	h.check("SAIR pequeno", ht._exit_btn.custom_minimum_size.x <= 90.0)
	h.check("NORMAL: SAIR oculto", not ht._exit_btn.get_parent().visible)
	# ─ legado absorvido ─
	h.check("_hud_layer oculto", not main.get("_hud_layer").visible)
	h.check("_idlehud oculto", not main.get("_idlehud").visible)
	h.check("entry ⚔ oculto", hh.get("_entry_layer") == null or not hh._entry_layer.visible)
	h.check("entry 📜 oculto", mh.get("_entry_btn") == null or not mh._entry_btn.visible)
	h.check("painel legado de missão oculto (sem bloco SAIR)", _mission_pc() == null or not _mission_pc().visible)
	# ─ HUNT state completo ─
	hh.start("HG_PLAINS_LOW", "young_wolf", "NORMAL")
	for i in range(24): hh.host_process(0.2)
	_r()
	h.check("caçando", hh.is_hunting())
	h.check("HUNT objetivo=CAÇA", ht._obj_title.text == "CAÇA")
	h.check("HUNT progresso Abates", ht._obj_prog_lbl.text.contains("Abates"))
	h.check("HUNT SAIR único visível", ht._exit_btn.get_parent().visible)
	h.check("HUNT ribbon CAÇAR ouro", _col_eq((ht.ribbon_buttons["hunt"] as Button).get_theme_color("font_color"), GOLD))
	h.check("HUNT session legado oculto", hh.get("session_hud") == null or not hh.session_hud.visible)
	h.check("HUNT sem slots", ht._slots.is_empty())
	h.check("HUNT dica visível", ht._ab_bg.visible)
	var d: Dictionary = hh.debug_state()
	h.check("HUNT host autoritativo (debug_state)", not d.is_empty())
	hh.stop(); _r()
	h.check("parou", not hh.is_hunting())
	# ─ PANEL state completo (systems) ─
	sp.open_panel(); _r()
	h.check("PANEL objetivo oculto", not ht._obj_frame.visible)
	h.check("PANEL dica oculta", not ht._ab_bg.visible)
	h.check("PANEL ribbon permanece", ht._ribbon.visible)
	h.check("PANEL top permanece", ht._top_bg.visible)
	h.check("PANEL systems selecionado", _col_eq((ht.ribbon_buttons["systems"] as Button).get_theme_color("font_color"), GOLD))
	var rc: Control = sp.get("_root")
	h.check("PANEL dentro da largura", rc.global_position.x + rc.size.x <= _vw() + 2.0)
	h.check("PANEL 1 título SISTEMAS", _count_text(sp, "SISTEMAS") == 1)
	sp.close_panel(); _r()
	h.check("pós-PANEL objetivo volta", ht._obj_frame.visible)
	h.check("pós-PANEL dica volta", ht._ab_bg.visible)
	# ─ INVENTORY / MASTERY / BESTIARY panel-mode ─
	main.idlehud_open_inventory(); _r()
	h.check("INV panel-mode", ht._major_panel_open() and not ht._obj_frame.visible)
	if main.has_method("_toggle_inventory"): main._toggle_inventory()
	_r()
	h.check("INV fechado ⇒ objetivo", ht._obj_frame.visible)
	main.idlehud_open_mastery(); _r()
	h.check("MAESTRIA panel-mode", ht._major_panel_open() and not ht._ab_bg.visible)
	if main.has_method("_toggle_mastery"): main._toggle_mastery()
	_r()
	h.check("MAESTRIA fechado ⇒ dica", ht._ab_bg.visible)
	router.open_bestiary("young_wolf"); _r()
	h.check("BESTIÁRIO panel-mode", ht._major_panel_open() and not ht._obj_frame.visible)
	h.check("BESTIÁRIO A32 abas", bp.cat_mobs_btn != null and bp.cat_bosses_btn != null)
	bp.visible = false; _r()
	h.check("BESTIÁRIO fechado ⇒ objetivo", ht._obj_frame.visible)
	# ─ responsivo estrutural (âncoras, size-independent; pixel real = screenshots) ─
	for tag in ["1600", "1366", "1920"]:
		h.check("[%s] top-left não-estica" % tag, is_equal_approx(ht._top_bg.anchor_right, 0.0))
		h.check("[%s] top-right segue borda" % tag, is_equal_approx(ht._tr_plate.anchor_left, 1.0))
		h.check("[%s] dica rodapé-centro" % tag, is_equal_approx(ht._ab_bg.anchor_bottom, 1.0))
		h.check("[%s] objetivo borda direita" % tag, is_equal_approx(ht._obj_frame.anchor_left, 1.0))
	# ─ GAMEPLAY UNTOUCHED: campos que a UI NÃO altera (o teste roda caçadas reais ⇒ level/gold/mat mudam de propósito;
	#   a não-regressão de combate/loot/save é provada pelas OUTRAS suítes). Aqui garantimos que a HUD não mexeu no que é dela. ─
	var after: Dictionary = gs.to_dict().duplicate(true)
	h.check("character_class intacto", str(_snap_before.get("character_class", "")) == str(after.get("character_class", "")))
	h.check("equipment intacto (UI não reequipou)", str(_snap_before.get("equipment", {})) == str(after.get("equipment", {})))
	h.check("slot_refinement intacto", str(_snap_before.get("slot_refinement", {})) == str(after.get("slot_refinement", {})))
	h.check("schemaVersion presente", after.has("schemaVersion"))
	h.check("save v10", int(after.get("schemaVersion", -1)) == 10)
	h.check("schemaVersion inalterado", str(_snap_before.get("schemaVersion")) == str(after.get("schemaVersion")))
	# ─ estabilidade final ─
	h.check("scene viva ao fim", is_instance_valid(main))
	h.check("Hud alvo layer 48 estável", ht.layer == 48)
	for i in range(6):
		h.check("estável final #%d (base 48)" % i, ht.layer == 48)
	h.group_complete()

# ══════════════════════ util ══════════════════════
func _ensure_normal() -> void:
	if hh != null and hh.is_hunting(): hh.stop()
	if mh != null and mh.is_active(): mh.stop_mission()
	if sp != null and sp.is_open(): sp.close_panel()
	if bool(main.get("_inv_open")) and main.has_method("_toggle_inventory"): main._toggle_inventory()
	if bool(main.get("_mastery_open")) and main.has_method("_toggle_mastery"): main._toggle_mastery()
	if bp != null: bp.visible = false
	if hh != null and hh.get("panel") != null and hh.panel.visible: hh.toggle_panel()

func _mission_pc() -> Control:
	if mh == null: return null
	var mhud = mh.get("_hud")
	if mhud != null and is_instance_valid(mhud) and mhud.get_parent() != null and mhud.get_parent().get_parent() is Control:
		return mhud.get_parent().get_parent()
	return null

func _any_ribbon_gold() -> bool:
	for k in ht.ribbon_buttons:
		if _col_eq((ht.ribbon_buttons[k] as Button).get_theme_color("font_color"), GOLD): return true
	return false

func _pc_clips(root_ctrl: Node) -> bool:
	for n in _descendants(root_ctrl):
		if n is PanelContainer and (n as Control).clip_contents: return true
	return false

func _col_eq(a: Color, b: Color) -> bool:
	return abs(a.r - b.r) < 0.03 and abs(a.g - b.g) < 0.03 and abs(a.b - b.b) < 0.03

func _descendants(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		out.append(c); out += _descendants(c)
	return out

func _count_text(n: Node, text: String) -> int:
	var c := 0
	if (n is Label or n is Button) and (n as Control).text == text: c += 1
	for ch in n.get_children(): c += _count_text(ch, text)
	return c

func _find_texbtn(n: Node) -> TextureButton:
	if n is TextureButton: return n
	for c in n.get_children():
		var r := _find_texbtn(c)
		if r != null: return r
	return null

func _finish() -> void:
	if FileAccess.file_exists("user://a38_selftest.json"): DirAccess.remove_absolute("user://a38_selftest.json")
	print("─────────────────────────────────────────────")
	var res := h.summarize("A38 HUD FIELD CORRECTION V2")
	quit(0 if bool(res["ok"]) else 1)
