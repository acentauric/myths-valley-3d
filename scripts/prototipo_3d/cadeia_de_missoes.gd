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
##   (`visitar` aceita `horas: [de, ate]`, a janela do relógio do vale em que chegar
##   conta — a roda na praia de noite, a maré das cinco; ver `_na_hora`.)
##
## (Vieram outros depois — levar, falar, evento, obra —, e com a fé, #52, mais
## dois: `visitar`, que risca cada lugar de uma lista ao chegar perto dele — os
## três marcos, a romaria —, e `oferendar`, que é o `levar` com um LUGAR no
## lugar de uma pessoa: a mesa do terreiro, as conchas da gameleira.)
##
##
## O QUE A CHEGADA ACRESCENTOU (docs/mundo/CHEGADA_E_MUTIROES.md)
##
##   quem_paga  o morador que paga a recompensa: o HUD diz "Recebido de Tonho",
##              e não o nome do dono da cadeia, quando quem pagou foi outro
##   entrega    também uma LISTA de entregas: a enxada E a maniva na mesma fala
##   eventos    a meta `evento` com vários acontecimentos, todos cobrados, e a
##              conta no HUD: arar, plantar e regar a primeira leira
##   mutirao    quem ajuda: {id: {item: quanto}}. Cada um vai ao lugar do passo e
##              fica lá até ele fechar; o que tem itens os entrega ao chegar
##
## O segundo existe por causa do capim do cemitério. No 2D, cortar o mato não
## põe nada na mochila — o mato some, que é o que limpar quer dizer. Contar
## pela mochila obrigaria a inventar um item "capim" no catálogo
## COMPARTILHADO, e mexer no jogo 2D por uma necessidade que é daqui.

signal missao_mudou(texto: String, alvo: Vector3, indice: int, total: int)
## Um passo fechou e pagou (ver `_pagar`): o texto diz de quem e o quê.
signal pagou(texto: String)
## A FALA SEM DONO (08/10): a resposta da oferenda descreve o que acontece no lugar dela — a onda
## levando a ostra, a toalha aberta na mesa —, e o dono da fila está longe dali. Vai ao aviso do HUD,
## sem nome e sem balão (o vale liga em `_pendurar_cadeia`).
signal narrou(texto: String)
## OS RÉIS NA ENTREGA (08/10): "reis" na carga de um passo `levar` é dinheiro (`Jogo.dinheiro`), e
## não item da mochila — é como o jogador paga a dívida do Tonho ao Seu Nicolau.
const REIS := "reis"
## UM PASSO DO MEIO DA MISSÃO FECHOU (07/10): o resumo dele, para o HUD marcar a tarefa
## cumprida — pulso, risco e sinete (`PrototypeHUD.tarefa_concluida`). O último passo não
## passa por aqui: ele é a festa da missão inteira (`CadernoDoVale.festeja`).
signal passo_cumprido(resumo: String)
## O morador entregou uma ferramenta (ver `entregar`): o texto diz o número da
## barra que a põe na mão.
signal entregou(texto: String)
## A meta `visitar` riscou um lugar — o vale conta o que se vê dali.
signal visitou(lugar: String)
## Fechou um passo que tem `cena` (a luz dourada da chapada, a cabra que desce
## da lombada): o vale a toca. A cadeia só diz o nome; quem sabe tocar é o vale.
signal cena(nome: String)

const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")
const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")
const FilaDeFalas = preload("res://scripts/prototipo_3d/fila_de_falas.gd")
## Toda cadeia viva entra neste grupo: é por ele que um morador pergunta se tem
## missão com o jogador antes de cumprimentar (`npc.gd`, `tem_missao`).
const GRUPO := &"cadeias_de_missoes"
## O QUE O MORADOR AINDA DEVE, guardado na memória da cadeia (`_levados`, que vai
## no save): a ferramenta ou a recompensa que não coube na mochila cheia, como
## "pendente:<item>:<quantos>:<n>". Ver `_dar`.
const PENDENTE := "pendente:"
## A ENTREGA DO PASSO JÁ FOI FEITA, por id: "entregou:<passo>". Ver `retomar`.
const ENTREGOU := "entregou:"
## De quanto em quanto tempo o que não coube tenta entrar na mochila de novo.
const TENTAR_DE_NOVO := 1.0
## Os avisos da mochila cheia, nos três idiomas.
const AVISOS := "res://data/entregas_pendentes.json"

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
## O ANÚNCIO NÃO ESPERA A PALAVRA, E NÃO FALA POR CIMA. Ele esperava ninguém
## falar perto, e num lugar cheio (a praça, o píer) um cumprimento emendava no
## outro: o passo nunca anunciava ("não deu para interagir" com a Dona
## Candinha). O remendo foi um prazo, `ESPERA_MAXIMA_PELA_VEZ`, seis segundos
## depois dos quais o passo falava POR CIMA de quem estivesse falando — e as
## falas se sobrepunham de propósito. Agora o anúncio acontece na hora — a
## ferramenta, o caderno, o objetivo — e a FALA dele entra na fila de falas
## (`fila_de_falas.gd`), que não deixa duas no ar e não deixa o cumprimento de
## quem passa furar a vez.
## O arremate já pedido à fila, que ainda não acabou de ser dito.
var _arremate_pedido := false
var _proxima_tentativa := 0.0
static var _avisos: Dictionary = {}
## O NOME DA MISSÃO INTEIRA ("O cemitério esquecido"), que é o que o diário
## lista e o HUD escreve em cima do objetivo — o passo é só onde ela está. Vem
## do campo `nome` do arquivo, nos três idiomas.
var nome_da_missao := ""
## O QUE O DONO DIZ NO E ENQUANTO A FILA ESTÁ TRANCADA (`dica_da_trancada`): o que fazer antes,
## "volte depois de ...", nos três idiomas (`trancada`, `trancada_en`, `trancada_es`).
var trancada_texto := ""


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
		# O RESUMO DA FALA PARA O DIÁRIO (#202), escrito à mão quando o corte
		# automático não basta: `diario`, `diario_en`, `diario_es`.
		passo["diario"] = str(IdiomaMenu.campo(passo, "diario", ""))
		# A RESPOSTA DE QUEM RECEBE também é fala do jogador ler, e também nasce
		# nos três idiomas (`resposta`, `resposta_en`, `resposta_es`).
		var meta: Dictionary = passo.get("meta", {})
		if meta.has("resposta"):
			meta["resposta"] = str(IdiomaMenu.campo(meta, "resposta", ""))
		passos.append(passo)
	chave = str(dado.get("dono", ""))
	principal = bool(dado.get("principal", false))
	nome_da_missao = str(IdiomaMenu.campo(dado, "nome", ""))
	trancada_texto = str(IdiomaMenu.campo(dado, "trancada", ""))
	arremate = dado.get("arremate", {}).duplicate()
	arremate["texto"] = str(IdiomaMenu.campo(arremate, "texto"))
	return not passos.is_empty()


func _ready() -> void:
	add_to_group(GRUPO)


## ESTE MORADOR ESTÁ NESTA MISSÃO AGORA?
##
## "Quando encostar no NPC com missão, o NPC não [deve] falar a fala de
## aproximação. Isso tá deixando o jogador confuso." O morador cumprimentava a
## três metros e meio sem saber de missão nenhuma, e a fala da missão saía logo
## depois, na mesma boca: o Tonho dizia "passa aqui de tarde" e em seguida
## respondia o bom-dia da chegada. Quem tem missão com o jogador fala a missão,
## e só ela.
##
## Está na missão quem é DONO dela e ela anda, ou vai abrir ao chegar perto;
## quem tem o arremate ainda por dizer; e quem é o destinatário do passo de
## agora ("levar" e "falar", `a_quem`) — o Tonho do bom-dia, que a fila é do
## Pedro. Fila que ainda espera outra coisa (`depois_de`) ou congelada
## (`so_enquanto`) não conta: dali não sai fala nenhuma, e o morador pode
## cumprimentar.
func envolve(morador: Node) -> bool:
	if morador == null or (so_enquanto.is_valid() and not bool(so_enquanto.call())):
		return false
	if morador == dono:
		if not iniciado:
			return comeca_perto_de > 0.0 and (not depois_de.is_valid() or bool(depois_de.call()))
		if not acabou():
			return true
		return not despedida_feita and bool(arremate.get("narra", true)) \
			and not str(arremate.get("texto", "")).is_empty()
	if not iniciado or acabou():
		return false
	var quem := str((passo_atual().get("meta", {}) as Dictionary).get("a_quem", ""))
	var dados = morador.get("dados")
	return quem != "" and dados is Dictionary and str((dados as Dictionary).get("id", "")) == quem


