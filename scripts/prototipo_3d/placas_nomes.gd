extends Node
## Plaquinhas com o nome de cada morador, na identidade do HUD (painel escuro, borda e
## nome dourados), presas acima da cabeça. Somem com QUALQUER balão de fala no ar (o balão
## já traz o nome de quem fala, e é ele que manda: #218), longe demais ou atrás da câmera,
## com o morador fora do vale (o mestre Quirino fora do dia do saveiro: o rótulo dele continua
## `visible`, quem some é ele) e quando AJUSTAR → Cenário → Nomes dos personagens está em Ocultar.
##
##
## O BALÃO TEM PRIORIDADE, E TODAS AS PLACAS SOMEM (#218)
##
## "Enquanto um morador fala, as plaquinhas dos outros continuam na tela, disputando atenção
## com o balão": a Dona Zefa falava no poço e a placa da Dona Estefânia aparecia ao lado.
## Com um balão no ar (conversa, fala solta, o Pedro conduzindo, as cenas — todos moram no
## grupo `baloes_de_fala`), NENHUMA placa fica na tela, nem a do alvo da missão nem a do dono
## do E: as que estavam acesas apagam no fade de sempre (`SEGUNDOS_DO_FADE`), e as que voltam,
## voltam no mesmo fade. Falas seguidas não fazem piscar: as placas só voltam depois de
## `SILENCIO_APOS_O_BALAO` sem nenhum balão no ar, e um balão novo dentro desse prazo reinicia a espera.
##
##
## NO MÁXIMO TRÊS DE CADA VEZ
##
## "Tem muitos popups de personagem, precisamos limitar essa quantidade para evitar
## poluir a tela." (playtest da Build 9B, 06/10/2026)
##
## A praça junta de seis a treze moradores ao longo do dia, e todos estavam a menos
## de 22 m: até treze plaquinhas de uma vez, mais a dica do E, o balão e a seta.
## Agora só `MAXIMO_DE_PLACAS` aparecem (e nenhuma com um balão no ar, ver abaixo), e quem
## leva uma é, nesta ordem:
##
##   1. quem vai receber o E (o nome de quem se vai procurar tem de estar na tela);
##   2. quem a missão acompanhada aponta;
##   3. quem está mais perto do jogador e mais à frente da câmera.
##
## Quem já tem a placa leva um bônus (`BONUS_DE_QUEM_JA_TEM`): dois moradores a
## distâncias quase iguais não trocam a vaga a cada quadro. Não entra quem está sob um
## painel do HUD, sob um balão ou uma dica do E (a do dono do E é a que sobe acima da placa
## dele), cortado pela borda da tela, ou em cima de uma placa melhor — tudo com histerese (quem
## já tem a placa aguenta mais sobreposição), para duas caixas a um pixel do limite não
## trocarem a vaga a cada quadro. A placa que entra ou sai ACENDE e APAGA em
## `SEGUNDOS_DO_FADE`, e a vaga só é de outro quando a que saiu apagou: nunca mais de
## `maximo` placas ligadas, nem no meio da troca.
##
##
## COM PESO
##
## O ponto da cabeça é o alvo de uma mola (`suavizador_de_tela.gd`): a placa desliza
## até ele, e o tremor de um pixel da câmera não a move.
##
##
## NUNCA NO ROSTO, E ATRÁS DO QUE ESTÁ MAIS PERTO (#184)
##
## "A plaquinha de nome cai em cima do personagem: 'Dona Zefa' cobre o rosto e o chapéu
## dela." A placa conhecia o HUD, o balão e a dica do E, mas não a silhueta de ninguém.
## Agora cada personagem à vista (os moradores e o jogador) projeta duas caixas na tela,
## a da CABEÇA (do chapéu ao queixo) e a do TRONCO, a partir da altura real do modelo (a
## malha mais alta, e não só o `altura` do dado):
##
##   1. ROSTO: a placa que cairia sobre a cabeça de qualquer um (a do próprio dono, com a
##      câmera perto e baixa, ou a de quem está atrás de outro) SOBE até ficar livre dela,
##      só o que falta. Se para isso teria de subir mais que `SUBIDA_MAXIMA` (o dono do E e
##      o alvo da missão aguentam `SUBIDA_MAXIMA_DE_QUEM_IMPORTA`) não há lugar bom, e ela não aparece.
##      A subida tem histerese: sobe na hora, só desce quando a folga passa de `DESCE_SO_DEPOIS` px.
##   2. PROFUNDIDADE: a placa de quem está MAIS LONGE da câmera que um personagem ou um balão
##      (por mais que `PROFUNDIDADE_MINIMA`) e passa na frente dele fica transparente, tanto
##      mais quanto maior a parte coberta e quanto maior a diferença de distância. Nunca
##      some por isso: o piso é `ALFA_ATRAS` (`ALFA_ATRAS_DE_QUEM_IMPORTA` para o dono do E e o
##      alvo da missão), e o alfa anda em `SEGUNDOS_DO_ALFA_ATRAS`, sem piscar.

const SuavizadorDeTela = preload("res://scripts/prototipo_3d/suavizador_de_tela.gd")
const PopupsDoMundo = preload("res://scripts/prototipo_3d/popups_do_mundo.gd")
const FocoDoE = preload("res://scripts/prototipo_3d/foco_do_e.gd")
const Camadas = preload("res://scripts/prototipo_3d/camadas.gd")
## A árvore ganha espaço local; uma placa apagada precisa de mais folga para voltar.
const FOLGA_ARVORE := 12.0
const FOLGA_ARVORE_PARA_VOLTAR := 24.0
const INTERVALO_OCLUSAO := 0.12
const ESTABILIZAR_OCLUSAO := 0.18

