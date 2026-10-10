extends RefCounted
## O QUE O CORPO MOSTRA DO QUE VESTE, no jogador do vale e no boneco da mochila.
##
## "No inventário, ao lado dos itens equipados, coloque o 3D do boneco com os
## itens equipados, igual nos jogos de RPG. Assim ele pode ver as alterações
## conforme vai equipando." O boneco (`boneco_da_mochila.gd`) e o jogador
## (`player_controller.gd`) vestem pelo mesmo caminho, daqui: o boneco nunca
## mostra o que o corpo no vale não mostra, nem o contrário.
##
## Aparecem o que tem modelo: o chapéu na cabeça, as luvas nas duas mãos e, na
## mão, o machado (de ferro ou de aço, que é o mesmo modelo), o facão, a foice,
## a picareta, a enxada, a vara de pescar ou o balde — a ferramenta da barra que
## tiver modelo. O gibão e o patuá ainda não têm
## modelo, e nada aparece por eles.

const CatalogoAssets = preload("res://scripts/prototipo_3d/catalogo_assets.gd")

## O QUE VAI NA CABEÇA, por id do item: a peça do catálogo, a largura dela em
## metros, e onde ela assenta no osso da cabeça (metros acima e à frente do
## osso, no referencial dele).
const NA_CABECA := {
	"chapeu": {"peca": "chapeu", "metros": 0.42, "acima": 0.115, "frente": 0.012},
}
## Os ossos da raiz de cada dedo, pelo nome que segue o do osso da mão (Mixamo).
const DEDOS := ["Thumb1", "Index1", "Middle1", "Ring1", "Pinky1"]
## AS LUVAS, o encaixe das Mãos ("não é para armas, mas sim para luvas"): a
## peça do catálogo, o comprimento da luva em metros (das pontas dos dedos à
## boca do punho), quanto ela recua do osso da mão para o punho cobrir o pulso,
## o deslocamento no quadro da mão (metros: X para o polegar, Z para a palma),
## quanto ela engrossa no eixo da palma (o couro grosso cobre a mão dos dois
## lados), o giro (graus) por cima do quadro, e quanto os dedos encolhem dentro
## dela. O modelo é de mão direita; na esquerda vai espelhado. Os números saíram
## de folhas de fotos do boneco (`scratch/foto/ajuste_luva.gd`).
const NAS_MAOS := {
	"luvas_de_couro": {"peca": "luvas_de_couro", "metros": 0.28, "recuo": 0.07, "deslocamento": Vector3(0.025, 0.0, -0.0075), "espessura": 1.25, "giro": Vector3.ZERO, "dedos": 0.1},
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
##
## TODO CABO É SEGURO COMO O MACHADO, que é o molde aprovado: o acerto de cada
## peça é o giro que leva o eixo do cabo e o lado da cabeça dela até os do
## machado no GLB, e a pegada fica a 7,4 cm da ponta do cabo, como a dele. Por
## cima do molde, a POSE de cada estado do corpo (`pose_de`): o giro em volta da
## vertical e a inclinação em volta do lado do corpo — positiva abaixa a ponta —,
## em graus. Sem pose escrita, parado e andando são (-30, 0) e o golpe (0, 0),
## que é o machado de sempre; "uso" é a lida que não é golpe (regar, pescar).
##
## O BALDE VAI PENDURADO ("pendurar"): em pé, pela alça, com a vertical do mundo
## — nunca deitado no punho. "ponta" é o ponto do GLB de onde sai alguma coisa:
## a linha da vara (`ponta_na_mao`).
##
## O ACERTO É DO OSSO DA MÃO DO CORPO EM QUE FOI MEDIDO. Cada rig do Tripo vira o
## osso da mão de um jeito em volta do eixo dos dedos: o do viajante
## (`viajante_tripo.glb`) difere 158° do do personagem medieval, em que estas
## linhas nasceram, e o mesmo acerto deita a peça na mão de um e a atravessa na do
## outro (foi o que reprovou o portão quando o corpo do jogador mudou). Dois
## corpos no mesmo clipe têm a mão para o mesmo lado — o que se mede nos nós dos
## dedos: a linha do mínimo ao indicador e o eixo do pulso ao dedo médio —, e só a
## rolagem do osso muda; então trocar o corpo é levar o acerto de cada linha pela
## rotação entre os dois ossos (`tools/prototipo_3d/acerto_para_o_corpo.gd` faz a
## conta), e a peça fica na mão como o machado aprovado a segurava. A pegada, o
## tamanho e as poses seguem. Assim ficou a tabela abaixo (viajante, 05/10): o
## machado, o facão e a foice chegaram com a pegada cerca de 1 cm mais para dentro
## da palma (o machado, na pior fase da passada, de 3,4 para 2,5 cm dela), e a
## enxada ganhou o `aperto` e uma pose do andar só dela — em fases do passo o cabo
## batia no braço direito, até 14% da peça dentro dele.
##
## O que o morador leva na mão (`npc._levar`) passa por aqui com o osso do rig dele,
## que gira de outro jeito (a rolagem varia de um morador a outro) e sem pose: o
## encaixe da enxada, da foice e da vara vale para o viajante.
##
## A enxada, o balde, a vara e a picareta foram refeitos no Tripo na noite de
## 05/10 (cabo reto e lâmina larga, alça de balde, vara de bambu, picareta de
## verdade): GLB novo pede só medir de novo e trocar a linha dele aqui, com a
## folha de `fotos_da_mao.gd`.
const NA_MAO := {
	# O fio do machado à frente e para baixo vem do acerto levado ao osso do viajante;
	# `eixo_inversao`/`rebater_lamina` (da main) ficam para peça que precise.
	"machado": {"tamanho": 0.46, "pegada": Vector3(0.34, 0.12, 0.014), "acerto": Vector3(21.9, -177.6, 174.0)},
	"facao": {"tamanho": 0.34, "pegada": Vector3(0.307, 0.199, 0.159), "acerto": Vector3(-1.0, -175.2, 174.4)},
	# No golpe a ponta desce 25°: a picareta bate na pedra, e não no ar.
	"picareta": {"tamanho": 0.536, "pegada": Vector3(0.149, 0.070, 0.078), "acerto": Vector3(-22.0, 29.2, 130.8), "golpe": Vector2(0.0, 25.0)},
	# A foicinha de mão (~0,55 m): parada, a lâmina vai à frente e para cima. O
	# cabo é fino, e a pegada entra no punho ("aperto").
	"foice": {"tamanho": 0.459, "pegada": Vector3(0.33, 0.138, 0.309), "acerto": Vector3(-75.9, -46.6, 126.7), "parado": Vector2(-30.0, -60.0), "aperto": 0.6},
	# A enxada de cabo reto (~1,3 m) e lâmina larga (~0,3 m): a pegada fica a
	# ~35 cm do pé do cabo (o pé passa entre as duas mãos do golpe). Em pé ela vai
	# ao ombro, com a lâmina para cima e para trás; andando, 8° mais para trás e 4°
	# a mais de giro, para o cabo não bater no braço na passada.
	"enxada": {"tamanho": 0.545, "pegada": Vector3(0.19, 0.578, -0.036), "acerto": Vector3(-20.4, 3.6, 13.7), "parado": Vector2(80.0, -105.0), "andando": Vector2(84.0, -113.0), "golpe": Vector2(0.0, 33.0), "aperto": 0.6},
	# A vara de 2,4 m: erguida, senão a ponta se enterra; pescando, baixa para a água.
	"vara_pescar": {"tamanho": 0.553, "pegada": Vector3(0.106, 0.029, 0.259), "acerto": Vector3(-44.1, 31.4, 126.5), "parado": Vector2(-42.0, -55.0), "golpe": Vector2(0.0, -55.0), "uso": Vector2(-36.0, -35.0), "ponta": Vector3(-0.12, 0.97, -0.33)},
	# Regando, o balde tomba para a frente pela alça e a boca despeja.
	"balde": {"tamanho": 0.5, "pegada": Vector3(0.09, 0.84, 0.06), "pendurar": true, "uso": Vector2(0.0, 70.0)},
}
## O ITEM QUE TEM OUTRO NOME NO CATÁLOGO DE MODELOS: o item é "vara_de_pescar",
## e a peça é "vara_pescar" (o cenário da orla já usa essa chave, que fica).
const PECA_DO_ITEM := {"vara_de_pescar": "vara_pescar"}


## O que o corpo mostra na mão agora: "machado" (o de ferro ou o de aço), a
## peça da ferramenta ou arma escolhida na barra que tenha modelo — o facão, a
## foice, a de aço com o modelo da de ferro (`Catalogo.familia`) —, ou "". Na
## mão de verdade só cabe uma.
static func item_na_mao() -> String:
	if Equipamento.da_familia_em_uso("machado") != "":
		return "machado"
	var id := Inventario.na_mao()
	if id == "" or (Catalogo.tipo(id) != "ferramenta" and Catalogo.dano(id) <= 0.0):
		return ""
	var peca := Catalogo.familia(id)
	peca = str(PECA_DO_ITEM.get(peca, peca))
	if not CatalogoAssets.tem_tripo(peca):
		return ""
	return peca


## O nome da âncora da mão para a peça: "MachadoNaMao", "FacaoNaMao"...
static func nome_da_ancora(peca: String) -> String:
	return peca.to_pascal_case() + "NaMao"


## A PEÇA NA MÃO, a que `item_na_mao` deu. Devolve o pivô da pegada (a pose de
## cada estado gira em volta dele, `posar`), ou null quando a peça não tem pivô
## (nenhuma hoje: toda peça na mão tem pivô).
static func na_mao(ancora: Node3D, visual: Node3D, peca: String) -> Node3D:
	if peca == "machado":
		return machado(ancora, visual)
	if not NA_MAO.has(peca):
		# Peça sem encaixe medido vai pendurada pelo topo: é o modo que nunca
		# entra no braço. Ela pede uma linha em NA_MAO.
		push_warning("Vestimenta3D: a peça \"%s\" não tem encaixe na mão (NA_MAO); vai pendurada pelo topo." % peca)
		return _pendurado(ancora, visual, peca, {})
	if bool(NA_MAO[peca].get("pendurar", false)):
		return _pendurado(ancora, visual, peca, NA_MAO[peca])
	return _na_mao(ancora, visual, peca)


## A POSE DA PEÇA num estado do corpo — "parado", "andando", "golpe" ou "uso" —:
## (giro em volta da vertical, inclinação em volta do lado do corpo), em graus.
## O que a linha da peça não diz é o do machado; pendurada, ela fica em pé.
static func pose_de(peca: String, estado: String) -> Vector2:
	var ajuste: Dictionary = NA_MAO.get(peca, {})
	var em_pe := bool(ajuste.get("pendurar", false)) or not NA_MAO.has(peca)
	var parado: Vector2 = ajuste.get("parado", Vector2.ZERO if em_pe else Vector2(MACHADO_PARADO, 0.0))
	match estado:
		"andando":
			return ajuste.get("andando", parado)
		"golpe":
			return ajuste.get("golpe", Vector2.ZERO)
		"uso":
			return ajuste.get("uso", parado)
	return parado


## Ao erguer a enxada o cabo passa pelo lado do ombro, não pelo peito.
## No contato e no retorno mantém o encaixe medido do golpe.
static func pose_no_golpe(peca: String, fase: float) -> Vector2:
	var pose := pose_de(peca, "golpe")
	if peca == "enxada" and fase >= 0.0:
		var levantar := smoothstep(0.06, 0.12, fase)
		var alinhar := 1.0 - smoothstep(0.18, 0.25, fase)
		pose.x -= 30.0 * levantar * alinhar
		var descer := smoothstep(0.28, 0.33, fase)
		var contato := 1.0 - smoothstep(0.39, 0.44, fase)
		pose.x += 20.0 * descer * contato
	return pose


## POSA A PEÇA em volta da pegada: `pose` é (giro, inclinação) em graus, no
## quadro do corpo (`visual`), como `pose_de` dá. A pendurada guarda a pose e se
## apruma sozinha a cada quadro do esqueleto.
static func posar(ancora: Node3D, pivo: Node3D, visual: Node3D, pose: Vector2) -> void:
	if pivo is PivoPendurado:
		pivo.giro = pose.x
		pivo.inclinacao = pose.y
		pivo.aprumar()
		return
	var vertical := (ancora.global_basis.inverse() * visual.global_basis.y).normalized()
	var lateral := (ancora.global_basis.inverse() * visual.global_basis.x).normalized()
	pivo.basis = Basis(vertical, deg_to_rad(pose.x)) * Basis(lateral, deg_to_rad(pose.y))


## ONDE A PONTA DA PEÇA NA MÃO ESTÁ NO MUNDO (a da vara, de onde sai a linha; a
## boca do balde), procurando em `corpo` a peça vestida; INF se não houver.
static func ponta_na_mao(corpo: Node) -> Vector3:
	if corpo == null:
		return Vector3.INF
	for encontrado in corpo.find_children("*", "Node3D", true, false):
		var no := encontrado as Node3D
		if not no.has_meta("peca") or no.is_queued_for_deletion() or not no.is_visible_in_tree():
			continue
		var ajuste: Dictionary = NA_MAO.get(str(no.get_meta("peca")), {})
		if ajuste.has("ponta"):
			return no.global_transform * (ajuste["ponta"] as Vector3)
	return Vector3.INF


## A PEÇA PENDURADA (o balde): em pé, pela pegada, que fica na palma. Sem
## pegada medida, pelo meio do topo do GLB.
static func _pendurado(ancora: Node3D, visual: Node3D, peca: String, ajuste: Dictionary) -> Node3D:
	var no := CatalogoAssets.instanciar(peca, ancora, Vector3.ZERO, float(ajuste.get("tamanho", 0.5)))
	if no == null:
		return null
	var fator := no.scale.x
	var pegada: Vector3 = ajuste.get("pegada", Vector3.INF)
	if not pegada.is_finite():
		var caixa: AABB = no.get_meta("limites", AABB())
		pegada = Vector3(caixa.get_center().x, caixa.end.y, caixa.get_center().z) / maxf(fator, 0.0001)
	var pivo := PivoPendurado.new()
	pivo.name = "PivoDaAlca"
	pivo.corpo = visual
	pivo.position = Vector3(0.0, 0.06, 0.0)
	ancora.add_child(pivo)
	no.reparent(pivo, false)
	no.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * fator), -pegada * fator)
	no.set_meta("peca", peca)
	pivo.aprumar()
	return pivo


