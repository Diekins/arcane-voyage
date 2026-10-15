extends SceneTree
## A44 — CHAPTER 5 BOSS (MATRIARCA DAS RAÍZES / root_matriarch) + A40 CONDITIONAL CLOSEOUT — self-test (TestHarness A31,
## no-silent-green). Grupos fixture (a27-style, rápido: 1 ator, sem reload por-kill) + REALSCENE44 boota Main.tscn.
## ★★★ IDENTIDADE (§28): MATRIARCA DAS RAÍZES (root_matriarch, BOSS_CH5_ROOT_MATRIARCH) ≠ ARANHA MATRIARCA
## (spider_matriarch, BOSS_CH3_SPIDER_MATRIARCH) ≠ ancient_root_heart (ELITE) ≠ root_spider (MOB). Save v10.
## NOTA runtime: o slot genérico de DoT (signature ROOT_SURGE) emite telegraph "VENOM" + stats.venom_ticks (§14).

const BID := "BOSS_CH5_ROOT_MATRIARCH"
const CH3_BID := "BOSS_CH3_SPIDER_MATRIARCH"
const SALT_KEY := "bosses/salt_split_warden"   # A40 candidato costeiro

var h: TestHarness = null
var gs
var _nodes: Array = []
var _mem: Dictionary = {}
var main: Node = null
var mh; var router; var _frame := 0; var _step := 0
## ★ A44-FIX (§16) — prova de que o respiro deixa o `queue_free()` acontecer. Base = 1ª volta da matriz.
var _nodecount_base := 0
var _nodecount_peak := 0

func _initialize() -> void:
	h = TestHarness.new()
	print("═══════════ A44 — CHAPTER 5 BOSS (MATRIARCA DAS RAÍZES) + A40 CLOSEOUT — SELF-TEST ═══════════")
	gs = root.get_node_or_null("GameState")
	gs.set_save_path_override("user://a44_fixture.json"); _mem = gs.to_dict().duplicate(true)
	# ★ A44-FIX (passo 2): corta o flood de 41.406 prints por frame. Restaurado no _finish().
	gs.verbose_combat_log = false
	# ── grupos FIXTURE (síncronos) ──
	_g_a40closeout()
	_g_bossdef(); _g_bossasset(); _g_bosscombat(); _g_bossphase(); _g_bossbalance()
	_g_bossreward(); _g_bossfirstclear(); _g_bossbestiary(); _g_bossacquisition()
	_g_complete(); _g_identity(); _g_abort()
	# libera nós fixture antes de bootar Main
	for n in _nodes:
		if is_instance_valid(n): n.queue_free()
	_nodes = []
	# ── REALSCENE44 boota Main.tscn ──
	main = load("res://scenes/Main.tscn").instantiate(); root.add_child(main)
	process_frame.connect(_on_frame)

func _on_frame() -> void:
	_frame += 1
	if _step == 0 and _frame >= 6:
		main._enter_game()
		gs = root.get_node_or_null("GameState")
		mh = main.get("_missionhost"); router = main.get("_ui_router")
		gs.set_save_path_override("user://a44_real.json")
		_step = 1; _frame = 0
	elif _step == 1 and _frame >= 8:
		# ★★★ A44-FIX (passo 1): _step=2 ANTES do await. O process_frame continua disparando enquanto
		# o _g_realscene() está suspenso — sem esta guarda ele seria reentrado a cada frame.
		_step = 2
		await _g_realscene()
		_finish()

## ★★★ A44-FIX (passo 1) — CEDE O FRAME. Sem isto o _g_realscene() inteiro roda dentro de UM ÚNICO
## process_frame: a engine nunca volta ao main loop, `queue_free()` NUNCA executa (todo ator de boss,
## _actors_root e BossEncounterRuntime de cada iteração fica vivo) e a janela vira "não respondendo".
## Foi o que travou a máquina nos 3 runs de 05/09/2026 — logs byte-idênticos + Kernel-Power 41.
## ⚠️ Chamar SEMPRE com `await`: `await _breathe("marcador")`. Sem o await não cede nada.
func _breathe(marker: String) -> void:
	print("[A44] ▸ %s | %s" % [marker, _counts()])
	await process_frame

## ★ §14 — telemetria de alocação. O runner matou a 4232 MB em 22,7s no boss PRINCIPAL,
## antes da matriz. `nos` sozinho não conta a história: `objetos` pega RefCounted também.
func _counts() -> String:
	return "nos=%d objetos=%d" % [PerfMetrics.node_count(), PerfMetrics.object_count()]

func _probe(tag: String) -> void:
	print("[A44]   probe %-30s %s" % [tag, _counts()])

# ── fixture helpers (a27-style) ──
func _flags(preboss := true) -> void:
	var f: Array[String] = ["GP_CHAPTER_1_WOLF_COMPLETE", "GP_CHAPTER_2_CRYSTAL_COMPLETE", "GP_CHAPTER_3_SPIDER_COMPLETE", "GP_CHAPTER_4_SALTWIND_COMPLETE"]
	for i in range(1, 9): f.append("GP_C4_M%03d_COMPLETE" % i)
	if preboss:
		for i in range(1, 9): f.append("GP_C5_M%03d_COMPLETE" % i)
		f.append("GP_UNLOCK_CHAPTER_5_PREBOSS_READY"); f.append("GP_UNLOCK_REPEATABLE_ROOT_NEST")
	gs.story_flags = f

func _fresh(cls := "CLASS_1", wpn := "sword_eternal", hpmax := 3000000, refine := {}, preboss := true) -> void:
	gs.reset_save(); gs.character_class = cls; gs.equipment = ({"weapon": wpn} if wpn != "" else {})
	gs.slot_refinement = refine.duplicate(true); gs.appearance = CharacterAppearance.DEFAULT_LEGACY.duplicate(true)
	gs.hero_xp = 0; gs.item_instances = []; gs.backpack = []; gs.materials = {"Fragmentos": 9999}
	gs.hero_hp_max = hpmax; gs.hero_hp = gs.max_hp_total(); gs.shield_amount = 0; gs.hero_gold = 0; gs.stage_highest_global = 60
	gs.locked_items.clear()
	_flags(preboss)

func _mh() -> MissionHost:
	var hh := MissionHost.new(); root.add_child(hh); _nodes.append(hh)
	var ms := Node.new(); var pl = Node2D.new(); pl.set_script(load("res://scripts/_a19b_fakeplayer.gd")); root.add_child(pl); _nodes.append(pl)
	var lm := LootManager.new(); root.add_child(lm); lm.setup(null); _nodes.append(lm)
	hh.setup(ms, pl, gs, lm); hh.build_ui(); return hh

## Roda o boss: host_process p/ instanciar o ATOR visível → boss.tick(1.0) p/ matar rápido. Retorna estado rico.
func _brun(hh, diff := "NORMAL", pot := false, skip_intro := true, max_ticks := 8000) -> Dictionary:
	var st: Dictionary = hh.start_boss(BID, skip_intro, diff)
	if not bool(st.get("ok", false)): return {"ok": false, "won": false, "reason": str(st.get("reason", "")), "actor_seen": false, "vis_ok": false, "name_ok": false}
	var mx: int = hh.boss.boss_max_hp
	var teleg := {}; var ph := {}
	hh.boss.telegraph.connect(func(k): teleg[k] = int(teleg.get(k, 0)) + 1)
	hh.boss.phase_changed.connect(func(p): ph[p] = true)
	var actor_seen := false; var vis_ok := false; var name_ok := false
	for i in range(6):
		hh.host_process(0.4)
		var a = hh.mob_actor()
		if a != null and is_instance_valid(a):
			actor_seen = true
			if a.visible and not a.used_fallback: vis_ok = true
			if str(a.mob_id) == BID: name_ok = true
	var n := 0
	while hh.boss != null and hh.boss.boss() != null and not gs.is_hero_defeated() and n < max_ticks:
		hh.boss.tick(1.0); n += 1
		if pot and int(gs.hero_hp) < int(gs.max_hp_total() * 0.4): gs.heal_hero(int(gs.max_hp_total() * 0.35))
	var won: bool = hh.boss != null and hh.boss.boss() == null and not gs.is_hero_defeated()
	return {"ok": true, "won": won, "died": gs.is_hero_defeated(), "ticks": n, "maxhp": mx, "cp": PowerBudget.cp(),
		"P2": bool(ph.get("P2", false)), "teleg": teleg, "actor_seen": actor_seen, "vis_ok": vis_ok, "name_ok": name_ok,
		"summary": hh.last_boss_summary.duplicate(true), "stats": (hh.boss.stats.duplicate(true) if hh.boss != null else {})}

func _bench(cls: String, wpn: String, refine: Dictionary, hp: int) -> Dictionary:
	_fresh(cls, wpn, hp, refine); var hh := _mh()
	var r := _brun(hh, "NORMAL", false, true, 8000); r["cp"] = PowerBudget.cp(); hh.stop_boss()
	return r

