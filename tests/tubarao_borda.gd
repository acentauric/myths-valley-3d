extends "res://tests/suite/caso.gd"
## O TUBARÃO MATA ANTES DE A BORDA DO MAPA APARECER NO MINIMAPA (#260), com o jogador nadando (ou vadeando) de verdade.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste tubarao_borda
##     .\tools\prototipo_3d\testar.ps1 -Teste tubarao_borda -Extra --falsificar     (tem de reprovar)
##
## A regra do autor: "toda vez que a borda aparecer no minimapa, o tubarão já tem que ter matado o jogador" — o mar
## aberto é o limite do mundo. O caso leva o jogador em linha reta, mar adentro, até a borda do quadro, em todos os lados
## que têm mar (leste, sul e norte; o oeste é terra), e confere:
##
##   1. O QUE O MINIMAPA FOTOGRAFA É O QUADRO: a foto cobre exatamente `get_map_frame()`, e é dessa borda que a conta fala.
##   2. O AVISO VEM ANTES: ao entrar na faixa de aviso a barbatana aparece perto do jogador, o HUD diz, e a música de
##      tensão entra — tudo com o jogador ainda além da linha fatal, a tempo de voltar.
##   3. O TUBARÃO MORDE ANTES DA BORDA: da linha fatal ao susto, o jogador, andando sem parar (e andando ainda durante a
##      tela escurecendo), nunca chega a 27,5 u da borda, o raio da vista do minimapa. Vale nadando a 3 u/s e no pior
##      ritmo que ele tem na água.
##   4. VALE NA BAIXA-MAR E A VAU: com a maré baixa o tubarão do pesqueiro some e a baía vira planície de joelho; o mar
##      aberto não liga para a maré, e o jogador que vadeia até a borda é mordido do mesmo jeito.
##   5. DÁ PARA VOLTAR: quem recua da faixa de aviso não é mordido, e a barbatana afunda e volta ao pesqueiro.
##   6. QUEM MORDE É O SUSTO DE SEMPRE, com o texto do mar aberto, e o jogador acorda em terra firme.
##   7. O PRAZO VALE COM O TUBARÃO LONGE: se na hora de dar o bote ele está a centenas de unidades (preso, ou onde a água
##      não deixa chegar), o mar não espera: no fim do prazo ele aparece colado no jogador e morde, ainda antes da borda.
##   8. O MAPA DOIDO ADIANTA A LINHA: com a foto do minimapa escorregada pela deriva, a borda aparece mais cedo, e a
##      linha fatal anda junto: a mesma posição que sem o mapa doido é só aviso vira bote.
##
## O TEMPO DESTE CASO É O DO JOGO, e não o de quadros de física: com `ACELERAR` o Godot entrega ao jogo um delta de
## `time_scale / 60` s por passo de física. O corpo anda `ritmo x delta` por passo (medido no relógio do próprio tubarão), e o
## susto, que é um tween, não entra na conta: o corpo fica parado enquanto a tela escurece, e a distância que ele ainda
## andaria nesse 1 s (`Tubarao.ATE_O_PRETO`) é descontada do que ele chegou a estar da borda.
##
## FALSIFICAÇÃO: `--falsificar` zera a linha fatal do tubarão: o jogador anda até a borda sem morrer, e as perguntas 3 e 4 reprovam.

const MarAberto = preload("res://scripts/prototipo_3d/mar_aberto.gd")
const RelogioDeJogo = preload("res://tests/fixtures/relogio_de_jogo.gd")
## A simulação anda 4 vezes mais depressa que a parede.
const ACELERAR := 4
const TETO_S := 900
## De que distância da borda cada corrida parte: além da faixa de aviso, para o aviso acontecer com o jogador andando.
const PARTIDA := MarAberto.FAIXA_DE_AVISO + 30.0
## Água mínima ao longo da reta (u): só conta como prova um caminho que é mar todo ele.
const AGUA_MINIMA := 0.5

