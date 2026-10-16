extends "res://tests/unidade/base.gd"
## A FALA DO PEDRO DIZ AS TECLAS DE QUEM JOGA (#254).
##
##     .\tools\prototipo_3d\testar.ps1 -Teste teclas_no_texto
##
## "Pedro: o I abre a mochila, e o F come o que estiver marcado" — e a plaquinha do botão mostrava outra letra. As lições de
## `data/missoes_guia.json` escreviam as letras à mão, e com o `controles.cfg` do autor (o mapa no I, a mochila no M) a fala
## mentia ao lado da plaqueta. Agora o texto cita a tecla pela AÇÃO, `{tecla:mochila}`, e quem o lê (`IdiomaMenu.campo`, por
## onde passa todo texto traduzido dos dados) a troca pela letra que o jogador tem. Quatro perguntas:
##
##   1. A MARCA SE RESOLVE (`Atalhos.resolver`): na letra de fábrica e na que o jogador escolheu (o mapa no I dá o M à
##      mochila), várias numa frase, e a que a tabela não conhece fica como está.
##   2. `IdiomaMenu.campo` A RESOLVE, nos três idiomas, e sem marca devolve o texto como veio.
##   3. TODA MARCA DOS DADOS É BOA: nomeia uma ação da tabela, está fechada, e as três línguas de um campo citam as mesmas.
##   4. NENHUMA LETRA À MÃO. A cadeia do Pedro (`missoes_guia.json`) não escreve tecla nenhuma que o jogador possa trocar; as
##      outras filas, nenhuma que não seja o E. Quem ensina a letra pela palavra ("P de povo") está declarado, com a razão.
##
## A primeira e a segunda gravam o `controles.cfg` e o idioma, e por isso só rodam no perfil descartável do `testar.ps1`.

const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")
const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")

## Os campos de texto de uma missão que o jogador lê.
const CAMPOS := ["texto", "resumo", "diario", "titulo", "resposta", "trancada"]
const SUFIXOS := ["", "_en", "_es", "_zh"]
## As letras que a tabela de atalhos pode trocar; o F fica de fora, e é de propósito: dentro da mochila o F veste ou come, e
## essa letra é escrita à mão no `prototype.gd` (ver `LETRA_FIXA_PERMITIDA` em `test_atalhos.gd`), então a fala "o F come" é
## verdade em qualquer perfil. O W, o A, o S e o D andam e não se trocam.
const TROCAVEIS := "EIJKLPCTRMBV"

## A cadeia em que o jogador aprende o jogo: nenhuma tecla trocável à mão, o E inclusive.
const A_CADEIA_DO_PEDRO := "missoes_guia.json"
## Letra à mão que fica, por arquivo, com a razão.
const LETRA_A_MAO_PERMITIDA := {
	"missoes_arraial.json": {
		"P": "a lição ensina a letra pela palavra — 'a letra de povo', 'P for people', 'la P de pueblo' —, e com a tecla trocada a frase perderia o sentido",
	},
}
var _idioma_de_antes := 0
var _padroes: Array[RegEx] = []


func before_each() -> void:
	super()
	Atalhos._cache.clear()
	_idioma_de_antes = IdiomaMenu.indice()
	if _padroes.is_empty():
		var verbos := "(?:[Aa]perte|[Aa]perta|[Aa]pertar|[Tt]oque|[Tt]oca|[Pp]ulse|[Pp]ulsa|[Pp]ress|[Tt]ap|[Aa]bra|[Aa]bre|[Oo]pen|[Uu]se|[Uu]sa)"
		var artigo := "(?:\\s+(?:o|a|os|as|the|el|la|los|las))?"
		var solta := "(?<![\\w'’{:])([%s])(?![\\w'’}:])" % TROCAVEIS
		for expressao in [
			"\\b%s%s\\s+([%s])\\b" % [verbos, artigo, TROCAVEIS],          # aperte E · press J · abra o J · abre la J
			solta + "\\s+(?:abre|opens|serve|mostra)\\b",                  # o J abre · I opens · la K la abre
			"[\\[(]([%s])[\\])]" % TROCAVEIS,                              # [E] · (K)
			"\\b(?:o|a|the|el|la)\\s+([%s])(?:,|\\s+(?:na|en|on|ou|or|o)\\b)" % TROCAVEIS,   # o E, ou o J na aba de obras
			"\\(([%s])," % TROCAVEIS,                                      # (I, depois F)
		]:
			_padroes.append(RegEx.create_from_string(expressao))


func after_each() -> void:
	if Estado.perfil_descartavel():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Atalhos.ARQUIVO))
		Atalhos._cache.clear()
		Atalhos.aplicar()
		IdiomaMenu.definir(_idioma_de_antes)


