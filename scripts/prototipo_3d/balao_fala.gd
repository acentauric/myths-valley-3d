extends Control
## Balão de fala em tela, com tamanho fixo na interface (não encolhe com a distância),
## nome em cima e a ponta apontando para a cabeça de quem fala.
##
## NO DESENHO DO MYTHS' VALLEY. "Melhore o design dos balões de interação de acordo
## com o visual do MythsValley 3D." Era papel creme com a letra de fábrica da
## engine, o único pedaço da interface fora da identidade do jogo
## (`identidade.gd`). Agora é a LACA verde-escura dos menus e do HUD, com o filete
## de ouro, o nome em Cinzel, em versalete dourado, e a fala em Cormorant
## Garamond, a letra do resto do jogo; a ponta é da mesma laca, com o mesmo
## filete.
##
## A posição é escolhida entre cinco lugares em volta da cabeça (acima, acima à
## direita/esquerda, ao lado direito/esquerdo): ganha o que menos cobre quem fala, o
## jogador, os painéis do HUD, as placas de nome e as dicas do E. Some quando quem
## fala sai da câmera ou fica longe demais.
##
##
## COM PESO, E SEM PULAR
##
## "Devem deslizar com maior peso na tela, em vez de ficar gritando tentando se
## ajustar." (playtest da Build 9B, 06/10/2026) A posição era escolhida a CADA
## quadro, e a troca de lugar era um teletransporte. Agora:
##
##   - a caixa é uma mola (`suavizador_de_tela.gd`) presa ao canto de baixo do lugar
##     escolhido: desliza até ele, e quando a fala muda de altura (a página seguinte)
##     é o alto que se mexe, não o pé do balão, que fica junto da cabeça;
##   - o lugar só troca de canto depois de `PERMANENCIA_MINIMA` no mesmo, e mesmo
##     assim se o outro for bem melhor — nunca duas trocas em menos que isso;
##   - a ponta aponta para a cabeça por uma mola mais leve: acompanha quem fala sem
##     tremer com a câmera.
##
##
## SOBRE QUEM FALA (#224)
##
## "O balão do Pedro, que estava no canto esquerdo, aparece no canto direito superior, longe
## dele, sem ligação visual." O lugar era escolhido por uma soma de multas, e a multa por cobrir
## uma placa, uma dica ou o jogador (milhares de px²) valia mais que quilômetros de distância: o
## balão fugia para o canto vazio mais longe da tela só para não roçar numa dica. Agora:
##
##   1. O IDEAL É ACIMA DA CABEÇA, com a ponta para ela. `lugares` dá sete pontos de partida em
##      volta dela (centrado, deslocado de lado, ao lado do corpo), em ordem de preferência.
##   2. O QUE CAI SOBRE O HUD DESLIZA O MÍNIMO (`deslizar_do_hud`): para o lado, para cima ou
##      para baixo do painel que cobriria, o que anda menos, e inteiro na tela. Fora da tela (a
##      cabeça passou da borda) o balão encosta na borda do lado dela, e a ponta indica a direção.
##   3. A DISTÂNCIA À CABEÇA TEM PREÇO (`PESO_DA_DISTANCIA`, por px além da folga da ponta), e o
##      ROSTO de quem fala e do jogador pesa mais que o corpo (`PESO_DO_ROSTO`): o balão anda
##      umas dezenas de px para não cobrir um rosto, e nunca atravessa a tela por causa de uma dica
##      (a dica de quem fala já tem a folga embaixo, e a de outra coisa o balão sobe acima dela).
##   4. A ESCOLHA É UMA CONTA PURA, `avaliar`, que o portão `balao_sobre_quem_fala` confere com o
##      falante perto, longe, na borda e fora da tela.
##
## Na fala paginada o pé do balão fica onde estava (a mola segue o canto de baixo), e só o alto
## cresce ou encolhe com a página.
##
##
## FALA LONGA EM PÁGINAS
##
## Uma fala de 30 ou 40 s de leitura (quinze letras por segundo) virava um balão do
## tamanho da tela. Acima de `LINHAS_SEM_PAGINA` linhas, o balão mostra DUAS por vez
## (a última página, três, se sobrar uma), e as páginas passam no ritmo da fila de
## falas: a página é a fração do tempo da fala que já passou (`no_ar` / (`no_ar` +
## `resta`)), então a última página aparece no fim da fala, seja qual for o tempo que
## a fila deu a ela — e a página só avança, mesmo que a fila estique a fala. Sem a
## fila (um portão com um morador só), o tempo é o da leitura. Quem decide quanto a
## fala dura é a fila; aqui só se decide o desenho. O texto do `Label` continua o
## texto INTEIRO (`lines_skipped` e `max_lines_visible` escolhem as linhas), e uns
## pontinhos no cabeçalho dizem em que página se está.
##
##
## O E PASSA A PÁGINA (#220)
##
## Na fala que espera o E (`npc.espera_o_e`), o tempo para com o jogador perto (`fila_de_falas.gd`) e
## quem passa a página é ele: `passar_a_pagina` leva a fala ao ponto em que a seguinte começa. Um
## "E »" no canto do cabeçalho diz que há mais; na última página vira "E ×", o que fecha.
##
##
## SEM COBRIR NINGUÉM
##
## Roda por último no quadro (`process_priority` 20): lê o retângulo fresco das
## placas e das dicas, e a placa de nome é que cede ao balão (`placas_nomes.gd`).
## A dica de quem fala fica na folga entre o balão e a cabeça; e, se uma dica de
## outra coisa cairia por cima, o balão sobe acima dela.

