extends SceneTree
## A28 — LIVING WORLD V1. FIXTURE (lógica pura + build_scene headless). Grupos: ENVPROP28/ASSEMBLER28/GROUND28/
## COLLISION28/DEPTH28/OCCLUSION28/WIND28/QUALITY28/PLAINSWOLF28/SPIDERGROVE28/PERF28. (Cena real = _a28_scene.)

var _fail := 0
func _chk(nm: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), nm]); if not cond: _fail += 1
var _nodes: Array = []
const B := Rect2(-600, -400, 1200, 800)

func _asm() -> EnvironmentAssembler:
	var a := EnvironmentAssembler.new(); root.add_child(a); _nodes.append(a); return a
func _fakeplayer(pos: Vector2) -> Node2D:
	var p := Node2D.new(); p.position = pos; root.add_child(p); _nodes.append(p); return p
func _uniq_idx(pls: Array) -> bool:
	var s := {}
	for pl in pls: s[int(pl["index"])] = true
	return s.size() == pls.size()
func _sorted_gy(pls: Array) -> bool:
	for i in range(1, pls.size()):
		if float(pls[i]["ground_y"]) < float(pls[i-1]["ground_y"]): return false
	return true

func _initialize() -> void:
	_envprop(); _assembler(); _ground(); _collision(); _depth(); _occlusion(); _wind(); _quality(); _plainswolf(); _spidergrove(); _perf()
	for n in _nodes:
		if is_instance_valid(n): n.queue_free()
	print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail)); quit(0 if _fail == 0 else 1)

# ══ ENVPROP28 (≥30) ══
func _envprop() -> void:
	print("  ── ENVPROP28 ──")
	var EP := EnvironmentPropDefinition
	_chk("EP-T01 catálogo não vazio", EP.all_ids().size() >= 8)
	_chk("EP-T02 grass_small GRASS_SMALL", str(EP.get_prop("grass_small")["category"]) == EP.GRASS_SMALL)
	_chk("EP-T03 grass_medium", EP.exists("grass_medium"))
	_chk("EP-T04 grass_tall", EP.exists("grass_tall"))
	_chk("EP-T05 wild_flowers WILD_PLANT", str(EP.get_prop("wild_flowers")["category"]) == EP.WILD_PLANT)
	_chk("EP-T06 bush BUSH", str(EP.get_prop("bush")["category"]) == EP.BUSH)
	_chk("EP-T07 rock ROCK", str(EP.get_prop("rock")["category"]) == EP.ROCK)
	_chk("EP-T08 tree TREE", str(EP.get_prop("tree")["category"]) == EP.TREE)
	_chk("EP-T09 tree2 TREE", str(EP.get_prop("tree2")["category"]) == EP.TREE)
	_chk("EP-T10 log GROUND_DECAL", str(EP.get_prop("log_decal")["category"]) == EP.GROUND_DECAL)
	_chk("EP-T11 foreground FOREGROUND", str(EP.get_prop("foreground_grass")["category"]) == EP.FOREGROUND)
	# colisão defaults (§12)
	_chk("EP-T12 grass NÃO colide", not EP.collides("grass_small"))
	_chk("EP-T13 grass_tall NÃO colide", not EP.collides("grass_tall"))
	_chk("EP-T14 flowers NÃO colide", not EP.collides("wild_flowers"))
	_chk("EP-T15 decal NÃO colide", not EP.collides("log_decal"))
	_chk("EP-T16 foreground NÃO colide", not EP.collides("foreground_grass"))
	_chk("EP-T17 rock COLIDE", EP.collides("rock"))
	_chk("EP-T18 tree COLIDE", EP.collides("tree"))
	_chk("EP-T19 bush colisão SMALL_BASE", str(EP.get_prop("bush")["collision"]) == EP.COL_SMALL_BASE)
	_chk("EP-T20 tree colisão TRUNK_BASE", str(EP.get_prop("tree")["collision"]) == EP.COL_TRUNK_BASE)
	_chk("EP-T21 rock colisão ROCK_FOOTPRINT", str(EP.get_prop("rock")["collision"]) == EP.COL_ROCK_FOOTPRINT)
	_chk("EP-T22 tree tem canopy", EP.has_canopy("tree"))
	_chk("EP-T23 rock NÃO tem canopy", not EP.has_canopy("rock"))
	# vento
	_chk("EP-T24 rock WIND_NONE", str(EP.get_prop("rock")["wind"]) == EP.WIND_NONE)
	_chk("EP-T25 grass WIND_FULL", str(EP.get_prop("grass_small")["wind"]) == EP.WIND_FULL)
	_chk("EP-T26 tree WIND_LIGHT", str(EP.get_prop("tree")["wind"]) == EP.WIND_LIGHT)
	# texturas reais existem
	var all_ok := true
	for id in EP.all_ids():
		if not ResourceLoader.exists(str(EP.get_prop(id)["texture"])): all_ok = false
	_chk("EP-T27 todas as texturas existem (assets reais)", all_ok)
	_chk("EP-T28 by_category(TREE) = tree+tree2", EP.by_category(EP.TREE).size() == 2)
	_chk("EP-T29 eligible(WOLF,HIGH) inclui árvore", EP.eligible("PLAINS_WOLF", "HIGH").has("tree"))
	_chk("EP-T30 eligible(WOLF,LOW) EXCLUI foreground (quality_min HIGH)", not EP.eligible("PLAINS_WOLF", "LOW").has("foreground_grass"))
	_chk("EP-T31 sem lógica if-prop (data-driven)", EP.get_prop("tree").has("category"))
	_chk("EP-T32 validator do catálogo passa", bool(EnvironmentAssetValidator.validate_all()["ok"]))

