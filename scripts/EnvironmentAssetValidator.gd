class_name EnvironmentAssetValidator extends RefCounted
## A28.37 — validador DEV/TEST de props de ambiente (equivalente ao ActorAssetValidator). Confere arquivo/dimensões/
## referências das definições. NÃO valida arte subjetiva. Não roda em produção.

## Valida uma definição de prop (arquivo existe + carrega + dimensões > 0). Retorna {ok, errors[], w, h}.
static func validate_prop(prop_id: String) -> Dictionary:
	var out := {"ok": false, "errors": [], "w": 0, "h": 0, "prop_id": prop_id}
	if not EnvironmentPropDefinition.exists(prop_id):
		out["errors"].append("UNKNOWN_PROP: %s" % prop_id); return out
	var p := EnvironmentPropDefinition.get_prop(prop_id)
	var path := str(p.get("texture", ""))
	if not ResourceLoader.exists(path):
		out["errors"].append("MISSING_FILE: %s" % path); return out
	var tex := load(path) as Texture2D
	if tex == null:
		out["errors"].append("NOT_A_TEXTURE: %s" % path); return out
	out["w"] = tex.get_width(); out["h"] = tex.get_height()
	if tex.get_width() <= 0 or tex.get_height() <= 0:
		out["errors"].append("BAD_DIMENSIONS")
	# árvore precisa de canopy_frac coerente; prop que colide precisa de footprint
	if str(p.get("category", "")) == "TREE" and not (float(p.get("canopy_frac", 0.0)) > 0.0 and float(p["canopy_frac"]) < 1.0):
		out["errors"].append("TREE_CANOPY_FRAC_INVALID")
	if str(p.get("collision", "NONE")) != "NONE" and (p.get("footprint", {}) as Dictionary).is_empty():
		out["errors"].append("MISSING_FOOTPRINT")
	out["ok"] = (out["errors"] as Array).is_empty()
	return out

## Valida TODO o catálogo. Retorna {ok, checked, failed[]}.
static func validate_all() -> Dictionary:
	var failed: Array = []; var checked := 0
	for id in EnvironmentPropDefinition.all_ids():
		checked += 1
		var r := validate_prop(id)
		if not bool(r["ok"]): failed.append({"prop_id": id, "errors": r["errors"]})
	return {"ok": failed.is_empty(), "checked": checked, "failed": failed}
