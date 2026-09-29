extends SceneTree
## Confere que o CALENDÁRIO do jogo 2D chegou ao vale, e que ele não brigou
## com o relógio que já estava aqui.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/calendario.gd
##
## Este é o ponto em que os dois projetos se sobrepunham: o `Dia` conta hora, e
## o `Relogio` do 2D também. A saída não foi escolher um — foi dividir o
## assunto. O `Dia` continua dono da HORA, porque é ele que o céu, as luzes de
## 1887, o som e a tela de carregamento consultam. O `Relogio` entra como
## CALENDÁRIO, que é o que o vale não tinha: dia, estação, ano.
##
## E não foi preciso mudar uma linha do `Relogio` para isso. Ele já tinha a
## porta — o `pausado` —, e o `Dia` a usa.
##
## Cinco perguntas:
##
##   1. OS DOIS ESTÃO DE PÉ, e o `Efeitos`, que depende do calendário, também.
##   2. O CALENDÁRIO NÃO CONTA HORA SOZINHO. Se os dois andarem, eles divergem,
##      e a divergência aparece semanas depois como "a planta cresceu no dia
##      errado".
##   3. OS DOIS CONCORDAM NA HORA. Mudar a hora no `Dia` muda a do `Relogio`.
##   4. O CALENDÁRIO EXISTE: dia, estação, ano e dia absoluto respondem, com os
##      números do 2D — 28 dias por estação, quatro estações.
##   5. O DIA VIRA QUANDO MANDAM, e não sozinho. No 2D quem manda é a cama; o
##      vale ainda não tem uma, e é por isso que este teste chama `dormir()` na
##      mão em vez de esperar.

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("CALENDARIO_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	# --- 1. DE PÉ -------------------------------------------------------------
	var dia_3d := root.get_node_or_null("/root/Dia")
	var relogio := root.get_node_or_null("/root/Relogio")
	var efeitos := root.get_node_or_null("/root/Efeitos")
	_conferir(dia_3d != null, "o autoload Dia não subiu")
	_conferir(relogio != null, "o autoload Relogio não subiu")
	_conferir(efeitos != null, "o autoload Efeitos não subiu")
	if dia_3d == null or relogio == null or efeitos == null:
		_fechar()
		return

	# --- 2. O CALENDÁRIO NÃO CONTA HORA SOZINHO -------------------------------
	#
	# O `Dia` fica PARADO para esta pergunta, e a razão é a lição que a primeira
	# versão deste teste aprendeu apanhando: com ele andando, o calendário
	# também anda — porque espelha —, e a medida não distingue "espelhou
	# direito" de "contou sozinho", que é exatamente o defeito procurado. Com o
	# `Dia` parado, qualquer movimento no calendário só pode ter vindo do
	# `_process` dele.
	dia_3d.pausado = true
	dia_3d.definir_hora(9.0)
	await process_frame
	_conferir(relogio.pausado,
		"o calendário não está pausado: os dois relógios vão andar e divergir")

	var antes: float = relogio.minutos
	for i in 30:
		await process_frame
	_conferir(relogio.minutos == antes,
		"o calendário andou sozinho com o Dia parado: de %s para %s em 30 quadros"
			% [str(antes), str(relogio.minutos)])

	# --- 3. OS DOIS CONCORDAM NA HORA -----------------------------------------
	for hora_teste in [0.0, 6.0, 13.5, 23.0]:
		dia_3d.definir_hora(hora_teste)
		await process_frame
		_conferir(is_equal_approx(relogio.minutos, hora_teste * 60.0),
			"pus o Dia em %sh e o calendário marcou %s minutos" % [str(hora_teste), str(relogio.minutos)])
		_conferir(relogio.hora() == int(hora_teste),
			"o calendário diz %dh e o Dia está em %sh" % [relogio.hora(), str(hora_teste)])

	# --- 4. O CALENDÁRIO EXISTE, com os números do 2D -------------------------
	_conferir(relogio.DIAS_POR_ESTACAO == 28,
		"a estação não tem 28 dias: %d" % relogio.DIAS_POR_ESTACAO)
	_conferir(relogio.NOMES_ESTACAO.size() == 4,
		"não são quatro estações: %d" % relogio.NOMES_ESTACAO.size())
	_conferir(relogio.dia >= 1, "o dia começou em %d" % relogio.dia)
	_conferir(relogio.ano >= 1, "o ano começou em %d" % relogio.ano)
	_conferir(relogio.dia_absoluto() >= 1,
		"o dia absoluto deu %d" % relogio.dia_absoluto())
	_conferir(relogio.nome_estacao() != "", "a estação não tem nome")

	# --- 5. O DIA VIRA QUANDO MANDAM ------------------------------------------
	var dia_antes: int = relogio.dia
	var absoluto_antes: int = relogio.dia_absoluto()
	relogio.dormir()
	await process_frame
	_conferir(relogio.dia_absoluto() == absoluto_antes + 1,
		"dormir avançou o dia absoluto de %d para %d" % [absoluto_antes, relogio.dia_absoluto()])
	_conferir(relogio.dia != dia_antes or relogio.dia == 1,
		"dormir não mexeu no dia: %d" % relogio.dia)

	# E O EFEITO CONTA EM DIAS, que é o que o calendário veio destravar. Um
	# efeito de dois dias tem de vencer depois de duas noites, e não antes.
	efeitos.conceder("portao_do_calendario", "Conferência", "eficiencia", 0.0, 2)
	_conferir(efeitos.dias_restantes("portao_do_calendario") == 2,
		"o efeito de 2 dias nasceu com %d" % efeitos.dias_restantes("portao_do_calendario"))
	relogio.dormir()
	await process_frame
	_conferir(efeitos.dias_restantes("portao_do_calendario") == 1,
		"depois de uma noite, o efeito tem %d dia(s)" % efeitos.dias_restantes("portao_do_calendario"))
	relogio.dormir()
	await process_frame
	_conferir(not efeitos.ativos.has("portao_do_calendario"),
		"o efeito de dois dias sobreviveu a duas noites")

	# O `Dia` não pode ter perdido a hora dele no meio disso: `dormir()` mexe no
	# calendário, e o dono da hora continua sendo o outro.
	_conferir(dia_3d.hora >= 0.0 and dia_3d.hora < 24.0,
		"a hora do vale saiu da faixa: %s" % str(dia_3d.hora))

	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("CALENDARIO_OK: o Dia manda na hora, o Relogio entra como calendário sem andar sozinho, os dois concordam, e o efeito conta em dias de verdade")
	else:
		print("calendário: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)
