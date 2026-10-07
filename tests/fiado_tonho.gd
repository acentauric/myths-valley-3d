extends SceneTree
var falhas := 0
func _initialize() -> void:
	_run.call_deferred()
func conferir(ok: bool, mensagem: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA: ", mensagem)
func _run() -> void:
	await process_frame
	var jogo = root.get_node("Jogo")
	var fiado = load("res://scripts/prototipo_3d/fiado_tonho.gd").new()
	root.add_child(fiado)
	fiado.set_process(false)
	fiado.ultimo_dia = 1
	fiado.abater_dias(10)
	conferir(fiado.divida == 1900, "sem rede, esperar não paga")
	jogo.dinheiro = 240
	conferir(fiado.pagar(900) == 240 and jogo.dinheiro == 0 and fiado.divida == 1660, "pagamento limitado pelo dinheiro")
	conferir(fiado.pagar(-3) == 0 and fiado.divida == 1660, "valor negativo não aumenta dinheiro")
	jogo.dinheiro = 3000
	conferir(fiado.pagar(900) == 500 and jogo.dinheiro == 2500, "máximo por lançamento é 500")
	fiado.rede = true
	fiado.abater_dias(11)
	if "--sem-rede" in OS.get_cmdline_user_args():
		fiado.divida += 130
	conferir(fiado.divida == 1030, "rede abate 130 no dia seguinte")
	fiado.abater_dias(11)
	conferir(fiado.divida == 1030, "mesmo dia não abate duas vezes")
	fiado.lido = true
	var salvo: Dictionary = JSON.parse_string(JSON.stringify(fiado.estado_para_salvar()))
	var retomado = load("res://scripts/prototipo_3d/fiado_tonho.gd").new()
	root.add_child(retomado)
	retomado.set_process(false)
	retomado.restaurar(salvo)
	conferir(retomado.divida == 1030 and retomado.lido and retomado.rede and retomado.ultimo_dia == 11, "saldo/rede/leitura/dia sobrevivem JSON")
	retomado.abater_dias(19)
	conferir(retomado.divida == 0, "rede termina sem saldo negativo")
	retomado.abater_dias(20)
	conferir(retomado.divida == 0 and retomado.pagar(500) == 0, "dívida quitada não cobra")
	retomado.restaurar({"divida": 1900, "rede": true, "ultimo_dia": 1})
	retomado.abater_dias(15)
	conferir(retomado.divida == 80, "quatorze dias ainda deixam 80")
	retomado.abater_dias(16)
	conferir(retomado.divida == 0, "quinze dias de rede quitam 1900")
	var fila = load("res://scripts/prototipo_3d/cadeia_de_missoes.gd").new()
	root.add_child(fila)
	fila.set_process(false)
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/missoes_tonho.json"))
	var livro: Dictionary = dados.passos[3]
	conferir(fila.falta_a_meta(livro), "chegar à venda não quita a dívida")
	fila.registrar_evento("livro_tonho_lido")
	conferir(fila.falta_a_meta(livro), "leitura não anuncia Zerou")
	fila.registrar_evento("divida_tonho_quitada")
	conferir(not fila.falta_a_meta(livro), "leitura e quitação liberam terra")
	fiado.queue_free()
	retomado.queue_free()
	fila.queue_free()
	await process_frame
	print("FIADO: %d falhas" % falhas)
	quit(0 if falhas == 0 else 1)
