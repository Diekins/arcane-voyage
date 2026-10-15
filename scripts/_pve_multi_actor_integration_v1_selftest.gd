extends SceneTree
## PVE MULTI-ACTOR INTEGRATION V1 — Fase 21.
## ★★★ Diferença para `_pve_group_activation_v1`: aqui NÃO há stub. Monta HuntHost + HuntRuntime +
## PveMobActor REAIS e prova que 2 mobs lógicos viram 2 atores VISÍVEIS e independentes.
## É o portão que faltava antes de ligar `EARLY NORMAL 2–3` em produção.
##
## ⛔ REGRA DE ESPERA: nada de "roda N frames e mede". Espera por CONDIÇÃO com deadline.
## (lição de _a161/_a162/_a19b/_a22 — teste que conta frames fica preso à cadência)

var h: TestHarness = null
var gs
var _nodes: Array = []
var _mem: Dictionary = {}

func _initialize() -> void:
	h = TestHarness.new()
	print("═══════════ PVE MULTI-ACTOR INTEGRATION V1 — SELF-TEST ═══════════")
	gs = root.get_node_or_null("GameState")
	gs.set_save_path_override("user://pve_multiactor_fixture.json")
	_mem = gs.to_dict().duplicate(true)
	gs.verbose_combat_log = false
	_g_two_real()
	_g_independent_hp()
	_g_cross_feedback()
	_g_reconciliation_stability()
	_g_exit_two_alive()
	_g_three_real()
	_g_initial_fill_production()
	_finish()

# ── fixture REAL (mesmo padrão do _a22) ────────────────────────────────────────
func _hh() -> HuntHost:
	var host := HuntHost.new(); root.add_child(host); _nodes.append(host)
	var ms := Node.new()
	var pl = Node2D.new(); pl.set_script(load("res://scripts/_a19b_fakeplayer.gd"))
	root.add_child(pl); _nodes.append(pl)
	host.setup(ms, pl, null, gs)
	return host

## Inicia a caça e sobe o cap. Devolve o host pronto (ou null se o start recusar).
func _start(cap: int) -> HuntHost:
	gs.reset_save(); gs.set_save_path_override("user://pve_multiactor_fixture.json")
	# ★★★ HERÓI DELIBERADAMENTE FRACO na fixture. Sem isso o TTK fica MENOR que o RESPAWN_DELAY
	# (1.6 s) e a população oscila em 1: o lobo morre antes de o segundo nascer, e `active_count()`
	# nunca chega a 2. Não é balance — é a condição necessária para OBSERVAR o grupo montado.
	# ⛔ Fixture isolada (`pve_multiactor_fixture.json`); o save real é restaurado no `_finish`.
	gs.equipment = {}          # sem arma ⇒ dano mínimo ⇒ TTK longo
	gs.slot_refinement = {}
	gs.hero_hp_max = 400000; gs.reset_hero_hp()   # HP alto: o teste é de GRUPO, não de sobrevivência
	var host := _hh()
	var r: Dictionary = host.start("HG_PLAINS_LOW", "young_wolf", "NORMAL")
	if not bool(r.get("ok", false)): return null
	host._runtime.set_max_active(cap)
	return host

## ★★★ ESPERA POR CONDIÇÃO, com deadline em tempo simulado. Devolve se a condição foi satisfeita.
func _until(host: HuntHost, cond: Callable, budget_s := 40.0, step := 0.2) -> bool:
	var t := 0.0
	while t < budget_s:
		if cond.call(): return true
		host.host_process(step)
		t += step
	return cond.call()

## ★★★ POPULA o grupo até `n` membros pelo CAMINHO REAL (spawn do runtime + reconciliação do host),
## com o COMBATE DESLIGADO.
## Por que desligar: o TTK do lobo é MENOR que o RESPAWN_DELAY (1.6 s) — o herói mata o primeiro
## antes de o segundo nascer e `active_count()` nunca chega a 2 (medido: 104 spawns, 0 grupos).
## Isso é BALANCE, e balance não é o que esta suíte prova. Aqui o alvo é o REGISTRO DE ATORES:
## instance→ator, pockets distintos, HP independente, roteamento. `_spawn_mob` e `_sync_mob_actor`
## continuam sendo os de produção — nada é simulado.
func _fill(host: HuntHost, n: int, budget_s := 60.0, step := 0.2) -> bool:
	var t := 0.0
	while t < budget_s and host._runtime.active_count() < n:
		host._runtime.combat_enabled = false   # só POPULAR: sem troca de golpes
		host._runtime.tick(step)
		host._sync_mob_actor(step)             # reconciliação REAL do host
		t += step
	host._sync_mob_actor(step)                 # garante atores criados p/ todos os membros
	return host._runtime.active_count() >= n

func _live(host: HuntHost) -> Array:
	return host._runtime.active_mobs()

