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
## (Vieram outros depois — levar, falar, evento, obra —, e com a fé, #52, mais
## dois: `visitar`, que risca cada lugar de uma lista ao chegar perto dele — os
## três marcos, a romaria —, e `oferendar`, que é o `levar` com um LUGAR no
## lugar de uma pessoa: a mesa do terreiro, as conchas da gameleira.)
##
## O segundo existe por causa do capim do cemitério. No 2D, cortar o mato não
## põe nada na mochila — o mato some, que é o que limpar quer dizer. Contar
## pela mochila obrigaria a inventar um item "capim" no catálogo
## COMPARTILHADO, e mexer no jogo 2D por uma necessidade que é daqui.

signal missao_mudou(texto: String, alvo: Vector3, indice: int, total: int)
## Um passo fechou e pagou (ver `_pagar`): o texto diz de quem e o quê.
signal pagou(texto: String)
## A meta `visitar` riscou um lugar — o vale conta o que se vê dali.
signal visitou(lugar: String)

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
## ONDE FICA UM LUGAR, respondido de fora, para as metas `visitar` e
## `oferendar`. Sem resposta, é a âncora do `Lugares`; com ela, o vale pode
## dizer que "capela" é o ALTAR da igreja, e não o meio do telhado.
var ponto_do_lugar: Callable = Callable()
## SÓ ANDA ENQUANTO isto responder verdadeiro: a missão de uma fé CONGELA quando
## o jogador muda para outra, e volta a correr quando ele voltar (é a regra do
## 2D, docs/FE.md §2). Congelada, nem risca, nem entrega, nem anuncia.
var so_enquanto: Callable = Callable()

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
## O último resumo mandado ao HUD, para só reenviar quando ele muda.
var _resumo_mostrado := ""
## O NOME DA MISSÃO INTEIRA ("O cemitério esquecido"), que é o que o diário
## lista e o HUD escreve em cima do objetivo — o passo é só onde ela está. Vem
## do campo `nome` do arquivo, nos três idiomas.
var nome_da_missao := ""


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
		var passo: Dictionary = bruto.duplicate(true)
		passo["texto"] = str(IdiomaMenu.campo(passo, "texto"))
		passo["resumo"] = str(IdiomaMenu.campo(passo, "resumo", ""))
		passo["titulo"] = str(IdiomaMenu.campo(passo, "titulo", ""))
		# A RESPOSTA DE QUEM RECEBE também é fala do jogador ler, e também nasce
		# nos três idiomas (`resposta`, `resposta_en`, `resposta_es`).
		var meta: Dictionary = passo.get("meta", {})
		if meta.has("resposta"):
			meta["resposta"] = str(IdiomaMenu.campo(meta, "resposta", ""))
		passos.append(passo)
	chave = str(dado.get("dono", ""))
	principal = bool(dado.get("principal", false))
	nome_da_missao = str(IdiomaMenu.campo(dado, "nome", ""))
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
		# A conta do HUD anda com o trabalho: "Corte lenha (1/2)" vira "(2/2)".
		if resumo_do_passo(passo) != _resumo_mostrado:
			_mostrar_o_resumo(passo)
		return
	var alvo := posicao_do_passo(missao)
	if jogador != null and jogador.global_position.distance_to(alvo) < float(passo.get("raio", 8.0)):
		avancar()


## RETOMA UMA PARTIDA SALVA SEM FALAR DE NOVO.
##
## Carregar reapontava o marcador pondo `espera` de volta, e `espera` que vence
## chama `anunciar` — que FALA. Quem salvasse no primeiro passo do Pedro ouvia a
## abertura do jogo inteira ao voltar, como se a partida tivesse recomeçado; e
## mesmo no meio da campanha, voltar e ser recebido pela fala do passo é o vale
## se repetindo.
##
## O que o jogador precisa ao voltar é o OBJETIVO, não a fala: onde ir e o que
## falta. Isso é o caderno e o marcador, e os dois se põem aqui sem balão. A fala
## já aconteceu uma vez, e uma vez é o que ela vale.
func retomar() -> void:
	# ZERO, E NÃO UM NÚMERO PEQUENO: o `correr` só anuncia quando `espera` VENCE,
	# então espera que nasce zerada nunca chega ao anúncio.
	espera = 0.0
	if missao < 0 or missao >= passos.size():
		return
	var passo: Dictionary = passos[missao]
	_registrar_no_caderno(passo)
	_mostrar_o_resumo(passo)


