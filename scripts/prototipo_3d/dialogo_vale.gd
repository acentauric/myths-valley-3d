extends CanvasLayer
## A FALA LONGA DO VALE, com a escolha de Sim e Não (#21). Autoload `Dialogo`.
##
## Uso, o mesmo do 2D:
##     await Dialogo.falar("Pedro", ["Primeira fala.", "Segunda fala."])
##     var sim: bool = await Dialogo.perguntar("", "Firmar o pacto?")
##
## O balão 3D continua para a fala de passagem — o cumprimento, a resposta de
## quem recebe a entrega. Esta caixa é para o que o jogador PRECISA ler antes de
## seguir, e para a pergunta que ele precisa responder. Ver o MIGRACAO_2D_3D.md,
## "Onde o 3D já resolve, fica o do 3D".
##
## CÓPIA ADAPTADA, DECLARADA (regra 3 do plano), como o painel J. Vem do
## `scripts/ui/dialogo.gd` do 2D, e vieram iguais a API, a fila de falas, as
## duas travas (o E que não responde sem escolha feita e a carência do martelo)
## e o quadro de 640×360 com a caixa no rodapé. O desenho, não: desde 06/10 a
## caixa veste a identidade do vale 3D (`identidade.gd`), como o balão de fala —
## a laca com o filete de ouro, o nome em Cinzel, a fala em Cormorant — e não
## mais o marrom e as letras da `dialogo.tscn`. O que mudou, e por quê:
##
## - NÃO FECHA AS TELAS NEM PAUSA O RELÓGIO. No 2D a caixa chama
##   `Telas.fechar_todas()` e liga o `Relogio.pausado`. O vale não tem `Telas`,
##   e quem manda na hora aqui é o `Dia`: o `Relogio` é calendário, preso, e
##   soltá-lo no fim da fala o deixaria andando sozinho. Quem fecha a tela
##   aberta e para o vale e o `Dia` é o próprio vale, ouvindo `abriu` e
##   `terminou` (`prototype._ao_abrir_a_fala`), do mesmo jeito que para atrás
##   das telas.
## - SEM `pedir_texto`. O modo de digitar nome usa o `TemaIntro`, que é o tema
##   do menu do 2D e não atravessou, e o vale não pede nome digitado.
## - A CENA VIROU CÓDIGO. A `dialogo.tscn` aponta para o script por caminho do
##   outro projeto; os nós são os mesmos, montados em `_montar`.
## - O RODAPÉ MORA EM `data/dialogo.json`, com as palavras do 2D: texto de
##   jogador não mora em constante (AGENTS.md).
## - DESENHA NUM QUADRO DE 640×360, e o vale escala a camada para a tela dele
##   (`prototype._ajustar_as_telas_do_2d`). No 2D a janela inteira é desse
##   tamanho; aqui a caixa ancorada na janela de 1280×720 sairia com metade.
##
## VOLTA A SER UM ARQUIVO SÓ quando o 2D trocar a chamada ao `Telas` e a pausa
## do `Relogio` por quem ouve `abriu` e `terminou` — a porta que a mochila já
## usa (`alguem_fala`, `abrir_documento`) — e o modo de texto for para o menu.

signal terminou
## Quem abriu a boca, pelo nome que a caixa mostra. No vale é o sinal que para
## o vale atrás da caixa.
signal abriu(quem: String)

const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")
const Identidade = preload("res://scripts/prototipo_3d/identidade.gd")
const TEXTOS := "res://data/dialogo.json"
## A VOZ DE CADA LINHA, quando quem fala manda (`falar(nome, falas, vozes)`): o
## arquivo em assets/audio/vozes/, sem extensão. "Na explicação do pedro sobre a
## barra de stamina e similares, crie os audios para ele narrar." A linha que
## passa no E cala a voz dela e começa a da seguinte.
const PASTA_VOZES := "res://assets/audio/vozes/"
## O quadro em que a caixa é desenhada, o mesmo da tela do 2D.
const DESENHADA_PARA := Vector2(640, 360)

## O nome de quem está falando agora, ou "" quando é narração ou a caixa está
## fechada. Não é o mesmo que o rótulo da caixa: "Mural" e "Cruzeiro" também
## aparecem lá, e não são gente.
var quem_fala: String = ""


enum Modo { FALA, PERGUNTA }

## A tecla que fecha a caixa não pode valer também para o mundo: senão o mesmo
## "E" que confirma "Firmar?" reabre a pergunta no quadro seguinte.
##
## A carência é contada em QUADROS, e não em milissegundos: uma tecla vale um
## quadro, independente de a máquina estar a 15 ou 144 fps.
const CARENCIA_EM_QUADROS := 1

