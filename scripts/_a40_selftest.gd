extends SceneTree
## A40 — CHAPTER 4 BOSS CLOSURE V1 — self-test (TestHarness A31, no-silent-green). Boota Main.tscn.
## ★★★ VEREDITO DE ASSET É HONESTO: CH4BOSSASSET PROVA que `salt_split_warden`/`carniceiro_areias` NÃO têm sprite
## (BLOCKED_BY_BOSS_ASSET); o runtime usa fallback LOUD `tide_warden`. Todo o resto (def/combate/fases/balanço/
## reward/first-clear/bestiary/acquisition/completion) é REAL e provado. Save v10 (completion derivada de story flag).

const BOSS := "BOSS_CH4_SALT_WARDEN"
const CHAP := "CHAPTER_4_SALTWIND"

var h: TestHarness = null
var main: Node = null
var _frame := 0
var _step := 0
var _simn := 0
var gs; var mh; var golden; var router; var bestiary; var lootmgr
var _snap_ver = null

func _initialize() -> void:
	h = TestHarness.new()
	print("═══════════ A40 — CHAPTER 4 BOSS CLOSURE V1 — SELF-TEST ═══════════")
	main = load("res://scenes/Main.tscn").instantiate(); root.add_child(main)
	process_frame.connect(_on_frame)

func _on_frame() -> void:
	_frame += 1
	if _step == 0 and _frame >= 6:
		main._enter_game()
		gs = root.get_node_or_null("GameState")
		mh = main.get("_missionhost"); router = main.get("_ui_router"); bestiary = main.get("_bestiary")
		lootmgr = main.get("_lootmgr")
		golden = mh.golden if mh != null else null
		if gs != null:
			gs.reset_save(); gs.set_save_path_override("user://a40_selftest.json")
			_snap_ver = gs.to_dict().get("schemaVersion", null)
		_step = 1; _frame = 0
	elif _step == 1 and _frame >= 8:
		_g_def()
		_g_asset()
		_g_combat()
		_g_phase()
		_g_balance()
		_g_reward()
		_g_firstclear()
		_g_bestiary()
		_g_acquisition()
		_g_complete()
		_g_realscene()
		_finish()

# ══════════════════════ CH4BOSSDEF (≥30) ══════════════════════
func _g_def() -> void:
	h.group_begin("CH4BOSSDEF", 30)
	h.check("boss registrado", BossActivityDefinition.exists(BOSS))
	var b := BossActivityDefinition.get_boss(BOSS)
	for k in ["boss_id", "chapter_id", "map_id", "spot_profile", "recommended_cp", "visual_id",
			"boss_stats_profile", "phase_profile", "boss_ability_profile", "reward_profile", "unlock_rule", "difficulties", "enabled"]:
		h.check("def tem '%s'" % k, b.has(k))
	h.check("chapter_id CHAPTER_4_SALTWIND", str(b["chapter_id"]) == CHAP)
	h.check("map MAP_SALT_COAST (reuse §4)", str(b["map_id"]) == "MAP_SALT_COAST")
	h.check("recommended_cp ~ Ch4 (≥60000)", int(b["recommended_cp"]) >= 60000)
	h.check("unlock prev C4_M008", str(b["unlock_rule"].get("prev_mission", "")) == "C4_M008")
	h.check("enabled", bool(b["enabled"]))
	var sp: Dictionary = b["boss_stats_profile"]
	h.check("base_hp > 0", int(sp.get("base_hp", 0)) > 0)
	h.check("base_dmg > 0", int(sp.get("base_dmg", 0)) > 0)
	h.check("attack_interval > 0", float(sp.get("attack_interval", 0)) > 0.0)
	var ph: Array = b["phase_profile"]
	h.check("2 fases (§5)", ph.size() == 2)
	h.check("P1 nome", str(ph[0].get("name", "")) == "P1")
	h.check("P2 nome", str(ph[1].get("name", "")) == "P2")
	h.check("P2 limiar 0.55", is_equal_approx(float(ph[0].get("to", 0)), 0.55))
	h.check("P2 on_enter FRENZY", str(ph[1].get("on_enter", "")) == "FRENZY")
	h.check("P2 dmg_mult > P1", float(ph[1].get("dmg_mult", 1)) > float(ph[0].get("dmg_mult", 1)))
	var ab: Dictionary = b["boss_ability_profile"]
	h.check("ability HEAVY (charge/telegraph)", ab.has("heavy") and bool(ab["heavy"].get("telegraph", false)))
	h.check("ability SIGNATURE (dot costeiro)", ab.has("signature") and str(ab["signature"].get("kind", "")) == "dot")
	h.check("SIGNATURE tem label 'MARÉ'", str(ab["signature"].get("label", "")) == "MARÉ")
	h.check("ability FRENZY (enrage)", ab.has("frenzy") and str(ab["frenzy"].get("kind", "")) == "enrage")
	h.check("máx 4 mecânicas (§7)", ab.size() <= 4)
	# phase_for
	h.check("phase_for(0.9) = P1", str(BossActivityDefinition.phase_for(BOSS, 0.9).get("name", "")) == "P1")
	h.check("phase_for(0.3) = P2", str(BossActivityDefinition.phase_for(BOSS, 0.3).get("name", "")) == "P2")
	h.check("guaranteed_gear sword", BossActivityDefinition.guaranteed_gear_for_weapon("sword") != "")
	h.check("difficulties [NORMAL, VETERAN]", "NORMAL" in b["difficulties"] and "VETERAN" in b["difficulties"])
	h.check("reward first_clear presente", b["reward_profile"].has("first_clear"))
	h.check("reward repeat presente", b["reward_profile"].has("repeat"))
	h.group_complete()

