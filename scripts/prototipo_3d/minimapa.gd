extends Control
## Minimapa do canto inferior esquerdo: uma FOTO do vale visto de cima
## (assets/prototipo_3d/identidade/minimapa/mapa_vale.png, tirada por
## tools/prototipo_3d/capturar_minimapa.gd), recortada em volta do jogador por um
## shader. Antes era um SubViewport no mesmo mundo do vale, com câmera ortográfica:
## o vale era desenhado DUAS vezes por quadro (7 a 12 ms de GPU) só para encher um
## círculo de 170 px. Agora o quadro só desliza o UV da textura. Por cima, um desenho
## leve: triângulo dourado do jogador (gira com o modelo), ponto claro do Pedro e
## losango âmbar do alvo da missão (fora da vista, encosta na borda). A preferência
## "interface/minimapa" (AJUSTAR → Cenário) mostra ou esconde e é relida de tempos em
## tempos; com outra câmera ativa (mapa grande) ou o painel CONTROLES aberto no mesmo
## canto, ele se recolhe sozinho. Sem a foto (nunca capturada), ele some sem erro.

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
## A foto e o retângulo do mundo que ela cobre (origem_x, origem_z, largura, altura
## em unidades). Os dois saem juntos da ferramenta de captura.
const MAPA := "res://assets/prototipo_3d/identidade/minimapa/mapa_vale.png"
const MAPA_DADOS := "res://assets/prototipo_3d/identidade/minimapa/mapa_vale.json"
const PREFERENCIAS := "user://preferencias_visuais.cfg"
const FUNDO := Color(0.055, 0.085, 0.075, 0.9)
const OURO := Color("b49a60")
const DOURADO := Color("d6ba78")
const CLARO := Color("f5e3b3")
const AMBAR := Color("e2a93b")

## A VISTA REDONDA: amostra a foto em volta de `centro_uv` e apaga o que cai fora do
## círculo.
##
## `COLOR.a` em vez de `discard`: a transparência deixa o fundo da moldura
## aparecer na quina, e o `smoothstep` tira o serrado do contorno. O raio é 0.5
## em UV — o quadro é quadrado, então 0.5 é a borda. Fora da foto, a cor `fundo`
## (o mundo acaba ali). A foto é lida sempre e a mistura é por `step`, porque
## amostrar dentro de um `if` por pixel é pedir derivada indefinida.
const VISTA_REDONDA := """
shader_type canvas_item;
uniform sampler2D mapa : source_color, filter_linear, repeat_disable;
uniform vec2 centro_uv = vec2(0.5);
uniform vec2 vista_uv = vec2(0.1);
uniform vec4 fundo = vec4(0.055, 0.085, 0.075, 0.9);
// O MAPA DOIDO (loucura_do_mapa.gd): `rotacao` gira a vista (rad) em torno do centro, com o lado da
// foto em unidades (`tamanho`) para a vista não entortar. Zero é a vista de sempre, sem conta nenhuma.
uniform float rotacao = 0.0;
uniform vec2 tamanho = vec2(1.0);
void fragment() {
	vec2 d = (UV - vec2(0.5)) * vista_uv;
	vec2 m = d * tamanho;
	m = vec2(cos(rotacao) * m.x - sin(rotacao) * m.y, sin(rotacao) * m.x + cos(rotacao) * m.y);
	vec2 p = centro_uv + mix(d, m / tamanho, step(0.00001, abs(rotacao)));
	vec3 foto = texture(mapa, clamp(p, vec2(0.0), vec2(1.0))).rgb;
	vec2 dentro2 = step(vec2(0.0), p) * step(p, vec2(1.0));
	float dentro = dentro2.x * dentro2.y;
	vec4 cor = mix(fundo, vec4(foto, 1.0), dentro);
	float r = length(UV - vec2(0.5));
	cor.a *= 1.0 - smoothstep(0.47, 0.5, r);
	COLOR = cor;
}
"""

