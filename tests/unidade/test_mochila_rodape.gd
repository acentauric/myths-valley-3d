extends "res://tests/unidade/base.gd"
## O rodapé da mochila acompanha o remapeamento da tecla de fechar, em qualquer idioma.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste mochila_rodape
##
## O teste põe o mapa no I (a mochila herda o M) e troca o idioma, e os dois ficam gravados no `user://`. Por isso SÓ RODA NO
## PERFIL DESCARTÁVEL do `testar.ps1` (#254): por fora do runner ele fica pendente. Antes ele guardava os bytes do
## `controles.cfg` de verdade e os devolvia no fim, e um teste que estourava no meio deixava o arquivo com o mapa no I. A
## limpeza agora mora no `after_each`, que roda também quando o teste estoura.
const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")
const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")

var _idioma_de_antes := 0


func before_each() -> void:
	super()
	Atalhos._cache.clear()
	_idioma_de_antes = IdiomaMenu.indice()


func after_each() -> void:
	if Estado.perfil_descartavel():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Atalhos.ARQUIVO))
		Atalhos._cache.clear()
		Atalhos.aplicar()
		IdiomaMenu.definir(_idioma_de_antes)


func test_rodape_acompanha_remapeamento() -> void:
	if not exige_perfil_descartavel():
		return
	var mochila := root.get_node("Mochila")
	var antiga: Callable = mochila.letra_de_fechar
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
	for idioma in [1, 2]:
		IdiomaMenu.definir(idioma)
		mochila._ultimo_clique = -1
		mochila._atualizar()
		conferir(mochila._rodape.text.contains("[M]") and mochila._rodape.text.contains("close" if idioma == 1 else "cerrar"), "tradução conserva tecla remapeada")
		mochila._ultimo_clique = mochila._cursor
		mochila._atualizar()
		conferir(mochila._rodape.text.contains("wear or eat" if idioma == 1 else "vestir o comer"), "segundo clique traduzido")
	mochila.fechar()
	mochila.letra_de_fechar = antiga
