extends SceneTree
## PVE MAP INTEGRATION CLOSEOUT V1 — o chão pintado do Ch1/Ch2 tem de VENCER o tile legado.
## ★★★ ROOT CAUSE que isto guarda: em `Main.gd` os ramos de tile por `region_id` vinham ANTES dos
## pintados e venciam por existência de arquivo. `plains/grass.png` existe ⇒ o mapa velho ganhava.
## Agora há um ramo GENÉRICO `_region_has_painted_ground(region_id)` antes dos legados.

const PLAINS := "res://assets/tilesets/plains/ground_painted.png"
const CAVE := "res://assets/tilesets/cave/ground_painted.png"
const COAST := "res://assets/tilesets/saltwind_shore/ground_painted.png"
const NEST := "res://assets/tilesets/ancient_root_nest/ground_painted.png"

var h: TestHarness = null
var main: Node = null
var _frame := 0
var _step := 0

func _initialize() -> void:
	h = TestHarness.new()
	print("═══════════ PVE MAP INTEGRATION CLOSEOUT V1 ═══════════")
	_g_assets()
	_g_reuse_and_regression()
	# cena real: prova que o BUILDER pintado é o escolhido
	main = load("res://scenes/Main.tscn").instantiate(); root.add_child(main)
	process_frame.connect(_on_frame)

func _on_frame() -> void:
	_frame += 1
	if _step == 0 and _frame >= 8:
		_step = 1
		_g_realscene()
		_finish()

func _dim(path: String) -> Vector2:
	var t := load(path) as Texture2D
	return Vector2(t.get_width(), t.get_height()) if t != null else Vector2.ZERO

# ══════════ CH1_PAINTED_ASSET_EXISTS + CORRECT_DIMENSIONS + RUNTIME_PATH ══════════
func _g_assets() -> void:
	h.group_begin("CH1_PAINTED_ASSET", 14)
	h.check("★ CH1 ground_painted EXISTE no caminho de runtime", ResourceLoader.exists(PLAINS))
	h.check("nome literal, sem sufixo (é a chave que o runtime procura)", PLAINS.ends_with("/plains/ground_painted.png"))
	var d := _dim(PLAINS)
	h.check("★ CH1 = 2400x1600 (== _region_world_size('plains'))", d == Vector2(2400, 1600))
	h.check("CH1 carrega como Texture2D", load(PLAINS) != null)
	h.check("★ CH2 ground_painted EXISTE", ResourceLoader.exists(CAVE))
	var d2 := _dim(CAVE)
	h.check("★ CH2 = 1800x1200 (== _region_world_size('cave'))", d2 == Vector2(1800, 1200))
	h.check("CH2 carrega como Texture2D", load(CAVE) != null)
	# tiles legados PRESERVADOS (não apagar: ainda são fallback de conteúdo sem pintado)
	h.check("tile legado plains/grass.png preservado", ResourceLoader.exists("res://assets/tilesets/plains/grass.png"))
	h.check("tile legado cave/cave_floor.png preservado", ResourceLoader.exists("res://assets/tilesets/cave/cave_floor.png"))
	# Ch4/Ch5 intactos
	h.check("CH4 saltwind_shore pintado intacto", ResourceLoader.exists(COAST))
	h.check("CH5 ancient_root_nest pintado intacto", ResourceLoader.exists(NEST))
	h.check("CH4 = 2200x1300", _dim(COAST) == Vector2(2200, 1300))
	h.check("CH5 = 1700x1200", _dim(NEST) == Vector2(1700, 1200))
	h.check("★ os 4 capítulos com mapa real têm pintado", ResourceLoader.exists(PLAINS) and ResourceLoader.exists(CAVE) and ResourceLoader.exists(COAST) and ResourceLoader.exists(NEST))
	h.group_complete()

