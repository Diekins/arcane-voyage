class_name CombatVfx
extends AnimatedSprite2D
## CombatVfx — overlay de VFX de combate curto e auto-destrutivo (GODOT-COMBAT-VFX-WEAPON-INTEGRATION-1).
## Fatia o atlas `attack_vfx_overlay_atlas_02_alpha.png` (972×1619, 4 frames/linha de 243px) em strips de
## 4 quadros por efeito. As bandas Y de cada linha foram MEDIDAS no atlas (perfil de opacidade, ignorando
## os separadores). Toca uma vez e some sozinho (animation_finished → queue_free). NÃO captura input, NÃO
## toca em dano/cooldown — é só apresentação. Fallback seguro: se o atlas/efeito faltar, não faz nada.

const ATLAS := "res://assets/vfx/combat/attack_vfx_overlay_atlas_02_alpha.png"
const FRAME_W := 243
const FRAMES := 4

## nome do efeito → [y_topo, altura] da banda no atlas (medido; separadores já ignorados).
const ROWS := {
	"slash_arc_down_overlay": [36, 71], "slash_arc_side_overlay": [145, 46], "slash_arc_up_overlay": [217, 60],
	"thrust_line_down_overlay": [367, 43], "thrust_line_side_overlay": [455, 26], "thrust_line_up_overlay": [528, 74],
	"arrow_trail_side_overlay": [645, 30],
	"projectile_magic_blue": [729, 44], "projectile_magic_violet": [837, 20],
	"impact_small_physical": [922, 29], "impact_large_critical": [990, 70], "impact_blue_magic": [1092, 56],
	"ground_telegraph_orange": [1194, 50], "ground_telegraph_blue_boss": [1272, 76],
	"heal_ring_green_blue": [1372, 80], "dust_step_whoosh": [1493, 80],
}

## escala de EXIBIÇÃO por efeito (o frame nativo tem 243px; o conteúdo é menor) → tamanho sensato no mundo.
const BASE_SCALE := {
	"slash_arc_down_overlay": 0.6, "slash_arc_side_overlay": 0.6, "slash_arc_up_overlay": 0.6,
	"thrust_line_down_overlay": 0.65, "thrust_line_side_overlay": 0.65, "thrust_line_up_overlay": 0.65,
	"arrow_trail_side_overlay": 0.65,
	"projectile_magic_blue": 0.5, "projectile_magic_violet": 0.5,
	"impact_small_physical": 0.9, "impact_large_critical": 1.1, "impact_blue_magic": 0.9,
	"ground_telegraph_orange": 1.0, "ground_telegraph_blue_boss": 1.0,
	"heal_ring_green_blue": 0.75, "dust_step_whoosh": 0.7,
}

# ─────────────────────────── BIBLIOTECA DE CLASSE (VISUAL ASSET INTEGRATION WAVE 1) ───────────────────────────
## Segunda FONTE de VFX, aditiva: strips de arquivo (1 PNG por efeito) do `class_combat_vfx_library_pack_01`.
## Contrato do strip: RGBA, horizontal, `largura % altura == 0`, 4 quadros de altura×altura (mesma regra do
## ActorAssetValidator). Diferente do ATLAS acima (uma folha fatiada por bandas Y medidas), aqui cada efeito é
## um arquivo — por isso o registro é DERIVADO do disco, não de coordenadas escritas à mão.
## ⚠️ A resolução em `spawn()` é: LIB → UPGRADE → ROWS(atlas) → null. Nomes antigos continuam válidos.
const LIB_DIR := "res://assets/vfx/classes"

## efeito → subpasta. Só isto é escrito à mão; o resto (frames, escala) sai da própria textura.
const LIB := {
	"melee_basic_accent": "melee", "melee_heavy_arc": "melee",
	"melee_signature_impact": "melee", "melee_guard_response": "melee",
	"magic_basic_cast": "magic", "magic_heavy_burst": "magic",
	"magic_signature_field": "magic", "magic_barrier_response": "magic",
	"ranged_basic_trail": "ranged", "ranged_heavy_shot": "ranged",
	"ranged_signature_volley": "ranged", "ranged_evasion_response": "ranged",
	"reach_basic_sweep": "reach", "reach_heavy_thrust": "reach",
	"reach_signature_cleave": "reach", "reach_spacing_response": "reach",
	"support_basic_offense": "support", "support_empowerment": "support",
	"support_signature_pulse": "support", "support_protection": "support",
	"physical_hit_small": "common_hits", "physical_hit_heavy": "common_hits",
	"arcane_hit_small": "common_hits", "arcane_hit_heavy": "common_hits",
	"support_hit": "common_hits", "critical_hit_accent": "common_hits",
}

