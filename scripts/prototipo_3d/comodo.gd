extends Node3D
## UM CÔMODO DENTRO DA CASCA DE UMA CONSTRUÇÃO — o que todo cômodo do vale tem.
##
## Nasceu da igreja do Bom Jesus (`interior_igreja.gd`), o primeiro cômodo, e
## saiu dela quando a casa herdada (`interior_casa.gd`) abriu por dentro: a
## parede, o chão, o forro, a porta aberta com o túnel pela casca, as rampas
## onde degrau travaria o pé, as cortinas da câmera, a luz de dentro que não
## vaza, as janelas que acompanham o dia. O que é de cada construção — o altar,
## a cama — mora em quem estende esta classe (`_montar_dentro`).
##
## A origem é o meio da fachada, por dentro, no chão do cômodo; o cômodo corre
## para -Z, longe da fachada. A porta fica em Z = 0, em X = `porta_x`: no meio
## da fachada na igreja, à direita na casa de taipa.
##
##
## A MEDIDA VEM DA CASCA
##
## Quem monta o cômodo não sabe o tamanho da construção: `configurar` recebe a
## largura, o comprimento e o pé-direito que o `interiores.gd` MEDIU na malha do
## modelo, com raios de dentro para fora — e a porta que a construção declara.
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
const Camadas = preload("res://scripts/prototipo_3d/camadas.gd")

## As camadas visuais do cômodo e dos corpos que andam nele (1 << n-1).
const CAMADA_DO_COMODO := 1 << 10
const CAMADA_DOS_CORPOS := 1 << 11

## A espessura da parede de fábrica. A de cada cômodo é `parede`: a casca que mede
## pouco por dentro (a palhoça, a capelinha) leva parede fina, para a sala não
## sair de dentro dela nem ficar menor que um quarto de gente (ver `configurar`).
const PAREDE := 0.4

const CAL := Color("efe8d8")
const MADEIRA := Color("5b3a22")
const MADEIRA_CLARA := Color("8a5f3a")
const PEDRA := Color("cfc6b2")

## A espessura da parede deste cômodo (`parede` em `configurar`).
var parede := PAREDE
## As medidas do cômodo, por dentro (ver `configurar`).
var largura := 4.6
var comprimento := 7.8
var pe_direito := 3.6
## Até onde a porta atravessa a fachada, a partir da parede de dentro: o vão
## por onde se passa e onde fica o escuro da porta aberta, visto de fora.
var fundo_da_porta := 0.3
## Quanto o chão do cômodo está acima do patamar de fora, na porta: a rampa da
## soleira desce isso.
var altura_da_soleira := 0.7
## O degrau do alicerce, do chão de fora até o patamar (ver `_montar_porta`), e
## onde a frente do alicerce fica, a partir da parede de dentro da fachada.
var degrau_de_fora := 0.0
var borda_do_alicerce := 0.0
## Quanto a soleira de fora se afasta da porta: o quanto há de chão livre na
## frente dela, até o primeiro estorvo.
var afastamento_de_fora := 1.6
## A CASCA DE FORA (#205): quanto a colisão avança para fora, além da parede (`parede`), até a face
## visível da parede do modelo, em cada lado e no fundo; e onde, no cômodo (z), está a face de fora
## da fachada fora do vão — 0 sem medida. Ver `_montar_a_casca_de_fora`.
var fora_direita := 0.0
var fora_esquerda := 0.0
var fora_fundo := 0.0
var fachada_de_fora := 0.0
## A PORTA: onde ela fica na fachada (do meio para +X) e o tamanho do vão.
var porta_x := 0.0
var largura_da_porta := 1.2
var altura_da_porta := 2.7

## As chamas que tremem (ver `_process`) e as janelas que acompanham o dia.
var _velas: Array[OmniLight3D] = []
var _janelas: Array[Dictionary] = []
var _relogio := 0.0
## Quantas caixas já foram postas, para o nome de cada uma ser único.
var _pecas := 0
var _cortina_de_dentro: StaticBody3D
var _cortina_de_fora: StaticBody3D
## A CÂMERA DE CIMA, para cômodo pequeno demais para a de passeio (a casa): com
## o jogador lá dentro, o teto e a casca da construção (`casca`, que o
## `interiores.gd` entrega) somem para a câmera e continuam fazendo sombra —
## o sol não entra pelo telhado que não se vê. O forro não tem colisão, para o
## braço da câmera passar por ele.
var camera_de_cima := false
## UMA RAMPA SÓ, da soleira até depois da quina do alicerce, em vez das duas
## (a da soleira e a do adro). A do adro começa em cima do alicerce e desce por
## baixo da quina dele; numa base baixa e curta, como a de chão batido da casa
## de taipa, a quina ficava cinco dedos acima da rampa, e o corpo, de 0,28 de
## raio, a tomava por parede e parava na porta.
var rampa_da_porta_inteira := false
var casca: Array = []
## Se o teto e a casca estão só na sombra agora (`por_dentro`), e as malhas que ficaram assim.
var _casca_so_na_sombra := false
var _geometrias_da_casca: Array = []
var _teto: Array[Node] = []
## Os corpos do cômodo (paredes, móveis): a câmera de cima não bate neles, e
## fica por cima da parede em vez de encolher até a cabeça do jogador.
var _corpos: Array[RID] = []
## Os móveis com colisão: {"nome", "peca", "corpo"} (ver `_colisao_da_peca`).
var _moveis: Array[Dictionary] = []


