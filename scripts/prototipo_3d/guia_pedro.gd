class_name GuiaPedro
extends MoradorNPC
## Pedro, o pescador que conduz o tutorial: acompanha o jogador de perto e narra a
## chegada — os pedidos do Tonho, da Candinha e da Dona Zefa, o fogo da casa do
## finado, o mutirão do poço, a primeira janta e a primeira noite, a leira e o
## convite (docs/mundo/CHEGADA_E_MUTIROES.md) —, com voz do ElevenLabs onde há.
## Ao entardecer avisa que vai escurecer.
##
##
## A FILA DE MISSÕES NÃO MORA MAIS AQUI.
##
## Ela morava, e isso fazia do Pedro o único morador do vale capaz de dar
## missão. O jogo 2D não é assim: lá a Dona Zefa manda um recado, o Damião
## pede um cabo de foice, o Tonho cobra uma dívida. Trazer a segunda cadeia
## copiando este arquivo seria ter duas cópias das mesmas regras, e duas
## cópias de uma regra divergem — uma ganha o conserto e a outra não.
##
## As regras foram para `cadeia_de_missoes.gd`, e o Pedro virou o primeiro
## freguês delas. O que continua sendo dele está tudo aqui: seguir o jogador
## de perto, correr quando fica para trás, avisar que vai escurecer, e a voz.
##
## Os nomes antigos — `MISSOES`, `missao`, `_espera` — continuam existindo
## como janelas para dentro da cadeia. Não é cortesia: o save do vale guarda
## `pedro.missao` e o portão `tests/cadeia_das_missoes.gd` lê `pedro.MISSOES`,
## e trocar os dois de nome no mesmo commit em que a regra muda de casa é
## misturar duas mudanças num diff só.

signal missao_mudou(texto: String, alvo: Vector3, indice: int, total: int)
signal narrou(texto: String)
## A RECOMPENSA DE UM PASSO DA CHEGADA, já dita ("Recebido de Tonho: 1 peixe").
## A chegada antiga não pagava nada, e por isso este sinal não existia.
signal pagou(texto: String)

const CadeiaDeMissoes = preload("res://scripts/prototipo_3d/cadeia_de_missoes.gd")
const ARQUIVO_MISSOES := "res://data/missoes_guia.json"

const SEGUIR_MAX := 4.6
const CORRER_ALEM := 9.5
const ANDAR := 2.1
const CORRER := 5.2
## OS CÔMODOS EM QUE ELE NÃO ENTRA: a casa herdada é de quatro por quatro, e a
## quatro passos e meio do jogador o lugar dele era o vão da porta — o jogador
## entrou para dormir e não saiu mais. Ali ele espera do lado de fora, de lado
## para a porta (`Comodo.lugar_de_esperar_fora`). Na igreja, que é larga, ele
## entra junto.
const ESPERA_FORA := ["casa"]

## O PEDRO VAI NA FRENTE. "O Pedro deve conduzir o jogador até a casa dele. [...]
## no inicio sempre é o Pedro que conduz e orienta, temos que partir do
## principio que o jogador não conhece o lugar e nenhum NPC, ou seja, o Pedro
## que vai apresentar." No passo com `conduz` ele anda pela malha até quem o
## passo apresenta (ou até o lugar dele) e para a CONDUZ_ATE dele; o jogador vai
## atrás. Ficando o jogador a mais de ESPERA_QUEM_FICA, ele para e espera,
## virado para ele, e só volta a andar com o jogador a VOLTA_A_ANDAR. Anda no
## passo do jogador: correndo se ele corre.
const CONDUZ_ATE := 2.4
const ESPERA_QUEM_FICA := 6.5
const VOLTA_A_ANDAR := 4.0
## E NO PASSO COM `fica` — o desembarque e a primeira corrida — ele fica onde
## está, na ponta da prancha, olhando o jogador.

## O CORPO, EXPLICADO UMA VEZ. "Durante esse processo, o jogador vai ficar
## cansado pela baixa do vigor e o Pedro deve introduzir o que é o vigor, o que
## é a stamina e o que é a vida." Na caminhada em que ele conduz (os passos com
## `conduz`), na primeira vez que o vigor baixa de LIMIAR_DO_CORPO, o Pedro
## explica as três barras na caixa de fala longa, que segura o vale até o
## jogador ler (as falas são o `corpo` do `missoes_guia.json`). Quem chega à
## porta da casa (PASSO_DA_PORTA) sem ter cansado ouve a mesma explicação lá,
## com a última fala no tempo de quem ainda não sentiu. Uma vez por partida: a
## lembrança vai no save, com as da cadeia (`lembrancas`).
const LIMIAR_DO_CORPO := 0.3
const LEMBRANCA_DO_CORPO := "explicou:corpo"
const PASSO_DA_PORTA := "casa"
const PASSO_DO_BAU := "pegar"
## Mais que ESPERA_QUEM_FICA: quem cansou e parou fica a essa distância dele.
const PERTO_PARA_EXPLICAR := 8.0

