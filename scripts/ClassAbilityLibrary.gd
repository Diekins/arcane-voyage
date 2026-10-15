class_name ClassAbilityLibrary extends RefCounted
## FATIA A15.1/§12 — DEFINIÇÃO das habilidades por classe. Estrutura pura/data (não binda a asset Codex inexistente
## §12): ability_id/class_id/role/cooldown/range/targeting/cast_type/damage/heal/shield/status/scaling/pve_allowed/
## arena_allowed/tags/animation_hook/vfx_hook/ai. Cada classe = basic + skill1 + skill2 + skill3 + dodge (§14).
## SUPPORT é REAL (§19): tem dano (SMITE/RITE) p/ SOLO PvE, além de cura/escudo — NÃO é Magic recolorido.
## `damage`/`heal`/`shield` = FATOR sobre o dano esperado do caster (CombatMath resolve a magnitude, §14).

const ROLE_OFFENSE := "OFFENSE"
const ROLE_HEAL := "HEAL"
const ROLE_SHIELD := "SHIELD"
const ROLE_CONTROL := "CONTROL"
const ROLE_MOBILITY := "MOBILITY"

const TARGET_SELF := "SELF"
const TARGET_SINGLE := "SINGLE"
const TARGET_AREA := "AREA"
const TARGET_LINE := "LINE"
const TARGET_CONE := "CONE"

static func _ab(id: String, cls: String, role: String, cd: float, rng: float, targeting: String, dmg: float, heal: float, shield: float, status: Dictionary, tags: Array, ai_priority: int, ai_cond: String) -> Dictionary:
	return {
		"ability_id": id, "class_id": cls, "role": role, "cooldown": cd, "range": rng, "targeting": targeting,
		"cast_type": "INSTANT", "damage": dmg, "heal": heal, "shield": shield, "status": status,
		"scaling": "expected_damage", "pve_allowed": true, "arena_allowed": true, "tags": tags,
		"animation_hook": "anim_" + id, "vfx_hook": "vfx_" + id, "ai": {"priority": ai_priority, "condition": ai_cond},
	}

## Kits das 5 classes. AI priority: maior = avaliada primeiro (§30 support prioriza cura em HP crítico).
const KITS := {
	"CLASS_1": {   # MELEE — toughness + close combat
		"basic": ["SK_C1_STRIKE"], "s1": "SK_C1_CLEAVE", "s2": "SK_C1_BASH", "s3": "SK_C1_GUARD", "dodge": "SK_C1_ROLL"},
	"CLASS_2": {   # RANGED — precision/offense, menor resistência
		"basic": ["SK_C2_SHOT"], "s1": "SK_C2_PIERCE", "s2": "SK_C2_VOLLEY", "s3": "SK_C2_MARK", "dodge": "SK_C2_ROLL"},
	"CLASS_3": {   # MAGIC — burst/AoE
		"basic": ["SK_C3_BOLT"], "s1": "SK_C3_NOVA", "s2": "SK_C3_FIELD", "s3": "SK_C3_WARDM", "dodge": "SK_C3_BLINK"},
	"CLASS_4": {   # REACH — spacing/line
		"basic": ["SK_C4_JAB"], "s1": "SK_C4_THRUST", "s2": "SK_C4_SWEEP", "s3": "SK_C4_BRACE", "dodge": "SK_C4_VAULT"},
	"CLASS_5_SUPPORT": {   # SUPPORT/HEALER — cura/sustain/proteção + dano solo
		"basic": ["SK_C5_SMITE"], "s1": "SK_C5_MEND", "s2": "SK_C5_WARD", "s3": "SK_C5_RITE", "dodge": "SK_C5_STEP"},
}

