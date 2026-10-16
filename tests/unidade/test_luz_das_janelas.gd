extends "res://tests/unidade/base.gd"
## O VIDRO ACESO SÓ ONDE HÁ JANELA, RENTE À FACHADA E COM TEXTURA (#257).
##
##     .\tools\prototipo_3d\testar.ps1 -Teste luz_das_janelas
##
## Na Build 11, ao entardecer (18h27), havia um quadrado branco chapado e brilhante sobre a porta da
## igreja. Era a "Luz da janela" (`LuzesEpoca.janela`): um quad de 0,86 x 1,0 m de uma cor só, emissivo
## a 2,2 (o tonemap o levava ao branco), posto onde a igreja não tem janela (é a verga entalhada da
## porta) e sempre voltado para o sul do mundo, e não para a frente da casa: a igreja olha para o
## oeste, e o quad ficava de través, espetado para fora da parede. Perguntas:
##
##   1. SÓ ONDE HÁ JANELA: toda `luz_janela` da composição (`composicao_vale.tscn`) e da tabela padrão
##      (`PecasConstrucoes.POR_CASA`) mora numa construção da lista COM_JANELA, que diz por quê. A
##      igreja não está nela.
##   2. RENTE À FACHADA: `janela(posicao, yaw)` põe o vidro com a normal na frente da casa (o +Z do
##      modelo girado por `yaw`) e o facho de luz 0,3 m à frente dele, para qualquer giro.
##   3. COM TEXTURA E SEM QUEIMAR: o vidro tem a mesma textura no albedo e na emissão, com moldura e
##      travessa mais escuras que o meio, o meio é quente (não branco), e a emissão cheia fica abaixo
##      da de antes (2,2), que queimava.
##   4. RESPONDE À LUZ DA CENA: de dia o vidro e o facho somem; à noite acendem.
##
## FALSIFICAÇÃO: reponha o nó "Luz da janela" em `Casas/Igreja` na composição, ou a linha em
## `POR_CASA["Igreja"]`: a pergunta 1 reprova. Tire o `rotation.y = yaw` de `LuzesEpoca.janela`: a 2
## reprova nos giros diferentes de zero. Volte o material à cor chapada (`albedo_color` e `emission`):
## a 3 reprova.

const COMPOSICAO := "res://scenes/prototipo_3d/composicao_vale.tscn"
const LUZES := "res://scripts/prototipo_3d/luzes_epoca.gd"
## Giros de fachada, em radianos: o sul (0), o leste, um qualquer e o da igreja do vale (-2,129: olha
## para o oeste-noroeste).
const GIROS := [0.0, PI / 2.0, 1.0, -2.1292093, 3.0]
## A emissão do vidro antes da #257, que o tonemap levava ao branco.
const EMISSAO_QUE_QUEIMAVA := 2.2

## As construções cuja fachada tem janela no ponto da `luz_janela`, e por quê.
const COM_JANELA := {
	"Casa de taipa": "a janela de madeira ao lado da porta, de frente, medida em foto de 15/10/2026",
}


## As construções ("Casas/<nome>") que têm um nó de tipo `luz_janela` na composição.
func _luzes_da_composicao() -> PackedStringArray:
	var casas := PackedStringArray()
	var regex := RegEx.create_from_string('parent="Casas/([^"/]+)"')
	var casa := ""
	for linha in FileAccess.get_file_as_string(COMPOSICAO).split("\n"):
		if linha.begins_with("[node "):
			var achado := regex.search(linha)
			casa = achado.get_string(1) if achado != null else ""
		elif casa != "" and linha.strip_edges() == 'tipo = "luz_janela"':
			casas.append(casa)
	return casas


## Os vidros acesos que `luzes` pôs (pelo grupo: o Godot renomeia o segundo nó de mesmo nome).
func _vidros(luzes: Node) -> Array:
	return luzes.get_children().filter(func(filho: Node) -> bool: return filho is MeshInstance3D and filho.is_in_group("vidro_aceso"))


func test_luz_da_janela_so_onde_ha_janela() -> void:
	var na_composicao := _luzes_da_composicao()
	_conferir(na_composicao.has("Casa de taipa"),
		"a composição perdeu a luz da janela da Casa de taipa (ou o leitor do .tscn deixou de achá-la)")
	for casa in na_composicao:
		_conferir(COM_JANELA.has(casa),
			"a composição põe uma luz_janela em '%s', cuja fachada não tem janela ali: o vidro aceso vira uma ficha branca sobre a parede (#257)" % casa)
	for casa: String in PecasConstrucoes.POR_CASA:
		for item: Dictionary in PecasConstrucoes.POR_CASA[casa]:
			if String(item.get("tipo", "")) == "luz_janela":
				_conferir(COM_JANELA.has(casa),
					"a tabela PecasConstrucoes.POR_CASA põe uma luz_janela em '%s', cuja fachada não tem janela ali (#257)" % casa)


