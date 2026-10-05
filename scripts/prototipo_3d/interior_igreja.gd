extends "res://scripts/prototipo_3d/comodo.gd"
## O INTERIOR DA IGREJA DO BOM JESUS — dentro da própria igreja, no lugar dela no vale (#26).
##
## "Vamos começar a criar os ambientes internos das construções também. Comece
## pela igreja." E depois: "Os cômodos têm que ser em 3D mesmo. O 2D é só
## referência" — com a escolha de que o interior fica DENTRO da construção, sem
## sala à parte. A primeira versão montava a nave longe do vale e levava o
## jogador até ela num escurecer, como os cômodos do 2D; esta mora dentro da
## casca do modelo, e se entra andando pela porta.
##
## É uma capela de arraial do Recôncavo de 1887, no tamanho da casca que a
## contém: nave caiada com a barra de azulejo azul, chão de lajota, forro de
## tábua com as vigas à mostra, janelas dos dois lados, o presbitério um
## palmo acima da nave, o altar de alvenaria com a toalha e o frontal vermelho,
## o retábulo dourado com a cruz no nicho, os bancos com o corredor no meio, a
## pia de água benta na entrada e os ex-votos na parede.
##
##
## A MEDIDA VEM DA CASCA
##
## Quem monta o cômodo não sabe o tamanho da igreja: `configurar` recebe a
## largura, o comprimento e o pé-direito que o `interiores.gd` MEDIU na malha
## do modelo, com raios de dentro para fora. Nada aqui é escrito para uma
## igreja de 8 por 17: o presbitério, a fila de bancos, as janelas e o
## retábulo saem em proporção do que coube.
##
## A origem é o meio da soleira, por dentro, no chão da nave; a nave corre
## para -Z até o altar, e a porta fica em Z = 0.
##
##
## O QUE É PEÇA E O QUE É ARQUITETURA
##
## Os MÓVEIS saem do `CatalogoAssets`, no estilo escolhido: o banco, o
## candeeiro, o cruzeiro (em tamanho de altar) e o pote são GLBs do Tripo que já
## existiam; no procedural, os construtores do `FloraReconcavo`. Nenhuma peça foi
## gerada — gerar gasta crédito, e o lote dos móveis de interior (#26) pede o
## custo aprovado antes. A ARQUITETURA — parede, chão, forro, degrau, altar de
## alvenaria, retábulo — é desta classe, como o terreno e as ruas.
##
##
## O que é de todo cômodo — a parede, a porta aberta, as rampas, as cortinas da
## câmera, a luz que não vaza — mora em `comodo.gd`, de onde esta classe
## estende; aqui fica o que é da igreja.

const AZULEJO := Color("2f5d93")
const OURO := Color("c9a14a")
const VERMELHO := Color("8e2a24")

## O presbitério: fundo e altura (dois degraus).
var _fundo_do_presbiterio := 2.2
const ALTURA_DO_PRESBITERIO := 0.3


## A RAMPA INTEIRA DA PORTA, como a da casa (`comodo._montar_porta`). A rampa
## estreita da soleira só se subia de frente, e no procedural o cruzeiro da
## composição fica no pé dela, no eixo da porta: o Pedro que seguia o jogador
## para dentro batia nele, e o desvio cego o levava em volta ou fachada afora,
## conforme o quadro — de um dos lados, nunca entrava. Com a rampa da largura da
## porta e mais um tanto, chega-se à soleira de qualquer lado.
func _init() -> void:
	rampa_da_porta_inteira = true


func _comprimento_minimo() -> float:
	return 5.0


func _pe_direito_minimo() -> float:
	return 2.9


func _configurar(_medidas: Dictionary) -> void:
	_fundo_do_presbiterio = clampf(comprimento * 0.3, 1.8, 4.2)


func _montar_dentro() -> void:
	_montar_presbiterio()
	_montar_retabulo()
	_montar_janelas()
	_montar_moveis()


## ONDE SE REZA: no meio do presbitério, diante do altar. É o marco "capela"
## da fé católica (ver `marcos_da_fe.gd`).
func ponto_do_altar() -> Vector3:
	return to_global(Vector3(0.0, ALTURA_DO_PRESBITERIO, -comprimento + _fundo_do_presbiterio * 0.6))


# --- a casca da nave ------------------------------------------------------------

## A lajota vai até o presbitério, que é estrado de tábua (`_montar_presbiterio`).
func _montar_chao() -> void:
	var nave := comprimento - _fundo_do_presbiterio
	_caixa(Vector3(largura, 0.3, nave), Vector3(0, -0.15, -nave * 0.5), _lajota(), true, "Chao")


