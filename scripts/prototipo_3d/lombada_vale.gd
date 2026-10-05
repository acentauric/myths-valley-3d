extends Node3D
## A LOMBADA DE PEDRA, A LAPA E A CABRA (data/missoes_lombada.json;
## docs/projeto/MISSOES_DO_2D.md, 1.5).
##
## O vale não tinha morro perto das terras — os altos são o outeiro do cemitério
## e o mirante —, e a frente do ofício do 2D pede um: a lombada onde a cabra do
## Seu Benedito subiu e não desce, com a rampa trancada pela lapa que a chuva
## rolou ladeira abaixo. O lugar foi escolhido no vale de hoje e revisado pelo
## autor ("Aprovo os três"): entre a casa e a chapada.
##
## O ALTO é uma caixa de pedra do tamanho de ALTO, apoiada no chão mais alto
## debaixo dela, vestida com as pedras do catálogo, maiores — parede em pé dos
## quatro lados, que não se sobe. A RAMPA sobe pelo leste, num corredor entre duas
## paredes de pedra, e no pé dela está a LAPA: o alvo de trabalho
## `lapa_da_lombada` (data/recursos_3d.json), que racha com a picareta em oito
## pedras. Enquanto ela está de pé, uma TRAVA invisível fecha o corredor na
## altura dela — a pedra do catálogo é baixa e redonda, e o jogador pularia por
## cima ou passaria de raspão. Caída a lapa (`derrubados("lapa")`, que vai no
## save), a trava sai.
##
## Lá em cima a CABRA perambula, e a placa da Santa Casa diz de quem é o alto.
## Ela desce quando o passo `cabra` fecha (a `cena` "cabra_desce"): rampa abaixo
## e embora, para o cercado do Seu Benedito. Quem diz se ela ainda está lá em
## cima é a fila (`passou("cabra")`), que vai no save.

## O meio do alto, em metros a partir da praça (o `world_builder` põe as âncoras).
const CENTRO_M := Vector3(-128.0, 0.0, -960.0)
## O alto: comprimento (x, de oeste a leste), altura e largura (z).
const ALTO := Vector3(10.0, 2.8, 7.0)
## A rampa, que sobe do leste até a borda do alto.
const RAMPA := 6.5
const LARGURA_DA_RAMPA := 2.6
## Do meio do alto ao pé da rampa, e do pé da rampa ao meio da lapa.
const PE_DA_RAMPA := ALTO.x * 0.5 + RAMPA
const ANTES_DA_LAPA := 0.9
## As paredes do corredor da rampa: grossura, e quanto passam da lapa.
const PAREDE := 0.7
const ALEM_DA_LAPA := 1.6

## A pedra: do escuro ao claro, na cor das pedras do catálogo em volta.
const PEDRA_ESCURA := Color(0.27, 0.25, 0.22)
const PEDRA_CLARA := Color(0.5, 0.47, 0.42)
## A altura das paredes do corredor sobre o chão da rampa.
const ACIMA_DA_RAMPA := 1.6
const MADEIRA := Color(0.4, 0.29, 0.18)
const TINTA := Color(0.16, 0.11, 0.07)
## A cabra no alto: até onde passeia a partir do meio, de quanto em quanto, e a
## que passo; e o passo dela descendo, que é de bicho que sabe o caminho.
const PASSEIO := Vector2(3.4, 2.2)
const PAUSA := 3.5
const PASSO := 0.8
const PASSO_DESCENDO := 2.4
## De quanto em quanto se confere a lapa e a fila (a partida que volta do save).
const CONFERIR_A_CADA := 0.25

var _mundo
var _cadeia
var _recursos
## A âncora "Lombada": o meio, na altura do chão mais alto debaixo do alto.
var _centro := Vector3.INF
var _topo := 0.0
var _trava: StaticBody3D = null
var _cabra: Node3D = null
var _descendo := false
var _desceu := false
var _proximo_passeio := 0.0
var _rng := RandomNumberGenerator.new()
var _conferir_em := 0.0
var _pedra: StandardMaterial3D = null


