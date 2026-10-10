extends SceneTree
## Primeira extração, sem sobrescrever autoria existente. Usa o próprio mundo real.

const SAIDA := "res://scenes/prototipo_3d/composicao_vale.tscn"
const RUAS := "res://scenes/prototipo_3d/ruas_referencia.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAIDA):
		push_error("A composição já existe. Edite a cena; a extração não sobrescreve autoria.")
		quit(1)
		return
	var construtor := load("res://scripts/prototipo_3d/world_builder.gd") as Script
	var mundo := construtor.new() as Node3D
	mundo.ignorar_composicao = true
	root.add_child(mundo)
	if not mundo.construido:
		await mundo.pronto
	var cena := Node3D.new()
	cena.name = "ComposicaoDoVale"
	cena.set_script(load("res://scripts/prototipo_3d/composicao_editor.gd"))
	cena.editor_description = "Edite Casas: posição e giro Y. Ctrl+S salva a composição usada pelo jogo. Ruas e terreno são referências geográficas."
	var ruas := Node3D.new()
	ruas.name = "Ruas"
	var nomes := PackedStringArray()
	for rua in mundo._region._roads:
		nomes.append(rua.name)
	for filho in mundo._region.get_children():
		if filho is MeshInstance3D and (String(filho.name) in nomes or String(filho.name).begins_with("Transição ") or String(filho.name).begins_with("Cruzamento")):
			filho.reparent(ruas, false)
			filho.owner = ruas
	var pacote_ruas := PackedScene.new()
	if pacote_ruas.pack(ruas) != OK or ResourceSaver.save(pacote_ruas, RUAS) != OK:
		push_error("Falhou ao guardar as referências das ruas.")
		quit(1)
		return
	ruas.free()
	var casas := Node3D.new()
	casas.name = "Casas"
	cena.add_child(casas)
	casas.owner = cena
	var script_casa := load("res://scripts/prototipo_3d/casa_composicao.gd") as Script
	for nome in mundo.construcoes_editaveis:
		var dados: Dictionary = mundo.construcoes_editaveis[nome]
		var casa := Node3D.new()
		casa.name = nome
		casa.set_script(script_casa)
		casa.identificador = nome
		casa.chave = dados["chave"]
		casa.position = dados["pos"]
		casa.rotation.y = dados["yaw"]
		casa.posicao_inicial = casa.position
		casa.posicao_lote_inicial = mundo._lotes[nome]["inicial"]
		casa.giro_inicial = casa.rotation.y
		casa.set_meta("_edit_group_", true)
		casas.add_child(casa)
		casa.owner = cena
	var pacote := PackedScene.new()
	if pacote.pack(cena) != OK or ResourceSaver.save(pacote, SAIDA) != OK:
		push_error("Falhou ao guardar a composição.")
		quit(1)
		return
	print("COMPOSICAO_EXTRAIDA: ", mundo.construcoes_editaveis.size(), " construções; ", nomes.size(), " ruas. ", SAIDA)
	cena.free()
	mundo.queue_free()
	await process_frame
	quit()
