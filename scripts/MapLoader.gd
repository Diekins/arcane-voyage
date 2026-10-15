extends RefCounted
class_name MapLoader
## MapLoader (EXPERIMENTAL / opt-in) — consome o JSON exportado pelo Arcane Voyage Studio
## (schemaVersion 1) e, opcionalmente, monta os nós visuais mínimos num parent recebido.
##
## NÃO substitui os mapas atuais (Vila/Planície/Caverna montados em Main.gd) — é uma ponte
## separada pra validar o formato do Studio. Pode ser usado headless (só parse/validação) ou
## construir visual numa cena de teste (MapLoaderTest.tscn).
##
## Convenções de coordenada (iguais ao Studio e ao Main.gd):
##  - sprites de objects/markers = CENTRADOS em (x,y); tiles e blockers = canto sup-esq + (w,h).
##  - z-sort: ysort ? int(y + baseOffset) : z.
## Assets: "tilesets/..", "actors/.." => res://assets/<path>. Paths externos (user/, outputs,
## "..", drive absoluto) são IGNORADOS com warning — nunca causam SCRIPT ERROR.

const ASSET_ROOT := "res://assets/"

var data: Dictionary = {}
var schema_version: int = 0
var map: Dictionary = {}
var objects: Array = []
var blockers: Array = []          # Array[Rect2] (compatível com _blockers do Main)
var blocker_raw: Array = []       # dicts originais (id/x/y/w/h)
var portals: Array = []
var markers: Array = []
var mobs: Array = []
var loot: Dictionary = {}
var npcs: Array = []
var services: Array = []
var asset_bank: Array = []
var quests: Array = []
var warnings: Array = []
var loaded: bool = false
var mob_nodes: Array = []          # [{node, origin:Vector2, radius:float, mobId}] — preenchido por build_into

# --------------------------------------------------------------------------------------
# CARREGAMENTO
# --------------------------------------------------------------------------------------
func load_map_json(path: String) -> bool:
	warnings.clear()
	if not FileAccess.file_exists(path):
		push_warning("[MapLoader] arquivo ausente: %s" % path)
		warnings.append("arquivo ausente: " + path)
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		warnings.append("não consegui abrir: " + path)
		return false
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("[MapLoader] JSON inválido: %s" % path)
		warnings.append("JSON inválido: " + path)
		return false
	return load_map_dict(parsed)

func load_map_dict(d: Dictionary) -> bool:
	data = d
	schema_version = int(d.get("schemaVersion", 0))
	map = d.get("map", {}) if d.get("map", {}) is Dictionary else {}
	objects = _as_array(d.get("objects", []))
	blocker_raw = _as_array(d.get("blockers", []))
	portals = _as_array(d.get("portals", []))
	markers = _as_array(d.get("markers", []))
	mobs = _as_array(d.get("mobs", []))
	loot = d.get("loot", {}) if d.get("loot", {}) is Dictionary else {}
	npcs = _as_array(d.get("npcs", []))
	services = _as_array(d.get("services", []))
	asset_bank = _as_array(d.get("assetBank", []))
	quests = _as_array(d.get("quests", []))
	# blockers -> Rect2
	blockers.clear()
	for b in blocker_raw:
		if b is Dictionary:
			blockers.append(Rect2(float(b.get("x", 0)), float(b.get("y", 0)), float(b.get("w", 0)), float(b.get("h", 0))))
	loaded = true
	return true

func _as_array(v: Variant) -> Array:
	return v if v is Array else []

# --------------------------------------------------------------------------------------
# VALIDAÇÃO MÍNIMA — devolve lista de ERROS (string). Vazia = ok pra montar.
# --------------------------------------------------------------------------------------
func validate_min() -> Array:
	var errs: Array = []
	if schema_version != 1:
		errs.append("schemaVersion %d != 1" % schema_version)
	if map.is_empty():
		errs.append("map ausente")
	else:
		if float(map.get("width", 0)) <= 0.0 or float(map.get("height", 0)) <= 0.0:
			errs.append("map.width/height inválidos")
		var sp: Variant = map.get("spawn", null)
		if not (sp is Dictionary) or not sp.has("x"):
			errs.append("map.spawn ausente")
	return errs

