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
##   - o extra ser conferido só num dos cabeçalhos: o local e o central passam pelo mesmo crivo.
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
	var casos := {
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
	for rotulo in casos:
		var veredito := _veredito_de(casos[rotulo])
		_conferir(veredito == "", "%s foi recusado: %s" % [rotulo, veredito])


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
	var casos := {
		"o ZIP64 (0x0001)": "01000800" + "0000000000000000",
		"o nome Unicode alternativo (0x7075)": "75700600" + "01" + "11223344" + "61",
		"o link Unix do PKWARE (0x000d)": "0d000c00" + "000000000000000000000000",
		"o Unix antigo do Info-ZIP (0x5855)": "55580800" + "0000000000000000",
		"o Unix antigo do Info-ZIP sem dados (0x7855)": "55780000",
		"um id desconhecido (0xcafe)": "feca0000",
		"o id 0 sem dados": "00000000",
	}
	for rotulo in casos:
		var extra := _extra(casos[rotulo])
		# Cada um sozinho e ao lado de um extra bom: a companhia não o salva.
		for lado in ["central", "local"]:
			for acompanhado in [false, true]:
				var dado := (_extra(CARIMBO_CENTRAL) + extra) if acompanhado else extra
				var veredito := _veredito("", dado.hex_encode()) if lado == "central" else _veredito(dado.hex_encode(), "")
				var esperado := NAO_PERMITIDO if lado == "central" else LOCAL_NAO_CONFERE
				_conferir(veredito == esperado, "%s no cabeçalho %s%s não foi recusado como devia: '%s'" % [rotulo, lado, " (com um extra bom)" if acompanhado else "", veredito])


func test_extras_tortos_sao_recusados() -> void:
	var casos := {
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
	for rotulo in casos:
		var extra := _extra(casos[rotulo])
		var central := _veredito("", extra.hex_encode())
		var local := _veredito(extra.hex_encode(), "")
		_conferir(central == NAO_PERMITIDO, "%s no índice central não foi recusado como devia: '%s'" % [rotulo, central])
		_conferir(local == LOCAL_NAO_CONFERE, "%s no cabeçalho local não foi recusado como devia: '%s'" % [rotulo, local])


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


# --- o montador de zips --------------------------------------------------------------------------------------------

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