const MAXIMO_DE_PLACAS := 3
## #218. Quanto tempo (s) as placas seguem apagadas depois que o último balão de fala se vai: cobre o
## vão entre duas falas seguidas (a fila pausa uma fração de segundo entre elas) sem piscar.
const SILENCIO_APOS_O_BALAO := 0.6
## #184. As caixas de um personagem na tela (metros, a partir dos pés): a cabeça vai do queixo ao
## alto do modelo (`FRACAO_DA_CABECA` da altura); o tronco, dali até `FRACAO_DO_TRONCO` da altura
## abaixo do topo. As meias-larguras são em metros no plano da câmera.
const FRACAO_DA_CABECA := 0.17
const FRACAO_DO_TRONCO := 0.58
const MEIA_LARGURA_DA_CABECA := 0.24
const MEIA_LARGURA_DO_TRONCO := 0.36
## Quanto o modelo pode passar do `altura` do dado (o chapéu, o cabelo) e de quanto em quanto
## tempo se mede de novo (s).
const EXCESSO_DO_MODELO := 1.12
## A altura (m) de quem não declara `altura` nem `character_height`.
const ALTURA_DE_QUEM_NAO_DIZ := 1.75
const INTERVALO_DA_MEDIDA := 1.5
## A folga (px) entre a placa e a cabeça que ela deixa livre, e o quanto a cabeça pode ser
## tocada de lado sem contar (a caixa encolhe tanto).
const FOLGA_DO_ROSTO := 4.0
const ENCOLHE_DO_ROSTO := 3.0
## O quanto a placa pode subir (px) para liberar uma cabeça antes de desistir, e quanto mais aguenta
## quem já tem a placa. Quem importa sobe mais.
const SUBIDA_MAXIMA := 90.0
const SUBIDA_MAXIMA_DE_QUEM_IMPORTA := 220.0
const SUBIDA_DE_QUEM_JA_TEM := 1.25
const VELOCIDADE_DA_SUBIDA := 480.0
const DESCE_SO_DEPOIS := 8.0
## A placa de quem está mais longe que isto (m) de um personagem ou balão que ela cobre esmaece:
## nada até `PROFUNDIDADE_MINIMA`, cheio em `PROFUNDIDADE_PLENA`; e `COBERTURA_PLENA` é a fração
## coberta da placa que já conta como cheia.
const PROFUNDIDADE_MINIMA := 0.6
const PROFUNDIDADE_PLENA := 5.0
const COBERTURA_PLENA := 0.4
const ALFA_ATRAS := 0.22
const ALFA_ATRAS_DE_QUEM_IMPORTA := 0.6
const SEGUNDOS_DO_ALFA_ATRAS := 0.25
## SÓ DE PERTO (#90): inteira até PLACA_PERTO, esmaecendo até PLACA_LONGE, e nada
## além — na live os nomes da praça inteira apareciam a vinte e duas unidades.
const PLACA_PERTO := 6.0
const PLACA_LONGE := 10.0
## QUEM IMPORTA SE VÊ DE MAIS LONGE: o dono do E e quem a missão aponta levam a placa
## inteira até aqui (o nome de quem se vai procurar tem de estar na tela, a seta o
## aponta); só o resto da praça fica "só de perto".
const DISTANCIA_DE_QUEM_IMPORTA := 16.0
const ACIMA_DA_CABECA := 0.1
const FUNDO := Color(0.055, 0.085, 0.075, 0.88)
const OURO := Color("b49a60")
const NOME := Color("e2c47f")
## O peso da placa: ver `suavizador_de_tela.gd`.
const TEMPO_DE_SEGUIR := 0.25
const CORREIA := 110.0
const SEGUNDOS_DO_FADE := 0.18
## A conta de quem leva a vaga: a distância (m) mais isto vezes o quanto está de
## costas (0 de frente, 1 de costas), menos os vieses. Menor leva.
const PESO_DO_RUMO := 6.0
const VIES_DO_E := 100.0
const VIES_DA_MISSAO := 60.0
const BONUS_DE_QUEM_JA_TEM := 3.0
## A SOBREPOSIÇÃO TEM HISTERESE: uma placa só entra se menos que `SOBREPOSTA_PARA_ENTRAR` dela
## fica sob outra coisa (placa melhor, painel do HUD, balão, dica do E), e só sai se passar de
## `SOBREPOSTA_PARA_SAIR`. Com um limite só, duas caixas a um pixel do limite (a câmera treme,
## o morador respira) faziam a vaga trocar de mão a cada quadro, e a tela piscava.
const SOBREPOSTA_PARA_ENTRAR := 0.15
const SOBREPOSTA_PARA_SAIR := 0.45
## Sob a dica do E (ou na coluna dela) a placa dos outros não tem tolerância: qualquer pedaço coberto a faz ceder.
const SOBREPOSTA_DA_DICA := 0.0
## A placa mais perto da borda da tela que isto não aparece (cortada, ou sob o HUD); quem já tem a
## placa aguenta `MARGEM_DE_QUEM_JA_TEM` px a mais antes de perdê-la.
const MARGEM_DA_TELA := 14.0
const MARGEM_DE_QUEM_JA_TEM := 12.0
## O morador está "no alvo" da missão a menos disto (m, no chão) do ponto da seta.
const RAIO_DA_MISSAO := 3.0

