extends SceneTree
## ESCREVE A CENA DO PAISAGISMO (scenes/prototipo_3d/paisagismo_vale.tscn) a partir
## das zonas iniciais de data/paisagismo/zonas_iniciais.json, uma vez.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/mapas/planejar_paisagismo.gd
##
## Depois disso A CENA É A FONTE: o dono abre `paisagismo_vale.tscn` no editor e
## puxa os pontos de cada zona (Zonas/<nome>, um Path3D fechado) ou muda a
## receita, a semente e o rumo no inspetor. Este script RECUSA sobrescrever a cena
## — regerá-la apagaria o que foi editado. Para recomeçar, apague a cena de
## propósito e rode de novo.

const ZONAS := "res://data/paisagismo/zonas_iniciais.json"
const CENA := "res://scenes/prototipo_3d/paisagismo_vale.tscn"
const ZonaDeFlora := preload("res://scripts/prototipo_3d/zona_de_flora.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(CENA):
		push_error("A cena do paisagismo já existe e é a fonte das zonas: %s. Apague-a de propósito para recomeçar." % CENA)
		print("RECUSADO: a cena já existe; nada foi escrito.")
		quit(1)
		return
	var arquivo := FileAccess.open(ZONAS, FileAccess.READ)
	if arquivo == null:
		push_error("Sem as zonas iniciais: " + ZONAS)
		quit(1)
		return
	var dados: Dictionary = JSON.parse_string(arquivo.get_as_text())
	var raiz := Node3D.new()
	raiz.name = "PaisagismoVale"
	var zonas := Node3D.new()
	zonas.name = "Zonas"
	raiz.add_child(zonas)
	zonas.owner = raiz
	for zona: Dictionary in dados["zonas"]:
		var no := ZonaDeFlora.new()
		no.name = String(zona["nome"])
		no.receita = String(zona["receita"])
		no.semente = int(zona["semente"])
		no.rumo_graus = float(zona["rumo_graus"])
		var curva := Curve3D.new()
		var poligono: Array = zona["poligono"]
		for ponto: Array in poligono:
			curva.add_point(Vector3(float(ponto[0]), 0.0, float(ponto[1])))
		# Fechado: o último ponto volta ao primeiro.
		curva.add_point(Vector3(float(poligono[0][0]), 0.0, float(poligono[0][1])))
		no.curve = curva
		zonas.add_child(no)
		no.owner = raiz
	var cena := PackedScene.new()
	cena.pack(raiz)
	var erro := ResourceSaver.save(cena, CENA)
	print("PAISAGISMO_PLANEJADO: %d zonas -> %s (erro %d)" % [dados["zonas"].size(), CENA, erro])
	raiz.free()
	quit(0 if erro == OK else 1)
