extends Node3D
## A LAVOURA DA CASA — a fazenda do jogador, na frente da casa herdada (#8).
##
## "Implemente também a casa do jogador, com sua fazenda." A regra é a do 2D
## (`plantacao.gd`, trazida inteira); o que este nó faz é o vale: uma grade de
## leitos no chão aberto do roçado, depois da cana e da lenha
## (`world_builder.LAVOURA_NA_CASA`), o desenho de cada leito e o gesto do E.
##
## O GESTO É O DO 2D (`Mundo._usar_no_rocado`): quem decide é o que está na mão.
##
##   enxada     ara o chão bruto
##   balde      molha o leito arado
##   semente    planta no leito arado e vazio, e gasta uma
##   mão livre  colhe o que está no ponto
##
## e cada gesto que não cabe DIZ por quê, como lá: "Chão bruto. A enxada abre o
## leito." O dia que vira (`Relogio.dia_comecou`, que a cama, a queda e o
## desmaio das duas disparam) faz crescer o que foi regado.
##
## O DESENHO DA PLANTA sai do catálogo, no estilo escolhido, com as peças que
## ele já tem: o capim é o broto, o canteiro de mandioca é a mandioca crescida,
## a cana é a cana, e as três fruteiras são as árvores da vila, pequenas. Não há
## peça nova nem desenho procedural novo; o chão arado é chão, como o terreno.

const Plantacao = preload("res://scripts/prototipo_3d/plantacao.gd")
const CatalogoAssets = preload("res://scripts/prototipo_3d/catalogo_assets.gd")
const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")
const DicaTecla = preload("res://scripts/prototipo_3d/dica_tecla.gd")
const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")
const TEXTOS := "res://data/lavoura.json"

## A grade: colunas de lado a lado (X da casa), linhas para a frente (Z).
const COLUNAS := 6
const LINHAS := 4
const ESPACO := 1.2
const LADO_DO_LEITO := 1.0
## De quão longe do campo a tecla ainda vale, e a altura dela.
const MARGEM := 0.7
const ALTURA_DA_DICA := 1.2
## Com que se rega: o balde d'água, como no 2D.
const DE_REGAR := ["balde"]
## Quanto tempo o balde fica tombado, despejando (s).
const GESTO_DE_REGAR := 0.8

## O desenho de cada estágio: a peça do catálogo e o tamanho dela.
const ESTAGIOS := {
	"mandioca": [["capim", 0.3], ["capim", 0.6], ["mandioca_canteiro", 0.2], ["mandioca_canteiro", 0.3]],
	"milho": [["capim", 0.35], ["capim", 0.7], ["capim", 1.1], ["capim", 1.5]],
	"cana": [["cana", 0.25], ["cana", 0.5], ["cana", 0.75], ["cana", 1.0]],
	"bananeira": [["bananeira", 0.2], ["bananeira", 0.45], ["bananeira", 0.6]],
	"mangueira": [["mangueira", 0.08], ["mangueira", 0.16], ["mangueira", 0.28], ["mangueira", 0.32]],
	"cajueiro": [["cajueiro", 0.12], ["cajueiro", 0.3], ["cajueiro", 0.4]],
}

signal arou
signal plantou
signal regou
signal colheu

var plantacao
var _mundo
var _jogador: Node3D
var _hud
var _textos: Dictionary = {}
var _dica: PanelContainer
## O meio do campo e os eixos dele (a frente da casa).
var _meio := Vector3.ZERO
var _x := Vector3.RIGHT
var _z := Vector3.BACK
## célula -> {"chao": MeshInstance3D, "planta": Node3D, "desenho": String}
var _leitos_3d: Dictionary = {}
var _perto := Vector2i(-1, -1)
var _material_seco: StandardMaterial3D
var _material_molhado: StandardMaterial3D


