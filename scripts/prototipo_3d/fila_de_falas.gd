extends Node
## A FILA DE FALAS: UMA FALA DE CADA VEZ NO VALE.
##
## "As falas estão sendo sobrepostas, as falas precisam esperar umas as outras
## terminarem, entende?" (playtest da Build 9B, 06/10/2026)
##
##
## COMO ERA
##
## Cada boca decidia sozinha. O cumprimento perguntava a uma tabela de raio
## (`npc._falando`) se alguém falava a dezoito metros; a fala da missão segurava
## a palavra por quatro segundos e deixava o balão oito no ar, e o texto pedia
## onze para ser lido; a resposta do E não perguntava nada a ninguém; o anúncio
## do passo esperava seis segundos e falava POR CIMA de quem estivesse falando
## (`ESPERA_MAXIMA_PELA_VEZ`); a caixa de fala, a narração e a festa da missão
## não sabiam umas das outras. Duas vozes, dois balões, o texto de um cortado
## pelo do outro.
##
##
## COMO É
##
## Toda fala pede a vez aqui (`pedir`) e só uma está no ar. Ela segura a vez pelo
## tempo da voz ou de ler o texto — quinze letras por segundo, nunca menos que
## MINIMO —, o que for maior; a seguinte entra um RESPIRO depois. Quem pede:
##
##   o balão dos moradores e do Pedro — o cumprimento (`npc.saudar`), a conversa
##   do E (`conversar`), a fala da missão e a resposta de quem recebe (`narrar`);
##   a voz do mundo nos marcos (`voz_do_marco.gd`), que fala na caixa;
##   a narração do vale (`narracao_do_vale.gd`), o escuro com as frases;
##   a festa da missão cumprida (`conquista_da_missao.gd`).
##
## A caixa de fala longa (`dialogo_vale.gd`) é a única que não espera: ela para o
## vale inteiro, e enquanto está aberta a fala que estava no ar fica SUSPENSA — o
## balão some, a voz pausa, o tempo dela não corre — e volta quando a caixa
## fecha. O mesmo com qualquer tela que pause a árvore. Ela só espera a narração.
##
##
## QUEM PASSA NA FRENTE (`Classe`)
##
## Quem o jogador procurou com o E vem primeiro; depois a missão (o anúncio do
## passo, o arremate, a festa); depois a narração do mundo; e por último o
## cumprimento de quem passa, que NUNCA espera: sem a vez livre ele não sai (o
## morador tenta de novo no próximo encontro). A resposta do E também espera a
## vez — mas corta o cumprimento no ar, e a festa CEDE a ela: o emblema se
## recolhe enquanto a pessoa responde, e volta depois. Quem fala e é procurado
## (`no_lugar`) troca a própria fala pela resposta: não há duas bocas.
##
##
## O DESEMPATE
##
## Fala tem fim, então ninguém espera para sempre — salvo quem segura a vez sem
## largar (o portão simula isso com `_tomar_palavra` a cada quadro). Uma fala
## importante de OUTRA pessoa que espera ESPERA_MAXIMA, com a do ar há pelo menos
## metade disso, CORTA a do ar: o balão dela some e a voz cala. Corta, e não fala
## por cima — que era o defeito.
##
##
## SEM FILA NO VALE (um portão que monta uma peça só) cada boca fala na hora,
## como antes: quem pede pergunta `da(no)` e, sem resposta, segue sozinho. Este
## arquivo não cita autoload pelo nome (AGENTS.md: portão rodado com --script).

const GRUPO := "fila_de_falas"

## As classes, da que passa na frente para a que espera mais.
enum Classe { CONVERSA, MISSAO, NARRACAO, PASSAGEM }

## O TEMPO DE UMA FALA: o da voz ou o de ler, o que for maior.
const LETRAS_POR_SEGUNDO := 15.0
## Um ideograma (o texto em chinês) carrega o que umas duas letras e meia e se lê mais devagar: sem este peso, uma
## fala de 50 ideogramas ganhava 3,3 s e sumia do balão antes de o jogador lê-la.
const LETRAS_POR_IDEOGRAMA := 2.5
const MINIMO := 2.5
## Entre o fim de uma fala e o começo da seguinte.
const RESPIRO := 0.4
## Ver "O DESEMPATE", acima.
const ESPERA_MAXIMA := 16.0
## Um quadro que demorou mais que isto (a carga, um engasgo) não come a fala
## inteira: quem não viu o balão não o leu.
const QUADRO_MAXIMO := 1.0
const NA_FILA_NO_MAXIMO := 12
const HISTORICO_NO_MAXIMO := 240

