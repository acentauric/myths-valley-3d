extends SceneTree
## A fonte próxima não é útil quando seu talento ou sua ferramenta não permitem bater.
var falhas := 0

func _initialize() -> void:
	_testar.call_deferred()

func conferir(ok: bool, texto: String) -> void:
	if not ok:
		print("FALHA: ", texto)
		falhas += 1

func _testar() -> void:
	var recursos = load("res://scripts/prototipo_3d/recursos_3d.gd").new()
	root.add_child(recursos)
	var inventario = root.get_node("Inventario")
	inventario.adicionar("picareta")
	recursos._alvos = {
		"talento": {"pos": Vector3(1, 0, 0), "ficha": {"rende": "pedra", "ferramenta": "picareta", "nivel": 999}},
		"aco": {"pos": Vector3(2, 0, 0), "ficha": {"rende": "pedra", "ferramenta": "picareta", "grau": 999}},
		"possivel": {"pos": Vector3(6, 0, 0), "ficha": {"rende": "pedra", "ferramenta": "picareta", "nivel": 1, "grau": 1}},
	}
	conferir(recursos.mais_perto_que_rende("pedra", Vector3.ZERO) == Vector3(6, 0, 0), "ignorar talento e grau indisponíveis mesmo estando mais perto")
	if recursos.has_method("mais_perto_que_cede"):
		conferir(recursos.mais_perto_que_cede("pedra", Vector3.ZERO) == Vector3(6, 0, 0), "fonte estrita considera ferramenta na mochila sem exigir equipamento atual")
		var espacos: Array = inventario.espacos.duplicate(true)
		inventario.espacos.clear()
		conferir(not recursos.mais_perto_que_cede("pedra", Vector3.ZERO).is_finite(), "sem ferramenta carregada a fonte não é acessível")
		inventario.espacos = espacos
		recursos._alvos.erase("possivel")
		conferir(not recursos.mais_perto_que_cede("pedra", Vector3.ZERO).is_finite(), "sem fonte acessível não orientar interação impossível")
		recursos._alvos["manual"] = {"pos": Vector3(8, 0, 0), "ficha": {"rende": "lenha"}}
		conferir(recursos.mais_perto_que_cede("lenha", Vector3.ZERO) == Vector3(8, 0, 0), "coleta manual permanece acessível")
		conferir(not recursos.mais_perto_que_cede("tabua", Vector3.ZERO).is_finite(), "não inventar matéria-prima de receita")
	else:
		conferir(false, "testador precisa seleção estrita")
	recursos.free()
	print("ALVO_MATERIAL_ACESSIVEL: ", falhas, " falhas")
	quit(1 if falhas else 0)
