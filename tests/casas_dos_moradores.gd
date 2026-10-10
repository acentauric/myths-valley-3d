extends "res://tests/suite/caso.gd"
## Confere que A CASA DO PEDRO E A DA DONA ZEFA ABREM POR DENTRO, e que as casas
## não são iguais.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste casas_dos_moradores
##
## "Produza o ambiente interno da casa de Pedro e Dona Zefa. Lembre de fazer
## algumas variações para todas as casas não serem iguais." Seis perguntas:
##
##   1. O VALE ESCOLHE AS CASAS: a do Pedro é a casa de taipa do arraial mais
##      perto do píer ("na praia, perto do píer"), a da Zefa a mais perto da
##      casa herdada; são lotes diferentes, e o `Lugares` as resolve.
##   2. CADA UMA TEM CÔMODO, com o perfil de quem mora.
##   3. O CÔMODO DIZ QUEM MORA: o Pedro dorme de rede, e não tem cama; a Zefa
##      tem a cama dela, a rede do neto e o oratório. (As peças novas do lote,
##      quando o catálogo as tiver, também: a rede de pesca e os remos; as ervas,
##      o pilão e a gamela.)
##   4. AS TRÊS CASAS NÃO SÃO IGUAIS: o que cada uma tem por dentro e a cor da
##      parede são diferentes umas das outras.
##   5. O MORADOR VOLTA PARA ELA: de noite o Pedro, a Zefa e o Cosme estão na
##      porta da casa deles.
##   6. ENTRA-SE ANDANDO: da porta do Pedro, a tecla de andar leva para dentro.

## Recebe o vale montado do zero: reprovava no vale deixado pelos casos anteriores (a suíte, #242).
const VALE_NOVO := true