# ══════════ CH3_MAP_REUSE + LEGACY_FALLBACK_POLICY ══════════
func _g_reuse_and_regression() -> void:
	h.group_begin("CH3_REUSE_AND_POLICY", 12)
	# ★ Ch3 NÃO ganha mapa próprio: reusa MAP_PLAINS e diferencia por PERFIL
	h.check("★ Ch3 reusa MAP_PLAINS (sem mapa próprio)", HuntMapBinding.region_of("MAP_PLAINS") == "plains")
	h.check("★ NÃO existe região/tileset 'spider_grove'", not ResourceLoader.exists("res://assets/tilesets/spider_grove/ground_painted.png"))
	# diferenciação do Ch3 é por EnvironmentProfile, não por chão
	h.check("perfil PLAINS_SPIDER_GROVE existe", EnvironmentProfile.exists("PLAINS_SPIDER_GROVE"))
	h.check("perfil PLAINS_WOLF existe", EnvironmentProfile.exists("PLAINS_WOLF"))
	var pw := EnvironmentProfile.get_profile("PLAINS_WOLF")
	var ps := EnvironmentProfile.get_profile("PLAINS_SPIDER_GROVE")
	h.check("★ Ch1 e Ch3 compartilham o mesmo map_id", str(pw.get("map_id", "")) == str(ps.get("map_id", "")))
	h.check("★ mas COMPÕEM diferente (densidade)", float(pw.get("base_density", 0.0)) != float(ps.get("base_density", 0.0)))
	h.check("★ e diferem nas approach_lanes", str(pw.get("approach_lanes", [])) != str(ps.get("approach_lanes", [])))
	h.check("Ch3 é mais fechado (edge_richness maior)", float(ps.get("edge_richness", 0.0)) > float(pw.get("edge_richness", 0.0)))
	# ligações de mapa preservadas
	h.check("CH2 → cave", HuntMapBinding.region_of("MAP_CAVE") == "cave")
	h.check("CH5 → ancient_root_nest", HuntMapBinding.region_of("MAP_ROOT_NEST") == "ancient_root_nest")
	h.check("★ CH4 segue SEM região (fail loud, não aponta errado)", HuntMapBinding.region_of("MAP_SALT_COAST") == "")
	h.check("★ e o motivo do CH4 está DOCUMENTADO no código", HuntMapBinding.unresolved_map_reason("MAP_SALT_COAST").contains("WORLD_REGION_REQUIRED"))
	h.group_complete()

