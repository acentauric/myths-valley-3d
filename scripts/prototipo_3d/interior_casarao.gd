extends "res://scripts/prototipo_3d/interior_casa.gd"
## O CASARÃO DA FAZENDA POR DENTRO — o térreo da casa-grande do capítulo 6.
##
## "Precisamos melhorar a casa grande no norte do mapa, com acesso interno como as demais
## casas pequenas têm." O casarão (`casarao_fazenda`) era uma caixa de colisão só, do
## tamanho da pegada: a escada de pedra virava um bloco invisível e a porta dupla era
## pintada num muro. Agora o cômodo mora dentro da casca como o das outras casas
## (`interiores.gd`), e este arquivo diz o que é só dele:
##
##   · A ESCADARIA DE PEDRA, que dá na porta. O piso de dentro fica a 0,78 do chão
##     (a plataforma do pórtico) e a escada de oito degraus desce dela até o pátio: a
##     colisão é uma rampa que passa rente às quinas dos degraus, mais a plataforma e as
##     balaustradas. Medido no modelo (06/10/2026, perfil lateral do GLB por raios): a
##     plataforma vai de 0,9 além da porta, a escada de mais 1,5, e a quina do último
##     degrau fica a 0,16 do chão.
##   · O SALÃO, de ponta a ponta da casa, sem divisória: a mesa grande e os bancos no meio,
##     as camas e os baús na ponta de cá, o fogão e o jirau da cozinha na de lá, o
##     oratório e a escada para o andar de cima no fundo (a escada é cenário: o andar de
##     cima não abre, e o corpo bate nela).
##
## O que o salão tem mora em `data/interiores_casas.json` (`perfis.casarao`), como o das
## outras casas; aqui só entra o que não é peça do catálogo.

## Quanto a plataforma do pórtico avança além da porta, e a escada além dela (m, medidos).
const PLATAFORMA := 0.9
const ESCADA := 1.5
## A largura da escada e a das balaustradas dela (m).
const LARGURA_DA_ESCADA := 1.5
const LARGURA_DA_PLATAFORMA := 4.6
## A escada para o andar de cima, no fundo do salão: largura e fundura (m), e quantos degraus.
const ESCADA_DE_DENTRO := Vector2(2.3, 2.5)
const DEGRAUS := 10


## A porta fica no alto da escadaria: quem espera, ou espera para entrar, fica no pé dela.
func _configurar(_medidas: Dictionary) -> void:
	afastamento_de_fora = PLATAFORMA + ESCADA + 0.9


func _montar_dentro() -> void:
	_montar_janela()
	_montar_escada_de_dentro()
	_montar_moveis()


func _forro() -> Material:
	return _tabua(Color("7a5a3a"))


# --- a escadaria de fora --------------------------------------------------------------

## A soleira do casarão: o chão do salão atravessa a parede, e do outro lado vêm a
## plataforma do pórtico, a escada de pedra (uma rampa) e as balaustradas dela.
func _montar_a_soleira() -> void:
	_caixa(Vector3(largura_da_porta + 0.4, 0.3, parede), Vector3(porta_x, -0.15, parede * 0.5), null, true, "Soleira")
	var cara_da_fachada := parede + fundo_da_porta
	var altura := maxf(altura_da_soleira, 0.2)
	# A plataforma: o topo à altura do chão do salão, do vão ao começo da escada.
	var fundo_da_plataforma := PLATAFORMA + 0.2
	_caixa(Vector3(LARGURA_DA_PLATAFORMA, altura + 0.3, fundo_da_plataforma),
		Vector3(porta_x, -(altura + 0.3) * 0.5, cara_da_fachada - 0.2 + fundo_da_plataforma * 0.5), null, true, "Plataforma")
	# A escada: uma rampa do fim da plataforma até o chão, passando rente às quinas dos degraus.
	var topo := Vector2(cara_da_fachada + PLATAFORMA, 0.0)
	var pe := Vector2(cara_da_fachada + PLATAFORMA + ESCADA + 0.35, -altura)
	_rampa("EscadaDePedra", LARGURA_DA_ESCADA, topo, pe)
	# As balaustradas dos dois lados dela (o desenho as tem; a colisão as acompanha).
	for lado in [-1.0, 1.0]:
		_caixa(Vector3(0.5, altura + 0.5, ESCADA + 0.3),
			Vector3(porta_x + lado * (LARGURA_DA_ESCADA * 0.5 + 0.25), -altura + (altura + 0.5) * 0.5, topo.x + (ESCADA + 0.3) * 0.5),
			null, true, "Balaustrada")


# --- a escada para o andar de cima -------------------------------------------------

## A escada do fundo, cenário: os degraus de tábua, um bloco que a segura (o corpo bate
## nela, e não sobe até o forro), e o chão que ela ocupa, para os móveis não a tomarem.
func _montar_escada_de_dentro() -> void:
	var alto := minf(pe_direito - 0.3, 3.0)
	var passo := ESCADA_DE_DENTRO.y / float(DEGRAUS)
	var madeira := _tabua(Color("8a5f3a"))
	for i in DEGRAUS:
		var h := alto * float(i + 1) / float(DEGRAUS)
		var z := -comprimento + ESCADA_DE_DENTRO.y - (float(i) + 0.5) * passo
		_caixa(Vector3(ESCADA_DE_DENTRO.x, h, passo), Vector3(0.0, h * 0.5, z), madeira, false, "Degrau")
	_caixa(Vector3(ESCADA_DE_DENTRO.x, pe_direito, ESCADA_DE_DENTRO.y), Vector3(0.0, pe_direito * 0.5, -comprimento + ESCADA_DE_DENTRO.y * 0.5),
		null, true, "BlocoDaEscada")
	# O corrimão, de um lado e do outro.
	for lado in [-1.0, 1.0]:
		_caixa(Vector3(0.08, 0.9, ESCADA_DE_DENTRO.y), Vector3(lado * (ESCADA_DE_DENTRO.x * 0.5 + 0.04), alto * 0.5 + 0.2, -comprimento + ESCADA_DE_DENTRO.y * 0.5),
			_cor(MADEIRA), false, "Corrimao")


## Só a entrada fica livre: o salão é um vão só, e quem anda nele contorna a mesa.
func _reservar_a_passagem() -> void:
	_reservado.clear()
	_tomado.clear()
	var meia := largura_da_porta * 0.5 + 0.45
	_reservado.append(Rect2(porta_x - meia, -ENTRADA - 0.8, meia * 2.0, ENTRADA + 0.8))
	_tomado.append(Rect2(-ESCADA_DE_DENTRO.x * 0.5 - 0.1, -comprimento, ESCADA_DE_DENTRO.x + 0.2, ESCADA_DE_DENTRO.y + 0.2))


# --- as janelas -------------------------------------------------------------------------

## Duas janelas na fachada, uma de cada lado da porta, e duas no fundo.
func _montar_janela() -> void:
	var y := minf(1.55, pe_direito - 0.8)
	for x in [-2.6, 2.6]:
		if absf(x - porta_x) > largura_da_porta * 0.5 + 0.9 and absf(x) < largura * 0.5 - 0.8:
			_janela(Vector3(x, y, -0.04), Vector3(0, 0, -1), 0.85, 0.95)
	for x in [-3.2, 3.2]:
		if absf(x) < largura * 0.5 - 0.8:
			_janela(Vector3(x, y, -comprimento + 0.04), Vector3(0, 0, 1), 0.85, 0.95)
