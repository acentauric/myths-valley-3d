extends Node3D
## Cena do vale: cenário, jogador, HUD, som do lugar, moradores e o Pedro guia.
## Estilo visual (Tripo/Procedural), hora do dia e velocidade do tempo vêm dos
## autoloads Estilo e Dia, ajustados no menu (AJUSTAR).

const NPCS := "res://data/npcs_3d.json"
const TeclasMovimento = preload("res://scripts/prototipo_3d/teclas_movimento.gd")
const TelaCarregamento = preload("res://scripts/prototipo_3d/tela_carregamento.gd")
const TemaMenu = preload("res://scripts/prototipo_3d/tema_menu.gd")
const MapaJogo = preload("res://scripts/prototipo_3d/mapa_jogo.gd")
const Lapides = preload("res://scripts/prototipo_3d/lapides.gd")
const ArvoresInfo = preload("res://scripts/prototipo_3d/arvores_info.gd")
const PlacasNomes = preload("res://scripts/prototipo_3d/placas_nomes.gd")
const Tubarao = preload("res://scripts/prototipo_3d/tubarao.gd")
const Queda = preload("res://scripts/prototipo_3d/queda.gd")
const LutaVale = preload("res://scripts/prototipo_3d/luta_vale.gd")
const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")
const PainelVale = preload("res://scripts/prototipo_3d/painel_vale.gd")
const BancadasVale = preload("res://scripts/prototipo_3d/bancadas_vale.gd")
const ColecaoVale = preload("res://scripts/prototipo_3d/colecao_vale.gd")
const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")
const CameraMouse = preload("res://scripts/prototipo_3d/camera_mouse.gd")
const Recursos3D = preload("res://scripts/prototipo_3d/recursos_3d.gd")
const Minimapa = preload("res://scripts/prototipo_3d/minimapa.gd")
const CadeiaDeMissoes = preload("res://scripts/prototipo_3d/cadeia_de_missoes.gd")
const TelasDoVale = preload("res://scripts/prototipo_3d/telas_do_vale.gd")
const MenuPausa = preload("res://scripts/prototipo_3d/menu_pausa.gd")
const MENU_SCENE := "res://scenes/prototipo_3d/abertura.tscn"
## Raio de terra firme em volta do ponto de chegada.
const RAIO_CHEGADA := 6.0
const PERIODOS := {"madrugada": "Madrugada", "manha": "Manhã", "tarde": "Tarde", "entardecer": "Entardecer", "noite": "Noite"}

@onready var player = $Jogador
@onready var hud = $HUD
@onready var world = $Cenario
var ambiente: AmbienteVale
## A MISSÃO EM CURSO DO VALE MUDOU, venha ela de quem vier.
##
## O Pedro era o único que dava missão, então o HUD, a seta e o minimapa
## escutavam o `pedro.missao_mudou` — três closures presas a um morador. Com o
## Damião dando a segunda cadeia, isso viraria seis, e a terceira cadeia nove.
##
## Agora é um relé: cada cadeia despeja aqui, e os três consumidores escutam
## este sinal. Cadeia nova é uma linha, e não três.
##
## Quando duas cadeias estão abertas, vale a ÚLTIMA que anunciou — que é a que
## o jogador acabou de ouvir, e é a resposta certa para "o que eu estou
## fazendo agora".
signal missao_do_vale_mudou(texto: String, alvo: Vector3, indice: int, total: int)

var pedro: GuiaPedro
var moradores: Array[MoradorNPC] = []
var _visited: Dictionary = {}
var _step_time := 0.0
var pegadas_no	# pegadas.gd — pool de marcas dos passos no chão
var _saindo := false
var mapa	# mapa_jogo.gd
var _recursos  # recursos_3d.gd — os alvos de trabalho (troncos, lajedos)
var lapides	# lapides.gd
## Modo de câmera de antes da pausa, para o retorno devolver o que havia.
## As filas de missão penduradas em moradores, por id do morador — para o save
## e para quem precise achá-las. A do Pedro NÃO está aqui: ela mora dentro do
## `guia_pedro.gd` e é salva pelo nome antigo (`pedro.missao`), que o save do
## vale já guardava antes de existir a segunda cadeia.
var _cadeias: Dictionary = {}
var _camera_travada_antes := false
var _relogio_pausado_antes := false
var painel	# painel_vale.gd — tecla J
var colecao	# colecao_vale.gd — sem tecla: virou seção do almanaque
## Dono único das telas: só uma fica aberta. Ver telas_do_vale.gd.
var telas
## O menu do Esc, com o que era a coluna de ícones. Ver menu_pausa.gd.
var menu_pausa
## As plaquinhas de nome dos moradores; somem com tela aberta (placas_nomes.gd).
var placas
## A aba pedida no último `abrir_o_painel`, entregue à abertura crua.
var _aba_pedida := 0