var falhas := 0
var falsificar := false
var world
var player: CharacterBody3D
var tubarao
var audio
var relogio: Node
var avisos_do_hud: Array[String] = []
var _aviso_original := Callable()
## Segundos de jogo que passam em cada passo de física (medido no relógio do tubarão).
var passo_s := 1.0 / 60.0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		falhas += 1
		push_error("TUBARAO_BORDA_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)


func _run() -> void:
	falsificar = "--falsificar" in OS.get_cmdline_user_args()
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "o vale não carregou")
	await _frames(6)
	await _mundo_pronto()
	var vale = current_scene
	# O cartão da água funda (#96) para o vale no primeiro nado: aqui o nado é a prova.
	vale._avisou_agua_funda = true
	world = vale.world
	player = vale.player
	tubarao = vale.get_node_or_null("Tubarao")
	audio = root.get_node("/root/Audio")
	_conferir(tubarao != null and tubarao.get("_ativo") == true, "o tubarão não está ativo")
	if tubarao == null or tubarao.get("_ativo") != true:
		quit(1)
		return
	relogio = RelogioDeJogo.new()
	root.add_child(relogio)
	var quadro: Rect2 = world.get_map_frame()

	# --- 1. O QUE O MINIMAPA FOTOGRAFA É O QUADRO -----------------------------------------------------
	var dados = JSON.parse_string(FileAccess.get_file_as_string("res://assets/prototipo_3d/identidade/minimapa/mapa_vale.json"))
	_conferir(dados is Dictionary, "falta o mapa_vale.json do minimapa")
	if dados is Dictionary:
		var foto := Rect2(float(dados["origem_x"]), float(dados["origem_z"]), float(dados["largura"]), float(dados["altura"]))
		_conferir(world.has_map_frame(), "o mundo não tem o quadro do mapa")
		_conferir(foto.position.distance_to(quadro.position) < 0.5 and foto.size.distance_to(quadro.size) < 0.5,
			"a foto do minimapa (%s) não cobre o quadro do mapa (%s): a borda que a conta usa não é a que a vista mostra" % [str(foto), str(quadro)])
	print("TUBARAO_BORDA: quadro %s · raio da vista %.1f u · linha fatal %.0f u · faixa de aviso %.0f u" % [str(quadro), MarAberto.borda_no_minimapa(), MarAberto.LINHA_FATAL, MarAberto.FAIXA_DE_AVISO])

	# O jogador parte da terra firme do povoado (a última terra firme, para onde o susto o devolve); o corpo fica parado
	# (sem a física dele) e é movido à mão, como nos outros portões do mar.
	var terra: Vector3 = world.get_spawn_position()
	player.global_position = terra
	player.set("_last_land", terra)
	player.velocity = Vector3.ZERO
	player.set_physics_process(false)
	var tempo_antes: float = tubarao.get("_tempo")
	await _physics_frames(30)
	passo_s = (float(tubarao.get("_tempo")) - tempo_antes) / 30.0
	print("TUBARAO_BORDA: cada passo de física vale %.4f s de jogo (tempo do jogo x%.1f)" % [passo_s, Engine.time_scale])
	_conferir(passo_s > 0.0, "o relógio do tubarão não andou")
	_aviso_original = tubarao.get("_aviso")
	tubarao.set("_aviso", func(texto: String) -> void:
		avisos_do_hud.append(texto)
		if _aviso_original.is_valid():
			_aviso_original.call(texto))
	if falsificar:
		print("  FALSIFICAÇÃO: a linha fatal do tubarão vale zero (--falsificar)")
		tubarao.set("_linha_fatal", 0.0)

	var mare := root.get_node("/root/Mare")
	var dia := root.get_node("/root/Dia")
	# O relógio do dia pára: a corrida dura minutos de jogo, e a meia-noite traz o desmaio das duas (a tela de dormir
	# pára o vale e leva o jogador para a cama) no meio da medida.
	var dia_pausado_antes: bool = dia.pausado
	dia.pausado = true
	var nado_de_corrida: float = player.VELOCIDADE_NADO * 2.0

	# --- 2 e 3. O AVISO E O BOTE, na preamar (o portão roda sem maré: o nível é o da cheia) ---------------
	var raios := _raios(quadro, PARTIDA)
	print("TUBARAO_BORDA: %d reta(s) de mar até a borda: %s" % [raios.size(), ", ".join(PackedStringArray(raios.map(func(r: Dictionary) -> String: return "%s@%.0f" % [r["lado"], r["posicao"]])))])
	for lado in ["leste", "sul", "norte"]:
		_conferir(raios.any(func(r: Dictionary) -> bool: return r["lado"] == lado), "não achei reta de mar até a borda %s" % lado)
	for raio in raios:
		var r := await _correr(raio, nado_de_corrida, terra)
		_conferir_a_corrida(raio, r, "nado de corrida %.1f u/s, na cheia" % nado_de_corrida, true)
		if falsificar and falhas > 0:
			break
		await _esperar_a_patrulha()
	# O pior ritmo que ele tem na água (a vau, com os talentos todos): o tubarão ainda chega antes da borda (uma reta por lado).
	for raio in _um_por_lado(raios):
		if falsificar and falhas > 0:
			break
		var r := await _correr(raio, MarAberto.RITMO_MAXIMO, terra)
		_conferir_a_corrida(raio, r, "pior ritmo %.1f u/s, na cheia" % MarAberto.RITMO_MAXIMO, false)
		await _esperar_a_patrulha()

	# --- 7. O PRAZO VALE COM O TUBARÃO LONGE ---------------------------------------------------------------
	if not raios.is_empty() and not (falsificar and falhas > 0):
		var r := await _correr(raios[0], MarAberto.RITMO_MAXIMO, terra, true)
		var onde := "%s@%.0f (tubarão levado para longe na hora do bote, a %.1f u/s)" % [raios[0]["lado"], raios[0]["posicao"], MarAberto.RITMO_MAXIMO]
		print("TUBARAO_BORDA: %s · mordido %s · chegou a %.1f u da borda · bote %.2f s depois da linha" % [onde, r["mordeu"], r["menor"], r["bote_s"]])
		_conferir(r["mordeu"], "%s: o tubarão longe não mordeu no prazo (o jogador chegou a %.1f u da borda)" % [onde, r["menor"]])
		_conferir(not MarAberto.borda_a_vista(float(r["menor"])), "%s: a borda entrou na vista com o jogador vivo (a %.1f u dela)" % [onde, r["menor"]])
		_conferir(float(r["bote_s"]) >= MarAberto.PRAZO_DO_BOTE - 0.3 and float(r["bote_s"]) <= MarAberto.PRAZO_DO_BOTE + passo_s * 3.0,
			"%s: devia morder no fim do prazo (%.1f s), e mordeu %.2f s depois da linha" % [onde, MarAberto.PRAZO_DO_BOTE, r["bote_s"]])
		_conferir(r["em_terra"], "%s: depois do susto o jogador devia estar em terra firme" % onde)
		await _esperar_a_patrulha()

	# --- 8. O MAPA DOIDO ADIANTA A LINHA ----------------------------------------------------------------
	if not raios.is_empty() and not falsificar:
		await _mapa_doido(raios[0], terra)

	# --- 5. DÁ PARA VOLTAR ----------------------------------------------------------------------------
	if not raios.is_empty() and not falsificar:
		await _recuar(raios[0], nado_de_corrida, terra, quadro)

	# --- 4. A BAIXA-MAR, A VAU ---------------------------------------------------------------------------
	mare.modo = 1
	dia.definir_hora(fposmod(float(mare.fase_da_preamar_h) + 6.0, 24.0))
	await relogio.esperar(2.5)
	_conferir(float(mare.nivel_offset()) < -0.4, "a baixa-mar não baixou o mar (%.2f)" % float(mare.nivel_offset()))
	var rasos := _raios(quadro, PARTIDA, true)
	print("TUBARAO_BORDA: na baixa-mar (%.2f u), %d reta(s) de mar raso, onde o jogador vadeia" % [float(mare.nivel_offset()), rasos.size()])
	_conferir(rasos.size() >= 1, "na baixa-mar não achei reta de mar onde o jogador só vadeia: o portão não prova o vau")
	_conferir(tubarao.get("_submerso") == true, "na baixa-mar o tubarão do pesqueiro devia estar escondido (o mar aberto é que não liga para a maré)")
	for raio in rasos:
		if falsificar and falhas > 0:
			break
		var r := await _correr(raio, MarAberto.RITMO_MAXIMO, terra)
		_conferir_a_corrida(raio, r, "a vau, na baixa-mar, a %.1f u/s" % MarAberto.RITMO_MAXIMO, false)
		await _esperar_a_patrulha()
	mare.modo = 0
	dia.pausado = dia_pausado_antes

	# --- devolve o que mexeu ------------------------------------------------------------------------------
	tubarao.set("_aviso", _aviso_original)
	player.global_position = terra
	player.velocity = Vector3.ZERO
	player.set_physics_process(true)
	_calar_a_tensao()
	relogio.queue_free()
	if falhas == 0:
		print("TUBARAO_BORDA_OK: em %d lado(s) de mar o jogador, andando sem parar, é mordido antes de a borda do mapa entrar na vista do minimapa (a menos de %.1f u dela), nadando, no pior ritmo e a vau na baixa-mar; antes da linha fatal a barbatana ronda, o HUD avisa e a tensão entra; quem recua é largado" % [raios.size(), MarAberto.borda_no_minimapa()])
	quit(0 if falhas == 0 else 1)


