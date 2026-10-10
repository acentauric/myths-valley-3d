extends Node3D
## Cena do vale: cenário, jogador, HUD, som do lugar, moradores e o Pedro guia.
## A hora do dia e a velocidade do tempo vêm do autoload Dia, ajustado no menu (AJUSTAR).

const NPCS := "res://data/npcs_3d.json"
const TeclasMovimento = preload("res://scripts/prototipo_3d/teclas_movimento.gd")
const MarcosDaFe = preload("res://scripts/prototipo_3d/marcos_da_fe.gd")
const VozDoMarco = preload("res://scripts/prototipo_3d/voz_do_marco.gd")
const CaixaDePergunta = preload("res://scripts/prototipo_3d/caixa_de_pergunta.gd")
const TelaCarregamento = preload("res://scripts/prototipo_3d/tela_carregamento.gd")
const TemaMenu = preload("res://scripts/prototipo_3d/tema_menu.gd")
const MapaJogo = preload("res://scripts/prototipo_3d/mapa_jogo.gd")
const Lapides = preload("res://scripts/prototipo_3d/lapides.gd")
const TeclaDasBancadas = preload("res://scripts/prototipo_3d/tecla_das_bancadas.gd")
const TeclaDosMoradores = preload("res://scripts/prototipo_3d/tecla_dos_moradores.gd")
const FocoDoE = preload("res://scripts/prototipo_3d/foco_do_e.gd")
const AceiteDeMissao = preload("res://scripts/prototipo_3d/aceite_de_missao.gd")
const FilaDeFalas = preload("res://scripts/prototipo_3d/fila_de_falas.gd")
const FalasDoViajante = preload("res://scripts/prototipo_3d/falas_do_viajante.gd")
const SeloDoViajante = preload("res://scripts/prototipo_3d/selo_do_viajante.gd")
const DicasDosMoradores = preload("res://scripts/prototipo_3d/dicas_dos_moradores.gd")
const AvisoDaPrimeiraVez = preload("res://scripts/prototipo_3d/aviso_da_primeira_vez.gd")
const CapaDeCordel = preload("res://scripts/prototipo_3d/capa_de_cordel.gd")
const Almanaque = preload("res://scripts/prototipo_3d/almanaque.gd")
const ConquistaDaMissao = preload("res://scripts/prototipo_3d/conquista_da_missao.gd")
const LuzDourada = preload("res://scripts/prototipo_3d/luz_dourada.gd")
const ArvoresInfo = preload("res://scripts/prototipo_3d/arvores_info.gd")
const PlacasNomes = preload("res://scripts/prototipo_3d/placas_nomes.gd")
const BonecoDaMochila = preload("res://scripts/prototipo_3d/boneco_da_mochila.gd")
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
const SaveiroVale = preload("res://scripts/prototipo_3d/saveiro_vale.gd")
const Minimapa = preload("res://scripts/prototipo_3d/minimapa.gd")
const CadeiaDeMissoes = preload("res://scripts/prototipo_3d/cadeia_de_missoes.gd")
const TelasDoVale = preload("res://scripts/prototipo_3d/telas_do_vale.gd")
const MenuPausa = preload("res://scripts/prototipo_3d/menu_pausa.gd")
const TelaControles = preload("res://scripts/prototipo_3d/tela_controles.gd")
const TeiaTalentos = preload("res://scripts/prototipo_3d/teia_talentos.gd")
const TeiaSocial = preload("res://scripts/prototipo_3d/teia_social.gd")
const Retratos3D = preload("res://scripts/prototipo_3d/retratos_3d.gd")
const Interiores = preload("res://scripts/prototipo_3d/interiores.gd")
const CasaDoJogador = preload("res://scripts/prototipo_3d/casa_do_jogador.gd")
const LavouraVale = preload("res://scripts/prototipo_3d/lavoura_vale.gd")
const NavegacaoVale = preload("res://scripts/prototipo_3d/navegacao_vale.gd")
const CemiterioVale = preload("res://scripts/prototipo_3d/cemiterio_vale.gd")
const PonteVale = preload("res://scripts/prototipo_3d/ponte_vale.gd")
const LombadaVale = preload("res://scripts/prototipo_3d/lombada_vale.gd")
const FazendaVale = preload("res://scripts/prototipo_3d/fazenda_vale.gd")
const CurralVale = preload("res://scripts/prototipo_3d/curral_vale.gd")
const RevoarVale = preload("res://scripts/prototipo_3d/revoar_vale.gd")
const Plantacao = preload("res://scripts/prototipo_3d/plantacao.gd")
const NarracaoDoVale = preload("res://scripts/prototipo_3d/narracao_do_vale.gd")
const SustosDaMata = preload("res://scripts/prototipo_3d/sustos_da_mata.gd")
const MENU_SCENE := "res://scenes/prototipo_3d/abertura.tscn"
## Raio de terra firme em volta do ponto de chegada.
const RAIO_CHEGADA := 6.0
const PERIODOS := {"madrugada": "Madrugada", "manha": "Manhã", "tarde": "Tarde", "entardecer": "Entardecer", "noite": "Noite"}

@onready var player = $Jogador
@onready var hud: Variant = $HUD
@onready var hud_layer: Control = $HUD/PrototypeHUD
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
## O `_ready` inteiro terminou (moradores, bichos, telas, partida salva). A tela de
## carregamento espera por ele depois de o mundo ficar pronto; `carga_ok` cobre quem
## chega depois do aviso.
signal carga_concluida
var carga_ok := false

