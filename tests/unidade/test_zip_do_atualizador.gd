extends "res://tests/unidade/base.gd"
## O FORMATO DO ZIP QUE O ATUALIZADOR ACEITA (#231): os extras comuns de zip passam, cada um com a
## estrutura que o formato dele manda, e todo o resto continua recusado.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste zip_do_atualizador
##
## O que este portão impede:
##   - o atualizador recusar o zip que o próprio tar.exe do Windows faz. O zip da Build 11 saiu do
##     tar.exe com os extras 0x5455 (carimbos) e 0x7875 (uid/gid), e o `_extras_seguros` da 11 só
##     deixava passar 0x5455 e 0x000a: quem tinha a 11 baixaria 1,2 GB para ouvir "pacote com nome ou
##     conteúdo não permitido". A partir da 12 o 0x7875 passa;
##   - o extra aceito servir de brecha: um id conhecido com tamanho ou versão tortos é recusado, e o
##     que não está em EXTRAS_ACEITOS (ZIP64, nome Unicode alternativo, link Unix) também;
##   - o extra ser conferido só num dos cabeçalhos: o local e o central passam pelo mesmo crivo;
##   - o zip da build seguinte sair com extras que um atualizador já na mão dos jogadores recusa: o
##     script de fechamento (tools/prototipo_3d/zipar_build.py) zipa sem extras, e o conferidor dele,
##     que roda sem Godot e confere as builds anteriores (data/atualizador_builds.json), diz o mesmo que o
##     `Atualizacao.conferir_zip` de verdade. Os testes que chamam o Python ficam pendentes (e não
##     reprovam) numa máquina sem Python.
##
## Os zips daqui são montados byte a byte (o ZIPPacker do Godot não sabe gravar extras): um arquivo,
## MythsValley3D.exe, guardado sem compressão, sem ZIP64 e sem comentário.

const NOME_DO_EXE := "MythsValley3D.exe"
const NAO_PERMITIDO := "pacote com nome ou conteúdo não permitido"
const LOCAL_NAO_CONFERE := "caminho ou dados locais não conferem"

## Os 32 bytes de extras que o MythsValley3D.exe do zip da Build 11 (tar.exe) leva nos dois
## cabeçalhos, lidos do zip publicado: o carimbo 0x5455 (modificação, acesso e criação) e o dono
## 0x7875 (uid 0, gid 0).
const EXTRAS_DA_BUILD_11 := "55540d00071d14cb6a2f14cb6af113cb6a75780b000104000000000400000000"
## Carimbo do índice central: só a modificação.
const CARIMBO_CENTRAL := "55540500011d14cb6a"
const DONO := "75780b000104000000000400000000"
## Dono com uid e gid de 8 bytes: versão 1, tamanho 8 e 8 bytes, tamanho 8 e 8 bytes (19 no total).
const DONO_DE_8 := "75781300" + "01" + "08" + "0000000000000000" + "08" + "0000000000000000"
## NTFS: 4 reservados, atributo 1 de 24 bytes (três carimbos de 8).
const NTFS := "0a0020000000000001001800" + "00112233445566778899aabbccddeeff0011223344556677"

var Atualizacao: GDScript
var _pasta_dos_zips := ""


func before_all() -> void:
	super.before_all()
	# load() e não preload: o script tem de ser lido já com os autoloads de pé.
	Atualizacao = load("res://scripts/autoload/atualizacao.gd")


func before_each() -> void:
	super.before_each()
	_pasta_dos_zips = _pasta_limpa("fixtures")


func test_zip_sem_extras_passa() -> void:
	# O controle de todos os outros: sem extras o zip montado aqui passa. Se este falha, o resto não prova nada.
	_conferir(_veredito("", "") == "", "o zip sem extras foi recusado (%s): o montador do teste está errado" % _veredito("", ""))
	# E o montador não aceita tudo: sem o executável, ou com dois, o zip cai.
	var sem_exe := _zip_com("README.txt", "", "")
	_gravar_bytes(_caminho("sem_exe"), sem_exe)
	_conferir(Atualizacao.conferir_zip(_caminho("sem_exe")) != "", "um zip sem o MythsValley3D.exe foi aceito")


func test_extras_comuns_passam() -> void:
	var casos := _extras_que_passam()
	for rotulo in casos:
		var veredito := _veredito_de(casos[rotulo])
		_conferir(veredito == "", "%s foi recusado: %s" % [rotulo, veredito])