## Uma corrida do jogador, em linha reta e sem parar, de `raio["inicio"]` rumo à borda, à velocidade `ritmo` (u/s).
## Quando o susto começa o corpo pára (a tela escurece por `Tubarao.ATE_O_PRETO` s, de tween), e a distância que ele ainda
## andaria nesse tempo, correndo, é descontada do que chegou a estar da borda. Devolve o que se viu.
func _correr(raio: Dictionary, ritmo: float, terra: Vector3, afastar_o_tubarao: bool = false) -> Dictionary:
	var inicio: Vector3 = raio["inicio"]
	var rumo: Vector3 = raio["rumo"]
	var quadro: Rect2 = world.get_map_frame()
	var passo := ritmo * passo_s
	var mordidas_antes: int = tubarao.mordidas_no_mar_aberto
	avisos_do_hud.clear()
	var avisou_a := INF
	var viu_a_barbatana_a := INF
	var tensao_a := INF
	var tensao_maxima := 0.0
	var rondou_a := INF
	var t_da_linha := -1.0
	var t_da_mordida := -1.0
	var distancia_ao_morder := INF
	var menor := INF
	var posicao := inicio
	var mordeu := false
	var afastado := false
	var no_fim_s := 0.0
	# O aviso de cada entrada conta de novo (o intervalo de 90 s entre avisos é do jogo, e não da prova).
	tubarao.set("_ultimo_aviso", -1000000.0)
	var avisos_do_sinal := [0]
	var contar := func() -> void: avisos_do_sinal[0] += 1
	tubarao.avisou_no_mar_aberto.connect(contar)
	for quadro_n in 12000:
		await physics_frame
		if tubarao.mordidas_no_mar_aberto > mordidas_antes:
			# O susto escureceu a tela e devolveu o jogador à terra: acabou a corrida.
			mordeu = true
			break
		if tubarao.get("_atacando") == true:
			if t_da_mordida < 0.0:
				t_da_mordida = tubarao.get("_tempo")
				distancia_ao_morder = MarAberto.distancia_a_borda(posicao, quadro)
			continue
		if MarAberto.distancia_a_borda(posicao, quadro) > 4.0:
			posicao += rumo * passo
		else:
			# Chegou à parede sem ser mordido: não há o que esperar (é a falsificação, ou um defeito).
			no_fim_s += passo_s
			if no_fim_s > 2.0:
				break
		_por_o_jogador(posicao)
		var distancia := MarAberto.distancia_a_borda(posicao, quadro)
		menor = minf(menor, distancia)
		if distancia < MarAberto.LINHA_FATAL and t_da_linha < 0.0:
			t_da_linha = tubarao.get("_tempo")
		if avisou_a == INF and avisos_do_sinal[0] > 0:
			avisou_a = distancia
		# 7. No instante em que o bote começa, o tubarão é levado para o pesqueiro, a centenas de unidades do jogador.
		if afastar_o_tubarao and not afastado and tubarao.get("_zona") == MarAberto.Zona.FATAL:
			afastado = true
			var centro: Vector3 = tubarao.get("_centro")
			tubarao.global_position = Vector3(centro.x, tubarao.global_position.y, centro.z)
		var do_tubarao := Vector2(tubarao.global_position.x - posicao.x, tubarao.global_position.z - posicao.z).length()
		if tubarao.get("_zona") == MarAberto.Zona.AVISO:
			rondou_a = minf(rondou_a, do_tubarao)
			if viu_a_barbatana_a == INF and tubarao.visible and float(tubarao.get("_emersao")) > 0.5 and do_tubarao < 40.0:
				viu_a_barbatana_a = distancia
		if tensao_a == INF and audio.tensao_atual() > 0.0 and distancia > MarAberto.LINHA_FATAL:
			tensao_a = distancia
		tensao_maxima = maxf(tensao_maxima, audio.tensao_atual())
	tubarao.avisou_no_mar_aberto.disconnect(contar)
	if not mordeu:
		var onde_p: Vector3 = player.global_position
		print("  [diag] sem mordida: zona %s · chamado %s · atacando %s · na água %s · lâmina %.2f · em terra %s · jogador em %s · tubarão em %s (visível %s)" % [
			str(tubarao.get("_zona")), str(tubarao.get("_chamado")), str(tubarao.get("_atacando")), str(tubarao.get("_jogador_na_agua")),
			world.water_depth_at(onde_p), str(world.is_on_land(onde_p)), str(onde_p.snapped(Vector3.ONE * 0.1)), str(tubarao.global_position.snapped(Vector3.ONE * 0.1)), str(tubarao.visible)])
	if mordeu and distancia_ao_morder < INF:
		menor = minf(menor, distancia_ao_morder - ritmo * tubarao.ATE_O_PRETO)
	var bote_s := t_da_mordida - t_da_linha if t_da_mordida >= 0.0 and t_da_linha >= 0.0 else INF
	var aviso_do_hud: bool = avisos_do_hud.size() > 0 and avisos_do_hud[0] == tubarao._texto("aviso")
	var susto_do_hud: bool = avisos_do_hud.size() > 0 and avisos_do_hud[avisos_do_hud.size() - 1] == tubarao._texto("susto_borda")
	var depois: Vector3 = player.global_position
	var em_terra := Vector2(depois.x - terra.x, depois.z - terra.z).length() < 3.0
	return {"mordeu": mordeu, "menor": menor, "avisou_a": avisou_a, "barbatana_a": viu_a_barbatana_a, "tensao_a": tensao_a, "tensao_max": tensao_maxima,
		"bote_s": bote_s, "rondou_a": rondou_a, "avisos": avisos_do_sinal[0], "aviso_do_hud": aviso_do_hud, "susto_do_hud": susto_do_hud, "em_terra": em_terra}


