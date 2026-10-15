class_name HudTargetV1 extends CanvasLayer
## A38 — HUD FIELD CORRECTION V2 (world-first). SUBSTITUI a barra preta full-width por CLUSTERS COMPACTOS:
##   top-left = status (medalhão/nível + ⚔ poder + ❤ HP curto) · top-right = recursos (ouro/frag) + AUTO ·
##   left = ribbon VERTICAL com ícone+label · right = objetivo compacto (auto-size) + SAIR pequeno ·
##   bottom-center = dica de teclas compacta (sem action bar gigante, sem orbe/slots vazios).
## MUNDO DOMINA: nenhum fundo atravessa a tela; cada cluster abraça só o próprio conteúdo. Só DISPLAY (zero gameplay).
## MAJOR-PANEL MODE: com um painel aberto, esconde HUD que compete (objetivo/SAIR/teclas). Absorve o HUD legado
## (⚔ CAÇAR/📜 MISSÕES flutuantes + HuntSessionHud) — o ribbon é o ÚNICO ponto de navegação.

var main: Node = null
var gs = null
var hh = null
var mh = null

# top-left status (campo _top_bg mantido p/ contrato de teste = a placa do cluster esquerdo)
var _top_bg: PanelContainer
var _medallion: Control
var _level_lbl: Label
var _power_lbl: Label
var _hp_fill: ColorRect
var _hp_lbl: Label
# top-right recursos + AUTO
var _tr_plate: PanelContainer
var _auto_btn: TextureButton
var _stats: Dictionary = {}       # id -> Label (gold/fragments)
# ribbon
var _ribbon: VBoxContainer
var ribbon_buttons: Dictionary = {}   # key -> Button
var _ribbon_icon_normal: Dictionary = {}
var _ribbon_icon_selected: Dictionary = {}
# objetivo (campo _obj_frame mantido = a placa do objetivo)
var _obj_frame: PanelContainer
var _obj_title: Label
var _obj_line: Label
var _obj_prog_row: Control
var _obj_prog_lbl: Label
var _obj_fill: ColorRect
var _exit_btn: Button
# dica de teclas (campo _ab_bg mantido = a placa compacta de teclas; NÃO é mais action bar)
var _ab_bg: PanelContainer
var _hint_lbl: Label
# array vazio mantido p/ contrato (não há slots reais §14/§15 — orbe/slots removidos)
var _slots: Array = []

const GOLD := Color("f0c860")
const TEXT := Color("d9ddea")
const DIM := Color("9aa0b0")
const HPBAR_W := 116.0

func setup(p_main) -> void:
	main = p_main
	gs = _root_gs()
	hh = main.get("_hunthost"); mh = main.get("_missionhost")
	if hh != null: hh.suppress_session_hud = true   # o HUD de sessão legado não aparece; o ribbon/objetivo absorvem
	layer = 48
	_build()

func _root_gs():
	var loop := Engine.get_main_loop()
	return (loop as SceneTree).root.get_node_or_null("GameState") if loop is SceneTree else null

func _lbl(txt: String, size: int, col: Color) -> Label:
	var l := Label.new(); l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## Placa pequena translúcida que ABRAÇA só o próprio conteúdo (§8 — nunca full-width).
func _plate() -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.05, 0.065, 0.72)
	sb.border_color = Color(0.5, 0.42, 0.25, 0.5); sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 10; sb.content_margin_right = 10
	sb.content_margin_top = 6; sb.content_margin_bottom = 6
	sb.shadow_color = Color(0, 0, 0, 0.35); sb.shadow_size = 4
	pc.add_theme_stylebox_override("panel", sb)
	return pc

func _stat_icon(id: String, px: float = 22.0) -> Control:
	var i := HudArtPack.icon(id, px)
	if i != null: return i
	var c := Control.new(); c.custom_minimum_size = Vector2(px, px); return c

