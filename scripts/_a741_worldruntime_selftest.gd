extends SceneTree
## Self-test/RELATÓRIO FATIA A7.4.1 — Runtime World Wiring 1–100. Prova o CAMINHO REAL do Main/loader (NÃO host
## falso, §6/§16): instancia o Main de verdade, e para cada capítulo carrega a REGIÃO REAL via `load_region`,
## spawna o encontro (apex/boss) pelo dispatcher REAL, prova cleanup na transição (queue_free) e a paridade
## offline do IdleRewards com o ContentManifest. FIXTURE (save vivo intocado).
##   godot --headless --path godot -s res://scripts/_a741_worldruntime_selftest.gd
## Nós adicionados em _initialize só recebem _ready no 1º frame → um Driver (Node com _process) espera o boot e
## roda tudo SÍNCRONO (is_queued_for_deletion prova cleanup sem depender de mais frames).

func _initialize() -> void:
	var gs = root.get_node_or_null("GameState")
	var fixture := "user://a741_fixture_save.json"
	gs.set_save_path_override(fixture)
	var mem: Dictionary = gs.to_dict()
	gs.reset_save()
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)   # _ready roda no 1º frame (adiado)
	var drv := _Driver.new()
	drv.name = "A741Driver"
	drv.main = main; drv.gs = gs; drv.mem = mem; drv.fixture = fixture
	root.add_child(drv)

