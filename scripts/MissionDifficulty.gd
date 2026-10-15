class_name MissionDifficulty extends RefCounted
## FATIA A18.7 — DIFICULDADE de missão (§A18.7). V1: NORMAL/VETERAN habilitadas; NIGHTMARE/ABYSSAL PREPARADAS mas
## DESABILITADAS. Data-driven: cada dificuldade modifica hp/dano/xp/loot/elite/reward. ★ Mais difícil ≠ mais XP/hora
## garantido — a eficiência depende da build (§22). Puro/testável. Nomes finais = CANON_REVIEW_REQUIRED.

const TIERS := {
	"NORMAL":  {"enabled": true,  "label": "Normal",  "hp_mult": 1.0, "dmg_mult": 1.0, "xp_mult": 1.0, "gold_mult": 1.0, "elite_mult": 1.0, "special_mult": 1.0, "completion_mult": 1.0},
	"VETERAN": {"enabled": true,  "label": "Veterano", "hp_mult": 2.2, "dmg_mult": 1.6, "xp_mult": 1.8, "gold_mult": 1.6, "elite_mult": 1.5, "special_mult": 1.4, "completion_mult": 1.6},
	# preparadas, NÃO habilitadas (não mostrar/aceitar na V1)
	"NIGHTMARE": {"enabled": false, "label": "Pesadelo", "hp_mult": 4.0, "dmg_mult": 2.4, "xp_mult": 3.0, "gold_mult": 2.2, "elite_mult": 2.0, "special_mult": 2.0, "completion_mult": 2.4},
	"ABYSSAL":   {"enabled": false, "label": "Abissal",  "hp_mult": 7.0, "dmg_mult": 3.2, "xp_mult": 4.5, "gold_mult": 3.0, "elite_mult": 2.6, "special_mult": 2.6, "completion_mult": 3.4},
}

static func get_tier(tier: String) -> Dictionary:
	return TIERS.get(tier, TIERS["NORMAL"]).duplicate(true)

static func is_enabled(tier: String) -> bool:
	return bool(TIERS.get(tier, {}).get("enabled", false))

## Dificuldade permitida por esta missão E habilitada no jogo (§A18.7 — cliente não força tier locked, §DIFF-T08).
static func is_selectable(tier: String, mission_available: Array) -> bool:
	return is_enabled(tier) and mission_available.has(tier)
