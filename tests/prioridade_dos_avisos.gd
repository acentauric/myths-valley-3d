extends SceneTree
## #132: disputa real dos retângulos do HUD com fala e interação, sem cenário.
const Popups = preload("res://scripts/prototipo_3d/popups_do_mundo.gd")
class Fala extends Control:
	func retangulo() -> Rect2:
		return get_global_rect() if visible else Rect2()
var falhas := 0
func _initialize() -> void:
	_run.call_deferred()
func conferir(ok: bool, motivo: String) -> void:
	if not ok:
		falhas += 1
		push_error("PRIORIDADE_AVISOS_FALHOU: " + motivo)
func _run() -> void:
	await process_frame
	var hud = load("res://scripts/prototipo_3d/prototype_hud.gd").new()
	root.add_child(hud)
	await process_frame
	hud.set_aviso_de_espera("Volte para perto do guia.")
	hud.set_notice("Recebido: 1 peixe", 20.0)
	await process_frame
	var fala := Fala.new()
	root.add_child(fala)
	fala.add_to_group(Popups.GRUPO_BALOES)
	fala.position = hud._espera_panel.get_global_rect().position
	fala.size = hud._espera_panel.size
	hud._sincronizar_prioridade_dos_avisos()
	conferir(not hud._espera_panel.visible, "aviso cobre fala")
	conferir(hud._notice_panel.visible, "aviso distante foi escondido sem motivo")
	var obstaculos := Popups.paineis_do_hud(root.get_visible_rect().size, hud, Popups.PRIORIDADE_FALA)
	conferir(not obstaculos.has(hud._espera_panel.get_global_rect()), "aviso inferior continua expulsando fala")
	fala.visible = false
	hud._sincronizar_prioridade_dos_avisos()
	conferir(hud._espera_panel.visible, "aviso contextual não voltou ao liberar espaço")
	var dica := Control.new()
	root.add_child(dica)
	dica.add_to_group(Popups.GRUPO_DICAS)
	dica.position = hud._notice_panel.get_global_rect().position
	dica.size = hud._notice_panel.size
	hud._sincronizar_prioridade_dos_avisos()
	conferir(not hud._notice_panel.visible and not hud._notice_label.visible, "resultado cobre interação")
	hud.set_notice("")
	dica.visible = false
	hud._sincronizar_prioridade_dos_avisos()
	conferir(not hud._notice_panel.visible, "aviso expirado reapareceu")
	hud.set_map_open(true)
	hud._sincronizar_prioridade_dos_avisos()
	conferir(not hud._espera_panel.visible, "prioridade reacende aviso sobre mapa")
	hud.set_map_open(false)
	hud._sincronizar_prioridade_dos_avisos()
	conferir(hud._espera_panel.visible, "fechar mapa não devolve aviso vigente")
	fala.queue_free()
	dica.queue_free()
	hud.queue_free()
	await process_frame
	print("PRIORIDADE_AVISOS: %d falha(s)" % falhas)
	quit(1 if falhas else 0)