const Identidade = preload("res://scripts/prototipo_3d/identidade.gd")
const SuavizadorDeTela = preload("res://scripts/prototipo_3d/suavizador_de_tela.gd")
const PopupsDoMundo = preload("res://scripts/prototipo_3d/popups_do_mundo.gd")
const FilaDeFalas = preload("res://scripts/prototipo_3d/fila_de_falas.gd")
const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")

const LARGURA_MAX := 300.0
## Só de perto (#90): era 45 u, e balões da praça inteira apareciam de longe.
const ALCANCE := 16.0
const MARGEM := 12.0
## Espaço livre no pé da tela (aviso do HUD).
const RODAPE := 110.0
## Distância entre o balão e a cabeça (onde cabe a ponta). Alta o bastante para a
## dica do E de quem fala (`tecla_dos_moradores`, logo acima da cabeça) caber
## embaixo do balão, e não por cima do pé da fala.
const FOLGA := 44.0
const PONTA := 26.0
## A laca dos menus, o ouro do filete, o rótulo dourado e a letra clara
## (`identidade.gd`).
const FUNDO := Color(Identidade.LACA, 0.95)
const FILETE := Color(Identidade.OURO, 0.8)
const NOME := Identidade.ROTULO
const LETRA := Identidade.TEXTO
const TAMANHO_DA_FALA := 17
## O PESO da caixa e da ponta.
const TEMPO_DE_SEGUIR := 0.3
const CORREIA := 200.0
## A troca de canto muda o alvo da caixa de uma vez (até uns 400 px): não é corte de câmera, e o
## que passa da correia volta devagar, para a caixa DESLIZAR até o canto novo.
const SALTO := 700.0
const PUXAO := 1200.0
const ZONA_MORTA := 3.0
const TEMPO_DA_PONTA := 0.12
## Quanto tempo o balão fica no canto escolhido antes de poder trocar (s de jogo).
const PERMANENCIA_MINIMA := 0.9
## A folga entre o balão e a dica do E que ele deixaria coberta.
const FOLGA_DAS_DICAS := 4.0
## Até esta quantidade de linhas a fala cabe de uma vez; acima, páginas de duas.
const LINHAS_SEM_PAGINA := 3
const LINHAS_POR_PAGINA := 2
## Largura de cada pontinho do indicador de página.
const ESPACO_DO_PONTO := 13.0
## O PREÇO DE CADA LUGAR (#224), em "notas" (menor leva). A área coberta (px²) de um painel do HUD
## pesa mais que tudo; o rosto de quem fala e o do jogador, bem mais que o corpo; a distância à
## cabeça, além da folga da ponta, custa por px; e o que o lugar andou para caber na tela ou fugir
## do HUD também. A fração do corpo que conta como rosto, do chapéu ao queixo, vem do alto.
const PESO_DO_HUD := 100.0
const PESO_DO_ROSTO := 14.0
const PESO_DO_ROSTO_DO_JOGADOR := 9.0
const PESO_DO_CORPO := 0.6
const PESO_DO_CORPO_DO_JOGADOR := 0.8
const PESO_DA_DICA := 0.8
const PESO_DA_PLACA := 0.3
## O "?"/"!" de missão sobre as cabeças (#216) fica por baixo de toda interface: o balão o evita.
const PESO_DO_MARCADOR := 1.0
const PESO_DA_DISTANCIA := 6.0
const PESO_DO_DESLOCAMENTO := 4.0
const PESO_DA_ORDEM := 30.0
const FRACAO_DO_ROSTO := 0.24