## Anuncia o passo em curso: entrega o que ele promete e fala.
func anunciar() -> void:
	var passo := passo_atual()
	if passo.is_empty():
		return
	entregar(passo)
	_registrar_no_caderno(passo)
	_falar(str(passo.get("audio", "")), str(passo.get("texto", "")))
	_mostrar_o_resumo(passo)


## O OBJETIVO DO HUD É O RESUMO, e não a fala.
##
## "A descrição da missão no HUD deve ser um resumo com atividades diretas ao
## ponto. O texto completo deve ficar apenas no painel de missão (J)." O HUD
## recebia a fala inteira com o nome na frente — "Damião: O senhor subiu. Pouca
## gente sobe. Olha em volta: capim de dois anos..." —, e o canto da tela virava
## parede de letra. A fala continua no balão e no caderno, que o J mostra.
##
## O que vai é o `resumo` do passo, escrito no JSON nos três idiomas; passo com
## meta e sem resumo escrito ganha um gerado da meta ("Fale com Tonho"). Meta
## que se conta leva a conta junto, e a conta anda: o pulso refaz o resumo e
## só reenvia quando ele muda (ver `correr`).
func _mostrar_o_resumo(passo: Dictionary) -> void:
	_resumo_mostrado = resumo_do_passo(passo)
	CadernoDoVale.descrever(_id_no_caderno(passo), {"resumo": _resumo_mostrado})
	missao_mudou.emit(_resumo_mostrado, posicao_do_passo(missao), missao + 1, passos.size())


## Os passos já cumpridos desta missão, pelo resumo de cada um, para o diário
## riscar. Passo de lugar que o cenário não tem foi pulado, e não entra.
func _feitos() -> Array:
	var lista: Array = []
	for i in range(0, mini(missao, passos.size())):
		var anterior: Dictionary = passos[i]
		if not Lugares.resolve(str(anterior.get("lugar", ""))):
			continue
		var escrito := str(anterior.get("resumo", "")).strip_edges()
		var feito := escrito if escrito != "" else _titulo_do_passo(anterior)
		# O que se ganhou vai junto do objetivo riscado, como no diário do Witcher.
		var ganho := _texto_da_recompensa(anterior)
		lista.append(feito if ganho == "" else "%s  —  %s" % [feito, ganho])
	return lista


func resumo_do_passo(passo: Dictionary) -> String:
	var meta: Dictionary = passo.get("meta", {})
	var escrito := str(passo.get("resumo", "")).strip_edges()
	var conta := ""
	var gerado := ""
	match str(meta.get("tipo", "")):
		"juntar":
			var carga := _carga_da_meta(meta)
			var tem := 0
			var pede := 0
			var nomes: Array[String] = []
			for qual in carga:
				pede += int(carga[qual])
				tem += mini(int(carga[qual]), Inventario.quantidade(str(qual)))
				nomes.append(_nome_do_item(str(qual)).to_lower())
			conta = "%d/%d" % [tem, pede]
			gerado = tr("Junte %s") % ", ".join(nomes)
		"obra":
			var obra := str(meta.get("obra", ""))
			gerado = tr("Faça a obra: %s") % str(Obras.dados(obra).get("nome", obra))
		"derrubar":
			var quantos_pes := int(meta.get("quantos", 1))
			var caidos := 0
			if recursos != null and recursos.has_method("derrubados"):
				caidos = mini(quantos_pes, int(recursos.derrubados(str(meta.get("alvo", "")))))
			conta = "%d/%d" % [caidos, quantos_pes]
			gerado = tr("Corte %s") % _nome_do_item(str(meta.get("alvo", ""))).to_lower()
		"levar":
			var itens: Array[String] = []
			for qual in _carga_da_meta(meta):
				itens.append(_nome_do_item(str(qual)).to_lower())
			gerado = tr("Leve %s a %s") % [", ".join(itens), _nome_de(str(meta.get("a_quem", "")))]
		"falar":
			gerado = tr("Fale com %s") % _nome_de(str(meta.get("a_quem", "")))
		"visitar":
			var lugares := _lugares_da_meta(meta)
			conta = "%d/%d" % [_visitados(passo).size(), lugares.size()]
		"oferendar":
			var carga := _carga_da_meta(meta)
			var tem := 0
			var pede := 0
			for qual in carga:
				pede += int(carga[qual])
				tem += mini(int(carga[qual]), Inventario.quantidade(str(qual)))
			conta = "%d/%d" % [tem, pede]
	var frase := escrito if escrito != "" else gerado
	if frase == "":
		# Passo sem meta e sem resumo escrito: o título, que é curto.
		frase = _titulo_do_passo(passo)
	return frase if conta == "" else "%s (%s)" % [frase, conta]


