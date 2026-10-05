extends SceneTree
## LEVA O ACERTO DE CADA LINHA DE `Vestimenta3D.NA_MAO` DE UM CORPO PARA OUTRO.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/prototipo_3d/acerto_para_o_corpo.gd -- --de=<glb do corpo antigo> --para=<glb do corpo novo>
##
## Lê as linhas que estão em `NA_MAO` como as do corpo `--de` e imprime o acerto
## delas para o corpo `--para`.
##
## O acerto de uma linha é do osso da mão do corpo em que foi medido: cada rig
## do Tripo vira esse osso de um jeito em volta do eixo dos dedos (o do viajante
## difere 158° do do personagem medieval, e o mesmo acerto que deita o machado na
## mão de um o atravessa na do outro). Dois corpos que tocam o mesmo clipe têm a
## mão para o mesmo lado — o que se mede nos nós dos dedos: a linha do mínimo ao
## indicador e o eixo do pulso ao dedo médio —, e só a rolagem do osso muda. Esta
## ferramenta mede essa rolagem nos dois esqueletos de repouso e imprime cada
## linha com o acerto levado do osso antigo para o novo: a peça fica na mão
## como ficava no corpo de antes. A pegada, o tamanho e as poses seguem como
## estão; o que sobra é olhar a folha de `fotos_da_mao.gd` e rodar o portão
## `itens_na_mao`, que julgam o resultado (e congelar de novo, em `APROVADOS`
## do portão, a conta do machado e do facão).
##
## Foi assim a troca de 05/10/2026, do personagem medieval
## (`personagem/medieval_character_animated.glb`) para o viajante
## (`personagens/viajante_tripo.glb`).


func _initialize() -> void:
	_run.call_deferred()


func _arg(nome: String, padrao: String) -> String:
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with("--" + nome + "="):
			return argumento.trim_prefix("--" + nome + "=")
	return padrao


func _run() -> void:
	var de := _arg("de", "")
	var para := _arg("para", "")
	if de == "" or para == "":
		print("uso: --script res://tools/prototipo_3d/acerto_para_o_corpo.gd -- --de=<glb do corpo antigo> --para=<glb do corpo novo>")
		quit(1)
		return
	var antigo := _quadro_da_mao(de)
	var novo := _quadro_da_mao(para)
	if antigo.is_empty() or novo.is_empty():
		print("FALHA: sem esqueleto de Mixamo (osso ...RightHand com Index1, Middle1 e Pinky1) em ", de if antigo.is_empty() else para)
		quit(1)
		return
	var V := load("res://scripts/prototipo_3d/vestimenta_3d.gd")
	# O que `Vestimenta3D._na_mao` põe antes do acerto: o giro de 1°, 2° e 92° e a meia-volta.
	var base := Basis.from_euler(Vector3(deg_to_rad(1.0), deg_to_rad(2.0), deg_to_rad(92.0))) * Basis(Vector3.UP, PI)
	# `quadro` tem como colunas os eixos da mão no espaço do osso, então a rotação do osso
	# antigo para o novo é quadro_novo * quadro_antigo^T.
	var entre_ossos: Basis = (novo[0] as Basis) * (antigo[0] as Basis).transposed()
	var leva := base.inverse() * entre_ossos * base
	var giro := rad_to_deg(Quaternion(leva).get_angle())
	giro = minf(giro, 360.0 - giro)
	print("De:   %s\nPara: %s\nRolagem do osso da mão entre os dois: %.1f°\n" % [de, para, giro])
	var linhas: Dictionary = V.NA_MAO
	for peca in linhas:
		var linha: Dictionary = linhas[peca]
		if not linha.has("acerto"):
			print("%-12s sem acerto (%s): fica como está" % [peca, "pendurada" if bool(linha.get("pendurar", false)) else "?"])
			continue
		var velho: Vector3 = linha["acerto"]
		var graus := Basis.from_euler(Vector3(deg_to_rad(velho.x), deg_to_rad(velho.y), deg_to_rad(velho.z)))
		var e := (leva * graus).get_euler(EULER_ORDER_YXZ)
		print("%-12s acerto %s -> Vector3(%.1f, %.1f, %.1f)" % [peca, str(velho), rad_to_deg(e.x), rad_to_deg(e.y), rad_to_deg(e.z)])
	quit(0)


## Os eixos da mão direita nos nós dos dedos, como colunas, no espaço do osso da mão no
## repouso: x do mínimo ao indicador (tirada a parte ao longo do eixo), y do pulso ao dedo
## médio, z saindo da palma. Devolve [quadro], ou [] se o corpo não tem o esqueleto.
func _quadro_da_mao(caminho: String) -> Array:
	var cena := load(caminho) as PackedScene
	if cena == null:
		return []
	var corpo := cena.instantiate() as Node3D
	root.add_child(corpo)
	var resultado := []
	for encontrado in corpo.find_children("*", "Skeleton3D", true, false):
		var esqueleto := encontrado as Skeleton3D
		for i in esqueleto.get_bone_count():
			var nome := String(esqueleto.get_bone_name(i))
			if not nome.to_lower().ends_with("righthand"):
				continue
			var medio := esqueleto.find_bone(nome + "Middle1")
			var indicador := esqueleto.find_bone(nome + "Index1")
			var minimo := esqueleto.find_bone(nome + "Pinky1")
			if medio < 0 or indicador < 0 or minimo < 0:
				continue
			var para_a_mao := esqueleto.get_bone_global_rest(i).affine_inverse()
			var eixo := (para_a_mao * esqueleto.get_bone_global_rest(medio).origin).normalized()
			var lado := (para_a_mao * esqueleto.get_bone_global_rest(indicador).origin) - (para_a_mao * esqueleto.get_bone_global_rest(minimo).origin)
			var x := (lado - eixo * lado.dot(eixo)).normalized()
			resultado = [Basis(x, eixo, x.cross(eixo))]
			break
		if not resultado.is_empty():
			break
	corpo.queue_free()
	return resultado
