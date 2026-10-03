extends Node3D
## AS CONSTRUÇÕES POR DENTRO: a porta de fora, o cômodo, e a passagem entre os dois.
##
## O vale não tinha cômodo nenhum (#26: "o buraco maior"). A primeira
## construção que se abre é a igreja do Bom Jesus (`interior_igreja.gd`).
##
##
## POR QUE O CÔMODO MORA LONGE
##
## A igreja do Tripo é UMA malha fechada, com colisão em caixa: não há como
## entrar nela. Em vez de esvaziar o modelo, o cômodo é montado à parte, num
## canto do quadro e bem acima do vale (`ALTURA`), e a porta de fora leva até
## ele com um escurecer rápido — como as casas do Stardew e as cavernas do
## Skyrim. Lá em cima o mar não chega, o bicho não caça e os sons de lugar
## (mar, fogueira) somem sozinhos.
##
## O que precisa saber que o jogador está no vale — a bússola, o mapa, o Pedro
## que o segue, o save — pergunta a `posicao_no_mapa()` do jogador, que dentro
## é a porta de fora. O Pedro espera na porta.
##
##
## A TECLA
##
## O E de interagir, com a dica em cima da porta, como o resto do vale. Este nó
## entra no vale por último, e por isso ouve o E antes dos outros: na soleira,
## a porta vale mais que o coqueiro do adro.

signal entrou(qual: String)
signal saiu(qual: String)

const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")
const DicaTecla = preload("res://scripts/prototipo_3d/dica_tecla.gd")
const InteriorIgreja = preload("res://scripts/prototipo_3d/interior_igreja.gd")

## Onde os cômodos moram: num canto do quadro do mapa, e BEM ACIMA do vale.
##
## Não podem morar fora do quadro: o mundo jogável é o retângulo 16:9, e o mar
## põe paredes invisíveis nas quatro bordas dele (`Mar._paredes`, planos sem
## fim). Corpo posto além da borda é empurrado de volta até ela no quadro
## seguinte — foi assim que o primeiro teste da igreja achou o jogador caindo
## do céu na borda do mapa. Dentro do quadro e a 400 de altura, nenhuma conta
## de água vale, o bicho não alcança e o som de lugar não chega.
const ALTURA := 400.0
const RECUO_DA_BORDA := 40.0
## Da porta de fora, a que distância a dica aparece e o E entra.
const ALCANCE_DA_PORTA := 3.0
## Longe assim do cômodo, quem estava dentro saiu por outra porta: a queda que
## leva à cama, o "Destravar o boneco" do J, o R que reinicia.
const SAIU_POR_OUTRO_LADO := 120.0
const ESCURECER := 0.28

## As construções que se abrem: a âncora do vale, o nome que o HUD escreve, e a
## profundidade da fachada no estilo procedural (no Tripo ela é medida).
const CONSTRUCOES := {
	"igreja": {"ancora": "Igreja", "nome": "Igreja do Bom Jesus", "fachada_procedural": 7.15},
}

var _mundo: Node3D
var _jogador: Node3D
var _hud
## qual -> {"porta": Vector3 (fora), "frente": Vector3, "sala": Node3D}
var _portas: Dictionary = {}
var _dentro := ""
var _na_porta := ""
var _dica: PanelContainer
var _veu: ColorRect
var _passando := false


func configurar(mundo: Node3D, jogador: Node3D, hud) -> void:
	_mundo = mundo
	_jogador = jogador
	_hud = hud
	_dica = DicaTecla.criar(hud.map_layer(), Atalhos.letra("interagir"), "Entrar")
	var camada := CanvasLayer.new()
	camada.layer = 29
	add_child(camada)
	_veu = ColorRect.new()
	_veu.name = "Veu"
	_veu.color = Color(0, 0, 0, 0)
	_veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veu.set_anchors_preset(Control.PRESET_FULL_RECT)
	camada.add_child(_veu)
	var longe := Vector3(0.0, ALTURA, 0.0)
	if mundo.has_method("has_map_frame") and mundo.has_map_frame():
		var quadro: Rect2 = mundo.get_map_frame()
		longe = Vector3(quadro.position.x + RECUO_DA_BORDA, ALTURA, quadro.position.y + RECUO_DA_BORDA)
	var indice := 0
	for qual in CONSTRUCOES:
		var porta := _porta_de_fora(qual)
		if not porta.is_finite():
			continue
		var sala: Node3D = null
		match qual:
			"igreja":
				sala = InteriorIgreja.new()
		if sala == null:
			continue
		sala.name = "Interior_" + qual
		# A nave corre para -Z a partir da porta: a sala começa um comprimento
		# para dentro do quadro, para caber inteira nele.
		sala.position = longe + Vector3(indice * 60.0, 0.0, InteriorIgreja.COMPRIMENTO + 2.0)
		add_child(sala)
		_portas[qual] = {"porta": porta, "frente": _frente(qual), "sala": sala}
		indice += 1


## Em que construção o jogador está, ou "".
func dentro() -> String:
	return _dentro


func porta_de(qual: String) -> Vector3:
	return (_portas[qual]["porta"] as Vector3) if _portas.has(qual) else Vector3.INF


