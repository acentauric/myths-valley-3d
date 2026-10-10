extends "res://tests/suite/caso.gd"
## A MARÉ VEM LIGADA, SE VÊ NO JOGO E O VALE INTEIRO A SEGUE.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste mare_ligada
##
## "Eu ainda não vi a maré, ela se mantém implementada?" (playtest da Build 9B). Ela estava
## inteira no código e DESLIGADA de fábrica ("Sem maré"), e a preferência do desenvolvedor
## tinha o 0 gravado. Este portão confere, nesta ordem:
##
##   1. O PADRÃO É A MARÉ LIGADA ("Ciclo do lugar"). Os portões rodam sem tela e medem o mar
##      contra um nível fixo, então SEM TELA o de fábrica é "Sem maré", e `MV_MARE_MODO` o força.
##   2. A MIGRAÇÃO: a preferência de antes (`modo=0` sem a marca `escolhida`) é o padrão antigo,
##      e não escolha, e passa para a maré ligada; quem escolheu "Sem maré" em AJUSTAR (a marca
##      `escolhida=true`) continua sem maré; um ciclo gravado sem marca era escolha e fica.
##   3. A CURVA É A DO LUGAR E SE VÊ: 2,4 m (0,6 u) de amplitude, preamar às 07:00 e 19:00 (o jogo
##      abre com a água cheia e o saveiro atraca nela), baixa-mar às 13:00 e à 01:00, período de 12 h;
##      em três horas de jogo (90 s no ritmo Normal) o mar já desceu mais de um metro.
##   4. O VALE SEGUE a maré — montado com a baixa-mar (hora de partida do AJUSTAR) e levado à
##      preamar e de volta: o nível de água do mundo e o plano do mar e a barreira da câmera
##      (os nós do grupo `mare_superficie`) sobem e descem 0,6 u, a preamar é o nível de antes
##      da maré existir, os uniformes dos shaders (areia, leito, água) recebem os metros, o
##      fundo raso fica EXPOSTO na baixa-mar (e o chão dos pés vira lama, onde na cheia era
##      água), as canoas encalham e voltam a boiar, a barbatana do tubarão fica na superfície e os
##      cardumes dos xaréus são postos pela cheia (o vale montado na baixa-mar tem os dois pares).
##
## FALSIFICAÇÃO: com `MV_FALSIFICAR=fase` a preamar volta às 00:00 (a curva e a chegada na
## cheia têm de FALHAR); com `MV_FALSIFICAR=mar` o plano do mar deixa de seguir a maré (o
## vale não segue: tem de FALHAR). Revertendo o código: a migração desfeita em `mare.gd` e a
## lâmina do `fauna_vale.gd` trocada de volta pela do instante (sem xaréus no vale montado na
## baixa-mar) também reprovam. A espera é em segundos DE JOGO (`relogio_de_jogo.gd`).

const RelogioDeJogo = preload("res://tests/fixtures/relogio_de_jogo.gd")
const PREFERENCIAS := "user://preferencias_visuais.cfg"
const TESTE_CFG := "user://mare_ligada_teste.cfg"
const AMPLITUDE_U := 0.6
## Folga das medidas de nível (u): o plano e o `water_level` somam o mesmo offset.
const FOLGA := 0.02