## O PIVÔ DA PEÇA PENDURADA: segue a palma, mas não o giro da mão — fica com a
## vertical do mundo e o rumo do corpo, mais a pose. Ele se apruma no sinal do
## esqueleto, DEPOIS de a animação mexer a mão: no `_process` ele correria um
## quadro atrás dela, e o balde tremeria.
class PivoPendurado extends Node3D:
	var corpo: Node3D
	var giro := 0.0
	var inclinacao := 0.0

	func _ready() -> void:
		var no := get_parent()
		while no != null and not (no is Skeleton3D):
			no = no.get_parent()
		if no != null:
			(no as Skeleton3D).skeleton_updated.connect(aprumar)
		set_process(no == null)

	func _process(_delta: float) -> void:
		aprumar()

	func aprumar() -> void:
		if not is_instance_valid(corpo) or not is_inside_tree():
			return
		var escala := get_parent_node_3d().global_basis.get_scale().x
		var rumo := corpo.global_rotation.y + deg_to_rad(giro)
		global_basis = (Basis(Vector3.UP, rumo) * Basis(Vector3.RIGHT, deg_to_rad(inclinacao))).scaled(Vector3.ONE * escala)


## O que o corpo mostra nas mãos agora (as luvas): o id do item, se ele tem
## modelo, ou "".
static func item_nas_maos() -> String:
	var id := Equipamento.no_encaixe("maos")
	return id if NAS_MAOS.has(id) else ""


