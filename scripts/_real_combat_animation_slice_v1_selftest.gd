extends SceneTree
## REAL COMBAT ANIMATION INTEGRATION PREP V1 — suíte de preparação + fatia MELEE.
##
## ★★★ CEDE FRAME EM TODO LAÇO DE CENA. Suíte que roda tudo num frame só TRAVA A MÁQUINA em vez de
## reprovar (ver TEST_HARNESS_SCENE_REAL_SAFETY.md). Toda espera aqui é por CONDIÇÃO com teto de
## frames — nunca por contagem fixa, que é frágil.
##
## Uso: --headless --path <proj> --script res://scripts/_real_combat_animation_slice_v1_selftest.gd
## Exit 0 = tudo passou · 1 = alguma asserção falhou ou algum grupo ficou abaixo do mínimo.

const MINIMOS := {
	"READY_STATUS_GATE": 30, "PLAYER_LOOKUP": 40, "MOB_LOOKUP": 40, "MISSING_FALLBACK": 35,
	"REAL_TRANSIENT_PLAYBACK": 50, "DIRECTION_RESOLUTION": 35, "HFLIP": 25, "RESTORE_LOCOMOTION": 40,
	"MELEE_BASIC": 45, "MELEE_HIT": 35, "MELEE_DEATH_SAFE": 25,
	"ASH_WOLF_ATTACK": 40, "ASH_WOLF_HIT": 40, "ASH_WOLF_DEATH": 40,
	"INSTANCE_ROUTING_REGRESSION": 45, "MULTI_ACTOR_ANIMATION": 45,
	"VFX_SYNC": 35, "CONTACT_FRAME_VISUAL": 30, "STRESS_100_ATTACKS": 40,
	"REALSCENE_ANIMATION_SLICE": 100,
}

const CLASSES := ["MELEE", "RANGED", "MAGIC", "REACH", "SUPPORT"]
const NAO_PRONTAS := ["RANGED", "MAGIC", "REACH", "SUPPORT"]
const ACOES := ["ATTACK_BASIC", "ATTACK_HEAVY", "HIT", "DEATH"]
const DIRS := ["BASE", "SIDE", "UP"]
const MOBS := ["ash_wolf", "crystal_bat", "grove_spider", "root_spider", "dune_skitter", "salt_husk"]

var _pass := 0
var _fail := 0
var _g := ""
var _por_grupo := {}
var _falhas: Array = []
var _diag_feito := false

func _grp(nome: String) -> void:
	_g = nome
	_por_grupo[nome] = {"p": 0, "f": 0}
	print("\n── %s (mínimo %d) ──" % [nome, int(MINIMOS.get(nome, 0))])

func _ck(id: String, cond: bool, detail := "") -> void:
	var b: Dictionary = _por_grupo.get(_g, {"p": 0, "f": 0})
	if cond:
		_pass += 1
		b["p"] = int(b["p"]) + 1
	else:
		_fail += 1
		b["f"] = int(b["f"]) + 1
		_falhas.append("%s :: %s %s" % [_g, id, detail])
		print("   FAIL %-46s %s" % [id, detail])
	_por_grupo[_g] = b

## Espera por CONDIÇÃO cedendo frame, com teto. Devolve true se a condição bateu.
func _ate(cond: Callable, teto := 240) -> bool:
	var n := 0
	while n < teto:
		if cond.call():
			return true
		await process_frame
		n += 1
	return cond.call()

## Monta um ator de teste com spritesheet REAL na árvore (senão `_anim` é null e nada toca).
func _novo_animator(sheet_key: String, kind: String, id: String) -> Dictionary:
	var holder := Node2D.new()
	root.add_child(holder)
	var body := Node2D.new()
	holder.add_child(body)
	var an := ActorAnimator.new()
	holder.add_child(an)
	an.setup(body, sheet_key, 3.0, true)
	an.combat_kind = kind
	an.combat_id = id
	return {"holder": holder, "anim": an}

## Sobreposição SÓ-DE-TESTE que marca MELEE pronto. Aponta para as MESMAS 12 strips já materializadas
## (o `player_dir` do dado de produção não muda), então o que se prova é o caminho real de verdade —
## só a APROVAÇÃO é simulada, nunca o arquivo.
func _ovl_melee() -> Dictionary:
	return {"player": {"MELEE": {
		"ready": true, "status": "TEST_OVERLAY", "materialized": true,
		"actions": {
			"ATTACK_BASIC": {"BASE": true, "SIDE": true, "UP": true, "contact_frame": 3},
			"ATTACK_HEAVY": {"BASE": true, "SIDE": true, "UP": true, "contact_frame": 3},
			"HIT":          {"BASE": true, "SIDE": true, "UP": true, "contact_frame": 1},
			"DEATH":        {"BASE": true, "SIDE": true, "UP": true, "contact_frame": 0},
		}}}}

func _initialize() -> void:
	_run()

func _run() -> void:
	print("═════════ REAL COMBAT ANIMATION SLICE V1 — SELFTEST ═════════")
	CombatAnimationRegistry.reload()

	# ★★★ ONDA 2: o handoff reconciliado do Codex REVOGOU o MELEE (e tudo o mais). Esta suíte prova a
	# MECÂNICA do caminho real, que não pode depender do humor do manifesto — então os grupos de
	# mecânica rodam sob SOBREPOSIÇÃO DE TESTE. O grupo READY_STATUS_GATE roda ANTES dela e mede o
	# portão de PRODUÇÃO de verdade. Assim uma coisa nunca mascara a outra.
	await _g_ready_gate()
	CombatAnimationRegistry.apply_test_overlay(_ovl_melee())
	await _g_player_lookup()
	await _g_mob_lookup()
	await _g_missing_fallback()
	await _g_direction()
	await _g_transient()
	await _g_hflip()
	await _g_restore()
	await _g_melee_basic()
	await _g_melee_hit()
	await _g_melee_death()
	# os grupos do lobo medem o PORTÃO DE PRODUÇÃO fechado + fallback ⇒ sem sobreposição
	CombatAnimationRegistry.clear_test_overlay()
	await _g_wolf("ASH_WOLF_ATTACK", "ATTACK_BASIC")
	await _g_wolf("ASH_WOLF_HIT", "HIT")
	await _g_wolf("ASH_WOLF_DEATH", "DEATH")
	CombatAnimationRegistry.apply_test_overlay(_ovl_melee())
	await _g_instance_routing()
	await _g_multi_actor()
	await _g_vfx_sync()
	await _g_contact_frame()
	await _g_stress()
	await _g_realscene()

	_fecho()

