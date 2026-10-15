class_name CharacterAppearance extends RefCounted
## FATIA A13 — APARÊNCIA do personagem (§12-19). ★ APPEARANCE = 0 COMBAT POWER (§13): tom de pele, apresentação
## corporal, cabelo, cor, roupa NUNCA alteram stats. Diversidade GRATUITA (§14): todas as opções básicas são livres
## (nenhuma é premium). Opções ALLOWLISTED (IDs conhecidos §78) — o cliente não injeta path de arquivo. cosmetic_skin
## é SEPARADO da aparência base (§19) e nunca altera classe/stats. Precomposed V1 (§15): resolve para actor_key, sem
## layered runtime sprite. NÃO usa `modulate` (§18 — ocupado por feedback de combate).

# opções BÁSICAS gratuitas (allowlists). Sprites reais são gerados offline (§17) — aqui só os IDs.
const BODY := ["BODY_F", "BODY_M", "BODY_NB"]                        # feminino/masculino/neutro
const SKIN := ["SKIN_1", "SKIN_2", "SKIN_3", "SKIN_4", "SKIN_5", "SKIN_6"]
const HAIR := ["HAIR_0", "HAIR_1", "HAIR_2", "HAIR_3", "HAIR_4", "HAIR_5"]
const HAIR_COLOR := ["HC_BLACK", "HC_BROWN", "HC_BLONDE", "HC_RED", "HC_WHITE", "HC_BLUE"]
const OUTFIT := ["OUTFIT_1", "OUTFIT_2", "OUTFIT_3", "OUTFIT_4"]
const BASE_ACTOR_FAMILY := ["ERRANTE", "SCOUT", "MAGE", "LANCER"]     # famílias visuais precompostas

const DEFAULT_LEGACY := {
	"body_presentation_id": "BODY_M", "skin_tone_id": "SKIN_3", "hair_style_id": "HAIR_1",
	"hair_color_id": "HC_BROWN", "outfit_palette_id": "OUTFIT_1", "base_actor_family": "ERRANTE",
	"cosmetic_skin_id": "",
}

static func new_appearance(body: String, skin: String, hair: String, hair_color: String, outfit: String, actor_family: String, cosmetic_skin: String = "") -> Dictionary:
	return {
		"body_presentation_id": body, "skin_tone_id": skin, "hair_style_id": hair,
		"hair_color_id": hair_color, "outfit_palette_id": outfit, "base_actor_family": actor_family,
		"cosmetic_skin_id": cosmetic_skin,
	}

## Valida uma aparência: cada campo tem de ser um ID allowlisted (§78). cosmetic_skin_id "" = sem skin (ok).
## Retorna {ok} ou {ok:false, reason, field}.
static func validate(appearance: Dictionary) -> Dictionary:
	var checks := {
		"body_presentation_id": BODY, "skin_tone_id": SKIN, "hair_style_id": HAIR,
		"hair_color_id": HAIR_COLOR, "outfit_palette_id": OUTFIT, "base_actor_family": BASE_ACTOR_FAMILY,
	}
	for field in checks:
		var v := str(appearance.get(field, ""))
		if not (checks[field] as Array).has(v):
			return {"ok": false, "reason": "BAD_APPEARANCE_OPTION", "field": field}
	return {"ok": true}

## Sanitiza (do save/cliente): campos inválidos caem para o DEFAULT_LEGACY (nunca crasha, nunca injeta path §79).
static func sanitize(raw) -> Dictionary:
	var a := DEFAULT_LEGACY.duplicate(true)
	if raw is Dictionary:
		var val := validate(raw)
		if bool(val["ok"]):
			for k in a:
				if k != "cosmetic_skin_id" and raw.has(k):
					a[k] = str(raw[k])
		# cosmetic_skin_id é validado à parte (ownership §92), aqui só copia string
		if raw.has("cosmetic_skin_id"):
			a["cosmetic_skin_id"] = str(raw["cosmetic_skin_id"])
	return a

## Todas as opções básicas são gratuitas (§14/§52) — nunca premium.
static func option_is_free(_field: String, _value: String) -> bool:
	return true

## Poder de combate da aparência = SEMPRE 0 (§13/§59).
static func combat_power(_appearance: Dictionary) -> int:
	return 0