var falhas := 0
## Pelo caminho, e não pelo nome da classe: o portão compila antes dos autoloads.
var catalogo = load("res://scripts/prototipo_3d/catalogo_assets.gd")


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("CASAS_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _quadros(4)
	await _mundo_pronto()
	await _quadros(8)
	var vale = current_scene
	var mundo = vale.world
	var interiores = vale.get("interiores")
	var lugares = root.get_node("/root/Lugares")
	root.get_node("/root/Dia").pausado = true

	# --- 1. O VALE ESCOLHE AS CASAS -----------------------------------------------
	var casas: Dictionary = mundo.get("casas_dos_moradores")
	_conferir(casas.has("pedro") and casas.has("zefa"), "o vale não escolheu as casas do Pedro e da Zefa: %s" % str(casas))
	if not (casas.has("pedro") and casas.has("zefa")):
		_fechar()
		return
	_conferir(casas["pedro"] != casas["zefa"], "o Pedro e a Zefa ficaram na mesma casa")
	var lotes: Dictionary = mundo.get("_lotes")
	var pier: Vector3 = mundo.ancoras["Pier"]
	var herdada: Vector3 = mundo.ancoras["Casa de taipa"]
	var mais_perto_do_pier := ""
	var menor := INF
	for nome in lotes:
		if String(nome).begins_with("Casa do arraial") and str(lotes[nome].get("chave", "")) == "casa_taipa":
			var d: float = (mundo.ancoras[nome] as Vector3).distance_to(pier)
			if d < menor:
				menor = d
				mais_perto_do_pier = String(nome)
	_conferir(casas["pedro"] == mais_perto_do_pier, "a casa do Pedro é '%s', e a de taipa mais perto do píer é '%s'" % [casas["pedro"], mais_perto_do_pier])
	_conferir((mundo.ancoras[casas["zefa"]] as Vector3).distance_to(herdada) < 40.0, "a casa da Zefa não é vizinha da casa herdada")
	_conferir(lugares.ponto("casa_do_pedro") != lugares.NENHUM and lugares.ponto("casa_da_zefa") != lugares.NENHUM, "o Lugares não resolve as casas do Pedro e da Zefa")

	# --- 2 e 3. CADA UMA TEM CÔMODO, E O CÔMODO DIZ QUEM MORA ------------------------
	var tem := {}
	var cor := {}
	for qual in ["casa", "casa_pedro", "casa_zefa"]:
		var sala = interiores.sala_de(qual)
		_conferir(sala != null, "a '%s' não tem cômodo" % qual)
		if sala == null:
			continue
		var chaves := {}
		for no in sala.find_children("*", "Node3D", true, false):
			if (no as Node3D).has_meta("chave"):
				chaves[str((no as Node3D).get_meta("chave"))] = true
		tem[qual] = chaves
		var parede = sala._parede()
		# A cal é material padrão com textura (8e66ba3: a cor mora em `albedo_color`).
		cor[qual] = parede.albedo_color if parede is StandardMaterial3D else (parede.get_shader_parameter("cor") if parede is ShaderMaterial else null)
		print("  %s (%s): %s" % [qual, sala.perfil, ", ".join(chaves.keys())])
	if tem.has("casa_pedro"):
		var pedro_tem: Dictionary = tem["casa_pedro"]
		_conferir(interiores.sala_de("casa_pedro").perfil == "pescador", "a casa do Pedro não tem o perfil de pescador")
		_conferir(pedro_tem.has("rede") and not pedro_tem.has("cama"), "o Pedro não dorme de rede: %s" % str(pedro_tem.keys()))
		for chave in ["rede_de_pesca", "remos"]:
			if catalogo.tem_tripo(chave):
				_conferir(pedro_tem.has(chave), "o catálogo tem '%s', e a casa do Pedro não" % chave)
	if tem.has("casa_zefa"):
		var zefa_tem: Dictionary = tem["casa_zefa"]
		_conferir(interiores.sala_de("casa_zefa").perfil == "rezadeira", "a casa da Zefa não tem o perfil de rezadeira")
		_conferir(zefa_tem.has("cama") and zefa_tem.has("rede") and zefa_tem.has("oratorio") and zefa_tem.has("barril"),
			"a casa da Zefa não tem a cama, a rede do neto, o oratório e o barril: %s" % str(zefa_tem.keys()))
		for chave in ["ervas_secando", "pilao", "gamela"]:
			if catalogo.tem_tripo(chave):
				_conferir(zefa_tem.has(chave), "o catálogo tem '%s', e a casa da Zefa não" % chave)

	# --- 4. AS TRÊS CASAS NÃO SÃO IGUAIS ----------------------------------------------
	var vistas := []
	for qual in tem:
		var ordenada: Array = (tem[qual] as Dictionary).keys()
		ordenada.sort()
		var chave := str(ordenada)
		_conferir(not vistas.has(chave), "a '%s' tem por dentro o mesmo que outra casa" % qual)
		vistas.append(chave)
	if cor.has("casa_pedro") and cor.has("casa_zefa") and cor.has("casa"):
		_conferir(cor["casa"] != cor["casa_pedro"] and cor["casa"] != cor["casa_zefa"] and cor["casa_pedro"] != cor["casa_zefa"],
			"as paredes das três casas têm a mesma cal")

	# --- 5. O MORADOR VOLTA PARA ELA ---------------------------------------------------
	var quem := {}
	for morador in vale.moradores:
		quem[str(morador.dados.get("id", ""))] = morador
	var pedro = vale.get("pedro")
	if pedro != null:
		quem["pedro"] = pedro
	for par in [["pedro", "Casa do Pedro"], ["zefa", "Casa da Zefa"], ["cosme", "Casa da Zefa"]]:
		var morador = quem.get(par[0])
		if morador == null:
			_conferir(false, "não achei '%s' no vale" % par[0])
			continue
		var de_noite: Vector3 = morador._posicao_do_posto("noite")
		var casa: Vector3 = mundo.ancoras[par[1]]
		var longe := Vector2(de_noite.x - casa.x, de_noite.z - casa.z).length()
		_conferir(longe < 6.0, "de noite '%s' fica a %.1f da %s" % [par[0], longe, par[1]])

	# --- 6. ENTRA-SE ANDANDO -------------------------------------------------------------
	var sala_do_pedro = interiores.sala_de("casa_pedro")
	if sala_do_pedro != null:
		var jogador = vale.player
		var fora: Vector3 = sala_do_pedro.soleira_de_fora()
		var rumo: Vector3 = sala_do_pedro.soleira_de_dentro() - fora
		jogador.teleportar(fora + (fora - sala_do_pedro.soleira_de_dentro()).normalized() * 0.8, atan2(-rumo.x, -rumo.z) - PI)
		await _passos(4)
		Input.action_press("mv_forward")
		var entrou := false
		for i in 400:
			await physics_frame
			if interiores.contem(jogador.global_position) == "casa_pedro":
				entrou = true
				break
		Input.action_release("mv_forward")
		_conferir(entrou, "andando pela porta do Pedro, o jogador não entrou na casa dele")
	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("CASAS_OK: o vale escolhe a casa do Pedro perto do píer e a da Zefa ao lado da herdada; cada uma abre por dentro com o perfil de quem mora — o Pedro de rede, a Zefa com a cama, a rede do neto e o oratório —, as três casas são diferentes por dentro e na cal, os três moradores dormem na porta de casa, e entra-se andando")
	else:
		print("casas dos moradores: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _passos(n: int) -> void:
	for i in n:
		await physics_frame


func _quadros(n: int) -> void:
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
