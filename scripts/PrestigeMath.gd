class_name PrestigeMath
## PrestigeMath — a MATEMÁTICA do Prestígio / Master Level (FATIA A6). FUNÇÕES PURAS (determinísticas, sem
## estado, sem RNG, sem GameState/Node) → 100% testáveis e consumíveis pelo PrestigeManager/IdleHud.
##
## Responde: qual stage o próximo Prestígio exige? quantos Selos? qual o Master multiplier? qual o CP projetado
## depois de prestigiar (SEM mutar save)? Nada aqui paga reward, reseta estado nem toca combate.
##
## ★ AUDITORIA ascension.ts (§26): o Ascension web é TIER DE ALMA (nível permanente + multiplicadores cumulativos
## por Tier + aura + título romano) — NÃO é reset. Reaproveitamos aqui só o CONCEITO de multiplicador permanente
## e a APRESENTAÇÃO por título; NÃO portamos o multiplicador do Nexo. A6 tem UMA fonte de bônus de reset:
## MASTER_MULTIPLIER = 1.08^M. Sem double-count com o Nexo (que não existe no runtime Godot).

# ── Requisito de STAGE do próximo Prestígio ────────────────────────────────────────────────────────
## PRESTIGE_STAGE_REQUIREMENT(p) = 100 + 20×p, onde p = Prestígios JÁ realizados (§10).
##   P0→exige stage 100 · P1→120 · P2→140 · …
const PRESTIGE_STAGE_BASE := 100
const PRESTIGE_STAGE_STEP := 20

## PRESTIGE_SEALS_REQUIRED(p) = 10 + 2×p (§11). P0→10 · P1→12 · P2→14 · …
const PRESTIGE_SEALS_BASE := 10
const PRESTIGE_SEALS_STEP := 2

## MASTER_MULTIPLIER(M) = 1.08^M (§22). Bônus PERMANENTE de reset, aplicado ao PODER REAL (dano + HP), nunca
## como CP artificial. M0=1.0 · M1=1.08 · M5≈1.469 · M10≈2.159.
const MASTER_BASE := 1.08

const STAGES_PER_CHAPTER := 10

## Stage global exigido para o Prestígio nº (p+1), dado p Prestígios já feitos.
static func required_stage(prestige_count: int) -> int:
	return PRESTIGE_STAGE_BASE + PRESTIGE_STAGE_STEP * maxi(0, prestige_count)

## Selos exigidos para o próximo Prestígio.
static func required_seals(prestige_count: int) -> int:
	return PRESTIGE_SEALS_BASE + PRESTIGE_SEALS_STEP * maxi(0, prestige_count)

## Master multiplier permanente para um Master Level M.
static func master_multiplier(master_level: int) -> float:
	return pow(MASTER_BASE, float(maxi(0, master_level)))

## Uma stage global é BOSS-STAGE (fonte de Selo)? Todo múltiplo de 10 (1-10, 2-10, …). §8.
static func is_boss_global(global_stage: int) -> bool:
	return global_stage >= STAGES_PER_CHAPTER and (global_stage % STAGES_PER_CHAPTER) == 0

## Nº de boss-stages já CONCLUÍDAS EM AVANÇO dado o maior global ALCANÇADO no ciclo. Concluir a boss G (múltiplo
## de 10) em avanço leva o herói a G+1 → "cleared" ⟺ highest > G. Logo seals = floor((highest-1)/10). Usado na
## MIGRAÇÃO conservadora (§47): credita só os Selos REALMENTE ganhos ao chegar onde chegou (não é Prestígio grátis
## — Prestígio ainda exige stage≥100). §16/§17.
static func seals_from_highest(cycle_highest_global: int) -> int:
	return maxi(0, (maxi(1, cycle_highest_global) - 1) / STAGES_PER_CHAPTER)

## Watermark de Selo (maior boss-global creditado) coerente com um nº de Selos derivado do highest.
static func seal_high_from_highest(cycle_highest_global: int) -> int:
	return seals_from_highest(cycle_highest_global) * STAGES_PER_CHAPTER

## Projeção PURA do CP após o próximo Prestígio (§28/§29): o CP escala LINEARMENTE com o Master multiplier
## (dano ×mult e HP ×mult ⇒ CP = sqrt(off×hp) ×mult). Como o personagem-base (nível/equip) não muda no reset,
## projected = round(cp × next_mult / cur_mult). NÃO muta save, NÃO executa Prestígio.
static func projected_cp(current_cp: int, master_level: int) -> int:
	var cur := master_multiplier(master_level)
	var nxt := master_multiplier(master_level + 1)
	if cur <= 0.0:
		return current_cp
	return int(round(float(current_cp) * nxt / cur))

## Rótulo presentacional do Master Level (reaproveita a numeração romana do ascension.ts — §27, puramente
## presentacional, SEM multiplicador novo). "Mestre" + romano; M0 = "" (ainda não é Mestre).
static func master_title(master_level: int) -> String:
	if master_level <= 0:
		return ""
	return "Mestre %s" % _roman(master_level)

## Romano até valores altos (espelha ascension.ts toRoman; suficiente p/ Master Levels realistas).
static func _roman(n: int) -> String:
	if n <= 0:
		return ""
	var vals := [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
	var syms := ["M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"]
	var v := n
	var out := ""
	for i in range(vals.size()):
		while v >= vals[i]:
			out += syms[i]
			v -= vals[i]
	return out
