class_name CenaVale
extends Node
## AS CENAS DO VALE, PELOS DADOS (07/10: "implementar a mesma lógica de cutscene que fizemos
## no 2D: travando a tela e comandos do jogador e a própria engine conduzindo os personagens
## para uma interação com fala. Em alguns momentos podem explorar a vista, outros o cenário,
## outros aproximar dos personagens interagindo, talvez até fazer alguns movimentos com os
## braços").
##
## No 2D cada cena era escrita à mão (`cena_pedro_busca_machado`: o Pedro assume a cena, vai
## até a porta, o jogador espera). Aqui uma cena é uma LISTA DE COMANDOS em `data/cenas.json`,
## e o passo da missão que a declara (`cena` no dado do passo) a toca quando fecha:
## `CadeiaDeMissoes.cena` → `prototype._tocar_a_cena`. As doze cenas da chapada, da fazenda e
## do revoar continuam escritas à mão (`Prototype.CENAS_ESCRITAS_A_MAO`); as da chegada vêm
## destes dados.
##
## OS COMANDOS (`faz`):
##   segura      trava o jogador (sem andar, sem E), baixa as tarjas, entrega a câmera à cena e
##               SEGURA A FILA que emitiu a cena: o passo seguinte só se anuncia no `anuncia`
##               (ou no fim da cena).
##   camera      `modo` olha: parte de `de` e enquadra `para`, `recuo` atrás e `lado` de lado;
##               vista: de cima de `de`, varre o olhar de `olha_de` a `olha_para`; aproxima:
##               dolly até `para`, parando a `recuo`. Sempre `altura` do chão, em `tempo` s.
##   anda        `quem` vai pela malha até `folga` de `ate`, a `velocidade`, com teto `teto` s.
##   encara      `quem` fica virado para `para`.
##   gesto       `quem` mexe os braços: acenar, concordar, apontar, chamar, olhar_em_volta,
##               tchau, medo, bracos_cruzados, reverencia (`MoradorNPC.GESTOS_DA_CENA`).
##   fala        `quem` diz `texto` (texto_en/texto_es; `audio` quando há arquivo); `espera`
##               false não aguarda a fala acabar.
##   anuncia     solta o anúncio do passo seguinte — a fala do passo é a fala da cena; com
##               `espera` true aguarda essa fala acabar.
##   espera      `s` segundos do relógio da cena (a pausa do jogo pausa a cena).
##   solta       devolve câmera, jogador e fila (acontece no fim mesmo sem o comando).
##
## TODA ESPERA TEM TETO, e a cena inteira tem o seu (TETO_DA_CENA): cena nenhuma prende o jogo.
## Cena pedida durante outra espera a vez (`_fila`), e não some.
##
## Quem é `quem`/`de`/`para`/`ate`: "jogador", "pedro", o id de um morador (`_achar_morador`),
## um nome de lugar (`Lugares.ponto`), uma âncora do vale ou [x, y, z].

signal comecou(nome: String)
signal acabou(nome: String)

const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")
const FilaDeFalas = preload("res://scripts/prototipo_3d/fila_de_falas.gd")

const ARQUIVO := "res://data/cenas.json"
const COMANDOS := ["segura", "camera", "anda", "encara", "gesto", "fala", "anuncia", "espera", "solta"]
const MODOS_DE_CAMERA := ["olha", "vista", "aproxima"]
## O teto da cena inteira, em segundos do relógio dela.
const TETO_DA_CENA := 28.0
## A espera que segura a fila: o passo seguinte não se anuncia enquanto ela vale.
const SEGURA_A_FILA := 1000.0
## As tarjas pretas de cima e de baixo, em fração da tela, e o tempo de descer.
const TARJA := 0.11
const SOBE_AS_TARJAS := 0.35
const CAMADA_DAS_TARJAS := 24
## A volta da câmera para a do jogador, em segundos.
const VOLTA_DA_CAMERA := 0.8
## A câmera da cena nunca fica abaixo disto do chão.
const ACIMA_DO_CHAO := 0.5

## CENAS DESLIGADAS: nenhuma toca (os portões que dirigem a chegada na mão, como `chegada`, não
## podem ter o Pedro tomado por uma cena no meio da medida).
var desligadas := false
var _vale: Node
var _em_cena := false
var _nome := ""
var _cadeia: Node
var _espera_antes := 0.0
var _fila_segura := false
var _relogio := 0.0
var _camera: Camera3D
var _camera_do_jogador: Camera3D
var _tarjas: CanvasLayer
var _tarjas_quadro: Control
var _assumidos: Array = []
var _movidos: Array = []
var _fila: Array = []