var alvo: Node3D
var altura := 2.0
var _painel: PanelContainer
var _nome: Label
var _texto: Label
var _ponta: Control
var _pontos: Control
## O "E »" (há mais) / "E ×" (fim) do cabeçalho: só aparece quando o E é quem passa a fala.
var _indicador_e: Label
var _escolha := 0
## Onde a cabeça está na tela, de verdade (a conta dos lugares) e com a mola (a ponta).
var _cabeca_tela := Vector2.ZERO
var _alvo_da_ponta := Vector2.ZERO
var _mola_da_caixa := SuavizadorDeTela.new()
var _mola_da_ponta := SuavizadorDeTela.new()
## O relógio do balão (só corre com ele na tela), e de quando é o lugar de agora.
var _relogio := 0.0
var _desde := 0.0
## Primeira posição desta fala (ou da volta à tela): vai direto, sem deslizar.
var _novo := true
## Quantas vezes o balão trocou de canto nesta fala (o portão confere).
var trocas := 0
## Quanto o balão fica no canto antes de trocar (o portão da falsificação zera isto).
var permanencia := PERMANENCIA_MINIMA
## As páginas da fala de agora: quantas linhas, quantas páginas, em qual está.
var _linhas := 1
var _paginas := 1
var _pagina := 0
## Sem a fila: quanto da fala já passou, e quanto ela dura.
var _lido_s := 0.0
var _duracao_s := 0.0


func configurar(novo_alvo: Node3D, nova_altura: float, nome: String) -> void:
	alvo = novo_alvo
	altura = nova_altura
	_nome.text = nome


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	# Por último no quadro: lê o retângulo fresco das placas e das dicas.
	process_priority = 20
	add_to_group(PopupsDoMundo.GRUPO_BALOES)
	_ponta = Control.new()
	_ponta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ponta.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ponta.draw.connect(_desenhar_ponta)
	add_child(_ponta)
	_painel = PanelContainer.new()
	_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = FUNDO
	estilo.border_color = FILETE
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(8)
	estilo.content_margin_left = 14
	estilo.content_margin_right = 14
	estilo.content_margin_top = 7
	estilo.content_margin_bottom = 9
	estilo.shadow_color = Color(0, 0, 0, 0.35)
	estilo.shadow_size = 6
	estilo.shadow_offset = Vector2(0, 2)
	_painel.add_theme_stylebox_override("panel", estilo)
	add_child(_painel)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 3)
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel.add_child(coluna)
	# O cabeçalho: o nome, e à direita os pontinhos da página (só na fala paginada).
	var cabecalho := HBoxContainer.new()
	cabecalho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.add_child(cabecalho)
	_nome = Label.new()
	_nome.uppercase = true
	_nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_nome.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TITULO, 600, 2))
	_nome.add_theme_font_size_override("font_size", 12)
	_nome.add_theme_color_override("font_color", NOME)
	cabecalho.add_child(_nome)
	_indicador_e = Label.new()
	_indicador_e.visible = false
	_indicador_e.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_indicador_e.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_indicador_e.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TITULO, 700, 1))
	_indicador_e.add_theme_font_size_override("font_size", 12)
	_indicador_e.add_theme_color_override("font_color", Identidade.OURO)
	cabecalho.add_child(_indicador_e)
	_pontos = Control.new()
	_pontos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pontos.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_pontos.visible = false
	_pontos.draw.connect(_desenhar_pontos)
	cabecalho.add_child(_pontos)
	# O filete de ouro entre o nome e a fala, como nos títulos dos menus.
	var filete := ColorRect.new()
	filete.color = Color(Identidade.OURO, 0.35)
	filete.custom_minimum_size = Vector2(0, 1)
	filete.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.add_child(filete)
	_texto = Label.new()
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TEXTO, 600))
	_texto.add_theme_font_size_override("font_size", TAMANHO_DA_FALA)
	_texto.add_theme_color_override("font_color", LETRA)
	_texto.add_theme_constant_override("line_spacing", -1)
	coluna.add_child(_texto)


