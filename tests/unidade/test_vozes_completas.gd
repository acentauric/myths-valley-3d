extends "res://tests/unidade/base.gd"
## AS VOZES DO VALE ESTÃO LIGADAS: cada campo de áudio dos dados aponta para um mp3 que existe e importa, nenhum
## mp3 fica sem uso, e a voz de cada fala diz o texto que o jogador lê.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste vozes_completas
##
## O jogo não toca o que não está escrito: a voz de uma fala mora num campo de áudio ao lado do texto dela
## (`audio` e `texto`, `audio_resposta` e `resposta`, `trancada_audio` e `trancada`, `audio_oferta` e `oferta`,
## `audio_pergunta` e `pergunta`), com o nome de assets/audio/vozes/<nome>.mp3. Voz que não está num campo é
## arquivo que ninguém toca; campo que aponta para arquivo que não existe é fala muda, e nada avisa. Três
## perguntas, que valem para o lote de 15/10/2026 (#248, #59 e #210) e para todo lote que vier:
##
##   1. TODO CAMPO DE ÁUDIO APONTA PARA UM MP3 QUE EXISTE: o arquivo, o `.import` (que se commita junto, com o uid) e
##      o recurso que o Godot carrega.
##   2. NENHUM MP3 FICA SEM USO. Um mp3 gerado e não ligado é crédito gasto para nada. As sobras que já existiam estão
##      declaradas em `SEM_USO_DECLARADO`, com a razão; a lista só encolhe (o teste reprova a que passou a ter uso).
##   3. A VOZ DIZ O QUE O BALÃO ESCREVE (#210). `docs/falas/audios_gravados.json` guarda o texto de cada voz no dia em
##      que foi gerada; o texto de hoje tem de ser o mesmo. Mudou o texto de uma fala com voz: gere a voz de novo e
##      fotografe o texto (`node tools/falas/gerar_documento_das_falas.js --fotografar-audios`), ou tire o `audio` da
##      fala até a voz nova chegar. Sem isto a voz antiga toca com o texto novo na legenda.
##
## O teste se falsifica sozinho (`test_os_detectores_reprovam_o_que_devem`): cada pergunta é um detector que roda
## aqui também sobre dados estragados de propósito, e tem de achar o defeito.

const PASTA := "res://assets/audio/vozes/"
const DADOS := "res://data"
const REGISTRO := "res://docs/falas/audios_gravados.json"
## Campo de áudio → o campo do texto que ele diz, no mesmo objeto.
const PARES := {
	"audio": "texto",
	"audio_resposta": "resposta",
	"trancada_audio": "trancada",
	"audio_oferta": "oferta",
	"audio_pergunta": "pergunta",
}
## O escopo da pergunta 3: as falas dos moradores e das missões (o viajante, as dicas e as broncas têm os portões
## deles). O registro guarda o texto da gravação por arquivo.
const ESCOPO_DO_REGISTRO_ARQUIVO := "res://data/npcs_3d.json"
const ESCOPO_DO_REGISTRO_PREFIXO := "res://data/missoes_"

## Os mp3 que nenhum campo de áudio usa, e por quê. Só encolhe: o que ganhar uso, ou for apagado, sai daqui.
const SEM_USO_DECLARADO := {
	"pedro_pier": "passo antigo da chegada: a fala nova, a do Pedro que conduz, o substituiu (docs/falas/README.md, 'O áudio além das correções')",
	"pedro_praca": "passo antigo da chegada: a fala nova, a do Pedro que conduz, o substituiu (docs/falas/README.md, 'O áudio além das correções')",
	"pedro_capela": "passo antigo da chegada (docs/falas/README.md, 'O áudio além das correções')",
	"pedro_casa_pasto": "passo antigo da chegada (docs/falas/README.md, 'O áudio além das correções')",
	"pedro_arraial_mirante_material": "diz 'vinte tábuas, doze pedras e seis cordas', e a obra pede 8, 4 e 2 desde 10/10 (0241ea3): o texto do passo foi corrigido e o passo ficou sem voz até uma tomada nova; quando ela chegar, o `audio` volta ao passo mirante_material",
}

var _campos: Array = []


func before_all() -> void:
	super.before_all()
	_campos = _campos_de_audio()


# --- as três perguntas ---------------------------------------------------------------------------------

func test_todo_audio_declarado_aponta_para_um_arquivo_que_existe() -> void:
	# Com o lote todo passam de 600; abaixo de 300 a varredura não está pegando os dados.
	conferir(_campos.size() >= 300, "só %d campo(s) de áudio nos dados: a varredura não está pegando" % _campos.size())
	var ruins := _sem_arquivo(_campos)
	conferir(ruins.is_empty(), "%d campo(s) de áudio sem mp3, sem .import ou que o Godot não carrega: %s" % [ruins.size(), "; ".join(ruins.slice(0, 6))])


