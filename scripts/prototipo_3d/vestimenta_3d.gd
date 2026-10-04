extends RefCounted
## O QUE O CORPO MOSTRA DO QUE VESTE, no jogador do vale e no boneco da mochila.
##
## "No inventário, ao lado dos itens equipados, coloque o 3D do boneco com os
## itens equipados, igual nos jogos de RPG. Assim ele pode ver as alterações
## conforme vai equipando." O boneco (`boneco_da_mochila.gd`) e o jogador
## (`player_controller.gd`) vestem pelo mesmo caminho, daqui: o boneco nunca
## mostra o que o corpo no vale não mostra, nem o contrário.
##
## Aparecem o que tem modelo: o chapéu na cabeça e, na mão, o machado (de ferro
## ou de aço, que é o mesmo modelo) ou o facão. O gibão e o patuá ainda não têm
## modelo, e nada aparece por eles. No estilo procedural só o machado, que é o
## que aquele estilo desenha: o procedural não ganha arte nova.

const CatalogoAssets = preload("res://scripts/prototipo_3d/catalogo_assets.gd")

## O QUE VAI NA CABEÇA, por id do item: a peça do catálogo, a largura dela em
## metros, e onde ela assenta no osso da cabeça (metros acima e à frente do
## osso, no referencial dele).
const NA_CABECA := {
	"chapeu": {"peca": "chapeu", "metros": 0.42, "acima": 0.115, "frente": 0.012},
}
## O MACHADO COM O CORPO PARADO: o jogador o leva a -30° em volta da pegada
## (`player_controller._atualizar_pose_machado`), e o boneco o mostra assim.
const MACHADO_PARADO := -30.0
## AS FERRAMENTAS NA MÃO, pelo caminho que o machado do jogador sempre usou: o
## tamanho no catálogo, a pegada (o ponto do cabo, no GLB, que fica na palma) e
## o acerto antes do giro do punho. O facão vem deitado no GLB como o machado —
## cabo embaixo à direita, ponta em cima à esquerda —, mas com a lâmina 23°
## para trás, e o acerto a endireita; a pegada dele é o meio do cabo (medido
## nas vistas do GLB, `scratch/foto/foto_facao.gd`).
const NA_MAO := {
	"machado": {"tamanho": 0.46, "pegada": Vector3(0.34, 0.12, 0.0), "acerto": Vector3.ZERO},
	"facao": {"tamanho": 0.34, "pegada": Vector3(0.31, 0.19, 0.13), "acerto": Vector3(23.0, 0.0, 0.0)},
}


## O que o corpo mostra na mão agora: "machado", "facao" ou "". O machado ganha
## do facão, como na mão de verdade só cabe um.
static func item_na_mao() -> String:
	if Equipamento.da_familia_em_uso("machado") != "":
		return "machado"
	if Equipamento.em_uso("facao"):
		return "facao"
	return ""


## O que o corpo mostra na cabeça agora: o id do item, se ele tem modelo, ou "".
static func item_na_cabeca() -> String:
	var id := Equipamento.no_encaixe("cabeca")
	return id if NA_CABECA.has(id) else ""


## A ÂNCORA DA MÃO DIREITA: no boneco procedural, abaixo do cotovelo; no modelo
## com esqueleto, presa ao osso da mão direita; sem nenhum dos dois, num ponto
## fixo do corpo.
static func ancora_da_mao(modelo: Node3D, altura: float, visual: Node3D, nome: String = "MachadoNaMao") -> Node3D:
	if modelo is PersonagemProcedural:
		var cotovelo := modelo.find_child("CotoveloD", true, false) as Node3D
		if cotovelo == null:
			return null
		var ancora := Node3D.new()
		ancora.name = nome
		ancora.position = Vector3(0.0, -altura * 0.16, 0.0)
		cotovelo.add_child(ancora)
		return ancora
	var no_osso := _no_osso(modelo, "righthand", nome)
	if no_osso != null:
		return no_osso
	var ancora := Node3D.new()
	ancora.name = nome
	ancora.position = Vector3(0.34, 0.9, 0.08)
	visual.add_child(ancora)
	return ancora


## A ÂNCORA DA CABEÇA: presa ao osso da cabeça (o modelo com esqueleto), ou ao
## pivô "Cabeca" do boneco procedural.
static func ancora_da_cabeca(modelo: Node3D, nome: String = "ChapeuNaCabeca") -> Node3D:
	if modelo is PersonagemProcedural:
		var cabeca := modelo.find_child("Cabeca", true, false) as Node3D
		if cabeca == null:
			return null
		var ancora := Node3D.new()
		ancora.name = nome
		cabeca.add_child(ancora)
		return ancora
	return _no_osso(modelo, "head", nome)


## Uma âncora presa ao osso cujo nome termina em `sufixo` ("righthand", "head").
static func _no_osso(modelo: Node3D, sufixo: String, nome: String) -> Node3D:
	for encontrado in modelo.find_children("*", "Skeleton3D", true, false):
		var esqueleto := encontrado as Skeleton3D
		for indice in esqueleto.get_bone_count():
			if not String(esqueleto.get_bone_name(indice)).to_lower().ends_with(sufixo):
				continue
			var anexo := BoneAttachment3D.new()
			anexo.name = nome
			anexo.bone_name = esqueleto.get_bone_name(indice)
			esqueleto.add_child(anexo)
			var ancora := Node3D.new()
			anexo.add_child(ancora)
			return ancora
	return null


