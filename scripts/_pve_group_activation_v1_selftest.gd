extends SceneTree
## PVE GROUP ACTIVATION V1 — Stages 10/11/13/17A do contrato de grupo.
## ★★★ FOCO: os invariantes de CRÉDITO. É o risco nº1 declarado pelo arquiteto — com N mobs, N
## mortes podem cair na mesma janela, e é aí que double-credit / crédito perdido nascem.
##
## ⛔ NÃO usa amostragem por frame fixo (lição de _a161/_a162/_a19b/_a22): espera por CONDIÇÃO,
## com deadline. Teste que conta frames fica acoplado à cadência e quebra a cada ajuste de ritmo.
##
## Uso: --headless --path <proj> --script res://scripts/_pve_group_activation_v1_selftest.gd

var h: TestHarness = null
var gs
var _nodes: Array = []

func _initialize() -> void:
	h = TestHarness.new()
	print("═══════════ PVE GROUP ACTIVATION V1 — SELF-TEST ═══════════")
	gs = root.get_node_or_null("GameState")
	if gs != null: gs.verbose_combat_log = false
	_g_hard_cap()
	_g_instance_identity()
	_g_credit_exact_once()
	_g_simultaneous_death()
	_g_lost_credit()
	_g_primary_promotion()
	_g_actor_registry()
	_finish()

# ── helpers ────────────────────────────────────────────────────────────────────
## Runtime isolado, sem HuntService real: exercita LEDGER e CONTAINER, não reward de produção.
func _rt() -> HuntRuntime:
	var r := HuntRuntime.new()
	root.add_child(r); _nodes.append(r)
	return r

## Cria um HuntMob registrado no runtime, como o `_spawn_mob` faria (identidade + container).
func _member(r: HuntRuntime, mob_id: String, hp := 30) -> HuntMob:
	var m := HuntMob.new()
	m.setup(mob_id, hp, "spot", "char")
	r.add_child(m)
	r._instance_seq += 1
	m.instance_id = r._instance_seq
	r._register_member(m)
	if r._mob == null: r._mob = m
	return m

# ══════════════ HARD_CAP (Stage 17A) ══════════════
func _g_hard_cap() -> void:
	h.group_begin("HARD_CAP", 9)
	var r := _rt()
	# ★ ATUALIZADO 05/09 — EARLY NORMAL ligado: o default de produção passou de 1 para 2.
	# O que continua sendo provado é o INTERRUPTOR DE SEGURANÇA: `set_max_active(1)` recria o
	# comportamento antigo a qualquer momento (debug/regressão). Não perder isso.
	h.check("default de produção = 2 (EARLY NORMAL ligado)", r.max_active() == 2)
	r.set_max_active(1)
	h.check("★ interruptor de segurança: volta a 1 (comportamento antigo)", r.max_active() == 1)
	r.set_max_active(3);   h.check("set_max_active(3) aceita", r.max_active() == 3)
	r.set_max_active(0);   h.check("0 é clampado p/ 1 (nunca zero)", r.max_active() == 1)
	r.set_max_active(-5);  h.check("negativo é clampado p/ 1", r.max_active() == 1)
	r.set_max_active(999); h.check("★ config absurda NÃO explode (hard cap)", r.max_active() == HuntRuntime.GROUP_HARD_CAP)
	h.check("hard cap = nº de POCKETS existentes (6)", HuntRuntime.GROUP_HARD_CAP == 6)
	h.check("hard cap ≥ maior perfil previsto (VETERAN 5)", HuntRuntime.GROUP_HARD_CAP >= 5)
	h.check("hard cap não é ilimitado", HuntRuntime.GROUP_HARD_CAP < 100)
	h.group_complete()

# ══════════════ TWO_INSTANCE_IDENTITY (Stage 10A) ══════════════
func _g_instance_identity() -> void:
	h.group_begin("TWO_INSTANCE_IDENTITY", 10)
	var r := _rt(); r.set_max_active(2)
	var a := _member(r, "young_wolf")
	var b := _member(r, "young_wolf")   # MESMA definição, indivíduos diferentes
	h.check("2 membros vivos", r.active_count() == 2)
	h.check("★ mesma definição (mob_id) nos dois", a.mob_id == b.mob_id)
	h.check("★ instance_id DIFERENTE (é o que distingue)", a.instance_id != b.instance_id)
	h.check("instance_id de A > 0", a.instance_id > 0)
	h.check("instance_id de B > 0", b.instance_id > 0)
	h.check("primary é A", r.primary_mob() == a)
	h.check("current_mob() (API legada) = primary", r.current_mob() == a)
	h.check("active_mobs() contém A", r.active_mobs().has(a))
	h.check("active_mobs() contém B", r.active_mobs().has(b))
	h.check("nós distintos (sem ref compartilhada)", a != b)
	h.group_complete()

