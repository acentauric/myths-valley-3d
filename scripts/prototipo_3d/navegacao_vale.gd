extends Node3D
## A MALHA DE NAVEGAÇÃO DOS MORADORES — o caminho de verdade, e não a linha reta.
##
## O morador andava em linha reta até o posto, com um desvio local quando batia
## (`npc.gd`, `_contornar_bloqueio`): "decisão local não vê o mapa inteiro". Com
## a festa de cada fé o caminho ficou longo — do píer à gameleira, da casa da
## estrada ao cruzeiro, passando por casa, cerca e mata —, e "andar o caminho
## inteiro pede navegação de verdade". É esta.
##
## A MALHA SE ASSA AO MONTAR O VALE, e não sai pronta do disco: o vale é feito em
## tempo de execução, nos dois estilos, e uma malha guardada envelheceria a cada
## árvore mudada de lugar. Assar é barato (medido em 03/10/2026: uns 50 ms para
## ler o vale e 1,7 s para assar a área dos moradores, 7.000 polígonos), e ainda
## assim vai numa linha de execução à parte: enquanto a malha não fica pronta, o
## morador anda reto, como antes.
##
## O QUE ENTRA: o chão e o que tem colisão no vale — casas, cômodos por dentro
## (com a porta e as rampas), cercas, pedras —, e os troncos da mata como
## obstáculos, tirados da lista da mata e não das colisões: a colisão dos troncos
## é um punhado de cilindros que acompanha o jogador, e longe dele não há tronco
## nenhum para a malha ver.
##
## O QUE SAI: o FUNDO DO MAR, que tem colisão para o corpo andar no raso, mas
## que morador não atravessa — fica só o que está acima da preamar, o que mantém
## o píer e a ponte —; o LEITO DOS RIOS, pelo mesmo motivo (ver `_leito_dos_rios`);
## e as ILHAS: assada das colisões, a malha punha chão no
## telhado de cada casa e no tampo de cada caixote, e o ponto mais perto de quem
## está junto de uma casa podia cair lá em cima, num pedaço sem saída. Fica só o
## pedaço ligado maior, o chão do vale.
##
## E SE ASSA DE NOVO QUANDO O VALE MUDA: obra que levanta parede no caminho — o
## cercado do cemitério (`cemiterio_vale.gd`) — pede `reassar()`. A malha velha
## vale até a nova entrar no mapa, e quem pede durante uma assada ganha outra
## logo depois, com o que mudou nesse meio tempo.
##
## A PRIMEIRA ASSADA ESPERA O `_ready` DO VALE ACABAR (`_primeira_assada`): a malha era
## assada no meio dele, antes de o saveiro, o cercado da ponte e o resto nascerem, e a
## segunda assada que as obras da ponte pediam era um acaso — entre uma e outra a malha
## já estava "pronta" e não conhecia o barco atracado, que o morador (o Pedro, na ponta
## da prancha, no primeiro minuto do jogo) atravessava. Uma assada só, com tudo.
##
## O CASCO DO SAVEIRO ATRACADO é obstáculo declarado (`_casco_do_saveiro`), e não o que a
## malha acha do triângulo dele: o convés do casco virava chão ligado ao píer pela
## prancha, e o contorno simplificado da malha raspava a quina do barco.

signal pronta

## O tamanho da célula da malha e da sola do morador. O RAIO É CURTO POR CAUSA
## DA PORTA: o Recast arredonda o raio para células inteiras, e a parede que não
## cai na beira de uma célula ainda come mais uma. Com 0,3 de raio a porta da
## igreja (1,2) fechava — com célula de 0,3, de 0,2 e de 0,15 —; com 0,2 a
## erosão é de uma célula, e passam as portas e o corredor entre os bancos. O
## corpo do morador (0,26) é um pouco mais largo: quem o segura na quina é a
## colisão, e o morador não corta a quina (`npc.gd`, `PONTO_ALCANCADO`).
const CELULA := 0.2
const ALTURA_DA_CELULA := 0.2
const RAIO := 0.2
## A MALHA LARGA (07/10: "muito NPC andando colado na parede, batendo em árvore"): a mesma
## malha assada com o raio de uma pessoa com folga, num mapa só dela, para o passeio ao ar
## livre — o caminho dela passa a RAIO_LARGO das paredes, dos troncos e das cercas. A
## estreita continua existindo para onde a larga não passa (a porta da igreja, o tabuado do
## píer, o vão entre duas casas): `caminho` vai pela larga e EMENDA pela estreita as pontas
## que a larga não alcança.
const RAIO_LARGO := 0.6
## Até onde da partida e da chegada o caminho da larga conta como "chegou": mais longe que
## isso, a estreita emenda o resto.
const CHEGA_LARGO := 1.3
## A emenda que fica mais comprida que isto vezes o caminho estreito (e mais a sobra) é a
## larga indo para o lado errado (outra ilha, a outra margem): vale o caminho estreito.
const DESVIO_MAXIMO_DA_LARGA := 1.5
const SOBRA_DA_LARGA := 3.0
const ALTURA := 1.6
const DEGRAU := 0.4
const RAMPA := 40.0
## A folga em volta da área dos postos e dos marcos.
const FOLGA := 20.0
## As âncoras por onde os moradores andam: os postos e os marcos da festa.
const LUGARES := ["Praça", "Igreja", "Cruzeiro", "PierPiso", "Casa de taipa", "Lavoura", "Terreiro",
	"Gameleira", "Cemitério", "Bar", "Restaurante", "Casa da estrada", "Casa de Carro Quebrado", "Poço",
	# As casas dos moradores novos e os lugares da jornada deles.
	"Casa do arraial 1", "Casa do arraial 4", "Casa do arraial 7", "Casa do guarda", "Casa do pescador",
	"Casa da marisqueira", "Casa da lavadeira", "Casa da rendeira", "Casa da quituteira", "Casa do carpinteiro",
	"Casa de farinha", "Rio 2", "Ponte do rio central",
	# O convite conduz além da área dos postos do arraial. Sem estas âncoras,
	# a malha projetava o Pedro de volta para a borda sul antes do portão.
	"Portão da fazenda", "Pátio da fazenda", "Casarão"]

var _mundo
var _raiz: Node
var _regiao: NavigationRegion3D
var _pronta := false
var _malha_larga: NavigationMesh
var _mapa_largo: RID
var _regiao_larga: RID
var _larga_pronta := false
var _larga_de_novo := false
var _fonte_da_vez: NavigationMeshSourceGeometryData3D
var _malha: NavigationMesh
var _agua := -INF
var _sonda := Vector3.INF
var _assando := false
var _de_novo := false
## Verdadeiro entre `configurar` e a primeira assada, que espera o `_ready` do vale
## acabar: quem pede `reassar()` nesse intervalo não precisa de assada própria.
var _adiada := false
## Quantas malhas já entraram no mapa: a primeira, e uma a cada `reassar`.
var versao := 0