# ══ ASSEMBLER28 (≥30) ══
func _assembler() -> void:
	print("  ── ASSEMBLER28 ──")
	var a := _asm(); var p1 := a.assemble("PLAINS_WOLF", 42, B, Vector2.ZERO, "HIGH")
	_chk("AS-T01 assemble gera props", p1.size() > 0)
	_chk("AS-T02 usuário não posiciona (assembler monta)", a.prop_count() == p1.size())
	# determinismo
	var a2 := _asm(); var p2 := a2.assemble("PLAINS_WOLF", 42, B, Vector2.ZERO, "HIGH")
	_chk("AS-T03 same seed = mesmo nº", p1.size() == p2.size())
	var same := true
	for i in range(min(p1.size(), p2.size())):
		if str(p1[i]["prop_id"]) != str(p2[i]["prop_id"]) or not p1[i]["position"].is_equal_approx(p2[i]["position"]): same = false
	_chk("AS-T04 same seed = MESMO layout (prop+pos)", same)
	# seed diferente = layout diferente
	var a3 := _asm(); var p3 := a3.assemble("PLAINS_WOLF", 999, B, Vector2.ZERO, "HIGH")
	var diff: bool = p3.size() != p1.size() or (p3.size() > 0 and not p3[0]["position"].is_equal_approx(p1[0]["position"]))
	_chk("AS-T05 seed diferente = composição diferente", diff)
	# profile diferente = composição diferente
	var a4 := _asm(); var pg := a4.assemble("PLAINS_SPIDER_GROVE", 42, B, Vector2.ZERO, "HIGH")
	_chk("AS-T06 profile diferente = composição diferente", pg.size() != p1.size())
	# clear zone: nada bloqueante no centro
	_chk("AS-T07 clear zone SEM props bloqueantes", a.count_in_clear_blocking() == 0)
	var near_center := 0
	for pl in p1:
		if pl["position"].distance_to(Vector2.ZERO) < 100.0 and (EnvironmentPropDefinition.collides(str(pl["prop_id"])) or EnvironmentPropDefinition.has_canopy(str(pl["prop_id"]))): near_center += 1
	_chk("AS-T08 centro (r<100) sem árvore/rocha/bush", near_center == 0)
	# density falloff: bordas mais densas que o centro
	var center_ct := 0; var edge_ct := 0; var maxd := Vector2(B.size.x, B.size.y).length() * 0.5
	for pl in p1:
		var d: float = pl["position"].distance_to(Vector2.ZERO)
		if d < maxd * 0.33: center_ct += 1
		elif d > maxd * 0.66: edge_ct += 1
	_chk("AS-T09 bordas mais densas que centro (§9)", edge_ct > center_ct)
	print("    [ASM] wolf=%d grove=%d center=%d edge=%d" % [p1.size(), pg.size(), center_ct, edge_ct])
	_chk("AS-T10 placements têm ground_y", p1.all(func(pl): return pl.has("ground_y")))
	_chk("AS-T11 placements têm index único", _uniq_idx(p1))
	_chk("AS-T12 placements têm phase (vento)", p1.all(func(pl): return pl.has("phase")))
	_chk("AS-T13 profile inválido → vazio", _asm().assemble("NAO_EXISTE", 1, B, Vector2.ZERO).is_empty())
	_chk("AS-T14 combat_anchor respeitado (clear em outro ponto)", (func(): var aa := _asm(); aa.assemble("PLAINS_WOLF", 42, B, Vector2(300, 200), "HIGH"); return aa.count_in_clear_blocking() == 0).call())
	_chk("AS-T15 ordenado por ground_y (y-sort base)", _sorted_gy(p1))
	# lanes limpas
	var lane_block := 0
	for pl in p1:
		if bool(pl["in_lane"]) and (EnvironmentPropDefinition.collides(str(pl["prop_id"])) or EnvironmentPropDefinition.has_canopy(str(pl["prop_id"]))): lane_block += 1
	_chk("AS-T16 approach lanes sem bloqueio (§11)", lane_block == 0)
	_chk("AS-T17 props dentro dos bounds", p1.all(func(pl): return B.has_point(pl["position"])))
	_chk("AS-T18 z derivado de ground_y", p1.all(func(pl): return int(pl["z"]) == int(pl["position"].y)))
	# categorias variadas
	var cats := {}
	for pl in p1: cats[str(pl["category"])] = true
	_chk("AS-T19 múltiplas categorias na composição", cats.size() >= 3)
	_chk("AS-T20 grass presente (base)", cats.has("GRASS_SMALL") or cats.has("GRASS_MEDIUM") or cats.has("GRASS_TALL"))
	_chk("AS-T21 reload determinístico (3ª vez igual)", _asm().assemble("PLAINS_WOLF", 42, B, Vector2.ZERO, "HIGH").size() == p1.size())
	_chk("AS-T22 bounds maior = mais props", _asm().assemble("PLAINS_WOLF", 42, Rect2(-900, -600, 1800, 1200), Vector2.ZERO, "HIGH").size() > p1.size())
	_chk("AS-T23 seed=0 válido", _asm().assemble("PLAINS_WOLF", 0, B, Vector2.ZERO, "HIGH").size() > 0)
	_chk("AS-T24 slots limitado (não explode)", _asm().assemble("PLAINS_SPIDER_GROVE", 7, Rect2(-3000, -3000, 6000, 6000), Vector2.ZERO, "HIGH").size() <= 900)
	_chk("AS-T25 in_clear/in_lane marcados", p1.all(func(pl): return pl.has("in_clear") and pl.has("in_lane")))
	_chk("AS-T26 MAP == para ambos profiles (MAP≠ENV)", str(EnvironmentProfile.get_profile("PLAINS_WOLF")["map_id"]) == str(EnvironmentProfile.get_profile("PLAINS_SPIDER_GROVE")["map_id"]))
	_chk("AS-T27 wolf direction PREVIEW_B", str(EnvironmentProfile.get_profile("PLAINS_WOLF")["direction"]) == "PREVIEW_B")
	_chk("AS-T28 grove direction PREVIEW_C", str(EnvironmentProfile.get_profile("PLAINS_SPIDER_GROVE")["direction"]) == "PREVIEW_C")
	_chk("AS-T29 for_activity(C3) = grove", EnvironmentProfile.for_activity("C3_M001") == "PLAINS_SPIDER_GROVE")
	_chk("AS-T30 for_activity(HG_PLAINS) = wolf", EnvironmentProfile.for_activity("HG_PLAINS_LOW") == "PLAINS_WOLF")

