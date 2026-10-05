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
	return resultado
