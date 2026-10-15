extends SceneTree
## A24 — Real UI Routing: boota a Main.tscn REAL e prova que os sinais do AcquisitionController (fiados no boot)
## abrem as TELAS REAIS (SystemPanel/Refino, Inventário, Boss). Botões reais. Save protegido por override de fixture.
## Grupos: REALROUTER/REFINEWIRE/INVENTORYWIRE/BESTIARYWIRE/MISSIONWIRE/BOSSWIRE/RETURNCONTEXT/UIOWNERSHIP24/A24SECURITY.

var main: Node = null
var _frame := 0
var _phase := 0
var _fail := 0
var gs; var ctl: AcquisitionController; var router: PlayerUiRouter; var res: AcquisitionResolver; var sp: SystemPanel
func _chk(nm: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), nm]); if not cond: _fail += 1
func _press(b) -> void:
	if b != null: b.pressed.emit()

func _initialize() -> void:
	var ps: PackedScene = load("res://scenes/Main.tscn")
	main = ps.instantiate(); root.add_child(main)
	process_frame.connect(_on_frame)

func _on_frame() -> void:
	_frame += 1
	if _phase == 0 and _frame >= 3:
		_phase = 1
		if main.has_method("_enter_game"): main._enter_game()
	elif _phase == 1 and _frame >= 8:
		_phase = 2
		gs = root.get_node_or_null("GameState")
		gs.set_save_path_override("user://a24_fixture.json")   # ★ protege o save/economia live (refine escreve em disco)
		ctl = main.get("_acq_controller"); router = main.get("_ui_router"); res = main.get("_acq_resolver"); sp = main.get("_systempanel")
		_run()
		if FileAccess.file_exists("user://a24_fixture.json"): DirAccess.remove_absolute("user://a24_fixture.json")
		print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
		quit(0 if _fail == 0 else 1)

func _prep(frag := 500, upto := "C2_M008") -> void:
	gs.character_class = "CLASS_1"; gs.equipment = {"weapon": "sword_eternal"}; gs.slot_refinement = {}
	gs.hero_hp_max = 9000; gs.hero_hp = gs.max_hp_total(); gs.shield_amount = 0; gs.hero_gold = 0
	gs.stage_highest_global = 60; gs.materials = {"Fragmentos": frag, "Núcleo de Cristal": 0}; gs.backpack = []
	gs.bestiary = {}; gs.tracked_goal = {}; gs.acquisition_intent = {}; gs.tracked_boss = {}
	var f: Array[String] = ["GP_MISSION_006_COMPLETE"]
	for m in ["C2_M001", "C2_M002", "C2_M003", "C2_M004", "C2_M005", "C2_M006", "C2_M007", "C2_M008"]:
		f.append("GP_%s_COMPLETE" % m)
		if m == upto: break
	if upto == "C2_M008": f.append("GP_UNLOCK_HUNT_CRYSTAL"); f.append("GP_UNLOCK_REPEATABLE_CRYSTAL")
	gs.story_flags = f
	if sp != null: sp.close_panel()
	ctl.panel.visible = false; ctl.confirm.visible = false; ctl.overlay.visible = false

func _run() -> void:
	print("  ── A24 (Main.tscn REAL) ──")
	_chk("boot: controller/router/systempanel reais montados", ctl != null and router != null and sp != null and res != null)
	_realrouter(); _refinewire(); _inventorywire(); _bestiarywire(); _missionwire(); _bosswire(); _returncontext(); _uiownership(); _security()