## O NOME CURTO DO PASSO, que é o que entra no caderno e na lista do painel.
##
## O `texto` é a FALA — um parágrafo, às vezes dois. Ele servia de título por
## falta de outro, e a lista de missões virava parede de letra: um botão com um
## parágrafo dentro empurra a caixa do painel para fora da janela. O jogo 2D
## sempre teve as duas coisas separadas (`titulo` e `fala` no arraial.json), e
## agora os arquivos daqui também têm.
##
## SEM `titulo`, CORTA. Missão escrita amanhã sem o campo não pode explodir a
## tela de quem a abrir: vale uma reticência, não vale um parágrafo.
const LETRAS_DO_TITULO := 52

static func _titulo_do_passo(passo: Dictionary) -> String:
	var nome := str(passo.get("titulo", "")).strip_edges()
	if nome != "":
		return nome
	var fala := str(passo.get("texto", "")).strip_edges()
	if fala.length() <= LETRAS_DO_TITULO:
		return fala
	return fala.substr(0, LETRAS_DO_TITULO - 1).strip_edges() + "…"


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
	CadernoDoVale.abrir_missao(id, _titulo_do_passo(passo), chave, principal,
		_com_o_nome(str(passo.get("texto", ""))))
	# LIÇÃO ANTES DO TRABALHO, como no 2D: o passo que abre ensina a planta
	# que ele vai cobrar adiante (`Receitas`, porta "missao").
	Receitas.passo_abriu(str(passo.get("id", "")))
	CadernoDoVale.descrever(id, {
		"missao": nome_da_missao if nome_da_missao != "" else _titulo_do_passo(passo),
		"quem": _nome_do_dono(),
		"resumo": resumo_do_passo(passo),
		"passo": missao + 1,
		"passos": passos.size(),
		"feitos": _feitos(),
	})
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
	var nome := _nome_do_dono()
	return texto if nome.is_empty() else "%s: %s" % [nome, texto]


func _nome_do_dono() -> String:
	if dono == null or not ("dados" in dono):
		return ""
	return str((dono.dados as Dictionary).get("nome", ""))


## O MORADOR ENTREGA A FERRAMENTA AO ANUNCIAR, E JÁ NA MÃO.
##
## É a regra 1 do tutorial do 2D — o NPC anuncia antes de cobrar — levada a
## sério: quem ouve "toma o machado e vai cortar" precisa ter o machado na
## mesma frase. Pedir primeiro e entregar depois é o que faz o jogador rodar o
## mapa procurando uma ferramenta que ninguém deu.
##
## E "na mão" quer dizer NA MÃO: bater exige a ferramenta escolhida na barra de
## mão (ou vestida em "Mãos"), e não só carregada na mochila
## (`Recursos3D._tem_ferramenta`). Entregar na mochila e deixar o jogador
## descobrir sozinho que falta pegar é a mesma ferramenta que ninguém deu, com
## um passo a mais.
##
## Então quem entrega, acende o espaço da barra (ver `_por_na_mao`).
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


## O item está na mão agora — pela barra ou pelo encaixe?
func _na_mao(item: String) -> bool:
	return Equipamento.em_uso(item)


