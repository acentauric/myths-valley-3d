extends Node
## Livro, pagamento confirmado e rendimento da rede do Tonho (#68).
const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")
const DicaTecla = preload("res://scripts/prototipo_3d/dica_tecla.gd")
const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")
const FocoDoE = preload("res://scripts/prototipo_3d/foco_do_e.gd")
const TEXTOS := "res://data/fiado_tonho.json"
const DIVIDA := 1900
const POR_DIA := 130
const POR_PAGAMENTO := 500
var divida := DIVIDA
var rede := false
var lido := false
var ultimo_dia := 0
var _jogador: Node3D
var _interiores: Node
var _fila: Node
var _hud: Node
var _dica: PanelContainer
var _ocupado := false
var _textos: Dictionary = {}

func configurar(jogador: Node3D, hud: Node, interiores: Node, fila: Node) -> void:
	_jogador = jogador
	_hud = hud
	_interiores = interiores
	_fila = fila
	_textos = JSON.parse_string(FileAccess.get_file_as_string(TEXTOS))
	_dica = DicaTecla.criar(hud.map_layer(), Atalhos.letra("interagir"), texto("acao"))
	add_to_group(FocoDoE.GRUPO)
	ultimo_dia = Relogio.dia_absoluto()
	Relogio.dia_comecou.connect(_ao_virar_dia)

func texto(chave: String) -> String:
	return str(IdiomaMenu.campo(_textos.get(chave, {}), "texto", chave))

func _process(_delta: float) -> void:
	_sincronizar()
	if _dica == null:
		return
	var alvo := alvo_do_e()
	_dica.visible = not alvo.is_empty() and FocoDoE.e_dele(self)
	if _dica.visible:
		DicaTecla.mostrar_em(_dica, get_viewport().get_camera_3d(), alvo["ponto"], texto("acao"))

func _sincronizar() -> void:
	if _fila == null:
		return
	if not rede and _fila.passou("pescador_rede"):
		rede = true
		ultimo_dia = Relogio.dia_absoluto()
	if lido:
		_fila.registrar_evento("livro_tonho_lido")
	if divida == 0:
		_fila.registrar_evento("divida_tonho_quitada")

func alvo_do_e() -> Dictionary:
	if _jogador == null or _ocupado or Dialogo.ocupado() or _interiores == null \
			or _interiores.dentro() != "venda" or get_viewport().get_camera_3d() != _jogador.get("camera"):
		return {}
	var sala: Node3D = _interiores.sala_de("venda")
	if sala == null:
		return {}
	var bau: Node3D = sala.peca_do_perfil("bau")
	if bau == null:
		return {}
	var ponto: Vector3 = sala.to_global(sala.caixa_no_comodo(bau).get_center())
	var distancia := Vector2(ponto.x - _jogador.global_position.x, ponto.z - _jogador.global_position.z).length()
	return {"ponto": ponto} if distancia <= 1.7 else {}

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == Atalhos.tecla("interagir") \
			and not alvo_do_e().is_empty() and _jogador.is_physics_processing() and FocoDoE.e_dele(self):
		get_viewport().set_input_as_handled()
		ler()

func quanto_pagar() -> int:
	return mini(POR_PAGAMENTO, mini(divida, maxi(0, Jogo.dinheiro)))

func pagar(quanto: int) -> int:
	var pago := mini(maxi(0, quanto), quanto_pagar())
	Jogo.dinheiro -= pago
	divida -= pago
	_sincronizar()
	return pago

func ler() -> void:
	if _ocupado:
		return
	_ocupado = true
	lido = true
	_sincronizar()
	var quanto := quanto_pagar()
	if divida == 0:
		await Dialogo.falar(texto("titulo"), [texto("quitada")])
	elif quanto == 0:
		await Dialogo.falar(texto("titulo"), [texto("sem_dinheiro") % divida])
	else:
		var sim: bool = await Dialogo.perguntar(texto("titulo"), texto("pergunta") % [divida, quanto, Jogo.dinheiro])
		if sim:
			var pago := pagar(quanto)
			_hud.set_notice(texto("pago") % [pago, divida])
	_ocupado = false

func _ao_virar_dia(_dia: int, _estacao: int, _ano: int) -> void:
	abater_dias(Relogio.dia_absoluto())

func abater_dias(hoje: int) -> void:
	var dias := maxi(0, hoje - ultimo_dia)
	if rede:
		divida = maxi(0, divida - POR_DIA * dias)
	ultimo_dia = maxi(ultimo_dia, hoje)
	_sincronizar()

func estado_para_salvar() -> Dictionary:
	return {"divida": divida, "rede": rede, "lido": lido, "ultimo_dia": ultimo_dia}

func restaurar(estado: Dictionary) -> void:
	divida = clampi(int(estado.get("divida", DIVIDA)), 0, DIVIDA)
	rede = bool(estado.get("rede", false))
	lido = bool(estado.get("lido", false))
	ultimo_dia = int(estado.get("ultimo_dia", Relogio.dia_absoluto()))
	_sincronizar()
