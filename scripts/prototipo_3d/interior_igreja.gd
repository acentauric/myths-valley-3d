extends Node3D
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
## A LUZ NÃO VAZA
##
## Tudo o que é deste cômodo mora na camada visual `CAMADA_DO_COMODO`, e as
## luzes daqui só acendem essa camada e a dos corpos (`CAMADA_DOS_CORPOS`, que
## o `interiores.gd` põe no jogador e nos moradores). Sem isso o lampião da nave
## clareava o adro de noite através da parede: luz sem sombra não conhece muro.

const CatalogoAssets = preload("res://scripts/prototipo_3d/catalogo_assets.gd")
const Mar = preload("res://scripts/prototipo_3d/mar.gd")

## As camadas visuais do cômodo e dos corpos que andam nele (1 << n-1).
const CAMADA_DO_COMODO := 1 << 10
const CAMADA_DOS_CORPOS := 1 << 11

const PAREDE := 0.4
## A porta, no meio da fachada.
const LARGURA_DA_PORTA := 1.2
const ALTURA_DA_PORTA := 2.7

const CAL := Color("efe8d8")
const AZULEJO := Color("2f5d93")
const MADEIRA := Color("5b3a22")
const MADEIRA_CLARA := Color("8a5f3a")
const OURO := Color("c9a14a")
const VERMELHO := Color("8e2a24")
const PEDRA := Color("cfc6b2")

## As medidas da nave, por dentro (ver `configurar`).
var largura := 4.6
var comprimento := 7.8
var pe_direito := 3.6
## Até onde a porta atravessa a fachada, a partir da parede de dentro: o vão
## por onde se passa e onde fica o escuro da porta aberta, visto de fora.
var fundo_da_porta := 0.3
## Quanto o chão da nave está acima do patamar de fora, na porta (o topo da
## escadaria de pedra que o vale põe na frente da igreja): a rampa da soleira
## desce isso.
var altura_da_soleira := 0.7

## O presbitério: fundo e altura (dois degraus).
var _fundo_do_presbiterio := 2.2
const ALTURA_DO_PRESBITERIO := 0.3

## As velas do altar, para tremerem (ver `_process`).
var _velas: Array[OmniLight3D] = []
var _janelas: Array[Dictionary] = []
var _relogio := 0.0
## Quantas caixas já foram postas, para o nome de cada uma ser único.
var _pecas := 0


## O degrau do alicerce, do adro até o patamar de fora (ver `_montar_porta`), e
## onde a frente do alicerce fica, a partir da parede de dentro da fachada.
var degrau_de_fora := 0.0
var borda_do_alicerce := 0.0
## Quanto a soleira de fora se afasta da porta: o quanto há de chão livre na
## frente dela, até o primeiro estorvo (o cruzeiro, no procedural, fica a um
## passo da torre).
var afastamento_de_fora := 1.6
var _cortina_de_dentro: StaticBody3D
var _cortina_de_fora: StaticBody3D


## As medidas que couberam na casca (ver `Interiores._abrir`), em metros e no
## cômodo: largura, comprimento e pe_direito da nave; fundo_da_porta;
## soleira, o degrau da nave ao patamar de fora; degrau_de_fora e borda, o do
## alicerce; e livre, o chão sem estorvo na frente da porta. Chamar antes de
## entrar na árvore.
func configurar(medidas: Dictionary) -> void:
	largura = maxf(float(medidas.get("largura", largura)), 3.0)
	comprimento = maxf(float(medidas.get("comprimento", comprimento)), 5.0)
	pe_direito = clampf(float(medidas.get("pe_direito", pe_direito)), 2.9, 6.6)
	fundo_da_porta = maxf(float(medidas.get("fundo_da_porta", fundo_da_porta)), 0.0)
	altura_da_soleira = maxf(float(medidas.get("soleira", altura_da_soleira)), 0.0)
	degrau_de_fora = clampf(float(medidas.get("degrau_de_fora", 0.0)), 0.0, 1.2)
	borda_do_alicerce = maxf(float(medidas.get("borda", 0.0)), PAREDE + fundo_da_porta)
	afastamento_de_fora = clampf(float(medidas.get("livre", 3.0)) - 0.6, 0.7, 1.6)
	_fundo_do_presbiterio = clampf(comprimento * 0.3, 1.8, 4.2)


