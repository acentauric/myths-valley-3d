extends Node3D
## Cena do vale: cenário, jogador, HUD, som do lugar, moradores e o Pedro guia.
## Estilo visual (Tripo/Procedural), hora do dia e velocidade do tempo vêm dos
## autoloads Estilo e Dia, ajustados no menu (AJUSTAR).

const NPCS := "res://data/npcs_3d.json"
const TeclasMovimento = preload("res://scripts/prototipo_3d/teclas_movimento.gd")
const MarcosDaFe = preload("res://scripts/prototipo_3d/marcos_da_fe.gd")
const CaixaDePergunta = preload("res://scripts/prototipo_3d/caixa_de_pergunta.gd")
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
const AchadosVale = preload("res://scripts/prototipo_3d/achados_vale.gd")
const PescaVale = preload("res://scripts/prototipo_3d/pesca_vale.gd")
const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")
const CameraMouse = preload("res://scripts/prototipo_3d/camera_mouse.gd")
const Recursos3D = preload("res://scripts/prototipo_3d/recursos_3d.gd")
const Minimapa = preload("res://scripts/prototipo_3d/minimapa.gd")
const CadeiaDeMissoes = preload("res://scripts/prototipo_3d/cadeia_de_missoes.gd")
const TelasDoVale = preload("res://scripts/prototipo_3d/telas_do_vale.gd")
const MenuPausa = preload("res://scripts/prototipo_3d/menu_pausa.gd")
const TelaControles = preload("res://scripts/prototipo_3d/tela_controles.gd")
const TeiaTalentos = preload("res://scripts/prototipo_3d/teia_talentos.gd")
const TeiaSocial = preload("res://scripts/prototipo_3d/teia_social.gd")
const Retratos3D = preload("res://scripts/prototipo_3d/retratos_3d.gd")
const Interiores = preload("res://scripts/prototipo_3d/interiores.gd")
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
var _arvores_info	# arvores_info.gd — saúde e regeneração dos coqueiros
## Modo de câmera de antes da pausa, para o retorno devolver o que havia.
## As filas de missão penduradas em moradores, por id do morador — para o save
## e para quem precise achá-las. A do Pedro NÃO está aqui: ela mora dentro do
## `guia_pedro.gd` e é salva pelo nome antigo (`pedro.missao`), que o save do
## vale já guardava antes de existir a segunda cadeia.
var _cadeias: Dictionary = {}
var _relogio_pausado_antes := false
## A pergunta da tecla de adiantar a hora, enquanto está aberta.
var _pergunta_do_relogio = null
## OS MARCOS DE FÉ (#52): o cruzeiro, a igreja, a capela velha, o cemitério, o
## terreiro e a gameleira — e o que acontece neles (`marcos_da_fe.gd`).
var marcos: Node
## A seta da missão acompanhada (seta_missao.gd).
var _seta
## O que o HUD diz quando o caderno não tem missão aberta: o convite do começo,
## e depois o fim da última cadeia. Ver `_on_missao_mudou`.
var _objetivo_sem_missao := "Fale com Pedro: ele veio te esperar no píer."
## Foi a fala longa que parou o vale? Ver `_ao_abrir_a_fala`.
var _fala_parou_o_vale := false
## O cordel que o folheto vai abrir, e a tela a que ele volta. Ver `ler_o_folheto`.
var _folheto_a_ler := ""
var _voltar_do_folheto := ""
var painel	# painel_vale.gd — tecla J
## Dono único das telas: só uma fica aberta. Ver telas_do_vale.gd.
var telas
## O menu do Esc, com o que era a coluna de ícones. Ver menu_pausa.gd.
var menu_pausa
## A tela de Controles, aberta pelo menu do Esc. Ver tela_controles.gd.
var tela_controles
## A teia de talentos, na tecla K (teia_talentos.gd).
var teia
## A teia social do arraial, na tecla P (teia_social.gd).
var social
## O estúdio dos retratos 3D dos moradores (retratos_3d.gd).
var retratos
## As construções por dentro (interiores.gd).
var interiores
## As plaquinhas de nome dos moradores; somem com tela aberta (placas_nomes.gd).
var placas
## A aba pedida no último `abrir_o_painel`, entregue à abertura crua.
var _aba_pedida := 0
var _machado_inicial_entregue := false
var achados	# achados_vale.gd — cordéis, sinais e cartas no chão
var pesca	# pesca_vale.gd — a vara na mão e o E na beira da água


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
	# Cyberpunk usam I ou Tab). O Tab aqui já é a câmera, então fica o I — de
	# fábrica, pela tabela de atalhos, remapeável como as outras telas (#4).
	_bind("mv_mochila", [Atalhos.tecla("mochila")], true)
	# O TECLADO DE DENTRO DA MOCHILA (#2). Ela é tela do 2D e escuta as ações
	# do `Controles` de lá — `equipar`, `interagir`, `cancelar`, `mover_*` —,
	# que o vale não tinha: F, E e as setas não faziam nada dentro dela, e
	# cada tecla imprimia erro de ação inexistente. Só o mouse funcionava.
	#
	# E e F FIXOS, e não pela tabela de atalhos: o rodapé da mochila escreve
	# "[E] arrumar · [F] vestir ou comer", e o arquivo é compartilhado — não se
	# muda daqui. Com ela aberta o vale está parado, então o E e o F de fora
	# não disputam a tecla. As setas e o WASD, como nas outras telas.
	_bind("equipar", [KEY_F], true)
	_bind("interagir", [KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER], true)
	_bind("cancelar", [KEY_ESCAPE], true)
	_bind("mover_cima", [KEY_W, KEY_UP], true)
	_bind("mover_baixo", [KEY_S, KEY_DOWN], true)
	_bind("mover_esquerda", [KEY_A, KEY_LEFT], true)
	_bind("mover_direita", [KEY_D, KEY_RIGHT], true)
	# O ZOOM SAIU DA RODA, que agora troca o item da mão como no 2D (#2). Fica
	# no mais e no menos — as duas fileiras, e o igual junto do mais, porque
	# em ABNT2 e US o mais mora no shift do igual — e no Ctrl+roda.
	_bind("mv_zoom_in", [KEY_EQUAL, KEY_PLUS, KEY_KP_ADD], true)
	_bind("mv_zoom_out", [KEY_MINUS, KEY_KP_SUBTRACT], true)
	# O ALMANAQUE DAS PLANTAS pela tabela de atalhos, e não numa letra fixa.
	#
	# Ele morava no `KEY_L` escrito aqui, porque L é a coleção do 2D. Aí a
	# coleção de verdade chegou ao vale, TAMBÉM no L, e as duas telas ficaram
	# na mesma tecla — coisa que a tabela existe para impedir e não podia, com
	# o almanaque passando por fora dela. Agora ele está lá dentro, de fábrica
	# no L, e remapeável como os outros.
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
	# AS CONSTRUÇÕES POR DENTRO (interiores.gd), a começar pela igreja: o cômodo
	# mora dentro da casca dela, no lugar dela. Medidas LOGO DEPOIS de o vale
	# ficar de pé, antes de qualquer morador, do Pedro e da partida salva: a
	# medida espera dois quadros de física, e nesses quadros nada que dependa da
	# partida pode estar andando. Medidas depois deles, o Pedro saudava como na
	# chegada ao píer — a fila dele ainda não tinha voltado do save. E antes da
	# partida salva também porque ela pode pôr o jogador lá dentro.
	interiores = Interiores.new()
	interiores.name = "Interiores"
	add_child(interiores)
	set_process(false)
	await interiores.configurar(world, player)
	set_process(true)
	# O menu também move o relógio visual. A partida começa sua própria contagem;
	# quando houver save, `restaurar_do_save` devolve a contagem guardada.
	Dia.horas_decorridas = 0.0
	# Partida nova conta conquista, com o relógio correndo e o registro dele em
	# branco; a salva diz o que o jogador já fez com ele.
	Dia.zerar_a_partida()
	_relogio_pausado_antes = false
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
	hud.house_info_close_requested.connect(_fechar_info_aberta)
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
	_arvores_info = arvores
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
	_ajustar_as_telas_do_2d()
	get_viewport().size_changed.connect(_ajustar_as_telas_do_2d)
	# A FALA LONGA (#21) para o vale como uma tela, sem ser tela: ninguém a
	# abre por tecla, é o mundo que fala. Ver `_ao_abrir_a_fala`.
	Dialogo.abriu.connect(_ao_abrir_a_fala)
	Dialogo.terminou.connect(_ao_calar_a_fala)
	telas.ocupado = func() -> bool: return Dialogo.ocupado() or Amanhecer.aberto
	# O FOLHETO (#21) é tela, mas quem o abre é o mundo: o cordel achado, ou o
	# almanaque pedindo para reler. Nenhuma tecla é dele (`minha` diz que não);
	# sendo tela, o Esc o guarda, e a tecla de outra tela troca para ela — é o
	# "[L] coleção" que o rodapé dele escreve. Ver `ler_o_folheto`.
	telas.registrar("folheto",
		func(_e: InputEvent) -> bool: return false,
		func() -> bool: return Folheto.aberto,
		func() -> void: Folheto.abrir(_folheto_a_ler),
		func() -> void: Folheto.fechar())
	Folheto.fechou.connect(_ao_guardar_o_folheto)
	if hud.almanaque() != null:
		var alm: Control = hud.almanaque()
		telas.registrar("almanaque",
			func(e: InputEvent) -> bool: return e.physical_keycode == Atalhos.tecla("almanaque"),
			func() -> bool: return alm.aberto(),
			func() -> void: alm.abrir(),
			func() -> void: alm.fechar())
		alm.ler_no_papel.connect(func(id: String) -> void: ler_o_folheto(id, "almanaque"))
	telas.registrar("painel",
		func(e: InputEvent) -> bool: return e.physical_keycode == Atalhos.tecla("painel"),
		func() -> bool: return painel != null and painel.aberto,
		_abrir_painel_cru,
		func() -> void: if painel != null: painel.fechar())
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
		# CONTROLES É TELA, como nos outros jogos: a lista das teclas, cada uma
		# trocável ali mesmo, e o Esc volta para este menu. Era o painelzinho do
		# canto, aberto com o menu fechando por fora do dono das telas — e o vale
		# ficava parado atrás de nada. Ver `tela_controles.gd`.
		{"rotulo": "Controles", "icone": "ajuda",
			"fazer": func() -> void: telas.abrir("controles")},
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
		# O RELÓGIO DIZ O QUE O JOGADOR ESCOLHEU, e não o que o menu fez.
		#
		# Com o menu aberto o `Dia` está SEMPRE parado — é o menu que o para —,
		# e a linha lia `Dia.pausado`: dizia "parado" com o relógio andando, e
		# apertá-la não mudava o texto. A escolha do jogador mora em
		# `_relogio_pausado_antes`, que é o que o fechamento devolve ao `Dia`.
		#
		# PARAR PERGUNTA. Parar o relógio desliga as conquistas da partida dali
		# em diante (`Dia.relogio_alterado`, que vai no save), e o menu abre uma
		# caixa de confirmação antes; só o "sim" para. Religar não pede nada. Era também
		# trancado por uma opção do AJUSTAR que vinha "Bloqueado" — o aviso
		# tomou o lugar da tranca.
		#
		# E TODA MUDANÇA VAI PARA O REGISTRO DO RELÓGIO, no save
		# (`Dia.registro_do_relogio`). Com a pausa bloqueada no AJUSTAR, a linha
		# não para e diz por quê — e religar continua podendo.
		{"rotulo": func() -> String:
				var estado := tr("parado") if _relogio_pausado_antes else tr("andando")
				if Dia.relogio_alterado:
					return tr("Relógio: %s · sem conquistas") % estado
				if not Dia.pausa_no_jogo and not _relogio_pausado_antes:
					return tr("Relógio: %s · pausa bloqueada") % estado
				return tr("Relógio: %s") % estado,
			"icone": "relogio",
			"ligado": func() -> bool: return not _relogio_pausado_antes,
			"confirmar": func() -> Dictionary:
				if _relogio_pausado_antes or not Dia.pausa_no_jogo:
					return {}
				return Dia.aviso_de_parar(),
			"fazer": func():
				if not _relogio_pausado_antes and not Dia.pausa_no_jogo:
					Audio.efeito("ui_trava")
					return tr("Pausar o relógio está bloqueado em AJUSTAR → Geral.")
				Audio.efeito("ui_confirmar")
				_relogio_pausado_antes = not _relogio_pausado_antes
				if _relogio_pausado_antes:
					Dia.marcar_relogio_alterado()
					Dia.registrar_no_relogio("parou", "menu")
				else:
					Dia.registrar_no_relogio("voltou", "menu")
				return null},
		{"rotulo": func() -> String: return "Velocidade do tempo: %s" % Dia.ROTULOS_VELOCIDADE[Dia.velocidade],
			"icone": "velocidade",
			"fazer": func() -> void:
				Dia.definir_velocidade(Dia.proxima_velocidade())},
		{"rotulo": func() -> String: return "Câmera do mouse: %s" % ("arrastar" if CameraMouse.travada() else "livre"),
			"icone": "camera",
			"fazer": func() -> void:
				# Troca A PREFERÊNCIA, e não a câmera de agora: com o menu aberto
				# o cursor está solto de propósito, e é a preferência que o
				# fechamento vai ler. Mexer na câmera aqui seria desfeito um
				# quadro depois. Ver `_camera_da_preferencia`.
				CameraMouse.definir(CameraMouse.LIVRE if CameraMouse.travada() else CameraMouse.ARRASTAR)},
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
	# A TEIA DE TALENTOS, na tecla K — a mesma do jogo 2D.
	#
	# O sistema já estava no vale: `Talentos` é autoload compartilhado desde a
	# Fase 2, com os 37 nós, o custo, as exigências e a soma dos bônus. O que
	# faltava era poder olhar — sem tela, o jogador subia de nível e o ponto
	# ficava num número que ninguém via.
	teia = TeiaTalentos.new()
	teia.name = "TeiaTalentos"
	add_child(teia)
	# A TEIA SOCIAL, na tecla P — a mesma do jogo 2D ("aperte P e veja quem é
	# quem no arraial", do tutorial de lá).
	#
	# O `Afinidade` também já estava no vale: os sete moradores, os cinco graus,
	# o gosto de cada um lido do `aldeoes.json`, e o preço social de migrar de
	# fé. Faltava a tela — sem ela a afinidade subia sem ninguém ver.
	# OS RETRATOS 3D DOS MORADORES, para a teia social e o diário. Ver
	# `retratos_3d.gd`; as fotos saem quando o vale já está de pé
	# (`_pedir_os_retratos`).
	retratos = Retratos3D.new()
	retratos.name = "Retratos3D"
	add_child(retratos)
	social = TeiaSocial.new()
	social.name = "TeiaSocial"
	social.retratos = retratos
	add_child(social)
	telas.registrar("arraial",
		func(e: InputEvent) -> bool: return e.physical_keycode == Atalhos.tecla("arraial"),
		func() -> bool: return social.aberta,
		func() -> void: social.abrir(),
		func() -> void: social.fechar())
	telas.registrar("talentos",
		func(e: InputEvent) -> bool: return e.physical_keycode == Atalhos.tecla("talentos"),
		func() -> bool: return teia.aberta,
		func() -> void: teia.abrir(),
		func() -> void: teia.fechar())
	telas.registrar("menu_pausa",
		# O Esc já é cuidado pelo dono das telas: com tela aberta ele fecha, e
		# sem nada aberto cai na escada do `_unhandled_key_input` daqui, que é
		# quem pede este menu. Então esta linha não reclama tecla nenhuma.
		func(_e: InputEvent) -> bool: return false,
		func() -> bool: return menu_pausa.aberto,
		func() -> void: menu_pausa.abrir(),
		func() -> void: menu_pausa.fechar())
	# O MENU QUE SE FECHA POR UMA LINHA AVISA O DONO DAS TELAS.
	#
	# "Voltar ao vale", "Mapa", "Ajustes" e as saídas fecham o menu por dentro,
	# sem passar pelo `telas` — e ninguém devolvia o vale: a árvore ficava
	# pausada e o relógio parado. "Quando abri MENU > Controles, ele travou o
	# jogo." E pior, calado: os Ajustes abertos dali guardavam o relógio já
	# parado pelo menu como se fosse a escolha do jogador, e o devolviam parado
	# ao fechar. Fechado pelo próprio `telas`, o aviso é ignorado lá.
	menu_pausa.fechou.connect(func() -> void: telas.fechou_por_conta("menu_pausa"))
	tela_controles = TelaControles.new()
	tela_controles.name = "TelaControles"
	add_child(tela_controles)
	telas.registrar("controles",
		func(_e: InputEvent) -> bool: return false,
		func() -> bool: return tela_controles.aberta,
		func() -> void: tela_controles.abrir(),
		func() -> void: tela_controles.fechar(),
		# O Esc DAQUI volta ao menu, que é de onde se chega.
		"menu_pausa")
	tela_controles.voltar_pedido.connect(func() -> void: telas.abrir("menu_pausa"))
	tela_controles.teclas_mudaram.connect(hud._update_control_mode)
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
	hud.set_objective(_objetivo_sem_missao)
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
		elif quem == "zefa":
			_pendurar_cadeia(morador, "res://data/missoes_zefa.json", 4.0)
		elif quem == "tonho":
			_pendurar_cadeia(morador, "res://data/missoes_tonho.json", 4.0)
		elif quem == "candinha":
			_pendurar_cadeia(morador, "res://data/missoes_candinha.json", 4.0)
	# AS MISSÕES DO ARRAIAL, do Pedro, DEPOIS DO TUTORIAL: no 2D elas vêm
	# "depois que o Pedro termina de ensinar a sobreviver". A cadeia fica
	# pendurada nele, mas só abre com a do guia terminada e a despedida dita.
	if pedro != null:
		var do_arraial = _pendurar_cadeia(pedro, "res://data/missoes_arraial.json", 6.0, "pedro_arraial")
		if do_arraial != null:
			do_arraial.depois_de = func() -> bool:
				return pedro.missao >= pedro.MISSOES.size() and bool(pedro.get("_despedida_feita"))
	# OS ACONTECIMENTOS QUE UM PASSO PODE ESPERAR (meta "evento"): abrir a tela
	# do P. Todas as cadeias ouvem, mesmo as que ainda não chegaram no passo.
	social.abriu.connect(func() -> void:
		for qual in _cadeias:
			_cadeias[qual].registrar_evento("abriu_arraial"))
	Dia.periodo_mudou.connect(_on_periodo_mudou)
	# Os corpos de quem anda no vale entram na luz de dentro dos cômodos — agora
	# que os moradores e o Pedro existem (ver `Interiores.marcar_os_corpos`).
	interiores.marcar_os_corpos()
	# OS MARCOS DE FÉ (#52): o rito, a entrada numa fé e a troca, no lugar de
	# cada um. Antes da partida salva, que pode estar no meio de uma missão de
	# fé. A escolha só se abre depois que a Dona Zefa mostra as três.
	marcos = MarcosDaFe.new()
	marcos.name = "MarcosDaFe"
	add_child(marcos)
	marcos.configurar(world, player, hud, interiores)
	marcos.liberada = func() -> bool: return Fe.ativa != ""
	interiores.entrou.connect(_ao_mudar_de_lado.unbind(1))
	interiores.saiu.connect(_ao_mudar_de_lado.unbind(1))
	# A PARTIDA SALVA entra depois de o vale estar montado — moradores, Pedro,
	# luta —, porque o estado do mundo aponta para eles. Ver Partida e
	# `estado_para_salvar`.
	Salvamento.registrar_mundo(self)
	_retomar_a_partida()
	_conferir_o_relogio_parado()
	Inventario.trazer_ferramentas_para_a_mao()
	_entregar_machado_inicial()
	# Depois da partida salva: o que ela diz que já foi achado não volta ao chão.
	achados.espalhar()
	_comecar_no_lugar_pedido()
	_atualizar_relogio()
	print("PROTOTYPE_READY: estilo=%s hora=%s moradores=%d user_dir=%s" % [Estilo.modo, Dia.texto_hora(), moradores.size(), OS.get_user_data_dir()])
	_pedir_os_retratos()