var _jogador: Node3D
## Morador -> placa. O portão de saveiro e o de vida leem este mapa.
var _placas: Dictionary = {}
## Falso enquanto alguma tela está aberta. Ver `permitir`.
var _permitido := true
## Quantas placas ligadas, no máximo (o portão da falsificação sobe isto).
var maximo := MAXIMO_DE_PLACAS
## Falso desliga o rosto e a profundidade (#184): o jogo de antes, para o portão reprovar.
var respeita_rostos := true
## Falso tira a prioridade do balão (#218): o jogo de antes, que só descontava uma vaga com um balão
## no ar, para o portão reprovar.
var cala_com_balao := true
## Quanto falta (s) para as placas poderem voltar depois do último balão (ver `SILENCIO_APOS_O_BALAO`).
var _silencio := 0.0
## Morador -> a mola da placa dele, e o quanto ela está acesa (0 a 1).
var _molas: Dictionary = {}
var _alfa: Dictionary = {}
## Quem ganhou a vaga no quadro passado.
var _vaga: Dictionary = {}
var _oclusao: Dictionary = {}
## Morador -> quanto a placa sobe (px) para liberar uma cabeça, e o alfa que a profundidade deixa a ela.
var _subida: Dictionary = {}
var _alfa_atras: Dictionary = {}
## Personagem -> {"topo": altura real (m), "ate": até quando vale, em s}, a medida do modelo (ver `_altura_real`).
var _medidas: Dictionary = {}


func _init() -> void:
	# Antes de tudo: as dicas do E e o balão leem o retângulo fresco das placas
	# (`popups_do_mundo.gd`).
	process_priority = -20


## As placas estão apagadas pela prioridade do balão (ou pelo instante que se segue a ele)? Para o portão.
func em_silencio() -> bool:
	return cala_com_balao and _silencio > 0.0