## `raiz` é de onde se lê o que tem colisão: o vale inteiro, e não só o mundo
## — os cômodos (paredes, porta, rampas) moram no nó dos interiores.
func configurar(mundo, raiz: Node) -> void:
	_mundo = mundo
	_raiz = raiz
	add_to_group("navegacao")
	var area := _area()
	if not area.has_volume():
		return
	_agua = _nivel_da_preamar()
	_sonda = mundo.ancoras.get("Praça", Vector3.INF)
	_malha = NavigationMesh.new()
	_malha.cell_size = CELULA
	_malha.cell_height = ALTURA_DA_CELULA
	_malha.agent_radius = RAIO
	_malha.agent_height = ALTURA
	_malha.agent_max_climb = DEGRAU
	_malha.agent_max_slope = RAMPA
	_malha.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	_malha.geometry_collision_mask = 1
	_malha.filter_baking_aabb = area
	var mapa: RID = get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(mapa, CELULA)
	NavigationServer3D.map_set_cell_height(mapa, ALTURA_DA_CELULA)
	# A malha larga, num mapa só dela.
	_malha_larga = _malha.duplicate()
	_malha_larga.agent_radius = RAIO_LARGO
	_mapa_largo = NavigationServer3D.map_create()
	NavigationServer3D.map_set_cell_size(_mapa_largo, CELULA)
	NavigationServer3D.map_set_cell_height(_mapa_largo, ALTURA_DA_CELULA)
	NavigationServer3D.map_set_active(_mapa_largo, true)
	_regiao_larga = NavigationServer3D.region_create()
	NavigationServer3D.region_set_map(_regiao_larga, _mapa_largo)
	# Adiada: o `_ready` do vale ainda cria o saveiro, o cercado da ponte e o cemitério.
	_adiada = true
	_primeira_assada.call_deferred()


## O MAR NA PREAMAR, e não o do instante. A malha se assa uma vez e o mar sobe e desce (a maré vem ligada): assada
## com a água do instante, na baixa-mar ela guardava a faixa de areia que a cheia cobre, e na cheia o Pedro e
## os moradores seguiam um caminho que entra no mar. Com o nível da preamar a malha é só do chão que nunca molha,
## seja a hora em que o vale se monta — `tests/navegacao.gd` monta o vale na baixa-mar e confere.
func _nivel_da_preamar() -> float:
	var regiao = _mundo.get("_region")
	if regiao != null and regiao.has_method("water_level"):
		var nivel := float(regiao.water_level())
		if is_finite(nivel):
			return nivel
	return float(_mundo.water_level()) if _mundo.has_method("water_level") else -INF


## A primeira assada, depois de o `_ready` que chamou `configurar` terminar de montar o vale.
func _primeira_assada() -> void:
	_adiada = false
	_assar()


## O VALE MUDOU: assa de novo. Durante uma assada, fica pedida a próxima.
func reassar() -> void:
	if _malha == null or _adiada:
		return
	if _assando:
		_de_novo = true
		return
	_assar()


func _assar() -> void:
	_assando = true
	# Ler o vale é coisa da linha principal; assar, da outra.
	var fonte := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(_malha, fonte, _raiz)
	_troncos_da_mata(fonte, _malha.filter_baking_aabb)
	_leito_dos_rios(fonte, _malha.filter_baking_aabb)
	_casco_do_saveiro(fonte)
	_alicerces(fonte)
	_pecas_rentes_ao_degrau(fonte)
	# A LARGA ASSA DA FONTE ANTES DOS CORRIMÃOS: tirar as faces deles e pôr a obstrução dos lados é
	# conta da estreita (o raio dela cabe no tabuleiro e subiria no corrimão); na larga, de 0,6, o
	# corrimão inteiro é o que segura o caminho no meio da ponte, como era até 08/10.
	_fonte_da_vez = _copia_da_fonte(fonte)
	_corrimaos_das_pontes(fonte)
	_obstaculos_das_pontes(fonte)
	NavigationServer3D.bake_from_source_geometry_data_async(_malha, fonte, _ao_assar)


## Uma cópia da fonte lida (os triângulos e as obstruções), para a malha larga assar sem o que
## só a estreita mexe depois.
static func _copia_da_fonte(fonte: NavigationMeshSourceGeometryData3D) -> NavigationMeshSourceGeometryData3D:
	var copia := NavigationMeshSourceGeometryData3D.new()
	copia.set_vertices(fonte.get_vertices())
	copia.set_indices(fonte.get_indices())
	copia.set_projected_obstructions(fonte.get_projected_obstructions())
	return copia


## O tabuleiro fica livre; a pegada dos corrimãos não vira piso nem atalho
## pela quina. O raio da malha dá a folga física ao lado da madeira.
func _obstaculos_das_pontes(fonte: NavigationMeshSourceGeometryData3D) -> void:
	for ponte in _mundo.pontes.values():
		var modelo: Node3D = (ponte.get("modelos", {}) as Dictionary).get("de_pe")
		if modelo == null and ponte.has("corrimao"):
			_obstaculos_da_ponte_grande(fonte, ponte)
			continue
		if modelo == null or not modelo.visible or not modelo.has_meta("piso_do_tabuleiro"):
			continue
		var centro: Vector3 = ponte.centro
		var eixo: Vector3 = ponte.ao_longo
		var lado := Vector3(-eixo.z, 0, eixo.x)
		var fator := float(ponte.comprimento) / 9.0
		var piso := float(modelo.get_meta("piso_do_tabuleiro"))
		for sinal: float in [-1.0, 1.0]:
			var contorno := PackedVector3Array()
			for canto in [Vector2(-4.5, 0.5), Vector2(4.5, 0.5), Vector2(4.5, 1.1), Vector2(-4.5, 1.1)]:
				contorno.append(centro + (eixo * canto.x + lado * canto.y * sinal) * fator)
			fonte.add_projected_obstruction(contorno, piso - 0.2, ALTURA + 0.4, false)


## A PONTE GRANDE DA VILA NÃO TEM `modelos` (só a pequena, a do rio grande, tem a de pé e a
## caída), e então não tinha obstrução nenhuma: `_corrimaos_das_pontes` tirava as faces do
## corrimão e dos mourões da cabeceira da fonte e a malha estreita passava a tê-los como chão
## — o caminho da emenda raspava o mourão da entrada e o Pedro empacava nele (#219). A faixa
## do corrimão (`corrimao`, de dentro para fora, medida no GLB) entra como obstáculo projetado
## nos dois lados, do chão da ponte até acima da cabeça, e um palmo além das cabeceiras.
const ALEM_DA_CABECEIRA := 0.3
const PISO_DA_PONTE_GRANDE := 0.7


func _obstaculos_da_ponte_grande(fonte: NavigationMeshSourceGeometryData3D, ponte: Dictionary) -> void:
	var centro: Vector3 = ponte.centro
	var eixo: Vector3 = ponte.ao_longo
	var lado := Vector3(-eixo.z, 0, eixo.x)
	var faixa: Vector2 = ponte.corrimao
	var meio := float(ponte.comprimento) * 0.5 + ALEM_DA_CABECEIRA
	for sinal: float in [-1.0, 1.0]:
		var contorno := PackedVector3Array()
		for canto in [Vector2(-meio, faixa.x), Vector2(meio, faixa.x), Vector2(meio, faixa.y), Vector2(-meio, faixa.y)]:
			contorno.append(centro + eixo * canto.x + lado * canto.y * sinal)
		# Do meio palmo abaixo do tabuleiro (a tábua mais alta chega a 0,7 sobre o centro da ponte) até
		# dois metros acima: o leito debaixo do corrimão também sai, e ninguém passa por baixo da ponte.
		fonte.add_projected_obstruction(contorno, centro.y - 0.5, ALTURA + 1.4, false)


