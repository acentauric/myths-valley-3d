extends SceneTree
## O BALÃO FICA SOBRE QUEM FALA, COM A PONTA PARA ELE (#224).
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/balao_sobre_quem_fala.gd
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/balao_sobre_quem_fala.gd -- --falsificar
##
## "O Pedro está no canto esquerdo da tela e o balão dele aparece no canto direito superior,
## longe dele, sem ligação visual." O lugar do balão saía de uma soma de multas em que cobrir
## uma dica valia mais que atravessar a tela. A escolha agora é uma conta pura
## (`BalaoFala.avaliar`), medida aqui sem cena nenhuma, numa tela de 1280x720:
##
##   1. FALANTE PERTO, no meio: o balão está acima da cabeça, com o pé a `FOLGA` dela, a cabeça
##      sob ele, e sem cobrir o rosto.
##   2. FALANTE LONGE (pequeno na tela): o mesmo.
##   3. NA BORDA: com a cabeça colada na borda esquerda e na direita, o balão cabe inteiro na tela,
##      perto dela, e sem cobrir o rosto.
##   4. FORA DA TELA: com a cabeça além da borda, o balão encosta na borda do lado dela.
##   5. SOB O HUD: o Pedro à esquerda, sob o bloco da missão, no caso da captura: o balão desliza
##      para fora do HUD, perto da cabeça, sem cobrir o rosto, e não vai para o outro lado da tela.
##   6. COM DICA E JOGADOR AO LADO: o balão não atravessa a tela por causa deles; fica a menos de
##      meia tela da cabeça e sem cobrir o rosto de nenhum dos dois.
##   7. EM PÁGINAS: a fala de duas linhas e a de três têm o pé no mesmo lugar (só o alto muda).
##   8. A ORDEM É FIXA: o número de lugares não depende do HUD (a permanência troca por índice).
##
## `--falsificar` entrega ao balão um HUD vazio e confere contra o HUD de verdade: o balão fica
## sobre o bloco da missão e o portão reprova.

## Carregado no _run, não por preload: no --script o preload compila antes de os autoloads (a Tela do balão)
## virarem nomes globais, e o portão não abria.
var BalaoFala: GDScript
const PopupsDoMundo = preload("res://scripts/prototipo_3d/popups_do_mundo.gd")

const TELA := Vector2(1280, 720)
const BALAO := Vector2(300, 110)
## Roçar de um ou dois pixels não é cobrir.
const TOLERANCIA_DE_PX2 := 16.0

