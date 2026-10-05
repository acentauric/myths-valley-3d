extends RefCounted
## AJUSTAR: monta o conteúdo do modal de ajustes (cabeçalho com ×, abas Geral / Sons do
## vale / Cenário / Atalhos, duas colunas de campos com "?" de ajuda) dentro de um
## VBoxContainer.
## O menu usa no painel central; o jogo usa num modal próprio, com o vale pausado, e
## esconde o que só vale para o menu (idioma, trilha, paisagem sonora, cenário e fonte).

const AudioToggleIcon = preload("res://scripts/prototipo_3d/audio_toggle_icon.gd")
const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")
const AjudaMenu = preload("res://scripts/prototipo_3d/ajuda_menu.gd")
const HudIcon = preload("res://scripts/prototipo_3d/hud_icon.gd")
const TemaMenu = preload("res://scripts/prototipo_3d/tema_menu.gd")
const TeclasMovimento = preload("res://scripts/prototipo_3d/teclas_movimento.gd")
const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")
const CameraMouse = preload("res://scripts/prototipo_3d/camera_mouse.gd")
const Identidade = preload("res://scripts/prototipo_3d/identidade.gd")

## × do cabeçalho (o anfitrião fecha o modal).
signal fechar_pedido
## Estilo visual trocado: o anfitrião recarrega a cena para reconstruir o vale.
signal estilo_mudou
## Preferências do menu que o menu aplica na hora (tema e câmera de fundo).
signal fonte_menu_mudou(opcao: int)
signal cenario_menu_mudou(sobrevoo: bool)

## Mesma altura dos outros modais do menu; só a largura varia. Abas que passam da altura
## rolam por dentro.
const TAMANHO := Vector2(900, 600)
const ABAS := ["Geral", "Sons do vale", "Cenário", "Atalhos"]
## Altura de cada campo e do controle dentro dele (seleção ou volume).
const ALTURA_CAMPO := 66.0
const ALTURA_CONTROLE := 36.0
## Altura comum do cabeçalho dos modais (título + botão do canto).
const ALTURA_CABECALHO := 44.0
## Distância (fração da barra) em que o volume encaixa na marca do padrão.
const IMA := 0.035
const HORAS_INICIAIS := [4.5, 7.0, 12.0, 15.0, 17.5, 20.5]
const ROTULOS_HORAS := ["Madrugada (4h30)", "Manhã (7h)", "Meio-dia", "Tarde (15h)", "Entardecer (17h30)", "Noite (20h30)"]
const PREFERENCIAS_VISUAIS := "user://preferencias_visuais.cfg"
## Fonte do menu (Cenário): a Crônica da identidade ("" = Cormorant e Cinzel), a fonte
## do Godot ("padrao") ou as duas fontes do 2D. Ver tema_menu.gd.
const FONTES_MENU := ["", "padrao", "res://assets/fonts/Almendra-Bold.ttf", "res://assets/fonts/miva.ttf"]
const ROTULOS_FONTES := ["Crônica", "Padrão", "Almendra", "Miva"]

## Opção de fábrica de cada seleção (índice na lista), para o botão de voltar ao padrão.
## Idioma, estilo e fonte voltam à primeira opção (Português, Tripo, Crônica).
const PADRAO_VELOCIDADE := 2
const PADRAO_HORA := 1
const PADRAO_PAUSA := 1
const PADRAO_TRILHA := 0
const PADRAO_BOTOES := 1
const PADRAO_PAISAGEM := 3
const PADRAO_CENARIO := 1

## true no jogo: só os ajustes que valem dentro do vale.
var no_jogo := false
## Tema do modal de ajuda (o mesmo do painel que hospeda os ajustes).
var tema: Theme
var aba := 0
var _content: VBoxContainer
var _camada: Node
var _pai: Container
var _ajuda: Control


func _init(dentro_do_jogo := false) -> void:
	no_jogo = dentro_do_jogo


