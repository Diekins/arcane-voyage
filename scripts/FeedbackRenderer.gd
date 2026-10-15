class_name FeedbackRenderer extends CanvasLayer
## FATIA A8.1 — RENDERER único do feedback. CONSOME o GameFeedback e cria ELEMENTOS VISUAIS REAIS (Labels/Panels
## reusando UI/cores existentes; NADA de arte nova) com lifetime e cleanup garantidos. NÃO decide regra de negócio
## (prioridade/rarity/quality/CP/chance/pity/boss-state vêm do bus/modelos). Só apresenta. Toasts no CANTO (não
## cobrem o centro); floating damage no MUNDO; banner/warning breves no topo. `tick(delta)` é a entrada testável.

signal audio_event_requested(event_id: String)   # §36 — relê o hook de áudio do bus (assets futuros)

const MAX_VISIBLE_TOASTS := 4      # §5 — poucos simultâneos (a fila lógica do bus continua cap 12)
const TOAST_LIFE := 2.4
const BANNER_LIFE := 1.6
const WARN_LIFE := 0.8
const FLOAT_LIFE := 0.85
const MAX_FLOATS := 24             # §9 — teto de números flutuantes vivos (sem orphan/crescimento infinito)
const TOAST_PERIOD := 0.125        # §4 — puxa toasts ~8Hz (floating damage é imediato, todo frame)

# cores reusadas do projeto (auditoria A8): dourado/verde-ganho/perigo/dano-herói/mágico/cura + raridades no ItemDB.
const COL_TOAST := Color(0.98, 0.85, 0.45)
const COL_GAIN := Color(0.6, 1.0, 0.7)
const COL_DAMAGE := Color(1.0, 0.88, 0.54)
const COL_TAKEN := Color("ff6b6b")
const COL_HEAL := Color("9fe0a0")
const COL_SHIELD := Color("8fbaff")
const COL_DANGER := Color(1.0, 0.5, 0.45)

var _bus
var _world_cb: Callable            # → Node2D pai do floating text no mundo (região corrente), ou null
var _player_cb: Callable           # → Node2D do herói (posição do dano recebido), ou null
var _toast_box: VBoxContainer
var _banner: Label
var _warn: Label
var _active_toasts: Array = []      # [{node, life}]
var _active_floats: Array = []      # [{node, life, vy}]
var _banner_life := 0.0
var _warn_life := 0.0
var _toast_accum := 0.0

func setup(bus, world_cb: Callable = Callable(), player_cb: Callable = Callable()) -> void:
	_bus = bus
	_world_cb = world_cb
	_player_cb = player_cb
	layer = 55   # acima do IdleHud (45), abaixo do SystemPanel (60)
	_build_ui()
	if _bus != null:
		if not _bus.feedback.is_connected(_on_feedback):
			_bus.feedback.connect(_on_feedback)
		if not _bus.banner_ready.is_connected(_on_banner):
			_bus.banner_ready.connect(_on_banner)
		if not _bus.audio_event.is_connected(_on_audio):
			_bus.audio_event.connect(_on_audio)

func _build_ui() -> void:
	# TRANSIENT MESSAGE ZONE (A36 §7) — TOP-CENTER, ABAIXO da top bar (100px). Não invade o top-right/objetivo/
	# atividade nem o centro do combate. Mensagens aparecem→duram→somem (duração inalterada §8).
	_toast_box = VBoxContainer.new()
	_toast_box.name = "ToastBox"
	_toast_box.anchor_left = 0.5; _toast_box.anchor_right = 0.5; _toast_box.anchor_top = 0.0
	_toast_box.offset_left = -300.0; _toast_box.offset_top = 100.0; _toast_box.offset_right = 300.0
	_toast_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_toast_box.add_theme_constant_override("separation", 4)
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast_box)
	# BANNER — topo-centro, breve (intro/capítulo)
	_banner = _mk_center_label(28, -140.0)
	_banner.visible = false
	add_child(_banner)
	# WARN — centro-alto, breve (aviso de boss)
	_warn = _mk_center_label(22, -80.0)
	_warn.modulate = COL_DANGER
	_warn.visible = false
	add_child(_warn)

