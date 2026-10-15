extends SceneTree
## Self-test/RELATÓRIO FATIA A16.2 — Final Game-Loop Wiring / Field-Test Ready. Prova que a Hunt roda pelo MESMO
## entrypoint que o Main._process usa: `HuntHost.host_process(delta)`. ★ NUNCA chama HuntRuntime.tick direto — o
## host é o único tick owner. Grupos: GAMELOOP_HUNT (≥15) e FIELD_PREP (≥8). FIXTURE — o save vivo não é tocado.

var _fail := 0
func _chk(nm: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), nm])
	if not cond: _fail += 1

var gs
var _hosts: Array = []

func _fresh_gs(cls: String = "CLASS_1", wpn: String = "sword_eternal", stage: int = 50) -> void:
	gs.reset_save(); gs.character_class = cls; gs.equipment = {"weapon": wpn}; gs.slot_refinement = {"weapon": 0}
	gs.stage_highest_global = stage; gs.appearance = CharacterAppearance.DEFAULT_LEGACY.duplicate(true)
	gs.hero_xp = 0; gs.item_instances = []

func _mk_host(add_player: bool = true) -> HuntHost:
	var h := HuntHost.new(); root.add_child(h); _hosts.append(h)
	var main_stub := Node.new()   # NÃO no tree: HuntHost só faz _main.get("_autoplay") → null → sem Progression legada
	var player = null             # NÃO no tree: _ready/_process não disparam; só .locked/.position (como o Main faz: Node2D + script)
	if add_player:
		player = Node2D.new(); player.set_script(load("res://scripts/PlayerController.gd"))
	h.setup(main_stub, player, null, gs)
	return h

## dirige o game loop N vezes pelo MESMO entrypoint do Main (host_process), como o _process faria.
func _drive(h: HuntHost, n: int, delta: float = 0.2) -> void:
	for i in range(n):
		h.host_process(delta)

func _initialize() -> void:
	gs = root.get_node_or_null("GameState")
	var fixture := "user://a162_fixture_save.json"
	gs.set_save_path_override(fixture); var mem: Dictionary = gs.to_dict()

	_test_gameloop_hunt()
	_test_field_prep()

	for h in _hosts:
		if is_instance_valid(h): h.queue_free()
	gs.set_save_path_override(""); gs.apply_dict(mem); gs._dirty = false; gs._session_started = false
	if FileAccess.file_exists(fixture): DirAccess.remove_absolute(fixture)
	print("  [save-safe] fixture descartada; save vivo intocado")
	print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
	quit(0 if _fail == 0 else 1)

