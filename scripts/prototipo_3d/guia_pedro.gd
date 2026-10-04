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

## Criada no `_init`, e não no `_ready`, de propósito: o `Prototype` escreve
## `pedro.recursos` e o save escreve `pedro.missao`, e propriedade que cai no
## vazio porque a cadeia ainda não existe é defeito calado.
var _cadeia := CadeiaDeMissoes.new()
var _anoiteceu_hoje := false


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
		super(delta)
		return
	if _andar_dando_passagem(delta):
		_atualizar_animacao(delta)
		_atualizar_interacao(delta)
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
