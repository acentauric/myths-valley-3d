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
## A ferramenta que um passo da chegada entregou, com o número da barra.
signal entregou(texto: String)
## NA CONDUÇÃO, ELE PAROU PORQUE O JOGADOR FICOU PARA TRÁS (verdadeiro), ou voltou
## a andar, chegou, ou parou de conduzir (falso). O HUD põe o aviso de voltar.
signal esperando_quem_ficou(esperando: bool)

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
## que vai apresentar." No passo com `conduz` ele anda pela malha — e pela estrada e
## pela ponte (`Navegacao.caminho_pela_estrada`) — até quem o passo apresenta (ou até o
## lugar dele) e para a CONDUZ_ATE dele; o jogador vai atrás.
##
## A LINHA DO PERCURSO (playtest de 07/10: "o Pedro só começa a andar depois do jogador
## encostar nele... tem que andar já na direção do jogador; toda missão com deslocamento
## de NPC deve ter uma linha de percurso para saber se o jogador já está mais à frente").
## O caminho da condução é a régua: quanto cada um já andou dela (`_progresso_de`) diz
## quem está na frente. Com o jogador À FRENTE, o Pedro não espera ninguém — segue, e
## corre se ficou para trás. Com o jogador PARA TRÁS mais que VOLTA_POR_QUEM_FICA E SEM VÊ-LO
## (ver Conducao: à vista ele segue, mesmo longe), ele espera e depois VOLTA pelo caminho até ele,
## em vez de parar no meio da estrada esperando uma aproximação que o jogador não entendia; a
## VOLTA_A_ANDAR dele, ou assim que o jogador volta a vê-lo, retoma. Enquanto o
## jogador não pode andar (a caixa de fala aberta, o corpo parado), ele espera. Os
## marcos de antes (parar a cada onze passos) saíram: eram a espera que confundia.
const CONDUZ_ATE := 2.4
const VOLTA_POR_QUEM_FICA := 5.5
const VOLTA_A_ANDAR := 3.0
## O AFASTAMENTO PELA VISTA DO JOGADOR (#238). O Pedro andava colado e voltava sempre que o jogador
## se afastava VOLTA_POR_QUEM_FICA: com o jogador um pouco lento (ou o testador hesitando) ele ia e
## voltava, e a caminhada arrastava. Quem decide agora é se o jogador PODE VÊ-LO:
##  - À VISTA (dentro do campo da câmera, sem obstáculo cobrindo e a até LEGIVEL_ATE do jogador) ele
##    SEGUE até o objetivo, por maior que seja o atraso: o jogador sabe para onde ir;
##  - FORA DA VISTA por OCULTO_APOS segundos ele ESPERA onde está, e só depois de ESPERA_ANTES_DE_VOLTAR
##    segundos, se o jogador não vem na direção dele (VINDO_MINIMO u/s), VOLTA — o "Pedro voltou para
##    te buscar".
## A decisão não pisca: a vista só muda de estado depois de VISTO_APOS (ao reaparecer) ou OCULTO_APOS
## (ao sumir) seguidos, medida a cada AMOSTRA_DA_VISTA.
enum Conducao { SEGUE, ESPERA, VOLTA }
const LEGIVEL_ATE := 18.0
const VISTO_APOS := 0.6
const OCULTO_APOS := 2.0
const ESPERA_ANTES_DE_VOLTAR := 3.0
const AMOSTRA_DA_VISTA := 0.2
const VINDO_MINIMO := 0.8
var _a_vista_estavel := true
var _visto_s := 0.0
var _oculto_s := 0.0
var _amostra_vista_s := 0.0
var _na_tela_agora := true
var _espera_oculto_s := 0.0
var _distancia_antes := -1.0
var _amostra_vindo_s := 0.0
var _vindo := false
## De quanto em quanto se refaz o caminho de volta até quem ficou.
const REFAZER_A_VOLTA := 0.8
var _volta: PackedVector3Array = PackedVector3Array()
## O ponto da vez da volta (índice em `_volta`): só avança.
var _volta_ponto := 1
var _volta_em := 0.0
## NÃO FICA ATOLADO NO MEIO DO CAMINHO. A malha pode mandar por um corpo que ela não conhecia (uma peça
## nova da cena, a casca de um prédio): o Pedro anda contra ele sem sair do lugar, o jogador espera atrás
## ("o Pedro está esperando você") e o tutorial para ali para sempre — a partida jogada do zero ficou 600 s
## de jogo parada na rua da praça. Depois de DESATOLA_APOS segundos de passo sem sair do lugar, ele salta
## para o ponto livre do caminho mais adiante (o primeiro de DESATOLA_PULOS que não tem corpo em cima).
const DESATOLA_APOS := 10.0
## BARRADO, ELE NÃO VOLTA (#237): o "Pedro voltou para te buscar" é para o jogador que ficou para
## trás, e não para o Pedro que deu na cerca ou no mourão e não sai do lugar. Há esse tempo andando
## sem avançar, ele fica onde está tentando passar (e, passado DESATOLA_APOS, salta para o ponto livre
## do caminho) em vez de largar a rota e voltar à cidade.
const ATOLADO_SEM_VOLTAR := 1.5
const DESATOLA_PULOS := [6.0, 10.0, 14.0, 20.0]
var _atolado_s := 0.0
## AS CASAS ELE CONDUZ ATÉ A PORTA, do lado de fora: a herdada, onde ele não
## entra, e as de quem mora — a dele, na ida aos machados do avô, e a da Dona
## Zefa. A âncora de uma casa é o meio dela, e conduzir até lá era levar o
## jogador para dentro da casa dos outros atrás dele.
const CONDUZ_ATE_A_PORTA := ["casa", "casa_pedro", "casa_zefa"]
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
## O passo em que ele leva o jogador até a Dona Candinha.
const PASSO_DA_CANDINHA := "chave"
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
## O AVISO DE VOLTAR já está na tela? E o último quadro de física em que ele
## conduziu: passo que fecha, tutorial que acaba ou fila que muda tiram a
## condução sem passar por `_conduzir`, e o aviso não pode ficar órfão.
var _avisou_quem_ficou := false
var _quadro_da_conducao := -1
## O jogador cansou na caminhada e ainda não ouviu a explicação. Guardado
## porque o vigor volta depressa — parado, 20 por segundo —, e a fala pode
## estar ocupada no instante em que ele cai.
var _cansou_na_caminhada := false
## A próxima das falas de depois do tutorial (`falas_depois` no npcs_3d.json).
var _proxima_fala_depois := -1