var _jogador: Node3D
var _pedro: Node3D
var _hud	# prototype_hud.gd (para recolher com o painel CONTROLES aberto)
var _vista: ColorRect
var _material: ShaderMaterial
var _sobre: Control
## Retângulo do mundo coberto pela foto: position é a origem (x, z).
var _retangulo := Rect2()
var _sem_mapa := true
var _alvo := Vector3.ZERO
var _tem_alvo := false
var _mostrar := true
var _suspenso := false
var _releitura := 0.0
var _loucura_no: Node


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("obstaculos_do_hud")
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
	_vista = ColorRect.new()
	_vista.name = "Vista"
	_vista.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vista)
	_vista.position = Vector2(BORDA, BORDA)
	_vista.size = Vector2(LARGURA - BORDA * 2.0, ALTURA - BORDA * 2.0)
	# A MÁSCARA REDONDA. O aro é desenho de moldura e não corta nada: quem corta
	# a vista do mundo é este shader, que apaga o que cai fora do círculo.
	_material = ShaderMaterial.new()
	var redondo := Shader.new()
	redondo.code = VISTA_REDONDA
	_material.shader = redondo
	_material.set_shader_parameter("fundo", FUNDO)
	_vista.material = _material
	_carregar_mapa()
	_sobre = Control.new()
	_sobre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sobre)
	_sobre.position = Vector2(BORDA, BORDA)
	_sobre.size = Vector2(LARGURA - BORDA * 2.0, ALTURA - BORDA * 2.0)
	_sobre.draw.connect(_desenhar)
	Tela.vincular_componente(self, "minimapa", Vector2(0, 1))
	aplicar_visibilidade()


## `hud` é opcional: com ele, o minimapa se recolhe enquanto o painel CONTROLES
## (que abre no mesmo canto) está na tela.
func configurar(jogador: Node3D, pedro: Node3D = null, hud = null) -> void:
	_jogador = jogador
	_pedro = pedro
	_hud = hud
	_seguir()


func _process(delta: float) -> void:
	_releitura += delta
	if _releitura >= 1.0:
		# O painel AJUSTAR só grava a preferência; o minimapa a relê a cada segundo.
		_releitura = 0.0
		aplicar_visibilidade()
	if _jogador == null or _sem_mapa:
		visible = false
		return
	# Com o mapa grande (ou qualquer outra câmera) ativo, o minimapa se recolhe.
	var camera_do_jogo: bool = get_viewport().get_camera_3d() == _jogador.get("camera")
	var controles_abertos: bool = _hud != null and _hud.controls_open()
	visible = _mostrar and not _suspenso and camera_do_jogo and not controles_abertos
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


## Desliza a vista: o centro da textura é o jogador, em fração da foto. É só isto
## que muda por quadro; a foto fica parada na placa de vídeo.
func _seguir() -> void:
	if _sem_mapa or _jogador == null:
		return
	var p := _jogador.global_position
	var centro_uv := centro_da_vista(p)
	var louca := _loucura()
	if louca != null:
		# O MAPA DOIDO: a foto escorrega para um lugar errado e gira. Sem loucura os dois são zero.
		var deriva: Vector2 = louca.deriva_do_mapa()
		centro_uv += Vector2(deriva.x / _retangulo.size.x, deriva.y / _retangulo.size.y)
		_material.set_shader_parameter("rotacao", louca.rotacao_do_mapa())
	_material.set_shader_parameter("centro_uv", centro_uv)


## O nó da loucura do mapa (`loucura_do_mapa.gd`), achado pelo grupo; null sem ele (cena sem sustos).
func _loucura() -> Node:
	if not is_instance_valid(_loucura_no):
		_loucura_no = get_tree().get_first_node_in_group(&"loucura_do_mapa") if is_inside_tree() else null
	return _loucura_no


## O ponto do mundo na foto, em fração dela (0..1 em x e em y; o topo é o -Z).
func centro_da_vista(p: Vector3) -> Vector2:
	return Vector2((p.x - _retangulo.position.x) / _retangulo.size.x,
		(p.z - _retangulo.position.y) / _retangulo.size.y)