# ══════════════ REAL_HOST_RUNTIME_TWO + VISIBLE + POCKETS ══════════════
func _g_two_real() -> void:
	h.group_begin("REAL_HOST_RUNTIME_TWO", 18)
	var host := _start(2)
	h.check("start da Hunt OK (componentes reais)", host != null)
	if host == null: h.group_complete(); return
	h.check("cap aplicado = 2", host._runtime.max_active() == 2)
	var got := _fill(host, 2)
	h.check("★ 2 mobs LÓGICOS vivos (esperado por condição)", got and host._runtime.active_count() == 2)
	var mobs := _live(host)
	if mobs.size() < 2: h.group_complete(); return
	var a = mobs[0]; var b = mobs[1]
	h.check("★ instance_id distintos", int(a.instance_id) != int(b.instance_id))
	h.check("mesma definição de mob", str(a.mob_id) == str(b.mob_id))
	# ── ATORES VISÍVEIS (21C) ──
	var acts: Array = host.mob_actors()
	h.check("★ 2 ATORES no registro", acts.size() == 2)
	h.check("host.active_mob_count() = 2", host.active_mob_count() == 2)
	var actA: PveMobActor = host._actor_for_instance(int(a.instance_id))
	var actB: PveMobActor = host._actor_for_instance(int(b.instance_id))
	h.check("★ ator de A existe", actA != null)
	h.check("★ ator de B existe", actB != null)
	if actA == null or actB == null: h.group_complete(); return
	h.check("★ atores DIFERENTES (sem compartilhar)", actA != actB)
	# ⚠️ na fixture o `_main` é um Node solto, então o `_actors_root` pende do HOST (não da cena).
	# O que importa aqui é a PARENTAGEM CORRETA, não estar na SceneTree do jogo.
	h.check("ator A parenteado no actors_root", is_instance_valid(actA) and actA.get_parent() == host._actors_root)
	h.check("ator B parenteado no actors_root", is_instance_valid(actB) and actB.get_parent() == host._actors_root)
	h.check("ator A visível", actA.visible)
	h.check("ator B visível", actB.visible)
	h.check("mesmo pai (actors_root)", actA.get_parent() == actB.get_parent())
	# ── POCKETS DISTINTOS (21D) ──
	var pA := int(host._pocket_by_instance.get(int(a.instance_id), -1))
	var pB := int(host._pocket_by_instance.get(int(b.instance_id), -1))
	h.check("★ pockets DIFERENTES", pA >= 0 and pB >= 0 and pA != pB)
	h.check("★ posições de mundo DIFERENTES (não empilham)", actA.global_position != actB.global_position)
	h.check("registro não vazou (2 entradas)", host._mob_actors_by_instance.size() == 2)
	h.group_complete()

# ══════════════ INDEPENDENT_HP (21E) ══════════════
func _g_independent_hp() -> void:
	h.group_begin("INDEPENDENT_HP", 8)
	var host := _start(2)
	if host == null: h.check("start falhou", false); h.group_complete(); return
	var ok := _fill(host, 2)
	h.check("2 membros vivos", ok)
	var mobs := _live(host)
	if mobs.size() < 2: h.group_complete(); return
	var a = mobs[0]; var b = mobs[1]
	var hpA0 := int(a.hp); var hpB0 := int(b.hp)
	h.check("HP inicial de A > 0", hpA0 > 0)
	h.check("HP inicial de B > 0", hpB0 > 0)
	# ★ dano SÓ em B
	# ★ o dano exige o DONO correto (§19 ownership de spot): `take_damage(amount, character)`.
	# Passar "char" era rejeitado em silêncio — defeito do teste, não do runtime.
	b.take_damage(5, host._runtime.character)
	h.check("★ HP de B CAIU", int(b.hp) < hpB0)
	h.check("★ HP de A INALTERADO (estado não é compartilhado)", int(a.hp) == hpA0)
	# dano só em A
	var hpB1 := int(b.hp)
	a.take_damage(5, host._runtime.character)
	h.check("★ HP de A caiu", int(a.hp) < hpA0)
	h.check("★ HP de B inalterado pelo dano em A", int(b.hp) == hpB1)
	h.check("os dois seguem vivos", a.alive() and b.alive())
	h.group_complete()

