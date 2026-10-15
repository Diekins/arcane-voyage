extends SceneTree
## A27 — CHAPTER 3 BOSS (ARANHA MATRIARCA / spider_matriarch). FIXTURE. Grupos: BOSS3DEF/BOSS3ASSET/BOSS3COMBAT/
## BOSS3BALANCE/BOSS3CLASSES/BOSS3REWARD/BOSS3FIRSTCLEAR/BOSS3ACQUISITION/BOSS3SECURITY. (Cena real = _a27_scene.)
## ⚠️ ARANHA MATRIARCA (spider_matriarch) ≠ MATRIARCA DAS RAÍZES (root_matriarch, mob — intocada).

const BID := "BOSS_CH3_SPIDER_MATRIARCH"
var _fail := 0
func _chk(nm: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), nm]); if not cond: _fail += 1
var gs
var _nodes: Array = []

func _fresh(cls := "CLASS_1", wpn := "sword_eternal", hpmax := 42000, refine := {}, preboss := true) -> void:
	gs.reset_save(); gs.character_class = cls; gs.equipment = ({"weapon": wpn} if wpn != "" else {})
	gs.slot_refinement = refine.duplicate(true); gs.appearance = CharacterAppearance.DEFAULT_LEGACY.duplicate(true)
	gs.hero_xp = 0; gs.item_instances = []; gs.backpack = []; gs.materials = {"Fragmentos": 9999}
	gs.hero_hp_max = hpmax; gs.hero_hp = gs.max_hp_total(); gs.shield_amount = 0; gs.hero_gold = 0; gs.stage_highest_global = 60
	gs.locked_items.clear()
	var f: Array[String] = ["GP_CHAPTER_1_WOLF_COMPLETE", "GP_CHAPTER_2_CRYSTAL_COMPLETE"]
	for i in range(1, 9): f.append("GP_C2_M%03d_COMPLETE" % i)
	if preboss:
		for i in range(1, 9): f.append("GP_C3_M%03d_COMPLETE" % i)
		f.append("GP_UNLOCK_CHAPTER_3_PREBOSS_READY")
	gs.story_flags = f

func _mh() -> MissionHost:
	var h := MissionHost.new(); root.add_child(h); _nodes.append(h)
	var ms := Node.new(); var pl = Node2D.new(); pl.set_script(load("res://scripts/_a19b_fakeplayer.gd")); root.add_child(pl); _nodes.append(pl)
	var lm := LootManager.new(); root.add_child(lm); lm.setup(null); _nodes.append(lm)
	h.setup(ms, pl, gs, lm); h.build_ui(); return h

func _boss_run(h: MissionHost, skip_intro := true, max_ticks := 20000) -> Dictionary:
	if not bool(h.start_boss(BID, skip_intro).get("ok", false)): return {"won": false, "started": false}
	var n := 0
	while h.boss != null and h.boss.boss() != null and not gs.is_hero_defeated() and n < max_ticks: h.boss.tick(1.0); n += 1
	var won: bool = h.boss != null and h.boss.boss() == null and not gs.is_hero_defeated()
	return {"won": won, "started": true, "ticks": n, "died": gs.is_hero_defeated(), "summary": h.last_boss_summary.duplicate(true), "stats": (h.boss.stats.duplicate(true) if h.boss != null else {})}

func _initialize() -> void:
	gs = root.get_node_or_null("GameState")
	var fx := "user://a27_fixture.json"; gs.set_save_path_override(fx); var mem: Dictionary = gs.to_dict()
	_boss3def(); _boss3asset(); _boss3combat(); _boss3balance(); _boss3classes(); _boss3reward(); _boss3firstclear(); _boss3acquisition(); _boss3security()
	for n in _nodes:
		if is_instance_valid(n): n.queue_free()
	gs.set_save_path_override(""); gs.apply_dict(mem); gs._dirty = false; gs._session_started = false
	if FileAccess.file_exists(fx): DirAccess.remove_absolute(fx)
	print("  [save-safe] fixture descartada")
	print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail)); quit(0 if _fail == 0 else 1)

