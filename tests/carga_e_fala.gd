extends SceneTree
## #137: a fila não inicia voz durante montagem nem durante o fade da carga.
class CenaEmCarga extends Node:
	signal carga_concluida
	var carga_ok := false
var falhas := 0
var entrou := false
func _initialize() -> void:
	_run.call_deferred()
func conferir(ok: bool, motivo: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA: " + motivo)
func _run() -> void:
	await process_frame
	var cena := CenaEmCarga.new()
	root.add_child(cena)
	current_scene = cena
	var fila = load("res://scripts/prototipo_3d/fila_de_falas.gd").new()
	cena.add_child(fila)
	var falante := Node.new()
	cena.add_child(falante)
	fila.pedir({"falante": falante, "texto": "A fala de chegada",
		"comecar": func(_fala): entrou = true})
	await create_timer(0.2).timeout
	conferir(not entrou, "fala começou antes de a cena ficar pronta")
	var transicao := Control.new()
	cena.add_child(transicao)
	transicao.add_to_group("telas_de_carregamento")
	cena.carga_ok = true
	transicao.modulate.a = 0.01
	await create_timer(0.2).timeout
	conferir(not entrou, "fala começou enquanto a transição ainda estava na tela")
	transicao.queue_free()
	await create_timer(0.3).timeout
	conferir(entrou, "fim da carga não liberou a fala")
	cena.queue_free()
	await process_frame
	print("CARGA_E_FALA: %d falha(s)" % falhas)
	quit(1 if falhas else 0)
