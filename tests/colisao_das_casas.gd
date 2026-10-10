extends "res://tests/suite/caso.gd"
## Confere que A COLISÃO DE TODA CASA ACOMPANHA A PAREDE VISÍVEL (#205): o viajante para
## encostado, e nunca com o ombro dentro do reboco.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste colisao_das_casas
##
## "Na casa da Dona Zefa o viajante aparece entrando na parede: metade do corpo atravessa a quina
## da fachada, ao lado da porta." Duas causas, as duas na colisão que o cômodo põe no lugar da caixa
## inteira da construção (`interiores.gd`, `comodo.gd`): a parede acaba um palmo para dentro da face
## de dentro da casca e a parede do modelo tem a espessura dela; e, ao lado da porta, a fachada só
## tinha o batente de 20 cm sólido: o resto do fundo do vão era vazio. Agora a casca de fora
## (`Comodo._montar_a_casca_de_fora`) cobre o que falta até a face de fora medida.
##
## Para cada cômodo montado, de cada construção com modelo (`world.construcoes`), a malha visível do
## modelo vai para uma camada só dela (`auditoria_de_geometria.gd`) e raios entram por fora, em duas
## alturas de peito: nas laterais, no fundo e na fachada — de cada lado do vão da porta, as ombreiras
## inclusas. Cada raio mede quanto a primeira colisão do cômodo está DENTRO da face visível:
##
##   1. NINGUÉM ENTRA NA PAREDE: a fachada ao lado da porta não passa de `FUNDURA_NA_FACHADA` e a
##      mediana de cada parede não passa de `FUNDURA_MEDIANA`; nenhum ponto passa de `FUNDURA_MAXIMA`
##      (pilar, quina e beiral que saem num ponto só ficam sob essa).
##   2. NÃO HÁ PAREDE DE AR: a colisão não está mais de `AR_MAXIMO` fora da face visível.
##   3. NÃO HÁ BURACO: nenhum raio passa pela construção inteira sem achar colisão.
##   4. O DETECTOR DE "DENTRO DE GEOMETRIA" (o do testador automático) acha um ponto no meio da
##      parede de uma casa, e não acha um ponto a dois metros dela.
##
## FALSIFICAÇÃO: `-- --falsificar=sem_casca_de_fora` tira do primeiro cômodo as caixas da casca de
## fora (sai como era antes da correção) e o portão TEM de reprovar na fachada ao lado da porta.
## A variável `MV_FALSIFICAR` faz o mesmo.

const Auditoria = preload("res://scripts/prototipo_3d/auditoria_de_geometria.gd")

## Quanto a colisão pode estar dentro da parede visível, em metros: no ponto, na mediana da parede,
## e na fachada ao lado da porta (onde o corpo entrava).
const FUNDURA_MAXIMA := 0.35
const FUNDURA_MEDIANA := 0.15
const FUNDURA_NA_FACHADA := 0.25
## Quanto a colisão pode estar fora da parede visível (parede de ar), em metros.
const AR_MAXIMO := 0.45
## As alturas de peito, a partir do piso do cômodo.
const ALTURAS := [0.7, 1.3]

