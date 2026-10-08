extends SceneTree
## Confere O E NOS SÍTIOS DE OBRA (scripts/prototipo_3d/tecla_das_bancadas.gd): o poço,
## a ponte, o mirante, o cemitério e a carroça respondem ao E, e o E vai para a
## obra que a missão pede — não para o morador parado ao lado do jogador.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/obras_com_e.gd
##
## "O botão de interagir com o E está sendo sobreposto." / "Não consegui interagir
## com o poço, logo essa missão quebrou." Seis passos de missão fecham numa obra, e
## só a mesa do prumo respondia ao E: no poço a tecla só chegava ao Pedro (que segue
## o jogador) e à Dona Zefa e ao Cosme (que o mutirão põe numa roda de dois passos e
## meio em volta dele). O J abria no diário, e a aba de obras ficava a um Tab que
## ninguém sabia. Todos os portões de missão passavam por cima disto: teletransporte,
## `Obras.executar` direto, `tecla.usar()` direto. Este anda o caminho do jogador —
## a tecla de verdade, pela janela (`push_input`) —, em cada um dos cinco sítios:
##
##   0. O RESUMO DO HUD DIZ A TECLA: todo passo de obra, de toda fila, escreve nos
##      três idiomas, em até 60 letras, a tecla que faz a obra — e o poço e a
##      carroça, onde o E passou a valer, dizem o [E] e o [J].
##   1. LIGADO SÓ COM RAZÃO: antes de a missão chegar ao passo (e de ensinar a
##      planta), parado no mesmo ponto não há dica de obra nenhuma.
##   2. COM O PASSO ABERTO E O PEDRO AO LADO, de frente para o sítio, o E é DO SÍTIO:
##      o foco o escolhe, SÓ a dica dele acende, e o rótulo diz o que a tecla faz.
##   3. O J ABRE DIRETO EM OBRAS, no sítio, com o cursor na obra da missão — e longe
##      dele abre no diário, como sempre.
##   4. O E ABRE O PAINEL NA ABA DE OBRAS DAQUELE SÍTIO, com o cursor na obra da
##      missão; o E de novo toca a obra, e o passo fecha.
##   5. FEITA A OBRA, a dica apaga: sem obra à mão e sem passo pedindo, o sítio fica
##      quieto, e o E volta a ser de quem estiver perto.
##   6. VIRADO PARA O MORADOR, O MORADOR: o viés do sítio zera a distância, não o
##      rumo — quem quer conversar com a Dona Zefa no poço se vira para ela.
##
## Falsificação: tire `raio_do_e` do sítio em `BancadasVale.OBRAS` (a 1 e a 2
## reprovam), zere `vies_da_obra_pedida` (o Pedro ao lado leva o E, e a 2 reprova), ou
## volte o resumo do poço para "Conserte o poço com a Dona Zefa" (a 0 reprova).

const FocoDoE = preload("res://scripts/prototipo_3d/foco_do_e.gd")

## Os cinco sítios. `fila`: a cadeia que tem o passo ("guia" é a chegada do Pedro,
## que não mora em `_cadeias`); `ancora`: onde o sítio fica; `distancia` e `angulo`
## (graus, 0 = +x e 90 = +z): onde o jogador para, a partir da âncora, e de que lado
## ele chega.
const SITIOS := [
	{"sitio": "poco", "fila": "guia", "passo": "mutirao_poco", "obra": "poco_corda", "ancora": "Poço",
		"hora": 15.0, "distancia": 3.0, "angulo": 232.0},
	{"sitio": "ponte", "fila": "pedro_ponte", "passo": "ponte", "obra": "ponte_levantar", "ancora": "Ponte",
		"hora": 10.0, "distancia": 5.8, "angulo": 283.0},
	{"sitio": "mirante", "fila": "pedro_arraial", "passo": "mirante_obra", "obra": "mirante_levantar", "ancora": "Mirante",
		"hora": 10.0, "distancia": 4.2, "angulo": 90.0},
	{"sitio": "cemiterio", "fila": "damiao", "passo": "coveiro_cercado", "obra": "cemiterio_cercado", "ancora": "Cemitério",
		"hora": 10.0, "distancia": 5.6, "angulo": 90.0},
	{"sitio": "carroca", "fila": "benedito_carroca", "passo": "carroca_mutirao", "obra": "arraial_carroca", "ancora": "Casa de Carro Quebrado",
		"hora": 15.0, "distancia": 3.9, "angulo": 208.0},
]
## O teto do resumo de missão no HUD (o mesmo de `tests/cadeia_das_missoes.gd`).
const LETRAS_DO_RESUMO := 60
## Os passos de obra em que o E passou a valer: o resumo diz as duas teclas.
const COM_AS_DUAS_TECLAS := ["mutirao_poco", "carroca_mutirao"]
## Quão longe das lápides o jogador fica (o alcance delas é 2,2): a dica de "Ler
## lápide" não entra na conta deste portão.
const AFASTADO_DAS_LAPIDES := 2.6

