class_name BossBestiary extends RefCounted
## A32 — BOSS BESTIARY / ENCOUNTER INTELLIGENCE V1. DERIVA o estado do boss do save EXISTENTE (story_flags via
## GoldenPath) — ZERO campo novo, save v10 inalterado, save antigo carrega (flag ausente ⇒ UNKNOWN). Enumera
## BossActivityDefinition.BOSSES (registry-driven, SEM `if boss == x`). NUNCA concede reward (só informa; loot =
## Direct Settlement do MissionHost). Drops derivados da MESMA fonte do ItemSourceRegistry (single truth).
## ★ spider_matriarch (BOSS_CH3_SPIDER_MATRIARCH) É boss; root_matriarch é MOB ⇒ NÃO aparece aqui.

const UNKNOWN := "UNKNOWN"
const DISCOVERED := "DISCOVERED"
const DEFEATED := "DEFEATED"

# ordem de progressão p/ sort ESTÁVEL (não depende de insertion order acidental §36)
const CHAPTER_ORDER := {"CHAPTER_1_WOLF": 1, "CHAPTER_2_CRYSTAL": 2, "CHAPTER_3_SPIDER": 3, "CHAPTER_4_SALTWIND": 4}

## Ids de boss REAIS (enabled), ordenados por capítulo e depois id estável.
static func boss_ids() -> Array:
	var ids: Array = []
	for bid in BossActivityDefinition.BOSSES:
		if bool(BossActivityDefinition.BOSSES[bid].get("enabled", true)):
			ids.append(str(bid))
	ids.sort_custom(_cmp_boss)
	return ids

static func _cmp_boss(a, b) -> bool:
	var oa := _chap_order(a); var ob := _chap_order(b)
	if oa != ob: return oa < ob
	return str(a) < str(b)

static func _chap_order(bid) -> int:
	return int(CHAPTER_ORDER.get(str(BossActivityDefinition.BOSSES.get(bid, {}).get("chapter_id", "")), 99))

## Estado de descoberta (spoiler gate): UNKNOWN (não revelar) → DISCOVERED (identidade+contexto) → DEFEATED (tudo).
## Derivado: DEFEATED se first-clear feito; DISCOVERED se disponível (unlock alcançado); senão UNKNOWN.
static func discovery_state(golden, boss_id: String) -> String:
	if golden == null or not BossActivityDefinition.exists(boss_id):
		return UNKNOWN
	if golden.boss_first_cleared(boss_id):
		return DEFEATED
	if golden.boss_available(boss_id):
		return DISCOVERED
	return UNKNOWN

static func _display(b: Dictionary) -> String:
	return str(b.get("display_name", b.get("display_name_key", b.get("boss_id", "???"))))

static func _lock_reason(b: Dictionary) -> String:
	var prev := str(b.get("unlock_rule", {}).get("prev_mission", ""))
	if prev == "":
		return "Requisito de progressão."
	return "Requer concluir: %s" % prev

## Item garantido de first-clear (por família de arma equipada; genérico se weapon_kind vazio).
static func _guaranteed_item(b: Dictionary, weapon_kind: String) -> String:
	var fc: Dictionary = b.get("reward_profile", {}).get("first_clear", {})
	if not bool(fc.get("guaranteed_gear_by_weapon", false)):
		return ""
	if weapon_kind == "":
		return ""   # sem arma conhecida → UI mostra "por família de arma"
	return BossActivityDefinition.guaranteed_gear_for_weapon(weapon_kind)

## Drops derivados do reward_profile (mesma fonte do ItemSourceRegistry). Spoiler: possible só REVELADO quando DEFEATED.
static func drops(golden, boss_id: String, weapon_kind := "") -> Dictionary:
	var b := BossActivityDefinition.get_boss(boss_id)
	var st := discovery_state(golden, boss_id)
	var out := {"guaranteed": [], "possible": [], "revealed": st == DEFEATED}
	if st == UNKNOWN:
		return out   # nada revelado
	# GUARANTEED (first-clear): visível a partir de DISCOVERED (é o objetivo do capítulo, já anunciado)
	var gi := _guaranteed_item(b, weapon_kind)
	var fc: Dictionary = b.get("reward_profile", {}).get("first_clear", {})
	if bool(fc.get("guaranteed_gear_by_weapon", false)):
		(out["guaranteed"] as Array).append({
			"item_key": gi,                        # "" ⇒ "por família de arma da classe"
			"by_weapon": true,
			"claimed": st == DEFEATED,             # first-clear já resgatado?
		})
	# POSSIBLE (repeat pool): só REVELADO após DEFEATED (senão "???")
	var rep: Dictionary = b.get("reward_profile", {}).get("repeat", {})
	for gid in rep.get("gear_pool", []):
		(out["possible"] as Array).append({
			"item_key": (str(gid) if st == DEFEATED else "???"),
			"real_key": str(gid),
			"chance": float(rep.get("gear_chance", 0.0)),
			"revealed": st == DEFEATED,
		})
	return out

## Entrada completa de boss (Encounter Intelligence). Metadata leve — NÃO instancia encounter (§50).
static func entry(golden, boss_id: String, weapon_kind := "") -> Dictionary:
	var b := BossActivityDefinition.get_boss(boss_id)
	if b.is_empty():
		return {}
	var st := discovery_state(golden, boss_id)
	var cleared := st == DEFEATED
	var avail: bool = golden != null and golden.boss_available(boss_id)
	var known := st != UNKNOWN
	return {
		"boss_id": boss_id,
		"discovery": st,
		"discovered": known,
		"defeated": cleared,
		"first_clear_complete": cleared,
		"chapter_id": str(b.get("chapter_id", "")),
		"display_name": (_display(b) if known else "???"),
		"region": (str(b.get("map_id", "")) if known else "???"),
		"recommended_cp": (int(b.get("recommended_cp", 0)) if known else 0),
		"visual_id": str(b.get("visual_id", "")),          # asset real (fallback legítimo p/ retrato)
		"available": avail,
		"availability_state": ("AVAILABLE" if avail else "LOCKED"),
		"locked_reason": ("" if avail else _lock_reason(b)),
		"best_difficulty": ("NORMAL" if cleared else ""),  # Nightmare deferred; Veteran já suportado (A40)
		"difficulties": BossActivityDefinition.difficulties_of(boss_id),   # A40 — data-driven (NORMAL[/VETERAN])
		"action": ("FIGHT" if avail else "LOCKED"),
		"drops": drops(golden, boss_id, weapon_kind),
	}

## Todas as entradas ordenadas (para a UI/lista). weapon_kind opcional p/ resolver o gear garantido.
static func all_entries(golden, weapon_kind := "") -> Array:
	var out: Array = []
	for bid in boss_ids():
		out.append(entry(golden, bid, weapon_kind))
	return out
