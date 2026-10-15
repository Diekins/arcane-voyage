class_name HuntConfirmPanel extends PanelContainer
## A23.4 — confirmação PEQUENA da Targeted Hunt (não outro menu gigante). "Caça ilimitada. Você permanece até sair."
## Difficulty selecionável + objetivo rastreado (se houver). Two-click: CAÇAR → INICIAR. Buttons REAIS.

signal confirmed(ground_id: String, mob_id: String, difficulty: String)
signal cancelled()

var ground_id := ""
var mob_id := ""
var difficulty := "NORMAL"
var start_btn: Button = null
var cancel_btn: Button = null
var normal_btn: Button = null
var veteran_btn: Button = null

func open(p_ground: String, p_mob: String, mob_name: String, difficulties: Array, goal_text := "", presentation := "desktop") -> void:
	ground_id = p_ground; mob_id = p_mob; difficulty = "NORMAL"
	for c in get_children(): remove_child(c); c.free()
	custom_minimum_size = Vector2(320, 0)
	var vb := VBoxContainer.new(); vb.add_theme_constant_override("separation", 8); add_child(vb)
	var t := Label.new(); t.text = "CAÇAR %s" % mob_name; vb.add_child(t)
	var w := Label.new(); w.text = "Caça ilimitada.\nVocê permanece aqui até escolher sair."; vb.add_child(w)
	if goal_text != "":
		var gl := Label.new(); gl.text = goal_text; gl.modulate = Color(0.7, 1.0, 0.7); vb.add_child(gl)
	var tt := UiMetrics.min_touch_target(presentation, "TT_B")
	# seletor de dificuldade (só as disponíveis)
	var dh := HBoxContainer.new(); vb.add_child(dh)
	normal_btn = Button.new(); normal_btn.text = "NORMAL"; normal_btn.toggle_mode = true; normal_btn.button_pressed = true
	normal_btn.custom_minimum_size = Vector2(0, tt); normal_btn.pressed.connect(func(): _set_diff("NORMAL")); dh.add_child(normal_btn)
	if difficulties.has("VETERAN"):
		veteran_btn = Button.new(); veteran_btn.text = "VETERANO"; veteran_btn.toggle_mode = true
		veteran_btn.custom_minimum_size = Vector2(0, tt); veteran_btn.pressed.connect(func(): _set_diff("VETERAN")); dh.add_child(veteran_btn)
	start_btn = Button.new(); start_btn.text = "INICIAR"; start_btn.custom_minimum_size = Vector2(0, UiMetrics.min_touch_target(presentation, "TT_A"))
	start_btn.pressed.connect(func(): confirmed.emit(ground_id, mob_id, difficulty)); vb.add_child(start_btn)
	cancel_btn = Button.new(); cancel_btn.text = "CANCELAR"; cancel_btn.custom_minimum_size = Vector2(0, tt)
	cancel_btn.pressed.connect(func(): cancelled.emit()); vb.add_child(cancel_btn)

func _set_diff(d: String) -> void:
	difficulty = d
	if normal_btn != null: normal_btn.button_pressed = (d == "NORMAL")
	if veteran_btn != null: veteran_btn.button_pressed = (d == "VETERAN")
