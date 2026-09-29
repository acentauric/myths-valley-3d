extends Node
## Experiência e árvore de talentos.
##
## XP vem de TRABALHO FEITO, não de bicho morto: arar, derrubar, colher, rezar.
## É o que casa com um jogo de fazenda — quem trabalha aprende.
##
## A árvore tem quatro raízes, as mesmas do GDD: Terra, Água, Mata e Fé. Cada
## nó custa ponto e alguns pedem outro nó antes. O que ela mexe é `Progressao`
## — teto de fôlego, quanto o sono devolve, eficiência, nível de ferramenta —
## e nada mais: o resto do jogo lê Progressao sem saber que talento existe.
##
## A regra que importa vem de Progressao: **subir o teto de fôlego não faz
## acordar com mais**. Quem quiser acordar melhor precisa gastar ponto em
## "Sono pesado". São escolhas diferentes e custam separado.

signal subiu_de_nivel(nivel: int)
signal ganhou_xp(quanto: float)
signal mudou

## XP de cada trabalho. Derrubar madeira de lei dá mais porque custa mais.
const XP_POR_ACAO := {
	"arar": 3,
	"plantar": 2,
	"regar": 2,
	"colher": 6,
	"bater": 5,
	"bater_duro": 12,
	"rezar": 25,
	# Combate (fase 6-A): o golpe rende pouco e o abate rende como uma colheita
	# grande, porque abate custa fôlego, vida e caminho até a mata funda.
	"golpe": 4,
	"abate": 18,
	# Obra vale mais que missão de recado e menos que capítulo: é o trabalho
	# mais caro que o jogador faz por conta própria. Obra de casca conta três
	# vezes (ver Obras._peso_em_xp).
	"obra": 30,
	"missao": 40,
}

## XP para sair do nível N para o N+1. Cresce, mas não desanda.
const BASE_DO_NIVEL := 60
const CRESCIMENTO := 1.35

## Um ponto por nível. Simples de propósito: a escolha está em ONDE gastar.
const PONTOS_POR_NIVEL := 1