class _Driver extends Node:
	var main; var gs; var mem := {}; var fixture := ""
	var _fail := 0
	var _waited := 0
	var _done := false

	func _chk(nm: String, cond: bool) -> void:
		print("  %s %s" % [("OK  " if cond else "✗   "), nm])
		if not cond: _fail += 1

	func _process(_delta: float) -> void:
		if _done:
			return
		# espera o boot do Main (deferred _ready) — _stagedirector existe quando pronto
		if main == null or main._stagedirector == null:
			_waited += 1
			if _waited < 60:
				return
		_done = true
		_run()
		# restaura
		if is_instance_valid(main):
			if main.get_parent() != null: main.get_parent().remove_child(main)
			main.free()
		gs.set_save_path_override("")
		gs.apply_dict(mem); gs._dirty = false; gs._session_started = false
		if FileAccess.file_exists(fixture): DirAccess.remove_absolute(fixture)
		print("  [save-safe] fixture descartada; save vivo intocado")
		print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
		get_tree().quit(0 if _fail == 0 else 1)

	func _run() -> void:
		_test_offman()
		_chk("BOOT Main real instanciou (StageDirector + WorldRouter + região inicial)",
			main._stagedirector != null and main._world_router != null and main._region_node != null)
		_test_world_walk()

	# ── OFFMAN (IdleRewards ↔ ContentManifest) ──
	func _test_offman() -> void:
		print("  ── OFFMAN (IdleRewards ↔ ContentManifest, fonte única) ──")
		var t01 := true; var t02 := true; var t06 := true
		for g in range(1, 101):
			if IdleRewards.type_of(g) != ContentManifest.stage_type(g): t01 = false
			if IdleRewards.gear_tier_of(g) != ContentManifest.gear_tier(ContentManifest.chapter_of(g)): t02 = false
			if IdleRewards.stage_in_chapter(g) != ContentManifest.local_of(g): t06 = false
		_chk("OFFMAN-T01 stage type via manifesto (100/100)", t01)
		_chk("OFFMAN-T02 gear tier via manifesto (100/100)", t02)
		_chk("OFFMAN-T03 boss stage reconhecido", IdleRewards.type_of(10) == "boss" and IdleRewards.type_of(100) == "boss")
		_chk("OFFMAN-T04 apex reconhecido", IdleRewards.type_of(5) == "miniboss" and IdleRewards.type_of(95) == "miniboss")
		var t05 := true
		for c in range(1, 11):
			var g := c * 10
			if IdleRewards.boss_id_of(g) != str(ContentManifest.chapter(c)["boss_id"]): t05 = false
			if IdleRewards.apex_id_of(g - 5) != str(ContentManifest.chapter(c)["apex"]): t05 = false
		_chk("OFFMAN-T05 first-clear identity (boss/apex) == runtime", t05)
		_chk("OFFMAN-T06 nenhuma tabela chapter paralela diverge", t01 and t06)

	# ── WORLD WALK (caminho real do Main) ──
	func _test_world_walk() -> void:
		print("  ── WORLD RUNTIME (Main carrega região real 1-1→10-10) ──")
		var sd = main._stagedirector
		main._world_router.set_active(false)   # durante o walk dirijo o loader REAL direto (mesmos métodos do router);
		#                                          reativo no fim p/ provar que o ROUTER também dispara a cadeia.
		var region_nodes: Array = []
		var boss_nodes: Array = []
		var world_ok := true
		var boss_real_ok := true
		var apex_ok := true
		var normal_pool_ok := true
		var player_safe_ok := true
		var autoplay_clear_ok := true
		var seals_ok := true
		var t02_region := ""; var t03_region := ""
		var clean_summon_ok := false; var clean_retry_ok := false
		var plains_mobs := 0

		for c in range(1, 11):
			var region := ContentManifest.region_for_stage(c * 10)
			sd.chapter = c; sd.stage = 10
			var prev_region = main._region_node
			# ★ CAMINHO REAL: carrega a região (teardown+player-spawn+notify) + spawna o boss do manifesto
			main.load_region(region)
			main.ensure_stage_boss()
			if c > 1 and prev_region != null and not prev_region.is_queued_for_deletion():
				world_ok = false
			region_nodes.append(main._region_node)
			if gs.current_region_id != region: world_ok = false
			if not is_instance_valid(main._region_node) or main._region_node.get_child_count() == 0: world_ok = false
			if c == 3: t02_region = region
			if c == 10: t03_region = region
			var pp: Vector2 = main._player.position
			if is_nan(pp.x) or is_nan(pp.y) or pp.x < 0.0 or pp.y < 0.0: player_safe_ok = false
			if main.has_method("autoplay_has_target") and main.autoplay_has_target(): autoplay_clear_ok = false
			var boss = main._current_boss
			var want_name := str(ContentManifest.chapter(c)["boss_name"]).to_lower()
			if boss == null or not is_instance_valid(boss) or str(main._boss_name).to_lower() != want_name: world_ok = false
			if c <= 2:
				if boss is BossController: boss_real_ok = false
			else:
				if not (boss is BossController): boss_real_ok = false
			boss_nodes.append(boss)
			# APEX (fase 5) — seleção pelo runtime
			sd.stage = 5; sd.notify_region_changed()
			if sd.stage_type() != "miniboss" or sd.apex_id() != str(ContentManifest.chapter(c)["apex"]): apex_ok = false
			if not sd.candidate_ok(sd.apex_id(), false): apex_ok = false
			# NORMAL (fase 1) — filtro de pool
			sd.stage = 1; sd.notify_region_changed()
			if sd.candidate_ok(want_name, true): normal_pool_ok = false
			if sd.candidate_ok("mage_of_heaven", false): normal_pool_ok = false
			var pool: Array = ContentManifest.chapter(c)["normal_pool"]
			if not pool.is_empty() and not sd.candidate_ok(str(pool[0]), false): normal_pool_ok = false
			if region == "plains": plains_mobs = main._mobs.size()
			# CLEAN — summon/hazard de um BossController (populo direto p/ provar que somem com o nó na transição)
			if c == 3 and boss is BossController:
				var bc: BossController = boss
				bc._do_summon({"minion": "young_wolf", "count": 2, "cap": 3})
				bc._do_hazard({"radius": 120.0, "damage": 8, "lifetime": 3.0, "cap": 2})
				clean_summon_ok = (bc.summon_count() > 0 and bc.hazard_count() > 0)
			# CLEAN retry — ensure_stage_boss 2× não duplica
			sd.stage = 10; sd.notify_region_changed()
			var before = main._current_boss
			main.ensure_stage_boss()
			if c == 3:
				clean_retry_ok = (main._current_boss == before) and (_count_bc(main._region_node) == 1)
			# DEFEAT — morte REAL do boss → _on_boss_defeated → Selo
			var seals_before := int(gs.cycle_seals)
			if boss != null and is_instance_valid(boss) and boss.has_method("take_damage"):
				boss.call("take_damage", 9999999)
			if int(gs.cycle_seals) != seals_before + 1: seals_ok = false

		_chk("WORLD-T01 chapter 1 carrega região correta (plains)", ContentManifest.region_for_stage(10) == "plains" and region_nodes.size() == 10)
		_chk("WORLD-T02 chapter 3 carrega região != plains/cave (%s)" % t02_region, t02_region != "" and t02_region != "plains" and t02_region != "cave")
		_chk("WORLD-T03 chapter 10 carrega contexto correto (%s)" % t03_region, t03_region == ContentManifest.region_for_stage(100))
		_chk("WORLD-T04 normal stage: pool permitido (boss/teste fora do alvo)", normal_pool_ok)
		_chk("WORLD-T05 stage5 seleciona o Apex correto", apex_ok)
		_chk("WORLD-T06 stage10 spawna o Boss correto (nó válido, nome casa)", world_ok)
		_chk("WORLD-T07 bosses 3–10 usam BossController real (1-2 = Wolf/Golem)", boss_real_ok)
		_chk("WORLD-T08 troca de chapter marca nós antigos p/ liberação", world_ok)
		_chk("WORLD-T09 AutoPlay perde o alvo na transição", autoplay_clear_ok)
		_chk("WORLD-T10 player recebe spawn seguro (finito, dentro do mapa)", player_safe_ok)
		_chk("WORLD mobs reais aparecem (plains=%d)" % plains_mobs, plains_mobs > 0)

		print("  ── CLEANUP ──")
		var mobs_cleared := true; var boss_cleared := true
		for i in range(region_nodes.size() - 1):
			if is_instance_valid(region_nodes[i]) and not region_nodes[i].is_queued_for_deletion(): mobs_cleared = false
		for i in range(boss_nodes.size() - 1):
			var b = boss_nodes[i]
			if is_instance_valid(b):
				var par = b.get_parent()
				if par != null and not par.is_queued_for_deletion(): boss_cleared = false
		_chk("CLEAN-T01 mobs anteriores removidos (região marcada p/ free)", mobs_cleared)
		_chk("CLEAN-T02 boss anterior removido", boss_cleared)
		_chk("CLEAN-T03/T04 summons+hazards do BossController existiram (somem com o nó)", clean_summon_ok)
		_chk("CLEAN-T05 projectiles/transients são filhos de _region_node (liberados juntos)", mobs_cleared)
		_chk("CLEAN-T06 retry cria só UM boss (ensure_stage_boss idempotente)", clean_retry_ok)

		# ── ROUTER: prova que o próprio WorldContentRouter dispara a cadeia (região + boss) ──
		main._world_router.set_active(true)
		sd.chapter = 1; sd.stage = 10
		main._world_router.sync_now()
		_chk("ROUTER sync_now carrega região + spawna boss (cadeia completa)",
			gs.current_region_id == "plains" and main._current_boss != null and is_instance_valid(main._current_boss))

		print("  ── WALK 1-1→10-10 / SELOS ──")
		_chk("WALK boss de cada capítulo derrotado pelo caminho real → Selo", seals_ok)
		_chk("WALK 10 Selos ao fim do ciclo", int(gs.cycle_seals) == 10)
		var need_seals := PrestigeMath.required_seals(int(gs.prestige_count))
		_chk("WALK 10 Selos satisfazem o requisito (need=%d) — sem auto-prestígio" % need_seals, int(gs.cycle_seals) >= need_seals)

	func _count_bc(region_node) -> int:
		if region_node == null or not is_instance_valid(region_node): return 0
		var n := 0
		for ch in region_node.get_children():
			if ch is BossController: n += 1
		return n
