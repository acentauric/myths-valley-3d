extends SceneTree
## MEDE O CARREGAMENTO DO VALE: quanto tempo cada etapa da montagem segura, em
## quantos quadros, qual foi o maior congelamento, o que soa enquanto a tela de
## carregamento cobre a cena e o que fica montado no fim.
##
## POR QUE ASSIM. A montagem (world_builder.gd + geo_region_renderer.gd) já avisa
## cada etapa no sinal `progresso(fracao, etapa)` do nó do grupo "mundo", para a
## tela de carregamento escrever o texto. O mesmo sinal vira cronômetro: o tempo
## de uma etapa vai do aviso dela até o aviso da seguinte.
##
## A cena entra como em `TelaCarregamento.trocar_cena` (tela_carregamento.gd:495):
## leitura em segundo plano pelo ResourceLoader, `change_scene_to_packed`, VSync
## desligado e espera do `pronto`. Só muda ONDE o sinal é ligado: lá, dois quadros
## depois da troca, quando as primeiras etapas já passaram; aqui, no `node_added`,
## que chega depois do `_enter_tree` do mundo (que o põe no grupo) e antes do
## `_ready` dele (que começa a montar). Nenhuma etapa escapa.
##
## Não mexe em arquivo do jogo nem grava preferência: o estilo e o mudo valem só
## nesta execução. Sem vaga escolhida o vale não salva (Partida.salvar).
##
## RODAR (sempre com teto; se travar, mate só o PID que você levantou, AGENTS.md):
##   timeout 900 C:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##       --script res://tools/prototipo_3d/medir_carregamento.gd -- --cena=abertura
##   ... -- --cena=abertura,vale   o caminho do jogador: a abertura e depois JOGAR
##   ... -- --so_compilar=1        só confere que este script e os auxiliares compilam
## Com --headless só sai o custo de CPU; sem ele (janela) entram a textura subindo
## para a GPU, o shader compilando no primeiro quadro visível e o desenho da tela.
##
## OPÇÕES (depois do "--"):
##   --cena=abertura|vale|abertura,vale  cenas medidas, em ordem (padrão abertura);
##                                       aceita também o caminho de uma .tscn
##   --estilo=tripo|procedural           força o estilo só nesta execução
##   --tela=0                            sem a tela de carregamento por cima
##   --particulas=0                      a tela sem as bolinhas (A/B do custo delas)
##   --precarregar=1                     lê antes, em threads, todos os GLBs do catálogo
##   --quadros_depois=N                  quadros medidos depois do pronto (30)
##   --teto=S                            segundos até desistir e imprimir o parcial (1500)
##   --mudo=1                            cala o barramento Master (os sons seguem anotados)
##   --saida=arquivo.json                grava o JSON também num arquivo (indentado)
##   --so_compilar=1                     não monta o vale: monta só a tela e sai
##   --soltar_mouse=0                    com janela, deixa o jogador capturar o mouse
##                                       (padrão 1: o vale captura no _ready do jogador,
##                                       player_controller.gd:115, e prenderia o mouse
##                                       de quem está trabalhando ao lado até o fim)
##
## SAÍDA: linhas "MEDICAO: ..." para ler e uma linha "MEDICAO_JSON: {...}" com tudo.
## Em cada medição, `etapas` é a linha do tempo inteira, de t0 até o fim: a soma
## dos `ms` dá o `total_ms`. Etapas entre parênteses não são da montagem: são a
## leitura, a troca de cena, o `_ready` dos outros nós e o que vem depois do pronto.

const CENAS := {
	"abertura": "res://scenes/prototipo_3d/abertura.tscn",
	"vale": "res://scenes/prototipo_3d/vale.tscn",
}
## Carregados com load() depois do primeiro quadro: citam autoloads (AGENTS.md).
const TELA := "res://scripts/prototipo_3d/tela_carregamento.gd"
const TEMA := "res://scripts/prototipo_3d/tema_menu.gd"
const CATALOGO := "res://scripts/prototipo_3d/catalogo_assets.gd"
const PADROES := {
	"cena": "abertura", "estilo": "", "tela": "1", "particulas": "1", "precarregar": "0",
	"quadros_depois": "30", "teto": "1500", "mudo": "0", "saida": "", "so_compilar": "0",
	"soltar_mouse": "1",
}
## Uma etapa escrita pode esconder trabalhos diferentes, e a fração do mundo
## (fração da região × 0,75, world_builder.gd:487) diz qual é qual.
## "Moldando o terreno": a terra com a colisão dela até 0,285
## (geo_region_renderer.gd:219-221) e depois a vila e as áreas do KML (:228-247).
## "Plantando a mata": o sorteio dos pontos até 0,525 (:1372-1406), a malha de cada
## espécie até 0,735 (:1422-1444) e, sem ceder quadro, o sub-bosque, as margens do
## rio e a orla (:1446-1448).
const CORTES := {
	"Moldando o terreno": [[0.0, "terra: malha e colisão"], [0.285, "vila e áreas do KML"]],
	"Plantando a mata": [[0.0, "sorteio dos pontos"], [0.525, "malhas por espécie"], [0.735, "sub-bosque, rio e orla"]],
}
## Acima disto o jogador vê a tela parar: a montagem cede um quadro a cada 80 ms
## (world_builder.gd:525, geo_region_renderer.gd:35).
const QUADRO_LENTO_MS := 250.0
const MAIORES_QUADROS := 10
## Classes contadas no fim, pelo nome exato da classe nativa.
const CLASSES := [
	"MeshInstance3D", "MultiMeshInstance3D", "CollisionShape3D", "StaticBody3D",
	"CharacterBody3D", "RigidBody3D", "Area3D", "OmniLight3D", "SpotLight3D",
	"DirectionalLight3D", "AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D",
	"CPUParticles2D", "CPUParticles3D", "GPUParticles2D", "GPUParticles3D", "Label3D",
	"SubViewport", "Camera3D", "WorldEnvironment", "AnimationPlayer", "Skeleton3D",
	"CanvasLayer", "Timer",
]

