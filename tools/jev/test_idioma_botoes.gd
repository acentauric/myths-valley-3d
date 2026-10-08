extends "res://tools/jev/sessao.gd"
## #180: na tela de idioma o robô só oferece o botão do idioma da sessão. Oferecer o "Português"
## (Idioma0) com a sessão em inglês regravava a preferência e a partida abria toda em pt.
var falhas := 0


func _initialize() -> void:
	_conferir_botoes.call_deferred()


func _confere(condicao: bool, texto: String) -> void:
	if not condicao:
		print("FALHA: ", texto)
		falhas += 1


func _botoes_oferecidos() -> Array:
	var cena := Control.new()
	root.add_child(cena)
	current_scene = cena
	for i in 4:
		var botao := Button.new()
		botao.name = "Idioma%d" % i
		cena.add_child(botao)
	var opcoes := _acoes({})
	var nomes: Array = []
	for id in opcoes:
		nomes.append(str(catalogo[id].name))
	cena.free()
	return nomes


func _conferir_botoes() -> void:
	await process_frame
	indice_do_idioma = 0
	_confere(_botoes_oferecidos() == ["Idioma0"], "sem idioma pedido o robô confirma o português")
	indice_do_idioma = 1
	_confere(_botoes_oferecidos() == ["Idioma1"], "com a sessão em inglês só o botão English é oferecido")
	indice_do_idioma = 2
	_confere(_botoes_oferecidos() == ["Idioma2"], "com a sessão em espanhol só o botão Español é oferecido")
	indice_do_idioma = 3
	_confere(_botoes_oferecidos() == ["Idioma3"], "com a sessão em chinês só o botão 中文 é oferecido")
	print("AUTOPLAYER_IDIOMA_BOTOES: %d falha(s)" % falhas)
	quit(1 if falhas else 0)
