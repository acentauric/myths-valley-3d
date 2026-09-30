extends Node
## UMA CADEIA DE MISSÕES CONDUZIDA POR UM MORADOR.
##
## Estas regras moravam dentro do `guia_pedro.gd`, e o Pedro era o único que
## podia dar missão no vale. O jogo 2D não é assim: lá a Dona Zefa manda um
## recado, o Damião pede um cabo de foice, o Tonho cobra uma dívida — cada um
## com a sua fila de passos. Trazer a segunda cadeia copiando o arquivo do
## Pedro seria ter duas cópias das mesmas regras, e duas cópias de uma regra
## divergem: uma ganha o conserto e a outra não.
##
## Então as regras saíram de lá e vieram para cá, inteiras, e o Pedro passou a
## ser o primeiro FREGUÊS delas em vez de o dono. O que ficou com ele é o que
## é dele: seguir o jogador de perto, avisar que vai escurecer, e a voz.
##
##
## O QUE UM PASSO É
##
## O dado é o mesmo formato do `missoes_guia.json`, e o campo que importa é
## `lugar`: NOME DE CONTRATO do autoload `Lugares`, o mesmo nome que o jogo 2D
## usa. É o que faz um passo servir nos dois jogos sem ser reescrito.
##
##   lugar    onde o passo acontece; lugar que o vale ainda não tem faz o
##            passo ser PULADO, e não apontar a origem do mundo
##   raio     em unidades (1 u = 4 m), para o passo de visita fechar
##   entrega  ferramenta que o morador põe na mão AO ANUNCIAR, nunca depois
##   meta     o trabalho que fecha o passo, quando há
##
##
## COMO UM PASSO FECHA
##
## Sem meta, fecha ao chegar. Com meta, FECHA PELA META — onde quer que o
## jogador esteja. Foi o defeito da missão da picareta, dado por consertado
## duas vezes: o passo pedia três pedras E exigia estar perto do alvo, e o
## alvo é o lajedo, que some quando cai. O jogador quebrava a pedra, juntava
## as três, e o marcador tinha voltado para a âncora — de onde ele teria de
## caminhar até uma casa para o passo fechar.
##
## Há dois tipos de meta, e acrescentar um terceiro é acrescentar um `match`:
##
##   juntar    conta item na mochila (lenha, pedra)
##   derrubar  conta ALVOS DE TRABALHO que caíram, por peça
##
## O segundo existe por causa do capim do cemitério. No 2D, cortar o mato não
## põe nada na mochila — o mato some, que é o que limpar quer dizer. Contar
## pela mochila obrigaria a inventar um item "capim" no catálogo
## COMPARTILHADO, e mexer no jogo 2D por uma necessidade que é daqui.

signal missao_mudou(texto: String, alvo: Vector3, indice: int, total: int)

const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")

## Quem fala. Precisa de `narrar(audio, texto)`.
var dono: Node3D = null
var jogador: Node3D = null
## Os alvos de trabalho, para o marcador apontar o tronco em vez da casa e
## para a meta "derrubar" saber contar. Sem eles a cadeia ainda anda: o
## marcador cai na âncora, e a meta "derrubar" nunca se cumpre — o que é
## verdade, porque sem alvo não há o que derrubar.
var recursos: Node = null
## ACHAR UM MORADOR PELO ID, respondido de fora.
##
## A cadeia precisa disto para a meta "levar": entregar o pirão ao Tonho pede
## saber onde o Tonho está. Mas a cadeia não conhece a cena — e não deve: quem
## sabe a lista dos moradores é o `Prototype`, e pedir a ele por dentro
## amarraria esta peça àquela cena.
##
## É a terceira vez que este mesmo remendo aparece nesta migração, depois do
## `Vida.esta_lendo` e do `Mochila.alguem_fala`: pergunta sobre o ambiente,
## respondida por um `Callable` que quem monta liga. Sem ele, a meta "levar"
## nunca se cumpre — e isso é honesto, porque sem saber quem é o destinatário
## não há entrega.
var achar_morador: Callable = Callable()

## Passos cuja entrega já foi feita, por id. A meta "levar" não se mede olhando
## o mundo: ela ACONTECE num instante — o jogador chega com o item e ele muda de
## mão. Sem esta memória, a mochila vazia depois da entrega pareceria "ainda não
## trouxe" e a missão pediria o pirão de novo.
var _levados: Dictionary = {}

