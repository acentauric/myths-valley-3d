extends Node
## A CÂMERA DA SESSÃO DE TESTE (#201): o viajante nunca fica escondido atrás de um poste.
##
## "A câmera fica atrás de um poste/tronco e o viajante some da tela": quem assiste não
## sabe o que o testador faz, e as capturas do relatório ficam inúteis. No jogo normal
## isso é de propósito: mourão, tronco, morador e móvel não barram a câmera (`camadas.gd`),
## porque o braço dela, ao encolher a cada peça fina, dava pulos. Aqui é só da sessão de
## teste, e o jogo comum não muda: este nó é criado pelo `sessao.gd` e mexe no giro e na
## distância da câmera do jogador, sem tocar nas camadas nem no código dele.
##
## A cada quadro, um raio da câmera até o peito e outro até a cabeça. Se algo opaco
## barra (poste, tronco, parede, árvore, chão; moradores e bichos não contam), a câmera
## GIRA em órbita para o lado livre mais próximo, e se não houver lado livre APROXIMA até
## passar à frente do obstáculo. O giro é suave (o ritmo é limitado), a distância
## volta ao que era quando o caminho abre, e um relance (cruzar um poste andando) não faz
## nada: só age depois de `CONFIRMA_S` encoberto.

const Camadas = preload("res://scripts/prototipo_3d/camadas.gd")

## O que esconde o viajante: o corpo do mundo, o que a câmera respeita e a malha da vegetação.
const MASCARA_DA_VISTA := Camadas.MUNDO | Camadas.CAMERA | Camadas.CAMERA_VEGETACAO
const ALTURA_DO_PEITO := 1.1
const ALTURA_DA_CABECA := 1.65
const DISTANCIA_MINIMA := 1.6
## A órbita é procurada de passo em passo (rad), dos dois lados, até a volta inteira.
const PASSO_DO_GIRO := 0.35
const PASSOS_DO_GIRO := 9
## O ritmo máximo do giro (rad/s): uns 90° em meio segundo, sem tremer.
const GIRO_MAXIMO_POR_S := 3.2
## Quanto tempo encoberto antes de agir, e de sondar de novo; abaixo disto é relance.
const CONFIRMA_S := 0.2
const SONDA_A_CADA_S := 0.15
## Encoberto por tanto tempo é achado do relatório (o critério é não passar de ~1 s).
const ENCOBERTO_DEMAIS_S := 1.5
## A distância só volta ao que era depois de tanto tempo livre, e devagar (m/s).
const LIVRE_ANTES_DE_VOLTAR_S := 1.5
const VOLTA_DA_DISTANCIA_POR_S := 1.5

signal encoberto_demais(segundos: float)

var jogador: CharacterBody3D

var encoberto_s := 0.0
var _livre_s := 0.0
var _sonda_s := 0.0
var _alvo_yaw := NAN
var _distancia_original := NAN
var _anunciado := false


# --- a geometria, sem estado: é o que o portão confere -----------------------------

## Onde fica a câmera com o pivô, o giro, a inclinação e o braço dados (a conta do
## `player_controller.gd`, que a mede no `SpringArm3D`).
static func posicao_da_camera(pivo: Vector3, yaw: float, pitch: float, distancia: float) -> Vector3:
	return pivo + (Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)) * Vector3(0.0, 0.0, distancia)


## O primeiro corpo opaco entre `de` e `ate`, ou {}. Morador, bicho e o próprio viajante
## (`excluir`) não escondem ninguém: o raio os atravessa e segue.
static func primeiro_bloqueio(espaco: PhysicsDirectSpaceState3D, de: Vector3, ate: Vector3, excluir: Array[RID]) -> Dictionary:
	var fora: Array[RID] = excluir.duplicate()
	for _volta in 6:
		var consulta := PhysicsRayQueryParameters3D.create(de, ate, MASCARA_DA_VISTA, fora)
		var acerto := espaco.intersect_ray(consulta)
		if acerto.is_empty():
			return {}
		if acerto.get("collider") is CharacterBody3D:
			fora.append(acerto["rid"])
			continue
		return acerto
	return {}


