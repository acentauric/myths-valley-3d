extends SceneTree
## Os três varais Tripo têm a escala de gente (#194): estacas por volta de 1,9 u
## ao lado do viajante (1,75 u), e não os 3,5 u que a largura da corda dava.
var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, texto: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA: " + texto)


func _run() -> void:
	await process_frame
	for chave in ["varal", "varal_bambu", "varal_estacas"]:
		_conferir(CatalogoAssets.PECAS.has(chave) and CatalogoAssets.tem_tripo(chave), "%s está no catálogo com o GLB" % chave)
		_conferir(CatalogoAssets.PECAS[chave].has("altura"), "%s é medido pela altura, não pela largura da corda" % chave)
		var pai := Node3D.new()
		root.add_child(pai)
		var peca := CatalogoAssets.instanciar(chave, pai, Vector3.ZERO)
		_conferir(peca != null, "%s instancia" % chave)
		if peca != null:
			var caixa: AABB = peca.get_meta("limites")
			_conferir(caixa.size.y >= 1.7 and caixa.size.y <= 2.1, "%s tem %.2f u de altura (esperado 1,7 a 2,1)" % [chave, caixa.size.y])
			_conferir(maxf(caixa.size.x, caixa.size.z) <= 3.2, "%s tem %.2f u de largura (esperado até 3,2)" % [chave, maxf(caixa.size.x, caixa.size.z)])
		pai.free()
	print("VARAIS_EM_ESCALA: %d falhas" % falhas)
	quit(0 if falhas == 0 else 1)
