class_name ItemInspectionModel extends RefCounted
## FATIA A14.2 — ficha de INSPEÇÃO de item (§43-48). ★ Resolve o débito nº1 de mobile: hoje os stats de item só
## existem em HOVER (§21). Este modelo devolve TUDO que a ficha precisa (nome/raridade/qualidade/stats/rolls/afixos/
## delta-de-comparação/estado-equipado/tradeável/ações) SEM depender de hover (§44/§R9). Uma fonte, reusável por
## Mochila/Baú/Loja/Equip (§43). Puro (dados server-side/estado real). A UI usa dois toques (selecionar → ação §46)
## p/ não equipar/destruir por engano; este modelo só ENTREGA a informação e as ações POSSÍVEIS.

## Monta a ficha de um ItemInstance. `equipped_inst` = a instância atualmente equipada no MESMO slot (p/ delta).
static func build(inst: Dictionary, equipped_inst: Dictionary = {}) -> Dictionary:
	var item_id := ItemInstance.base_item_id(inst)
	var slot := ItemDB.slot_of(item_id)
	var q := ItemInstance.quality(inst)
	var core: Dictionary = {}
	for key in ItemInstance.affected_stats(inst):
		core[key] = int(round(ItemInstance.effective_stat(inst, key, 0)))
	# delta de comparação vs equipado (§44) — nunca por hover
	var delta: Dictionary = {}
	var is_equipped := not equipped_inst.is_empty() and str(equipped_inst.get("iid", "")) == str(inst.get("iid", ""))
	if not equipped_inst.is_empty() and not is_equipped:
		var eq_core: Dictionary = {}
		for key in ItemInstance.affected_stats(equipped_inst):
			eq_core[key] = int(round(ItemInstance.effective_stat(equipped_inst, key, 0)))
		var keys := {}
		for k in core: keys[k] = true
		for k in eq_core: keys[k] = true
		for k in keys:
			delta[k] = int(core.get(k, 0)) - int(eq_core.get(k, 0))
	var tradeable := bool(inst.get("tradeable", false))
	var bound := bool(inst.get("bound", false))
	return {
		"iid": str(inst.get("iid", "")), "item_id": item_id,
		"name": str(ItemDB.get_item(item_id).get("name", item_id)),
		"rarity": ItemDB.rarity(item_id), "slot": slot,
		"quality": q, "quality_label": ItemInstance.quality_label(q),
		"core_stats": core, "rolls": (inst.get("rolls", {}) as Dictionary).duplicate(true),
		"affixes": (inst.get("affixes", []) as Array).duplicate(true),
		"compare_delta": delta, "equipped": is_equipped,
		"tradeable": tradeable, "bound": bound,
		"actions": _actions(is_equipped, tradeable, bound),
	}

## Ações POSSÍVEIS (IDs; a execução é a lógica de jogo existente). Fechar/destrutivo exige confirmação na UI (§46/§60).
static func _actions(is_equipped: bool, tradeable: bool, bound: bool) -> Array:
	var out: Array = []
	if is_equipped:
		out.append("UNEQUIP")
	else:
		out.append("EQUIP")
		out.append("SALVAGE")   # destrutivo → confirmação na UI
	out.append("LOCK")
	if tradeable and not bound and not is_equipped:
		out.append("TRADE")
	return out

## Só realce por hover é PROIBIDO como fonte (§48): esta função confirma que a ficha é auto-suficiente (tem stats).
static func is_self_sufficient(sheet: Dictionary) -> bool:
	return sheet.has("core_stats") and sheet.has("quality") and sheet.has("rarity")