# ══════════════ CREDIT_EXACT_ONCE (Stage 11A) ══════════════
func _g_credit_exact_once() -> void:
	h.group_begin("CREDIT_EXACT_ONCE", 10)
	var r := _rt(); r.set_max_active(2)
	var a := _member(r, "young_wolf")
	h.check("1º claim CONCEDE crédito", r._claim_kill_credit(a))
	h.check("granted = 1", int(r.group_stats["credit_granted"]) == 1)
	# ★ sinal de morte DUPLICADO da mesma instância (Stage 11A)
	h.check("★ 2º claim da MESMA instância é BLOQUEADO", not r._claim_kill_credit(a))
	h.check("★ granted continua 1 (sem double-credit)", int(r.group_stats["credit_granted"]) == 1)
	h.check("blocked_dup = 1", int(r.group_stats["credit_blocked_dup"]) == 1)
	h.check("3º claim também bloqueado", not r._claim_kill_credit(a))
	h.check("blocked_dup = 2", int(r.group_stats["credit_blocked_dup"]) == 2)
	var b := _member(r, "young_wolf")
	h.check("★ OUTRA instância credita normalmente", r._claim_kill_credit(b))
	h.check("granted = 2 (A e B, um cada)", int(r.group_stats["credit_granted"]) == 2)
	h.check("blocked_dup segue 2", int(r.group_stats["credit_blocked_dup"]) == 2)
	h.group_complete()

# ══════════════ SIMULTANEOUS_DEATH_CREDIT (Stage 11) ══════════════
func _g_simultaneous_death() -> void:
	h.group_begin("SIMULTANEOUS_DEATH_CREDIT", 10)
	for n in [2, 3]:
		var r := _rt(); r.set_max_active(n)
		var ms: Array = []
		for i in range(n): ms.append(_member(r, "young_wolf"))
		h.check("[%d] grupo montado" % n, r.active_count() == n)
		# TODOS morrem na MESMA janela lógica — o cenário que cria double-credit
		var granted := 0
		for m in ms:
			if r._claim_kill_credit(m): granted += 1
		h.check("★ [%d] crédito total EXATO = %d" % [n, n], granted == n)
		h.check("[%d] granted no ledger = %d" % [n, n], int(r.group_stats["credit_granted"]) == n)
		h.check("★ [%d] ZERO bloqueio (mortes legítimas distintas)" % n, int(r.group_stats["credit_blocked_dup"]) == 0)
		# repetir TODOS os sinais: nada pode passar de novo
		var again := 0
		for m in ms:
			if r._claim_kill_credit(m): again += 1
		h.check("★ [%d] repetição dos %d sinais credita ZERO" % [n, n], again == 0)
	h.group_complete()

# ══════════════ LOST_CREDIT_DETECTION (Stage 11B) ══════════════
func _g_lost_credit() -> void:
	h.group_begin("LOST_CREDIT_DETECTION", 8)
	var r := _rt(); r.set_max_active(2)
	var a := _member(r, "young_wolf", 10)
	h.check("membro vivo antes", r.active_count() == 1)
	# mata SEM passar pelo caminho de settlement (é o defeito que queremos detectar)
	a.take_damage(999, "char")
	h.check("mob está morto", not a.alive())
	h.check("ainda registrado (settlement não rodou)", r._active_mobs.has(a))
	h.check("nenhum crédito registrado", int(r.group_stats["credit_granted"]) == 0)
	r._sweep_unsettled()
	h.check("★ morte sem crédito DETECTADA (não silenciada)", int(r.group_stats["death_without_credit"]) == 1)
	h.check("membro removido do container pelo sweep", not r._active_mobs.has(a))
	h.check("★ sweep NÃO inventa crédito (não conserta em silêncio)", int(r.group_stats["credit_granted"]) == 0)
	r._sweep_unsettled()
	h.check("sweep idempotente (não conta de novo)", int(r.group_stats["death_without_credit"]) == 1)
	h.group_complete()

