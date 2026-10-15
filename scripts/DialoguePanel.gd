extends CanvasLayer
## DialoguePanel — renderiza uma `DialogueScene` (do export `dialogue_scenes.json`):
## retrato + speaker + texto, linha a linha, e as `choices` ao final. A UI é construída em
## CÓDIGO (sem .tscn complexo). Emite `dialogue_closed(choice_id)` ao fechar.

signal dialogue_closed(choice_id: String)

const TONE_COLORS := {
	"gold": Color("e8c267"),
	"blood": Color("c8553d"),
	"void": Color("8a6db0"),
	"emerald": Color("6fcf97"),
	"rift": Color("7aa7d8"),
	"neutral": Color("cfd3da"),
}

var _scene: Dictionary = {}
var _line := 0
var _showing_choices := false

# referências de UI
var _root: Control
var _portrait: TextureRect
var _initials: Label
var _speaker: Label
var _text: Label
var _hint: Label
var _choices_box: VBoxContainer

func _ready() -> void:
	layer = 10
	_build_ui()
	_root.visible = false

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# IGNORE: o avanço por clique é tratado em _input (antes da GUI); os botões de escolha,
	# por serem Controls próprios (STOP), continuam recebendo cliques normalmente.
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# tela escurecida
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	# painel inferior (estilizado: fundo escuro translúcido + borda dourada, p/ legibilidade)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -240.0
	panel.offset_left = 24.0
	panel.offset_right = -24.0
	panel.offset_bottom = -24.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.08, 0.92)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.9, 0.78, 0.4, 0.5)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", sb)
	_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	margin.add_child(hbox)

	# retrato (TextureRect) + fallback de iniciais
	var portrait_holder := Control.new()
	portrait_holder.custom_minimum_size = Vector2(128, 128)
	hbox.add_child(portrait_holder)

	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(128, 128)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait_holder.add_child(_portrait)

	_initials = Label.new()
	_initials.set_anchors_preset(Control.PRESET_FULL_RECT)
	_initials.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_initials.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_initials.add_theme_font_size_override("font_size", 40)
	portrait_holder.add_child(_initials)

	# coluna de texto
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	hbox.add_child(vbox)

	_speaker = Label.new()
	_speaker.add_theme_font_size_override("font_size", 22)
	vbox.add_child(_speaker)

	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("font_size", 18)
	vbox.add_child(_text)

	_choices_box = VBoxContainer.new()
	_choices_box.add_theme_constant_override("separation", 6)
	vbox.add_child(_choices_box)

	_hint = Label.new()
	_hint.text = "[Espaço / clique] continuar"
	_hint.modulate = Color(1, 1, 1, 0.6)
	_hint.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_hint)

func show_scene(scene: Dictionary) -> void:
	if scene.is_empty():
		push_error("[DialoguePanel] cena vazia — nada a mostrar.")
		return
	_scene = scene
	_line = 0
	_showing_choices = false
	_clear_choices()
	_root.visible = true
	_render_line()

func _render_line() -> void:
	var lines: Array = _scene.get("lines", [])
	if _line >= lines.size():
		_show_choices_or_close()
		return
	var ln: Dictionary = lines[_line]
	_speaker.text = str(ln.get("speaker", "???"))
	_speaker.modulate = TONE_COLORS.get(str(ln.get("tone", "neutral")), Color.WHITE)
	_text.text = str(ln.get("text", ""))

	# retrato real (npcId -> res path) ou fallback de iniciais
	var npc_id := str(ln.get("npcId", ""))
	var tex: Texture2D = null
	if npc_id != "":
		var p := DataLoader.npc_portrait_res(npc_id)
		if p != "" and ResourceLoader.exists(p):
			tex = load(p) as Texture2D
	if tex != null:
		_portrait.texture = tex
		_portrait.visible = true
		_initials.visible = false
	else:
		_portrait.texture = null
		_portrait.visible = false
		_initials.visible = true
		_initials.text = str(ln.get("portraitInitials", "?"))

	var lines_total: int = lines.size()
	_hint.text = "[Espaço / clique] continuar  (%d/%d)" % [_line + 1, lines_total]

func _show_choices_or_close() -> void:
	var choices: Variant = _scene.get("choices", null)
	if choices is Array and choices.size() > 0:
		_showing_choices = true
		_hint.text = "Escolha:"
		_text.text = ""
		for c in choices:
			var b := Button.new()
			b.text = str(c.get("label", c.get("id", "...")))
			var cid := str(c.get("id", ""))
			b.pressed.connect(func() -> void: _close(cid))
			_choices_box.add_child(b)
	else:
		_close("")

func _clear_choices() -> void:
	for child in _choices_box.get_children():
		child.queue_free()

func _close(choice_id: String) -> void:
	GameState.mark_dialogue_seen(str(_scene.get("id", "")), choice_id)
	_root.visible = false
	_showing_choices = false
	_clear_choices()
	dialogue_closed.emit(choice_id)

func is_open() -> bool:
	return _root != null and _root.visible

func _input(event: InputEvent) -> void:
	# _input roda ANTES da GUI: durante as falas consumimos Espaço/E/clique para avançar;
	# durante as choices retornamos cedo, deixando os botões receberem o clique.
	if not is_open() or _showing_choices:
		return
	if event is InputEventKey and event.echo:
		return  # ignora auto-repeat ao segurar a tecla
	var advance := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance = true
	elif event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_E):
		advance = true
	if advance:
		_line += 1
		_render_line()
		get_viewport().set_input_as_handled()
