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
## O ALVO DIZ DE QUE FERRAMENTA PRECISA, E ELA TEM DE ESTAR NA MÃO.
##
## Começou como simplificação — bastava a ferramenta na mochila, enquanto a
## barra de mão não existia. A barra chegou (teclas 1 a 0, como no 2D; os
## gestos ficaram no Alt), e a simplificação virou defeito: com o machado na
## mão, o capim da foice se cortava. Ver `_tem_ferramenta`.

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
## Quantos alvos de cada peça — e de cada grupo — foram POSTOS no mundo, para a
## conta de quantos já caíram: alvo derrubado some de `_alvos`, e sem este
## número não haveria de onde subtrair. Ver `derrubados`.
var _postos: Dictionary = {}
## Os ids dos alvos que já caíram nesta partida, para o save. Ver `caidos`.
var _caidos: Array[String] = []


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

		# A COLISÃO É UM NÓ SEPARADO, e é preciso guardá-la.
		#
		# `CatalogoAssets.colisao` não põe a forma dentro da peça: ela cria um
		# `StaticBody3D` irmão, filho do mundo. Faz sentido para cenário, que
		# nunca sai — mas alvo de trabalho SAI, e a primeira versão disto
		# liberava só o visual. O tronco desaparecia e continuava barrando o
		# caminho: colisão invisível no meio do roçado, que foi a queixa.
		#
		# Quais filhos do mundo nasceram desta chamada só se sabe olhando antes
		# e depois — então é o que se faz.
		var antes := _world.get_child_count()
		CatalogoAssets.colisao(str(ficha.get("peca", "")), no, _world, pos,
			float(ficha.get("tamanho", 1.0)))
		var corpos: Array[Node] = []
		for i in range(antes, _world.get_child_count()):
			corpos.append(_world.get_child(i))

		# A MEIA-PEGADA: o quanto este alvo empurra o jogador para longe do
		# próprio centro. É o que o alcance do golpe soma, para "encoste e
		# aperte E" valer em peça de qualquer tamanho. Ver `_mais_perto`.
		var meia := 0.0
		for corpo in corpos:
			for forma_no in (corpo as Node).get_children():
				if not (forma_no is CollisionShape3D):
					continue
				var forma = (forma_no as CollisionShape3D).shape
				if forma is BoxShape3D:
					var caixa := (forma as BoxShape3D).size
					meia = maxf(meia, maxf(caixa.x, caixa.z) * 0.5)
				elif forma is CylinderShape3D:
					meia = maxf(meia, (forma as CylinderShape3D).radius)

		var peca := str(ficha.get("peca", ""))
		_postos[peca] = int(_postos.get(peca, 0)) + 1
		var grupo := str(ficha.get("grupo", ""))
		if grupo != "":
			_postos[grupo] = int(_postos.get(grupo, 0)) + 1
		_alvos[id] = {"no": no, "pos": pos, "ficha": ficha, "golpes_dados": 0,
			"corpos": corpos, "meia_pegada": meia}


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
## O ALVO AO ALCANCE DO BRAÇO, medido da SUPERFÍCIE dele e não do centro.
##
## Era aqui o defeito da missão da picareta, e ele durou três rodadas porque
## cada conserto olhou uma parte diferente: que o alvo existe, que o golpe
## funciona, que a meta fecha pela meta. Nada disso era o problema.
##
## O problema era ARITMÉTICA. O lajedo é a peça `pedras` em tamanho 2,2, e a
## caixa de colisão dela fica com 6,6 de lado — 3,30 do centro até a face. O
## alcance era 3,20 do CENTRO. O corpo do jogador esbarra na face e para a
## 3,30; o golpe exigia chegar a 3,20. Folga negativa de dez centímetros, e
## nenhuma quantidade de insistência resolvia: o lajedo era fisicamente
## inalcançável.
##
## Medir do centro só funciona enquanto os alvos são pequenos. Agora o alcance
## é somado à meia-pegada de cada um, que é o quanto ele empurra o jogador para
## longe do próprio centro — e aí "encoste e aperte E" volta a ser verdade para
## qualquer tamanho de peça.
##
## NA LAVOURA, A TECLA É DELA: os pés de cana e a lenha da beira do roçado
## ficam a um alcance do campo, e o E que ara o leito batia na cana.
##
## E A PAREDE SEPARA. A lenha da casa de taipa fica do lado de fora da parede
## direita, perto o bastante para o alcance passar por ela: de dentro da casa,
## junto do fogão, o E oferecia a lenha. Quem está dentro de um cômodo só
## alcança o que está dentro dele, e quem está fora, o que está fora.
func _mais_perto() -> String:
	var melhor := ""
	var menor := INF
	var lavoura := get_tree().get_first_node_in_group("lavoura") if is_inside_tree() else null
	if lavoura != null and lavoura.no_campo(_jogador.global_position):
		return ""
	var interiores := get_tree().get_first_node_in_group("interiores") if is_inside_tree() else null
	var lado_do_jogador: String = interiores.contem(_jogador.global_position) if interiores != null else ""
	for id in _alvos:
		var d: Vector3 = _alvos[id]["pos"] - _jogador.global_position
		d.y = 0.0
		var sobra: float = d.length() - float(_alvos[id].get("meia_pegada", 0.0))
		if sobra < ALCANCE and sobra < menor:
			if interiores != null and interiores.contem(_alvos[id]["pos"]) != lado_do_jogador:
				continue
			menor = sobra
			melhor = id
	return melhor


