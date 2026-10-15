class_name ItemInstance
## ItemInstance — uma CÓPIA CONCRETA de um ItemDefinition (ItemDB), com rolls/qualidade/afixos PRÓPRIOS
## (FATIA A7.1). Duas cópias da mesma Espada podem valer muito diferente.
##
## ★ SEPARAÇÃO (PARTE A): ItemDB = MODELO (nome/sprite/slot/raridade-base/stats-base/preço). ItemInstance =
## o que VARIA naquela cópia. A instância NÃO duplica nome/sprite (§8) — só referencia `item_id`.
##
## ★ ARMAZENADA COMO DICIONÁRIO (serializa direto no save). Este arquivo é o HELPER puro (sem estado): cria,
## valida, calcula stat efetivo, serializa payload de troca, market score. Sem Node, sem GameState, sem RNG.
##
## PIPELINE (§21/§22): ItemInstance → rolls → Refino do SLOT (só CORE refinável) → Joias/global → stats reais.

## Stats reais do Godot que podem ser rolados/afixados. CORE_REFINABLE = escalam com o Refino do slot (§23).
const CORE_REFINABLE := ["attack", "magic", "defense", "max_hp", "speed"]

## Faixa dos core rolls (§12): 0.85..1.15 sobre o stat-base do item.
const CORE_ROLL_MIN := 0.85
const CORE_ROLL_MAX := 1.15

## Rótulos APRESENTACIONAIS de qualidade (§18) — o PODER vem dos stats, não do rótulo.
static func quality_label(quality: int) -> String:
	if quality >= 99: return "Perfeito"
	if quality >= 97: return "Excepcional"
	if quality >= 90: return "Excelente"
	if quality >= 75: return "Bom"
	return "Comum"

## Cria uma instância normalizada (dicionário). `rolls` = {stat: mult 0.85..1.15}; `affixes` = [{stat,kind,value}].
static func make(iid: String, item_id: String, quality: int, rolls: Dictionary, affixes: Array, origin: String, created_at: int, tradeable: bool, bound: bool) -> Dictionary:
	return {
		"iid": iid,
		"item_id": item_id,
		"quality": clampi(quality, 0, 100),
		"rolls": rolls,
		"affixes": affixes,
		"origin": origin,
		"created_at": created_at,
		"tradeable": tradeable,
		"bound": bound,
	}

## FATIA A7.2 — instância LEGADO NEUTRA (§7/§30/§66): rolls 1.0 (stats EXATAMENTE os do item-base, 0 nerf/0 god
## roll grátis), afixos vazios, quality neutra (50 = média), origin "legacy". `iid` ESTÁVEL (determinístico) →
## materializar de novo devolve a MESMA identidade (§32). tradeable por preço.
static func make_legacy(item_id: String, iid: String) -> Dictionary:
	var rolls: Dictionary = {}
	for k in CORE_REFINABLE:
		if int(ItemDB.stat(item_id, k)) > 0:
			rolls[k] = 1.0
	var tradeable := ItemDB.price(item_id) > 0
	return make(iid, item_id, 50, rolls, [], "legacy", 0, tradeable, not tradeable)

static func base_item_id(inst: Dictionary) -> String:
	return str(inst.get("item_id", ""))

static func quality(inst: Dictionary) -> int:
	return int(inst.get("quality", 0))

static func is_tradeable(inst: Dictionary) -> bool:
	return bool(inst.get("tradeable", false)) and not bool(inst.get("bound", false))

## Contribuição EFETIVA da instância p/ um stat, dado o nível de Refino do SLOT (§22/§23):
##   core_refinado = base × roll[stat] × RefineMult(level)   (só CORE refinável)
##   + afixos no stat: flat (não-refinado) + pct × base (não-refinado)  (§23 afixo especial non-refinable)
## Retorna FLOAT (o chamador soma e arredonda uma vez — precisão preservada).
static func effective_stat(inst: Dictionary, key: String, refine_level: int) -> float:
	var item_id := base_item_id(inst)
	var base := float(ItemDB.stat(item_id, key))
	var total := 0.0
	if base != 0.0 and CORE_REFINABLE.has(key):
		var roll := float((inst.get("rolls", {}) as Dictionary).get(key, 1.0))
		total += base * roll * RefineMath.mult(refine_level)   # CORE: rolado E refinado
	elif base != 0.0:
		total += base   # stat-base não-refinável (não deveria ocorrer nos CORE; segurança)
	# afixos (NÃO refinados, §23) — flat somado; pct sobre a base
	for a in inst.get("affixes", []):
		if a is Dictionary and str(a.get("stat", "")) == key:
			if str(a.get("kind", "flat")) == "pct":
				total += base * float(a.get("value", 0.0))
			else:
				total += float(a.get("value", 0))
	return total

