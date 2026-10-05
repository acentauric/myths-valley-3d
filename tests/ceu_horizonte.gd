extends SceneTree
## O CÉU E O HORIZONTE: o céu é o do CeuVale (shader próprio, névoa que tira a cor do
## céu), a névoa segue a regra que esconde o corte da mata sem virar sopa, a baixada tem
## neblina na alvorada, o céu não tem partícula, e a terra além do quadro sobe com o mesmo
## exagero do relevo do jogo (sem o degrau na borda).
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/ceu_horizonte.gd
##
## A REGRA DA NÉVOA, em QUALQUER hora do dia: a 280 u (onde a mata some por bloco) entre
## 22% e 45%; a 2 800 u (o far do jogador) 94% ou mais; a 4 400 u (a borda do mar vista
## do menu) 98% ou mais.
##
## FALSIFICAÇÃO embutida: o degrau da borda é medido também com o exagero desligado
## (como o shader do leito era antes) e TEM de reprovar na mesma régua; se a régua não
## reprovar o defeito antigo, ela não vale nada e o portão falha.

## Carregados em _run, depois dos autoloads (Dia, Mare): um preload aqui compilaria
## ceu_vale.gd e mar.gd antes de eles existirem.
var CeuVale: GDScript
var Mar: GDScript

## Régua do degrau na borda: mediana da diferença de altura (u) entre o terreno do jogo,
## logo dentro do quadro, e o leito logo fora, em terra. Antes da correção: ~12 u.
const DEGRAU_MAXIMO := 3.0
const NEVOA_280 := Vector2(0.22, 0.45)
const NEVOA_2800 := 0.94
const NEVOA_4400 := 0.98

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _verificar(condicao: bool, descricao: String) -> void:
	if not condicao:
		falhas += 1
		push_error("CEU_FALHOU: " + descricao)
		print("FALHA: ", descricao)