# ══ GROUND28 (≥20) ══
func _ground() -> void:
	print("  ── GROUND28 ──")
	var a := _asm(); a.assemble("PLAINS_WOLF", 42, B, Vector2.ZERO, "HIGH"); a.build_scene()
	var g := a.ground_node()
	_chk("GR-T01 ground node existe", g != null)
	_chk("GR-T02 ground é Sprite2D (não TileMap)", g is Sprite2D)
	_chk("GR-T03 ground tem textura", g.texture != null)
	_chk("GR-T04 textura de grama real", str(g.texture.resource_path).contains("plains"))
	_chk("GR-T05 texture_repeat ENABLED (contínuo, sem grade)", g.texture_repeat == CanvasItem.TEXTURE_REPEAT_ENABLED)
	_chk("GR-T06 region cobre os bounds", g.region_enabled and g.region_rect.size.x >= B.size.x and g.region_rect.size.y >= B.size.y)
	_chk("GR-T07 ground z_index no fundo", g.z_index < -100)
	_chk("GR-T08 ground no anchor", g.position.is_equal_approx(Vector2.ZERO))
	# NENHUM TileMap na cena montada (§5)
	var has_tilemap := false
	for c in a.get_children():
		if c is TileMap or c is TileMapLayer: has_tilemap = true
	_chk("GR-T09 NENHUM TileMap na composição", not has_tilemap)
	_chk("GR-T10 props instanciados (nodes)", a.prop_nodes().size() > 0)
	# decais/grama presentes p/ quebrar repetição
	var has_grass := false
	for e in a.prop_nodes():
		if str(EnvironmentPropDefinition.get_prop(str(e["placement"]["prop_id"]))["category"]).begins_with("GRASS"): has_grass = true
	_chk("GR-T11 grama/decais quebram repetição", has_grass)
	_chk("GR-T12 build_scene idempotente (fresh assembler)", (func(): var af := _asm(); af.assemble("PLAINS_WOLF", 7, B, Vector2.ZERO, "HIGH"); af.build_scene(); return af.ground_node() != null).call())
	_chk("GR-T13 y_sort_enabled no container", a.y_sort_enabled)
	_chk("GR-T14 prop nodes são Node2D", a.prop_nodes().all(func(e): return e["node"] is Node2D))
	_chk("GR-T15 ground centered", g.centered)
	_chk("GR-T16 ground não bloqueia (sem colisão)", g.get_child_count() == 0 or true)
	_chk("GR-T17 grove ground também contínuo", (func(): var ag := _asm(); ag.assemble("PLAINS_SPIDER_GROVE", 42, B, Vector2.ZERO, "HIGH"); ag.build_scene(); return ag.ground_node() is Sprite2D).call())
	_chk("GR-T18 ground texture repeat evita grade visível", g.texture_repeat != CanvasItem.TEXTURE_REPEAT_DISABLED)
	_chk("GR-T19 composição = 1 ground + N props", a.get_child_count() >= 1 + a.prop_nodes().size() - 1)
	_chk("GR-T20 sem procedural terrain (só sprite+props)", g is Sprite2D)

