extends "res://tests/suite/caso.gd"
## Confere que A ÁRVORE DE ENCOSTA ASSENTA PELO PÉ DO TRONCO (#141).
##
##     .\tools\prototipo_3d\testar.ps1 -Teste pe_das_arvores_na_encosta
##
## "A posição das árvores e suas bases estão estranhas em alguns pontos do cenário." O plantio
## punha a árvore na altura do chão do PONTO de plantio, que é o meio da caixa do GLB (o meio da
## copa), e o tronco sai de até um metro e meio dele: nas encostas o pé ficava a até 0,5 u (aroeira)
## e 0,7 u (ingazeiro) do chão dele, flutuando de um lado e enterrado do outro. Agora o plantio mede
## o pé do tronco uma vez por malha (`GeoRegionRenderer.desnivel_do_pe`, que usa
## `CatalogoAssets.tronco_da_malha`) e põe a árvore na altura do chão do pé, e o `ground` do tronco
## acompanha.
##
## A MEDIDA, nas árvores plantadas de verdade (mata, beira do rio, restinga, paisagismo), menos o
## coqueiro (que tem a base própria) e o mangue (que mora na água): o erro de assento é a diferença
## entre o chão sob o pé do tronco que se vê (`base_do_tronco`) e o `ground` do tronco, que é a altura
## em que a árvore foi posta. Compara-se com o erro que a regra de antes daria (o `ground` do ponto de
## plantio, no mesmo pé):
##   1. há amostras (árvores com o pé a mais de um palmo do ponto de plantio);
##   2. o mundo TEM encosta em que a regra antiga erra (sensibilidade da régua);
##   3. o erro médio de agora é menos da metade do de antes;
##   4. o erro no percentil 95 cabe em MAXIMO_P95 (o que sobra é a trava de 1,2 u, a encosta em
##      barranco e a diferença entre a faixa de tamanho da árvore e a do tamanho de referência).
##
## FALSIFICAÇÃO embutida (`-- --falsificar`): a medida passa a tomar como erro o da regra antiga, e o
## portão TEM de reprovar na regra 3 (e na 4); se não reprovar, a régua não vale nada.

## Tamanho mínimo da amostra, e a distância do pé ao ponto de plantio que a faz contar (u).
const AMOSTRAS_MINIMAS := 200
const PE_LONGE_DO_PONTO := 0.2
## A régua tem de enxergar o defeito antigo: algum pé a mais disto do chão do ponto de plantio.
const SENSIBILIDADE := 0.3
## O erro médio de agora, sobre o de antes.
const MELHORA := 0.5
## O erro no percentil 95 (u).
const MAXIMO_P95 := 0.35
const ESPECIES_FORA := ["coqueiro", "mangue"]

var falhas := 0
var falsificar := false


func _initialize() -> void:
	falsificar = "--falsificar" in OS.get_cmdline_user_args()
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("PE_DA_ARVORE_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(8)
	var jogo := current_scene
	var world = jogo.get("world")
	var regiao = world._region if world != null else null
	_conferir(regiao != null and not (regiao._tree_trunks as Array).is_empty(), "o vale não tem tronco nenhum registrado")
	if regiao == null or (regiao._tree_trunks as Array).is_empty():
		_fechar()
		return

	var novos: Array[float] = []
	var velhos: Array[float] = []
	var pior_velho := 0.0
	var pior_especie := ""
	for t: Dictionary in regiao._tree_trunks:
		var especie := str(t.get("especie", ""))
		if especie in ESPECIES_FORA or bool(t.get("cortado", false)):
			continue
		var ponto: Vector2 = t["point"]
		var base: Vector3 = regiao.base_do_tronco(t)
		if Vector2(base.x - ponto.x, base.z - ponto.y).length() < PE_LONGE_DO_PONTO:
			continue
		var no_pe: float = regiao.ground_height_at(Vector3(base.x, 0.0, base.z))
		var velho := absf(no_pe - float(regiao.ground_height_at(Vector3(ponto.x, 0.0, ponto.y))))
		var novo := velho if falsificar else absf(no_pe - float(t["ground"]))
		novos.append(novo)
		velhos.append(velho)
		if velho > pior_velho:
			pior_velho = velho
			pior_especie = especie
	_conferir(novos.size() >= AMOSTRAS_MINIMAS, "poucas árvores com o pé longe do ponto de plantio (%d)" % novos.size())
	if novos.is_empty():
		_fechar()
		return
	_conferir(pior_velho > SENSIBILIDADE, "a régua não enxerga o defeito antigo: o pior pé está a só %.2f u do chão do ponto (%s)" % [pior_velho, pior_especie])
	var media_nova := _media(novos)
	var media_velha := _media(velhos)
	_conferir(media_nova < media_velha * MELHORA,
		"o erro médio de assento não caiu pela metade: %.3f u agora contra %.3f u antes" % [media_nova, media_velha])
	novos.sort()
	var p95: float = novos[mini(int(float(novos.size()) * 0.95), novos.size() - 1)]
	_conferir(p95 <= MAXIMO_P95, "o erro de assento no percentil 95 é de %.2f u (o limite é %.2f)" % [p95, MAXIMO_P95])
	print("  %d árvores medidas: erro médio %.3f u (antes %.3f), p95 %.2f u, pior de antes %.2f u (%s)"
		% [novos.size(), media_nova, media_velha, p95, pior_velho, pior_especie])
	_fechar()


func _media(valores: Array[float]) -> float:
	var soma := 0.0
	for v in valores:
		soma += v
	return soma / float(maxi(valores.size(), 1))


func _fechar() -> void:
	if falsificar:
		print("PE_DA_ARVORE_FALSIFICADO: %s" % ("o portão reprovou, como devia" if falhas > 0 else "O PORTÃO NÃO REPROVOU: a régua não vale"))
		quit(0 if falhas > 0 else 1)
		return
	print("PE_DA_ARVORE_OK: o pé do tronco assenta no chão dele nas encostas" if falhas == 0 else "pe_das_arvores_na_encosta: Falhas: %d" % falhas)
	quit(1 if falhas else 0)


func _frames(quantos: int) -> void:
	for i in quantos:
		await process_frame


func _mundo_pronto() -> void:
	for i in 3000:
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
