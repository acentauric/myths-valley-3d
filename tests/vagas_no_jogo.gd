extends "res://tests/suite/caso.gd"
const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")
## Duas vagas reais no perfil isolado do runner: cancelar não grava;
## confirmar guarda a origem, recarrega o vale e preserva o destino.
var falhas := 0
func _initialize() -> void:
	_run.call_deferred()
func conferir(ok: bool, texto: String) -> void:
	if not ok:
		falhas += 1
		push_error(texto)
func pronto() -> bool:
	for i in range(6000):
		if current_scene != null and current_scene.get("carga_ok") == true:
			return true
		await process_frame
	return false
func _run() -> void:
	var partida := root.get_node("Partida")
	var saves := root.get_node("Salvamento")
	var jogo := root.get_node("Jogo")
	var textos: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/vagas_no_jogo.json"))
	for chave in textos:
		for idioma in range(3):
			var campo: String = "texto" + ["", "_en", "_es"][idioma]
			conferir(not str(textos[chave].get(campo, "")).is_empty(), "texto de vaga nos três idiomas: " + chave)
			conferir(IdiomaMenu.campo_no_idioma(textos[chave], "texto", idioma) == textos[chave][campo], "seleção da tradução de vaga")
	if "--sem-confirmacao" in OS.get_cmdline_user_args():
		# Falsificação isolada da pergunta: a primeira tecla emite a troca.
		var fonte := FileAccess.get_file_as_string("res://scripts/prototipo_3d/painel_vale.gd")
		fonte = fonte.replace("\r\n", "\n")
		var comeco := fonte.find("func _confirmar_vaga()")
		var fim := fonte.find("\n\n\n", comeco)
		var bloco := fonte.substr(comeco, fim - comeco).replace("if _confirmando != _cursor:", "if false:")
		fonte = fonte.substr(0, comeco) + bloco + fonte.substr(fim)
		var arquivo := FileAccess.open("user://painel_sem_confirmacao.gd", FileAccess.WRITE)
		arquivo.store_string(fonte)
		arquivo.close()
		partida.comecar(1)
		var mutante = load("user://painel_sem_confirmacao.gd").new()
		root.add_child(mutante)
		var pedidos: Array[String] = []
		mutante.pediu.connect(func(acao): pedidos.append(acao))
		mutante.abrir(mutante.Aba.AJUSTES)
		mutante.fazer_a_acao({"acao": "vagas"})
		mutante.escolher(1)
		mutante._confirmar()
		conferir(pedidos.is_empty(), "primeiro E somente pergunta")
		print("VAGAS_NO_JOGO_MUTANTE: %d falha(s)" % falhas)
		quit(1 if falhas else 0)
		return
	for slot in [1, 2]:
		partida.comecar(slot, true)
		jogo.dinheiro = slot * 111
		conferir(partida.salvar(), "fixture salva vaga %d" % slot)
	var destino := FileAccess.get_file_as_bytes(saves.arquivo(2))
	partida.comecar(1)
	conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "abre vale")
	if not await pronto():
		conferir(false, "vale pronto no prazo")
		quit(1)
		return
	var vale := current_scene
	conferir(jogo.dinheiro == 111, "retoma origem")
	jogo.dinheiro = 999
	var painel = vale.painel
	vale.abrir_o_painel(painel.Aba.AJUSTES)
	conferir(painel.fazer_a_acao({"acao": "vagas"}), "ação explícita abre vagas")
	conferir(painel._aba == painel.Aba.VAGAS, "lista própria de vagas")
	painel.escolher(1)
	painel._confirmar()
	conferir(saves.slot_atual == 1 and current_scene == vale, "primeiro E somente pergunta")
	conferir(saves.ler(1).Jogo.dinheiro == 111, "pergunta não grava origem")
	vale.telas.fechar_tudo()
	conferir(jogo.dinheiro == 999 and saves.slot_atual == 1, "cancelamento mantém partida")
	vale.abrir_o_painel(painel.Aba.AJUSTES)
	painel.fazer_a_acao({"acao": "vagas"})
	painel.escolher(0)
	painel._confirmar()
	conferir(saves.slot_atual == 1, "vaga atual não reinicia")
	painel.escolher(1)
	painel._confirmar()
	painel._confirmar()
	await process_frame
	await process_frame
	if not await pronto():
		conferir(false, "nova instância pronta no prazo")
	else:
		conferir(current_scene != vale and current_scene.scene_file_path.ends_with("vale.tscn"), "troca sem menu inicial")
		conferir(saves.slot_atual == 2 and jogo.dinheiro == 222, "retoma destino sem estado da origem")
		conferir(saves.ler(1).Jogo.dinheiro == 999, "salva origem antes da troca")
		conferir(FileAccess.get_file_as_bytes(saves.arquivo(2)) == destino, "arquivo destino preservado")
	paused = false
	print("VAGAS_NO_JOGO: %d falha(s)" % falhas)
	quit(1 if falhas else 0)