func _conferir_a_corrida(raio: Dictionary, r: Dictionary, como: String, com_aviso: bool) -> void:
	var onde := "%s@%.0f (%s)" % [raio["lado"], raio["posicao"], como]
	print("TUBARAO_BORDA: %s · mordido %s · chegou a %.1f u da borda · bote %.1f s depois da linha · aviso a %.0f u · barbatana a %.0f u (rondou a %.0f u do jogador) · tensão a %.0f u" % [
		onde, r["mordeu"], r["menor"], r["bote_s"], r["avisou_a"], r["barbatana_a"], r["rondou_a"], r["tensao_a"]])
	_conferir(r["mordeu"], "%s: o tubarão não mordeu antes da borda (o jogador chegou a %.1f u dela)" % [onde, r["menor"]])
	_conferir(not MarAberto.borda_a_vista(float(r["menor"])), "%s: a borda do mapa entrou na vista do minimapa com o jogador vivo (a %.1f u dela; o raio da vista é %.1f)" % [onde, r["menor"], MarAberto.borda_no_minimapa()])
	# O prazo é conferido a cada passo de física: três passos de folga (a linha vista pelo caso, o prazo visto pelo tubarão, a mordida
	# vista pelo caso).
	_conferir(float(r["bote_s"]) <= MarAberto.PRAZO_DO_BOTE + passo_s * 3.0, "%s: o bote demorou %.2f s depois da linha (o prazo é %.1f s)" % [onde, r["bote_s"], MarAberto.PRAZO_DO_BOTE])
	_conferir(r["em_terra"], "%s: depois do susto o jogador devia estar em terra firme" % onde)
	_conferir(r["susto_do_hud"], "%s: o HUD devia dizer o susto do mar aberto (o texto 'susto_borda'): %s" % [onde, str(avisos_do_hud)])
	_conferir(r["avisos"] == 1, "%s: o aviso devia sair uma vez por entrada (saiu %d)" % [onde, r["avisos"]])
	if com_aviso:
		_conferir(float(r["avisou_a"]) > MarAberto.LINHA_FATAL, "%s: o aviso veio tarde (a %.1f u da borda; a linha fatal é %.0f)" % [onde, r["avisou_a"], MarAberto.LINHA_FATAL])
		_conferir(float(r["barbatana_a"]) > MarAberto.LINHA_FATAL, "%s: a barbatana só apareceu perto do jogador a %.1f u da borda (a linha fatal é %.0f)" % [onde, r["barbatana_a"], MarAberto.LINHA_FATAL])
		_conferir(float(r["tensao_a"]) > MarAberto.LINHA_FATAL, "%s: a música de tensão só entrou a %.1f u da borda (a linha fatal é %.0f)" % [onde, r["tensao_a"], MarAberto.LINHA_FATAL])
		_conferir(r["aviso_do_hud"], "%s: o HUD devia avisar da barbatana primeiro (o texto 'aviso'): %s" % [onde, str(avisos_do_hud)])


