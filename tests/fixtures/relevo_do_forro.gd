extends Node3D
var declive := Vector2.ZERO
func ground_height_at(ponto: Vector3) -> float:
	return ponto.x * declive.x + ponto.z * declive.y