## Criada no `_init`, e não no `_ready`, de propósito: o `Prototype` escreve
## `pedro.recursos` e o save escreve `pedro.missao`, e propriedade que cai no
## vazio porque a cadeia ainda não existe é defeito calado.
var _cadeia := CadeiaDeMissoes.new()
var _anoiteceu_hoje := false
## As falas do corpo (`corpo` no `missoes_guia.json`), lidas no `_init`.
var _corpo: Array = []
## Parado à espera do jogador que ficou para trás na condução.
var _esperando_quem_ficou := false
## O jogador cansou na caminhada e ainda não ouviu a explicação. Guardado
## porque o vigor volta depressa — parado, 20 por segundo —, e a fala pode
## estar ocupada no instante em que ele cai.
var _cansou_na_caminhada := false


## --- as janelas para dentro da cadeia -------------------------------------

var MISSOES: Array:
	get: return _cadeia.passos

var missao: int:
	get: return _cadeia.missao
	set(valor): _cadeia.missao = valor

var recursos: Node:
	get: return _cadeia.recursos
	set(valor): _cadeia.recursos = valor

var _iniciado: bool:
	get: return _cadeia.iniciado
	set(valor): _cadeia.iniciado = valor

var _espera: float:
	get: return _cadeia.espera
	set(valor): _cadeia.espera = valor

var _despedida_feita: bool:
	get: return _cadeia.despedida_feita
	set(valor): _cadeia.despedida_feita = valor


func _init() -> void:
	_cadeia.name = "CadeiaDeMissoes"
	_cadeia.dono = self
	_cadeia.carregar(ARQUIVO_MISSOES)
	var lido = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO_MISSOES))
	if lido is Dictionary and lido.get("corpo", []) is Array:
		_corpo = lido.get("corpo", [])


func _ready() -> void:
	super()
	intervalo_saudacao_ms = 1 << 30
	_cadeia.jogador = jogador
	_cadeia.missao_mudou.connect(
		func(texto: String, alvo: Vector3, indice: int, total: int) -> void:
			missao_mudou.emit(texto, alvo, indice, total))
	_cadeia.pagou.connect(func(texto: String) -> void: pagou.emit(texto))
	add_child(_cadeia)


## O TUTORIAL ACABOU — as nove primeiras missões e a despedida —, e o Pedro
## para de seguir: volta à vida de pescador, nos postos dele (`npcs_3d.json`,
## "guia"), e quem quer falar com ele vai até ele. As missões do arraial abrem
## assim, chegando perto dele (`prototype._pendurar_cadeia`, 6 de raio).
func terminou_o_tutorial() -> bool:
	return _cadeia.acabou() and _cadeia.despedida_feita


## O passo de id `id` da chegada já fechou? A roça do Cosme abre depois da
## primeira leira (`roca`).
func passou(id: String) -> bool:
	return _cadeia.passou(id)


## O passo em curso o segura parado (`fica`)? É o desembarque: a carga de uma
## partida salva no convés o devolve à ponta da prancha, e não ao lado do jogador.
func fica_no_passo() -> bool:
	return _cadeia.iniciado and bool(_cadeia.passo_atual().get("fica", false))


## O id do passo em curso, ou "" — é o que vai no save, para a partida voltar ao
## MESMO passo mesmo que a lista mude (ver `ir_ao_passo`).
func passo_em_curso() -> String:
	return str(_cadeia.passo_atual().get("id", ""))


## Põe a chegada no passo de id `id`. Devolve false se a lista não o tem.
func ir_ao_passo(id: String) -> bool:
	for i in _cadeia.passos.size():
		if str((_cadeia.passos[i] as Dictionary).get("id", "")) == id:
			_cadeia.missao = i
			return true
	return false


## UM ACONTECIMENTO DO VALE (`CadeiaDeMissoes.registrar_evento`): a chegada
## espera a janta, a cama, a leira e a leitura do convite.
func registrar_evento(nome: String) -> void:
	_cadeia.registrar_evento(nome)


