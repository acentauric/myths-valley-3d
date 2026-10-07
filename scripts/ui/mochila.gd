extends CanvasLayer
## Tela do inventário (tecla I): a mochila e o que o personagem veste.
##
## À esquerda, os 30 espaços numa grade de 10 por 3 — a primeira fila é a barra
## de mão, a mesma do rodapé. À direita, a coluna dos cinco ENCAIXES: cabeça,
## corpo, mãos, pés e amuleto.
##
## Dez colunas para a fila de cima ser EXATAMENTE a barra de mão, na mesma
## ordem e com os mesmos números. Com seis colunas e dez espaços de mão a
## barra quebrava no meio da segunda fila, e aí o número escrito no canto não
## queria dizer mais nada.
##
## O cursor é um só e atravessa as duas partes: passar da última coluna da
## grade leva aos encaixes. Assim não há modo, não há foco a alternar, e o
## jogador não precisa decorar em que metade está.
##
## E arruma a mochila, F veste ou come. Tudo de teclado, como o resto do jogo.

## QUEM ABRE O DOCUMENTO QUE O JOGADOR ESTÁ LENDO.
##
## O cordel e a carta se leem numa folha por cima da tela, e essa folha é do
## projeto: no jogo 2D é o `Tela.ler_documento`, que escurece e passa página.
## Este arquivo é usado pelo protótipo 3D; não acopla documentos a uma tela — então
## ele não pergunta a ninguém pelo nome, pergunta a quem foi apresentado.
##
## Vazio é o fallback para uma cena que não apresentou um leitor. No vale,
## `Prototype` conecta `_ler_documento`: cordéis abrem a folha existente.
##
## Mesma costura de `Vida.esta_lendo`. Ver `Telas._ready`.
var abrir_documento: Callable = Callable()

## ALGUÉM ESTÁ FALANDO?
##
## Fechar a mochila devolve o tempo ao jogo, menos quando uma caixa de fala já
## o tinha parado por conta dela — despausar ali faria o mundo andar por baixo
## de uma conversa. No 2D quem sabe disso é o `Dialogo`; no protótipo 3D não há
## `Dialogo`, e o relógio de lá tem outro dono.
##
## Terceira vez que a mesma pergunta aparece nesta migração — depois de
## `Vida.esta_lendo` e da tecla da mão. Se uma quarta aparecer, ela merece uma
## casa só em vez de um `Callable` por arquivo.
var alguem_fala: Callable = Callable()
## A tela pergunta ao dono dos controles, sem conhecer a tabela do projeto.
var letra_de_fechar: Callable = Callable()

const COLUNAS := 10
## Espaço menor que antes: dez colunas de 34px não cabiam nos 640 da viewport
## junto com a coluna dos encaixes.
const LADO := 28
const ESPACAMENTO := 3

const COR_MOLDURA := Color(0.5, 0.42, 0.28)
const COR_CURSOR := Color(0.96, 0.84, 0.46)
const COR_PEGO := Color(0.55, 0.85, 0.62)
const COR_MAO := Color(0.72, 0.6, 0.36)
const COR_ENCAIXE := Color(0.62, 0.55, 0.72)
## A moldura do baú: madeira, para não se confundir com a do que se veste.
const COR_BAU := Color(0.58, 0.44, 0.28)

var aberta: bool = false

var _grade: GridContainer
var _encaixes_coluna: VBoxContainer
var _efeitos: VBoxContainer
var _titulo_dos_efeitos: Label
var _titulo: Label
var _rodape: Label
var _nome_do_item: Label
var _molduras: Array = []      ## 0..ESPACOS-1 mochila, depois os encaixes

var _cursor: int = 0
## Espaço levantado, esperando onde soltar. -1 = nada na mão do cursor.
var _pego: int = -1
## Comida que já avisou que vai desperdiçar fôlego e espera o segundo F.
var _confirmar: String = ""

var _vidro: Control
## Espaço de onde o arrasto começou, enquanto o botão está apertado.
var _arrastando_de: int = -1
## Último espaço CLICADO. Clicar de novo nele é o segundo clique — e o cursor
## ter chegado ali pelas setas não conta, senão o primeiro clique em cima de
## uma comida já escolhida pelo teclado comeria ela.
var _ultimo_clique: int = -1
var _ja_escolhido: bool = false

