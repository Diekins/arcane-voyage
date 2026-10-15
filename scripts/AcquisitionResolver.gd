class_name AcquisitionResolver extends RefCounted
## A22.2 — dado um item, resolve as FONTES conhecidas com disponibilidade/navegação, ordenadas de forma útil.
## Também dono do TrackedAcquisitionGoal (OWN_QUANTITY, lê o storage REAL), do AcquisitionIntent (return context)
## e do watch de boss. Tudo persistido em gs.tracked_goal / gs.acquisition_intent / gs.tracked_boss.

var gs = null
var golden: GoldenPath = null

func setup(p_gs, p_golden: GoldenPath = null) -> void:
	gs = p_gs
	golden = p_golden if p_golden != null else GoldenPath.new()
	if golden.gs == null: golden.setup(gs)

# ══════════════════════ RESOLVE ════════════════════════════════════════════════
## Fontes prontas p/ UI, ordenadas: AVAILABLE_NOW < UNLOCKED_HARDER < SCHEDULED < LOCKED < UNKNOWN.
func resolve(item_key: String) -> Array:
	var out: Array = []
	for src in ItemSourceRegistry.sources_for(item_key):
		out.append(_decorate(src))
	out.sort_custom(func(a, b): return int(a["sort"]) < int(b["sort"]))
	return out

func _decorate(src: Dictionary) -> Dictionary:
	var t := str(src["source_type"])
	var d := src.duplicate(true)
	d["available"] = false; d["sort"] = 4; d["state"] = "UNKNOWN"
	d["recommended_power"] = 0; d["nav_action"] = ""; d["reason_text"] = ""
	match t:
		ItemSourceRegistry.MOB_DROP:
			var mob: Dictionary = MobEligibility.get_mob(str(src["mob_id"]))
			d["display_name"] = str(mob.get("visual_id", src["mob_id"]))
			var ground := str(src.get("ground_id", ""))
			var g: Dictionary = HuntingGround.get_ground(ground)
			d["recommended_power"] = int(g.get("recommended_cp", 0))
			d["nav_action"] = "TARGETED_HUNT"; d["nav_ground"] = ground; d["nav_mob"] = str(src["mob_id"])
			if ground != "" and HuntingGround.is_unlocked(ground, _cp(), _stage()):
				d["available"] = true; d["sort"] = 0; d["state"] = "AVAILABLE"; d["reason_text"] = "Caça infinita disponível."
			else:
				d["sort"] = 3; d["state"] = "LOCKED"; d["reason_text"] = "Requer Power %d / progresso." % int(g.get("recommended_cp", 0))
		ItemSourceRegistry.BOSS_DROP:
			var boss_id := str(src["boss_id"])
			var b: Dictionary = BossActivityDefinition.get_boss(boss_id)
			d["display_name"] = str(b.get("display_name", boss_id))
			d["nav_action"] = "BOSS_FIGHT"; d["nav_boss"] = boss_id
			d["recommended_power"] = int(b.get("recommended_cp", b.get("boss_stats_profile", {}).get("recommended_cp", 0)))
			var unlocked := golden.boss_available(boss_id)
			var pol: Dictionary = b.get("availability_policy", {"type": BossAvailabilityPolicy.ALWAYS})
			var st := BossAvailabilityPolicy.resolve(pol, BossAvailabilityPolicy.server_now(), _boss_last_defeat(boss_id), unlocked)
			d["state"] = str(st["state"]); d["available"] = bool(st["available"]); d["reason_text"] = str(st["reason_text"])
			d["next_open_at"] = int(st.get("next_open_at", 0)); d["available_until"] = int(st.get("available_until", 0)); d["respawn_at"] = int(st.get("respawn_at", 0))
			if d["available"]: d["sort"] = 0
			elif not unlocked: d["sort"] = 3
			else: d["sort"] = 2   # SCHEDULED/RESPAWNING
		ItemSourceRegistry.MISSION_REWARD:
			var mid := str(src["mission_id"])
			var mm: Dictionary = AfkMissionDefinition.get_mission(mid)
			d["display_name"] = str(mm.get("intro_profile", {}).get("title", mid))
			d["nav_action"] = "MISSION"; d["nav_mission"] = mid
			var complete := golden.is_complete(mid)
			var repeatable := bool(mm.get("repeatable", false))
			if complete and not repeatable:
				d["available"] = false; d["sort"] = 3; d["state"] = "DONE"; d["reason_text"] = "Concluída (recompensa única)."
			elif golden.is_available(mid):
				d["available"] = true; d["sort"] = 0; d["state"] = "AVAILABLE"; d["reason_text"] = "Missão disponível."
			else:
				d["sort"] = 3; d["state"] = "LOCKED"; d["reason_text"] = "Requer missão anterior."
		ItemSourceRegistry.SALVAGE:
			d["display_name"] = "Desmontar equipamento"
			d["nav_action"] = "INVENTORY"; d["available"] = true; d["sort"] = 0; d["state"] = "AVAILABLE"
			d["reason_text"] = "Desmonte itens no inventário para obter Fragmentos."
		_:
			d["display_name"] = str(src.get("item_key", "?"))
	return d

## A22.11 — descoberta de fonte: KNOWN (já matou o mob / já possui o drop) · HINTED (drop definido, ainda não visto)
## · UNKNOWN. Reusa o Bestiário (gs.bestiary). Usar com moderação — a maioria fica KNOWN.
func discovery_state(mob_id: String) -> String:
	if gs == null: return "HINTED"
	var b: Dictionary = gs.bestiary.get(mob_id, {})
	if int(b.get("kills", 0)) > 0: return "KNOWN"
	return "HINTED"

