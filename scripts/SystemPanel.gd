class_name SystemPanel extends CanvasLayer
## SystemPanel — MOLDE GENÉRICO de UI dos sistemas de poder (FATIA A7, §3/§64). Renderiza QUALQUER provider que
## siga o contrato (SystemProviders.Base) sem conhecer sua regra interna (§SYS-T04: não calcula CP, só exibe o
## `projected_cp` que o provider informa). Adicionar um sistema = registrar um provider (§SYS-T05) — zero cópia
## de painel. Um único painel serve os 6 sistemas (Equipamento/Refino/Joias/Maestria/Bestiário/Códice).

const COL_GOLD := Color(0.98, 0.85, 0.45)
const COL_TEXT := Color(0.90, 0.92, 0.97)
const COL_DIM := Color(0.62, 0.66, 0.74)
const COL_GAIN := Color(0.6, 1.0, 0.7)
const COL_PANEL := Color(0.05, 0.05, 0.08, 0.96)
const COL_BADGE := Color(1.0, 0.5, 0.45)

## A24 — quando um row não pode agir por falta de material, o painel oferece "COMO OBTER" e emite este sinal; o
## PlayerUiRouter abre o AcquisitionPanel real com esse item. (Wiring do Refine real ↔ Acquisition.)
signal acquire_requested(item_key: String, desired: int)

var _host = null
var _providers: Array = []          # [SystemProviders.Base]
var _current: int = -1
var _backdrop: ColorRect            # A33 — dim modal que bloqueia o clique atrás e fecha ao clicar fora
var _root: Control
var _list: VBoxContainer
var _detail: VBoxContainer
var _sys_buttons: Array = []        # [{btn, badge, idx}]
var _focus_action := ""             # A24 — row a destacar ao reabrir (return-to-context, ex.: "refine:weapon")
var acquire_buttons: Array = []     # A24 — refs de teste dos botões "COMO OBTER" [{item_key, desired, btn}]
var action_buttons: Array = []      # A24 — refs de teste dos botões de ação [{action_id, btn}]

func setup(host, providers: Array) -> void:
	_host = host
	_providers = providers
	layer = 60
	_build()
	visible = false

## A37 §2/§3 — aplica a ABA real (panel_tab) a um Button. `selected` reflete a aba ATIVA (não decorativo).
func _apply_tab_style(b: Button, selected: bool) -> void:
	var base := HudArtPack.panel_stylebox("panels/panel_tab_selected.png" if selected else "panels/panel_tab_normal.png")
	if base == null: return
	b.add_theme_stylebox_override("normal", base)
	var hov := HudArtPack.panel_stylebox("panels/panel_tab_selected.png")
	if hov != null: b.add_theme_stylebox_override("hover", hov)
	var sel := HudArtPack.panel_stylebox("panels/panel_tab_selected.png")
	if sel != null: b.add_theme_stylebox_override("pressed", sel)
	b.add_theme_color_override("font_color", COL_GOLD if selected else COL_TEXT)

## A36 — botão de fechar (X) no canto, com a arte close_button do pack. Reusa close_panel (ESC/click-away seguem).
func _skin_close_button() -> TextureButton:
	var tn := HudArtPack.tex("panels/close_button_normal.png")
	if tn == null: return null
	var b := TextureButton.new()
	b.texture_normal = tn
	var th := HudArtPack.tex("panels/close_button_hover.png"); if th != null: b.texture_hover = th
	var tp := HudArtPack.tex("panels/close_button_pressed.png"); if tp != null: b.texture_pressed = tp
	b.ignore_texture_size = true; b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.custom_minimum_size = Vector2(34, 34)
	b.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	b.offset_left = -44; b.offset_top = 8; b.offset_right = -10; b.offset_bottom = 42
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(close_panel)
	return b

func _gs():
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("GameState")
	return null

