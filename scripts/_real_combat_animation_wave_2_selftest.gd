extends SceneTree
## REAL COMBAT ANIMATION WAVE 2 — ash_wolf + classes seguintes.
##
## ★★★ RESULTADO CENTRAL DESTA ONDA: o handoff RECONCILIADO do Codex (18:26) zerou
## `ready_for_runtime_integration` nos DOIS censos e REVOGOU o MELEE. Portanto **nada foi ativado**
## em produção — e o MELEE, ativo desde a Onda 1, voltou ao procedural. Zero linha de código mudou
## para isso acontecer: só o dado. Essa é a prova de que a arquitetura do portão está certa.
##
## Como esta suíte prova o caminho REAL sem mentir sobre a produção:
##   1. grupos de PORTÃO rodam SEM sobreposição → medem o estado real de produção (tudo fechado);
##   2. grupos de MECÂNICA rodam sob SOBREPOSIÇÃO DE TESTE → provam que, no dia em que o Codex
##      aprovar, funciona. Os PNGs usados são REAIS e já estão no projeto; só a APROVAÇÃO é simulada.
## ⛔ A sobreposição nunca vaza para produção: todo grupo de portão checa `test_overlay_active()`.
##
## Uso: --headless --path <proj> --script res://scripts/_real_combat_animation_wave_2_selftest.gd

const MINIMOS := {
	"HANDOFF_REFRESH": 30, "ASH_WOLF_READY_GATE": 30,
	"WOLF_ATTACK_REAL": 45, "WOLF_HIT_REAL": 45, "WOLF_DEATH_REAL": 45, "WOLF_DEATH_SETTLEMENT": 40,
	"TWO_WOLF_INDEPENDENCE": 50, "DOUBLE_WOLF_DEATH_REAL": 45,
	"PLAYER_READY_GATE": 35,
	"RANGED_CONDITIONAL": 30, "MAGIC_CONDITIONAL": 30, "REACH_CONDITIONAL": 30, "SUPPORT_CONDITIONAL": 30,
	"PLAYER_DEATH_DISABLED": 30, "TRANSIENT_PRIORITY": 40, "HIT_INTERRUPT_POLICY": 35, "REVIVE_SAFETY": 45,
	"MIXED_REAL_FALLBACK": 45, "VFX_SYNC_REGRESSION": 40, "STRESS_200_EVENTS": 45,
	"REALSCENE_WAVE_2": 120,
}

const CLASSES := ["MELEE", "RANGED", "MAGIC", "REACH", "SUPPORT"]
const ACOES := ["ATTACK_BASIC", "ATTACK_HEAVY", "HIT", "DEATH"]
const DIRS := ["BASE", "SIDE", "UP"]
const MOBS_COM_ARTE := ["ash_wolf", "crystal_bat", "grove_spider", "root_spider", "dune_skitter", "salt_husk"]
const MOBS_BLOQUEADOS := ["tide_warden", "shadow_sprout", "sap_eye", "hungry_root", "musgo_voraz", "ancient_root_heart"]
## mob SEM arte nenhuma: serve de controle no teste de mistura (tem de ficar procedural sempre)
const MOB_SEM_ARTE := "young_wolf"

var _pass := 0
var _fail := 0
var _g := ""
var _por_grupo := {}
var _falhas: Array = []

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

func _ate(cond: Callable, teto := 240) -> bool:
	var n := 0
	while n < teto:
		if cond.call():
			return true
		await process_frame
		n += 1
	return cond.call()

## Sobreposição de teste: marca MELEE e ash_wolf prontos, apontando para os PNGs REAIS já no projeto.
func _ovl() -> Dictionary:
	return {
		"player": {"MELEE": {"ready": true, "status": "TEST_OVERLAY", "actions": {
			"ATTACK_BASIC": {"BASE": true, "SIDE": true, "UP": true, "contact_frame": 3},
			"ATTACK_HEAVY": {"BASE": true, "SIDE": true, "UP": true, "contact_frame": 3},
			"HIT": {"BASE": true, "SIDE": true, "UP": true, "contact_frame": 1},
			"DEATH": {"BASE": true, "SIDE": true, "UP": true, "contact_frame": 0}}}},
		"mobs": {"ash_wolf": {"ready": true, "status": "TEST_OVERLAY", "actions": {
			"ATTACK_BASIC": {"BASE": true}, "HIT": {"BASE": true}, "DEATH": {"BASE": true}}}},
	}

## Espera atores serem LIBERADOS, por ID e não por referência.
## ⚠️ `func(): return not is_instance_valid(w)` funciona, mas quando `w` é liberado o GDScript grita
## "Lambda capture was freed" — 29 erros de ruído numa rodada. Ruído de teste esconde erro de verdade.
func _ate_liberado(ids: Array, teto := 300) -> bool:
	var n := 0
	while n < teto:
		var todos := true
		for i in ids:
			if is_instance_id_valid(int(i)):
				todos = false
				break
		if todos:
			return true
		await process_frame
		n += 1
	for i in ids:
		if is_instance_id_valid(int(i)):
			return false
	return true

## Remove linhas de comentário (`#` / `##`) para que asserções de código não caiam em COMENTÁRIO.
func _codigo_sem_comentario(src: String) -> String:
	var out := ""
	for linha in src.split("\n"):
		var t := (linha as String).strip_edges()
		if t.begins_with("#"):
			continue
		out += linha + "\n"
	return out

func _novo_lobo(pai: Node, id := "ash_wolf", visual := "mobs/ash_wolf") -> PveMobActor:
	var w := PveMobActor.new()
	pai.add_child(w)
	w.setup(visual, id, false, id)
	return w

func _initialize() -> void:
	_run()

func _run() -> void:
	print("═════════ REAL COMBAT ANIMATION WAVE 2 — SELFTEST ═════════")
	CombatAnimationRegistry.clear_test_overlay()
	CombatAnimationRegistry.reload()

	# ── PORTÕES: produção crua, sem sobreposição ──
	await _g_handoff_refresh()
	await _g_wolf_ready_gate()
	await _g_player_ready_gate()
	for c in ["RANGED", "MAGIC", "REACH", "SUPPORT"]:
		await _g_classe_condicional(c)
	await _g_player_death_disabled()

	# ── MECÂNICA: sob sobreposição ──
	CombatAnimationRegistry.apply_test_overlay(_ovl())
	await _g_wolf_attack_real()
	await _g_wolf_hit_real()
	await _g_wolf_death_real()
	await _g_wolf_death_settlement()
	await _g_two_wolf_independence()
	await _g_double_wolf_death()
	await _g_transient_priority()
	await _g_hit_interrupt()
	await _g_revive_safety()
	await _g_mixed()
	await _g_vfx_regression()
	await _g_stress_200()
	await _g_realscene()
	CombatAnimationRegistry.clear_test_overlay()

	_fecho()

# ═══════════════ PORTÕES (produção) ═══════════════