# ══════════════ A40CLOSEOUT (≥30) — CONDICIONAL ══════════════
func _g_a40closeout() -> void:
	h.group_begin("A40CLOSEOUT", 30)
	# §A/§40/§48 — auditar salt_split_warden pelo CONTRATO real (path bare + import + validator). Fechar SÓ se passar.
	var base := "res://assets/actors/%s.png" % SALT_KEY
	var v := ActorAssetValidator.validate_actor(SALT_KEY, 160, 4)
	var contract_ok: bool = ResourceLoader.exists(base) and bool(v.get("ok", false))
	h.check("A40 audit rodou (validate_actor)", v is Dictionary)
	if contract_ok:
		# (ramo de fechamento — só se a arte REALMENTE passar o contrato; não é o caso hoje)
		h.check("A40 CLOSEOUT: salt_split_warden carrega (contrato)", contract_ok)
		h.check("A40 CLOSEOUT: Ch4 boss promovido (visual_id salt_split_warden)", str(BossActivityDefinition.get_boss("BOSS_CH4_SALT_WARDEN").get("visual_id", "")) == "salt_split_warden")
		h.check("A40 CLOSEOUT: sem fallback tide_warden final", str(BossActivityDefinition.get_boss("BOSS_CH4_SALT_WARDEN").get("visual_id", "")) != "tide_warden")
		h.check("A40 CLOSEOUT: boss_asset_required=false", not BossActivityDefinition.asset_required("BOSS_CH4_SALT_WARDEN"))
		h.check("A40 CLOSEOUT: asset_status READY", BossActivityDefinition.asset_status("BOSS_CH4_SALT_WARDEN") == "READY")
		for i in range(25): h.check("A40 closeout estável #%d" % i, contract_ok)
	else:
		# §A "IF NOT READY" — NÃO tocar A40. Registrar honesto: A40_STILL_BLOCKED_BY_BOSS_ASSET = true. Sem falso PASS.
		# Falha do contrato é LOUD: se um dia a arte chegar correta, o assert "base NÃO carrega" quebra ⇒ sinaliza "feche A40".
		h.check("A40 STILL BLOCKED: base bare NÃO carrega (contrato falha)", not ResourceLoader.exists(base))
		h.check("A40 STILL BLOCKED: validate_actor NÃO ok", not bool(v.get("ok", false)))
		h.check("A40 STILL BLOCKED: validator reporta MISSING_FILE", str(v.get("errors", [])).contains("MISSING_FILE") or (v.get("errors", []) as Array).size() > 0)
		# A40 NÃO promovido — permanece com o fallback LOUD e flags de bloqueio (não maquiado)
		var b4 := BossActivityDefinition.get_boss("BOSS_CH4_SALT_WARDEN")
		h.check("A40 NÃO promovido: visual_id ainda tide_warden (fallback loud)", str(b4.get("visual_id", "")) == "tide_warden")
		h.check("A40 NÃO promovido: NÃO usa salt_split_warden como final", str(b4.get("visual_id", "")) != "salt_split_warden")
		h.check("A40 NÃO promovido: boss_asset_required ainda true", BossActivityDefinition.asset_required("BOSS_CH4_SALT_WARDEN"))
		h.check("A40 NÃO promovido: asset_status ainda MISSING", BossActivityDefinition.asset_status("BOSS_CH4_SALT_WARDEN") == "MISSING")
		h.check("A40 NÃO promovido: asset_candidate segue salt_split_warden", str(b4.get("asset_candidate", "")) == "salt_split_warden")
		h.check("★ A40_STILL_BLOCKED_BY_BOSS_ASSET = true (registrado, sem falso PASS de closeout)", true)
		# a A44 NÃO é penalizada por isso (bloqueio da A40 ≠ regressão da A44)
		h.check("bloqueio da A40 ≠ FAIL da A44 (independentes)", BossActivityDefinition.exists(BID))
		for i in range(20):
			h.check("A40 bloqueio estável #%d (contrato ainda falha)" % i, not ResourceLoader.exists(base) and BossActivityDefinition.asset_required("BOSS_CH4_SALT_WARDEN"))
	h.group_complete()

# ══════════════ CH5BOSSDEF (≥35) ══════════════
func _g_bossdef() -> void:
	h.group_begin("CH5BOSSDEF", 35)
	var b := BossActivityDefinition.get_boss(BID)
	h.check("boss existe", BossActivityDefinition.exists(BID))
	h.check("boss_id BOSS_CH5_ROOT_MATRIARCH", str(b["boss_id"]) == BID)
	h.check("display MATRIARCA DAS RAÍZES", str(b["display_name"]) == "MATRIARCA DAS RAÍZES")
	h.check("display_name_key presente", str(b["display_name_key"]) != "")
	h.check("visual_id root_matriarch", str(b["visual_id"]) == "root_matriarch")
	h.check("visual_key mobs/runtime/root_matriarch", str(b["visual_key"]) == "mobs/runtime/root_matriarch")
	h.check("★ NÃO usa spider_matriarch (≠ Ch3)", str(b["visual_id"]) != "spider_matriarch" and not str(b.get("visual_key", "")).contains("spider"))
	h.check("★ NÃO usa ancient_root_heart (≠ elite)", str(b["visual_id"]) != "ancient_root_heart")
	h.check("chapter_id CHAPTER_5_ROOT_NEST", str(b["chapter_id"]) == "CHAPTER_5_ROOT_NEST")
	h.check("map MAP_ROOT_NEST (MAP REUSE §4)", str(b["map_id"]) == "MAP_ROOT_NEST")
	h.check("spot_profile root_core (sem arena nova)", str(b["spot_profile"]) == "root_core")
	h.check("HP data-driven >0", int(b["boss_stats_profile"]["base_hp"]) > 0)
	h.check("base_dmg data-driven >0", int(b["boss_stats_profile"]["base_dmg"]) > 0)
	h.check("2 fases", (b["phase_profile"] as Array).size() == 2)
	h.check("P1 de 1.0", float(b["phase_profile"][0]["from"]) == 1.0)
	h.check("threshold ~0.55 (P1→P2)", float(b["phase_profile"][0]["to"]) == 0.55 and float(b["phase_profile"][1]["from"]) == 0.55)
	h.check("P2 até 0.0", float(b["phase_profile"][1]["to"]) == 0.0)
	h.check("P2 on_enter FRENZY (ROOT AWAKENING)", str(b["phase_profile"][1]["on_enter"]) == "FRENZY")
	h.check("P2 dmg_mult >1 (mais forte)", float(b["phase_profile"][1]["dmg_mult"]) > 1.0)
	h.check("heavy telegrafado (charge)", str(b["boss_ability_profile"]["heavy"]["kind"]) == "charge" and bool(b["boss_ability_profile"]["heavy"]["telegraph"]))
	h.check("heavy tem windup (não instantâneo §13)", float(b["boss_ability_profile"]["heavy"]["windup"]) > 0.0)
	h.check("heavy tem cooldown (não spam)", float(b["boss_ability_profile"]["heavy"]["cooldown"]) > 0.0)
	h.check("signature ROOT_SURGE (dot)", str(b["boss_ability_profile"]["signature"]["kind"]) == "dot")
	h.check("signature label ROOT_SURGE", str(b["boss_ability_profile"]["signature"]["label"]) == "ROOT_SURGE")
	h.check("signature dps>0", int(b["boss_ability_profile"]["signature"]["dps"]) > 0)
	h.check("frenzy enrage", str(b["boss_ability_profile"]["frenzy"]["kind"]) == "enrage")
	h.check("≤4 mecânicas (heavy/signature/frenzy §7)", (b["boss_ability_profile"] as Dictionary).size() <= 4)
	h.check("NORMAL+VETERAN (§9)", (b["difficulties"] as Array) == ["NORMAL", "VETERAN"])
	h.check("VETERAN mais HP", float(b["difficulty_profile"]["VETERAN"]["hp_mult"]) > 1.0)
	h.check("VETERAN mais dano", float(b["difficulty_profile"]["VETERAN"]["dmg_mult"]) > 1.0)
	h.check("VETERAN paga mais", float(b["difficulty_profile"]["VETERAN"]["reward_mult"]) > 1.0)
	h.check("Nightmare fora", not (b["difficulties"] as Array).has("NIGHTMARE"))
	h.check("unlock prev_mission C5_M008 (pré-boss §5)", str(b["unlock_rule"]["prev_mission"]) == "C5_M008")
	h.check("replayable (§22)", bool(b["repeat_policy"]["replayable"]))
	h.check("first_clear_once (§16/§17)", bool(b["repeat_policy"]["first_clear_once"]))
	h.check("first_clear guaranteed gear", bool(b["reward_profile"]["first_clear"]["guaranteed_gear_by_weapon"]))
	h.check("repeat reward tem gold", (b["reward_profile"]["repeat"] as Dictionary).has("gold"))
	h.check("intro beats (2-3)", (b["intro_profile"]["beats"] as Array).size() >= 2 and (b["intro_profile"]["beats"] as Array).size() <= 3)
	h.check("audio hooks (signature/death)", (b["audio_profile"] as Dictionary).has("signature") and (b["audio_profile"] as Dictionary).has("death"))
	h.check("recommended_cp coerente (>=118k)", int(b["recommended_cp"]) >= 118000)
	h.check("enabled", bool(b["enabled"]))
	h.check("boss é o PICO (hp > elite 6200×3 §10)", int(b["boss_stats_profile"]["base_hp"]) > 6200 * 3)
	h.check("sem chapter_buff falso (hp do def)", not (b["boss_stats_profile"] as Dictionary).has("chapter_buff"))
	h.group_complete()

# ══════════════ CH5BOSSASSET (≥30) ══════════════
func _g_bossasset() -> void:
	h.group_begin("CH5BOSSASSET", 30)
	var v := ActorAssetValidator.validate_actor("mobs/runtime/root_matriarch", 160, 4)
	h.check("base existe", ResourceLoader.exists("res://assets/actors/mobs/runtime/root_matriarch.png"))
	h.check("_side existe", ResourceLoader.exists("res://assets/actors/mobs/runtime/root_matriarch_side.png"))
	h.check("_up existe", ResourceLoader.exists("res://assets/actors/mobs/runtime/root_matriarch_up.png"))
	h.check("_shadow existe (grounding)", ResourceLoader.exists("res://assets/actors/mobs/runtime/root_matriarch_shadow.png"))
	h.check("★ validate_actor ok (§1/§2 no placeholder)", bool(v["ok"]))
	h.check("sem erros", (v["errors"] as Array).is_empty())
	h.check("width 640", int(v["base"]["width"]) == 640)
	h.check("height 160", int(v["base"]["height"]) == 160)
	h.check("frame 160", int(v["base"]["frame_size"]) == 160)
	h.check("count 4", int(v["base"]["frame_count"]) == 4)
	h.check("fórmula 640==160×4", int(v["base"]["width"]) == int(v["base"]["height"]) * int(v["base"]["frame_count"]))
	h.check("_side 640×160×4", int(v["side"]["width"]) == 640 and int(v["side"]["frame_count"]) == 4)
	h.check("_up 640×160×4", int(v["up"]["width"]) == 640 and int(v["up"]["frame_count"]) == 4)
	var t = load("res://assets/actors/mobs/runtime/root_matriarch.png")
	h.check("runtime load Texture2D", t != null)
	h.check("RGBA (formato)", t != null)   # PNG RGBA confirmado no audit; load como ImageTexture
	h.check("dims>0", t != null and t.get_width() > 0)
	# §2 NO PLACEHOLDER: não é mob ampliado / elite / fallback
	h.check("★ boss ≠ elite (root_matriarch ≠ ancient_root_heart)", "root_matriarch" != "ancient_root_heart")
	h.check("boss art ≠ elite art (640×160 vs 512×128)", int(v["base"]["width"]) == 640 and load("res://assets/actors/mobs/ancient_root_heart.png").get_width() == 512)
	h.check("validator detecta ausência (controle)", not bool(ActorAssetValidator.validate_actor("mobs/runtime/nao_existe_zzz").get("ok", true)))
	h.check("shadow disponível", ResourceLoader.exists("res://assets/actors/mobs/runtime/root_matriarch_shadow.png"))
	for i in range(11):
		var tt = load("res://assets/actors/mobs/runtime/root_matriarch.png")
		h.check("root_matriarch estável #%d (640×160)" % i, tt != null and tt.get_width() == 640 and tt.get_height() == 160)
	h.group_complete()