## As medidas que couberam na casca (ver `Interiores._abrir`), em metros e no
## cômodo: largura, comprimento e pe_direito; fundo_da_porta; soleira, o degrau
## do chão ao patamar de fora; degrau_de_fora e borda, o do alicerce; livre, o
## chão sem estorvo na frente da porta; e a porta: porta_x, largura_da_porta e
## altura_da_porta. Chamar antes de entrar na árvore.
func configurar(medidas: Dictionary) -> void:
	parede = clampf(float(medidas.get("parede", PAREDE)), 0.12, PAREDE)
	largura = maxf(float(medidas.get("largura", largura)), 3.0)
	comprimento = maxf(float(medidas.get("comprimento", comprimento)), _comprimento_minimo())
	pe_direito = clampf(float(medidas.get("pe_direito", pe_direito)), _pe_direito_minimo(), 6.6)
	fundo_da_porta = maxf(float(medidas.get("fundo_da_porta", fundo_da_porta)), 0.0)
	altura_da_soleira = maxf(float(medidas.get("soleira", altura_da_soleira)), 0.0)
	degrau_de_fora = clampf(float(medidas.get("degrau_de_fora", 0.0)), 0.0, 1.2)
	borda_do_alicerce = maxf(float(medidas.get("borda", 0.0)), parede + fundo_da_porta)
	afastamento_de_fora = clampf(float(medidas.get("livre", 3.0)) - 0.6, 0.7, 1.6)
	largura_da_porta = clampf(float(medidas.get("largura_da_porta", largura_da_porta)), 0.8, 2.0)
	altura_da_porta = clampf(float(medidas.get("altura_da_porta", altura_da_porta)), 1.9, pe_direito)
	fora_direita = maxf(float(medidas.get("fora_direita", 0.0)), 0.0)
	fora_esquerda = maxf(float(medidas.get("fora_esquerda", 0.0)), 0.0)
	fora_fundo = maxf(float(medidas.get("fora_fundo", 0.0)), 0.0)
	fachada_de_fora = float(medidas.get("fachada_de_fora", 0.0))
	# A porta não sai da fachada: o vão inteiro cabe entre as paredes do lado.
	var folga := largura * 0.5 - largura_da_porta * 0.5 - 0.1
	porta_x = clampf(float(medidas.get("porta_x", porta_x)), -folga, folga)
	_configurar(medidas)


## O menor comprimento e o menor pé-direito que o cômodo aceita.
func _comprimento_minimo() -> float:
	return 3.0


func _pe_direito_minimo() -> float:
	return 2.4


## O que a construção acrescenta às medidas (o presbitério da igreja).
func _configurar(_medidas: Dictionary) -> void:
	pass


func _ready() -> void:
	_montar_casca()
	_montar_porta()
	_montar_dentro()
	_montar_luz()
	_acompanhar_o_dia()
	_por_na_camada(self)


## O que é desta construção por dentro: o altar, os bancos, a cama.
func _montar_dentro() -> void:
	pass


## O cômodo contém este ponto do mundo? Com folga de meio palmo nas paredes, e
## `mais` além dela: quem JÁ está dentro fica dentro um pouco além da porta
## (`Interiores`), e o corpo parado na soleira não troca de lado a cada quadro.
func contem(ponto: Vector3, mais: float = 0.0) -> bool:
	var local := to_local(ponto)
	return absf(local.x) <= largura * 0.5 + 0.15 + mais and local.z <= 0.15 + mais \
		and local.z >= -comprimento - 0.15 - mais and local.y >= -0.6 - mais and local.y <= pe_direito + 0.4 + mais


## O ponto de passagem por dentro da porta, e o de fora dela, no chão.
func soleira_de_dentro() -> Vector3:
	return to_global(Vector3(porta_x, 0.05, -1.0))


func soleira_de_fora() -> Vector3:
	return to_global(Vector3(porta_x, -altura_da_soleira + 0.05, parede + fundo_da_porta + afastamento_de_fora))


