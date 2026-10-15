class_name MissionEngine extends Node
## FATIA A18 — O MOTOR de missão AFK (UM engine, N definições data-driven). Reusa a infra de Hunt: HuntMob (ameaça),
## CombatRuntime (as 5 classes), survival com FONTE ÚNICA de HP (GameState), e o SETTLEMENT DIRETO (§A18.12 — sem floor
## pickup). Encounter FECHADO: spawna SÓ mob elegível (MobEligibility §8), 1 alvo por vez, ownership do encounter.
## Objetivos: KILL_COUNT / COLLECT_DROP / ELITE_KILL. Conclusão exact-once. run_id p/ repetível (sem dup no restart).

signal mob_spawned(is_elite: bool)
signal mob_killed(is_elite: bool)
signal loot_settled(kind: String, rarity: String)
signal special_dropped(material: String)
signal first_gear()
signal completed(summary: Dictionary)
signal hero_died()
signal hero_revived()

var gs = null                    # GameState (fonte única de HP + carteira/inventário) — settlement direto
var lootmgr = null               # LootManager (backpack/overflow/autosalvage) — reuso, sem 2ª lógica
var mission_id := ""
var difficulty := "NORMAL"
var run_id := ""
var objective := ""
var required := 1
var collect_material := ""
var progress := 0
var _completed := false
var _first_gear_shown := false

var _mob: HuntMob = null
var _cds := CooldownTracker.new()
var _caster: Dictionary = {}
var _engage_dist := 60.0
var _now := 0.0
var _respawn_at := -1.0
const RESPAWN_DELAY := 0.4
const HUNT_SHIELD_DUR := 6.0
var _rng := RandomNumberGenerator.new()
var _def: Dictionary = {}
var _diff: Dictionary = {}
var _mobdef: Dictionary = {}
var stats := {"kills": 0, "elite": 0, "xp": 0, "gold": 0, "items": 0, "materials": 0, "rare": 0, "special": 0, "deaths": 0, "damage_taken": 0, "hero_attacks": 0, "mob_attacks": 0, "hero_damage_last": 0, "mob_damage_last": 0}

func setup(p_gs, p_lootmgr, p_mission: String, p_difficulty: String, p_run_id: String, caster: Dictionary, chosen_count: int = -1, rng_seed: int = 18) -> void:
	gs = p_gs; lootmgr = p_lootmgr; mission_id = p_mission; difficulty = p_difficulty; run_id = p_run_id
	_def = AfkMissionDefinition.get_mission(p_mission)
	_diff = MissionDifficulty.get_tier(p_difficulty)
	var tmids: Array = _def.get("target_mob_ids", ["young_wolf"])
	var first_mob := str(tmids[0]) if not tmids.is_empty() else "young_wolf"
	_mobdef = MobEligibility.get_mob(first_mob)
	objective = str(_def.get("objective_type", AfkMissionDefinition.OBJ_KILL))
	collect_material = str(_def.get("collect_material", ""))
	required = AfkMissionDefinition.effective_required(p_mission, chosen_count)
	_caster = caster.duplicate(true)
	_engage_dist = _compute_engage_dist(str(_caster.get("class_id", "LEGACY_CLASS")))
	_rng.seed = rng_seed

func _compute_engage_dist(class_id: String) -> float:
	var arch := CharacterClassDefinition.archetype_of(class_id)
	var pref := float(AutoCombatBrain.PREFERRED.get(arch, 60.0))
	var reliable := 0.0
	for aid in ClassAbilityLibrary.abilities_of(class_id):
		var ab := ClassAbilityLibrary.get_ability(aid)
		if str(ab.get("role", "")) == ClassAbilityLibrary.ROLE_OFFENSE and str(ab.get("ai", {}).get("condition", "always")) == "always":
			reliable = maxf(reliable, float(ab.get("range", 0.0)))
	return pref if reliable <= 0.0 else minf(pref, reliable * 0.95)