## AS FALAS SITUACIONAIS (#179). Fora do roteiro o Pedro ficava calado: o jogador some, para, cai
## na água, cansa, e a condução parecia mecânica. Dez comentários curtos (`situacoes` no
## npcs_3d.json, cada um com o `gatilho` e a voz), disparados pelo que acontece com o jogador
## ENQUANTO ELE CONDUZ o tutorial (`_na_chegada`); acabada a chegada, calam. O gatilho PEDE a fala
## (`_pedir_situacao`) e ela sai quando a palavra está livre (`_dizer_situacao`): sem atropelar a
## narração, a caixa de fala, o anúncio do passo nem o balão de outro morador, com a pausa
## SITUACAO_PAUSA entre quaisquer duas e sem repetir a mesma antes do `intervalo` dela (sem
## `intervalo`, uma vez por partida: a lembrança `disse:<gatilho>` vai no save). O pedido vence em
## `validade` segundos: o comentário sobre o mar não sai com o jogador já em terra.
const SITUACAO_PAUSA := 25.0
## Quanto tempo o jogador parado, na condução, antes do "pode olhar à vontade".
const PARADO_DEMAIS := 20.0
## Quanto tempo ele barra o caminho do Pedro antes do "com licença".
const BARRADO_DEMAIS := 1.2
## Quantas amostras seguidas (uma por segundo) o jogador se afasta do destino, andando, para ser o lado errado.
const AFASTANDO_DEMAIS := 5
## O vigor do jogador que conta como zerado, e o que o reabilita para uma próxima vez.
const VIGOR_ZERADO := 0.02
const VIGOR_RECUPERADO := 0.5
## O peixe que o Tonho paga no bom-dia: o primeiro item que o jogador pega na mão.
const PEIXE_DO_TONHO := "peixe"
var _situacao_ultima_ms := -1000000
var _situacao_dita_em: Dictionary = {}
## Gatilho -> quando o pedido vence (ms).
var _situacao_pedidas: Dictionary = {}
var _jogador_parado_s := 0.0
var _barrado_s := 0.0
var _afastando := 0
var _distancia_ao_destino := -1.0
var _amostra_s := 0.0
var _vigor_zerado := false
var _nado_ligado := false

## A CAPOEIRA DO PEDRO (#190). "Quando o Pedro está ocioso e longe do jogador, de
## vez em quando ele treina capoeira no lugar: ginga e movimentos, em ciclos
## curtos. Quando o jogador vai chegando perto, ele termina o golpe e para, volta
## ao idle e se vira para o jogador." É o clipe Capoeira Idle do Mixamo, em laço,
## no posto dele depois do tutorial (o píer, a praça). Começa só com o jogador além
## de TREINO_LONGE e para a TREINO_PARA — esperando o fim do golpe
## (`authored_animator.parar_no_fim_do_golpe`) —, nunca na condução, em missão
## em curso com ele, em conversa, dentro de cômodo, à noite, nem com gente a menos
## de TREINO_FOLGA (a ginga anda de lado mais de meio metro).
const TREINO_CLIPE := "capoeira"
const TREINO_LONGE := 12.0
const TREINO_PARA := 9.0
const TREINO_FOLGA := 2.0
## Quanto dura um treino e quanto ele descansa entre dois (s, sorteados na faixa).
const TREINO_DURA := Vector2(8.0, 16.0)
const TREINO_PAUSA := Vector2(18.0, 45.0)
const PERIODOS_DO_TREINO := ["manha", "tarde", "entardecer"]
## Parado o treino porque o jogador chegou, ele se vira para ele por este tempo (s).
const TREINO_VIRA_POR := 5.0
var _treino_resta := 0.0
var _treino_espera := 8.0
var _treino_virar_s := 0.0

## APONTAR O CAMINHO (#190, o Pointing do Mixamo): na condução, quando ele para no
## marco para esperar o jogador e quando chega a quem o passo apresenta, ele olha o
## rumo e aponta. Uma vez por parada.
const APONTAR_CLIPE := "pointing"
var _chegou_antes := false
var _apontar_para := Vector3.INF
var _apontando_s := 0.0


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
	_cadeia.entregou.connect(func(texto: String) -> void: entregou.emit(texto))
	add_child(_cadeia)
	Inventario.mao_trocada.connect(_ao_trocar_a_mao)
	Dia.periodo_mudou.connect(_ao_mudar_o_periodo)


func _exit_tree() -> void:
	if Inventario.mao_trocada.is_connected(_ao_trocar_a_mao):
		Inventario.mao_trocada.disconnect(_ao_trocar_a_mao)
	if Dia.periodo_mudou.is_connected(_ao_mudar_o_periodo):
		Dia.periodo_mudou.disconnect(_ao_mudar_o_periodo)
	super()


## O TUTORIAL ACABOU — as nove primeiras missões e a despedida —, e o Pedro
## para de seguir: volta à vida de pescador, nos postos dele (`npcs_3d.json`,
## "guia"), e quem quer falar com ele vai até ele. As missões do arraial abrem
## assim, chegando perto dele (`prototype._pendurar_cadeia`, 6 de raio).
func terminou_o_tutorial() -> bool:
	return _cadeia.acabou() and _cadeia.despedida_feita


## POSTO NA PORTA DA CASA (#92), do lado de fora, quando o jogador acorda lá
## dentro depois de apagar: nadando, ele ficava no mar. Enquanto o tutorial dura
## ele acompanha, e a condução recomeça dali (`queda._levar_para_casa`).
func vir_para_a_porta(ponto: Vector3) -> void:
	if not ponto.is_finite():
		return
	global_position = ponto + Vector3(0.0, 0.05, 0.0)
	velocity = Vector3.ZERO
	_nadando = false
	_preso = 0.0
	_desvios = 0
	_desvio_tempo = 0.0
	_parado = 0.0
	_ponto_bloqueio = Vector3.INF
	_caminho_ate = Vector3.INF


## O passo de id `id` da chegada já fechou? A roça do Cosme abre depois da
## primeira leira (`roca`).
func passou(id: String) -> bool:
	return _cadeia.passou(id)