func configurar(mundo, jogador: Node3D, hud) -> void:
	_mundo = mundo
	_jogador = jogador
	_hud = hud
	add_to_group("lavoura")
	var lido = JSON.parse_string(FileAccess.get_file_as_string(TEXTOS))
	_textos = lido if lido is Dictionary else {}
	_meio = mundo.ancoras.get("Lavoura", Vector3.INF)
	var frente: Vector3 = mundo.ancoras.get("LavouraFrente", Vector3.BACK)
	frente.y = 0.0
	_z = frente.normalized() if frente.length() > 0.01 else Vector3.BACK
	_x = Vector3.UP.cross(_z).normalized()
	plantacao = Plantacao.new(func(celula: Vector2i) -> bool: return na_grade(celula))
	plantacao.mudou.connect(_desenhar)
	if not Relogio.dia_comecou.is_connected(_ao_virar_o_dia):
		Relogio.dia_comecou.connect(_ao_virar_o_dia)
	_material_seco = _terra(Color("7a5a3c"))
	_material_molhado = _terra(Color("4b3423"))
	if _meio.is_finite():
		_montar_o_chao()
	if hud != null:
		_dica = DicaTecla.criar(hud.map_layer(), Atalhos.letra("interagir"), "")


func _ao_virar_o_dia(_dia: int, _estacao: int, _ano: int) -> void:
	plantacao.novo_dia()


# --- a grade ---------------------------------------------------------------------

func na_grade(celula: Vector2i) -> bool:
	return celula.x >= 0 and celula.x < COLUNAS and celula.y >= 0 and celula.y < LINHAS


## O meio do leito, no chão.
func posicao_da(celula: Vector2i) -> Vector3:
	var local := Vector2((float(celula.x) - (COLUNAS - 1) * 0.5) * ESPACO, (float(celula.y) - (LINHAS - 1) * 0.5) * ESPACO)
	var ponto := _meio + _x * local.x + _z * local.y
	return _mundo.ground_position(ponto, 0.0) if _mundo != null else ponto


## A célula sob este ponto, ou (-1, -1) fora da grade.
func celula_em(ponto: Vector3) -> Vector2i:
	if not _meio.is_finite():
		return Vector2i(-1, -1)
	var d := ponto - _meio
	var celula := Vector2i(roundi(d.dot(_x) / ESPACO + (COLUNAS - 1) * 0.5), roundi(d.dot(_z) / ESPACO + (LINHAS - 1) * 0.5))
	return celula if na_grade(celula) else Vector2i(-1, -1)


## O jogador está no campo (ou na beira dele)? É onde a tecla é da lavoura, e
## não dos alvos de trabalho em volta (`recursos_3d.gd`).
func no_campo(ponto: Vector3) -> bool:
	if not _meio.is_finite():
		return false
	var d := ponto - _meio
	return absf(d.dot(_x)) <= COLUNAS * ESPACO * 0.5 + MARGEM and absf(d.dot(_z)) <= LINHAS * ESPACO * 0.5 + MARGEM \
		and absf(d.y) < 3.0


# --- o chão e a planta -------------------------------------------------------------

## O chão da lavoura, um pouco mais claro que o arado, para se ver onde ela é.
func _montar_o_chao() -> void:
	for y in LINHAS:
		for x in COLUNAS:
			var celula := Vector2i(x, y)
			var chao := MeshInstance3D.new()
			chao.name = "Leito_%d_%d" % [x, y]
			var caixa := BoxMesh.new()
			caixa.size = Vector3(LADO_DO_LEITO, 0.05, LADO_DO_LEITO)
			chao.mesh = caixa
			chao.material_override = _terra(COR_BRUTA)
			add_child(chao)
			chao.global_position = posicao_da(celula) + Vector3.UP * 0.02
			chao.global_basis = Basis.looking_at(-_z, Vector3.UP)
			_leitos_3d[celula] = {"chao": chao, "planta": null, "desenho": ""}


