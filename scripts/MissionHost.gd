class_name MissionHost extends Node
## FATIA A18 — integra o MissionEngine ao game loop REAL (teleport-only §A18.8, movement lock §A18.10, tick owner
## único). Reusa os hooks visuais do Main (on_hunt_enter/exit) p/ a viagem. Concede a completion reward EXACT-ONCE
## via GoldenPath (story) ou por run (repetível). Movement lock INDEPENDENTE de AUTO (§A18.10). Sobrevivência = A17.

signal mission_state_changed(active: bool)

var _main: Node = null
var _player: Node2D = null
var gs = null
var lootmgr = null
var golden: GoldenPath
var engine: MissionEngine = null
var active_mission := ""
var active_difficulty := "NORMAL"
var active_run_id := ""
var _pre_pos := Vector2.ZERO
var _anchor := Vector2.ZERO
var _autoplay_was_on := false
var _now := 0.0
var _revive_at := -1.0
var _run_counter := 0
const REVIVE_DELAY := 2.0
var last_summary: Dictionary = {}

var _ui: CanvasLayer = null
var _entry_btn: Button = null
var _hud: Label = null
var _summary_lbl: Label = null
var _continue_btn: Button = null

func setup(main: Node, player: Node2D, p_gs, p_lootmgr) -> void:
	_main = main; _player = player
	gs = p_gs if p_gs != null else get_tree().root.get_node_or_null("GameState")
	lootmgr = p_lootmgr
	golden = GoldenPath.new(); golden.setup(gs)

## UI MÍNIMA (§A18.19): botão "MISSÕES" descobrível → inicia a missão atual da cadeia; HUD compacto de progresso;
## summary na conclusão com [CONTINUAR]. Progressive disclosure: o botão some quando o capítulo acaba.
func build_ui() -> void:
	_ui = CanvasLayer.new(); _ui.layer = 47; _ui.name = "MissionUI"; add_child(_ui)
	var root := Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; _ui.add_child(root)
	_entry_btn = Button.new(); _entry_btn.text = "📜 MISSÕES"
	_entry_btn.anchor_left = 0.0; _entry_btn.anchor_top = 1.0; _entry_btn.anchor_bottom = 1.0
	_entry_btn.offset_left = 148; _entry_btn.offset_top = -92; _entry_btn.offset_bottom = -56; _entry_btn.offset_right = 280
	_entry_btn.pressed.connect(_on_entry_pressed); root.add_child(_entry_btn)
	var pc := PanelContainer.new(); pc.set_anchors_preset(Control.PRESET_TOP_RIGHT); pc.position = Vector2(-300, 200); pc.custom_minimum_size = Vector2(280, 0); root.add_child(pc)
	var vb := VBoxContainer.new(); pc.add_child(vb)
	_hud = Label.new(); _hud.text = ""; vb.add_child(_hud)
	_summary_lbl = Label.new(); _summary_lbl.text = ""; _summary_lbl.visible = false; vb.add_child(_summary_lbl)
	_continue_btn = Button.new(); _continue_btn.text = "CONTINUAR"; _continue_btn.custom_minimum_size = Vector2(0, 40); _continue_btn.visible = false
	_continue_btn.pressed.connect(_on_continue_pressed); vb.add_child(_continue_btn)
	var stop_btn := Button.new(); stop_btn.text = "SAIR"; stop_btn.custom_minimum_size = Vector2(0, 40)
	stop_btn.pressed.connect(stop_mission); vb.add_child(stop_btn)
	_refresh_ui()

func _on_entry_pressed() -> void:
	if is_active(): return
	var cur := golden.current_mission()
	if cur == "" and golden.is_unlocked("REPEATABLE_WOLF"): cur = "REPEATABLE_WOLF"
	if cur != "": start_mission(cur)

func _on_continue_pressed() -> void:
	if _summary_lbl != null: _summary_lbl.visible = false
	if _continue_btn != null: _continue_btn.visible = false
	stop_mission()

