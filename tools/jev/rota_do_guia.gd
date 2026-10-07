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
