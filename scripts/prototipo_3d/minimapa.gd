extends Control
## Minimapa do canto inferior esquerdo: um SubViewport (mesmo mundo do vale, sem mundo
## próprio) com câmera ortográfica de topo seguindo o jogador. Por cima, um desenho
## leve: triângulo dourado do jogador (gira com o modelo), ponto claro do Pedro e
## losango âmbar do alvo da missão (fora da vista, encosta na borda). A preferência
## "interface/minimapa" (AJUSTAR → Cenário) mostra ou esconde e é relida de tempos em
## tempos; com outra câmera ativa (mapa grande) ou o painel CONTROLES aberto no mesmo
## canto, ele se recolhe sozinho.

## REDONDO COMO BÚSSOLA, por pedido do autor: a vista era um retângulo de
## 210x150 com cantos arredondados, e em jogo de mapa grande a bússola redonda
## diz melhor "isto é direção" do que "isto é um pedaço do mapa". Quadrado
## porque círculo em moldura retangular corta mais de um lado que do outro.
const LADO := 176.0
const LARGURA := LADO
const ALTURA := LADO
const MARGEM := 14.0
## Quanto o marcador para antes do aro, para o losango não ser cortado ao meio.
const MARGEM_DO_ARO := 9.0
## Respiro entre a borda dourada da moldura e a vista do mundo.
const BORDA := 3.0
## Lado vertical da vista, em unidades do mundo (~55 u = 220 m).
const VISTA := 55.0
## A câmera ortográfica preserva o enquadramento nesta altura. A 200 u, a
## restinga atingia o corte de LOD antes mesmo de aparecer no minimapa.
## 100 u ainda ficam acima do relevo do vale e mantêm as copas na vista pequena.
const ALTURA_CAMERA := 100.0
const PREFERENCIAS := "user://preferencias_visuais.cfg"
const FUNDO := Color(0.055, 0.085, 0.075, 0.9)
const OURO := Color("b49a60")
const DOURADO := Color("d6ba78")
const CLARO := Color("f5e3b3")
const AMBAR := Color("e2a93b")

## O recorte redondo da vista, aplicado ao SubViewportContainer.
##
## `COLOR.a` em vez de `discard`: a transparência deixa o fundo da moldura
## aparecer na quina, e o `smoothstep` tira o serrado do contorno. O raio é 0.5
## em UV — o container é quadrado, então 0.5 é a borda.
const MASCARA_REDONDA := """
shader_type canvas_item;
void fragment() {
	float r = length(UV - vec2(0.5));
	COLOR.a *= 1.0 - smoothstep(0.47, 0.5, r);
}
"""

var _jogador: Node3D
var _pedro: Node3D
var _hud	# prototype_hud.gd (para recolher com o painel CONTROLES aberto)
var _viewport: SubViewport
var _camera: Camera3D
var _sobre: Control
var _alvo := Vector3.ZERO
var _tem_alvo := false
var _mostrar := true
var _suspenso := false
var _releitura := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	offset_left = MARGEM
	offset_right = MARGEM + LARGURA
	offset_top = -MARGEM - ALTURA
	offset_bottom = -MARGEM
	var moldura := Panel.new()
	moldura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = FUNDO
	estilo.border_color = OURO
	estilo.set_border_width_all(1)
	# O raio é metade do lado: num painel quadrado isso é um círculo, e assim a
	# moldura dourada vira o aro da bússola sem precisar de arte.
	estilo.set_corner_radius_all(int(LADO * 0.5))
	moldura.add_theme_stylebox_override("panel", estilo)
	add_child(moldura)
	moldura.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var quadro := SubViewportContainer.new()
	quadro.stretch = true
	quadro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(quadro)
	quadro.position = Vector2(BORDA, BORDA)
	quadro.size = Vector2(LARGURA - BORDA * 2.0, ALTURA - BORDA * 2.0)
	# A MÁSCARA REDONDA. O aro é desenho de moldura e não corta nada: quem corta
	# a vista do mundo é este shader, que apaga o que cai fora do círculo. A
	# borda é suavizada em poucos pixels para o recorte não ficar serrado.
	var recorte := ShaderMaterial.new()
	var redondo := Shader.new()
	redondo.code = MASCARA_REDONDA
	recorte.shader = redondo
	quadro.material = recorte
	_viewport = SubViewport.new()
	# Sem mundo próprio: o SubViewport enxerga o mesmo World3D do vale.
	_viewport.own_world_3d = false
	# A câmera do minimapa não pode virar o ouvido 3D do jogo.
	_viewport.audio_listener_enable_3d = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	quadro.add_child(_viewport)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = VISTA
	_camera.far = 400.0
	_camera.rotation_degrees = Vector3(-90, 0, 0)
	_viewport.add_child(_camera)
	_sobre = Control.new()
	_sobre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sobre)
	_sobre.position = Vector2(BORDA, BORDA)
	_sobre.size = Vector2(LARGURA - BORDA * 2.0, ALTURA - BORDA * 2.0)
	_sobre.draw.connect(_desenhar)
	aplicar_visibilidade()


## `hud` é opcional: com ele, o minimapa se recolhe enquanto o painel CONTROLES
## (que abre no mesmo canto) está na tela.
func configurar(jogador: Node3D, pedro: Node3D = null, hud = null) -> void:
	_jogador = jogador
	_pedro = pedro
	_hud = hud
	# De 200 u de altura o nevoeiro do vale apagaria tudo: esta câmera fica sem névoa.
	var ambiente: Environment = get_viewport().world_3d.environment
	if ambiente != null:
		_camera.environment = ambiente.duplicate() as Environment
		_camera.environment.fog_enabled = false
	_seguir()


