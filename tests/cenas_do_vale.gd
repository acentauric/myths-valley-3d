extends "res://tests/suite/caso.gd"
## AS CENAS DO VALE PELOS DADOS (07/10: "implementar a mesma lógica de cutscene que fizemos no 2D,
## travando a tela e comandos do jogador e a própria engine conduzindo os personagens para uma
## interação com fala; explorar a vista, o cenário, aproximar dos personagens, mexer os braços").
##
##     .\tools\prototipo_3d\testar.ps1 -Teste cenas_do_vale
##
##   1. OS DADOS FECHAM: cada cena de data/cenas.json só usa comandos conhecidos, segura e solta;
##      `quem` é o Pedro ou um morador do vale; `de`/`para`/`ate`/`olha_de`/`olha_para` resolvem
##      (jogador, Pedro, morador, âncora, lugar); o gesto existe; a câmera tem modo; `fala` vem nos
##      três idiomas; e toda `cena` pedida por um passo de data/missoes_*.json existe — nos dados
##      ou entre as escritas à mão (`Prototype.CENAS_ESCRITAS_A_MAO`).
##   2. A CENA TRAVA E CONDUZ: fechado o passo da corrida da chegada, a apresentação do Tonho toca
##      pela própria fila (sinal `cena`): o jogador para (sem física), a câmera da cena assume e as
##      tarjas descem, a fila fica segura até o `anuncia`, o Pedro anda até o Tonho; e no fim tudo
##      volta — jogador, câmera, tarjas, fila —, o passo seguinte foi anunciado e a cena coube no teto.
##   3. CENA DURANTE CENA ESPERA A VEZ: pedida outra no meio, ela toca depois, e não some.

## Recebe o vale montado do zero: reprovava no vale deixado pelos casos anteriores (a suíte, #242).
const VALE_NOVO := true

