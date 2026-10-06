extends SceneTree
## AS MISSÕES DO COMEÇO AO FIM, jogadas com os controles do jogador.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/missoes_do_comeco_ao_fim.gd
##     ... -- --ate=ponte          só até a fase (chegada, ponte, lombada, ... fazenda); para depurar
##     ... -- --guardar --ate=X    guarda a partida (vaga 1 do perfil) a cada passo fechado
##     ... -- --retomar            volta do último passo guardado, na fase em que parou
##
## "Faça um teste completo nas missões até o fim delas todas, teste todas elas e garanta funcionamento":
## os portões de missão até aqui TELEPORTAVAM o jogador, chamavam `Obras.executar`, `recursos.bater` e
## `tecla.usar` pela mão, punham `missao = N` e injetavam o material. Nenhum provava que o jogador CHEGA
## ao poço e que a tecla DELE o toca — e "não consegui interagir com o poço" passou por todos eles.
##
## ESTE joga UMA partida nova, sem `missao = N`, sem `registrar_evento`, sem injetar material de missão, das
## 22 filas e 85 passos, do desembarque à fazenda, e no fim confere pela memória das próprias filas que os
## 85 passaram:
##
##   - o jogador ANDA pelo controle (`tests/fixtures/jogada.gd`: teleporta só até 15 u do alvo e anda o
##     resto pela navegação do clique, e o último trecho com as setas); no tutorial e quando o Pedro
##     conduz, anda atrás dele, que para quando o jogador fica a mais de 6,5 u;
##   - a tecla vai pela janela (`push_input`), DEPOIS de perguntar ao foco quem leva o E — e reprova
##     quando ele é de outro (o Pedro ao lado do Tonho, o toco ao lado do Damião, a lápide ao lado do capim,
##     o poço); o E segurado (golpe forte, rasteira) vai por `Input.parse_input_event`;
##   - obra se abre pelo E do sítio e pelo J, e o painel confirma com o E; o painel FECHA enquanto o mutirão
##     anda (aberto, ele para o vale);
##   - a matéria-prima vem de bater nos alvos, de cortar as árvores do vale, de tirar a fibra das palmeiras
##     e, quando falta muito e há dinheiro, de comprar no balcão da Venda (J + Tab + E); as peças, da bancada;
##   - o machado, a picareta, a foice, o facão e a vara vêm do passo que os entrega; o baú da casa, pela
##     mochila (E, setas, E); comer e ler o convite, pela mochila (I, setas, F); a luta, pelo E perto do
##     caititu e a ginga na hora do bote; a pesca, pela vara na beira da água; o talento, pela teia (K).
##
## O que ainda NÃO é o caminho do jogador fica dito por `ATALHO:` no andamento e no resumo final.
## Cada fila só abre quando a anterior a destranca (`CadeiaDeMissoes.esta_trancada`). Para parar na primeira
## fase que falha, as seguintes ficam sem jogar. Pesado (50 a 100 min de relógio): só roda com `-Tudo` ou
## pelo nome (`tools/prototipo_3d/testar.ps1`).

const Jogada = preload("res://tests/fixtures/jogada.gd")
const RelogioDeJogo = preload("res://tests/fixtures/relogio_de_jogo.gd")
const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")

const SEGUNDOS_PARA_ANUNCIAR := 25.0
const SEGUNDOS_POR_PASSO := 40.0
const FASES := ["chegada", "ponte", "lombada", "zefa", "candinha", "filo", "roca", "chapada", "coveiro", "tonho",
	"saveiro", "carroca", "arraial", "fe", "oficio", "candomble", "capoeira", "armas", "caboclo", "metas", "fazenda"]

var falhas := 0
var maos
var relogio: Node
var vale
var jogador
var pedro
var inv
var energia
var dialogo
var lugares
var obras
var oficina
var cozinha
var recursos
var painel
var jogados := {}
var ate_a_fase := ""
var passos_do_vale := 0
## `--guardar`: a cada passo fechado, guarda a partida na vaga 1 (e o andamento do portão ao lado), para
## depurar um passo tardio sem rejogar os de antes. `--retomar`: volta dessa vaga, na fase em que parou,
## e a fila segue do passo em que estava. É só para quem depura: a bateria roda sem nenhum dos dois, de
## uma partida nova.
var guardar := false
var retomar := false
var fase_atual := ""
const ANDAMENTO := "user://comeco_ao_fim.json"
const PONTO := "user://comeco_ao_fim.save"


func _initialize() -> void:
	_run.call_deferred()


func _falha(texto: String) -> void:
	push_error("COMECO_AO_FIM_FALHOU: " + texto)
	print("FALHA: ", texto)
	falhas += 1


func _conferir(ok: bool, texto: String) -> void:
	if not ok:
		_falha(texto)


func _conta(texto: String) -> void:
	print(texto)
	# Também no stderr, que não fica preso no buffer: de fora se vê onde a jogada está.
	printerr("  > " + texto)


func _run() -> void:
	for argumento in OS.get_cmdline_user_args():
		if str(argumento).begins_with("--ate="):
			ate_a_fase = str(argumento).trim_prefix("--ate=")
		elif str(argumento) == "--guardar":
			guardar = true
		elif str(argumento) == "--retomar":
			retomar = true
	if guardar or retomar:
		# A vaga 1 do perfil isolado deste portão: partida nova (apagando a de antes) ou a guardada no
		# último passo (a cópia dela, porque o jogo salva sozinho e estragaria o ponto).
		if retomar:
			_restaurar_o_ponto()
		root.get_node("/root/Partida").comecar(1, not retomar)
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await process_frame
	for i in range(3000):
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	for i in range(8):
		await process_frame
	vale = current_scene
	relogio = RelogioDeJogo.new()
	root.add_child(relogio)
	relogio.ficar_lento()
	maos = Jogada.new(self, vale, relogio, func(t: String) -> void: _falha(t), func(t: String) -> void: _conta(t))
	jogador = vale.player
	pedro = vale.pedro
	inv = root.get_node("/root/Inventario")
	energia = root.get_node("/root/Energia")
	dialogo = root.get_node("/root/Dialogo")
	lugares = root.get_node("/root/Lugares")
	obras = root.get_node("/root/Obras")
	oficina = root.get_node("/root/Oficina")
	cozinha = root.get_node("/root/Cozinha")
	recursos = vale.get_node("Recursos3D")
	painel = vale.painel
	# O relógio do dia parado de manhã: os moradores ficam nos postos da manhã, onde as filas os esperam.
	root.get_node("/root/Dia").pausado = true
	var pulando := retomar and _ler_o_andamento() != ""
	for fase in FASES:
		if pulando and str(fase) != fase_atual:
			continue
		pulando = false
		fase_atual = str(fase)
		print("")
		print("######## FASE %s" % fase)
		var falhas_antes := falhas
		await call("_fase_" + str(fase))
		if falhas > falhas_antes:
			# As filas seguintes dependem desta: jogá-las sem ela só empilha falha que não é delas.
			print("")
			print("a fase '%s' falhou: as seguintes ficam sem jogar" % fase)
			break
		if ate_a_fase == str(fase):
			break
	_fechar()


func _guardar_o_andamento() -> void:
	var partida := root.get_node("/root/Partida")
	partida.salvar()
	var salvamento := root.get_node("/root/Salvamento")
	DirAccess.copy_absolute(_globo(salvamento.arquivo(1)), _globo(PONTO))
	var arquivo := FileAccess.open(ANDAMENTO, FileAccess.WRITE)
	arquivo.store_string(JSON.stringify({"fase": fase_atual, "jogados": jogados.keys(), "passos": passos_do_vale, "atalhos": maos.atalhos}))
	arquivo.close()


func _globo(caminho: String) -> String:
	return ProjectSettings.globalize_path(caminho)


## A cópia do ponto guardado volta a ser a vaga 1, antes de o vale subir.
func _restaurar_o_ponto() -> void:
	if not FileAccess.file_exists(PONTO):
		_falha("--retomar pede uma partida guardada (rode antes com --guardar), e não há")
		return
	var salvamento := root.get_node("/root/Salvamento")
	DirAccess.copy_absolute(_globo(PONTO), _globo(salvamento.arquivo(1)))


## O andamento do portão, do último passo guardado: devolve a fase em que parou ("" sem nada guardado).
func _ler_o_andamento() -> String:
	if not FileAccess.file_exists(ANDAMENTO):
		return ""
	var lido = JSON.parse_string(FileAccess.get_file_as_string(ANDAMENTO))
	if not lido is Dictionary:
		return ""
	for id in (lido as Dictionary).get("jogados", []):
		jogados[str(id)] = true
	passos_do_vale = int((lido as Dictionary).get("passos", 0))
	for a in (lido as Dictionary).get("atalhos", []):
		maos.atalhos.append(str(a))
	fase_atual = str((lido as Dictionary).get("fase", ""))
	print("  [retomando na fase '%s', com %d passos já jogados]" % [fase_atual, passos_do_vale])
	return fase_atual


# --- as fases ---------------------------------------------------------------------------------

func _fase_chegada() -> void:
	# O TUTORIAL: o Pedro conduz, e o jogador anda tudo (o Pedro não se perde de vista).
	maos.teleporte = false
	var guia = pedro._cadeia
	await _jogar_cadeia(guia, "a chegada (o tutorial do Pedro)")
	maos.teleporte = true
	# A despedida dita: o tutorial acaba, e as filas depois dele destrancam.
	await maos.esperar(func() -> bool: return pedro.terminou_o_tutorial(), 40.0)
	_conferir(pedro.terminou_o_tutorial(), "a chegada acabou os passos e o Pedro não terminou o tutorial (despedida não dita)")


## Joga a fila pendurada em `vale._cadeias[chave]`.
func _fila(chave: String, nome: String) -> bool:
	var cadeia = vale._cadeias.get(chave)
	if cadeia == null:
		_falha("o vale não pendurou a fila '%s'" % chave)
		return false
	return await _jogar_cadeia(cadeia, nome)


func _fase_ponte() -> void:
	await _fila("pedro_ponte", "a ponte do rio grande")


func _fase_lombada() -> void:
	await _fila("pedro_lombada", "a lombada do alto")


func _fase_zefa() -> void:
	await _fila("zefa", "a Dona Zefa")


func _fase_candinha() -> void:
	await _fila("candinha", "a Dona Candinha")


func _fase_filo() -> void:
	await _fila("filo", "a Dona Filó")


func _fase_roca() -> void:
	await _fila("cosme_roca", "a roça do finado")


func _fase_chapada() -> void:
	await _fila("pedro_chapada", "a chapada do Seu Benedito")


