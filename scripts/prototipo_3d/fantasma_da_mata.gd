extends Node3D
## O VULTO DA MATA — o susto que parece defeito. Lá no fundo da mata, de vez em quando, aparece um
## vulto pálido entre os troncos, atrás do jogador. Quem VIRA A CÂMERA para ele o vê sumir, e não
## acontece nada. Quem fica de costas o vê chegar devagar e depois disparar — e, quando ele alcança, o
## jogo SALVA, sem aviso, e FECHA de repente, como se tivesse caído. Não é defeito. O ajuste "Sustos"
## (AJUSTAR → Cenário) desliga tudo isto.
##
## AS REGRAS (todas no `porque_nao`, na ordem em que valem, para o portão e o log lerem o motivo):
##   - a chave Sustos ligada (desligada na edição Tripothon e com `--sem-sustos`);
##   - não nos portões (sem tela), salvo `forcar_para_o_portao` — o `quit()` de um portão sem tela sai
##     com código 0, e portão que acaba cedo PASSA: falso verde;
##   - com no mínimo `SESSAO_MINIMA` s de jogo, o tutorial do Pedro acabado, e no máximo UMA vez por
##     sessão, e nunca antes de `ESFRIAR_REAL` s de relógio desde a última (guardada em disco);
##   - o jogo LIVRE: nenhuma tela, fala, festa, interior, nado nem caçada de onça (`livre`);
##   - o jogador no fundo da mata (`mata_funda.gd`).
## E o sorteio: só depois de `FUNDO_MINIMO` s ANDANDO na mata funda (parado ou teleportado não conta),
## a cada `SORTEIO_A_CADA` s, com `CHANCE` (o dobro de tarde para a noite).
##
## O QUE ELE FAZ: aparece a 20-35 u, FORA da vista (o sussurro 3D chama), em lugar de onde a câmera o
## veria sem tronco no meio. `OLHAR_PARA_SUMIR` s com ele no campo de visão e sem nada na frente, e ele
## se desfaz. Sem ser olhado, espreita (anda a 2,4 u/s) até 12 u — ou até `TEMPO_PARA_O_BOTE` s — e
## dispara a 9,5 u/s. Parado enquanto olhado: olhar ganha. Some quieto se o jogador entra em casa,
## nada, abre uma tela, sai da mata ou passa de `VIDA_MAXIMA` s. Ao alcançar: `pegou`, `salvar`,
## a tela congela e fica muda, e `sair`.

const MataFunda = preload("res://scripts/prototipo_3d/mata_funda.gd")
const SustosDaMata = preload("res://scripts/prototipo_3d/sustos_da_mata.gd")

signal apareceu(onde: Vector3)
## `porque`: "olhado", "abortado", "longe", "fora_da_mata".
signal sumiu(porque: String)
## Emitido ANTES de salvar e de sair.
signal pegou

enum Estado { DORMINDO, APARECENDO, ESPREITANDO, BOTE, PEGOU, SUMINDO }

const ARQUIVO_DO_ESFRIAR := "user://sustos.cfg"
## Antes de existir: segundos de jogo, de andança na mata funda, e a cadência do sorteio.
const SESSAO_MINIMA := 240.0
const FUNDO_MINIMO := 90.0
const SORTEIO_A_CADA := 20.0
const CHANCE := 0.06
const ESFRIAR_REAL := 1800.0
## De onde aparece (u) e o ângulo mínimo da frente da câmera (graus): sempre fora da vista.
const DISTANCIA := Vector2(20.0, 35.0)
const ANGULO_ATRAS := 100.0
## O que a câmera precisa: tempo com ele na vista e sem nada na frente (s). O resto do olhar esquece
## depressa (duas vezes mais que acumula), para um olhar de relance não somar com o outro de longe.
const OLHAR_PARA_SUMIR := 0.4
## Como ele se move (u/s) e quando dispara (u, s), quanto o bote pode durar e a distância que pega.
const VELOCIDADE_DE_ESPREITA := 2.4
const VELOCIDADE_DO_BOTE := 9.5
const DISTANCIA_DO_BOTE := 12.0
const TEMPO_PARA_O_BOTE := 8.0
const DURACAO_DO_BOTE := 4.0
const DISTANCIA_QUE_PEGA := 1.1
const VIDA_MAXIMA := 22.0
const LONGE_DEMAIS := 60.0
const TELEGRAFO := 1.5
const SEGUNDOS_PARA_APARECER := 1.1
const SEGUNDOS_PARA_SUMIR := 0.9
## Fora da mata funda por mais que isto (s), ele desiste.
const TOLERANCIA_FORA_DA_MATA := 3.0
## O jogo congela e fica mudo por isto (s de relógio de parede) antes de fechar.
const CONGELA_POR := 0.35
const CHECAGEM := 0.5
## Mais alto que gente (o personagem tem 1,78 u): a túnica de 2,17 u sobe a escala `ALTURA / 2.17`.
const ALTURA := 2.8
const ALTURA_DA_MALHA := 2.17