var pedro: GuiaPedro
var moradores: Array[MoradorNPC] = []
var apresentacao_do_povoado: Node
var _segundos_apresentacao := 0.0
var _visited: Dictionary = {}
var _step_time := 0.0
var pegadas_no	# pegadas.gd — pool de marcas dos passos no chão
var _saindo := false
var mapa	# mapa_jogo.gd
var _recursos  # recursos_3d.gd — os alvos de trabalho (troncos, lajedos)
var lapides	# lapides.gd
var _arvores_info	# arvores_info.gd — as fichas, o corte e o ano de crescer das árvores
## O saveiro do mestre Quirino, que encosta no píer uma vez por estação.
var saveiro
## Modo de câmera de antes da pausa, para o retorno devolver o que havia.
## As filas de missão penduradas em moradores, por id do morador — para o save
## e para quem precise achá-las. A do Pedro NÃO está aqui: ela mora dentro do
## `guia_pedro.gd` e é salva pelo nome antigo (`pedro.missao`), que o save do
## vale já guardava antes de existir a segunda cadeia.
var _cadeias: Dictionary = {}
## AS TELAS SEGURAM O DIA POR MOTIVO, CONTADAS (#100): cada tela aberta por cima
## de outra soma um, e o dia só volta quando a última fecha. Antes um booleano
## guardava "estava pausado antes?", e duas telas aninhadas (a mochila por
## cima de uma fala, o mapa por cima do J) deixavam `Dia.pausado` preso ao
## fechar — o relógio travado às 07:14 na live de 06/10. `Dia.pausado` agora é
## só a pausa que o jogador pediu; o HUD mostra quem segura (`Dia.segurado`).
const MOTIVO_DA_TELA := "tela"
## A camada das plaquinhas de nome (#103): abaixo dos balões (10) e do HUD (20).
const CAMADA_DAS_PLACAS := 8
var _telas_que_param := 0
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
## O menu do Esc também reúne os atalhos da coluna do HUD. Ver menu_pausa.gd.
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
## A casa herdada por dentro: a cama e o baú (`casa_do_jogador.gd`), e a noite
## que vira por três portas (`queda.gd`).
var casa: Node
var fiado_tonho: Node
var noite: Node
## A lavoura da casa, a fazenda do jogador (`lavoura_vale.gd`, #8).
var lavoura: Node3D
## A malha de navegação dos moradores (`navegacao_vale.gd`).
var navegacao: Node3D
## O cemitério que a missão do Damião conserta: as lajes tortas e o cercado
## (`cemiterio_vale.gd`).
var cemiterio: Node3D
## A ponte do rio grande, cercada até a obra da frente da trilha (`ponte_vale.gd`).
var ponte_do_rio: Node3D
## A lombada de pedra, a lapa e a cabra da frente do ofício (`lombada_vale.gd`).
var lombada: Node3D
## A fazenda do convite e o dia dela (`fazenda_vale.gd`).
var fazenda: Node3D
## O curral do quintal: o galinheiro do talento Curral e os ovos (`curral_vale.gd`, #160).
var curral: Node3D
## O capítulo 7, o revoar das asas negras: as ruínas, a torre, a fera e a estátua (`revoar_vale.gd`, #31).
var revoar: Node3D
## AS CENAS DOS DADOS (cena_vale.gd, data/cenas.json): a chegada apresenta o Tonho, mostra a
## praça e chega à casa do tio.
var cenas: CenaVale
## A voz do mundo, sem nome, sobre o escuro (`narracao_do_vale.gd`).
var narracao: CanvasLayer
## As plaquinhas de nome dos moradores; somem com tela aberta (placas_nomes.gd).
var placas
## O personagem em 3D na mochila, ao lado dos encaixes (boneco_da_mochila.gd).
var boneco_da_mochila
## A aba pedida no último `abrir_o_painel`, entregue à abertura crua. -1 é o J,
## que não pede aba nenhuma e deixa a abertura escolher (`_abrir_painel_cru`).
var _aba_pedida := -1
## O sítio de obra que o E pediu no último `abrir_o_painel`, ou "".
var _obra_pedida := ""
var _barra_de_ferramentas_migrada := false
var achados	# achados_vale.gd — cordéis, sinais e cartas no chão
var pesca	# pesca_vale.gd — a vara na mão e o E na beira da água
## O E na bancada da oficina e na fogueira (`tecla_das_bancadas.gd`).
var tecla_das_bancadas: Node
## O E nos moradores: conversar e cumprir passo (`tecla_dos_moradores.gd`).
var tecla_dos_moradores: Node
## A tela de aceite da missão (aceite_de_missao.gd): o E na fila por abrir passa por ela.
var aceite: Node
## Quem leva o E entre tudo o que o aceita (`foco_do_e.gd`).
var foco_do_e: Node
## Uma fala de cada vez no vale (`fila_de_falas.gd`).
var fila_de_falas: Node
## O viajante comenta o que acontece, só em voz e sem balão (`falas_do_viajante.gd`, #187).
var viajante: Node
## O selo de ondas sobre a cabeça dele enquanto a voz toca, e a legenda opcional (`selo_do_viajante.gd`, #225).
var selo_do_viajante: Control
## A camada das placas, onde moram as placas de nome e o selo do viajante.
var _chao_das_placas: Control
## Os moradores que vêm dar uma dica a quem está perdido (`dicas_dos_moradores.gd`, #204).
var dicas_dos_moradores: Node
## O cartão do primeiro cordel e da primeira árvore (`aviso_da_primeira_vez.gd`).
var aviso_da_primeira_vez: CanvasLayer
## A tela da missão cumprida (`conquista_da_missao.gd`).
var conquista: CanvasLayer
## A luz dourada da chegada à chapada (`luz_dourada.gd`), uma das cenas dos passos.
var luz_dourada: CanvasLayer


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
	# O zoom também pode ser controlado pelo teclado, além da roda do mouse.
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
	# A MALHA DE NAVEGAÇÃO dos moradores, assada depois dos cômodos — a porta e
	# as rampas deles entram nela —, numa linha de execução à parte. Até ficar
	# pronta, eles andam reto, como antes.
	navegacao = NavegacaoVale.new()
	navegacao.name = "Navegacao"
	add_child(navegacao)
	navegacao.configurar(world, self)
	# O menu também move o relógio visual. A partida começa sua própria contagem;
	# quando houver save, `restaurar_do_save` devolve a contagem guardada.
	Dia.horas_decorridas = 0.0
	# Partida nova conta conquista, com o relógio correndo e o registro dele em
	# branco; a salva diz o que o jogador já fez com ele.
	Dia.zerar_a_partida()
	_telas_que_param = 0
	# Vindo do menu, o relógio esperou a montagem na hora_inicial (abertura._start_game).
	Dia.congelado_na_carga = false
	var spawn: Vector3 = _ponto_de_chegada()
	player.spawn_position = spawn
	player.global_position = spawn
	player.configure_click_world(world)
	player.capture_changed.connect(Callable(hud, "set_captured"))
	player.camera_lock_changed.connect(Callable(hud, "set_camera_locked"))
	player.animation_requested.connect(_on_animation_requested)
	player.navigation_status.connect(Callable(hud, "set_notice"))
	player.nado_mudou.connect(_ao_mudar_o_nado)
	hud.connect("camera_lock_requested", func(_travada: bool) -> void: player.alternar_camera())
	world.house_interacted.connect(func(properties: Dictionary): hud.show_house_info(world.format_house_properties(properties)))
	world.house_interaction_cleared.connect(Callable(hud, "clear_house_info"))
	hud.connect("house_info_close_requested", Callable(self, "_fechar_info_aberta"))
	hud.connect("menu_prompt_requested", Callable(self, "_ask_return_to_menu"))
	hud.connect("menu_requested", Callable(self, "_return_to_menu"))
	hud.connect("menu_cancelled", Callable(self, "_on_menu_cancelled"))
	mapa = MapaJogo.new()
	mapa.name = "Mapa"
	add_child(mapa)
	hud.connect("map_requested", Callable(self, "_toggle_map"))
	hud.connect("quests_requested", func() -> void:
		abrir_o_painel(PainelVale.Aba.MISSOES))
	hud.connect("settings_requested", Callable(self, "_open_settings"))
	hud.connect("settings_closed", Callable(self, "_on_menu_cancelled"))
	# O E NA BANCADA DA OFICINA E NA FOGUEIRA (tecla_das_bancadas.gd). Entra antes
	# de todo mundo que ouve o E: quem entra depois o recebe primeiro, e a árvore,
	# o lajedo, a pesca e os achados têm alvo mais preciso que "estar perto".
	tecla_das_bancadas = TeclaDasBancadas.new()
	tecla_das_bancadas.name = "TeclaDasBancadas"
	add_child(tecla_das_bancadas)
	tecla_das_bancadas.configurar(world, player, hud, abrir_o_painel,
		func() -> bool: return not _lendo() and (telas == null or telas.aberta() == ""))
	# O E NA FOGUEIRA COM A LENHA NA MÃO a alimenta (07/10).
	tecla_das_bancadas.alimentar = alimentar_a_fogueira
	lapides = Lapides.new()
	lapides.name = "Lapides"
	add_child(lapides)
	lapides.configurar(world, player, hud, hud_layer)
	var arvores := ArvoresInfo.new()
	arvores.name = "ArvoresInfo"
	add_child(arvores)
	arvores.configurar(world, player, hud, hud_layer)
	_arvores_info = arvores
	# ONDE BATER: os troncos e lajedos que respondem à ferramenta. Vem depois
	# das árvores porque usa o mesmo alcance e a mesma dica, e quem estiver
	# perto dos dois tem de ver a dica do que dá para fazer, não a da ficha.
	var recursos := Recursos3D.new()
	recursos.name = "Recursos3D"
	add_child(recursos)
	recursos.configurar(world, player, hud, hud_layer)
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
	var apoios = load("res://scripts/prototipo_3d/apoios_vale.gd").new()
	apoios.name = "Apoios"
	add_child(apoios)
	telas.registrar("apoios",
		func(e: InputEvent) -> bool: return e is InputEventKey and e.pressed and e.keycode == Atalhos.tecla("apoios"),
		func() -> bool: return apoios.aberta,
		func() -> void: apoios.abrir(),
		func() -> void: apoios.fechar_tela())
	apoios.fechou.connect(func() -> void: telas.fechou_por_conta("apoios"))
	apoios.usou.connect(func(texto: String) -> void: hud.set_notice(texto))
	hud.controls_requested.connect(func() -> void: telas.abrir("controles"))
	telas.registrar("mochila",
		func(e: InputEvent) -> bool: return e.is_action_pressed("mv_mochila"),
		func() -> bool: return Mochila.aberta,
		func() -> void: Mochila.abrir(),
		func() -> void: Mochila.fechar())
	# A TELA DE ACEITE DA MISSÃO (08/10): tela do vale sem tecla própria — o E no morador com
	# fila por abrir a pede (`tecla_dos_moradores.usar`); o Esc recusa.
	aceite = AceiteDeMissao.new()
	aceite.name = "AceiteDeMissao"
	add_child(aceite)
	aceite.configurar(telas)
	telas.registrar("aceite",
		func(_e: InputEvent) -> bool: return false,
		func() -> bool: return aceite.aberto,
		func() -> void: pass,
		func() -> void: aceite.recusar())
	_ajustar_as_telas_do_2d()
	get_viewport().size_changed.connect(_ajustar_as_telas_do_2d)
	# O BONECO DA MOCHILA: "ao lado dos itens equipados, coloque o 3D do boneco
	# com os itens equipados, igual nos jogos de RPG". A mochila é tela do 2D e
	# não se mexe nela: o boneco entra na fileira dela daqui.
	boneco_da_mochila = BonecoDaMochila.new()
	boneco_da_mochila.montar(Mochila, player)
	# A FALA LONGA (#21) para o vale como uma tela, sem ser tela: ninguém a
	# abre por tecla, é o mundo que fala. Ver `_ao_abrir_a_fala`.
	Dialogo.abriu.connect(_ao_abrir_a_fala)
	Dialogo.terminou.connect(_ao_calar_a_fala)
	Dialogo.linha_mudou.connect(_ao_mudar_a_linha_da_fala)
	telas.ocupado = func() -> bool: return Dialogo.ocupado() or Amanhecer.aberto \
		or (aviso_da_primeira_vez != null and aviso_da_primeira_vez.aberto())
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
	# O MENU DO ESC reúne os atalhos que também ficam na coluna do HUD.
	#
	# As mesmas ações também aparecem em linhas com rótulos e estado escrito;
	# assim continuam acessíveis pelo Esc quando o cursor está capturado.
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
		# Com o menu aberto o `Dia` está segurado pela tela (MOTIVO_DA_TELA), e
		# `Dia.pausado` é só a escolha do jogador (#100): a linha lê e muda isso,
		# e o fechamento do menu não mexe nele.
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
				var estado := tr("parado") if Dia.pausado else tr("andando")
				if Dia.relogio_alterado:
					return tr("Relógio: %s · sem conquistas") % estado
				if not Dia.pausa_no_jogo and not Dia.pausado:
					return tr("Relógio: %s · pausa bloqueada") % estado
				return tr("Relógio: %s") % estado,
			"icone": "relogio",
			"ligado": func() -> bool: return not Dia.pausado,
			"confirmar": func() -> Dictionary:
				if Dia.pausado or not Dia.pausa_no_jogo:
					return {}
				return Dia.aviso_de_parar(),
			"fazer": func():
				if not Dia.pausado and not Dia.pausa_no_jogo:
					Audio.efeito("ui_trava")
					return tr("Pausar o relógio está bloqueado em AJUSTAR → Geral.")
				Audio.efeito("ui_confirmar")
				Dia.pausado = not Dia.pausado
				if Dia.pausado:
					Dia.marcar_relogio_alterado()
					Dia.registrar_no_relogio("parou", "menu")
				else:
					Dia.registrar_no_relogio("voltou", "menu")
				return null},
		{"rotulo": func() -> String: return "Velocidade do tempo: %s" % Dia.ROTULOS_VELOCIDADE[Dia.velocidade],
			"icone": "velocidade",
			"fazer": func() -> void:
				Dia.definir_velocidade(Dia.proxima_velocidade())},
		{"rotulo": func() -> String: return "Câmera do mouse: %s" % CameraMouse.rotulo(),
			"icone": "camera",
			"fazer": func() -> void:
				# Troca A PREFERÊNCIA, e não a câmera de agora: com o menu aberto
				# o cursor está solto de propósito, e é a preferência que o
				# fechamento vai ler. Mexer na câmera aqui seria desfeito um
				# quadro depois. Ver `_camera_da_preferencia`.
				CameraMouse.definir((CameraMouse.modo() + 1) % 3)},
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
		if _nome == "controles":
			hud.set_controls_screen_open(aberta)
		if aberta:
			_pause_valley()
		else:
			_retomar_o_vale()
		# As plaquinhas de nome dos moradores somem com a tela aberta: elas
		# moram no mesmo Control do HUD que o almanaque e a barra, e entram
		# depois — "o nome do Pedro tá sobrescrevendo os MENUs". Ver
		# `placas_nomes.gd`.
		_acertar_as_placas())
	# O VALE ABRE NO MODO DE CÂMERA ESCOLHIDO (AJUSTAR → Geral → Câmera do
	# mouse). Era sempre livre, e quem preferia arrastar tinha de apertar a
	# tecla da câmera toda vez que entrava.
	player.set_camera_modo(CameraMouse.modo())
	hud.set_region_title(world.get_region_title())
	var corpo_do_jogador := "viajante do Tripo" if player.model != null and player.model.scene_file_path.ends_with("viajante_tripo.glb") else "personagem GLB provisório"
	hud.set_model_status("Estilo Tripo: modelos do Tripo Studio (%s)" % corpo_do_jogador)
	hud.set_telemetry("Tripo · 1,78 m")
	hud.set_objective(_objetivo_sem_missao)
	hud.set_notice("Bom Jesus dos Pobres, 1887 · 1 unidade = %s m" % _formatar(world.get_meters_per_unit()))
	_montar_som()
	_montar_moradores(spawn)
	# OS PEDIDOS DOS MORADORES ESPERAM A APRESENTAÇÃO. Cada fila abria ao primeiro
	# passo perto do dono, e no píer, antes de o Pedro acabar a primeira frase, o
	# Tonho já contava a dívida do armazém. A chegada agora apresenta o arraial
	# pelos pedidos de cada um (docs/mundo/CHEGADA_E_MUTIROES.md), e as filas
	# deles vêm depois dela — a ordem do 2D, a mesma do mirante e da fé. Fila que
	# já tinha começado numa partida salva continua: `depois_de` só segura quem
	# ainda não abriu.
	var depois_da_chegada := func() -> bool: return pedro == null or pedro.terminou_o_tutorial()
	# O cabo da foice e o mato do Damião, e a rede do Tonho, são de madeira: esperam
	# o machado da ponte (ver `_ja_recebeu_o_machado`).
	var depois_do_machado := func() -> bool: return depois_da_chegada.call() and _ja_recebeu_o_machado()
	for morador in moradores:
		var quem := String(morador.dados.get("id", ""))
		var fila: Node = null
		if quem == "damiao":
			lapides.coveiro = morador
			fila = _pendurar_cadeia(morador, "res://data/missoes_coveiro.json", 4.0)
		elif quem == "filo":
			fila = _pendurar_cadeia(morador, "res://data/missoes_filo.json", 4.0)
		elif quem == "zefa":
			fila = _pendurar_cadeia(morador, "res://data/missoes_zefa.json", 4.0)
		elif quem == "tonho":
			fila = _pendurar_cadeia(morador, "res://data/missoes_tonho.json", 4.0)
		elif quem == "candinha":
			fila = _pendurar_cadeia(morador, "res://data/missoes_candinha.json", 4.0)
		elif quem == "cosme":
			# A ROÇA DO FINADO (data/missoes_roca.json) é a frente que corre ao
			# lado: abre quando a chegada passa da primeira leira, perto do Cosme,
			# que capinava para o tio. Colher, torrar a farinha e levar a primeira
			# cuia à Dona Filó.
			var roca = _pendurar_cadeia(morador, "res://data/missoes_roca.json", 6.0, "cosme_roca")
			if roca != null:
				roca.depois_de = func() -> bool: return pedro == null or pedro.passou("roca")
		if fila != null:
			fila.depois_de = depois_do_machado if quem in ["damiao", "tonho"] else depois_da_chegada
	fiado_tonho.configurar(player, hud, interiores, _cadeias.get("tonho"))
	# OS FAVORES DOS MORADORES (07/10, docs/projeto/MISSOES_SECUNDARIAS.md): as filas
	# secundárias de cada morador do arraial, penduradas pela tabela e trancadas pela
	# afinidade — abrem quando o morador conhece o jogador, e as que seguem outra, quando
	# a de antes acabou.
	_pendurar_as_secundarias(moradores, depois_da_chegada)
	# A PONTE DO RIO GRANDE (data/missoes_ponte.json), a frente da trilha do 2D:
	# ver a ponte cercada, a lenha, as tábuas e a obra. É enredo — a fazenda do
	# convite fica do outro lado do rio —, e por isso é a PRIMEIRA fila que o E
	# no Pedro abre depois da chegada: pendurada antes das outras dele.
	#
	# AS MISSÕES DO ARRAIAL, do Pedro, DEPOIS DO TUTORIAL: no 2D elas vêm
	# "depois que o Pedro termina de ensinar a sobreviver", e a ponte é do
	# tutorial — o mirante é "a segunda coisa que muda neste arraial em vinte
	# anos", e a primeira é ela. A cadeia fica pendurada nele, mas só abre com a
	# do guia terminada, a despedida dita e a ponte de pé.
	if pedro != null:
		var da_ponte = _pendurar_cadeia(pedro, "res://data/missoes_ponte.json", 6.0, "pedro_ponte")
		if da_ponte != null:
			da_ponte.depois_de = func() -> bool: return pedro.terminou_o_tutorial()
		# A CHAPADA DO SEU BENEDITO (data/missoes_chapada.json), a frente do 2D que
		# ESPERA A PRIMEIRA COLHEITA: a conversa de terra que poderia ser sua, dita a
		# quem nunca tirou nada do chão, é conversa no vazio (`_frente_da_chapada`).
		var da_chapada = _pendurar_cadeia(pedro, "res://data/missoes_chapada.json", 6.0, "pedro_chapada")
		if da_chapada != null:
			da_chapada.depois_de = func() -> bool:
				var roca = _cadeias.get("cosme_roca")
				return pedro.terminou_o_tutorial() and roca != null and roca.passou("colher")
		var do_arraial = _pendurar_cadeia(pedro, "res://data/missoes_arraial.json", 6.0, "pedro_arraial")
		if do_arraial != null:
			do_arraial.depois_de = func() -> bool:
				return pedro.missao >= pedro.MISSOES.size() and bool(pedro.get("_despedida_feita")) \
					and (da_ponte == null or da_ponte.acabou())
	# O SAVEIRO DA ESTAÇÃO (data/missoes_saveiro.json): o Seu Benedito, que vende
	# a colheita para o saveiro há quarenta e duas safras, ensina que o mestre
	# Quirino encosta no píer uma vez por estação — depois do tutorial, que antes
	# disso o jogador anda com o Pedro. O saveiro (saveiro_vale.gd) traz e leva o
	# mestre e o barco pelo calendário, e a encomenda de piaçava volta toda
	# estação depois da cadeia.
	var do_saveiro: Node = null
	var da_carroca: Node = null
	var quirino: Node3D = null
	for morador in moradores:
		match String(morador.dados.get("id", "")):
			"benedito":
				do_saveiro = _pendurar_cadeia(morador, "res://data/missoes_saveiro.json", 4.0, "benedito_saveiro")
				# A CARROÇA DO AVÔ (data/missoes_carroca.json): a colheita que ele
				# vende ao saveiro desce no ombro desde a cheia de fevereiro. Ele
				# fala dela depois da piaçava — quando o jogador já trabalhou para
				# ele uma vez —, e o fim é o mutirão no terreiro dele.
				da_carroca = _pendurar_cadeia(morador, "res://data/missoes_carroca.json", 4.0, "benedito_carroca")
			"quirino":
				quirino = morador
	if do_saveiro != null and pedro != null:
		do_saveiro.depois_de = func() -> bool: return pedro.terminou_o_tutorial()
	if da_carroca != null:
		# Oito tábuas e quatro cordas: a carroça também espera o machado da ponte.
		da_carroca.depois_de = func() -> bool:
			return (do_saveiro == null or bool(do_saveiro.call("passou", "saveiro_piacava"))) \
				and _ja_recebeu_o_machado()
	saveiro = SaveiroVale.new()
	saveiro.name = "Saveiro"
	add_child(saveiro)
	saveiro.configurar(world, quirino, hud, do_saveiro)
	# O CEMITÉRIO QUE A FILA DO DAMIÃO CONSERTA: as lajes que a raiz levantou
	# endireitam com o conserto, e o cercado sobe com a obra do J. Os dois se
	# leem da fila e do `Obras`, que já vão no save (`cemiterio_vale.gd`).
	cemiterio = CemiterioVale.new()
	cemiterio.name = "Cemiterio"
	add_child(cemiterio)
	cemiterio.configurar(world, _cadeias.get("damiao"))
	# A PONTE DO RIO GRANDE, cercada nas duas cabeceiras até a obra da frente da
	# trilha (data/missoes_ponte.json). Quem diz é o `Obras`, que vai no save.
	ponte_do_rio = PonteVale.new()
	ponte_do_rio.name = "PonteDoRio"
	add_child(ponte_do_rio)
	ponte_do_rio.configurar(world)
	# OS ACONTECIMENTOS QUE UM PASSO PODE ESPERAR (meta "evento"): abrir a tela
	# do P. Todas as cadeias ouvem, mesmo as que ainda não chegaram no passo.
	social.abriu.connect(func() -> void: _avisar_as_cadeias("abriu_arraial"))
	# E OS DA CHEGADA (docs/mundo/CHEGADA_E_MUTIROES.md): a janta, a farinha, a
	# corda, a leira, a cama e o papel lido. Métodos, e não lambdas, nos sinais
	# dos autoloads: eles ficam quando o vale sai, e `_exit_tree` os desliga.
	Cozinha.cozinhou.connect(_ao_cozinhar)
	Cozinha.comeu.connect(_ao_comer)
	Oficina.fabricou.connect(_ao_fabricar)
	lavoura.arou.connect(_avisar_as_cadeias.bind("arou"))
	lavoura.plantou.connect(_avisar_as_cadeias.bind("plantou"))
	lavoura.regou.connect(_avisar_as_cadeias.bind("regou"))
	lavoura.colheu.connect(_avisar_as_cadeias.bind("colheu"))
	lavoura.plantou_cultura.connect(_ao_plantar)
	noite.deitou.connect(_ao_deitar)
	Mochila.abrir_documento = _ler_documento
	Mochila.letra_de_fechar = _letra_da_mochila
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
	_pendurar_as_filas_da_fe()
	_pendurar_as_frentes_do_2d()
	# A LOMBADA DA LAPA E DA CABRA, entre a casa e a chapada: a lapa é alvo de
	# trabalho (`_recursos`), e a cabra desce com o passo da frente dela, que
	# acabou de ser pendurada (data/missoes_lombada.json).
	lombada = LombadaVale.new()
	lombada.name = "Lombada"
	add_child(lombada)
	lombada.configurar(world, _cadeias.get("pedro_lombada"), _recursos)
	# A FAZENDA DO CONVITE, do outro lado do rio grande, e o dia dela: a manhã
	# seguinte à fé escolhida, com a ponte de pé (data/missoes_fazenda.json).
	fazenda = FazendaVale.new()
	fazenda.name = "Fazenda"
	add_child(fazenda)
	fazenda.configurar(world, self)
	# O CAPÍTULO 7 (#31): as ruínas do palacete atrás do monte, a torre da capela, a fera e
	# a estátua; a fila segue a da fazenda (data/missoes_revoar.json).
	revoar = RevoarVale.new()
	revoar.name = "Revoar"
	add_child(revoar)
	revoar.configurar(world, self)
	# AS CENAS PELOS DADOS (07/10, cena_vale.gd): a fila que fecha um passo com `cena` as toca.
	cenas = CenaVale.new()
	cenas.name = "Cenas"
	add_child(cenas)
	cenas.configurar(self)
	# A interface do vale se recolhe com a cena e volta no fim dela (#215).
	cenas.comecou.connect(_acertar_as_placas.unbind(1))
	cenas.acabou.connect(_acertar_as_placas.unbind(1))
	interiores.entrou.connect(_ao_mudar_de_lado.unbind(1))
	interiores.saiu.connect(_ao_mudar_de_lado.unbind(1))
	# O E NOS MORADORES (tecla_dos_moradores.gd): conversar, cumprir o passo que
	# manda falar com alguém ou levar alguma coisa, e abrir a fila de quem tem o
	# que pedir. Quem decide se o E é dele ou do cordel ao lado é o foco.
	tecla_dos_moradores = TeclaDosMoradores.new()
	tecla_dos_moradores.name = "TeclaDosMoradores"
	add_child(tecla_dos_moradores)
	tecla_dos_moradores.configurar(player, hud,
		func() -> Array:
			var todos: Array = moradores.duplicate()
			if pedro != null:
				todos.append(pedro)
			return todos,
		func() -> bool: return not _lendo() and (telas == null or telas.aberta() == ""))
	# O FOCO DO E (foco_do_e.gd): de tudo o que responde ao E — morador, cordel,
	# árvore, lápide, alvo de trabalho, bancada, marco, lavoura, casa, pesca e
	# luta —, só um leva a tecla e acende a dica: o da frente do jogador, e mais
	# perto. Antes quem levava era o último nó posto no vale.
	tecla_dos_moradores.aceite = aceite
	foco_do_e = FocoDoE.new()
	foco_do_e.name = "FocoDoE"
	add_child(foco_do_e)
	foco_do_e.configurar(player)
	# A FESTA DA MISSÃO E A VOZ DO MUNDO cobrem o vale por baixo do HUD sem parar a
	# árvore: as dicas do E se calam enquanto elas duram, como as plaquinhas.
	foco_do_e.coberto = func() -> bool:
		# E A CENA (cena_vale.gd): com ela tocando, nenhuma dica do E fica acesa.
		var em_cena: bool = cenas != null and bool(cenas.em_cena())
		return (conquista != null and conquista.ativa()) or (narracao != null and narracao.tocando()) or em_cena
	# O AVISO DA PRIMEIRA VEZ (aviso_da_primeira_vez.gd): o primeiro cordel e a
	# primeira árvore dizem onde ficam guardados. É instrução, e segura o vale e o
	# relógio como a caixa de fala.
	aviso_da_primeira_vez = AvisoDaPrimeiraVez.new()
	aviso_da_primeira_vez.name = "AvisoDaPrimeiraVez"
	add_child(aviso_da_primeira_vez)
	aviso_da_primeira_vez.abriu.connect(func() -> void: _ao_abrir_a_fala(""))
	aviso_da_primeira_vez.fechou.connect(_ao_calar_a_fala)
	aviso_da_primeira_vez.abriu.connect(_acertar_as_placas)
	aviso_da_primeira_vez.fechou.connect(_acertar_as_placas)
	if _arvores_info != null and _arvores_info.has_signal("conheceu"):
		_arvores_info.conheceu.connect(_ao_conhecer_a_arvore)
	# A CONQUISTA: toda missão cumprida escurece a tela e festeja
	# (conquista_da_missao.gd).
	conquista = ConquistaDaMissao.new()
	conquista.name = "ConquistaDaMissao"
	add_child(conquista)
	conquista.comecou.connect(_acertar_as_placas)
	conquista.acabou.connect(_acertar_as_placas)
	luz_dourada = LuzDourada.new()
	luz_dourada.name = "LuzDourada"
	add_child(luz_dourada)
	narracao = NarracaoDoVale.new()
	narracao.name = "NarracaoDoVale"
	add_child(narracao)
	# A FILA DE FALAS (fila_de_falas.gd): o balão de cada morador, a voz do marco,
	# a narração e a festa da missão pedem a vez a ela, e só uma fala fica no ar.
	# Antes da partida salva e da chegada pelo saveiro, onde o Pedro já saúda.
	fila_de_falas = FilaDeFalas.new()
	fila_de_falas.name = "FilaDeFalas"
	add_child(fila_de_falas)
	# AS FALAS DO VIAJANTE (#187): ele deixa de ser mudo. Só voz, na vez que a fila dá a uma fala de
	# passagem; antes da partida salva, que devolve o que ele já disse de uma vez só.
	viajante = FalasDoViajante.new()
	viajante.name = "FalasDoViajante"
	add_child(viajante)
	viajante.configurar(player, world, pedro, saveiro, interiores, lavoura, _recursos, noite)
	# O SELO DO VIAJANTE (#225): sem balão, um ícone de ondas sobre a cabeça dele diz que é ele falando. Mora na
	# camada das placas (sob o balão e o HUD) e cede a balão, dica do E e painéis.
	selo_do_viajante = SeloDoViajante.new()
	selo_do_viajante.name = "SeloDoViajante"
	_chao_das_placas.add_child(selo_do_viajante)
	selo_do_viajante.configurar(player, placas, viajante)
	selo_do_viajante.coberto = func() -> bool:
		var em_cena: bool = cenas != null and bool(cenas.em_cena())
		return (conquista != null and conquista.ativa()) or (narracao != null and narracao.tocando()) or em_cena
	# OS MORADORES AJUDAM QUEM ESTÁ PERDIDO (#204): a missão acompanhada parada, a mesma recusa de novo ou o lado
	# errado chamam o morador que entende do assunto (Ajustes: Ligadas, Poucas ou Desligadas).
	dicas_dos_moradores = DicasDosMoradores.new()
	dicas_dos_moradores.name = "DicasDosMoradores"
	add_child(dicas_dos_moradores)
	dicas_dos_moradores.configurar(player, pedro, _achar_morador, _passo_da_acompanhada, interiores, noite, _recursos)
	# A PARTIDA SALVA entra depois de o vale estar montado — moradores, Pedro,
	# luta —, porque o estado do mundo aponta para eles. Ver Partida e
	# `estado_para_salvar`.
	Salvamento.registrar_mundo(self)
	var retomou_partida := _retomar_a_partida()
	# TRÊS CONTAS (#82): a reserva do dia (o `Energia`, que o HUD ouve sozinho), o
	# vigor do corpo e o fôlego do nado, estes dois lidos do jogador.
	hud.configurar_corpo(player)
	_ligar_os_acontecimentos_das_frentes()
	_conferir_o_relogio_parado()
	Equipamento.migrar_ferramenta_das_maos()
	if not _barra_de_ferramentas_migrada:
		Inventario.trazer_ferramentas_para_a_mao()
		_barra_de_ferramentas_migrada = true
	# SEM MACHADO DE SAÍDA: ele chega na ponte, nos machados do avô do Pedro
	# (data/missoes_ponte.json, "buscar_machado"). Ver `_ja_recebeu_o_machado`.
	# Depois da partida salva: o que ela diz que já foi achado não volta ao chão.
	achados.espalhar()
	var lugar_pedido := _comecar_no_lugar_pedido()
	if not retomou_partida and not lugar_pedido:
		_chegar_pelo_saveiro(spawn)
	_acertar_a_porta_da_casa()
	apresentacao_do_povoado = preload("res://scripts/prototipo_3d/apresentacao_do_povoado.gd").new()
	apresentacao_do_povoado.name = "ApresentacaoDoPovoado"
	add_child(apresentacao_do_povoado)
	apresentacao_do_povoado.segundos = _segundos_apresentacao
	apresentacao_do_povoado.configurar(self)
	if pedro != null:
		pedro.missao_mudou.connect(func(_t: String, _a: Vector3, _i: int, _n: int) -> void: _conferir_a_chave_da_casa())
	_atualizar_relogio()
	print("PROTOTYPE_READY: hora=%s moradores=%d user_dir=%s" % [Dia.texto_hora(), moradores.size(), OS.get_user_data_dir()])
	_pedir_os_retratos()
	carga_ok = true
	carga_concluida.emit()


