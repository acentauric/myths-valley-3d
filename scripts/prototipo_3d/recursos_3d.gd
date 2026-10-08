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
##
##
## A COBRANÇA SAI NO IMPACTO, E NÃO NO APERTO (#112).
##
## "Aperto E várias vezes e consome a stamina várias vezes. Mas só acontece uma
## animação e o item não vai parar no inventário até que a animação termine."
## A reserva era cobrada no E, e o golpe acontecia no impacto do clipe; o clipe
## que o corpo ainda andando cortava não dava impacto, o alvo só sofria o golpe
## por um temporizador de 1,5 s, a trava caía a 1,25 s e o E seguinte
## reiniciava o clipe no meio. Agora o E só confere se há com que pagar
## (`bater`); a cobrança e o golpe saem juntos, no impacto
## (`_ao_impacto_do_golpe`); a trava dura o clipe inteiro; e um clipe que morre
## solta a trava sem cobrar nem bater (`_cancelar_golpe`). O E durante o golpe
## não faz nada. Portão `golpe_repetido`.
## PEDRA PEQUENA SE QUEBRA, PEDRA GRANDE É CENÁRIO.
##
## "Algumas pedras que são quebráveis estão grandes demais, precisam ficar
## pequenas; precisamos de pedras quebráveis pequenas e grandes não quebráveis."
## O lajedo do poço era a peça `pedras` em tamanho 2,2 — 6,6 de largura por 4,1 de
## altura, mais alto que o jogador — e quebrava e sumia no último golpe. A regra
## agora é do motor: a ficha que rende pedra só vira alvo se o desenho posto cabe na
## mão (`pedra_pequena`: até 1,25 de largura e 0,8 de altura). O que passa disso fica
## no mundo como CENÁRIO — com corpo, sem E, sem golpe — e mora na seção "fixas" do
## JSON (`_fixas`). A ficha que rende pedra, é grande e não tem a razão escrita
## (`grande_de_proposito`) é rebaixada a cenário, com aviso (`rebaixados`), e o
## `tests/pedras.gd` reprova. A exceção é a lapa da lombada: é a pedra da missão.
##
##
## O GOLPE TEM SOM.
##
## Pedra, tronco, capim e ostra batiam em silêncio, e o `picareta.mp3` estava
## órfão. Cada impacto toca o som da ferramenta pelo `Audio` (`SONS_DO_GOLPE`), e o
## último golpe do alvo que cai toca o dele (`SONS_DO_ULTIMO`). As tabelas já
## esperam os nomes que o gerador de efeitos vai dar (`marretada_pedra`,
## `pedra_quebra`, `foice_capim`...): o que existe na pasta toca, e o que ainda não
## existe cai no som que já há — no dia em que o arquivo chegar, toca sem mexer em código.

const DicaTecla = preload("res://scripts/prototipo_3d/dica_tecla.gd")
const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")
const CatalogoAssets = preload("res://scripts/prototipo_3d/catalogo_assets.gd")
const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")
const CoqueiroCortado = preload("res://scripts/prototipo_3d/coqueiro_cortado.gd")
const FocoDoE = preload("res://scripts/prototipo_3d/foco_do_e.gd")

const DADOS := "res://data/recursos_3d.json"
## Distância no chão para a dica aparecer e para o golpe valer.
const ALCANCE := 3.2
const ALTURA_DICA := 1.6
const TEMPO_ATE_IMPACTO := 0.3
const TEMPO_LIMITE_IMPACTO := 1.5
const TEMPO_LIMITE_FIM_DO_GOLPE := 1.25
const TEMPO_MAXIMO_DO_GOLPE := 5.0

## PEDRA QUE SE QUEBRA CABE NA MÃO: até esta largura e esta altura, em unidades (o
## jogador tem 1,75), medidas no desenho posto. Ver `pedra_pequena`.
const PEDRA_MAX_LARGURA := 1.25
const PEDRA_MAX_ALTURA := 0.8

## OS SONS DO GOLPE, do mais certo ao que existe hoje: o primeiro da lista que está na
## pasta é o que toca. A chave é "ferramenta/rende", ou só "ferramenta" (a mão é "");
## `SONS_DO_ULTIMO` é o do último golpe do alvo, e sem arquivo ele soa como os outros.
## Os nomes à frente de cada lista (`marretada_pedra`, `foice_capim`, `catar_ostra`,
## `galho_quebra`, `pedra_quebra`) ainda não têm arquivo: quem espera está em
## `sons_que_faltam`. A ficha pode mandar o seu: `"som"` e `"som_do_ultimo"`.
const PASTA_DOS_SONS := "res://assets/audio/efeitos/"
const SONS_DO_GOLPE := {
	"picareta": ["marretada_pedra", "picareta"],
	"machado": ["machado"],
	"foice": ["foice_capim", "colher"],
	"/ostra": ["catar_ostra", "pegar"],
	"/lenha": ["galho_quebra", "pegar"],
	"": ["pegar"],
}
const SONS_DO_ULTIMO := {
	"picareta/pedra": ["pedra_quebra"],
	"machado/cai": ["arvore_cai"],
}
## O som da queda entra depois do golpe, e não por cima dele: o `Audio.efeito` toca
## num tocador só, e o segundo som corta o primeiro.
const QUEDA_DEPOIS_DO_GOLPE_S := 0.35