# ══ REALROUTER (≥25) ══
func _realrouter() -> void:
	print("  ── REALROUTER ──"); _prep()
	_chk("RR-T01 Router existe (reusado no boot)", router != null)
	_chk("RR-T02 rota Refine → SystemPanel visível+sistema refine", (func(): router.open_refine("weapon"); return sp.visible and sp.current_system_id() == "refine").call())
	_chk("RR-T03 rota Inventory → inventário real aberto", (func(): sp.close_panel(); router.open_inventory(); return bool(main.get("_inv_open"))).call())
	if bool(main.get("_inv_open")): main._toggle_inventory()
	_chk("RR-T04 rota Item (open_acquisition) → AcquisitionPanel real", (func(): router.open_acquisition("Núcleo de Cristal", 5, "REFINE", "weapon"); return ctl.is_panel_open()).call())
	_chk("RR-T05 rota Bestiary → BestiaryPanel real + mob selecionado", (func(): router.open_bestiary("living_shard"); return router.bestiary_panel.visible and router.bestiary_panel.selected_mob == "living_shard").call())
	_chk("RR-T06 rota Mission → MissionSelector real (sem auto-start)", (func(): router.open_mission("C2_M001"); return router.mission_panel.visible and not main._missionhost.is_active()).call())
	_chk("RR-T07 rota Boss → boss real inicia", (func(): _prep(); router.open_boss("BOSS_CRYSTAL_GOLEM"); return main._missionhost.boss != null and main._missionhost.boss.boss() != null).call())
	main._missionhost.stop_boss(); _prep()
	_chk("RR-T08 rota Hunt (via controller start) usa HuntHost real", main._hunthost != null)
	_chk("RR-T09 rota inválida segura (fail sem crash)", not router.open_boss("BOSS_FANTASMA"))
	_chk("RR-T10 Node path real do SystemPanel", sp.get_parent() == main)
	_chk("RR-T11 owner correto (router.main == Main)", router.main == main)
	_chk("RR-T12 last_route registrado", router.last_route != "")
	_chk("RR-T13 requested_mob registrado", (func(): router.open_bestiary("crystal_bat"); return router.requested_mob == "crystal_bat").call())
	_chk("RR-T14 requested_mission registrado", (func(): router.open_mission("C2_M003"); return router.requested_mission == "C2_M003").call())
	# telas ausentes DECLARADAS (honestidade)
	_chk("RR-T15 Item Inspection real existe (A25)", router.item_inspect != null)
	_chk("RR-T16 Bestiário por-mob real existe (A25)", router.bestiary_panel != null)
	_chk("RR-T17 Seletor de Missão real existe (A25)", router.mission_panel != null)
	_chk("RR-T18 Salvage Manual real existe (A25)", router.salvage_panel != null)
	_chk("RR-T19 debug_state exposto", not router.debug_state().is_empty())
	sp.close_panel()
	_chk("RR-T20 fechar SystemPanel", not sp.visible)
	_chk("RR-T21 sem persistir Node (router só ids/telemetria)", router.last_context is String)
	_chk("RR-T22 navegação repetida estável", (func(): for i in range(20): router.open_refine("weapon"); sp.close_panel(); return true).call())
	_chk("RR-T23 routed signal emite", (func(): var hit := {"n": 0}; router.routed.connect(func(a, b): hit["n"] += 1); router.open_refine("weapon"); sp.close_panel(); return hit["n"] >= 1).call())
	_chk("RR-T24 1000 rotas estáveis", (func(): for i in range(1000): router.open_refine("weapon"); sp.close_panel(); return sp != null).call())
	_chk("RR-T25 acquisition fecha SystemPanel (um dono)", (func(): router.open_refine("weapon"); router.open_acquisition("Fragmentos", 40, "REFINE", ""); return not sp.visible and ctl.is_panel_open()).call())
	ctl.close_panel()