## Os extras que o atualizador aceita, [local, central] em bytes, pelo que cada um é.
func _extras_que_passam() -> Dictionary:
	return {
		"o carimbo 0x5455 sozinho": [_extra(EXTRAS_DA_BUILD_11.substr(0, 34)), _extra(CARIMBO_CENTRAL)],
		"o dono 0x7875 sozinho": [_extra(DONO), _extra(DONO)],
		"o NTFS 0x000a": [_extra(NTFS), _extra(NTFS)],
		"o carimbo e o dono do tar.exe (zip da Build 11)": [_extra(EXTRAS_DA_BUILD_11), _extra(EXTRAS_DA_BUILD_11)],
		"o carimbo do índice central só com a modificação": [_extra(EXTRAS_DA_BUILD_11), _extra(CARIMBO_CENTRAL + DONO)],
		"os três juntos": [_extra(EXTRAS_DA_BUILD_11 + NTFS), _extra(EXTRAS_DA_BUILD_11 + NTFS)],
		"o dono vazio no índice central": [_extra(DONO), _extra("75780000")],
		"o carimbo sem nenhum tempo": [_extra("5554010000"), _extra("5554010000")],
		"o dono de 8 bytes (uid e gid de 64 bits)": [_extra(DONO_DE_8), _extra(DONO_DE_8)],
		"o NTFS sem atributos": [_extra("0a000400" + "00000000"), _extra("0a000400" + "00000000")],
	}


## O defeito que a #231 achou, reproduzido com os bytes reais: o zip do tar.exe tem o 0x7875, e este
## é o motivo pelo qual a Build 11 o recusaria. Os ids lidos do fixture provam que ele é o do tar.
func test_o_zip_da_build_11_passa_na_regra_nova() -> void:
	var ids := _ids(_extra(EXTRAS_DA_BUILD_11))
	_conferir(ids == [0x5455, 0x7875], "o fixture da Build 11 não traz o 0x5455 + 0x7875 do tar.exe: %s" % str(ids))
	# O que a Build 11 aceitava (a regra congelada dela): só 0x5455 e 0x000a.
	var aceitos_pela_11 := [0x5455, 0x000a]
	var recusados_pela_11 := ids.filter(func(id: int) -> bool: return id not in aceitos_pela_11)
	_conferir(recusados_pela_11 == [0x7875], "a Build 11 não recusaria o 0x7875 do fixture: %s" % str(recusados_pela_11))
	_conferir(0x7875 in Atualizacao.EXTRAS_ACEITOS, "o 0x7875 do tar.exe não está em EXTRAS_ACEITOS")
	_conferir(_veredito_de([_extra(EXTRAS_DA_BUILD_11), _extra(EXTRAS_DA_BUILD_11)]) == "", "o zip com os extras do tar.exe foi recusado pela regra nova")
	# Tudo o que a Build 11 aceitava continua aceito: a regra nova não estreita.
	for id in aceitos_pela_11:
		_conferir(id in Atualizacao.EXTRAS_ACEITOS, "o extra 0x%04x que a Build 11 aceitava deixou de ser aceito" % id)


func test_extras_fora_da_lista_sao_recusados() -> void:
	var casos := _extras_fora_da_lista()
	for rotulo in casos:
		var extra := _extra(casos[rotulo])
		# Cada um sozinho e ao lado de um extra bom: a companhia não o salva.
		for lado in ["central", "local"]:
			for acompanhado in [false, true]:
				var dado := (_extra(CARIMBO_CENTRAL) + extra) if acompanhado else extra
				var veredito := _veredito("", dado.hex_encode()) if lado == "central" else _veredito(dado.hex_encode(), "")
				var esperado := NAO_PERMITIDO if lado == "central" else LOCAL_NAO_CONFERE
				_conferir(veredito == esperado, "%s no cabeçalho %s%s não foi recusado como devia: '%s'" % [rotulo, lado, " (com um extra bom)" if acompanhado else "", veredito])


## Os extras que nenhum atualizador aceita, em hexadecimal: o ZIP64, o nome Unicode alternativo, o link Unix.
func _extras_fora_da_lista() -> Dictionary:
	return {
		"o ZIP64 (0x0001)": "01000800" + "0000000000000000",
		"o nome Unicode alternativo (0x7075)": "75700600" + "01" + "11223344" + "61",
		"o link Unix do PKWARE (0x000d)": "0d000c00" + "000000000000000000000000",
		"o Unix antigo do Info-ZIP (0x5855)": "55580800" + "0000000000000000",
		"o Unix antigo do Info-ZIP sem dados (0x7855)": "55780000",
		"um id desconhecido (0xcafe)": "feca0000",
		"o id 0 sem dados": "00000000",
	}


