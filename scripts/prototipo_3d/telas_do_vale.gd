extends Node
## AS TELAS DO VALE, E A REGRA DE QUE SÓ UMA FICA ABERTA.
##
## Antes cada tela cuidava da própria tecla, em cinco arquivos diferentes: a
## mochila no `barra_de_mao.gd`, o almanaque no `almanaque.gd`, o painel e a
## coleção no `prototype.gd`, e cada um deles com o Esc dele. Cada tela sabia
## abrir e fechar a si mesma e NÃO SABIA DAS OUTRAS.
##
## Isso produziu duas queixas que são a mesma:
##
##   "Quando tava no Menu de missão, apertei o Menu do Almanaque e ele abriu
##    ATRÁS do da missão."
##
##   "Quando sai do almanaque, a tela tava destravada, igual aos erros que já
##    corrigimos no passado."
##
## A segunda é consequência da primeira, e é por isso que ela voltou depois de
## consertada. Quem guarda o modo de câmera é o `Prototype`, numa gaveta só
## (`_camera_travada_antes`): o painel abre e guarda "travada", o almanaque abre
## POR CIMA e guarda o que acha agora — que é "solta", porque o painel já
## soltou. Fechar o almanaque devolve "solta". A gaveta não estava errada; o
## empilhamento de telas é que não devia existir.
##
## Então em vez de dar uma gaveta a cada tela — o que faria a terceira nascer
## esquecendo a sua —, a regra passa a ser UMA TELA DE CADA VEZ. Abrir uma fecha
## a que estiver aberta, e o par guardar/devolver da câmera nunca se aninha.
##
##
## POR QUE `_input` E NÃO `_unhandled_key_input`
##
## As telas continuam ouvindo as próprias teclas de NAVEGAÇÃO — Tab troca de
## aba, W/S andam, E confirma — no `_unhandled_input` delas. Se este nó
## escutasse ali também, quem ganharia o evento dependeria da ordem da árvore, e
## ordem de árvore é o tipo de coisa que muda quando alguém acrescenta um nó.
##
## `_input` roda ANTES de todo `_unhandled_*`, para qualquer nó. Aqui só passam
## as teclas de ABRIR E FECHAR; o resto segue adiante intacto.
##
## E este nó roda em `PROCESS_MODE_ALWAYS`, porque as telas pausam o vale: nó
## pausável perderia a tecla que fecha a tela que o pausou.

## A tela que está aberta mudou. O `Prototype` escuta para pausar e devolver a
## câmera num lugar só.
signal tela_mudou(nome: String, aberta: bool)

## Cada tela: nome, "esta tecla é minha?", "estou aberta?", abrir e fechar.
var _telas: Array[Dictionary] = []

## QUEM SEGURA O JOGADOR SEM SER TELA: a fala longa (#21). O vale preenche.
##
## Enquanto ela estiver aberta, nenhuma tecla abre nem fecha tela: o I não abre
## a mochila por cima da conversa e o J não interrompe o Pedro no meio da frase.
## E o Esc segue adiante sem fechar nada, porque é dela — na pergunta, Esc é
## "Não", e quem responde é a caixa. Ela lê o teclado pelo `Input`, então a
## tecla não precisa ser consumida aqui para chegar lá.
var ocupado: Callable

## Este nó está fechando uma tela agora? Ver `fechou_por_conta`.
var _fechando := false


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Registra uma tela. `minha` recebe o evento de tecla e diz se é a dela — assim
## serve tanto para ação do InputMap quanto para letra da tabela de atalhos, sem
## este nó precisar saber qual é qual.
func registrar(nome: String, minha: Callable, aberta: Callable,
		abrir: Callable, fechar: Callable) -> void:
	_telas.append({"nome": nome, "minha": minha, "aberta": aberta,
		"abrir": abrir, "fechar": fechar})


## O nome da tela aberta, ou "" se nenhuma está.
func aberta() -> String:
	for tela in _telas:
		if bool((tela["aberta"] as Callable).call()):
			return str(tela["nome"])
	return ""


## Fecha o que estiver aberto. Devolve o nome do que fechou, ou "".
func fechar_tudo() -> String:
	var qual := ""
	for tela in _telas:
		if bool((tela["aberta"] as Callable).call()):
			qual = str(tela["nome"])
			_fechar(tela)
			tela_mudou.emit(qual, false)
	return qual


## UMA TELA QUE FECHOU SOZINHA, sem passar por aqui.
##
## O folheto (#21) se guarda com o E ou o clique dentro dele, como no 2D, e só
## ele sabe disso: sem este aviso o vale ficaria parado atrás de papel nenhum.
## Quando é ESTE nó que fecha a tela, ela avisa igual, e o aviso é ignorado —
## o `tela_mudou` já saiu daqui, e sair duas vezes devolveria a câmera duas.
func fechou_por_conta(nome: String) -> void:
	if _fechando:
		return
	tela_mudou.emit(nome, false)


func _fechar(tela: Dictionary) -> void:
	_fechando = true
	(tela["fechar"] as Callable).call()
	_fechando = false


## Abre uma tela pelo nome, fechando antes a que estiver aberta.
##
## Apertar a tecla da tela JÁ ABERTA fecha, que é o que toda tela de menu faz.
## Com a fala aberta, não abre nada — nem pela tecla, nem pelo botão do HUD.
func abrir(nome: String) -> void:
	if _segurado():
		return
	for tela in _telas:
		if str(tela["nome"]) != nome:
			continue
		if bool((tela["aberta"] as Callable).call()):
			_fechar(tela)
			tela_mudou.emit(nome, false)
			return
		fechar_tudo()
		(tela["abrir"] as Callable).call()
		# Abrir pode ser recusado por quem abre (o painel recusa com o mapa
		# aberto, por exemplo). O aviso só sai se a tela de fato abriu.
		if bool((tela["aberta"] as Callable).call()):
			tela_mudou.emit(nome, true)
		return


func _segurado() -> bool:
	return ocupado.is_valid() and bool(ocupado.call())


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if _segurado():
		return

	# O ESC FECHA A TELA ABERTA, e só isso. Sem tela aberta ele NÃO é consumido:
	# quem cuida dele daí em diante é a escada do `Prototype`, que fecha o mapa
	# ou abre o menu. Consumir o Esc aqui em todo caso mataria o menu.
	if event.physical_keycode == KEY_ESCAPE:
		if fechar_tudo() != "":
			get_viewport().set_input_as_handled()
		return

	for tela in _telas:
		if not bool((tela["minha"] as Callable).call(event)):
			continue
		abrir(str(tela["nome"]))
		get_viewport().set_input_as_handled()
		return