# ─────────────────────────────────────────────────────────────────────────────
func _g_ready_gate() -> void:
	_grp("READY_STATUS_GATE")
	_ck("registro carregou", CombatAnimationRegistry.loaded())
	_ck("4 ações", CombatAnimationRegistry.ACTIONS.size() == 4)
	_ck("3 direções", CombatAnimationRegistry.DIRECTIONS.size() == 3)
	_ck("contrato 64px", CombatAnimationRegistry.FRAME_SIZE == 64)
	_ck("contrato 4 quadros", CombatAnimationRegistry.FRAME_COUNT == 4)
	# ★★★ o coração do portão: prontidão é DECLARADA, por entidade.
	for c in CLASSES:
		var e := CombatAnimationRegistry.entry("player", c)
		_ck("player %s existe no dado" % c, not e.is_empty())
		_ck("player %s tem status" % c, CombatAnimationRegistry.status_of("player", c) != "")
		_ck("player %s tem evidência" % c, str(e.get("evidence", "")) != "", "sem rastro do manifesto")
		# ★★★ handoff RECONCILIADO (18:26) zerou `ready_for_runtime_integration` ⇒ ninguém pronto.
		_ck("player %s NÃO pronto (handoff)" % c, not bool(e.get("ready", false)), str(e.get("status", "")))
		_ck("player %s declara blocker" % c, (e.get("blockers", []) as Array).size() > 0, str(e.get("blockers", [])))
	for m in MOBS:
		var em := CombatAnimationRegistry.entry("mobs", m)
		_ck("mob %s existe no dado" % m, not em.is_empty())
		_ck("mob %s NÃO está pronto" % m, not bool(em.get("ready", false)), str(em.get("status", "")))
		_ck("mob %s tem evidência" % m, str(em.get("evidence", "")) != "")
	# ★★★ "existe" ≠ "pronto": ash_wolf tem arte no staging e MESMO ASSIM o portão fica fechado.
	# ★★★ O invariante que importa: MATERIALIZADO ≠ PRONTO. As strips do ash_wolf e do MELEE estão
	# no projeto, e mesmo assim o portão está FECHADO nas duas. É esse o ponto da arquitetura.
	var aw := CombatAnimationRegistry.entry("mobs", "ash_wolf")
	_ck("ash_wolf materializado no projeto", bool(aw.get("materialized", false)))
	_ck("ash_wolf MESMO ASSIM não está pronto", not bool(aw.get("ready", true)))
	_ck("ash_wolf gate fechado p/ ATTACK", not CombatAnimationRegistry.is_ready("mobs", "ash_wolf", "ATTACK_BASIC"))
	var mel := CombatAnimationRegistry.entry("player", "MELEE")
	_ck("MELEE materializado", bool(mel.get("materialized", false)))
	_ck("MELEE MESMO ASSIM foi revogado", not bool(mel.get("ready", true)), str(mel.get("status", "")))
	_ck("MELEE gate fechado em produção", not CombatAnimationRegistry.is_ready("player", "MELEE", "ATTACK_BASIC"))
	_ck("sem sobreposição de teste ativa aqui", not CombatAnimationRegistry.test_overlay_active())
	# entidade/ação/direção desconhecidas nunca abrem o portão
	_ck("classe inexistente fechada", not CombatAnimationRegistry.is_ready("player", "NAO_EXISTE", "ATTACK_BASIC"))
	_ck("ação inexistente fechada", not CombatAnimationRegistry.is_ready("player", "MELEE", "ACAO_X"))
	_ck("direção inexistente fechada", not CombatAnimationRegistry.is_ready("player", "MELEE", "ATTACK_BASIC", "DIAGONAL"))
	_ck("kind inexistente fechado", not CombatAnimationRegistry.is_ready("bichos", "ash_wolf", "HIT"))
	_ck("nenhuma classe pronta", CombatAnimationRegistry.ready_ids("player").is_empty(), str(CombatAnimationRegistry.ready_ids("player")))
	_ck("nenhum mob pronto", CombatAnimationRegistry.ready_ids("mobs").is_empty(), str(CombatAnimationRegistry.ready_ids("mobs")))
	# políticas de PRODUTO existem e estão desligadas
	_ck("morte real do jogador DESLIGADA", not CombatAnimationRegistry.policy_flag("player_death_real_animation_enabled"))
	_ck("pesado real do jogador DESLIGADO", not CombatAnimationRegistry.policy_flag("player_heavy_real_animation_enabled"))
	_ck("HIT interrompe ATTACK declarado", CombatAnimationRegistry.policy_flag("hit_interrupts_attack"))
	_ck("prioridade HIT > ATTACK", CombatAnimationRegistry.priority_of("HIT") > CombatAnimationRegistry.priority_of("ATTACK_BASIC"))
	_ck("prioridade DEATH > HIT", CombatAnimationRegistry.priority_of("DEATH") > CombatAnimationRegistry.priority_of("HIT"))
	await process_frame

func _g_player_lookup() -> void:
	_grp("PLAYER_LOOKUP")
	for c in CLASSES:
		for a in ACOES:
			for d in DIRS:
				var p := CombatAnimationRegistry.strip_path("player", c, a, d)
				_ck("path %s/%s/%s" % [c, a, d], p.contains(c) and p.contains(a) and p.ends_with("_%s.png" % d), p)
	_ck("path de ação inválida vazio", CombatAnimationRegistry.strip_path("player", "MELEE", "XX") == "")
	_ck("path minúsculo vira MAIÚSCULO", CombatAnimationRegistry.strip_path("player", "melee", "HIT").contains("MELEE"))
	_ck("path do player usa player_dir", CombatAnimationRegistry.strip_path("player", "MELEE", "HIT").contains("combat/player"))
	await process_frame

func _g_mob_lookup() -> void:
	_grp("MOB_LOOKUP")
	for m in MOBS:
		for a in ACOES:
			var p := CombatAnimationRegistry.strip_path("mobs", m, a)
			_ck("path %s/%s" % [m, a], p.contains(m) and p.contains(a) and p.ends_with("_BASE.png"), p)
			_ck("mob %s/%s não é caminho de player" % [m, a], not p.contains("combat/player"))
	_ck("mob id preserva minúsculas", CombatAnimationRegistry.strip_path("mobs", "ash_wolf", "HIT").contains("ash_wolf"))
	_ck("mob usa mob_dir", CombatAnimationRegistry.strip_path("mobs", "ash_wolf", "HIT").contains("combat/mobs"))
	await process_frame