## Uma fala ganhou a vez pela primeira vez, ou perdeu a vez de vez.
signal comecou(fala: Dictionary)
signal terminou(fala: Dictionary, cortada: bool)

## O PEDIDO, um Dictionary:
##   falante    quem fala (o morador, a voz do marco, a festa, a narração)
##   texto      o que se lê: dá o tempo e entra no histórico
##   classe     Classe (sem ela, MISSAO)
##   origem     de onde veio ("anuncio:<cadeia>:<passo>"): `calar(origem)` a retira,
##              e um pedido novo da mesma origem toma o lugar do antigo
##   segundos   quanto segura a vez; sem isto, a conta do texto
##   modal      segura a vez até `soltar(id)` (a narração, a festa, a caixa do marco)
##   caixa      é ela quem abre a caixa de fala: a caixa aberta não a suspende
##   cede       modal que cede a vez à conversa do E e à narração (a festa)
##   no_lugar   o mesmo falante no ar troca a fala dele por esta
##   agora      entra já, cortando a fala com tempo que estiver no ar
##   comecar    Callable(fala): ganhou a vez
##   parar      Callable(fala, cortada): perdeu a vez de vez
##   suspender  Callable(fala, sim): a caixa ou uma tela cobriu o vale (ou a festa cedeu)
##   tique      Callable(resta): a cada quadro, o tempo que falta
##   ao_comecar Callable(): quem pediu fica sabendo que começou
##   ao_terminar Callable(): quem pediu fica sabendo que acabou — de qualquer jeito:
##              dita, cortada, calada ou descartada antes de sair
var _atual: Dictionary = {}
var _fila: Array[Dictionary] = []
## Antes disto (ms), o respiro depois da última fala.
var _livre_em := 0
var _ultimo_ms := 0
var _serie := 0
## QUEM FALOU, DE QUANDO A QUANDO: um trecho por vez no ar (a festa que cede e
## volta tem dois). É o que o portão `falas_em_fila` confere: trechos não se
## sobrepõem.
var historico: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(GRUPO)
	_ultimo_ms = Time.get_ticks_msec()


## A fila do vale de `no`, ou null (portão sem vale).
static func da(no: Node) -> Node:
	if no == null or not is_instance_valid(no) or not no.is_inside_tree():
		return null
	return no.get_tree().get_first_node_in_group(GRUPO)


## Quanto uma fala segura a vez: a voz ou a leitura, nunca menos que MINIMO.
static func duracao(texto: String, voz: float = 0.0) -> float:
	return maxf(maxf(voz, tempo_de_leitura(texto)), MINIMO)


## O tempo de ler o texto: letras por segundo, com cada ideograma (U+4E00 a U+9FFF) valendo `LETRAS_POR_IDEOGRAMA`.
static func tempo_de_leitura(texto: String) -> float:
	var limpo := texto.strip_edges()
	var letras := 0.0
	for i in limpo.length():
		var c := limpo.unicode_at(i)
		letras += LETRAS_POR_IDEOGRAMA if c >= 0x4E00 and c <= 0x9FFF else 1.0
	return letras / LETRAS_POR_SEGUNDO


## PEDE A VEZ. Devolve o id do pedido, ou 0 quando o cumprimento foi descartado.
func pedir(fala: Dictionary) -> int:
	_serie += 1
	fala["id"] = _serie
	fala["pedido_ms"] = Time.get_ticks_msec()
	fala["esperou"] = 0.0
	if not fala.has("classe"):
		fala["classe"] = Classe.MISSAO
	if not bool(fala.get("modal", false)) and not fala.has("segundos"):
		fala["segundos"] = duracao(str(fala.get("texto", "")))
	var classe := int(fala["classe"])
	var agora := bool(fala.get("agora", false))
	# O CUMPRIMENTO DE QUEM PASSA NÃO ESPERA: sem a vez livre, não sai.
	if classe == Classe.PASSAGEM and not agora and not livre():
		_avisar_fim(fala)
		return 0
	# O mesmo pedido de novo toma o lugar do antigo, que ainda não saiu.
	_tirar_da_fila(func(outra: Dictionary) -> bool: return _mesmo_pedido(outra, fala))
	if _entra_ja(fala):
		_comecar(fala)
	else:
		_enfileirar(fala, agora)
		_tentar_comecar()
	return int(fala["id"])