## `forcar_para_o_portao` liga o vulto onde não há tela; as aparições da sessão contam entre cenas.
static var forcar_para_o_portao := false
static var aparicoes_nesta_sessao := 0

## O que acontece no fim: guardar a partida (por padrão `Partida.salvar`) e fechar o jogo. Os portões põem
## aqui gravadores — o `quit()` de verdade sai com código 0 e o portão PASSARIA.
var salvar := Callable()
var sair := Callable()
## Segundos de jogo desde que o vale subiu, e andando na mata funda desde a última aparição ou sorteio.
var sessao_s := 0.0
var fundo_s := 0.0
var estado := Estado.DORMINDO
var vida_s := 0.0
var olhado_s := 0.0
## 0 é inteiro, 1 é nada (o `dissolver` do shader).
var dissolver := 1.0

var _world
var _jogador
var _luta
var _livre := Callable()
var _tutorial_acabou := Callable()
var _checar := 0.0
var _sortear := 0.0
var _fora_da_funda := 0.0
var _tempo_do_bote := 0.0
var _ultima_aparicao := 0.0
var _ligado := true
var _corpo: Node3D
var _material: ShaderMaterial
var _olhos: Array[MeshInstance3D] = []
var _bracos: Array[MeshInstance3D] = []


func configurar(world: Object, jogador: Node3D, livre: Callable = Callable(), tutorial_acabou: Callable = Callable(), luta: Node = null) -> void:
	_world = world
	_jogador = jogador
	_livre = livre
	_tutorial_acabou = tutorial_acabou
	_luta = luta
	var guardado := ConfigFile.new()
	if guardado.load(ARQUIVO_DO_ESFRIAR) == OK:
		_ultima_aparicao = float(guardado.get_value("fantasma", "ultima", 0.0))
	if not salvar.is_valid():
		salvar = Callable(Partida, "salvar")
	if not sair.is_valid():
		sair = _fechar_de_verdade
	_ligado = SustosDaMata.ligado()
	visible = false
	set_process(true)


func _process(delta: float) -> void:
	sessao_s += delta
	match estado:
		Estado.DORMINDO:
			_vigiar(delta)
		Estado.APARECENDO, Estado.ESPREITANDO, Estado.BOTE:
			_viver(delta)
		Estado.SUMINDO:
			_desfazer(delta)
		_:
			pass


## Por que o vulto NÃO pode aparecer agora ("" se pode): as guardas, na ordem em que valem.
func porque_nao() -> String:
	if not SustosDaMata.ligado():
		return "desligado"
	if DisplayServer.get_name() == "headless" and not forcar_para_o_portao:
		return "sem_tela"
	if sessao_s < SESSAO_MINIMA:
		return "sessao_curta"
	if aparicoes_nesta_sessao >= 1:
		return "ja_apareceu"
	if Time.get_unix_time_from_system() - _ultima_aparicao < ESFRIAR_REAL:
		return "esfriando"
	if _tutorial_acabou.is_valid() and not bool(_tutorial_acabou.call()):
		return "tutorial"
	if _jogador == null or String(_jogador.dentro_de) != "":
		return "interior"
	if _jogador.is_swimming():
		return "nadando"
	if _livre.is_valid() and not bool(_livre.call()):
		return "tela_aberta"
	if _caca_de_onca():
		return "cacada"
	if not MataFunda.e_funda(_world, _jogador.global_position):
		return "fora_da_mata"
	return ""


## Faz o vulto aparecer AGORA (o sorteio e o portão usam esta). `distancia` negativa sorteia entre
## `DISTANCIA`. Devolve false sem lugar bom ou com alguma guarda fechada.
func aparecer(distancia: float = -1.0) -> bool:
	if estado != Estado.DORMINDO or porque_nao() != "":
		return false
	var lugar: Variant = _escolher_o_lugar(distancia)
	if lugar == null:
		return false
	_comecar(lugar)
	return true