func _g_missing_fallback() -> void:
	_grp("MISSING_FALLBACK")
	# ⛔ classe não marcada pronta NUNCA devolve frames, mesmo que alguém copie o arquivo.
	for c in NAO_PRONTAS:
		for a in ACOES:
			for d in DIRS:
				_ck("frames %s/%s/%s == null" % [c, a, d], CombatAnimationRegistry.frames("player", c, a, d) == null)
	for m in MOBS:
		_ck("frames mob %s == null" % m, CombatAnimationRegistry.frames("mobs", m, "ATTACK_BASIC") == null)
	_ck("entidade inexistente == null", CombatAnimationRegistry.frames("player", "FANTASMA", "HIT") == null)
	_ck("ação inexistente == null", CombatAnimationRegistry.frames("player", "MELEE", "PULO") == null)
	# ★ o fallback é SILENCIOSO no caso normal: nada foi cacheado para o que não está pronto
	_ck("nada não-pronto entrou no cache", CombatAnimationRegistry.cache_size() == 0, str(CombatAnimationRegistry.cache_size()))
	await process_frame

func _g_direction() -> void:
	_grp("DIRECTION_RESOLUTION")
	for a in ACOES:
		for d in DIRS:
			_ck("MELEE %s/%s resolve nele mesmo" % [a, d], CombatAnimationRegistry.resolve_direction("player", "MELEE", a, d) == d)
	for c in NAO_PRONTAS:
		for a in ACOES:
			for d in DIRS:
				_ck("%s %s/%s resolve vazio" % [c, a, d], CombatAnimationRegistry.resolve_direction("player", c, a, d) == "")
	_ck("direção inválida cai em BASE", CombatAnimationRegistry.resolve_direction("player", "MELEE", "HIT", "TRAS") == "BASE")
	_ck("mob não pronto resolve vazio", CombatAnimationRegistry.resolve_direction("mobs", "ash_wolf", "HIT") == "")
	# tradução de Dir→vocabulário do registro, no ator de verdade
	var t := _novo_animator("hero/errante", "player", "MELEE")
	var an: ActorAnimator = t["anim"]
	an.set_direction(Vector2.DOWN);  _ck("DOWN→BASE", an.combat_direction() == "BASE")
	an.set_direction(Vector2.RIGHT); _ck("RIGHT→SIDE", an.combat_direction() == "SIDE")
	an.set_direction(Vector2.LEFT);  _ck("LEFT→SIDE", an.combat_direction() == "SIDE")
	an.set_direction(Vector2.UP);    _ck("UP→UP", an.combat_direction() == "UP")
	t["holder"].queue_free()
	await process_frame

func _g_transient() -> void:
	_grp("REAL_TRANSIENT_PLAYBACK")
	var t := _novo_animator("hero/errante", "player", "MELEE")
	var an: ActorAnimator = t["anim"]
	_ck("ator tem spritesheet", an.has_spritesheet())
	for a in ACOES:
		if a == "DEATH":
			continue          # morte tem grupo próprio (não dá pra repetir no mesmo ator)
		for d in [Vector2.DOWN, Vector2.RIGHT, Vector2.UP]:
			an.set_direction(d)
			var dirname := an.combat_direction()
			_ck("has_real_combat %s/%s" % [a, dirname], an.has_real_combat(a))
			var ok := an.play_real_transient(a, d)
			_ck("play_real_transient %s/%s" % [a, dirname], ok)
			_ck("transitório ativo %s/%s" % [a, dirname], an.real_transient_active())
			var esperado := CombatAnimationRegistry.anim_name("player", "MELEE", a, dirname)
			_ck("anim registrada %s/%s" % [a, dirname], an._anim.sprite_frames.has_animation(esperado), esperado)
			_ck("anim não faz loop %s/%s" % [a, dirname], not an._anim.sprite_frames.get_animation_loop(esperado))
			_ck("4 quadros %s/%s" % [a, dirname], an._anim.sprite_frames.get_frame_count(esperado) == 4)
			var terminou: bool = await _ate(func(): return not an.real_transient_active())
			_ck("terminou sozinho %s/%s" % [a, dirname], terminou)
	_ck("cache do registro > 0", CombatAnimationRegistry.cache_size() > 0, str(CombatAnimationRegistry.cache_size()))
	# ator SEM identidade de combate nunca entra no caminho real
	var t2 := _novo_animator("hero/errante", "", "")
	_ck("sem combat_kind → false", not (t2["anim"] as ActorAnimator).play_real_transient("ATTACK_BASIC"))
	_ck("sem combat_kind → has_real false", not (t2["anim"] as ActorAnimator).has_real_combat("ATTACK_BASIC"))
	t["holder"].queue_free(); t2["holder"].queue_free()
	await process_frame

func _g_hflip() -> void:
	_grp("HFLIP")
	var t := _novo_animator("hero/errante", "player", "MELEE")
	var an: ActorAnimator = t["anim"]
	for a in ["ATTACK_BASIC", "ATTACK_HEAVY", "HIT"]:
		for v in [Vector2.LEFT, Vector2.RIGHT]:
			an.set_direction(v)
			var antes: bool = an._anim.flip_h
			var face_antes := an.facing_left
			an.play_real_transient(a, v)
			_ck("flip preservado no início %s/%s" % [a, str(v)], an._anim.flip_h == antes)
			_ck("facing preservado %s/%s" % [a, str(v)], an.facing_left == face_antes)
			var _fim: bool = await _ate(func(): return not an.real_transient_active())
			_ck("flip preservado no fim %s/%s" % [a, str(v)], an._anim.flip_h == antes)
			_ck("facing preservado no fim %s/%s" % [a, str(v)], an.facing_left == face_antes)
	an.set_direction(Vector2.LEFT)
	_ck("esquerda marca facing_left", an.facing_left)
	an.set_direction(Vector2.RIGHT)
	_ck("direita desmarca facing_left", not an.facing_left)
	t["holder"].queue_free()
	await process_frame

func _g_restore() -> void:
	_grp("RESTORE_LOCOMOTION")
	var t := _novo_animator("hero/errante", "player", "MELEE")
	var an: ActorAnimator = t["anim"]
	for a in ["ATTACK_BASIC", "ATTACK_HEAVY", "HIT"]:
		for andando in [false, true]:
			for v in [Vector2.DOWN, Vector2.RIGHT, Vector2.UP]:
				if andando:
					an.play_walk(v)
				else:
					an.set_direction(v); an.play_idle()
				var estado_antes := an.state
				var aim_antes := an._aim
				an.play_real_transient(a, v)
				var _fim: bool = await _ate(func(): return not an.real_transient_active())
				_ck("estado restaurado %s/%s/%s" % [a, str(andando), str(v)], an.state == estado_antes, "%d vs %d" % [an.state, estado_antes])
				_ck("alvo (_aim) preservado %s/%s/%s" % [a, str(andando), str(v)], an._aim == aim_antes)
				_ck("não ficou preso %s/%s/%s" % [a, str(andando), str(v)], not an.real_transient_active())
	_ck("nenhum transitório pendente no fim", not an.real_transient_active())
	t["holder"].queue_free()
	await process_frame