func _build() -> void:
	var rootc := Control.new(); rootc.set_anchors_preset(Control.PRESET_FULL_RECT)
	rootc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rootc)
	_build_top_left(rootc)
	_build_top_right(rootc)
	_build_ribbon(rootc)
	_build_objective(rootc)
	_build_hotkeys(rootc)
	refresh()

# ── TOP-LEFT: status compacto ────────────────────────────────────────────────────────────────
func _build_top_left(rootc: Control) -> void:
	_top_bg = _plate()
	_top_bg.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_top_bg.offset_left = 16; _top_bg.offset_top = 14
	rootc.add_child(_top_bg)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 12)
	_top_bg.add_child(row)
	# medalhão pequeno (40) + nível centralizado (sem caixa gigante §2)
	_medallion = Control.new(); _medallion.custom_minimum_size = Vector2(40, 40); _medallion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var med := HudArtPack.icon("frames/player_medallion.png", 40.0)
	if med != null: _medallion.add_child(med)
	_level_lbl = _lbl("1", 16, GOLD); _level_lbl.position = Vector2(0, 10); _level_lbl.size = Vector2(40, 20)
	_level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_medallion.add_child(_level_lbl)
	row.add_child(_medallion)
	# ⚔ poder
	var pbox := HBoxContainer.new(); pbox.add_theme_constant_override("separation", 4); pbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pbox.add_child(_stat_icon("icons/icon_power.png", 22.0))
	_power_lbl = _lbl("—", 18, GOLD); pbox.add_child(_power_lbl)
	row.add_child(pbox)
	# ❤ HP curto (§4 — barra curta, não faixa)
	var hpbox := HBoxContainer.new(); hpbox.add_theme_constant_override("separation", 4); hpbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hpbox.add_child(_stat_icon("icons/icon_hp.png", 20.0) if HudArtPack.has("icons/icon_hp.png") else _hp_heart())
	var bar := Control.new(); bar.custom_minimum_size = Vector2(HPBAR_W, 18); bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A39 §17/§18 — TRACK de fundo NEUTRO (não vermelho): vazio ≠ cheio. Só o FILL é vermelho e encolhe com o HP.
	var hpbg := ColorRect.new(); hpbg.color = Color(0.14, 0.14, 0.17, 0.92); hpbg.position = Vector2(0, 1); hpbg.size = Vector2(HPBAR_W, 16); hpbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(hpbg)
	_hp_fill = ColorRect.new(); _hp_fill.color = Color(0.82, 0.2, 0.22); _hp_fill.position = Vector2(0, 1); _hp_fill.size = Vector2(HPBAR_W, 16); _hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(_hp_fill)
	_hp_lbl = _lbl("—", 11, Color(1, 1, 1)); _hp_lbl.position = Vector2(0, 1); _hp_lbl.size = Vector2(HPBAR_W, 16)
	_hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _hp_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(_hp_lbl)
	hpbox.add_child(bar)
	row.add_child(hpbox)

func _hp_heart() -> Label:
	return _lbl("❤", 18, Color("e04a4a"))

# ── TOP-RIGHT: recursos + AUTO ───────────────────────────────────────────────────────────────
func _build_top_right(rootc: Control) -> void:
	_tr_plate = _plate()
	_tr_plate.anchor_left = 1.0; _tr_plate.anchor_right = 1.0
	_tr_plate.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_tr_plate.offset_right = -16; _tr_plate.offset_top = 14
	rootc.add_child(_tr_plate)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 12)
	_tr_plate.add_child(row)
	_add_stat(row, "gold", "icons/icon_gold.png", GOLD)
	_add_stat(row, "fragments", "icons/icon_fragments.png", Color("b78cff"))
	# AUTO compacto, controle real (§7)
	_auto_btn = _tex_button("frames/auto_off.png"); _auto_btn.custom_minimum_size = Vector2(70, 30)
	_auto_btn.pressed.connect(func(): if main.has_method("_toggle_autoplay"): main._toggle_autoplay())
	row.add_child(_auto_btn)

