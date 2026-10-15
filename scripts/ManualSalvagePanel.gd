class_name ManualSalvagePanel extends PanelContainer
## A25.4 — SALVAGE MANUAL player-facing. Lista os itens desmontáveis da mochila (LootManager.salvageable_backpack —
## já barra locked/equipado/protegido) e desmonta UM por vez com confirmação. Yield/settlement = LootManager
## (single truth, exact-once). Sem backend novo. O jogador escolhe — nunca automático.

signal salvaged(item_id: String, frag_yield: int)
signal back_requested()

var lm = null
var _vb: VBoxContainer = null
var _confirm: VBoxContainer = null
var _pres := "desktop"
var desmontar_buttons: Array = []   # [{id, btn}]
var confirm_btn: Button = null
var cancel_btn: Button = null
var back_btn: Button = null
var _pending := ""

func open(loot_mgr, presentation := "desktop") -> void:
	lm = loot_mgr; _pres = presentation; _pending = ""
	for c in get_children(): remove_child(c); c.free()
	desmontar_buttons.clear(); confirm_btn = null; cancel_btn = null
	custom_minimum_size = Vector2(380, 0)
	_vb = VBoxContainer.new(); _vb.add_theme_constant_override("separation", 6); add_child(_vb)
	_lbl("DESMONTAR EQUIPAMENTOS", 16)
	_lbl("Selecione um equipamento para desmontar.", 11)
	var tt := UiMetrics.min_touch_target(_pres, "TT_B")
	var list: Array = lm.salvageable_backpack()
	if list.is_empty():
		_lbl("Nenhum equipamento desmontável.", 12)
	for e in list:
		var id := str(e["id"])
		var row := HBoxContainer.new()
		_lbl_to(row, "%s  x%d  → %d Frag" % [ItemDB.display_name(id), int(e["qty"]), int(e["yield"])], 12)
		var b := Button.new(); b.text = "DESMONTAR"; b.custom_minimum_size = Vector2(0, tt)
		b.pressed.connect(func(): _ask(id))
		row.add_child(b); _vb.add_child(row); desmontar_buttons.append({"id": id, "btn": b})
	_confirm = VBoxContainer.new(); _confirm.visible = false; _vb.add_child(_confirm)
	back_btn = Button.new(); back_btn.text = "VOLTAR"; back_btn.custom_minimum_size = Vector2(0, UiMetrics.min_touch_target(_pres, "TT_D"))
	back_btn.pressed.connect(func(): back_requested.emit()); _vb.add_child(back_btn)

func _ask(id: String) -> void:
	_pending = id
	for c in _confirm.get_children(): _confirm.remove_child(c); c.free()
	_confirm.visible = true
	var y := int(lm.salvage_value(id))
	_lbl_to(_confirm, "Desmontar %s?  Você receberá %d Fragmentos." % [ItemDB.display_name(id), y], 12)
	var hb := HBoxContainer.new(); _confirm.add_child(hb)
	var tt := UiMetrics.min_touch_target(_pres, "TT_A")
	confirm_btn = Button.new(); confirm_btn.text = "DESMONTAR"; confirm_btn.custom_minimum_size = Vector2(0, tt)
	confirm_btn.pressed.connect(_do_confirm); hb.add_child(confirm_btn)
	cancel_btn = Button.new(); cancel_btn.text = "CANCELAR"; cancel_btn.custom_minimum_size = Vector2(0, tt)
	cancel_btn.pressed.connect(func(): _confirm.visible = false; _pending = ""); hb.add_child(cancel_btn)

func _do_confirm() -> void:
	if _pending == "": return
	var res: Dictionary = lm.manual_salvage(_pending)   # AUTHORITY: valida + fórmula única + exact-once
	if bool(res.get("ok", false)):
		salvaged.emit(_pending, int(res["yield"]))
	_pending = ""
	open(lm, _pres)   # refresh da lista (item removido)

func _lbl(txt: String, size: int) -> void: _lbl_to(_vb, txt, size)
func _lbl_to(parent: Node, txt: String, size: int) -> void:
	var l := Label.new(); l.text = txt; l.add_theme_font_size_override("font_size", size); parent.add_child(l)
func desmontar_button_for(id: String) -> Button:
	for e in desmontar_buttons:
		if str(e["id"]) == id: return e["btn"]
	return null
func item_count() -> int: return desmontar_buttons.size()
