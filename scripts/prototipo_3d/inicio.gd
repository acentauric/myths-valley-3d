extends Node
## Cena de entrada do jogo: mostra a tela de carregamento (tela_carregamento.gd) logo
## no primeiro quadro, no lugar da tela do Godot, e só então carrega a abertura — que
## monta o vale inteiro como cenário do menu e leva alguns segundos.

const TelaCarregamento = preload("res://scripts/prototipo_3d/tela_carregamento.gd")
const TemaMenu = preload("res://scripts/prototipo_3d/tema_menu.gd")
const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")
const ABERTURA := "res://scenes/prototipo_3d/abertura.tscn"


func _ready() -> void:
	IdiomaMenu.aplicar_menu()
	var camada := CanvasLayer.new()
	add_child(camada)
	var barra := TelaCarregamento.mostrar(camada, TemaMenu.criar(), tr("Carregando o vale…"))
	# Espera o fade da tela (0,2 s) terminar: a montagem do vale trava os quadros.
	await get_tree().create_timer(0.25).timeout
	TelaCarregamento.trocar_cena(get_tree(), ABERTURA, barra)
