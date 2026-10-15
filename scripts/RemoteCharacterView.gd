class_name RemoteCharacterView extends RefCounted
## FATIA A11.1 — ESPELHO de UI do estado autoritativo (§23). ★ NÃO é autoridade: o cliente online NUNCA edita
## economia aqui (§24). Recebe o `client_view` (DTO seguro do servidor) + revision e guarda para a tela. Aplica
## SOMENTE se a revision for >= a atual (§29/§31) — resposta atrasada/out-of-order não regride o estado.

var revision := -1
var view: Dictionary = {}

## Aplica um snapshot/view do servidor. Retorna true se aplicou; false se ignorou (revision mais velha §29).
func apply(new_revision: int, new_view: Dictionary) -> bool:
	if new_revision < revision:
		return false   # §29 — nunca regride para uma revision anterior
	revision = new_revision
	view = new_view.duplicate(true)
	return true

func gold() -> int: return int(view.get("gold", 0))
func fragments() -> int: return int(view.get("fragments", 0))
func level() -> int: return int(view.get("level", 1))
func prestige() -> int: return int(view.get("prestige", 0))
func cycle_seals() -> int: return int(view.get("cycle_seals", 0))
func item_count() -> int: return int(view.get("item_count", 0))
func equipped_instances() -> Dictionary: return view.get("equipped_instances", {})

func reset() -> void:
	revision = -1
	view = {}