## QUANTO TEMPO A CAIXA IGNORA O "E" DEPOIS DE ABRIR, em segundos.
##
## É a situação em que o mundo abre uma fala enquanto o jogador está
## TRABALHANDO com a mesma tecla. Quem racha lenha martela o E; a fala cai do
## céu, e os toques seguintes — que eram para a árvore — passariam as linhas
## uma a uma, sem o jogador ver o que foi dito. Dois quadros cobrem só a tecla
## que estava no ar; meio segundo cobre o martelo e ainda deixa a caixa
## responder de imediato a quem estava lendo.
const CARENCIA_DE_ABERTURA := 0.5

## E ENTRE UMA LINHA E OUTRA, um respiro menor: um toque de quem martela chega
## a valer dois avanços quando a linha troca no meio da pancada.
const CARENCIA_DA_LINHA := 0.2

## O vale consulta isto para segurar o teclado durante a conversa.
var ativo: bool = false

var _painel: PanelContainer
var _nome: Label
var _texto: Label
var _rodape: Label
var _textos: Dictionary = {}

var _modo: int = Modo.FALA
var _falas: Array = []
## A voz de cada linha (ver PASTA_VOZES), na ordem das falas; "" é linha muda.
var _vozes: Array = []
var _voz: AudioStreamPlayer
var _indice: int = 0
var _escolha: bool = true
## O jogador já escolheu um lado? Enquanto for `false`, o E não responde nada.
## Ver `_atualizar_rodape_pergunta`.
var _escolheu: bool = false
## Quadro a partir do qual a caixa aceita tecla (ignora a que a abriu).
var _aceita_a_partir_de: int = 0
## Instante (relógio de parede, em segundos) a partir do qual a caixa aceita
## tecla. É a outra metade da trava, a que segura o martelo.
var _aceita_depois_de: float = 0.0
## Quadro em que a caixa fechou.
var _fechou_no_quadro: int = -10


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var lido = JSON.parse_string(FileAccess.get_file_as_string(TEXTOS))
	_textos = lido if lido is Dictionary else {}
	_montar()
	_painel.visible = false
	_voz = AudioStreamPlayer.new()
	_voz.name = "Voz"
	_voz.bus = Audio.GERAL
	add_child(_voz)


## Verdadeiro enquanto a caixa está aberta ou acabou de fechar. Quem lê a tecla
## "interagir" fora daqui deve checar isto antes de agir.
func ocupado() -> bool:
	return ativo or Engine.get_process_frames() <= _fechou_no_quadro + CARENCIA_EM_QUADROS


## Mostra as falas em sequência. Se já houver conversa aberta, espera a vez.
## `vozes`, quando vem, é a voz de cada linha (ver PASTA_VOZES).
##
## E A FILA DE FALAS DO VALE (`fila_de_falas.gd`): a caixa não espera o balão de
## ninguém — ela para o vale, e a fala que estava no ar fica suspensa, escondida,
## até a caixa fechar —, mas espera a narração do mundo, que cobre a tela
## inteira como ela.
func falar(nome: String, falas: Array, vozes: Array = []) -> void:
	if falas.is_empty():
		return
	await _esperar_a_vez()
	_abrir(nome, Modo.FALA)
	_falas = falas
	_vozes = vozes
	_indice = 0
	_mostrar_fala()
	await terminou


## A voz que está tocando agora, ou "" (para o portão).
func voz_tocando() -> String:
	if _voz == null or not _voz.playing or _voz.stream == null:
		return ""
	return _voz.stream.resource_path.get_file().get_basename()


## Pergunta de sim ou não. Esquerda escolhe Sim, direita escolhe Não.
func perguntar(nome: String, pergunta: String) -> bool:
	await _esperar_a_vez()
	_abrir(nome, Modo.PERGUNTA)
	_falas = [pergunta]
	_vozes = []
	_indice = 0
	# NASCE SEM ESCOLHA FEITA. `_escolha` continua em "Sim" só como valor de
	# partida do cursor; quem manda é `_escolheu`, e ele começa falso — sem um
	# A ou um D antes, o E não responde. Ver `_atualizar_rodape_pergunta`.
	_escolha = true
	_escolheu = false
	_mostrar_fala()
	await terminou
	return _escolheu and _escolha


## Fecha a caixa sem resposta — a pergunta vale Não — e cala também quem
## esperava a vez. É para quem sai do vale no meio da conversa (a volta ao menu,
## um portão que troca de cena): ninguém vai dar o E que ela espera. Não há
## isto no 2D, onde a caixa e o mundo vivem e morrem juntos.
func calar() -> void:
	while ativo:
		_escolha = false
		_fechar()


