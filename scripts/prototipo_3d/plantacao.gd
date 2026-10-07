extends RefCounted
## ROÇADO: arar, plantar, regar, crescer e colher — a regra do 2D, no vale (#8).
##
## É a `Plantacao` do jogo 2D (`scripts/mundo/plantacao.gd` de lá), trazida
## inteira, menos o desenho: lá cada leito era um tile, e o estado morava num
## dicionário ao lado porque "o tile guarda só o desenho". Aqui não há tile — o
## leito é uma célula da grade da lavoura da casa (`lavoura_vale.gd`), com
## posição no vale — e quem desenha escuta `mudou`. A regra não mudou uma
## vírgula: é o laço central do jogo, e o portão dele é o mesmo.
##
## Regra de crescimento: a planta só avança um estágio no dia seguinte SE tiver
## sido regada. Dia sem rega é dia perdido — é o que o Pedro avisa no tutorial.

## Um leito mudou: arado, plantado, regado, cresceu, colhido.
signal mudou(celula: Vector2i)

## As culturas, com os tempos do 2D. `estagios` é quantos desenhos a planta
## tem, do que se planta ao ponto de colher; o último é o maduro, e na fruteira
## o penúltimo é a mesma árvore sem fruto (para onde `volta_para` aponta).
##
## `perene` é o que separa fruteira de roça: pé de manga não acaba quando se
## colhe a manga. Colhida, ela VOLTA ao estágio `volta_para` e carrega de novo.
## A cana se corta e REBROTA (`rebrota`): volta lá para baixo e sobe de novo.
## `carencia` é quantos dias REGADOS a planta passa sem carregar depois de uma
## colheita. Os tempos são os da planta de verdade: milho é o mais rápido e o
## mais barato, mandioca é o meio, cana é a mais demorada e a que rende mais.
const CULTURAS := {
	"mandioca": {"nome": "Mandioca", "estagios": 4, "colheita": "mandioca", "rendimento": 2, "sementes_de_volta": 1},
	"milho": {"nome": "Milho", "estagios": 4, "colheita": "milho", "rendimento": 3, "sementes_de_volta": 1},
	"cana": {"nome": "Cana-de-açúcar", "estagios": 4, "colheita": "cana", "rendimento": 4, "sementes_de_volta": 0,
		"perene": true, "rebrota": true, "volta_para": 1, "carencia": 5},
	"bananeira": {"nome": "Bananeira", "estagios": 3, "colheita": "banana", "rendimento": 3, "sementes_de_volta": 0,
		"carencia": 4, "perene": true, "volta_para": 1},
	"mangueira": {"nome": "Mangueira", "estagios": 4, "colheita": "manga", "rendimento": 4, "sementes_de_volta": 0,
		"carencia": 9, "perene": true, "volta_para": 2},
	"cajueiro": {"nome": "Cajueiro", "estagios": 3, "colheita": "caju", "rendimento": 3, "sementes_de_volta": 0,
		"carencia": 6, "perene": true, "volta_para": 1},
}

## A QUALIDADE DA COLHEITA vem de CUIDADO — não de sorte. Cada leito guarda
## quantos dias passaram desde que a planta foi posta e em quantos deles ela
## estava molhada quando o dia virou; a fração é o cuidado. Três degraus, e não
## dez: a diferença tem que caber numa frase que o jogador leia sem parar.
const QUALIDADES := [
	{"de": 0.0, "nome": "miúda", "a_mais": 0},
	{"de": 0.7, "nome": "boa", "a_mais": 1},
	{"de": 0.95, "nome": "de primeira", "a_mais": 2},
]

## A CACIMBA E OS REGOS: o que a obra do canteiro rega sozinha, de madrugada,
## nos leitos mais perto dela. Limitada de propósito: se regasse tudo, regar
## deixaria de existir como gesto.
const REGADOS_PELA_CACIMBA := {
	"canteiro_cacimba": 8,
	"canteiro_acude": 20,
}

## Quem decide se uma célula pode virar leito: na lavoura, a grade dela.
var _pode_arar: Callable
## célula -> {"molhado", "cultura", "estagio", "espera", "dias", "regados"}.
## Célula presente no dicionário = terra arada.
var _leitos: Dictionary = {}
var _boca_da_cacimba := Vector2i(-1, -1)