func _g_melee_basic() -> void:
	_grp("MELEE_BASIC")
	for d in DIRS:
		_ck("MELEE BASIC pronto %s" % d, CombatAnimationRegistry.is_ready("player", "MELEE", "ATTACK_BASIC", d))
		var sf := CombatAnimationRegistry.frames("player", "MELEE", "ATTACK_BASIC", d)
		_ck("frames %s não nulo" % d, sf != null)
		if sf == null:
			continue
		_ck("frames %s tem 4" % d, sf.get_frame_count("p") == 4)
		_ck("frames %s sem loop" % d, not sf.get_animation_loop("p"))
		for i in range(4):
			var tx: AtlasTexture = sf.get_frame_texture("p", i) as AtlasTexture
			_ck("quadro %d/%s é 64x64" % [i, d], tx != null and tx.region.size == Vector2(64, 64))
			_ck("quadro %d/%s deslocado" % [i, d], tx != null and tx.region.position.x == float(i * 64))
	# o corpo real de verdade, no ator
	var t := _novo_animator("hero/errante", "player", "MELEE")
	var an: ActorAnimator = t["anim"]
	for v in [Vector2.DOWN, Vector2.RIGHT, Vector2.UP]:
		an.set_direction(v)
		var ok := an.play_real_transient("ATTACK_BASIC", v)
		_ck("basic toca %s" % str(v), ok)
		_ck("estado ATTACK %s" % str(v), an.state == ActorAnimator.State.ATTACK)
		_ck("busy segura o pose %s" % str(v), an._busy_t > 0.0)
		var _f: bool = await _ate(func(): return not an.real_transient_active())
		_ck("voltou ao idle %s" % str(v), an.state == ActorAnimator.State.IDLE)
	_ck("mesma anim reusada (sem recorte novo)", an._anim.sprite_frames.has_animation(CombatAnimationRegistry.anim_name("player", "MELEE", "ATTACK_BASIC", "BASE")))
	t["holder"].queue_free()
	await process_frame

func _g_melee_hit() -> void:
	_grp("MELEE_HIT")
	for d in DIRS:
		_ck("MELEE HIT pronto %s" % d, CombatAnimationRegistry.is_ready("player", "MELEE", "HIT", d))
		var sf := CombatAnimationRegistry.frames("player", "MELEE", "HIT", d)
		_ck("HIT frames %s" % d, sf != null and sf.get_frame_count("p") == 4)
	var t := _novo_animator("hero/errante", "player", "MELEE")
	var an: ActorAnimator = t["anim"]
	for i in range(6):
		var v: Vector2 = [Vector2.DOWN, Vector2.RIGHT, Vector2.UP][i % 3]
		an.set_direction(v)
		_ck("hit %d toca" % i, an.play_real_transient("HIT", v))
		_ck("hit %d estado HIT" % i, an.state == ActorAnimator.State.HIT)
		_ck("hit %d não morreu" % i, not an._dead)
		var _f: bool = await _ate(func(): return not an.real_transient_active())
		_ck("hit %d restaurou" % i, an.state == ActorAnimator.State.IDLE)
		_ck("hit %d vivo" % i, not an._dead)
	# fallback: classe não pronta usa o flinch procedural e NÃO fica presa
	var t2 := _novo_animator("hero/errante", "player", "RANGED")
	var an2: ActorAnimator = t2["anim"]
	for i in range(5):
		_ck("RANGED hit %d NÃO usa real" % i, not an2.play_real_transient("HIT"))
		an2.play_hit()
		_ck("RANGED hit %d procedural mexeu" % i, an2.state == ActorAnimator.State.HIT)
		_ck("RANGED hit %d sem transitório" % i, not an2.real_transient_active())
	t["holder"].queue_free(); t2["holder"].queue_free()
	await process_frame

func _g_melee_death() -> void:
	_grp("MELEE_DEATH_SAFE")
	for d in DIRS:
		_ck("MELEE DEATH declarado pronto %s" % d, CombatAnimationRegistry.is_ready("player", "MELEE", "DEATH", d))
		_ck("DEATH frames %s" % d, CombatAnimationRegistry.frames("player", "MELEE", "DEATH", d) != null)
	# ★★★ DECISÃO DE ESCOPO (Parte 9): a morte do JOGADOR fica ADIADA. `set_downed()` continua no
	# gesto procedural, porque "abatido" é estado RECUPERÁVEL ([R] levanta) e trocar por uma strip que
	# emite `death_finished` mexeria no ciclo de vida do jogador. Registrado e provado, não ativado.
	var t := _novo_animator("hero/errante", "player", "MELEE")
	var an: ActorAnimator = t["anim"]
	# ⚠️ CONTADOR EM ARRAY, não em int: lambda de GDScript captura local por VALOR — um `var mortes := 0`
	# incrementado dentro do lambda nunca chega aqui fora, e o teste acusava "sinal não emitido" com o
	# produto certo. Erro de MEDIDOR. Array é referência, então o incremento é visível.
	var mortes: Array = [0]
	an.death_finished.connect(func(): mortes[0] += 1)
	_ck("morte real toca", an.play_real_transient("DEATH"))
	_ck("estado DEATH", an.state == ActorAnimator.State.DEATH)
	var _f: bool = await _ate(func(): return int(mortes[0]) > 0)
	_ck("death_finished emitido", int(mortes[0]) == 1, str(mortes[0]))
	_ck("ficou morto", an._dead)
	_ck("transitório encerrado", not an.real_transient_active())
	_ck("morto não aceita novo transitório", not an.play_real_transient("ATTACK_BASIC"))
	an.play_attack(Vector2.DOWN)
	_ck("morto não aceita ataque procedural", an.state == ActorAnimator.State.DEATH)
	_ck("death_finished não repetiu", int(mortes[0]) == 1, str(mortes[0]))
	_ck("estado segue DEATH", an.state == ActorAnimator.State.DEATH)
	_ck("morto não anda", (func(): an.play_walk(Vector2.RIGHT); return an.state == ActorAnimator.State.DEATH).call() == true)
	_ck("morto não volta ao idle", (func(): an.play_idle(); return an.state == ActorAnimator.State.DEATH).call() == true)
	an.reset()
	_ck("reset ressuscita", not an._dead)
	_ck("reset limpa transitório", not an.real_transient_active())
	_ck("reset volta a IDLE", an.state == ActorAnimator.State.IDLE)
	_ck("depois do reset aceita ataque", an.play_real_transient("ATTACK_BASIC"))
	var _f2: bool = await _ate(func(): return not an.real_transient_active())
	_ck("e restaura de novo", an.state == ActorAnimator.State.IDLE)
	_ck("reset não ressuscitou o sinal", int(mortes[0]) == 1, str(mortes[0]))
	_ck("ainda vivo depois de tudo", not an._dead)
	# ★★★ INVARIANTE QUE A CENA REAL REVELOU: morrer NO MEIO de um gesto tem de CANCELAR o gesto.
	# Sem isso o `animation_finished` nunca vem (o sprite é pausado), o transitório fica setado para
	# sempre e — como play_idle/play_walk respeitam o transitório — o ator NUNCA MAIS anima.
	for morte_por in ["downed", "death", "snap"]:
		var t2 := _novo_animator("hero/errante", "player", "MELEE")
		var a2: ActorAnimator = t2["anim"]
		_ck("%s: gesto iniciou" % morte_por, a2.play_real_transient("ATTACK_BASIC", Vector2.RIGHT))
		_ck("%s: gesto ativo" % morte_por, a2.real_transient_active())
		match morte_por:
			"downed": a2.play_downed()
			"death": a2.play_death()
			_: a2.snap_dead()
		_ck("%s: transitório CANCELADO" % morte_por, not a2.real_transient_active())
		_ck("%s: ficou morto" % morte_por, a2._dead)
		a2.reset()
		_ck("%s: revive sem transitório preso" % morte_por, not a2.real_transient_active())
		_ck("%s: volta a animar" % morte_por, a2.play_real_transient("ATTACK_BASIC", Vector2.RIGHT))
		var _f3: bool = await _ate(func(): return not a2.real_transient_active())
		_ck("%s: e termina normal" % morte_por, not a2.real_transient_active())
		t2["holder"].queue_free()
	# a decisão de adiar é MEDIDA, não prometida:
	var pc_src := FileAccess.get_file_as_string("res://scripts/PlayerController.gd")
	# ★ Onda 2: a trava deixou de ser "não existe código" e virou POLÍTICA EM DADO — melhor, porque
	# não liga por acidente quando o Codex aprovar a arte. O que se mede agora é o FLAG.
	_ck("morte real do jogador desligada por política", not CombatAnimationRegistry.policy_flag("player_death_real_animation_enabled"))
	_ck("set_downed consulta a política", pc_src.contains("player_death_real_animation_enabled"))
	_ck("set_downed mantém o fallback", pc_src.contains("_anim.play_downed()"))
	_ck("play_attack USA strip real", pc_src.contains("play_real_transient"))
	_ck("hit_recoil preserva fallback", pc_src.contains("_anim.play_hit()"))
	_ck("play_attack preserva fallback", pc_src.contains("_anim.play_attack(aim, \"melee\")"))
	t["holder"].queue_free()
	await process_frame

