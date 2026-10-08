extends RefCounted
## A CASCA DE UMA CONSTRUÇÃO COMO O OLHO A VÊ, para conferir a colisão contra ela (#205).
## Sem `class_name`: carrega-se com `preload`.
##
## "O viajante aparece entrando na parede": a colisão das casas não batia com a parede visível.
## Duas perguntas, e as duas moram aqui para o portão (`tests/colisao_das_casas.gd`) e o testador
## automático (`tools/jev/sessao.gd`) fazerem a mesma:
##
##   1. ONDE A COLISÃO ESTÁ CONTRA A MALHA: `corpo_da_casca` põe a malha do modelo numa camada só
##      dela (`Camadas.AUDITORIA`, trimesh com as duas faces), e `fundura_da_colisao` diz, num raio
##      vindo de fora, quanto a primeira face de colisão da construção está DENTRO da face visível
##      (positivo) ou fora dela (negativo).
##   2. O CENTRO DO CORPO DENTRO DA MALHA: `dentro_da_malha` conta quantas faces os raios horizontais
##      cruzam. Um volume fechado dá número ímpar em todo raio; debaixo de um beiral, de um alpendre
##      ou numa fresta, só alguns. Só reprova quem é ímpar nos quatro.

const Camadas = preload("res://scripts/prototipo_3d/camadas.gd")

## Quantas faces um raio atravessa, no máximo, antes de desistir.
const CRUZAMENTOS_MAXIMOS := 12
const DIRECOES := [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]


## Põe a malha do `modelo` no mundo, numa colisão provisória da camada `Camadas.AUDITORIA`, e a
## devolve. Quem a cria a libera (`queue_free`). A consulta só vale dois quadros de física depois.
static func corpo_da_casca(pai: Node, modelo: Node3D) -> StaticBody3D:
	var corpo := StaticBody3D.new()
	corpo.name = "CascaDaAuditoria"
	corpo.collision_layer = Camadas.AUDITORIA
	corpo.collision_mask = 0
	pai.add_child(corpo)
	for no in modelo.find_children("*", "MeshInstance3D", true, false):
		var malha := no as MeshInstance3D
		if malha.mesh == null or not malha.is_visible_in_tree():
			continue
		var forma := malha.mesh.create_trimesh_shape()
		if forma == null:
			continue
		forma.backface_collision = true
		var colisao := CollisionShape3D.new()
		colisao.shape = forma
		corpo.add_child(colisao)
		colisao.global_transform = malha.global_transform
	return corpo


## A primeira face da casca (a visível, de fora) num raio de `de` a `para`, ou `Vector3.INF`.
static func face_visivel(espaco: PhysicsDirectSpaceState3D, de: Vector3, para: Vector3) -> Vector3:
	var pergunta := PhysicsRayQueryParameters3D.create(de, para, Camadas.AUDITORIA)
	pergunta.hit_back_faces = true
	return espaco.intersect_ray(pergunta).get("position", Vector3.INF)


## QUANTO A COLISÃO ESTÁ DENTRO DA PAREDE VISÍVEL, num raio que chega à `face` visível em
## direção a `para_dentro` (unitário): de 1,5 m antes da face visível, o raio segue 2 m adiante
## contra o mundo (camada `MUNDO`), e a primeira colisão que for do `dono` (o cômodo da
## construção) diz a fundura. Positivo: o corpo que encosta nela já está dentro do reboco.
## Negativo: há parede de ar. INF se a construção não tem colisão ali (o raio passa por
## ela inteira).
static func fundura_da_colisao(espaco: PhysicsDirectSpaceState3D, face: Vector3, para_dentro: Vector3, dono: Node) -> float:
	var comeco := face - para_dentro * 1.5
	var pergunta := PhysicsRayQueryParameters3D.create(comeco, face + para_dentro * 2.0, Camadas.MUNDO)
	var ignorados: Array[RID] = []
	var achou := espaco.intersect_ray(pergunta)
	while not achou.is_empty():
		var colisor = achou.get("collider")
		if colisor is Node and dono.is_ancestor_of(colisor):
			return ((achou["position"] as Vector3) - comeco).length() - 1.5
		# Outra coisa (cerca, árvore, outra casa) no caminho: segue além dela.
		ignorados.append(achou["rid"])
		pergunta.exclude = ignorados
		achou = espaco.intersect_ray(pergunta)
	return INF


## O PONTO ESTÁ DENTRO DE UM VOLUME DA MALHA? Raios horizontais nas quatro direções, contados
## contra a camada `AUDITORIA`: ímpar nos quatro é dentro.
static func dentro_da_malha(espaco: PhysicsDirectSpaceState3D, ponto: Vector3) -> bool:
	for direcao: Vector3 in DIRECOES:
		if cruzamentos(espaco, ponto, direcao) % 2 == 0:
			return false
	return true


## Quantas faces da casca o raio de `ponto` na `direcao` atravessa.
static func cruzamentos(espaco: PhysicsDirectSpaceState3D, ponto: Vector3, direcao: Vector3) -> int:
	var conta := 0
	var de := ponto
	var ate := ponto + direcao * 60.0
	for i in CRUZAMENTOS_MAXIMOS:
		var pergunta := PhysicsRayQueryParameters3D.create(de, ate, Camadas.AUDITORIA)
		pergunta.hit_back_faces = true
		var achou := espaco.intersect_ray(pergunta)
		if achou.is_empty():
			break
		conta += 1
		de = (achou["position"] as Vector3) + direcao * 0.002
	return conta