## A barra de azulejo azul dos dois lados da nave, com o friso de madeira.
func _barra_da_parede(lado: float) -> void:
	var meio_z := -comprimento * 0.5
	_caixa(Vector3(0.04, 1.2, comprimento), Vector3(lado * (largura * 0.5 - 0.02), 0.6, meio_z), _azulejo(), false, "Azulejo")
	_caixa(Vector3(0.07, 0.08, comprimento), Vector3(lado * (largura * 0.5 - 0.035), 1.22, meio_z), _cor(MADEIRA), false, "Friso")


func _barra_da_fachada(largura_do_trecho: float, meio_x: float) -> void:
	_caixa(Vector3(largura_do_trecho, 1.2, 0.04), Vector3(meio_x, 0.6, -0.02), _azulejo(), false, "Azulejo")


# --- o presbitério e o altar --------------------------------------------------

func _montar_presbiterio() -> void:
	var frente := -comprimento + _fundo_do_presbiterio
	var meio := -comprimento + _fundo_do_presbiterio * 0.5
	_caixa(Vector3(largura, ALTURA_DO_PRESBITERIO, _fundo_do_presbiterio),
		Vector3(0, ALTURA_DO_PRESBITERIO * 0.5, meio), _tabua(), true, "Presbiterio")
	# Dois degraus de pedra no meio, e uma rampa invisível por baixo deles.
	var largura_do_degrau := minf(2.4, largura * 0.6)
	for i in 2:
		var altura := ALTURA_DO_PRESBITERIO * float(2 - i) / 2.0
		_caixa(Vector3(largura_do_degrau, altura, 0.3), Vector3(0, altura * 0.5, frente + 0.15 + i * 0.3), _cor(PEDRA), false, "Degrau")
	_rampa("RampaDosDegraus", largura_do_degrau, Vector2(frente, ALTURA_DO_PRESBITERIO), Vector2(frente + 0.75, 0.0))
	# A grade de comunhão, de madeira, com a passagem no meio.
	var passagem := minf(1.2, largura * 0.26)
	var trecho := largura * 0.5 - passagem
	for lado in [-1.0, 1.0]:
		var meio_x: float = lado * (passagem + trecho * 0.5)
		_caixa(Vector3(trecho, 0.07, 0.1), Vector3(meio_x, ALTURA_DO_PRESBITERIO + 0.85, frente - 0.08), _cor(MADEIRA_CLARA), false, "Grade")
		var x: float = lado * passagem
		while absf(x) <= largura * 0.5 - 0.05:
			_caixa(Vector3(0.05, 0.85, 0.05), Vector3(x, ALTURA_DO_PRESBITERIO + 0.425, frente - 0.08), _cor(MADEIRA_CLARA), false, "Balaustre")
			x += lado * 0.26
		_caixa(Vector3(trecho, 0.9, 0.12), Vector3(meio_x, ALTURA_DO_PRESBITERIO + 0.45, frente - 0.08), null, true, "GradeColisao", false)
	# O altar de alvenaria, com a toalha branca e o frontal vermelho bordado.
	var altar_z := -comprimento + 0.85
	var chao := ALTURA_DO_PRESBITERIO
	var largura_do_altar := minf(2.4, largura * 0.42)
	_caixa(Vector3(largura_do_altar, 0.95, 0.8), Vector3(0, chao + 0.475, altar_z), _cal(), true, "Altar", false)
	_caixa(Vector3(largura_do_altar + 0.14, 0.05, 0.92), Vector3(0, chao + 0.975, altar_z), _cor(Color("f6f2e8")), false, "Toalha")
	_caixa(Vector3(largura_do_altar + 0.14, 0.3, 0.02), Vector3(0, chao + 0.82, altar_z + 0.46), _cor(Color("f6f2e8")), false, "Toalha")
	_caixa(Vector3(largura_do_altar - 0.3, 0.6, 0.03), Vector3(0, chao + 0.36, altar_z + 0.415), _cor(VERMELHO), false, "Frontal")
	for y in [0.67, 0.07]:
		_caixa(Vector3(largura_do_altar - 0.2, 0.05, 0.035), Vector3(0, chao + y, altar_z + 0.42), _ouro(), false, "Galao")
	_caixa(Vector3(0.07, 0.32, 0.035), Vector3(0, chao + 0.36, altar_z + 0.43), _ouro(), false, "CruzBordada")
	_caixa(Vector3(0.24, 0.06, 0.035), Vector3(0, chao + 0.42, altar_z + 0.43), _ouro(), false, "CruzBordada")


