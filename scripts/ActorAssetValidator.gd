class_name ActorAssetValidator extends RefCounted
## A27.31 — validador DEV/TEST de packs de ator do Codex (o 1º após o novo standard de criaturas). Confere que a
## strip runtime segue o contrato do ActorAnimator: existe, dimensões, frame quadrado (lado=altura), contagem, e
## `largura == altura × n_frames`. NÃO valida arte subjetiva. NÃO roda em produção (só testes/DEV).

## Valida uma strip runtime. `key` = caminho relativo em res://assets/actors/ SEM extensão (ex.: "mobs/runtime/spider_matriarch").
## Retorna {ok, errors[], width, height, frame_size, frame_count}.
static func validate_strip(key: String, expected_frame_size := -1, expected_count := -1) -> Dictionary:
	var out := {"ok": false, "errors": [], "width": 0, "height": 0, "frame_size": 0, "frame_count": 0, "key": key}
	var path := "res://assets/actors/%s.png" % key
	if not ResourceLoader.exists(path):
		out["errors"].append("MISSING_FILE: %s" % path); return out
	var tex := load(path) as Texture2D
	if tex == null:
		out["errors"].append("NOT_A_TEXTURE: %s" % path); return out
	var w := tex.get_width(); var h := tex.get_height()
	out["width"] = w; out["height"] = h; out["frame_size"] = h
	if h <= 0 or w <= 0:
		out["errors"].append("BAD_DIMENSIONS %dx%d" % [w, h]); return out
	if w % h != 0:
		out["errors"].append("WIDTH_NOT_MULTIPLE_OF_HEIGHT (%d %% %d != 0) — frame não-quadrado" % [w, h])
	var count := int(w / h)
	out["frame_count"] = count
	if w != h * count:
		out["errors"].append("FORMULA_FAIL: width(%d) != height(%d) × count(%d)" % [w, h, count])
	if expected_frame_size > 0 and h != expected_frame_size:
		out["errors"].append("FRAME_SIZE %d != esperado %d" % [h, expected_frame_size])
	if expected_count > 0 and count != expected_count:
		out["errors"].append("FRAME_COUNT %d != esperado %d" % [count, expected_count])
	out["ok"] = (out["errors"] as Array).is_empty()
	return out

## Valida um ator com direções (base + _side + _up). Retorna {ok, base, side, up, errors[]}.
static func validate_actor(key: String, expected_frame_size := -1, expected_count := -1, require_dirs := true) -> Dictionary:
	var base := validate_strip(key, expected_frame_size, expected_count)
	var res := {"ok": base["ok"], "base": base, "errors": (base["errors"] as Array).duplicate()}
	for d in ["side", "up"]:
		var dk := "%s_%s" % [key, d]
		if ResourceLoader.exists("res://assets/actors/%s.png" % dk):
			var v := validate_strip(dk, expected_frame_size, expected_count)
			res[d] = v
			if not bool(v["ok"]): res["errors"].append_array(v["errors"]); res["ok"] = false
		elif require_dirs:
			res["errors"].append("MISSING_DIRECTION: %s" % dk); res["ok"] = false
	res["ok"] = (res["errors"] as Array).is_empty()
	return res