## O que o corpo mostra na cabeça agora: o id do item, se ele tem modelo, ou "".
static func item_na_cabeca() -> String:
	var id := Equipamento.no_encaixe("cabeca")
	return id if NA_CABECA.has(id) else ""


## A ÂNCORA DA MÃO DIREITA: no modelo com esqueleto, presa ao osso da mão
## direita; sem esqueleto (a caixa cinza provisória), num ponto fixo do corpo.
static func ancora_da_mao(modelo: Node3D, altura: float, visual: Node3D, nome: String = "MachadoNaMao") -> Node3D:
	var no_osso := _no_osso(modelo, "righthand", nome)
	if no_osso != null:
		return no_osso
	var ancora := Node3D.new()
	ancora.name = nome
	ancora.position = Vector3(0.34, 0.9, 0.08)
	visual.add_child(ancora)
	return ancora


## A ÂNCORA DA CABEÇA: presa ao osso da cabeça (o modelo com esqueleto).
static func ancora_da_cabeca(modelo: Node3D, nome: String = "ChapeuNaCabeca") -> Node3D:
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


## O MACHADO NA MÃO. Devolve o pivô da pegada (o jogador gira o machado em volta
## dele no balanço do braço).
static func machado(ancora: Node3D, visual: Node3D) -> Node3D:
	return _na_mao(ancora, visual, "machado")