## Um alvo derrubado. O `Missoes` e o guia escutam para contar o trabalho.
signal derrubado(id: String, rende: String, quantidade: int)
## Bateu e não deu: sem ferramenta, ou sem fôlego. O HUD conta ao jogador.
signal recusado(motivo: String)
## Bateu num alvo que pede uma ferramenta que o jogador não tem (nem na mão nem na mochila): o viajante comenta.
signal sem_ferramenta(ferramenta: String)
## Bateu num alvo e carrega a ferramenta certa, mas não na mão (`ferramenta` é o item): os moradores dão a dica (#204).
signal fora_da_mao(ferramenta: String)
## Um impacto que soou: o nome do arquivo de `assets/audio/efeitos` (sem o .mp3) e se
## foi o último golpe do alvo. Quem quer saber o que tocou — o portão — escuta aqui.
signal golpe_sonoro(nome: String, ultimo: bool)

var _world: Node3D
var _jogador: Node3D
var _hud
var _dica: PanelContainer
var _animador: Node
var _golpe_pendente := ""
var _golpe_animando := false
## Quadros seguidos com o golpe pendente e o clipe parado: o clipe morreu.
var _quadros_sem_clipe := 0
var _timer_impacto: Timer
var _timer_fim_golpe: Timer
## id → {"no", "pos", "ficha", "golpes_dados"}
var _alvos: Dictionary = {}
var _perto := ""
## Quantos alvos de cada peça — e de cada grupo — foram POSTOS no mundo, para a
## conta de quantos já caíram: alvo derrubado some de `_alvos`, e sem este
## número não haveria de onde subtrair. Ver `derrubados`.
var _postos: Dictionary = {}
## Os ids dos alvos que já caíram nesta partida, para o save. Ver `caidos`.
var _caidos: Array[String] = []
## A partir de quantos golpes a dica conta o trabalho ("Lajedo 12/96").
const GOLPES_DE_TRABALHO_LONGO := 8
## As pedras grandes de cenário (hoje só a ficha que o motor rebaixa por falta de razão):
## id → {"no", "corpos", "ficha", "rebaixada"}.
var _fixas: Dictionary = {}
## As fichas que rendem pedra, são grandes e não têm razão escrita: o motor as pôs de
## cenário, com aviso. Fica vazio quando os dados estão em ordem (`tests/pedras.gd`).
var rebaixados: Array[String] = []


func configurar(world: Node3D, jogador: Node3D, hud, hud_layer: Control) -> void:
	_world = world
	_jogador = jogador
	_hud = hud
	_dica = DicaTecla.criar(hud_layer, Atalhos.letra("interagir"), "Bater")
	add_to_group(FocoDoE.GRUPO)
	_animador = _jogador.get("animator") as Node
	if _animador != null and _animador.has_signal("golpe_impacto"):
		_animador.connect("golpe_impacto", Callable(self, "_ao_impacto_do_golpe"))
	if _animador != null and _animador.has_signal("golpe_concluido"):
		_animador.connect("golpe_concluido", Callable(self, "_ao_golpe_concluido"))
	_timer_impacto = Timer.new()
	_timer_impacto.name = "ImpactoDoGolpe"
	_timer_impacto.one_shot = true
	add_child(_timer_impacto)
	_timer_impacto.timeout.connect(_ao_impacto_sem_sinal)
	_timer_fim_golpe = Timer.new()
	_timer_fim_golpe.name = "FimDoGolpe"
	_timer_fim_golpe.one_shot = true
	add_child(_timer_fim_golpe)
	_timer_fim_golpe.timeout.connect(_ao_golpe_concluido)
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

		_erguer_alvo(ficha, pos)

	# AS PEDRAS ESPALHADAS pelo vale (07/10), sorteadas com semente: ver `_espalhar`.
	_espalhar(dado.get("espalhadas", []))

	# AS PEDRAS GRANDES, de cenário: o desenho e o corpo de sempre, sem ser alvo.
	_erguer_as_fixas(dado.get("fixas", []))


## UM ALVO NO MUNDO, no ponto dado: a peça do catálogo, a colisão e a ficha em `_alvos`.
## É o corpo do laço de `_erguer`, para as pedras espalhadas (`_espalhar`) nascerem pelo
## mesmo caminho.
func _erguer_alvo(ficha: Dictionary, pos: Vector3) -> void:
	var id := str(ficha.get("id", ""))
	# "giro" (graus) vira a peça no chão: três troncos caídos não caem paralelos.
	var giro := deg_to_rad(float(ficha.get("giro", 0.0)))
	var no := CatalogoAssets.instanciar(str(ficha.get("peca", "")), _world, pos,
		float(ficha.get("tamanho", 1.0)), giro)
	if no == null:
		return
	if str(ficha.get("peca", "")) == "capim":
		CatalogoAssets.assentar_planta(no, _world, pos)

	# PEDRA GRANDE NÃO É ALVO. A ficha que rende pedra só vira alvo se o desenho cabe
	# na mão (`pedra_pequena`) ou se traz a razão escrita (`grande_de_proposito`, a
	# lapa da missão). Sem uma coisa nem outra o motor a põe de cenário e avisa: o
	# dado errado não pode voltar a pôr um lajedo de seis metros diante do poço.
	var limites_do_no: AABB = no.get_meta("limites", AABB())
	if str(ficha.get("rende", "")) == "pedra" and str(ficha.get("grande_de_proposito", "")) == "" \
			and not pedra_pequena(limites_do_no):
		push_warning("Recursos: '%s' rende pedra e mede %.1f x %.1f x %.1f u: grande demais para quebrar, fica de cenário." % [id, limites_do_no.size.x, limites_do_no.size.y, limites_do_no.size.z])
		rebaixados.append(id)
		_fixas[id] = {"no": no, "corpos": _por_a_colisao(str(ficha.get("peca", "")), no, pos, float(ficha.get("tamanho", 1.0)), giro),
			"ficha": ficha, "rebaixada": true}
		return

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
	var corpos := _por_a_colisao(str(ficha.get("peca", "")), no, pos, float(ficha.get("tamanho", 1.0)), giro)

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