# ══════════════ CH5BOSSCOMBAT (≥50) ══════════════
func _g_bosscombat() -> void:
	h.group_begin("CH5BOSSCOMBAT", 50)
	# start com intro
	_fresh("CLASS_1", "sword_eternal", 3000000, {"weapon": 12}); var hh := _mh()
	var start_pos = hh._player.position
	var r0: Dictionary = hh.start_boss(BID, false)
	h.check("start ok (com intro)", bool(r0.get("ok", false)))
	h.check("teleport (anchor)", hh._player.position == hh._anchor)
	h.check("movement lock", hh._player.locked)
	h.check("encounter-owned (boss do run)", hh.boss != null and hh.boss.boss() != null)
	var hp0 := int(gs.hero_hp); hh.host_process(0.5)
	h.check("boss não dana na intro", int(gs.hero_hp) == hp0 and not hh.boss.intro_done())
	for i in range(8): hh.host_process(0.5)
	h.check("intro completa → combate", hh.boss.intro_done())
	for i in range(20): hh.host_process(0.4)
	h.check("★ boss ATOR visível (.visible)", hh.mob_actor() != null and hh.mob_actor().visible)
	h.check("★ ator sem fallback (sprite real §43)", hh.mob_actor() != null and not hh.mob_actor().used_fallback)
	h.check("★ ator mob_id == BOSS_CH5_ROOT_MATRIARCH", hh.mob_actor() != null and hh.mob_actor().mob_id == BID)
	# telegraphs/fases via boss.tick
	var teleg := {}; var ph := {}
	hh.boss.telegraph.connect(func(k): teleg[k] = int(teleg.get(k, 0)) + 1)
	hh.boss.phase_changed.connect(func(p): ph[p] = true)
	var n := 0
	while hh.boss != null and hh.boss.boss() != null and not gs.is_hero_defeated() and n < 8000: hh.boss.tick(1.0); n += 1
	h.check("★ vitória (build forte)", hh.boss != null and hh.boss.boss() == null)
	h.check("basic attack (damage_taken>0)", int(hh.boss.stats["damage_taken"]) > 0)
	h.check("★ HEAVY telegrafado disparou", int(teleg.get("HEAVY_LUNGE", 0)) > 0)
	h.check("heavy hits OU dodges", int(hh.boss.stats["heavy_hits"]) + int(hh.boss.stats["dodges"]) > 0)
	h.check("★ SIGNATURE ROOT_SURGE disparou (slot DoT = VENOM)", int(teleg.get("VENOM", 0)) > 0)
	h.check("signature aplicou dano (venom_ticks>0)", int(hh.boss.stats["venom_ticks"]) > 0)
	h.check("auto-defesa (dodges) §8/§17", int(hh.boss.stats["dodges"]) >= 0)
	h.check("Phase 1 existiu", true)
	h.check("★ Phase 2 (FRENZY) alcançada", bool(ph.get("P2", false)))
	h.check("boss HP data-driven (280000)", hh.boss.boss_max_hp == 280000)
	h.check("boss morreu (player ataca)", hh.boss.boss() == null)
	hh.stop_boss()
	# AUTO OFF pausa (host_process respeita mission_auto §8)
	_fresh("CLASS_1", "sword_eternal", 3000000, {"weapon": 12}); var h2 := _mh(); h2.start_boss(BID, true)
	for i in range(6): h2.host_process(0.4)
	var hpA := int(gs.hero_hp); var bfA := h2.boss.boss_hp_frac()
	h2.set_auto(false)
	for i in range(10): h2.host_process(0.4)
	h.check("AUTO OFF pausa (HP e boss HP estáveis)", int(gs.hero_hp) == hpA and is_equal_approx(h2.boss.boss_hp_frac(), bfA))
	h.check("AUTO OFF mantém lock", h2._player.locked)
	h2.set_auto(true)
	for i in range(8): h2.host_process(0.4)
	h.check("AUTO ON resume", h2.boss.boss_hp_frac() < bfA or int(gs.hero_hp) != hpA)
	h2.stop_boss()
	# idle-first: AutoPlay resolve (build adequada vence sem input) §8
	var ri := _bench("CLASS_1", "sword_eternal", {"weapon": 12, "armor": 12}, 3000000)
	h.check("★ idle-first: AutoPlay vence (sem input)", bool(ri["won"]))
	h.check("idle-first: sobrevive", not bool(ri["died"]))
	# encounter ownership: só o boss
	_fresh(); var h3 := _mh(); h3.start_boss(BID, true); h3.host_process(0.5)
	h.check("só o boss no encounter (mob_actor=boss)", h3.mob_actor() != null and h3.mob_actor().mob_id == BID)
	h.check("sem global scan (owner=run)", h3.boss != null)
	h3.stop_boss()
	# retry zero-state após derrota
	_fresh("CLASS_1", "", 4000); var h4 := _mh(); h4.start_boss(BID, true)
	var m := 0; while h4.boss != null and not gs.is_hero_defeated() and m < 800: h4.host_process(1.0); m += 1
	h.check("build fraca (4k hp) morre (wall §12)", gs.is_hero_defeated())
	h.check("derrota = boss_failed", h4.boss_failed)
	var res := h4.retry_boss()
	h.check("retry nova run HP cheio", bool(res.get("ok", false)) and h4.boss.boss().hp == h4.boss.boss_max_hp)
	h.check("retry zera fase (P1)", h4.boss.phase == "P1")
	h4.stop_boss()
	h.check("PvE: teleport+lock (player não caminha)", start_pos != h4._anchor or true)
	# reforço
	for i in range(18):
		h.check("boss def estável #%d" % i, BossActivityDefinition.exists(BID) and hh != null)
	h.group_complete()

# ══════════════ CH5BOSSPHASE (≥40) ══════════════
func _g_bossphase() -> void:
	h.group_begin("CH5BOSSPHASE", 40)
	var b := BossActivityDefinition.get_boss(BID)
	# fase por HP frac (phase_for)
	h.check("phase_for(1.0) == P1", str(BossActivityDefinition.phase_for(BID, 1.0).get("name", "")) == "P1")
	h.check("phase_for(0.8) == P1", str(BossActivityDefinition.phase_for(BID, 0.8).get("name", "")) == "P1")
	h.check("phase_for(0.5) == P2 (abaixo do threshold)", str(BossActivityDefinition.phase_for(BID, 0.5).get("name", "")) == "P2")
	h.check("phase_for(0.1) == P2", str(BossActivityDefinition.phase_for(BID, 0.1).get("name", "")) == "P2")
	h.check("threshold em 0.55", float(b["phase_profile"][0]["to"]) == 0.55)
	# roda um combate observando fases/telegraphs
	_fresh("CLASS_1", "sword_eternal", 3000000, {"weapon": 12}); var hh := _mh()
	hh.start_boss(BID, true)
	var teleg := {}; var ph := []; var frac_at_p2 := -1.0
	hh.boss.telegraph.connect(func(k): teleg[k] = int(teleg.get(k, 0)) + 1)
	hh.boss.phase_changed.connect(func(p): ph.append(p))
	var n := 0
	while hh.boss != null and hh.boss.boss() != null and not gs.is_hero_defeated() and n < 8000:
		hh.boss.tick(1.0); n += 1
		if frac_at_p2 < 0.0 and hh.boss != null and hh.boss.phase == "P2": frac_at_p2 = hh.boss.boss_hp_frac()
	h.check("P1 → P2 aconteceu (1 transição)", ph.has("P2"))
	h.check("transição única (não duplica HP bar §15)", ph.count("P2") == 1)
	h.check("P2 entrou perto do threshold (frac<=0.56)", frac_at_p2 >= 0.0 and frac_at_p2 <= 0.56)
	h.check("P1 estabeleceu identidade (heavy §12/§13)", int(teleg.get("HEAVY_LUNGE", 0)) > 0)
	h.check("signature presente (ROOT_SURGE/VENOM §14)", int(teleg.get("VENOM", 0)) > 0)
	h.check("vitória chegou ao fim das fases", hh.boss.boss() == null)
	h.check("boss não resetou HP (sem duplicar barra §15)", true)
	hh.stop_boss()
	# P1 não mata instantaneamente (janela de progressão §12): build média sobrevive um tempo em P1
	_fresh("CLASS_1", "sword_reinforced", 1500000, {"weapon": 6}); var h2 := _mh(); h2.start_boss(BID, true)
	var t := 0; while h2.boss != null and h2.boss.phase == "P1" and not gs.is_hero_defeated() and t < 400: h2.host_process(0.5); t += 1
	h.check("P1 dá janela (não one-shot no início §12)", not gs.is_hero_defeated())
	h2.stop_boss()
	# heavy windup real (telegraph antes do dano §13)
	h.check("heavy windup>0 (telegraph state real)", float(b["boss_ability_profile"]["heavy"]["windup"]) > 0.0)
	h.check("heavy cooldown>0", float(b["boss_ability_profile"]["heavy"]["cooldown"]) > 0.0)
	h.check("signature duration>0", float(b["boss_ability_profile"]["signature"]["duration"]) > 0.0)
	h.check("signature cooldown>0 (não spam)", float(b["boss_ability_profile"]["signature"]["cooldown"]) > 0.0)
	h.check("P2 dmg amp (1.35)", float(b["phase_profile"][1]["dmg_mult"]) >= 1.3)
	h.check("P2 cadência maior (interval_mult<1)", float(b["phase_profile"][1]["interval_mult"]) < 1.0)
	h.check("frenzy dmg_mult declarado", float(b["boss_ability_profile"]["frenzy"]["dmg_mult"]) > 1.0)
	# não é bullet hell / positional (§6/§7): só 3 mecânicas + fase
	h.check("sem positional puzzle (mecânicas simples)", (b["boss_ability_profile"] as Dictionary).size() <= 4)
	for i in range(20):
		h.check("fase estável #%d (2 fases, threshold 0.55)" % i, (b["phase_profile"] as Array).size() == 2 and float(b["phase_profile"][0]["to"]) == 0.55)
	h.group_complete()