func _fase_coveiro() -> void:
	await _fila("damiao", "o cemitério esquecido")


func _fase_tonho() -> void:
	await _fila("tonho", "as redes do Tonho")


func _fase_saveiro() -> void:
	await _fila("benedito_saveiro", "o saveiro da estação")


func _fase_carroca() -> void:
	await _fila("benedito_carroca", "a carroça do avô")


func _fase_arraial() -> void:
	await _fila("pedro_arraial", "o mirante do arraial")


func _fase_fe() -> void:
	# A fé do arraial: a Dona Zefa, os três lugares, a escolha no marco (a católica, no cruzeiro) e o fim.
	await _fila("pedro_fe", "a fé do arraial")
	await _fila("fe_catolica", "a romaria")


func _fase_candomble() -> void:
	# Trocar para o candomblé no terreiro, e a mesa da folha (a capoeira espera por ela).
	if not await _no_marco("terreiro", "troca para o candomblé"):
		return
	await _fila("fe_candomble", "a mesa da folha")


func _fase_caboclo() -> void:
	if not await _no_marco("gameleira", "troca para o caboclo"):
		return
	await _fila("fe_caboclo", "pagar o monte")


func _fase_capoeira() -> void:
	# Candomblé outra vez (a capoeira é a teia dele), e a lição do Cosme.
	if root.get_node("/root/Fe").ativa != "candomble":
		if not await _no_marco("terreiro", "volta ao candomblé"):
			return
	await _fila("cosme_capoeira", "a capoeira do Cosme")


func _fase_oficio() -> void:
	await _fila("pedro_oficio", "o ofício do Pedro")


func _fase_armas() -> void:
	await _fila("pedro_armas", "as armas do Pedro")


func _fase_metas() -> void:
	# Dez caititus derrubados abrem a meta do gibão.
	var luta := root.get_node("/root/Luta")
	await _lutar("meta dos caititus", func() -> bool: return int(luta.abates.get("caititu", 0)) >= 10, "facao")
	await _fila("pedro_metas", "a meta dos caititus")


func _fase_fazenda() -> void:
	# A fazenda do convite: com a ponte de pé e a fé escolhida, na manhã seguinte o Pedro vem à porta.
	var da_fazenda = vale._cadeias.get("pedro_fazenda")
	if da_fazenda == null:
		_falha("o vale não pendurou a fila da fazenda")
		return
	if not da_fazenda.iniciado:
		await _dormir("fazenda")
		await maos.esperar(func() -> bool: return da_fazenda.iniciado, 40.0)
	await _jogar_cadeia(da_fazenda, "a fazenda do convite")


## O E no marco da fé e as respostas "sim" que ele pergunta (entrar, trocar, levar os pontos). Como no
## jogo: anda até o marco, o foco dá o E a ele, o jogador aperta e responde.
func _no_marco(marco: String, porque: String) -> bool:
	var marcos = vale.marcos
	var onde: Vector3 = marcos.ponto(marco)
	if not await maos.ir_ate(onde, 1.6, true, 60.0, 3.0):
		return false
	await maos.quadros(3)
	var dono = maos.dono_do_e()
	if dono != marcos:
		_falha("%s: ao lado do marco '%s' o E é de %s, e não do marco. Concorrem: %s" % [porque, marco, maos.nome_de(dono), maos.explicar_o_foco()])
		return false
	await maos.apertar(KEY_E)
	var limite: float = relogio.agora() + 60.0
	while marcos.ocupado() and relogio.agora() < limite:
		if dialogo.ativo:
			if dialogo._modo == dialogo.Modo.PERGUNTA:
				dialogo._escolha = true
				dialogo._escolheu = true
			dialogo._fechar()
		await maos.quadros(1)
	if marcos.ocupado():
		_falha("%s: o marco '%s' não terminou de responder em 60 s de jogo" % [porque, marco])
		return false
	await maos.quadros(2)
	return true


# --- uma fila inteira ---------------------------------------------------------------------------

## Joga a fila `cadeia` do primeiro ao último passo. Devolve se chegou ao fim.
func _jogar_cadeia(cadeia, nome: String) -> bool:
	print("== %s (aberta=%s, no passo %d de %d)" % [nome, str(cadeia.iniciado), cadeia.missao + 1, cadeia.passos.size()])
	if not cadeia.iniciado:
		if cadeia == pedro._cadeia:
			# O tutorial abre sozinho quando o jogador chega perto do Pedro (a saudação).
			var onde_esta_o_pedro: Vector3 = pedro.global_position
			if not await maos.ir_ate(onde_esta_o_pedro, 3.5):
				return false
			await maos.esperar(func() -> bool: return cadeia.iniciado, 20.0)
		elif cadeia.comeca_perto_de > 0.0:
			if cadeia.esta_trancada():
				_falha("a fila '%s' devia estar aberta aqui e está trancada: '%s'" % [nome, cadeia.dica_da_trancada()])
				return false
			# O Pedro tem várias filas à espera (a ponte, as armas, o ofício, a lombada...): cada E abre a
			# primeira que cabe, na ordem dos nós, e o jogador aperta de novo até abrir a que quer.
			for vez in range(6):
				if not await maos.e_no_morador(cadeia.dono, "abrir a fila '%s' (E no dono, vez %d)" % [nome, vez + 1]):
					return false
				if await maos.esperar(func() -> bool: return cadeia.iniciado, 6.0):
					break
		else:
			await maos.esperar(func() -> bool: return cadeia.iniciado, 8.0)
	if not cadeia.iniciado:
		_falha("a fila '%s' não abriu" % nome)
		return false
	var voltas := 0
	while not cadeia.acabou() and voltas < cadeia.passos.size() + 4:
		voltas += 1
		var indice: int = cadeia.missao
		var passo: Dictionary = cadeia.passo_atual()
		var id := str(passo.get("id", "?"))
		var anunciou: bool = await maos.esperar(func() -> bool: return cadeia.espera <= 0.0, SEGUNDOS_PARA_ANUNCIAR)
		if not anunciou:
			_falha("o passo '%s' não anunciou em %.0f s de jogo (espera %.2f)" % [id, SEGUNDOS_PARA_ANUNCIAR, cadeia.espera])
			return false
		var inicio: float = relogio.jogo_s
		await _jogar_passo(cadeia, passo, indice)
		var fechou: bool = await maos.esperar(func() -> bool: return cadeia.missao != indice, SEGUNDOS_POR_PASSO)
		if not fechou:
			_falha("o passo '%s' (%d de %d, %s) não fechou em %.0f s de jogo depois de jogado. jogador em %s, a %.1f u do lugar (raio %s), meta %s. Mochila: %s. A fila: espera=%.2f, anda=%s, dono=%s (anda=%s, visível=%s, em %s)"
				% [id, indice + 1, cadeia.passos.size(), nome, SEGUNDOS_POR_PASSO, str(jogador.global_position),
					jogador.global_position.distance_to(cadeia.posicao_do_passo(indice)), str(passo.get("raio", "?")), str(passo.get("meta", {})), _mochila_em_texto(),
					float(cadeia.espera), str(cadeia.can_process()), maos.nome_de(cadeia.dono), str(cadeia.dono.can_process()), str(cadeia.dono.visible), str(cadeia.dono.global_position)])
			return false
		jogados[id] = true
		passos_do_vale += 1
		_conta("  %-24s fechou (%.0f s de jogo)" % [id, relogio.jogo_s - inicio])
		if guardar:
			_guardar_o_andamento()
	if not cadeia.acabou():
		_falha("a fila '%s' parou no passo %d de %d" % [nome, cadeia.missao + 1, cadeia.passos.size()])
		return false
	return true


## Em que o corpo `quem` bateu no último passo de física: o nome e o ponto de cada corpo.
func _bateu_em(quem: CharacterBody3D) -> String:
	var lista: PackedStringArray = []
	for i in range(quem.get_slide_collision_count()):
		var colisao := quem.get_slide_collision(i)
		var corpo = colisao.get_collider()
		lista.append("%s@%s normal %s" % [str((corpo as Node).name) if corpo is Node else str(corpo), str((corpo as Node3D).global_position) if corpo is Node3D else "?", str(colisao.get_normal())])
	return ", ".join(lista) if not lista.is_empty() else "nada"


## A mochila em uma linha ("lenha 3, pedra 1"), para o relatório de quem não fechou.
func _mochila_em_texto() -> String:
	var itens := {}
	for i in inv.ESPACOS:
		var espaco: Dictionary = inv.espacos[i]
		if not espaco.is_empty():
			itens[str(espaco["id"])] = int(itens.get(str(espaco["id"]), 0)) + int(espaco.get("qtd", 1))
	var partes: PackedStringArray = []
	for id in itens:
		partes.append("%s %d" % [id, itens[id]])
	return "%s; %d réis" % [", ".join(partes), int(root.get_node("/root/Jogo").dinheiro)]