func _ready() -> void:
	_montar_casca()
	_montar_porta()
	_montar_presbiterio()
	_montar_retabulo()
	_montar_janelas()
	_montar_moveis()
	_montar_luz()
	_acompanhar_o_dia()
	_por_na_camada(self)


## O cômodo contém este ponto do mundo? Com folga de meio palmo nas paredes.
func contem(ponto: Vector3) -> bool:
	var local := to_local(ponto)
	return absf(local.x) <= largura * 0.5 + 0.15 and local.z <= 0.15 \
		and local.z >= -comprimento - 0.15 and local.y >= -0.6 and local.y <= pe_direito + 0.4


## O ponto de passagem por dentro da porta, e o de fora dela, no chão.
func soleira_de_dentro() -> Vector3:
	return to_global(Vector3(0.0, 0.05, -1.0))


func soleira_de_fora() -> Vector3:
	return to_global(Vector3(0.0, -altura_da_soleira + 0.05, PAREDE + fundo_da_porta + afastamento_de_fora))


## NO CORREDOR DA PORTA: alinhado com o vão, entre um pouco antes da soleira de
## dentro e um pouco depois da de fora. Quem está aqui atravessa a porta em
## linha reta; quem não está vai primeiro até a soleira do seu lado.
func no_vao(ponto: Vector3) -> bool:
	var local := to_local(ponto)
	return absf(local.x) <= LARGURA_DA_PORTA * 0.5 and local.z >= -1.4 \
		and local.z <= PAREDE + fundo_da_porta + afastamento_de_fora + 0.5


# --- a casca: chão, paredes, forro --------------------------------------------

func _montar_casca() -> void:
	var meio_z := -comprimento * 0.5
	var nave := comprimento - _fundo_do_presbiterio
	_caixa(Vector3(largura, 0.3, nave), Vector3(0, -0.15, -nave * 0.5), _lajota(), true, "Chao")
	var lado_x := largura * 0.5 + PAREDE * 0.5
	for lado in [-1.0, 1.0]:
		_caixa(Vector3(PAREDE, pe_direito, comprimento + PAREDE), Vector3(lado * lado_x, pe_direito * 0.5, meio_z - PAREDE * 0.5),
			_cal(), true, "Parede")
		_caixa(Vector3(0.04, 1.2, comprimento), Vector3(lado * (largura * 0.5 - 0.02), 0.6, meio_z), _azulejo(), false, "Azulejo")
		_caixa(Vector3(0.07, 0.08, comprimento), Vector3(lado * (largura * 0.5 - 0.035), 1.22, meio_z), _cor(MADEIRA), false, "Friso")
	_caixa(Vector3(largura + PAREDE * 2.0, pe_direito, PAREDE), Vector3(0, pe_direito * 0.5, -comprimento - PAREDE * 0.5),
		_cal(), true, "Fundos")
	# O forro de tábua, e as vigas por baixo dele, de lado a lado.
	_caixa(Vector3(largura + PAREDE * 2.0, 0.2, comprimento + PAREDE * 2.0), Vector3(0, pe_direito + 0.1, meio_z),
		_tabua(), true, "Forro")
	var viga := 0.9
	while viga < comprimento - 0.3:
		_caixa(Vector3(largura, 0.2, 0.18), Vector3(0, pe_direito - 0.1, -viga), _cor(MADEIRA), false, "Viga")
		viga += 1.6
	for lado in [-1.0, 1.0]:
		_caixa(Vector3(0.18, 0.2, comprimento), Vector3(lado * (largura * 0.5 - 0.09), pe_direito - 0.1, meio_z),
			_cor(MADEIRA), false, "Cimalha")


