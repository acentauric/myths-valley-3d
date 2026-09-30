extends SceneTree
## Confere A TABELA DE ATALHOS do vale (#4) — as letras, não as telas.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/atalhos.gd
##
## Cada tela tem o próprio portão, e cada um deles já pergunta se a SUA tecla é
## a certa. O que nenhum pergunta é a tabela INTEIRA — e foi por aí que a
## mochila ficou de fora: o I estava escrito à mão no `prototype.gd`, não
## aparecia no AJUSTAR, e a troca de letras não o enxergava.
##
##   1. AS CINCO TELAS ESTÃO NA TABELA, nas letras do 2D: mochila I, painel J,
##      talentos K, almanaque L, arraial P.
##   2. NENHUMA COLISÃO DE FÁBRICA, nem entre atalhos nem com as letras que
##      andam — e a reserva cobre toda letra que o movimento usa.
##   3. O AJUSTAR SÓ OFERECE LETRA LIVRE, e toda letra de fábrica está entre elas.
##   4. LETRA RESERVADA É RECUSADA: pelo `definir()`, e também quando já está
##      gravada no arquivo, de antes de haver reserva.
##   5. A TROCA CHEGA AO INPUTMAP: pôr o mapa no I dá o M à mochila, e o
##      `aplicar()` faz cada ação responder à letra nova, e só a ela.
##   6. NENHUMA LETRA FIXA NO CÓDIGO DO VALE fora da tabela, a não ser as que
##      andam e as declaradas abaixo, com a razão. É a pergunta que teria pegado
##      o I da mochila e, antes dele, o L do almanaque.
##
## O `controles.cfg` de verdade vai para uma reserva e volta no fim.

const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")
const TeclasMovimento = preload("res://scripts/prototipo_3d/teclas_movimento.gd")

const RESERVA := "user://reserva_do_teste_de_atalhos.cfg"
const PASTA_DO_VALE := "res://scripts/prototipo_3d/"

const TELAS := {
	"mochila": KEY_I,
	"painel": KEY_J,
	"talentos": KEY_K,
	"almanaque": KEY_L,
	"arraial": KEY_P,
}

