extends Node
## A PESCA NO VALE (#11): a vara na mão, água à frente, e o E.
##
## A regra é o `Pesca` compartilhado, sem uma linha mudada: quanto se espera, a
## janela de três quartos de segundo para ferrar, o fôlego do lance e o tanque
## de cada água — no mar o robalo, no rio a traíra. O que mora aqui é o que o
## `Mundo._pescar` do 2D fazia com a cena: achar a água à frente, dizer de que
## água ela é, pôr a bóia, mostrar a fisgada e contar o que veio.
##
## A ÁGUA DECIDE O PEIXE. É doce onde o ponto cai na calha de um rio do mapa
## geográfico (a mesma linha com largura que o cenário usa para não plantar
## árvore dentro do rio), e é mar no resto. A lagoa (#23) entra como doce
## quando existir.
##
## A FISGADA É A BÓIA QUE AFUNDA, com o som da água mexendo — o "regar", que
## é o som que o 2D dá a ela —, e o aviso diz. É o que manda o jogador apertar
## o E, e a janela é curta.
##
## FERRAR VEM ANTES DE TUDO, como no 2D: com o peixe na linha, o E é da pesca
## antes de ser da luta, do achado ou da árvore — três quartos de segundo não
## dão para o E ir parar em outra coisa. Por isso ferrar escuta em `_input`, e
## o resto (lançar, recolher) em `_unhandled_key_input`, depois dos achados:
## com a vara na mão, dá para pegar o cordel do píer.
##
## ANDAR RECOLHE A LINHA. Pescar é esperar parado; quem sai de onde lançou
## desistiu.
##
## A VARA NA MÃO PESCA: do lance ao fim da espera ela fica na pose de "uso"
## (`Vestimenta3D.NA_MAO`, a ponta baixa para a água), e uma linha fina desce
## da ponta dela até a bóia, com a barriga que a linha frouxa tem. O peixe que
## fisga dá um tranco na vara. A linha sai da ponta que a peça mostra: no estilo
## procedural não há vara na mão, e então não há linha, só a bóia.

const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")
const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")
const Vestimenta3D = preload("res://scripts/prototipo_3d/vestimenta_3d.gd")
const TEXTOS := "res://data/pesca.json"
const VARA := "vara_de_pescar"

## Até onde, à frente, a linha procura água.
const ALCANCE := [1.6, 2.4, 3.4]
## Lâmina mínima para ser água de pescar, e não poça.
const FUNDO_MINIMO := 0.25
## Andou isto de onde lançou, desistiu.
const DESISTE := 1.2
## Perto assim do centro de um cardume, a linha está "no cardume".
const RAIO_DO_CARDUME := 6.0
## Os segmentos da linha, e quanto ela cai no meio (fração do comprimento).
const SEGMENTOS_DA_LINHA := 14
const BARRIGA_DA_LINHA := 0.06

var _world
var _player
var _hud
var _textos: Dictionary = {}
var _boia: MeshInstance3D
var _linha: MeshInstance3D
var _malha_da_linha: ImmediateMesh
var _sinal: Label3D
var _lancou_de: Vector3 = Vector3.INF
## A última água em que se lançou: "mar", "doce", ou "".
var agua_do_lance := ""
var no_cardume := false


func configurar(world, player, hud) -> void:
	_world = world
	_player = player
	_hud = hud
	var lido = JSON.parse_string(FileAccess.get_file_as_string(TEXTOS))
	_textos = lido if lido is Dictionary else {}
	_montar_a_boia()
	Pesca.fisgou.connect(_ao_fisgar)


func _texto(chave: String) -> String:
	return str(IdiomaMenu.campo(_textos.get(chave, {}), "texto", chave))


