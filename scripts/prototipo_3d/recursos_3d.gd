extends Node
## ONDE BATER: os alvos de trabalho do vale.
##
## O jogo 2D deixa o jogador bater em qualquer árvore ou pedra, porque lá o
## mundo é de tiles e todo tile sabe o que é. Aqui a mata são milhares de
## instâncias num `MultiMesh`, sem nó por árvore — e fazer cada uma responder
## seria refazer a mata, que é o oposto do que esta migração se propõe.
##
## Então os alvos são POSTOS, e poucos: troncos caídos e lajedos perto do
## roçado, da casa de taipa e do poço, lidos de `data/recursos_3d.json`. É o
## bastante para as ferramentas existirem de verdade — precisar da certa,
## gastar fôlego, render material — e é o que o tutorial precisa para poder
## apontar um lugar.
##
## As peças saem do `CatalogoAssets`: `lenha` e `pedras` já estavam lá, então
## nenhum modelo novo foi preciso.
##
##
## A FERRAMENTA É ESCOLHIDA PELO ALVO, e isso é uma simplificação declarada.
##
## No 2D o jogador põe a ferramenta na mão com as teclas 1 a 0. No vale, 1 a 8
## já são os gestos do personagem, e roubá-las seria mexer no que funciona.
## Então aqui a regra é: o alvo diz de que ferramenta precisa, e o golpe só
## acontece se ela estiver NA MOCHILA. "Precisa do machado" continua sendo a
## mecânica; "qual das dez mãos" espera a mochila chegar (Fase 6 do plano).

const DicaTecla = preload("res://scripts/prototipo_3d/dica_tecla.gd")
const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")
const CatalogoAssets = preload("res://scripts/prototipo_3d/catalogo_assets.gd")

const DADOS := "res://data/recursos_3d.json"
## Distância no chão para a dica aparecer e para o golpe valer.
const ALCANCE := 3.2
const ALTURA_DICA := 1.6

## Um alvo derrubado. O `Missoes` e o guia escutam para contar o trabalho.
signal derrubado(id: String, rende: String, quantidade: int)
## Bateu e não deu: sem ferramenta, ou sem fôlego. O HUD conta ao jogador.
signal recusado(motivo: String)

var _world: Node3D
var _jogador: Node3D
var _hud
var _dica: PanelContainer
## id → {"no", "pos", "ficha", "golpes_dados"}
var _alvos: Dictionary = {}
var _perto := ""


func configurar(world: Node3D, jogador: Node3D, hud) -> void:
	_world = world
	_jogador = jogador
	_hud = hud
	_dica = DicaTecla.criar(hud.map_layer(), Atalhos.letra("interagir"), "Bater")
	# OS ALVOS SÓ SOBEM COM O VALE PRONTO: eles se põem em lugares que o
	# `Lugares` resolve, e o `Lugares` só conhece o vale depois do
	# `world_builder._concluir`. Erguer antes é erguer no nada.
	if world.construido:
		_erguer()
	else:
		world.pronto.connect(_erguer, CONNECT_ONE_SHOT)


## Põe cada alvo no mundo, no lugar que o `Lugares` resolver.
##
## Lugar que o vale ainda não tem simplesmente não recebe alvo — é o mesmo
## trato do resto da migração, e o dia em que a Fase 2.5 trouxer o vau e a
## chapada, basta acrescentar linhas ao JSON.
func _erguer() -> void:
	var arquivo := FileAccess.open(DADOS, FileAccess.READ)
	if arquivo == null:
		push_warning("Recursos: não achei %s." % DADOS)
		return
	var dado = JSON.parse_string(arquivo.get_as_text())
	arquivo.close()
	if typeof(dado) != TYPE_DICTIONARY:
		push_warning("Recursos: %s não é um objeto JSON." % DADOS)
		return

	for ficha: Dictionary in dado.get("recursos", []):
		var lugar := str(ficha.get("lugar", ""))
		var base: Vector3 = Lugares.ponto(lugar)
		if base == Lugares.NENHUM:
			continue
		var desvio: Array = ficha.get("desvio", [0.0, 0.0])
		var pos := base + Vector3(float(desvio[0]), 0.0, float(desvio[1]))
		pos = _world.ground_position(pos)

		var id := str(ficha.get("id", ""))
		var no := CatalogoAssets.instanciar(str(ficha.get("peca", "")), _world, pos,
			float(ficha.get("tamanho", 1.0)))
		if no == null:
			continue
		CatalogoAssets.colisao(str(ficha.get("peca", "")), no, _world, pos,
			float(ficha.get("tamanho", 1.0)))
		_alvos[id] = {"no": no, "pos": pos, "ficha": ficha, "golpes_dados": 0}