func _desenhar(celula: Vector2i) -> void:
	if not _leitos_3d.has(celula):
		return
	var leito: Dictionary = _leitos_3d[celula]
	var chao: MeshInstance3D = leito["chao"]
	if plantacao.arado(celula):
		chao.material_override = _material_molhado if plantacao.molhado(celula) else _material_seco
		(chao.mesh as BoxMesh).size = Vector3(LADO_DO_LEITO, 0.09, LADO_DO_LEITO)
	else:
		chao.material_override = _terra(COR_BRUTA)
		(chao.mesh as BoxMesh).size = Vector3(LADO_DO_LEITO, 0.05, LADO_DO_LEITO)
	var cultura: String = plantacao.cultura_em(celula)
	var desenho := "" if cultura == "" else "%s:%d" % [cultura, plantacao.estagio(celula)]
	if desenho == str(leito["desenho"]):
		return
	if is_instance_valid(leito["planta"]):
		(leito["planta"] as Node).queue_free()
	leito["planta"] = null
	leito["desenho"] = desenho
	if cultura == "":
		return
	leito["planta"] = _planta(cultura, plantacao.estagio(celula), posicao_da(celula) + Vector3.UP * 0.05,
		float(hash("%d,%d" % [celula.x, celula.y]) % 628) / 100.0)


## A planta no estágio dela: a peça do catálogo, ou, no procedural, o broto de
## cone que o roçado já desenhava (`world_builder._build_farm`).
func _planta(cultura: String, qual: int, onde: Vector3, giro: float) -> Node3D:
	var estagios: Array = ESTAGIOS.get(cultura, [])
	if estagios.is_empty():
		return null
	var peca: Array = estagios[clampi(qual, 0, estagios.size() - 1)]
	if Estilo.tripo():
		var modelo := CatalogoAssets.instanciar(str(peca[0]), self, onde, float(peca[1]), giro)
		if modelo != null:
			modelo.name = "Planta_%s" % cultura
			return modelo
	var broto := MeshInstance3D.new()
	broto.name = "Planta_%s" % cultura
	var cone := CylinderMesh.new()
	cone.top_radius = 0.02
	cone.bottom_radius = 0.12 + 0.06 * float(qual)
	cone.height = 0.3 + 0.35 * float(qual)
	cone.radial_segments = 5
	broto.mesh = cone
	var verde := StandardMaterial3D.new()
	verde.albedo_color = Color("8fa85e")
	broto.material_override = verde
	add_child(broto)
	broto.global_position = onde + Vector3.UP * cone.height * 0.5
	return broto


## A terra arada (terra_arada_v1, do OpenAI): sulcos paralelos no sentido de cada leito
## (o UV é o da caixa, que gira com o campo). Um material por tinta, compartilhado
## pelos 24 leitos: antes era um novo a cada célula, e liso.
const TERRA_ARADA := "res://assets/prototipo_3d/materiais/terra_arada_v1.png"
## Quantas vezes a textura (3 m de chão, 0,75 u) se repete num leito de 1 u.
const REPETE_ARADA := 1.35
## O leito ainda por arar, mais claro que o arado para se ver onde a lavoura é.
const COR_BRUTA := Color("8c7253")
## A cor média da textura (medida em Python): a tinta a acerta para a cor do estado.
const MEDIA_ARADA := Color(0.262, 0.189, 0.138)
var _terras: Dictionary = {}


func _terra(cor: Color) -> StandardMaterial3D:
	if _terras.has(cor):
		return _terras[cor]
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(TERRA_ARADA)
	# A tinta de cada estado (bruto, seco, molhado) é a cor de antes dividida pela
	# média da textura: o leito arado continua escuro e o bruto, claro.
	# A divisão é em luz linear, que é onde a cor da caixa multiplica a textura.
	var alvo := cor.srgb_to_linear()
	var media := MEDIA_ARADA.srgb_to_linear()
	material.albedo_color = Color(alvo.r / media.r, alvo.g / media.g, alvo.b / media.b).linear_to_srgb()
	material.uv1_scale = Vector3(REPETE_ARADA, REPETE_ARADA, 1.0)
	material.roughness = 0.95
	_terras[cor] = material
	return material


