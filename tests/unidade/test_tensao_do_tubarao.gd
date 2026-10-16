extends "res://tests/unidade/base.gd"
## A MÚSICA DE TENSÃO DO TUBARÃO (#261): a camada que entra POR CIMA da música do dia quando ele persegue.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste tensao_do_tubarao
##
## O pedido do autor: "quando o tubarão se aproximar, a música troca para uma trilha de tensão (pulsante, grave,
## crescendo com a proximidade) e volta à música do vale quando o perigo passa", com "crossfade de 1–2 s na entrada e
## de 4–6 s na saída" e "diálogos e narração continuam por cima". O `Audio` não troca o fluxo da trilha do dia (se
## trocasse, ela recomeçaria do início ao voltar): a tensão é uma camada própria, e a do dia só abaixa.
## O tubarão fala com ela por um número só, `tensao_do_tubarao(nivel)`. Perguntas:
##
##   1. O GANHO CRESCE COM O PERIGO: zero sem perigo, um sussurro grave ao longe e a trilha inteira com a boca em cima.
##   2. A TRILHA É A PRÓPRIA, OU A DA MATA ENQUANTO A PRÓPRIA NÃO EXISTE (a geração é paga), e sem nenhuma o jogo não
##      quebra.
##   3. ENTRA EM 1–2 s E SAI EM 4–6 s, sem corte seco, e a camada PARA quando a descida acaba.
##   4. A MÚSICA DO DIA SÓ ABAIXA: o fluxo e o caminho dela não mudam, o volume desce com a tensão e volta ao fim.
##   5. FALA E NARRAÇÃO FICAM POR CIMA: o volume máximo da tensão está bem abaixo do da voz e do da narração; o mudo
##      e o volume de Música valem para a camada.
##   6. PERIGO INVÁLIDO NÃO TRAVA A TENSÃO LIGADA.
##
## FALSIFICAÇÃO (à mão, o GUT não aceita argumento): `ENTRADA_DA_TENSAO := 3.0` reprova a 3; `GANHO_LONGE := 1.0`
## reprova a 1; `VOLUME_DA_TENSAO := 0.0` reprova a 5; tirar `_abafo_da_tensao` da conta de `_aplicar_volume_da_musica`
## reprova a 4.

var audio: Node
var _tempo_antes := 1.0


func before_each() -> void:
	super.before_each()
	audio = root.get_node("/root/Audio")
	_tempo_antes = Engine.time_scale


func after_each() -> void:
	Engine.time_scale = _tempo_antes
	# A camada é um nó filho do autoload, e a foto do estado só devolve variáveis: apaga o que o teste ligou.
	if audio._tensao_transicao != null and audio._tensao_transicao.is_valid():
		audio._tensao_transicao.kill()
	audio._tensao_ligada = false
	audio._tensao_nivel = 0.0
	audio._tensao_envelope = 0.0
	audio._tensao.stop()
	audio._caminho_musica = ""
	audio._aplicar_volumes()


# --- 1. O GANHO CRESCE COM O PERIGO ------------------------------------------------------------------

func test_o_ganho_cresce_com_o_perigo() -> void:
	conferir(audio.ganho_da_tensao(0.0) == 0.0, "sem perigo a camada devia ficar muda")
	conferir(audio.ganho_da_tensao(-1.0) == 0.0 and audio.ganho_da_tensao(NAN) == 0.0, "perigo negativo ou inválido devia ficar mudo")
	conferir(is_equal_approx(audio.ganho_da_tensao(1.0), 1.0) and is_equal_approx(audio.ganho_da_tensao(7.0), 1.0),
		"com a boca em cima a tensão devia soar inteira")
	var longe: float = audio.ganho_da_tensao(0.01)
	conferir(longe >= audio.GANHO_LONGE and longe < 0.3,
		"ao longe a tensão devia ser só um sussurro grave (%.2f)" % longe)
	var anterior := 0.0
	for passo in range(1, 21):
		var g: float = audio.ganho_da_tensao(float(passo) / 20.0)
		conferir(g > anterior, "o ganho devia crescer com o perigo (%.2f depois de %.2f)" % [g, anterior])
		anterior = g
	conferir(audio.ganho_da_tensao(1.0) > audio.ganho_da_tensao(0.1) * 3.0,
		"perto devia soar bem mais que longe (%.2f contra %.2f)" % [audio.ganho_da_tensao(1.0), audio.ganho_da_tensao(0.1)])


