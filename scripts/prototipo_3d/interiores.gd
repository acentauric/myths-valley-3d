extends Node3D
## AS CONSTRUÇÕES POR DENTRO, no lugar delas no vale.
##
## O vale não tinha cômodo nenhum (#26: "o buraco maior"). A primeira
## construção que se abriu foi a igreja do Bom Jesus (`interior_igreja.gd`); a
## segunda, a casa herdada (`interior_casa.gd`), onde fica a cama que vira o
## dia (#50). O que os dois cômodos têm em comum mora em `comodo.gd`.
##
##
## DENTRO DA PRÓPRIA CONSTRUÇÃO
##
## "Os cômodos têm que ser em 3D mesmo. O 2D é só referência." A primeira
## versão fazia como o 2D: a nave morava longe do vale, e a porta levava até
## ela num escurecer — e tudo o que pergunta onde o jogador está (a bússola, o
## mapa, o Pedro, o save) precisava ser enganado para ver a porta. Agora o
## cômodo mora DENTRO DA CASCA do modelo, no lugar da igreja: entra-se andando
## pela porta, o Pedro entra junto, e o vale vê o jogador onde ele está.
##
##
## COMO O CÔMODO CABE NA CASCA
##
## O modelo do Tripo é uma malha fechada, com uma caixa de colisão inteira por
## cima — não há onde entrar. Ao montar, este nó:
##
##   1. MEDE A CASCA por dentro, com raios contra a própria malha (uma colisão
##      provisória, numa camada só dela, desfeita em seguida): onde ficam as
##      paredes, o fundo, a fachada, o beiral e o chão; e, contra a colisão do
##      mundo, o patamar na porta, a quina do alicerce e o chão livre até o
##      cruzeiro. Assim o cômodo acompanha o modelo, e o estilo procedural —
##      cuja porta atravessa a torre — também.
##   2. TIRA A COLISÃO INTEIRA da construção, e o cômodo põe a dele: paredes um
##      palmo para dentro da casca, o vão da porta, e rampas onde degrau
##      travaria o pé — da nave ao patamar, e do patamar ao adro por cima da
##      quina do alicerce de pedra.
##   3. ABRE A PORTA: um vão escuro por cima da porta pintada da fachada. De
##      dentro, o vão mostra o adro — a casca do modelo só desenha a face de
##      fora, e por isso some de dentro. E a câmera fica do lado da porta em
##      que o jogador está (`camera_do_lado_de_dentro`).
##
## O que este nó NÃO faz: esvaziar o modelo, ou esconder pedaço dele. A casca
## fica inteira, e o cômodo cabe nela.

signal entrou(qual: String)
signal saiu(qual: String)

const Comodo = preload("res://scripts/prototipo_3d/comodo.gd")
const InteriorIgreja = preload("res://scripts/prototipo_3d/interior_igreja.gd")
const InteriorCasa = preload("res://scripts/prototipo_3d/interior_casa.gd")

## As construções que se abrem:
##
##   ancora     a âncora do vale e o nome do lote (`world_builder.construcoes`)
##   nome       o que o HUD escreve lá dentro
##   colisao    o nome do corpo inteiro, para quando o lote não o guardou
##   meio_lote  até onde, do meio, vai a casca (de lado, e de frente e fundo):
##              no procedural, as malhas e os corpos do lote são os daí
##   porta_x    onde a porta fica na fachada, do meio para a direita de quem
##              olha a casa de frente; e o tamanho do vão da porta pintada
##   sonda      de que altura se procura o patamar na frente da porta: abaixo
##              do beiral, que na casa de taipa avança por cima da porta
const CONSTRUCOES := {
	"igreja": {"ancora": "Igreja", "nome": "Igreja do Bom Jesus", "colisao": "IgrejaColisao",
		"meio_lote": Vector2(4.5, 8.0), "porta_x": 0.0, "largura_da_porta": 1.2, "altura_da_porta": 2.7, "sonda": 8.0},
	"casa": {"ancora": "Casa de taipa", "nome": "Sua casa", "colisao": "Casa TaipaColisao",
		"meio_lote": Vector2(3.4, 3.2), "porta_x": 0.92, "largura_da_porta": 1.05, "altura_da_porta": 2.15, "sonda": 1.6},
	# AS CASAS DO PEDRO E DA DONA ZEFA: a mesma casa de taipa por fora, e por
	# dentro a de quem mora (`InteriorCasa.perfil`). O lote é o que o vale
	# escolheu para cada um (`WorldBuilder.casas_dos_moradores`).
	"casa_pedro": {"morador": "pedro", "nome": "Casa do Pedro", "perfil": "pescador",
		"meio_lote": Vector2(3.4, 3.2), "porta_x": 0.92, "largura_da_porta": 1.05, "altura_da_porta": 2.15, "sonda": 1.6},
	"casa_zefa": {"morador": "zefa", "nome": "Casa da Dona Zefa", "perfil": "rezadeira",
		"meio_lote": Vector2(3.4, 3.2), "porta_x": 0.92, "largura_da_porta": 1.05, "altura_da_porta": 2.15, "sonda": 1.6},
}

