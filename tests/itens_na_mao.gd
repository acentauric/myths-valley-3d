extends SceneTree
## Confere OS ITENS NA MÃO.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/itens_na_mao.gd
##     (só alguns: ... -- --itens=enxada,balde)
##
## "Corrija itens desproporcionais ou mal encaixados na mão (por exemplo a
## ferramenta de arar) sem quebrar nada." Só o corpo do jogador
## (`personagem.tscn`), sem o vale, no estilo Tripo. Cada ferramenta da barra é
## posta na mão pelo caminho do jogo (`Vestimenta3D`, `player_controller`) e
## medida parada, andando, no golpe — a 30% do `chop` e a 45%, que é o
## impacto — e em uso, onde houver. Dez perguntas:
##
##   1. ESTÁ NA MÃO, E É A PEÇA DELA: a vara de pescar inclusive (o item é
##      "vara_de_pescar"; a peça, "vara_pescar").
##   2. NA PALMA: da palma (meio do osso da mão e da raiz do dedo médio) à
##      superfície da peça, no máximo 3,5 cm, em todo estado.
##   3. DO TAMANHO DELA: o comprimento real (o eixo maior dos vértices, no
##      mundo) na faixa da peça — o machado 0,75–0,90 m, a vara 2–3 m...
##   4. FORA DO CORPO: parada e andando, no máximo 10% dos vértices dentro das
##      cápsulas dos ossos (tronco, cabeça, pernas, braço esquerdo, braço
##      direito até o cotovelo), e nada abaixo do chão.
##   5. O BALDE EM PÉ: parado e andando, o eixo a até 10° da vertical; regando,
##      tomba pelo menos 45° para a frente.
##   6. O GOLPE NO ALVO: no impacto, a cabeça da picareta abaixo de 0,45 m (bate
##      na pedra); a lâmina da enxada no chão — no máximo 14 cm acima dele e no
##      máximo 12 cm abaixo — entre 0,5 e 1,2 m à frente (o leito é a 0,75 m).
##   7. A VARA ERGUIDA: parada, a ponta acima de 1,5 m; pescando, mais baixa e
##      à frente; e `ponta_na_mao` é mesmo a ponta da malha (dali sai a linha).
##   8. NADANDO, A PEÇA SOME.
##   9. O MACHADO E O FACÃO NÃO MUDAM: comparados, em cada estado, com uma
##      cópia montada pela conta aprovada (`_na_mao` de antes, giro de -30°
##      parado e 0° no golpe), até 1 cm. Os números dela (`APROVADOS`) são os do
##      corpo de hoje: trocar o corpo do jogador pede linhas novas nos dois lugares.
##  10. NO PROCEDURAL SÓ O MACHADO: o estilo procedural não ganha arte nova.
##
## A folha de fotos dos mesmos estados é `tools/prototipo_3d/fotos_da_mao.gd`,
## que usa as funções de medida daqui.

