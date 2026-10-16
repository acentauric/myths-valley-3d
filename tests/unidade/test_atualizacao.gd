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
##     demais ou sem espaço em disco vira FALHOU com o motivo e a oferta do site, nunca EM_DIA;
##   - (#231) o download do zip de 1,2 GB morrer no minuto 5 com a conexão boa: não há prazo total,
##     só o tempo sem chegar byte novo, e quem para de receber vê a falha com a saída de tentar de novo.
##
## O formato do zip (os extras que passam) fica em tests/unidade/test_zip_do_atualizador.gd.

var Atualizacao: GDScript
var IdiomaMenu: GDScript


func before_all() -> void:
	super.before_all()
	# load() e não preload: o script tem de ser lido já com os autoloads de pé.
	Atualizacao = load("res://scripts/autoload/atualizacao.gd")
	IdiomaMenu = load("res://scripts/prototipo_3d/idioma_menu.gd")


func test_manifesto() -> void:
	_manifesto()


func test_limites_seguem_o_jogo() -> void:
	_limites_seguem_o_jogo()


func test_nunca_em_silencio() -> void:
	_nunca_em_silencio()


func test_espaco_em_disco() -> void:
	_espaco_em_disco()


func test_download_sem_teto_de_tempo() -> void:
	_download_sem_teto_de_tempo()


func test_download_que_para_de_chegar() -> void:
	_download_que_para_de_chegar()


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


## O DOWNLOAD NÃO TEM PRAZO TOTAL. O `timeout` do HTTPRequest vale para a requisição inteira: com 300 s,
## o zip de 1,2 GB morria no minuto 5 para quem tem menos de uns 32 Mbps, com a conexão boa e andando.
## O pedido sai com `timeout` 0 e a vigia só desiste quando nenhum byte novo chega por TEMPO_SEM_PROGRESSO.
func _download_sem_teto_de_tempo() -> void:
	var zip_real := 1200 * 1024 * 1024
	var instancia: Node = Atualizacao.new()
	instancia.manifesto = _manifesto_de(9999, zip_real)
	var pedido: HTTPRequest = instancia._preparar_download("user://atualizacao/atualizacao.zip")
	_conferir(pedido.timeout == 0.0, "o download ficou com prazo total de %.0f s: o zip de 1,2 GB morre no meio para quem tem menos de uns 32 Mbps" % pedido.timeout)
	_conferir(pedido.download_file == "user://atualizacao/atualizacao.zip" and pedido.max_redirects == 0 and pedido.body_size_limit == zip_real,
		"o pedido do download perdeu a configuração que já tinha (arquivo, redirecionamento, tamanho)")
	# Sem linha própria: na linha própria a leitura do corpo bloqueia num pedaço inteiro, a vigia não vê os bytes
	# de uma conexão que parou, e `cancel_request()` trava o jogo até o servidor fechar (medido no Godot 4.7.2).
	_conferir(not pedido.use_threads, "o download voltou para a linha própria do HTTPRequest: uma conexão parada trava o jogo no cancelamento e a vigia não vê os bytes")
	pedido.free()
	instancia.free()
	# O tempo sem progresso é a única régua: tem de ser curto para quem perdeu a rede e longo para a conexão que engasga.
	_conferir(Atualizacao.TEMPO_SEM_PROGRESSO >= 30.0 and Atualizacao.TEMPO_SEM_PROGRESSO <= 120.0, "TEMPO_SEM_PROGRESSO (%s s) está fora do que aguenta uma conexão que engasga sem deixar o jogador esperando à toa" % Atualizacao.TEMPO_SEM_PROGRESSO)
	# A regra pura: byte novo zera o relógio, a falta de byte soma o quadro.
	_conferir(Atualizacao.tempo_parado(1000, 1000, 10.0, 0.5) == 10.5, "sem byte novo o tempo parado devia somar o quadro")
	_conferir(Atualizacao.tempo_parado(1001, 1000, 59.0, 0.5) == 0.0, "um byte novo devia zerar o tempo parado")
	_conferir(Atualizacao.tempo_parado(0, 0, 0.0, 1.0) == 1.0, "antes do primeiro byte o tempo parado também conta")