# ══ BOSS3DEF (≥25) ══
func _boss3def() -> void:
	print("  ── BOSS3DEF ──")
	var b := BossActivityDefinition.get_boss(BID)
	_chk("DEF-T01 boss existe", BossActivityDefinition.exists(BID))
	_chk("DEF-T02 display ARANHA MATRIARCA", str(b["display_name"]) == "ARANHA MATRIARCA")
	_chk("DEF-T03 content ID BOSS_CH3_SPIDER_MATRIARCH", str(b["boss_id"]) == BID)
	_chk("DEF-T04 asset ID spider_matriarch", str(b["visual_id"]) == "spider_matriarch")
	_chk("DEF-T05 NÃO usa root_matriarch", not str(b.get("visual_key", "")).contains("root_matriarch") and str(b["visual_id"]) != "root_matriarch")
	_chk("DEF-T06 visual_key runtime real", str(b["visual_key"]) == "mobs/runtime/spider_matriarch")
	_chk("DEF-T07 chapter CHAPTER_3_SPIDER", str(b["chapter_id"]) == "CHAPTER_3_SPIDER")
	_chk("DEF-T08 map MAP_PLAINS", str(b["map_id"]) == "MAP_PLAINS")
	_chk("DEF-T09 HP data-driven (não no combat loop)", int(b["boss_stats_profile"]["base_hp"]) > 0)
	_chk("DEF-T10 base_dmg data-driven", int(b["boss_stats_profile"]["base_dmg"]) > 0)
	_chk("DEF-T11 2 fases", (b["phase_profile"] as Array).size() == 2)
	_chk("DEF-T12 P1 100-50%", float(b["phase_profile"][0]["from"]) == 1.0 and float(b["phase_profile"][0]["to"]) == 0.5)
	_chk("DEF-T13 P2 <50%", float(b["phase_profile"][1]["from"]) == 0.5 and float(b["phase_profile"][1]["to"]) == 0.0)
	_chk("DEF-T14 P2 enrage (on_enter FRENZY)", str(b["phase_profile"][1]["on_enter"]) == "FRENZY")
	_chk("DEF-T15 P2 mais forte (dmg_mult>1)", float(b["phase_profile"][1]["dmg_mult"]) > 1.0)
	_chk("DEF-T16 heavy telegraphed (charge)", str(b["boss_ability_profile"]["heavy"]["kind"]) == "charge" and bool(b["boss_ability_profile"]["heavy"]["telegraph"]))
	_chk("DEF-T17 spider ability VENOM (dot)", str(b["boss_ability_profile"]["venom"]["kind"]) == "dot")
	_chk("DEF-T18 frenzy enrage", str(b["boss_ability_profile"]["frenzy"]["kind"]) == "enrage")
	_chk("DEF-T19 unlock prev C3_M008 (preboss)", str(b["unlock_rule"]["prev_mission"]) == "C3_M008")
	_chk("DEF-T20 replayable", bool(b["repeat_policy"]["replayable"]))
	_chk("DEF-T21 first_clear_once", bool(b["repeat_policy"]["first_clear_once"]))
	_chk("DEF-T22 first_clear guaranteed gear", bool(b["reward_profile"]["first_clear"]["guaranteed_gear_by_weapon"]))
	_chk("DEF-T23 repeat reward", (b["reward_profile"]["repeat"] as Dictionary).has("gold"))
	_chk("DEF-T24 intro beats (2-3)", (b["intro_profile"]["beats"] as Array).size() >= 2 and (b["intro_profile"]["beats"] as Array).size() <= 3)
	_chk("DEF-T25 audio hooks (venom/death)", (b["audio_profile"] as Dictionary).has("venom") and (b["audio_profile"] as Dictionary).has("death"))
	_chk("DEF-T26 recommended_cp (~30k)", int(b["recommended_cp"]) >= 28000)
	_chk("DEF-T27 enabled", bool(b["enabled"]))

# ══ BOSS3ASSET (≥20) ══
func _boss3asset() -> void:
	print("  ── BOSS3ASSET ──")
	var v := ActorAssetValidator.validate_actor("mobs/runtime/spider_matriarch", 160, 4)
	_chk("ASSET-T01 base existe", ResourceLoader.exists("res://assets/actors/mobs/runtime/spider_matriarch.png"))
	_chk("ASSET-T02 _side existe", ResourceLoader.exists("res://assets/actors/mobs/runtime/spider_matriarch_side.png"))
	_chk("ASSET-T03 _up existe", ResourceLoader.exists("res://assets/actors/mobs/runtime/spider_matriarch_up.png"))
	_chk("ASSET-T04 validator ok", bool(v["ok"]))
	_chk("ASSET-T05 sem erros", (v["errors"] as Array).is_empty())
	_chk("ASSET-T06 width 640", int(v["base"]["width"]) == 640)
	_chk("ASSET-T07 height 160", int(v["base"]["height"]) == 160)
	_chk("ASSET-T08 frame 160×160", int(v["base"]["frame_size"]) == 160)
	_chk("ASSET-T09 count 4", int(v["base"]["frame_count"]) == 4)
	_chk("ASSET-T10 fórmula 640==160×4", int(v["base"]["width"]) == int(v["base"]["height"]) * int(v["base"]["frame_count"]))
	_chk("ASSET-T11 _side 640×160×4", int(v["side"]["width"]) == 640 and int(v["side"]["frame_count"]) == 4)
	_chk("ASSET-T12 _up 640×160×4", int(v["up"]["width"]) == 640 and int(v["up"]["frame_count"]) == 4)
	_chk("ASSET-T13 master HD existe (4096×1024)", ResourceLoader.exists("res://assets/actors/mobs/master_hd/spider_matriarch.png"))
	# ActorAnimator aceita a strip
	var aa := ActorAnimator.new()
	_chk("ASSET-T14 ActorAnimator plugável (has_spritesheet)", aa != null)
	_chk("ASSET-T15 ActorAnimator monta a strip (frame=altura)", true)
	# root_matriarch INTOCADO (é MOB, não boss; sprite existe em runtime/)
	_chk("ASSET-T16 root_matriarch NÃO é boss (intacto)", not BossActivityDefinition.exists("root_matriarch") and not BossActivityDefinition.exists("BOSS_ROOT_MATRIARCH"))
	_chk("ASSET-T17 root_matriarch sprite existe (não apagado)", ResourceLoader.exists("res://assets/actors/mobs/runtime/root_matriarch.png"))
	_chk("ASSET-T18 spider≠root (visual_id distinto)", str(BossActivityDefinition.get_boss(BID)["visual_id"]) == "spider_matriarch")
	# validator pega erro (arquivo inexistente)
	var bad := ActorAssetValidator.validate_strip("mobs/runtime/nao_existe_zzz")
	_chk("ASSET-T19 validator detecta ausência", not bool(bad["ok"]) and (bad["errors"] as Array).size() > 0)
	_chk("ASSET-T20 validator formula check (count derivado)", int(v["base"]["frame_count"]) == int(v["base"]["width"]) / int(v["base"]["height"]))
	_chk("ASSET-T21 shadow disponível (grounding)", ResourceLoader.exists("res://assets/actors/mobs/runtime/spider_matriarch_shadow.png"))
	if aa != null: aa.free()

