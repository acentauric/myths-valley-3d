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
## AS ONÇAS (#28) moram nas duas pontas da Mata: a pintada no penedo, junto das
## Pedras, como no 2D; a preta na outra ponta, e só do entardecer à madrugada.
## Ficam numa lista própria (`oncas`), e não em `criaturas`: `criaturas` é o
## que a mata repõe perto da vila — o caititu —, e é por ela que o caderno, a
## Caipora e a partida salva perguntam. A luta vale para todas (`_vivas`).
## Quando uma onça vê o jogador pela primeira vez, o HUD avisa; enquanto
## alguma caça, toca a música da mata.
##
## A mão se escolhe pela barra (1–0) e consulta `Equipamento.no_encaixe`:
## o jogador equipa a arma pela interface; de mão vazia, luta quem aprendeu
## a capoeira. O que o
## bicho deixa fica no chão e no save, até ser recolhido com E (#67).

const Criatura = preload("res://scripts/prototipo_3d/criatura_vale.gd")
const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")
const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")
const FocoDoE = preload("res://scripts/prototipo_3d/foco_do_e.gd")
const TEXTOS := "res://data/luta.json"
## COM BICHO AO ALCANCE, O E É GOLPE ANTES DE TUDO (`foco_do_e.gd`): conversa,
## cordel e árvore esperam. Antes era a ordem dos nós no vale que decidia.
const VIES_DA_LUTA := 1000.0

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

## As onças e onde cada uma mora (ver `ponto_da_onca`).
const NINHOS_DA_ONCA := ["pintada", "preta"]
const ONCA_LONGE_DO_CAITITU := 30.0
const ONCA_LONGE_DE_CASA := 120.0
const ONCA_LONGE_DA_CHEGADA := 60.0
const ONCA_LONGE_DA_RUA := 25.0
## Entre a pintada e a preta, ou a preta vai para a serra.
const ONCAS_SEPARADAS := 40.0
## O penedo: até onde das Pedras se procura o ninho da pintada, e até onde
## dele vale "colado na mata" mesmo fora do polígono.
const PENEDO_BUSCA := 30.0
const PENEDO_COLADO := 12.0
const PASSO_DA_ONCA := 2.0
## Chão de onça: acima da praia (onde a terra acaba, a colisão da terra também, e
## quem nasce ali cai no vazio) e longe das pedras da orla.
const ONCA_CHAO_MINIMO := 1.8
const PENEDO_LONGE_DA_PRAIA := 8.0
## O PENEDO COM LAPA de cada onça (o GLB `penedo_lapa`): o tamanho em relação ao
## do catálogo, quanto atrás do ninho fica o centro dele (u) e o giro que põe a
## boca da lapa de frente para o ninho.
const PENEDO_TAMANHO := 0.75
const PENEDO_ATRAS := 4.2
const PENEDO_GIRO := 0.0
## Quando a onça-preta anda.
const PRETA_ANDA := ["entardecer", "noite", "madrugada"]
## De quanto em quanto tempo a luta confere a música e a hora da preta (s).
const CONFERIR_A_CADA := 0.25

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
## As onças da Mata, fora de `criaturas` (ver o cabeçalho).
var oncas: Array = []
## Algum bicho já viu o jogador nesta partida? O aviso é só da primeira vez.
var avisou_da_onca := false
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
var _conferir_em: float = 0.0
var _musica_da_caca := false
var coleta: Node3D


func configurar(world, player, hud, camada: Control = null) -> void:
	_world = world
	_player = player
	_hud = hud
	if camada != null:
		coleta = preload("res://scripts/prototipo_3d/coleta_no_chao.gd").new()
		coleta.name = "Coleta"
		add_child(coleta)
		coleta.configurar(world, player, hud, camada)
	add_to_group(FocoDoE.GRUPO)
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
	var outra := Vector3.INF
	for pelagem in NINHOS_DA_ONCA:
		var ninho := ponto_da_onca(pelagem, outra)
		if not ninho.is_finite():
			push_warning("Luta: não achei onde a onça %s mora" % pelagem)
			continue
		nascer("onca", ninho, pelagem)
		outra = ninho
	_conferir_a_preta()


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


