extends SceneTree
## Persiste somente a terra da região ativa numa cena que o editor consegue mostrar.
## A malha nasce do próprio GeoRegionRenderer; este arquivo não replica projeção,
## relevo ou triangulação.

const RENDERIZADOR := "res://scripts/prototipo_3d/geo_region_renderer.gd"
const CATALOGO := "res://data/mapas/regioes.json"
const SAIDA := "res://scenes/prototipo_3d/terreno_editavel.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var catalogo := _ler_json(CATALOGO)
	var regiao := _regiao_ativa(catalogo)
	if regiao.is_empty():
		push_error("Não há região ativa válida em " + CATALOGO)
		quit(1)
		return

	# Em execução por `--script`, os autoloads só podem ser citados pelas
	# dependências depois que a árvore subiu. `load` aqui evita compilar Mar antes
	# do autoload Mare existir.
	var script_renderizador := load(RENDERIZADOR) as Script
	if script_renderizador == null:
		push_error("Não foi possível carregar " + RENDERIZADOR)
		quit(1)
		return
	var gerador := script_renderizador.new() as Node3D
	gerador.name = "FonteDoTerreno"
	gerador.terrain_only = true
	gerador.set_meters_per_unit(float(regiao.get("scale_m_per_unit", 1.0)))
	gerador.set_vertical_exaggeration(float(regiao.get("vertical_exaggeration", 1.0)))
	root.add_child(gerador)
	await gerador.build_region(String(regiao["geometry"]), String(regiao["scenario"]))

	var terra := gerador.get_node_or_null("Terra")
	var colisao := gerador.get_node_or_null("Colisão da terra")
	if terra == null or colisao == null:
		push_error("O renderizador não produziu a terra e sua colisão.")
		quit(1)
		return

	var cena := Node3D.new()
	cena.name = "TerrenoEditor"
	cena.editor_description = (
		"Prévia editável da terra da região ativa. Atualize com "
		+ "tools/mapas/gerar_terreno_editavel.gd; o jogo remove esta cena antes de gerar o vale real."
	)
	gerador.remove_child(terra)
	gerador.remove_child(colisao)
	cena.add_child(terra)
	cena.add_child(colisao)
	_definir_dono(terra, cena)
	_definir_dono(colisao, cena)

	var pacote := PackedScene.new()
	var erro_pacote := pacote.pack(cena)
	if erro_pacote != OK:
		push_error("Não foi possível empacotar o terreno: %s" % error_string(erro_pacote))
		quit(1)
		return
	var erro := ResourceSaver.save(pacote, SAIDA)
	if erro != OK:
		push_error("Não foi possível salvar %s: %s" % [SAIDA, error_string(erro)])
		quit(1)
		return
	print("TERRENO_EDITOR_OK: ", SAIDA)
	root.remove_child(gerador)
	gerador.free()
	cena.free()
	quit()


func _definir_dono(no: Node, dono: Node) -> void:
	no.owner = dono
	for filho in no.get_children():
		_definir_dono(filho, dono)


func _ler_json(caminho: String) -> Dictionary:
	var dados: Variant = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	return dados if typeof(dados) == TYPE_DICTIONARY else {}


func _regiao_ativa(catalogo: Dictionary) -> Dictionary:
	var ativa := String(catalogo.get("active_region", ""))
	for valor in catalogo.get("regions", []):
		var regiao: Dictionary = valor
		if String(regiao.get("id", "")) == ativa:
			return regiao
	return {}
