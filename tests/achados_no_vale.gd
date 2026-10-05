extends SceneTree
## Confere que O QUE SE ACHA NO VALE ESTÁ AO ALCANCE DE QUEM ANDA.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/achados_no_vale.gd
##
## "Confira se os cordéis estão espalhados pelo mapa e acessíveis pelo jogador."
##
## O `achados_vale.gd` põe cada cordel num lugar do arraial — o balcão do
## armazém, o banco da capela, a ponta do píer — e é o mesmo trato do `Mundo` do
## 2D. O que ninguém media é se o jogador CHEGA neles.
##
## É a mesma pergunta que o `alcance_dos_alvos.gd` faz dos troncos e dos lajedos,
## e ela nasceu da mesma queixa: a missão da picareta ficou três rodadas quebrada
## porque o lajedo estava posto num lugar em que o corpo do jogador não cabia.
## Coisa colecionável tem o mesmo risco e é pior de notar — ninguém reclama do
## cordel que nunca viu.
##
## Seis perguntas:
##
##   1. TODO CORDEL DECLARADO FOI POSTO, ou está na lista dos que faltam COM A
##      RAZÃO. Sumir calado é o defeito que este portão existe para pegar.
##   2. CADA UM ESTÁ EM TERRA FIRME, e não dentro d'água nem no ar.
##   3. HÁ CHÃO LIVRE EM VOLTA. Cordel encravado entre paredes é cordel que se vê
##      e não se pega.
##   4. O JOGADOR CHEGA E O JOGO OFERECE. Posto o jogador ao lado, o `AchadosVale`
##      tem de reconhecer que há algo ali — é o que responde "acessível".
##   5. PEGAR GUARDA NA COLEÇÃO. O cordel não vai para a mochila: vai para o
##      caderno, e é assim no 2D ("coisa que se guarda na memória não entra na
##      mochila").
##   6. PENDE NUM BARBANTE, como na feira: dois mourões e a corda, o folheto à
##      altura de quem passa, com a capa dele para fora (`CapaDeCordel`) — e
##      nenhum dos mourões entra em coisa sólida (no cemitério ele fica entre
##      duas covas).
##   7. NENHUM MARCO DE FÉ TOMA O E DELE: os marcos entram na árvore depois e
##      recebem a tecla primeiro, e o cordel da capela velha ficava a três
##      palmos do lugar da reza — o E rezava, e o folheto não se pegava.
##
## OS ACHADOS DO JOGADOR NÃO SÃO TOCADOS: a coleção é persistida, e este portão
## guarda o que havia antes e devolve no fim.

var falhas := 0
const CapaDeCordel = preload("res://scripts/prototipo_3d/capa_de_cordel.gd")
## Chão livre exigido em volta, em unidades, e em quantas das oito direções.
const RAIO_LIVRE := 1.6
const LIVRES_MINIMO := 3