func _vigiar(delta: float) -> void:
	_checar -= delta
	if _checar > 0.0:
		return
	_checar = CHECAGEM
	_ligado = SustosDaMata.ligado()
	if porque_nao() != "":
		return
	# Só conta a andança por conta própria na mata funda: parado, ou teleportado, o vulto não nasce.
	if Vector2(_jogador.velocity.x, _jogador.velocity.z).length() < 0.5:
		return
	fundo_s += CHECAGEM
	if fundo_s < FUNDO_MINIMO:
		return
	_sortear += CHECAGEM
	if _sortear < SORTEIO_A_CADA:
		return
	_sortear = 0.0
	var chance := CHANCE * (2.0 if String(Dia.periodo()) in ["entardecer", "noite", "madrugada"] else 1.0)
	if randf() < chance:
		aparecer()


func _comecar(lugar: Vector3) -> void:
	aparicoes_nesta_sessao += 1
	_ultima_aparicao = Time.get_unix_time_from_system()
	var guardado := ConfigFile.new()
	guardado.load(ARQUIVO_DO_ESFRIAR)
	guardado.set_value("fantasma", "ultima", _ultima_aparicao)
	guardado.save(ARQUIVO_DO_ESFRIAR)
	fundo_s = 0.0
	_sortear = 0.0
	_montar_o_corpo()
	global_position = lugar
	vida_s = 0.0
	olhado_s = 0.0
	_fora_da_funda = 0.0
	_tempo_do_bote = 0.0
	dissolver = 1.0
	_aplicar_o_dissolver()
	visible = true
	estado = Estado.APARECENDO
	_virar_para_o_jogador()
	SustosDaMata.tocar_3d(self, "fantasma_sussurro", lugar + Vector3(0.0, 1.5, 0.0), 90.0, 14.0)
	apareceu.emit(lugar)


func _viver(delta: float) -> void:
	vida_s += delta
	_checar -= delta
	if _checar <= 0.0:
		_checar = CHECAGEM
		_ligado = SustosDaMata.ligado()
		if MataFunda.e_funda(_world, _jogador.global_position):
			_fora_da_funda = 0.0
		else:
			_fora_da_funda += CHECAGEM
	var motivo := _porque_abortar()
	if motivo != "":
		_sumir(motivo)
		return
	var olhando := _olhando()
	if olhando:
		olhado_s += delta
		if olhado_s >= OLHAR_PARA_SUMIR:
			_sumir("olhado")
			return
	else:
		olhado_s = maxf(olhado_s - 2.0 * delta, 0.0)
	_balancar()
	var para: Vector3 = _jogador.global_position - global_position
	para.y = 0.0
	var distancia: float = para.length()
	match estado:
		Estado.APARECENDO:
			dissolver = move_toward(dissolver, 0.0, delta / SEGUNDOS_PARA_APARECER)
			_aplicar_o_dissolver()
			if vida_s >= TELEGRAFO:
				estado = Estado.ESPREITANDO
		Estado.ESPREITANDO:
			if not olhando:
				_andar(para, VELOCIDADE_DE_ESPREITA * delta)
			if distancia <= DISTANCIA_DO_BOTE or vida_s >= TEMPO_PARA_O_BOTE:
				_comecar_o_bote()
		Estado.BOTE:
			_tempo_do_bote += delta
			if not olhando:
				_andar(para, VELOCIDADE_DO_BOTE * delta)
			if distancia <= DISTANCIA_QUE_PEGA:
				_pegar()
			elif _tempo_do_bote >= DURACAO_DO_BOTE:
				_sumir("longe")
	if estado != Estado.PEGOU and estado != Estado.SUMINDO:
		_virar_para_o_jogador()


## A câmera o vê: no campo de visão (o peito ou a cabeça), ATRÁS do jogador (mais longe da câmera que
## ele), sem tronco, chão ou casa na frente. A câmera de terceira pessoa fica uns 8 u atrás do corpo:
## quem vem de costas para o jogador passa ENTRE a câmera e o corpo nos últimos metros, e isso não é o
## jogador olhar para ele — senão o vulto nunca alcançaria ninguém que anda para a frente.
func _olhando() -> bool:
	var camera: Camera3D = _jogador.camera
	if camera == null or not camera.is_inside_tree():
		return false
	var peito := global_position + Vector3(0.0, ALTURA * 0.5, 0.0)
	var cabeca := global_position + Vector3(0.0, ALTURA * 0.9, 0.0)
	if not camera.is_position_in_frustum(peito) and not camera.is_position_in_frustum(cabeca):
		return false
	var olho: Vector3 = camera.global_position
	if olho.distance_to(peito) <= olho.distance_to((_jogador.global_position as Vector3) + Vector3(0.0, 1.0, 0.0)):
		return false
	return MataFunda.linha_livre(self, _world, olho, peito, [_jogador.get_rid()])