func _mk_label(txt: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _build() -> void:
	# A33 — BACKDROP MODAL: escurece a tela e CAPTURA o clique (MOUSE_FILTER_STOP) para o input não atravessar
	# para o mundo/atividade atrás (field bug #2/#7). Clicar fora do painel FECHA (click-away). Fica atrás do _root.
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.0, 0.0, 0.0, 0.5)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: close_panel())
	add_child(_backdrop)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_CENTER)
	# A38 §31/§33 — painel mais largo p/ o conteúdo do detalhe caber (o botão de ação escapava à direita).
	_root.offset_left = -390; _root.offset_top = -215; _root.offset_right = 390; _root.offset_bottom = 215
	add_child(_root)
	# A36 §3 — reskin com a FAMÍLIA DE PAINÉIS (panel_frame + header + close), sem tocar providers/lógica/A33.
	var frame := HudArtPack.nine("panels/panel_frame.png")
	var skinned := frame != null
	if skinned:
		frame.set_anchors_preset(Control.PRESET_FULL_RECT); _root.add_child(frame)
	var pc := PanelContainer.new(); pc.set_anchors_preset(Control.PRESET_FULL_RECT)
	pc.clip_contents = true   # A38 §33 — garante que NADA escape do retângulo do painel
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0) if skinned else COL_PANEL   # com a arte, o fundo do container fica transparente
	sb.set_corner_radius_all(8)
	if not skinned: sb.set_border_width_all(2); sb.border_color = COL_GOLD
	# A39 — PanelContainer insere pelo CONTENT_MARGIN do STYLEBOX (theme const "margin_*" é do MarginContainer e era
	# no-op aqui). O topo 54 libera a altura do header p/ o conteúdo (ex.: Códice) não ficar sob o título.
	sb.content_margin_left = 22 if skinned else 4
	sb.content_margin_top = 54 if skinned else 4
	sb.content_margin_right = 22 if skinned else 4
	sb.content_margin_bottom = 22 if skinned else 4
	pc.add_theme_stylebox_override("panel", sb)
	_root.add_child(pc)
	if skinned:
		var header := HudArtPack.nine("panels/panel_header.png")
		if header != null:
			header.set_anchors_preset(Control.PRESET_TOP_WIDE)
			header.offset_left = 10; header.offset_right = -10; header.offset_top = 6; header.offset_bottom = 48
			_root.add_child(header)
		var htitle := _mk_label("SISTEMAS", 18, COL_GOLD); htitle.position = Vector2(28, 14); _root.add_child(htitle)
		var cx := _skin_close_button()
		if cx != null: _root.add_child(cx)
	var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 14); pc.add_child(hb)
	# coluna esquerda: lista de sistemas
	_list = VBoxContainer.new(); _list.add_theme_constant_override("separation", 4)
	_list.custom_minimum_size = Vector2(180, 380)
	hb.add_child(_list)
	if not skinned: _list.add_child(_mk_label("SISTEMAS", 16, COL_GOLD))   # A37 §1 — dedup: com o header já dizendo SISTEMAS, não repete o título interno
	for i in range(_providers.size()):
		var p = _providers[i]
		var row := Control.new(); row.custom_minimum_size = Vector2(180, 40)
		var b := Button.new(); b.text = str(p.sys_name()); b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(180, 40)
		_apply_tab_style(b, false)   # A37 §2 — ABA REAL (panel_tab_normal/selected)
		b.pressed.connect(_select.bind(i))
		row.add_child(b)
		var badge := _mk_label("●", 14, COL_BADGE); badge.position = Vector2(160, 4); badge.visible = false
		row.add_child(badge)
		_list.add_child(row)
		_sys_buttons.append({"btn": b, "badge": badge, "idx": i})
	var close := Button.new(); close.text = "Fechar"; close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(close_panel)
	_list.add_child(close)
	# coluna direita: detalhe do sistema selecionado
	_detail = VBoxContainer.new(); _detail.add_theme_constant_override("separation", 6)
	_detail.custom_minimum_size = Vector2(560, 380)   # A38 — mais largura útil (o painel cresceu); conteúdo cabe sem escapar
	hb.add_child(_detail)

## Abre o painel; opcionalmente já no sistema `system_id` e destacando o row `focus_action_id` (return-to-context A24).
func open_panel(system_id: String = "", focus_action_id: String = "") -> void:
	visible = true
	_focus_action = focus_action_id
	var idx := 0
	if system_id != "":
		for i in range(_providers.size()):
			if str(_providers[i].sys_id()) == system_id:
				idx = i; break
	_select(idx)

## A33 — está aberto? (fonte única do estado; antes o "aberto" era só o `visible` interno, sem acessor).
func is_open() -> bool:
	return visible

## A33 — toggle pelo MESMO botão que abriu (§6/§34): aberto → fecha; fechado → abre no sistema pedido.
func toggle_panel(system_id: String = "", focus_action_id: String = "") -> void:
	if visible:
		close_panel()
	else:
		open_panel(system_id, focus_action_id)

## A33 — ESC fecha o modal (§6/§34). CanvasLayer recebe input global; só consome quando ABERTO.
func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close_panel()
		var vp := get_viewport()
		if vp != null: vp.set_input_as_handled()

## A24 — o sistema atualmente aberto (para o router/testes verificarem o contexto real).
func current_system_id() -> String:
	return str(_providers[_current].sys_id()) if _current >= 0 and _current < _providers.size() else ""
func focus_action() -> String: return _focus_action

func close_panel() -> void:
	visible = false
	if _host != null and _host.has_method("systempanel_closed"): _host.systempanel_closed()

