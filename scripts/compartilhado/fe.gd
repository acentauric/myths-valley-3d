extends Node
## A FÉ do personagem: qual é, o que ela ensina, e o que custa trocar.
##
## É UMA SÓ POR VEZ. O jogo não tem "nível de fé" somado: tem três fés, cada
## uma com a sua árvore e a sua conta de XP, e o personagem pratica uma. As
## outras ficam CONGELADAS, exatamente no ponto em que pararam — voltar a uma
## fé antiga devolve a árvore inteira como ela estava, não uma árvore nova.
##
## As três saem do Recôncavo de 1887, e nenhuma é invenção:
##
##   catolica   A oficial. Cruzeiro na praça, capela na beira, capela de
##              estrada, cemitério na encosta. Em 1887 é a única que pode ser
##              praticada à luz do dia, e por isso é a única cujos marcos já
##              estavam no mapa desde o começo.
##   candomble  Perseguida, e por isso ESCONDIDA: o terreiro fica na mata, fora
##              da vista da estrada. Quem entra, entra sabendo. O jogo não
##              trata isso como segredo pitoresco — trata como o que era.
##   caboclo    O ancestral da própria terra. A gameleira grande no sambaqui, o
##              monte de conchas que gente que viveu aqui antes de todo mundo
##              deixou. Não é povo de fantasia: é o chão, e o que ele guarda.
##
## COMO O XP FUNCIONA, que é a parte que confunde:
##
##   O que se guarda é o TOTAL acumulado de cada fé. Nível e ponto saem dele
##   por conta — nível é onde o total chega, e ponto é um por nível vencido.
##
##   Migrar PONTOS é outra coisa, e é opcional: leva o total de uma fé para
##   outra e perde 85% no caminho. O que chega SOMA ao que a fé de destino já
##   tinha; a de origem fica zerada de total — mas NÃO perde o que já aprendeu,
##   e nem os pontos que já ganhou. O que você aprendeu fica; o que você
##   acumulou, vai.
##
##   O `teto` existe por causa disso: guarda o nível mais alto que a fé já
##   alcançou, e o ponto só é creditado acima dele. Sem isso dava para migrar
##   tudo para fora, reconquistar o mesmo nível e ganhar o mesmo ponto duas
##   vezes.

signal mudou
signal adotou(fe: String)
signal migrou(de: String, para: String)
signal subiu_de_nivel(fe: String, nivel: int)
signal ganhou_xp(quanto: float)

## O que sobra de cem pontos quando se muda de fé.
##
## Quinze por cento é pouco de propósito. Mudar de fé não é trocar de ramo numa
## árvore de talentos: é a decisão mais cara que o personagem toma fora do
## enredo, e tem que doer o bastante para ser pensada. O jogo diz o número
## inteiro antes — ver `previa_da_migracao`.
const FRACAO_QUE_SOBREVIVE := 0.15

const BASE_DO_NIVEL := 60
const CRESCIMENTO := 1.35
const PONTOS_POR_NIVEL := 1

## XP por ato de fé. Só conta para a fé ATIVA: rezar no cruzeiro sendo do
## candomblé não rende axé nenhum, e é isso que faz a escolha pesar.
const XP_POR_ATO := {
	"rito": 30,        ## o rito do próprio marco (rezar, oferendar)
	"visita": 8,       ## chegar a um marco da sua fé
	"missao": 60,      ## missão de fé cumprida
	"obra": 20,        ## obra levantada num marco da sua fé
	"festa": 40,       ## celebrar no dia da festa da sua fé, por cima do rito
}

