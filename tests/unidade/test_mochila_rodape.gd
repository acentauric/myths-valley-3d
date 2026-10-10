extends "res://tests/unidade/base.gd"
## O rodapé da mochila acompanha o remapeamento da tecla de fechar, em qualquer idioma.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste mochila_rodape
const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")
const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")
func test_rodape_acompanha_remapeamento() -> void:
	var mochila := root.get_node("Mochila")
	var antiga: Callable = mochila.letra_de_fechar
	var controles_existiam := FileAccess.file_exists(Atalhos.ARQUIVO)
	var controles_antes := FileAccess.get_file_as_bytes(Atalhos.ARQUIVO) if controles_existiam else PackedByteArray()
	mochila.letra_de_fechar = func(): return Atalhos.letra("mochila")
	if "--tecla-fixa" in OS.get_cmdline_user_args():
		# Falsificação da antiga tabela literal, mantendo o remapeamento real.
		mochila.letra_de_fechar = func(): return "I"
	Atalhos.definir("mapa", KEY_I)
	conferir(Atalhos.letra("mochila") == "M", "mochila remapeada para M")
	mochila.abrir()
	conferir(mochila._rodape.text.contains("[M]") and not mochila._rodape.text.contains("[I]"), "rodape acompanha fechamento remapeado")
	mochila._ultimo_clique = mochila._cursor
	mochila._atualizar()
	conferir(mochila._rodape.text.contains("[M]"), "rodape do segundo clique acompanha remapeamento")
	var idioma_antes := IdiomaMenu.indice()
	for idioma in [1, 2]:
		IdiomaMenu.definir(idioma)
		mochila._ultimo_clique = -1
		mochila._atualizar()
		conferir(mochila._rodape.text.contains("[M]") and mochila._rodape.text.contains("close" if idioma == 1 else "cerrar"), "tradução conserva tecla remapeada")
		mochila._ultimo_clique = mochila._cursor
		mochila._atualizar()
		conferir(mochila._rodape.text.contains("wear or eat" if idioma == 1 else "vestir o comer"), "segundo clique traduzido")
	IdiomaMenu.definir(idioma_antes)
	mochila.fechar()
	mochila.letra_de_fechar = antiga
	if controles_existiam:
		var arquivo := FileAccess.open(Atalhos.ARQUIVO, FileAccess.WRITE)
		arquivo.store_buffer(controles_antes)
		arquivo.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Atalhos.ARQUIVO))