var _opcoes := {}
var _resultado := {}
## A cena em medição e a etapa aberta nela (vazios fora de uma medição).
var _medicao := {}
var _etapa := {}
var _caminho := ""
var _t0_us := 0
var _etapa_inicio_us := 0
## Último corte da etapa aberta: o início dela ou a última fronteira de quadro.
var _etapa_desde_us := 0
var _quadro_us := 0
var _quadros := 0
var _lentos := 0
## Desenho de cada quadro cedido (a tela por cima, e o céu atrás dela), lido do
## RenderingServer quadro a quadro. Os monitores TIME_PROCESS e TIME_PHYSICS_PROCESS
## do Performance não servem para somar: guardam o máximo do último segundo.
var _desenho_cpu_ms := 0.0
var _desenho_gpu_ms := 0.0
var _fisica_antes := 0
var _desenhados_antes := 0
var _maiores: Array = []
## A etapa aberta na última fronteira de quadro: onde o quadro seguinte começou.
var _rotulo_do_quadro := ""
var _raiz_nova: Node
var _mundo: Node
var _pronto := false
var _tocadores: Array = []
var _sons_vistos := {}
var _glbs_antes: Array = []
var _camada_tela: CanvasLayer
var _barra: ProgressBar
## O que foi pré-carregado fica seguro aqui: sem referência, o cache do
## ResourceLoader solta o recurso e o CatalogoAssets leria do disco de novo.
var _segurar: Array = []
## Com janela, devolve o mouse a cada quadro (--soltar_mouse, padrão ligado).
var _soltar_mouse := false


func _initialize() -> void:
	# Do começo do motor até aqui: autoloads prontos, antes de qualquer cena.
	_resultado["motor_ate_o_script_ms"] = Time.get_ticks_msec()
	_run.call_deferred()


func _run() -> void:
	_opcoes = _ler_opcoes()
	create_timer(float(_opcoes["teto"])).timeout.connect(_estourou)
	# Os autoloads só respondem depois do primeiro quadro (AGENTS.md).
	await process_frame
	var estilo := root.get_node("/root/Estilo")
	if String(_opcoes["estilo"]) != "":
		# Pelo campo, e não por `definir`, que gravaria a preferência do jogador.
		estilo.set("modo", String(_opcoes["estilo"]))
	if _opcoes["mudo"] == "1":
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	_resultado["opcoes"] = _opcoes
	_resultado["estilo"] = String(estilo.get("modo"))
	_resultado["headless"] = DisplayServer.get_name() == "headless"
	_soltar_mouse = not bool(_resultado["headless"]) and _opcoes["soltar_mouse"] == "1"
	_resultado["godot"] = String(Engine.get_version_info().get("string", ""))
	_resultado["medicoes"] = []
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	_quadro_us = Time.get_ticks_usec()
	# Ligado antes de qualquer `await` do vale: roda primeiro em cada quadro.
	process_frame.connect(_ao_quadro)
	node_added.connect(_ao_entrar_no)
	_tocadores = _achar_tocadores(root)
	if _opcoes["so_compilar"] == "1":
		await _so_compilar()
		return
	if _opcoes["precarregar"] == "1":
		_resultado["precarga"] = await _precarregar_glbs()
	for nome in String(_opcoes["cena"]).split(",", false):
		await _medir(nome.strip_edges())
	_imprimir()
	await _calar()
	quit(0)


func _ler_opcoes() -> Dictionary:
	var opcoes := PADROES.duplicate()
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var par := arg.substr(2).split("=", true, 1)
		if not opcoes.has(par[0]):
			push_warning("MEDICAO: opção desconhecida " + arg)
			continue
		opcoes[par[0]] = par[1] if par.size() > 1 else "1"
	return opcoes


