extends Node
## A LUTA NO VALE: o E e o V do jogo 2D no corpo do 3D, e quem mora na mata.
##
## A REGRA É O `Luta` COMPARTILHADO, sem uma linha mudada: que golpe a mão dá,
## quanto ele fere, tonteia e cansa, quem sabe a ginga. O que mora aqui é o
## que o 2D tinha em `Mundo` e o vale não tinha: o gatilho (tocar e segurar o
## E perto do bicho; o V), a pancada no tempo do braço, quem está na frente do
## golpe, o que se ganha ao derrubar, e a mata que repõe o bicho em dias.
##
## TOCAR E SEGURAR, como no 2D (`Mundo._armar_a_luta`). Com bicho ao alcance e
## a mão que luta — arma, ou vazia para quem aprendeu a meia-lua —, o E só luta:
## tocado é o golpe (ou a meia-lua); segurado `Luta.SEGURAR`, o golpe forte (ou
## a rasteira), para quem aprendeu. Sem bicho perto o E segue para o que já
## fazia no vale — lápide, ficha de árvore —, porque a luta só o toma quando
## tem com quem lutar. Este nó entra na árvore depois das lápides e das
## árvores, e por isso recebe a tecla antes delas.
##
## A ESCALA sai do passo do jogador, como na criatura (`u_por_px`): o alcance
## de 26 px do golpe de facão vira pouco menos de um metro.
##
## O QUE O VALE AINDA NÃO TEM, e a luta não espera: a mão se escolhe pela
## mochila (#2) e pelas teclas (#4); até lá, só quem pôs a arma na mão por
## código luta de facão — de mão vazia, luta quem aprendeu a capoeira. O que o
## bicho deixa vai direto para a mochila, porque o vale não tem coleta no chão.

const Criatura = preload("res://scripts/prototipo_3d/criatura_vale.gd")
const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")
const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")
const TEXTOS := "res://data/luta.json"

## Até onde o E procura bicho para lutar, em pixels do 2D.
const ALCANCE_DE_LUTA := 40.0
## Colada, a menos disto (px), não há frente: pega de qualquer lado.
const COLADA := 4.0

## ONDE O BICHO NASCE HOJE. No 2D cada espécie tem a zona dela; o vale só tem a
## vila e a mata em volta (a serra e o brejo são a #24). O caititu fica na mata
## fechada — a mesma que liga a música tensa —, longe da porta de casa e do
## píer: quem cai acorda na porta (ver queda.gd), e acordar do lado do bicho
## que derrubou seria cair de novo.
const NINHOS := ["caititu"]
const LONGE_DE_CASA := 45.0
const LONGE_DA_CHEGADA := 45.0
## A varredura atrás do ninho: raio em volta da Praça e passo da grade.
const BUSCA_RAIO := 320.0
const BUSCA_PASSO := 8.0

## O número da pancada, com as cores do 2D (`Mundo._mostrar_pancada`).
const COR_DA_PANCADA := Color(0.96, 0.93, 0.84)
const COR_DA_PANCADA_PESADA := Color(1.0, 0.8, 0.3)
const COR_DO_JOGADOR_FERIDO := Color(0.95, 0.32, 0.26)
const COR_DA_ESQUIVA := Color(0.62, 0.86, 0.95)
const COR_DA_PECONHA := Color(0.55, 0.85, 0.35)
const ALTURA_DA_PANCADA := 1.2
const SOBE_A_PANCADA := 0.8
const DURA_A_PANCADA := 0.8

## Um golpe saiu (depois do fôlego, antes do impacto).
signal bateu(golpe: String)

var u_por_px: float = 2.1 / Criatura.PASSO_DO_JOGADOR_2D
var criaturas: Array = []
## Quem caiu e quando volta: {especie, ninho, volta_em} (`volta_em` é dia absoluto).
var mortes: Array = []
## O E ainda está apertado? Por Callable para o portão poder segurar a tecla
## sem teclado — headless não aperta tecla nenhuma.
var segurando: Callable

var _world
var _player
var _hud
var _golpe_segurado_desde: float = -1.0
var _ginga_resta: float = 0.0
var _ginga_rumo: Vector3 = Vector3.ZERO
var _textos: Dictionary = {}
## Onde o corpo fica em repouso: golpe e ginga podem se atropelar, e cada um
## voltar para onde o outro o deixou desalinharia o corpo da cápsula.
var _repouso_do_corpo: Vector3 = Vector3.ZERO