func _add_stat(row: HBoxContainer, id: String, icon_id: String, col: Color) -> void:
	var box := HBoxContainer.new(); box.add_theme_constant_override("separation", 4); box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_stat_icon(icon_id, 20.0))
	var v := _lbl("0", 16, col); box.add_child(v)
	row.add_child(box)
	_stats[id] = v

func _tex_button(id: String) -> TextureButton:
	var b := TextureButton.new()
	var t := HudArtPack.tex(id)
	if t != null:
		b.texture_normal = t; b.ignore_texture_size = true; b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	else:
		b.custom_minimum_size = Vector2(64, 30)
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	return b

# ── RIBBON: vertical, ícone + label (§9/§10/§11) ─────────────────────────────────────────────
func _build_ribbon(rootc: Control) -> void:
	_ribbon = VBoxContainer.new(); _ribbon.add_theme_constant_override("separation", 8)
	_ribbon.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_ribbon.position = Vector2(14, -150)   # 5 × ~52 + 4×8 ≈ 300 ⇒ centro em -150
	_ribbon.mouse_filter = Control.MOUSE_FILTER_PASS
	rootc.add_child(_ribbon)
	_ribbon_item("hunt", "CAÇAR", func(): _open_exclusive("hunt", func(): _press_hunt()))
	_ribbon_item("missions", "MISSÕES", func(): _open_exclusive("missions", func(): _press_missions()))
	_ribbon_item("inventory", "INVENTÁRIO", func(): _open_exclusive("inventory", func(): if main.has_method("idlehud_open_inventory"): main.idlehud_open_inventory()))
	_ribbon_item("mastery", "MAESTRIA", func(): _open_exclusive("mastery", func(): if main.has_method("idlehud_open_mastery"): main.idlehud_open_mastery()))
	_ribbon_item("systems", "SISTEMAS", func(): _open_exclusive("systems", func(): if main.has_method("idlehud_open_system"): main.idlehud_open_system()))

## A39 §23/§24 — ONE MAJOR PANEL: fecha os demais painéis antes de abrir o pedido (nunca dois abertos).
func _close_major_panels(except: String) -> void:
	var sp = main.get("_systempanel")
	if except != "systems" and sp != null and sp.has_method("is_open") and sp.is_open(): sp.close_panel()
	if except != "inventory" and bool(main.get("_inv_open")) and main.has_method("_toggle_inventory"): main._toggle_inventory()
	if except != "mastery" and bool(main.get("_mastery_open")) and main.has_method("_toggle_mastery"): main._toggle_mastery()
	if except != "hunt" and hh != null and hh.get("panel") != null and is_instance_valid(hh.panel) and hh.panel.visible:
		if hh.panel.has_method("close_panel"): hh.panel.close_panel()
		else: hh.panel.visible = false
	if except != "bestiary":
		var best = main.find_child("BestiaryPanel", true, false)
		if best != null and best.visible: best.visible = false

func _open_exclusive(key: String, opener: Callable) -> void:
	_close_major_panels(key)
	opener.call()

