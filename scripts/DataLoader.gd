extends Node
## DataLoader (autoload) — carrega os JSON canônicos exportados e valida o schemaVersion.
##
## Fonte: res://data/canonical/ (cópia gerada por `npm run export:canonical`; NÃO editar à mão).
## Expõe dicionários indexados por id. É o equivalente Godot dos catálogos TS do protótipo web.

const DATA_DIR := "res://data/canonical/"
const EXPECTED_SCHEMA := 1

var loaded := false
var manifest := {}
var scenes_ordered := []    # dialogue_scenes.json NA ORDEM (o dispatcher itera isto)
var scenes_by_id := {}      # dialogue_scenes.json: id -> cena
var npcs_by_id := {}        # npcs.json: id -> npc
var acts := []              # campaign_acts.json
var quests_by_id := {}      # campaign_quests.json: id -> quest
var bosses := []            # bosses.json (na ordem)
var bosses_by_id := {}      # bosses.json: id -> boss
var relics := []            # relics.json (na ordem)
var relics_by_id := {}      # relics.json: id -> relic
var regions := []           # regions.json (na ordem)
var regions_by_id := {}     # regions.json: id -> region

func _ready() -> void:
	_load_all()

func _load_json(file_name: String) -> Variant:
	var path := DATA_DIR + file_name
	if not FileAccess.file_exists(path):
		push_error("[DataLoader] Arquivo ausente: %s — rode 'npm run export:canonical' e copie para %s" % [path, DATA_DIR])
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("[DataLoader] Não consegui abrir: %s" % path)
		return null
	var text := f.get_as_text()
	f.close()
	var data: Variant = JSON.parse_string(text)
	if data == null:
		push_error("[DataLoader] JSON inválido: %s" % path)
	return data

func _load_all() -> void:
	manifest = _load_json("manifest.json")
	if typeof(manifest) != TYPE_DICTIONARY:
		push_error("[DataLoader] manifest.json ausente/ inválido — abortando load.")
		return
	var sv := int(manifest.get("schemaVersion", -1))
	if sv != EXPECTED_SCHEMA:
		push_error("[DataLoader] schemaVersion %d != esperado %d. Regenere o export." % [sv, EXPECTED_SCHEMA])
		return

	var scenes: Variant = _load_json("dialogue_scenes.json")
	if scenes is Array:
		scenes_ordered = scenes
		for s in scenes:
			scenes_by_id[s["id"]] = s
	var npcs: Variant = _load_json("npcs.json")
	if npcs is Array:
		for n in npcs:
			npcs_by_id[n["id"]] = n
	var a: Variant = _load_json("campaign_acts.json")
	if a is Array:
		acts = a
	var q: Variant = _load_json("campaign_quests.json")
	if q is Array:
		for item in q:
			quests_by_id[item["id"]] = item
	var bs: Variant = _load_json("bosses.json")
	if bs is Array:
		bosses = bs
		for boss in bs:
			bosses_by_id[boss["id"]] = boss
	var rl: Variant = _load_json("relics.json")
	if rl is Array:
		relics = rl
		for relic in rl:
			relics_by_id[relic["id"]] = relic
	var rg: Variant = _load_json("regions.json")
	if rg is Array:
		regions = rg
		for region in rg:
			regions_by_id[region["id"]] = region

	loaded = true
	print("[DataLoader] OK — schemaVersion=%d | %d cenas, %d npcs, %d atos, %d quests, %d bosses, %d relíquias, %d regiões" % [
		sv, scenes_by_id.size(), npcs_by_id.size(), acts.size(), quests_by_id.size(), bosses_by_id.size(), relics_by_id.size(), regions_by_id.size()
	])

## --- acessadores ---

func scene(id: String) -> Dictionary:
	return scenes_by_id.get(id, {})

func npc(id: String) -> Dictionary:
	return npcs_by_id.get(id, {})

func quest(id: String) -> Dictionary:
	return quests_by_id.get(id, {})

func boss(id: String) -> Dictionary:
	return bosses_by_id.get(id, {})

func relic(id: String) -> Dictionary:
	return relics_by_id.get(id, {})

func region(id: String) -> Dictionary:
	return regions_by_id.get(id, {})

## Resolve uma relíquia pelo NOME (case-insensitive) — usado p/ casar `narrativeReward.ref`.
func relic_by_name(name: String) -> Dictionary:
	var target := name.to_lower()
	for r in relics:
		if str(r.get("name", "")).to_lower() == target:
			return r
	return {}

## Busca o `narrativeReward` do capítulo (campaign_acts) cujo `questId` casa. {} se não houver.
func narrative_reward_for_quest(quest_id: String) -> Dictionary:
	for act in acts:
		for ch in act.get("chapters", []):
			if str(ch.get("questId", "")) == quest_id:
				var nr: Variant = ch.get("narrativeReward", null)
				if nr is Dictionary:
					return nr
	return {}

## Resolve um narrativeReward → id de relíquia (via `ref` = nome). "" se não casar (sem reward).
func relic_id_for_reward(reward: Dictionary) -> String:
	var ref := str(reward.get("ref", ""))
	if ref == "":
		return ""
	var r := relic_by_name(ref)
	return str(r.get("id", "")) if not r.is_empty() else ""

## "/assets/npcs/x.png" (imageUrl do export) -> "res://assets/npcs/x.png".
## Retorna "" se o NPC não tiver retrato real.
func npc_portrait_res(npc_id: String) -> String:
	var n: Dictionary = npcs_by_id.get(npc_id, {})
	var url: String = str(n.get("imageUrl", ""))
	if url == "":
		return ""
	return "res://assets" + url