## --- O BAÚ ------------------------------------------------------------------
##
## "O baú tem que abrir igual inventário, só que mostrando as coisas dele e do
## inventário do jogador."
##
## Não é uma tela nova: é a MOCHILA com uma grade a mais em cima. Tela nova
## teria outro visual, outra navegação e outro jeito de fechar, e baú é
## justamente a coisa que só faz sentido ao lado da mochila.
##
## O conteúdo vem POR REFERÊNCIA de quem abriu — o `Array` do baú da casa, o do
## finado. Array em GDScript é referência, então mexer aqui mexe lá, e não há
## cópia para sincronizar depois. É o que faz o baú da casa continuar salvando
## certo sem ninguém avisar o save.
const BAU_MAXIMO := 20
var _bau: Array = []
var _bau_cabe: int = 0
var _bau_caixa: VBoxContainer
var _bau_grade: GridContainer
var _bau_rotulo: Label
var _bau_titulo: String = ""
var _recado: String = ""


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar()
	Inventario.mudou.connect(_atualizar)
	Equipamento.mudou.connect(_atualizar)
	visible = false


func abrir() -> void:
	if aberta:
		return
	_fechar_o_bau()
	aberta = true
	_cursor = 0
	_pego = -1
	_ultimo_clique = -1
	_confirmar = ""
	visible = true
	Relogio.pausado = true
	_atualizar()


## ABRE COM UM BAÚ DO LADO. `conteudo` é mexido no lugar — ver o bloco do baú.
##
## O cursor começa NO BAÚ, e é de propósito: quem abriu um baú foi ver o que
## tem dentro dele, não a própria mochila.
func abrir_bau(conteudo: Array, cabe: int, titulo: String) -> void:
	# FECHA ANTES DE GUARDAR, e a ordem é o conserto de um defeito: guardando
	# primeiro, o `fechar()` logo abaixo chamava `_fechar_o_bau()` e apagava o
	# que acabara de ser guardado. A tela abria com `_bau_cabe` em zero, o
	# cursor caía na faixa do baú sem baú e a conta dos encaixes estourava.
	if aberta:
		fechar()
	_bau = conteudo
	_bau_cabe = mini(cabe, BAU_MAXIMO)
	_bau_titulo = titulo
	_recado = ""
	aberta = true
	_pego = -1
	_ultimo_clique = -1
	_confirmar = ""
	_bau_caixa.visible = true
	_cursor = _primeiro_do_bau()
	visible = true
	Relogio.pausado = true
	Audio.efeito("porta_abrir")
	_atualizar()


func fechar() -> void:
	if not aberta:
		return
	aberta = false
	_pego = -1
	visible = false
	_fechar_o_bau()
	# Fechar a mochila devolve o tempo — MENOS se alguém estiver falando, que
	# é quem tem o relógio parado por outro motivo. Quem responde isso é o
	# projeto: ver `alguem_fala`, logo no alto, e a mesma costura em
	# `Vida.esta_lendo`.
	if not (alguem_fala.is_valid() and alguem_fala.call()):
		Relogio.pausado = false


func _fechar_o_bau() -> void:
	_bau = []
	_bau_cabe = 0
	_bau_titulo = ""
	_recado = ""
	# O CURSOR VOLTA PARA A MOCHILA. Ele fica onde estava, e se estava numa
	# vaga do baú passa a apontar um índice que, sem baú, cai na conta dos
	# encaixes — `ENCAIXES[5]` numa lista de cinco. O erro só aparece no
	# próximo `_atualizar`, que vem de um sinal, longe daqui.
	if _cursor >= _primeiro_do_bau():
		_cursor = 0
	if _bau_caixa != null:
		_bau_caixa.visible = false


func _unhandled_input(evento: InputEvent) -> void:
	# Abrir, fechar e trocar por outra tela é com o `Telas`, que escuta antes
	# desta e já consumiu a tecla I quando ela chega aqui.
	if not aberta:
		return

	# Qualquer tecla que não seja o F de confirmar desarma o aviso: quem mudou
	# de ideia não fica com um "tem certeza?" pendurado na tela.
	var era_f := evento.is_action_pressed("equipar")

	_recado = ""
	if evento.is_action_pressed("cancelar"):
		fechar()
	elif era_f:
		_usar()
	elif evento.is_action_pressed("mover_esquerda"):
		_mover(-1, 0)
	elif evento.is_action_pressed("mover_direita"):
		_mover(1, 0)
	elif evento.is_action_pressed("mover_cima"):
		_mover(0, -1)
	elif evento.is_action_pressed("mover_baixo"):
		_mover(0, 1)
	elif evento.is_action_pressed("interagir"):
		_pegar_ou_soltar()
	else:
		return
	if not era_f and _confirmar != "":
		_confirmar = ""
		_atualizar()
	get_viewport().set_input_as_handled()


