extends RefCounted
## O QUE OS POPUPS DO MUNDO COMBINAM ENTRE SI: quem ocupa que pedaço da tela.
##
## A placa de nome, a dica do E e o balão de fala moram em camadas diferentes e
## são feitos por scripts diferentes, e não se conheciam: a dica do E subia por
## cima da placa de quem ia ser procurado, o balão de um cobria a placa do outro.
## Aqui estão os nomes dos grupos em que cada um se anuncia, e as contas de
## retângulo que eles usam para não se cobrir. Sem estado e sem nome de autoload:
## um portão rodado com `--script` o carrega com `preload`.
##
## A ORDEM DE QUEM CEDE A QUEM: o balão de fala é o que mais importa e não cede a
## ninguém (só as dicas, pelo lugar que ele deixa para elas); a dica do E sobe
## acima das placas; a placa some quando um balão a cobre. Para cada um ler o
## retângulo FRESCO de quem manda nele, o `process_priority` põe as placas antes
## de tudo (-20), as dicas no meio (0, o das fontes do E) e o balão por último (+20).

const GRUPO_PLACAS := "placas_de_nome"
const GRUPO_DICAS := "dicas_de_tecla"
const GRUPO_BALOES := "baloes_de_fala"
const GRUPO_SETA := "seta_da_missao"
const GRUPO_HUD := "obstaculos_do_hud"
## Matriz: narração > HUD essencial > E > fala > aviso contextual > nome.
## A NARRAÇÃO (a caixa longa do Dialogo, #106) está acima de tudo: o que a cobre, seja HUD, seta ou
## painel do testador, se recolhe enquanto ela está aberta (`foco_da_narracao.gd`), e só o que ela
## mesma explica (a barra da vez) fica aceso.
const PRIORIDADE_NARRACAO := 120
const PRIORIDADE_HUD := 100
const PRIORIDADE_INTERACAO := 90
const PRIORIDADE_FALA := 80
const PRIORIDADE_AVISO := 60
const PRIORIDADE_NOME := 20

## Painéis fixos do HUD que os popups do mundo evitam: bloco do título (esquerda),
## relógio (centro) e coluna de botões (direita, medida a partir da borda).
const HUD_TITULO := Rect2(0, 0, 395, 215)
const HUD_RELOGIO := Rect2(-90, 0, 180, 118)
const HUD_COLUNA := 110.0

## Quanta placa/dica abaixo disto de opacidade já não conta como "na tela".
const OPACIDADE_MINIMA := 0.25


## Os painéis fixos do HUD, em coordenadas de tela, para uma janela de `tela`.
static func paineis_do_hud(tela: Vector2, no: Node = null, prioridade_minima: int = 0) -> Array[Rect2]:
	var paineis: Array[Rect2] = [
		HUD_TITULO,
		Rect2(tela.x * 0.5 + HUD_RELOGIO.position.x, 0, HUD_RELOGIO.size.x, HUD_RELOGIO.size.y),
		Rect2(tela.x - HUD_COLUNA, 0, HUD_COLUNA, tela.y),
	]
	paineis.append_array(retangulos(no, GRUPO_HUD, null, prioridade_minima))
	return paineis


## Os retângulos (em tela) dos Controls visíveis do `grupo`, menos `ignorar`.
static func retangulos(no: Node, grupo: String, ignorar: Node = null, prioridade_minima: int = 0) -> Array[Rect2]:
	var saida: Array[Rect2] = []
	if no == null or not no.is_inside_tree():
		return saida
	for membro in no.get_tree().get_nodes_in_group(grupo):
		if int(membro.get_meta("popup_prioridade", PRIORIDADE_HUD)) < prioridade_minima:
			continue
		var controle := membro as Control
		if controle == null or controle == ignorar or not controle.is_visible_in_tree() \
				or controle.modulate.a < OPACIDADE_MINIMA:
			continue
		saida.append(retangulo_na_tela(controle))
	return saida


## O retângulo de `controle` em tela COM a escala que ele (ou um pai) carrega: o
## `get_global_rect` do Godot mede só a posição e o `size`, e um painel ampliado pelo tamanho
## do componente de Ajustes (pivô + `scale`) ocupa mais do que ele diz (#196).
static func retangulo_na_tela(controle: Control) -> Rect2:
	return controle.get_global_transform() * Rect2(Vector2.ZERO, controle.size)


