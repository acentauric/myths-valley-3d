class_name ReacoesVisuais
extends RefCounted
## AS REAÇÕES VISUAIS DO GOLPE (#16): as lascas que saltam do alvo e a sacudida da tela.
##
## No 2D, o `Efeitos` fazia a partícula e o tranco da tela. No 3D o nome `Efeitos` é dos efeitos
## temporários (bênção, comida), e as reações visuais moram aqui: duas funções estáticas, sem
## estado, que quem bate chama no impacto. O alvo já dá o tranco dele (`recursos_3d._sacudir`);
## aqui entram o que sai dele (lascas) e o que o jogador sente (a câmera).
##
## - `lascas`: uma rajada única de cubinhos na cor do material (pedra, madeira, folha, concha,
##   poeira). Nasce no ponto do golpe, cai com a gravidade e some sozinha; o último golpe solta o
##   dobro. Não deixa nó para trás: o emissor se livra no fim do tempo de vida.
## - `sacudir_tela`: desloca o quadro da câmera (`h_offset`/`v_offset`, que não mexem na posição
##   nem na colisão dela) e volta a zero. Quem tem o "movimento reduzido" ligado (`Jogo.movimento_reduzido`, ainda sem chave nos Ajustes) não tem
##   sacudida (e as lascas ficam mais poucas).

## Cor de cada material das lascas.
const CORES := {
	"pedra": Color(0.62, 0.6, 0.56),
	"madeira": Color(0.5, 0.34, 0.18),
	"folha": Color(0.32, 0.52, 0.22),
	"concha": Color(0.86, 0.82, 0.74),
	"poeira": Color(0.72, 0.64, 0.5),
}
## Material de cada ferramenta (e do que ela rende), como a tabela de sons do golpe a lê.
const MATERIAL_DA_FERRAMENTA := {
	"picareta": "pedra",
	"machado": "madeira",
	"foice": "folha",
	"/ostra": "concha",
	"/lenha": "madeira",
	"": "poeira",
}

const LASCAS_POR_GOLPE := 10
const LASCAS_NO_ULTIMO := 20
## Tempo de vida de cada lasca (s), tamanho (m) e a velocidade de saída (m/s).
const VIDA := 0.7
const TAMANHO := 0.06
const VELOCIDADE_MIN := 1.4
const VELOCIDADE_MAX := 3.2

## Sacudida da tela em metros de quadro (offset da câmera). Pequena: um tranco, e não um terremoto.
const FORCA_DO_GOLPE := 0.025
const FORCA_DO_ULTIMO := 0.06
const DURACAO_DO_GOLPE := 0.14
const DURACAO_DO_ULTIMO := 0.28
const META_DA_SACUDIDA := "sacudida_da_tela"


## O material das lascas desta ficha: a ferramenta e o que rende, na mesma ordem da tabela de sons.
static func material_do_golpe(ficha: Dictionary) -> String:
	var ferramenta := str(ficha.get("ferramenta", ""))
	for chave in ["%s/%s" % [ferramenta, str(ficha.get("rende", ""))], ferramenta]:
		if MATERIAL_DA_FERRAMENTA.has(chave):
			return str(MATERIAL_DA_FERRAMENTA[chave])
	return "poeira"


## Quantas lascas saem num golpe (menos com o movimento reduzido).
static func quantas_lascas(ultimo: bool) -> int:
	var n := LASCAS_NO_ULTIMO if ultimo else LASCAS_POR_GOLPE
	return maxi(3, int(n / 3.0)) if _movimento_reduzido() else n