## A árvore. `raiz` só agrupa na tela; `exige` é o que prende de verdade.
const NOS := {
	"lavrador": {
		"raiz": "Terra", "nome": "Lavrador", "custo": 1,
		"resumo": "O corpo aprende a enxada. Toda ação custa 10% menos fôlego.",
		"efeito": {"eficiencia": -0.10},
	},
	"costas_largas": {
		"raiz": "Terra", "nome": "Costas largas", "custo": 1, "exige": ["lavrador"],
		"resumo": "Aumenta em 30 o seu fôlego máximo. Não muda o quanto o sono devolve.",
		"efeito": {"energia_maxima": 30.0},
	},
	"sono_pesado": {
		"raiz": "Terra", "nome": "Sono pesado", "custo": 1,
		"resumo": "Dormir devolve 15 de fôlego a mais. É isto, e não o teto, que faz acordar melhor.",
		"efeito": {"recuperacao_ao_dormir": 15.0},
	},
	"dorme_onde_cai": {
		"raiz": "Terra", "nome": "Dorme onde cai", "custo": 1, "exige": ["sono_pesado"],
		"resumo": "Desmaiar devolve 10 de fôlego a mais. Não é bom, mas dói menos.",
		"efeito": {"recuperacao_ao_desmaiar": 10.0},
	},
	"bracos_de_machado": {
		"raiz": "Mata", "nome": "Braços de machado", "custo": 1,
		"resumo": "Seu machado passa a morder madeira de lei.",
		"efeito": {"ferramenta_machado": 2},
	},
	"mao_de_pedra": {
		"raiz": "Mata", "nome": "Mão de pedra", "custo": 1,
		"resumo": "Sua picareta passa a quebrar pedra dura.",
		"efeito": {"ferramenta_picareta": 2},
	},
	"po_de_mato": {
		"raiz": "Mata", "nome": "Pé de mato", "custo": 1, "exige": ["bracos_de_machado"],
		"resumo": "Aumenta em 20 o seu fôlego máximo. Quem anda na mata todo dia cansa menos.",
		"efeito": {"energia_maxima": 20.0},
	},
	"regador_firme": {
		"raiz": "Água", "nome": "Regador firme", "custo": 1,
		"resumo": "Dormir devolve 5 de fôlego a mais. Quem rega cedo dorme melhor.",
		"efeito": {"recuperacao_ao_dormir": 5.0},
	},
	## A raiz "Fé" NÃO mora mais aqui.
	##
	## "Promessa" e "Devoção" eram talentos de ofício que mexiam no cruzeiro da
	## praça — e cruzeiro da praça é marco CATÓLICO. Com três fés no jogo, cada
	## uma com a sua árvore (ver fe.gd), deixá-los aqui daria ao jogador do
	## candomblé um talento que encurta a espera de uma reza que ele não faz.
	## Os dois estão agora em `Fe.ARVORES.catolica`, junto com o resto da fé.
	##
	## O que ficou aqui é OFÍCIO: o que o corpo aprende trabalhando, e que não
	## muda quando o personagem muda de crença.
	# --- raízes novas. O efeito de várias ainda é só marcador: o sistema que
	# elas mexem (construção, comércio, pastoreio, combate) lê o bônus quando
	# existir. Já entram para a árvore ter o formato final desde agora.
	"mao_de_obra": {
		"raiz": "Construção", "nome": "Mão de obra", "custo": 1,
		"resumo": "Obra gasta 20% menos tábua.",
		"efeito": {"desconto_de_obra": 0.2},
	},
	"mestre_de_obras": {
		"raiz": "Construção", "nome": "Mestre de obras", "custo": 2, "exige": ["mao_de_obra"],
		"resumo": "Destrava obra de dois andares sem precisar da varanda antes.",
		"efeito": {"pula_varanda": 1.0},
	},
	"bom_de_papo": {
		"raiz": "Sociabilidade", "nome": "Bom de papo", "custo": 1,
		"resumo": "Vendeiro paga 10% a mais pelo que você vende.",
		"efeito": {"margem_de_venda": 0.1},
	},
	"gente_fina": {
		"raiz": "Sociabilidade", "nome": "Gente fina", "custo": 1, "exige": ["bom_de_papo"],
		"resumo": "Morador que pede favor aceita metade do que pedia.",
		"efeito": {"favor_mais_barato": 0.5},
	},
	"olho_de_mercador": {
		"raiz": "Comércio", "nome": "Olho de mercador", "custo": 1,
		"resumo": "Compra na venda sai 10% mais barato.",
		"efeito": {"desconto_de_compra": 0.1},
	},
	# "no terreiro" era erro de digitação por "no terreno", e o erro mudava o
	# sentido: TERREIRO, neste jogo, é o marco de fé do candomblé na mata do
	# poente (ver Fe.FES). Criar bode no terreiro é outra coisa inteira.
	#
	# E o talento não destravava nada: o galinheiro já vinha posto no quintal do
	# jogador desde o primeiro dia e as galinhas já ciscavam nele. Agora ele
	# destrava de verdade — é `mundo.gd` quem levanta o galinheiro e solta as
	# galinhas no dia em que este nó sai.
	"curral": {
		"raiz": "Pastoreio", "nome": "Curral", "custo": 1,
		"resumo": "Levanta o galinheiro no seu terreno e destrava criar bicho.",
		"efeito": {"pastoreio": 1.0},
	},
	"punho_firme": {
		"raiz": "Combate", "nome": "Punho firme", "custo": 1,
		"resumo": "Golpe de arma acerta um quarto mais forte.",
		"efeito": {"forca": 1.0},
	},
	# O GOLPE FORTE (segurar o E), que o Pedro ensina (ver Luta). O braço que
	# aprendeu o peso gasta menos para levantá-lo.
	"braco_pesado": {
		"raiz": "Combate", "nome": "Braço pesado", "custo": 1, "exige": ["punho_firme"],
		"resumo": "O golpe forte (segurar E) gasta 30% menos fôlego.",
		"efeito": {"golpe_de_peso": 0.3},
	},
	# A PEÇONHA da jararaca ganha ramo (regra 5): é a imunidade do Stardew,
	# medida em tempo. Ver Vida.envenenar.
	"sangue_grosso": {
		"raiz": "Combate", "nome": "Sangue grosso", "custo": 1, "exige": ["punho_firme"],
		"resumo": "Peçonha de cobra dura metade do tempo no seu corpo.",
		"efeito": {"imunidade": 0.5},
	},
	"pele_grossa": {
		"raiz": "Atributos", "nome": "Pele grossa", "custo": 1,
		"resumo": "Aguenta mais pancada: dez de vida a mais no teto.",
		"efeito": {"vigor": 1.0},
	},
	"pernas_de_andarilho": {
		"raiz": "Atributos", "nome": "Pernas de andarilho", "custo": 1,
		"resumo": "Anda 8% mais rápido. O mapa cresceu; isto vale.",
		"efeito": {"passo": 0.08},
	},
	## A única ATIVA até aqui: não vale sozinha, é acionada (tecla R). As outras
	## são passivas. Marcar as duas naturezas desde já é o que faz a árvore ter
	## formato — e uma ativa que funciona vale mais que cinco que não fazem nada.
	"segundo_folego": {
		"raiz": "Atributos", "nome": "Segundo fôlego", "custo": 1,
		"exige": ["pernas_de_andarilho"], "ativo": true,
		"resumo": "Uma vez por dia, na tecla R: recupera 30 de fôlego na hora.",
		"efeito": {},
	},

	## --- as mecânicas novas ---------------------------------------------------
	##
	## Regra que vale daqui para a frente: mecânica que entra no jogo ganha ramo
	## na teia. Sistema sem talento é sistema que não cresce com o personagem —
	## o jogador aprende a fazer e nunca fica melhor nisso, e aí a coisa vira
	## tarefa em vez de ofício.
	##
	## Pesca, cozinha e coleção entraram sem ramo nenhum; agora têm.

	"linha_firme": {
		"raiz": "Água", "nome": "Linha firme", "custo": 1,
		"resumo": "Aumenta em 60% o tempo que você tem para ferrar o peixe.",
		"efeito": {"janela_de_pesca": 0.6},
	},
	"mao_de_pescador": {
		"raiz": "Água", "nome": "Mão de pescador", "custo": 1,
		"exige": ["linha_firme"],
		"resumo": "O peixe morde 35% mais cedo, e vem mais peixe na linha.",
		"efeito": {"espera_de_pesca": -0.35, "sorte_de_pesca": 1.0},
	},
	"tempero_da_casa": {
		"raiz": "Fogo", "nome": "Tempero da casa", "custo": 1,
		"resumo": "Comida feita por você devolve 25% mais fôlego.",
		"efeito": {"rendimento_da_panela": 0.25},
	},
	"mao_de_cozinheiro": {
		"raiz": "Fogo", "nome": "Mão de cozinheiro", "custo": 1,
		"exige": ["tempero_da_casa"],
		"resumo": "Cozinhar custa metade do fôlego. Panela grande pede braço, e o seu aprendeu.",
		"efeito": {"folego_da_panela": -0.5},
	},
	"fogo_manso": {
		"raiz": "Fogo", "nome": "Fogo manso", "custo": 2,
		"exige": ["mao_de_cozinheiro"],
		"resumo": "O efeito da comida que você faz dura um dia a mais.",
		"efeito": {"dias_de_comida": 1.0},
	},
	"olho_de_colecionador": {
		"raiz": "Sociabilidade", "nome": "Olho de colecionador", "custo": 1,
		"exige": ["bom_de_papo"],
		"resumo": "Folheto de cordel se vê de mais longe e rende 50% a mais.",
		"efeito": {"faro_de_cordel": 1.0, "valor_de_cordel": 0.5},
	},
	# --- o desnível do terreno ------------------------------------------------
	# Mecânica nova no jogo ganha ramo na teia. Os altos topográficos entraram
	# com uma regra própria: de cima a câmera abre e se enxerga mais longe.
	# Estes dois são o que se pode treinar em cima disso.
	"perna_de_ladeira": {
		"raiz": "Terra", "nome": "Perna de ladeira", "custo": 1, "exige": ["lavrador"],
		"resumo": "Toda ação custa mais 5% de fôlego a menos. Quem sobe morro todo dia cansa menos.",
		"efeito": {"eficiencia": -0.05},
	},
	"olho_de_mirante": {
		"raiz": "Terra", "nome": "Olho de mirante", "custo": 1, "exige": ["perna_de_ladeira"],
		"resumo": "Do alto de um morro, a vista alcança 10% mais longe.",
		"efeito": {"vista_do_alto": 0.1},
	},
	# --- fruteira, curral e gente trabalhando para você -----------------------
	# Mecânica que entra no jogo ganha ramo na teia. Entraram três: pé de
	# fruta que carrega de novo, bicho que dá ovo e leite, e morador designado
	# que rende no fim do dia.
	"mao_de_pomar": {
		"raiz": "Terra", "nome": "Mão de pomar", "custo": 1, "exige": ["lavrador"],
		"resumo": "Cada colheita de fruteira sua rende uma fruta a mais.",
		"efeito": {"fruta_a_mais": 1.0},
	},
	"trato_do_curral": {
		"raiz": "Terra", "nome": "Trato do curral", "custo": 1, "exige": ["mao_de_pomar"],
		"resumo": "Bicho seu rende um dia antes. Bicho bem tratado não faz esperar.",
		"efeito": {"pressa_do_curral": 1.0},
	},
	"palavra_de_patrao": {
		"raiz": "Sociabilidade", "nome": "Palavra de patrão", "custo": 1,
		"exige": ["bom_de_papo"],
		"resumo": "Quem trabalha para você rende 50% a mais no fim do dia.",
		"efeito": {"rendimento_do_morador": 0.5},
	},
	"mestre_de_oficio": {
		"raiz": "Sociabilidade", "nome": "Mestre de ofício", "custo": 2,
		"exige": ["palavra_de_patrao"],
		"resumo": "Quem trabalha para você aprende em metade do tempo. Cada dia de serviço conta por dois.",
		"efeito": {"pericia_do_morador": 1.0},
	},
	"cantador": {
		"raiz": "Sociabilidade", "nome": "Cantador", "custo": 2,
		"exige": ["olho_de_colecionador"],
		"resumo": "O vendeiro paga mais 10% pelo que você vende. Quem sabe os versos de cor abre porta.",
		"efeito": {"margem_de_venda": 0.1},
	},

	## --- OS NÓS DE ENCONTRO ---------------------------------------------------
	##
	## Talentos com DOIS pré-requisitos, e de raízes diferentes.
	##
	## `exige` sempre foi lista e `impedimento` sempre cobrou todos os nomes
	## dela — só que nenhum nó usava mais de um, e por isso a teia não era teia:
	## era um leque de fios paralelos que nunca se tocavam. Fio que não cruza
	## com outro fio não faz teia, faz franja.
	##
	## A regra destes quatro: cada um é uma coisa que SÓ existe quando dois
	## ofícios se encontram na mesma pessoa. Cavar canoa é machado com paciência
	## de pescador; moqueca é panela com peixe fresco; obra tocada por gente sua
	## é prumo com palavra; tropeiro é perna de ladeira com perna de estrada.
	## Nenhum deles é "o de cima, mais caro": todos são um terceiro ofício.
	##
	## Cada um mora na raiz do lado a que MAIS pertence, e o fio do outro pai
	## atravessa a teia para chegar nele. É esse fio atravessado que a tela
	## desenha em curva — ver `_arrumar` e `_fio` em talentos_tela.gd.
	"canoa_de_um_homem_so": {
		"raiz": "Água", "nome": "Canoa de um homem só", "custo": 2,
		"exige": ["mao_de_pescador", "bracos_de_machado"],
		"resumo": "Cavar um tronco pede machado e paciência de pescador. O peixe morde 20% mais cedo e o corpo aguenta mais 10.",
		"efeito": {"espera_de_pesca": -0.2, "energia_maxima": 10.0},
	},
	"moqueca_de_festa": {
		"raiz": "Fogo", "nome": "Moqueca de festa", "custo": 2,
		"exige": ["mao_de_cozinheiro", "mao_de_pescador"],
		"resumo": "Peixe fresco na panela de quem sabe. Comida feita por você devolve mais 20% de fôlego.",
		"efeito": {"rendimento_da_panela": 0.2},
	},
	"empreiteiro": {
		"raiz": "Construção", "nome": "Empreiteiro do arraial", "custo": 2,
		"exige": ["mestre_de_obras", "palavra_de_patrao"],
		"resumo": "Obra riscada por você e tocada por gente sua. Obra gasta mais 10% menos tábua, e quem trabalha para você rende mais 25%.",
		"efeito": {"desconto_de_obra": 0.1, "rendimento_do_morador": 0.25},
	},
	"tropeiro": {
		"raiz": "Atributos", "nome": "Tropeiro", "custo": 2,
		"exige": ["perna_de_ladeira", "pernas_de_andarilho"],
		"resumo": "Ladeira e estrada na mesma perna. Anda mais 6% e toda ação custa mais 3% a menos.",
		"efeito": {"passo": 0.06, "eficiencia": -0.03},
	},
}