## O que o jogador faz neste passo, pelo caminho do jogo.
func _jogar_passo(cadeia, passo: Dictionary, indice: int) -> void:
	var meta: Dictionary = passo.get("meta", {})
	var tipo := str(meta.get("tipo", ""))
	var id := str(passo.get("id", ""))
	energia.encher()
	_alvos_que_nao_deram.clear()
	# O PEDRO CONDUZ: o jogador anda atrás dele até onde ele para; e só então faz o que o passo pede.
	if bool(passo.get("conduz", false)):
		await _seguir_o_pedro(cadeia, indice, id)
	match tipo:
		"":
			var raio := float(passo.get("raio", 8.0))
			await maos.ir_ate(cadeia.posicao_do_passo(indice), 0.0, false, 60.0, clampf(raio * 0.6, 1.0, 8.0))
		"falar", "levar":
			var quem = vale._achar_morador(str(meta.get("a_quem", "")))
			if quem == null:
				_falha("o passo '%s' procura '%s', que não está no vale" % [id, meta.get("a_quem", "")])
				return
			if tipo == "levar":
				await _ter_a_carga(cadeia, meta, id)
			if str(meta.get("a_quem", "")) == "quirino":
				await _chamar_o_saveiro(id)
			await maos.e_no_morador(quem, "passo '%s'" % id)
		"juntar":
			await _pegar_do_bau(_carga(meta), id)
			await _ter_a_carga(cadeia, meta, id, passo)
		"visitar":
			var raio_da_visita := float(meta.get("raio", 6.0))
			for nome in cadeia._lugares_da_meta(meta):
				var ponto_da_visita: Vector3 = lugares.ponto(str(nome))
				# O CERCADO DO CEMITÉRIO só se cruza pela entrada (a malha do clique não conhece a cerca: o
				# corpo bate nela): quem vai ao cemitério dá a volta até a entrada e entra por ela.
				if str(nome) == "cemiterio":
					await _entrar_pelo_cercado(ponto_da_visita)
				await maos.ir_ate(ponto_da_visita, 0.0, false, 60.0, maxf(raio_da_visita - 1.0, 1.0))
				await maos.passar(0.8)
		"derrubar":
			await _derrubar(str(meta.get("alvo", "")), int(meta.get("quantos", 1)), id)
		"oferendar":
			await _ter_a_carga(cadeia, meta, id)
			var onde_oferecer := str(meta.get("lugar", passo.get("lugar", "")))
			await maos.ir_ate(lugares.ponto(onde_oferecer), 0.0, false, 60.0, clampf(float(meta.get("raio", 4.0)) * 0.5, 1.0, 3.0))
		"contar":
			await _contar(cadeia, passo, id)
		"obra":
			# O MATERIAL DA OBRA que o jogador põe (o mutirão do passo traz o resto: o Cosme e o Tonho chegam ao
			# sítio com a parte deles): se o passo anterior não o fez juntar, junta aqui.
			var da_obra: Dictionary = obras.custo(str(meta.get("obra", ""))).duplicate()
			var do_mutirao: Dictionary = passo.get("mutirao", {})
			for quem_traz in do_mutirao:
				var traz: Dictionary = do_mutirao[quem_traz]
				for item in traz:
					da_obra[item] = maxi(int(da_obra.get(item, 0)) - int(traz[item]), 0)
			var minha_parte := {}
			for item in da_obra:
				if int(da_obra[item]) > 0:
					minha_parte[str(item)] = int(da_obra[item])
			if not minha_parte.is_empty():
				await _ter_a_carga(cadeia, {"itens": minha_parte}, id)
			await _fazer_a_obra(str(meta.get("construcao", "")), str(meta.get("obra", "")), id)
		"evento":
			for evento in _eventos(meta):
				await _acontecer(str(evento), id, func() -> bool: return cadeia.missao != indice)
		_:
			_falha("o passo '%s' tem meta '%s', que este portão ainda não joga" % [id, tipo])


## O PEDRO VAI NA FRENTE (`guia_pedro._conduzir`): anda a 2,1 u/s pela malha até o destino do passo e PARA
## quando o jogador fica a mais de 6,5 u, só voltando com ele a 4,0 u. Quem anda sozinho pelo caminho mais
## curto o deixa para trás, parado no píer — foi o que este portão fez na primeira versão. O jogador faz o
## que se faz: vai atrás dele, a uma distância de conversa, até ele chegar.
func _seguir_o_pedro(cadeia, indice: int, id: String) -> void:
	var inicio: float = relogio.jogo_s
	var ultima_ordem: float = relogio.jogo_s
	var teto := 600.0
	while relogio.jogo_s - inicio < teto and cadeia.missao == indice:
		var falta: Vector3 = pedro._destino_da_conducao(cadeia) - pedro.global_position
		falta.y = 0.0
		if falta.length() <= pedro.CONDUZ_ATE + 0.5:
			break
		var longe: float = Vector2(jogador.global_position.x - pedro.global_position.x, jogador.global_position.z - pedro.global_position.z).length()
		# SEGUIR NÃO REPROVA A CADA CLIQUE QUE NÃO CHEGA: o guia anda e para, e o ponto de agora pode não ter caminho
		# (o portão da fazenda, a beira do píer). O que reprova é o guia não chegar ao destino em `teto` (adiante).
		maos.calado = true
		if longe > 14.0:
			# Longe: o clique, até perto dele (o ponto de pisar ao lado, e não o corpo dele).
			maos.calado = true
			await maos.ir_ate(pedro.global_position, 2.0, false, 30.0, 3.0)
			maos.calado = false
		elif longe > float(pedro.VOLTA_A_ANDAR) - 0.8:
			# Perto: as setas, de frente para ele, até a uma distância de conversa — sem encostar (quem encosta o
			# faz dar passagem, e ele não anda). Ele só espera quando passa de 6,5 u. Se as setas não aproximam
			# (a beira do píer, a cerca, entre os dois), o clique dá a volta pela malha, parando longe dele.
			await maos.guiar_ate(pedro.global_position, 2.4, 2.0)
			var depois: float = Vector2(jogador.global_position.x - pedro.global_position.x, jogador.global_position.z - pedro.global_position.z).length()
			if depois > longe - 0.5 and depois > float(pedro.VOLTA_A_ANDAR) - 0.8:
				maos.calado = true
				await maos.ir_ate(pedro.global_position, 2.4, false, 30.0, 3.0)
				maos.calado = false
		else:
			await maos.quadros(2)
		maos.calado = false
		if relogio.jogo_s - ultima_ordem > 30.0:
			ultima_ordem = relogio.jogo_s
			_conta("    ... seguindo o Pedro (passo '%s'): ele em %s, o jogador em %s, o destino em %s; ele espera quem ficou=%s, malha=%s, caminho de %d pontos, velocidade %.1f, preso %.1f" % [
				id, str(pedro.global_position), str(jogador.global_position), str(pedro._destino_da_conducao(cadeia)),
				str(pedro._esperando_quem_ficou), str(pedro._esperando_a_malha), pedro._caminho.size(), (pedro.velocity as Vector3).length(), float(pedro._preso)]
				+ "; no chão=%s; bateu em: %s" % [str(pedro.is_on_floor()), _bateu_em(pedro)])
	await maos.quadros(2)
	if cadeia.missao == indice and relogio.jogo_s - inicio >= teto:
		_falha("o passo '%s': o Pedro não chegou ao destino em %.0f s de jogo, conduzindo (ele em %s, destino %s, jogador em %s)" % [
			id, teto, str(pedro.global_position), str(pedro._destino_da_conducao(cadeia)), str(jogador.global_position)])


func _eventos(meta: Dictionary) -> Array:
	var lista: Array = meta.get("eventos", [])
	return lista if not lista.is_empty() else [str(meta.get("evento", ""))]


## O que a meta pede, pela conta do próprio motor das filas (`item`/`quantos`, `itens`, `da_obra`).
func _carga(meta: Dictionary) -> Dictionary:
	return pedro._cadeia._carga_da_meta(meta)


# --- material --------------------------------------------------------------------------------

## O que falta na mochila para a meta do passo, ou, sem passo, para `carga` na mochila.
func _falta_a_carga(cadeia, meta: Dictionary, passo: Dictionary) -> bool:
	if not passo.is_empty():
		return cadeia.falta_a_meta(passo)
	var carga := _carga(meta)
	for item in carga:
		if inv.quantidade(str(item)) < int(carga[item]):
			return true
	return false


## Faz o jogador ter o que a meta pede: a matéria-prima, batendo no alvo; as peças, na bancada.
func _ter_a_carga(cadeia, meta: Dictionary, id: String, passo: Dictionary = {}) -> void:
	var carga := _carga(meta)
	var voltas := 0
	while _falta_a_carga(cadeia, meta, passo) and voltas < 12:
		voltas += 1
		# O QUE FALTA DE MATÉRIA-PRIMA, a mais do que a mochila tem: o que falta dos itens que se juntam
		# (`cru`), e o custo das peças que a bancada faz e ainda faltam (`custo_das_pecas`), do qual a
		# mochila só abate o que não conta para a meta (a lenha que é também meta não serve de dois).
		var cru := {}
		var custo_das_pecas := {}
		for item in carga:
			var tem: int = int(cadeia._tem_para_a_meta(meta, str(item))) if not passo.is_empty() else int(inv.quantidade(str(item)))
			var falta: int = int(carga[item]) - tem
			if falta <= 0:
				continue
			if oficina.dados(str(item)).is_empty():
				cru[str(item)] = int(cru.get(str(item), 0)) + falta
			else:
				_somar_o_cru(custo_das_pecas, str(item), falta)
		for material in custo_das_pecas:
			var reserva: int = 0 if carga.has(material) else int(inv.quantidade(str(material)))
			var adicional: int = int(custo_das_pecas[material]) - reserva
			if adicional > 0:
				cru[str(material)] = int(cru.get(str(material), 0)) + adicional
		for material in cru:
			await _colher(str(material), int(inv.quantidade(str(material))) + int(cru[material]), id)
		for item in carga:
			if not oficina.dados(str(item)).is_empty():
				var tem2: int = int(cadeia._tem_para_a_meta(meta, str(item))) if not passo.is_empty() else int(inv.quantidade(str(item)))
				if tem2 < int(carga[item]):
					await _fabricar(str(item), int(carga[item]) - tem2, id)
		# `equivale` (a lenha da ponte): a lenha que sobrar por falta, colhe mais um tanto.
		if _falta_a_carga(cadeia, meta, passo) and meta.has("equivale") and cru.is_empty():
			await _colher(str(meta.get("item", "lenha")), inv.quantidade(str(meta.get("item", "lenha"))) + 8, id)
		if cru.is_empty() and custo_das_pecas.is_empty():
			break


## A matéria-prima (não fabricável) de `quantos` de `item`, somada em `cru`.
func _somar_o_cru(cru: Dictionary, item: String, quantos: int) -> void:
	var receita: Dictionary = oficina.dados(item)
	if receita.is_empty():
		cru[item] = int(cru.get(item, 0)) + quantos
		return
	var vezes := ceili(float(quantos) / float(oficina.rende(item)))
	var custo: Dictionary = receita.get("custo", {})
	for material in custo:
		_somar_o_cru(cru, str(material), int(custo[material]) * vezes)


## Alvos que o jogador já tentou e não alcançou (o barranco, o canto entre a casa e a cerca): ele escolhe
## outro, como quem desiste de uma árvore que não chega.
var _alvos_que_nao_deram := {}


## Os alvos de trabalho que `servem` (ficha -> bool), os que o jogador bate com o que tem primeiro e, em cada
## grupo, do mais perto ao mais longe. [{id, pos}]
func _alvos_que(serve: Callable) -> Array:
	var lista: Array = []
	for qual in recursos._alvos:
		if _alvos_que_nao_deram.has(str(qual)):
			continue
		var ficha: Dictionary = recursos._alvos[qual]["ficha"]
		if not bool(serve.call(ficha)):
			continue
		var ferramenta := str(ficha.get("ferramenta", ""))
		var pos: Vector3 = recursos._alvos[qual]["pos"]
		var longe: float = Vector2(pos.x - jogador.global_position.x, pos.z - jogador.global_position.z).length()
		var pesa: float = longe + (0.0 if ferramenta == "" or _tem_a_ferramenta(ferramenta) else 100000.0)
		lista.append({"fonte": "recurso", "id": str(qual), "pos": pos, "pesa": pesa})
	lista.sort_custom(func(a, b) -> bool: return float(a["pesa"]) < float(b["pesa"]))
	return lista