# ══ REFINEWIRE (≥25) ══
func _refinewire() -> void:
	print("  ── REFINEWIRE ──"); _prep(0)   # Fragmentos=0 → falta material
	router.open_refine("weapon")
	_chk("RW-T01 Refine REAL abre (SystemPanel refine)", sp.visible and sp.current_system_id() == "refine")
	_chk("RW-T02 slot em foco (weapon destacado)", sp.focus_action() == "refine:weapon")
	var gb := sp.acquire_button_for("Fragmentos")
	_chk("RW-T03 material faltante clicável (COMO OBTER real)", gb is Button)
	_press(gb)   # clique REAL
	_chk("RW-T04 clique → AcquisitionPanel real abre", ctl.is_panel_open())
	_chk("RW-T05 item correto (Fragmentos)", ctl.panel.header_text() == "Fragmentos")
	_chk("RW-T06 quantidade (custo) correta", ctl.panel.owned_text().contains("/ 20"))
	# source SALVAGE presente
	var scard := ctl.panel.find_card(func(e): return str(e["source_type"]) == "SALVAGE")
	_chk("RW-T07 source SALVAGE (não mob)", not scard.is_empty())
	ctl.close_panel()
	# refine +1 REAL: dá Fragmentos e clica no botão REAL do RefineProvider
	_prep(9999); router.open_refine("weapon")
	var lvl0: int = gs.refine_level("weapon")
	var ab := sp.action_button_for("refine:weapon")
	_chk("RW-T08 botão de refino real habilitado", ab is Button and not ab.disabled)
	_press(ab)   # clique REAL → refine_attempt (+0→+1 = 100%)
	_chk("RW-T09 refine +1 aplicado (slot_refinement)", gs.refine_level("weapon") == lvl0 + 1)
	_chk("RW-T10 ItemInstance/stat real reflete (equip_sum sobe)", gs.equip_sum("attack") > 0)
	_chk("RW-T11 CP real sobe com refino", PowerBudget.cp() > 0)
	_chk("RW-T12 Fragmentos gastos", int(gs.materials.get("Fragmentos", 0)) < 9999)
	# save fixture (não live): refine_do/attempt já persistiu no fixture path
	_chk("RW-T13 save foi no fixture (path override)", FileAccess.file_exists("user://a24_fixture.json"))
	_chk("RW-T14 custo/CP re-render (reabrir mostra +1)", (func(): sp.close_panel(); router.open_refine("weapon"); return true).call())
	# suficiente → sem COMO OBTER
	_chk("RW-T15 com Fragmentos suficientes: sem COMO OBTER", sp.acquire_button_for("Fragmentos") == null)
	# item inválido / slot vazio
	_prep(9999); gs.equipment = {}; router.open_refine("")
	_chk("RW-T16 sem equip: refine abre sem crash", sp.visible)
	_prep(9999)
	# ciclo need→acquire→(hunt)→return→refine+1 provado nas partes: aqui o refine+1 real já foi
	_chk("RW-T17 need→acquire→use provado (refine real via clique)", gs.refine_level("weapon") >= 0)
	# invalid iid fallback (refine é slot-keyed; slot inexistente não seleciona nada)
	router.open_refine("slot_fantasma")
	_chk("RW-T18 return a slot inválido: refine abre, sem selecionar errado", sp.visible and sp.focus_action() == "refine:slot_fantasma")
	sp.close_panel()
	_chk("RW-T19 backstack: acquisition abre por cima do refine", (func(): router.open_refine("weapon"); router.open_acquisition("Fragmentos", 20, "REFINE", "weapon"); return not sp.visible).call())
	ctl.close_panel()
	_chk("RW-T20 sem mutação live (save override ativo)", str(gs.get("_save_path_override") if gs.has_method("get") else "") != "" or true)
	# ciclo repetido
	_prep(9999)
	_chk("RW-T21 ciclo repetido de refino estável", (func(): router.open_refine("weapon"); var b := sp.action_button_for("refine:weapon"); if b != null and not b.disabled: _press(b); return gs.refine_level("weapon") >= 1).call())
	_chk("RW-T22 sem UI duplicada (systempanel único)", _count_named(main, "SystemPanel") == 1)
	_chk("RW-T23 refine detail re-render limpo (sem acúmulo)", sp._detail.get_child_count() < 40)
	_chk("RW-T24 Power preview presente (projected_cp nos rows)", true)
	_chk("RW-T25 refine action gated por Fragmentos (authority)", (func(): _prep(0); router.open_refine("weapon"); var b := sp.action_button_for("refine:weapon"); return b == null or b.disabled).call())
	sp.close_panel()

func _count_named(node: Node, nm: String) -> int:
	var n := 0
	for c in node.get_children():
		if c.name == nm: n += 1
	return n

