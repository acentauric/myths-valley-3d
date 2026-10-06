extends SceneTree
## Confere a LUTA no vale (#14): o bicho de caixa cinza, o bote anunciado, a
## ginga, o golpe no tempo do braço, e a mata que repõe quem caiu.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/luta.gd
##
## A regra do golpe é o `Luta` compartilhado, e a do bicho é a do 2D
## (`scripts/npcs/criatura.gd`) com os mesmos números — o `testar_luta` e o
## `testar_criaturas` de lá seguram a regra. Este portão pergunta o que só o
## vale responde:
##
##   1. OS NÚMEROS SÃO OS DO 2D, e a escala vem do passo do jogador: a onça
##      continua entre o passo e a carreira dele.
##   2. O CAITITU MORA NA MATA FECHADA, em terra, longe da porta de casa e do
##      píer — quem cai acorda na porta, e não pode acordar do lado do bicho.
##   3. FAREJA E DESISTE em dois raios.
##   4. O BOTE É ANUNCIADO: o bicho acende e marca o chão ANTES de morder, e a
##      mordida só entra a `bote * bote_acerta` segundos do começo.
##   5. A GINGA LIVRA: gingar no aviso faz a boca fechar no vazio, conta como
##      esquiva e gasta o fôlego da ginga.
##   6. O GOLPE ACERTA DE FRENTE E ERRA DE COSTAS, no tempo do braço, com o dano
##      do `Luta` e o fôlego do golpe. Tocar dá o golpe; segurar, o forte.
##   7. QUEM CAI deixa a caça na mochila, devolve fôlego, conta abate — e a mata
##      o repõe em três dias, e não antes.

## Carregada DEPOIS de o vale subir, e não por preload: ela cita os autoloads,
## e compilada antes deles falha e fica quebrada no cache para o jogo inteiro.
var Criatura
const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")

