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
## que vai apresentar." No passo com `conduz` ele anda pela malha até quem o
## passo apresenta (ou até o lugar dele) e para a CONDUZ_ATE dele; o jogador vai
## atrás. Ficando o jogador a mais de ESPERA_QUEM_FICA, ele para e espera,
## virado para ele, e só volta a andar com o jogador a VOLTA_A_ANDAR. Anda no
## passo do jogador: correndo se ele corre.
const CONDUZ_ATE := 2.4
const ESPERA_QUEM_FICA := 5.5
const VOLTA_A_ANDAR := 3.0
## OS MARCOS DA ESTRADA (playtest de 07/10: "depois de falar na praça, o Pedro tá
## saindo correndo sem esperar o jogador; o ideal é ter alguns marcos ao longo da
## estrada onde o Pedro espera o jogador chegar"). A cada MARCO unidades andadas
## desde a última espera ele para, vira-se para o jogador e espera que ele chegue a
## CHEGOU_AO_MARCO; e não dá um passo enquanto o jogador não pode andar (a caixa de
## fala aberta, o corpo parado): era assim que ele ganhava a dianteira na praça.
const MARCO := 11.0
const CHEGOU_AO_MARCO := 3.0
var _andado_desde_o_marco := 0.0
var _no_marco := false
## NÃO FICA ATOLADO NO MEIO DO CAMINHO. A malha pode mandar por um corpo que ela não conhecia (uma peça
## nova da cena, a casca de um prédio): o Pedro anda contra ele sem sair do lugar, o jogador espera atrás
## ("o Pedro está esperando você") e o tutorial para ali para sempre — a partida jogada do zero ficou 600 s
## de jogo parada na rua da praça. Depois de DESATOLA_APOS segundos de passo sem sair do lugar, ele salta
## para o ponto livre do caminho mais adiante (o primeiro de DESATOLA_PULOS que não tem corpo em cima).
const DESATOLA_APOS := 10.0
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
	var destino := _destino_da_conducao(cadeia)
	var onde_esta: Vector3 = jogador.global_position
	var do_jogador := Vector2(onde_esta.x - global_position.x, onde_esta.z - global_position.z).length()
	if _esperando_quem_ficou:
		_esperando_quem_ficou = do_jogador > VOLTA_A_ANDAR
	elif do_jogador > ESPERA_QUEM_FICA:
		_esperando_quem_ficou = true
		_pedir_situacao("ficou_atras", 10.0)
	var falta := destino - global_position
	falta.y = 0.0
	# O JOGADOR NÃO PODE ANDAR (a caixa de fala aberta, o corpo parado): ele espera.
	var jogador_preso: bool = not jogador.is_physics_processing() or Dialogo.ocupado()
	if cadeia == null:
		_vigiar_o_rumo(delta, onde_esta, destino, falta.length(), jogador_preso)
	# O MARCO: andou um trecho, para e espera o jogador chegar perto — a não ser que o
	# destino já esteja logo ali.
	if _no_marco:
		if do_jogador <= CHEGOU_AO_MARCO:
			_no_marco = false
			_andado_desde_o_marco = 0.0
	elif _andado_desde_o_marco >= MARCO and falta.length() > CONDUZ_ATE + MARCO * 0.5 and do_jogador > CHEGOU_AO_MARCO:
		_no_marco = true
	# O AVISO SÓ NO MEIO DO CAMINHO: chegado, o que o passo pede é perto dele (quem
	# ele apresenta, a porta da casa), e quem anda por ali está fazendo o passo.
	_quadro_da_conducao = Engine.get_physics_frames()
	_avisar_quem_ficou((_esperando_quem_ficou or _no_marco) and not jogador_preso and falta.length() > CONDUZ_ATE)
	if _esperando_quem_ficou or _no_marco or jogador_preso or falta.length() <= CONDUZ_ATE:
		_atolado_s = 0.0
		_mover(Vector3.ZERO, ANDAR, delta)
		_olhar_para(onde_esta, delta)
		if falta.length() <= CONDUZ_ATE:
			_andado_desde_o_marco = 0.0
			if cadeia == null and do_jogador <= ESPERA_QUEM_FICA and str(_cadeia.passo_atual().get("id", "")) == PASSO_DA_CANDINHA:
				_pedir_situacao("chegada_candinha", 15.0)
		return
	var ponto := _ponto_do_caminho(destino, delta)
	var rumo := ponto - global_position
	rumo.y = 0.0
	# CORRE SÓ SE O JOGADOR CORRE DE FATO (o passo trocado para a corrida, parado,
	# fazia o Pedro disparar enquanto o jogador ainda lia a caixa).
	var depressa: float = Vector2(jogador.velocity.x, jogador.velocity.z).length() if "velocity" in jogador else 0.0
	var correndo := jogador.has_method("is_running") and bool(jogador.call("is_running")) and depressa > ANDAR * 1.2
	var antes_de_andar := global_position
	_mover(rumo.normalized() if rumo.length() > 0.05 else Vector3.ZERO, CORRER if correndo else ANDAR, delta)
	_andado_desde_o_marco += Vector2(global_position.x - antes_de_andar.x, global_position.z - antes_de_andar.z).length()
	_pedir_passagem(rumo)
	var andou := Vector2(get_real_velocity().x, get_real_velocity().z).length()
	if rumo.length() > 0.05 and andou < ANDAR * 0.25:
		_atolado_s += delta
		if _atolado_s >= DESATOLA_APOS:
			_atolado_s = 0.0
			_saltar_para_o_caminho_livre()
	else:
		_atolado_s = maxf(_atolado_s - delta * 2.0, 0.0)


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
	if not terminou_o_tutorial() or depois.is_empty():
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
			narrar(String(aviso.get("audio", "")), texto, {"classe": FilaDeFalas.Classe.MISSAO, "origem": "anoitecer"})
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