## Confere, sem montar o vale, que este script e os que ele carrega compilam: monta
## a tela de carregamento uma vez e conta o que há nela (as bolinhas aparecem como
## CPUParticles2D).
func _so_compilar() -> void:
	var faltando: Array = []
	for caminho in [TELA, TEMA, CATALOGO, CENAS["abertura"], CENAS["vale"]]:
		if not ResourceLoader.exists(caminho):
			faltando.append(caminho)
	var catalogo = load(CATALOGO)
	_medicao = {"cena": "(so_compilar)"}
	_t0_us = Time.get_ticks_usec()
	_montar_tela("abertura")
	await process_frame
	_resultado["so_compilar"] = {
		"faltando": faltando,
		"pecas_no_catalogo": (catalogo.get("PECAS") as Dictionary).size(),
		"glbs_ja_carregados": _glbs_carregados().size(),
		"tela": _contar(_camada_tela),
	}
	_medicao = {}
	_desmontar_tela()
	_imprimir()
	print("MEDICAO_COMPILOU: %s" % ("ok" if faltando.is_empty() else "faltam arquivos"))
	quit(0 if faltando.is_empty() else 1)


# --- uma cena ---------------------------------------------------------------

func _medir(nome: String) -> void:
	# Além dos dois nomes, aceita o caminho de qualquer cena (uma cena de teste).
	var avulsa := nome.ends_with(".tscn") or nome.ends_with(".scn")
	_caminho = String(CENAS.get(nome, nome if avulsa else ""))
	_medicao = {"cena": nome, "caminho": _caminho, "etapas": [], "sons": []}
	(_resultado["medicoes"] as Array).append(_medicao)
	if _caminho.is_empty() or not ResourceLoader.exists(_caminho):
		_medicao["erro"] = "cena desconhecida: " + nome
		_medicao = {}
		return
	_preparar_relogio(nome)
	_raiz_nova = null
	_mundo = null
	_pronto = false
	_etapa = {}
	_quadros = 0
	_lentos = 0
	_desenho_cpu_ms = 0.0
	_desenho_gpu_ms = 0.0
	_fisica_antes = Engine.get_physics_frames()
	_desenhados_antes = Engine.get_frames_drawn()
	_maiores = []
	# O que já tocava (a música do menu, ao medir o vale depois dela) não conta como
	# som novo desta carga.
	_sons_vistos = {}
	for chave in _tocando():
		_sons_vistos[chave] = true
	_medicao["tocando_no_inicio"] = _sons_vistos.keys()
	_glbs_antes = _glbs_carregados()
	_medicao["tela"] = {"montada": _opcoes["tela"] == "1", "particulas": _opcoes["particulas"] == "1"}
	_t0_us = Time.get_ticks_usec()
	# O primeiro quadro conta a partir daqui, e não da fronteira anterior, que ainda
	# carrega a contagem e a impressão da medição passada.
	_quadro_us = _t0_us
	_rotulo_do_quadro = ""
	if _opcoes["tela"] == "1":
		# O jogo monta a tela antes de pedir a cena (inicio.gd:17, abertura.gd:1412).
		_abrir_etapa("(monta a tela de carregamento)")
		_montar_tela(nome)
	# 1. Leitura em segundo plano, como trocar_cena (tela_carregamento.gd:496-505).
	_abrir_etapa("(leitura em segundo plano)")
	var inicio_da_leitura := Time.get_ticks_usec()
	ResourceLoader.load_threaded_request(_caminho)
	var estado := ResourceLoader.load_threaded_get_status(_caminho)
	while estado == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await process_frame
		estado = ResourceLoader.load_threaded_get_status(_caminho)
	var cena := ResourceLoader.load_threaded_get(_caminho) as PackedScene
	_medicao["leitura_ms"] = _ms(Time.get_ticks_usec() - inicio_da_leitura)
	if cena == null:
		_medicao["erro"] = "a leitura falhou (estado %d)" % estado
		_encerrar_medicao()
		return
	# 2. A troca: instanciar é síncrono; a cena entra na árvore no fim do quadro,
	# depois de a anterior ser liberada (no caminho abertura,vale, o vale do menu).
	var vsync := DisplayServer.window_get_vsync_mode()
	_abrir_etapa("(instanciar a cena)")
	change_scene_to_packed(cena)
	_abrir_etapa("(troca de cena: libera a anterior e espera o fim do quadro)")
	# Sem VSync durante a montagem, como trocar_cena (tela_carregamento.gd:529-530).
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var espera := 0
	while _mundo == null and espera < 600:
		espera += 1
		await process_frame
	if _mundo == null:
		_medicao["erro"] = "a cena não tem nó no grupo \"mundo\""
	else:
		# 3. A montagem: os avisos chegam por _ao_progresso; o fim, por _ao_pronto.
		while not _pronto and is_instance_valid(_mundo):
			await process_frame
	DisplayServer.window_set_vsync_mode(vsync)
	# 4. Os primeiros quadros com o vale à vista: textura e shader de quem estava
	# escondido durante a montagem (world_builder.gd:471) entram aqui.
	for i in range(maxi(int(_opcoes["quadros_depois"]), 1)):
		await process_frame
	_encerrar_medicao()