## UM LUGAR DE ESPERAR DO LADO DE FORA: diante da fachada, do lado da porta que
## tem mais parede, e fora do corredor dela — quem espera ali não fecha a
## passagem. É onde o Pedro espera o jogador que entrou em casa.
func lugar_de_esperar_fora() -> Vector3:
	var lado := -1.0 if porta_x >= 0.0 else 1.0
	var x := clampf(porta_x + lado * (largura_da_porta * 0.5 + 0.9), -largura * 0.5 - 0.6, largura * 0.5 + 0.6)
	return to_global(Vector3(x, -altura_da_soleira + 0.05, parede + fundo_da_porta + afastamento_de_fora + 0.9))


## NO CORREDOR DA PORTA: alinhado com o vão, entre um pouco antes da soleira de
## dentro e um pouco depois da de fora. Quem está aqui atravessa a porta em
## linha reta; quem não está vai primeiro até a soleira do seu lado.
func no_vao(ponto: Vector3) -> bool:
	var local := to_local(ponto)
	return absf(local.x - porta_x) <= largura_da_porta * 0.5 and local.z >= -1.4 \
		and local.z <= parede + fundo_da_porta + afastamento_de_fora + 0.5


# --- a casca: chão, paredes, forro --------------------------------------------

func _montar_casca() -> void:
	var meio_z := -comprimento * 0.5
	_montar_chao()
	var lado_x := largura * 0.5 + parede * 0.5
	for lado in [-1.0, 1.0]:
		_caixa(Vector3(parede, pe_direito, comprimento + parede), Vector3(lado * lado_x, pe_direito * 0.5, meio_z - parede * 0.5),
			_parede(), true, "Parede")
		_barra_da_parede(lado)
	_caixa(Vector3(largura + parede * 2.0, pe_direito, parede), Vector3(0, pe_direito * 0.5, -comprimento - parede * 0.5),
		_parede(), true, "Fundos")
	_barra_do_fundo()
	_montar_a_casca_de_fora()
	# O forro, e as vigas por baixo dele, de lado a lado.
	_teto.append(_caixa(Vector3(largura + parede * 2.0, 0.2, comprimento + parede * 2.0), Vector3(0, pe_direito + 0.1, meio_z),
		_forro(), not camera_de_cima, "Forro"))
	var viga := 0.9
	while viga < comprimento - 0.3:
		_teto.append(_caixa(Vector3(largura, 0.2, 0.18), Vector3(0, pe_direito - 0.1, -viga), _cor(MADEIRA), false, "Viga"))
		viga += 1.6
	for lado in [-1.0, 1.0]:
		_teto.append(_caixa(Vector3(0.18, 0.2, comprimento), Vector3(lado * (largura * 0.5 - 0.09), pe_direito - 0.1, meio_z),
			_cor(MADEIRA), false, "Cimalha"))


## A COLISÃO ATÉ A PAREDE VISÍVEL (#205). As paredes do cômodo acabam um palmo para dentro da face
## de dentro da casca do modelo, e a parede do modelo tem a espessura dela: o corpo que chegava por
## fora parava com o ombro dentro do reboco — e, ao lado da porta, onde a fachada tem o fundo do
## vão e só o batente de 20 cm era sólido, entrava na parede. Aqui entram, só de colisão e sem
## desenho, o que falta até a face de fora: as duas laterais e o fundo (`fora_*`) e a fachada de
## cada lado do vão, da parede de dentro à face de fora — as ombreiras da porta são sólidas.
func _montar_a_casca_de_fora() -> void:
	var z_frente := _face_de_fora_da_fachada()
	var x_direita := largura * 0.5 + parede + fora_direita
	var x_esquerda := -(largura * 0.5 + parede + fora_esquerda)
	var z_fundo := -comprimento - parede - fora_fundo
	if fora_direita > 0.02:
		_caixa(Vector3(fora_direita, pe_direito, z_frente - z_fundo),
			Vector3(largura * 0.5 + parede + fora_direita * 0.5, pe_direito * 0.5, (z_frente + z_fundo) * 0.5), null, true, "ParedeFora")
	if fora_esquerda > 0.02:
		_caixa(Vector3(fora_esquerda, pe_direito, z_frente - z_fundo),
			Vector3(-(largura * 0.5 + parede + fora_esquerda * 0.5), pe_direito * 0.5, (z_frente + z_fundo) * 0.5), null, true, "ParedeFora")
	if fora_fundo > 0.02:
		_caixa(Vector3(x_direita - x_esquerda, pe_direito, fora_fundo),
			Vector3((x_direita + x_esquerda) * 0.5, pe_direito * 0.5, -comprimento - parede - fora_fundo * 0.5), null, true, "FundosFora")
	var fundo_da_fachada := z_frente - parede
	if fundo_da_fachada > 0.02:
		var meia := largura_da_porta * 0.5
		for lado in [-1.0, 1.0]:
			var junto_da_porta: float = porta_x + lado * meia
			var ponta: float = x_direita if lado > 0.0 else x_esquerda
			var trecho: float = absf(ponta - junto_da_porta)
			if trecho > 0.02:
				_caixa(Vector3(trecho, pe_direito, fundo_da_fachada),
					Vector3((junto_da_porta + ponta) * 0.5, pe_direito * 0.5, parede + fundo_da_fachada * 0.5), null, true, "FachadaFora")