## Ativos já usados hoje. Zera quando o dia vira.
var _usados_hoje: Dictionary = {}

var nivel: int = 1
var xp: float = 0.0
var pontos: int = 0
var destravados: Array = []


func _ready() -> void:
	Relogio.dia_comecou.connect(func(_d, _e, _a): _usados_hoje.clear())


## Habilidades ativas já destravadas, na ordem da árvore.
func ativos() -> Array:
	var lista: Array = []
	for id in destravados:
		if NOS.get(id, {}).get("ativo", false):
			lista.append(id)
	return lista


func ativo_pronto(id: String) -> bool:
	return tem(id) and not _usados_hoje.has(id)


## Aciona a habilidade ativa. Devolve o que aconteceu, ou "" se não deu.
func acionar(id: String) -> String:
	if not ativo_pronto(id):
		return ""
	_usados_hoje[id] = true
	mudou.emit()
	match id:
		"segundo_folego":
			Energia.repor(30.0)
			return "Você para, apoia as mãos nos joelhos e respira. O corpo volta."
	return ""


## Quanto falta para o próximo nível.
func xp_do_nivel() -> int:
	return int(roundf(BASE_DO_NIVEL * pow(CRESCIMENTO, nivel - 1)))


## Credita o XP de um trabalho.
##
## `vezes` é FRAÇÃO, e o XP acumulado também. A tabela é de inteiros e sempre
## foi, mas a conta não pode ser: no dia em que existir "+15% de experiência" —
## e vai existir, porque é o bônus mais óbvio que falta na teia —, arar renderia
## 3 × 1,15 = 3,45, o `int` faria disso 3, e o talento não pagaria NADA em
## nenhuma ação pequena. O jogador teria gastado um ponto num número que não
## muda.
##
## A fração nunca chega à tela: quem mostra usa `%d`, que trunca. Meia
## experiência não é coisa que se mostre a ninguém — mas é coisa que se guarda.
func ganhar(acao: String, vezes: float = 1.0) -> void:
	var quanto: float = float(XP_POR_ACAO.get(acao, 0)) * vezes
	if quanto <= 0.0:
		return
	xp += quanto
	ganhou_xp.emit(quanto)

	while xp >= xp_do_nivel():
		xp -= xp_do_nivel()
		nivel += 1
		pontos += PONTOS_POR_NIVEL
		subiu_de_nivel.emit(nivel)
	mudou.emit()