func map_size() -> Vector2:
	return Vector2(float(map.get("width", 0)), float(map.get("height", 0)))

func map_spawn() -> Vector2:
	var sp: Variant = map.get("spawn", {})
	if sp is Dictionary:
		return Vector2(float(sp.get("x", 0)), float(sp.get("y", 0)))
	return Vector2.ZERO

# --------------------------------------------------------------------------------------
# ASSETS — resolução segura. "" = não-carregável (externo/outputs/absoluto).
# --------------------------------------------------------------------------------------
func resolve_asset_path(asset: Variant) -> String:
	if asset == null:
		return ""
	var a := str(asset)
	if a == "":
		return ""
	if a.begins_with("res://"):
		return a   # já resolvido
	# externos / não versionados → ignorar (sem crash)
	if a.begins_with("user/") or a.find("..") != -1 or a.find(":") != -1 or a.find("outputs") != -1 or a.begins_with("/"):
		return ""
	return ASSET_ROOT + a

func _asset_loadable(asset: Variant) -> bool:
	var rp := resolve_asset_path(asset)
	return rp != "" and FileAccess.file_exists(rp)

# --------------------------------------------------------------------------------------
# ACESSADORES de definição (por id)
# --------------------------------------------------------------------------------------
func get_mob(id: String) -> Dictionary:
	for m in mobs:
		if m is Dictionary and str(m.get("mobId", "")) == id: return m
	return {}
func get_npc(id: String) -> Dictionary:
	for n in npcs:
		if n is Dictionary and str(n.get("npcId", "")) == id: return n
	return {}
func get_service(id: String) -> Dictionary:
	for s in services:
		if s is Dictionary and str(s.get("serviceId", "")) == id: return s
	return {}
func get_item(id: String) -> Dictionary:
	var items: Array = _as_array(loot.get("items", []))
	for it in items:
		if it is Dictionary and str(it.get("itemId", "")) == id: return it
	return {}

# entrada do Asset Bank por path (metadados de frame/direção). {} se não houver.
func asset_bank_for_path(path: String) -> Dictionary:
	for e in asset_bank:
		if e is Dictionary and str(e.get("path", "")) == path: return e
	return {}

# {frameW, frameH} a partir do Asset Bank (ou {} se não souber). Usado p/ recortar o 1º quadro
# (linha 0 = "down" no caso 4dir; 1º frame nos demais), respeitando metadados de produção.
func _frame_meta(asset: Variant) -> Dictionary:
	var e := asset_bank_for_path(str(asset))
	if e.is_empty(): return {}
	return { "frameW": int(e.get("frameW", 0)), "frameH": int(e.get("frameH", 0)), "directionMode": str(e.get("directionMode", "")) }

# Resolve o JSON-alvo de um portal: 1º por map.id == target dentro de res://data/studio_*.json,
# senão fallback p/ studio_<target>.json. "" se não achar.
func find_map_for_target(target: String, dir := "res://data/") -> String:
	if target == "": return ""
	var d := DirAccess.open(dir)
	if d != null:
		for f in d.get_files():
			if f.begins_with("studio_") and f.ends_with(".json"):
				var p := dir + f
				var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
				if parsed is Dictionary:
					var mp: Variant = parsed.get("map", {})
					if mp is Dictionary and str(mp.get("id", "")) == target:
						return p
	var direct := dir + "studio_" + target + ".json"
	if FileAccess.file_exists(direct): return direct
	return ""