## O relógio como o jogo o deixa: o menu abre no começo do dia e o põe para andar
## durante toda a montagem (abertura.gd:107-109); a entrada no vale o congela na
## hora inicial até o pronto (abertura.gd:1413-1416, prototype.gd:172).
func _preparar_relogio(nome: String) -> void:
	if nome != "vale":
		return
	var dia := root.get_node("/root/Dia")
	root.get_node("/root/Audio").call("parar_narracao")
	dia.set("pausado", false)
	dia.call("definir_hora", float(dia.get("hora_inicial")))
	dia.set("congelado_na_carga", true)


func _encerrar_medicao() -> void:
	var agora := Time.get_ticks_usec()
	if not _etapa.is_empty():
		_fechar_etapa(agora)
	_desmontar_tela()
	var total := _ms(agora - _t0_us)
	_medicao["total_ms"] = total
	_medicao["quadros"] = _quadros
	_medicao["quadros_lentos"] = _lentos
	_medicao["maiores_quadros"] = _maiores
	# O preço de ceder quadros à tela: o desenho de cada um (zero com --headless) e
	# os passos de física que o motor roda para alcançar o relógio depois de um
	# quadro longo (até 8 por quadro).
	_medicao["desenho_cpu_ms"] = snappedf(_desenho_cpu_ms, 0.1)
	_medicao["desenho_gpu_ms"] = snappedf(_desenho_gpu_ms, 0.1)
	_medicao["quadros_desenhados"] = Engine.get_frames_drawn() - _desenhados_antes
	_medicao["passos_de_fisica"] = Engine.get_physics_frames() - _fisica_antes
	_medicao["tocando_no_fim"] = _tocando()
	var raiz: Node = _raiz_nova if is_instance_valid(_raiz_nova) else current_scene
	if raiz != null:
		_medicao["contagem"] = _contar(raiz)
	_medicao["mundo"] = _sobre_o_mundo()
	var glbs := _glbs_carregados()
	var novos: Array = []
	for chave in glbs:
		if not _glbs_antes.has(chave):
			novos.append(chave)
	var catalogo = load(CATALOGO)
	_medicao["glbs"] = {
		"carregados_no_total": glbs.size(),
		"novos_nesta_cena": novos.size(),
		"chaves_novas": novos,
		"faltando": catalogo.get("faltando"),
	}
	_medicao["monitores"] = _monitores()
	_imprimir_resumo(_medicao)
	_medicao = {}
	_etapa = {}


# --- avisos da cena -----------------------------------------------------------

func _ao_entrar_no(no: Node) -> void:
	if _medicao.is_empty() or not _medicao.has("etapas"):
		return
	if not _etapa.is_empty():
		_etapa["nos_criados"] = int(_etapa["nos_criados"]) + 1
	if no is AudioStreamPlayer or no is AudioStreamPlayer2D or no is AudioStreamPlayer3D:
		_tocadores.append(no)
	# A raiz é reconhecida pelo arquivo da cena: a camada da tela, criada por código,
	# também é filha da raiz, mas não tem arquivo.
	if _raiz_nova == null and not _caminho.is_empty() and no != _camada_tela \
			and no.get_parent() == root and no.scene_file_path == _caminho:
		_raiz_nova = no
		_medicao["raiz"] = String(no.name)
		_abrir_etapa("(a cena entra na árvore)")
		# O `ready` da raiz chega depois do de todos os filhos (mundo incluído).
		no.connect("ready", _ao_ready_da_cena, CONNECT_ONE_SHOT)
	elif _mundo == null and _raiz_nova != null and no.is_in_group("mundo") and no.has_signal("progresso"):
		_mundo = no
		# Ligados antes do `_ready` do mundo, estes avisos rodam antes dos do jogo.
		no.connect("progresso", _ao_progresso)
		no.connect("pronto", _ao_pronto, CONNECT_ONE_SHOT)
		_abrir_etapa("(mundo: antes da primeira etapa)")


## O mundo dá a primeira etapa ainda dentro do `_ready` dele; os `_ready` dos
## irmãos e da raiz (o retábulo e a música do menu; o jogador, o HUD e o começo
## do prototype no vale) rodam em seguida, no mesmo quadro. Esse trecho é deles,
## e a etapa recomeça daqui.
func _ao_ready_da_cena() -> void:
	# O jogador acabou de capturar o mouse no _ready dele: devolve já, sem esperar o
	# próximo quadro, que só vem depois da primeira etapa da montagem.
	_devolver_mouse()
	var rotulo := "(_ready da cena: %s)" % String(_medicao.get("raiz", "?"))
	if int(_etapa.get("avisos", 0)) == 0:
		_abrir_etapa(rotulo)
		return
	var aberta := String(_etapa["etapa"])
	var fracao := float(_etapa.get("fracao_final", -1.0))
	_etapa["etapa"] = rotulo
	_etapa["avisos"] = 0
	_etapa.erase("fracao_inicial")
	_etapa.erase("fracao_final")
	_abrir_etapa(aberta, fracao)