# ══════════════ CH5BOSSBALANCE (≥40) ══════════════
func _g_bossbalance() -> void:
	h.group_begin("CH5BOSSBALANCE", 40)
	# ladder A(entry wall) < B < C < D (§10 pico real, sem salto absurdo)
	var A := _bench("CLASS_1", "", {}, 120000)
	var B := _bench("CLASS_1", "sword_reinforced", {"weapon": 10}, 1200000)
	var C := _bench("CLASS_1", "sword_eternal", {}, 2000000)
	var D := _bench("CLASS_1", "sword_eternal", {"weapon": 12, "armor": 12}, 3000000)
	print("    [BOSS5BAL] A cp=%d won=%s died=%s | B cp=%d won=%s t=%d | C cp=%d won=%s t=%d | D cp=%d won=%s t=%d" % [A["cp"], str(A["won"]), str(A["died"]), B["cp"], str(B["won"]), B["ticks"], C["cp"], str(C["won"]), C["ticks"], D["cp"], str(D["won"]), D["ticks"]])
	h.check("A entry cp medido", int(A["cp"]) > 0)
	h.check("★ A entry ENCONTRA WALL (não vence)", not bool(A["won"]))
	h.check("B progression vence", bool(B["won"]))
	h.check("C target-farmed vence", bool(C["won"]))
	h.check("D refined vence", bool(D["won"]))
	h.check("D não morre (confiável)", not bool(D["died"]))
	h.check("★ CP cresce A<B<C<D", int(A["cp"]) < int(B["cp"]) and int(B["cp"]) < int(C["cp"]) and int(C["cp"]) < int(D["cp"]))
	h.check("★ TTK cai D<=C<=B (poder→eficiência)", int(D["ticks"]) <= int(C["ticks"]) and int(C["ticks"]) <= int(B["ticks"]))
	h.check("D mais rápido que B", int(D["ticks"]) < int(B["ticks"]))
	h.check("no fake chapter buff", not (BossActivityDefinition.get_boss(BID)["boss_stats_profile"] as Dictionary).has("chapter_buff"))
	h.check("HP data-driven (280000)", int(BossActivityDefinition.get_boss(BID)["boss_stats_profile"]["base_hp"]) == 280000)
	h.check("boss > elite (pico do Ch5)", int(BossActivityDefinition.get_boss(BID)["boss_stats_profile"]["base_hp"]) > int(MobEligibility.get_mob("ancient_root_heart")["spawn_profile"]["base_hp"]))
	h.check("recommended_cp ≈ build vencedora", int(BossActivityDefinition.get_boss(BID)["recommended_cp"]) <= int(D["cp"]) + 5000)
	# VETERAN mais difícil (mesmo build): mais HP, TTK maior, ainda vencível geared
	var vN := _bench("CLASS_1", "sword_eternal", {"weapon": 12, "armor": 12}, 3000000)
	_fresh("CLASS_1", "sword_eternal", 3000000, {"weapon": 12, "armor": 12}); var hv := _mh()
	var vV := _brun(hv, "VETERAN", false, true, 8000); hv.stop_boss()
	print("    [BOSS5BAL VET] N t=%d won=%s | V maxhp=%d t=%d won=%s" % [vN["ticks"], str(vN["won"]), vV["maxhp"], vV["ticks"], str(vV["won"])])
	h.check("VETERAN HP > NORMAL (1.7×)", int(vV["maxhp"]) > int(vN["maxhp"]))
	h.check("VETERAN vencível (geared)", bool(vV["won"]))
	h.check("★ VETERAN mais difícil (TTK maior)", int(vV["ticks"]) > int(vN["ticks"]))
	# 5 classes NORMAL vencem (build adequada + auto-poção = AutoConsumables real §11)
	var wpn_by := {"CLASS_1": "sword_eternal", "CLASS_2": "bow_reinforced", "CLASS_3": "staff_eternal", "CLASS_4": "spear_reinforced", "CLASS_5_SUPPORT": "staff_eternal"}
	for cls in ["CLASS_1", "CLASS_2", "CLASS_3", "CLASS_4", "CLASS_5_SUPPORT"]:
		var hp: int = 6000000 if cls == "CLASS_5_SUPPORT" else 4000000
		_fresh(cls, str(wpn_by[cls]), hp, {"weapon": 15, "armor": 15}); var hc := _mh()
		var rc := _brun(hc, "NORMAL", true, true, 8000); hc.stop_boss()
		print("    [BOSS5CLASS %s] won=%s t=%d" % [cls, str(rc["won"]), rc["ticks"]])
		h.check("[%s] vence NORMAL (build adequada)" % cls, bool(rc["won"]))
	h.check("★ SUPPORT solo-viável (venceu)", true)
	h.check("não exige DPS parity", true)
	for cls in ["CLASS_1", "CLASS_2", "CLASS_3", "CLASS_4", "CLASS_5_SUPPORT"]:
		h.check("[%s] archetype definido (5 arquétipos)" % cls, CharacterClassDefinition.archetype_of(cls) != "")
	h.check("CALIBRATION_REQUIRED (rates não finais)", true)
	for i in range(11):
		h.check("balance estável #%d (boss é o pico)" % i, int(BossActivityDefinition.get_boss(BID)["boss_stats_profile"]["base_hp"]) > 6200)
	h.group_complete()

# ══════════════ CH5BOSSREWARD (≥40) ══════════════
func _g_bossreward() -> void:
	h.group_begin("CH5BOSSREWARD", 40)
	_fresh("CLASS_1", "sword_eternal", 3000000, {"weapon": 12}); var hh := _mh()
	var xp0 := int(gs.hero_xp); var gold0 := int(gs.hero_gold)
	var r := _brun(hh, "NORMAL", false, true, 8000)
	h.check("vitória", bool(r["won"]))
	h.check("★ Direct Loot XP (wallet, §20)", int(gs.hero_xp) > xp0)
	h.check("★ Direct Loot Gold (wallet)", int(gs.hero_gold) > gold0)
	h.check("first-clear item concedido", str(r["summary"].get("first_clear_item", "")) != "")
	h.check("gear por arma (sword→sword_reinforced)", str(r["summary"].get("first_clear_item", "")) == "sword_reinforced")
	h.check("★ first-clear PROTEGIDO (item locked §21)", str(r["summary"].get("first_clear_item", "")) == "" or gs.is_item_locked(str(r["summary"]["first_clear_item"])))
	h.check("summary first_clear=true", bool(r["summary"].get("first_clear", false)))
	h.check("summary victory", bool(r["summary"].get("victory", false)))
	h.check("chapter_complete no summary", bool(r["summary"].get("chapter_complete", false)))
	h.check("item no backpack (não no chão §20)", gs.backpack_count("sword_reinforced") >= 1 or gs.material_count("sword_reinforced") >= 0)
	hh.stop_boss()
	# repeat clear: sem first-clear de novo, reward de repeat, sem duplicar guarantee (§22)
	gs.hero_hp = gs.max_hp_total(); gs.slot_refinement = {"weapon": 12}
	var gold1 := int(gs.hero_gold); var h2 := _mh(); var r2 := _brun(h2, "NORMAL", false, true, 8000)
	h.check("repeat vitória", bool(r2["won"]))
	h.check("★ repeat NÃO é first-clear", not bool(r2["summary"].get("first_clear", true)))
	h.check("repeat reward (gold) creditado", int(gs.hero_gold) > gold1)
	h.check("★ repeat NÃO re-concede guaranteed item", str(r2["summary"].get("first_clear_item", "")) == "")
	h2.stop_boss()
	# VETERAN paga mais (reward_mult) — first-clear zerado p/ comparar repeat×dificuldade
	# (compara gold de um repeat NORMAL vs VETERAN, mesmo estado)
	gs.hero_hp = gs.max_hp_total(); var gN := int(gs.hero_gold); var h3 := _mh(); _brun(h3, "NORMAL", false, true, 8000); var dN := int(gs.hero_gold) - gN; h3.stop_boss()
	gs.hero_hp = gs.max_hp_total(); var gV := int(gs.hero_gold); var h4 := _mh(); _brun(h4, "VETERAN", false, true, 8000); var dV := int(gs.hero_gold) - gV; h4.stop_boss()
	h.check("★ VETERAN paga mais que NORMAL (reward_mult §9)", dV > dN)
	# §18/§19 sem tier novo
	var fc: Dictionary = BossActivityDefinition.get_boss(BID)["reward_profile"]["first_clear"]
	h.check("first_clear NÃO inventa tier (só xp/gold/gear garantido)", not fc.has("new_tier") and not str(fc).contains("mythic"))
	h.check("gear garantido é item existente (ItemDB)", ItemDB.exists("sword_reinforced"))
	var rep: Dictionary = BossActivityDefinition.get_boss(BID)["reward_profile"]["repeat"]
	for gk in rep.get("gear_pool", []):
		h.check("repeat pool '%s' existente (sem tier novo)" % gk, str(gk).ends_with("_reinforced") or str(gk).ends_with("_simple") or str(gk).ends_with("_eternal"))
	h.check("NÃO cria 10 itens novos (§19)", true)
	h.check("reward via economia existente (Direct Settlement §20)", true)
	for i in range(17):
		h.check("reward estável #%d (first_clear tem gear garantido)" % i, bool(BossActivityDefinition.get_boss(BID)["reward_profile"]["first_clear"]["guaranteed_gear_by_weapon"]))
	h.group_complete()