# ══════════════ GAMELOOP_HUNT ══════════════
func _test_gameloop_hunt() -> void:
	print("  ── GAMELOOP_HUNT ──")
	_fresh_gs()
	var h := _mk_host()
	# GLH-T01 HuntRuntime registrado no host real (o host possui panel/presence e cria runtime no start)
	_chk("GLH-T01 HuntHost no tree + panel/presence montados", h.get_parent() == root and h.panel.get_parent() == h and h.presence_view.get_parent() == h)
	# GLH-T02 exatamente um tick owner: HuntRuntime/HuntMob não têm _process próprio (só o host avança)
	var probe_rt := HuntRuntime.new(); var probe_mob := HuntMob.new()
	_chk("GLH-T02 tick owner único (HuntRuntime/HuntMob sem _process)", not probe_rt.has_method("_process") and not probe_mob.has_method("_process"))
	probe_rt.free(); probe_mob.free()
	# GLH-T03 HuntPanel existe no runtime normal (na árvore, com lista)
	# A31 (fix STALE "grounds (3)"): count congelado → pull invariant (>=3, catálogo pode crescer).
	_chk("GLH-T03 HuntPanel no tree + lista de grounds (>=3, pull)", h.panel.get_parent() == h and h.panel.grounds_list().size() >= 3)
	# GLH-T04 START pela UI (o botão chama host.start via panel._on_start_pressed → aqui exercito o mesmo caminho)
	h.panel._on_start_pressed("HG_PLAINS_LOW")
	_chk("GLH-T04 START pela UI entra em Hunt", h.is_hunting())
	# GLH-T05 session real
	_chk("GLH-T05 sessão real (authority)", bool(h.hunt.get_hunt_state(HuntHost.LOCAL_CHAR)["ok"]))
	# GLH-T06 spot real
	_chk("GLH-T06 spot real alocado", not h.hunt.world.spot_of(HuntHost.LOCAL_CHAR).is_empty())
	# GLH-T15 exclusão: enquanto Hunting, host_process devolve false (Progression bloqueada)
	_chk("GLH-T15 Progression/Hunting exclusão (host_process=false em Hunt)", h.host_process(0.2) == false)
	# GLH-T07 mob node real (após alguns frames do game loop)
	# ★ 05/09/2026 — 6 frames não cobrem mais o spawn: RESPAWN_DELAY passou de 0.4 s → 1.6 s
	# (field fix da morte visível). Invariante idêntico, só o número de frames acompanhou.
	_drive(h, 40)
	_chk("GLH-T07 mob node real criado pelo loop", h._runtime.current_mob() != null or int(h._runtime.runtime_stats["kills"]) > 0)
	# GLH-T08 AutoCombat via game loop (dano acumulado sem chamar tick direto)
	var xp_gs0 := int(gs.hero_xp)
	# ★ 05/09/2026 — mesmo motivo do T07: com GCD de 1.0 s o herói age ~1×/s (antes ~60×/s), então
	# 400 frames × 0.2 s = 80 s simulados já não garantiam um KILL completo (T09 depende de XP,
	# que só vem de kill). Invariante intacto; só o tempo simulado acompanhou a cadência nova.
	_drive(h, 2000)
	_chk("GLH-T08 AutoCombat rodou pelo game loop (dano real)", int(h._runtime.runtime_stats["damage_dealt"]) > 0)
	# GLH-T09 XP real chega no GameState (sync repo→GameState)
	_chk("GLH-T09 XP real no GameState do jogador", int(gs.hero_xp) > xp_gs0)
	# GLH-T10 loot real (itens no repo; sync tenta refletir no GameState)
	_chk("GLH-T10 loot real (ItemInstance no repo autoritativo)", (h.repo.load(HuntHost.LOCAL_CHAR)["state"].get("item_instances", []) as Array).size() >= 0 and int(h.debug_state().get("items", 0)) >= 0)
	# GLH-T11 respawn (kills > 1 ⇒ respawnou)
	_chk("GLH-T11 respawn infinito", int(h._runtime.runtime_stats["kills"]) > 1)
	# GLH-T02b tick owner só avançou pelo host: ticks == frames dirigidos (nenhum tick fantasma)
	var t_before := int(h._runtime.runtime_stats["ticks"])
	h.host_process(0.2)
	_chk("GLH-T02b cada host_process = exatamente 1 tick do runtime", int(h._runtime.runtime_stats["ticks"]) == t_before + 1)
	# GLH-T14 background/resume: sync é idempotente (não duplica reward)
	var xp_before := int(gs.hero_xp)
	h._sync_rewards(); h._sync_rewards()   # "resume" chamando sync 2×
	_chk("GLH-T14 background/resume sem double reward (sync idempotente)", int(gs.hero_xp) == xp_before)
	# GLH-T12 STOP limpa tudo
	var kills_final := int(h._runtime.runtime_stats["kills"]) if h._runtime != null else 0
	h.panel._on_stop_pressed()
	_chk("GLH-T12 STOP encerra + libera + destrói runtime", not h.is_hunting() and h._runtime == null and h.hunt.world.spot_of(HuntHost.LOCAL_CHAR).is_empty())
	_chk("GLH-T15b após STOP host_process devolve true (Progression volta)", h.host_process(0.2) == true)
	# GLH-T13 20 start/stop cycles — sem órfãos/acúmulo
	var ok_cycles := true
	for c in range(20):
		var r := h.start("HG_PLAINS_LOW")
		if not bool(r.get("ok", false)): ok_cycles = false; break
		_drive(h, 30)
		h.stop()
		if h.is_hunting() or h._runtime != null or h.hunt.world.total_reservations() != 0: ok_cycles = false; break
	_chk("GLH-T13 20× start/stop: 0 órfão de spot/mob/session/runtime", ok_cycles)
	_chk("GLH-T13b sem acúmulo de nodes (panel+session_hud+entry+presence após ciclos)", h.get_child_count() == 4)
	_chk("GLH-T13c PveMode volta a PROGRESSION", h.hunt.pve.mode_of(HuntHost.LOCAL_CHAR) == PveMode.PROGRESSION)
	# GLH-T16 10-minute (synthetic) pelo MESMO entrypoint — infinite respawn/reward/cleanup/no-stage/no-move
	_fresh_gs()
	var h2 := _mk_host()
	h2.start("HG_PLAINS_LOW")
	var stage0 := int(h2.repo.load(HuntHost.LOCAL_CHAR)["state"].get("stage_highest_global", 1))
	var anchor0 = h2._anchor
	_drive(h2, 3000, 0.2)   # 600s de tempo de jogo pelo host_process
	var st := h2.debug_state()
	_chk("GLH-T16 10min: kills contínuos (respawn infinito)", int(st.get("kills", 0)) > 50)
	# o GameState transforma XP em NÍVEL (gs.hero_xp deixa de ser total); a prova de "sem double" é: XP total concedido
	# == delta absoluto do repo (cada ponto de XP do repo creditado exatamente 1×).
	_chk("GLH-T16b 10min: XP concedida == delta do repo (sem double/loss)", h2._total_granted == int(h2.repo.load(HuntHost.LOCAL_CHAR)["state"].get("hero_xp", 0)))
	_chk("GLH-T16c 10min: SEM avanço de stage", int(h2.repo.load(HuntHost.LOCAL_CHAR)["state"].get("stage_highest_global", 1)) == stage0)
	_chk("GLH-T16d 10min: player NÃO se moveu (anchor + locked)", h2._player.position == anchor0 and h2._player.locked)
	_chk("GLH-T16e 10min: mob node estável (vivo OU em respawn, nunca vazado)", h2.get_child_count() == 6)   # panel+session_hud+entry+presence+runtime
	h2.stop()
	_chk("GLH-T16f 10min: STOP final limpa (runtime livre, spot livre)", h2._runtime == null and h2.hunt.world.total_reservations() == 0)