static func _all() -> Dictionary:
	var d: Dictionary = {}
	# MELEE
	d["SK_C1_STRIKE"] = _ab("SK_C1_STRIKE", "CLASS_1", ROLE_OFFENSE, 0.0, 60, TARGET_SINGLE, 1.0, 0, 0, {}, ["basic", "melee"], 1, "always")
	d["SK_C1_CLEAVE"] = _ab("SK_C1_CLEAVE", "CLASS_1", ROLE_OFFENSE, 4.0, 70, TARGET_CONE, 1.4, 0, 0, {}, ["aoe"], 5, "multi_target")
	d["SK_C1_BASH"] = _ab("SK_C1_BASH", "CLASS_1", ROLE_CONTROL, 6.0, 60, TARGET_SINGLE, 0.8, 0, 0, {"type": "slow", "magnitude": 0.4, "duration": 2.0}, ["control"], 4, "target_ok")
	d["SK_C1_GUARD"] = _ab("SK_C1_GUARD", "CLASS_1", ROLE_SHIELD, 10.0, 0, TARGET_SELF, 0, 0, 0.6, {}, ["defense"], 8, "hp_below_0_5")
	d["SK_C1_ROLL"] = _ab("SK_C1_ROLL", "CLASS_1", ROLE_MOBILITY, 1.0, 0, TARGET_SELF, 0, 0, 0, {"type": "iframe", "duration": 0.3}, ["dodge"], 9, "danger")
	# RANGED
	d["SK_C2_SHOT"] = _ab("SK_C2_SHOT", "CLASS_2", ROLE_OFFENSE, 0.0, 300, TARGET_SINGLE, 1.0, 0, 0, {}, ["basic", "ranged"], 1, "always")
	d["SK_C2_PIERCE"] = _ab("SK_C2_PIERCE", "CLASS_2", ROLE_OFFENSE, 5.0, 320, TARGET_LINE, 1.6, 0, 0, {}, ["line"], 5, "line_targets")
	d["SK_C2_VOLLEY"] = _ab("SK_C2_VOLLEY", "CLASS_2", ROLE_OFFENSE, 7.0, 300, TARGET_AREA, 1.3, 0, 0, {}, ["aoe"], 6, "multi_target")
	d["SK_C2_MARK"] = _ab("SK_C2_MARK", "CLASS_2", ROLE_CONTROL, 8.0, 320, TARGET_SINGLE, 0.5, 0, 0, {"type": "vuln", "magnitude": 0.15, "duration": 4.0}, ["mark"], 4, "boss")
	d["SK_C2_ROLL"] = _ab("SK_C2_ROLL", "CLASS_2", ROLE_MOBILITY, 1.0, 0, TARGET_SELF, 0, 0, 0, {"type": "iframe", "duration": 0.3}, ["dodge"], 9, "danger")
	# MAGIC
	d["SK_C3_BOLT"] = _ab("SK_C3_BOLT", "CLASS_3", ROLE_OFFENSE, 0.0, 260, TARGET_SINGLE, 1.1, 0, 0, {}, ["basic", "magic"], 1, "always")
	d["SK_C3_NOVA"] = _ab("SK_C3_NOVA", "CLASS_3", ROLE_OFFENSE, 6.0, 180, TARGET_AREA, 1.8, 0, 0, {}, ["aoe", "burst"], 6, "multi_target")
	d["SK_C3_FIELD"] = _ab("SK_C3_FIELD", "CLASS_3", ROLE_CONTROL, 9.0, 220, TARGET_AREA, 0.6, 0, 0, {"type": "slow", "magnitude": 0.5, "duration": 3.0}, ["ground", "dot"], 5, "multi_target")
	d["SK_C3_WARDM"] = _ab("SK_C3_WARDM", "CLASS_3", ROLE_SHIELD, 12.0, 0, TARGET_SELF, 0, 0, 0.5, {}, ["defense"], 7, "hp_below_0_5")
	d["SK_C3_BLINK"] = _ab("SK_C3_BLINK", "CLASS_3", ROLE_MOBILITY, 3.0, 0, TARGET_SELF, 0, 0, 0, {"type": "iframe", "duration": 0.25}, ["dodge", "teleport"], 9, "danger")
	# REACH
	d["SK_C4_JAB"] = _ab("SK_C4_JAB", "CLASS_4", ROLE_OFFENSE, 0.0, 120, TARGET_SINGLE, 1.0, 0, 0, {}, ["basic", "reach"], 1, "always")
	d["SK_C4_THRUST"] = _ab("SK_C4_THRUST", "CLASS_4", ROLE_OFFENSE, 4.0, 160, TARGET_LINE, 1.5, 0, 0, {}, ["line"], 5, "line_targets")
	d["SK_C4_SWEEP"] = _ab("SK_C4_SWEEP", "CLASS_4", ROLE_OFFENSE, 6.0, 120, TARGET_CONE, 1.3, 0, 0, {"type": "knockback", "magnitude": 60, "duration": 0}, ["aoe", "spacing"], 6, "multi_target")
	d["SK_C4_BRACE"] = _ab("SK_C4_BRACE", "CLASS_4", ROLE_SHIELD, 10.0, 0, TARGET_SELF, 0, 0, 0.45, {}, ["defense"], 7, "hp_below_0_5")
	d["SK_C4_VAULT"] = _ab("SK_C4_VAULT", "CLASS_4", ROLE_MOBILITY, 2.0, 0, TARGET_SELF, 0, 0, 0, {"type": "iframe", "duration": 0.3}, ["dodge", "spacing"], 9, "danger")
	# SUPPORT/HEALER — REAL, com dano solo (§19)
	d["SK_C5_SMITE"] = _ab("SK_C5_SMITE", "CLASS_5_SUPPORT", ROLE_OFFENSE, 0.0, 200, TARGET_SINGLE, 0.9, 0, 0, {}, ["basic", "spirit"], 1, "always")
	d["SK_C5_MEND"] = _ab("SK_C5_MEND", "CLASS_5_SUPPORT", ROLE_HEAL, 5.0, 0, TARGET_SELF, 0, 1.2, 0, {}, ["heal"], 10, "hp_below_0_6")
	d["SK_C5_WARD"] = _ab("SK_C5_WARD", "CLASS_5_SUPPORT", ROLE_SHIELD, 9.0, 0, TARGET_SELF, 0, 0, 0.7, {}, ["shield", "protect"], 8, "danger")
	d["SK_C5_RITE"] = _ab("SK_C5_RITE", "CLASS_5_SUPPORT", ROLE_OFFENSE, 7.0, 180, TARGET_AREA, 1.1, 0, 0, {"type": "dot", "magnitude": 0.2, "duration": 4.0}, ["aoe", "dot"], 6, "multi_target")
	d["SK_C5_STEP"] = _ab("SK_C5_STEP", "CLASS_5_SUPPORT", ROLE_MOBILITY, 2.0, 0, TARGET_SELF, 0, 0, 0, {"type": "iframe", "duration": 0.3}, ["dodge"], 9, "danger")
	return d