## As três fés.
##
## `marcos` é a lista de ids de construção/adorno no mundo que pertencem a ela;
## o primeiro é o marco MAIOR, que é onde se entra para a fé e onde se migra.
## `rito` é o nome do que se faz ali, e sai na pergunta e no diálogo.
const FES := {
	"catolica": {
		"nome": "Católica",
		"marcos": ["cruzeiro", "capela", "capela_estrada", "cemiterio"],
		"rito": "rezar",
		"convite": "Parar um instante e rezar?",
		"resumo": "A fé do calendário e da promessa. Anda com o arraial inteiro: o que ela dá, dá devagar e dá para todo mundo junto.",
		"pratica": "Reza no cruzeiro da praça, na capela e na capela de estrada.",
	},
	"candomble": {
		"nome": "Candomblé",
		"marcos": ["terreiro"],
		"rito": "oferendar",
		"convite": "Pedir licença e deixar a oferenda?",
		"resumo": "A fé da folha, do ferro e da água. Ensina o que a terra e o mar dão, e ensina em roda — ninguém aprende sozinho num terreiro.",
		"pratica": "Oferenda no terreiro, escondido na mata a oeste da estrada do mirante.",
	},
	"caboclo": {
		"nome": "Caboclo",
		"marcos": ["gameleira"],
		"rito": "oferendar",
		"convite": "Bater na raiz e deixar o que trouxe?",
		"resumo": "A fé do mato e do antigo. Não promete fartura: promete corpo que aguenta, pé que anda e olho que enxerga longe.",
		"pratica": "Oferenda na gameleira do sambaqui, na ponta poente da praia.",
	},
}


## A FESTA DE CALENDÁRIO de cada fé — a fase 5 do PLANO.md, segunda parte.
##
## Um dia por ano, e é onde a fé encontra os moradores: à tarde, quem é da fé
## vai para o marco maior dela (ver `Mundo._posto_de`), o rito ali sai mesmo
## fora do prazo (ver `Ritos.pode_celebrar`) e quem celebra junto ganha com
## todo mundo que está lá (ver `Afinidade.POR_FESTA`). O cartão do amanhecer
## avisa (ver `Mundo._lembretes_do_dia`).
##
## É o CALENDÁRIO que manda, não a fé ativa: a festa acontece no arraial quer
## o jogador seja dela ou não. As datas são as do Recôncavo, postas na estação
## do jogo (0 primavera, 1 verão, 2 outono, 3 inverno — ver Relogio.Estacao):
##
##   catolica   Bom Jesus dos Navegantes, 1º de janeiro — verão. É o padroeiro
##              do arraial (Bom Jesus dos Pobres), e a procissão dele é de
##              saveiro, que é como o forasteiro chegou.
##   candomble  Cosme e Damião, 27 de setembro — primavera. O dia do caruru das
##              crianças; dois moradores do arraial têm esses nomes, e não é
##              acaso.
##   caboclo    Dois de Julho — inverno. A independência da Bahia, que o povo
##              celebra com o caboclo e a cabocla nos carros, e é a romaria de
##              quem é do mato.
const FESTAS := {
	"catolica": {"nome": "Bom Jesus dos Navegantes", "estacao": 1, "dia": 1,
		"aviso": "Hoje é dia de Bom Jesus dos Navegantes. À tarde, quem é da igreja se junta no cruzeiro."},
	"candomble": {"nome": "Cosme e Damião", "estacao": 0, "dia": 27,
		"aviso": "Hoje é dia de Cosme e Damião. À tarde, quem é do terreiro se junta lá."},
	"caboclo": {"nome": "Dois de Julho", "estacao": 3, "dia": 2,
		"aviso": "Hoje é Dois de Julho. À tarde, quem é do caboclo se junta na gameleira."},
}

## As bênçãos de cada fé. Uma é sorteada por rito — não se escolhe graça.
##
## Cada uma vale uma FRAÇÃO do que o personagem já tem, e não um número fixo:
## +40 de teto é enorme no primeiro dia e é migalha no capítulo 7, e a graça
## precisa continuar valendo a pena lá. A conta é feita na hora do rito.
##
## As três listas não se repetem de propósito. Se a bênção fosse a mesma,
## trocar de fé seria trocar de nome — e a decisão mais cara do jogo não pode
## ser cosmética.
const BENCAOS := {
	"catolica": {
		"mao_leve": {"nome": "Mão leve", "campo": "eficiencia", "fracao": -0.25,
			"resumo": "Por dois dias, todo trabalho custa um quarto menos de fôlego."},
		"bom_sono": {"nome": "Bom sono", "campo": "recuperacao_ao_dormir", "fracao": 0.5,
			"resumo": "Por dois dias, a noite devolve metade a mais."},
		"folego_de_boi": {"nome": "Fôlego de boi", "campo": "energia_maxima", "fracao": 0.34,
			"resumo": "Por dois dias, seu teto de fôlego sobe um terço."},
	},
	"candomble": {
		"axe_da_folha": {"nome": "Axé da folha", "campo": "energia_maxima", "fracao": 0.45,
			"resumo": "Por dois dias, seu teto de fôlego sobe quase pela metade."},
		"mao_de_ogum": {"nome": "Mão de Ogum", "campo": "eficiencia", "fracao": -0.3,
			"resumo": "Por dois dias, ferramenta pesa menos: todo trabalho custa 30% a menos."},
		"agua_doce": {"nome": "Água doce", "campo": "recuperacao_ao_dormir", "fracao": 0.6,
			"resumo": "Por dois dias, a noite devolve mais da metade a mais."},
	},
	"caboclo": {
		"pe_de_mata": {"nome": "Pé de mata", "campo": "eficiencia", "fracao": -0.4,
			"resumo": "Por dois dias, tudo custa 40% menos. É a graça mais forte que existe aqui."},
		"couro_duro": {"nome": "Couro duro", "campo": "recuperacao_ao_desmaiar", "fracao": 1.0,
			"resumo": "Por dois dias, apagar no chão devolve o dobro."},
		"folego_de_caca": {"nome": "Fôlego de caça", "campo": "energia_maxima", "fracao": 0.3,
			"resumo": "Por dois dias, seu teto de fôlego sobe um terço."},
	},
}

