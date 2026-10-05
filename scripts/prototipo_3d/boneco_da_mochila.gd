extends Control
## O BONECO DA MOCHILA: o personagem em 3D ao lado dos encaixes, vestido com o
## que está neles e na mão.
##
## "No inventário, ao lado dos itens equipados, coloque o 3D do boneco com os
## itens equipados, igual nos jogos de RPG. Assim ele pode ver as alterações
## conforme vai equipando."
##
## A mochila é tela do 2D (`scripts/ui/mochila.gd`), e o vale não mexe nela: o
## boneco entra nela daqui (`montar`), no alto da coluna dos efeitos — logo à
## direita dos encaixes, com o que faz efeito no corpo embaixo dele, como a
## ficha do personagem nos RPGs. Ao lado, e não numa coluna nova: a mochila já
## passava dos 640 de largura do quadro do 2D, e uma coluna a mais a cortava
## nas bordas da tela. Ele é um palco à parte — um SubViewport com mundo, luz e câmera
## próprios — com o mesmo corpo do jogador (a mesma cena, o mesmo transform e
## os mesmos materiais de dois lados) parado no idle, e veste pelo mesmo
## caminho do jogador (`Vestimenta3D`): o boneco nunca mostra o que o corpo no
## vale não mostra.
##
## Arrastar com o mouse por cima dele gira o corpo; soltar em cima dele uma
## peça arrastada da mochila veste a peça no encaixe dela, como nos RPGs. Só
## desenha com a mochila aberta: fechada, o palco não renderiza. Com o baú
## aberto, que é tela de transferir, o boneco sai: as duas fileiras do baú em
## cima, mais ele e os efeitos, passavam da altura da tela.

const Vestimenta3D = preload("res://scripts/prototipo_3d/vestimenta_3d.gd")
const AuthoredAnimator = preload("res://scripts/prototipo_3d/authored_animator.gd")

## O tamanho no quadro de 640×360 da mochila: da altura da coluna dos cinco
## encaixes (5 × 28 + 4 × 3).
const LARGURA := 108.0
const ALTURA := 152.0
## O palco renderiza no dobro: a mochila é escalada 1,8× no vale, e o boneco
## não pode sair borrado.
const RESOLUCAO := 2
## Três quartos, como nos RPGs: o corpo quase de frente, com o lado da mão
## direita à vista.
const GIRO_INICIAL := -0.45
const GIRO_POR_PIXEL := 0.012
const CAMPO := 28.0
const COR_DA_MOLDURA := Color(0.5, 0.42, 0.28)

var palco: SubViewport
## O pivô que gira (o "visual" do jogador), com o modelo dentro.
var corpo: Node3D
var modelo: Node3D
var animador: Node
var camera: Camera3D
## O que o boneco está vestindo agora, como o `Vestimenta3D` diz.
var vestido_na_mao := ""
var vestido_na_cabeca := ""
var vestido_nas_maos := ""
var giro := GIRO_INICIAL

var _mochila
var _jogador
var _altura := 1.78
var _anexos: Array[Node] = []
var _arrastando := false
## O espaço da mochila de onde começou um arrasto (para vestir ao soltar no
## boneco), ou -1.
var _arrastado_de := -1
var _precisa_vestir := true
## A âncora e o pivô da ferramenta na mão (o machado ou o facão), para o
## balanço de parado.
var _ancora_do_machado: Node3D
var _pivo_do_machado: Node3D


## Põe o boneco na mochila, no alto da coluna dos efeitos (à direita dos
## encaixes), com o corpo do `jogador`.
func montar(mochila, jogador) -> void:
	_mochila = mochila
	_jogador = jogador
	_altura = float(jogador.get("character_height")) if jogador.get("character_height") != null else 1.78
	name = "BonecoDaMochila"
	process_mode = Node.PROCESS_MODE_ALWAYS
	custom_minimum_size = Vector2(LARGURA, ALTURA)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var efeitos: Control = mochila.get("_efeitos")
	var fileira := efeitos.get_parent()
	# Uma partida nova (de volta do menu) monta outro: o de antes sai.
	for velho in fileira.get_children():
		if velho != self and str(velho.name).begins_with("BonecoDaMochila"):
			fileira.remove_child(velho)
			velho.queue_free()
	fileira.add_child(self)
	fileira.move_child(self, 0)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	var moldura := Panel.new()
	moldura.set_anchors_preset(Control.PRESET_FULL_RECT)
	moldura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.06, 0.05, 0.04, 0.55)
	estilo.border_color = COR_DA_MOLDURA
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(2)
	moldura.add_theme_stylebox_override("panel", estilo)
	add_child(moldura)

	palco = SubViewport.new()
	palco.name = "Palco"
	palco.own_world_3d = true
	palco.transparent_bg = true
	palco.msaa_3d = Viewport.MSAA_4X
	palco.size = Vector2i(int(LARGURA) * RESOLUCAO, int(ALTURA) * RESOLUCAO)
	palco.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(palco)
	var tela := TextureRect.new()
	tela.name = "Tela"
	tela.texture = palco.get_texture()
	tela.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tela.stretch_mode = TextureRect.STRETCH_SCALE
	tela.set_anchors_preset(Control.PRESET_FULL_RECT)
	tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tela)

	_montar_o_palco()
	var vidro: Control = mochila.get("_vidro")
	if vidro != null and not vidro.gui_input.is_connected(_no_vidro):
		vidro.gui_input.connect(_no_vidro)
	if not Equipamento.mudou.is_connected(_pedir_para_vestir):
		Equipamento.mudou.connect(_pedir_para_vestir)
	if not Inventario.mudou.is_connected(_pedir_para_vestir):
		Inventario.mudou.connect(_pedir_para_vestir)