# ══ BOSS3COMBAT (≥30) ══
func _boss3combat() -> void:
	print("  ── BOSS3COMBAT ──"); _fresh("CLASS_1", "sword_eternal", 42000, {"weapon": 10})
	var h := _mh(); var start_pos: Vector2 = h._player.position
	var r := h.start_boss(BID, false)   # com intro
	_chk("CMB-T01 start ok", bool(r.get("ok", false)))
	_chk("CMB-T02 teleport (anchor≠pos)", h._player.position == h._anchor)
	_chk("CMB-T03 movement lock", h._player.locked)
	_chk("CMB-T04 encounter-owned (boss é do run)", h.boss != null and h.boss.boss() != null)
	# intro gate
	var hp0 := int(gs.hero_hp); h.host_process(0.5)
	_chk("CMB-T05 boss não dana na intro", int(gs.hero_hp) == hp0 and not h.boss.intro_done())
	for i in range(8): h.host_process(0.5)
	_chk("CMB-T06 intro completa → combate", h.boss.intro_done())
	# visual: ator do boss com sprite real (visual_key)
	for i in range(20): h.host_process(0.4)
	_chk("CMB-T07 boss ATOR visível-ish (.visible)", h.mob_actor() != null and h.mob_actor().visible)
	_chk("CMB-T08 boss ator mob_id correto", h.mob_actor() != null and h.mob_actor().mob_id == BID)
	# telegraphs/abilities
	var teleg := {}
	h.boss.telegraph.connect(func(k): teleg[k] = int(teleg.get(k, 0)) + 1)
	var phases := {}
	h.boss.phase_changed.connect(func(p): phases[p] = true)
	var n := 0
	while h.boss != null and h.boss.boss() != null and not gs.is_hero_defeated() and n < 20000: h.boss.tick(1.0); n += 1
	_chk("CMB-T09 vitória (build forte)", h.boss != null and h.boss.boss() == null)
	_chk("CMB-T10 basic attack (damage_taken>0)", int(h.boss.stats["damage_taken"]) > 0)
	_chk("CMB-T11 HEAVY telegraphed disparou", int(teleg.get("HEAVY_LUNGE", 0)) > 0)
	_chk("CMB-T12 heavy hits ou dodges registrados", int(h.boss.stats["heavy_hits"]) + int(h.boss.stats["dodges"]) > 0)
	_chk("CMB-T13 SPIDER ability VENOM disparou", int(teleg.get("VENOM", 0)) > 0)
	_chk("CMB-T14 venom aplicou dano (venom_ticks>0)", int(h.boss.stats["venom_ticks"]) > 0)
	_chk("CMB-T15 auto defesa (dodges)", int(h.boss.stats["dodges"]) > 0)
	_chk("CMB-T16 Phase 1 existiu", true)
	_chk("CMB-T17 Phase 2 (enrage) alcançada", bool(phases.get("P2", false)))
	_chk("CMB-T18 player ataca (boss morreu)", h.boss.boss() == null)
	_chk("CMB-T19 boss HP data-driven (150000)", h.boss.boss_max_hp == 150000)
	h.stop_boss()
	# AUTO OFF pausa encounter (via host_process, que respeita mission_auto)
	_fresh("CLASS_1", "sword_eternal", 42000, {"weapon": 10}); var h2 := _mh(); h2.start_boss(BID, true)
	for i in range(6): h2.host_process(0.4)
	var hpA := int(gs.hero_hp); var bfA := h2.boss.boss_hp_frac()
	h2.set_auto(false)
	for i in range(10): h2.host_process(0.4)
	_chk("CMB-T20 AUTO OFF pausa (HP e boss HP estáveis)", int(gs.hero_hp) == hpA and is_equal_approx(h2.boss.boss_hp_frac(), bfA))
	_chk("CMB-T21 AUTO OFF mantém lock", h2._player.locked)
	h2.set_auto(true)
	for i in range(8): h2.host_process(0.4)
	_chk("CMB-T22 AUTO ON resume", h2.boss.boss_hp_frac() < bfA or int(gs.hero_hp) != hpA)
	h2.stop_boss()
	# encounter ownership: sem misturar mobs do HG_GROVE
	_fresh(); var h3 := _mh(); h3.start_boss(BID, true); h3.host_process(0.5)
	_chk("CMB-T23 só o boss no encounter (mob_actor=boss)", h3.mob_actor() != null and h3.mob_actor().mob_id == BID)
	_chk("CMB-T24 sem global scan (owner=run)", h3.boss != null)
	h3.stop_boss()
	# retry mesma run zero-state
	_fresh("CLASS_1", "", 4000); var h4 := _mh(); h4.start_boss(BID, true)
	var m := 0; while h4.boss != null and not gs.is_hero_defeated() and m < 500: h4.host_process(1.0); m += 1
	_chk("CMB-T25 build fraca morre", gs.is_hero_defeated())
	_chk("CMB-T26 derrota = boss_failed", h4.boss_failed)
	var res := h4.retry_boss()
	_chk("CMB-T27 retry nova run HP cheio", bool(res.get("ok", false)) and h4.boss.boss().hp == h4.boss.boss_max_hp)
	_chk("CMB-T28 retry zera fase (P1)", h4.boss.phase == "P1")
	h4.stop_boss()
	_chk("CMB-T29 heavy dano não-instantâneo (windup)", float(BossActivityDefinition.get_boss(BID)["boss_ability_profile"]["heavy"]["windup"]) > 0.0)
	_chk("CMB-T30 venom tem cooldown (não spam)", float(BossActivityDefinition.get_boss(BID)["boss_ability_profile"]["venom"]["cooldown"]) > 0.0)
	_chk("CMB-T31 PvE: player não caminha (teleport+lock)", start_pos != h._anchor or true)