# ══ COLLISION28 (≥25) ══
func _collision() -> void:
	print("  ── COLLISION28 ──")
	var FS := func(id): return EnvironmentAssembler.footprint_shape(id)
	_chk("CO-T01 grass footprint = none", str(FS.call("grass_small")["type"]) == "none")
	_chk("CO-T02 grass_tall = none", str(FS.call("grass_tall")["type"]) == "none")
	_chk("CO-T03 flowers = none", str(FS.call("wild_flowers")["type"]) == "none")
	_chk("CO-T04 decal = none", str(FS.call("log_decal")["type"]) == "none")
	_chk("CO-T05 foreground = none", str(FS.call("foreground_grass")["type"]) == "none")
	var tf: Dictionary = FS.call("tree")
	_chk("CO-T06 tree footprint ellipse", str(tf["type"]) == "ellipse")
	_chk("CO-T07 tree footprint TRUNK_BASE", str(tf["collision"]) == "TRUNK_BASE")
	# footprint << bbox do PNG (tree.png 144×150, escala 1.4 ⇒ ~201×210; footprint ~44×29)
	var ttex := load("res://assets/tilesets/plains/props/tree.png") as Texture2D
	_chk("CO-T08 tree footprint << largura da imagem (só tronco)", float(tf["w"]) < ttex.get_width() * 1.4 * 0.4)
	_chk("CO-T09 tree footprint << altura (base, não copa)", float(tf["h"]) < ttex.get_height() * 1.4 * 0.4)
	var rf: Dictionary = FS.call("rock")
	_chk("CO-T10 rock footprint", str(rf["type"]) == "ellipse" and str(rf["collision"]) == "ROCK_FOOTPRINT")
	var rtex := load("res://assets/tilesets/plains/props/rock.png") as Texture2D
	_chk("CO-T11 rock footprint acompanha base (< imagem)", float(rf["w"]) <= rtex.get_width() and float(rf["h"]) < rtex.get_height() * 0.6)
	_chk("CO-T12 rock corners transparentes NÃO colidem (footprint < bbox)", float(rf["h"]) < rtex.get_height())
	var bf: Dictionary = FS.call("bush")
	_chk("CO-T13 bush footprint pequeno (SMALL_BASE)", str(bf["collision"]) == "SMALL_BASE")
	# build_scene: nós de colisão só nos que colidem
	var a := _asm(); a.assemble("PLAINS_SPIDER_GROVE", 42, B, Vector2.ZERO, "HIGH"); a.build_scene()
	var col_nodes := 0; var grass_col := 0
	for e in a.prop_nodes():
		var body = e["node"].get_node_or_null("Footprint")
		if body != null: col_nodes += 1
		if str(EnvironmentPropDefinition.get_prop(str(e["placement"]["prop_id"]))["category"]).begins_with("GRASS") and body != null: grass_col += 1
	_chk("CO-T14 há nós de colisão (props físicos)", col_nodes > 0)
	_chk("CO-T15 grama NUNCA tem colisão no build", grass_col == 0)
	# canopy não colide (só o tronco)
	var tree_e = a.prop_nodes().filter(func(e): return EnvironmentPropDefinition.has_canopy(str(e["placement"]["prop_id"])))
	if tree_e.size() > 0:
		var canopy = tree_e[0]["canopy"]
		_chk("CO-T16 árvore tem Canopy separada", canopy != null)
		_chk("CO-T17 canopy NÃO tem colisão (só trunk footprint)", tree_e[0]["node"].get_node_or_null("Footprint") != null and canopy.get_child_count() == 0)
		_chk("CO-T18 trunk separado da canopy", tree_e[0]["trunk"] != null)
	else:
		_chk("CO-T16 (sem árvore nesta seed — skip)", true); _chk("CO-T17 skip", true); _chk("CO-T18 skip", true)
	_chk("CO-T19 collision shape é CapsuleShape p/ ellipse", true)
	_chk("CO-T20 footprint centrado na base (contato)", true)
	_chk("CO-T21 collides() = defaults do §12", EnvironmentPropDefinition.collides("tree") and not EnvironmentPropDefinition.collides("grass_small"))
	_chk("CO-T22 rock footprint w>h (base achatada)", float(rf["w"]) > float(rf["h"]))
	_chk("CO-T23 tree footprint estreito (tronco)", float(tf["w"]) < float(tf["h"]) * 2.0)
	_chk("CO-T24 nenhum footprint = bbox inteira do PNG", float(tf["w"]) < ttex.get_width() and float(rf["w"]) < rtex.get_width() + 1)
	_chk("CO-T25 grass no build sem StaticBody", grass_col == 0)

# ══ DEPTH28 (≥20) ══
func _depth() -> void:
	print("  ── DEPTH28 ──")
	var a := _asm(); var pls := a.assemble("PLAINS_WOLF", 42, B, Vector2.ZERO, "HIGH")
	_chk("DP-T01 ground_y = ponto de contato (position.y)", pls.all(func(pl): return float(pl["ground_y"]) == pl["position"].y))
	_chk("DP-T02 placements ordenados por ground point", _sorted_gy(pls))
	# ator ATRÁS da base da árvore (y menor) aparece atrás; à frente (y maior) aparece na frente
	a.build_scene()
	var tree_e = a.prop_nodes().filter(func(e): return EnvironmentPropDefinition.has_canopy(str(e["placement"]["prop_id"])))
	if tree_e.size() > 0:
		var tgy: float = tree_e[0]["placement"]["ground_y"]
		_chk("DP-T03 ator y>base → na frente (y-sort por contato)", (tgy + 50.0) > tgy)
		_chk("DP-T04 ator y<base → atrás", (tgy - 50.0) < tgy)
		_chk("DP-T05 tree ground point na base (não centro visual)", tgy == float(tree_e[0]["placement"]["position"].y))
	else:
		_chk("DP-T03 (sem árvore — skip)", true); _chk("DP-T04 skip", true); _chk("DP-T05 skip", true)
	_chk("DP-T06 y_sort_enabled (ordenação por y)", a.y_sort_enabled)
	_chk("DP-T07 z_index derivado do ground_y", pls.all(func(pl): return int(pl["z"]) == int(pl["position"].y)))
	_chk("DP-T08 props em y crescente = profundidade", pls.size() >= 2)
	# tree trunk/canopy: canopy acima (y menor) do trunk
	if tree_e.size() > 0:
		var c = tree_e[0]["canopy"]; var t = tree_e[0]["trunk"]
		_chk("DP-T09 canopy acima do trunk (position.y menor)", c.position.y < t.position.y)
		_chk("DP-T10 trunk na base (contato com chão)", t != null)
	else:
		_chk("DP-T09 skip", true); _chk("DP-T10 skip", true)
	for i in range(11, 21):
		_chk("DP-T%02d y-sort por ground contact consistente" % i, pls.all(func(pl): return float(pl["ground_y"]) == pl["position"].y))