func _porque_abortar() -> String:
	if not _ligado:
		return "abortado"
	if _livre.is_valid() and not bool(_livre.call()):
		return "abortado"
	if String(_jogador.dentro_de) != "" or _jogador.is_swimming():
		return "abortado"
	if vida_s >= VIDA_MAXIMA:
		return "longe"
	if _fora_da_funda >= TOLERANCIA_FORA_DA_MATA:
		return "fora_da_mata"
	if global_position.distance_to(_jogador.global_position) > LONGE_DEMAIS:
		return "longe"
	return ""


func _comecar_o_bote() -> void:
	estado = Estado.BOTE
	_tempo_do_bote = 0.0
	SustosDaMata.tocar_3d(self, "fantasma_avanco", global_position + Vector3(0.0, 1.2, 0.0), 90.0, 12.0, true)


func _andar(para: Vector3, passo: float) -> void:
	if para.length() < 0.001:
		return
	var novo := global_position + para.normalized() * minf(passo, para.length())
	novo.y = _world.ground_height_at(novo)
	global_position = novo


func _virar_para_o_jogador() -> void:
	var para: Vector3 = _jogador.global_position - global_position
	rotation.y = atan2(para.x, para.z)


## O vulto se desfaz (sem pegar ninguém). O sinal sai na hora da decisão, e o corpo some em seguida.
func _sumir(porque: String) -> void:
	if estado == Estado.SUMINDO or estado == Estado.PEGOU or estado == Estado.DORMINDO:
		return
	estado = Estado.SUMINDO
	sumiu.emit(porque)


func _desfazer(delta: float) -> void:
	dissolver = move_toward(dissolver, 1.0, delta / SEGUNDOS_PARA_SUMIR)
	_aplicar_o_dissolver()
	if dissolver >= 1.0:
		visible = false
		estado = Estado.DORMINDO


## ALCANÇOU: guarda a partida, congela a tela e a deixa muda, e fecha. Sem mensagem.
func _pegar() -> void:
	estado = Estado.PEGOU
	pegou.emit()
	if salvar.is_valid():
		salvar.call()
	_travar_a_tela()
	await get_tree().create_timer(CONGELA_POR, true, false, true).timeout
	if sair.is_valid():
		sair.call()


## A queda de mentira: o jogo para onde está (a pausa não para o relógio de parede, só o jogo) e o som
## corta, como num travamento. Um quadro de preto no fim, e o `sair`.
func _travar_a_tela() -> void:
	var master := AudioServer.get_bus_index(&"Master")
	if master >= 0:
		AudioServer.set_bus_mute(master, true)
	get_tree().paused = true
	var camada := CanvasLayer.new()
	camada.layer = 200
	camada.process_mode = Node.PROCESS_MODE_ALWAYS
	var preto := ColorRect.new()
	preto.color = Color.BLACK
	preto.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preto.visible = false
	camada.add_child(preto)
	get_tree().root.add_child(camada)
	# O preto só entra no último instante: até lá o jogador vê o quadro em que o vulto o alcançou.
	get_tree().create_timer(maxf(CONGELA_POR - 0.05, 0.01), true, false, true).timeout.connect(func() -> void: preto.visible = true)


func _fechar_de_verdade() -> void:
	if DisplayServer.get_name() == "headless" and not forcar_para_o_portao:
		push_warning("Vulto da mata: recusei fechar o jogo sem tela (um portão sairia com código 0, e passaria).")
		return
	get_tree().quit()


func _caca_de_onca() -> bool:
	if _luta == null:
		return false
	for onca in _luta.oncas:
		if is_instance_valid(onca) and bool(onca.cacando):
			return true
	return false