func _montar_o_palco() -> void:
	var mundo := Node3D.new()
	mundo.name = "Mundo"
	palco.add_child(mundo)
	var ambiente := WorldEnvironment.new()
	var ceu := Environment.new()
	ceu.background_mode = Environment.BG_CLEAR_COLOR
	ceu.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ceu.ambient_light_color = Color(0.62, 0.57, 0.50)
	ceu.ambient_light_energy = 0.6
	ceu.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	ambiente.environment = ceu
	mundo.add_child(ambiente)
	_luz(mundo, Vector3(-1.6, 2.4, 2.6), 1.2, Color(1.0, 0.93, 0.82))
	_luz(mundo, Vector3(2.0, 0.8, 1.4), 0.4, Color(0.80, 0.86, 1.0))
	_luz(mundo, Vector3(0.6, 1.8, -2.4), 0.8, Color(1.0, 0.86, 0.62))

	corpo = Node3D.new()
	corpo.name = "Corpo"
	corpo.rotation.y = giro
	mundo.add_child(corpo)
	_montar_o_modelo()

	camera = Camera3D.new()
	camera.fov = CAMPO
	camera.near = 0.05
	camera.far = 30.0
	mundo.add_child(camera)
	# O corpo inteiro, com o chapéu e uma folga embaixo dos pés.
	var meio := _altura * 0.52
	var distancia := (_altura * 0.62) / tan(deg_to_rad(CAMPO * 0.5))
	camera.position = Vector3(0.0, meio + 0.06, distancia)
	camera.look_at(Vector3(0.0, meio, 0.0), Vector3.UP)
	camera.current = true


func _luz(mundo: Node3D, de_onde: Vector3, forca: float, cor: Color) -> void:
	var luz := DirectionalLight3D.new()
	luz.light_energy = forca
	luz.light_color = cor
	mundo.add_child(luz)
	luz.look_at_from_position(de_onde, Vector3(0.0, _altura * 0.5, 0.0), Vector3.UP)


## O MESMO CORPO DO JOGADOR: o boneco procedural no estilo procedural; no Tripo,
## a mesma cena que o jogador carregou, com o transform e os materiais dele (os
## de dois lados, que o jogador acerta para o torso não sumir).
func _montar_o_modelo() -> void:
	var do_jogador: Node3D = _jogador.get("model") if _jogador != null else null
	if do_jogador is PersonagemProcedural or (do_jogador == null and Estilo.procedural()):
		var procedural := PersonagemProcedural.novo("viajante", _altura)
		corpo.add_child(procedural)
		modelo = procedural
		animador = procedural
		return
	if do_jogador == null or do_jogador.scene_file_path == "":
		return
	var cena := load(do_jogador.scene_file_path) as PackedScene
	if cena == null:
		return
	modelo = cena.instantiate() as Node3D
	corpo.add_child(modelo)
	modelo.transform = do_jogador.transform
	_copiar_materiais(do_jogador, modelo)
	var autoral := AuthoredAnimator.new()
	autoral.name = "Animador"
	add_child(autoral)
	if autoral.configure(modelo):
		animador = autoral
	else:
		autoral.queue_free()


static func _copiar_materiais(de: Node3D, para: Node3D) -> void:
	for encontrado in de.find_children("*", "MeshInstance3D", true, false):
		var malha := encontrado as MeshInstance3D
		var outra := para.get_node_or_null(de.get_path_to(malha)) as MeshInstance3D
		if outra == null:
			continue
		for i in malha.get_surface_override_material_count():
			var material := malha.get_surface_override_material(i)
			if material != null and i < outra.get_surface_override_material_count():
				outra.set_surface_override_material(i, material)


func _pedir_para_vestir() -> void:
	_precisa_vestir = true