func configurar(jogador: Node3D, camada: Control) -> void:
	_jogador = jogador
	for morador in get_tree().get_nodes_in_group("moradores"):
		_placas[morador] = _criar(camada, String(morador.dados.get("nome", "Morador")))
		_molas[morador] = SuavizadorDeTela.new()
		_alfa[morador] = 0.0
		# O rótulo 3D antigo fica só como sinal de "sem balão"; quem aparece é a placa.
		if morador.get("nome_label") != null:
			morador.nome_label.modulate.a = 0.0
			morador.nome_label.outline_modulate.a = 0.0
			# Sem camada nenhuma a câmera não o enfileira (com alfa zero ele ainda entrava
			# na passada transparente); `visible` fica como está, que é o sinal de "sem balão".
			morador.nome_label.layers = 0


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var em_jogo: bool = camera != null and _jogador != null and camera == _jogador.get("camera")
	var liberado: bool = _permitido and em_jogo and Estilo.mostrar_nomes
	var tela := get_viewport().get_visible_rect().size
	var baloes: Array[Rect2] = []
	var dicas: Array[Rect2] = []
	var dicas_arvore: Array[Rect2] = []
	# A coluna acima da placa de quem vai receber o E: é a da dica dele, e fica livre para ela.
	var colunas: Array[Rect2] = []
	var dono_do_e: Node3D = null
	var da_missao: Node3D = null
	var frente := Vector3.ZERO
	# #184: as cabeças (para a placa não cair no rosto de ninguém) e o que está na tela com a sua
	# distância à câmera (para a placa de quem está atrás de um deles esmaecer).
	var rostos: Array[Rect2] = []
	var no_caminho: Array = []
	if liberado:
		baloes = PopupsDoMundo.retangulos_dos_baloes(self)
		dicas = PopupsDoMundo.retangulos(self, PopupsDoMundo.GRUPO_DICAS)
		for dica: Node in get_tree().get_nodes_in_group(PopupsDoMundo.GRUPO_DICAS):
			if dica is Control and dica.is_visible_in_tree() and bool(dica.get_meta("interacao_arvore", false)):
				dicas_arvore.append((dica as Control).get_global_rect())
		dono_do_e = _dono_do_e()
		da_missao = _da_missao()
		var coluna := _coluna_da_dica(camera, dono_do_e, dicas)
		if coluna.size != Vector2.ZERO:
			colunas.append(coluna)
		frente = -camera.global_transform.basis.z
		frente.y = 0.0
		frente = frente.normalized()
		if respeita_rostos:
			for personagem: Dictionary in _caixas_dos_personagens(camera):
				rostos.append(encolhida(personagem["cabeca"] as Rect2, ENCOLHE_DO_ROSTO))
				no_caminho.append({"no": personagem["no"], "caixa": personagem["corpo"], "distancia": personagem["distancia"]})
			no_caminho.append_array(_baloes_com_profundidade(camera))
			# O "?"/"!" de missão (#216) é do mundo 3D e fica por baixo de toda placa: a placa sobe
			# para não o cobrir, ou desiste se fosse subir demais, como faz com um rosto.
			rostos.append_array(PopupsDoMundo.retangulos_dos_marcadores(self))
	# O BALÃO TEM PRIORIDADE (#218): com um no ar, ou nos instantes depois dele, ninguém leva placa.
	if cala_com_balao and not baloes.is_empty():
		_silencio = SILENCIO_APOS_O_BALAO
	else:
		_silencio = maxf(_silencio - delta, 0.0)
	var limite := 0 if cala_com_balao and _silencio > 0.0 else maximo - (1 if not baloes.is_empty() else 0)
	var util := Rect2(Vector2.ZERO, tela).grow(-MARGEM_DA_TELA)
	var paineis := PopupsDoMundo.paineis_do_hud(tela)
	# A projeção da cabeça de todo morador à frente da câmera (a placa que apaga a segue
	# até apagar), e, entre eles, quem pode levar uma placa agora.
	var ancoras := {}
	# Morador -> o quanto a distância deixa a placa dele acesa (1 perto, 0 em PLACA_LONGE).
	var perto := {}
	var candidatos: Array = []
	for morador: Node3D in _placas.keys():
		if not is_instance_valid(morador):
			_placas[morador].queue_free()
			_placas.erase(morador)
			_molas.erase(morador)
			_alfa.erase(morador)
			_vaga.erase(morador)
			_oclusao.erase(morador)
			_subida.erase(morador)
			_alfa_atras.erase(morador)
			_medidas.erase(morador)
			continue
		var topo := morador.global_position + Vector3(0, _altura_real(morador) + ACIMA_DA_CABECA, 0)
		if not liberado or not morador.is_visible_in_tree() or camera.is_position_behind(topo):
			_apagar_ja(morador)
			continue
		var ancora := camera.unproject_position(topo)
		ancoras[morador] = ancora
		var distancia := morador.global_position.distance_to(_jogador.global_position)
		# SÓ DE PERTO (#90): a placa esmaece de PLACA_PERTO a PLACA_LONGE, por cima do
		# acender e apagar da vaga, e além de PLACA_LONGE nem disputa a vaga — menos a de
		# quem importa (o dono do E, quem a missão aponta), inteira até
		# DISTANCIA_DE_QUEM_IMPORTA.
		var importa := morador == dono_do_e or morador == da_missao
		perto[morador] = 1.0 if importa else 1.0 - smoothstep(PLACA_PERTO, PLACA_LONGE, distancia)
		if not morador.nome_label.is_visible_in_tree():
			continue
		if distancia >= (DISTANCIA_DE_QUEM_IMPORTA if importa else PLACA_LONGE):
			continue
		if _nome_ja_identificado(morador) or not _visivel_para_camera(morador, camera):
			_apagar_ja(morador)
			continue
		_placas[morador].scale = Vector2.ONE * Tela.escala_componente("nomes")
		var tamanho: Vector2 = (_placas[morador] as PanelContainer).get_combined_minimum_size() * _placas[morador].scale
		var caixa := Rect2(ancora - Vector2(tamanho.x * 0.5, tamanho.y), tamanho)
		# A placa inteira na tela: cortada pela borda, ou meio sob o HUD, não é placa. (Com histerese: quem
		# já tem a placa aguenta mais.)
		var tinha := _vaga.has(morador)
		if _concorre_com_arvore(caixa, dicas_arvore, tinha):
			continue
		# NUNCA NO ROSTO (#184): sobe até liberar toda cabeça que cobriria, ou desiste se for demais.
		var precisa := subida_do_rosto(caixa, rostos, FOLGA_DO_ROSTO)
		var teto := (SUBIDA_MAXIMA_DE_QUEM_IMPORTA if importa else SUBIDA_MAXIMA) * (SUBIDA_DE_QUEM_JA_TEM if tinha else 1.0)
		if precisa > teto:
			continue
		caixa.position.y -= _acertar_subida(morador, precisa, delta)
		var tolerancia := SOBREPOSTA_PARA_SAIR if tinha else SOBREPOSTA_PARA_ENTRAR
		var area_util := util.grow(MARGEM_DE_QUEM_JA_TEM) if tinha else util
		if not area_util.encloses(caixa) or _encosta_em_algum(caixa, paineis, tolerancia) or _encosta_em_algum(caixa, baloes, tolerancia):
			continue
		# A DICA DO E É DE QUEM VAI RECEBER O E, e sobe por cima da placa dele: a placa dos outros que ficaria
		# sob a dica (alguém atrás dele na mesma linha da câmera) cede, em vez de empurrar a dica para longe
		# do dono dela.
		#
		# SEM HISTERESE AQUI: a dica do E é dona do lugar dela, e a placa que a cobre por pouco (menos que a
		# tolerância de entrar) a empurraria para cima assim que acendesse de novo — e a dica não voltaria ao
		# lugar de antes quando a placa de quem está atrás cede. Qualquer cobertura da dica, ou da coluna dela,
		# faz a placa ceder.
		if morador != dono_do_e and (_encosta_em_algum(caixa, dicas, SOBREPOSTA_DA_DICA) or _encosta_em_algum(caixa, colunas, SOBREPOSTA_DA_DICA)):
			continue
		var rumo := 0.0
		var para_ele := morador.global_position - camera.global_position
		para_ele.y = 0.0
		if para_ele.length() > 0.01 and frente.length() > 0.01:
			rumo = (1.0 - frente.dot(para_ele.normalized())) * 0.5
		candidatos.append({
			"no": morador, "distancia": distancia, "rumo": rumo, "caixa": caixa,
			"dono_do_e": morador == dono_do_e, "da_missao": morador == da_missao,
			"tinha": tinha,
			"fundo": alfa_por_profundidade(caixa, camera.global_position.distance_to(morador.global_position),
				no_caminho, ALFA_ATRAS_DE_QUEM_IMPORTA if importa else ALFA_ATRAS, morador),
		})
	var vencedores := {}
	# Quanto o que está mais perto deixa a placa de cada vencedor acesa (1 sem nada na frente).
	var fundos := {}
	for indice in escolher(candidatos, limite):
		vencedores[candidatos[indice]["no"]] = true
		fundos[candidatos[indice]["no"]] = float(candidatos[indice]["fundo"])
	_vaga = vencedores
	var ligadas := 0
	for placa: PanelContainer in _placas.values():
		if placa.visible:
			ligadas += 1
	for morador: Node3D in ancoras.keys():
		var placa: PanelContainer = _placas[morador]
		var mola: SuavizadorDeTela = _molas[morador]
		var alfa := float(_alfa.get(morador, 0.0))
		var quer := 1.0 if vencedores.has(morador) else 0.0
		var sobe := Vector2(0.0, float(_subida.get(morador, 0.0)))
		if alfa <= 0.0:
			if quer <= 0.0:
				continue
			# A VAGA É DE OUTRO ATÉ ELE APAGAR: nunca mais de `maximo` ligadas, nem na troca.
			if ligadas >= maximo:
				continue
			ligadas += 1
			mola.reiniciar(ancoras[morador] - sobe)
			_alfa_atras[morador] = float(fundos.get(morador, 1.0))
		alfa = move_toward(alfa, quer, maxf(delta, 1.0 / 60.0) / SEGUNDOS_DO_FADE)
		_alfa[morador] = alfa
		# A PROFUNDIDADE (#184): o que está na frente da placa a esmaece aos poucos.
		var atras := float(_alfa_atras.get(morador, 1.0))
		if fundos.has(morador):
			atras = move_toward(atras, float(fundos[morador]), maxf(delta, 1.0 / 60.0) / SEGUNDOS_DO_ALFA_ATRAS)
			_alfa_atras[morador] = atras
		placa.modulate.a = alfa * float(perto.get(morador, 1.0)) * atras
		placa.visible = alfa > 0.0
		if placa.visible:
			placa.reset_size()
			var onde := mola.seguir(ancoras[morador] - sobe, delta, TEMPO_DE_SEGUIR,
				SuavizadorDeTela.VELOCIDADE_MAXIMA, SuavizadorDeTela.ZONA_MORTA, CORREIA)
			placa.position = (onde - Vector2(placa.size.x * placa.scale.x * 0.5, placa.size.y * placa.scale.y)).round()