## ONDE A ONÇA MORA. A pintada, no penedo: o ponto bom mais perto das Pedras,
## dentro da Mata ou colado nela. A preta, na outra ponta: o ponto bom da Mata
## mais longe da pintada, se ficar a `ONCAS_SEPARADAS` dela; senão, na serra
## além da rua do mirante. Ponto bom é terra firme, longe do ninho do caititu,
## das casas, da chegada e das ruas — onça não mora no caminho de ninguém.
func ponto_da_onca(pelagem: String, outra: Vector3 = Vector3.INF) -> Vector3:
	var regiao = _world.get("_region")
	if regiao == null:
		return Vector3.INF
	var mata: PackedVector2Array = regiao._kml_forest if regiao._kml_forest.size() >= 3 else regiao._forest
	var pedras: Vector3 = _world.ancoras.get("Pedras", Vector3.INF)
	var melhor := Vector3.INF
	if pelagem == "pintada" and pedras.is_finite():
		var melhor_d := INF
		var passos := int(PENEDO_BUSCA / PASSO_DA_ONCA)
		for i in range(-passos, passos + 1):
			for j in range(-passos, passos + 1):
				var p := pedras + Vector3(i * PASSO_DA_ONCA, 0.0, j * PASSO_DA_ONCA)
				var d := Criatura._plano(p - pedras).length()
				if d >= melhor_d or d > PENEDO_BUSCA or d < PENEDO_LONGE_DA_PRAIA:
					continue
				if not (_world.na_mata_fechada(p) or (d <= PENEDO_COLADO and _na_mata(mata, p))) and d > PENEDO_COLADO:
					continue
				if _serve_para_onca(p):
					melhor = p
					melhor_d = d
	elif pelagem != "pintada" and mata.size() >= 3:
		var caixa := Rect2(mata[0], Vector2.ZERO)
		for ponto in mata:
			caixa = caixa.expand(ponto)
		var melhor_d := -INF
		var x := caixa.position.x
		while x <= caixa.end.x:
			var z := caixa.position.y
			while z <= caixa.end.y:
				var p := Vector3(x, 0.0, z)
				z += PASSO_DA_ONCA * 2.0
				if not _world.na_mata_fechada(p) or not _serve_para_onca(p):
					continue
				var d := Criatura._plano(p - outra).length() if outra.is_finite() else 0.0
				if d > melhor_d:
					melhor = p
					melhor_d = d
			x += PASSO_DA_ONCA * 2.0
		if outra.is_finite() and melhor_d < ONCAS_SEPARADAS:
			melhor = _ponto_na_serra(regiao, outra)
	return _world.ground_position(melhor, 0.05) if melhor.is_finite() else Vector3.INF


func _na_mata(mata: PackedVector2Array, p: Vector3) -> bool:
	return mata.size() >= 3 and Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), mata)


func _serve_para_onca(p: Vector3) -> bool:
	if not _world.is_on_land(p) or _world.ground_height_at(p) < ONCA_CHAO_MINIMO:
		return false
	for c in criaturas:
		if is_instance_valid(c) and Criatura._plano(c._ninho - p).length() < ONCA_LONGE_DO_CAITITU:
			return false
	if Criatura._plano(_player.spawn_position - p).length() < ONCA_LONGE_DA_CHEGADA:
		return false
	var lotes: Dictionary = _world.get("_lotes") if _world.get("_lotes") != null else {}
	for nome in lotes:
		if Criatura._plano(_world.ancoras.get(nome, Vector3.INF) - p).length() < ONCA_LONGE_DE_CASA:
			return false
	var regiao = _world.get("_region")
	if regiao != null:
		var ponto := Vector2(p.x, p.z)
		for rua in regiao._roads:
			if (rua.bounds as Rect2).grow(ONCA_LONGE_DA_RUA).has_point(ponto) \
					and regiao._distance_to_line(ponto, rua.points) < ONCA_LONGE_DA_RUA + float(rua.width) * 0.5:
				return false
	return true