## Onde, no cômodo (z), está a face de fora da fachada: a do vão da porta (`parede + fundo_da_porta`),
## ou a medida fora do vão (`fachada_de_fora`), a que avançar mais — porta rebaixada na parede.
func _face_de_fora_da_fachada() -> float:
	var no_vao := parede + fundo_da_porta
	return clampf(maxf(no_vao, fachada_de_fora), no_vao, no_vao + 1.0)


## O chão do cômodo, de parede a parede.
func _montar_chao() -> void:
	_caixa(Vector3(largura, 0.3, comprimento), Vector3(0, -0.15, -comprimento * 0.5), _piso(), true, "Chao")


## A barra da parede do lado (`lado` -1 ou 1): o azulejo da igreja, o barro da
## casa. Nada, de fábrica.
func _barra_da_parede(_lado: float) -> void:
	pass


func _barra_do_fundo() -> void:
	pass


## A barra da fachada por dentro, de cada lado da porta: `largura_do_trecho` e
## o meio dele em X.
func _barra_da_fachada(_largura_do_trecho: float, _meio_x: float) -> void:
	pass


## Os materiais da construção: parede, piso e forro.
func _parede() -> Material:
	return _cal()


func _piso() -> Material:
	return _lajota()


func _forro() -> Material:
	return _tabua()


## A FACHADA POR DENTRO, com o vão da porta aberto: a parede em três pedaços
## (os lados e a verga), o batente de madeira, as duas folhas abertas para
## dentro, e o túnel da porta através da casca até a fachada de fora — com o
## escuro da porta aberta posto lá, por cima da porta pintada do modelo. Por
## fora, a rampa leva do chão à soleira.
func _montar_porta() -> void:
	var meia := largura_da_porta * 0.5
	var borda := (largura + parede * 2.0) * 0.5
	for lado in [-1.0, 1.0]:
		# Do lado do vão até a quina da fachada.
		var junto_da_porta: float = porta_x + lado * meia
		var trecho: float = borda - lado * junto_da_porta
		_caixa(Vector3(trecho, pe_direito, parede), Vector3(junto_da_porta + lado * trecho * 0.5, pe_direito * 0.5, parede * 0.5),
			_parede(), true, "Fachada")
		var por_dentro: float = largura * 0.5 - lado * junto_da_porta
		if por_dentro > 0.05:
			_barra_da_fachada(por_dentro, junto_da_porta + lado * por_dentro * 0.5)
		# O batente, e a folha aberta encostada na parede de dentro.
		_caixa(Vector3(0.12, altura_da_porta, parede + 0.04), Vector3(junto_da_porta + lado * 0.06, altura_da_porta * 0.5, parede * 0.5),
			_cor(MADEIRA), false, "Batente")
		var folha := minf(meia, maxf(por_dentro - 0.15, 0.2))
		_caixa(Vector3(folha, altura_da_porta - 0.05, 0.06), Vector3(junto_da_porta + lado * (folha * 0.5 + 0.12), altura_da_porta * 0.5, -0.06),
			_cor(Color("4d3019")), false, "Folha")
		# O túnel da porta através da casca, para quem passa não escorregar para
		# dentro da parede do modelo.
		if fundo_da_porta > 0.05:
			_caixa(Vector3(0.2, altura_da_porta, fundo_da_porta + 0.1),
				Vector3(junto_da_porta + lado * 0.1, altura_da_porta * 0.5, parede + fundo_da_porta * 0.5), null, true, "Umbral")
	var verga := pe_direito - altura_da_porta
	if verga > 0.02:
		_caixa(Vector3(largura_da_porta, verga, parede), Vector3(porta_x, altura_da_porta + verga * 0.5, parede * 0.5), _parede(), true, "Verga")
	_caixa(Vector3(largura_da_porta + 0.24, 0.14, parede + 0.04), Vector3(porta_x, altura_da_porta + 0.07, parede * 0.5), _cor(MADEIRA), false, "Batente")
	# O ESCURO DA PORTA ABERTA, de fora: por cima da porta pintada da fachada do
	# modelo, um vão escuro do tamanho dela. De dentro ele não se vê (só a
	# frente da placa desenha), e o vão mostra o lado de fora.
	var escuro := MeshInstance3D.new()
	escuro.name = "PortaAberta"
	var placa := QuadMesh.new()
	placa.size = Vector2(largura_da_porta, altura_da_porta)
	escuro.mesh = placa
	var breu := StandardMaterial3D.new()
	breu.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	breu.albedo_color = Color(0.045, 0.035, 0.03)
	escuro.material_override = breu
	escuro.position = Vector3(porta_x, altura_da_porta * 0.5, parede + fundo_da_porta + 0.03)
	add_child(escuro)
	_porta_aberta = escuro
	# AS CORTINAS DA CÂMERA, nas duas pontas do vão: o braço da câmera
	# atravessava a porta aberta, e com o jogador lá dentro a câmera ia parar do
	# lado de fora — de onde só se via o escuro da porta. Ou, numa porta funda,
	# ficava no meio do vão, olhando o avesso da parede. Fica valendo a cortina
	# do lado de quem a câmera segue (`camera_do_lado_de_dentro`); estão na
	# camada que só a câmera enxerga (a mesma da superfície do mar), e ninguém
	# tropeça nelas.
	_cortina_de_dentro = _cortina("CortinaDeDentro", parede * 0.5)
	_cortina_de_fora = _cortina("CortinaDeFora", escuro.position.z)
	camera_do_lado_de_dentro(false)
	_montar_a_soleira()