func _montar_retabulo() -> void:
	var fundo := -comprimento + 0.06
	var chao := ALTURA_DO_PRESBITERIO
	var largura_do_retabulo := minf(5.0, largura * 0.74)
	var altura_do_retabulo := minf(5.2, pe_direito - chao - 0.25)
	var nicho_l := minf(1.6, largura_do_retabulo * 0.36)
	var nicho_a := altura_do_retabulo * 0.6
	var nicho_y := chao + 1.05 + nicho_a * 0.5
	_caixa(Vector3(largura_do_retabulo, altura_do_retabulo, 0.12), Vector3(0, chao + altura_do_retabulo * 0.5, fundo), _cor(Color("4a2d1a")), false, "Retabulo")
	_caixa(Vector3(nicho_l, nicho_a, 0.06), Vector3(0, nicho_y, fundo + 0.08), _cor(Color("1f3557")), false, "Nicho")
	for borda in [
		[Vector3(nicho_l + 0.2, 0.12, 0.1), Vector3(0, nicho_y + nicho_a * 0.5 + 0.06, fundo + 0.1)],
		[Vector3(nicho_l + 0.2, 0.12, 0.1), Vector3(0, nicho_y - nicho_a * 0.5 - 0.06, fundo + 0.1)],
		[Vector3(0.12, nicho_a + 0.24, 0.1), Vector3(-nicho_l * 0.5 - 0.06, nicho_y, fundo + 0.1)],
		[Vector3(0.12, nicho_a + 0.24, 0.1), Vector3(nicho_l * 0.5 + 0.06, nicho_y, fundo + 0.1)],
		[Vector3(largura_do_retabulo + 0.2, 0.18, 0.18), Vector3(0, chao + altura_do_retabulo - 0.09, fundo + 0.08)],
		[Vector3(largura_do_retabulo + 0.2, 0.26, 0.22), Vector3(0, chao + 0.13, fundo + 0.1)],
	]:
		_caixa(borda[0], borda[1], _ouro(), false, "Moldura")
	# As colunas do barroco, aqui lisas e douradas: duas de cada lado do nicho.
	for x in [-largura_do_retabulo * 0.5 + 0.22, -nicho_l * 0.5 - 0.32, nicho_l * 0.5 + 0.32, largura_do_retabulo * 0.5 - 0.22]:
		var coluna := MeshInstance3D.new()
		var cilindro := CylinderMesh.new()
		cilindro.top_radius = 0.1
		cilindro.bottom_radius = 0.12
		cilindro.height = altura_do_retabulo - 0.5
		coluna.mesh = cilindro
		coluna.material_override = _ouro()
		coluna.position = Vector3(x, chao + 0.25 + cilindro.height * 0.5, fundo + 0.2)
		add_child(coluna)
	# A cruz do nicho: o cruzeiro do adro em tamanho de altar.
	_peca("cruzeiro", Vector3(0, nicho_y - nicho_a * 0.5 + 0.02, fundo + 0.16), 0.0, (nicho_a - 0.15) / 4.5)
	# Os dois candeeiros do santíssimo, nas pontas do altar, com a vela acesa.
	var largura_do_altar := minf(2.4, largura * 0.42)
	for x in [-largura_do_altar * 0.5 + 0.18, largura_do_altar * 0.5 - 0.18]:
		var castical := _peca("candeeiro", Vector3(x, chao + 1.0, -comprimento + 0.85), 0.0, 1.0)
		_vela("Vela", Vector3(x, chao + 1.5, -comprimento + 0.95), minf(5.0, comprimento * 0.6))
		if castical == null:
			_caixa(Vector3(0.06, 0.3, 0.06), Vector3(x, chao + 1.15, -comprimento + 0.85), _cor(Color("f3ecd8")), false, "Vela")


# --- as janelas ---------------------------------------------------------------