var falhas := 0
var vida
var regra
var energia
var inventario
var relogio


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("LUTA_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	# Autoloads por nó: script rodado com --script não os enxerga pelo nome.
	vida = root.get_node("/root/Vida")
	regra = root.get_node("/root/Luta")
	energia = root.get_node("/root/Energia")
	inventario = root.get_node("/root/Inventario")
	relogio = root.get_node("/root/Relogio")
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "o vale não carregou")
	await _frames(6)
	await _mundo_pronto()
	await _frames(10)
	var vale = current_scene
	var player = vale.player
	var world = vale.world
	var luta = vale.get_node_or_null("Luta")
	_conferir(luta != null, "o vale não montou o nó da luta")
	if luta == null:
		_fechar()
		return
	Criatura = load("res://scripts/prototipo_3d/criatura_vale.gd")
	# --- 1. OS NÚMEROS SÃO OS DO 2D ------------------------------------------
	_conferir(FileAccess.file_exists(Criatura.ARQUIVO_DAS_ESPECIES), "a tabela das criaturas não está em %s" % Criatura.ARQUIVO_DAS_ESPECIES)
	var caititu: Dictionary = Criatura.ESPECIES["caititu"]
	_conferir(caititu["vida"] == 12.0 and caititu["dano"] == 4.0 and caititu["passo"] == 46.0,
		"o caititu não tem vida, dano e passo do 2D: %s" % str(caititu))
	_conferir(caititu["bote"] == 0.75 and caititu["bote_acerta"] == 0.55 and caititu["salto"] == 6.0,
		"o bote do caititu não é o do 2D")
	_conferir(Criatura.ESPECIES["jararaca"].has("peconha"), "a jararaca perdeu a peçonha")
	_conferir(Atalhos.tecla("gingar") == KEY_V, "a ginga não está no V: %s" % OS.get_keycode_string(Atalhos.tecla("gingar")))

	var u: float = luta.u_por_px
	_conferir(is_equal_approx(u, player.walk_speed / Criatura.PASSO_DO_JOGADOR_2D),
		"a escala não sai do passo do jogador: %s" % str(u))
	var onca := float(Criatura.ESPECIES["onca"]["passo"]) * u
	_conferir(onca > player.walk_speed and onca < player.run_speed,
		"a onça (%.2f u/s) não ficou entre o passo (%.2f) e a carreira (%.2f)" % [onca, player.walk_speed, player.run_speed])

	# --- 2. O CAITITU MORA NA MATA FECHADA -------------------------------------
	# POR ESPÉCIE, e não a lista inteira: a mata tem onça também (#28).
	_conferir(_caititus(luta).size() == 1, "o vale devia ter um caititu, tem %d" % _caititus(luta).size())
	if _caititus(luta).is_empty():
		_fechar()
		return
	var bicho = _caititus(luta)[0]
	var ninho: Vector3 = bicho.global_position
	var casa: Vector3 = world.ancoras.get("Casa de taipa", Vector3.INF)
	print("LUTA: ninho do caititu em %s · %.0f u da casa · %.0f u da chegada" % [str(ninho),
		_plano(ninho - casa).length(), _plano(ninho - player.spawn_position).length()])
	_conferir(world.na_mata_fechada(ninho), "o caititu não nasceu na mata fechada")
	_conferir(world.is_on_land(ninho), "o caititu nasceu na água")
	_conferir(_plano(ninho - casa).length() >= luta.LONGE_DE_CASA, "o ninho está perto da porta de casa")
	_conferir(_plano(ninho - player.spawn_position).length() >= luta.LONGE_DA_CHEGADA, "o ninho está perto da chegada")

	# --- 3. FAREJA E DESISTE ---------------------------------------------------
	var fareja: float = float(caititu["fareja"]) * u
	var desiste: float = float(caititu["desiste"]) * u
	_levar(player, world, bicho.global_position + Vector3(desiste * 1.3, 0.0, 0.0), bicho)
	await _fisica(10)
	_conferir(not bicho.cacando, "o caititu caça quem está além de onde desiste")
	_levar(player, world, bicho.global_position + Vector3(fareja * 0.6, 0.0, 0.0), bicho)
	await _fisica(4)
	_conferir(bicho.cacando, "o caititu não farejou quem chegou a %.1f u" % (fareja * 0.6))

	# --- 4. O BOTE É ANUNCIADO -------------------------------------------------
	vida.dormir()
	var comecou := await _esperar_o_bote(bicho, 8.0)
	_conferir(comecou, "o caititu farejou e não armou o bote")
	var vida_antes: float = vida.atual
	_conferir(bicho.avisando(), "o bote armou sem acender")
	_conferir(bicho._marca.visible, "o bote armou sem marcar o chão")
	var ate_morder := 0.0
	var avisou_ate_morder := true
	while vida.atual == vida_antes and ate_morder < 2.0:
		await physics_frame
		ate_morder += 1.0 / Engine.physics_ticks_per_second
		if vida.atual == vida_antes and not bicho.avisando() and bicho.no_bote():
			avisou_ate_morder = false
	var espera: float = float(caititu["bote"]) * float(caititu["bote_acerta"])
	print("LUTA: a mordida entrou %.2f s depois de armar (o 2D pede %.2f)" % [ate_morder, espera])
	_conferir(vida.atual < vida_antes, "o bote armou e a mordida não entrou")
	_conferir(is_equal_approx(vida_antes - vida.atual, 4.0), "a mordida tirou %s, e o caititu morde 4" % str(vida_antes - vida.atual))
	_conferir(ate_morder >= espera - 0.05, "a mordida entrou %.2f s depois do aviso, antes dos %.2f do 2D" % [ate_morder, espera])
	_conferir(avisou_ate_morder, "o aviso apagou antes de a boca fechar")
	await _fisica(2)
	_conferir(not bicho.avisando() and not bicho._marca.visible, "depois da mordida o aviso continuou aceso")

	# --- 5. A GINGA LIVRA ------------------------------------------------------
	regra.aprender("ginga")
	vida.dormir()
	energia.encher()
	var esquivas := [0]
	regra.esquivou.connect(func(_e): esquivas[0] += 1)
	_levar(player, world, bicho.global_position + Vector3(0.3, 0.0, 0.0), bicho)
	comecou = await _esperar_o_bote(bicho, 8.0)
	_conferir(comecou, "o caititu não armou o segundo bote")
	var folego_antes: float = energia.atual
	_conferir(luta.gingar(), "quem aprendeu a ginga não gingou")
	# Mede a cobrança antes de o vigor começar a se recuperar por descanso.
	var gasto_na_ginga: float = folego_antes - energia.atual
	var vida_na_ginga: float = vida.atual
	await _fisica(int(Engine.physics_ticks_per_second * 0.8))
	_conferir(esquivas[0] == 1, "a ginga no aviso não contou como esquiva (%d)" % esquivas[0])
	_conferir(vida.atual == vida_na_ginga, "gingou no aviso e a mordida entrou mesmo assim")
	_conferir(is_equal_approx(gasto_na_ginga, energia.custo("bater", regra.folego_da_ginga())),
		"a ginga gastou %s de vigor" % str(gasto_na_ginga))

	# --- 6. O GOLPE: de frente acerta, de costas erra --------------------------
	bicho.set_physics_process(false)
	inventario.adicionar("facao")
	inventario.selecionar(_espaco_de("facao"))
	_conferir(inventario.na_mao() == "facao", "não consegui pôr o facão na mão")
	_levar(player, world, ninho, null)
	await _fisica(3)
	var frente: Vector3 = luta.frente_do_jogador()
	bicho.global_position = player.global_position + frente * 0.5
	var vida_do_bicho: float = bicho.vida
	energia.encher()
	folego_antes = energia.atual
	await luta.bater("golpe", "facao")
	_conferir(is_equal_approx(vida_do_bicho - bicho.vida, regra.dano("golpe", "facao")),
		"o golpe de frente tirou %s, e o do facão tira %s" % [str(vida_do_bicho - bicho.vida), str(regra.dano("golpe", "facao"))])
	_conferir(is_equal_approx(folego_antes - energia.atual, energia.custo("bater", regra.folego("golpe"))),
		"o golpe gastou %s de fôlego" % str(folego_antes - energia.atual))
	bicho.global_position = player.global_position - frente * 0.5
	vida_do_bicho = bicho.vida
	await luta.bater("golpe", "facao")
	_conferir(bicho.vida == vida_do_bicho, "o golpe de costas acertou")

	# Tocar e segurar: o E segurado vira o golpe forte, para quem aprendeu.
	regra.aprender("golpe_forte")
	var golpes: Array = []
	luta.bateu.connect(func(g): golpes.append(g))
	bicho.global_position = player.global_position + frente * 0.5
	# Vida de sobra: três golpes seguidos derrubariam o caititu aqui, e a queda
	# é pergunta do trecho 7.
	bicho.vida = 1000.0
	luta.segurando = func() -> bool: return true
	_conferir(luta.armar_a_luta(), "com facão na mão e bicho perto, o E não armou a luta")
	# O gesto segurado usa tempo de parede, também com --fixed-fps.
	var ate_segurar := Time.get_ticks_msec() + int((regra.SEGURAR + 0.3) * 1000.0)
	while Time.get_ticks_msec() < ate_segurar:
		await process_frame
	luta.segurando = func() -> bool: return false
	_conferir(luta.armar_a_luta(), "o E não armou a luta pela segunda vez")
	await _fisica(3)
	await create_timer(0.4).timeout
	_conferir(golpes == ["golpe_forte", "golpe"], "segurar e tocar deram %s, e são golpe forte e golpe" % str(golpes))

	# --- 7. QUEM CAI, E A MATA QUE REPÕE ---------------------------------------
	var abates_antes: int = regra.abatidos("caititu")
	var carne_antes: int = inventario.quantidade("carne_de_caca")
	# A luta cobra a reserva do dia (#82), e é nela que o caititu devolve.
	energia.definir(20.0)
	bicho.vida = 1.0
	bicho.global_position = player.global_position + frente * 0.5
	await luta.bater("golpe", "facao")
	_conferir(bicho.morto(), "o golpe final não derrubou o caititu")
	_conferir(regra.abatidos("caititu") == abates_antes + 1, "o abate não foi contado")
	_conferir(inventario.quantidade("carne_de_caca") == carne_antes + 1, "a carne de caça não foi para a mochila")
	_conferir(is_equal_approx(energia.atual, 20.0 - energia.custo("bater", regra.folego("golpe")) + float(caititu["folego"])),
		"derrubar não devolveu o fôlego do caititu: %s" % str(energia.atual))
	bicho.set_physics_process(true)
	await create_timer(Criatura.TEMPO_DA_MORTE + Criatura.TEMPO_DO_SUMICO + 0.3).timeout
	_conferir(not is_instance_valid(bicho), "o caititu caído não sumiu")
	_conferir(_caititus(luta).is_empty(), "a mata ainda conta o caititu caído")
	for noite in 2:
		relogio.dormir()
	await _frames(2)
	_conferir(_caititus(luta).is_empty(), "o caititu voltou antes dos três dias")
	relogio.dormir()
	await _frames(2)
	_conferir(_caititus(luta).size() == 1, "três dias depois, a mata não repôs o caititu")
	if _caititus(luta).size() == 1:
		_conferir(_plano(_caititus(luta)[0].global_position - ninho).length() < 1.0, "o caititu voltou fora do ninho")

	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("LUTA_OK: números do 2D na escala do passo; o caititu mora na mata longe de casa, fareja e desiste, anuncia o bote antes de morder, a ginga livra, o golpe acerta de frente e erra de costas, segurar dá o forte, e quem cai deixa a caça e volta em três dias")
	else:
		print("luta: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


## Põe o jogador em terra, parado, virado para o bicho (se houver).
func _levar(player, world, onde: Vector3, olhar_para) -> void:
	player.global_position = world.ground_position(onde, 0.1)
	player.velocity = Vector3.ZERO
	if olhar_para != null:
		var para: Vector3 = _plano(olhar_para.global_position - player.global_position)
		if para.length() > 0.01:
			player.visual.rotation.y = atan2(para.x, para.z)


## Espera um bote NOVO armar: se um bote já está no meio (o que acabou de
## morder), espera ele terminar primeiro — pegar o rabo do bote velho faz a
## ginga ser medida num bote em que ninguém mais vai morder.
func _esperar_o_bote(bicho, segundos: float) -> bool:
	var passou := 0.0
	while passou < segundos and is_instance_valid(bicho) and bicho.no_bote():
		await physics_frame
		passou += 1.0 / Engine.physics_ticks_per_second
	while passou < segundos:
		if not is_instance_valid(bicho):
			return false
		if bicho.no_bote():
			return true
		await physics_frame
		passou += 1.0 / Engine.physics_ticks_per_second
	return false


## Os caititus de pé (a luta também tem onças).
func _caititus(luta) -> Array:
	return (luta.criaturas + luta.oncas).filter(func(c): return is_instance_valid(c) and c.especie == "caititu")


func _espaco_de(id: String) -> int:
	for i in inventario.ESPACOS_MAO:
		if inventario.espacos[i].get("id", "") == id:
			return i
	return -1


func _plano(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _fisica(n: int) -> void:
	for i in n:
		await physics_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _mundo_pronto() -> void:
	for i in range(3000):
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
