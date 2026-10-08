extends PanelContainer
## O painel da sessão do testador: quem decidiu, a ação em palavras, o motivo, a missão, a
## barra de quanto falta para zerar o jogo, as últimas decisões e o gasto. É só desenho:
## `sessao.gd` junta os dados (`mostrar`) e escuta o pedido de parar.

const TestadorApoios = preload("res://scripts/prototipo_3d/testador_apoios.gd")
const Identidade = preload("res://scripts/prototipo_3d/identidade.gd")
const TemaMenu = preload("res://scripts/prototipo_3d/tema_menu.gd")

signal parar_pedido

const LARGURA := 340.0
const MARGEM := 14.0
const MARGEM_DE_BAIXO := 104.0       # acima da barra de mão e do nome do item
const FOLGA := 8.0                   # respiro mínimo entre o painel e o que ele não pode cobrir
const TOPO := 70.0                   # abaixo do relógio e dos botões do alto
const MAX_DECISOES := 4
const NOTA := Color("c9b98f")
const ALERTA := Identidade.TERRACOTA
const CORES := {
	"deterministic": Color("8fd1a5"),
	"jev": Identidade.OURO,
	"gpt": Color("8fb4e8"),
}

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


func montar(t: Callable) -> void:
	_t = t
	# O tema do menu e do HUD: botões em Cinzel com a laca verde e o filete de ouro.
	theme = TemaMenu.criar()
	add_theme_stylebox_override("panel", _estilo_do_painel())
	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 5)
	add_child(caixa)
	var cabeca := HBoxContainer.new()
	cabeca.add_theme_constant_override("separation", 8)
	caixa.add_child(cabeca)
	_titulo = _rotulo(cabeca, 15, Identidade.CREME, Identidade.fonte(Identidade.FONTE_TITULO, 600, 3))
	_titulo.uppercase = true
	_titulo.autowrap_mode = TextServer.AUTOWRAP_OFF
	_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pilula = PanelContainer.new()
	_pilula.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cabeca.add_child(_pilula)
	_nivel = _rotulo(_pilula, 11, Color.WHITE, Identidade.fonte(Identidade.FONTE_TITULO, 700, 1))
	_nivel.autowrap_mode = TextServer.AUTOWRAP_OFF
	_nivel.uppercase = true
	_sub = _rotulo(caixa, 15, NOTA, Identidade.fonte(Identidade.FONTE_ITALICO, 500))
	caixa.add_child(Identidade.divisor())
	_acao = _rotulo(caixa, 19, Identidade.CREME, Identidade.fonte(Identidade.FONTE_TEXTO, 700))
	# O nome técnico da ação fica na dica: o Label ignora o mouse por padrão e não a mostraria.
	_acao.mouse_filter = Control.MOUSE_FILTER_STOP
	_motivo = _rotulo(caixa, 15, NOTA)
	_objetivo = _rotulo(caixa, 16, Identidade.TEXTO)
	_barra = BarraMarcos.new()
	caixa.add_child(_barra)
	_capitulo = _rotulo(caixa, 15, Identidade.TEXTO)
	_agora = _rotulo(caixa, 15, NOTA)
	_ritmo = _rotulo(caixa, 15, NOTA)
	_travado = _rotulo(caixa, 15, ALERTA)
	_decisoes = VBoxContainer.new()
	_decisoes.add_theme_constant_override("separation", 0)
	caixa.add_child(_decisoes)
	var rodape := HBoxContainer.new()
	rodape.add_theme_constant_override("separation", 8)
	caixa.add_child(rodape)
	_gasto = _rotulo(rodape, 14, NOTA)
	_gasto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rodape.add_child(_plaqueta_da_tecla("F8"))
	# O Parar é um botão do jogo, só que pequeno: a tecla vem na plaqueta ao lado, como nos atalhos.
	_parar = Button.new()
	_parar.focus_mode = Control.FOCUS_NONE
	_parar.theme_type_variation = &"BotaoNegativo"
	_parar.add_theme_font_size_override("font_size", 12)
	_parar.add_theme_constant_override("outline_size", 0)
	_parar.mouse_entered.connect(func() -> void: Audio.efeito("ui_hover"))
	_parar.pressed.connect(func() -> void: parar_pedido.emit())
	rodape.add_child(_parar)
	# Largura fixa, altura do conteúdo; a posição é escolhida por `posicionar`.
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	custom_minimum_size = Vector2(LARGURA, 0.0)


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