func configurar(mundo, cadeia, recursos) -> void:
	_mundo = mundo
	_cadeia = cadeia
	_recursos = recursos
	add_to_group("lombada")
	_centro = mundo.ancoras.get("Lombada", Vector3.INF)
	if not _centro.is_finite():
		return
	_rng.seed = 1887
	_topo = _centro.y + ALTO.y
	_levantar_o_alto()
	_levantar_a_rampa()
	_por_a_placa()
	# A lapa caída abre o corredor NA HORA; a conferência de quarto em quarto de
	# segundo cobre o resto (a partida que volta).
	if _recursos != null and _recursos.has_signal("derrubado"):
		_recursos.derrubado.connect(func(id: String, _rende: String, _quantos: int) -> void:
			if id == "lapa_da_lombada":
				acertar())
	acertar()


## A LOMBADA COMO O JOGO DIZ QUE ELA ESTÁ: a trava enquanto a lapa está de pé, a
## cabra enquanto o passo dela não fechou. Para os dois lados — carregar uma
## partida de antes põe as duas de volta.
func acertar() -> void:
	if not _centro.is_finite():
		return
	var lapa_de_pe: bool = _recursos == null or int(_recursos.derrubados("lapa")) == 0
	if lapa_de_pe and _trava == null:
		_trava = _corpo(Vector3(1.2, ALTO.y + 1.0, LARGURA_DA_RAMPA), _no_chao(PE_DA_RAMPA + ANTES_DA_LAPA, 0.0) + Vector3(0, (ALTO.y + 1.0) * 0.5 - 0.5, 0), "TravaDaLapa")
	elif not lapa_de_pe and _trava != null:
		_trava.queue_free()
		_trava = null
	var cabra_la_em_cima: bool = _cadeia == null or not _cadeia.passou("cabra")
	if cabra_la_em_cima and _cabra == null and not _descendo:
		_desceu = false
		_cabra = CatalogoAssets.instanciar("cabra", self, Vector3(_centro.x, _topo, _centro.z), 1.0, _rng.randf() * TAU)
		_proximo_passeio = 1.0
	elif not cabra_la_em_cima and _cabra != null and not _descendo:
		_cabra.queue_free()
		_cabra = null
		_desceu = true


## A lapa está de pé (o corredor da rampa fechado)?
func trancada() -> bool:
	return _trava != null


## Onde está a cabra, ou INF se ela já desceu.
func cabra() -> Vector3:
	return _cabra.global_position if is_instance_valid(_cabra) else Vector3.INF


func a_cabra_ja_desceu() -> bool:
	return _desceu


func _process(delta: float) -> void:
	_conferir_em -= delta
	if _conferir_em <= 0.0:
		_conferir_em = CONFERIR_A_CADA
		acertar()
	if not is_instance_valid(_cabra) or _descendo:
		return
	_proximo_passeio -= delta
	if _proximo_passeio > 0.0:
		return
	_proximo_passeio = PAUSA + _rng.randf() * PAUSA
	# UM PASSEIO NO ALTO: um ponto ao acaso dentro da borda, de frente para ele.
	var destino := Vector3(_centro.x + _rng.randf_range(-PASSEIO.x, PASSEIO.x), _topo, _centro.z + _rng.randf_range(-PASSEIO.y, PASSEIO.y))
	_andar_ate(_cabra, [destino], PASSO)


## A CABRA DESCE: rampa abaixo e embora, para o cercado do Seu Benedito, e some.
func a_cabra_desce() -> void:
	if not is_instance_valid(_cabra) or _descendo:
		return
	_descendo = true
	var caminho: Array = [
		Vector3(_centro.x + ALTO.x * 0.5 - 0.6, _topo, _centro.z),
		_no_chao(PE_DA_RAMPA, 0.0),
		_no_chao(PE_DA_RAMPA + 5.0, 0.0),
		_no_chao(PE_DA_RAMPA + 22.0, 6.0),
	]
	var andando := _andar_ate(_cabra, caminho, PASSO_DESCENDO)
	andando.tween_callback(func() -> void:
		if is_instance_valid(_cabra):
			_cabra.queue_free()
		_cabra = null
		_descendo = false
		_desceu = true)