## AS PEDRAS ESPALHADAS PELO VALE (playtest de 07/10: "espalhe mais pedras pelo mapa, de
## forma que tenha harmonia, logo não deve ter nas estradas e nem em pontos importantes
## da vila"). Cada entrada de `espalhadas` sorteia `quantas` pedras soltas com uma
## semente fixa — as mesmas a cada partida, que é o que o save dos caídos precisa — em
## terra firme, fora da mata fechada e da água, longe das ruas, das âncoras (a praça, as
## casas, o poço, a lavoura, a fazenda…), dos lotes, dos outros alvos e de qualquer corpo
## de pé. Cada uma é um alvo como os da ficha, com o id numerado.
const ESPALHADAS_TENTATIVAS_POR_PEDRA := 80
const ESPALHADAS_VAO := Vector3(2.4, 1.2, 2.4)


func _espalhar(lista: Array) -> void:
	var regiao = _world.get("_region")
	if regiao == null or lista.is_empty():
		return
	var terra: PackedVector2Array = regiao._land
	if terra.size() < 3:
		return
	var caixa := Rect2(terra[0], Vector2.ZERO)
	for v in terra:
		caixa = caixa.expand(v)
	for spec: Dictionary in lista:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(spec.get("semente", 1))
		var quantas := int(spec.get("quantas", 0))
		var longe_da_rua := float(spec.get("longe_da_rua", 7.0))
		var longe_das_ancoras := float(spec.get("longe_das_ancoras", 10.0))
		var longe_dos_outros := float(spec.get("longe_de_outros", 4.0))
		var tamanhos: Array = spec.get("tamanho", [0.3, 0.3]) if spec.get("tamanho") is Array else [float(spec.get("tamanho", 0.3)), float(spec.get("tamanho", 0.3))]
		var postas := 0
		var tentativas := 0
		while postas < quantas and tentativas < quantas * ESPALHADAS_TENTATIVAS_POR_PEDRA:
			tentativas += 1
			var p := Vector3(rng.randf_range(caixa.position.x, caixa.end.x), 0.0, rng.randf_range(caixa.position.y, caixa.end.y))
			var tamanho := rng.randf_range(float(tamanhos[0]), float(tamanhos[tamanhos.size() - 1]))
			var giro := rng.randf_range(0.0, 360.0)
			if not _world.is_on_land(p) or _world.na_mata_fechada(p):
				continue
			var chao: Vector3 = _world.ground_position(p)
			if chao.y < _world.water_level_at(p) + 0.6:
				continue
			if regiao._distancia_da_rua(Vector2(p.x, p.z)) < longe_da_rua:
				continue
			if _perto_de_algo(chao, longe_das_ancoras, longe_dos_outros) or not _vao_livre(chao):
				continue
			var ficha: Dictionary = spec.duplicate(true)
			for chave in ["quantas", "semente", "longe_da_rua", "longe_das_ancoras", "longe_de_outros"]:
				ficha.erase(chave)
			ficha["id"] = "%s_%02d" % [str(spec.get("id", "pedra_espalhada")), postas + 1]
			ficha["tamanho"] = tamanho
			ficha["giro"] = giro
			_erguer_alvo(ficha, chao)
			postas += 1
		if postas < quantas:
			push_warning("Recursos: só %d de %d '%s' couberam no vale (%d tentativas)." % [postas, quantas, str(spec.get("id", "")), tentativas])


## Perto demais de uma âncora (as da frente e do rumo não contam: são direções), de um
## lote ou de outro alvo?
func _perto_de_algo(p: Vector3, das_ancoras: float, dos_outros: float) -> bool:
	for nome in _world.ancoras:
		var chave := String(nome)
		if chave.ends_with("Frente") or chave.ends_with("Direcao") or chave.ends_with("Lado"):
			continue
		var a = _world.ancoras[nome]
		if a is Vector3 and Vector2((a as Vector3).x - p.x, (a as Vector3).z - p.z).length() < das_ancoras:
			return true
	var lotes = _world.get("_lotes")
	if lotes is Dictionary:
		for nome in lotes:
			var lote: Dictionary = lotes[nome]
			var onde = lote.get("pos", Vector3.INF)
			if onde is Vector3 and Vector2((onde as Vector3).x - p.x, (onde as Vector3).z - p.z).length() < das_ancoras:
				return true
	for id in _alvos:
		var q: Vector3 = _alvos[id]["pos"]
		if Vector2(q.x - p.x, q.z - p.z).length() < dos_outros:
			return true
	for id in _fixas:
		var q: Vector3 = (_fixas[id]["no"] as Node3D).global_position
		if Vector2(q.x - p.x, q.z - p.z).length() < dos_outros:
			return true
	return false