func _ao_progresso(fracao: float, texto: String) -> void:
	if texto == "Pronto":
		return
	var rotulo := _rotulo(texto, fracao)
	if String(_etapa.get("etapa", "")) != rotulo:
		_abrir_etapa(rotulo, fracao)
	_etapa["fracao_final"] = snappedf(fracao, 0.001)
	_etapa["avisos"] = int(_etapa.get("avisos", 0)) + 1
	if _barra != null and is_instance_valid(_barra):
		_barra.value = 0.25 + 0.75 * fracao


func _rotulo(texto: String, fracao: float) -> String:
	var rotulo := texto
	for corte: Array in CORTES.get(texto, []):
		if fracao >= float(corte[0]) - 0.0001:
			rotulo = "%s · %s" % [texto, String(corte[1])]
	return rotulo


func _ao_pronto() -> void:
	_pronto = true
	_medicao["ate_o_pronto_ms"] = _ms(Time.get_ticks_usec() - _t0_us)
	# Este aviso roda antes dos do jogo; o resto do `_ready` do vale (moradores, HUD,
	# som, missões: prototype.gd:165-428) roda logo depois, no mesmo quadro, e o
	# adiado só chega quando ele acabou.
	_abrir_etapa("(depois do pronto, no mesmo quadro)")
	_fim_do_quadro_do_pronto.call_deferred()


func _fim_do_quadro_do_pronto() -> void:
	if _medicao.is_empty():
		return
	_abrir_etapa("(primeiros quadros com o vale à vista)")


# --- etapas e quadros ----------------------------------------------------------

func _abrir_etapa(rotulo: String, fracao: float = -1.0) -> void:
	var agora := Time.get_ticks_usec()
	if not _etapa.is_empty():
		# Som que começou durante a etapa que fecha é dela, mesmo sem ter passado
		# quadro (a música do menu nasce no _ready da abertura, abertura.gd:155).
		_ouvir(String(_etapa["etapa"]))
		_fechar_etapa(agora)
	_etapa = {"etapa": rotulo, "inicio_ms": _ms(agora - _t0_us), "quadros": 0,
		"maior_trecho_sem_ceder_ms": 0.0, "nos_criados": 0, "avisos": 0}
	if fracao >= 0.0:
		_etapa["fracao_inicial"] = snappedf(fracao, 0.001)
		_etapa["fracao_final"] = snappedf(fracao, 0.001)
	_etapa_inicio_us = agora
	_etapa_desde_us = agora


func _fechar_etapa(agora: int) -> void:
	_etapa["ms"] = _ms(agora - _etapa_inicio_us)
	_etapa["maior_trecho_sem_ceder_ms"] = maxf(float(_etapa["maior_trecho_sem_ceder_ms"]), _ms(agora - _etapa_desde_us))
	(_medicao["etapas"] as Array).append(_etapa)
	_etapa = {}


func _ao_quadro() -> void:
	var agora := Time.get_ticks_usec()
	var quadro := _ms(agora - _quadro_us)
	_quadro_us = agora
	_devolver_mouse()
	if _medicao.is_empty() or not _medicao.has("etapas"):
		return
	_quadros += 1
	# O RenderingServer fala do último quadro desenhado: somados, cobrem a medição.
	var tela := root.get_viewport_rid()
	_desenho_cpu_ms += RenderingServer.get_frame_setup_time_cpu() + RenderingServer.viewport_get_measured_render_time_cpu(tela)
	_desenho_gpu_ms += RenderingServer.viewport_get_measured_render_time_gpu(tela)
	var rotulo := String(_etapa.get("etapa", ""))
	if quadro >= QUADRO_LENTO_MS:
		_lentos += 1
	_guardar_maior(quadro, _rotulo_do_quadro, rotulo, _ms(agora - _t0_us))
	_rotulo_do_quadro = rotulo
	if not _etapa.is_empty():
		_etapa["quadros"] = int(_etapa["quadros"]) + 1
		_etapa["maior_trecho_sem_ceder_ms"] = maxf(float(_etapa["maior_trecho_sem_ceder_ms"]), _ms(agora - _etapa_desde_us))
		_etapa_desde_us = agora
	_ouvir(rotulo)


## Um quadro longo pode cruzar etapas que avisam sem ceder: guarda onde ele
## começou e onde terminou.
func _guardar_maior(quadro: float, comecou_em: String, terminou_em: String, quando: float) -> void:
	if _maiores.size() >= MAIORES_QUADROS and quadro <= float(_maiores[-1]["ms"]):
		return
	_maiores.append({"ms": quadro, "etapa_no_inicio": comecou_em, "etapa_no_fim": terminou_em, "terminou_em_ms": quando})
	_maiores.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["ms"]) > float(b["ms"]))
	if _maiores.size() > MAIORES_QUADROS:
		_maiores.resize(MAIORES_QUADROS)


func _ms(microssegundos: int) -> float:
	return snappedf(microssegundos / 1000.0, 0.1)