## Começa a conduzir, com uma folga antes do primeiro anúncio.
func comecar(folga: float) -> void:
	if iniciado:
		return
	iniciado = true
	missao = 0
	espera = folga


func total() -> int:
	return passos.size()


## O FAVOR FEITO: a fila inteira de um morador fechou, e a afinidade dele dá o salto
## (`Afinidade.POR_FAVOR`, +25 — de "Conhecido de vista" a "Gente boa"). Até 07/10 ninguém
## chamava `fez_o_favor`: conversa e presente subiam a afinidade, e cumprir o pedido do
## morador, que é o salto do 2D, não valia nada. Só para quem está na teia
## (`Afinidade.MORADORES`, data/dialogos/aldeoes.json): o Pedro e as vozes da fé ficam fora.
func _dar_o_favor() -> void:
	if dono == null or not ("dados" in dono):
		return
	var id := str(dono.dados.get("id", ""))
	if id != "" and Afinidade.MORADORES.has(id):
		Afinidade.fez_o_favor(id)


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
## `palavra_livre` ficou de fora da conta: quem decide a vez de falar é a fila de
## falas (ver `_arremate_pedido`). O parâmetro continua para quem o passa.
func correr(delta: float, _palavra_livre: bool = true) -> void:
	if acabou() and not despedida_feita and not _arremate_pedido \
			and not str(arremate.get("texto", "")).is_empty():
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
			# A DESPEDIDA SE DÁ POR FEITA QUANDO ACABA DE SER DITA, e não quando é
			# pedida: o Pedro só volta à vida de pescador depois de dizer a última
			# frase do tutorial, e não com ela esperando a vez na fila.
			_arremate_pedido = true
			# COM A VOZ DELE, quando o arremate a tem ("audio", a da chegada: 07/10, "crie um
			# áudio para o Pedro narrar a interação depois que o jogador lê o convite").
			if not _falar(str(arremate.get("audio", "")), str(arremate["texto"]), FilaDeFalas.Classe.MISSAO, "arremate:%d" % get_instance_id(),
					{"ao_terminar": _arremate_dito}):
				_arremate_dito()
		else:
			despedida_feita = true
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
			espera = 0.0
			anunciar()
		return

	var passo: Dictionary = passos[missao]
	if not (passo.get("meta", {}) as Dictionary).is_empty():
		# Meta que ACONTECE, e não só se mede: a entrega precisa de alguém para
		# tentar antes de a pergunta ser feita.
		_tentar_encontro(passo)
		_receber_o_mutirao(passo)
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
##
## MAS A FERRAMENTA, SIM. O anúncio é quem entrega o que o passo promete (a
## picareta do lajedo, o machado do avô, a foice, a vara), e salvar no respiro
## entre um passo fechar e o seguinte anunciar dava uma partida em que o anúncio
## nunca mais vinha: sem picareta, sem lajedo, sem o resto da chegada. Retomar
## entrega o que o passo ainda deve — uma vez: a marca `ENTREGOU` vai no save, e
## quem já recebeu e vendeu não ganha outra recarregando.
func retomar() -> void:
	# ZERO, E NÃO UM NÚMERO PEQUENO: o `correr` só anuncia quando `espera` VENCE,
	# então espera que nasce zerada nunca chega ao anúncio.
	espera = 0.0
	if missao < 0 or missao >= passos.size():
		return
	var passo: Dictionary = passos[missao]
	if not bool(_levados.get(_marca_da_entrega(passo), false)):
		entregar(passo)
	_registrar_no_caderno(passo)
	_mostrar_o_resumo(passo)
	_chamar_o_mutirao(passo)


## Anuncia o passo em curso: entrega o que ele promete e fala. A entrega, o
## caderno e o objetivo vêm NA HORA; a fala, na vez dela (`fila_de_falas.gd`).
## `classe` é a da fala: o anúncio que o jogador pediu com o E (a fila que abre
## na conversa) é resposta, e passa na frente dos anúncios.
##
## A ENTREGA VEM DEPOIS DE PEDIR A FALA, no mesmo quadro: com a vez livre a fala
## entra já e põe o texto dela no aviso do HUD, e o aviso da entrega ("Recebido:
## picareta. Aperte 3", ou o da mochila cheia) tem de ficar por cima dele.
func anunciar(classe: int = FilaDeFalas.Classe.MISSAO, extra: Dictionary = {}) -> void:
	var passo := passo_atual()
	if passo.is_empty():
		return
	_registrar_no_caderno(passo)
	_falar(str(passo.get("audio", "")), str(passo.get("texto", "")), classe, _origem_do_anuncio(passo), extra)
	entregar(passo)
	_mostrar_o_resumo(passo)
	_chamar_o_mutirao(passo)


## DE ONDE VEM O ANÚNCIO DE UM PASSO, para a fila de falas: o passo que fecha cala
## o próprio anúncio (`_calar_o_anuncio`), que não tem mais o que pedir.
func _origem_do_anuncio(passo: Dictionary) -> String:
	return "anuncio:%d:%s" % [get_instance_id(), str(passo.get("id", ""))]


func _calar_o_anuncio(passo: Dictionary) -> void:
	var fila := FilaDeFalas.da(self)
	if fila != null and not passo.is_empty():
		fila.calar(_origem_do_anuncio(passo))


func _arremate_dito() -> void:
	despedida_feita = true
	_arremate_pedido = false


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


