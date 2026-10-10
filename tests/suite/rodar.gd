extends SceneTree
## A SUÍTE DO VALE: todos os casos de integração num Godot só, com o vale montado uma vez.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/suite/rodar.gd
##     ... -- --casos=casa,achados_no_vale     só estes (inclusive os isolados)
##     ... -- --saida=C:/caminho/da/pasta       grava o log de cada caso e o resultado.json
##     ... -- --listar                          imprime o plano (linha PLANO: + JSON) e sai
##     ... -- --longos                          inclui os casos LONGO (a partida inteira)
##     ... -- --deslocamento=3 --total=170      numera as linhas na conta da bateria inteira
##
## Quem roda isto no dia a dia é o `tools/prototipo_3d/testar.ps1`, que dá ao
## processo um perfil descartável (saves e preferências) e repete sozinho, num
## Godot novo, o caso que reprovar aqui, para separar defeito de contaminação.
##
## O CASO é um portão convertido: `extends "res://tests/suite/caso.gd"` (ver a
## explicação lá). O anfitrião carrega cada um na vez dele, chama `_initialize`
## e espera o `quit`, o teto de tempo ou o primeiro erro de script. O vale fica
## montado de um caso para o outro; só se remonta quando o caso pede outra cena,
## outro estilo, ou recarrega o vale de propósito.
##
## ENTRE UM CASO E OUTRO o anfitrião desfaz o que é do motor e não do jogo: tira
## a pausa, devolve a escala de tempo e os quadros de física, solta toda tecla
## apertada, volta o estilo ao padrão e apaga o que o caso pendurou na raiz.
## O estado do jogo (missões, mochila, relógio) é do caso: o portão que mexe
## nisso devolve no fim, como já fazia, ou se declara ISOLADO.
##
## A ORDEM é fixa, para a contaminação ser reproduzível: primeiro os casos que
## não usam o vale, depois os do vale no estilo Tripo, depois os do procedural.

const PASTA := "res://tests/"
const BASE := "res://tests/suite/caso.gd"
const CENA_DO_VALE := "res://scenes/prototipo_3d/vale.tscn"
const TETO_PADRAO_S := 300.0
## O mesmo critério do runner antigo para "o script não compilou": erro de script
## (SCRIPT ERROR), Parse Error, Compile Error e recurso que não carregou.
const Estado := preload("res://tests/suite/estado.gd")
const FATAL := "Parse Error|Compile Error|Failed loading resource"


class Captura extends Logger:
	var trava := Mutex.new()
	var ativa := false
	var linhas := PackedStringArray()
	var fatais := PackedStringArray()
	var _fatal := RegEx.create_from_string(FATAL)

	func comecar() -> void:
		trava.lock()
		linhas = PackedStringArray()
		fatais = PackedStringArray()
		ativa = true
		trava.unlock()

	func parar() -> void:
		trava.lock()
		ativa = false
		trava.unlock()

	func tem_fatal() -> bool:
		trava.lock()
		var tem := not fatais.is_empty()
		trava.unlock()
		return tem

	func _log_message(mensagem: String, _erro: bool) -> void:
		trava.lock()
		if ativa:
			linhas.append(mensagem.trim_suffix("\n"))
		trava.unlock()

	func _log_error(funcao: String, arquivo: String, linha: int, codigo: String, razao: String,
			_editor: bool, tipo: int, _pilha: Array[ScriptBacktrace]) -> void:
		var texto := (razao if razao != "" else codigo)
		var onde := "%s:%d %s" % [arquivo, linha, funcao]
		trava.lock()
		if ativa:
			var rotulo: String = ["ERROR", "WARNING", "SCRIPT ERROR", "SHADER ERROR"][clampi(tipo, 0, 3)]
			linhas.append("%s: %s (%s)" % [rotulo, texto, onde])
			if tipo == ERROR_TYPE_SCRIPT or _fatal.search(texto + " " + codigo) != null:
				fatais.append("%s: %s (%s)" % [rotulo, texto, onde])
		trava.unlock()


