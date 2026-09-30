extends Node
## CARTAS: pactos com mitos, apoios e rituais.
##
## O GDD chama isto de "mecânica central" desde a primeira versão. Havia três
## pastas vazias — `data/mitos/`, `data/rituais/`, `data/items/` — e nenhuma
## linha de código. Este arquivo é a Fase 3 do plano; as pastas saíram do
## repositório, e as cartas moram em `data/cartas/cartas.json`.
##
##
## AS TRÊS NATUREZAS, e por que elas não são a mesma coisa com nomes diferentes
##
##   PACTO      é com um MITO, e mito não se contrata. Ele cobra. Um pacto dá
##              um ganho permanente enquanto estiver firmado e TIRA alguma
##              coisa todo dia — e é a cobrança que faz dele uma decisão em vez
##              de um bônus. Um de cada vez: quem serve a dois não serve a
##              nenhum, e é assim que o universo do Batalha de Mitos trata isso
##              (ver docs/mundo/VILA_E_EXPEDICOES.md: "a Caipora não trabalha para
##              ninguém; ela vigia caminhos e cobra pedágio").
##
##   APOIO      é uma carta de gente, não de mito. Vale UMA VEZ POR DIA, na
##              tecla R, e faz uma coisa pequena e imediata. Não cobra nada
##              porque não é de ninguém do outro mundo — é um favor guardado,
##              uma reza que alguém te ensinou, um jeito de fazer.
##
##   RITUAL     é consumível, e se PREPARA com o que se planta. Some ao usar.
##              É o único dos três que o jogador fabrica, e é de propósito: o
##              ritual amarra a mecânica central ao roçado, que é o coração do
##              jogo. Ritual comprado no armazém seria mais uma poção.
##
##
## DE ONDE VÊM
##
## Não da loja. Pacto se firma indo ao lugar do mito; apoio é dado por morador
## de quem você é próximo (afinidade, ver `Afinidade`); ritual se prepara no
## ORATÓRIO da sua casa — que é uma obra que existia desde sempre dando quatro
## de fôlego e mais nada.
##
## Isso amarra as três fases anteriores numa só: a Fase 1 dá as cartas de
## apoio, a Fase 2 dá os ingredientes do ritual, e a obra do oratório da Fase 0
## passa a ter função.

signal mudou
signal pacto_mudou(mito: String)
signal aprendeu(carta: String)

const ARQUIVO := "res://data/cartas/cartas.json"

## Onde o ritual se prepara. É a obra de mobília do oratório, na casa do
## jogador — a mesma que já dava fôlego e nada mais.
const OBRA_DO_ORATORIO := "mobilia_altar"

## O pacto em vigor, ou "" quando não há nenhum. UM de cada vez.
var pacto: String = ""
## Cartas que o jogador já tem. id -> true.
var sabidas: Dictionary = {}
## Apoios já usados hoje. id -> dia absoluto.
var _usadas: Dictionary = {}
## Dia em que o pacto foi firmado, para a cobrança não cobrar no primeiro dia.
var _pacto_desde: int = 0


func _ready() -> void:
	Relogio.dia_comecou.connect(_ao_comecar_dia)


func tudo() -> Dictionary:
	return Jogo.dados(ARQUIVO).get("cartas", {})


func dados(id: String) -> Dictionary:
	return tudo().get(id, {})


func natureza(id: String) -> String:
	return str(dados(id).get("natureza", ""))


func nome(id: String) -> String:
	return str(dados(id).get("nome", id))


func tem(id: String) -> bool:
	return bool(sabidas.get(id, false))


## As que o jogador tem, de uma natureza. Em ordem de arquivo, que é a ordem
## em que elas foram pensadas.
func minhas(de_natureza: String = "") -> Array:
	var lista: Array = []
	for id in tudo():
		if not tem(str(id)):
			continue
		if de_natureza != "" and natureza(str(id)) != de_natureza:
			continue
		lista.append(str(id))
	return lista


## Aprender uma carta. Devolve false se já a tinha — quem chama usa isso para
## não repetir a fala de quem está entregando.
func aprender(id: String) -> bool:
	if dados(id).is_empty() or tem(id):
		return false
	sabidas[id] = true
	aprendeu.emit(id)
	mudou.emit()
	return true


# --- pacto ----------------------------------------------------------------------

## Firma o pacto. O anterior é desfeito — um de cada vez.
##
## Devolve "" se deu, ou o motivo de não dar. Motivo e não `false` porque
## recusa de mito tem que ser dita com palavra: "você já é de outro" é uma
## informação de enredo, não um erro de interface.
func firmar(mito: String) -> String:
	if natureza(mito) != "pacto":
		return "Isso não é pacto."
	if not tem(mito):
		return "Você ainda não tem essa carta."
	if pacto == mito:
		return "Já está firmado."
	desfazer()
	pacto = mito
	_pacto_desde = Relogio.dia_absoluto()
	_aplicar_o_ganho(mito, 1.0)
	pacto_mudou.emit(mito)
	mudou.emit()
	return ""


func desfazer() -> void:
	if pacto == "":
		return
	var antigo := pacto
	_aplicar_o_ganho(antigo, -1.0)
	pacto = ""
	_pacto_desde = 0
	pacto_mudou.emit("")
	mudou.emit()


## O ganho do pacto entra na Progressao enquanto ele durar, como o equipamento
## faz. Direto, e não por `Efeitos`: efeito tem prazo e o pacto não tem — ele
## acaba quando o jogador desfizer, e só.
func _aplicar_o_ganho(mito: String, sinal: float) -> void:
	for campo in dados(mito).get("ganho", {}):
		var quanto := float(dados(mito)["ganho"][campo]) * sinal
		var agora := float(Progressao.get(str(campo)))
		Progressao.ajustar(str(campo), agora + quanto)