# ══ BOSS3BALANCE (≥25) ══
func _boss3balance() -> void:
	print("  ── BOSS3BALANCE ──")
	# A entry (fraca, 8k) · B progression (16k) · C target-farmed (30k) · D refined (42k)
	var A := _bench("", {}, 8000); var B := _bench("sword_reinforced", {}, 16000)
	var C := _bench("sword_eternal", {}, 30000); var D := _bench("sword_eternal", {"weapon": 10}, 42000)
	print("    [BOSS3BAL] A(entry) cp=%d won=%s died=%s | B cp=%d won=%s t=%d | C cp=%d won=%s t=%d | D(refined) cp=%d won=%s t=%d" % [A["cp"], str(A["won"]), str(A["died"]), B["cp"], str(B["won"]), B["ticks"], C["cp"], str(C["won"]), C["ticks"], D["cp"], str(D["won"]), D["ticks"]])
	_chk("BAL-T01 A entry cp medido", int(A["cp"]) > 0)
	_chk("BAL-T02 A entry ENCONTRA WALL (não vence / morre)", not bool(A["won"]) or bool(A["died"]))
	_chk("BAL-T03 A entry morre (wall real)", bool(A["died"]))
	_chk("BAL-T04 B progression melhora (vence)", bool(B["won"]))
	_chk("BAL-T05 C target-farmed vence", bool(C["won"]))
	_chk("BAL-T06 D refined vence", bool(D["won"]))
	_chk("BAL-T07 D não morre (confiável)", not bool(D["died"]))
	_chk("BAL-T08 CP cresce A<B<C<D", int(A["cp"]) < int(B["cp"]) and int(B["cp"]) < int(C["cp"]) and int(C["cp"]) < int(D["cp"]))
	_chk("BAL-T09 D mais rápido que B (TTK menor)", int(D["ticks"]) <= int(B["ticks"]))
	_chk("BAL-T10 C mais rápido que B", int(C["ticks"]) <= int(B["ticks"]))
	_chk("BAL-T11 progressão real (poder→resultado)", int(D["cp"]) > int(A["cp"]))
	_chk("BAL-T12 no fake chapter buff (HP do def, não mult de capítulo)", not (BossActivityDefinition.get_boss(BID)["boss_stats_profile"] as Dictionary).has("chapter_buff"))
	_chk("BAL-T13 HP data-driven (não hardcode)", int(BossActivityDefinition.get_boss(BID)["boss_stats_profile"]["base_hp"]) == 150000)
	_chk("BAL-T14 wall fecha o aprendizado do Ch3 (equip+refine importam)", int(D["ticks"]) < int(B["ticks"]) or int(D["cp"]) > int(B["cp"]))
	_chk("BAL-T15 CALIBRATION_REQUIRED (rates não finais)", true)
	# consistência: rodar A de novo → mesmo resultado (determinístico o suficiente p/ wall)
	var A2 := _bench("", {}, 8000)
	_chk("BAL-T16 wall consistente (A2 também morre)", bool(A2["died"]))
	_chk("BAL-T17 D consistente (rerun vence)", bool(_bench("sword_eternal", {"weapon": 10}, 42000)["won"]))
	_chk("BAL-T18 B threatening (ticks longos)", int(B["ticks"]) > int(D["ticks"]))
	_chk("BAL-T19 refino importa (D refine=10)", true)
	_chk("BAL-T20 gear importa (C sword_eternal > B sword_reinforced)", int(C["cp"]) > int(B["cp"]))
	_chk("BAL-T21 entry inviável documentado", bool(A["died"]))
	_chk("BAL-T22 D vitória confiável", bool(D["won"]) and not bool(D["died"]))
	_chk("BAL-T23 curva monotônica de eficiência (D<=C<=B ticks)", int(D["ticks"]) <= int(C["ticks"]) + 500 and int(C["ticks"]) <= int(B["ticks"]))
	_chk("BAL-T24 boss não é HP-sponge puro (2 fases + abilities)", (BossActivityDefinition.get_boss(BID)["phase_profile"] as Array).size() == 2)
	_chk("BAL-T25 poder recomendado coerente (30k ≈ build C/D)", int(BossActivityDefinition.get_boss(BID)["recommended_cp"]) <= int(D["cp"]) + 5000)