func _refresh_ui() -> void:
	if _hud == null: return
	if boss != null:
		if _entry_btn != null: _entry_btn.visible = false
		var bf := boss.boss_hp_frac()
		if not _boss_intro_done: _hud.text = "%s\n(intro…)" % str(active_boss_id)
		elif boss_failed: _hud.text = "DERROTA\nPoder %d (rec. %d)\n[RETRY / FARMAR / MELHORAR]" % [PowerBudget.cp(), int(BossActivityDefinition.get_boss(active_boss_id).get("recommended_cp", 0))]
		else: _hud.text = "%s\nFase %s  HP %d%%\nSeu HP %d/%d" % [str(BossActivityDefinition.get_boss(active_boss_id).get("display_name_key", active_boss_id)), boss.phase, int(bf * 100.0), int(gs.hero_hp) if gs != null else 0, int(gs.max_hp_total()) if gs != null else 0]
		return
	if is_active() and engine != null:
		if _entry_btn != null: _entry_btn.visible = false
		var obj := "Abates" if engine.objective != AfkMissionDefinition.OBJ_COLLECT else "Coletados"
		_hud.text = "%s\n%s: %d / %d\nHP %d/%d" % [str(engine._def.get("display_name_key", active_mission)), obj, engine.progress, engine.required, int(gs.hero_hp) if gs != null else 0, int(gs.max_hp_total()) if gs != null else 0]
	else:
		var cur := golden.current_mission()
		if _entry_btn != null: _entry_btn.visible = (cur != "" or golden.is_unlocked("REPEATABLE_WOLF"))
		_hud.text = ""

func is_active() -> bool: return (engine != null and not engine.is_completed()) or boss != null

var mission_auto := true   # §27 — AUTO da missão (separado do AutoPlay de Progressão). OFF pausa a luta, mantém lock.
func toggle_auto() -> void: mission_auto = not mission_auto
func set_auto(v: bool) -> void: mission_auto = v

## FIELD FIX 01B — HUD da missão: HudShell modo MISSION + SUPRIME a UI de Hunt (a screenshot mostrava HuntSessionHud).
func _set_mission_hud(active: bool) -> void:
	if _main == null: return
	var shell = _main.get("_hudshell")
	if shell != null and shell.has_method("on_mission_changed"): shell.on_mission_changed(active)
	var hh = _main.get("_hunthost")
	if hh != null:
		# esconde o botão ⚔ CAÇAR e o HUD de sessão de Hunt enquanto a missão roda (um dono só §21)
		if hh.get("_entry_layer") != null: hh._entry_layer.visible = not active
		if hh.get("session_hud") != null and active: hh.session_hud.visible = false

# FIELD FIX 01B — ATORES VISÍVEIS. root visível (filho do Main), 1 ator por mob lógico, sincronizado + approach.
var _actors_root: Node2D = null
var _mob_actor: PveMobActor = null
var _bound_mob = null

func _ensure_actors_root() -> void:
	if _actors_root != null and is_instance_valid(_actors_root): return
	_actors_root = Node2D.new(); _actors_root.name = "MissionActorsRoot"; _actors_root.z_index = 50
	# no jogo real, pendura no Main (visível); no self-test (stub), em si mesmo
	if _main != null and _main.is_inside_tree(): _main.add_child(_actors_root)
	else: add_child(_actors_root)

## Mantém UM ator visível casado ao mob lógico atual. Cria no spawn (spawn pocket → approach), livra na morte (§7/§13).
func _sync_mob_actor(logical_mob, mob_id: String, delta: float) -> void:
	_ensure_actors_root()
	if logical_mob != _bound_mob:
		if _mob_actor != null and is_instance_valid(_mob_actor): _mob_actor.die_and_free()
		_mob_actor = null; _bound_mob = logical_mob
		if logical_mob != null:
			var vkey := ""
			if BossActivityDefinition.exists(mob_id):
				# A27 — se o boss declara `visual_key` (asset fora de bosses/, ex.: mobs/runtime/spider_matriarch), usa-o;
				# senão, a convenção bosses/<visual_id>.
				var bdv: Dictionary = BossActivityDefinition.get_boss(mob_id)
				vkey = str(bdv.get("visual_key", "bosses/%s" % str(bdv.get("visual_id", mob_id))))
			elif MobEligibility.exists(mob_id):
				vkey = "mobs/%s" % str(MobEligibility.get_mob(mob_id).get("visual_id", mob_id))
			else:
				vkey = "mobs/young_wolf"
			var elite: bool = logical_mob is HuntMob and (logical_mob as HuntMob).is_elite
			_mob_actor = PveMobActor.new(); _mob_actor.setup(vkey, mob_id, elite)
			_actors_root.add_child(_mob_actor)
			_mob_actor.global_position = _anchor + PveMobActor.pocket_for(int(engine.stats["kills"]) if engine != null else 0)   # spawn pocket variado (§A20.10)
	if _mob_actor != null and is_instance_valid(_mob_actor) and logical_mob != null:
		_mob_actor.approach(_anchor, 240.0, delta)   # o lobo VEM até o Errante (§A18.10)
		_mob_actor.face(_anchor)                     # ★ B3 — encara o alvo mesmo parado (mesmo fix da Hunt)

