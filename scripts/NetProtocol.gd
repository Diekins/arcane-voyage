class_name NetProtocol extends RefCounted
## FATIA A11.1 — PROTOCOLO DE MENSAGEM (envelope versionado). Transport e Authority são SEPARADOS (§3): este arquivo
## só define/serializa o ENVELOPE e valida FORMA — NÃO executa economia. Envelope pequeno, versionado (§4/§5). O
## cliente jamais ganha autoridade por injetar campo no pacote (§40 whitelist). request_id (troca de rede) ≠
## command_id (operação lógica idempotente) (§6). Formato = JSON UTF-8 (adequado ao Godot, debugável); pacote ENet
## já é o frame. Limite de tamanho (§41). NÃO faz crypto (§53/§81) — token é opaco, gerado server-side.

const PROTOCOL_VERSION := 1
const MAX_MSG_BYTES := 65536            # §41 — teto razoável de mensagem; acima disso = OVERSIZED, sem crash

# ── message_type (§4) ──
const HELLO := "HELLO"                  # cliente→servidor: handshake (declara protocol_version)
const HELLO_ACK := "HELLO_ACK"
const LOGIN := "LOGIN"                  # cliente→servidor: credencial DEV (§8)
const LOGIN_RESULT := "LOGIN_RESULT"
const OPEN_CHARACTER := "OPEN_CHARACTER"
const OPEN_RESULT := "OPEN_RESULT"      # inclui snapshot + revision (§31)
const COMMAND := "COMMAND"              # operação econômica (§4)
const COMMAND_RESULT := "COMMAND_RESULT"
const GET_STATE := "GET_STATE"          # resync (§32)
const STATE := "STATE"
const HEARTBEAT := "HEARTBEAT"          # §33 — mantém lease; timestamp final é do ServerClock (§34)
const HEARTBEAT_ACK := "HEARTBEAT_ACK"
const LOGOUT := "LOGOUT"
const RECONNECT := "RECONNECT"          # §36 — reassocia um token a uma nova conexão (mesma conta)
const RECONNECT_RESULT := "RECONNECT_RESULT"
const ARENA_QUERY := "ARENA_QUERY"      # A12 — leituras da Arena (profile/leaderboards/my_rank/nearby/season)
const ARENA_RESULT := "ARENA_RESULT"
const CHAR_QUERY := "CHAR_QUERY"        # A13 — roster/create/select/identity/loadout/appearance (nível de CONTA)
const CHAR_RESULT := "CHAR_RESULT"
const HUNT_QUERY := "HUNT_QUERY"        # A16 — start/stop/state/presence de Hunting Ground (só ground_id do cliente)
const HUNT_RESULT := "HUNT_RESULT"
const ERROR := "ERROR"                  # resposta de rejeição (reason)
const PROTOCOL_MISMATCH := "PROTOCOL_MISMATCH"   # §5 — nunca interpreta pacote de outra versão

# ── permissões de comando (§33/§59) ──
const PERM_CLIENT := "CLIENT_ALLOWED"
const PERM_SERVER_INTERNAL := "SERVER_INTERNAL"
const PERM_DEV_ONLY := "DEV_ONLY"

## Política por comando: cliente comum só pode os econômicos do próprio character; loot/boss são internos (§57/§58).
const COMMAND_PERMISSION := {
	"REFINE_SLOT": PERM_CLIENT,
	"CLAIM_OFFLINE": PERM_CLIENT,
	"PRESTIGE": PERM_CLIENT,
	"EQUIP_INSTANCE": PERM_CLIENT,
	"GRANT_LOOT": PERM_SERVER_INTERNAL,     # §57 — sem endpoint "me dê loot"
	"CLEAR_BOSS": PERM_SERVER_INTERNAL,     # §58 — cliente não declara boss morto
	# A11.2 — Trade P2P (cliente participante; a autoridade valida participante/estado §56)
	"TRADE_INVITE": PERM_CLIENT, "TRADE_ACCEPT_INVITE": PERM_CLIENT, "TRADE_DECLINE": PERM_CLIENT,
	"TRADE_ADD_ITEM": PERM_CLIENT, "TRADE_REMOVE_ITEM": PERM_CLIENT, "TRADE_SET_GOLD": PERM_CLIENT,
	"TRADE_ACCEPT_OFFER": PERM_CLIENT, "TRADE_CANCEL": PERM_CLIENT, "TRADE_GET_STATE": PERM_CLIENT,
}

## Comandos que roteiam para o TradeService (não para a economia do AuthorityServer).
static func is_trade_command(ctype: String) -> bool:
	return ctype.begins_with("TRADE_")