## PÕE NA MÃO PELA BARRA, que é a porta que o jogador usa: o número do espaço
## fica aceso, e é o mesmo número que ele vai apertar para guardar e pegar de
## novo. Só quando o item não está em nenhum dos dez da barra (mochila cheia lá
## em cima) é que ele vai para o encaixe. Quem não é de encaixe fica onde está.
func _por_na_mao(item: String) -> void:
	if _na_mao(item) or not (Catalogo.tipo(item) == "ferramenta" or Equipamento.e_equipamento(item)):
		return
	# Toda ferramenta, e não só a de encaixe: o trabalho cobra a ferramenta NA
	# MÃO (`Recursos3D._tem_ferramenta`), e a foice entregue para o capim tem de
	# chegar acesa na barra como o machado.
	for i in Inventario.ESPACOS_MAO:
		if str((Inventario.espacos[i] as Dictionary).get("id", "")) == item:
			Inventario.selecionar(i)
			return
	if not Equipamento.e_equipamento(item):
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
			# UM ITEM OU VÁRIOS: `item`/`quantos`, ou `itens` {id: quanto} — o
			# material do mirante é tábua, pedra e corda de uma vez.
			var carga := _carga_da_meta(meta)
			for qual in carga:
				if Inventario.quantidade(str(qual)) < int(carga[qual]):
					return true
			return false
		"levar", "falar":
			# Encontro é ACONTECIMENTO, e não estado do mundo: depois dele não
			# sobra nada no mundo que diga que aconteceu. Quem responde é a
			# memória. Ver `_tentar_encontro`.
			return not bool(_levados.get(str(passo.get("id", "")), false))
		"derrubar":
			if recursos == null or not recursos.has_method("derrubados"):
				return true
			return int(recursos.derrubados(str(meta.get("alvo", "")))) < int(meta.get("quantos", 1))
		"evento":
			# ACONTECIMENTO DO VALE que o vale avisa (`registrar_evento`): abrir a
			# tela do P, por exemplo. Também é memória, pela mesma razão do
			# encontro.
			return not bool(_levados.get(_chave_do_evento(str(meta.get("evento", ""))), false))
		"obra":
			# A OBRA FEITA, do `Obras` — o mirante levantado. Isso o mundo
			# guarda sozinho, e o save também.
			return not Obras.ja_feita(str(meta.get("construcao", "")), str(meta.get("obra", "")))
		"visitar":
			# CHEGAR É ACONTECIMENTO, como o encontro: a memória diz quem já foi.
			return _visitados(passo).size() < _lugares_da_meta(meta).size()
		"oferendar":
			return not bool(_levados.get(str(passo.get("id", "")), false))
		_:
			return false


## UM ACONTECIMENTO DO VALE que um passo pode esperar — "abriu_arraial" é o
## jogador abrindo a tela do P. O vale avisa todas as cadeias, mesmo as que
## ainda não chegaram no passo: quem já sabe usar o P não precisa aprender de
## novo. Fica na memória da cadeia, que vai no save.
func registrar_evento(nome: String) -> void:
	_levados[_chave_do_evento(nome)] = true


static func _chave_do_evento(nome: String) -> String:
	return "evento:" + nome


## A RECOMPENSA DO PASSO (#48), paga quando ele fecha: itens e réis, com os
## números do jogo 2D (bloco `recompensas` do `arraial.json` de lá). Paga UMA
## vez porque o passo só fecha uma vez — carregar a partida põe a cadeia no
## passo seguinte, e `avancar` não roda de novo para o que já fechou.
##
## O HUD diz o que se ganhou (`pagou`), e o diário escreve ao lado do
## objetivo riscado (`_feitos`).
func _pagar(passo: Dictionary) -> void:
	var recompensa: Dictionary = passo.get("recompensa", {})
	if recompensa.is_empty():
		return
	for chave in recompensa:
		var quanto := int(recompensa[chave])
		if str(chave) == "reis":
			Jogo.dinheiro += quanto
		elif Catalogo.existe(str(chave)):
			Inventario.adicionar(str(chave), quanto)
	pagou.emit(tr("Recebido de %s: %s") % [_nome_do_dono(), _texto_da_recompensa(passo)])


func _texto_da_recompensa(passo: Dictionary) -> String:
	var partes: Array[String] = []
	var recompensa: Dictionary = passo.get("recompensa", {})
	for chave in recompensa:
		var quanto := int(recompensa[chave])
		if str(chave) == "reis":
			partes.append(tr("%d réis") % quanto)
		else:
			partes.append("%d %s" % [quanto, _nome_do_item(str(chave)).to_lower()])
	return ", ".join(partes)


