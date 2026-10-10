extends PanelContainer
## O painel da sessão do testador: quem decidiu, a ação em palavras, o motivo, a missão, a
## barra de quanto falta para zerar o jogo, as últimas decisões e o gasto. É só desenho:
## `sessao.gd` junta os dados (`mostrar`) e escuta o pedido de parar.

const TestadorApoios = preload("res://scripts/prototipo_3d/testador_apoios.gd")
const Identidade = preload("res://scripts/prototipo_3d/identidade.gd")
const TemaMenu = preload("res://scripts/prototipo_3d/tema_menu.gd")

signal parar_pedido
## F7 em botão (#206): tirar o testador do volante ou devolver.
signal manual_pedido
## F6 (#234): minimizar ou maximizar o painel.
signal minimizar_pedido

const LARGURA := 340.0
const MARGEM := 14.0
const MARGEM_DE_BAIXO := 104.0       # acima da barra de mão e do nome do item
const FOLGA := 8.0                   # respiro mínimo entre o painel e o que ele não pode cobrir
const TOPO := 70.0                   # abaixo do relógio e dos botões do alto
const LARGURA_UTIL := LARGURA - 28.0   # a largura menos as duas margens de 14 do filete
const MAX_DECISOES := 4
## O PAINEL TEM TAMANHO FIXO (10/10/2026): crescia para a esquerda com a etiqueta do nível
## ("DETERMINÍSTICO · RECUPERAÇÃO LOCAL") e subia e descia com as linhas que apareciam e
## sumiam. Agora cada linha guarda sempre o seu número de linhas (vazia, guarda o espaço), a
## etiqueta corta com reticências e as decisões são sempre quatro vagas.
const LINHAS := {"sub": 1, "acao": 1, "motivo": 2, "objetivo": 1, "capitulo": 1, "agora": 2, "ritmo": 1, "travado": 1, "gasto": 1}
const NOTA := Color("c9b98f")
const ALERTA := Identidade.TERRACOTA
const CORES := {
	"deterministic": Color("8fd1a5"),
	"jev": Identidade.OURO,
	"gpt": Color("8fb4e8"),
}

## O MODO DO TESTADOR EM ÍCONE (10/10/2026), no lugar da etiqueta escrita: o nome inteiro fica
## na dica. "deterministic" é o robô; "local", o robô com a seta de recuperar; "jev", dois nós
## ligados (o raciocínio do Jev); "gpt", a estrela de quatro pontas. Desenha na grade de 24.
class IconeModo extends Control:
	var modo := "deterministic"
	var cor := Color.WHITE

	func _init() -> void:
		custom_minimum_size = Vector2(22.0, 22.0)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, size / 24.0)
		match modo:
			"deterministic", "local":
				draw_rect(Rect2(5, 7, 14, 11), cor, false, 1.7, true)
				draw_line(Vector2(12, 7), Vector2(12, 4), cor, 1.5, true)
				draw_circle(Vector2(12, 3.5), 1.3, cor)
				draw_circle(Vector2(9.2, 12), 1.5, cor)
				draw_circle(Vector2(14.8, 12), 1.5, cor)
				draw_line(Vector2(9.5, 15.5), Vector2(14.5, 15.5), cor, 1.3, true)
				if modo == "local":
					draw_arc(Vector2(18.5, 18.5), 4.0, deg_to_rad(-200), deg_to_rad(60), 10, Identidade.OURO, 1.6, true)
					draw_colored_polygon(PackedVector2Array([Vector2(20.5, 21.6), Vector2(23.5, 20.0), Vector2(20.6, 18.0)]), Identidade.OURO)
			"jev":
				draw_line(Vector2(7, 8), Vector2(17, 16), cor, 1.6, true)
				draw_line(Vector2(7, 8), Vector2(17, 6), cor, 1.6, true)
				draw_line(Vector2(17, 6), Vector2(17, 16), cor, 1.6, true)
				for c in [Vector2(7, 8), Vector2(17, 6), Vector2(17, 16)]:
					draw_circle(c, 3.0, cor)
			"gpt":
				draw_colored_polygon(PackedVector2Array([Vector2(12, 2), Vector2(14, 10), Vector2(22, 12), Vector2(14, 14), Vector2(12, 22), Vector2(10, 14), Vector2(2, 12), Vector2(10, 10)]), cor)