## Nada de pé no vão da pedra: uma caixa acima do chão, que não toca o terreno.
func _vao_livre(ponto: Vector3) -> bool:
	if not is_inside_tree() or not (_world is Node3D):
		return true
	var espaco: PhysicsDirectSpaceState3D = (_world as Node3D).get_world_3d().direct_space_state
	if espaco == null:
		return true
	var forma := BoxShape3D.new()
	forma.size = ESPALHADAS_VAO
	var pedido := PhysicsShapeQueryParameters3D.new()
	pedido.shape = forma
	pedido.transform = Transform3D(Basis.IDENTITY, ponto + Vector3.UP * (0.5 + ESPALHADAS_VAO.y * 0.5))
	pedido.collision_mask = 0xFFFFFFFF
	pedido.collide_with_areas = false
	if _jogador is CollisionObject3D:
		pedido.exclude = [(_jogador as CollisionObject3D).get_rid()]
	return espaco.intersect_shape(pedido, 4).is_empty()


## A seção "fixas" do JSON: as pedras grandes, de cenário. O mesmo lugar, o mesmo
## tamanho e o corpo de sempre — mas não entram em `_alvos`: não respondem ao E, não
## aparecem na dica, não votam no foco e não apanham.
func _erguer_as_fixas(lista: Array) -> void:
	for ficha: Dictionary in lista:
		var base: Vector3 = Lugares.ponto(str(ficha.get("lugar", "")))
		if base == Lugares.NENHUM:
			continue
		var desvio: Array = ficha.get("desvio", [0.0, 0.0])
		var pos: Vector3 = _world.ground_position(base + Vector3(float(desvio[0]), 0.0, float(desvio[1])))
		var giro := deg_to_rad(float(ficha.get("giro", 0.0)))
		var peca := str(ficha.get("peca", ""))
		var tamanho := float(ficha.get("tamanho", 1.0))
		var no := CatalogoAssets.instanciar(peca, _world, pos, tamanho, giro)
		if no == null:
			continue
		_fixas[str(ficha.get("id", ""))] = {"no": no, "corpos": _por_a_colisao(peca, no, pos, tamanho, giro),
			"ficha": ficha, "rebaixada": false}


## Põe a colisão da peça no mundo e devolve os corpos que nasceram (os filhos novos do
## mundo), que é o que se guarda para liberar junto com o visual. Ver o comentário em
## `_erguer`: `CatalogoAssets.colisao` cria um nó irmão, e quais nasceram desta chamada
## só se sabe olhando antes e depois.
func _por_a_colisao(peca: String, no: Node3D, pos: Vector3, tamanho: float, giro: float) -> Array[Node]:
	var antes := _world.get_child_count()
	CatalogoAssets.colisao(peca, no, _world, pos, tamanho, giro)
	var corpos: Array[Node] = []
	for i in range(antes, _world.get_child_count()):
		corpos.append(_world.get_child(i))
	return corpos


func _process(_delta: float) -> void:
	# O CLIPE MORREU NO CAMINHO (o corpo se mexeu: `update_motion` corta o gesto)
	# e o impacto não vai vir: solta a trava já, sem cobrar (#112). Dois quadros
	# de folga para o `play` entrar.
	if _golpe_pendente != "" and _golpe_animando and _animador != null and _animador.has_method("chop_ativo"):
		if bool(_animador.call("chop_ativo")):
			_quadros_sem_clipe = 0
		else:
			_quadros_sem_clipe += 1
			if _quadros_sem_clipe > 2:
				_cancelar_golpe()
	if _jogador == null or _dica == null:
		return
	var antes := _perto
	_perto = _mais_perto()
	if _perto != antes:
		_dica.visible = _perto != ""
	if _perto == "":
		return
	# O E É DE OUTRO (`foco_do_e.gd`): a dica daqui se apaga.
	if not FocoDoE.e_dele(self):
		_dica.visible = false
		return
	_dica.visible = true
	var alvo: Dictionary = _alvos[_perto]
	var ficha: Dictionary = alvo["ficha"]
	# A dica diz o nome do alvo E o que falta para bater nele — a ferramenta
	# que não está na mochila, ou o fôlego que acabou. Dica que só diz "E ·
	# bater" manda o jogador apertar uma tecla que não vai fazer nada.
	# A CONTA DO TRABALHO LONGO (07/10): a pedra grande diz os golpes dados e os que
	# faltam — "quanto maior a pedra, maior o marcador".
	var nome_na_dica := str(IdiomaMenu.campo(ficha, "nome"))
	if int(ficha.get("golpes", 3)) >= GOLPES_DE_TRABALHO_LONGO:
		nome_na_dica = "%s %d/%d" % [nome_na_dica, int(alvo["golpes_dados"]), int(ficha.get("golpes", 3))]
	DicaTecla.mostrar_em(_dica, get_viewport().get_camera_3d(),
		alvo["pos"] + Vector3(0.0, ALTURA_DICA, 0.0),
		"%s · %s" % [nome_na_dica, _o_que_falta(ficha)])


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


## O que a dica diz depois do nome: a ferramenta que falta, o talento ou o aço
## que o alvo pede, ou com o que se vai bater.
func _o_que_falta(ficha: Dictionary) -> String:
	var ferramenta := str(ficha.get("ferramenta", ""))
	if ferramenta == "":
		return tr("à mão") if Energia.aguenta("bater", _dureza(ficha)) else "sem %s" % Energia.nome_recurso()
	if not _tem_ferramenta(ferramenta):
		# Na barra, mas não escolhida: diz a tecla. Só na mochila: manda pôr na mão.
		for indice in Inventario.ESPACOS_MAO:
			var na_barra := str(Inventario.espacos[indice].get("id", ""))
			if na_barra != "" and Catalogo.familia(na_barra) == ferramenta:
				return tr("selecione %s (%s)") % [_nome_do_item(na_barra), Inventario.rotulo_do_espaco(indice)]
		if _carrega(ferramenta):
			return tr("ponha na mão: %s") % _nome_do_item(ferramenta)
		return tr("precisa de %s") % _nome_do_item(ferramenta)
	var impede := _o_que_impede(ficha, false)
	if impede != "":
		return impede
	if not Energia.aguenta("bater", _dureza(ficha)):
		return "sem %s" % Energia.nome_recurso()
	return "com %s" % _nome_do_item(Equipamento.da_familia_em_uso(ferramenta))


