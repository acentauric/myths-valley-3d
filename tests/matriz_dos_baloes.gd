extends SceneTree
## #121/#124/#127/#132: controles reais, nomes em tela e obstáculos físicos reais.
const Popups = preload("res://scripts/prototipo_3d/popups_do_mundo.gd")

class Jogador extends Node3D:
	var camera: Camera3D
class Morador extends CharacterBody3D:
	var dados := {"nome": "Pessoa", "id": ""}
	var altura := 1.75
	var nome_label := Label3D.new()
	var fala := false
	var conversas := 0
	func _ready() -> void:
		add_child(nome_label)
		add_to_group("moradores")
	func falando_agora() -> bool:
		return fala
	func conversar() -> void:
		conversas += 1
class Hud extends RefCounted:
	var camada: Control
	func map_layer() -> Control:
		return camada

var falhas := 0
func _initialize() -> void:
	_run.call_deferred()
func conferir(ok: bool, motivo: String) -> void:
	if not ok:
		falhas += 1
		push_error("MATRIZ_BALOES_FALHOU: " + motivo)
func esperar(segundos: float = 0.55) -> void:
	await create_timer(segundos).timeout
func _run() -> void:
	load("res://scripts/prototipo_3d/atalhos.gd").aplicar()
	for acao in ["interagir", "cancelar"]:
		if not InputMap.has_action(acao):
			InputMap.add_action(acao)
	root.size = Vector2i(1280, 720)
	var mundo := Node3D.new()
	root.add_child(mundo)
	var jogador := Jogador.new()
	mundo.add_child(jogador)
	jogador.set_physics_process(true)
	jogador.position = Vector3(0, 0, 1.8)
	var camera := Camera3D.new()
	mundo.add_child(camera)
	camera.position = Vector3(0, 3, 8)
	camera.look_at(Vector3(0, 1, 0))
	camera.current = true
	jogador.camera = camera
	var pessoa := Morador.new()
	pessoa.dados.nome = "Pedro"
	mundo.add_child(pessoa)
	var vizinha := Morador.new()
	vizinha.dados.nome = "Dona Candinha"
	mundo.add_child(vizinha)
	vizinha.position.x = 4.5
	var camada := Control.new()
	root.add_child(camada)
	var hud := Hud.new()
	hud.camada = camada
	var origem := "res://scripts/prototipo_3d/"
	if "--antes" in OS.get_cmdline_user_args():
		origem = "res://tools/temp/matriz-antes/"
	var placas = load(origem + "placas_nomes.gd").new()
	root.add_child(placas)
	placas.configurar(jogador, camada)
	var teclas = load(origem + "tecla_dos_moradores.gd").new()
	root.add_child(teclas)
	teclas.configurar(jogador, hud, func() -> Array: return [pessoa, vizinha], func() -> bool: return true)
	await esperar()
	conferir(teclas._dica.visible, "conversa disponível oferece E")
	conferir(placas._placas[pessoa].visible, "a dica do E diz só 'Conversar' (#188): o nome de Pedro fica na placa")
	conferir(placas._placas[vizinha].visible, "nome útil de outra pessoa permanece")
	pessoa.fala = true
	await esperar()
	conferir(not teclas._dica.visible and teclas.perto() == null, "fala de Pedro não oferece nova conversa")
	teclas.usar(pessoa)
	conferir(pessoa.conversas == 0, "atalho automático não reinicia conversa durante fala")
	pessoa.fala = false
	await esperar()
	conferir(teclas._dica.visible, "E volta ao terminar fala, ainda ao alcance")
	# A caixa real avança pelo próprio E mesmo com uma fala ambiente ativa.
	var dialogo = root.get_node("Dialogo")
	dialogo.falar("Pedro", ["Página um", "Página dois"])
	await esperar(0.7)
	var pagina: int = dialogo._indice
	Input.action_press("interagir")
	dialogo._process(0.0)
	await process_frame
	await process_frame
	Input.action_release("interagir")
	await process_frame
	conferir(dialogo._indice > pagina or not dialogo.ativo, "E de continuar Dialogo permanece independente")
	dialogo._fechar()
	# Tire a dica de conversa e coloque a árvore apenas ao lado da placa do Pedro.
	teclas.set_process(false)
	teclas._dica.hide()
	await esperar()
	conferir(placas._placas[pessoa].visible, "nome volta sem dica correspondente")
	var arvore := Control.new()
	camada.add_child(arvore)
	arvore.add_to_group(Popups.GRUPO_DICAS)
	arvore.set_meta("interacao_arvore", true)
	arvore.size = Vector2(140, 36)
	arvore.position = placas._placas[pessoa].get_global_rect().position
	await esperar()
	conferir(not placas._placas[pessoa].visible, "árvore suprime nome concorrente")
	conferir(placas._placas[vizinha].visible, "árvore mantém nome fora da região")
	arvore.hide()
	await esperar()
	conferir(placas._placas[pessoa].visible, "nome retorna depois da interação da árvore")
	# Histerese espacial: quem já estava visível aguenta a folga menor.
	var tipos = load("res://scripts/prototipo_3d/placas_nomes.gd")
	var caixas: Array[Rect2] = [Rect2(100, 100, 100, 30)]
	conferir(not tipos._concorre_com_arvore(Rect2(216, 100, 40, 20), caixas, true)
		and tipos._concorre_com_arvore(Rect2(216, 100, 40, 20), caixas, false), "folgas distintas evitam piscar na borda")
	var parede := StaticBody3D.new()
	mundo.add_child(parede)
	parede.position = Vector3(0, 1.5, 4)
	parede.collision_layer = 1 | (1 << 13)
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(2, 4, 0.3)
	forma.shape = caixa
	parede.add_child(forma)
	await esperar(0.8)
	conferir(not placas._placas[pessoa].visible, "pessoa imóvel atrás da parede não tem nome")
	conferir(placas._placas[vizinha].visible, "parede local não oculta vizinha visível")
	parede.add_to_group("folhagem")
	await esperar(0.8)
	conferir(placas._placas[pessoa].visible, "volume amplo de folhagem não vira parede opaca")
	parede.remove_from_group("folhagem")
	# Só cobre os pés: cabeça/torso visíveis preservam a identificação.
	caixa.size.y = 0.3
	parede.position.y = 0.1
	await esperar(0.8)
	conferir(placas._placas[pessoa].visible, "oclusão parcial não apaga pessoa visível")
	caixa.size.y = 4
	parede.position.y = 1.5
	await esperar(0.8)
	for modo in 3:
		camera.position = Vector3(5 + modo, 3 + modo, 7)
		camera.look_at(Vector3(0, 1, 0))
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL if modo == 1 else Camera3D.PROJECTION_PERSPECTIVE
		camera.size = 12
		await esperar(0.8)
		conferir(placas._placas[pessoa].visible, "câmera mudou: placa recupera visão no modo %d" % modo)
	placas.queue_free()
	teclas.queue_free()
	mundo.queue_free()
	camada.queue_free()
	await process_frame
	await process_frame
	print("MATRIZ_BALOES: %d falha(s)" % falhas)
	quit(1 if falhas else 0)
