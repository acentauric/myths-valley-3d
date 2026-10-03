extends Node3D
## O INTERIOR DA IGREJA DO BOM JESUS — o primeiro cômodo do vale (#26).
##
## "Vamos começar a criar os ambientes internos das construções também. Comece
## pela igreja." Uma capela de arraial do Recôncavo de 1887: nave caiada com a
## barra de azulejo azul, chão de lajota, forro de tábua com as vigas à mostra,
## três janelas de cada lado, o presbitério dois palmos acima da nave, o altar
## de alvenaria com a toalha e o frontal vermelho, e o retábulo dourado com a
## cruz no nicho. Bancos em duas colunas com o corredor no meio, a pia de água
## benta na entrada, os ex-votos na parede da esquerda.
##
##
## O QUE É PEÇA E O QUE É ARQUITETURA
##
## Os MÓVEIS saem do `CatalogoAssets`, no estilo escolhido, como o resto do
## vale: o banco, o candeeiro, o cruzeiro (em tamanho de altar) e o pote são
## GLBs do Tripo que já existiam, e no procedural são os construtores do
## `FloraReconcavo`. Nenhuma peça nova foi gerada: gerar gasta crédito, e o lote
## dos móveis de interior (#26) pede o custo aprovado antes.
##
## A ARQUITETURA — parede, chão, forro, degrau, altar de alvenaria, retábulo —
## é desta classe, em código, como o terreno e as ruas: é o cômodo, e não uma
## peça que se põe nele. O que for virar modelo do Tripo depois (o retábulo e o
## altar são os candidatos) troca de lado sem mudar quem chama.
##
##
## A MEDIDA
##
## Em unidades do vale (o corpo do jogador mede 1,78). A origem é o meio da
## soleira, por dentro, no chão da nave; a nave corre para -Z, até o altar.

const CatalogoAssets = preload("res://scripts/prototipo_3d/catalogo_assets.gd")

## Largura e comprimento por dentro, e o pé-direito.
const LARGURA := 8.0
const COMPRIMENTO := 17.0
const PE_DIREITO := 6.6
const PAREDE := 0.4
## O presbitério: fundo, e quanto ele sobe sobre a nave (três degraus).
const FUNDO_DO_PRESBITERIO := 4.2
const ALTURA_DO_PRESBITERIO := 0.45
## Onde o jogador aparece ao entrar, e a que distância da porta ele pode sair.
const CHEGADA := Vector3(0.0, 0.05, -1.7)
const PORTA := Vector3(0.0, 1.2, -0.3)
const ALCANCE_DA_PORTA := 2.4

const CAL := Color("efe8d8")
const AZULEJO := Color("2f5d93")
const MADEIRA := Color("5b3a22")
const MADEIRA_CLARA := Color("8a5f3a")
const OURO := Color("c9a14a")
const VERMELHO := Color("8e2a24")
const PEDRA := Color("cfc6b2")

## As velas do altar, para tremerem (ver `_process`).
var _velas: Array[OmniLight3D] = []
var _janelas: Array[Dictionary] = []
var _relogio := 0.0
## Quantas caixas já foram postas, para o nome de cada uma ser único.
var _pecas := 0


func _ready() -> void:
	_montar_casca()
	_montar_presbiterio()
	_montar_retabulo()
	_montar_janelas()
	_montar_moveis()
	_montar_luz()
	_acompanhar_o_dia()


## Onde o jogador entra e de onde sai, no mundo.
func chegada() -> Vector3:
	return to_global(CHEGADA)


func porta() -> Vector3:
	return to_global(PORTA)


func perto_da_porta(ponto: Vector3) -> bool:
	var na_sala := to_local(ponto)
	return Vector2(na_sala.x - PORTA.x, na_sala.z - PORTA.z).length() <= ALCANCE_DA_PORTA


# --- a casca: chão, paredes, forro --------------------------------------------