## OS MARCADORES DAS ETAPAS (#186): círculo cheio é etapa feita, vazado é etapa por
## fazer. Eram "✓" e "□", e o HUD (fonte padrão) não desenhava nenhum dos dois, nem
## a Cormorant o "✓": o símbolo caía na fonte de reserva do sistema, pequeno, fino e
## fora da linha de base — parecia glifo quebrado. A Cormorant desenha "●" e "○", e
## o HUD a leva como reserva (`Identidade.fonte_do_hud`), então o marcador sai de
## uma fonte do jogo, na linha. Vale para toda missão com `etapas`, no HUD e no J.
const MARCA_FEITA := "●"
const MARCA_PENDENTE := "○"


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
				tem += mini(int(carga[qual]), _tem_para_a_meta(meta, str(qual)))
				nomes.append(_nome_do_item(str(qual)).to_lower())
			conta = "%d/%d" % [tem, pede]
			gerado = tr("Junte %s") % ", ".join(nomes)
		"obra":
			var obra := str(meta.get("obra", ""))
			gerado = tr("Faça a obra: %s") % str(Obras.dados(obra).get("nome", obra))
			# O MATERIAL DA OBRA, CONTADO À PARTE DO PASSO (08/10: "a missão continuou indicando
			# para construir a cerca como se eu tivesse o material, mesmo sem material; é
			# importante ter o contador de material independente do status da missão" — as seis
			# lenhas tinham virado as duas cordas). A mochila agora, do que a obra pede.
			var custo: Dictionary = Obras.custo(obra)
			var materiais: Array[String] = []
			var tem := 0
			var pede := 0
			for qual in custo:
				var quantos := int(custo[qual])
				var na_mochila := mini(quantos, Inventario.quantidade(str(qual)))
				materiais.append("%s %d/%d" % [_nome_do_item(str(qual)).to_lower(), na_mochila, quantos])
				tem += na_mochila
				pede += quantos
			if not custo.is_empty():
				conta = ", ".join(materiais) if materiais.size() <= 2 else "%d/%d" % [tem, pede]
		"derrubar":
			var quantos_pes := int(meta.get("quantos", 1))
			var caidos := 0
			if recursos != null and recursos.has_method("derrubados"):
				caidos = mini(quantos_pes, int(recursos.derrubados(str(meta.get("alvo", "")))))
			conta = "%d/%d" % [caidos, quantos_pes]
			gerado = tr("Corte %s") % _nome_do_item(str(meta.get("alvo", ""))).to_lower()
		"levar":
			# O QUANTITATIVO (07/10: "não informou o quantitativo; mesmo que o jogador já tenha no
			# inventário, esse dado deve ser informado"): no texto gerado, cada item com o que se
			# pede ("corda ×5") e a conta total no fim; no resumo escrito à mão, a conta de cada
			# item ("tábua 2/2, pedra 4/4"; com três ou mais, o total).
			var carga := _carga_da_meta(meta)
			var itens: Array[String] = []
			var por_item: Array[String] = []
			var tem := 0
			var pede := 0
			for qual in carga:
				var quantos := int(carga[qual])
				var na_mochila := mini(quantos, _quanto_tem(str(qual)))
				var nome := _nome_do_item(str(qual)).to_lower()
				if str(qual) == REIS:
					itens.append("%d %s" % [quantos, nome])
				else:
					itens.append("%s ×%d" % [nome, quantos] if quantos > 1 else nome)
				por_item.append("%s %d/%d" % [nome, na_mochila, quantos])
				tem += na_mochila
				pede += quantos
			conta = "%d/%d" % [tem, pede] if escrito == "" or por_item.size() > 2 else ", ".join(por_item)
			gerado = tr("Leve %s a %s") % [", ".join(itens), _nome_de(str(meta.get("a_quem", "")))]
		"falar":
			gerado = tr("Fale com %s") % _nome_de(str(meta.get("a_quem", "")))
		"evento":
			var pedidos := eventos_da_meta(meta)
			if pedidos.size() > 1:
				conta = "%d/%d" % [_eventos_feitos(meta), pedidos.size()]
		"contar":
			var vezes := int(meta.get("quantos", 1))
			conta = "%d/%d" % [mini(_contados(passo), vezes), vezes]
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
	var etapas: Array[String] = []
	for etapa in passo.get("etapas", []):
		if etapa is Dictionary:
			etapas.append("%s %s" % [MARCA_FEITA if aconteceu(str(etapa.get("evento", ""))) else MARCA_PENDENTE,
				str(IdiomaMenu.campo(etapa, "texto", ""))])
	if not etapas.is_empty():
		frase += "\n" + " · ".join(etapas)
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

## A FALA NO DIÁRIO É RESUMO (#202). O diário do J não rola, e a página da missão
## divide a altura com os objetivos: a fala inteira — que repete o que os
## objetivos já dizem ("encoste no tronco e aperte E") — continua no diálogo do
## jogo. Aqui entram as frases inteiras que cabem em `LETRAS_DA_FALA_NO_DIARIO`;
## a primeira frase sempre entra, e se ela sozinha passa do limite, corta na
## palavra, com reticência. Quem quiser um resumo melhor escreve `diario` no passo.
const LETRAS_DA_FALA_NO_DIARIO := 200

static func fala_curta(fala: String, limite: int = LETRAS_DA_FALA_NO_DIARIO) -> String:
	var inteira := fala.strip_edges()
	if inteira.length() <= limite:
		return inteira
	# A última frase que ainda cabe: o ponto, a exclamação ou a interrogação
	# seguidos de espaço (não o ":" nem o ";", que abrem frase e não fecham).
	var fim := -1
	for i in range(mini(limite, inteira.length() - 1)):
		if inteira[i] in [".", "!", "?", "…"] and inteira[i + 1] == " ":
			fim = i + 1
	if fim > 0:
		return inteira.substr(0, fim).strip_edges()
	var corte := inteira.rfind(" ", limite)
	if corte <= 0:
		corte = limite
	return inteira.substr(0, corte).strip_edges().rstrip(",;:—-") + "…"


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
		# A fala em resumo para o diário (#202); a inteira fica no `texto`.
		"fala_curta": _fala_no_diario(passo),
		"passo": missao + 1,
		"passos": passos.size(),
		# O que o passo paga, para o diário mostrar em ícones (#107).
		"recompensa": (passo.get("recompensa", {}) as Dictionary).duplicate(),
		"feitos": _feitos(),
	})
	var alvo := posicao_do_passo(missao)
	if alvo != Vector3.ZERO:
		CadernoDoVale.apontar(id, alvo)
	_acertar_o_caderno(passo)


## O que o diário mostra da fala deste passo: o resumo escrito à mão, ou o corte.
func _fala_no_diario(passo: Dictionary) -> String:
	var escrito := str(passo.get("diario", "")).strip_edges()
	return escrito if escrito != "" else fala_curta(str(passo.get("texto", "")))


## O id do passo no caderno, com o dono na frente para duas cadeias não colidirem
## num passo de mesmo nome.
func _id_no_caderno(passo: Dictionary) -> String:
	var id := str(passo.get("id", ""))
	return "" if id == "" else "%s_%s" % [chave, id] if chave != "" else id


func _nome_do_item(item: String) -> String:
	if item == REIS:
		return tr("réis")
	return Catalogo.nome(item)


func _nome_de(quem: String) -> String:
	var no := _morador(quem)
	if no == null or not ("dados" in no):
		return quem
	return str((no.dados as Dictionary).get("nome", quem))

## A FALA DO DONO, NA FILA DE FALAS (`npc.narrar`, `voz_do_marco.narrar`):
## `classe` e `origem` dizem à fila quem é ela, e `extra` leva o resto do pedido
## (`no_lugar`, `ao_terminar`). Devolve se havia quem falasse.
func _falar(audio: String, texto: String, classe: int = FilaDeFalas.Classe.MISSAO,
		origem: String = "", extra: Dictionary = {}) -> bool:
	if dono == null or not dono.has_method("narrar"):
		return false
	var pedido := {"classe": classe, "origem": origem}
	pedido.merge(extra, true)
	dono.narrar(audio, texto, pedido)
	return true


## O nome de quem fala na frente da fala, que é como o HUD do vale já mostrava
## as missões do Pedro.
func _com_o_nome(texto: String) -> String:
	var nome := _nome_do_dono()
	return texto if nome.is_empty() else "%s: %s" % [nome, texto]


func _nome_do_dono() -> String:
	if dono == null or not ("dados" in dono):
		return ""
	return str((dono.dados as Dictionary).get("nome", ""))