## Monta a aba `nova_aba` em `content`, apagando o que houver nele. `camada` recebe o
## modal de ajuda dos "?", por cima de tudo.
func construir(content: VBoxContainer, camada: Node, nova_aba: int = 0) -> void:
	_content = content
	_camada = camada
	aba = nova_aba
	fechar_ajuda()
	for filho in content.get_children():
		content.remove_child(filho)
		filho.queue_free()
	content.add_theme_constant_override("separation", 10)
	cabecalho(content, "Ajustes", func() -> void: fechar_pedido.emit(),
		"Tempo, sons e aparência do vale." if no_jogo else "Idioma, tempo, sons e aparência do vale.")
	var abas := HBoxContainer.new()
	abas.add_theme_constant_override("separation", 8)
	content.add_child(abas)
	var ativa: Button
	for indice in range(ABAS.size()):
		var botao := Button.new()
		botao.text = ABAS[indice]
		botao.toggle_mode = true
		botao.button_pressed = indice == aba
		botao.custom_minimum_size.y = 40
		botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if indice == aba:
			for cor in ["font_color", "font_pressed_color", "font_focus_color"]:
				botao.add_theme_color_override(cor, Color("e2c47f"))
			ativa = botao
		botao.pressed.connect(func() -> void:
			Audio.efeito("ui_confirmar")
			_reconstruir(indice))
		abas.add_child(botao)
	# Abas mais altas que o modal (Geral com os atalhos) rolam em vez de estourar a tela.
	var rolagem := ScrollContainer.new()
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rolagem.follow_focus = true
	content.add_child(rolagem)
	var colunas := HBoxContainer.new()
	colunas.add_theme_constant_override("separation", 32)
	colunas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	colunas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rolagem.add_child(colunas)
	var esquerda := _coluna(colunas)
	var direita := _coluna(colunas)
	match aba:
		1: _aba_sons(esquerda, direita)
		2: _aba_cenario(esquerda, direita)
		3: _aba_atalhos(esquerda, direita)
		_: _aba_geral(esquerda, direita)
	# Os volumes moram em Geral e em Sons do vale.
	if aba in [0, 1]:
		_restaurar_volumes()
	ativa.grab_focus()


func ajuda_aberta() -> bool:
	return is_instance_valid(_ajuda)


func fechar_ajuda() -> void:
	if is_instance_valid(_ajuda):
		_ajuda.queue_free()
	_ajuda = null


func _reconstruir(nova_aba: int) -> void:
	if is_instance_valid(_content):
		construir(_content, _camada, nova_aba)


func _coluna(colunas: HBoxContainer) -> VBoxContainer:
	var coluna := VBoxContainer.new()
	coluna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coluna.add_theme_constant_override("separation", 8)
	colunas.add_child(coluna)
	return coluna


## Geral: à esquerda o que vale para todo o jogo (idioma e relógio do vale), à direita
## os volumes principais.
func _aba_geral(esquerda: VBoxContainer, direita: VBoxContainer) -> void:
	_pai = esquerda
	_secao("Jogo")
	if not no_jogo:
		_escolha("Idioma", IdiomaMenu.ROTULOS, IdiomaMenu.indice(), func(i: int) -> void:
			IdiomaMenu.definir(i)
			_reconstruir(0), 0)
	_escolha("Passagem do tempo", Dia.ROTULOS_VELOCIDADE, Dia.velocidade, Dia.definir_velocidade, PADRAO_VELOCIDADE)
	var hora_indice := 1
	for indice in range(HORAS_INICIAIS.size()):
		if absf(float(HORAS_INICIAIS[indice]) - Dia.hora_inicial) < 0.75:
			hora_indice = indice
	_escolha("Hora inicial", ROTULOS_HORAS, hora_indice, func(i: int) -> void: Dia.definir_hora_inicial(float(HORAS_INICIAIS[i])), PADRAO_HORA)
	_escolha("Pausar o relógio no jogo", ["Permitido", "Bloqueado"], 0 if Dia.pausa_no_jogo else 1, func(i: int) -> void: Dia.definir_pausa_no_jogo(i == 0), PADRAO_PAUSA)
	_escolha("Teclas de movimento", TeclasMovimento.ROTULOS, TeclasMovimento.modo(), TeclasMovimento.definir, TeclasMovimento.PADRAO)
	# A CÂMERA DO MOUSE. Só muda o modo com que o jogo ABRE; a tecla da câmera
	# continua alternando na hora, como sempre fez.
	_escolha("Câmera do mouse", CameraMouse.ROTULOS, CameraMouse.modo(), CameraMouse.definir, CameraMouse.PADRAO)
	_pai = direita
	_secao("Volume")
	_volume("Música", Audio.volume_musica, Audio.definir_volume_musica, "musica")
	_volume("Narração", Audio.volume_narracao, Audio.definir_volume_narracao, "narracao")
	_volume("Falas dos personagens", Audio.volume_vozes, Audio.definir_volume_vozes, "vozes")
	_volume("Efeitos e passos", Audio.volume_efeitos, Audio.definir_volume_efeitos, "efeitos")
	_volume("Ambiente", Audio.volume_ambiente, Audio.definir_volume_ambiente, "ambiente")