## As árvores do vale (`ArvoresInfo`) que o jogador corta com o que tem e que rendem `item`, até `ate_longe`
## unidades dele: as que ele pode cortar (`_recusa` vazia: o talento e o aço da madeira) e, entre elas, as
## mais perto. [{fonte, id, indice, pos, pesa}]
func _arvores_que_rendem(item: String, ate_longe: float = 160.0) -> Array:
	var lista: Array = []
	var arvores = vale._arvores_info
	if item == "piacava":
		# A piaçaba: as piaçabeiras de pé com fibra pronta, que o facão (ou a foice) tira.
		var tem_o_fio := _tem_a_ferramenta("facao") or _tem_a_ferramenta("foice")
		for i in arvores._cortaveis.size():
			var palmeira: Dictionary = arvores._cortaveis[i]
			if str(palmeira["especie"]) != str(arvores.PALMEIRA_DA_FIBRA) or bool(palmeira.get("cortado", false)) 					or not arvores.fibra_pronta(i) or _alvos_que_nao_deram.has("palmeira:%d" % i):
				continue
			var onde: Vector3 = palmeira["pos"]
			var distancia: float = Vector2(onde.x - jogador.global_position.x, onde.z - jogador.global_position.z).length()
			if distancia <= ate_longe:
				lista.append({"fonte": "palmeira", "id": "palmeira:%d" % i, "indice": i, "pos": onde,
					"pesa": distancia + (0.0 if tem_o_fio else 100000.0)})
		lista.sort_custom(func(a, b) -> bool: return float(a["pesa"]) < float(b["pesa"]))
		return lista
	var tem_o_machado := _tem_a_ferramenta("machado")
	for i in arvores._cortaveis.size():
		var arvore: Dictionary = arvores._cortaveis[i]
		if bool(arvore.get("cortado", false)) or _alvos_que_nao_deram.has("arvore:%d" % i):
			continue
		var pos: Vector3 = arvore["pos"]
		var longe: float = Vector2(pos.x - jogador.global_position.x, pos.z - jogador.global_position.z).length()
		if longe > ate_longe:
			continue
		var madeira: Dictionary = arvores.madeira_de(str(arvore["especie"]))
		if str(madeira.get("rende", "lenha")) != item:
			continue
		if tem_o_machado and str(arvores._recusa(i)) != "":
			continue
		lista.append({"fonte": "arvore", "id": "arvore:%d" % i, "indice": i, "pos": pos,
			"pesa": longe - 1.5 * float(madeira.get("quantidade", 1)) + (0.0 if tem_o_machado else 100000.0)})
	lista.sort_custom(func(a, b) -> bool: return float(a["pesa"]) < float(b["pesa"]))
	return lista


## Os candidatos a render `item`: alvos de trabalho e, para a lenha, as árvores — do mais fácil ao mais difícil.
func _candidatos_de(item: String) -> Array:
	var lista := _alvos_que(func(ficha: Dictionary) -> bool: return str(ficha.get("rende", "")) == item)
	if item == "lenha" or item == "piacava":
		lista.append_array(_arvores_que_rendem(item))
	lista.sort_custom(func(a, b) -> bool: return float(a["pesa"]) < float(b["pesa"]))
	return lista


func _tem_a_ferramenta(familia: String) -> bool:
	for i in inv.ESPACOS:
		var item := str((inv.espacos[i] as Dictionary).get("id", ""))
		if item != "" and Catalogo.familia(item) == familia:
			return true
	return false


## Bate nos alvos de trabalho até a mochila ter `ate` de `item`.
func _colher(item: String, ate: int, id: String) -> bool:
	var voltas := 0
	while inv.quantidade(item) < ate and voltas < 140:
		voltas += 1
		# FALTA MUITO e o balcão vende: quem tem o dinheiro compra o grosso, que é o que se faz com 30 paus
		# (a venda de lenha é o "pior caso" que o relatório das missões conta para cada material).
		var falta: int = ate - int(inv.quantidade(item))
		_conta("    ... %s: %d de %d (jogo a %.0f s)" % [item, int(inv.quantidade(item)), ate, relogio.jogo_s])
		var venda = root.get_node("/root/Venda")
		if falta >= 10 and venda.MERCADORIAS.has(item):
			# O que o dinheiro paga, com a folga: o resto, o jogador junta.
			var posso: int = mini(falta, (int(root.get_node("/root/Jogo").dinheiro) - 120) / maxi(int(venda.preco_de_compra(item)), 1))
			if posso >= 5 and await _comprar(item, posso, id):
				continue
		var candidatos := _candidatos_de(item)
		if candidatos.is_empty() and item == "peixe" and _tem_a_ferramenta("vara_de_pescar"):
			# PEIXE não se bate: pesca-se, com a vara que o Pedro deu, na beira do píer.
			await _pescar(func() -> bool: return inv.quantidade(item) >= ate, id)
			if inv.quantidade(item) >= ate:
				continue
		if candidatos.is_empty():
			# SEM MAIS ALVO NO VALE, o que o dinheiro paga, sem folga: o relatório das missões conta a compra como
			# o pior caso de cada material.
			var paga: int = 0
			if venda.MERCADORIAS.has(item):
				paga = mini(falta, int(root.get_node("/root/Jogo").dinheiro) / maxi(int(venda.preco_de_compra(item)), 1))
			if paga >= 1 and await _comprar(item, paga, id):
				continue
			_falha("passo '%s': o vale não tem (mais) alvo alcançável que renda '%s' (faltam %d), e o balcão não resolveu (tinha %d réis, a unidade custa %d)" % [
				id, item, falta, root.get_node("/root/Jogo").dinheiro, int(venda.preco_de_compra(item))])
			return false
		var alvo: Dictionary = candidatos[0]
		var tinha: int = inv.quantidade(item)
		if not await _bater_no_alvo(alvo, id, func() -> bool: return inv.quantidade(item) >= ate):
			continue
		# BATEU E NÃO RENDEU (a pedra dura que pede picareta de aço, a árvore que cai para a ferramenta que o
		# jogador não tem): esse alvo fica de lado, e o jogador procura outro.
		if inv.quantidade(item) <= tinha:
			_alvos_que_nao_deram[str(alvo["id"])] = true
			_conta("    ... o alvo '%s' não rendeu '%s' (bateu e a mochila não cresceu)" % [str(alvo["id"]), item])
	return inv.quantidade(item) >= ate


## Bate nos alvos da peça (ou do grupo) `peca` até `quantos` terem caído: o capim da foice, o mato do
## cemitério, a lapa da picareta.
func _derrubar(peca: String, quantos: int, id: String) -> bool:
	var voltas := 0
	while recursos.derrubados(peca) < quantos and voltas < 80:
		voltas += 1
		var candidatos := _alvos_que(func(ficha: Dictionary) -> bool: return str(ficha.get("peca", "")) == peca or (peca != "" and str(ficha.get("grupo", "")) == peca))
		if candidatos.is_empty():
			_falha("passo '%s': não resta alvo '%s' de pé alcançável (caíram %d de %d)" % [id, peca, recursos.derrubados(peca), quantos])
			return false
		if not await _bater_no_alvo(candidatos[0], id, func() -> bool: return recursos.derrubados(peca) >= quantos):
			continue
	return recursos.derrubados(peca) >= quantos


## Anda até o alvo de trabalho `candidato` ({id, pos}) e bate nele com o E, como o jogador: a dica acende, o E
## é do alvo, a ferramenta certa está na mão. Para quando `basta` diz que chega ou quando o alvo cai. Devolve
## false quando não deu (o alvo vai para os que não deram, e quem chama escolhe outro).
func _bater_no_alvo(candidato: Dictionary, id: String, basta: Callable) -> bool:
	energia.encher()
	if str(candidato.get("fonte", "recurso")) == "arvore":
		return await _cortar_a_arvore(candidato, id, basta)
	if str(candidato.get("fonte", "recurso")) == "palmeira":
		return await _tirar_a_fibra(candidato, id)
	var meu: String = str(candidato["id"])
	var alvo: Vector3 = candidato["pos"]
	await _entrar_pelo_cercado(alvo)
	maos.calado = true
	var chegou: bool = await maos.ir_ate(alvo, 1.5, true, 60.0, 4.0)
	maos.calado = false
	if not chegou:
		_alvos_que_nao_deram[meu] = true
		_conta("    ... o alvo '%s' (%s) não deu: %s" % [meu, str(alvo), maos.ultimo_motivo])
		return false
	await maos.quadros(2)
	# O ALVO AO ALCANCE É O MAIS PERTO (`Recursos3D._mais_perto`): ao lado do capim o tronco perde a dica.
	# Quem joga lê a dica ("Capim · falta a foice") e chega mais perto do que quer bater.
	for tentativa in range(2):
		if str(recursos.get("_perto")) == meu:
			break
		await maos.guiar_ate(alvo, 0.6, 5.0)
		maos.virar_para(alvo)
		await maos.quadros(2)
	var qual := str(recursos.get("_perto"))
	if qual != meu:
		_alvos_que_nao_deram[meu] = true
		_conta("    ... o alvo '%s' (%s) não deu: parado ao lado dele o alcance é de '%s'" % [meu, str(alvo), qual if qual != "" else "ninguém"])
		return false
	var ficha: Dictionary = recursos._alvos[qual]["ficha"]
	var ferramenta := str(ficha.get("ferramenta", ""))
	if ferramenta != "" and not _na_mao_a_ferramenta(ferramenta):
		_falha("passo '%s': o alvo '%s' pede %s e o jogador não a tem (na mochila)" % [id, qual, ferramenta])
		_alvos_que_nao_deram[meu] = true
		return false
	await maos.quadros(2)
	var dono = maos.dono_do_e()
	# O E É DE OUTRO (a lápide ao lado do capim): quem joga muda de lado até o E ser do alvo — o foco pesa a
	# distância e o rumo, e de frente para o capim, e longe da lápide, ele é do capim.
	if dono != recursos:
		var primeiro_dono: String = maos.nome_de(dono)
		var conta_antes: String = maos.explicar_o_foco()
		for lado in range(1, 8):
			var rumo := TAU * float(lado) / 8.0
			var onde: Vector3 = alvo + Vector3(sin(rumo), 0.0, cos(rumo)) * 1.4
			onde = maos.superficie(onde, alvo.y)
			if not vale.world.is_walkable_point(onde) or not maos.sem_corpo(onde):
				continue
			await maos.guiar_ate(onde, 0.4, 5.0)
			maos.virar_para(alvo)
			await maos.quadros(3)
			dono = maos.dono_do_e()
			if dono == recursos:
				break
		if dono != recursos:
			_falha("passo '%s': ao lado de '%s' o E é de %s, e não de quem bate no alvo, de nenhum dos lados. Concorrem (da primeira vez): %s" % [id, qual, primeiro_dono, conta_antes])
			_alvos_que_nao_deram[meu] = true
			return false
	for k in 16:
		energia.encher()
		await maos.apertar(KEY_E)
		await maos.esperar(func() -> bool: return relogio.golpe_acabou(recursos), 10.0)
		if not recursos._alvos.has(qual) or basta.call():
			break
	return true


