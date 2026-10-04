extends SceneTree
## PROMOVE AS CAPAS DOS CORDÉIS geradas (`gerar-capas-cordeis.ps1`) para o jogo:
## de `.assets-raw/cordeis/<id>.png` (1024x1536, uns 4 MB cada) para
## `assets/prototipo_3d/cordeis/<id>.jpg` em 768x1152 — o bastante até em tela 4K,
## onde o folheto mostra a capa em 768x1152 —, com qualidade 88.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/openai/promover_capas.gd
##
## Só promove o que já foi conferido: apague de `.assets-raw/cordeis/` a capa que
## não presta antes de rodar.

const DE := "res://.assets-raw/cordeis/"
const PARA := "res://assets/prototipo_3d/cordeis/"
const TAMANHO := Vector2i(768, 1152)
const QUALIDADE := 0.88


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PARA))
	var pasta := DirAccess.open(DE)
	if pasta == null:
		print("não achei ", DE)
		quit(1)
		return
	var feitas := 0
	for arquivo in pasta.get_files():
		if not arquivo.ends_with(".png"):
			continue
		var imagem := Image.load_from_file(ProjectSettings.globalize_path(DE + arquivo))
		if imagem == null or imagem.is_empty():
			print("não abriu: ", arquivo)
			continue
		imagem.convert(Image.FORMAT_RGB8)
		imagem.resize(TAMANHO.x, TAMANHO.y, Image.INTERPOLATE_LANCZOS)
		var destino := ProjectSettings.globalize_path(PARA + arquivo.get_basename() + ".jpg")
		if imagem.save_jpg(destino, QUALIDADE) == OK:
			feitas += 1
			print("promovida: ", arquivo.get_basename())
	print("%d capa(s) promovida(s) para %s" % [feitas, PARA])
	quit(0)