var _captura := Captura.new()
var _saida := ""
var _estilo_padrao := ""
var _estilo_montado := ""
var _quadros_fisica := 60
var _passos_fisica := 8
var _max_fps := 0
var _cena_antes: Node = null
var montagens := 0
var _resultados: Array[Dictionary] = []
var _zerar_user := false
## O estado dos autoloads (e do user://) como num Godot recém-aberto...
var _foto_inicial := {}
## ...e logo depois de o vale ficar pronto, no estilo montado.
var _foto_vale := {}


func _initialize() -> void:
	OS.add_logger(_captura)
	_rodar.call_deferred()


func _rodar() -> void:
	var argumentos := _argumentos()
	_saida = argumentos.get("saida", "")
	if _saida != "":
		DirAccess.make_dir_recursive_absolute(_saida)
	var pedidos: PackedStringArray = []
	if argumentos.has("casos"):
		for nome in String(argumentos["casos"]).split(",", false):
			pedidos.append(nome.strip_edges().trim_suffix(".gd"))
	var plano := _planejar(pedidos, argumentos.has("longos"))
	if argumentos.has("listar"):
		print("PLANO:" + JSON.stringify(plano))
		quit(0)
		return
	var casos: Array = plano["casos"]
	for faltando in plano["inexistentes"]:
		print("caso inexistente: ", faltando)
	if casos.is_empty():
		print("nada a rodar")
		quit(1 if not plano["inexistentes"].is_empty() else 0)
		return

	var estilo := root.get_node_or_null("/root/Estilo")
	if estilo != null:
		_estilo_padrao = String(estilo.get("modo"))
	_quadros_fisica = Engine.physics_ticks_per_second
	_passos_fisica = Engine.max_physics_steps_per_frame
	_max_fps = Engine.max_fps
	# Só apaga e reescreve o user:// quando quem chamou deu um perfil descartável:
	# rodado à mão, sem isso, os saves de quem joga ficam como estão.
	_zerar_user = Estado.perfil_descartavel()
	if argumentos.has("perfil-descartavel") and not _zerar_user:
		print("aviso: --perfil-descartavel sem perfil descartavel (%s); o user:// nao sera zerado" % OS.get_user_data_dir())
	# Carregados antes da foto, para as `static` deles entrarem nela com o valor de
	# quem nunca rodou (o caso que carrega a abertura depois mexe nelas).
	for caminho in Estado.scripts_com_estaticas():
		load(caminho)
	_foto_inicial = Estado.fotografar(root, _zerar_user)

	print("suite: %d caso(s) num Godot so" % casos.size())
	var relogio := Time.get_ticks_msec()
	var reprovados: PackedStringArray = []
	var contaminados: PackedStringArray = []
	var feitos := 0
	var deslocamento := int(argumentos.get("deslocamento", "0"))
	var total := int(argumentos.get("total", str(casos.size())))
	for item in casos:
		var veredito := await _rodar_caso(item, deslocamento + feitos, total)
		# O VALE EMPRESTADO PODE ESTAR SUJO: um caso anterior pegou o cordel, cortou a
		# árvore, deixou o foco do E sem dono. O caso do vale que reprova roda de novo
		# com o vale montado do zero (e os autoloads de um Godot novo); só reprova se
		# reprovar assim também. Quem passou na segunda vai na lista dos contaminados.
		if veredito["status"] != "ok" and int(item["grupo"]) > 0 and not argumentos.has("sem-segunda-chance"):
			var primeira: Dictionary = veredito
			_foto_vale = {}
			await _descarregar_cena()
			veredito = await _rodar_caso(item, deslocamento + feitos, total)
			veredito["segundos"] += primeira["segundos"]
			veredito["repetido"] = true
			if veredito["status"] == "ok":
				veredito["contaminado"] = true
				contaminados.append(item["nome"])
				veredito["detalhes"] = PackedStringArray(["no vale emprestado: %s %s" % [primeira["status"], primeira["resumo"]]]) + _primeiros(primeira["detalhes"], 2)
		feitos += 1
		_resultados.append(veredito)
		print("[%3d/%d] %-8s %-26s %4ds  %s" % [deslocamento + feitos, total, veredito["status"], item["nome"],
			roundi(veredito["segundos"]), veredito["resumo"]])
		for detalhe in veredito["detalhes"]:
			print("         " + detalhe)
		if veredito["status"] != "ok":
			reprovados.append(item["nome"])
		_gravar_resultado(relogio)

	var minutos := (Time.get_ticks_msec() - relogio) / 60000.0
	print("")
	print("vale montado %d vez(es)" % montagens)
	if not contaminados.is_empty():
		print("passaram so com o vale novo (o vale emprestado estava sujo de um caso anterior): %s" % ", ".join(contaminados))
	if reprovados.is_empty():
		print("os %d casos rodados passaram em %.1f min" % [casos.size(), minutos])
		quit(0)
	else:
		print("%d caso(s) reprovado(s) de %d rodados em %.1f min: %s" % [reprovados.size(), casos.size(), minutos, ", ".join(reprovados)])
		quit(1)