## O item que um passo da chegada deve e ainda não coube na mochila (#217: a chave da casa)?
func esta_devendo(item: String) -> bool:
	return _cadeia._devendo(item)


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
	# O NADO DO JOGADOR chega aqui pelo sinal dele, ligado na primeira vez em que ele existe (#179).
	if not _nado_ligado and jogador.has_signal("nado_mudou"):
		_nado_ligado = true
		jogador.connect("nado_mudou", _ao_nadar)
	# EM CENA (cena_vale.gd), a cena manda nele, como no 2D (`Pedro._em_cena`).
	if _em_cena:
		_passo_da_cena(delta)
		return
	if terminou_o_tutorial():
		# DEPOIS DO TUTORIAL ELE AINDA CONDUZ quando uma fila dele pede: a jornada da
		# fazenda, em que ele leva o jogador pela ponte até o portão, como no 2D.
		var conduzindo := _outra_que_conduz()
		if conduzindo != null:
			_largar_o_treino()
			_conduzir(delta, conduzindo)
			_atualizar_animacao(delta)
			_atualizar_interacao(delta)
			return
		super(delta)
		_treinar_capoeira(delta)
		return
	if _andar_dando_passagem(delta):
		_atualizar_animacao(delta)
		_atualizar_interacao(delta)
		return
	_ver_se_explica_o_corpo()
	_vigiar_o_jogador(delta)
	_ver_situacoes()
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
		if sala_do_jogador in ESPERA_FORA or interiores.espera_fora(sala_do_jogador):
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
	_prefere_a_estrada = true
	var destino := _destino_da_conducao(cadeia)
	var onde_esta: Vector3 = jogador.global_position
	var do_jogador := Vector2(onde_esta.x - global_position.x, onde_esta.z - global_position.z).length()
	var falta := destino - global_position
	falta.y = 0.0
	if Engine.get_physics_frames() - _quadro_da_conducao > 30:
		_reiniciar_a_leitura_da_vista()
	_quadro_da_conducao = Engine.get_physics_frames()
	# O JOGADOR NÃO PODE ANDAR (a caixa de fala aberta, o corpo parado): ele espera. E chegado,
	# o que o passo pede é perto dele (quem ele apresenta, a porta da casa).
	var jogador_preso: bool = not jogador.is_physics_processing() or Dialogo.ocupado()
	if cadeia == null:
		_vigiar_o_rumo(delta, onde_esta, destino, falta.length(), jogador_preso)
	_ver_se_aponta(falta.length() <= CONDUZ_ATE, destino)
	if jogador_preso or falta.length() <= CONDUZ_ATE:
		_atolado_s = 0.0
		_esperando_quem_ficou = false
		_avisar_quem_ficou(false)
		_mover(Vector3.ZERO, ANDAR, delta)
		if _apontando_s > 0.0:
			# Apontando, ele olha o rumo, e não o jogador.
			_apontando_s -= delta
			_olhar_para(_apontar_para, delta)
		else:
			_olhar_para(onde_esta, delta)
		if falta.length() <= CONDUZ_ATE and cadeia == null and do_jogador <= VOLTA_POR_QUEM_FICA and str(_cadeia.passo_atual().get("id", "")) == PASSO_DA_CANDINHA:
			_pedir_situacao("chegada_candinha", 15.0)
		return
	_apontando_s = 0.0
	# O ponto da vez do caminho (pela estrada), que também o refaz quando é hora.
	var ponto := _ponto_do_caminho(destino, delta)
	# A LINHA DO PERCURSO: o atraso do jogador ao longo dela (negativo: ele vai à frente).
	var atraso := do_jogador
	if _caminho.size() >= 2:
		var meu := _progresso_de(global_position)
		var dele := _progresso_de(onde_esta)
		if dele <= 0.5:
			# O JOGADOR ANTES DO COMEÇO DA LINHA (o caminho acabou de ser refeito de onde o Pedro
			# estava, e o jogador ficou atrás disso): o atraso é o que o Pedro andou na linha mais
			# o que falta ao jogador para chegar ao começo dela — e não só o andado, que era pouco
			# e deixava o Pedro seguir em frente por quem ficou doze passos atrás (07/10).
			atraso = meu + Vector2(onde_esta.x - _caminho[0].x, onde_esta.z - _caminho[0].z).length()
		else:
			atraso = meu - dele
	var a_vista := _a_vista_do_jogador(delta, do_jogador)
	var decisao := decidir_a_conducao(a_vista, atraso, do_jogador, _esperando_quem_ficou, _espera_oculto_s,
		_jogador_vindo(delta, do_jogador), _atolado_s >= ATOLADO_SEM_VOLTAR)
	if decisao == Conducao.VOLTA and not _esperando_quem_ficou:
		_pedir_situacao("ficou_atras", 10.0)
	_esperando_quem_ficou = decisao == Conducao.VOLTA
	if decisao == Conducao.ESPERA:
		# FORA DA VISTA E LONGE: espera onde está, virado para o jogador. Quem anda para o lado errado
		# ouve o "é por aqui" antes de ele voltar.
		if _espera_oculto_s <= 0.0 and _afastando > 0:
			_pedir_situacao("lado_errado", 10.0)
		_espera_oculto_s += delta
	else:
		_espera_oculto_s = 0.0
	_avisar_quem_ficou(_esperando_quem_ficou)
	if decisao == Conducao.ESPERA:
		_atolado_s = 0.0
		_mover(Vector3.ZERO, ANDAR, delta)
		_olhar_para(onde_esta, delta)
		return
	var depressa: float = Vector2(jogador.velocity.x, jogador.velocity.z).length() if "velocity" in jogador else 0.0
	var correndo := jogador.has_method("is_running") and bool(jogador.call("is_running")) and depressa > ANDAR * 1.2
	var rumo: Vector3
	var velocidade := ANDAR
	if _esperando_quem_ficou:
		# VOLTA POR QUEM FICOU, pela malha (a parede e a água no caminho de volta também contam).
		_volta_em -= delta
		if _volta_em <= 0.0 or _volta.is_empty():
			_volta_em = REFAZER_A_VOLTA
			var navegacao := get_tree().get_first_node_in_group("navegacao")
			_volta = navegacao.caminho(global_position, onde_esta) if navegacao != null and navegacao.esta_pronta() else PackedVector3Array()
			_volta_ponto = 1
		var alvo := onde_esta
		if _volta.size() > 1:
			# O PONTO DA VEZ DA VOLTA NÃO RECUA: alcançado, fica para trás de vez. Recomeçar do
			# primeiro a cada quadro mandava o Pedro de volta ao ponto que acabara de passar, e ele
			# vinha aos trancos (07/10: 1,2 u por segundo, a 2,1 de passo).
			while _volta_ponto < _volta.size() - 1 and Vector2(_volta[_volta_ponto].x - global_position.x, _volta[_volta_ponto].z - global_position.z).length() < PONTO_ALCANCADO:
				_volta_ponto += 1
			alvo = _volta[clampi(_volta_ponto, 0, _volta.size() - 1)]
		rumo = alvo - global_position
	else:
		_volta = PackedVector3Array()
		rumo = ponto - global_position
		# CORRE SÓ SE O JOGADOR CORRE DE FATO — ou se ele foi à frente e ficou longe (o passo
		# trocado para a corrida, parado, fazia o Pedro disparar enquanto o jogador lia a caixa).
		velocidade = CORRER if (correndo or atraso < -CORRER_ALEM) else ANDAR
	rumo.y = 0.0
	_mover(rumo.normalized() if rumo.length() > 0.05 else Vector3.ZERO, velocidade, delta)
	_pedir_passagem(rumo)
	if _esperando_quem_ficou:
		_atolado_s = 0.0
		return
	var andou := Vector2(get_real_velocity().x, get_real_velocity().z).length()
	if rumo.length() > 0.05 and andou < ANDAR * 0.25:
		_atolado_s += delta
		if _atolado_s >= DESATOLA_APOS:
			_atolado_s = 0.0
			_saltar_para_o_caminho_livre()
	else:
		_atolado_s = maxf(_atolado_s - delta * 2.0, 0.0)


