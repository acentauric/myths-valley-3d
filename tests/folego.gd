extends SceneTree
## Confere que o FÔLEGO do jogo 2D chegou ao vale, e que ele pesa no corpo.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/folego.gd
##
## `Progressao` e `Energia` não são código escrito para o 3D: são os mesmos
## arquivos do jogo 2D, em `scripts/compartilhado/`, conferidos byte a byte
## pelo `testar_compartilhado` do outro projeto. Eles atravessaram porque não
## sabem o que é um tile — e este teste existe para que continuem assim.
##
## Quatro perguntas:
##
##   1. OS DOIS SUBIRAM, e com os números do 2D. Autoload que falha ao carregar
##      não derruba o jogo no Godot: ele some, e quem o chama é que estoura,
##      três telas adiante.
##   2. A REGRA DO CANSAÇO É A DO 2D: abaixo de um quinto do fôlego o passo cai
##      para 62%, e não para outro número inventado aqui.
##   3. O CORPO SENTE. O `player_controller` multiplica a velocidade pelo
##      `Energia.passo()` — lido do fonte, porque medir velocidade de um corpo
##      que anda por física dá um teste que falha por pouco em máquina lenta.
##   4. NADA GASTA FÔLEGO AINDA, e isso é de propósito. No 2D quem cobra é a
##      enxada, o machado e a picareta, e o vale não tem trabalho. O dia em que
##      tiver, esta pergunta é a que vai avisar que ela precisa mudar.

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("FOLEGO_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	# --- 1. OS DOIS SUBIRAM ---------------------------------------------------
	var progressao := root.get_node_or_null("/root/Progressao")
	var energia := root.get_node_or_null("/root/Energia")
	_conferir(progressao != null, "o autoload Progressao não subiu")
	_conferir(energia != null, "o autoload Energia não subiu")
	if progressao == null or energia == null:
		_fechar()
		return

	_conferir(progressao.ENERGIA_MAXIMA_INICIAL == 100.0,
		"o teto de fôlego não é o do 2D: %s" % str(progressao.ENERGIA_MAXIMA_INICIAL))
	_conferir(progressao.RECUPERACAO_INICIAL == 40.0,
		"o que o sono devolve não é o do 2D: %s" % str(progressao.RECUPERACAO_INICIAL))
	_conferir(energia.atual == progressao.ENERGIA_MAXIMA_INICIAL,
		"o vale não começa com o fôlego cheio: %s" % str(energia.atual))

	# --- 2. A REGRA DO CANSAÇO É A DO 2D --------------------------------------
	_conferir(energia.LIMIAR_DE_CANSACO == 0.2,
		"o limiar do cansaço mudou: %s" % str(energia.LIMIAR_DE_CANSACO))
	_conferir(energia.PESO_DO_CANSACO == 0.62,
		"o peso do cansaço mudou: %s" % str(energia.PESO_DO_CANSACO))

	_conferir(not energia.cansado(), "de fôlego cheio, o corpo já estava cansado")
	_conferir(energia.passo() == 1.0, "de fôlego cheio, o passo não é inteiro")

	# Um décimo do teto: abaixo do limiar, e o passo tem de encurtar.
	energia.atual = progressao.ENERGIA_MAXIMA_INICIAL * 0.1
	_conferir(energia.cansado(), "com 10% do fôlego, o corpo não se deu por cansado")
	_conferir(is_equal_approx(energia.passo(), energia.PESO_DO_CANSACO),
		"cansado, o passo é %s e devia ser %s" % [str(energia.passo()), str(energia.PESO_DO_CANSACO)])

	energia.encher()
	_conferir(energia.atual == energia.maximo(), "encher() não encheu")

	# --- 3. O CORPO SENTE -----------------------------------------------------
	var fonte := FileAccess.get_file_as_string("res://scripts/prototipo_3d/player_controller.gd")
	_conferir(fonte != "", "não consegui ler o player_controller")
	_conferir(fonte.contains("speed *= Energia.passo()"),
		"o controle do jogador não multiplica a velocidade pelo passo do Energia: o cansaço não chega ao corpo")

	# --- 4. AGORA ALGUMA COISA GASTA, E ISSO É O CERTO ------------------------
	#
	# A versão anterior desta pergunta cobrava o CONTRÁRIO: que nada no vale
	# gastasse fôlego, porque não havia trabalho aqui. Ela dizia, no próprio
	# comentário, que reprovaria no dia em que alguém ligasse uma ação — e
	# reprovou, quando os troncos e os lajedos chegaram.
	#
	# O recado que ela deixou era "troque esta pergunta pelo portão do que
	# gasta", e é o que está feito: quem mede o golpe agora é
	# `tests/ferramentas.gd`, que bate de verdade e confere que o fôlego caiu.
	#
	# O que sobra aqui é a outra metade, e ela continua valendo: o fôlego só
	# pode ser gasto por quem o jogo declara. Uma chamada a `Energia.gastar`
	# que apareça fora dos recursos é ação nova sem portão, e é isso que esta
	# pergunta passa a pegar.
	var quem_gasta: Array[String] = []
	for arquivo in _scripts_do_prototipo():
		var texto := FileAccess.get_file_as_string(arquivo)
		if texto.contains("Energia.gastar(") or texto.contains("Energia.dormir(") \
				or texto.contains("Energia.desmaiar("):
			quem_gasta.append(arquivo.get_file())
	_conferir(quem_gasta.has("recursos_3d.gd"),
		"o trabalho parou de gastar fôlego: bater tem de custar, e é o que faz a ferramenta valer")
	for arquivo in quem_gasta:
		_conferir(arquivo == "recursos_3d.gd",
			"'%s' passou a gastar fôlego e não tem portão: escreva o dele, como o ferramentas.gd fez"
				% arquivo)

	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("FOLEGO_OK: Progressao e Energia subiram com os números do 2D, o cansaço encurta o passo para 62%, o corpo lê isso, e só o trabalho gasta fôlego — quem mede o golpe é o tests/ferramentas.gd")
	else:
		print("folego: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


## Todo `.gd` do protótipo, menos os compartilhados (que são do 2D) e os
## próprios testes.
func _scripts_do_prototipo() -> Array:
	var achados := []
	var pastas := ["res://scripts/prototipo_3d", "res://scripts/autoload"]
	for pasta in pastas:
		var dir := DirAccess.open(pasta)
		if dir == null:
			continue
		for nome in dir.get_files():
			if nome.ends_with(".gd"):
				achados.append(pasta + "/" + nome)
	return achados
