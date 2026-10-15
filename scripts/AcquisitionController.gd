class_name AcquisitionController extends Node
## A23 — ORQUESTRADOR da UX de aquisição. Liga AcquisitionPanel + HuntConfirmPanel + GoalCompleteOverlay +
## NotificationSurface + UIBackStack + HuntHost + AcquisitionResolver. Transforma CLIQUE (Button.pressed) em AÇÃO real
## (abrir painel / iniciar Targeted Hunt / completar goal / voltar à origem / enfrentar boss). NÃO concede authority —
## HuntHost/resolver validam. "Um painel grande": AcquisitionPanel XOR HuntConfirmPanel.

signal boss_fight_requested(boss_id: String)          # Main → missionhost.start_boss
signal inventory_requested()
signal salvage_requested()                            # A25 → PlayerUiRouter.open_salvage
signal inspect_requested(item_key: String)            # A25 → PlayerUiRouter.open_item_inspection
signal mission_requested(mission_id: String)
signal bestiary_requested(mob_id: String)
signal return_to_origin(origin_system: String, origin_context_id: String)

var hunt_host = null
var resolver: AcquisitionResolver = null
var _root: Control = null
var backstack: UIBackStack = null
var presentation := "desktop"

var panel: AcquisitionPanel = null
var confirm: HuntConfirmPanel = null
var overlay: GoalCompleteOverlay = null
var notifications: NotificationSurface = null

var _pending_item := ""
var _pending_desired := 0
var _goal_shown := false

func setup(p_hunt_host, p_resolver: AcquisitionResolver, p_root: Control, p_presentation := "desktop") -> void:
	hunt_host = p_hunt_host; resolver = p_resolver; _root = p_root; presentation = p_presentation
	backstack = UIBackStack.new()
	panel = AcquisitionPanel.new(); panel.visible = false; _root.add_child(panel)
	confirm = HuntConfirmPanel.new(); confirm.visible = false; _root.add_child(confirm)
	overlay = GoalCompleteOverlay.new(); overlay.visible = false; _root.add_child(overlay)
	notifications = NotificationSurface.new(); _root.add_child(notifications)
	panel.hunt_requested.connect(_on_hunt_requested)
	panel.boss_requested.connect(_on_boss_requested)
	panel.track_boss_requested.connect(_on_track_boss)
	panel.inventory_requested.connect(func(): inventory_requested.emit())
	panel.salvage_requested.connect(func(): salvage_requested.emit())
	panel.mission_requested.connect(func(mid): mission_requested.emit(mid))
	panel.bestiary_requested.connect(_on_bestiary)
	panel.back_requested.connect(close_panel)
	confirm.confirmed.connect(_on_confirmed)
	confirm.cancelled.connect(_on_confirm_cancel)
	overlay.continue_pressed.connect(func(): pass)   # Hunt continua; overlay só some
	overlay.return_pressed.connect(_on_return)

# ═══ A23.2 — abrir "COMO OBTER" (missing item clickable → aqui) ═══
func open_for_item(item_key: String, desired: int, origin_system := "", origin_ctx := "") -> void:
	_pending_item = item_key; _pending_desired = desired; _goal_shown = false
	if origin_system != "": resolver.set_intent(origin_system, origin_ctx, item_key)
	panel.open(item_key, desired, resolver, presentation)
	panel.visible = true; confirm.visible = false
	backstack.clear(); backstack.push("ACQUISITION")   # ponto de entrada: pilha limpa (sem duplicar entradas)

func close_panel() -> void:
	panel.visible = false
	if backstack.is_open("ACQUISITION"): backstack.close("ACQUISITION")

# A25 — abrir a confirmação de caça SEM objetivo (ex.: a partir do Bestiário) — reusa o mesmo HuntConfirmPanel.
func start_hunt_confirm(ground_id: String, mob_id: String) -> void:
	_pending_item = ""; _pending_desired = 0
	_on_hunt_requested(ground_id, mob_id, "NORMAL")