## ★★★ Ponto de combate no mundo, pela FONTE ÚNICA (`HuntMapBinding.world_combat_anchor`).
## ⛔ Se o mapa não resolver, GRITA e mantém o comportamento antigo — nunca teleporta calado
## para um lugar arbitrário (foi assim que a missão foi parar dentro da Vila).
func _resolve_combat_anchor(map_id: String) -> Vector2:
	var a := HuntMapBinding.world_combat_anchor(_main, map_id, Vector2(200, 200))
	if a == Vector2.INF:
		push_warning("[MissionHost] mapa '%s' sem região ligada — usando anchor legado (200,200)" % map_id)
		return Vector2(200, 200)
	print("[MissionHost] spot de combate: map=%s => %s (centro da região)" % [map_id, str(a)])
	return a

func actor_root() -> Node2D: return _actors_root
func mob_actor() -> PveMobActor: return _mob_actor
func _free_actors() -> void:
	if _mob_actor != null and is_instance_valid(_mob_actor): _mob_actor.queue_free()
	_mob_actor = null; _bound_mob = null
	if _actors_root != null and is_instance_valid(_actors_root):
		if _actors_root.get_parent() != null: _actors_root.get_parent().remove_child(_actors_root)
		_actors_root.queue_free()
	_actors_root = null

# ── A19 BOSS ──
var boss: BossEncounterRuntime = null
var active_boss_id := ""
# A40 — a dificuldade do boss reutiliza o campo `active_difficulty` (linha ~15), pois boss e missão são exclusivos.
var boss_failed := false
var _boss_intro_done := false
var _boss_intro_t := 0.0
const BOSS_INTRO_TIME := 2.4
var last_boss_summary: Dictionary = {}

func is_boss_active() -> bool: return boss != null

## Inicia o Boss (só após M006). Teleport-only + spot lock + intro gate. run_id novo por tentativa (§21).
func start_boss(boss_id: String, skip_intro := false, difficulty := "NORMAL") -> Dictionary:
	if is_active(): return {"ok": false, "reason": "ALREADY_ACTIVE"}
	if not BossActivityDefinition.exists(boss_id): return {"ok": false, "reason": "NO_BOSS"}
	if not golden.boss_available(boss_id): return {"ok": false, "reason": "LOCKED"}
	_run_counter += 1
	active_boss_id = boss_id; boss_failed = false
	# A40 — dificuldade: só aceita as declaradas pelo boss (default NORMAL). Veteran = mais HP/dano/reward.
	active_difficulty = "NORMAL"
	if difficulty in BossActivityDefinition.difficulties_of(boss_id): active_difficulty = difficulty
	active_run_id = "%s#r%d" % [boss_id, _run_counter]
	if gs != null and gs.is_hero_defeated(): gs.reset_hero_hp()
	var caster := _build_caster()
	boss = BossEncounterRuntime.new(); boss.name = "BossEncounter"
	boss.setup(gs, boss_id, caster, active_run_id, active_difficulty)
	boss.hero_died.connect(_on_boss_hero_died)
	boss.boss_defeated.connect(_on_boss_victory)
	add_child(boss)
	# intro: replays podem pular (§12). first-clear roda a intro.
	_boss_intro_done = skip_intro or golden.boss_first_cleared(active_boss_id)
	_boss_intro_t = 0.0
	if _boss_intro_done: boss.complete_intro()
	# teleport + lock + exclusão
	_pre_pos = _player.position if _player != null else Vector2.ZERO
	# ★ mesmo fix da missão: o boss também nascia dentro da Vila (ver `_resolve_combat_anchor`).
	_anchor = _resolve_combat_anchor(str(BossActivityDefinition.get_boss(boss_id).get("map_id", "MAP_PLAINS")))
	if _player != null: _player.position = _anchor; _player.locked = true
	_autoplay_was_on = _main != null and _main.get("_autoplay") != null and bool(_main._autoplay.enabled)
	if _autoplay_was_on: _main._autoplay.set_enabled(false)
	var bdef := BossActivityDefinition.get_boss(boss_id)
	if _main != null and _main.has_method("on_hunt_enter"):
		_main.on_hunt_enter(str(bdef.get("map_id", "MAP_PLAINS")), str(bdef.get("display_name_key", boss_id)), _anchor)
	_now = 0.0; _revive_at = -1.0
	mission_state_changed.emit(true); _set_mission_hud(true); _refresh_ui()
	return {"ok": true, "run_id": active_run_id, "intro": not _boss_intro_done}