## Põe o corpo do jogador (parado, sem física) em `ponto`: a altura é a de quem nada ou a do fundo, e a mão da água não importa
## ao tubarão, que só olha onde o jogador está.
func _por_o_jogador(ponto: Vector3) -> void:
	var lamina: float = world.water_depth_at(ponto)
	player.global_position = Vector3(ponto.x, world.water_level() - minf(maxf(lamina, 0.2), 1.2), ponto.z)
	player.velocity = Vector3.ZERO


## 8. O mapa doido (`loucura_do_mapa.gd`) escorrega a foto do minimapa até 38 u do jogador, e a borda aparece mais cedo. O nó dele
## é posto num instante de deriva grande (pelos campos, sem os sinais: ninguém mais precisa saber), o jogador fica a uma
## distância que sem o mapa doido seria só aviso, e a linha fatal tem de ter andado junto: é bote. Sem a loucura, aviso de novo.
func _mapa_doido(raio: Dictionary, terra: Vector3) -> void:
	var louca = get_first_node_in_group(&"loucura_do_mapa")
	_conferir(louca != null, "o vale não tem o nó do mapa doido (grupo loucura_do_mapa)")
	if louca == null:
		return
	louca.set("_ativa", true)
	louca.set("_duracao", 1.0e6)
	var melhor_t := 0.0
	var melhor := 0.0
	for t in range(3, 400):
		louca.set("_t", float(t))
		var deriva: float = (louca.deriva_do_mapa() as Vector2).length()
		if deriva > melhor:
			melhor = deriva
			melhor_t = float(t)
	louca.set("_t", melhor_t)
	_conferir(melhor > 30.0, "o mapa doido não escorrega o bastante para a prova (a deriva maior foi %.1f u)" % melhor)
	var distancia := MarAberto.LINHA_FATAL + melhor * 0.6
	_conferir(distancia < MarAberto.FAIXA_DE_AVISO, "a posição da prova (%.0f u) já passa da faixa de aviso" % distancia)
	var posicao: Vector3 = raio["inicio"] + raio["rumo"] * (PARTIDA - distancia)
	_por_o_jogador(posicao)
	await _physics_frames(6)
	var com_a_deriva: float = (louca.deriva_do_mapa() as Vector2).length()
	_conferir(tubarao.get("_zona") == MarAberto.Zona.FATAL,
		"com o mapa doido (a foto escorregou %.0f u) a %.0f u da borda a linha fatal devia andar junto, e o tubarão devia dar o bote (zona %s)" % [com_a_deriva, distancia, str(tubarao.get("_zona"))])
	louca.set("_ativa", false)
	louca.set("_t", 0.0)
	louca.set("_duracao", 0.0)
	await _physics_frames(6)
	_conferir(tubarao.get("_zona") == MarAberto.Zona.AVISO, "sem o mapa doido, a mesma posição (%.0f u da borda) devia ser só aviso (zona %s)" % [distancia, str(tubarao.get("_zona"))])
	print("TUBARAO_BORDA: mapa doido: com a foto escorregada %.0f u, a %.0f u da borda é bote; sem ele, aviso" % [com_a_deriva, distancia])
	player.global_position = terra
	await _esperar_a_patrulha()