var falhas := 0
var falsificar := ""
var relogio
var mare
var dia
var vale
var world
var jogador
## O que havia em `user://preferencias_visuais.cfg` antes do portão (bytes), para devolver.
var _reserva := PackedByteArray()
var _havia_arquivo := false


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		falhas += 1
		push_error("MARE_LIGADA_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)


func _run() -> void:
	falsificar = OS.get_environment("MV_FALSIFICAR")
	mare = root.get_node("/root/Mare")
	dia = root.get_node("/root/Dia")
	relogio = RelogioDeJogo.new()
	root.add_child(relogio)
	if falsificar != "":
		print("  FALSIFICAÇÃO: ", falsificar, " (MV_FALSIFICAR)")
	_reservar_preferencias()
	_padrao_e_migracao()
	_curva_do_lugar()
	await _vale_segue()
	_devolver_preferencias()
	if falhas == 0:
		print("MARE_LIGADA_OK: maré ligada de fábrica, migração, curva de 2,4 m com preamar às 07:00, e o vale inteiro a segue")
	quit(0 if falhas == 0 else 1)


# --- 1 e 2. O PADRÃO E A MIGRAÇÃO -------------------------------------------------

func _padrao_e_migracao() -> void:
	_conferir(mare.MODO_PADRAO == 1, "o modo de fábrica não é o 'Ciclo do lugar' (%d)" % mare.MODO_PADRAO)
	_conferir(mare.modo_de_fabrica(false, "") == mare.MODO_PADRAO, "com tela, o de fábrica não é a maré ligada")
	_conferir(mare.modo_de_fabrica(true, "") == 0, "sem tela (portões), o de fábrica não é 'Sem maré'")
	_conferir(mare.modo_de_fabrica(true, "1") == 1 and mare.modo_de_fabrica(false, "3") == 3 and mare.modo_de_fabrica(true, "9") == 3, "MV_MARE_MODO não força o modo de fábrica")

	var casos := [
		["sem arquivo nenhum", null, 1],
		["preferência de antes (modo=0 sem a marca)", {"modo": 0}, 1],
		["escolheu 'Sem maré' em AJUSTAR (escolhida)", {"modo": 0, "escolhida": true}, 0],
		["ciclo lento gravado sem a marca (só podia ser escolha)", {"modo": 2}, 2],
		["rápida escolhida", {"modo": 3, "escolhida": true}, 3],
		["valor absurdo é limitado", {"modo": 9, "escolhida": true}, 3],
	]
	for caso in casos:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TESTE_CFG))
		if caso[1] != null:
			var cfg := ConfigFile.new()
			for chave in caso[1]:
				cfg.set_value("mare", chave, caso[1][chave])
			cfg.save(TESTE_CFG)
		var modo: int = mare.modo_salvo(TESTE_CFG, mare.MODO_PADRAO)
		_conferir(modo == int(caso[2]), "%s: deu modo %d, e o esperado era %d" % [caso[0], modo, int(caso[2])])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TESTE_CFG))

	# O CAMINHO DE VERDADE (`_ready`): a preferência velha do desenvolvedor, o padrão de quem tem tela.
	OS.set_environment("MV_MARE_MODO", "1")
	_escrever_preferencias({"modo": 0})
	mare._ready()
	_conferir(mare.modo == 1, "a preferência velha (modo=0) manteve o jogo SEM maré (%d)" % mare.modo)
	mare.definir_modo(0)
	mare._ready()
	_conferir(mare.modo == 0, "quem escolheu 'Sem maré' em AJUSTAR voltou a ver maré (%d)" % mare.modo)
	var gravado := ConfigFile.new()
	gravado.load(PREFERENCIAS)
	_conferir(bool(gravado.get_value("mare", "escolhida", false)), "AJUSTAR não gravou a marca de escolha")
	mare.definir_modo(mare.MODO_PADRAO)
	OS.unset_environment("MV_MARE_MODO")


# --- 3. A CURVA --------------------------------------------------------------------

func _curva_do_lugar() -> void:
	mare.modo = 1
	if falsificar == "fase":
		mare.fase_da_preamar_h = 0.0
	var menor := 0.0
	var maior := -INF
	for meia_hora in range(0, 49):
		var n: float = mare.nivel_na_hora(meia_hora * 0.5)
		menor = minf(menor, n)
		maior = maxf(maior, n)
		_conferir(n >= -AMPLITUDE_U - 0.0001 and n <= 0.0001, "o nível às %.1f h (%.3f u) sai de [-0,6, 0]" % [meia_hora * 0.5, n])
		_conferir(absf(n - mare.nivel_na_hora(meia_hora * 0.5 + 12.0)) < 0.0001, "o período não é de 12 h às %.1f h" % [meia_hora * 0.5])
	_conferir(absf(mare.nivel_na_hora(7.0)) < 0.0001, "às 07:00 a água não está na preamar (%.3f u): o jogo abriria com a baixa-mar" % mare.nivel_na_hora(7.0))
	_conferir(absf(mare.nivel_na_hora(19.0)) < 0.0001, "às 19:00 a água não está na preamar (%.3f u)" % mare.nivel_na_hora(19.0))
	_conferir(absf(mare.nivel_na_hora(13.0) + AMPLITUDE_U) < 0.0001, "às 13:00 a água não está na baixa-mar (%.3f u)" % mare.nivel_na_hora(13.0))
	_conferir(absf(mare.nivel_na_hora(1.0) + AMPLITUDE_U) < 0.0001, "à 01:00 a água não está na baixa-mar (%.3f u)" % mare.nivel_na_hora(1.0))
	_conferir(absf(menor + AMPLITUDE_U) < 0.0001 and absf(maior) < 0.0001, "a amplitude do dia não é de 2,4 m (%.3f a %.3f u)" % [menor, maior])
	# SE VÊ: três horas de jogo (90 s no Normal) depois da abertura o mar já desceu mais de um metro.
	var desceu: float = -(mare.nivel_na_hora(10.0) - mare.nivel_na_hora(7.0)) * mare.METROS_POR_UNIDADE
	_conferir(desceu >= 1.1, "em 3 h de jogo o mar desce só %.2f m, e não se vê" % desceu)
	# Os outros ciclos: o lento é de 24 h, na mesma preamar das 07:00; "sem maré" não mexe.
	mare.modo = 2
	_conferir(absf(mare.nivel_na_hora(7.0)) < 0.0001 and absf(mare.nivel_na_hora(19.0) + AMPLITUDE_U) < 0.0001 and absf(mare.nivel_na_hora(31.0)) < 0.0001, "o ciclo lento não é de 24 h com a preamar às 07:00")
	mare.modo = 0
	_conferir(mare.nivel_na_hora(13.0) == 0.0, "'Sem maré' mexeu o nível")
	mare.modo = 1