## O MORADOR ENTREGA A FERRAMENTA AO ANUNCIAR, NA BARRA DE MÃO.
##
## É a regra 1 do tutorial do 2D — o NPC anuncia antes de cobrar — levada a
## sério: quem ouve "toma o machado e vai cortar" precisa ter o machado na
## mesma frase. Pedir primeiro e entregar depois é o que faz o jogador rodar o
## mapa procurando uma ferramenta que ninguém deu.
##
## NA BARRA, E NÃO NA MÃO. Bater exige a ferramenta escolhida na barra
## (`Recursos3D._tem_ferramenta`), e a entrega chegou a escolhê-la sozinha —
## até o dia em que a primeira leira fechou com o balde na mão e o machado do
## passo seguinte tomou o lugar dele: "ele trocou automaticamente para o
## machado de madeira. Isso não deve acontecer." A mão é do jogador. A
## ferramenta vai para um dos dez da barra, e o HUD diz o número que a põe na
## mão (ver `_por_na_barra`) — é o que a fala do Pedro já ensinava: "o número
## dele na barra põe o machado na mão".
##
## Entrega uma vez só: o anúncio de cada passo acontece uma vez, e retomar o
## passo não reanuncia (mas entrega o que faltou: ver `retomar`).
##
## UMA ENTREGA OU VÁRIAS: a primeira leira pede a enxada E a maniva na mesma
## fala. A PRIMEIRA ferramenta da lista é a que o HUD aponta na barra — a
## enxada, que é o primeiro gesto; a maniva vai para a mochila.
##
## COM A MOCHILA CHEIA a ferramenta não se perde: fica devendo (`_dar`), o HUD
## diz que falta espaço, e ela entra sozinha quando abrir um. Antes ela sumia, e
## o HUD não dizia nada — e passo sem a ferramenta que ele cobra é passo preso.
func entregar(passo: Dictionary) -> void:
	_levados[_marca_da_entrega(passo)] = true
	# O GOLPE QUE O PASSO ENSINA (`ensina`), na mesma fala que o pede: o golpe
	# forte, a ginga, a meia-lua e a rasteira do `Luta` só valem para quem os
	# aprendeu, e no vale só a missão os ensina.
	if str(passo.get("ensina", "")) != "":
		Luta.aprender(str(passo["ensina"]))
	var apontar := ""
	for entrega: Dictionary in entregas_do_passo(passo):
		var item := str(entrega.get("item", ""))
		if item == "":
			continue
		# Não duplica um item já recebido, vestido ou devido em uma partida salva.
		if not Inventario.tem(item) and not _na_mao(item) and not _devendo(item):
			if not _dar(item, int(entrega.get("quantidade", 1))):
				continue
		if apontar == "":
			apontar = item if Catalogo.tipo(item) == "ferramenta" or Equipamento.e_equipamento(item) else ""
	if apontar != "" and Inventario.tem(apontar):
		_por_na_barra(apontar)


## A marca de que a entrega deste passo já foi feita (ver `retomar`).
static func _marca_da_entrega(passo: Dictionary) -> String:
	return ENTREGOU + str(passo.get("id", ""))


## DÁ O ITEM, OU FICA DEVENDO. Com a mochila cheia ele fica guardado na memória
## da cadeia (vai no save), o HUD diz que falta espaço, e a cada TENTAR_DE_NOVO
## ele tenta entrar (`_entregar_o_que_ficou`). Devolve se entrou agora.
func _dar(item: String, quantidade: int, avisar := true) -> bool:
	if Inventario.adicionar(item, quantidade):
		return true
	var n := 0
	while _levados.has("%s%s:%d:%d" % [PENDENTE, item, quantidade, n]):
		n += 1
	_levados["%s%s:%d:%d" % [PENDENTE, item, quantidade, n]] = true
	_proxima_tentativa = TENTAR_DE_NOVO
	if avisar:
		entregou.emit(_aviso("mochila_cheia") % ["%d %s" % [quantidade, _nome_do_item(item).to_lower()], _nome_do_dono()])
	return false


## Este item está guardado, esperando espaço na mochila?
func _devendo(item: String) -> bool:
	for chave in _levados:
		if str(chave).begins_with(PENDENTE + item + ":"):
			return true
	return false


## O QUE NÃO COUBE ENTRA QUANDO ABRE ESPAÇO, com o recado do que entrou; a
## ferramenta vai para a barra, como na entrega.
func _entregar_o_que_ficou() -> void:
	for chave in _levados.keys():
		var texto := str(chave)
		if not texto.begins_with(PENDENTE):
			continue
		var partes := texto.trim_prefix(PENDENTE).split(":")
		if partes.size() < 2 or not Catalogo.existe(partes[0]):
			_levados.erase(chave)
			continue
		var item := partes[0]
		var quantidade := maxi(int(partes[1]), 1)
		if not Inventario.adicionar(item, quantidade):
			return
		_levados.erase(chave)
		pagou.emit(_aviso("recebido_depois") % [_nome_do_dono(), "%d %s" % [quantidade, _nome_do_item(item).to_lower()]])
		if Catalogo.tipo(item) == "ferramenta" or Equipamento.e_equipamento(item):
			_por_na_barra(item)


## O AVISO `chave` de data/entregas_pendentes.json, no idioma do jogo.
static func _aviso(chave: String) -> String:
	if _avisos.is_empty():
		var lido = JSON.parse_string(FileAccess.get_file_as_string(AVISOS))
		_avisos = lido if lido is Dictionary else {"_vazio": true}
	var dado = _avisos.get(chave, {})
	var texto := str(IdiomaMenu.campo(dado, "texto", "")) if dado is Dictionary else ""
	return texto if texto.count("%s") == 2 else "%s · %s"


## As entregas do passo como lista, nas duas formas que o dado aceita: um objeto
## `{"item", "quantidade"}` ou uma lista deles.
static func entregas_do_passo(passo: Dictionary) -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	var bruto = passo.get("entrega", {})
	if bruto is Dictionary:
		if not (bruto as Dictionary).is_empty():
			lista.append(bruto)
	elif bruto is Array:
		for uma in bruto:
			if uma is Dictionary and not (uma as Dictionary).is_empty():
				lista.append(uma)
	return lista


## O item está na mão agora — pela barra ou pelo encaixe?
func _na_mao(item: String) -> bool:
	return Equipamento.em_uso(item)


## A FERRAMENTA FICA NA BARRA, e o HUD diz o número (ver `entregar`). O
## `Inventario.adicionar` já enche a barra antes da mochila; com a barra cheia
## ela fica na mochila, e o HUD diz isso também, em vez de o jogador apertar
## número atrás de número. A PEÇA DE VESTIR vai para o corpo, como antes: vestir
## não mexe no que está na mão.
func _por_na_barra(item: String) -> void:
	if _na_mao(item):
		return
	if Equipamento.e_equipamento(item):
		for i in Inventario.espacos.size():
			if str((Inventario.espacos[i] as Dictionary).get("id", "")) == item:
				Equipamento.equipar_do_espaco(i)
				return
		return
	if Catalogo.tipo(item) != "ferramenta":
		return
	var nome := tr(Catalogo.nome(item))
	for i in Inventario.ESPACOS_MAO:
		if str((Inventario.espacos[i] as Dictionary).get("id", "")) == item:
			entregou.emit(tr("Recebido: %s. Aperte %s para usar.") % [nome, Inventario.rotulo_do_espaco(i)])
			return
	entregou.emit(tr("Recebido: %s, na mochila. Arraste para a barra de mão (%s abre a mochila).") % [nome, Atalhos.letra("mochila")])


## A meta do passo ainda não foi cumprida? Passo sem meta nunca falta.
func falta_a_meta(passo: Dictionary) -> bool:
	var meta: Dictionary = passo.get("meta", {})
	if meta.is_empty():
		return false
	match str(meta.get("tipo", "")):
		"juntar":
			# UM ITEM OU VÁRIOS: `item`/`quantos`, ou `itens` {id: quanto} — o
			# material do mirante é tábua, pedra e corda de uma vez. Com
			# `equivale`, a lenha da ponte conta a tábua já serrada.
			var carga := _carga_da_meta(meta)
			for qual in carga:
				if _tem_para_a_meta(meta, str(qual)) < int(carga[qual]):
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
			# encontro. Com `eventos`, todos os da lista.
			return _eventos_feitos(meta) < eventos_da_meta(meta).size()
		"contar":
			# O MESMO ACONTECIMENTO, N VEZES, contadas desde que o passo abriu: o
			# 'contar' do 2D, que não volta atrás (o golpe forte dado não se
			# desdá).
			return _contados(passo) < int(meta.get("quantos", 1))
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
	# O PASSO QUE CONTA ESTE ACONTECIMENTO ('contar': três golpes fortes, dois
	# peixes): cada vez vira uma lembrança numerada, que vai no save como as
	# outras — recarregar no meio da conta não a zera.
	var passo := passo_atual()
	var meta: Dictionary = passo.get("meta", {})
	if iniciado and str(meta.get("tipo", "")) == "contar" and str(meta.get("evento", "")) == nome:
		_levados["conta:%s:%d" % [str(passo.get("id", "")), _contados(passo) + 1]] = true