func configurar(world, player, hud) -> void:
	_world = world
	_player = player
	_hud = hud
	_repouso_do_corpo = player.visual.position
	u_por_px = float(player.walk_speed) / Criatura.PASSO_DO_JOGADOR_2D
	segurando = func() -> bool: return Input.is_physical_key_pressed(Atalhos.tecla("interagir"))
	var lido = JSON.parse_string(FileAccess.get_file_as_string(TEXTOS))
	_textos = lido if lido is Dictionary else {}
	Vida.ferido.connect(_ao_ferir_o_jogador)
	Vida.envenenado.connect(_ao_mudar_a_peconha)
	Luta.esquivou.connect(_ao_esquivar_o_bote)
	Relogio.dia_comecou.connect(_ao_comecar_o_dia)
	for especie in NINHOS:
		var ninho := ponto_de_ninho()
		if ninho.is_finite():
			nascer(especie, ninho)
		else:
			push_warning("Luta: não achei mata fechada longe de casa para o ninho de %s" % especie)


func _texto(chave: String) -> String:
	return str(IdiomaMenu.campo(_textos.get(chave, {}), "texto", chave))


# --- a mata ------------------------------------------------------------------

## O ninho: o ponto de mata fechada, em terra, longe da porta de casa e da
## chegada, mais perto da Praça — onde o jogador que sai da vila encontra.
func ponto_de_ninho() -> Vector3:
	var ancoras: Dictionary = _world.ancoras
	var praca: Vector3 = ancoras.get("Praça", Vector3.ZERO)
	var casa: Vector3 = ancoras.get("Casa de taipa", Vector3.INF)
	var chegada: Vector3 = _player.spawn_position
	var melhor := Vector3.INF
	var melhor_d := INF
	var passos := int(BUSCA_RAIO / BUSCA_PASSO)
	for i in range(-passos, passos + 1):
		for j in range(-passos, passos + 1):
			var p := praca + Vector3(i * BUSCA_PASSO, 0.0, j * BUSCA_PASSO)
			var d := Vector2(p.x - praca.x, p.z - praca.z).length()
			if d >= melhor_d or not _world.na_mata_fechada(p) or not _world.is_on_land(p):
				continue
			if casa.is_finite() and Vector2(p.x - casa.x, p.z - casa.z).length() < LONGE_DE_CASA:
				continue
			if Vector2(p.x - chegada.x, p.z - chegada.z).length() < LONGE_DA_CHEGADA:
				continue
			melhor = p
			melhor_d = d
	return _world.ground_position(melhor, 0.05) if melhor.is_finite() else Vector3.INF


func nascer(especie: String, onde: Vector3):
	var bicho = Criatura.new()
	bicho.especie = especie
	bicho.name = "Criatura_%s" % especie
	add_child(bicho)
	bicho.global_position = onde
	bicho.configurar(_world, _player, u_por_px)
	bicho.morreu.connect(_ao_morrer)
	criaturas.append(bicho)
	return bicho


func _ao_morrer(bicho) -> void:
	var volta := int(bicho.dados().get("volta", 3))
	mortes.append({"especie": bicho.especie, "ninho": bicho._ninho,
		"volta_em": Relogio.dia_absoluto() + volta})
	criaturas.erase(bicho)


## A MATA REPÕE quem morreu, em dias (`volta` da espécie): três no caititu.
## Matar limpa a mata por uns dias, e não para sempre.
func _ao_comecar_o_dia(_dia: int, _estacao: int, _ano: int) -> void:
	var hoje := Relogio.dia_absoluto()
	for morte in mortes.duplicate():
		if hoje >= int(morte["volta_em"]):
			mortes.erase(morte)
			nascer(str(morte["especie"]), morte["ninho"])


## A partida salva diz quem caiu e ainda não voltou (#7). Quem está nessa
## lista não pode estar de pé no vale recém-montado: o caititu que o jogador
## derrubou ontem não reaparece só porque o jogo foi fechado e aberto.
func restaurar_mortes(lista: Array) -> void:
	mortes = []
	for morte in lista:
		if morte is Dictionary:
			mortes.append(morte.duplicate(true))
	for morte in mortes:
		for c in _vivas():
			if c.especie == str(morte.get("especie", "")) 					and Criatura._plano(c._ninho - morte.get("ninho", Vector3.INF)).length() < 1.0:
				criaturas.erase(c)
				c.queue_free()


func _vivas() -> Array:
	return criaturas.filter(func(c): return is_instance_valid(c) and not c.morto())


# --- a tecla -----------------------------------------------------------------

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if _player == null or not _player.is_physics_processing():
		return
	if event.physical_keycode == Atalhos.tecla("interagir"):
		if armar_a_luta():
			get_viewport().set_input_as_handled()
	elif event.physical_keycode == Atalhos.tecla("gingar"):
		if gingar():
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _golpe_segurado_desde >= 0.0:
		_conferir_o_golpe_segurado()