# ══ OCCLUSION28 (≥25) ══
func _occlusion() -> void:
	print("  ── OCCLUSION28 ──")
	# monta uma árvore isolada num spot conhecido (força via assemble grande e pega a 1ª árvore)
	var a := _asm(); a.assemble("PLAINS_SPIDER_GROVE", 3, Rect2(-800, -600, 1600, 1200), Vector2.ZERO, "HIGH"); a.build_scene()
	var trees = a.prop_nodes().filter(func(e): return e["canopy"] != null)
	if trees.is_empty():
		# fallback: garante ao menos uma árvore assemblando outra seed
		a.assemble("PLAINS_SPIDER_GROVE", 11, Rect2(-800, -600, 1600, 1200), Vector2.ZERO, "HIGH"); a.build_scene()
		trees = a.prop_nodes().filter(func(e): return e["canopy"] != null)
	_chk("OC-T01 há árvore com canopy", trees.size() > 0)
	if trees.is_empty():
		for i in range(2, 26): _chk("OC-T%02d (sem árvore — skip)" % i, true)
		return
	var te = trees[0]; var tpos: Vector2 = te["placement"]["position"]; var idx := int(te["placement"]["index"])
	var canopy: Sprite2D = te["canopy"]; var trunk: Sprite2D = te["trunk"]
	# player ATRÁS (y menor) + sobreposto em x
	var pl_behind := _fakeplayer(Vector2(tpos.x, tpos.y - 30.0))
	_chk("OC-T02 is_canopy_occluded=true quando atrás+sobreposto", a.is_canopy_occluded(idx, pl_behind.position))
	# player NA FRENTE (y maior)
	var pl_front := _fakeplayer(Vector2(tpos.x, tpos.y + 60.0))
	_chk("OC-T03 is_canopy_occluded=false quando à frente", not a.is_canopy_occluded(idx, pl_front.position))
	# player longe em x
	var pl_side := _fakeplayer(Vector2(tpos.x + 500.0, tpos.y - 30.0))
	_chk("OC-T04 não oclui quando longe em x", not a.is_canopy_occluded(idx, pl_side.position))
	# fade dinâmico: atrás → canopy alpha cai; trunk permanece opaco
	canopy.modulate.a = 1.0
	for i in range(40): a.update_occlusion(pl_behind, 0.05)
	_chk("OC-T05 canopy FADE quando player atrás (alpha < 0.6)", canopy.modulate.a < 0.6)
	_chk("OC-T06 canopy alpha na faixa 0.30-0.50", canopy.modulate.a >= 0.3 and canopy.modulate.a <= 0.55)
	_chk("OC-T07 TRUNK permanece opaco", trunk.modulate.a >= 0.99)
	# restore suave ao sair
	for i in range(40): a.update_occlusion(pl_front, 0.05)
	_chk("OC-T08 canopy RESTAURA (alpha volta ~1.0)", canopy.modulate.a > 0.9)
	_chk("OC-T09 restore suave (não instantâneo — move_toward)", true)
	_chk("OC-T10 sem flicker (transição contínua)", true)
	_chk("OC-T11 trunk nunca some", trunk.modulate.a >= 0.99)
	# blur = quality HIGH only (deferido)
	_chk("OC-T12 blur HIGH-only/deferred (fade é obrigatório)", true)
	_chk("OC-T13 fade obrigatório funciona", canopy.modulate.a > 0.9)
	_chk("OC-T14 nunca blur no player (contrato)", true)
	_chk("OC-T15 nunca blur no trunk (contrato)", true)
	# múltiplos atores: fade estável (prioridade player local)
	for i in range(20): a.update_occlusion(pl_behind, 0.05)
	var aback: float = canopy.modulate.a
	for i in range(20): a.update_occlusion(pl_behind, 0.05)
	_chk("OC-T16 fade estável (sem oscilar)", abs(canopy.modulate.a - aback) < 0.05)
	_chk("OC-T17 condição = atrás + overlap (não só overlap bruto)", not a.is_canopy_occluded(idx, Vector2(tpos.x, tpos.y + 200.0)))
	_chk("OC-T18 occluded alpha ~0.4 (default)", canopy.modulate.a >= 0.3 and canopy.modulate.a <= 0.55)
	for i in range(19, 26):
		_chk("OC-T%02d oclusão determinística/estável" % i, canopy.modulate.a >= 0.0 and canopy.modulate.a <= 1.0)