## A VEZ ESTÁ LIVRE: ninguém no ar, ninguém esperando, o respiro passou, e
## nenhuma caixa ou tela parando o vale. É a pergunta do cumprimento.
func livre() -> bool:
	return _atual.is_empty() and _fila.is_empty() and not _bloqueada() \
		and Time.get_ticks_msec() >= _livre_em


## O que está no ar agora, ou {}.
func atual() -> Dictionary:
	return _atual


## `falante` está com a vez?
func falando(falante: Object) -> bool:
	return not _atual.is_empty() and _atual.get("falante") == falante


## `falante` tem fala esperando a vez?
func pendente(falante: Object) -> bool:
	for fala in _fila:
		if fala.get("falante") == falante:
			return true
	return false


## Quantas esperam.
func esperando() -> int:
	return _fila.size()


## ALGUÉM ALÉM DE `falante` ESTÁ NO AR perto de `ponto`? Quem não tem corpo no
## mundo (a festa, a narração, a voz do marco) está na tela, e conta sempre.
func alguem_alem_de(falante: Object, ponto: Vector3, raio: float) -> bool:
	if _atual.is_empty() or _atual.get("falante") == falante:
		return false
	var quem = _atual.get("falante")
	if quem is Node3D and is_instance_valid(quem):
		return (quem as Node3D).global_position.distance_to(ponto) < raio
	return true


## A CAIXA DE FALA ESPERA a narração: as duas cobrem a tela inteira.
func segura_a_caixa() -> bool:
	return not _atual.is_empty() and int(_atual["classe"]) == Classe.NARRACAO \
		and bool(_atual.get("modal", false))


## PASSA A FALA DO AR — o E em quem está falando, de quem já leu; e o portão,
## que lê depressa. Só a fala com tempo: a narração e a festa têm a tecla delas.
func pular() -> bool:
	if _atual.is_empty() or bool(_atual.get("modal", false)):
		return false
	_encerrar_atual(true)
	_tentar_comecar()
	return true


## O SEGUNDO E: quem já tinha a resposta na fila passa na frente, e a fala com
## tempo que estiver no ar é cortada. Devolve se havia o que apressar.
func apressar(falante: Object) -> bool:
	var achada := -1
	for i in _fila.size():
		if _fila[i].get("falante") == falante and not bool(_fila[i].get("modal", false)):
			achada = i
			break
	if achada < 0:
		return false
	var fala: Dictionary = _fila[achada]
	_fila.remove_at(achada)
	if not _atual.is_empty():
		if bool(_atual.get("modal", false)):
			if not bool(_atual.get("cede", false)):
				_fila.insert(0, fala)
				return true
			_ceder_atual()
		else:
			_encerrar_atual(true)
	if _bloqueada():
		_fila.insert(0, fala)
	else:
		_comecar(fala)
	return true


## Estica a fala de `falante` no ar para durar pelo menos `segundos` daqui.
func estender(falante: Object, segundos: float) -> void:
	if falando(falante) and not bool(_atual.get("modal", false)):
		_atual["resta"] = maxf(float(_atual.get("resta", 0.0)), segundos)


## CALA O QUE VEIO DE `origem`: o anúncio de um passo que já fechou não tem mais o
## que dizer. A que espera sai da fila; a que está no ar é cortada.
func calar(origem: String) -> void:
	if origem == "":
		return
	_tirar_da_fila(func(fala: Dictionary) -> bool:
		return str(fala.get("origem", "")) == origem and not bool(fala.get("modal", false)))
	if not _atual.is_empty() and str(_atual.get("origem", "")) == origem and not bool(_atual.get("modal", false)):
		_encerrar_atual(true)
		_tentar_comecar()


## Cala tudo de `falante`: ele saiu do vale, ou entrou em casa.
func calar_falante(falante: Object) -> void:
	_tirar_da_fila(func(fala: Dictionary) -> bool: return fala.get("falante") == falante)
	if falando(falante):
		_encerrar_atual(true)
		_tentar_comecar()