## A VEZ DA CAIXA: nenhuma outra caixa aberta, e nenhuma narração do vale na tela
## (a fila de falas diz, `segura_a_caixa`). Sem fila no vale, só a outra caixa.
## Sem nada na frente, volta no mesmo quadro: quem chama lê a caixa já aberta.
func _esperar_a_vez() -> void:
	while ativo or _narracao_na_tela():
		if ativo:
			await terminou
		else:
			await get_tree().process_frame


func _narracao_na_tela() -> bool:
	if not is_inside_tree():
		return false
	var fila := get_tree().get_first_node_in_group("fila_de_falas")
	return fila != null and bool(fila.call("segura_a_caixa"))


func _abrir(nome: String, modo: int) -> void:
	ativo = true
	_modo = modo
	if nome == "Pedro":
		_nome.text = Jogo.nome_pedro
	else:
		_nome.text = nome
	_nome.visible = nome != ""
	_painel.visible = true
	quem_fala = _nome.text if nome != "" else ""
	abriu.emit(quem_fala)
	_aceita_a_partir_de = Engine.get_process_frames() + 2
	# `get_ticks_msec` e não o relógio do jogo: o vale acabou de parar o `Dia`
	# (é o `abriu` de cima), e a espera tem de correr mesmo com ele parado.
	_aceita_depois_de = Time.get_ticks_msec() / 1000.0 + CARENCIA_DE_ABERTURA


func _fechar() -> void:
	_painel.visible = false
	if _voz != null:
		_voz.stop()
	_vozes = []
	ativo = false
	quem_fala = ""
	_fechou_no_quadro = Engine.get_process_frames()
	terminou.emit()


func _montar() -> void:
	var quadro := Control.new()
	quadro.name = "Quadro"
	quadro.size = DESENHADA_PARA
	quadro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(quadro)

	# NA IDENTIDADE DO VALE 3D (06/10), e não mais no marrom do 2D: a laca
	# verde-escura dos menus e do HUD com o filete de ouro, como o balão de fala
	# (`balao_fala.gd`) — a caixa longa e o balão curto são a mesma voz.
	var estilo := StyleBoxFlat.new()
	estilo.content_margin_left = 14.0
	estilo.content_margin_top = 7.0
	estilo.content_margin_right = 14.0
	estilo.content_margin_bottom = 6.0
	estilo.bg_color = Color(Identidade.LACA, 0.95)
	estilo.set_border_width_all(1)
	estilo.border_color = Color(Identidade.OURO, 0.8)
	estilo.set_corner_radius_all(6)
	estilo.shadow_color = Color(0, 0, 0, 0.35)
	estilo.shadow_size = 6
	estilo.shadow_offset = Vector2(0, 2)

	_painel = PanelContainer.new()
	_painel.name = "Painel"
	_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quadro.add_child(_painel)
	_painel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_painel.offset_left = 40.0
	_painel.offset_top = -78.0
	_painel.offset_right = -40.0
	_painel.offset_bottom = -12.0
	_painel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_painel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_painel.add_theme_stylebox_override("panel", estilo)

	var caixa := VBoxContainer.new()
	caixa.name = "Caixa"
	caixa.add_theme_constant_override("separation", 4)
	_painel.add_child(caixa)

	# O nome em Cinzel versalete dourado, o fio de ouro, a fala em Cormorant e o
	# rodapé em Cinzel miúdo — os mesmos traços do balão e dos títulos do menu.
	_nome = _rotulo("Nome", Identidade.ROTULO, 11, Identidade.fonte(Identidade.FONTE_TITULO, 600, 2))
	_nome.uppercase = true
	caixa.add_child(_nome)
	var fio := ColorRect.new()
	fio.name = "Fio"
	fio.color = Color(Identidade.OURO, 0.35)
	fio.custom_minimum_size = Vector2(0, 1)
	fio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa.add_child(fio)
	_texto = _rotulo("Texto", Identidade.TEXTO, 13, Identidade.fonte(Identidade.FONTE_TEXTO, 600))
	_texto.custom_minimum_size = Vector2(0, 30)
	_texto.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.add_theme_constant_override("line_spacing", -1)
	caixa.add_child(_texto)
	_rodape = _rotulo("Rodape", Color(Identidade.ROTULO, 0.85), 9, Identidade.fonte(Identidade.FONTE_TITULO, 600, 1))
	_rodape.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	caixa.add_child(_rodape)


func _rotulo(nome: String, cor: Color, tamanho: int, fonte: Font) -> Label:
	var etiqueta := Label.new()
	etiqueta.name = nome
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiqueta.add_theme_font_override("font", fonte)
	etiqueta.add_theme_color_override("font_color", cor)
	etiqueta.add_theme_font_size_override("font_size", tamanho)
	Identidade.sombra_texto(etiqueta)
	return etiqueta


func _escrito(chave: String) -> String:
	return str(IdiomaMenu.campo(_textos.get(chave, {}), "texto", chave))