## A barra de progresso com um marco por capítulo: o trecho do capítulo atual fica em ouro
## cheio, os concluídos em ouro suave e os que faltam só como divisão.
class BarraMarcos extends Control:
	var valor := 0.0
	var marcos: Array = []     # [{"fim": 0..1, "atual": bool, "acabou": bool}]

	func _init() -> void:
		custom_minimum_size = Vector2(0.0, 14.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var trilha := Rect2(0.0, size.y * 0.32, size.x, size.y * 0.36)
		draw_rect(trilha, Color(1.0, 0.94, 0.82, 0.14))
		draw_rect(Rect2(trilha.position, Vector2(size.x * clampf(valor, 0.0, 1.0), trilha.size.y)), Color("e8c46a"))
		var inicio := 0.0
		for marco in marcos:
			var fim: float = float(marco["fim"])
			if bool(marco["atual"]):
				draw_rect(Rect2(Vector2(size.x * inicio, size.y * 0.12), Vector2(size.x * (fim - inicio), size.y * 0.76)),
					Color(0.91, 0.77, 0.42, 0.28))
			var x := size.x * fim
			var cor := Color("f6ead0") if bool(marco["acabou"]) else Color(0.96, 0.92, 0.82, 0.55)
			draw_line(Vector2(x, size.y * 0.1), Vector2(x, size.y * 0.9), cor, 2.0 if bool(marco["atual"]) else 1.0)
			inicio = fim

var _t: Callable                  # chave -> frase no idioma da sessão
var _titulo: Label
var _pilula: PanelContainer
var _nivel: Label
var _icone_modo: IconeModo
var _sub: Label
var _acao: Label
var _motivo: Label
var _objetivo: Label
var _barra: BarraMarcos
var _capitulo: Label
var _agora: Label
var _ritmo: Label
var _travado: Label
var _decisoes: VBoxContainer
var _gasto: Label
var _parar: Button
var _manual: Button
## F6 (#234): minimiza o painel numa faixa de uma linha e maximiza de novo.
var _minimizar: Button
var _corpo: VBoxContainer
var _faixa: Label
var _comandos_em_pe: VBoxContainer
var _comandos_deitados: HBoxContainer
var minimizado := false


func montar(t: Callable) -> void:
	_t = t
	# O tema do menu e do HUD: botões em Cinzel com a laca verde e o filete de ouro.
	theme = TemaMenu.criar()
	add_theme_stylebox_override("panel", _estilo_do_painel())
	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 6)
	add_child(caixa)
	# A FAIXA MINIMIZADA (F6, #234): "TESTANDO · Determinístico · 32 ações · 5,4%".
	_faixa = Label.new()
	_faixa.name = "Faixa"
	_faixa.autowrap_mode = TextServer.AUTOWRAP_OFF
	_faixa.clip_text = true
	_faixa.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_faixa.uppercase = true
	_faixa.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TITULO, 600, 1))
	_faixa.add_theme_font_size_override("font_size", 13)
	_faixa.add_theme_color_override("font_color", Identidade.CREME)
	_faixa.visible = false
	caixa.add_child(_faixa)
	_corpo = VBoxContainer.new()
	_corpo.name = "Corpo"
	_corpo.add_theme_constant_override("separation", 5)
	caixa.add_child(_corpo)
	var cabeca := HBoxContainer.new()
	cabeca.add_theme_constant_override("separation", 8)
	_corpo.add_child(cabeca)
	_titulo = _rotulo(cabeca, 15, Identidade.CREME, Identidade.fonte(Identidade.FONTE_TITULO, 600, 3))
	_titulo.uppercase = true
	_titulo.autowrap_mode = TextServer.AUTOWRAP_OFF
	_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pilula = PanelContainer.new()
	_pilula.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Só o ícone, sem moldura: o modo não é botão e não deve parecer clicável.
	_pilula.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	cabeca.add_child(_pilula)
	_nivel = _rotulo(_pilula, 11, Color.WHITE, Identidade.fonte(Identidade.FONTE_TITULO, 700, 1))
	_nivel.autowrap_mode = TextServer.AUTOWRAP_OFF
	_nivel.uppercase = true
	_nivel.clip_text = true
	_nivel.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# O nome do modo fica na dica do ícone; o rótulo só guarda o texto (o portão o lê).
	_nivel.visible = false
	_icone_modo = IconeModo.new()
	_icone_modo.custom_minimum_size = Vector2(26.0, 26.0)
	_pilula.add_child(_icone_modo)
	_sub = _rotulo(_corpo, 15, NOTA, Identidade.fonte(Identidade.FONTE_ITALICO, 500))
	_corpo.add_child(Identidade.divisor())
	_acao = _rotulo(_corpo, 19, Identidade.CREME, Identidade.fonte(Identidade.FONTE_TEXTO, 700))
	# O nome técnico da ação fica na dica: o Label ignora o mouse por padrão e não a mostraria.
	_acao.mouse_filter = Control.MOUSE_FILTER_STOP
	_motivo = _rotulo(_corpo, 15, NOTA)
	_objetivo = _rotulo(_corpo, 16, Identidade.TEXTO)
	_barra = BarraMarcos.new()
	_corpo.add_child(_barra)
	_capitulo = _rotulo(_corpo, 15, Identidade.TEXTO)
	_agora = _rotulo(_corpo, 15, NOTA)
	_ritmo = _rotulo(_corpo, 15, NOTA)
	_travado = _rotulo(_corpo, 15, ALERTA)
	_decisoes = VBoxContainer.new()
	_decisoes.add_theme_constant_override("separation", 0)
	_corpo.add_child(_decisoes)
	_gasto = _rotulo(_corpo, 14, NOTA)
	for chave in LINHAS:
		_fixar(get("_" + chave) as Label, int(LINHAS[chave]))
	for _i in MAX_DECISOES:
		var vaga := Label.new()
		vaga.add_theme_font_size_override("font_size", 14)
		vaga.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TEXTO, 600))
		vaga.clip_text = true
		vaga.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		vaga.custom_minimum_size = Vector2(LARGURA_UTIL, ceilf(vaga.get_line_height()))
		_decisoes.add_child(vaga)
	# OS COMANDOS NO MESMO PADRÃO (#234): plaqueta da tecla e rótulo curto, do mesmo tamanho.
	# Maximizado ficam empilhados (F6, F7, F8); minimizado, lado a lado embaixo da faixa.
	_comandos_em_pe = VBoxContainer.new()
	_comandos_em_pe.add_theme_constant_override("separation", 4)
	caixa.add_child(_comandos_em_pe)
	_comandos_deitados = HBoxContainer.new()
	_comandos_deitados.add_theme_constant_override("separation", 4)
	_comandos_deitados.visible = false
	caixa.add_child(_comandos_deitados)
	_minimizar = _comando("Minimizar", "F6", &"", func() -> void: minimizar_pedido.emit())
	# Assumir o controle (F7) ou devolver ao testador: o texto vem de `mostrar` (`manual_botao`).
	_manual = _comando("Manual", "F7", &"", func() -> void: manual_pedido.emit())
	# Parar continua em vermelho: é a ação destrutiva.
	_parar = _comando("Parar", "F8", &"BotaoNegativo", func() -> void: parar_pedido.emit())
	for botao in [_minimizar, _manual, _parar]:
		_comandos_em_pe.add_child(botao)
	# Largura fixa, altura do conteúdo; a posição é escolhida por `posicionar`.
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	custom_minimum_size = Vector2(LARGURA, 0.0)