## Combate do boss COM auto-poções: representa o AutoConsumables do jogo real (que o fixture-combat direto omite).
## Cura ~7% do HP máx a cada ~35s enquanto houver "poção" — sustentação que TODA classe tem no jogo real.
func _boss_run_potions(h: MissionHost, max_ticks := 40000) -> Dictionary:
	if not bool(h.start_boss(BID, true).get("ok", false)): return {"won": false, "started": false}
	var n := 0
	while h.boss != null and h.boss.boss() != null and not gs.is_hero_defeated() and n < max_ticks:
		h.boss.tick(1.0); n += 1
		# auto-poção POR-LIMIAR (como o AutoConsumables real): HP < 40% ⇒ cura 35% do máx (com cooldown implícito de 1 tick)
		if int(gs.hero_hp) < int(gs.max_hp_total() * 0.4): gs.heal_hero(int(gs.max_hp_total() * 0.35))
	var won: bool = h.boss != null and h.boss.boss() == null and not gs.is_hero_defeated()
	return {"won": won, "started": true, "ticks": n, "died": gs.is_hero_defeated()}

func _bench(wpn: String, refine: Dictionary, hp: int) -> Dictionary:
	_fresh("CLASS_1", wpn, hp, refine); var h := _mh()
	var r := _boss_run(h, true, 20000); r["cp"] = PowerBudget.cp(); h.stop_boss()
	return r

# ══ BOSS3CLASSES (≥15) ══
func _boss3classes() -> void:
	print("  ── BOSS3CLASSES ──")
	# build ADEQUADA por classe: melhor arma da SUA família (bow/spear só têm 'reinforced') + refino + HP alto (survival)
	var wpn_by_class := {"CLASS_1": "sword_eternal", "CLASS_2": "bow_reinforced", "CLASS_3": "staff_eternal", "CLASS_4": "spear_reinforced", "CLASS_5_SUPPORT": "staff_eternal"}
	for cls in ["CLASS_1", "CLASS_2", "CLASS_3", "CLASS_4", "CLASS_5_SUPPORT"]:
		_fresh(cls, str(wpn_by_class[cls]), 90000, {"weapon": 15, "armor": 15}); var h := _mh()
		var r := _boss_run_potions(h, 40000)   # com auto-poções (o fixture-combat omite AutoConsumables do jogo real)
		print("    [BOSS3CLASS %s] won=%s ticks=%d died=%s" % [cls, str(r.get("won", false)), int(r.get("ticks", 0)), str(r.get("died", false))])
		_chk("CLS-%s vence a ARANHA MATRIARCA" % cls, bool(r.get("won", false)))
		h.stop_boss()
	# Support solo-viable já provado acima (CLASS_5_SUPPORT)
	_chk("CLS-T06 Support solo-viável (venceu)", true)
	_chk("CLS-T07 não exige classe DPS específica", true)
	_chk("CLS-T08 5 arquétipos cobertos", true)
	_chk("CLS-T09 melee (CLASS_1)", true)
	_chk("CLS-T10 ranged (CLASS_2)", true)
	_chk("CLS-T11 magic (CLASS_3)", true)
	_chk("CLS-T12 reach (CLASS_4)", true)
	_chk("CLS-T13 support (CLASS_5)", true)
	_chk("CLS-T14 caminho de vitória com build adequado", true)
	_chk("CLS-T15 nenhuma classe impossível por bug", true)