## QUEM É O MORADOR DE TAL ID, respondido pelo vale — a chegada agora fala com
## o Tonho, a Candinha e a Dona Zefa, e chama o Cosme ao mutirão do poço.
func ligar_moradores(achar: Callable) -> void:
	_cadeia.achar_morador = achar


## A MEMÓRIA DA CHEGADA (encontros, acontecimentos, mutirão), para o save: sem
## ela, salvar no meio da primeira leira esqueceria que a terra já foi arada.
func lembrancas() -> Array:
	return _cadeia._levados.keys()


func lembrar(chaves: Array) -> void:
	_cadeia._levados.clear()
	for chave in chaves:
		_cadeia._levados[str(chave)] = true


func _physics_process(delta: float) -> void:
	if jogador == null:
		return
	# A cadeia recebe o jogador aqui também: no `_ready` ele pode ainda não
	# estar de pé, e ela não anda sem saber de quem se aproximar.
	if _cadeia.jogador == null:
		_cadeia.jogador = jogador
	if terminou_o_tutorial():
		# DEPOIS DO TUTORIAL ELE AINDA CONDUZ quando uma fila dele pede: a jornada da
		# fazenda, em que ele leva o jogador pela ponte até o portão, como no 2D.
		var conduzindo := _outra_que_conduz()
		if conduzindo != null:
			_conduzir(delta, conduzindo)
			_atualizar_animacao(delta)
			_atualizar_interacao(delta)
			return
		super(delta)
		return
	if _andar_dando_passagem(delta):
		_atualizar_animacao(delta)
		_atualizar_interacao(delta)
		return
	_ver_se_explica_o_corpo()
	# NA CHEGADA ELE VAI NA FRENTE, ou fica na ponta da prancha (ver CONDUZ_ATE).
	var passo := _cadeia.passo_atual() if _cadeia.iniciado else {}
	if bool(passo.get("fica", false)):
		_mover(Vector3.ZERO, ANDAR, delta)
		_olhar_para(jogador.global_position, delta)
		_atualizar_animacao(delta)
		_atualizar_interacao(delta)
		_verificar_anoitecer()
		return
	if bool(passo.get("conduz", false)):
		_conduzir(delta)
		_atualizar_animacao(delta)
		_atualizar_interacao(delta)
		_verificar_anoitecer()
		return
	# O PEDRO ENTRA JUNTO. Com o jogador dentro da igreja e ele fora (ou o
	# contrário), seguir em linha reta era empurrar a parede: o caminho passa
	# pela porta, ponto a ponto (`Interiores.passagem`), e só depois volta a
	# ser o jogador. Ponto de passagem se alcança de perto; o jogador, não.
	var onde_esta: Vector3 = jogador.global_position
	var alvo := onde_esta
	var basta := SEGUIR_MAX
	var interiores := get_tree().get_first_node_in_group("interiores")
	if interiores != null:
		var sala_do_jogador: String = interiores.contem(onde_esta)
		if sala_do_jogador in ESPERA_FORA:
			# Na casa ele não entra: espera de lado para a porta, do lado de fora
			# — e, se já estava dentro, sai pela porta primeiro.
			var sala = interiores.sala_de(sala_do_jogador)
			var espera: Vector3 = sala.lugar_de_esperar_fora()
			if terreno != null:
				espera = terreno.ground_position(espera, 0.05)
			alvo = interiores.passagem(global_position, espera)
			basta = 0.35
		else:
			alvo = interiores.passagem(global_position, onde_esta)
			if not alvo.is_equal_approx(onde_esta):
				basta = 0.35
	var para_jogador := alvo - global_position
	para_jogador.y = 0.0
	var distancia := para_jogador.length()
	var direcao := Vector3.ZERO
	var velocidade := ANDAR
	if distancia > basta:
		direcao = para_jogador / distancia
		velocidade = CORRER if (onde_esta - global_position).length() > CORRER_ALEM else ANDAR
	_mover(direcao, velocidade, delta)
	if direcao == Vector3.ZERO:
		_olhar_para(onde_esta, delta)
	_atualizar_animacao(delta)
	_atualizar_interacao(delta)
	_verificar_anoitecer()