# ---------------------------------------------------------------------------
# O PLANO: quais casos, em que ordem, com que teto.

func _planejar(pedidos: PackedStringArray, longos: bool) -> Dictionary:
	var todos: Array[Dictionary] = []
	var inexistentes: PackedStringArray = []
	var nomes: PackedStringArray = []
	if pedidos.is_empty():
		for arquivo in DirAccess.get_files_at(PASTA):
			if arquivo.ends_with(".gd"):
				nomes.append(arquivo.get_basename())
		nomes.sort()
	else:
		nomes = pedidos
	var isolados: PackedStringArray = []
	var fora: PackedStringArray = []
	var deixados: PackedStringArray = []
	for nome in nomes:
		var caminho := PASTA + nome + ".gd"
		if not FileAccess.file_exists(caminho):
			inexistentes.append(nome)
			continue
		var info := _ler_cadeia(caminho)
		if not info["caso"]:
			fora.append(nome)
			continue
		if info["longo"] and pedidos.is_empty() and not longos:
			deixados.append(nome)
			continue
		if info["isolado"] and pedidos.is_empty():
			isolados.append(nome)
			continue
		var grupo := 0
		if info["vale"]:
			grupo = 2 if info["procedural"] else 1
		todos.append({"nome": nome, "caminho": caminho, "teto": info["teto"], "grupo": grupo, "isolado": info["isolado"], "vale_novo": info["vale_novo"], "acelerar": info["acelerar"]})
	todos.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["grupo"] < b["grupo"] if a["grupo"] != b["grupo"] else a["nome"] < b["nome"])
	var nomes_dos_casos: PackedStringArray = []
	for item in todos:
		nomes_dos_casos.append(item["nome"])
	return {"casos": todos, "nomes": nomes_dos_casos, "isolados": isolados, "longos_deixados": deixados,
		"fora_da_suite": fora, "inexistentes": inexistentes}


## O que o texto do caso (e o dos portões de que ele herda) declara.
func _ler_cadeia(caminho: String) -> Dictionary:
	var info := {"caso": false, "isolado": false, "longo": false, "vale_novo": false, "acelerar": 1.0, "teto": TETO_PADRAO_S, "vale": false, "procedural": false}
	var vistos := {}
	var atual := caminho
	var teto_achado := false
	var isolado_achado := false
	while atual != "" and not vistos.has(atual) and FileAccess.file_exists(atual):
		vistos[atual] = true
		var texto := FileAccess.get_file_as_string(atual)
		if CENA_DO_VALE in texto:
			info["vale"] = true
		if "return \"procedural\"" in texto and atual == caminho:
			info["procedural"] = true
		var r := RegEx.create_from_string("(?m)^const TETO_S\\s*:?=\\s*([0-9.]+)")
		var m := r.search(texto)
		if m != null and not teto_achado:
			info["teto"] = float(m.get_string(1))
			teto_achado = true
		var ri := RegEx.create_from_string("(?m)^const ISOLADO\\s*:?=\\s*(true|false)")
		var mi := ri.search(texto)
		if mi != null and not isolado_achado:
			info["isolado"] = mi.get_string(1) == "true"
			isolado_achado = true
		if RegEx.create_from_string("(?m)^const LONGO\\s*:?=\\s*true").search(texto) != null:
			info["longo"] = true
		if RegEx.create_from_string("(?m)^const VALE_NOVO\\s*:?=\\s*true").search(texto) != null:
			info["vale_novo"] = true
		var ma := RegEx.create_from_string("(?m)^const ACELERAR\\s*:?=\\s*([0-9.]+)").search(texto)
		if ma != null and info["acelerar"] == 1.0:
			info["acelerar"] = float(ma.get_string(1))
		var re := RegEx.create_from_string("(?m)^extends\\s+\"([^\"]+)\"")
		var me := re.search(texto)
		if me == null:
			break
		if me.get_string(1) == BASE:
			info["caso"] = true
			break
		atual = me.get_string(1)
	return info