## Mouse: arrastar um item de um espaço para o outro é o gesto natural de
## mochila, e é o mesmo que E-pega-E-solta faz no teclado.
##
## Clicar NÃO usa de primeira. O primeiro clique escolhe o espaço; só o segundo,
## no espaço já escolhido, é que veste ou come. Comer é irreversível — um clique
## torto em cima da comida não pode acabar com ela.
func _mouse(evento: InputEvent) -> void:
	if evento is InputEventMouseButton:
		var botao: InputEventMouseButton = evento
		if botao.button_index != MOUSE_BUTTON_LEFT:
			return
		var onde := _espaco_em(botao.position)
		if botao.pressed:
			# Guardado ANTES de mexer no cursor: é o que diz se este clique é o
			# primeiro (escolher) ou o segundo (fazer).
			_ja_escolhido = onde >= 0 and onde == _ultimo_clique
			_ultimo_clique = onde
			_arrastando_de = onde
			if onde >= 0:
				_cursor = onde
				_pego = -1
				_atualizar()
			return

		# Soltou: em outro espaço, troca; no mesmo, usa.
		if onde >= 0 and _arrastando_de >= 0 and onde != _arrastando_de:
			# ARRASTAR DE E PARA O BAÚ é a mesma viagem que o E faz. Tratado
			# antes de tudo porque os índices do baú vêm DEPOIS dos encaixes:
			# sem isto, soltar uma peça do baú caía no `ENCAIXES[...]` com
			# índice fora da lista.
			var de_bau := _arrastando_de >= _primeiro_do_bau()
			var para_bau := onde >= _primeiro_do_bau()
			if _bau_cabe > 0 and (de_bau or para_bau):
				if de_bau and not para_bau:
					_tirar_do_bau(_arrastando_de - _primeiro_do_bau())
				elif para_bau and not de_bau and _arrastando_de < Inventario.ESPACOS:
					_guardar_no_bau(_arrastando_de)
				_arrastando_de = -1
				_atualizar()
				return
			if _arrastando_de < Inventario.ESPACOS and onde < Inventario.ESPACOS:
				Inventario.trocar(_arrastando_de, onde)
			elif _arrastando_de < Inventario.ESPACOS:
				var encaixe_destino := str(Equipamento.ENCAIXES[onde - Inventario.ESPACOS])
				Equipamento.equipar_do_espaco(_arrastando_de, encaixe_destino)
			elif _arrastando_de < _primeiro_do_bau():
				Equipamento.desequipar(str(Equipamento.ENCAIXES[_arrastando_de - Inventario.ESPACOS]))
			Audio.efeito("menu_confirma")
			_cursor = onde
		elif onde >= 0 and onde == _arrastando_de and _ja_escolhido:
			# COM O BAÚ ABERTO, o segundo clique TRANSFERE em vez de usar.
			#
			# "Dar 2 cliques dentro do item no baú e no inventário deve
			# transferir de um pro outro. Se for um item com quantidade, deve
			# transferir 1 unidade por clique. Se apertar CTRL deve transferir
			# o total."
			#
			# Comer com o baú aberto continua no F, que é o botão de usar em
			# toda a tela — e comer por engano no meio de uma arrumação é
			# justamente o que o clique duplo não pode fazer aqui.
			if _bau_cabe > 0:
				if onde >= _primeiro_do_bau():
					_tirar_do_bau(onde - _primeiro_do_bau(), _tudo())
				elif onde < Inventario.ESPACOS:
					_guardar_no_bau(onde, _tudo())
			else:
				_usar()
		_arrastando_de = -1
		_atualizar()


## Qual espaço está debaixo do ponteiro, ou -1.
func _espaco_em(onde: Vector2) -> int:
	for i in _molduras.size():
		if (_molduras[i] as Panel).get_global_rect().has_point(onde):
			return i
	return -1


## O primeiro espaço do baú, no índice global das molduras.
func _primeiro_do_bau() -> int:
	return Inventario.ESPACOS + Equipamento.ENCAIXES.size()


func _no_bau() -> bool:
	return _bau_cabe > 0 and _cursor >= _primeiro_do_bau()


func _nos_encaixes() -> bool:
	return _cursor >= Inventario.ESPACOS and not _no_bau()


func _encaixe_do_cursor() -> String:
	if not _nos_encaixes():
		return ""
	return str(Equipamento.ENCAIXES[_cursor - Inventario.ESPACOS])