## Entrou ou saiu de uma construção: o som de fora abafa e o HUD diz onde se
## está.
func _ao_mudar_de_lado() -> void:
	var qual: String = interiores.dentro()
	if ambiente != null:
		ambiente.abafado = 1.0 if qual != "" else 0.0
	# O sol só faz sombra até onde a câmera de cima alcança (#185); a de passeio vê o vale.
	var sala = interiores.sala_de(qual) if qual != "" else null
	world.sombra_de_dentro(sala != null and bool(sala.camera_de_cima))
	if qual != "":
		hud.set_region_title(interiores.nome_de(qual))
		# ENTRAR É ACONTECIMENTO: a chegada espera o jogador entrar na casa
		# herdada (o passo `casa`, "entrou:casa").
		_avisar_as_cadeias("entrou:" + qual)
	else:
		hud.set_region_title(world.get_region_title())


## A CASA HERDADA FICA TRANCADA ATÉ A CHAVE. Na chegada quem guarda a chave é a
## Dona Zefa: ela entrega o item `chave_da_casa` no fim do passo `chave_zefa`
## (#217), e a porta só abre com a chave na mochila — "o Pedro deve conduzir o
## jogador até a casa dele", e quem chega antes não acha a casa aberta. O passo
## `casa` gasta a chave ao abrir a porta (`gasta` em data/missoes_guia.json), e
## dali em diante a porta fica livre (`passou("casa")`). Fora da chegada —
## tutorial acabado, ou nem começado — a porta é livre, e nunca tranca com o
## jogador lá dentro.
func _acertar_a_porta_da_casa() -> void:
	var sala = interiores.sala_de("casa") if interiores != null else null
	if sala == null or not sala.has_method("trancar") or player == null:
		return
	var na_chegada: bool = pedro != null and bool(pedro.get("_iniciado")) and not pedro.terminou_o_tutorial()
	var com_a_chave: bool = Inventario.tem(CHAVE_DA_CASA) or (na_chegada and pedro.passou("casa"))
	var trancada: bool = na_chegada and not com_a_chave and not sala.contem(player.global_position)
	sala.trancar(trancada)


