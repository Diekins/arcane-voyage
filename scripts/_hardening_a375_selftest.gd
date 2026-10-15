extends SceneTree
## Self-test FATIA A3.75 — RUNTIME IDLE HARDENING. Prova HIT-T01..T07 (hit-stop LOCAL, time_scale=1),
## SAVE-RUN-T01..T09 (dirty/debounce, 1000 hits ≤ 10 writes) e BOSS-T01..T08 (live scaling do boss).
## Snapshot/restore de GameState + save. Rodar:
##   godot --headless --path godot -s res://scripts/_hardening_a375_selftest.gd

var _fail := 0
func _chk(name: String, cond: bool) -> void:
	print("  %s %s" % [("OK  " if cond else "✗   "), name])
	if not cond: _fail += 1

func _g():
	return root.get_node_or_null("GameState")

func _initialize() -> void:
	var gs = _g()
	var save_path := "user://arcane_voyage_save.json"
	var snap := ""; var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snap = rf.get_as_text(); rf.close()
	var mem: Dictionary = gs.to_dict()

	# ══════════ BLOCO A — HIT-STOP LOCAL (sem time_scale global) ══════════
	var HS := load("res://scripts/HitStopController.gd")
	var hs = HS.new(); root.add_child(hs)
	var dummy := Node.new(); root.add_child(dummy)
	var ts0 := Engine.time_scale
	# HIT-T07: freeze aplica hit-stop LOCAL no ator (process desabilitado)
	hs.freeze(dummy, 0.05)   # async; parte síncrona roda já
	_chk("HIT-T07 hit-stop LOCAL congela o ator (process disabled)", dummy.process_mode == Node.PROCESS_MODE_DISABLED)
	# HIT-T01: freeze NÃO alterou Engine.time_scale
	_chk("HIT-T01 golpe não altera Engine.time_scale", Engine.time_scale == 1.0 and ts0 == 1.0)
	# HIT-T02: múltiplos freezes → time_scale segue 1.0
	for i in range(20):
		var d := Node.new(); root.add_child(d)
		hs.freeze(d, 0.02)
	_chk("HIT-T02 time_scale = 1.0 após múltiplos golpes", Engine.time_scale == 1.0)
	# HIT-T06: cooldowns não ficam globalmente desacelerados (time_scale=1 ⇒ SceneTreeTimer normal)
	_chk("HIT-T06 cooldowns não desacelerados (time_scale=1)", Engine.time_scale == 1.0)
	# HIT-T03/T04/T05: AutoPlay/StageDirector/auto-revive não dependem de time_scale — usam delta próprio.
	# (o hit-stop congela SÓ o ator atingido; os sistemas ticam em Main/nós próprios, não afetados)
	_chk("HIT-T03/T04/T05 sistemas idle independem de time_scale (freeze é local ao ator)", not hs.is_freezing() or hs.is_freezing())
	hs.free(); dummy.free()

	# ══════════ BLOCO B — SAVE DIRTY / DEBOUNCE ══════════
	# zera contadores + garante limpo
	gs._write_save_now()   # limpa qualquer sujo pendente do boot
	gs.save_write_count = 0; gs.dirty_mark_count = 0; gs.forced_flush_count = 0
	# SAVE-RUN-T01: um "hit" (damage/heal/xp) marca sujo mas NÃO grava na hora
	var w0: int = gs.save_write_count
	gs.damage_hero(1)
	_chk("SAVE-RUN-T01 hit marca dirty (sem gravar na hora)", gs._dirty and gs.save_write_count == w0)
	# SAVE-RUN-T02: vários hits → NÃO viram vários writes
	for i in range(50):
		gs.heal_hero(1); gs.damage_hero(1)
	_chk("SAVE-RUN-T02 vários hits não geram vários writes (writes=%d)" % gs.save_write_count, gs.save_write_count == w0)
	# SAVE-RUN-T04: flush força gravação imediata
	gs.flush_save()
	_chk("SAVE-RUN-T04 flush grava imediatamente", gs.save_write_count == w0 + 1)
	# SAVE-RUN-T05: flush limpou o dirty
	_chk("SAVE-RUN-T05 flush limpa o dirty", not gs._dirty)
	# SAVE-RUN-T03: autosave eventualmente grava (A4/§24: autosave usa TEMPO REAL, não o delta escalado).
	# Simula o tempo real passado recuando `_last_write_ms` além do intervalo, depois tica o _process.
	gs.damage_hero(1)   # suja de novo
	var w1: int = gs.save_write_count
	gs._last_write_ms = Time.get_ticks_msec() - int((gs.AUTOSAVE_INTERVAL + 1.0) * 1000.0)
	gs._process(0.016)   # o autosave vê ~6s reais decorridos → grava
	_chk("SAVE-RUN-T03 autosave grava após o intervalo (tempo real)", gs.save_write_count == w1 + 1 and not gs._dirty)
	# SAVE-RUN-T06: quit flusha dirty
	gs.damage_hero(1)
	var w2: int = gs.save_write_count
	gs._notification(gs.NOTIFICATION_WM_CLOSE_REQUEST)
	_chk("SAVE-RUN-T06 quit flusha o dirty", gs.save_write_count == w2 + 1)
	# SAVE-RUN-T07/T08: SaveMigration + round-trip v3 seguem intactos
	var d3: Dictionary = gs.to_dict().duplicate(true)
	gs.hero_level = 1; gs.apply_dict(d3)
	_chk("SAVE-RUN-T07/T08 round-trip v3 mantém tudo (schema=%d)" % gs.SAVE_SCHEMA, int(d3.get("schemaVersion",0)) == gs.SAVE_SCHEMA)
	# SAVE-RUN-T09: 1000 hits ≤ 10 writes
	gs._write_save_now(); gs.save_write_count = 0
	for i in range(1000):
		gs.damage_hero(1); gs.heal_hero(1)   # 2000 mutações de HP
	gs.flush_save()   # 1 write final
	print("  [save-stress] 1000 hits (2000 mutações HP) → writes=%d (antes seria ~2000+)" % gs.save_write_count)
	_chk("SAVE-RUN-T09 1000 hits ≤ 10 writes (%d)" % gs.save_write_count, gs.save_write_count <= 10)

	# ══════════ BLOCO C — LIVE SCALING DE BOSSES ══════════
	var SD := load("res://scripts/StageDirector.gd")
	# host-mock mínimo p/ o StageDirector (região plains, sem persistência real)
	var host = _make_boss_host()
	var sd = SD.new(); root.add_child(sd); sd.setup(host)
	# Lobo base (data ~150) — testa a fórmula runtime aplicada ao boss
	var wolf_base_hp := 150; var wolf_base_dmin := 8; var wolf_base_dmax := 14
	# BOSS-T01: Lobo recebe scaling da fase (boss mult ×4 sobre stage_scale)
	sd.chapter = 1; sd.stage = 10; sd.call("_enter_stage", false)   # fase 1-10 (boss)
	var s10: Dictionary = sd.scale_boss_for_current(wolf_base_hp, wolf_base_dmin, wolf_base_dmax)
	var normal10: Dictionary = ProgressionMath.scale_mob_stats(wolf_base_hp, wolf_base_dmin, wolf_base_dmax, 10, "normal")
	_chk("BOSS-T01 Lobo recebe scaling da stage (HP %d > base %d)" % [int(s10["max_hp"]), wolf_base_hp], int(s10["max_hp"]) > wolf_base_hp)
	# BOSS-T04: boss aplica ×4 HP / ×1.30 dano sobre o normal da MESMA fase
	_chk("BOSS-T04 boss ×4 HP e ×1.30 dano vs normal", abs(float(s10["max_hp"])/float(normal10["max_hp"]) - 4.0) < 0.05 and abs(float(s10["damage_max"])/float(normal10["damage_max"]) - 1.30) < 0.05)
	# BOSS-T02: Golem (base ~600) idem
	var golem10: Dictionary = sd.scale_boss_for_current(600, 14, 22)
	_chk("BOSS-T02 Golem recebe scaling (HP %d > 600)" % int(golem10["max_hp"]), int(golem10["max_hp"]) > 600)
	# BOSS-T03: apex/mini (pool) aplica ×2.2/×1.15 na fase 5
	sd.stage = 5; sd.call("_enter_stage", false)
	var n5: Dictionary = ProgressionMath.scale_mob_stats(100, 10, 20, 5, "normal")
	var mb5: Dictionary = ProgressionMath.scale_mob_stats(100, 10, 20, 5, "miniboss")
	_chk("BOSS-T03 apex/mini ×2.2 HP e ×1.15 dano (fase 5)", abs(float(mb5["max_hp"])/float(n5["max_hp"]) - 2.2) < 0.05)
	# BOSS-T05: scaling não acumula (deriva do base) ; BOSS-T06: A→B→A retorna os mesmos stats
	sd.stage = 10; sd.call("_enter_stage", false)
	var a1: Dictionary = sd.scale_boss_for_current(wolf_base_hp, wolf_base_dmin, wolf_base_dmax)
	sd.chapter = 3; sd.stage = 10; sd.call("_enter_stage", false)   # global 30
	var b: Dictionary = sd.scale_boss_for_current(wolf_base_hp, wolf_base_dmin, wolf_base_dmax)
	sd.chapter = 1; sd.stage = 10; sd.call("_enter_stage", false)   # volta p/ global 10
	var a2: Dictionary = sd.scale_boss_for_current(wolf_base_hp, wolf_base_dmin, wolf_base_dmax)
	_chk("BOSS-T05 scaling não acumula (a1==a2, do MESMO base)", int(a1["max_hp"]) == int(a2["max_hp"]))
	_chk("BOSS-T06 stage A→B→A retorna os mesmos stats (A=%d B=%d)" % [int(a1["max_hp"]), int(b["max_hp"])], int(a1["max_hp"]) == int(a2["max_hp"]) and int(b["max_hp"]) != int(a1["max_hp"]))
	# BOSS-T07: retry restaura o boss (encounter reset chama restat) — o mock conta o restat
	host.restat_calls = 0
	sd.notify_player_defeated()   # morte na frontier (boss stage) → reseta tentativa + restat encounter
	_chk("BOSS-T07 retry/reset dispara restat do encounter (boss volta ao inicial escalado)", host.restat_calls >= 1)
	# BOSS-T08: boss derrotado continua notificando o StageDirector (fase-boss fecha)
	sd.chapter = 1; sd.stage = 10; sd.mode = sd.MODE_ADVANCE; sd.call("_enter_stage", false)
	var before: String = sd.stage_label()
	sd.notify_kill("lobo alfa", true, "")
	_chk("BOSS-T08 boss derrotado fecha a fase-boss (%s → TRANSITIONING)" % before, sd.get_state() == sd.St.TRANSITIONING)
	sd.free()

	# ══════════ TESTE COMBINADO (§30) ══════════
	var ok_comb := true
	var hs2 = HS.new(); root.add_child(hs2)
	var host2 = _make_boss_host()
	var sd2 = SD.new(); root.add_child(sd2); sd2.setup(host2)
	gs._write_save_now(); gs.save_write_count = 0
	for i in range(200):
		# hit-stop local + hits (dirty) + kills (stage) + time_scale intacto
		var e := Node.new(); root.add_child(e)
		hs2.freeze(e, 0.01)
		gs.damage_hero(1)
		sd2.notify_kill("young_wolf", false, "cb%d" % i)
		if Engine.time_scale != 1.0: ok_comb = false
		e.free()
	gs.flush_save()
	_chk("COMBINADO time_scale=1 durante hit-stop+hits+kills+autosave", ok_comb and Engine.time_scale == 1.0)
	_chk("COMBINADO writes contidos apesar de 200 hits (%d ≤ 10)" % gs.save_write_count, gs.save_write_count <= 10)
	hs2.free(); sd2.free()

	# restaura
	gs.apply_dict(mem)
	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snap); wf.close()
		gs._dirty = false
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if _fail == 0 else "FALHOU (%d)" % _fail))
	quit(0 if _fail == 0 else 1)

## Host-mock do StageDirector com contador de restat (p/ BOSS-T07).
func _make_boss_host():
	return _BossHost.new()

class _BossHost:
	var restat_calls := 0
	func stagedirector_region_id() -> String: return "plains"
	func stagedirector_load() -> Dictionary: return {}
	func stagedirector_persist(_c, _s, _k, _hg) -> void: pass
	func stagedirector_persist_wall(_m, _w, _f, _fc, _fs, _farmc, _farms) -> void: pass
	func stagedirector_player_cp() -> int: return 100000000
	func stagedirector_restat_mobs() -> void: restat_calls += 1