## O corrimão importado não é piso. Remover suas faces da fonte evita
## que a simplificação ligue um caminho sobre ele ao tabuleiro. A geometria
## de colisão e o modelo permanecem completos; somente a leitura da malha muda.
func _corrimaos_das_pontes(fonte: NavigationMeshSourceGeometryData3D) -> void:
	var vertices := fonte.get_vertices()
	var indices := fonte.get_indices()
	var filtrados := PackedInt32Array()
	for i in range(0, indices.size(), 3):
		var meio := Vector3.ZERO
		var alto := -INF
		for j in 3:
			var v := indices[i + j] * 3
			meio += Vector3(vertices[v], vertices[v + 1], vertices[v + 2]) / 3.0
			alto = maxf(alto, vertices[v + 1])
		var corrimao := false
		for ponte in _mundo.pontes.values():
			var centro: Vector3 = ponte.centro
			var modelo: Node3D = (ponte.get("modelos", {}) as Dictionary).get("de_pe")
			var piso := float(modelo.get_meta("piso_do_tabuleiro", centro.y + 0.31)) if modelo != null else centro.y + 0.31
			if modelo == null and ponte.has("corrimao"):
				# A tábua mais alta da ponte grande fica a 0,7 sobre o centro dela (medido no GLB): com o
				# piso em 0,31 as tábuas altas saíam da malha junto com o corrimão, e o tabuleiro ficava furado.
				piso = centro.y + PISO_DA_PONTE_GRANDE
			var eixo: Vector3 = ponte.ao_longo
			var lado := Vector3(-eixo.z, 0, eixo.x)
			var relativo := meio - centro
			if alto > piso + 0.09 and absf(relativo.dot(eixo)) < float(ponte.comprimento) * 0.5 + 0.3 and absf(relativo.dot(lado)) < float(ponte.largura) * 0.5 + 0.3:
				corrimao = true
				break
		if not corrimao:
			filtrados.append_array(indices.slice(i, i + 3))
	fonte.set_indices(filtrados)


## O CASCO DO SAVEIRO ATRACADO como obstáculo: o retângulo dele (`SaveiroVale.pegada_do_casco`),
## do fundo da quilha até além da borda. SEM "carve", como os troncos: o buraco cresce do raio
## do agente, e o caminho não raspa o casco. O mesmo obstáculo come o convés e o pedaço da
## prancha que ficam dentro dele. Barco fora do píer: nada.
func _casco_do_saveiro(fonte: NavigationMeshSourceGeometryData3D) -> void:
	if not is_inside_tree():
		return
	var saveiro := get_tree().get_first_node_in_group("saveiro")
	if saveiro == null or not saveiro.has_method("pegada_do_casco"):
		return
	var pegada: Dictionary = saveiro.pegada_do_casco()
	if pegada.is_empty():
		return
	fonte.add_projected_obstruction(pegada["contorno"], float(pegada["elevacao"]), float(pegada["altura"]), false)


## OS ALICERCES — plataforma baixa debaixo de uma construção (o da capelinha: 1,07 de altura, 0,35 maior que
## ela de cada lado) — são obstáculo com FOLGA. A parede de um alicerce passa do degrau do agente (`DEGRAU`) e a
## malha o contorna rente, e o contorno simplificado da malha (o `edge_max_error` do Recast, 0,26 m aqui) cortava
## a quina dele: o caminho da praça à casa de taipa raspava a esquina e o corpo, mais largo que o agente, prendia
## (`tests/colisoes_de_passeio.gd`, que o conferia andando e carregava isto como exceção). Cada alicerce entra na
## fonte da malha como obstáculo projetado, com a pegada aberta em `FOLGA_DO_ALICERCE` de cada lado; sem "carve"
## o buraco ainda cresce do raio do agente, e o caminho passa a uns 0,55 da parede. Alicerce = corpo de caixa,
## direto no mundo, mais alto que o degrau e mais baixo que o agente, com 3 u ou mais de lado.
const FOLGA_DO_ALICERCE := 0.35
const LADO_MINIMO_DO_ALICERCE := 3.0


func _alicerces(fonte: NavigationMeshSourceGeometryData3D) -> void:
	for alicerce in alicerces():
		fonte.add_projected_obstruction(alicerce["contorno"], float(alicerce["base"]) - 0.2, float(alicerce["altura"]) + 0.4, false)


## AS PEÇAS RENTES AO DEGRAU (o cocho da casa do carro quebrado: 0,44 de altura). Mais altas que o
## degrau do corpo (`DEGRAU`), elas barram quem anda; mas a malha mede a altura em células de
## `ALTURA_DA_CELULA`, e uma caixa só um palmo acima do degrau, no chão inclinado, cai na conta como
## degrau que se sobe — o caminho passava por cima dela e o corpo prendia (`colisoes_de_passeio`,
## 08/10, com a malha larga). Entram como obstáculo projetado, sem folga: o raio do agente a dá.
func _pecas_rentes_ao_degrau(fonte: NavigationMeshSourceGeometryData3D) -> void:
	if _mundo == null:
		return
	for corpo in _mundo.get_children():
		if corpo is not StaticBody3D or ((corpo as StaticBody3D).collision_layer & 1) == 0:
			continue
		for filho in corpo.get_children():
			if filho is not CollisionShape3D or (filho as CollisionShape3D).disabled or (filho as CollisionShape3D).shape is not BoxShape3D:
				continue
			var caixa: Vector3 = ((filho as CollisionShape3D).shape as BoxShape3D).size
			if caixa.y <= DEGRAU or caixa.y >= DEGRAU + 0.1:
				continue
			var t: Transform3D = (filho as CollisionShape3D).global_transform
			var contorno := PackedVector3Array()
			for sinal in [Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(1.0, 1.0), Vector2(-1.0, 1.0)]:
				var canto: Vector3 = t * Vector3(sinal.x * caixa.x * 0.5 / maxf(t.basis.x.length(), 0.0001), 0.0, sinal.y * caixa.z * 0.5 / maxf(t.basis.z.length(), 0.0001))
				canto.y = 0.0
				contorno.append(canto)
			fonte.add_projected_obstruction(contorno, t.origin.y - caixa.y * 0.5 - 0.2, caixa.y + 0.4, false)


## Os alicerces do mundo: {"nome", "contorno" (a pegada com folga, no chão), "base", "altura"}.
func alicerces() -> Array[Dictionary]:
	var achados: Array[Dictionary] = []
	if _mundo == null:
		return achados
	for corpo in _mundo.get_children():
		if corpo is not StaticBody3D or ((corpo as StaticBody3D).collision_layer & 1) == 0:
			continue
		for filho in corpo.get_children():
			if filho is not CollisionShape3D or (filho as CollisionShape3D).disabled or (filho as CollisionShape3D).shape is not BoxShape3D:
				continue
			var caixa: Vector3 = ((filho as CollisionShape3D).shape as BoxShape3D).size
			if caixa.y < DEGRAU + 0.1 or caixa.y > ALTURA - 0.2 or minf(caixa.x, caixa.z) < LADO_MINIMO_DO_ALICERCE:
				continue
			var t: Transform3D = (filho as CollisionShape3D).global_transform
			var metade := Vector2(caixa.x * 0.5 + FOLGA_DO_ALICERCE, caixa.z * 0.5 + FOLGA_DO_ALICERCE)
			var contorno := PackedVector3Array()
			for sinal in [Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(1.0, 1.0), Vector2(-1.0, 1.0)]:
				var canto: Vector3 = t * Vector3(sinal.x * metade.x / maxf(t.basis.x.length(), 0.0001), 0.0, sinal.y * metade.y / maxf(t.basis.z.length(), 0.0001))
				canto.y = 0.0
				contorno.append(canto)
			achados.append({"nome": str(corpo.name), "contorno": contorno, "base": t.origin.y - caixa.y * 0.5, "altura": caixa.y})
	return achados


func esta_pronta() -> bool:
	return _pronta