const PERSONAGEM := "res://scenes/prototipo_3d/personagem.tscn"
## [item da barra, peça esperada, comprimento mínimo, máximo (m)]
const ITENS := [
	["machado", "machado", 0.75, 0.90],
	["facao", "facao", 0.45, 0.60],
	["picareta", "picareta", 0.80, 1.00],
	["foice", "foice", 0.45, 0.60],
	["enxada", "enxada", 1.10, 1.50],
	["vara_de_pescar", "vara_pescar", 2.00, 3.00],
	["balde", "balde", 0.28, 0.38],
]
const PALMA_MAXIMA := 0.035
## O facão fica onde foi aprovado (pergunta 9), com o cabo uns 2 cm fora do
## punho: a régua dele é a de hoje, e não a das peças novas. A enxada tem 1 cm de
## folga: o cabo fino anda uns milímetros entre uma passada e outra.
const PALMA_MAXIMA_DA_PECA := {"facao": 0.06, "enxada": 0.045}
## O balde nunca vai a um golpe (só rega); no `chop` ele só não pode se soltar da mão.
const PALMA_DO_BALDE_NO_GOLPE := 0.09
const CORPO_MAXIMO := 10.0
## A conta aprovada do machado e do facão, congelada: [tamanho, pegada, acerto].
## É a do corpo do viajante: o acerto é do osso da mão do corpo em que foi medido
## (ver `Vestimenta3D.NA_MAO`), e quando o corpo do jogador mudou — do personagem
## medieval para o viajante do Tripo, cujo osso da mão gira 158° em volta dos
## dedos — as duas linhas foram levadas para o osso novo (a peça segura como o
## machado aprovado a segurava) e congeladas de novo aqui. Corpo novo, linha nova.
const APROVADOS := {
	"machado": [0.46, Vector3(0.34, 0.12, 0.014), Vector3(21.9, -177.6, 174.0)],
	"facao": [0.34, Vector3(0.307, 0.199, 0.159), Vector3(-1.0, -175.2, 174.4)],
}
## As cápsulas do corpo: [osso, osso, raio]. Sem o antebraço e a mão direitos,
## que seguram a peça.
const SEGMENTOS := [
	["Hips", "Spine", 0.15], ["Spine", "Spine1", 0.15], ["Spine1", "Spine2", 0.15], ["Spine2", "Neck", 0.13],
	["Neck", "Head", 0.08], ["Head", "HeadTop_End", 0.1],
	["LeftUpLeg", "LeftLeg", 0.09], ["LeftLeg", "LeftFoot", 0.065], ["LeftFoot", "LeftToeBase", 0.05],
	["RightUpLeg", "RightLeg", 0.09], ["RightLeg", "RightFoot", 0.065], ["RightFoot", "RightToeBase", 0.05],
	["LeftShoulder", "LeftArm", 0.06], ["LeftArm", "LeftForeArm", 0.06], ["LeftForeArm", "LeftHand", 0.05],
	["RightShoulder", "RightArm", 0.06], ["RightArm", "RightForeArm", 0.06],
]

var falhas := 0
var V
var CA