## A dureza do alvo para o Energia: o fôlego de cada golpe é bater x dureza.
## Sem o campo, 1 — o lajedo e o tronco caído de sempre.
static func _dureza(ficha: Dictionary) -> float:
	return float(ficha.get("dureza", 1.0))


## O QUE O ALVO PEDE ALÉM DA FERRAMENTA CERTA NA MÃO, ou "".
##
## Dois pedidos, e eles não se parecem — foi a queixa do 2D: "precisa
## diferenciar uma árvore que precisa de machado melhor de uma que precisa
## destravar a habilidade". `"nivel": 2` é o do talento (`Progressao.nivel`,
## que só a teia sobe: Mão de pedra, Pedra de Xangô), e manda à teia;
## `"grau": 2` é a ferramenta de aço na mão, e manda à venda. A pedra dura pede
## o talento; o matacão pede os dois. `frase` é a recusa inteira, com ponto;
## sem ela, o pedaço que a dica põe depois do nome.
func _o_que_impede(ficha: Dictionary, frase: bool) -> String:
	var ferramenta := str(ficha.get("ferramenta", ""))
	if ferramenta == "":
		return ""
	var nivel := int(ficha.get("nivel", 1))
	var grau := int(ficha.get("grau", 1))
	var falta_talento := Progressao.nivel(ferramenta) < nivel
	var falta_aco := Catalogo.grau(Equipamento.da_familia_em_uso(ferramenta)) < grau
	if not falta_talento and not falta_aco:
		return ""
	var de_aco := _nome_do_item(_da_familia_no_grau(ferramenta, grau))
	var talentos := " / ".join(Talentos.que_abrem(ferramenta, nivel))
	if falta_talento and falta_aco:
		return (tr("Pede %s e o talento %s.") if frase else tr("pede %s e o talento %s")) % [de_aco, talentos]
	if falta_aco:
		return (tr("Pede %s.") if frase else tr("pede %s")) % de_aco
	return (tr("Pede o talento %s.") if frase else tr("pede o talento %s")) % talentos


## A ferramenta desta família naquele grau — a picareta de aço, para a
## picareta no grau 2 —, ou a própria família quando não há.
static func _da_familia_no_grau(familia: String, grau: int) -> String:
	for id in Catalogo.ITENS:
		if Catalogo.familia(id) == familia and Catalogo.grau(id) == grau:
			return str(id)
	return familia


## Tem na mochila alguma ferramenta desta família (a de ferro ou a de aço)?
func _carrega(familia: String, grau_minimo: int = 1) -> bool:
	for id in Catalogo.ITENS:
		if Catalogo.familia(id) == familia and Inventario.tem(str(id)) and Catalogo.grau(str(id)) >= grau_minimo:
			return true
	return false


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
	# SEM FERRAMENTA É À MÃO: a ostra se cata na pedra (#52). E o machado de
	# aço é machado: a ficha pede a FAMÍLIA, e o grau é conta à parte
	# (`_o_que_impede`).
	return id == "" or Equipamento.da_familia_em_uso(id) != ""


## O GOLPE.
##
## A ordem das recusas importa e é a do 2D: primeiro a ferramenta, depois o
## fôlego. Quem não tem machado precisa saber que é do machado que precisa, e
## não que está cansado — a segunda informação não ajuda em nada.
func bater() -> bool:
	if _perto == "":
		return false
	if _golpe_pendente != "" or _golpe_animando:
		return false
	var alvo: Dictionary = _alvos[_perto]
	var ficha: Dictionary = alvo["ficha"]
	var ferramenta := str(ficha.get("ferramenta", ""))

	if not _tem_ferramenta(ferramenta):
		# Carregando a certa e segurando outra (ou nada): diz qual pôr na mão.
		if _carrega(ferramenta):
			recusado.emit(tr("Ponha na mão: %s.") % _nome_do_item(ferramenta))
			fora_da_mao.emit(ferramenta)
		else:
			recusado.emit("Precisa de %s." % _nome_do_item(ferramenta))
			sem_ferramenta.emit(ferramenta)
		return false
	# A certa na mão e o alvo duro demais para ela, ou para quem a segura.
	var impede := _o_que_impede(ficha, true)
	if impede != "":
		recusado.emit(impede)
		return false
	var dureza := _dureza(ficha)
	if not Energia.aguenta("bater", dureza):
		recusado.emit("Sem %s para bater." % Energia.nome_recurso())
		return false
	# Recursos recolhidos à mão não usam ferramenta nem animação de golpe:
	# cobram e resolvem já, para não manter a trava entre coletas próximas.
	if ferramenta == "":
		if not _cobrar(dureza):
			return false
		_aplicar_golpe(_perto)
		return true
	# COM FERRAMENTA A COBRANÇA SAI NO IMPACTO (#112), junto com o golpe: ver
	# `_ao_impacto_do_golpe`. Aqui só se conferiu que há com que pagar.
	_iniciar_golpe(_perto)
	return true


