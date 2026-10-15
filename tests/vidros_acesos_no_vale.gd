extends "res://tests/suite/caso.gd"
## OS VIDROS ACESOS NO VALE, DE DIA E À NOITE (#257): a fachada da igreja não tem quadrado branco, não
## sobra quad emissivo sem dono, e o vidro que existe fica rente à fachada de uma casa com janela.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste vidros_acesos_no_vale
##
## As perguntas de regra (a lista das construções com janela, o giro, a textura, o apagar de dia) estão no
## teste de unidade `test_luz_das_janelas`; este olha o vale montado, às 19h (noite fechada) e ao meio-dia:
##
##   1. A FACHADA DA IGREJA ESTÁ LIMPA: nenhum quad emissivo (MeshInstance3D de QuadMesh com emissão) a
##      menos de 6 m da porta dela. Era o "quadrado branco chapado sobre a porta" da Build 11.
##   2. NENHUM QUAD EMISSIVO SOLTO: todo quad emissivo do vale é um vidro aceso (grupo `vidro_aceso`) ou
##      é de um achado (`Achados/`: o folheto de cordel no chão, feito emissivo de propósito). O que
##      aparecer sem dono reprova, onde quer que esteja.
##   3. O VIDRO FICA RENTE À FACHADA DE UMA CASA COM JANELA: a casa mais próxima (a âncora com `Frente`) é
##      uma das que têm janela no ponto, o vidro olha para a frente dela, e fica do lado de fora da parede.
##
## FALSIFICAÇÃO embutida: (A) um vidro posto na porta da igreja com giro zero (a janela de antes, sempre
## voltada para o sul do mundo, enquanto a igreja olha para o oeste) e (B) uma ficha emissiva branca solta
## no mesmo lugar têm de ser achados pelas perguntas que lhes cabem. Se o detector não os achar, ele não
## vale nada e o caso reprova.

const ALCANCE_DA_PORTA := 6.0
## A frente da igreja, a partir da âncora, onde ficava a porta (o quad antigo estava a 4,52 m).
const PORTA_A_FRENTE := 4.6
const PARALELO := 0.99
## As construções cuja fachada tem janela no ponto da `luz_janela` (a mesma lista do teste de unidade).
const COM_JANELA := ["Casa de taipa"]
const HORAS := [19.0, 12.0]

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("VIDROS_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _quadros(4)
	await _mundo_pronto()
	await _quadros(8)
	var mundo = get_first_node_in_group("mundo")
	var dia := root.get_node("/root/Dia")
	var hora_de_antes: float = dia.hora
	var igreja: Vector3 = mundo.ancoras.get("Igreja", Vector3.INF)
	var frente: Vector3 = mundo.ancoras.get("IgrejaFrente", Vector3.INF)
	_conferir(igreja.is_finite() and frente.is_finite(), "o vale não tem a igreja e a frente dela")
	if not igreja.is_finite() or not frente.is_finite():
		_fechar()
		return
	var porta := igreja + frente * PORTA_A_FRENTE + Vector3.UP * 2.0
	dia.pausado = true
	for hora: float in HORAS:
		dia.definir_hora(hora)
		await _quadros(3)
		_conferir(_quads_perto(porta).is_empty(),
			"às %.0fh há quad emissivo a menos de %.0f m da porta da igreja: %s" % [hora, ALCANCE_DA_PORTA, str(_quads_perto(porta))])
		_conferir(_sem_dono().is_empty(), "às %.0fh há quad emissivo sem dono: %s" % [hora, str(_sem_dono())])
		_conferir(_vidros_fora_de_lugar(mundo).is_empty(), "às %.0fh há vidro aceso fora de lugar: %s" % [hora, str(_vidros_fora_de_lugar(mundo))])
	var vidros := get_nodes_in_group("vidro_aceso")
	_conferir(not vidros.is_empty(), "o vale não tem nenhum vidro aceso (a janela da Casa de taipa sumiu?)")
	_falsificar(mundo, porta, igreja, frente)
	dia.definir_hora(hora_de_antes)
	_fechar()


## FALSIFICAÇÃO: os dois defeitos da #257 postos na porta da igreja têm de ser achados. (A) O vidro como
## era, com giro zero (sempre voltado para o sul do mundo, enquanto a igreja olha para o oeste): pelas
## perguntas 1 e 3. (B) Um quad emissivo branco chapado, sem dono: pelas perguntas 1 e 2.
func _falsificar(mundo: Node3D, porta: Vector3, igreja: Vector3, frente: Vector3) -> void:
	var LuzesEpoca: GDScript = load("res://scripts/prototipo_3d/luzes_epoca.gd")
	var intruso = LuzesEpoca.new()
	mundo.add_child(intruso)
	intruso.janela(igreja + frente * PORTA_A_FRENTE + Vector3.UP * 1.4, 0.0)
	_conferir(not _quads_perto(porta).is_empty(), "falsificação A: o vidro de través na porta da igreja não foi achado a menos de 6 m dela")
	_conferir(not _vidros_fora_de_lugar(mundo).is_empty(), "falsificação A: o vidro de través na igreja passou pela pergunta 3")
	intruso.free()
	_conferir(_quads_perto(porta).is_empty() and _vidros_fora_de_lugar(mundo).is_empty(), "o vidro da falsificação A ficou no vale")
	var ficha := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.86, 1.0)
	var branco := StandardMaterial3D.new()
	branco.albedo_color = Color.WHITE
	branco.emission_enabled = true
	branco.emission = Color.WHITE
	ficha.mesh = quad
	ficha.material_override = branco
	mundo.add_child(ficha)
	ficha.global_position = igreja + frente * PORTA_A_FRENTE + Vector3.UP * 1.4
	_conferir(not _quads_perto(porta).is_empty(), "falsificação B: a ficha branca na porta da igreja não foi achada a menos de 6 m dela")
	_conferir(not _sem_dono().is_empty(), "falsificação B: o quad emissivo sem dono passou pela pergunta 2")
	ficha.free()
	_conferir(_quads_perto(porta).is_empty() and _sem_dono().is_empty(), "a ficha da falsificação B ficou no vale")


