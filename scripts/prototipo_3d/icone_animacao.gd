extends Control
## O ÍCONE DE UMA ANIMAÇÃO na ficha de MODELOS: um boneco de traço, de perfil (virado
## para a direita), na pose que lembra o clipe, às vezes com o objeto da ação (a vara,
## a pá, a porta, a água). Desenha na grade de 24, como o `HudIcon`; quem usa põe o
## tamanho e a escala. Todos em creme; só o do clipe que está tocando (o botão apertado) fica em
## ouro. A origem (Mixamo ou Tripo) fica na dica do botão.
##
## A pose é feita de ângulos absolutos, em graus, a partir do "para baixo": 0 aponta
## para o chão, 90 para a frente (direita), 180 para o alto e -90 para trás. Cada
## membro é [segmento de cima, segmento de baixo]: braço e antebraço, coxa e canela.
## `tronco` inclina o corpo (positivo para a frente) e `quadril` move o boneco.

const OURO := Color("e2c47f")
const CREME := Color(0.93, 0.96, 0.92)
const QUADRIL := Vector2(12, 14)
const TRONCO := 6.0
const BRACO := [3.6, 3.4]
const PERNA := [4.2, 4.0]

## Pose de cada desenho: tronco, braço da frente (bf), braço de trás (bt), perna da
## frente (pf), perna de trás (pt), quadril e o objeto ou marca da ação.
const POSES := {
	"parado": {"bf": [8, 4], "bt": [-8, -4], "pf": [5, 0], "pt": [-5, 0]},
	"andar": {"bf": [-25, -5], "bt": [30, 70], "pf": [28, 5], "pt": [-24, -50]},
	"andar_alegre": {"bf": [-40, 20], "bt": [60, 140], "pf": [30, 10], "pt": [-24, -60], "objeto": "nota"},
	"vaidoso": {"tronco": -10, "bf": [-60, -20], "bt": [40, 100], "pf": [35, 10], "pt": [-20, -40]},
	"correr": {"tronco": 18, "bf": [70, 150], "bt": [-60, 10], "pf": [60, -10], "pt": [-45, -110]},
	"escada": {"tronco": 18, "bf": [70, 150], "bt": [-60, 10], "pf": [80, 0], "pt": [-30, -70], "objeto": "escada"},
	"pular": {"quadril": Vector2(12, 11.5), "bf": [160, 170], "bt": [-160, -170], "pf": [35, -20], "pt": [-35, -50], "objeto": "chao"},
	"descer": {"quadril": Vector2(13, 11), "tronco": 10, "bf": [120, 150], "bt": [-120, -150], "pf": [40, 0], "pt": [-20, -60], "objeto": "degrau"},
	"acenar": {"bf": [140, 175], "bt": [-8, -4], "pf": [5, 0], "pt": [-5, 0], "objeto": "aceno"},
	"saudar": {"tronco": 8, "bf": [110, 150], "bt": [-8, -4], "pf": [5, 0], "pt": [-5, 0]},
	"apontar": {"bf": [92, 92], "bt": [-8, -4], "pf": [8, 0], "pt": [-8, 0]},
	"continencia": {"bf": [115, -125], "bt": [-4, 0], "pf": [2, 0], "pt": [-2, 0]},
	"curvar": {"tronco": 60, "bf": [60, 60], "bt": [55, 55], "pf": [0, 0], "pt": [-4, 0]},
	"sentado": {"quadril": Vector2(10, 15), "bf": [25, 80], "bt": [10, 60], "pf": [90, 0], "pt": [88, 0], "objeto": "banco"},
	"conversa": {"quadril": Vector2(10, 15), "bf": [40, 130], "bt": [10, 60], "pf": [90, 0], "pt": [88, 0], "objeto": "conversa"},
	"chamar": {"quadril": Vector2(10, 15), "bf": [50, 170], "bt": [10, 60], "pf": [90, 0], "pt": [88, 0], "objeto": "grito"},
	"balancar": {"quadril": Vector2(10, 15), "bf": [10, 40], "bt": [-10, 20], "pf": [90, 40], "pt": [88, -15], "objeto": "banco"},
	"rezar": {"quadril": Vector2(11, 16), "bf": [40, 160], "bt": [35, 155], "pf": [5, -90], "pt": [2, -90]},
	"ajoelhar": {"quadril": Vector2(11, 16), "bf": [10, 5], "bt": [-5, 0], "pf": [5, -90], "pt": [2, -90]},
	"levantar_do_chao": {"quadril": Vector2(11, 16), "tronco": 30, "bf": [30, 30], "bt": [-10, 0], "pf": [80, 0], "pt": [10, -90]},
	"pescar": {"bf": [70, 110], "bt": [60, 100], "pf": [5, 0], "pt": [-5, 0], "objeto": "vara"},
	"lancar_linha": {"tronco": -8, "bf": [165, 200], "bt": [150, 190], "pf": [12, 0], "pt": [-12, 0], "objeto": "vara_atras"},
	"cavar": {"tronco": 28, "bf": [55, 90], "bt": [35, 70], "pf": [12, 0], "pt": [-12, 0], "objeto": "pa"},
	"ceifar": {"tronco": 25, "bf": [60, 70], "bt": [20, 60], "pf": [12, 0], "pt": [-12, 0], "objeto": "foice"},
	"cortar": {"tronco": -5, "bf": [160, 180], "bt": [150, 175], "pf": [12, 0], "pt": [-12, 0], "objeto": "machado"},
	"capoeira": {"quadril": Vector2(11, 15), "tronco": -25, "bf": [-70, -30], "bt": [-120, -150], "pf": [115, 125], "pt": [-15, 10]},
	"soco": {"tronco": 8, "bf": [92, 92], "bt": [60, 160], "pf": [25, 0], "pt": [-25, 0], "objeto": "punho"},
	"porta": {"bf": [85, 95], "bt": [-8, -4], "pf": [10, 0], "pt": [-10, 0], "objeto": "porta"},
	"pegar": {"tronco": 70, "bf": [5, 0], "bt": [15, 5], "pf": [12, 0], "pt": [-10, 0], "objeto": "caixa_chao"},
	"carregar": {"bf": [170, 175], "bt": [-170, -175], "pf": [12, 0], "pt": [-12, 0], "objeto": "caixa_alto"},
	"puxar": {"tronco": -25, "bf": [80, 90], "bt": [70, 85], "pf": [30, 0], "pt": [-15, 0], "objeto": "corda"},
	"cansado": {"tronco": 40, "bf": [20, 0], "bt": [10, -5], "pf": [15, -5], "pt": [-10, -10], "objeto": "ofego"},
	"suor": {"bf": [130, -110], "bt": [-8, -4], "pf": [5, 0], "pt": [-5, 0], "objeto": "gota"},
	"espreguicar": {"tronco": -6, "bf": [172, 178], "bt": [-172, -178], "pf": [5, 0], "pt": [-5, 0]},
	"contar": {"bf": [35, 130], "bt": [25, 110], "pf": [5, 0], "pt": [-5, 0], "objeto": "dedos"},
	"nadar": {"quadril": Vector2(9, 12), "tronco": 85, "bf": [175, 180], "bt": [20, 40], "pf": [-80, -70], "pt": [-95, -110], "objeto": "agua"},
	"medo": {"tronco": -15, "bf": [140, 210], "bt": [120, 200], "pf": [15, 0], "pt": [-15, 0]},
	"concordar": {"bf": [8, 4], "bt": [-8, -4], "pf": [5, 0], "pt": [-5, 0], "objeto": "aceno_cabeca"},
	"bracos_cruzados": {"bf": [25, 115], "bt": [-15, 100], "pf": [8, 0], "pt": [-8, 0]},
	"olhar_ao_redor": {"bf": [8, 4], "bt": [-8, -4], "pf": [5, 0], "pt": [-5, 0], "objeto": "olhar"},
}

