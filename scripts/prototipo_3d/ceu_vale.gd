extends RefCounted
## O CÉU DO VALE: o céu pintado por shader próprio (ceu_vale.gdshader), o sol, a lua e a
## névoa que dissolve o longe no horizonte. world_builder._build_lighting monta, e
## world_builder._aplicar_hora chama aplicar(hora) a cada quadro.
##
## "O jogo não tem céu, nuvens nem horizonte." Era um ProceduralSkyMaterial de topo
## verde-acinzentado e horizonte bege, sem nuvem, sol sem disco, e uma névoa do mesmo
## bege: o mar ao longe, o horizonte e a serra viravam uma faixa só. Agora o céu tem
## degradê cobalto, sol e lua com disco, estrelas e Via Láctea girando com a hora,
## cúmulos de tempo bom e cirros que o alísio leva devagar, e a outra margem da baía.
##
## A NÉVOA TIRA A COR DO CÉU (perspectiva aérea): cada pixel distante se mistura com o
## céu atrás dele, então o mar converge para o azul que o céu pinta abaixo do horizonte,
## e a serra se dissolve na bruma, alaranjada do lado do sol. É ela que resolve a
## "montanha pelada": a mata some por bloco a 280 u (LOD_MATA), e ali a névoa já pesa.
##
## A REGRA DA NÉVOA (portão tests/ceu_horizonte.gd), em qualquer hora: a 280 u, entre
## 22% e 45% (o corte da mata não aparece, e o vale não vira sopa); a 2 800 u, o far
## do jogador, 94% ou mais; a 4 400 u, a borda do mar vista do menu, 98% ou mais.
##
## Na alvorada, uma neblina de baixada deita sobre o mar e o mangue (névoa de altura);
## o Mirante fica acima dela. Nada de partícula: tudo é shader e Environment.

const SHADER := preload("res://assets/prototipo_3d/ceu/ceu_vale.gdshader")

## Densidade da névoa exponencial (/u) por período.
const DENSIDADE_DIA := 0.0011
const DENSIDADE_DOURADA := 0.0016
const DENSIDADE_NOITE := 0.0020
## Espalhamento do sol na névoa: discreto de dia, forte na hora dourada.
const ESPALHAMENTO_DIA := 0.08
const ESPALHAMENTO_DOURADO := 0.35
## Neblina de baixada: topo (u acima do chão zero) e densidade no pico, às 5h45.
const NEBLINA_ALTURA := 2.5
const NEBLINA_DENSIDADE := 0.15
const NEBLINA_PICO := 5.75
const NEBLINA_FIM := 7.25
const NEBLINA_INICIO := 3.5

## Paleta (AMBIENTACAO §7): cobalto suave de dia, sem ciano; azul-marinho à noite;
## latão e telha no entardecer.
const ZENITE_DIA := Color("4b78b8")
const HORIZONTE_DIA := Color("c3d2de")
const MAR_DIA := Color("5f8199")
const ZENITE_DOURADO := Color("4a5c95")
const HORIZONTE_ROSADO := Color("c9a3a0")
const BRILHO_ALTO := Color("f4bf6e")
const BRILHO_BAIXO := Color("d9683c")
const ZENITE_NOITE := Color("0b1327")
const HORIZONTE_NOITE := Color("22304a")
const MAR_NOITE := Color("0c1424")
## Cobertura dos cúmulos: tempo bom, céu mais de meio limpo.
const COBERTURA := 0.36

var ambiente: Environment
var material: ShaderMaterial
var sol: DirectionalLight3D
var lua: DirectionalLight3D
## Os nós que o céu pôs no mundo (o portão confere que nenhum é partícula).
var nos: Array[Node] = []

static var _ruido: Texture2D


