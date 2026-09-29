extends SceneTree
## Confere AS FERRAMENTAS E ONDE BATER: o trabalho existe no vale.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/ferramentas.gd
##
## Até aqui a migração trouxe a regra do trabalho — `Energia`, `Inventario`,
## `Catalogo`, `Missoes` — e o vale não tinha em que bater. Esta fatia põe os
## alvos: troncos caídos e lajedos, do `data/recursos_3d.json`, montados com
## peças que o `CatalogoAssets` já tinha (`lenha`, `pedras`). Nenhum modelo
## novo foi preciso.
##
## Seis perguntas:
##
##   1. OS ALVOS ESTÃO NO MUNDO, e nos lugares que o `Lugares` resolve.
##   2. SEM FERRAMENTA NÃO SE BATE, e o jogo DIZ de qual precisa — recusa muda
##      é o que faz o jogador achar que o jogo travou.
##   3. COM A FERRAMENTA SE BATE, e cada golpe custa fôlego pela conta do 2D.
##   4. O ALVO CAI NO NÚMERO DE GOLPES DA FICHA, nem antes nem depois.
##   5. O QUE CAIU VIRA MATERIAL NA MOCHILA.
##   6. AS MISSÕES DE FERRAMENTA ENTREGAM O QUE PEDEM. O Pedro que manda
##      cortar lenha sem dar o machado é o defeito que o playtest do 2D
##      chamou de "o jogo conta e o jogador não recebe".

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("FERRAMENTAS_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK,
		"a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()

	var recursos := current_scene.get_node_or_null("Recursos3D")
	var inv := root.get_node_or_null("/root/Inventario")
	var energia := root.get_node_or_null("/root/Energia")
	_conferir(recursos != null, "o nó Recursos3D não foi criado")
	_conferir(inv != null and energia != null, "o inventário ou o fôlego não subiram")
	if recursos == null or inv == null or energia == null:
		_fechar()
		return

	# --- 1. OS ALVOS ESTÃO NO MUNDO ------------------------------------------
	_conferir(recursos.restantes() > 0,
		"nenhum alvo de trabalho foi posto: os lugares do JSON não resolveram")
	var troncos: int = recursos.restantes("lenha")
	var lajedos: int = recursos.restantes("pedra")
	_conferir(troncos > 0, "não há tronco para cortar")
	_conferir(lajedos > 0, "não há lajedo para quebrar")

	# Põe o jogador em cima do primeiro tronco, que é o que o teste precisa
	# para exercitar o golpe sem andar o mapa inteiro.
	var alvo_id := ""
	for id in recursos._alvos:
		if str(recursos._alvos[id]["ficha"].get("rende", "")) == "lenha":
			alvo_id = id
			break
	_conferir(alvo_id != "", "não achei um tronco para medir")
	if alvo_id == "":
		_fechar()
		return

	# O jogador do vale está no grupo "map_player" (é o minimapa que o usa) e
	# se chama "Jogador" na cena. O grupo é o caminho estável.
	var jogador := get_first_node_in_group("map_player")
	_conferir(jogador != null, "não achei o jogador")
	if jogador == null:
		_fechar()
		return
	jogador.global_position = recursos._alvos[alvo_id]["pos"]
	await _frames(3)
	_conferir(recursos._perto == alvo_id,
		"de cima do tronco, o alvo perto é '%s'" % recursos._perto)

	# --- 2. SEM FERRAMENTA NÃO SE BATE ---------------------------------------
	var recusas: Array[String] = []
	recursos.recusado.connect(func(motivo: String) -> void: recusas.append(motivo))
	_conferir(not inv.tem("machado"), "o teste começou com machado na mochila")
	_conferir(not recursos.bater(), "bateu sem machado")
	_conferir(recusas.size() == 1, "a recusa não avisou nada")
	if recusas.size() == 1:
		_conferir(recusas[0].to_lower().contains("machado"),
			"a recusa não disse de que ferramenta precisa: '%s'" % recusas[0])

	# --- 3 e 4. COM A FERRAMENTA SE BATE, E CAI NO NÚMERO CERTO --------------
	inv.adicionar("machado", 1)
	energia.encher()
	var golpes: int = int(recursos._alvos[alvo_id]["ficha"].get("golpes", 3))
	var lenha_antes: int = inv.quantidade("lenha")
	var folego_antes: float = energia.atual

	for i in range(golpes - 1):
		_conferir(recursos.bater(), "o golpe %d não saiu" % (i + 1))
		_conferir(recursos.restantes("lenha") == troncos,
			"o tronco caiu no golpe %d, antes da conta" % (i + 1))

	_conferir(energia.atual < folego_antes,
		"bater não gastou fôlego: %s → %s" % [str(folego_antes), str(energia.atual)])

	_conferir(recursos.bater(), "o golpe final não saiu")
	_conferir(recursos.restantes("lenha") == troncos - 1,
		"o tronco não caiu no golpe %d" % golpes)

	# --- 5. O QUE CAIU VIRA MATERIAL -----------------------------------------
	_conferir(inv.quantidade("lenha") > lenha_antes,
		"o tronco caiu e não deu lenha: %d" % inv.quantidade("lenha"))

	# --- 6. AS MISSÕES DE FERRAMENTA ENTREGAM O QUE PEDEM --------------------
	#
	# Lido do DADO, e não jogando o tutorial inteiro: a pergunta é aritmética.
	# Todo passo que pede um item numa `meta` do tipo "juntar" precisa que
	# alguém, nele ou antes dele, tenha entregado a ferramenta que produz esse
	# item — senão o Pedro manda cortar lenha e não dá machado.
	var arquivo := FileAccess.open("res://data/missoes_guia.json", FileAccess.READ)
	_conferir(arquivo != null, "não consegui ler missoes_guia.json")
	if arquivo != null:
		var dado = JSON.parse_string(arquivo.get_as_text())
		arquivo.close()
		var entregues: Array[String] = []
		var com_meta := 0
		for passo: Dictionary in dado.get("passos", []):
			for chave in passo.get("entrega", {}).keys():
				if chave == "item":
					entregues.append(str(passo["entrega"]["item"]))
			var meta: Dictionary = passo.get("meta", {})
			if meta.is_empty():
				continue
			com_meta += 1
			_conferir(str(meta.get("tipo", "")) == "juntar",
				"o passo '%s' tem meta de tipo desconhecido" % str(passo.get("id", "?")))
			var pedido := str(meta.get("item", ""))
			_conferir(Catalogo.ITENS.has(pedido),
				"o passo '%s' pede '%s', que não está no catálogo" % [str(passo.get("id", "?")), pedido])
			_conferir(not entregues.is_empty(),
				"o passo '%s' pede %s e nenhuma ferramenta foi entregada até aqui"
					% [str(passo.get("id", "?")), pedido])
		_conferir(com_meta >= 3, "só achei %d passo(s) com meta de trabalho" % com_meta)

	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("FERRAMENTAS_OK: os alvos estão no vale, sem a ferramenta o jogo recusa DIZENDO qual falta, com ela o golpe gasta fôlego, o alvo cai na conta certa e o material entra na mochila")
	else:
		print("ferramentas: %d falha(s)" % falhas)
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
