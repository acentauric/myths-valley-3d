extends RefCounted
## A cena é a fonte de posição das construções. Nunca a regenere sobre uma edição.

const CENA := "res://scenes/prototipo_3d/composicao_vale.tscn"


static func ler(caminho: String = CENA) -> Dictionary:
	if not ResourceLoader.exists(caminho):
		push_error("A composição autoral não foi encontrada: " + caminho)
		return {}
	var recurso := load(caminho) as PackedScene
	if recurso == null:
		push_error("Não foi possível ler a composição autoral: " + caminho)
		return {}
	var cena := recurso.instantiate()
	var resultado := extrair(cena)
	cena.free()
	return resultado


static func extrair(cena: Node) -> Dictionary:
	var resultado := {}
	var casas := cena.get_node_or_null("Casas")
	if casas == null:
		push_error("A composição precisa do grupo Casas.")
		return resultado
	for casa in casas.get_children():
		if not casa is Node3D or casa.get_script() == null:
			continue
		var nome: String = casa.identificador
		if nome.is_empty() or resultado.has(nome):
			push_error("Identificador vazio ou repetido na composição: " + nome)
			continue
		var transformacao: Transform3D = (casas as Node3D).transform * casa.transform
		var giro := transformacao.basis.get_euler()
		if not transformacao.origin.is_finite() or not transformacao.basis.get_scale().is_equal_approx(Vector3.ONE) or absf(giro.x) > 0.001 or absf(giro.z) > 0.001:
			push_error("Transformação inválida de " + nome + ": use posição e rotação Y.")
			continue
		resultado[nome] = {
			"pos": transformacao.origin, "yaw": giro.y, "chave": casa.chave,
			"inicial": casa.posicao_inicial, "giro_inicial": casa.giro_inicial,
			"lote_inicial": casa.posicao_lote_inicial,
		}
		resultado[nome]["alicerce"] = casa.ajustes_alicerce() if casa.has_method("ajustes_alicerce") else {}
		# Peças autorais: depois de criadas no editor, só elas valem (apagar = sumir do jogo).
		var pecas: Array = []
		for filho in casa.get_children():
			if filho.has_method("dados"):
				pecas.append(filho.dados())
		resultado[nome]["pecas"] = pecas
		resultado[nome]["pecas_autorais"] = bool(casa.get("pecas_criadas"))
		var terreiro := casa.get_node_or_null("Terreiro") as Decal
		if terreiro != null:
			# Relativo à casa: o jogo reaplica sobre a posição final (após assentar no terreno).
			resultado[nome]["terreiro"] = {
				"transform": terreiro.transform, "size": terreiro.size, "modulate": terreiro.modulate,
				"visible": terreiro.visible,
			}
	return resultado


## OS AVULSOS: objetos fora das casas (árvores soltas, píer, praça, fazenda...), no
## grupo "Avulsos" da composição, em subgrupos só de organização. Posição no mundo.
## Devolve {"criados": bool, "itens": {id: dados}}; sem o grupo, o jogo usa o código.
static func ler_avulsos(caminho: String = CENA) -> Dictionary:
	if not ResourceLoader.exists(caminho):
		return {"criados": false, "itens": {}}
	var recurso := load(caminho) as PackedScene
	if recurso == null:
		return {"criados": false, "itens": {}}
	var cena := recurso.instantiate()
	var resultado := extrair_avulsos(cena)
	cena.free()
	return resultado


static func extrair_avulsos(cena: Node) -> Dictionary:
	var grupo := cena.get_node_or_null("Avulsos") as Node3D
	if grupo == null:
		return {"criados": false, "itens": {}}
	var itens := {}
	var grupos: Array = []
	for filho in grupo.get_children():
		if not filho.has_method("dados"):
			grupos.append(String(filho.name))
	_coletar_avulsos(grupo, Transform3D.IDENTITY, itens)
	return {"criados": true, "itens": itens, "grupos": grupos}


static func _coletar_avulsos(no: Node, acumulado: Transform3D, itens: Dictionary, grupo: String = "") -> void:
	for filho in no.get_children():
		if not filho is Node3D:
			continue
		var transformacao: Transform3D = acumulado * (filho as Node3D).transform
		if filho.has_method("dados"):
			var dados: Dictionary = filho.dados()
			var id := String(dados.get("id", ""))
			if id.is_empty():
				id = String(filho.name)
			if itens.has(id):
				push_error("Id de avulso repetido na composição: " + id)
				continue
			dados["transform"] = transformacao
			dados["grupo"] = grupo
			itens[id] = dados
		else:
			_coletar_avulsos(filho, transformacao, itens, String(filho.name) if grupo.is_empty() else grupo)