## O download que anda devagar não morre; o que para de receber desiste, apaga o arquivo pela metade e
## diz o motivo, sem mandar o jogador ao site (tentar de novo resolve quando a conexão volta).
func _download_que_para_de_chegar() -> void:
	var zip_real := 1200 * 1024 * 1024
	var destino := _pasta_limpa("vigia").path_join("atualizacao.zip")
	var vigia := func(bytes: int) -> Node:
		var instancia: Node = Atualizacao.new()
		instancia.manifesto = _manifesto_de(9999, zip_real)
		instancia.estado = Atualizacao.Estado.BAIXANDO
		instancia._http = instancia._preparar_download(destino)
		instancia.add_child(instancia._http)
		instancia._destino_do_download = destino
		instancia._baixado_visto = bytes
		_gravar(destino, "metade do zip")
		return instancia

	# 1. Devagar mas andando: um byte a cada 55 s por uma hora. O teto fixo de 300 s já teria matado.
	var andando: Node = vigia.call(0)
	var desistiu := false
	for passo in 66:
		desistiu = desistiu or andando._vigiar_download(55.0, passo + 1)
	_conferir(not desistiu and andando.estado == Atualizacao.Estado.BAIXANDO and andando._http != null, "o download que anda devagar (66 passos de 55 s, uma hora) foi dado por parado")
	_conferir(FileAccess.file_exists(destino), "o arquivo do download que anda foi apagado")
	# 2. Parou: o tempo sem byte novo passa de TEMPO_SEM_PROGRESSO, e só aí desiste.
	var cedo: bool = andando._vigiar_download(Atualizacao.TEMPO_SEM_PROGRESSO - 1.0, 66)
	_conferir(not cedo and andando.estado == Atualizacao.Estado.BAIXANDO, "desistiu antes de %s s sem byte novo" % Atualizacao.TEMPO_SEM_PROGRESSO)
	var tarde: bool = andando._vigiar_download(1.0, 66)
	_conferir(tarde, "não desistiu depois de %s s sem byte novo" % Atualizacao.TEMPO_SEM_PROGRESSO)
	_conferir(andando.estado == Atualizacao.Estado.FALHOU, "o download parado não virou FALHOU (estado %d)" % andando.estado)
	_conferir(not andando.so_pelo_site, "o download parado mandou o jogador ao site: tentar de novo é a saída")
	_conferir(andando._http == null, "o pedido parado ficou pendurado")
	_conferir(not FileAccess.file_exists(destino), "o arquivo pela metade ficou no disco")
	_conferir(str(andando.erro).contains("9999") and str(andando.erro).contains("%d" % int(Atualizacao.TEMPO_SEM_PROGRESSO)), "o motivo não diz a build nem os segundos: '%s'" % andando.erro)
	andando.free()
	# 3. Nunca chegou um byte (a conexão nem abriu): a vigia também pega.
	var muda: Node = vigia.call(0)
	_conferir(not muda._vigiar_download(Atualizacao.TEMPO_SEM_PROGRESSO - 1.0, 0), "desistiu cedo demais de um download que ainda nem começou")
	_conferir(muda._vigiar_download(2.0, 0) and muda.estado == Atualizacao.Estado.FALHOU, "um download que nunca recebeu byte não foi dado por parado")
	muda.free()
	# 4. Um byte no meio do silêncio zera a espera: engasgou e voltou. Dois silêncios de 50 s, um byte entre
	# eles, não somam 100 s; só um silêncio inteiro de TEMPO_SEM_PROGRESSO desiste.
	var engasgou: Node = vigia.call(0)
	_conferir(not engasgou._vigiar_download(50.0, 10), "desistiu com os primeiros bytes chegando")
	_conferir(not engasgou._vigiar_download(50.0, 10), "desistiu com 50 s de silêncio")
	_conferir(not engasgou._vigiar_download(5.0, 11), "desistiu com um byte novo chegando")
	_conferir(not engasgou._vigiar_download(50.0, 11) and engasgou.estado == Atualizacao.Estado.BAIXANDO, "somou os dois silêncios (50 s + 50 s) apesar do byte que chegou entre eles")
	_conferir(engasgou._vigiar_download(11.0, 11) and engasgou.estado == Atualizacao.Estado.FALHOU, "um silêncio de %s s depois do último byte não derrubou o download" % (Atualizacao.TEMPO_SEM_PROGRESSO + 1.0))
	engasgou.free()


## O aviso novo existe nos três idiomas e não é cópia do português.
func test_aviso_do_download_parado_nos_idiomas() -> void:
	var chave := "O download da Build %d parou: nenhum dado chegou em %d segundos. Confira a conexão e tente de novo."
	for dicionario in [IdiomaMenu.EN, IdiomaMenu.ES]:
		var texto := str(dicionario.get(chave, ""))
		_conferir(not texto.is_empty() and texto != chave, "o aviso do download parado falta em inglês ou espanhol, ou é cópia do português")
		_conferir(texto.count("%d") == 2, "a tradução do aviso do download parado não tem os dois %%d: '%s'" % texto)


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