func _on_boss_hero_died() -> void:
	# DERROTA (§A19.6): sem reward, sem chapter complete. O encounter congela; o jogador escolhe RETRY/FARM/MELHORAR.
	boss_failed = true

## Vitória do boss (§A19.7): freeze → reward DIRETO garantido (first-clear exact-once) → chapter completion.
func _on_boss_victory() -> void:
	var bdef := BossActivityDefinition.get_boss(active_boss_id)
	var first := golden.mark_boss_cleared(active_boss_id)   # exact-once (também seta CHAPTER_1_COMPLETE)
	var rp: Dictionary = bdef.get("reward_profile", {})
	var _dm := BossActivityDefinition.difficulty_mults(active_boss_id, active_difficulty)
	var rmult := float(_dm["reward_mult"])   # A40 — Veteran paga mais
	last_boss_summary["difficulty"] = active_difficulty
	if first:
		var fc: Dictionary = rp.get("first_clear", {})
		_grant_reward({"xp": int(round(float(int(fc.get("xp", 0))) * rmult)), "gold": int(round(float(int(fc.get("gold", 0))) * rmult))})
		if bool(fc.get("guaranteed_gear_by_weapon", false)) and gs != null:
			var wk := str(gs.current_weapon_type()) if gs.has_method("current_weapon_type") else "sword"
			var gid := BossActivityDefinition.guaranteed_gear_for_weapon(wk)
			# A20.27 — PROTEÇÃO first-clear: trava o item ANTES do settlement ⇒ classify()=PROTECTED ⇒ o AutoSalvage
			# NÃO engole a recompensa garantida antes do jogador ver (§G). O player pode destravar/salvar depois.
			if gs != null and gs.has_method("set_item_locked"): gs.set_item_locked(gid, true)
			if lootmgr != null: lootmgr.receive_loot(gid, 1)
			elif gs != null: gs.backpack_add(gid, 1)
			last_boss_summary["first_clear_item"] = gid; last_boss_summary["first_clear_protected"] = true
	else:
		var rep: Dictionary = rp.get("repeat", {})
		_grant_reward({"xp": int(round(float(int(rep.get("xp", 0))) * rmult)), "gold": int(round(float(int(rep.get("gold", 0))) * rmult))})
	last_boss_summary["victory"] = true; last_boss_summary["first_clear"] = first
	# A27 — chapter_complete do CAPÍTULO DO BOSS (antes usava o default CHAPTER_1_WOLF ⇒ errado p/ Ch2/Ch3).
	last_boss_summary["chapter_complete"] = golden.is_chapter_complete(str(bdef.get("chapter_id", "CHAPTER_1_WOLF")))

