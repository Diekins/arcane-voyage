class_name BossEncounterRuntime extends Node
## FATIA A19.4/A19.5 — RUNTIME do encounter de Boss (AFK, spot-locked). Reusa HuntMob (corpo do boss, HP real,
## take_damage/died, owner=run_id §18), CombatRuntime (as 5 classes atacam), survival A17 (HP truth = GameState) e o
## contrato BossToolkit (BossAbility windup/telegraph). INTRO GATE: o boss não dana durante a intro (§13). Fases por %
## de HP (§14). BITE (cadência) + HEAVY_LUNGE (telegraphed → resposta defensiva/dodge automática §16/§17) + HOWL/FRENZY
## (enrage por fase). Boss futuro = DATA. Sem `if boss==wolf_alpha`.

signal phase_changed(phase_name: String)
signal telegraph(kind: String)
signal boss_ability(id: String)
signal boss_defeated()
signal hero_died()

var gs = null
var boss_id := ""
var run_id := ""
var _def: Dictionary = {}
var _boss: HuntMob = null
var boss_max_hp := 1
var _difficulty := "NORMAL"       # A40 — NORMAL/VETERAN (escala HP/dano do boss no setup)
var phase := "P1"
var _buff_mult := 1.0            # HOWL/FRENZY (enrage acumulado por fase)
var _base_dmg := 10
var _base_interval := 1.4
var _intro_done := false
var _now := 0.0
var _cds := CooldownTracker.new()        # skills do jogador
var _dodge_cd := CooldownTracker.new()   # dodge/defensa reativa do jogador (por classe)
var _caster: Dictionary = {}
var _engage_dist := 60.0
var _heavy_cd := 0.0
var _heavy_windup := -1.0        # -1 ocioso; >0 telegraph em andamento
# A27 — VENOM (spider ability): DoT data-driven OPCIONAL. Só age se o boss declara `boss_ability_profile.venom`
# (crystal_golem/wolf_alpha não declaram ⇒ inalterados). Não é novo engine — 3 contadores no runtime existente.
var _venom_cd := 0.0
var _venom_left := 0.0
var _venom_dps := 0
const HUNT_SHIELD_DUR := 6.0
var stats := {"boss_dmg_dealt": 0, "damage_taken": 0, "deaths": 0, "dodges": 0, "heavy_hits": 0, "venom_ticks": 0, "phase": "P1"}

func setup(p_gs, p_boss_id: String, caster: Dictionary, p_run_id: String, difficulty := "NORMAL") -> void:
	gs = p_gs; boss_id = p_boss_id; run_id = p_run_id
	_def = BossActivityDefinition.get_boss(p_boss_id)
	_caster = caster.duplicate(true)
	_engage_dist = _compute_engage_dist(str(_caster.get("class_id", "LEGACY_CLASS")))
	var sp: Dictionary = _def.get("boss_stats_profile", {})
	# A40 — dificuldade (NORMAL/VETERAN): escala HP e dano do boss. Boss sem difficulty_profile ⇒ mults 1.0 (compat).
	_difficulty = difficulty
	var dm := BossActivityDefinition.difficulty_mults(boss_id, difficulty)
	boss_max_hp = int(round(float(int(sp.get("base_hp", 2000))) * float(dm["hp_mult"])))
	_base_dmg = int(round(float(int(sp.get("base_dmg", 12))) * float(dm["dmg_mult"])))
	_base_interval = float(sp.get("attack_interval", 1.4))
	_boss = HuntMob.new(); _boss.setup(boss_id, boss_max_hp, boss_id, run_id); _boss.is_apex = true
	_boss.set_attack(_base_dmg, _base_dmg, _base_interval)   # BITE (cadência); Heavy é separado (telegraphed)
	add_child(_boss)

func _compute_engage_dist(class_id: String) -> float:
	var arch := CharacterClassDefinition.archetype_of(class_id)
	var pref := float(AutoCombatBrain.PREFERRED.get(arch, 60.0))
	var reliable := 0.0
	for aid in ClassAbilityLibrary.abilities_of(class_id):
		var ab := ClassAbilityLibrary.get_ability(aid)
		if str(ab.get("role", "")) == ClassAbilityLibrary.ROLE_OFFENSE and str(ab.get("ai", {}).get("condition", "always")) == "always":
			reliable = maxf(reliable, float(ab.get("range", 0.0)))
	return pref if reliable <= 0.0 else minf(pref, reliable * 0.95)

## INTRO GATE (§13): o boss só age depois disto.
func complete_intro() -> void: _intro_done = true
func intro_done() -> bool: return _intro_done
func difficulty() -> String: return _difficulty
func boss() -> HuntMob: return _boss
func boss_hp_frac() -> float: return float(_boss.hp) / float(maxi(1, boss_max_hp)) if _boss != null else 0.0