func test_a_marca_se_resolve_na_letra_de_quem_joga() -> void:
	if not exige_perfil_descartavel():
		return
	# De fábrica.
	_conferir(Atalhos.resolver("Sem marca nenhuma.") == "Sem marca nenhuma.", "o texto sem marca devia voltar como veio")
	_conferir(Atalhos.resolver("") == "", "o texto vazio devia voltar vazio")
	_conferir(Atalhos.resolver("o {tecla:mochila} abre a mochila") == "o I abre a mochila", "de fábrica a mochila é o I: '%s'" % Atalhos.resolver("o {tecla:mochila} abre a mochila"))
	_conferir(Atalhos.resolver("[{tecla:interagir}] ou [{tecla:painel}] › Obras") == "[E] ou [J] › Obras", "duas marcas na mesma frase: '%s'" % Atalhos.resolver("[{tecla:interagir}] ou [{tecla:painel}] › Obras"))
	_conferir(Atalhos.resolver("{tecla:mapa}{tecla:camera}") == "MC", "duas marcas coladas: '%s'" % Atalhos.resolver("{tecla:mapa}{tecla:camera}"))
	# A que a tabela não conhece (e a que ficou sem fechar) fica como está: o portão de dados é quem a reprova.
	_conferir(Atalhos.resolver("a {tecla:inexistente} aqui") == "a {tecla:inexistente} aqui", "marca de ação desconhecida devia ficar")
	_conferir(Atalhos.resolver("aperte {tecla:mochila e pronto") == "aperte {tecla:mochila e pronto", "marca sem fechar devia ficar")
	_conferir(Atalhos.resolver("{tecla:inexistente} e {tecla:painel}") == "{tecla:inexistente} e J", "uma marca ruim não devia impedir a seguinte")
	# Na letra que o jogador escolheu: o perfil do autor, o mapa no I (a mochila herda o M).
	Atalhos.definir("mapa", KEY_I)
	_conferir(Atalhos.resolver("o {tecla:mochila} abre a mochila") == "o M abre a mochila", "com a mochila no M a fala devia dizer M: '%s'" % Atalhos.resolver("o {tecla:mochila} abre a mochila"))
	_conferir(Atalhos.resolver("o {tecla:mapa} abre o mapa") == "o I abre o mapa", "com o mapa no I a fala devia dizer I: '%s'" % Atalhos.resolver("o {tecla:mapa} abre o mapa"))
	Atalhos.definir("painel", KEY_Y)
	_conferir(Atalhos.resolver("[{tecla:painel}] › Obras") == "[Y] › Obras", "com o painel no Y: '%s'" % Atalhos.resolver("[{tecla:painel}] › Obras"))


func test_o_campo_do_idioma_resolve_a_marca_nos_tres_idiomas() -> void:
	if not exige_perfil_descartavel():
		return
	var dado := {"texto": "Aperte {tecla:painel} e veja.", "texto_en": "Press {tecla:painel} and see.", "texto_es": "Pulsa {tecla:painel} y mira.", "numero": 7, "lista": ["{tecla:painel}"]}
	var esperado := ["Aperte J e veja.", "Press J and see.", "Pulsa J y mira."]
	for idioma in 3:
		IdiomaMenu.definir(idioma)
		_conferir(str(IdiomaMenu.campo(dado, "texto")) == esperado[idioma], "no idioma %d o campo devia dizer '%s' e disse '%s'" % [idioma, esperado[idioma], str(IdiomaMenu.campo(dado, "texto"))])
	Atalhos.definir("painel", KEY_Y)
	IdiomaMenu.definir(1)
	_conferir(str(IdiomaMenu.campo(dado, "texto")) == "Press Y and see.", "com o painel no Y o campo devia dizer 'Press Y and see.' ('%s')" % str(IdiomaMenu.campo(dado, "texto")))
	# O que não é texto passa como veio, e a prévia de outro idioma (que não mexe em nada) não resolve.
	_conferir(IdiomaMenu.campo(dado, "numero") == 7, "o campo numérico foi mexido")
	_conferir(IdiomaMenu.campo(dado, "lista") == ["{tecla:painel}"], "a lista foi mexida")
	_conferir(str(IdiomaMenu.campo(dado, "sem_esse_campo", "padrão")) == "padrão", "o padrão não voltou")


