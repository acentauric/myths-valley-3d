extends "res://tests/unidade/base.gd"
## A ATUALIZAÇÃO PELO SITE (#74), sem rede: o manifesto, a comparação de builds, o
## SHA-256 e a cadeia de arquivos da instalação — zip, extração, troca do executável
## e limpeza — numa pasta descartável de user://.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste atualizacao
##
## O que este portão impede:
##   - oferecer uma build que não é mais nova, ou aceitar manifesto que não diz de
##     onde baixar com segurança (http, sem hash, sem zip);
##   - instalar arquivo cujo hash não confere;
##   - perder o executável quando a troca falha no meio (ele tem de voltar);
##   - deixar o `.old` e a pasta de extração para trás;
##   - (#231) o limite de tamanho ficar abaixo do jogo: o manifesto com o tamanho REAL da última build
##     registrada (data/atualizador_builds.json) e com o dobro dele tem de passar, e build grande
##     demais ou sem espaço em disco vira FALHOU com o motivo e a oferta do site, nunca EM_DIA.

var Atualizacao: GDScript


func before_all() -> void:
	super.before_all()
	# load() e não preload: o script tem de ser lido já com os autoloads de pé.
	Atualizacao = load("res://scripts/autoload/atualizacao.gd")


func test_manifesto() -> void:
	_manifesto()


func test_limites_seguem_o_jogo() -> void:
	_limites_seguem_o_jogo()


func test_nunca_em_silencio() -> void:
	_nunca_em_silencio()


func test_espaco_em_disco() -> void:
	_espaco_em_disco()


func test_hash() -> void:
	_hash()


func test_instalacao() -> void:
	_instalacao()


func test_edicao_estatica() -> void:
	_edicao_estatica()