func test_nenhum_mp3_fica_sem_uso() -> void:
	var arquivos := PackedStringArray()
	for arquivo in DirAccess.get_files_at(PASTA):
		if arquivo.ends_with(".mp3"):
			arquivos.append(arquivo.get_basename())
	conferir(arquivos.size() >= 300, "só %d mp3 em %s: a varredura não está pegando" % [arquivos.size(), PASTA])
	var sobras := _sobras(_campos, arquivos, SEM_USO_DECLARADO)
	conferir(sobras.is_empty(), "%d mp3 em assets/audio/vozes que nenhum campo de áudio usa (ligue no dado, ou apague, ou declare em SEM_USO_DECLARADO): %s" % [sobras.size(), "; ".join(sobras.slice(0, 8))])
	var usados := _nomes_usados(_campos)
	for nome in SEM_USO_DECLARADO:
		conferir(arquivos.has(nome), "'%s' foi apagado: tire de SEM_USO_DECLARADO" % nome)
		conferir(not usados.has(nome), "'%s' agora tem uso: tire de SEM_USO_DECLARADO" % nome)


func test_a_voz_diz_o_texto_que_o_jogador_le() -> void:
	var gravados := _registro()
	conferir(not gravados.is_empty(), "docs/falas/audios_gravados.json não abre ou está vazio")
	var ruins := _textos_que_mudaram(_campos, gravados)
	conferir(ruins.is_empty(), "%d voz(es) com o texto gravado diferente do que o jogador lê (regere a voz e fotografe o texto, ou tire o `audio`): %s" % [ruins.size(), "; ".join(ruins.slice(0, 5))])


## FALSIFICAÇÃO: os três detectores sobre dados estragados de propósito.
func test_os_detectores_reprovam_o_que_devem() -> void:
	# 1. um campo que aponta para um mp3 que não existe.
	var falso: Array = _campos.duplicate()
	falso.append({"onde": "falso.audio", "arquivo": "falso", "audio": "nao_existe_mesmo", "texto": "x"})
	conferir(_sem_arquivo(falso).size() == _sem_arquivo(_campos).size() + 1, "o detector de arquivo não achou o áudio que não existe")
	# 2. um mp3 novo que nenhum campo usa, e uma declaração que passou a ter uso.
	var arquivos := PackedStringArray(["um_mp3_novo_sem_uso", "benedito_fala_1"])
	conferir(_sobras(_campos, arquivos, {}) == ["um_mp3_novo_sem_uso"], "o detector de sobras não achou o mp3 sem uso (ou achou a mais): %s" % str(_sobras(_campos, arquivos, {})))
	conferir(_sobras(_campos, PackedStringArray(["um_mp3_novo_sem_uso"]), {"um_mp3_novo_sem_uso": "razão"}).is_empty(), "a sobra declarada não devia reprovar")
	# 3. uma letra a mais no texto de uma fala com voz.
	var gravados := _registro()
	var mexido: Array = []
	for campo in _campos:
		var c: Dictionary = (campo as Dictionary).duplicate()
		if _no_escopo(str(c["arquivo"])) and c["texto"] != null and gravados.has("assets/audio/vozes/%s.mp3" % c["audio"]):
			c["texto"] = str(c["texto"]) + "s"
			mexido.append(c)
			break
	conferir(mexido.size() == 1 and _textos_que_mudaram(mexido, gravados).size() == 1, "o detector de texto não achou a fala que mudou depois da voz")
	var sem_foto: Array = [{"onde": "falso.audio", "arquivo": ESCOPO_DO_REGISTRO_ARQUIVO, "audio": "voz_sem_foto_do_texto", "texto": "x"}]
	conferir(_textos_que_mudaram(sem_foto, gravados).size() == 1, "o detector de texto não achou a voz sem o texto guardado no registro")


# --- os detectores -------------------------------------------------------------------------------------

## Os campos de áudio que não têm mp3, nem `.import`, nem recurso que o Godot carregue.
func _sem_arquivo(campos: Array) -> Array:
	var ruins: Array = []
	for campo in campos:
		var caminho := PASTA + str(campo["audio"]) + ".mp3"
		if not FileAccess.file_exists(caminho):
			ruins.append("%s aponta '%s', que não existe" % [campo["onde"], campo["audio"]])
		elif not FileAccess.file_exists(caminho + ".import"):
			ruins.append("%s: '%s' não tem o .import (abra o projeto no Godot, ou rode o testar.ps1, e commite o .import)" % [campo["onde"], campo["audio"]])
		elif not ResourceLoader.exists(caminho):
			ruins.append("%s: o Godot não importou '%s'" % [campo["onde"], campo["audio"]])
	return ruins