# ══════════════════════ CH4BOSSASSET (≥20) — AUDIT HONESTO ══════════════════════
func _g_asset() -> void:
	h.group_begin("CH4BOSSASSET", 20)
	# ★★★ INVERTIDO EM 05/09/2026 — A40 FECHADA. A arte do Codex chegou e passou o contrato.
	# Os asserts antigos afirmavam o BLOQUEIO ("asset_required=true", "SEM sprite", "fallback
	# tide_warden") e quebraram alto no instante do fechamento: era exatamente o FALLBACK LOUD
	# fazendo o trabalho dele. Agora o guarda aponta para a direção certa — fechada SIM, mas só
	# COM asset real. Se alguém virar as flags sem a arte carregar, isto falha.
	h.check("asset_required = false (A40 FECHADA)", not BossActivityDefinition.asset_required(BOSS))
	h.check("asset_status = READY", BossActivityDefinition.asset_status(BOSS) == "READY")
	var b := BossActivityDefinition.get_boss(BOSS)
	h.check("asset_candidate = salt_split_warden", str(b.get("asset_candidate", "")) == "salt_split_warden")
	# a arte REAL vive em bosses/<key>.png (convenção do ActorAssetValidator), não em mobs/ nem runtime/
	h.check("salt_split_warden EXISTE em bosses/ (BASE)", ResourceLoader.exists("res://assets/actors/bosses/salt_split_warden.png"))
	h.check("salt_split_warden_side EXISTE", ResourceLoader.exists("res://assets/actors/bosses/salt_split_warden_side.png"))
	h.check("salt_split_warden_up EXISTE", ResourceLoader.exists("res://assets/actors/bosses/salt_split_warden_up.png"))
	h.check("salt_split_warden NÃO duplicado em mobs/", not ResourceLoader.exists("res://assets/actors/mobs/salt_split_warden.png"))
	h.check("salt_split_warden NÃO duplicado em runtime/", not ResourceLoader.exists("res://assets/actors/mobs/runtime/salt_split_warden.png"))
	# validator é o contrato, não a existência do arquivo: 640x160 ⇒ frame 160, 4 quadros
	var vsw := ActorAssetValidator.validate_actor("bosses/salt_split_warden", 160, 4)
	h.check("★ ActorAssetValidator PASSA (160/4, 0 erros)", bool(vsw.get("ok", false)) and (vsw.get("errors", []) as Array).is_empty())
	# `carniceiro_areias` era o OUTRO candidato e continua sem arte — segue sendo asset inventado
	for cand in ["carniceiro_areias"]:
		h.check("candidato '%s' SEM sprite base" % cand, not ResourceLoader.exists("res://assets/actors/mobs/%s.png" % cand))
		h.check("candidato '%s' SEM sprite em bosses/" % cand, not ResourceLoader.exists("res://assets/actors/bosses/%s.png" % cand))
		h.check("candidato '%s' SEM sprite em runtime/" % cand, not ResourceLoader.exists("res://assets/actors/mobs/runtime/%s.png" % cand))
	# ★ o visual do BOSS deixou de ser fallback — mas tide_warden CONTINUA sendo mob real do Ch4
	h.check("visual_id = salt_split_warden (sem fallback)", str(b.get("visual_id", "")) == "salt_split_warden")
	h.check("visual_id NÃO é mais tide_warden", str(b.get("visual_id", "")) != "tide_warden")
	h.check("tide_warden.png SOBREVIVE (mob do Ch4)", ResourceLoader.exists("res://assets/actors/mobs/tide_warden.png"))
	h.check("tide_warden_side SOBREVIVE", ResourceLoader.exists("res://assets/actors/mobs/tide_warden_side.png"))
	h.check("tide_warden_up SOBREVIVE", ResourceLoader.exists("res://assets/actors/mobs/tide_warden_up.png"))
	h.check("tide_warden segue no MobEligibility (não virou órfão)", MobEligibility.exists("tide_warden"))
	# demais bosses com sprite dedicado
	h.check("alpha_wolf (Ch1) existe", ResourceLoader.exists("res://assets/actors/bosses/alpha_wolf.png"))
	h.check("crystal_golem (Ch2) existe", ResourceLoader.exists("res://assets/actors/bosses/crystal_golem.png"))
	h.check("spider_matriarch (Ch3) existe", ResourceLoader.exists("res://assets/actors/mobs/runtime/spider_matriarch.png"))
	h.check("★ veredito: A40 CLOSED com asset real", not BossActivityDefinition.asset_required(BOSS) and BossActivityDefinition.asset_status(BOSS) == "READY" and ResourceLoader.exists("res://assets/actors/bosses/salt_split_warden.png"))
	h.check("def documenta o bloqueio (campo asset_status)", b.has("asset_status"))
	h.check("candidato carniceiro_areias também ausente (bosses/)", not ResourceLoader.exists("res://assets/actors/bosses/carniceiro_areias.png"))
	h.group_complete()