# ═══ mob → confirmação ═══
func _on_hunt_requested(ground_id: String, mob_id: String, _diff: String) -> void:
	var diffs: Array = ["NORMAL"]
	if MissionDifficulty.is_selectable("VETERAN", ["NORMAL", "VETERAN"]): diffs = ["NORMAL", "VETERAN"]
	var gtxt := ""
	if _pending_desired > 0:
		gtxt = "Objetivo: %s  %d / %d" % [_pending_item, resolver.owned(_pending_item), _pending_desired]
	confirm.open(ground_id, mob_id, mob_id, diffs, gtxt, presentation)
	confirm.visible = true; panel.visible = false     # um painel grande
	backstack.push("HUNT_CONFIRM")

func _on_confirm_cancel() -> void:
	confirm.visible = false
	if backstack.is_open("HUNT_CONFIRM"): backstack.close("HUNT_CONFIRM")
	panel.visible = true

# ═══ INICIAR → goal + intent + Targeted Hunt (teleport) ═══
func _on_confirmed(ground_id: String, mob_id: String, difficulty: String) -> void:
	if _pending_desired > 0:
		resolver.start_goal(_pending_item, _pending_desired, str(resolver.intent().get("origin_system", "")), str(resolver.intent().get("origin_context_id", "")), {"mob_id": mob_id})
	confirm.visible = false; panel.visible = false
	backstack.clear()
	_goal_shown = false
	var r: Dictionary = hunt_host.start(ground_id, mob_id, difficulty)
	return   # r ignorado aqui; o teste checa is_hunting

# ═══ tick: durante a Hunt, detecta goal completo → overlay UMA vez (Hunt continua) ═══
func process_ux() -> void:
	if hunt_host != null and hunt_host.is_hunting() and resolver.has_goal() and not _goal_shown:
		if resolver.goal_check_complete():
			_goal_shown = true
			var gp: Dictionary = resolver.goal_progress()
			var rl := "VOLTAR AO REFINE" if str(resolver.intent().get("origin_system", "")) == "REFINE" else "VOLTAR"
			overlay.show_for(str(gp["item_id"]), int(gp["have"]), int(gp["desired"]), rl, presentation)
			notifications.notify("acq:%s" % str(gp["item_id"]), "ACQUISITION_COMPLETE", "Objetivo concluído: %s" % str(gp["item_id"]), "", presentation)

# ═══ VOLTAR À ORIGEM: sai da Hunt limpo + devolve o contexto ═══
func _on_return() -> void:
	var back: Dictionary = resolver.return_target()
	if hunt_host != null and hunt_host.is_hunting(): hunt_host.stop()
	return_to_origin.emit(str(back.get("origin_system", "MAIN")), str(back.get("origin_context_id", "")))

# ═══ boss ═══
func _on_boss_requested(boss_id: String) -> void:
	boss_fight_requested.emit(boss_id)

func _on_track_boss(boss_id: String) -> void:
	resolver.track_boss(boss_id)
	notifications.notify("track:%s" % boss_id, "SYSTEM", "Rastreando boss.", "", presentation)

func _on_bestiary(mob_id: String) -> void:
	backstack.push("BESTIARY")
	bestiary_requested.emit(mob_id)

## A23.11 — chamado periodicamente: se boss rastreado ficou disponível, notifica com ação ENFRENTAR.
func check_boss_watch() -> bool:
	if resolver.boss_watch_check():
		var bid := str(resolver.gs.tracked_boss.get("boss_id", ""))
		notifications.notify("boss:%s" % bid, "BOSS_AVAILABLE", "%s está disponível!" % bid, "ENFRENTAR", presentation)
		if not notifications.action_pressed.is_connected(_on_notify_action):
			notifications.action_pressed.connect(_on_notify_action)
		return true
	return false

func _on_notify_action(key: String) -> void:
	if key.begins_with("boss:"): boss_fight_requested.emit(key.substr(5))

# ── acessores de teste (invariante "um painel grande") ──
func is_panel_open() -> bool: return panel.visible
func is_confirm_open() -> bool: return confirm.visible
func is_overlay_visible() -> bool: return overlay.visible
func one_large_panel() -> bool: return not (panel.visible and confirm.visible)