func _enter_tree() -> void:
	# Movimento: WASD, setas ou os dois, conforme AJUSTAR → Geral.
	TeclasMovimento.aplicar()
	_bind("mv_run", [KEY_SHIFT])
	# O `mv_release` no Esc SAIU daqui. Ele soltava o mouse, e era a causa da
	# queixa de "tenho que clicar e arrastar": quem apertava Esc procurando o
	# menu caía no modo de arrastar sem saber por quê. O Esc agora é o menu, e
	# a ação ficou sem uso nenhum — ação órfã com tecla é convite para alguém
	# religá-la sem saber por que ela foi desligada.
	# Atalhos remapeáveis (AJUSTAR → Geral → Atalhos); o Tab da câmera é fixo.
	_bind("mv_cursor", [KEY_TAB, Atalhos.tecla("camera")], true)
	_bind("mv_reset", [Atalhos.tecla("reiniciar")])
	_bind("mv_inspect", [Atalhos.tecla("observar")])
	_bind("mv_time", [Atalhos.tecla("hora")])
	_bind("mv_mapa", [Atalhos.tecla("mapa")])
	# A MOCHILA no I, como no jogo 2D e como no gênero (Palworld, Stardew,
	# Cyberpunk usam I ou Tab). O Tab aqui já é a câmera, então fica o I.
	_bind("mv_mochila", [KEY_I])
	# O ALMANAQUE DAS PLANTAS pela tabela de atalhos, e não numa letra fixa.
	#
	# Ele morava no `KEY_L` escrito aqui, porque L é a coleção do 2D. Aí a
	# coleção de verdade chegou ao vale, TAMBÉM no L, e as duas telas ficaram
	# na mesma tecla — coisa que a tabela existe para impedir e não podia, com
	# o almanaque passando por fora dela. Agora ele está lá dentro, de fábrica
	# no K, e remapeável como os outros.
	_bind("mv_almanaque", [Atalhos.tecla("almanaque")])
	# OS NÚMEROS PASSARAM A SER A BARRA DE MÃO, e os gestos foram para Alt.
	#
	# 1 a 0 põem item na mão, como no jogo 2D — é a barra que o jogador procura
	# quando ganha um machado, e ela não pode estar ocupada por animação de
	# demonstração. Os gestos não se perderam: ficaram em Alt+1 a Alt+8, no
	# mesmo número de sempre, para quem os conhece continuar achando.
	for index in range(8):
		_bind_alt("mv_animation_%d" % (index + 1), KEY_1 + index)
	for index in range(10):
		# O zero é o DÉCIMO espaço, como em Minecraft e como no 2D: é onde a
		# mão vai sozinha depois de anos de outro jogo.
		_bind("mv_mao_%d" % (index + 1), [KEY_1 + index if index < 9 else KEY_0])
	_bind("mv_animation_9", [KEY_SPACE], true)


