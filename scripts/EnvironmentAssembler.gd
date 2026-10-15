class_name EnvironmentAssembler extends Node2D
## A28 — LIVING WORLD: monta o ambiente AUTOMÁTICO (o usuário NÃO posiciona props na mão §34). Entrada: profile+seed+
## bounds+combat_anchor. Saída: composição DETERMINÍSTICA (mesmo seed = mesmo layout §8). Densidade cresce do centro
## p/ a borda (Preview B no centro, C nas bordas §9). CombatClearZone (§10) e SpawnApproachLanes (§11) ficam limpas de
## props bloqueantes. build_scene() instancia ground CONTÍNUO (sem grade de tile) + props com footprint/y-sort/copa.

var profile_id := ""
var seed_val := 0
var bounds := Rect2()
var combat_anchor := Vector2.ZERO
var quality := "HIGH"
var placements: Array = []      # [{prop_id, position, index, category, ground_y, z, in_clear, in_lane, phase}]
var _ground: Sprite2D = null
var _prop_nodes: Array = []     # [{node, placement, canopy, trunk}]
var _debug := false
var _t := 0.0

const QUALITY_DENSITY := {"LOW": 0.55, "MEDIUM": 0.8, "HIGH": 1.0}
const QUALITY_LEAF := {"LOW": 0.2, "MEDIUM": 0.5, "HIGH": 1.0}

# ═══════════════════ COMPOSIÇÃO DETERMINÍSTICA (pura; testável headless) ═══════════════════
func assemble(p_profile: String, p_seed: int, p_bounds: Rect2, p_anchor: Vector2, p_quality := "HIGH") -> Array:
	profile_id = p_profile; seed_val = p_seed; bounds = p_bounds; combat_anchor = p_anchor; quality = p_quality
	placements = []
	if not EnvironmentProfile.exists(p_profile): return placements
	var prof := EnvironmentProfile.get_profile(p_profile)
	var mix: Dictionary = prof["category_mix"]
	var clear_r := float(prof["clear_zone_radius"])
	var lanes: Array = prof["approach_lanes"]; var lane_hw := float(prof["lane_half_width"])
	var edge_rich := float(prof.get("edge_richness", 1.5))
	var max_dist := maxf(1.0, Vector2(bounds.size.x, bounds.size.y).length() * 0.5)
	var rng := RandomNumberGenerator.new(); rng.seed = p_seed
	# nº de candidatos ∝ área × densidade × qualidade
	var area := bounds.size.x * bounds.size.y
	var qmult := float(QUALITY_DENSITY.get(p_quality, 1.0))
	var slots := int(area / 9000.0 * float(prof["base_density"]) * qmult)
	slots = clampi(slots, 12, 900)
	var cat_keys: Array = mix.keys()
	var idx := 0
	for i in range(slots):
		var pos := Vector2(rng.randf_range(bounds.position.x, bounds.position.x + bounds.size.x),
			rng.randf_range(bounds.position.y, bounds.position.y + bounds.size.y))
		var dist := pos.distance_to(combat_anchor)
		var in_clear := dist < clear_r
		var in_lane := _in_lane(pos, lanes, lane_hw)
		# densidade cresce com a distância (centro raro, borda densa §9)
		var density := clampf(dist / max_dist, 0.08, 1.0)
		density = pow(density, 1.0 / edge_rich)   # edge_richness empurra p/ bordas
		if rng.randf() > density: continue
		# escolhe categoria pela mistura ponderada
		var cat := _weighted_pick(cat_keys, mix, rng)
		var candidates := EnvironmentPropDefinition.by_category(cat).filter(func(id): return (EnvironmentPropDefinition.get_prop(id)["profiles"] as Array).has(p_profile) and _quality_ok(id))
		if candidates.is_empty(): continue
		var prop_id := _weighted_pick_props(candidates, rng)
		# CLEAR ZONE / LANES: nada que COLIDA ou seja árvore/bush grande no centro/corredor (§10/§11)
		var blocking := EnvironmentPropDefinition.collides(prop_id) or EnvironmentPropDefinition.has_canopy(prop_id)
		if (in_clear or in_lane) and blocking:
			continue
		var ph := EnvironmentWindProfile.phase_for(p_seed, idx)
		placements.append({"prop_id": prop_id, "position": pos, "index": idx, "category": cat,
			"ground_y": pos.y, "z": int(pos.y), "in_clear": in_clear, "in_lane": in_lane, "phase": ph})
		idx += 1
	# ordenação determinística por ground point (y) — base do y-sort (§16)
	placements.sort_custom(func(a, b): return float(a["ground_y"]) < float(b["ground_y"]))
	return placements