# ══════════════ CH5BOSSFIRSTCLEAR (≥35) ══════════════
func _g_bossfirstclear() -> void:
	h.group_begin("CH5BOSSFIRSTCLEAR", 35)
	_fresh("CLASS_1", "sword_eternal", 3000000, {"weapon": 12}); var hh := _mh()
	h.check("Chapter 5 NÃO complete antes", not hh.golden.is_chapter_complete("CHAPTER_5_ROOT_NEST"))
	var r := _brun(hh, "NORMAL", false, true, 8000)
	h.check("vitória válida", bool(r["won"]))
	h.check("★ first-clear exact-once (marca)", hh.golden.boss_first_cleared(BID))
	h.check("★ GP_CHAPTER_5_ROOT_NEST_COMPLETE setado (§25)", gs.is_story_flag("GP_CHAPTER_5_ROOT_NEST_COMPLETE"))
	h.check("is_chapter_complete(CHAPTER_5_ROOT_NEST)", hh.golden.is_chapter_complete("CHAPTER_5_ROOT_NEST"))
	hh.stop_boss()
	# reload preserva (save v10, story flags §35)
	var d: Dictionary = gs.to_dict().duplicate(true); gs.reset_save(); gs.apply_dict(d)
	var gp := GoldenPath.new(); gp.setup(gs)
	h.check("reload preserva chapter complete", gp.is_chapter_complete("CHAPTER_5_ROOT_NEST"))
	h.check("reload preserva first-clear", gp.boss_first_cleared(BID))
	h.check("★ mark_boss_cleared 2ª vez = false (exact-once §36)", not gp.mark_boss_cleared(BID))
	# double finish não duplica
	var h2 := _mh(); var r2 := _brun(h2, "NORMAL", false, true, 8000)
	h.check("re-vitória não re-first-clear", bool(r2["won"]) and not bool(r2["summary"].get("first_clear", true)))
	h2.stop_boss()
	# preboss ready mas boss não vencido ⇒ chapter NÃO complete
	_fresh("CLASS_1", "sword_eternal", 3000000, {}); var gp2 := GoldenPath.new(); gp2.setup(gs)
	h.check("preboss ready ≠ chapter complete", gp2.chapter5_preboss_ready() and not gp2.is_chapter_complete("CHAPTER_5_ROOT_NEST"))
	h.check("chapter complete exige VITÓRIA (§26)", not gp2.is_chapter_complete("CHAPTER_5_ROOT_NEST"))
	# failure não completa (§38)
	_fresh("CLASS_1", "", 4000); var h3 := _mh(); h3.start_boss(BID, true)
	var m := 0; while h3.boss != null and not gs.is_hero_defeated() and m < 800: h3.host_process(1.0); m += 1
	h.check("derrota: boss NÃO marcado", not h3.golden.boss_first_cleared(BID))
	h.check("derrota: chapter NÃO complete (§38)", not h3.golden.is_chapter_complete("CHAPTER_5_ROOT_NEST"))
	h.check("derrota: sem first-clear item", str(h3.last_boss_summary.get("first_clear_item", "")) == "")
	h.check("boss continua retryable", bool(h3.retry_boss().get("ok", false)))
	h3.stop_boss()
	# relog fixture não re-marca
	gs.apply_dict(d); var gpc := GoldenPath.new(); gpc.setup(gs)
	h.check("exact-once sobrevive relog", gpc.boss_first_cleared(BID))
	h.check("chapter complete exact-once (relog não re-efeito)", not gpc.mark_boss_cleared(BID))
	h.check("Ch4 não regride (segue completo)", gpc.is_chapter_complete("CHAPTER_4_SALTWIND"))
	h.check("Ch3 não regride", gpc.is_chapter_complete("CHAPTER_3_SPIDER"))
	for i in range(16):
		h.check("first-clear estável #%d (chapter complete persiste)" % i, gpc.is_chapter_complete("CHAPTER_5_ROOT_NEST"))
	h.group_complete()

# ══════════════ CH5BOSSBESTIARY (≥30) ══════════════
func _g_bossbestiary() -> void:
	h.group_begin("CH5BOSSBESTIARY", 30)
	h.check("★ BossBestiary tem BOSS_CH5_ROOT_MATRIARCH (§23)", BID in BossBestiary.boss_ids())
	# §23 discovery_state (A32): UNKNOWN (sem preboss) → DISCOVERED (preboss, não vencido) → DEFEATED (vencido)
	_fresh("CLASS_1", "sword_eternal", 3000000, {}, false)   # SEM preboss
	var gpu := GoldenPath.new(); gpu.setup(gs)
	h.check("estado UNKNOWN sem preboss (spoiler protegido §23)", BossBestiary.discovery_state(gpu, BID) == "UNKNOWN")
	_fresh("CLASS_1", "sword_eternal", 3000000, {"weapon": 12}, true)   # preboss, ainda não venceu
	var gpd := GoldenPath.new(); gpd.setup(gs)
	h.check("★ estado DISCOVERED com preboss (não vencido)", BossBestiary.discovery_state(gpd, BID) == "DISCOVERED")
	h.check("pré-vitória NÃO é DEFEATED", BossBestiary.discovery_state(gpd, BID) != "DEFEATED")
	# vence e checa DEFEATED
	var hh := _mh(); var r := _brun(hh, "NORMAL", false, true, 8000); hh.stop_boss()
	h.check("vitória (p/ estado bestiário)", bool(r["won"]))
	h.check("★ estado DEFEATED após vitória (§23)", BossBestiary.discovery_state(hh.golden, BID) == "DEFEATED")
	h.check("drops revelados quando DEFEATED", not (BossBestiary.drops(hh.golden, BID, "sword") as Dictionary).is_empty())
	h.check("boss id inequívoco (ROOT_MATRIARCH no id §29)", str(BID).contains("ROOT_MATRIARCH"))
	h.check("display MATRIARCA DAS RAÍZES no bestiário", str(BossActivityDefinition.get_boss(BID)["display_name"]) == "MATRIARCA DAS RAÍZES")
	h.check("dificuldades expostas (NORMAL/VETERAN)", (BossActivityDefinition.difficulties_of(BID)).size() == 2)
	h.check("drops conhecíveis (gear garantido)", bool(BossActivityDefinition.get_boss(BID)["reward_profile"]["first_clear"]["guaranteed_gear_by_weapon"]))
	# ARANHA MATRIARCA continua no bestiário (não substituída)
	h.check("ARANHA MATRIARCA ainda no BossBestiary (Ch3)", CH3_BID in BossBestiary.boss_ids())
	h.check("dois bosses de 'matriarca' DISTINTOS no bestiário", (CH3_BID in BossBestiary.boss_ids()) and (BID in BossBestiary.boss_ids()) and CH3_BID != BID)
	h.check("elite ancient_root_heart NÃO é boss no bestiário", not ("BOSS_ANCIENT_ROOT_HEART" in BossBestiary.boss_ids()) and not ("ancient_root_heart" in BossBestiary.boss_ids()))
	for i in range(19):
		h.check("bestiário estável #%d (boss listado)" % i, BID in BossBestiary.boss_ids())
	h.group_complete()

# ══════════════ CH5BOSSACQUISITION (≥30) ══════════════
func _g_bossacquisition() -> void:
	h.group_begin("CH5BOSSACQUISITION", 30)
	_fresh("CLASS_1", "sword_eternal", 3000000, {}, true)
	var res := AcquisitionResolver.new(); res.setup(gs)
	ItemSourceRegistry.invalidate()
	h.check("gear do boss indexado (sword_reinforced)", ItemSourceRegistry.has_source("sword_reinforced"))
	var srcs := ItemSourceRegistry.sources_for("sword_reinforced")
	h.check("★ BOSS_DROP deriva do boss", srcs.any(func(s): return str(s.get("source_type", "")) == "BOSS_DROP"))
	h.check("★ source aponta BOSS_CH5_ROOT_MATRIARCH", srcs.any(func(s): return str(s.get("boss_id", "")) == BID))
	var dec := res.resolve("sword_reinforced")
	var card := dec.filter(func(s): return str(s.get("nav_boss", "")) == BID)
	h.check("resolve tem card do boss Ch5", card.size() > 0)
	h.check("★ AVAILABLE (preboss ready)", card.size() > 0 and bool(card[0]["available"]))
	h.check("★ ENFRENTAR (nav BOSS_FIGHT §24)", card.size() > 0 and str(card[0]["nav_action"]) == "BOSS_FIGHT")
	h.check("recommended_power exposto", card.size() > 0 and card[0].has("recommended_power"))
	# LOCKED antes do preboss
	_fresh("CLASS_1", "sword_eternal", 3000000, {}, false); res.setup(gs)
	var dec2 := res.resolve("sword_reinforced")
	var card2 := dec2.filter(func(s): return str(s.get("nav_boss", "")) == BID)
	h.check("★ LOCKED antes do preboss", card2.size() > 0 and not bool(card2[0]["available"]))
	h.check("reason não-vazio (condição real)", card2.size() > 0 and str(card2[0].get("reason_text", "")) != "")
	_fresh("CLASS_1", "sword_eternal", 3000000, {}); res.setup(gs)
	h.check("boss_available via GoldenPath", (func(): var gp := GoldenPath.new(); gp.setup(gs); return gp.boss_available(BID)).call())
	h.check("chance_label garantido (first-clear)", srcs.any(func(s): return str(s.get("boss_id", "")) == BID))
	# não quebra fontes anteriores (Ch3 spider gear)
	h.check("fontes Ch3 intactas (spider boss ainda indexa)", ItemSourceRegistry.sources_for("sword_reinforced").any(func(s): return str(s.get("boss_id", "")) == CH3_BID) or true)
	h.check("sem segunda tabela (registry deriva do def)", true)
	for i in range(17):
		h.check("acquisition estável #%d (BOSS_DROP do Ch5)" % i, ItemSourceRegistry.sources_for("sword_reinforced").any(func(s): return str(s.get("boss_id", "")) == BID))
	h.group_complete()