## Quantas vezes o acontecimento do passo 'contar' já aconteceu nele.
func _contados(passo: Dictionary) -> int:
	var prefixo := "conta:%s:" % str(passo.get("id", ""))
	var vezes := 0
	for chave in _levados:
		if str(chave).begins_with(prefixo):
			vezes += 1
	return vezes


## O acontecimento `nome` já chegou a esta fila (`registrar_evento`)?
func aconteceu(nome: String) -> bool:
	return bool(_levados.get(_chave_do_evento(nome), false))


static func _chave_do_evento(nome: String) -> String:
	return "evento:" + nome


## Os acontecimentos que a meta cobra: `eventos` (todos), ou o `evento` só.
static func eventos_da_meta(meta: Dictionary) -> Array[String]:
	var lista: Array[String] = []
	for nome in meta.get("eventos", []):
		lista.append(str(nome))
	if lista.is_empty() and str(meta.get("evento", "")) != "":
		lista.append(str(meta["evento"]))
	return lista


func _eventos_feitos(meta: Dictionary) -> int:
	var feitos := 0
	for nome in eventos_da_meta(meta):
		if bool(_levados.get(_chave_do_evento(nome), false)):
			feitos += 1
	return feitos


## A RECOMPENSA DO PASSO (#48), paga quando ele fecha: itens e réis, com os
## números do jogo 2D (bloco `recompensas` do `arraial.json` de lá). Paga UMA
## vez porque o passo só fecha uma vez — carregar a partida põe a cadeia no
## passo seguinte, e `avancar` não roda de novo para o que já fechou.
##
## O HUD diz o que se ganhou (`pagou`), e o diário escreve ao lado do
## objetivo riscado (`_feitos`).
##
## O QUE NÃO COUBE NA MOCHILA fica devendo (`_dar`): o HUD diz "Recebido" só do
## que entrou, e o resto entra quando abrir espaço.
func _pagar(passo: Dictionary) -> void:
	var recompensa: Dictionary = passo.get("recompensa", {})
	if recompensa.is_empty():
		return
	var entrou: Array[String] = []
	var ficou: Array[String] = []
	for chave in recompensa:
		var quanto := int(recompensa[chave])
		if str(chave) == "reis":
			Jogo.dinheiro += quanto
			entrou.append(tr("%d réis") % quanto)
		elif str(chave) == "xp":
			# As missões pagam XP (#107, decisão do autor em 06/10): pela teia de
			# talentos, como as obras e o trabalho.
			Talentos.ganhar_pontos(float(quanto))
		elif Catalogo.existe(str(chave)):
			var nome := "%d %s" % [quanto, _nome_do_item(str(chave)).to_lower()]
			if _dar(str(chave), quanto, false):
				entrou.append(nome)
			else:
				ficou.append(nome)
	if not entrou.is_empty():
		pagou.emit(tr("Recebido de %s: %s") % [_quem_paga(passo), ", ".join(entrou)])
	# O aviso da mochila cheia por último: o HUD mostra o recado mais novo.
	if not ficou.is_empty():
		entregou.emit(_aviso("mochila_cheia") % [", ".join(ficou), _quem_paga(passo)])


## O QUE O PASSO GASTA (`gasta`, #217): a chave que a Dona Zefa deu é usada ao abrir a porta da casa do
## tio, e o passo `casa`, que fecha quando o jogador entra, a tira da mochila ("gasta": {"chave_da_casa": 1}).
## O aviso do que aconteceu é o `aviso_gasta` do passo (nos idiomas do jogo), e vai pelo mesmo canal da entrega
## (`entregou`). Gasta só o que há: passo pulado, sem a chave, não deve nada.
func _gastar(passo: Dictionary) -> void:
	var gasta = passo.get("gasta", {})
	if not (gasta is Dictionary) or (gasta as Dictionary).is_empty():
		return
	var gastou := false
	for item in gasta:
		if Catalogo.existe(str(item)) and Inventario.consumir(str(item), int(gasta[item])):
			gastou = true
	var aviso := str(IdiomaMenu.campo(passo, "aviso_gasta", ""))
	if gastou and aviso != "":
		entregou.emit(aviso)


## QUEM PAGA é quem pediu. O Pedro conduz a chegada, mas o peixe é do Tonho e a
## garapa é da Dona Candinha: o HUD dizer "Recebido de Pedro" seria pôr na boca
## dele o agrado dos outros. Sem `quem_paga`, é o dono da cadeia, como sempre.
func _quem_paga(passo: Dictionary) -> String:
	var quem := str(passo.get("quem_paga", ""))
	return _nome_do_dono() if quem == "" else _nome_de(quem)


func _texto_da_recompensa(passo: Dictionary) -> String:
	var partes: Array[String] = []
	var recompensa: Dictionary = passo.get("recompensa", {})
	for chave in recompensa:
		var quanto := int(recompensa[chave])
		if str(chave) == "reis":
			partes.append(tr("%d réis") % quanto)
		elif str(chave) == "xp":
			partes.append("%d XP" % quanto)
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
		# O ANÚNCIO DO PASSO QUE FECHOU NÃO TEM MAIS O QUE PEDIR: sai da fila de
		# falas, ou do ar, se ainda estava lá. O jogador já fez o que ele dizia, e
		# a fala inteira continua no caderno (J).
		_calar_o_anuncio(fechando)
		_pagar(fechando)
		_gastar(fechando)
		_dispensar_o_mutirao(fechando)
		# MISSÃO DE FÉ RENDE NA FÉ ATIVA, e no ofício também, como no 2D
		# (`Arraial._fechar_a_missao_da_fe`). Sem fé ainda, o `Fe` não credita.
		if bool(fechando.get("xp_de_fe", false)):
			Fe.ganhar("missao")
			Talentos.ganhar("missao")
		# A FESTA SÓ NO ÚLTIMO PASSO (07/10), com o nome da missão inteira em vez do
		# passo: "Chegada ao arraial", e não "A chave com a Dona Zefa".
		var ultimo := missao + 1 >= passos.size()
		# O FAVOR DA AFINIDADE (07/10, docs/projeto/MISSOES_SECUNDARIAS.md): fechar a fila
		# inteira de um morador da teia é o salto da afinidade, como no 2D.
		if ultimo:
			_dar_o_favor()
		else:
			passo_cumprido.emit(resumo_do_passo(fechando))
		CadernoDoVale.concluir(_id_no_caderno(fechando),
			{"titulo": nome_da_missao if nome_da_missao != "" else _titulo_do_passo(fechando), "missao": "",
				"quem": _nome_do_dono()} if ultimo else null)
		if str(fechando.get("cena", "")) != "":
			cena.emit(str(fechando["cena"]))
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
				var tem := mini(pede, _tem_para_a_meta(meta, str(qual)))
				tem_tudo += tem
				pede_tudo += pede
				partes.append("%s %d/%d" % [_nome_do_item(str(qual)), tem, pede])
			var linha := "Juntar %s: %d de %d" % [_nome_do_item(str(carga.keys()[0])), tem_tudo, pede_tudo] \
				if carga.size() == 1 else "Juntar " + " · ".join(partes)
			CadernoDoVale.andar(id, tem_tudo, pede_tudo, linha)
		"evento":
			CadernoDoVale.andar(id, _eventos_feitos(meta), maxi(eventos_da_meta(meta).size(), 1), str(passo.get("resumo", "")))
		"contar":
			var vezes := int(meta.get("quantos", 1))
			CadernoDoVale.andar(id, mini(_contados(passo), vezes), vezes, str(passo.get("resumo", "")))
		"obra":
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
						mini(pedidas, _quanto_tem(str(qual)))])
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
## Passo que pede trabalho escolhe uma fonte próxima e mantém o destino até
## ela se esgotar. Contornar obstáculos não troca a árvore a cada quadro.
## Quem ouve "me traga duas achas" precisa de seta para onde há tronco;
## sem fonte elegível, o marcador cai na âncora do lugar.
var _chave_do_alvo_material := ""
var _ponto_do_alvo_material := Vector3.INF
var _fonte_do_alvo_material: Node = null
var _item_do_alvo_material := ""


