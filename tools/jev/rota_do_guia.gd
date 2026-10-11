extends RefCounted
## Aproximação do guia continua pela malha, mesmo quando ele está perto.
## Uma reta de 14 m cortava a cabeceira e derrubava o jogador junto à ponte.

static func rumo(origem: Vector3, destino: Vector3, caminho: PackedVector3Array, reta_apoiada: bool = false) -> Vector3:
	if reta_apoiada:
		return destino
	if caminho.is_empty():
		return destino if origem.distance_to(destino) <= 3.0 else Vector3.INF
	for ponto in caminho:
		if Vector2(ponto.x - origem.x, ponto.z - origem.z).length() >= 0.35:
			return ponto
	return caminho[-1]

## A malha pode terminar antes do píer. A aproximação direta só é segura
## quando há chão sob cada meio metro da reta, na altura interpolada dos pés.
static func reta_apoiada(espaco: PhysicsDirectSpaceState3D, origem: Vector3, destino: Vector3, excluir: Array) -> bool:
	var rids: Array[RID] = []
	for rid in excluir:
		rids.append(rid)
	var passos := maxi(1, ceili(origem.distance_to(destino) / 0.4))
	for i in range(passos + 1):
		var ponto := origem.lerp(destino, float(i) / passos)
		var consulta := PhysicsRayQueryParameters3D.create(ponto + Vector3.UP * 0.45, ponto + Vector3.DOWN * 0.6, 1)
		consulta.exclude = rids
		if espaco.intersect_ray(consulta).is_empty():
			return false
	return true


## DESVIA DO QUE ESTÁ NA FRENTE (10/10/2026: "muitas vezes ele bate na árvore e então fica perdido"):
## a malha de navegação não leva os troncos da mata, e a rota passava por dentro deles. Um raio à
## altura do peito, de `alcance` metros no rumo pedido; se bate em algo, testa ângulos para os
## dois lados (o menor giro primeiro) e devolve o primeiro rumo livre. Sem lado livre, o pedido.
static func desviar(espaco: PhysicsDirectSpaceState3D, origem: Vector3, rumo: Vector3, excluir: Array, alcance: float = 1.6) -> Vector3:
	var para := Vector3(rumo.x - origem.x, 0.0, rumo.z - origem.z)
	if para.length() < 0.05:
		return rumo
	var direcao := para.normalized()
	var rids: Array[RID] = []
	for rid in excluir:
		rids.append(rid)
	var distancia := minf(alcance, para.length())
	for graus in [0, 25, -25, 45, -45, 65, -65, 90, -90]:
		var lado := direcao.rotated(Vector3.UP, deg_to_rad(float(graus)))
		var livre := true
		for altura in [0.5, 1.1]:
			var de: Vector3 = origem + Vector3.UP * float(altura)
			var consulta := PhysicsRayQueryParameters3D.create(de, de + lado * distancia, 1)
			consulta.exclude = rids
			if not espaco.intersect_ray(consulta).is_empty():
				livre = false
				break
		if livre:
			return rumo if graus == 0 else origem + lado * maxf(distancia, 1.0)
	return rumo