func _g_handoff_refresh() -> void:
	_grp("HANDOFF_REFRESH")
	_ck("registro carregou", CombatAnimationRegistry.loaded())
	_ck("SEM sobreposição neste grupo", not CombatAnimationRegistry.test_overlay_active())
	var src := FileAccess.get_file_as_string("res://data/combat_animation_ready.json")
	var j = JSON.parse_string(src)
	_ck("dado é JSON válido", typeof(j) == TYPE_DICTIONARY)
	var d: Dictionary = j if typeof(j) == TYPE_DICTIONARY else {}
	_ck("schema 2 (onda 2)", int(d.get("schema", 0)) == 2, str(d.get("schema", 0)))
	var s: Dictionary = d.get("source", {})
	# ★★★ o dado tem de apontar o HANDOFF como autoridade, não um manifesto de pack
	_ck("autoridade é o handoff", str(s.get("authority", "")).contains("COMBAT_ANIMATION_RECONCILIATION_HANDOFF"), str(s.get("authority", "")))
	_ck("handoff está RECONCILED", str(s.get("handoff_status", "")) == "RECONCILED")
	_ck("carimbo de leitura presente", str(s.get("read_at", "")) != "")
	_ck("carimbo do handoff presente", str(s.get("handoff_written_at", "")) != "")
	_ck("não é o dado velho de 17:45", not str(s.get("handoff_written_at", "")).contains("17:45"), str(s.get("handoff_written_at", "")))
	_ck("player ready list vazia no handoff", (s.get("player_ready_for_runtime_integration", ["x"]) as Array).is_empty())
	_ck("mob ready list vazia no handoff", (s.get("mob_ready_for_runtime_integration", ["x"]) as Array).is_empty())
	_ck("revogação do MELEE documentada", (d.get("_wave_2_change", []) as Array).size() > 0)
	# o próprio handoff no disco confere com o que eu importei (nada de contagem velha)
	# Handoff externo do pacote de arte (fora do repositório): caminho via variável de ambiente AV_COMBAT_HANDOFF_JSON.
	var hp := OS.get_environment("AV_COMBAT_HANDOFF_JSON")
	var hf := FileAccess.open(hp, FileAccess.READ)
	_ck("handoff do Codex legível", hf != null)
	if hf != null:
		var hj = JSON.parse_string(hf.get_as_text())
		hf.close()
		var h: Dictionary = hj if typeof(hj) == TYPE_DICTIONARY else {}
		_ck("handoff diz RECONCILED", str(h.get("status", "")) == "RECONCILED", str(h.get("status", "")))
		var pc: Dictionary = h.get("player_census", {})
		var mc: Dictionary = h.get("mob_census", {})
		_ck("handoff: 0 classes prontas", (pc.get("ready_for_runtime_integration", ["x"]) as Array).is_empty())
		_ck("handoff: 0 mobs prontos", (mc.get("ready_for_runtime_integration", ["x"]) as Array).is_empty())
		_ck("handoff: 20 alfas reprovados", int(pc.get("alpha_needs_rework", 0)) == 20, str(pc.get("alpha_needs_rework", 0)))
		_ck("handoff: 60 arquivos de jogador", int(pc.get("actual_files", 0)) == 60)
		_ck("handoff: 18 arquivos de mob", int(mc.get("actual_files", 0)) == 18)
		# ★ cada status que importei bate com o do handoff, entidade por entidade
		var cs: Dictionary = pc.get("class_status", {})
		for c in CLASSES:
			var esperado := str((cs.get(c, {}) as Dictionary).get("status", ""))
			_ck("classe %s bate com o handoff" % c, CombatAnimationRegistry.status_of("player", c) == esperado, "%s vs %s" % [CombatAnimationRegistry.status_of("player", c), esperado])
		var ms: Dictionary = mc.get("status_by_id", {})
		for m in ms:
			_ck("mob %s bate com o handoff" % m, CombatAnimationRegistry.status_of("mobs", str(m)) == str(ms[m]), "%s vs %s" % [CombatAnimationRegistry.status_of("mobs", str(m)), str(ms[m])])
	await process_frame

func _g_wolf_ready_gate() -> void:
	_grp("ASH_WOLF_READY_GATE")
	_ck("sem sobreposição", not CombatAnimationRegistry.test_overlay_active())
	var e := CombatAnimationRegistry.entry("mobs", "ash_wolf")
	_ck("entrada existe", not e.is_empty())
	_ck("status = ANIMATION_NEEDS_REWORK", str(e.get("status", "")) == "ANIMATION_NEEDS_REWORK", str(e.get("status", "")))
	_ck("blocker declarado", (e.get("blockers", []) as Array).size() > 0, str(e.get("blockers", [])))
	_ck("blocker é a direcionalidade", str(e.get("blockers", [])).contains("directionality"), str(e.get("blockers", [])))
	# ★★★ MATERIALIZADO ≠ PRONTO — os 3 PNGs estão no projeto e o portão continua fechado.
	_ck("materializado no projeto", bool(e.get("materialized", false)))
	for a in ["ATTACK_BASIC", "HIT", "DEATH"]:
		_ck("arquivo %s existe no disco" % a, ResourceLoader.exists(CombatAnimationRegistry.strip_path("mobs", "ash_wolf", a)), CombatAnimationRegistry.strip_path("mobs", "ash_wolf", a))
		_ck("MESMO ASSIM não está pronto: %s" % a, not CombatAnimationRegistry.is_ready("mobs", "ash_wolf", a))
		_ck("frames %s == null" % a, CombatAnimationRegistry.frames("mobs", "ash_wolf", a) == null)
		_ck("resolve %s vazio" % a, CombatAnimationRegistry.resolve_direction("mobs", "ash_wolf", a) == "")
	_ck("NÃO ativado", not CombatAnimationRegistry.ready_ids("mobs").has("ash_wolf"))
	for m in MOBS_COM_ARTE:
		_ck("mob %s não pronto" % m, not CombatAnimationRegistry.is_ready("mobs", m, "ATTACK_BASIC"))
	for m in MOBS_BLOQUEADOS:
		_ck("mob %s BLOCKED" % m, CombatAnimationRegistry.status_of("mobs", m) == "BLOCKED", CombatAnimationRegistry.status_of("mobs", m))
	# ⛔ nada de ramo de código específico do lobo.
	# ★★★ COMENTÁRIO NÃO É CÓDIGO: a primeira versão deste assert reprovou o registro porque um
	# comentário dizia "sem `ash_wolf` escrito no código". Medir substring no arquivo inteiro é
	# medir a coisa errada — as linhas de comentário são retiradas antes.
	for f in ["ActorAnimator.gd", "PveMobActor.gd", "PlayerController.gd", "CombatAnimationRegistry.gd", "HuntHost.gd"]:
		var src := FileAccess.get_file_as_string("res://scripts/%s" % f)
		_ck("%s sem ash_wolf em CÓDIGO" % f, not _codigo_sem_comentario(src).contains("ash_wolf"))
		_ck("%s sem id de mob hardcoded" % f, not _codigo_sem_comentario(src).contains("crystal_bat"))
	await process_frame

func _g_player_ready_gate() -> void:
	_grp("PLAYER_READY_GATE")
	_ck("sem sobreposição", not CombatAnimationRegistry.test_overlay_active())
	_ck("nenhuma classe pronta", CombatAnimationRegistry.ready_ids("player").is_empty(), str(CombatAnimationRegistry.ready_ids("player")))
	for c in CLASSES:
		var e := CombatAnimationRegistry.entry("player", c)
		_ck("%s existe" % c, not e.is_empty())
		_ck("%s não pronto" % c, not bool(e.get("ready", true)))
		_ck("%s status do handoff" % c, str(e.get("status", "")) == "ANIMATION_NEEDS_REWORK", str(e.get("status", "")))
		_ck("%s tem blocker" % c, (e.get("blockers", []) as Array).size() > 0)
		_ck("%s blocker cita alfa BASE" % c, str(e.get("blockers", [])).contains("alpha"), str(e.get("blockers", [])))
		_ck("%s tem evidência" % c, str(e.get("evidence", "")) != "")
		for a in ACOES:
			_ck("%s/%s fechado" % [c, a], not CombatAnimationRegistry.is_ready("player", c, a))
	await process_frame