## UM PULSO DA CONDUÇÃO (ver CONDUZ_ATE): pela malha até o destino do passo, no
## passo do jogador; parado, virado para ele, quando chegou ou quando ele ficou
## para trás.
func _conduzir(delta: float, cadeia: Node = null) -> void:
	var destino := _destino_da_conducao(cadeia)
	var onde_esta: Vector3 = jogador.global_position
	var do_jogador := Vector2(onde_esta.x - global_position.x, onde_esta.z - global_position.z).length()
	if _esperando_quem_ficou:
		_esperando_quem_ficou = do_jogador > VOLTA_A_ANDAR
	elif do_jogador > ESPERA_QUEM_FICA:
		_esperando_quem_ficou = true
	var falta := destino - global_position
	falta.y = 0.0
	if _esperando_quem_ficou or falta.length() <= CONDUZ_ATE:
		_mover(Vector3.ZERO, ANDAR, delta)
		_olhar_para(onde_esta, delta)
		return
	var ponto := _ponto_do_caminho(destino, delta)
	var rumo := ponto - global_position
	rumo.y = 0.0
	var correndo := jogador.has_method("is_running") and bool(jogador.call("is_running"))
	_mover(rumo.normalized() if rumo.length() > 0.05 else Vector3.ZERO, CORRER if correndo else ANDAR, delta)


## PARA ONDE ELE CONDUZ: quem o passo apresenta, ou o lugar do passo — e, sendo
## o lugar um cômodo em que ele não entra (a casa herdada), a porta dela, do
## lado de fora.
func _destino_da_conducao(cadeia: Node = null) -> Vector3:
	var quem: Node = cadeia if cadeia != null else _cadeia
	var destino: Vector3 = quem.posicao_do_passo(quem.missao)
	var interiores := get_tree().get_first_node_in_group("interiores")
	if interiores != null:
		var sala_do_destino: String = interiores.contem(destino)
		if sala_do_destino in ESPERA_FORA:
			var espera: Vector3 = interiores.sala_de(sala_do_destino).lugar_de_esperar_fora()
			return terreno.ground_position(espera, 0.05) if terreno != null else espera
	return destino


func _chegou_ao_destino() -> bool:
	var falta := _destino_da_conducao() - global_position
	falta.y = 0.0
	return falta.length() <= CONDUZ_ATE + 0.5


## A OUTRA FILA DELE QUE CONDUZ AGORA, além da chegada: a primeira, entre as
## penduradas nele, cujo passo em curso tem `conduz`. Ou null.
func _outra_que_conduz() -> Node:
	for filho in get_children():
		if filho == _cadeia or not filho.has_method("passo_atual"):
			continue
		if filho.iniciado and not filho.acabou() and bool(filho.passo_atual().get("conduz", false)):
			return filho
	return null


## O vigor do jogador, de 0 a 1 (ver `player_controller.vigor_atual`).
func _fracao_do_vigor() -> float:
	if jogador == null or not jogador.has_method("vigor_atual"):
		return 1.0
	return float(jogador.call("vigor_atual")) / maxf(float(jogador.call("vigor_maximo")), 1.0)


## A HORA DE EXPLICAR O CORPO (ver LIMIAR_DO_CORPO): cansado na caminhada, ou
## na porta da casa sem ter cansado. Só com a palavra livre e o jogador perto.
func _ver_se_explica_o_corpo() -> void:
	if _corpo.is_empty() or not _cadeia.iniciado or bool(_cadeia._levados.get(LEMBRANCA_DO_CORPO, false)):
		return
	var passo := _cadeia.passo_atual()
	# SÓ NA CONDUÇÃO, com ele andando junto. No desembarque ele fica na prancha,
	# e quem corre para o mar e volta cansado não está na caminhada com ele.
	if bool(passo.get("conduz", false)) and _fracao_do_vigor() <= LIMIAR_DO_CORPO:
		_cansou_na_caminhada = true
	if Dialogo.ocupado() or not _palavra_livre():
		return
	if jogador.global_position.distance_to(global_position) > PERTO_PARA_EXPLICAR:
		return
	# Na porta, ou já com o jogador lá dentro, no passo do baú. Depois dele, não:
	# quem passou da casa sem ouvir é partida de antes desta chegada.
	var id := str(passo.get("id", ""))
	var na_porta := (id == PASSO_DA_PORTA and _chegou_ao_destino()) or id == PASSO_DO_BAU
	if _cansou_na_caminhada or na_porta:
		explicar_o_corpo(_cansou_na_caminhada)


