extends "res://tests/suite/caso.gd"
var falhas := 0
func _initialize() -> void: _run.call_deferred()
func conferir(ok: bool, texto: String) -> void:
 if not ok:
  falhas += 1
  print("FALHA: " + texto)
func _run() -> void:
 var hud = load("res://scripts/prototipo_3d/prototype_hud.gd").new()
 root.add_child(hud)
 for tamanho in [Vector2i(800,600), Vector2i(1280,720), Vector2i(1920,1080)]:
  root.size = tamanho
  await process_frame
  hud.set_notice("")
  var longo := "Pedro: Chegamos. Daqui da cerca para dentro é seu. A chave tá com você: abre a porta e entra. Eu fico aqui fora, que dentro é seu. "
  hud.set_notice(longo + longo)
  if "--falsificar" in OS.get_cmdline_user_args():
   hud._notice_label.autowrap_mode = TextServer.AUTOWRAP_OFF
  for _i in 4: await process_frame
  var texto: Label = hud._notice_label
  var fundo: Control = hud._notice_panel
  conferir(texto.get_line_count() >= 2, "fala longa quebra em linhas")
  conferir(texto.size.y >= texto.get_minimum_size().y, "todas as linhas cabem")
  conferir(fundo.get_global_rect().encloses(texto.get_global_rect()), "fundo acompanha altura do texto")
  conferir(fundo.get_global_rect().position.x >= 0 and fundo.get_global_rect().end.x <= hud._root.get_viewport_rect().size.x, "aviso cabe na tela")
  if "--capturar" in OS.get_cmdline_user_args():
   await process_frame
   await RenderingServer.frame_post_draw
   DirAccess.make_dir_recursive_absolute("res://scratch/avisos-em-linhas")
   root.get_texture().get_image().save_png("res://scratch/avisos-em-linhas/%d.png" % tamanho.x)
 print("AVISOS_EM_LINHAS: %d falha(s)" % falhas)
 quit(1 if falhas else 0)