## SAIR/limpar o boss (retry/derrota/vitória). Destrava player, restaura cena.
func stop_boss() -> void:
	_free_actors()
	if boss != null: boss.stop(); remove_child(boss); boss.queue_free(); boss = null
	if _player != null: _player.locked = false; _player.position = _pre_pos
	if _autoplay_was_on and _main != null and _main.get("_autoplay") != null: _main._autoplay.set_enabled(true)
	_autoplay_was_on = false
	if _main != null and _main.has_method("on_hunt_exit"): _main.on_hunt_exit()
	mission_state_changed.emit(false); _set_mission_hud(false); _refresh_ui()

## Inicia uma missão (story ou repetível). Valida disponibilidade + dificuldade habilitada + count válido (authority).
func start_mission(mission_id: String, difficulty := "", chosen_count := -1) -> Dictionary:
	if is_active(): return {"ok": false, "reason": "ALREADY_ACTIVE"}
	if not AfkMissionDefinition.exists(mission_id): return {"ok": false, "reason": "NO_MISSION"}
	var def := AfkMissionDefinition.get_mission(mission_id)
	# story: exige disponibilidade na cadeia; repetível: exige o unlock ESPECÍFICO (o mission_id É o nome do unlock —
	# REPEATABLE_WOLF/CRYSTAL/SPIDER; A26 corrige o gate antes hardcoded em REPEATABLE_WOLF, que travava CRYSTAL/SPIDER).
	if bool(def.get("repeatable", false)):
		if not golden.is_unlocked(mission_id): return {"ok": false, "reason": "LOCKED"}
	elif not golden.is_available(mission_id):
		return {"ok": false, "reason": "LOCKED"}
	var diff := difficulty if difficulty != "" else str(def.get("default_difficulty", "NORMAL"))
	if not MissionDifficulty.is_selectable(diff, def.get("available_difficulties", ["NORMAL"])):
		return {"ok": false, "reason": "DIFFICULTY_LOCKED"}
	# caster REAL (as 5 classes). expected_damage do ataque base da arma (aprox. via CombatMath); HP = GameState.
	_run_counter += 1
	active_mission = mission_id; active_difficulty = diff
	active_run_id = "%s#%s#r%d" % [mission_id, diff, _run_counter]
	if gs != null and gs.is_hero_defeated(): gs.reset_hero_hp()
	var caster := _build_caster()
	engine = MissionEngine.new(); engine.name = "MissionEngine"
	engine.setup(gs, lootmgr, mission_id, diff, active_run_id, caster, chosen_count, 18 + _run_counter)
	engine.hero_died.connect(_on_hero_died)
	engine.completed.connect(_on_completed)
	add_child(engine)
	# teleport + lock + exclusão com Progression (movement lock INDEPENDENTE de Auto)
	_pre_pos = _player.position if _player != null else Vector2.ZERO
	# ★★★ FIELD FIX 05/09/2026 — A MISSÃO ACONTECIA DENTRO DA VILA.
	# `Vector2(200, 200)` é coordenada de MUNDO e cai no canto superior-esquerdo de
	# `starter_village` (x 0–2200, y 0–1600). Como o mundo é contínuo, a missão rodava
	# literalmente em cima das casas — foi o "bloco verde com prédios" do screenshot.
	# Agora resolve pelo `map_id` da missão, no CENTRO da região (mesma fonte que a Hunt).
	_anchor = _resolve_combat_anchor(str(def.get("map_id", "MAP_PLAINS")))
	if _player != null: _player.position = _anchor; _player.locked = true
	_autoplay_was_on = _main != null and _main.get("_autoplay") != null and bool(_main._autoplay.enabled)
	if _autoplay_was_on: _main._autoplay.set_enabled(false)
	if _main != null and _main.has_method("on_hunt_enter"):
		_main.on_hunt_enter(str(def.get("map_id", "MAP_PLAINS")), str(def.get("intro_profile", {}).get("title", mission_id)), _anchor)
	_now = 0.0; _revive_at = -1.0
	mission_state_changed.emit(true); _set_mission_hud(true)
	_refresh_ui()
	return {"ok": true, "run_id": active_run_id, "required": engine.required, "difficulty": diff}