## Atalhos: as teclas de cada ação, divididas nas duas colunas.
func _aba_atalhos(esquerda: VBoxContainer, direita: VBoxContainer) -> void:
	# Só as letras livres: W/A/S/D andam e navegam as telas (`Atalhos.RESERVADAS`).
	var codigos: Array = Atalhos.letras_livres()
	var letras: Array = []
	for codigo in codigos:
		letras.append(OS.get_keycode_string(codigo))
	var acoes: Array = Atalhos.DEFINICOES.keys()
	var metade := ceili(acoes.size() / 2.0)
	for indice in acoes.size():
		var acao: String = acoes[indice]
		_pai = esquerda if indice < metade else direita
		if indice == 0 or indice == metade:
			_secao("Atalhos" if indice == 0 else " ")
		_escolha(Atalhos.rotulo(acao), letras, codigos.find(Atalhos.tecla(acao)), func(i: int) -> void:
			Atalhos.definir(acao, int(codigos[i]))
			Atalhos.aplicar()
			# Reconstrói a aba: numa troca (swap) a linha da outra ação também muda.
			_reconstruir(3), codigos.find(int(Atalhos.DEFINICOES[acao]["padrao"])))


## Sons: à esquerda as escolhas sonoras do menu (no jogo, só o som dos botões), à direita
## o volume de cada camada do ambiente (aplicado sobre o volume geral de Ambiente).
func _aba_sons(esquerda: VBoxContainer, direita: VBoxContainer) -> void:
	_pai = esquerda
	_secao("Botões" if no_jogo else "Menu")
	if not no_jogo:
		_escolha("Trilha do menu", ["Introdução", "Menu I", "Menu II", "Recôncavo"], Audio.musica_menu_opcao - 1, func(i): Audio.definir_musica_menu(i + 1), PADRAO_TRILHA)
	_escolha("Som dos botões", ["Original", "Madeira"], Audio.efeitos_menu_opcao - 1, func(i):
		Audio.definir_efeitos_menu(i + 1)
		Audio.testar_efeito_menu(), PADRAO_BOTOES)
	# Passos na água: sons originais ou os novos (_v2), com prévia ao lado.
	var anterior_agua := _abrir_campo()
	_rotulo_do_campo("Passos na água", "Passos na água")
	var linha_agua := HBoxContainer.new()
	linha_agua.add_theme_constant_override("separation", 10)
	_pai.add_child(linha_agua)
	var seletor_agua := OptionButton.new()
	seletor_agua.custom_minimum_size.y = ALTURA_CONTROLE
	seletor_agua.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for opcao in ["Original", "Novos"]:
		seletor_agua.add_item(opcao)
	seletor_agua.select(Audio.sons_agua_opcao - 1)
	seletor_agua.item_selected.connect(func(i: int) -> void: Audio.definir_sons_agua(i + 1))
	linha_agua.add_child(seletor_agua)
	var ouvir := Button.new()
	ouvir.text = "Ouvir"
	ouvir.custom_minimum_size = Vector2(84, ALTURA_CONTROLE)
	ouvir.mouse_entered.connect(func(): Audio.efeito("ui_hover"))
	ouvir.pressed.connect(func() -> void:
		Audio.previa_efeito("passo_agua_v2" if Audio.sons_agua_opcao == 2 else "passo_agua"))
	linha_agua.add_child(ouvir)
	_pai = anterior_agua
	if not no_jogo:
		_escolha("Paisagem sonora do menu", ["Silêncio", "Mar", "Aves", "Mar e aves"], Audio.ambiente_menu_opcao, Audio.definir_ambiente_menu, PADRAO_PAISAGEM)
	_pai = direita
	_secao("Sons do vale")
	for camada: String in Audio.CAMADAS_AMBIENTE:
		_volume(String(Audio.ROTULOS_CAMADAS[camada]), float(Audio.volume_camadas[camada]), func(v: float) -> void: Audio.definir_volume_camada(camada, v), camada)