# --- 4. O VALE SEGUE ---------------------------------------------------------------

func _vale_segue() -> void:
	# A baixa-mar de partida: a hora inicial do AJUSTAR pode ser 12:00, e o vale se monta nela.
	mare.modo = 1
	dia.pausado = true
	dia.definir_hora(13.0)
	await _frames(4)
	_conferir(absf(mare.nivel_offset() + AMPLITUDE_U) < 0.0001, "o autoload não está na baixa-mar às 13:00 (%.3f u)" % mare.nivel_offset())
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "o vale não carregou")
	await _frames(6)
	await _mundo_pronto()
	vale = current_scene
	world = vale.world
	jogador = vale.player
	dia.pausado = true
	var tubarao: Node3D = vale.get_node_or_null("Tubarao")
	var canoas: Node3D = world.get_node_or_null("Canoas")
	_conferir(tubarao != null and canoas != null and canoas.get("_canoas").size() > 0, "o vale não tem o tubarão e as canoas (%s, %s)" % [tubarao, canoas])
	var mar: Node3D = null
	for no in get_nodes_in_group("mare_superficie"):
		if String(no.name) == "Mar":
			mar = no
	_conferir(mar != null, "o plano do mar não segue a maré (nenhum nó 'Mar' no grupo mare_superficie)")
	if falsificar == "mar" and mar != null:
		mar.remove_from_group("mare_superficie")

	# Água rasa para o pé: acha, a partir do píer, um ponto de fundo raso (0,08 a 0,40 u na cheia).
	dia.definir_hora(7.0)
	await relogio.esperar(0.4)
	var nivel_cheia: float = world.water_level()
	mare.modo = 0
	await relogio.esperar(0.3)
	var nivel_de_antes: float = world.water_level()
	mare.modo = 1
	await relogio.esperar(0.3)
	_conferir(absf(nivel_cheia - nivel_de_antes) < 0.001, "às 07:00 o mar está %.3f u fora da preamar de antes da maré: a chegada do saveiro cairia fora da altura" % (nivel_cheia - nivel_de_antes))
	# OS XARÉUS SÃO POSTOS PELA CHEIA: o vale montado às 13:00, na baixa-mar (a hora inicial do AJUSTAR pode
	# ser 12:00), tem os dois pares de xaréus entre as canoas, como o montado às 07:00. Com a lâmina do instante
	# a rota deles (0,3 u de fundo) some, e o vale ficava sem eles.
	var fauna: Node = null
	for filho in vale.get_children():
		if filho.has_method("raio_de_perigo"):
			fauna = filho
	_conferir(fauna != null and fauna.get("_xareus").size() == 2, "o vale montado na baixa-mar tem %s par(es) de xaréus (devia ter 2)" % [fauna.get("_xareus").size() if fauna != null else "nenhum"])
	var raso := _achar_o_raso(nivel_cheia)
	_conferir(raso.is_finite(), "não achei fundo raso a partir do píer")
	_conferir(absf(float(world.water_depth_at(raso))) > 0.05 and not world.fundo_exposto(raso), "o raso (%s) não tem água na preamar" % [raso])
	var lamina_cheia: float = world.water_depth_at(raso)
	var chao := _chao(raso)
	jogador.teleportar(chao + Vector3.UP * 0.05, 0.0)
	await relogio.esperar(0.6)
	var pe_cheia: String = jogador.chao_dos_pes()
	_conferir(pe_cheia in ["agua", "poca"], "na preamar o chão dos pés no raso é '%s', e devia ser água rasa" % pe_cheia)
	var canoa_cheia := _maior_tombo(canoas)
	var fundos_cheia := _alturas_do_grupo()
	_conferir_a_barbatana(tubarao, "preamar")
	var materiais_cheia := _metros_nos_materiais()

	# Baixa-mar, às 13:00: passa pela vazante em passos (a hora corre), e confere o resto.
	var mudancas := [0]
	var contar := func(_o: float) -> void: mudancas[0] += 1
	mare.mare_mudou.connect(contar)
	var h := 7.0
	while h < 13.0:
		h += 0.1
		dia.definir_hora(h)
		await process_frame
	await relogio.esperar(1.4)
	mare.mare_mudou.disconnect(contar)
	_conferir(mudancas[0] > 10, "o autoload não avisou a vazante (%d avisos)" % mudancas[0])
	var nivel_baixa: float = world.water_level()
	_conferir(absf((nivel_cheia - nivel_baixa) - AMPLITUDE_U) < FOLGA, "o nível do mundo desceu %.3f u da cheia à baixa-mar, e eram %.1f" % [nivel_cheia - nivel_baixa, AMPLITUDE_U])
	_conferir(world.fundo_exposto(raso), "o raso continuou coberto na baixa-mar")
	_conferir(float(world.water_depth_at(raso)) == 0.0, "o raso (%.3f u de lâmina na cheia) ainda tem água na baixa-mar (%.3f u)" % [lamina_cheia, world.water_depth_at(raso)])
	jogador.teleportar(chao + Vector3.UP * 0.05, 0.0)
	await relogio.esperar(0.6)
	var pe_baixa: String = jogador.chao_dos_pes()
	_conferir(pe_baixa == "lama", "na baixa-mar o chão dos pés no fundo exposto é '%s', e devia ser lama" % pe_baixa)
	var fundos_baixa := _alturas_do_grupo()
	_conferir(fundos_cheia.size() >= 2 and fundos_baixa.size() == fundos_cheia.size(), "o grupo da maré tem %d nó(s), e precisa do plano do mar e da barreira da câmera (2 ou mais)" % fundos_baixa.size())
	for i in range(mini(fundos_cheia.size(), fundos_baixa.size())):
		_conferir(absf((float(fundos_cheia[i]["y"]) - float(fundos_baixa[i]["y"])) - AMPLITUDE_U) < FOLGA, "o nó '%s' do grupo da maré desceu %.3f u (e eram %.1f): o plano do mar e a barreira da câmera têm de acompanhar" % [fundos_cheia[i]["nome"], float(fundos_cheia[i]["y"]) - float(fundos_baixa[i]["y"]), AMPLITUDE_U])
	var materiais_baixa := _metros_nos_materiais()
	_conferir(materiais_cheia.size() > 0 and materiais_baixa.size() == materiais_cheia.size(), "nenhum shader recebeu a maré (%d)" % materiais_baixa.size())
	for i in range(mini(materiais_cheia.size(), materiais_baixa.size())):
		_conferir(absf(float(materiais_baixa[i]) - float(materiais_cheia[i]) + AMPLITUDE_U * mare.METROS_POR_UNIDADE) < 0.05, "o shader %d recebeu %.2f m na baixa-mar e %.2f m na cheia (devia ser -2,4 de diferença)" % [i, materiais_baixa[i], materiais_cheia[i]])
	var canoa_baixa := _maior_tombo(canoas)
	_conferir(canoa_baixa >= 0.2, "na baixa-mar nenhuma canoa encalhou (maior tombo %.2f)" % canoa_baixa)
	_conferir(canoa_cheia <= 0.15, "na preamar há canoa tombada (%.2f): a cheia não as põe a boiar" % canoa_cheia)
	print("MARE_LIGADA: preamar %.3f u / baixa-mar %.3f u · raso %s (lâmina %.2f u): %s → %s · canoa tomba %.2f → %.2f" % [nivel_cheia, nivel_baixa, raso, lamina_cheia, pe_cheia, pe_baixa, canoa_cheia, canoa_baixa])
	_conferir_a_barbatana(tubarao, "baixa-mar")

	# E volta: a enchente das 13:00 às 19:00 devolve a água cheia, e as canoas a boiar.
	h = 13.0
	while h < 19.0:
		h += 0.1
		dia.definir_hora(h)
		await process_frame
	await relogio.esperar(1.4)
	_conferir(absf(world.water_level() - nivel_cheia) < FOLGA, "às 19:00 o mar não voltou à preamar (%.3f u de diferença)" % (world.water_level() - nivel_cheia))
	_conferir(not world.fundo_exposto(raso), "o raso continuou seco na enchente")
	_conferir(_maior_tombo(canoas) <= 0.15, "na enchente as canoas continuam encalhadas")


