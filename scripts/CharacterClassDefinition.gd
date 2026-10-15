class_name CharacterClassDefinition extends RefCounted
## FATIA A13 — CLASSES V1 (§4-11). ★ CLASSE ≠ APARÊNCIA (§6): classe define identidade de combate, regras de arma,
## tendência de stats, skill pool e loadout. Appearance é o visual humano. 4 arquétipos com cobertura REAL no runtime
## (auditados via current_combat_archetype: melee/ranged/magic/reach); support(book) fica CONTENT_REQUIRED. TODAS as
## classes base são GRATUITAS (§7) — monetização é slot/loadout/cosmetic, nunca poder. IDs estáveis; display pendente
## de Canon (§5). Stat profile = multiplicadores PEQUENOS e explícitos que entram NATURALMENTE no CP (§10, sem
## class_bonus_cp artificial). Foundation, NÃO balance final (§11 → PVP_CLASS_BALANCE_FIELD_REQUIRED).

const CLASS_1 := "CLASS_1"   # melee — sword/axe/hammer (+ escudo)
const CLASS_2 := "CLASS_2"   # ranged — bow
const CLASS_3 := "CLASS_3"   # magic — staff
const CLASS_4 := "CLASS_4"   # reach — spear
const CLASS_5_SUPPORT := "CLASS_5_SUPPORT"   # A15 — SUPPORT/HEALER (book/focus); nome final CANON_REVIEW_REQUIRED
const LEGACY_CLASS := "LEGACY_CLASS"   # personagem antigo mapeado (§71)

const STATUS_PLAYABLE := "PLAYABLE"
const STATUS_CONTENT_REQUIRED := "CONTENT_REQUIRED"

## Registro autoritativo. `base_stat_profile` = multiplicadores pequenos aplicáveis (foundation). `skill_pool` = IDs
## de skill ESTÁVEIS (mecânica é futura §42, não inventada aqui). `arena_allowed`/`pve_allowed` = elegibilidade.
const CLASSES := {
	CLASS_1: {"archetype": "melee", "allowed_weapon_families": ["sword", "axe", "hammer"], "offhand_allowed": true, "starter_weapon": "sword_simple",
		"base_stat_profile": {"offense": 1.00, "defense": 1.10, "hp": 1.10, "mobility": 1.00, "range": 0.90},
		"skill_pool": ["SK_C1_GUARD", "SK_C1_CLEAVE", "SK_C1_BASH", "SK_C1_RALLY"], "status": STATUS_PLAYABLE},
	CLASS_2: {"archetype": "ranged", "allowed_weapon_families": ["bow"], "offhand_allowed": false, "starter_weapon": "bow_simple",
		"base_stat_profile": {"offense": 1.10, "defense": 0.90, "hp": 0.95, "mobility": 1.10, "range": 1.30},
		"skill_pool": ["SK_C2_VOLLEY", "SK_C2_PIN", "SK_C2_ROLL", "SK_C2_MARK"], "status": STATUS_PLAYABLE},
	CLASS_3: {"archetype": "magic", "allowed_weapon_families": ["staff"], "offhand_allowed": false, "starter_weapon": "staff_simple",
		"base_stat_profile": {"offense": 1.20, "defense": 0.85, "hp": 0.90, "mobility": 0.95, "range": 1.20},
		"skill_pool": ["SK_C3_BOLT", "SK_C3_NOVA", "SK_C3_WARD", "SK_C3_BLINK"], "status": STATUS_PLAYABLE},
	CLASS_4: {"archetype": "reach", "allowed_weapon_families": ["spear"], "offhand_allowed": false, "starter_weapon": "spear_simple",
		"base_stat_profile": {"offense": 1.05, "defense": 1.00, "hp": 1.00, "mobility": 1.05, "range": 1.10},
		"skill_pool": ["SK_C4_THRUST", "SK_C4_SWEEP", "SK_C4_VAULT", "SK_C4_BRACE"], "status": STATUS_PLAYABLE},
	CLASS_5_SUPPORT: {"archetype": "support", "allowed_weapon_families": ["book"], "offhand_allowed": false, "starter_weapon": "book_simple",
		"base_stat_profile": {"offense": 0.90, "defense": 1.15, "hp": 1.15, "mobility": 0.95, "range": 1.05},
		"skill_pool": ["SK_C5_MEND", "SK_C5_WARD", "SK_C5_RITE", "SK_C5_SMITE"], "status": STATUS_PLAYABLE},
	LEGACY_CLASS: {"archetype": "melee", "allowed_weapon_families": ["sword", "axe", "hammer", "bow", "staff", "spear", "book"], "offhand_allowed": true, "starter_weapon": "sword_simple",
		"base_stat_profile": {"offense": 1.00, "defense": 1.00, "hp": 1.00, "mobility": 1.00, "range": 1.00},
		"skill_pool": [], "status": STATUS_PLAYABLE},
}