# --------------------------------------------------------------------------------------
# CONSTRUÇÃO VISUAL MÍNIMA — cria um nó "StudioMap" sob `parent` e devolve um summary.
# `opts` aceita callbacks opcionais (Callable) p/ delegar ao Main:
#   add_prop(path,pos,z,ysort,base) · add_blocker(rect) · build_portal(pos,target,title)
# Sem callbacks, monta tudo aqui (sprites/labels/placeholders) — desacoplado do Main.
# --------------------------------------------------------------------------------------
func build_into(parent: Node, opts: Dictionary = {}) -> Dictionary:
	var summary := {"objects": 0, "blockers": 0, "portals": 0, "npc": 0, "service": 0, "mob": 0, "missing": 0, "warnings": 0, "tilemaps": 0, "tilecells": 0, "tileedges": 0}
	if parent == null:
		warnings.append("build_into: parent nulo")
		return summary
	mob_nodes = []
	var root := Node2D.new()
	root.name = "StudioMap"
	parent.add_child(root)

	# fundo (groundColor)
	var bg := ColorRect.new()
	bg.size = map_size()
	bg.color = _parse_color(str(map.get("groundColor", "#222222")))
	bg.z_index = -100
	root.add_child(bg)

	# objects (inclui pisos pintados = objetos `tilemap`)
	for o in objects:
		if o is Dictionary:
			if bool(o.get("tilemap", false)):
				_build_tilemap(root, o, summary)
			else:
				_build_object(root, o, opts)
				summary.objects += 1

	# blockers (Rect2 + opcional StaticBody2D + debug)
	var build_collision: bool = bool(opts.get("build_collision", true))
	for i in range(blocker_raw.size()):
		var b: Dictionary = blocker_raw[i]
		var rect: Rect2 = blockers[i]
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			warnings.append("blocker inválido (w/h<=0): %s" % str(b.get("id", i)))
		if opts.has("add_blocker") and opts["add_blocker"] is Callable:
			opts["add_blocker"].call(rect)
		elif build_collision:
			var body := StaticBody2D.new()
			body.position = rect.position + rect.size * 0.5
			var cs := CollisionShape2D.new()
			var shape := RectangleShape2D.new()
			shape.size = rect.size
			cs.shape = shape
			body.add_child(cs)
			root.add_child(body)
		var dbg := ColorRect.new()   # debug visual discreto
		dbg.size = rect.size
		dbg.position = rect.position
		dbg.color = Color(0.9, 0.3, 0.3, 0.18)
		dbg.z_index = 50
		root.add_child(dbg)
		summary.blockers += 1

	# portals (visual + dados; NÃO troca região de verdade aqui)
	for p in portals:
		if p is Dictionary:
			_build_portal(root, p, opts)
			summary.portals += 1

	# markers (npc / service / mob)
	for mk in markers:
		if not (mk is Dictionary): continue
		var kind := str(mk.get("kind", ""))
		match kind:
			"npc": _build_npc(root, mk); summary.npc += 1
			"service": _build_service(root, mk); summary.service += 1
			"mob": _build_mob(root, mk); summary.mob += 1
			_: _build_generic_marker(root, mk)

	# spawn do jogador (marcador)
	var sp := map_spawn()
	var spawn_tag := _make_label("SPAWN", sp + Vector2(-22, 20), Color(0.5, 0.66, 1.0))
	root.add_child(spawn_tag)

	summary.missing = _count_missing()
	summary.warnings = warnings.size()
	summary["mob_nodes"] = mob_nodes
	return summary

func _build_object(root: Node2D, o: Dictionary, opts: Dictionary) -> void:
	var asset: Variant = o.get("asset", null)
	var pos := Vector2(float(o.get("x", 0)), float(o.get("y", 0)))
	var ysort: bool = bool(o.get("ysort", false))
	var base_off: float = float(o.get("baseOffset", 0))
	var z: int = int(o.get("z", 0))
	# delega ao Main se houver callback e asset carregável
	if opts.has("add_prop") and opts["add_prop"] is Callable and _asset_loadable(asset):
		opts["add_prop"].call(resolve_asset_path(asset), pos, z, ysort, base_off)
		return
	var rp := resolve_asset_path(asset)
	if asset != null and str(asset) != "" and rp == "":
		warnings.append("asset externo ignorado: %s (%s)" % [str(asset), str(o.get("id", "?"))])
		_add_placeholder(root, o); return
	if rp != "" and not FileAccess.file_exists(rp):
		warnings.append("asset ausente: %s (%s)" % [rp, str(o.get("id", "?"))])
		_add_placeholder(root, o); return
	var tex: Texture2D = null
	if rp != "":
		tex = load(rp) as Texture2D
	if tex == null:
		warnings.append("asset não carregou (import?): %s (%s)" % [rp, str(o.get("id", "?"))])
		_add_placeholder(root, o); return
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.position = pos
	if bool(o.get("tile", false)):
		spr.centered = false
		spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		spr.region_enabled = true
		spr.region_rect = Rect2(0, 0, float(o.get("w", 256)), float(o.get("h", 256)))
	else:
		spr.scale = Vector2(float(o.get("scale", 1)), float(o.get("scale", 1)))
		var meta := _frame_meta(asset)
		var fw: int = int(o.get("frameW", 0))
		if fw <= 0: fw = int(meta.get("frameW", 0))
		if fw > 0 and tex.get_width() > fw:
			var fh: int = int(meta.get("frameH", 0))
			if fh <= 0: fh = tex.get_height()
			spr.region_enabled = true
			spr.region_rect = Rect2(0, 0, fw, fh)   # 1º quadro (linha 0 = "down" no 4dir)
	spr.z_index = int(pos.y + base_off) if ysort else z
	root.add_child(spr)