func _devolver_mouse() -> void:
	if _soltar_mouse and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# --- som ---------------------------------------------------------------------

func _achar_tocadores(raiz: Node) -> Array:
	var tocadores: Array = []
	for tipo in ["AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D"]:
		tocadores.append_array(raiz.find_children("*", tipo, true, false))
	return tocadores


func _chave_do_som(tocador: Node) -> String:
	var fluxo: AudioStream = tocador.get("stream")
	if fluxo == null or not bool(tocador.get("playing")):
		return ""
	var arquivo := fluxo.resource_path if not fluxo.resource_path.is_empty() else fluxo.get_class()
	return "%s ← %s" % [String(tocador.get_path()), arquivo]


func _tocando() -> Array:
	var chaves: Array = []
	for tocador in _tocadores:
		if is_instance_valid(tocador):
			var chave := _chave_do_som(tocador)
			if chave != "":
				chaves.append(chave)
	return chaves


## Anota cada som que começa durante a medição, com a hora e a etapa em que começou.
func _ouvir(rotulo: String) -> void:
	if not _medicao.has("sons"):
		return
	for i in range(_tocadores.size() - 1, -1, -1):
		var tocador = _tocadores[i]
		if not is_instance_valid(tocador):
			_tocadores.remove_at(i)
			continue
		var chave := _chave_do_som(tocador)
		if chave == "" or _sons_vistos.has(chave):
			continue
		_sons_vistos[chave] = true
		(_medicao["sons"] as Array).append({"em_ms": _ms(Time.get_ticks_usec() - _t0_us), "etapa": rotulo,
			"som": chave, "volume_db": snappedf(float(tocador.get("volume_db")), 0.1)})


func _calar() -> void:
	# Como os testes: o misturador encerra sem fila de som.
	for tocador in _achar_tocadores(root):
		tocador.call("stop")
	await create_timer(0.2).timeout


# --- tela de carregamento ----------------------------------------------------

func _montar_tela(nome: String) -> void:
	var dia := root.get_node("/root/Dia")
	var tela_script = load(TELA)
	var tema: Theme = load(TEMA).criar()
	# A capa segue a hora em que a cena abre: o começo do dia no menu (inicio.gd:17),
	# a hora inicial escolhida no vale (abertura.gd:1425).
	var hora := float(dia.get("INICIO_DO_DIA")) if nome == "abertura" else float(dia.get("hora_inicial"))
	_camada_tela = CanvasLayer.new()
	_camada_tela.name = "TelaDaMedicao"
	# A camada própria da tela durante a troca (tela_carregamento.gd:507-508).
	_camada_tela.layer = 100
	root.add_child(_camada_tela)
	_barra = tela_script.mostrar(_camada_tela, tema, "Carregando o vale…", hora)
	if _opcoes["particulas"] == "0":
		# Desligadas e escondidas, não liberadas: o `resized` da tela ainda as
		# reposiciona (tela_carregamento.gd:189-193).
		for nuvem in _camada_tela.find_children("*", "CPUParticles2D", true, false):
			nuvem.set("emitting", false)
			nuvem.set("visible", false)
			nuvem.process_mode = Node.PROCESS_MODE_DISABLED


func _desmontar_tela() -> void:
	if _camada_tela != null and is_instance_valid(_camada_tela):
		_camada_tela.queue_free()
	_camada_tela = null
	_barra = null


# --- GLBs ----------------------------------------------------------------------

## Chaves do catálogo cujo GLB o CatalogoAssets já leu (o cache estático `_cenas`,
## catalogo_assets.gd:109, que sobrevive à troca de cena).
func _glbs_carregados() -> Array:
	var catalogo = load(CATALOGO)
	var cenas: Dictionary = catalogo.get("_cenas")
	var chaves: Array = []
	for chave in cenas:
		if cenas[chave] != null:
			chaves.append(String(chave))
	chaves.sort()
	return chaves


## A/B da leitura dos GLBs: hoje cada um é lido no quadro principal, no meio da
## montagem (catalogo_assets.gd:140). Aqui todos são pedidos de uma vez, em
## threads, antes da cena; a montagem que vem depois os acha no cache.
func _precarregar_glbs() -> Dictionary:
	var catalogo = load(CATALOGO)
	var pecas: Dictionary = catalogo.get("PECAS")
	var pasta := String(catalogo.get("PASTA"))
	var inicio := Time.get_ticks_usec()
	var pendentes: Array[String] = []
	for chave in pecas:
		var caminho := pasta + String(pecas[chave]["tripo"])
		if ResourceLoader.exists(caminho) and not pendentes.has(caminho):
			ResourceLoader.load_threaded_request(caminho, "", true)
			pendentes.append(caminho)
	var total := pendentes.size()
	var falhas: Array = []
	var quadros := 0
	while not pendentes.is_empty():
		for i in range(pendentes.size() - 1, -1, -1):
			if ResourceLoader.load_threaded_get_status(pendentes[i]) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				continue
			var recurso := ResourceLoader.load_threaded_get(pendentes[i])
			if recurso == null:
				falhas.append(pendentes[i])
			else:
				_segurar.append(recurso)
			pendentes.remove_at(i)
		if not pendentes.is_empty():
			quadros += 1
			await process_frame
	var resultado := {"glbs": total, "ms": _ms(Time.get_ticks_usec() - inicio), "quadros": quadros, "falhas": falhas}
	print("MEDICAO: pré-carga de %d GLBs em %s ms (%d quadros)" % [total, resultado["ms"], quadros])
	return resultado