func _initialize() -> void:
	_run.call_deferred()
	var vigia := create_timer(300.0)
	vigia.timeout.connect(func() -> void:
		print("FALHA: o portão passou de 300 s")
		quit(2))


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("ITENS_NA_MAO_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	root.get_node("/root/Estilo").modo = "tripo"
	var jogador := await montar_jogador(self)
	V = load("res://scripts/prototipo_3d/vestimenta_3d.gd")
	CA = load("res://scripts/prototipo_3d/catalogo_assets.gd")
	var so := _itens_pedidos()
	for item in ITENS:
		if not so.is_empty() and not so.has(str(item[0])):
			continue
		await _conferir_item(jogador, item)
	if so.is_empty() or so.has("procedural"):
		_conferir_procedural()
	if falhas == 0:
		print("ITENS_NA_MAO_OK: as sete ferramentas da barra estão na mão (a vara inclusive), na palma, do tamanho delas e fora do corpo; o balde vai em pé e tomba regando; a picareta e a enxada batem no chão; a vara vai erguida; nadando somem; o machado e o facão não mudaram um centímetro; e o procedural só mostra o machado")
	quit(1 if falhas > 0 else 0)


func _itens_pedidos() -> Array:
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with("--itens="):
			return Array(argumento.trim_prefix("--itens=").split(",", false))
	return []


## O CORPO DO JOGADOR SOZINHO, num mundo vazio, sem física nem teclado: só o
## `_process` dele, que veste e posa a peça da mão.
static func montar_jogador(arvore: SceneTree) -> Node3D:
	var mundo := Node3D.new()
	mundo.name = "Palco"
	arvore.root.add_child(mundo)
	var jogador := (load(PERSONAGEM) as PackedScene).instantiate() as Node3D
	mundo.add_child(jogador)
	jogador.set_physics_process(false)
	jogador.set_process_unhandled_input(false)
	jogador.set_process_input(false)
	for _i in 10:
		await arvore.process_frame
	arvore.root.get_node("/root/Inventario").selecionar(-1)
	for _i in 3:
		await arvore.process_frame
	return jogador


## PÕE O ITEM NA MÃO pela barra (o primeiro espaço) e devolve a peça que o
## corpo mostra, ou null. O corpo assenta no repouso antes: o deslocamento da
## pegada (`Vestimenta3D._na_mao`) é tirado da pose do corpo na hora em que a
## peça nasce, e logo depois de um golpe ou de um passo essa pose ainda é a
## mistura com o clipe de antes (0,18 s de transição) — a peça de cada item
## nascia num lugar diferente conforme o que o item anterior tinha feito.
static func por_na_mao(arvore: SceneTree, jogador: Node3D, id: String) -> Node3D:
	var inventario := arvore.root.get_node("/root/Inventario")
	inventario.selecionar(-1)
	jogador.set("velocity", Vector3.ZERO)
	jogador.get("animator").update_motion(0.0, 0.016)
	await _segundos(arvore, 0.5)
	inventario.espacos[0] = {"id": id, "qtd": 1}
	inventario.selecionar(0)
	for _i in 4:
		await arvore.process_frame
	return peca_na_mao(jogador)


## A peça que o corpo segura agora (o nó com "peca" que não é roupa), ou null.
static func peca_na_mao(jogador: Node3D) -> Node3D:
	for no in jogador.find_children("*", "Node3D", true, false):
		if no.has_meta("peca") and not no.is_queued_for_deletion() and not str(no.get_meta("peca")) in ["luvas_de_couro", "chapeu"]:
			return no
	return null


## LEVA O CORPO A UM ESTADO e o segura nele para a medida: "parado", "andando",
## "golpe@0.30" (fração do `chop`), "uso". Depois da medida, `sair_do_estado`.
static func ir_ao_estado(arvore: SceneTree, jogador: Node3D, estado: String) -> void:
	var animador = jogador.get("animator")
	if estado == "parado":
		jogador.set("velocity", Vector3.ZERO)
		animador.update_motion(0.0, 0.016)
		await _segundos(arvore, 0.5)
	elif estado == "andando":
		jogador.set("velocity", Vector3(0.0, 0.0, 2.1))
		for _q in 25:
			animador.update_motion(2.1, 0.016)
			await arvore.process_frame
	elif estado == "uso":
		jogador.set("velocity", Vector3.ZERO)
		animador.update_motion(0.0, 0.016)
		jogador.call("usar_item_na_mao", 30.0)
		await _segundos(arvore, 0.6)
	elif estado.begins_with("golpe@"):
		var alvo := float(estado.trim_prefix("golpe@"))
		jogador.set("velocity", Vector3.ZERO)
		animador.update_motion(0.0, 0.016)
		await _segundos(arvore, 0.3)
		animador.play_chop(1)
		var tocador: AnimationPlayer = animador.get("animation_player")
		var clipe := str(tocador.current_animation)
		var duracao := tocador.get_animation(clipe).length
		for _limite in 600:
			await arvore.process_frame
			if str(tocador.current_animation) != clipe:
				break
			if tocador.current_animation_position / duracao >= alvo:
				tocador.pause()
				break
		await arvore.process_frame
		await arvore.process_frame


static func sair_do_estado(arvore: SceneTree, jogador: Node3D) -> void:
	var animador = jogador.get("animator")
	var tocador: AnimationPlayer = animador.get("animation_player")
	if tocador != null and not tocador.is_playing() and tocador.current_animation != &"":
		tocador.play()
	animador.stop_chop()
	jogador.call("usar_item_na_mao", 0.0)
	jogador.set("velocity", Vector3.ZERO)
	animador.update_motion(0.0, 0.016)
	await arvore.process_frame


static func _segundos(arvore: SceneTree, s: float) -> void:
	var ate := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < ate:
		await arvore.process_frame


func _conferir_item(jogador: Node3D, item: Array) -> void:
	var id := str(item[0])
	var esperada := str(item[1])
	if not CA.tem_tripo(esperada):
		_conferir(false, "%s: a peça \"%s\" não tem GLB importado" % [id, esperada])
		return
	var no := await por_na_mao(self, jogador, id)
	_conferir(no != null, "%s: escolhido na barra, nada aparece na mão" % id)
	if no == null:
		return
	_conferir(str(no.get_meta("peca")) == esperada, "%s: a mão mostra \"%s\", e não \"%s\"" % [id, str(no.get_meta("peca")), esperada])
	var referencia := {}
	if APROVADOS.has(esperada):
		referencia = _montar_referencia(jogador, esperada)
	var estados := ["parado", "andando", "golpe@0.30", "golpe@0.45"]
	if V.NA_MAO.get(esperada, {}).has("uso"):
		estados.append("uso")
	var medidas := {}
	for estado in estados:
		await ir_ao_estado(self, jogador, estado)
		var m := medir(jogador, no)
		medidas[estado] = m
		print("  %s %s: %s" % [id, estado, descrever(m)])
		var palma_maxima := float(PALMA_MAXIMA_DA_PECA.get(esperada, PALMA_MAXIMA))
		if esperada == "balde" and estado.begins_with("golpe"):
			palma_maxima = PALMA_DO_BALDE_NO_GOLPE
		_conferir(float(m["palma"]) <= palma_maxima, "%s %s: a palma está a %.1f cm da peça (máximo %.1f)" % [id, estado, float(m["palma"]) * 100.0, palma_maxima * 100.0])
		_conferir(float(m["comprimento"]) >= float(item[2]) and float(m["comprimento"]) <= float(item[3]),
			"%s %s: a peça tem %.2f m (faixa %.2f–%.2f)" % [id, estado, float(m["comprimento"]), float(item[2]), float(item[3])])
		if estado in ["parado", "andando"]:
			_conferir(float(m["corpo"]) <= CORPO_MAXIMO, "%s %s: %.0f%% da peça dentro do corpo" % [id, estado, float(m["corpo"])])
			_conferir(float(m["abaixo"]) <= 0.0, "%s %s: %.0f%% da peça abaixo do chão" % [id, estado, float(m["abaixo"])])
		if not referencia.is_empty():
			var desvio := _desvio_da_referencia(jogador, no, referencia, 0.0 if estado.begins_with("golpe") else -30.0)
			_conferir(desvio <= 0.01, "%s %s: mudou de lugar %.1f cm em relação à conta aprovada" % [id, estado, desvio * 100.0])
		await sair_do_estado(self, jogador)
	if esperada == "balde":
		for estado in ["parado", "andando"]:
			_conferir(float(medidas[estado]["inclinacao"]) <= 10.0, "balde %s: deitado, a %.0f° da vertical" % [estado, float(medidas[estado]["inclinacao"])])
		_conferir(float(medidas["uso"]["inclinacao"]) >= 45.0, "balde regando: só tomba %.0f°" % float(medidas["uso"]["inclinacao"]))
	if esperada == "picareta":
		_conferir(float(medidas["golpe@0.45"]["baixo"].y) < 0.45, "picareta: no impacto a cabeça fica a %.2f m (golpe no ar)" % float(medidas["golpe@0.45"]["baixo"].y))
	if esperada == "enxada":
		var baixo: Vector3 = medidas["golpe@0.45"]["baixo"]
		_conferir(baixo.y <= 0.14 and baixo.y >= -0.12, "enxada: no impacto a lâmina fica a %.2f m do chão" % baixo.y)
		_conferir(baixo.z >= 0.5 and baixo.z <= 1.2, "enxada: no impacto a lâmina cai a %.2f m à frente (0,5–1,2)" % baixo.z)
	if esperada == "vara_pescar":
		var parada: Vector3 = medidas["parado"]["ponta"]
		var pescando: Vector3 = medidas["uso"]["ponta"]
		_conferir(parada.y >= 1.5, "vara parada: a ponta fica a %.2f m (mínimo 1,5)" % parada.y)
		_conferir(pescando.y < parada.y and pescando.z >= 1.0, "vara pescando: a ponta não baixa para a água (%s; parada %s)" % [str(pescando), str(parada)])
		await ir_ao_estado(self, jogador, "parado")
		var visual := jogador.get("visual") as Node3D
		var ponta: Vector3 = V.ponta_na_mao(jogador)
		var malha: Vector3 = medir(jogador, no)["ponta"]
		_conferir(ponta.is_finite() and (visual.global_transform.affine_inverse() * ponta).distance_to(malha) <= 0.1,
			"vara: a ponta de onde sai a linha não é a ponta da malha (%s; malha %s)" % [str(ponta), str(malha)])
	# Nadando, some; saindo da água, volta.
	jogador.set("_nadando", true)
	await process_frame
	await process_frame
	_conferir(not no.is_visible_in_tree(), "%s: nadando, a peça continua na mão" % id)
	jogador.set("_nadando", false)
	await process_frame
	await process_frame
	_conferir(no.is_visible_in_tree(), "%s: fora da água, a peça não volta à mão" % id)
	if not referencia.is_empty():
		(referencia["anexo"] as Node).queue_free()


## A CÓPIA PELA CONTA APROVADA (o `_na_mao` de antes, congelado aqui), presa ao
## mesmo osso da mão: o machado e o facão do jogo têm de coincidir com ela.
func _montar_referencia(jogador: Node3D, peca: String) -> Dictionary:
	var ancora_real := jogador.get("_machado_ancora") as Node3D
	var anexo_real := ancora_real.get_parent() as BoneAttachment3D
	var anexo := BoneAttachment3D.new()
	anexo.name = "Referencia"
	anexo.bone_name = anexo_real.bone_name
	anexo_real.get_parent().add_child(anexo)
	var ancora := Node3D.new()
	anexo.add_child(ancora)
	var visual := jogador.get("visual") as Node3D
	var conta: Array = APROVADOS[peca]
	var no: Node3D = CA.instanciar(peca, ancora, Vector3.ZERO, float(conta[0]))
	no.rotation = Vector3(deg_to_rad(1.0), deg_to_rad(2.0), deg_to_rad(92.0))
	var acerto: Vector3 = conta[2]
	no.basis = no.basis * Basis(Vector3.UP, PI) * Basis.from_euler(Vector3(deg_to_rad(acerto.x), deg_to_rad(acerto.y), deg_to_rad(acerto.z)))
	var pegada: Vector3 = conta[1]
	no.position -= no.transform * pegada
	no.position += Vector3(0.0, 0.06, 0.0)
	no.position += ancora.global_basis.inverse() * (visual.global_basis.x * 0.08)
	var pivo := Node3D.new()
	ancora.add_child(pivo)
	pivo.position = no.transform * pegada
	no.reparent(pivo, true)
	anexo.visible = false
	return {"anexo": anexo, "ancora": ancora, "pivo": pivo, "no": no}


## Quanto a peça do jogo se afastou da cópia aprovada (o maior desvio entre os
## cantos da caixa do GLB), com a cópia no giro aprovado do estado.
func _desvio_da_referencia(jogador: Node3D, no: Node3D, referencia: Dictionary, giro: float) -> float:
	var ancora_real := jogador.get("_machado_ancora") as Node3D
	var ancora := referencia["ancora"] as Node3D
	var visual := jogador.get("visual") as Node3D
	ancora.position = ancora_real.position
	var vertical := (ancora.global_basis.inverse() * visual.global_basis.y).normalized()
	(referencia["pivo"] as Node3D).basis = Basis(vertical, deg_to_rad(giro))
	var copia := referencia["no"] as Node3D
	var caixa: AABB = no.get_meta("limites", AABB())
	var escala := maxf(no.scale.x, 0.0001)
	var pior := 0.0
	for i in 8:
		var canto := caixa.get_endpoint(i) / escala
		pior = maxf(pior, (no.global_transform * canto).distance_to(copia.global_transform * canto))
	return pior


func _conferir_procedural() -> void:
	var estilo := root.get_node("/root/Estilo")
	var inventario := root.get_node("/root/Inventario")
	estilo.modo = "procedural"
	var mostrados := {}
	for item in ITENS:
		inventario.espacos[0] = {"id": str(item[0]), "qtd": 1}
		inventario.selecionar(0)
		var peca: String = V.item_na_mao()
		if peca != "":
			mostrados[str(item[0])] = peca
		inventario.selecionar(-1)
	estilo.modo = "tripo"
	_conferir(mostrados.keys() == ["machado"] and mostrados["machado"] == "machado", "no procedural a mão mostra %s (só o machado tem desenho lá)" % str(mostrados))


# --- as medidas ------------------------------------------------------------------

## A MEDIDA DA PEÇA NA MÃO, no quadro do corpo (x para a esquerda do boneco, y
## para cima, z para a frente; o chão em y = 0): comprimento (eixo maior), palma
## (distância exata à superfície), corpo e abaixo (% dos vértices), baixo (o
## vértice mais baixo), ponta (o vértice do eixo mais longe da palma) e
## inclinação (graus do Y da peça à vertical do mundo).
static func medir(jogador: Node3D, peca: Node3D) -> Dictionary:
	var visual := jogador.get("visual") as Node3D
	var para_o_corpo := visual.global_transform.affine_inverse()
	var esqueleto := jogador.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var prefixo := ""
	for i in esqueleto.get_bone_count():
		var nome := String(esqueleto.get_bone_name(i))
		if nome.ends_with("RightHand"):
			prefixo = nome.trim_suffix("RightHand")
			break
	var osso := func(nome: String) -> Vector3:
		var indice := esqueleto.find_bone(prefixo + nome)
		return esqueleto.global_transform * esqueleto.get_bone_global_pose(indice).origin if indice >= 0 else Vector3.INF
	var palma_mundo: Vector3 = (osso.call("RightHand") + osso.call("RightHandMiddle1")) * 0.5
	var palma := para_o_corpo * palma_mundo
	var pontos := PackedVector3Array()
	var melhor := INF
	var perto := Vector3.INF
	for encontrado in peca.find_children("*", "MeshInstance3D", true, false):
		var malha := encontrado as MeshInstance3D
		if malha.mesh == null:
			continue
		var t := malha.global_transform
		for s in malha.mesh.get_surface_count():
			var arrays := malha.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var passo := maxi(1, vs.size() / 1500)
			for i in range(0, vs.size(), passo):
				pontos.append(para_o_corpo * (t * vs[i]))
			for i in range(0, indices.size() - 2, 3):
				var c := _mais_perto_no_triangulo(palma_mundo, t * vs[indices[i]], t * vs[indices[i + 1]], t * vs[indices[i + 2]])
				if c.distance_to(palma_mundo) < melhor:
					melhor = c.distance_to(palma_mundo)
					perto = c
	# A palma e o ponto da peça mais perto dela, no quadro do GLB: é por onde se
	# acerta a pegada (`fotos_da_mao.gd` imprime os dois).
	var para_a_peca := peca.global_transform.affine_inverse()
	var m := {"comprimento": 0.0, "palma": melhor, "corpo": 0.0, "abaixo": 0.0, "baixo": Vector3.INF, "ponta": Vector3.INF, "inclinacao": 0.0,
		"palma_no_corpo": palma, "palma_na_peca": para_a_peca * palma_mundo, "perto_na_peca": para_a_peca * perto if perto.is_finite() else Vector3.INF}
	if pontos.is_empty():
		return m
	var centro := Vector3.ZERO
	for p in pontos:
		centro += p
	centro /= pontos.size()
	# O eixo maior pela iteração de potência na covariância.
	var cov := Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
	for p in pontos:
		var d := p - centro
		cov.x += d * d.x
		cov.y += d * d.y
		cov.z += d * d.z
	var eixo := Vector3(0.3, 0.9, 0.2).normalized()
	for _k in 60:
		eixo = (cov * eixo).normalized()
	var lo := INF
	var hi := -INF
	var baixo := Vector3(0.0, INF, 0.0)
	for p in pontos:
		var s := (p - centro).dot(eixo)
		lo = minf(lo, s)
		hi = maxf(hi, s)
		if p.y < baixo.y:
			baixo = p
	var ponta := centro + eixo * lo
	if (centro + eixo * hi).distance_to(palma) > ponta.distance_to(palma):
		ponta = centro + eixo * hi
	# A ponta de verdade: o vértice mais longe da palma ao longo do eixo.
	var mais_longe := -INF
	for p in pontos:
		var s := (p - palma).dot((ponta - palma).normalized())
		if s > mais_longe:
			mais_longe = s
			m["ponta"] = p
	var segmentos := []
	for seg in SEGMENTOS:
		var a: Vector3 = osso.call(str(seg[0]))
		var b: Vector3 = osso.call(str(seg[1]))
		if a.is_finite() and b.is_finite():
			segmentos.append([para_o_corpo * a, para_o_corpo * b, float(seg[2])])
	var dentro := 0
	var abaixo := 0
	for p in pontos:
		if p.y < -0.02:
			abaixo += 1
		for seg in segmentos:
			var a: Vector3 = seg[0]
			var ab: Vector3 = seg[1] - a
			var f := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
			if p.distance_to(a + ab * f) < float(seg[2]):
				dentro += 1
				break
	m["comprimento"] = hi - lo
	m["corpo"] = 100.0 * dentro / pontos.size()
	m["abaixo"] = 100.0 * abaixo / pontos.size()
	m["baixo"] = baixo
	m["inclinacao"] = rad_to_deg(peca.global_basis.y.normalized().angle_to(Vector3.UP))
	return m


static func descrever(m: Dictionary) -> String:
	var baixo: Vector3 = m["baixo"]
	var ponta: Vector3 = m["ponta"]
	return "comprimento=%.2fm palma=%.1fcm corpo=%.0f%% abaixo=%.0f%% mais_baixo=(y %.2f, z %.2f) ponta=(%.2f, %.2f, %.2f) inclinacao=%.0f°" % [
		float(m["comprimento"]), float(m["palma"]) * 100.0, float(m["corpo"]), float(m["abaixo"]), baixo.y, baixo.z, ponta.x, ponta.y, ponta.z, float(m["inclinacao"])]


static func _mais_perto_no_triangulo(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var ab := b - a
	var ac := c - a
	var ap := p - a
	var d1 := ab.dot(ap)
	var d2 := ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return a
	var bp := p - b
	var d3 := ab.dot(bp)
	var d4 := ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3:
		return b
	var vc := d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		return a + ab * (d1 / (d1 - d3))
	var cp := p - c
	var d5 := ab.dot(cp)
	var d6 := ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return c
	var vb := d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		return a + ac * (d2 / (d2 - d6))
	var va := d3 * d6 - d5 * d4
	if va <= 0.0 and (d4 - d3) >= 0.0 and (d5 - d6) >= 0.0:
		return b + (c - b) * ((d4 - d3) / ((d4 - d3) + (d5 - d6)))
	var den := 1.0 / (va + vb + vc)
	return a + ab * (vb * den) + ac * (vc * den)
