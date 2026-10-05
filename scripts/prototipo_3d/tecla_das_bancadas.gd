extends Node
## O E NAS BANCADAS: perto da bancada da oficina, a tecla abre a aba Oficina do
## painel; perto da fogueira do terreiro, a do fogão. O J continua abrindo as
## duas, como abre toda aba de lugar (`BancadasVale.aplicar`).
##
## "Não consegui progredir nas missões porque a bancada não tem asset e não
## consegui interagir." No 2D a bancada e o fogão se usam como a cama e o baú:
## encosta e aperta E ("Encoste nela e aperte E: ali a lenha vira tábua e vira
## corda"). No vale só o J abria, e nada na bancada dizia isso; quem chegava
## nela apertava o E, e nada acontecia.
##
## Mesmo molde da casa (`casa_do_jogador.gd`): a dica da tecla em cima do lugar
## e o E no `_unhandled_key_input`. O `Prototype` o põe antes de todo mundo que
## ouve o E — as lápides, as árvores, os lajedos, a pesca, os achados, a luta —,
## e quem entra depois recebe a tecla primeiro: com alvo mais preciso à mão, o
## E é deles.

const DicaTecla = preload("res://scripts/prototipo_3d/dica_tecla.gd")
const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")
const BancadasVale = preload("res://scripts/prototipo_3d/bancadas_vale.gd")
const PainelVale = preload("res://scripts/prototipo_3d/painel_vale.gd")
const FocoDoE = preload("res://scripts/prototipo_3d/foco_do_e.gd")

## Os lugares do E: a bancada (`BancadasVale.OBRAS`/`BANCADAS`), a aba que abre e
## o rótulo da dica.
const LUGARES := {
	"oficina": {"aba": PainelVale.Aba.OFICINA, "rotulo": "Oficina"},
	# A mesa do prumo abre a aba de obras dela ("Chegue no canteiro e aperte E.
	# Abre a aba de obras daquela mesa", no 2D).
	"canteiro": {"aba": PainelVale.Aba.OBRAS, "rotulo": "Canteiro"},
	"cozinha": {"aba": PainelVale.Aba.COZINHA, "rotulo": "Cozinhar"},
}
## A dica fica em cima da bancada, e não no pé dela.
const ALTURA_DA_DICA := 1.3

var _world
var _jogador: Node3D
## Abre o painel numa aba (`Prototype.abrir_o_painel`).
var _abrir: Callable
## Pode usar o E agora? (Ninguém lendo, nenhuma tela aberta: `Prototype`.)
var _livre: Callable
var _dica: PanelContainer
## O lugar ao alcance agora, ou "".
var _perto := ""


func configurar(world, jogador: Node3D, hud, abrir: Callable, livre: Callable) -> void:
	_world = world
	_jogador = jogador
	_abrir = abrir
	_livre = livre
	_dica = DicaTecla.criar(hud.map_layer(), Atalhos.letra("interagir"), "")
	add_to_group(FocoDoE.GRUPO)


## O QUE O E FARIA AQUI, para o foco (`foco_do_e.gd`): abrir a aba da bancada.
func alvo_do_e() -> Dictionary:
	if _perto == "" or _world == null:
		return {}
	return {"ponto": BancadasVale.ponto_da_provisoria(_world, _perto)}


## O lugar ao alcance do jogador agora: "oficina", "canteiro", "cozinha" ou "".
func perto() -> String:
	return _perto


func _process(_delta: float) -> void:
	if _jogador == null or _dica == null or _world == null:
		return
	_perto = ""
	var camera := get_viewport().get_camera_3d()
	var em_jogo: bool = camera != null and camera == _jogador.get("camera")
	if em_jogo and _jogador.is_physics_processing() and (not _livre.is_valid() or bool(_livre.call())):
		var menor := INF
		for qual: String in LUGARES:
			var d: float = BancadasVale.distancia(_world, _jogador.global_position, qual)
			if d <= BancadasVale.raio(qual) and d < menor:
				menor = d
				_perto = qual
	if _perto == "" or not FocoDoE.e_dele(self):
		_dica.visible = false
		return
	var onde: Vector3 = BancadasVale.ponto_da_provisoria(_world, _perto)
	DicaTecla.mostrar_em(_dica, camera, onde + Vector3.UP * ALTURA_DA_DICA, tr(str(LUGARES[_perto]["rotulo"])))


func _unhandled_key_input(event: InputEvent) -> void:
	if _perto == "":
		return
	if not (event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == Atalhos.tecla("interagir")):
		return
	if Dialogo.ocupado() or not _jogador.is_physics_processing() or not FocoDoE.e_dele(self):
		return
	get_viewport().set_input_as_handled()
	usar(_perto)


## Abre a aba do lugar. Público para o portão chamar sem simular tecla.
func usar(qual: String) -> void:
	if not LUGARES.has(qual) or not _abrir.is_valid():
		return
	_dica.visible = false
	_abrir.call(int(LUGARES[qual]["aba"]))