func _montar_casca() -> void:
	var meio_z := -COMPRIMENTO * 0.5
	# O chão da nave, de lajota; o do presbitério vem com ele, de tábua.
	_caixa(Vector3(LARGURA, 0.3, COMPRIMENTO - FUNDO_DO_PRESBITERIO),
		Vector3(0, -0.15, -(COMPRIMENTO - FUNDO_DO_PRESBITERIO) * 0.5), _lajota(), true, "Chao")
	# As quatro paredes, com a barra de azulejo por dentro.
	var lado_x := LARGURA * 0.5 + PAREDE * 0.5
	for lado in [-1.0, 1.0]:
		_caixa(Vector3(PAREDE, PE_DIREITO, COMPRIMENTO + PAREDE * 2.0),
			Vector3(lado * lado_x, PE_DIREITO * 0.5, meio_z), _cal(), true, "Parede")
		_caixa(Vector3(0.04, 1.3, COMPRIMENTO), Vector3(lado * (LARGURA * 0.5 - 0.02), 0.65, meio_z),
			_azulejo(Vector2(COMPRIMENTO, 1.3)), false, "Azulejo")
		_caixa(Vector3(0.08, 0.1, COMPRIMENTO), Vector3(lado * (LARGURA * 0.5 - 0.04), 1.32, meio_z),
			_cor(MADEIRA), false, "Friso")
	# Os fundos (atrás do retábulo) e a fachada, com a porta de duas folhas.
	_caixa(Vector3(LARGURA, PE_DIREITO, PAREDE), Vector3(0, PE_DIREITO * 0.5, -COMPRIMENTO - PAREDE * 0.5), _cal(), true, "Fundos")
	_caixa(Vector3(LARGURA, PE_DIREITO, PAREDE), Vector3(0, PE_DIREITO * 0.5, PAREDE * 0.5), _cal(), true, "Fachada")
	for lado in [-1.0, 1.0]:
		_caixa(Vector3(LARGURA * 0.5 - 1.2, 1.3, 0.04), Vector3(lado * (LARGURA * 0.25 + 0.6), 0.65, -0.02),
			_azulejo(Vector2(LARGURA * 0.5 - 1.2, 1.3)), false, "Azulejo")
	_caixa(Vector3(2.4, 3.6, 0.1), Vector3(0, 1.8, -0.05), _cor(MADEIRA), false, "Porta")
	_caixa(Vector3(0.06, 3.5, 0.12), Vector3(0, 1.8, -0.1), _cor(Color("3a2416")), false, "Porta")
	_caixa(Vector3(2.8, 0.25, 0.2), Vector3(0, 3.72, -0.1), _cor(PEDRA), false, "Verga")
	for lado in [-1.0, 1.0]:
		var argola := MeshInstance3D.new()
		var anel := TorusMesh.new()
		anel.inner_radius = 0.05
		anel.outer_radius = 0.08
		argola.mesh = anel
		argola.material_override = _metal()
		argola.rotation_degrees = Vector3(90, 0, 0)
		argola.position = Vector3(lado * 0.22, 1.5, -0.12)
		add_child(argola)
	# O forro de tábua, e as vigas por baixo dele, de lado a lado.
	_caixa(Vector3(LARGURA + PAREDE * 2.0, 0.2, COMPRIMENTO + PAREDE * 2.0),
		Vector3(0, PE_DIREITO + 0.1, meio_z), _tabua(Vector2(LARGURA, COMPRIMENTO)), true, "Forro")
	var viga := 1.0
	while viga < COMPRIMENTO:
		_caixa(Vector3(LARGURA, 0.24, 0.22), Vector3(0, PE_DIREITO - 0.12, -viga), _cor(MADEIRA), false, "Viga")
		viga += 2.1
	for lado in [-1.0, 1.0]:
		_caixa(Vector3(0.22, 0.24, COMPRIMENTO), Vector3(lado * (LARGURA * 0.5 - 0.11), PE_DIREITO - 0.12, meio_z),
			_cor(MADEIRA), false, "Cimalha")


# --- o presbitério e o altar --------------------------------------------------

