class_name HudArtPack extends RefCounted
## A35 — carregador do HUD ART PACK 01 (data-driven pelo manifest REAL). Dá textura + patch_margins + size por id,
## respeitando `do_not_integrate_currently` (mana/minimap = PROVISIONAL, NUNCA integrados §5/§15). Sem inventar nomes:
## tudo vem de `hud_art_pack_01_manifest.json`. NinePatch usa as margens do manifest (§18).

const BASE := "res://assets/ui/hud_target_v1/"
const MANIFEST := BASE + "hud_art_pack_01_manifest.json"

static var _by_file: Dictionary = {}     # "frames/top_frame_center.png" -> entry
static var _by_base: Dictionary = {}     # "top_frame_center" -> entry (basename sem ext; 1º que aparecer)
static var _loaded := false

static func _ensure() -> void:
	if _loaded: return
	_loaded = true
	if not FileAccess.file_exists(MANIFEST): return
	var txt := FileAccess.get_file_as_string(MANIFEST)
	var data = JSON.parse_string(txt)
	if data == null or not (data is Dictionary): return
	for e in data.get("entries", []):
		var f := str((e as Dictionary).get("file", ""))
		if f == "": continue
		_by_file[f] = e
		var b := f.get_file().get_basename()
		if not _by_base.has(b): _by_base[b] = e

static func _entry(id: String) -> Dictionary:
	_ensure()
	if _by_file.has(id): return _by_file[id]
	if _by_base.has(id): return _by_base[id]
	# aceita "frames/x" e "x" e "x.png"
	var b := id.get_file().get_basename()
	if _by_base.has(b): return _by_base[b]
	return {}

## A36 — caminho direto (arquivo REAL no disco) quando o id é uma path relativa não coberta pelo manifest
## (ex.: HUD NAV ICON PACK 02, entregue depois do manifest). Sem inventar: só resolve se o arquivo existe.
static func _direct_path(id: String) -> String:
	if id.ends_with(".png") and id.contains("/"):
		var p := BASE + id
		if ResourceLoader.exists(p): return p
	return ""

static func has(id: String) -> bool:
	return not _entry(id).is_empty() or _direct_path(id) != ""

## PROVISIONAL / não-integrável agora (mana, minimap, mockups) — a integração pula estes (§5/§15/§27).
static func integrable(id: String) -> bool:
	var e := _entry(id)
	if not e.is_empty():
		return not bool(e.get("do_not_integrate_currently", false)) and not bool(e.get("provisional", false))
	return _direct_path(id) != ""   # fora do manifest mas real no disco (Pack 02) ⇒ integrável

static func path(id: String) -> String:
	var e := _entry(id)
	if not e.is_empty(): return BASE + str(e.get("file", ""))
	return _direct_path(id)

static func tex(id: String) -> Texture2D:
	var p := path(id)
	if p == "" or not ResourceLoader.exists(p): return null
	return load(p) as Texture2D

static func patch(id: String) -> Array:
	var e := _entry(id)
	return e.get("patch_margins", [0, 0, 0, 0]) if not e.is_empty() else [0, 0, 0, 0]

static func size_of(id: String) -> Vector2i:
	var e := _entry(id)
	var s: Dictionary = e.get("size", {}) if not e.is_empty() else {}
	return Vector2i(int(s.get("w", 0)), int(s.get("h", 0)))

static func all_files() -> Array:
	_ensure(); return _by_file.keys()

## Fábrica de NinePatchRect com as margens do manifest (respeita ornamento — §18). null se não integrável/ausente.
static func nine(id: String) -> NinePatchRect:
	if not integrable(id): return null
	var t := tex(id)
	if t == null: return null
	var np := NinePatchRect.new()
	np.texture = t
	var pm := patch(id)
	np.patch_margin_left = int(pm[0]); np.patch_margin_top = int(pm[1])
	np.patch_margin_right = int(pm[2]); np.patch_margin_bottom = int(pm[3])
	np.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return np

## A36 — StyleBoxTexture da família de painéis (fundo esticável com as margens do manifest §18). null se ausente.
## Ideal p/ PanelContainer (`add_theme_stylebox_override("panel", ...)`) — reskin sem tocar a estrutura de filhos.
static func panel_stylebox(id: String) -> StyleBoxTexture:
	if not integrable(id): return null
	var t := tex(id)
	if t == null: return null
	var sb := StyleBoxTexture.new()
	sb.texture = t
	var pm := patch(id)
	sb.set_texture_margin(SIDE_LEFT, float(pm[0])); sb.set_texture_margin(SIDE_TOP, float(pm[1]))
	sb.set_texture_margin(SIDE_RIGHT, float(pm[2])); sb.set_texture_margin(SIDE_BOTTOM, float(pm[3]))
	sb.set_content_margin(SIDE_LEFT, 16.0); sb.set_content_margin(SIDE_TOP, 16.0)
	sb.set_content_margin(SIDE_RIGHT, 16.0); sb.set_content_margin(SIDE_BOTTOM, 16.0)
	return sb

## Sprite simples (TextureRect) de um ícone/estado — escala mantendo aspecto. null se ausente/não-integrável.
static func icon(id: String, px: float) -> TextureRect:
	if not integrable(id): return null
	var t := tex(id)
	if t == null: return null
	var tr := TextureRect.new()
	tr.texture = t
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(px, px)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

## Validação (para o teste HUD35ASSET): arquivo existe + dimensões batem com o manifest.
static func validate_entry(id: String) -> Dictionary:
	var e := _entry(id)
	if e.is_empty():
		# A36 — fora do manifest, mas arquivo REAL no disco (Pack 02) = válido se carrega
		var dp := _direct_path(id)
		if dp == "": return {"ok": false, "reason": "não no manifest nem no disco"}
		return {"ok": true} if (load(dp) as Texture2D) != null else {"ok": false, "reason": "não carrega textura"}
	var p := BASE + str(e.get("file", ""))
	if not ResourceLoader.exists(p): return {"ok": false, "reason": "arquivo ausente: " + p}
	var t := load(p) as Texture2D
	if t == null: return {"ok": false, "reason": "não carrega textura"}
	var want := size_of(id)
	var got := t.get_size()
	if want.x > 0 and (int(got.x) != want.x or int(got.y) != want.y):
		return {"ok": false, "reason": "dimensão %dx%d != manifest %dx%d" % [int(got.x), int(got.y), want.x, want.y]}
	return {"ok": true}