func _cp() -> int: return PowerBudget.cp()
func _stage() -> int: return int(gs.stage_highest_global) if gs != null else 0
func _boss_last_defeat(boss_id: String) -> int:
	return int((gs.tracked_boss.get("last_defeat", {}) as Dictionary).get(boss_id, 0)) if gs != null else 0

# ══════════════════════ OWNED / GOAL (OWN_QUANTITY) ════════════════════════════
## Quantidade REAL possuída agora (material + inventário) — nunca um contador paralelo (§A22.24).
func owned(item_key: String) -> int:
	if gs == null: return 0
	return int(gs.material_count(item_key)) + int(gs.backpack_count(item_key))

func start_goal(item_key: String, desired: int, origin_system: String, origin_context_id: String = "", source: Dictionary = {}) -> Dictionary:
	var g := {"type": "OWN_QUANTITY", "item_id": item_key, "desired": maxi(1, desired),
		"start": owned(item_key), "origin_system": origin_system, "origin_context_id": origin_context_id,
		"source_selected": source, "status": "ACTIVE", "notified": false}
	gs.tracked_goal = g
	if gs.has_method("save_game"): gs.save_game()
	return g

func has_goal() -> bool: return gs != null and not gs.tracked_goal.is_empty() and str(gs.tracked_goal.get("status", "")) == "ACTIVE"

func goal_progress() -> Dictionary:
	if not has_goal(): return {"active": false}
	var g: Dictionary = gs.tracked_goal
	var have := owned(str(g["item_id"]))
	var complete := have >= int(g["desired"])
	return {"active": true, "item_id": str(g["item_id"]), "have": have, "desired": int(g["desired"]),
		"complete": complete, "origin_system": str(g.get("origin_system", "")), "origin_context_id": str(g.get("origin_context_id", ""))}

## Marca 'complete' 1× (retorna true só na 1ª vez que atinge a meta) — Hunt NÃO encerra (§A22.5).
func goal_check_complete() -> bool:
	if not has_goal(): return false
	var g: Dictionary = gs.tracked_goal
	if owned(str(g["item_id"])) >= int(g["desired"]) and not bool(g.get("notified", false)):
		g["notified"] = true; gs.tracked_goal = g
		return true
	return false

func cancel_goal() -> void:
	gs.tracked_goal = {}
	if gs.has_method("save_game"): gs.save_game()

# ══════════════════════ INTENT / RETURN CONTEXT ════════════════════════════════
func set_intent(origin_system: String, origin_context_id: String = "", item_key: String = "") -> void:
	gs.acquisition_intent = {"origin_system": origin_system, "origin_context_id": origin_context_id, "item_id": item_key}

func intent() -> Dictionary: return gs.acquisition_intent.duplicate(true) if gs != null else {}

## Alvo de retorno VÁLIDO (item/contexto ainda existe) ou fallback seguro (§A22.9 invalid origin).
func return_target() -> Dictionary:
	var it: Dictionary = intent()
	if it.is_empty(): return {"origin_system": "MAIN", "valid": false}
	var ctx := str(it.get("origin_context_id", ""))
	var sys := str(it.get("origin_system", "MAIN"))
	var valid := true
	if sys == "REFINE": valid = ItemDB.SLOT_ORDER.has(ctx) or ctx == ""    # slot ainda válido
	elif sys == "MISSION": valid = AfkMissionDefinition.exists(ctx)
	it["origin_system"] = sys if valid else "MAIN"; it["valid"] = valid
	return it

func clear_intent() -> void: gs.acquisition_intent = {}

# ══════════════════════ BOSS TRACKING ══════════════════════════════════════════
func track_boss(boss_id: String) -> void:
	gs.tracked_boss = {"boss_id": boss_id, "notified": false, "last_defeat": gs.tracked_boss.get("last_defeat", {})}
	if gs.has_method("save_game"): gs.save_game()

func is_tracking_boss() -> bool: return gs != null and str(gs.tracked_boss.get("boss_id", "")) != ""

func untrack_boss() -> void:
	var ld: Dictionary = gs.tracked_boss.get("last_defeat", {})
	gs.tracked_boss = {"last_defeat": ld}

## Boss rastreado ficou disponível com o jogo aberto? Retorna true 1× (dispara notificação in-game).
func boss_watch_check(now_unix: int = -1) -> bool:
	if not is_tracking_boss(): return false
	if now_unix < 0: now_unix = BossAvailabilityPolicy.server_now()
	var boss_id := str(gs.tracked_boss["boss_id"])
	var b: Dictionary = BossActivityDefinition.get_boss(boss_id)
	var pol: Dictionary = b.get("availability_policy", {"type": BossAvailabilityPolicy.ALWAYS})
	var st := BossAvailabilityPolicy.resolve(pol, now_unix, _boss_last_defeat(boss_id), golden.boss_available(boss_id))
	if bool(st["available"]) and not bool(gs.tracked_boss.get("notified", false)):
		gs.tracked_boss["notified"] = true
		return true
	return false

## Registra derrota do boss (para RESPAWN_TIMER) — authority-side, timestamp absoluto.
func record_boss_defeat(boss_id: String, now_unix: int = -1) -> void:
	if now_unix < 0: now_unix = BossAvailabilityPolicy.server_now()
	var ld: Dictionary = gs.tracked_boss.get("last_defeat", {})
	ld[boss_id] = now_unix
	gs.tracked_boss["last_defeat"] = ld