# ── SPAWN (só mob elegível; §8/§A18.9 encounter-owned) ──
func _spawn_mob() -> void:
	if _completed: return
	var mob_id := str((_def.get("target_mob_ids", ["young_wolf"]) as Array)[0])
	if not MobEligibility.can_spawn_in_mission(mob_id, mission_id):
		return   # nunca nasce mob não autorizado
	var sp: Dictionary = _mobdef.get("spawn_profile", {"base_hp": 32, "base_dmg": 6, "attack_interval": 1.5})
	# elite roll (policy × dificuldade)
	var elite_chance := float(_def.get("elite_policy", {}).get("chance", 0.0)) * float(_diff.get("elite_mult", 1.0))
	var is_elite := _rng.randf() < elite_chance
	var hp := int(round(float(sp.get("base_hp", 32)) * float(_diff.get("hp_mult", 1.0)) * (2.2 if is_elite else 1.0)))
	var dmgm := float(_diff.get("dmg_mult", 1.0)) * (1.2 if is_elite else 1.0)
	var m := HuntMob.new()
	m.setup(mob_id, hp, mission_id, run_id)   # owner_session = run_id (ownership do encounter)
	m.is_elite = is_elite
	var base_dmg := int(sp.get("base_dmg", 6))
	m.set_attack(int(round(base_dmg * dmgm * 0.8)), int(round(base_dmg * dmgm * 1.2)), float(sp.get("attack_interval", 1.5)))
	add_child(m); _mob = m
	mob_spawned.emit(is_elite)

# ── TICK (mesmo padrão de sobrevivência do HuntRuntime; ameaça primeiro) ──
func tick(delta: float) -> void:
	if _completed: return
	_now += delta
	_sync_caster_from_hp()
	if gs != null and gs.is_hero_defeated():
		return   # morto — host cuida do revive
	if _mob == null or not _mob.alive():
		if _respawn_at < 0.0: _respawn_at = _now + RESPAWN_DELAY
		elif _now >= _respawn_at: _respawn_at = -1.0; _spawn_mob()
		return
	# AMEAÇA primeiro (§A18.10): o mob golpeia ao engajar
	var incoming := _mob.attack_tick(delta)
	if incoming > 0:
		stats["mob_attacks"] = int(stats["mob_attacks"]) + 1; stats["mob_damage_last"] = incoming
		if _take_damage(incoming): return
	# combate do herói (só o mob DESTE encounter)
	var arch := CharacterClassDefinition.archetype_of(str(_caster.get("class_id", "LEGACY_CLASS")))
	var ctx := {"class_id": str(_caster.get("class_id", "melee")), "archetype": arch, "dist": _engage_dist,
		"target_count": 1, "hp_frac": float(_caster.get("current_hp", 1)) / float(maxi(1, _caster.get("max_hp", 1))),
		"targets": [{"id": _mob.mob_id, "hp": _mob.hp}], "is_boss": false}
	var r := CombatRuntime.step(_caster, ctx, _cds, _now)
	for d in r.get("damage_events", []):
		stats["hero_attacks"] = int(stats["hero_attacks"]) + 1; stats["hero_damage_last"] = int(d["amount"])
		if _mob != null and _mob.take_damage(int(d["amount"]), run_id):
			_on_kill(_mob.is_elite)
	for _h in r.get("heal_events", []):
		if gs != null: gs.heal_hero(int(_h["amount"])); _sync_caster_from_hp()
	for _s in r.get("shield_events", []):
		if gs != null: gs.activate_shield(int(_s["amount"]), HUNT_SHIELD_DUR); _sync_caster_from_hp()

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
		stats["deaths"] = int(stats["deaths"]) + 1
		if _mob != null: _mob.queue_free(); _mob = null
		_respawn_at = -1.0; hero_died.emit(); return true
	return false

func revive() -> void:
	if gs != null: gs.reset_hero_hp(); _sync_caster_from_hp()
	_cds = CooldownTracker.new(); hero_revived.emit()

# ── KILL → SETTLEMENT DIRETO + PROGRESSO + COMPLETION ──
func _on_kill(is_elite: bool) -> void:
	stats["kills"] = int(stats["kills"]) + 1
	if is_elite: stats["elite"] = int(stats["elite"]) + 1
	_settle_kill(is_elite)
	# progresso por tipo de objetivo
	match objective:
		AfkMissionDefinition.OBJ_KILL: progress += 1
		AfkMissionDefinition.OBJ_ELITE:
			if is_elite: progress += 1
		AfkMissionDefinition.OBJ_COLLECT:
			pass   # o progresso de COLLECT é incrementado no settlement do material (abaixo)
	mob_killed.emit(is_elite)
	if _mob != null: _mob.queue_free(); _mob = null
	_respawn_at = _now + RESPAWN_DELAY
	_check_completion()