## Letra fixa fora da tabela, arquivo a arquivo, com a razão.
const LETRA_FIXA_PERMITIDA := {
	"abertura.gd": {
		KEY_E: "a abertura roda antes do vale e aceita Enter, Espaço e E para seguir; é tecla de 'continuar', não o atalho de interagir",
	},
}

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("ATALHOS_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_devolver_reserva_esquecida()
	_guardar_as_preferencias_de_verdade()

	# --- 1. AS CINCO TELAS ESTÃO NA TABELA ------------------------------------
	for acao in TELAS:
		_conferir(Atalhos.DEFINICOES.has(acao), "a tela '%s' não está na tabela de atalhos" % acao)
		if not Atalhos.DEFINICOES.has(acao):
			continue
		_conferir(int(Atalhos.DEFINICOES[acao]["padrao"]) == int(TELAS[acao]),
			"'%s' vem de fábrica no %s, e a tecla dela no 2D é %s" % [acao,
				OS.get_keycode_string(int(Atalhos.DEFINICOES[acao]["padrao"])), OS.get_keycode_string(int(TELAS[acao]))])
		_conferir(Atalhos.tecla(acao) == int(TELAS[acao]),
			"sem preferência gravada, '%s' não responde no %s" % [acao, OS.get_keycode_string(int(TELAS[acao]))])
	_conferir(Atalhos.ACOES_INPUT.get("mochila", "") == "mv_mochila",
		"a mochila não re-registra a mv_mochila no aplicar(): remapeada no AJUSTAR, ela continuaria no I")

	# --- 2. NENHUMA COLISÃO DE FÁBRICA ----------------------------------------
	var vistas := {}
	for acao in Atalhos.DEFINICOES:
		var padrao := int(Atalhos.DEFINICOES[acao]["padrao"])
		_conferir(not vistas.has(padrao), "%s e %s vêm de fábrica na mesma tecla" % [acao, vistas.get(padrao, "")])
		vistas[padrao] = acao
		_conferir(not Atalhos.RESERVADAS.has(padrao),
			"'%s' vem de fábrica numa letra reservada (%s)" % [acao, OS.get_keycode_string(padrao)])
	for acao in TeclasMovimento.ACOES:
		for tecla in TeclasMovimento.ACOES[acao]:
			if int(tecla) >= KEY_A and int(tecla) <= KEY_Z:
				_conferir(Atalhos.RESERVADAS.has(int(tecla)),
					"%s anda com o %s, e a reserva dos atalhos não o protege" % [acao, OS.get_keycode_string(int(tecla))])

	# --- 3. O AJUSTAR SÓ OFERECE LETRA LIVRE ----------------------------------
	var livres: Array = Atalhos.letras_livres()
	_conferir(livres.size() == 26 - Atalhos.RESERVADAS.size(),
		"o AJUSTAR oferece %d letras, e deviam ser %d" % [livres.size(), 26 - Atalhos.RESERVADAS.size()])
	for codigo in livres:
		_conferir(not Atalhos.RESERVADAS.has(int(codigo)),
			"o AJUSTAR oferece o %s, que é reservado" % OS.get_keycode_string(int(codigo)))
	for acao in Atalhos.DEFINICOES:
		_conferir(livres.has(int(Atalhos.DEFINICOES[acao]["padrao"])),
			"a letra de fábrica de '%s' não está entre as que o AJUSTAR oferece: restaurar o padrão não teria o que mostrar" % acao)

	# --- 4. LETRA RESERVADA É RECUSADA ----------------------------------------
	_conferir(not Atalhos.definir("mapa", KEY_W), "o definir() aceitou pôr o mapa no W")
	_conferir(Atalhos.tecla("mapa") == KEY_M, "depois da recusa, o mapa saiu do M: %s" % Atalhos.letra("mapa"))
	var ninguem_no_w := true
	for acao in Atalhos.DEFINICOES:
		if Atalhos.tecla(acao) == KEY_W:
			ninguem_no_w = false
	_conferir(ninguem_no_w, "a recusa do W deixou alguma ação no W")
	_conferir(not Atalhos.definir("tela_que_nao_existe", KEY_Q), "o definir() gravou uma ação que a tabela não tem")

	# Gravada à mão, de antes da reserva: volta ao padrão.
	var arquivo := ConfigFile.new()
	arquivo.set_value("atalhos", "painel", KEY_S)
	arquivo.save(Atalhos.ARQUIVO)
	Atalhos._cache.clear()
	_conferir(Atalhos.tecla("painel") == KEY_J,
		"um S gravado no arquivo pôs o painel no S — o primeiro passo para trás abriria o painel")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Atalhos.ARQUIVO))
	Atalhos._cache.clear()

	# --- 5. A TROCA CHEGA AO INPUTMAP -----------------------------------------
	_conferir(Atalhos.definir("mapa", KEY_I), "o definir() recusou pôr o mapa no I, que é letra livre")
	_conferir(Atalhos.tecla("mapa") == KEY_I, "o mapa não foi para o I")
	_conferir(Atalhos.tecla("mochila") == KEY_M, "a mochila não herdou o M do mapa: as duas ficaram no I")
	Atalhos.aplicar()
	_conferir(_responde("mv_mochila", KEY_M), "remapeada para o M, a mochila não responde ao M")
	_conferir(not _responde("mv_mochila", KEY_I), "remapeada para o M, a mochila continua respondendo ao I")
	_conferir(_responde("mv_mapa", KEY_I), "remapeado para o I, o mapa não responde ao I")
	_conferir(not _responde("mv_mapa", KEY_M), "remapeado para o I, o mapa continua respondendo ao M")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Atalhos.ARQUIVO))
	Atalhos._cache.clear()
	Atalhos.aplicar()

	# --- 6. NENHUMA LETRA FIXA NO CÓDIGO DO VALE ------------------------------
	var escritas := _letras_escritas_no_vale()
	for chave in escritas:
		var arquivo_nome: String = chave.split(":")[0]
		var codigo := int(chave.split(":")[1])
		var permitidas: Dictionary = LETRA_FIXA_PERMITIDA.get(arquivo_nome, {})
		_conferir(permitidas.has(codigo),
			"%s escreve o %s à mão, fora da tabela de atalhos: o AJUSTAR não o enxerga e a troca de letras não o protege (%s)" % [
				arquivo_nome, OS.get_keycode_string(codigo), escritas[chave]])
	for arquivo_nome in LETRA_FIXA_PERMITIDA:
		for codigo in LETRA_FIXA_PERMITIDA[arquivo_nome]:
			_conferir(str(LETRA_FIXA_PERMITIDA[arquivo_nome][codigo]).length() > 20,
				"%s: o %s está permitido sem razão escrita" % [arquivo_nome, OS.get_keycode_string(int(codigo))])
			_conferir(escritas.has("%s:%d" % [arquivo_nome, int(codigo)]),
				"%s não escreve mais o %s à mão: tire a linha da permissão" % [arquivo_nome, OS.get_keycode_string(int(codigo))])

	_fechar()