# --- 2. A TRILHA ----------------------------------------------------------------------------------------

func test_a_trilha_cai_na_da_mata_enquanto_a_propria_nao_existe() -> void:
	conferir(audio.faixa_da_tensao_entre(true, true) == audio.MUSICA_TUBARAO, "com as duas, vale a do tubarão")
	conferir(audio.faixa_da_tensao_entre(true, false) == audio.MUSICA_TUBARAO, "só a do tubarão, vale a do tubarão")
	conferir(audio.faixa_da_tensao_entre(false, true) == audio.MUSICA_MATA, "sem a do tubarão, vale a da mata fechada")
	conferir(audio.faixa_da_tensao_entre(false, false) == "", "sem nenhuma, a tensão fica muda e o jogo segue")
	conferir(audio.MUSICA_TUBARAO.ends_with("musica_tubarao.mp3"), "o nome da trilha própria é combinado com a geração")
	var faixa: String = audio.faixa_da_tensao()
	conferir(faixa == audio.faixa_da_tensao_entre(ResourceLoader.exists(audio.MUSICA_TUBARAO), ResourceLoader.exists(audio.MUSICA_MATA)),
		"a faixa de agora (%s) não segue o que existe em disco" % faixa)
	conferir(faixa != "" and ResourceLoader.exists(faixa), "o jogo devia ter uma trilha de tensão que existe (%s)" % faixa)


func test_a_camada_toca_a_trilha_no_barramento_geral() -> void:
	audio.tensao_do_tubarao(0.5)
	var faixa: String = audio.faixa_da_tensao()
	conferir(audio.tensao_tocando(), "a camada devia estar tocando com perigo")
	conferir(audio._tensao.stream == audio._carregar(faixa), "a camada devia tocar a trilha de tensão (%s)" % faixa.get_file())
	conferir(String(audio._tensao.bus) == String(audio.GERAL), "a camada devia sair pelo barramento Geral (o do botão de som): %s" % audio._tensao.bus)
	conferir(bool(audio._tensao.stream.loop), "a trilha de tensão devia repetir enquanto durar o perigo")
	conferir(is_equal_approx(audio.tensao_atual(), 0.5), "tensao_atual devia dizer o último perigo (%.2f)" % audio.tensao_atual())


# --- 3. ENTRA EM 1–2 s E SAI EM 4–6 s ---------------------------------------------------------------------

func test_entra_em_um_a_dois_segundos_e_sai_em_quatro_a_seis() -> void:
	conferir(audio.ENTRADA_DA_TENSAO >= 1.0 and audio.ENTRADA_DA_TENSAO <= 2.0, "a entrada devia durar de 1 a 2 s (%.1f)" % audio.ENTRADA_DA_TENSAO)
	conferir(audio.SAIDA_DA_TENSAO >= 4.0 and audio.SAIDA_DA_TENSAO <= 6.0, "a saída devia durar de 4 a 6 s (%.1f)" % audio.SAIDA_DA_TENSAO)
	Engine.time_scale = 4.0
	audio.tensao_do_tubarao(0.8)
	conferir(audio._tensao_envelope < 0.05, "a tensão devia entrar em fusão, e não de uma vez (%.2f)" % audio._tensao_envelope)
	await get_tree().create_timer(audio.ENTRADA_DA_TENSAO * 0.45).timeout
	var no_meio: float = audio._tensao_envelope
	conferir(no_meio > 0.05 and no_meio < 0.95, "no meio da entrada a tensão devia estar subindo (%.2f)" % no_meio)
	await get_tree().create_timer(audio.ENTRADA_DA_TENSAO * 0.8).timeout
	conferir(audio._tensao_envelope > 0.99, "depois da entrada a tensão devia estar inteira (%.2f)" % audio._tensao_envelope)
	# A saída: o perigo passou, e a camada desce devagar, tocando até o fim da descida.
	audio.tensao_do_tubarao(0.0)
	conferir(audio.tensao_atual() == 0.0, "sem perigo a tensão atual devia ser zero")
	conferir(audio._tensao_envelope > 0.95, "a saída não devia cortar seco (%.2f)" % audio._tensao_envelope)
	await get_tree().create_timer(audio.SAIDA_DA_TENSAO * 0.5).timeout
	var descendo: float = audio._tensao_envelope
	conferir(descendo > 0.05 and descendo < 0.95, "no meio da saída a tensão devia estar descendo (%.2f)" % descendo)
	conferir(audio.tensao_tocando(), "a camada devia seguir tocando até o fim da descida")
	await get_tree().create_timer(audio.SAIDA_DA_TENSAO * 0.6).timeout
	conferir(audio._tensao_envelope < 0.01, "depois da saída a tensão devia ter sumido (%.2f)" % audio._tensao_envelope)
	conferir(not audio.tensao_tocando(), "a camada devia parar quando a descida acaba")