## Cenário: estilo visual do vale (Tripo ou procedural), o cursor e, no menu, o fundo e a fonte.
func _aba_cenario(esquerda: VBoxContainer, direita: VBoxContainer) -> void:
	_pai = esquerda
	_secao("Vale")
	_escolha("Estilo visual", ["Tripo (modelos gerados)", "Procedural (por código)"], 0 if Estilo.tripo() else 1, func(i: int) -> void:
		var novo: String = Estilo.TRIPO if i == 0 else Estilo.PROCEDURAL
		if novo != Estilo.modo:
			Estilo.definir(novo)
			estilo_mudou.emit(), 0)
	_escolha("Nomes dos personagens", ["Mostrar", "Ocultar"], 0 if Estilo.mostrar_nomes else 1, func(i: int) -> void: Estilo.definir_nomes(i == 0), 0)
	var visuais := ConfigFile.new()
	visuais.load(PREFERENCIAS_VISUAIS)
	var minimapa_ativo := bool(visuais.get_value("interface", "minimapa", true))
	_escolha("Minimapa", ["Mostrar", "Ocultar"], 0 if minimapa_ativo else 1, func(i: int) -> void:
		# Só grava: o minimapa relê esta preferência sozinho, a cada segundo no vale.
		var preferencias := ConfigFile.new()
		preferencias.load(PREFERENCIAS_VISUAIS)
		preferencias.set_value("interface", "minimapa", i == 0)
		if preferencias.save(PREFERENCIAS_VISUAIS) != OK:
			push_warning("Não foi possível salvar a preferência do minimapa."), 0)
	_escolha("Maré", ["Sem maré", "Ciclo do lugar", "Ciclo lento", "Rápida (ver acontecer)"], Mare.modo, Mare.definir_modo, 0)
	_pai = direita
	_secao("Interface")
	_escolha("Cursor do mouse", Tela.ROTULOS_CURSOR, Tela.cursor, Tela.definir_cursor, Tela.PADRAO_CURSOR)
	_escolha("Tamanho do texto", Tela.ROTULOS_TAMANHO, Tela.tamanho_texto, Tela.definir_tamanho_texto, Tela.PADRAO_TAMANHO)
	_escolha("Tamanho do HUD", Tela.ROTULOS_TAMANHO, Tela.tamanho_hud, Tela.definir_tamanho_hud, Tela.PADRAO_TAMANHO)
	if no_jogo:
		return
	_secao("Menu")
	var preferencias := ConfigFile.new()
	preferencias.load(PREFERENCIAS_VISUAIS)
	var sobrevoo := bool(preferencias.get_value("menu", "sobrevoo", true))
	var fonte := ler_fonte_menu(preferencias)
	_escolha("Cenário do menu", ["Parado", "Sobrevoo"], 1 if sobrevoo else 0, func(i: int) -> void:
		_salvar_preferencia("sobrevoo", i == 1)
		cenario_menu_mudou.emit(i == 1), PADRAO_CENARIO)
	_escolha("Fonte do menu", ROTULOS_FONTES, fonte, func(i: int) -> void:
		_salvar_preferencia("fonte_menu", i)
		fonte_menu_mudou.emit(i)
		_reconstruir(2), 0)


## Preferência de fonte do menu, com migração: a chave antiga "fonte" era de antes da
## Crônica entrar como primeira opção, então cada índice antigo anda uma casa.
static func ler_fonte_menu(preferencias: ConfigFile) -> int:
	if preferencias.has_section_key("menu", "fonte_menu"):
		return clampi(int(preferencias.get_value("menu", "fonte_menu", 0)), 0, FONTES_MENU.size() - 1)
	if preferencias.has_section_key("menu", "fonte"):
		return clampi(int(preferencias.get_value("menu", "fonte", 0)) + 1, 0, FONTES_MENU.size() - 1)
	return 0


func _salvar_preferencia(chave: String, valor: Variant) -> void:
	var preferencias := ConfigFile.new()
	preferencias.load(PREFERENCIAS_VISUAIS)
	preferencias.set_value("menu", chave, valor)
	if preferencias.save(PREFERENCIAS_VISUAIS) != OK:
		push_warning("Não foi possível salvar a preferência do menu: %s" % chave)


