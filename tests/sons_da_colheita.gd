extends SceneTree
## O GOLPE TEM SOM: a pedra, o tronco, o capim e a ostra deixam de bater em silêncio.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/sons_da_colheita.gd
##
## Do playtest da Build 9B: "adicione o efeito sonoro de marretada na pedra e os
## demais faltantes". O `Recursos3D._aplicar_golpe` — o ponto onde a picareta bate
## na pedra, o machado no tronco caído, a foice no capim e a mão na ostra — não
## tinha uma chamada de áudio, e o `picareta.mp3` estava órfão: nenhuma linha do
## jogo o tocava. Só a árvore em pé tinha som (`arvores_info.gd`).
##
## Esta fatia usa SÓ o que já existe em `assets/audio/efeitos/`. O que o jogo
## precisa e ainda não tem arquivo fica na tabela `Recursos3D.SONS_DO_GOLPE` com o
## nome que o gerador de efeitos vai dar: no dia em que `marretada_pedra.mp3`
## existir, ele passa a tocar sozinho, sem tocar em código.
##
## Seis perguntas:
##
##   1. TODO ALVO TEM SOM, E O SOM EXISTE: para cada ficha do JSON o golpe resolve
##      para um arquivo que está na pasta — nada de nome que cai no vazio, como o
##      `menu_negado` da mochila, que nunca teve arquivo.
##   2. A PICARETA NA PEDRA SOA PICARETA, a cada golpe, inclusive o que quebra, e o
##      som sai pelo tocador de efeitos do `Audio` de verdade.
##   3. O MACHADO NO TRONCO SOA MACHADO, e a embaúba nova que cai faz o som da
##      árvore caindo, depois do golpe e sem cortá-lo.
##   4. A FOICE NO CAPIM TEM SOM (a colheita, até haver o da foice).
##   5. À MÃO, A OSTRA E O GALHO SECO TÊM SOM (o pegar).
##   6. SEM A FERRAMENTA NÃO HÁ GOLPE E NÃO HÁ SOM: a recusa é muda.
##
## FALSIFICAÇÃO: tire a chamada de `_tocar_o_golpe` do `_aplicar_golpe` do
## `recursos_3d.gd`: as perguntas 2 a 5 reprovam.
##
## A espera do golpe é em segundo DE JOGO (`tests/fixtures/relogio_de_jogo.gd`).

const RelogioDeJogo = preload("res://tests/fixtures/relogio_de_jogo.gd")
const PASTA_DOS_SONS := "res://assets/audio/efeitos/"