## COBRA UM GOLPE: a reserva (bater × dureza) e o que o trabalho ensina. QUEM
## TRABALHA APRENDE, e o duro ensina mais (`Talentos.XP_POR_ACAO`): é por aqui
## que o golpe leva à teia que abre o alvo mais duro.
func _cobrar(dureza: float) -> bool:
	if not Energia.gastar("bater", dureza):
		recusado.emit("Sem %s para bater." % Energia.nome_recurso())
		return false
	Talentos.ganhar("bater_duro" if dureza > 1.5 else "bater")
	return true


func _iniciar_golpe(id: String) -> void:
	_golpe_pendente = id
	var animador := _animador
	var animacao_iniciada := false
	if animador != null and animador.has_method("play_chop"):
		animacao_iniciada = not str(animador.call("play_chop", 1)).is_empty()
	elif animador != null and animador.has_method("play_gesture"):
		animacao_iniciada = not str(animador.call("play_gesture", GESTO_GOLPEAR)).is_empty()
	_golpe_animando = animacao_iniciada and animador.has_signal("golpe_concluido")
	# A TRAVA DURA O CLIPE INTEIRO (#112): a 1,25 s fixo ela caía antes de o
	# clipe acabar, e o E seguinte reiniciava o golpe no meio — "só acontece uma
	# animação". O animador diz quanto o clipe dura; sem ele, o teto antigo.
	var duracao := 0.0
	if animacao_iniciada and animador.has_method("duracao_do_golpe"):
		duracao = float(animador.call("duracao_do_golpe"))
	if _golpe_animando:
		_timer_fim_golpe.start(duracao + 0.25 if duracao > 0.0 else TEMPO_LIMITE_FIM_DO_GOLPE)
	if animacao_iniciada and _jogador.has_method("travar_acao_de_golpe"):
		_jogador.call("travar_acao_de_golpe", TEMPO_MAXIMO_DO_GOLPE, true)
	_quadros_sem_clipe = 0
	# Os animadores do projeto emitem o impacto onde a mão bate, antes de o golpe
	# acabar. O timer cobre modelos sem esse sinal (`_ao_impacto_sem_sinal`) e,
	# nos que o têm, é o teto para um impacto que não veio.
	if animacao_iniciada and animador.has_signal("golpe_impacto"):
		_timer_impacto.start(duracao + 0.3 if duracao > 0.0 else TEMPO_LIMITE_IMPACTO)
	else:
		_timer_impacto.start(TEMPO_ATE_IMPACTO)


## O IMPACTO: a ferramenta encontrou o alvo. É AQUI que a reserva é cobrada
## (#112) — cobrança e golpe no mesmo instante, e nunca uma sem o outro. Sem com
## que pagar (a reserva acabou entre o aperto e o impacto), o golpe não sai.
func _ao_impacto_do_golpe() -> void:
	if _golpe_pendente.is_empty():
		return
	_timer_impacto.stop()
	var id := _golpe_pendente
	_golpe_pendente = ""
	if not _alvos.has(id):
		return
	if _cobrar(_dureza(_alvos[id]["ficha"])):
		_aplicar_golpe(id)
	if not _golpe_animando:
		if _jogador.has_method("liberar_acao_de_golpe"):
			_jogador.call("liberar_acao_de_golpe")


## O TEMPORIZADOR DO IMPACTO venceu. Em animador sem o sinal, é o impacto (o
## gesto do procedural). Em animador com o sinal, o impacto NÃO VEIO: o clipe
## morreu no caminho, e o golpe é cancelado sem cobrar nem bater (#112) — era o
## golpe fantasma de 1,5 s, pago no aperto e sem golpe à vista.
func _ao_impacto_sem_sinal() -> void:
	if _golpe_animando and _animador != null and _animador.has_signal("golpe_impacto"):
		_cancelar_golpe()
		return
	_ao_impacto_do_golpe()


## O GOLPE NÃO ACONTECEU: solta a trava sem cobrar nem bater.
func _cancelar_golpe() -> void:
	_timer_impacto.stop()
	_timer_fim_golpe.stop()
	_golpe_pendente = ""
	_golpe_animando = false
	_quadros_sem_clipe = 0
	if _jogador != null and _jogador.has_method("liberar_acao_de_golpe"):
		_jogador.call("liberar_acao_de_golpe")


func _ao_golpe_concluido() -> void:
	if not _golpe_animando:
		return
	_timer_fim_golpe.stop()
	_golpe_animando = false