func _mk_center_label(font_size: int, y_off: float) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.anchor_left = 0.5; l.anchor_right = 0.5; l.anchor_top = 0.5
	l.offset_left = -260.0; l.offset_right = 260.0; l.offset_top = y_off
	l.add_theme_font_size_override("font_size", font_size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

# ═══════════════ LOOP ═══════════════
func _process(delta: float) -> void:
	tick(delta)

## Entrada única (chamada pelo engine e pelos self-tests). Floating damage imediato; toasts ~8Hz; cleanup por lifetime.
func tick(delta: float) -> void:
	if _bus == null:
		return
	# floating damage — imediato (§4/§7): consome o flush do bus (agregado por fonte)
	for e in _bus.flush_damage():
		_spawn_float(e)
	_tick_floats(delta)
	# toasts — ~8Hz (§4/§5): agrega salvage da janela → 1 toast; puxa 1 por período se houver espaço visível
	_toast_accum += delta
	if _toast_accum >= TOAST_PERIOD:
		_toast_accum = 0.0
		_bus.flush_salvage()   # §16: N reciclados num toast só
		_pull_toast()
	_tick_toasts(delta)
	# banner / warn — lifetime breve
	if _banner_life > 0.0:
		_banner_life -= delta
		if _banner_life <= 0.0: _banner.visible = false
	if _warn_life > 0.0:
		_warn_life -= delta
		if _warn_life <= 0.0: _warn.visible = false

# ═══════════════ TOASTS ═══════════════
func _pull_toast() -> void:
	if _active_toasts.size() >= MAX_VISIBLE_TOASTS:
		return
	var t: Dictionary = _bus.next_toast()
	if t.is_empty():
		return
	# A37 §4 — cada toast é um CARD compacto (fundo escuro + borda bronze), não texto solto flutuante.
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.075, 0.06, 0.92); sb.border_color = Color(0.62, 0.5, 0.28, 0.7)
	sb.set_border_width_all(1); sb.set_corner_radius_all(6)
	sb.content_margin_left = 14; sb.content_margin_right = 14; sb.content_margin_top = 6; sb.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", sb)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := Label.new()
	lbl.text = str(t.get("text", ""))
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.modulate = _toast_color(t)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(lbl)
	_toast_box.add_child(card)
	_active_toasts.append({"node": card, "life": TOAST_LIFE})

func _toast_color(t: Dictionary) -> Color:
	var col := str(t.get("color", ""))
	if col != "":
		return Color(col)
	match str(t.get("kind", "")):
		GameFeedback.K_LOOT_EXCEPTIONAL: return Color("ffcf5a")
		GameFeedback.K_PRESTIGE: return Color(0.82, 0.72, 0.98)
		GameFeedback.K_WALL: return COL_DANGER
		GameFeedback.K_CP_GAIN: return COL_GAIN
		GameFeedback.K_BOSS_PHASE: return COL_DANGER
		GameFeedback.K_SALVAGE: return Color(0.7, 0.72, 0.78)
		_: return COL_TOAST

func _tick_toasts(delta: float) -> void:
	var keep: Array = []
	for e in _active_toasts:
		e["life"] = float(e["life"]) - delta
		var n = e["node"]
		if float(e["life"]) <= 0.0:
			if is_instance_valid(n): n.queue_free()
		else:
			if is_instance_valid(n):
				n.modulate.a = clampf(float(e["life"]) / 0.5, 0.0, 1.0)   # fade nos últimos 0.5s
				keep.append(e)
	_active_toasts = keep

