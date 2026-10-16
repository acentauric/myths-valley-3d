extends "res://tests/unidade/base.gd"
## AS VOZES DO VALE ESTÃO LIGADAS: cada campo de áudio dos dados aponta para um mp3 que existe e importa, nenhum
## mp3 fica sem uso, e a voz de cada fala diz o texto que o jogador lê.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste vozes_completas
##
## O jogo não toca o que não está escrito: a voz de uma fala mora num campo de áudio ao lado do texto dela
## (`audio` e `texto`, `audio_resposta` e `resposta`, `trancada_audio` e `trancada`, `audio_oferta` e `oferta`,
## `audio_pergunta` e `pergunta`), com o nome de assets/audio/vozes/<nome>.mp3. Voz que não está num campo é
## arquivo que ninguém toca; campo que aponta para arquivo que não existe é fala muda, e nada avisa; fala sem
## campo é fala muda também. Quatro perguntas, que valem para o lote de 15/10/2026 (#248, #59 e #210) e para
## todo lote que vier:
##
##   0. TODA FALA FALADA TEM VOZ (#248): cada conversa, cada anúncio de passo, resposta, arremate, aviso de fila
##      trancada, socorro e fala de cena de morador ou de missão tem o campo de áudio preenchido. O que ainda não
##      tem está declarado em `VOZ_PENDENTE`, com a razão; a lista só encolhe. A narração do mundo (a voz sem nome,
##      em `NARRACAO_SEM_VOZ`) e as notas de fim (`narra: false`) não são faladas por quem quer que seja.
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

## A narração do mundo, que não tem quem a diga: a voz sem nome, com o escuro, na tela (`narracao_do_vale.gd`).
## Por arquivo de missão, os blocos de cena que são narração e não fala de ninguém. Qualquer outro bloco de
## fala dessas cenas é de um personagem, e tem voz.
const NARRACAO_SEM_VOZ := {
	"fazenda": ["silencio", "de_pe", "subida", "cerco", "porta", "narracao"],
	"revoar": ["quarto", "aceite", "chao", "recusa", "miragens", "fuga", "revoar", "noite", "senhor", "chamado",
		"pedra", "amanhecer", "amanhecer_levado"],
}

## As falas faladas que ainda não têm voz, e por quê. A chave é uma CATEGORIA (todas as falas dela) ou uma fala
## ("arraial:mirante_material"). Só encolhe: a que ganhou voz sai daqui (o teste reprova a pendência cumprida).
const VOZ_PENDENTE := {
	"arraial:mirante_material": "o passo diz 'oito tábuas, quatro pedras e duas cordas' desde que a obra baixou o custo (0241ea3), e a voz gerada ainda diz vinte, doze e seis: o passo fica sem voz até uma tomada com o texto certo",
	"socorro": "o socorro da mungunzá ainda não toca a voz",
	"cena": "as falas de cena da fazenda e do revoar ainda não tocam a voz",
	"pergunta": "as perguntas de cena ainda não tocam a voz",
	"fe": "as vozes da fé ainda não tocam a voz",
	"oferenda": "a resposta da oferenda é aviso do HUD e ainda não toca a voz",
	"quirino": "o mestre Quirino ainda não tem voz",
}

var _campos: Array = []


func before_all() -> void:
	super.before_all()
	_campos = _campos_de_audio()


# --- as quatro perguntas -------------------------------------------------------------------------------

func test_toda_fala_falada_tem_voz() -> void:
	var falas := _falas_faladas()
	# Moradores (229) e missões (perto de 500): abaixo de 450 a varredura não está pegando.
	conferir(falas.size() >= 450, "só %d fala(s) falada(s) nos dados: a varredura não está pegando" % falas.size())
	var sem_voz := _sem_voz(falas, VOZ_PENDENTE)
	conferir(sem_voz.is_empty(), "%d fala(s) falada(s) sem voz (gere a voz e ligue no campo de áudio, ou declare em VOZ_PENDENTE): %s" % [sem_voz.size(), "; ".join(sem_voz.slice(0, 6))])
	var cumpridas := _pendencias_cumpridas(falas, VOZ_PENDENTE)
	conferir(cumpridas.is_empty(), "pendência de voz que já foi cumprida (tire de VOZ_PENDENTE): %s" % ", ".join(cumpridas))


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
	# 0. uma fala falada sem voz, fora da lista de pendências; e uma pendência que já foi cumprida.
	var faladas := _falas_faladas()
	var sem_voz_hoje := _sem_voz(faladas, VOZ_PENDENTE).size()
	faladas.append({"onde": "falsa", "chave": "falsa:fala", "categoria": "anuncio", "audio": ""})
	conferir(_sem_voz(faladas, VOZ_PENDENTE).size() == sem_voz_hoje + 1, "o detector de fala sem voz não achou a fala que não tem")
	conferir(_pendencias_cumpridas(faladas, VOZ_PENDENTE.merged({"conversa": "razão"})) == ["conversa"], "o detector de pendência cumprida não achou a categoria que já tem voz")
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


## As falas faladas sem voz que ninguém declarou: ["arquivo:passo (categoria)"].
func _sem_voz(faladas: Array, pendente: Dictionary) -> Array:
	var ruins: Array = []
	for fala in faladas:
		if str(fala["audio"]) == "" and not pendente.has(fala["categoria"]) and not pendente.has(fala["chave"]):
			ruins.append("%s (%s)" % [fala["chave"], fala["categoria"]])
	return ruins