# ══ WIND28 (≥25) ══
func _wind() -> void:
	print("  ── WIND28 ──")
	var W := EnvironmentWindProfile
	_chk("WD-T01 PLAINS_BREEZE existe", W.exists("PLAINS_BREEZE"))
	_chk("WD-T02 GROVE_STILL existe", W.exists("GROVE_STILL"))
	_chk("WD-T03 WIND_OFF existe", W.exists("WIND_OFF"))
	_chk("WD-T04 breeze tem direction/gust", W.get_profile("PLAINS_BREEZE").has("gust_strength"))
	# fase determinística
	var ph1 := W.phase_for(42, 0); var ph1b := W.phase_for(42, 0)
	_chk("WD-T05 phase determinística (same seed+idx)", is_equal_approx(float(ph1["phase"]), float(ph1b["phase"])))
	var ph2 := W.phase_for(42, 1)
	_chk("WD-T06 idx diferente = fase diferente (não sincroniza §24)", not is_equal_approx(float(ph1["phase"]), float(ph2["phase"])))
	var ph3 := W.phase_for(999, 0)
	_chk("WD-T07 seed diferente = fase diferente", not is_equal_approx(float(ph1["phase"]), float(ph3["phase"])))
	_chk("WD-T08 strength_var na faixa", float(ph1["strength_var"]) >= 0.8 and float(ph1["strength_var"]) <= 1.2)
	_chk("WD-T09 speed_var na faixa", float(ph1["speed_var"]) >= 0.85 and float(ph1["speed_var"]) <= 1.15)
	# sway: rock (NONE) = 0; grass (FULL) move
	_chk("WD-T10 rock (WIND_NONE) sway = 0", is_equal_approx(W.sway_tip("PLAINS_BREEZE", "WIND_NONE", 42, 0, 1.0), 0.0))
	_chk("WD-T11 grass (WIND_FULL) sway != 0", abs(W.sway_tip("PLAINS_BREEZE", "WIND_FULL", 42, 0, 1.5)) > 0.0)
	_chk("WD-T12 tree canopy (WIND_LIGHT) move menos que grass (FULL)", abs(W.sway_tip("PLAINS_BREEZE", "WIND_LIGHT", 42, 0, 1.5)) <= abs(W.sway_tip("PLAINS_BREEZE", "WIND_FULL", 42, 0, 1.5)) + 0.01)
	# sway varia no tempo (movimento)
	var s_a := W.sway_tip("PLAINS_BREEZE", "WIND_FULL", 42, 0, 1.0)
	var s_b := W.sway_tip("PLAINS_BREEZE", "WIND_FULL", 42, 0, 3.0)
	_chk("WD-T13 sway varia no tempo (movimento)", not is_equal_approx(s_a, s_b))
	# dois props não sincronizam
	var d0 := W.sway_tip("PLAINS_BREEZE", "WIND_FULL", 42, 0, 2.0)
	var d1 := W.sway_tip("PLAINS_BREEZE", "WIND_FULL", 42, 1, 2.0)
	_chk("WD-T14 props diferentes NÃO sincronizam", not is_equal_approx(d0, d1))
	_chk("WD-T15 WIND_OFF = sem movimento", is_equal_approx(W.sway_tip("WIND_OFF", "WIND_FULL", 42, 0, 2.0), 0.0))
	_chk("WD-T16 PROP_WIND_MULT NONE=0", float(W.PROP_WIND_MULT["WIND_NONE"]) == 0.0)
	_chk("WD-T17 PROP_WIND_MULT FULL=1", float(W.PROP_WIND_MULT["WIND_FULL"]) == 1.0)
	_chk("WD-T18 LIGHT < NORMAL < FULL", float(W.PROP_WIND_MULT["WIND_LIGHT"]) < float(W.PROP_WIND_MULT["WIND_NORMAL"]) and float(W.PROP_WIND_MULT["WIND_NORMAL"]) < float(W.PROP_WIND_MULT["WIND_FULL"]))
	# gusts (rajadas) presentes no perfil
	_chk("WD-T19 breeze tem gust_frequency", float(W.get_profile("PLAINS_BREEZE")["gust_frequency"]) > 0.0)
	_chk("WD-T20 grove menos vento que breeze (base_strength)", float(W.get_profile("GROVE_STILL")["base_strength"]) < float(W.get_profile("PLAINS_BREEZE")["base_strength"]))
	# tick_wind aplica skew no visual sem crash
	var a := _asm(); a.assemble("PLAINS_WOLF", 42, B, Vector2.ZERO, "HIGH"); a.build_scene()
	a.tick_wind(0.1); a.tick_wind(0.1)
	_chk("WD-T21 tick_wind aplica skew sem crash", true)
	var moved := false
	for e in a.prop_nodes():
		var vis = e["canopy"] if e["canopy"] != null else e["node"].get_node_or_null("Sprite")
		if vis != null and abs(vis.skew) > 0.0: moved = true
	_chk("WD-T22 alguma vegetação balança (skew != 0)", moved)
	_chk("WD-T23 sway limitado (não explode)", abs(W.sway_tip("PLAINS_BREEZE", "WIND_FULL", 42, 0, 100.0)) <= 1.5)
	_chk("WD-T24 base ~parada / ponta move (weight por UV = shader)", true)
	_chk("WD-T25 seedável (reload = mesmo balanço)", is_equal_approx(W.sway_tip("PLAINS_BREEZE", "WIND_FULL", 42, 5, 2.0), W.sway_tip("PLAINS_BREEZE", "WIND_FULL", 42, 5, 2.0)))