## A camada de física das colisões provisórias da medida (só elas moram nela).
const CAMADA_DE_MEDIR := 1 << 19
## Quanto a parede do cômodo fica para dentro da casca do modelo.
const FOLGA := 0.1

var _mundo: Node3D
var _jogador: Node3D
## qual -> {"sala": Node3D, "nome": String}
var _construcoes: Dictionary = {}
var _dentro := ""


## Monta os cômodos. É uma corrotina: a medida espera dois quadros de física
## para a colisão provisória valer — quem precisa do cômodo pronto (o save que
## põe o jogador lá dentro) espera com `await`. Os corpos dos moradores entram
## na luz de dentro depois, quando eles existirem (`marcar_os_corpos`).
func configurar(mundo: Node3D, jogador: Node3D) -> void:
	_mundo = mundo
	_jogador = jogador
	add_to_group("interiores")
	for qual in CONSTRUCOES:
		await _abrir(qual)


## Em que construção o jogador está, ou "".
func dentro() -> String:
	return _dentro


func sala_de(qual: String) -> Node3D:
	return _construcoes[qual]["sala"] if _construcoes.has(qual) else null


func nome_de(qual: String) -> String:
	return tr(str(CONSTRUCOES.get(qual, {}).get("nome", "")))


## Em que cômodo este ponto do mundo está, ou "".
func contem(ponto: Vector3) -> String:
	for qual in _construcoes:
		if (_construcoes[qual]["sala"] as Node3D).contem(ponto):
			return qual
	return ""


## O PRÓXIMO PONTO no caminho de `de` até `para`, quando um está dentro de um
## cômodo e o outro não: a soleira do lado de quem anda, e, já no corredor da
## porta, a do outro lado. Sem cômodo no meio, é o próprio destino. É por aqui
## que o Pedro entra junto: andando em linha reta ele empurraria a parede, e
## não acharia a porta.
##
## O corredor é uma faixa, e não a distância até a soleira: com a distância, o
## Pedro que passava da soleira de fora rumo à porta ficava longe dela de novo,
## dava meia-volta, e ficava indo e vindo no patamar.
func passagem(de: Vector3, para: Vector3) -> Vector3:
	for qual in _construcoes:
		var sala: Node3D = _construcoes[qual]["sala"]
		var de_dentro: bool = sala.contem(de)
		if de_dentro == sala.contem(para):
			continue
		var fora: Vector3 = sala.soleira_de_fora()
		var por_dentro: Vector3 = sala.soleira_de_dentro()
		if sala.no_vao(de):
			return fora if de_dentro else por_dentro
		return por_dentro if de_dentro else fora
	return para


func _process(_delta: float) -> void:
	if _jogador == null:
		return
	var agora := contem(_jogador.global_position)
	if agora == _dentro:
		return
	var antes := _dentro
	_dentro = agora
	if "dentro_de" in _jogador:
		_jogador.dentro_de = agora
	for qual in _construcoes:
		(_construcoes[qual]["sala"] as Node3D).camera_do_lado_de_dentro(qual == agora)
	var sala_de_agora = sala_de(agora)
	if _jogador.has_method("camera_de_cima"):
		var de_cima: bool = sala_de_agora != null and bool(sala_de_agora.camera_de_cima)
		_jogador.camera_de_cima(de_cima, sala_de_agora.corpos_do_comodo() if de_cima else ([] as Array[RID]))
	if antes != "":
		saiu.emit(antes)
	if agora != "":
		entrou.emit(agora)