## O ITEM QUE ABRE A CASA HERDADA (catalogo.gd) e os dois passos da chegada que o cercam.
const CHAVE_DA_CASA := "chave_da_casa"


## A CHAVE DE QUEM JÁ PASSOU PELA DONA ZEFA SEM TÊ-LA (#217): a partida salva antes de a chave existir, ou
## o passo pulado de propósito (`ir_ao_passo`, nos portões), chega ao passo da casa de mãos vazias — e a
## porta que só abre com a chave não abriria nunca. Entre `chave_zefa` e `casa` a chave se completa; depois
## de `casa` ela já foi usada, e a que sobrou na mochila (passo pulado) é guardada no prego. Só roda quando
## a cadeia muda de passo e quando uma partida volta: a mochila cheia não vira recado a cada item.
func _conferir_a_chave_da_casa() -> void:
	if pedro == null or not bool(pedro.get("_iniciado")) or pedro.terminou_o_tutorial():
		return
	if pedro.passou("casa"):
		Inventario.consumir(CHAVE_DA_CASA, Inventario.quantidade(CHAVE_DA_CASA))
	elif pedro.passou("chave_zefa") and not Inventario.tem(CHAVE_DA_CASA) and not pedro.esta_devendo(CHAVE_DA_CASA):
		Inventario.adicionar(CHAVE_DA_CASA)
	_acertar_a_porta_da_casa()


## Mexeu na mochila: a chave que chegou (ou que acabou de ser gasta) acerta a porta.
func _ao_mudar_a_mochila() -> void:
	_acertar_a_porta_da_casa()


## A CHEGADA PELO SAVEIRO, na partida nova: o jogador no convés, olhando o píer;
## o Pedro na ponta da prancha, que saúda e começa a conduzir. Sem saveiro (o
## vale sem âncora do píer), a chegada antiga, em terra, de frente para a praia.
func _chegar_pelo_saveiro(spawn: Vector3) -> void:
	var no_conves: Vector3 = saveiro.ponto_do_conves() if saveiro != null and saveiro.na_chegada() else Vector3.INF
	if not no_conves.is_finite():
		var direcao_para_praia: Vector3 = world.ancoras.get("Pier", spawn) - spawn
		player.iniciar_de_frente(direcao_para_praia)
		return
	# De costas para a câmera, olhando o píer: à frente estão o Pedro e o arraial.
	var rumo: Vector3 = saveiro.rumo_do_pier()
	player.teleportar(no_conves, atan2(rumo.x, rumo.z))
	# A câmera espia pelo ombro, do lado da proa: o Pedro e o píer à vista, e não atrás do viajante (#119).
	player.enquadrar_de_ombro(saveiro.ombro_da_chegada())
	if pedro != null:
		pedro.global_position = saveiro.lugar_do_pedro()
		pedro.velocity = Vector3.ZERO
		_saudar_quando_pronto.call_deferred()
	_acertar_a_porta_da_casa()
	_tonho_para_a_areia()


## O TONHO ESPERA A CHEGADA NA AREIA (playtest de 07/10: "no início do jogo, talvez
## faça mais sentido o Tonho estar na areia da praia para não ficar com o píer muito
## poluído"): na partida nova ele sai do tabuado para a areia ao lado do píer
## (`ancoras["Areia"]`), onde o Pedro leva o jogador para o bom-dia, e volta à rotina
## dele quando a chegada passa da casa (ou acaba) — `_acertar_o_tonho_da_chegada`.
var _tonho_na_areia := false


func _tonho_para_a_areia() -> void:
	var tonho := _achar_morador("tonho")
	var areia: Vector3 = world.ancoras.get("Areia", Vector3.INF)
	if tonho == null or not areia.is_finite() or not tonho.has_method("ir_ate"):
		return
	tonho.global_position = areia + Vector3(0.0, 0.05, 0.0)
	tonho.velocity = Vector3.ZERO
	tonho.ir_ate(areia)
	_tonho_na_areia = true


## Ele volta à rotina quando a chegada passou do bom-dia E ninguém está olhando (o
## jogador a mais de LONGE_DO_TONHO), para não sair andando na cara de quem acabou de
## cumprimentá-lo — ou na hora em que a festa de uma fé o chama à roda.
const LONGE_DO_TONHO := 14.0


func _acertar_o_tonho_da_chegada() -> void:
	if not _tonho_na_areia:
		return
	var tonho := _achar_morador("tonho")
	if tonho == null or not tonho.has_method("liberar"):
		_tonho_na_areia = false
		return
	var na_festa: bool = str(tonho.get("_posto")) == "festa"
	var passou_a_praia: bool = pedro == null or pedro.terminou_o_tutorial() or pedro.passou("bom_dia")
	var longe: bool = player == null or player.global_position.distance_to(tonho.global_position) > LONGE_DO_TONHO
	if na_festa or (passou_a_praia and longe):
		_tonho_na_areia = false
		tonho.liberar()


## Posicionar no convés não inicia voz ou contagem do tutorial sob a carga.
func _saudar_quando_pronto() -> void:
	while is_inside_tree() and (not carga_ok or not get_tree().get_nodes_in_group("telas_de_carregamento").is_empty()):
		await get_tree().process_frame
	if is_inside_tree() and is_instance_valid(pedro):
		pedro.saudar()


## AS FERRAMENTAS DO FINADO NUMA PARTIDA DE ANTES DO BAÚ. A enxada vinha do
## Pedro, no passo da roça; agora está no baú da casa (`casa_do_jogador`), e a
## roça vem antes da lenha. Quem salvou no meio da chegada antiga volta com o
## passo do baú dado por passado, sem ter recebido a enxada: ela vai para o
## baú.
func _conferir_a_enxada_do_finado() -> void:
	if pedro == null or casa == null or not pedro.passou("pegar"):
		return
	if Inventario.tem("enxada") or Equipamento.em_uso("enxada"):
		return
	for monte in casa.bau:
		if str((monte as Dictionary).get("id", "")) == "enxada":
			return
	casa.bau.append({"id": "enxada", "qtd": 1})


## AS FILAS DA FÉ (#52), as missões do 2D trazidas para os marcos do vale.
##
## A DA DONA ZEFA vem pela boca do Pedro, como no 2D ("A Dona Zefa mandou te
## chamar"), e abre com o mirante consertado: ela começa reconhecendo o que o
## jogador fez. Mostra os três marcos, conta como é, e só então eles aceitam
## alguém (`marcos.liberada`). Na primeira chegada a cada marco, o mundo conta o
## que se vê dali.
##
## AS DE CADA FÉ não têm morador: o marco as dá, na voz do mundo
## (`voz_do_marco.gd`), no dia em que o jogador entra na fé — e congelam quando
## ele muda para outra, voltando a correr se ele voltar.
func _pendurar_as_filas_da_fe() -> void:
	var da_fe: Node = null
	if pedro != null:
		da_fe = _pendurar_cadeia(pedro, "res://data/missoes_fe.json", 6.0, "pedro_fe")
	if da_fe != null:
		da_fe.depois_de = func() -> bool:
			var arraial = _cadeias.get("pedro_arraial")
			return arraial != null and arraial.acabou()
		da_fe.ponto_do_lugar = Callable(marcos, "ponto")
		da_fe.visitou.connect(func(lugar: String) -> void: marcos.narrar_visita(lugar))
	marcos.liberada = func() -> bool:
		var fila = _cadeias.get("pedro_fe")
		return Fe.ativa != "" or (fila != null and fila.passou("fe_voltar"))
	for fe in Fe.ids():
		var marco := Fe.marco_maior(str(fe))
		var voz := VozDoMarco.new()
		voz.name = "VozDo_" + marco
		voz.dados = {"id": "fe_" + str(fe), "nome": tr(str(MarcosDaFe.NOMES_DOS_MARCOS.get(marco, marco)))}
		add_child(voz)
		if marcos.ponto(marco).is_finite():
			voz.global_position = marcos.ponto(marco)
		var fila = _pendurar_cadeia(voz, "res://data/missoes_fe_%s.json" % str(fe), 0.0, "fe_" + str(fe))
		if fila == null:
			continue
		fila.ponto_do_lugar = Callable(marcos, "ponto")
		var esta := str(fe)
		fila.so_enquanto = func() -> bool: return Fe.ativa == esta
	# POR MÉTODO, e não por lambda: o `Fe` é autoload e não morre, e o vale
	# é refeito a cada carga — método de nó liberado o Godot desliga sozinho.
	Fe.adotou.connect(_ao_entrar_numa_fe)
	Fe.migrou.connect(_ao_migrar_de_fe)


## AS FRENTES DO 2D QUE NÃO PEDEM LUGAR NOVO (docs/projeto/MISSOES_DO_2D.md): o
## combate, a pesca e a teia de talentos já rodavam no vale, e ninguém levava o
## jogador até eles.
##
## AS ARMAS E O OFÍCIO são do Pedro, depois da chegada, cada uma aberta por um E
## nele — penduradas depois do arraial e da fé, que são enredo e têm a vez antes
## na conversa. A CAPOEIRA é do Cosme e da fé do candomblé: abre com a mesa da
## folha cumprida e congela fora dele. A META DOS CAITITUS abre sozinha quando a
## conta de abatidos chega (`_conferir_as_metas`), e fecha no E no Pedro.
func _pendurar_as_frentes_do_2d() -> void:
	if pedro != null:
		# A LAPA E A CABRA (data/missoes_lombada.json), a frente do ofício do 2D, a
		# primeira das de ofício e DEPOIS DAS DE ENREDO no E do Pedro (a ponte, a
		# chapada, o mirante e a fé): no 2D o enredo entra na frente. ESPERA A LENHA
		# DA PONTE, como lá — a missão da picareta abria na primeira machadada, e o
		# jogador pulava as falas apertando E no tronco (`_frente_do_oficio`).
		var da_lombada = _pendurar_cadeia(pedro, "res://data/missoes_lombada.json", 6.0, "pedro_lombada")
		if da_lombada != null:
			da_lombada.depois_de = func() -> bool:
				var da_ponte = _cadeias.get("pedro_ponte")
				return pedro.terminou_o_tutorial() and da_ponte != null and da_ponte.passou("ponte_lenha")
		for qual in ["armas", "oficio"]:
			var frente = _pendurar_cadeia(pedro, "res://data/missoes_%s.json" % qual, 6.0, "pedro_" + qual)
			if frente != null:
				frente.depois_de = func() -> bool: return pedro.terminou_o_tutorial()
		_pendurar_cadeia(pedro, "res://data/missoes_metas.json", 0.0, "pedro_metas")
		# A JORNADA DA FAZENDA (data/missoes_fazenda.json): não abre no E; quem a
		# começa é o dia dela (`fazenda_vale.gd`).
		_pendurar_cadeia(pedro, "res://data/missoes_fazenda.json", 0.0, "pedro_fazenda")
		# O SEGUNDO TUTORIAL (data/missoes_quintal.json; MISSOES_DO_2D.md, 2; #160): o
		# pomar, o curral e o capataz. Não abre no E: começa sozinho na sexta colheita,
		# como no 2D (`_conferir_o_quintal`).
		_pendurar_cadeia(pedro, "res://data/missoes_quintal.json", 0.0, "pedro_quintal")
		# O CAPÍTULO 7 (data/missoes_revoar.json; #31): não abre no E; começa quando a
		# porta estreita se fecha atrás do Pedro (`revoar_vale.gd`).
		_pendurar_cadeia(pedro, "res://data/missoes_revoar.json", 0.0, "pedro_revoar")
	# A META DA ONÇA é da Dona Zefa (data/missoes_metas_onca.json, #117): abre
	# sozinha quando a conta de abatidos chega, como a dos caititus, e fecha
	# levando o couro a ela.
	var zefa := _achar_morador("zefa")
	if zefa != null:
		_pendurar_cadeia(zefa, "res://data/missoes_metas_onca.json", 0.0, "zefa_metas")
	# AS CONTAS DAS METAS vêm do caderno dos bichos (`meta.conta` de cada
	# espécie), e cada meta sabe a fila que a paga (CADEIA_DA_META).
	var bichos = JSON.parse_string(FileAccess.get_file_as_string("res://data/colecionaveis/bichos.json"))
	if bichos is Dictionary:
		for especie in ((bichos as Dictionary).get("bichos", {}) as Dictionary):
			var meta: Dictionary = (((bichos as Dictionary)["bichos"] as Dictionary)[especie] as Dictionary).get("meta", {})
			var cadeia := str(CADEIA_DA_META.get(str(meta.get("missao", "")), ""))
			if cadeia != "" and meta.has("conta"):
				_metas_dos_bichos[str(especie)] = {"conta": int(meta["conta"]), "cadeia": cadeia}
	var cosme := _achar_morador("cosme")
	if cosme != null:
		var capoeira = _pendurar_cadeia(cosme, "res://data/missoes_capoeira.json", 4.0, "cosme_capoeira")
		if capoeira != null:
			capoeira.depois_de = func() -> bool:
				var mesa = _cadeias.get("fe_candomble")
				return Fe.ativa == "candomble" and mesa != null and mesa.acabou()
			capoeira.so_enquanto = func() -> bool: return Fe.ativa == "candomble"