func _process(delta: float) -> void:
	_releitura += delta
	if _releitura >= 1.0:
		# O painel AJUSTAR só grava a preferência; o minimapa a relê a cada segundo.
		_releitura = 0.0
		aplicar_visibilidade()
	if _jogador == null:
		visible = false
		return
	# Com o mapa grande (ou qualquer outra câmera) ativo, o minimapa se recolhe.
	var camera_do_jogo: bool = get_viewport().get_camera_3d() == _jogador.get("camera")
	var controles_abertos: bool = _hud != null and _hud.controls_open()
	visible = _mostrar and not _suspenso and camera_do_jogo and not controles_abertos
	# Escondido, o SubViewport para de renderizar (o vale não é desenhado duas vezes à toa).
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED
	if not visible:
		return
	_seguir()
	_alvo_do_caderno()
	_sobre.queue_redraw()


## Relê a preferência "interface/minimapa" (padrão: mostrar).
func aplicar_visibilidade() -> void:
	var preferencias := ConfigFile.new()
	preferencias.load(PREFERENCIAS)
	_mostrar = bool(preferencias.get_value("interface", "minimapa", true))


## Suspensão externa (mapa grande aberto, cenas de transição).
func set_suspenso(valor: bool) -> void:
	_suspenso = valor


## O ALVO VEM DO CADERNO, e não de quem falou por último.
##
## Antes o losango seguia o último passo ANUNCIADO: com várias cadeias abertas,
## ele apontava para quem tinha acabado de falar, e não para o que o jogador
## escolheu fazer. O painel de missões já promete a escolha — "[E] fixar" —, e
## quem guarda essa escolha é o `CadernoDoVale.atual()`, com o alvo de cada
## missão. É o que a maioria dos RPG faz: a bússola segue a missão em foco.
##
## `definir_alvo` continua existindo para quem quiser apontar algo que não é
## missão; o caderno só manda quando há missão em foco com lugar.
func _alvo_do_caderno() -> void:
	var caderno := get_node_or_null("/root/CadernoDoVale")
	if caderno == null:
		return
	var missao: Dictionary = caderno.atual()
	if missao.is_empty():
		_tem_alvo = false
		return
	var onde: Vector3 = missao.get("alvo", Vector3.ZERO)
	_tem_alvo = onde != Vector3.ZERO
	if _tem_alvo:
		_alvo = onde


## Alvo da missão do Pedro: losango âmbar no quadro.
func definir_alvo(pos: Vector3) -> void:
	_alvo = pos
	_tem_alvo = true


func limpar_alvo() -> void:
	_tem_alvo = false


func _seguir() -> void:
	# Filho direto do SubViewport: a posição já é em coordenadas do mundo.
	# Dentro de uma construção a vista fica na porta dela (ver `posicao_no_mapa`).
	_camera.position = _onde_esta_o_jogador() + Vector3(0, ALTURA_CAMERA, 0)


func _desenhar() -> void:
	if _jogador == null:
		return
	var centro: Vector2 = _sobre.size * 0.5
	# KEEP_HEIGHT: a altura do quadro cobre VISTA unidades do mundo.
	var escala: float = _sobre.size.y / VISTA
	if is_instance_valid(_pedro):
		_sobre.draw_circle(_no_quadro(_pedro.global_position, centro, escala), 3.0, CLARO)
	if _tem_alvo:
		var a := _no_quadro(_alvo, centro, escala)
		var losango := PackedVector2Array([a + Vector2(0, -6), a + Vector2(5, 0), a + Vector2(0, 6), a + Vector2(-5, 0)])
		_sobre.draw_colored_polygon(losango, AMBAR)
	# Triângulo do jogador: a frente do modelo é o +Z do nó `visual`, e a câmera de topo
	# põe o norte (-Z) para cima, então a direção na tela é (sin yaw, cos yaw).
	var direcao := Vector2(0, 1)
	var visual := _jogador.get("visual") as Node3D
	if visual != null:
		var yaw := visual.global_rotation.y
		direcao = Vector2(sin(yaw), cos(yaw))
	var pontos := PackedVector2Array([
		centro + direcao * 9.0,
		centro + direcao.rotated(2.6) * 7.0,
		centro + direcao.rotated(-2.6) * 7.0,
	])
	_sobre.draw_colored_polygon(pontos, DOURADO)


## Ponto do mundo no quadro, centrado no jogador. Fora da vista, ENCOSTA NO ARO —
## o marcador ainda dá a direção, que é o serviço da bússola.
##
## O limite é redondo, e não o retângulo de antes: com a máscara circular, ponto
## preso num canto cai justamente no pedaço que o shader apaga, e o jogador
## perderia o marcador exatamente quando mais precisa dele — longe do alvo.
func _no_quadro(pos: Vector3, centro: Vector2, escala: float) -> Vector2:
	var aqui := _onde_esta_o_jogador()
	var fora := Vector2(pos.x - aqui.x,
		pos.z - aqui.z) * escala
	var aro: float = minf(_sobre.size.x, _sobre.size.y) * 0.5 - MARGEM_DO_ARO
	if fora.length() > aro:
		fora = fora.normalized() * aro
	return centro + fora


## Onde o jogador está NO VALE: dentro de uma construção, a porta dela.
func _onde_esta_o_jogador() -> Vector3:
	if _jogador.has_method("posicao_no_mapa"):
		return _jogador.posicao_no_mapa()
	return _jogador.global_position