func test_voltar_o_perigo_durante_a_saida_cancela_a_parada() -> void:
	Engine.time_scale = 4.0
	audio.tensao_do_tubarao(1.0)
	await get_tree().create_timer(audio.ENTRADA_DA_TENSAO * 1.2).timeout
	audio.tensao_do_tubarao(0.0)
	await get_tree().create_timer(audio.SAIDA_DA_TENSAO * 0.3).timeout
	audio.tensao_do_tubarao(0.6)
	await get_tree().create_timer(audio.SAIDA_DA_TENSAO * 0.8).timeout
	conferir(audio.tensao_tocando(), "o perigo que voltou devia manter a camada tocando")
	conferir(audio._tensao_envelope > 0.99, "o perigo que voltou devia levar a tensão de novo ao cheio (%.2f)" % audio._tensao_envelope)


# --- 4. A MÚSICA DO DIA SÓ ABAIXA ---------------------------------------------------------------------------

func test_a_musica_do_dia_nao_e_trocada_so_abaixa() -> void:
	audio._caminho_musica = audio.MUSICAS_PERIODO["manha"]
	var fluxo = audio._musica.stream
	audio._aplicar_volumes()
	var volume_normal: float = audio._musica.volume_db
	audio.tensao_do_tubarao(1.0)
	audio._tensao_envelope = 1.0
	conferir(audio._caminho_musica == audio.MUSICAS_PERIODO["manha"], "a tensão trocou a trilha do dia (%s)" % audio._caminho_musica.get_file())
	conferir(audio._musica.stream == fluxo, "a tensão mexeu no fluxo da trilha do dia: ela recomeçaria ao voltar")
	var abafado: float = audio._musica.volume_db
	var esperado: float = volume_normal + linear_to_db(audio.ABAFO_DA_MUSICA_NA_TENSAO)
	conferir(abafado < volume_normal - 6.0 and is_equal_approx(abafado, esperado),
		"com a tensão inteira a trilha do dia devia descer a %.1f dB (desceu a %.1f)" % [esperado - volume_normal, abafado - volume_normal])
	audio._tensao_envelope = 0.0
	audio._tensao_ligada = false
	conferir(is_equal_approx(audio._musica.volume_db, volume_normal), "sem a tensão a trilha do dia devia voltar ao volume de antes (%.1f contra %.1f)" % [audio._musica.volume_db, volume_normal])
	conferir(audio._abafo_da_tensao == 1.0, "o abafo da tensão devia voltar a 1")


func test_a_tensao_longe_abafa_menos_que_a_tensao_perto() -> void:
	audio._tensao_envelope = 1.0
	audio._tensao_ligada = true
	audio._tensao_nivel = 0.05
	audio._aplicar_a_tensao()
	var longe: float = audio._abafo_da_tensao
	audio._tensao_nivel = 1.0
	audio._aplicar_a_tensao()
	var perto: float = audio._abafo_da_tensao
	conferir(longe > perto and longe < 1.0, "ao longe a trilha do dia devia abaixar menos que perto (%.2f contra %.2f)" % [longe, perto])
	conferir(audio._tensao.volume_db > -40.0, "a camada devia se ouvir com a boca em cima (%.1f dB)" % audio._tensao.volume_db)


# --- 5. FALA E NARRAÇÃO POR CIMA --------------------------------------------------------------------------