# ══════════════ CROSS_FEEDBACK_TARGET (21F) + ATTACK_SOURCE (21G) ══════════════
func _g_cross_feedback() -> void:
	h.group_begin("CROSS_FEEDBACK_TARGET", 10)
	var host := _start(2)
	if host == null: h.check("start falhou", false); h.group_complete(); return
	var ok := _fill(host, 2)
	h.check("2 membros vivos", ok)
	var mobs := _live(host)
	if mobs.size() < 2: h.group_complete(); return
	var prim = host._runtime.primary_mob()
	var other = mobs[0] if mobs[0] != prim else mobs[1]
	h.check("primário definido", prim != null)
	h.check("★ existe um SECUNDÁRIO distinto do primário", other != null and other != prim)
	var actPrim: PveMobActor = host._actor_for_instance(int(prim.instance_id))
	var actOther: PveMobActor = host._actor_for_instance(int(other.instance_id))
	h.check("ator do primário resolvido", actPrim != null)
	h.check("ator do secundário resolvido", actOther != null)
	h.check("★ mob_actor() (API legada) = ator do PRIMÁRIO", host.mob_actor() == actPrim)
	# ★★★ O TESTE QUE IMPORTA: evento de hit no SECUNDÁRIO resolve para o ator do SECUNDÁRIO
	h.check("★★★ hit em B roteia p/ o ator de B, NÃO p/ o primário",
		host._actor_for_instance(int(other.instance_id)) == actOther and actOther != actPrim)
	# feedback tardio de instância inexistente: descarta e conta
	var drop0 := int(host.host_group_stats["late_feedback_dropped"])
	host._on_combat_feedback("hit", {"amount": 9, "instance_id": 999999, "mob_id": "young_wolf"})
	h.check("★ feedback de instância morta é DESCARTADO (não vai p/ o primário)",
		int(host.host_group_stats["late_feedback_dropped"]) == drop0 + 1)
	# ataque do mob: só o atacante encena (roteado por instance_id)
	host._on_combat_feedback("mob_attack", {"amount": 3, "instance_id": int(other.instance_id), "mob_id": "young_wolf"})
	h.check("★ mob_attack do secundário não quebra nem cria ator", host._mob_actors_by_instance.size() == 2)
	h.check("registro segue com 2 atores", host.mob_actors().size() == 2)
	h.group_complete()

# ══════════════ RECONCILIATION_STABILITY (21N) ══════════════
func _g_reconciliation_stability() -> void:
	h.group_begin("RECONCILIATION_STABILITY", 8)
	var host := _start(2)
	if host == null: h.check("start falhou", false); h.group_complete(); return
	var ok := _fill(host, 2)
	h.check("2 membros vivos", ok)
	var mobs := _live(host)
	if mobs.size() < 2: h.group_complete(); return
	var ia := int(mobs[0].instance_id); var ib := int(mobs[1].instance_id)
	var a0 := host._actor_for_instance(ia); var b0 := host._actor_for_instance(ib)
	var pa0 := int(host._pocket_by_instance[ia]); var pb0 := int(host._pocket_by_instance[ib])
	var n0 := host._mob_actors_by_instance.size()
	# várias reconciliações seguidas
	for i in range(10): host._sync_mob_actor(0.05)
	h.check("★ MESMO ator para A (não recriou)", host._actor_for_instance(ia) == a0)
	h.check("★ MESMO ator para B (não recriou)", host._actor_for_instance(ib) == b0)
	h.check("★ pocket de A ESTÁVEL (não teleporta)", int(host._pocket_by_instance[ia]) == pa0)
	h.check("★ pocket de B ESTÁVEL", int(host._pocket_by_instance[ib]) == pb0)
	h.check("★ registro NÃO cresceu (sem churn)", host._mob_actors_by_instance.size() == n0)
	h.check("atores seguem válidos", is_instance_valid(a0) and is_instance_valid(b0))
	h.check("contagem segue 2", host.active_mob_count() == 2)
	h.group_complete()

# ══════════════ EXIT_TWO_ALIVE_REAL (21K) ══════════════
func _g_exit_two_alive() -> void:
	h.group_begin("EXIT_TWO_ALIVE_REAL", 10)
	var host := _start(2)
	if host == null: h.check("start falhou", false); h.group_complete(); return
	var ok := _fill(host, 2)
	h.check("2 membros vivos antes de SAIR", ok)
	var xp0 := int(gs.hero_xp); var gold0 := int(gs.hero_gold)
	h.check("2 atores antes de SAIR", host.mob_actors().size() == 2)
	host.stop()   # ← SAIR
	h.check("★ hunt encerrada", not host.is_hunting())
	h.check("★ registro de atores VAZIO", host._mob_actors_by_instance.is_empty())
	h.check("★ pockets limpos", host._pocket_by_instance.is_empty())
	h.check("★ mob_actors() vazio", host.mob_actors().is_empty())
	h.check("★ mob_actor() (compat) = null", host.mob_actor() == null)
	# ★ sem recompensa após a saída
	for i in range(20): host.host_process(0.3)
	h.check("★ XP não muda após SAIR", int(gs.hero_xp) == xp0)
	h.check("★ gold não muda após SAIR", int(gs.hero_gold) == gold0)
	h.check("★ nenhum ator ressurgiu", host.mob_actors().is_empty())
	h.group_complete()

