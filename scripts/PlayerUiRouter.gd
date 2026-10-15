class_name PlayerUiRouter extends Node
## A24.1/A25.5 — camada ÚNICA de roteamento de UI. Converte as intenções do AcquisitionController em ABERTURA de
## TELAS REAIS. A25 fecha as 4 superfícies antes ausentes com painéis REAIS por-contexto (ItemInspection/Bestiário
## por-mob/Seletor de Missão/Salvage Manual) — deep-link com SELEÇÃO real, não só `requested_*`. Invariante: um
## painel grande (fecha os demais ao abrir um). Boss/Inventário do Main permanecem reais.

signal routed(route: String, context: String)

var main = null
var controller: AcquisitionController = null
# painéis A25 (criados pelo Main, hospedados no root do router)
var item_inspect: ItemInspectionPanel = null
var bestiary_panel: BestiaryPanel = null
var mission_panel: MissionSelectorPanel = null
var salvage_panel: ManualSalvagePanel = null
var resolver: AcquisitionResolver = null
var loot_mgr = null
var golden: GoldenPath = null
# telemetria/F3
var last_route := ""
var last_context := ""
var requested_mob := ""
var requested_mission := ""

func setup(p_main, p_controller: AcquisitionController, panels: Dictionary = {}) -> void:
	main = p_main; controller = p_controller
	item_inspect = panels.get("item_inspect")
	bestiary_panel = panels.get("bestiary")
	mission_panel = panels.get("mission")
	salvage_panel = panels.get("salvage")
	resolver = panels.get("resolver")
	loot_mgr = panels.get("loot_mgr")
	golden = panels.get("golden")
	controller.inventory_requested.connect(func(): open_inventory(""))
	controller.mission_requested.connect(open_mission)
	controller.bestiary_requested.connect(open_bestiary)
	controller.boss_fight_requested.connect(open_boss)
	controller.return_to_origin.connect(_on_return_to_origin)
	if controller.has_signal("salvage_requested") and not controller.salvage_requested.is_connected(open_salvage):
		controller.salvage_requested.connect(open_salvage)
	if controller.has_signal("inspect_requested") and not controller.inspect_requested.is_connected(_on_inspect):
		controller.inspect_requested.connect(_on_inspect)
	# "COMO OBTER" do Refino real (SystemPanel) → AcquisitionPanel real
	var sp = _systempanel()
	if sp != null and not sp.acquire_requested.is_connected(_on_acquire):
		sp.acquire_requested.connect(_on_acquire)
	# sinais internos dos 4 painéis A25
	if item_inspect != null:
		item_inspect.acquire_requested.connect(func(ik, dz): open_acquisition(ik, dz, "ITEM_INSPECTION", ik))
		item_inspect.back_requested.connect(func(): _hide_all())
	if bestiary_panel != null:
		bestiary_panel.inspect_requested.connect(open_item_inspection.bind({}))
		bestiary_panel.hunt_requested.connect(func(g, m, d): _hide_big(); controller.start_hunt_confirm(g, m))
		bestiary_panel.boss_fight_requested.connect(open_boss)   # A32: LUTAR do Boss Bestiary → fluxo de boss real (start_boss gateia unlock)
		bestiary_panel.back_requested.connect(func(): _hide_all())
	if mission_panel != null:
		mission_panel.start_requested.connect(_on_start_mission)
		mission_panel.back_requested.connect(func(): _hide_all())
	if salvage_panel != null:
		salvage_panel.back_requested.connect(func(): _hide_all())

# ── acesso às telas reais ──
func _systempanel(): return main.get("_systempanel") if main != null else null
func _missionhost(): return main.get("_missionhost") if main != null else null

# ── visibilidade (um painel grande) ──
func _big_panels() -> Array:
	return [item_inspect, bestiary_panel, mission_panel, salvage_panel]
func _hide_big() -> void:
	for p in _big_panels():
		if p != null: p.visible = false
	if controller != null: controller.panel.visible = false; controller.confirm.visible = false
	var sp = _systempanel()
	if sp != null: sp.close_panel()
func _hide_all() -> void: _hide_big()
func _show_only(target) -> void:
	_hide_big()
	if target != null: target.visible = true

# ── A24 rotas reais ──
func open_refine(context_id := "") -> bool:
	var sp = _systempanel()
	if sp == null: return _fail("refine")
	_hide_big()
	var focus := ("refine:%s" % context_id) if context_id != "" else ""
	sp.open_panel("refine", focus)
	return _ok("refine", context_id)