func _ready() -> void:
	Audio.parar_narracao()
	Audio.tocar_musica()
	# O vale se monta ao longo de vários quadros (world_builder), com a tela de
	# carregamento por cima; o resto da cena depende dele. Até lá o jogador não cai.
	if not world.construido:
		set_process(false)
		player.set_physics_process(false)
		await world.pronto
		set_process(true)
		player.set_physics_process(true)
	# Vindo do menu, o relógio esperou a montagem na hora_inicial (abertura._start_game).
	Dia.congelado_na_carga = false
	var spawn: Vector3 = _ponto_de_chegada()
	player.spawn_position = spawn
	player.global_position = spawn
	player.configure_click_world(world)
	player.capture_changed.connect(hud.set_captured)
	player.camera_lock_changed.connect(hud.set_camera_locked)
	player.animation_requested.connect(_on_animation_requested)
	player.navigation_status.connect(hud.set_notice)
	hud.camera_lock_requested.connect(player.set_camera_locked)
	world.house_interacted.connect(func(properties: Dictionary): hud.show_house_info(world.format_house_properties(properties)))
	world.house_interaction_cleared.connect(hud.clear_house_info)
	hud.house_info_close_requested.connect(world.clear_house_interaction)
	hud.menu_prompt_requested.connect(_ask_return_to_menu)
	hud.menu_requested.connect(_return_to_menu)
	hud.menu_cancelled.connect(_on_menu_cancelled)
	mapa = MapaJogo.new()
	mapa.name = "Mapa"
	add_child(mapa)
	hud.map_requested.connect(_toggle_map)
	hud.settings_requested.connect(_open_settings)
	hud.settings_closed.connect(_on_menu_cancelled)
	hud.style_changed.connect(func() -> void:
		# Novo estilo visual: reconstrói o vale inteiro, com a tela de carregamento.
		get_tree().paused = false
		# Os ajustes tinham parado o relógio; ele volta como estava antes de abri-los.
		Dia.pausado = _relogio_pausado_antes
		_saindo = true
		# Trocar o estilo RECARREGA o vale, e o vale recarregado lê a vaga:
		# sem salvar aqui, o jogador voltaria ao último save.
		Partida.salvar()
		var barra := TelaCarregamento.mostrar(hud.map_layer(), TemaMenu.criar(), tr("Trocando o estilo do vale…"))
		TelaCarregamento.trocar_cena(get_tree(), scene_file_path, barra))
	lapides = Lapides.new()
	lapides.name = "Lapides"
	add_child(lapides)
	lapides.configurar(world, player, hud)
	var arvores := ArvoresInfo.new()
	arvores.name = "ArvoresInfo"
	add_child(arvores)
	arvores.configurar(world, player, hud)
	# ONDE BATER: os troncos e lajedos que respondem à ferramenta. Vem depois
	# das árvores porque usa o mesmo alcance e a mesma dica, e quem estiver
	# perto dos dois tem de ver a dica do que dá para fazer, não a da ficha.
	var recursos := Recursos3D.new()
	recursos.name = "Recursos3D"
	add_child(recursos)
	recursos.configurar(world, player, hud)
	recursos.recusado.connect(func(motivo: String) -> void: hud.set_notice(motivo))
	recursos.derrubado.connect(_ao_derrubar)
	_recursos = recursos
	# AS TELAS DO VALE, num dono só.
	#
	# Cada uma cuidava da própria tecla, em cinco arquivos, e nenhuma sabia das
	# outras: apertar a do almanaque com o painel aberto abria o almanaque ATRÁS
	# dele, e fechá-lo devolvia a câmera solta — porque a gaveta do modo de
	# câmera é uma só e as duas telas escreveram nela. Ver `telas_do_vale.gd`.
	#
	# Agora só uma fica aberta, e a pausa e a câmera acontecem AQUI, num lugar,
	# quando o dono avisa que a tela mudou.
	telas = TelasDoVale.new()
	telas.name = "TelasDoVale"
	add_child(telas)
	telas.registrar("mochila",
		func(e: InputEvent) -> bool: return e.is_action_pressed("mv_mochila"),
		func() -> bool: return Mochila.aberta,
		func() -> void: Mochila.abrir(),
		func() -> void: Mochila.fechar())
	if hud.almanaque() != null:
		var alm: Control = hud.almanaque()
		telas.registrar("almanaque",
			func(e: InputEvent) -> bool: return e.physical_keycode == Atalhos.tecla("almanaque"),
			func() -> bool: return alm.aberto(),
			func() -> void: alm.abrir(),
			func() -> void: alm.fechar())
	telas.registrar("painel",
		func(e: InputEvent) -> bool: return e.physical_keycode == Atalhos.tecla("painel"),
		func() -> bool: return painel != null and painel.aberto,
		_abrir_painel_cru,
		func() -> void: if painel != null: painel.fechar())
	telas.registrar("colecao",
		# A COLEÇÃO NÃO TEM MAIS TECLA: ela virou seção do almanaque, que ficou com
		# o L. A tela dela continua de pé e continua registrada aqui — o portão da
		# câmera a abre por este dono —, mas nenhuma tecla a chama.
		func(_e: InputEvent) -> bool: return false,
		func() -> bool: return colecao != null and colecao.aberta,
		_abrir_colecao_crua,
		func() -> void: if colecao != null: colecao.fechar())
	# O MENU DO ESC, com o que estava na coluna de ícones do canto esquerdo.
	#
	# "Os ícones na esquerda do HUD podem ser todos dentro do menu ESC." Eram
	# nove botões redondos empilhados na borda, por cima do vale, o tempo todo —
	# e sem rótulo: o do som era um desenho diferente ligado e desligado, e só
	# passando o mouse se descobria qual era qual. Em linha, com o estado
	# escrito, "Som: ligado" responde as duas perguntas de uma vez.
	#
	# As linhas são declaradas AQUI e não lá dentro, porque quem sabe pausar o
	# relógio e trocar o estilo é esta casa. O menu só desenha, lê o rótulo e
	# chama. Mesma costura do `telas_do_vale.gd`.
	menu_pausa = MenuPausa.new()
	menu_pausa.name = "MenuPausa"
	add_child(menu_pausa)
	menu_pausa.definir([
		{"rotulo": "Voltar ao vale", "icone": "fechar", "fecha": true,
			"fazer": func() -> void: pass},
		{"rotulo": "Mapa do vale", "icone": "mapa", "fecha": true,
			"fazer": func() -> void: _toggle_map()},
		{"rotulo": "Ajustes", "icone": "ajustes", "fecha": true,
			"fazer": func() -> void: _open_settings()},
		{"rotulo": "Controles", "icone": "ajuda", "fecha": true,
			"fazer": func() -> void: hud.set_controls_open(not hud.controls_open())},
		# SALVAR COMO NO 2D: devolve recado, porque dá certo e a tela fica igual,
		# e ação sem retorno é a que se aperta três vezes. As três respostas são
		# as do painel do J, que já as trouxe de lá — sem vaga não salva, salvou
		# na vaga tal, ou não salvou e a de antes continua onde estava.
		{"rotulo": "Salvar jogo", "icone": "restaurar",
			"fazer": func() -> String:
				if not Partida.tem_vaga():
					return "Este passeio não tem vaga, e por isso não salva. Para guardar, escolha uma vaga em JOGAR."
				if Partida.salvar():
					return "Partida guardada na vaga %d." % Salvamento.slot_atual
				return "Não consegui salvar. A partida que estava na vaga continua lá."},
		{"rotulo": func() -> String: return "Som: %s" % ("ligado" if Audio.som_ativo else "desligado"),
			"icone": "som",
			"fazer": func() -> void: Audio.definir_som_ativo(not Audio.som_ativo)},
		{"rotulo": func() -> String: return "Relógio: %s" % ("andando" if not Dia.pausado else "parado"),
			"icone": "relogio",
			"fazer": func() -> void:
				if not Dia.pausa_no_jogo:
					Audio.efeito("ui_trava")
					return
				Audio.efeito("ui_confirmar")
				# O relógio fica como o jogador deixou, e não como o menu o
				# achou: é ele que o dono das telas vai devolver ao fechar.
				_relogio_pausado_antes = not _relogio_pausado_antes},
		{"rotulo": func() -> String: return "Velocidade do tempo: %s" % Dia.ROTULOS_VELOCIDADE[Dia.velocidade],
			"icone": "velocidade",
			"fazer": func() -> void:
				Dia.definir_velocidade((Dia.velocidade + 1) % Dia.VELOCIDADES.size())},
		{"rotulo": func() -> String: return "Câmera do mouse: %s" % ("arrastar" if _camera_travada_antes else "livre"),
			"icone": "camera",
			"fazer": func() -> void:
				# Troca a gaveta, e não a câmera de agora: com o menu aberto o
				# cursor está solto de propósito, e é a gaveta que o fechamento
				# devolve. Mexer na câmera aqui seria desfeito um quadro depois.
				_camera_travada_antes = not _camera_travada_antes
				CameraMouse.definir(CameraMouse.ARRASTAR if _camera_travada_antes else CameraMouse.LIVRE)},
		# AS DUAS SAÍDAS, embaixo e em destaque. Sair do vale não é do mesmo tipo
		# que trocar o volume, e a separação e a cor dizem isso antes de o texto
		# ser lido.
		{"rotulo": "Voltar ao menu inicial", "icone": "casa", "fecha": true, "saida": true,
			"fazer": func() -> void: _ask_return_to_menu()},
		{"rotulo": "Sair do jogo", "icone": "externo", "fecha": true, "saida": true,
			"fazer": func() -> void:
				Partida.salvar()
				get_tree().quit()},
	] as Array[Dictionary])
	telas.registrar("menu_pausa",
		# O Esc já é cuidado pelo dono das telas: com tela aberta ele fecha, e
		# sem nada aberto cai na escada do `_unhandled_key_input` daqui, que é
		# quem pede este menu. Então esta linha não reclama tecla nenhuma.
		func(_e: InputEvent) -> bool: return false,
		func() -> bool: return menu_pausa.aberto,
		func() -> void: menu_pausa.abrir(),
		func() -> void: menu_pausa.fechar())
	telas.tela_mudou.connect(func(_nome: String, aberta: bool) -> void:
		if aberta:
			_pause_valley()
		else:
			_retomar_o_vale()
		# As plaquinhas de nome dos moradores somem com a tela aberta: elas
		# moram no mesmo Control do HUD que o almanaque e a barra, e entram
		# depois — "o nome do Pedro tá sobrescrevendo os MENUs". Ver
		# `placas_nomes.gd`.
		if placas != null:
			placas.permitir(not aberta))
	# O VALE ABRE NO MODO DE CÂMERA ESCOLHIDO (AJUSTAR → Geral → Câmera do
	# mouse). Era sempre livre, e quem preferia arrastar tinha de apertar a
	# tecla da câmera toda vez que entrava.
	player.set_camera_locked(CameraMouse.travada())
	hud.set_region_title(world.get_region_title())
	if Estilo.procedural():
		hud.set_model_status("Estilo procedural: personagem, casas e árvores por código")
		hud.set_telemetry("Procedural · 1,78 m")
	else:
		var viajante := "viajante do Tripo" if player.model != null and player.model.scene_file_path.ends_with("viajante_tripo.glb") else "personagem GLB provisório"
		hud.set_model_status("Estilo Tripo: modelos do Tripo Studio (%s)" % viajante)
		hud.set_telemetry("Tripo · 1,78 m")
	hud.set_objective("Fale com Pedro: ele veio te esperar no píer.")
	hud.set_notice("Bom Jesus dos Pobres, 1887 · 1 unidade = %s m" % _formatar(world.get_meters_per_unit()))
	_montar_som()
	_montar_moradores(spawn)
	for morador in moradores:
		var quem := String(morador.dados.get("id", ""))
		if quem == "damiao":
			lapides.coveiro = morador
			_pendurar_cadeia(morador, "res://data/missoes_coveiro.json", 4.0)
		elif quem == "filo":
			_pendurar_cadeia(morador, "res://data/missoes_filo.json", 4.0)
	Dia.periodo_mudou.connect(_on_periodo_mudou)
	# A PARTIDA SALVA entra depois de o vale estar montado — moradores, Pedro,
	# luta —, porque o estado do mundo aponta para eles. Ver Partida e
	# `estado_para_salvar`.
	Salvamento.registrar_mundo(self)
	_retomar_a_partida()
	_comecar_no_lugar_pedido()
	_atualizar_relogio()
	print("PROTOTYPE_READY: estilo=%s hora=%s moradores=%d user_dir=%s" % [Estilo.modo, Dia.texto_hora(), moradores.size(), OS.get_user_data_dir()])