# --- o que ficou montado -------------------------------------------------------

func _contar(raiz: Node) -> Dictionary:
	var tipos := {}
	var formas := {}
	var glbs := {}
	var blocos := {}
	var ramos := {}
	var triangulos := {}
	var malhas := {}
	var c := {
		"nos": 0, "controles_de_interface": 0, "triangulos_em_malhas": 0,
		"instancias_multimesh": 0, "triangulos_multimesh_lod0": 0, "faces_trimesh": 0,
		"amostras_heightmap": 0, "colisoes_desligadas": 0, "luzes_com_sombra": 0,
		"npcs": 0, "jogador": 0, "alvos_de_casa": 0, "instancias_de_glb": 0,
	}
	for filho in raiz.get_children():
		ramos[String(filho.name)] = _contar_nos(filho)
	var pilha: Array[Node] = [raiz]
	while not pilha.is_empty():
		var no: Node = pilha.pop_back()
		pilha.append_array(no.get_children())
		c["nos"] += 1
		var classe := no.get_class()
		if classe in CLASSES:
			tipos[classe] = int(tipos.get(classe, 0)) + 1
		if no is Control:
			c["controles_de_interface"] += 1
		if no.is_in_group("moradores"):
			c["npcs"] += 1
		if no.is_in_group("map_player"):
			c["jogador"] += 1
		if no.is_in_group("interactive_house"):
			c["alvos_de_casa"] += 1
		if no is MeshInstance3D:
			var malha: Mesh = (no as MeshInstance3D).mesh
			if malha != null:
				malhas[malha.get_instance_id()] = true
				c["triangulos_em_malhas"] += _triangulos(malha, triangulos)
		elif no is MultiMeshInstance3D:
			var multimesh: MultiMesh = (no as MultiMeshInstance3D).multimesh
			if multimesh != null:
				var n := multimesh.instance_count if multimesh.visible_instance_count < 0 else multimesh.visible_instance_count
				c["instancias_multimesh"] += n
				if multimesh.mesh != null:
					malhas[multimesh.mesh.get_instance_id()] = true
					c["triangulos_multimesh_lod0"] += n * _triangulos(multimesh.mesh, triangulos)
				var grupo := _grupo_do_bloco(String(no.name))
				var bloco: Dictionary = blocos.get(grupo, {"blocos": 0, "instancias": 0})
				bloco["blocos"] = int(bloco["blocos"]) + 1
				bloco["instancias"] = int(bloco["instancias"]) + n
				blocos[grupo] = bloco
		elif no is CollisionShape3D:
			var colisao := no as CollisionShape3D
			if colisao.disabled:
				c["colisoes_desligadas"] += 1
			if colisao.shape != null:
				var forma := colisao.shape.get_class()
				formas[forma] = int(formas.get(forma, 0)) + 1
				if colisao.shape is ConcavePolygonShape3D:
					c["faces_trimesh"] += floori((colisao.shape as ConcavePolygonShape3D).get_faces().size() / 3.0)
				elif colisao.shape is HeightMapShape3D:
					var mapa := colisao.shape as HeightMapShape3D
					c["amostras_heightmap"] += mapa.map_width * mapa.map_depth
		elif no is Light3D and (no as Light3D).shadow_enabled:
			c["luzes_com_sombra"] += 1
		# CatalogoAssets.instanciar põe a meta "limites" e o nome "<Chave>Tripo".
		if no is Node3D and no.has_meta("limites") and String(no.name).contains("Tripo"):
			var chave := _chave_do_glb(String(no.name))
			glbs[chave] = int(glbs.get(chave, 0)) + 1
			c["instancias_de_glb"] += 1
	c["por_classe"] = tipos
	c["formas_de_colisao"] = formas
	c["malhas_distintas"] = malhas.size()
	c["glbs_instanciados"] = glbs
	c["multimesh_por_grupo"] = blocos
	c["nos_por_ramo"] = ramos
	return c


func _contar_nos(no: Node) -> int:
	var total := 0
	var pilha: Array[Node] = [no]
	while not pilha.is_empty():
		var atual: Node = pilha.pop_back()
		total += 1
		pilha.append_array(atual.get_children())
	return total


