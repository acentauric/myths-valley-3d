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


## O RECEITUÁRIO DA BANCADA, lido do script do autoload e não pelo nome dele.
##
## `Oficina` é autoload, não `class_name`: escrever `Oficina.RECEITAS` aqui faz o
## Godot tentar compilar o oficina.gd como dependência DESTE script, antes de os
## autoloads existirem, e ele morre em "Identifier not found: Receitas" — que é o
## autoload que o oficina.gd consulta. Pegar o script do nó já compilado, como o
## portão dos achados faz com o AchadosVale, não tem esse problema.
var _receitas: Dictionary = {}


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
	var oficina := root.get_node_or_null("/root/Oficina")
	if oficina != null:
		_receitas = oficina.get_script().RECEITAS
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
	# SEM FERRAMENTA é mochila sem machado E mão sem machado: bater exige a
	# ferramenta NA MÃO, e não só carregada (`Recursos3D._tem_ferramenta`). O jogo
	# novo já começa sem ele (o machado é da ponte); tira-se das duas mesmo assim,
	# para a pergunta não depender de como o vale começa.
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

	# --- 2b. NA MOCHILA NÃO BASTA: A FERRAMENTA DO ALVO TEM DE ESTAR NA MÃO --
	#
	# "Na missão de introdução da foice eu consegui fazer a animação usando o
	# machado. Cada ferramenta tem seus pontos de interação e nenhuma deve
	# invadir a interação da outra." O alvo conferia a mochila: com a ferramenta
	# certa guardada e OUTRA na mão, o golpe saía com a outra no braço.
	inv.adicionar("machado", 1)
	inv.adicionar("foice", 1)
	for i in inv.ESPACOS_MAO:
		if str((inv.espacos[i] as Dictionary).get("id", "")) == "foice":
			inv.selecionar(i)
	_conferir(inv.na_mao() == "foice", "não consegui pôr a foice na mão para a pergunta da mão errada")
	recusas.clear()
	_conferir(not recursos.bater(), "com a foice na mão e o machado na mochila, o tronco apanhou")
	_conferir(recusas.size() == 1 and recusas[0].to_lower().contains("mão"),
		"a recusa da mão errada não diz para pôr a ferramenta na mão: %s" % str(recusas))
	# E O CASO DA QUEIXA, com ferramenta SEM encaixe: o machado já pedia a mão
	# antes; a foice e a picareta se contentavam com a mochila. Machado na mão,
	# foice guardada: o capim não é do machado.
	for i in inv.ESPACOS_MAO:
		if str((inv.espacos[i] as Dictionary).get("id", "")) == "machado":
			inv.selecionar(i)
	_conferir(inv.na_mao() == "machado", "não consegui pôr o machado na mão para a pergunta do capim")
	_conferir(not recursos._tem_ferramenta("foice"),
		"com o machado na mão e a foice na mochila, o capim aceita o golpe: uma ferramenta invade a outra")
	inv.selecionar(inv.MAO_LIVRE)
	while inv.tem("foice"):
		inv.consumir("foice", 1)
	while inv.tem("machado"):
		inv.consumir("machado", 1)

	# --- 3 e 4. COM A FERRAMENTA SE BATE, E CAI NO NÚMERO CERTO --------------
	# Na mão ativa da barra, escolhida por número, como o jogador faz.
	inv.adicionar("machado", 1)
	for i in inv.ESPACOS_MAO:
		if str((inv.espacos[i] as Dictionary).get("id", "")) == "machado":
			# O ENCAIXE DAS MÃOS É DAS LUVAS: "Armas são nos campos numerais."
			# O machado não veste as Mãos, nem pedindo o encaixe; vai na barra.
			_conferir(not equipamento.equipar_do_espaco(i) and not equipamento.equipar_do_espaco(i, "maos"),
				"o machado entrou no encaixe das Mãos, que é das luvas")
			inv.selecionar(i)
			break
	_conferir(not equipamento.e_equipamento("facao") and not equipamento.e_equipamento("machado_de_aco"),
		"o facão ou o machado de aço ainda vestem um encaixe: arma vai nos números")
	_conferir(inv.na_mao() == "machado",
		"o machado não está na mão: os golpes abaixo mediriam a recusa, não o golpe")
	energia.encher()
	var golpes: int = int(recursos._alvos[alvo_id]["ficha"].get("golpes", 3))
	var lenha_antes: int = inv.quantidade("lenha")
	var folego_antes: float = energia.atual

	for i in range(golpes - 1):
		_conferir(recursos.bater(), "o golpe %d não saiu" % (i + 1))
		_conferir(not recursos._golpe_pendente.is_empty(), "a peça foi atingida antes do golpe começar")
		_conferir(recursos.restantes("lenha") == troncos,
			"o tronco caiu no golpe %d, antes da conta" % (i + 1))
		await _esperar_golpe(recursos)

	_conferir(energia.atual < folego_antes,
		"bater não gastou fôlego: %s → %s" % [str(folego_antes), str(energia.atual)])

	_conferir(recursos.bater(), "o golpe final não saiu")
	_conferir(recursos.restantes("lenha") == troncos, "o tronco caiu antes do impacto do golpe final")
	await _esperar_golpe(recursos)
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
	# O QUE SE CATA NA MÃO, POR LUGAR: a galhada seca do terreiro dá a lenha da
	# primeira noite sem machado (o passo 'lenha' da chegada, no mesmo lugar); em
	# outro lugar a lenha é do machado. Por isso a ferramenta de quem rende fica
	# com a ferramenta, quando há as duas, e a mão vale só no lugar dela.
	var a_mao_no_lugar := {}
	for id in recursos._alvos:
		var ficha: Dictionary = recursos._alvos[id]["ficha"]
		var qual := str(ficha.get("ferramenta", ""))
		if str(ficha.get("rende", "")) != "":
			if qual != "" or not ferramenta_de_rende.has(str(ficha["rende"])):
				ferramenta_de_rende[str(ficha["rende"])] = qual
			if qual == "":
				var no_lugar: Array = a_mao_no_lugar.get(str(ficha.get("lugar", "")), [])
				no_lugar.append(str(ficha["rende"]))
				a_mao_no_lugar[str(ficha.get("lugar", ""))] = no_lugar
		if str(ficha.get("peca", "")) != "":
			ferramenta_de_peca[str(ficha["peca"])] = qual
		# O GRUPO TAMBÉM É NOME DE PEDIDO: o mato do cemitério é embaúba e
		# tronco caído, e o passo pede o grupo (`Recursos3D.derrubados`).
		if str(ficha.get("grupo", "")) != "":
			ferramenta_de_peca[str(ficha["grupo"])] = qual

	var moram_no_vale: Array[String] = []
	for morador in current_scene.get("moradores"):
		moram_no_vale.append(str((morador.dados as Dictionary).get("id", "")))
	# O GUIA TAMBÉM: o desembarque manda o jogador até o Pedro, e o vale o acha
	# pelo id (`prototype._achar_morador`), embora ele não seja dos moradores.
	if current_scene.get("pedro") != null:
		moram_no_vale.append("pedro")

	var metas_que_o_vale_sabe := ["juntar", "derrubar", "levar", "falar", "evento", "contar", "obra"]
	# O BAÚ DA CASA também dá: as ferramentas do finado — a enxada, o balde e a
	# maniva — esperam lá o passo da chegada que manda pegá-las, como no 2D.
	var do_bau: Dictionary = load("res://scripts/prototipo_3d/casa_do_jogador.gd").DO_FINADO
	var passos_com_meta := 0
	# AS FILAS VÊM DEPOIS DA CHEGADA (`depois_de`, docs/mundo/CHEGADA_E_MUTIROES.md):
	# o que o Pedro entregou — o machado, a picareta, a enxada — já está na mão de
	# quem chega nelas. A roça do Cosme abre no meio da chegada, depois da leira, e
	# a essa altura também já recebeu tudo isso.
	var entregues_pelo_guia: Array[String] = []
	# O MACHADO É DA PONTE (`prototype._ja_recebeu_o_machado`): as filas que pedem
	# madeira — o Damião, o Tonho, a carroça e o mirante, que espera a ponte
	# inteira — abrem depois dos machados do avô, e herdam o que a ponte entregou.
	# A ponte vem logo depois da chegada nesta lista para isso.
	var entregues_pela_ponte: Array[String] = []
	const DEPOIS_DO_MACHADO := ["missoes_coveiro", "missoes_tonho", "missoes_carroca", "missoes_arraial"]
	for nome in ["missoes_guia", "missoes_ponte", "missoes_coveiro", "missoes_filo", "missoes_zefa",
			"missoes_tonho", "missoes_candinha", "missoes_arraial", "missoes_roca", "missoes_carroca",
			"missoes_armas", "missoes_oficio", "missoes_capoeira", "missoes_metas", "missoes_chapada", "missoes_lombada", "missoes_fazenda"]:
		var texto := FileAccess.get_file_as_string("res://data/%s.json" % nome)
		_conferir(texto != "", "não consegui ler %s.json" % nome)
		var dado = JSON.parse_string(texto)
		_conferir(dado is Dictionary, "%s.json não é um objeto JSON" % nome)
		if not (dado is Dictionary):
			continue
		# O QUE JÁ FOI ENTREGADO ATÉ AQUI, na ordem dos passos: a ferramenta pode
		# vir no passo que cobra o trabalho ou em qualquer um antes dele.
		var entregues: Array[String] = []
		if nome != "missoes_guia":
			entregues = entregues_pelo_guia.duplicate()
		if nome in DEPOIS_DO_MACHADO:
			entregues.append_array(entregues_pela_ponte)
		for passo: Dictionary in dado.get("passos", []):
			var qual_passo := "%s/%s" % [nome, str(passo.get("id", "?"))]
			# A ENTREGA PODE SER UMA LISTA: a enxada E a maniva na mesma fala.
			var entregas: Array = passo.get("entrega") if passo.get("entrega") is Array else [passo.get("entrega", {})]
			for entrega in entregas:
				if not (entrega is Dictionary) or (entrega as Dictionary).is_empty():
					continue
				var dado_agora := str((entrega as Dictionary).get("item", ""))
				_conferir(Catalogo.ITENS.has(dado_agora),
					"o passo '%s' entrega '%s', que não está no catálogo" % [qual_passo, dado_agora])
				entregues.append(dado_agora)
				if nome == "missoes_guia":
					entregues_pelo_guia.append(dado_agora)
				elif nome == "missoes_ponte":
					entregues_pela_ponte.append(dado_agora)
			# QUEM PAGA e QUEM VEM AO MUTIRÃO moram no vale, e o mutirão só traz o
			# que o catálogo conhece.
			if str(passo.get("quem_paga", "")) != "":
				_conferir(moram_no_vale.has(str(passo["quem_paga"])),
					"o passo '%s' é pago por '%s', que não mora no vale" % [qual_passo, str(passo["quem_paga"])])
			var mutirao = passo.get("mutirao", {})
			_conferir(mutirao is Dictionary, "o mutirão do passo '%s' não é um objeto {quem: {item: quanto}}" % qual_passo)
			if mutirao is Dictionary:
				for quem in mutirao:
					_conferir(moram_no_vale.has(str(quem)),
						"o passo '%s' chama '%s' ao mutirão, e ele não mora no vale" % [qual_passo, str(quem)])
					for traz in (mutirao[quem] as Dictionary):
						_conferir(Catalogo.ITENS.has(str(traz)),
							"no mutirão do passo '%s', '%s' traz '%s', fora do catálogo" % [qual_passo, str(quem), str(traz)])
						entregues.append(str(traz))

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
					# Um item (`item`) ou vários (`itens`), como o material do mirante.
					for bruto in _carga_do_passo(meta):
						var pedido := str(bruto)
						_conferir(Catalogo.ITENS.has(pedido),
							"o passo '%s' pede '%s', que não está no catálogo" % [qual_passo, pedido])
						if do_bau.has(pedido):
							# Pegou do baú: dali em diante está na mão, como o que o
							# Pedro entrega.
							entregues.append(pedido)
							if nome == "missoes_guia":
								entregues_pelo_guia.append(pedido)
							continue
						# A RECEITA QUE O PRÓPRIO PASSO ENSINA (o facão das armas: a
						# porta dela é a abertura do passo, `abre.missao`).
						if _a_bancada_ensina(pedido, str(passo.get("id", "")), ferramenta_de_rende):
							continue
						_conferir(_da_no_vale(pedido, ferramenta_de_rende),
							"o passo '%s' pede '%s', que nenhum alvo posto no vale rende, a bancada não faz e o baú não tem"
								% [qual_passo, pedido])
						# A FERRAMENTA SÓ SE COBRA DE QUEM CAI DE ALVO: o que sai da
						# bancada sai de material, e o material já foi perguntado.
						var precisa := str(ferramenta_de_rende.get(pedido, ""))
						var na_mao_aqui: bool = (a_mao_no_lugar.get(str(passo.get("lugar", "")), []) as Array).has(pedido)
						_conferir(precisa == "" or na_mao_aqui or entregues.has(precisa),
							"o passo '%s' pede %s, que só sai de %s, e ninguém entregou a %s até aqui"
								% [qual_passo, pedido, precisa, precisa])
				"evento", "contar":
					var pedidos: Array = meta.get("eventos", []) if not (meta.get("eventos", []) as Array).is_empty() else [meta.get("evento", "")]
					for evento in pedidos:
						_conferir(_o_vale_avisa(str(evento)),
							"o passo '%s' espera o evento '%s', que o vale não avisa: o passo nunca fecha"
								% [qual_passo, str(evento)])
						# O QUE UM PASSO MANDOU COZINHAR, o jogador tem dali em diante:
						# a farinha da roça é o que o passo seguinte manda levar.
						if str(evento).begins_with("cozinhou:"):
							entregues.append(str(evento).trim_prefix("cozinhou:"))
				"obra":
					var obras_no := root.get_node("/root/Obras")
					var a_obra := str(meta.get("obra", ""))
					_conferir(not (obras_no.dados(a_obra) as Dictionary).is_empty(),
						"o passo '%s' cobra a obra '%s', que não existe" % [qual_passo, a_obra])
					_conferir(load("res://scripts/prototipo_3d/bancadas_vale.gd").OBRAS.has(str(meta.get("construcao", ""))),
						"o passo '%s' cobra obra em '%s', que não tem lugar de obra no vale" % [qual_passo, str(meta.get("construcao", ""))])
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
						var cobrada := _carga_do_passo(meta)
						_conferir(not cobrada.is_empty(),
							"o passo '%s' manda levar e não diz o quê" % qual_passo)
						for carga in cobrada:
							var qual_carga := str(carga)
							_conferir(Catalogo.ITENS.has(qual_carga),
								"o passo '%s' manda levar '%s', fora do catálogo" % [qual_passo, qual_carga])
							# ENTREGADO OU QUE O VALE DÊ A QUEM TRABALHA. A Dona
							# Candinha não dá a cana: pede a do roçado do jogador.
							# O Tonho não dá corda nem tábua: elas saem da bancada,
							# de lenha que cai de árvore. Exigir que alguém entregue
							# a carga reprovaria as duas missões que funcionam, e
							# não perguntar deixaria passar a que manda levar o que
							# não existe.
							_conferir(entregues.has(qual_carga) or _da_no_vale(qual_carga, ferramenta_de_rende),
								"o passo '%s' manda levar %s, que ninguém deu, nenhum alvo do vale rende e a bancada não faz"
									% [qual_passo, qual_carga])
	print("  passos com meta nas nove cadeias: %d" % passos_com_meta)
	_conferir(passos_com_meta >= 13,
		"só achei %d passo(s) com meta nas nove cadeias" % passos_com_meta)

	_fechar()


