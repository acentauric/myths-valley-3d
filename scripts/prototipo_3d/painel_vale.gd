extends CanvasLayer
## O PAINEL (tecla J) no vale: missões, cartas, obras, oficina, cozinha, venda e
## o menu do jogo. É o `scripts/ui/painel.gd` do 2D trazido para cá (#19).
##
## É CÓPIA ADAPTADA, e não arquivo compartilhado, e a razão é a mesma que
## deixou o painel fora da lista do `testar_compartilhado`: ele conversa com o
## que o 2D tem e o vale não — o `Telas` (quem abre e fecha a tela), o
## `SlotsTela` (a vaga ao salvar), o `Terrenos` e o `Povoado` (a aba de
## trabalho), o `Dialogo`. Interface não é regra: a REGRA de cada aba continua
## nos autoloads compartilhados (`Missoes`, `Cartas`, `Obras`, `Oficina`,
## `Cozinha`, `Venda`, `Receitas`), e é ela que este painel chama.
##
## O QUE MUDOU DO 2D PARA CÁ:
##
## - A MEDIDA E A CARA são as do HUD do vale: a tela aqui é 1280×720, e o
##   painel do 2D, de 640×360, sairia com letra de rodapé.
## - AS TECLAS são as do vale: J abre e fecha, Tab troca de aba, W/S ou as
##   setas escolhem, A/D andam entre abas (na venda, A vende), E confirma, Esc
##   fecha. O mouse vale para tudo, como no 2D.
## - O RELÓGIO QUE PARA é o `Dia` (no 2D, o `Relogio`): no vale é ele quem
##   manda na hora. O mundo não para — o bicho, porém, não caça quem está com
##   o painel aberto (ver criatura_vale.gd), e a peçonha não corre em quem lê.
## - A ABA DE TRABALHO NÃO EXISTE AINDA: ela é do `Terrenos` e do `Povoado`,
##   que não atravessaram (#9, #13).
## - A ABA "JOGO" não pergunta a vaga: no vale ela foi escolhida na abertura
##   (#7). E a porta dela é o botão JOGO do canto do painel, e não o Esc — no
##   vale o Esc é da câmera. Continua fora do giro das setas, pela razão do 2D:
##   quem lê a checklist não pode encostar no botão de fechar o jogo.

signal abriu
signal fechou
## O painel não conhece o mundo; ele avisa e quem sabe fazer resolve.
signal pediu(acao: String)

const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")
const Identidade = preload("res://scripts/prototipo_3d/identidade.gd")
const BancadasVale = preload("res://scripts/prototipo_3d/bancadas_vale.gd")

const COR_TITULO := Color("d6ba78")
const COR_TEXTO := Color("e8e4d7")
const COR_APAGADA := Color("aebaae")
const COR_CURSOR := Color("f2d27a")
const COR_FIXADA := Color("9fd89a")
const COR_FUNDO := Color(0.055, 0.085, 0.075, 0.96)
const COR_BORDA := Color(0.84, 0.73, 0.47, 0.8)

enum Aba { MISSOES, CARTAS, OBRAS, OFICINA, COZINHA, VENDA, TRABALHO, AJUSTES, SAVEIRO }
const NOME_DA_ABA := ["Missões", "Cartas", "Obras", "Oficina", "Cozinha", "Venda", "Trabalho", "Jogo", "Saveiro"]
const ICONES_DO_PAINEL := {
	"obra": preload("res://assets/sprites/icones/obra.png"),
	"folego": preload("res://assets/sprites/icones/folego.png"),
	"saveiro": preload("res://assets/sprites/icones/saveiro.png"),
	"pacto": preload("res://assets/sprites/icones/pacto.png"),
	"apoio": preload("res://assets/sprites/icones/apoio.png"),
	"ritual": preload("res://assets/sprites/icones/ritual.png"),
}

## Maior que a do 2D desde que a aba de missões virou DIÁRIO, com a lista e a
## página da missão lado a lado: cabe em 1280×720 com folga de 100 e de 50.
const TAMANHO := Vector2(1080, 620)
## A largura da lista de missões, à esquerda do diário.
const LARGURA_DA_LISTA_DE_MISSOES := 300.0
## Largura da coluna das abas, à esquerda. A mesma proporção do almanaque.
const LARGURA_DAS_ABAS := 230.0
const ALTURA_DA_LINHA := 28.0
const LETRA_TITULO := 22
const LETRA_ABAS := 15
const LETRA_LINHA := 16
const LETRA_DICA := 14

## Campos editáveis da aba do jogo: rótulo, campo em Progressao, passo.
const CAMPOS := [
	{"rotulo": "Fôlego máximo", "campo": "energia_maxima", "passo": 10.0,
		"dica": "O teto. Subir isto sozinho não faz acordar com mais."},
	{"rotulo": "Sono devolve", "campo": "recuperacao_ao_dormir", "passo": 5.0,
		"dica": "Pontos fixos por noite, não fração do máximo."},
	{"rotulo": "Desmaio devolve", "campo": "recuperacao_ao_desmaiar", "passo": 5.0,
		"dica": "Sempre menos que a cama. Apagar no chão não descansa."},
	{"rotulo": "Eficiência", "campo": "eficiencia", "passo": 0.05,
		"dica": "Multiplica o custo de toda ação. Menor é melhor."},
]

## AS AÇÕES DA ABA "JOGO", na ordem em que o jogador as procura (ver o 2D).
## `sinal` vazio: o painel resolve. `confirma`: pede um segundo E.
const ACOES := [
	{"rotulo": "Salvar agora", "acao": "salvar",
		"dica": "Guarda a partida na vaga em que ela está. O vale também salva quando você cai, volta ao menu ou fecha o jogo."},
	{"rotulo": "Salvar e voltar à tela inicial", "acao": "menu", "confirma": true,
		"dica": "Guarda a partida e volta ao menu. Você retoma daqui pela mesma vaga, em JOGAR."},
	{"rotulo": "Salvar e sair do jogo", "acao": "sair", "confirma": true,
		"dica": "Guarda a partida e fecha o jogo."},
	{"rotulo": "Destravar o boneco", "acao": "destravar",
		"dica": "Tira você de onde estiver preso e põe na última terra firme por onde passou."},
]

var aberto: bool = false

## A obra sob a mão do jogador ("oficina", "canteiro", "casa"...). Vazio = a
## aba de obras não aparece. Quem liga isto é o vale (ver bancadas_vale.gd).
var obra_em_foco: String = ""
## No balcão da venda.
var na_venda: bool = false
## Perto do mestre Quirino, no dia do saveiro: o `SaveiroVale`, ou null. Com
## ele, a aba do saveiro, onde ele compra o que se produziu no mês.
var saveiro: Node = null
## De frente para o fogão da própria casa.
var na_cozinha: bool = false

var _aba: int = Aba.MISSOES
var _cursor: int = 0
## O índice da ação que está pedindo confirmação, ou -1 (ver o 2D).
var _confirmando: int = -1
## O retorno da última ação do jogo ("Partida guardada..."), que fica na dica
## até o cursor andar. Salvar é ação em que nada muda na tela (ver o 2D).
var _aviso := ""

var _titulo: Label
## A coluna das abas, à esquerda, como as seções do almanaque.
var _abas_coluna: VBoxContainer
var _rolagem: ScrollContainer
var _lista: VBoxContainer
## Só as linhas ESCOLHÍVEIS, na ordem do cursor (ver o 2D).
var _escolhiveis: Array = []
var _dica: Label
## O estúdio dos retratos 3D (retratos_3d.gd), posto pelo vale: o diário mostra
## o rosto de quem deu a missão, como o Witcher mostra o de quem a pediu.
var retratos: Node = null
## O diário da aba de missões: a página da missão escolhida, à direita da lista.
var _diario: ScrollContainer
var _detalhe: VBoxContainer
var _rodape: Label
var _linhas: Array = []
var _botao_jogo: Button


func _ready() -> void:
	# Acima do HUD (20) e abaixo da tela da queda (30): o painel cobre a coluna
	# de botões do canto, e o fundo segura o clique para ele não cair no mundo.
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar()
	visible = false
	if retratos != null:
		retratos.pronto.connect(func(_id: String, _foto: Texture2D) -> void: _redesenhar())
	CadernoDoVale.mudou.connect(_redesenhar)
	Progressao.mudou.connect(_redesenhar)
	Inventario.mudou.connect(_redesenhar)