## Quantos caititus abrem a meta do gibão (`bichos.json`, a parede da Guilda).
## As metas do caderno dos bichos: espécie → {conta, cadeia}, lidas de
## bichos.json em `_pendurar_as_frentes_do_2d` (#117).
const CADEIA_DA_META := {"meta_caititu": "pedro_metas", "meta_onca": "zefa_metas"}
## Quantas colheitas abrem o segundo tutorial (data/missoes_quintal.json): a sexta, como no 2D.
const COLHEITAS_DO_QUINTAL := 6
var _metas_dos_bichos: Dictionary = {}


## A META ABRE SOZINHA: com a conta de caititus derrubados, o Pedro chama.
## O SOCORRO DA MUNGUNZÁ (o `_vigiar_o_folego` do 2D): trinta e seis paus de
## lenha não cabem num braço só. Na lenha e nas tábuas, na primeira vez que o
## braço não aguenta mais bater — o vigor no fim — e não há o que comer, vem a
## panela da mãe do Pedro: seis cuias, uma vez por partida (a lembrança vai na
## fila da ponte, que vai no save). No corpo de três barras o vigor volta
## sozinho, e a comida o devolve na hora: a cuia é o que deixa seguir batendo
## sem esperar o braço. Depois da chegada o Pedro não segue o jogador, então
## a fala vem na caixa, como a explicação do corpo, e não no balão dele.
const CUIAS_DE_MUNGUNZA := 6
const PASSOS_DO_SOCORRO := ["ponte_lenha", "tabuas"]


func _conferir_o_socorro() -> void:
	var ponte = _cadeias.get("pedro_ponte")
	if ponte == null or not ponte.iniciado or ponte.acabou() or ponte.aconteceu("socorro"):
		return
	if not PASSOS_DO_SOCORRO.has(str(ponte.passo_atual().get("id", ""))):
		return
	if Dialogo.ocupado() or Energia.aguenta("bater", 1.0):
		return
	if Inventario.tem("mungunza") or Efeitos.tem("comida"):
		return
	ponte.registrar_evento("socorro")
	var linhas: Array = []
	for fala in (Jogo.dados("res://data/missoes_ponte.json").get("socorro", []) as Array):
		linhas.append(str(IdiomaMenu.campo(fala, "texto", "")))
	Dialogo.falar(str(pedro.dados.get("nome", "Pedro")) if pedro != null else "Pedro", linhas)
	Inventario.adicionar("mungunza", CUIAS_DE_MUNGUNZA)
	Audio.efeito("pegar")


## A PONTE ABRE SOZINHA QUANDO O TUTORIAL ACABA (07/10: "depois que conclui as 16
## atividades iniciais, não abriu nenhuma outra missão"). É o enredo — a trava da
## jornada da fazenda —, e no 2D o enredo entra na frente da lista sem esperar E.
## O Pedro está ao lado do jogador na despedida, e anuncia o passo ali mesmo. As
## frentes de ofício dele (as armas, o ofício, a lombada) seguem abrindo no E.
## E SÓ COM O PEDRO AO LADO (PERTO_PARA_A_PONTE): é ele quem anuncia, e anunciar de
## longe seria um balão que ninguém vê. Na despedida ele está junto do jogador.
const PERTO_PARA_A_PONTE := 8.0


func _conferir_a_ponte() -> void:
	var da_ponte = _cadeias.get("pedro_ponte")
	if da_ponte == null or da_ponte.iniciado or pedro == null or player == null:
		return
	if pedro.terminou_o_tutorial() and player.global_position.distance_to(pedro.global_position) <= PERTO_PARA_A_PONTE:
		da_ponte.comecar(2.0)


## O SEGUNDO TUTORIAL ABRE SOZINHO NA SEXTA COLHEITA, como no 2D (`tutorial.gd` de lá):
## com o tutorial acabado, a fila do quintal começa e o Pedro chama (#160). Sem E e sem
## aviso de fila trancada: ele dá cada aviso uma vez, e já tem o da chapada a dar.
func _conferir_o_quintal() -> void:
	var quintal = _cadeias.get("pedro_quintal")
	if quintal == null or quintal.iniciado or pedro == null or lavoura == null:
		return
	if pedro.terminou_o_tutorial() and lavoura.colheitas >= COLHEITAS_DO_QUINTAL:
		quintal.comecar(2.0)


func _conferir_as_metas() -> void:
	for especie in _metas_dos_bichos:
		var meta: Dictionary = _metas_dos_bichos[especie]
		var fila = _cadeias.get(str(meta["cadeia"]))
		if fila != null and not fila.iniciado and Luta.abatidos(str(especie)) >= int(meta["conta"]):
			fila.comecar(1.0)


## OS ACONTECIMENTOS DAS FRENTES: o golpe que acertou, o bicho que caiu, o que
## ficou tonto, o bote esquivado, o peixe que veio na linha e o talento
## destravado. Métodos, e não lambdas: os sinais são de autoloads.
func _ao_acertar(golpe: String, especie: String, derrubou: bool, tonteou: bool) -> void:
	_avisar_as_cadeias("acertou:" + golpe)
	if derrubou:
		_avisar_as_cadeias("derrubou:" + especie)
	if tonteou:
		_avisar_as_cadeias("tonteou")


func _ao_esquivar(_especie: String) -> void:
	_avisar_as_cadeias("esquivou")


func _ao_pescar(_peixe: String, quantos: int) -> void:
	for i in maxi(quantos, 1):
		_avisar_as_cadeias("pescou")


## PLANTOU, E O QUÊ: "plantou:bananeira", e "plantou:fruteira" para as culturas perenes —
## o pomar do segundo tutorial fecha com qualquer fruteira (#160).
func _ao_plantar(cultura: String) -> void:
	_avisar_as_cadeias("plantou:" + cultura)
	if bool((Plantacao.CULTURAS.get(cultura, {}) as Dictionary).get("perene", false)):
		_avisar_as_cadeias("plantou:fruteira")


## Destravou um nó da teia: o `Talentos` só diz que mudou, e a carga do save
## também muda — por isso a conta começa DEPOIS da partida salva
## (`_ligar_os_acontecimentos_das_frentes`), e só a que cresce avisa.
var _talentos_destravados := -1
var _talentos_vistos: Array = []


func _ao_mudar_os_talentos() -> void:
	var agora: int = Talentos.destravados.size()
	if _talentos_destravados >= 0 and agora > _talentos_destravados:
		_avisar_as_cadeias("destravou_talento")
		# E QUAL FOI (#160): "destravou:curral" fecha o passo do curral do segundo tutorial.
		for no in Talentos.destravados:
			if not _talentos_vistos.has(no):
				_avisar_as_cadeias("destravou:" + str(no))
	_talentos_vistos = Talentos.destravados.duplicate()
	_talentos_destravados = agora


func _ligar_os_acontecimentos_das_frentes() -> void:
	_talentos_destravados = Talentos.destravados.size()
	_talentos_vistos = Talentos.destravados.duplicate()
	for ligado in [[Luta.acertou, _ao_acertar], [Luta.esquivou, _ao_esquivar],
			[Pesca.terminou, _ao_pescar], [Talentos.mudou, _ao_mudar_os_talentos],
			[Inventario.mudou, _ao_mudar_a_mochila]]:
		if not (ligado[0] as Signal).is_connected(ligado[1]):
			(ligado[0] as Signal).connect(ligado[1])
	# O J ABERTO (a caderneta da chegada).
	if painel != null and painel.has_signal("abriu") and not painel.abriu.is_connected(_avisar_as_cadeias):
		painel.abriu.connect(_avisar_as_cadeias.bind("abriu_painel"))


func _ao_migrar_de_fe(_de: String, para: String) -> void:
	_ao_entrar_numa_fe(para)


## ENTROU NUMA FÉ — a primeira ou outra: as filas que esperam por isso ficam
## sabendo (a da Dona Zefa fecha a escolha), e a missão própria da fé abre, se
## ainda não abriu.
func _ao_entrar_numa_fe(fe: String) -> void:
	_avisar_as_cadeias("adotou_fe")
	var fila = _cadeias.get("fe_" + fe)
	if fila != null and not fila.iniciado:
		fila.comecar(1.5)


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


## O jogador chega de barco pelo píer; a orientação inicial olha de volta para a praia.
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
		pedro.ligar_moradores(_achar_morador)
		# A narração já aparece inteira no balão, com duração da leitura/voz e
		# limpeza pela fila. Duplicá-la no rodapé deixava o recado após a fala.
		# O QUE A CHEGADA PAGA é dito no HUD, como nas filas dos moradores.
		pedro.pagou.connect(func(texto: String) -> void: hud.set_notice(texto))
		pedro._cadeia.passo_cumprido.connect(hud.tarefa_concluida)
		# AS CENAS DA CHEGADA (data/cenas.json): a apresentação do Tonho, a vista da praça, a casa.
		pedro._cadeia.cena.connect(_tocar_a_cena.bind(pedro._cadeia))
		pedro.entregou.connect(func(texto: String) -> void: hud.set_notice(texto))
		# QUEM FICOU PARA TRÁS NA CONDUÇÃO vê, no alto da tela, o aviso de voltar.
		pedro.esperando_quem_ficou.connect(func(esperando: bool) -> void:
			hud.set_aviso_de_espera(tr("%s voltou para te buscar: siga com ele.") % str(pedro.dados.get("nome", "Pedro")) if esperando else ""))
	placas = PlacasNomes.new()
	placas.name = "PlacasNomes"
	add_child(placas)
	# AS PLAQUINHAS ABAIXO DOS BALÕES (#103): numa camada própria, sob a dos
	# balões de fala (10) e a do HUD (20). No `map_layer` do HUD elas ficavam por
	# cima do balão — "a camada do chat deve ser acima da camada do nome" —, e o
	# HUD segue cobrindo as duas.
	var camada_das_placas := CanvasLayer.new()
	camada_das_placas.name = "CamadaDasPlacas"
	camada_das_placas.layer = CAMADA_DAS_PLACAS
	add_child(camada_das_placas)
	var chao_das_placas := Control.new()
	chao_das_placas.name = "Placas"
	chao_das_placas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chao_das_placas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	camada_das_placas.add_child(chao_das_placas)
	_chao_das_placas = chao_das_placas
	placas.configurar(player, chao_das_placas)
	# Seta da missão: cone e anel no mundo + chevron na borda da tela seguem o
	# alvo DA MISSÃO ACOMPANHADA (ver `_mostrar_a_acompanhada`).
	_seta = SetaMissao.new()
	_seta.name = "SetaMissao"
	add_child(_seta)
	_seta.configurar(hud.map_layer())
	CadernoDoVale.mudou.connect(_mostrar_a_acompanhada)
	CadernoDoVale.abriu.connect(_ao_abrir_missao)
	# Tubarão da parte funda: persegue só o jogador nadando no fundo; o susto vai ao HUD.
	# Depois dele, os cardumes e as raias (fauna_vale.gd), que rondam o pesqueiro dele.
	var tubarao := Tubarao.new()
	tubarao.name = "Tubarao"
	add_child(tubarao)
	tubarao.configurar(world, player, func(texto: String) -> void: hud.set_notice(texto))
	add_child(preload("res://scripts/prototipo_3d/fauna_vale.gd").new(world, player, tubarao, saveiro))
	# E os bichos de casa: cães, gatos, porcos, bandos de aves (bichos_de_casa.gd).
	add_child(preload("res://scripts/prototipo_3d/bichos_de_casa.gd").new(world, player))
	# Vida no chão é noite no chão — e a cama e as duas da manhã também viram a
	# noite pelo mesmo nó (queda.gd). Com o cômodo da casa, acorda-se ao pé da
	# cama; sem ele, na porta.
	var queda := Queda.new()
	queda.name = "Queda"
	add_child(queda)
	queda.configurar(world, player, hud)
	queda.interiores = interiores
	queda.guia = pedro
	noite = queda
	casa = CasaDoJogador.new()
	casa.name = "CasaDoJogador"
	add_child(casa)
	casa.configurar(player, hud, interiores, queda)
	fiado_tonho = load("res://scripts/prototipo_3d/fiado_tonho.gd").new()
	fiado_tonho.name = "FiadoTonho"
	add_child(fiado_tonho)
	lavoura = LavouraVale.new()
	lavoura.name = "Lavoura"
	add_child(lavoura)
	lavoura.configurar(world, player, hud)
	# O CURRAL DO QUINTAL (#160): o galinheiro que o talento Curral levanta, as três
	# galinhas e os ovos de cada manhã.
	curral = CurralVale.new()
	curral.name = "Curral"
	add_child(curral)
	curral.configurar(world, self, player, hud)
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
	luta.configurar(world, player, hud, hud_layer)
	achados.configurar(world, player, hud, luta, hud_layer)
	achados.achou.connect(_ao_achar)
	# O painel da tecla J (painel_vale.gd), por cima do HUD.
	painel = PainelVale.new()
	painel.name = "Painel"
	painel.retratos = retratos
	add_child(painel)
	painel.abriu.connect(_parar_o_jogador)
	painel.fechou.connect(_soltar_o_jogador)
	# O × e as ações que fecham o painel por dentro (menu, sair) não passam pelo
	# dono das telas: sem este aviso, o vale ficava parado atrás de painel
	# nenhum. Quando é o dono que fecha, ele ignora o aviso (`fechou_por_conta`).
	painel.fechou.connect(func() -> void: telas.fechou_por_conta("painel"))
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
	hud_layer.add_child(minimapa)
	minimapa.configurar(player, pedro, hud)
	_mostrar_a_acompanhada()
	# Os sustos da mata: o vulto que "fecha o jogo" e as pegadas do Curupira que enlouquecem o mapa.
	# Depois do minimapa, do mapa e da seta, que ouvem a loucura (sustos_da_mata.gd).
	SustosDaMata.montar(self)


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
	_ver_se_correu(_delta)
	# A porta da casa acompanha a chegada também a cada meio segundo: o passo
	# muda por sinal, mas a carga, o atalho de depuração e quem põe o passo à
	# mão não passam por ele.
	_conferir_a_porta_em -= _delta
	if _conferir_a_porta_em <= 0.0:
		_conferir_a_porta_em = 0.5
		_acertar_a_porta_da_casa()
		_conferir_as_metas()
		_conferir_o_quintal()
		_conferir_a_ponte()
		_acertar_o_tonho_da_chegada()
	# O SOCORRO A CADA QUADRO, e não a cada meio segundo: com o corpo de três
	# barras quem cansa é o vigor, que volta sozinho a vinte por segundo — em meio
	# segundo o braço que não aguentava bater já aguenta, e a panela nunca vinha.
	_conferir_o_socorro()
	_atualizar_relogio()


