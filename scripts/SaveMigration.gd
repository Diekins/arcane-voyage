class_name SaveMigration
## SaveMigration — infraestrutura REUTILIZÁVEL de migração de saves (FATIA A1.5).
##
## PROBLEMA que resolve (auditado): hoje `GameState.load_game()` faz `if schemaVersion != SAVE_SCHEMA:
## return false` → o save é IGNORADO e o PRÓXIMO `save_game()` o SOBRESCREVE com o estado default →
## **perda silenciosa** de todo o progresso num bump de schema. Também: um JSON corrompido pode ser
## sobrescrito (única cópia perdida).
##
## O que esta camada garante:
##   • lê o schema existente;
##   • migra VERSÃO POR VERSÃO (v1→v2→v3…) por passos registrados — preservando os campos existentes;
##   • BACKUP do arquivo original ANTES da 1ª migração destrutiva (e antes de qualquer sobrescrita de um
##     save problemático) — nunca apaga a única cópia;
##   • diagnóstico claro p/ JSON inválido / save mais NOVO que o cliente (não faz downgrade);
##   • pronta p/ FUTUROS bumps (basta registrar um passo em `_steps()`), SEM inflar o schema agora.
##
## ★ NÃO aumenta `SAVE_SCHEMA` artificialmente: A2 segue compatível com schema 1 → `CURRENT_VERSION = 1` e
## `_steps()` está vazio (no-op). A infraestrutura só ENTRA EM AÇÃO quando um passo real for registrado.

const CURRENT_VERSION := 10   # espelha GameState.SAVE_SCHEMA. v10 (FATIA A13): character_class/appearance/display_name/loadouts.

## Registro de passos de migração vN → v(N+1). Cada passo é um Callable(data: Dictionary) -> Dictionary
## que transforma um save da versão N na versão N+1, PRESERVANDO os campos existentes.
static func _steps() -> Dictionary:
	return {
		1: Callable(SaveMigration, "_v1_to_v2"),
		2: Callable(SaveMigration, "_v2_to_v3"),
		3: Callable(SaveMigration, "_v3_to_v4"),
		4: Callable(SaveMigration, "_v4_to_v5"),
		5: Callable(SaveMigration, "_v5_to_v6"),
		6: Callable(SaveMigration, "_v6_to_v7"),
		7: Callable(SaveMigration, "_v7_to_v8"),
		8: Callable(SaveMigration, "_v8_to_v9"),
		9: Callable(SaveMigration, "_v9_to_v10"),
	}

## v1 → v2 (FATIA A3): adiciona os campos do MURO com defaults seguros (sem muro, modo avanço). PRESERVA
## 100% dos campos v1 (só adiciona). O apply_dict do GameState também tolera a ausência, mas materializamos
## aqui p/ o save migrado ficar explícito e completo.
static func _v1_to_v2(d: Dictionary) -> Dictionary:
	if not d.has("stage_mode"): d["stage_mode"] = "advance"
	if not d.has("stage_wall_active"): d["stage_wall_active"] = false
	if not d.has("stage_fails"): d["stage_fails"] = 0
	if not d.has("stage_frontier_chapter"): d["stage_frontier_chapter"] = int(d.get("stage_chapter", 1))
	if not d.has("stage_frontier_stage"): d["stage_frontier_stage"] = int(d.get("stage_index", 1))
	if not d.has("stage_farm_chapter"): d["stage_farm_chapter"] = 1
	if not d.has("stage_farm_stage"): d["stage_farm_stage"] = 1
	return d

## v2 → v3 (FATIA A3.5): adiciona o inventário idle (locked_items + loot_overflow) com defaults vazios.
## PRESERVA 100% dos campos v2 (só adiciona). O recurso de salvage vive em `materials` (já existente).
static func _v2_to_v3(d: Dictionary) -> Dictionary:
	if not d.has("locked_items"): d["locked_items"] = []
	if not d.has("loot_overflow"): d["loot_overflow"] = []
	return d

## v3 → v4 (FATIA A5): adiciona os campos de progressão offline com defaults seguros (1º run: sem ausência).
## PRESERVA 100% dos campos v3 (só adiciona). last_seen_at=0 → no boot vira "now" sem premiar desde 1970 (§52).
static func _v3_to_v4(d: Dictionary) -> Dictionary:
	if not d.has("last_seen_at"): d["last_seen_at"] = 0
	if not d.has("offline_pending"): d["offline_pending"] = {}
	if not d.has("offline_remainder_seconds"): d["offline_remainder_seconds"] = 0.0
	return d