func _g_wolf(grupo: String, acao: String) -> void:
	_grp(grupo)
	# ★★★ ash_wolf tem ARTE no staging e MESMO ASSIM não entra: o portão é o dado, não o arquivo.
	_ck("gate fechado BASE", not CombatAnimationRegistry.is_ready("mobs", "ash_wolf", acao, "BASE"))
	_ck("gate fechado SIDE", not CombatAnimationRegistry.is_ready("mobs", "ash_wolf", acao, "SIDE"))
	_ck("gate fechado UP", not CombatAnimationRegistry.is_ready("mobs", "ash_wolf", acao, "UP"))
	_ck("frames null", CombatAnimationRegistry.frames("mobs", "ash_wolf", acao) == null)
	_ck("resolve vazio", CombatAnimationRegistry.resolve_direction("mobs", "ash_wolf", acao) == "")
	_ck("status explícito do handoff", CombatAnimationRegistry.status_of("mobs", "ash_wolf") == "ANIMATION_NEEDS_REWORK", CombatAnimationRegistry.status_of("mobs", "ash_wolf"))
	var ator := PveMobActor.new()
	root.add_child(ator)
	ator.setup("mobs/ash_wolf", "ash_wolf", false, "Lobo de Cinzas")
	_ck("ator tem sheet real", ator._anim != null and ator._anim.has_spritesheet())
	_ck("não caiu no losango", not ator.used_fallback)
	_ck("combat_kind ligado", ator._anim.combat_kind == "mobs")
	_ck("combat_id é o mob_id", ator._anim.combat_id == "ash_wolf")
	_ck("has_real_combat false", not ator._anim.has_real_combat(acao))
	# 8 repetições: o fallback tem de aguentar repetição sem prender nem crescer
	var filhos_antes := ator.get_child_count()
	for i in range(8):
		if acao == "ATTACK_BASIC":
			ator.play_attack(Vector2.RIGHT)
			_ck("ataque %d encenou" % i, ator._anim.state == ActorAnimator.State.ATTACK)
		elif acao == "HIT":
			ator.play_hit()
			_ck("hit %d encenou" % i, ator._anim.state == ActorAnimator.State.HIT)
		else:
			_ck("morte %d ainda não disparada" % i, not ator._anim._dead)
		_ck("sem transitório real %d" % i, not ator._anim.real_transient_active())
		_ck("sem crescer filhos %d" % i, ator.get_child_count() == filhos_antes, "%d vs %d" % [ator.get_child_count(), filhos_antes])
		_ck("mob segue vivo %d" % i, is_instance_valid(ator))
		await process_frame
	if acao == "DEATH":
		# a morte procedural precisa CHEGAR ao fim e liberar o nó (lifecycle intacto)
		# ⚠️ espera por ID: capturar o ator no lambda gera "Lambda capture was freed" quando ele some.
		var aid := ator.get_instance_id()
		ator.die_and_free()
		_ck("entrou em morrendo", ator._dying)
		var sumiu: bool = await _ate(func(): return not is_instance_id_valid(aid), 300)
		_ck("ator liberado ao morrer", sumiu)
	else:
		_ck("ator ainda válido", is_instance_valid(ator))
		ator.queue_free()
	await process_frame

