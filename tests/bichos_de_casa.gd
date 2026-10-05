extends SceneTree
## Confere os BICHOS DE CASA do vale (#28): cães, gatos, porcos, cabras, o jumento
## e os bandos de aves do quintal e do adro, pelo `data/bichos_de_casa.json`.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/bichos_de_casa.gd
##
## O que este portão pergunta:
##
##   1. QUEM MORA ONDE: cão caramelo no Pedro, no Tonho e no Benedito; gatos na
##      Venda, no Restaurante e em outras casas; galinhas em 5 casas ou mais,
##      d'angola na Zefa; porcos no chiqueiro, cabras e bode no terreiro do
##      Benedito, jumento na Venda, patos no riacho, pavão e três pavoas no adro.
##      Toda casa do JSON existe no vale (nada foi pulado).
##   2. FORA DA CAMADA 1: nenhum corpo de bicho barra o jogador ou a câmera
##      (camada 0, máscara 1), e as aves não têm física nenhuma.
##   3. CADA UM NO SEU CHÃO: em terra, na altura do chão, seco, fora da caixa da
##      casa; todo terreiro acha pelo menos seis pontos de ave.
##   4. O DIA DO CÃO: de dia segue o dono (e chega a menos de 2,6 u dele), na
##      sesta deita na porta, de noite deita na porta e troca para o GLB deitado.
##   5. O GATO FOGE DO CÃO e o porco fica no chiqueiro.
##   6. O BANDO: ao entardecer sobe no poleiro, às sete está no chão de novo, de
##      dia cisca dentro do terreiro, o pavão abre o leque (troca de modelo) e o
##      bando é espantado por quem chega perto.
##   7. O NÍVEL DE DETALHE: a 80 u o bicho some, com histerese; a 26 u ele deixa a
##      física (o `move_and_slide` custa mais que o resto e uma vila de bichos
##      estouraria o quadro) e anda pelo chão do vale, e também chega ao dono.
##   8. NOS DOIS ESTILOS: no Tripo o corpo é o GLB do catálogo; no procedural, a
##      caixa — `bichos_de_casa_procedural.gd` roda o mesmo portão.
##
## FALSIFICAÇÃO: com `--falsificar-bichos` um cão passa para a camada 1 e uma
## galinha vai para dentro de uma casa; os dois testes têm de FALHAR.

var falhas := 0
var falsificar := false
var dia