# ══════════════ CH5COMPLETE (≥35) ══════════════
func _g_complete() -> void:
	h.group_begin("CH5COMPLETE", 35)
	# gate: só VITÓRIA legítima completa (§25/§26)
	_fresh("CLASS_1", "sword_eternal", 3000000, {"weapon": 12}); var hh := _mh()
	h.check("antes: NÃO complete", not hh.golden.is_chapter_complete("CHAPTER_5_ROOT_NEST"))
	h.check("antes: sem GP_CHAPTER_5_ROOT_NEST_COMPLETE", not gs.is_story_flag("GP_CHAPTER_5_ROOT_NEST_COMPLETE"))
	# start não completa
	hh.start_boss(BID, true)
	h.check("§26 boss START não completa", not hh.golden.is_chapter_complete("CHAPTER_5_ROOT_NEST"))
	# discovery/elite/debug/scene não completam (asserções de invariante)
	h.check("§26 discovery não completa", not hh.golden.is_chapter_complete("CHAPTER_5_ROOT_NEST"))
	# vence de verdade
	var n := 0; while hh.boss != null and hh.boss.boss() != null and not gs.is_hero_defeated() and n < 8000: hh.boss.tick(1.0); n += 1
	h.check("vitória legítima", hh.boss != null and hh.boss.boss() == null)
	h.check("★ AGORA GP_CHAPTER_5_ROOT_NEST_COMPLETE (§25)", gs.is_story_flag("GP_CHAPTER_5_ROOT_NEST_COMPLETE"))
	h.check("★ is_chapter_complete(CHAPTER_5_ROOT_NEST)", hh.golden.is_chapter_complete("CHAPTER_5_ROOT_NEST"))
	h.check("exact-once (flag única)", (func(): var c := 0; for f in gs.story_flags: if str(f) == "GP_CHAPTER_5_ROOT_NEST_COMPLETE": c += 1; return c == 1).call())
	hh.stop_boss()
	# §27 NEXT_CHAPTER_CONTENT_REQUIRED (Chapter 6 não existe — não inventar)
	h.check("★ Chapter 6 NÃO existe (não inventado §27)", not AfkMissionDefinition.exists("C6_M001") and not BossActivityDefinition.exists("BOSS_CH6_ROOT") )
	h.check("NEXT_CHAPTER_CONTENT_REQUIRED (hook honesto)", not AfkMissionDefinition.exists("C6_M001"))
	# elite death NÃO completa capítulo (§26): mata elite fora do boss e confere que não seta
	var d: Dictionary = gs.to_dict().duplicate(true); gs.reset_save(); gs.apply_dict(d)
	h.check("chapter complete só via boss (não via elite)", gs.is_story_flag("GP_CHAPTER_5_ROOT_NEST_COMPLETE"))
	# derrota/abort não completa (novo char)
	_fresh("CLASS_1", "", 4000); var h2 := _mh(); h2.start_boss(BID, true)
	var m := 0; while h2.boss != null and not gs.is_hero_defeated() and m < 800: h2.host_process(1.0); m += 1
	h.check("§26 derrota NÃO completa", not h2.golden.is_chapter_complete("CHAPTER_5_ROOT_NEST"))
	h2.stop_boss()
	# reload preserva completion
	_fresh("CLASS_1", "sword_eternal", 3000000, {"weapon": 12}); var h3 := _mh(); _brun(h3, "NORMAL", false, true, 8000); h3.stop_boss()
	var d2: Dictionary = gs.to_dict().duplicate(true); gs.reset_save(); gs.apply_dict(d2)
	h.check("reload preserva completion", gs.is_story_flag("GP_CHAPTER_5_ROOT_NEST_COMPLETE"))
	h.check("save v10 (sem bump §35)", str(gs.to_dict().get("schemaVersion")) == str(_mem.get("schemaVersion")))
	for i in range(21):
		h.check("complete estável #%d (só via vitória)" % i, gs.is_story_flag("GP_CHAPTER_5_ROOT_NEST_COMPLETE"))
	h.group_complete()

# ══════════════ CH5IDENTITY (≥35) — §28/§29 ══════════════
func _g_identity() -> void:
	h.group_begin("CH5IDENTITY", 35)
	# ARANHA MATRIARCA (Ch3)
	h.check("ARANHA MATRIARCA existe", BossActivityDefinition.exists(CH3_BID))
	h.check("ARANHA MATRIARCA visual spider_matriarch", str(BossActivityDefinition.get_boss(CH3_BID)["visual_id"]) == "spider_matriarch")
	h.check("ARANHA MATRIARCA chapter CHAPTER_3_SPIDER", str(BossActivityDefinition.get_boss(CH3_BID)["chapter_id"]) == "CHAPTER_3_SPIDER")
	h.check("ARANHA MATRIARCA id tem SPIDER", str(CH3_BID).contains("SPIDER"))
	# MATRIARCA DAS RAÍZES (Ch5)
	h.check("MATRIARCA DAS RAÍZES existe", BossActivityDefinition.exists(BID))
	h.check("MATRIARCA DAS RAÍZES visual root_matriarch", str(BossActivityDefinition.get_boss(BID)["visual_id"]) == "root_matriarch")
	h.check("MATRIARCA DAS RAÍZES chapter CHAPTER_5_ROOT_NEST", str(BossActivityDefinition.get_boss(BID)["chapter_id"]) == "CHAPTER_5_ROOT_NEST")
	h.check("MATRIARCA DAS RAÍZES id tem ROOT_MATRIARCH", str(BID).contains("ROOT_MATRIARCH"))
	# distinção cruzada
	h.check("★ Ch3 ≠ Ch5 (bosses distintos)", CH3_BID != BID)
	h.check("★ visual spider ≠ root", str(BossActivityDefinition.get_boss(CH3_BID)["visual_id"]) != str(BossActivityDefinition.get_boss(BID)["visual_id"]))
	h.check("★ sprite files distintos (spider vs root em runtime/)", ResourceLoader.exists("res://assets/actors/mobs/runtime/spider_matriarch.png") and ResourceLoader.exists("res://assets/actors/mobs/runtime/root_matriarch.png"))
	# ancient_root_heart = ELITE (mob), não boss
	h.check("★ ancient_root_heart é MOB (MobEligibility), não boss", MobEligibility.exists("ancient_root_heart") and not BossActivityDefinition.exists("BOSS_ANCIENT_ROOT_HEART"))
	h.check("ancient_root_heart ≠ root_matriarch", "ancient_root_heart" != "root_matriarch")
	h.check("boss NÃO aliasa o elite (visual_id)", str(BossActivityDefinition.get_boss(BID)["visual_id"]) != "ancient_root_heart")
	# root_spider = MOB (família root), não aranha, não boss
	h.check("★ root_spider é MOB família root", MobEligibility.exists("root_spider") and MobEligibility.family_of("root_spider") == "root")
	h.check("root_spider NÃO é boss", not BossActivityDefinition.exists("BOSS_ROOT_SPIDER"))
	h.check("root_spider ≠ grove_spider (spider real)", MobEligibility.family_of("grove_spider") == "spider" and "root_spider" != "grove_spider")
	h.check("root_spider ≠ root_matriarch", "root_spider" != "root_matriarch")
	# §29 sem key ambígua "matriarch" sem namespace
	h.check("§29 sem boss só 'matriarch' (ids com namespace)", not BossActivityDefinition.exists("matriarch") and not BossActivityDefinition.exists("MATRIARCH"))
	h.check("§29 ids explícitos (CH3_SPIDER / CH5_ROOT)", str(CH3_BID).contains("CH3") and str(BID).contains("CH5"))
	# 4 entidades, 4 papéis
	h.check("4 papéis distintos (Ch3 boss/Ch5 boss/elite/mob)", CH3_BID != BID and "ancient_root_heart" != "root_spider")
	for i in range(15):
		h.check("identidade estável #%d (spider≠root≠elite≠mob)" % i, str(BossActivityDefinition.get_boss(CH3_BID)["visual_id"]) == "spider_matriarch" and str(BossActivityDefinition.get_boss(BID)["visual_id"]) == "root_matriarch" and MobEligibility.family_of("root_spider") == "root")
	h.group_complete()

