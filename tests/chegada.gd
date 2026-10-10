extends "res://tests/suite/caso.gd"
## Confere A CHEGADA PELO SAVEIRO, o começo do jogo jogado como o jogador joga.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste chegada
##
## "O jogador tem que começar com o boneco posicionado em cima de um saveiro, no
## pier. [...] No fim do primeiro dia, o saveiro obviamente some do mapa. Nesse
## momento deve ser introduzido ao jogador como andar e correr. O Pedro deve
## conduzir o jogador até a casa dele. [...] Durante esse processo, o jogador
## vai ficar cansado pela baixa do vigor e o Pedro deve introduzir o que é o
## vigor, o que é a stamina e o que é a vida." Oito perguntas:
##
##   1. NASCE NO CONVÉS: a partida nova põe o jogador em cima do saveiro
##      atracado, de pé no convés, e não na água nem em terra.
##   2. O PEDRO ESPERA NA PONTA DA PRANCHA: já saudou, a chegada começou pelo
##      desembarque, e ele fica ali enquanto o jogador não desce. E A CÂMERA O
##      MOSTRA (#119): o Pedro e o píer estão no quadro, sem o viajante nem a vela
##      e o mastro entre a câmera e ele. `-- --falsificar=sem_ombro` tira o ombro
##      da câmera, e o portão TEM de reprovar (o Pedro fica atrás do viajante).
##   3. A PRANCHA LEVA AO TABUADO: andando para a frente, o corpo desce do convés
##      ao píer, sem cair na água e sem empacar na borda — e o E no Pedro, e não
##      só chegar perto dele, fecha o desembarque.
##   4. CORRER É UM PASSO: com o Shift, correr um trecho fecha o passo da
##      corrida; tocar o Shift parado não fecha.
##   5. O PEDRO VAI NA FRENTE: depois da corrida vem o bom-dia ao Tonho; na
##      chave ele anda do píer rumo à Dona Candinha, e para à espera do
##      jogador que ficou para trás — e a tela avisa para voltar, até ele voltar.
##   6. O CORPO, UMA VEZ: com o vigor baixo na caminhada, o Pedro explica as três
##      barras na caixa de fala, com a fala de quem cansou e na voz dele, linha a
##      linha; de novo cansado, não repete — e a lembrança vai no save.
##   7. A PORTA ESPERA A CHAVE: a casa herdada está trancada até a Dona Zefa dar
##      a chave, e aberta depois; o baú tem a enxada, o balde e a maniva.
##   8. O SAVEIRO LARGA: no dia seguinte, o barco não está mais no píer.

##
## O PORTÃO NÃO DEPENDE DE MÁQUINA FOLGADA. Na bateria cheia, com sete portões brigando pela
## máquina, este reprovou sozinho: "na chave o Pedro não foi na frente até a Dona Candinha
## (estava a 82.4 e ficou a 82.1)". Aquela falha não se reproduziu só com quadro lento, e o
## que se fez foi tirar do portão as duas dependências que ele tinha:
##
##  - AS ESPERAS SÃO EM SEGUNDOS DE JOGO, E NÃO DE PAREDE (`tests/fixtures/relogio_de_jogo.gd`):
##    com a física limitada a 3 passos por quadro (`project.godot`), o jogo anda mais devagar
##    que a parede com o quadro acima de 50 ms, e na bateria cheia ele passa. O portão antigo,
##    com `MV_QUADRO_LENTO_MS=300` no ambiente, reprova na corrida ("o passo da corrida não
##    fechou"); este passa a 150 e a 300.
##  - A CONDUÇÃO É PELA MALHA DE NAVEGAÇÃO, que se assa numa linha à parte: sem ela o Pedro anda
##    reto do píer à praça e para na água. O passo da chave espera a malha pronta, como o jogador
##    a espera nos minutos que leva até ele.

const RelogioDeJogo = preload("res://tests/fixtures/relogio_de_jogo.gd")

## A distância a que o Pedro considera o jogador de volta (`GuiaPedro.VOLTA_A_ANDAR`).
const VOLTA_A_ANDAR_DO_PEDRO := 3.0

var falhas := 0
var relogio
var dia
var dialogo
var relogio_jogo: Node


func _initialize() -> void:
	_run.call_deferred()



## A NARRAÇÃO LIVRE (#106): com a caixa longa aberta, nenhum painel do grupo `obstaculos_do_hud`
## (minimapa, barra de mão, avisos, o painel do testador...) fica visível por cima dela. Cada um que a
## cobre tem de estar apagado (alfa efetivo, contando os pais); os que não a tocam não importam.
func _conferir_a_narracao_livre(dialogo: Node) -> void:
	var caixa: Rect2 = dialogo.retangulo_da_caixa()
	_conferir(caixa.has_area(), "a caixa da narração aberta não tem retângulo")
	for no in get_nodes_in_group("obstaculos_do_hud"):
		var controle := no as Control
		if controle == null or not controle.is_visible_in_tree():
			continue
		var alfa := 1.0
		var atual: Node = controle
		while atual is CanvasItem:
			alfa *= (atual as CanvasItem).modulate.a
			atual = atual.get_parent()
		var rect: Rect2 = controle.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, controle.size)
		_conferir(alfa < 0.05 or not rect.intersects(caixa), "o painel '%s' fica por cima da caixa da narração (alfa %.2f)" % [controle.name, alfa])