## O caminho de `de` até `para` pela malha, ou vazio sem malha.
## Entre cômodos, chega pela soleira e cruza o vão alinhado. Cortar a quina
## do umbral prendia a cápsula da igreja com a passagem central livre.
func caminho(de: Vector3, para: Vector3) -> PackedVector3Array:
	if not _pronta:
		return PackedVector3Array()
	var interiores: Node = _raiz.get("interiores")
	if interiores == null:
		return _caminho_na_malha(de, para)
	var saida: String = interiores.contem(de)
	var entrada: String = interiores.contem(para)
	if saida == entrada:
		return _caminho_na_malha(de, para)
	var sala_saida: Node3D = interiores.sala_de(saida)
	var sala_entrada: Node3D = interiores.sala_de(entrada)
	# Uma porta fechada não ganha um trecho que a atravesse à força.
	if (sala_saida != null and sala_saida.trancada()) or (sala_entrada != null and sala_entrada.trancada()):
		return _caminho_na_malha(de, para)
	var pontos := PackedVector3Array()
	var inicio := de
	var fim := para
	if sala_saida != null:
		pontos.append_array(_caminho_na_malha(de, sala_saida.soleira_de_dentro()))
		inicio = sala_saida.soleira_de_fora()
		pontos.append(inicio)
	if sala_entrada != null:
		fim = sala_entrada.soleira_de_fora()
	pontos.append_array(_caminho_na_malha(inicio, fim))
	if sala_entrada != null:
		pontos.append(sala_entrada.soleira_de_dentro())
		pontos.append_array(_caminho_na_malha(sala_entrada.soleira_de_dentro(), para))
	return pontos


## Segmento livre calculado pela malha, preservando o raio das portas.
func _caminho_na_malha(de: Vector3, para: Vector3) -> PackedVector3Array:
	var estreito := caminho_estreito(de, para)
	if not _larga_pronta or estreito.size() < 2:
		return estreito
	# PELA LARGA, que anda longe das paredes e dos troncos. Onde ela não sai de onde o
	# morador está ou não chega ao destino (a porta, o píer), a estreita emenda a ponta.
	var largo := NavigationServer3D.map_get_path(_mapa_largo, de, para, true)
	if largo.size() < 2:
		return estreito
	var pontos := PackedVector3Array()
	if _plano(largo[0], de) > CHEGA_LARGO:
		var ate_a_larga := caminho_estreito(de, largo[0])
		if ate_a_larga.size() < 2:
			return estreito
		pontos.append_array(ate_a_larga)
	pontos.append_array(largo)
	if _plano(largo[largo.size() - 1], para) > CHEGA_LARGO:
		var da_larga := caminho_estreito(largo[largo.size() - 1], para)
		if da_larga.size() < 2:
			return estreito
		pontos.append_array(da_larga)
	if _comprimento(pontos) > _comprimento(estreito) * DESVIO_MAXIMO_DA_LARGA + SOBRA_DA_LARGA:
		return estreito
	return pontos


## O caminho só pela malha estreita (a das portas): o de sempre até 07/10.
func caminho_estreito(de: Vector3, para: Vector3) -> PackedVector3Array:
	if not _pronta:
		return PackedVector3Array()
	return NavigationServer3D.map_get_path(get_world_3d().navigation_map, de, para, true)


## A malha larga já respondeu? (Para os portões: o caminho ao ar livre é o dela.)
func larga_pronta() -> bool:
	return _larga_pronta


## O mapa e a região da malha larga são do servidor de navegação: devolvidos ao sair, ou vazam.
func _exit_tree() -> void:
	if _regiao_larga.is_valid():
		NavigationServer3D.free_rid(_regiao_larga)
		_regiao_larga = RID()
	if _mapa_largo.is_valid():
		NavigationServer3D.free_rid(_mapa_largo)
		_mapa_largo = RID()


## O caminho só pela malha larga, cru (sem as emendas), para os portões medirem.
func caminho_largo(de: Vector3, para: Vector3) -> PackedVector3Array:
	if not _larga_pronta:
		return PackedVector3Array()
	return NavigationServer3D.map_get_path(_mapa_largo, de, para, true)


static func _plano(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## O CAMINHO PELA ESTRADA (07/10: "ao sair da praça, o Pedro tá correndo por trás da casa ao
## invés de pegar a estrada; na água do rio, ao invés de passar na ponte"). O caminho da malha
## é o mais curto, e o mais curto corta por trás das casas e beira a água. Quem conduz o
## jogador vai pela rua: da partida à rua mais perto pela malha, pela rua — as linhas das
## ruas da região, ligadas nos cruzamentos, pelo caminho mais curto delas; a ponte é rua —
## até o ponto da rua mais perto da chegada, e dali à chegada pela malha (a casa da Zefa fica a
## quarenta e dois passos da rua mais perta, e a conta cabe nela). Longe de qualquer
## rua (LONGE_DA_RUA), ou quando a volta pela rua passa de DESVIO_MAXIMO_PELA_RUA vezes a
## reta da malha, vale o caminho da malha.
const LONGE_DA_RUA := 45.0
const DESVIO_MAXIMO_PELA_RUA := 2.2
## Até onde do fim de uma rua ela se liga a outra (um cruzamento, um T).
const LIGA_RUAS_ATE := 2.5
var _grafo_das_ruas := {}


func caminho_pela_estrada(de: Vector3, para: Vector3) -> PackedVector3Array:
	return alinhar_nas_pontes(_caminho_pela_estrada_cru(de, para))


## O CAMINHO PELA ESTRADA, antes de alinhar nas pontes (ver `alinhar_nas_pontes`).
func _caminho_pela_estrada_cru(de: Vector3, para: Vector3) -> PackedVector3Array:
	var direto := caminho(de, para)
	if direto.is_empty():
		return direto
	_montar_o_grafo_das_ruas()
	if _grafo_das_ruas.is_empty():
		return direto
	# A ENTRADA E A SAÍDA DA RUA são o ponto mais perto de um TRECHO dela (os vértices são
	# esparsos: o píer fica longe de todos), postos no grafo como nós de passagem ligados às
	# duas pontas do trecho.
	var entrada := _ponto_da_rua_mais_perto(Vector2(de.x, de.z))
	var saida := _ponto_da_rua_mais_perto(Vector2(para.x, para.z))
	if entrada.is_empty() or saida.is_empty():
		return direto
	if float(entrada["distancia"]) > LONGE_DA_RUA or float(saida["distancia"]) > LONGE_DA_RUA:
		return direto
	if (entrada["ponto"] as Vector2).distance_to(saida["ponto"]) < 1.0:
		return direto
	var nos: PackedVector2Array = (_grafo_das_ruas["nos"] as PackedVector2Array).duplicate()
	var vizinhos: Array = []
	for lista in (_grafo_das_ruas["vizinhos"] as Array):
		vizinhos.append((lista as Array).duplicate())
	var no_entrada := _por_no_grafo(nos, vizinhos, entrada)
	var no_saida := _por_no_grafo(nos, vizinhos, saida)
	var pela_rua := _dijkstra(nos, vizinhos, no_entrada, no_saida)
	if pela_rua.size() < 2:
		return direto
	var pontos := PackedVector3Array()
	var primeiro := _na_malha(nos[no_entrada], de.y)
	var ultimo := _na_malha(nos[no_saida], para.y)
	pontos.append_array(caminho(de, primeiro))
	# CADA TRECHO DA RUA SEGUE A MALHA (#237, #219). Os vértices da rua são esparsos, e a reta entre
	# dois deles não sabe de cerca, de mourão nem de pilar: o Pedro entrava no corredor das roças, dava
	# na cerca nova e voltava para a cidade, e na ponte a reta raspava a cabeceira. O trecho agora é o
	# caminho da malha entre os dois vértices; se algum não tem caminho que chegue ao outro, a rua
	# não é andável por aí e vale o caminho da malha inteiro.
	var anterior := primeiro
	for i in pela_rua:
		var ponto := _na_malha(nos[i], de.y)
		if _plano(anterior, ponto) < 0.05:
			continue
		var elo := _elo_da_rua(anterior, ponto)
		if elo.is_empty():
			return direto
		pontos.append_array(elo)
		anterior = ponto
	pontos.append_array(caminho(ultimo, para))
	if _comprimento(pontos) > _comprimento(direto) * DESVIO_MAXIMO_PELA_RUA:
		return direto
	return pontos


## Quanto o elo da rua pode passar da reta entre os dois vértices (mais a sobra) antes de a rua
## ali ser tida por barrada; e a que distância do vértice o caminho da malha ainda "chegou".
const DESVIO_DO_ELO := 2.0
const SOBRA_DO_ELO := 6.0
const CHEGA_NO_ELO := 1.5


## O trecho da rua de `a` a `b` (sem o `a`, com o `b` no fim) pela malha. Vazio quando a malha não
## liga os dois, ou só os liga por um desvio enorme: a cerca fecha a rua. Trecho que toca uma ponte fica
## reto: o caminho da malha por ali passa pelo leito raso debaixo dela, e quem põe o Pedro no tabuleiro
## é o alinhamento (`alinhar_nas_pontes`).
func _elo_da_rua(a: Vector3, b: Vector3) -> PackedVector3Array:
	var reto := PackedVector3Array([b])
	if _toca_alguma_ponte(a, b):
		return reto
	var via := caminho(a, b)
	if via.size() < 2 or _plano(via[via.size() - 1], b) > CHEGA_NO_ELO:
		return PackedVector3Array()
	if _comprimento(via) > _plano(a, b) * DESVIO_DO_ELO + SOBRA_DO_ELO:
		return PackedVector3Array()
	var elo := via.slice(1)
	elo.append(b)
	return elo


## O ponto da malha mais perto de um ponto da rua: a altura certa (a ponte, e não o leito
## embaixo dela).
func _na_malha(p: Vector2, altura: float) -> Vector3:
	var chao: float = altura
	if _mundo != null and _mundo.has_method("ground_height_at"):
		chao = maxf(float(_mundo.ground_height_at(Vector3(p.x, 0.0, p.y))), altura - 6.0)
	return NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, Vector3(p.x, chao + 0.5, p.y))


