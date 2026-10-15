extends SceneTree
## Self-test FATIA A17 — Player Experience / Hunt Travel / Session HUD / Hunt UX. Prova a VIAGEM real (reposiciona no
## spot + hooks visuais do host), o HUD compacto de sessão, o botão de entrada e a UX do painel (nomes/locks). FIXTURE.

var _fail := 0
func _chk(nm: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), nm])
	if not cond: _fail += 1

var gs
var _hosts: Array = []

func _fresh_gs(cls: String = "CLASS_1", wpn: String = "sword_eternal", stage: int = 50) -> void:
	gs.reset_save(); gs.character_class = cls; gs.equipment = {"weapon": wpn}; gs.slot_refinement = {"weapon": 0}
	gs.stage_highest_global = stage; gs.appearance = CharacterAppearance.DEFAULT_LEGACY.duplicate(true)
	gs.hero_xp = 0; gs.item_instances = []

func _mk_host(stub: Node, start_pos: Vector2 = Vector2.ZERO) -> HuntHost:
	var h := HuntHost.new(); root.add_child(h); _hosts.append(h)
	var player = Node2D.new(); player.set_script(load("res://scripts/PlayerController.gd")); player.position = start_pos
	h.setup(stub, player, null, gs)
	return h

func _initialize() -> void:
	gs = root.get_node_or_null("GameState")
	var fixture := "user://a17_fixture_save.json"
	gs.set_save_path_override(fixture); var mem: Dictionary = gs.to_dict()

	_test_hunt_travel()
	_test_session_hud()
	_test_hunt_ux()

	for h in _hosts:
		if is_instance_valid(h): h.queue_free()
	gs.set_save_path_override(""); gs.apply_dict(mem); gs._dirty = false; gs._session_started = false
	if FileAccess.file_exists(fixture): DirAccess.remove_absolute(fixture)
	print("  [save-safe] fixture descartada; save vivo intocado")
	print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
	quit(0 if _fail == 0 else 1)

# ══════════════ HUNT_TRAVEL ══════════════
func _test_hunt_travel() -> void:
	print("  ── HUNT_TRAVEL ──")
	_fresh_gs()
	var stub: Node = load("res://scripts/_a17_stub_main.gd").new(); root.add_child(stub)
	var start_pos := Vector2(999, 999)   # posição de progressão distinta do anchor do spot
	var h := _mk_host(stub, start_pos)
	var r := h.start("HG_PLAINS_LOW")
	_chk("TRV-T01 start ok", bool(r.get("ok", false)))
	var anchor = h.hunt.world.spot_of(HuntHost.LOCAL_CHAR)["anchor"]
	_chk("TRV-T02 spot tem anchor real (server)", anchor is Vector2 and anchor != Vector2.ZERO)
	_chk("TRV-T03 player REPOSICIONADO no anchor do spot", h._player.position == anchor)
	_chk("TRV-T04 posição mudou (viagem real, ≠ posição de progressão)", h._player.position != start_pos)
	_chk("TRV-T05 movement lock ativo", h._player.locked)
	_chk("TRV-T06 hook on_hunt_enter chamado (esconder cenário/câmera/banner)", stub.entered == 1 and stub.last_ground == "HG_PLAINS_LOW")
	_chk("TRV-T07 nome amigável passado ao host", stub.last_friendly == "PLANÍCIE (Iniciante)")
	# STOP volta
	h.stop()
	_chk("TRV-T08 hook on_hunt_exit chamado (restaura cenário/câmera)", stub.exited == 1)
	_chk("TRV-T09 player volta à posição de progressão", h._player.position == start_pos)
	_chk("TRV-T10 movement lock liberado", not h._player.locked)
	# camera assert (contrato): o host expõe o anchor de destino p/ a câmera acompanhar
	_chk("TRV-T11 anchor de destino == spot do servidor (câmera acompanha)", stub.last_anchor == anchor)