## As três árvores.
##
## Cada uma tem VOCAÇÃO, e é isso que faz a escolha ser escolha:
##
##   catolica   bênção, comunidade e caminho — a fé que rende no CONVÍVIO:
##              obra mais barata, venda melhor, sono melhor, romaria.
##   candomble  folha, ferro e água — a fé que rende no TRABALHO da terra e do
##              mar: colheita, panela, ferramenta, pesca, gente junta.
##   caboclo    caça e mata velha — a fé que rende no CORPO: fôlego que dura,
##              pé que anda, machadada que rende, olho que alcança.
##
## `raiz` só agrupa na teia; `exige` é o que prende de verdade. Mesmo formato
## dos talentos de ofício (ver talentos.gd), de propósito: é a mesma tela que
## desenha as duas.
const ARVORES := {
	"catolica": {
		"ladainha": {
			"raiz": "Reza", "nome": "Ladainha", "custo": 1,
			"resumo": "Rezar devolve 20% mais fôlego.",
			"efeito": {"folego_do_rito": 0.2},
		},
		"promessa": {
			"raiz": "Reza", "nome": "Promessa", "custo": 1, "exige": ["ladainha"],
			"resumo": "A bênção do marco dura o dobro.",
			"efeito": {"duracao_da_bencao": 1.0},
		},
		"devocao": {
			"raiz": "Reza", "nome": "Devoção", "custo": 1, "exige": ["promessa"],
			"resumo": "Reduz pela metade a espera para rezar de novo.",
			"efeito": {"espera_do_rito": -0.5},
		},
		"novena": {
			"raiz": "Reza", "nome": "Novena", "custo": 2, "exige": ["devocao"],
			"resumo": "Toda bênção vale metade a mais do que valeria.",
			"efeito": {"forca_da_bencao": 0.5},
		},
		"mutirao": {
			"raiz": "Comunidade", "nome": "Mutirão", "custo": 1,
			"resumo": "Obra gasta 10% menos material. Quem chama o povo levanta parede num dia.",
			"efeito": {"desconto_de_obra": 0.1},
		},
		"vigilia": {
			"raiz": "Comunidade", "nome": "Vigília", "custo": 1, "exige": ["mutirao"],
			"resumo": "Dormir devolve 10 de fôlego a mais.",
			"efeito": {"recuperacao_ao_dormir": 10.0},
		},
		"padroeiro": {
			"raiz": "Comunidade", "nome": "Dia do padroeiro", "custo": 2, "exige": ["vigilia"],
			"resumo": "O vendeiro paga 10% a mais pelo que você vende. Quem é visto na missa é conhecido.",
			"efeito": {"margem_de_venda": 0.1},
		},
		"romaria": {
			"raiz": "Caminho", "nome": "Romaria", "custo": 1,
			"resumo": "Anda 6% mais rápido. Quem promete ir a pé, chega.",
			"efeito": {"passo": 0.06},
		},
		"navegantes": {
			"raiz": "Caminho", "nome": "Senhor dos Navegantes", "custo": 2, "exige": ["romaria"],
			"resumo": "O peixe morde 25% mais cedo. É o padroeiro de quem vive do mar, e esta vila vive.",
			"efeito": {"espera_de_pesca": -0.25},
		},
	},
	"candomble": {
		"folha_de_ossain": {
			"raiz": "Folha", "nome": "Folha de Ossain", "custo": 1,
			"resumo": "A mata ensina qual folha serve. Toda colheita sua rende uma a mais.",
			"efeito": {"colheita_a_mais": 1.0},
		},
		"mao_de_pilao": {
			"raiz": "Folha", "nome": "Mão de pilão", "custo": 1, "exige": ["folha_de_ossain"],
			"resumo": "Comida feita por você devolve 25% mais fôlego.",
			"efeito": {"rendimento_da_panela": 0.25},
		},
		"comida_de_santo": {
			"raiz": "Folha", "nome": "Comida de santo", "custo": 2, "exige": ["mao_de_pilao"],
			"resumo": "O efeito da comida que você faz dura um dia a mais.",
			"efeito": {"dias_de_comida": 1.0},
		},
		"ferro_de_ogum": {
			"raiz": "Ferro", "nome": "Ferro de Ogum", "custo": 1,
			"resumo": "Seu machado passa a morder madeira de lei.",
			"efeito": {"ferramenta_machado": 2},
		},
		"pedra_de_xango": {
			"raiz": "Ferro", "nome": "Pedra de Xangô", "custo": 1, "exige": ["ferro_de_ogum"],
			"resumo": "Sua picareta passa a quebrar pedra dura.",
			"efeito": {"ferramenta_picareta": 2},
		},
		"mata_de_oxossi": {
			"raiz": "Mata e água", "nome": "Mata de Oxóssi", "custo": 1,
			"resumo": "Anda 8% mais rápido. Caçador não se cansa no caminho de casa.",
			"efeito": {"passo": 0.08},
		},
		"agua_de_iemanja": {
			"raiz": "Mata e água", "nome": "Água de Iemanjá", "custo": 2, "exige": ["mata_de_oxossi"],
			"resumo": "O peixe morde 30% mais cedo, e vem mais peixe na linha.",
			"efeito": {"espera_de_pesca": -0.3, "sorte_de_pesca": 1.0},
		},
		"axe": {
			"raiz": "Axé", "nome": "Axé", "custo": 1,
			"resumo": "Aumenta em 30 o seu fôlego máximo.",
			"efeito": {"energia_maxima": 30.0},
		},
		"ebo": {
			"raiz": "Axé", "nome": "Ebó", "custo": 1, "exige": ["axe"],
			"resumo": "A oferenda devolve 30% mais fôlego.",
			"efeito": {"folego_do_rito": 0.3},
		},
		"curimba": {
			"raiz": "Axé", "nome": "Curimba", "custo": 2, "exige": ["ebo"],
			"resumo": "Quem trabalha para você rende 50% a mais. Terreiro é gente junta, e gente junta rende.",
			"efeito": {"rendimento_do_morador": 0.5},
		},
		# A CAPOEIRA, que o Cosme ensina a quem é do terreiro (ver Luta e a
		# série dele em Arraial). A lição dá o golpe; a teia o faz crescer. Os
		# três nós só valem para quem aprendeu — ginga não se compra com ponto.
		"ginga_de_roda": {
			"raiz": "Capoeira", "nome": "Ginga de roda", "custo": 1,
			"resumo": "A ginga (V) gasta metade do fôlego. Quem joga desde menino não se cansa de sair da frente.",
			"efeito": {"ginga_leve": 1.0},
		},
		"meia_lua_de_compasso": {
			"raiz": "Capoeira", "nome": "Meia-lua de compasso", "custo": 1, "exige": ["ginga_de_roda"],
			"resumo": "Meia-lua e rasteira batem 50% mais forte.",
			"efeito": {"forca_da_capoeira": 0.5},
		},
		"rasteira_de_mestre": {
			"raiz": "Capoeira", "nome": "Rasteira de mestre", "custo": 2, "exige": ["meia_lua_de_compasso"],
			"resumo": "O bicho que leva a rasteira fica tonto o dobro do tempo.",
			"efeito": {"tontura": 1.0},
		},
	},
	"caboclo": {
		"flecha_certa": {
			"raiz": "Caça", "nome": "Flecha certa", "custo": 1,
			"resumo": "Toda ação custa 12% menos fôlego. Não se gasta o que não precisa.",
			"efeito": {"eficiencia": -0.12},
		},
		"pe_no_chao": {
			"raiz": "Caça", "nome": "Pé no chão", "custo": 1, "exige": ["flecha_certa"],
			"resumo": "Anda 10% mais rápido.",
			"efeito": {"passo": 0.1},
		},
		"couro_curtido": {
			"raiz": "Caça", "nome": "Couro curtido", "custo": 2, "exige": ["pe_no_chao"],
			"resumo": "Apagar no chão devolve 15 de fôlego a mais. Quem dorme no mato acorda inteiro.",
			"efeito": {"recuperacao_ao_desmaiar": 15.0},
		},
		"olho_da_mata": {
			"raiz": "Mata velha", "nome": "Olho da mata", "custo": 1,
			"resumo": "Do alto de um morro, a vista alcança 20% mais longe.",
			"efeito": {"vista_do_alto": 0.2},
		},
		"machado_de_antigo": {
			"raiz": "Mata velha", "nome": "Machado de antigo", "custo": 1, "exige": ["olho_da_mata"],
			"resumo": "Cada pau derrubado rende uma lenha a mais.",
			"efeito": {"lenha_a_mais": 1.0},
		},
		"sambaqui": {
			"raiz": "Mata velha", "nome": "Sambaqui", "custo": 2, "exige": ["machado_de_antigo"],
			"resumo": "Aumenta em 40 o seu fôlego máximo. O monte de conchas tem mil anos, e ainda está de pé.",
			"efeito": {"energia_maxima": 40.0},
		},
		"mesa_de_caboclo": {
			"raiz": "Encantado", "nome": "Mesa de caboclo", "custo": 1,
			"resumo": "A oferenda devolve 40% mais fôlego.",
			"efeito": {"folego_do_rito": 0.4},
		},
		"encantado": {
			"raiz": "Encantado", "nome": "Encantado da mata", "custo": 2, "exige": ["mesa_de_caboclo"],
			"resumo": "A bênção da gameleira dura o dobro.",
			"efeito": {"duracao_da_bencao": 1.0},
		},
	},
}