## `obra_pedida`: na aba de obras, o cursor já cai nesta obra — a que a missão
## manda fazer — em vez de na primeira da lista. Com o poço, a ponte e o mirante
## o cursor no lugar certo é a diferença entre "E, E" e procurar a obra com W/S.
func abrir(aba: int = Aba.MISSOES, obra_pedida: String = "") -> void:
	if aberto:
		return
	aberto = true
	_aba = aba
	_cursor = 0
	if aba == Aba.OBRAS and obra_pedida != "":
		_cursor = maxi(Obras.disponiveis(obra_em_foco).find(obra_pedida), 0)
	_confirmando = -1
	_aviso = ""
	visible = true
	# O RELÓGIO NÃO É DAQUI. Quem para o vale e o relógio atrás de qualquer tela
	# é o dono das telas (`telas_do_vale.gd` e `Prototype._pause_valley`). Este
	# painel também parava, e pelas duas mãos o relógio ficava parado para
	# sempre: o painel parava primeiro, o dono das telas guardava "já estava
	# parado", e ao fechar o painel devolvia "andando" e o dono, logo depois,
	# "parado". "Consegui parar o relógio sem mexer nas configurações" — era
	# abrir e fechar o J.
	abriu.emit()
	_redesenhar()


func mostrando_missoes() -> bool:
	return aberto and _aba == Aba.MISSOES


func fechar() -> void:
	if not aberto:
		return
	aberto = false
	visible = false
	fechou.emit()


func _unhandled_input(evento: InputEvent) -> void:
	if not aberto:
		return
	if not (evento is InputEventKey and evento.pressed and not evento.echo):
		return
	var tecla: int = evento.physical_keycode
	if tecla == KEY_ESCAPE or tecla == Atalhos.tecla("painel"):
		fechar()
	elif tecla == KEY_TAB:
		_proxima_aba(-1 if evento.shift_pressed else 1)
	elif evento.is_action_pressed("mv_forward"):
		_mover(-1)
	elif evento.is_action_pressed("mv_back"):
		_mover(1)
	elif evento.is_action_pressed("mv_left"):
		_ajustar(-1)
	elif evento.is_action_pressed("mv_right"):
		_ajustar(1)
	elif tecla == Atalhos.tecla("interagir") or tecla == KEY_ENTER or tecla == KEY_KP_ENTER or tecla == KEY_SPACE:
		_confirmar()
	else:
		return
	get_viewport().set_input_as_handled()


## Abas que fazem sentido agora. Obras, oficina, cozinha e venda só existem com
## o jogador no lugar certo — menu com aba morta é menu que ensina a ignorar
## menu. A aba do jogo é sozinha: aberta, é a única da lista (ver o 2D).
func abas_validas() -> Array:
	if _aba == Aba.AJUSTES:
		return [Aba.AJUSTES]
	var lista: Array = [Aba.MISSOES]
	if not Cartas.sabidas.is_empty():
		lista.append(Aba.CARTAS)
	if obra_em_foco == "oficina":
		lista.append(Aba.OFICINA)
	if obra_em_foco != "":
		lista.append(Aba.OBRAS)
	if na_cozinha:
		lista.append(Aba.COZINHA)
	if na_venda:
		lista.append(Aba.VENDA)
	if saveiro != null:
		lista.append(Aba.SAVEIRO)
	return lista


func _proxima_aba(sentido: int = 1) -> void:
	var validas := abas_validas()
	var onde := validas.find(_aba)
	_aba = validas[wrapi(onde + sentido, 0, validas.size())]
	_cursor = 0
	_confirmando = -1
	_aviso = ""
	Audio.efeito("menu_mover")
	_redesenhar()


func aba() -> int:
	return _aba


func _lista_atual() -> Array:
	match _aba:
		Aba.MISSOES: return CadernoDoVale.por_importancia()
		Aba.CARTAS: return Cartas.minhas()
		Aba.OBRAS: return Obras.disponiveis(obra_em_foco)
		Aba.OFICINA: return Oficina.receitas()
		Aba.COZINHA: return Cozinha.receitas()
		Aba.VENDA: return o_que_o_balcao_tem()
		Aba.SAVEIRO: return saveiro.o_que_compra() if saveiro != null else []
		_: return ACOES + CAMPOS


func escolher(indice: int) -> void:
	var total := _lista_atual().size()
	if total == 0:
		return
	_confirmando = -1
	_aviso = ""
	_cursor = clampi(indice, 0, total - 1)
	_redesenhar()


func _mover(passo: int) -> void:
	var total := _lista_atual().size()
	if total == 0:
		return
	_confirmando = -1
	_aviso = ""
	_cursor = wrapi(_cursor + passo, 0, total)
	Audio.efeito("menu_mover")
	_redesenhar()


## No jogo, esquerda e direita mexem no valor. Na venda, a esquerda vende. Nas
## outras abas, andam entre abas — COM O SENTIDO (ver o 2D).
func _ajustar(sentido: int) -> void:
	if _aba == Aba.AJUSTES:
		var onde := _cursor - ACOES.size()
		if onde < 0 or onde >= CAMPOS.size():
			return
		var campo: Dictionary = CAMPOS[onde]
		var atual: float = Progressao.get(campo["campo"])
		Progressao.ajustar(campo["campo"], atual + campo["passo"] * sentido)
		Audio.efeito("menu_mover")
		return
	if _aba == Aba.VENDA and sentido < 0:
		vender()
		return
	_proxima_aba(sentido)


func _confirmar() -> void:
	match _aba:
		Aba.MISSOES:
			if _cursor >= CadernoDoVale.ativas.size():
				return
			CadernoDoVale.fixar(str((CadernoDoVale.por_importancia()[_cursor] as Dictionary)["id"]))
		Aba.CARTAS:
			var minhas := Cartas.minhas()
			if _cursor >= minhas.size():
				return
			var carta := str(minhas[_cursor])
			match Cartas.natureza(carta):
				"pacto":
					# Firmar aqui e não só no lugar do mito: a primeira vez é
					# encontro, mas TROCAR de pacto não pode obrigar a atravessar
					# o mapa duas vezes (ver o 2D).
					if Cartas.pacto == carta:
						Cartas.desfazer()
					elif Cartas.firmar(carta) != "":
						return
				"ritual":
					if not Cartas.preparar(carta):
						return
				_:
					return
		Aba.OBRAS:
			var lista := Obras.disponiveis(obra_em_foco)
			if _cursor >= lista.size():
				return
			var obra := str(lista[_cursor])
			if not Obras.executar(obra_em_foco, obra):
				return
			pagar_o_que_a_obra_da(obra)
			# "Obra pronta", como no 2D (`Mundo._ao_concluir_obra`). Onde olhar
			# para ver a obra ainda não se diz: a casa do vale não muda por fora
			# nem por dentro até os modelos e o cômodo chegarem (#26, #27).
			_aviso = "Obra pronta: %s. %s" % [Obras.dados(obra).get("nome", obra), Obras.dados(obra).get("resumo", "")]
			_cursor = 0
		Aba.OFICINA:
			var receitas := Oficina.receitas()
			if _cursor >= receitas.size():
				return
			if not Oficina.fabricar(str(receitas[_cursor])):
				return
		Aba.COZINHA:
			var pratos := Cozinha.receitas()
			if _cursor >= pratos.size():
				return
			if not Cozinha.cozinhar(str(pratos[_cursor])):
				return
		Aba.VENDA:
			var lista := o_que_o_balcao_tem()
			if _cursor >= lista.size():
				return
			var receita := _receita_da_linha(str(lista[_cursor]))
			if receita != "":
				if not Receitas.comprar(receita):
					return
			elif not Venda.comprar(str(lista[_cursor])):
				return
		Aba.AJUSTES:
			if _cursor >= ACOES.size():
				return
			if not fazer_a_acao(ACOES[_cursor]):
				return
		Aba.SAVEIRO:
			# O MESTRE COMPRA UM, pelo preço dele; o porquê de não comprar vai
			# para a linha de aviso.
			var o_que: Array = saveiro.o_que_compra() if saveiro != null else []
			if _cursor >= o_que.size():
				return
			var motivo: String = saveiro.vender(str(o_que[_cursor]))
			if motivo != "":
				_aviso = motivo
				_redesenhar()
				return
			_aviso = ""
		_:
			return
	Audio.efeito("menu_confirma")
	_redesenhar()


## O BALCÃO VENDE MERCADORIA E VENDE PLANO (ver o 2D). O prefixo separa a
## receita do item de mesmo id — `pirao` é prato e é plano.
const PREFIXO_DA_RECEITA := "receita:"

