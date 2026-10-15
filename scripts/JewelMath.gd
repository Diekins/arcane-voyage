class_name JewelMath
## JewelMath — a MATEMÁTICA das Joias (FATIA A7, PARTE III). FUNÇÕES PURAS (sem estado/RNG/GameState).
##
## ★ AUDITORIA do sistema web (`src/lib/gems.ts`, §23): lá as gemas vivem em SOCKETS por INSTÂNCIA de item
## (épico=1/lendário=2), com tipos canônicos **Rubi/Safira/Esmeralda/Diamante** (dano/defesa/HP/crítico),
## qualidade Lascada/Polida/Perfeita (×1/×2/×4) e lapidação 3→1. **NÃO portamos o modelo por-instância** (§25:
## o inventário Godot não tem item-instance robusto). Portamos a IDENTIDADE/EFEITO canônico como progressão
## POR TIPO (nível global por joia), igual ao Refino — permanente, sink de Fragmentos (§26, fallback permitido).
##
## ★ Diamante (Crítico) é OMITIDO na V1: o combate Godot atual NÃO tem sistema de crítico → não teria efeito
## real (proibido bônus sem stat real, §28). Fica documentado p/ quando houver crítico.
##
## MAPA canônico → stat REAL do Godot:
##   Rubi (ofensiva)   → attack
##   Safira (defesa)   → defense
##   Esmeralda (vida)  → max_hp   (espelha o flatHp=8 da esmeralda web)

const JEWEL_MAX_LEVEL := 10                  # cap V1 (§29)
const JEWEL_COST_BASE := 15.0                # +0→+1 = 15 Fragmentos
const JEWEL_COST_GROWTH := 1.6               # custo ∝ 1.6^level

## Joias V1 (nomes canônicos) → {stat REAL, flat por nível}. flat espelha a ordem de grandeza do web.
const JEWELS := {
	"ruby":     {"name": "Rubi",      "stat": "attack",  "per_level": 2},
	"sapphire": {"name": "Safira",    "stat": "defense", "per_level": 1},
	"emerald":  {"name": "Esmeralda", "stat": "max_hp",  "per_level": 8},
}
const JEWEL_ORDER := ["ruby", "sapphire", "emerald"]

static func exists(jewel_type: String) -> bool:
	return JEWELS.has(jewel_type)

static func display_name(jewel_type: String) -> String:
	return str(JEWELS.get(jewel_type, {}).get("name", jewel_type))

## Stat REAL do Godot que esta joia melhora ("attack"/"defense"/"max_hp").
static func stat_key(jewel_type: String) -> String:
	return str(JEWELS.get(jewel_type, {}).get("stat", ""))

## Custo em Fragmentos p/ subir do nível ATUAL → +1. round(15 × 1.6^level).
static func cost(level: int) -> int:
	return int(round(JEWEL_COST_BASE * pow(JEWEL_COST_GROWTH, float(maxi(0, level)))))

static func is_max(level: int) -> bool:
	return level >= JEWEL_MAX_LEVEL

## Bônus FLAT desta joia no nível dado (flat = per_level × level). Aditivo ao stat real do personagem.
static func flat_bonus(jewel_type: String, level: int) -> int:
	var per := int(JEWELS.get(jewel_type, {}).get("per_level", 0))
	return per * clampi(level, 0, JEWEL_MAX_LEVEL)

## Soma do flat de TODAS as joias que melhoram `stat_key`, dado o mapa {jewel_type: level}. Usado no chokepoint
## de stats do GameState (attack_bonus/defense_bonus/max_hp) — CP sobe naturalmente (§27/§28), sem CP direto.
static func flat_for_stat(stat: String, levels: Dictionary) -> int:
	var s := 0
	for jt in JEWEL_ORDER:
		if stat_key(jt) == stat:
			s += flat_bonus(jt, int(levels.get(jt, 0)))
	return s