func _manifesto() -> void:
	var bom := {
		"build": 7,
		"url": "https://mythsvalley.app.br/downloads/MythsValley3D-build7-windows.zip",
		"arquivo": "MythsValley3D-build7-windows.zip",
		"sha256": "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
		"bytes": 100,
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


## O MANIFESTO NO TAMANHO DO JOGO. A Build 9 não via a 10 porque o limite era de uma build de 360 MB e
## o jogo já tinha mais de 1 GB: aqui o limite é cobrado contra o tamanho real da última build
## registrada, e contra o dobro dele (data/atualizador_builds.json; ao fechar uma build,
## tools/prototipo_3d/conferir_fechamento_de_build.ps1 -Registrar a põe lá).
func _limites_seguem_o_jogo() -> void:
	var registro = JSON.parse_string(FileAccess.get_file_as_string("res://data/atualizador_builds.json"))
	_conferir(registro is Dictionary and (registro as Dictionary).get("builds") is Dictionary, "data/atualizador_builds.json não abriu")
	if not (registro is Dictionary and (registro as Dictionary).get("builds") is Dictionary):
		return
	var ultima := -1
	for numero in registro["builds"]:
		var dados = registro["builds"][numero]
		if dados is Dictionary and (dados as Dictionary).has("zip_bytes") and int(numero) > ultima:
			ultima = int(numero)
	_conferir(ultima > 0, "o registro não tem o tamanho de nenhuma build")
	if ultima <= 0:
		return
	var medida: Dictionary = registro["builds"][str(ultima)]
	var zip_real := int(medida["zip_bytes"])
	var exe_real := int(medida["exe_bytes"])
	_conferir(zip_real > 1000 * 1024 * 1024, "o tamanho registrado da Build %d (%d) não é o de um jogo de mais de 1 GB" % [ultima, zip_real])
	for fator in [1, 2]:
		var manifesto := _manifesto_de(ultima + 1, zip_real * fator)
		_conferir(Atualizacao.manifesto_valido(manifesto), "o manifesto com %dx o zip da Build %d (%d bytes) foi recusado: o limite ficou abaixo do jogo" % [fator, ultima, zip_real * fator])
		_conferir(not Atualizacao.grande_demais(manifesto), "o zip de %dx a Build %d foi tomado por grande demais" % [fator, ultima])
		manifesto["extraido"] = exe_real * fator
		_conferir(Atualizacao.manifesto_valido(manifesto), "o manifesto com %dx o executável da Build %d (%d bytes) foi recusado: o limite do jogo extraído ficou abaixo do jogo" % [fator, ultima, exe_real * fator])
	_conferir(zip_real * 2 <= Atualizacao.MAX_ZIP, "MAX_ZIP (%d) não dá o dobro do zip da Build %d" % [Atualizacao.MAX_ZIP, ultima])
	_conferir(exe_real * 2 <= Atualizacao.MAX_EXTRAIDO, "MAX_EXTRAIDO (%d) não dá o dobro do executável da Build %d" % [Atualizacao.MAX_EXTRAIDO, ultima])
	# A falsificação do portão: os limites antigos (768 MB e 1 GB) reprovariam o próprio jogo.
	_conferir(zip_real > 768 * 1024 * 1024 and exe_real > 1024 * 1024 * 1024, "o tamanho registrado já cabe nos limites antigos: o portão não prova nada")
	# Tamanho absurdo continua recusado, e com nome.
	var enorme := _manifesto_de(ultima + 1, Atualizacao.MAX_ZIP + 1)
	_conferir(Atualizacao.manifesto_bem_formado(enorme) and Atualizacao.grande_demais(enorme) and not Atualizacao.manifesto_valido(enorme),
		"um zip acima de MAX_ZIP não foi tomado por grande demais")
	var gigante := _manifesto_de(ultima + 1, zip_real)
	gigante["extraido"] = Atualizacao.MAX_EXTRAIDO + 1
	_conferir(Atualizacao.grande_demais(gigante) and not Atualizacao.manifesto_valido(gigante), "um jogo extraído acima de MAX_EXTRAIDO não foi tomado por grande demais")
	var torto := _manifesto_de(ultima + 1, zip_real)
	torto["extraido"] = -5
	_conferir(not Atualizacao.manifesto_bem_formado(torto), "extraido negativo foi aceito")


## BUILD GRANDE DEMAIS NUNCA VIRA "EM DIA". O manifesto chega ao `_ao_receber_manifesto` como chegaria
## da rede: a build nova que passa dos limites vira FALHOU, com o motivo e a oferta do site.
func _nunca_em_silencio() -> void:
	var recebido := func(corpo: Variant) -> Node:
		var instancia: Node = Atualizacao.new()
		root.add_child(instancia)
		var bytes: PackedByteArray = corpo if corpo is PackedByteArray else JSON.stringify(corpo).to_utf8_buffer()
		instancia._ao_receber_manifesto(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), bytes)
		return instancia
	var grande: Node = recebido.call(_manifesto_de(9999, Atualizacao.MAX_ZIP + 1))
	_conferir(grande.estado == Atualizacao.Estado.FALHOU, "build grande demais não virou FALHOU (estado %d)" % grande.estado)
	_conferir(grande.so_pelo_site and not str(grande.erro).is_empty(), "build grande demais não disse o motivo nem ofereceu o site")
	_conferir(str(grande.erro).contains("9999"), "o motivo não diz qual build é: '%s'" % grande.erro)
	_conferir(grande.build_nova() == 9999 and str(grande.pagina_de_download()).begins_with(Atualizacao.ORIGEM), "a oferta do site não tem a build nem a página")
	grande.free()
	var pesada := _manifesto_de(9999, 1024 * 1024 * 1024)
	pesada["extraido"] = Atualizacao.MAX_EXTRAIDO + 1
	var jogo_grande: Node = recebido.call(pesada)
	_conferir(jogo_grande.estado == Atualizacao.Estado.FALHOU and jogo_grande.so_pelo_site, "jogo extraído grande demais não virou FALHOU com o site")
	jogo_grande.free()
	var normal: Node = recebido.call(_manifesto_de(9999, 1200 * 1024 * 1024))
	_conferir(normal.estado == Atualizacao.Estado.DISPONIVEL and not normal.so_pelo_site, "a build do tamanho da 10 não foi oferecida (estado %d)" % normal.estado)
	normal.free()
	var lixo: Node = recebido.call("isto não é json".to_utf8_buffer())
	# O JSON.parse_string de uma resposta que não é JSON registra um erro de motor, esperado aqui (o GUT o reprovaria).
	assert_engine_error("error != Error::OK")
	_conferir(lixo.estado == Atualizacao.Estado.EM_DIA, "uma resposta que não é manifesto não deixou o jogo em dia")
	lixo.free()