## Põe o ambiente, o sol e a lua como filhos de `pai`, com os nomes de sempre.
func montar(pai: Node3D) -> void:
	material = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("ruido", textura_ruido())
	material.set_shader_parameter("cobertura", COBERTURA)
	var ceu := Sky.new()
	ceu.sky_material = material
	# Nuvens andam com TIME: o reflexo (radiance) acompanha em tempo real, que pede 256.
	ceu.process_mode = Sky.PROCESS_MODE_REALTIME
	ceu.radiance_size = Sky.RADIANCE_SIZE_256
	ambiente = Environment.new()
	ambiente.background_mode = Environment.BG_SKY
	ambiente.sky = ceu
	ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	ambiente.fog_enabled = true
	ambiente.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	ambiente.fog_aerial_perspective = 1.0
	ambiente.fog_sky_affect = 0.0
	ambiente.fog_height = NEBLINA_ALTURA
	var mundo := WorldEnvironment.new()
	mundo.environment = ambiente
	pai.add_child(mundo)
	sol = DirectionalLight3D.new()
	sol.name = "Sol"
	sol.shadow_enabled = true
	sol.directional_shadow_max_distance = 180.0
	sol.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	pai.add_child(sol)
	lua = DirectionalLight3D.new()
	lua.name = "Lua"
	lua.light_color = Color("9fb3d6")
	lua.shadow_enabled = false
	pai.add_child(lua)
	nos.assign([mundo, sol, lua])


## Curvas de cor por hora: madrugada azul, alvorada rosada, meio-dia cobalto,
## entardecer dourado, noite estrelada.
func aplicar(hora: float) -> void:
	var luz := Dia.luz_do_dia()
	var elevacao := Dia.elevacao_solar()
	var horizonte := 1.0 - smoothstep(6.0, 22.0, absf(elevacao))
	# Crepúsculo do céu: vai além do pôr (o brilho fica até o sol descer ~12°).
	var crepusculo := smoothstep(-13.0, -1.0, elevacao) * (1.0 - smoothstep(3.0, 18.0, elevacao))
	var para_o_sol := -Dia.direcao_da_luz_solar()
	# Sol na posição real do lugar (Dia.direcao_da_luz_solar): nasce a leste, culmina ao
	# norte e se põe a oeste. Perto do horizonte a LUZ fica em ~2° para não varar o chão;
	# o disco no céu segue a posição de verdade.
	var luz_solar := -para_o_sol
	if luz_solar.y > -0.035:
		luz_solar = Vector3(luz_solar.x, 0.0, luz_solar.z).normalized() * cos(0.035) + Vector3(0.0, -0.035, 0.0)
	sol.basis = Basis.looking_at(luz_solar, Vector3.UP if absf(luz_solar.y) < 0.99 else Vector3.FORWARD)
	sol.light_energy = lerpf(0.0, 1.15, luz)
	sol.light_color = Color("fff0d0").lerp(Color("ff9d5c"), horizonte * 0.85)
	sol.visible = luz > 0.02
	# Lua alta, do lado oposto ao sol.
	var horizontal := Vector3(-luz_solar.x, 0.0, -luz_solar.z).normalized()
	var luz_lunar := horizontal * cos(deg_to_rad(52.0)) + Vector3(0.0, -sin(deg_to_rad(52.0)), 0.0)
	lua.basis = Basis.looking_at(luz_lunar, Vector3.UP)
	lua.light_energy = lerpf(0.26, 0.0, luz)
	lua.visible = luz < 0.98

	var noite := 1.0 - luz
	var zenite := ZENITE_DIA.lerp(ZENITE_NOITE, noite).lerp(ZENITE_DOURADO, crepusculo * luz * 0.55)
	var horizonte_cor := HORIZONTE_DIA.lerp(HORIZONTE_NOITE, noite)
	horizonte_cor = horizonte_cor.lerp(HORIZONTE_ROSADO.lerp(HORIZONTE_NOITE, noite * 0.6), crepusculo * 0.55)
	var brilho := BRILHO_ALTO.lerp(BRILHO_BAIXO, smoothstep(8.0, -5.0, elevacao))
	brilho = brilho.lerp(HORIZONTE_NOITE, smoothstep(-6.0, -13.0, elevacao))
	var mar := MAR_DIA.lerp(MAR_NOITE, noite).lerp(horizonte_cor * 0.72, crepusculo * 0.3)
	var cor_sol := Color("fff4dc").lerp(Color("ffb066"), horizonte)
	material.set_shader_parameter("sol_dir", para_o_sol)
	material.set_shader_parameter("lua_dir", -luz_lunar)
	material.set_shader_parameter("luz", luz)
	material.set_shader_parameter("horizonte", crepusculo)
	material.set_shader_parameter("cor_zenite", zenite)
	material.set_shader_parameter("cor_horizonte", horizonte_cor)
	material.set_shader_parameter("cor_sol", cor_sol)
	material.set_shader_parameter("cor_brilho", brilho)
	material.set_shader_parameter("cor_mar", mar)
	# Nuvem: branca ao sol, tingida no crepúsculo, cinza-azulada ao luar.
	var nuvem_luz := Color("fffaf2").lerp(brilho.lightened(0.25), crepusculo * 0.75).lerp(Color("2a3448"), smoothstep(0.35, 0.0, luz))
	var nuvem_sombra := zenite.lerp(horizonte_cor, 0.55).darkened(0.12).lerp(Color("141b2a"), smoothstep(0.3, 0.0, luz))
	material.set_shader_parameter("cor_nuvem_luz", nuvem_luz)
	material.set_shader_parameter("cor_nuvem_sombra", nuvem_sombra)
	material.set_shader_parameter("esfera_celeste", esfera_celeste(hora, Dia.latitude))

	ambiente.ambient_light_color = Color("cad9d5").lerp(Color("2b3454"), noite)
	ambiente.ambient_light_energy = lerpf(0.3, 0.65, luz)
	# Com a perspectiva aérea a cor vem do céu; esta só vale enquanto o reflexo não
	# ficou pronto, e é a do horizonte, não mais o bege de antes.
	ambiente.fog_light_color = horizonte_cor
	ambiente.fog_density = densidade_da_nevoa(luz, horizonte)
	ambiente.fog_sun_scatter = lerpf(ESPALHAMENTO_DIA, ESPALHAMENTO_DOURADO, horizonte * luz)
	ambiente.fog_height_density = NEBLINA_DENSIDADE * neblina_de_baixada(hora)