## A15 — SUPPORT deixou de ser CONTENT_REQUIRED; agora é a 5ª classe JOGÁVEL (cura/sustain/proteção + dano solo).
const CONTENT_REQUIRED_CLASSES := {}

## A15 §10 — multiplicador de stat REAL da classe (base_stat_profile). Entra NATURALMENTE no CP via PlayerPowerModifiers;
## NUNCA class_bonus_cp artificial. LEGACY_CLASS/desconhecido = 1.0 (sem efeito).
static func stat_mult(class_id: String, key: String) -> float:
	return float((CLASSES.get(class_id, {}) as Dictionary).get("base_stat_profile", {}).get(key, 1.0))

static func archetype_of(class_id: String) -> String:
	return str((CLASSES.get(class_id, {}) as Dictionary).get("archetype", "melee"))

static func exists(class_id: String) -> bool:
	return CLASSES.has(class_id)

static func get_def(class_id: String) -> Dictionary:
	return CLASSES.get(class_id, {}).duplicate(true)

static func is_free(_class_id: String) -> bool:
	return true   # §7 — toda classe base é gratuita, sempre

static func display_name(_class_id: String) -> String:
	return "CANON_REVIEW_REQUIRED"   # §5 — nome narrativo pendente de Canon

## Uma arma pertence à família permitida da classe?
static func weapon_allowed(class_id: String, weapon_family: String) -> bool:
	return exists(class_id) and (CLASSES[class_id]["allowed_weapon_families"] as Array).has(weapon_family)

## Uma skill pertence ao pool da classe? Aceita o pool declarado (A13) OU o kit real do ClassAbilityLibrary (A15).
static func skill_in_pool(class_id: String, skill_id: String) -> bool:
	if not exists(class_id):
		return false
	if (CLASSES[class_id]["skill_pool"] as Array).has(skill_id):
		return true
	return ClassAbilityLibrary.ability_belongs_to_class(skill_id, class_id)

static func starter_weapon(class_id: String) -> String:
	return str(CLASSES.get(class_id, {}).get("starter_weapon", "sword_simple"))

static func playable_ids() -> Array:
	return [CLASS_1, CLASS_2, CLASS_3, CLASS_4, CLASS_5_SUPPORT]   # A15 — 5 classes jogáveis, todas gratuitas

## Info MECÂNICA p/ o Character Creator (§39) — role/range/weapon family/survivability/identity. SEM lore inventada.
static func class_info(class_id: String) -> Dictionary:
	if not exists(class_id): return {}
	var d := get_def(class_id)
	var p: Dictionary = d["base_stat_profile"]
	var surv := float(p.get("hp", 1.0)) * float(p.get("defense", 1.0))
	var role_map := {"melee": "BRUISER", "ranged": "MARKSMAN", "magic": "CASTER", "reach": "SKIRMISHER", "support": "HEALER"}
	var role: String = str(role_map.get(str(d["archetype"]), "FIGHTER"))
	return {
		"class_id": class_id, "display_name": display_name(class_id), "archetype": str(d["archetype"]),
		"role": role, "weapon_families": (d["allowed_weapon_families"] as Array).duplicate(),
		"range_tendency": float(p.get("range", 1.0)), "offense_tendency": float(p.get("offense", 1.0)),
		"survivability": surv, "free": true,
	}