var falhas := 0
var relogio: Node
## O que o `Recursos3D` tocou, na ordem: {nome, ultimo, no_tocador}.
var tocados: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("SONS_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	relogio = RelogioDeJogo.new()
	root.add_child(relogio)
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(6)
	relogio.ficar_lento()

	var vale := current_scene
	var jogador = vale.get("player")
	var recursos := vale.get_node_or_null("Recursos3D")
	var inv := root.get_node("/root/Inventario")
	var energia := root.get_node("/root/Energia")
	var audio := root.get_node("/root/Audio")
	_conferir(recursos != null and jogador != null, "o vale não montou o jogador ou os alvos de trabalho")
	if recursos == null or jogador == null:
		_fechar()
		return
	var dado = JSON.parse_string(FileAccess.get_file_as_string("res://data/recursos_3d.json"))
	_conferir(dado is Dictionary, "data/recursos_3d.json não é um objeto JSON")
	if not (dado is Dictionary):
		_fechar()
		return

	# --- 1. TODO ALVO TEM SOM, E O SOM EXISTE ------------------------------------------
	var usados := {}
	for ficha: Dictionary in dado.get("recursos", []):
		var id := str(ficha.get("id", ""))
		var golpe: String = recursos.som_do_golpe(ficha, false)
		_conferir(golpe != "" and _existe(golpe), "o golpe de '%s' resolve para '%s', que não é um arquivo em %s" % [id, golpe, PASTA_DOS_SONS])
		usados[golpe] = true
		var fim: String = recursos.som_do_golpe(ficha, true)
		# "" é o último soar como os outros — e só vale se o golpe comum existe.
		if fim != "":
			_conferir(_existe(fim), "o último golpe de '%s' resolve para '%s', que não é um arquivo" % [id, fim])
			usados[fim] = true
	_conferir(usados.has("picareta") or usados.has("marretada_pedra"), "nenhum alvo toca a picareta: o arquivo continua órfão")
	var esperam: Array = recursos.sons_que_faltam()
	print("  sons usados hoje: %s" % ", ".join(PackedStringArray(usados.keys())))
	print("  AINDA SEM ARQUIVO (a tabela já os espera, e passam a tocar sozinhos quando existirem): %s" % ", ".join(PackedStringArray(esperam)))

	recursos.golpe_sonoro.connect(func(nome: String, ultimo: bool) -> void:
		var tocador := ""
		var stream = audio._efeitos.stream
		if stream != null:
			tocador = str(stream.resource_path).get_file().get_basename()
		tocados.append({"nome": nome, "ultimo": ultimo, "no_tocador": tocador, "tocando": bool(audio._efeitos.playing)}))

	# --- 6. SEM A FERRAMENTA NÃO HÁ GOLPE E NÃO HÁ SOM (a mão livre, a pedra solta) ----
	inv.selecionar(inv.MAO_LIVRE)
	var da_pedra := "pedra_poco"
	_conferir(recursos._alvos.has(da_pedra), "o alvo '%s' não foi posto" % da_pedra)
	if not recursos._alvos.has(da_pedra):
		_fechar()
		return
	await _ir(jogador, recursos, da_pedra)
	energia.encher()
	tocados.clear()
	# Uma lista, e não um bool: a lambda copia o que é simples, e a lista é a mesma.
	var recusas: Array[String] = []
	recursos.recusado.connect(func(motivo: String) -> void: recusas.append(motivo))
	_conferir(not recursos.bater(), "a pedra solta apanhou sem a picareta")
	await _frames(3)
	_conferir(recusas.size() == 1 and tocados.is_empty(),
		"sem a picareta o golpe recusou %d vez(es) (%s) e mesmo assim tocou %s" % [recusas.size(), str(recusas), str(tocados)])

	# --- 2. A PICARETA NA PEDRA SOA PICARETA ---------------------------------------------
	_por_na_mao(inv, "picareta")
	var golpes_da_pedra := int(recursos._alvos[da_pedra]["ficha"].get("golpes", 2))
	var esperado_pedra: String = recursos.som_do_golpe(recursos._alvos[da_pedra]["ficha"], false)
	for i in golpes_da_pedra:
		energia.encher()
		tocados.clear()
		_conferir(recursos.bater(), "o golpe %d da pedra solta não saiu" % (i + 1))
		await relogio.ate(func() -> bool: return relogio.golpe_acabou(recursos), 6.0)
		_conferir(not tocados.is_empty(), "o golpe %d da picareta na pedra solta foi mudo" % (i + 1))
		if tocados.is_empty():
			continue
		var primeiro: Dictionary = tocados[0]
		_conferir(primeiro["nome"] == esperado_pedra, "o golpe %d na pedra tocou '%s', e devia tocar '%s'" % [i + 1, str(primeiro["nome"]), esperado_pedra])
		_conferir(primeiro["no_tocador"] == esperado_pedra and bool(primeiro["tocando"]),
			"o golpe %d na pedra pôs '%s' no tocador de efeitos (tocando=%s): o Audio não recebeu o som" % [i + 1, str(primeiro["no_tocador"]), str(primeiro["tocando"])])
		_conferir(bool(primeiro["ultimo"]) == (i == golpes_da_pedra - 1), "o golpe %d da pedra saiu marcado como último=%s" % [i + 1, str(primeiro["ultimo"])])
	_conferir(not recursos._alvos.has(da_pedra), "a pedra solta não quebrou nos %d golpes" % golpes_da_pedra)

	# --- 3. O MACHADO NO TRONCO SOA MACHADO, E A EMBAÚBA QUE CAI FAZ A QUEDA -------------
	var da_embauba := "embauba_cemiterio_a"
	if recursos._alvos.has(da_embauba):
		_por_na_mao(inv, "machado")
		await _ir(jogador, recursos, da_embauba)
		var golpes_da_embauba := int(recursos._alvos[da_embauba]["ficha"].get("golpes", 3))
		var ficha_embauba: Dictionary = recursos._alvos[da_embauba]["ficha"]
		for i in golpes_da_embauba:
			energia.encher()
			tocados.clear()
			_conferir(recursos.bater(), "o golpe %d da embaúba não saiu" % (i + 1))
			await relogio.ate(func() -> bool: return relogio.golpe_acabou(recursos), 6.0)
			_conferir(not tocados.is_empty() and tocados[0]["nome"] == recursos.som_do_golpe(ficha_embauba, false),
				"o golpe %d da embaúba tocou %s, e devia tocar '%s'" % [i + 1, str(tocados), recursos.som_do_golpe(ficha_embauba, false)])
			if i == golpes_da_embauba - 1:
				# A queda soa DEPOIS do golpe, e não no lugar dele.
				var caida: String = recursos.som_do_golpe(ficha_embauba, true)
				_conferir(caida != "", "a embaúba que cai não tem som de queda")
				await relogio.ate(func() -> bool: return tocados.size() >= 2, 3.0)
				_conferir(tocados.size() >= 2 and tocados[1]["nome"] == caida and tocados[1]["ultimo"],
					"depois do último golpe a embaúba devia tocar '%s' e tocou %s" % [caida, str(tocados)])
	else:
		_conferir(false, "o alvo '%s' não foi posto" % da_embauba)

	# --- 4. A FOICE NO CAPIM TEM SOM --------------------------------------------------------
	var do_capim := "capim_cemiterio_a"
	if recursos._alvos.has(do_capim):
		_por_na_mao(inv, "foice")
		await _ir(jogador, recursos, do_capim)
		var ficha_capim: Dictionary = recursos._alvos[do_capim]["ficha"]
		energia.encher()
		tocados.clear()
		_conferir(recursos.bater(), "o golpe da foice no capim não saiu")
		await relogio.ate(func() -> bool: return relogio.golpe_acabou(recursos), 6.0)
		_conferir(not tocados.is_empty() and tocados[0]["nome"] == recursos.som_do_golpe(ficha_capim, false) and tocados[0]["no_tocador"] == tocados[0]["nome"],
			"o golpe da foice no capim tocou %s, e devia tocar '%s'" % [str(tocados), recursos.som_do_golpe(ficha_capim, false)])
	else:
		_conferir(false, "o alvo '%s' não foi posto" % do_capim)

	# --- 5. À MÃO, A OSTRA E O GALHO SECO TÊM SOM ----------------------------------------------
	inv.selecionar(inv.MAO_LIVRE)
	for id in ["ostra_pedras_a", "lenha_casa_taipa"]:
		if not recursos._alvos.has(id):
			_conferir(false, "o alvo '%s' não foi posto" % id)
			continue
		await _ir(jogador, recursos, id)
		var ficha: Dictionary = recursos._alvos[id]["ficha"]
		energia.encher()
		tocados.clear()
		_conferir(recursos.bater(), "o golpe à mão em '%s' não saiu" % id)
		await _frames(2)
		_conferir(not tocados.is_empty() and tocados[0]["nome"] == recursos.som_do_golpe(ficha, false) and tocados[0]["no_tocador"] == tocados[0]["nome"],
			"o golpe à mão em '%s' tocou %s, e devia tocar '%s'" % [id, str(tocados), recursos.som_do_golpe(ficha, false)])

	_fechar()


func _existe(nome: String) -> bool:
	return ResourceLoader.exists(PASTA_DOS_SONS + nome + ".mp3")


## Põe o jogador no alvo (o `_mais_perto` do `Recursos3D` o devolve de cima dele).
func _ir(jogador, recursos, id: String) -> void:
	jogador.global_position = recursos._alvos[id]["pos"]
	# O CARTÃO DA PRIMEIRA VEZ (a árvore do almanaque, ao cortar a embaúba) para a árvore
	# inteira, e o alvo perto não se refaz com o vale parado: fecha, como o jogador faria.
	var aviso = current_scene.get("aviso_da_primeira_vez")
	for i in 6:
		if aviso != null and aviso.aberto():
			aviso.fechar()
		await process_frame
	await _frames(4)
	_conferir(recursos._perto == id, "de cima de '%s', o alvo perto é '%s'" % [id, recursos._perto])


## Põe o item na mão pela barra, como o jogador faz.
func _por_na_mao(inv, id: String) -> void:
	if not inv.tem(id):
		inv.adicionar(id, 1)
	for i in inv.ESPACOS_MAO:
		if str((inv.espacos[i] as Dictionary).get("id", "")) == id:
			if inv.selecionado != i:
				inv.selecionar(i)
			return


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("SONS_OK: todo alvo de trabalho resolve para um som que existe na pasta; a picareta na pedra toca picareta a cada golpe pelo tocador de efeitos do Audio; o machado toca machado e a embaúba que cai faz o som da queda depois; a foice no capim e a mão na ostra e no galho têm som; e sem a ferramenta o golpe recusa e fica mudo")
	else:
		print("sons da colheita: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _mundo_pronto() -> void:
	for i in 3000:
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
