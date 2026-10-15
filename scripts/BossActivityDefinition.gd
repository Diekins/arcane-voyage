class_name BossActivityDefinition extends RefCounted
## FATIA A19.2/A19.3 — DEFINIÇÃO data-driven do primeiro Boss (Wolf Alpha), fechando o Chapter 1. Reusa o contrato
## de PveActivity (TYPE_BOSS) e o BossToolkit (BossAbility windup/telegraph). Boss futuro = DATA+ASSET+BALANCE, nunca
## `if boss == wolf_alpha`. Nomes/lore = CANON_REVIEW_REQUIRED. Recompensa first-clear GARANTIDA e class-compatible.

const BOSSES := {
	"BOSS_WOLF_ALPHA": {
		"boss_id": "BOSS_WOLF_ALPHA", "chapter_id": "CHAPTER_1_WOLF", "display_name_key": "MOONSCAR — O ALFA MARCADO",
		"map_id": "MAP_PLAINS", "spot_profile": "alpha_den", "recommended_cp": 1400,
		"visual_id": "young_wolf",   # fallback (CODEX_BOSS_ASSET_REQUIRED)
		"boss_stats_profile": {"base_hp": 2200, "base_dmg": 14, "attack_interval": 1.4},
		# 3 fases por % de HP (§14). Cada fase pode escalar dano/cadência.
		"phase_profile": [
			{"name": "P1", "from": 1.0, "to": 0.6, "dmg_mult": 1.0, "interval_mult": 1.0},
			{"name": "P2", "from": 0.6, "to": 0.3, "dmg_mult": 1.25, "interval_mult": 0.9, "on_enter": "HOWL"},
			{"name": "P3", "from": 0.3, "to": 0.0, "dmg_mult": 1.6, "interval_mult": 0.75, "on_enter": "FRENZY"},
		],
		# abilities V1 (§15): BITE (básico, via cadência), HEAVY_LUNGE (telegraphed charge), HOWL/FRENZY (enrage por fase).
		"boss_ability_profile": {
			"heavy": {"kind": "charge", "damage": 40, "windup": 0.9, "cooldown": 5.0, "telegraph": true},
			"howl": {"kind": "enrage", "dmg_mult": 1.15},
			"frenzy": {"kind": "enrage", "dmg_mult": 1.3, "speed_mult": 1.3},
		},
		"intro_profile": {"skippable_after_first": true, "beats": [
			"A matilha silencia.", "Algo observa além da névoa.", "MOONSCAR — O ALFA MARCADO"]},
		"audio_profile": {"intro": "boss_intro", "roar": "boss_roar", "bite": "boss_bite", "howl": "boss_howl",
			"heavy": "boss_heavy", "frenzy": "boss_frenzy", "hit": "boss_hit", "death": "boss_death", "victory": "boss_victory"},
		# recompensa: FIRST-CLEAR garantida (rare, por família de arma da classe) + loot normal.
		"reward_profile": {
			"first_clear": {"xp": 3000, "gold": 2500, "guaranteed_gear_by_weapon": true},
			"repeat": {"xp": 400, "gold": 300, "gear_chance": 0.5, "gear_pool": ["armor_reinforced", "boots_reinforced", "ring_reinforced"]},
		},
		"unlock_rule": {"prev_mission": "MISSION_006"}, "repeat_policy": {"replayable": true, "first_clear_once": true},
		"enabled": true,
	},
	# A20 CHAPTER 2 — Boss do arco de cristal. Sprite real bosses/crystal_golem existe. Só DADO; runtime reusado.
	"BOSS_CRYSTAL_GOLEM": {
		"boss_id": "BOSS_CRYSTAL_GOLEM", "chapter_id": "CHAPTER_2_CRYSTAL", "display_name_key": "O GOLEM DO CORAÇÃO",
		"map_id": "MAP_CAVE", "spot_profile": "crystal_heart", "recommended_cp": 9000,
		"visual_id": "crystal_golem",
		"boss_stats_profile": {"base_hp": 9000, "base_dmg": 26, "attack_interval": 1.6},
		"phase_profile": [
			{"name": "P1", "from": 1.0, "to": 0.6, "dmg_mult": 1.0, "interval_mult": 1.0},
			{"name": "P2", "from": 0.6, "to": 0.3, "dmg_mult": 1.25, "interval_mult": 0.9, "on_enter": "HOWL"},
			{"name": "P3", "from": 0.3, "to": 0.0, "dmg_mult": 1.6, "interval_mult": 0.75, "on_enter": "FRENZY"},
		],
		"boss_ability_profile": {
			"heavy": {"kind": "charge", "damage": 60, "windup": 1.0, "cooldown": 5.5, "telegraph": true},
			"howl": {"kind": "enrage", "dmg_mult": 1.15}, "frenzy": {"kind": "enrage", "dmg_mult": 1.3, "speed_mult": 1.3},
		},
		"intro_profile": {"skippable_after_first": true, "beats": ["O coração de cristal treme.", "Uma forma se ergue do vidro.", "O GOLEM DO CORAÇÃO"]},
		"audio_profile": {"intro": "boss_intro", "roar": "boss_roar", "bite": "boss_bite", "howl": "boss_howl", "heavy": "boss_heavy", "frenzy": "boss_frenzy", "hit": "boss_hit", "death": "boss_death", "victory": "boss_victory"},
		"reward_profile": {
			"first_clear": {"xp": 40000, "gold": 30000, "guaranteed_gear_by_weapon": true},
			"repeat": {"xp": 3000, "gold": 2000, "gear_chance": 0.5, "gear_pool": ["armor_reinforced", "helmet_reinforced", "amulet_reinforced"]},
		},
		"unlock_rule": {"prev_mission": "C2_M008"}, "repeat_policy": {"replayable": true, "first_clear_once": true}, "enabled": true,
	},
	# A27 — CHAPTER 3 BOSS: ARANHA MATRIARCA (spider_matriarch). NÃO confundir com a MATRIARCA DAS RAÍZES (root_matriarch,
	# um MOB — intocada). Asset REAL em mobs/runtime/spider_matriarch.png (640×160, 4×160). Reusa BossEncounterRuntime.
	# Fecha o Chapter 3 (chapter_id CHAPTER_3_SPIDER ⇒ mark_boss_cleared seta GP_CHAPTER_3_SPIDER_COMPLETE). Só DADO.
	"BOSS_CH3_SPIDER_MATRIARCH": {
		"boss_id": "BOSS_CH3_SPIDER_MATRIARCH", "chapter_id": "CHAPTER_3_SPIDER", "display_name": "ARANHA MATRIARCA",
		"display_name_key": "ARANHA MATRIARCA", "map_id": "MAP_PLAINS", "spot_profile": "deep_nest", "recommended_cp": 30000,
		"visual_id": "spider_matriarch", "visual_key": "mobs/runtime/spider_matriarch",   # asset fora de bosses/ (novo layout)
		"boss_stats_profile": {"base_hp": 150000, "base_dmg": 460, "attack_interval": 1.5},
		"phase_profile": [
			{"name": "P1", "from": 1.0, "to": 0.5, "dmg_mult": 1.0, "interval_mult": 1.0},
			{"name": "P2", "from": 0.5, "to": 0.0, "dmg_mult": 1.35, "interval_mult": 0.8, "on_enter": "FRENZY"},
		],
		"boss_ability_profile": {
			"heavy": {"kind": "charge", "damage": 450, "windup": 1.0, "cooldown": 6.0, "telegraph": true},   # investida de presas
			"venom": {"kind": "dot", "dps": 220, "duration": 3.0, "cooldown": 8.0, "telegraph": true},         # SPIDER ABILITY: veneno (DoT)
			"frenzy": {"kind": "enrage", "dmg_mult": 1.25, "speed_mult": 1.3},                                 # P2: ninhada em fúria
		},
		"intro_profile": {"skippable_after_first": true, "beats": ["A teia estremece.", "Oito olhos se abrem no escuro.", "ARANHA MATRIARCA"]},
		"audio_profile": {"intro": "boss_intro", "roar": "matriarch_roar", "bite": "matriarch_bite", "heavy": "matriarch_lunge", "venom": "matriarch_venom", "frenzy": "matriarch_frenzy", "hit": "boss_hit", "death": "matriarch_death", "victory": "boss_victory"},
		"reward_profile": {
			"first_clear": {"xp": 400000, "gold": 260000, "guaranteed_gear_by_weapon": true},
			"repeat": {"xp": 30000, "gold": 20000, "gear_chance": 0.5, "gear_pool": ["armor_reinforced", "ring_reinforced", "amulet_simple"]},
		},
		"unlock_rule": {"prev_mission": "C3_M008"}, "repeat_policy": {"replayable": true, "first_clear_once": true}, "enabled": true,
	},
	# A40 — CHAPTER 4 BOSS: encerra a COSTA DO SAL-VENTO (chapter_id CHAPTER_4_SALTWIND ⇒ mark_boss_cleared seta
	# GP_CHAPTER_4_SALTWIND_COMPLETE). Só DADO; runtime/reward/bestiary/acquisition REUSADOS (data-driven).
	# ✅ A40 CLOSEOUT (05/09/2026) — a arte do Codex chegou e PASSOU o contrato. O fallback LOUD `tide_warden` foi
	# removido daqui: `visual_id` agora é o asset REAL `salt_split_warden`.
	# Prova (via `_a40_assetproof.gd`, headless): BASE/SIDE/UP = `assets/actors/bosses/salt_split_warden{,_side,_up}.png`,
	# 640×160 ⇒ frame_size=160, frame_count=4; `ActorAssetValidator.validate_actor(..., 160, 4)` ⇒ ok=true, 0 erros.
	# Sem `visual_key`: `MissionHost:127` resolve o default `bosses/<visual_id>` ⇒ `bosses/salt_split_warden`. ✔
	# ⚠️ `tide_warden` CONTINUA existindo como MOB do Chapter 4 (`mobs/tide_warden*.png`) — só deixou de ser fallback do BOSS.
	# ⚠️ display_name adota o candidato `salt_split_warden` ⇒ CANON_REVIEW_REQUIRED (nome não canonizado sem aprovação).
	"BOSS_CH4_SALT_WARDEN": {
		"boss_id": "BOSS_CH4_SALT_WARDEN", "chapter_id": "CHAPTER_4_SALTWIND",
		"display_name": "salt_split_warden",                 # candidato (CANON_REVIEW_REQUIRED)
		"display_name_key": "O GUARDIÃO DA TEMPESTADE",       # provisional (CANON_REVIEW_REQUIRED)
		"map_id": "MAP_SALT_COAST", "spot_profile": "storm_shore", "recommended_cp": 78000,
		"visual_id": "salt_split_warden",                    # ✅ asset REAL (A40 closeout) — sem fallback
		"boss_asset_required": false, "asset_candidate": "salt_split_warden", "asset_status": "READY",
		"boss_stats_profile": {"base_hp": 380000, "base_dmg": 1050, "attack_interval": 1.5},
		# 2 fases (§5): P1 (básico/heavy/signature) → limiar 0.55 → P2 (pressão maior + signature modificada + frenzy).
		"phase_profile": [
			{"name": "P1", "from": 1.0, "to": 0.55, "dmg_mult": 1.0, "interval_mult": 1.0},
			{"name": "P2", "from": 0.55, "to": 0.0, "dmg_mult": 1.4, "interval_mult": 0.8, "on_enter": "FRENZY"},
		],
		# BASIC (cadência) · HEAVY (quebra-mar telegrafado) · SIGNATURE costeira: MARÉ (DoT sustentado, ≠ esquivável) ·
		# PHASE_TRANSITION: frenzy (tempestade desperta). Máx. 4 mecânicas (§7). `signature` = slot genérico de DoT.
		"boss_ability_profile": {
			"heavy": {"kind": "charge", "damage": 1050, "windup": 1.0, "cooldown": 6.0, "telegraph": true},
			"signature": {"kind": "dot", "dps": 520, "duration": 3.0, "cooldown": 8.0, "telegraph": true, "label": "MARÉ"},
			"frenzy": {"kind": "enrage", "dmg_mult": 1.3, "speed_mult": 1.3},
		},
		# NORMAL/VETERAN (§8). Nightmare fora. Veteran = mais HP/dano/reward, MESMA identidade.
		"difficulty_profile": {
			"NORMAL": {"hp_mult": 1.0, "dmg_mult": 1.0, "reward_mult": 1.0},
			"VETERAN": {"hp_mult": 1.7, "dmg_mult": 1.4, "reward_mult": 1.9},
		},
		"difficulties": ["NORMAL", "VETERAN"],
		"intro_profile": {"skippable_after_first": true, "beats": [
			"A maré recua além do normal.", "O céu escurece sobre a costa.", "O GUARDIÃO DA TEMPESTADE"]},
		"audio_profile": {"intro": "boss_intro", "roar": "boss_roar", "bite": "boss_bite", "heavy": "boss_heavy",
			"signature": "boss_surge", "frenzy": "boss_frenzy", "hit": "boss_hit", "death": "boss_death", "victory": "boss_victory"},
		"reward_profile": {
			"first_clear": {"xp": 5000000, "gold": 3000000, "guaranteed_gear_by_weapon": true,
				"material": {"name": "Olho da Tempestade", "qty": 1}},
			"repeat": {"xp": 300000, "gold": 200000, "gear_chance": 0.5,
				"gear_pool": ["armor_reinforced", "boots_reinforced", "ring_reinforced"]},
		},
		"unlock_rule": {"prev_mission": "C4_M008"}, "repeat_policy": {"replayable": true, "first_clear_once": true},
		"enabled": true,
	},
	# A44 — CHAPTER 5 BOSS: MATRIARCA DAS RAÍZES. Fecha o NINHO DAS RAÍZES ANTIGAS (chapter_id CHAPTER_5_ROOT_NEST ⇒
	# mark_boss_cleared seta GP_CHAPTER_5_ROOT_NEST_COMPLETE exact-once, §25). ARTE REAL e VALIDADA (A43/A44 audit):
	# mobs/runtime/root_matriarch (640×160, 4×160, BASE/SIDE/UP/shadow) — mesmo contrato do spider_matriarch que funciona.
	# ★★★ IDENTIDADE (§28): MATRIARCA DAS RAÍZES (root_matriarch, BOSS_CH5_ROOT_MATRIARCH) ≠ ARANHA MATRIARCA
	# (spider_matriarch, BOSS_CH3_SPIDER_MATRIARCH) ≠ ancient_root_heart (ELITE) ≠ root_spider (MOB). Só DADO; runtime/
	# reward/bestiary/acquisition REUSADOS (data-driven). MAP REUSE (§4): MAP_ROOT_NEST, sem arena nova.
	"BOSS_CH5_ROOT_MATRIARCH": {
		"boss_id": "BOSS_CH5_ROOT_MATRIARCH", "chapter_id": "CHAPTER_5_ROOT_NEST",
		"display_name": "MATRIARCA DAS RAÍZES", "display_name_key": "MATRIARCA DAS RAÍZES",
		"map_id": "MAP_ROOT_NEST", "spot_profile": "root_core", "recommended_cp": 120000,
		"visual_id": "root_matriarch", "visual_key": "mobs/runtime/root_matriarch",   # asset REAL validado (runtime/)
		"boss_stats_profile": {"base_hp": 280000, "base_dmg": 1900, "attack_interval": 1.5},
		# 2 fases (§6/§12/§15): P1 (básico/heavy/signature ROOT_SURGE) → limiar 0.55 → P2 (pressão + frenzy = ROOT AWAKENING).
		"phase_profile": [
			{"name": "P1", "from": 1.0, "to": 0.55, "dmg_mult": 1.0, "interval_mult": 1.0},
			{"name": "P2", "from": 0.55, "to": 0.0, "dmg_mult": 1.4, "interval_mult": 0.8, "on_enter": "FRENZY"},
		],
		# BASIC (cadência) · HEAVY (golpe de raiz telegrafado §13) · SIGNATURE: ROOT_SURGE (DoT/pressão sustentada §7/§14,
		# ≠ esquivável) · PHASE_TRANSITION: frenzy (ROOT AWAKENING). Máx. 4 mecânicas. `signature`=slot genérico de DoT.
		"boss_ability_profile": {
			"heavy": {"kind": "charge", "damage": 1900, "windup": 1.0, "cooldown": 6.0, "telegraph": true},
			"signature": {"kind": "dot", "dps": 700, "duration": 3.5, "cooldown": 8.0, "telegraph": true, "label": "ROOT_SURGE"},
			"frenzy": {"kind": "enrage", "dmg_mult": 1.35, "speed_mult": 1.3},
		},
		# NORMAL/VETERAN (§9). Nightmare fora. Veteran = mais HP/dano/reward, MESMA identidade. Pipeline existente.
		"difficulty_profile": {
			"NORMAL": {"hp_mult": 1.0, "dmg_mult": 1.0, "reward_mult": 1.0},
			"VETERAN": {"hp_mult": 1.7, "dmg_mult": 1.4, "reward_mult": 1.9},
		},
		"difficulties": ["NORMAL", "VETERAN"],
		"intro_profile": {"skippable_after_first": true, "beats": [
			"As raízes se contorcem no escuro.", "Algo antigo desperta sob o ninho.", "MATRIARCA DAS RAÍZES"]},
		"audio_profile": {"intro": "boss_intro", "roar": "root_roar", "bite": "root_bite", "heavy": "root_heavy",
			"signature": "root_surge", "frenzy": "root_frenzy", "hit": "boss_hit", "death": "root_death", "victory": "boss_victory"},
		# §18/§19 SEM tier novo: xp/gold + gear garantido por arma (existente). repeat = xp/gold (pool informativo).
		"reward_profile": {
			"first_clear": {"xp": 8000000, "gold": 5000000, "guaranteed_gear_by_weapon": true},
			"repeat": {"xp": 400000, "gold": 260000, "gear_chance": 0.5,
				"gear_pool": ["armor_reinforced", "helmet_reinforced", "ring_reinforced", "amulet_simple"]},
		},
		"unlock_rule": {"prev_mission": "C5_M008"}, "repeat_policy": {"replayable": true, "first_clear_once": true},
		"enabled": true,
	},
}

