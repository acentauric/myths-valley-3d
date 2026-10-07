extends Node3D
## A CABRA DE CENA: a cabra que passeia sem física, levada por quem monta a cena —
## a da lombada, que sobe e desce a rampa, e as três da festa da fazenda.
##
## ANTES ELA ESCORREGAVA. As duas usavam o GLB `aderecos/cabra_tripo.glb`, uma malha
## parada, sem esqueleto nem clipe, que um Tween levava de um ponto a outro: a cabra
## deslizava pelo chão como um móvel. Agora ela veste a cabra COM O RIG (`cabra_solta`,
## a mesma dos quintais) e o `Animador` põe o clipe de andar na velocidade do chão —
## a pata acompanha o passo, o corpo respira parado e olha de lado de tempos em
## tempos. Quem a leva só avisa quando começa e quando para (`andar`, `parar`).
##
## A origem do nó fica no CHÃO, sob a cabra, de frente para +Z: quem a leva continua
## lendo `global_position` e girando `rotation:y`, como fazia com o GLB parado.
##
## No procedural, a caixa cinza dos bichos (a mesma `Animador.vestir`): o clipe não
## existe, e o balanço do passo faz a leitura sem perna.

const Animador = preload("res://scripts/prototipo_3d/animador_bicho.gd")

## O modelo no catálogo, a largura que a cabra de cena sempre teve (1,3 u) contra a
## do catálogo (1,15), e a caixa e a cor do procedural.
const CHAVE := "cabra_solta"
const LARGURA := 1.3
const LARGURA_NO_CATALOGO := 1.15
const CAIXA := Vector3(0.3, 0.75, 0.95)
const COR := Color("e6dfd0")
## A passada de referência sem clipe (u/s); com clipe, é medida pelos pés.
const PASSADA := 0.8

var _pose: Node3D
var _animador


func _ready() -> void:
	_pose = Node3D.new()
	_pose.name = "Pose"
	add_child(_pose)
	var corpo := Animador.vestir(CHAVE, _pose, CAIXA, COR, 0.0, LARGURA / LARGURA_NO_CATALOGO)
	_animador = Animador.new()
	_animador.name = "Animador"
	add_child(_animador)
	_animador.configurar(_pose, corpo, false, CHAVE, PASSADA)


## Começa a andar a `passo` u/s: o clipe passa a tocar no ritmo do chão.
func andar(passo: float) -> void:
	if _animador != null:
		_animador.velocidade = passo


## Para: termina o passo e congela no quadro de pé.
func parar() -> void:
	if _animador != null:
		_animador.velocidade = 0.0


func andando() -> bool:
	return _animador != null and _animador.velocidade > _animador.PARADO_ABAIXO


## O animador, para o portão olhar o clipe.
func animador():
	return _animador


## Liga ou desliga uma cabra de cena que um Tween leva: `andar` ao ir, `parar` ao
## chegar. Aceita qualquer nó, e não faz nada com o que não é cabra de cena.
static func andar_se_for(quem, passo: float) -> void:
	if is_instance_valid(quem) and quem.has_method("andar"):
		quem.andar(passo)


static func parar_se_for(quem) -> void:
	if is_instance_valid(quem) and quem.has_method("parar"):
		quem.parar()