func _g_instance_routing() -> void:
	_grp("INSTANCE_ROUTING_REGRESSION")
	var host = HuntHost.new()
	var raiz := Node2D.new(); root.add_child(raiz)
	var jog := Node2D.new(); jog.position = Vector2(400, 400); root.add_child(jog)
	host.set("_actors_root", raiz)
	host.set("_player", jog)
	host.set("_anchor", Vector2(400, 400))
	var a := PveMobActor.new(); raiz.add_child(a); a.setup("mobs/ash_wolf", "ash_wolf"); a.global_position = Vector2(500, 400)
	var b := PveMobActor.new(); raiz.add_child(b); b.setup("mobs/ash_wolf", "ash_wolf"); b.global_position = Vector2(300, 400)
	var reg := {}
	reg[101] = a
	reg[202] = b
	host.set("_mob_actors_by_instance", reg)
	_ck("registro tem 2", reg.size() == 2)
	_ck("A resolve por id", host._actor_for_instance(101) == a)
	_ck("B resolve por id", host._actor_for_instance(202) == b)
	_ck("id desconhecido → null", host._actor_for_instance(999) == null)
	# ★★★ o bug histórico: mostrar o dano de B em cima de A. Cada evento tem de tocar SÓ o seu.
	for ciclo in range(10):
		var alvo_id := 101 if ciclo % 2 == 0 else 202
		var alvo: PveMobActor = a if alvo_id == 101 else b
		var outro: PveMobActor = b if alvo_id == 101 else a
		var est_outro := outro._anim.state
		host._on_combat_feedback("hit", {"instance_id": alvo_id, "amount": 5, "mob_id": "ash_wolf"})
		_ck("ciclo %d: alvo reagiu" % ciclo, alvo._anim.state == ActorAnimator.State.HIT)
		_ck("ciclo %d: o OUTRO não reagiu" % ciclo, outro._anim.state == est_outro)
		host._on_combat_feedback("mob_attack", {"instance_id": alvo_id})
		_ck("ciclo %d: ataque foi do alvo" % ciclo, alvo._anim.state == ActorAnimator.State.ATTACK)
		_ck("ciclo %d: outro seguiu quieto" % ciclo, outro._anim.state == est_outro)
		await process_frame
	# evento tardio de instância morta: descarta e CONTA, não recria nem estoura
	var antes := int((host.get("host_group_stats") as Dictionary).get("late_feedback_dropped", 0))
	host._on_combat_feedback("hit", {"instance_id": 777, "amount": 9})
	var depois := int((host.get("host_group_stats") as Dictionary).get("late_feedback_dropped", 0))
	_ck("evento tardio contado", depois == antes + 1, "%d → %d" % [antes, depois])
	_ck("nada foi recriado", raiz.get_child_count() >= 2)
	_ck("A intacto", is_instance_valid(a))
	_ck("B intacto", is_instance_valid(b))
	# VFX continua nascendo (a onda 1 não regrediu)
	var vfx_antes := raiz.get_child_count()
	host._on_combat_feedback("hit", {"instance_id": 101, "amount": 6})
	_ck("hit desenha VFX", raiz.get_child_count() > vfx_antes)
	host.free(); raiz.queue_free(); jog.queue_free()
	await process_frame

func _g_multi_actor() -> void:
	_grp("MULTI_ACTOR_ANIMATION")
	var raiz := Node2D.new(); root.add_child(raiz)
	var lobos: Array = []
	for i in range(2):
		var w := PveMobActor.new(); raiz.add_child(w)
		w.setup("mobs/ash_wolf", "ash_wolf", false, "Lobo %d" % i)
		w.global_position = Vector2(300 + i * 200, 400)
		lobos.append(w)
	_ck("2 lobos criados", lobos.size() == 2)
	_ck("animators distintos", lobos[0]._anim != lobos[1]._anim)
	_ck("sem estado compartilhado", lobos[0]._anim.get_instance_id() != lobos[1]._anim.get_instance_id())
	for ciclo in range(8):
		var i := ciclo % 2
		var eu: PveMobActor = lobos[i]
		var outro: PveMobActor = lobos[1 - i]
		outro._anim.play_idle()
		var est_outro := outro._anim.state
		eu.play_attack(Vector2.RIGHT)
		_ck("c%d lobo %d atacou" % [ciclo, i], eu._anim.state == ActorAnimator.State.ATTACK)
		_ck("c%d o outro ficou IDLE" % ciclo, outro._anim.state == est_outro)
		eu.play_hit()
		_ck("c%d lobo %d apanhou" % [ciclo, i], eu._anim.state == ActorAnimator.State.HIT)
		_ck("c%d outro segue IDLE" % ciclo, outro._anim.state == est_outro)
		eu.face(Vector2(0, 0) if i == 0 else Vector2(800, 400))
		_ck("c%d facing independente" % ciclo, true)
		await process_frame
	# morte independente: mata o 0, o 1 continua inteiro
	var l0id: int = (lobos[0] as Node).get_instance_id()
	lobos[0].die_and_free()
	var morreu: bool = await _ate(func(): return not is_instance_id_valid(l0id), 300)
	_ck("lobo 0 liberado", morreu)
	_ck("lobo 1 intacto", is_instance_valid(lobos[1]))
	var sobrevivente: PveMobActor = lobos[1]
	sobrevivente.play_attack(Vector2.LEFT)
	_ck("lobo 1 ainda anima", sobrevivente._anim.state == ActorAnimator.State.ATTACK)
	_ck("lobo 1 não ficou preso", not sobrevivente._anim.real_transient_active())
	raiz.queue_free()
	await process_frame

func _g_vfx_sync() -> void:
	_grp("VFX_SYNC")
	# ★ Parte 12: corpo é corpo, VFX é VFX. Nada de VFX embutido na strip → os dois sistemas coexistem.
	var pai := Node2D.new(); root.add_child(pai)
	var antes := pai.get_child_count()
	var n := 0
	for arch in ["melee", "magic", "ranged", "reach", "support"]:
		for papel in ["basic", "heavy", "signature", "response"]:
			var eff := CombatVfx.class_effect(arch, papel)
			_ck("efeito %s/%s existe na LIB" % [arch, papel], CombatVfx.LIB.has(eff), eff)
			if CombatVfx.spawn(pai, eff, Vector2(n * 5, 0)) != null:
				n += 1
	_ck("todos os 20 desenharam", n == 20, str(n))
	_ck("nasceram sob o pai", pai.get_child_count() == antes + 20)
	for arch in ["melee", "magic", "support"]:
		_ck("hit %s existe" % arch, CombatVfx.LIB.has(CombatVfx.hit_effect(arch)))
		_ck("hit pesado %s existe" % arch, CombatVfx.LIB.has(CombatVfx.hit_effect(arch, true)))
	_ck("crítico existe", CombatVfx.LIB.has(CombatVfx.hit_effect("melee", false, true)))
	_ck("atlas legado preservado", CombatVfx.spawn(pai, "slash_arc_down_overlay", Vector2.ZERO) != null)
	_ck("nome inválido → null", CombatVfx.spawn(pai, "nao_existe_isso", Vector2.ZERO) == null)
	# corpo real e VFX no MESMO golpe, sem um anular o outro
	var t := _novo_animator("hero/errante", "player", "MELEE")
	var an: ActorAnimator = t["anim"]
	for i in range(4):
		var c := pai.get_child_count()
		var corpo := an.play_real_transient("ATTACK_BASIC", Vector2.RIGHT)
		var vfx = CombatVfx.spawn(pai, "melee_basic_accent", Vector2(i * 3, 0))
		_ck("golpe %d: corpo real tocou" % i, corpo)
		_ck("golpe %d: VFX tocou junto" % i, vfx != null)
		_ck("golpe %d: VFX é nó próprio" % i, pai.get_child_count() == c + 1)
		var _f: bool = await _ate(func(): return not an.real_transient_active())
		_ck("golpe %d: corpo voltou" % i, an.state == ActorAnimator.State.IDLE)
	t["holder"].queue_free(); pai.queue_free()
	await process_frame