# ---------------------------------------------------------------------------
# UM CASO.

func _rodar_caso(item: Dictionary, feitos: int, total: int) -> Dictionary:
	var nome: String = item["nome"]
	var inicio := Time.get_ticks_msec()
	_captura.comecar()
	var veredito := {"nome": nome, "status": "ok", "segundos": 0.0, "resumo": "", "detalhes": PackedStringArray()}
	# Quem usa o vale recebe o vale pronto e os autoloads como estavam logo depois
	# da montagem; quem não usa, os autoloads de um Godot recém-aberto.
	if int(item["grupo"]) > 0:
		# VALE_NOVO: o caso depende de um vale que ninguém tocou (a cadeia do Pedro do
		# começo, o morador no posto): monta do zero antes dele.
		if item.get("vale_novo", false):
			_foto_vale = {}
			await _descarregar_cena()
		if not await _garantir_vale("procedural" if int(item["grupo"]) == 2 else _estilo_padrao):
			_captura.parar()
			veredito["status"] = "NAO ABRE"
			veredito["resumo"] = "o vale nao ficou pronto"
			veredito["detalhes"] = _primeiros(_captura.fatais, 3)
			veredito["segundos"] = (Time.get_ticks_msec() - inicio) / 1000.0
			_gravar_log(nome, veredito)
			return veredito
		Estado.restaurar(root, _foto_vale)
	else:
		# Num Godot novo não há cena nenhuma: a que um caso anterior abriu (a
		# abertura, as ruas de referência) sai antes, com a física e os sinais dela.
		await _descarregar_cena()
		Estado.restaurar(root, _foto_inicial)
	var antes_na_raiz := root.get_children()
	_cena_antes = current_scene

	var script: Script = load(item["caminho"])
	if script == null or not script.can_instantiate() or _captura.tem_fatal():
		_captura.parar()
		veredito["status"] = "NAO ABRE"
		veredito["resumo"] = "o script nao compilou"
		veredito["detalhes"] = _primeiros(_captura.fatais, 3)
		veredito["segundos"] = (Time.get_ticks_msec() - inicio) / 1000.0
		_gravar_log(nome, veredito)
		await _arrumar(antes_na_raiz)
		return veredito

	# ACELERAR: o caso de simulação longa roda o tempo do jogo N vezes mais rápido,
	# com a física ainda em passos de 1/60 s (só mais passos por quadro).
	var acelerar := float(item.get("acelerar", 1.0))
	if acelerar > 1.0:
		Engine.time_scale = acelerar
		Engine.max_physics_steps_per_frame = maxi(_passos_fisica, ceili(_passos_fisica * acelerar))
	var caso: Object = script.new()
	caso.set("arvore", self)
	caso.set("_caso_anfitriao", self)
	caso.call("_initialize")
	var teto_ms := float(item["teto"]) * 1000.0
	var ultimo_sinal := Time.get_ticks_msec()
	var travou := false
	while not caso.get("_caso_fim") and not _captura.tem_fatal():
		if Time.get_ticks_msec() - inicio >= teto_ms:
			travou = true
			break
		if Time.get_ticks_msec() - ultimo_sinal >= 15000:
			ultimo_sinal = Time.get_ticks_msec()
			_captura.parar()
			print("          ... rodando: %s %ds  (faltam %d na fila)" % [nome, (Time.get_ticks_msec() - inicio) / 1000, total - feitos - 1])
			_captura.ativa = true
		await process_frame
	caso.call("congelar")
	# Um quadro para o que o caso adiou (call_deferred) acontecer ainda na conta dele.
	await process_frame
	_captura.parar()
	veredito["segundos"] = (Time.get_ticks_msec() - inicio) / 1000.0

	var falhas := PackedStringArray()
	var resumo := ""
	for linha in _captura.linhas:
		if linha.begins_with("FALHA:"):
			falhas.append(linha.strip_edges())
		if "_OK" in linha and ":" in linha:
			resumo = linha.strip_edges()
	if not _captura.fatais.is_empty():
		veredito["status"] = "NAO ABRE"
		veredito["resumo"] = "erro de script"
		veredito["detalhes"] = _primeiros(_captura.fatais, 3)
	elif travou:
		veredito["status"] = "TRAVOU"
		veredito["resumo"] = "passou do teto de %ds" % roundi(item["teto"])
		veredito["detalhes"] = _primeiros(falhas, 5)
	elif int(caso.get("_caso_codigo")) != 0 or not falhas.is_empty():
		veredito["status"] = "FALHOU"
		veredito["resumo"] = "saiu com %d" % int(caso.get("_caso_codigo"))
		veredito["detalhes"] = _primeiros(falhas, 8)
	else:
		if resumo == "":
			for linha in _captura.linhas:
				if linha.strip_edges() != "" and not linha.begins_with("ERROR") and not linha.begins_with("WARNING"):
					resumo = linha.strip_edges()
		veredito["resumo"] = resumo.substr(0, 107) + ("..." if resumo.length() > 110 else "")
	_gravar_log(nome, veredito)
	await _arrumar(antes_na_raiz)
	return veredito