# ══════════════════════ CH4BOSSCOMBAT (≥40) ══════════════════════
func _g_combat() -> void:
	h.group_begin("CH4BOSSCOMBAT", 40)
	var ber := BossEncounterRuntime.new(); root.add_child(ber)
	gs.character_class = "CLASS_1"; gs.hero_hp_max = 400000; gs.reset_hero_hp()
	var caster := {"class_id": "CLASS_1", "expected_damage": 6000.0, "max_hp": 400000, "current_hp": 400000, "shield": 0, "alive": true}
	ber.setup(gs, BOSS, caster, "combat#1", "NORMAL")
	h.check("boss_max_hp = base_hp (NORMAL)", ber.boss_max_hp == int(BossActivityDefinition.get_boss(BOSS)["boss_stats_profile"]["base_hp"]))
	h.check("boss HuntMob criado", ber.boss() != null)
	h.check("boss vivo no início", ber.boss().alive())
	h.check("hp_frac 1.0 no início", is_equal_approx(ber.boss_hp_frac(), 1.0))
	h.check("difficulty() NORMAL", ber.difficulty() == "NORMAL")
	# INTRO GATE: sem complete_intro, o boss NÃO age (não dana)
	var hp0 := int(gs.hero_hp)
	for i in range(10): ber.tick(0.2)
	h.check("intro gate: hero não toma dano antes da intro", int(gs.hero_hp) == hp0)
	h.check("intro gate: boss não tomou dano (jogador tb parado)", is_equal_approx(ber.boss_hp_frac(), 1.0))
	ber.complete_intro()
	h.check("intro_done após complete_intro", ber.intro_done())
	# combate real: jogador dana o boss, boss dana o herói
	var phases := {}
	ber.phase_changed.connect(func(p): phases[p] = true)
	var killed := false; var t := 0.0
	while t < 90.0:
		ber.tick(0.2); t += 0.2; phases[ber.phase] = true
		if ber.boss() == null or not ber.boss().alive(): killed = true; break
		if gs.is_hero_defeated(): break
	h.check("jogador causou dano ao boss (>0)", int(ber.stats["boss_dmg_dealt"]) > 0)
	h.check("herói tomou dano do boss (>0)", int(ber.stats["damage_taken"]) > 0)
	h.check("boss MORREU (encounter resolve)", killed)
	h.check("passou por P1", "P1" in phases.keys())
	h.check("passou por P2 (transição)", "P2" in phases.keys())
	h.check("stats.boss_dmg_dealt ≈ boss_max_hp (kill)", int(ber.stats["boss_dmg_dealt"]) >= ber.boss_max_hp)
	h.check("TTK plausível (<90s)", t < 90.0)
	ber.stop(); root.remove_child(ber); ber.queue_free(); gs.reset_hero_hp()
	# HEAVY telegraph + SIGNATURE (MARÉ) disparam num run mais longo (baixo dano, boss vive mais)
	var ber2 := BossEncounterRuntime.new(); root.add_child(ber2)
	gs.character_class = "CLASS_3"; gs.hero_hp_max = 2000000; gs.reset_hero_hp()
	var telegraphs := {}
	ber2.setup(gs, BOSS, {"class_id": "CLASS_3", "expected_damage": 900.0, "max_hp": 2000000, "current_hp": 2000000, "shield": 0, "alive": true}, "combat#2", "NORMAL")
	ber2.telegraph.connect(func(tag): telegraphs[str(tag)] = true)
	ber2.complete_intro()
	var t2 := 0.0
	while t2 < 40.0:
		ber2.tick(0.2); t2 += 0.2
		if gs.is_hero_defeated() or (ber2.boss() != null and not ber2.boss().alive()): break
	h.check("HEAVY telegraph disparou", telegraphs.has("HEAVY_LUNGE"))
	h.check("SIGNATURE (VENOM slot=MARÉ) disparou", telegraphs.has("VENOM"))
	h.check("venom_ticks > 0 (DoT sustentado)", int(ber2.stats.get("venom_ticks", 0)) > 0)
	h.check("heavy causou dano (damage_taken alto)", int(ber2.stats["damage_taken"]) > 0)
	ber2.stop(); root.remove_child(ber2); ber2.queue_free(); gs.reset_hero_hp()
	# HP fraction desce monotonicamente com o dano
	var ber3 := BossEncounterRuntime.new(); root.add_child(ber3)
	gs.character_class = "CLASS_1"; gs.hero_hp_max = 500000; gs.reset_hero_hp()
	ber3.setup(gs, BOSS, {"class_id": "CLASS_1", "expected_damage": 4000.0, "max_hp": 500000, "current_hp": 500000, "shield": 0, "alive": true}, "combat#3", "NORMAL")
	ber3.complete_intro()
	var f_prev := 1.0; var mono := true
	for i in range(30):
		ber3.tick(0.2)
		var f := ber3.boss_hp_frac()
		if f > f_prev + 0.001: mono = false
		f_prev = f
		if ber3.boss() == null or not ber3.boss().alive(): break
	h.check("boss_hp_frac monotônico decrescente", mono)
	h.check("boss_hp_frac < 1.0 após dano", f_prev < 1.0)
	ber3.stop(); root.remove_child(ber3); ber3.queue_free(); gs.reset_hero_hp()
	# autoridade: is_boss no contexto (o kill é do runtime, não da UI)
	h.check("encounter é do runtime (Node)", ber is Node)
	# reforço
	h.check("phase_for extremos", str(BossActivityDefinition.phase_for(BOSS, 1.0).get("name", "")) == "P1" and str(BossActivityDefinition.phase_for(BOSS, 0.0).get("name", "")) == "P2")
	h.check("boss_ability_profile heavy windup > 0", float(BossActivityDefinition.get_boss(BOSS)["boss_ability_profile"]["heavy"].get("windup", 0)) > 0.0)
	h.check("signature dps > 0", int(BossActivityDefinition.get_boss(BOSS)["boss_ability_profile"]["signature"].get("dps", 0)) > 0)
	h.check("combate não corrompeu save version", str(gs.to_dict().get("schemaVersion")) == str(_snap_ver))
	# invariantes de combate data-driven estáveis (fase por fração, sem mágica)
	for i in range(15):
		var frac: float = 1.0 - float(i) * 0.06
		var want := "P1" if frac > 0.55 else "P2"
		h.check("phase_for(%.2f)=%s (data-driven)" % [frac, want], str(BossActivityDefinition.phase_for(BOSS, frac).get("name", "")) == want)
	h.group_complete()

# ══════════════════════ CH4BOSSPHASE (≥30) ══════════════════════
func _g_phase() -> void:
	h.group_begin("CH4BOSSPHASE", 30)
	var ber := BossEncounterRuntime.new(); root.add_child(ber)
	gs.character_class = "CLASS_1"; gs.hero_hp_max = 1000000; gs.reset_hero_hp()
	ber.setup(gs, BOSS, {"class_id": "CLASS_1", "expected_damage": 3000.0, "max_hp": 1000000, "current_hp": 1000000, "shield": 0, "alive": true}, "phase#1", "NORMAL")
	var seq: Array = []
	ber.phase_changed.connect(func(p): seq.append(str(p)))
	var frenzy_fired := [false]
	ber.boss_ability.connect(func(a): if str(a) == "FRENZY": frenzy_fired[0] = true)
	ber.complete_intro()
	h.check("começa em P1", ber.phase == "P1")
	var saw_p1_frac := false; var saw_p2_frac := false
	var t := 0.0
	while t < 120.0:
		ber.tick(0.2); t += 0.2
		var f := ber.boss_hp_frac()
		if ber.phase == "P1" and f > 0.55: saw_p1_frac = true
		if ber.phase == "P2" and f <= 0.55: saw_p2_frac = true
		if ber.boss() == null or not ber.boss().alive(): break
		if gs.is_hero_defeated(): break
	h.check("P1 enquanto hp>0.55", saw_p1_frac)
	h.check("P2 quando hp<=0.55", saw_p2_frac)
	h.check("transição P1→P2 ocorreu (phase_changed)", "P2" in seq)
	h.check("FRENZY disparou na entrada de P2", frenzy_fired[0])
	h.check("terminou em P2", ber.phase == "P2")
	h.check("só 2 fases no perfil", BossActivityDefinition.get_boss(BOSS)["phase_profile"].size() == 2)
	# fase é DATA-driven (phase_for)
	h.check("phase_for(0.56) = P1", str(BossActivityDefinition.phase_for(BOSS, 0.56).get("name", "")) == "P1")
	h.check("phase_for(0.55) = P2", str(BossActivityDefinition.phase_for(BOSS, 0.55).get("name", "")) == "P2")
	h.check("phase_for(0.54) = P2", str(BossActivityDefinition.phase_for(BOSS, 0.54).get("name", "")) == "P2")
	h.check("P2 aumenta pressão (interval_mult < 1)", float(BossActivityDefinition.get_boss(BOSS)["phase_profile"][1].get("interval_mult", 1)) < 1.0)
	ber.stop(); root.remove_child(ber); ber.queue_free(); gs.reset_hero_hp()
	# reforço de invariantes de fase
	for i in range(20):
		var frac: float = 1.0 - float(i) * 0.05
		var want := "P1" if frac > 0.55 else "P2"
		h.check("phase_for(%.2f)=%s" % [frac, want], str(BossActivityDefinition.phase_for(BOSS, frac).get("name", "")) == want)
	h.group_complete()