## Renderiza um objeto `tilemap` (piso pintado pelo Studio): 1 célula = 1 sprite escalado p/ tileSize.
## Agrupa as células num Node2D só; resolve o asset UMA vez (1 warning no máximo, não por célula).
func _build_tilemap(root: Node2D, o: Dictionary, summary: Dictionary) -> void:
	var cells: Variant = o.get("cells", [])
	if not (cells is Array):
		warnings.append("tilemap com cells inválido: %s" % str(o.get("id", "?")))
		return
	var ts := float(o.get("tileSize", 32))
	if ts <= 0.0: ts = 32.0
	var asset: Variant = o.get("asset", null)
	var holder := Node2D.new()
	holder.name = "Tilemap"
	holder.z_index = int(o.get("z", -20))
	root.add_child(holder)
	summary.tilemaps += 1
	# resolve o asset 1× (warning único)
	var rp := resolve_asset_path(asset)
	var tex: Texture2D = null
	if asset != null and str(asset) != "" and rp == "":
		warnings.append("tilemap asset externo ignorado: %s (%s)" % [str(asset), str(o.get("id", "?"))])
	elif rp != "" and not FileAccess.file_exists(rp):
		warnings.append("tilemap asset ausente: %s (%s)" % [rp, str(o.get("id", "?"))])
	elif rp != "":
		tex = load(rp) as Texture2D
		if tex == null:
			warnings.append("tilemap asset não carregou (import?): %s" % rp)
	var tw := tex.get_width() if tex != null else 0
	var th := tex.get_height() if tex != null else 0
	var n := 0
	for k in cells:
		var parts := str(k).split(",")
		if parts.size() != 2:
			continue   # célula malformada → ignora, sem crash
		var c := int(parts[0])
		var r := int(parts[1])
		var x := c * ts
		var y := r * ts
		if tex != null and tw > 0 and th > 0:
			var spr := Sprite2D.new()
			spr.texture = tex
			spr.centered = false
			spr.position = Vector2(x, y)
			spr.scale = Vector2(ts / float(tw), ts / float(th))   # PNG escalado p/ a célula
			holder.add_child(spr)
		else:
			var cr := ColorRect.new()
			cr.size = Vector2(ts, ts)
			cr.position = Vector2(x, y)
			cr.color = Color(0.47, 0.47, 0.55, 0.5)   # placeholder discreto
			holder.add_child(cr)
		n += 1
	summary.tilecells += n

	# --- auto-acabamento (autotile v1 = "edge tufts"): tufos nas bordas EXPOSTAS ---
	# Mesma fórmula determinística do Studio (core.tileEdges). Sem corner tiles (não há assets).
	if bool(o.get("autoEdge", false)):
		var edge_assets: Variant = o.get("edgeAssets", [])
		if edge_assets is Array and edge_assets.size() > 0:
			var tuft: Array = []
			var warned := false
			for ea in edge_assets:
				var erp := resolve_asset_path(ea)
				var et: Texture2D = null
				if erp != "" and FileAccess.file_exists(erp):
					et = load(erp) as Texture2D
				if et == null and not warned:
					warnings.append("tilemap: asset de transição ausente/não carregou: %s (%s)" % [str(ea), str(o.get("id", "?"))])
					warned = true
				tuft.append(et)
			var sz := tuft.size()
			var cset := {}
			for k in cells:
				cset[str(k)] = true
			var esz := ts * 0.72
			var ne := 0
			for k in cells:
				var parts := str(k).split(",")
				if parts.size() != 2: continue
				var c := int(parts[0]); var r := int(parts[1]); var x := c * ts; var y := r * ts
				var sides := [
					[not cset.has("%d,%d" % [c, r - 1]), Vector2(x + ts / 2.0, y), 0],
					[not cset.has("%d,%d" % [c, r + 1]), Vector2(x + ts / 2.0, y + ts), 1],
					[not cset.has("%d,%d" % [c + 1, r]), Vector2(x + ts, y + ts / 2.0), 2],
					[not cset.has("%d,%d" % [c - 1, r]), Vector2(x, y + ts / 2.0), 3],
				]
				for s in sides:
					if not s[0]: continue
					var v := ((c * 3 + r * 7 + int(s[2])) % sz + sz) % sz
					var et2: Texture2D = tuft[v]
					if et2 == null: continue
					var spr := Sprite2D.new()
					spr.texture = et2
					spr.centered = true
					spr.position = s[1]
					spr.z_index = int(o.get("z", -20)) + 1
					spr.scale = Vector2(esz / float(et2.get_width()), esz / float(et2.get_height()))
					holder.add_child(spr)
					ne += 1
			summary.tileedges += ne