static func _comprimento(pontos: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, pontos.size()):
		total += Vector2(pontos[i].x - pontos[i - 1].x, pontos[i].z - pontos[i - 1].z).length()
	return total


## O CAMINHO ATRAVESSA A PONTE PELO EIXO DELA (#219). "O Pedro fica parado na cabeceira de baixo,
## encostado no pilar": o caminho que chegava à ponte vinha em reta de vértice de rua a vértice de
## rua, ou da emenda da malha estreita, e entrava na cabeceira de viés, pelo mourão. A ponte tem
## um corredor andado e provado de ponta a ponta (`travessia_da_ponte_central`: a cápsula pelo
## eixo, nos dois sentidos), e é nele que todo caminho que a cruza passa a entrar: uma chegada
## alinhada a CHEGADA_NA_PONTE da cabeceira, a cabeceira, o meio, a outra cabeceira e a saída.
## A ponte interditada (a do rio grande, cercada até a obra) não é atravessada, e o caminho que
## só passa perto dela, ou que parte de cima dela, fica como está.
const FOLGA_DA_ZONA_DA_PONTE := 2.5
const CHEGADA_NA_PONTE := 3.5
const PASSO_DA_AMOSTRA := 0.5
const DENTRO_DA_CABECEIRA := 0.5


func alinhar_nas_pontes(pontos: PackedVector3Array) -> PackedVector3Array:
	if _mundo == null or pontos.size() < 2:
		return pontos
	var pontes = _mundo.get("pontes")
	if not (pontes is Dictionary):
		return pontos
	var saida := pontos
	for nome in (pontes as Dictionary):
		var ponte: Dictionary = (pontes as Dictionary)[nome]
		if not _ponte_pervia(str(nome)):
			continue
		var altura_do_centro := float((ponte.centro as Vector3).y)
		saida = alinhar_pela_ponte(saida, ponte.centro, ponte.ao_longo, float(ponte.comprimento), float(ponte.largura),
			func(xz: Vector2) -> Vector3: return _no_da_ponte(xz, altura_do_centro))
	return saida


## A ponte de nome `nome` pode ser atravessada agora? Só a do rio grande fecha (a cerca até a obra).
func _ponte_pervia(nome: String) -> bool:
	if nome != "Ponte" or not is_inside_tree():
		return true
	var obra := get_tree().get_first_node_in_group("ponte_do_rio")
	return obra == null or not obra.has_method("interditada") or not bool(obra.interditada())


## O segmento de `a` a `b` entra na zona de alguma ponte pervia?
func _toca_alguma_ponte(a: Vector3, b: Vector3) -> bool:
	if _mundo == null:
		return false
	var pontes = _mundo.get("pontes")
	if not (pontes is Dictionary):
		return false
	for nome in (pontes as Dictionary):
		var ponte: Dictionary = (pontes as Dictionary)[nome]
		if not _ponte_pervia(str(nome)):
			continue
		var comprimento := _plano(a, b)
		var passos := maxi(1, ceili(comprimento / 1.0))
		for k in passos + 1:
			var p := a.lerp(b, float(k) / float(passos))
			if _na_zona_da_ponte(Vector2(p.x, p.z), ponte.centro, ponte.ao_longo, float(ponte.comprimento), float(ponte.largura)):
				return true
	return false


static func _na_zona_da_ponte(p: Vector2, centro: Vector3, eixo: Vector3, comprimento: float, largura: float) -> bool:
	var e := Vector2(eixo.x, eixo.z).normalized()
	var rel := p - Vector2(centro.x, centro.z)
	return absf(rel.dot(e)) <= comprimento * 0.5 + FOLGA_DA_ZONA_DA_PONTE and absf(rel.dot(Vector2(-e.y, e.x))) <= largura * 0.5 + FOLGA_DA_ZONA_DA_PONTE