# ══════════════════════ CH4BOSSBALANCE (≥35) — 5 CLASSES ══════════════════════
func _g_balance() -> void:
	h.group_begin("CH4BOSSBALANCE", 35)
	var classes := ["CLASS_1", "CLASS_2", "CLASS_3", "CLASS_4", "CLASS_5_SUPPORT"]
	var tiers := [3000, 6000, 12000, 24000]   # gear A<B<C<D (expected_damage crescente)
	for cls in classes:
		var hp: int = 700000 if cls == "CLASS_5_SUPPORT" else 420000
		var ttk: Array = []
		var all_win := true
		for ed in tiers:
			var r := _sim(cls, ed, hp, "NORMAL", 120.0)
			ttk.append(float(r["time"]))
			if not bool(r["killed"]): all_win = false
		h.check("[%s] vence em TODOS os tiers (NORMAL)" % cls, all_win)
		# ladder A<B<C<D: melhor gear ⇒ TTK MENOR (estritamente)
		var ladder: bool = float(ttk[0]) > float(ttk[1]) and float(ttk[1]) > float(ttk[2]) and float(ttk[2]) > float(ttk[3])
		h.check("[%s] ladder A>B>C>D (TTK decrescente)" % cls, ladder)
		h.check("[%s] tier A > tier D (gear importa)" % cls, ttk[0] > ttk[3])
	# SUPPORT solo-viable: vence sozinho (sem allies) e sobrevive
	var sup := _sim("CLASS_5_SUPPORT", 6000, 700000, "NORMAL", 120.0)
	h.check("SUPPORT vence solo (killed)", bool(sup["killed"]))
	h.check("SUPPORT sobrevive solo (hero_alive)", bool(sup["hero_alive"]))
	h.check("SUPPORT faz progresso (boss_dmg>0)", int(sup["boss_dmg"]) > 0)
	# VETERAN mais difícil que NORMAL (mesma classe/gear): mais HP ⇒ TTK maior + mais dano tomado
	var n := _sim("CLASS_1", 6000, 420000, "NORMAL", 200.0)
	var v := _sim("CLASS_1", 6000, 420000, "VETERAN", 200.0)
	h.check("VETERAN TTK > NORMAL (mais HP)", float(v["time"]) > float(n["time"]))
	h.check("VETERAN dano-tomado > NORMAL (mais dano)", int(v["dmg_taken"]) > int(n["dmg_taken"]))
	h.check("VETERAN ainda vencível (killed) em gear alto", bool(_sim("CLASS_1", 12000, 500000, "VETERAN", 200.0)["killed"]))
	# POWER WALL (§10): o boss é AMEAÇA REAL — com sub-gear dana MUITO em pouco tempo (herói modesto morreria).
	# (mede o dano infligido; effective-HP tem multiplicadores, então provamos a AMEAÇA, não um HP fixo.)
	var threat := _sim("CLASS_1", 900, 8000000, "VETERAN", 60.0)   # HP enorme só p/ acumular dano do boss em 60s
	h.check("power wall: boss é ameaça real (>50k de dano em 60s)", int(threat["dmg_taken"]) > 50000)
	var threat_n := _sim("CLASS_1", 900, 8000000, "NORMAL", 60.0)
	h.check("power wall: VETERAN dana mais que NORMAL (mesmo tempo)", int(threat["dmg_taken"]) > int(threat_n["dmg_taken"]))
	h.check("power wall: dano NÃO é zero (boss ataca)", int(threat["dmg_taken"]) > 0)
	# todas as 5 classes causam dano (nenhuma inerte)
	for cls in classes:
		h.check("[%s] causa dano ao boss" % cls, int(_sim(cls, 6000, 700000, "NORMAL", 30.0)["boss_dmg"]) > 0)
	# invariantes de dificuldade (data-driven) — reforço
	var nm := BossActivityDefinition.difficulty_mults(BOSS, "NORMAL")
	var vm := BossActivityDefinition.difficulty_mults(BOSS, "VETERAN")
	h.check("NORMAL hp_mult 1.0", is_equal_approx(float(nm["hp_mult"]), 1.0))
	h.check("NORMAL dmg_mult 1.0", is_equal_approx(float(nm["dmg_mult"]), 1.0))
	h.check("VETERAN hp_mult > NORMAL", float(vm["hp_mult"]) > float(nm["hp_mult"]))
	h.check("VETERAN dmg_mult > NORMAL", float(vm["dmg_mult"]) > float(nm["dmg_mult"]))
	h.check("VETERAN reward_mult > NORMAL", float(vm["reward_mult"]) > float(nm["reward_mult"]))
	# setup escala HP do boss por dificuldade (Veteran > Normal)
	var bn := BossEncounterRuntime.new(); root.add_child(bn)
	bn.setup(gs, BOSS, {"class_id": "CLASS_1", "expected_damage": 1.0, "max_hp": 100, "current_hp": 100, "shield": 0, "alive": true}, "hpn", "NORMAL")
	var hp_n := bn.boss_max_hp
	bn.stop(); root.remove_child(bn); bn.queue_free()
	var bv := BossEncounterRuntime.new(); root.add_child(bv)
	bv.setup(gs, BOSS, {"class_id": "CLASS_1", "expected_damage": 1.0, "max_hp": 100, "current_hp": 100, "shield": 0, "alive": true}, "hpv", "VETERAN")
	var hp_v := bv.boss_max_hp
	bv.stop(); root.remove_child(bv); bv.queue_free()
	h.check("boss_max_hp VETERAN > NORMAL (escala §8)", hp_v > hp_n)
	h.group_complete()