## O NOME DESTA CADEIA no caderno de missões, para dois donos não colidirem num
## passo de mesmo nome. Vem do campo `dono` do arquivo.
var chave := ""
## A cadeia é de ENREDO? Missão de enredo vai na frente na lista do painel, como
## a fila do arraial no jogo 2D. O tutorial do Pedro é; um favor de vizinho não.
var principal := false


var passos: Array = []
var arremate: Dictionary = {}
var missao := -1
var iniciado := false
## Conta regressiva até o anúncio do passo. Zero quer dizer "já anunciado".
var espera := 0.0
var despedida_feita := false


## Lê os passos do arquivo, já no idioma escolhido.
##
## A tradução é resolvida AQUI, uma vez, e não a cada fala: quem lê `texto`
## daqui para frente lê a língua do jogador sem saber que existem outras.
## Quem escolhe é o `IdiomaMenu.campo`, que a abertura já usava.
##
## Arquivo que não abre devolve `false` e deixa a cadeia vazia — o morador
## simplesmente não conduz nada, e o vale continua jogável. É o mesmo trato do
## `CatalogoAssets` com peça não exportada.
func carregar(caminho: String) -> bool:
	passos = []
	arremate = {}
	var arquivo := FileAccess.open(caminho, FileAccess.READ)
	if arquivo == null:
		push_warning("CadeiaDeMissoes: não achei %s; ninguém vai conduzir isto." % caminho)
		return false
	var dado = JSON.parse_string(arquivo.get_as_text())
	arquivo.close()
	if typeof(dado) != TYPE_DICTIONARY:
		push_warning("CadeiaDeMissoes: %s não é um objeto JSON." % caminho)
		return false

	for bruto in dado.get("passos", []):
		var passo: Dictionary = bruto.duplicate()
		passo["texto"] = str(IdiomaMenu.campo(passo, "texto"))
		passos.append(passo)
	chave = str(dado.get("dono", ""))
	principal = bool(dado.get("principal", false))
	arremate = dado.get("arremate", {}).duplicate()
	arremate["texto"] = str(IdiomaMenu.campo(arremate, "texto"))
	return not passos.is_empty()


## Começa a conduzir, com uma folga antes do primeiro anúncio.
func comecar(folga: float) -> void:
	if iniciado:
		return
	iniciado = true
	missao = 0
	espera = folga


func total() -> int:
	return passos.size()


func acabou() -> bool:
	return missao >= passos.size()


func passo_atual() -> Dictionary:
	if missao < 0 or missao >= passos.size():
		return {}
	return passos[missao]


## O texto do passo em curso, para o HUD. Vazio quer dizer "nada em curso".
func texto_do_passo() -> String:
	var passo := passo_atual()
	return str(passo.get("texto", "")) if not passo.is_empty() else ""


## UM PULSO DA CADEIA. O morador chama isto do `_physics_process` dele.
##
## `palavra_livre` é a pergunta "posso falar agora?", e vem DE FORA porque
## quem sabe respondê-la é o morador: ele conhece os outros que falam perto
## dele e a posição do jogador. A cadeia só precisa saber se pode ou não.
func correr(delta: float, palavra_livre: bool) -> void:
	if acabou() and not despedida_feita and palavra_livre \
			and not str(arremate.get("texto", "")).is_empty():
		despedida_feita = true
		# ARREMATE QUE NÃO SE FALA. Por padrão o dono da cadeia diz a última
		# frase, que é o certo quando ele está por perto — o Pedro termina o
		# tutorial do lado do jogador.
		#
		# A missão do pirão termina no PÍER, e a Dona Filó está na Casa da
		# estrada: a fala dela sairia num balão do outro lado do vale, que o
		# jogador não vê. Ali o fim de verdade é a resposta do Tonho, que a
		# própria meta narra na boca dele, e o arremate é só a nota que fica no
		# objetivo. `narra: false` no dado diz isso.
		if bool(arremate.get("narra", true)):
			_falar("", str(arremate["texto"]))
	if not iniciado or missao < 0 or missao >= passos.size():
		return

	# Lugar que este cenário ainda não tem: pula o passo em vez de apontar a
	# origem do mundo. É o mesmo trato do `Lugares` com os treze nomes que a
	# Fase 2.5 vai trazer — nome que não resolve some, e nada quebra.
	if not Lugares.resolve(str(passos[missao].get("lugar", ""))):
		avancar()
		return

	if espera > 0.0:
		espera -= delta
		if espera <= 0.0:
			if palavra_livre:
				anunciar()
			else:
				# Alguém ainda fala por perto: tenta de novo daqui a pouco.
				espera = 0.25
		return

	var passo: Dictionary = passos[missao]
	if not (passo.get("meta", {}) as Dictionary).is_empty():
		# Meta que ACONTECE, e não só se mede: a entrega precisa de alguém para
		# tentar antes de a pergunta ser feita.
		_tentar_encontro(passo)
		_acertar_o_caderno(passo)
		if not falta_a_meta(passo):
			avancar()
		return
	var alvo := posicao_do_passo(missao)
	if jogador != null and jogador.global_position.distance_to(alvo) < float(passo.get("raio", 8.0)):
		avancar()