## As janelas da nave, dos dois lados, quantas couberem: o vidro acende de dia,
## doura no fim da tarde e escurece à noite, e um facho de luz entra enviesado.
## O vidro não é vidro: é a luz do dia, e de noite o azul-escuro de fora.
func _montar_janelas() -> void:
	var nave := comprimento - _fundo_do_presbiterio
	var quantas := maxi(1, int(floor((nave - 1.0) / 2.6)))
	var altura := minf(1.8, pe_direito * 0.42)
	var centro_y := minf(pe_direito - altura * 0.5 - 0.35, 1.5 + altura * 0.5 + 0.3)
	for i in quantas:
		var z := -1.6 - (nave - 2.2) * (float(i) + 0.5) / float(quantas)
		for lado in [-1.0, 1.0]:
			var x: float = lado * (largura * 0.5 - 0.03)
			_caixa(Vector3(0.08, altura + 0.2, 1.0), Vector3(x, centro_y, z), _cor(MADEIRA), false, "Janela")
			var vidro := MeshInstance3D.new()
			var placa := QuadMesh.new()
			placa.size = Vector2(0.82, altura)
			vidro.mesh = placa
			var luz_do_vidro := StandardMaterial3D.new()
			luz_do_vidro.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			vidro.material_override = luz_do_vidro
			vidro.position = Vector3(x - lado * 0.05, centro_y, z)
			vidro.rotation.y = -lado * PI * 0.5
			add_child(vidro)
			for travessa in [Vector3(0.1, 0.05, 0.82), Vector3(0.1, altura, 0.05)]:
				_caixa(travessa, Vector3(x - lado * 0.07, centro_y, z), _cor(MADEIRA), false, "Caixilho")
			var facho := SpotLight3D.new()
			facho.name = "LuzDaJanela"
			facho.light_color = Color(1.0, 0.94, 0.82)
			facho.spot_range = largura * 1.6
			facho.spot_angle = 40.0
			facho.spot_attenuation = 0.8
			facho.light_cull_mask = CAMADA_DO_COMODO | CAMADA_DOS_CORPOS
			add_child(facho)
			facho.look_at_from_position(Vector3(x - lado * 0.25, centro_y + 0.4, z),
				Vector3(-lado * largura * 0.2, 0.0, z - 0.8), Vector3.UP)
			_janelas.append({"vidro": luz_do_vidro, "luz": facho})


# --- os móveis ----------------------------------------------------------------

func _montar_moveis() -> void:
	# OS BANCOS, em duas colunas com o corredor no meio, de frente para o
	# altar. O comprimento do banco sai do que sobra de cada lado do corredor.
	var corredor := 0.9
	var comprimento_do_banco := (largura - corredor) * 0.5 - 0.25
	var escala := _escala_do_banco(comprimento_do_banco)
	var fila := -1.5
	var ultima := -(comprimento - _fundo_do_presbiterio) + 0.75
	while fila >= ultima:
		for lado in [-1.0, 1.0]:
			var onde := Vector3(lado * (corredor * 0.5 + comprimento_do_banco * 0.5 + 0.05), 0.0, fila)
			# A colisão na medida do banco posto (`_colisao_da_peca`), e não
			# de comprimento fixo; sem modelo, a caixa de sempre.
			var banco := _peca("banco", onde, PI, escala)
			if _colisao_da_peca(banco, "Banco") == null:
				_caixa(Vector3(comprimento_do_banco, 0.85, 0.6), onde + Vector3(0, 0.42, 0), null, true, "BancoColisao", false)
		fila -= 1.3
	# A pia de água benta, à direita de quem entra.
	_colisao_da_peca(_peca("pote", Vector3(largura * 0.5 - 0.35, 0.0, -0.55), 0.0, 0.55), "Pote")
	# Os ex-votos na parede da esquerda: quadrinhos de quem foi atendido.
	var cores := [Color("d9c39a"), Color("b9d0c4"), Color("e2b8a6"), Color("c7c1df"), Color("e8d79f"), Color("bfcfae")]
	for i in cores.size():
		var x := -largura * 0.5 + 0.05
		var z := -0.9 - float(i % 3) * 0.42
		var y := 1.55 + float(i / 3) * 0.45
		_caixa(Vector3(0.04, 0.34, 0.28), Vector3(x, y, z), _cor(MADEIRA), false, "ExVoto")
		_caixa(Vector3(0.045, 0.27, 0.21), Vector3(x + 0.01, y, z), _cor(cores[i]), false, "ExVoto")


## A escala do banco para ele ter o comprimento pedido: o GLB do Tripo é
## normalizado pela altura, e o procedural tem a medida dele. Nunca maior que
## o natural, que banco de igreja esticado vira banco de praça.
func _escala_do_banco(comprimento_desejado: float) -> float:
	var natural := 1.8
	if Estilo.tripo():
		var medida := Node3D.new()
		add_child(medida)
		var modelo := CatalogoAssets.instanciar("banco", medida, Vector3.ZERO, 1.0, 0.0)
		if modelo != null and modelo.has_meta("limites"):
			var caixa: AABB = modelo.get_meta("limites")
			natural = maxf(caixa.size.x, caixa.size.z)
		medida.queue_free()
	return clampf(comprimento_desejado / maxf(natural, 0.1), 0.5, 1.0)



# --- materiais da igreja ----------------------------------------------------------

func _ouro() -> StandardMaterial3D:
	var material := _cor(OURO)
	material.metallic = 0.85
	material.roughness = 0.32
	return material


## A barra de azulejo: quadrados de 15 cm, branco com o desenho azul de
## losango e flor, como a azulejaria das igrejas da Bahia.
func _azulejo() -> ShaderMaterial:
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