func _estilo_do_portao() -> String:
	return "tripo"


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("BICHOS_DE_CASA_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	falsificar = "--falsificar-bichos" in OS.get_cmdline_user_args()
	var tripo := _estilo_do_portao() == "tripo"
	root.get_node("/root/Estilo").modo = _estilo_do_portao()
	dia = root.get_node("/root/Dia")
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "o vale não carregou")
	await _frames(6)
	await _mundo_pronto()
	var vale = current_scene
	var world = vale.world
	var player = vale.player
	var gerente: Node = null
	for i in 3000:
		gerente = vale.get_node_or_null("BichosDeCasa")
		if gerente != null and gerente.bichos.size() > 0 and gerente.bandos.size() > 0:
			break
		await process_frame
	_conferir(gerente != null, "o vale não criou o BichosDeCasa")
	if gerente == null:
		_fechar()
		return
	await _frames(10)
	dia.pausado = true
	# O nível de detalhe é do teste: ele diz quem está perto. Longe da câmera o
	# bicho não anda (nem cai pelo chão que a vila ainda não tem): todos longe, de
	# noite — cada um em casa, cada ave no galho —, para conferir o chão.
	gerente.set_process(false)
	for b in gerente.bichos:
		b.perto = false
		b.fisica = true
	for bando in gerente.bandos:
		bando.perto = false
	dia.definir_hora(21.0)
	await create_timer(0.6).timeout
	await _fisica(10)

	# --- 1. QUEM MORA ONDE -----------------------------------------------------
	_conferir(gerente.casas_puladas.is_empty(), "casas do JSON sem âncora no vale: %s" % str(gerente.casas_puladas))
	print("BICHOS: %d corpos de quatro patas, %d bandos · %s" % [gerente.bichos.size(), gerente.bandos.size(), gerente.contagem()])
	for casa in ["Casa do Pedro", "Casa da estrada", "Casa de Carro Quebrado"]:
		_conferir(_da_casa(gerente, casa, "cachorro_caramelo").size() >= 1, "%s não tem cão caramelo" % casa)
	var com_gato := {}
	for b in gerente.bichos:
		if b.chave.begins_with("gato"):
			com_gato[b.casa] = true
	_conferir(com_gato.size() >= 2 and com_gato.has("Venda do Bar") and com_gato.has("Restaurante"),
		"gatos só em %s (deviam estar na Venda, no Restaurante e em mais casas)" % str(com_gato.keys()))
	var com_galinha := 0
	for bando in gerente.bandos:
		var n := 0
		for ave in bando.aves:
			n += 1 if ave["chave"] == "galinha" else 0
		com_galinha += 1 if n >= 2 else 0
	_conferir(com_galinha >= 5, "galinhas em %d casas (mínimo 5)" % com_galinha)
	_conferir(_aves_da_casa(gerente, "Casa da Zefa", "galinha_dangola").size() >= 4, "a Zefa não tem as galinhas-d'angola")
	_conferir(_da_casa(gerente, "Casa de Carro Quebrado", "porco").size() >= 2 and _da_casa(gerente, "Casa de Carro Quebrado", "leitao").size() >= 1, "faltam os porcos e o leitão no chiqueiro")
	_conferir(_da_casa(gerente, "Casa de Carro Quebrado", "cabra_solta").size() >= 2 and _da_casa(gerente, "Casa de Carro Quebrado", "bode").size() >= 1, "faltam as cabras e o bode no terreiro do Benedito")
	_conferir(_da_casa(gerente, "Venda do Bar", "jumento").size() >= 1, "o vendeiro não tem o jumento")
	_conferir(_aves_da_casa(gerente, "Ponte do rio central", "pato").size() >= 3, "faltam os patos no riacho")
	_conferir(_aves_da_casa(gerente, "Igreja", "pavao").size() == 1 and _aves_da_casa(gerente, "Igreja", "pavoa").size() >= 3, "o adro da Igreja não tem o pavão e as pavoas")
	# O porco fica longe da praça, e a onça-preta não é de casa: o chiqueiro do Benedito.
	for porco in _da_casa(gerente, "Casa de Carro Quebrado", "porco"):
		_conferir(_plano(porco.global_position - world.ancoras.get("Praça", Vector3.ZERO)).length() > 8.0, "o porco está na praça")

	# --- 2. FORA DA CAMADA 1 ---------------------------------------------------
	if falsificar and not gerente.bichos.is_empty():
		gerente.bichos[0].collision_layer = 1
	for b in gerente.bichos:
		_conferir(b.collision_layer == 0 and b.collision_mask == 1, "o %s da %s barra a câmera (camada %d)" % [b.chave, b.casa, b.collision_layer])
	for bando in gerente.bandos:
		_conferir(bando.find_children("*", "CollisionObject3D", true, false).is_empty(), "o bando da %s tem corpo físico" % bando.casa)

	# --- 3. CADA UM NO SEU CHÃO ------------------------------------------------
	if falsificar and not gerente.bandos.is_empty():
		var casa_alvo := _caixa_de_casa("Casa de Carro Quebrado")
		if casa_alvo != null:
			gerente.bandos[0].aves[0]["no"].global_position = casa_alvo.global_position
	for b in gerente.bichos:
		_conferir(world.is_on_land(b.global_position), "o %s da %s nasceu fora de terra" % [b.chave, b.casa])
		_conferir(absf(b.global_position.y - world.ground_height_at(b.global_position)) < 1.2, "o %s da %s está fora do chão" % [b.chave, b.casa])
		_conferir(not _molhado(world, b.global_position), "o %s da %s nasceu na água" % [b.chave, b.casa])
		_conferir(not _dentro_de_casa(b.global_position, 0.0), "o %s da %s nasceu dentro de uma casa" % [b.chave, b.casa])
	for bando in gerente.bandos:
		_conferir(bando.pontos.size() >= 6, "o terreiro da %s achou só %d pontos de ave" % [bando.casa, bando.pontos.size()])
		for ave in bando.aves:
			var p: Vector3 = ave["no"].global_position
			_conferir(not _dentro_de_casa(p, 0.0), "uma %s do bando da %s está dentro de uma casa" % [ave["chave"], bando.casa])
			_conferir(absf(p.y - world.ground_height_at(p)) < 1.2 or ave["no_poleiro"], "uma %s do bando da %s está fora do chão" % [ave["chave"], bando.casa])
			if tripo:
				_conferir(ave["modelo"].find_child("Caixa", true, false) == null, "a %s vestiu a caixa no estilo Tripo" % ave["chave"])
			else:
				_conferir(ave["modelo"].name == "Caixa" or ave["modelo"].find_child("Caixa", true, false) != null, "a %s não é a caixa no procedural" % ave["chave"])
	for b in gerente.bichos:
		var caixa_do_bicho: Node = b._de_pe.find_child("Caixa", true, false) if b._de_pe.name != "Caixa" else b._de_pe
		if tripo:
			_conferir(caixa_do_bicho == null, "o %s da %s vestiu a caixa no estilo Tripo" % [b.chave, b.casa])
		else:
			_conferir(caixa_do_bicho != null, "o %s da %s não é a caixa no procedural" % [b.chave, b.casa])
	dia.definir_hora(10.0)
	await _fisica(4)

	# Os donos: o morador existe (Pedro, Tonho, Benedito) e o bicho o encontrou.
	for i in 400:
		if not gerente._sem_dono:
			break
		gerente._ligar_os_donos()
		await process_frame
	for casa in ["Casa do Pedro", "Casa da estrada", "Casa de Carro Quebrado"]:
		for cao in _da_casa(gerente, casa, "cachorro_caramelo"):
			_conferir(cao.dono != null and is_instance_valid(cao.dono), "o cão da %s não achou o dono (%s)" % [casa, str(cao.dados.get("dono", ""))])

	# --- 4. O DIA DO CÃO -------------------------------------------------------
	var cao = _da_casa(gerente, "Casa de Carro Quebrado", "cachorro_caramelo")[0]
	var filhote = _da_casa(gerente, "Casa de Carro Quebrado", "filhote_caramelo")[0]
	var porta: Vector3 = cao.lugar_de_casa()
	for b in gerente.bichos:
		b.perto = false
	cao.perto = true
	cao.global_position = porta
	cao._parado = 0.0
	var frente: Vector3 = world.ancoras.get("Casa de Carro QuebradoFrente", Vector3.BACK)
	var dono := Node3D.new()
	vale.add_child(dono)
	dono.global_position = world.ground_position(porta + frente * 7.0, 0.0)
	cao.dono = dono
	dia.definir_hora(9.0)
	await _fisica(300)
	var d := _plano(cao.global_position - dono.global_position).length()
	_conferir(cao.fazendo == "acompanha" and d < 2.6, "de manhã o cão não está junto do dono: faz '%s' a %.1f u" % [cao.fazendo, d])
	_conferir(not cao.deitado, "o cão acompanha o dono deitado")
	# Sem física (a câmera vê de longe) ele também chega ao dono, e não pisa em água funda.
	cao.fisica = false
	cao.global_position = porta
	cao.velocity = Vector3.ZERO
	await _fisica(420)
	d = _plano(cao.global_position - dono.global_position).length()
	_conferir(d < 2.6, "sem física o cão não chegou ao dono: a %.1f u" % d)
	_conferir(not _molhado(world, cao.global_position) and not _dentro_de_casa(cao.global_position, 0.0), "sem física o cão pisou na água ou entrou em casa")
	_conferir(absf(cao.global_position.y - world.ground_height_at(cao.global_position)) < 1.2, "sem física o cão saiu do chão")
	cao.fisica = true
	# A sesta: deita na porta, e o GLB deitado entra no lugar do de pé.
	dia.definir_hora(13.0)
	await _fisica(900)
	_conferir(_plano(cao.global_position - porta).length() < 1.5, "na sesta o cão não voltou à porta (%.1f u)" % _plano(cao.global_position - porta).length())
	_conferir(cao.deitado, "na sesta o cão não deitou")
	if tripo:
		_conferir(cao._deitado != null and cao._deitado.visible and not cao._de_pe.visible, "o cão deitado não trocou para o modelo deitado")
	# De tarde, depois da sesta, levanta e segue o dono de novo.
	dia.definir_hora(15.0)
	await _fisica(300)
	_conferir(not cao.deitado and cao.fazendo == "acompanha", "às três o cão não levantou para seguir o dono ('%s')" % cao.fazendo)
	# De noite deita na porta, mesmo com o dono longe.
	dia.definir_hora(21.0)
	await _fisica(900)
	_conferir(cao.deitado and _plano(cao.global_position - porta).length() < 1.5, "de noite o cão não deitou na porta")
	# O filhote segue o cão grande e deita com ele.
	filhote.perto = true
	_conferir(filhote.lider == cao, "o filhote não segue o cão da casa")
	cao.perto = false
	filhote.perto = false

	# --- 5. O GATO FOGE DO CÃO, E O PORCO FICA NO CHIQUEIRO --------------------
	dia.definir_hora(9.0)
	var gato = _da_casa(gerente, "Casa da estrada", "gato_malhado")[0]
	var cao_da_estrada = _da_casa(gerente, "Casa da estrada", "cachorro_caramelo")[0]
	_conferir(gato.caes.has(cao_da_estrada), "o gato da estrada não sabe de quem foge")
	gato.perto = true
	cao_da_estrada.perto = true
	cao_da_estrada.set_physics_process(false)
	var soleira: Vector3 = gato.lugar_de_casa()
	var frente_da_estrada: Vector3 = world.ancoras.get("Casa da estradaFrente", Vector3.BACK)
	var lado := frente_da_estrada.cross(Vector3.UP).normalized()
	# O cão chega de um lado e, se a parede estiver desse lado, do outro: o gato
	# foge para onde há chão, e o que se conta é o mais longe a que ele chegou.
	var longe := 0.0
	for sinal in [1.0, -1.0]:
		gato.global_position = soleira
		gato.velocity = Vector3.ZERO
		gato._alvo = Vector3.INF
		gato._fugindo = 0.0
		cao_da_estrada.global_position = world.ground_position(soleira + lado * 1.4 * sinal, 0.0)
		await _fisica(20)
		if sinal > 0.0:
			_conferir(gato.fazendo == "foge", "o gato a 1,4 u do cão não fugiu ('%s')" % gato.fazendo)
		for i in 110:
			await physics_frame
			longe = maxf(longe, _plano(gato.global_position - cao_da_estrada.global_position).length())
		if longe > 3.0:
			break
	_conferir(longe > 3.0, "o gato fugiu só até %.1f u do cão" % longe)
	gato.perto = false
	cao_da_estrada.perto = false
	var porco = _da_casa(gerente, "Casa de Carro Quebrado", "porco")[0]
	porco.perto = true
	await _fisica(240)
	var do_chiqueiro := _plano(porco.global_position - porco.lugar_de_casa()).length()
	_conferir(do_chiqueiro < float(porco.dados.get("raio", 1.6)) + 3.0, "de manhã o porco está a %.1f u do chiqueiro" % do_chiqueiro)
	porco.perto = false

	# --- 6. O BANDO ------------------------------------------------------------
	var bando = _bando_de(gerente, "Casa de Carro Quebrado")
	bando.perto = false
	dia.definir_hora(19.5)
	await create_timer(0.6).timeout
	var no_galho := 0
	for ave in bando.aves:
		if ave["no_poleiro"]:
			no_galho += 1
	if bando.arvore.is_finite():
		_conferir(no_galho == bando.aves.size(), "ao entardecer só %d de %d aves subiram no poleiro" % [no_galho, bando.aves.size()])
		for ave in bando.aves:
			_conferir(ave["no"].global_position.y > bando.arvore.y + 1.0, "uma %s no poleiro está a %.1f u do chão da árvore" % [ave["chave"], ave["no"].global_position.y - bando.arvore.y])
	dia.definir_hora(7.0)
	await create_timer(0.6).timeout
	for ave in bando.aves:
		_conferir(not ave["no_poleiro"], "às sete uma %s ainda dorme no poleiro" % ave["chave"])
	# De dia, perto: cisca dentro do terreiro, e há movimento.
	bando.perto = true
	dia.definir_hora(10.0)
	var antes: Array[Vector3] = []
	for ave in bando.aves:
		antes.append(ave["no"].global_position)
	await _frames(420)
	var andou := 0
	for i in bando.aves.size():
		var p: Vector3 = bando.aves[i]["no"].global_position
		andou += 1 if _plano(p - antes[i]).length() > 0.25 else 0
		_conferir(_plano(p - bando.centro).length() <= bando.raio + 3.5, "uma %s saiu do terreiro: a %.1f u do centro" % [bando.aves[i]["chave"], _plano(p - bando.centro).length()])
		_conferir(not _dentro_de_casa(p, 0.0), "uma %s do bando entrou na casa" % bando.aves[i]["chave"])
	_conferir(andou >= 2, "só %d ave(s) do bando andaram em sete segundos" % andou)
	# Quem chega perto espanta.
	var qualquer: Node3D = bando.aves[0]["no"]
	player.global_position = qualquer.global_position + Vector3(0.7, 0.2, 0.0)
	player.velocity = Vector3.ZERO
	_conferir(bando._espanto().is_finite(), "o bando não se espantou com o jogador a 0,7 u")
	player.global_position = qualquer.global_position + Vector3(25.0, 0.2, 0.0)
	_conferir(not bando._espanto().is_finite(), "o bando se espantou com o jogador a 25 u")
	bando.perto = false

	# O pavão abre o leque, e o modelo troca.
	var adro = _bando_de(gerente, "Igreja")
	adro.perto = true
	dia.definir_hora(10.0)
	await _frames(10)
	var pavao: Dictionary = adro._o_pavao()
	_conferir(not pavao.is_empty(), "o adro não tem o pavão do leque")
	if not pavao.is_empty():
		adro.fechar_leque()
		_conferir(not adro.leque_aberto() and pavao["modelo"].visible, "o leque começa aberto")
		adro.abrir_leque()
		_conferir(adro.leque_aberto(), "o pavão não abriu o leque")
		if tripo:
			_conferir(pavao.has("modelo_leque") and pavao["modelo_leque"].visible and not pavao["modelo"].visible, "com o leque aberto o modelo não trocou para o pavão de cauda aberta")
		else:
			_conferir(pavao.has("modelo_leque") and pavao["modelo_leque"].visible, "no procedural o leque não apareceu")
		adro.fechar_leque()
		_conferir(not adro.leque_aberto() and pavao["modelo"].visible and not pavao["modelo_leque"].visible, "o pavão não fechou o leque")
	adro.perto = false

	# --- 7. O NÍVEL DE DETALHE -------------------------------------------------
	var olho := Vector3.ZERO
	var Gerente = load("res://scripts/prototipo_3d/bichos_de_casa.gd")
	_conferir(Gerente._perto(Vector3(60.0, 0.0, 0.0), olho, false), "a 60 u o bicho está longe")
	_conferir(not Gerente._perto(Vector3(95.0, 0.0, 0.0), olho, false), "a 95 u o bicho está perto")
	_conferir(Gerente._perto(Vector3(85.0, 0.0, 0.0), olho, true), "a 85 u quem estava perto some (sem histerese)")
	_conferir(not Gerente._perto(Vector3(85.0, 0.0, 0.0), olho, false), "a 85 u quem estava longe aparece (sem histerese)")
	var BichoDeCasa = load("res://scripts/prototipo_3d/bicho_de_casa.gd")
	_conferir(Gerente._perto(Vector3(15.0, 0.0, 0.0), olho, false, BichoDeCasa.FISICA_ATE), "a 15 u o bicho ainda anda sem física")
	_conferir(not Gerente._perto(Vector3(20.0, 0.0, 0.0), olho, false, BichoDeCasa.FISICA_ATE), "a 20 u quem andava sem física passa a andar com física (sem histerese)")
	_conferir(Gerente._perto(Vector3(30.0, 0.0, 0.0), olho, true, BichoDeCasa.FISICA_ATE), "a 30 u quem andava com física passa a andar sem (sem histerese)")
	_conferir(not Gerente._perto(Vector3(40.0, 0.0, 0.0), olho, true, BichoDeCasa.FISICA_ATE), "a 40 u o bicho ainda anda com física")

	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("BICHOS_DE_CASA_OK: cães caramelo no Pedro, no Tonho e no Benedito, gatos em mais de uma casa, galinhas em cinco casas ou mais, porcos, cabras, jumento, patos e o pavão com as pavoas, tudo fora da camada 1, em terra seca e fora das casas; o cão segue o dono de dia, deita na porta na sesta e de noite, o gato foge do cão, o bando sobe no poleiro ao entardecer e o pavão abre o leque (%s)" % _estilo_do_portao())
	else:
		print("bichos_de_casa: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _da_casa(gerente, casa: String, chave: String) -> Array:
	var lista: Array = []
	for b in gerente.bichos:
		if b.casa == casa and b.chave == chave:
			lista.append(b)
	return lista


func _bando_de(gerente, casa: String):
	for bando in gerente.bandos:
		if bando.casa == casa:
			return bando
	return null


func _aves_da_casa(gerente, casa: String, chave: String) -> Array:
	var lista: Array = []
	for bando in gerente.bandos:
		if bando.casa != casa:
			continue
		for ave in bando.aves:
			if ave["chave"] == chave:
				lista.append(ave)
	return lista


func _caixa_de_casa(nome: String) -> Node3D:
	for alvo in get_nodes_in_group("interactive_house"):
		var propriedades: Dictionary = alvo.get_meta("house_properties", {})
		if str(propriedades.get("name", "")) == nome:
			return alvo as Node3D
	return null


func _dentro_de_casa(p: Vector3, folga: float) -> bool:
	for alvo in get_nodes_in_group("interactive_house"):
		var caixa: Vector3 = alvo.get_meta("house_bounds", Vector3.ZERO)
		var local: Vector3 = (alvo as Node3D).global_transform.affine_inverse() * p
		if absf(local.x) < caixa.x * 0.5 + folga and absf(local.z) < caixa.z * 0.5 + folga:
			return true
	return false


func _molhado(world, p: Vector3) -> bool:
	return world.water_depth_at(p) > 0.12 and p.y < world.water_level_at(p) + 0.05


func _plano(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _fisica(n: int) -> void:
	for i in n:
		await physics_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _mundo_pronto() -> void:
	for i in range(3000):
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