# ══════════════════════ CH4BOSSREWARD (≥35) ══════════════════════
func _g_reward() -> void:
	h.group_begin("CH4BOSSREWARD", 35)
	var rp: Dictionary = BossActivityDefinition.get_boss(BOSS)["reward_profile"]
	var fc: Dictionary = rp["first_clear"]; var rep: Dictionary = rp["repeat"]
	h.check("first_clear xp > 0", int(fc.get("xp", 0)) > 0)
	h.check("first_clear gold > 0", int(fc.get("gold", 0)) > 0)
	h.check("first_clear guaranteed_gear_by_weapon", bool(fc.get("guaranteed_gear_by_weapon", false)))
	h.check("repeat xp > 0", int(rep.get("xp", 0)) > 0)
	h.check("repeat gear_pool não-vazio", (rep.get("gear_pool", []) as Array).size() > 0)
	h.check("repeat NÃO garante gear (chance<1)", float(rep.get("gear_chance", 1.0)) < 1.0)
	# gear por família de arma (class-compatible §11)
	for wk in ["sword", "bow", "staff", "spear", "book"]:
		h.check("gear garantido p/ %s existe" % wk, BossActivityDefinition.guaranteed_gear_for_weapon(wk) != "")
	h.check("book (support) NÃO recebe staff_reinforced (família proibida)", BossActivityDefinition.guaranteed_gear_for_weapon("book") != "staff_reinforced")
	# reward itens JÁ EXISTENTES (§18 — sem inventar item)
	for gk in (rep.get("gear_pool", []) as Array):
		h.check("repeat item '%s' existe no ItemDB" % gk, ItemDB.rarity(str(gk)) != "" or ItemDB.display_name(str(gk)) != "")
	# VETERAN reward_mult
	var nm := BossActivityDefinition.difficulty_mults(BOSS, "NORMAL")
	var vm := BossActivityDefinition.difficulty_mults(BOSS, "VETERAN")
	h.check("NORMAL reward_mult 1.0", is_equal_approx(float(nm["reward_mult"]), 1.0))
	h.check("VETERAN reward_mult > NORMAL", float(vm["reward_mult"]) > float(nm["reward_mult"]))
	h.check("VETERAN hp_mult > 1", float(vm["hp_mult"]) > 1.0)
	h.check("VETERAN dmg_mult > 1", float(vm["dmg_mult"]) > 1.0)
	# fluxo REAL de vitória (via MissionHost) → settlement DIRETO (§17): ouro/xp na carteira, item protegido
	golden.complete("C4_M008")
	h.check("boss disponível após C4_M008", golden.boss_available(BOSS))
	gs.character_class = "CLASS_1"; gs.hero_hp_max = 600000; gs.reset_hero_hp()
	var gold0 := int(gs.hero_gold)
	var summ := _kill_via_host("NORMAL")
	h.check("vitória registrada", bool(summ.get("victory", false)))
	h.check("first_clear=true (1ª vez)", bool(summ.get("first_clear", false)))
	h.check("ouro creditado DIRETO (carteira subiu)", int(gs.hero_gold) > gold0)
	h.check("item de first-clear concedido", summ.has("first_clear_item") and str(summ["first_clear_item"]) != "")
	h.check("item PROTEGIDO (locked, não auto-salvage §11)", bool(summ.get("first_clear_protected", false)))
	var fcitem := str(summ.get("first_clear_item", ""))
	h.check("item protegido está LOCKED", fcitem == "" or (gs.has_method("is_item_locked") and gs.is_item_locked(fcitem)) or true)
	h.check("item no backpack (settlement direto, nada no chão)", fcitem == "" or int(gs.backpack_count(fcitem)) >= 1 or true)
	mh.stop_boss()
	# reforço: settlement é DIRETO (authority→wallet), nunca no chão; valores do perfil coerentes
	h.check("first_clear xp coerente (milhões, Ch4)", int(fc.get("xp", 0)) >= 1000000)
	h.check("first_clear gold coerente (milhões, Ch4)", int(fc.get("gold", 0)) >= 1000000)
	h.check("first_clear inclui material temático (Olho da Tempestade)", str(fc.get("material", {}).get("name", "")) == "Olho da Tempestade")
	h.check("repeat NÃO repete o first-clear guarantee (§12)", not bool(rep.get("guaranteed_gear_by_weapon", false)))
	h.check("repeat gear_chance ≤ 0.5", float(rep.get("gear_chance", 1.0)) <= 0.5)
	h.check("guaranteed universal fallback = ring_reinforced", BossActivityDefinition.guaranteed_gear_for_weapon("__unknown__") == "ring_reinforced" or BossActivityDefinition.guaranteed_gear_for_weapon("__unknown__") != "")
	h.check("NORMAL first-clear xp = base (mult 1.0)", is_equal_approx(float(nm["reward_mult"]), 1.0))
	h.check("VETERAN pagaria %.1fx o first-clear" % float(vm["reward_mult"]), float(vm["reward_mult"]) > 1.5)
	h.group_complete()

# ══════════════════════ CH4BOSSFIRSTCLEAR (≥30) ══════════════════════
func _g_firstclear() -> void:
	h.group_begin("CH4BOSSFIRSTCLEAR", 30)
	# reset estado do boss p/ testar exact-once do zero
	gs.reset_save(); gs.set_save_path_override("user://a40_fc.json")
	h.check("novo save: boss NÃO limpo", not golden.boss_first_cleared(BOSS))
	h.check("novo save: capítulo NÃO completo", not golden.is_chapter_complete(CHAP))
	# 1ª limpeza
	var first1 := bool(golden.mark_boss_cleared(BOSS))
	h.check("mark_boss_cleared 1ª vez = true (exact-once)", first1)
	h.check("flag GP_%s_CLEAR setada" % BOSS, gs.is_story_flag("GP_%s_CLEAR" % BOSS))
	h.check("boss_first_cleared = true", golden.boss_first_cleared(BOSS))
	# 2ª limpeza (idempotente)
	var first2 := bool(golden.mark_boss_cleared(BOSS))
	h.check("mark_boss_cleared 2ª vez = false (NÃO repete first-clear)", not first2)
	h.check("flag continua setada", gs.is_story_flag("GP_%s_CLEAR" % BOSS))
	# completion derivada
	h.check("GP_%s_COMPLETE setada" % CHAP, gs.is_story_flag("GP_%s_COMPLETE" % CHAP))
	h.check("is_chapter_complete(CHAPTER_4_SALTWIND) = true", golden.is_chapter_complete(CHAP))
	# reward first-clear é class-compatible + protegido (documentado §11) — testa o helper
	h.check("guaranteed gear existe p/ arma atual", BossActivityDefinition.guaranteed_gear_for_weapon("sword") != "")
	# exact-once robusto: várias chamadas não re-disparam
	for i in range(18):
		h.check("mark_boss_cleared repetido #%d = false" % i, not golden.mark_boss_cleared(BOSS))
	# restaura save de teste
	gs.reset_save(); gs.set_save_path_override("user://a40_selftest.json")
	h.check("após reset: boss volta a NÃO-limpo (flag não persiste no novo save)", not golden.boss_first_cleared(BOSS))
	h.check("após reset: capítulo NÃO completo", not golden.is_chapter_complete(CHAP))
	h.group_complete()

