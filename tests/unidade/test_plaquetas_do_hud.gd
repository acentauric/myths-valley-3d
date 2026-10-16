extends "res://tests/unidade/base.gd"
## CADA BOTÃO DA COLUNA DO CANTO MOSTRA A TECLA DO SEU ATALHO, E ACOMPANHA O REMAPEAMENTO (#254).
##
##     .\tools\prototipo_3d\testar.ps1 -Teste plaquetas_do_hud
##
## Na Build 11 o autor viu a plaquinha "I" no botão do MAPA e nenhuma no do que ele tomava por mochila (era o cubo do FPS),
## com o Pedro dizendo "o I abre a mochila". A leitura estava certa — a plaqueta lê o atalho do próprio botão, e o
## `controles.cfg` do autor tinha o mapa no I e a mochila no M —, mas faltavam três coisas, que este teste cobra:
##
##   1. CADA BOTÃO LÊ O SEU ATALHO: o do mapa mostra a letra do mapa, o da câmera a da câmera, o do diário a do painel, o da
##      mochila a da mochila; nenhum outro botão da coluna tem plaqueta, e nenhuma letra se repete.
##   2. REMAPEAR ATUALIZA A PLAQUETA DO BOTÃO CERTO, na hora (o HUD só lia a letra ao montar a coluna): o mapa no I dá o M à
##      mochila, e cada plaqueta segue o dono da letra; restaurar o padrão devolve as quatro.
##   3. A COLUNA TEM UM BOTÃO DE FPS SÓ, e nenhum botão cobre outro. O de FPS criava um segundo botão por cima do HOME (o
##      HOME não recebia o clique) e deixava outro, com o cubo, na coluna.
##
## O teste grava as letras no `controles.cfg`, e por isso só roda no perfil descartável do `testar.ps1`.

const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")

## O ícone de cada botão com plaqueta, e o atalho que ela lê.
const ATALHO_DO_ICONE := {"mapa": "mapa", "camera": "camera", "missoes": "painel", "mochila": "mochila"}


func before_each() -> void:
	super()
	Atalhos._cache.clear()


func after_each() -> void:
	if Estado.perfil_descartavel():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Atalhos.ARQUIVO))
		Atalhos._cache.clear()
		Atalhos.aplicar()


func _hud() -> Node:
	var hud: Node = load("res://scripts/prototipo_3d/prototype_hud.gd").new()
	pendurar(hud)
	return hud


## Os botões da coluna do HUD, por tipo de ícone: {tipo: {canto, botao, marca}}. O som e o FPS não têm tipo de ícone: ficam como "sem_ícone_<vaga>".
func _coluna() -> Dictionary:
	var achados := {}
	for canto: Control in get_tree().get_nodes_in_group("botoes_canto"):
		var icone: Control = canto.get_meta("icone")
		var tipo := str(icone.get("tipo")) if icone.get("tipo") != null else "sem_ícone_%d" % int(canto.get_meta("posicao"))
		var botao: Button = canto.get_meta("botao")
		achados[tipo] = {"canto": canto, "botao": botao, "marca": botao.get_node_or_null("TeclaDeAtalho")}
	return achados


## Toda plaqueta da coluna diz a letra do atalho do botão dela; os botões sem atalho não têm plaqueta.
func _conferir_a_coluna(rotulo: String) -> void:
	var coluna := _coluna()
	var letras := {}
	for tipo: String in coluna:
		var marca: Label = coluna[tipo]["marca"]
		if ATALHO_DO_ICONE.has(tipo):
			_conferir(marca != null, "%s: o botão '%s' não tem plaqueta de tecla" % [rotulo, tipo])
			if marca == null:
				continue
			var acao: String = ATALHO_DO_ICONE[tipo]
			_conferir(marca.text == Atalhos.letra(acao),
				"%s: a plaqueta do botão '%s' diz '%s', e o atalho '%s' é a letra '%s'" % [rotulo, tipo, marca.text, acao, Atalhos.letra(acao)])
			_conferir(not letras.has(marca.text), "%s: a letra '%s' está em duas plaquetas ('%s' e '%s')" % [rotulo, marca.text, str(letras.get(marca.text, "")), tipo])
			letras[marca.text] = tipo
		else:
			_conferir(marca == null, "%s: o botão '%s' não tem atalho e mostra a plaqueta '%s'" % [rotulo, tipo, marca.text if marca != null else ""])
	for tipo: String in ATALHO_DO_ICONE:
		_conferir(coluna.has(tipo), "%s: a coluna não tem o botão '%s'" % [rotulo, tipo])


func test_cada_botao_mostra_a_tecla_do_seu_atalho() -> void:
	if not exige_perfil_descartavel():
		return
	var hud := _hud()
	await process_frame
	_conferir_a_coluna("de fábrica")
	# De fábrica: o mapa no M e a mochila no I, nos botões certos.
	var coluna := _coluna()
	if coluna.has("mapa") and coluna.has("mochila"):
		_conferir((coluna["mapa"]["marca"] as Label).text == "M" and (coluna["mochila"]["marca"] as Label).text == "I",
			"de fábrica o botão do mapa devia dizer M e o da mochila, I (dizem '%s' e '%s')" % [(coluna["mapa"]["marca"] as Label).text, (coluna["mochila"]["marca"] as Label).text])
	hud.queue_free()


