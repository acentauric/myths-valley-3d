extends "res://tests/unidade/base.gd"
## O BALÃO DO CANTO FICA ABAIXO DA FAIXA DE CINEMA, E DESLIZA ATÉ LÁ (#246).
##
##     .\tools\prototipo_3d\testar.ps1 -Teste balao_abaixo_da_tarja
##
## Na cena da chegada (o Pedro apresentando o Tonho no píer) entram as tarjas pretas de cinema, e o balão da fala,
## preso no canto de cima, ficava sob a de cima: a primeira linha saía cortada. O HUD recolhido devolvia y = 18, e a
## tarja cobre 11% da altura do viewport (79 px do canvas de 1280×720; na janela de 1080p são os mesmos 79, esticados
## em 119 px de tela). Três perguntas, sem o vale:
##
##   1. O CANTO CONTA A TARJA: com uma cena que a pede, `canto_da_fala` nunca passa de `tarja + margem` — com o
##      quadro da missão recolhido (o que a cena faz) e também com ele à vista.
##   2. SEM CENA, NADA MUDA: sem tarja o canto é o de sempre (18 de margem; abaixo do quadro da missão).
##   3. O BALÃO DESLIZA: quando o canto muda de uma vez (a tarja que desce, o quadro que volta no fim da cena), a caixa
##      vai ao canto novo em quadros, sem salto, e assenta nele; a fala que nasce vai direto ao canto.
##
## O vale inteiro, com a cena de verdade, é o caso `cena_so_com_balao` (pergunta 6).

const TARJA := 0.11
const MARGEM := 18.0

var _janela_de_antes := Vector2i.ZERO


## Uma cena que só sabe dizer quantos pixels da janela a tarja cobre.
class CenaFalsa:
	extends Node
	var tarja := 0.0

	func altura_da_tarja() -> float:
		return tarja


## Um HUD que só sabe dizer onde é o canto da fala.
class HudFalso:
	extends Node
	var canto := Rect2(18.0, 126.0, 360.0, 0.0)

	func canto_da_fala() -> Rect2:
		return canto


func before_each() -> void:
	super()
	_janela_de_antes = root.size


func after_each() -> void:
	root.size = _janela_de_antes


func test_o_canto_conta_a_tarja_com_o_hud_recolhido_e_a_vista() -> void:
	for tamanho: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = tamanho
		var hud: Node = load("res://scripts/prototipo_3d/prototype_hud.gd").new()
		pendurar(hud)
		await process_frame
		hud.set_objective("Siga o Pedro até a Dona Candinha", "Quem guardou a chave")
		await process_frame
		var rotulo := "janela %dx%d" % [tamanho.x, tamanho.y]

		# --- 2. SEM CENA, NADA MUDA ------------------------------------------------------------------
		var quadro: Rect2 = hud._retangulo_em_tela(hud._heading)
		var sem_cena: Rect2 = hud.canto_da_fala()
		_conferir(is_equal_approx(sem_cena.position.y, quadro.end.y + hud.FOLGA_DA_COLUNA),
			"%s: sem cena o canto devia ficar %.0f abaixo do quadro da missão (y=%.1f, o quadro termina em %.1f)" % [rotulo, hud.FOLGA_DA_COLUNA, sem_cena.position.y, quadro.end.y])
		hud._root.visible = false
		_conferir(is_equal_approx(hud.canto_da_fala().position.y, MARGEM),
			"%s: com o HUD recolhido e sem cena o canto devia ficar na margem de %.0f (y=%.1f)" % [rotulo, MARGEM, hud.canto_da_fala().position.y])
		hud._root.visible = true

		# --- 1. O CANTO CONTA A TARJA -----------------------------------------------------------------
		# O canvas é esticado (`stretch/mode = canvas_items`, base 1280×720): a tarja e o HUD moram no espaço lógico do viewport.
		var alta := TARJA * root.get_visible_rect().size.y
		var cena := CenaFalsa.new()
		cena.tarja = alta
		cena.add_to_group("cenas_do_vale")
		pendurar(cena)
		hud._root.visible = false
		var recolhido: Rect2 = hud.canto_da_fala()
		_conferir(recolhido.position.y >= alta + MARGEM - 0.01,
			"%s: o quadro da missão recolhido, o canto fica em y=%.1f, dentro da tarja de %.1f px (o topo devia ser %.1f)" % [rotulo, recolhido.position.y, alta, alta + MARGEM])
		_conferir(is_equal_approx(recolhido.position.x, MARGEM), "%s: a tarja moveu o canto de lado (x=%.1f)" % [rotulo, recolhido.position.x])
		hud._root.visible = true
		# Com o quadro à vista o canto já está abaixo dele; a tarja só empurra quando passa dele.
		var a_vista: Rect2 = hud.canto_da_fala()
		_conferir(a_vista.position.y >= maxf(quadro.end.y + hud.FOLGA_DA_COLUNA, alta + MARGEM) - 0.01,
			"%s: com o quadro à vista o canto (y=%.1f) devia passar do quadro (%.1f) e da tarja (%.1f)" % [rotulo, a_vista.position.y, quadro.end.y + hud.FOLGA_DA_COLUNA, alta + MARGEM])
		cena.tarja = 400.0
		_conferir(hud.canto_da_fala().position.y >= 400.0 + MARGEM - 0.01,
			"%s: com uma tarja bem alta (400 px) o canto com o quadro à vista não a acompanhou (y=%.1f)" % [rotulo, hud.canto_da_fala().position.y])
		cena.tarja = 0.0
		_conferir(is_equal_approx(hud.canto_da_fala().position.y, sem_cena.position.y),
			"%s: acabada a cena o canto não voltou ao de antes (y=%.1f, era %.1f)" % [rotulo, hud.canto_da_fala().position.y, sem_cena.position.y])
		cena.queue_free()
		hud.queue_free()
		await process_frame