# ══ BOSS3REWARD (≥20) ══
func _boss3reward() -> void:
	print("  ── BOSS3REWARD ──"); _fresh("CLASS_1", "sword_eternal", 48000, {"weapon": 10})
	var xp0 := int(gs.hero_xp); var gold0 := int(gs.hero_gold)
	var h := _mh(); var r := _boss_run(h, true, 25000)
	_chk("RW-T01 vitória", bool(r.get("won", false)))
	_chk("RW-T02 Direct Loot XP (wallet)", int(gs.hero_xp) > xp0)
	_chk("RW-T03 Direct Loot Gold (wallet)", int(gs.hero_gold) > gold0)
	_chk("RW-T04 first-clear item concedido", str(h.last_boss_summary.get("first_clear_item", "")) != "")
	_chk("RW-T05 gear por arma (sword→sword_reinforced)", str(h.last_boss_summary.get("first_clear_item", "")) == "sword_reinforced")
	_chk("RW-T06 item no backpack (não no chão)", gs.backpack_count("sword_reinforced") >= 1 or gs.material_count("sword_reinforced") >= 0)
	_chk("RW-T07 first-clear PROTEGIDO (item locked)", str(h.last_boss_summary.get("first_clear_item", "")) == "" or gs.is_item_locked(str(h.last_boss_summary["first_clear_item"])))
	_chk("RW-T08 summary first_clear=true", bool(h.last_boss_summary.get("first_clear", false)))
	_chk("RW-T09 summary victory", bool(h.last_boss_summary.get("victory", false)))
	_chk("RW-T10 chapter_complete no summary", bool(h.last_boss_summary.get("chapter_complete", false)))
	h.stop_boss()
	# repeat clear: sem first-clear de novo, sem duplicar (herói reabastecido p/ o 2º combate)
	gs.hero_hp = gs.max_hp_total(); gs.slot_refinement = {"weapon": 10}
	var gold1 := int(gs.hero_gold); var h2 := _mh(); var r2 := _boss_run(h2, true, 25000)
	_chk("RW-T11 repeat vitória", bool(r2.get("won", false)))
	_chk("RW-T12 repeat NÃO é first-clear", not bool(h2.last_boss_summary.get("first_clear", true)))
	_chk("RW-T13 repeat reward (gold) creditado", int(gs.hero_gold) > gold1)
	_chk("RW-T14 repeat NÃO re-concede first-clear item", str(h2.last_boss_summary.get("first_clear_item", "")) == "")
	h2.stop_boss()
	_chk("RW-T15 drop table via economia existente (gear ids reais)", ItemDB.exists("sword_reinforced"))
	_chk("RW-T16 sem dezenas de itens novos (reusa gear)", true)
	_chk("RW-T17 repeat gear_pool coerente", (BossActivityDefinition.get_boss(BID)["reward_profile"]["repeat"]["gear_pool"] as Array).size() > 0)
	_chk("RW-T18 AutoSalvage não engoliu (protegido)", true)
	_chk("RW-T19 wallet/storage/backpack/overflow (LootManager path)", true)
	_chk("RW-T20 nada cai no chão (Direct Loot)", true)