func _montar_presbiterio() -> void:
	var frente := -COMPRIMENTO + FUNDO_DO_PRESBITERIO
	var meio := -COMPRIMENTO + FUNDO_DO_PRESBITERIO * 0.5
	# O estrado de tábua, dois palmos acima da nave.
	_caixa(Vector3(LARGURA, ALTURA_DO_PRESBITERIO, FUNDO_DO_PRESBITERIO),
		Vector3(0, ALTURA_DO_PRESBITERIO * 0.5, meio), _tabua(Vector2(LARGURA, FUNDO_DO_PRESBITERIO)), true, "Presbiterio")
	# Três degraus de pedra no meio, e uma rampa invisível por baixo deles: o
	# corpo do jogador não sobe degrau, mas sobe rampa de vinte e poucos graus.
	for i in 3:
		var altura := ALTURA_DO_PRESBITERIO * float(3 - i) / 3.0
		_caixa(Vector3(3.6, altura, 0.32), Vector3(0, altura * 0.5, frente + 0.16 + i * 0.32), _cor(PEDRA), false, "Degrau")
	var rampa := StaticBody3D.new()
	rampa.name = "RampaDosDegraus"
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	var comprimento_da_rampa := 1.15
	caixa.size = Vector3(3.6, 0.1, sqrt(comprimento_da_rampa * comprimento_da_rampa + ALTURA_DO_PRESBITERIO * ALTURA_DO_PRESBITERIO))
	forma.shape = caixa
	rampa.add_child(forma)
	rampa.position = Vector3(0, ALTURA_DO_PRESBITERIO * 0.5 - 0.04, frente + comprimento_da_rampa * 0.5)
	rampa.rotation.x = -atan2(ALTURA_DO_PRESBITERIO, comprimento_da_rampa)
	add_child(rampa)
	# A grade de comunhão, de madeira, com a passagem no meio.
	for lado in [-1.0, 1.0]:
		_caixa(Vector3(2.0, 0.08, 0.12), Vector3(lado * 2.9, ALTURA_DO_PRESBITERIO + 0.9, frente - 0.1), _cor(MADEIRA_CLARA), false, "Grade")
		var x: float = lado * 2.0
		while absf(x) <= 3.9:
			_caixa(Vector3(0.06, 0.9, 0.06), Vector3(x, ALTURA_DO_PRESBITERIO + 0.45, frente - 0.1), _cor(MADEIRA_CLARA), false, "Balaustre")
			x += lado * 0.3
		_caixa(Vector3(2.0, 0.95, 0.14), Vector3(lado * 2.9, ALTURA_DO_PRESBITERIO + 0.47, frente - 0.1), null, true, "GradeColisao")
	# O altar de alvenaria, com a toalha branca e o frontal vermelho bordado.
	var altar_z := -COMPRIMENTO + 1.5
	var chao := ALTURA_DO_PRESBITERIO
	_caixa(Vector3(2.6, 0.95, 1.0), Vector3(0, chao + 0.475, altar_z), _cal(), true, "Altar")
	_caixa(Vector3(2.75, 0.05, 1.12), Vector3(0, chao + 0.975, altar_z), _cor(Color("f6f2e8")), false, "Toalha")
	_caixa(Vector3(2.75, 0.32, 0.02), Vector3(0, chao + 0.82, altar_z + 0.57), _cor(Color("f6f2e8")), false, "Toalha")
	_caixa(Vector3(2.2, 0.62, 0.03), Vector3(0, chao + 0.36, altar_z + 0.515), _cor(VERMELHO), false, "Frontal")
	_caixa(Vector3(2.3, 0.05, 0.035), Vector3(0, chao + 0.68, altar_z + 0.52), _ouro(), false, "Galao")
	_caixa(Vector3(2.3, 0.05, 0.035), Vector3(0, chao + 0.05, altar_z + 0.52), _ouro(), false, "Galao")
	_caixa(Vector3(0.08, 0.36, 0.035), Vector3(0, chao + 0.36, altar_z + 0.53), _ouro(), false, "CruzBordada")
	_caixa(Vector3(0.26, 0.07, 0.035), Vector3(0, chao + 0.42, altar_z + 0.53), _ouro(), false, "CruzBordada")