## Clipe (id do Mixamo ou nome-base do Tripo) → pose. Clipe sem pose fica "parado".
const DO_CLIPE := {
	"idle": "parado", "walk": "andar", "run": "correr", "run_upstairs": "escada",
	"jump": "pular", "jump_down": "descer", "sit": "sentado", "swim": "nadar",
	"wave_goodbye_02": "acenar", "waving": "acenar", "greet_01": "saudar", "salute": "continencia",
	"pointing": "apontar", "bow": "curvar", "agree": "concordar", "fold_arms": "bracos_cruzados",
	"look_around": "olhar_ao_redor", "afraid": "medo", "chop": "cortar", "dig": "cavar",
	"digging": "cavar", "harvesting": "ceifar", "lift_heavy": "carregar", "picking_up": "pegar",
	"pulling_rope": "puxar", "capoeira": "capoeira", "punching": "soco", "opening_door": "porta",
	"fishing_idle": "pescar", "fishing_cast": "lancar_linha", "praying": "rezar",
	"kneeling_idle": "ajoelhar", "getting_up": "levantar_do_chao", "sitting_idle": "sentado",
	"sitting_talking": "conversa", "sitting_yell": "chamar", "girl_bench_swing": "balancar",
	"tired_breathing_idle": "cansado", "wiping_sweat": "suor", "stretching_yawn": "espreguicar",
	"counting": "contar", "happy_walk": "andar_alegre", "strut_walking": "vaidoso",
}