## A regra sem mundo, para o portão conferir: `pontos` (o caminho) alinhado na ponte de `centro`,
## `eixo` (unitário, horizontal), `comprimento` e `largura`. `no_lugar` põe um ponto do plano (x, z)
## na altura certa. O caminho que não a cruza de uma cabeceira à outra volta igual.
static func alinhar_pela_ponte(pontos: PackedVector3Array, centro: Vector3, eixo: Vector3, comprimento: float, largura: float, no_lugar: Callable) -> PackedVector3Array:
	var e := Vector2(eixo.x, eixo.z)
	if pontos.size() < 2 or e.length() < 0.001:
		return pontos
	e = e.normalized()
	var c := Vector2(centro.x, centro.z)
	var meio := comprimento * 0.5
	var primeiro := -1
	var ultimo := -1
	var u_entra := 0.0
	var u_sai := 0.0
	for i in range(pontos.size() - 1):
		var a := Vector2(pontos[i].x, pontos[i].z)
		var b := Vector2(pontos[i + 1].x, pontos[i + 1].z)
		var passos := maxi(1, ceili(a.distance_to(b) / PASSO_DA_AMOSTRA))
		for k in passos + 1:
			var q := a.lerp(b, float(k) / float(passos))
			if not _na_zona_da_ponte(q, centro, eixo, comprimento, largura):
				continue
			var u := (q - c).dot(e)
			if primeiro < 0:
				primeiro = i
				u_entra = u
			ultimo = i
			u_sai = u
	# Só o que ENTRA por uma cabeceira e SAI pela outra: de uma ponta à outra do corredor.
	if primeiro < 0 or absf(u_entra) < meio * 0.5 or absf(u_sai) < meio * 0.5 or u_entra * u_sai >= 0.0:
		return pontos
	var sinal := signf(u_entra)
	var saida := PackedVector3Array()
	for i in range(0, primeiro + 1):
		if i == 0 or not _na_zona_da_ponte(Vector2(pontos[i].x, pontos[i].z), centro, eixo, comprimento, largura):
			saida.append(pontos[i])
	# Quem já parte dentro da zona, junto da cabeceira, não volta atrás para a chegada alinhada.
	var parte_de_dentro := primeiro == 0 and _na_zona_da_ponte(Vector2(pontos[0].x, pontos[0].z), centro, eixo, comprimento, largura)
	for u: float in [meio + CHEGADA_NA_PONTE, meio + DENTRO_DA_CABECEIRA, meio - DENTRO_DA_CABECEIRA, 0.0]:
		if parte_de_dentro and u > meio + DENTRO_DA_CABECEIRA:
			continue
		saida.append(no_lugar.call(c + e * u * sinal))
	for u: float in [meio - DENTRO_DA_CABECEIRA, meio + DENTRO_DA_CABECEIRA, meio + CHEGADA_NA_PONTE]:
		saida.append(no_lugar.call(c - e * u * sinal))
	for i in range(ultimo + 1, pontos.size()):
		if i == pontos.size() - 1 or not _na_zona_da_ponte(Vector2(pontos[i].x, pontos[i].z), centro, eixo, comprimento, largura):
			saida.append(pontos[i])
	return saida


## O ponto da ponte (ou do chão junto dela) em `xz`: a altura é a do primeiro corpo sólido visto de
## cima — o tabuleiro, ou o chão da cabeceira —, sem contar moradores nem o jogador, que andam por cima.
func _no_da_ponte(xz: Vector2, altura_do_centro: float) -> Vector3:
	var altura := altura_do_centro
	if is_inside_tree():
		var espaco := get_world_3d().direct_space_state
		var de := Vector3(xz.x, altura_do_centro + 6.0, xz.y)
		var ate := Vector3(xz.x, altura_do_centro - 3.0, xz.y)
		var fora: Array[RID] = []
		for tentativa in 6:
			var pergunta := PhysicsRayQueryParameters3D.create(de, ate, 1)
			pergunta.exclude = fora
			var achou := espaco.intersect_ray(pergunta)
			if achou.is_empty():
				break
			if achou.collider is CharacterBody3D:
				fora.append((achou.collider as CollisionObject3D).get_rid())
				continue
			altura = (achou.position as Vector3).y
			break
	return Vector3(xz.x, altura + 0.05, xz.y)


## As ruas da região viram um grafo: os pontos das linhas delas são os nós, os trechos
## entre pontos seguidos são as arestas, e as ruas se ligam onde um ponto de uma cai a
## LIGA_RUAS_ATE (ou meia largura) de um ponto ou de um trecho de outra.
func _montar_o_grafo_das_ruas() -> void:
	if not _grafo_das_ruas.is_empty() or _mundo == null:
		return
	var regiao = _mundo.get("_region")
	if regiao == null or not ("_roads" in regiao):
		return
	var nos := PackedVector2Array()
	var vizinhos: Array = []
	var trechos: Array = []
	var rua_do_no := PackedInt32Array()
	var ruas: Array = regiao._roads
	for r in ruas.size():
		var pontos: PackedVector2Array = (ruas[r] as Dictionary)["points"]
		var primeiro := nos.size()
		for k in pontos.size():
			nos.append(pontos[k])
			vizinhos.append([])
			rua_do_no.append(r)
			if k > 0:
				_ligar(vizinhos, primeiro + k - 1, primeiro + k)
				trechos.append([primeiro + k - 1, primeiro + k])
	# Os cruzamentos: um nó de uma rua perto de um nó de outra; a ponta de uma rua caindo no
	# meio de um trecho de outra (o T) liga-se às duas pontas do trecho.
	for i in nos.size():
		for j in range(i + 1, nos.size()):
			if rua_do_no[i] == rua_do_no[j]:
				continue
			var folga := maxf(LIGA_RUAS_ATE, maxf(float((ruas[rua_do_no[i]] as Dictionary).get("width", 3.0)), float((ruas[rua_do_no[j]] as Dictionary).get("width", 3.0))) * 0.5)
			if nos[i].distance_to(nos[j]) <= folga:
				_ligar(vizinhos, i, j)
	for i in nos.size():
		for r in ruas.size():
			if r == rua_do_no[i]:
				continue
			var pontos: PackedVector2Array = (ruas[r] as Dictionary)["points"]
			var folga := maxf(LIGA_RUAS_ATE, float((ruas[r] as Dictionary).get("width", 3.0)) * 0.5)
			var base := 0
			for rr in r:
				base += ((ruas[rr] as Dictionary)["points"] as PackedVector2Array).size()
			for k in range(pontos.size() - 1):
				var proj := Geometry2D.get_closest_point_to_segment(nos[i], pontos[k], pontos[k + 1])
				if nos[i].distance_to(proj) <= folga:
					_ligar(vizinhos, i, base + k)
					_ligar(vizinhos, i, base + k + 1)
	# OS CRUZAMENTOS EM X: dois trechos de ruas diferentes que se cortam no meio ganham um nó no
	# ponto do corte, ligado às quatro pontas — sem ele, a Rua da Praça e a Rua Principal só se
	# falariam se um vértice de uma caísse em cima da outra.
	var quantos_trechos := trechos.size()
	for i in quantos_trechos:
		for j in range(i + 1, quantos_trechos):
			var ai := int(trechos[i][0])
			var bi := int(trechos[i][1])
			var aj := int(trechos[j][0])
			var bj := int(trechos[j][1])
			if rua_do_no[ai] == rua_do_no[aj]:
				continue
			var corte = Geometry2D.segment_intersects_segment(nos[ai], nos[bi], nos[aj], nos[bj])
			if corte == null:
				continue
			var novo := nos.size()
			nos.append(corte)
			vizinhos.append([])
			rua_do_no.append(rua_do_no[ai])
			for ponta in [ai, bi, aj, bj]:
				_ligar(vizinhos, novo, ponta)
	_grafo_das_ruas = {"nos": nos, "vizinhos": vizinhos, "trechos": trechos}


static func _ligar(vizinhos: Array, a: int, b: int) -> void:
	if a == b:
		return
	if not (vizinhos[a] as Array).has(b):
		(vizinhos[a] as Array).append(b)
	if not (vizinhos[b] as Array).has(a):
		(vizinhos[b] as Array).append(a)


## O ponto de rua mais perto de `p`: {"ponto", "distancia", "a", "b"} — a projeção no trecho
## entre os nós `a` e `b` —, ou {} sem ruas.
func _ponto_da_rua_mais_perto(p: Vector2) -> Dictionary:
	var nos: PackedVector2Array = _grafo_das_ruas["nos"]
	var trechos: Array = _grafo_das_ruas["trechos"]
	var melhor := {}
	var menor := INF
	for trecho in trechos:
		var a := int(trecho[0])
		var b := int(trecho[1])
		var proj := Geometry2D.get_closest_point_to_segment(p, nos[a], nos[b])
		var d := p.distance_to(proj)
		if d < menor:
			menor = d
			melhor = {"ponto": proj, "distancia": d, "a": a, "b": b}
	return melhor


