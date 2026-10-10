extends "res://tests/suite/caso.gd"
## A MÚSICA ACOMPANHA O DIA, NO VALE DE VERDADE: o relógio anda pelos cinco períodos
## (madrugada, manhã, tarde, entardecer, noite) e a trilha que toca troca a cada um
## que tem trilha própria, em fusão — a atual desce, o fluxo muda no fundo, a nova sobe.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste musica_do_dia
##
## "Senti falta da mudança de trilha entre os períodos do dia" (playtest da Build 9B). O
## `audio_fade` só mexe nas trilhas do menu, com fluxos sintéticos; nada garantia que o
## relógio do VALE chegasse à música. Este portão sobe o vale como o jogador o sobe (o
## menu fixa a hora e segura o relógio na carga, o `prototype.gd` solta quando fica de
## pé) e pergunta, com as trilhas de verdade:
##
##   0. CADA PERÍODO TEM A SUA TRILHA, e a de um período é outra que a do período vizinho: o HUD
##      anuncia cinco períodos, e até a Build 9B só havia três trilhas (o entardecer repetia a tarde,
##      a madrugada, a noite) — o jogador via o período virar e a música seguir igual.
##   1. NA ENTRADA toca a trilha do período da hora de partida, audível: tocando, no
##      barramento Geral (o do botão de som), com volume que se ouve.
##   2. O RELÓGIO ANDA O DIA INTEIRO, em passos de quadro como o do jogo, e em cada
##      virada de período: a atual DESCE (o ganho cai), o fluxo troca com o ganho no fundo
##      e a nova SOBE de volta — sem corte seco e sem silêncio que fique. (Se um período
##      voltar a repetir a trilha do vizinho, o portão confere que NADA recomeça à toa; mas a
##      pergunta 0 já o reprova.)
##   3. CARREGAR UMA PARTIDA SALVA em cada período (`restaurar_do_save`, o mesmo caminho do
##      `Salvamento`): a trilha do vale passa para a daquela hora, qualquer que seja a
##      que tocava.
##   4. NADA POR CIMA SEQUESTRA A TRILHA do jogo: escolher a "Trilha do menu" em AJUSTAR
##      com o vale aberto guarda a escolha para o menu e não troca a música do jogo; e a
##      trilha de tensão da mata cobre o período enquanto o jogador está lá (a hora
##      passando não a tira) e devolve a do período CERTO ao sair.
##   5. A TRILHA DA MATA PRESA de uma partida que acabou caçada não vira a música de uma
##      partida nova: o `AmbienteVale` que nasce desliga a tensão que não é dele.
##
## FALSIFICAÇÃO: com `MV_FALSIFICAR=musica` o `Audio` deixa de ouvir o relógio (o sinal
## `hora_mudou` é desligado dele): as perguntas 2 e 3 têm de FALHAR (o portão sai vermelho).
## Revertendo o código: `entardecer` apontando para a trilha da tarde reprova a 0; tirar a guarda de
## `definir_musica_menu` (o vale aberto) reprova a 4; tirar o `Audio.tocar_musica_mata(false)` do
## `AmbienteVale._ready` reprova a 5. A espera é em segundos DE JOGO (`tests/fixtures/relogio_de_jogo.gd`).

const RelogioDeJogo = preload("res://tests/fixtures/relogio_de_jogo.gd")

## Quanto o relógio anda por quadro ao percorrer o dia: miúdo, como o do jogo, e longe do
## 02:00 do desmaio (que só o `avancar` anuncia; aqui anda-se por `definir_hora`).
const PASSO_H := 0.05
## A troca dura o `FADE_MUSICA` do Audio (2,5 s) e o gate dá folga de sobra.
const ESPERA_DA_TROCA_S := 7.0
## Abaixo disto o ganho da trilha está "descido" — o fundo da fusão.
const GANHO_DE_FUNDO := 0.35
## Os períodos, uma hora no MEIO de cada um (nunca a menos de 0,4 h da virada).
const PERIODOS := [["madrugada", 3.0], ["manha", 8.0], ["tarde", 14.0], ["entardecer", 17.9], ["noite", 21.0]]

