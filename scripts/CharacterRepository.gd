class_name CharacterRepository extends RefCounted
## FATIA A11 — PERSISTÊNCIA AUTORITATIVA de personagens. O estado do character é um dict no MESMO formato do
## GameState.to_dict (reusa a economia congelada; NÃO duplica o schema §8/§63). Cada estado tem uma REVISION
## MONOTÔNICA e CONCORRÊNCIA OTIMISTA (§15/§16): escrita com revision velha é REJEITADA (STALE) — nunca sobrescreve
## um estado mais novo. Ownership account→character (§4/§5). In-memory p/ bancada, com persist p/ arquivo (teste de
## RESTART §77). Metadados de servidor (revision/owner) vivem AQUI, fora do save do jogador (§63) — sem bump v10.

var _store: Dictionary = {}      # character_id → {state:Dict, revision:int, account_id:String}
var _accounts: Dictionary = {}   # account_id → Array[character_id]

## Cria um character sob uma conta. revision inicia em 1. Falha se o id já existe.
func create_character(account_id: String, character_id: String, initial_state: Dictionary) -> Dictionary:
	if _store.has(character_id):
		return {"ok": false, "reason": "EXISTS"}
	_store[character_id] = {"state": initial_state.duplicate(true), "revision": 1, "account_id": account_id}
	if not _accounts.has(account_id):
		_accounts[account_id] = []
	if not (_accounts[account_id] as Array).has(character_id):
		_accounts[account_id].append(character_id)
	return {"ok": true, "revision": 1}

## Carrega o estado autoritativo + revision (cópia PROFUNDA — o chamador não altera o store por referência).
func load(character_id: String) -> Dictionary:
	if not _store.has(character_id):
		return {"ok": false, "reason": "NOT_FOUND"}
	var e: Dictionary = _store[character_id]
	return {"ok": true, "state": (e["state"] as Dictionary).duplicate(true), "revision": int(e["revision"]), "account_id": str(e["account_id"])}

## Escreve o estado SE a revision esperada bate com a atual (concorrência otimista §16). Bump monotônico.
func save(character_id: String, expected_revision: int, new_state: Dictionary) -> Dictionary:
	if not _store.has(character_id):
		return {"ok": false, "reason": "NOT_FOUND"}
	var e: Dictionary = _store[character_id]
	var cur := int(e["revision"])
	if expected_revision != cur:
		return {"ok": false, "reason": "STALE", "current_revision": cur}   # NÃO sobrescreve estado mais novo (§16)
	e["state"] = new_state.duplicate(true)
	e["revision"] = cur + 1
	return {"ok": true, "revision": cur + 1}

## A11.2 §44 — COMMIT ATÔMICO MULTI-CHARACTER: valida TODAS as revisions esperadas, depois aplica TODAS. Se
## qualquer revision não bater → NADA muda (STALE). Single-thread + validate-all-then-apply-all = sem commit
## parcial (§43: proíbe "save A → crash → save B"). `expected`/`new_states` = {character_id: valor}.
func commit_many(expected: Dictionary, new_states: Dictionary) -> Dictionary:
	# 1) valida TUDO antes de tocar em qualquer estado
	for cid in expected:
		if not _store.has(cid):
			return {"ok": false, "reason": "NOT_FOUND", "cid": cid}
		if int(_store[cid]["revision"]) != int(expected[cid]):
			return {"ok": false, "reason": "STALE", "cid": cid, "current_revision": int(_store[cid]["revision"])}
	for cid in new_states:
		if not _store.has(cid):
			return {"ok": false, "reason": "NOT_FOUND", "cid": cid}
	# 2) aplica TUDO (já validado; nada pode falhar aqui num único thread)
	var revs: Dictionary = {}
	for cid in new_states:
		_store[cid]["state"] = (new_states[cid] as Dictionary).duplicate(true)
		_store[cid]["revision"] = int(_store[cid]["revision"]) + 1
		revs[cid] = int(_store[cid]["revision"])
	return {"ok": true, "revisions": revs}

func revision_of(character_id: String) -> int:
	if not _store.has(character_id):
		return -1
	return int(_store[character_id]["revision"])

func owner_of(character_id: String) -> String:
	if not _store.has(character_id):
		return ""
	return str(_store[character_id]["account_id"])

## A conta é dona do character? (base de todo isolamento cross-player §49/§50)
func owns(account_id: String, character_id: String) -> bool:
	return owner_of(character_id) == account_id and account_id != ""

func characters_of(account_id: String) -> Array:
	return _accounts.get(account_id, []).duplicate()

# ── PERSISTÊNCIA em arquivo (teste de RESTART do servidor §77) ──
func persist_to(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"store": _store, "accounts": _accounts}))
	f.close()
	return true

func load_from(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var j = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(j) != TYPE_DICTIONARY:
		return false
	_store = (j.get("store", {}) as Dictionary)
	_accounts = (j.get("accounts", {}) as Dictionary)
	# JSON traz revision como float → normaliza p/ int
	for cid in _store:
		_store[cid]["revision"] = int(_store[cid]["revision"])
	return true

func character_count() -> int:
	return _store.size()

## A13 — remove um character (rollback de create atômico §84/§85; NÃO é delete de produto §37).
func remove(character_id: String) -> void:
	_store.erase(character_id)