func _notification(que: int) -> void:
	# Quem aparece (ou volta à tela, depois da caixa de fala) aparece no lugar.
	if que == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_novo = true


func mostrar(texto: String) -> void:
	_texto.text = texto
	var fonte := _texto.get_theme_font("font")
	var largura := fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, TAMANHO_DA_FALA).x + 2.0
	var largura_do_texto := minf(largura, LARGURA_MAX)
	_texto.custom_minimum_size = Vector2(largura_do_texto, 0.0)
	# O rótulo só sabe quantas linhas tem na largura em que vai ficar: diz-se a ele já.
	_texto.size = Vector2(largura_do_texto, _texto.size.y)
	_lido_s = 0.0
	_duracao_s = FilaDeFalas.duracao(texto)
	_paginar()
	_painel.reset_size()
	visible = texto != ""
	_novo = true
	_escolha = 0
	trocas = 0
	_posicionar(0.0)


func esconder() -> void:
	visible = false


## O retângulo do balão na tela, ou vazio sem ele.
func retangulo() -> Rect2:
	if not visible or not _painel.visible:
		return Rect2()
	return Rect2(_painel.global_position, _painel.size)


## O balão está sendo visto: com fala, ao alcance e na frente da câmera. Longe
## ou atrás, a raiz fica `visible` e só o painel se recolhe (`_posicionar`).
func a_vista() -> bool:
	return visible and _painel.visible


## HÁ MAIS PÁGINAS depois da de agora?
func ha_mais() -> bool:
	return _paginas > 1 and _pagina < _paginas - 1


## Em que fração (0 a 1) do tempo da fala começa a página seguinte, ou -1 na última (ou sem páginas).
## Um tiquinho depois da divisa, para a conta de `_process` cair na página nova e não na de antes.
func fracao_da_proxima_pagina() -> float:
	if not ha_mais():
		return -1.0
	return minf((_pagina + 1) * LINHAS_POR_PAGINA / float(_linhas) + 0.002, 0.999)


## O E PASSA A PÁGINA (#220): vai à seguinte e leva o tempo da fala até onde ela começa, na fila ou
## no relógio do próprio balão. Falso na última página (ou sem páginas): o E ali é de fechar.
func passar_a_pagina() -> bool:
	var fracao := fracao_da_proxima_pagina()
	if fracao < 0.0:
		return false
	_lido_s = fracao * maxf(_duracao_s, 0.1)
	var fila := FilaDeFalas.da(self)
	if fila != null:
		fila.ajustar(alvo, fracao)
	_aplicar_pagina(_pagina + 1)
	return true


## Em que página está (0 é a primeira) e quantas são.
func pagina() -> int:
	return _pagina


func paginas() -> int:
	return _paginas


## O "E »" / "E ×" do cabeçalho: só quando quem fala espera o E (`npc.espera_o_e`).
func _atualizar_o_indicador() -> void:
	var espera: bool = alvo != null and is_instance_valid(alvo) and alvo.has_method("espera_o_e") \
		and bool(alvo.call("espera_o_e"))
	if espera:
		_indicador_e.text = "%s %s" % [Atalhos.letra("interagir"), "»" if ha_mais() else "×"]
	if _indicador_e.visible != espera:
		_indicador_e.visible = espera
		_painel.reset_size()


func _process(delta: float) -> void:
	if not visible:
		return
	_relogio += delta
	_lido_s += delta
	_atualizar_o_indicador()
	if _paginas > 1:
		var indice := mini(floori(_fracao_da_fala() * _linhas / float(LINHAS_POR_PAGINA)), _paginas - 1)
		# A página só avança: a fila pode esticar a fala, e a fração, voltar.
		if indice > _pagina:
			_aplicar_pagina(indice)
	_posicionar(delta)


## Quanto da fala já passou (0 a 1): pelo tempo da fila, que é quem a segura no ar; sem
## ela, pelo tempo de ler.
func _fracao_da_fala() -> float:
	var fila := FilaDeFalas.da(self)
	if fila != null:
		var no_ar: Dictionary = fila.atual()
		if not no_ar.is_empty() and no_ar.get("falante") == alvo and not bool(no_ar.get("modal", false)):
			var passou := float(no_ar.get("no_ar", 0.0))
			var total := passou + maxf(float(no_ar.get("resta", 0.0)), 0.0)
			return clampf(passou / total, 0.0, 1.0) if total > 0.0 else 0.0
	return clampf(_lido_s / maxf(_duracao_s, 0.1), 0.0, 1.0)