func _add_placeholder(root: Node2D, o: Dictionary) -> void:
	var ph := ColorRect.new()
	var w: float = float(o.get("w", 48)) if bool(o.get("tile", false)) else 48.0
	var h: float = float(o.get("h", 48)) if bool(o.get("tile", false)) else 48.0
	ph.size = Vector2(w, h)
	ph.position = Vector2(float(o.get("x", 0)) - w * 0.5, float(o.get("y", 0)) - h * 0.5)
	ph.color = Color(0.8, 0.2, 0.8, 0.5)
	ph.z_index = int(o.get("z", 0))
	root.add_child(ph)

func _build_portal(root: Node2D, p: Dictionary, opts: Dictionary) -> void:
	var pos := Vector2(float(p.get("x", 0)), float(p.get("y", 0)))
	var title := str(p.get("title", "Portal"))
	var target := str(p.get("target", ""))
	if target == "":
		warnings.append("portal sem target: %s" % str(p.get("id", "?")))
	if opts.has("build_portal") and opts["build_portal"] is Callable:
		opts["build_portal"].call(pos, target, title)
		return
	var node := Node2D.new()
	node.position = pos
	var door := ColorRect.new()
	door.size = Vector2(70, 110); door.position = Vector2(-35, -55)
	door.color = Color(0.08, 0.09, 0.13, 0.92)
	node.add_child(door)
	node.add_child(_make_label("%s → %s" % [title, target], Vector2(-60, 60), Color("e8c267")))
	root.add_child(node)

func _build_npc(root: Node2D, mk: Dictionary) -> void:
	var def := get_npc(str(mk.get("npcId", "")))
	var nm := str(mk.get("name", "")) if str(mk.get("name", "")) != "" else str(def.get("name", "NPC"))
	var asset: Variant = mk.get("asset", null)
	if (asset == null or str(asset) == "") and not def.is_empty():
		asset = def.get("asset", null)
	_marker_sprite_or_dot(root, mk, asset, Color(0.43, 0.84, 0.88))
	root.add_child(_make_label("☻ " + nm, Vector2(float(mk.get("x", 0)) - 30, float(mk.get("y", 0)) + 18), Color(0.43, 0.84, 0.88)))

