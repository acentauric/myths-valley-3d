extends SceneTree
## Confere AS FALAS DOS MORADORES: todo morador do vale fala — ou é mudo POR ESCRITO, com a
## razão —, e os catorze que eram mudos falam, nos três idiomas, pela fila de falas.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/falas_dos_moradores.gd
##     ... -- --falsificar-falas        (o portão TEM de reprovar: ver `_falsificar`)
##
## "Crie as falas para os personagens que ainda não têm." (playtest da Build 9B, 06/10/2026).
## Catorze dos vinte e dois moradores eram `"mudo": true`, sem uma linha. Agora cada um tem
## `saudacoes` (o cumprimento de quem passa, que cabe inteiro no balão), `falas` (a conversa do E)
## e, se está na rua no escuro, `saudacoes_noite` e `falas_noite` (`falas_dos_moradores.gd`).
## Sete perguntas:
##
##   1. TODO MORADOR FALA OU TEM RAZÃO ESCRITA PARA NÃO FALAR: `mudo` sem `mudo_motivo` reprova;
##      sem `mudo`, os sete de antes (e o Quirino) têm as três `falas` de sempre, e TODO OUTRO tem
##      de ter o padrão novo — nenhum morador entra no vale com menos que isso.
##   2. O PADRÃO NOVO: de 3 a 4 saudações e de 6 a 10 falas, cada uma com `texto`, `texto_en` e
##      `texto_es` de verdade — nunca igual ao português nem quase (mais de 60% das palavras em
##      comum), sem marca de português no inglês nem de inglês no espanhol —, sem `audio` que não
##      exista (fora de quem declarou `voz_pendente`; a voz é conferida em vozes_dos_moradores.gd), sem texto
##      repetido no arquivo.
##   3. O TAMANHO: a saudação tem de 12 a 60 letras nos três idiomas e a frase que o balão curto leva
##      (`MoradorNPC.balao_curto`: a primeira) sai INTEIRA, sem reticências — o resto vai no aviso do HUD;
##      a fala de conversa, de 60 a 140 letras em português.
##   4. A LISTA CERTA PARA CADA HORA (`FalasDosMoradores`): de noite soma as `*_noite`, de dia não, e ao
##      cair a noite a rotação recomeça por elas; quem fica na rua à noite mais de meia hora tem fala
##      de noite, e só ele.
##   5. NO VALE, O CUMPRIMENTO DE CADA UM DOS CATORZE SAI DAS `saudacoes` e o E DAS `falas`: um balão
##      com uma fala dele, na língua do jogo, pela fila (um só `comecou` do falante, na classe
##      certa), com o aviso do HUD e o relógio parado enquanto responde.
##   6. DE NOITE O GUARDA DIZ AS DE NOITE (e só as de noite aparecem na hora certa), pelo mesmo caminho.
##   7. QUEM TRABALHA CONTINUA TRABALHANDO ENQUANTO FALA: o sacristão que varre não larga a vassoura
##      nem troca o clipe do ofício pelo gesto de saudação.

const RelogioDeJogo = preload("res://tests/fixtures/relogio_de_jogo.gd")
const FalasDosMoradores = preload("res://scripts/prototipo_3d/falas_dos_moradores.gd")
const FilaDeFalas = preload("res://scripts/prototipo_3d/fila_de_falas.gd")

## Os catorze que eram mudos.
const NOVOS := ["padre", "sacristao", "beata", "mercador", "guarda", "pescador", "marisqueira", "lavadeira",
	"rendeira", "quituteira", "carpinteiro", "menino", "menina", "mestre_saveiro"]
## Os que já falavam, com a mesma lista no cumprimento e no E. As traduções que faltam a eles estão
## declaradas em tests/idiomas.gd (FALTAM_TRADUCAO). Esta lista só encolhe.
const ANTIGOS := ["benedito", "zefa", "cosme", "tonho", "filo", "candinha", "damiao", "quirino"]