func test_extras_tortos_sao_recusados() -> void:
	var casos := _extras_tortos()
	for rotulo in casos:
		var extra := _extra(casos[rotulo])
		var central := _veredito("", extra.hex_encode())
		var local := _veredito(extra.hex_encode(), "")
		_conferir(central == NAO_PERMITIDO, "%s no índice central não foi recusado como devia: '%s'" % [rotulo, central])
		_conferir(local == LOCAL_NAO_CONFERE, "%s no cabeçalho local não foi recusado como devia: '%s'" % [rotulo, local])


## Os extras de id conhecido com tamanho, versão ou forma tortos, em hexadecimal.
func _extras_tortos() -> Dictionary:
	return {
		# 0x5455: o byte de bits, e depois um inteiro de 4 bytes por carimbo.
		"o carimbo sem nenhum dado": "55540000",
		"o carimbo com um tempo pela metade": "55540300" + "07" + "1d14",
		"o carimbo com um byte a mais": "55540600" + "01" + "1d14cb6aff",
		"o carimbo com quatro tempos": "55541100" + "07" + "1d14cb6a" + "1d14cb6a" + "1d14cb6a" + "1d14cb6a",
		"o carimbo com bits reservados": "55540500" + "09" + "1d14cb6a",
		# 0x7875: versão 1, tamanho do uid, uid, tamanho do gid, gid.
		"o dono de versão 2": "75780b00" + "02" + "04" + "00000000" + "04" + "00000000",
		"o dono com uid de tamanho 0": "75780300" + "01" + "00" + "00",
		"o dono com uid de 9 bytes": "75781000" + "01" + "09" + "000000000000000000" + "04" + "00000000",
		"o dono com gid de tamanho 0": "75780700" + "01" + "04" + "00000000" + "00",
		"o dono cujo gid passa do que o campo tem": "75780a00" + "01" + "04" + "00000000" + "04" + "000000",
		"o dono com um byte a mais no fim": "75780c00" + "01" + "04" + "00000000" + "04" + "00000000" + "ff",
		"o dono só com a versão": "75780100" + "01",
		"o dono que acaba no tamanho do uid": "75780200" + "01" + "04",
		# 0x000a: 4 reservados e o atributo 1, de 24 bytes.
		"o NTFS com 3 bytes": "0a000300" + "000000",
		"o NTFS de outro atributo (etiqueta 2)": "0a002000" + "00000000" + "02001800" + "00112233445566778899aabbccddeeff0011223344556677",
		"o NTFS cujo atributo tem 16 bytes": "0a001800" + "00000000" + "01001000" + "00112233445566778899aabbccddeeff",
		"o NTFS com dois atributos": "0a003c00" + "00000000" + "01001800" + "00112233445566778899aabbccddeeff0011223344556677" + "01001800" + "00112233445566778899aabbccddeeff0011223344556677",
		# O invólucro do extra: cabeçalho pela metade, tamanho que passa do fim, repetido.
		"o cabeçalho do extra pela metade": "5554",
		"o tamanho que passa do que o extra tem": "55540d0007",
		"o mesmo id duas vezes": CARIMBO_CENTRAL + CARIMBO_CENTRAL,
		"lixo depois de um extra bom": CARIMBO_CENTRAL + "ff",
	}


## O extra bom num cabeçalho só não basta: os dois são conferidos, e um extra ruim em qualquer um recusa o zip.
func test_local_e_central_passam_pelo_mesmo_crivo() -> void:
	_conferir(_veredito(EXTRAS_DA_BUILD_11, "") == "", "o extra bom só no cabeçalho local foi recusado")
	_conferir(_veredito("", EXTRAS_DA_BUILD_11) == "", "o extra bom só no índice central foi recusado")
	var ruim := "010008000000000000000000"
	_conferir(_veredito(EXTRAS_DA_BUILD_11, ruim) == NAO_PERMITIDO, "o extra ruim só no índice central passou")
	_conferir(_veredito(ruim, EXTRAS_DA_BUILD_11) == LOCAL_NAO_CONFERE, "o extra ruim só no cabeçalho local passou")