func sala_de(qual: String) -> Node3D:
	return _portas[qual]["sala"] if _portas.has(qual) else null


## A PORTA DE FORA: no meio da fachada, rente ao chão. A fachada é a frente do
## lote (`<âncora>Frente`), a mesma que põe o cruzeiro no adro; a distância do
## meio dela é a metade da caixa do modelo do Tripo, ou a medida do procedural.
func _porta_de_fora(qual: String) -> Vector3:
	var dado: Dictionary = CONSTRUCOES[qual]
	var ancora := str(dado["ancora"])
	if _mundo == null or not ("ancoras" in _mundo) or not _mundo.ancoras.has(ancora):
		return Vector3.INF
	var base: Vector3 = _mundo.ancoras[ancora]
	var meia := float(dado.get("fachada_procedural", 6.0))
	var modelo := _mundo.get_node_or_null(ancora.capitalize() + "Tripo")
	if modelo != null and modelo.has_meta("limites"):
		meia = (modelo.get_meta("limites") as AABB).size.z * 0.5
	var ponto := base + _frente(qual) * (meia + 0.8)
	return _mundo.ground_position(ponto, 0.05) if _mundo.has_method("ground_position") else ponto


func _frente(qual: String) -> Vector3:
	var ancora := str(CONSTRUCOES[qual]["ancora"])
	var frente: Vector3 = _mundo.ancoras.get(ancora + "Frente", Vector3.BACK)
	frente.y = 0.0
	return frente.normalized() if frente.length() > 0.01 else Vector3.BACK


func _process(_delta: float) -> void:
	if _jogador == null or _passando:
		return
	# SAIU POR OUTRA PORTA: a queda, o destravar e o reinício tiram o corpo da
	# sala sem passar por aqui. O estado de dentro não pode ficar valendo.
	if _dentro != "" and _jogador.global_position.distance_to((_portas[_dentro]["sala"] as Node3D).global_position) > SAIU_POR_OUTRO_LADO:
		_marcar_fora()
	_na_porta = ""
	var camera := get_viewport().get_camera_3d()
	if _dentro != "":
		var sala: Node3D = _portas[_dentro]["sala"]
		if sala.perto_da_porta(_jogador.global_position):
			_na_porta = _dentro
			DicaTecla.mostrar_em(_dica, camera, sala.porta() + Vector3(0, 0.4, 0), tr("Sair"))
			return
	else:
		for qual in _portas:
			var porta: Vector3 = _portas[qual]["porta"]
			var aqui: Vector3 = _jogador.global_position
			if Vector2(aqui.x - porta.x, aqui.z - porta.z).length() <= ALCANCE_DA_PORTA and absf(aqui.y - porta.y) < 3.0:
				_na_porta = qual
				# Na altura do peito, como as outras dicas: em cima do batente ela
				# saía do alto da tela com a câmera colada na porta.
				DicaTecla.mostrar_em(_dica, camera, porta + Vector3(0, 1.5, 0),
					tr("Entrar: %s") % str(CONSTRUCOES[qual]["nome"]))
				return
	_dica.visible = false


func _unhandled_key_input(event: InputEvent) -> void:
	if _na_porta == "" or _passando:
		return
	if not (event is InputEventKey and event.pressed and not event.echo
			and event.physical_keycode == Atalhos.tecla("interagir")):
		return
	# Com tela aberta, ou com o corpo parado (o escuro da queda), a porta não abre.
	if get_tree().paused or not _jogador.is_physics_processing():
		return
	get_viewport().set_input_as_handled()
	if _dentro != "":
		sair()
	else:
		entrar(_na_porta)


## ENTRA na construção: escurece, põe o corpo na soleira de dentro, clareia.
func entrar(qual: String) -> void:
	if not _portas.has(qual) or _dentro != "" or _passando:
		return
	_passando = true
	_dica.visible = false
	Audio.efeito("porta_abrir")
	await _escurecer(1.0)
	var sala: Node3D = _portas[qual]["sala"]
	_jogador.porta_do_interior = _portas[qual]["porta"]
	_jogador.teleportar(sala.chegada(), PI)
	_dentro = qual
	Audio.efeito("porta_fechar")
	entrou.emit(qual)
	await get_tree().physics_frame
	await _escurecer(0.0)
	_passando = false


## SAI para a porta de fora, de costas para ela e de frente para o adro.
func sair() -> void:
	if _dentro == "" or _passando:
		return
	_passando = true
	_dica.visible = false
	Audio.efeito("porta_abrir")
	await _escurecer(1.0)
	var qual := _dentro
	var frente: Vector3 = _portas[qual]["frente"]
	_jogador.teleportar(_portas[qual]["porta"] + frente * 0.6, atan2(frente.x, frente.z))
	_marcar_fora()
	Audio.efeito("porta_fechar")
	await get_tree().physics_frame
	await _escurecer(0.0)
	_passando = false


func _marcar_fora() -> void:
	var qual := _dentro
	_dentro = ""
	_jogador.porta_do_interior = Vector3.INF
	if qual != "":
		saiu.emit(qual)


func _escurecer(alvo: float) -> void:
	if not is_instance_valid(_veu):
		return
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_veu, "color:a", alvo, ESCURECER)
	await tween.finished
