class_name NotificationSurface extends Control
## A23.12 — camada mínima de notificações (NÃO um centro MMO). Tipos: ACQUISITION_COMPLETE / BOSS_AVAILABLE /
## RARE_DROP / SYSTEM. Fila curta com COALESCING por chave (evita 20 toasts). Toast pode ter 1 ação (Button real).

const MAX_VISIBLE := 3
signal action_pressed(key: String)

var _vb: VBoxContainer = null
var _items: Array = []   # {key, kind, text}

func _ensure() -> void:
	if _vb != null: return
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	_vb = VBoxContainer.new(); _vb.set_anchors_preset(Control.PRESET_TOP_WIDE); add_child(_vb)

## Enfileira. Coalesce por `key`: se já existe uma notificação com a mesma key, atualiza no lugar (sem empilhar).
func notify(key: String, kind: String, text: String, action_label := "", presentation := "desktop") -> void:
	_ensure()
	for it in _items:
		if str(it["key"]) == key:
			it["text"] = text; _rebuild(presentation); return
	_items.append({"key": key, "kind": kind, "text": text, "action_label": action_label})
	while _items.size() > MAX_VISIBLE: _items.pop_front()
	_rebuild(presentation)

func _rebuild(presentation: String) -> void:
	for c in _vb.get_children(): _vb.remove_child(c); c.free()
	for it in _items:
		var pc := PanelContainer.new(); var hb := HBoxContainer.new(); pc.add_child(hb)
		var l := Label.new(); l.text = str(it["text"]); hb.add_child(l)
		if str(it.get("action_label", "")) != "":
			var b := Button.new(); b.text = str(it["action_label"])
			b.custom_minimum_size = Vector2(0, UiMetrics.min_touch_target(presentation, "TT_B"))
			var k := str(it["key"])
			b.pressed.connect(func(): action_pressed.emit(k))
			hb.add_child(b)
		_vb.add_child(pc)

func dismiss(key: String) -> void:
	for i in range(_items.size() - 1, -1, -1):
		if str(_items[i]["key"]) == key: _items.remove_at(i)
	if _vb != null: _rebuild("desktop")

func count() -> int: return _items.size()
func has(key: String) -> bool: return _items.any(func(i): return str(i["key"]) == key)
func button_for(key: String) -> Button:
	if _vb == null: return null
	var idx := 0
	for it in _items:
		if str(it["key"]) == key:
			var pc := _vb.get_child(idx) as PanelContainer
			if pc != null:
				for c in (pc.get_child(0) as HBoxContainer).get_children():
					if c is Button: return c
		idx += 1
	return null