## As três barras na caixa de fala longa; a última fala muda com o cansaço.
func explicar_o_corpo(cansado: bool) -> void:
	_cadeia._levados[LEMBRANCA_DO_CORPO] = true
	var linhas: Array = []
	for fala in _corpo:
		if not (fala is Dictionary):
			continue
		var quando := str((fala as Dictionary).get("quando", ""))
		if quando != "" and quando != ("cansado" if cansado else "descansado"):
			continue
		linhas.append(str(IdiomaMenu.campo(fala, "texto", "")))
	Dialogo.falar(str(dados.get("nome", "Pedro")), linhas)


## Retomar uma partida salva é da cadeia; esta é a janela para ela, como as
## propriedades acima. Ver `CadeiaDeMissoes.retomar`: repõe objetivo e marcador
## sem refazer a fala.
func retomar() -> void:
	_cadeia.retomar()


## A SAUDAÇÃO DO PEDRO É A DA CHEGADA NO PÍER, e só cabe uma vez por partida.
##
## "A fala do Pedro depois de dar um loading não está condizente com o momento
## do jogo. Ele tá repetindo a frase quando o jogador chega no porto no início
## do jogo." O "já saudei" do morador é um relógio de memória
## (`_ultima_saudacao_ms`), que não vai no save: toda carga — continuar a vaga,
## trocar o estilo — nascia com ele zerado, e o Pedro, posto ao lado do
## jogador, dizia "Opa! É você o moço da capital?" no meio da partida.
##
## Quem sabe se a chegada já aconteceu é a cadeia, e ela vai no save
## (`iniciado`). Com ela começada, a saudação se cala — e se dá por feita, para
## não ser perguntada de novo a cada quadro.
func saudar() -> void:
	if _cadeia.iniciado:
		_ultima_saudacao_ms = Time.get_ticks_msec()
		return
	super()
	_cadeia.comecar(6.5)


## O E NO PEDRO (`tecla_dos_moradores.gd`), quando nenhuma fila usa a conversa:
## antes da chegada, é a saudação que a abre; durante ela, ele repete o que fazer
## agora — quem se perdeu pergunta ao Pedro. Depois do tutorial, é a conversa de
## qualquer morador.
func conversar() -> void:
	if not _cadeia.iniciado:
		saudar()
		return
	if not terminou_o_tutorial() and not _cadeia.acabou():
		var texto := _cadeia.texto_do_passo()
		if texto != "":
			_ultima_saudacao_ms = Time.get_ticks_msec()
			narrar("", texto)
			return
	super()


## O mesmo `narrar` da base, mais o `narrou` — que é o que põe a fala do Pedro
## no aviso do HUD. A parte comum subiu para o `npc.gd` quando o Damião ganhou
## fila de missões; o que sobrou aqui é o sinal, que é do guia.
func narrar(nome_audio: String, texto: String) -> void:
	super(nome_audio, texto)
	narrou.emit(texto)


func _verificar_anoitecer() -> void:
	var periodo := Dia.periodo()
	if periodo == "entardecer" and not _anoiteceu_hoje and _cadeia.espera <= 0.0 and _palavra_livre():
		_anoiteceu_hoje = true
		narrar("pedro_anoitecer", "Daqui a pouco escurece. Quando terminar, volte pra cama. Apagar no chão não descansa igual.")
	elif periodo == "manha":
		_anoiteceu_hoje = false


## Pedro só narra quando nem ele nem o jogador estão ao alcance de outra fala.
func _palavra_livre() -> bool:
	return pode_falar() and not fala_perto_de(jogador.global_position)


## ONDE O PASSO ACONTECE, resolvido pelo NOME e não pela âncora.
##
## O `Lugares` traduz "praca" no ponto do vale, e traduziria o mesmo "praca"
## num `Vector2` do jogo 2D. É a costura da Fase 1, e é ela que faz a campanha
## escrita lá servir aqui. A conta mora na cadeia; isto é a janela para ela,
## que o portão `tests/cadeia_das_missoes.gd` usa pelo nome antigo.
func _posicao_da_missao(indice: int) -> Vector3:
	return _cadeia.posicao_do_passo(indice)


func _falta_a_meta(passo: Dictionary) -> bool:
	return _cadeia.falta_a_meta(passo)


func texto_da_missao() -> String:
	if not _cadeia.iniciado:
		return "Fale com Pedro: ele veio te esperar no píer."
	if _cadeia.acabou():
		return "Você conheceu o arraial. Explore o vale como quiser."
	return "Pedro: " + _cadeia.texto_do_passo()
