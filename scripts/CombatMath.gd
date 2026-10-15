class_name CombatMath
## CombatMath — FONTE CENTRAL da matemática de DANO (FATIA A1.5).
##
## PROBLEMA que resolve: o dano estava calculado em ~5 caminhos espalhados (melee/arco/cajado/livro do
## jogador + inimigos), cada um montando `randi_range(base) + bônus` à mão. Isso impede um `PowerBudget`
## (CP) confiável na A3, que precisa do DANO ESPERADO **sem rolar RNG**.
##
## ★ REGRA FUNDAMENTAL (A1.5): NÃO rebalanceia. Esta camada ESPELHA os call-sites reais 1:1 — mesma base de
## RNG, mesma pilha de bônus, mesmo `randi_range`. A equivalência pré/pós é provada por RNG semeada no
## self-test. O rebalanceamento (se houver) é de outra fatia.
##
## MODELO: todo dano = BASE aleatória (randi_range) + BÔNUS FLAT (equipamento + proficiência + maestria).
##   • min_damage/max_damage/expected_damage → PUROS, SEM RNG (o `expected` é o que a A3 consulta).
##   • rolled_damage → o combate REAL (usa randi_range, como antes).
##
## ★ CLASSIFICAÇÃO DE ARMA: nunca por nome textual. O arquétipo vem de `_gs().current_combat_archetype()`,
## que já é derivado do SLOT/`weapon_kind` do item (ItemDB) — fonte confiável. Aqui só CONSUMIMOS o archetype.

## Bases de RNG do golpe BÁSICO do jogador por arquétipo (espelham as constantes reais do Main.gd):
##   melee/reach = MOB_DMG (14..22) · ranged(arco)/magic(cajado) = 8..13 · support(livro) = 5..9.
## (No melee vs BOSS o call-site passa a faixa do boss como override — quirk legado preservado.)
const PLAYER_BASE := {
	"melee":   Vector2i(14, 22),
	"reach":   Vector2i(14, 22),
	"ranged":  Vector2i(8, 13),
	"magic":   Vector2i(8, 13),
	"support": Vector2i(5, 9),
}

# ──────────────────────────────────────────────────────────────────────────────────────────────
# PRIMITIVAS PURAS (testáveis sem GameState/RNG)
# ──────────────────────────────────────────────────────────────────────────────────────────────
static func min_damage(base_min: int, _base_max: int, flat_bonus: int) -> int:
	return base_min + flat_bonus

static func max_damage(_base_min: int, base_max: int, flat_bonus: int) -> int:
	return base_max + flat_bonus

## Dano ESPERADO (média) — NUNCA rola RNG. É o valor que o PowerBudget (A3) vai consumir.
static func expected_damage(base_min: int, base_max: int, flat_bonus: int) -> float:
	return (float(base_min) + float(base_max)) * 0.5 + float(flat_bonus)

## Dano ROLADO (combate real) — usa randi_range, exatamente como os call-sites originais.
static func rolled_damage(base_min: int, base_max: int, flat_bonus: int) -> int:
	return randi_range(base_min, base_max) + flat_bonus

## Perfil {min,max,expected} de uma base+bônus quaisquer (puro).
static func profile(base_min: int, base_max: int, flat_bonus: int) -> Dictionary:
	return {
		"min": min_damage(base_min, base_max, flat_bonus),
		"max": max_damage(base_min, base_max, flat_bonus),
		"expected": expected_damage(base_min, base_max, flat_bonus),
	}

# ──────────────────────────────────────────────────────────────────────────────────────────────
# JOGADOR (lê GameState — autoload global; disponível no jogo e nos self-tests do projeto)
# ──────────────────────────────────────────────────────────────────────────────────────────────
## Faixa base de RNG do golpe básico por arquétipo (default melee se desconhecido).
static func player_base_range(archetype: String) -> Vector2i:
	return PLAYER_BASE.get(archetype, PLAYER_BASE["melee"])

## Pilha de BÔNUS FLAT do jogador por arquétipo — ESPELHA os call-sites do Main.gd 1:1:
##   melee/reach: attack + vocation("attack") + stance(capada, só lança)
##   ranged:      attack + vocation("attack") + precision(capada, só arco)
##   magic:       magic + attack + vocation("magic") + arcane(capada, só cajado)
##   support:     magic + vocation("magic")
static func player_flat_bonus(archetype: String) -> int:
	match archetype:
		"ranged":
			return _gs().attack_bonus() + _gs().vocation_bonus("attack") + _gs().precision_damage_bonus()
		"magic":
			return _gs().magic_bonus() + _gs().attack_bonus() + _gs().vocation_bonus("magic") + _gs().arcane_damage_bonus()
		"support":
			return _gs().magic_bonus() + _gs().vocation_bonus("magic")
		_:
			return _gs().attack_bonus() + _gs().vocation_bonus("attack") + _gs().stance_damage_bonus()

## FATIA A6/A7 — multiplicador OFENSIVO GLOBAL do jogador, aplicado ao dano FINAL (player_profile p/ o CP +
## player_roll p/ o combate real) → HUD e dano real usam A MESMA regra. FATIA A7: passa a ser o agregado ÚNICO
## `PlayerPowerModifiers.damage_mult()` = Master × Bestiário × Códice (§51/§52), sem double-count. Sem sistema
## de poder ⇒ 1.0 (zero impacto).
static func player_master_mult() -> float:
	return PlayerPowerModifiers.damage_mult()

## Perfil COMPLETO {min,max,expected} do golpe básico do jogador (p/ o PowerBudget da A3 — SEM rolar RNG).
## base_min/base_max < 0 = usa a faixa do arquétipo; >=0 = override (ex.: melee vs boss). Já com Master mult (A6).
static func player_profile(archetype: String, base_min: int = -1, base_max: int = -1) -> Dictionary:
	var b := player_base_range(archetype)
	var bmin := b.x if base_min < 0 else base_min
	var bmax := b.y if base_max < 0 else base_max
	var p := profile(bmin, bmax, player_flat_bonus(archetype))
	var m := player_master_mult()
	return {
		"min": int(round(float(p["min"]) * m)),
		"max": int(round(float(p["max"]) * m)),
		"expected": float(p["expected"]) * m,
	}

## ROLL do golpe básico do jogador (combate real). Mesmo resultado que os call-sites originais × Master mult (A6).
static func player_roll(archetype: String, base_min: int = -1, base_max: int = -1) -> int:
	var b := player_base_range(archetype)
	var bmin := b.x if base_min < 0 else base_min
	var bmax := b.y if base_max < 0 else base_max
	return int(round(float(rolled_damage(bmin, bmax, player_flat_bonus(archetype))) * player_master_mult()))

# ──────────────────────────────────────────────────────────────────────────────────────────────
# INIMIGO (mob/boss): faixa simples, sem bônus de equipamento
# ──────────────────────────────────────────────────────────────────────────────────────────────
static func enemy_profile(dmin: int, dmax: int) -> Dictionary:
	return {"min": dmin, "max": dmax, "expected": (float(dmin) + float(dmax)) * 0.5}

## ROLL de dano de inimigo (mob/boss) — equivalente exato a randi_range(dmin, dmax).
static func enemy_roll(dmin: int, dmax: int) -> int:
	return randi_range(dmin, dmax)

## Resolve o autoload GameState em RUNTIME (funções static não enxergam o identificador global no compile
## sob `-s`). Vale no jogo e nos self-tests.
static func _gs():
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("GameState")
	return null