## O jogador chega de barco: começa no píer, de frente para a praça.
func _ponto_de_chegada() -> Vector3:
	var spawn: Vector3 = world.get_spawn_position()
	if world.ancoras.has("Pier") and world.ancoras.has("Praça"):
		var pier: Vector3 = world.ancoras["Pier"]
		var praca: Vector3 = world.ancoras["Praça"]
		var direcao: Vector3 = praca - pier
		direcao.y = 0.0
		spawn = world.ground_position(pier + direcao.normalized() * 7.5, 0.07)
		# Desde o relevo do mapa geográfico, 7,5 m do píer ainda caem na passarela sobre
		# a água: avança rumo à praça até um ponto com terra firme em volta, para o
		# primeiro passo não sair da passarela e cair no mar.
		var distancia := direcao.length()
		var passo := 7.5
		while passo < distancia:
			var candidato: Vector3 = pier + direcao.normalized() * passo
			if _terra_em_volta(candidato, RAIO_CHEGADA):
				spawn = world.ground_position(candidato, 0.07)
				break
			passo += 1.0
	return spawn


## Centro e oito pontos num raio em terra firme.
func _terra_em_volta(centro: Vector3, raio: float) -> bool:
	if not world.is_on_land(centro):
		return false
	for indice in range(8):
		var borda := centro + Vector3.FORWARD.rotated(Vector3.UP, TAU * indice / 8.0) * raio
		if not world.is_on_land(borda):
			return false
	return true


func _montar_som() -> void:
	ambiente = AmbienteVale.new()
	ambiente.name = "Ambiente"
	add_child(ambiente)
	if world.ancoras.has("Pier"):
		ambiente.fonte("mar", AmbienteVale.MAR, world.ancoras["Pier"], 60.0, 2.0)
	for chave in ["Rio", "Rio 2"]:
		if world.ancoras.has(chave):
			ambiente.fonte("riacho", AmbienteVale.RIACHO, world.ancoras[chave], 26.0, -2.0)
	if world.ancoras.has("Fogueira"):
		ambiente.fonte("fogueira", AmbienteVale.FOGUEIRA, world.ancoras["Fogueira"] + Vector3(0, 0.5, 0), 16.0, 0.0, true)


