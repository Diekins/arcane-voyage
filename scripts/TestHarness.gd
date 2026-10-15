class_name TestHarness extends RefCounted
## A31 — TEST INTEGRITY V1. "NO SILENT GREEN": um grupo que ABORTA (early return, runtime null, setup falho)
## ou que não atinge o mínimo de asserts NÃO passa — e o runner geral fica FAIL. GDScript não tem try/catch de
## erro de runtime; então a garantia é ESTRUTURAL: cada grupo precisa CHAMAR group_complete() no fim E cumprir
## asserts >= minimum. Se um caminho de erro pula o group_complete (o caso clássico da A29), o grupo fica
## INCOMPLETE ⇒ runner FAIL. Uso: h.group_begin(nome,min) → h.check(...)* → h.group_complete(); no fim h.summarize().

var groups: Array = []          # cada: {name,min,asserts,fails,completed,error,fail_descs}
var _cur = null                 # Dictionary do grupo aberto, ou null
var strict := false             # STRICT_TEST_MODE (dev/test): warning estrutural grave falha a suíte

func _init(strict_mode := false) -> void:
	strict = strict_mode

# ── lifecycle ──
func group_begin(name: String, minimum: int) -> void:
	# grupo anterior aberto e não-completo permanece registrado como INCOMPLETE (não sobrescreve)
	_cur = {"name": name, "min": int(minimum), "asserts": 0, "fails": 0, "completed": false, "error": "", "fail_descs": []}
	groups.append(_cur)

func check(desc: String, cond: bool) -> bool:
	if _cur == null:
		push_error("TestHarness.check() sem grupo aberto: " + desc)
		return cond
	_cur["asserts"] = int(_cur["asserts"]) + 1
	if cond:
		print("    OK  %s" % desc)
	else:
		_cur["fails"] = int(_cur["fails"]) + 1
		(_cur["fail_descs"] as Array).append(desc)
		print("    ✗   %s" % desc)
	return cond

## falha estrutural explícita do grupo (setup null, boot de cena falho, runtime null) — NÃO é PASS por omissão.
func group_error(reason: String) -> void:
	if _cur == null:
		push_error("TestHarness.group_error() sem grupo aberto: " + reason)
		return
	_cur["error"] = reason
	_cur["fails"] = int(_cur["fails"]) + 1
	print("    ✗   [GROUP ERROR] %s" % reason)

func group_complete() -> void:
	if _cur != null:
		_cur["completed"] = true

# ── veredito ──
func status_of(g: Dictionary) -> String:
	if not bool(g.get("completed", false)):
		return "INCOMPLETE"
	if int(g.get("asserts", 0)) < int(g.get("min", 0)):
		return "FAIL_MIN"
	if int(g.get("fails", 0)) > 0 or str(g.get("error", "")) != "":
		return "FAIL"
	return "PASS"

func all_ok() -> bool:
	if groups.is_empty():
		return false
	for g in groups:
		if status_of(g) != "PASS":
			return false
	return true

## imprime a tabela de verdade e devolve {ok, total, pass, fail, incomplete, asserts}. ok SÓ se fail==0 E incomplete==0 E há grupos.
func summarize(title := "") -> Dictionary:
	var pass_n := 0; var fail_n := 0; var inc_n := 0; var asserts := 0
	for g in groups:
		asserts += int(g.get("asserts", 0))
		match status_of(g):
			"PASS": pass_n += 1
			"INCOMPLETE": inc_n += 1
			_: fail_n += 1
	for g in groups:
		var st := status_of(g)
		var extra := "" if str(g.get("error", "")) == "" else (" err=%s" % str(g.get("error")))
		print("  [%-10s] %-16s asserts=%d/min=%d fails=%d%s" % [st, str(g.get("name")), int(g.get("asserts", 0)), int(g.get("min", 0)), int(g.get("fails", 0)), extra])
	var ok := (fail_n == 0 and inc_n == 0 and not groups.is_empty())
	print("  ── %s: groups=%d PASS=%d FAIL=%d INCOMPLETE=%d asserts=%d ⇒ %s" % [title, groups.size(), pass_n, fail_n, inc_n, asserts, (">>> OK" if ok else ">>> FALHOU")])
	return {"ok": ok, "total": groups.size(), "pass": pass_n, "fail": fail_n, "incomplete": inc_n, "asserts": asserts}

# ══════════════════════════════════════════════════════════════════════════════════════════════
# HELPERS DE CATÁLOGO (estáticos, puros) — subset/unique em vez de count congelado
# ══════════════════════════════════════════════════════════════════════════════════════════════
## IDs de `required` que FALTAM em `actual` (vazio = tudo presente). Base do "required ⊆ actual".
static func missing_ids(required: Array, actual: Array) -> Array:
	var miss: Array = []
	for r in required:
		if not (r in actual):
			miss.append(r)
	return miss

## IDs duplicados numa lista (vazio = todos únicos).
static func duplicate_ids(ids: Array) -> Array:
	var seen := {}; var dups: Array = []
	for i in ids:
		if seen.has(i):
			if not (i in dups): dups.append(i)
		else:
			seen[i] = true
	return dups

# ── asserts de catálogo que registram no harness ──
## required ⊆ actual (catálogo pode CRESCER; só falha se sumir conteúdo requerido).
func assert_registry_contains(desc: String, actual: Array, required: Array) -> bool:
	var miss := missing_ids(required, actual)
	return check(desc + ("" if miss.is_empty() else " (FALTA: %s)" % str(miss)), miss.is_empty())

## nenhum ID duplicado.
func assert_registry_unique(desc: String, ids: Array) -> bool:
	var d := duplicate_ids(ids)
	return check(desc + ("" if d.is_empty() else " (DUP: %s)" % str(d)), d.is_empty())

## contagem >= mínimo (piso, não igualdade). Catálogo pode crescer acima do piso.
func assert_minimum_count(desc: String, actual_count: int, minimum: int) -> bool:
	return check(desc + (" (%d>=%d)" % [actual_count, minimum]), actual_count >= minimum)

## def tem todas as chaves obrigatórias.
func assert_definition_valid(desc: String, def: Dictionary, required_keys: Array) -> bool:
	var miss: Array = []
	for k in required_keys:
		if not def.has(k): miss.append(k)
	return check(desc + ("" if miss.is_empty() else " (FALTA KEYS: %s)" % str(miss)), miss.is_empty())

## toda referência em `refs` existe em `universe` (broken-reference). Retorna a lista quebrada p/ diagnóstico.
func assert_all_references_valid(desc: String, refs: Array, universe: Array) -> bool:
	var broken: Array = []
	for r in refs:
		if not (r in universe) and not (r in broken): broken.append(r)
	return check(desc + ("" if broken.is_empty() else " (REF QUEBRADA: %s)" % str(broken)), broken.is_empty())