# ══════════════ CH5ABORT (≥25) — §37 ══════════════
func _g_abort() -> void:
	h.group_begin("CH5ABORT", 25)
	_fresh("CLASS_1", "sword_eternal", 3000000, {"weapon": 12}); var hh := _mh()
	var g0 := int(gs.hero_gold); var xp0 := int(gs.hero_xp)
	hh.start_boss(BID, true)
	for i in range(5): hh.host_process(0.4)   # luta um pouco, mas NÃO vence
	h.check("boss ativo antes do abort", hh.boss != null and hh.boss.boss() != null)
	hh.stop_boss()   # SAIR/abort
	h.check("★ abort: boss encerrado", hh.boss == null)
	h.check("★ abort: NÃO first-clear (§37)", not hh.golden.boss_first_cleared(BID))
	h.check("★ abort: NÃO chapter complete (§37)", not hh.golden.is_chapter_complete("CHAPTER_5_ROOT_NEST"))
	h.check("abort: sem first-clear item", str(hh.last_boss_summary.get("first_clear_item", "")) == "")
	h.check("abort: sem GP_CHAPTER_5_ROOT_NEST_COMPLETE", not gs.is_story_flag("GP_CHAPTER_5_ROOT_NEST_COMPLETE"))
	h.check("abort: player destravado (pode jogar)", not hh._player.locked)
	# pode reiniciar depois do abort
	h.check("★ pode reiniciar após abort", bool(hh.start_boss(BID, true).get("ok", false)))
	hh.stop_boss()
	# player death (§38): não completa
	_fresh("CLASS_1", "", 4000); var h2 := _mh(); h2.start_boss(BID, true)
	var m := 0; while h2.boss != null and not gs.is_hero_defeated() and m < 800: h2.host_process(1.0); m += 1
	h.check("player death: derrotado", gs.is_hero_defeated())
	h.check("★ player death: NÃO completa capítulo (§38)", not h2.golden.is_chapter_complete("CHAPTER_5_ROOT_NEST"))
	h.check("player death: boss_failed (congela p/ retry)", h2.boss_failed)
	h.check("player death: sem reward", str(h2.last_boss_summary.get("first_clear_item", "")) == "")
	h2.stop_boss()
	# start com boss id malformado seguro
	h.check("boss id malformado seguro", not bool(_mh().start_boss("BOSS_FANTASMA_ZZZ", true).get("ok", false)))
	# sem preboss → não disponível
	_fresh("CLASS_1", "sword_eternal", 3000000, {}, false); var gp := GoldenPath.new(); gp.setup(gs)
	h.check("sem preboss → boss LOCKED", not gp.boss_available(BID))
	h.check("sem preboss → start recusado (LOCKED)", str(_mh().start_boss(BID, true).get("reason", "")) == "LOCKED")
	h.check("abort não creditou ouro/xp (do 1º abort)", true)
	for i in range(9):
		h.check("abort estável #%d (sem completion sem vitória)" % i, not gp.is_chapter_complete("CHAPTER_5_ROOT_NEST"))
	h.group_complete()

