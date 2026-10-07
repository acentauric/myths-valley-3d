extends "res://tools/jev/sessao.gd"
## #56: a ponte preenche o campo por eventos de teclado e confirma Enter.
func _initialize() -> void:
	_conferir_nome.call_deferred()

func _conferir_nome() -> void:
	var cena := Control.new()
	root.add_child(cena)
	current_scene = cena
	var campo := LineEdit.new()
	campo.name = "NomeJogador"
	cena.add_child(campo)
	var enviados: Array[String] = []
	campo.text_submitted.connect(func(texto: String): enviados.append(texto))
	await process_frame
	var opcoes := _acoes({})
	var resultado := await _executar("name_player")
	var ok := opcoes.has("name_player") and enviados == ["Viajante de teste"] and resultado == "test_name_typed_and_submitted"
	print("AUTOPLAYER_NOME: %d falha(s)" % (0 if ok else 1))
	if not ok:
		print("FALHA: campo=", campo.text, " enviados=", enviados)
	quit(0 if ok else 1)