func _init(pode_arar: Callable = Callable()) -> void:
	_pode_arar = pode_arar


func dentro_do_rocado(celula: Vector2i) -> bool:
	if arado(celula):
		return true
	return _pode_arar.is_valid() and _pode_arar.call(celula)


func arado(celula: Vector2i) -> bool:
	return _leitos.has(celula)


func plantado(celula: Vector2i) -> bool:
	return arado(celula) and _leitos[celula]["cultura"] != ""


func molhado(celula: Vector2i) -> bool:
	return arado(celula) and _leitos[celula]["molhado"]


func maduro(celula: Vector2i) -> bool:
	if not plantado(celula):
		return false
	var dados: Dictionary = _leitos[celula]
	return int(dados["estagio"]) >= estagios_de(str(dados["cultura"])) - 1


func estagio(celula: Vector2i) -> int:
	return int(_leitos.get(celula, {}).get("estagio", 0))


static func estagios_de(cultura: String) -> int:
	return int(CULTURAS.get(cultura, {}).get("estagios", 1))


# --- ações -------------------------------------------------------------------

func arar(celula: Vector2i) -> bool:
	if not dentro_do_rocado(celula) or arado(celula):
		return false
	# `espera` nasce com o leito, e não só quando a primeira colheita acontece:
	# campo que aparece depois faz o save de ida e o de volta terem formatos
	# diferentes.
	_leitos[celula] = {"molhado": false, "cultura": "", "estagio": 0, "espera": 0}
	mudou.emit(celula)
	return true


func plantar(celula: Vector2i, cultura: String) -> bool:
	if not arado(celula) or plantado(celula) or not CULTURAS.has(cultura):
		return false
	_leitos[celula]["cultura"] = cultura
	_leitos[celula]["estagio"] = 0
	mudou.emit(celula)
	return true


func regar(celula: Vector2i) -> bool:
	if not arado(celula) or molhado(celula):
		return false
	_leitos[celula]["molhado"] = true
	mudou.emit(celula)
	return true


func qualidade(celula: Vector2i) -> int:
	if not plantado(celula):
		return 0
	var dados: Dictionary = _leitos[celula]
	var dias := int(dados.get("dias", 0))
	if dias <= 0:
		return 0
	var cuidado := float(dados.get("regados", 0)) / float(dias)
	var qual := 0
	for i in QUALIDADES.size():
		if cuidado >= float(QUALIDADES[i]["de"]):
			qual = i
	return qual


## Devolve {"id", "qtd", "sementes", "semente_id", "qualidade", "qualidade_nome"},
## ou {} se não havia nada para colher.
func colher(celula: Vector2i) -> Dictionary:
	if not maduro(celula):
		return {}
	var cultura: String = _leitos[celula]["cultura"]
	var dados: Dictionary = CULTURAS[cultura]
	var qual := qualidade(celula)
	if bool(dados.get("perene", false)):
		# Fruteira não acaba na colheita: perde a fruta e carrega de novo — e
		# DEMORA a carregar (`carencia`). A conta do cuidado recomeça a cada ciclo.
		_leitos[celula]["estagio"] = int(dados.get("volta_para", 0))
		_leitos[celula]["espera"] = int(dados.get("carencia", 0))
		_leitos[celula]["dias"] = 0
		_leitos[celula]["regados"] = 0
	else:
		# COLHIDO, O LEITO VOLTA A CHÃO BRUTO (playtest de 07/10: "sempre depois de
		# colher, o jogador tem que arar a terra novamente"). A mandioca arrancada leva o
		# leito junto: a enxada abre outro, como no primeiro dia.
		_leitos.erase(celula)
	mudou.emit(celula)
	# "Mão de pomar" só vale para fruteira; "Folha de Ossain", para toda colheita.
	var rende := int(dados["rendimento"])
	rende += int(Talentos.bonus("colheita_a_mais"))
	if bool(dados.get("perene", false)):
		rende += int(Talentos.bonus("fruta_a_mais"))
	rende += int(QUALIDADES[qual]["a_mais"])
	return {"id": dados["colheita"], "qtd": rende,
		"sementes": dados.get("sementes_de_volta", 0),
		"semente_id": semente_de(cultura),
		"qualidade": qual,
		"qualidade_nome": str(QUALIDADES[qual]["nome"])}


