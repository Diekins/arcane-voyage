class_name UIBackStack extends RefCounted
## FATIA A14.2 — política CENTRAL de navegação BACK (§49-52). ★ Android VOLTAR / PC Esc / botão ✕ chamam a MESMA
## action (§50/§51/§52). BACK: fecha o modal do topo → fecha painel secundário → volta ao painel anterior → só então
## considera SAIR (§49). Nunca "Android back → quit" com painel aberto (§26). Puro/testável.

const KIND_MODAL := "MODAL"
const KIND_PANEL := "PANEL"

var _stack: Array = []   # [{id, kind}]

## Empilha um painel/modal aberto.
func push(id: String, kind: String = KIND_PANEL) -> void:
	_stack.append({"id": id, "kind": kind})

func top() -> Dictionary:
	return _stack[-1].duplicate() if _stack.size() > 0 else {}

func depth() -> int: return _stack.size()

func is_open(id: String) -> bool:
	for e in _stack:
		if str(e["id"]) == id: return true
	return false

## Ação BACK (§49): fecha o topo se houver; senão sinaliza EXIT_REQUEST (o app decide, nunca fecha sozinho §26/§50).
func back() -> Dictionary:
	if _stack.size() > 0:
		var closed: Dictionary = _stack.pop_back()
		return {"action": "CLOSE", "closed": closed, "remaining": _stack.size()}
	return {"action": "EXIT_REQUEST"}   # nada aberto → o app pergunta "sair?" (não encerra automático)

## Fecha um id específico (botão ✕) — mesma semântica de fechamento (§52).
func close(id: String) -> Dictionary:
	for i in range(_stack.size() - 1, -1, -1):
		if str(_stack[i]["id"]) == id:
			var e: Dictionary = _stack[i]
			_stack.remove_at(i)
			return {"action": "CLOSE", "closed": e, "remaining": _stack.size()}
	return {"action": "NOOP"}

func clear() -> void: _stack.clear()