## Entrou ou saiu de uma construção: o som de fora abafa e o HUD diz onde se
## está.
func _ao_mudar_de_lado() -> void:
	var qual: String = interiores.dentro()
	if ambiente != null:
		ambiente.abafado = 1.0 if qual != "" else 0.0
	if qual != "":
		hud.set_region_title(interiores.nome_de(qual))
	else:
		hud.set_region_title(world.get_region_title())


## AS FOTOS DOS MORADORES saem com o vale de pé e um respiro depois, para não
## disputarem os primeiros quadros com a chegada. Uma por quadro, e só uma vez:
## a teia social e o diário as pegam prontas.
func _pedir_os_retratos() -> void:
	await get_tree().create_timer(1.5, true).timeout
	if not is_inside_tree() or _saindo:
		return
	var quem: Array = ["pedro"]
	quem.append_array(Afinidade.MORADORES)
	retratos.pedir(quem)


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
	# Seta da missão: cone e anel no mundo + chevron na borda da tela seguem o
	# alvo DA MISSÃO ACOMPANHADA (ver `_mostrar_a_acompanhada`).
	_seta = SetaMissao.new()
	_seta.name = "SetaMissao"
	add_child(_seta)
	_seta.configurar(hud.map_layer())
	CadernoDoVale.mudou.connect(_mostrar_a_acompanhada)
	CadernoDoVale.abriu.connect(_ao_abrir_missao)
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
	# A pesca (pesca_vale.gd). Entra ANTES dos achados: com a vara na mão, o E
	# ainda pega o cordel do píer. Ferrar o peixe escuta em `_input`, e esse
	# vem antes de tudo — a janela é de três quartos de segundo.
	pesca = PescaVale.new()
	pesca.name = "Pesca"
	add_child(pesca)
	pesca.configurar(world, player, hud)
	# As bancadas sem modelo ainda (a oficina): caixa cinza no lugar delas.
	BancadasVale.montar_as_provisorias(world, self)
	# Cordéis, sinais e cartas no chão (achados_vale.gd). Entra ANTES da luta,
	# que assim recebe o E primeiro quando há bicho perto; é configurado depois
	# dela, porque a Caipora fica longe do ninho do caititu.
	achados = AchadosVale.new()
	achados.name = "Achados"
	add_child(achados)
	# A luta e o caititu da mata (luta_vale.gd). Entra depois das lápides e das
	# árvores: com bicho perto, o E é dela antes de ser delas.
	var luta := LutaVale.new()
	luta.name = "Luta"
	add_child(luta)
	luta.configurar(world, player, hud)
	achados.configurar(world, player, hud, luta)
	achados.achou.connect(_ao_achar)
	# O painel da tecla J (painel_vale.gd), por cima do HUD.
	painel = PainelVale.new()
	painel.name = "Painel"
	painel.retratos = retratos
	add_child(painel)
	painel.abriu.connect(_parar_o_jogador)
	painel.fechou.connect(_soltar_o_jogador)
	painel.pediu.connect(_ao_pedido_do_painel)
	# Quem está lendo não perde vida: a peçonha espera o painel fechar (ver
	# Vida.esta_lendo). Por método, que deixa de valer quando o vale sai.
	Vida.esta_lendo = Callable(self, "_lendo")
	# Pegadas do jogador no chão, por terreno, sumindo com o tempo.
	pegadas_no = preload("res://scripts/prototipo_3d/pegadas.gd").new()
	pegadas_no.name = "Pegadas"
	add_child(pegadas_no)

	# Minimapa do canto inferior esquerdo. O losango dele segue a missão
	# acompanhada no caderno, sozinho (`Minimapa._alvo_do_caderno`).
	var minimapa := Minimapa.new()
	minimapa.name = "Minimapa"
	hud.map_layer().add_child(minimapa)
	minimapa.configurar(player, pedro, hud)
	_mostrar_a_acompanhada()


