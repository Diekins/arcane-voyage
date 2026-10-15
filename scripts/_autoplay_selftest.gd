extends SceneTree
## Self-test FATIA A1 — AutoPlay (caça automática infinita). Exercita a máquina de estados de AutoPlay.gd
## com um HOST-MOCK (implementa os métodos autoplay_*), sem janela/input/save. Cobre: aquisição, continuidade
## (matar → próximo), sequência longa, zero-alvos (espera sem spam/erro), presença manual (cede o controle),
## reativação (sessão limpa), troca de contexto, herói abatido, e a instrumentação dos kills (sem dupla
## contagem). Rodar:
##   godot --headless --path godot -s res://scripts/_autoplay_selftest.gd

## Host de teste: reproduz o contrato mínimo que o AutoPlay chama. Flags controláveis pelo teste.
class MockHost:
	var can_fight := true
	var manual := false
	var has_target := false
	var in_range := false
	var enemies_available := true    # há candidato p/ adquirir?
	var acquire_calls := 0
	var release_calls := 0
	var defeated := false            # herói abatido? (A1.5 auto-revive)
	var revive_calls := 0

	func autoplay_can_fight() -> bool: return can_fight
	func autoplay_manual_active() -> bool: return manual
	func autoplay_has_target() -> bool: return has_target
	func autoplay_target_in_range() -> bool: return in_range
	func autoplay_hero_defeated() -> bool: return defeated
	func autoplay_request_revive() -> void:
		revive_calls += 1
		defeated = false
		can_fight = true   # revivido → pode combater de novo
	func autoplay_release() -> void:
		release_calls += 1
		has_target = false
		in_range = false
	func autoplay_acquire_nearest() -> bool:
		acquire_calls += 1
		if enemies_available:
			has_target = true
			in_range = true
			return true
		return false

## Avança N ticks de `dt` no AutoPlay.
func _tick(ap, n: int, dt: float) -> void:
	for i in range(n):
		ap.tick(dt)