## O que passa na conferência tem de extrair: o tar.exe (ou o ZIPReader, fora do Windows) lê o zip
## com os extras do tar.exe e entrega o executável inteiro. A conferência sozinha não prova isso.
func test_o_zip_com_extras_do_tar_extrai() -> void:
	var pasta := _pasta_limpa("extrai")
	var zip := pasta.path_join("build.zip")
	_gravar_bytes(zip, _zip_com(NOME_DO_EXE, EXTRAS_DA_BUILD_11, EXTRAS_DA_BUILD_11))
	_conferir(Atualizacao.conferir_zip(zip) == "", "o zip com os extras do tar.exe não passou na conferência: %s" % Atualizacao.conferir_zip(zip))
	var destino := pasta.path_join("saida")
	DirAccess.make_dir_recursive_absolute(destino)
	var falha: String = Atualizacao.extrair_zip(zip, destino)
	_conferir(falha == "", "o zip com os extras do tar.exe não extraiu: %s" % falha)
	var achado: String = Atualizacao.achar_executavel(destino, NOME_DO_EXE)
	_conferir(not achado.is_empty() and FileAccess.get_file_as_string(achado) == "build 12", "o executável extraído não é o do zip")


# --- o registro, o código e o script de fechamento ----------------------------------------------------------------------

## O registro de builds (data/atualizador_builds.json) guarda, de cada build, os extras que o atualizador dela aceita: é
## com eles que o fechamento confere o zip novo contra quem já está na mão dos jogadores (quem tem a build N baixa a mais
## nova publicada e a confere com a regra da N).
func test_o_registro_guarda_os_extras_de_cada_build() -> void:
	var registro = JSON.parse_string(FileAccess.get_file_as_string("res://data/atualizador_builds.json"))
	_conferir(registro is Dictionary and (registro as Dictionary).get("builds") is Dictionary, "data/atualizador_builds.json não abriu")
	if not (registro is Dictionary and (registro as Dictionary).get("builds") is Dictionary):
		return
	var builds: Dictionary = registro["builds"]
	for numero in builds:
		var extras = (builds[numero] as Dictionary).get("extras_aceitos")
		_conferir(extras is Array and not (extras as Array).is_empty(), "a Build %s não diz os extras que o atualizador dela aceita (extras_aceitos)" % numero)
		if extras is Array:
			for id in extras:
				_conferir(str(id).length() == 6 and str(id).begins_with("0x") and str(id).substr(2).is_valid_hex_number(), "extras_aceitos da Build %s tem '%s', que não é um id de 16 bits como 0x5455" % [numero, str(id)])
	# A regra congelada da Build 11 (a que recusa o 0x7875): é por ela que o zip da 12 tem de sair sem extras.
	if builds.has("11"):
		_conferir((builds["11"].get("extras_aceitos", []) as Array) == ["0x5455", "0x000a"], "o registro da Build 11 não diz mais que ela aceita só 0x5455 e 0x000a")


## O fechamento lê o EXTRAS_ACEITOS do código (o ps1, para gravar no registro; o Python, para a regra desta árvore): a
## linha tem de ter a forma que os dois leem, e dizer o mesmo que a constante.
func test_extras_aceitos_tem_a_forma_que_o_fechamento_le() -> void:
	var codigo := FileAccess.get_file_as_string("res://scripts/autoload/atualizacao.gd")
	var padrao := RegEx.new()
	padrao.compile("(?m)^const EXTRAS_ACEITOS := \\[([0-9a-fA-Fx, ]+)\\]\\s*$")
	var achou := padrao.search(codigo)
	_conferir(achou != null, "a linha 'const EXTRAS_ACEITOS := [0x...]' de atualizacao.gd não tem a forma que conferir_fechamento_de_build.ps1 e zipar_build.py leem")
	if achou == null:
		return
	var ids := []
	for parte in achou.get_string(1).split(","):
		if not parte.strip_edges().is_empty():
			ids.append(parte.strip_edges().hex_to_int())
	_conferir(ids == Atualizacao.EXTRAS_ACEITOS and not ids.is_empty(), "os ids lidos da linha de EXTRAS_ACEITOS (%s) não são os da constante (%s)" % [str(ids), str(Atualizacao.EXTRAS_ACEITOS)])


## O conferidor que o fechamento roda num Godot sem janela (conferir_zip_do_atualizador.gd) compila: um erro de script ali
## não derruba nada, só deixa o ps1 sem resposta na hora de fechar a build.
func test_o_conferidor_de_verdade_compila() -> void:
	var conferidor = load("res://tools/prototipo_3d/conferir_zip_do_atualizador.gd")
	_conferir(conferidor is GDScript and (conferidor as GDScript).can_instantiate(), "tools/prototipo_3d/conferir_zip_do_atualizador.gd não compila")


