extends "res://tests/suite/caso.gd"
## A ATENÇÃO A QUEM A MISSÃO MANDA PROCURAR (#198): o morador que o passo aponta PARA e olha o
## jogador que chega perto, em vez de seguir a rotina.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste atencao_do_morador
##
## Playtest: no passo "Volte ao Pedro e conte o que viu" o Pedro seguia andando, o jogador ia atrás dele,
## colado, e a dica "E Falar com Pedro" nunca firmava. Cinco perguntas:
##
##   1. A FRASE É SORTEADA SEM REPETIR a anterior, e a do `quando` só vale no momento dela
##      (`npc.escolher_atencao`, sem mundo).
##   2. O PEDRO TEM de quatro a seis frases de atenção, nos quatro idiomas, uma do fim do dia e uma do relato,
##      cada uma com o nome do áudio (o arquivo é conferido em `vozes_dos_moradores.gd`).
##   3. QUEM O PASSO APONTA PARA quando o jogador chega perto e se vira para ele (o Tonho, no bom-dia da chegada).
##   4. A FRASE NÃO TIRA O E: com ela no ar, `tecla_dos_moradores` ainda o vê ao alcance (a dica firme).
##   5. ELE SOLTA O JOGADOR: afastando-se, ele volta à rotina. E quem NÃO é alvo de passo nenhum não para.

