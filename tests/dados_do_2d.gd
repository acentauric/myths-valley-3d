extends SceneTree
## Confere que os DADOS copiados do 2D continuam iguais ao original.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/dados_do_2d.gd
##
## Os autoloads compartilhados leem `res://data/...`, e `res://` aqui é a pasta
## do protótipo. Então o arquivo tem de morar dentro dela — e passa a ser uma
## cópia. Cópia que ninguém confere é regra sem portão: o 2D muda um cordel, o
## vale continua mostrando o velho, e ninguém fica sabendo.
##
## O dono é sempre o 2D. Este portão compara, byte a byte, cada cópia com o
## original na raiz do repositório e reprova dizendo qual divergiu. É o mesmo
## trato do `testar_compartilhado` com os scripts, feito do lado do vale.
##
## Ao trazer um arquivo novo do 2D, ponha-o em COPIAS.

const COPIAS := [
	"data/colecionaveis/cordeis.json",
	"data/colecionaveis/sinais.json",
	"data/colecionaveis/bichos.json",
	"data/cartas/cartas.json",
]

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("DADOS_DO_2D_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	var raiz_do_2d := ProjectSettings.globalize_path("res://").path_join("..")
	for caminho in COPIAS:
		var copia := FileAccess.get_file_as_bytes("res://" + caminho)
		var original := FileAccess.get_file_as_bytes(raiz_do_2d.path_join(caminho))
		_conferir(not copia.is_empty(), "o vale não tem %s" % caminho)
		_conferir(not original.is_empty(), "não achei o original do 2D: %s" % caminho)
		_conferir(copia == original, "%s divergiu do 2D: o dono é o 2D, copie de lá de novo" % caminho)
	print("")
	if falhas == 0:
		print("DADOS_DO_2D_OK: %d cópia(s) iguais ao original do 2D, byte a byte" % COPIAS.size())
	else:
		print("dados_do_2d: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)