## Volume: alto-falante que silencia só este canal (como o botão de som do canto), a
## barra e o botão de voltar ao padrão. Silenciado, a barra esmaece e guarda o valor
## para quando voltar. Uma bolinha dourada na trilha marca o padrão, e a barra "gruda"
## nela ao passar perto (ímã).
func _volume(titulo: String, valor: float, ao_mudar: Callable, canal: String) -> void:
	var padrao := float(Audio.PADROES.get(canal, 1.0))
	var anterior := _abrir_campo()
	var rotulo := _rotulo_do_campo(titulo, "")
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 10)
	_pai.add_child(linha)
	var mudo := Button.new()
	mudo.toggle_mode = true
	mudo.theme_type_variation = &"BotaoIcone"
	mudo.custom_minimum_size = Vector2(ALTURA_CONTROLE, ALTURA_CONTROLE)
	mudo.focus_mode = Control.FOCUS_NONE
	var icone := AudioToggleIcon.new()
	icone.position = Vector2(6, 6)
	icone.size = Vector2(24, 24)
	icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mudo.add_child(icone)
	linha.add_child(mudo)
	var barra := HSlider.new()
	barra.min_value = 0
	barra.max_value = 1
	barra.step = 0.01
	barra.value = valor
	# Mesma altura do OptionButton: a trilha fica centrada e as linhas das colunas batem.
	barra.custom_minimum_size.y = ALTURA_CONTROLE
	barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(barra)
	# Marca do padrão: bolinha dourada desenhada sobre a trilha, atrás do puxador.
	var marca := Control.new()
	marca.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marca.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	barra.add_child(marca)
	marca.draw.connect(func() -> void:
		# Com o puxador em cima da marca, ela some (o próprio puxador está no padrão).
		if absf(barra.value - padrao) < 0.03:
			return
		var puxador := barra.get_theme_icon("grabber").get_size()
		var x := puxador.x * 0.5 + padrao * (barra.size.x - puxador.x)
		var y := barra.size.y * 0.5
		marca.draw_circle(Vector2(x, y), 5.0, Color("1b2420"))
		marca.draw_circle(Vector2(x, y), 3.6, Color("e2c47f")))
	barra.resized.connect(marca.queue_redraw)
	var restaurar := _botao_padrao(linha)
	var atualizar := func() -> void:
		var silenciado := Audio.canal_mudo(canal)
		icone.set_active(not silenciado)
		mudo.set_pressed_no_signal(silenciado)
		mudo.tooltip_text = tr("Ativar") if silenciado else tr("Silenciar")
		barra.modulate.a = 0.45 if silenciado else 1.0
		rotulo.text = "%s · %s" % [tr(titulo), tr("mudo") if silenciado else "%d%%" % roundi(barra.value * 100)]
		_marcar_padrao(restaurar, is_equal_approx(barra.value, padrao) and not silenciado, "%d%%" % roundi(padrao * 100))
		marca.queue_redraw()
	atualizar.call()
	mudo.toggled.connect(func(silenciado: bool) -> void:
		Audio.definir_mudo(canal, silenciado)
		Audio.efeito("ui_confirmar")
		atualizar.call())
	barra.value_changed.connect(func(v: float) -> void:
		# Ímã: perto da marca do padrão, a barra encaixa nela com um clique de madeira.
		if absf(v - padrao) < IMA and not is_equal_approx(v, padrao):
			barra.set_value_no_signal(padrao)
			v = padrao
			Audio.efeito("ui_hover")
		ao_mudar.call(v)
		atualizar.call())
	restaurar.pressed.connect(func() -> void:
		Audio.efeito("ui_confirmar")
		if Audio.canal_mudo(canal):
			Audio.definir_mudo(canal, false)
		barra.value = padrao
		atualizar.call())
	_pai = anterior


## Pé do modal, centralizado: "Restaurar estes" volta ao padrão só os volumes da aba
## aberta; "Restaurar todos", os das duas abas. Nos dois, nada fica silenciado.
func _restaurar_volumes() -> void:
	var linha := HBoxContainer.new()
	linha.alignment = BoxContainer.ALIGNMENT_CENTER
	linha.add_theme_constant_override("separation", 12)
	_content.add_child(linha)
	var desta_aba: Array = Audio.CAMADAS_AMBIENTE if aba == 1 else Audio.CANAIS_GERAIS
	_botao_restaurar(linha, "Restaurar estes", desta_aba,
		"Sons do vale voltam ao padrão." if aba == 1 else "Música, narração, falas, efeitos e ambiente voltam ao padrão.")
	_botao_restaurar(linha, "Restaurar todos", [], "Todos os volumes, das duas abas, voltam ao padrão.")


