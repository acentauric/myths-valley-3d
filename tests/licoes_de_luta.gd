extends SceneTree
## As filas reais ensinam os quatro golpes e recebem os sinais de combate (#53).
var falhas := 0
func _initialize() -> void:
	_run.call_deferred()
func conferir(ok: bool, texto: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA: " + texto)
func _run() -> void:
	change_scene_to_file("res://scenes/prototipo_3d/vale.tscn")
	await process_frame
	while get_first_node_in_group("mundo") == null or not get_first_node_in_group("mundo").construido:
		await process_frame
	for i in range(8):
		await process_frame
	var vale = current_scene
	for fila in get_nodes_in_group("cadeias_de_missoes"):
		fila.set_physics_process(false)
	var luta = root.get_node("Luta")
	var fe = root.get_node("Fe")
	var armas = vale._cadeias["pedro_armas"]
	var capoeira = vale._cadeias["cosme_capoeira"]
	conferir(armas.dono == vale.pedro, "Pedro é quem ensina armas")
	conferir(str(capoeira.dono.dados.id) == "cosme", "Cosme é quem ensina capoeira")
	conferir(not armas.depois_de.call(), "armas esperam a chegada")
	vale.pedro.missao = vale.pedro.MISSOES.size()
	vale.pedro._cadeia.despedida_feita = true
	conferir(armas.depois_de.call(), "armas abrem depois da chegada")
	fe.ativa = "catolicismo"
	conferir(not capoeira.depois_de.call() and not capoeira.so_enquanto.call(), "capoeira não abre em outra fé")
	fe.ativa = "candomble"
	conferir(not capoeira.depois_de.call(), "capoeira espera a mesa da folha")
	var mesa = vale._cadeias["fe_candomble"]
	mesa.missao = mesa.passos.size()
	conferir(capoeira.depois_de.call() and capoeira.so_enquanto.call(), "mesa cumprida libera capoeira")
	luta.aprendidos.clear()
	var ensinados: Array = []
	for fila in [armas, capoeira]:
		fila.iniciado = true
		for i in range(fila.passos.size()):
			var passo: Dictionary = fila.passos[i]
			var golpe := str(passo.get("ensina", ""))
			if golpe.is_empty():
				continue
			conferir(not luta.sabe(golpe), "%s ainda não foi ensinado" % golpe)
			fila.missao = i
			if "--sem-licao" in OS.get_cmdline_user_args():
				passo.erase("ensina")
			fila.anunciar()
			conferir(luta.sabe(golpe), "o anúncio ensina %s" % golpe)
			ensinados.append(golpe)
			var meta: Dictionary = passo.meta
			conferir(fila.falta_a_meta(passo), "a lição espera praticar %s" % golpe)
			for n in range(int(meta.quantos)):
				match str(meta.evento):
					"esquivou": luta.esquivou.emit("caititu")
					"tonteou": luta.acertou.emit("rasteira", "caititu", false, true)
					_: luta.acertou.emit(golpe, "caititu", false, false)
			conferir(not fila.falta_a_meta(passo), "sinal de combate cumpre a prática de %s" % golpe)
	conferir(ensinados == ["golpe_forte", "ginga", "meia_lua", "rasteira"], "as quatro lições existem")
	var metas = vale._cadeias["pedro_metas"]
	metas.iniciado = false
	# Eventos pelo sinal de Luta, sem escrever a conta nem chamar registrar_evento.
	for i in range(int(vale._caititus_da_meta) - 1):
		luta.acertou.emit("golpe", "caititu", true, false)
	vale._conferir_as_metas()
	conferir(not metas.iniciado, "a recompensa espera a conta inteira de caititus")
	luta.acertou.emit("golpe", "caititu", true, false)
	vale._conferir_as_metas()
	conferir(metas.iniciado and str(metas.passo_atual().id) == "meta_caititu", "a conta de caititus abre a meta do Pedro")
	fe.ativa = "catolicismo"
	conferir(not capoeira.so_enquanto.call(), "trocar de fé suspende a fila")
	print("LICOES_DE_LUTA: %d falhas" % falhas)
	quit(0 if falhas == 0 else 1)