## Próximo passo; depois do último, emite com indice == total para a seta sumir.
func avancar() -> void:
	# O passo que fecha SAI DO CADERNO, como no 2D: `concluir` o tira das
	# ativas e o põe nas cumpridas, e é isso que faz a aba de missões mostrar o
	# que está em curso e não o histórico inteiro.
	var fechando := passo_atual()
	if not fechando.is_empty():
		_pagar(fechando)
		# MISSÃO DE FÉ RENDE NA FÉ ATIVA, e no ofício também, como no 2D
		# (`Arraial._fechar_a_missao_da_fe`). Sem fé ainda, o `Fe` não credita.
		if bool(fechando.get("xp_de_fe", false)):
			Fe.ganhar("missao")
			Talentos.ganhar("missao")
		CadernoDoVale.concluir(_id_no_caderno(fechando))
	missao += 1
	if missao >= passos.size():
		# O FIM TAMBÉM É CURTO NO HUD: o arremate é fala (balão, ou a nota da
		# meta), e o objetivo só diz que acabou e com quem.
		_resumo_mostrado = tr("Concluído: missões com %s") % _nome_do_dono()
		missao_mudou.emit(_resumo_mostrado, Vector3.ZERO, passos.size(), passos.size())
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
			var carga := _carga_da_meta(meta)
			var tem_tudo := 0
			var pede_tudo := 0
			var partes: Array[String] = []
			for qual in carga:
				var pede := int(carga[qual])
				var tem := mini(pede, Inventario.quantidade(str(qual)))
				tem_tudo += tem
				pede_tudo += pede
				partes.append("%s %d/%d" % [_nome_do_item(str(qual)), tem, pede])
			var linha := "Juntar %s: %d de %d" % [_nome_do_item(str(carga.keys()[0])), tem_tudo, pede_tudo] \
				if carga.size() == 1 else "Juntar " + " · ".join(partes)
			CadernoDoVale.andar(id, tem_tudo, pede_tudo, linha)
		"evento", "obra":
			CadernoDoVale.andar(id, 0 if falta_a_meta(passo) else 1, 1, str(passo.get("resumo", "")))
		"visitar":
			CadernoDoVale.andar(id, _visitados(passo).size(), _lugares_da_meta(meta).size(), str(passo.get("resumo", "")))
		"oferendar":
			var entregou: bool = bool(_levados.get(str(passo.get("id", "")), false))
			var pedidos := _carga_da_meta(meta)
			var faltas: Array[String] = []
			for qual in pedidos:
				faltas.append("%s %d/%d" % [_nome_do_item(str(qual)), mini(int(pedidos[qual]), Inventario.quantidade(str(qual))), int(pedidos[qual])])
			CadernoDoVale.andar(id, 1 if entregou else 0, 1, " · ".join(faltas))
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
			# QUANTAS AINDA FALTAM DE CADA UMA: sem isto o jogador sobe até a
			# praça para descobrir que trouxe cinco, ou atravessa o vale com as
			# cordas e sem as tábuas. A conta fica na frase e não na barra,
			# porque ter o material não é tê-lo entregado.
			var cobrada := _carga_da_meta(meta)
			var partes: Array[String] = []
			for qual in cobrada:
				var pedidas := int(cobrada[qual])
				if pedidas > 1:
					partes.append("%d %s (tem %d)" % [pedidas, _nome_do_item(str(qual)),
						mini(pedidas, Inventario.quantidade(str(qual)))])
				else:
					partes.append(_nome_do_item(str(qual)))
			CadernoDoVale.andar(id, 1 if levou else 0, 1,
				"Levar %s a %s" % [", ".join(partes), _nome_de(str(meta.get("a_quem", "")))])
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
	# PASSO DE VÁRIOS LUGARES — a escolha da fé, em qualquer um dos três marcos:
	# o marcador aponta o mais perto.
	if passo.has("lugares") and str(meta.get("tipo", "")) != "visitar":
		var de_cada: Vector3 = jogador.global_position if jogador != null else Vector3.ZERO
		var o_mais_perto := Lugares.NENHUM
		for lugar in passo.get("lugares", []):
			var la := _ponto_do(str(lugar))
			if la.is_finite() and (not o_mais_perto.is_finite() or de_cada.distance_to(la) < de_cada.distance_to(o_mais_perto)):
				o_mais_perto = la
		if o_mais_perto.is_finite():
			return o_mais_perto
	# OS LUGARES DA FÉ: o mais perto que ainda falta, e o lugar da oferenda.
	match str(meta.get("tipo", "")):
		"visitar":
			var de_onde: Vector3 = jogador.global_position if jogador != null else Vector3.ZERO
			var vistos := _visitados(passo)
			var melhor := Lugares.NENHUM
			for lugar in _lugares_da_meta(meta):
				if vistos.has(lugar):
					continue
				var ali := _ponto_do(str(lugar))
				if ali.is_finite() and (not melhor.is_finite() or de_onde.distance_to(ali) < de_onde.distance_to(melhor)):
					melhor = ali
			if melhor.is_finite():
				return melhor
		"oferendar":
			var ali := _ponto_do(str(meta.get("lugar", passo.get("lugar", ""))))
			if ali.is_finite():
				return ali
	if recursos != null and not meta.is_empty():
		var de: Vector3 = jogador.global_position if jogador != null else Vector3.ZERO
		var perto: Vector3 = Lugares.NENHUM
		match str(meta.get("tipo", "")):
			"juntar":
				# Com vários itens, aponta o alvo do primeiro que ainda falta;
				# o que não sai de alvo (tábua e corda saem da oficina) cai na
				# âncora do passo.
				if recursos.has_method("mais_perto_que_rende"):
					var carga := _carga_da_meta(meta)
					for qual in carga:
						if Inventario.quantidade(str(qual)) < int(carga[qual]):
							perto = recursos.mais_perto_que_rende(str(qual), de)
							break
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
## SÓ DEPOIS DE OUTRA COISA: a cadeia não abre enquanto isto responder falso.
## A do mirante espera o Pedro terminar o tutorial — no 2D as missões do
## arraial vêm "depois que o Pedro termina de ensinar a sobreviver".
var depois_de: Callable = Callable()
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
	if not iniciado and depois_de.is_valid() and not bool(depois_de.call()):
		return
	if so_enquanto.is_valid() and not bool(so_enquanto.call()):
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
## O QUE A ENTREGA COBRA, como {id: quantos}.
##
## Duas escritas para a mesma coisa, e é de propósito: `item` com `quantos` é a
## entrega de uma coisa só — o pirão da Dona Filó, as seis canas da Candinha —, e
## `itens` é a de várias, que é a rede do Tonho ("cinco cordas e três tábuas").
## Sem número é um, que é como estava antes de qualquer conta existir.
static func _carga_da_meta(meta: Dictionary) -> Dictionary:
	var varios: Dictionary = meta.get("itens", {})
	if not varios.is_empty():
		var conta := {}
		for qual in varios:
			conta[str(qual)] = maxi(int(varios[qual]), 1)
		return conta
	var um := str(meta.get("item", ""))
	return {} if um == "" else {um: maxi(int(meta.get("quantos", 1)), 1)}


