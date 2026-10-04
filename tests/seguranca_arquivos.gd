extends SceneTree
## #76: arquivos externos não escapam da pasta nem executam código ao serem lidos.
var falhas := 0
var Atualizacao: GDScript

func _initialize() -> void:
	Atualizacao = load("res://scripts/autoload/atualizacao.gd")
	call_deferred("_testar")

func _testar() -> void:
	_manifestos()
	_pacotes()
	_saves()
	print("SEGURANCA_ARQUIVOS_OK" if falhas == 0 else "FALHAS DE SEGURANCA: %d" % falhas)
	quit(1 if falhas else 0)

func _conferir(certo: bool, motivo: String) -> void:
	if not certo:
		print("FALHA: " + motivo)
		falhas += 1

func _manifestos() -> void:
	var bom := {"build": 9, "url": "https://mythsvalley.app.br/baixar/windows?origem=jogo", "arquivo": "build9.zip", "bytes": 100, "sha256": "a".repeat(64)}
	_conferir(Atualizacao.manifesto_valido(bom), "o manifesto do site não passa")
	for troca in [{"arquivo": "../fora.zip"}, {"arquivo": "C:/fora.zip"}, {"arquivo": "x.zip:alvo.zip"}, {"url": "https://example.invalid/x.zip"}, {"url": "https://mythsvalley.app.br.evil.invalid/x.zip"}, {"url": "https://mythsvalley.app.br@evil.invalid/x.zip"}, {"bytes": -1}, {"bytes": 2147483648}]:
		var dado := bom.duplicate()
		dado.merge(troca, true)
		_conferir(not Atualizacao.manifesto_valido(dado), "manifesto inseguro aceito: " + str(troca))

func _pacotes() -> void:
	var base := ProjectSettings.globalize_path("user://seguranca_pacotes")
	DirAccess.make_dir_recursive_absolute(base)
	var numero := 0
	for nome in ["../fora.txt", "MythsValley3D/../../fora.txt", "MythsValley3D\\..\\fora.txt", "MythsValley3D/arquivo.txt:fluxo", "MythsValley3D/NUL.txt", "MythsValley3D/nome. /fora.txt", "MythsValley3D/extra.dll"]:
		numero += 1
		var zip := base.path_join("ruim%d.zip" % numero)
		var destino := base.path_join("extracao%d" % numero)
		DirAccess.make_dir_recursive_absolute(destino)
		var packer := ZIPPacker.new()
		packer.open(zip)
		packer.start_file("MythsValley3D/MythsValley3D.exe")
		packer.write_file("executavel de teste".to_utf8_buffer())
		packer.close_file()
		packer.start_file(nome)
		packer.write_file("marcador inofensivo".to_utf8_buffer())
		packer.close_file()
		packer.close()
		_conferir(not Atualizacao.extrair_zip(zip, destino).is_empty(), "pacote inseguro foi extraído: " + nome)
		_conferir(not FileAccess.file_exists(destino.path_join("MythsValley3D/MythsValley3D.exe")), "extração parcial ocorreu antes de recusar o ZIP")
	_conferir(not FileAccess.file_exists(base.path_join("fora.txt")), "ZIP gravou fora da extração")
	for tipo in ["link", "cabecalho", "tamanho", "prefixo"]:
		var zip := base.path_join(tipo + ".zip")
		var packer := ZIPPacker.new()
		packer.open(zip)
		packer.start_file("MythsValley3D.exe")
		packer.write_file("marcador".to_utf8_buffer())
		packer.close_file()
		packer.close()
		var bytes := FileAccess.get_file_as_bytes(zip)
		for i in range(bytes.size() - 46):
			if bytes.decode_u32(i) == 0x02014b50:
				if tipo == "link":
					bytes.encode_u32(i + 38, 0xa1ff0000)
				elif tipo == "tamanho":
					bytes.encode_u32(i + 24, 2147483648)
				break
		if tipo == "cabecalho":
			bytes[30] = 46 # Nome local diferente do índice central.
		elif tipo == "prefixo":
			# Uma entrada não declarada antes dos registros que o índice enumera.
			var prefixo := PackedByteArray([0x50, 0x4b, 0x03, 0x04])
			for i in range(bytes.size() - 46):
				if bytes.decode_u32(i) == 0x02014b50:
					bytes.encode_u32(i + 42, bytes.decode_u32(i + 42) + prefixo.size())
			bytes.encode_u32(bytes.size() - 6, bytes.decode_u32(bytes.size() - 6) + prefixo.size())
			prefixo.append_array(bytes)
			bytes = prefixo
		var f := FileAccess.open(zip, FileAccess.WRITE)
		f.store_buffer(bytes)
		f.close()
		_conferir(not Atualizacao.extrair_zip(zip, base).is_empty(), "índice ZIP inseguro aceito: " + tipo)

func _saves() -> void:
	var saver := get_root().get_node("Salvamento")
	var base := ProjectSettings.globalize_path("user://seguranca_saves")
	DirAccess.make_dir_recursive_absolute(base)
	var script_path := base.path_join("marcador.gd")
	var marker := base.path_join("executou.txt")
	_gravar(script_path, "extends RefCounted\nfunc _init():\n\tvar f = FileAccess.open(%s, FileAccess.WRITE)\n\tf.store_string(\"inofensivo\")\n\tf.close()\n" % JSON.stringify(marker))
	var caminho := base.path_join("inseguro.save")
	_gravar(caminho, '{"versao": 2, "extra": Object(RefCounted, "script": Resource(%s))}' % JSON.stringify(script_path))
	_conferir(saver._ler_arquivo(caminho).is_empty(), "save com objeto foi aceito")
	_conferir(not FileAccess.file_exists(marker), "ler o save executou o script marcador")
	_gravar(caminho, '{"color": #ffffff, "extra": Object(RefCounted, "script": Resource(%s))}' % JSON.stringify(script_path))
	_conferir(saver._ler_arquivo(caminho).is_empty(), "cor hexadecimal escondeu código no save")
	_conferir(not FileAccess.file_exists(marker), "cor hexadecimal permitiu executar o marcador")
	var bom := {"versao": 2, "posicao": Vector3(1, 2, 3), "pequeno": 1e-20, "célula": {Vector2i(3, 4): Color(0.2, 0.4, 0.6)}, "texto": 'Object(Resource("não é código"))'}
	_gravar(caminho, var_to_str(bom))
	_conferir(saver._ler_arquivo(caminho) == bom, "save legítimo perdeu seus tipos ou texto")

func _gravar(caminho: String, texto: String) -> void:
	var arquivo := FileAccess.open(caminho, FileAccess.WRITE)
	arquivo.store_string(texto)
	arquivo.close()
