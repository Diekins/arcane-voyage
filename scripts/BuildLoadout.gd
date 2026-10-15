class_name BuildLoadout extends RefCounted
## FATIA A13 — LOADOUT de build (§41-49). Separado de CLASSE (§41). Guarda as 3 skills + arma/refs (§42/§43). NÃO
## inventa skills (§42): as skills vêm do skill_pool da classe (CharacterClassDefinition). FREE_LOADOUT_SLOTS=2 +
## entitlement futuro (§44). ★ LOADOUT SLOT ≠ PODER (§45): slot extra é conveniência, 0 stat/skill-extra-simultânea.
## Validação server-side (§46). No futuro trava no início do match (§49) — foundation só define o contrato.

const FREE_LOADOUT_SLOTS := 2

## Cria um loadout. weapon_family = família (sword/bow/...) permitida pela classe; skills do pool.
static func new_loadout(loadout_id: String, name: String, class_id: String, weapon_family: String, s1: String, s2: String, s3: String) -> Dictionary:
	return {"loadout_id": loadout_id, "name": name, "class_id": class_id, "weapon_family": weapon_family, "skill_1": s1, "skill_2": s2, "skill_3": s3, "passive": ""}

## Loadout inicial de uma classe (3 primeiras skills do pool, arma inicial).
static func default_for_class(class_id: String) -> Dictionary:
	var d := CharacterClassDefinition.get_def(class_id)
	var pool: Array = d.get("skill_pool", [])
	var fam := ""
	var fams: Array = d.get("allowed_weapon_families", [])
	if fams.size() > 0: fam = str(fams[0])
	return new_loadout("LO_DEFAULT", "Default", class_id, fam,
		str(pool[0]) if pool.size() > 0 else "", str(pool[1]) if pool.size() > 1 else "", str(pool[2]) if pool.size() > 2 else "")

## Valida um loadout contra a classe do character (§46). Retorna {ok} ou {ok:false, reason}.
static func validate(loadout: Dictionary, class_id: String) -> Dictionary:
	if str(loadout.get("class_id", "")) != class_id:
		return {"ok": false, "reason": "WRONG_CLASS"}                      # §91 LOAD-T04
	var fam := str(loadout.get("weapon_family", ""))
	if fam != "" and not CharacterClassDefinition.weapon_allowed(class_id, fam):
		return {"ok": false, "reason": "WEAPON_NOT_ALLOWED"}              # §91 LOAD-T05
	var skills := [str(loadout.get("skill_1", "")), str(loadout.get("skill_2", "")), str(loadout.get("skill_3", ""))]
	var seen := {}
	for sk in skills:
		if sk == "":
			return {"ok": false, "reason": "MISSING_SKILL"}              # §43 três slots
		if not CharacterClassDefinition.skill_in_pool(class_id, sk):
			return {"ok": false, "reason": "SKILL_NOT_IN_POOL"}          # §91 LOAD-T03
		if seen.has(sk):
			return {"ok": false, "reason": "DUPLICATE_SKILL"}           # §46 sem skill duplicada
		seen[sk] = true
	return {"ok": true}

## Slot cap de loadout de uma conta = livre + entitlement (§44). Extra = conveniência, 0 poder (§45).
static func slot_cap(loadout_entitlements: int) -> int:
	return FREE_LOADOUT_SLOTS + maxi(0, loadout_entitlements)

## Poder de combate de um slot extra = SEMPRE 0 (§45).
static func slot_combat_power() -> int:
	return 0