## Onde ele aparece: 20-35 u do jogador (ou `distancia`), num ângulo de trás (100 a 180 graus da frente
## da câmera, para o lado que cair), em mata funda, fora do campo de visão — e com a linha livre dos
## olhos do jogador até o peito dele, para virar a câmera servir de alguma coisa.
func _escolher_o_lugar(distancia: float) -> Variant:
	var camera: Camera3D = _jogador.camera
	var frente := Vector3.FORWARD
	if camera != null:
		frente = -camera.global_basis.z
		frente.y = 0.0
		frente = frente.normalized() if frente.length() > 0.01 else Vector3.FORWARD
	var centro: Vector3 = _jogador.global_position
	for _tentativa in range(48):
		var graus := randf_range(ANGULO_ATRAS, 180.0) * (1.0 if randf() < 0.5 else -1.0)
		var rumo := frente.rotated(Vector3.UP, deg_to_rad(graus))
		var longe := distancia if distancia > 0.0 else randf_range(DISTANCIA.x, DISTANCIA.y)
		var alvo := centro + rumo * longe
		var lugar: Vector3 = _world.ground_position(Vector3(alvo.x, 0.0, alvo.z))
		if not MataFunda.e_funda(_world, lugar):
			continue
		if camera != null and (camera.is_position_in_frustum(lugar + Vector3(0.0, ALTURA * 0.5, 0.0)) or camera.is_position_in_frustum(lugar + Vector3(0.0, ALTURA * 0.9, 0.0))):
			continue
		var olhos := centro + Vector3(0.0, MataFunda.ALTURA_DOS_OLHOS, 0.0)
		if not MataFunda.linha_livre(self, _world, olhos, lugar + Vector3(0.0, MataFunda.ALTURA_DO_PEITO, 0.0), [_jogador.get_rid()]):
			continue
		return lugar
	return null


# --- o corpo --------------------------------------------------------------------