## ★ ENTRYPOINT do game loop (Main._process delega aqui). Retorna se a Progressão pode rodar (false enquanto em missão).
func host_process(delta: float) -> bool:
	if boss != null: return _boss_process(delta)
	if engine == null: return true
	if engine.is_completed(): return true
	_now += delta
	# movement lock SEMPRE (independente de AUTO §A18.10)
	if _player != null: _player.locked = true; _player.position = _anchor
	if gs != null and gs.is_hero_defeated():
		if _revive_at < 0.0: _revive_at = _now + REVIVE_DELAY
		elif _now >= _revive_at: _revive_at = -1.0; engine.revive()
		_refresh_ui()
		return false
	# AUTO OFF (§27): PAUSA a missão inteira (herói E mob) — o player não é punido parado. Movement lock permanece.
	if not mission_auto:
		_refresh_ui(); return false
	engine.tick(delta)
	var lm = engine.current_mob()
	_sync_mob_actor(lm, str(lm.mob_id) if lm != null else "young_wolf", delta)   # ator VISÍVEL casado ao mob lógico
	_refresh_ui()
	return false

func _on_hero_died() -> void:
	_revive_at = _now + REVIVE_DELAY

## Loop do Boss (§A19.5): movement lock sempre; intro gate; derrota congela; vitória idle até CONTINUAR.
func _boss_process(delta: float) -> bool:
	_now += delta
	if _player != null: _player.locked = true; _player.position = _anchor   # spot lock, independente de AUTO
	if not _boss_intro_done:
		_boss_intro_t += delta
		if _boss_intro_t >= BOSS_INTRO_TIME: _boss_intro_done = true; boss.complete_intro()
		_refresh_ui(); return false
	if boss_failed: _refresh_ui(); return false   # DERROTA — congelado até RETRY/SAIR (sem reward)
	if not mission_auto: _refresh_ui(); return false   # AUTO OFF pausa a luta do boss também
	boss.tick(delta)
	var bm = boss.boss()
	_sync_mob_actor(bm, active_boss_id, delta)   # ator VISÍVEL do boss
	_refresh_ui()
	return false

## RETRY (§21): nova run, ZERO estado residual (boss HP/fase/cooldown/reward).
func retry_boss() -> Dictionary:
	var bid := active_boss_id
	stop_boss()
	return start_boss(bid)

## Conclusão: concede completion reward EXACT-ONCE (story via GoldenPath; repetível por run) + unlocks.
func _on_completed(summary: Dictionary) -> void:
	last_summary = summary.duplicate(true)
	var def := AfkMissionDefinition.get_mission(active_mission)
	if bool(def.get("repeatable", false)):
		# recompensa por run: escala com o alvo escolhido (mais tempo = mais reward), sem tocar special/kill
		var per: Dictionary = def.get("completion_per_kill", {"xp": 5, "gold": 3})
		_grant_reward({"xp": int(per.get("xp", 0)) * engine.required, "gold": int(per.get("gold", 0)) * engine.required})
	else:
		# story: marca concluída (exact-once) e só então concede
		if golden.complete(active_mission):
			var prof: Dictionary = def.get("completion_reward_profile", {})
			# aplica multiplicador de dificuldade na completion (§A18.7)
			var cm := float(MissionDifficulty.get_tier(active_difficulty).get("completion_mult", 1.0))
			_grant_reward({"xp": int(round(int(prof.get("xp", 0)) * cm)), "gold": int(round(int(prof.get("gold", 0)) * cm)),
				"item": prof.get("item", ""), "material": prof.get("material", {})})
	last_summary["completed_first_time"] = true
	# summary na UI (§A18.18) — itens já liquidados; só apresentação
	if _summary_lbl != null:
		_summary_lbl.text = "MISSÃO CONCLUÍDA\n%s: %d/%d\nEXP +%d  Ouro +%d\nItens %d  Raros+ %d\nMateriais %d  Elite %d\nEspecial %d  Poções? (auto)" % [
			str(def.get("display_name_key", active_mission)), int(summary.get("progress", 0)), int(summary.get("required", 0)),
			int(summary.get("xp", 0)), int(summary.get("gold", 0)), int(summary.get("items", 0)), int(summary.get("rare", 0)),
			int(summary.get("materials", 0)), int(summary.get("elite", 0)), int(summary.get("special", 0))]
		_summary_lbl.visible = true
	if _continue_btn != null: _continue_btn.visible = true
	if _hud != null: _hud.text = ""