## A cópia da regra em Python (tools/prototipo_3d/zipar_build.py), que o fechamento usa para conferir as builds anteriores
## sem Godot, diz o mesmo que o `Atualizacao.conferir_zip` de verdade sobre os mesmos zips: os extras que passam, os que
## caem, os tortos e alguns defeitos de estrutura. E, com a regra avulsa da Build 11, recusa todo zip com extra fora de
## 0x5455 e 0x000a: o que a 11 recusaria.
func test_a_copia_em_python_concorda_com_o_atualizador() -> void:
	var python := _achar_python()
	if python.is_empty():
		pending("sem python no PATH: a cópia da regra em tools/prototipo_3d/zipar_build.py não foi comparada com o atualizador")
		return
	var script := ProjectSettings.globalize_path("res://tools/prototipo_3d/zipar_build.py")
	var casos: Array = []
	var passam := _extras_que_passam()
	for rotulo in passam:
		casos.append(_caso(casos.size(), rotulo, NOME_DO_EXE, (passam[rotulo][0] as PackedByteArray).hex_encode(), (passam[rotulo][1] as PackedByteArray).hex_encode()))
	for tabela in [_extras_fora_da_lista(), _extras_tortos()]:
		for rotulo in tabela:
			casos.append(_caso(casos.size(), rotulo + " (cabeçalho local)", NOME_DO_EXE, tabela[rotulo], ""))
			casos.append(_caso(casos.size(), rotulo + " (índice central)", NOME_DO_EXE, "", tabela[rotulo]))
	# A estrutura além dos extras: o que o atualizador exige do pacote.
	casos.append(_caso(casos.size(), "só um README, sem o executável", "README.txt", "", ""))
	casos.append(_caso(casos.size(), "um arquivo que o pacote não pode ter", "evil.dll", "", ""))
	casos.append(_caso(casos.size(), "um caminho que sai da pasta", "../MythsValley3D.exe", "", ""))
	casos.append(_caso(casos.size(), "o executável dentro de MythsValley3D/", "MythsValley3D/MythsValley3D.exe", "", ""))
	casos.append(_caso(casos.size(), "um nome reservado do Windows", "MythsValley3D/CON.txt", "", ""))
	var do_godot := _caminho("godot_dois_arquivos")
	_zip_do_godot(do_godot, {NOME_DO_EXE: "build 12", "README.txt": "leia"})
	casos.append({"rotulo": "o zip do ZIPPacker com o executável e um README", "caminho": do_godot, "fora_da_11": false})
	var do_godot_ruim := _caminho("godot_dois_executaveis")
	_zip_do_godot(do_godot_ruim, {NOME_DO_EXE: "build 12", "MythsValley3D/MythsValley3D.exe": "outro"})
	casos.append({"rotulo": "o zip do ZIPPacker com dois executáveis", "caminho": do_godot_ruim, "fora_da_11": false})

	var caminhos := PackedStringArray()
	for caso in casos:
		caminhos.append(caso["caminho"])
	var da_arvore := _veredito_do_python(python, script, caminhos, "")
	var da_11 := _veredito_do_python(python, script, caminhos, "0x5455,0x000a")
	_conferir(da_arvore.size() == casos.size() and da_11.size() == casos.size(), "o zipar_build.py devolveu %d e %d vereditos para %d zips" % [da_arvore.size(), da_11.size(), casos.size()])
	if da_arvore.size() != casos.size() or da_11.size() != casos.size():
		return
	var aceitos := 0
	var recusados_so_pela_11 := 0
	for k in casos.size():
		var caso: Dictionary = casos[k]
		var recusa_godot: bool = Atualizacao.conferir_zip(caso["caminho"]) != ""
		_conferir(da_arvore[k].begins_with("RECUSADO") == recusa_godot, "o Python e o atualizador discordam sobre '%s': Python '%s', atualizador '%s'" % [caso["rotulo"], da_arvore[k], Atualizacao.conferir_zip(caso["caminho"])])
		# A Build 11 recusa tudo o que o código atual recusa e mais o que traz extra fora de 0x5455 e 0x000a.
		var recusa_11: bool = recusa_godot or bool(caso["fora_da_11"])
		_conferir(da_11[k].begins_with("RECUSADO") == recusa_11, "o Python diz '%s' sobre '%s' para a regra da Build 11, e devia recusar: %s" % [da_11[k], caso["rotulo"], recusa_11])
		aceitos += 0 if recusa_godot else 1
		recusados_so_pela_11 += 1 if (recusa_11 and not recusa_godot) else 0
	# Sem isto o teste poderia passar com tudo aceito (ou tudo recusado) dos dois lados.
	_conferir(aceitos >= 10 and casos.size() - aceitos >= 40, "os zips do teste não variam o bastante: %d aceitos de %d" % [aceitos, casos.size()])
	_conferir(recusados_so_pela_11 >= 5, "poucos zips que só a Build 11 recusa (%d): o 0x7875 do tar.exe tem de estar entre eles" % recusados_so_pela_11)