func _mostrar_fala() -> void:
	_texto.text = str(_falas[_indice])
	_tocar_a_voz()
	# Cada linha nova ganha o seu respiro. Ver `CARENCIA_DA_LINHA`.
	_aceita_depois_de = maxf(_aceita_depois_de,
		Time.get_ticks_msec() / 1000.0 + CARENCIA_DA_LINHA)
	if _modo == Modo.PERGUNTA:
		_atualizar_rodape_pergunta()
	else:
		# "SEGUIR" e não "fechar" na última linha: a caixa não sabe o que vem
		# depois dela. Falas encadeadas são chamadas em sequência, uma depois
		# de a outra fechar, e "seguir" é verdade quando fecha e quando emenda.
		var ultima := _indice == _falas.size() - 1
		_rodape.text = _escrito("seguir") if ultima else _escrito("continuar")


## A voz da linha da vez, no canal de vozes do AJUSTAR; a da linha de antes cala.
func _tocar_a_voz() -> void:
	if _voz == null:
		return
	_voz.stop()
	var nome := str(_vozes[_indice]) if _indice < _vozes.size() else ""
	var caminho := PASTA_VOZES + nome + ".mp3"
	if nome == "" or not ResourceLoader.exists(caminho):
		return
	_voz.stream = load(caminho)
	_voz.volume_db = Audio.volume_vozes_db()
	_voz.play()


## A PERGUNTA NÃO NASCE COM RESPOSTA ESCOLHIDA.
##
## O E é a MESMA tecla que avança fala: quem vem martelando E numa conversa de
## seis linhas já tem o dedo em cima quando a sétima é uma pergunta. Com "Sim"
## pré-marcado, martelar respondia por ele. A trava é de projeto, e não de
## tempo: o E não faz nada até haver um A ou um D. Enquanto nada está
## escolhido, o rodapé mostra as duas portas e as teclas que abrem cada uma.
func _atualizar_rodape_pergunta() -> void:
	if not _escolheu:
		_rodape.text = _escrito("escolha")
		return
	var sim := "[ %s ]" % _escrito("sim") if _escolha else "  %s  " % _escrito("sim")
	var nao := "[ %s ]" % _escrito("nao") if not _escolha else "  %s  " % _escrito("nao")
	_rodape.text = "%s %s      %s" % [sim, nao, _escrito("confirmar")]


## O rodapé pisca em ouro quando o E chega sem escolha feita: sem isto, a tecla
## que vinha funcionando a conversa inteira de repente não faz nada, e a
## leitura natural disso é "travou", não "falta escolher".
const COR_PISCA := Color(0.96, 0.82, 0.42)

func _piscar_a_escolha() -> void:
	Audio.efeito("menu_voltar")
	var volta: Color = _rodape.get_theme_color("font_color")
	_rodape.add_theme_color_override("font_color", COR_PISCA)
	var animacao := create_tween()
	animacao.tween_interval(0.16)
	animacao.tween_callback(func(): _rodape.add_theme_color_override("font_color", volta))


func _process(_delta: float) -> void:
	if not ativo or Engine.get_process_frames() < _aceita_a_partir_de:
		return

	if _modo == Modo.PERGUNTA:
		# Direcional, não alternado: esquerda é sempre Sim, direita é sempre Não.
		# A primeira direcional também é o que HABILITA o E.
		if Input.is_action_just_pressed("mover_esquerda") and (not _escolheu or not _escolha):
			_escolha = true
			_escolheu = true
			_atualizar_rodape_pergunta()
			Audio.efeito("menu_mover")
		elif Input.is_action_just_pressed("mover_direita") and (not _escolheu or _escolha):
			_escolha = false
			_escolheu = true
			_atualizar_rodape_pergunta()
			Audio.efeito("menu_mover")

		# Esc é sempre "Não". Sair de uma pergunta sem responder é responder
		# que não, e é a saída segura.
		if Input.is_action_just_pressed("cancelar"):
			_escolha = false
			_fechar()
		elif Input.is_action_just_pressed("interagir"):
			if _escolheu:
				_fechar()
			else:
				# NÃO ENGOLE A TECLA EM SILÊNCIO. Ver `_piscar_a_escolha`.
				_piscar_a_escolha()
		return

	# A TRAVA DO MARTELO, e SÓ AQUI — na fala corrida. A pergunta já tem uma
	# trava mais forte que tempo (o E sem escolha não responde), e as
	# direcionais precisam responder na hora.
	if Time.get_ticks_msec() / 1000.0 < _aceita_depois_de:
		return

	if Input.is_action_just_pressed("interagir") or Input.is_action_just_pressed("cancelar"):
		_indice += 1
		if _indice >= _falas.size():
			_fechar()
		else:
			_mostrar_fala()
