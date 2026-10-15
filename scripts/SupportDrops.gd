class_name SupportDrops
## SupportDrops — recompensas ESPECIAIS de refino (Catalisadores/Selos) por FIRST-CLEAR (FATIA A7.1, PARTE G,
## §53/§54/§55). DATA-DRIVEN. ★ Só na PRIMEIRA conclusão EM AVANÇO de um encontro (APEX fase-5 / BOSS fase-10)
## do CICLO — farm repetido NÃO chove suporte (§55). Novo Prestígio ⇒ novo ciclo ⇒ first-clears voltam.
##
## RNG determinístico offline (seed) / RNG normal online. NÃO cria pagamento real (§52).

## ★ FATIA A7.2 (§25/§27, anti-exploit): os suportes COMUNS (Catalisador/Superior) saem de first-clear do CICLO
## (voltam a cada Prestígio, §55 — reforçam o loop). Os RAROS (Preservação/Absoluto) saem SÓ de first-clear
## VITALÍCIO (profundidade NUNCA antes alcançada) — assim o "prestígio rápido → re-farm" NÃO fabrica raros.
const APEX_CYCLE := {
	"catalyst_refine": 0.05,
}
const BOSS_CYCLE := {
	"catalyst_refine": 0.12,
	"catalyst_superior": 0.03,
}
const APEX_LIFETIME := {}                     # apex não dá raros
const BOSS_LIFETIME := {
	"seal_preservation": 0.01,
	"seal_absolute": 0.0010,
}

static func _roll_table(table: Dictionary, seed_val: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var out: Array = []
	for item_id in table:
		if rng.randf() < float(table[item_id]):
			out.append(item_id)
	return out

static func _roll_table_online(table: Dictionary) -> Array:
	var out: Array = []
	for item_id in table:
		if randf() < float(table[item_id]):
			out.append(item_id)
	return out

## Drops de CICLO (Catalisador/Superior). seed<0 = online. is_boss decide a tabela.
static func roll_cycle(is_boss: bool, seed_val: int) -> Array:
	var t: Dictionary = BOSS_CYCLE if is_boss else APEX_CYCLE
	return _roll_table_online(t) if seed_val < 0 else _roll_table(t, seed_val)

## Drops VITALÍCIOS (Preservação/Absoluto). Só em profundidade nova. seed<0 = online.
static func roll_lifetime(is_boss: bool, seed_val: int) -> Array:
	var t: Dictionary = BOSS_LIFETIME if is_boss else APEX_LIFETIME
	return _roll_table_online(t) if seed_val < 0 else _roll_table(t, seed_val)