## OS ACONTECIMENTOS QUE O VALE AVISA às cadeias (`Prototype._avisar_as_cadeias`).
## Meta de evento que ninguém avisa é passo que nunca fecha. Os nomes fixos são os
## que o vale liga um a um; os de prefixo levam o id do que aconteceu, e o id tem
## de existir — "cozinhou:farinha" pede uma receita da cozinha chamada farinha.
const EVENTOS_FIXOS := ["abriu_arraial", "adotou_fe", "arou", "plantou", "regou", "colheu", "dormiu", "correu",
	"pescou", "esquivou", "tonteou", "destravou_talento", "abriu_painel"]

func _o_vale_avisa(evento: String) -> bool:
	if evento in EVENTOS_FIXOS:
		return true
	# ENTRAR NUM CÔMODO (a casa herdada, na chegada): o cômodo tem de existir.
	if evento.begins_with("entrou:"):
		var interiores = current_scene.get("interiores")
		return interiores != null and interiores.sala_de(evento.trim_prefix("entrou:")) != null
	if evento.begins_with("cozinhou:"):
		return not (root.get_node("/root/Cozinha").dados(evento.trim_prefix("cozinhou:")) as Dictionary).is_empty()
	if evento.begins_with("fabricou:"):
		return not (root.get_node("/root/Oficina").dados(evento.trim_prefix("fabricou:")) as Dictionary).is_empty()
	if evento.begins_with("comeu:"):
		return Catalogo.tipo(evento.trim_prefix("comeu:")) == "comida"
	# O COMBATE: o golpe tem de ser um que o `Luta` conhece, e o bicho, um do
	# caderno dos bichos.
	if evento.begins_with("acertou:"):
		return root.get_node("/root/Luta").GOLPES.has(evento.trim_prefix("acertou:"))
	if evento.begins_with("derrubou:"):
		var bichos = JSON.parse_string(FileAccess.get_file_as_string("res://data/colecionaveis/bichos.json"))
		return bichos is Dictionary and ((bichos as Dictionary).get("bichos", {}) as Dictionary).has(evento.trim_prefix("derrubou:"))
	if evento.begins_with("leu:"):
		var papeis = JSON.parse_string(FileAccess.get_file_as_string("res://data/documentos.json"))
		return papeis is Dictionary and (papeis as Dictionary).has(evento.trim_prefix("leu:"))
	return false