## Navegação em duas zonas coladas: sair pela direita da grade entra nos
## encaixes na mesma altura; sair pela esquerda dos encaixes volta à grade.
func _mover(dx: int, dy: int) -> void:
	# O BAÚ É UMA TERCEIRA ZONA, colada por cima da grade da mochila. Subir da
	# primeira fileira da mochila entra nele; descer da última fileira dele
	# volta. É a mesma gramática das outras duas zonas.
	if _no_bau():
		var k := _cursor - _primeiro_do_bau()
		if dy > 0 and k + COLUNAS >= _bau_cabe:
			_cursor = mini(k % COLUNAS, Inventario.ESPACOS - 1)
		elif dy != 0:
			_cursor = _primeiro_do_bau() + clampi(k + dy * COLUNAS, 0, _bau_cabe - 1)
		elif dx != 0:
			_cursor = _primeiro_do_bau() + wrapi(k + dx, 0, _bau_cabe)
		_ultimo_clique = -1
		Audio.efeito("menu_mover")
		_atualizar()
		return
	if _bau_cabe > 0 and dy < 0 and _cursor < COLUNAS:
		var coluna_atual := _cursor % COLUNAS
		var ultima_fileira: int = ((_bau_cabe - 1) / COLUNAS) * COLUNAS
		_cursor = _primeiro_do_bau() + mini(ultima_fileira + coluna_atual, _bau_cabe - 1)
		_ultimo_clique = -1
		Audio.efeito("menu_mover")
		_atualizar()
		return
	if _nos_encaixes():
		var linha := _cursor - Inventario.ESPACOS
		if dx < 0:
			_cursor = mini(linha, Inventario.ESPACOS / COLUNAS - 1) * COLUNAS + COLUNAS - 1
		elif dy != 0:
			_cursor = Inventario.ESPACOS + wrapi(linha + dy, 0, Equipamento.ENCAIXES.size())
	else:
		var coluna := _cursor % COLUNAS
		var linha := _cursor / COLUNAS
		if dx > 0 and coluna == COLUNAS - 1:
			_cursor = Inventario.ESPACOS + mini(linha, Equipamento.ENCAIXES.size() - 1)
		elif dx != 0:
			_cursor = wrapi(_cursor + dx, 0, Inventario.ESPACOS)
		elif dy != 0:
			_cursor = wrapi(_cursor + dy * COLUNAS, 0, Inventario.ESPACOS)
	# Andar pelas setas desfaz a escolha do mouse: o próximo clique volta a ser
	# o primeiro, onde quer que ele caia.
	_ultimo_clique = -1
	Audio.efeito("menu_mover")
	_atualizar()


func _pegar_ou_soltar() -> void:
	# COM O BAÚ ABERTO, O E É A VIAGEM: tira do baú, guarda no baú. Arrumar a
	# mochila continua existindo no ARRASTO do mouse — duas coisas no mesmo
	# botão precisam de contextos diferentes, e aqui o contexto é ter um baú
	# aberto na frente.
	if _bau_cabe > 0:
		# UMA UNIDADE, ou a pilha inteira com Ctrl. A mesma regra do clique:
		# ver `_tudo`.
		if _no_bau():
			_tirar_do_bau(_cursor - _primeiro_do_bau(), _tudo())
		else:
			_guardar_no_bau(_cursor, _tudo())
		_atualizar()
		return

	if _nos_encaixes():
		if Equipamento.desequipar(_encaixe_do_cursor()):
			Audio.efeito("menu_confirma")
		_atualizar()
		return

	if _pego < 0:
		if Inventario.vazio(_cursor):
			return
		_pego = _cursor
	elif _pego == _cursor:
		_pego = -1       # largou no mesmo lugar: desiste
	else:
		Inventario.trocar(_pego, _cursor)
		_pego = -1
	_atualizar()


## O JOGADOR PEDIU TUDO? Ctrl segurado quer dizer a pilha inteira.
##
## "Se for um item com quantidade, deve transferir 1 unidade por clique. Se
## apertar CTRL no teclado deve transferir o total."
##
## Uma unidade por vez é o padrão porque é o gesto mais comum — tirar dois
## beijus de uma pilha de vinte — e porque errar uma unidade se desfaz com um
## clique de volta. Tudo de uma vez continua a um dedo de distância.
func _tudo() -> bool:
	return Input.is_key_pressed(KEY_CTRL)


## TIRA DO BAÚ, uma unidade ou a pilha inteira, o quanto couber na mochila.
##
## O quanto couber, e não tudo ou nada: com a mochila quase cheia, "não coube"
## deixaria o jogador sem entender por que nada aconteceu. Levando o que cabe e
## dizendo quanto ficou, a conta fecha na tela.
func _tirar_do_bau(k: int, pilha_inteira: bool = true) -> void:
	if k < 0 or k >= _bau.size():
		return
	var dentro: Dictionary = _bau[k]
	var id := str(dentro.get("id", ""))
	var quantos := int(dentro.get("qtd", 1))
	if id == "" or quantos <= 0:
		return
	if not pilha_inteira:
		quantos = 1
	var levou := 0
	while levou < quantos and Inventario.adicionar(id, 1):
		levou += 1
	if levou == 0:
		_recado = "A mochila está cheia."
		Audio.efeito("menu_negado")
		return
	var restam := int(dentro.get("qtd", 1)) - levou
	if restam <= 0:
		_bau.remove_at(k)
		_cursor = _primeiro_do_bau() + clampi(k, 0, maxi(0, _bau_cabe - 1))
	else:
		dentro["qtd"] = restam
		if levou < quantos:
			_recado = "Só coube %d." % levou
	Audio.efeito("pegar")


