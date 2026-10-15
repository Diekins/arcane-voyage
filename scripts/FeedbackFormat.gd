class_name FeedbackFormat
## FATIA A8 — FORMATADORES PUROS de texto/estrutura de feedback (sem estado, sem render). Transformam dados dos
## sistemas JÁ APROVADOS (ItemInstance/ItemDB/RefineMath/PrestigeMath) em texto legível para toasts/painéis.
## NÃO altera matemática; só APRESENTA. Consumido por GameFeedback e pelos painéis (render field-deferido).

const EXCEPTIONAL_QUALITY := 95    # quality ≥ isto ou raridade lendária ⇒ "DROP EXCEPCIONAL" (§25)

## Número grande legível: 1234→"1.234", 12345→"12,3k", 1_234_567→"1,23M". PT-BR (vírgula decimal).
static func big(n: int) -> String:
	var a := absi(n)
	var sign := "-" if n < 0 else ""
	if a < 10000:
		return sign + _thousands(a)
	if a < 1000000:
		return "%s%s mil" % [sign, _dec(a / 1000.0)] if a >= 100000 else "%s%sk" % [sign, _dec(a / 1000.0)]
	return "%s%sM" % [sign, _dec(a / 1000000.0)]

static func _dec(v: float) -> String:
	return ("%.1f" % v).replace(".", ",")

static func _thousands(a: int) -> String:
	var s := str(a)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "." + out
	return out

# ═══════════════ LOOT (§22/§23/§24/§25) ═══════════════
## {kind, text, rarity, rarity_label, color, quality, name, exceptional}
static func loot(instance: Dictionary) -> Dictionary:
	var base_id := ItemInstance.base_item_id(instance)
	var rarity := ItemDB.rarity(base_id)
	var q := int(instance.get("quality", 0))
	var nm := ItemDB.display_name(base_id)
	var exc := (rarity == "legendary") or (q >= EXCEPTIONAL_QUALITY)
	var txt := ""
	if exc:
		txt = "DROP EXCEPCIONAL\n%s\nQualidade %d" % [nm, q]
	else:
		txt = "%s · %s · Q%d" % [nm, ItemDB.rarity_label(rarity), q]
	return {
		"kind": (GameFeedback.K_LOOT_EXCEPTIONAL if exc else GameFeedback.K_LOOT),
		"text": txt, "rarity": rarity, "rarity_label": ItemDB.rarity_label(rarity),
		"color": ItemDB.rarity_color(base_id), "quality": q, "name": nm, "exceptional": exc,
	}

## Rótulo de qualidade (§24): "Qualidade 87"; extremos ganham sufixo discreto (sem chamar tudo de GOD ROLL).
static func quality_label(q: int) -> String:
	var s := "Qualidade %d" % q
	if q >= 99: return s + " ✦✦✦"
	if q >= 98: return s + " ✦✦"
	if q >= EXCEPTIONAL_QUALITY: return s + " ✦"
	return s

static func is_exceptional(instance: Dictionary) -> bool:
	var base_id := ItemInstance.base_item_id(instance)
	return ItemDB.rarity(base_id) == "legendary" or int(instance.get("quality", 0)) >= EXCEPTIONAL_QUALITY

## §26 — auto-salvage NÃO pode parecer novo equipamento.
static func salvage_text(instance_or_id, frag: int) -> String:
	var nm := ""
	if instance_or_id is Dictionary:
		nm = ItemDB.display_name(ItemInstance.base_item_id(instance_or_id))
	else:
		nm = ItemDB.display_name(str(instance_or_id))
	return "SALVAGE AUTOMÁTICO\n%s → +%d Frag" % [nm, frag]

# ═══════════════ TRANSIÇÕES (§15/§18) ═══════════════
static func stage_clear(chapter: int, stage: int, next_type: String) -> String:
	var nxt_stage := stage + 1
	var nxt_ch := chapter
	if stage >= 10:
		nxt_ch = chapter + 1; nxt_stage = 1
	var tag := ""
	match next_type:
		"boss": tag = "\nBOSS"
		"miniboss": tag = "\nAPEX"
		_: tag = ""
	return "FASE %d-%d CONCLUÍDA\n→ %d-%d%s" % [chapter, stage, nxt_ch, nxt_stage, tag]

static func chapter_clear(chapter: int, display: String) -> String:
	return "CAPÍTULO %d CONCLUÍDO\n%s" % [chapter, display]

## Cabeçalho de capítulo (§18): "Cap. 6 · Areias de Khet · Tier 4".
static func chapter_header(chapter: int, display: String, gear_tier: int) -> String:
	return "Cap. %d · %s · Tier %d" % [chapter, display, gear_tier]

## Rótulo da barra de fase (§19): "Cap. 6 · 6-5 · APEX".
static func stage_hud(chapter: int, stage: int, stage_type: String) -> String:
	var t := ""
	match stage_type:
		"boss": t = " · BOSS"
		"miniboss": t = " · APEX"
		_: t = ""
	return "Cap. %d · %d-%d%s" % [chapter, chapter, stage, t]

# ═══════════════ CP / PODER (§20) ═══════════════
static func cp_gain(delta: int) -> String:
	return "+%s PODER" % big(delta)

