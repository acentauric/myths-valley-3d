extends SceneTree
## A ATUALIZAÇÃO PELO SITE (#74), sem rede: o manifesto, a comparação de builds, o
## SHA-256 e a cadeia de arquivos da instalação — zip, extração, troca do executável
## e limpeza — numa pasta descartável de user://.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/atualizacao.gd
##
## O que este portão impede:
##   - oferecer uma build que não é mais nova, ou aceitar manifesto que não diz de
##     onde baixar com segurança (http, sem hash, sem zip);
##   - instalar arquivo cujo hash não confere;
##   - perder o executável quando a troca falha no meio (ele tem de voltar);
##   - deixar o `.old` e a pasta de extração para trás.

var falhas := 0
var Atualizacao: GDScript


func _initialize() -> void:
	# load() e não preload: teste com --script não enxerga autoload pelo nome.
	Atualizacao = load("res://scripts/autoload/atualizacao.gd")
	_manifesto()
	_hash()
	_instalacao()
	if falhas == 0:
		print("ATUALIZACAO_OK: manifesto, builds, SHA-256, extração, troca do executável e limpeza")
	quit(1 if falhas > 0 else 0)


func _conferir(certo: bool, o_que: String) -> void:
	if not certo:
		print("FALHA: " + o_que)
		falhas += 1


func _manifesto() -> void:
	var bom := {
		"build": 7,
		"url": "https://mythsvalley.app.br/downloads/MythsValley3D-build7-windows.zip",
		"arquivo": "MythsValley3D-build7-windows.zip",
		"sha256": "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
	}
	_conferir(Atualizacao.manifesto_valido(bom), "um manifesto completo foi recusado")
	_conferir(Atualizacao.ha_versao_nova(bom, 6), "a Build 7 não foi oferecida a quem tem a 6")
	_conferir(not Atualizacao.ha_versao_nova(bom, 7), "a Build 7 foi oferecida a quem já tem a 7")
	_conferir(not Atualizacao.ha_versao_nova(bom, 9), "uma build mais velha foi oferecida")
	var ruins := {
		"sem https": {"url": "http://mythsvalley.app.br/x.zip"},
		"sem hash": {"sha256": ""},
		"hash curto": {"sha256": "ba7816bf"},
		"hash que não é hexadecimal": {"sha256": "z".repeat(64)},
		"sem zip": {"arquivo": "MythsValley3D.exe"},
		"sem build": {"build": 0},
		"url nula": {"url": null},
	}
	for caso in ruins:
		var dados := bom.duplicate()
		dados.merge(ruins[caso], true)
		_conferir(not Atualizacao.manifesto_valido(dados), "manifesto %s foi aceito" % caso)
		_conferir(not Atualizacao.ha_versao_nova(dados, 1), "manifesto %s ofereceu atualização" % caso)


func _hash() -> void:
	var pasta := _pasta_limpa("hash")
	var arquivo := FileAccess.open(pasta.path_join("abc.txt"), FileAccess.WRITE)
	arquivo.store_string("abc")
	arquivo.close()
	_conferir(Atualizacao.sha256_do_arquivo(pasta.path_join("abc.txt")) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", "o SHA-256 de 'abc' saiu errado")
	_conferir(Atualizacao.sha256_do_arquivo(pasta.path_join("nao_existe")) == "", "arquivo inexistente ganhou hash")


func _instalacao() -> void:
	var raiz := _pasta_limpa("jogo")
	var exe := raiz.path_join("MythsValley3D.exe")
	_gravar(exe, "build 6")

	# O zip da build traz o executável dentro de uma pasta, como o do site.
	var zip := raiz.path_join("build7.zip")
	var empacotador := ZIPPacker.new()
	empacotador.open(zip)
	empacotador.start_file("MythsValley3D/MythsValley3D.exe")
	empacotador.write_file("build 7".to_utf8_buffer())
	empacotador.close_file()
	empacotador.close()

	var extracao := raiz.path_join(Atualizacao.PASTA_EXTRACAO)
	DirAccess.make_dir_recursive_absolute(extracao)
	_conferir(Atualizacao.extrair_zip(zip, extracao) == "", "o zip não extraiu")
	var novo: String = Atualizacao.achar_executavel(extracao, "MythsValley3D.exe")
	_conferir(not novo.is_empty(), "o executável não foi achado dentro da pasta do zip")
	_conferir(Atualizacao.trocar_executavel(exe, novo) == "", "a troca do executável falhou")
	_conferir(_ler(exe) == "build 7", "o executável no lugar não é o novo")
	_conferir(_ler(exe + Atualizacao.SUFIXO_ANTIGO) == "build 6", "o executável antigo não ficou guardado como .old")

	# Troca que falha no meio (o novo sumiu): o atual tem de voltar para o lugar.
	_conferir(Atualizacao.trocar_executavel(exe, raiz.path_join("nao_existe.exe")) != "", "a troca sem arquivo novo disse que deu certo")
	_conferir(_ler(exe) == "build 7", "a troca que falhou deixou o jogo sem executável")

	Atualizacao.limpar_restos(exe)
	_conferir(not FileAccess.file_exists(exe + Atualizacao.SUFIXO_ANTIGO), "o .old ficou depois da limpeza")
	_conferir(not DirAccess.dir_exists_absolute(extracao), "a pasta de extração ficou depois da limpeza")
	_conferir(_ler(exe) == "build 7", "a limpeza levou o executável junto")


func _pasta_limpa(nome: String) -> String:
	var pasta := ProjectSettings.globalize_path("user://teste_atualizacao").path_join(nome)
	Atualizacao._apagar_pasta(pasta)
	DirAccess.make_dir_recursive_absolute(pasta)
	return pasta


func _gravar(caminho: String, texto: String) -> void:
	var arquivo := FileAccess.open(caminho, FileAccess.WRITE)
	arquivo.store_string(texto)
	arquivo.close()


func _ler(caminho: String) -> String:
	return FileAccess.get_file_as_string(caminho) if FileAccess.file_exists(caminho) else ""