func _process(delta: float) -> void:
	if not is_instance_valid(_jogador):
		queue_free()
		return
	var com_bau := _mochila != null and int(_mochila.get("_bau_cabe")) > 0
	visible = not com_bau
	var aberta: bool = _mochila != null and bool(_mochila.get("aberta")) and _mochila.visible and not com_bau
	palco.render_target_update_mode = SubViewport.UPDATE_ALWAYS if aberta else SubViewport.UPDATE_DISABLED
	if not aberta:
		_arrastando = false
		return
	corpo.rotation.y = giro
	if animador is PersonagemProcedural:
		animador.update_motion(0.0, delta)
	# Veste com o corpo já no idle: o machado se acerta pela pose da mão.
	if _precisa_vestir:
		_precisa_vestir = false
		vestir()
	# A peça na pose de parado dela (`Vestimenta3D.pose_de`): o machado a -30°, a
	# vara erguida, o balde em pé — a mesma do jogador parado.
	if is_instance_valid(_pivo_do_machado) and is_instance_valid(_ancora_do_machado):
		Vestimenta3D.posar(_ancora_do_machado, _pivo_do_machado, corpo, Vestimenta3D.pose_de(vestido_na_mao, "parado"))


## VESTE O BONECO com o que o corpo mostra agora (`Vestimenta3D`): o chapéu na
## cabeça, as luvas nas mãos e, na mão, o que a barra escolheu. Só refaz o que mudou.
func vestir() -> void:
	var na_mao := Vestimenta3D.item_na_mao()
	var na_cabeca := Vestimenta3D.item_na_cabeca()
	var nas_maos := Vestimenta3D.item_nas_maos()
	if na_mao == vestido_na_mao and na_cabeca == vestido_na_cabeca and nas_maos == vestido_nas_maos and _anexos.all(func(a) -> bool: return is_instance_valid(a)):
		return
	for anexo in _anexos:
		if is_instance_valid(anexo):
			anexo.get_parent().remove_child(anexo)
			anexo.queue_free()
	_anexos.clear()
	vestido_na_mao = na_mao
	vestido_na_cabeca = na_cabeca
	vestido_nas_maos = nas_maos
	if modelo == null:
		return
	if nas_maos != "":
		for ancora in Vestimenta3D.luvas(modelo, nas_maos):
			_anexos.append(_raiz(ancora))
	if na_cabeca != "":
		var cabeca := Vestimenta3D.ancora_da_cabeca(modelo)
		if cabeca != null:
			Vestimenta3D.na_cabeca(cabeca, na_cabeca)
			_anexos.append(_raiz(cabeca))
	if na_mao != "":
		var mao := Vestimenta3D.ancora_da_mao(modelo, _altura, corpo, Vestimenta3D.nome_da_ancora(na_mao))
		if mao != null:
			_ancora_do_machado = mao
			_pivo_do_machado = Vestimenta3D.na_mao(mao, corpo, na_mao)
			_anexos.append(_raiz(mao))


## O nó a tirar quando a peça sai: o anexo do osso, se a âncora está num.
func _raiz(ancora: Node3D) -> Node:
	return ancora.get_parent() if ancora.get_parent() is BoneAttachment3D else ancora


## AS PEÇAS QUE O BONECO VESTE AGORA: o "peca" de cada uma ("chapeu",
## "machado", "facao"). É o que o portão pergunta.
func pecas_vestidas() -> Array[String]:
	var lista: Array[String] = []
	if modelo == null:
		return lista
	for no in modelo.find_children("*", "Node3D", true, false):
		if no.has_meta("peca") and is_instance_valid(no) and not no.is_queued_for_deletion():
			lista.append(str(no.get_meta("peca")))
	return lista


## O MOUSE, pela folha de vidro da mochila (é ela que recebe o ponteiro):
## arrastar por cima do boneco gira o corpo; soltar nele uma peça que veio
## arrastada da mochila veste a peça no encaixe dela.
func _no_vidro(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and (evento as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var botao := evento as InputEventMouseButton
		var em_mim := get_global_rect().has_point(botao.position)
		if botao.pressed:
			_arrastando = em_mim
			_arrastado_de = _espaco_da_mochila(botao.position)
			return
		if em_mim and _arrastado_de >= 0 and _arrastado_de < Inventario.ESPACOS:
			var id := str((Inventario.espacos[_arrastado_de] as Dictionary).get("id", ""))
			if id != "" and Equipamento.encaixe_de(id) != "":
				if Equipamento.equipar_do_espaco(_arrastado_de):
					Audio.efeito("menu_confirma")
		_arrastando = false
		_arrastado_de = -1
	elif evento is InputEventMouseMotion and _arrastando:
		giro += (evento as InputEventMouseMotion).relative.x * GIRO_POR_PIXEL


## Qual espaço da mochila (só a grade, não os encaixes nem o baú) está debaixo
## do ponteiro, ou -1.
func _espaco_da_mochila(onde: Vector2) -> int:
	var molduras: Array = _mochila.get("_molduras") if _mochila != null else []
	for i in mini(molduras.size(), Inventario.ESPACOS):
		if (molduras[i] as Control).get_global_rect().has_point(onde):
			return i
	return -1