const SEGUNDOS_PARA_ANUNCIAR := 12.0
const SEGUNDOS_DE_PALAVRA := 25.0
const QUANDOS := ["", "fim_do_dia", "relato"]

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("ATENCAO_DO_MORADOR_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	var Npc = load("res://scripts/prototipo_3d/npc.gd")
	var arquivo = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs_3d.json"))
	_conferir(arquivo is Dictionary, "o npcs_3d.json não abre")
	var lista: Array = (arquivo["guia"] as Dictionary).get("atencao", []) if arquivo is Dictionary else []

	# --- 2. AS FRASES DO PEDRO -------------------------------------------------------------
	_conferir(lista.size() >= 4 and lista.size() <= 6, "o Pedro tem %d frase(s) de atenção, e são de quatro a seis" % lista.size())
	var do_dia := 0
	var do_relato := 0
	var vistos := {}
	for i in lista.size():
		var fala: Dictionary = lista[i]
		for chave in ["texto", "texto_en", "texto_es", "texto_zh", "audio"]:
			_conferir(str(fala.get(chave, "")) != "", "atencao[%d] sem o campo %s" % [i, chave])
		_conferir(QUANDOS.has(str(fala.get("quando", ""))), "atencao[%d] tem um `quando` que o motor não conhece: '%s'" % [i, str(fala.get("quando", ""))])
		_conferir(not vistos.has(str(fala.get("audio", ""))), "atencao[%d] repete o nome do áudio" % i)
		vistos[str(fala.get("audio", ""))] = true
		do_dia += 1 if str(fala.get("quando", "")) == "fim_do_dia" else 0
		do_relato += 1 if str(fala.get("quando", "")) == "relato" else 0
	_conferir(do_dia >= 1 and do_relato >= 1, "faltam a frase do fim do dia (%d) ou a do relato (%d)" % [do_dia, do_relato])

	# --- 1. O SORTEIO ------------------------------------------------------------------------
	var base := 0
	for fala in lista:
		base += 1 if str((fala as Dictionary).get("quando", "")) == "" else 0
	var normal := {}
	for passo in 40:
		var i: int = Npc.escolher_atencao(lista, -1, false, false, float(passo) / 40.0)
		_conferir(i >= 0 and str(lista[i].get("quando", "")) == "", "de dia e sem relato saiu a frase %d, que tem `quando`" % i)
		normal[i] = true
	_conferir(normal.size() == base, "o sorteio de dia alcançou %d frase(s) de %d" % [normal.size(), base])
	var anterior := 0
	for passo in 40:
		var i: int = Npc.escolher_atencao(lista, anterior, true, true, float(passo) / 40.0)
		_conferir(i >= 0 and i != anterior, "o sorteio repetiu a frase anterior (%d)" % anterior)
		anterior = i
	var viu_dia := false
	var viu_relato := false
	for passo in 40:
		var i: int = Npc.escolher_atencao(lista, -1, true, true, float(passo) / 40.0)
		viu_dia = viu_dia or str(lista[i].get("quando", "")) == "fim_do_dia"
		viu_relato = viu_relato or str(lista[i].get("quando", "")) == "relato"
	_conferir(viu_dia and viu_relato, "no fim do dia e com relato o sorteio nunca chegou às frases do momento")
	_conferir(Npc.escolher_atencao([], -1, true, true, 0.5) == -1, "sem frases o sorteio devia devolver -1")
	_conferir(Npc.escolher_atencao([{"texto": "só", "quando": "relato"}], -1, false, false, 0.5) == -1,
		"a frase do relato valeu fora do relato")
	_conferir(Npc.escolher_atencao([{"texto": "única"}], 0, false, false, 0.9) == 0,
		"com uma frase só, repetir a anterior é o certo")

	# --- 3, 4 e 5. NO VALE ---------------------------------------------------------------------
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(3)
	var jogo := current_scene
	var jogador = jogo.get("player")
	var pedro = jogo.get("pedro")
	var tecla = jogo.get("tecla_dos_moradores")
	var tonho: Node3D = null
	var sem_missao: Node3D = null
	for morador in jogo.get("moradores") as Array:
		if str((morador.dados as Dictionary).get("id", "")) == "tonho":
			tonho = morador
	_conferir(jogador != null and pedro != null and tonho != null and tecla != null, "não achei o jogador, o Pedro, o Tonho ou a tecla do E")
	if jogador == null or pedro == null or tonho == null or tecla == null:
		_fechar()
		return

	# O bom-dia ao Tonho é o passo que o aponta (como em `saudacao.gd`).
	pedro.saudar()
	_conferir(pedro.ir_ao_passo("bom_dia"), "a chegada não tem o bom-dia ao Tonho")
	var no_bom_dia: int = int(pedro.missao)
	pedro._espera = 0.05
	await _ate(func() -> bool: return int(pedro.missao) == no_bom_dia and float(pedro._espera) <= 0.0, SEGUNDOS_PARA_ANUNCIAR)
	_conferir(tonho.tem_missao(), "o passo da chegada manda falar com o Tonho, e ele se diz sem missão")
	_conferir(not tonho._passo_que_me_procura().is_empty(), "o Tonho não acha o passo que o procura")
	for morador in jogo.get("moradores") as Array:
		if morador != tonho and not morador.tem_missao() and morador.global_position.distance_to(tonho.global_position) > 12.0:
			sem_missao = morador
			break
	# Uma frase de teste, sem áudio: o que se confere é o motor.
	(tonho.dados as Dictionary)["atencao"] = [{"texto": "Diga!", "texto_en": "Go ahead!", "texto_es": "¡Dime!", "texto_zh": "说吧！", "audio": ""}]

	# 5a. Longe, ele não para.
	jogador.teleportar(tonho.global_position + Vector3(9.0, 0.0, 0.0), 0.0)
	await _ate(func() -> bool: return false, 1.2)
	_conferir(float(tonho._atencao_resta) <= 0.0, "o Tonho parou com o jogador a nove passos")

	# 3. Perto, ele para e se vira.
	await _palavra_livre(func() -> bool: return tonho.pode_falar(), SEGUNDOS_DE_PALAVRA)
	jogador.teleportar(tonho.global_position + Vector3(2.0, 0.0, 0.6), 0.0)
	var parou := await _ate(func() -> bool: return float(tonho._atencao_resta) > 0.0, 3.0)
	_conferir(parou, "o Tonho não deu atenção ao jogador a dois passos, com o passo apontando ele")
	await _ate(func() -> bool: return false, 0.5)
	_conferir(Vector2(tonho.velocity.x, tonho.velocity.z).length() < 0.3, "o Tonho segue andando enquanto dá atenção")
	# 4. A frase no ar não tira o E.
	await _palavra_livre(func() -> bool: return tonho.pode_falar(), SEGUNDOS_DE_PALAVRA)
	tonho._comecar_a_atencao()
	var falou := await _ate(func() -> bool: return tonho.atencao_no_ar(), 6.0)
	_conferir(falou, "o Tonho não disse a frase de atenção com a palavra livre")
	if falou:
		_conferir(tonho.falando_agora(), "a frase de atenção está no ar, e ele não diz que fala")
		_conferir(not tecla._fala_ativa(tonho), "a frase de atenção esconde a dica e o E do Tonho (a dica não firma)")
		_conferir(tecla._mais_perto() == tonho, "a dica do E não está no Tonho enquanto ele dá atenção")

	# 5b. Afastando-se, ele volta à rotina.
	jogador.teleportar(tonho.global_position + Vector3(9.0, 0.0, 0.0), 0.0)
	var largou := await _ate(func() -> bool: return float(tonho._atencao_resta) <= 0.0, 2.0)
	_conferir(largou, "o Tonho não largou a atenção com o jogador a nove passos")

	# 5c. Quem nenhum passo aponta não para.
	_conferir(sem_missao != null, "não achei morador sem missão longe do Tonho")
	if sem_missao != null:
		_conferir(sem_missao._passo_que_me_procura().is_empty(), "%s diz que o procuram, e nenhum passo o aponta" % sem_missao.name)
		jogador.teleportar(sem_missao.global_position + Vector3(1.5, 0.0, 0.0), 0.0)
		await _ate(func() -> bool: return false, 1.5)
		_conferir(float(sem_missao._atencao_resta) <= 0.0, "%s deu atenção, e nenhum passo o aponta" % sem_missao.name)
	_fechar()


func _palavra_livre(condicao: Callable, segundos: float) -> bool:
	var fila = current_scene.get("fila_de_falas")
	var limite := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < limite:
		if condicao.call():
			return true
		if fila != null:
			fila.pular()
		await process_frame
	return condicao.call()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("ATENCAO_DO_MORADOR_OK: a frase de atenção do Pedro é sorteada sem repetir e respeita o momento; quem o passo aponta para e se vira com o jogador perto, a frase no ar não tira o E, e ele solta o jogador que se afasta; quem nenhum passo aponta não para")
	else:
		print("atencao_do_morador: %d falha(s)" % falhas)
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
