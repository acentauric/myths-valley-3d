extends Node
## Maré da baía (autoload "Mare"): sobe e desce a superfície do mar conforme o modo
## escolhido em AJUSTAR → Cenário. Toda a batimetria fala em metros NA PREAMAR; aqui
## sai o deslocamento atual — nivel_offset() vai de 0.0 (preamar) a -0.6 unidades
## (baixa-mar de 2,4 m). Os nós do grupo "mare_superficie" (o plano do mar e a
## superfície da câmera, ver mar.gd) acompanham a altura; os ShaderMaterials
## registrados recebem "mare_offset_m" (em METROS) e "turbidez" (0..1, alta na
## enchente, quando a água revolve o fundo e escurece).

signal mare_mudou(offset: float)

const ARQUIVO := "user://preferencias_visuais.cfg"
## Amplitude real do lugar: 2,4 m = 0.6 unidades (1 u = 4 m).
const AMPLITUDE_U := 0.6
const METROS_POR_UNIDADE := 4.0
## Modo Rápida: um ciclo completo de maré em ~90 s reais, para ver acontecer.
const CICLO_RAPIDO_S := 90.0

## 0 = Sem maré (nível fixo na preamar), 1 = Ciclo do lugar (semidiurno: 2 baixas e
## 2 altas por dia de jogo), 2 = Ciclo lento (1 ciclo por dia), 3 = Rápida.
var modo := 0

var _offset := 0.0
## Materiais por referência fraca: morrem junto com as malhas na troca de cena.
var _materiais: Array[WeakRef] = []


func _ready() -> void:
	var preferencias := ConfigFile.new()
	if preferencias.load(ARQUIVO) == OK:
		modo = clampi(int(preferencias.get_value("mare", "modo", 0)), 0, 3)


func _process(_delta: float) -> void:
	var novo := _offset_do_modo()
	var mudou := absf(novo - _offset) > 0.00001
	_offset = novo
	# Nós que flutuam no nível da maré: base guardada em meta por mar.gd.
	for no in get_tree().get_nodes_in_group("mare_superficie"):
		var corpo := no as Node3D
		if corpo != null:
			corpo.position.y = float(corpo.get_meta("mare_base_y", corpo.position.y)) + _offset
	var offset_m := _offset * METROS_POR_UNIDADE
	var turva := turbidez()
	for i in range(_materiais.size() - 1, -1, -1):
		var material := _materiais[i].get_ref() as ShaderMaterial
		if material == null:
			_materiais.remove_at(i)
		else:
			material.set_shader_parameter("mare_offset_m", offset_m)
			material.set_shader_parameter("turbidez", turva)
	if mudou:
		mare_mudou.emit(_offset)


func definir_modo(indice: int) -> void:
	modo = clampi(indice, 0, 3)
	var preferencias := ConfigFile.new()
	preferencias.load(ARQUIVO)
	preferencias.set_value("mare", "modo", modo)
	preferencias.save(ARQUIVO)


## Deslocamento do nível do mar em unidades: 0.0 na preamar, -AMPLITUDE_U na baixa-mar.
func nivel_offset() -> float:
	return _offset


## Fase do ciclo em 0..1: 0 = preamar, 0.5 = baixa-mar, depois enchente até 1.
func fase() -> float:
	match modo:
		1:
			# Semidiurno como no lugar: período de 12 h → 2 baixas e 2 altas por dia.
			return fmod(Dia.hora, 12.0) / 12.0
		2:
			return Dia.hora / 24.0
		3:
			return fmod(Time.get_ticks_msec() / 1000.0, CICLO_RAPIDO_S) / CICLO_RAPIDO_S
	return 0.0


## A água está subindo (da baixa-mar rumo à preamar)?
func enchente() -> bool:
	return fase() > 0.5


## 0..1: a enchente revolve o fundo e a água fica turva; no pico da vazante, limpa.
func turbidez() -> float:
	return clampf(-sin(fase() * TAU), 0.0, 1.0)


## Material de água/areia/leito que precisa dos uniforms da maré a cada quadro.
func registrar_material(material: ShaderMaterial) -> void:
	if material == null:
		return
	for ref in _materiais:
		if ref.get_ref() == material:
			return
	_materiais.append(weakref(material))
	material.set_shader_parameter("mare_offset_m", _offset * METROS_POR_UNIDADE)
	material.set_shader_parameter("turbidez", turbidez())


## Cosseno: descida e subida suaves, sem quina na virada da maré.
func _offset_do_modo() -> float:
	if modo == 0:
		return 0.0
	return -AMPLITUDE_U * 0.5 * (1.0 - cos(fase() * TAU))