## A FACHADA POR DENTRO, com o vão da porta aberto: a parede em três pedaços
## (os lados e a verga), o batente de madeira, as duas folhas abertas para
## dentro, e o túnel da porta através da casca até a fachada de fora — com o
## escuro da porta aberta posto lá, por cima da porta pintada do modelo. Por
## fora, a rampa por cima da escadaria leva do chão do adro à soleira.
func _montar_porta() -> void:
	var meia := LARGURA_DA_PORTA * 0.5
	var lado_largo := (largura + PAREDE * 2.0) * 0.5 - meia
	for lado in [-1.0, 1.0]:
		_caixa(Vector3(lado_largo, pe_direito, PAREDE), Vector3(lado * (meia + lado_largo * 0.5), pe_direito * 0.5, PAREDE * 0.5),
			_cal(), true, "Fachada")
		_caixa(Vector3(largura * 0.5 - meia, 1.2, 0.04), Vector3(lado * (meia + (largura * 0.5 - meia) * 0.5), 0.6, -0.02),
			_azulejo(), false, "Azulejo")
		# O batente, e a folha aberta encostada na parede de dentro.
		_caixa(Vector3(0.12, ALTURA_DA_PORTA, PAREDE + 0.04), Vector3(lado * (meia + 0.06), ALTURA_DA_PORTA * 0.5, PAREDE * 0.5),
			_cor(MADEIRA), false, "Batente")
		_caixa(Vector3(meia, ALTURA_DA_PORTA - 0.05, 0.06), Vector3(lado * (meia + meia * 0.5 + 0.12), ALTURA_DA_PORTA * 0.5, -0.06),
			_cor(Color("4d3019")), false, "Folha")
		# O túnel da porta através da casca, para quem passa não escorregar para
		# dentro da parede do modelo.
		if fundo_da_porta > 0.05:
			_caixa(Vector3(0.2, ALTURA_DA_PORTA, fundo_da_porta + 0.1),
				Vector3(lado * (meia + 0.1), ALTURA_DA_PORTA * 0.5, PAREDE + fundo_da_porta * 0.5), null, true, "Umbral")
	var verga := pe_direito - ALTURA_DA_PORTA
	_caixa(Vector3(LARGURA_DA_PORTA, verga, PAREDE), Vector3(0, ALTURA_DA_PORTA + verga * 0.5, PAREDE * 0.5), _cal(), true, "Verga")
	_caixa(Vector3(LARGURA_DA_PORTA + 0.24, 0.14, PAREDE + 0.04), Vector3(0, ALTURA_DA_PORTA + 0.07, PAREDE * 0.5), _cor(MADEIRA), false, "Batente")
	# O ESCURO DA PORTA ABERTA, de fora: por cima da porta pintada da fachada do
	# modelo, um vão escuro do tamanho dela. De dentro ele não se vê (só a
	# frente da placa desenha), e o vão mostra o adro.
	var escuro := MeshInstance3D.new()
	escuro.name = "PortaAberta"
	var placa := QuadMesh.new()
	placa.size = Vector2(LARGURA_DA_PORTA, ALTURA_DA_PORTA)
	escuro.mesh = placa
	var breu := StandardMaterial3D.new()
	breu.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	breu.albedo_color = Color(0.045, 0.035, 0.03)
	escuro.material_override = breu
	escuro.position = Vector3(0, ALTURA_DA_PORTA * 0.5, PAREDE + fundo_da_porta + 0.03)
	add_child(escuro)
	# AS CORTINAS DA CÂMERA, nas duas pontas do vão: o braço da câmera
	# atravessava a porta aberta, e com o jogador lá dentro a câmera ia parar no
	# adro — de onde só se via o escuro da porta. Ou, numa porta funda como a da
	# torre do procedural, ficava no meio do vão, olhando o avesso da parede.
	# Fica valendo a cortina do lado de quem a câmera segue
	# (`camera_do_lado_de_dentro`); estão na camada que só a câmera enxerga (a
	# mesma da superfície do mar), e ninguém tropeça nelas.
	_cortina_de_dentro = _cortina("CortinaDeDentro", PAREDE * 0.5)
	_cortina_de_fora = _cortina("CortinaDeFora", escuro.position.z)
	camera_do_lado_de_dentro(false)
	# A SOLEIRA: o chão da nave atravessa a parede da frente, e uma rampa curta
	# o liga ao patamar de FORA — o da escadaria de pedra que o vale já põe na
	# frente da igreja, com colisão e degraus que o corpo sobe. Quase sempre é
	# um degrau de poucos dedos; rampa, para o pé não tropeçar no batente.
	_caixa(Vector3(LARGURA_DA_PORTA + 0.4, 0.3, PAREDE), Vector3(0, -0.15, PAREDE * 0.5), null, true, "Soleira")
	if altura_da_soleira > 0.03:
		var corrida := maxf(altura_da_soleira * 2.5, fundo_da_porta + 0.35)
		_rampa("RampaDaSoleira", LARGURA_DA_PORTA + 0.4, Vector2(PAREDE, 0.0), Vector2(PAREDE + corrida, -altura_da_soleira))
	else:
		_caixa(Vector3(LARGURA_DA_PORTA + 0.4, 0.3, fundo_da_porta + 0.3),
			Vector3(0, -0.15, PAREDE + (fundo_da_porta + 0.3) * 0.5), null, true, "Soleira")
	# A RAMPA DO ADRO, por cima da quina do alicerce. O vale assenta a igreja
	# num alicerce de pedra um palmo acima do adro, e a escadaria de pedra que
	# ele levanta não fica do lado da porta: a quina travava o corpo, que a
	# encostava de viés — alta demais para chão, baixa demais para degrau. A
	# rampa vai de cima do alicerce, onde a da soleira começa, até um pouco
	# abaixo do chão do adro, para o pé não achar beirada nenhuma; e tem a
	# largura da fachada, para se chegar de qualquer ponto da frente.
	if degrau_de_fora > 0.05:
		var alto := Vector2(borda_do_alicerce - 0.25, -altura_da_soleira)
		var baixo := Vector2(borda_do_alicerce + maxf(degrau_de_fora * 3.0, 0.8), -altura_da_soleira - degrau_de_fora)
		_rampa("RampaDoAdro", largura + PAREDE * 2.0 + 1.0, alto, baixo + (baixo - alto).normalized() * 0.3)