func configurar(vale: Node) -> void:
	_vale = vale


## Todas as cenas dos dados: nome → {passos, quando}. Chaves que começam com "_" são notas.
func todas() -> Dictionary:
	# Pelo caminho do nó, e não pelo nome do autoload: um portão que cita `CenaVale` compila este
	# script antes de os autoloads existirem, e o nome não resolve.
	var jogo := get_node_or_null("/root/Jogo")
	var dados: Dictionary = jogo.dados(ARQUIVO) if jogo != null else {}
	var saida := {}
	for nome in dados:
		if not str(nome).begins_with("_") and dados[nome] is Dictionary:
			saida[str(nome)] = dados[nome]
	return saida


func tem(nome: String) -> bool:
	return todas().has(nome)


func em_cena() -> bool:
	return _em_cena


func nome_da_cena() -> String:
	return _nome


func camera_da_cena() -> Camera3D:
	return _camera


func tarjas_a_vista() -> bool:
	return _tarjas_quadro != null and _tarjas_quadro.visible


func _process(delta: float) -> void:
	if _em_cena:
		_relogio += delta


## TOCA A CENA `nome`. `cadeia` é a fila que a pediu (fica segura até o `anuncia`).
func tocar(nome: String, cadeia: Node = null) -> void:
	if desligadas or _vale == null or not tem(nome):
		return
	if _em_cena:
		_fila.append([nome, cadeia])
		return
	_em_cena = true
	_nome = nome
	_cadeia = cadeia
	_relogio = 0.0
	comecou.emit(nome)
	# UM QUADRO: quem emitiu `cena` ainda está no `avancar`, que marca a espera do passo
	# seguinte DEPOIS de emitir — segurar a fila antes disso não segurava nada.
	await get_tree().process_frame
	if not is_inside_tree() or not is_instance_valid(_vale):
		_em_cena = false
		return
	var passos: Array = (todas()[nome] as Dictionary).get("passos", [])
	for passo in passos:
		if not _em_cena or not (passo is Dictionary):
			break
		if _relogio > TETO_DA_CENA:
			push_warning("CenaVale: a cena '%s' passou de %.0f s; solta." % [nome, TETO_DA_CENA])
			break
		var p: Dictionary = passo
		var faz := str(p.get("faz", ""))
		if faz == "solta":
			break
		await _fazer(faz, p)
	await _soltar()
	if not _fila.is_empty():
		var proxima: Array = _fila.pop_front()
		tocar(str(proxima[0]), proxima[1])


func _fazer(faz: String, p: Dictionary) -> void:
	match faz:
		"segura":
			_segurar()
		"camera":
			await _camera_cmd(p)
		"anda":
			await _andar(p)
		"encara":
			_encarar(p)
		"gesto":
			_gesto(p)
		"fala":
			await _falar(p)
		"anuncia":
			await _anunciar(p)
		"espera":
			await _esperar(float(p.get("s", 0.5)))
		_:
			push_warning("CenaVale: a cena '%s' pede o comando '%s', que ninguém conhece." % [_nome, faz])


# --- segurar e soltar -------------------------------------------------------------------------

func _segurar() -> void:
	var jogador = _vale.get("player")
	if _vale.has_method("_parar_o_jogador"):
		_vale._parar_o_jogador()
	if jogador != null and "velocity" in jogador:
		jogador.velocity = Vector3.ZERO
	# O E DOS MORADORES JÁ NÃO ENTRA: a tecla dos moradores e o foco do E olham a física do
	# jogador, parada pela cena; desligá-los (08/10) deixava a dica do E acesa por cima de uma
	# tela aberta no meio da cena, porque o foco é quem a apaga com o vale parado.
	# A FILA QUE EMITIU A CENA ESPERA, se o passo seguinte ainda não foi anunciado.
	if _cadeia != null and is_instance_valid(_cadeia) and "espera" in _cadeia and float(_cadeia.espera) > 0.0:
		_espera_antes = float(_cadeia.espera)
		_cadeia.espera = SEGURA_A_FILA
		_fila_segura = true
	_montar_a_camera()
	_tarjas_a_vista_por(true)