var falhas := 0
var falsificar := false


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("BALAO_SOBRE_QUEM_FALA_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


## O corpo de quem fala na tela, com a cabeça no ponto `c` e `alto` de altura.
func _corpo(c: Vector2, alto: float) -> Rect2:
	var largura := maxf(30.0, alto * 0.45)
	return Rect2(c.x - largura * 0.5, c.y, largura, alto)


## O melhor lugar para o balão: {"caixa", "indice", "notas", "caixas"}.
func _melhor(c: Vector2, tamanho: Vector2, contexto: Dictionary) -> Dictionary:
	var entregue := contexto.duplicate()
	if falsificar:
		entregue["hud"] = []
	var av: Dictionary = BalaoFala.avaliar(c, tamanho, TELA, entregue)
	var notas: Array = av["notas"]
	var menor := INF
	var indice := 0
	for i in notas.size():
		if float(notas[i]) < menor:
			menor = float(notas[i])
			indice = i
	return {"caixa": (av["caixas"] as Array)[indice] as Rect2, "indice": indice, "notas": notas, "caixas": av["caixas"]}


func _cobre_rosto(caixa: Rect2, corpo: Rect2) -> float:
	return PopupsDoMundo.cobertura(caixa, BalaoFala.rosto_de(corpo))


func _run() -> void:
	BalaoFala = load("res://scripts/prototipo_3d/balao_fala.gd")
	falsificar = "--falsificar" in OS.get_cmdline_user_args()
	if falsificar:
		print("  FALSIFICAÇÃO: o balão avaliado sem o HUD (--falsificar)")
	var hud: Array[Rect2] = PopupsDoMundo.paineis_do_hud(TELA, null)
	var folga: float = BalaoFala.FOLGA

	# --- 1 e 2. FALANTE PERTO E LONGE, NO MEIO -----------------------------------------------------
	for caso: Array in [["perto", 220.0], ["longe", 60.0]]:
		var c := Vector2(640.0, 330.0)
		var corpo := _corpo(c, float(caso[1]))
		var r := _melhor(c, BALAO, {"falante": corpo, "hud": hud})
		var caixa: Rect2 = r["caixa"]
		_conferir(is_equal_approx(caixa.end.y, c.y - folga), "%s: o pé do balão está em y=%.1f, e devia ficar a %.0f acima da cabeça (y=%.1f)" % [caso[0], caixa.end.y, folga, c.y - folga])
		_conferir(caixa.position.x <= c.x and c.x <= caixa.end.x, "%s: a cabeça (x=%.0f) não está sob o balão (%.0f a %.0f)" % [caso[0], c.x, caixa.position.x, caixa.end.x])
		_conferir(_cobre_rosto(caixa, corpo) <= TOLERANCIA_DE_PX2, "%s: o balão cobre o rosto de quem fala" % caso[0])
		_conferir(int(r["indice"]) == 0, "%s: sem nada em volta o balão devia ficar centrado acima da cabeça (lugar %d)" % [caso[0], int(r["indice"])])

	# --- 3. NA BORDA ----------------------------------------------------------------------------------
	for x: float in [24.0, TELA.x - 130.0]:
		var c := Vector2(x, 400.0)
		var corpo := _corpo(c, 200.0)
		var r := _melhor(c, BALAO, {"falante": corpo, "hud": hud})
		var caixa: Rect2 = r["caixa"]
		_conferir(Rect2(Vector2.ZERO, TELA).encloses(caixa), "borda x=%.0f: o balão sai da tela (%s)" % [x, str(caixa)])
		_conferir(BalaoFala.distancia_ate(caixa, c) <= folga + 60.0, "borda x=%.0f: o balão está a %.0f px da cabeça" % [x, BalaoFala.distancia_ate(caixa, c)])
		_conferir(_cobre_rosto(caixa, corpo) <= TOLERANCIA_DE_PX2, "borda x=%.0f: o balão cobre o rosto de quem fala" % x)

	# --- 4. FORA DA TELA -------------------------------------------------------------------------------
	var fora_esquerda := Vector2(-260.0, 400.0)
	var r_esq := _melhor(fora_esquerda, BALAO, {"hud": hud})
	_conferir(is_equal_approx((r_esq["caixa"] as Rect2).position.x, BalaoFala.MARGEM), "fora à esquerda: o balão devia encostar na borda esquerda (x=%.1f)" % (r_esq["caixa"] as Rect2).position.x)
	var fora_direita := Vector2(TELA.x + 260.0, 400.0)
	var r_dir := _melhor(fora_direita, BALAO, {"hud": hud})
	# À direita a borda é a coluna de botões do HUD (HUD_COLUNA): o balão encosta nela.
	_conferir(is_equal_approx((r_dir["caixa"] as Rect2).end.x, TELA.x - PopupsDoMundo.HUD_COLUNA - BalaoFala.MARGEM),
		"fora à direita: o balão devia encostar na coluna do HUD, à direita (termina em x=%.1f)" % (r_dir["caixa"] as Rect2).end.x)
	_conferir(Rect2(Vector2.ZERO, TELA).encloses(r_esq["caixa"] as Rect2) and Rect2(Vector2.ZERO, TELA).encloses(r_dir["caixa"] as Rect2), "fora da tela: o balão sai da tela")

	# --- 5. SOB O HUD: O CASO DA CAPTURA ----------------------------------------------------------------
	# O Pedro no canto esquerdo, com a cabeça logo abaixo do bloco da missão (até y=215).
	var cabeca_do_pedro := Vector2(150.0, 300.0)
	var corpo_do_pedro := _corpo(cabeca_do_pedro, 200.0)
	var r5 := _melhor(cabeca_do_pedro, BALAO, {"falante": corpo_do_pedro, "hud": hud})
	var caixa5: Rect2 = r5["caixa"]
	var cobertura_do_hud := 0.0
	for painel in hud:
		cobertura_do_hud += PopupsDoMundo.cobertura(caixa5, painel)
	_conferir(cobertura_do_hud <= TOLERANCIA_DE_PX2, "sob o HUD: o balão (%s) cobre %.0f px² do bloco da missão ou de outro painel" % [str(caixa5), cobertura_do_hud])
	_conferir(BalaoFala.distancia_ate(caixa5, cabeca_do_pedro) <= 160.0, "sob o HUD: o balão está a %.0f px da cabeça do Pedro; devia ficar junto dele, e não do outro lado da tela" % BalaoFala.distancia_ate(caixa5, cabeca_do_pedro))
	_conferir(caixa5.position.x < TELA.x * 0.5, "sob o HUD: o balão do Pedro, no canto esquerdo, foi para a metade direita da tela (x=%.0f)" % caixa5.position.x)
	_conferir(_cobre_rosto(caixa5, corpo_do_pedro) <= TOLERANCIA_DE_PX2, "sob o HUD: o balão cobre o rosto do Pedro")

	# --- 6. COM DICA E JOGADOR AO LADO ---------------------------------------------------------------------
	var c6 := Vector2(700.0, 330.0)
	var corpo6 := _corpo(c6, 200.0)
	var jogador6 := _corpo(Vector2(c6.x + 120.0, 350.0), 210.0)
	var dica6 := Rect2(c6.x - 48.0, c6.y - 34.0, 96.0, 34.0)
	var placa6 := Rect2(c6.x - 50.0, c6.y - 70.0, 100.0, 26.0)
	var r6 := _melhor(c6, BALAO, {"falante": corpo6, "jogador": jogador6, "hud": hud, "dicas": [dica6], "placas": [placa6]})
	var caixa6: Rect2 = r6["caixa"]
	_conferir(BalaoFala.distancia_ate(caixa6, c6) <= TELA.x * 0.25, "dica e jogador ao lado: o balão está a %.0f px da cabeça (mais que um quarto da tela)" % BalaoFala.distancia_ate(caixa6, c6))
	_conferir(_cobre_rosto(caixa6, corpo6) <= TOLERANCIA_DE_PX2, "dica e jogador ao lado: o balão cobre o rosto de quem fala")
	_conferir(_cobre_rosto(caixa6, jogador6) <= TOLERANCIA_DE_PX2, "dica e jogador ao lado: o balão cobre o rosto do jogador")

	# --- 7. EM PÁGINAS ----------------------------------------------------------------------------------------
	var c7 := Vector2(800.0, 400.0)
	var corpo7 := _corpo(c7, 200.0)
	var duas := _melhor(c7, Vector2(300.0, 88.0), {"falante": corpo7, "hud": hud})
	var tres := _melhor(c7, Vector2(300.0, 112.0), {"falante": corpo7, "hud": hud})
	_conferir(int(duas["indice"]) == int(tres["indice"]), "as páginas escolheram lugares diferentes (%d e %d)" % [int(duas["indice"]), int(tres["indice"])])
	_conferir(is_equal_approx((duas["caixa"] as Rect2).end.y, (tres["caixa"] as Rect2).end.y), "o pé do balão mudou entre as páginas: y=%.1f e y=%.1f" % [(duas["caixa"] as Rect2).end.y, (tres["caixa"] as Rect2).end.y])

	# --- 8. A ORDEM É FIXA --------------------------------------------------------------------------------------
	var sem_hud: Dictionary = BalaoFala.avaliar(Vector2(640.0, 330.0), BALAO, TELA, {"hud": []})
	var com_hud: Dictionary = BalaoFala.avaliar(Vector2(640.0, 330.0), BALAO, TELA, {"hud": hud})
	_conferir((sem_hud["notas"] as Array).size() == (com_hud["notas"] as Array).size() and (sem_hud["notas"] as Array).size() == BalaoFala.lugares(Vector2(640.0, 330.0), BALAO, Rect2()).size(),
		"o número de lugares muda com o HUD: a permanência perderia a identidade do lugar")

	print("")
	if falhas == 0:
		print("BALAO_SOBRE_QUEM_FALA_OK: o balão fica acima da cabeça, com o pé a %.0f px dela, de perto e de longe; cabe na borda; encosta na borda do lado de quem está fora da tela; desliza do HUD sem atravessar a tela; não cobre rosto; o pé não muda entre páginas" % folga)
	else:
		print("balao_sobre_quem_fala: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)