## O que é do motor volta ao padrão; o que o caso pendurou na raiz sai.
func _arrumar(antes_na_raiz: Array[Node]) -> void:
	paused = false
	Engine.time_scale = 1.0
	Engine.max_fps = _max_fps
	Engine.physics_ticks_per_second = _quadros_fisica
	Engine.max_physics_steps_per_frame = _passos_fisica
	for acao in InputMap.get_actions():
		Input.action_release(acao)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var estilo := root.get_node_or_null("/root/Estilo")
	if estilo != null and _estilo_padrao != "":
		estilo.set("modo", _estilo_padrao)
	for filho in root.get_children():
		if filho == current_scene or filho in antes_na_raiz:
			continue
		filho.queue_free()
	# O caso que pôs outra cena no lugar à mão (`current_scene = instancia`) deixa
	# a de antes pendurada na raiz, com os grupos e os registros dela: o próximo
	# vale acharia dois mundos. A de antes sai, e o vale conta como sujo.
	if _cena_antes != null and is_instance_valid(_cena_antes) and _cena_antes != current_scene:
		if _cena_antes.is_inside_tree() and not _cena_antes.is_queued_for_deletion():
			_cena_antes.queue_free()
		_foto_vale = {}
	_cena_antes = null
	await process_frame


# ---------------------------------------------------------------------------
# O VALE PRONTO E A FOTO DO ESTADO.

## Monta o vale no estilo pedido, se ele já não está montado assim, e fotografa
## os autoloads logo depois: é o estado que cada caso do vale recebe.
func _garantir_vale(estilo_alvo: String) -> bool:
	var atual := current_scene
	if atual != null and is_instance_valid(atual) and not atual.is_queued_for_deletion() \
			and atual.scene_file_path == CENA_DO_VALE and _estilo_montado == estilo_alvo and not _foto_vale.is_empty():
		return true
	await _descarregar_cena()
	Estado.restaurar(root, _foto_inicial)
	var estilo := root.get_node_or_null("/root/Estilo")
	if estilo != null and estilo_alvo != "":
		estilo.set("modo", estilo_alvo)
	_estilo_montado = estilo_alvo
	_foto_vale = {}
	montagens += 1
	if change_scene_to_file(CENA_DO_VALE) != OK:
		return false
	var limite := Time.get_ticks_msec() + int(TETO_PADRAO_S * 1000.0)
	while Time.get_ticks_msec() < limite and not _captura.tem_fatal():
		await process_frame
		var cena := current_scene
		if cena == null or cena.scene_file_path != CENA_DO_VALE:
			continue
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and bool(mundo.get("construido")):
			break
	var mundo_pronto := get_first_node_in_group("mundo")
	if mundo_pronto == null or not bool(mundo_pronto.get("construido")):
		return false
	for i in 6:
		await process_frame
	_foto_vale = Estado.fotografar(root, _zerar_user)
	return true