func _fechar_info_aberta() -> void:
	var dono: Object = hud.get("painel_dono")
	if dono != null and is_instance_valid(dono) and dono.has_method("fechar_painel"):
		dono.call("fechar_painel")
		return
	world.clear_house_interaction()
	hud.clear_house_info()


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


## O QUE UMA CADEIA ANUNCIA SÓ VAI AO HUD QUANDO NÃO HÁ MISSÃO ABERTA.
##
## Quem manda no HUD é a missão ACOMPANHADA (`_mostrar_a_acompanhada`). O que
## sobra para cá é o fim de uma cadeia ("Concluído: missões com Damião"), que
## fica escrito enquanto o caderno não tiver outra coisa para mostrar.
func _on_missao_mudou(texto: String, _alvo: Vector3, indice: int, total: int) -> void:
	if indice >= total:
		_objetivo_sem_missao = texto
	_mostrar_a_acompanhada()


## O HUD, A SETA E A BÚSSOLA SEGUEM A MISSÃO ACOMPANHADA.
##
## "No MENU J, de missões, eu tô clicando para trocar a missão de resumo, mas
## não muda. O comportamento tem que ser muito próximo de jogos de RPG como The
## Witcher 3." Lá, o diário escolhe a missão acompanhada, e o canto da tela
## mostra o nome dela e o objetivo de agora; a bússola e o marcador apontam
## para ela. Aqui era a última cadeia que FALOU quem mandava no HUD e na seta, e
## o "[E] fixar" do J só mudava a cor da linha.
##
## Agora há uma fonte só, o `CadernoDoVale.atual()`: escolher no J, cumprir um
## passo, abrir uma missão — tudo passa pelo `mudou` do caderno e chega aqui.
func _mostrar_a_acompanhada() -> void:
	if hud == null or not is_instance_valid(_seta):
		return
	var acompanhada: Dictionary = CadernoDoVale.atual()
	if acompanhada.is_empty():
		hud.set_objective(_objetivo_sem_missao)
		hud.set_mission_step(0, 0)
		_seta.limpar()
		return
	var resumo := str(acompanhada.get("resumo", ""))
	if resumo == "":
		resumo = str(acompanhada.get("linha", ""))
	if resumo == "":
		resumo = str(acompanhada.get("titulo", ""))
	hud.set_objective(resumo, str(acompanhada.get("missao", "")))
	hud.set_mission_step(int(acompanhada.get("passo", 0)), int(acompanhada.get("passos", 0)))
	var alvo: Vector3 = acompanhada.get("alvo", Vector3.ZERO)
	if alvo == Vector3.ZERO:
		_seta.limpar()
	else:
		_seta.definir_alvo(alvo, resumo)


