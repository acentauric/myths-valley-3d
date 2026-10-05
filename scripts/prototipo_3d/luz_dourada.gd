extends CanvasLayer
## A LUZ DOURADA DA CHAPADA: a cena da chegada à terra do Seu Benedito.
##
## No 2D a chegada à expansão é cena — "luz dourada, câmera fechando, e o Pedro
## falando do que aquilo poderia ser" (`Mundo.cena_chapada`). É o único momento
## sonhador do tutorial, e a luz é o que o marca: a tela inteira esquenta por uns
## segundos, como fim de tarde, e volta.
##
## No vale a luz é um véu dourado sobre a tela, e não o sol do `Dia` mudado: o
## relógio é do jogador (e vai no save), e mexer nele por uma cena seria mentir
## a hora. Fica por baixo da conquista (camada 8, ela é a 9), que festeja o passo
## no mesmo instante. Não segura o jogo nem o mouse.

const COR := Color(1.0, 0.76, 0.34)
const FORTE := 0.36
const ENTRA := 1.2
const FICA := 2.6
const SAI := 1.6

var _veu: ColorRect
var _tocando := false


func _ready() -> void:
	layer = 8
	process_mode = Node.PROCESS_MODE_ALWAYS
	_veu = ColorRect.new()
	_veu.name = "LuzDourada"
	_veu.color = Color(COR, 0.0)
	_veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veu)
	_veu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veu.visible = false


## A luz está na tela agora?
func tocando() -> bool:
	return _tocando


## O quanto do véu está na tela, de 0 a FORTE (para o portão).
func forca() -> float:
	return _veu.color.a if _veu != null else 0.0


func tocar() -> void:
	if _tocando:
		return
	_tocando = true
	_veu.visible = true
	_veu.color = Color(COR, 0.0)
	var luz := create_tween()
	luz.tween_property(_veu, "color:a", FORTE, ENTRA).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	luz.tween_interval(FICA)
	luz.tween_property(_veu, "color:a", 0.0, SAI).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	luz.tween_callback(func() -> void:
		_veu.visible = false
		_tocando = false)
