class_name PlayerPowerModifiers
## PlayerPowerModifiers — AGREGADOR ÚNICO dos multiplicadores GLOBAIS de poder do personagem (FATIA A7, PARTE
## VII). Centraliza p/ EVITAR double-count e fórmulas espalhadas (§51/§53).
##
## ★ ORDEM EFETIVA (§52) — cada fonte num chokepoint DISTINTO, sem sobreposição:
##   base stats + nível            → hero_hp_max / faixas de CombatMath
##   equipamento                   → GameState.equip_sum(key)
##   REFINO (por slot)             → multiplicador DENTRO de equip_sum (só o item do slot)
##   JOIAS (por tipo)              → flat aditivo nos accessors attack/defense/max_hp
##   MASTER + COLEÇÕES (GLOBAL)    → AQUI: damage_mult()/hp_mult(), aplicados 1× em CombatMath e max_hp_total
##   → PowerBudget lê o resultado  → CP sobe NATURALMENTE (nunca CP artificial, §1/§39)
##
## ★ Refino/Joias NÃO entram aqui (são item-específicos, já no equip_sum/accessors). Aqui só o que é GLOBAL e
## multiplicativo: Master (1.08^M) × Bestiário (coleção) × Códice (coleção).

## Bônus por TIER de Bestiário reivindicado (§37): +0.10% dano E +0.10% HP. Com ~60 mobs × 5 tiers ⇒ teto
## teórico +30%/+30% (não milhares por cento).
const BESTIARY_DMG_PER_TIER := 0.001
const BESTIARY_HP_PER_TIER := 0.001
## Bônus por MARCO de Códice reivindicado (§47): +0.5% dano E +0.5% HP.
const CODEX_DMG_PER_MILESTONE := 0.005
const CODEX_HP_PER_MILESTONE := 0.005

## Multiplicador de COLEÇÃO (Bestiário + Códice) — SEM Master. Puro sobre os contadores do GameState.
static func collection_damage_mult() -> float:
	var gs = _gs()
	if gs == null:
		return 1.0
	var best := int(gs.bestiary_claimed_tiers_total())
	var cdx := int(gs.codex_claimed_count())
	return (1.0 + BESTIARY_DMG_PER_TIER * float(best)) * (1.0 + CODEX_DMG_PER_MILESTONE * float(cdx))

static func collection_hp_mult() -> float:
	var gs = _gs()
	if gs == null:
		return 1.0
	var best := int(gs.bestiary_claimed_tiers_total())
	var cdx := int(gs.codex_claimed_count())
	return (1.0 + BESTIARY_HP_PER_TIER * float(best)) * (1.0 + CODEX_HP_PER_MILESTONE * float(cdx))

## A15 §10 — tendência de STAT da CLASSE (offense/hp). Entra no CP NATURALMENTE (nunca CP artificial). LEGACY = 1.0.
static func class_damage_mult() -> float:
	var gs = _gs()
	if gs == null: return 1.0
	return CharacterClassDefinition.stat_mult(str(gs.character_class), "offense")

static func class_hp_mult() -> float:
	var gs = _gs()
	if gs == null: return 1.0
	return CharacterClassDefinition.stat_mult(str(gs.character_class), "hp")

## Multiplicador OFENSIVO global final = Master × Coleção × Classe. Consumido por CombatMath (dano do jogador).
static func damage_mult() -> float:
	var gs = _gs()
	var master := 1.0
	if gs != null and gs.has_method("master_multiplier"):
		master = gs.master_multiplier()
	return master * collection_damage_mult() * class_damage_mult()

## Multiplicador DEFENSIVO global final = Master × Coleção × Classe. Consumido por GameState.max_hp_total.
static func hp_mult() -> float:
	var gs = _gs()
	var master := 1.0
	if gs != null and gs.has_method("master_multiplier"):
		master = gs.master_multiplier()
	return master * collection_hp_mult() * class_hp_mult()

static func _gs():
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("GameState")
	return null