## A DECISÃO DA CONDUÇÃO, sem mundo (ver Conducao): `a_vista` é a vista já estabilizada; `atraso` o quanto
## o jogador ficou para trás na linha do percurso; `do_jogador` a distância dele; `voltando` se ele já
## está voltando; `esperou_s` há quanto espera fora da vista; `vindo` se o jogador anda na direção dele;
## `barrado` se ele mesmo está atolado (cerca, mourão: a falha é da rota, e não do jogador).
static func decidir_a_conducao(a_vista: bool, atraso: float, do_jogador: float, voltando: bool, esperou_s: float, vindo: bool, barrado: bool) -> int:
	if voltando:
		return Conducao.VOLTA if (atraso > VOLTA_A_ANDAR and do_jogador > VOLTA_A_ANDAR and not a_vista) else Conducao.SEGUE
	if a_vista or barrado:
		return Conducao.SEGUE
	if atraso <= VOLTA_POR_QUEM_FICA or do_jogador <= VOLTA_POR_QUEM_FICA:
		return Conducao.SEGUE
	if esperou_s >= ESPERA_ANTES_DE_VOLTAR and not vindo:
		return Conducao.VOLTA
	return Conducao.ESPERA


## O jogador pode ver o Pedro agora, sem histerese: perto o bastante para ler (LEGIVEL_ATE), dentro do
## campo da câmera dele e sem corpo do mundo (casa, morro, árvore) entre a câmera e o peito do Pedro.
func esta_na_tela_do_jogador() -> bool:
	if jogador == null or not is_inside_tree():
		return false
	if Vector2(jogador.global_position.x - global_position.x, jogador.global_position.z - global_position.z).length() > LEGIVEL_ATE:
		return false
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return true
	var peito := global_position + Vector3.UP * altura * 0.6
	if not camera.is_position_in_frustum(peito):
		return false
	var fora: Array[RID] = [get_rid()]
	if jogador is CollisionObject3D:
		fora.append((jogador as CollisionObject3D).get_rid())
	var pergunta := PhysicsRayQueryParameters3D.create(camera.global_position, peito, 1)
	pergunta.exclude = fora
	var achou := get_world_3d().direct_space_state.intersect_ray(pergunta)
	return achou.is_empty() or camera.global_position.distance_to(achou.position as Vector3) > camera.global_position.distance_to(peito) - 0.6


## A vista já estabilizada (ver Conducao): amostra a cada AMOSTRA_DA_VISTA e só troca de estado depois de
## VISTO_APOS / OCULTO_APOS seguidos.
func _a_vista_do_jogador(delta: float, _do_jogador: float) -> bool:
	_amostra_vista_s += delta
	if _amostra_vista_s < AMOSTRA_DA_VISTA:
		return _a_vista_estavel
	var passou := _amostra_vista_s
	_amostra_vista_s = 0.0
	_na_tela_agora = esta_na_tela_do_jogador()
	if _na_tela_agora:
		_visto_s += passou
		_oculto_s = 0.0
		if _visto_s >= VISTO_APOS:
			_a_vista_estavel = true
	else:
		_oculto_s += passou
		_visto_s = 0.0
		if _oculto_s >= OCULTO_APOS:
			_a_vista_estavel = false
	return _a_vista_estavel


## O jogador anda na direção do Pedro? A distância medida a cada meio segundo; cai ao menos VINDO_MINIMO u/s.
func _jogador_vindo(delta: float, do_jogador: float) -> bool:
	_amostra_vindo_s += delta
	if _amostra_vindo_s >= 0.5:
		_vindo = _distancia_antes >= 0.0 and _distancia_antes - do_jogador >= VINDO_MINIMO * _amostra_vindo_s
		_distancia_antes = do_jogador
		_amostra_vindo_s = 0.0
	return _vindo


## A condução recomeça (passo novo, ou depois de parada): a vista parte de "visto" e a espera zera.
func _reiniciar_a_leitura_da_vista() -> void:
	_a_vista_estavel = true
	_na_tela_agora = true
	_visto_s = 0.0
	_oculto_s = 0.0
	_amostra_vista_s = 0.0
	_espera_oculto_s = 0.0
	_distancia_antes = -1.0
	_amostra_vindo_s = 0.0
	_vindo = false


## QUANTO DO CAMINHO (`_caminho`, pela malha e pela estrada) já ficou para trás de `p`: o
## comprimento até a projeção de `p` na linha. Sem caminho, 0.
func _progresso_de(p: Vector3) -> float:
	if _caminho.size() < 2:
		return 0.0
	var q := Vector2(p.x, p.z)
	var melhor := INF
	var progresso := 0.0
	var andado := 0.0
	for i in range(_caminho.size() - 1):
		var a := Vector2(_caminho[i].x, _caminho[i].z)
		var b := Vector2(_caminho[i + 1].x, _caminho[i + 1].z)
		var proj := Geometry2D.get_closest_point_to_segment(q, a, b)
		var d := q.distance_to(proj)
		if d < melhor:
			melhor = d
			progresso = andado + a.distance_to(proj)
		andado += a.distance_to(b)
	return progresso


## A que distância da linha do caminho `p` está.
func _afastamento_da_linha(p: Vector3) -> float:
	if _caminho.size() < 2:
		return INF
	var q := Vector2(p.x, p.z)
	var melhor := INF
	for i in range(_caminho.size() - 1):
		var a := Vector2(_caminho[i].x, _caminho[i].z)
		var b := Vector2(_caminho[i + 1].x, _caminho[i + 1].z)
		melhor = minf(melhor, q.distance_to(Geometry2D.get_closest_point_to_segment(q, a, b)))
	return melhor