## Depois de o quadro acabar: quem abre a missão a `descrever` logo em seguida,
## e o aviso precisa do nome e do passo que só chegam ali.
func _ao_abrir_missao(id: String) -> void:
	_avisar_missao_nova.call_deferred(id)


## "NOVA MISSÃO", como no Witcher: quem dá uma missão nova não rouba o
## acompanhamento de quem o jogador escolheu — mas avisa, e diz onde trocar.
func _avisar_missao_nova(id: String) -> void:
	var nova: Dictionary = CadernoDoVale.de(id)
	if nova.is_empty() or CadernoDoVale.acompanhada(id) or int(nova.get("passo", 1)) > 1:
		return
	hud.set_notice(tr("Nova missão: %s  ·  [%s] para acompanhar") % [
		str(nova.get("missao", nova.get("titulo", ""))), Atalhos.letra("painel")])


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
			_adiantar_o_relogio()


## A TECLA DE ADIANTAR A HORA também mexe no relógio: na primeira vez da
## partida pergunta antes, com o aviso das conquistas, e para o vale enquanto
## pergunta; depois disso, adianta e só anota no registro do relógio.
func _adiantar_o_relogio() -> void:
	var aviso := Dia.aviso_de_adiantar()
	if aviso.is_empty():
		_adiantar_uma_hora()
		return
	if _pergunta_do_relogio != null:
		return
	_pause_valley()
	_pergunta_do_relogio = CaixaDePergunta.new()
	_pergunta_do_relogio.perguntar(hud, aviso)
	Audio.efeito("ui_trava")
	_pergunta_do_relogio.respondeu.connect(func(sim: bool) -> void:
		_pergunta_do_relogio = null
		_retomar_o_vale()
		if sim:
			Dia.marcar_relogio_alterado()
			_adiantar_uma_hora()
		else:
			Audio.efeito("ui_voltar"))


