extends SceneTree
## Self-test headless do MapLoader (EXPERIMENTAL). NÃO faz parte do boot do jogo.
## Rodar:  godot --headless --script res://scripts/MapLoaderSelfTest.gd
## Verifica parse/validação/resolução de assets/build sem crashar e referências do Studio JSON.

var _pass := 0
var _fail := 0

func _c(name: String, cond: bool, extra := "") -> void:
	if cond:
		_pass += 1
		print("PASS  ", name)
	else:
		_fail += 1
		print("FALHA ", name, ("  [" + extra + "]") if extra != "" else "")

func _has(arr: Array, sub: String) -> bool:
	for w in arr:
		if str(w).find(sub) != -1:
			return true
	return false

func _initialize() -> void:
	print("===== MapLoader self-test (MAP-LOADER-GODOT-1) =====")
	var ML: Script = load("res://scripts/MapLoader.gd")
	var ld = ML.new()

	# 1. parse + schema
	var ok: bool = ld.load_map_json("res://data/studio_sample_map.json")
	_c("parse OK", ok)
	_c("schemaVersion == 1", ld.schema_version == 1, str(ld.schema_version))

	# 2. validação mínima
	var errs: Array = ld.validate_min()
	_c("validate_min sem erros", errs.is_empty(), str(errs))

	# 3. map width/height/spawn
	_c("map size 2400x1600", ld.map_size() == Vector2(2400, 1600), str(ld.map_size()))
	_c("map spawn 520,840", ld.map_spawn() == Vector2(520, 840), str(ld.map_spawn()))

	# 4. resolução de assets
	_c("resolve relativo -> res://assets/...", ld.resolve_asset_path("tilesets/plains/grass.png") == "res://assets/tilesets/plains/grass.png")
	_c("asset válido existe em disco", ld._asset_loadable("tilesets/plains/grass.png"))
	_c("asset externo (user/outputs) ignorado", ld.resolve_asset_path("user/outputs/raw.png") == "")
	_c("asset com '..' ignorado", ld.resolve_asset_path("../fora.png") == "")
	_c("asset ausente não é loadable", not ld._asset_loadable("tilesets/plains/does_not_exist.png"))

	# 5. build não crasha + summary
	var parent := Node2D.new()
	var sum: Dictionary = ld.build_into(parent, {})
	_c("build_into retorna summary", sum is Dictionary)
	_c("objects construídos (>=4)", int(sum.get("objects", 0)) >= 4, str(sum))
	_c("blockers (>=2)", ld.blockers.size() >= 2 and int(sum.get("blockers", 0)) >= 2)
	_c("portals (>=1)", ld.portals.size() >= 1 and int(sum.get("portals", 0)) >= 1)
	_c("markers npc/service/mob construídos", int(sum.npc) >= 2 and int(sum.service) >= 1 and int(sum.mob) >= 1, str(sum))

	# 6. assets ausentes/externos viram warning (sem crash)
	_c("asset ausente gera warning", _has(ld.warnings, "does_not_exist"), str(ld.warnings))
	_c("asset externo gera warning", _has(ld.warnings, "outputs"))

	# 7. referências resolvem
	_c("npcId resolve (elder)", not ld.get_npc("elder").is_empty())
	_c("serviceId resolve (quest_board)", not ld.get_service("quest_board").is_empty())
	_c("mobId resolve (alpha_wolf)", not ld.get_mob("alpha_wolf").is_empty())
	_c("itemId resolve (wolf_fang)", not ld.get_item("wolf_fang").is_empty())

	# 8. coleções preservadas
	_c("mobs[] preservado", ld.mobs.size() == 1)
	_c("loot.items preservado", (ld.loot.get("items", []) as Array).size() == 1)
	_c("npcs/services preservados", ld.npcs.size() == 1 and ld.services.size() == 1)
	_c("assetBank preservado", ld.asset_bank.size() == 1)
	_c("quests[] preservado (com steps)", ld.quests.size() == 1 and (ld.quests[0].get("steps", []) as Array).size() == 2)

	parent.free()

	print("\n%d/%d checagens OK" % [_pass, _pass + _fail])
	if _fail > 0:
		push_error("MapLoader self-test FALHOU (%d)" % _fail)
	quit(1 if _fail > 0 else 0)