func test_remapear_atualiza_a_plaqueta_do_botao_certo() -> void:
	if not exige_perfil_descartavel():
		return
	var hud := _hud()
	await process_frame
	# O perfil do autor: o mapa no I, e a mochila herda o M. Cada plaqueta segue o dono da letra.
	Atalhos.definir("mapa", KEY_I)
	Atalhos.aplicar()
	await process_frame
	_conferir_a_coluna("mapa no I")
	var coluna := _coluna()
	_conferir((coluna["mapa"]["marca"] as Label).text == "I" and (coluna["mochila"]["marca"] as Label).text == "M",
		"com o mapa no I o botão do mapa devia dizer I e o da mochila, M (dizem '%s' e '%s')" % [(coluna["mapa"]["marca"] as Label).text, (coluna["mochila"]["marca"] as Label).text])
	# A câmera numa letra que era de outra ação (a teia de talentos, K): a troca leva o C para ela, e só a câmera muda de plaqueta.
	Atalhos.definir("camera", KEY_K)
	Atalhos.aplicar()
	await process_frame
	_conferir_a_coluna("câmera no K")
	_conferir(((_coluna()["camera"]["marca"]) as Label).text == "K", "o botão da câmera devia dizer K")
	# O diário numa letra livre.
	Atalhos.definir("painel", KEY_Y)
	Atalhos.aplicar()
	await process_frame
	_conferir_a_coluna("painel no Y")
	# Restaurar o padrão (o que a tela de Controles faz, ação por ação) devolve as quatro.
	for acao: String in Atalhos.DEFINICOES:
		Atalhos.definir(acao, int(Atalhos.DEFINICOES[acao]["padrao"]))
	Atalhos.aplicar()
	await process_frame
	_conferir_a_coluna("padrão restaurado")
	var de_novo := _coluna()
	_conferir((de_novo["mapa"]["marca"] as Label).text == "M" and (de_novo["camera"]["marca"] as Label).text == "C"
			and (de_novo["missoes"]["marca"] as Label).text == "J" and (de_novo["mochila"]["marca"] as Label).text == "I",
		"restaurado o padrão as plaquetas devem ser M, C, J e I")
	hud.queue_free()


func test_o_medidor_enxerga_a_plaqueta_velha() -> void:
	# A falsificação do teste: com o HUD sem o quadro que refaz as plaquetas (`set_process(false)`), remapear deixa a
	# plaqueta com a letra antiga — o medidor tem de enxergá-la; ligado o quadro, ela se refaz.
	if not exige_perfil_descartavel():
		return
	var hud := _hud()
	await process_frame
	hud.set_process(false)
	Atalhos.definir("mapa", KEY_I)
	Atalhos.aplicar()
	await process_frame
	var marca: Label = _coluna()["mapa"]["marca"]
	_conferir(marca.text != Atalhos.letra("mapa"), "sem o quadro do HUD a plaqueta do mapa já devia estar velha ('%s' contra '%s'): o medidor não distingue" % [marca.text, Atalhos.letra("mapa")])
	hud.set_process(true)
	await process_frame
	_conferir(marca.text == Atalhos.letra("mapa"), "ligado o quadro do HUD a plaqueta do mapa devia se refazer ('%s' contra '%s')" % [marca.text, Atalhos.letra("mapa")])
	hud.queue_free()


func test_a_coluna_tem_um_botao_de_fps_e_nenhum_cobre_outro() -> void:
	var hud := _hud()
	await process_frame
	await process_frame
	var cantos: Array[Control] = []
	var vagas := {}
	for canto: Control in get_tree().get_nodes_in_group("botoes_canto"):
		cantos.append(canto)
		var vaga := int(canto.get_meta("posicao"))
		_conferir(not vagas.has(vaga), "dois botões na vaga %d da coluna (o segundo por cima do primeiro)" % vaga)
		vagas[vaga] = canto
	for i in cantos.size():
		for j in range(i + 1, cantos.size()):
			_conferir(not cantos[i].get_global_rect().intersects(cantos[j].get_global_rect()),
				"o botão da vaga %d cobre o da vaga %d" % [int(cantos[i].get_meta("posicao")), int(cantos[j].get_meta("posicao"))])
	var contadores: Array[Node] = hud._root.find_children("FPS", "Label", true, false)
	_conferir(contadores.size() == 1, "a coluna tem %d botões com o número do FPS, e devia ter um" % contadores.size())
	# Esse botão é o que abre o painel de desempenho, e mora na coluna (vem junto da dica, na lista da narração).
	var botao: Button = hud._performance_button
	_conferir(botao != null and hud._corner_nodes.has(botao.get_parent()), "o botão de FPS não é um dos botões da coluna do canto")
	# O HOME (o ícone da casa) está livre: nada, nem o número do FPS, fica por cima dele.
	var casa: Dictionary = _coluna().get("casa", {})
	_conferir(not casa.is_empty(), "a coluna não tem o botão HOME")
	if not casa.is_empty():
		var rect: Rect2 = (casa["canto"] as Control).get_global_rect()
		_conferir(not (contadores[0] as Control).get_global_rect().intersects(rect), "o número do FPS cobre o botão HOME")
	hud.queue_free()