func _adiantar_uma_hora() -> void:
	Dia.avancar(1.0)
	Dia.registrar_no_relogio("adiantou", "tecla")
	hud.set_notice("Relógio adiantado: %s (%s)" % [Dia.texto_hora(), PERIODOS.get(Dia.periodo(), "")])


## A PARTIDA QUE COMEÇA COM O TEMPO EM "PARADA" (escolhido no AJUSTAR, com o
## aviso) já começa marcada, e o registro diz que foi assim desde o começo. Uma
## vez só: partida carregada que já estava marcada não ganha outra linha.
func _conferir_o_relogio_parado() -> void:
	if Dia.velocidade != Dia.PARADA or Dia.relogio_alterado:
		return
	Dia.marcar_relogio_alterado()
	Dia.registrar_no_relogio("comecou_parada", "ajustar")
	hud.set_notice(tr("O tempo está em \"Parada\" no AJUSTAR: esta partida não conta conquistas."))


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
		player.set_captured(false)
		mapa.abrir(world, player, hud.map_layer())
	else:
		mapa.fechar()
		_camera_da_preferencia()


## Engrenagem do canto: ajustes com o vale e o relógio pausados (fechar retoma).
func _open_settings() -> void:
	if hud.settings_open() or hud.menu_confirm_open() or _saindo:
		return
	if mapa.aberto:
		_toggle_map()
	_pause_valley()
	hud.open_settings()