## A FALA MODAL `id` ACABOU (a narração, a festa, a caixa do marco).
func soltar(id: int) -> void:
	if not _atual.is_empty() and int(_atual.get("id", 0)) == id:
		_encerrar_atual(false)
		_tentar_comecar()
		return
	_tirar_da_fila(func(fala: Dictionary) -> bool: return int(fala.get("id", 0)) == id)


func _process(_delta: float) -> void:
	var agora := Time.get_ticks_msec()
	var dt := clampf((agora - _ultimo_ms) / 1000.0, 0.0, QUADRO_MAXIMO)
	_ultimo_ms = agora
	var bloqueada := _bloqueada()
	if not _atual.is_empty():
		var quem = _atual.get("falante")
		if quem != null and not is_instance_valid(quem):
			_encerrar_atual(true)
		else:
			# A CAIXA ABERTA, OU UMA TELA PARANDO O VALE: a fala fica suspensa no lugar.
			var suspensa := bloqueada and not bool(_atual.get("caixa", false))
			if suspensa != bool(_atual.get("suspensa", false)):
				_atual["suspensa"] = suspensa
				_chamar(_atual, "suspender", [_atual, suspensa])
			if not suspensa:
				_atual["no_ar"] = float(_atual.get("no_ar", 0.0)) + dt
				if not bool(_atual.get("modal", false)):
					_atual["resta"] = float(_atual.get("resta", 0.0)) - dt
					_chamar(_atual, "tique", [maxf(float(_atual["resta"]), 0.0)])
					if float(_atual["resta"]) <= 0.0:
						_encerrar_atual(false)
	if bloqueada or _fila.is_empty():
		return
	_tirar_da_fila(func(fala: Dictionary) -> bool:
		var quem = fala.get("falante")
		return quem != null and not is_instance_valid(quem))
	for fala in _fila:
		fala["esperou"] = float(fala.get("esperou", 0.0)) + dt
	_desempatar()
	_tentar_comecar()


## A caixa de fala aberta, ou a árvore parada (tela, menu, a caixa também).
func _bloqueada() -> bool:
	if not is_inside_tree():
		return true
	if get_tree().paused:
		return true
	var dialogo := get_node_or_null("/root/Dialogo")
	return dialogo != null and bool(dialogo.get("ativo"))


## ESTA ENTRA JÁ? Se ninguém que ainda não começou espera na frente dela; com a
## vez livre, quando o respiro passou (para quem respira); com alguém no ar, só
## quando passa na frente dele — e então ele já saiu do ar.
func _entra_ja(fala: Dictionary) -> bool:
	if _bloqueada():
		return false
	var agora := bool(fala.get("agora", false))
	var antes := _primeira_por_comecar(fala)
	if not agora and not antes.is_empty() and _vem_antes(antes, fala):
		return false
	if _atual.is_empty():
		return agora or int(fala["classe"]) == Classe.CONVERSA or Time.get_ticks_msec() >= _livre_em
	if not _passa_na_frente(fala):
		return false
	_tirar_do_ar()
	return true


## `fala` PASSA NA FRENTE DE QUEM ESTÁ NO AR? O "agora" corta a fala com tempo; o
## mesmo falante troca a própria fala (`no_lugar`); a conversa do E e a narração
## cortam o cumprimento de quem passa e fazem a festa ceder. Só pergunta.
func _passa_na_frente(fala: Dictionary) -> bool:
	if _atual.is_empty():
		return true
	var modal := bool(_atual.get("modal", false))
	if bool(fala.get("agora", false)) and not modal:
		return true
	if bool(fala.get("no_lugar", false)) and not modal and _atual.get("falante") == fala.get("falante"):
		return true
	var classe := int(fala["classe"])
	if classe == Classe.CONVERSA or classe == Classe.NARRACAO:
		if not modal and int(_atual["classe"]) == Classe.PASSAGEM:
			return true
		if modal and bool(_atual.get("cede", false)):
			return true
	return false


