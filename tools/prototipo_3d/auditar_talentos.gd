extends SceneTree
## Portado do 2D, SHA 62c0f14b, tools/gdscript/testar_talentos.gd (#18).
## Confere que TODO TALENTO FAZ ALGUMA COISA.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/prototipo_3d/auditar_talentos.gd
## Auditoria estrita fora da bateria: dependências ainda faltantes mantêm saída 1.
##
## O defeito que este teste existe para pegar não dá erro, não dá aviso e é
## caro para quem joga: o nó está na árvore, tem nome, tem resumo prometendo
## uma coisa, cobra ponto, risca na tela quando é destravado — e o campo que
## ele concede não é lido por ninguém.
##
## Foram OITO assim, achados numa varredura em setembro: vendeiro que pagaria
## 10% a mais, compra 10% mais barata, favor pela metade, folheto que se veria
## de mais longe, oito por cento de passo, sobrado sem varanda, curral. Todos
## escritos, nenhum ligado. Ponto de ofício é o recurso mais escasso do começo
## do jogo, e gastá-lo num número que não existe é o pior tipo de mentira que
## um jogo pode contar.
##
## São três conferências:
##
##   1. Todo campo de efeito da árvore de talentos e das três fés é CONSUMIDO
##      em algum lugar — por `Talentos.bonus(campo)`, por `Fe.bonus(campo)` ou
##      pelo `_aplicar` que escreve direto na Progressao.
##   2. Todo nó tem nome, resumo e custo, e o resumo não é o nome repetido.
##   3. Todo `exige` aponta para um nó que existe, e ninguém exige a si mesmo.
##
## A LISTA DE ESPERA abaixo é a única saída, e ela é explícita de propósito:
## campo que ainda não tem mecânica entra aqui com a razão escrita, em vez de
## o teste ser afrouxado.

## Campos declarados que AINDA não têm mecânica, e por quê.
##
## Os dois são de combate, e não há combate no jogo. Os resumos dos nós dizem
## "Entra com o capítulo 7" ao jogador, que é a única forma honesta de vender
## um talento que ainda não faz nada — ele sabe o que está comprando.
##
## Quem ligar o combate tira os dois daqui, e o teste passa a cobrar.
const ESPERANDO_MECANICA := {
	# "forca" SAIU da espera em setembro de 2026: é o dano do golpe (ver Mundo._golpear).
	# "vigor" SAIU da espera em setembro de 2026: é o teto de vida (ver vida.gd).
}

var falhas := 0


func _initialize() -> void:
	call_deferred("executar")


func conferir(ok: bool, descricao: String) -> void:
	if not ok:
		push_error(descricao)
		print("FALHA: ", descricao)
		falhas += 1