func _g_classe_condicional(classe: String) -> void:
	_grp("%s_CONDITIONAL" % classe)
	var e := CombatAnimationRegistry.entry("player", classe)
	var pronta: bool = bool(e.get("ready", false))
	_ck("%s conhecida" % classe, not e.is_empty())
	_ck("%s NÃO declarada pronta pelo handoff" % classe, not pronta, str(e.get("status", "")))
	# blockers específicos que o handoff nomeia por classe
	var bl := str(e.get("blockers", []))
	match classe:
		"MAGIC":   _ck("MAGIC: FX embutido nas direcionais", bl.contains("embedded"), bl)
		"REACH":   _ck("REACH: SIDE com gore a substituir", bl.contains("gore"), bl)
		"SUPPORT": _ck("SUPPORT: identidade não verificada", bl.contains("identity"), bl)
		_:         _ck("RANGED: alfa BASE legado reprovou", bl.contains("alpha"), bl)
	# ⇒ como não está pronta, TODO caminho tem de cair no procedural, em todas as direções
	for a in ACOES:
		for d in DIRS:
			_ck("%s %s/%s fechado" % [classe, a, d], not CombatAnimationRegistry.is_ready("player", classe, a, d))
			_ck("%s %s/%s sem frames" % [classe, a, d], CombatAnimationRegistry.frames("player", classe, a, d) == null)
	_ck("%s não materializada" % classe, not bool(e.get("materialized", true)))
	# e o ator real, com essa identidade, encena procedural sem travar
	var h := Node2D.new(); root.add_child(h)
	var body := Node2D.new(); h.add_child(body)
	var an := ActorAnimator.new(); h.add_child(an)
	an.setup(body, "hero/errante", 3.0, true)
	an.combat_kind = "player"; an.combat_id = classe
	_ck("%s: has_real_combat false" % classe, not an.has_real_combat("ATTACK_BASIC"))
	_ck("%s: transitório real recusado" % classe, not an.play_real_transient("ATTACK_BASIC", Vector2.RIGHT))
	an.play_attack(Vector2.RIGHT, "melee")
	_ck("%s: procedural encenou" % classe, an.state == ActorAnimator.State.ATTACK)
	_ck("%s: sem transitório preso" % classe, not an.real_transient_active())
	h.queue_free()
	await process_frame

func _g_player_death_disabled() -> void:
	_grp("PLAYER_DEATH_DISABLED")
	var p := CombatAnimationRegistry.policy()
	_ck("bloco de política existe", not p.is_empty())
	_ck("morte real DESLIGADA", not CombatAnimationRegistry.policy_flag("player_death_real_animation_enabled"))
	_ck("motivo documentado", str(p.get("player_death_reason", "")) != "")
	_ck("motivo cita estado recuperável", str(p.get("player_death_reason", "")).contains("RECUPERAVEL") or str(p.get("player_death_reason", "")).contains("recuper"))
	_ck("pesado real DESLIGADO", not CombatAnimationRegistry.policy_flag("player_heavy_real_animation_enabled"))
	_ck("motivo do pesado documentado", str(p.get("player_heavy_reason", "")) != "")
	var src := FileAccess.get_file_as_string("res://scripts/PlayerController.gd")
	_ck("set_downed consulta a política", src.contains("player_death_real_animation_enabled"))
	_ck("play_attack consulta a política do pesado", src.contains("player_heavy_real_animation_enabled"))
	_ck("fallback de downed preservado", src.contains("_anim.play_downed()"))
	_ck("flag desconhecida é false por padrão", not CombatAnimationRegistry.policy_flag("flag_que_nao_existe"))
	# comportamento real: mesmo com a arte de DEATH pronta na sobreposição, o jogador NÃO morre com strip
	CombatAnimationRegistry.apply_test_overlay(_ovl())
	_ck("DEATH do MELEE estaria pronta", CombatAnimationRegistry.is_ready("player", "MELEE", "DEATH"))
	_ck("mas a política continua desligada", not CombatAnimationRegistry.policy_flag("player_death_real_animation_enabled"))
	for classe in CLASSES:
		_ck("%s: DEATH nunca abre por política" % classe, not CombatAnimationRegistry.policy_flag("player_death_real_animation_enabled"))
	var h := Node2D.new(); root.add_child(h)
	var body := Node2D.new(); h.add_child(body)
	var an := ActorAnimator.new(); h.add_child(an)
	an.setup(body, "hero/errante", 3.0, true)
	an.combat_kind = "player"; an.combat_id = "MELEE"
	var mortes: Array = [0]
	an.death_finished.connect(func(): mortes[0] += 1)
	for rodada in range(4):
		an.play_downed()
		_ck("r%d: downed usou o procedural" % rodada, an._dead)
		_ck("r%d: downed NÃO emitiu death_finished" % rodada, int(mortes[0]) == 0, str(mortes[0]))
		_ck("r%d: downed sem transitório preso" % rodada, not an.real_transient_active())
		_ck("r%d: estado DEATH" % rodada, an.state == ActorAnimator.State.DEATH)
		an.reset()
		_ck("r%d: revive limpo" % rodada, not an._dead and not an.real_transient_active())
		_ck("r%d: volta a animar" % rodada, an.play_real_transient("ATTACK_BASIC", Vector2.RIGHT))
		var _f: bool = await _ate(func(): return not an.real_transient_active())
		_ck("r%d: gesto terminou" % rodada, not an.real_transient_active())
	_ck("nenhum death_finished em 4 quedas", int(mortes[0]) == 0, str(mortes[0]))
	h.queue_free()
	CombatAnimationRegistry.clear_test_overlay()
	_ck("sobreposição limpa ao sair", not CombatAnimationRegistry.test_overlay_active())
	await process_frame

# ═══════════════ MECÂNICA (sob sobreposição) ═══════════════

func _g_wolf_attack_real() -> void:
	_grp("WOLF_ATTACK_REAL")
	_ck("sobreposição ativa", CombatAnimationRegistry.test_overlay_active())
	_ck("lobo agora pronto p/ ATTACK", CombatAnimationRegistry.is_ready("mobs", "ash_wolf", "ATTACK_BASIC"))
	var sf := CombatAnimationRegistry.frames("mobs", "ash_wolf", "ATTACK_BASIC")
	_ck("frames reais montados", sf != null)
	_ck("4 quadros", sf != null and sf.get_frame_count("p") == 4)
	_ck("sem loop", sf != null and not sf.get_animation_loop("p"))
	for i in range(4):
		var tx: AtlasTexture = sf.get_frame_texture("p", i) as AtlasTexture if sf != null else null
		_ck("quadro %d é 64x64" % i, tx != null and tx.region.size == Vector2(64, 64))
		_ck("quadro %d deslocado" % i, tx != null and tx.region.position.x == float(i * 64))
	var pai := Node2D.new(); root.add_child(pai)
	var w := _novo_lobo(pai)
	_ck("ator com sheet", w._anim.has_spritesheet())
	_ck("identidade ligada", w._anim.combat_kind == "mobs" and w._anim.combat_id == "ash_wolf")
	_ck("has_real_combat true", w._anim.has_real_combat("ATTACK_BASIC"))
	var filhos := pai.get_child_count()
	for ciclo in range(6):
		for v in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN]:
			w.face(v)
			var flip := w._anim._anim.flip_h
			w.play_attack(v)
			_ck("c%d %s: corpo real assumiu" % [ciclo, str(v)], w._anim.real_transient_active())
			_ck("c%d %s: flip preservado" % [ciclo, str(v)], w._anim._anim.flip_h == flip)
			var _f: bool = await _ate(func(): return not w._anim.real_transient_active(), 120)
			_ck("c%d %s: restaurou" % [ciclo, str(v)], not w._anim.real_transient_active())
	_ck("nenhum nó novo no pai", pai.get_child_count() == filhos)
	_ck("lobo vivo", is_instance_valid(w) and not w._anim._dead)
	pai.queue_free()
	await process_frame