## Um balão de verdade, numa câmera, com o canto que o teste manda. Devolve {balao, hud}.
func _balao_no_canto(canto: Rect2) -> Dictionary:
	var Balao: GDScript = load("res://scripts/prototipo_3d/balao_fala.gd")
	var camera := Camera3D.new()
	pendurar(camera)
	camera.make_current()
	var falante := Node3D.new()
	pendurar(falante)
	falante.global_position = Vector3(0.0, 0.0, -5.0)
	var hud := HudFalso.new()
	hud.canto = canto
	hud.add_to_group("hud_do_vale")
	pendurar(hud)
	var camada := CanvasLayer.new()
	camada.layer = 10
	pendurar(camada)
	var balao: Control = Balao.new()
	camada.add_child(balao)
	balao.configurar(falante, 1.8, "Pedro")
	return {"balao": balao, "hud": hud}


## Roda `quadros` passos de 1/60 s do balão e devolve {maior_passo, y_final}: o maior pulo de y de um quadro ao
## seguinte, e onde ele parou.
func _andar(balao: Control, quadros: int) -> Dictionary:
	var antes: float = balao._painel.position.y
	var maior := 0.0
	for i in quadros:
		balao._posicionar(1.0 / 60.0)
		var agora: float = balao._painel.position.y
		maior = maxf(maior, absf(agora - antes))
		antes = agora
	return {"maior_passo": maior, "y_final": antes}


func test_o_balao_desliza_ate_o_canto_novo() -> void:
	var SuavizadorDeTela: GDScript = load("res://scripts/prototipo_3d/suavizador_de_tela.gd")
	var montado := _balao_no_canto(Rect2(18.0, 126.0, 360.0, 0.0))
	var balao: Control = montado["balao"]
	var hud: HudFalso = montado["hud"]
	balao.mostrar("Aquele de linha na mão desde a madrugada é o Tonho, pescador como eu.")
	await process_frame
	_conferir(balao.a_vista(), "o balão do canto não apareceu com a câmera a cinco passos de quem fala")
	if not balao.a_vista():
		return

	# A FALA QUE NASCE VAI DIRETO AO CANTO, e não desliza de onde a caixa estava (0, 0).
	_conferir(is_equal_approx(balao._painel.position.y, 126.0) and is_equal_approx(balao._painel.position.x, 18.0),
		"a fala nasceu em %s, e o canto é (18, 126)" % str(balao._painel.position))

	# A TARJA DESCE: o canto vai de uma vez para baixo da faixa, e o balão o segue deslizando.
	hud.canto = Rect2(18.0, 126.0 + 100.0, 360.0, 0.0)
	var descida := _andar(balao, 90)
	_conferir(float(descida["maior_passo"]) <= 12.0,
		"o canto novo (100 px abaixo) foi um salto de %.0f px num quadro, e devia deslizar" % float(descida["maior_passo"]))
	_conferir(absf(float(descida["y_final"]) - 226.0) <= 1.0,
		"1,5 s depois o balão ainda estava a %.0f px do canto novo" % absf(float(descida["y_final"]) - 226.0))

	# A CENA ACABA: o quadro da missão volta e o canto sobe, também devagar.
	hud.canto = Rect2(18.0, 126.0, 360.0, 0.0)
	var subida := _andar(balao, 90)
	_conferir(float(subida["maior_passo"]) <= 12.0,
		"a volta ao canto normal foi um salto de %.0f px num quadro, e devia deslizar" % float(subida["maior_passo"]))
	_conferir(absf(float(subida["y_final"]) - 126.0) <= 1.0,
		"1,5 s depois da cena o balão ainda estava a %.0f px do canto normal" % absf(float(subida["y_final"]) - 126.0))

	# O MEDIDOR ENXERGA O SALTO (a falsificação do teste): com a mola desligada a caixa segue o alvo cru, num quadro.
	SuavizadorDeTela.set("desligado", true)
	hud.canto = Rect2(18.0, 226.0, 360.0, 0.0)
	var seco := _andar(balao, 5)
	SuavizadorDeTela.set("desligado", false)
	_conferir(float(seco["maior_passo"]) >= 90.0,
		"sem a mola o balão devia saltar os 100 px de uma vez, e o medidor viu só %.0f px: o teste não distingue o salto" % float(seco["maior_passo"]))