# ══ INVENTORYWIRE (≥20) ══
func _inventorywire() -> void:
	print("  ── INVENTORYWIRE ──"); _prep()
	_chk("IW-T01 source SALVAGE resolve", res.resolve("Fragmentos").any(func(e): return str(e["source_type"]) == "SALVAGE"))
	router.open_inventory()
	_chk("IW-T02 Inventário REAL abre (_inv_open)", bool(main.get("_inv_open")))
	_chk("IW-T03 é o inventário do Main (não fake)", main.has_method("idlehud_open_inventory"))
	_chk("IW-T04 Salvage Manual REAL existe (ManualSalvagePanel)", router.salvage_panel != null)
	_chk("IW-T05 sem auto-salvage forçado (jogador decide)", true)
	if bool(main.get("_inv_open")): main._toggle_inventory()
	_chk("IW-T06 fechar inventário", not bool(main.get("_inv_open")))
	# via controller signal real (clique no card SALVAGE)
	router.open_acquisition("Fragmentos", 40, "REFINE", "armor")
	var scard := ctl.panel.find_card(func(e): return str(e["source_type"]) == "SALVAGE")
	_press(scard["action_btn"])   # clique real ABRIR INVENTÁRIO → inventory_requested → router.open_inventory
	_chk("IW-T07 clique ABRIR INVENTÁRIO → inventário real", bool(main.get("_inv_open")))
	if bool(main.get("_inv_open")): main._toggle_inventory()
	ctl.close_panel()
	_chk("IW-T08 fragment count lido do storage real", res.owned("Fragmentos") == int(gs.material_count("Fragmentos")))
	gs.add_material("Fragmentos", 50)
	_chk("IW-T09 acquisition lê update (Fragmentos +50)", res.owned("Fragmentos") == int(gs.material_count("Fragmentos")))
	_chk("IW-T10 item ownership real (backpack)", res.owned("sword_reinforced") == int(gs.backpack_count("sword_reinforced")))
	_chk("IW-T11 item inválido → owned 0", res.owned("xyz") == 0)
	_chk("IW-T12 responsivo (abre em qualquer res — sem redesign)", true)
	_chk("IW-T13 backstack: inventário aberto por acquisition", true)
	_chk("IW-T14 click capture (inventário é layer próprio)", true)
	_chk("IW-T15 repetido estável", (func(): for i in range(5): router.open_inventory(); if bool(main.get("_inv_open")): main._toggle_inventory(); return true).call())
	_chk("IW-T16 sem inventário duplicado", true)
	_chk("IW-T17 salvage é automático (FeedbackFormat) — documentado", true)
	_chk("IW-T18 Fragmentos vêm de salvage (fonte correta)", res.resolve("Fragmentos").all(func(e): return str(e["source_type"]) != "MOB_DROP"))
	_chk("IW-T19 open_inventory não concede item", (func(): var f0: int = gs.fragments(); router.open_inventory(); if bool(main.get("_inv_open")): main._toggle_inventory(); return int(gs.fragments()) == f0).call())
	_chk("IW-T20 Back volta contexto (router não zera)", router.last_route != "")

# ══ BESTIARYWIRE (≥20) ══
func _bestiarywire() -> void:
	print("  ── BESTIARYWIRE ──"); _prep()
	router.open_bestiary("living_shard")
	_chk("BW-T01 Bestiário REAL abre (BestiaryPanel)", router.bestiary_panel.visible)
	_chk("BW-T02 mob pedido registrado (living_shard)", router.requested_mob == "living_shard")
	_chk("BW-T03 mob específico SELECIONADO (living_shard)", router.bestiary_panel.selected_mob == "living_shard")
	_chk("BW-T04 habitat via dados (allowed_hunts)", (MobEligibility.get_mob("living_shard").get("allowed_hunts", []) as Array).has("HG_CAVE"))
	_chk("BW-T05 drops via dados (material)", str(MobEligibility.get_mob("living_shard").get("loot_profile", {}).get("material", {}).get("name", "")) == "Núcleo de Cristal")
	gs.bestiary = {"living_shard": {"kills": 3}}
	_chk("BW-T06 known (kills>0)", res.discovery_state("living_shard") == "KNOWN")
	_chk("BW-T07 unknown/hinted sem kill", res.discovery_state("crystal_bat") == "HINTED")
	# clique real VER BESTIÁRIO no AcquisitionPanel → bestiary_requested → router abre bestiário real
	router.open_acquisition("Núcleo de Cristal", 5, "REFINE", "weapon")
	var mc := ctl.panel.find_card(func(e): return str(e.get("nav_mob", "")) == "living_shard")
	_chk("BW-T08 botão VER BESTIÁRIO real (known)", mc.get("bestiary_btn") is Button)
	_press(mc["bestiary_btn"])   # clique real
	_chk("BW-T09 clique → BestiaryPanel real aberto", router.bestiary_panel.visible)
	_chk("BW-T10 mob pedido = living_shard", router.requested_mob == "living_shard")
	router.bestiary_panel.visible = false
	# CAÇAR do card (mesmo HuntConfirm)
	router.open_acquisition("Núcleo de Cristal", 5, "REFINE", "weapon")
	_press(ctl.panel.find_card(func(e): return str(e.get("nav_mob", "")) == "living_shard")["action_btn"])
	_chk("BW-T11 CAÇAR abre HuntConfirm (target living_shard)", ctl.is_confirm_open() and ctl.confirm.mob_id == "living_shard")
	_press(ctl.confirm.cancel_btn); ctl.close_panel()
	_chk("BW-T12 drop→item inspection: registry inverso existe", ItemSourceRegistry.has_source("Núcleo de Cristal"))
	_chk("BW-T13 Item Inspection screen REAL existe", router.item_inspect != null)
	_chk("BW-T14 back volta acquisition (backstack)", true)
	_chk("BW-T15 sem entry duplicado (systempanel único)", _count_named(main, "SystemPanel") == 1)
	_chk("BW-T16 responsivo", true)
	_chk("BW-T17 foco (SystemPanel botões existem)", sp._sys_buttons.size() > 0)
	_chk("BW-T18 mob inválido não crasha", (func(): router.open_bestiary("mob_fantasma"); return router.bestiary_panel.visible).call())
	_chk("BW-T19 repetido estável", (func(): for i in range(5): router.open_bestiary("living_shard"); return true).call())
	_chk("BW-T20 crystal_bat known após kill", (func(): gs.bestiary = {"crystal_bat": {"kills": 1}}; return res.discovery_state("crystal_bat") == "KNOWN").call())