func _ribbon_style(selected: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.08, 0.1, 0.85) if selected else Color(0.05, 0.045, 0.06, 0.66)
	sb.border_color = GOLD if selected else Color(0.42, 0.36, 0.22, 0.5)
	sb.set_border_width_all(2 if selected else 1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 10; sb.content_margin_right = 12
	sb.content_margin_top = 6; sb.content_margin_bottom = 6
	return sb

func _ribbon_item(key: String, label: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = "  " + label
	b.custom_minimum_size = Vector2(158, 50)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.clip_text = true
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_constant_override("icon_max_width", 30)
	var tn := HudArtPack.tex("navigation/nav_%s_normal.png" % key)
	var ts := HudArtPack.tex("navigation/nav_%s_selected.png" % key)
	if tn != null: b.icon = tn
	b.add_theme_stylebox_override("normal", _ribbon_style(false))
	b.add_theme_stylebox_override("hover", _ribbon_style(true))
	b.add_theme_stylebox_override("pressed", _ribbon_style(true))
	b.pressed.connect(cb)
	_ribbon.add_child(b)
	ribbon_buttons[key] = b
	_ribbon_icon_normal[key] = tn
	_ribbon_icon_selected[key] = ts

## SELECTED reflete a superfície ativa (não decorativo): ícone selected + placa dourada.
func _update_ribbon_selection() -> void:
	var hunt_panel_open: bool = hh != null and hh.get("panel") != null and is_instance_valid(hh.panel) and hh.panel.visible
	var active := {
		"systems": main.get("_systempanel") != null and main._systempanel.is_open(),
		"hunt": (hh != null and hh.is_hunting()) or hunt_panel_open,   # A39 — selecionado também com o seletor ÁREAS DE CAÇA aberto
		"missions": mh != null and mh.is_active(),
		"inventory": bool(main.get("_inv_open")),
		"mastery": bool(main.get("_mastery_open")),
	}
	for key in ribbon_buttons:
		var b: Button = ribbon_buttons[key]
		var sel: bool = bool(active.get(key, false))
		b.add_theme_stylebox_override("normal", _ribbon_style(sel))
		b.add_theme_color_override("font_color", GOLD if sel else TEXT)
		var want = _ribbon_icon_selected.get(key) if sel else _ribbon_icon_normal.get(key)
		if want != null and b.icon != want: b.icon = want

func _press_hunt() -> void:
	if hh != null and hh.has_method("toggle_panel"): hh.toggle_panel()   # abre/fecha o seletor de ÁREAS DE CAÇA (HuntPanel)

func _press_missions() -> void:
	if mh != null and mh.has_method("_on_entry_pressed"): mh._on_entry_pressed()

# ── OBJETIVO: compacto, auto-size, com SAIR pequeno (§18/§19/§20) ────────────────────────────
func _build_objective(rootc: Control) -> void:
	_obj_frame = _plate()
	_obj_frame.anchor_left = 1.0; _obj_frame.anchor_right = 1.0
	_obj_frame.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_obj_frame.offset_right = -16; _obj_frame.offset_top = 62
	_obj_frame.custom_minimum_size = Vector2(220, 0)
	rootc.add_child(_obj_frame)
	var vb := VBoxContainer.new(); vb.add_theme_constant_override("separation", 4); vb.mouse_filter = Control.MOUSE_FILTER_PASS
	_obj_frame.add_child(vb)
	_obj_title = _lbl("OBJETIVO", 12, GOLD); vb.add_child(_obj_title)
	_obj_line = _lbl("—", 14, TEXT); vb.add_child(_obj_line)
	# linha de progresso (só visível quando há fração real ⇒ auto-size)
	_obj_prog_row = VBoxContainer.new(); _obj_prog_row.add_theme_constant_override("separation", 2); _obj_prog_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_obj_prog_lbl = _lbl("", 12, DIM); _obj_prog_row.add_child(_obj_prog_lbl)
	var pb := Control.new(); pb.custom_minimum_size = Vector2(200, 10); pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pbg := ColorRect.new(); pbg.color = Color(0.1, 0.1, 0.13, 0.9); pbg.size = Vector2(200, 8); pbg.position = Vector2(0, 1); pbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pb.add_child(pbg)
	_obj_fill = ColorRect.new(); _obj_fill.color = GOLD; _obj_fill.size = Vector2(0, 8); _obj_fill.position = Vector2(0, 1); _obj_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pb.add_child(_obj_fill)
	_obj_prog_row.add_child(pb)
	vb.add_child(_obj_prog_row)
	# SAIR pequeno (só em atividade §20)
	_exit_btn = Button.new(); _exit_btn.text = "SAIR"; _exit_btn.focus_mode = Control.FOCUS_NONE
	_exit_btn.custom_minimum_size = Vector2(72, 28); _exit_btn.add_theme_font_size_override("font_size", 12)
	var esb := StyleBoxFlat.new(); esb.bg_color = Color(0.16, 0.06, 0.06, 0.9); esb.border_color = Color(0.7, 0.4, 0.35, 0.7)
	esb.set_border_width_all(1); esb.set_corner_radius_all(6); esb.content_margin_left = 8; esb.content_margin_right = 8; esb.content_margin_top = 4; esb.content_margin_bottom = 4
	_exit_btn.add_theme_stylebox_override("normal", esb)
	_exit_btn.pressed.connect(_press_exit)
	var exrow := HBoxContainer.new(); exrow.alignment = BoxContainer.ALIGNMENT_END; exrow.mouse_filter = Control.MOUSE_FILTER_PASS
	exrow.add_child(_exit_btn)
	vb.add_child(exrow)

func _press_exit() -> void:
	if hh != null and hh.is_hunting(): hh.stop()
	elif mh != null and mh.is_active() and mh.has_method("stop_mission"): mh.stop_mission()

# ── DICA DE TECLAS: placa compacta bottom-center (sem action bar/orbe/slots §12–§15) ─────────
func _build_hotkeys(rootc: Control) -> void:
	_ab_bg = _plate()
	# centro-baixo, abraçando o texto e crescendo p/ CIMA a partir de 26px do fundo (margem da taskbar §41).
	_ab_bg.anchor_left = 0.5; _ab_bg.anchor_right = 0.5; _ab_bg.anchor_top = 1.0; _ab_bg.anchor_bottom = 1.0
	_ab_bg.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_ab_bg.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_ab_bg.offset_bottom = -26
	rootc.add_child(_ab_bg)
	_hint_lbl = _lbl("TAB alvo   ·   J atacar   ·   K parar   ·   E interagir   ·   I mochila   ·   ESC menu", 12, DIM)
	_ab_bg.add_child(_hint_lbl)

# ── REFRESH (só display) ─────────────────────────────────────────────────────────────────────
func _fmt(n: int) -> String:
	var s := str(absi(n)); var out := ""; var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out; c += 1
		if c % 3 == 0 and i > 0: out = "." + out
	return ("-" if n < 0 else "") + out

## Absorve o HUD legado que competia. ★ A38: o `_hud_layer` (crest de vitals/HP + rodapé/SAIR) e o `_idlehud` NÃO
## ficavam ocultos — `set_legacy_hud_visible(false)` roda ANTES de `_build_hud` criar `_hud_layer` (guard pula o
## null). A barra preta full-width MASCARAVA isso; sem ela, o crest vazava. Forço aqui todo frame (ninguém re-mostra).
func _absorb_legacy() -> void:
	var hl = main.get("_hud_layer")
	if hl != null and is_instance_valid(hl) and hl.visible: hl.visible = false
	var ih = main.get("_idlehud")
	if ih != null and is_instance_valid(ih) and ih.visible: ih.visible = false
	# ★ A39 §15/§16 — o "ícone de alvo fantasma" (⚔) era o TOGGLE do paperdoll legado (`_eq_layer`, CanvasLayer 18),
	# sempre visível no topo-direito. Equipamento já vive no INVENTÁRIO ⇒ absorvo a camada legada (só apresentação).
	var eq = main.get("_eq_layer")
	if eq != null and is_instance_valid(eq) and eq.visible: eq.visible = false
	if hh != null:
		if hh.get("_entry_layer") != null and is_instance_valid(hh._entry_layer): hh._entry_layer.visible = false
		if hh.get("session_hud") != null and is_instance_valid(hh.session_hud): hh.session_hud.visible = false
	if mh != null:
		if mh.get("_entry_btn") != null and is_instance_valid(mh._entry_btn): mh._entry_btn.visible = false
		# ★ A38: o painel legado de missão (`pc`) ficava SEMPRE visível — uma caixa vazia com um SAIR de 280px no idle
		# (o "bloco SAIR gigante" do field test). O objetivo do HudTargetV1 já mostra progresso+SAIR da missão ⇒
		# escondo o painel legado, exceto quando há resumo/CONTINUAR pendente (para não quebrar o fecho da missão).
		var mhud = mh.get("_hud")
		if mhud != null and is_instance_valid(mhud) and mhud.get_parent() != null and mhud.get_parent().get_parent() is Control:
			var pc: Control = mhud.get_parent().get_parent()
			var cont = mh.get("_continue_btn"); var summ = mh.get("_summary_lbl")
			var keep: bool = (cont != null and is_instance_valid(cont) and cont.visible) or (summ != null and is_instance_valid(summ) and summ.visible)
			pc.visible = keep

## Um major panel aberto ⇒ esconder HUD que compete (§26/§27/§47).
func _major_panel_open() -> bool:
	var sp = main.get("_systempanel")
	if sp != null and sp.has_method("is_open") and sp.is_open(): return true
	if bool(main.get("_inv_open")) or bool(main.get("_mastery_open")) or bool(main.get("_shop_open")): return true
	if hh != null and hh.get("panel") != null and is_instance_valid(hh.panel) and hh.panel.visible: return true
	var best = main.find_child("BestiaryPanel", true, false)
	if best != null and best.visible: return true
	return false

func refresh() -> void:
	_absorb_legacy()
	if gs == null: gs = _root_gs()
	if gs == null: return
	_level_lbl.text = str(gs.hero_level)
	_power_lbl.text = _fmt(PowerBudget.cp())
	var hpf := float(gs.hero_hp) / maxf(float(gs.max_hp_total()), 1.0)
	_hp_fill.size.x = HPBAR_W * clampf(hpf, 0.0, 1.0)
	_hp_lbl.text = "%s/%s" % [_fmt(int(gs.hero_hp)), _fmt(int(gs.max_hp_total()))]
	_stats["gold"].text = _fmt(int(gs.hero_gold))
	_stats["fragments"].text = _fmt(int(gs.material_count("Fragmentos")))
	var hunting: bool = hh != null and hh.is_hunting()
	# AUTO estado (textura on/off)
	var auto_on: bool = main.has_method("autoplay_on") and main.autoplay_on()
	var atex := HudArtPack.tex("frames/auto_on.png" if auto_on else "frames/auto_off.png")
	if atex != null: _auto_btn.texture_normal = atex
	# MAJOR-PANEL MODE: esconde objetivo/SAIR/teclas quando um painel está aberto (top clusters + ribbon permanecem)
	var panel_open := _major_panel_open()
	_obj_frame.visible = not panel_open
	_ab_bg.visible = not panel_open
	if not panel_open:
		_refresh_objective(hunting)
	_update_ribbon_selection()

func _refresh_objective(hunting: bool) -> void:
	var title := "OBJETIVO"; var line := ""; var has_prog := false; var frac := 0.0; var prog := ""
	if mh != null and mh.is_active() and mh.get("engine") != null and mh.engine != null:
		var eng = mh.engine
		title = "MISSÃO"
		line = str(eng._def.get("display_name_key", "Missão"))
		prog = "%d / %d" % [int(eng.progress), int(eng.required)]
		frac = float(eng.progress) / maxf(float(eng.required), 1.0); has_prog = true
	elif hunting:
		title = "CAÇA"; line = "Caça automática"
		var d: Dictionary = hh.debug_state()
		prog = "Abates %s  ·  +%s XP" % [_fmt(int(d.get("kills", 0))), _fmt(int(d.get("xp", 0)))]
		has_prog = true; frac = 0.0
	else:
		line = "Explorar / evoluir"
	_obj_title.text = title
	_obj_line.text = line
	_obj_prog_lbl.text = prog
	_obj_prog_row.visible = has_prog            # auto-size: sem progresso, a placa encolhe (§19)
	_obj_fill.size.x = 200.0 * clampf(frac, 0.0, 1.0)
	_obj_fill.get_parent().visible = frac > 0.0  # barra só quando há fração real
	_exit_btn.get_parent().visible = hunting or (mh != null and mh.is_active())   # SAIR só em atividade (§20/§21)
