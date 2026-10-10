extends "res://tests/suite/caso.gd"
## Confere que A COLISÃO DA FACHADA SEGUE A MALHA NO ALPENDRE (#205): o pilar solto da parede é sólido, e o chão
## entre ele e a parede fica livre; o balcão colado na parede e o fundo do vão da porta seguem cheios.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste fachada_do_alpendre
##
## "A saída de viés do restaurante prende no pilar do alpendre": a colisão da fachada (`comodo.gd`,
## `_montar_a_fachada_de_fora`) enchia da parede até a face da frente de cada coluna medida, e o pilar de um
## alpendre virava um muro de ar até a parede, rente à porta. A medida agora traz também a face de trás de
## cada saliência (`interiores.gd`, `_coluna_da_fachada`) e o cômodo só põe caixa onde há sólido.
##
## O portão monta um cômodo sozinho, com um perfil de fachada escrito à mão (coluna a coluna, a cada 5 cm):
##
##   1. UM PILAR SOLTO (face de trás a 0,5 m da parede, da frente a 1,3 m): o meio do vão entre ele e a parede é
##      livre, e o pilar é sólido.
##   2. UM BALCÃO COLADO (da parede à frente, sem vão): é sólido da parede até a frente.
##   3. A PAREDE LISA ao lado do pilar não vira parede até ele, e o fundo do vão da porta não ganha caixa.
##
## FALSIFICAÇÃO: `-- --falsificar=cheio` mede o pilar como antes (da parede à frente) e o portão TEM de achar o
## vão fechado. A variável `MV_FALSIFICAR` faz o mesmo.

## Carregado em `_run`, e não com preload: `comodo.gd` usa o autoload `Estilo`, que ainda não existe quando o
## portão compila.
var Comodo

## A espessura da parede do cômodo no portão, e onde estão a parede lisa e as saliências, no cômodo (z para fora).
const PAREDE := 0.4
const FACE_DA_PAREDE := 0.45
const PILAR_DE_X := 1.2
const PILAR_ATE_X := 1.4
const PILAR_TRAS := 0.95
const PILAR_FRENTE := 1.7
const BALCAO_DE_X := -1.6
const BALCAO_ATE_X := -1.4
const BALCAO_FRENTE := 0.95

var falhas := 0
var sala: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("FACHADA_DO_ALPENDRE_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _pedido_de_falsificacao() -> String:
	var pedido := OS.get_environment("MV_FALSIFICAR")
	for argumento in OS.get_cmdline_user_args():
		if str(argumento).begins_with("--falsificar="):
			pedido = str(argumento).trim_prefix("--falsificar=")
	return pedido


func _run() -> void:
	var cheio := _pedido_de_falsificacao() == "cheio"
	if cheio:
		print("  FALSIFICAÇÃO: o pilar é medido como antes, da parede à frente: o portão TEM de achar o vão fechado")
	Comodo = load("res://scripts/prototipo_3d/comodo.gd")
	sala = Comodo.new()
	var perfil: Array[Vector3] = []
	var x := -2.7
	while x <= 2.7:
		var coluna := Vector3(x, FACE_DA_PAREDE, 0.0)
		if x >= PILAR_DE_X - 0.001 and x <= PILAR_ATE_X + 0.001:
			coluna = Vector3(x, PILAR_FRENTE, 0.0 if cheio else PILAR_TRAS)
		elif x >= BALCAO_DE_X - 0.001 and x <= BALCAO_ATE_X + 0.001:
			coluna = Vector3(x, BALCAO_FRENTE, 0.0)
		perfil.append(coluna)
		x += Comodo.PASSO_DA_FACHADA
	sala.configurar({
		"parede": PAREDE, "largura": 4.6, "comprimento": 7.8, "pe_direito": 3.0,
		"porta_x": 0.0, "largura_da_porta": 1.2, "altura_da_porta": 2.2, "fundo_da_porta": 0.3,
		"perfil_da_fachada": perfil,
	})
	root.add_child(sala)
	await process_frame
	await process_frame
	var caixas := _caixas_da_fachada()
	print("  %d caixa(s) de fachada de fora" % caixas.size())
	_conferir(caixas.size() >= 2, "a fachada de fora não ganhou caixa nenhuma: o pilar e o balcão ficaram sem colisão")
	# 1. O PILAR SOLTO.
	var meio_do_pilar := (PILAR_DE_X + PILAR_ATE_X) * 0.5
	_conferir(_dentro(caixas, Vector3(meio_do_pilar, 1.0, (PILAR_TRAS + PILAR_FRENTE) * 0.5)), "o pilar solto não tem colisão")
	_conferir(not _dentro(caixas, Vector3(meio_do_pilar, 1.0, (FACE_DA_PAREDE + PILAR_TRAS) * 0.5)),
		"o vão entre o pilar do alpendre e a parede está fechado por colisão: muro de ar, e quem sai da porta de viés prende nele")
	# 2. O BALCÃO COLADO.
	var meio_do_balcao := (BALCAO_DE_X + BALCAO_ATE_X) * 0.5
	_conferir(_dentro(caixas, Vector3(meio_do_balcao, 1.0, (FACE_DA_PAREDE + BALCAO_FRENTE) * 0.5)), "o balcão colado na parede não tem colisão da parede à frente")
	_conferir(_dentro(caixas, Vector3(meio_do_balcao, 1.0, PAREDE + 0.02)), "o balcão colado deixa um vão atrás dele, junto da parede")
	# 3. A PAREDE LISA, E O VÃO DA PORTA.
	_conferir(not _dentro(caixas, Vector3(0.9, 1.0, (FACE_DA_PAREDE + PILAR_TRAS) * 0.5 + 0.1)), "a parede lisa ao lado do pilar virou parede de colisão até ele")
	_conferir(not _dentro(caixas, Vector3(0.0, 1.0, PAREDE + 0.2)), "o fundo do vão da porta ganhou caixa de fachada")
	_fechar()


## As caixas de fachada de fora: o centro e o tamanho de cada uma, no cômodo.
func _caixas_da_fachada() -> Array[AABB]:
	var caixas: Array[AABB] = []
	for no in sala.get_children():
		if not str(no.name).begins_with("FachadaFora_"):
			continue
		for corpo in no.get_children():
			for forma in corpo.get_children():
				var colisao := forma as CollisionShape3D
				if colisao == null or not (colisao.shape is BoxShape3D):
					continue
				var tamanho: Vector3 = (colisao.shape as BoxShape3D).size
				var centro: Vector3 = (no as Node3D).position
				caixas.append(AABB(centro - tamanho * 0.5, tamanho))
	return caixas


func _dentro(caixas: Array[AABB], ponto: Vector3) -> bool:
	for caixa in caixas:
		if caixa.has_point(ponto):
			return true
	return false


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("FACHADA_DO_ALPENDRE_OK: o pilar solto da parede é sólido e o vão entre ele e a parede é livre; o balcão colado e a parede lisa seguem como eram, e o fundo do vão da porta não ganha caixa")
	else:
		print("fachada_do_alpendre: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)