## Solta as lascas em `ponto` (global), como filha de `pai`. Devolve o emissor, ou null se não há onde pôr.
static func lascas(pai: Node, ponto: Vector3, material: String, ultimo: bool = false) -> CPUParticles3D:
	if pai == null or not is_instance_valid(pai) or not pai.is_inside_tree():
		return null
	var emissor := CPUParticles3D.new()
	emissor.name = "LascasDoGolpe"
	emissor.top_level = true
	emissor.one_shot = true
	emissor.explosiveness = 1.0
	emissor.amount = quantas_lascas(ultimo)
	emissor.lifetime = VIDA
	emissor.local_coords = false
	emissor.direction = Vector3.UP
	emissor.spread = 70.0
	emissor.gravity = Vector3(0.0, -9.0, 0.0)
	emissor.initial_velocity_min = VELOCIDADE_MIN
	emissor.initial_velocity_max = VELOCIDADE_MAX
	emissor.angular_velocity_min = -360.0
	emissor.angular_velocity_max = 360.0
	emissor.scale_amount_min = 0.6
	emissor.scale_amount_max = 1.2
	emissor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cubo := BoxMesh.new()
	cubo.size = Vector3.ONE * TAMANHO
	var tinta := StandardMaterial3D.new()
	tinta.albedo_color = Color(CORES.get(material, CORES["poeira"]))
	tinta.roughness = 1.0
	cubo.material = tinta
	emissor.mesh = cubo
	pai.add_child(emissor)
	emissor.global_position = ponto
	emissor.emitting = true
	# Se livra sozinha quando a última lasca some, sem deixar nó parado no vale.
	pai.get_tree().create_timer(VIDA + 0.4).timeout.connect(func() -> void:
		if is_instance_valid(emissor):
			emissor.queue_free())
	return emissor


## Um tranco no quadro da câmera: `forca` em metros de offset, `duracao` em segundos. Uma sacudida nova
## troca a anterior (não se somam). Sem efeito com o movimento reduzido. Devolve se sacudiu.
static func sacudir_tela(camera: Camera3D, forca: float, duracao: float) -> bool:
	if camera == null or not is_instance_valid(camera) or not camera.is_inside_tree():
		return false
	if _movimento_reduzido() or forca <= 0.0 or duracao <= 0.0:
		return false
	if camera.has_meta(META_DA_SACUDIDA):
		var anterior = camera.get_meta(META_DA_SACUDIDA)
		if anterior is Tween and (anterior as Tween).is_valid():
			(anterior as Tween).kill()
	var tween := camera.create_tween()
	camera.set_meta(META_DA_SACUDIDA, tween)
	tween.tween_method(_passo_da_sacudida.bind(camera, forca), 1.0, 0.0, duracao)
	tween.tween_callback(_encerrar_sacudida.bind(camera))
	return true


## Um passo: o deslocamento sorteado, escalado pelo que resta da sacudida (1 → 0).
static func _passo_da_sacudida(resta: float, camera: Camera3D, forca: float) -> void:
	if not is_instance_valid(camera):
		return
	camera.h_offset = randf_range(-1.0, 1.0) * forca * resta
	camera.v_offset = randf_range(-1.0, 1.0) * forca * resta


static func _encerrar_sacudida(camera: Camera3D) -> void:
	if not is_instance_valid(camera):
		return
	camera.h_offset = 0.0
	camera.v_offset = 0.0
	if camera.has_meta(META_DA_SACUDIDA):
		camera.remove_meta(META_DA_SACUDIDA)


## As duas reações de um golpe que acertou: lascas no ponto e o tranco da tela.
static func golpe(pai: Node, ponto: Vector3, ficha: Dictionary, camera: Camera3D, ultimo: bool) -> void:
	lascas(pai, ponto, material_do_golpe(ficha), ultimo)
	sacudir_tela(camera, FORCA_DO_ULTIMO if ultimo else FORCA_DO_GOLPE,
		DURACAO_DO_ULTIMO if ultimo else DURACAO_DO_GOLPE)


static func _movimento_reduzido() -> bool:
	var arvore := Engine.get_main_loop() as SceneTree
	if arvore == null:
		return false
	var jogo := arvore.root.get_node_or_null("Jogo")
	return jogo != null and bool(jogo.get("movimento_reduzido"))
