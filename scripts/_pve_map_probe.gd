extends SceneTree
## SONDA DE COMPOSIÇÃO DE MAPA — Fase 1 do PAINTED MAP FIELD FIX.
## ⛔ NÃO é suíte de asserts: é um DUMP do que existe de fato na cena durante a caça do Ch1.
## Existe porque eu já errei o diagnóstico do "mapa antigo" duas vezes teorizando. Aqui a cena fala.
## Uso: --headless --path <proj> --script res://scripts/_pve_map_probe.gd

var main: Node = null
var _frame := 0
var _step := 0

func _initialize() -> void:
	print("═══════════ SONDA DE COMPOSIÇÃO DE MAPA (CH1) ═══════════")
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	process_frame.connect(_on_frame)

func _on_frame() -> void:
	_frame += 1
	if _step == 0 and _frame >= 10:
		main._enter_game()
		_step = 1; _frame = 0
	elif _step == 1 and _frame >= 20:
		_step = 2
		_dump()
		quit(0)

func _is_groundish(n: Node) -> bool:
	if n is ColorRect: return true
	if n is Sprite2D and int(n.z_index) <= -15: return true
	return false

func _describe(n: Node, depth: int) -> String:
	var cls := n.get_class()
	var extra := ""
	if n is ColorRect:
		var cr := n as ColorRect
		extra = " color=#%s size=%s pos=%s z=%d" % [cr.color.to_html(false), str(cr.size), str(cr.position), cr.z_index]
	elif n is Sprite2D:
		var sp := n as Sprite2D
		var tp := sp.texture.resource_path if sp.texture != null else "(sem textura)"
		var tw := sp.texture.get_width() if sp.texture != null else 0
		var th := sp.texture.get_height() if sp.texture != null else 0
		extra = " tex=%s %dx%d scale=%s pos=%s z=%d repeat=%d" % [tp, tw, th, str(sp.scale), str(sp.position), sp.z_index, int(sp.texture_repeat)]
	return "%s- %s [%s]%s" % ["  ".repeat(depth), n.name, cls, extra]

func _walk(n: Node, depth: int, out: Array) -> void:
	if _is_groundish(n): out.append(_describe(n, depth))
	for c in n.get_children():
		if depth < 6: _walk(c, depth + 1, out)

func _dump() -> void:
	print("\n── builders de chão que rodaram (region → builder) ──")
	for k in main.ground_builder_used.keys():
		print("   %-22s %s" % [k, str(main.ground_builder_used[k])])

	print("\n── região corrente / nó de região ──")
	var rn = main.get("_region_node")
	print("   _region_node = %s" % (rn.name if rn != null else "null"))
	if rn != null:
		print("   filhos diretos: %d" % rn.get_child_count())

	print("\n── NÓS DE CHÃO na cena (ColorRect + Sprite2D com z<=-15) ──")
	var out: Array = []
	_walk(main, 0, out)
	for line in out: print(line)
	print("   TOTAL de nós 'chão': %d" % out.size())

	print("\n── LivingWorld (overlay da atividade) ──")
	var env = main.get("_environment")
	if env == null:
		print("   (nenhum — só existe dentro de uma Hunt/Mission ativa)")
	else:
		print("   LivingWorld presente: %s | filhos=%d" % [env.name, env.get_child_count()])

	print("\n── VERDE #3c6b34 (a cor do ColorRect base do plains/vila) ──")
	var greens := 0
	for line in out:
		if line.contains("3c6b34"): greens += 1; print("   >>> %s" % line)
	print("   ocorrências do verde: %d" % greens)
	# ★★★ COBERTURA: o ponto de combate está longe da divisa entre regiões?
	print("\n── POSIÇÃO DE COMBATE vs FRONTEIRAS DE REGIÃO ──")
	var layout: Array = main._merged_world_layout()
	for e in layout:
		var id := str(e["id"])
		var off: Vector2 = e["offset"]
		var sz: Vector2 = main._region_world_size(id)
		print("   %-20s x=[%.0f..%.0f] y=[%.0f..%.0f] centro=(%.0f, %.0f)" % [id, off.x, off.x + sz.x, off.y, off.y + sz.y, off.x + sz.x * 0.5, off.y + sz.y * 0.5])
	# simula a âncora da caça do Ch1 pelo MESMO cálculo do HuntHost
	var origin: Vector2 = main.region_world_origin("plains")
	var rsize: Vector2 = main._region_world_size("plains")
	var slot := Vector2(200, 200)   # slot típico do HuntWorld
	var spread := Vector2(fposmod(slot.x, rsize.x * 0.4) - rsize.x * 0.2, fposmod(slot.y, rsize.y * 0.4) - rsize.y * 0.2)
	var anchor := origin + rsize * 0.5 + spread
	print("\n   âncora ANTIGA (origin+slot) = %s" % str(origin + slot))
	print("   âncora NOVA (centro+spread) = %s" % str(anchor))
	var cam_half := Vector2(640, 360)
	print("   câmera veria x=[%.0f..%.0f]" % [anchor.x - cam_half.x, anchor.x + cam_half.x])
	var village_right := 0.0
	for e in layout:
		if str(e["id"]) == "starter_village":
			village_right = (e["offset"] as Vector2).x + main._region_world_size("starter_village").x
	print("   borda direita da VILA = %.0f" % village_right)
	print("   ★ vila visível na caça? %s" % ("SIM (ainda invade)" if (anchor.x - cam_half.x) < village_right else "NÃO — folga de %.0f px" % ((anchor.x - cam_half.x) - village_right)))
	# ★★★ O QUE ESTÁ EM VOLTA DO PONTO DE COMBATE (props/NPCs que aparecem na tela)
	print("\n── NÓS VISÍVEIS PERTO DO SPOT DE COMBATE (raio 900px) ──")
	var spot := Vector2(3120, 680)   # âncora do Ch1 (centro de plains + spread)
	var near: Array = []
	_collect_near(main, spot, 900.0, near, 0)
	# agrupa por nome de classe/tipo para dar uma lista curta e acionável
	var by_kind := {}
	for e in near:
		var k := str(e["kind"])
		by_kind[k] = int(by_kind.get(k, 0)) + 1
	for k in by_kind.keys():
		print("   %-46s x%d" % [k, int(by_kind[k])])
	print("   TOTAL perto do combate: %d" % near.size())
	print("\n   ── detalhe (primeiros 30) ──")
	for i in range(mini(30, near.size())):
		var e = near[i]
		print("     %-30s [%s] pos=%s dist=%.0f" % [str(e["name"]), str(e["kind"]), str(e["pos"]), float(e["dist"])])
	print("\n═══════════ FIM DA SONDA ═══════════")

## Coleta nós VISÍVEIS com posição global perto do spot — é isso que entra no enquadramento.
func _collect_near(n: Node, spot: Vector2, radius: float, out: Array, depth: int) -> void:
	if depth > 7: return
	if n is Node2D:
		var n2 := n as Node2D
		if n2.visible:
			var d := n2.global_position.distance_to(spot)
			if d <= radius and d > 0.01:
				var kind := n2.get_class()
				if n2 is Sprite2D and (n2 as Sprite2D).texture != null:
					kind = "Sprite2D:" + (n2 as Sprite2D).texture.resource_path.get_file()
				elif n2.get_script() != null:
					kind = "script:" + str(n2.get_script().resource_path).get_file()
				out.append({"name": n2.name, "kind": kind, "pos": n2.global_position, "dist": d})
	for c in n.get_children():
		_collect_near(c, spot, radius, out, depth + 1)