# --- montar um cômodo -----------------------------------------------------------

func _abrir(qual: String) -> void:
	var dado: Dictionary = CONSTRUCOES[qual]
	var ancora := str(dado.get("ancora", ""))
	if dado.has("morador"):
		var casas = _mundo.get("casas_dos_moradores") if _mundo != null else null
		ancora = str(casas.get(str(dado["morador"]), "")) if casas is Dictionary else ""
	if ancora == "":
		return
	if _mundo == null or not ("ancoras" in _mundo) or not _mundo.ancoras.has(ancora):
		return
	var base: Vector3 = _mundo.ancoras[ancora]
	var frente := _frente(ancora)
	var chao: float = _mundo.ground_height_at(base)
	var centro := Vector3(base.x, chao, base.z)
	var construcoes = _mundo.get("construcoes")
	var lote: Dictionary = construcoes.get(ancora, {}) if construcoes is Dictionary else {}
	var modelo: Node3D = lote.get("modelo") if is_instance_valid(lote.get("modelo")) else null
	if modelo == null and qual == "igreja":
		modelo = _mundo.get_node_or_null(ancora.capitalize() + "Tripo")
	var malhas := _malhas_da_casca(modelo, centro, frente, dado["meio_lote"])
	if malhas.is_empty():
		return
	var caixa_inteira: Node = lote.get("colisao") if is_instance_valid(lote.get("colisao")) else null
	if caixa_inteira == null and modelo != null and qual == "igreja":
		caixa_inteira = _mundo.get_node_or_null(str(dado.get("colisao", "")))
	var medida: Dictionary = await _medir(malhas, centro, frente, caixa_inteira, dado)
	if medida.is_empty():
		return
	_tirar_a_colisao_inteira(caixa_inteira, modelo, centro, frente, medida)
	if modelo != null:
		_casca_so_por_fora(modelo)

	var sala: Node3D = null
	match qual:
		"igreja":
			sala = InteriorIgreja.new()
		"casa", "casa_pedro", "casa_zefa":
			sala = InteriorCasa.new()
			sala.perfil = str(dado.get("perfil", "herdada"))
	if sala == null:
		return
	# A parede do cômodo fica FOLGA para dentro da casca; a da frente, rente
	# ao lado de dentro da porta. A origem do cômodo é o meio da fachada, por
	# dentro, e o cômodo corre para trás (-Z), longe da fachada.
	var meia_largura: float = float(medida["lado"]) - FOLGA - Comodo.PAREDE
	var ate_a_frente: float = float(medida["frente"]) - FOLGA - Comodo.PAREDE
	var ate_o_fundo: float = float(medida["fundo"]) - FOLGA - Comodo.PAREDE
	var chao_da_nave: float = float(medida["chao"])
	sala.configurar({
		"largura": meia_largura * 2.0,
		"comprimento": ate_a_frente + ate_o_fundo,
		"pe_direito": float(medida["teto"]) - chao_da_nave - 0.25,
		"fundo_da_porta": float(medida["fachada"]) - (ate_a_frente + Comodo.PAREDE),
		"soleira": chao_da_nave - float(medida["soleira"]),
		"degrau_de_fora": float(medida["soleira"]) - float(medida["terreno"]),
		"borda": float(medida["borda"]) - ate_a_frente,
		"livre": float(medida["livre"]),
		"porta_x": float(dado["porta_x"]),
		"largura_da_porta": float(dado["largura_da_porta"]),
		"altura_da_porta": float(dado["altura_da_porta"]),
	})
	sala.name = "Interior_" + qual
	# A casca que some para a câmera de cima: o modelo, ou as malhas do lote.
	sala.casca = [modelo] if modelo != null else malhas
	add_child(sala)
	sala.global_transform = Transform3D(Basis.looking_at(-frente, Vector3.UP),
		centro + frente * ate_a_frente + Vector3.UP * chao_da_nave)
	_construcoes[qual] = {"sala": sala, "nome": str(dado["nome"])}


func _frente(ancora: String) -> Vector3:
	var frente: Vector3 = _mundo.ancoras.get(ancora + "Frente", Vector3.BACK)
	frente.y = 0.0
	return frente.normalized() if frente.length() > 0.01 else Vector3.BACK