func _initialize() -> void:
	var ok := true
	var AP := load("res://scripts/AutoPlay.gd")

	# ── TESTE A — AQUISIÇÃO: Auto ligado + alvo disponível → adquire e vai p/ luta ──
	var h := MockHost.new()
	var ap = AP.new()
	root.add_child(ap)
	ap.setup(h)
	_tick(ap, 3, 0.1)   # > SEARCH_INTERVAL (0.2) → dispara a busca
	var a_ok: bool = h.acquire_calls >= 1 and h.has_target and ap.get_state() == ap.St.FIGHTING
	print("  (A) aquisição → alvo travado + FIGHTING: %s  %s" % [str(a_ok), ("OK" if a_ok else "✗")])
	if not a_ok: ok = false

	# ── TESTE B — APPROACHING: tem alvo mas fora de alcance → estado 'indo' (host caminha) ──
	h.in_range = false
	ap.tick(0.1)
	var b_ok: bool = ap.get_state() == ap.St.APPROACHING
	print("  (B) fora de alcance → APPROACHING: %s  %s" % [str(b_ok), ("OK" if b_ok else "✗")])
	if not b_ok: ok = false
	h.in_range = true

	# ── TESTE D+E — CONTINUIDADE/SEQUÊNCIA: matar N vezes → readquire sozinho, conta kills ──
	var seq_ok := true
	var kills_before: int = ap.session_kills
	for i in range(50):
		# simula a morte do alvo atual: host solta o alvo + sinaliza o kill (como _on_mob_died faria)
		h.has_target = false
		h.in_range = false
		ap.notify_kill(null)
		_tick(ap, 3, 0.1)   # busca readquire o próximo
		if not h.has_target:
			seq_ok = false
			break
	var e_ok: bool = seq_ok and (ap.session_kills - kills_before) == 50
	print("  (D/E) 50 ciclos matar→readquirir, kills=%d: %s  %s" % [ap.session_kills, str(e_ok), ("OK" if e_ok else "✗")])
	if not e_ok: ok = false

	# ── TESTE F — ZERO ALVOS: acabaram os candidatos → SEARCHING, sem erro, sem desligar, aquisição tentada ──
	h.enemies_available = false
	h.has_target = false
	h.in_range = false
	var acq_before: int = h.acquire_calls
	_tick(ap, 10, 0.1)   # ~1s de espera
	var f_ok: bool = ap.enabled and ap.get_state() == ap.St.SEARCHING and h.acquire_calls > acq_before and not h.has_target
	print("  (F1) zero alvos → SEARCHING aguardando (tentou %d buscas): %s  %s" % [h.acquire_calls - acq_before, str(f_ok), ("OK" if f_ok else "✗")])
	if not f_ok: ok = false
	# respawn aparece → volta a caçar sozinho
	h.enemies_available = true
	_tick(ap, 3, 0.1)
	var f2_ok: bool = h.has_target and ap.get_state() == ap.St.FIGHTING
	print("  (F2) respawn → readquire sozinho: %s  %s" % [str(f2_ok), ("OK" if f2_ok else "✗")])
	if not f2_ok: ok = false

	# ── TESTE G — PRESENÇA MANUAL: WASD ativo → cede (release) + RECOVERING + NÃO adquire ──
	var acq_g: int = h.acquire_calls
	h.manual = true
	ap.tick(0.1)
	var g_ok: bool = ap.get_state() == ap.St.RECOVERING and not h.has_target and h.acquire_calls == acq_g
	print("  (G) presença manual → RECOVERING, cede controle, não adquire: %s  %s" % [str(g_ok), ("OK" if g_ok else "✗")])
	if not g_ok: ok = false
	# kill durante presença manual NÃO conta na sessão automática
	var k_manual: int = ap.session_kills
	ap.notify_kill(null)
	var g2_ok: bool = ap.session_kills == k_manual
	print("  (G2) kill durante presença manual não conta: %s  %s" % [str(g2_ok), ("OK" if g2_ok else "✗")])
	if not g2_ok: ok = false
	# solta o WASD → após o grace, retoma a caça sozinho
	h.manual = false
	_tick(ap, 8, 0.1)   # cobre MANUAL_RESUME_GRACE (0.45) + busca
	var g3_ok: bool = h.has_target and ap.get_state() == ap.St.FIGHTING
	print("  (G3) solta WASD → retoma a caça: %s  %s" % [str(g3_ok), ("OK" if g3_ok else "✗")])
	if not g3_ok: ok = false

	# ── TESTE herói ABATIDO — can_fight=false → RECOVERING, cede, não adquire; volta ao reviver ──
	h.can_fight = false
	ap.tick(0.1)
	var d_ok: bool = ap.get_state() == ap.St.RECOVERING and not h.has_target
	print("  (def) herói abatido → RECOVERING, sem ofensiva: %s  %s" % [str(d_ok), ("OK" if d_ok else "✗")])
	if not d_ok: ok = false
	h.can_fight = true
	_tick(ap, 3, 0.1)
	var d2_ok: bool = h.has_target
	print("  (def2) recuperou → volta a caçar: %s  %s" % [str(d2_ok), ("OK" if d2_ok else "✗")])
	if not d2_ok: ok = false

	# ══════════ AUTO-REVIVE (A1.5) — REVIVE-T01..T06 ══════════
	# REVIVE-T01: Auto ON + morte → auto-revive após o atraso (~2s)
	h.enemies_available = true; h.has_target = false
	h.defeated = true; h.can_fight = false; h.revive_calls = 0
	_tick(ap, 5, 0.1)   # 0.5s < 2s → ainda NÃO reviveu
	var rv_wait: bool = h.revive_calls == 0 and ap.get_state() == ap.St.RECOVERING
	_tick(ap, 20, 0.1)  # +2.0s → passa o AUTO_REVIVE_DELAY
	var t01_ok: bool = rv_wait and h.revive_calls == 1 and not h.defeated
	print("  (REVIVE-T01) Auto ON + morte → revive automático após atraso: %s  %s" % [str(t01_ok), ("OK" if t01_ok else "✗")])
	if not t01_ok: ok = false

	# REVIVE-T04: não ocorre double-revive (segue vivo → não chama de novo)
	_tick(ap, 30, 0.1)
	var t04_ok: bool = h.revive_calls == 1
	print("  (REVIVE-T04) sem double-revive: %s  %s" % [str(t04_ok), ("OK" if t04_ok else "✗")])
	if not t04_ok: ok = false

	# REVIVE-T05: após revive, AutoPlay volta a funcionar (readquire)
	_tick(ap, 3, 0.1)
	var t05_ok: bool = h.has_target and (ap.get_state() == ap.St.FIGHTING or ap.get_state() == ap.St.APPROACHING)
	print("  (REVIVE-T05) após revive, AutoPlay volta a caçar: %s  %s" % [str(t05_ok), ("OK" if t05_ok else "✗")])
	if not t05_ok: ok = false

	# REVIVE-T03: [R] manual antes do timer cancela o revive automático pendente
	h.defeated = true; h.can_fight = false; h.revive_calls = 0
	_tick(ap, 5, 0.1)   # arma o timer (0.5s), ainda pendente
	# jogador aperta [R] (manual): cura → deixa de estar abatido ANTES do timer
	h.defeated = false; h.can_fight = true
	_tick(ap, 25, 0.1)  # passa dos 2s
	var t03_ok: bool = h.revive_calls == 0   # o auto NÃO disparou (foi cancelado pela cura manual)
	print("  (REVIVE-T03) [R] antes do timer cancela o auto-revive pendente: %s  %s" % [str(t03_ok), ("OK" if t03_ok else "✗")])
	if not t03_ok: ok = false

	# REVIVE-T02: Auto OFF + morte → NÃO revive automaticamente (permanece manual)
	ap.set_enabled(false)
	h.defeated = true; h.can_fight = false; h.revive_calls = 0
	_tick(ap, 40, 0.1)  # 4s, bem além do atraso
	var t02_ok: bool = h.revive_calls == 0 and ap.get_state() == ap.St.DISABLED
	print("  (REVIVE-T02) Auto OFF + morte → sem auto-revive (manual): %s  %s" % [str(t02_ok), ("OK" if t02_ok else "✗")])
	if not t02_ok: ok = false
	# religa e revive p/ deixar o host são p/ os próximos testes
	ap.set_enabled(true)
	_tick(ap, 25, 0.1)

	# ── TESTE J — TROCA DE CONTEXTO: notify_region_changed → SEARCHING, mantém session_kills ──
	var kills_keep: int = ap.session_kills
	h.has_target = false; h.in_range = false
	ap.notify_region_changed()
	var j_ok: bool = ap.get_state() == ap.St.SEARCHING and ap.session_kills == kills_keep
	print("  (J) troca de contexto → SEARCHING, kills preservados (%d): %s  %s" % [ap.session_kills, str(j_ok), ("OK" if j_ok else "✗")])
	if not j_ok: ok = false

	# ── TESTE H — REATIVAÇÃO: desligar cede o controle; religar zera a sessão e recomeça limpo ──
	ap.set_enabled(false)
	var off_ok: bool = ap.get_state() == ap.St.DISABLED and not h.has_target
	ap.set_enabled(true)
	_tick(ap, 3, 0.1)
	var h_ok: bool = off_ok and ap.session_kills == 0 and h.has_target
	print("  (H) OFF cede + ON sessão limpa (kills=%d): %s  %s" % [ap.session_kills, str(h_ok), ("OK" if h_ok else "✗")])
	if not h_ok: ok = false

	ap.free()
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