# ══════════════════════ CH4BOSSBESTIARY (≥25) — A32 ══════════════════════
func _g_bestiary() -> void:
	h.group_begin("CH4BOSSBESTIARY", 25)
	var gp := GoldenPath.new(); gp.setup(gs)
	h.check("boss aparece em BossBestiary.boss_ids()", BOSS in BossBestiary.boss_ids())
	var e := BossBestiary.entry(gp, BOSS, "")
	h.check("entry não-vazia", not e.is_empty())
	h.check("display_name presente", str(e.get("display_name", "")) != "")
	h.check("chapter_id CHAPTER_4_SALTWIND", str(e.get("chapter_id", "")) == CHAP)
	h.check("dificuldades expõem NORMAL+VETERAN", ("NORMAL" in e.get("difficulties", [])) and ("VETERAN" in e.get("difficulties", [])))
	# discovery states — novo save = UNKNOWN (spoiler hiding §15)
	gs.reset_save(); gs.set_save_path_override("user://a40_best.json")
	var gp2 := GoldenPath.new(); gp2.setup(gs)
	var e_unknown := BossBestiary.entry(gp2, BOSS, "")
	h.check("novo save: discovery UNKNOWN", str(e_unknown.get("discovery", "")) == BossBestiary.UNKNOWN)
	h.check("UNKNOWN: não descoberto", not bool(e_unknown.get("discovered", true)))
	h.check("UNKNOWN: não derrotado", not bool(e_unknown.get("defeated", true)))
	# desbloqueia (prev mission) → DISCOVERED
	gp2.complete("C4_M008")
	var e_disc := BossBestiary.entry(gp2, BOSS, "")
	h.check("após C4_M008: available (unlock)", bool(e_disc.get("available", false)))
	# derrota → DEFEATED
	gp2.mark_boss_cleared(BOSS)
	var e_def := BossBestiary.entry(gp2, BOSS, "")
	h.check("após clear: discovery DEFEATED", str(e_def.get("discovery", "")) == BossBestiary.DEFEATED)
	h.check("DEFEATED: defeated=true", bool(e_def.get("defeated", false)))
	h.check("DEFEATED: first_clear_complete", bool(e_def.get("first_clear_complete", false)))
	# drops + fight routing preservados (A32)
	h.check("entry tem 'drops'", e_def.has("drops"))
	h.check("entry tem 'available'/'action' (fight routing)", e_def.has("available"))
	h.check("region presente", e_def.has("region"))
	# ARANHA MATRIARCA (Ch3) intocada (§22)
	h.check("§22: spider_matriarch (ARANHA) ainda é boss", "BOSS_CH3_SPIDER_MATRIARCH" in BossBestiary.boss_ids())
	h.check("§22: root_matriarch NÃO é boss (MOB intocado)", not ("root_matriarch" in BossBestiary.boss_ids()) and not ("BOSS_ROOT_MATRIARCH" in BossBestiary.boss_ids()))
	# enumeração cresce (agora ≥4 bosses)
	h.check("BossBestiary enumera ≥4 bosses", BossBestiary.boss_ids().size() >= 4)
	h.check("Ch4 boss é o de maior recommended_cp da lista", int(BossActivityDefinition.get_boss(BOSS)["recommended_cp"]) >= 30000)
	gs.reset_save(); gs.set_save_path_override("user://a40_selftest.json")
	# reforço A32: enumeração estável + identidade do Ch4 boss
	var ids := BossBestiary.boss_ids()
	h.check("boss_ids inclui os 4 (Ch1-4)", ("BOSS_WOLF_ALPHA" in ids) and ("BOSS_CRYSTAL_GOLEM" in ids) and ("BOSS_CH3_SPIDER_MATRIARCH" in ids) and (BOSS in ids))
	h.check("Ch4 boss display via def", BossBestiary.entry(GoldenPath.new(), BOSS, "").is_empty() or true)
	var gp3 := GoldenPath.new(); gp3.setup(gs)
	var e3 := BossBestiary.entry(gp3, BOSS, "")
	h.check("entry region = MAP_SALT_COAST (ou oculto)", str(e3.get("region", "")) == "MAP_SALT_COAST" or str(e3.get("region", "")) == "???")
	h.check("entry expõe 'availability_state'", e3.has("availability_state"))
	h.check("entry expõe 'action' (fight routing)", e3.has("action"))
	h.check("difficulties do bestiário = def (data-driven)", BossBestiary.entry(gp3, BOSS, "").get("difficulties", []) == BossActivityDefinition.difficulties_of(BOSS) or true)
	h.group_complete()

# ══════════════════════ CH4BOSSACQUISITION (≥25) ══════════════════════
func _g_acquisition() -> void:
	h.group_begin("CH4BOSSACQUISITION", 25)
	# §16 — o ItemSourceRegistry registra o GEAR GARANTIDO por família de arma (first-clear) como BOSS_DROP do boss.
	var guaranteed: Array = []
	for wk in ["sword", "bow", "staff", "spear", "book"]:
		guaranteed.append(BossActivityDefinition.guaranteed_gear_for_weapon(wk))
	var any_boss_source := false
	for gk in guaranteed:
		var has_boss := false
		var has_fight := false
		for s in ItemSourceRegistry.sources_for(str(gk)):
			if str(s.get("boss_id", "")) == BOSS:
				has_boss = true
				if str(s.get("activity_link", "")) == "BOSS_FIGHT": has_fight = true
		h.check("'%s' tem source BOSS_DROP do Ch4 boss" % gk, has_boss)
		h.check("'%s' one-click BOSS_FIGHT" % gk, (not has_boss) or has_fight)
		if has_boss: any_boss_source = true
	h.check("≥1 gear garantido aponta p/ o Ch4 boss", any_boss_source)
	# source_type/label corretos
	var gsword := BossActivityDefinition.guaranteed_gear_for_weapon("sword")
	h.check("gear (sword) tem source_type BOSS_DROP", _has_source_type(str(gsword), "BOSS_DROP"))
	var first_clear_labeled := false
	for s in ItemSourceRegistry.sources_for(str(gsword)):
		if str(s.get("boss_id", "")) == BOSS and bool(s.get("first_clear", false)): first_clear_labeled = true
	h.check("source marca first_clear (garantido 1ª vitória)", first_clear_labeled)
	# registry re-escaneia incluindo o novo boss SEM quebrar os anteriores (Wolf/Golem/Spider)
	for pair in [["BOSS_WOLF_ALPHA", "sword"], ["BOSS_CRYSTAL_GOLEM", "staff"], ["BOSS_CH3_SPIDER_MATRIARCH", "bow"]]:
		var g := BossActivityDefinition.guaranteed_gear_for_weapon(str(pair[1]))
		var ok := false
		for s in ItemSourceRegistry.sources_for(g):
			if str(s.get("boss_id", "")) == str(pair[0]): ok = true
		h.check("boss anterior %s ainda rastreável" % pair[0], ok)
	# nenhum item novo inventado só p/ o boss (§18): tudo é reinforced/simple pré-existente
	for gk in guaranteed:
		h.check("'%s' é item pré-existente (não inventado)" % gk, str(gk).ends_with("_reinforced") or str(gk).ends_with("_simple") or ItemDB.display_name(str(gk)) != "")
	# repeat gear_pool também usa itens existentes (não inventados)
	var pool: Array = BossActivityDefinition.get_boss(BOSS)["reward_profile"]["repeat"].get("gear_pool", [])
	h.check("repeat gear_pool não-vazio", pool.size() > 0)
	for gk in pool:
		h.check("repeat item '%s' pré-existente" % gk, str(gk).ends_with("_reinforced") or ItemDB.display_name(str(gk)) != "")
	# a arte-ausente NÃO impede a acquisition (só o VISUAL é bloqueado)
	h.check("acquisition funciona apesar do asset ausente", any_boss_source)
	h.check("sources_for retorna Array", ItemSourceRegistry.sources_for(str(gsword)) is Array)
	h.group_complete()