## As malhas que formam a casca: as do modelo do Tripo, ou, no procedural, as
## do mundo que estão dentro do lote da construção (`meio_lote`: de lado, e de
## frente e fundo).
func _malhas_da_casca(modelo: Node3D, centro: Vector3, frente: Vector3, meio_lote: Vector2) -> Array:
	var lista: Array = []
	if modelo != null:
		for no in modelo.find_children("*", "MeshInstance3D", true, false):
			lista.append(no)
		return lista
	var lado := frente.cross(Vector3.UP).normalized()
	for no in _mundo.get_children():
		if not (no is MeshInstance3D):
			continue
		var onde: Vector3 = (no as MeshInstance3D).global_position - centro
		if absf(onde.dot(lado)) < meio_lote.x and absf(onde.dot(frente)) < meio_lote.y and onde.y > -0.5 and onde.y < 12.0:
			lista.append(no)
	return lista


## A MEDIDA DA CASCA, por dentro e pela fachada, em unidades a partir do centro
## da construção no chão. Raios contra uma colisão provisória da própria malha:
##
##   lado     metade da largura por dentro, à altura de um homem
##   frente   do centro até a parede da fachada, por dentro (o menor dos três
##            pontos do meio: a porta pintada costuma ser rebaixada)
##   fundo    do centro até a parede do fundo, por dentro
##   fachada  do centro até a face de FORA da fachada, no meio da porta
##   teto     a altura do beiral junto das paredes, por dentro
##   chao     a altura do chão da nave: o da casca, ou a soleira, o que for maior
##   soleira  a altura do patamar de FORA, na porta: o que o corpo pisa ao
##            chegar — no Tripo, o topo da escadaria de pedra que o vale põe
##            na frente da igreja; no procedural, o chão. Medido contra a
##            colisão do mundo, sem a caixa inteira que vai sair.
func _medir(malhas: Array, centro: Vector3, frente: Vector3, caixa_inteira: Node, dado: Dictionary) -> Dictionary:
	var corpo := StaticBody3D.new()
	corpo.name = "MedidaDaCasca"
	corpo.collision_layer = CAMADA_DE_MEDIR
	corpo.collision_mask = 0
	_mundo.add_child(corpo)
	for malha in malhas:
		var mi := malha as MeshInstance3D
		if mi.mesh == null:
			continue
		var forma := mi.mesh.create_trimesh_shape()
		if forma == null:
			continue
		forma.backface_collision = true
		var cs := CollisionShape3D.new()
		cs.shape = forma
		corpo.add_child(cs)
		cs.global_transform = mi.global_transform
	await get_tree().physics_frame
	await get_tree().physics_frame
	var espaco: PhysicsDirectSpaceState3D = _mundo.get_world_3d().direct_space_state
	var lado := frente.cross(Vector3.UP).normalized()
	# Onde fica a porta: `porta_x` é do meio para a direita de quem olha a
	# casa de frente, que é o +X do cômodo.
	var na_porta := Vector3.UP.cross(frente).normalized() * float(dado.get("porta_x", 0.0))
	var medida := {}
	var meio_1 := centro + Vector3.UP * 1.5
	var meio_2 := centro + Vector3.UP * 2.2
	var lado_mais := minf(_distancia(espaco, meio_1, lado), _distancia(espaco, meio_2, lado))
	var lado_menos := minf(_distancia(espaco, meio_1, -lado), _distancia(espaco, meio_2, -lado))
	medida["lado"] = minf(lado_mais, lado_menos)
	medida["fundo"] = minf(_distancia(espaco, meio_1, -frente), _distancia(espaco, meio_2, -frente))
	var frente_por_dentro := INF
	for x in [-0.5, 0.0, 0.5]:
		frente_por_dentro = minf(frente_por_dentro, _distancia(espaco, meio_1 + na_porta + lado * x, frente))
	medida["frente"] = frente_por_dentro
	# A face de fora da fachada, na porta, vinda de longe na direção do centro.
	var de_fora := meio_1 + na_porta + frente * 30.0
	var na_fachada := _raio(espaco, de_fora, meio_1 + na_porta)
	medida["fachada"] = (na_fachada - centro).dot(frente) if na_fachada.is_finite() else frente_por_dentro
	# O beiral, junto das paredes: o menor teto de três pontos de cada lado.
	var teto := INF
	for x in [-1.0, 1.0]:
		for z in [-0.5, 0.0, 0.5]:
			var ponto: Vector3 = centro + lado * x * (float(medida["lado"]) - 0.35) \
				+ frente * z * float(medida["fundo"]) + Vector3.UP * 1.0
			var acima := _raio(espaco, ponto, ponto + Vector3.UP * 30.0)
			if acima.is_finite():
				teto = minf(teto, acima.y - centro.y)
	medida["teto"] = teto if is_finite(teto) else 4.5
	# O chão: o da casca por dentro, e a soleira da escadaria pela frente.
	var de_cima := centro + Vector3.UP * 3.0
	var no_chao := _raio(espaco, de_cima, centro - Vector3.UP * 2.0)
	var chao_de_dentro: float = (no_chao.y - centro.y) if no_chao.is_finite() else 0.0
	var diante := centro + na_porta + frente * (float(medida["fachada"]) + 0.35) + Vector3.UP * float(dado.get("sonda", 8.0))
	var degrau := _raio(espaco, diante, diante - Vector3.UP * 12.0)
	var soleira: float = (degrau.y - centro.y) if degrau.is_finite() else 0.0
	medida["chao"] = clampf(maxf(chao_de_dentro, soleira), 0.0, 2.0)
	# O patamar de fora, contra a colisão do mundo (camada 1), um palmo além
	# da fachada — sem a caixa inteira da construção, que sai em seguida.
	var no_patamar := centro + na_porta + frente * (float(medida["fachada"]) + 0.3) + Vector3.UP * 4.0
	var pergunta := PhysicsRayQueryParameters3D.create(no_patamar, no_patamar - Vector3.UP * 10.0, 1)
	if caixa_inteira is CollisionObject3D:
		pergunta.exclude = [(caixa_inteira as CollisionObject3D).get_rid()]
	var patamar: Vector3 = espaco.intersect_ray(pergunta).get("position", Vector3.INF)
	medida["soleira"] = (patamar.y - centro.y) if patamar.is_finite() else \
		(_mundo.ground_height_at(no_patamar) - centro.y)
	# ONDE O PATAMAR ACABA, e o chão do adro logo depois: o alicerce de pedra em
	# que o vale assenta a igreja fica um palmo acima do adro, e a quina dele
	# trava o corpo. Raios de cima para baixo, saindo da fachada a cada cinco
	# dedos, até o chão cair abaixo do patamar. (Um raio deitado, de fora para
	# dentro, batia no cruzeiro, que fica na frente da igreja.)
	medida["borda"] = float(medida["fachada"])
	medida["terreno"] = float(medida["soleira"])
	var passo := 0.05
	while passo < 4.0:
		var ponto := centro + na_porta + frente * (float(medida["fachada"]) + passo)
		var altura := _altura_do_mundo(espaco, ponto, centro.y + float(medida["soleira"]), pergunta.exclude)
		if is_finite(altura) and altura < centro.y + float(medida["soleira"]) - 0.05:
			medida["borda"] = float(medida["fachada"]) + passo - 0.025
			break
		passo += 0.05
	if float(medida["borda"]) > float(medida["fachada"]):
		var no_pe := centro + na_porta + frente * (float(medida["borda"]) + 0.9)
		var no_adro := _altura_do_mundo(espaco, no_pe, centro.y + float(medida["soleira"]), pergunta.exclude)
		if is_finite(no_adro):
			medida["terreno"] = no_adro - centro.y
	# O CHÃO LIVRE na frente da porta, até o primeiro estorvo: raios deitados,
	# na altura do joelho e do peito, da fachada para fora.
	medida["livre"] = 3.0
	for altura in [0.3, 1.0]:
		var de: Vector3 = centro + na_porta + frente * (float(medida["fachada"]) + 0.05) \
			+ Vector3.UP * (float(medida["soleira"]) + altura)
		var adiante := PhysicsRayQueryParameters3D.create(de, de + frente * 3.0, 1)
		adiante.exclude = pergunta.exclude
		var estorvo: Vector3 = espaco.intersect_ray(adiante).get("position", Vector3.INF)
		if estorvo.is_finite():
			medida["livre"] = minf(float(medida["livre"]), (estorvo - de).dot(frente) + 0.05)
	corpo.queue_free()
	for chave in ["lado", "frente", "fundo"]:
		if not is_finite(float(medida[chave])) or float(medida[chave]) < 1.5:
			push_warning("Interiores: a casca da construção não mediu '%s' (%s); o cômodo não foi montado." % [chave, str(medida[chave])])
			return {}
	return medida