## GUARDA NO BAÚ, uma unidade ou a pilha inteira.
func _guardar_no_bau(i: int, pilha_inteira: bool = true) -> void:
	if i < 0 or i >= Inventario.ESPACOS or Inventario.vazio(i):
		return
	var espaco: Dictionary = Inventario.espacos[i]
	var id := str(espaco.get("id", ""))
	var quantos := int(espaco.get("qtd", 1))
	if id == "":
		return
	if not pilha_inteira:
		quantos = 1
	# Empilha no que já está lá; só ocupa vaga nova se não houver pilha do
	# mesmo item. Baú que abre vaga nova para cada punhado enche à toa.
	var onde := -1
	for k in _bau.size():
		if str((_bau[k] as Dictionary).get("id", "")) == id:
			onde = k
			break
	if onde < 0 and _bau.size() >= _bau_cabe:
		_recado = "O baú está cheio."
		Audio.efeito("menu_negado")
		return
	if not Inventario.consumir(id, quantos):
		return
	if onde < 0:
		_bau.append({"id": id, "qtd": quantos})
	else:
		var dentro: Dictionary = _bau[onde]
		dentro["qtd"] = int(dentro.get("qtd", 0)) + quantos
	Audio.efeito("menu_confirma")


## F: veste equipamento, come comida. Um verbo só para "usar isto".
func _usar() -> void:
	if _nos_encaixes():
		if Equipamento.desequipar(_encaixe_do_cursor()):
			Audio.efeito("menu_confirma")
		_atualizar()
		return
	if Inventario.vazio(_cursor):
		return

	var id := str(Inventario.espacos[_cursor].get("id", ""))
	if Equipamento.e_equipamento(id):
		if Equipamento.equipar_do_espaco(_cursor):
			Audio.efeito("menu_confirma")
	elif Catalogo.tipo(id) == "comida":
		_comer(id)
	elif Catalogo.tipo(id) == "documento":
		_ler(id)
	_atualizar()


## Reler um documento, e DE PROPÓSITO.
##
## O convite era relido por acidente: bastava apertar E perto do mural com ele
## já no bolso, e a cerimônia do papel recomeçava — o jogador estava tentando
## fazer outra coisa e levava a carta na cara de novo. Ler de novo é vontade,
## não tropeço, então o lugar disso é aqui: F em cima do papel, na mochila.
##
## Fecha a mochila antes: o papel e a fala desenham por cima dela, e ler por
## trás de uma grade de inventário não é ler.
func _ler(id: String) -> void:
	fechar()
	if abrir_documento.is_valid():
		await abrir_documento.call(id)


## Comer com o corpo quase cheio JOGA FORA o que passa do teto, e comida custa
## dia de trabalho. Então o jogo avisa quanto se perde e espera um segundo F —
## sem abrir caixa de diálogo, que ficaria atrás desta tela.
##
## Quem come de fato é `Cozinha.comer`: esta tela só cuida da pergunta.
func _comer(id: String) -> void:
	if Cozinha.recado_de_desperdicio(id) != "" and _confirmar != id:
		_confirmar = id
		_atualizar()
		return
	_confirmar = ""
	Cozinha.comer(id)


# --- montagem -----------------------------------------------------------------