## O primeiro ponto de uma varredura a partir do píer, em linha reta para o mar, onde o corpo de pé está
## coberto por 0,06 a 0,30 u de água na preamar (o chão que ele pisa, e não só a batimetria desenhada) e onde a
## lâmina desenhada deixa o fundo seco na baixa-mar de 0,6 u.
func _achar_o_raso(nivel_cheia: float) -> Vector3:
	var seguinte: Vector3 = world.ancoras["PierDirecao"]
	var lado := Vector3(-seguinte.z, 0.0, seguinte.x) * 6.0
	var inicio: Vector3 = world.ancoras["PierPiso"] - seguinte * 10.0 + lado
	for passo in range(0, 400):
		var p: Vector3 = inicio + seguinte * float(passo)
		if world.water_depth_at(p) < 0.05 or not _tem_chao(p):
			continue
		var coberto: float = nivel_cheia - _chao(p).y
		if coberto >= 0.06 and coberto <= 0.30:
			return p
	return Vector3(INF, INF, INF)


func _tem_chao(ponto: Vector3) -> bool:
	var espaco := root.get_world_3d().direct_space_state
	return not espaco.intersect_ray(PhysicsRayQueryParameters3D.create(ponto + Vector3.UP * 30.0, ponto - Vector3.UP * 30.0, 1)).is_empty()


