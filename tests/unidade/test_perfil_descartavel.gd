extends "res://tests/unidade/base.gd"
## NENHUM TESTE DE UNIDADE MEXE NAS TECLAS DE QUEM JOGA (#254).
##
##     .\tools\prototipo_3d\testar.ps1 -Teste perfil_descartavel
##
## O `controles.cfg` do autor tinha o mapa no I e a mochila no M, e a plaqueta do botão do mapa dizia "I": a leitura estava certa
## (a plaqueta lê o atalho), mas o que estava gravado vinha de um teste. `test_atalhos` e `test_mochila_rodape` põem o mapa no I
## e só devolviam o arquivo no fim — por fora do runner, com o `user://` de verdade, um teste interrompido no meio o deixava
## trocado. Duas perguntas, sobre o código dos testes:
##
##   1. O GUARDA EXISTE E FUNCIONA: `exige_perfil_descartavel` (em `base.gd`) deixa passar no perfil do runner e, fora dele,
##      não deixa: o teste fica pendente com a razão, em vez de gravar.
##   2. TODO TESTE QUE GRAVA OS ATALHOS PASSA POR ELE: um arquivo de `tests/unidade/` que chama `Atalhos.definir`, escreve no
##      `Atalhos.ARQUIVO` ou cita o `controles.cfg` tem de chamar o guarda — o teste de atalhos que alguém escrever amanhã
##      também.

const PASTA := "res://tests/unidade/"
## Quem fala dos atalhos sem gravá-los (esta pergunta e o próprio guarda).
const ISENTOS := ["base.gd", "test_perfil_descartavel.gd"]


func test_o_guarda_deixa_passar_so_o_perfil_descartavel() -> void:
	# O guarda é o que o `Estado` já usa para só apagar o user:// com perfil descartável: o aviso do runner E o caminho.
	var codigo := FileAccess.get_file_as_string("res://tests/suite/estado.gd")
	_conferir(codigo.contains("\"perfil\" in OS.get_user_data_dir()") and codigo.contains("TESTAR3D_PERFIL_DESCARTAVEL"),
		"Estado.perfil_descartavel deixou de conferir o aviso do runner e o caminho do perfil")
	var base := FileAccess.get_file_as_string(PASTA + "base.gd")
	_conferir(base.contains("func exige_perfil_descartavel() -> bool:") and base.contains("pending("),
		"o guarda não deixa o teste pendente fora do perfil descartável")
	# Sob o runner (que avisa o perfil descartável em TESTAR3D_PERFIL_DESCARTAVEL) o guarda TEM de deixar passar: se o
	# caminho do perfil deixasse de parecer um, os testes que gravam os atalhos ficariam pendentes em silêncio.
	if OS.get_environment("TESTAR3D_PERFIL_DESCARTAVEL") != "1":
		pending("por fora do testar.ps1 não há perfil descartável: o guarda barra os testes de atalhos, e não há mais o que conferir aqui")
		return
	_conferir(Estado.perfil_descartavel(),
		"o testar.ps1 avisou o perfil descartável, mas o caminho dele não o parece (user_dir: %s): os testes que gravam os atalhos ficariam pendentes em silêncio" % OS.get_user_data_dir())
	_conferir(exige_perfil_descartavel(), "o guarda barrou um teste no perfil descartável do runner")


func test_todo_teste_que_grava_os_atalhos_chama_o_guarda() -> void:
	var gravam: Array[String] = []
	var padroes := ["Atalhos.definir(", "atalhos.definir(", "Atalhos.ARQUIVO", "controles.cfg"]
	for nome in DirAccess.get_files_at(PASTA):
		if not nome.ends_with(".gd") or nome in ISENTOS:
			continue
		var texto := FileAccess.get_file_as_string(PASTA + nome)
		var mexe := false
		for padrao in padroes:
			if texto.contains(padrao):
				mexe = true
		if mexe:
			gravam.append(nome)
			_conferir(texto.contains("exige_perfil_descartavel()"),
				"%s mexe nos atalhos (grava o controles.cfg) e não chama exige_perfil_descartavel(): rodado por fora do runner, grava nas teclas de quem joga" % nome)
	# O que a pergunta enxerga hoje: os testes de atalhos e do rodapé da mochila.
	for esperado in ["test_atalhos.gd", "test_mochila_rodape.gd"]:
		_conferir(gravam.has(esperado), "o varredor não viu %s entre os testes que gravam os atalhos (%s)" % [esperado, str(gravam)])
