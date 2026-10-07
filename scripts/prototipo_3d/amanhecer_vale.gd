extends "res://scripts/ui/amanhecer.gd"
## O CARTÃO DO AMANHECER NO VALE: o do 2D (`scripts/ui/amanhecer.gd`), desenhado
## na tela do vale, de 1280×720, com a letra do vale. Autoload `Amanhecer`.
##
## ESTENDE O ARQUIVO DO 2D em vez de copiá-lo (regra 3 do HISTORICO): a regra —
## o que o cartão diz, quanto fica, o que o pula, os lembretes — segue lá; aqui
## só `_montar`, onde moram as medidas. Até 07/10 o vale desenhava o cartão do
## 2D no quadro de 640×360 e ampliava a camada duas vezes
## (`prototype._ajustar_as_telas_do_2d`), e a letra saía serrilhada ("também vi ao
## deitar na cama"). As medidas são o dobro das de lá, e a letra é a dos menus
## do vale: o dia em Cinzel, o resto em Cormorant (`identidade.gd`).

const Identidade = preload("res://scripts/prototipo_3d/identidade.gd")

## O quadro em que o cartão é desenhado: a tela do vale (`prototype._na_tela_do_vale`).
const DESENHADA_PARA := Vector2(1280, 720)


func _montar() -> void:
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)

	var fundo := ColorRect.new()
	fundo.color = COR_FUNDO
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(fundo)

	_dia = _rotulo(52, COR_DIA)
	_dia.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TITULO, 600, 4))
	_dia.position = Vector2(0, 216)
	_dia.size = Vector2(DESENHADA_PARA.x, 80)
	_raiz.add_child(_dia)

	_data = _rotulo(28, COR_DATA)
	_data.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TEXTO, 600))
	_data.position = Vector2(0, 300)
	_data.size = Vector2(DESENHADA_PARA.x, 40)
	_raiz.add_child(_data)

	_folego = _rotulo(22, COR_MIUDO)
	_folego.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TEXTO, 500))
	_folego.position = Vector2(0, 344)
	_folego.size = Vector2(DESENHADA_PARA.x, 36)
	_raiz.add_child(_folego)

	_risco = Control.new()
	_risco.set_anchors_preset(Control.PRESET_FULL_RECT)
	_risco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_risco.draw.connect(func():
		_risco.draw_line(Vector2(480, 404), Vector2(800, 404), COR_RISCO, 2.0))
	_raiz.add_child(_risco)

	_lembretes = _rotulo(24, COR_LEMBRETE)
	_lembretes.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TEXTO, 600))
	_lembretes.position = Vector2(240, 428)
	_lembretes.size = Vector2(800, 160)
	_lembretes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_raiz.add_child(_lembretes)