func tem(no: String) -> bool:
	return destravados.has(no)


func dados(no: String) -> Dictionary:
	return NOS.get(no, {})


## "" quando dá para destravar; senão, o motivo.
func impedimento(no: String) -> String:
	var dado := dados(no)
	if dado.is_empty():
		return "Talento desconhecido."
	if tem(no):
		return "Já destravado."
	for exigido in dado.get("exige", []):
		if not tem(str(exigido)):
			return "Precisa de %s antes." % dados(str(exigido)).get("nome", exigido)
	var custo: int = int(dado.get("custo", 1))
	if pontos < custo:
		return "Falta ponto: %d de %d." % [pontos, custo]
	return ""


func pode(no: String) -> bool:
	return impedimento(no) == ""


func destravar(no: String) -> bool:
	if not pode(no):
		return false
	var dado := dados(no)
	pontos -= int(dado.get("custo", 1))
	destravados.append(no)
	_aplicar(dado.get("efeito", {}))
	mudou.emit()
	return true


## Lista dos nós de uma raiz, para a tela agrupar.
func raizes() -> Array:
	var vistas: Array = []
	for no in NOS:
		var raiz := str(NOS[no].get("raiz", ""))
		if not vistas.has(raiz):
			vistas.append(raiz)
	return vistas