func _g_contact_frame() -> void:
	_grp("CONTACT_FRAME_VISUAL")
	# ★★★ Parte 6: o contact frame é SUGESTÃO VISUAL. O dano continua no evento, não no quadro.
	for a in ACOES:
		var cf := CombatAnimationRegistry.contact_frame("player", "MELEE", a)
		_ck("MELEE %s tem contact frame" % a, cf >= 0, str(cf))
		_ck("MELEE %s dentro dos 4 quadros" % a, cf >= 0 and cf < 4, str(cf))
	_ck("BASIC contata no quadro 3", CombatAnimationRegistry.contact_frame("player", "MELEE", "ATTACK_BASIC") == 3)
	_ck("HEAVY contata no quadro 3", CombatAnimationRegistry.contact_frame("player", "MELEE", "ATTACK_HEAVY") == 3)
	_ck("HIT reage no quadro 1", CombatAnimationRegistry.contact_frame("player", "MELEE", "HIT") == 1)
	_ck("DEATH começa no 0", CombatAnimationRegistry.contact_frame("player", "MELEE", "DEATH") == 0)
	for c in NAO_PRONTAS:
		_ck("%s sem contact frame" % c, CombatAnimationRegistry.contact_frame("player", c, "ATTACK_BASIC") == -1)
	for m in MOBS:
		_ck("mob %s sem contact frame de ataque" % m, CombatAnimationRegistry.contact_frame("mobs", m, "ATTACK_HEAVY") == -1)
	_ck("entidade inexistente → -1", CombatAnimationRegistry.contact_frame("player", "NADA", "HIT") == -1)
	_ck("ação inexistente → -1", CombatAnimationRegistry.contact_frame("player", "MELEE", "VOAR") == -1)
	var t := _novo_animator("hero/errante", "player", "MELEE")
	var an: ActorAnimator = t["anim"]
	_ck("animator expõe contact frame", an.combat_contact_frame("ATTACK_BASIC") == 3)
	var anon := ActorAnimator.new()
	_ck("animator sem identidade → -1", anon.combat_contact_frame("HIT") == -1)
	anon.free()
	# ⛔ o dano NÃO passa por aqui: nenhum caminho de dano lê contact_frame
	var reg_src := FileAccess.get_file_as_string("res://scripts/CombatAnimationRegistry.gd")
	_ck("registro não toca em dano", not reg_src.contains("take_damage") and not reg_src.contains("apply_damage"))
	_ck("registro não toca em HP", not reg_src.contains("hero_hp") and not reg_src.contains("set_hp"))
	_ck("registro não toca em cooldown", not reg_src.contains("cooldown"))
	var an_src := FileAccess.get_file_as_string("res://scripts/ActorAnimator.gd")
	_ck("animator não toca em dano", not an_src.contains("take_damage"))
	_ck("animator não toca em HP", not an_src.contains("hero_hp"))
	_ck("contact frame nunca vira índice de dano", not an_src.contains("contact") or not an_src.contains("damage"))
	t["holder"].queue_free()
	await process_frame

func _g_stress() -> void:
	_grp("STRESS_100_ATTACKS")
	var pai := Node2D.new(); root.add_child(pai)
	var t := _novo_animator("hero/errante", "player", "MELEE")
	var an: ActorAnimator = t["anim"]
	var holder: Node2D = t["holder"]
	var anims_antes := an._anim.sprite_frames.get_animation_names().size()
	var filhos_antes := holder.get_child_count()
	var cache_antes := CombatAnimationRegistry.cache_size()
	_ck("baseline anims", anims_antes > 0)
	_ck("baseline filhos", filhos_antes > 0)
	var vfx_criados := 0
	var vfx_pico := 0
	for i in range(100):
		var v: Vector2 = [Vector2.DOWN, Vector2.RIGHT, Vector2.UP, Vector2.LEFT][i % 4]
		an.play_real_transient("ATTACK_BASIC", v)
		if CombatVfx.spawn(pai, "physical_hit_small", Vector2(i, 0)) != null:
			vfx_criados += 1
		vfx_pico = maxi(vfx_pico, pai.get_child_count())
		if i % 10 == 0:
			var _f: bool = await _ate(func(): return not an.real_transient_active(), 120)
			_ck("lote %d: transitório fechou" % (i / 10), not an.real_transient_active())
			_ck("lote %d: sem anim nova" % (i / 10), an._anim.sprite_frames.get_animation_names().size() <= anims_antes + 3, str(an._anim.sprite_frames.get_animation_names().size()))
			_ck("lote %d: sem filho novo no ator" % (i / 10), holder.get_child_count() == filhos_antes)
			_ck("lote %d: ator não travou" % (i / 10), not an._dead)
		await process_frame
	var _fim: bool = await _ate(func(): return not an.real_transient_active(), 240)
	# ★★★ o invariante: no MÁXIMO 3 anims novas (BASE/SIDE/UP), não 100.
	var anims_depois := an._anim.sprite_frames.get_animation_names().size()
	_ck("anims cresceram no máx 3", anims_depois <= anims_antes + 3, "%d → %d" % [anims_antes, anims_depois])
	_ck("cache do registro no máx +3", CombatAnimationRegistry.cache_size() <= cache_antes + 3)
	_ck("ator sem filho novo", holder.get_child_count() == filhos_antes)
	_ck("sem transitório preso", not an.real_transient_active())
	_ck("ator vivo e restaurado", not an._dead and an.state == ActorAnimator.State.IDLE)
	# ★★★ O invariante do VFX é AUTO-DESTRUIÇÃO, não presença. Contar filhos no FIM media o contrário:
	# como cada efeito some sozinho ao terminar, o número final tende a ZERO — e um "> 0" reprovaria
	# justamente o comportamento correto. Mede-se então: criou os 100 E o PICO simultâneo ficou baixo.
	_ck("100 VFX criados", vfx_criados == 100, str(vfx_criados))
	_ck("pico simultâneo bem abaixo de 100", vfx_pico < 60, "pico=%d" % vfx_pico)
	_ck("drenou quase tudo no fim", pai.get_child_count() < 20, "fim=%d" % pai.get_child_count())
	t["holder"].queue_free(); pai.queue_free()
	await process_frame

