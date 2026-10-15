class_name PowerBudget
## PowerBudget — o PODER REAL do personagem, condensado num único CP (FATIA A3).
##
## ★ REGRA FUNDAMENTAL (§2/§10): o CP é DERIVADO DO RESULTADO REAL DE COMBATE, não de um checklist de
## sistemas. Nada de "+500 por nível" / "+2000 por asa": os sistemas mudam ATRIBUTOS/EFEITOS reais, e o
## CP é recalculado a partir deles → sem double-count. Nível↑ → HP/ataque↑ → offense/effective-HP↑ → CP↑.
##
## OFFENSE = EXPECTED_DPS = expected_damage_por_golpe × golpes_por_segundo   (via CombatMath, SEM RNG)
## DEFENSE = EFFECTIVE_HP = max_hp × (hit_canônico / dano_realmente_tomado)   (via _gs().mitigated_damage)
## RAW_POWER = sqrt(OFFENSE × DEFENSE)   (média geométrica → build desequilibrada NÃO infla CP)
## CP = round(RAW_POWER × CP_DISPLAY_SCALE)
##
## ★ CLASSIFICAÇÃO DE ARMA (§4): SEMPRE por _gs().current_combat_archetype()/current_weapon_type()
## (derivados do weapon_kind/ItemDB), NUNCA por nome textual do item.

## Golpe "canônico" de referência p/ medir mitigação (§6). Um número fixo qualquer serve — o que importa é
## a RAZÃO hit/tomado, que cresce com armadura/defesa reais.
const CANONICAL_HIT := 100

## Escala de EXIBIÇÃO fixa (§8). Calibrada p/ o personagem default REAL (Nv1, desarmado, 100 HP, sem bônus):
##   OFFENSE≈51.43 dps · EFFECTIVE_HP=100 · RAW≈71.71 · CP≈1004 (dentro de 900–1100). Ver benchmark no relatório.
## FIXA (nunca dinâmica por personagem) p/ preservar comparabilidade entre builds.
const CP_DISPLAY_SCALE := 14.0

## Cooldowns por arma/arquétipo — ESPELHAM as constantes do Main.gd (fonte da cadência de ataque real).
## (sword/unarmed 0.35 · axe 0.45 · hammer 0.56 · spear 0.46 · bow 0.55 · staff 0.60 · book 0.72)
const CD_SWORD := 0.35
const CD_AXE := 0.45
const CD_HAMMER := 0.56
const CD_SPEAR := 0.46
const CD_BOW := 0.55
const CD_STAFF := 0.60
const CD_BOOK := 0.72

# ──────────────────────────────────────────────────────────────────────────────────────────────
# OFENSA
# ──────────────────────────────────────────────────────────────────────────────────────────────
## Cadência real (golpes/segundo) do arquétipo/arma atual.
static func attacks_per_second() -> float:
	var cd := attack_cooldown()
	return 1.0 / cd if cd > 0.0 else 0.0

static func attack_cooldown() -> float:
	var arch: String = _gs().current_combat_archetype()
	match arch:
		"ranged": return CD_BOW
		"magic": return CD_STAFF
		"support": return CD_BOOK
		"reach": return CD_SPEAR
		_:
			match _gs().current_weapon_type():
				"axe": return CD_AXE
				"hammer": return CD_HAMMER
				_: return CD_SWORD

## Dano ESPERADO por golpe (SEM RNG) — direto do CombatMath (já inclui equip+proficiência+maestria).
static func expected_damage_per_attack() -> float:
	return CombatMath.player_profile(_gs().current_combat_archetype())["expected"]

## OFFENSE = expected DPS.
static func offense() -> float:
	return expected_damage_per_attack() * attacks_per_second()

# ──────────────────────────────────────────────────────────────────────────────────────────────
# DEFESA / EFFECTIVE HP
# ──────────────────────────────────────────────────────────────────────────────────────────────
## Fator de mitigação = hit_canônico / dano_realmente_tomado (usa a mitigação REAL do GameState — pura, sem RNG).
static func mitigation_factor() -> float:
	var taken: int = _gs().mitigated_damage(CANONICAL_HIT)
	return float(CANONICAL_HIT) / maxf(float(taken), 1.0)

## DEFENSE = HP máx efetivo × fator de mitigação.
static func effective_hp() -> float:
	return float(_gs().max_hp_total()) * mitigation_factor()

# ──────────────────────────────────────────────────────────────────────────────────────────────
# CP
# ──────────────────────────────────────────────────────────────────────────────────────────────
static func raw_power() -> float:
	var o := offense()
	var d := effective_hp()
	if o <= 0.0 or d <= 0.0:
		return 0.0
	return sqrt(o * d)

## CP inteiro exibível. >=1 se houver qualquer ofensa+defesa (evita 0 confuso). Determinístico.
static func cp() -> int:
	var raw := raw_power()
	if raw <= 0.0:
		return 0
	return int(round(raw * CP_DISPLAY_SCALE))

## Breakdown completo (debug/testes/futuro painel). Não-persistido.
static func breakdown() -> Dictionary:
	var o := offense()
	var d := effective_hp()
	return {
		"archetype": _gs().current_combat_archetype(),
		"weapon_type": _gs().current_weapon_type(),
		"expected_damage": expected_damage_per_attack(),
		"attacks_per_second": attacks_per_second(),
		"offense_dps": o,
		"max_hp": _gs().max_hp_total(),
		"mitigation_factor": mitigation_factor(),
		"effective_hp": d,
		"raw_power": raw_power(),
		"cp": cp(),
	}

## Resolve o autoload GameState em RUNTIME (funções static não enxergam o identificador global no compile
## sob `-s`). Vale no jogo e nos self-tests.
static func _gs():
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("GameState")
	return null
