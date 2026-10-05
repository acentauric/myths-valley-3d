extends Node
## A CASA DO JOGADOR: a cama que vira o dia e o baú da casa (#50, #26).
##
## O cômodo (`interior_casa.gd`) é a casa; este nó é o que se faz nela. Perto da
## cama, a tecla diz "Dormir"; perto do baú, "Baú". Como no 2D:
##
##   - A CAMA pergunta antes ("Dormir até o amanhecer?", com o dia e a hora, de
##     `Mundo._tentar_dormir`), e quem diz que sim dorme pela `queda.gd` — a
##     mesma virada da queda e do desmaio, com o corpo descansado.
##   - O BAÚ DA CASA abre a tela da mochila com ele do lado
##     (`Mochila.abrir_bau`), doze espaços, e a tela mexe no próprio Array: o
##     save guarda o que está lá sem ninguém precisar sincronizar. A partida
##     nova o acha com dois beijus — a comida da casa do 2D (`COMIDA_DA_CASA`)
##     — e com o que o finado deixou para a roça: a enxada, o balde e o punhado
##     de maniva do baú da varanda do 2D (`Mundo.ITENS_INICIAIS`). Pegá-los é o
##     passo "As ferramentas do finado" da chegada, como no 2D.

const TEXTOS := "res://data/casa.json"
const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")
const DicaTecla = preload("res://scripts/prototipo_3d/dica_tecla.gd")
const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")

## De quão perto se alcança a cama e o baú, no chão.
const ALCANCE := 1.7
const ALTURA_DA_DICA := 0.5
## O baú da casa do 2D: doze espaços, e a comida da casa dentro.
const BAU_CABE := 12
const COMIDA_DA_CASA := "beiju"
const COMIDA_QUANTOS := 2
## "Enxada, balde e um punhado de maniva. Era o que o velho tinha."
const DO_FINADO := {"enxada": 1, "balde": 1, "semente_mandioca": 4}

var _jogador: Node3D
var _hud
var _interiores
var _noite
var _textos: Dictionary = {}
var _dica: PanelContainer
## "cama", "bau" ou "".
var _perto := ""
var _ocupado := false
## O BAÚ DA CASA: [{"id", "qtd"}], por referência na tela da mochila.
var bau: Array = []
## A comida da casa já foi posta no baú nesta partida.
var _comida_posta := false


func configurar(jogador: Node3D, hud, interiores, noite) -> void:
	_jogador = jogador
	_hud = hud
	_interiores = interiores
	_noite = noite
	add_to_group("casa_do_jogador")
	var lido = JSON.parse_string(FileAccess.get_file_as_string(TEXTOS))
	_textos = lido if lido is Dictionary else {}
	_dica = DicaTecla.criar(hud.map_layer(), Atalhos.letra("interagir"), "")
	_por_a_comida_da_casa()


## O cômodo da casa, se o vale o montou.
func quarto() -> Node3D:
	return _interiores.sala_de("casa") if _interiores != null and _interiores.has_method("sala_de") else null


## Perto de quê o jogador está agora: "cama", "bau" ou "".
func perto() -> String:
	return _perto


func _process(_delta: float) -> void:
	if _jogador == null or _dica == null:
		return
	var sala := quarto()
	var camera := get_viewport().get_camera_3d()
	var em_jogo: bool = camera != null and camera == _jogador.get("camera")
	_perto = ""
	if sala != null and em_jogo and not _ocupado and not Dialogo.ativo and _interiores.dentro() == "casa" \
			and not (_noite != null and _noite.virando_a_noite()):
		_perto = _mais_perto(sala, _jogador.global_position)
	if _perto == "":
		_dica.visible = false
		return
	DicaTecla.mostrar_em(_dica, camera, _ponto(sala, _perto) + Vector3.UP * ALTURA_DA_DICA, _acao(_perto))


func _ponto(sala: Node3D, qual: String) -> Vector3:
	return sala.ponto_da_cama() if qual == "cama" else sala.ponto_do_bau()


func _mais_perto(sala: Node3D, onde: Vector3) -> String:
	var melhor := ""
	var menor := INF
	for qual in ["cama", "bau"]:
		var ponto := _ponto(sala, qual)
		var d := Vector2(onde.x - ponto.x, onde.z - ponto.z).length()
		if d <= ALCANCE and d < menor:
			menor = d
			melhor = qual
	return melhor


func _acao(qual: String) -> String:
	return tr("Dormir") if qual == "cama" else tr("Baú")


func _unhandled_key_input(event: InputEvent) -> void:
	if _perto == "" or _ocupado:
		return
	if not (event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == Atalhos.tecla("interagir")):
		return
	# COM O CORPO PARADO, O E NÃO VALE PARA O MUNDO, como nos marcos: este nó
	# ouve no _unhandled_key_input, ANTES das telas que ouvem no
	# _unhandled_input (o cartão do amanhecer, o folheto).
	if Dialogo.ocupado() or not _jogador.is_physics_processing():
		return
	get_viewport().set_input_as_handled()
	usar(_perto)


## Usar a cama ou o baú. Corrotina: a cama espera a resposta e a noite.
func usar(qual: String) -> void:
	if _ocupado:
		return
	_ocupado = true
	_dica.visible = false
	match qual:
		"cama":
			var cama: Dictionary = _textos.get("cama", {})
			var pergunta := str(IdiomaMenu.campo(cama, "pergunta", "%s.\nDormir até o amanhecer?")) % Relogio.texto()
			var sim: bool = await Dialogo.perguntar(str(IdiomaMenu.campo(cama, "titulo", "Cama")), pergunta)
			if sim and _noite != null:
				await _noite.dormir_na_cama()
		"bau":
			# PELO DONO DAS TELAS, como a mochila do I: é ele que para o vale e
			# solta o cursor do mouse para clicar e arrastar entre o baú e a
			# mochila. Aberta direto, a tela vinha com o cursor preso na câmera.
			var titulo := str(IdiomaMenu.campo(_textos.get("bau", {}), "titulo", "Baú da casa"))
			var abrir_o_bau := func() -> void: Mochila.abrir_bau(bau, BAU_CABE, titulo)
			var telas: Node = get_parent().get_node_or_null("TelasDoVale") if get_parent() != null else null
			if telas != null and telas.has_method("abrir_por"):
				telas.abrir_por("mochila", abrir_o_bau)
			else:
				abrir_o_bau.call()
	_ocupado = false


## A COMIDA DA CASA: a partida nova acha dois beijus no baú, como no 2D. Uma vez
## só — a partida carregada traz o baú como ele estava.
func _por_a_comida_da_casa() -> void:
	if _comida_posta:
		return
	_comida_posta = true
	bau.append({"id": COMIDA_DA_CASA, "qtd": COMIDA_QUANTOS})
	for id in DO_FINADO:
		bau.append({"id": id, "qtd": int(DO_FINADO[id])})


func estado_para_salvar() -> Dictionary:
	return {"bau": bau.duplicate(true), "comida_posta": _comida_posta}


## O baú volta como estava. O Array é o mesmo, esvaziado e cheio de novo: a
## tela da mochila pode estar segurando a referência dele.
func restaurar(estado: Dictionary) -> void:
	bau.clear()
	for monte in estado.get("bau", []):
		if monte is Dictionary and str(monte.get("id", "")) != "":
			bau.append({"id": str(monte["id"]), "qtd": int(monte.get("qtd", 1))})
	_comida_posta = bool(estado.get("comida_posta", true))