# ═══════════════ FLOATING DAMAGE ═══════════════
func _spawn_float(e: Dictionary) -> void:
	if _active_floats.size() >= MAX_FLOATS:
		return
	var parent = _world_cb.call() if _world_cb.is_valid() else null
	if parent == null or not is_instance_valid(parent):
		return
	var kind := str(e.get("kind", GameFeedback.K_DAMAGE_DEALT))
	var amt := int(e.get("amount", 0))
	var lbl := Label.new()
	lbl.text = _float_text(kind, amt, int(e.get("hits", 1)))
	lbl.modulate = _float_color(kind)
	lbl.add_theme_font_size_override("font_size", 18 if kind == GameFeedback.K_DAMAGE_TAKEN else 16)
	var pos: Vector2 = e.get("pos", Vector2.ZERO)
	if kind == GameFeedback.K_DAMAGE_TAKEN and _player_cb.is_valid():
		var p = _player_cb.call()
		if p != null and is_instance_valid(p): pos = p.position
	lbl.position = pos + Vector2(-16.0, -60.0)
	lbl.z_index = 4095
	parent.add_child(lbl)
	_active_floats.append({"node": lbl, "life": FLOAT_LIFE})

## §7 — não depende SÓ de cor: prefixo/símbolo distingue dano-dado / recebido / cura / escudo.
func _float_text(kind: String, amt: int, hits: int) -> String:
	match kind:
		GameFeedback.K_DAMAGE_TAKEN: return "-%d" % amt
		GameFeedback.K_HEAL: return "+%d" % amt
		GameFeedback.K_SHIELD: return "⛊%d" % amt
		_: return ("%d" % amt) + ("×%d" % hits if hits > 1 else "")

func _float_color(kind: String) -> Color:
	match kind:
		GameFeedback.K_DAMAGE_TAKEN: return COL_TAKEN
		GameFeedback.K_HEAL: return COL_HEAL
		GameFeedback.K_SHIELD: return COL_SHIELD
		_: return COL_DAMAGE

func _tick_floats(delta: float) -> void:
	var keep: Array = []
	for e in _active_floats:
		e["life"] = float(e["life"]) - delta
		var n = e["node"]
		if float(e["life"]) <= 0.0:
			if is_instance_valid(n): n.queue_free()
		else:
			if is_instance_valid(n):
				n.position.y -= 42.0 * delta
				n.modulate.a = clampf(float(e["life"]) / FLOAT_LIFE, 0.0, 1.0)
				keep.append(e)
	_active_floats = keep

# ═══════════════ SINAIS DO BUS ═══════════════
func _on_feedback(e: Dictionary) -> void:
	var kind := str(e.get("kind", ""))
	match kind:
		GameFeedback.K_HEAL, GameFeedback.K_SHIELD:
			_spawn_float(e)
		GameFeedback.K_BOSS_WARNING:
			_show_warn(_warn_text(str(e.get("telegraph", ""))))

func _warn_text(shape: String) -> String:
	match shape:
		"LINE": return "LINHA"
		"CONE": return "CONE"
		"CIRCLE", "GROUND": return "ÁREA"
		"VOLLEY": return "RAJADA"
		"PROJECTILE": return "PROJÉTIL"
		"HAZARD": return "PERIGO"
		_: return "PERIGO"

func _show_warn(text: String) -> void:
	if _warn == null: return
	_warn.text = text
	_warn.visible = true
	_warn_life = WARN_LIFE

func _on_banner(e: Dictionary) -> void:
	if _banner == null: return
	_banner.text = str(e.get("text", ""))
	_banner.modulate = COL_TOAST if str(e.get("kind", "")) != GameFeedback.K_BOSS_INTRO else COL_DANGER
	_banner.visible = true
	_banner_life = BANNER_LIFE

func _on_audio(event_id: String) -> void:
	emit_signal("audio_event_requested", event_id)

# ═══════════════ contadores/estado (self-test/telemetria) ═══════════════
func active_toast_count() -> int: return _active_toasts.size()
func active_float_count() -> int: return _active_floats.size()
func banner_visible() -> bool: return _banner != null and _banner.visible
func warn_visible() -> bool: return _warn != null and _warn.visible

## Limpeza forte (troca de região/reset): descarta floats/banner/warn da cena velha (toasts podem persistir).
func clear_world() -> void:
	for e in _active_floats:
		if is_instance_valid(e["node"]): e["node"].queue_free()
	_active_floats.clear()
	if _banner != null: _banner.visible = false
	if _warn != null: _warn.visible = false
	_banner_life = 0.0; _warn_life = 0.0