## A SERRA ALÉM DA RUA DO MIRANTE, quando a Mata é curta para duas onças: o
## ponto bom mais longe da outra entre 30 e 60 u da metade de cima da rua,
## dentro da mata cênica (o predicado de mata da serra; o da Mata do KML não a
## alcança).
func _ponto_na_serra(regiao, outra: Vector3) -> Vector3:
	var mata_da_serra: PackedVector2Array = regiao._forest
	var melhor := Vector3.INF
	var melhor_d := -INF
	for rua in regiao._roads:
		if String(rua.name) != "Rua do mirante":
			continue
		var pontos: PackedVector2Array = rua.points
		for k in range(int(pontos.size() * 0.5), pontos.size(), 6):
			for giro in 8:
				for raio in [30.0, 45.0, 60.0]:
					var q: Vector2 = pontos[k] + Vector2.RIGHT.rotated(TAU * giro / 8.0) * raio
					var p := Vector3(q.x, 0.0, q.y)
					if mata_da_serra.size() >= 3 and not _na_mata(mata_da_serra, p):
						continue
					if not _serve_para_onca(p):
						continue
					var d := Criatura._plano(p - outra).length()
					if d > melhor_d:
						melhor = p
						melhor_d = d
	return melhor


func nascer(especie: String, onde: Vector3, pelagem: String = ""):
	var bicho = Criatura.new()
	bicho.especie = especie
	bicho.pelagem = pelagem
	bicho.name = "Criatura_%s" % (especie if pelagem == "" else especie + "_" + pelagem)
	add_child(bicho)
	bicho.global_position = onde
	bicho.configurar(_world, _player, u_por_px)
	bicho.morreu.connect(_ao_morrer)
	if bicho.tem_vista():
		bicho.avistou.connect(_ao_avistar)
		oncas.append(bicho)
		_montar_o_penedo(bicho)
	else:
		criaturas.append(bicho)
	return bicho


## O PENEDO COM LAPA do ninho da onça: fica atrás dela, com a boca da lapa
## virada para o ninho — e, portanto, para a vila, de onde o jogador vem. Uma vez
## só por ninho: a onça que a mata repõe volta ao mesmo penedo. No Tripo é o GLB
## com a colisão da pegada; no procedural, três pedras cinza amassadas.
func _montar_o_penedo(onca) -> void:
	var nome := "Penedo da onça %s" % onca.pelagem
	if _world.get_node_or_null(nome) != null:
		return
	var ninho: Vector3 = onca._ninho
	var para_a_vila := Criatura._plano(_player.spawn_position - ninho).normalized()
	if para_a_vila == Vector3.ZERO:
		para_a_vila = Vector3.BACK
	var raiz := Node3D.new()
	raiz.name = nome
	_world.add_child(raiz)
	var centro: Vector3 = _world.ground_position(ninho - para_a_vila * PENEDO_ATRAS, 0.0)
	raiz.global_position = centro
	var giro := atan2(para_a_vila.x, para_a_vila.z) + PENEDO_GIRO
	if Estilo.tripo() and CatalogoAssets.tem_tripo("penedo_lapa"):
		var modelo := CatalogoAssets.instanciar("penedo_lapa", raiz, Vector3.ZERO, PENEDO_TAMANHO, giro)
		CatalogoAssets.colisao("penedo_lapa", modelo, raiz, Vector3.ZERO, PENEDO_TAMANHO, giro)
		return
	var tinta := StandardMaterial3D.new()
	tinta.albedo_color = Color(0.43, 0.41, 0.38)
	tinta.roughness = 1.0
	var corpo := StaticBody3D.new()
	corpo.name = "Colisao"
	corpo.collision_layer = 1
	raiz.add_child(corpo)
	for pedra: Array in [[Vector3(0.0, 1.0, 0.0), Vector3(2.7, 1.9, 2.3)], [Vector3(-1.8, 0.7, 0.9), Vector3(1.7, 1.3, 1.5)], [Vector3(1.9, 0.6, 0.6), Vector3(1.5, 1.1, 1.4)]]:
		var malha := MeshInstance3D.new()
		var esfera := SphereMesh.new()
		esfera.radius = 1.0
		esfera.height = 2.0
		esfera.radial_segments = 14
		esfera.rings = 7
		malha.mesh = esfera
		malha.material_override = tinta
		malha.scale = pedra[1] * 0.5
		malha.position = (pedra[0] as Vector3).rotated(Vector3.UP, giro)
		raiz.add_child(malha)
		var forma := CollisionShape3D.new()
		var caixa := BoxShape3D.new()
		caixa.size = (pedra[1] as Vector3) * 0.8
		forma.shape = caixa
		forma.position = malha.position
		corpo.add_child(forma)