func o_que_o_balcao_tem() -> Array:
	var lista: Array = Venda.mercadorias()
	for id in Receitas.a_venda():
		lista.append(PREFIXO_DA_RECEITA + str(id))
	return lista


func _receita_da_linha(linha: String) -> String:
	if not linha.begins_with(PREFIXO_DA_RECEITA):
		return ""
	return linha.substr(PREFIXO_DA_RECEITA.length())


func vender() -> void:
	var lista := o_que_o_balcao_tem()
	if _cursor >= lista.size():
		return
	# Receita não se vende de volta: o que se aprendeu não sai da cabeça.
	if _receita_da_linha(str(lista[_cursor])) != "":
		return
	if Venda.vender(str(lista[_cursor])):
		Audio.efeito("menu_confirma")
		_redesenhar()


## Executa a ação escolhida. Devolve false quando ela só PEDIU confirmação, ou
## quando não deu — aí o painel não toca o som de confirmado.
func fazer_a_acao(acao: Dictionary) -> bool:
	if bool(acao.get("confirma", false)) and _confirmando != _cursor:
		_confirmando = _cursor
		_redesenhar()
		return false
	_confirmando = -1
	var qual := str(acao.get("acao", ""))
	match qual:
		"salvar":
			# O aviso sai mesmo dando certo: salvar é ação em que nada muda na
			# tela, e ação sem retorno é a que se aperta três vezes (ver o 2D).
			if not Partida.tem_vaga():
				_aviso = "Este passeio não tem vaga, e por isso não salva. Para guardar a partida, escolha uma vaga em JOGAR."
			elif Partida.salvar():
				_aviso = "Partida guardada na vaga %d." % Salvamento.slot_atual
			else:
				_aviso = "Não consegui salvar. A partida que estava na vaga continua lá."
			_redesenhar()
			return false
		"menu", "sair", "destravar":
			fechar()
			pediu.emit(qual)
			return true
	return false


# --- montagem ----------------------------------------------------------------

func _montar() -> void:
	var fundo := ColorRect.new()
	fundo.color = Color(0.02, 0.03, 0.03, 0.72)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fundo)

	var caixa := PanelContainer.new()
	caixa.name = "Caixa"
	caixa.add_theme_stylebox_override("panel", _estilo_do_painel())
	caixa.set_anchors_preset(Control.PRESET_CENTER)
	caixa.grow_horizontal = Control.GROW_DIRECTION_BOTH
	caixa.grow_vertical = Control.GROW_DIRECTION_BOTH
	caixa.custom_minimum_size = TAMANHO
	caixa.offset_left = -TAMANHO.x * 0.5
	caixa.offset_right = TAMANHO.x * 0.5
	caixa.offset_top = -TAMANHO.y * 0.5
	caixa.offset_bottom = TAMANHO.y * 0.5
	add_child(caixa)
	# A MOLDURA DE TALHA do resto do vale, como no almanaque. Painel com borda
	# própria é painel que envelhece sozinho quando a identidade muda.
	Identidade.emoldurar(caixa)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 10)
	caixa.add_child(coluna)

	# O CAMINHO no alto, como no almanaque: "Painel › Missões". É o fio que diz
	# onde se está sem gastar uma linha de abas horizontais.
	var topo := HBoxContainer.new()
	coluna.add_child(topo)
	_titulo = Label.new()
	_titulo.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TITULO, 500, 2))
	_titulo.add_theme_font_size_override("font_size", 19)
	_titulo.add_theme_color_override("font_color", Identidade.OURO)
	_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Identidade.sombra_texto(_titulo)
	topo.add_child(_titulo)
	_botao_jogo = _botao_pequeno("JOGO", func(): _ir_para_o_jogo())
	_botao_jogo.tooltip_text = "Salvar, voltar ao menu, sair e os ajustes de teste"
	topo.add_child(_botao_jogo)
	var fechar_painel := _botao_pequeno("×", fechar)
	fechar_painel.name = "Fechar"
	topo.add_child(fechar_painel)
	coluna.add_child(Identidade.divisor())

	var lado_a_lado := HBoxContainer.new()
	lado_a_lado.add_theme_constant_override("separation", 22)
	lado_a_lado.size_flags_vertical = Control.SIZE_EXPAND_FILL
	coluna.add_child(lado_a_lado)

	# À ESQUERDA AS ABAS, EM COLUNA, como as seções do almanaque.
	#
	# Eram uma linha horizontal de "[ Missões ]  Cartas  Venda", que é legível
	# com duas abas e fica apertada com seis — e que não deixa lugar para dizer
	# quantas missões há em cada uma. Em coluna, cada aba tem a sua linha, a sua
	# marca de aberta (▾) e a sua conta.
	_abas_coluna = VBoxContainer.new()
	_abas_coluna.name = "Abas"
	_abas_coluna.add_theme_constant_override("separation", 2)
	_abas_coluna.custom_minimum_size = Vector2(LARGURA_DAS_ABAS, 0)
	lado_a_lado.add_child(_abas_coluna)

	var fio := VSeparator.new()
	lado_a_lado.add_child(fio)

	# À DIREITA A PÁGINA: a lista da aba, e embaixo dela a dica do que está no
	# cursor. É a mesma divisão do almanaque — índice de um lado, página do
	# outro — e é por isso que as duas telas passam a se parecer.
	var pagina := VBoxContainer.new()
	pagina.add_theme_constant_override("separation", 8)
	pagina.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pagina.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lado_a_lado.add_child(pagina)

	# A lista rola, com barra visível: barra é a informação de que a lista
	# continua (ver o 2D).
	_rolagem = ScrollContainer.new()
	_rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rolagem.follow_focus = true
	_rolagem.get_v_scroll_bar().add_theme_stylebox_override("scroll", _estilo_da_calha())
	_rolagem.get_v_scroll_bar().add_theme_stylebox_override("grabber", _estilo_do_puxador(false))
	_rolagem.get_v_scroll_bar().add_theme_stylebox_override("grabber_highlight", _estilo_do_puxador(true))
	_rolagem.get_v_scroll_bar().add_theme_stylebox_override("grabber_pressed", _estilo_do_puxador(true))
	# A lista e, na aba de missões, O DIÁRIO ao lado dela — como no Witcher: as
	# missões à esquerda, a escolhida aberta à direita (ver `_desenhar_missoes`).
	# Nas outras abas o diário some e a lista toma a largura toda.
	var corpo := HBoxContainer.new()
	corpo.add_theme_constant_override("separation", 18)
	corpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pagina.add_child(corpo)
	corpo.add_child(_rolagem)
	_diario = ScrollContainer.new()
	_diario.name = "Diario"
	_diario.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_diario.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_diario.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_diario.visible = false
	corpo.add_child(_diario)
	_detalhe = VBoxContainer.new()
	_detalhe.name = "Detalhe"
	_detalhe.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detalhe.add_theme_constant_override("separation", 8)
	_diario.add_child(_detalhe)

	_lista = VBoxContainer.new()
	_lista.add_theme_constant_override("separation", 3)
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rolagem.add_child(_lista)

	_dica = Label.new()
	_dica.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TEXTO, 400))
	_dica.add_theme_font_size_override("font_size", 18)
	_dica.add_theme_color_override("font_color", COR_TEXTO)
	_dica.add_theme_constant_override("line_spacing", 3)
	_dica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dica.custom_minimum_size = Vector2(0, 52)
	pagina.add_child(_dica)

	_rodape = _rotulo("", LETRA_DICA, COR_APAGADA)
	_rodape.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coluna.add_child(_rodape)


