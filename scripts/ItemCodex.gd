class_name ItemCodex extends Node
## ItemCodex — CÓDICE DE ITENS (FATIA A7, PARTE VI). Recompensa DESCOBRIR itens ÚNICOS do catálogo (não
## quantidade do mesmo). Marcos reivindicáveis dão bônus REAL pequeno (dano+HP), nunca CP artificial (§28/§39).
##
## ★ DADOS no GameState (`codex_discovered` = ids únicos, `codex_claimed` = nº de marcos). Descoberta ocorre ao
## RECEBER/EQUIPAR/COLETAR-offline via LootManager (§44) — salvage posterior NÃO apaga (§44). Item offline só
## descobre no CLAIM do baú (§70), pois só aí passa pelo LootManager. LIFETIME: Prestígio NÃO reseta (§49).
##
## ★ NÃO há item generator procedural nesta fatia (§50): o Códice opera sobre o catálogo ItemDB atual (~31
## equipáveis). Marcos além do catálogo ficam preparados mas NÃO reivindicáveis (§46).

## Marcos de nº de itens ÚNICOS descobertos (data-driven, §46). Catálogo Godot atual ~31 equipáveis ⇒ 5/10/20/30
## são alcançáveis; 40/50 ficam PREPARADOS p/ expansão futura (não claimáveis até haver catálogo).
const MILESTONES := [5, 10, 20, 30, 40, 50]

var _host = null

func setup(host = null) -> void:
	_host = host

func _gs():
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("GameState")
	return null

# ── descoberta ──
## Marca um item como descoberto (delegado ao GameState, que valida catálogo/equipável). true se é NOVO.
func discover(id: String) -> bool:
	var gs = _gs()
	return gs != null and gs.codex_discover(id)

func unique_count() -> int:
	var gs = _gs()
	return int(gs.codex_unique_count()) if gs != null else 0

# ── marcos ──
## Nº de marcos ATINGIDOS por uma contagem de únicos (só conta marcos ≤ tamanho REAL do catálogo — §46).
static func reached_milestones(unique: int, catalog_size: int) -> int:
	var n := 0
	for m in MILESTONES:
		if m <= catalog_size and unique >= m:
			n += 1
	return n

func _catalog_size() -> int:
	return ItemDB.equippable_count()

func reached() -> int:
	return reached_milestones(unique_count(), _catalog_size())

## Marcos reivindicáveis (atingidos − reivindicados).
func claimable() -> int:
	var gs = _gs()
	if gs == null:
		return 0
	return maxi(0, reached() - int(gs.codex_claimed_count()))

func has_available_action() -> bool:
	return claimable() > 0

## Itens únicos faltando p/ o próximo marco claimável (0 = nenhum próximo dentro do catálogo).
func to_next_milestone() -> int:
	var u := unique_count()
	var cat := _catalog_size()
	for m in MILESTONES:
		if m <= cat and u < m:
			return m - u
	return 0

# ── claim ──
## Reivindica TODOS os marcos atingidos (claimed ← atingidos). Idempotente. Retorna marcos creditados.
func claim() -> int:
	var gs = _gs()
	if gs == null:
		return 0
	var reached_now := reached()
	var gained := reached_now - int(gs.codex_claimed_count())
	if gained <= 0:
		return 0
	gs.codex_set_claimed(reached_now)
	return gained

# ── projeção de CP (PURA) — bump temporário de codex_claimed + PowerBudget.cp() ──
func projected_cp_gain() -> int:
	var gs = _gs()
	if gs == null:
		return 0
	var pend := claimable()
	if pend <= 0:
		return 0
	var cp_now: int = PowerBudget.cp()
	var saved: int = gs.codex_claimed
	gs.codex_claimed = saved + pend
	var cp_proj: int = PowerBudget.cp()
	gs.codex_claimed = saved
	return cp_proj - cp_now

func status_text() -> String:
	return "Itens únicos: %d/%d · Marcos: %d · A coletar: %d" % [unique_count(), _catalog_size(), (_gs().codex_claimed_count() if _gs() != null else 0), claimable()]