## QUEM LEVA UMA PLACA entre `candidatos` — cada um {"distancia", "rumo", "caixa",
## "dono_do_e", "da_missao", "tinha"} —, no máximo `limite`: os índices, do melhor
## para o pior. O dono do E e o alvo da missão vêm antes de qualquer distância; só o dono
## do E não cede a ninguém, e os outros (o alvo da missão também) pulam quem se sobrepõe a
## um melhor. Pura, para o portão conferir a regra sem montar o vale.
static func escolher(candidatos: Array, limite: int) -> Array[int]:
	var notas: Array[float] = []
	var ordem: Array[int] = []
	for i in candidatos.size():
		notas.append(_nota(candidatos[i]))
		ordem.append(i)
	ordem.sort_custom(func(a: int, b: int) -> bool:
		return a < b if is_equal_approx(notas[a], notas[b]) else notas[a] < notas[b])
	var escolhidos: Array[int] = []
	for i in ordem:
		if escolhidos.size() >= limite:
			break
		var candidato: Dictionary = candidatos[i]
		# Só o dono do E não cede a ninguém: o nome de quem se vai procurar tem de estar na tela.
		if not bool(candidato.get("dono_do_e", false)) and _cobre_algum_melhor(candidato, candidatos, escolhidos):
			continue
		escolhidos.append(i)
	return escolhidos


## A conta de um candidato: a distância mais o rumo, menos os vieses. Menor leva.
static func _nota(candidato: Dictionary) -> float:
	var nota := float(candidato.get("distancia", 0.0)) + float(candidato.get("rumo", 0.0)) * PESO_DO_RUMO
	if bool(candidato.get("dono_do_e", false)):
		nota -= VIES_DO_E
	if bool(candidato.get("da_missao", false)):
		nota -= VIES_DA_MISSAO
	if bool(candidato.get("tinha", false)):
		nota -= BONUS_DE_QUEM_JA_TEM
	return nota


static func _cobre_algum_melhor(candidato: Dictionary, candidatos: Array, escolhidos: Array[int]) -> bool:
	var caixa: Rect2 = candidato.get("caixa", Rect2())
	var tolerancia := SOBREPOSTA_PARA_SAIR if bool(candidato.get("tinha", false)) else SOBREPOSTA_PARA_ENTRAR
	for j in escolhidos:
		var outra: Rect2 = candidatos[j].get("caixa", Rect2())
		var menor := minf(caixa.get_area(), outra.get_area())
		if menor > 0.0 and caixa.intersection(outra).get_area() > tolerancia * menor:
			return true
	return false


## A caixa tem mais que `tolerancia` dela coberta por algum destes?
func _encosta_em_algum(caixa: Rect2, outros: Array[Rect2], tolerancia: float) -> bool:
	for outro in outros:
		if PopupsDoMundo.cobertura(caixa, outro) > tolerancia * caixa.get_area():
			return true
	return false


## Identidade do alvo, não busca no texto traduzido: somente o nome redundante sai.
func _nome_ja_identificado(morador: Node3D) -> bool:
	for dica: Node in get_tree().get_nodes_in_group(PopupsDoMundo.GRUPO_DICAS):
		if dica is Control and dica.is_visible_in_tree() and dica.has_meta("nome_identificado") and dica.get_meta("nome_identificado") == morador:
			return true
	return false


static func _concorre_com_arvore(caixa: Rect2, dicas: Array[Rect2], tinha: bool) -> bool:
	var folga := FOLGA_ARVORE if tinha else FOLGA_ARVORE_PARA_VOLTAR
	for dica in dicas:
		if caixa.intersects(dica.grow(folga)):
			return true
	return false


