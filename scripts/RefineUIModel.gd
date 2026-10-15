class_name RefineUIModel
## FATIA A8 — MODELO (puro) da UX de Refino: escolha de SUPORTE + PREVIEW transparente + RESULTADO p/ feedback.
## NÃO reimplementa a matemática do refino (isso é RefineMath/GameState) — só ORGANIZA a escolha e FORMATA. O
## widget (checkbox/seleção) é FIELD DEFERIDO; este modelo é o que ele consumiria e é 100% testável.
## Regras de combinação (§29): Absoluto é EXCLUSIVO (100% garantido, dispensa catalisador/preservação); Catalisador
## (comum OU superior, um só) combina com Preservação. `preview` é READ-ONLY (não consome — prova de RUI-T06).

const SUP_NONE := "none"
const SUP_CATALYST := "catalyst_refine"
const SUP_SUPERIOR := "catalyst_superior"
const SUP_PRESERVE := "seal_preservation"
const SUP_ABSOLUTE := "seal_absolute"

static func support_label(id: String) -> String:
	match id:
		SUP_CATALYST: return "Catalisador (+5%)"
		SUP_SUPERIOR: return "Catalisador Superior (+15%)"
		SUP_PRESERVE: return "Selo de Preservação"
		SUP_ABSOLUTE: return "Selo Absoluto (100%)"
		_: return "Sem suporte"

## Uma SELEÇÃO válida? {catalyst: ""/id, preserve: bool, absolute: bool}. Absoluto exclui catalisador+preservação.
static func allowed(sel: Dictionary) -> bool:
	var absolute := bool(sel.get("absolute", false))
	var cat := str(sel.get("catalyst", ""))
	var preserve := bool(sel.get("preserve", false))
	if absolute and (cat != "" or preserve):
		return false   # Absoluto já garante 100% — combinar é desperdício/ambíguo
	if cat != "" and cat != SUP_CATALYST and cat != SUP_SUPERIOR:
		return false
	return true

## Pontos percentuais do catalisador escolhido (lê o dado do ItemDB, sem hardcode).
static func catalyst_pp(cat_id: String) -> float:
	if cat_id == "":
		return 0.0
	return float(ItemDB.get_item(cat_id).get("catalyst_pp", 0.0))

## PREVIEW transparente (§28) — READ-ONLY. Usa gs.refine_attempt_info (não consome nada). Retorna o dict do
## FeedbackFormat.refine_transparency + o nível atual/alvo. Prova RUI-T06 (cancelar/pré-visualizar não consome).
static func preview(gs, slot: String, sel: Dictionary) -> Dictionary:
	var cat := str(sel.get("catalyst", ""))
	var absolute := bool(sel.get("absolute", false))
	var info: Dictionary = gs.refine_attempt_info(slot, cat, absolute)
	var lvl := int(gs.slot_refinement.get(slot, 0))
	var t := FeedbackFormat.refine_transparency(
		float(info.get("base_chance", 0.0)),
		float(info.get("pity", 0.0)),
		float(info.get("catalyst_pp", 0.0)),
		int(info.get("cost", 0)),
		bool(info.get("fails_downgrade", false)) and not bool(sel.get("preserve", false)))
	t["level"] = lvl
	t["target"] = lvl + 1
	t["absolute"] = absolute
	if absolute:
		t["final"] = "100%"; t["final_value"] = 1.0; t["downgrade_risk"] = false
	return t

## Executa a tentativa REAL (consome) e devolve o RESULTADO formatável (FeedbackFormat.refine + push_cp).
## `roll01` injeta o sorteio (teste); online usa randf. Snapshota nível/CP antes e depois.
static func attempt(gs, slot: String, sel: Dictionary, roll01: float) -> Dictionary:
	var cat := str(sel.get("catalyst", ""))
	var preserve := bool(sel.get("preserve", false))
	var absolute := bool(sel.get("absolute", false))
	var cp_before := PowerBudget.cp()
	var res: Dictionary = gs.refine_attempt(slot, cat, preserve, absolute, roll01)   # retorno AUTORITATIVO
	var cp_after := PowerBudget.cp()
	return {
		"slot_label": ItemDB.SLOT_LABEL.get(slot, slot),
		"before": int(res.get("from", 0)), "after": int(res.get("to", 0)),
		"success": bool(res.get("success", false)),
		"downgraded": bool(res.get("downgraded", false)),
		"protected": bool(res.get("preserved", false)),
		"absolute": absolute and bool(res.get("success", false)),
		"pity_pp": int(round(float(res.get("pity_after", 0.0)) * 100.0)),
		"cp_delta": cp_after - cp_before,
	}
