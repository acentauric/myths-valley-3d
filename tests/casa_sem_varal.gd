extends SceneTree
## A variante de composição da casa herdada não estende roupas (#158).
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	await process_frame
	var cena: Node = load("res://scenes/prototipo_3d/composicao_vale.tscn").instantiate()
	var varal: Node3D = cena.get_node("Casas/Casa de taipa/Varal")
	if "--varal-na-casa" in OS.get_cmdline_user_args():
		varal.visible = true
	var falhas := 0
	if varal.visible:
		falhas += 1
		print("FALHA: roupas estendidas na casa recém-aberta")
	var pecas = load("res://scripts/prototipo_3d/pecas_construcoes.gd")
	for item in pecas.POR_CASA["Casa de taipa"]:
		if str(item.chave).begins_with("varal"):
			falhas += 1
			print("FALHA: a composição padrão repõe o varal")
	var outros := 0
	for peca in cena.find_children("*", "Node3D", true, false):
		if peca != varal and peca.get("chave") != null and str(peca.get("chave")).begins_with("varal") and peca.visible:
			outros += 1
	if outros == 0:
		falhas += 1
		print("FALHA: varais das outras casas foram removidos")
	cena.free()
	print("CASA_SEM_VARAL: %d falhas, %d outros varais preservados" % [falhas, outros])
	quit(0 if falhas == 0 else 1)