## A caixa de um rosto sem a beirada de `px` de cada lado (o roçar de lado não é cobrir), nunca mais que
## um quarto da largura e da altura dela: o rosto de quem está longe tem poucos pixels. Pura.
static func encolhida(caixa: Rect2, px: float) -> Rect2:
	var dx := minf(px, caixa.size.x * 0.25)
	var dy := minf(px, caixa.size.y * 0.25)
	return Rect2(caixa.position + Vector2(dx, dy), caixa.size - Vector2(dx, dy) * 2.0)


## O QUANTO A PLACA SOBE (px) para liberar um rosto, medido sobre a caixa sem subida: `precisa`
## é o que falta agora e `_subida` o que a placa já subiu. Sobe na hora (a mola da placa
## suaviza); só desce depois de a folga passar de `DESCE_SO_DEPOIS` px, para a cabeça que
## respira não fazer a placa tremer.
func _acertar_subida(morador: Node3D, precisa: float, delta: float) -> float:
	var atual := float(_subida.get(morador, 0.0))
	var alvo := atual
	if precisa > atual or precisa < atual - DESCE_SO_DEPOIS:
		alvo = precisa
	atual = move_toward(atual, alvo, VELOCIDADE_DA_SUBIDA * maxf(delta, 1.0 / 60.0))
	_subida[morador] = atual
	return atual


## O QUANTO A PLACA SOBE para ficar livre de toda cabeça de `rostos` que ela cobriria: só o que
## falta, empilhando sobre várias (do rosto mais baixo na tela para o mais alto). Pura.
static func subida_do_rosto(caixa: Rect2, rostos: Array[Rect2], folga: float) -> float:
	if rostos.is_empty() or caixa.size == Vector2.ZERO:
		return 0.0
	return maxf(caixa.position.y - PopupsDoMundo.afastar_de(caixa, rostos, folga).position.y, 0.0)


## O ALFA QUE A PROFUNDIDADE DEIXA À PLACA (#184): `caixa` é a placa de alguém a `distancia` da câmera,
## `atras` o que há na tela — cada um {"no", "caixa", "distancia"}, personagens e balões. A placa
## só esmaece por quem está MAIS PERTO da câmera que ela (por mais que `PROFUNDIDADE_MINIMA`) e que ela
## cobre, e esmaece mais com mais cobertura e com mais diferença de distância; nunca abaixo de
## `minimo`. `ignorar` é o dono da placa (o corpo dele não conta). Pura.
static func alfa_por_profundidade(caixa: Rect2, distancia: float, atras: Array, minimo: float, ignorar: Object = null) -> float:
	var area := caixa.get_area()
	if area <= 0.0:
		return 1.0
	var alfa := 1.0
	for outro: Dictionary in atras:
		if ignorar != null and outro.get("no") == ignorar:
			continue
		var diferenca := distancia - float(outro.get("distancia", distancia))
		if diferenca <= PROFUNDIDADE_MINIMA:
			continue
		var coberta := PopupsDoMundo.cobertura(caixa, outro.get("caixa", Rect2())) / area
		if coberta <= 0.0:
			continue
		var peso := clampf(coberta / COBERTURA_PLENA, 0.0, 1.0) * smoothstep(PROFUNDIDADE_MINIMA, PROFUNDIDADE_PLENA, diferenca)
		alfa = minf(alfa, lerpf(1.0, minimo, peso))
	return alfa


## A caixa, em tela, de uma fatia do corpo (de `de` a `ate` metros de altura, com `meia_largura` para cada
## lado no plano da câmera) de quem está em `pes`. Vazia se algum canto fica atrás da câmera.
static func caixa_na_tela(camera: Camera3D, pes: Vector3, de: float, ate: float, meia_largura: float) -> Rect2:
	var lado := camera.global_basis.x * meia_largura
	var minimo := Vector2(INF, INF)
	var maximo := Vector2(-INF, -INF)
	for altura in [de, ate]:
		for sinal in [-1.0, 1.0]:
			var ponto: Vector3 = pes + Vector3.UP * float(altura) + lado * float(sinal)
			if camera.is_position_behind(ponto):
				return Rect2()
			var tela := camera.unproject_position(ponto)
			minimo = minimo.min(tela)
			maximo = maximo.max(tela)
	return Rect2(minimo, maximo - minimo)


## Cada personagem à vista (os moradores e o jogador): {"no", "cabeca", "corpo", "distancia"}. A cabeça
## é a caixa do rosto e do chapéu; o corpo, a cabeça com o tronco.
func _caixas_dos_personagens(camera: Camera3D) -> Array:
	var saida: Array = []
	var todos: Array = _placas.keys()
	if _jogador != null:
		todos.append(_jogador)
	for no: Node3D in todos:
		if not is_instance_valid(no) or not no.is_visible_in_tree():
			continue
		var altura := _altura_real(no)
		var pes := no.global_position
		var cabeca := caixa_na_tela(camera, pes, altura * (1.0 - FRACAO_DA_CABECA), altura, MEIA_LARGURA_DA_CABECA)
		if cabeca.size == Vector2.ZERO:
			continue
		var tronco := caixa_na_tela(camera, pes, altura * (1.0 - FRACAO_DO_TRONCO), altura * (1.0 - FRACAO_DA_CABECA), MEIA_LARGURA_DO_TRONCO)
		saida.append({"no": no, "cabeca": cabeca, "corpo": cabeca.merge(tronco) if tronco.size != Vector2.ZERO else cabeca,
			"distancia": camera.global_position.distance_to(pes)})
	return saida