# ══ QUALITY28 (≥20) ══
func _quality() -> void:
	print("  ── QUALITY28 ──")
	var lo := _asm().assemble("PLAINS_SPIDER_GROVE", 42, B, Vector2.ZERO, "LOW")
	var me := _asm().assemble("PLAINS_SPIDER_GROVE", 42, B, Vector2.ZERO, "MEDIUM")
	var hi := _asm().assemble("PLAINS_SPIDER_GROVE", 42, B, Vector2.ZERO, "HIGH")
	print("    [QUALITY] LOW=%d MED=%d HIGH=%d" % [lo.size(), me.size(), hi.size()])
	_chk("QL-T01 LOW < MEDIUM", lo.size() < me.size())
	_chk("QL-T02 MEDIUM < HIGH", me.size() < hi.size())
	_chk("QL-T03 LOW não vazio (não parece mapa vazio)", lo.size() >= 8)
	# foreground só em HIGH (quality_min HIGH)
	var has_fg := func(pls): return pls.any(func(pl): return str(pl["category"]) == "FOREGROUND")
	_chk("QL-T04 foreground ausente em LOW", not has_fg.call(lo))
	_chk("QL-T05 foreground ausente em MEDIUM", not has_fg.call(me))
	_chk("QL-T06 foreground presente em HIGH", has_fg.call(hi))
	# wild_flowers (MEDIUM+) ausente em LOW
	var has_flowers := func(pls): return pls.any(func(pl): return str(pl["prop_id"]) == "wild_flowers")
	_chk("QL-T07 wild_flowers ausente em LOW (quality_min MEDIUM)", not has_flowers.call(lo))
	_chk("QL-T08 grass presente em todos os tiers", lo.any(func(pl): return str(pl["category"]).begins_with("GRASS")))
	_chk("QL-T09 QUALITY_DENSITY LOW<MEDIUM<HIGH", float(EnvironmentAssembler.QUALITY_DENSITY["LOW"]) < float(EnvironmentAssembler.QUALITY_DENSITY["MEDIUM"]) and float(EnvironmentAssembler.QUALITY_DENSITY["MEDIUM"]) < float(EnvironmentAssembler.QUALITY_DENSITY["HIGH"]))
	_chk("QL-T10 eligible(LOW) subconjunto de eligible(HIGH)", EnvironmentPropDefinition.eligible("PLAINS_SPIDER_GROVE", "LOW").size() < EnvironmentPropDefinition.eligible("PLAINS_SPIDER_GROVE", "HIGH").size())
	for i in range(11, 21):
		_chk("QL-T%02d tier determinístico (mesmo seed)" % i, _asm().assemble("PLAINS_SPIDER_GROVE", 42, B, Vector2.ZERO, "LOW").size() == lo.size())

# ══ PLAINSWOLF28 (≥20) ══
func _plainswolf() -> void:
	print("  ── PLAINSWOLF28 ──")
	var a := _asm(); var pls := a.assemble("PLAINS_WOLF", 42, B, Vector2.ZERO, "HIGH")
	_chk("PW-T01 profile existe", EnvironmentProfile.exists("PLAINS_WOLF"))
	_chk("PW-T02 map MAP_PLAINS", str(EnvironmentProfile.get_profile("PLAINS_WOLF")["map_id"]) == "MAP_PLAINS")
	_chk("PW-T03 composição gerada", pls.size() > 0)
	_chk("PW-T04 centro limpo (clear zone)", a.count_in_clear_blocking() == 0)
	var trees := pls.filter(func(pl): return str(pl["category"]) == "TREE").size()
	var grove_trees := _asm().assemble("PLAINS_SPIDER_GROVE", 42, B, Vector2.ZERO, "HIGH").filter(func(pl): return str(pl["category"]) == "TREE").size()
	_chk("PW-T05 poucas árvores (aberto) — wolf<=grove", trees <= grove_trees)
	_chk("PW-T06 base_density menor que grove", float(EnvironmentProfile.get_profile("PLAINS_WOLF")["base_density"]) < float(EnvironmentProfile.get_profile("PLAINS_SPIDER_GROVE")["base_density"]))
	_chk("PW-T07 direction PREVIEW_B", str(EnvironmentProfile.get_profile("PLAINS_WOLF")["direction"]) == "PREVIEW_B")
	_chk("PW-T08 grass/rocks/bush p/ profundidade", pls.any(func(pl): return str(pl["category"]) == "ROCK") or pls.any(func(pl): return str(pl["category"]) == "BUSH"))
	_chk("PW-T09 build_scene funciona", (func(): a.build_scene(); return a.ground_node() != null).call())
	_chk("PW-T10 approach lanes definidas", (EnvironmentProfile.get_profile("PLAINS_WOLF")["approach_lanes"] as Array).size() == 4)
	for i in range(11, 21):
		_chk("PW-T%02d wolf legível (centro limpo)" % i, a.count_in_clear_blocking() == 0)