## O mestre Quirino só está no píer no dia dele, das 7 às 17 h (`SaveiroVale`): o jogador esperaria os dias
## passarem; o portão põe o calendário nesse dia, ao meio-dia, e espera o mestre descer.
func _chamar_o_saveiro(id: String) -> void:
	var saveiro = vale.saveiro
	maos.atalho("o calendário foi posto no dia %d do mês, às 10 h, para o saveiro do mestre Quirino estar no píer (o jogador esperaria os dias passarem)" % int(saveiro.dia))
	root.get_node("/root/Relogio").dia = int(saveiro.dia)
	root.get_node("/root/Dia").definir_hora(10.0)
	var chegou: bool = await maos.esperar(func() -> bool: return saveiro.presente(), 20.0)
	if not chegou:
		_falha("passo '%s': posto o calendário no dia do saveiro (%d), o mestre Quirino não chegou ao píer em 20 s" % [id, int(saveiro.dia)])


## O dinheiro do jogador paga `quantos` de `item` no balcão, com uma folga de 120 réis?
func _pode_pagar(item: String, quantos: int) -> bool:
	return int(root.get_node("/root/Jogo").dinheiro) >= int(root.get_node("/root/Venda").preco_de_compra(item)) * quantos + 120


## Compra `quantos` de `item` no balcão da Venda, pelo J: anda até lá, abre o painel, Tab até a aba da Venda,
## põe o cursor na linha e aperta o E uma vez por unidade.
func _comprar(item: String, quantos: int, id: String) -> bool:
	var BancadasVale = load("res://scripts/prototipo_3d/bancadas_vale.gd")
	var balcao: Vector3 = BancadasVale.ponto_da_provisoria(vale.world, "venda")
	var alcance: float = BancadasVale.raio("venda")
	maos.calado = true
	var chegou: bool = await maos.ir_ate(balcao, 0.0, false, 60.0, minf(alcance * 0.6, 5.0))
	maos.calado = false
	if not chegou:
		_conta("    ... o balcão da Venda não deu: %s" % maos.ultimo_motivo)
		return false
	await maos.quadros(3)
	await maos.abrir_tela(KEY_J, func() -> bool: return painel.aberto)
	for k in 8:
		if not painel.aberto or painel.aba() == painel.Aba.VENDA:
			break
		await maos.apertar(KEY_TAB)
	if not painel.aberto or painel.aba() != painel.Aba.VENDA:
		_falha("passo '%s': no balcão da Venda o J não deu a aba da Venda (aberto=%s aba=%d, obra_em_foco='%s', jogador a %.1f u do balcão)" % [
			id, str(painel.aberto), painel.aba(), str(painel.obra_em_foco), jogador.global_position.distance_to(balcao)])
		if painel.aberto:
			painel.fechar()
		return false
	var linha: int = painel.o_que_o_balcao_tem().find(item)
	if linha < 0:
		_falha("passo '%s': o balcão da Venda não vende '%s'" % [id, item])
		painel.fechar()
		return false
	painel.escolher(linha)
	var comprou := 0
	for k in quantos:
		var antes: int = inv.quantidade(item)
		await maos.apertar(KEY_E)
		if inv.quantidade(item) <= antes:
			break
		comprou += 1
	painel.fechar()
	await maos.quadros(3)
	_conta("    ... comprei %d de %d '%s' no balcão da Venda (restam %d réis)" % [comprou, quantos, item, root.get_node("/root/Jogo").dinheiro])
	return comprou > 0


## Tira a fibra da piaçabeira `candidato`: o facão (ou a foice) na mão, junto da palmeira, o E (ela fica de pé).
func _tirar_a_fibra(candidato: Dictionary, id: String) -> bool:
	var arvores = vale._arvores_info
	var i: int = int(candidato["indice"])
	var chave: String = str(candidato["id"])
	var pos: Vector3 = candidato["pos"]
	if not (_na_mao_a_ferramenta("facao") or _na_mao_a_ferramenta("foice")):
		_falha("passo '%s': o jogador não tem o facão nem a foice para tirar a fibra (na mochila)" % id)
		_alvos_que_nao_deram[chave] = true
		return false
	maos.calado = true
	var chegou: bool = await maos.ir_ate(pos, 1.8, true, 60.0, 3.0)
	maos.calado = false
	if not chegou:
		_alvos_que_nao_deram[chave] = true
		_conta("    ... a piaçabeira %d (%s) não deu: %s" % [i, str(pos), maos.ultimo_motivo])
		return false
	await maos.quadros(2)
	if int(arvores._fibra_perto) != i:
		await maos.guiar_ate(pos, 1.2, 4.0)
		maos.virar_para(pos)
		await maos.quadros(2)
	if int(arvores._fibra_perto) != i:
		_alvos_que_nao_deram[chave] = true
		_conta("    ... a piaçabeira %d (%s) não deu: parado ao lado dela o alcance da fibra é da %d" % [i, str(pos), int(arvores._fibra_perto)])
		return false
	var dono = maos.dono_do_e()
	if dono != arvores:
		_alvos_que_nao_deram[chave] = true
		_conta("    ... a piaçabeira %d (%s) não deu: ao lado dela o E é de %s" % [i, str(pos), maos.nome_de(dono)])
		return false
	var antes: int = inv.quantidade("piacava")
	energia.encher()
	await maos.apertar(KEY_E)
	await maos.quadros(4)
	if inv.quantidade("piacava") <= antes:
		_alvos_que_nao_deram[chave] = true
		_conta("    ... a piaçabeira %d (%s) não deu: o E não passou fibra para a mochila" % [i, str(pos)])
		return false
	return true


## O CERCADO DO CEMITÉRIO só se cruza pela entrada (a malha do clique não conhece a cerca: o corpo bate nela):
## quem vai a um ponto de dentro dele (a pedra solta, o ponto da visita) dá a volta até a entrada e entra por ela.
func _entrar_pelo_cercado(ponto: Vector3) -> void:
	if not obras.ja_feita("cemiterio", "cemiterio_cercado"):
		return
	var centro: Vector3 = lugares.ponto("cemiterio")
	# O cercado é um quadrado de 8,5 u de meio lado em volta do ponto do cemitério.
	var dentro_o_alvo: bool = absf(ponto.x - centro.x) <= 9.5 and absf(ponto.z - centro.z) <= 9.5
	var dentro_o_jogador: bool = absf(jogador.global_position.x - centro.x) <= 9.5 and absf(jogador.global_position.z - centro.z) <= 9.5
	if not dentro_o_alvo or dentro_o_jogador:
		return
	var entrada: Dictionary = vale.cemiterio.entrada()
	if entrada.is_empty() or not (entrada["centro"] as Vector3).is_finite():
		return
	maos.calado = true
	await maos.ir_ate(entrada["centro"], 0.0, false, 60.0, 1.5)
	maos.calado = false
	await maos.guiar_ate(ponto, 3.0, 20.0)


## Corta a árvore `candidato` ({indice, pos}) como o jogador: o machado na mão, junto do tronco, o E (o golpe
## vai e vem pelo corpo e termina com a árvore no chão e a lenha na mochila).
func _cortar_a_arvore(candidato: Dictionary, id: String, basta: Callable) -> bool:
	var arvores = vale._arvores_info
	var i: int = int(candidato["indice"])
	var chave: String = str(candidato["id"])
	var pos: Vector3 = candidato["pos"]
	if not _na_mao_a_ferramenta("machado"):
		_falha("passo '%s': o jogador não tem o machado para cortar árvore (na mochila)" % id)
		_alvos_que_nao_deram[chave] = true
		return false
	maos.calado = true
	var chegou: bool = await maos.ir_ate(pos, 2.0, true, 60.0, 3.0)
	maos.calado = false
	if not chegou:
		_alvos_que_nao_deram[chave] = true
		_conta("    ... a árvore %d (%s) não deu: %s" % [i, str(pos), maos.ultimo_motivo])
		return false
	await maos.quadros(2)
	if int(arvores._cortavel_perto) != i:
		await maos.guiar_ate(pos, 1.6, 4.0)
		maos.virar_para(pos)
		await maos.quadros(2)
	if int(arvores._cortavel_perto) != i:
		_alvos_que_nao_deram[chave] = true
		_conta("    ... a árvore %d (%s) não deu: parado ao lado dela o alcance do machado é da árvore %d" % [i, str(pos), int(arvores._cortavel_perto)])
		return false
	var dono = maos.dono_do_e()
	if dono != arvores:
		_alvos_que_nao_deram[chave] = true
		_conta("    ... a árvore %d (%s) não deu: ao lado dela o E é de %s" % [i, str(pos), maos.nome_de(dono)])
		return false
	for k in 8:
		energia.encher()
		await maos.apertar(KEY_E)
		await maos.esperar(func() -> bool: return int(arvores._em_golpe) < 0 and int(arvores._cortavel_pendente) < 0, 20.0)
		if bool(arvores._cortaveis[i]["cortado"]) or basta.call():
			break
	if not bool(arvores._cortaveis[i]["cortado"]):
		_alvos_que_nao_deram[chave] = true
	return true


## Põe na mão a ferramenta da família `familia` (a que está na mochila).
func _na_mao_a_ferramenta(familia: String) -> bool:
	for i in inv.ESPACOS:
		var id := str((inv.espacos[i] as Dictionary).get("id", ""))
		if id != "" and Catalogo.familia(id) == familia:
			return maos.por_na_mao(id)
	return false