func _grant_reward(profile: Dictionary) -> void:
	if gs == null: return
	if int(profile.get("xp", 0)) > 0: gs.add_xp(int(profile["xp"]))
	if int(profile.get("gold", 0)) > 0: gs.add_gold(int(profile["gold"]))
	var item := str(profile.get("item", ""))
	if item != "":
		if lootmgr != null: lootmgr.receive_loot(item, 1)
		else: gs.backpack_add(item, 1)
	var mat: Dictionary = profile.get("material", {})
	if not mat.is_empty(): gs.add_material(str(mat.get("name", "")), int(mat.get("qty", 1)))

## Encerra a missão (SAIR ou pós-conclusão): destrava o player, restaura cenário/câmera, religa AutoPlay.
func stop_mission() -> void:
	_free_actors()
	if engine != null:
		engine.stop(); remove_child(engine); engine.queue_free(); engine = null
	if _player != null: _player.locked = false; _player.position = _pre_pos
	if _autoplay_was_on and _main != null and _main.get("_autoplay") != null: _main._autoplay.set_enabled(true)
	_autoplay_was_on = false
	if _main != null and _main.has_method("on_hunt_exit"): _main.on_hunt_exit()
	mission_state_changed.emit(false); _set_mission_hud(false)
	_refresh_ui()

## A19.1/A19.10 — passo de PREPARAÇÃO de build entre M006 e o Boss. CP REAL (PowerBudget, sem bônus fake §32) vs
## recomendado; NÃO bloqueia (§4 — pode tentar). Opções: ENFRENTAR/FARMAR/MELHORAR/EQUIPAMENTO. Reusa sistemas
## existentes (equip/refine) — não cria crafting novo.
func build_prep_info(boss_id := "BOSS_WOLF_ALPHA") -> Dictionary:
	var bdef := BossActivityDefinition.get_boss(boss_id)
	var cur := PowerBudget.cp()
	var rec := int(bdef.get("recommended_cp", 0))
	return {"current_cp": cur, "recommended_cp": rec, "can_attempt": golden.boss_available(boss_id),
		"under_recommended": cur < rec, "options": ["ENFRENTAR", "FARMAR", "MELHORAR", "EQUIPAMENTO"],
		"first_cleared": golden.boss_first_cleared(boss_id), "chapter_complete": golden.is_chapter_complete()}

func debug_state() -> Dictionary:
	var d := {"active": is_active(), "mission": active_mission, "difficulty": active_difficulty, "run_id": active_run_id}
	if engine != null:
		d["progress"] = engine.progress; d["required"] = engine.required; d["objective"] = engine.objective
		d["kills"] = int(engine.stats["kills"]); d["completed"] = engine.is_completed()
		if gs != null: d["hp"] = int(gs.hero_hp); d["max_hp"] = int(gs.max_hp_total())
	return d

func _build_caster() -> Dictionary:
	var cls: String = str(gs.character_class) if gs != null else "LEGACY_CLASS"
	# dano esperado ≈ ataque base da arma equipada (via CombatMath), coerente com a Progressão; HP = GameState real.
	var arch: String = str(gs.current_combat_archetype()) if gs != null and gs.has_method("current_combat_archetype") else "melee"
	var prof: Dictionary = CombatMath.player_profile(arch)
	# poder REAL (§32 sem bônus fake): dano base do arquétipo + ATAQUE do equipamento (equip_sum). HP = max_hp_total
	# (também reflete gear/jóias). Assim gear/refino MUDAM o desempenho contra o Boss (§4/BUILDLOOP).
	var atk_bonus: int = int(gs.attack_bonus()) if gs != null and gs.has_method("attack_bonus") else 0
	var exp_dmg: float = float(prof.get("expected", 20.0)) + float(atk_bonus)
	var mhp: int = maxi(50, int(gs.max_hp_total())) if gs != null else 100
	return {"class_id": cls, "expected_damage": exp_dmg, "max_hp": mhp, "current_hp": mhp, "shield": 0, "alive": true}