## Anuncia o passo em curso: entrega o que ele promete e fala.
func anunciar() -> void:
	var passo := passo_atual()
	if passo.is_empty():
		return
	entregar(passo)
	_registrar_no_caderno(passo)
	_falar(str(passo.get("audio", "")), str(passo.get("texto", "")))
	missao_mudou.emit(_com_o_nome(str(passo.get("texto", ""))),
		posicao_do_passo(missao), missao + 1, passos.size())


## O PASSO ENTRA NO CADERNO DO VALE, que é mecanismo do 3D.
##
## A primeira versão disto escrevia no `Missoes` compartilhado com o 2D, com a
## checklist de itens daquele autoload. Funcionou e foi desfeito, pela razão que
## o autor deu: o 3D tem de ter o mecanismo dele, sem depender do checklist de
## lá, porque missão nova aqui pode ter padrão, formato e ordem diferentes.
##
## O 2D segue sendo a referência — as falas, os passos e o que cada morador pede
## vieram de lá. O que não vem é a máquina.
##
## O caderno do vale é pequeno: uma missão tem UMA LINHA de andamento, escrita
## por quem conduz, e não uma lista de itens que o caderno entende. É por isso
## que acrescentar uma meta nova (a de entrega, por exemplo) não pediu campo
## novo nele — a linha é texto, e a conta é dois números.
func _registrar_no_caderno(passo: Dictionary) -> void:
	var id := _id_no_caderno(passo)
	if id == "":
		return
	CadernoDoVale.abrir_missao(id, str(passo.get("texto", "")), chave, principal)
	var alvo := posicao_do_passo(missao)
	if alvo != Vector3.ZERO:
		CadernoDoVale.apontar(id, alvo)
	_acertar_o_caderno(passo)


## O id do passo no caderno, com o dono na frente para duas cadeias não colidirem
## num passo de mesmo nome.
func _id_no_caderno(passo: Dictionary) -> String:
	var id := str(passo.get("id", ""))
	return "" if id == "" else "%s_%s" % [chave, id] if chave != "" else id


func _nome_do_item(item: String) -> String:
	return str(Catalogo.ITENS.get(item, {}).get("nome", item))


func _nome_de(quem: String) -> String:
	var no := _morador(quem)
	if no == null or not ("dados" in no):
		return quem
	return str((no.dados as Dictionary).get("nome", quem))

func _falar(audio: String, texto: String) -> void:
	if dono != null and dono.has_method("narrar"):
		dono.narrar(audio, texto)


## O nome de quem fala na frente da fala, que é como o HUD do vale já mostrava
## as missões do Pedro.
func _com_o_nome(texto: String) -> String:
	if dono == null:
		return texto
	var nome := ""
	if "dados" in dono:
		nome = str((dono.dados as Dictionary).get("nome", ""))
	return texto if nome.is_empty() else "%s: %s" % [nome, texto]