var _guardado: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("ACHADOS_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK,
		"a cena do vale carrega")
	await _frames(6)
	await _mundo_pronto()
	await _frames(6)

	var jogo := current_scene
	var world = jogo.get("world")
	var jogador = jogo.get("player")
	var colecao := root.get_node("/root/Colecao")
	var inventario := root.get_node("/root/Inventario")
	# O vale guarda o nó dos achados numa propriedade própria; procurá-lo por
	# nome na árvore seria depender de como ele foi batizado.
	var achados = jogo.get("achados")
	_conferir(achados != null, "o vale não montou o que se acha nele")
	if achados == null or world == null or jogador == null:
		_fechar()
		return
	_guardado = (colecao.achados as Dictionary).duplicate(true)

	var Achados = achados.get_script()

	# --- 1. TODO CORDEL DO CATÁLOGO ESTÁ POSTO OU DECLARADO AUSENTE ----------
	print("")
	var postos: Dictionary = Achados.CORDEIS
	var faltam: Dictionary = Achados.CORDEIS_QUE_FALTAM
	for bruto in colecao.ordem("cordeis"):
		var id := str(bruto)
		var no_vale: bool = postos.has(id)
		var declarado: bool = faltam.has(id)
		_conferir(no_vale or declarado,
			"o cordel '%s' existe no catálogo do 2D e não está nem posto no vale nem declarado ausente" % id)
		if declarado:
			_conferir(str(faltam[id]).length() > 20,
				"o cordel '%s' está declarado ausente sem razão escrita" % id)
	print("  cordéis: %d declarados no vale, %d declarados ausentes, %d no catálogo; já achados: %d; NO CHÃO AGORA: %d"
		% [postos.size(), faltam.size(), colecao.ordem("cordeis").size(),
			colecao.quantos("cordeis"), (achados.no_chao as Array).size()])

	# --- 2, 3, 4 e 5. CADA UM ESTÁ ONDE SE CHEGA ----------------------------
	var espaco: PhysicsDirectSpaceState3D = jogo.get_world_3d().direct_space_state
	# LÊ O QUE ESTÁ NO CHÃO, e não o que o cálculo devolve.
	#
	# A primeira versão perguntava `ponto_do_cordel(id)` de novo, e isso mede
	# outra coisa: aquela conta procura terra em volta da âncora e pode devolver
	# um ponto diferente do que foi usado na hora de pôr. O jogador não chega no
	# ponto calculado — chega no objeto.
	# A LISTA É COPIADA ANTES, porque pegar um cordel o TIRA dela. Percorrer
		# enquanto se esvazia pula os seguintes — meu laço media quatro de seis e
		# eu quase não vi.
	var no_chao_agora: Array = (achados.no_chao as Array).duplicate()
	# A física do jogador sai do caminho: posto num ponto do mirante ou da beira
	# d'água, ele cai ou é puxado para terra antes de o vale reparar nele, e a
	# medida seria feita longe do cordel.
	jogador.set_physics_process(false)
	for achado in no_chao_agora:
		if str(achado.get("tipo", "")) != "cordel":
			continue
		var id := str(achado["id"])
		var onde: Vector3 = achado["ponto"]
		_conferir(postos.has(id) or faltam.has(id),
			"há um cordel '%s' no chão que a lista do vale não declara" % id)

		# 2. EM TERRA FIRME — menos os que ficam em PISO de construção, como o da
		# ponta do píer: ali o chão é o tablado, e a água por baixo é o esperado.
		var no_piso: bool = bool((postos.get(id, {}) as Dictionary).get("piso", false))
		var em_terra: bool = world.is_on_land(onde)
		var fundo: float = world.water_depth_at(onde)
		_conferir(no_piso or (em_terra and fundo < 0.4),
			"o cordel '%s' está em %s: terra=%s, lâmina d'água=%.2f"
				% [id, str(onde.round()), str(em_terra), fundo])

		# 3. CHÃO LIVRE EM VOLTA.
		var livres := 0
		for i in 8:
			var giro := TAU * float(i) / 8.0
			var ponta := onde + Vector3(cos(giro), 0.0, sin(giro)) * RAIO_LIVRE
			var pergunta := PhysicsRayQueryParameters3D.create(
				onde + Vector3(0.0, 0.6, 0.0), ponta + Vector3(0.0, 0.6, 0.0))
			if espaco.intersect_ray(pergunta).is_empty():
				livres += 1
		_conferir(livres >= LIVRES_MINIMO,
			"o cordel '%s' tem só %d de 8 direções livres a %.1f u: encravado" % [id, livres, RAIO_LIVRE])

		# 6. NO BARBANTE, com a capa para fora.
		_conferir_o_barbante(achados, espaco, achado, id, onde)

		# 7. NENHUM MARCO TOMA O E DELE.
		var marcos = jogo.get("marcos")
		if marcos != null:
			var dono_do_e: String = marcos._mais_perto(onde)
			_conferir(dono_do_e == "",
				"o cordel '%s' fica debaixo do E do marco '%s': o E reza, e o folheto não se pega" % [id, dono_do_e])

		# 4. O JOGADOR CHEGA E O JOGO OFERECE.
		jogador.global_position = onde + Vector3(0.8, 0.0, 0.0)
		await _frames(4)
		var perto = achados.mais_perto()
		var oferece: bool = perto != null and str(perto.get("tipo", "")) == "cordel" \
			and str(perto.get("id", "")) == id

		_conferir(oferece,
			"ao lado do cordel '%s' o vale não oferece nada: ele está posto e não se pega" % id)

		# 5. PEGAR GUARDA NA COLEÇÃO, e não na mochila.
		if oferece:
			achados.interagir()
			await _frames(3)
			# O PRIMEIRO cordel vem com o aviso do que é um cordel
			# (`aviso_da_primeira_vez.gd`); fechado ele, o papel abre.
			var aviso = current_scene.get("aviso_da_primeira_vez")
			if aviso != null and aviso.aberto():
				aviso.fechar()
				await _frames(3)
			# O cordel achado abre no papel (#21): guardado, o próximo se pega.
			var folheto := root.get_node("/root/Folheto")
			_conferir(folheto.aberto, "peguei o cordel '%s' e ele não abriu no papel" % id)
			folheto.fechar()
			await _frames(2)
			_conferir(colecao.tem("cordeis", id),
				"peguei o cordel '%s' e ele não entrou na coleção" % id)
			_conferir(inventario.quantidade(id) == 0,
				"o cordel '%s' foi para a mochila: no 2D o que se guarda na memória não entra nela" % id)
		print("  %-22s %s  livres=%d/8  oferece=%s" % [id, str(onde.round()), livres, str(oferece)])
	jogador.set_physics_process(true)

	_fechar()


