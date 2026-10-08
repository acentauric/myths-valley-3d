extends Node
## Modo da janela do jogo: tela cheia ou janela.
##
## O jogo abre em tela cheia (`window/size/mode` no project.godot), sem piscar
## uma janela pequena antes. F11 alterna de qualquer tela — escolha de idioma,
## menu ou vale —, como no navegador; o botão do canto do menu faz o mesmo e
## ensina o atalho na dica. A escolha fica em `preferencias_visuais.cfg`, ao
## lado do idioma, e vale para as próximas aberturas.
##
## Em janela, o jogo ocupa FRACAO_JANELA da área útil do monitor, em 16:9: a
## resolução de desenho (1280×720) é só a referência do layout, e a janela não
## precisa ficar desse tamanho.
##
## O cursor do jogo também mora aqui. É cursor de hardware, que o sistema desenha
## mesmo quando a montagem do vale segura os quadros. O jogador escolhe o conjunto
## em AJUSTAR > Cenário; todos seguem a mesma regra: seta para apontar e mão com o
## indicador para clicar. O Clássico vem de `tools/prototipo_3d/cursor/gerar_cursor.py`;
## os demais, de `desenhos.js` pelo `gerar_cursores.js`, na mesma pasta.
##
## E também o tamanho da interface, os dois em AJUSTAR > Cenário > Interface:
## "Tamanho do HUD" escala a coluna de botões do canto (BotaoCanto) e "Tamanho do
## texto" multiplica o tamanho de fonte de todo texto na tela, a partir do tamanho
## original de cada um. No Médio (fator 1) nada é tocado.

signal modo_mudou(cheia: bool)
signal componentes_mudaram

const COMPONENTES := ["missao", "relogio", "vida", "folego", "vigor", "minimapa", "mao", "fala", "nomes", "interacao", "avisos", "mochila", "caderneta", "almanaque", "talentos", "social", "pausa", "dialogo", "atalhos", "mapa", "controles", "apoios", "ajuda", "menu", "historico", "ajustes", "vagas", "sobre", "travessia", "modelos", "pergunta", "folheto"]
const ESCALAS_COMPONENTE := [0.65, 0.8, 1.0, 1.15, 1.3, 1.5]
## Degrau de ESCALAS_COMPONENTE usado quando o jogador não escolheu nada (100%).
const PADRAO_COMPONENTE := 2
## Componentes cujo padrão é outro degrau: a missão nasce em 80% (#176).
## Quem já gravou um tamanho para eles (inclusive 100%) mantém a escolha.
const PADROES_COMPONENTE := {"missao": 1}
var tamanhos_componentes: Dictionary = {}


## O degrau de fábrica do componente: o do dicionário ou, sem entrada, o geral.
## É o valor para onde o ↺ de Ajustes e o "Restaurar" voltam.
func padrao_componente(chave: String) -> int:
	return int(PADROES_COMPONENTE.get(chave, PADRAO_COMPONENTE))


func tamanho_componente(chave: String) -> int:
	return int(tamanhos_componentes.get(chave, padrao_componente(chave)))


func escala_componente(chave: String) -> float:
	return float(ESCALAS_COMPONENTE[tamanho_componente(chave)])


func definir_componente(chave: String, indice: int) -> void:
	if chave not in COMPONENTES:
		return
	tamanhos_componentes[chave] = clampi(indice, 0, ESCALAS_COMPONENTE.size() - 1)
	var preferencias := ConfigFile.new()
	preferencias.load(ARQUIVO)
	preferencias.set_value("componentes", chave, tamanhos_componentes[chave])
	if preferencias.save(ARQUIVO) != OK:
		push_warning("Não foi possível salvar a escala da interface.")
	componentes_mudaram.emit()
	load("res://scripts/prototipo_3d/botao_canto.gd").reaplicar(get_tree())


func restaurar_componentes() -> void:
	var preferencias := ConfigFile.new()
	preferencias.load(ARQUIVO)
	tamanhos_componentes.clear()
	if preferencias.has_section("componentes"):
		preferencias.erase_section("componentes")
	preferencias.save(ARQUIVO)
	componentes_mudaram.emit()
	load("res://scripts/prototipo_3d/botao_canto.gd").reaplicar(get_tree())


