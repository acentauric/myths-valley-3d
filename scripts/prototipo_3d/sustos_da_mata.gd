extends RefCounted
## OS SUSTOS DA MATA — a chave, os textos, o som e a montagem dos dois sustos: o vulto que "fecha o
## jogo" (`fantasma_da_mata.gd`) e as pegadas do Curupira que enlouquecem o mapa (`rastro_do_curupira.gd`,
## `loucura_do_mapa.gd`).
##
## A CHAVE ("Sustos", em AJUSTAR → Cenário) fica em `user://preferencias_visuais.cfg`, [interface] sustos.
## Nasce LIGADA; na edição Tripothon nasce DESLIGADA: quem avalia o jogo não pode ver "o jogo fechou" —
## e liga, se quiser, em AJUSTAR. `--sem-sustos` desliga por linha de comando, seja qual for a escolha.
##
## Sem `class_name`: quem usa carrega com `preload`. Este arquivo NÃO carrega os nós dos sustos (a
## `montar` os carrega na hora), para o vulto e o rastro poderem carregá-lo sem laço de preload.

const PREFERENCIAS := "user://preferencias_visuais.cfg"
const SECAO := "interface"
const CHAVE := "sustos"
const ARGUMENTO_PARA_DESLIGAR := "--sem-sustos"
const ARQUIVO_DE_TEXTOS := "res://data/sustos.json"
const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")

## Para os portões: -1 pergunta ao motor se é a edição Tripothon; 0 diz que não é; 1 diz que é.
static var forcar_edicao := -1


static func e_tripothon() -> bool:
	return OS.has_feature("tripothon") if forcar_edicao < 0 else forcar_edicao == 1


## O que a chave vale antes de o jogador escolher: ligada, menos na edição Tripothon.
static func padrao_de_fabrica() -> bool:
	return not e_tripothon()


static func ligado() -> bool:
	if ARGUMENTO_PARA_DESLIGAR in OS.get_cmdline_user_args():
		return false
	var preferencias := ConfigFile.new()
	if preferencias.load(PREFERENCIAS) != OK:
		return padrao_de_fabrica()
	return bool(preferencias.get_value(SECAO, CHAVE, padrao_de_fabrica()))


static func definir_ligado(valor: bool) -> void:
	var preferencias := ConfigFile.new()
	preferencias.load(PREFERENCIAS)
	preferencias.set_value(SECAO, CHAVE, valor)
	if preferencias.save(PREFERENCIAS) != OK:
		push_warning("Não foi possível salvar a preferência dos sustos.")


## Um texto de `data/sustos.json` ("avisos" → chave) no idioma do jogador (campo, campo_en, campo_es).
static func texto(chave: String) -> String:
	var dados: Variant = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO_DE_TEXTOS))
	if not (dados is Dictionary):
		return ""
	var avisos: Dictionary = (dados as Dictionary).get("avisos", {})
	var entrada: Variant = avisos.get(chave, {})
	return str(IdiomaMenu.campo(entrada if entrada is Dictionary else {}, "texto", ""))


## Som de um efeito do jogo, POSICIONAL: um tocador 3D descartável em `onde`, com o arquivo e o volume
## do `Audio` (o mesmo controle de AJUSTAR → Efeitos, e o mudo, porque o `Audio` leva todo tocador novo
## para o barramento Geral). `seguir` o prende ao `pai`, para andar junto com o vulto.
static func tocar_3d(pai: Node3D, nome: String, onde: Vector3, alcance: float = 90.0, ajuste_db: float = 0.0, seguir: bool = false) -> AudioStreamPlayer3D:
	var caminho: String = Audio.arquivo_do_efeito(nome)
	if caminho == "":
		return null
	var fluxo := load(caminho) as AudioStream
	if fluxo == null:
		return null
	var tocador := AudioStreamPlayer3D.new()
	tocador.stream = fluxo
	tocador.max_distance = alcance
	tocador.unit_size = alcance * 0.16
	tocador.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	tocador.volume_db = Audio.volume_efeitos_db() + ajuste_db
	var destino: Node = pai if seguir else pai.get_tree().current_scene
	destino.add_child(tocador)
	tocador.global_position = onde
	tocador.finished.connect(tocador.queue_free)
	tocador.play()
	return tocador