## A COLUNA DAS ABAS, refeita a cada redesenho.
##
## Refazer em vez de remendar, pela mesma razão do almanaque: a lista de abas
## válidas muda com o lugar onde o jogador está (a Venda só existe no balcão),
## e tela que se remenda guarda estado em dois lugares.
func _montar_abas() -> void:
	for filho in _abas_coluna.get_children():
		filho.queue_free()
	for qual in abas_validas():
		var aberta: bool = qual == _aba
		var linha := Button.new()
		linha.focus_mode = Control.FOCUS_NONE
		linha.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		linha.custom_minimum_size = Vector2(0, ALTURA_DA_LINHA + 4.0)
		linha.alignment = HORIZONTAL_ALIGNMENT_LEFT
		linha.text = ("▾ " if aberta else "▸ ") + str(NOME_DA_ABA[qual])
		var distintivo := _distintivo_da_aba(qual)
		if distintivo != "":
			var figura := _icone_distintivo(distintivo, 22.0)
			figura.set_anchors_preset(Control.PRESET_CENTER_LEFT)
			figura.position = Vector2(9.0, -11.0)
			figura.size = Vector2(22.0, 22.0)
			linha.add_child(figura)
		var conta := _conta_da_aba(qual)
		if conta != "":
			linha.text += "    " + conta
		linha.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TITULO, 600))
		linha.add_theme_font_size_override("font_size", 16)
		linha.add_theme_color_override("font_color", Identidade.OURO if aberta else COR_APAGADA)
		linha.add_theme_color_override("font_hover_color", Identidade.CREME)
		for estado in ["normal", "hover", "pressed"]:
			linha.add_theme_stylebox_override(estado, _estilo_da_aba(aberta, estado != "normal", distintivo != ""))
		linha.pressed.connect(func() -> void: _ir_para_aba(qual))
		_abas_coluna.add_child(linha)


## "3" ao lado do nome da aba: quantas coisas há nela agora. Sem conta, vazio —
## aba de ação (Jogo) não conta nada.
func _conta_da_aba(qual: int) -> String:
	match qual:
		Aba.MISSOES:
			return str(CadernoDoVale.ativas.size()) if not CadernoDoVale.ativas.is_empty() else ""
		Aba.CARTAS:
			return str(Cartas.sabidas.size()) if not Cartas.sabidas.is_empty() else ""
		_:
			return ""


func _distintivo_da_aba(qual: int) -> String:
	match qual:
		Aba.OBRAS:
			return "obra"
		Aba.SAVEIRO:
			return "saveiro"
		_:
			return ""


func _icone_distintivo(chave: String, lado: float = 22.0) -> TextureRect:
	if not ICONES_DO_PAINEL.has(chave):
		push_error("Distintivo sem asset no painel: " + chave)
		return null
	var figura := TextureRect.new()
	figura.name = "Icone_" + chave
	figura.texture = ICONES_DO_PAINEL[chave]
	figura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	figura.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	figura.custom_minimum_size = Vector2(lado, lado)
	figura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return figura


func _ir_para_aba(qual: int) -> void:
	if _aba == qual:
		return
	_aba = qual
	_cursor = 0
	_confirmando = -1
	_aviso = ""
	_redesenhar()


func _estilo_da_aba(aberta: bool, realce: bool, com_icone: bool = false) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	if aberta:
		estilo.bg_color = Color(0.19, 0.21, 0.15, 0.96)
		estilo.border_color = Color(Identidade.OURO.r, Identidade.OURO.g, Identidade.OURO.b, 0.75)
		estilo.border_width_left = 2
	elif realce:
		estilo.bg_color = Color(0.13, 0.16, 0.12, 0.9)
	else:
		estilo.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	estilo.content_margin_left = 38 if com_icone else 10
	estilo.content_margin_right = 10
	return estilo


func _ir_para_o_jogo() -> void:
	_aba = Aba.MISSOES if _aba == Aba.AJUSTES else Aba.AJUSTES
	_cursor = 0
	_confirmando = -1
	_aviso = ""
	Audio.efeito("menu_mover")
	_redesenhar()


func _rotulo(texto: String, tamanho: int, cor: Color) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.add_theme_font_size_override("font_size", tamanho)
	etiqueta.add_theme_color_override("font_color", cor)
	return etiqueta


func _estilo_do_painel() -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = COR_FUNDO
	estilo.border_color = COR_BORDA
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(10)
	estilo.set_content_margin_all(18)
	return estilo


func _redesenhar() -> void:
	if not aberto:
		return
	for linha in _linhas:
		linha.queue_free()
	_linhas.clear()
	_escolhiveis.clear()

	_montar_abas()
	_titulo.text = "Painel  ›  %s" % str(NOME_DA_ABA[_aba])
	_botao_jogo.text = "‹ VOLTAR" if _aba == Aba.AJUSTES else "JOGO"
	# O diário só existe na aba de missões; nela a lista estreita e a dica de
	# baixo some, porque o diário é a dica, inteira.
	var no_diario := _aba == Aba.MISSOES
	_diario.visible = no_diario
	_dica.visible = not no_diario
	_rolagem.size_flags_horizontal = Control.SIZE_FILL if no_diario else Control.SIZE_EXPAND_FILL
	_rolagem.custom_minimum_size.x = LARGURA_DA_LISTA_DE_MISSOES if no_diario else 0.0
	for filho in _detalhe.get_children():
		_detalhe.remove_child(filho)
		filho.queue_free()

	match _aba:
		Aba.MISSOES: _desenhar_missoes()
		Aba.CARTAS: _desenhar_cartas()
		Aba.OBRAS: _desenhar_obras()
		Aba.OFICINA: _desenhar_oficina()
		Aba.COZINHA: _desenhar_cozinha()
		Aba.VENDA: _desenhar_venda()
		Aba.SAVEIRO: _desenhar_saveiro()
		_: _desenhar_ajustes()

	_rolar_ate_o_cursor()


func _rolar_ate_o_cursor() -> void:
	if _cursor < 0 or _cursor >= _escolhiveis.size():
		return
	var alvo: Control = _escolhiveis[_cursor]
	await get_tree().process_frame
	if is_instance_valid(alvo) and is_instance_valid(_rolagem):
		_rolagem.ensure_control_visible(alvo)


## O pé da bancada: quantas receitas ela ainda tem para ensinar (ver o 2D).
func _quantas_faltam(todas: Array) -> String:
	var faltam := Receitas.quantas_faltam(todas)
	if faltam <= 0:
		return ""
	return "\nFalta%s aprender %d %s: quem vive aqui ensina, e o balcão vende plano." % [
		"" if faltam == 1 else "m", faltam, "receita" if faltam == 1 else "receitas"]


func _desenhar_cozinha() -> void:
	_titulo.text = "Fogão      %s %d/%d" % [Energia.nome_recurso(), int(Energia.atual), int(Energia.maximo())]
	var pratos := Cozinha.receitas()
	if pratos.is_empty():
		_adicionar_linha("Você ainda não sabe cozinhar nada.", COR_APAGADA)
		_dica.text = "Receita se aprende." + _quantas_faltam(Cozinha.RECEITAS.keys())
		_rodape.text = "[Tab] outra aba · [Esc] fechar"
		return
	for i in pratos.size():
		var id := str(pratos[i])
		var pode := Cozinha.pode(id)
		var devolve := int(Catalogo.dados(id).get("folego", 0.0))
		var texto := "%s   %-22s %s" % [
			"✓" if pode else "·", Cozinha.dados(id).get("nome", id),
			"+%d de %s" % [devolve, Energia.nome_recurso()] if devolve > 0 else "ingrediente"]
		_adicionar_linha(texto, COR_CURSOR if i == _cursor else (COR_TEXTO if pode else COR_APAGADA))
	var escolhido := str(pratos[_cursor]) if _cursor < pratos.size() else ""
	var impede := Cozinha.impedimento(escolhido)
	_dica.text = str(Cozinha.dados(escolhido).get("resumo", "")) + "\n" + (
		impede if impede != "" else "Gasta: %s   ·   e %d de %s pra fazer" % [
			Cozinha.custo_em_texto(escolhido), int(Cozinha.dados(escolhido).get("folego", 0)), Energia.nome_recurso()]
		) + _quantas_faltam(Cozinha.RECEITAS.keys())
	_rodape.text = "[W/S] escolher · [E] cozinhar · [Esc] fechar"


## As cartas, agrupadas pelo que são: cada natureza se usa de um jeito.
const CABECALHO_DA_NATUREZA := {
	"pacto": "PACTOS — um de cada vez, e ele cobra todo dia",
	"apoio": "APOIOS — uma vez por dia, na tecla R",
	"ritual": "RITUAIS — preparados no oratório, com o que você planta",
}