## Salta para o primeiro ponto do caminho, a pelo menos DESATOLA_PULOS[i] unidades de caminho adiante, que
## não tem corpo em cima (uma esfera de 0,45 u na camada 1). Sem caminho ou sem ponto livre, fica onde está.
func _saltar_para_o_caminho_livre() -> void:
	if _caminho.size() < 2:
		return
	var espaco := get_world_3d().direct_space_state
	for pulo in DESATOLA_PULOS:
		var andado := 0.0
		var anterior := global_position
		for i in range(maxi(_ponto_da_vez, 0), _caminho.size()):
			var ponto: Vector3 = _caminho[i]
			andado += Vector2(ponto.x - anterior.x, ponto.z - anterior.z).length()
			anterior = ponto
			if andado < float(pulo):
				continue
			var esfera := SphereShape3D.new()
			esfera.radius = 0.45
			var pergunta := PhysicsShapeQueryParameters3D.new()
			pergunta.shape = esfera
			pergunta.transform = Transform3D(Basis.IDENTITY, ponto + Vector3(0.0, 0.9, 0.0))
			pergunta.collision_mask = 1
			pergunta.exclude = [get_rid()]
			if espaco.intersect_shape(pergunta, 1).is_empty():
				push_warning("GuiaPedro: atolado em %s, saltou para %s do caminho (a malha passa por um corpo que ela não conhecia)" % [str(global_position), str(ponto)])
				global_position = ponto + Vector3(0.0, 0.05, 0.0)
				velocity = Vector3.ZERO
				_ponto_da_vez = i
				_refazer_em = 0.0
				_preso = 0.0
				_desvios = 0
				_desvio_tempo = 0.0
				_lado_desvio = 0.0
				_ponto_bloqueio = Vector3.INF
				return
			break


## QUEM BARRA A CONDUÇÃO DÁ PASSAGEM, como dá ao jogador
## (`player_controller._empurrar_quem_barra`): no tabuado estreito do píer o Tonho,
## parado de bom-dia a dois passos da prancha, ficava no meio do caminho da malha, e
## o Pedro empacava nele em vez de levar o jogador à Dona Candinha.
func _pedir_passagem(rumo: Vector3) -> void:
	if rumo.length_squared() < 0.0025:
		return
	var direcao := Vector3(rumo.x, 0.0, rumo.z).normalized()
	var barrado_pelo_jogador := false
	for i in get_slide_collision_count():
		var colisao := get_slide_collision(i)
		var corpo := colisao.get_collider()
		var empurrao := -colisao.get_normal()
		empurrao.y = 0.0
		# O jogador no meio do caminho dele: o "com licença" (#179), e não um pedido de passagem.
		if corpo != null and corpo == jogador:
			barrado_pelo_jogador = barrado_pelo_jogador or (empurrao.length_squared() > 0.0001 and empurrao.normalized().dot(direcao) > 0.3)
			continue
		if corpo == null or corpo == self or not corpo.has_method("dar_passagem"):
			continue
		if empurrao.length_squared() > 0.0001 and empurrao.normalized().dot(direcao) > 0.3:
			corpo.dar_passagem(empurrao)
	var delta := get_physics_process_delta_time()
	_barrado_s = _barrado_s + delta if barrado_pelo_jogador else maxf(_barrado_s - delta * 2.0, 0.0)
	if _barrado_s >= BARRADO_DEMAIS:
		_barrado_s = 0.0
		_pedir_situacao("passagem", 6.0)


func _avisar_quem_ficou(sim: bool) -> void:
	if sim == _avisou_quem_ficou:
		return
	_avisou_quem_ficou = sim
	esperando_quem_ficou.emit(sim)


## Sem condução há mais de dois quadros de física, o aviso sai.
func _process(_delta: float) -> void:
	if _avisou_quem_ficou and Engine.get_physics_frames() - _quadro_da_conducao > 2:
		_avisar_quem_ficou(false)


## PARA ONDE ELE CONDUZ: quem o passo apresenta, ou o lugar do passo — e, sendo
## o lugar uma casa (CONDUZ_ATE_A_PORTA), a porta dela, do lado de fora.
func _destino_da_conducao(cadeia: Node = null) -> Vector3:
	var quem: Node = cadeia if cadeia != null else _cadeia
	var destino: Vector3 = quem.posicao_do_passo(quem.missao)
	var interiores := get_tree().get_first_node_in_group("interiores")
	if interiores != null:
		var evento := str(quem.passo_atual().get("meta", {}).get("evento", ""))
		if evento.begins_with("entrou:"):
			var sala: Node3D = interiores.sala_de(evento.trim_prefix("entrou:"))
			if sala != null:
				var espera: Vector3 = sala.lugar_de_esperar_fora()
				return terreno.ground_position(espera, 0.05) if terreno != null else espera
		var sala_do_destino: String = interiores.contem(destino)
		if sala_do_destino in ESPERA_FORA or sala_do_destino in CONDUZ_ATE_A_PORTA or interiores.espera_fora(sala_do_destino):
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
		# O animador também tem `passo_atual` (o passo da ação, #Mixamo rodada 2):
		# fila é quem tem também `acabou` e `iniciado`.
		if filho == _cadeia or not filho.has_method("passo_atual") or not filho.has_method("acabou") or not "iniciado" in filho:
			continue
		if filho.iniciado and not filho.acabou() and bool(filho.passo_atual().get("conduz", false)):
			return filho
	return null


## PODE VIR AJUDAR O JOGADOR (#204): só depois do tutorial, e não enquanto conduz uma fila dele (a jornada da fazenda).
func pode_vir_ajudar() -> bool:
	return terminou_o_tutorial() and _outra_que_conduz() == null and super()


## APONTA NA CHEGADA DA CONDUÇÃO (ver APONTAR_CLIPE): chegado, para o destino. Uma vez
## por chegada. (Os marcos, que também apontavam o próximo ponto, saíram com a condução
## pela estrada de 08/10: eram a espera que confundia.)
func _ver_se_aponta(chegou: bool, destino: Vector3) -> void:
	if chegou and not _chegou_antes:
		if animador != null and animador.has_method("gesto") and bool(animador.gesto(APONTAR_CLIPE)):
			_apontar_para = destino
			_apontando_s = float(animador.duracao_do_clipe(APONTAR_CLIPE))
	_chegou_antes = chegou


