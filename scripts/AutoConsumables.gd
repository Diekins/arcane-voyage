class_name AutoConsumables extends Node
## FATIA A17.6 — AUTO POÇÕES / AUTO CONSUMÍVEIS (requisito oficial do Arcane). Node ticado pelo Main._process em
## AMBOS os modos (Progression e Hunt). Quando o HP do herói cai abaixo do limiar e há poção de cura na mochila,
## usa automaticamente a MAIOR cura disponível (reusa GameState.use_consumable — autoridade única do inventário,
## zero refactor). Idem mana p/ classes que gastam mana. Cooldown curto anti-spam. NÃO revive (só cura vivo).
## Desacoplado do global GameState (injeção/resolução pela árvore) p/ ser testável em modo -s.

signal consumable_used(id: String, kind: String)

var game_state = null
var enabled := true
var hp_threshold := 0.5          # usa cura abaixo de 50% de HP (§24, clamp 0.1–0.9)
var critical_threshold := 0.25   # emergência: abaixo disso a poção tem prioridade IMEDIATA (§25)
var mana_threshold := 0.35       # usa poção de mana abaixo de 35%
var use_mana := true             # MANA_SYSTEM_REAL=YES (recurso de classe na progressão); Hunt não consome mana hoje
var _cd := 0.0
const USE_CD := 0.6              # intervalo mínimo entre usos (anti-spam / anti-double no mesmo frame)
# telemetria p/ o HUD/overlay
var stats := {"hp_used": 0, "mana_used": 0, "last_id": ""}

func setup(gs = null) -> void:
	game_state = gs if gs != null else get_tree().root.get_node_or_null("GameState")

## Limiares configuráveis com CLAMP (§24) — nunca aceitam NaN/negativo/>1.
func set_thresholds(hp: float, crit: float) -> void:
	hp_threshold = _clamp01(hp, 0.5); critical_threshold = clampf(_clamp01(crit, 0.25), 0.05, hp_threshold)

func _clamp01(v: float, fallback: float) -> float:
	if is_nan(v) or is_inf(v): return fallback
	return clampf(v, 0.10, 0.90)

## Chamado a cada frame pelo host (Main._process). `mend_pending` = SUPPORT com auto-cura própria pronta → a poção
## CEDE ao MEND acima do crítico (§26). Barato: só age abaixo do limiar e com cooldown livre.
func tick(delta: float, mend_pending: bool = false) -> void:
	_cd = maxf(0.0, _cd - delta)
	if not enabled or game_state == null or _cd > 0.0:
		return
	# CURA — nunca revive (HP>0); só abaixo do limiar; só se há poção
	var hpmax := int(game_state.max_hp_total())
	if hpmax > 0 and int(game_state.hero_hp) > 0:
		var frac := float(game_state.hero_hp) / float(hpmax)
		var critical := frac <= critical_threshold
		if frac < hp_threshold:
			# §26 acima do crítico, se o SUPPORT vai curar sozinho, a poção espera (não desperdiça item)
			if not critical and mend_pending:
				pass
			else:
				var missing := hpmax - int(game_state.hero_hp)
				var pid := _best_potion("heal", missing)
				if pid != "" and game_state.use_consumable(pid):
					_cd = USE_CD; stats["hp_used"] = int(stats["hp_used"]) + 1; stats["last_id"] = pid
					consumable_used.emit(pid, "hp"); return
	# MANA — só p/ classes de mana
	if use_mana and int(game_state.mana_max) > 0 and float(game_state.mana_current) / float(game_state.mana_max) < mana_threshold:
		var mmiss := int(game_state.mana_max) - int(game_state.mana_current)
		var mid := _best_potion("mana", mmiss)
		if mid != "" and game_state.use_consumable(mid):
			_cd = USE_CD; stats["mana_used"] = int(stats["mana_used"]) + 1; stats["last_id"] = mid
			consumable_used.emit(mid, "mana")

## Escolha do consumível (§28): monta candidatos {id, mag} da mochila e delega à seleção pura.
func _best_potion(kind: String, missing: int) -> String:
	var cands: Array = []
	for e in game_state.backpack:
		var id := str(e.get("id", ""))
		if int(e.get("qty", 0)) <= 0: continue
		var it := ItemDB.get_item(id)
		if str(it.get("cat", "")) != "consumable": continue
		var mag := int(it.get(kind, 0))
		if mag > 0: cands.append({"id": id, "mag": mag})
	return select_smallest_adequate(cands, missing)

## PURA/testável (§28): a MENOR poção que cobre `missing`; se nenhuma cobre, a MAIOR disponível (não desperdiça a
## poção maior/mais rara quando uma menor resolve). candidates = [{id, mag}].
static func select_smallest_adequate(candidates: Array, missing: int) -> String:
	var smallest_adequate := ""; var sa_mag := 2147483647
	var largest := ""; var lg_mag := 0
	for c in candidates:
		var mag := int(c.get("mag", 0))
		if mag <= 0: continue
		if mag > lg_mag: lg_mag = mag; largest = str(c.get("id", ""))
		if mag >= missing and mag < sa_mag: sa_mag = mag; smallest_adequate = str(c.get("id", ""))
	return smallest_adequate if smallest_adequate != "" else largest

func toggle() -> void: enabled = not enabled

func status() -> Dictionary:
	return {"enabled": enabled, "hp_threshold": hp_threshold, "critical_threshold": critical_threshold, "mana_threshold": mana_threshold,
		"hp_used": int(stats["hp_used"]), "mana_used": int(stats["mana_used"]), "last_id": str(stats["last_id"])}