## Um comando do rodapé: botão do jogo, pequeno, com a plaqueta da tecla e o rótulo dentro.
## O `text` do botão fica vazio; o rótulo é o Label "Rotulo" (o portão o lê por `rotulo_de`).
func _comando(nome: String, tecla: String, variacao: StringName, acao: Callable) -> Button:
	var botao := Button.new()
	botao.name = nome
	botao.focus_mode = Control.FOCUS_NONE
	botao.custom_minimum_size = Vector2(0.0, 30.0)
	botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if variacao != &"":
		botao.theme_type_variation = variacao
	botao.clip_contents = true
	botao.mouse_entered.connect(_som_de_passar_o_mouse)
	botao.pressed.connect(acao)
	var linha := HBoxContainer.new()
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linha.add_theme_constant_override("separation", 7)
	botao.add_child(linha)
	linha.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	linha.offset_left = 6.0
	linha.offset_right = -6.0
	var plaqueta := _plaqueta_da_tecla(tecla)
	plaqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linha.add_child(plaqueta)
	var rotulo := Label.new()
	rotulo.name = "Rotulo"
	rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rotulo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rotulo.clip_text = true
	rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rotulo.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TITULO, 600))
	rotulo.add_theme_font_size_override("font_size", 12)
	rotulo.add_theme_color_override("font_color", Identidade.CREME)
	linha.add_child(rotulo)
	return botao