func test_o_vidro_fica_rente_a_fachada_em_qualquer_giro() -> void:
	var luzes = load(LUZES).new()
	pendurar(luzes)
	for giro: float in GIROS:
		luzes.janela(Vector3(10.0, 2.0, -5.0), giro)
	var vidros: Array = _vidros(luzes)
	var facho: Array = luzes.find_children("*", "OmniLight3D", false, false)
	_conferir(vidros.size() == GIROS.size() and facho.size() == GIROS.size(),
		"cada janela põe um vidro e um facho (%d vidros, %d fachos para %d janelas)" % [vidros.size(), facho.size(), GIROS.size()])
	if vidros.size() != GIROS.size() or facho.size() != GIROS.size():
		return
	for i in GIROS.size():
		var giro: float = GIROS[i]
		var frente := Vector3(sin(giro), 0.0, cos(giro))
		var vidro := vidros[i] as Node3D
		var normal := vidro.global_transform.basis.z
		_conferir(normal.dot(frente) >= 0.999,
			"com giro de %.2f rad o vidro olha para %s, e a frente da casa é %s: ele fica de través na parede" % [giro, str(normal), str(frente)])
		var a_frente := (facho[i] as Node3D).position - vidro.position
		_conferir(a_frente.distance_to(frente * 0.3) < 0.01,
			"com giro de %.2f rad o facho fica em %s do vidro (esperado %s, à frente dele)" % [giro, str(a_frente), str(frente * 0.3)])


func test_o_vidro_tem_textura_e_nao_queima() -> void:
	var luzes = load(LUZES).new()
	pendurar(luzes)
	luzes.janela(Vector3.ZERO, 0.0)
	var vidros: Array = _vidros(luzes)
	_conferir(vidros.size() == 1, "a janela não pôs o vidro")
	if vidros.is_empty():
		return
	var material := (vidros[0] as MeshInstance3D).material_override as StandardMaterial3D
	_conferir(material != null, "o vidro não tem StandardMaterial3D")
	if material == null:
		return
	_conferir(material.albedo_texture != null, "o vidro não tem textura no albedo: é cor chapada (#257)")
	_conferir(material.emission_enabled and material.emission_texture != null and material.emission_texture == material.albedo_texture,
		"o vidro tem de emitir a mesma textura que mostra, para a moldura e a travessa não brilharem")
	_conferir(material.emission_energy_multiplier < EMISSAO_QUE_QUEIMAVA - 0.3,
		"a emissão cheia do vidro é %.2f, perto dos %.1f que o tonemap queimava em branco" % [material.emission_energy_multiplier, EMISSAO_QUE_QUEIMAVA])
	if material.albedo_texture == null:
		return
	var imagem := material.albedo_texture.get_image()
	var mais_claro := 0.0
	var mais_escuro := 1.0
	var cores := {}
	for y in imagem.get_height():
		for x in imagem.get_width():
			var cor := imagem.get_pixel(x, y)
			mais_claro = maxf(mais_claro, cor.get_luminance())
			mais_escuro = minf(mais_escuro, cor.get_luminance())
			cores[cor.to_html(false)] = true
	_conferir(cores.size() >= 8, "a textura do vidro tem só %d cores: é quase um quadrado chapado" % cores.size())
	_conferir(mais_escuro > 0.0 and mais_claro / mais_escuro >= 3.0,
		"a moldura e a travessa não se distinguem do vidro (luminância %.2f a %.2f)" % [mais_escuro, mais_claro])
	# Um ponto do vidro longe da moldura e da travessa: quente (vermelho > verde > azul) e longe do branco.
	var vidro := imagem.get_pixel(int(imagem.get_width() * 0.25), int(imagem.get_height() * 0.2))
	_conferir(vidro.r > vidro.g and vidro.g > vidro.b and vidro.b <= 0.7,
		"o vidro aceso tem cor %s: devia ser quente (a vela dentro do cômodo), e não branco" % vidro.to_html(false))


func test_o_vidro_acende_de_noite_e_apaga_de_dia() -> void:
	var dia := root.get_node("/root/Dia")
	var luzes = load(LUZES).new()
	pendurar(luzes)
	luzes.janela(Vector3.ZERO, 0.4)
	var vidros: Array = _vidros(luzes)
	var facho: Array = luzes.find_children("*", "OmniLight3D", false, false)
	_conferir(vidros.size() == 1 and facho.size() == 1, "a janela não pôs o vidro e o facho")
	if vidros.is_empty() or facho.is_empty():
		return
	var vidro := vidros[0] as MeshInstance3D
	var luz := facho[0] as OmniLight3D
	dia.definir_hora(12.0)
	luzes.aplicar_hora(12.0)
	_conferir(not vidro.visible and not luz.visible, "ao meio-dia o vidro ou o facho ficam acesos")
	dia.definir_hora(21.0)
	luzes.aplicar_hora(21.0)
	_conferir(vidro.visible and luz.visible and luz.light_energy > 0.1, "às 21h o vidro e o facho não acendem")
	var material := vidro.material_override as StandardMaterial3D
	_conferir(material != null and material.emission_energy_multiplier > 0.5 and material.emission_energy_multiplier < EMISSAO_QUE_QUEIMAVA - 0.3,
		"às 21h a emissão do vidro é %.2f: apagada, ou queimada" % (material.emission_energy_multiplier if material != null else -1.0))