## A PRIMEIRA CORRIDA (o passo `correr` da chegada): o jogador correu um trecho
## de verdade, e não só tocou o Shift parado. Avisado uma vez por carga; a cadeia
## guarda na memória dela, que vai no save.
const CORREU_DEPOIS_DE := 1.2
var _correndo_ha := 0.0
var _correu_avisado := false
var _conferir_a_porta_em := 0.0


func _ver_se_correu(delta: float) -> void:
	if _correu_avisado:
		return
	var depressa: bool = player.is_running() and Vector2(player.velocity.x, player.velocity.z).length() > player.walk_speed + 0.5
	_correndo_ha = _correndo_ha + delta if depressa else 0.0
	if _correndo_ha >= CORREU_DEPOIS_DE:
		_correu_avisado = true
		_avisar_as_cadeias("correu")


func _atualizar_relogio() -> void:
	hud.set_clock("%s\n%s" % [Dia.texto_hora(), tr(PERIODOS.get(Dia.periodo(), ""))])


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


## Alguma fila do vale abriu e ainda não acabou?
func _alguma_fila_em_andamento() -> bool:
	for cadeia in get_tree().get_nodes_in_group(CadeiaDeMissoes.GRUPO):
		if cadeia.has_method("em_andamento") and bool(cadeia.em_andamento()):
			return true
	return false


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
		# ENTRE UM PASSO E O SEGUINTE da mesma fila o caderno fica um instante sem atual (o
		# cumprido saiu, o próximo ainda não foi anunciado), e o HUD piscava "fale com Pedro:
		# ele veio te esperar no píer" (07/10). Com uma fila andando, fica como está.
		if _alguma_fila_em_andamento():
			return
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
			elif tecla_dos_moradores != null and tecla_dos_moradores.fechar_a_fala():
				# A conversa aberta é o que está aberto (#220): o Esc a fecha, e o menu fica para o próximo.
				pass
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
	hud.set_notice("Relógio adiantado: %s (%s)" % [Dia.texto_hora(), tr(PERIODOS.get(Dia.periodo(), ""))])


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
		mapa.abrir(world, player, hud_layer)
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
	_acertar_as_placas()



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
	player.set_camera_modo(CameraMouse.modo())

func _pause_valley() -> void:
	# LEMBRA O MODO DE CÂMERA ANTES DE SOLTAR O CURSOR.
	#
	# Era aqui o defeito de "depois do Esc o jogo volta com a câmera solta sem
	# eu apertar C": pausar solta o cursor, porque menu com o mouse preso é
	# menu que não se clica — mas nada devolvia o modo depois. Quem jogava no
	# modo livre voltava do menu no modo de arrastar, sem ter pedido.
	player.set_captured(false)
	_telas_que_param += 1
	Dia.segurar(MOTIVO_DA_TELA)
	get_tree().paused = true
	# O HUD para com a árvore: o estado do relógio se atualiza aqui.
	if is_instance_valid(hud):
		hud.atualizar_estado_do_relogio()
	_prender_o_calendario()


## Desfaz o `_pause_valley`, INCLUSIVE a câmera.
func _retomar_o_vale() -> void:
	# Fecha uma tela; com outra ainda aberta por baixo, o vale segue parado.
	_telas_que_param = maxi(0, _telas_que_param - 1)
	if _telas_que_param > 0:
		return
	get_tree().paused = false
	Dia.soltar(MOTIVO_DA_TELA)
	if is_instance_valid(hud):
		hud.atualizar_estado_do_relogio()
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
	_acertar_as_placas()


## Há um modal na frente do vale? As telas registradas em `telas` (que já contam a
## mochila e o baú, abertos por ali) e os Ajustes do HUD, que não são tela.
func modal_aberto() -> bool:
	if Mochila.aberta or (hud != null and hud.settings_open()):
		return true
	return telas != null and telas.aberta() != ""


## AS PLAQUINHAS DE NOME SÃO DO MUNDO, e somem com o que se põe na frente dele:
## uma tela aberta, o cartão da primeira vez e a festa da missão. As três
## perguntas num lugar só, porque uma coisa fecha com a outra ainda na tela — o
## cartão do primeiro cordel dá lugar ao folheto, a festa acaba com o painel
## aberto —, e quem devolvesse as placas por conta própria as acenderia por cima
## da que ficou.
func _acertar_as_placas() -> void:
	# TODO MODAL RECOLHE A INTERFACE DO VALE (#143, #199). Mochila, baú, Arraial,
	# Diário, Teia, Coleção, folheto, menu do Esc, Controles, Apoios e Ajustes são
	# todos camadas à parte; ocultar o ancestral do HUD recolhe também missão,
	# relógio, barras, atalhos, minimapa, dicas, avisos e a seta, sem reativar
	# filhos expirados quando a tela fecha. A regra mora SÓ aqui: tela nova que
	# entra em `telas` já a herda. O mapa (M) tem a dele em `hud.set_map_open`.
	#
	# A CENA TAMBÉM (#215): enquanto uma cena dos dados toca (`cena_vale.gd`), o jogador assiste, e só o
	# balão de fala e as tarjas ficam — o painel de missão, o relógio e as barras, os atalhos, o minimapa,
	# a barra de mão, a seta, as plaquinhas e as dicas se recolhem e voltam no fim dela.
	var na_cena: bool = cenas != null and bool(cenas.em_cena())
	if hud_layer != null:
		hud_layer.visible = _saindo or not (modal_aberto() or na_cena)
	if is_instance_valid(_seta):
		_seta.ocultar(na_cena)
	if placas == null:
		return
	var coberto: bool = Dialogo.ativo or (telas != null and telas.aberta() != "") \
		or (aviso_da_primeira_vez != null and aviso_da_primeira_vez.aberto()) \
		or (conquista != null and conquista.ativa()) or na_cena
	placas.permitir(not coberto)
	if selo_do_viajante != null:
		selo_do_viajante.permitir(not coberto)


## E CALOU. Falas encadeadas abrem na linha seguinte do mesmo `await`, então o
## vale espera o fim do quadro antes de voltar a andar: se outra fala já abriu,
## ele continua parado, sem soltar e prender o cursor entre uma e outra.
## A BARRA DA VEZ NA EXPLICAÇÃO DO CORPO (#106): cada linha do Pedro acende a
## barra de que fala e apaga o resto — a vida, o fôlego (a do meio, também no
## nado), o vigor; no respiro, tudo escuro. Linha de outra fala não mexe.
const BARRA_DA_VOZ := {
	"pedro_corpo_respiro": "",
	"pedro_corpo_vida": "Vida",
	"pedro_corpo_folego": "Folego",
	"pedro_corpo_nado": "Folego",
	"pedro_corpo_vigor": "Stamina",
	"pedro_corpo_vigor_cansado": "Stamina",
}


func _ao_mudar_a_linha_da_fala(voz: String) -> void:
	if BARRA_DA_VOZ.has(voz) and hud != null:
		hud.destacar_barra(str(BARRA_DA_VOZ[voz]))


func _ao_calar_a_fala() -> void:
	if hud != null:
		hud.apagar_destaque()
	_retomar_se_a_fala_acabou.call_deferred()


func _retomar_se_a_fala_acabou() -> void:
	if not _fala_parou_o_vale or Dialogo.ativo:
		return
	_fala_parou_o_vale = false
	_retomar_o_vale()
	_acertar_as_placas()


## O CORDEL NO PAPEL (#21): o `Folheto`, inteiro, por cima do vale — desenhado
## na tela do vale, em alta (ver `_na_tela_do_vale`).
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
	if tipo != "cordel":
		return
	# O PRIMEIRO CORDEL vem com o aviso — o que é um cordel, e que ele fica no
	# almanaque —, e o papel abre depois dele: UM QUADRO DEPOIS. O vale volta do
	# aviso no fim do quadro em que ele fecha (`_retomar_se_a_fala_acabou`); com
	# o papel aberto no mesmo quadro, essa volta soltava o vale por baixo do papel
	# — o E ia para o mundo e comia o que estava na mão — e o papel guardava o
	# relógio parado como se fosse o de antes dele.
	if Colecao.quantos("cordeis") == 1 and aviso_da_primeira_vez != null:
		await aviso_da_primeira_vez.mostrar("cordel", CapaDeCordel.textura(id))
		await get_tree().process_frame
	ler_o_folheto(id)


## A PRIMEIRA ÁRVORE do almanaque vem com o aviso de onde ela fica guardada.
func _ao_conhecer_a_arvore(_especie: String) -> void:
	if Almanaque.conhecidas().size() == 1 and aviso_da_primeira_vez != null:
		aviso_da_primeira_vez.mostrar("arvore")


## O PRIMEIRO MERGULHO EM ÁGUA FUNDA (#96) vem com o aviso de que parar é boiar e
## o fôlego volta — na live ninguém sabia, e o jogador quase se afogou; o Pedro
## só explica o nado na caminhada do tutorial. Uma vez por partida: a marca vai
## ao save (`avisou_agua_funda`).
var _avisou_agua_funda := false


func _ao_mudar_o_nado(nadando: bool) -> void:
	if not nadando or _avisou_agua_funda or aviso_da_primeira_vez == null:
		return
	_avisou_agua_funda = true
	aviso_da_primeira_vez.mostrar("agua_funda")


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
	# Os Ajustes fecharam por aqui: a interface do vale volta se nada mais cobre.
	_acertar_as_placas()


## Volta ao menu com a tela de carregamento (o menu monta o vale de novo ao abrir).
func _return_to_menu() -> void:
	if _saindo:
		return
	_saindo = true
	_acertar_as_placas()
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
## Ela é tela do 2D (`mochila.gd`), e no vale abria na camada 15 — por baixo do
## HUD, que é a 20, desenhava por cima dela e ficava com os cliques. O arquivo do
## 2D não se mexe daqui: o vale acerta a CAMADA dela e, desde 07/10, a desenha
## pela `mochila_vale.gd`, que estende o arquivo do 2D com as medidas da tela do
## vale (1280×720) e a identidade dos menus dele. Até então ela era desenhada
## nos 640×360 de lá e ampliada 1,8× — e a letra saía serrilhada. Escala em volta
## do centro da tela, e só quando a janela não é a do vale, porque os filhos
## dela se ancoram na tela inteira e o painel fica no meio. O mouse continua
## certo: a camada leva o clique de volta à coordenada dela.
## A tela do vale, em que as telas que vieram do 2D são desenhadas: a caixa de
## fala, a mochila, o cartão do amanhecer e o folheto.
const TELA_DO_VALE := Vector2(1280, 720)
## A camada das telas do vale (a do painel J); só uma abre por vez.
const CAMADA_DAS_TELAS := 25
## O cartão do amanhecer (#21), acima da tela preta da queda (30, `queda.gd`):
## ele é lido NO escuro, antes de clarear — como o do 2D fica acima do véu.
const CAMADA_DO_AMANHECER := 31


func _ajustar_a_mochila() -> void:
	var tela := get_viewport().get_visible_rect().size
	var escala := minf(tela.x / TELA_DO_VALE.x, tela.y / TELA_DO_VALE.y)
	Mochila.layer = CAMADA_DAS_TELAS
	Mochila.transform = Transform2D(0.0, Vector2(escala, escala), 0.0, tela * 0.5 * (1.0 - escala))


## AS TELAS QUE VIERAM DO 2D, na camada e no tamanho do vale. Chamado de novo
## quando a janela muda de tamanho.
func _ajustar_as_telas_do_2d() -> void:
	_ajustar_a_mochila()
	# A fala longa (#21) fica na camada das telas: por cima do HUD, e nenhuma
	# tela fica aberta com ela (ver `_ao_abrir_a_fala`).
	# TODAS NA TELA DO VALE (07/10): a caixa de fala e o cartão do amanhecer eram
	# desenhados no quadro de 640×360 do 2D e ampliados duas vezes — "a qualidade
	# tá muito serrilhada". Cada um passou a ter o dobro das medidas de lá
	# (`dialogo_vale.gd`, `amanhecer_vale.gd`), como o folheto desde 06/10.
	_na_tela_do_vale(Dialogo, CAMADA_DAS_TELAS)
	_na_tela_do_vale(Folheto, CAMADA_DAS_TELAS)
	_na_tela_do_vale(Amanhecer, CAMADA_DO_AMANHECER)


