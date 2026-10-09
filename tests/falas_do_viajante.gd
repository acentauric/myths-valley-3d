extends SceneTree
## AS FALAS DO VIAJANTE (#187): o personagem do jogador comenta o que acontece, SÓ EM VOZ e sem balão.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/falas_do_viajante.gd
##
## O viajante era mudo. Seis perguntas:
##
##   1. OS DADOS: os dez gatilhos, nos quatro idiomas, com o nome do áudio `viajante_<gatilho>` e a marcação de
##      interpretação da voz; o sono e o despertar têm 3 ou mais variações, com as contextuais (cansado, chuva,
##      madrugada) marcadas. Os mp3 existem, ou o `voz_pendente` declara a dívida (e some quando eles chegam).
##   2. CADA GATILHO ESTÁ LIGADO: o nome de cada `gatilho` aparece num `_pedir("...")` de falas_do_viajante.gd, e
##      todo pedido do script tem uma fala no arquivo.
##   3. SEM BALÃO: o script não abre balão, caixa de fala nem aviso no HUD.
##   4. O SORTEIO não repete a anterior do grupo, e a variação do contexto passa na frente das comuns.
##   5. NO VALE, a voz toca na vez da fila (classe PASSAGEM), sem balão; não fura quem fala; duas não saem coladas; a
##      de uma vez só não volta, a de intervalo não volta antes dele; o que ele disse vai no save.
##   6. O SONO E O DESPERTAR: deitar na cama diz o sono; acordar diz o despertar (o do contexto); a queda cala; o
##      início do inverno vira o "lá vem chuva" da manhã.
##   7. O SELO (#225): sem balão, um ícone de ondas aparece sobre a cabeça dele enquanto a voz toca, com fade, e
##      some quando ela acaba; a legenda é opcional (Ajustes → Legendas do viajante), DESLIGADA no padrão, e traz o
##      texto do idioma; o selo cede à dica do E (falsificação: um popup em cima dele o apaga) e some com tela aberta.