func _montar_moradores(spawn: Vector3) -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(NPCS))
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("Moradores 3D: arquivo inválido " + NPCS)
		return
	# Ajustes do painel PERSONAGENS (nome, altura, voz, falas, postos) por cima.
	data = AjustesConteudo.npcs(data)
	for entry in data.get("moradores", []):
		var morador := MoradorNPC.new()
		morador.configurar(entry, world.ancoras, player, world)
		add_child(morador)
		morador.saudou.connect(_on_saudacao)
		moradores.append(morador)
	# O objetivo do HUD é o primeiro freguês do relé.
	missao_do_vale_mudou.connect(_on_missao_mudou)
	var guia: Dictionary = data.get("guia", {})
	if not guia.is_empty():
		pedro = GuiaPedro.new()
		pedro.configurar(guia, world.ancoras, player, world)
		add_child(pedro)
		var lado: Vector3 = Vector3(-1.6, 0, 1.4)
		pedro.global_position = world.ground_position(spawn + lado, 0.05)
		pedro.saudou.connect(_on_saudacao)
		pedro.missao_mudou.connect(func(t: String, a: Vector3, i: int, n: int) -> void:
			missao_do_vale_mudou.emit(t, a, i, n))
		# OS ALVOS DE TRABALHO, para o marcador apontar o tronco e não a casa.
		pedro.recursos = _recursos
		pedro.narrou.connect(func(texto: String) -> void: hud.set_notice("Pedro: " + texto))
	placas = PlacasNomes.new()
	placas.name = "PlacasNomes"
	add_child(placas)
	placas.configurar(player, hud.map_layer())
	# Seta da missão: cone e anel no mundo + chevron na borda da tela seguem o alvo.
	var seta := SetaMissao.new()
	seta.name = "SetaMissao"
	add_child(seta)
	seta.configurar(hud.map_layer())
	missao_do_vale_mudou.connect(func(texto: String, destino: Vector3, indice: int, total: int) -> void:
		if indice >= total:
			seta.limpar()
		else:
			seta.definir_alvo(destino, texto))
	# Tubarão da parte funda: persegue só o jogador nadando no fundo; o susto vai ao HUD.
	var tubarao := Tubarao.new()
	tubarao.name = "Tubarao"
	add_child(tubarao)
	tubarao.configurar(world, player, func(texto: String) -> void: hud.set_notice(texto))
	# Vida no chão é noite no chão: quem cai acorda na porta de casa (queda.gd).
	var queda := Queda.new()
	queda.name = "Queda"
	add_child(queda)
	queda.configurar(world, player, hud)
	# A luta e o caititu da mata (luta_vale.gd). Entra depois das lápides e das
	# árvores: com bicho perto, o E é dela antes de ser delas.
	var luta := LutaVale.new()
	luta.name = "Luta"
	add_child(luta)
	luta.configurar(world, player, hud)
	# O painel da tecla J (painel_vale.gd), por cima do HUD.
	painel = PainelVale.new()
	painel.name = "Painel"
	add_child(painel)
	painel.abriu.connect(_parar_o_jogador)
	painel.fechou.connect(_soltar_o_jogador)
	painel.pediu.connect(_ao_pedido_do_painel)
	# A coleção da tecla L (colecao_vale.gd), no mesmo andar do painel.
	colecao = ColecaoVale.new()
	colecao.name = "Colecao"
	add_child(colecao)
	colecao.abriu.connect(_parar_o_jogador)
	colecao.fechou.connect(_soltar_o_jogador)
	# Quem está lendo não perde vida: a peçonha espera o painel fechar (ver
	# Vida.esta_lendo). Por método, que deixa de valer quando o vale sai.
	Vida.esta_lendo = Callable(self, "_lendo")
	# Pegadas do jogador no chão, por terreno, sumindo com o tempo.
	pegadas_no = preload("res://scripts/prototipo_3d/pegadas.gd").new()
	pegadas_no.name = "Pegadas"
	add_child(pegadas_no)

	# Minimapa do canto inferior esquerdo, com o alvo da missão do Pedro.
	var minimapa := Minimapa.new()
	minimapa.name = "Minimapa"
	hud.map_layer().add_child(minimapa)
	minimapa.configurar(player, pedro, hud)
	missao_do_vale_mudou.connect(func(_texto: String, alvo: Vector3, indice: int, total: int) -> void:
		if indice >= total or alvo == Vector3.ZERO:
			minimapa.limpar_alvo()
		else:
			minimapa.definir_alvo(alvo))


func _process(_delta: float) -> void:
	# Passos no ritmo do clipe do jogador (o intervalo sai da animação), com o som do
	# chão sob os pés; nadando, uma braçada por meio ciclo do nado.
	_step_time -= _delta
	var andando: bool = Vector2(player.velocity.x, player.velocity.z).length() > 0.3
	if andando and (player.is_on_floor() or player.is_swimming()):
		if _step_time <= 0:
			if player.is_swimming():
				Audio.passo("nado")
			else:
				var chao: String = player.chao_dos_pes()
				Audio.passo(chao, player.is_running())
				# A pegada usa o mesmo chão do som, no mesmo passo.
				if pegadas_no != null:
					pegadas_no.marcar(player.global_position, player.visual.rotation.y, chao, player.is_running())
			_step_time = player.step_interval()
	else:
		_step_time = 0
	for landmark: Dictionary in world.landmarks:
		var landmark_id: String = landmark["id"]
		var landmark_name: String = landmark["name"]
		var destination: Vector3 = landmark["position"]
		if not _visited.has(landmark_id) and player.global_position.distance_to(destination) < 7.0:
			_visited[landmark_id] = true
			hud.set_notice("Você chegou: %s  ·  %d/%d pontos explorados" % [landmark_name, _visited.size(), world.landmarks.size()])
	_atualizar_relogio()


func _atualizar_relogio() -> void:
	hud.set_clock("%s\n%s" % [Dia.texto_hora(), PERIODOS.get(Dia.periodo(), "")])


func _on_periodo_mudou(periodo: String) -> void:
	if not is_inside_tree():
		return
	match periodo:
		"entardecer":
			hud.set_notice("O sol vai baixando. Os lampiões da praça acendem logo mais.")
		"noite":
			hud.set_notice("Noite no arraial: só lampião, candeeiro e a fogueira do terreiro.")
		"manha":
			hud.set_notice("Amanheceu. A mata acorda com as aves do Recôncavo.")


func _on_saudacao(morador: MoradorNPC, texto: String) -> void:
	hud.set_notice("%s: %s" % [String(morador.dados.get("nome", "Morador")), texto])


## A MISSÃO EM CURSO, e QUANTO FALTA em linha separada.
##
## Antes a conta vinha grudada no texto — "Fale com o Damião  (3/9)" —, e ela
## voltava a aparecer a cada reanúncio no meio de uma frase que o jogador já
## estava lendo. Agora a frase é só a frase, e a conta mora ao lado do nome da
## região, onde ela não disputa a leitura.
func _on_missao_mudou(texto: String, _alvo: Vector3, indice: int, total: int) -> void:
	hud.set_objective(texto)
	hud.set_mission_step(indice, total)


func _bind(action: StringName, keys: Array, replace_existing := false) -> void:
	if InputMap.has_action(action):
		if not replace_existing:
			return
		InputMap.action_erase_events(action)
	else:
		InputMap.add_action(action)
	for key: int in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)


