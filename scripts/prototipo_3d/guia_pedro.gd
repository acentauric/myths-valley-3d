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
## corre se ficou para trás. Com o jogador PARA TRÁS mais que VOLTA_POR_QUEM_FICA, ele
## VOLTA pelo caminho até ele, em vez de parar no meio da estrada esperando uma
## aproximação que o jogador não entendia; a VOLTA_A_ANDAR dele, retoma. Enquanto o
## jogador não pode andar (a caixa de fala aberta, o corpo parado), ele espera. Os
## marcos de antes (parar a cada onze passos) saíram: eram a espera que confundia.
const CONDUZ_ATE := 2.4
const VOLTA_POR_QUEM_FICA := 5.5
const VOLTA_A_ANDAR := 3.0
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
	# EM CENA (cena_vale.gd), a cena manda nele, como no 2D (`Pedro._em_cena`).
	if _em_cena:
		_passo_da_cena(delta)
		return
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
	_quadro_da_conducao = Engine.get_physics_frames()
	# O JOGADOR NÃO PODE ANDAR (a caixa de fala aberta, o corpo parado): ele espera. E chegado,
	# o que o passo pede é perto dele (quem ele apresenta, a porta da casa).
	var jogador_preso: bool = not jogador.is_physics_processing() or Dialogo.ocupado()
	if jogador_preso or falta.length() <= CONDUZ_ATE:
		_atolado_s = 0.0
		_esperando_quem_ficou = false
		_avisar_quem_ficou(false)
		_mover(Vector3.ZERO, ANDAR, delta)
		_olhar_para(onde_esta, delta)
		return
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
	if _esperando_quem_ficou:
		_esperando_quem_ficou = atraso > VOLTA_A_ANDAR and do_jogador > VOLTA_A_ANDAR
	elif atraso > VOLTA_POR_QUEM_FICA and do_jogador > VOLTA_POR_QUEM_FICA:
		_esperando_quem_ficou = true
	_avisar_quem_ficou(_esperando_quem_ficou)
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
	for i in get_slide_collision_count():
		var colisao := get_slide_collision(i)
		var corpo := colisao.get_collider()
		if corpo == null or corpo == self or not corpo.has_method("dar_passagem"):
			continue
		var empurrao := -colisao.get_normal()
		empurrao.y = 0.0
		if empurrao.length_squared() > 0.0001 and empurrao.normalized().dot(direcao) > 0.3:
			corpo.dar_passagem(empurrao)


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
	var linhas: Array = []
	var vozes: Array = []
	for fala in _corpo:
		if not (fala is Dictionary):
			continue
		var quando := str((fala as Dictionary).get("quando", ""))
		if quando != "" and quando != ("cansado" if cansado else "descansado"):
			continue
		linhas.append(str(IdiomaMenu.campo(fala, "texto", "")))
		vozes.append(str((fala as Dictionary).get("audio", "")))
	Dialogo.falar(str(dados.get("nome", "Pedro")), linhas, vozes)


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


## A FALA DO PEDRO VAI PARA O AVISO DO HUD (`narrou`) quando ela entra no ar, e
## não quando é pedida: com a fila de falas ela pode esperar a vez, e o aviso
## tem de dizer o que está no balão.
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