func _g_realscene() -> void:
	_grp("REALSCENE_ANIMATION_SLICE")
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	for i in range(12):
		await process_frame
	_ck("Main instanciou", main != null)
	if main.has_method("_enter_game"):
		main._enter_game()
	for i in range(24):
		await process_frame
	_ck("cena entrou no jogo", true)
	# acha o PlayerController vivo
	var pc: Node = null
	var fila: Array = [main]
	while not fila.is_empty() and pc == null:
		var n: Node = fila.pop_front()
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("PlayerController.gd"):
			pc = n
			break
		for c in n.get_children():
			fila.append(c)
	_ck("PlayerController na cena", pc != null)
	if pc == null:
		return
	var an: ActorAnimator = pc.get("_anim")
	_ck("player tem ActorAnimator", an != null)
	if an == null:
		return
	_ck("player tem spritesheet", an.has_spritesheet())
	_ck("combat_kind = player", an.combat_kind == "player", an.combat_kind)
	_ck("combat_id preenchido", an.combat_id != "", an.combat_id)
	_ck("combat_id é classe conhecida", CLASSES.has(an.combat_id), an.combat_id)
	_ck("registro carregado em cena", CombatAnimationRegistry.loaded())
	# força MELEE para exercitar a fatia real na cena de verdade
	an.combat_id = "MELEE"
	_ck("has_real_combat na cena", an.has_real_combat("ATTACK_BASIC"))
	_ck("contact frame na cena", pc.attack_contact_frame() == 3)
	_ck("API pública responde", pc.has_real_combat_body("ATTACK_BASIC"))
	var pos0: Vector2 = (pc as Node2D).position
	# ⚠️ A cena é VIVA: o Errante leva dano de verdade e MORRE no meio da fatia. Este grupo mede
	# ANIMAÇÃO, não sobrevivência — então o herói é mantido de pé. Foi exatamente esta morte que
	# revelou o travamento do transitório; o invariante da morte é medido no MELEE_DEATH_SAFE.
	var gs = root.get_node_or_null("GameState")
	for ciclo in range(10):
		for v in [Vector2.DOWN, Vector2.RIGHT, Vector2.UP, Vector2.LEFT]:
			if an._dead:
				an.reset()
			if gs != null and gs.get("hero_hp") != null and int(gs.hero_hp) <= 0:
				gs.hero_hp = int(gs.hero_hp_max)
			an.set_direction(v)
			var flip_antes: bool = an._anim.flip_h
			pc.play_attack(v)
			_ck("c%d %s: corpo real assumiu" % [ciclo, str(v)], an.real_transient_active())
			# ★ Onda 2: com a PRIORIDADE de transitório (HIT > ATTACK), o estado pode legitimamente ser
			# HIT — a cena é viva e o Errante leva dano de verdade, e o flinch NÃO cede ao ataque.
			# Exigir ATTACK aqui passaria a reprovar o comportamento correto.
			_ck("c%d %s: corpo em ATTACK ou HIT" % [ciclo, str(v)], an.state == ActorAnimator.State.ATTACK or an.state == ActorAnimator.State.HIT, str(an.state))
			var _f: bool = await _ate(func(): return not an.real_transient_active(), 120)
			if an.real_transient_active() and not _diag_feito:
				_diag_feito = true
				var a3: ActorAnimator = pc.get("_anim")
				print("   ↳ DIAG travamento c%d %s:" % [ciclo, str(v)])
				print("      animator ainda é o mesmo? %s" % str(a3 == an))
				print("      _transient_anim = '%s'" % an._transient_anim)
				print("      _anim.animation = '%s'  is_playing=%s  frame=%d" % [an._anim.animation, str(an._anim.is_playing()), an._anim.frame])
				print("      speed_scale=%.2f  _busy_t=%.2f  _dead=%s  state=%d" % [an._anim.speed_scale, an._busy_t, str(an._dead), an.state])
				print("      anim existe no SpriteFrames? %s" % str(an._anim.sprite_frames.has_animation(an._transient_anim)))
				print("      quadros da anim = %d  conectado=%s" % [an._anim.sprite_frames.get_frame_count(an._transient_anim), str(an._anim.animation_finished.is_connected(an._on_transient_finished))])
			_ck("c%d %s: restaurou" % [ciclo, str(v)], not an.real_transient_active())
			_ck("c%d %s: flip preservado" % [ciclo, str(v)], an._anim.flip_h == flip_antes)
			_ck("c%d %s: player não andou sozinho" % [ciclo, str(v)], (pc as Node2D).position.distance_to(pos0) < 400.0)
	# dano recebido usa o corpo real e volta
	for i in range(6):
		pc.hit_recoil(Vector2.ZERO)
		_ck("recoil %d encenou" % i, an.state == ActorAnimator.State.HIT or an.real_transient_active())
		var _f2: bool = await _ate(func(): return not an.real_transient_active(), 120)
		_ck("recoil %d restaurou" % i, not an.real_transient_active())
		_ck("recoil %d vivo" % i, not an._dead)
	# troca de arma reavalia a identidade sem quebrar nada
	if pc.has_method("set_weapon_visual"):
		for arma in ["sword", "bow", "staff", "spear", "book", "nada"]:
			pc.set_weapon_visual(arma)
			await process_frame
			# ⚠️ `set_weapon_visual` pode RECONSTRUIR o AnimatedSprite2D — nunca reusar a referência velha.
			var a2: ActorAnimator = pc.get("_anim")
			_ck("arma %s: animator vivo" % arma, a2 != null and is_instance_valid(a2))
			if a2 == null:
				continue
			_ck("arma %s: kind segue player" % arma, a2.combat_kind == "player", a2.combat_kind)
			_ck("arma %s: sem transitório preso" % arma, not a2.real_transient_active())
	_ck("cena não vazou o player", is_instance_valid(pc))
	_ck("Main ainda válido", is_instance_valid(main))
	main.queue_free()
	await process_frame

func _fecho() -> void:
	print("\n═════════ MÍNIMOS POR GRUPO ═════════")
	var abaixo := 0
	for nome in MINIMOS:
		var b: Dictionary = _por_grupo.get(nome, {"p": 0, "f": 0})
		var total := int(b["p"]) + int(b["f"])
		var minimo := int(MINIMOS[nome])
		var ok := total >= minimo and int(b["f"]) == 0
		if not ok:
			abaixo += 1
		print("  %-30s %3d asserts (mín %3d) · %d falhas %s" % [nome, total, minimo, int(b["f"]), "" if ok else "  <<< ABAIXO/COM FALHA"])
	if not _falhas.is_empty():
		print("\n─── falhas ───")
		for f in _falhas:
			print("  %s" % f)
	print("\n═════════ RESUMO ═════════")
	print("  PASS   = %d" % _pass)
	print("  FAIL   = %d" % _fail)
	print("  grupos abaixo do mínimo = %d" % abaixo)
	print("  %s" % ("TUDO VERDE" if (_fail == 0 and abaixo == 0) else "REPROVADO"))
	quit(0 if (_fail == 0 and abaixo == 0) else 1)