func _unhandled_key_input(event: InputEvent) -> void:
	# Durante a montagem do vale (tela de carregamento) mapa e HUD ainda não existem; na
	# saída, abrir o mapa esconderia a tela de carregamento, que é filha do HUD.
	if mapa == null or _saindo:
		return
	# Tela aberta: as teclas são dela, inclusive a que fecha (J, L).
	if _lendo():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		# O J E O L SAÍRAM DAQUI, junto com o Esc que fechava tela. Quem cuida
		# de abrir e fechar tela é o `telas_do_vale.gd`, num lugar só, porque
		# abrir uma tem de FECHAR A OUTRA — e cinco arquivos cada um cuidando da
		# própria tecla não têm como saber disso.
		if event.physical_keycode == KEY_ESCAPE:
			# ESC É O MENU, que é o que todo jogo do gênero faz — Palworld,
			# Stardew, Witcher 3, Cyberpunk, todos.
			#
			# A ordem é a da convenção: primeiro ESC FECHA O QUE ESTÁ ABERTO, e
			# só com tudo fechado ele abre o menu. É uma escada, e o degrau de
			# cima não mora aqui: tela aberta é fechada pelo dono das telas
			# (`telas_do_vale.gd`), que consome o Esc antes de ele chegar nesta
			# função. O que chega até aqui é o mapa, e depois dele o vale sem
			# nada aberto.
			#
			# E o menu agora é o `menu_pausa`, com as nove linhas que eram a
			# coluna de ícones do canto — e não mais a caixa de "voltar ao
			# menu?", que virou UMA das linhas dele.
			if mapa.aberto:
				_toggle_map()
			elif telas != null:
				telas.abrir("menu_pausa")
		elif event.is_action_pressed("mv_mapa"):
			# M (remapeável) abre o mapa do vale; o HOME fica no botão da coluna do canto.
			_toggle_map()
		elif event.is_action_pressed("mv_time"):
			Dia.avancar(1.0)
			hud.set_notice("Relógio adiantado: %s (%s)" % [Dia.texto_hora(), PERIODOS.get(Dia.periodo(), "")])


## Botão de mapa (ou Esc com ele aberto): vista de cima do vale. O jogador fica parado
## e o mundo continua (moradores, relógio).
func _toggle_map() -> void:
	var abrir: bool = not mapa.aberto
	player.set_physics_process(not abrir)
	player.set_process_input(not abrir)
	player.set_process_unhandled_input(not abrir)
	hud.set_map_open(abrir)
	if abrir:
		# LEMBRA O MODO ANTES DE SOLTAR O CURSOR, e devolve ao fechar.
		#
		# Era a queixa "voltei do mapa e a câmera estava destravada, como se eu
		# tivesse apertado C". O mapa solta o cursor porque mapa sem cursor não
		# se navega — e não devolvia nada depois. É o mesmo defeito que o menu
		# tinha, no lugar de que ninguém desconfia.
		_camera_travada_antes = player.camera_travada()
		player.set_captured(false)
		mapa.abrir(world, player, hud.map_layer())
	else:
		mapa.fechar()
		player.set_camera_locked(_camera_travada_antes)


## Engrenagem do canto: ajustes com o vale e o relógio pausados (fechar retoma).
func _open_settings() -> void:
	if hud.settings_open() or hud.menu_confirm_open() or _saindo:
		return
	if mapa.aberto:
		_toggle_map()
	_pause_valley()
	hud.open_settings()


func _pause_valley() -> void:
	# LEMBRA O MODO DE CÂMERA ANTES DE SOLTAR O CURSOR.
	#
	# Era aqui o defeito de "depois do Esc o jogo volta com a câmera solta sem
	# eu apertar C": pausar solta o cursor, porque menu com o mouse preso é
	# menu que não se clica — mas nada devolvia o modo depois. Quem jogava no
	# modo livre voltava do menu no modo de arrastar, sem ter pedido.
	_camera_travada_antes = player.camera_travada()
	player.set_captured(false)
	_relogio_pausado_antes = Dia.pausado
	Dia.pausado = true
	get_tree().paused = true


## Desfaz o `_pause_valley`, INCLUSIVE a câmera.
func _retomar_o_vale() -> void:
	get_tree().paused = false
	Dia.pausado = _relogio_pausado_antes
	player.set_camera_locked(_camera_travada_antes)


## HOME ou M: pausa o vale (e o relógio) e pergunta antes de sair.
func _ask_return_to_menu() -> void:
	if hud.menu_confirm_open() or hud.settings_open() or _saindo:
		return
	if mapa.aberto:
		_toggle_map()
	_pause_valley()
	hud.open_menu_confirm()


func _on_menu_cancelled() -> void:
	_retomar_o_vale()


## Volta ao menu com a tela de carregamento (o menu monta o vale de novo ao abrir).
func _return_to_menu() -> void:
	if _saindo:
		return
	_saindo = true
	Partida.salvar()
	get_tree().paused = false
	player.set_captured(false)
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	var barra: ProgressBar = hud.show_loading()
	TelaCarregamento.trocar_cena(get_tree(), MENU_SCENE, barra)


func _on_animation_requested(label: String) -> void:
	hud.set_notice("Gesto: %s · mova o personagem para interromper" % label)


func _formatar(meters_per_unit: float) -> String:
	if is_equal_approx(meters_per_unit, roundf(meters_per_unit)):
		return str(int(roundf(meters_per_unit)))
	return String.num(meters_per_unit, 2)


## Um tronco ou lajedo caiu: conta no HUD e avisa quem estiver contando.
##
## O aviso diz O QUE ENTROU NA MOCHILA, e não "derrubou": o jogador acabou de
## gastar fôlego e precisa ver o que ganhou com isso. É a mesma escolha do 2D,
## onde a checklist mostra "Tábuas 3/5" em vez de "faltam 2".
func _ao_derrubar(_id: String, rende: String, quantidade: int) -> void:
	var item: Dictionary = Catalogo.ITENS.get(rende, {})
	hud.set_notice("%s ×%d" % [str(item.get("nome", rende)), quantidade])


## Como `_bind`, mas com o Alt segurado — é o que move os gestos para fora dos
## números, que agora são a barra de mão.
func _bind_alt(action: StringName, key: int) -> void:
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
	else:
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.alt_pressed = true
	InputMap.action_add_event(action, event)
# --- a partida ----------------------------------------------------------------