func _raio(espaco: PhysicsDirectSpaceState3D, de: Vector3, para: Vector3) -> Vector3:
	var pergunta := PhysicsRayQueryParameters3D.create(de, para, CAMADA_DE_MEDIR)
	pergunta.hit_back_faces = true
	return espaco.intersect_ray(pergunta).get("position", Vector3.INF)


## A altura do que se pisa neste ponto, na colisão do mundo (camada 1), de um
## metro acima de `ate` para baixo.
func _altura_do_mundo(espaco: PhysicsDirectSpaceState3D, ponto: Vector3, ate: float, fora: Array) -> float:
	var de_cima := Vector3(ponto.x, ate + 1.0, ponto.z)
	var pergunta := PhysicsRayQueryParameters3D.create(de_cima, de_cima - Vector3.UP * 4.0, 1)
	pergunta.exclude = fora
	var onde: Vector3 = espaco.intersect_ray(pergunta).get("position", Vector3.INF)
	return onde.y if onde.is_finite() else INF


func _distancia(espaco: PhysicsDirectSpaceState3D, de: Vector3, direcao: Vector3) -> float:
	var ponto := _raio(espaco, de, de + direcao * 30.0)
	return (ponto - de).dot(direcao) if ponto.is_finite() else INF


## TIRA A COLISÃO INTEIRA da construção: a caixa que o catálogo pôs no Tripo,
## ou, no procedural, os corpos das caixas da construção dentro do lote. O
## cômodo põe a dele no lugar.
func _tirar_a_colisao_inteira(caixa: Node, modelo: Node3D, centro: Vector3, frente: Vector3, medida: Dictionary) -> void:
	if modelo != null:
		if caixa != null:
			caixa.queue_free()
		return
	var lado := frente.cross(Vector3.UP).normalized()
	for no in _mundo.get_children():
		if not (no is StaticBody3D) or str(no.name) == "MedidaDaCasca":
			continue
		var onde: Vector3 = (no as StaticBody3D).global_position - centro
		if absf(onde.dot(lado)) <= float(medida["lado"]) + 0.6 \
				and onde.dot(frente) <= float(medida["fachada"]) + 0.6 \
				and onde.dot(frente) >= -float(medida["fundo"]) - 0.8 and onde.y < 12.0:
			no.queue_free()