func _cortina(nome: String, z: float) -> StaticBody3D:
	var cortina := StaticBody3D.new()
	cortina.name = nome
	cortina.collision_mask = 0
	var pano := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(LARGURA_DA_PORTA + 0.4, ALTURA_DA_PORTA + 0.3, 0.05)
	pano.shape = caixa
	cortina.add_child(pano)
	cortina.position = Vector3(0, ALTURA_DA_PORTA * 0.5, z)
	add_child(cortina)
	return cortina


## DE QUE LADO DA PORTA A CÂMERA FICA: do lado de quem ela segue. Com o
## jogador lá dentro, ela não sai pelo vão; com ele fora, não entra.
func camera_do_lado_de_dentro(dentro: bool) -> void:
	if _cortina_de_dentro == null:
		return
	_cortina_de_dentro.collision_layer = Mar.CAMADA_CAMERA_AGUA if dentro else 0
	_cortina_de_fora.collision_layer = 0 if dentro else Mar.CAMADA_CAMERA_AGUA


## UMA RAMPA INVISÍVEL, para o corpo subir o que, como degrau, travaria: uma
## tábua de colisão cujo tampo vai de `alto` a `baixo` (pares z, y no cômodo,
## com `baixo` do lado de +Z).
func _rampa(nome: String, largura_da_rampa: float, alto: Vector2, baixo: Vector2) -> void:
	var rampa := StaticBody3D.new()
	rampa.name = nome
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(largura_da_rampa, 0.1, alto.distance_to(baixo))
	forma.shape = caixa
	rampa.add_child(forma)
	# Positivo: a ponta de +Z desce. O meio do tampo fica entre os dois pontos,
	# e o da tábua, meia espessura abaixo dele.
	rampa.rotation.x = atan2(alto.y - baixo.y, baixo.x - alto.x)
	var meio := (alto + baixo) * 0.5
	rampa.position = Vector3(0, meio.y, meio.x) - rampa.basis.y * 0.05
	add_child(rampa)


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
		_caixa(Vector3(trecho, 0.9, 0.12), Vector3(meio_x, ALTURA_DO_PRESBITERIO + 0.45, frente - 0.08), null, true, "GradeColisao")
	# O altar de alvenaria, com a toalha branca e o frontal vermelho bordado.
	var altar_z := -comprimento + 0.85
	var chao := ALTURA_DO_PRESBITERIO
	var largura_do_altar := minf(2.4, largura * 0.42)
	_caixa(Vector3(largura_do_altar, 0.95, 0.8), Vector3(0, chao + 0.475, altar_z), _cal(), true, "Altar")
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
		var vela := OmniLight3D.new()
		vela.name = "Vela_%d" % _velas.size()
		vela.light_color = Color(1.0, 0.72, 0.42)
		vela.light_energy = 1.3
		vela.omni_range = minf(5.0, comprimento * 0.6)
		vela.light_cull_mask = CAMADA_DO_COMODO | CAMADA_DOS_CORPOS
		vela.position = Vector3(x, chao + 1.5, -comprimento + 0.95)
		add_child(vela)
		_velas.append(vela)
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
			_peca("banco", onde, PI, escala)
			_caixa(Vector3(comprimento_do_banco, 0.85, 0.6), onde + Vector3(0, 0.42, 0), null, true, "BancoColisao")
		fila -= 1.3
	# A pia de água benta, à direita de quem entra.
	_peca("pote", Vector3(largura * 0.5 - 0.35, 0.0, -0.55), 0.0, 0.55)
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
## de dentro sairiam claras como as de fora: a sonda de reflexo troca a luz
## ambiente do céu pela da sala, dentro da caixa dela. E um lampião ao meio,
## para a nave não ficar no breu à noite quando as janelas apagam.
func _montar_luz() -> void:
	var sonda := ReflectionProbe.new()
	sonda.name = "LuzDeDentro"
	sonda.size = Vector3(largura + PAREDE * 2.0, pe_direito + 0.6, comprimento + PAREDE * 2.0)
	sonda.position = Vector3(0, pe_direito * 0.5, -comprimento * 0.5)
	sonda.interior = true
	sonda.box_projection = true
	sonda.ambient_mode = ReflectionProbe.AMBIENT_COLOR
	sonda.ambient_color = Color(0.62, 0.52, 0.42)
	sonda.ambient_color_energy = 0.5
	sonda.update_mode = ReflectionProbe.UPDATE_ONCE
	sonda.cull_mask = CAMADA_DO_COMODO
	add_child(sonda)
	var lampiao := OmniLight3D.new()
	lampiao.name = "Lampiao"
	lampiao.light_color = Color(1.0, 0.78, 0.5)
	lampiao.light_energy = 0.75
	lampiao.omni_range = maxf(largura, comprimento) * 0.75
	lampiao.light_cull_mask = CAMADA_DO_COMODO | CAMADA_DOS_CORPOS
	lampiao.position = Vector3(0, pe_direito - 0.9, -comprimento * 0.45)
	add_child(lampiao)