func open_inventory(_context := "") -> bool:
	if main == null or not main.has_method("idlehud_open_inventory"): return _fail("inventory")
	main.idlehud_open_inventory()
	return _ok("inventory", "")

func open_boss(boss_id: String) -> bool:
	var mh = _missionhost()
	if mh == null or not mh.has_method("start_boss"): return _fail("boss")
	_hide_big()
	var r: Dictionary = mh.start_boss(boss_id, false)
	if not bool(r.get("ok", false)): return _fail("boss")
	return _ok("boss", boss_id)

func open_acquisition(item_key: String, desired: int, origin_system := "", origin_ctx := "") -> bool:
	if controller == null: return _fail("acquisition")
	_hide_big()
	controller.open_for_item(item_key, desired, origin_system, origin_ctx)
	return _ok("acquisition", item_key)

# ── A25 superfícies reais ──
func open_item_inspection(item_key: String, inst: Dictionary = {}) -> bool:
	if item_inspect == null: return _fail("item_inspection")
	item_inspect.open(item_key, resolver, inst, "desktop")
	_show_only(item_inspect)
	return _ok("item_inspection", item_key)

func open_bestiary(mob_id: String) -> bool:
	requested_mob = mob_id
	if bestiary_panel == null: return _fail("bestiary")
	bestiary_panel.open(resolver, resolver.gs if resolver != null else null, mob_id, "desktop")
	_show_only(bestiary_panel)
	return _ok("bestiary", mob_id)

## A32 — abre o Boss Bestiary já inspecionando um boss (cross-link "COMO OBTER → Boss X" → inspeção do boss, drops, LUTAR).
func open_boss_bestiary(boss_id: String) -> bool:
	if bestiary_panel == null: return _fail("boss_bestiary")
	bestiary_panel.open_boss(resolver, resolver.gs if resolver != null else null, boss_id, "desktop")
	_show_only(bestiary_panel)
	return _ok("boss_bestiary", boss_id)

func open_mission(mission_id: String) -> bool:
	requested_mission = mission_id
	if mission_panel == null or golden == null: return _fail("mission")
	mission_panel.open(golden, mission_id, "desktop")
	_show_only(mission_panel)
	return _ok("mission", mission_id)

func open_salvage() -> bool:
	if salvage_panel == null or loot_mgr == null: return _fail("salvage")
	salvage_panel.open(loot_mgr, "desktop")
	_show_only(salvage_panel)
	return _ok("salvage", "")

# ── handlers ──
func _on_start_mission(mission_id: String) -> void:
	var mh = _missionhost()
	if mh != null and mh.has_method("start_mission"):
		_hide_big()
		mh.start_mission(mission_id)   # MissionHost REAL (teleport/encounter); NÃO auto — veio de clique INICIAR

func _on_inspect(item_key: String) -> void:
	open_item_inspection(item_key, {})

func _on_return_to_origin(origin_system: String, origin_ctx: String) -> void:
	match origin_system:
		"REFINE": open_refine(origin_ctx)
		"INVENTORY": open_inventory(origin_ctx)
		"BESTIARY": open_bestiary(origin_ctx)
		"MISSION": open_mission(origin_ctx)
		"ITEM_INSPECTION": open_item_inspection(origin_ctx, {})
		_: pass

func _on_acquire(item_key: String, desired: int) -> void:
	open_acquisition(item_key, desired, "REFINE", "")

func _ok(route: String, ctx: String) -> bool:
	last_route = route; last_context = ctx; routed.emit(route, ctx); return true
func _fail(route: String) -> bool:
	last_route = "FAIL:%s" % route; return false

## A25 — as 4 superfícies antes ausentes agora existem como painéis reais. Nada mais pendente nesta camada.
func missing_screens() -> Array:
	return []

func debug_state() -> Dictionary:
	var sp = _systempanel()
	return {"last_route": last_route, "last_context": last_context, "requested_mob": requested_mob,
		"requested_mission": requested_mission, "systempanel_visible": sp != null and sp.visible,
		"item_inspect_visible": item_inspect != null and item_inspect.visible,
		"bestiary_visible": bestiary_panel != null and bestiary_panel.visible,
		"mission_visible": mission_panel != null and mission_panel.visible,
		"salvage_visible": salvage_panel != null and salvage_panel.visible,
		"acquisition_open": controller != null and controller.is_panel_open()}
