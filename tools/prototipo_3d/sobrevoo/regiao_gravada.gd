extends "res://scripts/prototipo_3d/geo_region_renderer.gd"
## RENDERIZADOR DA REGIAO QUE GUARDA A TRANSFORMACAO DE CADA INSTANCIA DE MULTIMESH.
##
## Por que existe: no --headless o RenderingServer e o dummy, e ele nao guarda instancia
## de MultiMesh (get_instance_transform devolve a identidade). Lida do vale vivo, a
## mata inteira viraria milhares de arvores empilhadas na origem, no tamanho cru do
## GLB e abaixo do chao, e a grade sairia sem vegetacao nenhuma.
##
## A regiao planta tudo com sementes fixas a partir dos mesmos JSON; reconstruida aqui,
## da as mesmas transformacoes, que este override grava antes de passar adiante. O
## extrator confere contra o vale vivo (plantio de cada arvore em _tree_trunks, a
## transformacao dos coqueiros registrados e a contagem de instancias por bloco) e
## aborta se algo divergir.
##
## Carregue com load() DEPOIS de o vale subir: o pai pre-carrega mar.gd, que cita o
## autoload Mare pelo nome.

## [{"nome", "mesh", "transforms": Array[Transform3D]}], na ordem em que a regiao plantou.
var gravados: Array = []


func _multimesh_em_blocos(nome: String, mesh: Mesh, transforms: Array[Transform3D], distancia_lod: float = 0.0, registros: Array[int] = []) -> void:
	gravados.append({"nome": nome, "mesh": mesh, "transforms": transforms.duplicate()})
	super(nome, mesh, transforms, distancia_lod, registros)