# ═══════════════ REFINO (§27) ═══════════════
## `result` = {slot_label, before, after, success, protected, absolute, downgraded, pity_pp, cp_delta}
static func refine(result: Dictionary) -> String:
	var slot := str(result.get("slot_label", "Item"))
	var before := int(result.get("before", 0))
	var after := int(result.get("after", 0))
	var cp := int(result.get("cp_delta", 0))
	if bool(result.get("absolute", false)):
		return "%s +%d → +%d\nGARANTIDO  %s" % [slot, before, after, cp_gain(cp)]
	if bool(result.get("success", false)):
		return "%s +%d → +%d\n%s" % [slot, before, after, cp_gain(cp)]
	# falha
	if bool(result.get("protected", false)):
		return "%s FALHOU\nSelo preservou +%d\nPity +%d%%" % [slot, before, int(result.get("pity_pp", 0))]
	if bool(result.get("downgraded", false)):
		return "%s FALHOU\n+%d → +%d\nPity +%d%%" % [slot, before, after, int(result.get("pity_pp", 0))]
	return "%s FALHOU\n+%d mantido\nPity +%d%%" % [slot, before, int(result.get("pity_pp", 0))]

## Transparência do refino (§28): sempre mostra base/pity/catalyst/final/custo/risco.
static func refine_transparency(base_chance: float, pity_pp: float, catalyst_pp: float, cost: int, downgrade_risk: bool) -> Dictionary:
	var final_c := clampf(base_chance + pity_pp + catalyst_pp, 0.0, 1.0)
	return {
		"base": "%d%%" % int(round(base_chance * 100.0)),
		"pity": "+%d%%" % int(round(pity_pp * 100.0)),
		"catalyst": "+%d%%" % int(round(catalyst_pp * 100.0)),
		"final": "%d%%" % int(round(final_c * 100.0)),
		"final_value": final_c,
		"cost": "%s Frag" % big(cost),
		"downgrade_risk": downgrade_risk,
	}

# ═══════════════ PRESTÍGIO (§32/§33) ═══════════════
static func prestige(prestige_n: int, master_n: int, cp_before: int, cp_after: int) -> String:
	return "PRESTÍGIO %s · MESTRE %s\nPODER: %s → %s\nJORNADA REINICIADA" % [
		_roman(prestige_n), _roman(master_n), big(cp_before), big(cp_after)]

# ═══════════════ MURO (§34) ═══════════════
static func wall(cp_now: int, cp_need: int) -> String:
	return "PODER INSUFICIENTE\n%s / %s" % [big(cp_now), big(cp_need)]

# ═══════════════ OFFLINE (§30) ═══════════════
## `summary` = {seconds, stages, gold, xp, items, materials, exceptional_name}
static func offline(summary: Dictionary) -> String:
	# A37 §4 — CARD COMPACTO de retorno: 1 linha essencial (+ 1 só se drop excepcional). Sem parede de texto.
	var t := IdleRewards.fmt_duration(int(summary.get("seconds", 0)))
	var items := int(summary.get("items", 0)); var mats := int(summary.get("materials", 0))
	var extra := ""
	if items > 0 or mats > 0: extra = " · %d itens · %d mat" % [items, mats]
	var lines := ["◆ Ausente %s  ·  +%s ouro  ·  +%s XP%s" % [t, big(int(summary.get("gold", 0))), big(int(summary.get("xp", 0))), extra]]
	var exc := str(summary.get("exceptional_name", ""))
	if exc != "":
		lines.append("✦ DROP EXCEPCIONAL: %s" % exc)
	return "\n".join(lines)

# ═══════════════ COMPARAÇÃO DE EQUIPAMENTO (§39) ═══════════════
## Linhas de stat ATUAL vs NOVO (sem iid). CP projetado vem do PowerAdvisor (não formatado aqui). `equipped`/`novo`
## são ItemInstance OU item_id (base). Retorna [{stat, cur, new, delta}] p/ os stats relevantes.
static func compare_rows(equipped, novo) -> Array:
	var keys := [["attack", "Ataque"], ["defense", "Defesa"], ["max_hp", "HP"], ["speed", "Vel"], ["magic", "Mag"]]
	var out: Array = []
	for k in keys:
		var cur := _stat_of(equipped, str(k[0]))
		var nw := _stat_of(novo, str(k[0]))
		if cur == 0 and nw == 0:
			continue
		out.append({"stat": str(k[1]), "cur": cur, "new": nw, "delta": nw - cur})
	return out

# ═══════════════ CARD DE ITEM (§38) — nunca expõe iid ═══════════════
## {name, rarity, rarity_label, color, quality, quality_label, affixes[], equipped, locked, exceptional}
static func item_card(instance: Dictionary, equipped: bool = false, locked: bool = false) -> Dictionary:
	var base_id := ItemInstance.base_item_id(instance)
	var rarity := ItemDB.rarity(base_id)
	var q := int(instance.get("quality", 0))
	var affixes: Array = instance.get("affixes", [])
	return {
		"name": ItemDB.display_name(base_id),
		"rarity": rarity, "rarity_label": ItemDB.rarity_label(rarity),
		"color": ItemDB.rarity_color(base_id),
		"quality": q, "quality_label": quality_label(q),
		"affixes": affixes,
		"equipped": equipped, "locked": locked,
		"exceptional": (rarity == "legendary") or (q >= EXCEPTIONAL_QUALITY),
	}

static func _stat_of(item, key: String) -> int:
	if item is Dictionary:
		return int(round(ItemInstance.effective_stat(item, key, 0)))
	elif item is String and item != "":
		return ItemDB.stat(item, key)
	return 0

# ═══════════════ helpers ═══════════════
static func _roman(n: int) -> String:
	if n <= 0: return "0"
	var vals := [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
	var syms := ["M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"]
	var out := ""
	var x := n
	for i in range(vals.size()):
		while x >= vals[i]:
			out += syms[i]; x -= vals[i]
	return out