# ══════════ REALSCENE: o BUILDER pintado é o escolhido ══════════
func _g_realscene() -> void:
	h.group_begin("REALSCENE_MAP_CLOSEOUT", 10)
	h.check("main vivo", is_instance_valid(main))
	h.check("★ _region_has_painted_ground('plains') = TRUE", bool(main._region_has_painted_ground("plains")))
	h.check("★ _region_has_painted_ground('cave') = TRUE", bool(main._region_has_painted_ground("cave")))
	h.check("_region_has_painted_ground('saltwind_shore') = TRUE", bool(main._region_has_painted_ground("saltwind_shore")))
	h.check("_region_has_painted_ground('ancient_root_nest') = TRUE", bool(main._region_has_painted_ground("ancient_root_nest")))
	# ★★★ o teste que fecha o field: o tamanho de mundo bate com a arte ⇒ escala 1.0, pixel-perfect
	h.check("★ world size de plains == dimensão da arte", main._region_world_size("plains") == Vector2(2400, 1600))
	h.check("★ world size de cave == dimensão da arte", main._region_world_size("cave") == Vector2(1800, 1200))
	h.check("world size de saltwind_shore == arte", main._region_world_size("saltwind_shore") == Vector2(2200, 1300))
	h.check("world size de ancient_root_nest == arte", main._region_world_size("ancient_root_nest") == Vector2(1700, 1200))
	# regiões SEM pintado continuam caindo no legado (política preservada)
	h.check("★ região sem pintado ainda usa legado (política mantida)", not bool(main._region_has_painted_ground("swamp")))
	h.group_complete()

	# ★★★ O TESTE QUE FALTAVA: QUAL BUILDER RODOU DE FATO.
	# A rodada anterior passou 36 asserts e o campo continuou no mapa velho, porque eu media a
	# EXISTÊNCIA do asset e não a DECISÃO do resolvedor. `plains` tem
	# `data/map_editor_overrides/plains.json` ⇒ `_is_manifest_region` era TRUE e o manifesto vencia.
	h.group_begin("GROUND_BUILDER_DECISION", 8)
	var used: Dictionary = main.ground_builder_used
	h.check("resolvedor registrou builders", not used.is_empty())
	h.check("★★★ plains usou PAINTED (não MANIFEST, não LEGACY_TILES)", str(used.get("plains", "")) == "PAINTED")
	h.check("★ plains NÃO caiu no manifesto", str(used.get("plains", "")) != "MANIFEST")
	h.check("★ plains NÃO caiu no tile legado", str(used.get("plains", "")) != "LEGACY_TILES")
	h.check("★ cave usou PAINTED", str(used.get("cave", "")) == "PAINTED" or not used.has("cave"))
	h.check("★ Vila preservou o builder próprio", str(used.get("starter_village", "VILLAGE")) == "VILLAGE")
	h.check("★ ZERO região caiu em LEGACY_TILES", not used.values().has("LEGACY_TILES"))
	h.check("plains NÃO é manifest region (hipótese descartada)", not bool(main._is_manifest_region("plains")))
	h.group_complete()

	# ★★★ O CHÃO DA ATIVIDADE — a causa raiz de verdade.
	# O resolvedor de REGIÃO já entregava PAINTED, e mesmo assim a tela seguia quadriculada:
	# na caça quem cobre a tela é o overlay `LivingWorld`, desenhado a partir do `ground_texture`
	# do EnvironmentProfile. Ch4/Ch5 já usavam pintado; Ch1/Ch3 seguiam no tile 64×64.
	h.group_begin("ACTIVITY_GROUND_TEXTURE", 10)
	var wolf := EnvironmentProfile.get_profile("PLAINS_WOLF")
	var spider := EnvironmentProfile.get_profile("PLAINS_SPIDER_GROVE")
	var coast := EnvironmentProfile.get_profile("SALT_WIND_COAST")
	var nest := EnvironmentProfile.get_profile("ROOT_NEST")
	h.check("★★★ Ch1 (PLAINS_WOLF) usa chão PINTADO", str(wolf.get("ground_texture", "")) == EnvironmentProfile.GROUND_PLAINS_PAINTED)
	h.check("★ Ch1 NÃO usa mais o tile grass.png", str(wolf.get("ground_texture", "")) != EnvironmentProfile.GROUND_GRASS)
	h.check("★ variante do Ch1 também não é tile", str(wolf.get("ground_variant", "")) != EnvironmentProfile.GROUND_GRASS2)
	h.check("★★★ Ch3 (PLAINS_SPIDER_GROVE) usa chão PINTADO", str(spider.get("ground_texture", "")) == EnvironmentProfile.GROUND_PLAINS_PAINTED)
	h.check("★ Ch1 e Ch3 compartilham o MESMO chão (MAP REUSE §34)", str(wolf.get("ground_texture", "")) == str(spider.get("ground_texture", "")))
	h.check("a textura do Ch1/Ch3 existe de fato", ResourceLoader.exists(str(wolf.get("ground_texture", ""))))
	h.check("Ch4 segue no chão pintado da Costa", str(coast.get("ground_texture", "")) == EnvironmentProfile.GROUND_COAST)
	h.check("Ch5 segue no chão pintado do Ninho", str(nest.get("ground_texture", "")) == EnvironmentProfile.GROUND_ROOT)
	h.check("★ NENHUM perfil aponta para tile legado", not [wolf, spider, coast, nest].any(func(p): return str(p.get("ground_texture", "")) in [EnvironmentProfile.GROUND_GRASS, EnvironmentProfile.GROUND_GRASS2]))
	h.check("consts legadas preservadas (não apaguei o fallback)", EnvironmentProfile.GROUND_GRASS != "" and ResourceLoader.exists(EnvironmentProfile.GROUND_GRASS))
	h.group_complete()

func _finish() -> void:
	print("─────────────────────────────────────────────")
	var res := h.summarize("PVE MAP INTEGRATION CLOSEOUT V1")
	var art := FileAccess.open("user://pve_map_integration_closeout_v1_selftest.json", FileAccess.WRITE)
	if art != null:
		art.store_string(JSON.stringify({"suite": "PVE_MAP_INTEGRATION_CLOSEOUT_V1", "result": res, "groups": h.groups}, "\t")); art.close()
	quit(0 if bool(res["ok"]) else 1)