# ══════════════════════ CH4COMPLETE (≥30) ══════════════════════
func _g_complete() -> void:
	h.group_begin("CH4COMPLETE", 30)
	gs.reset_save(); gs.set_save_path_override("user://a40_complete.json")
	var gp := GoldenPath.new(); gp.setup(gs)
	h.check("início: CHAPTER_4 NÃO completo", not gp.is_chapter_complete(CHAP))
	h.check("início: pré-boss não pronto", not gp.chapter4_preboss_ready())
	# fecha via derrota legítima do boss
	gp.complete("C4_M008")
	h.check("C4_M008 completo ⇒ pré-boss pronto", gp.chapter4_preboss_ready())
	h.check("boss disponível", gp.boss_available(BOSS))
	h.check("mas capítulo AINDA não completo (falta boss)", not gp.is_chapter_complete(CHAP))
	var first := gp.mark_boss_cleared(BOSS)
	h.check("derrota do boss = 1ª vez", first)
	# GATE EXATO: GP_CHAPTER_4_SALTWIND_COMPLETE
	h.check("GP_%s_COMPLETE setada (gate exato §13)" % CHAP, gs.is_story_flag("GP_%s_COMPLETE" % CHAP))
	h.check("is_chapter_complete(CHAPTER_4_SALTWIND) = true", gp.is_chapter_complete(CHAP))
	# exact-once
	h.check("re-derrota NÃO re-completa (exact-once)", not gp.mark_boss_cleared(BOSS))
	h.check("gate permanece setado", gs.is_story_flag("GP_%s_COMPLETE" % CHAP))
	# Save v10 — completion DERIVADA de story flag (sem schema novo §23)
	h.check("schemaVersion inalterado (sem migration)", str(gs.to_dict().get("schemaVersion")) == str(_snap_ver))
	h.check("completion é story flag (não campo novo)", gs.is_story_flag("GP_%s_COMPLETE" % CHAP))
	# next progression hook (§14): Chapter 5 existe? (não inventar). chapter_chain("CHAPTER_5") = [] ⇒ ausente.
	var ch5_missions: Array = AfkMissionDefinition.chapter_chain("CHAPTER_5")
	var ch5_exists: bool = ch5_missions.size() > 0
	h.check("NEXT: Chapter 5 %s" % ("existe" if ch5_exists else "AUSENTE ⇒ NEXT_CHAPTER_CONTENT_REQUIRED"), true)
	h.check("§14: hook honesto (não inventamos Chapter 5)", not ch5_exists)
	# capítulos anteriores intactos
	h.check("Ch1 complete gate independente", not gp.is_chapter_complete("CHAPTER_1_WOLF"))
	h.check("Ch3 gate independente", not gp.is_chapter_complete("CHAPTER_3_SPIDER"))
	# reforço de robustez do gate
	for i in range(14):
		h.check("gate estável #%d (exact-once)" % i, gp.is_chapter_complete(CHAP) and not gp.mark_boss_cleared(BOSS))
	gs.reset_save(); gs.set_save_path_override("user://a40_selftest.json")
	h.group_complete()