## Os balões no ar com a distância de quem fala à câmera, na forma de `alfa_por_profundidade`.
func _baloes_com_profundidade(camera: Camera3D) -> Array:
	var saida: Array = []
	for balao: Node in get_tree().get_nodes_in_group(PopupsDoMundo.GRUPO_BALOES):
		if not balao.has_method("retangulo"):
			continue
		var caixa: Rect2 = balao.call("retangulo")
		var quem = balao.get("alvo")
		if caixa.size == Vector2.ZERO or not quem is Node3D:
			continue
		saida.append({"no": quem, "caixa": caixa, "distancia": camera.global_position.distance_to((quem as Node3D).global_position)})
	return saida


## A altura de `no` (o jogador ou um morador) como a placa a mede, para quem põe um popup acima da cabeça
## (o selo de fala do viajante, #225).
func altura_do(no: Node3D) -> float:
	return _altura_real(no)


## As caixas das CABEÇAS de quem está à vista (os moradores e o jogador), menos a de `ignorar`: o que um popup
## acima da cabeça de outro não pode cobrir.
func cabecas_a_vista(camera: Camera3D, ignorar: Node3D = null) -> Array[Rect2]:
	var saida: Array[Rect2] = []
	for caixa: Dictionary in _caixas_dos_personagens(camera):
		if caixa["no"] != ignorar:
			saida.append(caixa["cabeca"])
	return saida


## A altura do personagem para o rosto e a placa: a do dado (`altura` no morador,
## `character_height` no jogador) ou, se o modelo passa dela (chapéu, cabelo), a malha mais alta,
## até `EXCESSO_DO_MODELO`. Medida de tempos em tempos, e não a cada quadro.
func _altura_real(no: Node3D) -> float:
	# O morador diz `altura`, o jogador `character_height`; quem não diz nenhum (um boneco de portão) fica
	# na altura de gente comum, em vez de quebrar o quadro.
	var bruto: Variant = no.get("altura")
	if bruto == null:
		bruto = no.get("character_height")
	var dado := float(bruto) if bruto != null else ALTURA_DE_QUEM_NAO_DIZ
	var agora := Time.get_ticks_msec() / 1000.0
	var medida: Dictionary = _medidas.get(no, {})
	if medida.is_empty() or agora >= float(medida["ate"]):
		var topo := dado
		var visual = no.get("visual")
		if visual is Node3D:
			var maior := _topo_das_malhas(visual as Node3D)
			if is_finite(maior):
				topo = clampf(maior - no.global_position.y, dado, dado * EXCESSO_DO_MODELO)
		medida = {"topo": topo, "ate": agora + INTERVALO_DA_MEDIDA + float(no.get_instance_id() % 10) * 0.1}
		_medidas[no] = medida
	return float(medida["topo"])


## O ponto mais alto (y global) das malhas visíveis sob `no`; -INF sem nenhuma.
static func _topo_das_malhas(no: Node) -> float:
	var maior := -INF
	if no is MeshInstance3D and (no as MeshInstance3D).mesh != null and (no as MeshInstance3D).is_visible_in_tree():
		var malha := no as MeshInstance3D
		maior = (malha.global_transform * malha.get_aabb()).end.y
	for filho in no.get_children():
		maior = maxf(maior, _topo_das_malhas(filho))
	return maior


## Cabeça e torso: pessoa parcialmente visível mantém nome; três amostras cobertas
## o escondem. Áreas de interação, corpos dos moradores e folhagem marcada não são
## paredes. A consulta é espaçada e exige estabilidade nas bordas dos obstáculos.
func _visivel_para_camera(morador: Node3D, camera: Camera3D) -> bool:
	var agora := Time.get_ticks_msec() / 1000.0
	var estado: Dictionary = _oclusao.get(morador, {})
	if not estado.is_empty() and agora < float(estado["proxima"]):
		return bool(estado["visivel"])
	var altura := float(morador.get("altura"))
	var lado := camera.global_basis.x * 0.22
	var base := morador.global_position
	var pontos: Array[Vector3] = [base + Vector3.UP * altura * 0.9,
		base + Vector3.UP * altura * 0.55 - lado,
		base + Vector3.UP * altura * 0.55 + lado]
	var excluir: Array[RID] = []
	if _jogador is CollisionObject3D:
		excluir.append((_jogador as CollisionObject3D).get_rid())
	for outro in _placas.keys():
		if is_instance_valid(outro) and outro is CollisionObject3D:
			excluir.append((outro as CollisionObject3D).get_rid())
	var visivel := false
	for ponto in pontos:
		if _raio_livre(camera, ponto, excluir):
			visivel = true
			break
	if estado.is_empty():
		estado = {"visivel": visivel, "candidato": visivel, "desde": agora}
	elif bool(estado["candidato"]) != visivel:
		estado["candidato"] = visivel
		estado["desde"] = agora
	elif agora - float(estado["desde"]) >= ESTABILIZAR_OCLUSAO:
		estado["visivel"] = visivel
	estado["proxima"] = agora + INTERVALO_OCLUSAO
	_oclusao[morador] = estado
	return bool(estado["visivel"])


func _raio_livre(camera: Camera3D, ponto: Vector3, ignorados: Array[RID]) -> bool:
	var excluir := ignorados.duplicate()
	for _tentativa in 8:
		var consulta := PhysicsRayQueryParameters3D.create(camera.global_position, ponto,
			Camadas.MUNDO_E_CAMERA, excluir)
		consulta.hit_from_inside = true
		var achou := camera.get_world_3d().direct_space_state.intersect_ray(consulta)
		if achou.is_empty():
			return true
		var corpo = achou.get("collider")
		if corpo is Node and (corpo.is_in_group("folhagem") or bool(corpo.get_meta("nao_oculta_nomes", false))):
			excluir.append(achou["rid"])
			continue
		return false
	return false


