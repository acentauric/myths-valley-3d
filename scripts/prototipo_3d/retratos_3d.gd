extends Node
## OS RETRATOS DO ARRAIAL, tirados do MODELO 3D de cada morador.
##
## "O MENU social ficou ótimo, agora será que é possível usar a foto do rosto
## já no modelo 3D ao invés do 2D?" A tela do arraial usava o primeiro quadro
## da folha de sprites do jogo 2D — um boneco de 48 px que não se parece com
## quem anda no vale. O retrato agora é do próprio morador do vale: o mesmo
## modelo, de rosto e ombros.
##
##
## COMO A FOTO É TIRADA
##
## Um estúdio por retrato: um SubViewport com MUNDO PRÓPRIO (`own_world_3d`),
## para o sol, a névoa e a hora do vale não entrarem na foto; o modelo do
## morador instanciado do mesmo jeito que o `npc.gd` o instancia; o clipe
## "idle" posto no primeiro meio segundo, porque o rig em descanso é a pose em
## T; e três luzes de estúdio — a principal da frente e de cima, a de
## preenchimento do outro lado e uma de recorte atrás. A câmera mira a cabeça
## (o osso "head" do rig, ou o alto da caixa do modelo) de três quartos, com lente longa para o rosto não se deformar.
##
## Um quadro desenhado, a imagem copiada para uma `ImageTexture`, e o estúdio é
## desmontado. Os retratos ficam guardados por id enquanto o vale existir;
## trocar o estilo recarrega o vale, e com ele o estúdio.
##
## SEM PLACA DE VÍDEO NÃO HÁ FOTO. Rodando sem tela (os portões, `--headless`),
## o servidor de desenho é de mentira e a imagem sai vazia: o estúdio nem
## monta, e quem pede o retrato continua com o desenho 2D, que é a reserva.

## Um retrato ficou pronto. Quem mostra retrato (a tela do arraial, o diário)
## se refaz para trocar o desenho 2D pela foto.
signal pronto(id: String, textura: Texture2D)

const CatalogoAssets = preload("res://scripts/prototipo_3d/catalogo_assets.gd")

## O lado da foto, em pixels. A tela do arraial a mostra com 40 e com 88.
const LADO := 256
## Lente longa (graus de campo vertical): rosto sem nariz de grande-angular.
const CAMPO := 22.0
## Quanto do corpo entra, em altura: cabeça e ombros.
const ALTURA_DO_QUADRO := 0.46
## O giro de três quartos, em graus.
const GIRO := 24.0

var _texturas: Dictionary = {}
var _fila: Array[String] = []
var _trabalhando := false


func _ready() -> void:
	# A tela do arraial pausa o vale; a foto tem de sair assim mesmo.
	process_mode = Node.PROCESS_MODE_ALWAYS


## O retrato pronto deste morador, ou null enquanto não houver.
func textura(id: String) -> Texture2D:
	return _texturas.get(id, null)


## Põe na fila os que ainda não têm retrato. As fotos saem uma por quadro.
func pedir(ids: Array) -> void:
	if not sabe_fotografar():
		return
	for bruto in ids:
		var id := str(bruto)
		if id == "" or _texturas.has(id) or _fila.has(id):
			continue
		_fila.append(id)
	if not _trabalhando and not _fila.is_empty():
		_tirar_a_fila()


## Há placa de vídeo de verdade? Sem ela (headless) a foto sairia vazia.
static func sabe_fotografar() -> bool:
	return DisplayServer.get_name() != "headless"


func _tirar_a_fila() -> void:
	_trabalhando = true
	while not _fila.is_empty():
		var id: String = _fila.pop_front()
		var foto: Texture2D = await _fotografar(id)
		if foto != null:
			_texturas[id] = foto
			pronto.emit(id, foto)
	_trabalhando = false