func _montar_a_boia() -> void:
	_boia = MeshInstance3D.new()
	_boia.name = "Boia"
	var esfera := SphereMesh.new()
	esfera.radius = 0.09
	esfera.height = 0.18
	_boia.mesh = esfera
	var tinta := StandardMaterial3D.new()
	tinta.albedo_color = Color(0.92, 0.3, 0.22)
	tinta.emission_enabled = true
	tinta.emission = Color(0.92, 0.3, 0.22)
	tinta.emission_energy_multiplier = 0.4
	_boia.material_override = tinta
	_boia.visible = false
	add_child(_boia)
	_sinal = Label3D.new()
	_sinal.text = "!"
	_sinal.font_size = 96
	_sinal.pixel_size = 0.006
	_sinal.modulate = Color(1.0, 0.85, 0.3)
	_sinal.outline_size = 10
	_sinal.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sinal.no_depth_test = true
	_sinal.visible = false
	add_child(_sinal)
	_malha_da_linha = ImmediateMesh.new()
	_linha = MeshInstance3D.new()
	_linha.name = "Linha"
	_linha.mesh = _malha_da_linha
	var fio := StandardMaterial3D.new()
	fio.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fio.albedo_color = Color(0.93, 0.9, 0.78)
	_linha.material_override = fio
	_linha.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_linha.visible = false
	add_child(_linha)


# --- a água ------------------------------------------------------------------

func _frente() -> Vector3:
	var giro: float = _player.visual.rotation.y
	return Vector3(sin(giro), 0.0, cos(giro))


## O ponto de água à frente do jogador, ou INF.
func agua_a_frente() -> Vector3:
	for passo in ALCANCE:
		var ponto: Vector3 = _player.global_position + _frente() * float(passo)
		if not _world.is_on_land(ponto) and _world.water_depth_at(ponto) >= FUNDO_MINIMO:
			return Vector3(ponto.x, _world.water_level(), ponto.z)
	return Vector3.INF


## "doce" na calha de um rio, "mar" no resto. Lê as linhas de rio do mapa
## geográfico — as mesmas que o cenário usa para não plantar dentro do rio.
func tipo_de_agua(ponto: Vector3) -> String:
	var regiao = _world.get("_region")
	if regiao != null:
		var aqui := Vector2(ponto.x, ponto.z)
		for rio in regiao.get("_rivers"):
			var largura := float(rio.get("width", 0.0))
			if regiao._distance_to_line(aqui, rio.get("points", PackedVector2Array())) <= largura * 0.5 + 0.5:
				return "doce"
	return "mar"


func _perto_de_cardume(ponto: Vector3) -> bool:
	for cardume in _world.find_children("Cardume*", "", true, false):
		var centro = cardume.get("_centro")
		if centro is Vector3 and Vector2(ponto.x - centro.x, ponto.z - centro.z).length() <= RAIO_DO_CARDUME:
			return true
	return false


# --- a tecla -----------------------------------------------------------------

## Ferrar vem antes de tudo (ver o cabeçalho).
func _input(event: InputEvent) -> void:
	if not Pesca.ferrando:
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == Atalhos.tecla("interagir"):
		ferrar()
		get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.physical_keycode != Atalhos.tecla("interagir") or not _player.is_physics_processing():
		return
	if Pesca.pescando:
		recolher()
		get_viewport().set_input_as_handled()
	elif Inventario.na_mao() == VARA and agua_a_frente().is_finite():
		lancar()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	_desenhar_a_linha()
	if not Pesca.pescando or not _lancou_de.is_finite():
		return
	var andou := Vector2(_player.global_position.x - _lancou_de.x, _player.global_position.z - _lancou_de.z).length()
	if andou > DESISTE:
		recolher()


# --- a pescaria --------------------------------------------------------------

