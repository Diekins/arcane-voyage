class_name LocalDevAuthProvider
## FATIA A11 — AuthProvider DEV_ONLY / NOT_PRODUCTION_AUTH (§6/§7). Existe APENAS para bancada/headless. NÃO é
## autenticação segura: a "credencial" JÁ é o account_id (fixture). Produção futura terá um AuthProvider real
## (Steam/Epic/OAuth/backend) — e este arquivo será substituído, não estendido. NÃO faz crypto/hash/token (§81):
## nenhuma criptografia caseira. A camada de AUTORIDADE (AuthorityServer) é quem importa; o auth é plugável.

const DEV_ONLY := true
const NOT_PRODUCTION_AUTH := true

## Autentica uma credencial de DEV → identidade {account_id}. Em produção isto virá de um provider verificado.
static func authenticate(credentials: Dictionary) -> Dictionary:
	var account := str(credentials.get("account_id", ""))
	if account == "":
		return {"ok": false, "reason": "NO_ACCOUNT"}
	return {"ok": true, "account_id": account, "dev_only": true}