## A vaga em curso tem partida? Então ela volta: sistemas, jogador, hora,
## Pedro, o que o vale lembra. Sem vaga (EXPLORAR) ou vaga nova, o vale começa
## do píer, como sempre.
func _retomar_a_partida() -> void:
	if not Partida.tem_vaga() or not Salvamento.existe_partida():
		return
	var guardado := Salvamento.ler()
	if guardado.is_empty():
		# Há arquivo e ele não abriu: partida de uma versão mais nova. O arquivo
		# não é tocado; o jogador fica sabendo, em vez de achar a vila do zero.
		if not Salvamento.ultimo_relato.is_empty():
			hud.set_notice(" ".join(Salvamento.ultimo_relato))
		return
	if Salvamento.carregar(guardado):
		hud.set_notice(_texto_da_partida("de_volta"))
		if not Salvamento.ultimo_relato.is_empty():
			hud.set_notice(" ".join(Salvamento.ultimo_relato))


func _texto_da_partida(chave: String) -> String:
	var dado = JSON.parse_string(FileAccess.get_file_as_string("res://data/partida.json"))
	var entrada: Dictionary = dado.get(chave, {}) if dado is Dictionary else {}
	return str(IdiomaMenu.campo(entrada, "texto", chave))


## O QUE O VALE ENTREGA AO SAVE. Os sistemas (mochila, vida, calendário...)
## são autoloads e o `Salvamento` os guarda sozinho; isto é o que só a cena
## sabe. A hora vai aqui, e não só em `Relogio.minutos`: no vale quem manda na
## hora é o `Dia`, e o `Relogio` só a espelha (ver dia.gd).
func estado_para_salvar() -> Dictionary:
	var estado := {
		"jogador": [player.global_position.x, player.global_position.y, player.global_position.z],
		"giro": player.visual.rotation.y,
		"hora": Dia.hora,
		"visitados": _visited.keys(),
	}
	# AS FILAS DOS OUTROS MORADORES, e os alvos que já caíram.
	#
	# A do Pedro já ia (`pedro`, logo abaixo), porque ele era o único que dava
	# missão. Com o Damião dando a segunda, missão não salva é missão que o
	# jogador faz duas vezes — ou, no caso do capim, que ele termina e volta a
	# dever ao recarregar.
	#
	# Os alvos caídos vão junto pelo mesmo motivo: a meta de "derrubar" conta
	# pé DERRUBADO, e pé que renasceu com o vale não conta. Sem esta lista, o
	# jogador corta os quatro, salva, volta, e o capim está de pé outra vez com
	# o passo ainda aberto.
	var cadeias := {}
	for id in _cadeias:
		var c = _cadeias[id]
		# `levados` vai junto porque entrega é ACONTECIMENTO, não estado: depois
		# dela a mochila está vazia, e mochila vazia é indistinguível de "nunca
		# pegou". Sem esta memória, recarregar reabriria o passo pedindo um pirão
		# que já foi entregue e não existe mais.
		cadeias[id] = {"missao": c.missao, "iniciado": c.iniciado,
			"despedida": c.despedida_feita, "levados": c._levados.keys()}
	estado["cadeias"] = cadeias
	if _recursos != null:
		estado["caidos"] = _recursos.caidos()
	if pedro != null:
		estado["pedro"] = {"missao": pedro.missao, "iniciado": pedro.get("_iniciado"),
			"despedida": pedro.get("_despedida_feita")}
	var luta := get_node_or_null("Luta")
	if luta != null:
		estado["mortes"] = luta.mortes.duplicate(true)
	return estado


func restaurar_do_save(estado: Dictionary) -> void:
	var onde: Array = estado.get("jogador", [])
	if onde.size() == 3:
		var ponto := Vector3(float(onde[0]), float(onde[1]), float(onde[2]))
		player.global_position = world.ground_position(ponto, 0.07) if world.is_on_land(ponto) else ponto
		player.velocity = Vector3.ZERO
		player.visual.rotation.y = float(estado.get("giro", player.visual.rotation.y))
	if estado.has("hora"):
		Dia.definir_hora(float(estado["hora"]))
	_visited.clear()
	for chave in estado.get("visitados", []):
		_visited[str(chave)] = true
	# As filas dos outros moradores voltam com um respiro antes do anúncio, como
	# a do Pedro: quem recarrega ouve de novo o passo em que parou, em vez de
	# ficar olhando um objetivo que ninguém explicou.
	var cadeias: Dictionary = estado.get("cadeias", {})
	for id in cadeias:
		if not _cadeias.has(id):
			continue
		var c = _cadeias[id]
		var guardado: Dictionary = cadeias[id]
		c.iniciado = bool(guardado.get("iniciado", false))
		c.despedida_feita = bool(guardado.get("despedida", false))
		c.missao = int(guardado.get("missao", -1))
		c._levados.clear()
		for passo in guardado.get("levados", []):
			c._levados[str(passo)] = true
		c.espera = 1.4
	# OS ALVOS CAÍDOS SOMEM DE NOVO, e é aqui e não antes: o vale se monta
	# inteiro primeiro (`_erguer`), e só então o save diz o que já tinha caído.
	if _recursos != null:
		_recursos.esquecer(estado.get("caidos", []))
	var guia: Dictionary = estado.get("pedro", {})
	if pedro != null and not guia.is_empty():
		pedro.set("_iniciado", bool(guia.get("iniciado", false)))
		pedro.set("_despedida_feita", bool(guia.get("despedida", false)))
		pedro.missao = int(guia.get("missao", -1))
		# Ele reanuncia o passo em que parou, logo depois de chegar perto.
		pedro.set("_espera", 1.4)
		pedro.global_position = world.ground_position(player.global_position + Vector3(-1.6, 0, 1.4), 0.05)
	var luta := get_node_or_null("Luta")
	if luta != null:
		luta.restaurar_mortes(estado.get("mortes", []))