## 5. O jogador chega à faixa de aviso, vê a barbatana, e recua: não é mordido, e a barbatana afunda e volta ao pesqueiro.
func _recuar(raio: Dictionary, ritmo: float, terra: Vector3, quadro: Rect2) -> void:
	var inicio: Vector3 = raio["inicio"]
	var rumo: Vector3 = raio["rumo"]
	var passo := ritmo * passo_s
	var mordidas_antes: int = tubarao.mordidas_no_mar_aberto
	var posicao := inicio
	_por_o_jogador(posicao)
	# Anda até a faixa de aviso (a 14 u da linha fatal) e fica nela uns segundos, com a barbatana rondando.
	var parado_s := 0.0
	for quadro_n in 12000:
		await physics_frame
		if MarAberto.distancia_a_borda(posicao, quadro) > MarAberto.LINHA_FATAL + 14.0:
			posicao += rumo * passo
		else:
			parado_s += passo_s
		_por_o_jogador(posicao)
		if parado_s > 6.0:
			break
	_conferir(tubarao.get("_zona") == MarAberto.Zona.AVISO and tubarao.get("_chamado") == true, "na faixa de aviso o tubarão devia estar rondando (zona %s)" % str(tubarao.get("_zona")))
	var do_tubarao := Vector2(tubarao.global_position.x - posicao.x, tubarao.global_position.z - posicao.z).length()
	_conferir(tubarao.visible and do_tubarao < 45.0, "na faixa de aviso a barbatana devia estar à vista, rondando perto (visível %s, a %.0f u)" % [str(tubarao.visible), do_tubarao])
	var volta := Vector3(-rumo.x, 0.0, -rumo.z)
	for quadro_n in 12000:
		await physics_frame
		var recuado := MarAberto.distancia_a_borda(posicao, quadro)
		if recuado < PARTIDA:
			posicao += volta * passo
		_por_o_jogador(posicao)
		if recuado > MarAberto.FAIXA_DE_AVISO + MarAberto.HISTERESE + 10.0 and tubarao.get("_chamado") == false:
			break
	_conferir(tubarao.mordidas_no_mar_aberto == mordidas_antes, "quem recuou da faixa de aviso foi mordido")
	await relogio.esperar(MarAberto.PRAZO_DO_BOTE + 2.0)
	_conferir(tubarao.get("_chamado") == false and tubarao.get("_zona") == MarAberto.Zona.NENHUMA, "recuado, o tubarão não largou o jogador")
	var centro: Vector3 = tubarao.get("_centro")
	_conferir(Vector2(tubarao.global_position.x - centro.x, tubarao.global_position.z - centro.z).length() <= float(tubarao.get("_a")) + float(tubarao.get("_b")) + 1.0,
		"largado o jogador, o tubarão devia voltar ao pesqueiro (está a %.0f u dele)" % Vector2(tubarao.global_position.x - centro.x, tubarao.global_position.z - centro.z).length())
	_conferir(tubarao.mordidas_no_mar_aberto == mordidas_antes, "quem recuou foi mordido depois")
	print("TUBARAO_BORDA: recuou da faixa de aviso sem ser mordido, e a barbatana voltou ao pesqueiro")
	player.global_position = terra
	await _esperar_a_patrulha()


