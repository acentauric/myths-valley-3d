extends Node
## Maré da baía (autoload "Mare"): sobe e desce a superfície do mar conforme o modo
## escolhido em AJUSTAR → Cenário. Toda a batimetria fala em metros NA PREAMAR; aqui
## sai o deslocamento atual — nivel_offset() vai de 0.0 (preamar) a -0.6 unidades
## (baixa-mar de 2,4 m). Os nós do grupo "mare_superficie" (o plano do mar e a
## superfície da câmera, ver mar.gd) acompanham a altura; os ShaderMaterials
## registrados recebem "mare_offset_m" (em METROS) e "turbidez" (0..1, alta na
## enchente, quando a água revolve o fundo e escurece).
##
## A MARÉ VEM LIGADA. Até a Build 9B o padrão era "Sem maré" e o único interruptor ficava
## em AJUSTAR → Cenário: o jogador jogou dias sem ver a água mexer ("eu ainda não vi a
## maré"), e a maré inteira — mar, areia, canoas, tubarão, peixes, câmera — era código
## que ninguém via rodar. O padrão agora é o "Ciclo do lugar", e a hora da preamar foi
## posta nas 07:00: o jogo abre com a água cheia, como sempre abriu (o saveiro atraca
## na prancha dessa altura), vazante até a baixa-mar das 13:00 — três minutos de jogo no
## ritmo Normal, onde a praia seca e a lama aparece — e enchente de volta às 19:00.

signal mare_mudou(offset: float)

const ARQUIVO := "user://preferencias_visuais.cfg"
## Amplitude real do lugar: 2,4 m = 0.6 unidades (1 u = 4 m).
const AMPLITUDE_U := 0.6
const METROS_POR_UNIDADE := 4.0
## Modo Rápida: um ciclo completo de maré em ~90 s reais, para ver acontecer.
const CICLO_RAPIDO_S := 90.0
## O modo de fábrica: "Ciclo do lugar" (o índice do `_escolha("Maré")` de AJUSTAR).
const MODO_PADRAO := 1
## A hora do relógio do vale em que a água está mais alta (preamar): 07:00 e, no ciclo do
## lugar, 19:00 — a baixa-mar cai nas 13:00 e à 01:00. Vem de fábrica nas 07:00 porque é a
## hora em que o jogo abre (`Dia.hora_inicial`) e a chegada do saveiro não pode cair na seca.
const HORA_DA_PREAMAR := 7.0

## 0 = Sem maré (nível fixo na preamar), 1 = Ciclo do lugar (semidiurno: 2 baixas e
## 2 altas por dia de jogo), 2 = Ciclo lento (1 ciclo por dia), 3 = Rápida.
var modo := MODO_PADRAO
## Uma variável, e não só a constante, para o portão poder falsificar a hora da preamar.
var fase_da_preamar_h := HORA_DA_PREAMAR

var _offset := 0.0
## Materiais por referência fraca: morrem junto com as malhas na troca de cena.
var _materiais: Array[WeakRef] = []


func _ready() -> void:
	var fabrica := modo_de_fabrica(DisplayServer.get_name() == "headless", OS.get_environment("MV_MARE_MODO"))
	modo = modo_salvo(ARQUIVO, fabrica)


## O modo de quem nunca escolheu. Os portões rodam sem tela (`--headless`) e MEDEM o mar
## — fundo, calado, lâmina, a água que o corpo atravessa — contra um nível que não se
## mexe: lá o padrão é "Sem maré", e quem quer a maré põe o modo que quer (`tests/mare_ligada.gd`).
## `MV_MARE_MODO` (0 a 3) força o de fábrica, headless ou não: é como se roda a bateria
## da água COM maré, que é o que o jogador tem.
static func modo_de_fabrica(sem_tela: bool, forcado: String = "") -> int:
	if forcado != "":
		return clampi(forcado.to_int(), 0, 3)
	return 0 if sem_tela else MODO_PADRAO


## O modo que vale para esta pessoa: o que ela ESCOLHEU em AJUSTAR (`definir_modo` grava
## `escolhida`), ou o de fábrica. As preferências de antes da maré vir ligada não tinham a
## marca, e o padrão de então era o 0: um 0 sem marca é o padrão antigo, e não escolha —
## vai para o de fábrica, que é como o jogador de sempre passa a ver a maré. Um 1, 2 ou 3 sem
## marca só podia ser escolha de alguém, e fica.
static func modo_salvo(arquivo: String, fabrica: int) -> int:
	var preferencias := ConfigFile.new()
	if preferencias.load(arquivo) != OK:
		return fabrica
	var guardado := clampi(int(preferencias.get_value("mare", "modo", fabrica)), 0, 3)
	if bool(preferencias.get_value("mare", "escolhida", false)):
		return guardado
	return guardado if guardado != 0 else fabrica


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


## A ESCOLHA DA PESSOA, em AJUSTAR → Cenário: grava o modo e a marca de que foi escolha
## (`modo_salvo`), e a partir daí nenhum padrão novo passa por cima dela.
func definir_modo(indice: int) -> void:
	modo = clampi(indice, 0, 3)
	var preferencias := ConfigFile.new()
	preferencias.load(ARQUIVO)
	preferencias.set_value("mare", "modo", modo)
	preferencias.set_value("mare", "escolhida", true)
	preferencias.save(ARQUIVO)


## Deslocamento do nível do mar em unidades: 0.0 na preamar, -AMPLITUDE_U na baixa-mar.
func nivel_offset() -> float:
	return _offset


## Fase do ciclo em 0..1: 0 = preamar, 0.5 = baixa-mar, depois enchente até 1.
func fase() -> float:
	return fase_na_hora(Dia.hora)


## A fase na hora `hora` do relógio do vale (0 a 24). No modo Rápida ela anda no relógio de
## parede, e a hora não entra.
func fase_na_hora(hora: float) -> float:
	match modo:
		1:
			# Semidiurno como no lugar: período de 12 h → 2 baixas e 2 altas por dia.
			return fposmod(hora - fase_da_preamar_h, 12.0) / 12.0
		2:
			return fposmod(hora - fase_da_preamar_h, 24.0) / 24.0
		3:
			return fmod(Time.get_ticks_msec() / 1000.0, CICLO_RAPIDO_S) / CICLO_RAPIDO_S
	return 0.0


## O deslocamento do nível (unidades) que o modo atual dá na hora `hora`.
func nivel_na_hora(hora: float) -> float:
	if modo == 0:
		return 0.0
	return -AMPLITUDE_U * 0.5 * (1.0 - cos(fase_na_hora(hora) * TAU))


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
	return nivel_na_hora(Dia.hora)