## Qual fé o personagem pratica. "" até a missão de fé ser cumprida — e é
## proposital: o jogo começa sem fé declarada, que é o único estado em que
## marco nenhum responde com graça.
var ativa: String = ""

## fe -> {"total", "teto", "destravados"}. É a única verdade; o resto é espelho.
var _estados: Dictionary = {}

## Espelhos da fé ATIVA, para a tela da teia poder ler `Fe` e `Talentos` com as
## mesmas palavras (ver talentos_tela.gd, que desenha as duas).
var nivel: int = 1
var xp: float = 0.0
var pontos: int = 0
var destravados: Array = []


func _ready() -> void:
	for fe in FES:
		_estados[fe] = {"total": 0.0, "teto": 1, "destravados": []}
	_espelhar()


# --- consulta -----------------------------------------------------------------

func nome(fe: String) -> String:
	return str(FES.get(fe, {}).get("nome", fe))


func dados_da_fe(fe: String) -> Dictionary:
	return FES.get(fe, {})


func ids() -> Array:
	return FES.keys()


func festa(fe: String) -> Dictionary:
	return FESTAS.get(fe, {})


## A fé cuja festa é hoje, ou "". Pelo calendário, e não pela fé ativa.
func festa_de_hoje() -> String:
	for fe in FESTAS:
		if int(FESTAS[fe]["estacao"]) == Relogio.estacao and int(FESTAS[fe]["dia"]) == Relogio.dia:
			return str(fe)
	return ""