var falhas := 0
var falsificar := ""
var relogio
var audio
var dia
var vale
## O que o quadro viu da música desde o último `_zerar_amostras`: {ganho, stream, tocando}.
var amostras: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		falhas += 1
		push_error("MUSICA_DO_DIA_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)


func _run() -> void:
	falsificar = OS.get_environment("MV_FALSIFICAR")
	audio = root.get_node("/root/Audio")
	dia = root.get_node("/root/Dia")
	relogio = RelogioDeJogo.new()
	root.add_child(relogio)
	if falsificar != "":
		print("  FALSIFICAÇÃO: ", falsificar, " (MV_FALSIFICAR)")

	_cada_periodo_tem_a_sua()

	# COMO O MENU ENTREGA O JOGO: a hora de partida fixada e o relógio segurado na carga.
	dia.pausado = false
	dia.definir_hora(7.0)
	dia.congelado_na_carga = true
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "o vale não carregou")
	await _frames(6)
	await _mundo_pronto()
	vale = current_scene
	# O vale só solta o relógio quando termina de se montar: é o "entrei no jogo".
	await relogio.ate(func() -> bool: return not dia.congelado_na_carga, 90.0)
	_conferir(not dia.congelado_na_carga, "o vale não soltou o relógio da carga")
	# O relógio do portão é o do portão: parado, para a hora só andar por onde o gate manda.
	dia.pausado = true
	if falsificar == "musica" and dia.hora_mudou.is_connected(audio._ao_mudar_hora):
		dia.hora_mudou.disconnect(audio._ao_mudar_hora)

	# 1. NA ENTRADA.
	await _esperar_trilha(audio.MUSICAS_PERIODO["manha"], "entrada às 07:00 (manhã)")
	_conferir(String(dia.periodo()) == "manha", "a hora de partida não é de manhã (%s)" % dia.periodo())
	_conferir_audivel("na entrada")

	# 2. O DIA INTEIRO, em passos de quadro: manhã → tarde → entardecer → noite → madrugada → manhã.
	var antes := "manha"
	for passo in [["tarde", 14.0], ["entardecer", 17.9], ["noite", 21.0], ["madrugada", 3.0], ["manha", 8.0]]:
		var periodo: String = passo[0]
		await _andar_o_relogio(float(passo[1]), antes, periodo)
		antes = periodo
	# De volta à manhã: o dia fechou o círculo.

	# 3. A PARTIDA SALVA em cada período, em ordem embaralhada (de cada um para o que não o segue).
	for periodo in ["noite", "manha", "entardecer", "madrugada", "tarde", "noite", "manha"]:
		await _carregar_partida_em(periodo)

	# 4. NADA SEQUESTRA A TRILHA.
	await _trilha_do_menu_nao_sequestra()
	await _mata_cobre_e_devolve()

	# 5. A MATA PRESA de uma partida anterior.
	await _mata_presa_nao_contamina()

	print("MUSICA_DO_DIA: trilha final %s" % audio.musica_atual().get_file())
	if falhas == 0:
		print("MUSICA_DO_DIA_OK: a trilha acompanha o relógio nos cinco períodos, na entrada, na partida salva, e nada a sequestra")
	quit(0 if falhas == 0 else 1)


## 0. Cinco períodos, cinco trilhas, e nenhuma igual à do período vizinho no ciclo do dia.
func _cada_periodo_tem_a_sua() -> void:
	var ciclo := ["madrugada", "manha", "tarde", "entardecer", "noite"]
	var vistas := {}
	for periodo in ciclo:
		_conferir(audio.MUSICAS_PERIODO.has(periodo), "o período '%s' não tem trilha" % periodo)
		var caminho: String = audio.MUSICAS_PERIODO.get(periodo, "")
		_conferir(ResourceLoader.exists(caminho), "a trilha do período '%s' (%s) não existe" % [periodo, caminho])
		vistas[caminho] = true
	_conferir(vistas.size() == ciclo.size(), "os %d períodos usam só %d trilhas diferentes: o HUD anuncia um período e a música segue igual" % [ciclo.size(), vistas.size()])
	for i in range(ciclo.size()):
		var este: String = ciclo[i]
		var seguinte: String = ciclo[(i + 1) % ciclo.size()]
		_conferir(audio.MUSICAS_PERIODO.get(este, "a") != audio.MUSICAS_PERIODO.get(seguinte, "b"), "'%s' e '%s' tocam a mesma trilha: a virada do período não se ouve" % [este, seguinte])


