extends SceneTree
## O ALCANCE DAS PEÇAS DO CENÁRIO: o que é caro e está longe deixa de ser desenhado.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/lod_das_pecas.gd
##
## "Adotamos a estratégia de deixar procedurais as árvores longe para as montanhas
## cobrir e deu certo, mas poderíamos fazer isso em tudo, nas casas também, que estão
## sendo desenhadas mesmo distantes." As ~300 peças individuais do cenário (28
## construções de 10 mil triângulos, 50 árvores nomeadas de 10 a 20 mil, adereços e
## recursos) não tinham corte nenhum. Cinco perguntas, no vale montado:
##
##   1. O CATÁLOGO: toda chave tem a sua classe de alcance (ou está em
##      `SEM_ALCANCE`, com o motivo escrito), o alcance cresce com o tamanho dentro
##      dos limites da classe, as peças pequenas somem entre 60 e 90 u, e toda
##      construção de 4,5 u para cima tem substituto de longe.
##   2. CADA PEÇA DO VALE tem o corte da classe dela (e o que anda, vai na mão ou mora
##      dentro de cômodo não tem), com desvanecer nos adereços e troca seca onde
##      há substituto.
##   3. O SUBSTITUTO COBRE O BURACO: a casa e a árvore nomeada têm um filho que entra
##      onde o modelo começa a sumir (o `begin` dele é o `end` do modelo, seco e SEM
##      margem, que é o que não deixa buraco: ver `pecas_distantes.gd`), vai até FIM,
##      não faz sombra, cabe na caixa do modelo, é barato e NÃO é MeshInstance3D (a
##      casca do cômodo mede por malha); e o modelo desvanece na margem, por cima dele.
##   4. O MAPA ALTO tira o corte e esconde os substitutos, e a volta ao passeio os
##      repõe: pela chamada direta e pela câmera ortográfica (a foto do minimapa).
##   5. O QUE SE DESENHA CAI: de um ponto alto e longe, o vale desenha uma fração dos
##      triângulos das peças; de perto também, só que menos. É a conta que a
##      GPU faz (alcance medido até o centro da caixa de cada malha).
##
## No estilo procedural (`lod_das_pecas_procedural.gd`) as casas e as árvores são caixas e
## malhas feitas em código, baratas, e não ganham alcance nem substituto; sobra no vale o que
## não tem versão procedural (a fazenda, os recursos, os bichos), que é GLB do mesmo jeito, e
## para esse o alcance vale igual: o portão roda as perguntas 2 a 4 nele também.
##
## FALSIFICAÇÃO: `CatalogoAssets.alcance_ligado = false` (o vale de antes) reprova 2, 3
## e 5; sem o gancho do renderizador reprova 4; sem a casa no `CASAS`, reprova 1; dar ao
## substituto a margem da troca seca da mata (15 u, histerese, o buraco) reprova 3 (uma
## FALHA por substituto: 92 no vale).

const PecasDistantes = preload("res://scripts/prototipo_3d/pecas_distantes.gd")

## Quanto os triângulos que se desenham do ponto alto e longe podem ser dos de antes.
const FRACAO_LONGE := 0.25
## E de dentro da praça, onde o que está perto fica.
const FRACAO_PERTO := 0.8
## Quantas peças, no mínimo, o vale tem de ter montado (para o portão não ser vazio).
const PECAS_MINIMAS := 150

var falhas := 0
var vale
var world


## O estilo do vale em que o portão roda: `lod_das_pecas_procedural.gd` o troca.
func _estilo_do_portao() -> String:
	return "tripo"


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("LOD_DAS_PECAS_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	create_timer(900.0).timeout.connect(func() -> void:
		push_error("LOD_DAS_PECAS: limite de 900 segundos excedido")
		quit(2))
	root.get_node("/root/Estilo").modo = _estilo_do_portao()
	if _estilo_do_portao() == "tripo":
		_catalogo()
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(10)
	vale = current_scene
	world = vale.get("world")
	if world == null:
		_conferir(false, "o vale não montou o mundo")
		_fechar()
		return
	var pecas := _pecas_do_vale()
	var por_chave := {}
	for modelo in pecas:
		por_chave[String(modelo.get_meta("peca"))] = int(por_chave.get(String(modelo.get_meta("peca")), 0)) + 1
	print("   peças do catálogo no vale (%s): %d, de %d chaves" % [_estilo_do_portao(), pecas.size(), por_chave.size()])
	if _estilo_do_portao() == "tripo":
		_conferir(pecas.size() >= PECAS_MINIMAS, "o vale montou peças do catálogo (%d, e o mínimo é %d)" % [pecas.size(), PECAS_MINIMAS])
	else:
		# No procedural as casas e as árvores são caixas e malhas feitas em código: sobra no
		# vale só o que não tem versão procedural (a fazenda, os recursos, os bichos), que
		# são GLBs do mesmo jeito. O alcance vale para esses também, e só para eles.
		print("   ", por_chave)
	_cada_peca(pecas)
	_substitutos(pecas)
	await _mapa_alto(pecas)
	if _estilo_do_portao() == "tripo":
		_triangulos(pecas)
	_fechar()