func _desenhar_cartas() -> void:
	_titulo.text = "Cartas"
	var todas := Cartas.minhas()
	var natureza_atual := ""
	for i in todas.size():
		var id := str(todas[i])
		var qual := Cartas.natureza(id)
		if qual != natureza_atual:
			natureza_atual = qual
			_adicionar_linha(str(CABECALHO_DA_NATUREZA.get(qual, qual.to_upper())), COR_APAGADA, true, qual)
		var marca := "·"
		var cor := COR_TEXTO
		match qual:
			"pacto":
				if Cartas.pacto == id:
					marca = "◆"
					cor = COR_FIXADA
			"apoio":
				if Cartas.apoio_pronto(id):
					marca = "✓"
				else:
					cor = COR_APAGADA
			"ritual":
				if Cartas.impedimento(id) == "":
					marca = "✓"
				else:
					cor = COR_APAGADA
		if i == _cursor:
			cor = COR_CURSOR
		_adicionar_linha("  %s  %s" % [marca, Cartas.nome(id)], cor)
	if todas.is_empty():
		_adicionar_linha("Você ainda não tem carta nenhuma.", COR_APAGADA, true)
		_rodape.text = "[Tab] outra aba · [Esc] fechar"
		return
	var escolhida := str(todas[_cursor]) if _cursor < todas.size() else ""
	var dado := Cartas.dados(escolhida)
	var linhas: Array = [str(dado.get("resumo", ""))]
	match Cartas.natureza(escolhida):
		"pacto":
			var conta: Array = []
			for item in dado.get("cobra", {}):
				conta.append("%d %s" % [int(dado["cobra"][item]), Catalogo.nome(str(item)).to_lower()])
			linhas.append("Cobra todo dia: %s." % ", ".join(conta))
			if Cartas.pacto == escolhida and not Cartas.em_dia():
				linhas.append("HOJE NÃO FOI PAGO, e por isso o ganho não vale.")
			_rodape.text = "[E] %s · [Tab] outra aba · [Esc] fechar" % (
				"desfazer o pacto" if Cartas.pacto == escolhida else "firmar o pacto")
		"apoio":
			linhas.append("Pronta para usar no R." if Cartas.apoio_pronto(escolhida)
				else "Já usada hoje. Amanhã serve de novo.")
			_rodape.text = "[Tab] outra aba · [Esc] fechar"
		"ritual":
			var custo: Array = []
			for item in dado.get("custo", {}):
				custo.append("%d %s" % [int(dado["custo"][item]), Catalogo.nome(str(item)).to_lower()])
			linhas.append("Custa: %s." % ", ".join(custo))
			var impede := Cartas.impedimento(escolhida)
			if impede != "":
				linhas.append(impede)
			_rodape.text = "[E] preparar · [Tab] outra aba · [Esc] fechar"
	_dica.text = "\n".join(linhas)


func _desenhar_oficina() -> void:
	_titulo.text = "Oficina      lenha %d · tábua %d · corda %d" % [
		Inventario.quantidade("lenha"), Inventario.quantidade("tabua"), Inventario.quantidade("corda")]
	var receitas := Oficina.receitas()
	if receitas.is_empty():
		_adicionar_linha("Você ainda não sabe fabricar nada.", COR_APAGADA)
		_dica.text = "Receita se aprende." + _quantas_faltam(Oficina.RECEITAS.keys())
		_rodape.text = "[Tab] outra aba · [Esc] fechar"
		return
	for i in receitas.size():
		var id := str(receitas[i])
		var pode := Oficina.pode(id)
		var cor := COR_CURSOR if i == _cursor else (COR_TEXTO if pode else COR_APAGADA)
		_adicionar_linha("%s   %s" % ["✓" if pode else "·", Oficina.dados(id).get("nome", id)], cor)
	var escolhida := str(receitas[_cursor]) if _cursor < receitas.size() else ""
	var impede := Oficina.impedimento(escolhida)
	_dica.text = str(Oficina.dados(escolhida).get("resumo", "")) + "\n" + (
		impede if impede != "" else "Gasta: %s   ·   rende %d" % [
			Oficina.custo_em_texto(escolhida), Oficina.rende(escolhida)]
		) + _quantas_faltam(Oficina.RECEITAS.keys())
	_rodape.text = "[W/S] escolher · [E] fabricar · [Tab] outra aba · [Esc] fechar"


## A ABA DE MISSÕES LÊ O CADERNO DO VALE, e não o `Missoes` do 2D.
##
## Ela lia o compartilhado, com a checklist de itens daquele autoload. Mudou por
## pedido do autor, e a razão é de projeto: o 3D tem de ter o mecanismo dele,
## sem depender do checklist de lá, porque missão nova aqui pode ter padrão,
## formato e ordem diferentes. Ver `caderno_do_vale.gd`.
##
## O que se perde na troca é a CHECKLIST — e é de propósito. Uma missão do vale
## tem UMA LINHA de andamento, escrita por quem conduz ("Juntar lenha: 1 de 2",
## "Levar pirão de peixe a Tonho"). Quem conduz decide a frase; esta tela não
## tenta entender de que tipo é a meta, e por isso meta nova não pede linha nova
## aqui.
##
##
## OS ÍCONES DA RECOMPENSA (#107): os réis e o XP não são itens do catálogo;
## os desenhos deles vêm de `assets/sprites/icones/` (gerados por imagem, ver o
## ORIGEM.md de lá). Os itens usam o ícone do catálogo, o mesmo da barra de mão.
const ICONE_DOS_REIS := "res://assets/sprites/icones/reis.png"
const ICONE_DO_XP := "res://assets/sprites/icones/xp.png"


func _icone_da_recompensa(chave: String) -> Texture2D:
	match chave:
		"reis":
			return load(ICONE_DOS_REIS) as Texture2D if ResourceLoader.exists(ICONE_DOS_REIS) else null
		"xp":
			return load(ICONE_DO_XP) as Texture2D if ResourceLoader.exists(ICONE_DO_XP) else null
		_:
			return Catalogo.icone(chave)


func _nome_da_recompensa(chave: String, quanto: int) -> String:
	match chave:
		"reis":
			return tr("%d réis") % quanto
		"xp":
			return "%d XP" % quanto
		_:
			return "×%d  %s" % [quanto, str(Catalogo.ITENS.get(chave, {}).get("nome", chave))]


## O DIÁRIO, COMO NO WITCHER
##
## "No MENU J, de missões, eu tô clicando para trocar a missão de resumo, mas
## não muda. O comportamento tem que ser muito próximo de jogos de RPG como The
## Witcher 3." O diário de lá tem a lista à esquerda, agrupada, com a marca da
## missão acompanhada; a escolhida aberta à direita — nome, quem deu, o texto,
## os objetivos com os cumpridos riscados — e o botão de acompanhar. Acompanhar
## é o que muda o canto da tela e o marcador; escolher na lista só abre a página.
##
## Aqui é o mesmo: W/S ou o clique escolhem; E, o segundo clique na mesma linha
## ou o botão ACOMPANHAR acompanham (`CadernoDoVale.fixar`). O HUD, a seta e a
## bússola seguem o caderno, e por isso mudam juntos (ver `_mostrar_a_acompanhada`
## no `prototype.gd`).
func _desenhar_missoes() -> void:
	_titulo.text = "Diário  ›  Missões"
	var abertas: Array = CadernoDoVale.por_importancia()
	if abertas.is_empty():
		_adicionar_linha("Nada em aberto por enquanto.", COR_APAGADA)
		_detalhe.add_child(_texto_do_diario(
			"Fale com quem mora no vale: quem tem o que pedir, pede.", 17, COR_APAGADA))
		_rodape.text = "[Esc] fechar"
		return
	# Dois grupos, com cabeçalho: enredo e dia a dia se leem diferente (ver o 2D).
	var grupo := ""
	for i in abertas.size():
		var missao: Dictionary = abertas[i]
		var qual := "ENREDO" if bool(missao.get("principal", false)) else "DO DIA A DIA"
		if qual != grupo:
			grupo = qual
			_adicionar_linha(qual, COR_APAGADA, true)
		var id := str(missao.get("id", ""))
		var acompanhada := CadernoDoVale.acompanhada(id)
		# ◆ cheio é a acompanhada, como o losango do Witcher; ◇ as outras.
		var marca := "◆" if acompanhada else "◇"
		var cor := COR_CURSOR if i == _cursor else (COR_FIXADA if acompanhada else COR_TEXTO)
		_adicionar_linha("%s  %s" % [marca, _nome_da_missao(missao)], cor)
	var escolhida: Dictionary = abertas[clampi(_cursor, 0, abertas.size() - 1)]
	_desenhar_o_diario(escolhida)
	_rodape.text = "[W/S] escolher · [E] acompanhar · [Esc] fechar"


func _nome_da_missao(missao: Dictionary) -> String:
	var nome := str(missao.get("missao", ""))
	return nome if nome != "" else str(missao.get("titulo", ""))