## Índice do provider por id ("" → -1). Usado pelo host/▸IR p/ abrir o sistema recomendado.
func has_system(system_id: String) -> bool:
	for p in _providers:
		if str(p.sys_id()) == system_id:
			return true
	return false

func _select(idx: int) -> void:
	_current = idx
	# A37 §3 — a aba SELECIONADA reflete o sistema ativo (não decorativo)
	for e in _sys_buttons:
		_apply_tab_style(e["btn"], int(e["idx"]) == idx)
	_refresh_detail()
	_refresh_badges()

## Reconstrói o detalhe a partir do provider — GENÉRICO (não conhece o sistema).
func _refresh_detail() -> void:
	for c in _detail.get_children():
		_detail.remove_child(c); c.free()   # A24 — free IMEDIATO (queue_free é deferido em -s e desalinha índices)
	acquire_buttons.clear(); action_buttons.clear()
	if _current < 0 or _current >= _providers.size():
		return
	var p = _providers[_current]
	_detail.add_child(_mk_label(str(p.sys_name()), 20, COL_GOLD))
	_detail.add_child(_mk_label(str(p.sys_desc()), 13, COL_DIM))
	_detail.add_child(_mk_label(str(p.resource_text()), 14, COL_TEXT))
	_detail.add_child(HSeparator.new())
	for r in p.rows():
		var line := HBoxContainer.new(); line.add_theme_constant_override("separation", 8)
		var aid := str(r.get("action_id", ""))
		var mark := "▶ " if (aid != "" and aid == _focus_action) else ""   # A24 — destaca o contexto de retorno
		var lt := _mk_label("%s%s   %s" % [mark, str(r.get("label", "")), str(r.get("detail", ""))], 13, COL_TEXT)
		lt.custom_minimum_size = Vector2(200, 24)
		lt.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # A38 §33 — a label ABSORVE a sobra e recorta; os botões fixos ficam dentro
		lt.clip_text = true
		line.add_child(lt)
		var pcp := int(r.get("projected_cp", 0))
		if pcp != 0:
			line.add_child(_mk_label("+%s Poder" % _fmt(pcp), 13, COL_GAIN))
		var al := str(r.get("action_label", ""))
		if al != "" and al != "—":
			var ab := Button.new(); ab.text = al; ab.focus_mode = Control.FOCUS_NONE
			ab.disabled = not bool(r.get("can_act", false))
			ab.pressed.connect(_do.bind(aid))
			line.add_child(ab); action_buttons.append({"action_id": aid, "btn": ab})
		# A24.3 — MATERIAL FALTANTE CLICÁVEL: quando o row não pode agir por falta de material, oferece "COMO OBTER".
		var hint: Dictionary = r.get("acquire_hint", {})
		if not hint.is_empty() and not bool(r.get("can_act", false)):
			var gb := Button.new(); gb.text = "COMO OBTER"; gb.focus_mode = Control.FOCUS_NONE
			var ik := str(hint.get("item_key", "")); var dz := int(hint.get("desired", 0))
			gb.pressed.connect(func(): acquire_requested.emit(ik, dz))
			line.add_child(gb)
			acquire_buttons.append({"item_key": ik, "desired": dz, "btn": gb})
		_detail.add_child(line)

## A24 — botão "COMO OBTER" do item (para o teste disparar o clique real). null se não há shortage renderizado.
func acquire_button_for(item_key: String) -> Button:
	for e in acquire_buttons:
		if str(e["item_key"]) == item_key: return e["btn"]
	return null

## A24 — botão de ação de um row (ex.: "refine:weapon") para o teste disparar o clique real.
func action_button_for(action_id: String) -> Button:
	for e in action_buttons:
		if str(e["action_id"]) == action_id: return e["btn"]
	return null

func _do(action_id: String) -> void:
	if _current < 0:
		return
	_providers[_current].do_action(action_id)   # o provider aplica a regra; o painel só dispara e re-renderiza
	_refresh_detail()
	_refresh_badges()
	if _host != null and _host.has_method("systempanel_changed"):
		_host.systempanel_changed()

## Badge por sistema = provider.has_available_action() (§6): só quando há AÇÃO REAL, sem ponto vermelho fixo.
func _refresh_badges() -> void:
	for e in _sys_buttons:
		var p = _providers[int(e["idx"])]
		e["badge"].visible = bool(p.has_available_action())

## Algum sistema com ação disponível (p/ o ▸IR/HUD).
func any_badge() -> bool:
	for p in _providers:
		if bool(p.has_available_action()):
			return true
	return false

func _fmt(n: int) -> String:
	var s := str(absi(n)); var out := ""; var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out; c += 1
		if c % 3 == 0 and i > 0: out = "." + out
	return ("-" if n < 0 else "") + out