func _tentar_encontro(passo: Dictionary) -> void:
	var meta: Dictionary = passo.get("meta", {})
	var tipo := str(meta.get("tipo", ""))
	if tipo == "visitar":
		_tentar_visita(passo, meta)
		return
	if tipo == "oferendar":
		_tentar_oferenda(passo, meta)
		return
	if tipo != "levar" and tipo != "falar":
		return
	var id := str(passo.get("id", ""))
	if bool(_levados.get(id, false)):
		return
	# A ENTREGA TEM CONTA, E PODE TER MAIS DE UM ITEM. A Dona Candinha pede SEIS
	# canas, e enquanto a meta levava um só, chegar ao lado dela com uma cana
	# fechava a missão das seis: o balão saía, o passo fechava, e a conta não
	# acontecia. O Tonho pede cinco cordas E três tábuas na mesma frase, e partir
	# isso em dois passos seria partir o que ele diz de uma vez.
	var carga := _carga_da_meta(meta)
	if tipo == "levar":
		if carga.is_empty():
			return
		for qual in carga:
			if Inventario.quantidade(str(qual)) < int(carga[qual]):
				return
	var quem := _morador(str(meta.get("a_quem", "")))
	if quem == null or jogador == null:
		return
	# QUEM NÃO ESTÁ NÃO RECEBE: o mestre Quirino só encosta no píer no dia do
	# saveiro (o SaveiroVale); fora dele, escondido, a entrega espera.
	if not quem.is_visible_in_tree():
		return
	var no_chao := quem.global_position - jogador.global_position
	no_chao.y = 0.0
	if no_chao.length() > float(meta.get("raio", 3.0)):
		return

	if tipo == "levar":
		for qual in carga:
			Inventario.consumir(str(qual), int(carga[qual]))
	_levados[id] = true
	var resposta := str(meta.get("resposta", ""))
	if resposta != "" and quem.has_method("narrar"):
		quem.narrar("", resposta)