func _ao_morrer(bicho) -> void:
	# A ESPÉCIE ÚNICA (a Matinta, "unica", #31) cai uma vez e não volta com os dias.
	if bool(bicho.dados().get("unica", false)):
		criaturas.erase(bicho)
		oncas.erase(bicho)
		return
	var volta := int(bicho.dados().get("volta", 3))
	var morte := {"especie": bicho.especie, "ninho": bicho._ninho,
		"volta_em": Relogio.dia_absoluto() + volta}
	if bicho.pelagem != "":
		morte["pelagem"] = bicho.pelagem
	mortes.append(morte)
	criaturas.erase(bicho)
	oncas.erase(bicho)


## A PRIMEIRA VEZ QUE UMA ONÇA VÊ O JOGADOR, o HUD diz — só a primeira: o aviso
## ensina que ela caça com os olhos, e repetido vira ruído.
func _ao_avistar(_bicho) -> void:
	if avisou_da_onca:
		return
	avisou_da_onca = true
	_avisar(_texto("onca_viu"))


## A música da mata enquanto alguma onça caça, e a hora da preta.
func _conferir_as_oncas(delta: float) -> void:
	_conferir_em -= delta
	if _conferir_em > 0.0:
		return
	_conferir_em = CONFERIR_A_CADA
	_conferir_a_preta()
	var caca := false
	for onca in oncas:
		if is_instance_valid(onca) and onca.cacando and not onca.morto():
			caca = true
	if caca:
		# Repetido de propósito: o ambiente desliga a música quando o jogador sai
		# da mata, e quem foge da onça sai da mata com ela atrás.
		Audio.tocar_musica_mata(true)
	elif _musica_da_caca:
		Audio.tocar_musica_mata(_player != null and _world.na_mata_fechada(_player.global_position))
	_musica_da_caca = caca


## A onça-preta só anda do entardecer à madrugada. Caçando, ela termina a caça.
func _conferir_a_preta() -> void:
	var anda: bool = Dia.periodo() in PRETA_ANDA
	for onca in oncas:
		if is_instance_valid(onca) and onca.pelagem == "preta" and not onca.morto() \
				and onca.ativa() != anda and not onca.cacando:
			onca.ativar(anda)


## A MATA REPÕE quem morreu, em dias (`volta` da espécie): três no caititu.
## Matar limpa a mata por uns dias, e não para sempre.
func _ao_comecar_o_dia(_dia: int, _estacao: int, _ano: int) -> void:
	var hoje := Relogio.dia_absoluto()
	for morte in mortes.duplicate():
		if hoje >= int(morte["volta_em"]):
			mortes.erase(morte)
			nascer(str(morte["especie"]), morte["ninho"], str(morte.get("pelagem", "")))


