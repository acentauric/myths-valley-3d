extends SceneTree
## PROMOVE OS ÍCONES gerados (`gerar-icones.ps1`, #107) para o jogo: de
## `.assets-raw/openai/icones/<id>.png` (1024×1024) para
## `assets/sprites/icones/<id>.png` em 96×96 — o HUD e o J os mostram a 20–32 px,
## e 96 aguenta tela 4K sem borrar.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/openai/promover_icones.gd
##
## O FUNDO SAI POR GEOMETRIA: o modelo pinta um fundo mesmo pedindo transparência,
## e o ícone tem a forma que o prompt pediu — o losango de azulejo do XP, o
## distintivo quadrado arredondado dos réis. A máscara de cada forma (MASCARAS,
## no quadro de 1024) deixa o fundo transparente e as bordas pintadas. Ícone
## novo sem máscara sai inteiro, como veio.
##
## Só promove o que já foi conferido: apague de `.assets-raw/openai/icones/` o
## ícone que não presta antes de rodar.

const DE := "res://.assets-raw/openai/icones/"
const PARA := "res://assets/sprites/icones/"
const LADO := 96
## {id: {"forma": "losango" | "quadrado", "centro", "meio" (metade do lado/diagonal), "raio" (do canto)}}
const MASCARAS := {
	"xp": {"forma": "losango", "centro": Vector2(512, 512), "meio": 430.0},
	"reis": {"forma": "quadrado", "centro": Vector2(512, 512), "meio": 420.0, "raio": 90.0},
}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PARA))
	var pasta := DirAccess.open(DE)
	if pasta == null:
		print("não achei ", DE)
		quit(1)
		return
	var feitos := 0
	for arquivo in pasta.get_files():
		if not arquivo.ends_with(".png"):
			continue
		var imagem := Image.load_from_file(ProjectSettings.globalize_path(DE + arquivo))
		if imagem == null or imagem.is_empty():
			print("não abriu: ", arquivo)
			continue
		imagem.convert(Image.FORMAT_RGBA8)
		var id := arquivo.get_basename()
		if MASCARAS.has(id):
			_recortar(imagem, MASCARAS[id])
		imagem.resize(LADO, LADO, Image.INTERPOLATE_LANCZOS)
		var destino := ProjectSettings.globalize_path(PARA + arquivo)
		if imagem.save_png(destino) == OK:
			feitos += 1
			print("promovido: ", id, " (máscara: ", str(MASCARAS.get(id, {}).get("forma", "nenhuma")), ")")
	print("%d ícone(s) promovido(s) para %s" % [feitos, PARA])
	quit(0)


## Deixa transparente o que está fora da forma, com uma borda suave de 3 px.
func _recortar(imagem: Image, mascara: Dictionary) -> void:
	var centro: Vector2 = mascara["centro"]
	var meio := float(mascara["meio"])
	var forma := str(mascara["forma"])
	var raio := float(mascara.get("raio", 0.0))
	for y in imagem.get_height():
		for x in imagem.get_width():
			var p := Vector2(x + 0.5, y + 0.5) - centro
			var fora := 0.0
			if forma == "losango":
				fora = absf(p.x) + absf(p.y) - meio
			else:
				var q := Vector2(maxf(absf(p.x) - (meio - raio), 0.0), maxf(absf(p.y) - (meio - raio), 0.0))
				fora = q.length() - raio
			if fora > -3.0:
				var cor := imagem.get_pixel(x, y)
				cor.a *= clampf(-fora / 3.0, 0.0, 1.0)
				imagem.set_pixel(x, y, cor)