## PODE TREINAR CAPOEIRA AGORA? (ver TREINO_CLIPE) A regra sem mundo, para o portão
## conferir: `distancia` do jogador e o `limite` (TREINO_LONGE para começar,
## TREINO_PARA para seguir), `parado` no posto, e os impedimentos.
static func pode_treinar(distancia: float, limite: float, parado: bool, conduzindo: bool, em_missao: bool,
		conversando_agora: bool, dentro: bool, periodo: String, gente_perto: bool) -> bool:
	return distancia > limite and parado and not conduzindo and not em_missao and not conversando_agora \
		and not dentro and periodo in PERIODOS_DO_TREINO and not gente_perto


## Um pulso do treino, depois do tutorial e fora da condução: começa quando pode e o
## descanso acabou; com o jogador chegando, termina o golpe e para, e se vira para
## ele; com conversa, missão ou cômodo, para já.
func _treinar_capoeira(delta: float) -> void:
	if animador == null or not animador.has_method("tem_clipe") or not bool(animador.tem_clipe(TREINO_CLIPE)):
		return
	var falta := jogador.global_position - global_position
	falta.y = 0.0
	var distancia := falta.length()
	var treinando := str(animador.trabalhando_em()) == TREINO_CLIPE
	if treinando:
		if bool(animador.parando()):
			return
		_treino_resta -= delta
		if _impedido_de_treinar():
			# Conversa, missão ou cômodo: para já, sem esperar o golpe.
			_largar_o_treino()
			return
		if not _pode_treinar_aqui(TREINO_PARA):
			_treino_virar_s = TREINO_VIRA_POR
			_treino_espera = randf_range(TREINO_PAUSA.x, TREINO_PAUSA.y)
			animador.parar_no_fim_do_golpe()
		elif _treino_resta <= 0.0:
			_treino_espera = randf_range(TREINO_PAUSA.x, TREINO_PAUSA.y)
			animador.parar_no_fim_do_golpe()
		return
	if _treino_virar_s > 0.0:
		_treino_virar_s -= delta
		if distancia < TREINO_LONGE + 2.0 and _velocidade_atual < 0.1:
			_olhar_para(jogador.global_position, delta)
	_treino_espera -= delta
	if _treino_espera > 0.0:
		return
	if _pode_treinar_aqui(TREINO_LONGE) and animador.trabalhar(TREINO_CLIPE, true):
		_treino_resta = randf_range(TREINO_DURA.x, TREINO_DURA.y)
	else:
		_treino_espera = 3.0


## O treino parado já, sem esperar o golpe (a condução que começa, a conversa).
func _largar_o_treino() -> void:
	if animador != null and animador.has_method("trabalhando_em") and str(animador.trabalhando_em()) == TREINO_CLIPE:
		animador.parar_trabalho()
	_treino_espera = maxf(_treino_espera, TREINO_PAUSA.x)


func _impedido_de_treinar() -> bool:
	return conversando() or Dialogo.ocupado() or falando_agora() or _atencao_resta > 0.0 \
		or _missao_em_curso() or _dentro_de_comodo()


func _pode_treinar_aqui(limite: float) -> bool:
	var falta := jogador.global_position - global_position
	falta.y = 0.0
	var chegou := Vector2(_alvo.x - global_position.x, _alvo.z - global_position.z).length() < 0.8
	var parado := chegou and _velocidade_atual < 0.1 and not _nadando and not _recolhido and not _dormindo \
		and not _destino_avulso.is_finite()
	return pode_treinar(falta.length(), limite, parado, _outra_que_conduz() != null, _missao_em_curso(),
		conversando() or Dialogo.ocupado() or falando_agora() or _atencao_resta > 0.0, _dentro_de_comodo(),
		Dia.periodo(), _gente_perto(TREINO_FOLGA))


## UMA MISSÃO EM CURSO COM ELE: uma fila viva, já começada e não acabada, que o envolve
## (a que só espera o jogador chegar perto para começar não conta).
func _missao_em_curso() -> bool:
	for cadeia in get_tree().get_nodes_in_group(GRUPO_DAS_CADEIAS):
		if not ("iniciado" in cadeia) or not cadeia.has_method("acabou") or not cadeia.has_method("envolve"):
			continue
		if bool(cadeia.iniciado) and not bool(cadeia.acabou()) and bool(cadeia.envolve(self)):
			return true
	return false


func _dentro_de_comodo() -> bool:
	var interiores := get_tree().get_first_node_in_group("interiores")
	return interiores != null and str(interiores.contem(global_position)) != ""


## Outro morador (à vista) a menos de `raio` dele.
func _gente_perto(raio: float) -> bool:
	for outro in get_tree().get_nodes_in_group("moradores"):
		if outro == self or not (outro is Node3D) or not (outro as Node3D).visible:
			continue
		if (outro as Node3D).global_position.distance_squared_to(global_position) < raio * raio:
			return true
	return false


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
	# A CAIXA NÃO ESPERA O BALÃO: ela para o vale, e a fala que estiver no ar fica
	# suspensa até a caixa fechar (`fila_de_falas.gd`). Espera só outra caixa e a
	# narração do mundo.
	if Dialogo.ocupado() or _narracao_na_tela():
		return
	if jogador.global_position.distance_to(global_position) > PERTO_PARA_EXPLICAR:
		return
	# Na porta, ou já com o jogador lá dentro, no passo do baú. Depois dele, não:
	# quem passou da casa sem ouvir é partida de antes desta chegada.
	var id := str(passo.get("id", ""))
	var na_porta := (id == PASSO_DA_PORTA and _chegou_ao_destino()) or id == PASSO_DO_BAU
	if _cansou_na_caminhada or na_porta:
		explicar_o_corpo(_cansou_na_caminhada)


## As três barras na caixa de fala longa; a última fala muda com o cansaço. COM
## A VOZ DELE em cada linha ("audio" no `corpo` do missoes_guia.json, gerado por
## tools/elevenlabs/gerar-falas-do-guia.ps1): "na explicação do pedro sobre a
## barra de stamina e similares, crie os audios para ele narrar".
func explicar_o_corpo(cansado: bool) -> void:
	_cadeia._levados[LEMBRANCA_DO_CORPO] = true
	# Depois da explicação do corpo, nenhum comentário situacional emenda (ver SITUACAO_PAUSA).
	_situacao_ultima_ms = Time.get_ticks_msec()
	var linhas: Array = []
	var vozes: Array = []
	var interfaces: Array = []
	for fala in _corpo:
		if not (fala is Dictionary):
			continue
		var quando := str((fala as Dictionary).get("quando", ""))
		if quando != "" and quando != ("cansado" if cansado else "descansado"):
			continue
		linhas.append(str(IdiomaMenu.campo(fala, "texto", "")))
		vozes.append(str((fala as Dictionary).get("audio", "")))
		interfaces.append(fala.get("interfaces", []))
	Dialogo.falar(str(dados.get("nome", "Pedro")), linhas, vozes, interfaces)


