class_name SetaMissao
extends Node3D
## Marcador do alvo da missão atual, em duas partes: no MUNDO, um cone dourado
## invertido flutuando sobre o alvo e um anel raso pulsando no chão; na TELA, um
## chevron dourado preso à borda apontando o rumo quando o alvo sai do campo de
## visão da câmera. API: definir_alvo(pos, texto) e limpar().
##
## O chevron tem PESO (`suavizador_de_tela.gd`): desliza até o lugar dele em vez de colar
## no ponto projetado a cada quadro, gira pelo caminho curto, e acende e apaga em vez de
## piscar — o salto da borda da tela para cima do alvo, quando ele entra no campo de visão,
## é um deslizar. `alvo_atual` diz o ponto aos que precisam saber (a placa de nome de
## quem a missão aponta).

const SuavizadorDeTela = preload("res://scripts/prototipo_3d/suavizador_de_tela.gd")
const PopupsDoMundo = preload("res://scripts/prototipo_3d/popups_do_mundo.gd")

const COR := Color("e2c47f")
## O peso do chevron, o giro dele (s) e o quanto ele acende e apaga (s).
const TEMPO_DE_SEGUIR := 0.22
const CORREIA := 130.0
const TEMPO_DO_GIRO := 0.09
const SEGUNDOS_DO_FADE := 0.18
## Altura (u) do cone acima do alvo e amplitude do sobe-e-desce.
const ALTURA_CONE := 1.8
const BOB := 0.12
## Chegar recolhe a orientação; a margem maior para sair evita piscar.
const RAIO_CHEGADA := 2.4
const RAIO_SAIDA := 3.2
## Margem (px) da borda da tela onde o chevron se prende.
const MARGEM_TELA := 28.0
## Alvo visível na tela e mais perto que isto (u): o chevron some (o cone basta).
const PERTO := 25.0
## Meio lado (px) do Control do chevron (pivô no centro para girar).
const MEIO_CHEVRON := 24.0

var _alvo := Vector3.ZERO
var _ativo := false
var _chegou := false
var _jogador: Node3D
var _tempo := 0.0
var _cone: MeshInstance3D
var _anel: MeshInstance3D
var _chevron: ChevronMissao
## O peso do chevron, e o quanto ele está aceso (0 a 1).
var _mola := SuavizadorDeTela.new()
var _alfa := 0.0
var _loucura_no: Node


func _ready() -> void:
	add_to_group(PopupsDoMundo.GRUPO_SETA)
	visible = false
	# Um só material para cone e anel: emissivo suave para ler de longe e à noite,
	# translúcido para não esconder o lugar que ele marca.
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(COR.r, COR.g, COR.b, 0.45)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = COR
	material.emission_energy_multiplier = 0.3
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cone_malha := CylinderMesh.new()
	# Raio em cima e zero embaixo: cone de ponta-cabeça, apontando o chão do alvo.
	cone_malha.top_radius = 0.24
	cone_malha.bottom_radius = 0.0
	cone_malha.height = 0.55
	# Sem tampa: a câmera interna nunca vê um disco sólido do cone.
	cone_malha.cap_top = false
	cone_malha.cap_bottom = false
	cone_malha.material = material
	_cone = MeshInstance3D.new()
	_cone.name = "Cone"
	_cone.mesh = cone_malha
	_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cone.position = Vector3(0, ALTURA_CONE, 0)
	add_child(_cone)
	var anel_malha := TorusMesh.new()
	anel_malha.inner_radius = 0.45
	anel_malha.outer_radius = 0.6
	anel_malha.material = material
	_anel = MeshInstance3D.new()
	_anel.name = "Anel"
	_anel.mesh = anel_malha
	_anel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Achatado e um tico acima do chão: um anel raso, não uma rosquinha.
	_anel.scale = Vector3(1, 0.18, 1)
	_anel.position = Vector3(0, 0.08, 0)
	add_child(_anel)