func _fotografar(id: String) -> Texture2D:
	var estudio := SubViewport.new()
	estudio.name = "Estudio_" + id
	estudio.size = Vector2i(LADO, LADO)
	estudio.own_world_3d = true
	estudio.transparent_bg = true
	estudio.msaa_3d = Viewport.MSAA_4X
	estudio.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(estudio)

	var cena := Node3D.new()
	estudio.add_child(cena)
	var ambiente := WorldEnvironment.new()
	var ceu := Environment.new()
	ceu.background_mode = Environment.BG_CLEAR_COLOR
	ceu.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ceu.ambient_light_color = Color(0.62, 0.57, 0.50)
	ceu.ambient_light_energy = 0.55
	ceu.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	ambiente.environment = ceu
	cena.add_child(ambiente)

	var modelo := _montar_modelo(id, cena)
	if modelo == null:
		estudio.queue_free()
		return null
	_por_em_pe(modelo)
	# Um quadro para o esqueleto assentar a pose antes de medir a cabeça.
	await RenderingServer.frame_post_draw
	if not is_instance_valid(estudio):
		return null

	var cabeca := _cabeca(modelo)
	var altura := _altura(modelo)
	var distancia := (ALTURA_DO_QUADRO * altura / 1.7) * 0.5 / tan(deg_to_rad(CAMPO * 0.5))
	var giro := deg_to_rad(GIRO)
	var frente := Vector3(sin(giro), 0.0, cos(giro))
	var mira := cabeca + Vector3(0.0, -0.06 * altura / 1.7, 0.0)

	var camera := Camera3D.new()
	camera.fov = CAMPO
	camera.near = 0.02
	camera.far = 20.0
	cena.add_child(camera)
	camera.look_at_from_position(mira + frente * distancia + Vector3(0.0, 0.03, 0.0), mira, Vector3.UP)
	camera.current = true

	_luz(cena, mira, mira + Vector3(-1.4, 1.6, 2.2), 1.25, Color(1.0, 0.93, 0.82))
	_luz(cena, mira, mira + Vector3(1.8, 0.4, 1.2), 0.38, Color(0.80, 0.86, 1.0))
	_luz(cena, mira, mira + Vector3(0.6, 1.2, -2.0), 0.85, Color(1.0, 0.86, 0.62))

	# Dois quadros: o primeiro com a câmera nova, o segundo com certeza no alvo.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if not is_instance_valid(estudio):
		return null
	var imagem := estudio.get_texture().get_image()
	estudio.queue_free()
	if imagem == null or imagem.is_empty():
		return null
	imagem.generate_mipmaps()
	return ImageTexture.create_from_image(imagem)


## O mesmo modelo que o `npc.gd` monta. Quem ainda não tem modelo não tem
## retrato: o morador é a caixa cinza provisória (`npc.gd._corpo_provisorio`), e
## o diário mostra o nome sozinho.
func _montar_modelo(id: String, cena: Node3D) -> Node3D:
	return CatalogoAssets.instanciar(id, cena, Vector3.ZERO, 1.0)


## O clipe "idle" no primeiro meio segundo: em descanso, o rig do Tripo é a
## pose em T, e de braços abertos o retrato sai com os ombros cortados.
func _por_em_pe(modelo: Node3D) -> void:
	for no in modelo.find_children("*", "AnimationPlayer", true, false):
		var tocador := no as AnimationPlayer
		for nome: StringName in tocador.get_animation_list():
			var base := String(nome)
			if base.length() > 4 and base[base.length() - 4] == "_" and base.right(3).is_valid_int():
				base = base.left(base.length() - 4)
			if base == "idle":
				tocador.play(nome)
				tocador.seek(0.5, true)
				tocador.pause()
				return


## Onde está a cabeça: o osso "head" do rig, ou um palmo abaixo do alto do
## modelo.
func _cabeca(modelo: Node3D) -> Vector3:
	for no in modelo.find_children("*", "Skeleton3D", true, false):
		var esqueleto := no as Skeleton3D
		for i in esqueleto.get_bone_count():
			var nome := String(esqueleto.get_bone_name(i)).to_lower()
			if nome.ends_with("head") and not nome.ends_with("tophead"):
				var osso := esqueleto.global_transform * esqueleto.get_bone_global_pose(i)
				return osso.origin + Vector3(0.0, 0.08 * _altura(modelo) / 1.7, 0.0)
	var caixa := _caixa(modelo)
	return Vector3(caixa.get_center().x, caixa.end.y - 0.12 * caixa.size.y, caixa.get_center().z)


func _altura(modelo: Node3D) -> float:
	return maxf(_caixa(modelo).size.y, 0.5)


func _caixa(modelo: Node3D) -> AABB:
	var caixa := AABB()
	var primeira := true
	for no in modelo.find_children("*", "VisualInstance3D", true, false):
		var visual := no as VisualInstance3D
		var dela := visual.global_transform * visual.get_aabb()
		if primeira:
			caixa = dela
			primeira = false
		else:
			caixa = caixa.merge(dela)
	return caixa


func _luz(cena: Node3D, alvo: Vector3, de_onde: Vector3, forca: float, cor: Color) -> void:
	var luz := DirectionalLight3D.new()
	luz.light_energy = forca
	luz.light_color = cor
	cena.add_child(luz)
	luz.look_at_from_position(de_onde, alvo, Vector3.UP)