## O vale está LIVRE para um susto? Nada na tela (menu, ajustes, painel, mapa, mochila, almanaque,
## fala, cartão do amanhecer), nenhum morador falando ou festa de missão (o relógio segurado), o jogador
## andando por conta própria e fora de casa. `jogo` é a cena do vale (`prototype.gd`).
static func jogo_livre(jogo: Node) -> bool:
	if jogo == null or not jogo.is_inside_tree() or jogo.get_tree().paused or bool(jogo.get("_saindo")):
		return false
	var jogador: Variant = jogo.get("player")
	if jogador == null or not jogador.is_physics_processing() or String(jogador.dentro_de) != "":
		return false
	var painel: Variant = jogo.get("painel")
	if painel != null and bool(painel.aberto):
		return false
	var telas: Variant = jogo.get("telas")
	if telas != null and String(telas.aberta()) != "":
		return false
	var mapa: Variant = jogo.get("mapa")
	if mapa != null and bool(mapa.aberto):
		return false
	var menu: Variant = jogo.get("menu_pausa")
	if menu != null and bool(menu.aberto):
		return false
	var hud: Variant = jogo.get("hud")
	if hud != null and (bool(hud.settings_open()) or bool(hud.menu_confirm_open())):
		return false
	# O cartão de "primeira vez" e a pergunta do relógio também seguram o jogador: são telas que o vale não registra.
	var aviso: Variant = jogo.get("aviso_da_primeira_vez")
	if aviso != null and bool(aviso.aberto()):
		return false
	if jogo.get("_pergunta_do_relogio") != null:
		return false
	return not (Dialogo.ocupado() or Amanhecer.aberto or Dia.segurado())


## Monta os sustos no vale: o nó da loucura do mapa, o rastro do Curupira e o vulto, ligados aos avisos
## do HUD e ao som. Chamado uma vez pelo `prototype.gd`, no fim da montagem dos moradores.
static func montar(jogo: Node3D) -> void:
	var mundo: Variant = jogo.get("world")
	var jogador: Variant = jogo.get("player")
	var hud: Variant = jogo.get("hud")
	var livre := func() -> bool: return jogo_livre(jogo)
	var loucura := Node.new()
	loucura.set_script(load("res://scripts/prototipo_3d/loucura_do_mapa.gd"))
	loucura.name = "LoucuraDoMapa"
	jogo.add_child(loucura)
	# O que o jogador ouve e lê quando o mapa enlouquece, e quando o norte volta.
	loucura.comecou.connect(func() -> void:
		hud.set_notice(texto("mapa_doido"))
		await jogo.get_tree().create_timer(1.2).timeout
		Audio.efeito("mapa_doido"))
	loucura.acabou.connect(func() -> void: hud.set_notice(texto("mapa_voltou")))
	var rastro := Node3D.new()
	rastro.set_script(load("res://scripts/prototipo_3d/rastro_do_curupira.gd"))
	rastro.name = "RastroDoCurupira"
	jogo.add_child(rastro)
	rastro.configurar(mundo, jogador, loucura, livre)
	# O aviso do sinal vem DEPOIS do aviso do mapa doido (o rodapé tem um recado só): dá tempo de ler o primeiro.
	rastro.anotou.connect(func() -> void:
		await jogo.get_tree().create_timer(6.0).timeout
		if is_instance_valid(hud):
			hud.set_notice(texto("sinal_anotado")))
	var vulto := Node3D.new()
	vulto.set_script(load("res://scripts/prototipo_3d/fantasma_da_mata.gd"))
	vulto.name = "FantasmaDaMata"
	jogo.add_child(vulto)
	var pedro: Variant = jogo.get("pedro")
	vulto.configurar(mundo, jogador, livre,
		func() -> bool: return pedro == null or bool(pedro.terminou_o_tutorial()),
		jogo.get_node_or_null("Luta"))
