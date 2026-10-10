extends SceneTree
## Confere as ANIMAÇÕES DOS BICHOS, uma por uma ("precisamos revisar as animações dos
## animais"): a esticada, a pausa, o clipe torto, a perna dura, a patinação e a cabra.
##
##     Godot_v4.7.2-stable-win64_console.exe --headless --path . --script res://tests/animais_animacao.gd
##
## O que este portão pergunta, e nenhum outro:
##
##   1. NÃO ESTICA PARADO. Parado, a escala do bicho não muda nada (a altura fica na que ele
##      persegue, a largura em 1) em 600 quadros a 30, 60, 144 e 240 quadros por segundo, de pé e
##      abaixado, quadrúpede e ave: a respiração (#109) só ergue o focinho até `RESPIRA` (0,7°), o
##      corpo rígido, e a anca apoiada. (Antes ela escalava a pose e realimentava a própria escala:
##      de +15 % a +43 %, pernas junto.)
##   2. NADA SE MEXE COM O JOGO PAUSADO: pose, osso do esqueleto, posição do clipe, e o
##      relógio do nado dos peixes (os shaders não usam mais o TIME do motor).
##   3. O CLIPE ANDA NO CHÃO: com clipe, ele toca em `velocidade / passada` — o dobro da
##      velocidade, o dobro do ritmo —, no passo de cada bicho o pé acompanha o corpo (a
##      passada cabe no alcance do clipe: no mínimo 90 % do chão), e na corrida (a fuga
##      dos gatos, a carga da onça) o clipe acelera até onde pode sem virar tremor.
##   4. O CLIPE É SAUDÁVEL em todos os 14 quadrúpedes: a pata não passa de 30 % da altura
##      do bicho e a cabeça não sai mais de 20 % do lugar (o da onça pintada e o do cão
##      caramelo vinham tortos: a pata subia à altura da cabeça).
##   5. PERNA PARADA: onde o clipe deixa uma perna dura (onça preta, cão malhado), ela
##      balança no ritmo da diagonal.
##   4b. O PESCOÇO FICA FIRME (#149): o clipe do cão caramelo e da onça pintada balançava o
##      ombro e o pescoço como perna, e a frente do bicho empinava a cada passo (o cachorro "em
##      pé nas patas de trás"). Com o clipe pronto a cabeça sai do lugar no máximo `CABECA_FIRME`
##      da altura (era 9 % no cão e 14 % na onça).
##   5b. AS PATAS DA FRENTE DO CÃO ANDAM, em contratempo: o clipe as deixa duras, o código as
##      balança copiando a pata de trás, meio ciclo uma da outra, e parado a defasagem some.
##   5c. O CORPO ACOMPANHA A RAMPA: o focinho sobe com o chão que sobe (`BichoDeCasa.inclinacao_da_encosta`)
##      e a pose segue a inclinação sem salto.
##   6. PARADO, ELE CONGELA NO QUADRO DE PÉ, e o bote (armar, pular, assentar) mexe em
##      posição e giro, sem esticar o corpo.
##   7. A CABRA DE CENA anda com o clipe, no ritmo do chão, e para.
##
## FALSIFICAÇÃO: com `--falsificar-clipe` o portão mede o clipe CRU (o GLB recarregado
## sem cache, como veio do Tripo) dos dois modelos tortos — a pergunta 4 tem de FALHAR.
## Com `--falsificar-pescoco` ele recentra o clipe cru dos dois modelos SEM firmar o pescoço — a 4b tem
## de FALHAR nos dois. Com `--falsificar-respiro` ele refaz a realimentação da escala (a de antes) por fora do
## animador — a pergunta 1 tem de FALHAR nos 60 quadros por segundo ou mais.

const MODELOS := ["onca_pintada", "onca_preta", "cachorro_caramelo", "cachorro_malhado", "filhote_caramelo",
	"gato_malhado", "gato_preto", "gato_amarelo", "porco", "leitao", "jumento", "cabra_solta", "bode", "caititu"]
## A pata e a cabeça dos clipes saudáveis (fração da altura do esqueleto).
const PATA_ATE := 0.30
const CABECA_ATE := 0.20
## O pé tem de andar pelo menos isto do passo do corpo no PASSO de cada bicho, e isto na
## CORRIDA (o clipe é um passeio: a corrida satura em `ACELERA_ATE`, e a pata é rápida demais
## para escorregar de verdade, mas não alcança o chão).
const PE_NO_PASSO := 0.9
const PE_NA_CORRIDA := 0.25
## A cabeça do clipe pronto (recentrado e de pescoço firme) sai do lugar, no máximo, esta fração da
## altura: o balanço da coluna (4 a 6 %) cabe, a frente empinando (9 a 14 %) não.
const CABECA_FIRME := 0.08
## O pé da frente do cão anda, no mínimo, esta fração da altura em cada passo (sem o balanço
## do código, a coluna sozinha o leva a 7 %).
const PE_DA_FRENTE_ANDA := 0.10
## O rig do bode não tem a perna de baixo: o clipe não mexe pé, e não há passada a medir.
const SEM_PASSADA := ["bode"]