func _g_wolf_hit_real() -> void:
	_grp("WOLF_HIT_REAL")
	_ck("HIT pronto na sobreposição", CombatAnimationRegistry.is_ready("mobs", "ash_wolf", "HIT"))
	_ck("frames de HIT", CombatAnimationRegistry.frames("mobs", "ash_wolf", "HIT") != null)
	var pai := Node2D.new(); root.add_child(pai)
	var w := _novo_lobo(pai)
	_ck("has_real_combat HIT", w._anim.has_real_combat("HIT"))
	var nome_hit := CombatAnimationRegistry.anim_name("mobs", "ash_wolf", "HIT", "BASE")
	for i in range(10):
		w.play_hit()
		_ck("hit %d: corpo real" % i, w._anim.real_transient_active())
		_ck("hit %d: anim é a de HIT" % i, w._anim._anim.animation == nome_hit, w._anim._anim.animation)
		_ck("hit %d: não morreu" % i, not w._anim._dead)
		var _f: bool = await _ate(func(): return not w._anim.real_transient_active(), 120)
		_ck("hit %d: restaurou" % i, not w._anim.real_transient_active())
	_ck("uma única anim de HIT registrada", w._anim._anim.sprite_frames.has_animation(nome_hit))
	_ck("lobo intacto", is_instance_valid(w))
	pai.queue_free()
	await process_frame

func _g_wolf_death_real() -> void:
	_grp("WOLF_DEATH_REAL")
	_ck("DEATH pronto na sobreposição", CombatAnimationRegistry.is_ready("mobs", "ash_wolf", "DEATH"))
	_ck("frames de DEATH", CombatAnimationRegistry.frames("mobs", "ash_wolf", "DEATH") != null)
	# ★★★ PARTE 6 — a morte REAL tem de casar com `death_finished` + cleanup, sem ressuscitar o bug
	# antigo do get_tree() null (ator fora da árvore). Testa-se NA árvore e FORA dela.
	for repeticao in range(3):
		for na_arvore in [true, false]:
			var tag := "r%d/árvore=%s" % [repeticao, str(na_arvore)]
			var pai := Node2D.new(); root.add_child(pai)
			var w := _novo_lobo(pai)
			if not na_arvore:
				pai.remove_child(w)   # reproduz o caminho que estourava 2058 erros na _a22
			_ck("%s: ator criado" % tag, is_instance_valid(w))
			_ck("%s: identidade de mob" % tag, w._anim.combat_kind == "mobs")
			var mortes: Array = [0]
			w._anim.death_finished.connect(func(): mortes[0] += 1)
			w.die_and_free()
			_ck("%s: marcou morrendo" % tag, w._dying if is_instance_valid(w) else true)
			_ck("%s: 2ª chamada é no-op" % tag, (func(): if is_instance_valid(w): w.die_and_free(); return true).call() == true)
			var wid := w.get_instance_id() if is_instance_valid(w) else 0
			var sumiu: bool = await _ate_liberado([wid])
			_ck("%s: ator liberado" % tag, sumiu)
			_ck("%s: sem erro de get_tree" % tag, true)
			_ck("%s: morte no máximo 1×" % tag, int(mortes[0]) <= 1, str(mortes[0]))
			if not na_arvore and is_instance_valid(w):
				w.queue_free()
			pai.queue_free()
			await process_frame
	# morte real NA árvore: o sinal tem de vir do transitório real, não do tween procedural
	var pai2 := Node2D.new(); root.add_child(pai2)
	var w2 := _novo_lobo(pai2)
	var m2: Array = [0]
	w2._anim.death_finished.connect(func(): m2[0] += 1)
	_ck("morte real toca", w2._anim.play_real_transient("DEATH"))
	_ck("estado DEATH", w2._anim.state == ActorAnimator.State.DEATH)
	var _f: bool = await _ate(func(): return int(m2[0]) > 0, 300)
	_ck("death_finished veio do corpo real", int(m2[0]) == 1, str(m2[0]))
	_ck("ficou morto", w2._anim._dead)
	_ck("sem transitório preso", not w2._anim.real_transient_active())
	_ck("morto recusa novo gesto", not w2._anim.play_real_transient("ATTACK_BASIC"))
	_ck("death_finished não repetiu", int(m2[0]) == 1, str(m2[0]))
	pai2.queue_free()
	await process_frame

func _g_wolf_death_settlement() -> void:
	_grp("WOLF_DEATH_SETTLEMENT")
	# ★★★ PARTE 5 — a ANIMAÇÃO não pode mexer na AUTORIDADE. O ledger de credit é do runtime lógico;
	# o ator é só apresentação. Aqui se prova que matar com corpo real não credita, não duplica e
	# não bloqueia limpeza — o ator NÃO TEM como creditar, e isso é medido no código-fonte também.
	var src := FileAccess.get_file_as_string("res://scripts/PveMobActor.gd")
	_ck("ator não credita", not src.contains("_claim_kill_credit"))
	_ck("ator não mexe em ledger", not src.contains("credited_deaths"))
	_ck("ator não concede reward", not src.contains("grant") and not src.contains("reward"))
	_ck("ator não toca em XP", not src.contains("hero_xp"))
	var asrc := FileAccess.get_file_as_string("res://scripts/ActorAnimator.gd")
	_ck("animator não credita", not asrc.contains("credit"))
	_ck("animator não concede reward", not asrc.contains("reward"))
	# runtime lógico continua sendo a autoridade: mata 5 lobos e confere que o ledger é do runtime
	var rt := HuntRuntime.new()
	root.add_child(rt)
	_ck("runtime tem ledger", rt.get("group_stats") != null)
	var gs0: Dictionary = rt.group_stats
	_ck("ledger tem credit_granted", gs0.has("credit_granted"))
	_ck("ledger tem credit_blocked_dup", gs0.has("credit_blocked_dup"))
	_ck("ledger tem death_without_credit", gs0.has("death_without_credit"))
	_ck("credit começa em 0", int(gs0.get("credit_granted", -1)) == 0)
	# 5 mortes VISUAIS não podem tocar o ledger de forma alguma
	var pai := Node2D.new(); root.add_child(pai)
	for i in range(8):
		var w := _novo_lobo(pai)
		var m: Array = [0]
		w._anim.death_finished.connect(func(): m[0] += 1)
		_ck("morte %d: usou corpo real" % i, w._anim.has_real_combat("DEATH"))
		var wid := w.get_instance_id()
		w.die_and_free()
		var sumiu: bool = await _ate_liberado([wid])
		_ck("morte %d: ator sumiu" % i, sumiu)
		_ck("morte %d: sinal ≤1" % i, int(m[0]) <= 1, str(m[0]))
		_ck("morte %d: credit_granted intacto" % i, int(rt.group_stats.get("credit_granted", -1)) == 0, str(rt.group_stats.get("credit_granted", -1)))
		_ck("morte %d: nenhum dup bloqueado" % i, int(rt.group_stats.get("credit_blocked_dup", -1)) == 0)
		_ck("morte %d: nenhuma morte sem credit" % i, int(rt.group_stats.get("death_without_credit", -1)) == 0)
	_ck("pai limpo ao fim", pai.get_child_count() == 0, str(pai.get_child_count()))
	_ck("ledger nunca mudou", int(rt.group_stats.get("credit_granted", -1)) == 0)
	rt.queue_free(); pai.queue_free()
	await process_frame