## Fabrica `quantos` de `item` na bancada: anda até ela, abre pelo E e confirma pelo E.
func _fabricar(item: String, quantos: int, id: String) -> bool:
	var BancadasVale = load("res://scripts/prototipo_3d/bancadas_vale.gd")
	var bancada: Vector3 = BancadasVale.ponto_da_provisoria(vale.world, "oficina")
	if not await maos.ir_ate(bancada, 1.8, true, 60.0, 4.0):
		return false
	await maos.quadros(3)
	var dono = maos.dono_do_e()
	if dono != vale.tecla_das_bancadas:
		_falha("passo '%s': ao lado da oficina o E é de %s" % [id, maos.nome_de(dono)])
		return false
	await maos.apertar(KEY_E)
	await maos.esperar(func() -> bool: return painel.aberto, 4.0)
	_conferir(painel.aberto and painel.aba() == painel.Aba.OFICINA, "passo '%s': o E na oficina não abriu a aba da oficina" % id)
	var receitas: Array = oficina.receitas()
	var vezes := ceili(float(quantos) / float(oficina.rende(item)))
	for k in vezes:
		energia.encher()
		painel.escolher(receitas.find(item))
		await maos.apertar(KEY_E)
		await maos.quadros(2)
	if painel.aberto:
		painel.fechar()
	await maos.quadros(2)
	return true


# --- a mochila: comer e ler ------------------------------------------------------------------

## O F em cima de `item`, na mochila: abre com a tecla da mochila, anda o cursor com as setas até o espaço
## dele e aperta o F (come a comida, relê o papel). Comida com o corpo cheio pede um segundo F. Fecha com o
## Esc (o papel fecha a mochila sozinho).
func _usar_da_mochila(item: String, id: String) -> bool:
	var k := -1
	for i in inv.ESPACOS:
		if str((inv.espacos[i] as Dictionary).get("id", "")) == item:
			k = i
			break
	if k < 0:
		_falha("passo '%s': o jogador não tem '%s' na mochila" % [id, item])
		return false
	var mochila := root.get_node("/root/Mochila")
	await maos.apertar(Atalhos.tecla("mochila"))
	await maos.esperar(func() -> bool: return mochila.aberta, 4.0)
	if not mochila.aberta:
		_falha("passo '%s': a tecla da mochila não abriu a mochila" % id)
		return false
	var colunas: int = int(mochila.COLUNAS)
	var dy: int = k / colunas - int(mochila._cursor) / colunas
	var dx: int = k % colunas - int(mochila._cursor) % colunas
	for i in range(absi(dy)):
		await maos.apertar(KEY_DOWN if dy > 0 else KEY_UP)
	for i in range(absi(dx)):
		await maos.apertar(KEY_RIGHT if dx > 0 else KEY_LEFT)
	await maos.apertar(KEY_F)
	await maos.quadros(2)
	if mochila.aberta and str(mochila._confirmar) != "":
		await maos.apertar(KEY_F)
		await maos.quadros(2)
	if mochila.aberta:
		await maos.apertar(KEY_ESCAPE)
		await maos.esperar(func() -> bool: return not mochila.aberta, 4.0)
	return true


## Come `item` pela mochila e confere que ele saiu dela.
func _comer(item: String, id: String) -> void:
	var antes: int = inv.quantidade(item)
	if not await _usar_da_mochila(item, id):
		return
	await maos.quadros(3)
	_conferir(inv.quantidade(item) < antes, "passo '%s': o F em cima de '%s' na mochila não o comeu (continua %d)" % [id, item, inv.quantidade(item)])


## A colheita da mandioca: a roça pede uns dias. Cada manhã o jogador rega o leito (E com o balde na mão) e
## à noite dorme na cama, até a rama amarelar (`Plantacao.maduro`); aí colhe de mão livre (E).
func _colher_a_roca(id: String) -> void:
	var leito := Vector2i(0, 0)
	var plantacao = vale.lavoura.plantacao
	var noites := 0
	while not plantacao.maduro(leito) and noites < 8:
		noites += 1
		await _lavrar("regou", id)
		await _dormir(id)
	if not plantacao.maduro(leito):
		_falha("passo '%s': a mandioca não amadureceu em %d noites regadas e dormidas" % [id, noites])
		return
	# De mão livre: o jogador aperta de novo o número do que está na mão, e a guarda (`Inventario.alternar`).
	inv.selecionar(inv.MAO_LIVRE)
	var ponto: Vector3 = vale.lavoura.posicao_da(leito)
	if not await maos.ir_ate(ponto, 0.9, true, 60.0, 2.5):
		return
	await maos.quadros(3)
	var dono = maos.dono_do_e()
	if dono != vale.lavoura:
		_falha("passo '%s': no roçado, de mão livre, o E é de %s, e não do canteiro" % [id, maos.nome_de(dono)])
		return
	await maos.apertar(KEY_E)
	await maos.quadros(4)


# --- a luta, a pesca, os talentos -----------------------------------------------------------------

func _luta() -> Node:
	return vale.get_node("Luta")


## O bicho de pé mais perto do jogador, ou null.
func _bicho_mais_perto(especie: String = "caititu") -> Object:
	var melhor = null
	var menor := INF
	for c in _luta().criaturas:
		if not is_instance_valid(c) or c.morto() or str(c.especie) != especie:
			continue
		var d: float = Vector2(c.global_position.x - jogador.global_position.x, c.global_position.z - jogador.global_position.z).length()
		if d < menor:
			menor = d
			melhor = c
	return melhor


## O jogador se cura entre as brigas (o caititu morde): o jogador comeria, dormiria, deixaria a mordida sarar.
func _curar() -> void:
	root.get_node("/root/Vida").curar(999.0)
	energia.encher()


## Põe na mão o que se luta: a arma (família `facao`) ou o punho, que é a barra vazia.
func _armar(mao: String) -> bool:
	if mao == "":
		inv.selecionar(inv.MAO_LIVRE)
		return true
	for i in inv.ESPACOS:
		var item := str((inv.espacos[i] as Dictionary).get("id", ""))
		if item != "" and Catalogo.familia(item) == mao:
			return maos.por_na_mao(item)
	return false


## Luta com o caititu até `basta`: anda até o bicho mais perto, vira para ele e bate com o E (`segurar_s`
## segura a tecla: o golpe forte e a rasteira). Quando os bichos caem, os dias passam até um voltar
## (3 dias; `Relogio.dormir`, o que a cama chama).
func _lutar(id: String, basta: Callable, mao: String, segurar_s: float = 0.0) -> bool:
	if not _armar(mao):
		_falha("passo '%s': o jogador não tem como lutar com '%s' (na mochila)" % [id, mao if mao != "" else "a mão livre"])
		return false
	var rodadas := 0
	while not basta.call() and rodadas < 120:
		rodadas += 1
		_curar()
		var bicho = _bicho_mais_perto()
		if bicho == null:
			maos.atalho("os dias de espera do caititu voltar ao ninho passam por `Relogio.dormir()` (o que a cama chama), e não por uma noite na cama cada vez")
			for dia in 4:
				root.get_node("/root/Relogio").dormir()
				await maos.quadros(2)
			continue
		if not await maos.ir_ate(bicho.global_position, 1.1, true, 40.0, 2.0):
			continue
		maos.virar_para(bicho.global_position)
		await maos.quadros(2)
		var dono = maos.dono_do_e()
		if dono != _luta():
			await maos.passar(0.5)
			continue
		await maos.apertar(KEY_E, segurar_s)
		await maos.passar(0.9)
	if not basta.call():
		_falha("passo '%s': o jogador lutou %d rodadas e o passo não fechou" % [id, rodadas])
	return basta.call()


## `contar` e o `evento` da luta e da pesca: cada um por onde o jogador faz.
func _contar(cadeia, passo: Dictionary, id: String) -> void:
	var meta: Dictionary = passo.get("meta", {})
	var evento := str(meta.get("evento", ""))
	var indice: int = cadeia.missao
	var feito := func() -> bool: return cadeia.missao != indice
	match evento:
		"pescou":
			await _pescar(feito, id)
		"acertou:golpe_forte":
			await _lutar(id, feito, "facao", 0.5)
		"acertou:meia_lua":
			await _lutar(id, feito, "")
		"tonteou":
			await _lutar(id, feito, "", 0.5)
		"esquivou":
			await _esquivar(feito, id)
		_:
			_falha("passo '%s': contar '%s' ainda não tem como ser jogado neste portão" % [id, evento])


## A ginga: o jogador fica perto do caititu e aperta a tecla da ginga quando ele parte para o bote; a
## mordida que cai na janela da ginga conta como esquiva (`criatura_vale._morder`).
func _esquivar(basta: Callable, id: String) -> void:
	var rodadas := 0
	while not basta.call() and rodadas < 90:
		rodadas += 1
		_curar()
		var bicho = _bicho_mais_perto()
		if bicho == null:
			maos.atalho("os dias de espera do caititu voltar ao ninho passam por `Relogio.dormir()` (o que a cama chama), e não por uma noite na cama cada vez")
			for dia in 4:
				root.get_node("/root/Relogio").dormir()
				await maos.quadros(2)
			continue
		if not await maos.ir_ate(bicho.global_position, 3.0, true, 40.0, 4.5):
			continue
		# Espera o bote por até 6 s de jogo, de olho no bicho; a ginga sai no começo dele.
		var ate: float = relogio.agora() + 6.0
		while relogio.agora() < ate and not basta.call() and is_instance_valid(bicho) and not bicho.morto():
			maos.virar_para(bicho.global_position)
			if bicho.no_bote():
				await maos.apertar(Atalhos.tecla("gingar"))
				await maos.passar(1.2)
				break
			await maos.quadros(1)