## As retas de mar até a borda, de cada lado que tem mar: `partida` u da borda até ela, toda em água de `AGUA_MINIMA` para cima
## (e, com `so_a_vau`, toda em água rasa demais para nadar: o jogador vadeia o caminho inteiro). Duas por lado, as mais
## afastadas. Cada uma: {"lado", "posicao" (ao longo da borda), "inicio", "rumo" (para a borda)}.
func _raios(quadro: Rect2, partida: float, so_a_vau: bool = false) -> Array:
	var lados := [
		{"lado": "leste", "dentro": Vector3.LEFT, "origem": Vector3(quadro.end.x, 0.0, quadro.position.y), "ao_longo": Vector3.BACK, "comprimento": quadro.size.y},
		{"lado": "sul", "dentro": Vector3.FORWARD, "origem": Vector3(quadro.position.x, 0.0, quadro.end.y), "ao_longo": Vector3.RIGHT, "comprimento": quadro.size.x},
		{"lado": "norte", "dentro": Vector3.BACK, "origem": Vector3(quadro.position.x, 0.0, quadro.position.y), "ao_longo": Vector3.RIGHT, "comprimento": quadro.size.x},
		{"lado": "oeste", "dentro": Vector3.RIGHT, "origem": Vector3(quadro.position.x, 0.0, quadro.position.y), "ao_longo": Vector3.BACK, "comprimento": quadro.size.y},
	]
	var raios: Array = []
	for lado in lados:
		var validos: Array = []
		var t := 30.0
		while t <= float(lado["comprimento"]) - 30.0:
			var na_borda: Vector3 = lado["origem"] + lado["ao_longo"] * t
			var inicio: Vector3 = na_borda + lado["dentro"] * partida
			# Só vale a reta cuja borda mais perto é esta (as outras estão tão longe quanto a partida, ou mais).
			if MarAberto.distancia_a_borda(inicio, quadro) >= partida - 0.01 and _e_mar_ate_a_borda(inicio, na_borda, so_a_vau):
				validos.append({"lado": lado["lado"], "posicao": t, "inicio": inicio, "rumo": -lado["dentro"]})
			t += 20.0
		if validos.size() > 2:
			validos = [validos[0], validos[validos.size() - 1]]
		raios.append_array(validos)
	return raios