# --- a tecla -------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if _jogador == null or _dica == null:
		return
	var camera := get_viewport().get_camera_3d()
	var em_jogo: bool = camera != null and camera == _jogador.get("camera")
	_perto = Vector2i(-1, -1)
	if em_jogo and not Dialogo.ativo and no_campo(_jogador.global_position):
		_perto = leito_da_vez()
	if _perto == Vector2i(-1, -1):
		_dica.visible = false
		return
	DicaTecla.mostrar_em(_dica, camera, posicao_da(_perto) + Vector3.UP * ALTURA_DA_DICA, acao(_perto))


## O leito em que o gesto cai: o da frente do corpo, ou o de baixo dele.
func leito_da_vez() -> Vector2i:
	var visual: Node3D = _jogador.get("visual")
	var adiante := Vector3.ZERO
	if visual != null:
		adiante = visual.global_basis.z
		adiante.y = 0.0
		adiante = adiante.normalized() * 0.75 if adiante.length() > 0.01 else Vector3.ZERO
	var celula := celula_em(_jogador.global_position + adiante)
	if celula == Vector2i(-1, -1):
		celula = celula_em(_jogador.global_position)
	return celula


## O que a tecla diz no leito, pelo que está na mão.
func acao(celula: Vector2i) -> String:
	var mao := Inventario.na_mao()
	if mao == "enxada":
		return _texto("arar")
	if mao in DE_REGAR:
		return _texto("regar")
	if Catalogo.tipo(mao) == "semente":
		return _texto("plantar") % Catalogo.nome(mao)
	if plantacao.maduro(celula):
		return _texto("colher") % _nome_da_cultura(plantacao.cultura_em(celula))
	return _texto("olhar")


func _unhandled_key_input(event: InputEvent) -> void:
	if _perto == Vector2i(-1, -1):
		return
	if not (event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == Atalhos.tecla("interagir")):
		return
	if Dialogo.ocupado() or not _jogador.is_physics_processing():
		return
	get_viewport().set_input_as_handled()
	_gesto_no_leito(_perto)
	usar(_perto)


## O GESTO QUE ACOMPANHA O EFEITO (arar e regar): o corpo se vira para o leito, e
## a enxada cai nele — o golpe do machado, uma vez, e com ele a pose de golpe da
## enxada (`Vestimenta3D.NA_MAO`) — ou o balde tomba e despeja. Só quando o
## efeito vai acontecer: a enxada num leito já arado, ou o balde num leito seco
## demais, não fazem gesto nenhum. Fica FORA de `usar()`, que os portões chamam
## aos montes: o gesto é da tecla.
func _gesto_no_leito(celula: Vector2i) -> void:
	if not na_grade(celula) or _jogador == null:
		return
	var mao := Inventario.na_mao()
	var arar: bool = mao == "enxada" and not plantacao.arado(celula)
	var regar: bool = mao in DE_REGAR and plantacao.arado(celula) and not plantacao.molhado(celula)
	if not arar and not regar:
		return
	var visual := _jogador.get("visual") as Node3D
	if visual != null:
		var alvo := posicao_da(celula)
		visual.rotation.y = atan2(alvo.x - _jogador.global_position.x, alvo.z - _jogador.global_position.z)
	if arar:
		var animador = _jogador.get("animator")
		if animador != null and animador.has_method("play_chop") and animador.play_chop(1) != "":
			_jogador.call("travar_acao_de_golpe", 5.0, true)
	elif _jogador.has_method("usar_item_na_mao"):
		_jogador.call("usar_item_na_mao", GESTO_DE_REGAR)