## O talento: o jogador aperta a tecla da árvore de habilidades (K), a tela abre no primeiro nó, e o Enter
## (ou o E) gasta o ponto que ele tem. Sem ponto nenhum, o passo não tem como fechar: diz o nível e o XP.
func _destravar_talento(id: String) -> void:
	var talentos := root.get_node("/root/Talentos")
	if int(talentos.pontos) < 1:
		_falha("passo '%s': o jogador chegou ao passo dos talentos sem nenhum ponto para gastar (nível %d, XP %.0f de %.0f)" % [
			id, int(talentos.nivel), float(talentos.xp), float(talentos.xp_do_nivel())])
		return
	_conta("    ... talentos: %d ponto(s), %d nó(s) destravado(s); K abre a teia" % [int(talentos.pontos), talentos.destravados.size()])
	await maos.abrir_tela(Atalhos.tecla("talentos"), func() -> bool: return bool(vale.teia.aberta))
	if not vale.teia.aberta:
		_falha("passo '%s': a tecla da árvore de habilidades não abriu a teia" % id)
		return
	# O primeiro nó pode pedir outro antes: o jogador anda pela teia (seta para baixo) até um que o ponto compra.
	var antes: int = talentos.destravados.size()
	for tentativa in range(14):
		await maos.apertar(KEY_ENTER)
		await maos.quadros(3)
		if talentos.destravados.size() > antes:
			break
		_conta("    ... o nó '%s' não destravou: %s" % [str(vale.teia._no), str(talentos.impedimento(str(vale.teia._no)))])
		await maos.apertar(KEY_DOWN)
		await maos.quadros(2)
	_conta("    ... talentos: agora %d nó(s) destravado(s), %d ponto(s); contador do vale %s; a fila ouviu=%s; a ponte do sinal=%s" % [
		talentos.destravados.size(), int(talentos.pontos), str(vale.get("_talentos_destravados")),
		str(vale._cadeias["pedro_oficio"].aconteceu("destravou_talento")), str(talentos.mudou.is_connected(vale._ao_mudar_os_talentos))])
	_conferir(talentos.destravados.size() > antes, "passo '%s': nenhum nó da teia pôde ser destravado com os %d pontos que o jogador tem" % [id, int(talentos.pontos)])
	# FECHA PELA TECLA, como o jogador: a tela é do `Telas`, que solta o vale parado; `teia.fechar()` direto
	# deixava a árvore de nós do vale PAUSADA (o Pedro e as filas paradas, e o passo nunca fechava).
	if vale.teia.aberta:
		await maos.apertar(Atalhos.tecla("talentos"))
		await maos.esperar(func() -> bool: return not bool(vale.teia.aberta), 4.0)
	_conferir(not bool(vale.teia.aberta) and not paused, "passo '%s': a tecla da árvore de habilidades não a fechou, ou deixou o vale pausado" % id)


## A pesca: a vara na mão, de frente para a água, E (lança), espera a fisgada, E (ferra) — até `basta`.
func _pescar(basta: Callable, id: String) -> void:
	if not maos.por_na_mao("vara_de_pescar"):
		_falha("passo '%s': o jogador não tem a vara de pescar na mochila" % id)
		return
	var pesca = root.get_node("/root/Pesca")
	var pesca_vale = vale.pesca
	var cais: Vector3 = vale.world.ancoras.get("Pier", Vector3.INF)
	var lugar := Vector3.INF
	var giro := 0.0
	# De frente para a água num ponto de pisar do píer: o jogador procura virando o corpo.
	for raio in [3.0, 5.0, 7.0, 9.0]:
		for k in 16:
			var ponto: Vector3 = vale.world.ground_position(cais + Vector3(sin(TAU * k / 16.0), 0.0, cos(TAU * k / 16.0)) * raio)
			if not vale.world.is_walkable_point(ponto):
				continue
			jogador.teleportar(ponto, 0.0)
			await maos.quadros(1)
			for h in 8:
				var rumo := TAU * h / 8.0
				jogador.visual.rotation.y = rumo
				if pesca_vale.agua_a_frente().is_finite():
					lugar = ponto
					giro = rumo
					break
			if lugar.is_finite():
				break
		if lugar.is_finite():
			break
	if not lugar.is_finite():
		_falha("passo '%s': não achei, junto do píer, um ponto de pisar de frente para a água de pescar" % id)
		return
	maos.atalho("o ponto de pescar (de frente para a água) foi achado por sonda de teleporte junto do píer")
	var voltas := 0
	while not basta.call() and voltas < 30:
		voltas += 1
		energia.encher()
		jogador.visual.rotation.y = giro
		await maos.apertar(KEY_E)
		var ate: float = relogio.agora() + 15.0
		# A fisgada: a janela de ferrar é curta (relógio de parede), então o E sai no primeiro quadro dela.
		while relogio.agora() < ate and pesca.pescando and not pesca.ferrando:
			await maos.quadros(1)
		if pesca.ferrando:
			await maos.apertar(KEY_E)
		await maos.esperar(func() -> bool: return not pesca.pescando, 8.0)
		await maos.quadros(3)
	if not basta.call():
		_falha("passo '%s': pesquei %d vezes e o passo não fechou" % [id, voltas])


# --- o baú da casa ---------------------------------------------------------------------------

## O que o baú da casa guarda e a mochila ainda não tem (a enxada, o balde e a maniva do finado): o jogador
## entra em casa, chega ao baú, aperta o E (abre a mochila com o baú), anda o cursor até o monte com a seta e
## aperta o E de novo (tira uma unidade), e fecha com o Esc.
func _pegar_do_bau(carga: Dictionary, id: String) -> bool:
	var casa = vale.casa
	var falta: Array[String] = []
	for item in carga:
		if inv.quantidade(str(item)) < int(carga[item]) and _lugar_no_bau(casa, str(item)) >= 0:
			falta.append(str(item))
	if falta.is_empty():
		return true
	var sala = casa.quarto()
	if vale.interiores.dentro() != "casa":
		await _entrar_na_sala("casa", id)
	if not await maos.ir_ate(sala.ponto_do_bau(), 1.0, true, 30.0, 1.4):
		return false
	await maos.quadros(3)
	var dono = maos.dono_do_e()
	if dono != casa:
		_falha("passo '%s': ao lado do baú o E é de %s" % [id, maos.nome_de(dono)])
		return false
	var mochila := root.get_node("/root/Mochila")
	await maos.apertar(KEY_E)
	await maos.esperar(func() -> bool: return mochila.aberta, 4.0)
	if not mochila.aberta:
		_falha("passo '%s': o E no baú não abriu a mochila com o baú" % id)
		return false
	for item in falta:
		while inv.quantidade(item) < int(carga[item]):
			var k := _lugar_no_bau(casa, item)
			if k < 0:
				_falha("passo '%s': o baú não tem mais '%s' (a mochila tem %d de %d)" % [id, item, inv.quantidade(item), int(carga[item])])
				break
			var onde: int = int(mochila._cursor) - int(mochila._primeiro_do_bau())
			for passo in range(posmod(k - onde, int(mochila._bau_cabe))):
				await maos.apertar(KEY_RIGHT)
			var antes: int = inv.quantidade(item)
			await maos.apertar(KEY_E)
			await maos.quadros(2)
			if inv.quantidade(item) <= antes:
				_falha("passo '%s': o E no monte de '%s' do baú não passou nada para a mochila" % [id, item])
				break
	await maos.apertar(KEY_ESCAPE)
	await maos.esperar(func() -> bool: return not mochila.aberta, 4.0)
	return true


## O lugar de `item` no baú, ou -1.
func _lugar_no_bau(casa, item: String) -> int:
	for k in casa.bau.size():
		if str((casa.bau[k] as Dictionary).get("id", "")) == item and int((casa.bau[k] as Dictionary).get("qtd", 0)) > 0:
			return k
	return -1


# --- a obra, pelo E e pelo J --------------------------------------------------------------------

func _fazer_a_obra(construcao: String, obra: String, id: String) -> void:
	var BancadasVale = load("res://scripts/prototipo_3d/bancadas_vale.gd")
	var sitio: Vector3 = BancadasVale.ponto_da_provisoria(vale.world, construcao)
	var raio_do_e: float = BancadasVale.raio_do_e(construcao)
	if not await maos.ir_ate(sitio, minf(raio_do_e * 0.55, 3.0), true, 60.0, raio_do_e):
		return
	await maos.quadros(3)
	# O J, no sítio da obra que a missão pede, abre direto em Obras.
	await maos.apertar(KEY_J)
	await maos.esperar(func() -> bool: return painel.aberto, 4.0)
	_conferir(painel.aberto and painel.aba() == painel.Aba.OBRAS and painel.obra_em_foco == construcao,
		"passo '%s': o J no sítio '%s' não abriu na aba de obras daquele sítio (aberto=%s aba=%d sitio='%s')" % [id, construcao, str(painel.aberto), painel.aba(), painel.obra_em_foco])
	if painel.aberto:
		painel.fechar()
	await maos.quadros(3)
	# O E do sítio: a tecla é do sítio (e não do Pedro, do Zefa, do Cosme parados ao lado).
	var dono = maos.dono_do_e()
	if dono != vale.tecla_das_bancadas:
		_falha("passo '%s': ao lado de '%s' (a %.1f u) o E é de %s, e não do sítio de obra" % [id, construcao, jogador.global_position.distance_to(sitio), maos.nome_de(dono)])
		return
	await maos.apertar(KEY_E)
	await maos.esperar(func() -> bool: return painel.aberto, 4.0)
	_conferir(painel.aberto and painel.aba() == painel.Aba.OBRAS and painel.obra_em_foco == construcao,
		"passo '%s': o E em '%s' não abriu a aba de obras do sítio" % [id, construcao])
	energia.encher()
	# O MUTIRÃO traz a parte dele andando até o sítio: espera os dois chegarem (até 360 s de jogo: o Cosme sai
	# do roçado, a mais de 200 u, e anda a 2 u/s).
	var comecou_a_espera: float = relogio.jogo_s
	if str(obras.impedimento(construcao, obra)) != "":
		# COM O PAINEL FECHADO: aberto, ele para o vale, e os ajudantes só andam com o vale correndo. Quem espera o
		# mutirão fecha a tela, espera, e abre de novo.
		painel.fechar()
		await maos.quadros(3)
	while relogio.jogo_s - comecou_a_espera < 360.0 and str(obras.impedimento(construcao, obra)) != "":
		await maos.esperar(func() -> bool: return str(obras.impedimento(construcao, obra)) == "", 30.0)
		if str(obras.impedimento(construcao, obra)) != "":
			var andando: PackedStringArray = []
			for chave in vale._cadeias:
				var fila = vale._cadeias[chave]
				if fila.passo_atual().get("id", "") == id:
					for quem_traz in fila.passo_atual().get("mutirao", {}):
						var morador = vale._achar_morador(str(quem_traz))
						if morador != null:
							andando.append("%s em %s (destino avulso %s, vel %.1f)" % [str(quem_traz), str(morador.global_position), str(morador.get("_destino_avulso")), (morador.velocity as Vector3).length()])
			_conta("    ... esperando o mutirão há %.0f s: %s" % [relogio.jogo_s - comecou_a_espera, "; ".join(andando)])
	if not painel.aberto:
		await maos.apertar(KEY_E)
		await maos.esperar(func() -> bool: return painel.aberto, 4.0)
		_conferir(painel.aberto and painel.aba() == painel.Aba.OBRAS and painel.obra_em_foco == construcao,
			"passo '%s': depois da espera do mutirão o E em '%s' não reabriu a aba de obras do sítio" % [id, construcao])
	var impedimento: String = str(obras.impedimento(construcao, obra))
	var onde_estao: PackedStringArray = []
	for chave in vale._cadeias:
		var fila = vale._cadeias[chave]
		if fila.passo_atual().get("id", "") == id:
			for quem_traz in fila.passo_atual().get("mutirao", {}):
				var morador = vale._achar_morador(str(quem_traz))
				if morador != null:
					onde_estao.append("%s em %s" % [str(quem_traz), str(morador.global_position)])
	_conferir(impedimento == "", "passo '%s': a obra '%s' tem impedimento com o material que o jogador juntou: %s (sítio em %s, jogador em %s; mutirão: %s)" % [
		id, obra, impedimento, str(sitio), str(jogador.global_position), "; ".join(onde_estao)])
	await maos.apertar(KEY_E)
	await maos.quadros(3)
	_conferir(obras.ja_feita(construcao, obra), "passo '%s': o E no painel não fez a obra '%s'" % [id, obra])
	if painel.aberto:
		painel.fechar()
	await maos.quadros(3)