func _triangulos(malha: Mesh, cache: Dictionary) -> int:
	var id := malha.get_instance_id()
	if cache.has(id):
		return int(cache[id])
	var total := 0
	if malha is ArrayMesh:
		# Só o tamanho dos arrays, sem copiar os vértices (LOD 0).
		var array_mesh := malha as ArrayMesh
		for superficie in array_mesh.get_surface_count():
			var indices := array_mesh.surface_get_array_index_len(superficie)
			total += floori((indices if indices > 0 else array_mesh.surface_get_array_len(superficie)) / 3.0)
	else:
		total = floori(malha.get_faces().size() / 3.0)
	cache[id] = total
	return total


## "Mata: mata_alta 3,-2" e os outros blocos de MultiMesh (geo_region_renderer.gd:1572)
## agrupados pelo nome, sem a coordenada do bloco.
func _grupo_do_bloco(nome: String) -> String:
	var espaco := nome.rfind(" ")
	if espaco > 0 and nome.substr(espaco + 1).contains(","):
		return nome.substr(0, espaco)
	return nome


func _chave_do_glb(nome: String) -> String:
	var limpo := nome.trim_prefix("@")
	var fim := limpo.find("Tripo")
	return limpo.substr(0, fim).strip_edges() if fim > 0 else limpo


func _sobre_o_mundo() -> Dictionary:
	if _mundo == null or not is_instance_valid(_mundo):
		return {}
	var dados := {
		"construido": bool(_mundo.get("construido")),
		"ancoras": (_mundo.get("ancoras") as Dictionary).size(),
		"pontos_de_interesse": (_mundo.get("landmarks") as Array).size(),
		"arvores_nomeadas": (_mundo.get("_arvores_nomeadas") as Array).size(),
		"nos_do_cenario": _contar_nos(_mundo),
	}
	var regiao = _mundo.get("_region")
	if regiao != null and is_instance_valid(regiao):
		dados["troncos_registrados"] = (regiao.get("_tree_trunks") as Array).size()
		dados["blocos_com_lod"] = (regiao.get("_blocos_vegetacao_lod") as Array).size()
		dados["alturas_em_cache"] = (regiao.get("_alturas_vertices") as Dictionary).size()
		dados["nos_da_regiao"] = _contar_nos(regiao)
	return dados


func _monitores() -> Dictionary:
	var mega := 1048576.0
	return {
		"nos": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"objetos": Performance.get_monitor(Performance.OBJECT_COUNT),
		"recursos": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"nos_orfaos": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"memoria_estatica_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / mega, 0.1),
		"video_mb": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / mega, 0.1),
		"texturas_mb": snappedf(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / mega, 0.1),
		"buffers_mb": snappedf(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / mega, 0.1),
		"objetos_no_quadro": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"primitivas_no_quadro": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"chamadas_de_desenho": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"fisica_corpos_ativos": Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),
		"fisica_pares": Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS),
		"fisica_ilhas": Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT),
	}


# --- saída ---------------------------------------------------------------------

func _imprimir_resumo(m: Dictionary) -> void:
	print("MEDICAO: %s · até o pronto %s ms · total %s ms · leitura %s ms · %d quadros (%d acima de %d ms)" % [
		m.get("cena", "?"), m.get("ate_o_pronto_ms", "?"), m.get("total_ms", "?"),
		m.get("leitura_ms", "?"), int(m.get("quadros", 0)), int(m.get("quadros_lentos", 0)), int(QUADRO_LENTO_MS)])
	for etapa: Dictionary in m.get("etapas", []):
		print("MEDICAO:   %9.1f ms · %4d quadros · maior trecho sem ceder %8.1f ms · %6d nós · %s" % [
			float(etapa.get("ms", 0.0)), int(etapa.get("quadros", 0)),
			float(etapa.get("maior_trecho_sem_ceder_ms", 0.0)), int(etapa.get("nos_criados", 0)),
			String(etapa.get("etapa", ""))])
	for som: Dictionary in m.get("sons", []):
		print("MEDICAO:   som aos %s ms, em %s: %s" % [som["em_ms"], som["etapa"], som["som"]])
	if m.has("erro"):
		print("MEDICAO:   ERRO: %s" % m["erro"])


func _imprimir() -> void:
	print("MEDICAO_JSON: " + JSON.stringify(_resultado))
	var saida := String(_opcoes.get("saida", ""))
	if saida.is_empty():
		return
	var arquivo := FileAccess.open(saida, FileAccess.WRITE)
	if arquivo == null:
		push_warning("MEDICAO: não consegui gravar " + saida)
		return
	arquivo.store_string(JSON.stringify(_resultado, "\t") + "\n")
	arquivo.close()


## Teto estourado: imprime o que já mediu, marcado, e sai com 2. Só dispara com
## quadros andando; um laço preso no quadro principal pede o `timeout` de fora.
func _estourou() -> void:
	push_error("MEDICAO: teto de %s s excedido" % String(_opcoes.get("teto", "?")))
	if not _medicao.is_empty():
		_medicao["erro"] = "teto excedido"
		if not _etapa.is_empty() and _medicao.has("etapas"):
			_fechar_etapa(Time.get_ticks_usec())
	_imprimir()
	quit(2)