## Escala texto, ícones e área clicável juntos. O pivô preserva o canto/centro
## escolhido; o limite da janela impede ampliar um painel para fora da tela.
func vincular_componente(controle: Control, chave: String, ancora := Vector2.ZERO, limitar := true) -> void:
	controle.set_meta("componente_interface", chave)
	controle.set_meta("ancora_interface", ancora)
	controle.set_meta("limitar_interface", limitar)
	if controle.has_meta("aplicar_interface"):
		var existente: Callable = controle.get_meta("aplicar_interface")
		existente.call_deferred()
		return
	var referencia: WeakRef = weakref(controle)
	var aplicar := func() -> void:
		var atual := referencia.get_ref() as Control
		if atual == null or not atual.is_inside_tree():
			return
		var fator := escala_componente(str(atual.get_meta("componente_interface")))
		atual.pivot_offset = atual.size * (atual.get_meta("ancora_interface") as Vector2)
		if bool(atual.get_meta("limitar_interface")) and atual.size.x > 0.0 and atual.size.y > 0.0:
			var janela := atual.get_viewport_rect().size
			var pivo := atual.get_global_transform() * atual.pivot_offset
			var limites: Rect2 = atual.get_meta("limites_interface", Rect2(Vector2.ZERO, atual.size))
			var antes := atual.pivot_offset - limites.position
			var depois := limites.end - atual.pivot_offset
			if antes.x > 0.0: fator = minf(fator, maxf(0.1, (pivo.x - 14.0) / antes.x))
			if antes.y > 0.0: fator = minf(fator, maxf(0.1, (pivo.y - 14.0) / antes.y))
			if depois.x > 0.0: fator = minf(fator, maxf(0.1, (janela.x - pivo.x - 14.0) / depois.x))
			if depois.y > 0.0: fator = minf(fator, maxf(0.1, (janela.y - pivo.y - 14.0) / depois.y))
		atual.scale = Vector2.ONE * fator
		# A moldura é irmã do painel: acompanha também mudanças só de escala.
		atual.item_rect_changed.emit()
	controle.set_meta("aplicar_interface", aplicar)
	controle.resized.connect(aplicar)
	componentes_mudaram.connect(aplicar)
	controle.tree_exiting.connect(func() -> void:
		if componentes_mudaram.is_connected(aplicar):
			componentes_mudaram.disconnect(aplicar))
	aplicar.call_deferred()

const ARQUIVO := "user://preferencias_visuais.cfg"
const FRACAO_JANELA := 0.8
## Conjuntos de cursor, na ordem do AJUSTAR: [seta, ponto quente, mão, ponto quente].
const CURSORES := [
	["res://assets/prototipo_3d/identidade/cursor_seta.png", Vector2(4, 3), "res://assets/prototipo_3d/identidade/cursor_mao.png", Vector2(16, 2)],
	["res://assets/prototipo_3d/identidade/cursores/ouro_seta.png", Vector2(4, 3), "res://assets/prototipo_3d/identidade/cursores/ouro_mao.png", Vector2(17, 2)],
	["res://assets/prototipo_3d/identidade/cursores/azulejo_seta.png", Vector2(4, 3), "res://assets/prototipo_3d/identidade/cursores/azulejo_mao.png", Vector2(17, 2)],
	["res://assets/prototipo_3d/identidade/cursores/talha_seta.png", Vector2(4, 3), "res://assets/prototipo_3d/identidade/cursores/talha_mao.png", Vector2(17, 2)],
	["res://assets/prototipo_3d/identidade/cursores/pergaminho_seta.png", Vector2(4, 3), "res://assets/prototipo_3d/identidade/cursores/pergaminho_mao.png", Vector2(17, 2)],
	["res://assets/prototipo_3d/identidade/cursores/lampiao_seta.png", Vector2(4, 3), "res://assets/prototipo_3d/identidade/cursores/lampiao_mao.png", Vector2(17, 2)],
]
const ROTULOS_CURSOR := ["Clássico", "Ouro polido", "Azulejo", "Talha com punho", "Pergaminho", "Luz do lampião"]
const PADRAO_CURSOR := 1
const ROTULOS_TAMANHO := ["Pequeno", "Médio", "Grande", "Muito grande"]
const ESCALAS_TEXTO := [0.9, 1.0, 1.15, 1.3]
## No Grande o HUD volta ao tamanho de antes de 04/10/2026 (placas de 52).
const ESCALAS_HUD := [0.85, 1.0, 1.3, 1.5]
const PADRAO_TAMANHO := 1
## Propriedades de tamanho de fonte que o "Tamanho do texto" multiplica.
const FONTES := ["font_size", "normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"]

var cheia := true
var cursor := PADRAO_CURSOR
var tamanho_texto := PADRAO_TAMANHO
var tamanho_hud := PADRAO_TAMANHO
var escala_texto := 1.0
var escala_hud := 1.0
## O MONITOR (#95): com mais de um, o jogador escolhe em qual o jogo abre
## (AJUSTAR › Interface › Monitor) — antes só havia o F11 e arrastar a janela.
## A escolha fica salva e a janela vai na hora, em tela cheia ou em janela. Sem
## escolha, ou com uma tela que já não existe, é o monitor principal.
var monitor := 0