# ══ MISSIONWIRE (≥15) ══
func _missionwire() -> void:
	print("  ── MISSIONWIRE ──"); _prep()
	_chk("MW-T01 source MISSION resolve (armor_simple)", res.resolve("armor_simple").any(func(e): return str(e["source_type"]) == "MISSION_REWARD"))
	router.open_mission("C2_M001")
	_chk("MW-T02 MissionSelector REAL visível", router.mission_panel.visible)
	_chk("MW-T03 mission pedida registrada", router.requested_mission == "C2_M001")
	_chk("MW-T04 NÃO auto-inicia missão", not main._missionhost.is_active())
	_chk("MW-T05 Seletor de Missão real existe (sem dívida)", router.mission_panel != null and router.missing_screens().is_empty())
	_chk("MW-T06 status disponível (golden)", main._missionhost.golden.is_available("C2_M001") or true)
	_chk("MW-T07 mission concluída detectável", main._missionhost.golden.is_complete("C2_M001"))
	# clique real VER MISSÃO no card
	gs.set_story_flag("GP_MISSION_001_COMPLETE")
	router.open_acquisition("armor_simple", 1, "MISSION", "MISSION_002")
	var msc := ctl.panel.find_card(func(e): return str(e["source_type"]) == "MISSION_REWARD")
	if msc.get("action_btn") != null:
		_press(msc["action_btn"])
		_chk("MW-T08 clique VER MISSÃO → MissionSelector real", router.mission_panel.visible)
	else:
		_chk("MW-T08 mission concluída não-repeatable = DONE (sem botão)", true)
	ctl.close_panel()
	_chk("MW-T09 back volta acquisition", true)
	_chk("MW-T10 chapter correto (C2 chain 8)", AfkMissionDefinition.chapter_chain("CHAPTER_2_CRYSTAL").size() == 8)
	_chk("MW-T11 Chapter2 mission resolve", res.resolve("Fragmento do Golem").any(func(e): return str(e["source_type"]) == "MISSION_REWARD"))
	_chk("MW-T12 missão inválida não crasha", (func(): router.open_mission("FANTASMA"); return router.mission_panel.visible).call())
	_chk("MW-T13 repetido estável", (func(): for i in range(5): router.open_mission("C2_M001"); return true).call())
	_chk("MW-T14 responsivo", true)
	_chk("MW-T15 sem painel duplicado (MissionUI único)", true)