## A COBRANÇA, todo dia. É ela que faz o pacto ser decisão.
##
## Cobra em ITEM, e não em fôlego ou dinheiro: o mito quer o que você tira da
## terra, que é o que ele guarda. A Caipora cobra pedágio de quem anda na mata
## dela; não faz sentido ela aceitar réis.
##
## Quem não tem com que pagar NÃO perde o pacto — perde o ganho daquele dia, e
## é avisado. Perder o pacto por um dia ruim seria punir o jogador por estar no
## meio de uma obra, e pacto que se quebra sozinho não é pacto.
func cobrar() -> Dictionary:
	if pacto == "" or Relogio.dia_absoluto() <= _pacto_desde:
		return {}
	var conta: Dictionary = dados(pacto).get("cobra", {})
	if conta.is_empty():
		return {}
	for item in conta:
		if Inventario.quantidade(str(item)) < int(conta[item]):
			return {"pago": false, "falta": str(item), "quanto": int(conta[item])}
	for item in conta:
		Inventario.consumir(str(item), int(conta[item]))
	return {"pago": true, "conta": conta}


## O pacto está de pé mas não foi pago hoje? Enquanto não for, o ganho não
## vale. Quem confere é o próprio `bonus`.
var _pago_hoje: bool = false

func em_dia() -> bool:
	return pacto == "" or _pago_hoje or Relogio.dia_absoluto() <= _pacto_desde


func _ao_comecar_dia(_dia: int, _estacao: int, _ano: int) -> void:
	var quitacao := cobrar()
	if quitacao.is_empty():
		_pago_hoje = true
		return
	_pago_hoje = bool(quitacao.get("pago", false))
	# O ganho do pacto é ligado e desligado conforme a cobrança do dia. Sem
	# isto, não pagar não custaria nada e a cobrança viraria enfeite.
	_aplicar_o_ganho(pacto, 1.0 if _pago_hoje else -1.0)


# --- apoio ----------------------------------------------------------------------

func apoio_pronto(id: String) -> bool:
	return tem(id) and natureza(id) == "apoio" \
		and int(_usadas.get(id, -1)) != Relogio.dia_absoluto()


## Usa a carta de apoio. Devolve o que aconteceu, ou "" se não deu.
func usar_apoio(id: String) -> String:
	if not apoio_pronto(id):
		return ""
	_usadas[id] = Relogio.dia_absoluto()
	var dado := dados(id)
	# O apoio concede um efeito com prazo, pelo mesmo caminho da comida e da
	# bênção — assim ele entra na mesma conta de três que o corpo aguenta, e
	# não abre uma segunda contabilidade paralela.
	if dado.has("efeito_campo"):
		Efeitos.conceder("carta_" + id, nome(id), str(dado["efeito_campo"]),
			float(dado.get("efeito_valor", 0.0)), int(dado.get("efeito_dias", 1)), "pacto")
	mudou.emit()
	return str(dado.get("ao_usar", ""))


# --- ritual ---------------------------------------------------------------------

func pode_preparar_rituais() -> bool:
	return Obras.ja_feita("casa", OBRA_DO_ORATORIO)


## "" quando dá para preparar; senão, o que falta.
func impedimento(id: String) -> String:
	if natureza(id) != "ritual":
		return "Isso não se prepara."
	if not tem(id):
		return "Você não sabe esse."
	if not pode_preparar_rituais():
		return "Precisa do oratório em casa."
	for item in dados(id).get("custo", {}):
		var pedido := int(dados(id)["custo"][item])
		if Inventario.quantidade(str(item)) < pedido:
			return "Falta %s: %d de %d." % [
				Catalogo.nome(str(item)), Inventario.quantidade(str(item)), pedido]
	return ""


## Prepara o ritual: gasta o material e põe o consumível na mochila. O que ele
## FAZ acontece na hora de usar, e quem sabe fazer é o mundo — ver
## `Mundo._usar_ritual`.
func preparar(id: String) -> bool:
	if impedimento(id) != "":
		return false
	for item in dados(id).get("custo", {}):
		Inventario.consumir(str(item), int(dados(id)["custo"][item]))
	Inventario.adicionar(id, 1)
	Talentos.ganhar("plantar")
	mudou.emit()
	return true


# --- salvar ---------------------------------------------------------------------

func estado() -> Dictionary:
	return {
		"pacto": pacto,
		"desde": _pacto_desde,
		"sabidas": sabidas.duplicate(true),
		"usadas": _usadas.duplicate(true),
		"pago": _pago_hoje,
	}


func restaurar(dados_salvos: Dictionary) -> void:
	# Desfaz antes de repor, senão o ganho do pacto antigo fica somado ao novo.
	desfazer()
	sabidas = (dados_salvos.get("sabidas", {}) as Dictionary).duplicate(true)
	_usadas = (dados_salvos.get("usadas", {}) as Dictionary).duplicate(true)
	_pago_hoje = bool(dados_salvos.get("pago", true))
	var qual := str(dados_salvos.get("pacto", ""))
	if qual != "":
		pacto = qual
		_pacto_desde = int(dados_salvos.get("desde", 0))
		# O ganho NÃO é reaplicado: ele já está dentro da Progressao, que é
		# salva junto. Somar de novo dobraria o pacto a cada carregamento —
		# é a mesma armadilha dos talentos e das obras.
		pacto_mudou.emit(qual)
	mudou.emit()