## DEPURAÇÃO: `-- --lugar=<nome>` começa o jogador direto num lugar do
## `Lugares` (praca, igreja, cemiterio, mirante...), sem refazer o caminho.
## Vem depois da partida salva: pedir um lugar é pedir para ir lá agora.
func _comecar_no_lugar_pedido() -> void:
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--lugar="):
			continue
		var nome := arg.substr("--lugar=".length())
		if not Lugares.resolve(nome):
			push_warning("--lugar=%s: o vale não tem esse lugar. Há: %s" % [nome, ", ".join(Lugares.nomes())])
			return
		player.global_position = world.ground_position(Lugares.ponto(nome), 0.07)
		player.velocity = Vector3.ZERO
		if pedro != null:
			pedro.global_position = world.ground_position(player.global_position + Vector3(-1.6, 0, 1.4), 0.05)
		print("DEPURACAO: começando em %s" % nome)
		return


func _notification(what: int) -> void:
	# Fechar a janela salva, como voltar ao menu: o vale não tem cama, e sem
	# isto quem fecha o jogo perde o dia.
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Partida.salvar()


# --- o painel -----------------------------------------------------------------

## Abre o painel com as abas do lugar onde o jogador está (bancadas_vale.gd).
## Abre o painel com as abas do lugar onde o jogador está (bancadas_vale.gd).
##
## PEDE AO DONO DAS TELAS, e não abre por fora dele: é o dono que fecha a tela
## que estiver aberta, pausa o vale e guarda a câmera. Quem abrir direto pula
## tudo isso — e foi por aí que o almanaque apareceu atrás do painel.
func abrir_o_painel(aba: int = 0) -> void:
	_aba_pedida = aba
	if telas != null:
		telas.abrir("painel")


func abrir_a_colecao() -> void:
	if telas != null:
		telas.abrir("colecao")


## A abertura CRUA das duas, que é o que o dono das telas chama. Ninguém mais
## deve chamá-las: elas não pausam nada e não mexem na câmera.
func _abrir_painel_cru() -> void:
	if painel == null or _lendo() or mapa.aberto or _saindo:
		return
	BancadasVale.aplicar(painel, world, player.global_position)
	painel.abrir(_aba_pedida)
	_aba_pedida = 0


func _abrir_colecao_crua() -> void:
	if colecao == null or _lendo() or mapa.aberto or _saindo:
		return
	colecao.abrir()


## COM UMA TELA ABERTA, O JOGADOR PARA — e SÓ isso.
##
## Este par já fez mais: guardava o modo de câmera, soltava o cursor e pausava
## a árvore. Fazia certo, e mesmo assim era errado, porque o `telas_do_vale.gd`
## passou a fazer o mesmo para TODAS as telas. Dois lugares guardando a mesma
## gaveta (`_camera_travada_antes`) é um deles escrevendo por cima do outro: o
## painel guardava "travada", o dono guardava logo depois o que achava — que já
## era "solta", porque o painel tinha acabado de soltar —, e fechar devolvia
## solta. O portão da câmera pegou, e a mensagem foi exatamente essa.
##
## Câmera, cursor, relógio e pausa da árvore são do dono das telas. Aqui ficou
## o que é do corpo do jogador: ele para de andar e de ouvir tecla.
func _parar_o_jogador() -> void:
	player.set_physics_process(false)
	player.set_process_input(false)
	player.set_process_unhandled_input(false)


func _soltar_o_jogador() -> void:
	player.set_physics_process(true)
	player.set_process_input(true)
	player.set_process_unhandled_input(true)


func _ao_pedido_do_painel(acao: String) -> void:
	match acao:
		"menu":
			_return_to_menu()
		"sair":
			Partida.salvar()
			get_tree().quit()
		"destravar":
			player._back_to_land()


## Alguma tela de leitura aberta? É o que a peçonha pergunta (Vida.esta_lendo).
func _lendo() -> bool:
	return (painel != null and painel.aberto) or (colecao != null and colecao.aberta)


func _exit_tree() -> void:
	if Vida.esta_lendo == Callable(self, "_lendo"):
		Vida.esta_lendo = Callable()
	# O save não fica segurando um vale que saiu da árvore. Hoje não quebraria
	# (o Godot compara o objeto liberado igual a null, e o Salvamento pergunta
	# `_mundo != null`), mas é essa a comparação de que ele deixa de depender.
	Salvamento.registrar_mundo(null)


## PENDURA UMA FILA DE MISSÕES NUM MORADOR QUALQUER.
##
## É o que faz o vale ter mais de um dono de missão. Até aqui só o Pedro dava
## — a fila morava dentro do `guia_pedro.gd` —, e o jogo 2D não é assim: lá a
## Dona Zefa manda um recado, o Damião pede um cabo de foice, o Tonho cobra
## uma dívida. Agora é uma linha por morador.
##
## A cadeia se move sozinha (`cadeia_de_missoes.gd`), abre quando o jogador
## chega a `perto` unidades do morador, e despeja no relé — de onde o HUD, a
## seta e o minimapa já escutam.
##
## Os alvos de trabalho vão junto: sem eles o marcador aponta a âncora do
## lugar em vez do pé de capim, que foi a queixa "marca a casa quando devia
## marcar os troncos".
func _pendurar_cadeia(morador: MoradorNPC, arquivo: String, perto: float) -> Node:
	var cadeia := CadeiaDeMissoes.new()
	cadeia.name = "CadeiaDeMissoes"
	cadeia.dono = morador
	cadeia.jogador = player
	cadeia.recursos = _recursos
	cadeia.comeca_perto_de = perto
	# QUEM É O MORADOR DE TAL ID, respondido por esta casa, que é a que tem a
	# lista. A meta "levar" precisa disso para achar quem recebe.
	cadeia.achar_morador = func(quem: String) -> Node3D:
		for outro in moradores:
			if String(outro.dados.get("id", "")) == quem:
				return outro
		if pedro != null and quem == "pedro":
			return pedro
		return null
	if not cadeia.carregar(arquivo):
		cadeia.free()
		return null
	cadeia.missao_mudou.connect(func(t: String, a: Vector3, i: int, n: int) -> void:
		missao_do_vale_mudou.emit(t, a, i, n))
	morador.add_child(cadeia)
	_cadeias[str(morador.dados.get("id", ""))] = cadeia
	return cadeia