## O zip que o script de fechamento faz passa no atualizador, sai SEM extras e no formato das Builds 8 a 10, extrai com o
## tar.exe; o que o script recusa não vira zip; e o zip do tar.exe (a Build 11) é o que o fechamento reprova, com o motivo.
func test_o_script_de_fechamento_zipa_sem_extras_e_reprova_o_zip_do_tar() -> void:
	var python := _achar_python()
	if python.is_empty():
		pending("sem python no PATH: tools/prototipo_3d/zipar_build.py não foi exercitado")
		return
	var script := ProjectSettings.globalize_path("res://tools/prototipo_3d/zipar_build.py")
	var raiz := _pasta_limpa("fechamento")
	var pasta := raiz.path_join("windows")
	DirAccess.make_dir_recursive_absolute(pasta)
	# Um "executável" de uns 2 MB: metade aleatória (não comprime) e metade repetitiva (comprime).
	var exe_bytes := Crypto.new().generate_random_bytes(1 << 20)
	exe_bytes.append_array("abc".repeat(350000).to_utf8_buffer())
	_gravar_bytes(pasta.path_join(NOME_DO_EXE), exe_bytes)

	# 1. O zip do script.
	var zip := raiz.path_join("MythsValley3D-v0.12.0-build12-windows.zip")
	var saida: Array = []
	var codigo := OS.execute(python, ["-I", script, pasta, zip, "--build", "12"], saida, true)
	var texto := "\n".join(saida)
	_conferir(codigo == 0, "o zipar_build.py saiu com %d em vez de 0: %s" % [codigo, texto])
	_conferir(FileAccess.file_exists(zip) and not FileAccess.file_exists(zip + ".parcial"), "o zip não está no destino, ou sobrou o .parcial")
	_conferir(Atualizacao.conferir_zip(zip) == "", "o zip do script foi recusado pelo atualizador: %s" % Atualizacao.conferir_zip(zip))
	var bytes := FileAccess.get_file_as_bytes(zip)
	var fim := bytes.size() - 22
	_conferir(fim > 0 and bytes.decode_u32(fim) == 0x06054b50 and bytes.decode_u16(fim + 20) == 0, "o zip do script tem comentário, ou o fim do índice não está onde devia")
	var indice := bytes.decode_u32(fim + 16)
	_conferir(bytes.decode_u16(fim + 10) == 1 and bytes.decode_u32(indice) == 0x02014b50, "o zip do script não tem uma só entrada")
	_conferir(bytes.decode_u16(indice + 4) >> 8 == 0 and bytes.decode_u16(indice + 8) == 0 and bytes.decode_u16(indice + 10) == 8, "o zip do script não é o das Builds 8 a 10 (feito no Windows, sem descritor, deflate)")
	_conferir(bytes.decode_u16(indice + 30) == 0 and bytes.decode_u16(indice + 32) == 0 and bytes.decode_u16(28) == 0 and bytes.decode_u16(6) == 0, "o zip do script saiu COM extras ou comentário: a Build 11 o recusaria")
	_conferir(bytes.decode_u32(indice + 24) == exe_bytes.size() and bytes.decode_u32(indice + 20) < exe_bytes.size(), "o zip do script não comprimiu o executável")
	var destino := raiz.path_join("saida")
	DirAccess.make_dir_recursive_absolute(destino)
	var falha: String = Atualizacao.extrair_zip(zip, destino)
	_conferir(falha == "", "o zip do script não extraiu: %s" % falha)
	var achado: String = Atualizacao.achar_executavel(destino, NOME_DO_EXE)
	_conferir(not achado.is_empty() and FileAccess.get_file_as_bytes(achado) == exe_bytes, "o executável extraído do zip do script não é igual ao original")
	# E o fechamento aprova o zip do script contra todas as builds anteriores.
	var saida_conferir: Array = []
	var codigo_conferir := OS.execute(python, ["-I", script, "--conferir", zip, "--build", "12"], saida_conferir, true)
	_conferir(codigo_conferir == 0, "o --conferir reprovou o zip do próprio script (saída %d): %s" % [codigo_conferir, "\n".join(saida_conferir)])

	# 2. Pasta com o que o atualizador não aceita no zip: o script diz qual é e não deixa zip.
	var com_lixo := raiz.path_join("com_lixo")
	DirAccess.make_dir_recursive_absolute(com_lixo)
	_gravar_bytes(com_lixo.path_join(NOME_DO_EXE), exe_bytes)
	_gravar_bytes(com_lixo.path_join("lixo.dll"), PackedByteArray([1, 2, 3]))
	var zip_lixo := raiz.path_join("com_lixo.zip")
	var saida_lixo: Array = []
	var codigo_lixo := OS.execute(python, ["-I", script, com_lixo, zip_lixo, "--build", "12"], saida_lixo, true)
	_conferir(codigo_lixo == 2 and "lixo.dll" in "\n".join(saida_lixo) and not FileAccess.file_exists(zip_lixo), "o script zipou (ou não nomeou) a pasta com lixo.dll: saída %d, %s" % [codigo_lixo, "\n".join(saida_lixo)])
	var vazia := raiz.path_join("vazia")
	DirAccess.make_dir_recursive_absolute(vazia)
	var saida_vazia: Array = []
	var codigo_vazio := OS.execute(python, ["-I", script, vazia, raiz.path_join("vazia.zip"), "--build", "12"], saida_vazia, true)
	_conferir(codigo_vazio == 2 and not FileAccess.file_exists(raiz.path_join("vazia.zip")), "o script zipou a pasta sem o executável (saída %d)" % codigo_vazio)

	# 3. O zip do tar.exe, com os extras da Build 11: o fechamento o reprova, e o motivo é a regra da Build 11.
	var do_tar := raiz.path_join("do_tar.zip")
	_gravar_bytes(do_tar, _zip_com(NOME_DO_EXE, EXTRAS_DA_BUILD_11, EXTRAS_DA_BUILD_11))
	var saida_tar: Array = []
	var codigo_tar := OS.execute(python, ["-I", script, "--conferir", do_tar, "--build", "12"], saida_tar, true)
	var texto_tar := "\n".join(saida_tar)
	_conferir(codigo_tar == 1, "o --conferir não reprovou o zip do tar.exe (saída %d): %s" % [codigo_tar, texto_tar])
	_conferir("Atualizador da Build 11 (extras 0x5455, 0x000a): RECUSADO" in texto_tar and "0x7875" in texto_tar, "o --conferir não disse que a Build 11 recusa o 0x7875: %s" % texto_tar)
	_conferir("0x7875, 0x000a): OK" in texto_tar, "o --conferir não disse que o código desta árvore aceita o zip do tar.exe: %s" % texto_tar)