## A fé a que um marco do mundo pertence, ou "" se aquilo não é marco de fé.
func fe_do_marco(marco: String) -> String:
	for fe in FES:
		if (FES[fe]["marcos"] as Array).has(marco):
			return fe
	return ""


## O marco maior de uma fé: onde se entra para ela e onde se migra.
func marco_maior(fe: String) -> String:
	var lista: Array = FES.get(fe, {}).get("marcos", [])
	return str(lista[0]) if not lista.is_empty() else ""


func praticada(fe: String) -> bool:
	return ativa != "" and ativa == fe


## A fé já foi praticada alguma vez? É o que separa "árvore nova" de "árvore
## que estava esperando".
func conhecida(fe: String) -> bool:
	var estado: Dictionary = _estados.get(fe, {})
	return int(estado.get("total", 0)) > 0 or not (estado.get("destravados", []) as Array).is_empty()


## O acumulado INTEIRO de uma fé, que é o que se mostra e o que a migração
## cobra. A fração fica guardada e não aparece aqui — ver `total_exato`.
func total(fe: String) -> int:
	return floori(total_exato(fe))


## O acumulado com a fração. É o que manda; `total` é a vista dele.
func total_exato(fe: String) -> float:
	return float(_estados.get(fe, {}).get("total", 0.0))


