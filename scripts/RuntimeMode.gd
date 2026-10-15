class_name RuntimeMode extends RefCounted
## FATIA A11.1 — MODOS EXPLÍCITOS (§22): LOCAL / SERVER / CLIENT. Nada de detecção mágica/frágil — lê CLI ou env,
## default LOCAL. LOCAL continua autoridade EMBUTIDA, sem socket (§21/§86). SERVER = headless sem UI (§19/§84).
## CLIENT = conecta ao servidor (§20). Também expõe o SERVER_ENV para o guard de produção (§52): LocalDevAuth NUNCA
## pode subir em production.

const LOCAL := "LOCAL"
const SERVER := "SERVER"
const CLIENT := "CLIENT"

const ENV_DEV := "development"
const ENV_PRODUCTION := "production"

## Resolve o modo a partir de CLI (--server/--client/--local) ou env AV_MODE. Default = LOCAL (§21).
static func resolve() -> String:
	var args := OS.get_cmdline_user_args() + OS.get_cmdline_args()
	for a in args:
		var s := str(a).to_lower()
		if s == "--server" or s == "--av-server": return SERVER
		if s == "--client" or s == "--av-client": return CLIENT
		if s == "--local" or s == "--av-local": return LOCAL
	if OS.has_environment("AV_MODE"):
		var m := OS.get_environment("AV_MODE").to_upper()
		if m == SERVER or m == CLIENT or m == LOCAL:
			return m
	return LOCAL

## Ambiente do servidor (§52). Default = development. Produção é declarada por env AV_SERVER_ENV=production.
static func server_env() -> String:
	if OS.has_environment("AV_SERVER_ENV"):
		var e := OS.get_environment("AV_SERVER_ENV").to_lower()
		if e == ENV_PRODUCTION: return ENV_PRODUCTION
	return ENV_DEV

static func is_production() -> bool:
	return server_env() == ENV_PRODUCTION

## Guard de boot (§52): em produção o AuthProvider DEV é PROIBIDO. Retorna {ok, reason}. O servidor deve
## ABORTAR o boot se ok==false. (Aqui não há AuthProvider de produção implementado — só o contrato §51 —,
## então production sempre falha de propósito: ninguém sobe produção acidentalmente com auth de dev.)
static func validate_auth_for_env(provider_is_dev_only: bool) -> Dictionary:
	return decide_auth(is_production(), provider_is_dev_only)

## Decisão PURA do guard (testável sem mexer em env): produção + auth DEV = FAIL BOOT (§52).
static func decide_auth(prod: bool, provider_is_dev_only: bool) -> Dictionary:
	if prod and provider_is_dev_only:
		return {"ok": false, "reason": "DEV_AUTH_IN_PRODUCTION"}
	return {"ok": true}
