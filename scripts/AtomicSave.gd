class_name AtomicSave extends RefCounted
## FATIA A14.1 — SAVE LOCAL ATÔMICO (§25-31). ★ Nunca "trunca canonical e reza": escreve TEMP inteiro → valida →
## promove (backup + rename). Se o processo morre a qualquer momento, o estado final é o SAVE VÁLIDO ANTIGO ou o
## NOVO — nunca zero bytes (§31). Load com recovery: canonical → backup (§28). TEMP incompleto NUNCA vira canonical
## (§28). Principalmente LOCAL/cache (§30) — o repositório do servidor continua autoridade online. Fault injection
## p/ testes (§31). Preserva schema v10 (§ASAVE-T06).

# fault de teste: ""|"BEFORE_TEMP"|"DURING_TEMP"(trunca)|"AFTER_TEMP_NO_PROMOTE"|"DURING_PROMOTE"(entre remove e rename)
static var _fault := ""
static func set_fault(f: String) -> void: _fault = f

static func _tmp(path: String) -> String: return path + ".tmp"
static func _bak(path: String) -> String: return path + ".bak"

## Valida um texto de save: parseável + tem schemaVersion (§29 — estrutura mínima, não lógica de gameplay).
static func validate_text(text: String) -> bool:
	if text.strip_edges() == "": return false
	var j = JSON.parse_string(text)
	return typeof(j) == TYPE_DICTIONARY and (j as Dictionary).has("schemaVersion")

static func _write(path: String, text: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null: return false
	f.store_string(text); f.flush(); f.close()
	return true

## Salva de forma atômica. Retorna {ok, reason}. Canonical antigo SEMPRE sobrevive se algo falhar.
static func save_atomic(path: String, text: String) -> Dictionary:
	var tmp := _tmp(path)
	# §31 crash antes do temp → nada muda
	if _fault == "BEFORE_TEMP":
		return {"ok": false, "reason": "FAULT_BEFORE_TEMP"}
	# escreve o temp inteiro (ou truncado, se fault)
	if _fault == "DURING_TEMP":
		_write(tmp, text.substr(0, maxi(1, text.length() / 2)))   # temp truncado/inválido
	else:
		_write(tmp, text)
	# valida o temp ANTES de promover (§29). Temp inválido → descarta, canonical intacto
	var tmp_text := FileAccess.get_file_as_string(tmp) if FileAccess.file_exists(tmp) else ""
	if not validate_text(tmp_text):
		if FileAccess.file_exists(tmp): DirAccess.remove_absolute(tmp)
		return {"ok": false, "reason": "BAD_TEMP"}   # §ASAVE-T04 — canonical não tocado
	# §31 crash após temp válido, antes de promover → canonical antigo sobrevive
	if _fault == "AFTER_TEMP_NO_PROMOTE":
		return {"ok": false, "reason": "FAULT_NO_PROMOTE"}
	# promove: backup do canonical (se existe) → remove canonical → rename temp→canonical
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(_bak(path)): DirAccess.remove_absolute(_bak(path))
		DirAccess.copy_absolute(path, _bak(path))   # §27 uma geração de backup
		DirAccess.remove_absolute(path)
	# §31 crash no meio da promoção (canonical já removido, ainda não renomeado) → recovery acha o .bak
	if _fault == "DURING_PROMOTE":
		return {"ok": false, "reason": "FAULT_DURING_PROMOTE"}
	DirAccess.rename_absolute(tmp, path)
	return {"ok": true}

## Carrega com recovery (§28): canonical válido → senão backup válido → senão falha. TEMP nunca é aceito como canonical.
static func load_recover(path: String) -> Dictionary:
	if FileAccess.file_exists(path):
		var t := FileAccess.get_file_as_string(path)
		if validate_text(t):
			return {"ok": true, "text": t, "source": "canonical"}
	if FileAccess.file_exists(_bak(path)):
		var b := FileAccess.get_file_as_string(_bak(path))
		if validate_text(b):
			return {"ok": true, "text": b, "source": "backup"}   # §ASAVE-T05 recovery
	return {"ok": false, "reason": "NO_VALID_SAVE"}

## Limpa artefatos (temp/bak/canonical) — uso de teste; NUNCA no save vivo.
static func cleanup(path: String) -> void:
	for p in [path, _tmp(path), _bak(path)]:
		if FileAccess.file_exists(p): DirAccess.remove_absolute(p)