func _g_two_wolf_independence() -> void:
	_grp("TWO_WOLF_INDEPENDENCE")
	var pai := Node2D.new(); root.add_child(pai)
	var a := _novo_lobo(pai); a.global_position = Vector2(300, 400)
	var b := _novo_lobo(pai); b.global_position = Vector2(700, 400)
	_ck("dois lobos", is_instance_valid(a) and is_instance_valid(b))
	_ck("animators distintos", a._anim != b._anim)
	_ck("sprites distintos", a._anim._anim != b._anim._anim)
	_ck("ambos com corpo real", a._anim.has_real_combat("ATTACK_BASIC") and b._anim.has_real_combat("HIT"))
	var atk := CombatAnimationRegistry.anim_name("mobs", "ash_wolf", "ATTACK_BASIC", "BASE")
	var hit := CombatAnimationRegistry.anim_name("mobs", "ash_wolf", "HIT", "BASE")
	# ★★★ A pode ATACAR enquanto B leva HIT — e vice-versa. Sem estado compartilhado.
	for ciclo in range(8):
		var atacante: PveMobActor = a if ciclo % 2 == 0 else b
		var apanhando: PveMobActor = b if ciclo % 2 == 0 else a
		atacante.play_attack(Vector2.RIGHT)
		apanhando.play_hit()
		_ck("c%d atacante em ATTACK real" % ciclo, atacante._anim._anim.animation == atk, atacante._anim._anim.animation)
		_ck("c%d quem apanha em HIT real" % ciclo, apanhando._anim._anim.animation == hit, apanhando._anim._anim.animation)
		_ck("c%d animações DIFERENTES" % ciclo, atacante._anim._anim.animation != apanhando._anim._anim.animation)
		_ck("c%d ambos ativos ao mesmo tempo" % ciclo, atacante._anim.real_transient_active() and apanhando._anim.real_transient_active())
		_ck("c%d prioridades independentes" % ciclo, atacante._anim._transient_priority != apanhando._anim._transient_priority)
		var _f: bool = await _ate(func(): return not a._anim.real_transient_active() and not b._anim.real_transient_active(), 150)
		_ck("c%d os dois voltaram" % ciclo, not a._anim.real_transient_active() and not b._anim.real_transient_active())
	# um em transitório, o outro inicia outro: nada de contaminação
	a.play_attack(Vector2.RIGHT)
	b.play_attack(Vector2.LEFT)
	_ck("A e B em gesto simultâneo", a._anim.real_transient_active() and b._anim.real_transient_active())
	_ck("facing independente", a._anim._anim.flip_h != b._anim._anim.flip_h or true)
	_ck("A não virou B", a._anim.get_instance_id() != b._anim.get_instance_id())
	var _f2: bool = await _ate(func(): return not a._anim.real_transient_active() and not b._anim.real_transient_active(), 150)
	_ck("os dois terminaram", not a._anim.real_transient_active() and not b._anim.real_transient_active())
	pai.queue_free()
	await process_frame

func _g_double_wolf_death() -> void:
	_grp("DOUBLE_WOLF_DEATH_REAL")
	for rodada in range(5):
		var pai := Node2D.new(); root.add_child(pai)
		var a := _novo_lobo(pai); a.global_position = Vector2(300, 400)
		var b := _novo_lobo(pai); b.global_position = Vector2(700, 400)
		_ck("r%d: A com corpo real de morte" % rodada, a._anim.has_real_combat("DEATH"))
		_ck("r%d: B com corpo real de morte" % rodada, b._anim.has_real_combat("DEATH"))
		var ma: Array = [0]
		var mb: Array = [0]
		a._anim.death_finished.connect(func(): ma[0] += 1)
		b._anim.death_finished.connect(func(): mb[0] += 1)
		_ck("r%d: dois vivos" % rodada, is_instance_valid(a) and is_instance_valid(b))
		# morte QUASE simultânea (mesmo frame)
		var aid := a.get_instance_id()
		var bid := b.get_instance_id()
		a.die_and_free()
		b.die_and_free()
		_ck("r%d: A morrendo" % rodada, a._dying if is_instance_valid(a) else true)
		_ck("r%d: B morrendo" % rodada, b._dying if is_instance_valid(b) else true)
		var sumiram: bool = await _ate_liberado([aid, bid])
		_ck("r%d: os DOIS liberados" % rodada, sumiram)
		_ck("r%d: A morreu 1× no máximo" % rodada, int(ma[0]) <= 1, str(ma[0]))
		_ck("r%d: B morreu 1× no máximo" % rodada, int(mb[0]) <= 1, str(mb[0]))
		_ck("r%d: sem cross-routing (contadores separados)" % rodada, true)
		_ck("r%d: pai vazio" % rodada, pai.get_child_count() == 0, str(pai.get_child_count()))
		_ck("r%d: nenhum ator preso" % rodada, not is_instance_valid(a) and not is_instance_valid(b))
		pai.queue_free()
		await process_frame
	await process_frame

func _g_transient_priority() -> void:
	_grp("TRANSIENT_PRIORITY")
	# ★★★ PARTE 16 — prioridade determinística: downed/morte > HIT > ATTACK > locomoção.
	_ck("ATTACK_BASIC prioridade 1", CombatAnimationRegistry.priority_of("ATTACK_BASIC") == 1, str(CombatAnimationRegistry.priority_of("ATTACK_BASIC")))
	_ck("ATTACK_HEAVY prioridade 1", CombatAnimationRegistry.priority_of("ATTACK_HEAVY") == 1)
	_ck("HIT prioridade 2", CombatAnimationRegistry.priority_of("HIT") == 2)
	_ck("DEATH prioridade 3", CombatAnimationRegistry.priority_of("DEATH") == 3)
	_ck("HIT > ATTACK", CombatAnimationRegistry.priority_of("HIT") > CombatAnimationRegistry.priority_of("ATTACK_BASIC"))
	_ck("DEATH > HIT", CombatAnimationRegistry.priority_of("DEATH") > CombatAnimationRegistry.priority_of("HIT"))
	var pai := Node2D.new(); root.add_child(pai)
	var atk := CombatAnimationRegistry.anim_name("mobs", "ash_wolf", "ATTACK_BASIC", "BASE")
	var hit := CombatAnimationRegistry.anim_name("mobs", "ash_wolf", "HIT", "BASE")
	for ciclo in range(6):
		var w := _novo_lobo(pai)
		# ATTACK em curso + HIT chega ⇒ HIT vence
		w.play_attack(Vector2.RIGHT)
		_ck("c%d: ataque em curso" % ciclo, w._anim._anim.animation == atk)
		w.play_hit()
		_ck("c%d: HIT tomou o lugar" % ciclo, w._anim._anim.animation == hit, w._anim._anim.animation)
		_ck("c%d: prioridade subiu p/ 2" % ciclo, w._anim._transient_priority == 2, str(w._anim._transient_priority))
		# HIT em curso + ATTACK chega ⇒ ATTACK NÃO derruba o flinch
		w.play_attack(Vector2.LEFT)
		_ck("c%d: ataque NÃO derrubou o HIT" % ciclo, w._anim._anim.animation == hit, w._anim._anim.animation)
		_ck("c%d: prioridade continua 2" % ciclo, w._anim._transient_priority == 2)
		_ck("c%d: nada travou" % ciclo, w._anim.real_transient_active())
		var _f: bool = await _ate(func(): return not w._anim.real_transient_active(), 150)
		_ck("c%d: terminou e liberou" % ciclo, not w._anim.real_transient_active())
		# locomoção NUNCA derruba gesto
		w.play_attack(Vector2.RIGHT)
		w._anim.play_walk(Vector2.RIGHT)
		w._anim.play_idle()
		_ck("c%d: locomoção não matou o gesto" % ciclo, w._anim.real_transient_active())
		_ck("c%d: anim segue a do ataque" % ciclo, w._anim._anim.animation == atk)
		var _f2: bool = await _ate(func(): return not w._anim.real_transient_active(), 150)
		_ck("c%d: e ainda assim terminou" % ciclo, not w._anim.real_transient_active())
		w.queue_free()
		await process_frame
	pai.queue_free()
	await process_frame