## O GESTO NO LEITO, pelo que está na mão — `Mundo._usar_no_rocado` do 2D.
func usar(celula: Vector2i) -> void:
	if not na_grade(celula):
		return
	var mao := Inventario.na_mao()
	if mao == "enxada" or mao in DE_REGAR or Catalogo.tipo(mao) == "ferramenta":
		if mao == "enxada" and not plantacao.arado(celula):
			if not Energia.gastar("arar"):
				_avisar("cansaco")
				return
			if plantacao.arar(celula):
				Audio.efeito("arar")
				Talentos.ganhar("arar")
				arou.emit()
		elif mao in DE_REGAR and plantacao.arado(celula) and not plantacao.molhado(celula):
			if not Energia.gastar("regar"):
				_avisar("cansaco")
				return
			if plantacao.regar(celula):
				Audio.efeito("regar")
				Talentos.ganhar("regar")
				regou.emit()
				# O INVERNO PARA A ROÇA, e o jogador precisa saber disso na hora
				# de regar, e não três dias depois.
				if plantacao.parada_por_estacao() and plantacao.plantado(celula):
					_avisar("inverno_regando")
		elif mao == "enxada":
			_avisar("ja_arado")
		elif mao in DE_REGAR and not plantacao.arado(celula):
			_avisar("molhar_chao_duro")
		elif mao in DE_REGAR:
			_avisar("ja_molhado")
		else:
			_avisar("nao_serve", Catalogo.nome(mao))
		return
	if Catalogo.tipo(mao) == "semente":
		var cultura := str(Catalogo.dados(mao).get("cultura", ""))
		if not plantacao.arado(celula):
			_avisar("semente_chao_duro")
			return
		if plantacao.plantado(celula):
			_avisar("ja_plantado")
			return
		if not Energia.gastar("plantar"):
			_avisar("cansaco")
			return
		if plantacao.plantar(celula, cultura):
			Inventario.consumir(mao, 1)
			Audio.efeito("plantar")
			Talentos.ganhar("plantar")
			plantou.emit()
		return
	# Mão livre (ou com o que não é ferramenta nem semente): colhe.
	if not plantacao.maduro(celula):
		if not plantacao.arado(celula):
			_avisar("chao_bruto")
		elif not plantacao.plantado(celula):
			_avisar("leito_vazio")
		elif plantacao.parada_por_estacao():
			_avisar("inverno")
		else:
			_avisar("nao_esta_no_ponto")
		return
	if not Energia.gastar("colher"):
		_avisar("cansaco")
		return
	var colhido: Dictionary = plantacao.colher(celula)
	if colhido.is_empty():
		return
	Inventario.adicionar(str(colhido["id"]), int(colhido["qtd"]))
	if int(colhido["sementes"]) > 0 and str(colhido.get("semente_id", "")) != "":
		Inventario.adicionar(str(colhido["semente_id"]), int(colhido["sementes"]))
	var qualidades: Array = _textos.get("qualidades", [])
	var qualidade := str(IdiomaMenu.campo(qualidades[int(colhido["qualidade"])], "texto")) \
		if int(colhido["qualidade"]) < qualidades.size() else str(colhido.get("qualidade_nome", ""))
	_avisar("colheita", qualidade, int(colhido["qtd"]), Catalogo.nome(str(colhido["id"])).to_lower())
	Audio.efeito("colher")
	Talentos.ganhar("colher")
	colheu.emit()


func _nome_da_cultura(cultura: String) -> String:
	var semente := Plantacao.semente_de(cultura)
	var colheita := str(Plantacao.CULTURAS.get(cultura, {}).get("colheita", cultura))
	return Catalogo.nome(colheita).to_lower() if colheita != "" else Catalogo.nome(semente)


func _texto(chave: String) -> String:
	return str(IdiomaMenu.campo(_textos.get("acoes", {}).get(chave, {}), "texto", chave))


## O recado do leito, nos três idiomas (`data/lavoura.json`), no canto do HUD.
func _avisar(chave: String, a = null, b = null, c = null) -> void:
	var texto := str(IdiomaMenu.campo(_textos.get("recados", {}).get(chave, {}), "texto", chave))
	var partes := [a, b, c].filter(func(p): return p != null)
	if not partes.is_empty():
		texto = texto % partes
	if _hud != null and _hud.has_method("set_notice"):
		_hud.set_notice(texto)


# --- o save ------------------------------------------------------------------------

func estado_para_salvar() -> Dictionary:
	return {"leitos": plantacao.leitos_para_salvar()}


func restaurar(estado: Dictionary) -> void:
	var leitos = estado.get("leitos", {})
	plantacao.restaurar_leitos(leitos if leitos is Dictionary else {})
	for celula in _leitos_3d:
		_desenhar(celula)