## O relógio vai de onde está até `hora_alvo` (0–24, sempre para a frente, passando da meia-noite
## se for preciso), em passos de PASSO_H, um por quadro, e confere a virada: o que ela faz com a
## trilha.
func _andar_o_relogio(hora_alvo: float, de: String, para: String) -> void:
	var trilha_de: String = audio.MUSICAS_PERIODO[de]
	var trilha_para: String = audio.MUSICAS_PERIODO[para]
	var fluxo_antes: AudioStream = audio._musica.stream
	_zerar_amostras()
	var inicio := float(dia.hora)
	var falta := fposmod(hora_alvo - inicio, 24.0)
	var andado := 0.0
	while andado < falta - 0.0001:
		andado = minf(andado + PASSO_H, falta)
		dia.definir_hora(inicio + andado)
		_amostrar()
		await process_frame
	_conferir(String(dia.periodo()) == para, "o relógio chegou a %s e o período é %s, e não %s" % [dia.texto_hora(), dia.periodo(), para])
	var chegou := await _esperar_trilha(trilha_para, "%s → %s" % [de, para])
	_conferir(chegou, "%s → %s: a trilha não ficou sendo %s" % [de, para, trilha_para.get_file()])
	if trilha_de != trilha_para:
		var menor := 1.0
		var troca_com_ganho := -1.0
		var visto_antes: AudioStream = fluxo_antes
		for a in amostras:
			menor = minf(menor, float(a["ganho"]))
			if a["stream"] != visto_antes and troca_com_ganho < 0.0:
				troca_com_ganho = float(a["ganho"])
			visto_antes = a["stream"]
		_conferir(menor < GANHO_DE_FUNDO, "%s → %s: a fusão não desceu a trilha (ganho mínimo %.2f)" % [de, para, menor])
		_conferir(troca_com_ganho >= 0.0 and troca_com_ganho < GANHO_DE_FUNDO, "%s → %s: o fluxo trocou com o ganho em %.2f, e não no fundo da fusão" % [de, para, troca_com_ganho])
		print("MUSICA_DO_DIA: %s → %s: %s → %s, ganho mínimo %.2f, troca com ganho %.2f" % [de, para, trilha_de.get_file(), trilha_para.get_file(), menor, troca_com_ganho])
	else:
		var recomecou := false
		for a in amostras:
			if a["stream"] != fluxo_antes or float(a["ganho"]) < 0.99:
				recomecou = true
		_conferir(not recomecou, "%s → %s: a mesma trilha recomeçou à toa" % [de, para])
		print("MUSICA_DO_DIA: %s → %s: a trilha segue (%s), sem recomeçar" % [de, para, trilha_para.get_file()])
	_conferir_audivel("%s → %s" % [de, para])


## CARREGAR PARTIDA: o vale está num período qualquer, a partida salva diz outra hora.
func _carregar_partida_em(periodo: String) -> void:
	var hora := 0.0
	for p in PERIODOS:
		if p[0] == periodo:
			hora = float(p[1])
	_zerar_amostras()
	vale.restaurar_do_save({"hora": hora})
	# O `restaurar_do_save` devolve o relógio ao que a partida guardou: parado de novo.
	dia.pausado = true
	var trilha: String = audio.MUSICAS_PERIODO[periodo]
	var chegou := await _esperar_trilha(trilha, "partida salva em %s" % periodo)
	_conferir(chegou, "partida salva às %s (%s): a trilha não passou a %s" % [dia.texto_hora(), periodo, trilha.get_file()])
	_conferir(String(dia.periodo()) == periodo, "a partida salva às %02d:00 não está em %s" % [int(hora), periodo])
	_conferir_audivel("partida salva em %s" % periodo)


## ESCOLHER A "TRILHA DO MENU" EM AJUSTAR COM O VALE ABERTO (painel_ajustes.gd) só guarda a
## preferência: a música do jogo, que segue o dia, não é a do menu.
func _trilha_do_menu_nao_sequestra() -> void:
	dia.definir_hora(8.0)
	await _esperar_trilha(audio.MUSICAS_PERIODO["manha"], "antes de mexer na trilha do menu")
	var fluxo: AudioStream = audio._musica.stream
	var opcao_anterior: int = audio.musica_menu_opcao
	audio.definir_musica_menu(2 if opcao_anterior != 2 else 3)
	await relogio.esperar(ESPERA_DA_TROCA_S)
	_conferir(audio._musica.stream == fluxo, "a escolha da trilha do menu trocou a música do jogo")
	_conferir(audio.musica_atual() == audio.MUSICAS_PERIODO["manha"], "a música do jogo passou a ser %s" % audio.musica_atual().get_file())
	_conferir(audio.musica_menu_opcao != opcao_anterior, "a escolha da trilha do menu não ficou guardada")
	# E o dia continua mandando depois dela: o relógio passa ao meio-dia e a trilha acompanha.
	dia.definir_hora(14.0)
	await _esperar_trilha(audio.MUSICAS_PERIODO["tarde"], "depois de mexer na trilha do menu")
	_conferir(audio.musica_atual() == audio.MUSICAS_PERIODO["tarde"], "depois de escolher a trilha do menu o dia deixou de mandar na música")
	audio.definir_musica_menu(opcao_anterior)


