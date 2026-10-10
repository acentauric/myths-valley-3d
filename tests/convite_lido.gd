extends "res://tests/suite/caso.gd"
## O CONVITE LIDO FECHA A CHEGADA (10/10/2026: "está travando após ler a carta"): no último passo
## da chegada ("Leia o convite que chegou"), ler o convite pela mochila (F) ou pela mão (E) avisa
## "leu:convite", e o passo fecha.

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA: ", rotulo)


func _run() -> void:
	change_scene_to_file("res://scenes/prototipo_3d/vale.tscn")
	for i in 3000:
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	for i in 3:
		await process_frame
	var vale := current_scene
	var guia = vale.get("pedro")
	var cadeia = guia._cadeia
	var indice := -1
	for i in cadeia.passos.size():
		if str(cadeia.passos[i].get("id", "")) == "convite":
			indice = i
	_conferir(indice >= 0, "a chegada tem o passo do convite")
	cadeia.iniciado = true
	cadeia.missao = indice
	cadeia.espera = 0.0
	var inv := root.get_node("/root/Inventario")
	if not inv.tem("convite"):
		inv.adicionar("convite", 1)
	for i in 5:
		await process_frame
	_conferir(cadeia.missao == indice, "o passo do convite não ficou aberto (missao %d)" % cadeia.missao)
	var dialogo := root.get_node("/root/Dialogo")
	vale._ler_documento("convite")
	await process_frame
	# O aviso vai na hora, sem esperar a caixa do papel fechar (ela pode demorar a ter a vez).
	_conferir(cadeia.aconteceu("leu:convite"), "o aviso 'leu:convite' esperou a caixa do papel fechar")
	var abriu := false
	for i in 600:
		await process_frame
		if dialogo.ativo:
			abriu = true
			dialogo.calar()
		elif abriu or cadeia.aconteceu("leu:convite"):
			break
	print("CONVITE: abriu=%s narracao_segura=%s" % [str(abriu), str(dialogo._narracao_na_tela())])
	for i in 20:
		await process_frame
	print("CONVITE: missao=%d indice=%d aconteceu=%s falta=%s ativo=%s" % [cadeia.missao, indice, str(cadeia.aconteceu("leu:convite")), str(cadeia.falta_a_meta(cadeia.passos[indice])), str(dialogo.ativo)])
	_conferir(cadeia.aconteceu("leu:convite"), "ler o convite não avisou 'leu:convite'")
	_conferir(cadeia.missao != indice or cadeia.acabou(), "lido o convite, o passo não fechou")
	print("CONVITE_LIDO_OK" if falhas == 0 else "convite_lido: Falhas: %d" % falhas)
	quit(1 if falhas else 0)
