class_name GoalCompleteOverlay extends PanelContainer
## A23.6 — overlay "OBJETIVO CONCLUÍDO" (UMA vez). NÃO encerra a Hunt (o farm segue atrás). Toast + barra de ação:
## [CONTINUAR CAÇANDO] / [VOLTAR AO <origem>]. Buttons REAIS.

signal continue_pressed()
signal return_pressed()

var continue_btn: Button = null
var return_btn: Button = null

func show_for(item_key: String, have: int, desired: int, return_label := "VOLTAR", presentation := "desktop") -> void:
	for c in get_children(): remove_child(c); c.free()
	visible = true
	var vb := VBoxContainer.new(); vb.add_theme_constant_override("separation", 8); add_child(vb)
	var t := Label.new(); t.text = "OBJETIVO CONCLUÍDO"; t.modulate = Color(0.7, 1.0, 0.7); vb.add_child(t)
	var q := Label.new(); q.text = "%s  %d / %d ✅" % [item_key, have, desired]; vb.add_child(q)
	var s := Label.new(); s.text = "Você já possui a quantidade necessária."; vb.add_child(s)
	var hb := HBoxContainer.new(); vb.add_child(hb)
	var tt := UiMetrics.min_touch_target(presentation, "TT_A")
	continue_btn = Button.new(); continue_btn.text = "CONTINUAR CAÇANDO"; continue_btn.custom_minimum_size = Vector2(0, tt)
	continue_btn.pressed.connect(func(): visible = false; continue_pressed.emit()); hb.add_child(continue_btn)
	return_btn = Button.new(); return_btn.text = return_label; return_btn.custom_minimum_size = Vector2(0, tt)
	return_btn.pressed.connect(func(): visible = false; return_pressed.emit()); hb.add_child(return_btn)

func hide_overlay() -> void: visible = false