static var _cache: Dictionary = {}
static func all_abilities() -> Dictionary:
	if _cache.is_empty(): _cache = _all()
	return _cache

static func get_ability(ability_id: String) -> Dictionary:
	return all_abilities().get(ability_id, {}).duplicate(true)

static func kit_of(class_id: String) -> Dictionary:
	return KITS.get(class_id, {}).duplicate(true)

## FIELD FIX 01B — CLASSE EFETIVA de combate. Personagem LEGACY_CLASS/desconhecido (save antigo, sem classe escolhida)
## NÃO tem kit próprio ⇒ o AutoCombatBrain não achava ataque e o herói ficava PARADO (bug de campo: kills=0). Fallback
## para o kit melee básico (CLASS_1) — o herói legado LUTA como melee padrão. CLASS_1..5 têm kit ⇒ inalterados.
static func effective_class(class_id: String) -> String:
	return class_id if not kit_of(class_id).is_empty() else "CLASS_1"

## Todas as ability_ids da classe (basic + 3 skills + dodge).
static func abilities_of(class_id: String) -> Array:
	var k := kit_of(class_id)
	if k.is_empty(): return []
	var out: Array = (k.get("basic", []) as Array).duplicate()
	for slot in ["s1", "s2", "s3", "dodge"]:
		if k.has(slot): out.append(str(k[slot]))
	return out

static func ability_belongs_to_class(ability_id: String, class_id: String) -> bool:
	return abilities_of(class_id).has(ability_id)

static func class_has_role(class_id: String, role: String) -> bool:
	for aid in abilities_of(class_id):
		if str(get_ability(aid).get("role", "")) == role:
			return true
	return false
