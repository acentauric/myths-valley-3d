extends "res://tests/suite/caso.gd"
## O GOLPE TEM REAÇÃO VISUAL: LASCAS DO MATERIAL E UM TRANCO NA TELA (#16).
##
##     .\tools\prototipo_3d\testar.ps1 -Teste reacoes_visuais
##
## O `Efeitos` do 2D fazia a partícula e a sacudida de tela; no 3D elas moram em `ReacoesVisuais`
## e saem do impacto de `recursos_3d._aplicar_golpe`.
##
##   1. O MATERIAL SEGUE A FERRAMENTA: picareta é pedra, machado é madeira, foice é folha, a ostra é
##      concha, a lenha é madeira, e a mão é poeira.
##   2. AS LASCAS SAEM: uma rajada única de partículas na cor do material, o último golpe com mais, e o
##      emissor some sozinho no fim do tempo de vida.
##   3. A TELA DÁ UM TRANCO e volta ao zero; uma sacudida nova não soma com a anterior.
##   4. O MOVIMENTO REDUZIDO (`Jogo.movimento_reduzido`) calma a tela: sem sacudida, e menos lascas.
##   5. NO VALE, O GOLPE QUE ACERTA solta as lascas e sacode a câmera do jogador; o último, com mais força.
##
## FALSIFICAÇÃO: tire o `_reagir_ao_golpe` de `_aplicar_golpe` e a 5 reprova; faça `sacudir_tela` ignorar
## o movimento reduzido e a 4 reprova; esqueça o `_encerrar_sacudida` e a câmera fica torta (a 3 reprova).

## Recebe o vale montado do zero: reprovava no vale deixado pelos casos anteriores (a suíte, #242).
const VALE_NOVO := true

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("REACOES_VISUAIS_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	var jogo = root.get_node("/root/Jogo")
	var reduzido_antes: bool = jogo.movimento_reduzido
	jogo.movimento_reduzido = false

	# --- 1. O MATERIAL ------------------------------------------------------------
	var casos := {
		"picareta": "pedra", "machado": "madeira", "foice": "folha", "": "poeira",
	}
	for ferramenta in casos:
		_conferir(ReacoesVisuais.material_do_golpe({"ferramenta": ferramenta, "rende": "qualquer"}) == casos[ferramenta],
			"a ferramenta '%s' deu o material '%s', e era '%s'" % [ferramenta, ReacoesVisuais.material_do_golpe({"ferramenta": ferramenta, "rende": "qualquer"}), casos[ferramenta]])
	_conferir(ReacoesVisuais.material_do_golpe({"ferramenta": "", "rende": "ostra"}) == "concha", "a ostra não deu concha")
	_conferir(ReacoesVisuais.material_do_golpe({"ferramenta": "", "rende": "lenha"}) == "madeira", "a lenha não deu madeira")

	# --- 2. AS LASCAS ---------------------------------------------------------------
	var palco := Node3D.new()
	root.add_child(palco)
	var camera := Camera3D.new()
	palco.add_child(camera)
	camera.current = true
	await process_frame
	var comum := ReacoesVisuais.lascas(palco, Vector3(1, 2, 3), "pedra", false)
	var ultimo := ReacoesVisuais.lascas(palco, Vector3(1, 2, 3), "pedra", true)
	_conferir(comum != null and ultimo != null, "as lascas não nasceram")
	if comum != null and ultimo != null:
		_conferir(comum.one_shot and comum.emitting, "as lascas não são uma rajada única emitindo")
		_conferir(ultimo.amount > comum.amount, "o último golpe não solta mais lascas que o comum (%d, %d)" % [ultimo.amount, comum.amount])
		_conferir(comum.global_position.is_equal_approx(Vector3(1, 2, 3)), "as lascas não nasceram no ponto do golpe")
		var cubo := comum.mesh as BoxMesh
		var cor: Color = (cubo.material as StandardMaterial3D).albedo_color
		_conferir(cor.is_equal_approx(ReacoesVisuais.CORES["pedra"]), "as lascas de pedra não têm a cor da pedra")
	_conferir(ReacoesVisuais.lascas(null, Vector3.ZERO, "pedra") == null, "lascas sem pai devem devolver null")

	# --- 3. A TELA ------------------------------------------------------------------
	_conferir(ReacoesVisuais.sacudir_tela(camera, 0.05, 0.2), "a sacudida não começou")
	var anterior = camera.get_meta(ReacoesVisuais.META_DA_SACUDIDA, null)
	await process_frame
	await process_frame
	await _esperar(0.05)
	_conferir(absf(camera.h_offset) > 0.0 or absf(camera.v_offset) > 0.0, "a tela não se mexeu durante a sacudida")
	_conferir(ReacoesVisuais.sacudir_tela(camera, 0.05, 0.2), "a segunda sacudida não começou")
	_conferir(anterior is Tween and not (anterior as Tween).is_valid(), "a sacudida nova não trocou a anterior")
	await _esperar(0.45)
	_conferir(camera.h_offset == 0.0 and camera.v_offset == 0.0, "a câmera não voltou a zero (%f, %f)" % [camera.h_offset, camera.v_offset])
	_conferir(not camera.has_meta(ReacoesVisuais.META_DA_SACUDIDA), "a sacudida deixou o registro para trás")
	await _esperar(ReacoesVisuais.VIDA + 0.2)
	_conferir(not is_instance_valid(comum), "as lascas não se livraram sozinhas")

	# --- 4. O MOVIMENTO REDUZIDO -------------------------------------------------------
	var cheias := ReacoesVisuais.quantas_lascas(false)
	jogo.movimento_reduzido = true
	_conferir(not ReacoesVisuais.sacudir_tela(camera, 0.05, 0.2), "o movimento reduzido ainda sacode a tela")
	_conferir(ReacoesVisuais.quantas_lascas(false) < cheias, "o movimento reduzido não diminuiu as lascas")
	jogo.movimento_reduzido = false
	palco.queue_free()

	# --- 5. NO VALE ------------------------------------------------------------------
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _mundo_pronto()
	await _quadros(8)
	var vale = current_scene
	var recursos = vale.get("_recursos")
	_conferir(recursos != null, "o vale não tem os alvos de trabalho")
	if recursos != null:
		var alvos: Dictionary = recursos.get("_alvos")
		_conferir(alvos.has("lapa_da_lombada"), "a lapa da lombada não está nos alvos")
		if alvos.has("lapa_da_lombada"):
			var cam: Camera3D = vale.player.camera
			recursos._aplicar_golpe("lapa_da_lombada")
			_conferir(recursos.get_node_or_null("LascasDoGolpe") != null, "o golpe na lapa não soltou lascas")
			_conferir(cam.has_meta(ReacoesVisuais.META_DA_SACUDIDA), "o golpe na lapa não sacudiu a câmera")
			await _esperar(0.5)
			_conferir(cam.h_offset == 0.0 and cam.v_offset == 0.0, "a câmera do jogador não voltou a zero")
	jogo.movimento_reduzido = reduzido_antes
	print("")
	if falhas == 0:
		print("REACOES_VISUAIS_OK: o golpe solta lascas do material e dá um tranco na tela, que volta a zero e se cala com o movimento reduzido")
	else:
		print("reacoes_visuais: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


func _esperar(segundos: float) -> void:
	var limite := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < limite:
		await process_frame


func _mundo_pronto() -> void:
	for i in 3000:
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
