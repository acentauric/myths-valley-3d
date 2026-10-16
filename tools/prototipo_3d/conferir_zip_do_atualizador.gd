extends SceneTree
## CONFERE UM ZIP COM O ATUALIZADOR DE VERDADE (#231): chama o `Atualizacao.conferir_zip` do código
## desta árvore, o mesmo que a próxima build vai embutir, e diz se ele aceita o zip.
##
##     Godot --headless --path . --script res://tools/prototipo_3d/conferir_zip_do_atualizador.gd -- <zip>
##
## Imprime `ZIP_OK` (saída 0) ou `ZIP_RECUSADO: <motivo>` (saída 1); `ZIP_USO: ...` e saída 2 se faltar o
## caminho. Quem chama é o conferir_fechamento_de_build.ps1, junto com a cópia em Python que o
## tools/prototipo_3d/zipar_build.py faz da mesma regra: esta aqui é a regra de verdade, aquela é a que
## roda sem Godot e confere as builds anteriores.
##
## Convenções do `--script` deste projeto: o `Atualizacao` não é lido pelo nome do autoload, que não existe
## num `--script`, e sim por `load()` do arquivo; o `conferir_zip` é estático e não precisa do resto do jogo.


func _initialize() -> void:
	var argumentos := OS.get_cmdline_user_args()
	if argumentos.size() != 1:
		print("ZIP_USO: conferir_zip_do_atualizador.gd -- <caminho do zip>")
		quit(2)
		return
	var Atualizacao: GDScript = load("res://scripts/autoload/atualizacao.gd")
	var falha: String = Atualizacao.conferir_zip(argumentos[0])
	if falha.is_empty():
		print("ZIP_OK")
		quit(0)
	else:
		print("ZIP_RECUSADO: " + falha)
		quit(1)
