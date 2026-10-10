extends "res://tests/suite/caso.gd"
## O CONVITE NO SAVE DA SESSÃO QUE TRAVOU (10/10/2026): a partida salva no último passo da chegada
## ("Leia o convite que chegou", tests/fixtures/saves/convite_preso.save). Carregada a vaga, ler o
## convite tem de fechar o passo. Na sessão, o "leu:convite" chegava à cadeia e o passo não andava.
const ISOLADO := true

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA: ", rotulo)


func _run() -> void:
	DirAccess.copy_absolute(ProjectSettings.globalize_path("res://tests/fixtures/saves/convite_preso.save"), ProjectSettings.globalize_path("user://partida_1.save"))
	root.get_node("/root/Partida").comecar(1)
	change_scene_to_file("res://scenes/prototipo_3d/vale.tscn")
	for i in 3000:
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido and current_scene.get("carga_ok"):
			break
		await process_frame
	for i in 30:
		await process_frame
	var vale := current_scene
	var cadeia = vale.get("pedro")._cadeia
	print("CONVITE_SAVE antes: missao=%d id=%s iniciado=%s espera=%.2f dono=%s jogador=%s fisica=%s pode=%s" % [cadeia.missao, str(cadeia.passo_atual().get("id", "")), str(cadeia.iniciado), cadeia.espera, str(cadeia.dono), str(cadeia.jogador), str(cadeia.is_physics_processing()), str(cadeia.can_process())])
	_conferir(str(cadeia.passo_atual().get("id", "")) == "convite", "a vaga não abriu no passo do convite")
	# Como o jogador e o testador leem: a mochila aberta pelas telas, e o F no convite (`Mochila._ler`).
	var mochila := root.get_node("/root/Mochila")
	vale.telas.abrir("mochila")
	await process_frame
	_conferir(mochila.aberta and arvore.paused, "a mochila não abriu parando o vale")
	mochila._ler("convite")
	var dialogo := root.get_node("/root/Dialogo")
	for i in 120:
		await process_frame
		if dialogo.ativo:
			dialogo.calar()
	for i in 60:
		await process_frame
		if str(cadeia.passo_atual().get("id", "")) != "convite":
			break
	print("CONVITE_SAVE pausa: paused=%s telas_que_param=%d" % [str(arvore.paused), int(vale._telas_que_param)])
	_conferir(not arvore.paused and int(vale._telas_que_param) == 0, "depois de ler o convite pela mochila o vale ficou parado (telas que param: %d)" % int(vale._telas_que_param))
	print("CONVITE_SAVE depois: missao=%d id=%s aconteceu=%s falta=%s espera=%.2f acabou=%s lugar=%s" % [cadeia.missao, str(cadeia.passo_atual().get("id", "")), str(cadeia.aconteceu("leu:convite")), str(cadeia.falta_a_meta(cadeia.passos[15])) if cadeia.passos.size() > 15 else "?", cadeia.espera, str(cadeia.acabou()), str(root.get_node("/root/Lugares").resolve(str(cadeia.passos[15].get("lugar", "")))) if cadeia.passos.size() > 15 else "?"])
	_conferir(str(cadeia.passo_atual().get("id", "")) != "convite", "lido o convite, o passo da chegada não andou")
	print("CONVITE_NO_SAVE_OK" if falhas == 0 else "convite_no_save: Falhas: %d" % falhas)
	quit(1 if falhas else 0)