func _process(_delta: float) -> void:
	if _jogador == null or _dica == null:
		return
	var antes := _perto
	_perto = _mais_perto()
	if _perto != antes:
		_dica.visible = _perto != ""
	if _perto == "":
		return
	var alvo: Dictionary = _alvos[_perto]
	var ficha: Dictionary = alvo["ficha"]
	# A dica diz o nome do alvo E o que falta para bater nele — a ferramenta
	# que não está na mochila, ou o fôlego que acabou. Dica que só diz "E ·
	# bater" manda o jogador apertar uma tecla que não vai fazer nada.
	DicaTecla.mostrar_em(_dica, get_viewport().get_camera_3d(),
		alvo["pos"] + Vector3(0.0, ALTURA_DICA, 0.0),
		"%s · %s" % [str(ficha.get("nome", "")), _o_que_falta(ficha)])


## O alvo ao alcance, ou "" — o mais perto quando há mais de um.
func _mais_perto() -> String:
	var melhor := ""
	var menor := ALCANCE
	for id in _alvos:
		var d: Vector3 = _alvos[id]["pos"] - _jogador.global_position
		d.y = 0.0
		var dist := d.length()
		if dist < menor:
			menor = dist
			melhor = id
	return melhor


## O que a dica diz depois do nome: a ferramenta que falta, ou o que vai render.
func _o_que_falta(ficha: Dictionary) -> String:
	var ferramenta := str(ficha.get("ferramenta", ""))
	if not Inventario.tem(ferramenta):
		return "precisa de %s" % _nome_do_item(ferramenta)
	if not Energia.aguenta("bater"):
		return "sem fôlego"
	return "com %s" % _nome_do_item(ferramenta)


func _nome_do_item(id: String) -> String:
	var item: Dictionary = Catalogo.ITENS.get(id, {})
	return str(item.get("nome", id))


## O GOLPE.
##
## A ordem das recusas importa e é a do 2D: primeiro a ferramenta, depois o
## fôlego. Quem não tem machado precisa saber que é do machado que precisa, e
## não que está cansado — a segunda informação não ajuda em nada.
func bater() -> bool:
	if _perto == "":
		return false
	var alvo: Dictionary = _alvos[_perto]
	var ficha: Dictionary = alvo["ficha"]
	var ferramenta := str(ficha.get("ferramenta", ""))

	if not Inventario.tem(ferramenta):
		recusado.emit("Precisa de %s." % _nome_do_item(ferramenta))
		return false
	if not Energia.gastar("bater"):
		recusado.emit("Sem fôlego para bater.")
		return false

	alvo["golpes_dados"] = int(alvo["golpes_dados"]) + 1
	var faltam := int(ficha.get("golpes", 3)) - int(alvo["golpes_dados"])
	if faltam > 0:
		_sacudir(alvo["no"])
		return true

	# Caiu: some do mundo e vira material na mochila.
	var rende := str(ficha.get("rende", ""))
	var quantos := int(ficha.get("quantidade", 1))
	Inventario.adicionar(rende, quantos)
	var no: Node3D = alvo["no"]
	if is_instance_valid(no):
		no.queue_free()
	var id := _perto
	_alvos.erase(id)
	_perto = ""
	_dica.visible = false
	derrubado.emit(id, rende, quantos)
	return true


## Um tranco na peça a cada golpe, para o jogador ver que acertou. Não é
## animação: é a peça recuando e voltando, que é o bastante para a batida ter
## resposta e não custa arte nenhuma.
func _sacudir(no: Node3D) -> void:
	if not is_instance_valid(no):
		return
	var de := no.position
	var tween := no.create_tween()
	tween.tween_property(no, "position", de + Vector3(0.0, -0.08, 0.0), 0.06)
	tween.tween_property(no, "position", de, 0.12)


## Quantos alvos daquele rendimento ainda estão de pé. O guia usa para saber
## se a missão de lenha ainda tem onde acontecer.
func restantes(rende: String = "") -> int:
	var conta := 0
	for id in _alvos:
		var ficha: Dictionary = _alvos[id]["ficha"]
		if rende == "" or str(ficha.get("rende", "")) == rende:
			conta += 1
	return conta


## A TECLA DE INTERAGIR BATE, e ela é a mesma que lê lápide e ficha de árvore.
##
## Quem chega primeiro no `_unhandled_key_input` ganha o evento, e este nó é
## acrescentado DEPOIS do `ArvoresInfo` — a árvore de propósito vem antes,
## porque ficha de árvore e tronco caído podem estar ao alcance ao mesmo tempo
## e ler é o que não gasta fôlego. Com alvo ao alcance, o golpe consome a
## tecla; sem alvo, ela passa adiante para quem mais a espera.
func _unhandled_key_input(event: InputEvent) -> void:
	if _perto == "":
		return
	if not (event is InputEventKey and event.pressed and not event.echo
			and event.physical_keycode == Atalhos.tecla("interagir")):
		return
	bater()
	get_viewport().set_input_as_handled()