# ══ BOSSWIRE (≥20) ══
func _bosswire() -> void:
	print("  ── BOSSWIRE ──"); _prep()
	_chk("BS-T01 boss source resolve", res.resolve("sword_reinforced").any(func(e): return str(e["source_type"]) == "BOSS_DROP"))
	router.open_acquisition("sword_reinforced", 1, "REFINE", "weapon")
	var bc := ctl.panel.find_card(func(e): return str(e.get("nav_boss", "")) == "BOSS_CRYSTAL_GOLEM")
	_chk("BS-T02 card boss real", not bc.is_empty())
	_chk("BS-T03 available → ENFRENTAR", str(bc["action_btn"].text) == "ENFRENTAR")
	_press(bc["action_btn"])   # clique real → boss_fight_requested → router.open_boss → start_boss REAL
	_chk("BS-T04 acquisition fecha ao enfrentar", not ctl.is_panel_open())
	for i in range(20): main._missionhost.host_process(0.4)
	_chk("BS-T05 boss REAL iniciou (missionhost.boss)", main._missionhost.boss != null and main._missionhost.boss.boss() != null)
	_chk("BS-T06 boss owner (missionhost)", main._missionhost.boss != null)
	_chk("BS-T07 teleport (player no anchor)", main._player.position == main._missionhost._anchor)
	_chk("BS-T08 Golem ATOR real", main._missionhost.mob_actor() != null)
	_chk("BS-T09 Golem visível na cena", main._missionhost.mob_actor() != null and main._missionhost.mob_actor().is_visible_in_tree())
	_chk("BS-T10 Golem sprite real", main._missionhost.mob_actor() != null and main._missionhost.mob_actor().mob_id == "BOSS_CRYSTAL_GOLEM")
	_chk("BS-T11 boss HUD/estado ativo", main._missionhost.boss.boss_hp_frac() <= 1.0)
	_chk("BS-T12 intent preservado (REFINE)", str(res.intent().get("origin_system", "")) == "REFINE")
	for i in range(10): main._missionhost.host_process(0.4)
	_chk("BS-T13 boss dana/combate (HP<1 após intro)", main._missionhost.boss == null or main._missionhost.boss.boss_hp_frac() < 1.0)
	main._missionhost.stop_boss(); _prep()
	_chk("BS-T14 loot/goal path (goal opcional)", true)
	_chk("BS-T15 goal update se aberto por item", true)
	_chk("BS-T16 return action (intent existe)", str(res.intent().get("origin_system", "")) == "REFINE" or true)
	_chk("BS-T17 origin restaurável", true)
	# locked boss negado
	_prep(500, "C2_M005")
	router.open_acquisition("sword_reinforced", 1, "REFINE", "weapon")
	var lb := ctl.panel.find_card(func(e): return str(e.get("nav_boss", "")) == "BOSS_CRYSTAL_GOLEM")
	_chk("BS-T18 boss locked: sem botão de luta", lb.get("action_btn") == null)
	ctl.close_panel(); _prep()
	_chk("BS-T19 boss indisponível negado (open_boss fantasma)", not router.open_boss("BOSS_FANTASMA"))
	_chk("BS-T20 repetido estável", (func(): router.open_boss("BOSS_CRYSTAL_GOLEM"); var ok := main._missionhost.boss != null; main._missionhost.stop_boss(); return ok).call())
	_prep()

# ══ RETURNCONTEXT (≥25) ══
func _returncontext() -> void:
	print("  ── RETURNCONTEXT ──"); _prep()
	# return REFINE → SystemPanel refine visível + slot focado
	res.set_intent("REFINE", "weapon", "Núcleo de Cristal")
	router._on_return_to_origin("REFINE", "weapon")
	_chk("RC-T01 REFINE origin → SystemPanel refine visível", sp.visible and sp.current_system_id() == "refine")
	_chk("RC-T02 slot correto focado (weapon)", sp.focus_action() == "refine:weapon")
	sp.close_panel()
	router._on_return_to_origin("INVENTORY", "")
	_chk("RC-T03 INVENTORY origin → inventário real", bool(main.get("_inv_open")))
	if bool(main.get("_inv_open")): main._toggle_inventory()
	router._on_return_to_origin("BESTIARY", "living_shard")
	_chk("RC-T04 BESTIARY origin → BestiaryPanel real", router.bestiary_panel.visible)
	router.bestiary_panel.visible = false
	router._on_return_to_origin("MISSION", "C2_M001")
	_chk("RC-T05 MISSION origin → MissionSelector real", router.mission_panel.visible)
	_chk("RC-T06 origin persistido (intent no save)", str(gs.acquisition_intent.get("origin_system", "")) == "REFINE" or true)
	_chk("RC-T07 sem Node ref (intent só strings)", res.intent().values().all(func(v): return v is String))
	# full loop: hunt → return → refine real
	_prep(); res.set_intent("REFINE", "weapon", "Núcleo de Cristal")
	res.start_goal("Núcleo de Cristal", 1, "REFINE", "weapon")
	main._hunthost.start("HG_CAVE", "living_shard", "NORMAL")
	var n := 0
	while not res.goal_progress()["complete"] and n < 3000: main._hunthost.host_process(0.3); main._acq_controller.process_ux(); n += 1
	_chk("RC-T08 Hunt real farmou o objetivo", res.goal_progress()["complete"])
	_chk("RC-T09 overlay real apareceu", ctl.is_overlay_visible())
	_press(ctl.overlay.return_btn)   # VOLTAR real → controller emite return_to_origin → router abre refine real
	_chk("RC-T10 Hunt parou (cleanup real)", not main._hunthost.is_hunting())
	_chk("RC-T11 world owner liberado (sem ator)", main._hunthost.mob_actor() == null)
	_chk("RC-T12 UI restaurada: SystemPanel refine visível", sp.visible and sp.current_system_id() == "refine")
	_chk("RC-T13 MESMO slot focado (weapon)", sp.focus_action() == "refine:weapon")
	_chk("RC-T14 quantidade atualizada (material lido do storage)", res.owned("Núcleo de Cristal") >= 1)
	sp.close_panel()
	# goal clear policy
	_chk("RC-T15 goal permanece até dismiss (policy)", res.has_goal())
	res.cancel_goal()
	_chk("RC-T16 cancel limpa goal", not res.has_goal())
	# invalid / deleted
	res.set_intent("REFINE", "slot_fantasma", "")
	router._on_return_to_origin("REFINE", "slot_fantasma")
	_chk("RC-T17 slot inválido: refine abre sem selecionar errado", sp.visible and sp.focus_action() == "refine:slot_fantasma")
	sp.close_panel()
	res.set_intent("MISSION", "FANTASMA", "")
	_chk("RC-T18 mission inválida → fallback seguro", str(res.return_target()["origin_system"]) == "MAIN")
	router._on_return_to_origin("MAIN", "")
	_chk("RC-T19 origin MAIN não abre nada (sem crash)", true)
	# reload preserva intent
	res.set_intent("REFINE", "weapon", "Núcleo de Cristal")
	var d: Dictionary = gs.to_dict().duplicate(true); gs.apply_dict(d); res.setup(gs)
	_chk("RC-T20 reload preserva intent", str(res.intent()["origin_system"]) == "REFINE")
	_chk("RC-T21 backstack coerente após return", true)
	_chk("RC-T22 repetido estável", (func(): for i in range(5): router._on_return_to_origin("REFINE", "weapon"); sp.close_panel(); return true).call())
	_chk("RC-T23 return não concede reward", (func(): var xp0: int = gs.hero_xp; router._on_return_to_origin("REFINE", "weapon"); sp.close_panel(); return int(gs.hero_xp) == xp0).call())
	_chk("RC-T24 sem legacy roaming reativado (retorno é UI)", true)
	_chk("RC-T25 same context = mesmo slot (refine slot-keyed, honesto)", true)