## A PÁGINA DA MISSÃO ESCOLHIDA, à direita da lista.
##
## O TEXTO COMPLETO MORA AQUI. O HUD mostra só o resumo ("Corte o capim com a
## foice (2/4)"); a fala inteira de quem pediu — o porquê, o lugar, o tom — é
## lida no diário. E os objetivos vêm como no Witcher: os cumpridos riscados em
## cinza, o de agora aceso, com a barra quando há conta.
func _desenhar_o_diario(missao: Dictionary) -> void:
	var id := str(missao.get("id", ""))
	var acompanhada := CadernoDoVale.acompanhada(id)

	# O ROSTO DE QUEM DEU A MISSÃO, ao lado do nome dela, quando o estúdio já
	# tirou a foto (`retratos_3d.gd`). Sem foto, o nome sozinho.
	var topo := HBoxContainer.new()
	topo.add_theme_constant_override("separation", 14)
	_detalhe.add_child(topo)
	var foto: Texture2D = retratos.textura(str(missao.get("dono", ""))) if retratos != null else null
	if foto != null:
		var moldura := PanelContainer.new()
		var estilo_moldura := StyleBoxFlat.new()
		estilo_moldura.bg_color = Color(0.09, 0.12, 0.10, 0.95)
		estilo_moldura.border_color = Color(Identidade.OURO.r, Identidade.OURO.g, Identidade.OURO.b, 0.6)
		estilo_moldura.set_border_width_all(1)
		estilo_moldura.set_corner_radius_all(4)
		estilo_moldura.set_content_margin_all(3)
		moldura.add_theme_stylebox_override("panel", estilo_moldura)
		var rosto := TextureRect.new()
		rosto.name = "RostoDeQuemDeu"
		rosto.texture = foto
		rosto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rosto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rosto.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		rosto.custom_minimum_size = Vector2(72, 72)
		moldura.add_child(rosto)
		topo.add_child(moldura)
	var nome := Label.new()
	nome.name = "NomeDaMissao"
	nome.text = _nome_da_missao(missao)
	nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nome.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nome.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TITULO, 600, 1))
	nome.add_theme_font_size_override("font_size", 24)
	nome.add_theme_color_override("font_color", Identidade.CREME)
	Identidade.sombra_texto(nome)
	topo.add_child(nome)

	var tipo := "◆ Enredo" if bool(missao.get("principal", false)) else "◇ Do dia a dia"
	var quem := str(missao.get("quem", ""))
	var linha_de_quem := tipo if quem == "" else "%s  ·  dada por %s" % [tipo, quem]
	var passo := int(missao.get("passo", 0))
	var passos := int(missao.get("passos", 0))
	if passo > 0 and passos > 0:
		linha_de_quem += "  ·  passo %d de %d" % [passo, passos]
	var sub := _texto_do_diario(linha_de_quem, 15, Identidade.OURO)
	sub.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_ITALICO, 400))
	_detalhe.add_child(sub)

	var filete := Identidade.filete_centrado(1.0)
	filete.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detalhe.add_child(filete)

	# A FALA DE QUEM PEDIU, inteira. O caderno a guarda com o nome na frente
	# ("Damião: O senhor subiu..."); aqui o nome já está em cima, e a fala vem
	# como citação.
	var fala := str(missao.get("texto", ""))
	if quem != "" and fala.begins_with(quem + ": "):
		fala = fala.substr(quem.length() + 2)
	if fala != "":
		var citacao := _texto_do_diario("“%s”" % fala, 17, COR_TEXTO)
		citacao.name = "Fala"
		citacao.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_ITALICO, 400))
		_detalhe.add_child(citacao)

	var objetivos := _texto_do_diario("OBJETIVOS", 13, Identidade.OURO)
	objetivos.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TEXTO, 600))
	_detalhe.add_child(objetivos)
	for feito in missao.get("feitos", []):
		var riscado := _texto_do_diario("✓  %s" % str(feito), 15, COR_APAGADA)
		riscado.name = "Feito"
		_detalhe.add_child(riscado)
	var agora := str(missao.get("resumo", ""))
	if agora == "":
		agora = str(missao.get("linha", missao.get("titulo", "")))
	var objetivo := _texto_do_diario("◆  %s" % agora, 16, COR_CURSOR if acompanhada else COR_TEXTO)
	objetivo.name = "ObjetivoDeAgora"
	_detalhe.add_child(objetivo)
	var total := int(missao.get("total", 0))
	if total > 0:
		var barra := ProgressBar.new()
		barra.name = "Andamento"
		barra.show_percentage = false
		barra.custom_minimum_size = Vector2(0, 10)
		barra.max_value = float(total)
		barra.value = float(int(missao.get("feito", 0)))
		var fundo := StyleBoxFlat.new()
		fundo.bg_color = Color(0.13, 0.16, 0.12, 0.9)
		fundo.border_color = Color(0.32, 0.35, 0.30, 0.9)
		fundo.set_border_width_all(1)
		fundo.set_corner_radius_all(3)
		var cheio := StyleBoxFlat.new()
		cheio.bg_color = COR_FIXADA
		cheio.set_corner_radius_all(3)
		barra.add_theme_stylebox_override("background", fundo)
		barra.add_theme_stylebox_override("fill", cheio)
		_detalhe.add_child(barra)

	# A RECOMPENSA DO PASSO (#107), em ícones: os itens com o ícone de cada um, os
	# réis e o XP com os deles (`assets/sprites/icones/`), e a conta ao lado.
	var recompensa: Dictionary = missao.get("recompensa", {})
	if not recompensa.is_empty():
		var titulo_da_recompensa := _texto_do_diario("RECOMPENSA", 13, Identidade.OURO)
		titulo_da_recompensa.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TEXTO, 600))
		_detalhe.add_child(titulo_da_recompensa)
		var linha_da_recompensa := HBoxContainer.new()
		linha_da_recompensa.name = "Recompensa"
		linha_da_recompensa.add_theme_constant_override("separation", 16)
		_detalhe.add_child(linha_da_recompensa)
		for chave in recompensa:
			var item := HBoxContainer.new()
			item.add_theme_constant_override("separation", 6)
			var icone := _icone_da_recompensa(str(chave))
			if icone != null:
				var figura := TextureRect.new()
				figura.name = "Icone_" + str(chave)
				figura.texture = icone
				figura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				figura.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				figura.custom_minimum_size = Vector2(28, 28)
				figura.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if str(chave) in ["reis", "xp"] else CanvasItem.TEXTURE_FILTER_NEAREST
				item.add_child(figura)
			var conta := _texto_do_diario(_nome_da_recompensa(str(chave), int(recompensa[chave])), 15, COR_TEXTO)
			conta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			item.add_child(conta)
			linha_da_recompensa.add_child(item)

	# ACOMPANHAR, o botão do Witcher. Acompanhada, ele diz que é e não faz nada.
	var respiro := Control.new()
	respiro.custom_minimum_size = Vector2(0, 6)
	_detalhe.add_child(respiro)
	var botao := Button.new()
	botao.name = "Acompanhar"
	botao.text = "◆  ACOMPANHANDO" if acompanhada else "ACOMPANHAR  [%s]" % Atalhos.letra("interagir")
	botao.focus_mode = Control.FOCUS_NONE
	botao.disabled = acompanhada
	botao.mouse_default_cursor_shape = Control.CURSOR_ARROW if acompanhada else Control.CURSOR_POINTING_HAND
	botao.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	botao.custom_minimum_size = Vector2(220, 38)
	botao.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TITULO, 600))
	botao.add_theme_font_size_override("font_size", 15)
	botao.add_theme_color_override("font_color", Identidade.CREME)
	botao.add_theme_color_override("font_disabled_color", COR_FIXADA)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.10, 0.17, 0.11, 0.95) if acompanhada else Color(0.19, 0.21, 0.15, 0.96)
	estilo.border_color = COR_FIXADA if acompanhada else Color(Identidade.OURO.r, Identidade.OURO.g, Identidade.OURO.b, 0.75)
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(4)
	for estado in ["normal", "hover", "pressed", "disabled"]:
		botao.add_theme_stylebox_override(estado, estilo)
	botao.pressed.connect(func() -> void:
		CadernoDoVale.fixar(id)
		Audio.efeito("menu_confirma"))
	_detalhe.add_child(botao)


func _texto_do_diario(texto: String, tamanho: int, cor: Color) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	etiqueta.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TEXTO, 400))
	etiqueta.add_theme_font_size_override("font_size", tamanho)
	etiqueta.add_theme_color_override("font_color", cor)
	return etiqueta