## A partida salva diz quem caiu e ainda não voltou (#7). Quem está nessa
## lista não pode estar de pé no vale recém-montado: o caititu que o jogador
## derrubou ontem não reaparece só porque o jogo foi fechado e aberto.
func restaurar_mortes(lista: Array) -> void:
	mortes = []
	for morte in lista:
		if morte is Dictionary:
			mortes.append(morte.duplicate(true))
	for morte in mortes:
		for c in criaturas + oncas:
			if is_instance_valid(c) and not c.morto() and c.especie == str(morte.get("especie", "")) \
					and Criatura._plano(c._ninho - morte.get("ninho", Vector3.INF)).length() < 1.0:
				criaturas.erase(c)
				oncas.erase(c)
				c.queue_free()


## Quem está de pé para a luta: os da mata e as onças que andam agora.
func _vivas() -> Array:
	return (criaturas + oncas).filter(func(c): return is_instance_valid(c) and not c.morto() and c.ativa())


# --- a tecla -----------------------------------------------------------------

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if _player == null or not _player.is_physics_processing():
		return
	if event.physical_keycode == Atalhos.tecla("interagir"):
		if FocoDoE.e_dele(self) and armar_a_luta():
			get_viewport().set_input_as_handled()
	elif event.physical_keycode == Atalhos.tecla("gingar"):
		if gingar():
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _golpe_segurado_desde >= 0.0:
		_conferir_o_golpe_segurado()
	if _world != null:
		_conferir_as_oncas(delta)


## O QUE O E FARIA AQUI, para o foco: o golpe no bicho ao alcance, antes de tudo.
func alvo_do_e() -> Dictionary:
	if _player == null or not _player.is_physics_processing():
		return {}
	if Luta.golpe_da_mao(_item_em_uso(), false) == "":
		return {}
	var bicho = _criatura_perto(ALCANCE_DE_LUTA * u_por_px)
	return {} if bicho == null else {"ponto": bicho.global_position, "vies": VIES_DA_LUTA}


## O E apertou com bicho perto: o corpo se vira para ele e começa a contar o
## segurar. Devolve false quando não há luta — e aí o E segue para o resto.
func armar_a_luta() -> bool:
	var mao := _item_em_uso()
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
	var mao := _item_em_uso()
	var golpe := Luta.golpe_da_mao(mao, ainda)
	if golpe != "":
		bater(golpe, mao)


## Com que se bate: o que está na barra de mão (a mão livre bate de punho).
## Arma vai nos números; o encaixe das Mãos é das luvas.
func _item_em_uso() -> String:
	return Inventario.na_mao()


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
	_animar_o_golpe(2, mao == "")
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
			if deixa != "" and coleta != null and coleta.deixar(deixa, quantos, onde):
				var textos: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/coleta_no_chao.json"))
				_avisar(str(IdiomaMenu.campo(textos.caiu, "texto")) % [nome, Catalogo.nome(deixa)])
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
func _animar_o_golpe(repeticoes: int = 2, de_mao_vazia: bool = false) -> bool:
	var animador = _player.animator
	# De mão vazia o golpe sai como o soco do Mixamo (#190), quando o corpo o tem.
	if de_mao_vazia and animador != null and animador.has_method("soco") and bool(animador.soco()):
		return true
	if animador != null and animador.has_method("play_chop"):
		if animador.play_chop(repeticoes) != "":
			return true
	_empurrar_o_corpo(frente_do_jogador() * 0.22, 0.08, 0.14)
	return false


## Reaproveita o mesmo golpe visual para interações com objetos do vale.
func animar_golpe(repeticoes: int = 2) -> bool:
	# O som do corte é disparado por ArvoresInfo no impacto da animação.
	return _animar_o_golpe(repeticoes)


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