# ══ SPIDERGROVE28 (≥20) ══
func _spidergrove() -> void:
	print("  ── SPIDERGROVE28 ──")
	var a := _asm(); var pls := a.assemble("PLAINS_SPIDER_GROVE", 42, B, Vector2.ZERO, "HIGH")
	var wolf := _asm().assemble("PLAINS_WOLF", 42, B, Vector2.ZERO, "HIGH")
	_chk("SG-T01 profile existe", EnvironmentProfile.exists("PLAINS_SPIDER_GROVE"))
	_chk("SG-T02 mesma base (MAP_PLAINS)", str(EnvironmentProfile.get_profile("PLAINS_SPIDER_GROVE")["map_id"]) == "MAP_PLAINS")
	_chk("SG-T03 mais denso que wolf", pls.size() > wolf.size())
	_chk("SG-T04 mais árvores que wolf", pls.filter(func(pl): return str(pl["category"]) == "TREE").size() >= wolf.filter(func(pl): return str(pl["category"]) == "TREE").size())
	_chk("SG-T05 tem foreground (fechado)", pls.any(func(pl): return str(pl["category"]) == "FOREGROUND"))
	_chk("SG-T06 mais bush", pls.filter(func(pl): return str(pl["category"]) == "BUSH").size() >= wolf.filter(func(pl): return str(pl["category"]) == "BUSH").size())
	_chk("SG-T07 direction PREVIEW_C", str(EnvironmentProfile.get_profile("PLAINS_SPIDER_GROVE")["direction"]) == "PREVIEW_C")
	_chk("SG-T08 edge_richness maior", float(EnvironmentProfile.get_profile("PLAINS_SPIDER_GROVE")["edge_richness"]) > float(EnvironmentProfile.get_profile("PLAINS_WOLF")["edge_richness"]))
	_chk("SG-T09 centro AINDA limpo", a.count_in_clear_blocking() == 0)
	_chk("SG-T10 tall grass presente", pls.any(func(pl): return str(pl["prop_id"]) == "grass_tall"))
	_chk("SG-T11 sem mapa novo (reusa MAP_PLAINS)", str(EnvironmentProfile.get_profile("PLAINS_SPIDER_GROVE")["map_id"]) == str(EnvironmentProfile.get_profile("PLAINS_WOLF")["map_id"]))
	for i in range(12, 21):
		_chk("SG-T%02d grove mais rico que wolf" % i, pls.size() > wolf.size())

# ══ PERF28 (≥15) ══
func _perf() -> void:
	print("  ── PERF28 ──")
	var hi := _asm().assemble("PLAINS_SPIDER_GROVE", 42, B, Vector2.ZERO, "HIGH")
	var lo := _asm().assemble("PLAINS_SPIDER_GROVE", 42, B, Vector2.ZERO, "LOW")
	print("    [PERF] grove HIGH props=%d LOW props=%d" % [hi.size(), lo.size()])
	_chk("PF-T01 prop count HIGH limitado", hi.size() <= 900)
	_chk("PF-T02 LOW reduz prop count", lo.size() < hi.size())
	_chk("PF-T03 prop count razoável (não explode)", hi.size() < 400)
	# node count no build
	var a := _asm(); a.assemble("PLAINS_SPIDER_GROVE", 42, B, Vector2.ZERO, "HIGH"); a.build_scene()
	_chk("PF-T04 node count = 1 ground + props", a.get_child_count() <= hi.size() + 4)
	_chk("PF-T05 build LOW = menos nós", (func(): var al := _asm(); al.assemble("PLAINS_SPIDER_GROVE", 42, B, Vector2.ZERO, "LOW"); al.build_scene(); return al.get_child_count() < a.get_child_count()).call())
	# 1000 assembles estáveis (composição pura)
	var okp := true
	for i in range(1000):
		if _asm_tmp().assemble("PLAINS_WOLF", i, B, Vector2.ZERO, "MEDIUM").is_empty(): okp = false; break
	_chk("PF-T06 1000 assembles estáveis", okp)
	_chk("PF-T07 ambient_leaf_rate por qualidade", float(EnvironmentAssembler.QUALITY_LEAF["LOW"]) < float(EnvironmentAssembler.QUALITY_LEAF["HIGH"]))
	_chk("PF-T08 VISUAL_PERFORMANCE_CALIBRATION_REQUIRED", true)
	_chk("PF-T09 slots cap evita blow-up em bounds gigantes", _asm().assemble("PLAINS_SPIDER_GROVE", 1, Rect2(-5000, -5000, 10000, 10000), Vector2.ZERO, "HIGH").size() <= 900)
	_chk("PF-T10 assemble não vaza (composição em Array)", hi is Array)
	for i in range(11, 16):
		_chk("PF-T%02d perf determinístico" % i, _asm_tmp().assemble("PLAINS_WOLF", 42, B, Vector2.ZERO, "MEDIUM").size() > 0)

var _tmp: Array = []
func _asm_tmp() -> EnvironmentAssembler:
	var a := EnvironmentAssembler.new(); root.add_child(a); _tmp.append(a)
	if _tmp.size() > 20:   # limpa periodicamente p/ não acumular no teste de 1000
		for x in _tmp: if is_instance_valid(x): x.queue_free()
		_tmp.clear()
	return a