static func rotulo_de(botao: Button) -> String:
	var r := botao.find_child("Rotulo", true, false) as Label
	return r.text if r != null else botao.text


func _rotular(botao: Button, texto: String) -> void:
	(botao.find_child("Rotulo", true, false) as Label).text = texto
	botao.tooltip_text = texto
	_acertar_comandos()


## OS TRÊS COMANDOS CABEM LADO A LADO, INTEIROS: cada botão fica com a largura do que diz
## ("MINIMIZAR" saía cortado em três partes iguais), e se os três não cabem na linha a letra
## desce até caber.
func _acertar_comandos() -> void:
	var botoes: Array = [_minimizar, _manual, _parar].filter(func(b) -> bool: return b != null and b.visible)
	for tamanho in range(12, 8, -1):
		var total := 4.0 * (botoes.size() - 1)
		var larguras: Array[float] = []
		for botao: Button in botoes:
			var rotulo := botao.find_child("Rotulo", true, false) as Label
			var plaqueta := (rotulo.get_parent() as Control).get_child(0) as Control
			var fonte := rotulo.get_theme_font("font")
			var largura := fonte.get_string_size(rotulo.text.to_upper() if rotulo.uppercase else rotulo.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x
			larguras.append(ceilf(largura + plaqueta.get_combined_minimum_size().x + 7.0 + 12.0 + 2.0))
			total += larguras.back()
		if total <= LARGURA_UTIL or tamanho == 9:
			for i in botoes.size():
				var b: Button = botoes[i]
				(b.find_child("Rotulo", true, false) as Label).add_theme_font_size_override("font_size", tamanho)
				b.custom_minimum_size.x = larguras[i]
				b.size_flags_stretch_ratio = larguras[i]
			return


## Troca entre o painel completo e a faixa de uma linha, levando os comandos junto.
func _arrumar_modo() -> void:
	_faixa.visible = minimizado
	_corpo.visible = not minimizado
	# Os comandos ficam sempre lado a lado, com o rótulo curto (MINIMIZAR, ASSUMIR, PARAR).
	var destino: BoxContainer = _comandos_deitados
	_comandos_deitados.visible = true
	_comandos_em_pe.visible = false
	for botao in [_minimizar, _manual, _parar]:
		if botao.get_parent() != destino:
			botao.get_parent().remove_child(botao)
			destino.add_child(botao)


## A laca verde-escura com o filete dourado suave e o canto chanfrado, como as plaquinhas do HUD.
static func _estilo_do_painel() -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(Identidade.LACA, 0.93)
	estilo.border_color = TemaMenu.BORDA_SUAVE
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(6)
	estilo.corner_detail = 1
	estilo.shadow_color = Color(0, 0, 0, 0.35)
	estilo.shadow_size = 6
	estilo.content_margin_left = 14
	estilo.content_margin_right = 14
	estilo.content_margin_top = 11
	estilo.content_margin_bottom = 11
	return estilo


## A etiqueta de quem decidiu: cor do nível sobre um fundo do mesmo tom.
static func _estilo_da_pilula(cor: Color) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(cor, 0.16)
	estilo.border_color = Color(cor, 0.7)
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(4)
	estilo.corner_detail = 1
	estilo.content_margin_left = 7
	estilo.content_margin_right = 7
	estilo.content_margin_top = 1
	estilo.content_margin_bottom = 1
	return estilo


## A tecla em papel claro, como nas dicas de interação (`dica_tecla.gd`).
static func _plaqueta_da_tecla(letra: String) -> PanelContainer:
	var tecla := PanelContainer.new()
	tecla.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Identidade.CREME
	estilo.set_corner_radius_all(4)
	estilo.content_margin_left = 6
	estilo.content_margin_right = 6
	estilo.content_margin_top = 1
	estilo.content_margin_bottom = 1
	tecla.add_theme_stylebox_override("panel", estilo)
	var rotulo := Label.new()
	rotulo.text = letra
	rotulo.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TITULO, 700))
	rotulo.add_theme_font_size_override("font_size", 12)
	rotulo.add_theme_color_override("font_color", Color("2b2a22"))
	tecla.add_child(rotulo)
	return tecla