var pose := "parado"
var cor := CREME


## Ícone do clipe `clipe` (`_do_mixamo` só vale para a dica, que o botão já leva).
func configurar(clipe: String, _do_mixamo: bool):
	pose = String(DO_CLIPE.get(clipe, "parado"))
	return self


static func tem_pose(clipe: String) -> bool:
	return DO_CLIPE.has(clipe)


static func _direcao(graus: float) -> Vector2:
	var radianos := deg_to_rad(graus)
	return Vector2(sin(radianos), cos(radianos))


func _membro(inicio: Vector2, angulos: Array, medidas: Array) -> Vector2:
	var meio := inicio + _direcao(float(angulos[0])) * float(medidas[0])
	var fim := meio + _direcao(float(angulos[1])) * float(medidas[1])
	draw_polyline(PackedVector2Array([inicio, meio, fim]), cor, 2.0, true)
	return fim


func _draw() -> void:
	var botao := get_parent() as BaseButton
	cor = OURO if botao != null and botao.button_pressed else CREME
	var p: Dictionary = POSES.get(pose, POSES["parado"])
	var quadril: Vector2 = p.get("quadril", QUADRIL)
	var inclinacao := float(p.get("tronco", 0))
	var ombro := quadril + _direcao(180.0 + inclinacao) * TRONCO
	var cabeca := ombro + _direcao(180.0 + inclinacao) * 3.0
	draw_line(quadril, ombro, cor, 2.3, true)
	draw_circle(cabeca, 2.6, cor)
	_membro(quadril, p.get("pt", [-5, 0]), PERNA)
	_membro(quadril, p.get("pf", [5, 0]), PERNA)
	_membro(ombro, p.get("bt", [-8, -4]), BRACO)
	var mao := _membro(ombro, p.get("bf", [8, 4]), BRACO)
	_objeto(String(p.get("objeto", "")), mao, cabeca, quadril)