## A SOLEIRA: o chão do cômodo atravessa a parede da frente, e uma rampa
## curta o liga ao patamar de FORA. Quase sempre é um degrau de poucos dedos;
## rampa, para o pé não tropeçar no batente. O casarão, que tem escada de pedra
## na porta, a refaz (`interior_casarao.gd`).
func _montar_a_soleira() -> void:
	_caixa(Vector3(largura_da_porta + 0.4, 0.3, parede), Vector3(porta_x, -0.15, parede * 0.5), null, true, "Soleira")
	if rampa_da_porta_inteira and degrau_de_fora > 0.05 and altura_da_soleira > 0.03:
		# Da soleira, no chão de dentro, até além da quina, por cima dela: o
		# quanto ela vai além da quina é o que a deixa uns dedos acima da
		# quina, e nunca abaixo.
		var ate_a_quina := borda_do_alicerce - parede
		var alem := maxf(0.8, ate_a_quina * degrau_de_fora / altura_da_soleira + 0.3)
		_rampa("RampaDaPorta", largura_da_porta + 1.2, Vector2(parede, 0.0),
			Vector2(borda_do_alicerce + alem, -altura_da_soleira - degrau_de_fora))
		return
	if altura_da_soleira > 0.03:
		var corrida := maxf(altura_da_soleira * 2.5, fundo_da_porta + 0.35)
		_rampa("RampaDaSoleira", largura_da_porta + 0.4, Vector2(parede, 0.0), Vector2(parede + corrida, -altura_da_soleira))
	else:
		_caixa(Vector3(largura_da_porta + 0.4, 0.3, fundo_da_porta + 0.3),
			Vector3(porta_x, -0.15, parede + (fundo_da_porta + 0.3) * 0.5), null, true, "Soleira")
	# A RAMPA DO ALICERCE, por cima da quina dele. Quando a construção fica num
	# alicerce um palmo acima do chão, a quina travava o corpo, que a encostava
	# de viés — alta demais para chão, baixa demais para degrau. A rampa vai de
	# cima do alicerce, onde a da soleira começa, até um pouco abaixo do chão,
	# para o pé não achar beirada nenhuma; e tem a largura da fachada, para se
	# chegar de qualquer ponto da frente.
	if degrau_de_fora > 0.05:
		var alto := Vector2(borda_do_alicerce - 0.25, -altura_da_soleira)
		var baixo := Vector2(borda_do_alicerce + maxf(degrau_de_fora * 3.0, 0.8), -altura_da_soleira - degrau_de_fora)
		_rampa("RampaDoAdro", largura + parede * 2.0 + 1.0, alto, baixo + (baixo - alto).normalized() * 0.3, 0.0)


## A PORTA TRANCADA: a casa herdada fica fechada até a Dona Zefa dar a chave
## (`prototype._acertar_a_porta_da_casa`). Trancada, um corpo fecha o vão do
## lado de fora, e o escuro da porta aberta sai — por fora volta a porta pintada
## do modelo. Destrancada, o corpo sai da física.
var _porta_aberta: MeshInstance3D
var _tranca: Node3D