func _montar_retabulo() -> void:
	var fundo := -COMPRIMENTO + 0.06
	var chao := ALTURA_DO_PRESBITERIO
	# O painel de madeira escura, a moldura dourada e o nicho azul no meio.
	_caixa(Vector3(5.0, 5.2, 0.12), Vector3(0, chao + 2.6, fundo), _cor(Color("4a2d1a")), false, "Retabulo")
	_caixa(Vector3(1.9, 3.3, 0.06), Vector3(0, chao + 2.75, fundo + 0.08), _cor(Color("1f3557")), false, "Nicho")
	for borda in [
		[Vector3(2.1, 0.14, 0.1), Vector3(0, chao + 4.45, fundo + 0.1)],
		[Vector3(2.1, 0.14, 0.1), Vector3(0, chao + 1.08, fundo + 0.1)],
		[Vector3(0.14, 3.5, 0.1), Vector3(-1.02, chao + 2.76, fundo + 0.1)],
		[Vector3(0.14, 3.5, 0.1), Vector3(1.02, chao + 2.76, fundo + 0.1)],
		[Vector3(5.2, 0.22, 0.2), Vector3(0, chao + 5.15, fundo + 0.08)],
		[Vector3(5.2, 0.3, 0.24), Vector3(0, chao + 0.15, fundo + 0.1)],
	]:
		_caixa(borda[0], borda[1], _ouro(), false, "Moldura")
	# As quatro colunas torsas do barroco, aqui lisas e douradas.
	for x in [-2.2, -1.5, 1.5, 2.2]:
		var coluna := MeshInstance3D.new()
		var cilindro := CylinderMesh.new()
		cilindro.top_radius = 0.13
		cilindro.bottom_radius = 0.15
		cilindro.height = 4.4
		coluna.mesh = cilindro
		coluna.material_override = _ouro()
		coluna.position = Vector3(x, chao + 2.6, fundo + 0.22)
		add_child(coluna)
	# A cruz do nicho: o cruzeiro do adro em tamanho de altar.
	_peca("cruzeiro", Vector3(0, chao + 1.15, fundo + 0.18), 0.0, 0.42)
	# Os dois lampadários do santíssimo, nas pontas do altar.
	for x in [-1.05, 1.05]:
		var castical := _peca("candeeiro", Vector3(x, chao + 1.0, -COMPRIMENTO + 1.5), 0.0, 1.0)
		var vela := OmniLight3D.new()
		vela.name = "Vela_%d" % _velas.size()
		vela.light_color = Color(1.0, 0.72, 0.42)
		vela.light_energy = 1.4
		vela.omni_range = 6.5
		vela.position = Vector3(x, chao + 1.55, -COMPRIMENTO + 1.6)
		add_child(vela)
		_velas.append(vela)
		if castical == null:
			_caixa(Vector3(0.06, 0.3, 0.06), Vector3(x, chao + 1.15, -COMPRIMENTO + 1.5), _cor(Color("f3ecd8")), false, "Vela")


# --- as janelas ---------------------------------------------------------------