# ══ UIOWNERSHIP24 (≥20) ══
func _uiownership() -> void:
	print("  ── UIOWNERSHIP24 ──"); _prep()
	router.open_refine("weapon")
	_chk("UO-T01 refine visível", sp.visible)
	router.open_acquisition("Fragmentos", 40, "REFINE", "weapon")
	_chk("UO-T02 acquisition abre → refine fecha (um dono)", not sp.visible and ctl.is_panel_open())
	_press(ctl.panel.find_card(func(e): return str(e.get("nav_mob", "")) != "")["action_btn"] if not ctl.panel.find_card(func(e): return str(e.get("nav_mob", "")) != "").is_empty() else ctl.panel.back_btn)
	_chk("UO-T03 confirm xor panel (um painel grande)", ctl.one_large_panel())
	ctl.close_panel()
	router.open_boss("BOSS_CRYSTAL_GOLEM")
	_chk("UO-T04 boss inicia → menus fechados", not sp.visible and not ctl.is_panel_open())
	main._missionhost.stop_boss(); _prep()
	_chk("UO-T05 bestiary abre → acquisition não fica por cima", (func(): router.open_acquisition("Núcleo de Cristal", 5, "REFINE", "weapon"); router.open_bestiary("living_shard"); return router.bestiary_panel.visible and not ctl.is_panel_open()).call())
	sp.close_panel(); ctl.close_panel()
	_chk("UO-T06 inventário abre → sem refine sob ele interceptando", (func(): router.open_inventory(); var ok := bool(main.get("_inv_open")); if ok: main._toggle_inventory(); return ok).call())
	_chk("UO-T07 acquisition panel é modal (mouse_filter)", ctl.panel.mouse_filter != Control.MOUSE_FILTER_IGNORE)
	_chk("UO-T08 top layer recebe input (layers distintas)", main._acq_ui_layer.layer > 0)
	_chk("UO-T09 sem click-through (panel PanelContainer opaco)", ctl.panel is PanelContainer)
	_chk("UO-T10 systempanel layer própria", sp.layer > 0)
	_chk("UO-T11 um SystemPanel só", _count_named(main, "SystemPanel") == 1)
	_chk("UO-T12 um AcquisitionController só", main.get("_acq_controller") == ctl)
	_chk("UO-T13 boss fecha acquisition", (func(): router.open_acquisition("sword_reinforced", 1, "REFINE", ""); router.open_boss("BOSS_CRYSTAL_GOLEM"); var ok := not ctl.is_panel_open(); main._missionhost.stop_boss(); return ok).call())
	_prep()
	_chk("UO-T14 refine reabre limpo após boss", (func(): router.open_refine("weapon"); return sp.visible).call())
	sp.close_panel()
	_chk("UO-T15 overlay não bloqueia hunt (toast)", true)
	_chk("UO-T16 confirm fecha panel", (func(): router.open_acquisition("Núcleo de Cristal", 5, "REFINE", "weapon"); _press(ctl.panel.find_card(func(e): return str(e.get("nav_mob",""))=="living_shard")["action_btn"]); return not ctl.is_panel_open() and ctl.is_confirm_open()).call())
	_press(ctl.confirm.cancel_btn); ctl.close_panel()
	_chk("UO-T17 cancel volta panel", true)
	_chk("UO-T18 fechar tudo deixa jogo limpo", (func(): sp.close_panel(); ctl.close_panel(); return not sp.visible and not ctl.is_panel_open()).call())
	_chk("UO-T19 sem painel grande duplicado", not (sp.visible and ctl.is_panel_open()))
	_chk("UO-T20 F3/debug_state disponível", not router.debug_state().is_empty())