## Tamanho de EXIBIÇÃO alvo por altura-de-quadro nativa. O pack tem 3 escalões (128/256/512) e sem isto um
## quadro de 512px entraria ~4× maior que um de 128px na mesma cena. Alinhado com o atlas legado, cujo quadro
## nativo de 243px desenha em ~150–270px de mundo.
const LIB_TARGET_PX := {128: 160.0, 256: 260.0, 512: 420.0}

## Nome ANTIGO (atlas) → nome NOVO (biblioteca), onde a semântica é a MESMA. Existe para que as chamadas já
## espalhadas pelo jogo herdem a arte nova sem edição em massa. ⛔ Só entram equivalências exatas: os efeitos
## de MOVIMENTO de arma (slash/thrust/arrow) e os telegrafos/heal NÃO têm par no pack novo — ficam no atlas.
## Reversível numa linha: esvazie este dicionário e tudo volta ao atlas.
const UPGRADE := {
	"impact_small_physical": "physical_hit_small",
	"impact_large_critical": "critical_hit_accent",
	"impact_blue_magic": "arcane_hit_small",
}

## ─── REGISTRO POR ARQUÉTIPO ───
## Chave = o que `GameState.current_combat_archetype()` devolve (melee/ranged/magic/reach/support), derivado
## do SLOT/weapon_kind — não de nome textual de arma. Assim o call site pede um PAPEL ("bateu forte") e o
## arquétipo escolhe a arte, sem `if classe ==` espalhado pelo jogo.
## ⛔ Nenhuma destas entradas é uma HABILIDADE: são acentos de apresentação. Não existe skill nova aqui.
const CLASS_FX := {
	"melee":   {"basic": "melee_basic_accent",     "heavy": "melee_heavy_arc",      "signature": "melee_signature_impact",     "response": "melee_guard_response"},
	"magic":   {"basic": "magic_basic_cast",       "heavy": "magic_heavy_burst",    "signature": "magic_signature_field",      "response": "magic_barrier_response"},
	"ranged":  {"basic": "ranged_basic_trail",     "heavy": "ranged_heavy_shot",    "signature": "ranged_signature_volley",    "response": "ranged_evasion_response"},
	"reach":   {"basic": "reach_basic_sweep",      "heavy": "reach_heavy_thrust",   "signature": "reach_signature_cleave",     "response": "reach_spacing_response"},
	"support": {"basic": "support_basic_offense",  "heavy": "support_empowerment",  "signature": "support_signature_pulse",    "response": "support_protection"},
}

## Arquétipos cujo IMPACTO lê como arcano em vez de físico (define o hit comum, não o dano).
const ARCANE_ARCHETYPES := ["magic", "support"]

## Efeito de classe por PAPEL. Cai em melee se o arquétipo for desconhecido (fallback documentado).
static func class_effect(archetype: String, role := "basic") -> String:
	var d: Dictionary = CLASS_FX.get(archetype, CLASS_FX["melee"])
	return str(d.get(role, d["basic"]))

## Hit comum por arquétipo e peso. `heavy` troca o pequeno pelo grande; `crit` vence os dois.
static func hit_effect(archetype: String, heavy := false, crit := false) -> String:
	if crit:
		return "critical_hit_accent"
	if archetype == "support":
		return "support_hit"
	var arcane: bool = ARCANE_ARCHETYPES.has(archetype)
	if arcane:
		return "arcane_hit_heavy" if heavy else "arcane_hit_small"
	return "physical_hit_heavy" if heavy else "physical_hit_small"

## Monta os SpriteFrames de um strip de arquivo. Retorna null se faltar/violar o contrato (fallback seguro).
static func _lib_frames(effect: String, fps: float) -> SpriteFrames:
	if not LIB.has(effect):
		return null
	var path := "%s/%s/%s.png" % [LIB_DIR, str(LIB[effect]), effect]
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		return null
	var h: int = tex.get_height()
	var w: int = tex.get_width()
	if h <= 0 or w % h != 0:
		return null                     # contrato do strip violado → não desenha lixo
	var frames := SpriteFrames.new()
	frames.add_animation("p")
	frames.set_animation_loop("p", false)
	frames.set_animation_speed("p", fps)
	for i in range(w / h):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * h, 0, h, h)
		frames.add_frame("p", at)
	return frames

