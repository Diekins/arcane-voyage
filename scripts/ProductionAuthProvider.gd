class_name ProductionAuthProvider extends RefCounted
## FATIA A11.1 — CONTRATO do AuthProvider de PRODUÇÃO (§51). ★ NÃO IMPLEMENTA autenticação real: só formaliza o
## ENCAIXE para a fatia futura. Toda chamada FALHA de propósito (NOT_IMPLEMENTED) — assim ninguém "liga" produção
## por engano achando que já autentica. O `LocalDevAuthProvider` continua o único caminho de bancada (DEV_ONLY).
##
## REQUISITOS que a implementação real terá de cumprir (documentados, não codificados):
##   1. Identidade AUTENTICADA por terceiro confiável (Steam/Epic/OAuth/backend próprio) — nunca o cliente cru.
##   2. account_id ESTÁVEL derivado do provedor, não escolhido pelo cliente (§8/§40).
##   3. Token VALIDADO server-side a cada request (assinatura/introspection do provedor) — sem crypto caseira (§81).
##   4. Expiry + revocation: token expira e pode ser revogado; sessão cai junto.
##   5. NUNCA confiar em account_id enviado no pacote; ele é sempre derivado do token verificado.
##   6. Segredos ficam no SERVIDOR (secrets manager), nunca no cliente (§53).

const DEV_ONLY := false
const NOT_PRODUCTION_AUTH := false

## Contrato: verificar um token de produção → identidade. Aqui SEMPRE falha (não implementado nesta fatia).
static func verify_token(_token: String) -> Dictionary:
	return {"ok": false, "reason": "NOT_IMPLEMENTED", "note": "ProductionAuthProvider é só contrato (§51)."}

static func authenticate(_credentials: Dictionary) -> Dictionary:
	return {"ok": false, "reason": "NOT_IMPLEMENTED"}