## Os mp3 da pasta que nenhum campo usa e que ninguém declarou.
func _sobras(campos: Array, arquivos: PackedStringArray, declaradas: Dictionary) -> Array:
	var usados := _nomes_usados(campos)
	var sobras: Array = []
	for nome in arquivos:
		if not usados.has(nome) and not declaradas.has(nome):
			sobras.append(nome)
	return sobras


## As falas com voz, no escopo do registro, cujo texto de hoje não é o da gravação (ou que o registro não conhece).
func _textos_que_mudaram(campos: Array, gravados: Dictionary) -> Array:
	var ruins: Array = []
	for campo in campos:
		if not _no_escopo(str(campo["arquivo"])) or campo["texto"] == null:
			continue
		var entrada = gravados.get("assets/audio/vozes/%s.mp3" % campo["audio"])
		if not (entrada is Dictionary):
			ruins.append("%s: '%s' não tem o texto gravado no registro" % [campo["onde"], campo["audio"]])
		elif str(entrada.get("hash", "")) != _hash(str(campo["texto"])):
			ruins.append("%s: a voz '%s' foi gerada com outro texto" % [campo["onde"], campo["audio"]])
	return ruins


func _nomes_usados(campos: Array) -> Dictionary:
	var usados := {}
	for campo in campos:
		usados[str(campo["audio"])] = true
	return usados


func _no_escopo(arquivo: String) -> bool:
	return arquivo == ESCOPO_DO_REGISTRO_ARQUIVO or arquivo.begins_with(ESCOPO_DO_REGISTRO_PREFIXO)


## O mesmo hash do gerador do documento das falas (tools/falas/gerar_documento_das_falas.js): sha1 do texto sem as
## pontas, dez primeiros caracteres.
static func _hash(texto: String) -> String:
	return texto.strip_edges().sha1_text().substr(0, 10)


func _registro() -> Dictionary:
	var lido = JSON.parse_string(FileAccess.get_file_as_string(REGISTRO))
	if lido is Dictionary and (lido as Dictionary).get("audios") is Dictionary:
		return (lido as Dictionary)["audios"]
	return {}


# --- a varredura dos dados ----------------------------------------------------------------------------

## Todo campo de áudio de data/**/*.json: [{onde, arquivo, audio, texto}]. O valor é o nome do mp3 (ou o caminho
## completo em assets/audio/vozes/, como as broncas do coveiro); caminho de outra pasta não é voz e fica de fora.
func _campos_de_audio() -> Array:
	var saida: Array = []
	for arquivo in _arquivos_json(DADOS):
		var dados = JSON.parse_string(FileAccess.get_file_as_string(arquivo))
		_varrer(dados, arquivo, arquivo.trim_prefix(DADOS + "/"), saida)
	return saida


func _arquivos_json(pasta: String) -> PackedStringArray:
	var achados := PackedStringArray()
	for arquivo in DirAccess.get_files_at(pasta):
		if arquivo.ends_with(".json"):
			achados.append(pasta.path_join(arquivo))
	for sub in DirAccess.get_directories_at(pasta):
		achados.append_array(_arquivos_json(pasta.path_join(sub)))
	return achados


func _varrer(no, arquivo: String, onde: String, saida: Array) -> void:
	if no is Dictionary:
		for chave in no:
			var valor = no[chave]
			if PARES.has(chave) and valor is String and valor != "":
				var nome := _nome_da_voz(valor)
				if nome != "":
					var texto = no.get(PARES[chave])
					saida.append({"onde": "%s.%s" % [onde, chave], "arquivo": arquivo, "audio": nome,
						"texto": texto if texto is String else null})
			_varrer(valor, arquivo, "%s.%s" % [onde, chave], saida)
	elif no is Array:
		for i in no.size():
			_varrer(no[i], arquivo, "%s[%d]" % [onde, i], saida)


## "benedito_fala_1" ou "res://assets/audio/vozes/damiao_bronca_1.mp3" → o nome do mp3; "" para outra pasta.
func _nome_da_voz(valor: String) -> String:
	if valor.begins_with("res://"):
		if not valor.begins_with(PASTA):
			return ""
		return valor.trim_prefix(PASTA).trim_suffix(".mp3")
	return valor
