extends "res://tests/unidade/base.gd"
## O JOGO NÃO USA A IDENTIDADE DO GODOT (#230): ícone da janela e da barra de tarefas, ícone do .exe
## exportado e splash.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste icone_do_jogo
##
## Até a Build 10 o `project.godot` não declarava ícone e os presets não davam `.ico` ao rcedit: o jogador
## baixava um `MythsValley3D.exe` com o ícone genérico, e abria uma janela com o logo do Godot. Aqui se
## cobra o que se pode cobrar sem exportar:
##
##   1. `application/config/icon` é um PNG 512x512 do jogo, e `windows_native_icon` um .ico com os seis
##      tamanhos que o Windows pede (16, 32, 48, 64, 128 e 256), mais o 24;
##   2. os DOIS presets de Windows (Desktop e Tripothon) dão esse .ico ao executável e ao wrapper do
##      console, e trazem empresa, produto e descrição;
##   3. o `include_filter` leva a pasta do ícone para dentro do pacote (o .ico não é recurso, e sem o filtro
##      a janela perderia o ícone em execução);
##   4. o splash não mostra imagem (nada de logo do Godot).
##
## O que o portão não vê é o `.exe` pronto: `tools/prototipo_3d/conferir_icone_do_exe.ps1` o confere depois
## da exportação, e o rcedit é pré-requisito (docs/ferramentas/EXPORTAR_WINDOWS.md).

const PASTA := "res://assets/prototipo_3d/identidade/icone/"
const TAMANHOS := [16, 24, 32, 48, 64, 128, 256]

func test_icone_do_jogo() -> void:
	_projeto()
	_arquivos_do_icone()
	_presets()


func _projeto() -> void:
	var icone := str(ProjectSettings.get_setting("application/config/icon", ""))
	var nativo := str(ProjectSettings.get_setting("application/config/windows_native_icon", ""))
	_conferir(icone == PASTA + "icone.png", "application/config/icon é '%s': a janela e a barra de tarefas ficam com o ícone do Godot" % icone)
	_conferir(nativo == PASTA + "icone.ico", "application/config/windows_native_icon é '%s'" % nativo)
	_conferir(not bool(ProjectSettings.get_setting("application/boot_splash/show_image", true)), "o splash mostra imagem (o logo do Godot)")
	_conferir(str(ProjectSettings.get_setting("application/boot_splash/image", "")) == "", "o splash tem imagem própria declarada")


func _arquivos_do_icone() -> void:
	var png := Image.load_from_file(ProjectSettings.globalize_path(PASTA + "icone.png"))
	_conferir(png != null and png.get_width() == 512 and png.get_height() == 512, "icone.png não tem 512x512")
	var ico := FileAccess.open(PASTA + "icone.ico", FileAccess.READ)
	_conferir(ico != null, "icone.ico não abriu")
	if ico == null:
		return
	_conferir(ico.get_16() == 0 and ico.get_16() == 1, "icone.ico não tem o cabeçalho de ícone")
	var quantos := ico.get_16()
	var tem: Array[int] = []
	for i in quantos:
		var largura := ico.get_8()
		var altura := ico.get_8()
		ico.seek(6 + 16 * i + 16)   # o próximo registro
		tem.append(256 if largura == 0 else largura)
		_conferir((largura == altura), "um quadro do .ico não é quadrado (%d x %d)" % [largura, altura])
	tem.sort()
	_conferir(str(tem) == str(TAMANHOS), "o .ico traz os tamanhos %s, e o Windows pede %s" % [str(tem), str(TAMANHOS)])


func _presets() -> void:
	var presets := ConfigFile.new()
	_conferir(presets.load("res://export_presets.cfg") == OK, "export_presets.cfg não abriu")
	var vistos := 0
	for secao in presets.get_sections():
		if presets.get_value(secao, "platform", "") != "Windows Desktop" or secao.ends_with(".options"):
			continue
		vistos += 1
		var nome := str(presets.get_value(secao, "name", secao))
		var opcoes := secao + ".options"
		_conferir(str(presets.get_value(opcoes, "application/icon", "")) == PASTA + "icone.ico", "o preset '%s' não dá o icone.ico ao executável" % nome)
		_conferir(str(presets.get_value(opcoes, "application/console_wrapper_icon", "")) == PASTA + "icone.ico", "o preset '%s' não dá o icone.ico ao wrapper do console" % nome)
		_conferir(bool(presets.get_value(opcoes, "application/modify_resources", false)), "o preset '%s' não grava os recursos do executável (modify_resources)" % nome)
		for campo in ["company_name", "product_name", "file_description"]:
			_conferir(str(presets.get_value(opcoes, "application/" + campo, "")).strip_edges() != "", "o preset '%s' não preenche application/%s" % [nome, campo])
		_conferir(str(presets.get_value(secao, "include_filter", "")).contains("assets/prototipo_3d/identidade/icone/"),
			"o preset '%s' não leva a pasta do ícone para o pacote" % nome)
	_conferir(vistos >= 2, "esperava os dois presets de Windows (Desktop e Tripothon), achei %d" % vistos)