func _alvo_material(qual: String, de: Vector3) -> Vector3:
	# A fonte escolhida permanece durante o trajeto; só muda quando se esgota.
	if qual == _item_do_alvo_material and is_instance_valid(_fonte_do_alvo_material) and _ponto_do_alvo_material.is_finite():
		var ainda: Vector3 = _fonte_do_alvo_material.mais_perto_que_rende(qual, _ponto_do_alvo_material)
		if ainda.is_finite() and ainda.distance_to(_ponto_do_alvo_material) < 0.05:
			return _ponto_do_alvo_material
		de = _ponto_do_alvo_material
	var fontes: Array[Node] = [recursos]
	if jogador != null:
		var arvores := jogador.get_tree().get_first_node_in_group("arvores_do_vale")
		if arvores != null:
			fontes.append(arvores)
	for fonte in fontes:
		if fonte == null or not fonte.has_method("mais_perto_que_rende"):
			continue
		var ponto: Vector3 = fonte.mais_perto_que_rende(qual, de)
		if ponto.is_finite():
			_ponto_do_alvo_material = ponto
			_fonte_do_alvo_material = fonte
			_item_do_alvo_material = qual
			return ponto
	return Lugares.NENHUM


func posicao_do_passo(indice: int) -> Vector3:
	if indice < 0 or indice >= passos.size():
		return Vector3.ZERO
	var passo: Dictionary = passos[indice]
	var meta: Dictionary = passo.get("meta", {})
	# Entrar numa casa pede a passagem da porta, e nao o centro da casca.
	var evento_da_entrada := str(meta.get("evento", ""))
	if evento_da_entrada.begins_with("entrou:") and is_inside_tree():
		var interiores := get_tree().get_first_node_in_group("interiores")
		if interiores != null:
			var sala: Node3D = interiores.sala_de(evento_da_entrada.trim_prefix("entrou:"))
			if sala != null:
				return sala.soleira_de_fora()
	var chave_alvo := "%d:%s" % [indice, JSON.stringify(meta)]
	if chave_alvo != _chave_do_alvo_material:
		_chave_do_alvo_material = chave_alvo
		_ponto_do_alvo_material = Vector3.INF
		_fonte_do_alvo_material = null
		_item_do_alvo_material = ""
	if str(meta.get("tipo", "")) == "evento" and passo.has("etapas") and is_inside_tree():
		var lavoura := get_tree().get_first_node_in_group("lavoura")
		if lavoura != null:
			for evento in eventos_da_meta(meta):
				if not aconteceu(evento):
					var de: Vector3 = jogador.global_position if jogador != null else Vector3.ZERO
					var ponto: Vector3 = lavoura.alvo_da_etapa(evento, de)
					if ponto.is_finite():
						return ponto
					break
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
						if _tem_para_a_meta(meta, str(qual)) < int(carga[qual]):
							perto = _alvo_material(str(qual), de)
							if perto != Lugares.NENHUM:
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


## A FILA SE ABRE CONVERSANDO COM O DONO: maior que zero, ela espera o jogador
## chegar perto do dono e apertar E (`interagir`). Zero quer dizer "quem abre é
## outro" — é o caso do Pedro, que abre no `saudar()`, e das filas da fé, que
## abrem na entrada numa fé.
##
## O Damião abre assim: o jogador sobe ao cemitério, vai falar com ele, e a
## conversa começa. No jogo 2D quem manda subir lá é a Dona Zefa; enquanto ela
## não tiver fila de missões no vale, falar com ele faz o mesmo serviço e não
## deixa a missão inalcançável. Abria sozinha ao chegar perto, até 05/10/2026:
## "o ideal é o Pedro ensinar a apertar E para iniciar as interações com os
## NPCs".
var comeca_perto_de := 0.0
## O AVISO DA TRANCADA SÓ SE DÁ QUANDO ISTO RESPONDER VERDADEIRO (07/10, os favores dos
## moradores, docs/projeto/MISSOES_SECUNDARIAS.md). Uma fila trancada pela AFINIDADE não pode
## tomar a conversa do morador no primeiro encontro: o aviso ("a gente mal se conhece") no
## lugar da fala dele era o que o jogador ouvia sempre — e a conversa diária, que é o que sobe
## a afinidade, nunca acontecia. Sem resposta, o aviso vale como antes (o Damião, o Tonho).
var avisa_a_trancada: Callable = Callable()
## O AVISO SE REPETE A CADA E? Sim para quem só tem isso a dizer (o Damião sem o machado); não
## para a fila trancada pela afinidade, que avisa uma vez e devolve a conversa ao morador.
var aviso_repete := true
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
	# O QUE FICOU DEVENDO tenta entrar na mochila de tempos em tempos (`_dar`).
	_proxima_tentativa -= delta
	if _proxima_tentativa <= 0.0:
		_proxima_tentativa = TENTAR_DE_NOVO
		_entregar_o_que_ficou()
	if not iniciado and depois_de.is_valid() and not bool(depois_de.call()):
		return
	if so_enquanto.is_valid() and not bool(so_enquanto.call()):
		return
	# QUEM ABRE A FILA DE UM MORADOR É O E (`interagir`): ele espera o jogador ir
	# falar com ele, e não começa a falar sozinho quando o jogador passa perto.
	if comeca_perto_de > 0.0 and not iniciado:
		return
	correr(delta)


## O MORADOR DE ID `quem`, ou null. Pergunta respondida de fora — ver
## `achar_morador`.
func _morador(quem: String) -> Node3D:
	if quem == "" or not achar_morador.is_valid():
		return null
	var achado = achar_morador.call(quem)
	return achado as Node3D


## O ENCONTRO: falar com quem espera (o E ao lado dele, `interagir`) — com a
## coisa na mão, ou de mãos vazias.
##
## São duas metas com o mesmo corpo. "Levar" pede o item junto; "falar" só pede
## que o jogador vá falar. Escrevê-las separadas seria ter a mesma travessia
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
	# O MATERIAL DE UMA OBRA PELA CONTA DE HOJE (`da_obra`): com a prancheta do
	# canteiro, o mirante pede dezoito tábuas e não vinte. O passo que manda
	# juntar cobra o que a obra vai cobrar — no 2D, "a conta de hoje".
	var da_obra := str(meta.get("da_obra", ""))
	if da_obra != "":
		var custo := {}
		var conta: Dictionary = Obras.custo(da_obra)
		for qual in conta:
			custo[str(qual)] = maxi(int(conta[qual]), 1)
		return custo
	var varios: Dictionary = meta.get("itens", {})
	if not varios.is_empty():
		var conta := {}
		for qual in varios:
			conta[str(qual)] = maxi(int(varios[qual]), 1)
		return conta
	var um := str(meta.get("item", ""))
	if um != "" and meta.has("equivale"):
		return {um: alvo_da_equivalencia(meta)}
	return {} if um == "" else {um: maxi(int(meta.get("quantos", 1)), 1)}


## A CONTA DA LENHA DA PONTE, tirada das receitas (`equivale`, o
## `Missoes.contagem` do 2D): a bancada rodada tantas vezes quanto a peça pedida
## exige, cada vez com o seu custo no item. Doze tábuas a duas lenhas e quatro
## cordas a três são trinta e seis. O número não se escreve à mão — a obra da
## oficina que rende mais tira lenha da conta.
static func alvo_da_equivalencia(meta: Dictionary) -> int:
	var qual := str(meta.get("item", ""))
	var credito: Dictionary = meta.get("equivale", {})
	var alvo := 0
	for peca in credito:
		var por_vez := int((Oficina.dados(str(peca)).get("custo", {}) as Dictionary).get(qual, 0))
		alvo += ceili(float(int(credito[peca])) / float(Oficina.rende(str(peca)))) * por_vez
	return maxi(alvo, 1)