## O que a dica diz depois do nome: a ferramenta que falta, ou o que vai render.
func _o_que_falta(ficha: Dictionary) -> String:
	var ferramenta := str(ficha.get("ferramenta", ""))
	if ferramenta == "":
		return tr("à mão") if Energia.aguenta("bater") else "sem fôlego"
	if not _tem_ferramenta(ferramenta):
		if Inventario.tem(ferramenta):
			return tr("ponha na mão: %s") % _nome_do_item(ferramenta)
		return "precisa de %s" % _nome_do_item(ferramenta)
	if not Energia.aguenta("bater"):
		return "sem fôlego"
	return "com %s" % _nome_do_item(ferramenta)


func _nome_do_item(id: String) -> String:
	var item: Dictionary = Catalogo.ITENS.get(id, {})
	return str(item.get("nome", id))


## A FERRAMENTA DO ALVO TEM DE ESTAR NA MÃO — pelo número da barra, ou vestida
## em "Mãos" —, e não só na mochila.
##
## "Na missão de introdução da foice eu consegui fazer a animação usando o
## machado. Cada ferramenta tem seus pontos de interação e nenhuma deve invadir
## a interação da outra." O capim pedia foice e conferia só se ela estava na
## mochila: com o machado na mão e a foice guardada, o E cortava o capim com o
## golpe e o machado no braço. A pesca (vara) e o coqueiro (machado) já
## perguntavam pela mão; os alvos de trabalho passam a perguntar também.
func _tem_ferramenta(id: String) -> bool:
	# SEM FERRAMENTA É À MÃO: a ostra se cata na pedra (#52).
	return id == "" or Equipamento.em_uso(id)


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

	if not _tem_ferramenta(ferramenta):
		# Carregando a certa e segurando outra (ou nada): diz qual pôr na mão.
		if Inventario.tem(ferramenta):
			recusado.emit(tr("Ponha na mão: %s.") % _nome_do_item(ferramenta))
		else:
			recusado.emit("Precisa de %s." % _nome_do_item(ferramenta))
		return false
	if not Energia.gastar("bater"):
		recusado.emit("Sem fôlego para bater.")
		return false

	_golpear_com_o_corpo()
	alvo["golpes_dados"] = int(alvo["golpes_dados"]) + 1
	var faltam := int(ficha.get("golpes", 3)) - int(alvo["golpes_dados"])
	if faltam > 0:
		_sacudir(alvo["no"])
		return true

	# Caiu: some do mundo e vira material na mochila.
	var rende := str(ficha.get("rende", ""))
	var quantos := int(ficha.get("quantidade", 1))
	# ALVO QUE NÃO RENDE NADA É ALVO QUE SÓ SE LIMPA, e o capim do cemitério é
	# o primeiro. No 2D, cortar o mato não põe nada na mochila: o mato some, e
	# é isso que limpar quer dizer. Sem esta guarda, `adicionar("")` empilharia
	# um item de id vazio na mochila do jogador a cada pé cortado.
	if rende != "":
		Inventario.adicionar(rende, quantos)
	var no: Node3D = alvo["no"]
	if is_instance_valid(no):
		no.queue_free()
	# E A COLISÃO COM ELE. Ver o comentário em `_erguer`: ela é nó irmão, e
	# esquecê-la deixa o caminho barrado por um tronco que não existe mais.
	for corpo in alvo.get("corpos", []):
		if is_instance_valid(corpo):
			corpo.queue_free()
	var id := _perto
	_alvos.erase(id)
	if not _caidos.has(id):
		_caidos.append(id)
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
	# COM O CORPO PARADO, O E NÃO VALE PARA O MUNDO, como nos achados, na pesca
	# e na luta. No escuro da queda o jogador já está na porta de casa, e o E
	# batia no tronco ao lado dela sem corpo nenhum de pé para bater.
	if not _jogador.is_physics_processing():
		return
	bater()
	get_viewport().set_input_as_handled()


## O CORPO GOLPEIA, e o clipe já existia.
##
## O personagem tem nove gestos no GLB, e o de índice 6 é `chop` — "Golpear".
## Ele estava ali desde o começo, acessível só por tecla de demonstração, e
## nenhum trabalho o usava: bater era um número caindo sem ninguém se mexer.
##
## Em terceira pessoa o personagem já olha para onde a câmera olha, e quem bate
## está de frente para o que bate — então não há para onde virá-lo. O que
## faltava era só o gesto.
const GESTO_GOLPEAR := 6