## Conta as linhas da fala na largura dela e a parte em páginas.
func _paginar() -> void:
	_texto.lines_skipped = 0
	_texto.max_lines_visible = -1
	_texto.clip_text = false
	_texto.custom_minimum_size.y = 0.0
	_linhas = maxi(_texto.get_line_count(), 1) if _texto.is_inside_tree() else 1
	_paginas = 1
	if _linhas > LINHAS_SEM_PAGINA:
		_paginas = maxi(floori(_linhas / float(LINHAS_POR_PAGINA)), 2)
	_pagina = 0
	_pontos.visible = _paginas > 1
	_aplicar_pagina(0)


## Mostra a página `indice`: as linhas dela, e só elas, com a altura delas.
func _aplicar_pagina(indice: int) -> void:
	_pagina = indice
	if _paginas <= 1:
		return
	var primeira := indice * LINHAS_POR_PAGINA
	var nesta := (_linhas - primeira) if indice == _paginas - 1 else LINHAS_POR_PAGINA
	# `max_lines_visible` esconde as linhas, mas o Label continua com a altura de todas:
	# sem cortar, a caixa ficaria do tamanho da fala inteira. A altura é dita a ele.
	_texto.lines_skipped = primeira
	_texto.max_lines_visible = nesta
	_texto.clip_text = true
	var da_linha := float(_texto.get_line_height())
	var entre := float(_texto.get_theme_constant("line_spacing"))
	_texto.custom_minimum_size.y = nesta * da_linha + (nesta - 1) * entre
	_pontos.custom_minimum_size = Vector2(_paginas * ESPACO_DO_PONTO, 12.0)
	_pontos.queue_redraw()
	_painel.reset_size()