## O que a entrega cobra, na mesma leitura da `CadeiaDeMissoes`: `item` com
## `quantos` para uma coisa só, `itens` para várias.
func _carga_do_passo(meta: Dictionary) -> Dictionary:
	# O material de uma obra (`da_obra`): o do catálogo, sem abatimento.
	if str(meta.get("da_obra", "")) != "":
		return (root.get_node("/root/Obras").dados(str(meta["da_obra"])) as Dictionary).get("custo", {})
	var varios: Dictionary = meta.get("itens", {})
	if not varios.is_empty():
		return varios
	var um := str(meta.get("item", ""))
	return {} if um == "" else {um: int(meta.get("quantos", 1))}


## O VALE DÁ ESTE ITEM A QUEM TRABALHA? Ou cai de um alvo posto, ou sai da
## bancada de algo que cai de um alvo posto.
##
## É a pergunta que faltava. A rede do Tonho pede cinco cordas e três tábuas, e
## nenhuma das duas cai de nada: vêm de lenha, na oficina. Olhar só os alvos
## diria que a missão é impossível quando ela é a coisa mais comum do vale.
##
## A RECEITA TEM DE NASCER SABIDA. Missão que cobra material de receita trancada
## é um beco: o jogador junta a lenha e não tem o que fazer com ela. Tábua e
## corda nascem sabidas justamente por isto, e o comentário do `Oficina.RECEITAS`
## diz que é por causa desta rede.
## A bancada faz o item com a receita que o passo `passo` ensina ao abrir, e o
## material dela o vale dá.
func _a_bancada_ensina(item: String, passo: String, de_alvo: Dictionary) -> bool:
	var receita: Dictionary = _receitas.get(item, {})
	if str((receita.get("abre", {}) as Dictionary).get("missao", "")) != passo:
		return false
	for custo in (receita.get("custo", {}) as Dictionary):
		if not _da_no_vale(str(custo), de_alvo):
			return false
	return true