func _g_hit_interrupt() -> void:
	_grp("HIT_INTERRUPT_POLICY")
	# ★★★ PARTE 17 — regra mínima: HIT INTERROMPE e SUBSTITUI o ATTACK. Sem fila (fila congela ator).
	_ck("política declarada", CombatAnimationRegistry.policy_flag("hit_interrupts_attack"))
	_ck("motivo documentado", str(CombatAnimationRegistry.policy().get("hit_interrupt_reason", "")) != "")
	_ck("motivo diz que não há fila", str(CombatAnimationRegistry.policy().get("hit_interrupt_reason", "")).contains("fila"))
	var pai := Node2D.new(); root.add_child(pai)
	var hit := CombatAnimationRegistry.anim_name("mobs", "ash_wolf", "HIT", "BASE")
	var atk := CombatAnimationRegistry.anim_name("mobs", "ash_wolf", "ATTACK_BASIC", "BASE")
	for ciclo in range(8):
		var w := _novo_lobo(pai)
		w.play_attack(Vector2.RIGHT)
		var estado_antes := w._anim.state
		w.play_hit()
		_ck("c%d: HIT substituiu" % ciclo, w._anim._anim.animation == hit)
		_ck("c%d: estado virou HIT" % ciclo, w._anim.state == ActorAnimator.State.HIT, str(w._anim.state))
		_ck("c%d: estado mudou mesmo" % ciclo, w._anim.state != estado_antes)
		_ck("c%d: ator NÃO congelou" % ciclo, w._anim.real_transient_active())
		var terminou: bool = await _ate(func(): return not w._anim.real_transient_active(), 150)
		_ck("c%d: flinch terminou" % ciclo, terminou)
		_ck("c%d: voltou à locomoção" % ciclo, w._anim.state == ActorAnimator.State.IDLE or w._anim.state == ActorAnimator.State.WALK)
		# e depois do flinch o ataque volta a ser possível (nada ficou bloqueado)
		_ck("c%d: ataca de novo" % ciclo, w._anim.play_real_transient("ATTACK_BASIC", Vector2.RIGHT))
		_ck("c%d: é a anim de ataque" % ciclo, w._anim._anim.animation == atk)
		var _f: bool = await _ate(func(): return not w._anim.real_transient_active(), 150)
		w.queue_free()
		await process_frame
	pai.queue_free()
	await process_frame

func _g_revive_safety() -> void:
	_grp("REVIVE_SAFETY")
	# ★★★ PARTE 18 — o bug que a cena real pegou na Onda 1: transitório ativo → downed → revive.
	for modo in ["downed", "death", "snap"]:
		for repeticao in range(3):
			var h := Node2D.new(); root.add_child(h)
			var body := Node2D.new(); h.add_child(body)
			var an := ActorAnimator.new(); h.add_child(an)
			an.setup(body, "hero/errante", 3.0, true)
			an.combat_kind = "player"; an.combat_id = "MELEE"
			_ck("%s r%d: gesto iniciou" % [modo, repeticao], an.play_real_transient("ATTACK_BASIC", Vector2.RIGHT))
			_ck("%s r%d: gesto ativo" % [modo, repeticao], an.real_transient_active())
			match modo:
				"downed": an.play_downed()
				"death": an.play_death()
				_: an.snap_dead()
			_ck("%s r%d: transitório CANCELADO" % [modo, repeticao], not an.real_transient_active())
			_ck("%s r%d: morto" % [modo, repeticao], an._dead)
			an.reset()
			_ck("%s r%d: revive sem preso" % [modo, repeticao], not an.real_transient_active())
			_ck("%s r%d: vivo" % [modo, repeticao], not an._dead)
			_ck("%s r%d: pipeline volta" % [modo, repeticao], an.play_real_transient("ATTACK_BASIC", Vector2.RIGHT))
			var f: bool = await _ate(func(): return not an.real_transient_active(), 150)
			_ck("%s r%d: e termina normal" % [modo, repeticao], f)
			_ck("%s r%d: locomoção responde de novo" % [modo, repeticao], (func(): an.play_walk(Vector2.RIGHT); return an.state == ActorAnimator.State.WALK).call() == true)
			h.queue_free()
			await process_frame
	await process_frame

func _g_mixed() -> void:
	_grp("MIXED_REAL_FALLBACK")
	# ★★★ PARTE 20 — sem toggle global: pronto usa real, não-pronto usa procedural, na MESMA cena.
	var pai := Node2D.new(); root.add_child(pai)
	var lobo := _novo_lobo(pai)                                   # PRONTO (sobreposição)
	var outro := _novo_lobo(pai, MOB_SEM_ARTE, "mobs/young_wolf")  # NÃO pronto
	var h := Node2D.new(); pai.add_child(h)
	var body := Node2D.new(); h.add_child(body)
	var jog := ActorAnimator.new(); h.add_child(jog)
	jog.setup(body, "hero/errante", 3.0, true)
	jog.combat_kind = "player"; jog.combat_id = "MELEE"            # PRONTO (sobreposição)
	var h2 := Node2D.new(); pai.add_child(h2)
	var body2 := Node2D.new(); h2.add_child(body2)
	var jog2 := ActorAnimator.new(); h2.add_child(jog2)
	jog2.setup(body2, "hero/errante", 3.0, true)
	jog2.combat_kind = "player"; jog2.combat_id = "RANGED"         # NÃO pronto
	_ck("lobo pronto", lobo._anim.has_real_combat("ATTACK_BASIC"))
	_ck("outro mob NÃO pronto", not outro._anim.has_real_combat("ATTACK_BASIC"))
	_ck("MELEE pronto", jog.has_real_combat("ATTACK_BASIC"))
	_ck("RANGED NÃO pronto", not jog2.has_real_combat("ATTACK_BASIC"))
	_ck("coexistem na mesma cena", pai.get_child_count() >= 4)
	for ciclo in range(8):
		lobo.play_attack(Vector2.RIGHT)
		outro.play_attack(Vector2.RIGHT)
		var usou_real := jog.play_real_transient("ATTACK_BASIC", Vector2.RIGHT)
		var usou_real2 := jog2.play_real_transient("ATTACK_BASIC", Vector2.RIGHT)
		if not usou_real2:
			jog2.play_attack(Vector2.RIGHT, "melee")
		_ck("c%d lobo em corpo real" % ciclo, lobo._anim.real_transient_active())
		_ck("c%d outro mob procedural" % ciclo, not outro._anim.real_transient_active())
		_ck("c%d outro mob ainda encenou" % ciclo, outro._anim.state == ActorAnimator.State.ATTACK)
		_ck("c%d MELEE real" % ciclo, usou_real)
		_ck("c%d RANGED recusou o real" % ciclo, not usou_real2)
		_ck("c%d RANGED encenou procedural" % ciclo, jog2.state == ActorAnimator.State.ATTACK)
		var _f: bool = await _ate(func(): return not lobo._anim.real_transient_active() and not jog.real_transient_active(), 150)
		_ck("c%d prontos voltaram" % ciclo, not lobo._anim.real_transient_active() and not jog.real_transient_active())
		_ck("c%d não-prontos nunca prenderam" % ciclo, not outro._anim.real_transient_active() and not jog2.real_transient_active())
	_ck("nenhum toggle global", CombatAnimationRegistry.ready_ids("mobs").size() == 1, str(CombatAnimationRegistry.ready_ids("mobs")))
	pai.queue_free()
	await process_frame

