class_name ItemRoller
## ItemRoller — gera ItemInstances a partir de um ItemDefinition (FATIA A7.1, PARTE B). DETERMINÍSTICO por seed
## (§20/§33): mesma (definition, seed) → mesma instância estatística. Usa RandomNumberGenerator LOCAL (NUNCA o
## RNG global) → não interfere no combate nem entre chamadas.
##
## ★ DISTRIBUIÇÃO ENVIESADA AO CENTRO (§19): core roll = 0.85 + 0.30×t, com t triangular (média de 2 uniformes)
## ⇒ média ~0.5 (qualidade ~50), extremos GENUINAMENTE raros (95+ ~raro, 99+ ~excepcional). Sem uniforme puro.
##
## ★ QUALIDADE EMERGE DOS ROLLS (§13/§18): quality = média normalizada de todos os t (core + afixos) × 100. God
## roll real ⇒ quality alta; sem flag artificial `god_roll=true`.

## Quantidade de afixos por raridade (§16, data-driven). {min,max} inclusivos.
const AFFIX_COUNT := {
	"common": [0, 1],
	"uncommon": [1, 2],
	"rare": [2, 3],
	"epic": [3, 4],        # FATIA A7.3 — tiers 4/5
	"legendary": [3, 5],
}

## Pool de stats de afixo por SLOT (§17) — respeita o arquétipo (arma = ofensivo; armadura = defensivo/vida).
const AFFIX_POOL_BY_SLOT := {
	"weapon": ["attack", "magic"],
	"offhand": ["defense", "max_hp"],
	"head": ["max_hp", "defense"],
	"chest": ["max_hp", "defense"],
	"legs": ["max_hp", "defense"],
	"boots": ["defense", "speed", "max_hp"],
	"accessory": ["max_hp", "attack", "defense"],
	"bracelet": ["attack", "max_hp", "defense"],
	"ring": ["max_hp", "attack", "defense"],
}

## Distribuição triangular em [0,1] (média de 2 uniformes) → viés ao centro.
static func _tri(rng: RandomNumberGenerator) -> float:
	return (rng.randf() + rng.randf()) * 0.5

static func _affix_pool_for(item_id: String) -> Array:
	var slot := ItemDB.slot_of(item_id)
	var pool: Array = (AFFIX_POOL_BY_SLOT.get(slot, ["max_hp"]) as Array).duplicate()
	# arma mágica (cajado/livro): garante magic no pool; arma física: attack
	return pool

## id de instância DETERMINÍSTICO (§5) — deriva do seed (que já embute drop_index no offline), sem timestamp.
static func make_iid(item_id: String, seed_val: int) -> String:
	return "%s#%08x" % [item_id, hash("iid|%d|%s" % [seed_val, item_id]) & 0x7fffffff]

## Gera uma ItemInstance DETERMINÍSTICA. `origin` p/ auditoria; tradeable default por raridade/flags.
static func roll(item_id: String, seed_val: int, origin: String = "loot", created_at: int = 0) -> Dictionary:
	if not ItemDB.exists(item_id) or ItemDB.slot_of(item_id) == "":
		return {}   # só EQUIPÁVEIS viram instância (§2/§7); stackáveis/materiais ficam de fora
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var rarity := ItemDB.rarity(item_id)
	var q_sum := 0.0
	var q_n := 0
	# ── CORE ROLLS: um por stat-base positivo refinável ──
	var rolls: Dictionary = {}
	for key in ItemInstance.CORE_REFINABLE:
		if int(ItemDB.stat(item_id, key)) > 0:
			var t := _tri(rng)
			rolls[key] = ItemInstance.CORE_ROLL_MIN + (ItemInstance.CORE_ROLL_MAX - ItemInstance.CORE_ROLL_MIN) * t
			q_sum += t; q_n += 1
	# ── AFIXOS: quantidade por raridade; stat do pool do slot; valor FLAT modesto (efeito REAL, §14/§15) ──
	var affixes: Array = []
	var rng_ct: Array = AFFIX_COUNT.get(rarity, [0, 1])
	var lo := int(rng_ct[0]); var hi := int(rng_ct[1])
	var n_aff := lo + (rng.randi() % (hi - lo + 1)) if hi >= lo else 0
	var pool := _affix_pool_for(item_id)
	for i in range(n_aff):
		if pool.is_empty():
			break
		var stat := str(pool[rng.randi() % pool.size()])
		var t2 := _tri(rng)
		# flat modesto: referência = maior stat-base do item (ou 8 se acessório sem stat), 5%..20% dele.
		var ref_base := _reference_base(item_id)
		var val := maxi(1, int(round(float(ref_base) * (0.05 + 0.15 * t2))))
		affixes.append({"stat": stat, "kind": "flat", "value": val})
	# ★ QUALIDADE = média dos CORE rolls (§13/§19). NÃO inclui afixos: incluir vários t na média estreita a cauda
	# e faz god roll NUNCA cair. Com 1 core (triangular) ⇒ 95+ ~0.5% (raro), 98+ ~0.08%, 99+ ~0.02% (excepcional).
	var quality := int(round((q_sum / float(maxi(1, q_n))) * 100.0))
	var iid := make_iid(item_id, seed_val)
	# tradeable: equipamento normal comercializável; unique/quest (sem preço) = bound (§35). Catálogo atual: por preço.
	var tradeable := ItemDB.price(item_id) > 0
	return ItemInstance.make(iid, item_id, quality, rolls, affixes, origin, created_at, tradeable, not tradeable)

## Referência p/ dimensionar afixo flat = maior stat-base do item (mín 6 p/ acessório magro).
static func _reference_base(item_id: String) -> int:
	var m := 0
	for k in ItemInstance.CORE_REFINABLE:
		m = maxi(m, int(ItemDB.stat(item_id, k)))
	return maxi(6, m)