## v4 → v5 (FATIA A6): adiciona Prestígio/Master/Selos/recorde vitalício. PRESERVA 100% dos campos v4 (só
## adiciona). Política CONSERVADORA (§47): prestige/master = 0; Selos e watermark DERIVADOS do maior global do
## ciclo (floor((highest-1)/10)) — creditam só os Selos REAIS ganhos ao chegar onde chegou (Prestígio ainda
## exige stage≥100, então NÃO é Prestígio retroativo). lifetime_highest = max(recorde salvo, maior do ciclo).
static func _v4_to_v5(d: Dictionary) -> Dictionary:
	var chapter := int(d.get("stage_chapter", 1))
	var idx := int(d.get("stage_index", 1))
	var cyc_hi := maxi(1, int(d.get("stage_highest_global", (chapter - 1) * 10 + idx)))
	if not d.has("prestige_count"): d["prestige_count"] = 0
	if not d.has("master_level"): d["master_level"] = 0
	if not d.has("cycle_seal_high"): d["cycle_seal_high"] = PrestigeMath.seal_high_from_highest(cyc_hi)
	if not d.has("cycle_seals"): d["cycle_seals"] = PrestigeMath.seals_from_highest(cyc_hi)
	if not d.has("lifetime_highest_stage"): d["lifetime_highest_stage"] = cyc_hi
	return d

## v5 → v6 (FATIA A7): sistemas de poder. PRESERVA 100% dos campos v5 (só adiciona). Defaults conservadores:
## refino/joias vazios (nível 0); bestiário vazio (SEM kills retroativas, §62); códice — NÃO marca todo o
## catálogo: deixa o campo AUSENTE p/ o apply_dict inferir só equipped+backpack seguros (§61). claimed=0.
static func _v5_to_v6(d: Dictionary) -> Dictionary:
	if not d.has("slot_refinement"): d["slot_refinement"] = {}
	if not d.has("jewel_levels"): d["jewel_levels"] = {}
	if not d.has("bestiary"): d["bestiary"] = {}
	if not d.has("codex_claimed"): d["codex_claimed"] = 0
	# codex_discovered fica AUSENTE de propósito → apply_dict deriva equipped+backpack (não marca o catálogo inteiro).
	return d

## v6 → v7 (FATIA A7.1): ItemInstance. PRESERVA 100% dos campos v6 (só adiciona vazios). Política CONSERVADORA
## (§7/§65/§66): equipamentos legados FICAM como item-base (equipment[slot]/backpack intactos) → o pipeline usa
## a rota base (stats IDÊNTICOS ao antigo, ZERO nerf, quantidade/lock/overflow/refino/joias preservados). Não
## rola god roll grátis nem rotula legado como quality 100 — legado = "sem instância" (qualidade neutra). Novos
## drops é que viram ItemInstance com rolls.
static func _v6_to_v7(d: Dictionary) -> Dictionary:
	if not d.has("equipped_instances"): d["equipped_instances"] = {}
	if not d.has("item_instances"): d["item_instances"] = []
	if not d.has("overflow_instances"): d["overflow_instances"] = []
	if not d.has("locked_instances"): d["locked_instances"] = []
	if not d.has("refine_pity_by_slot"): d["refine_pity_by_slot"] = {}
	return d

## v7 → v8 (FATIA A7.2): pity persistente + anti-farm dos raros. PRESERVA 100% dos campos v7. Defaults 0/{}.
## `refine_high_by_slot` vazio → o pity zera no 1º recorde (comportamento correto p/ saves antigos).
## `lifetime_encounter_high` derivado do maior stage do ciclo (conservador): assim quem já é profundo NÃO
## re-ganha os raros de encontros que já cruzou (evita "colher raros retroativos" no boot). §25/§27.
static func _v7_to_v8(d: Dictionary) -> Dictionary:
	if not d.has("refine_high_by_slot"): d["refine_high_by_slot"] = {}
	if not d.has("lifetime_encounter_high"):
		var chapter := int(d.get("stage_chapter", 1))
		var idx := int(d.get("stage_index", 1))
		var hi := maxi(1, int(d.get("stage_highest_global", (chapter - 1) * 10 + idx)))
		d["lifetime_encounter_high"] = hi   # profundidade já alcançada → não regala raros retroativos
	return d

## v8 → v9 (FATIA A9): estado do NarrativeDirector. PRESERVA 100% dos campos v8 (só adiciona vazios). CONSERVADORA
## (§52/§53): NÃO infere `seen` de nível/progresso — beats de saves antigos ficam AVAILABLE (não SEEN) e o
## diretor infere SEEN em RUNTIME só de evidência real (`seen_dialogues`). Choices antigas seguem em `choices`
## (cena) e são lidas por fallback — não duplicamos aqui. quests/flags/level/stage/prestige/inventário intactos.
static func _v8_to_v9(d: Dictionary) -> Dictionary:
	if not d.has("narrative_seen"): d["narrative_seen"] = []
	if not d.has("narrative_choices"): d["narrative_choices"] = {}
	return d

## v9 → v10 (FATIA A13): adiciona identidade com defaults LEGACY. PRESERVA 100% do save (level/XP/equip/inventory/
## ItemInstances/refine/pity/Prestige/Master/narrative/offline/currencies §70). O Errante legado NÃO muda de visual
## (DEFAULT_LEGACY §72) nem de classe (LEGACY_CLASS §71) — mapeamento explícito, sem adivinhação silenciosa.
static func _v9_to_v10(d: Dictionary) -> Dictionary:
	if not d.has("character_class"): d["character_class"] = "LEGACY_CLASS"
	if not d.has("appearance"): d["appearance"] = CharacterAppearance.DEFAULT_LEGACY.duplicate(true)
	if not d.has("display_name"): d["display_name"] = "Errante"
	if not d.has("loadouts"): d["loadouts"] = []
	if not d.has("active_loadout"): d["active_loadout"] = 0
	return d