var falhas := 0
var vale
var interiores
var mundo
var falsificar := ""
var _construcoes_medidas := 0
var _detectou := false


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("COLISAO_DAS_CASAS_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _pedido_de_falsificacao() -> String:
	var pedido := OS.get_environment("MV_FALSIFICAR")
	for argumento in OS.get_cmdline_user_args():
		if str(argumento).begins_with("--falsificar="):
			pedido = str(argumento).trim_prefix("--falsificar=")
	return pedido


func _run() -> void:
	falsificar = _pedido_de_falsificacao()
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(8)
	await _carga_pronta()
	vale = current_scene
	interiores = vale.get("interiores")
	mundo = vale.get("world")
	_conferir(interiores != null and mundo != null, "o vale não montou as construções por dentro")
	if interiores == null or mundo == null:
		_fechar()
		return
	root.get_node("/root/Dia").pausado = true
	if falsificar != "":
		print("  FALSIFICAÇÃO: %s" % falsificar)
	await interiores.garantir_todas()
	var vistos: Array = interiores.quais()
	vistos.sort()
	var primeira := true
	for qual in vistos:
		await _auditar(str(qual), primeira and falsificar == "sem_casca_de_fora")
		primeira = false
	_conferir(_construcoes_medidas >= 15, "só %d construções com modelo e cômodo foram medidas: a auditoria não prova nada" % _construcoes_medidas)
	_conferir(_detectou, "o detector de 'dentro de geometria' não achou ponto nenhum no meio de uma parede")
	_fechar()


func _auditar(qual: String, sem_a_casca_de_fora: bool) -> void:
	var sala: Node3D = interiores.sala_de(qual)
	var ancora := str(interiores._ancora_de(qual, interiores._tabela[qual]))
	var lote: Dictionary = mundo.construcoes.get(ancora, {})
	var modelo = lote.get("modelo")
	if sala == null or not (modelo is Node3D) or not is_instance_valid(modelo):
		return
	if sem_a_casca_de_fora:
		for no in sala.get_children():
			var nome := str(no.name)
			if nome.begins_with("ParedeFora_") or nome.begins_with("FundosFora_") or nome.begins_with("FachadaFora_"):
				no.queue_free()
		await _frames(2)
		await physics_frame
	var corpo: StaticBody3D = Auditoria.corpo_da_casca(mundo, modelo)
	await physics_frame
	await physics_frame
	var espaco: PhysicsDirectSpaceState3D = mundo.get_world_3d().direct_space_state
	var laterais: Array[float] = []
	var fundos: Array[float] = []
	var fachada: Array[float] = []
	var buracos := 0
	var x := sala.global_basis.x.normalized()
	var z := sala.global_basis.z.normalized()
	var meia_largura: float = sala.largura * 0.5 + sala.parede
	# As laterais, e o fundo.
	for h in ALTURAS:
		for fracao in [0.15, 0.4, 0.65, 0.9]:
			for sinal in [1.0, -1.0]:
				var ponto: Vector3 = sala.to_global(Vector3(0.0, float(h), -sala.comprimento * float(fracao)))
				buracos += _medir(espaco, sala, ponto, x * sinal, laterais)
		for fracao in [-0.35, -0.1, 0.2, 0.4]:
			var ponto: Vector3 = sala.to_global(Vector3(sala.largura * float(fracao), float(h), -sala.comprimento * 0.5))
			buracos += _medir(espaco, sala, ponto, -z, fundos)
	# A fachada, de cada lado do vão da porta e até a quina. O corpo tem altura: a coluna vale o
	# que a face mais saliente das duas alturas pede (um balcão só na altura do joelho, ou uma
	# viga só na do peito, é obstáculo do mesmo jeito), e não cada altura sozinha.
	for lado in [-1.0, 1.0]:
		var colunas: Array[float] = []
		for recuo in [0.3, 0.6, 1.0]:
			var xl: float = sala.porta_x + lado * (sala.largura_da_porta * 0.5 + float(recuo))
			if absf(xl) < meia_largura - 0.05:
				colunas.append(xl)
		colunas.append(lado * (meia_largura - 0.1))
		for xl in colunas:
			buracos += _medir_coluna(espaco, sala, xl, z, fachada)
	_detectar(espaco, sala, corpo)
	corpo.queue_free()
	_construcoes_medidas += 1
	var todas: Array[float] = []
	todas.append_array(laterais)
	todas.append_array(fundos)
	todas.append_array(fachada)
	var pior := _maior(todas)
	var pior_fachada := _maior(fachada)
	var mediana_lateral := _mediana(laterais)
	var mediana_fundo := _mediana(fundos)
	print("  casca    %-14s laterais %+.2f  fundo %+.2f  fachada %+.2f (pior %+.2f)  buracos %d" % [qual, mediana_lateral, mediana_fundo, _mediana(fachada), pior, buracos])
	_conferir(buracos == 0, "%s: %d raio(s) passaram pela construção sem achar colisão: a parede visível não barra" % [qual, buracos])
	_conferir(pior_fachada <= FUNDURA_NA_FACHADA,
		"%s: ao lado da porta a colisão está %.2f m dentro da fachada visível (máximo %.2f): o corpo entra na parede" % [qual, pior_fachada, FUNDURA_NA_FACHADA])
	_conferir(pior <= FUNDURA_MAXIMA,
		"%s: um ponto da parede tem a colisão %.2f m dentro da face visível (máximo %.2f)" % [qual, pior, FUNDURA_MAXIMA])
	_conferir(mediana_lateral <= FUNDURA_MEDIANA and mediana_fundo <= FUNDURA_MEDIANA,
		"%s: a colisão das paredes está dentro da face visível em %.2f (laterais) e %.2f (fundo); máximo %.2f" % [qual, mediana_lateral, mediana_fundo, FUNDURA_MEDIANA])
	_conferir(_menor(todas) >= -AR_MAXIMO,
		"%s: a colisão está %.2f m fora da parede visível (máximo %.2f): parede de ar" % [qual, -_menor(todas), AR_MAXIMO])


## Um raio por fora até o ponto: a fundura da colisão na face visível, anexada a `lista`. Devolve 1 se
## o raio não achou colisão da construção (um buraco), e 0 se achou ou se nem achou casca.
func _medir(espaco: PhysicsDirectSpaceState3D, sala: Node3D, ponto: Vector3, para_fora: Vector3, lista: Array[float]) -> int:
	var face := Auditoria.face_visivel(espaco, ponto + para_fora * 30.0, ponto)
	if not face.is_finite():
		return 0
	var fundura := Auditoria.fundura_da_colisao(espaco, face, -para_fora.normalized(), sala)
	if not is_finite(fundura):
		return 1
	lista.append(fundura)
	return 0


## O mesmo, para uma coluna da fachada (`xl` no cômodo): a fundura que vale é a da face mais
## saliente das alturas (positivo: o corpo que encosta já está dentro do reboco; negativo: a
## colisão está mais fora do que qualquer parte visível da coluna, parede de ar). Devolve 1 se um
## raio achou a casca e a coluna não tem colisão (um buraco).
func _medir_coluna(espaco: PhysicsDirectSpaceState3D, sala: Node3D, xl: float, z: Vector3, lista: Array[float]) -> int:
	var pior := -INF
	for h in ALTURAS:
		var ponto: Vector3 = sala.to_global(Vector3(xl, float(h), 0.0))
		var face := Auditoria.face_visivel(espaco, ponto + z * 30.0, ponto)
		if not face.is_finite():
			continue
		var fundura := Auditoria.fundura_da_colisao(espaco, face, -z.normalized(), sala)
		if not is_finite(fundura):
			return 1
		pior = maxf(pior, fundura)
	if is_finite(pior):
		lista.append(pior)
	return 0


## A pergunta 4: o ponto no meio da parede lateral, entre a face de dentro e a de fora, está
## "dentro da malha"; um ponto a dois metros da parede, não.
func _detectar(espaco: PhysicsDirectSpaceState3D, sala: Node3D, _corpo: StaticBody3D) -> void:
	var x := sala.global_basis.x.normalized()
	var meio: Vector3 = sala.to_global(Vector3(0.0, 1.0, -sala.comprimento * 0.5))
	var de_dentro := Auditoria.face_visivel(espaco, meio, meio + x * 30.0)
	var de_fora := Auditoria.face_visivel(espaco, meio + x * 30.0, meio)
	if not de_dentro.is_finite() or not de_fora.is_finite():
		return
	var na_parede := (de_dentro + de_fora) * 0.5
	if de_dentro.distance_to(de_fora) < 0.06:
		return
	if Auditoria.dentro_da_malha(espaco, na_parede):
		_detectou = true
	_conferir(not Auditoria.dentro_da_malha(espaco, de_fora + x * 2.0),
		"o detector achou 'dentro de geometria' num ponto a 2 m da parede, no ar")


static func _maior(lista: Array[float]) -> float:
	var m := -INF
	for v in lista:
		m = maxf(m, v)
	return m if is_finite(m) else 0.0


static func _menor(lista: Array[float]) -> float:
	var m := INF
	for v in lista:
		m = minf(m, v)
	return m if is_finite(m) else 0.0


static func _mediana(lista: Array[float]) -> float:
	if lista.is_empty():
		return 0.0
	var ordem := lista.duplicate()
	ordem.sort()
	return float(ordem[int(ordem.size() / 2.0)])


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("COLISAO_DAS_CASAS_OK: em %d construções a colisão do cômodo acompanha a parede visível — a fachada ao lado da porta, as laterais e o fundo —, sem parede de ar nem buraco, e o detector de 'dentro de geometria' acha o ponto no meio da parede" % _construcoes_medidas)
	else:
		print("colisao_das_casas: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _frames(count: int) -> void:
	for frame in range(count):
		await process_frame


func _carga_pronta() -> void:
	for i in range(3000):
		if current_scene != null and current_scene.get("carga_ok") == true:
			break
		await process_frame
	await process_frame


func _mundo_pronto() -> void:
	for i in range(3000):
		var no_mundo := get_first_node_in_group("mundo")
		if no_mundo != null and no_mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