const SAUDACOES := Vector2i(3, 4)
const CONVERSAS := Vector2i(6, 10)
const SAUDACAO_LETRAS := Vector2i(12, 60)
const CONVERSA_LETRAS := Vector2i(60, 140)
const CONVERSA_TRADUZIDA := Vector2i(45, 170)
## Passado disto de palavras em comum com o português, a "tradução" é o português com retoque.
const COMUM_NO_MAXIMO := 0.6
const MARCAS_DE_PORTUGUES := [" não ", " você", " uma ", " pra ", " ção", "ção ", "ções"]
const MARCAS_DE_INGLES := [" the ", " and ", " of ", " you ", " with "]
## A noite do vale (`Dia.periodo() == "noite"`): das 18h48 à meia-noite. A madrugada fica de fora de
## propósito (é a hora em que o padre, o sacristão e a lavadeira abrem o dia, e o cumprimento deles é o de
## sempre). Quem passa mais que `NOITE_NA_RUA` horas dela fora de casa tem de ter fala de noite.
const NOITE_DE := 18.8
const NOITE_NA_RUA := 0.5
const PASTA_VOZES := "res://assets/audio/vozes/"

const PovoadoLiberado = preload("res://tests/fixtures/povoado_liberado.gd")
const ConversaDoE = preload("res://tests/fixtures/conversa_do_e.gd")

var falhas := 0
var falsificar := false
var relogio: Node
var vale
var fila
var IdiomaMenu
## Cada fala que ganhou a vez na fila: {falante, classe, texto}.
var _comecaram: Array = []
## Quantos moradores tiveram o cumprimento e o E conferidos no vale (de dia, de noite, trabalhando).
var _no_vale := 0
## O morador que `_conferir_morador` está conferindo declarou `voz_pendente` (áudio que falta gerar).
var _morador_pendente := false
var _de_noite := 0
var _trabalhando := 0