## O "o que fazer" da missão, de TODOS os arquivos de fala (ver o 2D).
const PASTA_DAS_FALAS := "res://data/dialogos"
var _arquivos: Array = []

func _objetivo_de(id: String) -> String:
	if id == "":
		return ""
	for arquivo in _arquivos_de_falas():
		var passos: Dictionary = Jogo.dados(arquivo).get("passos", {})
		var passo = passos.get(id, null)
		if passo is Dictionary and str(passo.get("objetivo", "")) != "":
			return Jogo.texto(str(passo["objetivo"]))
	return ""


func _arquivos_de_falas() -> Array:
	if not _arquivos.is_empty():
		return _arquivos
	for nome in DirAccess.get_files_at(PASTA_DAS_FALAS):
		var limpo := str(nome).trim_suffix(".remap")
		if not limpo.ends_with(".json"):
			continue
		var caminho := "%s/%s" % [PASTA_DAS_FALAS, limpo]
		if Jogo.dados(caminho).has("passos"):
			_arquivos.append(caminho)
	return _arquivos


## O GANHO NO CORPO DA OBRA QUE O JOGADOR FEZ.
##
## O `Obras.executar` compartilhado consome o material, dá XP e emite
## `concluida`, mas NÃO paga os `ATRIBUTOS` — só o `conceder` (a obra que um
## morador dá de presente) paga. O próprio painel promete "Dá: +10 de fôlego
## máximo" na linha da obra, e sem isto a promessa não se cumpria, aqui e no 2D
## (o `testar_obras` de lá confere o `conceder` e não o `executar`).
##
## O conserto certo é no `executar`, que é do 2D, e não foi tocado. Até lá o
## vale paga aqui, e `tests/obras.gd` cobra que o ganho entre UMA vez: quando o
## 2D consertar, o portão reprova por ganho em dobro, e esta função sai.
func pagar_o_que_a_obra_da(obra: String) -> void:
	Obras._pagar_o_atributo(obra)


func _desenhar_obras() -> void:
	_titulo.text = "Obras — %s" % BancadasVale.nome(obra_em_foco)
	var lista := Obras.disponiveis(obra_em_foco)
	if lista.is_empty():
		_adicionar_linha("Nada a fazer aqui por enquanto.", COR_APAGADA)
		_dica.text = _aviso if _aviso != "" else "Obra pede material. Junte tábua, lenha e pedra e volte." \
			+ _quantas_faltam(Obras.todas_de(obra_em_foco))
		_rodape.text = "[Tab] outra aba · [Esc] fechar"
		return
	var compartimento := ""
	for i in lista.size():
		var obra := str(lista[i])
		var dado := Obras.dados(obra)
		var onde := str(dado.get("compartimento", ""))
		if onde != "" and onde != compartimento:
			compartimento = onde
			_adicionar_linha(onde.to_upper(), COR_APAGADA, true)
		var pode := Obras.pode(obra_em_foco, obra)
		var cor := COR_CURSOR if i == _cursor else (COR_TEXTO if pode else COR_APAGADA)
		_adicionar_linha("  %s   %s" % ["✓" if pode else "·", dado.get("nome", obra)], cor)
	var escolhida := str(lista[_cursor]) if _cursor < lista.size() else ""
	var dado := Obras.dados(escolhida)
	var impede := Obras.impedimento(obra_em_foco, escolhida)
	var abatido := "" if Obras.desconto() <= 0.0 else "   (canteiro abate %d%%)" % int(Obras.desconto() * 100.0)
	_dica.text = _aviso if _aviso != "" else str(dado.get("resumo", "")) + _ganho_da_obra(escolhida) + "\n" + (
		impede if impede != "" else "Custa: " + _precos(Obras.custo(escolhida)) + abatido
		) + _quantas_faltam(Obras.todas_de(obra_em_foco))
	_rodape.text = "[W/S] escolher · [E] tocar a obra · [Tab] outra aba · [Esc] fechar"


const NOME_DO_ATRIBUTO := {
	"energia_maxima": "fôlego máximo",
	"recuperacao_ao_dormir": "descanso da noite",
	"recuperacao_ao_desmaiar": "descanso de quem apaga",
	"eficiencia": "esforço de toda tarefa",
}

func _ganho_da_obra(obra: String) -> String:
	var ganhos: Dictionary = Obras.ATRIBUTOS.get(obra, {})
	if ganhos.is_empty():
		return ""
	var partes: Array = []
	for campo in ganhos:
		var quanto := float(ganhos[campo])
		var nome := str(NOME_DO_ATRIBUTO.get(str(campo), str(campo)))
		if str(campo) == "eficiencia":
			partes.append("%s %d%% no %s" % ["menos" if quanto < 0.0 else "mais", int(absf(quanto) * 100.0), nome])
		else:
			partes.append("%+d de %s" % [int(quanto), nome])
	return "\nDá: " + ", ".join(partes) + "."


func _desenhar_venda() -> void:
	_titulo.text = "Venda do arraial      %d réis" % Jogo.dinheiro
	var lista := o_que_o_balcao_tem()
	var virou := false
	for i in lista.size():
		var linha := str(lista[i])
		var receita := _receita_da_linha(linha)
		if receita != "" and not virou:
			virou = true
			_adicionar_linha("RECEITAS — o plano, uma vez só", COR_APAGADA, true)
		var texto := ""
		if receita != "":
			texto = "  %-30s  %4d réis   (%s)" % [
				Receitas.nome(receita), Receitas.preco(receita), Receitas.bancada_de(receita)]
		else:
			texto = "%-22s  compra %4d   vende %4d   (tem %d)" % [
				Catalogo.nome(linha), Venda.preco_de_compra(linha),
				Venda.preco_de_venda(linha), Inventario.quantidade(linha)]
		_adicionar_linha(texto, COR_CURSOR if i == _cursor else COR_TEXTO)
	var escolhida := _receita_da_linha(str(lista[_cursor])) if _cursor < lista.size() else ""
	if escolhida != "":
		_dica.text = Receitas.resumo(escolhida) + "\n" + (
			"Custa %d réis, e é para sempre." % Receitas.preco(escolhida)
			if Jogo.dinheiro >= Receitas.preco(escolhida)
			else "Faltam %d réis." % (Receitas.preco(escolhida) - Jogo.dinheiro))
		_rodape.text = "[W/S] escolher · [E] comprar a receita · [Tab] outra aba · [Esc] fechar"
		return
	_dica.text = "O que o arraial produz sai barato e entra caro. Mandioca e lenha vendem bem na estiagem."
	_rodape.text = "[W/S] escolher · [E] comprar · [A] vender · [Tab] outra aba · [Esc] fechar"


## A ABA DO SAVEIRO: o que o mestre Quirino compra, quanto paga por um, quanto
## o jogador tem e até quanto ele leva nesta viagem. Os textos são do
## `data/saveiro.json`, nos três idiomas.
func _desenhar_saveiro() -> void:
	if saveiro == null:
		return
	_titulo.text = saveiro.texto("painel_titulo") % Jogo.dinheiro
	var lista: Array = saveiro.o_que_compra()
	for i in lista.size():
		var id := str(lista[i])
		var falta: int = saveiro.leva(id) - saveiro.levou(id)
		var texto: String = saveiro.texto("painel_linha") % [Catalogo.nome(id), saveiro.paga(id), Inventario.quantidade(id), maxi(falta, 0)]
		_adicionar_linha(texto, COR_CURSOR if i == _cursor else (COR_APAGADA if Inventario.quantidade(id) == 0 or falta <= 0 else COR_TEXTO))
	_dica.text = (_aviso + "\n" if _aviso != "" else "") + saveiro.texto("painel_dica")
	_rodape.text = saveiro.texto("painel_rodape")


func _precos(custo: Dictionary) -> String:
	var partes: Array = []
	for id in custo:
		partes.append("%d %s" % [int(custo[id]), Catalogo.nome(id).to_lower()])
	return ", ".join(partes) if not partes.is_empty() else "nada"