func _montar() -> void:
	var fundo := ColorRect.new()
	fundo.color = Color(0.03, 0.03, 0.05, 0.72)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)

	var painel := PanelContainer.new()
	painel.add_theme_stylebox_override("panel", _estilo_do_painel())
	painel.set_anchors_preset(Control.PRESET_CENTER)
	painel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	painel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(painel)
	Tela.vincular_componente(painel, "mochila", Vector2(0.5, 0.5))

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 6)
	painel.add_child(coluna)

	_titulo = Label.new()
	_titulo.add_theme_font_size_override("font_size", 14)
	_titulo.add_theme_color_override("font_color", Color(0.85, 0.7, 0.36))
	coluna.add_child(_titulo)

	# O BAÚ, quando há um: em cima da mochila, com a mesma grade.
	#
	# "O baú tem que abrir igual inventário, só que mostrando as coisas dele e
	# do inventário do jogador." Em cima e não ao lado porque é a leitura de
	# cima para baixo que diz o sentido: o que está lá é o que se TIRA, o que
	# está aqui é o que se GUARDA, e o E faz a viagem nos dois sentidos.
	_bau_caixa = VBoxContainer.new()
	_bau_caixa.add_theme_constant_override("separation", 3)
	_bau_caixa.visible = false
	coluna.add_child(_bau_caixa)

	_bau_rotulo = Label.new()
	_bau_rotulo.add_theme_font_size_override("font_size", 11)
	_bau_rotulo.add_theme_color_override("font_color", Color(0.72, 0.64, 0.48))
	_bau_caixa.add_child(_bau_rotulo)

	# A GRADE NASCE VAZIA AQUI e é preenchida no fim de `_montar`.
	#
	# A caixa precisa entrar na coluna ANTES da mochila, porque é aí que ela
	# aparece na tela. Mas `_montar_espaco` empilha em `_molduras`, e é a ordem
	# dessa lista que diz qual índice é mochila, qual é encaixe e qual é baú.
	# Criando as vinte molduras aqui, elas tomavam os índices 0..19 — e a tela
	# abria com a mochila desenhada dentro do baú e o baú dentro da mochila.
	_bau_grade = GridContainer.new()
	_bau_grade.columns = COLUNAS
	_bau_grade.add_theme_constant_override("h_separation", ESPACAMENTO)
	_bau_grade.add_theme_constant_override("v_separation", ESPACAMENTO)
	_bau_caixa.add_child(_bau_grade)

	_bau_caixa.add_child(HSeparator.new())

	# Mochila à esquerda, o que se veste à direita.
	var lado_a_lado := HBoxContainer.new()
	lado_a_lado.add_theme_constant_override("separation", 16)
	coluna.add_child(lado_a_lado)

	_grade = GridContainer.new()
	_grade.columns = COLUNAS
	_grade.add_theme_constant_override("h_separation", ESPACAMENTO)
	_grade.add_theme_constant_override("v_separation", ESPACAMENTO)
	lado_a_lado.add_child(_grade)
	for i in Inventario.ESPACOS:
		_grade.add_child(_montar_espaco(i))

	_encaixes_coluna = VBoxContainer.new()
	_encaixes_coluna.add_theme_constant_override("separation", ESPACAMENTO)
	lado_a_lado.add_child(_encaixes_coluna)
	for encaixe in Equipamento.ENCAIXES:
		var linha := HBoxContainer.new()
		linha.add_theme_constant_override("separation", 6)
		linha.add_child(_montar_espaco(-1))
		var etiqueta := Label.new()
		etiqueta.name = "Rotulo"
		etiqueta.custom_minimum_size = Vector2(76, 0)
		etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		etiqueta.add_theme_font_size_override("font_size", 10)
		etiqueta.add_theme_color_override("font_color", Color(0.72, 0.64, 0.48))
		etiqueta.text = str(Equipamento.NOME_DO_ENCAIXE[encaixe])
		linha.add_child(etiqueta)
		_encaixes_coluna.add_child(linha)

	# O que está fazendo efeito no corpo agora. Fica ao lado dos encaixes
	# porque é da mesma natureza: o que o personagem VESTE e o que ele TOMOU
	# são as duas coisas que mexem nos números dele sem estar na mão.
	var coluna_dos_efeitos := VBoxContainer.new()
	coluna_dos_efeitos.add_theme_constant_override("separation", 2)
	coluna_dos_efeitos.custom_minimum_size = Vector2(178, 0)
	lado_a_lado.add_child(coluna_dos_efeitos)

	_titulo_dos_efeitos = Label.new()
	_titulo_dos_efeitos.add_theme_font_size_override("font_size", 10)
	_titulo_dos_efeitos.add_theme_color_override("font_color", Color(0.72, 0.64, 0.48))
	coluna_dos_efeitos.add_child(_titulo_dos_efeitos)

	_efeitos = VBoxContainer.new()
	_efeitos.add_theme_constant_override("separation", 1)
	coluna_dos_efeitos.add_child(_efeitos)

	_nome_do_item = Label.new()
	_nome_do_item.add_theme_font_size_override("font_size", 12)
	_nome_do_item.add_theme_color_override("font_color", Color(0.93, 0.88, 0.76))
	_nome_do_item.custom_minimum_size = Vector2(0, 30)
	_nome_do_item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coluna.add_child(_nome_do_item)

	_rodape = Label.new()
	_rodape.add_theme_font_size_override("font_size", 10)
	_rodape.add_theme_color_override("font_color", Color(0.72, 0.64, 0.48))
	coluna.add_child(_rodape)

	# AS MOLDURAS DO BAÚ, por último: o índice delas tem que vir depois do da
	# mochila e do dos encaixes. Ver a nota na criação de `_bau_grade`.
	for k in BAU_MAXIMO:
		_bau_grade.add_child(_montar_espaco(-1))

	# A folha de vidro por cima de tudo, que recebe o mouse. Fica por último
	# para estar na frente, e as molduras continuam sendo desenho — quem
	# responde ao ponteiro é só ela.
	_vidro = Control.new()
	_vidro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vidro.mouse_filter = Control.MOUSE_FILTER_STOP
	_vidro.gui_input.connect(_mouse)
	add_child(_vidro)


