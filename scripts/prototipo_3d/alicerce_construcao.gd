class_name AlicerceConstrucao
extends RefCounted
## Alicerce (e escadaria da igreja) calculado pelo relevo sob a construção.
## Fonte única: o jogo (world_builder) e a prévia do editor (casa_composicao) usam
## estas funções com a mesma função de altura do terreno.

const COR_ALICERCE_IGREJA := Color("9c927e")
const COR_ALICERCE_CASA := Color("958d79")
const COR_PEDRA := Color("b7aa90")

## Ajustes autorais aceitos (editáveis no Inspector de cada construção):
##   visivel (bool), margem (float, < 0 = padrão), escadaria (bool, só igreja).
static func padrao() -> Dictionary:
	return {"visivel": true, "margem": -1.0, "escadaria": true}


static func faixa_terreno(altura: Callable, posicao: Vector3, footprint: Vector2, yaw: float) -> Vector2:
	var menor := INF
	var maior := -INF
	for ix in range(5):
		for iz in range(5):
			var local := Vector2((float(ix) / 4.0 - 0.5) * footprint.x, (float(iz) / 4.0 - 0.5) * footprint.y).rotated(-yaw)
			var amostra: float = altura.call(Vector3(posicao.x + local.x, 0.0, posicao.z + local.y))
			if not is_finite(amostra):
				continue
			menor = minf(menor, amostra)
			maior = maxf(maior, amostra)
	return Vector2(menor, maior)


static func margem(igreja: bool, ajustes: Dictionary) -> float:
	var valor := float(ajustes.get("margem", -1.0))
	return valor if valor >= 0.0 else (0.36 if igreja else 0.16)


## Caixas do alicerce para uma construção já assentada em `posicao` (y = piso da casa).
## Cada item: {"size": Vector3, "center": Vector3, "cor": Color, "tipo": "alicerce"|"borda"|"degrau"}.
static func caixas(altura: Callable, posicao: Vector3, footprint: Vector2, yaw: float, igreja: bool, ajustes: Dictionary = {}) -> Array:
	var resultado: Array = []
	if not bool(ajustes.get("visivel", true)):
		return resultado
	var base_margin := margem(igreja, ajustes)
	var faixa := faixa_terreno(altura, posicao, footprint + Vector2.ONE * base_margin, yaw)
	if not is_finite(faixa.x):
		return resultado
	var top := posicao.y + (0.12 if igreja else 0.04)
	var bottom := minf(faixa.x - (0.24 if igreja else 0.06), top - 0.08)
	var tamanho := Vector3(footprint.x + base_margin, top - bottom, footprint.y + base_margin)
	resultado.append({"size": tamanho, "center": Vector3(posicao.x, (top + bottom) * 0.5, posicao.z), "cor": COR_ALICERCE_IGREJA if igreja else COR_ALICERCE_CASA, "tipo": "alicerce"})
	if igreja:
		# Uma borda de pedra cobre a junta com o modelo e marca o nível de entrada.
		resultado.append({"size": Vector3(tamanho.x + 0.12, 0.12, tamanho.z + 0.12), "center": Vector3(posicao.x, top - 0.06, posicao.z), "cor": COR_PEDRA, "tipo": "borda"})
		if bool(ajustes.get("escadaria", true)):
			resultado.append_array(_escadaria(altura, posicao, footprint, yaw, top))
	return resultado


static func _escadaria(altura: Callable, origem: Vector3, footprint: Vector2, yaw: float, base_top: float) -> Array:
	# A torre e a porta do GLB da igreja ficam no lado -Z do modelo.
	var front_edge := -footprint.y * 0.5 - 0.18
	var landing_depth := 0.78
	var tread_depth := 0.48
	var stair_width := minf(2.8, footprint.x * 0.48)
	var step_count := 1
	for _tentativa in range(8):
		var outer_z := front_edge - landing_depth - float(step_count) * tread_depth
		var outer_world := origem + Vector3(0, 0, outer_z).rotated(Vector3.UP, yaw)
		var rise := maxf(base_top - float(altura.call(outer_world)) - 0.08, 0.0)
		step_count = maxi(step_count, ceili(rise / 0.23))
	var last_z := front_edge - landing_depth - float(step_count) * tread_depth
	var last_world := origem + Vector3(0, 0, last_z).rotated(Vector3.UP, yaw)
	var step_height := maxf(maxf(base_top - float(altura.call(last_world)) - 0.08, 0.0) / float(step_count), 0.14)
	var degraus: Array = []
	# O patamar se sobrepõe um pouco ao alicerce para não abrir uma fenda.
	degraus.append(_degrau(altura, origem, yaw, front_edge - landing_depth * 0.5 + 0.04, stair_width + 0.22, landing_depth + 0.08, base_top))
	for indice in range(step_count):
		var local_z := front_edge - landing_depth - (float(indice) + 0.5) * tread_depth
		degraus.append(_degrau(altura, origem, yaw, local_z, stair_width, tread_depth + 0.06, base_top - float(indice + 1) * step_height))
	return degraus


static func _degrau(altura: Callable, origem: Vector3, yaw: float, local_z: float, largura: float, profundidade: float, top: float) -> Dictionary:
	var centro := origem + Vector3(0, 0, local_z).rotated(Vector3.UP, yaw)
	var terreno := faixa_terreno(altura, centro, Vector2(largura, profundidade), yaw)
	var bottom := minf(terreno.x - 0.12, top - 0.16)
	return {"size": Vector3(largura, top - bottom, profundidade), "center": Vector3(centro.x, (top + bottom) * 0.5, centro.z), "cor": COR_PEDRA, "tipo": "degrau"}