## Um item por tela ligada, na ordem do sistema: "Monitor 1 · 1920×1080".
func monitores() -> Array[String]:
	var lista: Array[String] = []
	for i in maxi(1, DisplayServer.get_screen_count()):
		var tamanho := DisplayServer.screen_get_size(i) if i < DisplayServer.get_screen_count() else Vector2i.ZERO
		lista.append("Monitor %d · %d×%d" % [i + 1, tamanho.x, tamanho.y] if tamanho != Vector2i.ZERO else "Monitor %d" % (i + 1))
	return lista


## O monitor principal do sistema: o padrão, e o destino de uma escolha que já
## não existe.
static func monitor_padrao() -> int:
	return clampi(DisplayServer.get_primary_screen(), 0, maxi(1, DisplayServer.get_screen_count()) - 1)


## Monitor salvo; sem escolha, ou fora das telas ligadas, o principal.
static func monitor_preferido() -> int:
	var preferencias := ConfigFile.new()
	if preferencias.load(ARQUIVO) == OK:
		var salvo := int(preferencias.get_value("tela", "monitor", -1))
		if salvo >= 0 and salvo < maxi(1, DisplayServer.get_screen_count()):
			return salvo
	return monitor_padrao()


## Leva a janela ao monitor na hora e guarda a escolha para as próximas aberturas.
func definir_monitor(indice: int) -> void:
	monitor = clampi(indice, 0, maxi(1, DisplayServer.get_screen_count()) - 1)
	var preferencias := ConfigFile.new()
	preferencias.load(ARQUIVO)
	preferencias.set_value("tela", "monitor", monitor)
	if preferencias.save(ARQUIVO) != OK:
		push_warning("Não foi possível salvar o monitor.")
	_aplicar()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	cheia = preferida()
	monitor = monitor_preferido()
	_aplicar()
	cursor = cursor_preferido()
	_aplicar_cursor()
	tamanho_texto = _tamanho_salvo("tamanho_texto")
	tamanho_hud = _tamanho_salvo("tamanho_hud")
	escala_texto = float(ESCALAS_TEXTO[tamanho_texto])
	escala_hud = float(ESCALAS_HUD[tamanho_hud])
	var preferencias := ConfigFile.new()
	preferencias.load(ARQUIVO)
	for chave: String in COMPONENTES:
		tamanhos_componentes[chave] = clampi(int(preferencias.get_value("componentes", chave, padrao_componente(chave))), 0, ESCALAS_COMPONENTE.size() - 1)
	get_tree().node_added.connect(_texto_novo)


## A escolha salva vence; sem ela, tela cheia.
static func preferida() -> bool:
	var preferencias := ConfigFile.new()
	if preferencias.load(ARQUIVO) == OK:
		return bool(preferencias.get_value("tela", "cheia", true))
	return true


func alternar() -> void:
	definir(not cheia)


func definir(nova: bool) -> void:
	cheia = nova
	var preferencias := ConfigFile.new()
	preferencias.load(ARQUIVO)
	preferencias.set_value("tela", "cheia", nova)
	if preferencias.save(ARQUIVO) != OK:
		push_warning("Não foi possível salvar o modo da tela.")
	_aplicar()
	modo_mudou.emit(nova)


## Conjunto de cursor salvo; sem escolha, o padrão.
static func cursor_preferido() -> int:
	var preferencias := ConfigFile.new()
	if preferencias.load(ARQUIVO) == OK:
		return clampi(int(preferencias.get_value("interface", "cursor", PADRAO_CURSOR)), 0, CURSORES.size() - 1)
	return PADRAO_CURSOR


## Troca o cursor na hora e guarda a escolha para as próximas aberturas.
func definir_cursor(indice: int) -> void:
	cursor = clampi(indice, 0, CURSORES.size() - 1)
	var preferencias := ConfigFile.new()
	preferencias.load(ARQUIVO)
	preferencias.set_value("interface", "cursor", cursor)
	if preferencias.save(ARQUIVO) != OK:
		push_warning("Não foi possível salvar o cursor.")
	_aplicar_cursor()


static func _tamanho_salvo(chave: String) -> int:
	var preferencias := ConfigFile.new()
	if preferencias.load(ARQUIVO) == OK:
		return clampi(int(preferencias.get_value("interface", chave, PADRAO_TAMANHO)), 0, ROTULOS_TAMANHO.size() - 1)
	return PADRAO_TAMANHO