## O chevron vive no overlay do HUD (hud.map_layer()), atrás do que abrir depois.
func configurar(camada: Control) -> void:
	_chevron = ChevronMissao.new()
	_chevron.name = "ChevronMissao"
	camada.add_child(_chevron)


## Passa a marcar `pos` (o texto já aparece no objetivo do HUD; fica só de registro).
func definir_alvo(pos: Vector3, _texto: String) -> void:
	if not pos.is_equal_approx(_alvo):
		_chegou = false
	_alvo = pos
	global_position = pos
	_ativo = true
	visible = true
	if is_instance_valid(_cone):
		_sincronizar_chegada()


## Missão acabou (ou não há alvo): marcador e chevron somem.
func limpar() -> void:
	_ativo = false
	visible = false
	_alfa = 0.0
	if is_instance_valid(_chevron):
		_chevron.visible = false


## O ponto que a seta marca agora, ou null sem missão acompanhada.
func alvo_atual() -> Variant:
	return _alvo if _ativo else null


## O nó da loucura do mapa (`loucura_do_mapa.gd`), achado pelo grupo; null sem ele.
func _loucura() -> Node:
	if not is_instance_valid(_loucura_no):
		_loucura_no = get_tree().get_first_node_in_group(&"loucura_do_mapa") if is_inside_tree() else null
	return _loucura_no


func _process(delta: float) -> void:
	if not _ativo:
		return
	_sincronizar_chegada()
	# O MAPA DOIDO (loucura_do_mapa.gd): o cone flutua longe do alvo de verdade. Fora da loucura o
	# desvio é zero, e a seta fica exatamente sobre o alvo.
	var louca := _loucura()
	if louca != null:
		var desvio: Vector2 = louca.deriva_do_alvo()
		global_position = _alvo + Vector3(desvio.x, 0.0, desvio.y)
	_tempo += delta
	# Cone flutua e gira devagar; o anel pulsa no chão.
	_cone.position.y = ALTURA_CONE + sin(_tempo * 2.4) * BOB
	_cone.rotation.y += delta * 1.6
	var pulso := 0.85 + 0.25 * sin(_tempo * 3.2)
	_anel.scale = Vector3(pulso, 0.18, pulso)
	_atualizar_chevron(delta)


## O destino lógico continua disponível ao mapa, às placas e ao testador.
## Só a orientação de deslocamento some: chegar não completa a missão.
func _sincronizar_chegada() -> void:
	if not is_instance_valid(_jogador):
		_jogador = get_tree().get_first_node_in_group("map_player") as Node3D
	if is_instance_valid(_jogador):
		var distancia := Vector2(_jogador.global_position.x - _alvo.x,
			_jogador.global_position.z - _alvo.z).length()
		if distancia <= RAIO_CHEGADA:
			_chegou = true
		elif distancia >= RAIO_SAIDA:
			_chegou = false
	var interiores := get_tree().get_first_node_in_group("interiores")
	var dentro := interiores != null and str(interiores.call("dentro")) != ""
	_cone.visible = not _chegou and not dentro
	_anel.visible = not _chegou and not dentro