## O CORDEL PENDURADO: dois mourões e o barbante, o folheto à altura de quem
## passa, a capa dele na folha de fora, e os mourões fora de coisa sólida.
func _conferir_o_barbante(achados, espaco: PhysicsDirectSpaceState3D, achado: Dictionary, id: String, onde: Vector3) -> void:
	var suporte: Node3D = achado.get("no")
	var folheto = achado.get("folheto")
	_conferir(is_instance_valid(suporte) and folheto != null and is_instance_valid(folheto),
		"o cordel '%s' não está pendurado: não há folheto no barbante" % id)
	if not is_instance_valid(suporte) or folheto == null or not is_instance_valid(folheto):
		return
	var mouroes := suporte.find_children("Mourao*", "MeshInstance3D", false, false)
	var cordas := suporte.find_children("Barbante*", "MeshInstance3D", false, false)
	_conferir(mouroes.size() == 2 and cordas.size() >= 1,
		"o cordel '%s' não tem os dois mourões e a corda (%d mourões, %d pedaços de corda)" % [id, mouroes.size(), cordas.size()])
	var altura: float = (folheto as Node3D).global_position.y - onde.y
	_conferir(altura > 0.8 and altura < 1.4,
		"o folheto '%s' pende a %.2f do chão: fora da altura de quem passa" % [id, altura])
	# A CAPA DOS DOIS LADOS, com o título impresso: "mais bonito que essa folha em
	# branco" — o verso era papel liso, e quem chegava por ele via uma folha vazia.
	for lado in ["Capa", "CapaDeTras"]:
		var gravura := (folheto as Node3D).get_node_or_null("%s/Gravura" % lado) as MeshInstance3D
		var textura: Texture2D = null
		if gravura != null and gravura.material_override is StandardMaterial3D:
			textura = (gravura.material_override as StandardMaterial3D).albedo_texture
		_conferir(textura != null, "o folheto '%s' pende sem a gravura na folha '%s': quem chega por ali vê uma folha em branco" % [id, lado])
		if textura != null:
			var desenhada = CapaDeCordel.desenhada(id)
			_conferir(textura == (desenhada if desenhada != null else CapaDeCordel.bloco()),
				"o folheto '%s' pende com uma capa que não é a dele (%s)" % [id, lado])
		var titulo := (folheto as Node3D).get_node_or_null("%s/Titulo" % lado) as Label3D
		_conferir(titulo != null and titulo.text != "", "o folheto '%s' pende sem o título impresso na folha '%s'" % [id, lado])
	# O FOLHETO NÃO ESTÁ DENTRO DE COISA SÓLIDA: o do mirante ficava no meio da
	# caixa de colisão dele, e o portão, de corpo parado, não via.
	var dentro := PhysicsPointQueryParameters3D.new()
	dentro.position = onde + Vector3(0.0, 0.5, 0.0)
	dentro.collision_mask = 1
	var parede := ""
	for toque in espaco.intersect_point(dentro, 8):
		if toque.get("collider") is StaticBody3D:
			parede = str((toque["collider"] as Node).name)
	_conferir(parede == "",
		"o cordel '%s' está dentro de coisa sólida (%s) em %s: ninguém chega nele" % [id, parede, str(onde.round())])
	for mourao in mouroes:
		var pe: Vector3 = (mourao as Node3D).global_position
		_conferir(not achados.mourao_encosta(espaco, Vector3(pe.x, onde.y, pe.z), onde.y),
			"um mourão do cordel '%s' entra em coisa sólida em %s" % [id, str(pe.round())])


## Devolve a coleção como estava: este portão pega cordéis para provar que se
## pegam, e o que o jogador achou é dele.
func _devolver() -> void:
	var colecao := root.get_node_or_null("/root/Colecao")
	if colecao == null or _guardado.is_empty():
		return
	colecao.achados = _guardado.duplicate(true)


func _fechar() -> void:
	_devolver()
	print("")
	if falhas == 0:
		print("ACHADOS_OK: todo cordel do catálogo está posto no vale ou declarado ausente com a razão, cada um posto está em terra firme com chão livre em volta, pende num barbante com a capa dele e os mourões fora de coisa sólida, nenhum marco de fé toma o E dele, o vale oferece quando o jogador chega, e pegar guarda na coleção e não na mochila")
	else:
		print("achados: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _frames(count: int) -> void:
	for frame in range(count):
		await process_frame


func _mundo_pronto() -> void:
	for i in range(3000):
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