## Três de cada lado, altas, com o vidro que acende de dia e escurece à noite
## e um facho de luz entrando enviesado. O vidro não é vidro: é a luz do dia,
## e de noite o azul-escuro de fora.
func _montar_janelas() -> void:
	for z in [-3.6, -7.4, -11.2]:
		for lado in [-1.0, 1.0]:
			var x: float = lado * (LARGURA * 0.5 - 0.03)
			_caixa(Vector3(0.1, 2.5, 1.3), Vector3(x, 3.75, z), _cor(MADEIRA), false, "Janela")
			var vidro := MeshInstance3D.new()
			var placa := QuadMesh.new()
			placa.size = Vector2(1.1, 2.3)
			vidro.mesh = placa
			var luz_do_vidro := StandardMaterial3D.new()
			luz_do_vidro.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			vidro.material_override = luz_do_vidro
			vidro.position = Vector3(x - lado * 0.06, 3.75, z)
			vidro.rotation.y = -lado * PI * 0.5
			add_child(vidro)
			for travessa in [Vector3(0.12, 0.06, 1.1), Vector3(0.12, 2.3, 0.06)]:
				_caixa(travessa, Vector3(x - lado * 0.08, 3.75, z), _cor(MADEIRA), false, "Caixilho")
			var facho := SpotLight3D.new()
			facho.name = "LuzDaJanela"
			facho.light_color = Color(1.0, 0.94, 0.82)
			facho.spot_range = 10.0
			facho.spot_angle = 38.0
			facho.spot_attenuation = 0.8
			add_child(facho)
			facho.look_at_from_position(Vector3(x - lado * 0.3, 4.4, z),
				Vector3(x - lado * 3.4, 0.0, z - 1.0), Vector3.UP)
			_janelas.append({"vidro": luz_do_vidro, "luz": facho})


# --- os móveis ----------------------------------------------------------------

func _montar_moveis() -> void:
	# Os bancos, em duas colunas com o corredor no meio, de frente para o altar.
	var fila := -3.4
	while fila >= -COMPRIMENTO + FUNDO_DO_PRESBITERIO + 1.4:
		for lado in [-1.0, 1.0]:
			var onde := Vector3(lado * 2.15, 0.0, fila)
			_peca("banco", onde, PI, 1.0)
			_caixa(Vector3(2.3, 0.9, 0.75), onde + Vector3(0, 0.45, 0), null, true, "BancoColisao")
		fila -= 1.65
	# A pia de água benta, à direita de quem entra.
	_peca("pote", Vector3(2.9, 0.0, -0.9), 0.0, 0.62)
	# Os ex-votos na parede da esquerda: quadrinhos de quem foi atendido.
	var cores := [Color("d9c39a"), Color("b9d0c4"), Color("e2b8a6"), Color("c7c1df"), Color("e8d79f"), Color("bfcfae")]
	for i in cores.size():
		var x := -LARGURA * 0.5 + 0.06
		var z := -1.4 - float(i % 3) * 0.55
		var y := 1.75 + float(i / 3) * 0.55
		_caixa(Vector3(0.04, 0.42, 0.36), Vector3(x, y, z), _cor(MADEIRA), false, "ExVoto")
		_caixa(Vector3(0.045, 0.34, 0.28), Vector3(x + 0.01, y, z), _cor(cores[i]), false, "ExVoto")


## Uma peça do catálogo no estilo do vale: o GLB do Tripo, ou o construtor do
## `FloraReconcavo`. Devolve null quando nenhum dos dois existe.
func _peca(chave: String, onde: Vector3, giro: float, tamanho: float) -> Node3D:
	if Estilo.tripo():
		var modelo := CatalogoAssets.instanciar(chave, self, onde, tamanho, giro)
		if modelo != null:
			return modelo
	var peca: Node3D = null
	match chave:
		"banco": peca = FloraReconcavo.banco_praca()
		"candeeiro": peca = FloraReconcavo.candeeiro()
		"cruzeiro": peca = FloraReconcavo.cruzeiro()
		"pote": peca = FloraReconcavo.pote_agua()
	if peca == null:
		return null
	peca.position = onde
	peca.rotation.y = giro
	peca.scale = Vector3.ONE * tamanho
	add_child(peca)
	return peca


# --- a luz --------------------------------------------------------------------

