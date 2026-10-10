extends "res://tests/unidade/base.gd"
## O limite segue os cantos e cada lance tem o comprimento da sua borda (#142).
##
##     .\tools\prototipo_3d\testar.ps1 -Teste contorno_das_cercas
const Paisagismo := preload("res://scripts/prototipo_3d/paisagismo_vale.gd")

func test_contorno_das_cercas() -> void:
	var poligono := PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 7), Vector2(0, 7)])
	var amostras := Paisagismo._amostras_do_perimetro(poligono, 3.0)
	if "--cortar-canto" in OS.get_cmdline_user_args():
		amostras.remove_at(amostras.find(Vector2(10, 0)))
	for canto in poligono:
		conferir(amostras.has(canto), "o limite conserva o canto %s" % canto)
	for i in amostras.size():
		var a := amostras[i]
		var b := amostras[(i + 1) % amostras.size()]
		conferir(is_equal_approx(a.x, b.x) or is_equal_approx(a.y, b.y), "um lance corta a esquina")
		conferir(a.distance_to(b) <= 3.01, "um lance excede seu espaçamento")
	var receitas := {"aderecos": {"cerca": {"chave": "cerca_varas", "receitas": ["roca"], "passo": 3.0},
		"porteira": {"alcance_da_rua": 8.0}}, "reservas": {"rua": 0.0}}
	var zona := {"nome": "Roça", "receita": "roca", "poligono": poligono}
	var reservas := {"rua": func(p: Vector2) -> float: return p.y + 5.0}
	# O cercado sai dos lances de canto a canto (`_lances_do_cercado`): só o lance
	# da entrada fica sem vara.
	var lances := Paisagismo._lances_do_cercado(poligono, 3.0, 1.6, 0.9)
	for lance in lances:
		conferir(is_equal_approx(lance.de.x, lance.ate.x) or is_equal_approx(lance.de.y, lance.ate.y), "um lance do cercado corta a esquina")
	var itens := _cercas(Paisagismo.aderecos(null, [zona], receitas, reservas))
	conferir(itens.size() == lances.size() - 1, "há uma abertura e o resto forma o limite")
	for item in itens:
		var de: Vector2 = item.get("de", Vector2.INF)
		var ate: Vector2 = item.get("ate", Vector2.INF)
		conferir(de.is_finite() and ate.is_finite(), "o lance conserva suas duas extremidades")
		conferir((de + ate).distance_to(item.ponto * 2.0) < 0.001, "o centro coincide com as extremidades")
	# Duas reservas nas laterais deixam uma peça central sem função: ela sai.
	reservas.rua = func(p: Vector2) -> float:
		return 0.0 if p.y < 0.1 and (p.x < 4.0 or p.x > 6.0) else 100.0
	itens = _cercas(Paisagismo.aderecos(null, [zona], receitas, reservas))
	for item in itens:
		var vizinhos := 0
		for outro in itens:
			if outro != item and (item.de.is_equal_approx(outro.ate) or item.ate.is_equal_approx(outro.de)):
				vizinhos += 1
		conferir(vizinhos > 0, "não sobra uma peça isolada entre reservas")

func _cercas(itens: Array) -> Array:
	return itens.filter(func(item: Dictionary) -> bool: return item.chave == "cerca_varas")