func nos_da_raiz(raiz: String) -> Array:
	var lista: Array = []
	for no in NOS:
		if str(NOS[no].get("raiz", "")) == raiz:
			lista.append(no)
	return lista


## Bônus somados dos talentos, para quem precisa deles fora de Progressao.
##
## SOMA A FÉ JUNTO, e é aqui que os dois sistemas se encontram. O resto do jogo
## — pesca, cozinha, obra, venda, colheita — pergunta por um bônus e recebe um
## número; nenhum deles precisa saber que metade dele pode ter vindo de um
## terreiro. Fé congelada não entra na conta, porque `Fe.bonus` só olha a fé
## ativa: é assim que trocar de fé se sente na mão no dia seguinte.
func bonus(campo: String) -> float:
	var total := 0.0
	for no in destravados:
		total += float(dados(str(no)).get("efeito", {}).get(campo, 0.0))
	return total + Fe.bonus(campo)


func _aplicar(efeito: Dictionary) -> void:
	for campo in efeito:
		var valor: float = float(efeito[campo])
		match campo:
			"eficiencia":
				Progressao.ajustar("eficiencia", Progressao.eficiencia + valor)
			"energia_maxima":
				Progressao.ajustar("energia_maxima", Progressao.energia_maxima + valor)
				Energia.repor(valor)
			"recuperacao_ao_dormir":
				Progressao.ajustar("recuperacao_ao_dormir", Progressao.recuperacao_ao_dormir + valor)
			"recuperacao_ao_desmaiar":
				Progressao.ajustar("recuperacao_ao_desmaiar", Progressao.recuperacao_ao_desmaiar + valor)
			"ferramenta_machado":
				Progressao.subir_ferramenta("machado", int(valor))
			"ferramenta_picareta":
				Progressao.subir_ferramenta("picareta", int(valor))