## Põe o ponto de passagem no grafo (uma cópia), ligado às duas pontas do trecho dele.
static func _por_no_grafo(nos: PackedVector2Array, vizinhos: Array, passagem: Dictionary) -> int:
	var i := nos.size()
	nos.append(passagem["ponto"])
	vizinhos.append([])
	_ligar(vizinhos, i, int(passagem["a"]))
	_ligar(vizinhos, i, int(passagem["b"]))
	return i


## O caminho mais curto pelo grafo das ruas (Dijkstra), como lista de nós; vazio sem ligação.
static func _dijkstra(nos: PackedVector2Array, vizinhos: Array, de: int, para: int) -> Array:
	var custo := PackedFloat32Array()
	var anterior := PackedInt32Array()
	var fechado := PackedByteArray()
	custo.resize(nos.size())
	anterior.resize(nos.size())
	fechado.resize(nos.size())
	for i in nos.size():
		custo[i] = INF
		anterior[i] = -1
		fechado[i] = 0
	custo[de] = 0.0
	while true:
		var atual := -1
		var menor := INF
		for i in nos.size():
			if fechado[i] == 0 and custo[i] < menor:
				menor = custo[i]
				atual = i
		if atual < 0:
			break
		if atual == para:
			break
		fechado[atual] = 1
		for v in (vizinhos[atual] as Array):
			var novo: float = custo[atual] + nos[atual].distance_to(nos[int(v)])
			if novo < custo[int(v)]:
				custo[int(v)] = novo
				anterior[int(v)] = atual
	if custo[para] == INF:
		return []
	var saida: Array = []
	var i := para
	while i >= 0:
		saida.push_front(i)
		i = anterior[i]
	return saida


## A área por onde os moradores andam, com folga, do fundo da água para cima.
func _area() -> AABB:
	var ancoras: Dictionary = _mundo.ancoras
	var caixa := AABB()
	var primeiro := true
	for nome in LUGARES:
		if not ancoras.has(nome):
			continue
		var ponto: Vector3 = ancoras[nome]
		if primeiro:
			caixa = AABB(ponto, Vector3.ZERO)
			primeiro = false
		else:
			caixa = caixa.expand(ponto)
	if primeiro:
		return AABB()
	caixa = caixa.grow(FOLGA)
	var agua := float(_mundo.water_level()) if _mundo.has_method("water_level") else caixa.position.y
	caixa.position.y = (agua if is_finite(agua) else caixa.position.y) - 3.0
	caixa.size.y = 80.0
	return caixa


## OS TRONCOS DA MATA como obstáculos: um octógono no pé de cada um, do chão a
## quatro metros.
func _troncos_da_mata(fonte: NavigationMeshSourceGeometryData3D, area: AABB) -> void:
	var regiao = _mundo.get("_region")
	if regiao == null:
		return
	for tronco in regiao._tree_trunks:
		var ponto: Vector2 = tronco.get("point", Vector2.INF)
		if not ponto.is_finite() or not area.has_point(Vector3(ponto.x, area.position.y + 1.0, ponto.y)):
			continue
		# NO PÉ DO TRONCO QUE SE VÊ, o mesmo do corpo (`base_do_tronco`): o ponto
		# de plantio é o meio da copa, e na mata fica a quase um metro da madeira.
		if regiao.has_method("base_do_tronco"):
			var base: Vector3 = regiao.base_do_tronco(tronco)
			ponto = Vector2(base.x, base.z)
		# O octógono POR FORA do tronco: com o raio nos vértices ele ficava por
		# dentro do círculo, e o caminho raspava no tronco pelo meio das arestas.
		# A colisão do coqueiro inclui sua base: usar apenas o raio nominal
		# deixava a rota atravessar a borda do corpo físico (#99/#150).
		var raio_fisico: float = regiao.raio_fisico_do_tronco(tronco)
		var raio := maxf(raio_fisico, 0.2) / cos(PI / 8.0)
		# O cilindro físico acompanha a inclinação do tronco. Um octógono só
		# no pé deixava a parte à altura do corpo atravessar o caminho (orla,
		# tronco com eixo Y = 0,75). Reserva a projeção até a altura do agente,
		# incluindo seu degrau; a copa alta não vira parede de navegação.
		var base_eixo: Vector3 = regiao.base_do_tronco(tronco)
		var alto_eixo: Vector3 = tronco.get("alto_tronco", base_eixo + Vector3.UP)
		var eixo := (alto_eixo - base_eixo).normalized()
		if eixo.y < 0.1:
			eixo = Vector3.UP
		var trecho := minf(float(tronco.get("height", ALTURA)), (ALTURA + DEGRAU) / eixo.y)
		var deslocamento := Vector2(eixo.x, eixo.z) * trecho
		var pegada := PackedVector2Array()
		for ponta in [Vector2.ZERO, deslocamento]:
			for k in 8:
				var angulo := TAU * float(k) / 8.0
				pegada.append(ponto + ponta + Vector2(cos(angulo), sin(angulo)) * raio)
		var contorno := PackedVector3Array()
		for vertice in Geometry2D.convex_hull(pegada):
			contorno.append(Vector3(vertice.x, 0.0, vertice.y))
		# O PÉ DO TRONCO é o chão do vale ali, e não o "ground" da lista, que nem
		# todo tronco traz: sem ele o octógono ficava embaixo da terra.
		var pe: float = _mundo.ground_height_at(Vector3(ponto.x, 0.0, ponto.y))
		# SEM "carve": o obstáculo cortado (carve = true) escapa da erosão do raio
		# do agente, e o contorno simplificado (edge_max_error de 1,3 u) virava
		# uma aresta que passava pelo meio do tronco — o caminho do píer à
		# gameleira raspava a 0,17 u do eixo de um coqueiro de raio 0,24. Sem o
		# corte, o buraco cresce do raio do agente e o caminho contorna o tronco.
		fonte.add_projected_obstruction(contorno, pe - 1.0, 5.0, false)


## O LEITO DOS RIOS como obstáculo: um quadrilátero por trecho da linha do rio,
## da largura da água e um palmo de margem, do fundo até um pouco acima da lâmina.
##
## "Quando Pedro chama o jogador para ir a casa de Dona Zefa na primeira missão,
## faça eles irem atravessando a ponte." O rio central é raso de dar pé, e o
## leito tem colisão — o corpo do jogador anda nele —, então a malha o tinha como
## chão: da praça à Dona Zefa o caminho mais curto molhava o pé a sete unidades
## da ponte, e o Pedro, que vai na frente pela malha, entrava no rio. Morador
## atravessa rio pela ponte, como atravessa o mar pelo píer.
##
## A PONTE FICA porque o obstáculo é PROJETADO até uma altura: o Recast só marca
## o chão que cai entre o fundo e a lâmina d'água mais a folga, e o tabuleiro da
## ponte passa por cima disso.
const MARGEM_DO_RIO := 0.3
const ACIMA_DA_AGUA := 0.3

const CORTAR_O_LEITO := false