func trancar(sim: bool) -> void:
	if _tranca == null:
		if not sim:
			return
		_tranca = _caixa(Vector3(largura_da_porta + 0.3, altura_da_porta, 0.3),
			Vector3(porta_x, altura_da_porta * 0.5, parede + fundo_da_porta + 0.15), null, true, "PortaTrancada")
	_tranca.process_mode = Node.PROCESS_MODE_INHERIT if sim else Node.PROCESS_MODE_DISABLED
	if _porta_aberta != null:
		_porta_aberta.visible = not sim


func trancada() -> bool:
	return _tranca != null and _tranca.process_mode != Node.PROCESS_MODE_DISABLED


func _cortina(nome: String, z: float) -> StaticBody3D:
	var cortina := StaticBody3D.new()
	cortina.name = nome
	cortina.collision_mask = 0
	var pano := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(largura_da_porta + 0.4, altura_da_porta + 0.3, 0.05)
	pano.shape = caixa
	cortina.add_child(pano)
	cortina.position = Vector3(porta_x, altura_da_porta * 0.5, z)
	add_child(cortina)
	return cortina


## DE QUE LADO DA PORTA A CÂMERA FICA: do lado de quem ela segue. Com o
## jogador lá dentro, ela não sai pelo vão; com ele fora, não entra.
func camera_do_lado_de_dentro(dentro: bool) -> void:
	if _cortina_de_dentro == null:
		return
	# A câmera de cima já fica por cima das paredes e do vão (`camera_de_cima`): a
	# cortina de dentro só serve ao cômodo de câmera de passeio. Nele, ao contrário,
	# ela cortava o braço colado às costas de quem acabava de entrar.
	_cortina_de_dentro.collision_layer = Mar.CAMADA_CAMERA_AGUA if dentro and not camera_de_cima else 0
	_cortina_de_fora.collision_layer = 0 if dentro else Mar.CAMADA_CAMERA_AGUA
	por_dentro(dentro)


## Os corpos que a câmera de cima atravessa (ver `_corpos`).
func corpos_do_comodo() -> Array[RID]:
	return _corpos


## O TETO SOME PARA A CÂMERA DE CIMA (ver `camera_de_cima`): o forro, as vigas
## e a casca da construção ficam só na sombra enquanto o jogador está dentro.
## Na construção sem câmera de cima, nada muda.
##
## SÓ MEXE QUANDO O ESTADO MUDA (#185). `Interiores` avisa TODAS as construções a cada
## troca de lado, e cada aviso varria a casca inteira atrás das malhas (`find_children`)
## para pôr nelas o modo que já tinham: na travessia da porta, a varredura de todas as
## casas do vale caía num quadro só, e cada `cast_shadow` regravado refaz o registro da
## malha no passe de sombra. Agora as malhas são achadas uma vez, na entrada, e quem já
## está no estado pedido não faz nada.
func por_dentro(dentro: bool) -> void:
	if not camera_de_cima or dentro == _casca_so_na_sombra:
		return
	_casca_so_na_sombra = dentro
	if dentro:
		_geometrias_da_casca.clear()
		for no in _teto + casca:
			if not is_instance_valid(no):
				continue
			if no is GeometryInstance3D:
				_geometrias_da_casca.append(no)
			_geometrias_da_casca.append_array((no as Node).find_children("*", "GeometryInstance3D", true, false))
	var modo := GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if dentro else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for geometria in _geometrias_da_casca:
		if is_instance_valid(geometria):
			(geometria as GeometryInstance3D).cast_shadow = modo
	if not dentro:
		_geometrias_da_casca.clear()


## UMA RAMPA INVISÍVEL, para o corpo subir o que, como degrau, travaria: uma
## tábua de colisão cujo tampo vai de `alto` a `baixo` (pares z, y no cômodo,
## com `baixo` do lado de +Z), centrada em `x` (a porta, de fábrica).
func _rampa(nome: String, largura_da_rampa: float, alto: Vector2, baixo: Vector2, x: float = INF) -> void:
	var rampa := StaticBody3D.new()
	rampa.name = nome
	# Chão para a câmera também: ela não passa por baixo da rampa da porta.
	rampa.collision_layer = Camadas.MUNDO_E_CAMERA
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(largura_da_rampa, 0.1, alto.distance_to(baixo))
	forma.shape = caixa
	rampa.add_child(forma)
	# Positivo: a ponta de +Z desce. O meio do tampo fica entre os dois pontos,
	# e o da tábua, meia espessura abaixo dele.
	rampa.rotation.x = atan2(alto.y - baixo.y, baixo.x - alto.x)
	var meio := (alto + baixo) * 0.5
	rampa.position = Vector3(porta_x if not is_finite(x) else x, meio.y, meio.x) - rampa.basis.y * 0.05
	add_child(rampa)