## Qual item de plantar dá nesta cultura. Vem do catálogo, onde a semente já
## diz que cultura ela planta — em vez de uma segunda tabela que envelhece.
static func semente_de(cultura: String) -> String:
	for id in Catalogo.ITENS:
		if str(Catalogo.ITENS[id].get("cultura", "")) == cultura:
			return str(id)
	return ""


func leitos() -> Array:
	return _leitos.keys()


func cultura_em(celula: Vector2i) -> String:
	return str(_leitos.get(celula, {}).get("cultura", ""))


func tem_maduro() -> bool:
	return primeira_madura() != Vector2i(-1, -1)


func primeira_madura() -> Vector2i:
	for celula in _leitos:
		if maduro(celula):
			return celula
	return Vector2i(-1, -1)


## Chamado quando o dia vira: o que foi regado cresce, e tudo seca.
func novo_dia() -> void:
	var parado := parada_por_estacao()
	for celula in _leitos:
		var dados: Dictionary = _leitos[celula]
		# A CONTA DO CUIDADO corre mesmo no inverno, quando a planta não anda.
		if dados["cultura"] != "":
			dados["dias"] = int(dados.get("dias", 0)) + 1
			if dados["molhado"]:
				dados["regados"] = int(dados.get("regados", 0)) + 1
		if dados["cultura"] != "" and dados["molhado"] and not parado:
			# CARÊNCIA primeiro, e ela só corre em dia regado.
			if int(dados.get("espera", 0)) > 0:
				dados["espera"] = int(dados["espera"]) - 1
			else:
				dados["estagio"] = mini(int(dados["estagio"]) + 1, estagios_de(str(dados["cultura"])) - 1)
		dados["molhado"] = false
	# A CACIMBA CORRE DEPOIS DE O DIA SECAR TUDO: o jogador acorda com os leitos
	# perto dela molhados, que é o que "de madrugada a água corre sozinha" diz.
	_regar_pela_cacimba()
	for celula in _leitos:
		mudou.emit(celula)


func definir_cacimba(celula: Vector2i) -> void:
	_boca_da_cacimba = celula


func alcance_da_cacimba() -> int:
	var quantos := 0
	for obra in REGADOS_PELA_CACIMBA:
		if Obras.ja_feita("canteiro", str(obra)):
			quantos = maxi(quantos, int(REGADOS_PELA_CACIMBA[obra]))
	return quantos


func _regar_pela_cacimba() -> void:
	var quantos := alcance_da_cacimba()
	if quantos <= 0 or _boca_da_cacimba == Vector2i(-1, -1):
		return
	var secos: Array = []
	for celula in _leitos:
		if not _leitos[celula]["molhado"]:
			secos.append(celula)
	secos.sort_custom(func(a, b):
		return Vector2(a).distance_squared_to(Vector2(_boca_da_cacimba)) \
			< Vector2(b).distance_squared_to(Vector2(_boca_da_cacimba)))
	for i in mini(quantos, secos.size()):
		_leitos[secos[i]]["molhado"] = true


## O INVERNO PARA A ROÇA. A convenção de jogo de fazenda (o ano tem uma estação
## morta que obriga a estocar), e não o clima da Bahia — onde o "inverno" é a
## estação das chuvas. Foi pedido assim no 2D, e está assim.
func parada_por_estacao() -> bool:
	return Relogio.estacao == Relogio.Estacao.INVERNO


# --- salvar e carregar ---------------------------------------------------------

## A cópia é FUNDA de propósito: o dicionário de cada leito continua vivo depois
## que o save é montado.
func leitos_para_salvar() -> Dictionary:
	return _leitos.duplicate(true)


func restaurar_leitos(dados: Dictionary) -> void:
	# Quem some também se redesenha: o leito que existia e o save não traz
	# volta a ser chão bruto.
	var antes := _leitos.keys()
	_leitos = dados.duplicate(true)
	for celula in _leitos:
		if not (_leitos[celula] as Dictionary).has("espera"):
			_leitos[celula]["espera"] = 0
	for celula in antes:
		if not _leitos.has(celula):
			mudou.emit(celula)
	for celula in _leitos:
		mudou.emit(celula)