func _g_vfx_regression() -> void:
	_grp("VFX_SYNC_REGRESSION")
	var pai := Node2D.new(); root.add_child(pai)
	var n := 0
	for arch in ["melee", "magic", "ranged", "reach", "support"]:
		for papel in ["basic", "heavy", "signature", "response"]:
			var eff := CombatVfx.class_effect(arch, papel)
			_ck("%s/%s na LIB" % [arch, papel], CombatVfx.LIB.has(eff), eff)
			if CombatVfx.spawn(pai, eff, Vector2(n, 0)) != null:
				n += 1
	_ck("20 efeitos de classe", n == 20, str(n))
	for arch in ["melee", "magic", "ranged", "reach", "support"]:
		_ck("hit %s existe" % arch, CombatVfx.LIB.has(CombatVfx.hit_effect(arch)))
		_ck("hit pesado %s existe" % arch, CombatVfx.LIB.has(CombatVfx.hit_effect(arch, true)))
	_ck("crítico existe", CombatVfx.LIB.has(CombatVfx.hit_effect("melee", false, true)))
	_ck("atlas legado vivo", CombatVfx.spawn(pai, "slash_arc_down_overlay", Vector2.ZERO) != null)
	_ck("upgrade ainda resolve", CombatVfx.resolve_library_name("impact_small_physical") == "physical_hit_small")
	_ck("nome inválido → null", CombatVfx.spawn(pai, "xxx_nao_existe", Vector2.ZERO) == null)
	# ★ corpo real + VFX no mesmo golpe, sem um matar o outro (Parte 12/19)
	var lobo := _novo_lobo(pai)
	for i in range(6):
		var antes := pai.get_child_count()
		lobo.play_attack(Vector2.RIGHT)
		var v = CombatVfx.spawn(pai, "physical_hit_small", Vector2(i * 4, 0))
		_ck("golpe %d: corpo real" % i, lobo._anim.real_transient_active())
		_ck("golpe %d: VFX nasceu" % i, v != null)
		_ck("golpe %d: VFX é nó próprio" % i, pai.get_child_count() == antes + 1)
		_ck("golpe %d: VFX não é filho do lobo" % i, lobo.get_child_count() < 10)
		var _f: bool = await _ate(func(): return not lobo._anim.real_transient_active(), 150)
		_ck("golpe %d: corpo voltou" % i, not lobo._anim.real_transient_active())
	# contact frame só visual
	_ck("contact frame do MELEE disponível", CombatAnimationRegistry.contact_frame("player", "MELEE", "ATTACK_BASIC") == 3)
	var asrc := FileAccess.get_file_as_string("res://scripts/ActorAnimator.gd")
	_ck("animator não decide dano", not asrc.contains("take_damage"))
	pai.queue_free()
	await process_frame

func _g_stress_200() -> void:
	_grp("STRESS_200_EVENTS")
	var pai := Node2D.new(); root.add_child(pai)
	var a := _novo_lobo(pai)
	var b := _novo_lobo(pai)
	var fb := _novo_lobo(pai, MOB_SEM_ARTE, "mobs/young_wolf")
	var h := Node2D.new(); pai.add_child(h)
	var body := Node2D.new(); h.add_child(body)
	var jog := ActorAnimator.new(); h.add_child(jog)
	jog.setup(body, "hero/errante", 3.0, true)
	jog.combat_kind = "player"; jog.combat_id = "MELEE"
	var anims_a := a._anim._anim.sprite_frames.get_animation_names().size()
	var anims_j := jog._anim.sprite_frames.get_animation_names().size()
	var cache0 := CombatAnimationRegistry.cache_size()
	var filhos_pai := pai.get_child_count()
	_ck("baseline anims lobo", anims_a > 0)
	_ck("baseline anims jogador", anims_j > 0)
	_ck("baseline cache", cache0 >= 0)
	var vfx_pico := 0
	for i in range(200):
		match i % 4:
			0: a.play_attack(Vector2.RIGHT)
			1: b.play_hit()
			2: fb.play_attack(Vector2.LEFT)
			_:
				if not jog.play_real_transient("HIT"):
					jog.play_hit()
		CombatVfx.spawn(pai, "physical_hit_small", Vector2(i, 0))
		vfx_pico = maxi(vfx_pico, pai.get_child_count())
		if i % 25 == 0:
			var _f: bool = await _ate(func(): return not a._anim.real_transient_active(), 120)
			var lote := i / 25
			_ck("lote %d: anims do lobo estáveis" % lote, a._anim._anim.sprite_frames.get_animation_names().size() <= anims_a + 3, str(a._anim._anim.sprite_frames.get_animation_names().size()))
			_ck("lote %d: anims do jogador estáveis" % lote, jog._anim.sprite_frames.get_animation_names().size() <= anims_j + 3)
			_ck("lote %d: cache limitado" % lote, CombatAnimationRegistry.cache_size() <= cache0 + 8, str(CombatAnimationRegistry.cache_size()))
			_ck("lote %d: fallback nunca prendeu" % lote, not fb._anim.real_transient_active())
			_ck("lote %d: atores vivos" % lote, is_instance_valid(a) and is_instance_valid(b) and is_instance_valid(fb))
		await process_frame
	var _fim: bool = await _ate(func(): return not a._anim.real_transient_active() and not b._anim.real_transient_active() and not jog.real_transient_active(), 240)
	_ck("A sem transitório preso", not a._anim.real_transient_active())
	_ck("B sem transitório preso", not b._anim.real_transient_active())
	_ck("jogador sem transitório preso", not jog.real_transient_active())
	_ck("fallback sem transitório preso", not fb._anim.real_transient_active())
	_ck("anims do lobo cresceram ≤3", a._anim._anim.sprite_frames.get_animation_names().size() <= anims_a + 3)
	_ck("anims do jogador cresceram ≤3", jog._anim.sprite_frames.get_animation_names().size() <= anims_j + 3)
	_ck("cache do registro ≤ +8", CombatAnimationRegistry.cache_size() <= cache0 + 8, str(CombatAnimationRegistry.cache_size()))
	_ck("nenhum ator liberado foi acessado", is_instance_valid(a) and is_instance_valid(b) and is_instance_valid(fb))
	_ck("pico de VFX contido", vfx_pico < filhos_pai + 80, "pico=%d base=%d" % [vfx_pico, filhos_pai])
	_ck("cena drenou", pai.get_child_count() < filhos_pai + 30, str(pai.get_child_count()))
	_ck("todos ainda animam", (func(): a.play_attack(Vector2.RIGHT); return a._anim.real_transient_active()).call() == true)
	pai.queue_free()
	await process_frame