func _build_service(root: Node2D, mk: Dictionary) -> void:
	var def := get_service(str(mk.get("serviceId", "")))
	var kind := str(mk.get("serviceKind", "")) if str(mk.get("serviceKind", "")) != "" else str(def.get("serviceKind", ""))
	var nm := str(mk.get("name", "")) if str(mk.get("name", "")) != "" else str(def.get("name", "serviço"))
	if kind == "":
		warnings.append("service marker sem serviceKind/serviceId: %s" % str(mk.get("id", "?")))
	_marker_sprite_or_dot(root, mk, mk.get("asset", null), Color(0.62, 0.88, 0.63))
	root.add_child(_make_label("✦ %s [%s]" % [nm, kind], Vector2(float(mk.get("x", 0)) - 30, float(mk.get("y", 0)) + 18), Color(0.62, 0.88, 0.63)))

func _build_mob(root: Node2D, mk: Dictionary) -> void:
	var mob_id := str(mk.get("mobId", ""))
	var def := get_mob(mob_id)
	var nm := str(def.get("name", "")) if not def.is_empty() else str(mk.get("name", "mob"))
	var asset: Variant = mk.get("asset", null)
	if (asset == null or str(asset) == "") and not def.is_empty():
		asset = def.get("asset", null)
	# Regra do projeto: atores/mobs novos devem ser 4-dir — avisa se o Asset Bank marca lateral provisório.
	var ab := asset_bank_for_path(str(asset))
	if not ab.is_empty() and str(ab.get("directionMode", "")) == "side":
		warnings.append("mob '%s' usa sprite lateral provisório (ideal 4dir): %s" % [mob_id, str(asset)])
	var node := _marker_sprite_or_dot(root, mk, asset, Color(0.88, 0.48, 0.48))
	root.add_child(_make_label("✸ " + nm, Vector2(float(mk.get("x", 0)) - 24, float(mk.get("y", 0)) + 18), Color(0.88, 0.48, 0.48)))
	mob_nodes.append({ "node": node, "origin": Vector2(float(mk.get("x", 0)), float(mk.get("y", 0))), "radius": float(mk.get("radius", 0)), "mobId": mob_id })

func _build_generic_marker(root: Node2D, mk: Dictionary) -> void:
	_marker_sprite_or_dot(root, mk, mk.get("asset", null), Color(0.8, 0.8, 0.8))

func _marker_sprite_or_dot(root: Node2D, mk: Dictionary, asset: Variant, dot: Color) -> Node:
	var pos := Vector2(float(mk.get("x", 0)), float(mk.get("y", 0)))
	if _asset_loadable(asset):
		var tex := load(resolve_asset_path(asset)) as Texture2D
		if tex != null:
			var spr := Sprite2D.new()
			spr.texture = tex
			spr.position = pos
			var meta := _frame_meta(asset)
			var fw: int = int(mk.get("frameW", 0))
			if fw <= 0: fw = int(meta.get("frameW", 0))
			if fw > 0 and tex.get_width() > fw:
				var fh: int = int(meta.get("frameH", 0))
				if fh <= 0: fh = tex.get_height()
				spr.region_enabled = true
				spr.region_rect = Rect2(0, 0, fw, fh)
			spr.z_index = int(pos.y)
			root.add_child(spr)
			return spr
	if asset != null and str(asset) != "" and resolve_asset_path(asset) == "":
		warnings.append("marker asset externo ignorado: %s" % str(asset))
	elif asset != null and str(asset) != "" and not FileAccess.file_exists(resolve_asset_path(asset)):
		warnings.append("marker asset ausente: %s" % str(asset))
	var c := ColorRect.new()
	c.size = Vector2(20, 20); c.position = pos - Vector2(10, 10)
	c.color = dot; c.z_index = int(pos.y)
	root.add_child(c)
	return c

func _make_label(text: String, pos: Vector2, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.modulate = col
	l.z_as_relative = false
	l.z_index = 4000
	return l

func _parse_color(s: String) -> Color:
	if s.begins_with("#") and (s.length() == 7 or s.length() == 9):
		return Color.html(s)
	return Color(0.13, 0.16, 0.13)

func _count_missing() -> int:
	var n := 0
	for w in warnings:
		if str(w).find("ausente") != -1 or str(w).find("não carregou") != -1 or str(w).find("externo") != -1:
			n += 1
	return n