## A PEÇA NA MÃO: deitada no punho, com a pegada na palma e um pivô em volta da
## pegada para o balanço do braço — o código que era do machado do jogador.
static func _na_mao(ancora: Node3D, visual: Node3D, peca: String) -> Node3D:
	var ajuste: Dictionary = NA_MAO[peca]
	var no := CatalogoAssets.instanciar(peca, ancora, Vector3.ZERO, float(ajuste["tamanho"]))
	if no == null:
		return null
	no.rotation = Vector3(deg_to_rad(1.0), deg_to_rad(2.0), deg_to_rad(92.0))
	var acerto: Vector3 = ajuste["acerto"]
	var eixo_inversao: Vector3 = ajuste.get("eixo_inversao", Vector3.UP)
	no.basis = no.basis * Basis(eixo_inversao, PI) * Basis.from_euler(Vector3(deg_to_rad(acerto.x), deg_to_rad(acerto.y), deg_to_rad(acerto.z)))
	if ajuste.get("rebater_lamina", false):
		no.basis = no.basis * Basis.from_scale(Vector3(-1.0, 1.0, 1.0))
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
	# CABO FINO: o lugar da pegada do machado deixa o cabo dele, grosso, junto da
	# palma; um cabo fino ali ficaria solto, longe dos dedos. O pivô — e a peça
	# com ele — anda essa fração do caminho até a palma.
	if ajuste.has("aperto"):
		pivo.position = pivo.position.lerp(_palma_na_ancora(ancora), float(ajuste["aperto"]))
	no.set_meta("peca", peca)
	return pivo


