class_name AcquisitionPanel extends PanelContainer
## A23.1/A23.3 — painel "COMO OBTER" ÚNICO e reutilizável (nunca um por sistema). Renderiza as fontes do
## AcquisitionResolver como CARDS com Buttons REAIS. Emite sinais de intenção; NÃO executa authority (o controller faz).
## Botão nunca é morto: todo Button visível tem handler conectado. Toque = UiMetrics.

signal hunt_requested(ground_id: String, mob_id: String, difficulty: String)
signal boss_requested(boss_id: String)
signal track_boss_requested(boss_id: String)
signal inventory_requested()
signal salvage_requested()          # A25 — abrir o painel de Salvage Manual (desmontar equipamento)
signal mission_requested(mission_id: String)
signal bestiary_requested(mob_id: String)
signal back_requested()

var item_key := ""
var desired := 0
var _resolver: AcquisitionResolver = null
var _presentation := "desktop"
var _vb: VBoxContainer = null
var _header: Label = null
var _owned: Label = null
# refs para teste (nenhum botão morto): {entry, action_btn, track_btn, bestiary_btn}
var cards: Array = []
var back_btn: Button = null

func open(p_item_key: String, p_desired: int, resolver: AcquisitionResolver, presentation := "desktop") -> void:
	item_key = p_item_key; desired = p_desired; _resolver = resolver; _presentation = presentation
	for c in get_children(): remove_child(c); c.free()
	cards.clear()
	custom_minimum_size = Vector2(360, 0)
	_vb = VBoxContainer.new(); _vb.add_theme_constant_override("separation", 8); add_child(_vb)
	_header = Label.new(); _header.text = _friendly(item_key); _vb.add_child(_header)
	_owned = Label.new(); _vb.add_child(_owned); _refresh_owned()
	var como := Label.new(); como.text = "COMO OBTER"; _vb.add_child(como)
	# fontes ordenadas pelo resolver, com cabeçalhos de grupo só quando há itens no bucket
	var sources := _resolver.resolve(item_key)
	var last_group := ""
	for e in sources:
		var grp := _group_of(e)
		if grp != last_group:
			var gh := Label.new(); gh.text = grp; gh.modulate = Color(0.7, 0.8, 1.0); _vb.add_child(gh); last_group = grp
		_vb.add_child(_build_card(e))
	back_btn = Button.new(); back_btn.text = "VOLTAR"; back_btn.custom_minimum_size = Vector2(0, UiMetrics.min_touch_target(_presentation, "TT_D"))
	back_btn.pressed.connect(func(): back_requested.emit())
	_vb.add_child(back_btn)

func _refresh_owned() -> void:
	var have := _resolver.owned(item_key)
	_owned.text = ("Você possui: %d / %d" % [have, desired]) if desired > 0 else ("Você possui: %d" % have)

func _group_of(e: Dictionary) -> String:
	match int(e.get("sort", 4)):
		0: return "DISPONÍVEL AGORA"
		2: return "AGENDADO"
		3: return "BLOQUEADO"
		_: return "DESCONHECIDO"