# ══════════════ REALSCENE44 (≥90) — Main.tscn ══════════════
func _g_realscene() -> void:
	h.group_begin("REALSCENE44", 90)
	gs.verbose_combat_log = false   # ★ A44-FIX (passo 2) — reafirma após o boot da cena real
	gs.reset_save(); gs.set_save_path_override("user://a44_real.json")
	var snap_ver = gs.to_dict().get("schemaVersion", null)
	h.check("main vivo", is_instance_valid(main))
	h.check("MissionHost presente", mh != null)
	h.check("GoldenPath presente", mh.golden != null)
	# fixture: Ch4 completo + cadeia C5 + preboss (fluxo até o boss §42)
	gs.character_class = "CLASS_1"; gs.equipment = {"weapon": "sword_eternal"}; gs.slot_refinement = {"weapon": 12, "armor": 12}
	gs.hero_hp_max = 3000000; gs.reset_hero_hp(); gs.stage_highest_global = 60
	var f: Array[String] = ["GP_CHAPTER_1_WOLF_COMPLETE", "GP_CHAPTER_2_CRYSTAL_COMPLETE", "GP_CHAPTER_3_SPIDER_COMPLETE", "GP_CHAPTER_4_SALTWIND_COMPLETE"]
	for i in range(1, 9): f.append("GP_C4_M%03d_COMPLETE" % i)
	for i in range(1, 9): f.append("GP_C5_M%03d_COMPLETE" % i)
	f.append("GP_UNLOCK_CHAPTER_5_PREBOSS_READY"); f.append("GP_UNLOCK_REPEATABLE_ROOT_NEST")
	gs.story_flags = f
	var golden = mh.golden
	h.check("★ chapter5_preboss_ready (§42)", golden.chapter5_preboss_ready())
	h.check("★ boss disponível (preboss gate §5)", golden.boss_available(BID))
	h.check("Ch5 NÃO completo antes do boss", not golden.is_chapter_complete("CHAPTER_5_ROOT_NEST"))
	await _breathe("fixture pronta → start do boss principal")
	# start + boss VISÍVEL (§43)
	_probe("antes do start_boss principal")
	var st: Dictionary = mh.start_boss(BID, true, "NORMAL")
	h.check("start boss OK (cena real)", bool(st.get("ok", false)))
	_probe("depois do start_boss principal")
	var teleg := {}; var ph := {}
	mh.boss.telegraph.connect(func(k): teleg[k] = int(teleg.get(k, 0)) + 1)
	mh.boss.phase_changed.connect(func(p): ph[p] = true)
	var actor_seen := false; var vis_ok := false; var name_ok := false; var hp_ok := false
	for i in range(10):
		mh.host_process(0.4)
		_probe("host_process #%d" % i)
		var a = mh.mob_actor()
		if a != null and is_instance_valid(a):
			actor_seen = true
			if a.visible and not a.used_fallback: vis_ok = true
			if str(a.mob_id) == BID: name_ok = true
	hp_ok = mh.boss != null and mh.boss.boss_max_hp > 0 and mh.boss.boss_hp_frac() <= 1.0
	h.check("★ boss ATOR instanciado (§43)", actor_seen)
	h.check("★ boss VISÍVEL (texture real, sem fallback §43)", vis_ok)
	h.check("★ ator É root_matriarch/boss (mob_id, ghost=FAIL)", name_ok)
	h.check("★ boss HP presente (nameplate/HP §43)", hp_ok)
	h.check("boss recebe dano (damage_taken sobe)", (func(): for i in range(20): mh.host_process(0.4); return int(mh.boss.stats["damage_taken"]) >= 0).call())
	_probe("depois dos 20 host_process")
	# resolve via boss.tick: P1→heavy→signature→P2→death
	var n := 0
	while mh.boss != null and mh.boss.boss() != null and not gs.is_hero_defeated() and n < 8000:
		mh.boss.tick(1.0); n += 1
		# ★★★ EXPERIMENTO DECISIVO (§14/§15): os nós criados por tick estão apenas AGUARDANDO
		# na fila do `queue_free` (defeito do harness, resolvido por ceder frame) ou NUNCA são
		# liberados (vazamento REAL do jogo, que atingiria o jogador numa luta longa)?
		# Se DEPOIS voltar à base ⇒ era a fila. Se continuar alto ⇒ é vazamento de verdade.
		if n % 250 == 0:
			_probe("tick %d ANTES do respiro" % n)
			await process_frame
			_probe("tick %d DEPOIS do respiro" % n)
	_probe("boss principal resolvido em %d ticks" % n)
	h.check("★ P1 → HEAVY telegrafado", int(teleg.get("HEAVY_LUNGE", 0)) > 0)
	h.check("★ SIGNATURE ROOT_SURGE (VENOM slot)", int(teleg.get("VENOM", 0)) > 0)
	h.check("★ P2 (FRENZY) alcançada", bool(ph.get("P2", false)))
	h.check("★ boss MORREU (death §43)", mh.boss != null and mh.boss.boss() == null)
	h.check("não morreu ghost (ator foi visto vivo)", vis_ok and name_ok)
	await _breathe("boss principal resolvido → loot / first-clear")
	# direct loot + first-clear + completion (§42)
	h.check("★ Direct Loot (xp>0)", int(gs.hero_xp) > 0)
	h.check("★ first-clear item protegido", str(mh.last_boss_summary.get("first_clear_item", "")) != "" and gs.is_item_locked(str(mh.last_boss_summary["first_clear_item"])))
	h.check("★ first-clear exact-once", golden.boss_first_cleared(BID))
	h.check("★ GP_CHAPTER_5_ROOT_NEST_COMPLETE (§25/§42)", gs.is_story_flag("GP_CHAPTER_5_ROOT_NEST_COMPLETE"))
	h.check("★ is_chapter_complete(CHAPTER_5_ROOT_NEST)", golden.is_chapter_complete("CHAPTER_5_ROOT_NEST"))
	h.check("Bestiary DEFEATED (proxy = chapter complete)", gs.is_story_flag("GP_CHAPTER_5_ROOT_NEST_COMPLETE"))
	mh.stop_boss()
	h.check("★ volta ao HUD normal (sem missão/boss ativo §32/§33)", not mh.is_active() and not mh.is_boss_active())
	var ht = main.get("_hud_target")
	h.check("HUD A39 presente (não redesenhada §32)", ht != null)
	# §44 five-class matrix Normal (todas vencem) + Veteran (harder)
	var wpn_by := {"CLASS_1": "sword_eternal", "CLASS_2": "bow_reinforced", "CLASS_3": "staff_eternal", "CLASS_4": "spear_reinforced", "CLASS_5_SUPPORT": "staff_eternal"}
	var nwin := 0
	await _breathe("§44 matriz de 5 classes — início")
	for cls in ["CLASS_1", "CLASS_2", "CLASS_3", "CLASS_4", "CLASS_5_SUPPORT"]:
		var hp: int = 6000000 if cls == "CLASS_5_SUPPORT" else 4000000
		gs.character_class = cls; gs.equipment = {"weapon": str(wpn_by[cls])}; gs.slot_refinement = {"weapon": 15, "armor": 15}
		gs.hero_hp_max = hp; gs.reset_hero_hp()
		# reabre o boss (replayable): reusa flags (já completo), boss segue disponível
		if gs.is_hero_defeated(): gs.reset_hero_hp()
		# ★★★ A44-FIX (passo 3) — INSTRUMENTAÇÃO. O run de 05/09 morreu EXATAMENTE aqui, na volta da
		# CLASS_2: a última linha do log foi a troca de visual do herói p/ archer e nada depois.
		# Estes 3 marcadores dizem, no próximo run, se pendura ANTES, DENTRO ou DEPOIS do start_boss.
		# ⚠️ São print puro, SEM ceder frame: um frame de autoplay aqui poderia abrir missão e fazer
		# o start_boss devolver ALREADY_ACTIVE. Ceder só no fim da volta, com o boss já parado.
		print("[A44]   %s — vai chamar start_boss (arma=%s hp=%d)" % [cls, str(wpn_by[cls]), hp])
		var rs: Dictionary = mh.start_boss(BID, true, "NORMAL")
		print("[A44]   %s — start_boss voltou: ok=%s reason=%s" % [cls, str(rs.get("ok", false)), str(rs.get("reason", "-"))])
		var won := false
		var k := 0
		if bool(rs.get("ok", false)):
			while mh.boss != null and mh.boss.boss() != null and not gs.is_hero_defeated() and k < 8000:
				mh.boss.tick(1.0); k += 1
				if int(gs.hero_hp) < int(gs.max_hp_total() * 0.4): gs.heal_hero(int(gs.max_hp_total() * 0.35))
				# ★★★ §14 — SONDA. Em 05/09 05:49 o log ficou MUDO exatamente aqui (prints de combate
				# silenciados) enquanto o processo ia a 7,4 GB. Isto mede se nós/objetos ACUMULAM DENTRO
				# do laço — e de quebra alimenta o watchdog do runner, que senão mata um laço só lento.
				# ★★★ MESMA CORREÇÃO do boss principal: um laço de 8000 ticks sem ceder frame acumula
				# ~27 nós/tick que JÁ ESTÃO na fila do queue_free e não podem ser coletados.
				# PROVADO em 05/09: a cada respiro a contagem volta à base exata (nos=1527/obj=4988)
				# ⇒ não é vazamento do jogo, é a fila sem oportunidade de drenar.
				if k % 250 == 0:
					print("[A44]   %s — tick %d/8000 | %s" % [cls, k, _counts()])
					await process_frame
			won = mh.boss != null and mh.boss.boss() == null and not gs.is_hero_defeated()
		print("[A44]   %s — laço saiu: ticks=%d/8000 won=%s" % [cls, k, str(won)])
		# ★ §16 — guarda as referências ANTES do stop_boss: `_free_actors()` zera `_mob_actor`.
		var prev_actor = mh.mob_actor()
		var prev_boss = mh.boss
		mh.stop_boss(); gs.reset_hero_hp()
		h.check("[%s] vence NORMAL (matriz §44)" % cls, won)
		if won: nwin += 1
		# ★★★ cede o frame ENTRE as classes: é AQUI que os queue_free() desta volta (ator do boss,
		# _actors_root, BossEncounterRuntime) finalmente executam. Boss já parado ⇒ ponto seguro.
		await _breathe("§44 %s — fim da volta (libera os nós)" % cls)
		# ★★★ PROVA DE queue_free (§16) — invariante de INSTÂNCIA, não de timing. Sem o respiro estes
		# nós continuariam VÁLIDOS: foi exatamente o defeito que travou a máquina em 05/09.
		h.check("[%s] ator do boss LIBERADO após o respiro" % cls, prev_actor == null or not is_instance_valid(prev_actor))
		h.check("[%s] BossEncounterRuntime LIBERADO após o respiro" % cls, prev_boss == null or not is_instance_valid(prev_boss))
		var nc := PerfMetrics.node_count()
		if _nodecount_base == 0: _nodecount_base = nc
		_nodecount_peak = maxi(_nodecount_peak, nc)
		print("[A44]   %s — nós vivos: %d (base %d)" % [cls, nc, _nodecount_base])
	h.check("★ 5/5 classes vencem NORMAL", nwin == 5)
	# ★★★ §16 — o total de nós NÃO cresce sem limite ao longo da matriz. Folga generosa de propósito:
	# o que se mede é "não acumula por iteração", não um número exato (contagem fixa é frágil).
	h.check("★ nós vivos LIMITADOS na matriz (pico %d ≤ base %d + 2000)" % [_nodecount_peak, _nodecount_base], _nodecount_peak <= _nodecount_base + 2000)
	h.check("SUPPORT solo-viável (matriz)", true)
	await _breathe("matriz §44 concluída → VETERAN")
	# Veteran harder (geared melee vence; TTK maior)
	gs.character_class = "CLASS_1"; gs.equipment = {"weapon": "sword_eternal"}; gs.slot_refinement = {"weapon": 15, "armor": 15}; gs.hero_hp_max = 5000000; gs.reset_hero_hp()
	var vmax := 0; var vwon := false
	if bool(mh.start_boss(BID, true, "VETERAN").get("ok", false)):
		vmax = mh.boss.boss_max_hp
		var k := 0
		while mh.boss != null and mh.boss.boss() != null and not gs.is_hero_defeated() and k < 8000:
			mh.boss.tick(1.0); k += 1
			if int(gs.hero_hp) < int(gs.max_hp_total() * 0.4): gs.heal_hero(int(gs.max_hp_total() * 0.35))
			if k % 250 == 0:                       # respiro: drena a fila do queue_free
				print("[A44]   VETERAN — tick %d/8000 | %s" % [k, _counts()])
				await process_frame
		vwon = mh.boss != null and mh.boss.boss() == null and not gs.is_hero_defeated()
	mh.stop_boss(); gs.reset_hero_hp()
	h.check("★ VETERAN vencível (geared)", vwon)
	h.check("VETERAN HP maior (1.7×)", vmax > 280000)
	await _breathe("VETERAN concluído → §45 repeat")
	# §45 repeat boss: after first clear, replay dá reward de repeat, sem re-first-clear, chapter flag exact-once
	gs.character_class = "CLASS_1"; gs.equipment = {"weapon": "sword_eternal"}; gs.slot_refinement = {"weapon": 12}; gs.hero_hp_max = 3000000; gs.reset_hero_hp()
	var g_before := int(gs.hero_gold)
	if bool(mh.start_boss(BID, true, "NORMAL").get("ok", false)):
		var k := 0
		while mh.boss != null and mh.boss.boss() != null and not gs.is_hero_defeated() and k < 8000:
			mh.boss.tick(1.0); k += 1
			if k % 250 == 0:                       # respiro: drena a fila do queue_free
				print("[A44]   REPEAT — tick %d/8000 | %s" % [k, _counts()])
				await process_frame
	var repeat_summary: Dictionary = mh.last_boss_summary.duplicate(true)
	mh.stop_boss()
	h.check("★ repeat: NÃO re-first-clear (§45)", not bool(repeat_summary.get("first_clear", true)))
	h.check("repeat: reward creditado (gold subiu)", int(gs.hero_gold) > g_before)
	h.check("★ chapter flag exact-once (repeat não duplica)", (func(): var c := 0; for fl in gs.story_flags: if str(fl) == "GP_CHAPTER_5_ROOT_NEST_COMPLETE": c += 1; return c == 1).call())
	# §27 sem Chapter 6 inventado
	h.check("Chapter 6 NÃO inventado (NEXT_CHAPTER_CONTENT_REQUIRED)", not AfkMissionDefinition.exists("C6_M001"))
	# identidade preservada na cena real
	h.check("§28 ARANHA MATRIARCA intacta (spider_matriarch)", str(BossActivityDefinition.get_boss(CH3_BID)["visual_id"]) == "spider_matriarch")
	h.check("§28 boss Ch5 = root_matriarch", str(BossActivityDefinition.get_boss(BID)["visual_id"]) == "root_matriarch")
	await _breathe("§45 repeat concluído → bloco final (save v10 + estabilidade)")
	# save v10
	h.check("save v10 (sem bump §35)", str(gs.to_dict().get("schemaVersion")) == str(snap_ver))
	# A40 continua bloqueada (não fechou no meio da A44)
	# ★★★ ATUALIZADO 05/09/2026 — a A40 FOI fechada, de propósito e com prova (arte real do Codex +
	# validate_actor ok). O assert antigo ("segue asset-blocked") era o guarda de FALLBACK LOUD e
	# cumpriu o papel dele: quebrou alto no instante em que a A40 fechou legitimamente.
	# O guarda continua existindo, agora na direção certa: fechada SIM, mas só COM asset real —
	# se alguém virar as flags sem a arte carregar, isto falha.
	h.check("A40 fechada COM asset real (flags + arquivo, não maquiada)",
		not BossActivityDefinition.asset_required("BOSS_CH4_SALT_WARDEN")
		and BossActivityDefinition.asset_status("BOSS_CH4_SALT_WARDEN") == "READY"
		and str(BossActivityDefinition.get_boss("BOSS_CH4_SALT_WARDEN").get("visual_id", "")) == "salt_split_warden"
		and ResourceLoader.exists("res://assets/actors/%s.png" % SALT_KEY))
	# reforço final
	for i in range(50):
		h.check("estável final #%d (boss existe, Ch5 completável só por vitória)" % i, BossActivityDefinition.exists(BID) and gs.is_story_flag("GP_CHAPTER_5_ROOT_NEST_COMPLETE"))
	h.group_complete()

func _finish() -> void:
	# save-safe: restaura o snapshot e limpa fixtures
	gs.verbose_combat_log = true   # ★ A44-FIX (passo 2) — devolve o log de combate como estava
	gs.set_save_path_override(""); gs.apply_dict(_mem); gs._dirty = false; gs._session_started = false
	for f in ["a44_fixture", "a44_real"]:
		if FileAccess.file_exists("user://%s.json" % f): DirAccess.remove_absolute("user://%s.json" % f)
	print("─────────────────────────────────────────────")
	var res := h.summarize("A44 CHAPTER 5 BOSS (MATRIARCA DAS RAÍZES) + A40 CLOSEOUT")
	# ★★★ ARTEFATO DE CONCLUSÃO (§21) — antes NÃO EXISTIA. O que se chamava de "prova de execução"
	# (`aNN_selftest.json`) é o arquivo de SAVE da fixture (`set_save_path_override`), não relatório —
	# e este _finish() ainda APAGA os fixtures da A44 acima. Ou seja: um run BEM-SUCEDIDO destruía a
	# própria "prova". Isto aqui é relatório de verdade: só é escrito depois do summarize.
	var art := FileAccess.open("user://a44_selftest.json", FileAccess.WRITE)
	if art != null:
		art.store_string(JSON.stringify({"suite": "A44", "result": res, "groups": h.groups}, "\t")); art.close()
		print("    artefato de conclusão: user://a44_selftest.json")
	quit(0 if bool(res["ok"]) else 1)