# --- peças do catálogo ------------------------------------------------------

## Uma peça do catálogo no estilo do vale: o GLB do Tripo, ou o construtor do
## `FloraReconcavo` (`_procedural`). Devolve null quando nenhum dos dois existe.
func _peca(chave: String, onde: Vector3, giro: float, tamanho: float) -> Node3D:
	if Estilo.tripo():
		var modelo := CatalogoAssets.instanciar(chave, self, onde, tamanho, giro)
		if modelo != null:
			# A chave do catálogo fica marcada: o nome o Godot troca entre irmãos.
			modelo.set_meta("chave", chave)
			return modelo
	var peca := _procedural(chave)
	if peca == null:
		return null
	peca.position = onde
	peca.rotation.y = giro
	peca.scale = Vector3.ONE * tamanho
	add_child(peca)
	return peca


## O construtor procedural da peça, para o estilo procedural.
func _procedural(chave: String) -> Node3D:
	match chave:
		"banco": return FloraReconcavo.banco_praca()
		"candeeiro": return FloraReconcavo.candeeiro()
		"cruzeiro": return FloraReconcavo.cruzeiro()
		"pote": return FloraReconcavo.pote_agua()
	return null


# --- a luz --------------------------------------------------------------------

## LUZ DE DENTRO. O céu do vale ilumina tudo por igual, e sem isto as paredes
## de dentro sairiam claras como as de fora: a sonda de reflexo troca a luz
## ambiente do céu pela do cômodo, dentro da caixa dele. E um lampião ao meio,
## para o cômodo não ficar no breu à noite quando as janelas apagam.
func _montar_luz() -> void:
	var sonda := ReflectionProbe.new()
	sonda.name = "LuzDeDentro"
	sonda.size = Vector3(largura + parede * 2.0, pe_direito + 0.6, comprimento + parede * 2.0)
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
	lampiao.position = _lugar_do_lampiao()
	add_child(lampiao)


func _lugar_do_lampiao() -> Vector3:
	return Vector3(0, pe_direito - 0.9, -comprimento * 0.45)


## Uma chama que treme, na luz do cômodo.
func _vela(nome: String, onde: Vector3, alcance: float, energia: float = 1.3) -> OmniLight3D:
	var vela := OmniLight3D.new()
	vela.name = "%s_%d" % [nome, _velas.size()]
	vela.light_color = Color(1.0, 0.72, 0.42)
	vela.light_energy = energia
	vela.omni_range = alcance
	vela.light_cull_mask = CAMADA_DO_COMODO | CAMADA_DOS_CORPOS
	vela.position = onde
	vela.set_meta("energia", energia)
	add_child(vela)
	_velas.append(vela)
	return vela


func _process(delta: float) -> void:
	_relogio += delta
	# A chama mexe: duas senoides de períodos primos entre si, para não repetir.
	for i in _velas.size():
		var base := float(_velas[i].get_meta("energia", 1.3)) - 0.05
		_velas[i].light_energy = base + 0.12 * sin(_relogio * 7.3 + i * 1.7) + 0.08 * sin(_relogio * 13.1 + i)