## A PALMA no quadro da âncora da mão: o meio do osso da mão e da raiz do dedo
## médio. Sem esqueleto, o lugar da pegada do machado.
static func _palma_na_ancora(ancora: Node3D) -> Vector3:
	var anexo := ancora.get_parent() as BoneAttachment3D
	var esqueleto := anexo.get_parent() as Skeleton3D if anexo != null else null
	if esqueleto == null:
		return Vector3(0.0, 0.06, 0.0)
	var mao := esqueleto.find_bone(String(anexo.bone_name))
	var medio := esqueleto.find_bone(String(anexo.bone_name) + "Middle1")
	if mao < 0 or medio < 0:
		return Vector3(0.0, 0.06, 0.0)
	return 0.5 * (esqueleto.get_bone_global_rest(mao).affine_inverse() * esqueleto.get_bone_global_rest(medio).origin)


## O balanço do machado em volta da pegada, no eixo vertical do corpo (o atalho
## de `posar` sem inclinação; `angulo` em radianos).
static func girar_o_machado(ancora: Node3D, pivo: Node3D, visual: Node3D, angulo: float) -> void:
	posar(ancora, pivo, visual, Vector2(rad_to_deg(angulo), 0.0))


## AS LUVAS NAS DUAS MÃOS: presas aos ossos das mãos, a direita como o modelo
## vem e a esquerda espelhada. Devolve as âncoras postas (para quem as tira
## depois).
static func luvas(modelo: Node3D, id: String) -> Array[Node3D]:
	var postas: Array[Node3D] = []
	if not NAS_MAOS.has(id):
		return postas
	var dedos := PackedInt32Array()
	for lado in [["righthand", "LuvaDireita", false], ["lefthand", "LuvaEsquerda", true]]:
		var ancora := _no_osso(modelo, str(lado[0]), str(lado[1]))
		if ancora == null:
			continue
		if _luva(ancora, id, bool(lado[2])) != null:
			postas.append(ancora)
			var anexo := ancora.get_parent() as BoneAttachment3D
			var esqueleto := anexo.get_parent() as Skeleton3D
			for dedo in DEDOS:
				var osso := esqueleto.find_bone(String(anexo.bone_name) + str(dedo))
				if osso >= 0:
					dedos.append(osso)
	# OS DEDOS DENTRO DA LUVA: a luva é rígida, de dedos esticados, e a mão do
	# modelo dobra os dedos (no parado, na pegada); dobrados, eles furariam o
	# couro. Encolhidos desde o nó, ficam dentro dela. Só os dedos: do osso da
	# mão pendem o machado e o facão, que não podem encolher junto.
	if not dedos.is_empty():
		var esqueleto := postas[0].get_parent().get_parent() as Skeleton3D
		var encolhe := MaoNaLuva.new()
		encolhe.name = "MaoNaLuva"
		encolhe.ossos = dedos
		encolhe.escala = float(NAS_MAOS[id].get("dedos", 1.0))
		esqueleto.add_child(encolhe)
		postas.append(encolhe)
	return postas