## A câmera em `camera` perde o viajante de vista (o peito ou a cabeça atrás de algo)?
static func encoberto_de(espaco: PhysicsDirectSpaceState3D, camera: Vector3, peito: Vector3, cabeca: Vector3, excluir: Array[RID]) -> bool:
	return not primeiro_bloqueio(espaco, camera, peito, excluir).is_empty() \
		or not primeiro_bloqueio(espaco, camera, cabeca, excluir).is_empty()


## O que fazer com a câmera de agora. `braco_livre` (Callable(yaw) -> float) diz até onde o
## braço chega num giro; no jogo é o corte dele contra o chão e as paredes. Devolve
## {"encoberto": bool, "yaw": float, "distancia": float, "livre": bool}: `livre` é se a
## pose devolvida deixa o viajante à vista. Sem obstáculo, a pose é a de entrada.
static func resolver(espaco: PhysicsDirectSpaceState3D, pivo: Vector3, peito: Vector3, cabeca: Vector3,
		yaw: float, pitch: float, distancia: float, excluir: Array[RID], braco_livre: Callable) -> Dictionary:
	var camera := posicao_da_camera(pivo, yaw, pitch, distancia)
	if not encoberto_de(espaco, camera, peito, cabeca, excluir):
		return {"encoberto": false, "yaw": yaw, "distancia": distancia, "livre": true}
	# 1. GIRAR para o lado livre mais próximo (os dois lados, do menor giro ao maior).
	for passo in range(1, PASSOS_DO_GIRO + 1):
		for sinal in [1.0, -1.0]:
			var giro: float = yaw + sinal * passo * PASSO_DO_GIRO
			var braco: float = float(braco_livre.call(giro)) if braco_livre.is_valid() else distancia
			if braco < distancia * 0.8:
				continue
			var candidata := posicao_da_camera(pivo, giro, pitch, minf(braco, distancia))
			if not encoberto_de(espaco, candidata, peito, cabeca, excluir):
				return {"encoberto": true, "yaw": giro, "distancia": distancia, "livre": true}
	# 2. APROXIMAR até passar à frente do obstáculo, sem entrar no corpo.
	var acerto := primeiro_bloqueio(espaco, peito, camera, excluir)
	if not acerto.is_empty():
		var nova := maxf(DISTANCIA_MINIMA, (acerto["position"] as Vector3).distance_to(pivo) - 0.4)
		if nova < distancia - 0.05:
			var perto := posicao_da_camera(pivo, yaw, pitch, nova)
			return {"encoberto": true, "yaw": yaw, "distancia": nova,
				"livre": not encoberto_de(espaco, perto, peito, cabeca, excluir)}
	return {"encoberto": true, "yaw": yaw, "distancia": distancia, "livre": false}


# --- o nó da sessão ----------------------------------------------------------------

## Só age onde a câmera é a de passeio: de cima (cômodo) o teto some, e nadando a água
## é que barra a vista.
func _aplicavel() -> bool:
	return jogador != null and is_instance_valid(jogador) and jogador.is_inside_tree() \
		and jogador.get("camera") != null and not bool(jogador.get("_de_cima")) \
		and not bool(jogador.call("is_swimming")) and not get_tree().paused


func _excluidos() -> Array[RID]:
	var fora: Array[RID] = [jogador.get_rid()]
	return fora


func _pontos() -> Array[Vector3]:
	var pe: Vector3 = jogador.global_position
	return [pe + Vector3.UP * ALTURA_DO_PEITO, pe + Vector3.UP * ALTURA_DA_CABECA]


## Até onde o braço da câmera do jogador chega num giro (o corte dele, com o giro trocado
## por um instante, como a câmera automática do jogo faz).
func _braco_no_giro(giro: float) -> float:
	var pivo: Node3D = jogador.get("camera_pivot")
	var guardado := pivo.rotation.y
	pivo.rotation.y = giro
	var livre: float = float(jogador.call("_braco_livre", float(jogador.get("_pitch")), float(jogador.call("distancia_da_vista"))))
	pivo.rotation.y = guardado
	return livre


