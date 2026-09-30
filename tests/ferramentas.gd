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
	var equipamento := root.get_node_or_null("/root/Equipamento")
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
	# SEM FERRAMENTA MUDOU DE LUGAR. O vale passou a dar um machado de saída, e
	# bater passou a exigir a ferramenta ENCAIXADA e não só carregada
	# (`Recursos3D._tem_ferramenta`). Então "sem machado" não é mais mochila
	# vazia: é encaixe vazio. Tira-se das duas para poder perguntar.
	equipamento.desequipar("maos")
	while inv.tem("machado"):
		inv.consumir("machado", 1)
	_conferir(not inv.tem("machado") and equipamento.no_encaixe("maos") != "machado",
		"o teste começou com o machado à mão e não pode perguntar o que pergunta")
	_conferir(not recursos.bater(), "bateu sem machado")
	_conferir(recusas.size() == 1, "a recusa não avisou nada")
	if recusas.size() == 1:
		_conferir(recusas[0].to_lower().contains("machado"),
			"a recusa não disse de que ferramenta precisa: '%s'" % recusas[0])

	# --- 3 e 4. COM A FERRAMENTA SE BATE, E CAI NO NÚMERO CERTO --------------
	# NA MÃO, e não na mochila: é o que o vale cobra agora, e é o que a missão
	# faz por quem recebe a ferramenta (`CadeiaDeMissoes.entregar`).
	inv.adicionar("machado", 1)
	for i in inv.espacos.size():
		if str((inv.espacos[i] as Dictionary).get("id", "")) == "machado":
			_conferir(equipamento.equipar_do_espaco(i), "o machado não entrou no encaixe")
			break
	_conferir(equipamento.no_encaixe("maos") == "machado",
		"o machado não está na mão: os golpes abaixo mediriam a recusa, não o golpe")
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

	# --- 6. TODA MISSÃO IMPORTADA É CUMPRÍVEL --------------------------------
	#
	# Lido do DADO, e não jogando cada cadeia inteira: a pergunta é aritmética, e
	# é a que o playtest do 2D deixou escrita — "cortar lenha sem dar o machado".
	#
	# VARRE OS QUATRO ARQUIVOS, e não só o do tutorial. A versão estreita olhava
	# apenas o `missoes_guia.json` e deixou passar justamente o defeito que
	# existia para pegar: o passo `coveiro_cabo` pedia duas achas de lenha, não
	# entregava machado, e ficou impossível no dia em que bater passou a exigir a
	# ferramenta encaixada. Cada cadeia nova que chegar do 2D entra aqui sozinha.
	#
	# QUEM DIZ QUAL FERRAMENTA PRODUZ O QUÊ É O VALE, lido dos alvos postos: a
	# ficha de cada um traz `rende`, `peca` e `ferramenta`. Escrever a tabela
	# aqui seria tê-la em dois lugares, e o segundo envelheceria calado.
	var ferramenta_de_rende := {}
	var ferramenta_de_peca := {}
	for id in recursos._alvos:
		var ficha: Dictionary = recursos._alvos[id]["ficha"]
		var qual := str(ficha.get("ferramenta", ""))
		if str(ficha.get("rende", "")) != "":
			ferramenta_de_rende[str(ficha["rende"])] = qual
		if str(ficha.get("peca", "")) != "":
			ferramenta_de_peca[str(ficha["peca"])] = qual

	var moram_no_vale: Array[String] = []
	for morador in current_scene.get("moradores"):
		moram_no_vale.append(str((morador.dados as Dictionary).get("id", "")))

	var metas_que_o_vale_sabe := ["juntar", "derrubar", "levar", "falar"]
	var passos_com_meta := 0
	for nome in ["missoes_guia", "missoes_coveiro", "missoes_filo", "missoes_zefa"]:
		var texto := FileAccess.get_file_as_string("res://data/%s.json" % nome)
		_conferir(texto != "", "não consegui ler %s.json" % nome)
		var dado = JSON.parse_string(texto)
		_conferir(dado is Dictionary, "%s.json não é um objeto JSON" % nome)
		if not (dado is Dictionary):
			continue
		# O QUE JÁ FOI ENTREGADO ATÉ AQUI, na ordem dos passos: a ferramenta pode
		# vir no passo que cobra o trabalho ou em qualquer um antes dele.
		var entregues: Array[String] = []
		for passo: Dictionary in dado.get("passos", []):
			var qual_passo := "%s/%s" % [nome, str(passo.get("id", "?"))]
			var entrega: Dictionary = passo.get("entrega", {})
			if not entrega.is_empty():
				var dado_agora := str(entrega.get("item", ""))
				_conferir(Catalogo.ITENS.has(dado_agora),
					"o passo '%s' entrega '%s', que não está no catálogo" % [qual_passo, dado_agora])
				entregues.append(dado_agora)

			var meta: Dictionary = passo.get("meta", {})
			if meta.is_empty():
				continue
			passos_com_meta += 1
			var tipo := str(meta.get("tipo", ""))
			_conferir(tipo in metas_que_o_vale_sabe,
				"o passo '%s' tem meta de tipo '%s', que a CadeiaDeMissoes não sabe cumprir"
					% [qual_passo, tipo])
			match tipo:
				"juntar":
					var pedido := str(meta.get("item", ""))
					_conferir(Catalogo.ITENS.has(pedido),
						"o passo '%s' pede '%s', que não está no catálogo" % [qual_passo, pedido])
					_conferir(ferramenta_de_rende.has(pedido),
						"o passo '%s' pede '%s' e nenhum alvo posto no vale rende isso"
							% [qual_passo, pedido])
					var precisa := str(ferramenta_de_rende.get(pedido, ""))
					_conferir(precisa == "" or entregues.has(precisa),
						"o passo '%s' pede %s, que só sai de %s, e ninguém entregou a %s até aqui"
							% [qual_passo, pedido, precisa, precisa])
				"derrubar":
					var peca := str(meta.get("alvo", ""))
					_conferir(ferramenta_de_peca.has(peca),
						"o passo '%s' manda derrubar '%s' e o vale não pôs nenhum pé disso"
							% [qual_passo, peca])
					var corta := str(ferramenta_de_peca.get(peca, ""))
					_conferir(corta == "" or entregues.has(corta),
						"o passo '%s' manda derrubar %s sem que a %s tenha sido entregue"
							% [qual_passo, peca, corta])
				"levar", "falar":
					var quem := str(meta.get("a_quem", ""))
					_conferir(moram_no_vale.has(quem),
						"o passo '%s' manda procurar '%s', que não mora no vale: a missão trava"
							% [qual_passo, quem])
					if tipo == "levar":
						var carga := str(meta.get("item", ""))
						_conferir(Catalogo.ITENS.has(carga),
							"o passo '%s' manda levar '%s', fora do catálogo" % [qual_passo, carga])
						_conferir(entregues.has(carga),
							"o passo '%s' manda levar %s e ninguém deu o %s"
								% [qual_passo, carga, carga])
	print("  passos com meta nas quatro cadeias: %d" % passos_com_meta)
	_conferir(passos_com_meta >= 8,
		"só achei %d passo(s) com meta nas quatro cadeias" % passos_com_meta)

	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("FERRAMENTAS_OK: os alvos estão no vale, sem a ferramenta à mão o jogo recusa DIZENDO qual falta, com ela encaixada o golpe gasta fôlego, o alvo cai na conta certa e o material entra na mochila; e nas quatro cadeias de missão toda meta é de um tipo que o vale sabe cumprir, todo material pedido sai de um alvo posto com a ferramenta entregue antes, e todo morador procurado mora aqui")
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