## Quanto a peça do catálogo precisa crescer para ter `metros` no maior eixo
## dentro de `ancora`: a âncora presa ao osso herda a escala do modelo.
static func _tamanho_na_ancora(ancora: Node3D, peca: String, metros: float) -> float:
	var spec: Dictionary = CatalogoAssets.PECAS.get(peca, {})
	var medida := float(spec.get("largura", spec.get("altura", 1.0)))
	var escala := ancora.global_basis.get_scale().x if ancora.is_inside_tree() else 1.0
	return metros / maxf(medida * escala, 0.0001)


## O MACHADO NA MÃO, no estilo de cada um. Devolve o pivô da pegada (o jogador
## gira o machado em volta dele no balanço do braço), ou null no procedural.
static func machado(ancora: Node3D, visual: Node3D) -> Node3D:
	if Estilo.procedural():
		machado_procedural(ancora)
		return null
	return _na_mao(ancora, visual, "machado")


## O FACÃO NA MÃO (só no estilo Tripo, que é onde ele tem modelo), pelo mesmo
## caminho do machado. Devolve o pivô da pegada.
static func facao(ancora: Node3D, visual: Node3D) -> Node3D:
	if not Estilo.tripo():
		return null
	return _na_mao(ancora, visual, "facao")


## A PEÇA NA MÃO: deitada no punho, com a pegada na palma e um pivô em volta da
## pegada para o balanço do braço — o código que era do machado do jogador.
static func _na_mao(ancora: Node3D, visual: Node3D, peca: String) -> Node3D:
	var ajuste: Dictionary = NA_MAO[peca]
	var no := CatalogoAssets.instanciar(peca, ancora, Vector3.ZERO, float(ajuste["tamanho"]))
	if no == null:
		return null
	no.rotation = Vector3(deg_to_rad(1.0), deg_to_rad(2.0), deg_to_rad(92.0))
	var acerto: Vector3 = ajuste["acerto"]
	no.basis = no.basis * Basis(Vector3.UP, PI) * Basis.from_euler(Vector3(deg_to_rad(acerto.x), deg_to_rad(acerto.y), deg_to_rad(acerto.z)))
	# A pegada fica logo acima da ponta real do cabo no GLB.
	var pegada: Vector3 = ajuste["pegada"]
	no.position -= no.transform * pegada
	no.position += Vector3(0.0, 0.06, 0.0)
	no.position += ancora.global_basis.inverse() * (visual.global_basis.x * 0.08)
	# Gira em torno da pegada para a ponta do cabo permanecer na mão direita.
	var pivo := Node3D.new()
	pivo.name = "PivoDaPegada"
	ancora.add_child(pivo)
	pivo.position = no.transform * pegada
	no.reparent(pivo, true)
	no.set_meta("peca", peca)
	return pivo


## O balanço do machado em volta da pegada, no eixo vertical do corpo.
static func girar_o_machado(ancora: Node3D, pivo: Node3D, visual: Node3D, angulo: float) -> void:
	var eixo_vertical_local := (ancora.global_basis.inverse() * visual.global_basis.y).normalized()
	pivo.basis = Basis(eixo_vertical_local, angulo)


static func machado_procedural(pai: Node3D) -> void:
	var cabo := MeshInstance3D.new()
	var malha_cabo := CylinderMesh.new()
	malha_cabo.top_radius = 0.018
	malha_cabo.bottom_radius = 0.024
	malha_cabo.height = 0.52
	cabo.mesh = malha_cabo
	cabo.position.y = -0.19
	var madeira := StandardMaterial3D.new()
	madeira.albedo_color = Color("70492d")
	cabo.material_override = madeira
	pai.add_child(cabo)
	var lamina := MeshInstance3D.new()
	var malha_lamina := BoxMesh.new()
	malha_lamina.size = Vector3(0.23, 0.15, 0.055)
	lamina.mesh = malha_lamina
	lamina.position = Vector3(0.07, -0.4, 0.0)
	var ferro := StandardMaterial3D.new()
	ferro.albedo_color = Color("777a78")
	ferro.metallic = 0.55
	lamina.material_override = ferro
	pai.add_child(lamina)
	pai.set_meta("peca", "machado")


## O QUE VAI NA CABEÇA (só no estilo Tripo).
static func na_cabeca(ancora: Node3D, id: String) -> Node3D:
	if not Estilo.tripo() or not NA_CABECA.has(id):
		return null
	var ajuste: Dictionary = NA_CABECA[id]
	var peca := str(ajuste["peca"])
	var tamanho := _tamanho_na_ancora(ancora, peca, float(ajuste["metros"]))
	var escala := ancora.global_basis.get_scale().x if ancora.is_inside_tree() else 1.0
	var assento := Vector3(0.0, float(ajuste["acima"]), float(ajuste["frente"])) / maxf(escala, 0.0001)
	var no := CatalogoAssets.instanciar(peca, ancora, assento, tamanho)
	if no != null:
		no.set_meta("peca", peca)
	return no
