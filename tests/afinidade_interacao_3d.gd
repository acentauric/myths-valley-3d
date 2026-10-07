extends SceneTree
## #49: usa o controlador real de E, os autoloads e a pergunta real de Sim/Não.
## O morador e a missão são dublês: não exige carregar todo o cenário.

class Morador extends Node3D:
	var dados := {"id": "benedito", "nome": "Seu Benedito"}
	var conversas := 0
	var resposta := ""
	func conversar() -> void:
		conversas += 1
	func mostrar_balao(texto: String, _segundos: float) -> void:
		resposta = texto

class Missao extends Node:
	var chamadas := 0
	func o_que_o_e_faz(_morador: Node3D) -> String:
		return "entregar"
	func interagir(_morador: Node3D) -> bool:
		chamadas += 1
		return true

var falhas := 0
var afinidade
var inventario
var dialogo
var relogio
var tecla
var morador: Morador
var social

func _initialize() -> void:
	_run.call_deferred()

func _conferir(ok: bool, descricao: String) -> void:
	if not ok:
		falhas += 1
		push_error("AFINIDADE_INTERACAO_FALHOU: " + descricao)

func _quadros(n: int = 3) -> void:
	for _i in n:
		await process_frame

func _mao(item: String, qtd: int = 2) -> void:
	inventario.espacos.fill({})
	inventario.espacos[0] = {"id": item, "qtd": qtd}
	inventario.selecionar(0)

func _responder(sim: bool) -> void:
	await _quadros(4)
	Input.action_press("mover_esquerda" if sim else "mover_direita")
	await _quadros(2)
	Input.action_release("mover_esquerda" if sim else "mover_direita")
	Input.action_press("interagir")
	await _quadros(2)
	Input.action_release("interagir")
	await _quadros(3)