func _montar_espaco(indice: int) -> Panel:
	var moldura := Panel.new()
	moldura.custom_minimum_size = Vector2(LADO, LADO)

	var icone := TextureRect.new()
	icone.name = "Icone"
	icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icone.set_anchors_preset(Control.PRESET_FULL_RECT)
	icone.offset_left = 3
	icone.offset_top = 3
	icone.offset_right = -3
	icone.offset_bottom = -3
	icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	moldura.add_child(icone)

	var quantidade := Label.new()
	quantidade.name = "Quantidade"
	quantidade.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	quantidade.offset_left = -20
	quantidade.offset_top = -14
	quantidade.offset_right = -2
	quantidade.offset_bottom = -1
	quantidade.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quantidade.add_theme_font_size_override("font_size", 9)
	quantidade.add_theme_color_override("font_color", Color(0.98, 0.94, 0.8))
	quantidade.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03))
	quantidade.add_theme_constant_override("outline_size", 3)
	quantidade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	moldura.add_child(quantidade)

	if indice >= 0 and indice < Inventario.ESPACOS_MAO:
		var numero := Label.new()
		numero.set_anchors_preset(Control.PRESET_TOP_LEFT)
		numero.offset_left = 2
		numero.offset_top = -1
		numero.text = Inventario.rotulo_do_espaco(indice)
		numero.add_theme_font_size_override("font_size", 8)
		numero.add_theme_color_override("font_color", Color(0.75, 0.66, 0.48, 0.85))
		numero.mouse_filter = Control.MOUSE_FILTER_IGNORE
		moldura.add_child(numero)

	_molduras.append(moldura)
	return moldura


func _estilo_do_painel() -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.09, 0.07, 0.05, 0.96)
	estilo.border_color = Color(0.79, 0.64, 0.35)
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(3)
	estilo.set_content_margin_all(10)
	return estilo


func _estilo_do_espaco(indice: int) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.13, 0.11, 0.08, 0.9)
	if indice == _cursor:
		estilo.border_color = COR_CURSOR
		estilo.set_border_width_all(2)
	elif indice == _pego:
		estilo.border_color = COR_PEGO
		estilo.set_border_width_all(2)
	elif indice >= _primeiro_do_bau():
		estilo.border_color = COR_BAU
		estilo.set_border_width_all(1)
	elif indice >= Inventario.ESPACOS:
		estilo.border_color = COR_ENCAIXE
		estilo.set_border_width_all(1)
	elif indice < Inventario.ESPACOS_MAO:
		estilo.border_color = COR_MAO
		estilo.set_border_width_all(1)
	else:
		estilo.border_color = COR_MOLDURA
		estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(2)
	return estilo


func _atualizar() -> void:
	if not aberta:
		return
	for i in _molduras.size():
		var moldura: Panel = _molduras[i]
		moldura.add_theme_stylebox_override("panel", _estilo_do_espaco(i))
		var icone: TextureRect = moldura.get_node("Icone")
		var quantidade: Label = moldura.get_node("Quantidade")

		var id := ""
		var quantos := 1
		if i < Inventario.ESPACOS:
			var espaco: Dictionary = Inventario.espacos[i]
			id = str(espaco.get("id", ""))
			quantos = int(espaco.get("qtd", 1))
		elif i < _primeiro_do_bau():
			id = Equipamento.no_encaixe(str(Equipamento.ENCAIXES[i - Inventario.ESPACOS]))
		else:
			var k := i - _primeiro_do_bau()
			moldura.visible = k < _bau_cabe
			if k < _bau.size():
				var dentro: Dictionary = _bau[k]
				id = str(dentro.get("id", ""))
				quantos = int(dentro.get("qtd", 1))

		if id == "":
			icone.texture = null
			quantidade.text = ""
			continue
		icone.texture = Catalogo.icone(id)
		icone.modulate.a = 0.45 if i == _pego else 1.0
		quantidade.text = str(quantos) if quantos > 1 or id == "madeira_de_coqueiro" else ""

	_titulo.text = "Mochila %d/%d        %d réis" % [
		Inventario.ocupados(), Inventario.ESPACOS, Jogo.dinheiro]
	if _bau_cabe > 0:
		_bau_rotulo.text = "%s   %d/%d" % [_bau_titulo, _bau.size(), _bau_cabe]
	_listar_efeitos()
	_nome_do_item.text = _descrever()
	if _recado != "":
		_nome_do_item.text = _recado
	if _confirmar != "":
		_nome_do_item.text = Cozinha.recado_de_desperdicio(_confirmar)
		_rodape.text = "[F] comer assim mesmo · qualquer outra tecla desiste"
	elif _bau_cabe > 0:
		_rodape.text = "[setas] escolher · [E] ou 2 cliques: %s 1 · [Ctrl] a pilha toda · [Esc] fechar" % (
			"tirar do baú" if _no_bau() else "guardar no baú")
	elif _pego >= 0:
		_rodape.text = "[E] soltar aqui · [Esc] desistir"
	else:
		_rodape.text = tr("[setas] escolher · [E] arrumar · [F] vestir ou comer · [%s] fechar") % _letra_de_fechar()
		if _ultimo_clique >= 0 and _ultimo_clique == _cursor:
			_rodape.text = tr("clique de novo para vestir ou comer · arraste para arrumar · [%s] fechar") % _letra_de_fechar()