## Whitelist de args por comando (§40): só estes campos chegam à Authority; o resto é DESCARTADO no parser.
## (A Authority já ignora injeção — isto é defesa-em-profundidade, o campo forjado nem trafega adiante.)
const COMMAND_ARG_WHITELIST := {
	"REFINE_SLOT": ["slot", "catalyst", "preserve", "absolute"],
	"CLAIM_OFFLINE": [],
	"PRESTIGE": [],
	"EQUIP_INSTANCE": ["iid"],
	"GRANT_LOOT": ["item_id"],
	"CLEAR_BOSS": ["global_stage"],
	"TRADE_INVITE": ["target"], "TRADE_ACCEPT_INVITE": ["trade_id"], "TRADE_DECLINE": ["trade_id"],
	"TRADE_ADD_ITEM": ["trade_id", "iid"], "TRADE_REMOVE_ITEM": ["trade_id", "iid"],
	"TRADE_SET_GOLD": ["trade_id", "amount"], "TRADE_ACCEPT_OFFER": ["trade_id", "offer_version"],
	"TRADE_CANCEL": ["trade_id"], "TRADE_GET_STATE": ["trade_id"],
}

## Monta um envelope. `sid` = session token ("" antes do login). `rid` identifica a TROCA de rede.
static func envelope(msg_type: String, request_id: String, session_token: String, payload: Dictionary) -> Dictionary:
	return {"v": PROTOCOL_VERSION, "t": msg_type, "rid": request_id, "sid": session_token, "p": payload}

## Serializa envelope → bytes (frame ENet).
static func encode(env: Dictionary) -> PackedByteArray:
	return JSON.stringify(env).to_utf8_buffer()

## Desserializa bytes → {ok, env|reason}. Trata malformado SEM crash (§39): JSON inválido, tamanho, campos.
static func decode(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() == 0:
		return {"ok": false, "reason": "EMPTY"}
	if bytes.size() > MAX_MSG_BYTES:
		return {"ok": false, "reason": "OVERSIZED"}
	var txt := bytes.get_string_from_utf8()
	var j = JSON.parse_string(txt)
	if typeof(j) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "BAD_JSON"}
	var env: Dictionary = j
	# rid best-effort para ecoar na resposta de erro (o cliente casa por rid)
	var rid_be := str(env.get("rid", "")) if typeof(env.get("rid")) == TYPE_STRING else ""
	if not env.has("t") or typeof(env.get("t")) != TYPE_STRING or str(env["t"]) == "":
		return {"ok": false, "reason": "NO_TYPE", "rid": rid_be}          # §39 message_type ausente
	if not env.has("v") or int(env.get("v", -1)) != PROTOCOL_VERSION:
		return {"ok": false, "reason": "PROTOCOL_MISMATCH", "rid": rid_be} # §5 — versão errada, nunca interpreta
	# normaliza campos opcionais
	if not env.has("rid") or typeof(env.get("rid")) != TYPE_STRING: env["rid"] = ""
	if not env.has("sid") or typeof(env.get("sid")) != TYPE_STRING: env["sid"] = ""
	if not env.has("p") or typeof(env.get("p")) != TYPE_DICTIONARY: env["p"] = {}
	return {"ok": true, "env": env}

## Extrai um COMMAND seguro do payload aplicando permissão e whitelist. Devolve {ok, command|reason, perm}.
## `dev_connection` habilita comandos SERVER_INTERNAL/DEV_ONLY (harness/admin) — cliente comum NÃO (§57/§58/§59).
static func parse_command(payload: Dictionary, dev_connection: bool = false) -> Dictionary:
	var ctype := str(payload.get("command_type", ""))
	if ctype == "":
		return {"ok": false, "reason": "NO_COMMAND_TYPE"}
	if not COMMAND_PERMISSION.has(ctype):
		return {"ok": false, "reason": "UNKNOWN_COMMAND"}
	var perm := str(COMMAND_PERMISSION[ctype])
	if perm != PERM_CLIENT and not dev_connection:
		return {"ok": false, "reason": "PERMISSION_DENIED", "perm": perm}   # §57/§58 endpoint interno
	var cmd_id := str(payload.get("command_id", ""))
	if cmd_id == "":
		return {"ok": false, "reason": "NO_COMMAND_ID"}
	# whitelist de args (§40): só os campos permitidos atravessam
	var raw_args: Dictionary = payload.get("args", {}) if payload.get("args", {}) is Dictionary else {}
	var allowed: Array = COMMAND_ARG_WHITELIST.get(ctype, [])
	var command := {"type": ctype, "command_id": cmd_id}
	for k in allowed:
		if raw_args.has(k):
			command[k] = raw_args[k]
	return {"ok": true, "command": command, "perm": perm}