# ══════════════ TARGET_ROTATION / PRIMARY PROMOTION (Stage 13/16B) ══════════════
func _g_primary_promotion() -> void:
	h.group_begin("TARGET_ROTATION_CHAIN", 12)
	var r := _rt(); r.set_max_active(3)
	var a := _member(r, "young_wolf")
	var b := _member(r, "young_wolf")
	var c := _member(r, "young_wolf")
	h.check("primary inicial = A", r.primary_mob() == a)
	h.check("current_mob() = A", r.current_mob() == a)
	# A morre → B promovido
	r._unregister_member(a)
	h.check("★ A removido promove novo primary", r.primary_mob() != a)
	h.check("★ primary = B (ordem determinística: 1º vivo do container)", r.primary_mob() == b)
	h.check("current_mob() acompanha (API legada coerente)", r.current_mob() == b)
	h.check("active_count = 2", r.active_count() == 2)
	# B morre → C promovido
	r._unregister_member(b)
	h.check("★ cadeia: primary = C", r.primary_mob() == c)
	h.check("current_mob() = C", r.current_mob() == c)
	h.check("active_count = 1", r.active_count() == 1)
	# C morre → ninguém
	r._unregister_member(c)
	h.check("★ sem membros ⇒ primary null (nunca aponta p/ morto)", r.primary_mob() == null)
	h.check("current_mob() null (API legada coerente)", r.current_mob() == null)
	h.check("active_count = 0", r.active_count() == 0)
	h.group_complete()

# ══════════════ ACTOR_REGISTRY (host multi-ator: Fases 2/9/10/19) ══════════════
## Exercita a LÓGICA do registro sem montar HuntService/repo: pocket estável e distinto por
## instância, e descarte seguro de feedback tardio. É o que impede dois mobs de dividirem um ator.
func _g_actor_registry() -> void:
	h.group_begin("ACTOR_REGISTRY", 12)
	var host := HuntHost.new()
	root.add_child(host); _nodes.append(host)
	h.check("registro começa vazio", host._mob_actors_by_instance.is_empty())
	h.check("mob_actors() vazio", host.mob_actors().is_empty())
	h.check("★ ator de instância desconhecida = null (base do late-feedback)", host._actor_for_instance(42) == null)
	# ★ POCKETS DISTINTOS — o núcleo da formação: 2 mobs não podem nascer no mesmo ponto
	var p0 := host._next_free_pocket()
	host._pocket_by_instance[101] = p0
	var p1 := host._next_free_pocket()
	host._pocket_by_instance[102] = p1
	var p2 := host._next_free_pocket()
	host._pocket_by_instance[103] = p2
	h.check("★ instância 1 e 2 recebem pockets DIFERENTES", p0 != p1)
	h.check("★ instância 3 difere das duas", p2 != p0 and p2 != p1)
	h.check("pockets dentro do range válido", p0 >= 0 and p0 < PveMobActor.POCKETS.size() and p1 < PveMobActor.POCKETS.size())
	h.check("★ pocket é ESTÁVEL (não muda ao reconsultar)", int(host._pocket_by_instance[101]) == p0)
	h.check("posições de POCKET realmente distintas no mundo", PveMobActor.pocket_for(p0) != PveMobActor.pocket_for(p1))
	h.check("hard cap do grupo ≤ nº de pockets (todo membro tem lugar)", HuntRuntime.GROUP_HARD_CAP <= PveMobActor.POCKETS.size())
	# ★ FASE 19 — feedback de instância inexistente NÃO cai no primário e NÃO estoura
	var before := int(host.host_group_stats["late_feedback_dropped"])
	host._on_combat_feedback("hit", {"amount": 77, "instance_id": 999, "mob_id": "young_wolf"})
	h.check("★ feedback tardio DESCARTADO (não roteia p/ primário)", int(host.host_group_stats["late_feedback_dropped"]) == before + 1)
	h.check("descarte não criou ator", host._mob_actors_by_instance.is_empty())
	h.check("descarte não quebrou o host", is_instance_valid(host))
	h.group_complete()

func _finish() -> void:
	for n in _nodes:
		if is_instance_valid(n): n.queue_free()
	if gs != null: gs.verbose_combat_log = true
	print("─────────────────────────────────────────────")
	var res := h.summarize("PVE GROUP ACTIVATION V1")
	var art := FileAccess.open("user://pve_group_activation_v1_selftest.json", FileAccess.WRITE)
	if art != null:
		art.store_string(JSON.stringify({"suite": "PVE_GROUP_ACTIVATION_V1", "result": res, "groups": h.groups}, "\t")); art.close()
		print("    artefato de conclusão: user://pve_group_activation_v1_selftest.json")
	quit(0 if bool(res["ok"]) else 1)