## Todos os stats que a instância afeta (core do item + stats dos afixos) — p/ somar no equip_sum.
static func affected_stats(inst: Dictionary) -> Array:
	var out: Array = []
	var item_id := base_item_id(inst)
	for k in CORE_REFINABLE:
		if int(ItemDB.stat(item_id, k)) != 0 and not out.has(k):
			out.append(k)
	for a in inst.get("affixes", []):
		if a is Dictionary:
			var s := str(a.get("stat", ""))
			if s != "" and not out.has(s):
				out.append(s)
	return out

## Sanitiza uma instância vinda do save (descarta lixo; nunca quebra). item_id inválido → null.
static func sanitize(raw) -> Dictionary:
	if not (raw is Dictionary):
		return {}
	var item_id := str(raw.get("item_id", ""))
	if not ItemDB.exists(item_id):
		return {}
	var rolls: Dictionary = {}
	var rr: Variant = raw.get("rolls", {})
	if rr is Dictionary:
		for k in rr:
			if CORE_REFINABLE.has(str(k)):
				rolls[str(k)] = clampf(float(rr[k]), 0.1, 5.0)
	var affixes: Array = []
	for a in raw.get("affixes", []):
		if a is Dictionary and str(a.get("stat", "")) != "":
			affixes.append({"stat": str(a.get("stat", "")), "kind": ("pct" if str(a.get("kind", "flat")) == "pct" else "flat"), "value": float(a.get("value", 0))})
	return make(
		str(raw.get("iid", "")), item_id, int(raw.get("quality", 0)), rolls, affixes,
		str(raw.get("origin", "unknown")), int(raw.get("created_at", 0)),
		bool(raw.get("tradeable", true)), bool(raw.get("bound", false)))

# ══════════════════════════════════════════════════════════════════════════════════════════════════
# TRADE PAYLOAD (§37) — o que VIAJA num futuro comércio: SÓ o item intrínseco. NUNCA refino do slot / Master /
# Bestiário / Códice / estado do personagem (§36/§37). Puro; não implementa mercado (§ NÃO IMPLEMENTAR).
# ══════════════════════════════════════════════════════════════════════════════════════════════════
static func trade_payload(inst: Dictionary) -> Dictionary:
	return {
		"iid": str(inst.get("iid", "")),
		"item_id": base_item_id(inst),
		"quality": quality(inst),
		"rolls": (inst.get("rolls", {}) as Dictionary).duplicate(true),
		"affixes": (inst.get("affixes", []) as Array).duplicate(true),
		"origin": str(inst.get("origin", "")),
		"tradeable": is_tradeable(inst),
	}

## Chaves PROIBIDAS num trade payload (usado pelo validator/teste VALUE-T04). O refino é do SLOT, não viaja.
const FORBIDDEN_TRADE_KEYS := ["slot_refinement", "refine_pity_by_slot", "master_level", "bestiary", "codex_claimed", "codex_discovered", "hero_level", "hero_gold"]

## Valida que um payload NÃO carrega estado do personagem/slot. true = seguro.
static func trade_payload_clean(payload: Dictionary) -> bool:
	for k in FORBIDDEN_TRADE_KEYS:
		if payload.has(k):
			return false
	return payload.has("item_id") and payload.has("rolls") and payload.has("quality")

# ══════════════════════════════════════════════════════════════════════════════════════════════════
# MARKET SCORE (§38) — valor técnico aproximado p/ SORT/UI/testes. NÃO é preço em ouro. Combina raridade +
# qualidade + magnitude dos stats do item. God roll vale mais no MERCADO que no triturador (§31).
# ══════════════════════════════════════════════════════════════════════════════════════════════════
const RARITY_WEIGHT := {"common": 1.0, "uncommon": 1.8, "rare": 3.2, "epic": 5.5, "legendary": 9.0}
static func market_score(inst: Dictionary) -> int:
	var item_id := base_item_id(inst)
	var rw: float = RARITY_WEIGHT.get(ItemDB.rarity(item_id), 1.0)
	var base_val := float(maxi(1, ItemDB.price(item_id)))
	var q := float(quality(inst)) / 100.0
	# qualidade pesa de forma acelerada nos extremos (god roll destaca)
	return int(round(base_val * rw * (0.5 + 1.5 * q * q)))