var falhas := 0
var falsificar_clipe := false
var falsificar_respiro := false
## A amplitude da respiração de antes de #109, que escalava a pose: o falsificador a refaz.
const RESPIRA_ANTIGA := 0.014
var falsificar_pescoco := false
var Animador
var CabraDeCena
var Cardume
var Criatura
var arena: Node3D
var animais: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("ANIMAIS_ANIMACAO_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	falsificar_clipe = "--falsificar-clipe" in OS.get_cmdline_user_args()
	falsificar_respiro = "--falsificar-respiro" in OS.get_cmdline_user_args()
	falsificar_pescoco = "--falsificar-pescoco" in OS.get_cmdline_user_args()
	root.get_node("/root/Estilo").modo = "tripo"
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "o vale não carregou")
	await _frames(6)
	await _mundo_pronto()
	await _frames(10)
	var vale = current_scene
	Animador = load("res://scripts/prototipo_3d/animador_bicho.gd")
	CabraDeCena = load("res://scripts/prototipo_3d/cabra_de_cena.gd")
	Cardume = load("res://scripts/prototipo_3d/cardume.gd")
	Criatura = load("res://scripts/prototipo_3d/criatura_vale.gd")

	# A arena: os bichos de verdade, um do lado do outro, longe do vale e sem ninguém por perto.
	arena = Node3D.new()
	arena.name = "ArenaDosBichos"
	vale.add_child(arena)
	arena.global_position = Vector3(9000.0, 0.0, 9000.0)
	for i in MODELOS.size():
		animais[MODELOS[i]] = _montar(MODELOS[i], Vector3(i * 3.0, 0.0, 0.0))
	var ave = _montar_ave(Vector3(0.0, 0.0, 6.0))

	# --- 1. NÃO ESTICA PARADO --------------------------------------------------------------
	for fps in [30, 60, 144, 240]:
		for chave in ["cachorro_malhado", "onca_pintada", "gato_preto"]:
			_conferir_banda(animais[chave]["an"], fps, 1.0, "%s de pé a %d qps" % [chave, fps])
			_conferir_banda(animais[chave]["an"], fps, 0.86, "%s abaixado a %d qps" % [chave, fps])
		_conferir_banda(ave, fps, 1.0, "a ave de pé a %d qps" % fps)

	# --- 3. O CLIPE ANDA NO CHÃO -------------------------------------------------------------
	var dt := 1.0 / 60.0
	print("ANIMAIS: passada de cada clipe (u/s do bicho com o clipe em 1x)")
	for chave in MODELOS:
		var an = animais[chave]["an"]
		_conferir(an.tem_clipe(), "%s não anda com o clipe do GLB" % chave)
		if not an.tem_clipe():
			continue
		if chave in SEM_PASSADA:
			continue
		_conferir(absf(an.passada - 1.0) > 0.01, "%s: a passada do clipe não foi medida (ficou em %.2f)" % [chave, an.passada])
		var devagar: float = an.passada * 0.8
		var depressa: float = an.passada * 1.6
		an.velocidade = devagar
		an._process(dt)
		var ritmo_devagar: float = an.animacao.speed_scale
		an.velocidade = depressa
		an._process(dt)
		var ritmo_depressa: float = an.animacao.speed_scale
		_conferir(absf(ritmo_devagar - 0.8) < 0.03 and absf(ritmo_depressa - 1.6) < 0.03,
			"%s: o clipe devia tocar a 0,8x e 1,6x em velocidade 0,8 e 1,6 da passada, e tocou a %.2f e %.2f" % [chave, ritmo_devagar, ritmo_depressa])
		an.velocidade = 0.0
		print("   %-18s %.2f u/s" % [chave, an.passada])
	# As velocidades que o jogo usa: no passo o pé acompanha o chão, e na corrida o clipe acelera
	# até onde pode (o que sobra é patinação, e é dito).
	var dados := _ler("res://data/bichos_de_casa.json")
	var especies: Dictionary = dados.get("especies", {})
	var u: float = 2.1 / 62.0
	var velocidades := {}
	for chave in MODELOS:
		if especies.has(chave):
			velocidades[chave] = [float(especies[chave].get("passo", 0.0)), float(especies[chave].get("corrida", 0.0))]
	velocidades["onca_pintada"] = [float(Criatura.ESPECIES["onca"]["passo"]) * u * Criatura.ESPREITA_PASSO, float(Criatura.ESPECIES["onca"]["passo"]) * u]
	velocidades["onca_preta"] = velocidades["onca_pintada"]
	velocidades["caititu"] = [float(Criatura.ESPECIES["caititu"]["passo"]) * u * 0.5, float(Criatura.ESPECIES["caititu"]["passo"]) * u]
	print("ANIMAIS: o pé em relação ao chão (passo / corrida), com a passada medida e o teto de %.0fx" % Animador.ACELERA_ATE)
	for chave in MODELOS:
		var an = animais[chave]["an"]
		if not an.tem_clipe() or chave in SEM_PASSADA or not velocidades.has(chave):
			continue
		var no_passo: float = minf(float(velocidades[chave][0]) / an.passada, Animador.ACELERA_ATE) / (float(velocidades[chave][0]) / an.passada)
		var na_corrida: float = minf(float(velocidades[chave][1]) / an.passada, Animador.ACELERA_ATE) / (float(velocidades[chave][1]) / an.passada)
		print("   %-18s passo %.2f u/s -> pé a %3.0f %%   corrida %.2f u/s -> pé a %3.0f %%" % [chave, velocidades[chave][0], no_passo * 100.0, velocidades[chave][1], na_corrida * 100.0])
		_conferir(no_passo >= PE_NO_PASSO, "%s anda a %.2f u/s e o clipe só acompanha %.0f %% do chão (o mínimo é %.0f %%): a pata escorrega" % [chave, velocidades[chave][0], no_passo * 100.0, PE_NO_PASSO * 100.0])
		_conferir(na_corrida >= PE_NA_CORRIDA, "%s corre a %.2f u/s e o clipe só acompanha %.0f %% do chão (o mínimo é %.0f %%)" % [chave, velocidades[chave][1], na_corrida * 100.0, PE_NA_CORRIDA * 100.0])

	# --- 4. O CLIPE É SAUDÁVEL -----------------------------------------------------------------
	print("ANIMAIS: saúde do clipe (pata mais alta e cabeça mais fora do lugar, em % da altura)")
	for chave in MODELOS:
		var an = animais[chave]["an"]
		if not an.tem_clipe():
			continue
		var saude: Dictionary
		if falsificar_clipe and chave in Animador.CLIPE_TORTO:
			saude = _saude_do_clipe_cru(chave)
		else:
			saude = _saude(an.animacao, an._esqueleto, an.pose, an._clipe)
		print("   %-18s pata %3.0f %%  cabeça %3.0f %%" % [chave, saude["pata"] * 100.0, saude["cabeca"] * 100.0])
		_conferir(saude["pata"] <= PATA_ATE, "o clipe de %s levanta a pata a %.0f %% da altura do bicho (o teto é %.0f %%)" % [chave, saude["pata"] * 100.0, PATA_ATE * 100.0])
		_conferir(saude["cabeca"] <= CABECA_ATE, "o clipe de %s tira a cabeça %.0f %% da altura do lugar (o teto é %.0f %%)" % [chave, saude["cabeca"] * 100.0, CABECA_ATE * 100.0])
	for chave in ["onca_pintada", "cachorro_caramelo"]:
		_conferir(animais[chave]["an"].clipe_recentrado(), "o clipe torto de %s não foi recentrado" % chave)

	# --- 4b. O PESCOÇO FICA FIRME ------------------------------------------------------------------
	print("ANIMAIS: a cabeça do clipe torto, depois do pescoço firme (em %% da altura, teto %.0f %%)" % (CABECA_FIRME * 100.0))
	for chave in ["onca_pintada", "cachorro_caramelo"]:
		var an = animais[chave]["an"]
		var saude_firme: Dictionary
		if falsificar_pescoco:
			saude_firme = _saude_do_clipe_cru(chave, true)
		else:
			saude_firme = _saude(an.animacao, an._esqueleto, an.pose, an._clipe)
		print("   %-18s cabeça %4.1f %%" % [chave, saude_firme["cabeca"] * 100.0])
		_conferir(saude_firme["cabeca"] <= CABECA_FIRME,
			"%s: a cabeça sai %.1f %% da altura do lugar no clipe pronto (o teto é %.0f %%): o ombro e o pescoço ainda balançam como perna e a frente empina" % [chave, saude_firme["cabeca"] * 100.0, CABECA_FIRME * 100.0])
	var clipe_do_cao: Animation = animais["cachorro_caramelo"]["an"].animacao.get_animation(animais["cachorro_caramelo"]["an"]._clipe)
	_conferir(clipe_do_cao.has_meta("pescoco_firme"), "o clipe do cão caramelo não teve o pescoço firmado")

	# --- 5. PERNA PARADA ---------------------------------------------------------------------------
	for chave in ["onca_preta", "cachorro_malhado"]:
		var an = animais[chave]["an"]
		_conferir(an.pernas_paradas() >= 1, "%s: o clipe deixa uma perna dura e nenhuma ganhou balanço" % chave)
		if an.pernas_paradas() >= 1:
			var viagem := _viagem_da_perna_parada(an)
			_conferir(viagem >= 0.05, "%s: a perna dura balança só %.1f %% da altura (devia passar de 5 %%)" % [chave, viagem * 100.0])

	# --- 5b. AS PATAS DA FRENTE DO CÃO ANDAM, EM CONTRATEMPO -----------------------------------------
	var cao = animais["cachorro_caramelo"]["an"]
	_conferir(cao.pernas_paradas() == 2, "cachorro_caramelo: as duas patas da frente deviam ser pernas duras com balanço do código (são %d)" % cao.pernas_paradas())
	if cao.pernas_paradas() == 2:
		var curso := _curso_das_pernas_paradas(cao)
		var altura_do_cao: float = curso["altura"]
		for z in curso["viagens"]:
			_conferir(float(z) / altura_do_cao >= PE_DA_FRENTE_ANDA,
				"cachorro_caramelo: a pata da frente anda só %.1f %% da altura por passo (o mínimo é %.0f %%)" % [float(z) / altura_do_cao * 100.0, PE_DA_FRENTE_ANDA * 100.0])
		var par: Array = curso["series"]
		var contratempo := _correlacao(par[0], par[1])
		_conferir(contratempo < -0.3, "cachorro_caramelo: as duas patas da frente andam juntas (correlação %.2f), e deviam alternar" % contratempo)
		cao.velocidade = 0.0
		for i in 120:
			cao.animacao.advance(dt)
			cao._process(dt)
		_conferir(cao._defasagem_viva < 0.01, "cachorro_caramelo: parado, a defasagem das patas da frente não se desfez (%.2f)" % cao._defasagem_viva)

	# --- 5c. O CORPO ACOMPANHA A RAMPA ---------------------------------------------------------------
	# O focinho sobe com o chão que sobe, desce com o que desce, e a inclinação tem teto.
	var BichoDeCasa = load("res://scripts/prototipo_3d/bicho_de_casa.gd")
	_conferir(BichoDeCasa.inclinacao_da_encosta(0.3, 0.0) < -0.2, "subindo a rampa o focinho não sobe (%.2f rad)" % BichoDeCasa.inclinacao_da_encosta(0.3, 0.0))
	_conferir(BichoDeCasa.inclinacao_da_encosta(0.0, 0.3) > 0.2, "descendo a rampa o focinho não desce (%.2f rad)" % BichoDeCasa.inclinacao_da_encosta(0.0, 0.3))
	_conferir(absf(BichoDeCasa.inclinacao_da_encosta(0.0, 0.0)) < 0.001, "no plano o corpo inclina")
	_conferir(absf(BichoDeCasa.inclinacao_da_encosta(5.0, 0.0)) <= BichoDeCasa.ENCOSTA_ATE + 0.001, "a inclinação da encosta não tem teto")
	for rampa in [-0.3, 0.3]:
		cao.velocidade = 0.0
		cao.inclinacao_do_chao = rampa
		for i in 90:
			cao._process(dt)
		_conferir(absf(cao.pose.rotation.x - rampa) < 0.03, "cachorro_caramelo: na rampa de %.2f rad o corpo inclinou %.2f rad" % [rampa, cao.pose.rotation.x])
	cao.inclinacao_do_chao = 0.0
	for i in 90:
		cao._process(dt)
	_conferir(absf(cao.pose.rotation.x) < 0.03, "cachorro_caramelo: de volta ao plano o corpo seguiu inclinado (%.2f rad)" % cao.pose.rotation.x)

	# --- 6. PARADO CONGELA NO QUADRO DE PÉ; O BOTE NÃO ESTICA --------------------------------------------
	for chave in ["cachorro_malhado", "onca_pintada", "gato_malhado", "porco"]:
		var an = animais[chave]["an"]
		an.velocidade = an.passada
		for i in 30:
			an.animacao.advance(dt)
			an._process(dt)
		an.velocidade = 0.0
		var parou := false
		for i in 240:
			an.animacao.advance(dt)
			an._process(dt)
			if an._parado_no_quadro:
				parou = true
				break
		_conferir(parou, "%s: parou de andar e o clipe não congelou em 4 s" % chave)
		if parou and not an._quadros_de_pe.is_empty():
			var onde: float = an.animacao.current_animation_position
			var perto := INF
			for q in an._quadros_de_pe:
				perto = minf(perto, absf(onde - q))
			_conferir(perto < 0.03, "%s: congelou em %.2f s, longe de qualquer quadro de pé %s" % [chave, onde, str(an._quadros_de_pe)])
		_conferir(not an._quadros_de_pe.is_empty(), "%s: o clipe não tem quadro de pé conhecido" % chave)
	var forma_maxima := Vector3.ZERO
	var forma_minima := Vector3.ZERO
	for k in 101:
		var forma: Vector3 = Animador._forma_do_bote(k / 100.0)
		forma_maxima = Vector3(maxf(forma_maxima.x, forma.x), maxf(forma_maxima.y, forma.y), maxf(forma_maxima.z, forma.z))
		forma_minima = Vector3(minf(forma_minima.x, forma.x), minf(forma_minima.y, forma.y), minf(forma_minima.z, forma.z))
	_conferir(forma_maxima.y > 0.2, "o bote não pula (sobe só %.2f u)" % forma_maxima.y)
	_conferir(forma_minima.z < -0.2 and forma_maxima.z > 0.2, "o bote não empina nem mergulha o focinho (de %.2f a %.2f rad)" % [forma_minima.z, forma_maxima.z])
	_conferir(forma_maxima.x <= 0.25 and forma_minima.x >= 0.0, "o bote abaixa o corpo mais de 25 %% (%.2f)" % forma_maxima.x)
	var onca = animais["onca_pintada"]["an"]
	var altura_minima := 10.0
	var altura_maxima := 0.0
	for k in 120:
		onca.bote(minf(k / 100.0, 1.0))
		onca._process(dt)
		altura_minima = minf(altura_minima, onca.pose.scale.y)
		altura_maxima = maxf(altura_maxima, onca.pose.scale.y)
	onca.bote(-1.0)
	for k in 60:
		onca._process(dt)
	_conferir(altura_minima > 0.75 and altura_maxima < 1.05, "o bote estica ou achata o corpo: a escala vai de %.2f a %.2f" % [altura_minima, altura_maxima])
	_conferir(absf(onca.pose.scale.y - 1.0) < 0.05 and absf(onca.pose.position.y) < 0.01 and absf(onca.pose.rotation.x) < 0.02,
		"depois do bote o corpo não voltou ao normal: escala %.2f, altura %.2f, cabeceio %.2f" % [onca.pose.scale.y, onca.pose.position.y, onca.pose.rotation.x])

	# --- 7. A CABRA DE CENA ANDA COM O CLIPE ---------------------------------------------------------------
	var cabra = CabraDeCena.new()
	arena.add_child(cabra)
	cabra.position = Vector3(0.0, 0.0, 12.0)
	var cabra_an = cabra.animador()
	_conferir(cabra_an != null and cabra_an.tem_clipe(), "a cabra de cena não tem o clipe de andar (é a malha parada do adereço?)")
	if cabra_an != null and cabra_an.tem_clipe():
		cabra.andar(2.4)
		cabra_an._process(dt)
		_conferir(cabra.andando() and cabra_an.animacao.is_playing() and cabra_an.animacao.speed_scale > 0.3,
			"a cabra anda e o clipe não toca (tocando %s, ritmo %.2f)" % [str(cabra_an.animacao.is_playing()), cabra_an.animacao.speed_scale])
		_conferir(absf(cabra_an.animacao.speed_scale - clampf(2.4 / cabra_an.passada, Animador.ACELERA_DE, Animador.ACELERA_ATE)) < 0.03,
			"o clipe da cabra não acompanha o chão: ritmo %.2f para 2,4 u/s e passada %.2f" % [cabra_an.animacao.speed_scale, cabra_an.passada])
		cabra.parar()
		var cabra_parou := false
		for i in 240:
			cabra_an.animacao.advance(dt)
			cabra_an._process(dt)
			if cabra_an._parado_no_quadro:
				cabra_parou = true
				break
		_conferir(cabra_parou and not cabra_an.animacao.is_playing(), "a cabra parou e o clipe seguiu tocando")
	_conferir(not (cabra_an != null and cabra_an.pose.get_child_count() == 0), "a cabra de cena não vestiu corpo nenhum")

	# --- 2. NADA SE MEXE COM O JOGO PAUSADO ---------------------------------------------------------------
	# Agora com a árvore andando de verdade: os bichos andam por 20 quadros, o jogo pausa, e nada muda.
	for chave in MODELOS:
		var an = animais[chave]["an"]
		an.velocidade = maxf(an.passada, 0.3)
	ave.velocidade = 0.0
	await _frames(20)
	var relogio_do_nado_antes: float = Cardume._relogio_do_nado
	_conferir(relogio_do_nado_antes > 0.0, "o relógio do nado dos peixes não anda com o jogo rodando")
	var antes := _fotografar()
	paused = true
	await _frames(30)
	var na_pausa := _fotografar()
	var relogio_do_nado_na_pausa: float = Cardume._relogio_do_nado
	paused = false
	for chave in antes:
		_conferir(antes[chave] == na_pausa[chave], "%s se mexeu com o jogo pausado: %s -> %s" % [chave, str(antes[chave]), str(na_pausa[chave])])
	_conferir(is_equal_approx(relogio_do_nado_antes, relogio_do_nado_na_pausa),
		"o relógio do nado dos peixes andou com o jogo pausado (%.3f -> %.3f)" % [relogio_do_nado_antes, relogio_do_nado_na_pausa])
	await _frames(20)
	var depois := _fotografar()
	var mexeu := false
	for chave in antes:
		mexeu = mexeu or antes[chave] != depois[chave]
	_conferir(mexeu, "com o jogo andando de novo os bichos continuaram parados (o portão não está medindo nada)")
	_conferir(Cardume._relogio_do_nado > relogio_do_nado_na_pausa, "o relógio do nado não voltou a andar depois da pausa")
	for caminho in ["res://assets/prototipo_3d/fauna/nado.gdshader", "res://assets/prototipo_3d/fauna/raia_voo.gdshader", "res://assets/prototipo_3d/fauna/silhueta_rio.gdshader"]:
		var texto := FileAccess.get_file_as_string(caminho)
		var regex := RegEx.create_from_string("\\bTIME\\b")
		var linhas_com_time: Array[String] = []
		for linha in texto.split("\n"):
			if not linha.strip_edges().begins_with("//") and regex.search(linha) != null:
				linhas_com_time.append(linha)
		_conferir(linhas_com_time.is_empty(), "%s usa o TIME do motor, que não pausa: %s" % [caminho.get_file(), str(linhas_com_time)])
		_conferir("uniform float tempo" in texto, "%s não declara o relógio do nado (uniform float tempo)" % caminho.get_file())
	var material_conferido := false
	for corpo: Dictionary in Cardume._corpos.values():
		var material := corpo.get("material") as ShaderMaterial
		if material != null:
			var tempo = material.get_shader_parameter("tempo")
			_conferir(tempo != null and absf(float(tempo) - Cardume._relogio_do_nado) < 1.0, "o material de um cardume não recebe o relógio do nado (tempo %s)" % str(tempo))
			material_conferido = true
			break
	_conferir(material_conferido, "não há material de peixe montado para conferir")

	arena.queue_free()
	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("ANIMAIS_ANIMACAO_OK: parado o bicho respira sem esticar (a escala não muda e só o focinho sobe 0,7° a 30, 60, 144 e 240 qps, de pé e abaixado), com o jogo pausado nada se mexe (nem o osso, nem o clipe, nem o nado dos peixes), o clipe toca no ritmo do chão e a pata acompanha o corpo, os 14 clipes são saudáveis (o da onça pintada e o do cão caramelo, recentrados e de pescoço firme, a frente sem empinar), a perna dura da onça preta e do cão malhado balança, as patas da frente do cão alternam, o corpo acompanha a rampa, parado ele congela no quadro de pé, o bote pula sem esticar e a cabra de cena anda com o clipe")
	else:
		print("animais_animacao: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


# --- montagem ----------------------------------------------------------------------------------------

## Um quadrúpede de verdade, montado como o jogo monta: a pose, o GLB do catálogo e o
## animador, no mesmo nó do vale.
func _montar(chave: String, onde: Vector3) -> Dictionary:
	var pose := Node3D.new()
	pose.name = "Pose_" + chave
	arena.add_child(pose)
	pose.position = onde
	var modelo = Animador.vestir(chave, pose, Vector3(0.3, 0.5, 0.9), Color.WHITE)
	var an = Animador.new()
	an.name = "Animador_" + chave
	arena.add_child(an)
	an.configurar(pose, modelo, false, chave, 1.0)
	return {"pose": pose, "modelo": modelo, "an": an}


func _montar_ave(onde: Vector3):
	var pose := Node3D.new()
	pose.name = "Pose_ave"
	arena.add_child(pose)
	pose.position = onde
	var corpo = Animador.vestir("galinha", pose, Vector3(0.2, 0.42, 0.38), Color("c9a87c"))
	var an = Animador.new()
	an.name = "Animador_ave"
	arena.add_child(an)
	an.configurar(pose, corpo, true, "galinha", 0.6)
	return an


# --- as perguntas -------------------------------------------------------------------------------------------

## 600 quadros parado a `fps`: a escala não respira (a vertical fica na altura que o bicho
## persegue, a horizontal em 1), o focinho só sobe até `RESPIRA`, o olhar de lado não passa
## do limite e o corpo sobe no máximo a alavanca do focinho.
func _conferir_banda(an, fps: int, altura: float, rotulo: String) -> void:
	an.velocidade = 0.0
	an.altura_alvo = altura
	an._altura = altura
	an._bote = -1.0
	var dt := 1.0 / float(fps)
	var minimo := INF
	var maximo := -INF
	var largura_minima := INF
	var largura_maxima := -INF
	var maior_giro := 0.0
	var maior_altura := 0.0
	var focinho_sobe := 0.0
	var focinho_desce := 0.0
	var feedback := 1.0
	for i in 600:
		an._process(dt)
		if falsificar_respiro:
			# A realimentação de antes: a escala do quadro anterior, já com o fôlego dentro, é
			# a base do seguinte (a altura persegue o alvo só `6 × dt` por quadro).
			var base := lerpf(feedback, altura, minf(1.0, dt * 6.0))
			feedback = base * (1.0 + sin(an._tempo * an.RITMO_DA_RESPIRACAO + an._fase) * RESPIRA_ANTIGA)
			an.pose.scale.y = feedback
		minimo = minf(minimo, an.pose.scale.y)
		maximo = maxf(maximo, an.pose.scale.y)
		largura_minima = minf(largura_minima, an.pose.scale.x)
		largura_maxima = maxf(largura_maxima, an.pose.scale.x)
		focinho_sobe = maxf(focinho_sobe, -an.pose.rotation.x)
		focinho_desce = maxf(focinho_desce, an.pose.rotation.x)
		maior_giro = maxf(maior_giro, absf(an.pose.rotation.y))
		maior_altura = maxf(maior_altura, absf(an.pose.position.y))
	_conferir(minimo >= altura - 0.001 and maximo <= altura + 0.001,
		"%s: a altura foi de %.4f a %.4f (devia ficar em %.3f, sem escala de respiração): o corpo estica" % [rotulo, minimo, maximo, altura])
	_conferir(largura_minima >= 0.999 and largura_maxima <= 1.001,
		"%s: a largura foi de %.4f a %.4f (devia ficar em 1): o corpo alarga" % [rotulo, largura_minima, largura_maxima])
	_conferir(focinho_sobe <= an.RESPIRA + 0.001 and focinho_desce <= 0.001,
		"%s: o focinho subiu %.4f rad e desceu %.4f (a respiração só ergue até %.4f)" % [rotulo, focinho_sobe, focinho_desce, an.RESPIRA])
	_conferir(focinho_sobe > an.RESPIRA * 0.5 or falsificar_respiro, "%s: o bicho parado não respira (o focinho subiu só %.4f rad)" % [rotulo, focinho_sobe])
	_conferir(maior_giro <= an.OLHA_ATE + 0.02, "%s: o olhar de lado passou do limite (%.2f rad)" % [rotulo, maior_giro])
	_conferir(maior_altura < 0.01, "%s: o corpo parado subiu e desceu %.3f u" % [rotulo, maior_altura])
	an.altura_alvo = 1.0
	an._altura = 1.0


## A saúde de um clipe: a pata mais alta (acima do repouso) e a cabeça mais fora do lugar,
## em fração da altura do esqueleto, nas 49 poses do ciclo.
func _saude(tocador: AnimationPlayer, esqueleto: Skeleton3D, referencia_no: Node3D, nome_do_clipe: String) -> Dictionary:
	var para_o_bicho := referencia_no.global_transform.affine_inverse() * esqueleto.global_transform
	var altura := -INF
	var baixo := INF
	for i in esqueleto.get_bone_count():
		var y := (para_o_bicho * esqueleto.get_bone_global_rest(i).origin).y
		altura = maxf(altura, y)
		baixo = minf(baixo, y)
	altura -= baixo
	var pes: Array[int] = Animador.achar_os_pes(esqueleto, para_o_bicho)
	var cabeca := -1
	for i in esqueleto.get_bone_count():
		var nome := esqueleto.get_bone_name(i).to_lower()
		if "head" in nome and (cabeca < 0 or nome.ends_with("head_0")):
			cabeca = i
	var clipe := tocador.get_animation(nome_do_clipe)
	var pata := 0.0
	var fora := 0.0
	tocador.play(nome_do_clipe)
	for k in 49:
		tocador.seek(k * clipe.length / 48.0, true)
		for pe in pes:
			var repouso := (para_o_bicho * esqueleto.get_bone_global_rest(pe).origin).y
			pata = maxf(pata, ((para_o_bicho * esqueleto.get_bone_global_pose(pe).origin).y - repouso) / altura)
		if cabeca >= 0:
			fora = maxf(fora, (para_o_bicho * esqueleto.get_bone_global_pose(cabeca).origin).distance_to(para_o_bicho * esqueleto.get_bone_global_rest(cabeca).origin) / altura)
	tocador.pause()
	tocador.seek(0.0, true)
	return {"pata": pata, "cabeca": fora}


## O clipe CRU: o GLB recarregado sem cache (as trilhas como vieram do Tripo, sem o recentro),
## para a falsificação mostrar o que o portão pega. Com `recentrar_sem_pescoco` ele é recentrado, mas
## sem firmar o pescoço (o estado de antes da #149).
func _saude_do_clipe_cru(chave: String, recentrar_sem_pescoco: bool = false) -> Dictionary:
	var caminho: String = "res://assets/prototipo_3d/" + str(_pecas()[chave]["tripo"])
	var cena := ResourceLoader.load(caminho, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
	var no := cena.instantiate() as Node3D
	arena.add_child(no)
	var esqueleto := no.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var tocador := no.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var nome := ""
	for n in tocador.get_animation_list():
		if "walk" in String(n).to_lower():
			nome = String(n)
	if recentrar_sem_pescoco:
		Animador.recentrar_o_clipe(tocador.get_animation(nome), esqueleto, Animador.TETO_DO_DESVIO, false)
	var saude := _saude(tocador, esqueleto, no, nome)
	no.queue_free()
	return saude


func _pecas() -> Dictionary:
	return load("res://scripts/prototipo_3d/catalogo_assets.gd").PECAS


## Quanto a perna parada balança (fração da altura do bicho), com o animador rodando: o pé
## dela, em Z, nas 25 poses do ciclo.
func _viagem_da_perna_parada(an) -> float:
	var esqueleto: Skeleton3D = an._esqueleto
	var para_o_bicho: Transform3D = an.pose.global_transform.affine_inverse() * esqueleto.global_transform
	var pes: Array[int] = Animador.achar_os_pes(esqueleto, para_o_bicho)
	var topo: int = an._paradas[0]["pares"][0]["osso"]
	var pe := -1
	for candidato in pes:
		if Animador.cadeia_da_perna(esqueleto, candidato, pes).back() == topo:
			pe = candidato
	if pe < 0:
		return 0.0
	var altura := -INF
	var baixo := INF
	for i in esqueleto.get_bone_count():
		var y := (para_o_bicho * esqueleto.get_bone_global_rest(i).origin).y
		altura = maxf(altura, y)
		baixo = minf(baixo, y)
	altura -= baixo
	an.velocidade = maxf(an.passada, 0.3)
	var minimo := INF
	var maximo := -INF
	var clipe: Animation = an.animacao.get_animation(an._clipe)
	for k in 25:
		an.animacao.play(an._clipe)
		an.animacao.seek(k * clipe.length / 24.0, true)
		an._process(0.0)
		var z := (para_o_bicho * esqueleto.get_bone_global_pose(pe).origin).z
		minimo = minf(minimo, z)
		maximo = maxf(maximo, z)
	an.velocidade = 0.0
	return (maximo - minimo) / altura


## O curso do pé de cada perna parada, com o animador rodando: o Z do pé em 25 poses do ciclo
## (`series`), quanto ele percorre (`viagens`) e a altura do esqueleto.
func _curso_das_pernas_paradas(an) -> Dictionary:
	var esqueleto: Skeleton3D = an._esqueleto
	var para_o_bicho: Transform3D = an.pose.global_transform.affine_inverse() * esqueleto.global_transform
	var pes: Array[int] = Animador.achar_os_pes(esqueleto, para_o_bicho)
	var altura := -INF
	var baixo := INF
	for i in esqueleto.get_bone_count():
		var y := (para_o_bicho * esqueleto.get_bone_global_rest(i).origin).y
		altura = maxf(altura, y)
		baixo = minf(baixo, y)
	altura -= baixo
	var series: Array = []
	var viagens: Array = []
	var clipe: Animation = an.animacao.get_animation(an._clipe)
	an.velocidade = maxf(an.passada, 0.3)
	for perna in an._paradas:
		var topo: int = perna["pares"][0]["osso"]
		var pe := -1
		for candidato in pes:
			if Animador.cadeia_da_perna(esqueleto, candidato, pes).back() == topo:
				pe = candidato
		var zs: Array = []
		if pe >= 0:
			for k in 25:
				an.animacao.play(an._clipe)
				an.animacao.seek(k * clipe.length / 24.0, true)
				an._process(0.0)
				zs.append((para_o_bicho * esqueleto.get_bone_global_pose(pe).origin).z)
		series.append(zs)
		viagens.append((zs.max() - zs.min()) if not zs.is_empty() else 0.0)
	an.velocidade = 0.0
	return {"series": series, "viagens": viagens, "altura": altura}


## Correlação de Pearson de duas séries do mesmo tamanho (0 se alguma é constante).
func _correlacao(a: Array, b: Array) -> float:
	var n := mini(a.size(), b.size())
	if n < 2:
		return 0.0
	var ma := 0.0
	var mb := 0.0
	for i in n:
		ma += float(a[i]) / n
		mb += float(b[i]) / n
	var sab := 0.0
	var saa := 0.0
	var sbb := 0.0
	for i in n:
		sab += (float(a[i]) - ma) * (float(b[i]) - mb)
		saa += (float(a[i]) - ma) * (float(a[i]) - ma)
		sbb += (float(b[i]) - mb) * (float(b[i]) - mb)
	if saa < 0.0000001 or sbb < 0.0000001:
		return 0.0
	return sab / sqrt(saa * sbb)


## O estado de cada bicho, para comparar antes e durante a pausa: pose, posição do clipe e
## a rotação de alguns ossos.
func _fotografar() -> Dictionary:
	var fotos := {}
	for chave in animais:
		var an = animais[chave]["an"]
		var ossos := []
		if an._esqueleto != null:
			for i in range(0, an._esqueleto.get_bone_count(), 4):
				ossos.append(an._esqueleto.get_bone_pose_rotation(i))
		fotos[chave] = [an.pose.position, an.pose.rotation, an.pose.scale,
			an.animacao.current_animation_position if an.animacao != null else -1.0, ossos]
	return fotos


# --- infraestrutura ----------------------------------------------------------------------------------------

func _ler(caminho: String) -> Dictionary:
	var arquivo := FileAccess.open(caminho, FileAccess.READ)
	if arquivo == null:
		return {}
	var lido = JSON.parse_string(arquivo.get_as_text())
	return lido if lido is Dictionary else {}


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