func _soltar() -> void:
	for quem in _movidos:
		if is_instance_valid(quem) and quem.has_method("liberar"):
			quem.liberar()
	for quem in _assumidos:
		if is_instance_valid(quem) and quem.has_method("liberar_cena"):
			quem.liberar_cena()
	_movidos.clear()
	_assumidos.clear()
	if _fila_segura and _cadeia != null and is_instance_valid(_cadeia):
		_cadeia.espera = minf(_espera_antes, 0.8) if _espera_antes > 0.0 else 0.8
	_fila_segura = false
	_tarjas_a_vista_por(false)
	await _devolver_a_camera()
	if is_instance_valid(_vale) and _vale.has_method("_soltar_o_jogador"):
		_vale._soltar_o_jogador()
	var nome := _nome
	_em_cena = false
	_nome = ""
	_cadeia = null
	acabou.emit(nome)


func _esperar(segundos: float) -> void:
	var fim := _relogio + segundos
	while _em_cena and _relogio < fim and is_inside_tree():
		await get_tree().process_frame


# --- a câmera ---------------------------------------------------------------------------------

func _montar_a_camera() -> void:
	var jogador = _vale.get("player")
	_camera_do_jogador = (jogador.get("camera") as Camera3D) if jogador != null else null
	if _camera_do_jogador == null:
		return
	if _camera == null:
		_camera = Camera3D.new()
		_camera.name = "CameraDaCena"
		add_child(_camera)
	_camera.fov = _camera_do_jogador.fov
	_camera.near = _camera_do_jogador.near
	_camera.far = _camera_do_jogador.far
	_camera.global_transform = _camera_do_jogador.global_transform
	_camera.make_current()


func _camera_cmd(p: Dictionary) -> void:
	if _camera == null:
		return
	var tempo := maxf(float(p.get("tempo", 1.2)), 0.05)
	var altura := float(p.get("altura", 1.8))
	var altura_do_alvo := float(p.get("altura_do_alvo", 1.3))
	var modo := str(p.get("modo", "olha"))
	match modo:
		"olha":
			var de := _ponto(p.get("de", "jogador"))
			var para := _ponto(p.get("para", "pedro"))
			if not de.is_finite() or not para.is_finite():
				return
			var frente := _rumo(para - de)
			var lateral := frente.cross(Vector3.UP)
			var pos := de - frente * float(p.get("recuo", 3.2)) + lateral * float(p.get("lado", 1.2)) + Vector3.UP * altura
			await _levar_a_camera(_acima_do_chao(pos), para + Vector3.UP * altura_do_alvo, tempo)
		"vista":
			var de := _ponto(p.get("de", "jogador"))
			var a := _ponto(p.get("olha_de", "pedro"))
			var b := _ponto(p.get("olha_para", "praca"))
			if not de.is_finite() or not a.is_finite() or not b.is_finite():
				return
			# De cima de `de`, um passo para trás do que se olha; primeiro chega, depois varre.
			var meio := (a + b) * 0.5
			var pos := _acima_do_chao(de - _rumo(meio - de) * float(p.get("recuo", 1.0)) + Vector3.UP * altura)
			await _levar_a_camera(pos, a + Vector3.UP * altura_do_alvo, maxf(tempo * 0.3, 0.3))
			await _varrer(a + Vector3.UP * altura_do_alvo, b + Vector3.UP * altura_do_alvo, tempo)
		"aproxima":
			var para := _ponto(p.get("para", "pedro"))
			if not para.is_finite():
				return
			var de_onde := _rumo(_camera.global_position - para)
			var pos := para + de_onde * float(p.get("recuo", 3.0)) + Vector3.UP * altura
			await _levar_a_camera(_acima_do_chao(pos), para + Vector3.UP * altura_do_alvo, tempo)
		_:
			push_warning("CenaVale: a cena '%s' pede a câmera em modo '%s', que não existe." % [_nome, modo])


func _levar_a_camera(pos: Vector3, alvo: Vector3, tempo: float) -> void:
	if _camera == null:
		return
	var de := _camera.global_position
	var olhava := de - _camera.global_transform.basis.z * 4.0
	var tween := create_tween()
	tween.tween_method(_passo_da_camera.bind(de, pos, olhava, alvo), 0.0, 1.0, tempo)
	await _esperar(tempo)


func _passo_da_camera(t: float, de: Vector3, pos: Vector3, olhava: Vector3, alvo: Vector3) -> void:
	if _camera == null:
		return
	var s := smoothstep(0.0, 1.0, t)
	_camera.global_position = de.lerp(pos, s)
	_mirar(olhava.lerp(alvo, s))