## A linha guarda sempre `linhas` linhas de altura, e o que passa disso corta com reticências.
func _fixar(rotulo: Label, linhas: int) -> void:
	rotulo.max_lines_visible = linhas
	rotulo.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	rotulo.clip_text = true
	if linhas == 1:
		rotulo.autowrap_mode = TextServer.AUTOWRAP_OFF
	rotulo.custom_minimum_size.y = ceilf(rotulo.get_line_height() * linhas + rotulo.get_theme_constant("line_spacing") * (linhas - 1))


func _rotulo(pai: Control, tamanho: int, cor := Color.WHITE, fonte: Font = null) -> Label:
	var r := Label.new()
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Sem largura conhecida o rótulo quebra letra a letra e o painel nasce com milhares de pixels;
	# na coluna, a largura é a do painel menos as margens.
	if pai is VBoxContainer:
		r.custom_minimum_size.x = LARGURA_UTIL
	r.add_theme_font_size_override("font_size", tamanho)
	r.add_theme_color_override("font_color", cor)
	if fonte != null:
		r.add_theme_font_override("font", fonte)
	pai.add_child(r)
	return r


## Atualiza tudo o que há para mostrar. Chaves ausentes escondem a linha que dependia delas.
func mostrar(d: Dictionary) -> void:
	_titulo.text = str(d.get("titulo", ""))
	var nivel := str(d.get("nivel", ""))
	# A pílula fica sempre no lugar (sem nível, transparente): a altura do painel não muda.
	_pilula.modulate.a = 1.0 if nivel != "" else 0.0
	if nivel != "":
		var etiqueta: String = _t.call("nivel_" + nivel)
		var modo := str(d.get("modo", "normal"))
		if modo == "local":
			etiqueta += " · " + str(_t.call("modo_local"))
		elif modo == "plan" and d.get("plano") is Array:
			etiqueta += " · " + str(_t.call("modo_plan")) % [int(d["plano"][0]), int(d["plano"][1])]
		_nivel.text = etiqueta
		_icone_modo.modo = "local" if nivel == "deterministic" and modo == "local" else nivel
		_icone_modo.cor = CORES.get(nivel, Color.WHITE)
		_icone_modo.tooltip_text = etiqueta
		_icone_modo.queue_redraw()
		var cor: Color = CORES.get(nivel, Color.WHITE)
		_nivel.add_theme_color_override("font_color", cor)
	_sub.text = str(d.get("sub", ""))
	_acao.text = str(d.get("acao", ""))
	_acao.tooltip_text = str(d.get("acao_tecnica", ""))
	_motivo.text = str(d.get("motivo", ""))
	var objetivo: Dictionary = d.get("objetivo", {})
	_objetivo.text = str(_t.call("objetivo")) % [str(objetivo.get("titulo", "")), int(objetivo.get("feito", 0)), int(objetivo.get("total", 0))] \
		if not objetivo.is_empty() else str(_t.call("sem_objetivo"))
	var p: Dictionary = d.get("progresso", {})
	var com_progresso := not p.is_empty() and int(p.get("total", 0)) > 0
	_barra.modulate.a = 1.0 if com_progresso else 0.0
	_capitulo.text = ""
	_agora.text = ""
	_ritmo.text = ""
	if com_progresso:
		_barra.valor = float(p["percentual"]) / 100.0
		var marcos: Array = []
		var acumulado := 0.0
		for m in p.get("marcos", []):
			acumulado += float(m["total"])
			marcos.append({"fim": acumulado / float(p["total"]), "atual": bool(m["atual"]), "acabou": bool(m["acabou"])})
		_barra.marcos = marcos
		_barra.queue_redraw()
		_capitulo.text = "%s  ·  %s" % [str(_t.call("capitulo")) % [str(p.get("capitulo", "")), int(p.get("capitulo_feitos", 0)), int(p.get("capitulo_total", 0))],
			str(_t.call("progresso_pct")) % TestadorApoios.numero(float(p["percentual"]), 1)]
		_agora.text = str(_t.call("agora")) % str(p.get("proximo_objetivo", "")) if str(p.get("proximo_objetivo", "")) != "" else ""
		var ritmo: Dictionary = d.get("ritmo", {})
		if ritmo.get("acoes_restantes") == null:
			_ritmo.text = str(_t.call("ritmo_depois"))
		else:
			_ritmo.text = str(_t.call("ritmo")) % [int(ritmo["acoes_restantes"]), duracao(int(ritmo["segundos_restantes"]))]
	var sinais: Array = d.get("sinais", [])
	_travado.text = ""
	if bool(d.get("bloqueado", false)):
		_travado.text = _t.call("bloqueado")
	elif not sinais.is_empty():
		var palavras: Array = []
		for s in sinais:
			palavras.append(_t.call("sinal_" + str(s)))
		_travado.text = str(_t.call("travado")) % ", ".join(palavras)
	_listar(d.get("decisoes", []))
	_gasto.text = str(d.get("gasto", ""))
	minimizado = bool(d.get("minimizado", false))
	_faixa.text = str(d.get("faixa", ""))
	_arrumar_modo()
	_rotular(_minimizar, str(d.get("minimizar_botao", _t.call("cmd_maximizar" if minimizado else "cmd_minimizar"))))
	_rotular(_parar, str(_t.call("parar_curto")))
	_rotular(_manual, str(d.get("manual_botao", "")))
	_manual.visible = str(d.get("manual_botao", "")) != ""
	reset_size()