## Os retângulos dos balões de fala no ar, menos o de `ignorar`.
static func retangulos_dos_baloes(no: Node, ignorar: Node = null) -> Array[Rect2]:
	var saida: Array[Rect2] = []
	if no == null or not no.is_inside_tree():
		return saida
	for balao in no.get_tree().get_nodes_in_group(GRUPO_BALOES):
		if balao == ignorar or not balao.has_method("retangulo"):
			continue
		var caixa: Rect2 = balao.call("retangulo")
		if caixa.size != Vector2.ZERO:
			saida.append(caixa)
	return saida


## A área (px²) em que `a` cobre `b`.
static func cobertura(a: Rect2, b: Rect2) -> float:
	if a.size == Vector2.ZERO or b.size == Vector2.ZERO:
		return 0.0
	return a.intersection(b).get_area()


## `caixa`, subida para cima dos `obstaculos` que ela cobriria, com `folga` entre eles: quem não
## os encosta (na horizontal ou por folga na vertical) fica onde está, e quem encosta SOBE até
## ficar `folga` acima do obstáculo. O empurrão é só o que falta, e cresce com a cobertura: sem salto
## no começo do encontro. Só sobe (descer botaria a dica sobre a placa que ela devia deixar embaixo, e o
## balão sobre quem fala), e vai do obstáculo mais baixo para o mais alto, para empilhar sobre vários.
static func afastar_de(caixa: Rect2, obstaculos: Array[Rect2], folga: float) -> Rect2:
	var ordenados := obstaculos.duplicate()
	ordenados.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.end.y > b.end.y)
	for obstaculo: Rect2 in ordenados:
		if caixa.position.x >= obstaculo.end.x or caixa.end.x <= obstaculo.position.x:
			continue
		if caixa.end.y <= obstaculo.position.y - folga or caixa.position.y >= obstaculo.end.y + folga:
			continue
		caixa.position.y = minf(caixa.position.y, obstaculo.position.y - folga - caixa.size.y)
	return caixa


## `caixa` fora dos painéis do HUD (#184): a dica do E, dona da vaga, também respeita as barras,
## o relógio e os painéis, e não só as placas de nome. Sem tocar em nenhum, fica onde está. Se
## cobriria algum, vai para o lugar mais perto que o deixa livre de todos, inteiro na tela:
## DESCE para baixo do painel, ENCOSTA ao lado dele (esquerda ou direita) ou, se estiver embaixo,
## sobe acima. Sem lugar nenhum, devolve um retângulo vazio: quem chama APAGA a dica.
static func livre_do_hud(caixa: Rect2, paineis: Array[Rect2], folga: float, tela: Vector2) -> Rect2:
	if not _cobre_algum(caixa, paineis, folga):
		return caixa
	var candidatos: Array[Rect2] = []
	for painel: Rect2 in paineis:
		if not caixa.grow(folga).intersects(painel):
			continue
		candidatos.append(Rect2(Vector2(caixa.position.x, painel.end.y + folga), caixa.size))
		candidatos.append(Rect2(Vector2(painel.position.x - folga - caixa.size.x, caixa.position.y), caixa.size))
		candidatos.append(Rect2(Vector2(painel.end.x + folga, caixa.position.y), caixa.size))
		candidatos.append(Rect2(Vector2(caixa.position.x, painel.position.y - folga - caixa.size.y), caixa.size))
	# O mais perto primeiro: o menor deslocamento é o que menos muda a dica de lugar.
	candidatos.sort_custom(func(a: Rect2, b: Rect2) -> bool:
		return a.position.distance_squared_to(caixa.position) < b.position.distance_squared_to(caixa.position))
	var area := Rect2(Vector2.ZERO, tela)
	for candidato: Rect2 in candidatos:
		if area.encloses(candidato) and not _cobre_algum(candidato, paineis, folga):
			return candidato
	return Rect2()


static func _cobre_algum(caixa: Rect2, paineis: Array[Rect2], folga: float) -> bool:
	# Um pouco menos que a folga: o candidato que encosta na folga exata não conta como cobrindo.
	var larga := caixa.grow(maxf(folga - 0.05, 0.0))
	for painel: Rect2 in paineis:
		if larga.intersects(painel):
			return true
	return false