## Retomar uma partida salva é da cadeia; esta é a janela para ela, como as
## propriedades acima. Ver `CadeiaDeMissoes.retomar`: repõe objetivo e marcador
## sem refazer a fala.
func retomar() -> void:
	_cadeia.retomar()


## --- as falas situacionais (#179) ------------------------------------------

## Está na chegada: a cadeia dela começou e o tutorial não acabou. Só aqui ele comenta.
func _na_chegada() -> bool:
	return _cadeia.iniciado and not terminou_o_tutorial()


## A fala do gatilho (`situacoes` no npcs_3d.json), ou {}.
func _fala_da_situacao(gatilho: String) -> Dictionary:
	for fala in dados.get("situacoes", []):
		if fala is Dictionary and str((fala as Dictionary).get("gatilho", "")) == gatilho:
			return fala
	return {}


## O gatilho ainda pode falar? Sem `intervalo`, uma vez por partida (a lembrança vai no save); com
## ele, de novo só passado o tempo.
func _pode_a_situacao(gatilho: String) -> bool:
	var fala := _fala_da_situacao(gatilho)
	if fala.is_empty():
		return false
	var intervalo := float(fala.get("intervalo", 0.0))
	if intervalo <= 0.0:
		return not bool(_cadeia._levados.get("disse:" + gatilho, false))
	return not _situacao_dita_em.has(gatilho) or Time.get_ticks_msec() - int(_situacao_dita_em[gatilho]) >= int(intervalo * 1000.0)


## O gatilho disparou: pede a fala, que sai quando a palavra estiver livre (`_ver_situacoes`) e
## vence em `validade` segundos.
func _pedir_situacao(gatilho: String, validade: float) -> void:
	if not _na_chegada() or _situacao_pedidas.has(gatilho) or not _pode_a_situacao(gatilho):
		return
	_situacao_pedidas[gatilho] = Time.get_ticks_msec() + int(validade * 1000.0)


## Um pulso: diz, se a palavra está livre, uma das falas pedidas; larga as vencidas e as que já não valem.
func _ver_situacoes() -> void:
	if _situacao_pedidas.is_empty():
		return
	var agora := Time.get_ticks_msec()
	for gatilho: String in _situacao_pedidas.keys():
		if agora > int(_situacao_pedidas[gatilho]) or not _na_chegada() or not _pode_a_situacao(gatilho):
			_situacao_pedidas.erase(gatilho)
		elif _dizer_situacao(gatilho):
			_situacao_pedidas.erase(gatilho)
			return


## Diz a fala do gatilho AGORA, se a palavra está livre: a narração, a caixa de fala, o anúncio do
## passo (`espera`) e o balão de outro morador têm a vez antes, e duas falas situacionais não saem
## coladas (SITUACAO_PAUSA). Devolve se disse. Classe PASSAGEM: a fila cede a vez ao que importa.
func _dizer_situacao(gatilho: String) -> bool:
	var fala := _fala_da_situacao(gatilho)
	if fala.is_empty() or not _pode_a_situacao(gatilho):
		return false
	var agora := Time.get_ticks_msec()
	if agora - _situacao_ultima_ms < int(SITUACAO_PAUSA * 1000.0):
		return false
	if _cadeia.espera > 0.0 or Dialogo.ocupado() or _narracao_na_tela() or not _palavra_livre():
		return false
	var texto := String(IdiomaMenu.campo(fala, "texto", ""))
	if texto.strip_edges() == "":
		return false
	_situacao_ultima_ms = agora
	_situacao_dita_em[gatilho] = agora
	if float(fala.get("intervalo", 0.0)) <= 0.0:
		_cadeia._levados["disse:" + gatilho] = true
	var fluxo := _voz_do_arquivo(String(fala.get("audio", "")))
	_pedir_fala({
		"texto": texto, "inteira": texto, "voz": fluxo, "classe": FilaDeFalas.Classe.PASSAGEM,
		"segundos": FilaDeFalas.duracao(texto, _tempo_da_voz(fluxo)), "gesto": _gesto_de_saudacao(),
	})
	return true


## O que o jogador faz, a cada quadro da chegada: parado demais na condução, vigor zerado.
func _vigiar_o_jogador(delta: float) -> void:
	if not _na_chegada():
		return
	var passo := _cadeia.passo_atual()
	# PARADO DEMAIS: na condução, sem caixa de fala aberta e sem ter chegado ao destino do passo.
	var livre: bool = jogador.is_physics_processing() and not Dialogo.ocupado()
	if bool(passo.get("conduz", false)) and livre and _velocidade_do_jogador() < 0.2:
		_jogador_parado_s += delta
		if _jogador_parado_s >= PARADO_DEMAIS:
			_jogador_parado_s = 0.0
			if not _chegou_ao_destino():
				_pedir_situacao("parado", 10.0)
	else:
		_jogador_parado_s = 0.0
	# VIGOR ZERADO: o corpo de quem acabou de chegar. A explicação do corpo (que ele dá cansado na
	# caminhada) tem a vez; este comentário é para quem zera fora dela.
	var vigor := _fracao_do_vigor()
	if vigor <= VIGOR_ZERADO:
		if not _vigor_zerado:
			_vigor_zerado = true
			if not _cansou_na_caminhada or bool(_cadeia._levados.get(LEMBRANCA_DO_CORPO, false)):
				_pedir_situacao("vigor_zerado", 8.0)
	elif vigor >= VIGOR_RECUPERADO:
		_vigor_zerado = false


func _velocidade_do_jogador() -> float:
	if jogador == null or not ("velocity" in jogador):
		return 0.0
	return Vector2(jogador.velocity.x, jogador.velocity.z).length()