## Botão curto com o alto-falante à esquerda, para ligar o gesto aos volumes.
func _botao_restaurar(pai: Container, texto: String, canais: Array, dica: String) -> void:
	var botao := Button.new()
	botao.text = texto
	botao.tooltip_text = tr(dica)
	botao.custom_minimum_size = Vector2(200, ALTURA_CONTROLE)
	# Espaço à esquerda para o ícone em todos os estados do botão.
	for estado in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var caixa := (botao.get_theme_stylebox(estado) if tema == null else tema.get_stylebox(estado, "Button")).duplicate() as StyleBoxFlat
		if caixa:
			caixa.content_margin_left = 40
			botao.add_theme_stylebox_override(estado, caixa)
	var icone := AudioToggleIcon.new()
	icone.position = Vector2(12, 6)
	icone.size = Vector2(24, 24)
	icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	botao.add_child(icone)
	botao.mouse_entered.connect(func(): Audio.efeito("ui_hover"))
	botao.pressed.connect(func() -> void:
		Audio.efeito("ui_confirmar")
		Audio.restaurar_padroes(canais)
		_reconstruir(aba))
	pai.add_child(botao)


## Seleção com o botão de voltar ao padrão (`padrao`, índice da opção de fábrica) no
## fim da linha, apagado quando já está no padrão.
func _escolha(titulo: String, opcoes: Array, selecionada: int, ao_escolher: Callable, padrao: int = -1) -> void:
	var anterior := _abrir_campo()
	_rotulo_do_campo(titulo, titulo)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 10)
	_pai.add_child(linha)
	var seletor := OptionButton.new()
	seletor.custom_minimum_size.y = ALTURA_CONTROLE
	seletor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for opcao in opcoes:
		seletor.add_item(opcao)
	seletor.select(selecionada)
	linha.add_child(seletor)
	if padrao >= 0:
		var voltar := _botao_padrao(linha)
		var atualizar := func() -> void:
			_marcar_padrao(voltar, seletor.selected == padrao, tr(String(opcoes[padrao])))
		atualizar.call()
		seletor.item_selected.connect(func(_i: int) -> void: atualizar.call())
		voltar.pressed.connect(func() -> void:
			Audio.efeito("ui_confirmar")
			seletor.select(padrao)
			atualizar.call()
			ao_escolher.call(padrao))
	seletor.item_selected.connect(ao_escolher)
	_pai = anterior


## Botão quadrado com a seta circular, no fim de uma linha de ajuste.
func _botao_padrao(linha: Container) -> Button:
	var botao := Button.new()
	botao.theme_type_variation = &"BotaoIcone"
	botao.custom_minimum_size = Vector2(ALTURA_CONTROLE, ALTURA_CONTROLE)
	botao.focus_mode = Control.FOCUS_NONE
	var icone = HudIcon.new().configurar("restaurar")
	icone.name = "Icone"
	icone.position = Vector2(6, 6)
	icone.size = Vector2(24, 24)
	icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	botao.add_child(icone)
	linha.add_child(botao)
	return botao


## Apaga o botão de padrão quando a linha já está no padrão; senão a dica diz qual é.
func _marcar_padrao(botao: Button, no_padrao: bool, valor_padrao: String) -> void:
	botao.disabled = no_padrao
	botao.get_node("Icone").definir(not no_padrao)
	botao.tooltip_text = "" if no_padrao else tr("Voltar ao padrão (%s)") % valor_padrao


## Campo (rótulo + controle) num bloco de altura fixa: seleções e volumes ocupam a mesma
## altura, então os rótulos das duas colunas ficam na mesma linha.
func _abrir_campo() -> Container:
	var anterior := _pai
	var campo := VBoxContainer.new()
	campo.add_theme_constant_override("separation", 4)
	campo.custom_minimum_size.y = ALTURA_CAMPO
	anterior.add_child(campo)
	_pai = campo
	return anterior


## Título de seção de uma coluna, com respiro antes dos campos.
func _secao(titulo: String) -> void:
	var rotulo := _texto(titulo, 20)
	rotulo.add_theme_color_override("font_color", Color("e2c47f"))
	_pai.add_child(rotulo)
	var respiro := Control.new()
	respiro.custom_minimum_size.y = 6
	_pai.add_child(respiro)


