class_name SessionRegistry extends RefCounted
## FATIA A11.1 — FRONTEIRA connection ≠ session (§10). O socket/peer pode cair; a SESSION é entidade separada,
## viva no AuthorityServer (lease). Aqui mora: autenticação da CONEXÃO (via LocalDevAuthProvider §8), o TOKEN de
## sessão (opaco, gerado server-side §9, ligado a account+character+lease-de-autoridade), e as políticas de
## reconnect (§36), 1-writer-por-sessão (§37) e anti-hijack (§38). NÃO faz crypto (§81) — o token é aleatório
## server-side; no DEV a "credencial" é o account_id (por isso DEV_ONLY). A garantia que PROVAMOS: um token só é
## usável numa conexão cuja conta AUTENTICADA seja a dona do token — conexão de B não opera token de A.

var _server: AuthorityServer
var _tokens: Dictionary = {}        # token → {account, character, authority_sid, connection_id}
var _by_conn: Dictionary = {}       # connection_id → token (conexão viva ligada a 1 sessão)
var _conn_account: Dictionary = {}  # connection_id → account autenticado (identidade da conexão)
var _rng := RandomNumberGenerator.new()
var _tok_counter := 0

func setup(server: AuthorityServer, rng_seed: int = 909090) -> void:
	_server = server
	_rng.seed = rng_seed

func _gen_token() -> String:
	_tok_counter += 1
	return "tok_%d_%08x" % [_tok_counter, _rng.randi()]   # opaco, server-side (§9); NÃO é character_id

## Autentica uma CONEXÃO via provider DEV. Liga connection→account (identidade). Cliente não declara conta crua
## como confiável sem passar aqui (§8). Em produção, o account virá do token verificado (§51).
func authenticate_connection(connection_id: String, credentials: Dictionary) -> Dictionary:
	var a := LocalDevAuthProvider.authenticate(credentials)
	if not bool(a.get("ok", false)):
		return {"ok": false, "reason": str(a.get("reason", "AUTH_FAILED"))}
	_conn_account[connection_id] = str(a["account_id"])
	return {"ok": true, "account_id": str(a["account_id"]), "dev_only": true}

## Abre um character sob a conexão autenticada. Valida ownership + lease single-session na Authority. Emite TOKEN.
func open_character(connection_id: String, character_id: String) -> Dictionary:
	var account := str(_conn_account.get(connection_id, ""))
	if account == "":
		return {"ok": false, "reason": "NOT_AUTHENTICATED"}
	var s := _server.open_session(account, character_id)   # NOT_OWNER / SESSION_IN_USE ficam a cargo da Authority
	if not bool(s.get("ok", false)):
		return {"ok": false, "reason": str(s.get("reason", "OPEN_FAILED"))}
	var token := _gen_token()
	_tokens[token] = {"account": account, "character": character_id, "authority_sid": str(s["session_id"]), "connection_id": connection_id}
	_by_conn[connection_id] = token
	return {"ok": true, "token": token, "authority_sid": str(s["session_id"]), "revision": int(s.get("revision", -1)), "character": character_id}

## Resolve um request: dada a conexão + token apresentado, devolve a sessão de autoridade SE válida e da conta certa.
func resolve(connection_id: String, token: String) -> Dictionary:
	if token == "" or not _tokens.has(token):
		return {"ok": false, "reason": "BAD_SESSION"}
	var t: Dictionary = _tokens[token]
	var conn_account := str(_conn_account.get(connection_id, ""))
	if conn_account == "" or conn_account != str(t["account"]):
		return {"ok": false, "reason": "SESSION_HIJACK"}     # §38 — token não pertence à conta desta conexão
	if str(t["connection_id"]) != connection_id:
		return {"ok": false, "reason": "WRONG_CONNECTION"}   # §37 — token ligado a outra conexão viva
	return {"ok": true, "authority_sid": str(t["authority_sid"]), "account": str(t["account"]), "character": str(t["character"])}

## Reconnect (§36): re-liga um token a uma NOVA conexão. Exige a MESMA conta autenticada (prova ownership).
## Substitui a conexão antiga (1 writer §37) — não deixa duas conexões escrevendo o mesmo character.
func rebind(new_connection_id: String, token: String) -> Dictionary:
	if not _tokens.has(token):
		return {"ok": false, "reason": "BAD_SESSION"}
	var t: Dictionary = _tokens[token]
	var conn_account := str(_conn_account.get(new_connection_id, ""))
	if conn_account == "" or conn_account != str(t["account"]):
		return {"ok": false, "reason": "SESSION_HIJACK"}
	var old_conn := str(t["connection_id"])
	if old_conn != "" and old_conn != new_connection_id:
		_by_conn.erase(old_conn)                              # desliga a conexão antiga
	t["connection_id"] = new_connection_id
	_by_conn[new_connection_id] = token
	return {"ok": true, "authority_sid": str(t["authority_sid"]), "character": str(t["character"])}

## Socket caiu (§35): a conexão some, mas a SESSION persiste (o lease de autoridade decide expiry). O token fica
## "destacado" (connection_id="") aguardando reconnect ou expiry — não é revogado aqui.
func drop_connection(connection_id: String) -> void:
	var tok := str(_by_conn.get(connection_id, ""))
	if tok != "" and _tokens.has(tok):
		_tokens[tok]["connection_id"] = ""
	_by_conn.erase(connection_id)
	_conn_account.erase(connection_id)

## Logout explícito: revoga token e fecha a sessão de autoridade (libera o lease).
func revoke(token: String) -> void:
	if not _tokens.has(token):
		return
	var t: Dictionary = _tokens[token]
	_server.close_session(str(t["authority_sid"]))
	_by_conn.erase(str(t["connection_id"]))
	_tokens.erase(token)

func account_of_connection(connection_id: String) -> String:
	return str(_conn_account.get(connection_id, ""))

func active_token_count() -> int: return _tokens.size()