## O MORADOR ENTREGA A FERRAMENTA AO ANUNCIAR, E JÁ NA MÃO.
##
## É a regra 1 do tutorial do 2D — o NPC anuncia antes de cobrar — levada a
## sério: quem ouve "toma o machado e vai cortar" precisa ter o machado na
## mesma frase. Pedir primeiro e entregar depois é o que faz o jogador rodar o
## mapa procurando uma ferramenta que ninguém deu.
##
## E "na mão" passou a querer dizer ENCAIXADA. O vale mudou a regra do trabalho:
## bater agora exige a ferramenta no encaixe, e não só na mochila
## (`Recursos3D._tem_ferramenta`) — que é o certo, e é o do 2D. Mas a promessa
## da fala não mudou: entregar na mochila e deixar o jogador descobrir sozinho
## que falta equipar é a mesma ferramenta que ninguém deu, com um passo a mais.
##
## Então quem entrega, encaixa. Se o encaixe estiver ocupado, o que estava lá
## volta para a mochila — quem cuida disso é o `Equipamento`, e não esta linha.
##
## Entrega uma vez só: o anúncio de cada passo acontece uma vez, e retomar o
## passo não reanuncia.
func entregar(passo: Dictionary) -> void:
	var entrega: Dictionary = passo.get("entrega", {})
	if entrega.is_empty():
		return
	var item := str(entrega.get("item", ""))
	if item == "":
		return
	# JÁ TEM NÃO É JÁ RECEBEU. O vale entrega um machado de saída e manda
	# equipar; se o passo desistisse por achar o item na mochila, o "toma o
	# machado e vai cortar" não daria nada e o trabalho ficaria impossível para
	# quem ainda não descobriu o encaixe. Não ganha outro — ganha na mão.
	if not Inventario.tem(item) and not _na_mao(item):
		if not Inventario.adicionar(item, int(entrega.get("quantidade", 1))):
			return
	_por_na_mao(item)


## O item está encaixado agora?
func _na_mao(item: String) -> bool:
	var encaixe := Equipamento.encaixe_de(item)
	return encaixe != "" and Equipamento.no_encaixe(encaixe) == item


## Encaixa o que está na mochila. Quem não é de encaixe fica onde está.
func _por_na_mao(item: String) -> void:
	if not Equipamento.e_equipamento(item) or _na_mao(item):
		return
	for i in Inventario.espacos.size():
		if str((Inventario.espacos[i] as Dictionary).get("id", "")) == item:
			Equipamento.equipar_do_espaco(i)
			return


## A meta do passo ainda não foi cumprida? Passo sem meta nunca falta.
func falta_a_meta(passo: Dictionary) -> bool:
	var meta: Dictionary = passo.get("meta", {})
	if meta.is_empty():
		return false
	match str(meta.get("tipo", "")):
		"juntar":
			return Inventario.quantidade(str(meta.get("item", ""))) < int(meta.get("quantos", 1))
		"levar", "falar":
			# Encontro é ACONTECIMENTO, e não estado do mundo: depois dele não
			# sobra nada no mundo que diga que aconteceu. Quem responde é a
			# memória. Ver `_tentar_encontro`.
			return not bool(_levados.get(str(passo.get("id", "")), false))
		"derrubar":
			if recursos == null or not recursos.has_method("derrubados"):
				return true
			return int(recursos.derrubados(str(meta.get("alvo", "")))) < int(meta.get("quantos", 1))
		_:
			return false


## Próximo passo; depois do último, emite com indice == total para a seta sumir.
func avancar() -> void:
	# O passo que fecha SAI DO CADERNO, como no 2D: `concluir` o tira das
	# ativas e o põe nas cumpridas, e é isso que faz a aba de missões mostrar o
	# que está em curso e não o histórico inteiro.
	var fechando := passo_atual()
	if not fechando.is_empty():
		CadernoDoVale.concluir(_id_no_caderno(fechando))
	missao += 1
	if missao >= passos.size():
		missao_mudou.emit(str(arremate.get("texto", "")), Vector3.ZERO, passos.size(), passos.size())
	else:
		espera = 1.4