# --- 1. O CATÁLOGO --------------------------------------------------------------

func _catalogo() -> void:
	print("")
	print("1. o catálogo")
	var classes := ["", "construcao", "arvore", "adereco", "planta"]
	var sem_classe_por_pasta := ["personagens/", "animais/", "peixes/", "mar/", "itens/", "moveis/"]
	# #226: pasta nova no catálogo precisa ser escolhida (cenário, com alcance, ou o que anda, vai na
	# mão ou mora dentro): senão a peça entra "sem classe" calada e é desenhada inteira a qualquer distância.
	var com_classe_por_pasta := ["construcoes/", "casas/", "arvores/", "aderecos/"]
	var construcoes_sem_substituto: Array[String] = []
	for chave: String in CatalogoAssets.PECAS:
		var classe: String = CatalogoAssets.classe_de_alcance(chave)
		_conferir(classe in classes, "%s: classe de alcance '%s' não existe" % [chave, classe])
		var arquivo := String(CatalogoAssets.PECAS[chave]["tripo"])
		var pasta_conhecida := false
		for pasta in sem_classe_por_pasta + com_classe_por_pasta:
			pasta_conhecida = pasta_conhecida or arquivo.begins_with(pasta)
		_conferir(pasta_conhecida, "%s mora em '%s', uma pasta que o portão do alcance não conhece: escolha se é cenário (com classe) ou se anda, vai na mão ou mora dentro" % [chave, arquivo.get_base_dir()])
		for pasta in sem_classe_por_pasta:
			if arquivo.begins_with(pasta):
				_conferir(classe == "", "%s mora em %s e não pode ter alcance (anda, vai na mão ou está dentro do cômodo)" % [chave, pasta])
		if CatalogoAssets.SEM_ALCANCE.has(chave):
			_conferir(classe == "" and not String(CatalogoAssets.SEM_ALCANCE[chave]).strip_edges().is_empty(), "%s está em SEM_ALCANCE e precisa do motivo escrito" % chave)
		elif arquivo.begins_with("construcoes/") or arquivo.begins_with("casas/") or arquivo.begins_with("arvores/") or arquivo.begins_with("aderecos/"):
			_conferir(classe != "", "%s é do cenário e ficou sem classe de alcance (ou entra em SEM_ALCANCE, com o motivo)" % chave)
		if classe == "":
			continue
		var pequeno: float = CatalogoAssets.alcance_de(chave, 0.5)
		var grande: float = CatalogoAssets.alcance_de(chave, 40.0)
		_conferir(pequeno >= CatalogoAssets.ALCANCE_MINIMO[classe] - 0.001 and grande <= CatalogoAssets.ALCANCE_MAXIMO[classe] + 0.001, "%s: o alcance fica dentro dos limites da classe %s" % [chave, classe])
		_conferir(CatalogoAssets.alcance_de(chave, 3.0) <= CatalogoAssets.alcance_de(chave, 6.0) + 0.001, "%s: o alcance não encolhe com o tamanho" % chave)
		# Toda construção de 4,5 u para cima, menos o portão (grade) e o que está em
		# SEM_ALCANCE, tem a casa de longe.
		var medida := float(CatalogoAssets.PECAS[chave].get("largura", CatalogoAssets.PECAS[chave].get("altura", 0.0)))
		if classe == "construcao" and medida >= CatalogoAssets.TAMANHO_DA_CASA and chave != "portao_fazenda" and not PecasDistantes.tem_casa(chave):
			construcoes_sem_substituto.append(chave)
	_conferir(construcoes_sem_substituto.is_empty(), "construção sem a casa de longe em PecasDistantes.CASAS: %s" % str(construcoes_sem_substituto))
	for chave in ["pier", "ponte", "mirante", "saveiro", "bote", "canoa", "canoa_amarela"]:
		_conferir(CatalogoAssets.SEM_ALCANCE.has(chave) and CatalogoAssets.alcance_de(chave, 9.0) == 0.0, "%s fica inteiro a qualquer distância" % chave)
	# Os números que o dono lê: o pequeno some entre 60 e 90 u, a casa e a igreja mais longe.
	for chave in ["pote", "candeeiro", "banco", "tumulo", "lenha", "poco"]:
		var medida_pequena := float(CatalogoAssets.PECAS[chave].get("largura", CatalogoAssets.PECAS[chave].get("altura", 1.0)))
		var alcance: float = CatalogoAssets.alcance_de(chave, medida_pequena)
		_conferir(alcance >= 60.0 and alcance <= 100.0, "o adereço %s (%.1f u) some entre 60 e 100 u (%.0f)" % [chave, medida_pequena, alcance])
	_conferir(CatalogoAssets.alcance_de("casa_taipa", 6.5) > CatalogoAssets.alcance_de("pote", 0.9) * 1.5, "a casa vai bem mais longe que o pote")
	_conferir(CatalogoAssets.alcance_de("igreja", 10.0) >= CatalogoAssets.alcance_de("casa_taipa", 6.5), "a igreja vai tão longe quanto a casa, ou mais")
	# A caixa e o telhado de cada casa: barato, com as cores medidas.
	var caixa := AABB(Vector3(-3.0, 0.0, -2.5), Vector3(6.0, 4.0, 5.0))
	for chave: String in PecasDistantes.CASAS:
		var triangulos := PecasDistantes.triangulos_da_casa(chave, caixa)
		_conferir(triangulos == 14, "a casa de longe de %s tem 14 triângulos (%d)" % [chave, triangulos])
		var cores: Dictionary = PecasDistantes.CASAS[chave]
		for lado in ["parede", "telha"]:
			var cor: Color = cores[lado]
			_conferir(cor.get_luminance() > 0.04 and cor.get_luminance() < 0.95, "%s: a cor da %s da casa de longe é de verdade" % [chave, lado])
	_conferir(PecasDistantes.Copas.triangulos_por_copa() <= 80, "a copa de longe da árvore nomeada é barata")
	# A casa e a árvore saindo de `instanciar` sozinhas: o substituto sem sombra, entrando onde
	# o modelo sai, e filho dele.
	var pai := Node3D.new()
	for chave in ["casa_taipa", "igreja", "mangueira", "coqueiro"]:
		var modelo := CatalogoAssets.instanciar(chave, pai, Vector3.ZERO, 1.0, 0.7)
		_conferir(modelo != null, "%s sai de instanciar" % chave)
		if modelo == null:
			continue
		var longe := modelo.get_node_or_null(PecasDistantes.NOME) as MultiMeshInstance3D
		_conferir(longe != null, "%s sai de instanciar com o substituto de longe" % chave)
		if longe == null:
			continue
		_conferir(longe.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s: o substituto sai sem sombra" % chave)
		var fim: float = PecasDistantes.geometrias_do_modelo(modelo)[0].visibility_range_end
		_conferir(fim > 60.0 and longe.visibility_range_begin == fim and longe.visibility_range_begin_margin == 0.0 and longe.visibility_range_end == PecasDistantes.FIM, "%s: o substituto entra aos %.0f u, seco, e vai a %.0f" % [chave, fim, PecasDistantes.FIM])
	pai.free()
	# E sem o alcance ligado (o vale de antes), nada disso nasce.
	var ligado_antes := CatalogoAssets.alcance_ligado
	CatalogoAssets.alcance_ligado = false
	var antigo := Node3D.new()
	var casa_antiga := CatalogoAssets.instanciar("casa_taipa", antigo, Vector3.ZERO)
	_conferir(casa_antiga != null and casa_antiga.get_node_or_null(PecasDistantes.NOME) == null and PecasDistantes.geometrias_do_modelo(casa_antiga)[0].visibility_range_end == 0.0, "com o alcance desligado a casa sai como era: sem corte e sem substituto")
	antigo.free()
	CatalogoAssets.alcance_ligado = ligado_antes


# --- 2. CADA PEÇA DO VALE -------------------------------------------------------

## Os modelos que o catálogo instanciou, onde quer que estejam no vale: o que traz a
## marca `peca` (posta em `CatalogoAssets.dar_alcance` para toda chave).
func _pecas_do_vale() -> Array[Node3D]:
	var lista: Array[Node3D] = []
	var pilha: Array[Node] = [vale]
	while not pilha.is_empty():
		var no: Node = pilha.pop_back()
		if no is SubViewport:
			continue
		for filho in no.get_children():
			pilha.append(filho)
		if no is Node3D and no.has_meta("peca"):
			lista.append(no as Node3D)
	return lista


func _tamanho(modelo: Node3D) -> float:
	var caixa: AABB = modelo.get_meta("limites", AABB())
	return maxf(caixa.size.x, maxf(caixa.size.y, caixa.size.z))


func _cada_peca(pecas: Array[Node3D]) -> void:
	print("")
	print("2. cada peça do vale (%d)" % pecas.size())
	var por_classe := {}
	for modelo in pecas:
		var chave := String(modelo.get_meta("peca"))
		var classe: String = CatalogoAssets.classe_de_alcance(chave)
		por_classe[classe] = int(por_classe.get(classe, 0)) + 1
		var fim: float = CatalogoAssets.alcance_de(chave, _tamanho(modelo))
		var tem_substituto := modelo.get_node_or_null(PecasDistantes.NOME) != null
		var geometrias := PecasDistantes.geometrias_do_modelo(modelo)
		_conferir(not geometrias.is_empty() or classe == "", "%s (%s) não tem geometria" % [chave, modelo.get_path()])
		_conferir(modelo.is_in_group(PecasDistantes.GRUPO) == (classe != ""), "%s: o modelo %s no grupo do alcance" % [chave, "devia estar" if classe != "" else "não devia estar"])
		for geometria in geometrias:
			if classe == "":
				# O que anda, vai na mão ou mora dentro não ganha o alcance do cenário (o bicho
				# tem o corte dele, de `animador_bicho.gd`, e não é o daqui).
				_conferir(not geometria.has_meta("lod_fim"), "%s (anda, vai na mão ou mora dentro): ganhou o alcance do cenário" % chave)
				continue
			_conferir(is_equal_approx(geometria.visibility_range_end, fim), "%s: o corte é o da classe %s (%.1f), e é %.1f" % [chave, classe, fim, geometria.visibility_range_end])
			# O modelo sempre desvanece (sem estado: a troca seca com margem deixava buraco).
			_conferir(geometria.visibility_range_fade_mode == GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF, "%s: o modelo desvanece no fim do alcance" % chave)
			var margem: float = CatalogoAssets.MARGEM_DA_TROCA if tem_substituto else CatalogoAssets.MARGEM_DO_DESVANECER
			_conferir(is_equal_approx(geometria.visibility_range_end_margin, margem), "%s: a faixa em que desvanece é de %.0f u (%.0f)" % [chave, margem, geometria.visibility_range_end_margin])
	print("   por classe: ", por_classe)
	if _estilo_do_portao() == "tripo":
		_conferir(int(por_classe.get("construcao", 0)) >= 20, "as construções do vale têm alcance (%d)" % int(por_classe.get("construcao", 0)))
		_conferir(int(por_classe.get("arvore", 0)) >= 20, "as árvores nomeadas do vale têm alcance (%d)" % int(por_classe.get("arvore", 0)))
		_conferir(int(por_classe.get("adereco", 0)) >= 30, "os adereços do vale têm alcance (%d)" % int(por_classe.get("adereco", 0)))


# --- 3. O SUBSTITUTO COBRE O BURACO ---------------------------------------------

func _substitutos(pecas: Array[Node3D]) -> void:
	print("")
	print("3. o substituto cobre o buraco")
	var casas := 0
	var copas := 0
	var mexidos_pelo_comodo := 0
	for modelo in pecas:
		var chave := String(modelo.get_meta("peca"))
		var classe: String = CatalogoAssets.classe_de_alcance(chave)
		var tamanho := _tamanho(modelo)
		var deve := (classe == "construcao" and tamanho >= CatalogoAssets.TAMANHO_DA_CASA and PecasDistantes.tem_casa(chave)) or classe == "arvore"
		var longe := modelo.get_node_or_null(PecasDistantes.NOME)
		_conferir((longe != null) == deve, "%s (%s, %.1f u): %s substituto de longe" % [chave, classe, tamanho, "devia ter" if deve else "não devia ter"])
		if longe == null or not deve:
			continue
		if classe == "construcao":
			casas += 1
		else:
			copas += 1
		var por_dentro := longe is MultiMeshInstance3D and not (longe is MeshInstance3D)
		_conferir(por_dentro, "%s: o substituto é MultiMeshInstance3D (a casca mede por MeshInstance3D)" % chave)
		if not (longe is MultiMeshInstance3D):
			continue
		var visual := longe as MultiMeshInstance3D
		var geometrias := PecasDistantes.geometrias_do_modelo(modelo)
		var fim: float = geometrias[0].visibility_range_end if not geometrias.is_empty() else -1.0
		var margem: float = geometrias[0].visibility_range_end_margin if not geometrias.is_empty() else -1.0
		_conferir(visual.visibility_range_begin == fim, "%s: o substituto aparece onde o modelo começa a sumir (%.0f e %.0f)" % [chave, visual.visibility_range_begin, fim])
		_conferir(visual.visibility_range_begin_margin == 0.0, "%s: o substituto não tem margem (margem é histerese, e histerese deixa buraco)" % chave)
		_conferir(visual.visibility_range_fade_mode == GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED, "%s: o substituto aparece seco" % chave)
		_conferir(margem > 0.0 and visual.visibility_range_begin <= fim + margem, "%s: o substituto já está lá quando o modelo acaba de sumir (%.0f, e o modelo some aos %.0f)" % [chave, visual.visibility_range_begin, fim + margem])
		_conferir(visual.visibility_range_end == PecasDistantes.FIM, "%s: o substituto vai até %.0f u" % [chave, PecasDistantes.FIM])
		# O cômodo liga e desliga a sombra de tudo o que está sob a casca (`Comodo.por_dentro`),
		# e o substituto, filho do modelo, entra na conta nas casas que têm cômodo: o
		# vale monta a sombra OFF (conferida em `_catalogo`) e o cômodo pode mexer nela.
		if visual.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			mexidos_pelo_comodo += 1
		_conferir(visual.multimesh != null and visual.multimesh.instance_count == 1 and visual.multimesh.mesh != null, "%s: o substituto é uma instância" % chave)
		_conferir(visual.get_parent() == modelo, "%s: o substituto é filho do modelo (anda e some com ele)" % chave)
		if visual.multimesh == null or visual.multimesh.mesh == null:
			continue
		var triangulos: int = visual.multimesh.mesh.surface_get_array_len(0) / 3
		_conferir(triangulos <= (14 if classe == "construcao" else 80), "%s: o substituto é barato (%d triângulos)" % [chave, triangulos])
		# Cabe na caixa do modelo (com 15% de folga): sem invadir a casa do vizinho
		# nem afundar no chão.
		var caixa_do_modelo := CatalogoAssets.limites(modelo)
		var esperada: AABB = visual.multimesh.mesh.get_aabb()
		if classe == "arvore":
			esperada = PecasDistantes.forma_da_copa(chave, caixa_do_modelo) * esperada
		var folga := caixa_do_modelo.size * 0.15
		var cabe := AABB(caixa_do_modelo.position - folga, caixa_do_modelo.size + folga * 2.0).encloses(esperada)
		_conferir(cabe, "%s: o substituto cabe na caixa do modelo (%s fora de %s)" % [chave, str(esperada), str(caixa_do_modelo)])
	_conferir(mexidos_pelo_comodo <= 4, "só as casas com cômodo (quatro) têm o substituto com a sombra mexida (%d)" % mexidos_pelo_comodo)
	if _estilo_do_portao() == "tripo":
		_conferir(casas >= 20, "as casas do vale têm substituto (%d)" % casas)
		_conferir(copas >= 20, "as árvores nomeadas do vale têm substituto (%d)" % copas)
	print("   %d casas e %d árvores com substituto" % [casas, copas])
	# Nenhum substituto fora de modelo: ele nasce e morre com a peça.
	var soltos := 0
	for no in vale.find_children(PecasDistantes.NOME, "MultiMeshInstance3D", true, false):
		if not (no.get_parent() is Node3D and (no.get_parent() as Node3D).has_meta("peca")):
			soltos += 1
	_conferir(soltos == 0, "nenhum substituto solto fora de um modelo (%d)" % soltos)


# --- 4. O MAPA ALTO -------------------------------------------------------------

func _mapa_alto(todas: Array[Node3D]) -> void:
	var pecas: Array[Node3D] = []
	for modelo in todas:
		if modelo.is_in_group(PecasDistantes.GRUPO):
			pecas.append(modelo)
	print("")
	print("4. o mapa alto")
	var antes := _estado(pecas)
	CatalogoAssets.modo_mapa(self, true)
	_conferir(_todas_sem_corte(pecas), "no mapa alto nenhuma peça tem corte (chamada direta)")
	_conferir(_substitutos_escondidos(pecas, true), "no mapa alto os substitutos se escondem (chamada direta)")
	CatalogoAssets.modo_mapa(self, false)
	_conferir(_estado(pecas) == antes, "a volta ao passeio repõe o corte e os substitutos (chamada direta)")
	# Pela câmera ortográfica, que é o que o mapa, o menu e a foto do minimapa fazem.
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3000.0
	vale.add_child(camera)
	camera.make_current()
	await _frames(4)
	_conferir(_todas_sem_corte(pecas), "câmera ortográfica: nenhuma peça tem corte")
	_conferir(_substitutos_escondidos(pecas, true), "câmera ortográfica: os substitutos se escondem")
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	await _frames(4)
	_conferir(_estado(pecas) == antes, "a volta à câmera de passeio repõe o corte e os substitutos")
	camera.queue_free()
	await _frames(2)


func _estado(pecas: Array[Node3D]) -> Array:
	var estado: Array = []
	for modelo in pecas:
		var linha: Array = []
		for geometria in PecasDistantes.geometrias_do_modelo(modelo):
			linha.append(geometria.visibility_range_end)
		var longe := modelo.get_node_or_null(PecasDistantes.NOME) as Node3D
		linha.append(longe.visible if longe != null else null)
		estado.append(linha)
	return estado


func _todas_sem_corte(pecas: Array[Node3D]) -> bool:
	for modelo in pecas:
		for geometria in PecasDistantes.geometrias_do_modelo(modelo):
			if geometria.visibility_range_end != 0.0:
				return false
	return true


func _substitutos_escondidos(pecas: Array[Node3D], escondidos: bool) -> bool:
	var algum := false
	for modelo in pecas:
		var longe := modelo.get_node_or_null(PecasDistantes.NOME) as Node3D
		if longe == null:
			continue
		algum = true
		if longe.visible == escondidos:
			return false
	return algum


# --- 5. O QUE SE DESENHA CAI ----------------------------------------------------

func _triangulos_da_malha(malha: Mesh) -> int:
	if malha == null:
		return 0
	var total := 0
	for s in malha.get_surface_count():
		total += malha.surface_get_array_len(s) / 3 if malha.surface_get_array_index_len(s) == 0 else malha.surface_get_array_index_len(s) / 3
	return total


## Quantos triângulos das peças a câmera em `de` desenha: com o alcance (o corte de
## cada malha e os substitutos que entram) ou sem ele (o vale de antes: tudo, sempre).
func _desenhados(pecas: Array[Node3D], de: Vector3, com_alcance: bool) -> int:
	var total := 0
	for modelo in pecas:
		if not modelo.is_visible_in_tree():
			continue
		var caixa := AABB()
		var primeiro := true
		var triangulos := 0
		for geometria in PecasDistantes.geometrias_do_modelo(modelo):
			if not (geometria is MeshInstance3D):
				continue
			var malha := geometria as MeshInstance3D
			var no_mundo := malha.global_transform * malha.get_aabb()
			caixa = no_mundo if primeiro else caixa.merge(no_mundo)
			primeiro = false
			var distancia := de.distance_to(no_mundo.get_center())
			# O modelo desvanece de `end` até `end` + a margem, e se desenha até lá (medido:
			# tools/prototipo_3d/medir_lod_das_pecas.gd --modo=troca).
			var fim := malha.visibility_range_end + malha.visibility_range_end_margin
			if not com_alcance or malha.visibility_range_end == 0.0 or distancia < fim:
				triangulos += _triangulos_da_malha(malha.mesh)
		total += triangulos
		if not com_alcance or primeiro:
			continue
		var longe := modelo.get_node_or_null(PecasDistantes.NOME) as MultiMeshInstance3D
		if longe != null and longe.visible:
			var distancia := de.distance_to(caixa.get_center())
			if distancia >= longe.visibility_range_begin + longe.visibility_range_begin_margin and distancia < longe.visibility_range_end:
				total += _triangulos_da_malha(longe.multimesh.mesh)
	return total


func _triangulos(todas: Array[Node3D]) -> void:
	print("")
	print("5. o que se desenha cai")
	# Só as peças do cenário: o bicho tem o corte dele, que não é o daqui. E só as que
	# ainda existem: entre a colheita da lista e esta parte, o mapa alto e a volta à
	# câmera de passeio deixam o corte trocar um modelo distante pelo substituto — o
	# modelo sai, e perguntar a um nó liberado derrubava o portão no perfil limpo.
	var pecas: Array[Node3D] = []
	for modelo in todas:
		if is_instance_valid(modelo) and modelo.is_in_group(PecasDistantes.GRUPO):
			pecas.append(modelo)
	var mirante: Vector3 = world.ancoras.get("Mirante", Vector3.ZERO)
	var praca: Vector3 = Vector3.ZERO
	var pier: Vector3 = world.ancoras.get("Pier", Vector3.ZERO)
	var pontos := {
		"praça (no chão)": [praca + Vector3(0, 3.0, 0), FRACAO_PERTO],
		"mirante (alto)": [mirante + Vector3(0, 12.0, 0), FRACAO_LONGE],
		"píer (no chão)": [pier + Vector3(0, 3.0, 0), FRACAO_PERTO],
		"baía (longe, a 300 u do píer)": [pier + Vector3(300, 6.0, 0), FRACAO_LONGE],
	}
	var tem_longe_de_verdade := false
	for rotulo: String in pontos:
		var onde: Vector3 = pontos[rotulo][0]
		var sem := _desenhados(pecas, onde, false)
		var com := _desenhados(pecas, onde, true)
		var limite := float(pontos[rotulo][1])
		print("   %-32s sem alcance %7d  com alcance %7d  (%.0f%%)" % [rotulo, sem, com, 100.0 * float(com) / maxf(float(sem), 1.0)])
		_conferir(sem > 100000, "%s: o vale de antes desenha mais de 100 mil triângulos de peças (%d)" % [rotulo, sem])
		_conferir(float(com) <= float(sem) * limite, "%s: com o alcance se desenha no máximo %.0f%% dos triângulos de antes (%d de %d)" % [rotulo, limite * 100.0, com, sem])
		if limite == FRACAO_LONGE and float(com) <= float(sem) * limite:
			tem_longe_de_verdade = true
	_conferir(tem_longe_de_verdade, "de longe o vale desenha uma fração dos triângulos de antes")
	# E o buraco: de nenhum ponto uma casa some sem o substituto no lugar.
	var sumiu := 0
	for modelo in pecas:
		var longe := modelo.get_node_or_null(PecasDistantes.NOME) as MultiMeshInstance3D
		if longe == null:
			continue
		for geometria in PecasDistantes.geometrias_do_modelo(modelo):
			if geometria.visibility_range_end > 0.0 and longe.visibility_range_begin > geometria.visibility_range_end:
				sumiu += 1
	_conferir(sumiu == 0, "nenhuma peça fica sem o substituto entre o fim do modelo e o começo dele (%d)" % sumiu)


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("LOD_DAS_PECAS_OK (%s): cada peça do cenário tem o corte da classe e do tamanho dela, a casa e a árvore nomeada têm o substituto barato que entra onde o modelo sai, o mapa alto tira o corte, e de longe se desenha uma fração dos triângulos de antes" % _estilo_do_portao())
	else:
		print("lod_das_pecas (%s): %d falha(s)" % [_estilo_do_portao(), falhas])
	quit(1 if falhas > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _mundo_pronto() -> void:
	for i in range(6000):
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