# A40 — multiplicadores por dificuldade (NORMAL default 1.0). Boss sem `difficulty_profile` ⇒ tudo 1.0 (compat).
static func difficulty_mults(boss_id: String, difficulty := "NORMAL") -> Dictionary:
	var dp: Dictionary = BOSSES.get(boss_id, {}).get("difficulty_profile", {})
	var m: Dictionary = dp.get(difficulty, dp.get("NORMAL", {}))
	return {"hp_mult": float(m.get("hp_mult", 1.0)), "dmg_mult": float(m.get("dmg_mult", 1.0)), "reward_mult": float(m.get("reward_mult", 1.0))}

## Dificuldades suportadas (default [NORMAL]).
static func difficulties_of(boss_id: String) -> Array:
	return BOSSES.get(boss_id, {}).get("difficulties", ["NORMAL"])

## A40 — o boss depende de arte AUSENTE? (audit honesto: true ⇒ BLOCKED_BY_BOSS_ASSET no runtime visual).
static func asset_required(boss_id: String) -> bool:
	return bool(BOSSES.get(boss_id, {}).get("boss_asset_required", false))
static func asset_status(boss_id: String) -> String:
	return str(BOSSES.get(boss_id, {}).get("asset_status", "READY"))

# gear rare por família de arma equipada (class-compatible §25). Universal fallback = acessório rare.
const GUARANTEED_BY_WEAPON := {
	"sword": "sword_reinforced", "axe": "sword_reinforced", "hammer": "sword_reinforced",
	"bow": "bow_reinforced", "staff": "staff_reinforced", "book": "book_reinforced", "spear": "spear_reinforced",   # A30: book agora dá gear que support EQUIPA (era staff_reinforced, família proibida p/ CLASS_5)
}
const GUARANTEED_UNIVERSAL := "ring_reinforced"

static func exists(boss_id: String) -> bool: return BOSSES.has(boss_id)
static func get_boss(boss_id: String) -> Dictionary: return BOSSES.get(boss_id, {}).duplicate(true)

## Item garantido do first-clear compatível com a arma da classe (nunca dá Bow p/ quem não usa arco §25).
static func guaranteed_gear_for_weapon(weapon_kind: String) -> String:
	return str(GUARANTEED_BY_WEAPON.get(weapon_kind, GUARANTEED_UNIVERSAL))

## Fase pela fração de HP (§14).
static func phase_for(boss_id: String, hp_frac: float) -> Dictionary:
	var b: Dictionary = BOSSES.get(boss_id, {})
	for ph in b.get("phase_profile", []):
		if hp_frac <= float(ph["from"]) and hp_frac > float(ph["to"]):
			return ph
	var arr: Array = b.get("phase_profile", [])
	return arr[arr.size() - 1] if not arr.is_empty() else {}