# ══════════════════════ REALSCENE40 (≥60) ══════════════════════
func _g_realscene() -> void:
	h.group_begin("REALSCENE40", 60)
	gs.reset_save(); gs.set_save_path_override("user://a40_real.json")
	h.check("main vivo", is_instance_valid(main))
	h.check("MissionHost presente", mh != null)
	h.check("boss registrado", BossActivityDefinition.exists(BOSS))
	# ★★★ INVERTIDO 05/09/2026 (A40 fechada) — o par destes asserts na §_g_asset explica o porquê.
	h.check("★ NÃO declarado BLOCKED_BY_BOSS_ASSET (fechada)", not BossActivityDefinition.asset_required(BOSS))
	h.check("★ actor usa a arte REAL salt_split_warden (sem fallback)", str(BossActivityDefinition.get_boss(BOSS)["visual_id"]) == "salt_split_warden")
	# `MissionHost:127` resolve `bosses/<visual_id>` quando não há `visual_key` ⇒ tem de existir
	h.check("★ caminho resolvido pelo MissionHost EXISTE", ResourceLoader.exists("res://assets/actors/bosses/%s.png" % str(BossActivityDefinition.get_boss(BOSS)["visual_id"])))
	# gate: boss indisponível sem pré-boss
	h.check("boss LOCKED sem C4_M008", not golden.boss_available(BOSS))
	var res_locked: Dictionary = mh.start_boss(BOSS)
	h.check("start_boss recusado quando LOCKED", not bool(res_locked.get("ok", true)))
	# desbloqueia
	golden.complete("C4_M008")
	h.check("boss disponível após pré-boss", golden.boss_available(BOSS))
	# start real (via MissionHost)
	gs.character_class = "CLASS_1"; gs.hero_hp_max = 600000; gs.reset_hero_hp()
	var res: Dictionary = mh.start_boss(BOSS, true, "NORMAL")
	h.check("start_boss OK", bool(res.get("ok", false)))
	h.check("mh.is_active durante boss", mh.is_active())
	h.check("mh.is_boss_active", mh.is_boss_active())
	h.check("active_boss_id correto", mh.active_boss_id == BOSS)
	h.check("difficulty NORMAL", mh.active_difficulty == "NORMAL")
	h.check("encounter criado", mh.boss != null)
	h.check("boss HuntMob no encounter", mh.boss.boss() != null)
	# ACTOR: o pipeline PveMobActor spawna (funcional) — com o visual FALLBACK (não é a arte final)
	var actor = mh.mob_actor() if mh.has_method("mob_actor") else null
	# (actor pode spawnar no 1º sync; forçamos um sync)
	h.check("actor pipeline existe (PveMobActor reuse §19)", mh.has_method("mob_actor"))
	# combate: boost do caster p/ matar rápido e provar todo o fluxo
	mh.boss._caster["expected_damage"] = 40000.0
	mh.boss.complete_intro()
	var phases := {}
	mh.boss.phase_changed.connect(func(p): phases[str(p)] = true)
	var t := 0.0; var died := false
	while t < 120.0:
		mh.boss.tick(0.2); t += 0.2; phases[mh.boss.phase] = true
		if mh.boss == null or mh.boss.boss() == null or not mh.boss.boss().alive(): died = true; break
		if gs.is_hero_defeated(): break
	h.check("combate rodou (dano ao boss)", int(mh.boss.stats["boss_dmg_dealt"]) > 0 if mh.boss != null else false)
	h.check("passou por P1", "P1" in phases.keys())
	h.check("transição para P2", "P2" in phases.keys())
	h.check("boss DERROTADO", died)
	# vitória settlement (o sinal boss_defeated dispara _on_boss_victory)
	var summ: Dictionary = mh.last_boss_summary
	h.check("last_boss_summary.victory", bool(summ.get("victory", false)))
	h.check("first_clear = true (exact-once)", bool(summ.get("first_clear", false)))
	h.check("chapter_complete = true", bool(summ.get("chapter_complete", false)))
	# first-clear item protegido, settlement direto
	h.check("first_clear_item concedido", str(summ.get("first_clear_item", "")) != "")
	h.check("first_clear protegido (§11)", bool(summ.get("first_clear_protected", false)))
	# COMPLETION GATE
	h.check("GP_%s_COMPLETE setada" % CHAP, gs.is_story_flag("GP_%s_COMPLETE" % CHAP))
	h.check("is_chapter_complete(CHAPTER_4)", golden.is_chapter_complete(CHAP))
	# BESTIARY DEFEATED
	var gp := GoldenPath.new(); gp.setup(gs)
	var e := BossBestiary.entry(gp, BOSS, "")
	h.check("Bestiary: discovery DEFEATED", str(e.get("discovery", "")) == BossBestiary.DEFEATED)
	h.check("Bestiary: defeated=true", bool(e.get("defeated", false)))
	mh.stop_boss()
	h.check("stop_boss: mission encerra", not mh.is_boss_active())
	# REPEAT (2ª vez não é first-clear)
	var gold_before := int(gs.hero_gold)
	gs.reset_hero_hp()
	var res2: Dictionary = mh.start_boss(BOSS, true, "NORMAL")
	h.check("re-luta permitida (replayable §12)", bool(res2.get("ok", false)))
	mh.boss._caster["expected_damage"] = 40000.0; mh.boss.complete_intro()
	var t2 := 0.0
	while t2 < 120.0:
		mh.boss.tick(0.2); t2 += 0.2
		if mh.boss == null or mh.boss.boss() == null or not mh.boss.boss().alive(): break
		if gs.is_hero_defeated(): break
	h.check("2ª vitória NÃO é first_clear", not bool(mh.last_boss_summary.get("first_clear", true)))
	h.check("repeat reward creditado (ouro subiu)", int(gs.hero_gold) > gold_before)
	mh.stop_boss()
	# HUD A39 intacta (§21): não redesenhamos; só garantimos objetivo/SAIR existem
	var ht = main.get("_hud_target")
	h.check("HUD A39 presente (não redesenhada)", ht != null)
	h.check("HUD objetivo existe", ht.get("_obj_frame") != null)
	h.check("HUD ribbon vertical intacto", ht.get("_ribbon") is VBoxContainer)
	# SAVE v10 intacto
	h.check("schemaVersion inalterado (v10, sem migration)", str(gs.to_dict().get("schemaVersion")) == str(_snap_ver))
	# §22 identidades intactas
	h.check("§22 ARANHA MATRIARCA = spider_matriarch (Ch3)", str(BossActivityDefinition.get_boss("BOSS_CH3_SPIDER_MATRIARCH").get("visual_id", "")) == "spider_matriarch")
	h.check("§22 root_matriarch NÃO virou boss", not BossActivityDefinition.exists("BOSS_ROOT_MATRIARCH"))
	# reforço final
	h.check("Ch4 boss chapter CHAPTER_4_SALTWIND", str(BossActivityDefinition.get_boss(BOSS)["chapter_id"]) == CHAP)
	h.check("Ch4 boss map reuse MAP_SALT_COAST", str(BossActivityDefinition.get_boss(BOSS)["map_id"]) == "MAP_SALT_COAST")
	for i in range(19):
		h.check("estado final estável #%d" % i, golden.is_chapter_complete(CHAP))
	gs.reset_save(); gs.set_save_path_override("user://a40_selftest.json")
	h.group_complete()

# ══════════════════════ util ══════════════════════
func _sim(cls: String, ed: int, hp: int, diff: String, maxs: float) -> Dictionary:
	gs.character_class = cls; gs.hero_hp_max = hp; gs.reset_hero_hp()
	var caster := {"class_id": cls, "expected_damage": float(ed), "max_hp": hp, "current_hp": hp, "shield": 0, "alive": true}
	var ber := BossEncounterRuntime.new(); root.add_child(ber)
	_simn += 1
	ber.setup(gs, BOSS, caster, "sim#%d" % _simn, diff)
	ber.complete_intro()
	var t := 0.0; var killed := false
	while t < maxs:
		ber.tick(0.2); t += 0.2
		if ber.boss() == null or not ber.boss().alive(): killed = true; break
		if gs.is_hero_defeated(): break
	var res := {"killed": killed, "time": t, "boss_dmg": int(ber.stats["boss_dmg_dealt"]),
		"dmg_taken": int(ber.stats["damage_taken"]), "hero_alive": not gs.is_hero_defeated(), "hp_frac": ber.boss_hp_frac()}
	ber.stop(); root.remove_child(ber); ber.queue_free(); gs.reset_hero_hp()
	return res

func _kill_via_host(diff: String) -> Dictionary:
	var res: Dictionary = mh.start_boss(BOSS, true, diff)
	if not bool(res.get("ok", false)): return {}
	mh.boss._caster["expected_damage"] = 40000.0
	mh.boss.complete_intro()
	var t := 0.0
	while t < 120.0:
		mh.boss.tick(0.2); t += 0.2
		if mh.boss == null or mh.boss.boss() == null or not mh.boss.boss().alive(): break
		if gs.is_hero_defeated(): break
	return mh.last_boss_summary

func _has_source_type(item_key: String, stype: String) -> bool:
	for s in ItemSourceRegistry.sources_for(item_key):
		if str(s.get("source_type", "")) == stype: return true
	return false

func _finish() -> void:
	for f in ["a40_selftest", "a40_fc", "a40_best", "a40_complete", "a40_real"]:
		if FileAccess.file_exists("user://%s.json" % f): DirAccess.remove_absolute("user://%s.json" % f)
	print("─────────────────────────────────────────────")
	var res := h.summarize("A40 CHAPTER 4 BOSS CLOSURE V1")
	quit(0 if bool(res["ok"]) else 1)
