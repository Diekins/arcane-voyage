class_name BestiaryManager extends Node
## BestiaryManager — CÓDICE DE ALMA / BESTIÁRIO (FATIA A7, PARTE V). Conta ABATES por mob (LIFETIME) e concede
## TIERS reivindicáveis que dão bônus REAL pequeno e cumulativo (dano+HP), nunca CP artificial (§39).
##
## ★ DADOS no GameState (`bestiary` = {mob_id:{kills,claimed}}); a MATEMÁTICA de tier/claim vive aqui. Kills
## contam SEMPRE (advance/farm/online/offline — §35); offline usa BATCH (§41, sem loop por kill). LIFETIME:
## Prestígio NÃO reseta (§40). O bônus é aplicado 1× via PlayerPowerModifiers (Master×Coleção) ⇒ CP sobe sozinho.
##
## Com ~60 mobs × 5 tiers e +0.10%/tier ⇒ teto teórico ~+30%/+30% (não milhares por cento, §37).

## Marcos de abates por tier (data-driven, §36). Índice 0 = "Tier I".
const TIERS := [10, 50, 200, 750, 2500]
const TIER_NAMES := ["Tier I", "Tier II", "Tier III", "Tier IV", "Tier V"]

var _host = null

func setup(host = null) -> void:
	_host = host

func _gs():
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("GameState")
	return null

# ── kills (ONLINE 1×; OFFLINE batch) ──
func notify_kill(mob_id: String) -> void:
	var gs = _gs()
	if gs != null:
		gs.bestiary_add_kill(mob_id)

func notify_kills_batch(kills_by_mob: Dictionary) -> void:
	var gs = _gs()
	if gs != null:
		gs.bestiary_add_kills_batch(kills_by_mob)

# ── tiers ──
## Nº de tiers ATINGIDOS por uma contagem de kills (0..5). Marco atingido ⟺ kills ≥ threshold.
static func reached_tier(kills: int) -> int:
	var n := 0
	for t in TIERS:
		if kills >= t:
			n += 1
	return n

## Kills faltando p/ o PRÓXIMO tier de um mob (0 = já no teto). Usado no ▸IR ("faltam N abates").
func kills_to_next(mob_id: String) -> int:
	var gs = _gs()
	if gs == null:
		return 0
	var e: Dictionary = gs.bestiary_entry(mob_id)
	var kills := int(e["kills"])
	for t in TIERS:
		if kills < t:
			return t - kills
	return 0

## Tiers reivindicáveis de UM mob (atingidos − já reivindicados).
func claimable_for(mob_id: String) -> int:
	var gs = _gs()
	if gs == null:
		return 0
	var e: Dictionary = gs.bestiary_entry(mob_id)
	return maxi(0, reached_tier(int(e["kills"])) - int(e["claimed"]))

## Total de tiers reivindicáveis somando todos os mobs (badge/▸IR).
func claimable_total() -> int:
	var gs = _gs()
	if gs == null:
		return 0
	var total := 0
	for mid in gs.bestiary:
		total += claimable_for(str(mid))
	return total

func has_available_action() -> bool:
	return claimable_total() > 0

## O mob com MAIS tiers reivindicáveis (p/ o ▸IR apontar 1 alvo). "" se nenhum.
func best_claimable_mob() -> String:
	var gs = _gs()
	if gs == null:
		return ""
	var best := ""
	var best_n := 0
	for mid in gs.bestiary:
		var c := claimable_for(str(mid))
		if c > best_n:
			best_n = c; best = str(mid)
	return best

# ── claim ──
## Reivindica TODOS os tiers atingidos de um mob (claimed ← atingidos). Idempotente (reclaim = 0, §BEST-T06).
## Retorna quantos tiers foram creditados. Aplica o bônus via recompute do total (PlayerPowerModifiers lê daí).
func claim_mob(mob_id: String) -> int:
	var gs = _gs()
	if gs == null:
		return 0
	var e: Dictionary = gs.bestiary_entry(mob_id)
	var reached := reached_tier(int(e["kills"]))
	var gained := reached - int(e["claimed"])
	if gained <= 0:
		return 0
	gs.bestiary_set_claimed(mob_id, reached)
	return gained

## Reivindica TODOS os mobs de uma vez (ação do painel/▸IR). Retorna o total de tiers creditados.
func claim_all() -> int:
	var gs = _gs()
	if gs == null:
		return 0
	var total := 0
	for mid in gs.bestiary.keys():
		total += claim_mob(str(mid))
	return total

# ── projeção de CP (PURA; não muta save) — bump temporário do contador de memória + PowerBudget.cp() ──
func projected_cp_gain() -> int:
	var gs = _gs()
	if gs == null:
		return 0
	var pend := claimable_total()
	if pend <= 0:
		return 0
	var cp_now: int = PowerBudget.cp()
	var saved: int = gs._bestiary_claimed_total
	gs._bestiary_claimed_total = saved + pend
	var cp_proj: int = PowerBudget.cp()
	gs._bestiary_claimed_total = saved   # restaura (nada persistido)
	return cp_proj - cp_now

# ── resumo p/ painel ──
func status_text() -> String:
	var gs = _gs()
	if gs == null:
		return ""
	var mobs: int = gs.bestiary.size()
	var claimed_total: int = gs.bestiary_claimed_tiers_total()
	return "Mobs registrados: %d · Tiers reivindicados: %d · A coletar: %d" % [mobs, claimed_total, claimable_total()]