func _aplicar_golpe(id: String) -> void:
	var alvo: Dictionary = _alvos[id]
	var ficha: Dictionary = alvo["ficha"]
	alvo["golpes_dados"] = int(alvo["golpes_dados"]) + 1
	var faltam := int(ficha.get("golpes", 3)) - int(alvo["golpes_dados"])
	# O SOM É DO IMPACTO (#89): cada golpe que acerta, e o que derruba também — uma
	# tabela só (`SONS_DO_GOLPE`, `SONS_DO_ULTIMO`), e a queda entra depois do golpe.
	_tocar_o_golpe(ficha, faltam <= 0)
	if faltam > 0:
		# A PEDRA GRANDE RENDE AOS POUCOS (07/10): a cada `rende_a_cada` golpes, o que a
		# ficha diz — dias de picareta até ela acabar, com a mochila enchendo no caminho.
		var a_cada := int(ficha.get("rende_a_cada", 0))
		var parcial := str(ficha.get("rende", ""))
		if a_cada > 0 and parcial != "" and int(alvo["golpes_dados"]) % a_cada == 0 \
				and Inventario.adicionar(parcial, int(ficha.get("quantidade", 1))):
			if _hud != null and _hud.has_method("set_notice"):
				_hud.set_notice("%s: +%d %s (%d/%d)" % [str(IdiomaMenu.campo(ficha, "nome")), int(ficha.get("quantidade", 1)),
					Catalogo.nome(parcial).to_lower(), int(alvo["golpes_dados"]), int(ficha.get("golpes", 3))])
		_sacudir(alvo["no"])
		return

	# Caiu: some do mundo e vira material na mochila.
	var rende := str(ficha.get("rende", ""))
	var quantos := int(ficha.get("quantidade", 1))
	# ALVO QUE NÃO RENDE NADA É ALVO QUE SÓ SE LIMPA, e o capim do cemitério é
	# o primeiro. No 2D, cortar o mato não põe nada na mochila: o mato some, e
	# é isso que limpar quer dizer. Sem esta guarda, `adicionar("")` empilharia
	# um item de id vazio na mochila do jogador a cada pé cortado.
	if rende != "":
		Inventario.adicionar(rende, quantos)
	# O MONTE QUE SE REFAZ rende e fica: nem some, nem entra nos caídos do save —
	# até a conta de `vezes` (07/10): a galhada do terreiro rende cinco vezes e acaba.
	alvo["rendeu"] = int(alvo.get("rendeu", 0)) + 1
	var vezes := int(ficha.get("vezes", 0))
	if _renova(ficha) and (vezes <= 0 or int(alvo["rendeu"]) < vezes):
		alvo["golpes_dados"] = 0
		_sacudir(alvo["no"])
		derrubado.emit(id, rende, quantos)
		return
	var no: Node3D = alvo["no"]
	if is_instance_valid(no):
		# A ÁRVORE NOVA CAI (`"cai": true`), do pé, para longe de quem cortou,
		# como as árvores do vale; o resto some onde estava.
		if bool(ficha.get("cai", false)):
			CoqueiroCortado.derrubar(no, no.get_parent(), no.global_position, no.global_position - _jogador.global_position)
		else:
			no.queue_free()
	# E A COLISÃO COM ELE. Ver o comentário em `_erguer`: ela é nó irmão, e
	# esquecê-la deixa o caminho barrado por um tronco que não existe mais.
	for corpo in alvo.get("corpos", []):
		if is_instance_valid(corpo):
			corpo.queue_free()
	_alvos.erase(id)
	if not _caidos.has(id):
		_caidos.append(id)
	if _perto == id:
		_perto = ""
	_dica.visible = false
	derrubado.emit(id, rende, quantos)


## O ALVO QUE SE REFAZ ENQUANTO O JOGADOR NÃO TEM A FERRAMENTA (`"renova_sem"`).
##
## É a galhada seca do terreiro (`"renova_sem": "machado"`). O machado só chega
## na missão da ponte, e antes dela a lenha do vale era contada: a chegada pede
## quatro, e quem gastasse uma em outra coisa — corda a mais na bancada — ficava
## sem ter onde buscar, com o peixe da janta por assar e a noite sem virar.
## Enquanto não há machado na mochila nem na mão, o monte rende e continua lá.
## Com o machado, rende a última vez e cai como qualquer alvo: daí em diante a
## lenha é dele.
func _renova(ficha: Dictionary) -> bool:
	var sem := str(ficha.get("renova_sem", ""))
	return sem != "" and not _carrega(sem) and Equipamento.da_familia_em_uso(sem) == ""


## A PEDRA CABE NA MÃO? Pela medida do desenho posto (`limites` de
## `CatalogoAssets.instanciar`): a largura é o maior lado do chão.
static func pedra_pequena(limites: AABB) -> bool:
	return maxf(limites.size.x, limites.size.z) <= PEDRA_MAX_LARGURA and limites.size.y <= PEDRA_MAX_ALTURA


## O SOM DO IMPACTO: o da ferramenta no alvo e, no último golpe, o da queda — que entra
## depois, e não por cima. Cada som que toca avisa em `golpe_sonoro`.
func _tocar_o_golpe(ficha: Dictionary, ultimo: bool) -> void:
	var golpe := som_do_golpe(ficha, false)
	if golpe != "":
		Audio.efeito(golpe)
		golpe_sonoro.emit(golpe, ultimo)
	if not ultimo:
		return
	var fim := som_do_golpe(ficha, true)
	if fim == "":
		return
	if golpe == "":
		_tocar_a_queda(fim)
	else:
		get_tree().create_timer(QUEDA_DEPOIS_DO_GOLPE_S).timeout.connect(_tocar_a_queda.bind(fim))


func _tocar_a_queda(nome: String) -> void:
	Audio.efeito(nome)
	golpe_sonoro.emit(nome, true)


## O som do golpe desta ficha: o primeiro candidato que existe na pasta, ou "" (o último
## golpe sem som próprio soa como os outros).
static func som_do_golpe(ficha: Dictionary, ultimo: bool) -> String:
	for nome in _sons_candidatos(ficha, ultimo):
		if ResourceLoader.exists(PASTA_DOS_SONS + str(nome) + ".mp3"):
			return str(nome)
	return ""