func tick(delta: float) -> void:
	if _boss == null or not _boss.alive(): return
	_now += delta
	_sync_caster_from_hp()
	if gs != null and gs.is_hero_defeated(): return   # morto — host cuida do retry
	if not _intro_done: return                          # §13 boss não dana durante a intro
	# fase por % de HP
	var ph := BossActivityDefinition.phase_for(boss_id, boss_hp_frac())
	var pname := str(ph.get("name", phase))
	if pname != phase:
		phase = pname; stats["phase"] = pname
		var on_enter := str(ph.get("on_enter", ""))
		if on_enter == "HOWL": _buff_mult *= float(_def.get("boss_ability_profile", {}).get("howl", {}).get("dmg_mult", 1.15)); boss_ability.emit("HOWL")
		elif on_enter == "FRENZY": _buff_mult *= float(_def.get("boss_ability_profile", {}).get("frenzy", {}).get("dmg_mult", 1.3)); boss_ability.emit("FRENZY")
		phase_changed.emit(pname)
	var dmg_mult := float(ph.get("dmg_mult", 1.0)) * _buff_mult
	# HEAVY LUNGE telegraphed (§16): windup → resolve. Durante o windup, o jogador pode ESQUIVAR (resposta auto §17).
	_heavy_cd = maxf(0.0, _heavy_cd - delta)
	if _heavy_windup < 0.0 and _heavy_cd <= 0.0:
		_heavy_windup = float(_def.get("boss_ability_profile", {}).get("heavy", {}).get("windup", 0.9))
		boss_ability.emit("HEAVY_LUNGE"); telegraph.emit("HEAVY_LUNGE")
	elif _heavy_windup >= 0.0:
		_heavy_windup -= delta
		if _heavy_windup <= 0.0:
			_heavy_windup = -1.0; _heavy_cd = float(_def.get("boss_ability_profile", {}).get("heavy", {}).get("cooldown", 5.0))
			_resolve_heavy(dmg_mult)
	# A27 — VENOM (spider ability, DoT telegrafado, data-driven): telegraph → dano por segundo durante `duration`.
	# Pressão sustentada (não esquivável, ≠ HEAVY). Só ativa se o boss declara `venom`. Escala pela fase (dmg_mult).
	# A40 — DoT sustentado: slot genérico. Lê `venom` (spider) OU `signature` (ex.: MARÉ do warden costeiro).
	var venom: Dictionary = _def.get("boss_ability_profile", {}).get("venom", {})
	if venom.is_empty(): venom = _def.get("boss_ability_profile", {}).get("signature", {})
	if not venom.is_empty():
		_venom_cd = maxf(0.0, _venom_cd - delta)
		if _venom_left <= 0.0 and _venom_cd <= 0.0:
			_venom_left = float(venom.get("duration", 3.0)); _venom_dps = int(venom.get("dps", _base_dmg))
			_venom_cd = float(venom.get("cooldown", 9.0))
			boss_ability.emit("VENOM"); telegraph.emit("VENOM")
		elif _venom_left > 0.0:
			_venom_left -= delta
			var vtick := int(round(float(_venom_dps) * delta * dmg_mult))
			stats["venom_ticks"] = int(stats.get("venom_ticks", 0)) + 1
			if vtick > 0 and _take_damage(vtick): return
	# BITE (cadência) → dano no HP real
	var bite := _boss.attack_tick(delta)
	if bite > 0:
		if _take_damage(int(round(bite * dmg_mult))): return
	# combate do jogador contra o boss (só o boss deste run §18)
	var arch := CharacterClassDefinition.archetype_of(str(_caster.get("class_id", "LEGACY_CLASS")))
	var ctx := {"class_id": str(_caster.get("class_id", "melee")), "archetype": arch, "dist": _engage_dist,
		"target_count": 1, "hp_frac": float(_caster.get("current_hp", 1)) / float(maxi(1, _caster.get("max_hp", 1))),
		"targets": [{"id": boss_id, "hp": _boss.hp}], "is_boss": true, "danger": _heavy_windup >= 0.0}
	var r := CombatRuntime.step(_caster, ctx, _cds, _now)
	for d in r.get("damage_events", []):
		if _boss != null and _boss.take_damage(int(d["amount"]), run_id):
			stats["boss_dmg_dealt"] = int(stats["boss_dmg_dealt"]) + int(d["amount"]); _on_boss_death(); return
		stats["boss_dmg_dealt"] = int(stats["boss_dmg_dealt"]) + int(d["amount"])
	for _h in r.get("heal_events", []):
		if gs != null: gs.heal_hero(int(_h["amount"])); _sync_caster_from_hp()
	for _s in r.get("shield_events", []):
		if gs != null: gs.activate_shield(int(_s["amount"]), HUNT_SHIELD_DUR); _sync_caster_from_hp()

## HEAVY resolve: golpe pesado. Resposta defensiva AUTOMÁTICA (§16/§17): se a esquiva/defesa da classe está pronta,
## ESQUIVA (evita) e entra em cooldown; senão leva o golpe cheio.
func _resolve_heavy(dmg_mult: float) -> void:
	var heavy := int(round(_base_dmg * 3.0 * dmg_mult))
	if _dodge_cd.is_ready("dodge", _now):
		_dodge_cd.trigger("dodge", _now, 3.0); stats["dodges"] = int(stats["dodges"]) + 1
		return   # esquivou o golpe pesado
	stats["heavy_hits"] = int(stats["heavy_hits"]) + 1
	_take_damage(heavy)

func _sync_caster_from_hp() -> void:
	if gs == null: return
	_caster["current_hp"] = int(gs.hero_hp); _caster["max_hp"] = maxi(1, int(gs.max_hp_total()))
	_caster["shield"] = int(gs.shield_amount); _caster["alive"] = not gs.is_hero_defeated()

func _take_damage(amount: int) -> bool:
	amount = maxi(0, amount); stats["damage_taken"] = int(stats["damage_taken"]) + amount
	if gs == null: return false
	var absorbed := int(gs.shield_absorb(amount)); var to_hp := amount - absorbed
	if to_hp > 0: gs.damage_hero(to_hp)
	_sync_caster_from_hp()
	if gs.is_hero_defeated():
		stats["deaths"] = int(stats["deaths"]) + 1; hero_died.emit(); return true
	return false

func revive() -> void:
	if gs != null: gs.reset_hero_hp(); _sync_caster_from_hp()
	_cds = CooldownTracker.new()

func _on_boss_death() -> void:
	if _boss != null: _boss.queue_free(); _boss = null
	boss_defeated.emit()

func stop() -> void:
	if _boss != null: _boss.queue_free(); _boss = null
