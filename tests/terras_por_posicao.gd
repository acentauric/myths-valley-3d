extends SceneTree
## #9: preço histórico, confirmação nativa, posse/save e contorno no mapa real.
class Morador extends Node3D:
	var dados := {"id": "zefa", "nome": "Dona Zefa"}
	var resposta := ""
	func mostrar_balao(texto: String, _prazo: float) -> void:
		resposta = texto
	func conversar() -> void:
		pass
class Mundo extends Node3D:
	var ancoras := {"Lavoura": Vector3(0, 2, 0), "LavouraFrente": Vector3.RIGHT,
		"Casa da Zefa": Vector3(20, 3, 0), "Chapada": Vector3(50, 7, 0)}
	var landmarks: Array = []
	var areas: Array = []
	func get_map_frame() -> Rect2:
		return Rect2(-100, -100, 200, 200)
	func has_map_frame() -> bool:
		return true
	func get_meters_per_unit() -> float:
		return 1.0
var falhas := 0
func _initialize() -> void:
	_run.call_deferred()
func conferir(ok: bool, texto: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA: ", texto)
func responder(sim: bool) -> void:
	for _i in 4:
		await process_frame
	Input.action_press("mover_esquerda" if sim else "mover_direita")
	await process_frame
	Input.action_release("mover_esquerda" if sim else "mover_direita")
	Input.action_press("interagir")
	await process_frame
	Input.action_release("interagir")
	for _i in 4:
		await process_frame
func _run() -> void:
	var terras = root.get_node("Terras")
	if "--falsificar-favor" in OS.get_cmdline_user_args():
		var mutante := GDScript.new()
		mutante.source_code = FileAccess.get_file_as_string("res://scripts/autoload/terras.gd").replace('Talentos.bonus("favor_mais_barato")', "0.0")
		conferir(mutante.reload() == OK, "mutante de favor não compilou")
		terras.set_script(mutante)
	var jogo = root.get_node("Jogo")
	var talentos = root.get_node("Talentos")
	var missoes = root.get_node("Missoes")
	var inventario = root.get_node("Inventario")
	var salvamento = root.get_node("Salvamento")
	root.get_node("Relogio").pausado = true
	root.get_node("Fe").ativa = ""
	terras.posses = {"rocado": true}
	talentos.destravados.clear()
	jogo.dinheiro = 5000
	conferir(terras.preco("terreno_zefa") == 1800 and terras.preco("terreno_benedito") == 2600, "preços históricos mudaram")
	conferir(not terras.comprar("terreno_benedito") and jogo.dinheiro == 5000, "Benedito foi comprado sem divisa com Zefa")
	conferir(not terras.comprar("inexistente"), "comprou terra inexistente")
	missoes.cumpridas.clear()
	conferir(terras.oferta("zefa") == "", "vendeu antes de conhecer a chapada")
	missoes.cumpridas.append("chapada_volta")
	talentos.destravados.append("gente_fina")
	if "--sem-favor" in OS.get_cmdline_user_args():
		talentos.destravados.clear()
	conferir(terras.preco("terreno_zefa") == 900, "Gente fina não reduz preço da terra pela metade")
	jogo.dinheiro = 899
	conferir(not terras.comprar("terreno_zefa") and jogo.dinheiro == 899, "falta de dinheiro comprou terra")
	jogo.dinheiro = 5000
	load("res://scripts/prototipo_3d/atalhos.gd").aplicar()
	for acao in ["mover_esquerda", "mover_direita", "cancelar", "interagir"]:
		if not InputMap.has_action(acao):
			InputMap.add_action(acao)
	var morador := Morador.new()
	root.add_child(morador)
	var tecla = load("res://scripts/prototipo_3d/tecla_dos_moradores.gd").new()
	root.add_child(tecla)
	tecla.set_process(false)
	tecla._dica = PanelContainer.new()
	tecla.add_child(tecla._dica)
	inventario.espacos.fill({})
	inventario.selecionar(inventario.MAO_LIVRE)
	tecla.usar(morador)
	conferir(root.get_node("Dialogo").ativo, "E não abriu confirmação de compra")
	await responder(false)
	conferir(not terras.meu("terreno_zefa") and jogo.dinheiro == 5000, "Não consumiu dinheiro ou posse")
	tecla.usar(morador)
	await responder(true)
	conferir(terras.meu("terreno_zefa") and jogo.dinheiro == 4100, "Sim não compra uma vez pelo preço apresentado")
	var saldo: int = jogo.dinheiro
	conferir(not terras.comprar("terreno_zefa") and jogo.dinheiro == saldo, "compra repetida gastou de novo")
	conferir(terras.pode_comprar("terreno_benedito"), "Zefa não libera divisa de Benedito")
	conferir(salvamento.salvar(3), "save de posse falhou")
	var gravado: Dictionary = salvamento.ler(3)
	conferir(bool(gravado.get("Terras", {}).get("posses", {}).get("terreno_zefa", false)), "posse não entrou no save real")
	terras.posses.clear()
	conferir(salvamento.carregar(gravado) and terras.meu("terreno_zefa"), "posse não voltou do save")
	var mundo := Mundo.new()
	root.add_child(mundo)
	var ui := Control.new()
	root.add_child(ui)
	var mapa = load("res://scripts/prototipo_3d/mapa_jogo.gd").new()
	root.add_child(mapa)
	mapa.abrir(mundo, morador, ui)
	for _i in 4:
		await process_frame
	conferir(mapa._marcadores_raiz.get_child(0).get_script().resource_path.ends_with("divisas_no_mapa.gd"), "mapa não recebeu divisas reais")
	var pontos: PackedVector3Array = terras.poligono("rocado", mundo)
	conferir(pontos.size() == 4 and is_equal_approx(pontos[0].y, 2.0), "contorno não usa âncora 3D")
	var lavoura = load("res://scripts/prototipo_3d/lavoura_vale.gd")
	conferir(is_equal_approx(pontos[0].distance_to(pontos[1]), lavoura.COLUNAS * lavoura.ESPACO), "contorno não acompanha tamanho da lavoura")
	conferir(is_equal_approx(pontos[1].distance_to(pontos[2]), lavoura.LINHAS * lavoura.ESPACO), "profundidade não acompanha lavoura")
	mapa.fechar()
	root.get_node("Partida").comecar(2)
	conferir(not terras.meu("terreno_zefa") and terras.meu("rocado"), "nova vaga herdou terra comprada")
	conferir(salvamento.carregar(gravado) and terras.meu("terreno_zefa"), "troca de vaga perdeu posse gravada")
	for chave in ["pergunta", "comprou", "sem_divisa", "sem_dinheiro", "sua"]:
		var textos: Dictionary = jogo.dados(terras.ARQUIVO)
		conferir(str(textos.get(chave + "_en", "")) != "" and str(textos.get(chave + "_es", "")) != "", "texto sem idioma: " + chave)
	mapa.queue_free()
	mundo.queue_free()
	ui.queue_free()
	tecla.queue_free()
	morador.queue_free()
	await process_frame
	print("TERRAS_POR_POSICAO: %d falhas" % falhas)
	quit(1 if falhas else 0)