func _chao(ponto: Vector3) -> Vector3:
	var espaco := root.get_world_3d().direct_space_state
	var bateu := espaco.intersect_ray(PhysicsRayQueryParameters3D.create(ponto + Vector3.UP * 30.0, ponto - Vector3.UP * 30.0, 1))
	return bateu["position"] if not bateu.is_empty() else world.ground_position(ponto)


## [{"nome", "y"}] de cada nó que acompanha a maré (o plano do mar, a barreira da câmera), em ordem de nome.
func _alturas_do_grupo() -> Array:
	var lista: Array = []
	for no in get_nodes_in_group("mare_superficie"):
		lista.append({"nome": String(no.name), "y": (no as Node3D).position.y})
	lista.sort_custom(func(a, b) -> bool: return String(a["nome"]) < String(b["nome"]))
	return lista


## O que os shaders registrados na maré leram como `mare_offset_m` (metros), em ordem estável: o
## plano do mar, o leito, a areia da praia.
func _metros_nos_materiais() -> Array:
	var metros: Array = []
	var materiais: Array = mare.get("_materiais")
	for ref in materiais:
		var material := (ref as WeakRef).get_ref() as ShaderMaterial
		if material != null:
			metros.append(float(material.get_shader_parameter("mare_offset_m")))
	return metros


## O maior tombo (rotação em z) das canoas: o que o encalhe mexe no casco.
func _maior_tombo(canoas: Node3D) -> float:
	var maior := 0.0
	for canoa in canoas.get("_canoas"):
		maior = maxf(maior, absf((canoa as Node3D).rotation.z))
	return maior


## A barbatana do tubarão corta a superfície DO MOMENTO (a maré mexe no nível): à vista e ativo, ele está
## na altura da água. (Na baixa-mar ele pode estar escondido — `_submerso` —, e aí não há o que medir.)
func _conferir_a_barbatana(tubarao: Node3D, onde: String) -> void:
	if tubarao.visible and bool(tubarao.get("_ativo")) and not bool(tubarao.get("_submerso")):
		var y := tubarao.global_position.y
		_conferir(absf(y - float(world.water_level())) < 0.08, "na %s a barbatana está a %.3f u e a superfície a %.3f" % [onde, y, world.water_level()])


# --- apoio -------------------------------------------------------------------------

func _reservar_preferencias() -> void:
	_havia_arquivo = FileAccess.file_exists(PREFERENCIAS)
	if _havia_arquivo:
		_reserva = FileAccess.get_file_as_bytes(PREFERENCIAS)


func _devolver_preferencias() -> void:
	if _havia_arquivo:
		var arquivo := FileAccess.open(PREFERENCIAS, FileAccess.WRITE)
		if arquivo != null:
			arquivo.store_buffer(_reserva)
			arquivo.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PREFERENCIAS))


func _escrever_preferencias(mare_secao: Dictionary) -> void:
	var cfg := ConfigFile.new()
	for chave in mare_secao:
		cfg.set_value("mare", chave, mare_secao[chave])
	cfg.save(PREFERENCIAS)


func _frames(quantos: int) -> void:
	for i in range(quantos):
		await process_frame


## O vale se monta ao longo de vários quadros (world_builder): espera ficar pronto.
func _mundo_pronto() -> void:
	for i in range(3000):
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