func test_fala_e_narracao_ficam_por_cima_da_tensao() -> void:
	# Com Música e as vozes no mesmo volume, a tensão inteira (o pior caso) fica dez decibéis abaixo da voz e da narração.
	var tensao_maxima: float = audio.VOLUME_DA_TENSAO
	conferir(tensao_maxima <= audio.VOLUME_VOZ - 10.0, "a tensão (%.1f dB) devia ficar 10 dB abaixo da voz dos personagens (%.1f dB)" % [tensao_maxima, audio.VOLUME_VOZ])
	conferir(tensao_maxima <= audio.VOLUME_NARRACAO - 8.0, "a tensão (%.1f dB) devia ficar 8 dB abaixo da narração (%.1f dB)" % [tensao_maxima, audio.VOLUME_NARRACAO])
	# E no volume de fábrica o que se ouve é isto mesmo.
	audio.restaurar_padroes(["musica", "vozes", "narracao"])
	audio._tensao_nivel = 1.0
	audio._tensao_ligada = true
	audio._tensao_envelope = 1.0
	conferir(audio._tensao.volume_db <= audio.volume_vozes_db() - 10.0,
		"no volume de fábrica a camada (%.1f dB) devia ficar 10 dB abaixo das vozes (%.1f dB)" % [audio._tensao.volume_db, audio.volume_vozes_db()])
	conferir(audio._tensao.volume_db <= audio._narracao.volume_db - 8.0,
		"no volume de fábrica a camada (%.1f dB) devia ficar 8 dB abaixo da narração (%.1f dB)" % [audio._tensao.volume_db, audio._narracao.volume_db])


func test_o_mudo_e_o_volume_de_musica_valem_para_a_camada() -> void:
	audio.definir_mudo("musica", false)
	audio.definir_volume_musica(0.5)
	audio._tensao_nivel = 1.0
	audio._tensao_ligada = true
	audio._tensao_envelope = 1.0
	var com_meio: float = audio._tensao.volume_db
	conferir(is_equal_approx(com_meio, audio.VOLUME_DA_TENSAO + linear_to_db(0.5)), "a camada devia seguir o volume de Música (%.1f dB)" % com_meio)
	audio.definir_volume_musica(1.0)
	conferir(audio._tensao.volume_db > com_meio + 5.0, "subir o volume de Música devia subir a camada (%.1f dB depois de %.1f)" % [audio._tensao.volume_db, com_meio])
	audio.definir_mudo("musica", true)
	conferir(audio._tensao.volume_db <= -80.0, "o mudo de Música devia calar a camada (%.1f dB)" % audio._tensao.volume_db)
	audio.definir_mudo("musica", false)
	conferir(audio._tensao.volume_db > -40.0, "tirar o mudo devia devolver a camada (%.1f dB)" % audio._tensao.volume_db)


# --- 6. PERIGO INVÁLIDO -----------------------------------------------------------------------------------

func test_perigo_invalido_apaga_a_tensao_e_o_maior_que_um_vale_um() -> void:
	audio.tensao_do_tubarao(9.0)
	conferir(is_equal_approx(audio.tensao_atual(), 1.0), "perigo acima de 1 devia valer 1 (%.2f)" % audio.tensao_atual())
	audio.tensao_do_tubarao(NAN)
	conferir(audio.tensao_atual() == 0.0, "perigo inválido devia apagar a tensão")
	audio.tensao_do_tubarao(-0.5)
	conferir(audio.tensao_atual() == 0.0, "perigo negativo devia apagar a tensão")
	audio.tensao_do_tubarao(0.0)
	audio.tensao_do_tubarao(0.0)
	conferir(audio.tensao_atual() == 0.0, "chamar de novo sem perigo devia continuar sem tensão")


func test_a_trilha_da_mata_no_ar_nao_e_dobrada_pela_camada() -> void:
	# A onça caçando põe a trilha da mata como A música; o tubarão que cai na mesma faixa não a toca duas vezes.
	if audio.faixa_da_tensao() != audio.MUSICA_MATA:
		pending("a tensão tem trilha própria: a regra da faixa dobrada só vale enquanto ela cai na da mata")
		return
	audio._caminho_musica = audio.MUSICA_MATA
	audio.tensao_do_tubarao(1.0)
	conferir(not audio.tensao_tocando(), "a camada dobrou a trilha da mata que já é a música")