func _run() -> void:
	load("res://scripts/prototipo_3d/atalhos.gd").aplicar()
	# No vale, Prototype registra estas ações usadas pelo Dialogo.
	for acao in ["mover_esquerda", "mover_direita", "cancelar", "interagir"]:
		if not InputMap.has_action(acao):
			InputMap.add_action(acao)
	afinidade = root.get_node("Afinidade")
	inventario = root.get_node("Inventario")
	dialogo = root.get_node("Dialogo")
	relogio = root.get_node("Relogio")
	relogio.pausado = true
	afinidade.restaurar({})
	tecla = load("res://scripts/prototipo_3d/tecla_dos_moradores.gd").new()
	root.add_child(tecla)
	tecla.set_process(false)
	tecla._dica = PanelContainer.new()
	tecla.add_child(tecla._dica)
	morador = Morador.new()
	root.add_child(morador)
	social = load("res://scripts/prototipo_3d/teia_social.gd").new()
	root.add_child(social)
	social._quem = "benedito"
	social.abrir()
	await _quadros()

	inventario.selecionar(inventario.MAO_LIVRE)
	tecla.usar(morador)
	await _quadros()
	_conferir(afinidade.de("benedito") == 1, "a conversa pelo E não ganhou um ponto")
	_conferir(not afinidade.pode_conversar("benedito"), "a conversa não marcou o dia")
	_conferir(_texto_social().contains("Já conversaram hoje"), "a tela P aberta não refletiu a conversa")
	tecla.usar(morador)
	_conferir(afinidade.de("benedito") == 1, "E repetido moendo afinidade no mesmo dia")

	_mao("enxada", 1)
	tecla.usar(morador)
	_conferir(not dialogo.ativo and inventario.quantidade("enxada") == 1,
		"a ferramenta de trabalho foi oferecida automaticamente")

	_mao("farinha")
	tecla.usar(morador)
	_conferir(dialogo.ativo, "o item da mão não pediu confirmação")
	if dialogo.ativo:
		_conferir(str(dialogo._texto.text).contains("Farinha") and str(dialogo._texto.text).contains("Seu Benedito"),
			"a pergunta não identifica item e destinatário")
		await _responder(false)
	_conferir(inventario.quantidade("farinha") == 2 and afinidade.pode_presentear("benedito"),
		"Não consumiu o item ou a oportunidade diária")
	_conferir(afinidade.de("benedito") == 1, "recusar presente mudou afinidade")

	tecla.usar(morador)
	if dialogo.ativo:
		await _responder(true)
	_conferir(inventario.quantidade("farinha") == 1 and afinidade.de("benedito") == 9,
		"presente apreciado não consumiu exatamente um item ou não aplicou gosto")
	_conferir(not afinidade.pode_presentear("benedito"), "presente não marcou o dia")
	_conferir(_texto_social().contains("Já ganhou alguma coisa hoje"), "P não refletiu o presente")
	tecla.usar(morador)
	_conferir(not dialogo.ativo and inventario.quantidade("farinha") == 1,
		"presente repetido reabriu confirmação ou consumiu mais um item")

	relogio.dormir()
	await _quadros()
	_mao("cana")
	tecla.usar(morador)
	if dialogo.ativo:
		await _responder(true)
	_conferir(inventario.quantidade("cana") == 1 and afinidade.de("benedito") == 4,
		"presente desgostado não descontou afinidade no novo dia")

	relogio.dormir()
	var missao := Missao.new()
	root.add_child(missao)
	missao.add_to_group("cadeias_de_missoes")
	_mao("farinha")
	tecla.usar(morador)
	_conferir(missao.chamadas == 1 and not dialogo.ativo and inventario.quantidade("farinha") == 2,
		"presente tomou a interação pedida pela missão")
	_conferir(afinidade.de("benedito") == 5, "a conversa da missão não contou no dia")
	missao.queue_free()
	await _quadros()

	# Uma confirmação pendente não pode dar o item de outro espaço após troca.
	tecla.usar(morador)
	if dialogo.ativo:
		inventario.selecionar(inventario.MAO_LIVRE)
		await _responder(true)
	_conferir(inventario.quantidade("farinha") == 2 and afinidade.pode_presentear("benedito"),
		"confirmou um presente que já não estava na mão")

	# No teto/piso, os pontos não emitem mudou; os selos diários ainda precisam atualizar.
	afinidade.restaurar({"pontos": {"benedito": 120}})
	inventario.selecionar(inventario.MAO_LIVRE)
	tecla.usar(morador)
	_conferir(afinidade.de("benedito") == 120 and _texto_social().contains("Já conversaram hoje"),
		"a conversa no teto deixou o selo diário desatualizado")
	_mao("farinha")
	tecla.usar(morador)
	if dialogo.ativo:
		await _responder(true)
	_conferir(afinidade.de("benedito") == 120 and inventario.quantidade("farinha") == 1 \
		and _texto_social().contains("Já ganhou alguma coisa hoje"),
		"o presente no teto não consumiu/marcou o dia na tela P")
	afinidade.restaurar({})
	_mao("cana")
	tecla.usar(morador)
	if dialogo.ativo:
		await _responder(true)
	_conferir(afinidade.de("benedito") == 0 and inventario.quantidade("cana") == 1 \
		and _texto_social().contains("Já ganhou alguma coisa hoje"),
		"o presente ruim no piso não consumiu/marcou o dia na tela P")

	var textos: Dictionary = root.get_node("Jogo").dados("res://data/afinidade_interacao_3d.json")
	for chave in ["pergunta", "bom", "ruim", "qualquer", "ja_deu", "item_mudou"]:
		for sufixo in ["", "_en", "_es"]:
			_conferir(str(textos.get(chave + sufixo, "")).strip_edges() != "", "texto social não traduzido: " + chave + sufixo)

	print("AFINIDADE_INTERACAO: ", falhas, " falha(s)")
	social.fechar()
	root.remove_child(social)
	social.free()
	tecla.queue_free()
	morador.queue_free()
	for tocador in root.get_node("Audio").get_children():
		if tocador is AudioStreamPlayer:
			tocador.stop()
			tocador.stream = null
	await create_timer(0.2).timeout
	await _quadros()
	quit(1 if falhas else 0)

func _texto_social() -> String:
	return _texto_de(social._pagina)

func _texto_de(no: Node) -> String:
	var texto := str(no.text) if no is Label else ""
	for filho in no.get_children():
		texto += "\n" + _texto_de(filho)
	return texto