## Densidade por período: dia limpo, hora dourada mais carregada, noite mais fechada.
static func densidade_da_nevoa(luz: float, horizonte: float) -> float:
	return lerpf(DENSIDADE_NOITE, lerpf(DENSIDADE_DIA, DENSIDADE_DOURADA, horizonte), luz)


## Quanto da névoa exponencial cobre um ponto a `distancia` u.
static func nevoa_a(densidade: float, distancia: float) -> float:
	return 1.0 - exp(-densidade * distancia)


## Força da neblina de baixada (0–1): sobe na madrugada, pico às 5h45, some às 7h15.
static func neblina_de_baixada(hora: float) -> float:
	var h := fposmod(hora, 24.0)
	return smoothstep(NEBLINA_INICIO, NEBLINA_PICO, h) * (1.0 - smoothstep(NEBLINA_PICO, NEBLINA_FIM, h))


## Do mundo (x leste, y para cima, z sul) para a esfera celeste (x no equinócio de
## março, z no polo norte celeste). O tempo sideral sai da hora solar do lugar e da
## ascensão reta do sol no dia do jogo (Dia.DIA_DO_ANO).
static func esfera_celeste(hora: float, latitude: float) -> Basis:
	var ascensao_do_sol := fposmod((270.0 - 80.0) * 24.0 / 365.25, 24.0)
	var sideral := deg_to_rad(15.0 * (hora - 12.0 + ascensao_do_sol))
	var fi := deg_to_rad(latitude)
	var cima := Vector3.UP
	var norte := Vector3(0.0, 0.0, -1.0)
	var leste := Vector3.RIGHT
	var polo := cima * sin(fi) + norte * cos(fi)
	var equador := cima * cos(fi) - norte * sin(fi)
	var para_o_mundo := Basis(equador * cos(sideral) - leste * sin(sideral),
		equador * sin(sideral) + leste * cos(sideral), polo)
	return para_o_mundo.transposed()


## Ruído sem emenda do céu, gerado na hora (não em thread): um quadro com textura vazia
## pintaria o céu inteiro de nuvem.
static func textura_ruido() -> Texture2D:
	if _ruido != null:
		return _ruido
	var ruido := FastNoiseLite.new()
	ruido.seed = hash("ceu_vale")
	ruido.frequency = 0.022
	ruido.fractal_octaves = 5
	var imagem := ruido.get_seamless_image(384, 384, false, false, 0.1, true)
	imagem.convert(Image.FORMAT_L8)
	imagem.generate_mipmaps()
	_ruido = ImageTexture.create_from_image(imagem)
	return _ruido