# --- o montador de zips --------------------------------------------------------------------------------------------

## O python do PATH (o atalho da Microsoft Store, em WindowsApps, é um arquivo vazio e não conta). "" se não há.
func _achar_python() -> String:
	var windows := OS.get_name() == "Windows"
	var nomes := ["python.exe", "python3.exe"] if windows else ["python3", "python"]
	for pasta in OS.get_environment("PATH").split(";" if windows else ":", false):
		if "WindowsApps" in pasta:
			continue
		for nome in nomes:
			var caminho: String = pasta.path_join(nome)
			if FileAccess.file_exists(caminho):
				return caminho
	return ""


## O que o zipar_build.py diz de cada zip, na ordem, contra o código desta árvore ou (com `extras`) contra uma regra avulsa.
func _veredito_do_python(python: String, script: String, zips: PackedStringArray, extras: String) -> Array:
	var argumentos := PackedStringArray(["-I", script, "--veredito"])
	if not extras.is_empty():
		argumentos.append_array(PackedStringArray(["--extras", extras]))
	argumentos.append_array(zips)
	var saida: Array = []
	var codigo := OS.execute(python, argumentos, saida, true)
	var linhas := []
	for linha in "\n".join(saida).split("\n", false):
		if linha.begins_with("OK") or linha.begins_with("RECUSADO"):
			linhas.append(linha.strip_edges())
	_conferir(codigo in [0, 1], "o zipar_build.py --veredito saiu com %d: %s" % [codigo, "\n".join(saida).left(300)])
	return linhas


## Grava um zip de um arquivo só e o descreve: o `fora_da_11` diz se algum extra dele é de um id que a Build 11 não aceita.
func _caso(numero: int, rotulo: String, nome: String, extra_local_hex: String, extra_central_hex: String) -> Dictionary:
	var caminho := _caminho("caso_%d" % numero)
	_gravar_bytes(caminho, _zip_com(nome, extra_local_hex, extra_central_hex))
	var fora := false
	for id in _ids(_extra(extra_local_hex)) + _ids(_extra(extra_central_hex)):
		fora = fora or id not in [0x5455, 0x000a]
	return {"rotulo": rotulo, "caminho": caminho, "fora_da_11": fora}