## QUANTO DO ITEM A META CONTA: o que está na mochila e, com `equivale`, o que já
## virou outra peça na bancada — até o tanto dela que a meta pede. Sem isto,
## quem serra a tábua antes de juntar a lenha toda vê a conta voltar atrás, e a
## missão dos trinta e seis paus pede mais paus. A conta que o HUD mostra e a que
## fecha o passo são esta mesma.
static func _tem_para_a_meta(meta: Dictionary, qual: String) -> int:
	var tem := Inventario.quantidade(qual)
	if str(meta.get("item", "")) != qual:
		return tem
	var credito: Dictionary = meta.get("equivale", {})
	for peca in credito:
		var por_vez := int((Oficina.dados(str(peca)).get("custo", {}) as Dictionary).get(qual, 0))
		var feitas := mini(Inventario.quantidade(str(peca)), int(credito[peca]))
		tem += ceili(float(feitas) / float(Oficina.rende(str(peca)))) * por_vez
	return tem


func _tentar_encontro(passo: Dictionary) -> void:
	var meta: Dictionary = passo.get("meta", {})
	var tipo := str(meta.get("tipo", ""))
	if tipo == "visitar":
		_tentar_visita(passo, meta)
	elif tipo == "oferendar":
		_tentar_oferenda(passo, meta)
	# "Levar" e "falar" não fecham mais ao chegar perto: fecham no E, ao lado de
	# quem recebe (`interagir`).


## O E AO LADO DE UM MORADOR (`tecla_dos_moradores.gd`), perguntado a cada fila.
## "O ideal é o Pedro ensinar a apertar E para iniciar as interações com os
## NPCs, incluindo cumprir etapas de missões." Devolve se esta fila usou a
## conversa:
##
##   - o dono da fila que espera o jogador vir falar (`comeca_perto_de`) a abre
##     e diz o primeiro passo;
##   - quem o passo de agora manda procurar (`falar`), ou a quem levar alguma
##     coisa (`levar`, com tudo na mochila), recebe e responde.
##
## A RESPOSTA DO E É FALA, E ESPERA A VEZ (`fila_de_falas.gd`) como qualquer
## outra — mas é a primeira da fila (`Classe.CONVERSA`), e quem foi procurado no
## meio de uma fala dele troca essa fala pela resposta (`no_lugar`).
func interagir(morador: Node3D) -> bool:
	match o_que_o_e_faz(morador):
		"abrir":
			comecar(0.0)
			anunciar(FilaDeFalas.Classe.CONVERSA, {"no_lugar": true})
			return true
		"falar", "entregar":
			var passo := passo_atual()
			# O PASSO QUE AINDA NÃO SE ANUNCIOU — o respiro entre um passo e outro —
			# se cumpre do mesmo jeito: quem foi direto à pessoa recebe junto o que o
			# anúncio daria, a ferramenta e a linha no caderno, sem a fala.
			if espera > 0.0:
				espera = 0.0
				entregar(passo)
				_registrar_no_caderno(passo)
				_mostrar_o_resumo(passo)
			_encontrar(passo, morador)
			return true
	return false


## O QUE O E FARIA COM ESTE MORADOR, nesta fila: "abrir", "falar", "entregar",
## ou "" (nada aqui). É o que a dica da tecla diz.
func o_que_o_e_faz(morador: Node3D) -> String:
	if morador == null or dono == null or (so_enquanto.is_valid() and not bool(so_enquanto.call())):
		return ""
	if not iniciado:
		if morador == dono and comeca_perto_de > 0.0 and (not depois_de.is_valid() or bool(depois_de.call())):
			return "abrir"
		return ""
	if acabou():
		return ""
	var passo := passo_atual()
	if not _recebe(passo, morador):
		return ""
	return "entregar" if str((passo.get("meta", {}) as Dictionary).get("tipo", "")) == "levar" else "falar"


## O passo manda o jogador a este morador, e ele já pode receber?
##
## A ENTREGA TEM CONTA, E PODE TER MAIS DE UM ITEM. A Dona Candinha pede SEIS
## canas, e enquanto a meta levava um só, chegar ao lado dela com uma cana
## fechava a missão das seis. O Tonho pede cinco cordas E três tábuas na mesma
## frase, e partir isso em dois passos seria partir o que ele diz de uma vez.
func _recebe(passo: Dictionary, morador: Node3D) -> bool:
	var meta: Dictionary = passo.get("meta", {})
	var tipo := str(meta.get("tipo", ""))
	if tipo != "levar" and tipo != "falar":
		return false
	if bool(_levados.get(str(passo.get("id", "")), false)):
		return false
	var dados = morador.get("dados")
	if not (dados is Dictionary) or str((dados as Dictionary).get("id", "")) != str(meta.get("a_quem", "")):
		return false
	# QUEM NÃO ESTÁ NÃO RECEBE: o mestre Quirino só encosta no píer no dia do
	# saveiro (o SaveiroVale); fora dele, escondido, a entrega espera.
	if not morador.is_visible_in_tree():
		return false
	if tipo == "levar":
		var carga := _carga_da_meta(meta)
		if carga.is_empty():
			return false
		for qual in carga:
			if _quanto_tem(str(qual)) < int(carga[qual]):
				return false
	return true


## Quanto o jogador tem disto: réis na bolsa (`Jogo.dinheiro`), ou o item na mochila.
func _quanto_tem(qual: String) -> int:
	return int(Jogo.dinheiro) if qual == REIS else Inventario.quantidade(qual)


## O ENCONTRO: o que se leva sai da mochila, a memória guarda que aconteceu, e
## QUEM FALA NO FIM É QUEM RECEBE, e não quem pediu.
##
## O anúncio do passo cala antes: o jogador acabou de fazer o que ele pedia, e a
## resposta não espera o fim de um pedido já cumprido.
func _encontrar(passo: Dictionary, quem: Node3D) -> void:
	var meta: Dictionary = passo.get("meta", {})
	if str(meta.get("tipo", "")) == "levar":
		var carga := _carga_da_meta(meta)
		for qual in carga:
			if str(qual) == REIS:
				Jogo.dinheiro = maxi(0, int(Jogo.dinheiro) - int(carga[qual]))
			else:
				Inventario.consumir(str(qual), int(carga[qual]))
	_levados[str(passo.get("id", ""))] = true
	_calar_o_anuncio(passo)
	var resposta := str(meta.get("resposta", ""))
	if resposta != "" and quem.has_method("narrar"):
		quem.narrar("", resposta, {"classe": FilaDeFalas.Classe.CONVERSA, "no_lugar": true,
			"origem": "resposta:%d:%s" % [get_instance_id(), str(passo.get("id", ""))]})


# --- os lugares da fé (#52) -----------------------------------------------------

## CHEGAR PERTO RISCA o lugar da lista, uma vez — e o vale fica sabendo
## (`visitou`), para contar o que se vê dali.
func _tentar_visita(passo: Dictionary, meta: Dictionary) -> void:
	var id := str(passo.get("id", ""))
	# A HORA DO PASSO (07/10, docs/projeto/MISSOES_SECUNDARIAS.md, fase 3): a roda na praia é de
	# noite, a maré das cinco é de madrugada, a vigília do sino vira a meia-noite. Fora da janela,
	# chegar não risca o lugar.
	if not _na_hora(meta):
		return
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
	_calar_o_anuncio(passo)
	var resposta := str(meta.get("resposta", ""))
	if resposta != "":
		narrou.emit(resposta)