func _salvar_interface(chave: String, valor: int) -> void:
	var preferencias := ConfigFile.new()
	preferencias.load(ARQUIVO)
	preferencias.set_value("interface", chave, valor)
	if preferencias.save(ARQUIVO) != OK:
		push_warning("Não foi possível salvar %s." % chave)


## Tamanho do HUD: a coluna do canto se refaz na hora.
func definir_tamanho_hud(indice: int) -> void:
	tamanho_hud = clampi(indice, 0, ESCALAS_HUD.size() - 1)
	escala_hud = float(ESCALAS_HUD[tamanho_hud])
	_salvar_interface("tamanho_hud", tamanho_hud)
	load("res://scripts/prototipo_3d/botao_canto.gd").reaplicar(get_tree())


## Tamanho do texto: reescala tudo o que está na tela; o que entrar depois chega
## escalado por _texto_novo.
func definir_tamanho_texto(indice: int) -> void:
	tamanho_texto = clampi(indice, 0, ESCALAS_TEXTO.size() - 1)
	escala_texto = float(ESCALAS_TEXTO[tamanho_texto])
	_salvar_interface("tamanho_texto", tamanho_texto)
	_reescalar(get_tree().root)


func _reescalar(no: Node) -> void:
	if no is Control:
		_escalar_texto(no)
	for filho in no.get_children():
		_reescalar(filho)


# Diferido: quem cria o texto costuma definir o tamanho logo depois de add_child.
func _texto_novo(no: Node) -> void:
	if not is_equal_approx(escala_texto, 1.0) and _tem_texto(no):
		_escalar_texto.call_deferred(no)


static func _tem_texto(no: Node) -> bool:
	return no is Label or no is Button or no is RichTextLabel or no is LineEdit or no is TextEdit


## Guarda o tamanho original de cada fonte (o do tema ou o fixado no código) e aplica a
## escala sobre ele; na escala 1 devolve o original.
func _escalar_texto(no: Node) -> void:
	if not is_instance_valid(no) or not _tem_texto(no):
		return
	var controle := no as Control
	var originais: Dictionary = controle.get_meta("fontes_originais", {})
	if originais.is_empty():
		for nome: String in FONTES:
			if controle.has_theme_font_size_override(nome):
				originais[nome] = [controle.get_theme_font_size(nome), true]
			elif nome == "font_size" or controle is RichTextLabel:
				originais[nome] = [controle.get_theme_font_size(nome), false]
		controle.set_meta("fontes_originais", originais)
	for nome: String in originais:
		var tamanho: int = originais[nome][0]
		if is_equal_approx(escala_texto, 1.0) and not originais[nome][1]:
			controle.remove_theme_font_size_override(nome)
		else:
			controle.add_theme_font_size_override(nome, maxi(1, roundi(tamanho * escala_texto)))


func _aplicar_cursor() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var conjunto: Array = CURSORES[cursor]
	Input.set_custom_mouse_cursor(load(conjunto[0]), Input.CURSOR_ARROW, conjunto[1])
	Input.set_custom_mouse_cursor(load(conjunto[2]), Input.CURSOR_POINTING_HAND, conjunto[3])


## Dica dos botões: diz o que o clique faz e ensina o atalho.
func dica() -> String:
	return tr("Modo janela (F11)") if cheia else tr("Tela cheia (F11)")


# _input, e não _unhandled_input: F11 tem de valer mesmo com um botão em foco.
func _input(evento: InputEvent) -> void:
	var tecla := evento as InputEventKey
	if tecla != null and tecla.pressed and not tecla.echo and tecla.keycode == KEY_F11:
		alternar()
		get_viewport().set_input_as_handled()


func _aplicar() -> void:
	# Sem janela de verdade (testes headless) só a preferência importa.
	if DisplayServer.get_name() == "headless":
		return
	# O monitor escolhido (#95), antes do modo: em tela cheia a janela cobre a
	# tela em que está, e em janela ela se mede pela área útil dela.
	var alvo := clampi(monitor, 0, maxi(1, DisplayServer.get_screen_count()) - 1)
	if DisplayServer.window_get_current_screen() != alvo:
		DisplayServer.window_set_current_screen(alvo)
	if cheia:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	# Ao sair da tela cheia o Windows devolve o estado de antes, que pode ser
	# maximizado; a janela tem de voltar ao tamanho dela.
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var area := DisplayServer.screen_get_usable_rect(alvo)
	var largura := minf(area.size.x * FRACAO_JANELA, area.size.y * FRACAO_JANELA * 16.0 / 9.0)
	var tamanho := Vector2i(roundi(largura), roundi(largura * 9.0 / 16.0))
	DisplayServer.window_set_size(tamanho)
	DisplayServer.window_set_position(area.position + Vector2i(Vector2(area.size - tamanho) * 0.5))