func _letra_de_fechar() -> String:
	return str(letra_de_fechar.call()) if letra_de_fechar.is_valid() else "I"


## Reza, bênção, comida, poção, pacto, oferenda: tudo que está fazendo efeito
## agora, com o prazo de cada um e quantas vagas o corpo ainda tem.
##
## O teto aparece SEMPRE, mesmo com o corpo limpo, porque ele é regra do jogo —
## o jogador precisa saber que existe antes de esbarrar nele.
func _listar_efeitos() -> void:
	for filho in _efeitos.get_children():
		filho.queue_free()

	var lista := Efeitos.em_curso()
	_titulo_dos_efeitos.text = "No corpo   %d/%d" % [lista.size(), Efeitos.cabem()]

	if lista.is_empty():
		var vazio := Label.new()
		vazio.add_theme_font_size_override("font_size", 9)
		vazio.add_theme_color_override("font_color", Color(0.55, 0.5, 0.42))
		vazio.text = "Nada fazendo efeito."
		vazio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vazio.custom_minimum_size = Vector2(178, 0)
		_efeitos.add_child(vazio)
		return

	for efeito in lista:
		var linha := Label.new()
		linha.add_theme_font_size_override("font_size", 9)
		linha.add_theme_color_override("font_color", Color(0.86, 0.78, 0.56))
		linha.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		linha.custom_minimum_size = Vector2(178, 0)
		linha.text = "%s · %s\n   %s · %s" % [
			efeito["natureza"], efeito["nome"],
			_quanto(str(efeito["campo"]), float(efeito["valor"])),
			"último dia" if int(efeito["dias"]) <= 1 else "%d dias" % int(efeito["dias"])]
		_efeitos.add_child(linha)


## O efeito em português, e não em nome de campo.
func _quanto(campo: String, valor: float) -> String:
	var sinal := "+" if valor > 0.0 else ""
	match campo:
		"energia_maxima":
			return "%s%d de teto" % [sinal, int(roundf(valor))]
		"recuperacao_ao_dormir":
			return "%s%d por noite" % [sinal, int(roundf(valor))]
		"recuperacao_ao_desmaiar":
			return "%s%d ao desmaiar" % [sinal, int(roundf(valor))]
		"eficiencia":
			return "trabalho %d%% mais %s" % [
				int(roundf(absf(valor) * 100.0)), "barato" if valor < 0.0 else "caro"]
	return "%s%.2f" % [sinal, valor]


## O que está sob o cursor, e o que ele faz. É aqui que o jogador descobre que
## um item é equipamento ou comida — não há tooltip neste jogo.
func _descrever() -> String:
	var id := ""
	if _no_bau():
		var k := _cursor - _primeiro_do_bau()
		if k >= _bau.size():
			return "Vaga vazia do baú."
		id = str((_bau[k] as Dictionary).get("id", ""))
		if id == "":
			return "Vaga vazia do baú."
		return "%s — %s" % [Catalogo.nome(id), str(Catalogo.dados(id).get("resumo", "no baú"))]
	if _nos_encaixes():
		id = Equipamento.no_encaixe(_encaixe_do_cursor())
		if id == "":
			if _encaixe_do_cursor() == "maos":
				return "Mãos — proteção para luvas ou escudo. Ferramentas são usadas pela barra numerada."
			return "%s — vazio." % Equipamento.NOME_DO_ENCAIXE[_encaixe_do_cursor()]
	else:
		if Inventario.vazio(_cursor):
			return "—"
		id = str(Inventario.espacos[_cursor].get("id", ""))

	var dados := Catalogo.dados(id)
	var texto := Catalogo.nome(id)
	if dados.has("resumo"):
		texto += " — " + str(dados["resumo"])
	if Equipamento.e_equipamento(id):
		texto += "   [%s]" % Equipamento.NOME_DO_ENCAIXE.get(Equipamento.encaixe_de(id), "")
	elif Catalogo.tipo(id) == "comida":
		# O remédio diz que é remédio (ver Cozinha, o chá de folha): a reclamação
		# que o Graveyard Keeper mais ouviu foi de quem não sabia o que curava.
		if float(dados.get("vida", 0.0)) > 0.0:
			texto += "   [+%d de vida, +%d de %s]" % [int(dados["vida"]), int(dados.get("folego", 0)), Energia.nome_recurso()]
		else:
			texto += "   [+%d de %s]" % [int(dados.get("folego", 0)), Energia.nome_recurso()]
	return texto