func nivel_da(fe: String) -> int:
	return _nivel_de(total_exato(fe))


func pontos_da(fe: String) -> int:
	var teto: int = int(_estados.get(fe, {}).get("teto", 1))
	return maxi(0, (teto - 1) * PONTOS_POR_NIVEL - _gastos(fe))


func destravados_da(fe: String) -> Array:
	return _estados.get(fe, {}).get("destravados", [])


# --- entrar e trocar ----------------------------------------------------------

## Primeira fé do personagem. Só vale uma vez; depois disso é `migrar`.
func adotar(fe: String) -> bool:
	if ativa != "" or not FES.has(fe):
		return false
	ativa = fe
	_espelhar()
	adotou.emit(fe)
	mudou.emit()
	return true


## Troca de fé. NÃO apaga nada: a de origem fica exatamente como estava, e a de
## destino volta de onde parou — ou começa vazia, se é a primeira vez.
##
## Migrar de fé e migrar PONTOS são coisas separadas de propósito. Dá para
## mudar de fé sem levar nada, que é o que a maioria das pessoas faria: você
## passa a praticar outra coisa e o que acumulou fica lá, esperando. Levar o
## acumulado junto é que custa os 85% — ver `migrar_pontos`.
func migrar(fe: String) -> bool:
	if not FES.has(fe) or fe == ativa:
		return false
	var de := ativa
	ativa = fe
	_espelhar()
	migrou.emit(de, fe)
	mudou.emit()
	return true


## O que sobraria se o acumulado de `de` fosse levado para `para`.
##
## Devolve tudo que o diálogo precisa dizer ANTES de o jogador decidir, porque
## decisão de 85% não se toma no escuro: quanto sai, quanto chega, quanto se
## perde, e em que nível a fé de destino fica depois.
func previa_da_migracao(de: String, para: String) -> Dictionary:
	var sai := total(de)
	var chega := int(floorf(sai * FRACAO_QUE_SOBREVIVE))
	var base := total(para)
	return {
		"sai": sai,
		"chega": chega,
		"perde": sai - chega,
		"base": base,
		"nivel_antes": _nivel_de(base),
		"nivel_depois": _nivel_de(base + chega),
	}


## Leva o acumulado de uma fé para outra, pagando os 85%.
##
## O que chega SOMA à base que a fé de destino já tinha — não substitui. E a de
## origem fica com total zero, mas conserva o que aprendeu (os nós destravados)
## e os pontos que já tinha ganhado: o `teto` não desce nunca.
func migrar_pontos(de: String, para: String) -> Dictionary:
	if de == para or not _estados.has(de) or not _estados.has(para):
		return {}
	var previa := previa_da_migracao(de, para)
	if int(previa["sai"]) <= 0:
		return {}
	_estados[de]["total"] = 0.0
	_creditar(para, int(previa["chega"]))
	_espelhar()
	mudou.emit()
	return previa


# --- XP -----------------------------------------------------------------------

## XP de um ato de fé. Vai SEMPRE para a fé ativa, e some se não houver fé
## nenhuma — ato de fé sem fé declarada é um homem tirando o chapéu.
## `vezes` é FRAÇÃO, e o acumulado também. Mesma razão do `Talentos.ganhar`: a
## tabela é de inteiros, mas a conta não pode ser, senão qualquer bônus de
## percentagem some no arredondamento antes de chegar ao acumulado.
func ganhar(ato: String, vezes: float = 1.0) -> void:
	if ativa == "":
		return
	var quanto: float = float(XP_POR_ATO.get(ato, 0)) * vezes
	if quanto <= 0.0:
		return
	_creditar(ativa, quanto)
	ganhou_xp.emit(quanto)
	_espelhar()
	mudou.emit()


func xp_do_nivel() -> int:
	return _custo_do_nivel(nivel)


# --- a árvore -----------------------------------------------------------------

func arvore() -> Dictionary:
	return ARVORES.get(ativa, {})


func dados(no: String) -> Dictionary:
	return arvore().get(no, {})