func _listar(todos: Array) -> void:
	var itens := todos.slice(maxi(0, todos.size() - MAX_DECISOES))
	var vagas := _decisoes.get_children()
	for i in vagas.size():
		var r := vagas[i] as Label
		r.text = "● " + str(itens[i]["texto"]) if i < itens.size() else ""
		r.add_theme_color_override("font_color", CORES.get(str(itens[i]["nivel"]), NOTA) if i < itens.size() else NOTA)


static func duracao(segundos: int) -> String:
	return "%d min %02d s" % [floori(segundos / 60.0), segundos % 60] if segundos >= 60 else "%d s" % segundos


## Os lugares onde o painel pode ficar, do preferido ao último recurso (#234). Com a coluna de
## atalhos da direita conhecida (`coluna`), o preferido é À ESQUERDA DELA, no alto, entre as
## barras do topo e a coluna, e depois mais abaixo, ainda colado à coluna. Os de sempre seguem:
## canto de baixo, acima da barra de mão, meio da direita, alto da direita e alto da esquerda.
static func candidatos(janela: Vector2, tamanho: Vector2, coluna := Rect2()) -> Array:
	var lista: Array = []
	if coluna.has_area():
		var x := coluna.position.x - FOLGA * 2.0 - tamanho.x
		lista.append(Rect2(Vector2(x, coluna.position.y), tamanho))
		lista.append(Rect2(Vector2(x, maxf(coluna.position.y, (janela.y - tamanho.y) * 0.5)), tamanho))
		lista.append(Rect2(Vector2(x, maxf(coluna.position.y, coluna.end.y - tamanho.y)), tamanho))
	var direita := janela.x - MARGEM - tamanho.x
	lista.append_array([Rect2(Vector2(direita, janela.y - MARGEM - tamanho.y), tamanho),
		Rect2(Vector2(direita, janela.y - MARGEM_DE_BAIXO - tamanho.y), tamanho),
		Rect2(Vector2(direita, (janela.y - tamanho.y) * 0.5), tamanho),
		Rect2(Vector2(direita, TOPO), tamanho),
		Rect2(Vector2(MARGEM, TOPO), tamanho)])
	return lista