## O E apertou com bicho perto: o corpo se vira para ele e começa a contar o
## segurar. Devolve false quando não há luta — e aí o E segue para o resto.
func armar_a_luta() -> bool:
	var mao := Inventario.na_mao()
	if Luta.golpe_da_mao(mao, false) == "":
		return false
	var bicho = _criatura_perto(ALCANCE_DE_LUTA * u_por_px)
	if bicho == null:
		return false
	_olhar_para(bicho.global_position)
	_golpe_segurado_desde = Time.get_ticks_msec() / 1000.0
	return true


func _conferir_o_golpe_segurado() -> void:
	if not _player.is_physics_processing():
		_golpe_segurado_desde = -1.0
		return
	var segurou := Time.get_ticks_msec() / 1000.0 - _golpe_segurado_desde
	var ainda: bool = segurando.call()
	if ainda and segurou < Luta.SEGURAR:
		return
	_golpe_segurado_desde = -1.0
	var mao := Inventario.na_mao()
	var golpe := Luta.golpe_da_mao(mao, ainda)
	if golpe != "":
		bater(golpe, mao)


## Um golpe inteiro: o fôlego, o corpo, e a pancada no tempo do braço.
func bater(golpe: String, mao: String) -> void:
	var g: Dictionary = Luta.GOLPES.get(golpe, {})
	if g.is_empty():
		return
	var custo := Luta.folego(golpe)
	if not Energia.aguenta("bater", custo):
		_avisar(_texto("cansado"))
		return
	Energia.gastar("bater", custo)
	bateu.emit(golpe)
	_animar_o_golpe()
	Audio.efeito("machado")
	await get_tree().create_timer(float(g["impacto"])).timeout
	if is_inside_tree():
		acertar(golpe, mao)


## A pancada: quem está no golpe apanha, recua, fica tonto se o golpe tonteia,
## e cai se era a última. QUEM VENCE A BRIGA RESPIRA (`folego` da espécie).
func acertar(golpe: String, mao: String) -> bool:
	var g: Dictionary = Luta.GOLPES.get(golpe, {})
	var alvos := criaturas_no_golpe(g)
	if alvos.is_empty():
		return false
	var dano := Luta.dano(golpe, mao)
	var tonteia := Luta.tontura(golpe)
	Talentos.ganhar("golpe")
	for alvo in alvos:
		var rumo: Vector3 = Criatura._plano(alvo.global_position - _player.global_position).normalized()
		var deixa := str(alvo.dados().get("cai", ""))
		var quantos := int(alvo.dados().get("quantos_caem", 1))
		var nome: String = alvo.nome()
		var especie: String = alvo.especie
		var respira := float(alvo.dados().get("folego", 0.0))
		var onde: Vector3 = alvo.global_position
		var caiu: bool = alvo.ferir(dano, rumo * float(g["empurra"]) * u_por_px, tonteia)
		Luta.acertou.emit(golpe, especie, caiu, tonteia > 0.0 and not caiu)
		var pesado := tonteia > 0.0 or golpe == "golpe_forte"
		mostrar_pancada(onde, "%d" % maxi(1, roundi(dano)), COR_DA_PANCADA_PESADA if pesado else COR_DA_PANCADA)
		if tonteia > 0.0 and not caiu:
			mostrar_pancada(onde + Vector3(0.0, 0.35, 0.0), _texto("tonto"), COR_DA_PANCADA_PESADA)
		if caiu:
			Talentos.ganhar("abate")
			Energia.repor(respira)
			if deixa != "" and Inventario.adicionar(deixa, quantos):
				_avisar(_texto("levou") % [nome, Catalogo.nome(deixa)])
			else:
				_avisar(_texto("caiu") % nome)
	return true


## Quem está no golpe: ao alcance dele e do lado para onde ele vai (`frente`).
## A meia-lua varre quase meia volta e pega todos; o resto pega o mais perto.
func criaturas_no_golpe(g: Dictionary) -> Array:
	if g.is_empty():
		return []
	var frente := frente_do_jogador()
	var de: Vector3 = _player.global_position
	var achadas: Array = []
	for c in _vivas():
		var para: Vector3 = Criatura._plano(c.global_position - de)
		var distancia := para.length()
		if distancia > float(g["alcance"]) * u_por_px:
			continue
		if distancia > COLADA * u_por_px and para.normalized().dot(frente) < float(g["frente"]):
			continue
		achadas.append(c)
	achadas.sort_custom(func(a, b): return a.global_position.distance_to(de) < b.global_position.distance_to(de))
	if not bool(g["varios"]) and achadas.size() > 1:
		achadas = [achadas[0]]
	return achadas


func frente_do_jogador() -> Vector3:
	var giro: float = _player.visual.rotation.y
	return Vector3(sin(giro), 0.0, cos(giro))


func _olhar_para(ponto: Vector3) -> void:
	var para: Vector3 = Criatura._plano(ponto - _player.global_position)
	if para.length() > 0.01:
		_player.visual.rotation.y = atan2(para.x, para.z)