func _varrer(a: Vector3, b: Vector3, tempo: float) -> void:
	if _camera == null:
		return
	var tween := create_tween()
	tween.tween_method(_passo_da_varredura.bind(a, b), 0.0, 1.0, tempo)
	await _esperar(tempo)


func _passo_da_varredura(t: float, a: Vector3, b: Vector3) -> void:
	_mirar(a.lerp(b, smoothstep(0.0, 1.0, t)))


func _mirar(alvo: Vector3) -> void:
	if _camera == null:
		return
	var direcao := alvo - _camera.global_position
	if direcao.length_squared() < 0.0025:
		return
	# Olhar a pino alinha a direção com o "para cima" e o look_at reclama: inclina um nada.
	if absf(direcao.normalized().dot(Vector3.UP)) > 0.999:
		alvo += Vector3(0.05, 0.0, 0.05)
	_camera.look_at(alvo, Vector3.UP)


func _devolver_a_camera() -> void:
	if _camera == null:
		return
	if _camera_do_jogador != null and is_instance_valid(_camera_do_jogador) and is_inside_tree():
		var inicio := _camera.global_transform
		var tween := create_tween()
		tween.tween_method(_passo_da_volta.bind(inicio), 0.0, 1.0, VOLTA_DA_CAMERA)
		await _esperar(VOLTA_DA_CAMERA)
		if is_instance_valid(_camera_do_jogador):
			_camera_do_jogador.make_current()
	if _camera != null:
		_camera.queue_free()
		_camera = null


func _passo_da_volta(t: float, inicio: Transform3D) -> void:
	if _camera == null or _camera_do_jogador == null or not is_instance_valid(_camera_do_jogador):
		return
	_camera.global_transform = inicio.interpolate_with(_camera_do_jogador.global_transform, smoothstep(0.0, 1.0, t))


func _acima_do_chao(pos: Vector3) -> Vector3:
	var mundo = _vale.get("world")
	if mundo != null and mundo.has_method("ground_height_at"):
		pos.y = maxf(pos.y, float(mundo.ground_height_at(pos)) + ACIMA_DO_CHAO)
	return pos


# --- as tarjas --------------------------------------------------------------------------------

func _tarjas_a_vista_por(sim: bool) -> void:
	if _tarjas_quadro == null:
		if not sim:
			return
		_tarjas = CanvasLayer.new()
		_tarjas.name = "TarjasDaCena"
		_tarjas.layer = CAMADA_DAS_TARJAS
		add_child(_tarjas)
		_tarjas_quadro = Control.new()
		_tarjas_quadro.name = "Tarjas"
		_tarjas_quadro.set_anchors_preset(Control.PRESET_FULL_RECT)
		_tarjas_quadro.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tarjas.add_child(_tarjas_quadro)
		for em_cima in [true, false]:
			var tarja := ColorRect.new()
			tarja.name = "Cima" if em_cima else "Baixo"
			tarja.color = Color.BLACK
			tarja.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tarja.anchor_left = 0.0
			tarja.anchor_right = 1.0
			tarja.anchor_top = 0.0 if em_cima else 1.0 - TARJA
			tarja.anchor_bottom = TARJA if em_cima else 1.0
			_tarjas_quadro.add_child(tarja)
		_tarjas_quadro.modulate.a = 0.0
	var tween := create_tween()
	if sim:
		_tarjas_quadro.visible = true
		tween.tween_property(_tarjas_quadro, "modulate:a", 1.0, SOBE_AS_TARJAS)
	else:
		tween.tween_property(_tarjas_quadro, "modulate:a", 0.0, SOBE_AS_TARJAS)
		tween.tween_callback(_esconder_as_tarjas)


func _esconder_as_tarjas() -> void:
	if _tarjas_quadro != null:
		_tarjas_quadro.visible = false


# --- os moradores -----------------------------------------------------------------------------

func _assumir(quem: Node3D) -> void:
	if quem == null or _assumidos.has(quem):
		return
	if quem.has_method("assumir_cena"):
		quem.assumir_cena()
	_assumidos.append(quem)