## Leva `quem` pelos pontos, de frente para onde vai (a cabra do Tripo olha
## para +Z), no passo dado.
func _andar_ate(quem: Node3D, pontos: Array, passo: float) -> Tween:
	var andando := create_tween()
	var de := quem.global_position
	for ponto: Vector3 in pontos:
		var rumo := ponto - de
		rumo.y = 0.0
		if rumo.length() > 0.05:
			andando.tween_property(quem, "rotation:y", atan2(rumo.x, rumo.z), 0.25)
		andando.tween_property(quem, "global_position", ponto, maxf((ponto - de).length() / passo, 0.2))
		de = ponto
	return andando


# --- a pedra -------------------------------------------------------------------

## Um ponto em volta da lombada (x para o leste, z para o sul), no chão.
func _no_chao(x: float, z: float) -> Vector3:
	return _mundo.ground_position(_centro + Vector3(x, 0.0, z))


## A PEDRA DAS CAIXAS: ruído sem emenda, do escuro ao claro, com relevo, posto
## pelo mundo (triplanar) para as caixas vizinhas casarem. Cor lisa lia como
## parede de cimento no meio da mata.
func _material() -> StandardMaterial3D:
	if _pedra != null:
		return _pedra
	var ruido := FastNoiseLite.new()
	ruido.seed = 1887
	ruido.frequency = 0.035
	ruido.fractal_octaves = 4
	var degrade := Gradient.new()
	degrade.set_color(0, PEDRA_ESCURA)
	degrade.set_color(1, PEDRA_CLARA)
	var cor := NoiseTexture2D.new()
	cor.noise = ruido
	cor.seamless = true
	cor.color_ramp = degrade
	var relevo := NoiseTexture2D.new()
	relevo.noise = ruido
	relevo.seamless = true
	relevo.as_normal_map = true
	relevo.bump_strength = 8.0
	_pedra = StandardMaterial3D.new()
	_pedra.albedo_texture = cor
	_pedra.normal_enabled = true
	_pedra.normal_texture = relevo
	_pedra.roughness = 1.0
	_pedra.uv1_triplanar = true
	_pedra.uv1_world_triplanar = true
	_pedra.uv1_scale = Vector3.ONE * 0.18
	return _pedra


## Corpo de colisão em caixa, sem desenho.
func _corpo(tamanho: Vector3, onde: Vector3, nome: String, giro: Basis = Basis()) -> StaticBody3D:
	var corpo := StaticBody3D.new()
	corpo.name = nome
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = tamanho
	forma.shape = caixa
	corpo.add_child(forma)
	add_child(corpo)
	corpo.global_transform = Transform3D(giro, onde)
	return corpo


## Caixa de pedra: desenho e corpo.
func _bloco(tamanho: Vector3, onde: Vector3, nome: String, giro: Basis = Basis()) -> void:
	var corpo := _corpo(tamanho, onde, nome, giro)
	var desenho := MeshInstance3D.new()
	var caixa := BoxMesh.new()
	caixa.size = tamanho
	desenho.mesh = caixa
	desenho.material_override = _material()
	corpo.add_child(desenho)


## O ALTO: a caixa (um metro enterrada, para o pé não achar fresta) e as pedras
## do catálogo em volta, que fazem dela uma lombada e não um caixote.
func _levantar_o_alto() -> void:
	var fundo := 1.0
	_bloco(Vector3(ALTO.x, ALTO.y + fundo, ALTO.z), _centro + Vector3(0, (ALTO.y - fundo) * 0.5, 0), "AltoDaLombada")
	var meio_x := ALTO.x * 0.5
	var meio_z := ALTO.z * 0.5
	var em_volta: Array = [
		Vector2(-meio_x, -2.0), Vector2(-meio_x, 1.8), Vector2(-2.5, -meio_z), Vector2(2.0, -meio_z),
		Vector2(-2.6, meio_z), Vector2(2.2, meio_z), Vector2(meio_x, -2.6), Vector2(meio_x, 2.6),
	]
	for canto: Vector2 in em_volta:
		var tamanho := _rng.randf_range(1.6, 2.2)
		CatalogoAssets.instanciar("pedras", self, _no_chao(canto.x, canto.y), tamanho, _rng.randf() * TAU)
	for i in 3:
		var em_cima := Vector3(_centro.x + _rng.randf_range(-3.5, 3.5), _topo, _centro.z + _rng.randf_range(-2.4, 2.4))
		CatalogoAssets.instanciar("pedras", self, em_cima, 0.45, _rng.randf() * TAU)