func _descarregar_cena() -> void:
	if current_scene == null:
		return
	unload_current_scene()
	_foto_vale = {}
	for i in 3:
		await process_frame


func _primeiros(lista: PackedStringArray, quantos: int) -> PackedStringArray:
	return lista.slice(0, quantos)


# ---------------------------------------------------------------------------
# A CENA: o vale emprestado ou montado de novo.

func trocar_cena(caminho: String, primeira_do_caso: bool) -> Error:
	var atual := current_scene
	var estilo := _estilo_atual()
	# Só o vale se empresta: outra cena (a abertura, o início) monta de novo, e o
	# caso que espera `scene_changed` recebe o sinal.
	if primeira_do_caso and caminho == CENA_DO_VALE and atual != null and is_instance_valid(atual) and not atual.is_queued_for_deletion() \
			and atual.scene_file_path == caminho and estilo == _estilo_montado:
		# O caso preparou algo antes de pedir o vale (uma partida nova, uma vaga, a
		# hora): o vale monta de novo a partir disso, como num Godot por portão.
		var mexeu := Estado.difere(root, _foto_vale)
		if mexeu == "":
			return OK
		print("          (o caso mexeu em %s antes de pedir o vale: monta de novo)" % mexeu)
	_estilo_montado = estilo
	# O vale montado assim é do caso: o próximo recebe um montado do zero.
	_foto_vale = {}
	if caminho == CENA_DO_VALE:
		montagens += 1
	return change_scene_to_file(caminho)


func trocar_cena_empacotada(cena: PackedScene) -> Error:
	_estilo_montado = _estilo_atual()
	return change_scene_to_packed(cena)


func _estilo_atual() -> String:
	var estilo := root.get_node_or_null("/root/Estilo")
	return String(estilo.get("modo")) if estilo != null else ""


# ---------------------------------------------------------------------------
# A SAÍDA.

func _argumentos() -> Dictionary:
	var lidos := {}
	for argumento in OS.get_cmdline_user_args():
		if not argumento.begins_with("--"):
			continue
		var partes := argumento.substr(2).split("=", true, 1)
		lidos[partes[0]] = partes[1] if partes.size() > 1 else true
	return lidos


func _gravar_log(nome: String, veredito: Dictionary) -> void:
	if _saida == "":
		return
	var arquivo := FileAccess.open(_saida.path_join(nome + ".txt"), FileAccess.WRITE)
	if arquivo == null:
		return
	arquivo.store_line("%s %s %.1fs %s" % [veredito["status"], nome, veredito["segundos"], veredito["resumo"]])
	for linha in _captura.linhas:
		arquivo.store_line(linha)


func _gravar_resultado(relogio: int) -> void:
	if _saida == "":
		return
	var arquivo := FileAccess.open(_saida.path_join("resultado.json"), FileAccess.WRITE)
	if arquivo == null:
		return
	var lista := []
	for v in _resultados:
		lista.append({"nome": v["nome"], "status": v["status"], "contaminado": v.get("contaminado", false), "repetido": v.get("repetido", false), "segundos": snappedf(v["segundos"], 0.1), "resumo": v["resumo"], "detalhes": Array(v["detalhes"])})
	arquivo.store_string(JSON.stringify({"casos": lista, "montagens": montagens, "segundos": (Time.get_ticks_msec() - relogio) / 1000.0}, "  "))