## Escala de exibição de um strip: normaliza os 3 escalões nativos para tamanhos de mundo comparáveis.
static func _lib_scale(frames: SpriteFrames) -> float:
	var f: Texture2D = frames.get_frame_texture("p", 0)
	if f == null:
		return 1.0
	var h: int = f.get_height()
	return float(LIB_TARGET_PX.get(h, 160.0)) / maxf(1.0, float(h))

## Resolve o nome pedido para um nome da BIBLIOTECA, ou "" se este efeito continua sendo do atlas.
static func resolve_library_name(effect: String) -> String:
	if LIB.has(effect):
		return effect
	var up := str(UPGRADE.get(effect, ""))
	return up if LIB.has(up) else ""

## Toca um efeito por NOME EXATO em `parent`, centrado em `pos`. `dir` define o flip horizontal (efeitos
## "side" encaram a esquerda quando dir.x<0). `rot` rotaciona (ex.: bolt na direção da mira). `scl_mult`
## multiplica a escala-base. Retorna o nó (ou null se faltar atlas/efeito = fallback seguro).
static func spawn(parent: Node, effect: String, pos: Vector2, dir := Vector2.RIGHT, scl_mult := 1.0, fps := 20.0, mod := Color(1, 1, 1, 1), rot := 0.0) -> Node:
	if parent == null:
		return null
	# ── 1) biblioteca de classe (arte nova, strip de arquivo) ──
	var lib_name := resolve_library_name(effect)
	if lib_name != "":
		var lf := _lib_frames(lib_name, fps)
		if lf != null:
			return _finish(parent, lf, pos, dir, _lib_scale(lf) * scl_mult, mod, rot)
		# strip ausente/inválido → NÃO retorna: cai no atlas abaixo se o nome original for de lá
	# ── 2) atlas legado ──
	if not ROWS.has(effect) or not ResourceLoader.exists(ATLAS):
		return null
	var tex = load(ATLAS)
	if tex == null:
		return null
	var band: Array = ROWS[effect]
	var frames := SpriteFrames.new()
	frames.add_animation("p")
	frames.set_animation_loop("p", false)
	frames.set_animation_speed("p", fps)
	for i in range(FRAMES):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * FRAME_W, float(band[0]), FRAME_W, float(band[1]))
		frames.add_frame("p", at)
	return _finish(parent, frames, pos, dir, float(BASE_SCALE.get(effect, 0.6)) * scl_mult, mod, rot)

## Instancia/parenteia/toca. Extraído para que ATLAS e BIBLIOTECA compartilhem exatamente a mesma
## apresentação (z-index, centragem, flip, auto-destruição) — dois caminhos de arte, um só comportamento.
static func _finish(parent: Node, frames: SpriteFrames, pos: Vector2, dir: Vector2, scl: float, mod: Color, rot: float) -> Node:
	var spr := CombatVfx.new()
	spr.sprite_frames = frames
	spr.animation = "p"
	spr.centered = true
	spr.position = pos
	spr.scale = Vector2.ONE * scl
	spr.modulate = mod
	spr.rotation = rot
	spr.z_index = 4095          # acima dos atores/props/números (≤ CANVAS_ITEM_Z_MAX=4096; 5000 estourava e spammava erro)
	spr.z_as_relative = false
	if absf(dir.x) >= absf(dir.y) and dir.x < 0.0:
		spr.flip_h = true       # efeito lateral encarando a esquerda
	spr.animation_finished.connect(spr.queue_free)
	parent.add_child(spr)
	spr.play("p")
	return spr

## Resolve a variante direcional de um efeito de base ("slash_arc"/"thrust_line"/"arrow_trail") conforme
## `dir`: usa _up/_down/_side_overlay se existir; senão cai no _side_overlay rotacionado (documentado).
static func spawn_directional(parent: Node, base: String, pos: Vector2, dir: Vector2, scl_mult := 1.0, fps := 20.0, mod := Color(1, 1, 1, 1)) -> Node:
	var d := dir if dir.length() > 0.01 else Vector2.DOWN
	var eff := base + "_side_overlay"
	var rot := 0.0
	if absf(d.y) > absf(d.x):
		var want := base + ("_up_overlay" if d.y < 0.0 else "_down_overlay")
		if ROWS.has(want):
			eff = want
		else:
			eff = base + "_side_overlay"   # fallback: gira o lateral p/ cima/baixo
			rot = -PI / 2.0 if d.y < 0.0 else PI / 2.0
	return spawn(parent, eff, pos, d, scl_mult, fps, mod, rot)