## UMA JANELA na parede, por dentro: o caixilho, o vidro que é a luz do dia, e
## o facho que entra enviesado. `onde` é o meio da janela rente à parede;
## `para_dentro` aponta da parede para o cômodo.
func _janela(onde: Vector3, para_dentro: Vector3, largura_da_janela: float, altura: float) -> void:
	var raiz := Node3D.new()
	_pecas += 1
	raiz.name = "Janela_%d" % _pecas
	raiz.position = onde
	raiz.rotation.y = atan2(para_dentro.x, para_dentro.z)
	add_child(raiz)
	# O caixilho em volta e a cruz de madeira por cima do vidro (+Z é o cômodo).
	for parte in [
		[Vector3(largura_da_janela + 0.18, 0.09, 0.08), Vector3(0, altura * 0.5 + 0.045, 0.02)],
		[Vector3(largura_da_janela + 0.18, 0.09, 0.08), Vector3(0, -altura * 0.5 - 0.045, 0.02)],
		[Vector3(0.09, altura, 0.08), Vector3(-largura_da_janela * 0.5 - 0.045, 0, 0.02)],
		[Vector3(0.09, altura, 0.08), Vector3(largura_da_janela * 0.5 + 0.045, 0, 0.02)],
		[Vector3(largura_da_janela, 0.05, 0.05), Vector3(0, 0, 0.05)],
		[Vector3(0.05, altura, 0.05), Vector3(0, 0, 0.05)],
	]:
		var malha := MeshInstance3D.new()
		var caixa := BoxMesh.new()
		caixa.size = parte[0]
		malha.mesh = caixa
		malha.material_override = _cor(MADEIRA)
		malha.position = parte[1]
		raiz.add_child(malha)
	var vidro := MeshInstance3D.new()
	var placa := QuadMesh.new()
	placa.size = Vector2(largura_da_janela, altura)
	vidro.mesh = placa
	var luz_do_vidro := StandardMaterial3D.new()
	luz_do_vidro.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	vidro.material_override = luz_do_vidro
	vidro.position = Vector3(0, 0, 0.01)
	raiz.add_child(vidro)
	var facho := SpotLight3D.new()
	facho.name = "LuzDaJanela"
	facho.light_color = Color(1.0, 0.94, 0.82)
	facho.spot_range = maxf(largura, comprimento) * 1.4
	facho.spot_angle = 40.0
	facho.spot_attenuation = 0.8
	facho.light_cull_mask = CAMADA_DO_COMODO | CAMADA_DOS_CORPOS
	add_child(facho)
	facho.look_at_from_position(onde + para_dentro * 0.25 + Vector3.UP * 0.4,
		onde + para_dentro * 2.5 + Vector3.DOWN * (onde.y + 0.5), Vector3.UP)
	_janelas.append({"vidro": luz_do_vidro, "luz": facho})


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
## material, só a colisão (os bancos, o túnel da porta).
##
## `barra_camera`: a caixa sólida barra também o braço da câmera
## (`camadas.gd`). Parede, chão, forro, verga e tranca barram — a câmera não
## sai do cômodo pela parede; móvel, banco, altar e grade não, e a câmera não
## salta ao passar por eles.
func _caixa(tamanho: Vector3, onde: Vector3, material: Material, solida: bool, nome: String, barra_camera: bool = true) -> Node3D:
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
		corpo.collision_layer = Camadas.MUNDO_E_CAMERA if barra_camera else Camadas.MUNDO
		var forma := CollisionShape3D.new()
		var formato := BoxShape3D.new()
		formato.size = tamanho
		forma.shape = formato
		corpo.add_child(forma)
		raiz.add_child(corpo)
		_corpos.append(corpo.get_rid())
	return raiz


## A COLISÃO DE UM MÓVEL NA MEDIDA DELE: a caixa das malhas da peça, no
## referencial do cômodo — e não uma medida escrita à parte.
##
## "Revise a área de colisão de todos os móveis." Na casa, só a cama e o baú
## tinham corpo, e com a medida escrita à mão: o modelo do Tripo é posto na
## largura pedida, e na outra direção ele tem a medida dele, que a caixa não
## acompanhava. A mesa, o fogão, o barril, a cantareira, o jirau e o oratório
## não tinham corpo nenhum, e o jogador passava por dentro deles. Na igreja, o
## banco tinha uma caixa de comprimento fixo. Agora todo móvel tem a caixa
## dele, medida nele.
func _colisao_da_peca(peca: Node3D, nome: String) -> Node3D:
	if peca == null:
		return null
	var caixa := caixa_no_comodo(peca)
	if caixa.size.x < 0.02 or caixa.size.z < 0.02:
		return null
	var corpo := _caixa(caixa.size, caixa.get_center(), null, true, nome + "Colisao", false)
	_moveis.append({"nome": nome, "peca": peca, "corpo": corpo})
	return corpo


## A caixa das malhas de `peca` no referencial do cômodo.
func caixa_no_comodo(peca: Node3D) -> AABB:
	var para_o_comodo := global_transform.affine_inverse()
	var caixa := AABB()
	var primeira := true
	var malhas: Array = peca.find_children("*", "MeshInstance3D", true, false)
	if peca is MeshInstance3D:
		malhas.append(peca)
	for no in malhas:
		var malha := no as MeshInstance3D
		if malha.mesh == null:
			continue
		var dela: AABB = para_o_comodo * malha.global_transform * malha.get_aabb()
		caixa = dela if primeira else caixa.merge(dela)
		primeira = false
	return caixa


## Os móveis com colisão, para quem confere (o portão dos móveis).
func moveis() -> Array[Dictionary]:
	return _moveis


func _cor(cor: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = cor
	material.roughness = 0.85
	return material


## A cal: branco quebrado, com a mancha suave de demão de pincel.
func _cal(cor: Color = CAL) -> ShaderMaterial:
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
""", {"cor": cor})


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


## Tábua corrida, para o forro e o estrado.
func _tabua(cor: Color = MADEIRA_CLARA) -> ShaderMaterial:
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
""", {"madeira": cor})


func _shader(codigo: String, parametros: Dictionary) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = codigo
	var material := ShaderMaterial.new()
	material.shader = shader
	for nome in parametros:
		material.set_shader_parameter(nome, parametros[nome])
	return material
