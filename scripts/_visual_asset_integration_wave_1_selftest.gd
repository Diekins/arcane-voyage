extends SceneTree
## VISUAL ASSET INTEGRATION WAVE 1 — prova de que a arte NOVA entrou no RUNTIME de verdade.
##
## ⛔ NÃO boota Main.tscn, NÃO roda combate, NÃO faz spawn de mob. É uma suíte de ASSET + API:
## responde "o PNG existe, importa, carrega, respeita o contrato de strip, e o CombatVfx real o desenha?".
## Sem cena = sem risco de single-frame DoS (ver TEST_HARNESS_SCENE_REAL_SAFETY.md). Roda em ~2s.
##
## ★★★ O que esta suíte NÃO promete: que o efeito APAREÇA na tela durante a caça. Isso depende de o call
## site chamar CombatVfx.spawn — coisa que só o field prova. Aqui mede-se a CAMADA DE ARTE, na fronteira dela.
##
## Uso: --headless --path <proj> --script res://scripts/_visual_asset_integration_wave_1_selftest.gd
## Exit 0 = tudo passou · 1 = alguma asserção falhou.

var _pass := 0
var _fail := 0
var _group := ""

func _g(name: String) -> void:
	_group = name
	print("\n── %s ──" % name)

func _ck(id: String, cond: bool, detail := "") -> void:
	if cond:
		_pass += 1
		print("   OK   %-34s %s" % [id, detail])
	else:
		_fail += 1
		print("   FAIL %-34s %s" % [id, detail])

## Posição do último filho, ou INF se não houver. Existe porque `get_child(-1)` ESTOURA e a suíte trava
## sem imprimir resumo — falha de MEDIDOR virando falso "congelou", não reprovação honesta.
func _ultimo_pos(p: Node) -> Vector2:
	if p.get_child_count() <= 0:
		return Vector2.INF
	var n := p.get_child(p.get_child_count() - 1) as Node2D
	return n.position if n != null else Vector2.INF