const SOMBRA_DO_VULTO := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;
uniform float dissolver : hint_range(0.0, 1.0) = 1.0;
uniform vec3 cor : source_color = vec3(0.80, 0.88, 0.93);
varying vec3 pos_mundo;
varying float alto;
float h(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
float ruido(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h(i), h(i + vec3(1.0, 0.0, 0.0)), f.x), mix(h(i + vec3(0.0, 1.0, 0.0)), h(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(h(i + vec3(0.0, 0.0, 1.0)), h(i + vec3(1.0, 0.0, 1.0)), f.x), mix(h(i + vec3(0.0, 1.0, 1.0)), h(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}
void vertex() {
	// A barra da túnica ondula e esfarrapa; o resto quase não se mexe.
	float barra = 1.0 - smoothstep(0.0, 0.7, VERTEX.y / 2.17);
	VERTEX.x += sin(TIME * 1.6 + VERTEX.y * 4.0 + VERTEX.z * 3.0) * 0.05 * (barra + 0.1);
	VERTEX.z += cos(TIME * 1.3 + VERTEX.y * 3.0 + VERTEX.x * 3.0) * 0.05 * (barra + 0.1);
	VERTEX.y += sin(atan(VERTEX.z, VERTEX.x) * 6.0 + TIME * 2.0) * 0.06 * barra * step(VERTEX.y, 0.5);
	alto = clamp(VERTEX.y / 2.17, 0.0, 1.0);
	pos_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	// Fumaça subindo: o ruído anda para cima, devagar. Sem pisca: nada aqui varia depressa.
	float n = ruido(pos_mundo * 2.2 + vec3(0.0, TIME * 0.3, 0.0));
	if (n < dissolver) {
		discard;
	}
	float borda = 1.0 - smoothstep(dissolver, dissolver + 0.14, n);
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.2);
	ALBEDO = cor + borda * vec3(0.25, 0.32, 0.36);
	// A barra some em fiapos (quase nada na altura do chão); a cabeça e o peito são o que se vê.
	float fiapo = mix(0.12, 1.0, smoothstep(0.0, 0.55, alto));
	ALPHA = clamp((0.2 + fresnel * 0.5) * fiapo + borda * 0.35, 0.0, 0.85);
}
"""

## O perfil da túnica (raio, altura), da barra à cabeça.
const PERFIL := [
	Vector2(0.58, 0.0), Vector2(0.52, 0.35), Vector2(0.42, 0.8), Vector2(0.34, 1.2), Vector2(0.3, 1.5),
	Vector2(0.2, 1.62), Vector2(0.11, 1.72), Vector2(0.16, 1.78), Vector2(0.2, 1.88), Vector2(0.19, 2.0),
	Vector2(0.12, 2.12), Vector2(0.0, 2.17),
]
const LADOS := 18


func _montar_o_corpo() -> void:
	if _corpo != null:
		return
	_corpo = Node3D.new()
	_corpo.name = "Corpo"
	_corpo.scale = Vector3.ONE * (ALTURA / ALTURA_DA_MALHA)
	add_child(_corpo)
	var sombra := Shader.new()
	sombra.code = SOMBRA_DO_VULTO
	_material = ShaderMaterial.new()
	_material.shader = sombra
	var tunica := MeshInstance3D.new()
	tunica.name = "Tunica"
	tunica.mesh = _malha_da_tunica()
	tunica.material_override = _material
	tunica.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_corpo.add_child(tunica)
	# Os braços compridos, caídos dos ombros: o que faz dele "gente" de longe.
	for lado in [-1.0, 1.0]:
		var braco := MeshInstance3D.new()
		var malha := CapsuleMesh.new()
		malha.radius = 0.045
		malha.height = 1.5
		braco.mesh = malha
		braco.material_override = _material
		braco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		braco.position = Vector3(lado * 0.36, 1.0, 0.04)
		braco.rotation = Vector3(0.0, 0.0, lado * 0.1)
		_corpo.add_child(braco)
		_bracos.append(braco)
	# Os olhos: dois furos escuros que aparecem através da névoa dele.
	var preto := StandardMaterial3D.new()
	preto.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	preto.albedo_color = Color(0.02, 0.02, 0.03, 1.0)
	preto.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for lado in [-1.0, 1.0]:
		var olho := MeshInstance3D.new()
		var bola := SphereMesh.new()
		bola.radius = 0.034
		bola.height = 0.068
		olho.mesh = bola
		olho.material_override = preto
		olho.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		olho.position = Vector3(lado * 0.07, 1.92, 0.16)
		_corpo.add_child(olho)
		_olhos.append(olho)


## A túnica: uma superfície de revolução do `PERFIL`, com a normal pela inclinação do perfil.
func _malha_da_tunica() -> ArrayMesh:
	var posicoes := PackedVector3Array()
	var normais := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for i in range(PERFIL.size()):
		var antes: Vector2 = PERFIL[maxi(i - 1, 0)]
		var depois: Vector2 = PERFIL[mini(i + 1, PERFIL.size() - 1)]
		var tangente := depois - antes
		var normal_do_perfil := Vector2(tangente.y, -tangente.x).normalized()
		for j in range(LADOS + 1):
			var angulo := TAU * float(j) / float(LADOS)
			var raio: float = (PERFIL[i] as Vector2).x
			posicoes.append(Vector3(cos(angulo) * raio, (PERFIL[i] as Vector2).y, sin(angulo) * raio))
			normais.append(Vector3(cos(angulo) * normal_do_perfil.x, normal_do_perfil.y, sin(angulo) * normal_do_perfil.x).normalized())
			uvs.append(Vector2(float(j) / float(LADOS), float(i) / float(PERFIL.size() - 1)))
	for i in range(PERFIL.size() - 1):
		for j in range(LADOS):
			var a := i * (LADOS + 1) + j
			var b := a + LADOS + 1
			indices.append_array([a, a + 1, b, a + 1, b + 1, b])
	var matrizes := []
	matrizes.resize(Mesh.ARRAY_MAX)
	matrizes[Mesh.ARRAY_VERTEX] = posicoes
	matrizes[Mesh.ARRAY_NORMAL] = normais
	matrizes[Mesh.ARRAY_TEX_UV] = uvs
	matrizes[Mesh.ARRAY_INDEX] = indices
	var malha := ArrayMesh.new()
	malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, matrizes)
	return malha


func _aplicar_o_dissolver() -> void:
	if _material != null:
		_material.set_shader_parameter("dissolver", dissolver)
	for olho in _olhos:
		(olho.material_override as StandardMaterial3D).albedo_color.a = clampf(1.0 - dissolver * 1.4, 0.0, 1.0)


## Os braços balançam de leve, fora de compasso.
func _balancar() -> void:
	var t := vida_s * 1.4
	for i in range(_bracos.size()):
		var lado := -1.0 if i == 0 else 1.0
		_bracos[i].rotation.x = sin(t + float(i) * 1.7) * 0.12
		_bracos[i].rotation.z = lado * (0.1 + 0.05 * sin(t * 0.7 + float(i)))