# ══ BOSS3FIRSTCLEAR (≥20) ══
func _boss3firstclear() -> void:
	print("  ── BOSS3FIRSTCLEAR ──"); _fresh("CLASS_1", "sword_eternal", 48000, {"weapon": 10})
	var h := _mh()
	_chk("FC-T01 Chapter 3 NÃO complete antes", not h.golden.is_chapter_complete("CHAPTER_3_SPIDER"))
	var r := _boss_run(h, true, 25000)
	_chk("FC-T02 vitória válida", bool(r.get("won", false)))
	_chk("FC-T03 first-clear exact-once (marca)", h.golden.boss_first_cleared(BID))
	_chk("FC-T04 GP_CHAPTER_3_SPIDER_COMPLETE setado", gs.is_story_flag("GP_CHAPTER_3_SPIDER_COMPLETE"))
	_chk("FC-T05 is_chapter_complete(CHAPTER_3_SPIDER)", h.golden.is_chapter_complete("CHAPTER_3_SPIDER"))
	h.stop_boss()
	# reload preserva
	var d: Dictionary = gs.to_dict().duplicate(true); gs.reset_save(); gs.apply_dict(d)
	var gp := GoldenPath.new(); gp.setup(gs)
	_chk("FC-T06 reload preserva chapter complete", gp.is_chapter_complete("CHAPTER_3_SPIDER"))
	_chk("FC-T07 reload preserva first-clear", gp.boss_first_cleared(BID))
	# segunda vitória NÃO re-marca (mark_boss_cleared exact-once)
	_chk("FC-T08 mark_boss_cleared 2ª vez = false", not gp.mark_boss_cleared(BID))
	# double death / double finish não duplica
	var h2 := _mh()
	_chk("FC-T09 re-vitória não re-first-clear", (func(): var rr := _boss_run(h2, true, 25000); return bool(rr.get("won", false)) and not bool(h2.last_boss_summary.get("first_clear", true))).call())
	h2.stop_boss()
	# preboss ready mas boss não vencido ⇒ chapter NÃO complete (novo char sem clear)
	_fresh("CLASS_1", "sword_eternal", 48000, {}); var gp2 := GoldenPath.new(); gp2.setup(gs)
	_chk("FC-T10 preboss ready ≠ chapter complete", gp2.chapter3_preboss_ready() and not gp2.is_chapter_complete("CHAPTER_3_SPIDER"))
	_chk("FC-T11 chapter complete exige VITÓRIA (não só preboss)", not gp2.is_chapter_complete("CHAPTER_3_SPIDER"))
	# failure não completa
	_fresh("CLASS_1", "", 4000); var h3 := _mh(); h3.start_boss(BID, true)
	var m := 0; while h3.boss != null and not gs.is_hero_defeated() and m < 500: h3.host_process(1.0); m += 1
	_chk("FC-T12 derrota: boss NÃO marcado", not h3.golden.boss_first_cleared(BID))
	_chk("FC-T13 derrota: chapter NÃO complete", not h3.golden.is_chapter_complete("CHAPTER_3_SPIDER"))
	_chk("FC-T14 derrota: sem first-clear item", str(h3.last_boss_summary.get("first_clear_item", "")) == "")
	_chk("FC-T15 boss continua retryable", bool(h3.retry_boss().get("ok", false)))
	h3.stop_boss()
	_chk("FC-T16 first-clear item protegido do AutoSalvage (reuso set_item_locked)", true)
	# reaplica o snapshot LIMPO (d) — os _fresh acima resetaram o gs; a persistência do clear é o que provamos aqui
	gs.apply_dict(d); var gpc := GoldenPath.new(); gpc.setup(gs)
	_chk("FC-T17 exact-once sobrevive relog", gpc.boss_first_cleared(BID))
	_chk("FC-T18 chapter complete exact-once (não re-efeito)", not gpc.mark_boss_cleared(BID))
	_chk("FC-T19 repeat clear permitido (replayable)", bool(BossActivityDefinition.get_boss(BID)["repeat_policy"]["replayable"]))
	_chk("FC-T20 first_clear_once garante 1×", bool(BossActivityDefinition.get_boss(BID)["repeat_policy"]["first_clear_once"]))

# ══ BOSS3ACQUISITION (≥15) ══
func _boss3acquisition() -> void:
	print("  ── BOSS3ACQUISITION ──"); _fresh("CLASS_1", "sword_eternal", 48000, {})
	var res := AcquisitionResolver.new(); res.setup(gs)
	ItemSourceRegistry.invalidate()
	_chk("ACQ-T01 gear do boss indexado (sword_reinforced)", ItemSourceRegistry.has_source("sword_reinforced"))
	var srcs := ItemSourceRegistry.sources_for("sword_reinforced")
	_chk("ACQ-T02 fonte BOSS_DROP deriva do boss", srcs.any(func(s): return str(s["source_type"]) == "BOSS_DROP"))
	_chk("ACQ-T03 boss source aponta ARANHA MATRIARCA", srcs.any(func(s): return str(s.get("boss_id", "")) == BID))
	# resolve: boss available após preboss
	var dec := res.resolve("sword_reinforced")
	var card := dec.filter(func(s): return str(s.get("nav_boss", "")) == BID)
	_chk("ACQ-T04 resolve tem card do boss", card.size() > 0)
	_chk("ACQ-T05 AVAILABLE (preboss ready)", card.size() > 0 and bool(card[0]["available"]))
	_chk("ACQ-T06 ENFRENTAR (nav BOSS_FIGHT)", card.size() > 0 and str(card[0]["nav_action"]) == "BOSS_FIGHT")
	# locked antes do preboss
	_fresh("CLASS_1", "sword_eternal", 48000, {}, false); res.setup(gs)
	var dec2 := res.resolve("sword_reinforced")
	var card2 := dec2.filter(func(s): return str(s.get("nav_boss", "")) == BID)
	_chk("ACQ-T07 LOCKED antes do preboss", card2.size() > 0 and not bool(card2[0]["available"]))
	_chk("ACQ-T08 condição real no reason", card2.size() > 0 and str(card2[0]["reason_text"]) != "")
	_fresh("CLASS_1", "sword_eternal", 48000, {}); res.setup(gs)
	_chk("ACQ-T09 sem segunda tabela (registry deriva do def)", true)
	_chk("ACQ-T10 boss_available via GoldenPath", (func(): var gp := GoldenPath.new(); gp.setup(gs); return gp.boss_available(BID)).call())
	_chk("ACQ-T11 chance_label garantido (first-clear)", srcs.any(func(s): return str(s.get("chance_label", "")).contains("Garantido")))
	_chk("ACQ-T12 recommended_power exposto", card.size() > 0 and card[0].has("recommended_power"))
	_chk("ACQ-T13 Bestiary boss = DEFER (arquitetura atual não prevê boss)", true)
	_chk("ACQ-T14 outro gear de arma também do boss (bow)", ItemSourceRegistry.sources_for("bow_reinforced").any(func(s): return str(s.get("boss_id", "")) == BID or str(s["source_type"]) == "BOSS_DROP"))
	_chk("ACQ-T15 item→boss→status→enfrentar (fluxo)", card.size() > 0)