func _leito_dos_rios(fonte: NavigationMeshSourceGeometryData3D, area: AABB) -> void:
	# Os rios rasos podem ser atravessados a pé no tutorial. O rio grande
	# exige a ponte, depois da obra; não pode oferecer seu fundo como atalho.
	var regiao = _mundo.get("_region")
	if regiao == null:
		return
	var caixa := Rect2(area.position.x, area.position.z, area.size.x, area.size.z)
	for rio in regiao._rivers:
		# Os rios rasos continuam atravessáveis, preservando o tutorial.
		if not CORTAR_O_LEITO and not bool(rio.get("grande", false)):
			continue
		if not (rio.bounds as Rect2).intersects(caixa):
			continue
		var pontos: PackedVector2Array = rio.points
		var meia := float(rio.width) * 0.5 + MARGEM_DO_RIO
		for i in range(pontos.size() - 1):
			var a: Vector2 = pontos[i]
			var b: Vector2 = pontos[i + 1]
			if not caixa.grow(meia).has_point(a) and not caixa.grow(meia).has_point(b):
				continue
			var ao_longo := b - a
			if ao_longo.length() < 0.01:
				continue
			ao_longo = ao_longo.normalized()
			# Um pouco além das pontas do trecho, para as juntas das curvas não
			# deixarem fresta de chão no meio da água.
			var a2 := a - ao_longo * meia * 0.5
			var b2 := b + ao_longo * meia * 0.5
			var lado := Vector2(-ao_longo.y, ao_longo.x) * meia
			var contorno := PackedVector3Array([
				Vector3(a2.x + lado.x, 0.0, a2.y + lado.y), Vector3(b2.x + lado.x, 0.0, b2.y + lado.y),
				Vector3(b2.x - lado.x, 0.0, b2.y - lado.y), Vector3(a2.x - lado.x, 0.0, a2.y - lado.y)])
			var fundo := minf(_mundo.ground_height_at(Vector3(a.x, 0.0, a.y)), _mundo.ground_height_at(Vector3(b.x, 0.0, b.y)))
			var lamina := maxf(regiao.river_water_level_at(Vector3(a.x, 0.0, a.y)), regiao.river_water_level_at(Vector3(b.x, 0.0, b.y)))
			if not is_finite(lamina):
				continue
			fonte.add_projected_obstruction(contorno, fundo - 1.0, lamina + ACIMA_DA_AGUA - (fundo - 1.0), true)


## ASSADA: fora o fundo do mar e as ilhas, e a malha entra no vale.
func _ao_assar() -> void:
	var vertices := _malha.get_vertices()
	var secos: Array[int] = []
	for i in _malha.get_polygon_count():
		var poligono := _malha.get_polygon(i)
		var meio := Vector3.ZERO
		for indice in poligono:
			meio += vertices[indice]
		meio /= float(poligono.size())
		if is_finite(_agua) and meio.y < _agua + 0.05:
			continue
		secos.append(i)
	var chao := NavigationMesh.new()
	chao.cell_size = _malha.cell_size
	chao.cell_height = _malha.cell_height
	chao.agent_radius = _malha.agent_radius
	chao.agent_height = _malha.agent_height
	chao.agent_max_climb = _malha.agent_max_climb
	chao.agent_max_slope = _malha.agent_max_slope
	chao.set_vertices(vertices)
	for i in _o_pedaco_maior(secos):
		chao.add_polygon(_malha.get_polygon(i))
	var mapa: RID = get_world_3d().navigation_map
	var iteracao := NavigationServer3D.map_get_iteration_id(mapa)
	if _regiao == null:
		_regiao = NavigationRegion3D.new()
		_regiao.name = "MalhaDosMoradores"
		_regiao.navigation_mesh = chao
		add_child(_regiao)
	else:
		_regiao.navigation_mesh = chao
	# O MAPA SÓ VÊ A REGIÃO depois de sincronizar, e isso leva alguns quadros de
	# física (medido: seis não bastavam). Pronta é quando ele responde de fato —
	# e, ao assar de novo, quando a malha que entrou é a nova.
	for i in 600:
		await get_tree().physics_frame
		if NavigationServer3D.map_get_iteration_id(mapa) == iteracao:
			continue
		var perto := NavigationServer3D.map_get_closest_point(mapa, _sonda) if _sonda.is_finite() else Vector3.ZERO
		if perto != Vector3.ZERO:
			break
	_pronta = true
	versao += 1
	_assando = false
	pronta.emit()
	# E A LARGA, depois da estreita, da mesma leitura do vale.
	_assar_a_larga()
	if _de_novo:
		_de_novo = false
		_assar()


## A assada da malha larga, com a leitura do vale que a estreita acabou de usar. Se a larga
## ainda está assando a anterior, fica pedida a próxima.
func _assar_a_larga() -> void:
	if _malha_larga == null or _fonte_da_vez == null:
		return
	if NavigationServer3D.is_baking_navigation_mesh(_malha_larga):
		_larga_de_novo = true
		return
	_larga_de_novo = false
	var fonte := _fonte_da_vez
	_fonte_da_vez = null
	NavigationServer3D.bake_from_source_geometry_data_async(_malha_larga, fonte, _ao_assar_larga)


## A malha larga assou: só o chão seco dela, no mapa dela.
func _ao_assar_larga() -> void:
	var vertices := _malha_larga.get_vertices()
	var chao := NavigationMesh.new()
	chao.cell_size = _malha_larga.cell_size
	chao.cell_height = _malha_larga.cell_height
	chao.agent_radius = _malha_larga.agent_radius
	chao.agent_height = _malha_larga.agent_height
	chao.agent_max_climb = _malha_larga.agent_max_climb
	chao.agent_max_slope = _malha_larga.agent_max_slope
	chao.set_vertices(vertices)
	for i in _malha_larga.get_polygon_count():
		var poligono := _malha_larga.get_polygon(i)
		var meio := Vector3.ZERO
		for indice in poligono:
			meio += vertices[indice]
		meio /= float(poligono.size())
		if is_finite(_agua) and meio.y < _agua + 0.05:
			continue
		chao.add_polygon(poligono)
	var iteracao := NavigationServer3D.map_get_iteration_id(_mapa_largo)
	NavigationServer3D.region_set_navigation_mesh(_regiao_larga, chao)
	for i in 600:
		await get_tree().physics_frame
		if NavigationServer3D.map_get_iteration_id(_mapa_largo) == iteracao:
			continue
		var perto := NavigationServer3D.map_get_closest_point(_mapa_largo, _sonda) if _sonda.is_finite() else Vector3.ZERO
		if perto != Vector3.ZERO:
			break
	_larga_pronta = true
	if _larga_de_novo and _fonte_da_vez != null:
		_assar_a_larga()


## O PEDAÇO LIGADO MAIOR: os polígonos que se tocam por aresta formam pedaços;
## fica o maior — o chão do vale —, e saem os telhados e os tampos.
func _o_pedaco_maior(poligonos: Array[int]) -> Array[int]:
	var por_aresta := {}
	for i in poligonos:
		var p := _malha.get_polygon(i)
		for k in p.size():
			var aresta := Vector2i(mini(p[k], p[(k + 1) % p.size()]), maxi(p[k], p[(k + 1) % p.size()]))
			if not por_aresta.has(aresta):
				por_aresta[aresta] = []
			(por_aresta[aresta] as Array).append(i)
	var pedaco := {}
	var tamanhos: Array[int] = []
	for i in poligonos:
		if pedaco.has(i):
			continue
		var qual := tamanhos.size()
		var fila: Array[int] = [i]
		pedaco[i] = qual
		var quantos := 0
		while not fila.is_empty():
			var atual: int = fila.pop_back()
			quantos += 1
			var p := _malha.get_polygon(atual)
			for k in p.size():
				var aresta := Vector2i(mini(p[k], p[(k + 1) % p.size()]), maxi(p[k], p[(k + 1) % p.size()]))
				for vizinho in por_aresta[aresta]:
					if not pedaco.has(vizinho):
						pedaco[vizinho] = qual
						fila.append(vizinho)
		tamanhos.append(quantos)
	if tamanhos.is_empty():
		return poligonos
	var maior := tamanhos.find(tamanhos.max())
	var ficam: Array[int] = []
	for i in poligonos:
		if pedaco[i] == maior:
			ficam.append(i)
	return ficam