## Tira do ar quem está nele, para outra passar na frente: a modal que cede volta
## para a fila (`_ceder_atual`); a fala com tempo é cortada.
func _tirar_do_ar() -> void:
	if _atual.is_empty():
		return
	if bool(_atual.get("modal", false)):
		_ceder_atual()
	else:
		_encerrar_atual(true)


## A primeira da fila que ESPERA NA FRENTE DE `nova`: não conta a festa que já
## começou e cedeu a vez, nem a que ainda espera e cederia a vez a ela.
func _primeira_por_comecar(nova: Dictionary) -> Dictionary:
	for fala in _fila:
		if not _cede_para(fala, nova):
			return fala
	return {}


## `antes`, na fila, deixa `fala` passar? A que já começou e cedeu a vez (a festa
## recolhida) volta quando a vez voltar; a modal que cede (a festa que espera)
## deixa passar a conversa do E e a narração.
static func _cede_para(antes: Dictionary, fala: Dictionary) -> bool:
	if bool(antes.get("iniciada", false)):
		return true
	var classe := int(fala["classe"])
	return bool(antes.get("modal", false)) and bool(antes.get("cede", false)) \
		and (classe == Classe.CONVERSA or classe == Classe.NARRACAO)


## `a` sai antes de `b`? Classe mais importante, ou a mesma e pedida antes.
static func _vem_antes(a: Dictionary, b: Dictionary) -> bool:
	return int(a["classe"]) <= int(b["classe"])


func _enfileirar(fala: Dictionary, na_frente := false) -> void:
	# Depois de quem é tão ou mais importante e não lhe cede a vez; na frente de
	# quem é menos importante, e da festa que espera e cederia a vez a ela (a
	# narração não espera a festa para depois a festa ceder). `na_frente`: a festa
	# que cedeu volta na frente da classe dela.
	var onde := 0
	for i in _fila.size():
		var outra := _fila[i]
		if int(outra["classe"]) > int(fala["classe"]):
			break
		if na_frente and int(outra["classe"]) == int(fala["classe"]):
			break
		var cede_a_ela := bool(outra.get("modal", false)) and bool(outra.get("cede", false)) \
			and (int(fala["classe"]) == Classe.CONVERSA or int(fala["classe"]) == Classe.NARRACAO)
		if not na_frente and cede_a_ela:
			continue
		onde = i + 1
	if bool(fala.get("agora", false)):
		onde = 0
	_fila.insert(onde, fala)
	while _fila.size() > NA_FILA_NO_MAXIMO:
		# A fila cheia larga a menos importante, a mais nova — nunca uma modal,
		# que alguém está esperando.
		var largar := -1
		for i in range(_fila.size() - 1, -1, -1):
			if not bool(_fila[i].get("modal", false)):
				largar = i
				break
		if largar < 0:
			break
		var largada: Dictionary = _fila[largar]
		_fila.remove_at(largar)
		_avisar_fim(largada)


func _tentar_comecar() -> void:
	if _fila.is_empty() or _bloqueada():
		return
	var primeira: Dictionary = _fila[0]
	if not _atual.is_empty():
		# QUEM ENTROU NA FILA COM O VALE PARADO (a caixa aberta, uma tela) e passa
		# na frente de quem está no ar — a conversa do E, a narração — passa agora
		# que o vale voltou: a festa cede, o cumprimento é cortado.
		if bool(primeira.get("iniciada", false)) or not _passa_na_frente(primeira):
			return
		_fila.pop_front()
		_tirar_do_ar()
		_comecar(primeira)
		return
	var respira := int(primeira["classe"]) != Classe.CONVERSA and not bool(primeira.get("iniciada", false)) \
		and not bool(primeira.get("agora", false))
	if respira and Time.get_ticks_msec() < _livre_em:
		return
	_fila.pop_front()
	_comecar(primeira)


func _comecar(fala: Dictionary) -> void:
	_atual = fala
	fala["suspensa"] = false
	var agora := Time.get_ticks_msec()
	_abrir_trecho(fala, agora)
	if bool(fala.get("iniciada", false)):
		# A FESTA QUE CEDEU A VEZ VOLTA de onde estava.
		_chamar(fala, "suspender", [fala, false])
		return
	fala["iniciada"] = true
	fala["inicio_ms"] = agora
	fala["no_ar"] = 0.0
	if not bool(fala.get("modal", false)):
		fala["resta"] = float(fala.get("segundos", MINIMO))
	_chamar(fala, "comecar", [fala])
	_chamar(fala, "ao_comecar", [])
	comecou.emit(fala)


