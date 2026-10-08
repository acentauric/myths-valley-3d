extends SceneTree
## #201: a câmera da sessão de teste não deixa o viajante escondido atrás de um poste.
## Monta um mundo mínimo (poste, parede, morador) e confere a geometria de
## `camera_do_teste.gd`: sem obstáculo não mexe; atrás do poste gira para o lado livre;
## morador não conta; sem lado livre, aproxima.
const CameraDoTeste = preload("res://tools/jev/camera_do_teste.gd")
const Camadas = preload("res://scripts/prototipo_3d/camadas.gd")

var falhas := 0


func _initialize() -> void:
	_conferir.call_deferred()


func _corpo(posicao: Vector3, tamanho: Vector3, camada: int, personagem: bool = false) -> void:
	var corpo: PhysicsBody3D = CharacterBody3D.new() if personagem else StaticBody3D.new()
	corpo.collision_layer = camada
	corpo.position = posicao
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = tamanho
	forma.shape = caixa
	corpo.add_child(forma)
	root.add_child(corpo)


func _confere(condicao: bool, mensagem: String) -> void:
	if not condicao:
		push_error(mensagem)
		falhas += 1


func _conferir() -> void:
	var pivo := Vector3(0.0, 1.18, 0.0)
	var peito := Vector3(0.0, 1.1, 0.0)
	var cabeca := Vector3(0.0, 1.65, 0.0)
	var distancia := 8.0
	var livre := func(_giro: float) -> float: return distancia
	var fora: Array[RID] = []

	# O poste no meio do caminho: um mourão a quatro metros do viajante, em linha com a câmera.
	_corpo(Vector3(0.0, 1.5, 4.0), Vector3(0.4, 3.0, 0.4), Camadas.MUNDO)
	await physics_frame
	await physics_frame
	var espaco := root.get_world_3d().direct_space_state

	var camera := CameraDoTeste.posicao_da_camera(pivo, 0.0, 0.0, distancia)
	_confere(CameraDoTeste.encoberto_de(espaco, camera, peito, cabeca, fora), "Atras do poste o viajante esta encoberto")

	var pose := CameraDoTeste.resolver(espaco, pivo, peito, cabeca, 0.0, 0.0, distancia, fora, livre)
	_confere(bool(pose["encoberto"]) and bool(pose["livre"]), "Encoberto, a camera acha um lado livre")
	_confere(absf(float(pose["yaw"])) > 0.1 and absf(float(pose["yaw"])) < 1.2, "O giro e o menor que liberta (veio %s)" % [pose["yaw"]])
	_confere(is_equal_approx(float(pose["distancia"]), distancia), "Girando, a distancia e a mesma")
	var nova := CameraDoTeste.posicao_da_camera(pivo, float(pose["yaw"]), 0.0, float(pose["distancia"]))
	_confere(not CameraDoTeste.encoberto_de(espaco, nova, peito, cabeca, fora), "Na pose nova o viajante aparece")

	# De lado, sem nada no meio, a camera nao mexe.
	var livre_de_poste := CameraDoTeste.resolver(espaco, pivo, peito, cabeca, PI * 0.5, 0.0, distancia, fora, livre)
	_confere(not bool(livre_de_poste["encoberto"]) and is_equal_approx(float(livre_de_poste["yaw"]), PI * 0.5), "Sem obstaculo a pose fica como esta")

	# Um morador na frente nao esconde ninguem: o raio o atravessa.
	_corpo(Vector3(4.0, 1.0, 0.0), Vector3(0.8, 2.0, 0.8), Camadas.MUNDO, true)
	await physics_frame
	await physics_frame
	espaco = root.get_world_3d().direct_space_state
	var camera_leste := CameraDoTeste.posicao_da_camera(pivo, PI * 0.5, 0.0, distancia)
	_confere(not CameraDoTeste.encoberto_de(espaco, camera_leste, peito, cabeca, fora), "Morador e bicho nao contam como obstaculo")

	# Sem lado livre (o braco do jogador nao cabe em giro nenhum), aproxima ate a frente do poste.
	var sem_lado := func(_giro: float) -> float: return 0.5
	var perto := CameraDoTeste.resolver(espaco, pivo, peito, cabeca, 0.0, 0.0, distancia, fora, sem_lado)
	_confere(bool(perto["encoberto"]) and float(perto["distancia"]) < 4.0 and float(perto["distancia"]) >= CameraDoTeste.DISTANCIA_MINIMA,
		"Sem lado livre a camera aproxima, sem entrar no corpo (veio %s)" % [perto["distancia"]])
	_confere(bool(perto["livre"]), "Aproximada, o viajante aparece")

	# Parede inteira atras: nem giro nem aproximacao sao possiveis ate o minimo, e a pose volta como "nao livre" so se ainda encobre.
	_corpo(Vector3(0.0, 1.5, 1.8), Vector3(6.0, 3.0, 0.4), Camadas.MUNDO)
	await physics_frame
	await physics_frame
	espaco = root.get_world_3d().direct_space_state
	var encurralado := CameraDoTeste.resolver(espaco, pivo, peito, cabeca, 0.0, 0.0, distancia, fora, sem_lado)
	_confere(float(encurralado["distancia"]) >= CameraDoTeste.DISTANCIA_MINIMA, "Nunca dentro do viajante: o braco nao passa do minimo")

	print("AUTOPLAYER_CAMERA: %d falha(s)" % falhas)
	quit(1 if falhas else 0)
