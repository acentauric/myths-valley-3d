extends "res://tests/suite/caso.gd"
## Mede a distância entre os lugares da primeira missão, para a ordem dela
## deixar de ser "indo e vindo".
##
##     .\tools\prototipo_3d\testar.ps1 -Teste ordem_da_visita
##
## Não é portão: é régua. Roda para responder uma pergunta — qual ordem faz o
## jogador andar menos — e imprime o percurso de cada uma.

## Régua, não portão: mede e imprime, não reprova. Fica fora da bateria e roda
## com `testar.ps1 -Longos` ou pelo nome.
const LONGO := true


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/prototipo_3d/vale.tscn")
	for i in 4:
		await process_frame
	for i in range(3000):
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame

	var lugares := root.get_node("/root/Lugares")
	var arquivo := FileAccess.open("res://data/missoes_guia.json", FileAccess.READ)
	var dado = JSON.parse_string(arquivo.get_as_text())
	arquivo.close()

	var passos: Array = []
	for passo: Dictionary in dado.get("passos", []):
		var lugar := str(passo.get("lugar", ""))
		var p: Vector3 = lugares.ponto(lugar)
		if p == lugares.NENHUM:
			continue
		passos.append({"id": str(passo.get("id", "")), "lugar": lugar, "pos": p})

	var jogador := get_first_node_in_group("map_player")
	var de: Vector3 = jogador.global_position if jogador != null else Vector3.ZERO
	print("\n=== DISTÂNCIAS DO PONTO DE PARTIDA (unidades; 1 u = 4 m) ===")
	for passo in passos:
		print("  %-14s %-16s %6.1f" % [passo["id"], passo["lugar"],
			_plano(de, passo["pos"])])

	print("\n=== MATRIZ ENTRE OS LUGARES ===")
	for a in passos:
		var linha := "  %-14s" % a["id"]
		for b in passos:
			linha += " %6.1f" % _plano(a["pos"], b["pos"])
		print(linha)

	print("\n=== PERCURSO DA ORDEM ATUAL ===")
	var total := _percurso(de, passos)
	print("  %s" % _nomes(passos))
	print("  total: %.1f u" % total)

	print("\n=== PERCURSO DO VIZINHO MAIS PERTO (guloso, a partir do jogador) ===")
	var guloso := _guloso(de, passos)
	print("  %s" % _nomes(guloso))
	print("  total: %.1f u" % _percurso(de, guloso))

	quit(0)


func _plano(a: Vector3, b: Vector3) -> float:
	var d := b - a
	d.y = 0.0
	return d.length()


func _percurso(de: Vector3, ordem: Array) -> float:
	var total := 0.0
	var atual := de
	for passo in ordem:
		total += _plano(atual, passo["pos"])
		atual = passo["pos"]
	return total


## O vizinho mais perto a cada passo. Não é o caminho ótimo — é o que o jogador
## faria se andasse sempre para o mais perto, e é o que evita a sensação de
## "indo e vindo".
func _guloso(de: Vector3, passos: Array) -> Array:
	var faltam := passos.duplicate()
	var ordem := []
	var atual := de
	while not faltam.is_empty():
		var melhor := 0
		var menor := INF
		for i in faltam.size():
			var d := _plano(atual, faltam[i]["pos"])
			if d < menor:
				menor = d
				melhor = i
		ordem.append(faltam[melhor])
		atual = faltam[melhor]["pos"]
		faltam.remove_at(melhor)
	return ordem


func _nomes(ordem: Array) -> String:
	var nomes := []
	for passo in ordem:
		nomes.append(str(passo["id"]))
	return " > ".join(nomes)