func _run() -> void:
	CeuVale = load("res://scripts/prototipo_3d/ceu_vale.gd")
	Mar = load("res://scripts/prototipo_3d/mar.gd")
	_verificar(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(3)
	var mundo := get_first_node_in_group("mundo")
	_verificar(mundo != null, "o mundo existe")
	if mundo == null:
		_fim()
		return
	var dia := root.get_node("/root/Dia")
	dia.pausado = true
	var ceu = mundo.get("_ceu")
	_verificar(ceu != null, "o mundo monta o CeuVale")
	if ceu == null:
		_fim()
		return
	_verificar(mundo.get("_environment") == ceu.ambiente, "o Environment do mundo é o do CeuVale")
	_conferir_camadas(ceu)
	_conferir_nevoa(ceu, dia)
	_conferir_sol_e_lua(ceu, dia)
	_conferir_neblina(ceu, dia)
	_conferir_estrelas()
	_conferir_sem_particulas(ceu)
	_conferir_borda(mundo)
	_fim()


func _fim() -> void:
	print("CEU_HORIZONTE_OK: céu, névoa em todas as horas, neblina, estrelas e borda sem degrau" if falhas == 0 else "ceu_horizonte: Falhas: %d" % falhas)
	quit(1 if falhas else 0)


## Céu com shader próprio e névoa com perspectiva aérea (a cor vem do céu atrás do pixel).
func _conferir_camadas(ceu) -> void:
	var sombreador: ShaderMaterial = ceu.material
	_verificar(sombreador != null and sombreador.shader != null and sombreador.shader.get_mode() == Shader.MODE_SKY, "o céu é um shader do tipo sky")
	_verificar(ceu.ambiente.background_mode == Environment.BG_SKY, "o fundo é o céu")
	_verificar(ceu.ambiente.fog_enabled and ceu.ambiente.fog_aerial_perspective >= 0.9, "a névoa tira a cor do céu (perspectiva aérea)")
	_verificar(is_zero_approx(ceu.ambiente.fog_sky_affect), "a névoa não tinge o céu por cima (o shader já tem a bruma)")
	_verificar(ceu.ambiente.sky.process_mode == Sky.PROCESS_MODE_REALTIME, "o reflexo acompanha as nuvens em tempo real")
	var ruido: Texture2D = sombreador.get_shader_parameter("ruido")
	_verificar(ruido != null and ruido.get_width() >= 256, "o ruído das nuvens existe na hora (não chega vazio)")
	var cobertura := float(sombreador.get_shader_parameter("cobertura"))
	_verificar(cobertura > 0.15 and cobertura < 0.55, "tempo bom: céu mais de meio limpo")


## A regra da névoa em todas as horas, medida no Environment que o mundo realmente usa.
func _conferir_nevoa(ceu, dia) -> void:
	var pior_280 := Vector2(1.0, 0.0)
	var pior_2800 := 1.0
	var pior_4400 := 1.0
	var hora := 0.0
	while hora < 24.0:
		dia.definir_hora(hora)
		var densidade: float = ceu.ambiente.fog_density
		var a280: float = CeuVale.nevoa_a(densidade, 280.0)
		pior_280 = Vector2(minf(pior_280.x, a280), maxf(pior_280.y, a280))
		pior_2800 = minf(pior_2800, CeuVale.nevoa_a(densidade, 2800.0))
		pior_4400 = minf(pior_4400, CeuVale.nevoa_a(densidade, 4400.0))
		hora += 0.25
	print("MEDIDA névoa a 280 u: %.1f%% a %.1f%% | a 2800 u: >= %.1f%% | a 4400 u: >= %.1f%%" % [pior_280.x * 100.0, pior_280.y * 100.0, pior_2800 * 100.0, pior_4400 * 100.0])
	_verificar(pior_280.x >= NEVOA_280.x, "a 280 u a névoa nunca fica abaixo de %.0f%% (o corte da mata apareceria): %.1f%%" % [NEVOA_280.x * 100.0, pior_280.x * 100.0])
	_verificar(pior_280.y <= NEVOA_280.y, "a 280 u a névoa nunca passa de %.0f%% (vira sopa): %.1f%%" % [NEVOA_280.y * 100.0, pior_280.y * 100.0])
	_verificar(pior_2800 >= NEVOA_2800, "a 2 800 u (far do jogador) a névoa fecha em %.0f%% ou mais: %.1f%%" % [NEVOA_2800 * 100.0, pior_2800 * 100.0])
	_verificar(pior_4400 >= NEVOA_4400, "a 4 400 u (borda do mar no menu) a névoa fecha em %.0f%% ou mais: %.1f%%" % [NEVOA_4400 * 100.0, pior_4400 * 100.0])
	# A régua tem dentes: uma densidade fraca ou forte demais é reprovada por ela.
	_verificar(CeuVale.nevoa_a(0.0004, 280.0) < NEVOA_280.x, "falsificação: névoa fraca demais sai da faixa dos 280 u")
	_verificar(CeuVale.nevoa_a(0.004, 280.0) > NEVOA_280.y, "falsificação: névoa grossa demais sai da faixa dos 280 u")
	_verificar(CeuVale.nevoa_a(0.0004, 2800.0) < NEVOA_2800, "falsificação: névoa fraca não fecha o horizonte")


## O céu pinta o sol onde ele está e a lua do lado oposto; de dia o sol está alto e de noite abaixo.
func _conferir_sol_e_lua(ceu, dia) -> void:
	dia.definir_hora(12.0)
	var sol_meio_dia: Vector3 = ceu.material.get_shader_parameter("sol_dir")
	_verificar(sol_meio_dia.y > 0.6, "ao meio-dia o disco do sol está alto no céu")
	_verificar(is_equal_approx(sol_meio_dia.length(), 1.0), "a direção do sol é unitária")
	_verificar(float(ceu.material.get_shader_parameter("luz")) > 0.9, "ao meio-dia o céu é de dia")
	_verificar(ceu.sol.visible and not ceu.lua.visible, "ao meio-dia só o sol ilumina")
	_verificar((-ceu.sol.basis.z).dot(-sol_meio_dia) > 0.95, "a luz do sol vem de onde o disco está (ao meio-dia)")
	dia.definir_hora(0.0)
	var sol_noite: Vector3 = ceu.material.get_shader_parameter("sol_dir")
	var lua_noite: Vector3 = ceu.material.get_shader_parameter("lua_dir")
	_verificar(sol_noite.y < -0.2, "à meia-noite o sol está abaixo do horizonte")
	_verificar(lua_noite.y > 0.3, "à meia-noite a lua está no céu")
	_verificar(float(ceu.material.get_shader_parameter("luz")) < 0.1, "à meia-noite o céu é de noite")
	_verificar(ceu.lua.visible and not ceu.sol.visible, "à meia-noite só a lua ilumina")
	dia.definir_hora(17.5)
	var luz_tarde := float(ceu.material.get_shader_parameter("horizonte"))
	_verificar(luz_tarde > 0.3, "às 17h30 é hora dourada (o céu esquenta do lado do sol)")
	dia.definir_hora(12.0)
	_verificar(float(ceu.material.get_shader_parameter("horizonte")) < 0.1, "ao meio-dia não há brilho de crepúsculo")


## A neblina de baixada deita na alvorada e o dia claro não a tem.
func _conferir_neblina(ceu, dia) -> void:
	_verificar(is_zero_approx(CeuVale.neblina_de_baixada(3.0)), "às 3h ainda não há neblina")
	_verificar(CeuVale.neblina_de_baixada(CeuVale.get("NEBLINA_PICO")) > 0.99, "às 5h45 a neblina está no pico")
	_verificar(is_zero_approx(CeuVale.neblina_de_baixada(8.0)), "às 8h a neblina já subiu")
	dia.definir_hora(CeuVale.get("NEBLINA_PICO"))
	_verificar(ceu.ambiente.fog_height_density > 0.05, "no pico da alvorada o Environment tem a névoa de altura")
	_verificar(ceu.ambiente.fog_height <= 4.0, "a neblina fica rente ao chão (o Mirante, a 45 u, fica acima)")
	dia.definir_hora(12.0)
	_verificar(is_zero_approx(ceu.ambiente.fog_height_density), "ao meio-dia não há neblina de baixada")


## Estrelas: a esfera celeste é uma rotação, tem o polo na latitude do lugar e gira com a hora.
func _conferir_estrelas() -> void:
	var latitude := -12.8123
	var meia_noite: Basis = CeuVale.esfera_celeste(0.0, latitude)
	_verificar(is_equal_approx(meia_noite.determinant(), 1.0), "a esfera celeste é uma rotação")
	var polo: Vector3 = meia_noite.transposed() * Vector3(0.0, 0.0, 1.0)
	_verificar(absf(polo.y - sin(deg_to_rad(latitude))) < 0.001, "o polo celeste norte fica a -12,8° do horizonte (latitude do lugar)")
	var seis: Basis = CeuVale.esfera_celeste(6.0, latitude)
	var antes: Vector3 = meia_noite * Vector3(0.0, 1.0, 0.0)
	var depois: Vector3 = seis * Vector3(0.0, 1.0, 0.0)
	_verificar(antes.distance_to(depois) > 0.5, "o céu estrelado gira com a hora")
	_verificar(((CeuVale.esfera_celeste(0.0, latitude) * Vector3.UP) - (CeuVale.esfera_celeste(24.0, latitude) * Vector3.UP)).length() < 0.01, "depois de 24 h o céu volta ao mesmo lugar")


## Nada de partícula no céu (as telas de carregamento e o menu ficam silenciosos).
func _conferir_sem_particulas(ceu) -> void:
	_verificar(ceu.nos.size() >= 3, "o céu registra o ambiente, o sol e a lua")
	var particulas := 0
	for no: Node in ceu.nos:
		if no is GPUParticles3D or no is CPUParticles3D:
			particulas += 1
		for filho in no.find_children("*", "", true, false):
			if filho is GPUParticles3D or filho is CPUParticles3D:
				particulas += 1
	_verificar(particulas == 0, "o céu não tem partícula")


## O degrau da borda: a terra além do quadro sobe tanto quanto a de dentro.
func _conferir_borda(mundo: Node) -> void:
	var regiao = mundo.get("_region")
	_verificar(regiao != null, "a região existe")
	if regiao == null:
		return
	var quadro: Rect2 = regiao.get_map_frame()
	var certo := _degrau_na_borda(mundo, quadro)
	print("MEDIDA degrau na borda (mediana, %d pontos em terra): %.2f u" % [certo.y, certo.x])
	_verificar(certo.y >= 20.0, "há terra suficiente nas bordas norte e oeste para medir o degrau: %d pontos" % int(certo.y))
	_verificar(certo.x <= DEGRAU_MAXIMO, "a terra de fora emenda na de dentro: degrau mediano %.2f u (máximo %.1f)" % [certo.x, DEGRAU_MAXIMO])
	# Falsificação: sem o exagero (o leito antigo), a mesma régua tem de reprovar.
	var exagero_real: float = Mar.get("_exageracao")
	Mar.set("_exageracao", 1.0)
	var antigo := _degrau_na_borda(mundo, quadro)
	Mar.set("_exageracao", exagero_real)
	print("MEDIDA degrau na borda com o leito antigo (sem exagero): %.2f u" % antigo.x)
	_verificar(antigo.x > DEGRAU_MAXIMO * 1.5, "falsificação: sem o exagero do relevo o degrau (%.2f u) reprova na mesma régua" % antigo.x)
	_verificar(not is_nan(Mar.altura_do_fundo(quadro.position - Vector2(5.0, 5.0))), "a altura do leito é conhecida logo fora do quadro")


## Mediana (x) e quantidade (y) das diferenças de altura entre o terreno do jogo, 2 u
## dentro do quadro, e o leito, 2 u fora, nas bordas norte e oeste, onde há terra.
func _degrau_na_borda(mundo: Node, quadro: Rect2) -> Vector2:
	var diferencas: Array[float] = []
	var passos := 60
	for i in passos + 1:
		var t := float(i) / float(passos)
		var norte := Vector2(lerpf(quadro.position.x, quadro.end.x, t), quadro.position.y)
		var oeste := Vector2(quadro.position.x, lerpf(quadro.position.y, quadro.end.y, t))
		for par in [[norte, Vector2(0.0, 2.0)], [oeste, Vector2(2.0, 0.0)]]:
			var borda: Vector2 = par[0]
			var para_dentro: Vector2 = par[1]
			var dentro := borda + para_dentro
			var fora := borda - para_dentro
			var altura_dentro: float = mundo.ground_height_at(Vector3(dentro.x, 0.0, dentro.y))
			var altura_fora: float = Mar.altura_do_fundo(fora)
			if is_nan(altura_fora) or altura_dentro < 4.0 or altura_fora < 4.0:
				continue
			diferencas.append(absf(altura_dentro - altura_fora))
	if diferencas.is_empty():
		return Vector2(INF, 0.0)
	diferencas.sort()
	return Vector2(diferencas[diferencas.size() / 2], diferencas.size())


func _frames(quantos: int) -> void:
	for i in quantos:
		await process_frame


func _mundo_pronto() -> void:
	for i in 3000:
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