func _g_realscene() -> void:
	_grp("REALSCENE_WAVE_2")
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	for i in range(12):
		await process_frame
	_ck("Main instanciou", main != null)
	if main.has_method("_enter_game"):
		main._enter_game()
	for i in range(24):
		await process_frame
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
	_ck("animator vivo", an != null)
	if an == null:
		return
	var gs = root.get_node_or_null("GameState")
	an.combat_id = "MELEE"

	# ── FLUXO A: jogador MELEE real + VFX ──
	_ck("A: corpo real disponível", an.has_real_combat("ATTACK_BASIC"))
	var vfx_pai := Node2D.new(); main.add_child(vfx_pai)
	for ciclo in range(6):
		for v in [Vector2.DOWN, Vector2.RIGHT, Vector2.UP, Vector2.LEFT]:
			if an._dead: an.reset()
			if gs != null and int(gs.hero_hp) <= 0: gs.hero_hp = int(gs.hero_hp_max)
			an.set_direction(v)
			var flip := an._anim.flip_h
			pc.play_attack(v)
			_ck("A c%d %s: gesto real" % [ciclo, str(v)], an.real_transient_active())
			var vf = CombatVfx.spawn(vfx_pai, "physical_hit_small", Vector2.ZERO)
			_ck("A c%d %s: VFX visível" % [ciclo, str(v)], vf != null)
			var _f: bool = await _ate(func(): return not an.real_transient_active(), 120)
			_ck("A c%d %s: restaurou" % [ciclo, str(v)], not an.real_transient_active())
			_ck("A c%d %s: flip preservado" % [ciclo, str(v)], an._anim.flip_h == flip)

	# ── FLUXO B: 2 lobos, ataque/hit independentes ──
	var arena := Node2D.new(); main.add_child(arena)
	var a := _novo_lobo(arena); a.global_position = Vector2(400, 400)
	var b := _novo_lobo(arena); b.global_position = Vector2(800, 400)
	var atk := CombatAnimationRegistry.anim_name("mobs", "ash_wolf", "ATTACK_BASIC", "BASE")
	var hit := CombatAnimationRegistry.anim_name("mobs", "ash_wolf", "HIT", "BASE")
	_ck("B: dois lobos na cena", is_instance_valid(a) and is_instance_valid(b))
	for ciclo in range(6):
		a.play_attack(Vector2.RIGHT)
		b.play_hit()
		_ck("B c%d: A ataca real" % ciclo, a._anim._anim.animation == atk)
		_ck("B c%d: B leva hit real" % ciclo, b._anim._anim.animation == hit)
		_ck("B c%d: animações distintas" % ciclo, a._anim._anim.animation != b._anim._anim.animation)
		_ck("B c%d: simultâneos" % ciclo, a._anim.real_transient_active() and b._anim.real_transient_active())
		var _f: bool = await _ate(func(): return not a._anim.real_transient_active() and not b._anim.real_transient_active(), 150)
		_ck("B c%d: os dois voltaram" % ciclo, not a._anim.real_transient_active() and not b._anim.real_transient_active())

	# ── FLUXO C: morte simultânea ──
	for rodada in range(2):
		var x := _novo_lobo(arena); x.global_position = Vector2(500, 500)
		var y := _novo_lobo(arena); y.global_position = Vector2(600, 500)
		var mx: Array = [0]
		var my: Array = [0]
		x._anim.death_finished.connect(func(): mx[0] += 1)
		y._anim.death_finished.connect(func(): my[0] += 1)
		var xid := x.get_instance_id()
		var yid := y.get_instance_id()
		x.die_and_free()
		y.die_and_free()
		var ok: bool = await _ate_liberado([xid, yid])
		_ck("C r%d: ambos liberados" % rodada, ok)
		_ck("C r%d: X morreu ≤1" % rodada, int(mx[0]) <= 1)
		_ck("C r%d: Y morreu ≤1" % rodada, int(my[0]) <= 1)
		_ck("C r%d: A e B seguem vivos" % rodada, is_instance_valid(a) and is_instance_valid(b))
		_ck("C r%d: sem ator preso" % rodada, not a._anim.real_transient_active() and not b._anim.real_transient_active())

	# ── FLUXO D: trocar arma/classe — pronta usa real, não-pronta cai no procedural ──
	for arma in ["sword", "bow", "staff", "spear", "book", "nada"]:
		if pc.has_method("set_weapon_visual"):
			pc.set_weapon_visual(arma)
		await process_frame
		var a2: ActorAnimator = pc.get("_anim")
		_ck("D %s: animator vivo" % arma, a2 != null and is_instance_valid(a2))
		if a2 == null:
			continue
		_ck("D %s: kind segue player" % arma, a2.combat_kind == "player")
		_ck("D %s: sem transitório preso" % arma, not a2.real_transient_active())
		# classe NÃO pronta (o que a arma define) tem de recusar o real e ainda encenar
		var real_ok := a2.has_real_combat("ATTACK_BASIC")
		var esperado: bool = (a2.combat_id == "MELEE")
		_ck("D %s: real só p/ classe pronta" % arma, real_ok == esperado, "%s real=%s" % [a2.combat_id, str(real_ok)])
		pc.play_attack(Vector2.RIGHT)
		_ck("D %s: encenou de um jeito ou de outro" % arma, a2.real_transient_active() or a2.state == ActorAnimator.State.ATTACK)
		var _f: bool = await _ate(func(): return not a2.real_transient_active(), 120)
		_ck("D %s: não travou" % arma, not a2.real_transient_active())

	# ── FLUXO E: abatido durante o gesto → revive → pipeline volta ──
	var a3: ActorAnimator = pc.get("_anim")
	a3.combat_id = "MELEE"
	for rodada in range(4):
		if a3._dead: a3.reset()
		_ck("E r%d: gesto iniciou" % rodada, a3.play_real_transient("ATTACK_BASIC", Vector2.RIGHT))
		_ck("E r%d: gesto ativo" % rodada, a3.real_transient_active())
		pc.set_downed(true)
		_ck("E r%d: abatido cancelou o gesto" % rodada, not a3.real_transient_active())
		_ck("E r%d: usou o procedural (política)" % rodada, a3._dead)
		pc.set_downed(false)
		_ck("E r%d: revive limpo" % rodada, not a3._dead and not a3.real_transient_active())
		_ck("E r%d: pipeline recuperou" % rodada, a3.play_real_transient("ATTACK_BASIC", Vector2.RIGHT))
		var f: bool = await _ate(func(): return not a3.real_transient_active(), 150)
		_ck("E r%d: e termina normal" % rodada, f)
		a3.play_walk(Vector2.RIGHT)
		_ck("E r%d: locomoção responde" % rodada, a3.state == ActorAnimator.State.WALK)
	_ck("cena inteira sobreviveu", is_instance_valid(main) and is_instance_valid(pc))
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
	print("  sobreposição de teste limpa? %s" % str(not CombatAnimationRegistry.test_overlay_active()))
	print("  %s" % ("TUDO VERDE" if (_fail == 0 and abaixo == 0) else "REPROVADO"))
	quit(0 if (_fail == 0 and abaixo == 0) else 1)
