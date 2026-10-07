extends SceneTree
## #133/#157: avisos expiram sem evento seguinte; falas mantêm sua vez e limpam.

class Balao extends Control:
	var texto := ""
	func mostrar(valor: String) -> void:
		texto = valor
		show()
	func esconder() -> void:
		texto = ""
		hide()

var falhas := 0

func _initialize() -> void:
	_run.call_deferred()

func _conferir(ok: bool, descricao: String) -> void:
	if not ok:
		falhas += 1
		push_error("AVISOS_COM_PRAZO_FALHOU: " + descricao)

func _run() -> void:
	var hud = load("res://scripts/prototipo_3d/prototype_hud.gd").new()
	root.add_child(hud)
	hud.set_notice("Recebido de Dona Zefa: 1 cocada", 0.2)
	if "--falsificar-prazo" in OS.get_cmdline_user_args():
		hud._notice_expiry.kill()
	_conferir(hud._notice_panel.visible, "aviso de recebimento aparece")
	await create_timer(0.3).timeout
	_conferir(hud._notice.is_empty() and not hud._notice_panel.visible, "recebimento some sem outro evento")
	hud.set_notice("Recebido: 1 pedra", 0.2)
	await create_timer(0.1).timeout
	hud.set_notice("Recebido: 1 madeira", 0.4)
	await create_timer(0.2).timeout
	_conferir(hud._notice == "Recebido: 1 madeira", "prazo antigo não apaga aviso mais recente")
	# Uma fonte repetitiva não mantém o mesmo aviso eternamente.
	hud.set_notice("Recebido: 1 madeira", 20.0)
	await create_timer(0.3).timeout
	_conferir(hud._notice.is_empty(), "mesmo texto não reinicia prazo")
	hud.set_notice("Aviso pausado", 0.2)
	paused = true
	await create_timer(0.3).timeout
	_conferir(hud._notice == "Aviso pausado", "pausa preserva tempo de leitura")
	paused = false
	await create_timer(0.3).timeout
	_conferir(hud._notice.is_empty(), "aviso expira depois de retomar")
	var fila = load("res://scripts/prototipo_3d/fila_de_falas.gd").new()
	root.add_child(fila)
	# Carrega depois dos autoloads. Só a montagem do modelo/mundo é substituída;
	# narrar, fila, início e encerramento continuam sendo os métodos reais.
	var script := GDScript.new()
	script.source_code = "extends 'res://scripts/prototipo_3d/guia_pedro.gd'\nfunc _ready(): pass\nfunc _process(_delta): pass\nfunc _physics_process(_delta): pass\n"
	_conferir(script.reload() == OK, "dublê de montagem compila")
	var pedro = script.new()
	pedro.balao = Balao.new()
	pedro.nome_label = Label3D.new()
	pedro.voz = AudioStreamPlayer3D.new()
	pedro.add_child(pedro.balao)
	pedro.add_child(pedro.nome_label)
	pedro.add_child(pedro.voz)
	pedro.add_child(pedro._cadeia)
	root.add_child(pedro)
	pedro.narrar("", "Chegamos. Daqui da cerca pra dentro é seu.", {"origem": "chegada_casa"})
	await process_frame
	_conferir(pedro.falando_agora() and pedro.balao.visible, "fala da chegada aparece pela fila real")
	_conferir(pedro._balao_tempo >= 2.5, "correção não encurta tempo da narração")
	await create_timer(3.3).timeout
	_conferir(not pedro.falando_agora() and not pedro.balao.visible, "balão da chegada termina sem novo evento")
	_conferir(pedro.nome_label.visible, "nome volta ao terminar a fala")
	hud.set_notice("Aviso ao sair da cena", 0.1)
	hud.queue_free()
	pedro.queue_free()
	fila.queue_free()
	await create_timer(0.2).timeout
	print("AVISOS_COM_PRAZO: ", falhas, " falhas")
	quit(0 if falhas == 0 else 1)