## Todo MeshInstance3D de QuadMesh com material emissivo na árvore do vale (visível ou não).
func _quads_emissivos() -> Array[MeshInstance3D]:
	var achados: Array[MeshInstance3D] = []
	for no in current_scene.find_children("*", "MeshInstance3D", true, false):
		var malha := no as MeshInstance3D
		if malha.mesh == null or not (malha.mesh is QuadMesh):
			continue
		var material: Material = malha.material_override
		if material == null:
			material = malha.mesh.surface_get_material(0)
		if material is StandardMaterial3D and (material as StandardMaterial3D).emission_enabled:
			achados.append(malha)
	return achados


## Os quads emissivos a menos de ALCANCE_DA_PORTA da porta, como texto.
func _quads_perto(porta: Vector3) -> PackedStringArray:
	var perto := PackedStringArray()
	for quad in _quads_emissivos():
		if quad.global_position.distance_to(porta) < ALCANCE_DA_PORTA:
			perto.append(String(quad.get_path()))
	return perto


## Os quads emissivos que não são vidro aceso nem de um achado.
func _sem_dono() -> PackedStringArray:
	var soltos := PackedStringArray()
	for quad in _quads_emissivos():
		if quad.is_in_group("vidro_aceso") or String(quad.get_path()).contains("/Achados/"):
			continue
		soltos.append(String(quad.get_path()))
	return soltos


## A âncora de construção (com `Frente`, sem "/" no nome) mais perto do ponto, no plano do chão.
func _casa_mais_perto(mundo: Node, ponto: Vector3) -> String:
	var melhor := ""
	var menor := INF
	for chave in mundo.ancoras:
		var nome := String(chave)
		if nome.ends_with("Frente") or nome.contains("/") or not mundo.ancoras.has(nome + "Frente"):
			continue
		var base: Vector3 = mundo.ancoras[nome]
		var distancia := Vector2(base.x - ponto.x, base.z - ponto.z).length()
		if distancia < menor:
			menor = distancia
			melhor = nome
	return melhor


## Os vidros acesos que não ficam rentes à fachada de uma casa com janela, como texto.
func _vidros_fora_de_lugar(mundo: Node) -> PackedStringArray:
	var fora := PackedStringArray()
	for vidro in get_nodes_in_group("vidro_aceso"):
		var quad := vidro as Node3D
		var casa := _casa_mais_perto(mundo, quad.global_position)
		if not COM_JANELA.has(casa):
			fora.append("%s está mais perto de '%s', que não tem janela ali" % [String(quad.get_path()), casa])
			continue
		var frente: Vector3 = mundo.ancoras[casa + "Frente"]
		var base: Vector3 = mundo.ancoras[casa]
		var olha := absf(quad.global_transform.basis.z.dot(frente))
		if olha < PARALELO:
			fora.append("%s olha %.2f da frente de '%s' (esperado %.2f ou mais): está de través na parede" % [String(quad.get_path()), olha, casa, PARALELO])
		if (quad.global_position - base).dot(frente) <= 0.0:
			fora.append("%s está do lado de dentro da parede de '%s'" % [String(quad.get_path()), casa])
	return fora


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("VIDROS_ACESOS_OK: a fachada da igreja está limpa de dia e à noite, não há quad emissivo sem dono, e o vidro aceso da Casa de taipa fica rente à parede; o vidro de través na igreja é achado")
	else:
		print("vidros_acesos_no_vale: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


func _mundo_pronto() -> void:
	for i in 3000:
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