## O ESPAÇO EM DISCO: o zip mais a margem na pasta de dados, o jogo extraído mais a margem ao lado
## do executável, tudo junto quando é o mesmo disco; 0 livre é "não sei" e não barra.
func _espaco_em_disco() -> void:
	var gb := 1024 * 1024 * 1024
	var zip := int(1.1 * gb)
	var jogo := int(1.4 * gb)
	_conferir(Atualizacao.espaco_que_falta(zip, jogo, 10 * gb, 10 * gb, false).is_empty(), "com 10 GB livres nos dois discos, faltou espaço")
	_conferir(Atualizacao.espaco_que_falta(zip, jogo, 10 * gb, 10 * gb, true).is_empty(), "com 10 GB livres no mesmo disco, faltou espaço")
	var falta_para_baixar: Dictionary = Atualizacao.espaco_que_falta(zip, jogo, gb, 10 * gb, false)
	_conferir(not falta_para_baixar.is_empty() and int(falta_para_baixar["precisa"]) == zip + Atualizacao.MARGEM_DE_ESPACO and int(falta_para_baixar["livre"]) == gb,
		"com 1 GB livre na pasta de dados, a conferência deixou baixar 1,1 GB: %s" % str(falta_para_baixar))
	var falta_para_extrair: Dictionary = Atualizacao.espaco_que_falta(zip, jogo, 10 * gb, gb, false)
	_conferir(not falta_para_extrair.is_empty() and int(falta_para_extrair["precisa"]) == jogo + Atualizacao.MARGEM_DE_ESPACO,
		"com 1 GB livre ao lado do executável, a conferência deixou extrair 1,4 GB: %s" % str(falta_para_extrair))
	# No mesmo disco, baixar e extrair somam: 2 GB livres bastam para cada um, mas não para os dois.
	_conferir(not Atualizacao.espaco_que_falta(zip, jogo, 2 * gb, 2 * gb, true).is_empty(), "no mesmo disco, 2 GB livres bastaram para baixar e extrair 2,5 GB")
	_conferir(Atualizacao.espaco_que_falta(zip, jogo, 2 * gb, 2 * gb, false).is_empty(), "em discos separados, 2 GB livres em cada um não bastaram")
	_conferir(Atualizacao.espaco_que_falta(zip, jogo, 0, 0, true).is_empty(), "sem saber o espaço livre (0), a conferência barrou o jogador")
	_conferir(Atualizacao.mesmo_disco("C:/Users/a/AppData", "c:/jogo"), "C: e c: são o mesmo disco")
	_conferir(not Atualizacao.mesmo_disco("C:/Users/a/AppData", "D:/jogo"), "C: e D: não são o mesmo disco")
	_conferir(not Atualizacao.mesmo_disco("user://x", "D:/jogo"), "caminho sem unidade foi tomado por mesmo disco")
	_conferir(Atualizacao.extraido_estimado({"bytes": 1000}) == 1500 and Atualizacao.extraido_estimado({"bytes": 1000, "extraido": 1300}) == 1300, "a estimativa do jogo extraído saiu errada")
	_conferir(Atualizacao.tamanho_legivel(int(1.5 * gb)) == "1.50 GB" and Atualizacao.tamanho_legivel(480 * 1024 * 1024) == "480 MB", "o tamanho legível saiu errado")


func _manifesto_de(build: int, bytes: int) -> Dictionary:
	return {
		"build": build,
		"url": "https://mythsvalley.app.br/downloads/MythsValley3D-build%d-windows.zip" % build,
		"arquivo": "MythsValley3D-build%d-windows.zip" % build,
		"sha256": "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
		"bytes": bytes,
	}


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


## A build do Tripothon (feature `tripothon`) é fixa: nunca consulta, baixa nem instala.
## O portão finge a feature pela variável do script e confere o preset de exportação.
func _edicao_estatica() -> void:
	_conferir(not Atualizacao.edicao_estatica(), "a edição normal foi tomada por estática")
	var presets := ConfigFile.new()
	_conferir(presets.load("res://export_presets.cfg") == OK, "export_presets.cfg não abriu")
	var achou := false
	for secao in presets.get_sections():
		if presets.get_value(secao, "name", "") == "Windows Tripothon":
			achou = true
			_conferir("tripothon" in str(presets.get_value(secao, "custom_features", "")).split(","), "o preset Tripothon não traz a feature tripothon")
			_conferir(str(presets.get_value(secao, "export_path", "")) == "build/tripothon/MythsValley3D.exe", "o preset Tripothon exporta para outro caminho")
		elif presets.get_value(secao, "name", "") == "Windows Desktop":
			_conferir(str(presets.get_value(secao, "custom_features", "")) == "", "o preset normal ganhou feature")
	_conferir(achou, "falta o preset Windows Tripothon")
	Atualizacao.forcar_estatica = true
	_conferir(Atualizacao.edicao_estatica(), "a feature fingida não valeu")
	var instancia: Node = Atualizacao.new()
	instancia.verificar()
	_conferir(instancia.estado == Atualizacao.Estado.PARADO and instancia._http == null, "a edição estática consultou o site")
	_conferir(not instancia.instala_sozinho(), "a edição estática se instalaria sozinha")
	# Mesmo com uma oferta na mão (manifesto de uma build nova), `atualizar` não anda.
	instancia.manifesto = {"build": 99}
	instancia.estado = Atualizacao.Estado.DISPONIVEL
	instancia.atualizar()
	_conferir(instancia.estado == Atualizacao.Estado.DISPONIVEL and instancia._http == null, "a edição estática começou a baixar")
	instancia.free()
	Atualizacao.forcar_estatica = false


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