## UMA TELA DESENHADA NA TELA DO VALE (1280×720), inteira na janela: o folheto,
## a caixa de fala e o cartão do amanhecer, que vieram do 2D no quadro de
## 640×360 e eram ampliados duas vezes — a letra borrava. Medidos na tela do
## vale, a escala só existe se a janela não for a do vale. Estas desenham a
## partir do canto da tela (a caixa de fala ancora no rodapé DELA), então a
## escala parte do canto, e a sobra da janela que não é 16:9 fica dividida dos
## dois lados.
func _na_tela_do_vale(camada: CanvasLayer, numero: int) -> void:
	var tela := get_viewport().get_visible_rect().size
	var escala := minf(tela.x / TELA_DO_VALE.x, tela.y / TELA_DO_VALE.y)
	camada.layer = numero
	camada.transform = Transform2D(0.0, Vector2(escala, escala), 0.0,
		(tela - TELA_DO_VALE * escala) * 0.5)


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
func _retomar_a_partida() -> bool:
	if not Partida.tem_vaga() or not Salvamento.existe_partida():
		return false
	var guardado := Salvamento.ler()
	if guardado.is_empty():
		# Há arquivo e ele não abriu: partida de uma versão mais nova. O arquivo
		# não é tocado; o jogador fica sabendo, em vez de achar a vila do zero.
		if not Salvamento.ultimo_relato.is_empty():
			hud.set_notice(" ".join(Salvamento.ultimo_relato))
		return false
	if Salvamento.carregar(guardado):
		hud.set_notice(_texto_da_partida("de_volta"))
		if not Salvamento.ultimo_relato.is_empty():
			hud.set_notice(" ".join(Salvamento.ultimo_relato))
		return true
	return false


## O MACHADO CHEGA NA PONTE, nos machados do avô do Pedro ("buscar_machado",
## data/missoes_ponte.json), como no 2D: "lembre-se que o machado só é
## introduzido na missão da ponte, com o Pedro indo buscar o machado em casa".
## O vale chegou a dar um machado de saída a todo jogo novo, e a chegada dava
## outro na lenha da casa; os dois saíram, e o fogo da primeira noite é de
## galho seco, catado na mão (data/recursos_3d.json, "lenha_casa_taipa").
##
## AS FILAS QUE PEDEM MADEIRA ESPERAM O MACHADO: o cabo da foice e o mato do
## Damião, a rede do Tonho, a carroça do Seu Benedito. No 2D elas vêm depois do
## tutorial, e a ponte é do tutorial de lá. Quem já tem um machado — partida
## salva de antes, ou um comprado — não espera.
func _ja_recebeu_o_machado() -> bool:
	var da_ponte = _cadeias.get("pedro_ponte")
	if da_ponte != null and da_ponte.passou("buscar_machado"):
		return true
	return Inventario.tem("machado") or Inventario.tem("machado_de_aco") \
		or Equipamento.da_familia_em_uso("machado") != ""


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
		"folego_oceano": player.folego_atual(),
		# O aviso da água funda já dado (#96): carregar não o repete.
		"avisou_agua_funda": _avisou_agua_funda,
		"hora": Dia.hora,
		"horas_decorridas": Dia.horas_decorridas,
		# O jogador parou o relógio nesta partida: daqui em diante ela não conta
		# conquista (ver `Dia.relogio_alterado`).
		"relogio_alterado": Dia.relogio_alterado,
		# E O REGISTRO DO RELÓGIO: quando e como o jogador mexeu nele (ver
		# `Dia.registro_do_relogio`). A marca diz se; o registro, quando.
		"registro_do_relogio": Dia.registro_do_relogio.duplicate(true),
		# O RELÓGIO PARADO PELO JOGADOR: carregar não o religa calado. As telas
		# seguram o dia por motivo (#100), e `Dia.pausado` é só a escolha dele.
		"pausado": Dia.pausado,
		"barra_de_ferramentas_migrada": _barra_de_ferramentas_migrada,
		"visitados": _visited.keys(),
		"segundos_apresentacao": apresentacao_do_povoado.segundos if apresentacao_do_povoado != null else _segundos_apresentacao,
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
		estado["arvores_cortadas"] = _arvores_info.estado_para_salvar()
		# As piaçabeiras que já deram fibra nesta estação.
		estado["piacava_tirada"] = _arvores_info.fibra_para_salvar()
	if saveiro != null:
		estado["saveiro"] = saveiro.estado_para_salvar()
	if pedro != null:
		estado["pedro"] = {"missao": pedro.missao, "iniciado": pedro.get("_iniciado"),
			"despedida": pedro.get("_despedida_feita"), "passo": pedro.passo_em_curso(),
			"levados": pedro.lembrancas()}
	var luta := get_node_or_null("Luta")
	if luta != null:
		estado["mortes"] = luta.mortes.duplicate(true)
		if luta.coleta != null:
			estado["coleta_no_chao"] = luta.coleta.estado_para_salvar()
	# O BAÚ DA CASA, como no 2D (`travas.bau_da_casa`).
	if casa != null:
		estado["casa"] = casa.estado_para_salvar()
	if fiado_tonho != null:
		estado["fiado_tonho"] = fiado_tonho.estado_para_salvar()
	# A LAVOURA inteira: cada leito é escolha do jogador, e nada se recalcula.
	if lavoura != null:
		estado["lavoura"] = lavoura.estado_para_salvar()
	# O NINHO: os ovos e o dia da postura (o galinheiro é o talento, que já vai).
	if curral != null:
		estado["curral"] = curral.estado_para_salvar()
	# O FOGO DA FOGUEIRA: para quantos pratos ainda dá (07/10).
	estado["fogueira"] = fogo_da_fogueira
	# O QUE O VIAJANTE JÁ DISSE DE UMA VEZ SÓ (#187).
	if viajante != null:
		estado["viajante"] = viajante.estado_para_salvar()
	return estado


func restaurar_do_save(estado: Dictionary) -> void:
	_segundos_apresentacao = maxf(0.0, float(estado.get("segundos_apresentacao", 0.0)))
	if apresentacao_do_povoado != null:
		apresentacao_do_povoado.segundos = _segundos_apresentacao
	player.definir_folego(float(estado.get("folego_oceano", player.folego_maximo())))
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
	Dia.pausado = bool(estado.get("pausado", false))
	_barra_de_ferramentas_migrada = bool(estado.get("barra_de_ferramentas_migrada", false))
	_avisou_agua_funda = bool(estado.get("avisou_agua_funda", false))
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
		# A chave velha é a do tempo em que só o coqueiro se cortava.
		_arvores_info.restaurar_do_save(estado.get("arvores_cortadas", estado.get("coqueiros_cortados", [])))
		_arvores_info.restaurar_fibra(estado.get("piacava_tirada", []))
	# O SAVEIRO depois do caderno e das cadeias: a encomenda da estação mora no
	# caderno, e só volta com a cadeia do Benedito acabada.
	if saveiro != null:
		saveiro.restaurar(estado.get("saveiro", {}))
	var guia: Dictionary = estado.get("pedro", {})
	if pedro != null and not guia.is_empty():
		pedro.set("_iniciado", bool(guia.get("iniciado", false)))
		pedro.set("_despedida_feita", bool(guia.get("despedida", false)))
		pedro.missao = _passo_da_chegada_salvo(guia)
		pedro.lembrar(guia.get("levados", []))
		# Ele NÃO reanuncia o passo: quem salvou no primeiro passo ouvia a
		# abertura do jogo de novo ao voltar, como se a partida recomeçasse. O
		# que volta é o objetivo — caderno e marcador. Ver `CadeiaDeMissoes.retomar`.
		pedro.retomar()
		# Durante o tutorial ele volta ao lado do jogador; depois dele, no posto dele.
		if pedro.terminou_o_tutorial():
			pedro.ir_ao_posto_agora()
		elif pedro.fica_no_passo() and saveiro != null and saveiro.na_chegada() and saveiro.lugar_do_pedro().is_finite():
			# Salvo no convés, antes de descer: ele volta à ponta da prancha.
			pedro.global_position = saveiro.lugar_do_pedro()
		else:
			pedro.global_position = world.ground_position(player.global_position + Vector3(-1.6, 0, 1.4), 0.05)
	var luta := get_node_or_null("Luta")
	if luta != null:
		luta.restaurar_mortes(estado.get("mortes", []))
		if luta.coleta != null:
			luta.coleta.restaurar(estado.get("coleta_no_chao", []))
	if casa != null and estado.has("casa"):
		casa.restaurar(estado["casa"])
	if fiado_tonho != null:
		fiado_tonho.restaurar(estado.get("fiado_tonho", {}))
	_conferir_a_enxada_do_finado()
	_conferir_a_chave_da_casa()
	if lavoura != null and estado.has("lavoura"):
		lavoura.restaurar(estado["lavoura"])
	if curral != null and estado.has("curral"):
		curral.restaurar(estado["curral"])
	fogo_da_fogueira = int(estado.get("fogueira", PRATOS_POR_LENHA))
	if viajante != null:
		viajante.restaurar(estado.get("viajante", {}))
	# As lajes e o cercado acompanham a fila e a obra que acabaram de voltar.
	if cemiterio != null:
		cemiterio.acertar()


## DEPURAÇÃO: `-- --lugar=<nome>` começa o jogador direto num lugar do
## `Lugares` (praca, igreja, cemiterio, mirante...), sem refazer o caminho.
## Vem depois da partida salva: pedir um lugar é pedir para ir lá agora.
func _comecar_no_lugar_pedido() -> bool:
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--lugar="):
			continue
		var nome := arg.substr("--lugar=".length())
		if not Lugares.resolve(nome):
			push_warning("--lugar=%s: o vale não tem esse lugar. Há: %s" % [nome, ", ".join(Lugares.nomes())])
			return false
		player.global_position = world.ground_position(Lugares.ponto(nome), 0.07)
		player.velocity = Vector3.ZERO
		if pedro != null:
			pedro.global_position = world.ground_position(player.global_position + Vector3(-1.6, 0, 1.4), 0.05)
		print("DEPURACAO: começando em %s" % nome)
		return true
	return false


func _notification(what: int) -> void:
	# Fechar a janela salva, como voltar ao menu: o vale não tem cama, e sem
	# isto quem fecha o jogo perde o dia.
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Partida.salvar()


# --- o painel -----------------------------------------------------------------

## Abre o painel com as abas do lugar onde o jogador está (bancadas_vale.gd).
##
## PEDE AO DONO DAS TELAS, e não abre por fora dele: é o dono que fecha a tela
## que estiver aberta, pausa o vale e guarda a câmera. Quem abrir direto pula
## tudo isso — e foi por aí que o almanaque apareceu atrás do painel.
##
## `obra` é o sítio de obra que o E pediu ("poco"): as obras dele, e não as do
## sítio mais perto pela regra do J. O pedido vale só para esta abertura: o J que
## vem depois não herda a aba nem o sítio de um E que o dono das telas recusou.
func abrir_o_painel(aba: int = 0, obra: String = "") -> void:
	_aba_pedida = aba
	_obra_pedida = obra
	if telas != null:
		telas.abrir("painel")
	_aba_pedida = -1
	_obra_pedida = ""


## A abertura CRUA do painel, que é o que o dono das telas chama. Ninguém mais
## deve chamá-las: elas não pausam nada e não mexem na câmera.
##
## O J NÃO PEDE ABA, e abre em OBRAS quando a missão de agora manda tocar obra no
## sítio onde o jogador está ("não consegui interagir com o poço": o J abria no
## diário, e a aba de obras ficava a um Tab que ninguém sabia). Em qualquer outro
## lugar abre no diário, como sempre.
func _abrir_painel_cru() -> void:
	if painel == null or _lendo() or mapa.aberto or _saindo:
		return
	BancadasVale.aplicar(painel, world, player.global_position)
	if _obra_pedida != "":
		painel.obra_em_foco = _obra_pedida
	var da_missao := ""
	if painel.obra_em_foco != "":
		da_missao = CadeiaDeMissoes.obra_que_se_pede(get_tree(), painel.obra_em_foco)
	var aba := _aba_pedida
	if aba < 0:
		aba = PainelVale.Aba.OBRAS if da_missao != "" else PainelVale.Aba.MISSOES
	painel.abrir(aba, da_missao if aba == PainelVale.Aba.OBRAS else "")


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


func _letra_da_mochila() -> String:
	return Atalhos.letra("mochila")


func _ao_pedido_do_painel(acao: String) -> void:
	if acao.begins_with("vaga:"):
		_trocar_vaga(int(acao.trim_prefix("vaga:")))
		return
	match acao:
		"menu":
			_return_to_menu()
		"sair":
			Partida.salvar()
			get_tree().quit()
		"destravar":
			player._back_to_land()


func _trocar_vaga(slot: int) -> void:
	if slot < 1 or slot > Salvamento.QUANTOS_SLOTS or slot == Salvamento.slot_atual:
		return
	# Um arquivo recusado nao autoriza iniciar por cima da vaga de destino.
	if Salvamento.existe_partida(slot) and Salvamento.ler(slot).is_empty():
		hud.set_notice(painel.texto_vagas("load_failed"))
		return
	if Partida.tem_vaga() and not Partida.salvar():
		hud.set_notice(painel.texto_vagas("save_failed"))
		return
	_saindo = true
	_parar_o_jogador()
	get_tree().paused = false
	Partida.comecar(slot)
	# A nova instancia aplica a vaga selecionada depois do carregamento normal.
	get_tree().change_scene_to_file(scene_file_path)


## Alguma tela de leitura aberta? É o que a peçonha pergunta (Vida.esta_lendo).
func _lendo() -> bool:
	return painel != null and painel.aberto