func _process(delta: float) -> void:
	_relogio += delta
	# A chama mexe: duas senoides de períodos primos entre si, para não repetir.
	for i in _velas.size():
		_velas[i].light_energy = 1.25 + 0.12 * sin(_relogio * 7.3 + i * 1.7) + 0.08 * sin(_relogio * 13.1 + i)


## As janelas acompanham o dia: claras de manhã à tarde, douradas no fim do
## dia, azul-escuras de noite — e o facho entra só com sol.
func _acompanhar_o_dia(_hora: float = 0.0) -> void:
	var luz := Dia.luz_do_dia()
	var cor_de_dia := Color(1.0, 0.95, 0.84).lerp(Color(1.0, 0.72, 0.42), 1.0 - smoothstep(0.55, 1.0, luz))
	var cor := Color(0.06, 0.08, 0.16).lerp(cor_de_dia, luz)
	for janela in _janelas:
		(janela["vidro"] as StandardMaterial3D).albedo_color = cor
		(janela["luz"] as SpotLight3D).light_energy = 2.6 * luz
		(janela["luz"] as SpotLight3D).visible = luz > 0.02
	if not Dia.hora_mudou.is_connected(_acompanhar_o_dia):
		Dia.hora_mudou.connect(_acompanhar_o_dia)


## Tudo o que este cômodo desenha vai para a camada dele, e só para ela: é o
## que as luzes daqui acendem (ver o cabeçalho). O escuro da porta aberta fica
## fora — ele é visto de fora, e é desenho sem luz.
func _por_na_camada(no: Node) -> void:
	for filho in no.get_children():
		if filho is VisualInstance3D and not (filho is Light3D) and not (filho is ReflectionProbe) \
				and str(filho.name) != "PortaAberta":
			(filho as VisualInstance3D).layers = CAMADA_DO_COMODO
		_por_na_camada(filho)


# --- materiais e caixas -------------------------------------------------------

## Uma caixa: malha com o material, e corpo de colisão quando `solida`. Sem
## material, só a colisão (a grade de comunhão, os bancos, o túnel da porta).
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
func _tabua() -> ShaderMaterial:
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