# ══════════════ REAL_HOST_RUNTIME_THREE (21O) ══════════════
func _g_three_real() -> void:
	h.group_begin("REAL_HOST_RUNTIME_THREE", 10)
	var host := _start(3)
	if host == null: h.check("start falhou", false); h.group_complete(); return
	var ok := _fill(host, 3, 90.0)
	h.check("★ 3 mobs lógicos vivos", ok and host._runtime.active_count() == 3)
	var mobs := _live(host)
	if mobs.size() < 3: h.group_complete(); return
	h.check("★ 3 atores no registro", host.mob_actors().size() == 3)
	var ids := {}
	var pockets := {}
	var positions := []
	for m in mobs:
		ids[int(m.instance_id)] = true
		pockets[int(host._pocket_by_instance.get(int(m.instance_id), -1))] = true
		var act: PveMobActor = host._actor_for_instance(int(m.instance_id))
		if act != null: positions.append(act.global_position)
	h.check("★ 3 instance_id ÚNICOS", ids.size() == 3)
	h.check("★ 3 POCKETS distintos", pockets.size() == 3 and not pockets.has(-1))
	h.check("★ 3 posições de mundo distintas", positions.size() == 3 and positions[0] != positions[1] and positions[1] != positions[2] and positions[0] != positions[2])
	h.check("cap respeitado (não passou de 3)", host._runtime.active_count() <= 3)
	h.check("hard cap global intacto", HuntRuntime.GROUP_HARD_CAP == 6)
	# cadeia de promoção com atores REAIS
	var p0 = host._runtime.primary_mob()
	h.check("primário definido", p0 != null)
	host._runtime._unregister_member(p0)
	h.check("★ promoção real: primário mudou", host._runtime.primary_mob() != p0)
	h.check("★ primário novo é membro vivo", host._runtime.primary_mob() != null and host._runtime.primary_mob().alive())
	h.group_complete()

# ══════════════ INITIAL_FILL pelo CAMINHO DE PRODUÇÃO (sem desligar combate) ══════════════
## ★★★ Este é o grupo que faltava. Os anteriores populavam com `combat_enabled = false` (muleta
## para observar o registro). Aqui roda `host_process` DE VERDADE: se o grupo se formar, ele se
## forma em campo. Antes do INITIAL_FILL isto era impossível (104 spawns / 0 grupos).
func _g_initial_fill_production() -> void:
	h.group_begin("INITIAL_FILL_PRODUCTION", 14)
	for cap in [2, 3]:
		var host := _start(cap)
		if host == null:
			h.check("[cap %d] start OK" % cap, false); continue
		h.check("[cap %d] começa em INITIAL_FILL" % cap, host._runtime._in_initial_fill)
		# ⛔ SÓ host_process — nada de tocar no runtime por dentro
		var formed := false
		var t := 0.0
		while t < 60.0:
			host.host_process(0.2); t += 0.2
			if host._runtime.active_count() >= cap: formed = true; break
		h.check("★★★ [cap %d] GRUPO FORMADO pelo caminho de produção" % cap, formed)
		h.check("[cap %d] %d membros vivos simultâneos" % [cap, cap], host._runtime.active_count() >= cap)
		h.check("★ [cap %d] %d ATORES simultâneos" % [cap, cap], host.mob_actors().size() >= cap)
		h.check("★ [cap %d] saiu do INITIAL_FILL (regime permanente)" % cap, not host._runtime._in_initial_fill)
		h.check("[cap %d] telemetria group_formed_count ≥ 1" % cap, int(host._runtime.group_stats["group_formed_count"]) >= 1)
		h.check("★ [cap %d] max_simultaneous_alive registrado = %d" % [cap, cap], int(host._runtime.group_stats["max_simultaneous_alive"]) >= cap)
		h.check("[cap %d] cap respeitado (não estourou)" % cap, host._runtime.active_count() <= cap)
	h.group_complete()

func _finish() -> void:
	for n in _nodes:
		if is_instance_valid(n): n.queue_free()
	gs.verbose_combat_log = true
	gs.set_save_path_override(""); gs.apply_dict(_mem); gs._dirty = false; gs._session_started = false
	if FileAccess.file_exists("user://pve_multiactor_fixture.json"): DirAccess.remove_absolute("user://pve_multiactor_fixture.json")
	print("─────────────────────────────────────────────")
	var res := h.summarize("PVE MULTI-ACTOR INTEGRATION V1")
	var art := FileAccess.open("user://pve_multi_actor_integration_v1_selftest.json", FileAccess.WRITE)
	if art != null:
		art.store_string(JSON.stringify({"suite": "PVE_MULTI_ACTOR_INTEGRATION_V1", "result": res, "groups": h.groups}, "\t")); art.close()
	quit(0 if bool(res["ok"]) else 1)