# --- os lugares da fé (#52) -----------------------------------------------------

## CHEGAR PERTO RISCA o lugar da lista, uma vez — e o vale fica sabendo
## (`visitou`), para contar o que se vê dali.
func _tentar_visita(passo: Dictionary, meta: Dictionary) -> void:
	var id := str(passo.get("id", ""))
	for lugar in _lugares_da_meta(meta):
		var chave_da_visita := _chave_da_visita(id, str(lugar))
		if bool(_levados.get(chave_da_visita, false)):
			continue
		if _perto_do_lugar(str(lugar), float(meta.get("raio", 6.0))):
			_levados[chave_da_visita] = true
			visitou.emit(str(lugar))


## A OFERENDA: com tudo na mochila e no pé do lugar, o que se leva fica lá. As
## duas condições juntas, como no 2D — quem junta tudo e gasta no caminho chega
## de mão vazia, e a conta desce sozinha.
func _tentar_oferenda(passo: Dictionary, meta: Dictionary) -> void:
	var id := str(passo.get("id", ""))
	if bool(_levados.get(id, false)):
		return
	var carga := _carga_da_meta(meta)
	if carga.is_empty():
		return
	for qual in carga:
		if Inventario.quantidade(str(qual)) < int(carga[qual]):
			return
	if not _perto_do_lugar(str(meta.get("lugar", passo.get("lugar", ""))), float(meta.get("raio", 4.0))):
		return
	for qual in carga:
		Inventario.consumir(str(qual), int(carga[qual]))
	_levados[id] = true
	var resposta := str(meta.get("resposta", ""))
	if resposta != "":
		_falar("", resposta)


## Os lugares da meta que o vale tem. Lugar que ainda não existe some da conta,
## como o passo de lugar que não existe é pulado.
func _lugares_da_meta(meta: Dictionary) -> Array:
	var lista: Array = []
	for lugar in meta.get("lugares", []):
		if _ponto_do(str(lugar)).is_finite():
			lista.append(str(lugar))
	return lista


func _visitados(passo: Dictionary) -> Array:
	var id := str(passo.get("id", ""))
	var lista: Array = []
	for lugar in _lugares_da_meta(passo.get("meta", {})):
		if bool(_levados.get(_chave_da_visita(id, str(lugar)), false)):
			lista.append(lugar)
	return lista


static func _chave_da_visita(passo: String, lugar: String) -> String:
	return "visita:%s:%s" % [passo, lugar]


func _ponto_do(lugar: String) -> Vector3:
	if ponto_do_lugar.is_valid():
		var achado = ponto_do_lugar.call(lugar)
		if achado is Vector3 and (achado as Vector3).is_finite():
			return achado
	return Lugares.ponto(lugar)


func _perto_do_lugar(lugar: String, raio: float) -> bool:
	var ali := _ponto_do(lugar)
	if not ali.is_finite() or jogador == null:
		return false
	var no_chao := ali - jogador.global_position
	no_chao.y = 0.0
	return no_chao.length() <= raio and absf(ali.y - jogador.global_position.y) < 4.0


## O passo de id `id` já fechou? É o que a fé pergunta para saber se a Dona Zefa
## já mostrou as três (o passo de contar a ela).
func passou(id: String) -> bool:
	for i in mini(missao, passos.size()):
		if str((passos[i] as Dictionary).get("id", "")) == id:
			return true
	return false