# ──────────────────────────────────────────────────────────────────────────────────────────────
# PREPARAÇÃO DE UM SAVE p/ aplicação (ponto de entrada usado pelo GameState.load_game).
# Retorna: { ok, data, version, migrated, status, note }
#   status ∈ "current" | "migrated" | "corrupt" | "newer" | "empty"
#   ok=true  → `data` pronto p/ apply_dict (na versão atual)
#   ok=false → NÃO aplicar; o arquivo problemático JÁ foi copiado p/ backup (nunca sobrescrito)
# ──────────────────────────────────────────────────────────────────────────────────────────────
static func prepare(raw_text: String, save_path: String) -> Dictionary:
	return prepare_versioned(raw_text, save_path, CURRENT_VERSION, _steps())

## Núcleo TESTÁVEL: recebe a versão-alvo e os passos como parâmetros (o self-test injeta cenários v1→vN
## sem tocar no schema real).
static func prepare_versioned(raw_text: String, save_path: String, current_version: int, steps: Dictionary) -> Dictionary:
	if raw_text.strip_edges() == "":
		return {"ok": false, "data": {}, "version": -1, "migrated": false, "status": "empty", "note": "arquivo vazio"}
	var parsed: Variant = JSON.parse_string(raw_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		# JSON corrompido → NÃO destruir: copia p/ .corrupt.bak (se ainda não existe) e diagnostica.
		backup_once(save_path, "corrupt")
		return {"ok": false, "data": {}, "version": -1, "migrated": false, "status": "corrupt", "note": "JSON inválido (não é objeto) — backup .corrupt.bak criado"}
	var data: Dictionary = parsed
	var v := int(data.get("schemaVersion", -1))
	if v < 1:
		# sem schemaVersion legível → tratamos como incompatível/desconhecido (não sobrescrever).
		backup_once(save_path, "corrupt")
		return {"ok": false, "data": {}, "version": v, "migrated": false, "status": "corrupt", "note": "schemaVersion ausente/ilegível — backup .corrupt.bak criado"}
	if v > current_version:
		# save mais NOVO que este cliente → não faz downgrade; preserva a cópia.
		backup_once(save_path, "newer_v%d" % v)
		return {"ok": false, "data": data, "version": v, "migrated": false, "status": "newer", "note": "save v%d > cliente v%d — não aplicado (sem downgrade)" % [v, current_version]}
	if v == current_version:
		return {"ok": true, "data": data, "version": v, "migrated": false, "status": "current", "note": "save na versão atual"}
	# v < current_version → MIGRAR. Backup do original ANTES da migração destrutiva.
	backup_once(save_path, "premigrate_v%d" % v)
	var migrated := migrate_with(data, v, current_version, steps)
	return {"ok": true, "data": migrated, "version": current_version, "migrated": true, "status": "migrated", "note": "migrado v%d → v%d" % [v, current_version]}

# ──────────────────────────────────────────────────────────────────────────────────────────────
# MIGRAÇÃO versão-por-versão
# ──────────────────────────────────────────────────────────────────────────────────────────────
static func migrate(data: Dictionary, from_v: int, to_v: int) -> Dictionary:
	return migrate_with(data, from_v, to_v, _steps())

## Aplica os passos from_v → to_v em sequência (v, v+1, …). Cada passo PRESERVA os campos existentes
## (só adiciona/transforma o necessário). Passo ausente p/ um salto = mantém os dados e avisa (gap).
static func migrate_with(data: Dictionary, from_v: int, to_v: int, steps: Dictionary) -> Dictionary:
	var out: Dictionary = data.duplicate(true)
	var v := from_v
	while v < to_v:
		if steps.has(v):
			var step: Callable = steps[v]
			out = step.call(out)
		else:
			push_warning("[SaveMigration] sem passo v%d→v%d — dados mantidos como estão (gap)." % [v, v + 1])
		v += 1
		out["schemaVersion"] = v
	return out

# ──────────────────────────────────────────────────────────────────────────────────────────────
# BACKUP — copia `path` p/ `path.<tag>.bak` SE a origem existe e o backup AINDA não existe (nunca
# sobrescreve a única cópia de um backup). Retorna true se criou um backup agora.
# ──────────────────────────────────────────────────────────────────────────────────────────────
static func backup_once(path: String, tag: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var bpath := "%s.%s.bak" % [path, tag]
	if FileAccess.file_exists(bpath):
		return false   # já há um backup com esta tag → NÃO sobrescrever
	var rf := FileAccess.open(path, FileAccess.READ)
	if rf == null:
		return false
	var content := rf.get_as_text()
	rf.close()
	var wf := FileAccess.open(bpath, FileAccess.WRITE)
	if wf == null:
		return false
	wf.store_string(content)
	wf.close()
	print("[SaveMigration] backup criado: %s" % bpath)
	return true