# ══════════════ SESSION_HUD ══════════════
func _test_session_hud() -> void:
	print("  ── SESSION_HUD ──")
	_fresh_gs()
	var stub: Node = load("res://scripts/_a17_stub_main.gd").new(); root.add_child(stub)
	var h := _mk_host(stub)
	# fora da caça: botão CAÇAR visível, session HUD escondido, lista escondida
	_chk("SES-T01 entrada CAÇAR visível fora da caça", h._entry_layer.visible)
	_chk("SES-T02 session HUD escondido fora da caça", not h.session_hud.visible)
	h.start("HG_PLAINS_LOW")
	for i in range(30): h.host_process(0.2)
	_chk("SES-T03 session HUD aparece na caça", h.session_hud.visible)
	_chk("SES-T04 lista de grounds fecha na caça", not h.panel.visible)
	_chk("SES-T05 botão CAÇAR some na caça", not h._entry_layer.visible)
	h.toggle_panel()   # durante a caça deve ser no-op
	_chk("SES-T06 toggle_panel não abre lista durante a caça", not h.panel.visible)
	# HUD mostra dados reais
	h.session_hud.refresh()
	_chk("SES-T07 HUD compacto reflete kills reais", int(h.debug_state().get("kills", 0)) >= 0 and h.session_hud._stats.text != "—")
	h.stop()
	_chk("SES-T08 session HUD some no STOP", not h.session_hud.visible)
	_chk("SES-T09 botão CAÇAR volta no STOP", h._entry_layer.visible)

# ══════════════ HUNT_UX ══════════════
func _test_hunt_ux() -> void:
	print("  ── HUNT_UX ──")
	_fresh_gs("CLASS_1", "sword_eternal", 5)   # stage baixo → HG_PLAINS_HIGH LOCKED
	var stub: Node = load("res://scripts/_a17_stub_main.gd").new(); root.add_child(stub)
	var h := _mk_host(stub)
	var list := h.panel.grounds_list()
	# A31 (fix STALE "grounds (3)"): subset core + piso, catálogo cresce (A26/A29 adicionaram grounds).
	var _g17: Array = []
	for _x in list: _g17.append(str(_x["ground_id"]))
	_chk("UX-T01 grounds do registry (⊇ HG_PLAINS_LOW/HIGH, >=3, únicos)",
		list.size() >= 3
		and TestHarness.missing_ids(["HG_PLAINS_LOW", "HG_PLAINS_HIGH"], _g17).is_empty()
		and TestHarness.duplicate_ids(_g17).is_empty())
	var low := {}; var high := {}
	for g in list:
		if str(g["ground_id"]) == "HG_PLAINS_LOW": low = g
		if str(g["ground_id"]) == "HG_PLAINS_HIGH": high = g
	_chk("UX-T02 nome amigável (não CANON_REVIEW_REQUIRED)", str(low["friendly"]) == "PLANÍCIE (Iniciante)")
	_chk("UX-T03 ground iniciante DISPONÍVEL", str(low["state"]) == "AVAILABLE")
	_chk("UX-T04 mobs listados", (low["mobs"] as Array).size() >= 1)
	_chk("UX-T05 ground avançado LOCKED", str(high["state"]) == "LOCKED")
	_chk("UX-T06 lock explica o requisito (Stage)", str(high["lock_reason"]).begins_with("Requer Stage"))
	# UI construída com botões reais
	h.panel.refresh()
	# A31: invariante real = UM card por ground listado (escala com o catálogo), não count fixo 3.
	_chk("UX-T07 painel tem UM card por ground (cards == grounds)", h.panel._list_box.get_child_count() == h.panel.grounds_list().size() and h.panel._list_box.get_child_count() >= 3)
	# START só pela ground disponível
	var res_locked := h.start("HG_PLAINS_HIGH")
	_chk("UX-T08 start em ground LOCKED negado", not bool(res_locked.get("ok", false)))
	_chk("UX-T09 start em ground disponível ok", bool(h.start("HG_PLAINS_LOW").get("ok", false)))
	h.stop()