func _da_no_vale(item: String, de_alvo: Dictionary, fundo: int = 4) -> bool:
	if de_alvo.has(item):
		return true
	if fundo <= 0:
		return false
	var receita: Dictionary = _receitas.get(item, {})
	if receita.is_empty():
		return false
	if not bool((receita.get("abre", {}) as Dictionary).get("comeco", false)):
		return false
	for custo in (receita.get("custo", {}) as Dictionary):
		if not _da_no_vale(str(custo), de_alvo, fundo - 1):
			return false
	return true


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("FERRAMENTAS_OK: os alvos estão no vale, sem a ferramenta à mão o jogo recusa DIZENDO qual falta, com ela encaixada o golpe gasta fôlego, o alvo cai na conta certa e o material entra na mochila; e nas nove cadeias de missão toda meta é de um tipo que o vale sabe cumprir, todo acontecimento esperado é um que o vale avisa, todo material pedido sai de um alvo posto com a ferramenta entregue antes, e todo morador procurado, que paga ou que vem ao mutirão mora aqui")
	else:
		print("ferramentas: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _frames(count: int) -> void:
	for frame in range(count):
		await process_frame


## O golpe do `Recursos3D` leva 1,5 s de JOGO, e o jogo anda mais devagar que a parede
## quando o quadro passa de 50 ms (`max_physics_steps_per_frame`, project.godot): a
## janela de 2 s de relógio reprovava na bateria cheia, num portão que passa sozinho.
## A espera sai assim que o golpe acaba; o teto só pega o golpe que não acaba nunca.
func _esperar_golpe(recursos) -> void:
	var limite := Time.get_ticks_msec() + 40000
	while (not recursos._golpe_pendente.is_empty() or recursos._golpe_animando) and Time.get_ticks_msec() < limite:
		await process_frame
	_conferir(recursos._golpe_pendente.is_empty() and not recursos._golpe_animando,
		"o golpe animado não chegou ao impacto e ao fim do clipe")


func _mundo_pronto() -> void:
	for i in range(3000):
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