## O MODO DA CÂMERA VEM DA PREFERÊNCIA, e não de uma gaveta por tela.
##
## Este defeito voltou QUATRO VEZES — perder o foco, o Esc, o mapa, o painel —, e
## na quinta ele voltou saindo do inventário. Cada conserto anterior foi do CASO:
## guardo o modo aqui, devolvo ali. E a cada tela nova o quinto caso nascia.
##
## A causa de fundo é que havia uma GAVETA (`_camera_travada_antes`): um lugar
## onde o modo era copiado ao abrir e lido ao fechar. Gaveta pode ficar velha,
## pode ser escrita por duas telas, pode não ser lida por uma. Enquanto existir
## gaveta, existe a sexta vez.
##
## Então não há mais gaveta. O modo de câmera é PREFERÊNCIA DO JOGADOR, guardada
## em `user://controles.cfg` pelo `CameraMouse` — a mesma coisa que o AJUSTAR
## escreve e que o vale lê ao abrir. Fechar qualquer tela devolve a câmera ao que
## a preferência diz, e é só isso. Não há o que esquecer de guardar, porque nada
## é guardado: pergunta-se a quem sabe.
##
## O que isso muda na prática: quem apertar Tab no meio do jogo para trocar de
## modo troca a PREFERÊNCIA, e é o que ele esperava — a escolha vale da próxima
## tela em diante e do próximo dia também. Antes o Tab mexia numa cópia que a
## tela seguinte sobrescrevia.
func _camera_da_preferencia() -> void:
	player.set_camera_locked(CameraMouse.travada())

func _pause_valley() -> void:
	# LEMBRA O MODO DE CÂMERA ANTES DE SOLTAR O CURSOR.
	#
	# Era aqui o defeito de "depois do Esc o jogo volta com a câmera solta sem
	# eu apertar C": pausar solta o cursor, porque menu com o mouse preso é
	# menu que não se clica — mas nada devolvia o modo depois. Quem jogava no
	# modo livre voltava do menu no modo de arrastar, sem ter pedido.
	player.set_captured(false)
	_relogio_pausado_antes = Dia.pausado
	Dia.pausado = true
	get_tree().paused = true
	_prender_o_calendario()


## Desfaz o `_pause_valley`, INCLUSIVE a câmera.
func _retomar_o_vale() -> void:
	get_tree().paused = false
	Dia.pausado = _relogio_pausado_antes
	_camera_da_preferencia()
	_prender_o_calendario()


## O `Relogio` AQUI É CALENDÁRIO, e fica preso (ver `dia.gd`). As telas que
## vêm do 2D o soltam ao fechar, porque lá ele é o dono da hora: a mochila
## escreve `Relogio.pausado = false`. Com o `Dia` andando, o quadro seguinte o
## prende de novo; com o `Dia` parado — o relógio pausado pelo jogador, ou a
## mochila fechada para a fala abrir (#21) —, ninguém prenderia, e o calendário
## andaria sozinho, que é o defeito que `tests/calendario.gd` procura.
func _prender_o_calendario() -> void:
	Relogio.pausado = true


## A FALA LONGA ABRIU (#21): o vale para atrás dela como para atrás de tela.
##
## É o que o `Dialogo` do 2D fazia sozinho — fechar o que estiver aberto e
## parar o relógio — trazido para cá, onde quem para o tempo é o `Dia` e quem
## fecha tela é o dono das telas. Fechar vem primeiro: a fala que sai com menu
## aberto ficaria atrás dele (é a razão que o 2D escreve no `_abrir` de lá).
## O mapa também fecha, mesmo não sendo tela: a caixa no rodapé ficaria por
## cima da vista aérea, com o mundo andando.
func _ao_abrir_a_fala(_quem: String) -> void:
	if _fala_parou_o_vale:
		return
	telas.fechar_tudo()
	if mapa != null and mapa.aberto:
		_toggle_map()
	_pause_valley()
	_fala_parou_o_vale = true


## E CALOU. Falas encadeadas abrem na linha seguinte do mesmo `await`, então o
## vale espera o fim do quadro antes de voltar a andar: se outra fala já abriu,
## ele continua parado, sem soltar e prender o cursor entre uma e outra.
func _ao_calar_a_fala() -> void:
	_retomar_se_a_fala_acabou.call_deferred()


func _retomar_se_a_fala_acabou() -> void:
	if not _fala_parou_o_vale or Dialogo.ativo:
		return
	_fala_parou_o_vale = false
	_retomar_o_vale()


## O CORDEL NO PAPEL (#21): o `Folheto` do 2D, inteiro, por cima do vale.
##
## Achar cordel sem poder ler seria só um item a mais — é a razão que o 2D
## escreve no `ler` de lá —, então o achado abre o papel na hora, como no
## `Mundo._pegar_cordel`. `voltar_para` é a tela de onde o jogador veio reler
## (o almanaque): guardado o papel, ela reabre onde ele estava, que é o que a
## coleção do 2D faz por ficar aberta embaixo. Aqui só uma tela fica aberta.
func ler_o_folheto(id: String, voltar_para := "") -> void:
	if Folheto.aberto or Dialogo.ocupado():
		return
	_folheto_a_ler = id
	_voltar_do_folheto = voltar_para
	if mapa != null and mapa.aberto:
		_toggle_map()
	telas.abrir("folheto")