## LUZ DE DENTRO. O céu do vale ilumina tudo por igual, e sem isto as paredes
## de dentro sairiam claras como as de fora, mesmo de porta fechada: a sonda de
## reflexo troca a luz ambiente do céu pela da sala dentro da caixa dela. Ao
## meio dele, uma luz fraca de lampião pendurado, para a nave não ficar no
## breu à noite quando as janelas apagam.
func _montar_luz() -> void:
	var sonda := ReflectionProbe.new()
	sonda.name = "LuzDeDentro"
	sonda.size = Vector3(LARGURA + PAREDE * 2.0, PE_DIREITO + 0.6, COMPRIMENTO + PAREDE * 2.0)
	sonda.position = Vector3(0, PE_DIREITO * 0.5, -COMPRIMENTO * 0.5)
	sonda.interior = true
	sonda.box_projection = true
	sonda.ambient_mode = ReflectionProbe.AMBIENT_COLOR
	sonda.ambient_color = Color(0.62, 0.52, 0.42)
	sonda.ambient_color_energy = 0.55
	sonda.update_mode = ReflectionProbe.UPDATE_ONCE
	add_child(sonda)
	var lampiao := OmniLight3D.new()
	lampiao.name = "Lampiao"
	lampiao.light_color = Color(1.0, 0.78, 0.5)
	lampiao.light_energy = 0.8
	lampiao.omni_range = 14.0
	lampiao.position = Vector3(0, PE_DIREITO - 1.4, -COMPRIMENTO * 0.45)
	add_child(lampiao)


func _process(delta: float) -> void:
	_relogio += delta
	# A chama mexe: duas senoides de períodos primos entre si, para não repetir.
	for i in _velas.size():
		_velas[i].light_energy = 1.35 + 0.12 * sin(_relogio * 7.3 + i * 1.7) + 0.08 * sin(_relogio * 13.1 + i)


## As janelas acompanham o dia: claras de manhã à tarde, douradas no fim do
## dia, azul-escuras de noite — e o facho entra só com sol.
func _acompanhar_o_dia(_hora: float = 0.0) -> void:
	var luz := Dia.luz_do_dia()
	var cor_de_dia := Color(1.0, 0.95, 0.84).lerp(Color(1.0, 0.72, 0.42), 1.0 - smoothstep(0.55, 1.0, luz))
	var cor := Color(0.06, 0.08, 0.16).lerp(cor_de_dia, luz)
	for janela in _janelas:
		(janela["vidro"] as StandardMaterial3D).albedo_color = cor
		(janela["luz"] as SpotLight3D).light_energy = 3.2 * luz
		(janela["luz"] as SpotLight3D).visible = luz > 0.02
	if not Dia.hora_mudou.is_connected(_acompanhar_o_dia):
		Dia.hora_mudou.connect(_acompanhar_o_dia)


# --- materiais e caixas -------------------------------------------------------

## Uma caixa: malha com o material, e corpo de colisão quando `solida`. Sem
## material, só a colisão (a grade de comunhão, os bancos).
func _caixa(tamanho: Vector3, onde: Vector3, material: Material, solida: bool, nome: String) -> Node3D:
	var raiz := Node3D.new()
	# Nome numerado: irmãos de mesmo nome o Godot renomeia para "@Node3D@57", e
	# quem procura "BancoColisao_*" não os acharia.
	_pecas += 1
	raiz.name = "%s_%d" % [nome, _pecas]
	raiz.position = onde
	add_child(raiz)
	if material != null:
		var malha := MeshInstance3D.new()
		var caixa := BoxMesh.new()
		caixa.size = tamanho
		malha.mesh = caixa
		malha.material_override = material
		raiz.add_child(malha)
	if solida:
		var corpo := StaticBody3D.new()
		var forma := CollisionShape3D.new()
		var formato := BoxShape3D.new()
		formato.size = tamanho
		forma.shape = formato
		corpo.add_child(forma)
		raiz.add_child(corpo)
	return raiz