## SETTLEMENT DIRETO (§A18.12): authority resolve → carteira/inventário. Sem floor node, sem walk-over.
func _settle_kill(is_elite: bool) -> void:
	var lp: Dictionary = _mobdef.get("loot_profile", {})
	var xpm := float(_diff.get("xp_mult", 1.0)) * (3.0 if is_elite else 1.0)
	var goldm := float(_diff.get("gold_mult", 1.0)) * (2.0 if is_elite else 1.0)
	# XP
	var xp := int(round(float(_mobdef.get("xp_profile", {}).get("base", 12)) * xpm))
	if gs != null and xp > 0: gs.add_xp(xp); stats["xp"] = int(stats["xp"]) + xp
	# GOLD
	var gr: Array = lp.get("gold", [3, 6])
	var gold := int(round(float(_rng.randi_range(int(gr[0]), int(gr[1]))) * goldm))
	if gs != null and gold > 0: gs.add_gold(gold); stats["gold"] = int(stats["gold"]) + gold
	# MATERIAL normal (conta p/ COLLECT_DROP se for o alvo)
	var matp: Dictionary = lp.get("material", {})
	if not matp.is_empty() and _rng.randf() < float(matp.get("chance", 0.0)):
		var mname := str(matp.get("name", "")); var mqty := int(matp.get("qty", 1))
		if gs != null and mname != "": gs.add_material(mname, mqty); stats["materials"] = int(stats["materials"]) + mqty
		if objective == AfkMissionDefinition.OBJ_COLLECT and mname == collect_material:
			progress += mqty
		loot_settled.emit("material", "common")
	# GEAR (equipamento) → LootManager (backpack/overflow/autosalvage). Feedback DEPOIS do settlement (§A18.13).
	if _rng.randf() < float(lp.get("gear_chance", 0.0)):
		var pool: Array = lp.get("gear_pool", [])
		if not pool.is_empty():
			var gid := str(pool[_rng.randi_range(0, pool.size() - 1)])
			if lootmgr != null: lootmgr.receive_loot(gid, 1)
			elif gs != null: gs.backpack_add(gid, 1)
			stats["items"] = int(stats["items"]) + 1
			var rarity := str(ItemDB.get_item(gid).get("rarity", "common"))
			if rarity != "common": stats["rare"] = int(stats["rare"]) + 1
			loot_settled.emit("gear", rarity)
			if not _first_gear_shown and str(ItemDB.get_item(gid).get("cat", "")) != "consumable":
				_first_gear_shown = true; first_gear.emit()
	# SPECIAL DROP (§A18.14) — chance por kill × dificuldade; NÃO requerido p/ completar.
	var sp: Dictionary = _def.get("special_drop_profile", {})
	if not sp.is_empty() and _rng.randf() < float(sp.get("chance", 0.0)) * float(_diff.get("special_mult", 1.0)):
		var smat := str(sp.get("material", "")); var sqty := int(sp.get("qty", 1))
		if gs != null and smat != "": gs.add_material(smat, sqty)
		stats["special"] = int(stats["special"]) + 1
		special_dropped.emit(smat); loot_settled.emit("special", "epic")

func _check_completion() -> void:
	if _completed or progress < required: return
	_completed = true
	if _mob != null: _mob.queue_free(); _mob = null
	completed.emit(summary())

func summary() -> Dictionary:
	var s: Dictionary = stats.duplicate(true)
	s["mission_id"] = mission_id; s["difficulty"] = difficulty; s["run_id"] = run_id
	s["progress"] = progress; s["required"] = required; s["objective"] = objective
	return s

func is_completed() -> bool: return _completed
func current_mob() -> HuntMob: return _mob
func stop() -> void:
	if _mob != null: _mob.queue_free(); _mob = null
