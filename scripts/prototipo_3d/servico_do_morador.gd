extends RefCounted
## O SERVIÇO DE QUEM TRABALHA PARA O JOGADOR — a conta do rendimento e da perícia (#160, #18).
##
## No 2D o morador designado rendia no fim do dia, e a árvore de talentos tinha dois nós sobre
## isso que no vale não eram lidos por ninguém: `rendimento_do_morador` ("Quem trabalha para você
## rende 50% a mais no fim do dia", a Palavra de patrão, o Empreiteiro e a fé do Curimba) e
## `pericia_do_morador` ("aprende em metade do tempo. Cada dia de serviço conta por dois", o
## Mestre de ofício). O vale não tem a aba de trabalho dos terrenos; o serviço que existe é o dia
## de roçado que o Cosme faz no segundo tutorial (`capataz_manha`, em `data/missoes_quintal.json`),
## pago de manhã na mochila. É esse pagamento que passa por aqui (`CadeiaDeMissoes._pagar`, passo
## com `"trabalho_do": "cosme"`).
##
## AS DUAS REGRAS
##
##   RENDIMENTO  o que o morador traz vem multiplicado por (1 + `rendimento_do_morador`): quatro
##               mandiocas e duas lenhas viram seis e três com a Palavra de patrão.
##   PERÍCIA     cada dia de serviço soma um dia de prática ao morador (dois com o Mestre de
##               ofício). Com `APRENDE_COM` dias ele "aprendeu o ofício" e passa a trazer um
##               quarto a mais (`OFICIO_APRENDIDO`). Sem o talento são dois dias de serviço;
##               com ele, um só basta: é o "metade do tempo".
##
## Os bônus entram por parâmetro, e não lidos aqui, para a conta ser testável sem o vale. Quem
## chama pergunta `Talentos.bonus(...)` (que soma a fé).
##
## O que vai no save: os dias de prática de cada morador, junto do ninho do curral
## (`curral_vale.gd`), que já viaja com a partida do vale.
const APRENDE_COM := 2
const OFICIO_APRENDIDO := 0.25

## Dias de prática por morador (id do morador -> dias contados).
static var dias: Dictionary = {}


## Quantos dias de prática um dia de serviço rende: um, ou dois com a perícia.
static func dias_por_servico(pericia: float) -> int:
	return 2 if pericia > 0.0 else 1


## Registra um dia de serviço do morador e devolve os dias de prática dele.
static func registrar_dia(morador: String, pericia: float) -> int:
	var total := int(dias.get(morador, 0)) + dias_por_servico(pericia)
	dias[morador] = total
	return total


static func aprendeu(morador: String) -> bool:
	return int(dias.get(morador, 0)) >= APRENDE_COM


## O que o morador traz de uma quantidade-base: o rendimento do patrão e o ofício aprendido
## somam sobre ela, e nunca trazem menos que a base.
static func pagamento(base: int, rendimento: float, oficio_aprendido: bool) -> int:
	var fator := 1.0 + maxf(rendimento, 0.0) + (OFICIO_APRENDIDO if oficio_aprendido else 0.0)
	return maxi(base, roundi(float(base) * fator))


static func limpar() -> void:
	dias.clear()


static func estado_para_salvar() -> Dictionary:
	return dias.duplicate()


static func restaurar(estado: Dictionary) -> void:
	dias.clear()
	for morador in estado:
		dias[str(morador)] = int(estado[morador])