func _desenhar_ajustes() -> void:
	_titulo.text = "Jogo — %s" % Relogio.texto_do_dia(Relogio.dia_absoluto())
	_adicionar_linha("  %s" % _quando_foi_salvo(), COR_APAGADA, true)
	_adicionar_linha("", COR_TEXTO, true)
	for i in ACOES.size():
		var pedindo := _confirmando == i
		var rotulo: String = str(ACOES[i]["rotulo"])
		if pedindo:
			rotulo = "%s — aperte E de novo para confirmar" % rotulo
		_adicionar_linha("» %s" % rotulo, COR_CURSOR if i == _cursor else (COR_FIXADA if pedindo else COR_TEXTO))

	# As teclas do vale, lidas dos atalhos: remapeou, a lista acompanha.
	_adicionar_linha("", COR_TEXTO, true)
	_adicionar_linha("TECLAS", COR_APAGADA, true)
	_adicionar_linha("  [%s] este painel  ·  [%s] mapa  ·  [%s] avança a hora" % [
		Atalhos.letra("painel"), Atalhos.letra("mapa"), Atalhos.letra("hora")], COR_APAGADA, true)
	_adicionar_linha("  [%s] ler / interagir, e golpe perto do bicho  ·  [%s] ginga" % [
		Atalhos.letra("interagir"), Atalhos.letra("gingar")], COR_APAGADA, true)
	_adicionar_linha("  [%s] observar  ·  [%s] reinicia  ·  [Tab] câmera  ·  roda: zoom  ·  1 a 0: item da mão" % [
		Atalhos.letra("observar"), Atalhos.letra("reiniciar")], COR_APAGADA, true)
	_adicionar_linha("  [%s] mochila  ·  [%s] almanaque  ·  [%s] árvore de habilidades  ·  [%s] o arraial" % [
		Atalhos.letra("mochila"), Atalhos.letra("almanaque"), Atalhos.letra("talentos"), Atalhos.letra("arraial")], COR_APAGADA, true)

	_adicionar_linha("", COR_TEXTO, true)
	_adicionar_linha("AJUSTES DE TESTE — mexem no balanço da partida", COR_APAGADA, true)
	for i in CAMPOS.size():
		_adicionar_campo(i)

	var tudo: Array = ACOES + CAMPOS
	_dica.text = _aviso if _aviso != "" else (str(tudo[_cursor]["dica"]) if _cursor < tudo.size() else "")
	_rodape.text = "[W/S] escolher · [A/D] mudar o valor · [E] usar · [Esc] fechar"


## Há quanto tempo a partida foi guardada, em dia do Recôncavo (ver o 2D).
func _quando_foi_salvo() -> String:
	if not Partida.tem_vaga():
		return "Passeio sem vaga: nada aqui é salvo."
	if not Salvamento.existe_partida():
		return "Esta partida ainda não foi salva."
	var dia := int(Salvamento.dia_do_save())
	if dia <= 0:
		return "Partida salva."
	var agora := Relogio.dia_absoluto()
	if dia >= agora:
		return "Salvo hoje."
	var atras := agora - dia
	return "Salvo há %d dia%s." % [atras, "" if atras == 1 else "s"]


## Uma linha da lista: título de grupo sai como texto, o resto como BOTÃO de
## verdade — foco, realce ao passar o mouse, mãozinha (ver o 2D).
func _adicionar_linha(texto: String, cor: Color, cabecalho: bool = false, distintivo: String = "") -> void:
	if cabecalho:
		if distintivo == "":
			var etiqueta := _rotulo(texto, LETRA_DICA, cor)
			_lista.add_child(etiqueta)
			_linhas.append(etiqueta)
		else:
			var fila := HBoxContainer.new()
			fila.name = "Cabecalho_" + distintivo
			fila.add_theme_constant_override("separation", 8)
			fila.custom_minimum_size.y = ALTURA_DA_LINHA
			fila.add_child(_icone_distintivo(distintivo, 22.0))
			fila.add_child(_rotulo(texto, LETRA_DICA, cor))
			_lista.add_child(fila)
			_linhas.append(fila)
		return
	var indice := _escolhiveis.size()
	var botao := Button.new()
	botao.text = texto
	botao.alignment = HORIZONTAL_ALIGNMENT_LEFT
	botao.focus_mode = Control.FOCUS_NONE
	botao.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	botao.custom_minimum_size = Vector2(0, ALTURA_DA_LINHA)
	# O BOTÃO NÃO EMPURRA A CAIXA. Texto comprido faz o Button pedir largura, e
	# a caixa de 900 cresce com ele até sair da janela — foi assim que a lista de
	# missões explodiu, com o parágrafo da fala no lugar do título. Cortar no fim
	# é o conserto de quem desenha; o título curto é o de quem escreve a missão
	# (`CadeiaDeMissoes._titulo_do_passo`). Os dois, porque um protege do outro.
	botao.clip_text = true
	botao.add_theme_font_size_override("font_size", LETRA_LINHA)
	botao.add_theme_color_override("font_color", cor)
	botao.add_theme_color_override("font_hover_color", COR_CURSOR)
	botao.add_theme_color_override("font_pressed_color", COR_CURSOR)
	var escolhida := indice == _cursor
	for estado in ["normal", "hover", "pressed", "focus"]:
		botao.add_theme_stylebox_override(estado, _estilo_da_linha(escolhida, estado == "hover"))
	botao.pressed.connect(func(): _clicar(indice))
	_lista.add_child(botao)
	_linhas.append(botao)
	_escolhiveis.append(botao)


## Campo de valor dos ajustes: ◀ rótulo valor ▶. O cursor conta as AÇÕES
## antes dos campos — no 2D o realce e a seta do mouse comparavam o índice do
## campo com o cursor sem esse desconto, e caíam no lugar errado.
func _adicionar_campo(i: int) -> void:
	var campo: Dictionary = CAMPOS[i]
	var escolhida := i + ACOES.size() == _cursor
	var moldura := PanelContainer.new()
	moldura.add_theme_stylebox_override("panel", _estilo_da_linha(escolhida, false))
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	fila.custom_minimum_size = Vector2(0, ALTURA_DA_LINHA)
	moldura.add_child(fila)
	fila.add_child(_botao_pequeno("◀", func(): _mexer_no_campo(i, -1)))
	if str(campo["campo"]) == "energia_maxima":
		fila.add_child(_icone_distintivo("folego", 22.0))
	var etiqueta := _rotulo("%-18s  %6.2f" % [campo["rotulo"], Progressao.get(campo["campo"])],
		LETRA_LINHA, COR_CURSOR if escolhida else COR_TEXTO)
	etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(etiqueta)
	fila.add_child(_botao_pequeno("▶", func(): _mexer_no_campo(i, 1)))
	_lista.add_child(moldura)
	_linhas.append(moldura)
	_escolhiveis.append(moldura)


func _mexer_no_campo(i: int, sentido: int) -> void:
	_cursor = i + ACOES.size()
	_ajustar(sentido)
	_redesenhar()


## Clique numa linha: o primeiro escolhe, o segundo confirma (ver o 2D).
func _clicar(indice: int) -> void:
	if indice == _cursor:
		_confirmar()
		return
	_cursor = indice
	_confirmando = -1
	_aviso = ""
	Audio.efeito("menu_mover")
	_redesenhar()


func _botao_pequeno(simbolo: String, ao_apertar: Callable) -> Button:
	var botao := Button.new()
	botao.text = simbolo
	botao.focus_mode = Control.FOCUS_NONE
	botao.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	botao.custom_minimum_size = Vector2(30, 26)
	botao.add_theme_font_size_override("font_size", LETRA_ABAS)
	botao.add_theme_color_override("font_color", COR_APAGADA)
	botao.add_theme_color_override("font_hover_color", COR_CURSOR)
	for estado in ["normal", "hover", "pressed", "focus"]:
		botao.add_theme_stylebox_override(estado, _estilo_da_linha(false, estado != "normal"))
	botao.pressed.connect(ao_apertar)
	return botao


func _estilo_da_linha(escolhida: bool, realce: bool) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	if escolhida:
		estilo.bg_color = Color(0.2, 0.22, 0.16, 0.95)
		estilo.border_color = COR_CURSOR
		estilo.set_border_width_all(1)
	elif realce:
		estilo.bg_color = Color(0.14, 0.17, 0.13, 0.85)
	else:
		estilo.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	estilo.set_corner_radius_all(5)
	estilo.content_margin_left = 8
	estilo.content_margin_right = 8
	return estilo


func _estilo_da_calha() -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.03, 0.05, 0.04, 0.8)
	estilo.set_corner_radius_all(4)
	estilo.content_margin_left = 4
	estilo.content_margin_right = 4
	return estilo


func _estilo_do_puxador(aceso: bool) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = COR_CURSOR if aceso else Color(0.55, 0.5, 0.36)
	estilo.set_corner_radius_all(4)
	return estilo
