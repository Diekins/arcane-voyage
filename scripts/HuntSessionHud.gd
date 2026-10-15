class_name HuntSessionHud extends CanvasLayer
## FATIA A17.5 — HUD COMPACTO da sessão de Hunt. Aparece SÓ enquanto caçando (o HuntHost mostra no START e esconde no
## STOP), substituindo a lista inteira de grounds. Mostra nome da ground + "Caçando automaticamente" + kills/EXP/itens/
## elite/apex + botão SAIR. Sem debug técnico (spot/shard/ticks ficam no overlay DEV, escondido). Server-authoritative:
## lê o estado pela HuntHost/HuntService; SAIR chama host.stop.

var host = null
var acq_resolver = null   # A23.5 — resolver p/ render do objetivo rastreado (opcional; nil = sem seção de goal)
var _title: Label = null
var _sub: Label = null
var _hp: Label = null
var _stats: Label = null
var _goal: Label = null
var _warn: Label = null
var _continue_btn: Button = null
var _exit_btn: Button = null    # A33 — SAIR único da caça (nomeado p/ contrato/teste)

func set_acquisition_resolver(r) -> void:
	acq_resolver = r
	if _goal != null: refresh()

## A23.5 — texto compacto do objetivo rastreado (ou "" se não há goal ativo).
func goal_text() -> String:
	if acq_resolver == null or not acq_resolver.has_goal(): return ""
	var gp: Dictionary = acq_resolver.goal_progress()
	return "OBJETIVO\n%s  %d / %d%s" % [str(gp["item_id"]), int(gp["have"]), int(gp["desired"]), ("  ✅" if bool(gp["complete"]) else "")]

func bind_host(h) -> void:
	host = h
	_build()
	refresh()

func _build() -> void:
	if _title != null: return
	layer = 47
	var pc := PanelContainer.new(); pc.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pc.position = Vector2(-300, 16); pc.custom_minimum_size = Vector2(280, 0)
	add_child(pc)
	var vb := VBoxContainer.new(); pc.add_child(vb)
	_title = Label.new(); _title.text = "CAÇA"; vb.add_child(_title)
	_sub = Label.new(); _sub.text = "Caçando automaticamente"; vb.add_child(_sub)
	_hp = Label.new(); _hp.text = "HP —"; vb.add_child(_hp)
	_stats = Label.new(); _stats.text = "—"; vb.add_child(_stats)
	_goal = Label.new(); _goal.text = ""; _goal.visible = false; _goal.modulate = Color(0.7, 1.0, 0.7); vb.add_child(_goal)
	_warn = Label.new(); _warn.text = ""; _warn.modulate = Color(1, 0.6, 0.4); _warn.visible = false; vb.add_child(_warn)
	_continue_btn = Button.new(); _continue_btn.text = "CONTINUAR"; _continue_btn.custom_minimum_size = Vector2(0, 40)
	_continue_btn.visible = false; _continue_btn.pressed.connect(func(): if host != null: host.continue_hunt())
	vb.add_child(_continue_btn)
	_exit_btn = Button.new(); _exit_btn.text = "SAIR"; _exit_btn.custom_minimum_size = Vector2(0, 40)   # A33 — o ÚNICO SAIR da caça (exposto p/ teste/contrato "one exit")
	_exit_btn.pressed.connect(func(): if host != null: host.stop())
	vb.add_child(_exit_btn)

## Atualiza o HUD a partir do estado autoritativo (chamado pelo host a cada tick enquanto visível).
func refresh() -> void:
	if _stats == null or host == null: return
	var d: Dictionary = host.debug_state()
	if str(d.get("mode", "")) != "HUNTING":
		_stats.text = "—"; return
	# nome amigável da ground (o display_name_key é CANON_REVIEW_REQUIRED → usa o id legível por ora)
	_title.text = _friendly_ground(str(d.get("ground_id", "")))
	if d.has("hp"):
		var sh := int(d.get("shield", 0))
		_hp.text = "HP %d/%d%s" % [int(d["hp"]), int(d.get("max_hp", 1)), ("  🛡%d" % sh) if sh > 0 else ""]
		if bool(d.get("dead", false)): _sub.text = "Caído — revivendo…"
		else: _sub.text = "Caçando automaticamente"
	_stats.text = "Kills: %d\nEXP: +%d\nItens: %d\n\nElite: %d   Apex: %d" % [
		int(d.get("kills", 0)), int(d.get("xp", 0)), int(d.get("items", 0)), int(d.get("elite", 0)), int(d.get("apex", 0))]
	# A23.5 — seção compacta do objetivo rastreado (sem transformar o HUD em painel gigante)
	if _goal != null:
		var gt := goal_text()
		_goal.visible = gt != ""; _goal.text = gt
	# aviso de área perigosa (§21) + botão CONTINUAR
	var paused := bool(d.get("paused", false))
	if _warn != null: _warn.visible = paused; _warn.text = str(d.get("pause_reason", "")) if paused else ""
	if _continue_btn != null: _continue_btn.visible = paused

func _friendly_ground(gid: String) -> String:
	match gid:
		"HG_PLAINS_LOW": return "PLANÍCIE (Iniciante)"
		"HG_PLAINS_HIGH": return "PLANÍCIE (Avançada)"
		"HG_CAVE": return "CAVERNA"
		_: return gid