## A primeira reta de cada lado.
func _um_por_lado(raios: Array) -> Array:
	var vistos := {}
	var escolhidos: Array = []
	for raio in raios:
		if not vistos.has(raio["lado"]):
			vistos[raio["lado"]] = true
			escolhidos.append(raio)
	return escolhidos


func _e_mar_ate_a_borda(inicio: Vector3, borda: Vector3, so_a_vau: bool) -> bool:
	var comprimento := Vector2(borda.x - inicio.x, borda.z - inicio.z).length()
	var passos := int(comprimento / 4.0)
	for i in range(passos + 1):
		var p := inicio.lerp(borda, float(i) / float(passos + 1) if i < passos else 0.97)
		var lamina: float = world.water_depth_at(p)
		if world.is_on_land(p) or lamina < AGUA_MINIMA:
			return false
		if so_a_vau and lamina >= 1.2:
			return false
	return true


## Espera o tubarão voltar à patrulha (a corrida acabou com o susto, que já o tira do chamado) e o perigo zerar.
func _esperar_a_patrulha() -> void:
	await relogio.ate(func() -> bool: return tubarao.get("_chamado") == false and tubarao.perigo() == 0.0, 12.0)
	_conferir(tubarao.get("_chamado") == false, "o tubarão não voltou à patrulha depois da corrida")
	# O susto leva a tela de volta ao normal em ~1,6 s: espera o fim, para a corrida seguinte começar limpa.
	await relogio.ate(func() -> bool: return tubarao.get("_atacando") == false, 6.0)
	_conferir(tubarao.get("_atacando") == false, "o susto não acabou: a tela de ataque seguiu ligada 6 s depois da mordida")


## O caso devolve o que mexe: a camada da tensão é um nó filho do autoload `Audio`, e o anfitrião só devolve variáveis.
func _calar_a_tensao() -> void:
	audio.tensao_do_tubarao(0.0)
	if audio._tensao_transicao != null and audio._tensao_transicao.is_valid():
		audio._tensao_transicao.kill()
	audio._tensao_envelope = 0.0
	audio._tensao.stop()


func _frames(count: int) -> void:
	for frame in range(count):
		await process_frame


func _physics_frames(count: int) -> void:
	for frame in range(count):
		await physics_frame


## O vale se monta ao longo de vários quadros (world_builder): espera ficar pronto.
func _mundo_pronto() -> void:
	for i in range(3000):
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