func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("CHEGADA_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	relogio_jogo = RelogioDeJogo.new()
	root.add_child(relogio_jogo)
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _quadros(4)
	await _mundo_pronto()
	await _quadros(8)
	relogio_jogo.ficar_lento()
	relogio = root.get_node("/root/Relogio")
	dia = root.get_node("/root/Dia")
	dialogo = root.get_node("/root/Dialogo")
	var vale = current_scene
	# AS CENAS FICAM DESLIGADAS: este portão dirige a chegada na mão (teleporta, aperta o E) e mede a
	# condução do Pedro; com a apresentação do Tonho tocando, ele anda em cena, e não conduz.
	if vale.get("cenas") != null:
		vale.cenas.desligadas = true
	var jogador = vale.player
	var mundo = vale.world
	var pedro = vale.get("pedro")
	var saveiro = vale.get("saveiro")
	_conferir(pedro != null and saveiro != null, "o vale não tem o Pedro ou o saveiro")
	if pedro == null or saveiro == null:
		_fechar()
		return

	# --- 1. NASCE NO CONVÉS ----------------------------------------------------------
	var no_conves: Vector3 = saveiro.ponto_do_conves()
	_conferir(saveiro.na_chegada() and saveiro.barco.visible, "a partida nova não tem o saveiro atracado")
	_conferir(no_conves.is_finite(), "o saveiro não mediu o ponto do convés")
	if not no_conves.is_finite():
		_fechar()
		return
	await _passos_de_fisica(40)
	var no_barco: Vector3 = saveiro.barco.global_position
	_conferir(Vector2(jogador.global_position.x - no_barco.x, jogador.global_position.z - no_barco.z).length() < 5.0,
		"o jogador não nasceu em cima do saveiro: está a %.1f do barco" % Vector2(jogador.global_position.x - no_barco.x, jogador.global_position.z - no_barco.z).length())
	_conferir(jogador.is_on_floor() and not jogador.is_swimming() and jogador.global_position.y > mundo.water_level(),
		"o jogador não está de pé no convés (no chão: %s, nadando: %s, altura %.2f, água %.2f)" % [str(jogador.is_on_floor()), str(jogador.is_swimming()), jogador.global_position.y, mundo.water_level()])

	# --- 2. O PEDRO ESPERA NA PONTA DA PRANCHA --------------------------------------
	_conferir(bool(pedro.get("_iniciado")), "o Pedro não saudou a chegada: a cadeia não começou")
	_conferir(pedro.passo_em_curso() == "desembarque", "a chegada não começou pelo desembarque (está em '%s')" % pedro.passo_em_curso())
	var onde_espera: Vector3 = saveiro.lugar_do_pedro()
	_conferir(Vector2(pedro.global_position.x - onde_espera.x, pedro.global_position.z - onde_espera.z).length() < 1.0,
		"o Pedro não está na ponta da prancha")
	await _ate(func() -> bool: return float(pedro.get("_espera")) <= 0.0, 15.0)
	await _passos_de_fisica(60)
	_conferir(Vector2(pedro.global_position.x - onde_espera.x, pedro.global_position.z - onde_espera.z).length() < 1.0,
		"no desembarque o Pedro saiu da ponta da prancha atrás do jogador, que ainda está no barco")

	# O TONHO ESPERA NA AREIA, ao lado do píer, e não no tabuado (07/10: "para não ficar com o
	# píer muito poluído"); ele volta à rotina quando a chegada passa da casa (parte 7).
	var lugares_t = root.get_node("/root/Lugares")
	var tonho_t = vale._achar_morador("tonho")
	var areia: Vector3 = lugares_t.ponto("areia")
	_conferir(areia != lugares_t.NENHUM and mundo.is_on_land(areia), "a areia ao lado do píer não resolve em terra firme: %s" % str(areia))
	_conferir(bool(vale.get("_tonho_na_areia")), "na chegada o Tonho não foi para a areia")
	if tonho_t != null and areia != lugares_t.NENHUM:
		_conferir(_no_chao(tonho_t.global_position, areia) < 2.5, "na chegada o Tonho está a %.1f da areia (em %s)" % [_no_chao(tonho_t.global_position, areia), str(tonho_t.global_position)])
		_conferir(_no_chao(tonho_t.global_position, mundo.ancoras["PierPiso"]) > 3.0, "na chegada o Tonho continua no tabuado do píer")

	# --- 2b. A CÂMERA MOSTRA O PEDRO E O PÍER (#119) ------------------------------------
	await _enquadramento(jogador, pedro, saveiro, mundo)

	# --- 3. A PRANCHA LEVA AO TABUADO -------------------------------------------------
	var piso: Vector3 = mundo.ancoras["PierPiso"]
	Input.action_press("mv_forward")
	var desceu := await _ate(func() -> bool:
		return jogador.global_position.distance_to(pedro.global_position) < 2.6 or pedro.passo_em_curso() != "desembarque", 12.0)
	Input.action_release("mv_forward")
	await _passos_de_fisica(10)
	_conferir(desceu, "andando para a frente, o jogador não chegou ao Pedro pela prancha (está em %s, o Pedro em %s)" % [str(jogador.global_position), str(pedro.global_position)])
	_conferir(not jogador.is_swimming() and jogador.global_position.y > mundo.water_level() and absf(jogador.global_position.y - piso.y) < 1.0,
		"a descida não acabou no tabuado (altura %.2f, piso %.2f, nadando %s)" % [jogador.global_position.y, piso.y, str(jogador.is_swimming())])
	# CHEGAR PERTO NÃO BASTA: o E é que conversa, e é o Pedro quem ensina.
	await _passos_de_fisica(30)
	_conferir(pedro.passo_em_curso() == "desembarque", "o desembarque fechou só de chegar perto do Pedro, sem o E")
	# FALA NO AR TIRA O E (#121, `tecla_dos_moradores._fala_ativa`): quem chegou ao Pedro enquanto ele ainda
	# saúda (a saudação dura a voz inteira, uns 10 s, em relógio de PAREDE) espera a fala acabar para apertar
	# o E, e o portão espera igual. Sem isto o resultado dependia de a máquina andar depressa: o jogo (em
	# segundos de jogo) anda mais devagar que a fala, e o jogador chegava com ela ainda no ar.
	_conferir(await _ate(func() -> bool: return not pedro.falando_agora(), 30.0), "a saudação do Pedro não acabou: o E nunca voltaria para ele")
	_conferir(vale.tecla_dos_moradores.perto() == pedro, "ao lado do Pedro, o E não está nele (está em %s)" % str(vale.tecla_dos_moradores.perto()))
	_apertar_e(vale)
	_conferir(await _ate(func() -> bool: return pedro.passo_em_curso() != "desembarque", 10.0),
		"com o E no Pedro, o desembarque não fechou")

	# --- 4. CORRER É UM PASSO --------------------------------------------------------
	_conferir(pedro.passo_em_curso() == "correr", "depois do desembarque não vem a corrida (vem '%s')" % pedro.passo_em_curso())
	await _ate(func() -> bool: return float(pedro.get("_espera")) <= 0.0, 15.0)
	# A SETA DA CORRIDA APONTA A PISTA, em terra, e não o Tonho (07/10: "quando manda correr, está
	# marcando o Tonho; isso tá confuso para o jogador").
	var pista: Vector3 = lugares_t.ponto("corrida")
	_conferir(pista != lugares_t.NENHUM and mundo.is_on_land(pista), "a pista da corrida não resolve em terra firme: %s" % str(pista))
	var alvo_da_corrida: Vector3 = pedro._cadeia.posicao_do_passo(pedro._cadeia.missao)
	_conferir(alvo_da_corrida.distance_to(pista) < 0.5, "o passo da corrida aponta %s, e não a pista %s" % [str(alvo_da_corrida), str(pista)])
	if tonho_t != null:
		_conferir(_no_chao(alvo_da_corrida, tonho_t.global_position) > 5.0, "a seta da corrida cai em cima do Tonho (a %.1f dele)" % _no_chao(alvo_da_corrida, tonho_t.global_position))
	_conferir(_no_chao(pista, mundo.ancoras["PierPiso"]) > 8.0, "a pista da corrida fica em cima do píer")
	# Tocar o Shift parado não é correr.
	_tocar_o_shift(jogador)
	await _passos_de_fisica(90)
	_conferir(pedro.passo_em_curso() == "correr", "tocar o Shift parado fechou o passo da corrida")
	jogador.global_position = pedro.global_position + Vector3(0.0, 0.3, 0.0) + _rumo_livre(jogador, mundo) * 1.5
	Input.action_press("mv_forward")
	_conferir(await _ate(func() -> bool: return pedro.passo_em_curso() != "correr", 10.0),
		"correndo com o Shift, o passo da corrida não fechou")
	Input.action_release("mv_forward")
	if jogador.is_running():
		_tocar_o_shift(jogador)

	# --- 5. O PEDRO VAI NA FRENTE -----------------------------------------------------
	_conferir(pedro.passo_em_curso() == "bom_dia", "depois da corrida não vem o bom-dia ao Tonho (vem '%s')" % pedro.passo_em_curso())
	# O Tonho está a dois passos da prancha: a condução se mede na da chave, que
	# leva do píer à Dona Candinha, na praça.
	var candinha = vale._achar_morador("candinha")
	# A condução vai pela malha: sem ela o Pedro anda reto do píer à praça e para na água.
	var navegacao = vale.get("navegacao")
	_conferir(navegacao != null and await _ate(func() -> bool: return navegacao.esta_pronta(), 60.0), "a malha de navegação não ficou pronta: o Pedro não tem por onde conduzir")
	_conferir(candinha != null and pedro.ir_ao_passo("chave"), "a chegada não tem a chave com a Dona Candinha")
	if candinha != null and pedro.passo_em_curso() == "chave":
		pedro.retomar()
		jogador.teleportar(pedro.global_position + Vector3(0.8, 0.1, 0.8), 0.0)
		var antes: float = _no_chao(pedro.global_position, candinha.global_position)
		# Junto do Pedro, ele anda: o jogador vai atrás, a dois passos.
		var andou := false
		for i in 16:
			jogador.teleportar(pedro.global_position + Vector3(1.0, 0.1, 1.0), 0.0)
			await _passos_de_fisica(15)
			if _no_chao(pedro.global_position, candinha.global_position) < antes - 2.0:
				andou = true
				break
		_conferir(andou, "na chave o Pedro não foi na frente até a Dona Candinha (estava a %.1f e ficou a %.1f)" % [antes, _no_chao(pedro.global_position, candinha.global_position)])
		# A LINHA DO PERCURSO (07/10, à noite): com o jogador a quatro passos atrás, o Pedro NÃO
		# para (os marcos de antes paravam, e o jogador não entendia o que fazer): continua até a
		# Dona Candinha.
		var antes_da_linha: float = _no_chao(pedro.global_position, candinha.global_position)
		for i in 8:
			var para_a_candinha: Vector3 = candinha.global_position - pedro.global_position
			para_a_candinha.y = 0.0
			var atras: Vector3 = -para_a_candinha.normalized() * 4.0 if para_a_candinha.length() > 0.1 else Vector3(4.0, 0.0, 0.0)
			jogador.teleportar(pedro.global_position + atras + Vector3(0.0, 0.1, 0.0), 0.0)
			await _passos_de_fisica(8)
		_conferir(_no_chao(pedro.global_position, candinha.global_position) < antes_da_linha - 1.0,
			"com o jogador a quatro passos atrás, o Pedro parou no caminho (estava a %.1f da Candinha e ficou a %.1f)" % [antes_da_linha, _no_chao(pedro.global_position, candinha.global_position)])
		# COM O JOGADOR À FRENTE, ele não espera ninguém: segue.
		var a_frente: Vector3 = candinha.global_position - pedro.global_position
		a_frente.y = 0.0
		if a_frente.length() > 9.0:
			jogador.teleportar(pedro.global_position + a_frente.normalized() * 7.0 + Vector3(0.0, 0.1, 0.0), 0.0)
			var antes_da_frente: float = _no_chao(pedro.global_position, candinha.global_position)
			await _passos_de_fisica(40)
			_conferir(not bool(pedro.get("_esperando_quem_ficou")), "com o jogador à frente no caminho, o Pedro ficou 'esperando' quem ficou")
			_conferir(_no_chao(pedro.global_position, candinha.global_position) < antes_da_frente - 1.0,
				"com o jogador à frente, o Pedro parou (estava a %.1f da Candinha e ficou a %.1f)" % [antes_da_frente, _no_chao(pedro.global_position, candinha.global_position)])
		# COM O JOGADOR PARA TRÁS, ele volta a buscá-lo em vez de ficar parado. "Para trás" é NA
		# LINHA DO PERCURSO (doze passos atrás no caminho do Pedro, em terra), e não doze passos
		# em linha reta — que, da praça para o píer, caem no mar, onde ninguém vai buscar ninguém
		# e o Pedro vinha pela beira, desviando da água a cada passo (07/10).
		var atras_na_linha := Vector3.INF
		for tanto in [12.0, 10.0, 8.0, 7.0]:
			var candidato: Vector3 = _atras_na_linha(vale.world, pedro.get("_caminho"), pedro.global_position, tanto)
			if not candidato.is_finite():
				var para_tras: Vector3 = candinha.global_position - pedro.global_position
				para_tras.y = 0.0
				candidato = vale.world.ground_position(pedro.global_position - para_tras.normalized() * tanto, 0.0)
			# EM TERRA E NA MALHA: o ponto tem de ser alcançável a pé (o do píer, por cima da água, não é).
			var alcance: PackedVector3Array = vale.navegacao.caminho_estreito(pedro.global_position, candidato)
			if alcance.size() >= 2 and _no_chao(alcance[alcance.size() - 1], candidato) < 1.0:
				atras_na_linha = candidato
				break
			if not atras_na_linha.is_finite() and alcance.size() >= 2 and _no_chao(alcance[alcance.size() - 1], pedro.global_position) >= 7.0:
				atras_na_linha = alcance[alcance.size() - 1]
		if not atras_na_linha.is_finite():
			atras_na_linha = pedro.global_position + Vector3(0.0, 0.0, 12.0)
		print("  o jogador para trás em %s, a %.1f do Pedro" % [str(Vector2(atras_na_linha.x, atras_na_linha.z)), _no_chao(atras_na_linha, pedro.global_position)])
		# A CONDUÇÃO PELA VISTA (#238): o Pedro à vista do jogador SEGUE, por mais atrás que ele esteja na
		# linha, e só fora da tela espera e depois volta. Primeiro o jogador doze passos atrás COM O PEDRO
		# NA TELA (a câmera virada para ele)...
		var rumo_a_ele := atan2(pedro.global_position.x - atras_na_linha.x, pedro.global_position.z - atras_na_linha.z)
		var rumos := {"para_ele": rumo_a_ele, "para_longe": rumo_a_ele + PI}
		var com_ele_na_tela := false
		for chave in ["para_ele", "para_longe"]:
			jogador.teleportar(atras_na_linha + Vector3(0.0, 0.1, 0.0), float(rumos[chave]))
			await _quadros(8)
			if pedro.esta_na_tela_do_jogador():
				com_ele_na_tela = true
				rumos["para_longe"] = float(rumos[chave]) + PI
				break
		if com_ele_na_tela:
			var antes_da_vista: float = _no_chao(pedro.global_position, candinha.global_position)
			await _passos_de_fisica(100)
			_conferir(not bool(pedro.get("_esperando_quem_ficou")), "com o Pedro na tela do jogador, a doze passos, ele voltou para buscá-lo")
			_conferir(_no_chao(pedro.global_position, candinha.global_position) < antes_da_vista - 1.0 or pedro._chegou_ao_destino(),
				"com o Pedro na tela do jogador, ele parou no caminho (estava a %.1f da Candinha e ficou a %.1f)" % [antes_da_vista, _no_chao(pedro.global_position, candinha.global_position)])
		else:
			print("  a vista do Pedro estava coberta nos dois rumos: a parte 'à vista' não foi conferida")
		# ...e agora com a câmera virada para o outro lado: fora da tela ele não volta de pronto (a vista
		# só muda depois de OCULTO_APOS), espera parado, e só depois de ESPERA_ANTES_DE_VOLTAR volta.
		jogador.teleportar(atras_na_linha + Vector3(0.0, 0.1, 0.0), float(rumos["para_longe"]))
		await _quadros(8)
		_conferir(not pedro.esta_na_tela_do_jogador(), "com a câmera virada para o outro lado, o Pedro continua na tela")
		await _passos_de_fisica(20)
		_conferir(not bool(pedro.get("_esperando_quem_ficou")), "o Pedro saiu da tela e voltou no mesmo instante, sem a espera")
		var longe_antes: float = _no_chao(pedro.global_position, jogador.global_position)
		var de_onde: Vector3 = pedro.global_position
		var serie: Array[String] = []
		var parado_desde := Vector3.INF
		var maior_distancia := longe_antes
		for i in 48:
			await _passos_de_fisica(10)
			serie.append("%s %.2f v%.2f" % ["E" if bool(pedro.get("_esperando_quem_ficou")) else "-", _no_chao(pedro.global_position, jogador.global_position), Vector2(pedro.velocity.x, pedro.velocity.z).length()])
			maior_distancia = maxf(maior_distancia, _no_chao(pedro.global_position, jogador.global_position))
			# Fora da tela há OCULTO_APOS (2 s) até ele ser dado por oculto e ESPERA_ANTES_DE_VOLTAR (3 s) até voltar:
			# entre os 3 e os 4,5 s (20 passos de antes, mais i * 10) ele espera parado.
			if i == 15:
				parado_desde = pedro.global_position
			if i == 24 and parado_desde.is_finite():
				_conferir(_no_chao(pedro.global_position, parado_desde) < 1.0 and not bool(pedro.get("_esperando_quem_ficou")),
					"fora da tela, o Pedro não esperou parado antes de voltar (andou %.1f)" % _no_chao(pedro.global_position, parado_desde))
		print("  a série (a cada 10 passos: esperando, distância, velocidade): ", " | ".join(serie))
		var longe_depois: float = _no_chao(pedro.global_position, jogador.global_position)
		# O caminho da volta, para o diagnóstico: o composto (larga + emendas), o estreito e o largo cru.
		var nav = vale.get("navegacao")
		var volta: PackedVector3Array = pedro.get("_volta")
		print("  a volta: %d pontos (%.1f u); de %s a %s; estreito %.1f u, largo cru %.1f u (sai a %.2f, chega a %.2f); andou %.2f em 60 passos" % [
			volta.size(), _comprimento(volta), str(Vector2(de_onde.x, de_onde.z)), str(Vector2(jogador.global_position.x, jogador.global_position.z)),
			_comprimento(nav.caminho_estreito(de_onde, jogador.global_position)) if nav.has_method("caminho_estreito") else -1.0,
			_comprimento(nav.caminho_largo(de_onde, jogador.global_position)) if nav.has_method("caminho_largo") else -1.0,
			_no_chao(nav.caminho_largo(de_onde, jogador.global_position)[0], de_onde) if nav.has_method("caminho_largo") and nav.caminho_largo(de_onde, jogador.global_position).size() > 0 else -1.0,
			_no_chao(nav.caminho_largo(de_onde, jogador.global_position)[-1], jogador.global_position) if nav.has_method("caminho_largo") and nav.caminho_largo(de_onde, jogador.global_position).size() > 0 else -1.0,
			_no_chao(pedro.global_position, de_onde)])
		_conferir(bool(pedro.get("_esperando_quem_ficou")) or longe_depois < VOLTA_A_ANDAR_DO_PEDRO,
			"com o jogador doze passos para trás, o Pedro não foi buscá-lo")
		_conferir(longe_depois < maior_distancia - 1.5 or longe_depois < VOLTA_A_ANDAR_DO_PEDRO,
			"com o jogador para trás, o Pedro não veio na direção dele (chegou a estar a %.1f e ficou a %.1f)" % [maior_distancia, longe_depois])
		# E A TELA DIZ QUE ELE PAROU: "deve aparecer um aviso em tela informando para
		# se reaproximar do NPC". Voltando para perto, o aviso sai.
		_conferir(str(vale.hud.aviso_de_espera()).contains("buscar") or longe_depois < VOLTA_A_ANDAR_DO_PEDRO,
			"o Pedro voltou por quem ficou para trás e a tela não avisou: '%s'" % str(vale.hud.aviso_de_espera()))
		jogador.teleportar(pedro.global_position + Vector3(1.0, 0.1, 1.0), 0.0)
		_conferir(await _ate(func() -> bool: return str(vale.hud.aviso_de_espera()) == "", 3.0),
			"o jogador voltou para perto do Pedro e o aviso de voltar continuou na tela")

	# --- 6. O CORPO, UMA VEZ -------------------------------------------------------------
	_conferir(not pedro.lembrancas().has(pedro.LEMBRANCA_DO_CORPO), "o Pedro explicou o corpo antes de o jogador cansar")
	jogador.teleportar(pedro.global_position + Vector3(1.0, 0.1, 1.0), 0.0)
	jogador.definir_vigor(jogador.vigor_maximo() * 0.2)
	var explicou := await _ate(func() -> bool: return dialogo.ativo, 15.0)
	_conferir(explicou, "com o vigor baixo na caminhada, o Pedro não explicou o corpo")
	if explicou:
		_conferir(str(dialogo.quem_fala) == str(root.get_node("/root/Jogo").nome_pedro), "a explicação do corpo não é na voz do Pedro (é '%s')" % str(dialogo.quem_fala))
		var falas: Array = dialogo._falas
		var juntas := " ".join(falas)
		# Cinco desde a #82: o respiro, a vida, o fôlego (a reserva do dia), o vigor
		# e o nado — a fala nova de 06/10 sobre o fôlego na água ficou ("ele não
		# deve ser removido").
		_conferir(falas.size() == 5, "a explicação do corpo tem %d fala(s), e são cinco: o respiro, a vida, o fôlego, o vigor e o nado" % falas.size())
		_conferir(juntas.contains("vida") and juntas.contains("fôlego") and juntas.contains("vigor"), "a explicação do corpo não fala da vida, do fôlego e do vigor")
		_conferir(juntas.contains("gastou agora"), "cansado, o Pedro não usou a fala de quem cansou")
		# NA VOZ DELE: "na explicação do pedro sobre a barra de stamina e
		# similares, crie os audios para ele narrar". A primeira linha toca ao abrir,
		# e cada linha do corpo tem a narração dela.
		_conferir(dialogo.voz_tocando() == "pedro_corpo_respiro",
			"a explicação do corpo abriu sem a voz do Pedro (tocando: '%s')" % dialogo.voz_tocando())
		for fala in pedro.get("_corpo"):
			var audio := str((fala as Dictionary).get("audio", ""))
			_conferir(audio != "" and ResourceLoader.exists("res://assets/audio/vozes/%s.mp3" % audio),
				"a linha do corpo '%s…' não tem a narração do Pedro ('%s')" % [str((fala as Dictionary).get("texto", "")).left(30), audio])
		# E O ARREMATE DA CHEGADA, depois do convite lido, na voz dele (07/10).
		var audio_do_arremate := str((pedro._cadeia.arremate as Dictionary).get("audio", ""))
		_conferir(audio_do_arremate != "" and ResourceLoader.exists("res://assets/audio/vozes/%s.mp3" % audio_do_arremate),
			"o arremate da chegada não tem a narração do Pedro ('%s')" % audio_do_arremate)
	if explicou:
		# A TELA ESCURECE E A BARRA DA VEZ ACENDE (#106): no respiro tudo apagado;
		# cada linha seguinte acende a barra de que fala e apaga as outras; fechada
		# a caixa, o véu some e o HUD volta inteiro.
		var hud_do_vale = vale.hud
		_conferir(hud_do_vale.destacando() and hud_do_vale._veu_do_destaque != null and hud_do_vale._veu_do_destaque.visible, "a explicação do corpo não escureceu a tela")
		_conferir(hud_do_vale.barra_destacada() == "", "no respiro já havia uma barra acesa ('%s')" % hud_do_vale.barra_destacada())
		await process_frame
		await process_frame
		_conferir_a_narracao_livre(dialogo)
		var barras := {"Vida": hud_do_vale.barra_vida, "Folego": hud_do_vale.barra_folego, "Stamina": hud_do_vale.barra_stamina}
		while dialogo._indice < dialogo._falas.size() - 1:
			dialogo._indice += 1
			dialogo._mostrar_fala()
			await process_frame
			var voz := str(dialogo._vozes[dialogo._indice]) if dialogo._indice < dialogo._vozes.size() else ""
			var esperada := str(vale.BARRA_DA_VOZ.get(voz, "?"))
			_conferir(hud_do_vale.barra_destacada() == esperada, "na linha '%s' a barra acesa é '%s', e devia ser '%s'" % [voz, hud_do_vale.barra_destacada(), esperada])
			for nome in barras:
				var acesa: bool = (barras[nome] as CanvasItem).modulate == Color.WHITE
				_conferir(acesa == (nome == esperada), "na linha '%s' a barra %s está %s" % [voz, nome, "acesa" if acesa else "apagada"])
	await _fechar_a_fala()
	_conferir(not vale.hud.destacando() and (vale.hud._veu_do_destaque == null or not vale.hud._veu_do_destaque.visible) and vale.hud.barra_vida.modulate == Color.WHITE,
		"fechada a explicação, a tela continuou escura ou o HUD apagado")
	_conferir(pedro.lembrancas().has(pedro.LEMBRANCA_DO_CORPO), "a explicação do corpo não ficou na lembrança que vai no save")
	jogador.definir_vigor(jogador.vigor_maximo() * 0.2)
	var repetiu := await _ate(func() -> bool: return dialogo.ativo, 4.0)
	_conferir(not repetiu, "cansado de novo, o Pedro explicou o corpo outra vez")
	await _fechar_a_fala()

	# --- 7. A PORTA ESPERA A CHAVE ----------------------------------------------------------
	var interiores = vale.get("interiores")
	var sala = interiores.sala_de("casa") if interiores != null else null
	_conferir(sala != null, "o vale não tem o cômodo da casa herdada")
	if sala != null:
		_conferir(sala.trancada(), "antes da chave da Dona Zefa, a casa herdada já está aberta")
		pedro.ir_ao_passo("casa")
		pedro.retomar()
		await _quadros(3)
		_conferir(not sala.trancada(), "com a chave dada, a casa herdada continua trancada")
		# A CHAVE É UM ITEM (#217): quem chega ao passo da casa sem ela (passo pulado, save antigo) a recebe, e a
		# porta só abre porque ela está na mochila; tirada a chave, a porta tranca de novo.
		var mochila = root.get_node("/root/Inventario")
		_conferir(mochila.tem("chave_da_casa"), "no passo da casa, a chave da Dona Zefa não está na mochila")
		mochila.consumir("chave_da_casa", mochila.quantidade("chave_da_casa"))
		await _quadros(2)
		_conferir(sala.trancada(), "sem a chave na mochila, a porta da casa herdada abre")
		pedro.retomar()
		await _quadros(2)
		_conferir(mochila.quantidade("chave_da_casa") == 1, "quem chega ao passo da casa sem a chave não a recebe de volta (%d)" % mochila.quantidade("chave_da_casa"))
		_conferir(not sala.trancada(), "com a chave de volta na mochila, a casa herdada continua trancada")
		var casa = vale.get("casa")
		var tem := {}
		for monte in casa.bau:
			tem[str(monte.get("id", ""))] = int(monte.get("qtd", 0))
		_conferir(tem.has("enxada") and tem.has("balde") and int(tem.get("semente_mandioca", 0)) >= 1, "o baú da casa não tem a enxada, o balde e a maniva do finado: %s" % str(tem))
		# E O TONHO VOLTA À ROTINA quando a chegada passa da casa (07/10).
		pedro.ir_ao_passo("pegar")
		pedro.retomar()
		_conferir(await _ate(func() -> bool: return not bool(vale.get("_tonho_na_areia")), 3.0), "passada a casa, o Tonho continua preso na areia")

	# --- 8. O SAVEIRO LARGA ---------------------------------------------------------------------
	relogio.dia = 2
	dia.definir_hora(9.0)
	await _quadros(5)
	_conferir(not saveiro.barco.visible, "no dia seguinte, o saveiro continua no píer")
	_fechar()


## O rumo de quem está no tabuado para longe da água: do Pedro para a praça.
func _rumo_livre(jogador, mundo) -> Vector3:
	var praca: Vector3 = mundo.ancoras.get("Praça", jogador.global_position)
	var rumo: Vector3 = praca - jogador.global_position
	rumo.y = 0.0
	if rumo.length() < 0.1:
		return Vector3.FORWARD
	rumo = rumo.normalized()
	jogador.teleportar(jogador.global_position, atan2(rumo.x, rumo.z))
	return rumo


## O E, pelo caminho do jogo: a tecla de interagir, a quem conversa com os
## moradores (`tecla_dos_moradores.gd`).
func _apertar_e(vale) -> void:
	var tecla := InputEventKey.new()
	tecla.keycode = KEY_E
	tecla.physical_keycode = KEY_E
	tecla.pressed = true
	vale.tecla_dos_moradores._unhandled_key_input(tecla)


## O Shift, pelo caminho do jogo: a tecla da ação de correr.
func _tocar_o_shift(jogador) -> void:
	var tecla := InputEventKey.new()
	tecla.keycode = KEY_SHIFT
	tecla.physical_keycode = KEY_SHIFT
	tecla.pressed = true
	jogador._input(tecla)


## O ponto `quanto` unidades ATRÁS de `posicao` na linha `caminho` (projetando `posicao` nela).
## Linha curta demais: segue para trás na direção do primeiro trecho, encurtando até cair em
## terra. Sem linha, INF.
static func _atras_na_linha(mundo, caminho: PackedVector3Array, posicao: Vector3, quanto: float) -> Vector3:
	if caminho.size() < 2:
		return Vector3.INF
	var q := Vector2(posicao.x, posicao.z)
	var melhor := INF
	var progresso := 0.0
	var andado := 0.0
	for i in range(caminho.size() - 1):
		var a := Vector2(caminho[i].x, caminho[i].z)
		var b := Vector2(caminho[i + 1].x, caminho[i + 1].z)
		var proj := Geometry2D.get_closest_point_to_segment(q, a, b)
		if q.distance_to(proj) < melhor:
			melhor = q.distance_to(proj)
			progresso = andado + a.distance_to(proj)
		andado += a.distance_to(b)
	for tanto in [quanto, quanto * 0.75, quanto * 0.6]:
		var ponto := Vector3.INF
		var alvo: float = progresso - tanto
		if alvo >= 0.0:
			andado = 0.0
			for i in range(caminho.size() - 1):
				var trecho := Vector2(caminho[i].x - caminho[i + 1].x, caminho[i].z - caminho[i + 1].z).length()
				if andado + trecho >= alvo and trecho > 0.0:
					ponto = caminho[i].lerp(caminho[i + 1], (alvo - andado) / trecho)
					break
				andado += trecho
		else:
			var rumo: Vector3 = caminho[0] - caminho[1]
			rumo.y = 0.0
			ponto = caminho[0] + (rumo.normalized() if rumo.length() > 0.05 else Vector3.BACK) * -alvo
		if ponto.is_finite():
			ponto = mundo.ground_position(ponto, 0.0)
			if not mundo.has_method("water_depth_at") or float(mundo.water_depth_at(ponto)) < 0.2:
				return ponto
	return Vector3.INF


static func _comprimento(pontos: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, pontos.size()):
		total += Vector2(pontos[i].x - pontos[i - 1].x, pontos[i].z - pontos[i - 1].z).length()
	return total


## A CHEGADA ENQUADRADA (#119): na partida nova a câmera fica atrás do viajante, no convés, e o Pedro espera na
## mesma linha, na ponta da prancha — escondido por ele, com a vela e o mastro ao lado. O ombro da câmera
## (`Player.enquadrar_de_ombro`) a desloca para o lado da proa: o Pedro e o píer ficam no quadro (no miolo dele,
## e não na borda), o corpo do viajante não os tapa, e a vela e o mastro não cortam a linha da câmera ao Pedro.
const MARGEM_DO_QUADRO := 0.12
## O quanto o viajante pode chegar perto da linha da câmera ao peito do Pedro (m): o raio do corpo (0,28) e uma folga.
const FOLGA_DO_CORPO := 0.4


func _enquadramento(jogador, pedro, saveiro, mundo) -> void:
	var pedido := OS.get_environment("MV_FALSIFICAR")
	for argumento in OS.get_cmdline_user_args():
		if str(argumento).begins_with("--falsificar="):
			pedido = str(argumento).trim_prefix("--falsificar=")
	if pedido == "sem_ombro":
		jogador.enquadrar_de_ombro(Vector3.ZERO)
		print("  FALSIFICAÇÃO: sem o ombro da câmera, atrás do viajante: o portão TEM de reprovar")
	else:
		_conferir(jogador.ombro_da_camera().length() > 1.0, "a partida nova não pôs o ombro na câmera da chegada (%s)" % str(jogador.ombro_da_camera()))
	await _quadros(4)
	var camera: Camera3D = jogador.camera
	var tela: Vector2 = root.get_visible_rect().size
	var peito: Vector3 = pedro.global_position + Vector3.UP * 1.0
	var piso: Vector3 = mundo.ancoras["PierPiso"]
	for alvo in [["o Pedro", peito], ["o tabuado do píer", piso + Vector3.UP * 0.5]]:
		var ponto: Vector3 = alvo[1]
		var no_quadro: bool = not camera.is_position_behind(ponto) and camera.is_position_in_frustum(ponto)
		var lugar := camera.unproject_position(ponto)
		var dentro_x: bool = lugar.x >= tela.x * MARGEM_DO_QUADRO and lugar.x <= tela.x * (1.0 - MARGEM_DO_QUADRO)
		var dentro_y: bool = lugar.y >= tela.y * MARGEM_DO_QUADRO and lugar.y <= tela.y * (1.0 - MARGEM_DO_QUADRO)
		var no_miolo: bool = dentro_x and dentro_y
		_conferir(no_quadro and no_miolo, "na chegada %s não está no miolo do quadro (tela %s, %s)" % [alvo[0], str(lugar.snapped(Vector2.ONE)), str(tela)])
	# O VIAJANTE NÃO TAPA O PEDRO: a linha da câmera ao peito dele passa longe do eixo do corpo.
	var pes: Vector3 = jogador.global_position
	var cabeca: Vector3 = pes + Vector3.UP * float(jogador.character_height)
	var proximos := Geometry3D.get_closest_points_between_segments(camera.global_position, peito, pes, cabeca)
	var folga: float = proximos[0].distance_to(proximos[1])
	print("  a linha da câmera ao Pedro passa a %.2f m do eixo do viajante" % folga)
	_conferir(folga >= FOLGA_DO_CORPO, "o viajante tapa o Pedro: a linha da câmera ao peito dele passa a %.2f m do eixo do corpo (mínimo %.2f)" % [folga, FOLGA_DO_CORPO])
	# NEM A VELA, NEM O MASTRO.
	_conferir(not saveiro.vela_entre(camera.global_position, peito), "a vela, o mastro ou a retranca do saveiro estão entre a câmera e o Pedro")


func _no_chao(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _fechar_a_fala() -> void:
	var ate := Time.get_ticks_msec() + 4000
	while dialogo.ativo and Time.get_ticks_msec() < ate:
		dialogo._fechar()
		await process_frame
	await _quadros(3)


func _fechar() -> void:
	Input.action_release("mv_forward")
	print("")
	if falhas == 0:
		print("CHEGADA_OK: a partida nova nasce de pé no convés do saveiro; o Pedro espera na ponta da prancha e não sai dali; a prancha leva ao tabuado sem água nem borda, e o E nele, e não chegar perto, fecha o desembarque; correr com o Shift fecha a corrida, e tocá-lo parado não; na chave o Pedro vai na frente rumo à Dona Candinha e espera quem ficou para trás; com o vigor baixo ele explica a vida, o fôlego e o vigor uma vez só, e a lembrança vai no save; a casa espera a chave da Dona Zefa, com a enxada, o balde e a maniva no baú; e no dia seguinte o saveiro larga")
	else:
		print("chegada: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _passos_de_fisica(n: int) -> void:
	for i in n:
		await physics_frame


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


## Roda quadros até `condicao` valer, com teto em SEGUNDOS DE JOGO (ver o cabeçalho):
## nunca menos, em parede, que os segundos de relógio que este portão esperava antes.
func _ate(condicao: Callable, segundos: float) -> bool:
	return await relogio_jogo.ate(condicao, segundos)


func _mundo_pronto() -> void:
	for i in 3000:
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