func _andar(p: Dictionary) -> void:
	var quem := _morador(p.get("quem", "pedro"))
	var ate := _ponto(p.get("ate", "jogador"))
	if quem == null or not ate.is_finite() or not quem.has_method("ir_ate"):
		return
	_assumir(quem)
	var folga := float(p.get("folga", 1.6))
	var destino := ate + _rumo(quem.global_position - ate) * folga
	var mundo = _vale.get("world")
	if mundo != null and mundo.has_method("ground_position"):
		destino = mundo.ground_position(destino, 0.05)
	quem.ir_ate(destino, float(p.get("velocidade", 2.6)))
	if not _movidos.has(quem):
		_movidos.append(quem)
	var fim := _relogio + float(p.get("teto", 8.0))
	while _em_cena and _relogio < fim and is_inside_tree() and is_instance_valid(quem):
		if _plano(quem.global_position, destino) < 0.5:
			break
		await get_tree().physics_frame
	if is_instance_valid(quem):
		quem.liberar()
		if quem.has_method("encarar"):
			quem.encarar(ate)


func _encarar(p: Dictionary) -> void:
	var quem := _morador(p.get("quem", "pedro"))
	var para := _ponto(p.get("para", "jogador"))
	if quem == null or not para.is_finite() or not quem.has_method("encarar"):
		return
	_assumir(quem)
	quem.encarar(para)


func _gesto(p: Dictionary) -> void:
	var quem := _morador(p.get("quem", "pedro"))
	if quem == null or not quem.has_method("gesto"):
		return
	_assumir(quem)
	quem.gesto(str(p.get("gesto", "acenar")))


func _falar(p: Dictionary) -> void:
	var quem := _morador(p.get("quem", "pedro"))
	if quem == null or not quem.has_method("narrar"):
		return
	var texto := str(IdiomaMenu.campo(p, "texto", ""))
	if texto.strip_edges() == "":
		return
	var acabou_a_fala := [false]
	quem.narrar(str(p.get("audio", "")), texto, {
		"classe": FilaDeFalas.Classe.CONVERSA,
		"ao_terminar": func() -> void: acabou_a_fala[0] = true,
	})
	if not bool(p.get("espera", true)):
		return
	var fim := _relogio + 3.0 + float(texto.length()) / 10.0
	while _em_cena and not acabou_a_fala[0] and _relogio < fim and is_inside_tree():
		await get_tree().process_frame


func _anunciar(p: Dictionary) -> void:
	if _cadeia == null or not is_instance_valid(_cadeia):
		return
	if _fila_segura:
		# UM NADA, E NÃO ZERO: a fila só anuncia quando a espera VENCE (`CadeiaDeMissoes.correr`);
		# espera zerada na mão nunca chega ao anúncio.
		_cadeia.espera = 0.05
		_fila_segura = false
	if not bool(p.get("espera", false)):
		return
	var dono = _cadeia.get("dono")
	if dono == null or not dono.has_method("falando_agora"):
		return
	# A fala do anúncio começa na vez dela e acaba quando acaba — ou no teto.
	var fim := _relogio + float(p.get("teto", 18.0))
	var comecou_a_fala := false
	while _em_cena and _relogio < fim and is_inside_tree() and is_instance_valid(dono):
		if bool(dono.falando_agora()):
			comecou_a_fala = true
		elif comecou_a_fala:
			break
		await get_tree().process_frame


# --- quem e onde ------------------------------------------------------------------------------

func _morador(ref) -> Node3D:
	var nome := str(ref)
	if nome == "pedro":
		return _vale.get("pedro") as Node3D
	if nome == "jogador" or not _vale.has_method("_achar_morador"):
		return null
	return _vale._achar_morador(nome) as Node3D


func _ponto(ref) -> Vector3:
	if ref is Array and (ref as Array).size() == 3:
		return Vector3(float(ref[0]), float(ref[1]), float(ref[2]))
	var nome := str(ref)
	if nome == "jogador":
		var jogador = _vale.get("player")
		return jogador.global_position if jogador != null else Vector3.INF
	var quem := _morador(nome)
	if quem != null:
		return quem.global_position
	var mundo = _vale.get("world")
	if mundo != null and "ancoras" in mundo and (mundo.ancoras as Dictionary).has(nome):
		return mundo.ancoras[nome]
	var lugares := get_node_or_null("/root/Lugares")
	if lugares != null:
		var p: Vector3 = lugares.ponto(nome)
		if p.is_finite():
			return p
	return Vector3.INF


static func _rumo(v: Vector3) -> Vector3:
	v.y = 0.0
	return v.normalized() if v.length() > 0.05 else Vector3.FORWARD


static func _plano(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
