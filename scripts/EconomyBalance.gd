class_name EconomyBalance
## EconomyBalance — HUB de leitura da economia comercial/de progressão (FATIA A7.2, §46/§47). NÃO cria tabelas
## concorrentes: DELEGA às fontes reais (RefineMath = chance/pity/custo/floors · RewardMath = Fragmentos/ouro/XP ·
## SupportDrops = first-clear · ItemDB = bônus de suporte · LootManager = fatores de salvage). Concentra aqui só
## os ALVOS DE EXPERIÊNCIA e o modelo de Fragmentos/h por perfil — para o simulador/relatório consultarem 1 lugar.
##
## ★ NÃO implementa pagamento real, loja ou marketplace (§2/§64). Prepara a economia; não cobra.

# ── ALVO DE EXPERIÊNCIA por faixa de refino (§21) — em HORAS de farm focado. Informacional/validação. ──
const TARGET_HOURS := {
	"+0..+5":  {"max": 1.0,   "label": "trivial/tutorial"},
	"+5..+10": {"max": 6.0,   "label": "progressão acessível"},
	"+10..+15":{"max": 30.0,  "label": "primeiro grind sério"},
	"+15..+18":{"max": 80.0,  "label": "endgame real"},
	"+18..+20":{"max": 200.0, "label": "aspiracional (free plausível)"},
}

# ── Classificação COMERCIAL FUTURA dos suportes (§58/§59) — SEM PREÇO EM R$. Baseada em grind/risco poupado. ──
const SUPPORT_TIER := {
	"catalyst_refine":   {"tier": "baixo",   "role": "aceleração recorrente/acessível"},
	"catalyst_superior": {"tier": "médio",   "role": "aceleração forte"},
	"seal_preservation": {"tier": "alto",    "role": "proteção do endgame (evita downgrade)"},
	"seal_absolute":     {"tier": "premium", "role": "garantia de UMA tentativa — raríssimo/controlado"},
}

# ── Delegações (fonte única) ──
static func refine_cost(level: int) -> int: return RefineMath.cost(level)
static func refine_base_chance(level: int) -> float: return RefineMath.base_chance(level)
static func refine_pity_max() -> float: return RefineMath.PITY_MAX_BONUS
static func refine_pity_per_fail() -> float: return RefineMath.PITY_PER_FAIL
static func fragments_cycle(global_stage: int) -> int: return RewardMath.fragments_cycle(global_stage)
static func catalyst_pp(item_id: String) -> float: return float(ItemDB.get_item(item_id).get("catalyst_pp", 0.0))

# ── PERFIS DE JOGADOR (§5) — stage/CP plausíveis (não personagem impossível). ──
## Retorna [{id, stage, note}]. O simulador estima Fragmentos/h em cada um.
static func player_profiles() -> Array:
	return [
		{"id": "A-inicio", "stage": 6,  "note": "P0, fases iniciais"},
		{"id": "B-midgame", "stage": 45, "note": "P0/P1, faixa intermediária"},
		{"id": "C-endgame-inicial", "stage": 95, "note": "múltiplos Prestígios, +10..+15"},
		{"id": "D-endgame", "stage": 130, "note": "+15..+18"},
		{"id": "E-aspiracional", "stage": 170, "note": "+18..+20"},
	]

## Fragmentos/h estimados num perfil (renda de ciclo escalada + salvage bônus não modelado aqui). speed=x1/x2/x3.
## Usa R=1.0 (jogador no seu nível). Offline sempre x1. Fonte: RewardMath.fragments_per_hour.
static func fragments_per_hour_at(global_stage: int, speed_mult: float = 1.0) -> float:
	var t := "normal"
	return RewardMath.fragments_per_hour(global_stage, t, 1.0, speed_mult)