## Um zip feito pelo ZIPPacker do Godot: {nome: texto}.
func _zip_do_godot(destino: String, arquivos: Dictionary) -> void:
	var empacotador := ZIPPacker.new()
	empacotador.open(destino)
	for nome in arquivos:
		empacotador.start_file(nome)
		empacotador.write_file(str(arquivos[nome]).to_utf8_buffer())
		empacotador.close_file()
	empacotador.close()


## O veredito de `conferir_zip` para um zip com esses extras (em hexadecimal) nos dois cabeçalhos.
func _veredito(extra_local_hex: String, extra_central_hex: String) -> String:
	var caminho := _caminho("fixture")
	_gravar_bytes(caminho, _zip_com(NOME_DO_EXE, extra_local_hex, extra_central_hex))
	return Atualizacao.conferir_zip(caminho)


## Como `_veredito`, com os extras já em bytes: [local, central].
func _veredito_de(extras: Array) -> String:
	return _veredito((extras[0] as PackedByteArray).hex_encode(), (extras[1] as PackedByteArray).hex_encode())


## Um zip de um arquivo só, `nome`, guardado sem compressão, com os extras pedidos (hexadecimal) nos
## cabeçalhos local e central. Sem ZIP64, sem comentário, sem descritor: o formato que o atualizador confere.
func _zip_com(nome: String, extra_local_hex: String, extra_central_hex: String) -> PackedByteArray:
	var conteudo := "build 12".to_utf8_buffer()
	var nome_bytes := nome.to_utf8_buffer()
	var extra_local := _extra(extra_local_hex)
	var extra_central := _extra(extra_central_hex)
	var crc := _crc32(conteudo)
	var b := StreamPeerBuffer.new()
	# Cabeçalho local.
	b.put_u32(0x04034b50)
	b.put_u16(20)
	b.put_u16(0)
	b.put_u16(0)
	b.put_u16(0)
	b.put_u16(0x0021)
	b.put_u32(crc)
	b.put_u32(conteudo.size())
	b.put_u32(conteudo.size())
	b.put_u16(nome_bytes.size())
	b.put_u16(extra_local.size())
	b.put_data(nome_bytes)
	b.put_data(extra_local)
	b.put_data(conteudo)
	var indice := b.get_size()
	# Índice central.
	b.put_u32(0x02014b50)
	b.put_u16(20)
	b.put_u16(20)
	b.put_u16(0)
	b.put_u16(0)
	b.put_u16(0)
	b.put_u16(0x0021)
	b.put_u32(crc)
	b.put_u32(conteudo.size())
	b.put_u32(conteudo.size())
	b.put_u16(nome_bytes.size())
	b.put_u16(extra_central.size())
	b.put_u16(0)
	b.put_u16(0)
	b.put_u16(0)
	b.put_u32(0x81a40000)
	b.put_u32(0)
	b.put_data(nome_bytes)
	b.put_data(extra_central)
	var tamanho_indice := b.get_size() - indice
	# Fim do índice.
	b.put_u32(0x06054b50)
	b.put_u16(0)
	b.put_u16(0)
	b.put_u16(1)
	b.put_u16(1)
	b.put_u32(tamanho_indice)
	b.put_u32(indice)
	b.put_u16(0)
	return b.data_array


func _extra(hex: String) -> PackedByteArray:
	return hex.hex_decode()


## Os ids dos extras de um bloco, na ordem.
func _ids(extra: PackedByteArray) -> Array:
	var ids := []
	var i := 0
	while i + 4 <= extra.size():
		ids.append(extra.decode_u16(i))
		i += 4 + extra.decode_u16(i + 2)
	return ids


static func _crc32(dados: PackedByteArray) -> int:
	var crc := 0xffffffff
	for octeto in dados:
		crc ^= octeto
		for _i in 8:
			crc = (crc >> 1) ^ (0xedb88320 if (crc & 1) == 1 else 0)
	return crc ^ 0xffffffff


## Onde os zips de cada conferência caem: uma pasta limpa por teste (o `before_each` a zera).
func _caminho(nome: String) -> String:
	return _pasta_dos_zips.path_join(nome + ".zip")


func _pasta_limpa(nome: String) -> String:
	var pasta := ProjectSettings.globalize_path("user://teste_zip_do_atualizador").path_join(nome)
	Atualizacao._apagar_pasta(pasta)
	DirAccess.make_dir_recursive_absolute(pasta)
	return pasta


func _gravar_bytes(caminho: String, dados: PackedByteArray) -> void:
	var arquivo := FileAccess.open(caminho, FileAccess.WRITE)
	arquivo.store_buffer(dados)
	arquivo.close()