## As pendências declaradas que não têm mais fala sem voz.
func _pendencias_cumpridas(faladas: Array, pendente: Dictionary) -> Array:
	var cumpridas: Array = []
	for chave in pendente:
		var sem_voz := false
		for fala in faladas:
			if (fala["categoria"] == chave or fala["chave"] == chave) and str(fala["audio"]) == "":
				sem_voz = true
				break
		if not sem_voz:
			cumpridas.append(chave)
	return cumpridas


# --- as falas faladas ----------------------------------------------------------------------------------

## Cada fala que o jogo diz em voz: {onde, chave, categoria, audio}. Dos moradores: todo objeto com `texto` de quem
## fala (o Pedro e os 22 moradores). Das missões: o anúncio de cada passo, a resposta, o arremate que se narra, o aviso
## de fila trancada, o socorro, as falas de cena dos personagens e as perguntas de cena.
func _falas_faladas() -> Array:
	var saida: Array = []
	var npcs = _ler("res://data/npcs_3d.json")
	for pessoa in [npcs["guia"]] + (npcs["moradores"] as Array):
		if bool(pessoa.get("mudo", false)):
			continue
		var id := str(pessoa.get("id", "?"))
		_textos_de_quem_fala(pessoa, "npcs_3d:" + id, "quirino" if id == "quirino" else "conversa", saida)
	for arquivo in _arquivos_de_missoes():
		_falas_da_missao(arquivo.get_file().trim_prefix("missoes_").trim_suffix(".json"), _ler(arquivo), saida)
	return saida


func _textos_de_quem_fala(no, onde: String, categoria: String, saida: Array) -> void:
	if no is Dictionary:
		if no.get("texto") is String and str(no["texto"]) != "":
			saida.append(_fala(onde, categoria, str(no.get("audio", ""))))
		for chave in no:
			_textos_de_quem_fala(no[chave], "%s.%s" % [onde, chave], categoria, saida)
	elif no is Array:
		for i in no.size():
			_textos_de_quem_fala(no[i], "%s[%d]" % [onde, i], categoria, saida)


func _falas_da_missao(nome: String, d: Dictionary, saida: Array) -> void:
	var da_fe := nome.begins_with("fe_")
	for passo in d.get("passos", []):
		var id := str(passo.get("id", "?"))
		var meta: Dictionary = passo.get("meta", {})
		if str(passo.get("texto", "")) != "":
			saida.append(_fala("%s:%s" % [nome, id], "fe" if da_fe else "anuncio", str(passo.get("audio", ""))))
		if str(meta.get("resposta", "")) != "":
			var categoria := "resposta"
			if da_fe:
				categoria = "fe"
			elif str(meta.get("tipo", "")) == "oferendar":
				categoria = "oferenda"
			elif str(meta.get("a_quem", "")) == "quirino":
				categoria = "quirino"
			saida.append(_fala("%s:%s.resposta" % [nome, id], categoria, str(meta.get("audio_resposta", ""))))
	var arremate: Dictionary = d.get("arremate", {})
	if str(arremate.get("texto", "")) != "" and bool(arremate.get("narra", true)):
		saida.append(_fala("%s:arremate" % nome, "fe" if da_fe else "arremate", str(arremate.get("audio", ""))))
	if str(d.get("trancada", "")) != "":
		saida.append(_fala("%s:trancada" % nome, "trancada", str(d.get("trancada_audio", ""))))
	var narracao: Array = NARRACAO_SEM_VOZ.get(nome, [])
	for chave in d:
		var valor = d[chave]
		if chave == "passos" or narracao.has(chave) or not (valor is Array):
			continue
		var categoria := "socorro" if chave == "socorro" else ("conversa" if chave == "corpo" else "cena")
		for i in valor.size():
			if valor[i] is Dictionary and str(valor[i].get("texto", "")) != "":
				saida.append(_fala("%s:%s[%d]" % [nome, chave, i], categoria, str(valor[i].get("audio", ""))))
	var trocas: Array = d.get("trocas", [])
	for i in trocas.size():
		saida.append(_fala("%s:trocas[%d].oferta" % [nome, i], "cena", str(trocas[i].get("audio_oferta", ""))))
		saida.append(_fala("%s:trocas[%d].pergunta" % [nome, i], "pergunta", str(trocas[i].get("audio_pergunta", ""))))
	var escudo = d.get("pergunta_escudo")
	if escudo is Dictionary and str(escudo.get("texto", "")) != "":
		saida.append(_fala("%s:pergunta_escudo" % nome, "pergunta", str(escudo.get("audio", ""))))


func _fala(chave: String, categoria: String, audio: String) -> Dictionary:
	return {"onde": chave, "chave": chave, "categoria": categoria, "audio": audio}


func _arquivos_de_missoes() -> PackedStringArray:
	var achados := PackedStringArray()
	for arquivo in DirAccess.get_files_at(DADOS):
		if arquivo.begins_with("missoes_") and arquivo.ends_with(".json"):
			achados.append(DADOS.path_join(arquivo))
	achados.sort()
	return achados


func _ler(caminho: String):
	return JSON.parse_string(FileAccess.get_file_as_string(caminho))


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
