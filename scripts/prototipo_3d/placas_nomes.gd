extends Node
## Plaquinhas com o nome de cada morador, na identidade do HUD (painel escuro, borda e
## nome dourados), presas acima da cabeça. Somem enquanto o morador fala (o balão já
## traz o nome), longe demais ou atrás da câmera, com o morador fora do vale (o mestre
## Quirino fora do dia do saveiro: o rótulo dele continua `visible`, quem some é ele) e
## quando AJUSTAR → Cenário → Nomes dos personagens está em Ocultar.
##
##
## NO MÁXIMO TRÊS DE CADA VEZ
##
## "Tem muitos popups de personagem, precisamos limitar essa quantidade para evitar
## poluir a tela." (playtest da Build 9B, 06/10/2026)
##
## A praça junta de seis a treze moradores ao longo do dia, e todos estavam a menos
## de 22 m: até treze plaquinhas de uma vez, mais a dica do E, o balão e a seta.
## Agora só `MAXIMO_DE_PLACAS` aparecem (duas, com um balão no ar: o balão e o
## nome de quem fala já são dois popups de personagem), e quem leva uma é, nesta ordem:
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
## Morador -> a mola da placa dele, e o quanto ela está acesa (0 a 1).
var _molas: Dictionary = {}
var _alfa: Dictionary = {}
## Quem ganhou a vaga no quadro passado.
var _vaga: Dictionary = {}
var _oclusao: Dictionary = {}


func _init() -> void:
	# Antes de tudo: as dicas do E e o balão leem o retângulo fresco das placas
	# (`popups_do_mundo.gd`).
	process_priority = -20


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
	var limite := maximo - (1 if not baloes.is_empty() else 0)
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
			continue
		var topo := morador.global_position + Vector3(0, float(morador.get("altura")) + ACIMA_DA_CABECA, 0)
		if not liberado or camera.is_position_behind(topo):
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
		var tamanho: Vector2 = (_placas[morador] as PanelContainer).get_combined_minimum_size()
		var caixa := Rect2(ancora - Vector2(tamanho.x * 0.5, tamanho.y), tamanho)
		# A placa inteira na tela: cortada pela borda, ou meio sob o HUD, não é placa. (Com histerese: quem
		# já tem a placa aguenta mais.)
		var tinha := _vaga.has(morador)
		if _concorre_com_arvore(caixa, dicas_arvore, tinha):
			continue
		var tolerancia := SOBREPOSTA_PARA_SAIR if tinha else SOBREPOSTA_PARA_ENTRAR
		var area_util := util.grow(MARGEM_DE_QUEM_JA_TEM) if tinha else util
		if not area_util.encloses(caixa) or _encosta_em_algum(caixa, paineis, tolerancia) or _encosta_em_algum(caixa, baloes, tolerancia):
			continue
		# A DICA DO E É DE QUEM VAI RECEBER O E, e sobe por cima da placa dele: a placa dos outros que ficaria
		# sob a dica (alguém atrás dele na mesma linha da câmera) cede, em vez de empurrar a dica para longe
		# do dono dela.
		if morador != dono_do_e and (_encosta_em_algum(caixa, dicas, tolerancia) or _encosta_em_algum(caixa, colunas, tolerancia)):
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
		})
	var vencedores := {}
	for indice in escolher(candidatos, limite):
		vencedores[candidatos[indice]["no"]] = true
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
		if alfa <= 0.0:
			if quer <= 0.0:
				continue
			# A VAGA É DE OUTRO ATÉ ELE APAGAR: nunca mais de `maximo` ligadas, nem na troca.
			if ligadas >= maximo:
				continue
			ligadas += 1
			mola.reiniciar(ancoras[morador])
		alfa = move_toward(alfa, quer, maxf(delta, 1.0 / 60.0) / SEGUNDOS_DO_FADE)
		_alfa[morador] = alfa
		placa.modulate.a = alfa * float(perto.get(morador, 1.0))
		placa.visible = alfa > 0.0
		if placa.visible:
			placa.reset_size()
			var onde := mola.seguir(ancoras[morador], delta, TEMPO_DE_SEGUIR,
				SuavizadorDeTela.VELOCIDADE_MAXIMA, SuavizadorDeTela.ZONA_MORTA, CORREIA)
			placa.position = (onde - Vector2(placa.size.x * 0.5, placa.size.y)).round()


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
	var topo := dono.global_position + Vector3(0, float(dono.get("altura")) + ACIMA_DA_CABECA, 0)
	if camera.is_position_behind(topo):
		return Rect2()
	var ancora := camera.unproject_position(topo)
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
