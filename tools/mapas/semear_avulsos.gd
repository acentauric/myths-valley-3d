extends SceneTree
## SEMENTE DOS AVULSOS E REFERÊNCIA DA PRAIA PARA O EDITOR.
##
##     Godot --headless --path . --script res://tools/mapas/semear_avulsos.gd
##
## Monta o vale de verdade (casas da composição, avulsos nas posições do código) e
## grava:
##   data/composicao/avulsos_padrao.json   onde cada objeto avulso ficou (inclusive
##       pontes, coqueiros da orla e manguezal); o editor cria com ela os subgrupos
##       de "Avulsos" da composicao_vale.tscn que ainda não existem (depois a cena é
##       a fonte; apagar um subgrupo inteiro o recria daqui);
##   scenes/prototipo_3d/paisagem_referencia.tscn   mar, orla, rios, foz e áreas,
##       que o editor mostra junto do terreno e das ruas (e as pontes, na semente).
## Rode de novo quando o código mudar a posição padrão de um avulso ou a costa.

const SEMENTE := "res://data/composicao/avulsos_padrao.json"
const PRAIA := "res://scenes/prototipo_3d/paisagem_referencia.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.get_node("Estilo").modo = "tripo"
	var construtor := load("res://scripts/prototipo_3d/world_builder.gd") as Script
	var mundo := construtor.new() as Node3D
	mundo.ignorar_avulsos = true
	root.add_child(mundo)
	if not mundo.construido:
		await mundo.pronto

	var lista: Array = []
	for id in mundo.avulsos_montados:
		var item: Dictionary = mundo.avulsos_montados[id]
		var pos: Vector3 = item["pos"]
		lista.append({
			"id": id, "tipo": item["tipo"], "chave": item["chave"], "grupo": item["grupo"],
			"pos": [snappedf(pos.x, 0.001), snappedf(pos.y, 0.001), snappedf(pos.z, 0.001)],
			"giro": snappedf(float(item["yaw"]), 0.0001), "tamanho": float(item["tamanho"]),
			"no_chao": bool(item["no_chao"]),
		})
	var arquivo := FileAccess.open(SEMENTE, FileAccess.WRITE)
	if arquivo == null:
		push_error("Não foi possível gravar " + SEMENTE)
		quit(1)
		return
	# COQUEIROS DA ORLA E MANGUEZAL: plantados pela região em lote; viram avulsos
	# editáveis um a um (a região planta os do autor quando o grupo existe).
	var contagem := {}
	for tronco in mundo._region._tree_trunks:
		if not tronco.has("visual") or not is_instance_valid(tronco["visual"]) or not tronco.has("giro"):
			continue
		var visual_nome := String((tronco["visual"] as Node).name)
		var grupo := "Coqueiros da orla" if visual_nome.begins_with("Coqueiros da orla") else ("Manguezal" if visual_nome.begins_with("Manguezal") else "")
		if grupo.is_empty():
			continue
		contagem[grupo] = int(contagem.get(grupo, 0)) + 1
		var p: Vector2 = tronco["point"]
		lista.append({
			"id": ("Coqueiro da orla %d" if grupo == "Coqueiros da orla" else "Mangue %d") % contagem[grupo],
			"tipo": "arvore", "chave": String(tronco["especie"]), "grupo": grupo,
			"pos": [snappedf(p.x, 0.001), snappedf(float(tronco["ground"]), 0.001), snappedf(p.y, 0.001)],
			"giro": snappedf(float(tronco["giro"]), 0.0001), "tamanho": snappedf(float(tronco["escala"]), 0.001), "no_chao": true,
		})
	# REFERÊNCIAS: modelos que seguem rua e rio (as pontes); o editor os mostra travados.
	var referencias: Array = []
	for ref in mundo.referencias_montadas:
		var tr: Transform3D = ref["transform"]
		var m := tr.basis
		var doze: Array = []
		for n in [m.x.x, m.x.y, m.x.z, m.y.x, m.y.y, m.y.z, m.z.x, m.z.y, m.z.z, tr.origin.x, tr.origin.y, tr.origin.z]:
			doze.append(snappedf(float(n), 0.0001))
		referencias.append({"chave": ref["chave"], "nome": ref["nome"], "transform": doze})
	arquivo.store_string(JSON.stringify({"versao": 2, "avulsos": lista, "referencias": referencias}, "\t") + "\n")
	arquivo.close()

	# A PAISAGEM: tudo o que a região desenha em malha, menos o que já tem
	# referência própria (terra, ruas) e a mata, que fica para quando ela for
	# editável. Entram mar, fundo, orla, rios e suas areias, foz, as áreas (praça,
	# fazenda...). Coqueiros e manguezal da orla vão na semente (ver vegetação).
	var praia := Node3D.new()
	praia.name = "Paisagem"
	var ruas := {}
	for rua in mundo._region._roads:
		ruas[String(rua.name)] = true
	for filho in mundo._region.get_children():
		var nome := String(filho.name)
		if not filho is MeshInstance3D or nome == "Terra" or ruas.has(nome) or nome.begins_with("Transição ") or nome.begins_with("Cruzamento"):
			continue
		filho.reparent(praia, false)
		filho.owner = praia
	var pacote := PackedScene.new()
	if praia.get_child_count() == 0 or pacote.pack(praia) != OK or ResourceSaver.save(pacote, PRAIA) != OK:
		push_error("Falhou ao guardar a referência da praia.")
		quit(1)
		return
	print("AVULSOS_SEMEADOS: %d avulsos em %s; %d malhas de paisagem em %s" % [lista.size(), SEMENTE, praia.get_child_count(), PRAIA])
	praia.free()
	mundo.queue_free()
	await process_frame
	quit()