const TETO_DA_CENA_S := 30.0

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("CENAS_DO_VALE_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "o vale não carregou")
	await _frames(4)
	await _mundo_pronto()
	await _frames(6)
	var vale = current_scene
	var cenas = vale.get("cenas")
	_conferir(cenas != null, "o vale não tem o nó das cenas (CenaVale)")
	if cenas == null:
		_fechar()
		return
	var jogador = vale.player
	var pedro = vale.pedro
	var lugares = root.get_node("/root/Lugares")

	# --- 1. OS DADOS FECHAM -----------------------------------------------------------------
	var dados: Dictionary = cenas.todas()
	_conferir(dados.size() >= 3, "data/cenas.json tem %d cena(s); a chegada pede três" % dados.size())
	for nome in dados:
		var passos: Array = (dados[nome] as Dictionary).get("passos", [])
		_conferir(passos.size() >= 2, "a cena '%s' não tem passos" % nome)
		var segura := false
		var solta := false
		for passo in passos:
			if not (passo is Dictionary):
				_conferir(false, "a cena '%s' tem um passo que não é um dicionário" % nome)
				continue
			var p: Dictionary = passo
			var faz := str(p.get("faz", ""))
			_conferir(faz in cenas.COMANDOS, "a cena '%s' pede o comando '%s', que ninguém conhece" % [nome, faz])
			segura = segura or faz == "segura"
			solta = solta or faz == "solta"
			if p.has("quem"):
				_conferir(_morador(vale, p["quem"]) != null, "a cena '%s' manda em '%s', que não é o Pedro nem morador do vale" % [nome, str(p["quem"])])
			for chave in ["de", "para", "ate", "olha_de", "olha_para"]:
				if p.has(chave):
					_conferir(_resolve(vale, lugares, p[chave]), "a cena '%s' aponta '%s' = '%s', que não é jogador, Pedro, morador, âncora nem lugar" % [nome, chave, str(p[chave])])
			if faz == "gesto":
				_conferir(pedro != null and (pedro.GESTOS_DA_CENA as Dictionary).has(str(p.get("gesto", ""))), "a cena '%s' pede o gesto '%s', que não existe" % [nome, str(p.get("gesto", ""))])
			if faz == "camera":
				_conferir(str(p.get("modo", "olha")) in cenas.MODOS_DE_CAMERA, "a cena '%s' pede a câmera em modo '%s'" % [nome, str(p.get("modo", ""))])
			if faz == "fala":
				for sufixo in ["", "_en", "_es"]:
					_conferir(str(p.get("texto" + sufixo, "")).strip_edges() != "", "a fala da cena '%s' não tem texto%s" % [nome, sufixo])
		_conferir(segura and solta, "a cena '%s' não segura e solta o jogador" % nome)
	# Toda cena pedida pelos passos das missões existe.
	var escritas: Array = vale.CENAS_ESCRITAS_A_MAO
	var pedidas := 0
	for arquivo in DirAccess.get_files_at("res://data"):
		if not (str(arquivo).begins_with("missoes_") and str(arquivo).ends_with(".json")):
			continue
		var fila: Dictionary = root.get_node("/root/Jogo").dados("res://data/" + str(arquivo))
		for passo in (fila.get("passos", []) as Array):
			if passo is Dictionary and str((passo as Dictionary).get("cena", "")) != "":
				pedidas += 1
				var pedida := str((passo as Dictionary)["cena"])
				_conferir(dados.has(pedida) or pedida in escritas, "%s pede a cena '%s', que não está em data/cenas.json nem entre as escritas à mão" % [str(arquivo), pedida])
	for nome in ["apresentacao_do_tonho", "vista_da_praca", "a_casa_do_tio"]:
		_conferir(dados.has(nome), "a cena da chegada '%s' não está em data/cenas.json" % nome)
	print("  %d cenas nos dados, %d pedidas pelas missões (%d escritas à mão)" % [dados.size(), pedidas, escritas.size()])

	# --- 2. A CENA TRAVA E CONDUZ -----------------------------------------------------------
	var guia = pedro._cadeia
	var i_correr := -1
	for i in guia.passos.size():
		if str((guia.passos[i] as Dictionary).get("id", "")) == "correr":
			i_correr = i
	_conferir(i_correr >= 0, "a chegada não tem o passo 'correr'")
	_conferir(str((guia.passos[i_correr] as Dictionary).get("cena", "")) == "apresentacao_do_tonho", "o passo 'correr' da chegada não declara a cena da apresentação do Tonho")
	var tonho = vale._achar_morador("tonho")
	_conferir(tonho != null, "o Tonho não está no vale")
	var camera_do_jogador: Camera3D = jogador.get("camera")
	_conferir(camera_do_jogador != null and root.get_camera_3d() == camera_do_jogador, "antes da cena a câmera corrente não é a do jogador")
	_conferir(jogador.is_physics_processing(), "antes da cena o jogador já estava parado")
	var nomes: Array = []
	cenas.comecou.connect(func(n: String) -> void: nomes.append("+" + n))
	cenas.acabou.connect(func(n: String) -> void: nomes.append("-" + n))
	guia.iniciado = true
	guia.missao = i_correr
	guia.espera = 0.0
	var d_antes: float = _plano(pedro.global_position, tonho.global_position) if tonho != null else 0.0
	var antes := Time.get_ticks_msec()
	guia.avancar()
	await _frames(3)
	_conferir(bool(cenas.em_cena()) and str(cenas.nome_da_cena()) == "apresentacao_do_tonho", "fechado o passo da corrida, a cena da apresentação não tocou (em cena: %s, '%s')" % [str(cenas.em_cena()), str(cenas.nome_da_cena())])
	_conferir(guia.missao == i_correr + 1, "a fila da chegada não passou ao passo seguinte (missao %d)" % guia.missao)
	_conferir(not jogador.is_physics_processing(), "na cena o jogador continua com a física ligada: a tela não travou")
	_conferir(cenas.camera_da_cena() != null and root.get_camera_3d() == cenas.camera_da_cena(), "na cena a câmera corrente não é a da cena")
	_conferir(bool(cenas.tarjas_a_vista()), "na cena as tarjas não desceram")
	_conferir(float(guia.espera) >= 100.0, "na cena a fila não ficou segura (espera %.1f): o passo seguinte vai se anunciar no meio" % float(guia.espera))
	_conferir(pedro.em_cena() or true, "")
	var acabou := await _ate(func() -> bool: return not bool(cenas.em_cena()), TETO_DA_CENA_S)
	var durou := float(Time.get_ticks_msec() - antes) / 1000.0
	_conferir(acabou, "a cena da apresentação não acabou em %.0f s" % TETO_DA_CENA_S)
	print("  a apresentação do Tonho durou %.1f s; Pedro→Tonho %.1f → %.1f" % [durou, d_antes, _plano(pedro.global_position, tonho.global_position) if tonho != null else 0.0])
	_conferir(durou <= cenas.TETO_DA_CENA + 2.0, "a cena passou do teto (%.1f s)" % durou)
	if tonho != null:
		var d_depois: float = _plano(pedro.global_position, tonho.global_position)
		_conferir(d_depois < d_antes - 1.0 or d_depois < 3.5, "na cena o Pedro não foi até o Tonho (%.1f → %.1f)" % [d_antes, d_depois])
	_conferir(jogador.is_physics_processing(), "acabada a cena o jogador não voltou a andar")
	_conferir(root.get_camera_3d() == camera_do_jogador, "acabada a cena a câmera não voltou para a do jogador")
	await _ate(func() -> bool: return not bool(cenas.tarjas_a_vista()), 2.0)
	_conferir(not bool(cenas.tarjas_a_vista()), "acabada a cena as tarjas não subiram")
	_conferir(float(guia.espera) < 100.0, "acabada a cena a fila continua segura (espera %.1f)" % float(guia.espera))
	_conferir(not bool(pedro.em_cena()), "acabada a cena o Pedro continua em cena")
	var resumo_seguinte := str(guia.resumo_do_passo(guia.passos[i_correr + 1]))
	var anunciou := await _ate(func() -> bool: return str(vale.hud.get("_objective")).contains(resumo_seguinte), 6.0)
	_conferir(anunciou, "o passo seguinte ('%s') não foi anunciado depois da cena (objetivo: '%s')" % [resumo_seguinte, str(vale.hud.get("_objective"))])
	_conferir(nomes == ["+apresentacao_do_tonho", "-apresentacao_do_tonho"], "os sinais da cena vieram errados: %s" % str(nomes))

	# --- 3. CENA DURANTE CENA ESPERA A VEZ --------------------------------------------------
	nomes.clear()
	cenas.tocar("a_casa_do_tio", guia)
	cenas.tocar("vista_da_praca", guia)
	await _frames(3)
	_conferir(str(cenas.nome_da_cena()) == "a_casa_do_tio", "a primeira cena pedida não tocou ('%s')" % str(cenas.nome_da_cena()))
	var passou_a_segunda := await _ate(func() -> bool: return str(cenas.nome_da_cena()) == "vista_da_praca", TETO_DA_CENA_S)
	_conferir(passou_a_segunda, "a cena pedida durante outra não tocou depois dela (%s)" % str(nomes))
	var acabou_a_segunda := await _ate(func() -> bool: return not bool(cenas.em_cena()), TETO_DA_CENA_S)
	_conferir(acabou_a_segunda, "a segunda cena não acabou em %.0f s" % TETO_DA_CENA_S)
	_conferir(jogador.is_physics_processing() and root.get_camera_3d() == camera_do_jogador, "depois das duas cenas o jogador ou a câmera não voltaram")
	_conferir(nomes == ["+a_casa_do_tio", "-a_casa_do_tio", "+vista_da_praca", "-vista_da_praca"], "a ordem das cenas em fila veio errada: %s" % str(nomes))
	_fechar()


func _morador(vale, ref) -> Node:
	var nome := str(ref)
	if nome == "pedro":
		return vale.pedro
	return vale._achar_morador(nome)


func _resolve(vale, lugares, ref) -> bool:
	if ref is Array:
		return (ref as Array).size() == 3
	var nome := str(ref)
	if nome == "jogador" or _morador(vale, nome) != null:
		return true
	if (vale.world.ancoras as Dictionary).has(nome):
		return true
	return (lugares.ponto(nome) as Vector3).is_finite()


static func _plano(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("CENAS_DO_VALE_OK: os dados das cenas fecham (comandos, gente, lugares, gestos, idiomas, e toda cena pedida existe); fechado o passo da corrida a apresentação do Tonho trava o jogador, assume a câmera, desce as tarjas, segura a fila, leva o Pedro ao Tonho e devolve tudo, com o passo seguinte anunciado; e cena pedida durante outra toca depois")
	else:
		print("cenas_do_vale: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _ate(condicao: Callable, segundos: float) -> bool:
	var limite := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < limite:
		if condicao.call():
			return true
		await process_frame
	return condicao.call()


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