func _ao_achar(tipo: String, id: String) -> void:
	if tipo == "cordel":
		ler_o_folheto(id)


## O papel se guardou com o E ou o clique, por conta dele: o dono das telas
## precisa saber, para o vale voltar a andar. E quem veio do almanaque volta a
## ele — a não ser que tenha trocado de tela pela tecla, que já abriu outra.
func _ao_guardar_o_folheto() -> void:
	telas.fechou_por_conta("folheto")
	_voltar_depois_do_folheto.call_deferred()


func _voltar_depois_do_folheto() -> void:
	var voltar := _voltar_do_folheto
	_voltar_do_folheto = ""
	if voltar != "" and telas.aberta() == "":
		telas.abrir(voltar)


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


## A MOCHILA NA CAMADA E NO TAMANHO DO VALE (#2).
##
## Ela é tela do 2D, desenhada para os 640×360 de lá (`mochila.gd`, espaço de
## 28 px). No vale de 1280×720 abria com metade do tamanho, na camada 15 — por
## baixo do HUD, que é a 20, desenhava por cima dela e ficava com os cliques.
## O arquivo é compartilhado e não se mexe nele daqui: o vale acerta a CAMADA
## dela. Escala em volta do centro da tela, porque os filhos dela se ancoram
## na tela inteira e o painel fica no meio. O mouse continua certo: a camada
## leva o clique de volta à coordenada dela.
##
## A 90% do encaixe, e não a 100%: o painel dela mede 647 px, já passa dos
## 640 de lá, e em 2× saía 7 px de cada lado da janela. A 1,8× cada espaço
## fica com 50 px, ao lado dos 52 da barra de mão.
## O quadro em que as telas do 2D são desenhadas: a janela inteira de lá.
const QUADRO_DO_2D := Vector2(640, 360)
const MOCHILA_FOLGA := 0.9
## A camada das telas do vale (a do painel J); só uma abre por vez.
const CAMADA_DAS_TELAS := 25
## O cartão do amanhecer (#21), acima da tela preta da queda (30, `queda.gd`):
## ele é lido NO escuro, antes de clarear — como o do 2D fica acima do véu.
const CAMADA_DO_AMANHECER := 31


func _ajustar_a_mochila() -> void:
	var tela := get_viewport().get_visible_rect().size
	var escala := minf(tela.x / QUADRO_DO_2D.x, tela.y / QUADRO_DO_2D.y) * MOCHILA_FOLGA
	Mochila.layer = CAMADA_DAS_TELAS
	Mochila.transform = Transform2D(0.0, Vector2(escala, escala), 0.0, tela * 0.5 * (1.0 - escala))


## AS TELAS QUE VIERAM DO 2D, na camada e no tamanho do vale. Chamado de novo
## quando a janela muda de tamanho.
func _ajustar_as_telas_do_2d() -> void:
	_ajustar_a_mochila()
	# A fala longa (#21) fica na camada das telas: por cima do HUD, e nenhuma
	# tela fica aberta com ela (ver `_ao_abrir_a_fala`).
	_no_quadro_do_2d(Dialogo, CAMADA_DAS_TELAS)
	_no_quadro_do_2d(Folheto, CAMADA_DAS_TELAS)
	_no_quadro_do_2d(Amanhecer, CAMADA_DO_AMANHECER)


## UMA TELA DESENHADA NO QUADRO DE 640×360 DO 2D, inteira na janela.
##
## Diferente da mochila: estas desenham a partir do canto do quadro (a caixa
## de fala ancora no rodapé DELE, e não no da janela), então a escala parte do
## canto, e a sobra da janela que não é 16:9 fica dividida dos dois lados.
func _no_quadro_do_2d(camada: CanvasLayer, numero: int) -> void:
	var tela := get_viewport().get_visible_rect().size
	var escala := minf(tela.x / QUADRO_DO_2D.x, tela.y / QUADRO_DO_2D.y)
	camada.layer = numero
	camada.transform = Transform2D(0.0, Vector2(escala, escala), 0.0,
		(tela - QUADRO_DO_2D * escala) * 0.5)


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