func executar() -> void:
	var talentos := root.get_node("/root/Talentos")
	var fe := root.get_node("/root/Fe")

	# O código inteiro do jogo, para procurar quem lê cada campo. Lido uma vez:
	# são uns cinquenta campos e varrer o disco por campo seria absurdo.
	var fonte := _ler_scripts("res://scripts")
	if "--falsificar-consumo" in OS.get_cmdline_user_args():
		fonte = fonte.replace('bonus("desconto_de_compra")', 'bonus("campo_desligado_18")')
	conferir(fonte.length() > 10000, "Não consegui ler os scripts do jogo")

	# O CORPO do `_aplicar`, isolado. Isolado e não procurado na fonte inteira:
	# a primeira versão perguntava "a fonte cita o campo E existe um _aplicar?",
	# e as duas coisas são verdadeiras para TODO campo — o próprio dicionário de
	# efeitos cita o nome, e o `_aplicar` existe sempre. O teste passava em tudo.
	#
	# Descoberto falsificando: desliguei o desconto de compra e ele não reprovou.
	#
	# São DUAS `_aplicar`, e isso também foi descoberto falsificando: a do
	# `Talentos` e a do `Fe`, cada uma cuidando da sua árvore. Pegar só a
	# primeira reprovou seis nós de fé que funcionam perfeitamente.
	var aplicar := _trechos(fonte, "func _aplicar")
	conferir(aplicar.length() > 100, "Não achei o corpo do `_aplicar` para conferir")

	# --- 1. todo efeito é consumido -------------------------------------------
	var campos: Dictionary = {}
	for no in talentos.NOS:
		for campo in talentos.NOS[no].get("efeito", {}):
			campos[str(campo)] = "talento '%s'" % str(talentos.NOS[no].get("nome", no))
	for f in fe.ARVORES:
		var arvore: Dictionary = fe.ARVORES[f]
		for no in arvore:
			for campo in (arvore[no] as Dictionary).get("efeito", {}):
				campos[str(campo)] = "fé %s, nó '%s'" % [str(f), str(no)]

	conferir(campos.size() >= 20, "Só achei %d campos de efeito; esperava bem mais" % campos.size())

	var esperando := 0
	for campo in campos:
		if ESPERANDO_MECANICA.has(str(campo)):
			esperando += 1
			continue
		# DUAS formas legítimas de um campo virar mecânica, e só duas:
		#
		#   por bônus — alguém pergunta `Talentos.bonus(campo)` ou
		#               `Fe.bonus(campo)` na hora de fazer a conta;
		#   por aplicar — o `_aplicar` escreve direto na Progressao quando o nó
		#               é destravado, que é o caminho do que é permanente.
		var por_bonus := fonte.contains('bonus("%s")' % campo)
		var por_aplicar := aplicar.contains('"%s"' % campo)
		conferir(por_bonus or por_aplicar,
			("O campo '%s' (%s) não é lido por ninguém: o nó custa ponto, promete no " +
				"resumo e não faz nada") % [campo, campos[campo]])

	# --- 2. todo nó é apresentável ao jogador ---------------------------------
	for no in talentos.NOS:
		var dado: Dictionary = talentos.NOS[no]
		conferir(str(dado.get("nome", "")) != "", "Talento sem nome: %s" % no)
		conferir(str(dado.get("raiz", "")) != "", "Talento sem raiz: %s" % no)
		conferir(str(dado.get("resumo", "")).length() > 12,
			"Talento '%s' tem resumo curto demais para dizer o que faz" % no)
		conferir(str(dado.get("resumo", "")) != str(dado.get("nome", "")),
			"Talento '%s' repete o nome no resumo" % no)
		conferir(int(dado.get("custo", 0)) > 0, "Talento '%s' é de graça" % no)
		# TALENTO ATIVO não tem campo de efeito, e está certo: ele age na tecla
		# R, por um caso no `acionar`. O que ele precisa ter é esse caso —
		# ativo sem caso é a mesma mentira dos passivos, com outra roupa: o
		# jogador aperta R e não acontece nada.
		#
		# (A primeira versão deste teste cobrava efeito de TODOS e reprovou o
		# "Segundo fôlego", que é ativo e funciona. A regra é que estava
		# errada, não o talento.)
		if bool(dado.get("ativo", false)):
			conferir(fonte.contains('"%s":' % no) and fonte.contains("func acionar"),
				"O talento ativo '%s' não tem caso no `acionar`: a tecla R não faz nada" % no)
		else:
			conferir(not (dado.get("efeito", {}) as Dictionary).is_empty(),
				"Talento '%s' não concede efeito nenhum" % no)

	# --- 3. o grafo fecha ------------------------------------------------------
	for no in talentos.NOS:
		for exigido in talentos.NOS[no].get("exige", []):
			conferir(talentos.NOS.has(str(exigido)),
				"O talento '%s' exige '%s', que não existe na árvore" % [no, exigido])
			conferir(str(exigido) != str(no), "O talento '%s' exige a si mesmo" % no)

	print("")
	if falhas == 0:
		print("talentos: %d nós, %d campos de efeito, %d esperando mecânica declarada" % [
			talentos.NOS.size(), campos.size(), esperando])
	else:
		print("talentos: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


## TODOS os corpos de função com aquele cabeçalho, emendados.
##
## Serve para perguntar "isto é tratado DENTRO daqui?" em vez de "isto aparece
## em algum lugar do projeto?", que são perguntas muito diferentes.
##
## Todos e não o primeiro: `_aplicar` existe duas vezes no jogo, uma na árvore
## de talentos e outra na de fé. Parar no primeiro faz o teste reprovar a
## árvore inteira da outra.
func _trechos(fonte: String, cabecalho: String) -> String:
	var tudo := ""
	var de := fonte.find(cabecalho)
	while de >= 0:
		var fim := fonte.find("\nfunc ", de + cabecalho.length())
		tudo += fonte.substr(de, (fim - de) if fim > de else -1) + "\n"
		de = fonte.find(cabecalho, de + cabecalho.length())
	return tudo


## Junta o texto de todos os .gd sob um diretório. É a forma mais honesta de
## perguntar "alguém usa isto?" sem manter à mão uma lista de consumidores que
## envelhece sozinha.
func _ler_scripts(onde: String) -> String:
	var tudo := ""
	var dir := DirAccess.open(onde)
	if dir == null:
		return tudo
	dir.list_dir_begin()
	var nome := dir.get_next()
	while nome != "":
		var caminho := onde.path_join(nome)
		if dir.current_is_dir():
			tudo += _ler_scripts(caminho)
		elif nome.ends_with(".gd"):
			tudo += FileAccess.get_file_as_string(caminho)
		nome = dir.get_next()
	dir.list_dir_end()
	return tudo