func _initialize() -> void:
	falsificar = OS.get_cmdline_user_args().has("--falsificar-falas")
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("FALAS_DOS_MORADORES_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	root.get_node("/root/Estilo").modo = "tripo"
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	relogio = RelogioDeJogo.new()
	root.add_child(relogio)
	await _quadros(4)
	await _mundo_pronto()
	await _quadros(8)
	relogio.ficar_lento()
	vale = current_scene
	# O povoado se apresenta aos poucos na chegada (#155): este portão fala com moradores de longe.
	await PovoadoLiberado.todos(self, vale)
	# O ACEITE É AUTOMÁTICO AQUI (08/10): este portão abre filas pelo E e segue; a tela de aceite
	# pausaria o vale no meio da medida (a tela tem portão próprio, tests/missao_a_vista.gd).
	if vale.get("aceite") != null:
		vale.aceite.automatico = true
	fila = vale.get("fila_de_falas")
	var jogador = vale.player
	var tecla = vale.get("tecla_dos_moradores")
	var dia = root.get_node("/root/Dia")
	_conferir(fila != null and tecla != null and jogador != null,
		"o vale não tem a fila de falas, o E dos moradores ou o jogador")
	if fila == null or tecla == null or jogador == null:
		_fechar()
		return
	# Depois de o vale subir: o `IdiomaMenu` cita autoload, e `load` antes do vale o quebraria no cache.
	IdiomaMenu = load("res://scripts/prototipo_3d/idioma_menu.gd")
	dia.pausado = true

	var arquivo = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs_3d.json"))
	_conferir(arquivo is Dictionary and (arquivo.get("moradores", []) as Array).size() >= ANTIGOS.size() + NOVOS.size(),
		"o npcs_3d.json não tem os moradores")
	if not (arquivo is Dictionary):
		_fechar()
		return
	var moradores_do_arquivo: Array = arquivo["moradores"]
	var por_id := {}
	for morador in vale.moradores:
		por_id[str(morador.dados.get("id", ""))] = morador
	_falsificar(moradores_do_arquivo, por_id)

	# --- 1 a 3. O ARQUIVO -------------------------------------------------------------
	var repetidos := {}
	for morador in moradores_do_arquivo:
		_conferir_morador(morador as Dictionary, repetidos)
	for fala in (arquivo.get("guia", {}) as Dictionary).get("falas", []):
		repetidos[str((fala as Dictionary).get("texto", ""))] = "pedro.falas"
	for id in NOVOS + ANTIGOS:
		_conferir(por_id.has(id), "o vale não tem o morador '%s'" % id)
	var referencia = por_id.get("padre")
	if referencia == null:
		_fechar()
		return
	_conferir_o_balao_da_saudacao(moradores_do_arquivo, referencia)
	_conferir_os_tres_idiomas(moradores_do_arquivo)

	# --- 4. A LISTA CERTA PARA CADA HORA ---------------------------------------------
	_conferir_as_listas(moradores_do_arquivo)

	# --- 5. NO VALE, CUMPRIMENTO E E DE CADA UM ---------------------------------------
	fila.comecou.connect(func(fala: Dictionary) -> void:
		_comecaram.append({"falante": fala.get("falante"), "classe": int(fala.get("classe", -1)),
			"texto": str(fala.get("texto", ""))}))
	for id in NOVOS:
		var m = por_id.get(id)
		if m == null:
			continue
		var d: Dictionary = m.dados
		var hora := _hora_na_rua(d)
		_conferir(hora >= 0.0, "'%s' não sai de casa em hora nenhuma da agenda" % id)
		if hora < 0.0:
			continue
		dia.definir_hora(hora)
		m.ir_ao_posto_agora()
		await _quadros(2)
		_conferir(not m.esta_recolhido() and m.visible, "às %.1f h '%s' devia estar na rua" % [hora, id])
		_ao_lado_de(jogador, m)
		await _quadros(2)
		await _vez_livre()
		await _cumprimentar_e_conversar(m, d, tecla, hora, false)
		_no_vale += 1

	# --- 6. DE NOITE, O GUARDA --------------------------------------------------------
	var guarda = por_id.get("guarda")
	if guarda != null:
		dia.definir_hora(21.0)
		_conferir(dia.periodo() == "noite", "às 21 h o período devia ser noite, e é '%s'" % dia.periodo())
		guarda.ir_ao_posto_agora()
		# O cumprimento de quem chega perto (`_atualizar_interacao`) só sai passados 45 s DE PAREDE do último, e
		# o portão leva mais que isso do dia à noite numa máquina ocupada: aí o guarda cumprimentava sozinho ao
		# ser posto ao lado do jogador, gastava "Boa noite" e o `saudar()` do portão caía na segunda saudação.
		# Quem quer a primeira de noite é o portão, que chama `saudar()`: o da proximidade fica fora.
		guarda.intervalo_saudacao_ms = 3600000
		guarda.set("_ultima_saudacao_ms", Time.get_ticks_msec())
		await _quadros(2)
		_ao_lado_de(jogador, guarda)
		await _quadros(2)
		await _vez_livre()
		await _cumprimentar_e_conversar(guarda, guarda.dados, tecla, 21.0, true)
		_de_noite += 1

	# --- 7. QUEM TRABALHA CONTINUA TRABALHANDO ENQUANTO FALA ---------------------------
	var sacristao = por_id.get("sacristao")
	if sacristao != null:
		dia.definir_hora(5.6)
		sacristao.ir_ao_posto_agora()
		jogador.global_position = vale.world.ground_position(sacristao.global_position + Vector3(6.0, 0.0, 0.0), 0.5)
		var animador = sacristao.animador
		var varrendo: bool = await relogio.ate(func() -> bool:
			return animador != null and animador.has_method("trabalhando") and animador.trabalhando(), 8.0)
		_conferir(varrendo, "o sacristão parado no posto devia estar varrendo (clipe do ofício)")
		if varrendo:
			_ao_lado_de(jogador, sacristao)
			await _quadros(2)
			await _vez_livre()
			await ConversaDoE.usar(tecla, sacristao)
			var falou: bool = await relogio.ate(func() -> bool: return sacristao.falando_agora(), 6.0)
			_conferir(falou, "o E no sacristão varrendo não o fez falar")
			await relogio.esperar(0.4)
			_conferir(animador.trabalhando(), "o sacristão largou o clipe do ofício para falar")
			var gesto = animador.get("_gesture_active")
			_conferir(gesto == null or not bool(gesto),
				"o sacristão trocou a vassoura pelo gesto de saudação enquanto falava")
			_conferir(sacristao._levados.size() == 1, "o sacristão devia seguir com a vassoura na mão (leva %d)" % sacristao._levados.size())
			_trabalhando += 1
	_fechar()


## O MORADOR NO ARQUIVO: ou mudo com razão, ou falando (o padrão antigo para os sete e o Quirino,
## o novo para todos os outros).
func _conferir_morador(m: Dictionary, repetidos: Dictionary) -> void:
	var id := str(m.get("id", "?"))
	_morador_pendente = str(m.get("voz_pendente", "")) != ""
	if bool(m.get("mudo", false)):
		_conferir(str(m.get("mudo_motivo", "")).length() > 20,
			"'%s' é mudo sem razão escrita (`mudo_motivo`): quem não fala diz por quê" % id)
		_conferir(not NOVOS.has(id), "'%s' devia ter falas, e continua mudo" % id)
		return
	var antigo := ANTIGOS.has(id)
	var falas: Array = m.get("falas", [])
	if antigo and not m.has("saudacoes"):
		_conferir(falas.size() >= 3, "'%s' tem %d fala(s), e os antigos têm ao menos três" % [id, falas.size()])
		for i in falas.size():
			_conferir(str((falas[i] as Dictionary).get("texto", "")) != "", "'%s'.falas[%d] sem texto" % [id, i])
			_repetido(repetidos, str((falas[i] as Dictionary).get("texto", "")), "%s.falas[%d]" % [id, i])
		return
	var saudacoes: Array = m.get("saudacoes", [])
	_conferir(saudacoes.size() >= SAUDACOES.x and saudacoes.size() <= SAUDACOES.y,
		"'%s' tem %d saudação(ões), e são de %d a %d" % [id, saudacoes.size(), SAUDACOES.x, SAUDACOES.y])
	_conferir(falas.size() >= CONVERSAS.x and falas.size() <= CONVERSAS.y,
		"'%s' tem %d fala(s) de conversa, e são de %d a %d" % [id, falas.size(), CONVERSAS.x, CONVERSAS.y])
	for categoria in ["saudacoes", "falas", "saudacoes_noite", "falas_noite"]:
		var lista: Array = m.get(categoria, [])
		for i in lista.size():
			var onde := "'%s'.%s[%d]" % [id, categoria, i]
			_conferir_entrada(onde, lista[i], categoria.begins_with("saudacoes"))
			if lista[i] is Dictionary:
				_repetido(repetidos, str(lista[i].get("texto", "")), onde)


func _repetido(repetidos: Dictionary, texto: String, onde: String) -> void:
	_conferir(not repetidos.has(texto) or texto == "", "%s repete a fala de %s" % [onde, str(repetidos.get(texto, ""))])
	repetidos[texto] = onde


## UMA FALA: nos três idiomas de verdade, no tamanho que o balão aguenta, sem voz que não exista.
func _conferir_entrada(onde: String, entrada, saudacao: bool) -> void:
	if not (entrada is Dictionary):
		_conferir(false, "%s não é um objeto" % onde)
		return
	var pt := str(entrada.get("texto", ""))
	_conferir(pt != "", "%s sem o texto em português" % onde)
	var faixa_pt := SAUDACAO_LETRAS if saudacao else CONVERSA_LETRAS
	_conferir(pt.length() >= faixa_pt.x and pt.length() <= faixa_pt.y,
		"%s tem %d letras em português, e devia ter de %d a %d" % [onde, pt.length(), faixa_pt.x, faixa_pt.y])
	for sufixo in ["_en", "_es"]:
		var t := str(entrada.get("texto" + sufixo, ""))
		_conferir(t != "", "%s sem o campo texto%s" % [onde, sufixo])
		if t == "" or pt == "":
			continue
		_conferir(t != pt, "%s: texto%s é cópia do português" % [onde, sufixo])
		var comum := _em_comum(pt, t)
		_conferir(comum <= COMUM_NO_MAXIMO,
			"%s: texto%s divide %.0f%% das palavras com o português — tradução faltando disfarçada" % [onde, sufixo, comum * 100.0])
		var faixa := SAUDACAO_LETRAS if saudacao else CONVERSA_TRADUZIDA
		_conferir(t.length() >= faixa.x and t.length() <= faixa.y,
			"%s: texto%s tem %d letras, e devia ter de %d a %d" % [onde, sufixo, t.length(), faixa.x, faixa.y])
		var marcas: Array = MARCAS_DE_PORTUGUES if sufixo == "_en" else MARCAS_DE_PORTUGUES + MARCAS_DE_INGLES
		var alheio := ""
		for marca: String in marcas:
			if (" " + t + " ").contains(marca):
				alheio = marca
		_conferir(alheio == "", "%s: texto%s traz '%s', que não é da língua dele" % [onde, sufixo, alheio.strip_edges()])
		if sufixo == "_en":
			_conferir(not (t.contains("ñ") or t.contains("¿") or t.contains("¡")), "%s: o texto_en traz letra de espanhol" % onde)
	# O ÁUDIO — existe, importa, dura o que o texto pede — é conferido a fundo em tests/vozes_dos_moradores.gd. Aqui
	# só que o nome aponta um arquivo de verdade, a não ser em quem declarou `voz_pendente` (falta gerar a voz).
	var audio := str(entrada.get("audio", ""))
	_conferir(audio == "" or _morador_pendente or ResourceLoader.exists(PASTA_VOZES + audio + ".mp3"),
		"%s aponta o áudio '%s', que não existe (gere com tools/elevenlabs/gerar-falas-moradores.ps1 ou declare `voz_pendente`)" % [onde, audio])


## A fração das palavras do português que a "tradução" repete.
func _em_comum(pt: String, outra: String) -> float:
	var minhas := _palavras(pt)
	if minhas.is_empty():
		return 0.0
	var delas := _palavras(outra)
	var iguais := 0
	for palavra in minhas:
		if delas.has(palavra):
			iguais += 1
	return float(iguais) / float(minhas.size())


func _palavras(texto: String) -> Dictionary:
	var limpo := texto.to_lower()
	for pontuacao in [".", ",", ";", ":", "!", "?", "¿", "¡", "—", "-", "\"", "(", ")", "…"]:
		limpo = limpo.replace(pontuacao, " ")
	var palavras := {}
	for palavra in limpo.split(" ", false):
		palavras[palavra] = true
	return palavras


## O BALÃO DA SAUDAÇÃO SAI INTEIRO nos três idiomas: a frase que o balão curto leva (a primeira) é o
## começo da saudação e não é cortada com reticências; o resto da saudação vai no aviso do HUD.
func _conferir_o_balao_da_saudacao(moradores: Array, referencia) -> void:
	var conferidas := 0
	for m in moradores:
		for categoria in ["saudacoes", "saudacoes_noite"]:
			for entrada in (m as Dictionary).get(categoria, []):
				for chave in ["texto", "texto_en", "texto_es"]:
					var texto := str((entrada as Dictionary).get(chave, ""))
					if texto == "":
						continue
					var curto: String = referencia.balao_curto(texto)
					_conferir(curto != "" and not curto.ends_with("…") and texto.strip_edges().begins_with(curto),
						"o balão da saudação de '%s' sai cortado, ou não é o começo dela (%s): '%s'" % [m.get("id", "?"), chave, curto])
					conferidas += 1
	_conferir(conferidas >= NOVOS.size() * SAUDACOES.x * 3, "só %d saudação(ões) conferida(s) no balão" % conferidas)


## O que o motor lê (`IdiomaMenu.campo_no_idioma`) é o que está escrito, nos três idiomas.
func _conferir_os_tres_idiomas(moradores: Array) -> void:
	var lidas := 0
	for m in moradores:
		if not NOVOS.has(str((m as Dictionary).get("id", ""))):
			continue
		for categoria in ["saudacoes", "falas", "saudacoes_noite", "falas_noite"]:
			for entrada in m.get(categoria, []):
				for indice in 3:
					var lida := str(IdiomaMenu.campo_no_idioma(entrada, "texto", indice, ""))
					var escrita := str(entrada.get(["texto", "texto_en", "texto_es"][indice], ""))
					_conferir(lida != "" and lida == escrita,
						"'%s'.%s: o idioma %d lê '%s' e está escrito '%s'" % [m.get("id", "?"), categoria, indice, lida.left(30), escrita.left(30)])
					lidas += 1
	_conferir(lidas > 0, "nenhuma fala lida nos três idiomas")


## A LISTA CERTA (`FalasDosMoradores`) e quem tem fala de noite.
func _conferir_as_listas(moradores: Array) -> void:
	_conferir(FalasDosMoradores.humor_do_periodo("noite") == FalasDosMoradores.NOITE, "'noite' devia ser humor de noite")
	for periodo in ["madrugada", "manha", "tarde", "entardecer", ""]:
		_conferir(FalasDosMoradores.humor_do_periodo(periodo) == "", "'%s' devia ser humor neutro" % periodo)
	for m in moradores:
		var dados: Dictionary = m
		var id := str(dados.get("id", ""))
		if not NOVOS.has(id):
			continue
		for categoria in ["saudacoes", "falas"]:
			var de_dia := FalasDosMoradores.lista(dados, categoria, "")
			var de_noite := FalasDosMoradores.lista(dados, categoria, FalasDosMoradores.NOITE)
			var extras: Array = dados.get(categoria + "_noite", [])
			_conferir(de_dia.size() == (dados.get(categoria, []) as Array).size(), "'%s': a lista de dia de %s não é a de sempre" % [id, categoria])
			_conferir(de_noite.size() == de_dia.size() + extras.size(), "'%s': a lista de noite de %s não soma as de noite" % [id, categoria])
			_conferir(de_dia.all(func(f) -> bool: return not extras.has(f)),
				"'%s': a lista de dia de %s traz fala de noite" % [id, categoria])
			de_dia.append({"texto": "mexida de fora"})
			_conferir((dados.get(categoria, []) as Array).size() == de_dia.size() - 1,
				"'%s': a lista devolvida de %s é a do próprio morador, e quem a recebe a altera" % [id, categoria])
		# Cai a noite: a rotação recomeça pelas de noite, de quem as tem; de dia, ou sem elas, segue onde estava.
		for categoria in ["saudacoes", "falas"]:
			var base := (dados.get(categoria, []) as Array).size()
			var tem_noite := not (dados.get(categoria + "_noite", []) as Array).is_empty()
			_conferir(FalasDosMoradores.recomeco(dados, categoria, FalasDosMoradores.NOITE, 2) == (base if tem_noite else 2),
				"'%s': a rotação de %s não recomeça pela primeira de noite (ou recomeça sem ter de noite)" % [id, categoria])
			_conferir(FalasDosMoradores.recomeco(dados, categoria, "", 2) == 2,
				"'%s': de dia a rotação de %s não devia recomeçar" % [id, categoria])
		var a_noite := _horas_na_rua_de_noite(dados)
		var tem := dados.has("saudacoes_noite") or dados.has("falas_noite")
		_conferir(not (a_noite >= NOITE_NA_RUA) or (dados.has("saudacoes_noite") and dados.has("falas_noite")),
			"'%s' fica %.1f h na rua à noite e não tem saudacoes_noite e falas_noite" % [id, a_noite])
		_conferir(not tem or a_noite > 0.0, "'%s' tem fala de noite e a agenda dele não o deixa na rua à noite" % id)


## Quantas horas da noite (das 18h48 à meia-noite) o morador passa FORA de casa, pela agenda: cada
## entrada vale até a seguinte, e a última dá a volta no dia.
func _horas_na_rua_de_noite(dados: Dictionary) -> float:
	var agenda: Array = dados.get("agenda", [])
	var total := 0.0
	for i in agenda.size():
		if str(agenda[i].get("acao", "")) == "recolhido":
			continue
		var de := float(agenda[i]["de"])
		var ate := float(agenda[(i + 1) % agenda.size()]["de"])
		if ate <= de:
			ate += 24.0
		total += maxf(0.0, minf(ate, 24.0) - maxf(de, NOITE_DE))
	return total


## Uma hora DE DIA (das 6h30 às 17h30) em que o morador está fora de casa: dentro da primeira entrada
## da agenda que não o recolhe e que passa por essa faixa. -1 sem nenhuma.
func _hora_na_rua(dados: Dictionary) -> float:
	var agenda: Array = dados.get("agenda", [])
	for i in agenda.size():
		if str(agenda[i].get("acao", "")) == "recolhido":
			continue
		var de := float(agenda[i]["de"])
		var ate := float(agenda[(i + 1) % agenda.size()]["de"])
		if ate <= de:
			ate += 24.0
		var hora := maxf(de, 6.5) + 0.1
		if hora < ate - 0.05 and hora <= 17.5:
			return hora
	return -1.0


## O CUMPRIMENTO E A CONVERSA DE UM MORADOR, na hora e no lugar dele, e o que cada um tem de ser.
func _cumprimentar_e_conversar(m, d: Dictionary, tecla, hora: float, de_noite: bool) -> void:
	var id := str(d.get("id", "?"))
	var humor := FalasDosMoradores.NOITE if de_noite else ""
	var saudacoes := FalasDosMoradores.lista(d, "saudacoes", humor)
	var falas := FalasDosMoradores.lista(d, "falas", humor)
	var avisos: Array[String] = []
	var ao_avisar := func(_quem, texto: String) -> void: avisos.append(texto)
	m.saudou.connect(ao_avisar)

	# O CUMPRIMENTO: uma das saudações, no balão curto. De dia a rotação começa na primeira; de noite NÃO
	# se força: cai a noite (o humor muda) e ela recomeça sozinha pela primeira de noite
	# (`FalasDosMoradores.recomeco`).
	if not de_noite:
		m.set("_proxima_saudacao", 0)
	var antes := _comecaram.size()
	m.saudar()
	var cumprimentou: bool = await relogio.ate(func() -> bool: return m.balao.visible and _no_balao(m) != "", 6.0)
	_conferir(cumprimentou, "às %.1f h '%s' não cumprimentou com balão" % [hora, id])
	if cumprimentou:
		# O balão leva a primeira frase (`balao_curto`); o aviso do HUD, a saudação inteira.
		var no_balao := _no_balao(m)
		var curtas: Array[String] = []
		var inteiras: Array[String] = []
		for s in saudacoes:
			inteiras.append(str(IdiomaMenu.campo(s, "texto", "")))
			curtas.append(m.balao_curto(inteiras[-1]))
		_conferir(curtas.has(no_balao), "o cumprimento de '%s' foi '%s', que não é de nenhuma saudação dele" % [id, no_balao])
		if de_noite:
			var noturnas: Array = d.get("saudacoes_noite", [])
			_conferir(not noturnas.is_empty() and no_balao == m.balao_curto(str(IdiomaMenu.campo(noturnas[0], "texto", ""))),
				"de noite '%s' não disse a primeira saudação de noite: '%s'" % [id, no_balao])
		for fala in (d.get("falas", []) as Array) + (d.get("falas_noite", []) as Array):
			_conferir(no_balao != m.balao_curto(str(IdiomaMenu.campo(fala, "texto", ""))),
				"o cumprimento de '%s' saiu das falas de conversa: '%s'" % [id, no_balao])
		_conferir(_veio_da_fila(m, antes, FilaDeFalas.Classe.PASSAGEM, no_balao),
			"o cumprimento de '%s' não passou pela fila de falas como passagem" % id)
		_conferir(avisos.size() == 1 and inteiras.has(avisos[0]) and m.balao_curto(avisos[0]) == no_balao,
			"o aviso do HUD de '%s' não levou a saudação inteira (%s)" % [id, str(avisos)])

	# A CONVERSA DO E: uma das falas, inteira, na vez dele, segurando o relógio. O cumprimento é fala no ar e tira o E
	# (#121): o jogador espera o balão sumir, e `ConversaDoE.usar` faz o mesmo.
	if not de_noite:
		m.set("_proxima_fala", 0)
	var antes_do_e := _comecaram.size()
	var esperadas: Array[String] = []
	for fala in falas:
		esperadas.append(str(IdiomaMenu.campo(fala, "texto", "")))
	await ConversaDoE.usar(tecla, m)
	var conversou: bool = await relogio.ate(func() -> bool:
		return _veio_da_fila(m, antes_do_e, FilaDeFalas.Classe.CONVERSA, "") and m.balao.visible and esperadas.has(_no_balao(m)), 8.0)
	_conferir(conversou, "o E em '%s' não abriu uma conversa de uma fala dele pela fila de falas (balão: '%s')" % [id, _no_balao(m).left(50)])
	if conversou:
		var dita := _no_balao(m)
		if de_noite:
			var noturnas: Array = d.get("falas_noite", [])
			_conferir(not noturnas.is_empty() and dita == str(IdiomaMenu.campo(noturnas[0], "texto", "")),
				"de noite o E em '%s' não trouxe a primeira fala de noite: '%s'" % [id, dita.left(50)])
		_conferir(dita.length() > 60, "o E em '%s' trouxe a saudação curta, e não a conversa: '%s'" % [id, dita])
		_conferir(m.conversando(), "o E em '%s' não segurou o relógio enquanto ele responde" % id)
		_conferir(avisos.size() == 2 and avisos[1] == dita, "o aviso do HUD do E em '%s' não é a fala inteira" % id)
		var fim = _quem_fala()
		_conferir(fim == m, "a fila diz que quem fala é '%s', e devia ser '%s'" % [str(fim), id])
	m.saudou.disconnect(ao_avisar)
	await _vez_livre()


## Alguma fala deste falante ganhou a vez depois de `desde`, na classe pedida, com `texto` (ou qualquer)?
func _veio_da_fila(m, desde: int, classe: int, texto: String) -> bool:
	for i in range(desde, _comecaram.size()):
		var c: Dictionary = _comecaram[i]
		if c["falante"] == m and int(c["classe"]) == classe and (texto == "" or str(c["texto"]) == texto):
			return true
	return false


func _quem_fala():
	return (fila.atual() as Dictionary).get("falante")


## O que está no balão de quem fala.
func _no_balao(morador) -> String:
	var rotulo = morador.balao.get("_texto")
	return str(rotulo.text) if rotulo != null else ""


## Ao lado do morador, virado para ele: é onde se conversa.
func _ao_lado_de(jogador, morador) -> void:
	var onde: Vector3 = morador.global_position + Vector3(1.0, 0.1, 0.6)
	var para_ele: Vector3 = morador.global_position - onde
	jogador.teleportar(onde, atan2(para_ele.x, para_ele.z))


## Passa a fala que estiver no ar (quem leu não espera o relógio) até a vez ficar livre.
func _vez_livre() -> void:
	await relogio.ate(func() -> bool:
		if fila.livre():
			return true
		fila.pular()
		return false, 20.0)
	await relogio.esperar(0.6)


## FALSIFICAÇÃO. Sem o argumento não mexe em nada. Com `-- --falsificar-falas`: a Mariinha volta a ser
## muda (o E nela não dá balão), o pescador ganha uma saudação em inglês que é cópia do português, o guarda
## perde a fala em espanhol de uma conversa e a fala de noite dele. O portão tem de reprovar em todas.
func _falsificar(moradores_do_arquivo: Array, por_id: Dictionary) -> void:
	if not falsificar:
		return
	for m in moradores_do_arquivo:
		var d: Dictionary = m
		match str(d.get("id", "")):
			"pescador":
				d["saudacoes"][0]["texto_en"] = d["saudacoes"][0]["texto"]
			"guarda":
				d["falas"][2]["texto_es"] = ""
				d.erase("falas_noite")
				d.erase("saudacoes_noite")
	if por_id.has("menina"):
		por_id["menina"].dados["mudo"] = true
	if por_id.has("guarda"):
		por_id["guarda"].dados.erase("falas_noite")
		por_id["guarda"].dados.erase("saudacoes_noite")
	print("  (falsificado: menina muda; pescador com texto_en copiado; guarda sem espanhol numa fala e sem as de noite)")


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


func _mundo_pronto() -> void:
	for i in 3000:
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame


func _fechar() -> void:
	print("")
	_conferir(_no_vale == NOVOS.size() and _de_noite == 1 and _trabalhando == 1,
		"o vale conferiu %d de %d moradores, %d de noite e %d trabalhando: algum caminho do portão não rodou" % [_no_vale, NOVOS.size(), _de_noite, _trabalhando])
	if falhas == 0:
		print("FALAS_DOS_MORADORES_OK: todo morador fala ou é mudo com razão escrita; os catorze que eram mudos têm de 3 a 4 saudações e de 6 a 10 falas nos três idiomas de verdade (nunca cópia do português), com a saudação inteira no balão curto; de noite somam as de noite só quem fica na rua no escuro; no vale o cumprimento sai das saudações e o E das falas, pela fila, com aviso no HUD e relógio parado; o guarda diz as de noite; e o sacristão continua varrendo enquanto fala")
	else:
		print("falas_dos_moradores: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)