## One starter axe per game; the saved marker also migrates older saves.
func _entregar_machado_inicial() -> void:
	if _machado_inicial_entregue:
		return
	if Inventario.tem("machado") or Equipamento.no_encaixe("maos") == "machado":
		_machado_inicial_entregue = true
		return
	if Inventario.adicionar("machado"):
		_machado_inicial_entregue = true
		var espaco := -1
		for i in Inventario.ESPACOS_MAO:
			if str((Inventario.espacos[i] as Dictionary).get("id", "")) == "machado":
				espaco = i
		if espaco >= 0:
			hud.set_notice(tr("Machado recebido. Aperte %s para pô-lo na mão.") % Inventario.rotulo_do_espaco(espaco))
		else:
			hud.set_notice(tr("Machado recebido. Arraste-o da mochila para a barra de mão."))
	else:
		hud.set_notice("Mochila cheia. Libere um espaco para receber o machado.")


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
		"horas_decorridas": Dia.horas_decorridas,
		# O jogador parou o relógio nesta partida: daqui em diante ela não conta
		# conquista (ver `Dia.relogio_alterado`).
		"relogio_alterado": Dia.relogio_alterado,
		# E O REGISTRO DO RELÓGIO: quando e como o jogador mexeu nele (ver
		# `Dia.registro_do_relogio`). A marca diz se; o registro, quando.
		"registro_do_relogio": Dia.registro_do_relogio.duplicate(true),
		# O RELÓGIO PARADO PELO JOGADOR: carregar não o religa calado. Com uma
		# tela aberta o `Dia` está parado pela tela, e a escolha do jogador é a
		# que ela vai devolver ao fechar.
		"pausado": _relogio_pausado_antes if get_tree().paused else Dia.pausado,
		"machado_inicial_entregue": _machado_inicial_entregue,
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
	# O CADERNO DO VALE entra no save: missão em curso é estado de partida, e
	# recarregar sem a lista seria o jogador voltando sem saber o que estava
	# fazendo. É mecanismo do 3D, então quem o guarda é o vale — o `Salvamento`
	# cuida sozinho dos autoloads que ele conhece, e este é novo.
	estado["caderno"] = CadernoDoVale.estado()
	if _arvores_info != null:
		estado["coqueiros_cortados"] = _arvores_info.estado_para_salvar()
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
		# Dentro de uma construção o chão é o assoalho dela, e não o do lote:
		# assentar no terreno poria o corpo embaixo do chão da nave.
		if interiores != null and interiores.contem(ponto) != "":
			player.global_position = ponto
		else:
			player.global_position = world.ground_position(ponto, 0.07) if world.is_on_land(ponto) else ponto
		player.velocity = Vector3.ZERO
		player.visual.rotation.y = float(estado.get("giro", player.visual.rotation.y))
	Dia.horas_decorridas = maxf(0.0, float(estado.get("horas_decorridas", 0.0)))
	Dia.relogio_alterado = bool(estado.get("relogio_alterado", false))
	var registro = estado.get("registro_do_relogio", [])
	Dia.registro_do_relogio = (registro as Array).duplicate(true) if registro is Array else []
	_relogio_pausado_antes = bool(estado.get("pausado", false))
	Dia.pausado = _relogio_pausado_antes or get_tree().paused
	_machado_inicial_entregue = bool(estado.get("machado_inicial_entregue", false))
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
		# SEM REANUNCIAR: ver `CadeiaDeMissoes.retomar`. O marcador e o caderno
		# voltam; a fala não, que ela já aconteceu.
		c.retomar()
	# OS ALVOS CAÍDOS SOMEM DE NOVO, e é aqui e não antes: o vale se monta
	# inteiro primeiro (`_erguer`), e só então o save diz o que já tinha caído.
	if _recursos != null:
		_recursos.esquecer(estado.get("caidos", []))
	if estado.has("caderno"):
		CadernoDoVale.restaurar(estado["caderno"])
	if _arvores_info != null:
		_arvores_info.restaurar_do_save(estado.get("coqueiros_cortados", []))
	var guia: Dictionary = estado.get("pedro", {})
	if pedro != null and not guia.is_empty():
		pedro.set("_iniciado", bool(guia.get("iniciado", false)))
		pedro.set("_despedida_feita", bool(guia.get("despedida", false)))
		pedro.missao = int(guia.get("missao", -1))
		# Ele NÃO reanuncia o passo: quem salvou no primeiro passo ouvia a
		# abertura do jogo de novo ao voltar, como se a partida recomeçasse. O
		# que volta é o objetivo — caderno e marcador. Ver `CadeiaDeMissoes.retomar`.
		pedro.retomar()
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


## A abertura CRUA do painel, que é o que o dono das telas chama. Ninguém mais
## deve chamá-las: elas não pausam nada e não mexem na câmera.
func _abrir_painel_cru() -> void:
	if painel == null or _lendo() or mapa.aberto or _saindo:
		return
	BancadasVale.aplicar(painel, world, player.global_position)
	painel.abrir(_aba_pedida)
	_aba_pedida = 0


## COM UMA TELA ABERTA, O JOGADOR PARA — e SÓ isso.
##
## Este par já fez mais: guardava o modo de câmera, soltava o cursor e pausava
## a árvore. Fazia certo, e mesmo assim era errado, porque o `telas_do_vale.gd`
## passou a fazer o mesmo para TODAS as telas. E a gaveta que guardava o modo
## acabou: ele vem da PREFERÊNCIA do jogador agora, porque a gaveta era a causa
## de fundo de o defeito ter voltado cinco vezes. Ver `_camera_da_preferencia`.
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
	return painel != null and painel.aberto


func _exit_tree() -> void:
	if Vida.esta_lendo == Callable(self, "_lendo"):
		Vida.esta_lendo = Callable()
	# UMA FALA ABERTA NÃO SOBREVIVE AO VALE (#21). O `Dialogo` é autoload e fica;
	# quem sai no meio dela — a volta ao menu, um portão que troca de cena — não
	# deixa a árvore parada nem a caixa esperando um E que ninguém vai dar. Os
	# sinais saem antes, para o calar não chamar de volta um vale de saída.
	if Dialogo.abriu.is_connected(_ao_abrir_a_fala):
		Dialogo.abriu.disconnect(_ao_abrir_a_fala)
	if Dialogo.terminou.is_connected(_ao_calar_a_fala):
		Dialogo.terminou.disconnect(_ao_calar_a_fala)
	Dialogo.calar()
	if _fala_parou_o_vale:
		_fala_parou_o_vale = false
		get_tree().paused = false
		Dia.pausado = _relogio_pausado_antes
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
##
## `chave` é o nome da fila no save; vazio, o id do morador. O Pedro tem duas
## filas — o guia, que mora dentro dele, e a do arraial —, e cada uma precisa
## de um nome seu.
func _pendurar_cadeia(morador: MoradorNPC, arquivo: String, perto: float, chave: String = "") -> Node:
	var cadeia := CadeiaDeMissoes.new()
	cadeia.name = "CadeiaDeMissoes" if chave == "" else "CadeiaDeMissoes_" + chave
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
	# A RECOMPENSA DO PASSO (#48) é dita no HUD, como no 2D.
	cadeia.pagou.connect(func(texto: String) -> void: hud.set_notice(texto))
	morador.add_child(cadeia)
	_cadeias[chave if chave != "" else str(morador.dados.get("id", ""))] = cadeia
	return cadeia