const GATILHOS := [
	"desceu_do_saveiro", "cansou_correndo", "entrou_no_mar", "entrou_em_casa", "primeira_noite",
	"mochila_cheia", "sem_ferramenta", "primeira_colheita", "chuva_comecando", "perto_do_escuro",
]
const PASTA_VOZES := "res://assets/audio/vozes/"
const SEGUNDOS_DE_PALAVRA := 25.0
## A classe PASSAGEM da fila de falas (`FilaDeFalas.Classe`): a que não fura ninguém.
const PASSAGEM := 3
## A classe MISSAO.
const MISSAO := 1

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("FALAS_DO_VIAJANTE_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	var arquivo = JSON.parse_string(FileAccess.get_file_as_string("res://data/falas_viajante.json"))
	_conferir(arquivo is Dictionary, "o falas_viajante.json não abre")
	if not (arquivo is Dictionary):
		_fechar()
		return
	var dados: Dictionary = arquivo

	# --- 1. OS DADOS ---------------------------------------------------------------------------------
	var voz: Dictionary = dados.get("voz", {})
	_conferir(str(voz.get("id", "")) != "" and str(voz.get("modelo", "")) == "eleven_v3", "o viajante sem voz (id e modelo eleven_v3)")
	var falas: Array = dados.get("falas", [])
	_conferir(falas.size() == GATILHOS.size(), "o viajante tem %d fala(s) de gatilho, e são %d" % [falas.size(), GATILHOS.size()])
	var vistos := {}
	var audios: Array = []
	for i in falas.size():
		var fala: Dictionary = falas[i]
		var g := str(fala.get("gatilho", ""))
		_conferir(g in GATILHOS and not vistos.has(g), "falas[%d]: gatilho '%s' desconhecido ou repetido" % [i, g])
		vistos[g] = true
		_conferir_fala(fala, "falas[%d] (%s)" % [i, g], "viajante_" + g)
		_conferir(bool(fala.get("uma_vez", false)) or float(fala.get("intervalo", 0.0)) >= 0.0, "falas[%d] (%s): intervalo negativo" % [i, g])
		audios.append(str(fala.get("audio", "")))
	for g: String in GATILHOS:
		_conferir(vistos.has(g), "falta a fala do gatilho '%s'" % g)
	var sono: Array = dados.get("sono", [])
	var despertar: Array = dados.get("despertar", [])
	_conferir(sono.size() >= 3 and sono.size() <= 4, "o sono tem %d variação(ões), e o pedido é de 3 a 4" % sono.size())
	_conferir(despertar.size() >= 3 and despertar.size() <= 5, "o despertar tem %d variação(ões), e o pedido é de 3 a 5" % despertar.size())
	for i in sono.size():
		_conferir_fala(sono[i], "sono[%d]" % i, "viajante_sono_%d" % (i + 1))
		audios.append(str((sono[i] as Dictionary).get("audio", "")))
	for i in despertar.size():
		_conferir_fala(despertar[i], "despertar[%d]" % i, "viajante_despertar_%d" % (i + 1))
		audios.append(str((despertar[i] as Dictionary).get("audio", "")))
	_conferir(_tem_contexto(sono, "cansado"), "o sono não tem a variação do corpo cansado")
	_conferir(_tem_contexto(despertar, "chuva"), "o despertar não tem a variação da chuva")
	_conferir(_tem_contexto(despertar, "madrugada"), "o despertar não tem a variação de quem dormiu tarde")
	var comuns_do_sono := 0
	for fala in sono:
		comuns_do_sono += 1 if str((fala as Dictionary).get("quando", "")) == "" else 0
	var comuns_do_despertar := 0
	for fala in despertar:
		comuns_do_despertar += 1 if str((fala as Dictionary).get("quando", "")) == "" else 0
	_conferir(comuns_do_sono >= 2 and comuns_do_despertar >= 2, "sem duas variações comuns por grupo o sorteio repetiria a anterior")
	var faltam := 0
	for nome: String in audios:
		var caminho := PASTA_VOZES + nome + ".mp3"
		if not FileAccess.file_exists(caminho) or not FileAccess.file_exists(caminho + ".import"):
			faltam += 1
	if str(dados.get("voz_pendente", "")) != "":
		_conferir(faltam > 0, "o voz_pendente sobrou: todos os áudios do viajante já existem, tire a marca do arquivo")
	else:
		_conferir(faltam == 0, "faltam %d áudio(s) do viajante (ou o import deles) e o arquivo não declara voz_pendente" % faltam)

	# --- 2 e 3. O CÓDIGO ---------------------------------------------------------------------------------
	var codigo := FileAccess.get_file_as_string("res://scripts/prototipo_3d/falas_do_viajante.gd")
	for g: String in GATILHOS:
		_conferir(codigo.contains("_pedir(\"%s\"" % g), "o gatilho '%s' não é pedido em lugar nenhum do falas_do_viajante.gd" % g)
	var cursor := 0
	while true:
		var achou := codigo.find("_pedir(\"", cursor)
		if achou < 0:
			break
		var fim := codigo.find("\"", achou + 8)
		var nome := codigo.substr(achou + 8, fim - achou - 8)
		_conferir(vistos.has(nome), "o falas_do_viajante.gd pede '%s', e o arquivo não tem essa fala" % nome)
		cursor = fim
	# Sem balão, sem caixa, sem aviso no HUD: o código que roda não cita nenhum (os comentários não contam).
	var sem_comentarios := ""
	for linha in codigo.split("\n"):
		if not linha.strip_edges().begins_with("##") and not linha.strip_edges().begins_with("#"):
			sem_comentarios += linha + "\n"
	for proibido in ["mostrar_balao", "balao.", "BalaoFala", "Dialogo.falar", "set_notice", "show_house_info", "narrar("]:
		_conferir(not sem_comentarios.contains(proibido), "o viajante usa '%s': a fala dele é só voz, sem balão nem caixa" % proibido)

	# --- 7a. O SELO: o ajuste e os textos ----------------------------------------------------------------
	var Selo = load("res://scripts/prototipo_3d/selo_do_viajante.gd")
	var painel := FileAccess.get_file_as_string("res://scripts/prototipo_3d/painel_ajustes.gd")
	_conferir(painel.contains("\"Legendas do viajante\"") and painel.contains("SeloDoViajante.definir_legendas"), "Ajustes não tem o campo 'Legendas do viajante'")
	_conferir(Selo.ROTULOS == ["Ligadas", "Desligadas"] and Selo.PADRAO == 1, "as legendas do viajante devem ser Ligadas/Desligadas e vir DESLIGADAS no padrão")
	var ajuda := FileAccess.get_file_as_string("res://scripts/prototipo_3d/ajuda_menu.gd")
	var idioma := FileAccess.get_file_as_string("res://scripts/prototipo_3d/idioma_menu.gd")
	_conferir(ajuda.contains("\"Legendas do viajante\": ["), "o ajuste das legendas do viajante não tem o texto de ajuda")
	_conferir(idioma.count("\"Legendas do viajante\":") >= 2, "'Legendas do viajante' não está traduzido para o inglês e o espanhol")
	var legendas_de_antes: int = Selo.modo_das_legendas()
	Selo.definir_legendas(0)
	Selo.esquecer_as_legendas()
	_conferir(Selo.legendas_ligadas(), "as legendas ligadas não voltaram do arquivo de preferências")
	Selo.definir_legendas(Selo.PADRAO)
	Selo.esquecer_as_legendas()
	_conferir(not Selo.legendas_ligadas(), "as legendas desligadas (o padrão) não voltaram do arquivo de preferências")

	# --- 4. O SORTEIO E 5, 6. NO VALE ------------------------------------------------------------------
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(3)
	var jogo := current_scene
	var jogador = jogo.get("player")
	var pedro = jogo.get("pedro")
	var v = jogo.get("viajante")
	var fila = jogo.get("fila_de_falas")
	_conferir(jogador != null and v != null and fila != null, "não achei o jogador, o viajante ou a fila de falas no vale")
	if jogador == null or v == null or fila == null:
		_fechar()
		return
	if pedro != null:
		pedro._cadeia.espera = 0.0

	# 4. Sorteio: sem repetir a anterior; a do contexto passa na frente.
	for grupo in ["sono", "despertar"]:
		v._ultima_do_grupo.erase(grupo)
		var anterior := ""
		var repetiu := false
		for i in 60:
			var sorteada: Dictionary = v.sortear(grupo, [])
			var audio := str(sorteada.get("audio", ""))
			repetiu = repetiu or audio == "" or audio == anterior or str(sorteada.get("quando", "")) != ""
			anterior = audio
			v._ultima_do_grupo[grupo] = audio
		_conferir(not repetiu, "o sorteio do '%s' repetiu a anterior, veio vazio ou trouxe uma variação de contexto sem pedir" % grupo)
	v._ultima_do_grupo.clear()
	_conferir(str(v.sortear("despertar", ["chuva"]).get("quando", "")) == "chuva", "com chuva o despertar não trouxe a variação da chuva")
	_conferir(str(v.sortear("despertar", ["madrugada", "chuva"]).get("quando", "")) == "madrugada", "a madrugada devia passar na frente da chuva")
	_conferir(str(v.sortear("sono", ["cansado"]).get("quando", "")) == "cansado", "cansado, o sono não trouxe a variação do cansaço")
	v._ultima_do_grupo["despertar"] = str(v.sortear("despertar", ["chuva"]).get("audio", ""))
	_conferir(str(v.sortear("despertar", ["chuva"]).get("quando", "")) == "", "a variação da chuva repetiu a anterior do despertar")
	v._ultima_do_grupo.clear()

	# 5. A voz toca na vez da fila, sem balão.
	v.voz_de_prova = _voz_muda(2.0)
	var avisos := [0, 0, ""]
	v.comecou_a_falar.connect(func(texto: String, _segundos: float) -> void:
		avisos[0] += 1
		avisos[2] = texto)
	v.calou_a_voz.connect(func() -> void: avisos[1] += 1)
	await _palavra_livre(fila, SEGUNDOS_DE_PALAVRA)
	var historico_antes: int = fila.historico.size()
	v._pedir("mochila_cheia", 4.0)
	_conferir(v._pedidos.has("mochila_cheia"), "o gatilho da mochila cheia não pediu a fala")
	var disse := await _ate(func() -> bool: return v._quando.has("mochila_cheia"), 8.0)
	_conferir(disse, "o viajante não disse a fala da mochila cheia com a palavra livre")
	_conferir(not v._pedidos.has("mochila_cheia"), "a fala da mochila foi dita e o pedido ficou")
	var tocou := await _ate(func() -> bool: return v._voz.playing, 3.0)
	_conferir(tocou, "a voz do viajante não tocou")
	_conferir(int(avisos[0]) == 1 and str(avisos[2]) != "", "a voz começou e o viajante não avisou (uma vez, com o texto) para o selo")
	var acabou := await _ate(func() -> bool: return int(avisos[1]) >= 1, 8.0)
	_conferir(acabou, "a voz acabou e o viajante não avisou para o selo")
	_conferir(fila.historico.size() > historico_antes, "a fala do viajante não passou pela fila de falas")
	var passou_de_passagem := false
	for i in range(historico_antes, fila.historico.size()):
		var trecho: Dictionary = fila.historico[i]
		passou_de_passagem = passou_de_passagem or (str(trecho.get("falante", "")) == "FalasDoViajante" and int(trecho.get("classe", -1)) == PASSAGEM)
	_conferir(passou_de_passagem, "a fala do viajante devia passar pela fila como PASSAGEM, e não passou")
	# Sem balão: nenhum balão de morador aberto por causa dele.
	for no in get_nodes_in_group("moradores"):
		if "balao" in no and no.balao != null:
			_conferir(not no.balao.visible, "um balão abriu enquanto o viajante falava")

	# Duas não saem coladas: o pedido espera a pausa.
	var ultima: int = v._ultima_ms
	v._pedir("sem_ferramenta", 6.0)
	_conferir(v._pedidos.has("sem_ferramenta"), "o pedido da ferramenta não entrou")
	await _ate(func() -> bool: return false, 1.5)
	_conferir(not v._quando.has("sem_ferramenta") and v._ultima_ms == ultima, "duas falas do viajante saíram coladas (a pausa não valeu)")
	v._pedidos.clear()
	# De uma vez só não volta; de intervalo não volta antes dele.
	v._ditas["primeira_colheita"] = true
	v._pedir("primeira_colheita", 20.0)
	_conferir(not v._pedidos.has("primeira_colheita"), "a fala da primeira colheita voltou depois de dita")
	v._pedir("mochila_cheia", 4.0)
	_conferir(not v._pedidos.has("mochila_cheia"), "a fala da mochila cheia voltou antes do intervalo")
	v._quando["mochila_cheia"] = Time.get_ticks_msec() - 400000
	v._pedir("mochila_cheia", 4.0)
	_conferir(v._pedidos.has("mochila_cheia"), "passado o intervalo, a mochila cheia não pôde ser pedida")
	v._pedidos.clear()
	# Não fura quem fala: com outra fala no ar, a palavra não está livre.
	await _palavra_livre(fila, SEGUNDOS_DE_PALAVRA)
	fila.pedir({"falante": jogo, "texto": "Outra fala qualquer.", "classe": MISSAO, "segundos": 6.0})
	_conferir(not v._palavra_livre(), "o viajante acharia a palavra livre com outra fala no ar")
	fila.calar_falante(jogo)
	# Salva e devolve o que era de uma vez só.
	var guardado: Dictionary = v.estado_para_salvar()
	_conferir((guardado.get("ditas", []) as Array).has("primeira_colheita"), "o save do viajante não guardou a primeira colheita")
	v._ditas.clear()
	v.restaurar(guardado)
	_conferir(v._ditas.has("primeira_colheita"), "o viajante não lembrou a primeira colheita depois de restaurar")
	v._ditas.clear()
	v._quando.clear()

	# 6. O sono e o despertar.
	v._ultima_ms = -1000000
	v._ultima_do_grupo.clear()
	await _palavra_livre(fila, SEGUNDOS_DE_PALAVRA)
	v._ao_deitar("cama")
	# Como em queda.gd: o jogador deitado perde o physics_process logo depois do aviso, e a fala sai assim mesmo.
	jogador.set_physics_process(false)
	var dormiu := await _ate(func() -> bool: return v._ultima_do_grupo.has("sono"), 6.0)
	jogador.set_physics_process(true)
	_conferir(dormiu, "deitar na cama não disse o sono")
	v._ao_acordar()
	_conferir(v._pedidos.has("despertar"), "acordar não pediu o despertar")
	var acordou := await _ate(func() -> bool: return v._ultima_do_grupo.has("despertar"), 40.0)
	_conferir(acordou, "acordar não disse o despertar com a palavra livre")
	# A queda cala: quem apagou machucado não comenta.
	v._pedidos.clear()
	v._ultima_do_grupo.clear()
	v._ao_deitar("queda")
	v._ao_acordar()
	_conferir(v._pedidos.is_empty() and v._ultima_do_grupo.is_empty(), "o viajante falou depois de uma queda")
	# O desmaio das duas: o corpo cansado e a madrugada pedem a variação deles.
	v._ao_deitar("desmaio")
	v._pedidos.clear()
	v._ao_acordar()
	_conferir(v._pedidos.has("despertar") and str((v._pedidos["despertar"]["fala"] as Dictionary).get("quando", "")) == "madrugada",
		"quem desmaiou das duas devia acordar com a variação da madrugada")
	# O inverno que começou durante o sono vira o "lá vem chuva" da manhã.
	v._pedidos.clear()
	v._ao_deitar("cama")
	v._ao_mudar_a_estacao(3)
	v._pedidos.clear()
	v._ao_acordar()
	_conferir(v._pedidos.has("chuva_comecando"), "o início do inverno não virou o 'lá vem chuva' ao acordar")
	v._pedidos.clear()
	v._ultima_ms = -1000000
	await _o_selo(jogo, jogador, v, Selo)
	Selo.definir_legendas(legendas_de_antes)
	Selo.esquecer_as_legendas()
	_fechar()


## 7. O SELO no vale: aparece sobre a cabeça com a voz, com fade, cede à dica do E, traz a legenda só se ligada.
func _o_selo(jogo: Node, jogador: Node, v: Node, Selo: GDScript) -> void:
	var selo = jogo.get("selo_do_viajante")
	_conferir(selo != null, "o vale não montou o selo do viajante")
	if selo == null:
		return
	selo.coberto = Callable()
	selo.permitir(true)
	Selo.definir_legendas(1)
	Selo.esquecer_as_legendas()
	var camera: Camera3D = root.get_camera_3d()
	_conferir(camera != null and camera == jogador.get("camera"), "a câmera do vale não é a do jogador: o selo não pode aparecer")
	_conferir(not selo.visible and selo.alfa_do_icone == 0.0, "o selo apareceu sem o viajante falar")
	# A voz começa: o ícone entra com fade, sobre a cabeça (o pé do ícone está acima do alto da cabeça).
	v.comecou_a_falar.emit("Lá vem chuva.", 8.0)
	await process_frame
	await process_frame
	_conferir(selo.falando, "o selo não soube que o viajante começou a falar")
	_conferir(selo.alfa_do_icone < 1.0, "o ícone apareceu de uma vez, sem fade de entrada")
	var entrou := await _ate(func() -> bool: return selo.alfa_do_icone >= 0.99, 3.0)
	_conferir(entrou, "o ícone de fala não acendeu sobre o viajante (alfa %.2f)" % selo.alfa_do_icone)
	var icone: Rect2 = selo.retangulo()
	var tela := root.get_visible_rect()
	_conferir(icone.size != Vector2.ZERO and tela.encloses(icone), "o ícone de fala ficou fora da tela: %s" % icone)
	var altura: float = jogo.get("placas").altura_do(jogador)
	var topo_da_cabeca := camera.unproject_position(jogador.global_position + Vector3.UP * altura).y
	_conferir(icone.end.y <= topo_da_cabeca + 1.0, "o ícone cobre o rosto: o pé dele (%.0f) passa do alto da cabeça (%.0f)" % [icone.end.y, topo_da_cabeca])
	# A legenda é opcional: desligada, não há caixa nenhuma.
	_conferir(selo.retangulo_da_legenda() == Rect2() and selo.alfa_da_legenda == 0.0, "a legenda apareceu com as legendas desligadas")
	# Cede à dica do E: um popup em cima do ícone o apaga, e quando sai, o ícone volta.
	var dica := Control.new()
	dica.add_to_group("dicas_de_tecla")
	dica.position = icone.position - Vector2(10, 10)
	dica.size = icone.size + Vector2(20, 20)
	selo.get_parent().add_child(dica)
	var cedeu := await _ate(func() -> bool: return selo.alfa_do_icone <= 0.01, 3.0)
	_conferir(cedeu, "o selo não cedeu à dica do E que caiu em cima dele")
	dica.free()
	var voltou := await _ate(func() -> bool: return selo.alfa_do_icone >= 0.99, 3.0)
	_conferir(voltou, "o selo não voltou depois que a dica do E saiu")
	# A legenda ligada traz o texto do idioma e fica acima do ícone.
	Selo.definir_legendas(0)
	v.comecou_a_falar.emit("Escureceu rápido.", 8.0)
	var com_legenda := await _ate(func() -> bool: return selo.alfa_da_legenda >= 0.99, 3.0)
	_conferir(com_legenda, "com as legendas ligadas a legenda não apareceu (alfa %.2f)" % selo.alfa_da_legenda)
	var caixa: Rect2 = selo.retangulo_da_legenda()
	_conferir(caixa.size != Vector2.ZERO and caixa.end.y <= selo.retangulo().position.y, "a legenda devia ficar acima do ícone: %s / %s" % [caixa, selo.retangulo()])
	_conferir(str(selo._texto.text) == "Escureceu rápido.", "a legenda não traz o texto da fala")
	# Uma tela aberta apaga o selo na hora, e a voz que acaba o apaga com fade.
	selo.permitir(false)
	_conferir(not selo.visible and selo.alfa_do_icone == 0.0, "o selo ficou na tela com uma tela aberta por cima")
	selo.permitir(true)
	v.calou_a_voz.emit()
	var saiu := await _ate(func() -> bool: return selo.alfa_do_icone <= 0.01 and selo.alfa_da_legenda <= 0.01 and not selo.visible, 3.0)
	_conferir(saiu, "o selo não saiu de cena quando a voz acabou")
	_conferir(not selo.falando, "o selo ainda acha que o viajante fala")


## Os campos de uma fala: o texto nos quatro idiomas, a marcação da voz e o nome do áudio.
func _conferir_fala(fala: Dictionary, rotulo: String, audio: String) -> void:
	for chave in ["texto", "texto_en", "texto_es", "texto_zh", "tts"]:
		_conferir(str(fala.get(chave, "")) != "", "%s sem o campo %s" % [rotulo, chave])
	_conferir(str(fala.get("audio", "")) == audio, "%s: o áudio devia se chamar %s" % [rotulo, audio])
	_conferir(str(fala.get("tts", "")).contains("["), "%s: o tts sem marcação de interpretação do v3" % rotulo)
	_conferir(str(fala.get("texto_en", "")) != str(fala.get("texto", "")), "%s: o inglês é cópia do português" % rotulo)


func _tem_contexto(lista: Array, contexto: String) -> bool:
	for fala in lista:
		if str((fala as Dictionary).get("quando", "")) == contexto:
			return true
	return false


## Silêncio no lugar do mp3 (que pode não existir ainda).
func _voz_muda(segundos: float) -> AudioStreamWAV:
	var onda := AudioStreamWAV.new()
	onda.format = AudioStreamWAV.FORMAT_16_BITS
	onda.mix_rate = 22050
	var bytes := PackedByteArray()
	bytes.resize(int(22050.0 * 2.0 * segundos))
	onda.data = bytes
	return onda


func _palavra_livre(fila: Node, segundos: float) -> bool:
	var limite := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < limite:
		if fila.livre():
			return true
		fila.pular()
		await process_frame
	return fila.livre()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("FALAS_DO_VIAJANTE_OK: o selo de ondas aparece sobre a cabeça dele com a voz, com fade, cede à dica do E e a legenda só vem se ligada; as dez falas do viajante e as variações de sono e despertar têm os quatro idiomas e a voz nomeada, cada gatilho está ligado no código, não há balão, o sorteio não repete e o contexto passa na frente, a voz toca na vez da fila sem furar ninguém, duas não saem coladas, a de uma vez só e a de intervalo não repetem, o save lembra, e deitar, acordar e cair falam (ou calam) como devem")
	else:
		print("falas_do_viajante: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _ate(condicao: Callable, segundos: float) -> bool:
	var limite := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < limite:
		if condicao.call():
			return true
		await process_frame
	return condicao.call()


func _frames(count: int) -> void:
	for frame in range(count):
		await process_frame


func _mundo_pronto() -> void:
	for i in range(3000):
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
