extends SceneTree
## Self-test do P1-A (First Contact Reframe). Lê o FONTE de Main.gd e confirma: strings reenquadradas PRESENTES e
## linguagem de conquista (missão/contrato/treinamento/aplauso) AUSENTE no onboarding/mural. + parse (load+métodos).
## Save-safe (snapshot/restore por protocolo; não muta GameState). Rodar:
##   godot --headless --path godot -s res://scripts/_p1a_selftest.gd

const PRESENT := [
	"A trilha segue a leste, para a Planície",   # Anciã: 1º puxão = estrada, mural como aparte
	"A trilha leste leva à Planície",            # hint orientação
	"Algo barra a trilha na Planície",           # hint: lobo = limiar
	"A trilha é sua.",                            # fecho sem treino/aplauso
	"Recados da Vila",                            # cabeçalho do mural
	"Mural de Recados",                           # título (sandbox)
	"Um pedido a menos na estrada",               # toast repetível
	"Um pedido atendido",                         # toast não-repetível
	"✦ TRILHA ATUAL",                             # header do tracker
	"Pedido recorrente: abata 4 Javalis",         # bounty re-vozeado (com espaço)
	"O mural de recados fica ali pela praça",      # fala de cidadão (Bran)
]
const ABSENT := [
	"Mural de Contratos", "Contratos da Vila", "Contrato cumprido", "Contrato recorrente:",
	"Tarefa concluída", "Leia o mural de missões", "O mural de missões",
	"Derrote o Lobo Alfa na Planície", "Seu chamado o espera", "Chamado atual",
	"se orgulha de você", "treinamento inicial", "ela orienta os novatos",
	"para encerrar seu treinamento", "✦ MISSÃO ATUAL", "Reputação %s",
]

func _initialize() -> void:
	var ok := true
	var save_path := "user://arcane_voyage_save.json"
	var snapshot := ""
	var had := FileAccess.file_exists(save_path)
	if had:
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf != null: snapshot = rf.get_as_text(); rf.close()

	# --- parse: carregar Main.gd e resolver métodos do onboarding ---
	var main = load("res://scripts/Main.gd").new()
	for m in ["_elder_lines", "_tutorial_hint", "_quest_board_lines"]:
		var has_m: bool = main.has_method(m)
		print("  método %s: %s" % [m, ("OK" if has_m else "✗ AUSENTE")])
		if not has_m: ok = false

	# --- scan do fonte ---
	var f := FileAccess.open("res://scripts/Main.gd", FileAccess.READ)
	if f == null:
		print("  ✗ não consegui abrir o fonte"); ok = false
	else:
		var src := f.get_as_text(); f.close()
		for s in PRESENT:
			var found: bool = src.contains(s)
			if not found: ok = false; print("  ✗ FALTA (deveria existir): '%s'" % s)
		for s in ABSENT:
			var gone: bool = not src.contains(s)
			if not gone: ok = false; print("  ✗ AINDA EXISTE (deveria sumir): '%s'" % s)
		print("  presentes-ok=%d/%d  ausentes-ok=%s" % [
			PRESENT.reduce(func(a, x): return a + (1 if src.contains(x) else 0), 0), PRESENT.size(),
			str(ABSENT.all(func(x): return not src.contains(x)))])

	if had:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null: wf.store_string(snapshot); wf.close()
		print("  [save-safe] user://save restaurado")
	print(">>> %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)