func _in_lane(pos: Vector2, lanes: Array, half_w: float) -> bool:
	var d := pos - combat_anchor
	if d.length() < 1.0: return true
	var ang := rad_to_deg(atan2(d.y, d.x))
	for la in lanes:
		var diff: float = abs(_ang_norm(ang - float(la)))
		# largura angular decai com distância; aproximamos por faixa angular fixa + faixa perpendicular
		var perp: float = abs(sin(deg_to_rad(diff))) * d.length()
		if diff < 20.0 or perp < half_w: return true
	return false

func _ang_norm(a: float) -> float:
	while a > 180.0: a -= 360.0
	while a < -180.0: a += 360.0
	return a

func _quality_ok(prop_id: String) -> bool:
	var rank := {"LOW": 0, "MEDIUM": 1, "HIGH": 2}
	return int(rank.get(str(EnvironmentPropDefinition.get_prop(prop_id).get("quality_min", "LOW")), 0)) <= int(rank.get(quality, 2))

func _weighted_pick(keys: Array, weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for k in keys: total += float(weights.get(k, 0.0))
	if total <= 0.0: return str(keys[0]) if not keys.is_empty() else ""
	var r := rng.randf() * total; var acc := 0.0
	for k in keys:
		acc += float(weights.get(k, 0.0))
		if r <= acc: return str(k)
	return str(keys[keys.size() - 1])

func _weighted_pick_props(ids: Array, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for id in ids: total += float(EnvironmentPropDefinition.get_prop(id).get("density_weight", 1.0))
	var r := rng.randf() * total; var acc := 0.0
	for id in ids:
		acc += float(EnvironmentPropDefinition.get_prop(id).get("density_weight", 1.0))
		if r <= acc: return str(id)
	return str(ids[ids.size() - 1])

# ═══════════════════ FOOTPRINT DE COLISÃO (pegada física, não a bbox do PNG §12-14) ═══════════════════
static func footprint_shape(prop_id: String) -> Dictionary:
	var p := EnvironmentPropDefinition.get_prop(prop_id)
	var col := str(p.get("collision", "NONE"))
	if col == "NONE": return {"type": "none"}
	var tex := load(str(p["texture"])) as Texture2D
	var w := 64.0; var h := 64.0
	if tex != null: w = tex.get_width() * float(p.get("display_scale", 1.0)); h = tex.get_height() * float(p.get("display_scale", 1.0))
	var fp: Dictionary = p.get("footprint", {"w": 0.5, "h": 0.25})
	var shape := "ellipse" if col in ["TRUNK_BASE", "ROCK_FOOTPRINT", "SMALL_BASE"] else "rect"
	# pegada centrada na BASE (contato com o chão), largura/altura = fração da imagem
	return {"type": shape, "w": w * float(fp["w"]), "h": h * float(fp["h"]), "collision": col}

# ═══════════════════ BUILD DE CENA (ground contínuo + props reais) ═══════════════════
func build_scene(player: Node2D = null) -> void:
	_clear_scene()
	var prof := EnvironmentProfile.get_profile(profile_id)
	# GROUND CONTÍNUO: Sprite2D com textura em REPEAT cobrindo os bounds — SEM grade de TileMap (§5).
	_ground = Sprite2D.new(); _ground.name = "GroundLayer"
	var gtex := load(str(prof.get("ground_texture", ""))) as Texture2D
	if gtex != null:
		gtex.take_over_path(gtex.resource_path)   # no-op seguro
		_ground.texture = gtex; _ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		_ground.region_enabled = true
		_ground.region_rect = Rect2(0, 0, bounds.size.x, bounds.size.y)
		_ground.position = combat_anchor; _ground.centered = true
	_ground.z_index = -4096
	add_child(_ground)
	# PROPS
	for pl in placements:
		var node := _build_prop_node(pl)
		if node != null: add_child(node)
	# y-sort do container (ordena por posição.y — ground contact §16)
	y_sort_enabled = true

func _build_prop_node(pl: Dictionary) -> Node2D:
	var p := EnvironmentPropDefinition.get_prop(str(pl["prop_id"]))
	var tex := load(str(p["texture"])) as Texture2D
	if tex == null: return null
	var root := Node2D.new(); root.name = str(pl["prop_id"]); root.position = pl["position"]
	var scale_v := float(p.get("display_scale", 1.0))
	var anchor := float(p.get("ground_anchor", 1.0))
	var meta := {"canopy": null, "trunk": null}
	if EnvironmentPropDefinition.has_canopy(str(pl["prop_id"])):
		# ÁRVORE: split conceitual por UV — trunk (baixo, opaco) + canopy (topo, oclui/some). Mesma textura, 2 regiões.
		var cfrac := float(p["canopy_frac"])
		var th := tex.get_height()
		var trunk := Sprite2D.new(); trunk.name = "Trunk"; trunk.texture = tex; trunk.region_enabled = true
		trunk.region_rect = Rect2(0, th * cfrac, tex.get_width(), th * (1.0 - cfrac))
		trunk.centered = false; trunk.scale = Vector2(scale_v, scale_v)
		trunk.position = Vector2(-tex.get_width() * scale_v * 0.5, -th * (1.0 - cfrac) * scale_v * anchor)
		root.add_child(trunk)
		var canopy := Sprite2D.new(); canopy.name = "Canopy"; canopy.texture = tex; canopy.region_enabled = true
		canopy.region_rect = Rect2(0, 0, tex.get_width(), th * cfrac)
		canopy.centered = false; canopy.scale = Vector2(scale_v, scale_v)
		canopy.position = Vector2(-tex.get_width() * scale_v * 0.5, -th * scale_v * anchor)
		root.add_child(canopy)
		meta["canopy"] = canopy; meta["trunk"] = trunk
	else:
		var spr := Sprite2D.new(); spr.name = "Sprite"; spr.texture = tex; spr.centered = false
		spr.scale = Vector2(scale_v, scale_v)
		spr.position = Vector2(-tex.get_width() * scale_v * 0.5, -tex.get_height() * scale_v * anchor)
		root.add_child(spr)
	# colisão FOOTPRINT (só se colide)
	if EnvironmentPropDefinition.collides(str(pl["prop_id"])):
		var body := StaticBody2D.new(); body.name = "Footprint"
		var cs := CollisionShape2D.new(); var fp := footprint_shape(str(pl["prop_id"]))
		if str(fp["type"]) == "ellipse":
			var cap := CapsuleShape2D.new(); cap.radius = float(fp["w"]) * 0.5; cap.height = maxf(float(fp["h"]), cap.radius * 2.0 + 1.0)
			cs.shape = cap; cs.rotation = PI / 2.0
		else:
			var rect := RectangleShape2D.new(); rect.size = Vector2(float(fp["w"]), float(fp["h"])); cs.shape = rect
		body.add_child(cs); root.add_child(body)
	root.z_index = 0
	_prop_nodes.append({"node": root, "placement": pl, "canopy": meta["canopy"], "trunk": meta["trunk"], "fade": 1.0})
	return root

func _clear_scene() -> void:
	for c in get_children(): remove_child(c); c.free()
	_prop_nodes.clear(); _ground = null

# ═══════════════════ OCLUSÃO DE COPA (fade quando o player fica ATRÁS §18/§19) ═══════════════════
func update_occlusion(player: Node2D, delta := 0.016) -> void:
	if player == null: return
	var pgy := player.global_position.y      # ground point do player (pés = position)
	var pgx := player.global_position.x
	for e in _prop_nodes:
		if e["canopy"] == null: continue
		var pl: Dictionary = e["placement"]
		var tgy := float(pl["ground_y"])
		var p := EnvironmentPropDefinition.get_prop(str(pl["prop_id"]))
		var tex := load(str(p["texture"])) as Texture2D
		var half_w := (tex.get_width() * float(p.get("display_scale", 1.0)) * 0.5) if tex != null else 40.0
		var canopy_h := (tex.get_height() * float(p["canopy_frac"]) * float(p.get("display_scale", 1.0))) if tex != null else 60.0
		# condição (§19): player ATRÁS (ground point acima) + sobreposição horizontal na área da copa
		var ppos: Vector2 = pl["position"]
		var behind: bool = pgy < tgy
		var overlap_x: bool = abs(pgx - ppos.x) < half_w
		var overlap_y: bool = pgy > (tgy - canopy_h - 40.0)   # dentro da faixa vertical da copa
		var occluded: bool = behind and overlap_x and overlap_y
		var target := 0.4 if occluded else 1.0           # occluded alpha 0.30–0.50 (§18)
		var rate := delta / 0.22                          # transição ~0.22s (§18)
		e["fade"] = move_toward(float(e["fade"]), target, rate)
		e["canopy"].modulate.a = float(e["fade"])         # trunk permanece opaco

## true se a copa da árvore está oclusa pelo player (para testes).
func is_canopy_occluded(prop_index: int, player_pos: Vector2) -> bool:
	for e in _prop_nodes:
		if int(e["placement"]["index"]) == prop_index and e["canopy"] != null:
			var pl: Dictionary = e["placement"]
			var p := EnvironmentPropDefinition.get_prop(str(pl["prop_id"]))
			var tex := load(str(p["texture"])) as Texture2D
			var half_w := (tex.get_width() * float(p.get("display_scale", 1.0)) * 0.5) if tex != null else 40.0
			var ppos2: Vector2 = pl["position"]
			return player_pos.y < float(pl["ground_y"]) and abs(player_pos.x - ppos2.x) < half_w
	return false

# ═══════════════════ VENTO (aplica sway; o shader real pesa por UV.y) ═══════════════════
func tick_wind(delta: float) -> void:
	_t += delta
	var wind_id := str(EnvironmentProfile.get_profile(profile_id).get("wind_profile", "WIND_OFF"))
	for e in _prop_nodes:
		var pl: Dictionary = e["placement"]
		var pw := str(EnvironmentPropDefinition.get_prop(str(pl["prop_id"])).get("wind", "WIND_NONE"))
		var sway := EnvironmentWindProfile.sway_tip(wind_id, pw, seed_val, int(pl["index"]), _t)
		# aplica leve skew horizontal na PONTA (canopy/sprite topo). Base ~parada (skew só no topo via pivot inferior).
		var vis: Node2D = e["canopy"] if e["canopy"] != null else (e["node"].get_node_or_null("Sprite"))
		if vis != null: vis.skew = sway * 0.08

# ═══════════════════ DEBUG VIEW (DEV; default OFF §38) ═══════════════════
func set_debug(on: bool) -> void: _debug = on; queue_redraw()
func _draw() -> void:
	if not _debug: return
	var prof := EnvironmentProfile.get_profile(profile_id)
	draw_circle(combat_anchor, float(prof.get("clear_zone_radius", 200.0)), Color(1, 0.3, 0.3, 0.15))   # clear zone
	for la in prof.get("approach_lanes", []):
		var dir := Vector2.RIGHT.rotated(deg_to_rad(float(la)))
		draw_line(combat_anchor, combat_anchor + dir * 500.0, Color(0.3, 0.6, 1.0, 0.4), 3.0)             # lanes
	for e in _prop_nodes:
		var pl: Dictionary = e["placement"]
		draw_circle(pl["position"], 4.0, Color(0.4, 1.0, 0.4, 0.8))                                        # prop anchors
		if EnvironmentPropDefinition.collides(str(pl["prop_id"])):
			var fp := footprint_shape(str(pl["prop_id"]))
			draw_rect(Rect2(pl["position"] - Vector2(float(fp["w"]), float(fp["h"])) * 0.5, Vector2(float(fp["w"]), float(fp["h"]))), Color(1, 1, 0.2, 0.5), false, 2.0)

# acessores de teste
func prop_count() -> int: return placements.size()
func count_in_clear_blocking() -> int:
	var n := 0
	for pl in placements:
		if bool(pl["in_clear"]) and (EnvironmentPropDefinition.collides(str(pl["prop_id"])) or EnvironmentPropDefinition.has_canopy(str(pl["prop_id"]))): n += 1
	return n
func ground_node() -> Sprite2D: return _ground
func prop_nodes() -> Array: return _prop_nodes