func _resolver_agora() -> Dictionary:
	var pontos := _pontos()
	var pivo: Node3D = jogador.get("camera_pivot")
	return resolver(jogador.get_world_3d().direct_space_state, pivo.global_position, pontos[0], pontos[1],
		float(jogador.get("_yaw")), float(jogador.get("_pitch")), float(jogador.call("distancia_da_vista")),
		_excluidos(), Callable(self, "_braco_no_giro"))


## A câmera de agora (a que se vê) esconde o viajante?
func encoberto_agora() -> bool:
	if not _aplicavel():
		return false
	var pontos := _pontos()
	var camera: Camera3D = jogador.get("camera")
	return encoberto_de(jogador.get_world_3d().direct_space_state, camera.global_position, pontos[0], pontos[1], _excluidos())


func _encurtar_a(distancia: float) -> void:
	var atual := float(jogador.get("_distance"))
	if distancia < atual - 0.01:
		if is_nan(_distancia_original):
			_distancia_original = atual
		jogador.set("_distance", distancia)


## Reposiciona a câmera NA HORA, sem suavizar, para a captura do relatório sair com o
## viajante à vista. Devolve se mexeu.
func liberar_ja() -> bool:
	if not _aplicavel():
		return false
	var pose := _resolver_agora()
	if not bool(pose["encoberto"]):
		return false
	jogador.set("_yaw", float(pose["yaw"]))
	_alvo_yaw = NAN
	_encurtar_a(float(pose["distancia"]))
	jogador.call("_apply_camera")
	jogador.call("_encaixar_a_camera")
	return true


func _process(delta: float) -> void:
	if not _aplicavel():
		encoberto_s = 0.0
		return
	var encoberto := encoberto_agora()
	if encoberto:
		encoberto_s += delta
		_livre_s = 0.0
	else:
		encoberto_s = 0.0
		_anunciado = false
		_livre_s += delta
	_sonda_s -= delta
	if encoberto and encoberto_s >= CONFIRMA_S and _sonda_s <= 0.0:
		_sonda_s = SONDA_A_CADA_S
		var pose := _resolver_agora()
		if bool(pose["livre"]):
			_alvo_yaw = float(pose["yaw"]) if not is_equal_approx(float(pose["yaw"]), float(jogador.get("_yaw"))) else NAN
		_encurtar_a(float(pose["distancia"]))
	_girar_suave(delta)
	_devolver_a_distancia(delta)
	if encoberto_s >= ENCOBERTO_DEMAIS_S and not _anunciado:
		_anunciado = true
		encoberto_demais.emit(encoberto_s)


## Leva o giro da câmera ao lado livre, no ritmo máximo, sem tremer.
func _girar_suave(delta: float) -> void:
	if is_nan(_alvo_yaw):
		return
	var yaw := float(jogador.get("_yaw"))
	var diferenca := _alvo_yaw - yaw
	if absf(diferenca) < 0.02:
		_alvo_yaw = NAN
		return
	var passo := clampf(diferenca * (1.0 - exp(-8.0 * delta)), -GIRO_MAXIMO_POR_S * delta, GIRO_MAXIMO_POR_S * delta)
	jogador.set("_yaw", yaw + passo)


## Livre por um tempo, a câmera volta à distância que tinha, desde que a volta não a
## devolva atrás do obstáculo.
func _devolver_a_distancia(delta: float) -> void:
	if is_nan(_distancia_original) or _livre_s < LIVRE_ANTES_DE_VOLTAR_S:
		return
	var atual := float(jogador.get("_distance"))
	var tentativa := minf(atual + VOLTA_DA_DISTANCIA_POR_S * delta, _distancia_original)
	var pontos := _pontos()
	var pivo: Node3D = jogador.get("camera_pivot")
	var camera := posicao_da_camera(pivo.global_position, float(jogador.get("_yaw")), float(jogador.get("_pitch")), tentativa)
	if encoberto_de(jogador.get_world_3d().direct_space_state, camera, pontos[0], pontos[1], _excluidos()):
		_livre_s = 0.0
		return
	jogador.set("_distance", tentativa)
	if tentativa >= _distancia_original:
		_distancia_original = NAN