static func _sons_candidatos(ficha: Dictionary, ultimo: bool) -> Array:
	var do_dado = ficha.get("som_do_ultimo" if ultimo else "som", null)
	if do_dado is String and do_dado != "":
		return [do_dado]
	if do_dado is Array:
		return do_dado
	var ferramenta := str(ficha.get("ferramenta", ""))
	var tabela: Dictionary = SONS_DO_ULTIMO if ultimo else SONS_DO_GOLPE
	var chaves: Array[String] = ["%s/%s" % [ferramenta, str(ficha.get("rende", ""))], ferramenta]
	if ultimo and bool(ficha.get("cai", false)):
		chaves.insert(0, "%s/cai" % ferramenta)
	for chave in chaves:
		if tabela.has(chave):
			return tabela[chave]
	return []


## Os nomes que as tabelas esperam e a pasta ainda não tem: o que falta o gerador de
## efeitos fazer. Cada um passa a tocar sozinho no dia em que o arquivo existir.
static func sons_que_faltam() -> Array:
	var faltam: Array = []
	for tabela: Dictionary in [SONS_DO_GOLPE, SONS_DO_ULTIMO]:
		for chave in tabela:
			for nome in tabela[chave]:
				if not ResourceLoader.exists(PASTA_DOS_SONS + str(nome) + ".mp3") and not faltam.has(nome):
					faltam.append(nome)
	return faltam


## Um tranco na peça a cada golpe, para o jogador ver que acertou. Não é
## animação: é a peça recuando e voltando, que é o bastante para a batida ter
## resposta e não custa arte nenhuma.
func _sacudir(no: Node3D) -> void:
	if not is_instance_valid(no):
		return
	# O REPOUSO FICA GUARDADO. Lida da peça, a posição de um segundo golpe dado no
	# meio do tranco já vinha afundada, e o tranco voltava para ela: alvo comum
	# some antes de isso aparecer, mas o monte que se refaz desceria um pouco a
	# cada par de golpes ligeiros.
	if not no.has_meta("repouso"):
		no.set_meta("repouso", no.position)
	var de: Vector3 = no.get_meta("repouso")
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
	if not _jogador.is_physics_processing() or not FocoDoE.e_dele(self):
		return
	bater()
	get_viewport().set_input_as_handled()


## O QUE O E FARIA AQUI, para o foco (`foco_do_e.gd`): bater no alvo ao alcance.
## A conta desconta a meia-pegada: encostado no lajedo grande, a distância é a
## da face dele, e não a do meio.
func alvo_do_e() -> Dictionary:
	if _perto == "" or not _alvos.has(_perto) or _jogador == null or not _jogador.is_physics_processing():
		return {}
	var alvo: Dictionary = _alvos[_perto]
	return {"ponto": alvo["pos"], "vies": float(alvo.get("meia_pegada", 0.0))}


## `chop` é o sétimo gesto do modelo com clipes autorados.
const GESTO_GOLPEAR := 6


## ONDE ESTÁ O ALVO MAIS PERTO QUE RENDE ISTO, ou `Lugares.NENHUM`.
##
## É o que o guia pergunta para pôr o marcador da missão no lugar certo. Antes
## ele marcava a ÂNCORA do passo — a casa, o roçado — e mandava o jogador a um
## lugar onde não havia o que bater. "Marca a casa quando devia marcar os
## troncos", nas palavras de quem jogou.
##
## E MARCA O QUE O JOGADOR PODE BATER: o que se cata na mão, ou o da ferramenta
## que ele carrega, respeitando seu grau e o talento exigido pelo alvo.
## A lenha da primeira noite sai da galhada seca, sem machado
## (o machado é da ponte); marcar o tronco caído mais perto, que pede machado,
## era mandá-lo bater no que não cede. Sem nenhum desses, vale o mais perto.
func mais_perto_que_rende(item: String, de: Vector3) -> Vector3:
	return _mais_perto_do_material(item, de, false)


## O testador não deve navegar até uma fonte que ainda não consegue colher.
func mais_perto_que_cede(item: String, de: Vector3) -> Vector3:
	return _mais_perto_do_material(item, de, true)


func _mais_perto_do_material(item: String, de: Vector3, estrito: bool) -> Vector3:
	var melhor: Vector3 = Lugares.NENHUM
	var menor := INF
	var cede: Vector3 = Lugares.NENHUM
	var menor_que_cede := INF
	for id in _alvos:
		var ficha: Dictionary = _alvos[id]["ficha"]
		if str(ficha.get("rende", "")) != item:
			continue
		var d: Vector3 = _alvos[id]["pos"] - de
		d.y = 0.0
		if d.length() < menor:
			menor = d.length()
			melhor = _alvos[id]["pos"]
		# O QUE CEDE: a ferramenta na mochila E do grau que o alvo pede, com o talento
		# (07/10): a pedra grande rende pedra, mas só ao aço e ao talento — a seta de
		# "junte três pedras" não pode apontar o lajedo a quem tem a picareta de ferro.
		var ferramenta := str(ficha.get("ferramenta", ""))
		var acessivel := ferramenta == "" or (_carrega(ferramenta, int(ficha.get("grau", 1))) and _o_que_impede(ficha, false) == "")
		if acessivel and d.length() < menor_que_cede:
			menor_que_cede = d.length()
			cede = _alvos[id]["pos"]
	return cede if cede != Lugares.NENHUM or estrito else melhor


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
## embaúba nova e tronco caído (`"grupo": "mato_do_cemiterio"` no JSON), e o
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
