class_name ArenaRewardPolicy extends RefCounted
## FATIA A12 — POLÍTICA de recompensas (§37-40). Só CONTRATO/entitlement nesta foundation — NÃO entrega cosmético
## real nem adiciona moeda ao save (§38). Tiers por participação/rank/posição final (§39). NÃO premia farm de
## derrota (§40): participação exige partidas VÁLIDAS (settled com resultado real; NO_CONTEST/SERVER_ABORT não
## contam §84). Nenhuma recompensa dá combat buff de Ranked (§113-AREW-T05). Puro/determinístico.

const REWARD_SEASON_BADGE := "SEASON_BADGE"
const REWARD_TITLE := "TITLE"
const REWARD_FRAME := "FRAME"
const REWARD_AURA := "AURA"
const REWARD_ARENA_COSMETIC := "ARENA_COSMETIC"
const REWARD_VICTORY_EFFECT := "VICTORY_EFFECT"
const REWARD_ARENA_CURRENCY := "ARENA_CURRENCY_FUTURE"   # catálogo futuro; NÃO cria moeda no save (§38)
const REWARD_LIMITED_MATERIAL := "LIMITED_MATERIAL_FUTURE"

const MIN_VALID_MATCHES := 5   # participação legítima mínima (§39/§40) — só matches válidos contam

## Entitlements de fim de season, dado o resultado congelado. Retorna Array de {type, id, tier}. Sem arte (§88).
## `valid_matches` = partidas settled com resultado real (exclui NO_CONTEST/SERVER_ABORT).
static func season_entitlements(final_rank: String, final_position: int, valid_matches: int, peak_rank: String) -> Array:
	var out: Array = []
	if valid_matches < MIN_VALID_MATCHES:
		return out   # §40 — sem participação legítima, sem recompensa (não premia farm de derrota)
	# participação válida
	out.append({"type": REWARD_SEASON_BADGE, "id": "PARTICIPANT", "tier": "PARTICIPATION"})
	# por rank alcançado (usa o MAIOR entre final e peak)
	var rank_for_reward := ArenaRank.higher(final_rank, peak_rank)
	out.append({"type": REWARD_TITLE, "id": "RANK_" + rank_for_reward, "tier": "RANK"})
	# por posição final
	if final_position == 1:
		out.append({"type": REWARD_SEASON_BADGE, "id": "SEASON_CHAMPION", "tier": "CHAMPION"})
		out.append({"type": REWARD_AURA, "id": "CHAMPION_AURA", "tier": "CHAMPION"})
	elif final_position >= 2 and final_position <= 10:
		out.append({"type": REWARD_SEASON_BADGE, "id": "TOP_10", "tier": "TOP_10"})
	elif final_position >= 11 and final_position <= 100:
		out.append({"type": REWARD_SEASON_BADGE, "id": "TOP_100", "tier": "TOP_100"})
	return out

## Match individual gera recompensa competitiva? Não em NO_CONTEST/SERVER_ABORT (§84).
static func match_grants_reward(reason: String) -> bool:
	return reason != "NO_CONTEST" and reason != "SERVER_ABORT"

## Invariante: nenhuma recompensa é buff de combate Ranked (§AREW-T05).
static func grants_combat_buff(_reward_type: String) -> bool:
	return false