## O LADO ERRADO: a cada segundo da condução mede quanto falta do jogador ao destino. Andando e
## cada vez mais longe dele, AFASTANDO_DEMAIS amostras seguidas, e já mais longe que o Pedro, é o
## outro caminho. Quem só ficou para trás volta para o Pedro, e a distância cai.
func _vigiar_o_rumo(delta: float, onde_esta: Vector3, destino: Vector3, falta_dele: float, preso: bool) -> void:
	_amostra_s += delta
	if _amostra_s < 1.0:
		return
	_amostra_s = 0.0
	var distancia := Vector2(onde_esta.x - destino.x, onde_esta.z - destino.z).length()
	var antes := _distancia_ao_destino
	_distancia_ao_destino = distancia
	if preso or antes < 0.0 or falta_dele <= CONDUZ_ATE or _velocidade_do_jogador() < 1.5 or distancia < antes + 1.0:
		_afastando = 0
		return
	_afastando += 1
	if _afastando >= AFASTANDO_DEMAIS and distancia > falta_dele + 6.0:
		_afastando = 0
		_pedir_situacao("lado_errado", 10.0)


func _ao_nadar(nadando: bool) -> void:
	if nadando:
		_pedir_situacao("nadou", 6.0)


func _ao_trocar_a_mao(_indice: int) -> void:
	if Inventario.na_mao() == PEIXE_DO_TONHO:
		_pedir_situacao("primeiro_peixe", 60.0)


## A hora virou durante a condução. O entardecer tem o aviso dele (`_verificar_anoitecer`).
func _ao_mudar_o_periodo(periodo: String) -> void:
	if periodo != "entardecer" and Engine.get_physics_frames() - _quadro_da_conducao <= 5:
		_pedir_situacao("tempo_virou", 15.0)


## O JOGADOR CONVERSOU COM `outro` (`tecla_dos_moradores`): no meio da condução e com quem o passo
## não manda procurar, o Pedro espera.
func o_jogador_falou_com(outro: Node) -> void:
	if outro == self or not _na_chegada() or Engine.get_physics_frames() - _quadro_da_conducao > 5:
		return
	var quem := str((_cadeia.passo_atual().get("meta", {}) as Dictionary).get("a_quem", ""))
	var dele = outro.get("dados")
	var id := str((dele as Dictionary).get("id", "")) if dele is Dictionary else ""
	if id != quem:
		_pedir_situacao("outro_morador", 20.0)


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
## qualquer morador, com as falas de quem já conhece o jogador (`_escolher_a_fala`).
##
## O E nele com ele falando passa a fala (`npc.conversar`), e não a recomeça.
func conversar() -> void:
	if not _cadeia.iniciado:
		saudar()
		return
	if not terminou_o_tutorial() and not _cadeia.acabou():
		var fila := _fila()
		if fila != null and fila.falando(self):
			# O E de quem a lê passa a página, e fecha na última (#220); o de quem não a espera passa a fala.
			if not avancar_a_fala():
				fila.pular()
			return
		var texto := _cadeia.texto_do_passo()
		if texto != "":
			_ultima_saudacao_ms = Time.get_ticks_msec()
			# O passo repetido sai como o anúncio dele: fechado o passo, cala junto.
			narrar("", texto, {"classe": FilaDeFalas.Classe.CONVERSA, "no_lugar": true,
				"origem": _cadeia._origem_do_anuncio(_cadeia.passo_atual())})
			return
	super()


## AS FALAS DE DEPOIS DO TUTORIAL. "Opa! É você o moço da capital?" era a fala
## dele para sempre: o E no Pedro, acabada a chegada, caía na conversa de qualquer
## morador, e as falas dele (`falas`, no npcs_3d.json) são as do primeiro
## encontro no píer — ele se apresentava de novo a cada conversa. Depois do
## tutorial ele fala como quem já conhece o jogador: o peixe, a maré, a praça de
## noite, o arraial (`falas_depois`, nos três idiomas), alternando como as dos
## outros moradores.
func _escolher_a_fala() -> Dictionary:
	var depois: Array = dados.get("falas_depois", [])
	# DESDE QUE A CHEGADA COMEÇOU, e não só depois do tutorial (07/10: "do nada, o áudio do Pedro
	# do início do jogo — 'chegou, homem, o mestre do saveiro...' — foi reproduzido sem nexo"):
	# as falas do primeiro encontro são só do primeiro encontro. Entre o último passo e a
	# despedida, e no E sem passo a repetir, ele caía nelas de novo.
	if not _cadeia.iniciado or depois.is_empty():
		return super()
	if _proxima_fala_depois < 0:
		_proxima_fala_depois = randi() % depois.size()
	var fala: Dictionary = depois[_proxima_fala_depois % depois.size()]
	_proxima_fala_depois += 1
	return {
		"texto": String(IdiomaMenu.campo(fala, "texto", "")),
		"voz": _voz_do_arquivo(String(fala.get("audio", ""))),
	}


## OS AVISOS DE FILA TRANCADA DO PEDRO SAEM UMA VEZ CADA (`npc._fila_que_avisa`). Ele tem muitas filas
## que esperam alguma coisa (a chapada, o mirante, a fé, a lapa, as de depois do tutorial) e as
## `falas_depois` dele: o aviso a cada E tomava a conversa dele para sempre, e o jogador que só queria
## trocar uma palavra ouvia "A chapada vai esperar" de novo. Dito uma vez, ele volta às falas.
func _repete_o_aviso() -> bool:
	return false


## `narrou` avisa observadores quando a fala realmente entra no ar, não quando
## é pedida. A interface usa o balão completo e seu prazo na fila; não duplica
## esta narração em um aviso independente no rodapé.
func _comecar_a_fala(fala: Dictionary) -> void:
	super(fala)
	if bool(fala.get("narrada", false)):
		narrou.emit(str(fala.get("inteira", fala.get("texto", ""))))


## O AVISO DO ENTARDECER, com a voz dele (`anoitecer` no npcs_3d.json, nos três
## idiomas: texto de jogador não mora em constante).
func _verificar_anoitecer() -> void:
	var periodo := Dia.periodo()
	if periodo == "entardecer" and not _anoiteceu_hoje and _cadeia.espera <= 0.0 and _palavra_livre():
		_anoiteceu_hoje = true
		var aviso: Dictionary = dados.get("anoitecer", {})
		var texto := String(IdiomaMenu.campo(aviso, "texto", ""))
		if texto != "":
			narrar(String(aviso.get("audio", "")), texto, {"classe": FilaDeFalas.Classe.MISSAO, "origem": "anoitecer", "por_e": false})
	elif periodo == "manha":
		_anoiteceu_hoje = false


## Pedro só narra quando a vez de falar está livre (`npc.pode_falar`).
func _palavra_livre() -> bool:
	return pode_falar() and not fala_perto_de(jogador.global_position)


## A narração do mundo está na tela (a fila de falas diz)? A caixa espera por ela.
func _narracao_na_tela() -> bool:
	var fila := _fila()
	return fila != null and bool(fila.segura_a_caixa())


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