func _posicionar(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or alvo == null:
		return
	var cabeca := alvo.global_position + Vector3(0, altura, 0)
	var longe := camera.global_position.distance_to(cabeca) > ALCANCE
	var atras := camera.is_position_behind(cabeca)
	_painel.visible = not (longe or atras)
	_ponta.visible = _painel.visible
	if not _painel.visible:
		# Quando voltar à câmera, volta no lugar.
		_novo = true
		return
	var tela := get_viewport().get_visible_rect().size
	# O rótulo com quebra só sabe a própria altura depois de ter largura: encolhe o
	# painel ao mínimo atual a cada quadro para não herdar uma altura errada.
	_painel.reset_size()
	_painel.scale = Vector2.ONE * Tela.escala_componente("fala")
	var tamanho := _painel.size * _painel.scale
	_cabeca_tela = camera.unproject_position(cabeca)
	var falante := _retangulo_do_corpo(camera, alvo, altura)
	var jogador := Rect2()
	var no_jogador := get_tree().get_first_node_in_group("map_player") as Node3D
	if no_jogador != null and no_jogador != alvo:
		jogador = _retangulo_do_corpo(camera, no_jogador, 1.8)
	var hud := PopupsDoMundo.paineis_do_hud(tela, self, PopupsDoMundo.PRIORIDADE_FALA)
	var placas := PopupsDoMundo.retangulos(self, PopupsDoMundo.GRUPO_PLACAS)
	var dicas := PopupsDoMundo.retangulos(self, PopupsDoMundo.GRUPO_DICAS)
	# Os lugares de partida, já deslizados do HUD e inteiros na tela, e a nota de cada um (#224).
	# O "?"/"!" de missão sobre as cabeças (#216) também entra na conta.
	var marcadores := PopupsDoMundo.retangulos_dos_marcadores(self)
	var avaliacao := avaliar(_cabeca_tela, tamanho, tela, {
		"falante": falante, "jogador": jogador, "hud": hud, "dicas": dicas, "placas": placas,
		"marcadores": marcadores})
	var caixas: Array = avaliacao["caixas"]
	var notas: Array[float] = []
	notas.assign(avaliacao["notas"])
	# A PERMANÊNCIA: o lugar só troca depois de `permanencia` no mesmo (a primeira
	# escolha é livre), e só se o novo for bem melhor que o atual.
	if _novo or _escolha >= notas.size():
		_escolha = notas.find(notas.min())
		_desde = _relogio
	else:
		var nova := decidir_canto(notas, _escolha, _relogio - _desde, permanencia)
		if nova != _escolha:
			_escolha = nova
			_desde = _relogio
			trocas += 1
	# A mola segue o CANTO DE BAIXO do lugar: a página de menos linhas encolhe o balão
	# pelo alto, e o pé dele não sai de perto da cabeça.
	var canto_de_baixo: Vector2 = (caixas[_escolha] as Rect2).position + Vector2(0.0, tamanho.y)
	if _novo:
		_mola_da_caixa.reiniciar(canto_de_baixo)
		_mola_da_ponta.reiniciar(_cabeca_tela)
	var canto := _mola_da_caixa.seguir(canto_de_baixo, delta, TEMPO_DE_SEGUIR,
		SuavizadorDeTela.VELOCIDADE_MAXIMA, ZONA_MORTA, CORREIA, SALTO, PUXAO)
	_alvo_da_ponta = _mola_da_ponta.seguir(_cabeca_tela, delta, TEMPO_DA_PONTA,
		SuavizadorDeTela.VELOCIDADE_MAXIMA, 1.5, 40.0)
	var caixa_final := dentro_da_tela(Rect2(canto - Vector2(0.0, tamanho.y), tamanho), tela)
	# DEIXA LUGAR PARA A DICA: a de outra coisa que cairia por cima fica por baixo dele.
	caixa_final = dentro_da_tela(PopupsDoMundo.afastar_de(caixa_final, dicas, FOLGA_DAS_DICAS), tela)
	# E o marcador de missão: o balão sobe para cima dele em vez de o esconder (#216).
	caixa_final = dentro_da_tela(PopupsDoMundo.afastar_de(caixa_final, marcadores, FOLGA_DAS_DICAS), tela)
	# A mola também pode atravessar o HUD ao trocar de canto. Durante essa
	# travessia, use o destino livre para manter a fala legível.
	for obstaculo in hud:
		if caixa_final.intersects(obstaculo):
			caixa_final = caixas[_escolha] as Rect2
			break
	_painel.position = caixa_final.position.round()
	_novo = false
	_ponta.queue_redraw()


## A REGRA DE TROCAR DE CANTO, pura: o canto de agora, ou o melhor das `notas` (menor
## nota leva) se o balão já passou `permanencia_s` no atual (`parado_s`) E o outro é bem
## melhor que ele. Pública para o portão conferir que notas que mudam de favorito a cada
## quadro não trocam o canto mais que uma vez por permanência.
func decidir_canto(notas: Array[float], atual: int, parado_s: float, permanencia_s: float) -> int:
	var melhor := notas.find(notas.min())
	if melhor != atual and parado_s >= permanencia_s and notas[melhor] < notas[atual] * 0.75 - 40.0:
		return melhor
	return atual


## Os lugares de partida do balão (canto superior esquerdo de cada um) em volta da cabeça `c`, em ordem
## de preferência: acima e centrado; acima, deslocado de lado até a cabeça ficar perto da quina; acima
## com a quina na cabeça; ao lado do corpo `falante`, na altura da cabeça. O pé do balão fica sempre
## `FOLGA` acima da cabeça, de qualquer altura que ele tenha: a página que encolhe o balão não o desloca.
static func lugares(c: Vector2, tamanho: Vector2, falante: Rect2) -> Array[Vector2]:
	var topo := c.y - tamanho.y - FOLGA
	var largura := tamanho.x
	var saida: Array[Vector2] = [
		Vector2(c.x - largura * 0.5, topo),
		Vector2(c.x - largura * 0.5 + largura * 0.28, topo),
		Vector2(c.x - largura * 0.5 - largura * 0.28, topo),
		Vector2(c.x + 18.0, topo),
		Vector2(c.x - largura - 18.0, topo),
	]
	# Sem corpo à vista (cabeça fora da tela, por exemplo), o corpo é a própria cabeça.
	var corpo := falante if falante.size != Vector2.ZERO else Rect2(c - Vector2(15.0, 0.0), Vector2(30.0, 30.0))
	saida.append(Vector2(corpo.end.x + FOLGA, c.y - tamanho.y * 0.5))
	saida.append(Vector2(corpo.position.x - tamanho.x - FOLGA, c.y - tamanho.y * 0.5))
	return saida


## `caixa` inteira na tela (com a margem e o pé livre do rodapé).
static func dentro_da_tela(caixa: Rect2, tela: Vector2) -> Rect2:
	caixa.position.x = clampf(caixa.position.x, MARGEM, maxf(tela.x - caixa.size.x - MARGEM, MARGEM))
	caixa.position.y = clampf(caixa.position.y, MARGEM, maxf(tela.y - caixa.size.y - RODAPE, MARGEM))
	return caixa


## `caixa` fora dos painéis do HUD, deslizando o MÍNIMO: para cada painel que ela cobriria, vai para o lado
## (esquerda ou direita), para cima ou para baixo dele — a saída que anda menos, e que fica inteira na
## tela. Pura. Sem saída que livre todos, fica na que cobre menos.
static func deslizar_do_hud(caixa: Rect2, paineis: Array[Rect2], tela: Vector2, folga: float) -> Rect2:
	var atual := dentro_da_tela(caixa, tela)
	for _passe in 4:
		var cobre := Rect2()
		for painel in paineis:
			if painel.size != Vector2.ZERO and atual.grow(-0.5).intersects(painel):
				cobre = painel
				break
		if cobre.size == Vector2.ZERO:
			return atual
		var saidas: Array[Rect2] = [
			Rect2(Vector2(cobre.position.x - folga - atual.size.x, atual.position.y), atual.size),
			Rect2(Vector2(cobre.end.x + folga, atual.position.y), atual.size),
			Rect2(Vector2(atual.position.x, cobre.position.y - folga - atual.size.y), atual.size),
			Rect2(Vector2(atual.position.x, cobre.end.y + folga), atual.size),
		]
		var melhor := atual
		var menor := INF
		for saida in saidas:
			var dentro := dentro_da_tela(saida, tela)
			# Cobrir o painel de novo (a tela é pequena demais) é a pior saída; as outras valem o que andam.
			var custo := dentro.position.distance_to(atual.position) + _area_coberta(dentro, paineis) * 0.05
			if custo < menor:
				menor = custo
				melhor = dentro
		atual = melhor
	return atual


static func _area_coberta(caixa: Rect2, outros: Array[Rect2]) -> float:
	var area := 0.0
	for outro in outros:
		area += PopupsDoMundo.cobertura(caixa, outro)
	return area


## A distância (px) de um ponto a um retângulo; zero dentro dele.
static func distancia_ate(caixa: Rect2, ponto: Vector2) -> float:
	var dx := maxf(maxf(caixa.position.x - ponto.x, 0.0), ponto.x - caixa.end.x)
	var dy := maxf(maxf(caixa.position.y - ponto.y, 0.0), ponto.y - caixa.end.y)
	return Vector2(dx, dy).length()


## O rosto dentro do retângulo do corpo: do chapéu ao queixo, sem as beiradas. Vazio sem corpo.
static func rosto_de(corpo: Rect2) -> Rect2:
	if corpo.size == Vector2.ZERO:
		return Rect2()
	return Rect2(corpo.position.x + corpo.size.x * 0.15, corpo.position.y, corpo.size.x * 0.7, corpo.size.y * FRACAO_DO_ROSTO)


## ONDE PÔR O BALÃO (#224), a conta pura: os sete lugares de partida de `lugares`, cada um deslizado do HUD e
## posto inteiro na tela, e a nota de cada um (menor leva). `contexto`: "falante" e "jogador" (os retângulos
## dos corpos na tela, vazios se não há), "hud" (os painéis), "dicas" e "placas". Devolve {"caixas", "notas"}
## com a mesma ordem de `lugares`: a ordem é fixa (o índice é a identidade do lugar para a permanência).
static func avaliar(c: Vector2, tamanho: Vector2, tela: Vector2, contexto: Dictionary) -> Dictionary:
	var falante: Rect2 = contexto.get("falante", Rect2())
	var jogador: Rect2 = contexto.get("jogador", Rect2())
	var hud: Array[Rect2] = []
	hud.assign(contexto.get("hud", []))
	var dicas: Array[Rect2] = []
	dicas.assign(contexto.get("dicas", []))
	var placas: Array[Rect2] = []
	placas.assign(contexto.get("placas", []))
	var marcadores: Array[Rect2] = []
	marcadores.assign(contexto.get("marcadores", []))
	var pontos := lugares(c, tamanho, falante)
	var caixas: Array[Rect2] = []
	var notas: Array[float] = []
	for indice in pontos.size():
		var ideal := Rect2(pontos[indice], tamanho)
		var caixa := deslizar_do_hud(ideal, hud, tela, MARGEM)
		var nota := _area_coberta(caixa, hud) * PESO_DO_HUD
		nota += PopupsDoMundo.cobertura(caixa, rosto_de(falante)) * PESO_DO_ROSTO
		nota += PopupsDoMundo.cobertura(caixa, rosto_de(jogador)) * PESO_DO_ROSTO_DO_JOGADOR
		nota += PopupsDoMundo.cobertura(caixa, falante) * PESO_DO_CORPO
		nota += PopupsDoMundo.cobertura(caixa, jogador) * PESO_DO_CORPO_DO_JOGADOR
		nota += _area_coberta(caixa, dicas) * PESO_DA_DICA
		nota += _area_coberta(caixa, placas) * PESO_DA_PLACA
		nota += _area_coberta(caixa, marcadores) * PESO_DO_MARCADOR
		# Quanto o lugar ficou longe da cabeça, além da folga que a ponta pede.
		nota += maxf(distancia_ate(caixa, c) - FOLGA, 0.0) * PESO_DA_DISTANCIA
		# O que andou para caber na tela ou sair do HUD, e a ordem de preferência.
		nota += caixa.position.distance_to(pontos[indice]) * PESO_DO_DESLOCAMENTO + indice * PESO_DA_ORDEM
		caixas.append(caixa)
		notas.append(nota)
	return {"caixas": caixas, "notas": notas}


## Retângulo em tela do corpo de alguém (da cabeça aos pés, largura ~ 45% da altura).
func _retangulo_do_corpo(camera: Camera3D, corpo: Node3D, alto: float) -> Rect2:
	var pes := corpo.global_position
	var topo := pes + Vector3(0, alto, 0)
	if camera.is_position_behind(pes) or camera.is_position_behind(topo):
		return Rect2()
	var p_topo := camera.unproject_position(topo)
	var p_pes := camera.unproject_position(pes)
	var altura_tela := absf(p_pes.y - p_topo.y)
	var largura := maxf(30.0, altura_tela * 0.45)
	return Rect2(p_topo.x - largura * 0.5, minf(p_topo.y, p_pes.y), largura, maxf(altura_tela, 30.0))


## Ponta do balão: sai da borda mais perto da cabeça de quem fala e aponta para ela.
func _desenhar_ponta() -> void:
	var caixa := Rect2(_painel.position, _painel.size * _painel.scale)
	var alvo_ponta := _alvo_da_ponta
	var base := Vector2(clampf(alvo_ponta.x, caixa.position.x + 16.0, caixa.end.x - 16.0), clampf(alvo_ponta.y, caixa.position.y + 12.0, caixa.end.y - 12.0))
	var lado := Vector2.ZERO
	if alvo_ponta.y > caixa.end.y:
		base.y = caixa.end.y - 1.0
		lado = Vector2(1, 0)
	elif alvo_ponta.y < caixa.position.y:
		base.y = caixa.position.y + 1.0
		lado = Vector2(1, 0)
	elif alvo_ponta.x > caixa.end.x:
		base.x = caixa.end.x - 1.0
		lado = Vector2(0, 1)
	elif alvo_ponta.x < caixa.position.x:
		base.x = caixa.position.x + 1.0
		lado = Vector2(0, 1)
	else:
		return
	var direcao := (alvo_ponta - base).normalized()
	var bico := base + direcao * minf(PONTA, base.distance_to(alvo_ponta))
	var a := base - lado * 8.0
	var b := base + lado * 8.0
	_ponta.draw_colored_polygon(PackedVector2Array([a, b, bico]), FUNDO)
	_ponta.draw_polyline(PackedVector2Array([a, bico, b]), FILETE, 1.0, true)


## Os pontinhos da página: o da página de agora cheio, os outros apagados.
func _desenhar_pontos() -> void:
	if _paginas <= 1:
		return
	var meio := _pontos.size.y * 0.5
	for indice in _paginas:
		# A página que ainda não passou fica legível (0,45), e não apagada: o jogador vê quantas faltam (#215).
		var cor := Color(Identidade.OURO, 0.98 if indice == _pagina else 0.45)
		_pontos.draw_circle(Vector2(ESPACO_DO_PONTO * (indice + 0.5), meio), 4.0 if indice == _pagina else 3.0, cor)