func _rotulo(pai: Control, tamanho: int, cor := Color.WHITE, fonte: Font = null) -> Label:
	var r := Label.new()
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	_pilula.visible = nivel != ""
	if nivel != "":
		var etiqueta: String = _t.call("nivel_" + nivel)
		var modo := str(d.get("modo", "normal"))
		if modo == "local":
			etiqueta += " · " + str(_t.call("modo_local"))
		elif modo == "plan" and d.get("plano") is Array:
			etiqueta += " · " + str(_t.call("modo_plan")) % [int(d["plano"][0]), int(d["plano"][1])]
		_nivel.text = etiqueta
		var cor: Color = CORES.get(nivel, Color.WHITE)
		_nivel.add_theme_color_override("font_color", cor)
		_pilula.add_theme_stylebox_override("panel", _estilo_da_pilula(cor))
	_sub.text = str(d.get("sub", ""))
	_acao.text = str(d.get("acao", ""))
	_acao.tooltip_text = str(d.get("acao_tecnica", ""))
	_motivo.text = str(d.get("motivo", ""))
	_motivo.visible = _motivo.text != ""
	var objetivo: Dictionary = d.get("objetivo", {})
	_objetivo.text = str(_t.call("objetivo")) % [str(objetivo.get("titulo", "")), int(objetivo.get("feito", 0)), int(objetivo.get("total", 0))] \
		if not objetivo.is_empty() else str(_t.call("sem_objetivo"))
	var p: Dictionary = d.get("progresso", {})
	var com_progresso := not p.is_empty() and int(p.get("total", 0)) > 0
	_barra.visible = com_progresso
	_capitulo.visible = com_progresso
	_agora.visible = com_progresso and str(p.get("proximo_objetivo", "")) != ""
	_ritmo.visible = com_progresso
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
		_agora.text = str(_t.call("agora")) % str(p.get("proximo_objetivo", ""))
		var ritmo: Dictionary = d.get("ritmo", {})
		if ritmo.get("acoes_restantes") == null:
			_ritmo.text = str(_t.call("ritmo_depois"))
		else:
			_ritmo.text = str(_t.call("ritmo")) % [int(ritmo["acoes_restantes"]), duracao(int(ritmo["segundos_restantes"]))]
	var sinais: Array = d.get("sinais", [])
	_travado.visible = not sinais.is_empty() or bool(d.get("bloqueado", false))
	if bool(d.get("bloqueado", false)):
		_travado.text = _t.call("bloqueado")
	elif not sinais.is_empty():
		var palavras: Array = []
		for s in sinais:
			palavras.append(_t.call("sinal_" + str(s)))
		_travado.text = str(_t.call("travado")) % ", ".join(palavras)
	_listar(d.get("decisoes", []))
	_gasto.text = str(d.get("gasto", ""))
	_parar.text = str(_t.call("parar_curto"))


func _listar(todos: Array) -> void:
	var itens := todos.slice(maxi(0, todos.size() - MAX_DECISOES))
	_decisoes.visible = not itens.is_empty()
	var existentes := _decisoes.get_children()
	for i in range(maxi(itens.size(), existentes.size())):
		if i >= itens.size():
			existentes[i].queue_free()
			continue
		var r: Label
		if i < existentes.size():
			r = existentes[i]
		else:
			r = Label.new()
			r.add_theme_font_size_override("font_size", 14)
			r.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TEXTO, 600))
			r.clip_text = true
			_decisoes.add_child(r)
		r.text = "● " + str(itens[i]["texto"])
		r.add_theme_color_override("font_color", CORES.get(str(itens[i]["nivel"]), NOTA))


static func duracao(segundos: int) -> String:
	return "%d min %02d s" % [floori(segundos / 60.0), segundos % 60] if segundos >= 60 else "%d s" % segundos


## Os cantos onde o painel pode ficar, do preferido ao último recurso: canto de baixo, acima
## da barra de mão, meio da direita, alto da direita e alto da esquerda.
static func candidatos(janela: Vector2, tamanho: Vector2) -> Array:
	var direita := janela.x - MARGEM - tamanho.x
	return [Rect2(Vector2(direita, janela.y - MARGEM - tamanho.y), tamanho),
		Rect2(Vector2(direita, janela.y - MARGEM_DE_BAIXO - tamanho.y), tamanho),
		Rect2(Vector2(direita, (janela.y - tamanho.y) * 0.5), tamanho),
		Rect2(Vector2(direita, TOPO), tamanho),
		Rect2(Vector2(MARGEM, TOPO), tamanho)]


## O primeiro canto que não encosta em nenhum obstáculo (o `atual` ganha a preferência
## enquanto continuar livre, para o painel não pular). Se todos encostam, o que cobre menos.
static func escolher(janela: Vector2, tamanho: Vector2, obstaculos: Array, atual := -1) -> int:
	var lista := candidatos(janela, tamanho)
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


## Põe o painel no canto livre. `obstaculos` são os retângulos do HUD em coordenadas da tela.
func posicionar(obstaculos: Array) -> void:
	var janela := get_viewport_rect().size
	var tamanho := get_combined_minimum_size()
	_canto = escolher(janela, tamanho, obstaculos, _canto)
	position = candidatos(janela, tamanho)[_canto].position