## A TENSÃO DA MATA cobre a trilha do período enquanto o jogador está lá, e devolve a do
## período CERTO — o de agora, e não o de quando entrou — ao sair.
func _mata_cobre_e_devolve() -> void:
	dia.definir_hora(11.7)
	await _esperar_trilha(audio.MUSICAS_PERIODO["manha"], "antes da mata")
	audio.tocar_musica_mata(true)
	var chegou := await _esperar_trilha(audio.MUSICA_MATA, "entrando na mata")
	_conferir(chegou, "a trilha da mata não entrou")
	# A manhã vira tarde com o jogador na mata: a hora passando não tira a tensão.
	var hora := float(dia.hora)
	while hora < 12.3:
		hora += PASSO_H
		dia.definir_hora(hora)
		await process_frame
	await relogio.esperar(ESPERA_DA_TROCA_S)
	_conferir(audio.musica_atual() == audio.MUSICA_MATA, "o relógio virou o período e tirou a tensão da mata (%s)" % audio.musica_atual().get_file())
	audio.tocar_musica_mata(false)
	var voltou := await _esperar_trilha(audio.MUSICAS_PERIODO["tarde"], "saindo da mata")
	_conferir(voltou, "ao sair da mata a trilha não foi a da TARDE de agora (%s)" % audio.musica_atual().get_file())


## UMA PARTIDA QUE ACABOU COM A ONÇA CAÇANDO deixa a tensão ligada no autoload; o vale novo
## (trocar o estilo recarrega a cena sem passar pelo menu) tem de começar sem ela.
func _mata_presa_nao_contamina() -> void:
	dia.definir_hora(8.0)
	await _esperar_trilha(audio.MUSICAS_PERIODO["manha"], "antes da mata presa")
	# O estado velho: a tensão ligada no autoload, sem ninguém na mata.
	audio._mata_ativa = true
	audio._cruzar_musica(audio.MUSICA_MATA, 0.5)
	await _esperar_trilha(audio.MUSICA_MATA, "mata presa de uma partida anterior")
	# O vale novo nasce: o `AmbienteVale` é quem confere a mata, e o primeiro que ele faz é
	# desligar a tensão que não é dele.
	var ambiente: Node3D = load("res://scripts/prototipo_3d/ambiente_vale.gd").new()
	vale.add_child(ambiente)
	var voltou := await _esperar_trilha(audio.MUSICAS_PERIODO["manha"], "o vale novo depois da mata presa")
	_conferir(voltou, "o vale novo herdou a trilha da mata presa (%s)" % audio.musica_atual().get_file())
	ambiente.queue_free()


## Espera a trilha `caminho` ficar ESCUTÁVEL: é a do autoload, o fluxo é o dela, está tocando e o ganho
## voltou ao cheio. Devolve se chegou lá dentro de ESPERA_DA_TROCA_S de jogo.
func _esperar_trilha(caminho: String, onde: String) -> bool:
	var chegou: bool = await _ate_quadro(func() -> bool:
		return audio.musica_atual() == caminho and audio._musica.playing and audio._ganho_musica > 0.99 and audio._musica.stream == audio._carregar(caminho), ESPERA_DA_TROCA_S)
	if not chegou:
		print("  [%s] esperava %s, e a música é %s (ganho %.2f, tocando %s)" % [onde, caminho.get_file(), audio.musica_atual().get_file(), audio._ganho_musica, audio._musica.playing])
	return chegou


## `relogio.ate`, mas amostrando a música a CADA quadro (a fusão acontece entre quadros).
func _ate_quadro(condicao: Callable, segundos: float) -> bool:
	var limite: float = relogio.agora() + segundos
	var guarda := Time.get_ticks_msec() + int(maxf(segundos * 12.0, 60.0) * 1000.0)
	while relogio.agora() < limite and Time.get_ticks_msec() < guarda:
		_amostrar()
		if condicao.call():
			return true
		await process_frame
	return condicao.call()


func _zerar_amostras() -> void:
	amostras.clear()


func _amostrar() -> void:
	amostras.append({"ganho": float(audio._ganho_musica), "stream": audio._musica.stream, "tocando": audio._musica.playing})


## A música que o jogador ouve: tocando, no barramento do botão de som, com volume de ouvir.
func _conferir_audivel(onde: String) -> void:
	_conferir(audio._musica.playing, "%s: a trilha não está tocando" % onde)
	_conferir(String(audio._musica.bus) == String(audio.GERAL), "%s: a trilha não sai pelo barramento Geral (%s)" % [onde, audio._musica.bus])
	_conferir(audio._musica.volume_db > -30.0, "%s: a trilha está inaudível (%.1f dB)" % [onde, audio._musica.volume_db])
	var indice: int = AudioServer.get_bus_index(audio.GERAL)
	_conferir(indice >= 0 and not AudioServer.is_bus_mute(indice), "%s: o barramento Geral está mudo" % onde)


func _frames(quantos: int) -> void:
	for i in range(quantos):
		await process_frame


## O vale se monta ao longo de vários quadros (world_builder): espera ficar pronto.
func _mundo_pronto() -> void:
	for i in range(3000):
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