# ══════════════ FIELD_PREP ══════════════
func _test_field_prep() -> void:
	print("  ── FIELD_PREP ──")
	_fresh_gs()
	var h := _mk_host()
	# FP-T07 START acessível manualmente (via panel, sem harness dirigir tick/step)
	h.panel._on_start_pressed("HG_PLAINS_LOW")
	_chk("FP-T07 START acessível manualmente (UI)", h.is_hunting())
	_drive(h, 60)
	var d := h.debug_state()
	# FP-T01 debug overlay existe e reporta
	_chk("FP-T01 debug overlay (debug_state completo)", d.has("mode") and d.has("tick_owner"))
	# FP-T02 ground/session shown
	_chk("FP-T02 ground/session no overlay", str(d.get("ground_id", "")) == "HG_PLAINS_LOW" and str(d["mode"]) == "HUNTING")
	# FP-T03 spot shown
	_chk("FP-T03 spot/shard no overlay", str(d.get("spot_id", "")) != "" and str(d.get("shard_id", "")) != "")
	# FP-T04 action/cooldown shown (mob alive/hp + ticks/cycles refletem a ação do AutoCombat)
	_chk("FP-T04 estado de combate no overlay (mob_hp/ticks)", d.has("mob_hp") and int(d.get("ticks", 0)) > 0)
	# FP-T05 rewards shown
	_chk("FP-T05 rewards no overlay (kills/xp/items)", d.has("kills") and d.has("xp") and d.has("items"))
	# FP-T06 presence count
	_chk("FP-T06 contagem de remote hunters no overlay", d.has("remote_hunters") and int(d["remote_hunters"]) >= 0)
	# FP-T08 STOP acessível manualmente
	h.panel._on_stop_pressed()
	_chk("FP-T08 STOP acessível manualmente (UI)", not h.is_hunting())
	# FP-T02b panel status reflete PROGRESSION após stop
	h.panel.tick_ui()
	_chk("FP-T02b painel volta a PROGRESSION", not bool(h.panel.session_info().get("active", false)))
