extends SceneTree
## Portão da prévia: a cena precisa guardar a mesma terra para as duas telas de
## composição e o runtime precisa descartá-la antes de construir o vale real.

const PREVIA := "res://scenes/prototipo_3d/terreno_editavel.tscn"
var falhas := 0


func _initialize() -> void:
	var recurso := load(PREVIA) as PackedScene
	_verificar(recurso != null, "cena do terreno editável carrega")
	if recurso != null:
		var terreno := recurso.instantiate()
		var visual := terreno.get_node_or_null("Terra") as MeshInstance3D
		var colisao := terreno.get_node_or_null("Colisão da terra/Forma") as CollisionShape3D
		_verificar(visual != null and visual.mesh != null, "prévia guarda a malha de terra")
		_verificar(visual != null and visual.mesh.get_aabb().size.x > 100.0, "malha tem a extensão da região")
		_verificar(visual != null and visual.mesh.get_aabb().size.y > 40.0, "malha persistida usa exageração vertical 2x")
		_verificar(colisao != null and colisao.shape != null, "prévia guarda a colisão do terreno")
		terreno.free()

	for cena in ["abertura.tscn", "vale.tscn"]:
		var texto := FileAccess.get_file_as_string("res://scenes/prototipo_3d/" + cena)
		_verificar(texto.contains("terreno_editor_preview.gd"), cena + " tem o host da prévia")
		_verificar(not texto.contains("terreno_editavel.tscn"), cena + " não carrega a malha pesada no jogo")
	var host := FileAccess.get_file_as_string("res://scripts/prototipo_3d/terreno_editor_preview.gd")
	_verificar(host.contains("Engine.is_editor_hint()"), "host só carrega a prévia dentro do editor")
	_verificar(host.contains(PREVIA), "host aponta para a cena editável")
	var construtor := FileAccess.get_file_as_string("res://scripts/prototipo_3d/world_builder.gd")
	_verificar(construtor.contains('get_node_or_null("TerrenoEditor")'), "runtime encontra e remove a prévia")

	print("TERRENO_EDITOR_OK: prévia visível nas duas cenas, com malha e colisão" if falhas == 0 else "terreno_editor: Falhas: %d" % falhas)
	quit(1 if falhas else 0)


func _verificar(condicao: bool, descricao: String) -> void:
	if not condicao:
		falhas += 1
		push_error("FALHOU: " + descricao)