func tem(no: String) -> bool:
	return destravados.has(no)


func raizes() -> Array:
	var vistas: Array = []
	for no in arvore():
		var raiz := str(arvore()[no].get("raiz", ""))
		if not vistas.has(raiz):
			vistas.append(raiz)
	return vistas


func nos_da_raiz(raiz: String) -> Array:
	var lista: Array = []
	for no in arvore():
		if str(arvore()[no].get("raiz", "")) == raiz:
			lista.append(no)
	return lista


## Nenhuma habilidade de fé é ATIVA por enquanto. Existe para a tela da teia
## poder perguntar o mesmo às duas fontes sem saber qual está desenhando.
func ativos() -> Array:
	return []


## "" quando dá para destravar; senão, o motivo.
func impedimento(no: String) -> String:
	if ativa == "":
		return "Você ainda não tem fé declarada."
	var dado := dados(no)
	if dado.is_empty():
		return "Este caminho não é desta fé."
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
	(_estados[ativa]["destravados"] as Array).append(no)
	_aplicar(dados(no).get("efeito", {}))
	_espelhar()
	mudou.emit()
	return true


## Bônus somados dos nós da fé ATIVA. Fé congelada não rende nada — é isso que
## "congelar" quer dizer, e é por isso que trocar de fé se sente no corpo.
##
## Quem chama isto é `Talentos.bonus`, que soma os dois num número só: o resto
## do jogo pergunta por um bônus e não precisa saber de onde ele veio.
func bonus(campo: String) -> float:
	if ativa == "":
		return 0.0
	var soma := 0.0
	for no in destravados:
		soma += float(dados(str(no)).get("efeito", {}).get(campo, 0.0))
	return soma


# --- interno ------------------------------------------------------------------

func _creditar(fe: String, quanto: float) -> void:
	var estado: Dictionary = _estados[fe]
	estado["total"] = float(estado["total"]) + quanto
	var agora := _nivel_de(float(estado["total"]))
	if agora > int(estado["teto"]):
		estado["teto"] = agora
		subiu_de_nivel.emit(fe, agora)


func _gastos(fe: String) -> int:
	var soma := 0
	var arvore_da_fe: Dictionary = ARVORES.get(fe, {})
	for no in _estados.get(fe, {}).get("destravados", []):
		soma += int(arvore_da_fe.get(str(no), {}).get("custo", 1))
	return soma


func _custo_do_nivel(n: int) -> int:
	return int(roundf(BASE_DO_NIVEL * pow(CRESCIMENTO, n - 1)))


func _nivel_de(acumulado: float) -> int:
	var n := 1
	var resto := acumulado
	while resto >= float(_custo_do_nivel(n)) and n < 99:
		resto -= float(_custo_do_nivel(n))
		n += 1
	return n


## Quanto do nível atual já foi andado.
func _progresso_de(acumulado: float) -> float:
	var n := 1
	var resto := acumulado
	while resto >= float(_custo_do_nivel(n)) and n < 99:
		resto -= float(_custo_do_nivel(n))
		n += 1
	return resto


## Copia a fé ativa para os campos que a tela lê. Sem fé, a teia fica vazia em
## vez de mostrar a de outra pessoa.
func _espelhar() -> void:
	if ativa == "" or not _estados.has(ativa):
		xp = 0.0
		pontos = 0
		destravados = []
		return
	var estado: Dictionary = _estados[ativa]
	nivel = _nivel_de(float(estado["total"]))
	xp = _progresso_de(float(estado["total"]))
	pontos = pontos_da(ativa)
	destravados = estado["destravados"]


## Efeito que mexe em Progressao é aplicado na hora, igual ao talento de
## ofício. Os outros campos ficam só no `bonus`, que quem precisa consulta.
##
## ATENÇÃO: efeito aplicado aqui NÃO é desfeito ao trocar de fé, e isso é
## deliberado — teto de fôlego que sobe e desce ao mudar de religião faria o
## jogador acordar com menos corpo do que deitou. O que a fé ensinou ao corpo,
## o corpo aprendeu. O que ela DAVA — bênção, desconto, sorte — some, porque
## isso passa por `bonus`, e `bonus` só olha a fé ativa.
func _aplicar(efeito: Dictionary) -> void:
	for campo in efeito:
		var valor: float = float(efeito[campo])
		match campo:
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