func _criatura_perto(raio: float):
	for c in _vivas():
		if Criatura._plano(c.global_position - _player.global_position).length() <= raio:
			return c
	return null


## O BRAÇO. No estilo Tripo, o clipe `chop` do personagem (o gesto 7); no
## procedural o gesto 7 é uma reverência, e o golpe vira o corpo jogado para
## a frente — o fallback que a #14 aceita até haver clipe dos dois estilos.
func _animar_o_golpe() -> void:
	var animador = _player.animator
	if not Estilo.procedural() and animador != null and animador.has_method("play_gesture"):
		if animador.play_gesture(6) != "":
			return
	_empurrar_o_corpo(frente_do_jogador() * 0.22, 0.08, 0.14)


func _empurrar_o_corpo(deslocamento: Vector3, ida: float, volta: float) -> void:
	var visual: Node3D = _player.visual
	var tween := create_tween()
	tween.tween_property(visual, "position", _repouso_do_corpo + visual.get_parent().global_basis.inverse() * deslocamento, ida)
	tween.tween_property(visual, "position", _repouso_do_corpo, volta)


# --- a ginga -----------------------------------------------------------------

## A GINGA, para quem aprendeu: gasta um pouco de fôlego, joga o corpo de lado
## — para onde ele já ia, ou para trás, parado — e o deixa fora do alcance do
## bote pelo tempo `Luta.GINGA.livre`. O passo anda por colisão (`_physics_process`),
## então a ginga não atravessa parede.
func gingar() -> bool:
	if not Luta.sabe("ginga"):
		return false
	var custo := Luta.folego_da_ginga()
	if not Energia.aguenta("bater", custo):
		_avisar(_texto("cansado"))
		return true
	Energia.gastar("bater", custo)
	var andando: Vector3 = Criatura._plano(_player.velocity)
	_ginga_rumo = andando.normalized() if andando.length() > 0.3 else -frente_do_jogador()
	_ginga_resta = float(Luta.GINGA["duracao"])
	Vida.livrar(float(Luta.GINGA["livre"]))
	# O corpo abaixa no passo, a base da ginga: é a esquiva dos dois estilos
	# enquanto não houver clipe dela.
	_empurrar_o_corpo(Vector3.UP * -0.18, float(Luta.GINGA["duracao"]) * 0.4, float(Luta.GINGA["duracao"]) * 0.6)
	return true


func _physics_process(delta: float) -> void:
	if _ginga_resta <= 0.0 or _player == null:
		return
	var passo := minf(delta, _ginga_resta)
	_ginga_resta -= passo
	var velocidade := float(Luta.GINGA["distancia"]) * u_por_px / float(Luta.GINGA["duracao"])
	_player.move_and_collide(_ginga_rumo * velocidade * passo)


# --- o que se vê -------------------------------------------------------------

## O NÚMERO DA PANCADA: sobe e some sobre quem apanhou.
func mostrar_pancada(onde: Vector3, texto: String, cor: Color) -> void:
	var rotulo := Label3D.new()
	rotulo.text = texto
	rotulo.modulate = cor
	rotulo.outline_modulate = Color(0.05, 0.05, 0.05, 0.9)
	rotulo.outline_size = 8
	rotulo.font_size = 48
	rotulo.pixel_size = 0.006
	rotulo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	rotulo.no_depth_test = true
	add_child(rotulo)
	rotulo.global_position = onde + Vector3(0.0, ALTURA_DA_PANCADA, 0.0)
	var tween := rotulo.create_tween()
	tween.set_parallel(true)
	tween.tween_property(rotulo, "global_position:y", rotulo.global_position.y + SOBE_A_PANCADA, DURA_A_PANCADA)
	tween.tween_property(rotulo, "modulate:a", 0.0, DURA_A_PANCADA).set_delay(DURA_A_PANCADA * 0.4)
	tween.chain().tween_callback(rotulo.queue_free)


func _ao_ferir_o_jogador(quanto: float) -> void:
	if quanto > 0.0 and _player != null:
		mostrar_pancada(_player.global_position, "%d" % maxi(1, roundi(quanto)), COR_DO_JOGADOR_FERIDO)


func _ao_mudar_a_peconha(esta: bool) -> void:
	if _player != null:
		mostrar_pancada(_player.global_position, _texto("veneno") if esta else _texto("cortou"),
			COR_DA_PECONHA if esta else COR_DA_ESQUIVA)


func _ao_esquivar_o_bote(_especie: String) -> void:
	if _player != null:
		mostrar_pancada(_player.global_position, _texto("escapou"), COR_DA_ESQUIVA)


func _avisar(texto: String) -> void:
	if _hud != null:
		_hud.set_notice(texto)