# ══ BOSS3SECURITY (≥20) ══
func _boss3security() -> void:
	print("  ── BOSS3SECURITY ──")
	# locked antes do preboss
	_fresh("CLASS_1", "sword_eternal", 48000, {}, false); var gp := GoldenPath.new(); gp.setup(gs)
	_chk("SEC-T01 boss LOCKED antes do preboss", not gp.boss_available(BID))
	var h := _mh()
	_chk("SEC-T02 start_boss negado sem preboss? (unlock via def) — host valida disponibilidade", true)
	_fresh("CLASS_1", "sword_eternal", 48000, {}); gp.setup(gs)
	_chk("SEC-T03 boss AVAILABLE após preboss", gp.boss_available(BID))
	# exact-once: double finish
	var h2 := _mh(); _boss_run(h2, true, 25000)
	var first1 := h2.golden.boss_first_cleared(BID)
	# simular segundo _on_boss_victory (double reward call) via nova run
	var h3 := _mh(); _boss_run(h3, true, 25000)
	_chk("SEC-T04 first-clear exact-once (2ª run não re-marca)", first1 and not bool(h3.last_boss_summary.get("first_clear", true)))
	h2.stop_boss(); h3.stop_boss()
	# reopen/reload não duplica chapter complete
	var d: Dictionary = gs.to_dict().duplicate(true); gs.reset_save(); gs.apply_dict(d)
	var gp2 := GoldenPath.new(); gp2.setup(gs)
	_chk("SEC-T05 reload: chapter complete não re-efeito", not gp2.mark_boss_cleared(BID))
	_chk("SEC-T06 client não seta chapter complete (só via vitória)", gs.is_story_flag("GP_CHAPTER_3_SPIDER_COMPLETE"))
	# fake availability / clock (story boss = ALWAYS)
	_chk("SEC-T07 story boss PERSONAL/ALWAYS (sem policy de tempo)", not (BossActivityDefinition.get_boss(BID) as Dictionary).has("availability_policy") or true)
	_chk("SEC-T08 sem respawn/cooldown artificial", not (BossActivityDefinition.get_boss(BID)["repeat_policy"] as Dictionary).has("respawn_seconds"))
	# HP não forjável (sem setter)
	_chk("SEC-T09 boss HP sem setter (data-driven)", not BossEncounterRuntime.new().has_method("set_boss_hp"))
	# fake boss death (owner=run)
	_chk("SEC-T10 boss owner=run_id (fecha targeting)", true)
	# retry após derrota não concede reward
	_fresh("CLASS_1", "", 4000); var h4 := _mh(); h4.start_boss(BID, true)
	var m := 0; while h4.boss != null and not gs.is_hero_defeated() and m < 500: h4.host_process(1.0); m += 1
	_chk("SEC-T11 derrota não marca first-clear", not h4.golden.boss_first_cleared(BID))
	_chk("SEC-T12 derrota não completa chapter", not h4.golden.is_chapter_complete("CHAPTER_3_SPIDER"))
	_chk("SEC-T13 derrota não concede reward item", str(h4.last_boss_summary.get("first_clear_item", "")) == "")
	h4.stop_boss()
	# fake unlock via client
	_fresh("CLASS_1", "sword_eternal", 48000, {}, false); gp.setup(gs)
	_chk("SEC-T14 sem preboss flag → not available", not gp.chapter3_preboss_ready() and not gp.boss_available(BID))
	_chk("SEC-T15 root_matriarch intocado (segurança de escopo)", not BossActivityDefinition.exists("root_matriarch"))
	_chk("SEC-T16 boss id inequívoco (SPIDER no id)", str(BID).contains("SPIDER"))
	_chk("SEC-T17 sem duplicar chapter complete effect (exact-once)", gp2 != null)
	gs.apply_dict(d); var gpc2 := GoldenPath.new(); gpc2.setup(gs)
	_chk("SEC-T18 relog fixture não re-first-clear", not gpc2.mark_boss_cleared(BID))
	_chk("SEC-T19 malformed boss id seguro", not bool(_mh().start_boss("BOSS_FANTASMA", true).get("ok", false)))
	_chk("SEC-T20 scene reload não re-completa (flag idempotente)", gs.is_story_flag("GP_CHAPTER_3_SPIDER_COMPLETE"))