func _build_card(e: Dictionary) -> Control:
	var pc := PanelContainer.new()
	var vb := VBoxContainer.new(); pc.add_child(vb)
	var t := str(e["source_type"])
	var name_l := Label.new(); name_l.text = str(e.get("display_name", "?")); vb.add_child(name_l)
	var info := Label.new(); vb.add_child(info)
	var card := {"entry": e, "action_btn": null, "track_btn": null, "bestiary_btn": null}
	var tt := UiMetrics.min_touch_target(_presentation, "TT_B")
	match t:
		ItemSourceRegistry.MOB_DROP:
			var g: Dictionary = HuntingGround.get_ground(str(e.get("nav_ground", "")))
			var diffs: Array = ["NORMAL"]
			if MissionDifficulty.is_selectable("VETERAN", ["NORMAL", "VETERAN"]) and int(_resolver._cp()) >= 0: diffs = ["NORMAL", "VETERAN"]
			info.text = "Caça infinita • Poder rec.: %d • Drop: %s\nDificuldade: %s" % [int(e.get("recommended_power", 0)), str(e.get("chance_label", "")), ", ".join(diffs)]
			var b := Button.new(); b.text = "CAÇAR" if bool(e["available"]) else "BLOQUEADO"
			b.disabled = not bool(e["available"]); b.custom_minimum_size = Vector2(0, tt)
			var gid := str(e.get("nav_ground", "")); var mid := str(e.get("nav_mob", ""))
			b.pressed.connect(func(): hunt_requested.emit(gid, mid, "NORMAL"))
			vb.add_child(b); card["action_btn"] = b
			# bestiário (se conhecido)
			if _resolver.discovery_state(mid) == "KNOWN":
				var bb := Button.new(); bb.text = "VER BESTIÁRIO"; bb.custom_minimum_size = Vector2(0, tt)
				bb.pressed.connect(func(): bestiary_requested.emit(mid))
				vb.add_child(bb); card["bestiary_btn"] = bb
		ItemSourceRegistry.BOSS_DROP:
			info.text = "Boss • Poder rec.: %d\nStatus: %s" % [int(e.get("recommended_power", 0)), str(e.get("reason_text", ""))]
			var bid := str(e.get("nav_boss", ""))
			if bool(e["available"]):
				var b2 := Button.new(); b2.text = "ENFRENTAR"; b2.custom_minimum_size = Vector2(0, tt)
				b2.pressed.connect(func(): boss_requested.emit(bid))
				vb.add_child(b2); card["action_btn"] = b2
			elif str(e.get("state", "")) != "LOCKED":
				var b3 := Button.new(); b3.text = "RASTREAR"; b3.custom_minimum_size = Vector2(0, tt)
				b3.pressed.connect(func(): track_boss_requested.emit(bid))
				vb.add_child(b3); card["track_btn"] = b3
			# LOCKED: sem botão (reason_text já explica) → nenhum botão morto
		ItemSourceRegistry.MISSION_REWARD:
			info.text = "Recompensa de missão • %s" % str(e.get("reason_text", ""))
			var mmid := str(e.get("nav_mission", ""))
			if str(e.get("state", "")) != "LOCKED":
				var b4 := Button.new(); b4.text = "VER MISSÃO"; b4.custom_minimum_size = Vector2(0, tt)
				b4.pressed.connect(func(): mission_requested.emit(mmid))
				vb.add_child(b4); card["action_btn"] = b4
		ItemSourceRegistry.SALVAGE:
			info.text = "Desmontar equipamentos"
			var b5 := Button.new(); b5.text = "ABRIR INVENTÁRIO"; b5.custom_minimum_size = Vector2(0, tt)
			b5.pressed.connect(func(): inventory_requested.emit())
			vb.add_child(b5); card["action_btn"] = b5
			# A25 — ação principal do salvage: abre o painel de Salvage Manual (desmontar)
			var sv := Button.new(); sv.text = "DESMONTAR EQUIPAMENTOS"; sv.custom_minimum_size = Vector2(0, tt)
			sv.pressed.connect(func(): salvage_requested.emit())
			vb.add_child(sv); card["salvage_btn"] = sv
		_:
			info.text = "???"   # UNKNOWN: sem ação
	cards.append(card)
	return pc

func _friendly(k: String) -> String: return k

# ── acessores de teste ──
func card_count() -> int: return cards.size()
func action_button(i: int) -> Button: return cards[i]["action_btn"] if i >= 0 and i < cards.size() else null
func header_text() -> String: return _header.text if _header != null else ""
func owned_text() -> String: return _owned.text if _owned != null else ""
func refresh_owned_public() -> void: _refresh_owned()
## primeiro card cujo entry casa o predicado
func find_card(pred: Callable) -> Dictionary:
	for c in cards:
		if pred.call(c["entry"]): return c
	return {}