## A fala do ar perde a vez de vez: dita até o fim, ou cortada.
func _encerrar_atual(cortada: bool) -> void:
	if _atual.is_empty():
		return
	var fala := _atual
	_atual = {}
	var agora := Time.get_ticks_msec()
	_fechar_trecho(fala, agora, cortada)
	fala["fim_ms"] = agora
	_chamar(fala, "parar", [fala, cortada])
	_avisar_fim(fala)
	terminou.emit(fala, cortada)
	if not cortada:
		_livre_em = agora + int(RESPIRO * 1000.0)


## A MODAL QUE CEDE (a festa) recolhe-se e volta para a fila, na frente da classe
## dela: quando a vez voltar, ela continua de onde estava.
func _ceder_atual() -> void:
	var fala := _atual
	_atual = {}
	_fechar_trecho(fala, Time.get_ticks_msec(), false)
	fala["suspensa"] = true
	_chamar(fala, "suspender", [fala, true])
	_enfileirar(fala, true)


## UMA FALA IMPORTANTE DE OUTRA PESSOA ESPEROU DEMAIS: a do ar é cortada.
func _desempatar() -> void:
	if _atual.is_empty() or bool(_atual.get("modal", false)):
		return
	if float(_atual.get("no_ar", 0.0)) < ESPERA_MAXIMA * 0.5:
		return
	for fala in _fila:
		if bool(fala.get("modal", false)) or int(fala["classe"]) > Classe.MISSAO:
			continue
		if fala.get("falante") == _atual.get("falante"):
			continue
		if float(fala.get("esperou", 0.0)) >= ESPERA_MAXIMA:
			_encerrar_atual(true)
			return


func _tirar_da_fila(criterio: Callable) -> void:
	var i := 0
	while i < _fila.size():
		if bool(criterio.call(_fila[i])):
			var tirada: Dictionary = _fila[i]
			_fila.remove_at(i)
			if bool(tirada.get("iniciada", false)):
				# A festa que tinha cedido e sai sem voltar ainda precisa encerrar.
				_chamar(tirada, "parar", [tirada, true])
			_avisar_fim(tirada)
		else:
			i += 1


static func _mesmo_pedido(antiga: Dictionary, nova: Dictionary) -> bool:
	if bool(antiga.get("modal", false)) or bool(antiga.get("iniciada", false)):
		return false
	var origem := str(nova.get("origem", ""))
	if origem != "" and str(antiga.get("origem", "")) == origem:
		return true
	# O E repetido no mesmo morador não enfileira duas conversas.
	return antiga.get("falante") == nova.get("falante") and nova.get("falante") != null \
		and int(antiga["classe"]) == Classe.CONVERSA and int(nova["classe"]) == Classe.CONVERSA


func _avisar_fim(fala: Dictionary) -> void:
	if bool(fala.get("_avisada", false)):
		return
	fala["_avisada"] = true
	_chamar(fala, "ao_terminar", [])


func _chamar(fala: Dictionary, chave: String, argumentos: Array) -> void:
	var chamada = fala.get(chave)
	if chamada is Callable and (chamada as Callable).is_valid():
		(chamada as Callable).callv(argumentos)


func _abrir_trecho(fala: Dictionary, agora: int) -> void:
	var quem = fala.get("falante")
	historico.append({
		"id": int(fala["id"]),
		"falante": str(quem.name) if quem is Node and is_instance_valid(quem) else "",
		"classe": int(fala["classe"]),
		"origem": str(fala.get("origem", "")),
		"texto": str(fala.get("texto", "")).left(60),
		"inicio_ms": agora,
		"fim_ms": -1,
		"cortada": false,
	})
	while historico.size() > HISTORICO_NO_MAXIMO:
		historico.pop_front()


func _fechar_trecho(fala: Dictionary, agora: int, cortada: bool) -> void:
	for i in range(historico.size() - 1, -1, -1):
		var trecho := historico[i]
		if int(trecho["id"]) == int(fala["id"]) and int(trecho["fim_ms"]) < 0:
			trecho["fim_ms"] = agora
			trecho["cortada"] = cortada
			return