## O ANDAMENTO DO PASSO, ACERTADO A CADA PULSO.
##
## Chamada do `correr`, todo quadro, com a verdade do momento — e o caderno só
## emite `mudou` quando o número de fato mudou, então isto não faz a tela piscar.
##
## Por que todo quadro e não só quando sobe: saldo DESCE. O jogador junta as duas
## achas, a linha diz "2 de 2", e ele gasta uma lenha em outra coisa no caminho.
## Se o andamento só fosse escrito na subida, a linha mentiria — e no 2D essa
## mentira já custou uma obra que não saía sem nada na tela explicando por quê.
##
## UMA LINHA, e não uma lista. Quem conduz escreve a frase e a conta; o caderno
## não tenta entender de que tipo é a meta. É o que deixa a próxima meta nascer
## sem mexer nele.
func _acertar_o_caderno(passo: Dictionary) -> void:
	var id := _id_no_caderno(passo)
	if id == "" or not CadernoDoVale.tem(id):
		return
	var meta: Dictionary = passo.get("meta", {})
	match str(meta.get("tipo", "")):
		"juntar":
			var item := str(meta.get("item", ""))
			var quantos := int(meta.get("quantos", 1))
			var tem := mini(quantos, Inventario.quantidade(item))
			CadernoDoVale.andar(id, tem, quantos,
				"Juntar %s: %d de %d" % [_nome_do_item(item), tem, quantos])
		"derrubar":
			var peca := str(meta.get("alvo", ""))
			var quantos_pes := int(meta.get("quantos", 1))
			var caidos := 0
			if recursos != null and recursos.has_method("derrubados"):
				caidos = mini(quantos_pes, int(recursos.derrubados(peca)))
			CadernoDoVale.andar(id, caidos, quantos_pes,
				"Cortar: %d de %d" % [caidos, quantos_pes])
		"levar":
			var levou: bool = bool(_levados.get(str(passo.get("id", "")), false))
			var carga := str(meta.get("item", ""))
			var pedidas := maxi(int(meta.get("quantos", 1)), 1)
			var linha := "Levar %s a %s" % [_nome_do_item(carga),
				_nome_de(str(meta.get("a_quem", "")))]
			# QUANTAS AINDA FALTAM, quando é mais de uma: sem isto o jogador sobe
			# até a praça para descobrir que trouxe cinco. A conta fica na frase
			# e não na barra, porque ter as seis não é tê-las entregado.
			if pedidas > 1:
				linha = "Levar %d %s a %s (tem %d)" % [pedidas, _nome_do_item(carga),
					_nome_de(str(meta.get("a_quem", ""))),
					mini(pedidas, Inventario.quantidade(carga))]
			CadernoDoVale.andar(id, 1 if levou else 0, 1, linha)
		"falar":
			var falou: bool = bool(_levados.get(str(passo.get("id", "")), false))
			CadernoDoVale.andar(id, 1 if falou else 0, 1,
				"Falar com %s" % _nome_de(str(meta.get("a_quem", ""))))
		_:
			# Passo de visita: sem conta, e a frase do passo já é o que fazer.
			CadernoDoVale.andar(id, 0, 0, "")
	# O marcador acompanha: alvo de trabalho que cai muda o lugar a apontar.
	var alvo := posicao_do_passo(missao)
	if alvo != Vector3.ZERO:
		CadernoDoVale.apontar(id, alvo)


## ONDE O MARCADOR APONTA.
##
## Passo que pede trabalho aponta O ALVO MAIS PERTO, e não a âncora do lugar:
## quem ouve "me traga duas achas" precisa de seta para onde há tronco, e não
## para a casa de quem pediu. Sem alvo à vista, cai na âncora.
func posicao_do_passo(indice: int) -> Vector3:
	if indice < 0 or indice >= passos.size():
		return Vector3.ZERO
	var passo: Dictionary = passos[indice]
	var meta: Dictionary = passo.get("meta", {})
	if recursos != null and not meta.is_empty():
		var de: Vector3 = jogador.global_position if jogador != null else Vector3.ZERO
		var perto: Vector3 = Lugares.NENHUM
		match str(meta.get("tipo", "")):
			"juntar":
				if recursos.has_method("mais_perto_que_rende"):
					perto = recursos.mais_perto_que_rende(str(meta.get("item", "")), de)
			"levar", "falar":
				var quem := _morador(str(meta.get("a_quem", "")))
				if quem != null:
					perto = quem.global_position
			"derrubar":
				if recursos.has_method("mais_perto_da_peca"):
					perto = recursos.mais_perto_da_peca(str(meta.get("alvo", "")), de)
		if perto != Lugares.NENHUM:
			return perto
	var ponto: Vector3 = Lugares.ponto(str(passo.get("lugar", "")))
	return Vector3.ZERO if ponto == Lugares.NENHUM else ponto