## Encolhe os dedos depois da animação, a cada quadro: o modificador do
## esqueleto roda por último, e a animação não o desfaz. O Godot devolve a pose
## de antes ao fim do quadro: sem o modificador, a mão volta ao tamanho dela.
class MaoNaLuva extends SkeletonModifier3D:
	var ossos := PackedInt32Array()
	var escala := 1.0

	func _process_modification_with_delta(_delta: float) -> void:
		var esqueleto := get_skeleton()
		if esqueleto == null:
			return
		for osso in ossos:
			esqueleto.set_bone_pose_scale(osso, Vector3.ONE * escala)


static func _luva(ancora: Node3D, id: String, esquerda: bool) -> Node3D:
	var ajuste: Dictionary = NAS_MAOS[id]
	var peca := str(ajuste["peca"])
	var escala := ancora.global_basis.get_scale().x if ancora.is_inside_tree() else 1.0
	# O pivô põe a luva no QUADRO DA MÃO (os eixos dela, medidos nos ossos dos
	# dedos); dentro dele, na mão esquerda, um espelho, porque o modelo é de mão
	# direita. A boca do punho recua para cobrir o pulso.
	var pivo := Node3D.new()
	pivo.name = "Pivo"
	ancora.add_child(pivo)
	var giro: Vector3 = ajuste["giro"]
	pivo.basis = _quadro_da_mao(ancora, esquerda) * Basis.from_euler(Vector3(deg_to_rad(giro.x), deg_to_rad(giro.y), deg_to_rad(giro.z)))
	var dentro: Node3D = pivo
	if esquerda:
		dentro = Node3D.new()
		dentro.name = "Espelho"
		dentro.scale = Vector3(-1.0, 1.0, 1.0)
		pivo.add_child(dentro)
	var tamanho := _tamanho_na_ancora(ancora, peca, float(ajuste["metros"]))
	var deslocamento: Vector3 = ajuste.get("deslocamento", Vector3.ZERO)
	var assento := Vector3(deslocamento.x, -float(ajuste["recuo"]), deslocamento.z) / maxf(escala, 0.0001)
	var no := CatalogoAssets.instanciar(peca, dentro, assento, tamanho)
	if no == null:
		return null
	no.set_meta("peca", peca)
	# Mais grossa no eixo da palma, em volta do meio da luva (e não da origem
	# do GLB, que fica fora do meio).
	var espessura := float(ajuste.get("espessura", 1.0))
	var meio: Vector3 = (no.get_meta("limites", AABB()) as AABB).get_center()
	no.scale.z *= espessura
	no.position.z -= meio.z * (espessura - 1.0)
	return no


## O QUADRO DA MÃO, no espaço do osso dela: o Y vai do pulso ao nó do dedo
## médio, o X atravessa a palma do mínimo para o indicador (para o polegar), e
## o Z sai da palma. Medido nas posições de descanso dos ossos dos dedos, e não
## nos eixos do osso da mão, que cada rig vira de um jeito. A luva do modelo tem
## os dedos no +Y, o polegar no +X e a palma no +Z; na mão esquerda, que vai
## espelhada, o X do quadro aponta para longe do polegar.
static func _quadro_da_mao(ancora: Node3D, esquerda: bool) -> Basis:
	var anexo := ancora.get_parent() as BoneAttachment3D
	var esqueleto := anexo.get_parent() as Skeleton3D if anexo != null else null
	if esqueleto == null:
		return Basis.IDENTITY
	var osso := String(anexo.bone_name)
	var mao := esqueleto.find_bone(osso)
	var medio := esqueleto.find_bone(osso + "Middle1")
	var indicador := esqueleto.find_bone(osso + "Index1")
	var minimo := esqueleto.find_bone(osso + "Pinky1")
	if mao < 0 or medio < 0 or indicador < 0 or minimo < 0:
		return Basis.IDENTITY
	var para_a_mao := esqueleto.get_bone_global_rest(mao).affine_inverse()
	var eixo := (para_a_mao * esqueleto.get_bone_global_rest(medio).origin).normalized()
	var lado := (para_a_mao * esqueleto.get_bone_global_rest(indicador).origin) - (para_a_mao * esqueleto.get_bone_global_rest(minimo).origin)
	if esquerda:
		lado = -lado
	var x := (lado - eixo * lado.dot(eixo)).normalized()
	return Basis(x, eixo, x.cross(eixo))


## O QUE VAI NA CABEÇA.
static func na_cabeca(ancora: Node3D, id: String) -> Node3D:
	if not NA_CABECA.has(id):
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
