extends "res://tests/unidade/base.gd"
## AS CASAS DE TAIPA COLORIDAS TÊM A ESCALA DAS BRANCAS (#211).
##
##     .\tools\prototipo_3d\testar.ps1 -Teste casas_taipa_em_escala
##
## Os GLBs coloridos (azul, ocre, rosa, verde) têm planta mais quadrada, telhado mais alto e beiral
## maior que o da `casa_taipa`; normalizados pela mesma largura (6,5), saíam até 100% mais altos e
## com 40% a mais de volume, e o viajante (1,75 m) parecia pequeno ao lado deles. Perguntas, para
## toda chave `casa_taipa_*` do catálogo, contra a `casa_taipa` branca:
##
##   1. A ALTURA fica entre 90% e 118% da branca, e o VOLUME DE CAIXA entre 75% e 115%.
##   2. A LARGURA não passa da branca (6,5): nenhuma colorida é maior no chão.
##   3. A PORTA PINTADA DO CÔMODO (`data/interiores_casas.json`) tem entre 1,9 e 2,4 m — porta de
##      gente — e cabe na fachada; o pé-direito máximo, quando há, deixa a pessoa em pé (>= 2,4 m).
##
## FALSIFICAÇÃO: volte `largura` da `casa_taipa_ocre` para 6.5 no catálogo: a pergunta 1 reprova
## (altura 1,33x, volume 1,40x); volte `altura_da_porta` do ocre para 2.7: a 3 reprova.

const BRANCA := "casa_taipa"
const FAIXA_DE_ALTURA := Vector2(0.90, 1.18)
const FAIXA_DE_VOLUME := Vector2(0.75, 1.15)
const PORTA := Vector2(1.9, 2.4)
const PE_DIREITO_MINIMO := 2.4


func _medida(chave: String) -> AABB:
	var pai := Node3D.new()
	root.add_child(pai)
	var peca := CatalogoAssets.instanciar(chave, pai, Vector3.ZERO)
	var caixa := AABB()
	if peca != null:
		caixa = peca.get_meta("limites")
	pai.free()
	return caixa


func test_casas_taipa_em_escala() -> void:
	await process_frame
	var branca := _medida(BRANCA)
	_conferir(branca.size.y > 1.0, "a casa branca não instanciou")
	var volume_da_branca := branca.size.x * branca.size.y * branca.size.z
	var interiores: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/interiores_casas.json")).get("modelos", {})
	var coloridas: Array[String] = []
	for chave: String in CatalogoAssets.PECAS:
		if chave.begins_with(BRANCA + "_"):
			coloridas.append(chave)
	coloridas.sort()
	_conferir(coloridas.size() >= 4, "o catálogo tem só %d casas de taipa coloridas (esperado 4 ou mais)" % coloridas.size())
	for chave in coloridas:
		var caixa := _medida(chave)
		_conferir(caixa.size.y > 1.0, "%s não instanciou" % chave)
		var altura := caixa.size.y / branca.size.y
		var volume := caixa.size.x * caixa.size.y * caixa.size.z / volume_da_branca
		var largura := maxf(caixa.size.x, caixa.size.z)
		print("  %-18s %.2f x %.2f x %.2f m   altura %.2fx   volume %.2fx" % [chave, caixa.size.x, caixa.size.y, caixa.size.z, altura, volume])
		_conferir(altura >= FAIXA_DE_ALTURA.x and altura <= FAIXA_DE_ALTURA.y,
			"%s tem %.2f da altura da branca (faixa %.2f a %.2f)" % [chave, altura, FAIXA_DE_ALTURA.x, FAIXA_DE_ALTURA.y])
		_conferir(volume >= FAIXA_DE_VOLUME.x and volume <= FAIXA_DE_VOLUME.y,
			"%s tem %.2f do volume da branca (faixa %.2f a %.2f)" % [chave, volume, FAIXA_DE_VOLUME.x, FAIXA_DE_VOLUME.y])
		_conferir(largura <= maxf(branca.size.x, branca.size.z) + 0.01,
			"%s tem %.2f m no chão, mais que a branca (%.2f m)" % [chave, largura, maxf(branca.size.x, branca.size.z)])
		var porta: Dictionary = interiores.get(chave, {})
		_conferir(not porta.is_empty(), "%s não tem a porta lida em interiores_casas.json" % chave)
		if porta.is_empty():
			continue
		var alta := float(porta.get("altura_da_porta", 0.0))
		_conferir(alta >= PORTA.x and alta <= PORTA.y, "%s tem porta de %.2f m (faixa %.1f a %.1f: porta de gente)" % [chave, alta, PORTA.x, PORTA.y])
		_conferir(absf(float(porta.get("porta_x", 0.0))) + float(porta.get("largura_da_porta", 0.0)) * 0.5 <= largura * 0.5,
			"a porta de %s não cabe na fachada de %.2f m" % [chave, largura])
		if porta.has("pe_direito_max"):
			_conferir(float(porta["pe_direito_max"]) >= PE_DIREITO_MINIMO, "%s tem pé-direito máximo de %.2f m (mínimo %.1f)" % [chave, float(porta["pe_direito_max"]), PE_DIREITO_MINIMO])