var falhas := 0
var vale
var jogador
var foco
var bancadas
var moradores
var painel
var telas
var obras
var receitas
var inventario


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("OBRAS_COM_E_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	# --- 0. O RESUMO DO HUD DIZ A TECLA ---------------------------------------------------
	_resumos_dos_passos_de_obra()
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _quadros(4)
	await _mundo_pronto()
	await _quadros(8)
	vale = current_scene
	# O ACEITE É AUTOMÁTICO AQUI (08/10): este portão abre filas pelo E e segue; a tela de aceite
	# pausaria o vale no meio da medida (a tela tem portão próprio, tests/missao_a_vista.gd).
	if vale.get("aceite") != null:
		vale.aceite.automatico = true
	jogador = vale.player
	foco = vale.get("foco_do_e")
	bancadas = vale.get("tecla_das_bancadas")
	moradores = vale.get("tecla_dos_moradores")
	painel = vale.get("painel")
	telas = vale.get("telas")
	obras = root.get_node("/root/Obras")
	receitas = root.get_node("/root/Receitas")
	inventario = root.get_node("/root/Inventario")
	root.get_node("/root/Dia").pausado = true
	_conferir(foco != null and bancadas != null and moradores != null and painel != null and telas != null and vale.pedro != null,
		"o vale não tem o foco do E, o E das bancadas, o E dos moradores, o painel, as telas ou o Pedro")
	if foco == null or bancadas == null or moradores == null or painel == null or telas == null or vale.pedro == null:
		_fechar()
		return

	var primeiro := true
	for sitio in SITIOS:
		await _um_sitio(sitio, primeiro)
		primeiro = false
	_fechar()


func _um_sitio(sitio: Dictionary, primeiro: bool) -> void:
	var qual: String = sitio["sitio"]
	var obra: String = sitio["obra"]
	var pedro = vale.pedro
	print("--- ", qual)
	# A FESTA DA MISSÃO DO SÍTIO ANTERIOR ACABA ANTES: ela cobre o vale por uns sete
	# segundos, e com ela na tela as dicas do E se calam (`foco_do_e.coberto`).
	var conquista = vale.get("conquista")
	if conquista != null:
		await _ate(func() -> bool: return not conquista.ativa() and not conquista.esperando(), 40.0)
	# O ESTADO DO DIA: cada um no posto da hora, e a chegada do Pedro terminada (só o
	# poço é do tutorial, em que ele segue o jogador; do resto em diante ele tem posto).
	root.get_node("/root/Dia").definir_hora(float(sitio["hora"]))
	for morador in vale.moradores:
		morador.ir_ao_posto_agora()
	if not primeiro:
		pedro.missao = pedro.MISSOES.size()
		pedro.set("_despedida_feita", true)
	var ancora: Vector3 = vale.world.ancoras.get(sitio["ancora"], Vector3.INF)
	_conferir(ancora.is_finite(), "%s: o vale não tem a âncora '%s'" % [qual, sitio["ancora"]])
	if not ancora.is_finite():
		return
	var ponto := _ponto_livre(ancora, float(sitio["distancia"]), float(sitio["angulo"]), true)
	_conferir(ponto.is_finite(), "%s: não achei chão livre a %.1f passos da âncora, para o jogador parar" % [qual, float(sitio["distancia"])])
	if not ponto.is_finite():
		return
	var rumo := _rumo(ponto, ancora)
	var lado := _lado_livre(ponto, rumo)

	# --- 1. LIGADO SÓ COM RAZÃO ----------------------------------------------------------
	_pr_o_jogador(ponto, rumo)
	pedro.global_position = lado + Vector3.UP * 0.1
	await _passos_de_fisica(10)
	pedro.global_position = lado + Vector3.UP * 0.1
	await _quadros(3)
	_conferir(bancadas.perto() == "",
		"%s: antes de o passo chegar (e de a planta ser ensinada) o sítio já responde ao E: '%s'" % [qual, bancadas.perto()])
	_conferir(not _dica_acesa(bancadas), "%s: a dica de obra está acesa sem obra à mão e sem passo pedindo" % qual)

	# --- o passo chega: a fila no passo de obra, anunciado (ensina a planta) ---------------
	var fila = pedro._cadeia if str(sitio["fila"]) == "guia" else vale._cadeias.get(str(sitio["fila"]))
	_conferir(fila != null, "%s: o vale não tem a fila '%s'" % [qual, sitio["fila"]])
	if fila == null:
		return
	var indice := _indice_do_passo(fila, str(sitio["passo"]))
	_conferir(indice >= 0, "%s: a fila não tem o passo '%s'" % [qual, sitio["passo"]])
	if indice < 0:
		return
	# O anúncio de cada passo até aqui ensina o que ele ensina, como no jogo (a planta
	# da ponte vem do passo das tábuas, a do mirante do passo do material).
	for i in indice + 1:
		receitas.passo_abriu(str((fila.passos[i] as Dictionary).get("id", "")))
	fila.iniciado = true
	fila.missao = indice
	fila.espera = 0.0
	fila.retomar()
	var passo: Dictionary = fila.passo_atual()
	_conferir(fila.pede_obra(qual) and fila.obra_pedida(qual) == obra,
		"%s: o passo '%s' não diz que pede a obra '%s' (diz '%s')" % [qual, sitio["passo"], obra, fila.obra_pedida(qual)])
	_conferir(obras.disponiveis(qual).has(obra), "%s: com o passo anunciado a obra '%s' não está na lista do sítio: %s" % [qual, obra, str(obras.disponiveis(qual))])
	# O MUTIRÃO: quem ajuda vai para a roda em volta do sítio (a carroça e o poço).
	var ajudantes: Dictionary = passo.get("mutirao", {})
	var i_ajudante := 0
	for quem in ajudantes:
		var ajudante = vale._achar_morador(str(quem))
		var onde: Vector3 = fila._lugar_no_mutirao(passo, i_ajudante, ajudantes.size())
		i_ajudante += 1
		if ajudante != null and onde.is_finite():
			ajudante.global_position = onde + Vector3.UP * 0.1

	# --- 2. COM O PASSO ABERTO E O PEDRO AO LADO, O E É DO SÍTIO ---------------------------
	_pr_o_jogador(ponto, rumo)
	await _passos_de_fisica(10)
	pedro.global_position = lado + Vector3.UP * 0.1
	_recolocar_ajudantes(fila, passo)
	await _quadros(3)
	var perto_do_pedro: Vector2 = Vector2(pedro.global_position.x - jogador.global_position.x, pedro.global_position.z - jogador.global_position.z)
	_conferir(perto_do_pedro.length() < 2.0 and moradores._ao_alcance() != null,
		"%s: não há morador ao alcance da conversa (Pedro a %.2f): o caso do E tomado não se montou" % [qual, perto_do_pedro.length()])
	_conferir(bancadas.perto() == qual, "%s: com o passo aberto o E não está no sítio (está em '%s')" % [qual, bancadas.perto()])
	_conferir(foco.dono() == bancadas, "%s: com o Pedro ao lado, virado para o sítio, o E é de '%s', e não do sítio (contas: %s)" % [qual, _nome(foco.dono()), _contas()])
	_conferir(_dica_acesa(bancadas) and _dicas_acesas() == 1,
		"%s: devia haver UMA dica acesa, a do sítio; há %d (sítio: %s, moradores: %s)" % [qual, _dicas_acesas(), str(_dica_acesa(bancadas)), str(_dica_acesa(moradores))])
	var rotulo := _rotulo_da_dica(bancadas)
	var aceitos := _rotulos_do(qual)
	_conferir(not aceitos.is_empty() and aceitos.has(rotulo),
		"%s: o rótulo da dica é '%s', e devia ser um dos de data/dicas_do_e_nas_obras.json (%s)" % [qual, rotulo, str(aceitos)])

	# --- 3. O J ABRE DIRETO EM OBRAS ------------------------------------------------------
	_apertar(KEY_J)
	await _quadros(3)
	_conferir(painel.aberto, "%s: o J não abriu o painel" % qual)
	_conferir(painel.aba() == painel.Aba.OBRAS and str(painel.obra_em_foco) == qual,
		"%s: o J abriu na aba %d com a obra em foco '%s', e devia abrir em Obras no sítio, com o passo pedindo" % [qual, painel.aba(), painel.obra_em_foco])
	_conferir(_obra_do_cursor() == obra, "%s: o cursor do J está em '%s', e a missão pede '%s'" % [qual, _obra_do_cursor(), obra])
	await _fechar_o_painel()
	if primeiro:
		# Longe do sítio, o J abre no diário, como sempre — mesmo com o passo pedindo.
		var longe: Vector3 = _ponto_livre(ancora, 40.0, float(sitio["angulo"]) + 90.0, false)
		_conferir(longe.is_finite(), "%s: não achei chão livre a 40 passos do sítio, para o J longe" % qual)
		if longe.is_finite():
			_pr_o_jogador(longe, 0.0)
			await _passos_de_fisica(8)
			await _quadros(2)
			_apertar(KEY_J)
			await _quadros(3)
			_conferir(painel.aberto and painel.aba() == painel.Aba.MISSOES,
				"%s: o J longe do sítio abriu na aba %d, e devia abrir no diário" % [qual, painel.aba()])
			await _fechar_o_painel()
		_pr_o_jogador(ponto, rumo)
		await _passos_de_fisica(10)
		await _quadros(2)

	# --- 6. VIRADO PARA O MORADOR, O MORADOR (só no poço, onde a roda de gente é maior) ---
	# Quem ajuda sai de perto: o Cosme tem fila para abrir no E, e na escolha do
	# morador (`tecla_dos_moradores.escolher_entre`) quem abre uma fila passa na frente
	# de quem só conversa — o Pedro. Aqui a pergunta é do foco: o Pedro sozinho a um
	# passo, o jogador virado para ele e o sítio de lado.
	if primeiro:
		_afastar_ajudantes(passo)
		pedro.global_position = lado + Vector3.UP * 0.1
		_pr_o_jogador(ponto, _rumo(ponto, pedro.global_position))
		await _quadros(3)
		pedro.global_position = lado + Vector3.UP * 0.1
		_afastar_ajudantes(passo)
		await _quadros(3)
		_conferir(moradores._ao_alcance() == pedro,
			"%s: o Pedro devia ser o único morador ao alcance, e é '%s'" % [qual, _nome(moradores._ao_alcance())])
		_conferir(foco.dono() == moradores,
			"%s: virado para o Pedro, a um passo, o E é de '%s', e devia ser dele — o viés do sítio zera a distância, não o rumo (contas: %s)" % [qual, _nome(foco.dono()), _contas()])
		_pr_o_jogador(ponto, rumo)
		await _passos_de_fisica(8)
		pedro.global_position = lado + Vector3.UP * 0.1
		_recolocar_ajudantes(fila, passo)
		await _quadros(3)
		_conferir(foco.dono() == bancadas, "%s: de volta para o sítio, o E não voltou a ele (é de '%s')" % [qual, _nome(foco.dono())])

	# --- 4. O E ABRE O PAINEL NA ABA DE OBRAS DAQUELE SÍTIO -----------------------------
	_apertar(KEY_E)
	await _quadros(3)
	_conferir(painel.aberto, "%s: o E no sítio não abriu o painel" % qual)
	_conferir(painel.aba() == painel.Aba.OBRAS and str(painel.obra_em_foco) == qual,
		"%s: o E abriu na aba %d com a obra em foco '%s', e devia abrir em Obras no sítio" % [qual, painel.aba(), painel.obra_em_foco])
	_conferir(_obra_do_cursor() == obra, "%s: o cursor do E está em '%s', e a missão pede '%s'" % [qual, _obra_do_cursor(), obra])
	var custo: Dictionary = obras.custo(obra)
	for item in custo:
		inventario.adicionar(str(item), int(custo[item]))
	await _quadros(2)
	_apertar(KEY_E)
	await _quadros(3)
	_conferir(obras.ja_feita(qual, obra), "%s: o E na aba de obras não fez '%s': %s" % [qual, obra, obras.impedimento(qual, obra)])
	await _fechar_o_painel()
	var fechou := await _ate(func() -> bool: return fila.missao > indice, 12.0)
	_conferir(fechou, "%s: feita a obra '%s', o passo '%s' não fechou em 12 s" % [qual, obra, sitio["passo"]])

	# --- 5. FEITA A OBRA, A DICA APAGA ------------------------------------------------------
	_pr_o_jogador(ponto, rumo)
	await _passos_de_fisica(8)
	await _quadros(3)
	_conferir(bancadas.perto() != qual and not fila.pede_obra(qual),
		"%s: feita a obra, o sítio continua respondendo ao E ('%s')" % [qual, bancadas.perto()])


# --- o resumo do HUD ----------------------------------------------------------------------

## Todo passo de obra das filas (`data/missoes_*.json`): o resumo, nos três idiomas, cabe
## no HUD e diz a tecla que faz a obra ("[E]", "(E)" ou "[J]"). O poço e a carroça, onde
## o E passou a valer, dizem o [E] e o [J].
func _resumos_dos_passos_de_obra() -> void:
	var vistos := 0
	for nome in DirAccess.get_files_at("res://data"):
		var arquivo := str(nome)
		if not (arquivo.begins_with("missoes_") and arquivo.ends_with(".json")):
			continue
		var dado = JSON.parse_string(FileAccess.get_file_as_string("res://data/" + arquivo))
		if not (dado is Dictionary):
			continue
		for bruto in (dado as Dictionary).get("passos", []):
			var passo: Dictionary = bruto
			var meta = passo.get("meta", {})
			if not (meta is Dictionary) or str((meta as Dictionary).get("tipo", "")) != "obra":
				continue
			vistos += 1
			for sufixo in ["", "_en", "_es"]:
				var resumo := str(passo.get("resumo" + sufixo, ""))
				var onde := "%s, passo '%s', resumo%s" % [arquivo, passo.get("id", "?"), sufixo]
				_conferir(resumo.contains("[E]") or resumo.contains("(E)") or resumo.contains("[J]"),
					"%s não diz a tecla que faz a obra: '%s'" % [onde, resumo])
				_conferir(resumo.length() <= LETRAS_DO_RESUMO,
					"%s tem %d letras, e o HUD aceita até %d: '%s'" % [onde, resumo.length(), LETRAS_DO_RESUMO, resumo])
				if COM_AS_DUAS_TECLAS.has(str(passo.get("id", ""))):
					_conferir(resumo.contains("[E]") and resumo.contains("[J]"),
						"%s devia dizer o [E] e o [J], porque o E toca a obra ali: '%s'" % [onde, resumo])
	_conferir(vistos >= 6, "achei só %d passo(s) de obra nas filas, e são seis" % vistos)


# --- o cenário -----------------------------------------------------------------------------

## Põe o jogador no ponto, virado para `rumo` (giro do corpo, como o foco lê).
func _pr_o_jogador(ponto: Vector3, rumo: float) -> void:
	jogador.teleportar(ponto + Vector3.UP * 0.3, rumo)


## O giro (em Y) de quem está em `de` e olha para `para`.
func _rumo(de: Vector3, para: Vector3) -> float:
	return atan2(para.x - de.x, para.z - de.z)


## Quem ajuda no mutirão, longe do sítio (trinta passos para o lado).
func _afastar_ajudantes(passo: Dictionary) -> void:
	for quem in passo.get("mutirao", {}):
		var ajudante = vale._achar_morador(str(quem))
		if ajudante != null:
			ajudante.global_position = vale.world.ground_position(ajudante.global_position + Vector3(30.0, 0.0, 30.0), 0.1)


## A roda do mutirão de volta ao lugar: quem ajuda fica onde a cadeia o chamou.
func _recolocar_ajudantes(fila, passo: Dictionary) -> void:
	var ajudantes: Dictionary = passo.get("mutirao", {})
	var i := 0
	for quem in ajudantes:
		var ajudante = vale._achar_morador(str(quem))
		var onde: Vector3 = fila._lugar_no_mutirao(passo, i, ajudantes.size())
		i += 1
		if ajudante != null and onde.is_finite():
			ajudante.global_position = onde + Vector3.UP * 0.1


## Chão livre (de terra firme e sem corpo num raio de 0,3) a `distancia` da âncora,
## começando no ângulo pedido e abrindo para os dois lados. `longe_das_lapides`:
## também a mais de AFASTADO_DAS_LAPIDES de qualquer túmulo.
func _ponto_livre(ancora: Vector3, distancia: float, graus: float, longe_das_lapides: bool) -> Vector3:
	for k in 19:
		# 0, +18, -18, +36, -36 ... graus, abrindo para os dois lados.
		var passo_do_angulo := float(int((k + 1) * 0.5)) * (18.0 if k % 2 == 1 else -18.0)
		var angulo := deg_to_rad(graus + passo_do_angulo)
		var p: Vector3 = vale.world.ground_position(ancora + Vector3(cos(angulo), 0.0, sin(angulo)) * distancia, 0.0)
		if not _livre(p):
			continue
		if longe_das_lapides and _perto_de_lapide(p):
			continue
		return p
	return Vector3.INF


## Um ponto à direita do jogador (a um passo), livre; o da esquerda se o da direita não for.
func _lado_livre(ponto: Vector3, rumo: float) -> Vector3:
	var para_o_lado := Vector3(cos(rumo), 0.0, -sin(rumo))
	for sentido in [1.0, -1.0]:
		var p: Vector3 = vale.world.ground_position(ponto + para_o_lado * 0.9 * sentido, 0.0)
		if _livre(p):
			return p
	return vale.world.ground_position(ponto + para_o_lado * 0.9, 0.0)


func _livre(p: Vector3) -> bool:
	if not vale.world.is_walkable_point(p):
		return false
	var forma := SphereShape3D.new()
	forma.radius = 0.3
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma
	consulta.transform = Transform3D(Basis(), p + Vector3(0.0, 0.75, 0.0))
	return vale.get_world_3d().direct_space_state.intersect_shape(consulta, 1).is_empty()


func _perto_de_lapide(p: Vector3) -> bool:
	for tumulo in vale.world.lapides:
		if Vector2(p.x - tumulo.x, p.z - tumulo.z).length() < AFASTADO_DAS_LAPIDES:
			return true
	return false


func _indice_do_passo(fila, id: String) -> int:
	for i in fila.passos.size():
		if str((fila.passos[i] as Dictionary).get("id", "")) == id:
			return i
	return -1


# --- o que o jogador vê --------------------------------------------------------------------------

func _nome(no) -> String:
	return str(no.name) if no is Node else "ninguém"


## A dica do E desta fonte está acesa?
func _dica_acesa(fonte) -> bool:
	var dica = fonte.get("_dica")
	return dica is Control and (dica as Control).visible


## Quantas dicas do E estão acesas entre as fontes do foco.
func _dicas_acesas() -> int:
	var acesas := 0
	for fonte in get_nodes_in_group(FocoDoE.GRUPO):
		if _dica_acesa(fonte):
			acesas += 1
	return acesas


## As contas do foco, para a mensagem de quem reprova: "fonte conta, fonte conta".
func _contas() -> String:
	var partes: Array[String] = []
	var frente: Vector3 = foco._frente()
	for fonte in get_nodes_in_group(FocoDoE.GRUPO):
		var alvo: Dictionary = fonte.alvo_do_e()
		if not alvo.is_empty():
			partes.append("%s %.2f" % [fonte.name, FocoDoE.conta_do_alvo(alvo, jogador.global_position, frente)])
	return ", ".join(partes)


## Os rótulos do sítio no arquivo, nos três idiomas: a máquina do portão pode estar em
## qualquer língua, e a dica sai na dela.
func _rotulos_do(qual: String) -> Array:
	var dados = JSON.parse_string(FileAccess.get_file_as_string("res://data/dicas_do_e_nas_obras.json"))
	var dado = dados.get(qual, {}) if dados is Dictionary else {}
	var lista: Array = []
	for chave in ["rotulo", "rotulo_en", "rotulo_es"]:
		if dado is Dictionary and str(dado.get(chave, "")) != "":
			lista.append(str(dado[chave]))
	return lista


func _rotulo_da_dica(fonte) -> String:
	var dica = fonte.get("_dica")
	if not (dica is Control):
		return ""
	var acao = (dica as Control).find_child("Acao", true, false)
	return str((acao as Label).text) if acao is Label else ""


## A obra sob o cursor da aba de obras.
func _obra_do_cursor() -> String:
	var lista: Array = obras.disponiveis(painel.obra_em_foco)
	var onde: int = painel._cursor
	return str(lista[onde]) if onde >= 0 and onde < lista.size() else ""


## Fecha o painel como o jogador fecha: o Esc, que passa pelo dono das telas (ele
## devolve o vale a andar). Com teto, e confere que o vale voltou.
func _fechar_o_painel() -> void:
	if not painel.aberto:
		return
	_apertar(KEY_ESCAPE)
	await _ate(func() -> bool: return not painel.aberto and not paused, 3.0)
	_conferir(not painel.aberto and not paused, "o Esc não fechou o painel e devolveu o vale a andar")
	await _quadros(2)


## A tecla pela janela, como o teclado: quem a recebe é decidido pelo jogo. O perfil
## do portão é novo, e as teclas estão de fábrica (E interage, J abre o painel).
func _apertar(tecla: int) -> void:
	for apertado in [true, false]:
		var evento := InputEventKey.new()
		evento.keycode = tecla
		evento.physical_keycode = tecla
		evento.pressed = apertado
		root.push_input(evento)


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("OBRAS_COM_E_OK: todo passo de obra diz a tecla no resumo do HUD, nos três idiomas e em até 60 letras; o poço, a ponte, o mirante, o cemitério e a carroça só respondem ao E com obra à mão; com o passo aberto e o Pedro ao lado, de frente para o sítio, o E é do sítio e só a dica dele acende; o J abre direto em Obras (e longe abre no diário); o E abre a aba de obras do sítio com o cursor na obra da missão, o E de novo toca a obra e o passo fecha; feita a obra a dica apaga; virado para o morador, o E é dele")
	else:
		print("obras_com_e: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


func _passos_de_fisica(n: int) -> void:
	for i in n:
		await physics_frame


## Roda quadros até `condicao` valer, com teto em SEGUNDO REAL.
func _ate(condicao: Callable, segundos: float) -> bool:
	var limite := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < limite:
		if condicao.call():
			return true
		await process_frame
	return condicao.call()


func _mundo_pronto() -> void:
	for i in 3000:
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
