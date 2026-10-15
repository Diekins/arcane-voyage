class_name StoryPanel extends CanvasLayer
## FATIA A9.1 — PAINEL DE HISTÓRIA (widget real, reusa Panel/Label/Button/ScrollContainer). Mostra DISPONÍVEIS e
## HISTÓRICO a partir do NarrativeDirector.panel_model() — SEM vazar source_ref/ids/flags (§2/§STORYRT-T06). NÃO é
## journal gigante (§3): só lista + abrir/rever. Clicar num beat chama `host.open_story_beat(beat_id)` (o host valida
## de novo, resolve a cena e abre o DialoguePanel existente). Fechar o painel NÃO marca seen (§10/§STORYRT-T05).

var _host = null
var _dir = null
var _root: Control
var _avail_box: VBoxContainer
var _seen_box: VBoxContainer
var _open := false
var _avail_rows := 0
var _seen_rows := 0

func setup(host, director) -> void:
	_host = host
	_dir = director
	layer = 62   # acima do renderer/HUD; abaixo do DialoguePanel só na ordem de USO (fecho o painel ao abrir a cena)
	_build_ui()
	_root.visible = false

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP   # painel modal (não deixa clique/ataque passar §30)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5); dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(560, 460)
	panel.offset_left = -280; panel.offset_right = 280; panel.offset_top = -230; panel.offset_bottom = 230
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.09, 0.95); sb.set_border_width_all(2)
	sb.border_color = Color(0.9, 0.78, 0.4, 0.5); sb.set_corner_radius_all(8); sb.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", sb)
	_root.add_child(panel)
	var vb := VBoxContainer.new(); vb.add_theme_constant_override("separation", 6); panel.add_child(vb)
	var title := Label.new(); title.text = "HISTÓRIA"; title.add_theme_font_size_override("font_size", 22)
	title.modulate = Color(0.98, 0.85, 0.45); vb.add_child(title)
	vb.add_child(_hdr("DISPONÍVEIS"))
	var sc1 := ScrollContainer.new(); sc1.custom_minimum_size = Vector2(536, 150); sc1.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_avail_box = VBoxContainer.new(); _avail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; sc1.add_child(_avail_box); vb.add_child(sc1)
	vb.add_child(_hdr("HISTÓRICO"))
	var sc2 := ScrollContainer.new(); sc2.custom_minimum_size = Vector2(536, 150); sc2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_seen_box = VBoxContainer.new(); _seen_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; sc2.add_child(_seen_box); vb.add_child(sc2)
	var close := Button.new(); close.text = "Fechar [ESC]"; close.pressed.connect(close_panel); vb.add_child(close)

func _hdr(t: String) -> Label:
	var l := Label.new(); l.text = t; l.add_theme_font_size_override("font_size", 14); l.modulate = Color(0.7, 0.72, 0.78)
	return l

## Abre o painel (§31: não abre duplicado; não abre durante viewing).
func open_panel() -> void:
	if _open: return
	if _host != null and _host.has_method("narrative_viewing") and _host.narrative_viewing(): return
	_open = true
	refresh()
	_root.visible = true

func close_panel() -> void:
	_open = false
	if _root != null: _root.visible = false

func is_open() -> bool:
	return _open

## Reconstrói as linhas a partir do modelo (só título/cap/tipo/estado/escolha — sem ids/flags internas).
func refresh() -> void:
	for c in _avail_box.get_children(): c.queue_free()
	for c in _seen_box.get_children(): c.queue_free()
	_avail_rows = 0; _seen_rows = 0
	if _dir == null: return
	for e in _dir.panel_model():
		var bid := str(e["beat_id"])
		var line := "%s · Cap. %d · %s" % [str(e["title"]), int(e["chapter"]), _type_label(str(e["type"]))]
		if str(e["state"]) == "AVAILABLE":
			var b := Button.new(); b.text = line
			b.pressed.connect(func() -> void: _pick(bid))
			_avail_box.add_child(b); _avail_rows += 1
		else:   # SEEN
			var txt := line
			if str(e.get("choice", "")) != "": txt += "  ✔ escolha: %s" % str(e["choice"])
			var b := Button.new(); b.text = ("REVER — " + txt) if bool(e["replay"]) else txt
			b.disabled = not bool(e["replay"])
			if bool(e["replay"]): b.pressed.connect(func() -> void: _pick(bid))
			_seen_box.add_child(b); _seen_rows += 1

func _type_label(t: String) -> String:
	match t:
		"INTRO": return "Início"
		"BOSS": return "Combate"
		"CHARACTER": return "Personagem"
		"CHOICE": return "Escolha"
		"ENDING": return "Final"
		_: return t

func _pick(beat_id: String) -> void:
	if _host != null and _host.has_method("open_story_beat"):
		close_panel()   # fecha o painel p/ a cena (DialoguePanel) aparecer por cima
		_host.open_story_beat(beat_id)

# contadores p/ self-test
func available_count() -> int: return _avail_rows
func seen_count() -> int: return _seen_rows

func _input(event: InputEvent) -> void:
	if _open and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close_panel()
		get_viewport().set_input_as_handled()