## Fora do campo de visão, o chevron prende na borda apontando o rumo; na tela e
## longe, flutua sobre o ponto apontando para baixo; na tela e perto, some. Em
## todos os casos o lugar e o giro são alvos de uma mola, e o chevron acende e apaga.
func _atualizar_chevron(delta: float) -> void:
	if not is_instance_valid(_chevron):
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		_alfa = 0.0
		_chevron.visible = false
		return
	var ponto := _alvo + Vector3(0, 1.2, 0)
	var atras := camera.is_position_behind(ponto)
	var projecao := camera.unproject_position(ponto)
	var tamanho: Vector2 = _chevron.get_viewport_rect().size
	var area := Rect2(Vector2.ZERO, tamanho).grow(-MARGEM_TELA)
	var centro := tamanho * 0.5
	# Atrás da câmera o unproject espelha: inverte para apontar pelo lado certo.
	var rumo := projecao - centro
	if atras:
		rumo = -rumo
	if rumo.length_squared() < 1.0:
		rumo = Vector2(0, 1)
	# O MAPA DOIDO: o chevron aponta para o lado errado (erro zero fora da loucura).
	var louca := _loucura()
	var erro := 0.0
	if louca != null:
		erro = louca.erro_da_seta()
		if erro != 0.0:
			rumo = rumo.rotated(erro)
	var na_tela := not atras and area.has_point(projecao)
	var distancia := camera.global_position.distance_to(_alvo)
	var some := _chegou or (na_tela and distancia < PERTO)
	var pos := _mola.posicao
	var giro := _chevron.rotation
	if not some:
		if na_tela:
			# Visível mas longe: paira sobre o ponto, apontando para baixo, para ele.
			pos = projecao - Vector2(0, 46)
			giro = PI * 0.5
			if erro != 0.0:
				giro += erro
				pos += louca.deriva_na_tela(60.0)
		else:
			# Do centro rumo ao alvo até tocar a borda com a margem.
			var meia := centro - Vector2(MARGEM_TELA, MARGEM_TELA)
			var fator := minf(meia.x / maxf(absf(rumo.x), 0.001), meia.y / maxf(absf(rumo.y), 0.001))
			pos = centro + rumo * fator
			giro = rumo.angle()
	var quer := 0.0 if some else 1.0
	if quer > 0.0 and _alfa <= 0.0:
		# ACENDE NO LUGAR: o chevron que nasce não desliza de onde ficou da última vez.
		_mola.reiniciar(pos)
		_chevron.rotation = giro
	_alfa = move_toward(_alfa, quer, maxf(delta, 1.0 / 60.0) / SEGUNDOS_DO_FADE)
	_chevron.modulate.a = _alfa
	_chevron.visible = _alfa > 0.0
	if not _chevron.visible:
		return
	if not some:
		pos = _mola.seguir(pos, delta, TEMPO_DE_SEGUIR, SuavizadorDeTela.VELOCIDADE_MAXIMA,
			SuavizadorDeTela.ZONA_MORTA, CORREIA)
		_chevron.rotation = lerp_angle(_chevron.rotation, giro, 1.0 - exp(-delta / TEMPO_DO_GIRO))
	else:
		pos = _mola.posicao
	_chevron.position = pos - _chevron.pivot_offset
	_chevron.pulso = 0.7 + 0.3 * (0.5 + 0.5 * sin(_tempo * 3.2))
	_chevron.queue_redraw()


## Chevron 2D desenhado à mão: seta apontando +X, girada pela rotação do Control.
## (Classe interna não enxerga as constantes do script: usa o nome global.)
class ChevronMissao extends Control:
	var pulso := 1.0

	func _init() -> void:
		var lado := SetaMissao.MEIO_CHEVRON * 2.0
		custom_minimum_size = Vector2(lado, lado)
		size = custom_minimum_size
		pivot_offset = Vector2(SetaMissao.MEIO_CHEVRON, SetaMissao.MEIO_CHEVRON)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false

	func _draw() -> void:
		# O chevron é desenhado como duas asas triangulares (cada triângulo é um
		# polígono trivialmente válido; o contorno único se autocruzava e a
		# triangulação do canvas rejeitava).
		var metades := [
			PackedVector2Array([Vector2(14, 0), Vector2(-10, -14), Vector2(-2, 0)]),
			PackedVector2Array([Vector2(14, 0), Vector2(-2, 0), Vector2(-10, 14)]),
		]
		var centro := Vector2(SetaMissao.MEIO_CHEVRON, SetaMissao.MEIO_CHEVRON)
		var cor: Color = SetaMissao.COR
		for metade: PackedVector2Array in metades:
			var forma := PackedVector2Array()
			var sombra := PackedVector2Array()
			for p in metade:
				forma.append(centro + p)
				sombra.append(centro + p + Vector2(1, 2))
			# Sombra leve para o chevron ler sobre céu claro.
			draw_colored_polygon(sombra, Color(0, 0, 0, 0.35 * pulso))
			draw_colored_polygon(forma, Color(cor.r, cor.g, cor.b, pulso))