## Do lance ao peixe. Quem conta os tempos é o `Pesca`; aqui só se mostra.
func lancar() -> Dictionary:
	var onde := agua_a_frente()
	if not onde.is_finite():
		return {}
	# Conferido ANTES de lançar, como no 2D: sem isto a bóia caía e voltava no
	# mesmo instante, porque `pescar()` desiste calado quando falta fôlego.
	if not Pesca.pode_pescar():
		_avisar(_texto("sem_folego"))
		return {}
	agua_do_lance = tipo_de_agua(onde)
	no_cardume = _perto_de_cardume(onde)
	_lancou_de = _player.global_position
	_boia.global_position = onde
	_boia.visible = true
	_sinal.visible = false
	if _player.has_method("usar_item_na_mao"):
		_player.call("usar_item_na_mao", INF)
	Audio.efeito("passo_agua")
	_avisar(_texto("no_cardume") if no_cardume else _texto("na_agua"))
	var premio: Dictionary = await Pesca.pescar(agua_do_lance, no_cardume)
	_lancou_de = Vector3.INF
	_boia.visible = false
	_sinal.visible = false
	_baixar_a_vara()
	if premio.is_empty():
		if not _recolhida:
			_avisar(_texto("vazia"))
		_recolhida = false
		return premio
	if str(premio["id"]) == "":
		_avisar(_texto("levou_a_isca"))
		return premio
	Audio.efeito("pegar")
	_avisar(_texto("ferrou") % [int(premio["qtd"]), _plural(str(premio["id"]), int(premio["qtd"]))])
	return premio


## Recolheu no meio da espera: sem aviso de "linha vazia" segundos depois.
var _recolhida := false

func recolher() -> void:
	if not Pesca.pescando:
		return
	_recolhida = true
	Pesca.desistir()
	_boia.visible = false
	_sinal.visible = false
	_lancou_de = Vector3.INF
	_baixar_a_vara()


func ferrar() -> bool:
	return Pesca.ferrar()


func _ao_fisgar() -> void:
	if _boia == null or not _boia.visible:
		return
	# A bóia afunda e o "!" acende: é a água que avisa, e o aviso escrito junto.
	_boia.global_position.y = _world.water_level() - 0.12
	_sinal.global_position = _boia.global_position + Vector3(0.0, 0.7, 0.0)
	_sinal.visible = true
	if _player.has_method("sacudir_item_na_mao"):
		_player.call("sacudir_item_na_mao")
	Audio.efeito("regar")
	_avisar(_texto("fisgou"))


## A vara volta à pose de parada, e a linha some.
func _baixar_a_vara() -> void:
	if _player != null and _player.has_method("usar_item_na_mao"):
		_player.call("usar_item_na_mao", 0.0)
	if _linha != null:
		_linha.visible = false


## A LINHA, da ponta da vara à bóia, num traço de segmentos com a barriga que a
## linha frouxa faz. Sem a ponta (a vara não está na mão), nada a desenhar.
func _desenhar_a_linha() -> void:
	if _linha == null:
		return
	var ponta := Vector3.INF
	if Pesca.pescando and _boia.visible and _player != null and _player.get("visual") != null:
		ponta = Vestimenta3D.ponta_na_mao(_player.get("visual"))
	_linha.visible = ponta.is_finite()
	_malha_da_linha.clear_surfaces()
	if not ponta.is_finite():
		return
	var fim := _boia.global_position
	var barriga := ponta.distance_to(fim) * BARRIGA_DA_LINHA
	_malha_da_linha.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in SEGMENTOS_DA_LINHA + 1:
		var t := float(i) / SEGMENTOS_DA_LINHA
		_malha_da_linha.surface_add_vertex(ponta.lerp(fim, t) - Vector3(0.0, 4.0 * t * (1.0 - t) * barriga, 0.0))
	_malha_da_linha.surface_end()


## "2 peixe" soava a erro de digitação (ver o 2D).
func _plural(id: String, quantos: int) -> String:
	var nome := Catalogo.nome(id).to_lower()
	if quantos <= 1 or nome.ends_with("s"):
		return nome
	return nome + "s"


func _avisar(texto: String) -> void:
	if _hud != null:
		_hud.set_notice(texto)