func _initialize() -> void:
	print("═════════ VISUAL ASSET INTEGRATION WAVE 1 — SELFTEST ═════════")

	# ── G1: os 26 strips existem, importam e carregam ──────────────────────────────
	_g("G1 — EXISTÊNCIA E CARGA DOS 26 STRIPS")
	var missing: Array = []
	var loaded := 0
	for effect in CombatVfx.LIB:
		var path := "%s/%s/%s.png" % [CombatVfx.LIB_DIR, str(CombatVfx.LIB[effect]), effect]
		var tex: Texture2D = (load(path) as Texture2D) if ResourceLoader.exists(path) else null
		if tex == null:
			missing.append(effect)
		else:
			loaded += 1
	_ck("LIB tem 26 entradas", CombatVfx.LIB.size() == 26, "size=%d" % CombatVfx.LIB.size())
	_ck("todos carregam", missing.is_empty(), "carregados=%d faltando=%s" % [loaded, str(missing)])

	# ── G2: contrato de strip (largura % altura == 0, 4 quadros, RGBA) ─────────────
	_g("G2 — CONTRATO DE STRIP (largura %% altura == 0)")
	var bad_ratio: Array = []
	var bad_count: Array = []
	var sizes := {}
	for effect in CombatVfx.LIB:
		var path := "%s/%s/%s.png" % [CombatVfx.LIB_DIR, str(CombatVfx.LIB[effect]), effect]
		var tex: Texture2D = load(path) as Texture2D
		if tex == null:
			continue
		var w: int = tex.get_width()
		var h: int = tex.get_height()
		if h <= 0 or w % h != 0:
			bad_ratio.append("%s(%dx%d)" % [effect, w, h])
			continue
		var fc: int = w / h
		if fc != 4:
			bad_count.append("%s(frames=%d)" % [effect, fc])
		sizes[h] = int(sizes.get(h, 0)) + 1
	_ck("nenhum viola largura%%altura", bad_ratio.is_empty(), str(bad_ratio))
	_ck("todos com 4 quadros", bad_count.is_empty(), str(bad_count))
	_ck("escalões nativos conhecidos", sizes.keys().all(func(k): return CombatVfx.LIB_TARGET_PX.has(k)), "alturas=%s" % str(sizes))

	# ── G3: o MONTADOR real entrega SpriteFrames de 4 quadros ─────────────────────
	# Mede a função que o jogo usa, não uma releitura do PNG. Se _lib_frames mudar e quebrar, cai aqui.
	_g("G3 — MONTAGEM VIA API REAL (_lib_frames)")
	var built := 0
	var build_fail: Array = []
	for effect in CombatVfx.LIB:
		var fr: SpriteFrames = CombatVfx._lib_frames(str(effect), 20.0)
		if fr == null or fr.get_frame_count("p") != 4:
			build_fail.append(effect)
		else:
			built += 1
	_ck("26 montados com 4 quadros", build_fail.is_empty(), "montados=%d falhas=%s" % [built, str(build_fail)])
	var f0: SpriteFrames = CombatVfx._lib_frames("melee_basic_accent", 20.0)
	_ck("não faz loop (toca 1×)", f0 != null and not f0.get_animation_loop("p"))
	var reg: AtlasTexture = f0.get_frame_texture("p", 1) as AtlasTexture if f0 != null else null
	_ck("quadro 2 é região deslocada", reg != null and reg.region.position.x == 128.0 and reg.region.size == Vector2(128, 128), str(reg.region) if reg != null else "null")

	# ── G4: normalização de escala entre os 3 escalões nativos ────────────────────
	# Sem isto um quadro de 512px entra ~4× maior que um de 128px. Mede-se o TAMANHO DE MUNDO resultante.
	_g("G4 — NORMALIZAÇÃO DE ESCALA (128/256/512 → mundo comparável)")
	var holder := Node2D.new()
	root.add_child(holder)
	var world := {}
	for effect in ["melee_basic_accent", "melee_heavy_arc", "melee_signature_impact"]:
		var n = CombatVfx.spawn(holder, effect, Vector2.ZERO)
		if n == null:
			_ck("spawn %s" % effect, false, "retornou null")
			continue
		var spr := n as AnimatedSprite2D
		var h: float = float(spr.sprite_frames.get_frame_texture("p", 0).get_height())
		world[effect] = h * spr.scale.x
	_ck("accent 128 → ~160px", absf(float(world.get("melee_basic_accent", 0.0)) - 160.0) < 1.0, "%.0f px" % float(world.get("melee_basic_accent", 0.0)))
	_ck("heavy 256 → ~260px", absf(float(world.get("melee_heavy_arc", 0.0)) - 260.0) < 1.0, "%.0f px" % float(world.get("melee_heavy_arc", 0.0)))
	_ck("signature 512 → ~420px", absf(float(world.get("melee_signature_impact", 0.0)) - 420.0) < 1.0, "%.0f px" % float(world.get("melee_signature_impact", 0.0)))
	var maior: float = float(world.get("melee_signature_impact", 0.0))
	var menor: float = float(world.get("melee_basic_accent", 1.0))
	_ck("razão maior/menor < 4× (nativo era 4×)", menor > 0.0 and (maior / menor) < 4.0, "%.2fx" % (maior / maxf(menor, 1.0)))

	# ── G5: os 3 UPGRADES herdam a arte nova sem editar call site ─────────────────
	# ★★★ Este é o grupo que prova INTEGRAÇÃO, não só materialização: um nome ANTIGO tem que sair NOVO.
	_g("G5 — UPGRADE DE NOMES ANTIGOS (atlas → biblioteca)")
	for velho in CombatVfx.UPGRADE:
		var novo := str(CombatVfx.UPGRADE[velho])
		_ck("%s resolve" % velho, CombatVfx.resolve_library_name(str(velho)) == novo, "→ %s" % novo)
		var n = CombatVfx.spawn(holder, str(velho), Vector2.ZERO)
		var ok_tex := false
		if n != null:
			var at: AtlasTexture = (n as AnimatedSprite2D).sprite_frames.get_frame_texture("p", 0) as AtlasTexture
			ok_tex = at != null and at.atlas != null and str(at.atlas.resource_path).contains(novo)
		_ck("%s desenha o strip novo" % velho, ok_tex)

	# ── G6: fallback do atlas legado INTACTO (não-regressão) ──────────────────────
	# O que NÃO tem par no pack novo (movimento de arma, telegrafo, heal) precisa continuar saindo do atlas.
	_g("G6 — ATLAS LEGADO PRESERVADO (não-regressão)")
	for legado in ["slash_arc_down_overlay", "thrust_line_side_overlay", "heal_ring_green_blue", "ground_telegraph_blue_boss"]:
		_ck("%s NÃO foi sequestrado" % legado, CombatVfx.resolve_library_name(legado) == "")
		var n = CombatVfx.spawn(holder, legado, Vector2.ZERO)
		var from_atlas := false
		if n != null:
			var at: AtlasTexture = (n as AnimatedSprite2D).sprite_frames.get_frame_texture("p", 0) as AtlasTexture
			from_atlas = at != null and at.atlas != null and str(at.atlas.resource_path).contains("attack_vfx_overlay_atlas")
		_ck("%s ainda vem do atlas" % legado, from_atlas)
	_ck("nome inexistente → null (fallback seguro)", CombatVfx.spawn(holder, "efeito_que_nao_existe", Vector2.ZERO) == null)

	# ── G7: apresentação idêntica nos DOIS caminhos de arte ───────────────────────
	# Atlas e biblioteca compartilham _finish. Se alguém duplicar a lógica e divergir, cai aqui.
	_g("G7 — APRESENTAÇÃO COMPARTILHADA (atlas ≡ biblioteca)")
	var a = CombatVfx.spawn(holder, "slash_arc_down_overlay", Vector2(10, 20))
	var b = CombatVfx.spawn(holder, "melee_heavy_arc", Vector2(10, 20))
	for par in [["atlas", a], ["biblioteca", b]]:
		var s := par[1] as AnimatedSprite2D
		_ck("%s: z=4095 absoluto" % par[0], s != null and s.z_index == 4095 and not s.z_as_relative)
		_ck("%s: centrado na posição" % par[0], s != null and s.centered and s.position == Vector2(10, 20))
		_ck("%s: auto-destrói no fim" % par[0], s != null and s.animation_finished.is_connected(s.queue_free))
	var bf := CombatVfx.spawn(holder, "melee_heavy_arc", Vector2.ZERO, Vector2.LEFT) as AnimatedSprite2D
	_ck("biblioteca: flip_h com dir=LEFT", bf != null and bf.flip_h)

	# ── G8: NENHUMA animação de jogador entrou (bloqueio do manifesto) ────────────
	# ⛔ O manifesto do player_combat_animation_library_pack_01 declara production_ready_staging_count=0 e
	# ANIMATION_NEEDS_REWORK em 20/20. Esta suíte TRAVA a entrada dessa arte enquanto o manifesto não virar.
	_g("G8 — TRAVA: ANIMAÇÃO DE JOGADOR NÃO ENTROU")
	var leaked: Array = []
	for cls in ["melee", "magic", "ranged", "reach", "support"]:
		for anim in ["attack_basic", "attack_heavy", "hit", "death"]:
			var p := "res://assets/actors/classes/%s_%s.png" % [cls, anim]
			if ResourceLoader.exists(p):
				leaked.append("%s_%s" % [cls, anim])
	_ck("0 strips de combate de classe no runtime", leaked.is_empty(), str(leaked))

	# ── G9: registro por arquétipo aponta só para arte que EXISTE ─────────────────
	_g("G9 — REGISTRO POR ARQUÉTIPO (CLASS_FX / hit_effect)")
	_ck("5 arquétipos", CombatVfx.CLASS_FX.size() == 5, str(CombatVfx.CLASS_FX.keys()))
	var dangling: Array = []
	for arch in CombatVfx.CLASS_FX:
		var d: Dictionary = CombatVfx.CLASS_FX[arch]
		if d.size() != 4:
			dangling.append("%s(papeis=%d)" % [arch, d.size()])
		for role in d:
			if not CombatVfx.LIB.has(str(d[role])):
				dangling.append("%s/%s→%s" % [arch, role, str(d[role])])
	_ck("nenhum ponteiro solto (4 papéis × 5)", dangling.is_empty(), str(dangling))
	_ck("arquétipo desconhecido cai em melee", CombatVfx.class_effect("arquetipo_inexistente") == "melee_basic_accent")
	_ck("magic → hit arcano", CombatVfx.hit_effect("magic") == "arcane_hit_small")
	_ck("melee → hit físico", CombatVfx.hit_effect("melee") == "physical_hit_small")
	_ck("heavy troca o tamanho", CombatVfx.hit_effect("melee", true) == "physical_hit_heavy")
	_ck("crit vence heavy e arquétipo", CombatVfx.hit_effect("magic", true, true) == "critical_hit_accent")
	_ck("support tem hit próprio", CombatVfx.hit_effect("support") == "support_hit")

	# ── G10: o EVENTO da caça chega mesmo no desenhista ───────────────────────────
	# ★★★ "leitor sem escritor": provar que o método existe NÃO prova que alguém o chama. Aqui o
	# _on_combat_feedback REAL é invocado e conta-se o CombatVfx que nasceu sob a raiz de atores.
	_g("G10 — ROTEAMENTO REAL DO EVENTO (HuntHost._on_combat_feedback)")
	var host = HuntHost.new()                      # sem add_child → _ready não roda, nada de HUD
	var actors := Node2D.new()
	root.add_child(actors)
	var fake_player := Node2D.new()
	fake_player.position = Vector2(500, 500)
	root.add_child(fake_player)
	host.set("_actors_root", actors)
	host.set("_player", fake_player)
	host.set("_anchor", Vector2(500, 500))
	_ck("host construído sem cena", host != null)
	_ck("raiz de VFX resolve para _actors_root", host._vfx_parent() == actors)
	var antes := actors.get_child_count()
	host._on_combat_feedback("hurt", {"amount": 7})
	var depois := actors.get_child_count()
	_ck("evento 'hurt' desenhou 1 VFX", depois == antes + 1, "%d → %d" % [antes, depois])
	var nasceu: Node = actors.get_child(actors.get_child_count() - 1) if actors.get_child_count() > 0 else null
	_ck("o nó nascido é um CombatVfx", nasceu is CombatVfx, nasceu.get_class() if nasceu != null else "(nenhum)")
	_ck("nasceu na posição do jogador", nasceu is Node2D and (nasceu as Node2D).position == Vector2(500, 500))
	host._on_combat_feedback("hurt", {"amount": 0})
	_ck("dano 0 NÃO desenha", actors.get_child_count() == depois)
	# impacto e swing pelo caminho público, com arquétipo padrão (game_state nulo → melee)
	host._vfx_impact(Vector2(700, 400), 12, false)
	_ck("impacto desenha no alvo", actors.get_child_count() == depois + 1 and _ultimo_pos(actors) == Vector2(700, 400), str(_ultimo_pos(actors)))
	host._vfx_swing(Vector2.RIGHT)
	_ck("swing desenha deslocado do jogador", actors.get_child_count() == depois + 2 and _ultimo_pos(actors) == Vector2(534, 500), str(_ultimo_pos(actors)))
	# sem raiz de atores o efeito é NO-OP, não erro (fallback seguro do self-test / cena ausente)
	host.set("_actors_root", null)
	_ck("sem raiz → _vfx_parent null", host._vfx_parent() == null)
	host._vfx_impact(Vector2.ZERO, 10, false)
	host._on_combat_feedback("hurt", {"amount": 5})
	_ck("sem raiz não estoura nem desenha", actors.get_child_count() == depois + 2)
	host.free()

	# ── fecho ─────────────────────────────────────────────────────────────────────
	print("\n═════════ RESUMO ═════════")
	print("  PASS = %d" % _pass)
	print("  FAIL = %d" % _fail)
	print("  %s" % ("TUDO VERDE" if _fail == 0 else "HÁ FALHAS — ver acima"))
	quit(0 if _fail == 0 else 1)