func _cor(cor: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = cor
	material.roughness = 0.85
	return material


func _metal() -> StandardMaterial3D:
	var material := _cor(Color("2b2622"))
	material.metallic = 0.7
	material.roughness = 0.45
	return material


func _ouro() -> StandardMaterial3D:
	var material := _cor(OURO)
	material.metallic = 0.85
	material.roughness = 0.32
	return material


## A cal: branco quebrado, com a mancha suave de demão de pincel.
func _cal() -> ShaderMaterial:
	return _shader("""
shader_type spatial;
uniform vec3 cor : source_color;
float ruido(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float suave(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(ruido(i), ruido(i + vec2(1, 0)), f.x), mix(ruido(i + vec2(0, 1)), ruido(i + vec2(1, 1)), f.x), f.y);
}
varying vec3 mundo;
void vertex() { mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float m = suave(mundo.xy * 1.7 + mundo.zz * 0.9) * 0.6 + suave(mundo.zy * 4.0) * 0.4;
	ALBEDO = cor * (0.93 + 0.07 * m);
	ROUGHNESS = 0.92;
}
""", {"cor": CAL})


## A barra de azulejo: quadrados de 15 cm, branco com o desenho azul de
## losango e flor, como a azulejaria das igrejas da Bahia.
func _azulejo(_medida: Vector2) -> ShaderMaterial:
	return _shader("""
shader_type spatial;
uniform vec3 azul : source_color;
varying vec3 mundo;
void vertex() { mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = vec2(mundo.x + mundo.z, mundo.y) / 0.15;
	vec2 q = fract(p) - 0.5;
	float rejunte = step(0.46, max(abs(q.x), abs(q.y)));
	float losango = step(abs(q.x) + abs(q.y), 0.36) - step(abs(q.x) + abs(q.y), 0.26);
	float miolo = step(length(q), 0.09);
	float canto = step(0.38, abs(q.x)) * step(0.38, abs(q.y));
	float desenho = clamp(losango + miolo + canto, 0.0, 1.0);
	vec3 base = mix(vec3(0.95, 0.94, 0.9), azul, desenho);
	ALBEDO = mix(base, vec3(0.78, 0.76, 0.7), rejunte);
	ROUGHNESS = mix(0.18, 0.8, rejunte);
	SPECULAR = 0.6;
}
""", {"azul": AZULEJO})


## A lajota de barro: placas de 40 cm em junta corrida, cada uma num tom.
func _lajota() -> ShaderMaterial:
	return _shader("""
shader_type spatial;
uniform vec3 barro : source_color;
float ruido(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
varying vec3 mundo;
void vertex() { mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = mundo.xz / 0.4;
	p.x += step(1.0, mod(floor(p.y), 2.0)) * 0.5;
	vec2 celula = floor(p);
	vec2 q = fract(p);
	float junta = 1.0 - step(0.04, q.x) * step(0.04, q.y);
	float tom = ruido(celula) * 0.22 - 0.11;
	vec3 placa = barro * (1.0 + tom) * (0.94 + 0.06 * ruido(floor(p * 9.0)));
	ALBEDO = mix(placa, vec3(0.42, 0.36, 0.3), junta);
	ROUGHNESS = 0.78;
}
""", {"barro": Color("a85f3d")})


## Tábua corrida, para o forro e o estrado do presbitério.
func _tabua(_medida: Vector2) -> ShaderMaterial:
	return _shader("""
shader_type spatial;
uniform vec3 madeira : source_color;
float ruido(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
varying vec3 mundo;
void vertex() { mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float tabua = floor(mundo.x / 0.22);
	float junta = step(0.94, fract(mundo.x / 0.22));
	float veio = sin(mundo.z * 3.0 + ruido(vec2(tabua, 1.0)) * 40.0 + sin(mundo.z * 0.7 + tabua) * 2.0) * 0.5 + 0.5;
	vec3 cor = madeira * (0.82 + 0.18 * ruido(vec2(tabua, 3.0))) * (0.9 + 0.1 * veio);
	ALBEDO = mix(cor, cor * 0.45, junta);
	ROUGHNESS = 0.7;
}
""", {"madeira": MADEIRA_CLARA})


func _shader(codigo: String, parametros: Dictionary) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = codigo
	var material := ShaderMaterial.new()
	material.shader = shader
	for nome in parametros:
		material.set_shader_parameter(nome, parametros[nome])
	return material