func _golpear_com_o_corpo() -> void:
	if not is_instance_valid(_jogador):
		return
	var animador = _jogador.animator
	if animador != null and animador.has_method("play_gesture"):
		animador.play_gesture(GESTO_GOLPEAR)


## ONDE ESTÁ O ALVO MAIS PERTO QUE RENDE ISTO, ou `Lugares.NENHUM`.
##
## É o que o guia pergunta para pôr o marcador da missão no lugar certo. Antes
## ele marcava a ÂNCORA do passo — a casa, o roçado — e mandava o jogador a um
## lugar onde não havia o que bater. "Marca a casa quando devia marcar os
## troncos", nas palavras de quem jogou.
func mais_perto_que_rende(item: String, de: Vector3) -> Vector3:
	var melhor: Vector3 = Lugares.NENHUM
	var menor := INF
	for id in _alvos:
		var ficha: Dictionary = _alvos[id]["ficha"]
		if str(ficha.get("rende", "")) != item:
			continue
		var d: Vector3 = _alvos[id]["pos"] - de
		d.y = 0.0
		if d.length() < menor:
			menor = d.length()
			melhor = _alvos[id]["pos"]
	return melhor


## QUANTOS ALVOS DESTA PEÇA JÁ CAÍRAM.
##
## A missão do cemitério pede "corte quatro pés de capim", e capim cortado não
## vai para a mochila — então contar pela mochila não serve. Conta-se pela
## diferença: quantos foram POSTOS no mundo menos quantos ainda estão de pé.
##
## Pela PEÇA, e não pelo que rende, porque o que o passo pede é o pé cortado e
## não o material: dois alvos de peças diferentes podem render a mesma coisa.
##
## OU PELO GRUPO, quando o pedido junta peças diferentes: o mato do cemitério é
## embaúba nova e galhada caída (`"grupo": "mato_do_cemiterio"` no JSON), e o
## Damião pede o mato, não a peça. O grupo é só mais um nome que o alvo atende.
func derrubados(peca: String) -> int:
	return int(_postos.get(peca, 0)) - _de_pe(peca)


## Quantos alvos desta peça (ou deste grupo) ainda estão de pé.
func _de_pe(peca: String) -> int:
	var conta := 0
	for id in _alvos:
		if _atende(_alvos[id]["ficha"], peca):
			conta += 1
	return conta


## O alvo desta ficha atende pelo nome `peca` — o da peça ou o do grupo dele?
static func _atende(ficha: Dictionary, peca: String) -> bool:
	return str(ficha.get("peca", "")) == peca or (peca != "" and str(ficha.get("grupo", "")) == peca)


## ONDE ESTÁ O ALVO MAIS PERTO DESTA PEÇA (ou deste grupo), ou `Lugares.NENHUM`.
##
## É o `mais_perto_que_rende` para os que não rendem nada. O losango do
## cemitério mostra o pé de capim mais perto, e quando ele parar de mostrar,
## acabou — que é literalmente o que o Damião diz no jogo 2D.
func mais_perto_da_peca(peca: String, de: Vector3) -> Vector3:
	var melhor: Vector3 = Lugares.NENHUM
	var menor := INF
	for id in _alvos:
		if not _atende(_alvos[id]["ficha"], peca):
			continue
		var d: Vector3 = _alvos[id]["pos"] - de
		d.y = 0.0
		if d.length() < menor:
			menor = d.length()
			melhor = _alvos[id]["pos"]
	return melhor


## OS ALVOS QUE JÁ CAÍRAM, por id, para o save.
##
## Sem isto, recarregar a partida faz o vale renascer inteiro: os troncos
## voltam de pé e o capim que o jogador passou a manhã cortando está lá outra
## vez. Para a lenha e a pedra chega a ser bem-vindo — material já está na
## mochila e o vale se refaz —, mas para o capim é a missão do cemitério
## desandando: a meta dela conta pé DERRUBADO, e pé que renasceu não conta.
func caidos() -> Array:
	return _caidos.duplicate()


## ESQUECE ALVOS QUE JÁ TINHAM CAÍDO NA PARTIDA SALVA.
##
## Chamado depois do `_erguer`, porque o vale se monta antes de o save entrar
## (ver `Prototype.restaurar_do_save`). Tira o visual, tira a colisão irmã — a
## mesma que ficava barrando o caminho quando só o visual era liberado — e
## conta o pé como caído, para a meta da missão continuar valendo.
func esquecer(ids: Array) -> void:
	for bruto in ids:
		var id := str(bruto)
		if not _alvos.has(id):
			continue
		var alvo: Dictionary = _alvos[id]
		var no: Node3D = alvo["no"]
		if is_instance_valid(no):
			no.queue_free()
		for corpo in alvo.get("corpos", []):
			if is_instance_valid(corpo):
				corpo.queue_free()
		_alvos.erase(id)
		if not _caidos.has(id):
			_caidos.append(id)
	if _perto != "" and not _alvos.has(_perto):
		_perto = ""
		if _dica != null:
			_dica.visible = false
