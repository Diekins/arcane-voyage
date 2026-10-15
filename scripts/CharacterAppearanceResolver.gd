class_name CharacterAppearanceResolver extends RefCounted
## FATIA A13 — resolve uma CharacterAppearance → actor_key de sprite PRECOMPOSTO (§15). ★ NÃO faz layered runtime
## sprite (Visual Bible §15). ★ SEGURANÇA (§78/§79): o cliente escolhe IDs allowlisted; NUNCA um path de arquivo.
## O actor_key resultante é conhecido (derivado de IDs), nunca "../../hack". Combinação sem sprite gerado → fallback
## DEFAULT_VISUAL + marca ASSET_REQUIRED (§16). NÃO gera asset (pipeline offline externo §17).

const DEFAULT_VISUAL := "actor_errante_default"

## actor_keys de sprites que EXISTEM (registro; o pipeline offline preencheria isto). Foundation: só os legados.
const AVAILABLE_ACTOR_KEYS := ["actor_errante_default"]

## Deriva um actor_key determinístico a partir da aparência (IDs → chave conhecida, sem path). cosmetic_skin tem
## precedência de APRESENTAÇÃO (§19) mas nunca muda classe/stats.
static func _compose_key(appearance: Dictionary) -> String:
	var cos := str(appearance.get("cosmetic_skin_id", ""))
	if cos != "":
		return "actor_skin_" + _safe(cos)
	return "actor_%s_%s_%s_%s" % [
		_safe(str(appearance.get("base_actor_family", "ERRANTE"))).to_lower(),
		_safe(str(appearance.get("body_presentation_id", "BODY_M"))).to_lower(),
		_safe(str(appearance.get("hair_style_id", "HAIR_1"))).to_lower(),
		_safe(str(appearance.get("outfit_palette_id", "OUTFIT_1"))).to_lower(),
	]

## Só letras/números/_ — impede qualquer injeção de path (§78). Nunca "/","\\","..".
static func _safe(s: String) -> String:
	var out := ""
	for i in range(s.length()):
		var c := s[i]
		if (c >= "A" and c <= "Z") or (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "_":
			out += c
	return out

## Resolve → {actor_key, available, fallback}. Aparência inválida ou asset ausente → DEFAULT_VISUAL + ASSET_REQUIRED.
static func resolve(appearance: Dictionary) -> Dictionary:
	var val := CharacterAppearance.validate(appearance)
	if not bool(val["ok"]):
		return {"actor_key": DEFAULT_VISUAL, "available": true, "fallback": true, "reason": "INVALID_APPEARANCE"}
	var key := _compose_key(appearance)
	if AVAILABLE_ACTOR_KEYS.has(key):
		return {"actor_key": key, "available": true, "fallback": false}
	# combinação válida mas sprite ainda não gerado (§16) — fallback previsível, marca ASSET_REQUIRED
	return {"actor_key": DEFAULT_VISUAL, "available": false, "fallback": true, "reason": "ASSET_REQUIRED", "requested_key": key}

## O actor_key resolvido é sempre seguro (allowlisted/derivado; nunca path arbitrário).
static func is_safe_key(key: String) -> bool:
	return key == _safe(key) and not key.contains("..") and not key.contains("/") and not key.contains("\\")