## A ação do InputMap responde a esta tecla física?
func _responde(acao: String, codigo: int) -> bool:
	var evento := InputEventKey.new()
	evento.physical_keycode = codigo
	evento.pressed = true
	return InputMap.has_action(acao) and InputMap.event_is_action(evento, acao, true)


## "arquivo.gd:keycode" → "linha N" de toda letra A–Z escrita como `KEY_X` no
## código do vale, fora de comentário, tirando a tabela, o movimento e as
## letras reservadas (que andam, e dentro das telas escolhem).
func _letras_escritas_no_vale() -> Dictionary:
	var achadas := {}
	var padrao := RegEx.new()
	padrao.compile("\\bKEY_([A-Z])\\b")
	for nome in DirAccess.get_files_at(PASTA_DO_VALE):
		if not nome.ends_with(".gd") or nome in ["atalhos.gd", "teclas_movimento.gd"]:
			continue
		var linhas := FileAccess.get_file_as_string(PASTA_DO_VALE + nome).split("\n")
		for n in linhas.size():
			var linha: String = linhas[n]
			var comentario := linha.find("#")
			if comentario >= 0:
				linha = linha.substr(0, comentario)
			for achado in padrao.search_all(linha):
				var codigo := KEY_A + (achado.get_string(1).unicode_at(0) - "A".unicode_at(0))
				if Atalhos.RESERVADAS.has(codigo):
					continue
				achadas["%s:%d" % [nome, codigo]] = "linha %d" % (n + 1)
	return achadas


func _guardar_as_preferencias_de_verdade() -> void:
	var de_verdade := ProjectSettings.globalize_path(Atalhos.ARQUIVO)
	if FileAccess.file_exists(Atalhos.ARQUIVO):
		DirAccess.copy_absolute(de_verdade, ProjectSettings.globalize_path(RESERVA))
		DirAccess.remove_absolute(de_verdade)
	Atalhos._cache.clear()


## Um teste que caiu no meio deixou a reserva: ela é o arquivo de verdade.
func _devolver_reserva_esquecida() -> void:
	if FileAccess.file_exists(RESERVA):
		var reserva := ProjectSettings.globalize_path(RESERVA)
		DirAccess.copy_absolute(reserva, ProjectSettings.globalize_path(Atalhos.ARQUIVO))
		DirAccess.remove_absolute(reserva)


func _devolver_as_preferencias() -> void:
	var de_verdade := ProjectSettings.globalize_path(Atalhos.ARQUIVO)
	if FileAccess.file_exists(Atalhos.ARQUIVO):
		DirAccess.remove_absolute(de_verdade)
	if FileAccess.file_exists(RESERVA):
		var reserva := ProjectSettings.globalize_path(RESERVA)
		DirAccess.copy_absolute(reserva, de_verdade)
		DirAccess.remove_absolute(reserva)
	Atalhos._cache.clear()


func _fechar() -> void:
	_devolver_as_preferencias()
	print("")
	if falhas == 0:
		print("ATALHOS_OK: as cinco telas estão na tabela nas letras do 2D, nenhuma letra de fábrica colide nem cai no que anda, o AJUSTAR só oferece letra livre, letra reservada é recusada no definir e no arquivo, a troca chega ao InputMap, e nenhuma letra fixa escapa da tabela no código do vale")
	else:
		print("atalhos: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)