## Rótulo de um campo com o botão "?" à esquerda, que abre a ajuda do campo.
func _rotulo_do_campo(titulo: String, texto: String) -> Label:
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 8)
	_pai.add_child(linha)
	if AjudaMenu.tem(titulo):
		var ajuda := Button.new()
		ajuda.text = "?"
		ajuda.theme_type_variation = &"BotaoAjuda"
		ajuda.custom_minimum_size = Vector2(24, 24)
		ajuda.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ajuda.add_theme_font_size_override("font_size", 13)
		ajuda.pressed.connect(func() -> void:
			Audio.efeito("ui_confirmar")
			_abrir_ajuda(titulo))
		linha.add_child(ajuda)
	var rotulo := _texto(texto, 16)
	rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(rotulo)
	return rotulo


## Modal de ajuda por cima de tudo: escurece o fundo, mostra título e texto do campo;
## fecha com ×, Esc (quem hospeda chama fechar_ajuda) ou clique fora.
func _abrir_ajuda(titulo: String) -> void:
	fechar_ajuda()
	_ajuda = Control.new()
	_ajuda.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ajuda.theme = tema if tema else TemaMenu.criar()
	_ajuda.process_mode = Node.PROCESS_MODE_ALWAYS
	_camada.add_child(_ajuda)
	var sombra := ColorRect.new()
	sombra.color = Color(0, 0, 0, 0.55)
	sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sombra.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			fechar_ajuda())
	_ajuda.add_child(sombra)
	var caixa := PanelContainer.new()
	caixa.add_theme_stylebox_override("panel", TemaMenu.estilo_painel())
	caixa.custom_minimum_size = Vector2(640, 0)
	caixa.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	caixa.grow_horizontal = Control.GROW_DIRECTION_BOTH
	caixa.grow_vertical = Control.GROW_DIRECTION_BOTH
	_ajuda.add_child(caixa)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 14)
	caixa.add_child(coluna)
	var fechar := cabecalho(coluna, titulo, fechar_ajuda, "Como funciona este ajuste.")
	var corpo := Label.new()
	corpo.text = AjudaMenu.texto(titulo, IdiomaMenu.indice())
	corpo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	corpo.custom_minimum_size.x = 584
	corpo.add_theme_font_size_override("font_size", 18)
	coluna.add_child(corpo)
	fechar.grab_focus()


func _texto(texto: String, tamanho: int) -> Label:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo.add_theme_font_size_override("font_size", tamanho)
	return rotulo


## Cabeçalho padrão dos modais: título e subtítulo à esquerda, botão com ícone no canto
## direito (× fecha a janela) e um divisor dourado antes do corpo. Devolve o botão do
## canto, para receber o foco.
static func cabecalho(pai: Container, titulo: String, acao: Callable, subtitulo: String = "", icone: String = "fechar") -> Button:
	var linha := HBoxContainer.new()
	linha.custom_minimum_size.y = ALTURA_CABECALHO
	pai.add_child(linha)
	var titulos := VBoxContainer.new()
	titulos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titulos.alignment = BoxContainer.ALIGNMENT_CENTER
	titulos.add_theme_constant_override("separation", 0)
	linha.add_child(titulos)
	var titulo_rotulo := Label.new()
	titulo_rotulo.text = titulo
	titulo_rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titulo_rotulo.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TITULO, 600, 2))
	titulo_rotulo.add_theme_font_size_override("font_size", 22)
	titulo_rotulo.add_theme_color_override("font_color", Identidade.CREME)
	titulos.add_child(titulo_rotulo)
	if not subtitulo.is_empty():
		var descricao := Label.new()
		descricao.text = subtitulo
		descricao.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_ITALICO, 500))
		descricao.add_theme_font_size_override("font_size", 17)
		descricao.add_theme_color_override("font_color", Color("c9b98f"))
		titulos.add_child(descricao)
	var botao := Button.new()
	botao.custom_minimum_size = Vector2(ALTURA_CABECALHO, ALTURA_CABECALHO)
	botao.theme_type_variation = &"BotaoIcone"
	botao.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var glifo = HudIcon.new().configurar(icone)
	glifo.position = Vector2(10, 10)
	glifo.size = Vector2(24, 24)
	glifo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	botao.add_child(glifo)
	botao.mouse_entered.connect(func(): Audio.efeito("ui_hover"))
	botao.tooltip_text = TranslationServer.translate("Fechar")
	botao.pressed.connect(func() -> void:
		Audio.efeito("ui_voltar")
		acao.call())
	linha.add_child(botao)
	pai.add_child(Identidade.divisor())
	return botao