## A JANELA DE HORAS DA META, `"horas": [de, ate]` no relógio do vale (`Dia.hora`, 0 a 24): sem
## ela, qualquer hora serve; com ela, só dentro — e a janela pode virar a meia-noite ([20, 5]).
func _na_hora(meta: Dictionary) -> bool:
	var horas: Array = meta.get("horas", [])
	if horas.size() < 2:
		return true
	var agora := float(Dia.hora)
	var de := float(horas[0])
	var ate := float(horas[1])
	if de <= ate:
		return agora >= de and agora < ate
	return agora >= de or agora < ate


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


# --- o mutirão --------------------------------------------------------------------

## O MUTIRÃO: obra do arraial se faz junto. "Uns foram ajudando os outros nas
## passagens quase virgens" é o capítulo 6; aqui é o dia a dia — a corda do poço,
## a carroça do Seu Benedito.
##
## Quem ajuda (`mutirao` no passo) vai ao lugar do passo ao anúncio, numa roda em
## volta dele, e fica até o passo fechar: dia e noite, que mutirão espera a obra.
## Quem tem itens no dado os entrega AO CHEGAR, e o HUD diz quem trouxe o quê —
## é o que faz o mutirão ser mecânica, e não enfeite: o Cosme chega com as
## tábuas que faltavam. Entrega uma vez (`_levados`, que vai no save).
##
## A RODA TEM O RAIO DO LUGAR (`roda` no passo): o poço é um ponto, e 2,4 u em
## volta dele é o terreiro; a casa do Seu Benedito tem 2,6 u de meia largura, e a
## roda dela precisa passar das paredes. Quem chega perto do LUGAR — e não do
## seu ponto exato da roda, que pode ser canto que a malha não alcança — chegou.
const RAIO_DA_RODA := 2.4
const CHEGOU_AO_MUTIRAO := 1.8


func _ajudantes(passo: Dictionary) -> Dictionary:
	var bruto = passo.get("mutirao", {})
	return bruto if bruto is Dictionary else {}


## O lugar de cada ajudante: uma roda em volta do lugar do passo.
func _lugar_no_mutirao(passo: Dictionary, indice: int, quantos: int) -> Vector3:
	var centro := _ponto_do(str(passo.get("lugar", "")))
	if not centro.is_finite():
		return Lugares.NENHUM
	var angulo := TAU * float(indice) / float(maxi(quantos, 1)) + 0.6
	return centro + Vector3(cos(angulo), 0.0, sin(angulo)) * float(passo.get("roda", RAIO_DA_RODA))


func _chamar_o_mutirao(passo: Dictionary) -> void:
	var ajudantes := _ajudantes(passo)
	var i := 0
	for quem in ajudantes:
		var morador := _morador(str(quem))
		var ali := _lugar_no_mutirao(passo, i, ajudantes.size())
		if morador != null and morador.has_method("ir_ate") and ali.is_finite():
			morador.ir_ate(ali)
		i += 1


func _dispensar_o_mutirao(passo: Dictionary) -> void:
	for quem in _ajudantes(passo):
		var morador := _morador(str(quem))
		if morador != null and morador.has_method("liberar"):
			morador.liberar()


func _receber_o_mutirao(passo: Dictionary) -> void:
	var ajudantes := _ajudantes(passo)
	var i := 0
	for quem in ajudantes:
		var traz: Dictionary = ajudantes[quem] if ajudantes[quem] is Dictionary else {}
		var chave_do_ajudante := "mutirao:%s:%s" % [str(passo.get("id", "")), str(quem)]
		var ali := _lugar_no_mutirao(passo, i, ajudantes.size())
		i += 1
		if traz.is_empty() or bool(_levados.get(chave_do_ajudante, false)):
			continue
		var morador := _morador(str(quem))
		if morador == null or not ali.is_finite():
			continue
		var centro := _ponto_do(str(passo.get("lugar", "")))
		var falta := morador.global_position - centro
		falta.y = 0.0
		if falta.length() > float(passo.get("roda", RAIO_DA_RODA)) + CHEGOU_AO_MUTIRAO:
			continue
		_levados[chave_do_ajudante] = true
		var partes: Array[String] = []
		var ficou: Array[String] = []
		for item in traz:
			var nome := "%d %s" % [int(traz[item]), _nome_do_item(str(item)).to_lower()]
			# O que não coube fica devendo, como a recompensa (`_dar`).
			if _dar(str(item), int(traz[item]), false):
				partes.append(nome)
			else:
				ficou.append(nome)
		if not partes.is_empty():
			pagou.emit(tr("Mutirão: %s trouxe %s") % [_nome_de(str(quem)), ", ".join(partes)])
		if not ficou.is_empty():
			entregou.emit(_aviso("mochila_cheia") % [", ".join(ficou), _nome_de(str(quem))])


## O passo de id `id` já fechou? É o que a fé pergunta para saber se a Dona Zefa
## já mostrou as três (o passo de contar a ela).
func passou(id: String) -> bool:
	for i in mini(missao, passos.size()):
		if str((passos[i] as Dictionary).get("id", "")) == id:
			return true
	return false


## A OBRA QUE O PASSO DE AGORA PEDE NESTA CONSTRUÇÃO, ou "".
##
## "Não consegui interagir com o poço, logo essa missão quebrou." O passo de obra
## fecha no painel (`Obras.executar`), e nada no vale dizia ao jogador que o E, ou
## o J, abria o painel ali. Quem quer saber se a missão manda tocar obra num sítio
## — o E do sítio (`tecla_das_bancadas.gd`), o J que abre direto em Obras, a aba
## que põe o cursor na obra — pergunta aqui.
##
## SÓ DEPOIS DO ANÚNCIO (`espera` zerada): é ele que ensina a planta da obra
## (`Receitas.passo_abriu`), e antes disso a aba estaria vazia.
func obra_pedida(construcao: String) -> String:
	if not iniciado or acabou() or espera > 0.0:
		return ""
	if so_enquanto.is_valid() and not bool(so_enquanto.call()):
		return ""
	var meta: Dictionary = passo_atual().get("meta", {})
	if str(meta.get("tipo", "")) != "obra" or str(meta.get("construcao", "")) != construcao:
		return ""
	var obra := str(meta.get("obra", ""))
	return "" if Obras.ja_feita(construcao, obra) else obra


## O passo de agora desta fila manda tocar obra nesta construção?
func pede_obra(construcao: String) -> bool:
	return obra_pedida(construcao) != ""


## A obra que ALGUMA fila viva pede agora nesta construção, ou "" (todas as filas
## estão no grupo `GRUPO`, a da chegada do Pedro também).
static func obra_que_se_pede(arvore: SceneTree, construcao: String) -> String:
	if arvore == null:
		return ""
	for cadeia in arvore.get_nodes_in_group(GRUPO):
		if cadeia.has_method("obra_pedida"):
			var obra := str(cadeia.obra_pedida(construcao))
			if obra != "":
				return obra
	return ""


## A FILA ESTÁ TRANCADA? Ainda não abriu e espera outra coisa (`depois_de`) ou outra fé
## (`so_enquanto`). É o caso do Damião antes do machado, do Tonho, da carroça do Seu
## Benedito, da lombada do Pedro e de quem só abre depois do tutorial.
func esta_trancada() -> bool:
	if iniciado or comeca_perto_de <= 0.0:
		return false
	return (depois_de.is_valid() and not bool(depois_de.call())) \
		or (so_enquanto.is_valid() and not bool(so_enquanto.call()))


## A FILA ANDA AGORA? Abriu e ainda não acabou.
func em_andamento() -> bool:
	return iniciado and not acabou()


## O QUE O DONO DIZ QUANDO O JOGADOR O PROCURA E A FILA ESTÁ TRANCADA: o que fazer
## antes, na língua do jogo, ou "" quando a fila não está trancada ou o arquivo não
## escreveu o aviso (`trancada`). "Só conversa de passagem" deixava o jogador sem saber
## o que lhe faltava.
func dica_da_trancada() -> String:
	if avisa_a_trancada.is_valid() and not bool(avisa_a_trancada.call()):
		return ""
	return trancada_texto if esta_trancada() else ""