## A DISTÂNCIA EM QUE A CADEIA SE ABRE SOZINHA, em unidades. Zero quer dizer
## "quem abre é outro" — é o caso do Pedro, que abre no `saudar()`.
##
## O Damião abre assim: o jogador sobe ao cemitério, chega perto dele, e a
## conversa começa. No jogo 2D quem manda subir lá é a Dona Zefa; enquanto ela
## não tiver fila de missões no vale, chegar perto faz o mesmo serviço e não
## deixa a missão inalcançável.
var comeca_perto_de := 0.0
## Folga entre abrir e o primeiro anúncio.
var folga_inicial := 2.0


## A CADEIA SE MOVE SOZINHA, e não pela mão do morador.
##
## Assim um morador qualquer ganha fila de missões sem ganhar código: basta
## pendurar este nó nele. O Pedro, que tem script próprio, também não chama
## `correr` — ele só cria o nó e escuta o sinal. Uma cadeia, um pulso.
func _physics_process(delta: float) -> void:
	if dono == null or jogador == null:
		return
	if comeca_perto_de > 0.0 and not iniciado:
		var perto := dono.global_position.distance_to(jogador.global_position) < comeca_perto_de
		if perto:
			comecar(folga_inicial)
		else:
			return
	correr(delta, _palavra_livre())


## O morador pode falar agora? Nem ele nem o jogador podem estar ao alcance de
## outra fala — é a regra do `npc.gd`, e quem a responde é o dono.
func _palavra_livre() -> bool:
	if dono.has_method("pode_falar") and not dono.pode_falar():
		return false
	if dono.has_method("fala_perto_de") and dono.fala_perto_de(jogador.global_position):
		return false
	return true


## O MORADOR DE ID `quem`, ou null. Pergunta respondida de fora — ver
## `achar_morador`.
func _morador(quem: String) -> Node3D:
	if quem == "" or not achar_morador.is_valid():
		return null
	var achado = achar_morador.call(quem)
	return achado as Node3D


## O ENCONTRO: chegar perto de quem espera — com a coisa na mão, ou de mãos vazias.
##
## São duas metas com o mesmo corpo. "Levar" pede o item junto; "falar" só pede
## que o jogador chegue. Escrevê-las separadas seria ter a mesma travessia
## escrita duas vezes, e a segunda ficaria para trás no dia em que a primeira
## ganhasse um conserto.
##
## E as duas são ACONTECIMENTO, não estado — é o que as separa de "juntar" e
## "derrubar". Dá para perguntar ao mundo quantas pedras há na mochila a
## qualquer momento; não dá para perguntar "o jogador já falou com o Cosme?",
## porque depois da conversa não sobra nada no mundo que diga isso. Daí a
## memória em `_levados`, que vale para as duas.
##
## QUEM FALA NO FIM É QUEM RECEBE, e não quem pediu. A Dona Filó manda o pirão
## da Casa da estrada; o Tonho responde no píer, que é onde o jogador está. Pôr
## a resposta na boca dela seria o jogador ouvir o agradecimento do outro lado
## do vale, num balão que ele não vê.
func _tentar_encontro(passo: Dictionary) -> void:
	var meta: Dictionary = passo.get("meta", {})
	var tipo := str(meta.get("tipo", ""))
	if tipo != "levar" and tipo != "falar":
		return
	var id := str(passo.get("id", ""))
	if bool(_levados.get(id, false)):
		return
	var item := str(meta.get("item", ""))
	# A ENTREGA TEM CONTA. A Dona Candinha pede SEIS canas, e enquanto a meta
	# levava um só, chegar ao lado dela com uma cana fechava a missão das seis:
	# o balão saía, o passo fechava, e a conta não acontecia. `quantos` sem
	# número é um, que é o pirão da Dona Filó e tudo que veio antes.
	var quantos := maxi(int(meta.get("quantos", 1)), 1)
	if tipo == "levar" and (item == "" or Inventario.quantidade(item) < quantos):
		return
	var quem := _morador(str(meta.get("a_quem", "")))
	if quem == null or jogador == null:
		return
	var no_chao := quem.global_position - jogador.global_position
	no_chao.y = 0.0
	if no_chao.length() > float(meta.get("raio", 3.0)):
		return

	if tipo == "levar":
		Inventario.consumir(item, quantos)
	_levados[id] = true
	var resposta := str(meta.get("resposta", ""))
	if resposta != "" and quem.has_method("narrar"):
		quem.narrar("", resposta)