## A RAMPA, do pé (no chão, a leste) até a borda do alto, num corredor de pedra
## que vai até além da lapa.
func _levantar_a_rampa() -> void:
	var alto := Vector3(_centro.x + ALTO.x * 0.5, _topo, _centro.z)
	var pe := _no_chao(PE_DA_RAMPA, 0.0)
	var rumo := pe - alto
	var comprimento := rumo.length() + 0.6
	var inclinacao := atan2(rumo.y, rumo.x)
	var giro := Basis(Vector3.BACK, inclinacao)
	var grossura := 0.5
	var meio := (alto + pe) * 0.5 - giro.y * (grossura * 0.5)
	_bloco(Vector3(comprimento, grossura, LARGURA_DA_RAMPA), meio, "RampaDaLombada", giro)
	# AS PAREDES DO CORREDOR, uma de cada lado: ao longo da rampa elas descem com
	# ela, ACIMA_DA_RAMPA por cima do chão dela — de pé até o alto, eram lajes de
	# quatro metros sobre o pé da rampa —; e do pé até além da lapa, na mesma
	# altura sobre o chão, fechando os lados dela.
	var ate := PE_DA_RAMPA + ANTES_DA_LAPA + ALEM_DA_LAPA
	for lado in [-1.0, 1.0]:
		var z: float = lado * (LARGURA_DA_RAMPA * 0.5 + PAREDE * 0.5)
		var ao_lado := Vector3(0.0, 0.0, z)
		var sobe := ACIMA_DA_RAMPA + grossura
		_bloco(Vector3(comprimento, sobe + 0.8, PAREDE), meio + ao_lado + giro.y * ((sobe + 0.8) * 0.5 - grossura * 0.5 - 0.8), "ParedeDaRampa", giro)
		var pe_da_parede := _no_chao(PE_DA_RAMPA, z)
		var fim := _no_chao(ate, z)
		var chao := maxf(pe_da_parede.y, fim.y)
		_bloco(Vector3(ate - PE_DA_RAMPA + 0.4, ACIMA_DA_RAMPA + 1.0, PAREDE), Vector3(_centro.x + (PE_DA_RAMPA + ate) * 0.5, chao + (ACIMA_DA_RAMPA - 1.0) * 0.5, _centro.z + z), "ParedeDaLapa")
		for k in 4:
			var x := lerpf(ALTO.x * 0.5 + 0.8, ate - 0.4, float(k) / 3.0)
			CatalogoAssets.instanciar("pedras", self, _no_chao(x, z + lado * 0.55), _rng.randf_range(1.2, 1.7), _rng.randf() * TAU)


## A PLACA DA SANTA CASA, na ponta oeste do alto, virada para quem sobe a rampa.
func _por_a_placa() -> void:
	var onde := Vector3(_centro.x - ALTO.x * 0.5 + 1.0, _topo, _centro.z)
	var poste := MeshInstance3D.new()
	var pau := BoxMesh.new()
	pau.size = Vector3(0.14, 1.5, 0.14)
	poste.mesh = pau
	var madeira := StandardMaterial3D.new()
	madeira.albedo_color = MADEIRA
	madeira.roughness = 1.0
	poste.material_override = madeira
	add_child(poste)
	poste.global_position = onde + Vector3(0, 0.75, 0)
	var tabua := MeshInstance3D.new()
	var prancha := BoxMesh.new()
	prancha.size = Vector3(0.06, 0.72, 1.8)
	tabua.mesh = prancha
	tabua.material_override = madeira
	add_child(tabua)
	tabua.global_position = onde + Vector3(0.08, 1.35, 0)
	var letreiro := Label3D.new()
	letreiro.name = "PlacaDaSantaCasa"
	letreiro.text = "SANTA CASA\nDE MISERICÓRDIA\nterras da irmandade"
	letreiro.font_size = 44
	letreiro.outline_size = 0
	letreiro.pixel_size = 0.0035
	letreiro.modulate = TINTA
	letreiro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(letreiro)
	letreiro.global_position = onde + Vector3(0.115, 1.35, 0)
	letreiro.rotation.y = PI * 0.5