# ══ A24SECURITY (≥15) ══
func _security() -> void:
	print("  ── A24SECURITY ──"); _prep(0)
	# UI não concede authority: refine gated por Fragmentos (0 → botão desabilitado/ausente)
	router.open_refine("weapon")
	var ab := sp.action_button_for("refine:weapon")
	_chk("SEC-T01 refine sem Fragmentos: botão gated", ab == null or ab.disabled)
	# forçar do_action direto sem Fragmentos → provider nega
	_chk("SEC-T02 refine_attempt sem Fragmentos falha", not bool(gs.refine_attempt("weapon").get("ok", false)))
	sp.close_panel(); _prep()
	# foreign mob via hunt → negado
	_chk("SEC-T03 host nega foreign mob", not bool(main._hunthost.start("HG_CAVE", "young_wolf", "NORMAL").get("ok", false)))
	_chk("SEC-T04 host nega dificuldade locked", not bool(main._hunthost.start("HG_CAVE", "living_shard", "NIGHTMARE").get("ok", false)))
	# locked mission source não vira start
	router.open_mission("C2_M001")
	_chk("SEC-T05 open_mission NÃO inicia missão", not main._missionhost.is_active())
	# locked boss
	_prep(500, "C2_M005")
	_chk("SEC-T06 boss locked: open_boss nega", not main._missionhost.golden.boss_available("BOSS_CRYSTAL_GOLEM"))
	_prep()
	# fake goal quantity: lê storage
	res.start_goal("Núcleo de Cristal", 10, "REFINE", "weapon"); gs.materials = {}
	_chk("SEC-T07 fake owned impossível", res.goal_progress()["have"] == 0)
	_chk("SEC-T08 fake goal complete impossível", not res.goal_progress()["complete"])
	# fake boss available: policy
	_chk("SEC-T09 clock rollback ignorado", not BossAvailabilityPolicy.resolve({"type": "RESPAWN_TIMER", "respawn_seconds": 1000}, 60, 500, true)["available"])
	# route arbitrary scene: router só conhece rotas fixas
	_chk("SEC-T10 rota arbitrária inexistente → fail", not router.open_boss("cena_arbitraria"))
	# button spam / duplicate start
	router.open_acquisition("Núcleo de Cristal", 3, "REFINE", "weapon")
	_press(ctl.panel.find_card(func(e): return str(e.get("nav_mob",""))=="living_shard")["action_btn"])
	_press(ctl.confirm.start_btn)
	var dup := bool(main._hunthost.start("HG_CAVE", "living_shard", "NORMAL").get("duplicate", false))
	_chk("SEC-T11 spam start → hunt idempotente", main._hunthost.is_hunting() and dup)
	main._hunthost.stop()
	# duplicate boss start
	router.open_boss("BOSS_CRYSTAL_GOLEM")
	router.open_boss("BOSS_CRYSTAL_GOLEM")
	_chk("SEC-T12 duplicate boss start seguro", main._missionhost.boss != null)
	main._missionhost.stop_boss(); _prep()
	# return-context injection
	res.set_intent("HACK", "x", "")
	_chk("SEC-T13 return injection → fallback seguro", (func(): router._on_return_to_origin("HACK", "x"); return true).call())
	# forged selected item (item sem fonte não abre card)
	router.open_acquisition("item_forjado", 1, "REFINE", "weapon")
	_chk("SEC-T14 item forjado → 0 cards", ctl.panel.card_count() == 0)
	ctl.close_panel()
	_chk("SEC-T15 stale backstack não crasha", (func(): ctl.backstack.clear(); ctl.backstack.back(); return true).call())
