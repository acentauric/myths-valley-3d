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
##      A única exceção é a QUEDA (`queda.gd`, #10): cair é a mesma noite do
##      desmaio, e ela chama `Energia.desmaiar()` como o `_apagar` do 2D. Isso
##      devolve fôlego, não gasta — e só ela pode.

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

	# --- 4. NADA GASTA AINDA, DE PROPÓSITO ------------------------------------
	#
	# Se um dia alguém ligar uma ação ao fôlego no vale, esta pergunta reprova
	# — e é para reprovar mesmo. O recado é: apague esta parte, e escreva em
	# lugar dela o portão do que passou a gastar.
	var gasta := false
	var desmaia_fora_da_queda := false
	# Chamada é linha de CÓDIGO: comentário que cita a função (e a queda.gd cita)
	# não pode contar como chamada, nem para acusar nem para absolver.
	var desmaia := RegEx.create_from_string("(?m)^[ \\t]+[^#\\n]*Energia\\.desmaiar\\(")
	for arquivo in _scripts_do_prototipo():
		var texto := FileAccess.get_file_as_string(arquivo)
		if texto.contains("Energia.gastar(") or texto.contains("Energia.dormir("):
			gasta = true
			print("  (gasta fôlego: %s)" % arquivo)
		if desmaia.search(texto) != null and not arquivo.ends_with("/queda.gd"):
			desmaia_fora_da_queda = true
			print("  (desmaia fora da queda: %s)" % arquivo)
	_conferir(not gasta,
		"alguma coisa no vale passou a gastar fôlego: troque esta pergunta pelo portão do que gasta")
	_conferir(not desmaia_fora_da_queda,
		"Energia.desmaiar() fora do queda.gd: o vale ganhou outra noite no chão, e ela precisa do portão dela")
	var queda := FileAccess.get_file_as_string("res://scripts/prototipo_3d/queda.gd")
	_conferir(desmaia.search(queda) != null,
		"a queda não chama Energia.desmaiar(): cair deixou de ser a mesma noite do desmaio do 2D")

	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("FOLEGO_OK: Progressao e Energia subiram com os números do 2D, o cansaço encurta o passo para 62% e o corpo lê isso; nada gasta fôlego ainda, porque o vale não tem trabalho")
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