## A CASCA SÓ POR FORA: material de dois lados desenharia a parede também de
## dentro, e o vão da porta mostraria o avesso da porta pintada em vez do adro.
## Só nesta construção, e com cópia do material, para não mexer em mais ninguém.
func _casca_so_por_fora(modelo: Node3D) -> void:
	for no in modelo.find_children("*", "MeshInstance3D", true, false):
		var mi := no as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var material := mi.get_active_material(i)
			if material is BaseMaterial3D and (material as BaseMaterial3D).cull_mode != BaseMaterial3D.CULL_BACK:
				var copia := (material as BaseMaterial3D).duplicate() as BaseMaterial3D
				copia.cull_mode = BaseMaterial3D.CULL_BACK
				mi.set_surface_override_material(i, copia)


## OS CORPOS NA LUZ DE DENTRO: as luzes do cômodo só acendem a camada dele e a
## dos corpos (ver `comodo.gd`). O jogador e os moradores entram nela,
## para a vela do altar iluminar quem chega perto dela.
func marcar_os_corpos() -> void:
	var corpos: Array = []
	if _jogador != null:
		corpos.append(_jogador)
	for morador in get_tree().get_nodes_in_group("moradores"):
		corpos.append(morador)
	for corpo in corpos:
		for no in (corpo as Node).find_children("*", "GeometryInstance3D", true, false):
			(no as GeometryInstance3D).layers |= Comodo.CAMADA_DOS_CORPOS
