@tool
extends Path3D
## UMA ZONA DO PAISAGISMO DO VALE: um contorno fechado (Path3D, só x e z contam) e
## a receita que o preenche — bananal, pomar de quintal, roça de mandioca, dendezal,
## mata ciliar... As receitas moram em `data/paisagismo/receitas.json`; a posição
## de cada pé sai de `PaisagismoVale.gerar`, que sorteia pela semente da zona. A
## cena `scenes/prototipo_3d/paisagismo_vale.tscn` é a fonte: mexer num ponto do
## contorno aqui replanta o vale no próximo jogo, sem mexer em código.

## Nome de uma receita de `receitas.json` ("bananal", "pomar_quintal", ...).
@export var receita := ""
## A semente da zona: a mesma semente planta o mesmo pomar, sempre.
@export var semente := 1887
## Fator sobre o espaçamento da receita: 1 é o da receita, 2 afasta os pés o dobro
## (um quarto deles), 0,5 os aperta.
@export_range(0.25, 4.0, 0.05) var densidade := 1.0
## O rumo das fileiras e das quadras, em graus (a roça segue a encosta, não o norte).
@export_range(-180.0, 180.0, 1.0) var rumo_graus := 0.0
## Desligada, a zona fica na cena mas não planta nada.
@export var ativa := true


## O contorno da zona no mundo, em unidades (x, z), sem repetir o primeiro ponto.
func poligono() -> PackedVector2Array:
	var pontos := PackedVector2Array()
	if curve == null:
		return pontos
	var transformacao := transform
	var pai := get_parent() as Node3D
	while pai != null:
		transformacao = pai.transform * transformacao
		pai = pai.get_parent() as Node3D
	for i in curve.point_count:
		var no_mundo := transformacao * curve.get_point_position(i)
		pontos.append(Vector2(no_mundo.x, no_mundo.z))
	if pontos.size() > 1 and pontos[0].is_equal_approx(pontos[pontos.size() - 1]):
		pontos.remove_at(pontos.size() - 1)
	return pontos