## Todo texto de jogador das filas de missão: [{arquivo, onde, campo, texto}].
func _textos_das_missoes() -> Array[Dictionary]:
	var achados: Array[Dictionary] = []
	for nome in DirAccess.get_files_at("res://data"):
		if not (nome.begins_with("missoes_") and nome.ends_with(".json")):
			continue
		var dado = JSON.parse_string(FileAccess.get_file_as_string("res://data/" + nome))
		if not (dado is Dictionary):
			continue
		for local: String in ["passos", "socorro"]:
			var itens: Array = (dado as Dictionary).get(local, [])
			for i in itens.size():
				var passo = itens[i]
				if not (passo is Dictionary):
					continue
				var donos: Array = [["", passo]]
				if (passo as Dictionary).get("meta") is Dictionary:
					donos.append(["meta/", (passo as Dictionary)["meta"]])
				for par: Array in donos:
					for base: String in CAMPOS:
						for sufixo: String in SUFIXOS:
							var chave := base + sufixo
							var texto = (par[1] as Dictionary).get(chave)
							if texto is String and not (texto as String).is_empty():
								achados.append({"arquivo": nome, "onde": "%s[%d]/%s%s" % [local, i, par[0], chave], "campo": str(par[0]) + base, "sufixo": sufixo, "texto": texto})
	return achados


func test_toda_marca_dos_dados_e_boa_e_igual_nas_tres_linguas() -> void:
	var marca := RegEx.create_from_string("\\{tecla:([^}]*)\\}")
	var abre := RegEx.create_from_string("\\{tecla:")
	var vistas := 0
	var por_campo := {}
	for item in _textos_das_missoes():
		var texto: String = item["texto"]
		var rotulo := "%s, %s" % [item["arquivo"], item["onde"]]
		var citadas: Array[String] = []
		for achado in marca.search_all(texto):
			var acao := achado.get_string(1)
			citadas.append(acao)
			vistas += 1
			_conferir(Atalhos.DEFINICOES.has(acao), "%s: a marca {tecla:%s} nomeia uma ação que a tabela de atalhos não tem" % [rotulo, acao])
		_conferir(abre.search_all(texto).size() == citadas.size(), "%s: tem uma marca {tecla: sem fechar" % rotulo)
		citadas.sort()
		var chave := "%s|%s|%s" % [item["arquivo"], str(item["onde"]).get_slice("/", 0), item["campo"]]
		if not por_campo.has(chave):
			por_campo[chave] = {}
		por_campo[chave][item["sufixo"]] = citadas
	for chave: String in por_campo:
		var linguas: Dictionary = por_campo[chave]
		var primeira = linguas.get("", null)
		if primeira == null:
			continue
		for sufixo: String in linguas:
			_conferir(linguas[sufixo] == primeira, "%s: o texto%s cita as teclas %s, e o português, %s" % [chave, sufixo, str(linguas[sufixo]), str(primeira)])
	_conferir(vistas >= 60, "o varredor achou só %d marcas nas missões (a conversão deixou mais de 80): o teste não está olhando" % vistas)


func test_nenhuma_letra_trocavel_escrita_a_mao_nas_missoes() -> void:
	var a_mao := {}
	for item in _textos_das_missoes():
		var texto: String = item["texto"]
		# As marcas já resolvidas não contam: o que se procura é a letra solta no meio do texto.
		for padrao in _padroes:
			for achado in padrao.search_all(texto):
				var letra := achado.get_string(1)
				a_mao["%s|%s|%s" % [item["arquivo"], item["onde"], letra]] = texto.substr(maxi(achado.get_start() - 30, 0), 70).replace("\n", " ")
	for chave: String in a_mao:
		var partes := chave.split("|")
		var arquivo := partes[0]
		var letra := partes[2]
		var permitida: Dictionary = LETRA_A_MAO_PERMITIDA.get(arquivo, {})
		if permitida.has(letra):
			continue
		# O E fica fora da cadeia do Pedro: é a tecla do jogo todo, e a dica de cada alvo já a mostra na letra de quem joga.
		if letra == "E" and arquivo != A_CADEIA_DO_PEDRO:
			continue
		_conferir(false, "%s, %s: a tecla '%s' escrita à mão ('…%s…'): com ela trocada no AJUSTAR a fala mente — escreva {tecla:acao}" % [arquivo, partes[1], letra, a_mao[chave]])
	for arquivo: String in LETRA_A_MAO_PERMITIDA:
		for letra: String in LETRA_A_MAO_PERMITIDA[arquivo]:
			_conferir(str(LETRA_A_MAO_PERMITIDA[arquivo][letra]).length() > 20, "%s: o %s está permitido à mão sem razão escrita" % [arquivo, letra])
			var ainda_escreve := false
			for chave: String in a_mao:
				if chave.begins_with(arquivo + "|") and chave.ends_with("|" + letra):
					ainda_escreve = true
			_conferir(ainda_escreve, "%s não escreve mais o %s à mão: tire a linha da permissão" % [arquivo, letra])