func _exit_tree() -> void:
	if Vida.esta_lendo == Callable(self, "_lendo"):
		Vida.esta_lendo = Callable()
	if Mochila.letra_de_fechar == Callable(self, "_letra_da_mochila"):
		Mochila.letra_de_fechar = Callable()
	if Mochila.abrir_documento == Callable(self, "_ler_documento"):
		Mochila.abrir_documento = Callable()
	for ligado in [[Cozinha.cozinhou, _ao_cozinhar], [Cozinha.comeu, _ao_comer], [Oficina.fabricou, _ao_fabricar],
			[Luta.acertou, _ao_acertar], [Luta.esquivou, _ao_esquivar], [Pesca.terminou, _ao_pescar],
			[Talentos.mudou, _ao_mudar_os_talentos], [Inventario.mudou, _ao_mudar_a_mochila]]:
		if (ligado[0] as Signal).is_connected(ligado[1]):
			(ligado[0] as Signal).disconnect(ligado[1])
	# UMA FALA ABERTA NÃO SOBREVIVE AO VALE (#21). O `Dialogo` é autoload e fica;
	# quem sai no meio dela — a volta ao menu, um portão que troca de cena — não
	# deixa a árvore parada nem a caixa esperando um E que ninguém vai dar. Os
	# sinais saem antes, para o calar não chamar de volta um vale de saída.
	if Dialogo.abriu.is_connected(_ao_abrir_a_fala):
		Dialogo.abriu.disconnect(_ao_abrir_a_fala)
	if Dialogo.terminou.is_connected(_ao_calar_a_fala):
		Dialogo.terminou.disconnect(_ao_calar_a_fala)
	if Dialogo.linha_mudou.is_connected(_ao_mudar_a_linha_da_fala):
		Dialogo.linha_mudou.disconnect(_ao_mudar_a_linha_da_fala)
	Dialogo.calar()
	if _fala_parou_o_vale:
		_fala_parou_o_vale = false
		get_tree().paused = false
		_telas_que_param = 0
		Dia.soltar(MOTIVO_DA_TELA)
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
## O PASSO DA CHEGADA NUMA PARTIDA SALVA. O save novo guarda o id do passo
## (`passo`), e a partida volta a ele mesmo que a lista mude. O save de antes
## da chegada nova (Builds #7 e #8, publicadas) só tem o índice na lista velha
## de nove passos: quem tinha acabado a chegada continua acabado, e quem estava
## no meio volta ao passo novo que faz o mesmo papel.
const CHEGADA_ANTIGA := ["pier", "praca", "casa_pasto", "capela", "rocado", "machado", "lenha", "picareta", "enxada"]
const CHEGADA_ANTIGA_PARA_NOVA := {
	"pier": "bom_dia", "praca": "chave", "casa_pasto": "chave", "capela": "chave",
	"rocado": "chave", "machado": "lenha", "lenha": "lenha", "picareta": "pedra_do_poco",
	"enxada": "roca",
}

func _passo_da_chegada_salvo(guia: Dictionary) -> int:
	var indice := int(guia.get("missao", -1))
	var id := str(guia.get("passo", ""))
	if id == "" and not guia.has("passo"):
		if indice >= CHEGADA_ANTIGA.size():
			return pedro.MISSOES.size()
		if indice >= 0:
			id = str(CHEGADA_ANTIGA_PARA_NOVA.get(CHEGADA_ANTIGA[indice], ""))
	if id != "" and pedro.ir_ao_passo(id):
		return pedro.missao
	return indice


## UM ACONTECIMENTO DO VALE, avisado a TODAS as cadeias — as dos moradores e a
## da chegada, que é do Pedro e não mora em `_cadeias`. Quem ainda não chegou
## no passo guarda para depois: quem já cozinhou não aprende de novo.
func _avisar_as_cadeias(evento: String) -> void:
	for qual in _cadeias:
		_cadeias[qual].registrar_evento(evento)
	if pedro != null:
		pedro.registrar_evento(evento)


func _ao_cozinhar(id: String, _quantos: int) -> void:
	_avisar_as_cadeias("cozinhou:" + id)
	# CADA PRATO GASTA O FOGO (07/10).
	fogo_da_fogueira = maxi(0, fogo_da_fogueira - 1)


## A LENHA DA FOGUEIRA (playtest de 07/10: "para cozinhar na fogueira, considere
## exigir recarregar ela com madeira a cada X comidas cozinhadas"). A fogueira do
## terreiro guarda fogo para alguns pratos; cada prato cozido gasta um, e uma lenha
## posta nela — o E na fogueira com a lenha na mão (`tecla_das_bancadas`) — devolve
## PRATOS_POR_LENHA, até o teto. Começa com fogo para três: o Pedro a acendeu na
## chegada, e a primeira janta não pede lenha a mais. Vai no save ("fogueira").
const PRATOS_POR_LENHA := 3
const FOGO_MAXIMO := 9
var fogo_da_fogueira := PRATOS_POR_LENHA


func fogueira_acesa() -> bool:
	return fogo_da_fogueira > 0


func pratos_no_fogo() -> int:
	return fogo_da_fogueira


## Põe uma lenha na fogueira. Devolve se pôs: sem lenha na mochila, ou com o fogo no
## teto, não põe (e o HUD diz por quê).
func alimentar_a_fogueira() -> bool:
	if fogo_da_fogueira > FOGO_MAXIMO - PRATOS_POR_LENHA:
		if hud != null:
			hud.set_notice(texto_da_fogueira("cheia") % fogo_da_fogueira)
		return false
	if not Inventario.consumir("lenha", 1):
		if hud != null:
			hud.set_notice(texto_da_fogueira("sem_lenha"))
		return false
	fogo_da_fogueira += PRATOS_POR_LENHA
	Audio.efeito("pegar")
	if hud != null:
		hud.set_notice(texto_da_fogueira("pos") % fogo_da_fogueira)
	return true


## Os recados da fogueira (data/fogueira.json), no idioma do menu: texto de jogador
## não mora em constante (AGENTS.md). A dica do E e a aba do fogão leem daqui também.
const TEXTOS_DA_FOGUEIRA := "res://data/fogueira.json"
var _textos_da_fogueira: Dictionary = {}


func texto_da_fogueira(chave: String) -> String:
	if _textos_da_fogueira.is_empty():
		var lido = JSON.parse_string(FileAccess.get_file_as_string(TEXTOS_DA_FOGUEIRA))
		_textos_da_fogueira = lido if lido is Dictionary else {"vazio": true}
	return str(IdiomaMenu.campo(_textos_da_fogueira.get(chave, {}), "texto", chave))


func _ao_comer(id: String) -> void:
	_avisar_as_cadeias("comeu:" + id)


func _ao_fabricar(id: String, _quantos: int) -> void:
	_avisar_as_cadeias("fabricou:" + id)


## A NOITE VIROU: pela cama é "dormiu"; pelo desmaio não é sono, é queda.
func _ao_deitar(motivo: String) -> void:
	if motivo == "cama":
		_avisar_as_cadeias("dormiu")


## LER UM PAPEL (F em cima dele, na mochila): a caixa de fala mostra as linhas
## do `data/documentos.json` na língua do jogador, e as cadeias ficam sabendo
## ("leu:convite" fecha a chegada). Papel sem texto ainda avisa: ler é o gesto.
const DOCUMENTOS := "res://data/documentos.json"

func _ler_documento(id: String) -> void:
	var dados = JSON.parse_string(FileAccess.get_file_as_string(DOCUMENTOS))
	var papel: Dictionary = dados.get(id, {}) if dados is Dictionary and dados.get(id) is Dictionary else {}
	var linhas = IdiomaMenu.campo(papel, "linhas", [])
	if linhas is Array and not (linhas as Array).is_empty():
		await Dialogo.falar(str(IdiomaMenu.campo(papel, "nome", Catalogo.nome(id))), linhas)
	_avisar_as_cadeias("leu:" + id)


## O passo em curso da missão acompanhada (o dicionário do passo, com a `meta`), ou {}: é o que as dicas dos
## moradores leem para saber o que o jogador está tentando fazer.
func _passo_da_acompanhada() -> Dictionary:
	var id := str(CadernoDoVale.atual().get("id", ""))
	if id == "":
		return {}
	var cadeias: Array = _cadeias.values()
	if pedro != null and pedro.get("_cadeia") != null:
		cadeias.append(pedro.get("_cadeia"))
	for cadeia in cadeias:
		var passo: Dictionary = cadeia.passo_atual()
		if not passo.is_empty() and str(cadeia._id_no_caderno(passo)) == id:
			return passo
	return {}


## QUEM É O MORADOR DE TAL ID, respondido por esta casa, que é a que tem a lista.
## A meta "levar" precisa disso para achar quem recebe; o mutirão, para chamar
## quem ajuda; e a chegada do Pedro, para o bom-dia ao Tonho.
func _achar_morador(quem: String) -> Node3D:
	for outro in moradores:
		if String(outro.dados.get("id", "")) == quem:
			return outro
	if pedro != null and quem == "pedro":
		return pedro
	return null


## AS CENAS ESCRITAS À MÃO, por nome: as da chapada, da fazenda e do revoar. O que não está
## aqui é cena dos dados (`CenaVale`, data/cenas.json) — o portão `cenas_do_vale` confere que
## toda cena pedida por um passo está num lugar ou no outro.
const CENAS_ESCRITAS_A_MAO := ["luz_dourada", "cabra_desce", "portao_se_abre", "chegou_ao_patio",
	"chamado_aos_corajosos", "porta_estreita", "o_quarto", "a_fuga", "o_relato", "a_fera_vem",
	"a_pedra", "o_amanhecer"]


## AS CENAS DOS PASSOS (`cena` no dado da missão, `CadeiaDeMissoes.cena`): a luz
## dourada da chegada à chapada, a cabra que desce da lombada, o portão da fazenda,
## o pé da escadaria, o chamado aos corajosos e a porta estreita (#114).
func _tocar_a_cena(nome: String, cadeia: Node = null) -> void:
	match nome:
		"luz_dourada":
			if luz_dourada != null:
				luz_dourada.tocar()
		"cabra_desce":
			if lombada != null:
				lombada.a_cabra_desce()
		"portao_se_abre":
			if fazenda != null:
				fazenda.o_portao_se_abre()
		"chegou_ao_patio":
			if fazenda != null:
				fazenda.chegou_ao_patio()
		"chamado_aos_corajosos":
			if fazenda != null:
				fazenda.o_chamado_aos_corajosos()
		"porta_estreita":
			if fazenda != null:
				fazenda.a_porta_estreita()
		# O capítulo 7 (`revoar_vale.gd`, #31).
		"o_quarto":
			if revoar != null:
				revoar.o_quarto()
		"a_fuga":
			if revoar != null:
				revoar.a_fuga()
		"o_relato":
			if revoar != null:
				revoar.o_relato()
		"a_fera_vem":
			if revoar != null:
				revoar.a_fera_vem()
		"a_pedra":
			if revoar != null:
				revoar.a_pedra()
		"o_amanhecer":
			if revoar != null:
				revoar.o_amanhecer()
		_:
			# As cenas dos dados (cena_vale.gd): a fila que pediu fica segura até o `anuncia`.
			if cenas != null:
				cenas.tocar(nome, cadeia)


func _pendurar_cadeia(morador: Node3D, arquivo: String, perto: float, chave: String = "") -> Node:
	var cadeia := CadeiaDeMissoes.new()
	cadeia.name = "CadeiaDeMissoes" if chave == "" else "CadeiaDeMissoes_" + chave
	cadeia.dono = morador
	cadeia.jogador = player
	cadeia.recursos = _recursos
	cadeia.comeca_perto_de = perto
	cadeia.achar_morador = _achar_morador
	if not cadeia.carregar(arquivo):
		cadeia.free()
		return null
	cadeia.missao_mudou.connect(func(t: String, a: Vector3, i: int, n: int) -> void:
		missao_do_vale_mudou.emit(t, a, i, n))
	# A RECOMPENSA DO PASSO (#48) é dita no HUD, como no 2D.
	cadeia.pagou.connect(func(texto: String) -> void: hud.set_notice(texto))
	# A RESPOSTA DA OFERENDA é narração, e não fala do dono (que está longe): só o aviso.
	cadeia.narrou.connect(func(texto: String) -> void: hud.set_notice(texto))
	# A TAREFA CUMPRIDA no meio da missão: o quadro pulsa, o risco desce, o sinete soa.
	cadeia.passo_cumprido.connect(hud.tarefa_concluida)
	# A FERRAMENTA ENTREGUE fica na barra, e o HUD diz o número que a põe na mão.
	cadeia.entregou.connect(func(texto: String) -> void: hud.set_notice(texto))
	cadeia.cena.connect(_tocar_a_cena.bind(cadeia))
	morador.add_child(cadeia)
	_cadeias[chave if chave != "" else str(morador.dados.get("id", ""))] = cadeia
	return cadeia


## A tabela dos favores dos moradores: dono, arquivo, chave, o grau de afinidade que abre
## e a fila que tem de ter acabado antes (ver o arquivo).
const FAVORES_DOS_MORADORES := "res://data/favores_dos_moradores.json"
## A partir de quantos pontos de afinidade o morador avisa que o favor espera conhecer melhor
## ("passe aqui mais vezes"): meio caminho até "Conhecido de vista" — umas conversas ou um
## presente. Antes disso ele só conversa; o aviso sai uma vez (`aviso_repete`).
const AFINIDADE_PARA_O_AVISO := 5


func _pendurar_as_secundarias(moradores: Array, depois_da_chegada: Callable) -> void:
	var tabela: Dictionary = Jogo.dados(FAVORES_DOS_MORADORES)
	for entrada in tabela.get("filas", []):
		var dono_id := str(entrada.get("dono", ""))
		var morador: Node3D = null
		for candidato in moradores:
			if String(candidato.dados.get("id", "")) == dono_id:
				morador = candidato
				break
		if morador == null:
			continue
		var chave := str(entrada.get("chave", dono_id + "_favor"))
		var fila = _pendurar_cadeia(morador, str(entrada.get("arquivo", "")), 4.0, chave)
		if fila == null:
			continue
		var grau := int(entrada.get("grau", 1))
		var depois := str(entrada.get("depois", ""))
		fila.aviso_repete = false
		fila.avisa_a_trancada = func() -> bool: return Afinidade.de(dono_id) >= AFINIDADE_PARA_O_AVISO
		fila.depois_de = func() -> bool:
			if not bool(depois_da_chegada.call()):
				return false
			if Afinidade.grau(dono_id) < grau:
				return false
			if depois != "":
				var anterior = _cadeias.get(depois)
				return anterior != null and bool(anterior.acabou())
			return true
