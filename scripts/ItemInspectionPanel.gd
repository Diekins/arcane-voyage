class_name ItemInspectionPanel extends PanelContainer
## A25.1 — ficha REAL de inspeção de item (gear id OU nome de material OU ItemInstance). Reusa ItemDB/ItemInspectionModel
## (não duplica dados). Se há fonte conhecida (ItemSourceRegistry), oferece "COMO OBTER" real. Sem botão morto.

signal acquire_requested(item_key: String, desired: int)
signal back_requested()

var item_key := ""
var _resolver: AcquisitionResolver = null
var como_obter_btn: Button = null
var back_btn: Button = null
var _header: Label = null

func open(p_item_key: String, resolver: AcquisitionResolver, inst: Dictionary = {}, presentation := "desktop") -> void:
	item_key = p_item_key; _resolver = resolver
	for c in get_children(): remove_child(c); c.free()
	custom_minimum_size = Vector2(340, 0)
	var vb := VBoxContainer.new(); vb.add_theme_constant_override("separation", 6); add_child(vb)
	var tt := UiMetrics.min_touch_target(presentation, "TT_B")
	if not inst.is_empty():
		# INSTÂNCIA real: stats da instância (não do template) via ItemInspectionModel
		var sheet: Dictionary = ItemInspectionModel.build(inst)
		_header = _lbl(vb, str(sheet["name"]), 18)
		_lbl(vb, "Raridade: %s • Slot: %s • Qualidade: %s" % [str(sheet["rarity"]), str(sheet["slot"]), str(sheet["quality_label"])], 12)
		var stats := ""
		for k in sheet["core_stats"]: stats += "%s +%d  " % [str(k), int(sheet["core_stats"][k])]
		_lbl(vb, stats, 12)
		if bool(inst.get("locked", false)): _lbl(vb, "🔒 Protegido", 12)
	elif ItemDB.exists(item_key):
		var it: Dictionary = ItemDB.get_item(item_key)
		_header = _lbl(vb, str(it.get("name", item_key)), 18)
		_lbl(vb, "Raridade: %s • Tipo: %s" % [str(ItemDB.rarity(item_key)), str(it.get("cat", "—"))], 12)
		if str(it.get("desc", "")) != "": _lbl(vb, str(it["desc"]), 12)
		_lbl(vb, "Você possui: %d" % _owned(), 12)
	else:
		# material (nome PT-BR, fora do ItemDB)
		_header = _lbl(vb, item_key, 18)
		_lbl(vb, "Material", 12)
		_lbl(vb, "Você possui: %d" % _owned(), 12)
	vb.add_child(HSeparator.new())
	# COMO OBTER só quando há fonte conhecida (sem botão morto)
	if ItemSourceRegistry.has_source(item_key):
		como_obter_btn = Button.new(); como_obter_btn.text = "COMO OBTER"; como_obter_btn.custom_minimum_size = Vector2(0, tt)
		como_obter_btn.pressed.connect(func(): acquire_requested.emit(item_key, 0))
		vb.add_child(como_obter_btn)
	else:
		_lbl(vb, "Fonte ainda não conhecida.", 11)
	back_btn = Button.new(); back_btn.text = "VOLTAR"; back_btn.custom_minimum_size = Vector2(0, UiMetrics.min_touch_target(presentation, "TT_D"))
	back_btn.pressed.connect(func(): back_requested.emit())
	vb.add_child(back_btn)

func _owned() -> int:
	return _resolver.owned(item_key) if _resolver != null else 0
func _lbl(parent: Node, txt: String, size: int) -> Label:
	var l := Label.new(); l.text = txt; l.add_theme_font_size_override("font_size", size); parent.add_child(l); return l
func header_text() -> String: return _header.text if _header != null else ""