# --- os acontecimentos ----------------------------------------------------------------------------

func _acontecer(evento: String, id: String, feito: Callable = Callable()) -> void:
	energia.encher()
	if evento == "correu":
		await _correr()
	elif evento == "abriu_painel":
		await maos.abrir_tela(KEY_J, func() -> bool: return painel.aberto)
		_conferir(painel.aberto, "passo '%s': o J não abriu o painel" % id)
		if painel.aberto:
			painel.fechar()
	elif evento == "abriu_arraial":
		await maos.abrir_tela(KEY_P, func() -> bool: return bool(vale.social.aberta))
		_conferir(bool(vale.social.aberta), "passo '%s': o P não abriu a tela do arraial" % id)
		await maos.quadros(4)
		# A tela do povo para o vale: o jogador a lê e fecha com o Esc.
		await maos.apertar(KEY_ESCAPE)
		await maos.quadros(3)
	elif evento.begins_with("entrou:"):
		await _entrar_na_sala(evento.trim_prefix("entrou:"), id)
	elif evento in ["arou", "plantou", "regou"]:
		await _lavrar(evento, id)
	elif evento.begins_with("cozinhou:"):
		await _cozinhar(evento.trim_prefix("cozinhou:"), id)
	elif evento == "dormiu":
		await _dormir(id)
	elif evento.begins_with("leu:"):
		await _ler(evento.trim_prefix("leu:"), id)
	elif evento == "destravou_talento":
		await _destravar_talento(id)
	elif evento.begins_with("derrubou:"):
		await _lutar(id, feito, "facao")
	elif evento == "adotou_fe":
		await _no_marco("cruzeiro", "escolher a fé no cruzeiro")
	elif evento == "colheu":
		await _colher_a_roca(id)
	elif evento.begins_with("comeu:"):
		await _comer(evento.trim_prefix("comeu:"), id)
	else:
		_falha("passo '%s': o acontecimento '%s' ainda não tem como ser jogado neste portão" % [id, evento])


## A CORRIDA, como o duplo clique: o jogador clica na praça e o corpo vai CORRENDO pelo caminho da malha
## (`_walk_run`), que é o do píer para a terra — a primeira versão corria em linha reta rumo à praça e
## entrava no mar. O passo fecha quando o vale conta 1,2 s acima do passo (`prototype._ver_se_correu`).
func _correr() -> void:
	var de: Vector3 = jogador.global_position
	var praca: Vector3 = vale.world.ancoras.get("Praça", de)
	var ponto: Vector3 = maos.chegada(praca, 0.0, de, 8.0)
	if not ponto.is_finite() or not jogador.caminhar_ate(ponto):
		_falha("passo 'correr': o clique na praça (%s) não dá caminho ao corpo, que está em %s" % [str(praca), str(de)])
		return
	jogador.set("_walk_run", true)
	await maos.esperar(func() -> bool: return vale.get("_correu_avisado") == true, 20.0)
	jogador._cancel_walk()
	await maos.quadros(2)


func _entrar_na_sala(qual: String, id: String) -> void:
	var sala = vale.interiores.sala_de(qual)
	if sala == null:
		_falha("passo '%s': o vale não tem o cômodo '%s'" % [id, qual])
		return
	# Até a porta, de fora, e para dentro pela soleira. Por dentro a malha de navegação não vai (o clique
	# não anda dentro de casa), então o último trecho é o do corpo: a frente, virado para a soleira de dentro.
	var fora: Vector3 = sala.soleira_de_fora()
	if not await maos.ir_ate(fora, 0.0, false, 60.0, 0.6):
		return
	await maos.guiar_ate(fora, 0.35, 8.0)
	maos.virar_para(sala.soleira_de_dentro())
	Input.action_press("mv_forward")
	await maos.esperar(func() -> bool: return vale.interiores.dentro() == qual, 12.0)
	Input.action_release("mv_forward")
	_conferir(vale.interiores.dentro() == qual, "passo '%s': o jogador não conseguiu entrar em '%s' pela porta (jogador em %s; soleira de fora %s, de dentro %s; porta trancada=%s; Pedro em %s)" % [
		id, qual, str(jogador.global_position), str(sala.soleira_de_fora()), str(sala.soleira_de_dentro()), str(sala.trancada()), str(pedro.global_position)])


func _lavrar(evento: String, id: String) -> void:
	var ferramenta := {"arou": "enxada", "plantou": "semente_mandioca", "regou": "balde"}[evento] as String
	if not maos.por_na_mao(ferramenta):
		_falha("passo '%s': o jogador não tem '%s' (que o baú da casa guarda) para '%s'" % [id, ferramenta, evento])
		return
	var leito := Vector2i(0, 0)
	var ponto: Vector3 = vale.lavoura.posicao_da(leito)
	if not await maos.ir_ate(ponto, 0.9, true, 60.0, 2.5):
		return
	await maos.quadros(3)
	var dono = maos.dono_do_e()
	if dono != vale.lavoura:
		_falha("passo '%s': no roçado, com '%s' na mão, o E é de %s, e não do canteiro" % [id, ferramenta, maos.nome_de(dono)])
		return
	await maos.apertar(KEY_E)
	await maos.quadros(4)


func _cozinhar(receita: String, id: String) -> void:
	# OS INGREDIENTES VÊM ANTES: quem vai ao fogo com a farinha por fazer junta a lenha no caminho.
	var custo: Dictionary = cozinha.dados(receita).get("custo", {})
	for ingrediente in custo:
		if inv.quantidade(str(ingrediente)) < int(custo[ingrediente]):
			await _colher(str(ingrediente), int(custo[ingrediente]), id)
	var fogueira: Vector3 = vale.world.ancoras.get("Fogueira", Vector3.INF)
	if not await maos.ir_ate(fogueira, 1.8, true, 60.0, 4.0):
		return
	await maos.quadros(3)
	var dono = maos.dono_do_e()
	if dono != vale.tecla_das_bancadas:
		_falha("passo '%s': ao lado da fogueira o E é de %s" % [id, maos.nome_de(dono)])
		return
	await maos.apertar(KEY_E)
	await maos.esperar(func() -> bool: return painel.aberto, 4.0)
	_conferir(painel.aberto and painel.aba() == painel.Aba.COZINHA, "passo '%s': o E na fogueira não abriu a aba da cozinha" % id)
	var lista: Array = cozinha.receitas()
	var linha: int = lista.find(receita)
	if linha < 0:
		_falha("passo '%s': a cozinha não lista '%s' (receitas: %s)" % [id, receita, str(lista)])
		if painel.aberto:
			painel.fechar()
		return
	painel.escolher(linha)
	energia.encher()
	var impedimento := str(cozinha.impedimento(receita))
	if impedimento != "":
		_falha("passo '%s': a cozinha não faz '%s' com o que o jogador trouxe: %s" % [id, receita, impedimento])
	await maos.apertar(KEY_E)
	await maos.quadros(3)
	if painel.aberto:
		painel.fechar()


func _dormir(id: String) -> void:
	var casa = vale.casa
	var sala = casa.quarto()
	if vale.interiores.dentro() != "casa":
		await _entrar_na_sala("casa", id)
	var cama: Vector3 = sala.ponto_da_cama()
	if not await maos.ir_ate(cama, 1.0, true, 30.0, 1.6):
		return
	await maos.quadros(3)
	var dono = maos.dono_do_e()
	if dono != casa:
		_falha("passo '%s': ao lado da cama o E é de %s" % [id, maos.nome_de(dono)])
		return
	await maos.apertar(KEY_E)
	# A pergunta "Dormir até o amanhecer?": responde Sim, como o A e o E fariam.
	await maos.esperar(func() -> bool: return dialogo.ativo, 6.0)
	_conferir(dialogo.ativo, "passo '%s': o E na cama não perguntou se dorme" % id)
	dialogo._escolha = true
	dialogo._escolheu = true
	dialogo._fechar()
	await maos.quadros(3)
	await maos.esperar(func() -> bool: return not vale.noite.virando_a_noite() and not dialogo.ativo, 60.0)
	await maos.quadros(10)


func _ler(papel: String, id: String) -> void:
	# F em cima do papel, na mochila (`Mochila._ler`): é como o jogo manda reler o convite.
	if not await _usar_da_mochila(papel, id):
		return
	await maos.esperar(func() -> bool: return dialogo.ativo, 6.0)
	await maos.quadros(2)


## Os passos das 22 filas que já passaram (a memória das próprias filas, e não a lista do portão: um passo que
## fecha sozinho ao abrir a fila, como a visita ao cemitério, também conta), e os que faltam.
func _contar_os_passos() -> Dictionary:
	var feitos := 0
	var faltam: PackedStringArray = []
	var filas: Array = [pedro._cadeia]
	for chave in vale._cadeias:
		filas.append(vale._cadeias[chave])
	for fila in filas:
		for passo in fila.passos:
			if fila.passou(str(passo.get("id", ""))):
				feitos += 1
			else:
				faltam.append(str(passo.get("id", "")))
	return {"feitos": feitos, "faltam": faltam}


func _fechar() -> void:
	print("")
	var contas := _contar_os_passos()
	print("passos jogados: %d de 85 (pela memória das filas: %d)" % [passos_do_vale, int(contas["feitos"])])
	if ate_a_fase == "" and falhas == 0:
		_conferir(int(contas["feitos"]) == 85, "as filas passaram %d dos 85 passos; faltam: %s" % [int(contas["feitos"]), ", ".join(contas["faltam"])])
	if not maos.atalhos.is_empty():
		print("o que NÃO foi o caminho do jogador:")
		for a in maos.atalhos:
			print("   - " + a)
	if falhas == 0:
		print("COMECO_AO_FIM_OK: %d passos das filas jogados do desembarque ao fim, com os controles do jogador" % passos_do_vale)
	else:
		print("comeco_ao_fim: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)