## O primeiro lugar que não encosta em nenhum obstáculo (o `atual` ganha a preferência
## enquanto continuar livre, para o painel não pular). Se todos encostam, o que cobre menos.
static func escolher(janela: Vector2, tamanho: Vector2, obstaculos: Array, atual := -1, coluna := Rect2()) -> int:
	var lista := candidatos(janela, tamanho, coluna)
	var cobertura: Array = []
	for rect: Rect2 in lista:
		var coberto := 0.0
		for obstaculo: Rect2 in obstaculos:
			var area := rect.intersection(obstaculo.grow(FOLGA))
			coberto += maxf(0.0, area.size.x) * maxf(0.0, area.size.y)
		if not Rect2(Vector2.ZERO, janela).encloses(rect):
			coberto += 1.0e9
		cobertura.append(coberto)
	if atual >= 0 and atual < lista.size() and cobertura[atual] == 0.0:
		return atual
	var melhor := 0
	for i in range(lista.size()):
		if cobertura[i] < cobertura[melhor]:
			melhor = i
	return melhor


var _canto := -1
var _modo_do_canto := false


## Põe o painel no lugar livre. `obstaculos` são os retângulos do HUD em coordenadas da tela;
## `coluna`, o retângulo da coluna de atalhos da direita (também é obstáculo).
func posicionar(obstaculos: Array, coluna := Rect2()) -> void:
	var janela := get_viewport_rect().size
	reset_size()
	var tamanho := get_combined_minimum_size()
	# Trocar entre minimizado e maximizado escolhe de novo, do preferido.
	if _modo_do_canto != minimizado:
		_modo_do_canto = minimizado
		_canto = -1
	var todos := obstaculos.duplicate()
	if coluna.has_area():
		todos.append(coluna)
	_canto = escolher(janela, tamanho, todos, _canto, coluna)
	position = candidatos(janela, tamanho, coluna)[_canto].position


## O som de passar o mouse. No --script o autoload `Audio` ainda não é nome global quando este
## arquivo compila (o `sessao.gd` o carrega por preload), então o nó é buscado na árvore.
func _som_de_passar_o_mouse() -> void:
	var audio := get_node_or_null("/root/Audio")
	if audio != null:
		audio.efeito("ui_hover")