## A COLUNA DA DICA DE QUEM VAI RECEBER O E: do alto da placa dele para cima, na altura e na largura da
## dica (a de agora, se está acesa, ou uma de tamanho comum). A placa de quem está atrás dele na mesma linha
## da câmera cede a essa coluna, em vez de empilhar a dica sobre duas placas e levá-la para longe do dono.
## Vazia sem dono do E.
func _coluna_da_dica(camera: Camera3D, dono: Node3D, dicas: Array[Rect2]) -> Rect2:
	if dono == null or not _placas.has(dono):
		return Rect2()
	var topo := dono.global_position + Vector3(0, _altura_real(dono) + ACIMA_DA_CABECA, 0)
	if camera.is_position_behind(topo):
		return Rect2()
	var ancora := camera.unproject_position(topo) - Vector2(0.0, float(_subida.get(dono, 0.0)))
	var placa := (_placas[dono] as PanelContainer).get_combined_minimum_size()
	var dica := Vector2(96.0, 34.0)
	for acesa in dicas:
		if absf(acesa.get_center().x - ancora.x) < dica.x:
			dica = acesa.size
	var largura := maxf(placa.x, dica.x) + 12.0
	return Rect2(ancora.x - largura * 0.5, ancora.y - placa.y - 3.0 - dica.y - 4.0, largura, dica.y + 7.0)


## Quem vai receber o E agora: o morador que a dica do E dos moradores aponta.
func _dono_do_e() -> Node3D:
	for fonte in get_tree().get_nodes_in_group(FocoDoE.GRUPO):
		if fonte.has_method("perto") and fonte.has_method("escolher_entre"):
			return fonte.call("perto") as Node3D
	return null


## O morador que a missão acompanhada aponta: o mais perto do ponto da seta, a menos
## de `RAIO_DA_MISSAO` dele.
func _da_missao() -> Node3D:
	for seta in get_tree().get_nodes_in_group(PopupsDoMundo.GRUPO_SETA):
		if not seta.has_method("alvo_atual"):
			continue
		var alvo = seta.call("alvo_atual")
		if not alvo is Vector3:
			continue
		var melhor: Node3D = null
		var menor := RAIO_DA_MISSAO
		for morador: Node3D in _placas.keys():
			if not is_instance_valid(morador):
				continue
			var falta: Vector3 = morador.global_position - (alvo as Vector3)
			if absf(falta.y) > 3.5:
				continue
			falta.y = 0.0
			if falta.length() < menor:
				menor = falta.length()
				melhor = morador
		return melhor
	return null


## Apaga a placa NA HORA: o morador saiu de trás da câmera, ou o jogo não está em
## cena. Uma placa que ficasse parada no meio da tela, só apagando, estaria no lugar errado.
func _apagar_ja(morador: Node3D) -> void:
	_alfa[morador] = 0.0
	_vaga.erase(morador)
	var placa: PanelContainer = _placas[morador]
	placa.visible = false
	placa.modulate.a = 0.0


func _criar(camada: Control, nome: String) -> PanelContainer:
	var placa := PanelContainer.new()
	placa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Nome flutuante pertence ao mundo; qualquer painel do HUD deve cobri-lo.
	placa.z_index = -1
	placa.visible = false
	placa.add_to_group(PopupsDoMundo.GRUPO_PLACAS)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = FUNDO
	estilo.border_color = OURO
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(6)
	estilo.content_margin_left = 9
	estilo.content_margin_right = 9
	estilo.content_margin_top = 3
	estilo.content_margin_bottom = 3
	placa.add_theme_stylebox_override("panel", estilo)
	var rotulo := Label.new()
	rotulo.text = nome
	rotulo.add_theme_font_size_override("font_size", 14)
	rotulo.add_theme_color_override("font_color", NOME)
	placa.add_child(rotulo)
	camada.add_child(placa)
	return placa


## PLAQUINHA DE NOME É COISA DO MUNDO, e some com qualquer tela aberta.
##
## "Quando abro os MENUs, o nome do Pedro tá sobrescrevendo os MENUs."
##
## A razão é ordem de irmãos. As plaquinhas moram no mesmo Control do HUD que o
## almanaque e a barra de mão, e entram DEPOIS deles — filho mais novo desenha
## por cima. Dava para consertar mexendo na ordem, ou pondo o almanaque numa
## camada própria, e as duas coisas consertariam este caso e deixariam o
## seguinte de pé: qualquer tela nova que nasça dentro do HUD volta a ser
## coberta.
##
## O conserto de fundo é de SENTIDO, não de camada: nome flutuando acima da
## cabeça de um morador é anotação sobre o vale, e com uma tela aberta não há
## vale à vista. Então elas somem — de todas as telas, de uma vez.
##
## Some NA HORA, e não no próximo `_process`: as telas pausam a árvore, e nó
## pausável não recebe mais `_process`. Esperar o quadro seguinte seria esperar
## para sempre.
func permitir(mostrar: bool) -> void:
	_permitido = mostrar
	if not mostrar:
		_vaga.clear()
		for morador in _placas.keys():
			var placa: PanelContainer = _placas[morador]
			if is_instance_valid(placa):
				placa.visible = false
				placa.modulate.a = 0.0
			_alfa[morador] = 0.0