## A foto e o seu retângulo. A foto vem do recurso importado; se o editor ainda não
## importou (captura recém-feita), cai para o PNG cru. Sem foto ou sem o JSON, o
## minimapa fica escondido: uma bússola sem mapa seria só um círculo vazio.
func _carregar_mapa() -> void:
	_sem_mapa = true
	if not FileAccess.file_exists(MAPA_DADOS):
		return
	var dados = JSON.parse_string(FileAccess.get_file_as_string(MAPA_DADOS))
	if not (dados is Dictionary) or float(dados.get("largura", 0.0)) <= 0.0 or float(dados.get("altura", 0.0)) <= 0.0:
		return
	var textura: Texture2D = null
	if _importada():
		textura = load(MAPA) as Texture2D
	if textura == null and FileAccess.file_exists(MAPA):
		var imagem := Image.load_from_file(ProjectSettings.globalize_path(MAPA))
		if imagem != null and not imagem.is_empty():
			textura = ImageTexture.create_from_image(imagem)
	if textura == null:
		return
	_retangulo = Rect2(float(dados.get("origem_x", 0.0)), float(dados.get("origem_z", 0.0)),
		float(dados["largura"]), float(dados["altura"]))
	_material.set_shader_parameter("mapa", textura)
	# A vista é quadrada e cobre VISTA unidades nos dois lados.
	_material.set_shader_parameter("vista_uv", Vector2(VISTA / _retangulo.size.x, VISTA / _retangulo.size.y))
	_material.set_shader_parameter("tamanho", _retangulo.size)
	_sem_mapa = false


## Já existe a textura importada? No jogo exportado sempre (o pacote só leva ela); no
## editor, a foto recém-capturada só é importada quando a janela do editor ganha
## foco, e carregar antes disso só enche o log de erro.
func _importada() -> bool:
	if OS.has_feature("template"):
		return true
	var importacao := ConfigFile.new()
	if importacao.load(MAPA + ".import") != OK:
		return ResourceLoader.exists(MAPA)
	var destino := String(importacao.get_value("remap", "path", ""))
	return destino != "" and FileAccess.file_exists(destino)


func _desenhar() -> void:
	if _jogador == null:
		return
	var centro: Vector2 = _sobre.size * 0.5
	# A altura do quadro cobre VISTA unidades do mundo.
	var escala: float = _sobre.size.y / VISTA
	var louca := _loucura()
	# O MAPA DOIDO: com a loucura pegada, o Pedro some da bússola (ele não está onde ela diz).
	if is_instance_valid(_pedro) and not (louca != null and louca.pegou_nos_nomes()):
		_sobre.draw_circle(_no_quadro(_pedro.global_position, centro, escala), 3.0, CLARO)
	if _tem_alvo:
		var a := _no_quadro(_alvo, centro, escala)
		var losango := PackedVector2Array([a + Vector2(0, -6), a + Vector2(5, 0), a + Vector2(0, 6), a + Vector2(-5, 0)])
		_sobre.draw_colored_polygon(losango, AMBAR)
	# Triângulo do jogador: a frente do modelo é o +Z do nó `visual`, e o topo da foto
	# é o norte (-Z), então a direção na tela é (sin yaw, cos yaw).
	var direcao := Vector2(0, 1)
	var visual := _jogador.get("visual") as Node3D
	if visual != null:
		var yaw := visual.global_rotation.y
		direcao = Vector2(sin(yaw), cos(yaw))
	# E o triângulo do jogador aponta para o lado errado (zero fora da loucura).
	if louca != null and louca.erro_da_seta() != 0.0:
		direcao = direcao.rotated(louca.erro_da_seta())
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
	var fora := Vector2(pos.x - _jogador.global_position.x,
		pos.z - _jogador.global_position.z) * escala
	# O MAPA DOIDO: o que a bússola mostra pula de lugar pelo aro (zero fora da loucura).
	var louca := _loucura()
	if louca != null and louca.erro_da_seta() != 0.0:
		fora = fora.rotated(louca.erro_da_seta())
	var aro: float = minf(_sobre.size.x, _sobre.size.y) * 0.5 - MARGEM_DO_ARO
	if fora.length() > aro:
		fora = fora.normalized() * aro
	return centro + fora