## O objeto ou a marca da ação, em traço mais fino.
func _objeto(objeto: String, mao: Vector2, cabeca: Vector2, quadril: Vector2) -> void:
	var fino := Color(cor, 0.85)
	match objeto:
		"chao":
			draw_line(Vector2(7, 22.5), Vector2(17, 22.5), fino, 1.2, true)
		"degrau":
			draw_polyline(PackedVector2Array([Vector2(2, 15), Vector2(7, 15), Vector2(7, 22.5), Vector2(22, 22.5)]), fino, 1.2, true)
		"escada":
			draw_polyline(PackedVector2Array([Vector2(13, 22.5), Vector2(16, 22.5), Vector2(16, 19.5), Vector2(19, 19.5), Vector2(19, 16.5), Vector2(22, 16.5)]), fino, 1.2, true)
		"aceno":
			draw_arc(mao, 2.6, deg_to_rad(-70), deg_to_rad(-10), 6, fino, 1.1, true)
			draw_arc(mao, 4.2, deg_to_rad(-70), deg_to_rad(-10), 6, fino, 1.1, true)
		"aceno_cabeca":
			draw_arc(cabeca, 4.0, deg_to_rad(110), deg_to_rad(160), 6, fino, 1.1, true)
			draw_arc(cabeca, 4.0, deg_to_rad(20), deg_to_rad(70), 6, fino, 1.1, true)
		"olhar":
			draw_arc(cabeca, 4.0, deg_to_rad(-30), deg_to_rad(30), 6, fino, 1.1, true)
			draw_arc(cabeca, 4.0, deg_to_rad(150), deg_to_rad(210), 6, fino, 1.1, true)
		"banco":
			draw_line(Vector2(5, quadril.y + 1.2), Vector2(16, quadril.y + 1.2), fino, 1.3, true)
			draw_line(Vector2(6, quadril.y + 1.2), Vector2(6, 22.5), fino, 1.1, true)
		"conversa":
			draw_line(Vector2(5, quadril.y + 1.2), Vector2(16, quadril.y + 1.2), fino, 1.3, true)
			draw_arc(Vector2(19, 4), 2.6, 0, TAU, 10, fino, 1.0, true)
		"grito":
			draw_line(Vector2(5, quadril.y + 1.2), Vector2(16, quadril.y + 1.2), fino, 1.3, true)
			for i in 3:
				draw_line(cabeca + Vector2(3.5, -2.0 + i * 2.0), cabeca + Vector2(6.5, -3.0 + i * 3.0), fino, 1.0, true)
		"vara":
			draw_line(mao, Vector2(22, 4), fino, 1.1, true)
			draw_line(Vector2(22, 4), Vector2(22, 20), Color(fino, 0.6), 0.8, true)
			draw_arc(Vector2(20.5, 21.5), 1.6, deg_to_rad(180), deg_to_rad(360), 5, fino, 1.0, true)
		"vara_atras":
			draw_line(mao, Vector2(2, 3), fino, 1.1, true)
		"pa":
			var ponta := mao + Vector2(4.5, 7.5)
			draw_line(mao, ponta, fino, 1.2, true)
			draw_colored_polygon(PackedVector2Array([ponta + Vector2(-1.6, 0), ponta + Vector2(1.6, 0), ponta + Vector2(0.6, 2.6), ponta + Vector2(-1.0, 2.6)]), fino)
		"foice":
			draw_line(mao, mao + Vector2(3, 3), fino, 1.2, true)
			draw_arc(mao + Vector2(5, 2.5), 3.2, deg_to_rad(200), deg_to_rad(380), 8, fino, 1.2, true)
		"machado":
			var lamina := mao + Vector2(1.5, -3.5)
			draw_line(mao, lamina, fino, 1.2, true)
			draw_colored_polygon(PackedVector2Array([lamina, lamina + Vector2(3.2, -0.6), lamina + Vector2(3.2, 2.6), lamina + Vector2(0, 1.6)]), fino)
		"punho":
			draw_circle(mao, 1.3, cor)
			draw_line(mao + Vector2(2.5, -1.5), mao + Vector2(4.5, -2.5), fino, 1.0, true)
			draw_line(mao + Vector2(2.5, 1.5), mao + Vector2(4.5, 2.5), fino, 1.0, true)
		"porta":
			draw_rect(Rect2(18, 6, 4.5, 16.5), fino, false, 1.2, true)
			draw_circle(Vector2(19.3, 14.5), 0.7, fino)
		"caixa_chao":
			draw_rect(Rect2(mao.x - 1.5, 19.5, 4, 3), fino, false, 1.1, true)
		"caixa_alto":
			draw_rect(Rect2(8.5, 0.6, 7, 3.4), fino, false, 1.1, true)
		"corda":
			draw_line(mao, Vector2(23, mao.y + 1.5), fino, 1.0, true)
		"ofego":
			draw_arc(cabeca + Vector2(4.5, 1.5), 1.6, deg_to_rad(-60), deg_to_rad(60), 5, fino, 1.0, true)
			draw_arc(cabeca + Vector2(6.0, 1.5), 2.8, deg_to_rad(-60), deg_to_rad(60), 6, fino, 1.0, true)
		"gota":
			draw_colored_polygon(PackedVector2Array([cabeca + Vector2(-4.5, -1.0), cabeca + Vector2(-3.6, 1.2), cabeca + Vector2(-5.4, 1.2)]), fino)
		"dedos":
			for i in 3:
				draw_circle(Vector2(19.5, 6 + i * 2.6), 0.7, fino)
		"nota":
			draw_line(Vector2(20, 3), Vector2(20, 8), fino, 1.0, true)
			draw_circle(Vector2(19, 8.2), 1.1, fino)
			draw_line(Vector2(20, 3), Vector2(22, 4), fino, 1.0, true)
		"agua":
			for i in 2:
				var y := 17.5 + i * 3.0
				draw_polyline(PackedVector2Array([Vector2(2, y), Vector2(6, y - 1.2), Vector2(10, y), Vector2(14, y - 1.2), Vector2(18, y), Vector2(22, y - 1.2)]), Color(fino, 0.7), 1.0, true)
