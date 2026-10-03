extends SceneTree
## EXTRAI A GEOMETRIA REAL DO VALE EM VOLTA DO SOBREVOO DO MENU, NUM ESTILO VISUAL.
##
##   godot --headless --path . --script res://tools/prototipo_3d/sobrevoo/extrair_geometria.gd -- --estilo=tripo --saida=C:/.../sobrevoo
##   godot ... -- --estilo=procedural --saida=...      (um estilo por vez: cada um monta o vale)
##   godot ... -- --estilo=uniao --saida=...           (junta os dois ja extraidos, sem montar)
##
## Por que triangulo e nao AABB: a tentativa reprovada media obstaculo pela caixa de
## cada malha, e a caixa do coqueiro do Tripo tem 38 m de altura por 49 m de largura.
## Medido nos triangulos (validacao abaixo), a 16-18 m do chao ele ocupa ~90 m2: o
## tronco inclinado (~3 m) e as pontas das folhas, que caem ate uns 10-12 m. A caixa
## inventava uma parede de 49 m e o voo fugia dela aos trancos.
##
## O que faz: monta a abertura no estilo pedido (definindo Estilo.modo DIRETO, sem
## definir(), que gravaria a preferencia do jogador), espera o vale, le ancoras e
## escala, recorta a regiao da rota de hoje crescida de 120 m e rasteriza os
## triangulos de todo MeshInstance3D visivel e de toda instancia de MultiMesh (LOD0 e
## os LODs gerados pelo importador, em uniao) numa grade de 0,5 m: por celula, um
## bitmask de faixas de 2 m acima do chao da celula (geometria.gd explica o formato).
##
## MultiMesh no --headless: o RenderingServer dummy NAO guarda instancia de MultiMesh
## (get_instance_transform devolve a identidade), entao a mata lida do vale vivo viraria
## arvores empilhadas na origem. As transformacoes vem de regiao_gravada.gd: a regiao
## reconstruida com as mesmas sementes, conferida contra o vale vivo (plantio de cada
## arvore, transformacao dos coqueiros, instancias por bloco); se divergir, aborta.
##
## Valida no proprio vale: chao bilinear x ground_height_at; ocupacao EXATA (triangulo
## recortado por coluna) de um coqueiro, uma casa e uma arvore grande contra a grade;
## folga da grade x distancia real a malha pela fisica do Godot; e o eixo do tronco das
## arvores nomeadas pelo cilindro de colisao do jogo. Vai tudo no cabecalho.
##
## Cada objeto (uma malha, ou uma instancia de MultiMesh) e PREENCHIDO na vertical,
## coluna a coluna, entre a sua faixa mais baixa e a mais alta: copa de mangueira e
## casa do Tripo sao cascas fechadas, e a camera no miolo delas estaria "dentro" do
## objeto, longe de qualquer triangulo. O preenchimento e por objeto para nao fechar
## o vao entre objetos diferentes (copa de coqueiro sobre um telhado).
##
## Fica de fora, com o motivo gravado no cabecalho:
## - TERRENO e o que e drapeado nele (filhos do renderizador da regiao a menos de 1 m
##   do chao: terra, areas, ruas, praia, leito e agua de rio, terreiros): o chao vira a
##   altura de referencia de cada celula (ground_height_at), e nao ocupacao; marcar a
##   faixa 0 em toda celula so apagaria a informacao. A altura do olho sobre ele e a
##   restricao H2 do avaliador, e o desvio entre a malha drapeada e ground_height_at e
##   medido e gravado.
## - AGUA (mar e rio, pelos shaders de agua) e fundo do mar (abaixo da agua).
## - PERSONAGENS com esqueleto (nao ficam parados no caminho).
## - Decalques planos (pe das arvores).
## Geometria abaixo do chao da celula nao conta.

const Geometria = preload("res://tools/prototipo_3d/sobrevoo/geometria.gd")
const CENA := "res://scenes/prototipo_3d/abertura.tscn"
const CELULA_M := 0.5
const MARGEM_M := 120.0
## Triangulo com planta maior que isto e dividido antes da caixa: parede e telhado
## grandes viram pedacos de ate 1 m, e a caixa conservadora nao vira um bloco.
const SUBDIVIDIR_M := 1.0
const RENTE_AO_CHAO_M := 1.0
const GIGANTE_M := 400.0
const SHADERS_DE_AGUA := ["agua_mar.gdshader", "agua_rio.gdshader", "foz_rio.gdshader"]
const CAMADAS_CAMPO_M := [10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0, 20.0, 21.0, 22.0]
const TETO_CAMPO_M := 40.0
const ESPECIES_ARVORE := ["mangueira", "jaqueira", "cajueiro", "pau_brasil", "pau-brasil", "dende", "bananeira", "ipe", "embauba", "mata", "castanhola", "aroeira", "mangue", "piacava", "ingazeiro", "inga", "clusia", "pitangueira", "jenipapeiro", "arvore", "tree"]
const CHAVES_CASA := ["casa", "venda", "igreja", "capela"]

var _args := {}
var _saida := ""
var _estilo := ""
var _s := 4.0
var _c := 0.125
var _inv_c := 8.0
var _ox := 0.0
var _oz := 0.0
var _nx := 0
var _nz := 0
var _sub_u := 0.25
var _gigante_u := 100.0
var _chao := PackedFloat32Array()
var _mascara := PackedInt32Array()
var _tmp := PackedInt32Array()
var _usar_lods := true
var _preencher := true
var _faces_cache := {}
var _lod_info := {}
var _log2 := {}
var _rota := PackedVector2Array()
var _objetos: Array = []
var _excluidos: Array = []
var _avisos: Array = []
var _contagens := {
	"malhas_vistas": 0, "malhas_rasterizadas": 0, "instancias_multimesh_vistas": 0,
	"instancias_rasterizadas": 0, "triangulos_lod0": 0, "triangulos_lods_extras": 0,
	"triangulos_na_regiao": 0, "triangulos_gigantes_ignorados": 0, "celulas_marcadas_por_preenchimento": 0,
	"bits_antes_do_preenchimento": 0, "bits_depois_do_preenchimento": 0,
	"excluidas_agua": 0, "excluidas_chao": 0, "excluidas_personagem": 0, "excluidas_decalque": 0,
	"invisiveis": 0, "fora_da_regiao": 0, "outros_nos_visuais": {},
}
var _tempos := {}
var _t0 := 0
var _conferencia_multimesh := {}
## So para o chao bilinear durante a extracao (a mascara ainda esta sendo feita).
var _geo_chao


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := {}
	for argumento in OS.get_cmdline_user_args():
		var texto := String(argumento)
		if texto.begins_with("--") and texto.contains("="):
			args[texto.substr(2, texto.find("=") - 2)] = texto.substr(texto.find("=") + 1)
		elif texto.begins_with("--"):
			args[texto.substr(2)] = "1"
	await _executar(args)


## Os portoes tests/sobrevoo_livre*.gd herdam este script e chamam isto direto, com
## --conferir=<trajeto>: monta o vale, rasteriza e confere o trajeto, sem gravar nada.
func _executar(args: Dictionary) -> void:
	_args = args
	_t0 = Time.get_ticks_msec()
	for k in range(32):
		_log2[1 << k] = k
	_saida = String(_args.get("saida", "user://sobrevoo"))
	_estilo = String(_args.get("estilo", "tripo"))
	_usar_lods = String(_args.get("lods", "1")) != "0"
	_preencher = String(_args.get("preencher", "1")) != "0"
	DirAccess.make_dir_recursive_absolute(_saida)
	var teto := float(_args.get("teto", "1500"))
	create_timer(teto).timeout.connect(func() -> void:
		push_error("EXTRAIR: passou de %d s sem terminar" % int(teto))
		quit(2))
	if _estilo == "uniao":
		_uniao()
		return
	if _estilo not in ["tripo", "procedural"]:
		push_error("EXTRAIR: --estilo deve ser tripo, procedural ou uniao")
		quit(1)
		return
	await _extrair()


func _log(texto: String) -> void:
	print("[%6.1f s] %s" % [(Time.get_ticks_msec() - _t0) / 1000.0, texto])


func _marca_tempo(nome: String, desde: int) -> int:
	var agora := Time.get_ticks_msec()
	_tempos[nome] = snappedf((agora - desde) / 1000.0, 0.01)
	return agora


# ---------------------------------------------------------------------------
# Um estilo: monta o vale e rasteriza.
# ---------------------------------------------------------------------------

func _extrair() -> void:
	# Direto no autoload: definir() gravaria a escolha na preferencia do jogador.
	var estilo_no := root.get_node("/root/Estilo")
	estilo_no.set("modo", _estilo)
	var marco := Time.get_ticks_msec()
	if change_scene_to_file(CENA) != OK:
		push_error("EXTRAIR: a abertura nao carrega")
		quit(1)
		return
	var mundo: Node3D = null
	while true:
		await process_frame
		mundo = get_first_node_in_group("mundo") as Node3D
		if mundo != null and bool(mundo.get("construido")):
			break
	for i in range(3):
		await process_frame
	marco = _marca_tempo("montar_vale", marco)
	var abertura: Node = current_scene
	var cenario := mundo
	var tripo_de_fato := bool(cenario.call("estilo_tripo"))
	if tripo_de_fato != (_estilo == "tripo"):
		push_error("EXTRAIR: pedi %s e o vale montou %s" % [_estilo, "tripo" if tripo_de_fato else "procedural"])
		quit(1)
		return
	_log("vale montado no estilo %s" % _estilo)
	_s = float(cenario.call("get_meters_per_unit"))
	var ancoras: Dictionary = cenario.get("ancoras")
	var pier: Vector3 = ancoras.get("Pier", Vector3.ZERO)
	var praca: Vector3 = ancoras.get("Praça", pier)
	var regiao_no: Node = cenario.get("_region")
	_c = CELULA_M / _s
	_inv_c = 1.0 / _c
	_sub_u = SUBDIVIDIR_M / _s
	_gigante_u = GIGANTE_M / _s
	# Regiao: a rota de hoje (e o alvo dela) crescida de MARGEM_M, alinhada a grade
	# global de 0,5 m (multiplos da celula a partir da origem), para os estilos casarem.
	var minimo := Vector2(INF, INF)
	var maximo := Vector2(-INF, -INF)
	_rota = PackedVector2Array()
	var chao_real := Callable(cenario, "ground_height_at")
	for i in range(2880):
		var p := Geometria.rota_base(pier, praca, _s, float(i) / 2880.0)
		var xz := Vector2(p.x, p.z)
		minimo = minimo.min(xz)
		maximo = maximo.max(xz)
		if i % 8 == 0:
			_rota.append(xz)
	var margem := MARGEM_M / _s
	_ox = floorf((minimo.x - margem) / _c) * _c
	_oz = floorf((minimo.y - margem) / _c) * _c
	_nx = ceili((maximo.x + margem - _ox) / _c)
	_nz = ceili((maximo.y + margem - _oz) / _c)
	_log("regiao: origem (%.3f, %.3f) u, %d x %d celulas (%.0f x %.0f m)" % [_ox, _oz, _nx, _nz, _nx * CELULA_M, _nz * CELULA_M])
	# Chao no centro de cada celula, pela mesma funcao que o voo usa.
	_chao = PackedFloat32Array()
	_chao.resize(_nx * _nz)
	for iz in range(_nz):
		var z := _oz + (iz + 0.5) * _c
		var linha := iz * _nx
		for ix in range(_nx):
			_chao[linha + ix] = cenario.ground_height_at(Vector3(_ox + (ix + 0.5) * _c, 0.0, z))
	marco = _marca_tempo("chao_por_celula", marco)
	_log("chao calculado")
	_mascara = PackedInt32Array()
	_mascara.resize(_nx * _nz)
	_geo_chao = Geometria.new()
	_geo_chao.iniciar(Vector2(_ox, _oz), _c, _nx, _nz, _s, _mascara, _chao)
	# Coleta: todo no visual do mundo 3D principal (sem SubViewport nem interface).
	var pilha: Array[Node] = [abertura]
	var malhas: Array[MeshInstance3D] = []
	var blocos: Array[MultiMeshInstance3D] = []
	while not pilha.is_empty():
		var no: Node = pilha.pop_back()
		if no is SubViewport or no is CanvasLayer:
			continue
		for filho in no.get_children():
			pilha.append(filho)
		if no is MeshInstance3D:
			malhas.append(no)
		elif no is MultiMeshInstance3D:
			blocos.append(no)
		elif no is GeometryInstance3D:
			var classe := no.get_class()
			var outros: Dictionary = _contagens["outros_nos_visuais"]
			outros[classe] = int(outros.get(classe, 0)) + 1
	_log("%d MeshInstance3D e %d MultiMeshInstance3D na cena" % [malhas.size(), blocos.size()])
	var regiao_rect := Rect2(_ox, _oz, _nx * _c, _nz * _c)
	for mi in malhas:
		_contagens["malhas_vistas"] += 1
		if not mi.is_visible_in_tree() or mi.mesh == null:
			_contagens["invisiveis"] += 1
			continue
		var caixa := mi.global_transform * mi.get_aabb()
		if not regiao_rect.intersects(Rect2(caixa.position.x, caixa.position.z, caixa.size.x, caixa.size.z), true):
			_contagens["fora_da_regiao"] += 1
			continue
		var motivo := _motivo_de_exclusao(mi)
		if motivo != "":
			_contagens["excluidas_" + motivo] += 1
			_excluidos.append({"no": _rotulo_no(mi), "motivo": motivo})
			continue
		var faces := mi.global_transform * _faces(mi.mesh)
		if mi.get_parent() == regiao_no:
			# Filho do renderizador da regiao: terreno e o que e drapeado nele, salvo prova
			# em contrario (algum vertice a mais de RENTE_AO_CHAO_M do chao).
			var altura := _altura_maxima_sobre_chao(faces)
			if altura <= RENTE_AO_CHAO_M:
				_contagens["excluidas_chao"] += 1
				_excluidos.append({"no": _rotulo_no(mi), "motivo": "chao", "altura_max_m": snappedf(altura, 0.01), "desvio_do_chao_m": snappedf(_desvio_da_malha_drapeada(faces), 0.001)})
				continue
			_avisos.append("filho da regiao acima do chao entra como obstaculo: %s (%.1f m)" % [_rotulo_no(mi), altura])
		var objeto := {"rotulo": _rotulo_no(mi) + " | " + _rotulo_malha(mi.mesh), "aabb": caixa, "no": mi, "instancia": -1}
		_rasterizar_e_registrar(objeto, faces, caixa, mi.mesh)
		_contagens["malhas_rasterizadas"] += 1
	# MultiMesh: no --headless o RenderingServer dummy nao guarda as instancias
	# (get_instance_transform devolve a identidade). As transformacoes vem da regiao
	# reconstruida com as mesmas sementes (regiao_gravada.gd), conferida contra o vale vivo.
	marco = _marca_tempo("rasterizar_malhas", marco)
	var regravada := await _regravar_regiao(cenario, regiao_no, tripo_de_fato, blocos)
	marco = _marca_tempo("reconstruir_regiao", marco)
	if not bool(regravada["ok"]):
		push_error("EXTRAIR: a regiao reconstruida nao bate com o vale vivo: " + JSON.stringify(regravada["conferencia"]))
		quit(1)
		return
	_conferencia_multimesh = regravada["conferencia"]
	_log("regiao reconstruida e conferida: %s" % JSON.stringify(_conferencia_multimesh["resumo"]))
	var base_regiao := (regiao_no as Node3D).global_transform
	for registro in regravada["gravados"]:
		var malha: Mesh = registro["mesh"]
		var transforms: Array = registro["transforms"]
		var quantas := transforms.size()
		_contagens["instancias_multimesh_vistas"] += quantas
		var caixa_malha := malha.get_aabb()
		if caixa_malha.size.y < 0.01:
			_contagens["excluidas_decalque"] += quantas
			_excluidos.append({"no": String(registro["nome"]), "motivo": "decalque", "instancias": quantas})
			continue
		var faces_locais := _faces(malha)
		for i in range(quantas):
			var forma: Transform3D = base_regiao * (transforms[i] as Transform3D)
			if absf(forma.basis.determinant()) < 1e-9:
				continue
			var caixa := forma * caixa_malha
			if not regiao_rect.intersects(Rect2(caixa.position.x, caixa.position.z, caixa.size.x, caixa.size.z), true):
				_contagens["fora_da_regiao"] += 1
				continue
			var objeto := {"rotulo": "%s #%d | %s" % [registro["nome"], i, _rotulo_malha(malha)], "aabb": caixa, "no": null, "instancia": i, "forma": forma, "malha": malha}
			_rasterizar_e_registrar(objeto, forma * faces_locais, caixa, malha)
			_contagens["instancias_rasterizadas"] += 1
	# Os decalques que o world_builder poe na regiao (pe das arvores) nao passam pela
	# reconstrucao; contam do vale vivo, pela malha plana.
	for bloco in blocos:
		if bloco.multimesh == null or bloco.multimesh.mesh == null or bloco.multimesh.mesh.get_aabb().size.y >= 0.01:
			continue
		var nome_bloco := String(bloco.name)
		if not (_conferencia_multimesh["nomes_so_no_vivo"] as Array).has(nome_bloco.substr(0, nome_bloco.rfind(" "))):
			continue
		_contagens["excluidas_decalque"] += bloco.multimesh.instance_count
		_excluidos.append({"no": _rotulo_no(bloco), "motivo": "decalque", "instancias": bloco.multimesh.instance_count})
	marco = _marca_tempo("rasterizar", marco)
	_log("rasterizacao: %d triangulos na regiao" % int(_contagens["triangulos_na_regiao"]))
	var geo = Geometria.new()
	geo.iniciar(Vector2(_ox, _oz), _c, _nx, _nz, _s, _mascara, _chao)
	geo.pier = pier
	geo.praca = praca
	if _args.has("conferir"):
		_conferir_trajeto(geo, String(_args["conferir"]), chao_real, pier, praca)
		return
	# Linha de base: o voo de hoje com o chao EXATO do vale (ground_height_at).
	var base: Dictionary = Geometria.trajeto_base(pier, praca, _s, chao_real, 720)
	var confere := _conferir_com_abertura(abertura, pier, praca, chao_real)
	var pasta_candidatos := _saida.path_join("candidatos")
	Geometria.salvar_json(pasta_candidatos.path_join("base_%s.json" % _estilo), base)
	if _estilo == "tripo":
		Geometria.salvar_json(pasta_candidatos.path_join("base.json"), base)
	marco = _marca_tempo("linha_de_base", marco)
	# Conferencias: chao bilinear, objetos reais (coqueiro, casa, arvore grande).
	var validacao := await _validar(cenario, geo, chao_real)
	marco = _marca_tempo("validacao", marco)
	geo.calcular_campo(PackedFloat32Array(CAMADAS_CAMPO_M), TETO_CAMPO_M)
	marco = _marca_tempo("campo_de_folga", marco)
	var perto := _objetos_perto_da_rota(40.0)
	var cabecalho := {
		"versao": Geometria.VERSAO, "tipo": "geometria_sobrevoo", "estilo": _estilo,
		"gerado_em": Time.get_datetime_string_from_system(true, true) + "Z",
		"metros_por_unidade": _s, "celula_m": CELULA_M, "celula_u": _c, "faixa_m": Geometria.FAIXA_M,
		"faixas": Geometria.FAIXAS, "altura_max_m": Geometria.FAIXAS * Geometria.FAIXA_M,
		"origem_u": [_ox, _oz], "nx": _nx, "nz": _nz,
		"indice": "i = iz * nx + ix; celula cobre [origem + i*celula, origem + (i+1)*celula] em x e z; chao no centro",
		"pier": [pier.x, pier.y, pier.z], "praca": [praca.x, praca.y, praca.z],
		"ancoras_por_estilo": {_estilo: {"pier": [pier.x, pier.y, pier.z], "praca": [praca.x, praca.y, praca.z]}},
		"regiao": {"rota_min_u": [minimo.x, minimo.y], "rota_max_u": [maximo.x, maximo.y], "margem_m": MARGEM_M},
		"opcoes": {"lods_em_uniao": _usar_lods, "preenchimento_por_objeto": _preencher, "subdividir_m": SUBDIVIDIR_M, "rente_ao_chao_m": RENTE_AO_CHAO_M},
		"contagens": _contagens, "tempos_s": _tempos, "excluidos": _excluidos, "avisos": _avisos,
		"multimesh_reconstruida": _conferencia_multimesh,
		"linha_de_base": {"arquivo": "candidatos/base_%s.json" % _estilo, "confere_com_abertura_viva": confere},
		"objetos_perto_da_rota": perto, "validacao": validacao,
	}
	_gravar("geometria_%s" % _estilo, cabecalho, _mascara, _chao, geo.campo, PackedFloat32Array(CAMADAS_CAMPO_M))
	_salvar_mapa("mapa_%s.png" % _estilo, pier, praca)
	_marca_tempo("gravar", marco)
	_tempos["total"] = snappedf((Time.get_ticks_msec() - _t0) / 1000.0, 0.01)
	cabecalho["tempos_s"] = _tempos
	Geometria.salvar_json(_saida.path_join("geometria_%s.json" % _estilo), cabecalho)
	print("EXTRAIR_JSON: ", JSON.stringify({"estilo": _estilo, "nx": _nx, "nz": _nz, "contagens": _contagens, "tempos_s": _tempos, "validacao_resumo": validacao.get("resumo", {})}))
	_log("EXTRAIR_OK %s" % _estilo)
	quit(0)


## Reconstroi a regiao numa copia que grava as transformacoes de MultiMesh e confere a
## copia contra o vale vivo: o ponto de plantio de cada arvore (_tree_trunks), a
## transformacao dos coqueiros registrados e a contagem de instancias por nome de bloco.
func _regravar_regiao(cenario: Node3D, regiao_no: Node, tripo: bool, blocos_vivos: Array[MultiMeshInstance3D]) -> Dictionary:
	var Gravada: GDScript = load("res://tools/prototipo_3d/sobrevoo/regiao_gravada.gd")
	var copia: Node3D = Gravada.new()
	copia.call("set_meters_per_unit", float(regiao_no.call("get_meters_per_unit")))
	copia.call("set_vertical_exaggeration", float(regiao_no.call("get_vertical_exaggeration")))
	copia.call("set_estilo_tripo", tripo)
	# As clareiras que o vale pede antes de a mata nascer (o terreiro e a gameleira,
	# #52): sem elas a copia planta oito arvores que o vale vivo nao tem.
	(copia.get("clareiras") as Array).assign(regiao_no.get("clareiras"))
	var dados: Dictionary = cenario.call("_active_region_data")
	await copia.call("build_region", String(dados["geometry"]), String(dados["scenario"]))
	var gravados: Array = copia.get("gravados")
	# Contagem por nome de bloco ("<nome> x,z", com o nome saneado como o Godot faz).
	var vivos := {}
	for bloco in blocos_vivos:
		if bloco.multimesh == null:
			continue
		var nome := String(bloco.name)
		var prefixo := nome.substr(0, nome.rfind(" "))
		vivos[prefixo] = int(vivos.get(prefixo, 0)) + bloco.multimesh.instance_count
	var copiados := {}
	for g in gravados:
		var prefixo := String(g["nome"]).validate_node_name()
		copiados[prefixo] = int(copiados.get(prefixo, 0)) + (g["transforms"] as Array).size()
	var contagem_ok := true
	var por_nome := {}
	var so_no_vivo: Array = []
	for prefixo in vivos:
		if not copiados.has(prefixo):
			so_no_vivo.append(prefixo)
			continue
		por_nome[prefixo] = [vivos[prefixo], copiados[prefixo]]
		if int(vivos[prefixo]) != int(copiados[prefixo]):
			contagem_ok = false
	for prefixo in copiados:
		if not vivos.has(prefixo):
			contagem_ok = false
			por_nome[prefixo] = [0, copiados[prefixo]]
	# Plantio de cada arvore e transformacao dos coqueiros registrados.
	var tv: Array = regiao_no.get("_tree_trunks")
	var tc: Array = copia.get("_tree_trunks")
	var pior_ponto := 0.0
	var pior_forma := 0.0
	var formas := 0
	var troncos_ok := tv.size() == tc.size()
	if troncos_ok:
		for k in range(tv.size()):
			var a: Dictionary = tv[k]
			var b: Dictionary = tc[k]
			if String(a.get("especie", "")) != String(b.get("especie", "")):
				troncos_ok = false
				break
			pior_ponto = maxf(pior_ponto, (a["point"] as Vector2).distance_to(b["point"]) * _s)
			if a.has("transformacao") and b.has("transformacao"):
				var fa: Transform3D = a["transformacao"]
				var fb: Transform3D = b["transformacao"]
				pior_forma = maxf(pior_forma, fa.origin.distance_to(fb.origin) * _s)
				pior_forma = maxf(pior_forma, (fa.basis.x - fb.basis.x).length() + (fa.basis.y - fb.basis.y).length() + (fa.basis.z - fb.basis.z).length())
				formas += 1
	troncos_ok = troncos_ok and pior_ponto < 0.001 and pior_forma < 0.001
	copia.free()
	var conferencia := {
		"arvores_no_vale_vivo": tv.size(), "arvores_na_copia": tc.size(),
		"maior_diferenca_de_plantio_m": pior_ponto, "coqueiros_com_transformacao_conferida": formas,
		"maior_diferenca_de_transformacao": pior_forma,
		"instancias_por_nome_vivo_copia": por_nome, "nomes_so_no_vivo": so_no_vivo,
		"resumo": {"troncos_ok": troncos_ok, "contagem_ok": contagem_ok, "arvores": tv.size(), "coqueiros_conferidos": formas},
	}
	return {"ok": troncos_ok and contagem_ok, "gravados": gravados, "conferencia": conferencia}


func _motivo_de_exclusao(mi: MeshInstance3D) -> String:
	if mi.skin != null:
		return "personagem"
	var esqueleto := mi.get_node_or_null(mi.skeleton)
	if esqueleto is Skeleton3D:
		return "personagem"
	var pai := mi.get_parent()
	while pai != null:
		if pai is Skeleton3D:
			return "personagem"
		pai = pai.get_parent()
	for i in range(mi.mesh.get_surface_count()):
		var material := mi.get_active_material(i)
		if material is ShaderMaterial and (material as ShaderMaterial).shader != null:
			if (material as ShaderMaterial).shader.resource_path.get_file() in SHADERS_DE_AGUA:
				return "agua"
	return ""


func _rotulo_no(no: Node) -> String:
	return String(current_scene.get_path_to(no)) if current_scene != null and current_scene.is_ancestor_of(no) else String(no.name)


func _rotulo_malha(malha: Mesh) -> String:
	return malha.resource_path.get_file().get_slice("::", 0) if not malha.resource_path.is_empty() else malha.get_class()


## Faces de LOD0 + as dos LODs que o importador gerou (mesmos vertices, outros indices),
## em uniao. Cache por recurso de malha: a mata repete a mesma malha centenas de vezes.
func _faces(malha: Mesh) -> PackedVector3Array:
	var chave := malha.get_instance_id()
	if _faces_cache.has(chave):
		return _faces_cache[chave]
	var faces := malha.get_faces()
	var lod0 := faces.size() / 3
	var extras := 0
	if _usar_lods and malha is ArrayMesh:
		for s in range(malha.get_surface_count()):
			if malha.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var superficie: Dictionary = RenderingServer.mesh_get_surface(malha.get_rid(), s)
			var lods: Array = superficie.get("lods", [])
			if lods.is_empty():
				continue
			var vertices: PackedVector3Array = malha.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			var contagem := int(superficie.get("index_count", 0))
			var bytes_indice: PackedByteArray = superficie.get("index_data", PackedByteArray())
			var largura := bytes_indice.size() / contagem if contagem > 0 else (2 if vertices.size() <= 65535 else 4)
			for lod in lods:
				var dados: PackedByteArray = (lod as Dictionary).get("index_data", PackedByteArray())
				var indices := PackedInt32Array()
				if largura == 4:
					indices = dados.to_int32_array()
				else:
					indices.resize(dados.size() / 2)
					for k in range(indices.size()):
						indices[k] = dados.decode_u16(k * 2)
				var k := 0
				while k + 2 < indices.size():
					faces.append(vertices[indices[k]])
					faces.append(vertices[indices[k + 1]])
					faces.append(vertices[indices[k + 2]])
					k += 3
				extras += indices.size() / 3
	_faces_cache[chave] = faces
	_lod_info[chave] = [lod0, extras, _rotulo_malha(malha)]
	return faces


func _faces_lod0(malha: Mesh) -> PackedVector3Array:
	return malha.get_faces()


## Maior altura (m) de um vertice sobre o chao da celula dele, so dentro da grade.
func _altura_maxima_sobre_chao(faces: PackedVector3Array) -> float:
	var maior := -INF
	for v in faces:
		var ix := floori((v.x - _ox) * _inv_c)
		var iz := floori((v.z - _oz) * _inv_c)
		if ix < 0 or iz < 0 or ix >= _nx or iz >= _nz:
			continue
		maior = maxf(maior, (v.y - _chao[iz * _nx + ix]) * _s)
	return maior


## Quanto a malha drapeada se afasta de ground_height_at no meio dos triangulos (m):
## os vertices estao no chao, o miolo e linear; o IDW nao.
func _desvio_da_malha_drapeada(faces: PackedVector3Array) -> float:
	var geo = _geo_chao
	var pior := 0.0
	var passo := maxi(1, faces.size() / 3 / 4000) * 3
	var t := 0
	while t + 2 < faces.size():
		var centro := (faces[t] + faces[t + 1] + faces[t + 2]) / 3.0
		if geo.dentro(centro.x, centro.z):
			var base := minf(faces[t].y - geo.chao(faces[t].x, faces[t].z), minf(faces[t + 1].y - geo.chao(faces[t + 1].x, faces[t + 1].z), faces[t + 2].y - geo.chao(faces[t + 2].x, faces[t + 2].z)))
			pior = maxf(pior, absf((centro.y - geo.chao(centro.x, centro.z)) - base) * _s)
		t += passo
	return pior


# ---------------------------------------------------------------------------
# Rasterizacao conservadora: caixa xz de cada triangulo (ou pedaco), faixas pela
# altura do triangulo sobre o chao de cada celula.
# ---------------------------------------------------------------------------

func _retangulo(caixa: AABB) -> Rect2i:
	var i0 := floori((caixa.position.x - _ox) * _inv_c)
	var i1 := floori((caixa.end.x - _ox) * _inv_c)
	var j0 := floori((caixa.position.z - _oz) * _inv_c)
	var j1 := floori((caixa.end.z - _oz) * _inv_c)
	if i1 < 0 or j1 < 0 or i0 >= _nx or j0 >= _nz:
		return Rect2i()
	i0 = clampi(i0, 0, _nx - 1)
	i1 = clampi(i1, 0, _nx - 1)
	j0 = clampi(j0, 0, _nz - 1)
	j1 = clampi(j1, 0, _nz - 1)
	return Rect2i(i0, j0, i1 - i0 + 1, j1 - j0 + 1)


func _rasterizar_e_registrar(objeto: Dictionary, faces: PackedVector3Array, caixa: AABB, malha: Mesh) -> void:
	var r := _retangulo(caixa)
	if r.size.x <= 0:
		_contagens["fora_da_regiao"] += 1
		return
	var n_regiao := _rasterizar_objeto(faces, r)
	_contagens["triangulos_na_regiao"] += n_regiao
	var info: Array = _lod_info.get(malha.get_instance_id(), [0, 0, ""])
	_contagens["triangulos_lod0"] += int(info[0])
	_contagens["triangulos_lods_extras"] += int(info[1])
	var topo := _juntar_na_mascara(r, _mascara, _preencher)
	objeto["retangulo"] = r
	objeto["topo_m"] = topo
	objeto["triangulos"] = n_regiao
	_objetos.append(objeto)


## Rasteriza as faces no buffer temporario do retangulo r (indices locais).
func _rasterizar_objeto(w: PackedVector3Array, r: Rect2i) -> int:
	var i0 := r.position.x
	var j0 := r.position.y
	var i1 := r.end.x - 1
	var j1 := r.end.y - 1
	var largura := r.size.x
	var n := largura * r.size.y
	if _tmp.size() < n:
		_tmp.resize(n)
	for k in range(n):
		_tmp[k] = 0
	var xa := _ox + i0 * _c
	var za := _oz + j0 * _c
	var xb := _ox + (i1 + 1) * _c
	var zb := _oz + (j1 + 1) * _c
	var lim := _sub_u
	var pilha := PackedVector3Array()
	var dentro := 0
	var t := 0
	var total := w.size() - 2
	while t < total:
		var a := w[t]
		var b := w[t + 1]
		var d := w[t + 2]
		t += 3
		var minx := minf(a.x, minf(b.x, d.x))
		var maxx := maxf(a.x, maxf(b.x, d.x))
		var minz := minf(a.z, minf(b.z, d.z))
		var maxz := maxf(a.z, maxf(b.z, d.z))
		if maxx < xa or minx > xb or maxz < za or minz > zb:
			continue
		dentro += 1
		if maxx - minx <= lim and maxz - minz <= lim:
			_marcar(minx, maxx, minz, maxz, minf(a.y, minf(b.y, d.y)), maxf(a.y, maxf(b.y, d.y)), i0, j0, i1, j1, largura)
			continue
		if maxx - minx > _gigante_u or maxz - minz > _gigante_u:
			_contagens["triangulos_gigantes_ignorados"] += 1
			continue
		pilha.append(a)
		pilha.append(b)
		pilha.append(d)
		while not pilha.is_empty():
			var topo := pilha.size()
			var pa := pilha[topo - 3]
			var pb := pilha[topo - 2]
			var pd := pilha[topo - 1]
			pilha.resize(topo - 3)
			var qminx := minf(pa.x, minf(pb.x, pd.x))
			var qmaxx := maxf(pa.x, maxf(pb.x, pd.x))
			var qminz := minf(pa.z, minf(pb.z, pd.z))
			var qmaxz := maxf(pa.z, maxf(pb.z, pd.z))
			if qmaxx < xa or qminx > xb or qmaxz < za or qminz > zb:
				continue
			if qmaxx - qminx <= lim and qmaxz - qminz <= lim:
				_marcar(qminx, qmaxx, qminz, qmaxz, minf(pa.y, minf(pb.y, pd.y)), maxf(pa.y, maxf(pb.y, pd.y)), i0, j0, i1, j1, largura)
				continue
			# Divide a aresta mais longa em planta.
			var lab := (pa.x - pb.x) * (pa.x - pb.x) + (pa.z - pb.z) * (pa.z - pb.z)
			var lbd := (pb.x - pd.x) * (pb.x - pd.x) + (pb.z - pd.z) * (pb.z - pd.z)
			var lda := (pd.x - pa.x) * (pd.x - pa.x) + (pd.z - pa.z) * (pd.z - pa.z)
			if lab >= lbd and lab >= lda:
				var m := (pa + pb) * 0.5
				pilha.append_array(PackedVector3Array([pa, m, pd, m, pb, pd]))
			elif lbd >= lda:
				var m := (pb + pd) * 0.5
				pilha.append_array(PackedVector3Array([pa, pb, m, pa, m, pd]))
			else:
				var m := (pd + pa) * 0.5
				pilha.append_array(PackedVector3Array([pa, pb, m, m, pb, pd]))
	return dentro


func _marcar(minx: float, maxx: float, minz: float, maxz: float, miny: float, maxy: float, i0: int, j0: int, i1: int, j1: int, largura: int) -> void:
	var ia := maxi(floori((minx - _ox) * _inv_c), i0)
	var ib := mini(floori((maxx - _ox) * _inv_c), i1)
	var ja := maxi(floori((minz - _oz) * _inv_c), j0)
	var jb := mini(floori((maxz - _oz) * _inv_c), j1)
	for j in range(ja, jb + 1):
		var linha := j * _nx
		var local := (j - j0) * largura - i0
		for i in range(ia, ib + 1):
			var g := _chao[linha + i]
			var alto := (maxy - g) * _s
			if alto < 0.0:
				continue
			var k0 := clampi(floori((miny - g) * _s * 0.5), 0, 31)
			var k1 := mini(floori(alto * 0.5), 31)
			var v := (_tmp[local + i] & 0xFFFFFFFF) | (((1 << (k1 + 1)) - 1) ^ ((1 << k0) - 1))
			_tmp[local + i] = v - 4294967296 if v >= 2147483648 else v


## Junta o buffer do objeto na mascara de destino, preenchendo cada coluna entre a
## faixa mais baixa e a mais alta do objeto. Devolve o topo (m) mais alto marcado.
func _juntar_na_mascara(r: Rect2i, destino: PackedInt32Array, preencher: bool) -> float:
	var topo := 0.0
	var largura := r.size.x
	for jj in range(r.size.y):
		var linha := (r.position.y + jj) * _nx + r.position.x
		var local := jj * largura
		for ii in range(largura):
			var v := _tmp[local + ii] & 0xFFFFFFFF
			if v == 0:
				continue
			var baixo: int = _log2[v & -v]
			var alto := 31
			while (v >> alto) & 1 == 0:
				alto -= 1
			topo = maxf(topo, (alto + 1) * Geometria.FAIXA_M)
			_contagens["bits_antes_do_preenchimento"] += _bits(v)
			if preencher:
				var cheio := ((1 << (alto + 1)) - 1) ^ ((1 << baixo) - 1)
				if cheio != v:
					_contagens["celulas_marcadas_por_preenchimento"] += 1
				v = cheio
			_contagens["bits_depois_do_preenchimento"] += _bits(v)
			var w := (destino[linha + ii] & 0xFFFFFFFF) | v
			destino[linha + ii] = w - 4294967296 if w >= 2147483648 else w
	return topo


static func _bits(v: int) -> int:
	v = v - ((v >> 1) & 0x55555555)
	v = (v & 0x33333333) + ((v >> 2) & 0x33333333)
	return ((((v + (v >> 4)) & 0x0F0F0F0F) * 0x01010101) & 0xFFFFFFFF) >> 24


# ---------------------------------------------------------------------------
# Linha de base e conferencia com o abertura.gd vivo.
# ---------------------------------------------------------------------------

## A formula copiada na biblioteca bate com o abertura.gd que esta rodando? Se outro
## agente mexeu nele, a diferenca aparece aqui (a base continua sendo a de HEAD).
func _conferir_com_abertura(abertura: Node, pier: Vector3, praca: Vector3, chao_real: Callable) -> Dictionary:
	if not abertura.has_method("_flyover_eye") or not abertura.has_method("_flyover_target"):
		return {"conferido": false, "motivo": "abertura sem _flyover_eye/_flyover_target"}
	var pior_olho := 0.0
	var pior_alvo := 0.0
	for i in range(72):
		var progresso := float(i) / 72.0
		var olho_vivo: Vector3 = abertura.call("_flyover_eye", progresso)
		var alvo_vivo: Vector3 = abertura.call("_flyover_target", progresso)
		pior_olho = maxf(pior_olho, olho_vivo.distance_to(Geometria.olho_base(pier, praca, _s, progresso, chao_real)) * _s)
		pior_alvo = maxf(pior_alvo, alvo_vivo.distance_to(Geometria.alvo_base(pier, praca, _s, progresso, chao_real)) * _s)
	return {"conferido": true, "maior_diferenca_olho_m": pior_olho, "maior_diferenca_alvo_m": pior_alvo, "igual": pior_olho < 0.01 and pior_alvo < 0.01}


func _distancia_a_rota_m(p: Vector2) -> float:
	var menor := INF
	for i in range(_rota.size()):
		var a := _rota[i]
		var b := _rota[(i + 1) % _rota.size()]
		menor = minf(menor, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
	return menor * _s


func _medir_distancias() -> void:
	for objeto in _objetos:
		if objeto.has("distancia_rota_m"):
			continue
		var caixa: AABB = objeto["aabb"]
		objeto["distancia_rota_m"] = _distancia_a_rota_m(Vector2(caixa.get_center().x, caixa.get_center().z))


func _objetos_perto_da_rota(limite_m: float) -> Array:
	_medir_distancias()
	var lista: Array = []
	for objeto in _objetos:
		var caixa: AABB = objeto["aabb"]
		var raio := Vector2(caixa.size.x, caixa.size.z).length() * 0.5 * _s
		var d := float(objeto["distancia_rota_m"])
		if d - raio > limite_m:
			continue
		lista.append({"rotulo": objeto["rotulo"], "centro_u": [snappedf(caixa.get_center().x, 0.01), snappedf(caixa.get_center().z, 0.01)], "distancia_do_centro_a_rota_m": snappedf(d, 0.1), "aabb_altura_m": snappedf(caixa.size.y * _s, 0.1), "aabb_largura_m": snappedf(maxf(caixa.size.x, caixa.size.z) * _s, 0.1), "topo_marcado_m": objeto.get("topo_m", 0.0)})
	lista.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["topo_marcado_m"]) > float(b["topo_marcado_m"]))
	return lista.slice(0, 80)


# ---------------------------------------------------------------------------
# Validacao contra objetos reais.
# ---------------------------------------------------------------------------

func _validar(cenario: Node3D, geo, chao_real: Callable) -> Dictionary:
	var resultado := {}
	# 1. Chao bilinear da grade x ground_height_at em pontos ao acaso.
	var rng := RandomNumberGenerator.new()
	rng.seed = 34
	var pior := 0.0
	for i in range(3000):
		var x := rng.randf_range(_ox, _ox + _nx * _c)
		var z := rng.randf_range(_oz, _oz + _nz * _c)
		var real: float = chao_real.call(Vector3(x, 0.0, z))
		pior = maxf(pior, absf(real - geo.chao(x, z)) * _s)
	var pior_rota := 0.0
	for i in range(720):
		var p := Geometria.rota_base(geo.pier, geo.praca, _s, i / 720.0)
		var real: float = chao_real.call(p)
		pior_rota = maxf(pior_rota, absf(real - geo.chao(p.x, p.z)) * _s)
	resultado["chao_bilinear_vs_ground_height_at_m"] = {"pior_em_3000_pontos": pior, "pior_na_rota": pior_rota}
	_log("chao bilinear: pior %.4f m (rota %.4f m)" % [pior, pior_rota])
	# 2. Objetos: coqueiro, casa e arvore grande mais perto da rota.
	_medir_distancias()
	var escolhidos := {}
	escolhidos["coqueiro"] = _escolher(Callable(self, "_e_coqueiro"), false)
	escolhidos["casa"] = _escolher(Callable(self, "_e_casa"), false)
	if escolhidos["casa"] == null:
		# Procedural: a casa sao caixas soltas; vale a caixa alta mais perto da rota.
		escolhidos["casa"] = _escolher(Callable(self, "_e_caixa_alta"), false)
	escolhidos["arvore_grande"] = _escolher(Callable(self, "_e_arvore"), true)
	escolhidos["coqueiro_multimesh"] = _escolher(Callable(self, "_e_coqueiro_multimesh"), false)
	escolhidos["coqueiro_nomeado"] = _escolher(Callable(self, "_e_coqueiro_nomeado"), false)
	escolhidos["mata_multimesh"] = _escolher(Callable(self, "_e_mata_multimesh"), false)
	var resumo := {}
	for nome in escolhidos:
		var objeto = escolhidos[nome]
		if objeto == null:
			resultado[nome] = {"achado": false}
			continue
		var r := await _validar_objeto(objeto, geo)
		resultado[nome] = r
		resumo[nome] = {"rotulo": r["rotulo"], "faltas": r["faltas_na_grade"], "folga_maior_que_real": r["folga"]["grade_maior_que_real"], "real_menos_grade_p95_m": r["folga"]["real_menos_grade_p95_m"]}
	# 3. Coqueiros com colisao do jogo (outro caminho de codigo): o tronco tem de estar na grade.
	resultado["troncos_pela_colisao_do_jogo"] = _conferir_troncos(cenario, geo)
	resumo["troncos_pela_colisao_do_jogo"] = resultado["troncos_pela_colisao_do_jogo"].get("resumo", "")
	resultado["resumo"] = resumo
	return resultado


func _e_coqueiro(o: Dictionary) -> bool:
	return String(o["rotulo"]).to_lower().contains("coqueiro")


func _e_coqueiro_multimesh(o: Dictionary) -> bool:
	return int(o["instancia"]) >= 0 and String(o["rotulo"]).to_lower().contains("coqueiro")


func _e_coqueiro_nomeado(o: Dictionary) -> bool:
	return int(o["instancia"]) < 0 and String(o["rotulo"]).to_lower().contains("coqueiro")


func _e_mata_multimesh(o: Dictionary) -> bool:
	return int(o["instancia"]) >= 0 and String(o["rotulo"]).begins_with("Mata")


func _e_casa(o: Dictionary) -> bool:
	var r := String(o["rotulo"]).to_lower()
	for chave in CHAVES_CASA:
		if r.contains(chave):
			return true
	return false


## Casa procedural: o corpo e uma caixa de ~20 x 12 x 17 m; poste e pilar ficam de fora.
func _e_caixa_alta(o: Dictionary) -> bool:
	var caixa: AABB = o["aabb"]
	return String(o["rotulo"]).contains("BoxMesh") and caixa.size.y * _s > 8.0 and minf(caixa.size.x, caixa.size.z) * _s > 10.0


func _e_arvore(o: Dictionary) -> bool:
	var r := String(o["rotulo"]).to_lower()
	if r.contains("coqueiro"):
		return false
	for especie in ESPECIES_ARVORE:
		if r.contains(especie):
			return true
	return false


func _escolher(filtro: Callable, mais_alto: bool):
	var melhor = null
	for objeto in _objetos:
		if not filtro.call(objeto):
			continue
		var d := float(objeto["distancia_rota_m"])
		if mais_alto:
			if d > 30.0:
				continue
			if melhor == null or (objeto["aabb"] as AABB).size.y > (melhor["aabb"] as AABB).size.y:
				melhor = objeto
		elif melhor == null or d < float(melhor["distancia_rota_m"]):
			melhor = objeto
	return melhor


func _faces_do_objeto(objeto: Dictionary, so_lod0: bool) -> PackedVector3Array:
	if int(objeto["instancia"]) < 0:
		var mi := objeto["no"] as MeshInstance3D
		return mi.global_transform * (_faces_lod0(mi.mesh) if so_lod0 else _faces(mi.mesh))
	var forma: Transform3D = objeto["forma"]
	var malha: Mesh = objeto["malha"]
	return forma * (_faces_lod0(malha) if so_lod0 else _faces(malha))


func _validar_objeto(objeto: Dictionary, geo) -> Dictionary:
	var caixa: AABB = objeto["aabb"]
	var r := _retangulo(caixa)
	var lod0 := _faces_do_objeto(objeto, true)
	var todas := _faces_do_objeto(objeto, false)
	var largura := r.size.x
	var n := largura * r.size.y
	# a) Ocupacao EXATA do LOD0: cada triangulo recortado contra cada coluna de celula.
	var exata := PackedInt32Array()
	exata.resize(n)
	var t := 0
	while t + 2 < lod0.size():
		_exato_triangulo(lod0[t], lod0[t + 1], lod0[t + 2], r, exata)
		t += 3
	# b) O rasterizador de producao so neste objeto: LOD0 sem preencher, e uniao com preenchimento.
	_rasterizar_objeto(lod0, r)
	var so_lod0 := PackedInt32Array()
	so_lod0.resize(n)
	for k in range(n):
		so_lod0[k] = _tmp[k]
	_rasterizar_objeto(todas, r)
	var cheia := PackedInt32Array()
	cheia.resize(n)
	var antes := _contagens.duplicate(true)
	var mascara_obj := PackedInt32Array()
	mascara_obj.resize(_nx * _nz)
	_juntar_na_mascara(r, mascara_obj, _preencher)
	_contagens = antes
	for jj in range(r.size.y):
		for ii in range(largura):
			cheia[jj * largura + ii] = mascara_obj[(r.position.y + jj) * _nx + r.position.x + ii]
	# Toda celula x faixa da ocupacao exata tem de estar na grade final.
	var faltas := 0
	var perfil: Array = []
	var por_faixa_exata := PackedInt32Array()
	por_faixa_exata.resize(32)
	var por_faixa_lod0 := PackedInt32Array()
	por_faixa_lod0.resize(32)
	var por_faixa_cheia := PackedInt32Array()
	por_faixa_cheia.resize(32)
	var por_faixa_grade := PackedInt32Array()
	por_faixa_grade.resize(32)
	for jj in range(r.size.y):
		for ii in range(largura):
			var k := jj * largura + ii
			var e := exata[k] & 0xFFFFFFFF
			var g := _mascara[(r.position.y + jj) * _nx + r.position.x + ii] & 0xFFFFFFFF
			if e & ~g & 0xFFFFFFFF != 0:
				faltas += 1
			for b in range(32):
				if (e >> b) & 1:
					por_faixa_exata[b] += 1
				if ((so_lod0[k] & 0xFFFFFFFF) >> b) & 1:
					por_faixa_lod0[b] += 1
				if ((cheia[k] & 0xFFFFFFFF) >> b) & 1:
					por_faixa_cheia[b] += 1
				if (g >> b) & 1:
					por_faixa_grade[b] += 1
	var area := CELULA_M * CELULA_M
	for b in range(32):
		if por_faixa_exata[b] == 0 and por_faixa_cheia[b] == 0:
			continue
		perfil.append({
			"faixa_m": "%d-%d" % [b * 2, b * 2 + 2],
			"exata_lod0_m2": por_faixa_exata[b] * area,
			"raster_lod0_m2": por_faixa_lod0[b] * area,
			"raster_lods_preenchido_m2": por_faixa_cheia[b] * area,
			"grade_final_no_retangulo_m2": por_faixa_grade[b] * area,
			"diametro_equivalente_exato_m": snappedf(2.0 * sqrt(por_faixa_exata[b] * area / PI), 0.1),
			"diametro_equivalente_grade_obj_m": snappedf(2.0 * sqrt(por_faixa_cheia[b] * area / PI), 0.1),
		})
	# c) Folga da grade (so este objeto) x distancia real a malha LOD0, pela fisica.
	var folga := await _folga_contra_fisica(lod0, r, mascara_obj, caixa)
	# d) Fatias para o olho: na faixa do voo (16-18 m) e na mais larga.
	var fatias := {}
	var b16 := 8
	fatias["faixa_16_18_m_exata"] = _fatia(exata, r, b16)
	fatias["faixa_16_18_m_grade_obj"] = _fatia(cheia, r, b16)
	var mais_larga := 0
	for b in range(32):
		if por_faixa_cheia[b] > por_faixa_cheia[mais_larga]:
			mais_larga = b
	fatias["faixa_mais_larga"] = "%d-%d m" % [mais_larga * 2, mais_larga * 2 + 2]
	fatias["faixa_mais_larga_grade_obj"] = _fatia(cheia, r, mais_larga)
	var chao_base := _chao[(r.position.y + r.size.y / 2) * _nx + r.position.x + largura / 2]
	var resultado := {
		"rotulo": objeto["rotulo"],
		"distancia_do_centro_a_rota_m": snappedf(float(objeto["distancia_rota_m"]), 0.1),
		"aabb": {"altura_m": snappedf(caixa.size.y * _s, 0.1), "largura_x_m": snappedf(caixa.size.x * _s, 0.1), "largura_z_m": snappedf(caixa.size.z * _s, 0.1), "base_sobre_chao_m": snappedf((caixa.position.y - chao_base) * _s, 0.1), "topo_sobre_chao_m": snappedf((caixa.end.y - chao_base) * _s, 0.1)},
		"triangulos_lod0": lod0.size() / 3, "triangulos_com_lods": todas.size() / 3,
		"faltas_na_grade": faltas,
		"perfil_por_faixa": perfil, "folga": folga, "fatias": fatias,
	}
	_log("validacao %s: faltas=%d folga>real=%d p95(real-grade)=%.2f m" % [objeto["rotulo"], faltas, int(folga["grade_maior_que_real"]), float(folga["real_menos_grade_p95_m"])])
	return resultado


## Ocupacao exata de um triangulo: recorta-o contra cada coluna de celula da caixa dele
## e marca as faixas entre o y minimo e o maximo do pedaco que sobra.
func _exato_triangulo(a: Vector3, b: Vector3, d: Vector3, r: Rect2i, destino: PackedInt32Array) -> void:
	var ia := maxi(floori((minf(a.x, minf(b.x, d.x)) - _ox) * _inv_c), r.position.x)
	var ib := mini(floori((maxf(a.x, maxf(b.x, d.x)) - _ox) * _inv_c), r.end.x - 1)
	var ja := maxi(floori((minf(a.z, minf(b.z, d.z)) - _oz) * _inv_c), r.position.y)
	var jb := mini(floori((maxf(a.z, maxf(b.z, d.z)) - _oz) * _inv_c), r.end.y - 1)
	var tri := PackedVector3Array([a, b, d])
	for j in range(ja, jb + 1):
		var z0 := _oz + j * _c
		var faixa_z := _recortar(_recortar(tri, 2, z0, true), 2, z0 + _c, false)
		if faixa_z.is_empty():
			continue
		for i in range(ia, ib + 1):
			var x0 := _ox + i * _c
			var pedaco := _recortar(_recortar(faixa_z, 0, x0, true), 0, x0 + _c, false)
			if pedaco.is_empty():
				continue
			var ymin := INF
			var ymax := -INF
			for p in pedaco:
				ymin = minf(ymin, p.y)
				ymax = maxf(ymax, p.y)
			var g := _chao[j * _nx + i]
			var alto := (ymax - g) * _s
			if alto < 0.0:
				continue
			var k0 := clampi(floori((ymin - g) * _s * 0.5), 0, 31)
			var k1 := mini(floori(alto * 0.5), 31)
			var k := (j - r.position.y) * r.size.x + (i - r.position.x)
			var v := (destino[k] & 0xFFFFFFFF) | (((1 << (k1 + 1)) - 1) ^ ((1 << k0) - 1))
			destino[k] = v - 4294967296 if v >= 2147483648 else v


## Sutherland-Hodgman contra um plano de eixo (0 = x, 2 = z): mantem o lado >= ou <=.
static func _recortar(poligono: PackedVector3Array, eixo: int, limite: float, manter_maior: bool) -> PackedVector3Array:
	var saida := PackedVector3Array()
	var n := poligono.size()
	if n == 0:
		return saida
	for i in range(n):
		var p := poligono[i]
		var q := poligono[(i + 1) % n]
		var vp := p[eixo] - limite
		var vq := q[eixo] - limite
		var p_dentro := vp >= 0.0 if manter_maior else vp <= 0.0
		var q_dentro := vq >= 0.0 if manter_maior else vq <= 0.0
		if p_dentro:
			saida.append(p)
		if p_dentro != q_dentro:
			var t := vp / (vp - vq)
			saida.append(p + (q - p) * t)
	return saida


func _fatia(mascara: PackedInt32Array, r: Rect2i, faixa: int) -> Array:
	# Desenho em texto da faixa (# ocupado), uma linha por celula em z, no retangulo.
	var linhas: Array = []
	var x_min := r.size.x
	var x_max := -1
	var z_min := r.size.y
	var z_max := -1
	for jj in range(r.size.y):
		for ii in range(r.size.x):
			if ((mascara[jj * r.size.x + ii] & 0xFFFFFFFF) >> faixa) & 1:
				x_min = mini(x_min, ii)
				x_max = maxi(x_max, ii)
				z_min = mini(z_min, jj)
				z_max = maxi(z_max, jj)
	if x_max < 0:
		return ["(vazia)"]
	x_min = maxi(x_min - 2, 0)
	z_min = maxi(z_min - 2, 0)
	x_max = mini(x_max + 2, r.size.x - 1)
	z_max = mini(z_max + 2, r.size.y - 1)
	var passo := maxi(1, ceili((x_max - x_min + 1) / 100.0))
	for jj in range(z_min, z_max + 1, passo):
		var linha := ""
		for ii in range(x_min, x_max + 1, passo):
			var cheio := false
			for dz in range(passo):
				for dx in range(passo):
					var a := ii + dx
					var b := jj + dz
					if a <= x_max and b <= z_max and ((mascara[b * r.size.x + a] & 0xFFFFFFFF) >> faixa) & 1:
						cheio = true
			linha += "#" if cheio else "."
		linhas.append(linha)
	linhas.push_front("celula de %.1f m por caractere; extensao %.1f x %.1f m" % [CELULA_M * passo, (x_max - x_min + 1) * CELULA_M, (z_max - z_min + 1) * CELULA_M])
	return linhas


## Distancia REAL a malha (fisica do Godot sobre o trimesh LOD0 do objeto, numa camada
## so dele) x folga da grade (so este objeto), em pontos em volta, do pe ao topo.
func _folga_contra_fisica(lod0: PackedVector3Array, r: Rect2i, mascara_obj: PackedInt32Array, caixa: AABB) -> Dictionary:
	var corpo := StaticBody3D.new()
	corpo.collision_layer = 1 << 30
	corpo.collision_mask = 0
	var forma := ConcavePolygonShape3D.new()
	forma.backface_collision = true
	forma.set_faces(lod0)
	var colisor := CollisionShape3D.new()
	colisor.shape = forma
	corpo.add_child(colisor)
	root.add_child(corpo)
	await physics_frame
	await physics_frame
	var espaco := root.get_world_3d().direct_space_state
	var esfera := SphereShape3D.new()
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = esfera
	consulta.collision_mask = 1 << 30
	var geo_obj = Geometria.new()
	geo_obj.iniciar(Vector2(_ox, _oz), _c, _nx, _nz, _s, mascara_obj, _chao)
	var centro := caixa.get_center()
	var chao_c: float = geo_obj.chao(centro.x, centro.z)
	var topo_m := (caixa.end.y - chao_c) * _s
	var raio_max := 15.0
	var diferencas: Array = []
	var maior_que_real := 0
	var pontos := 0
	var exemplos: Array = []
	var h := 2.0
	while h <= topo_m + 6.0:
		for dist in [0.0, 1.0, 2.0, 3.0, 4.0, 6.0, 8.0, 11.0, 15.0]:
			for ang in range(8):
				var dir := Vector2.RIGHT.rotated(ang * TAU / 8.0)
				var p := Vector3(centro.x + dir.x * dist / _s, 0.0, centro.z + dir.y * dist / _s)
				p.y = geo_obj.chao(p.x, p.z) + h / _s
				var grade: float = geo_obj.folga(p, raio_max)
				var real := _distancia_fisica(espaco, consulta, esfera, p, raio_max / _s) * _s
				if real >= raio_max and grade >= raio_max:
					continue
				pontos += 1
				var dif: float = real - grade
				diferencas.append(dif)
				if dif < -0.05:
					maior_que_real += 1
					if exemplos.size() < 5:
						exemplos.append({"altura_m": h, "dist_eixo_m": dist, "grade_m": grade, "real_m": real})
		h += 2.0
	corpo.queue_free()
	diferencas.sort()
	var p95 := float(diferencas[int(diferencas.size() * 0.95)]) if not diferencas.is_empty() else 0.0
	var media := 0.0
	for d in diferencas:
		media += float(d)
	media = media / maxf(diferencas.size(), 1)
	return {"pontos": pontos, "grade_maior_que_real": maior_que_real, "real_menos_grade_media_m": snappedf(media, 0.01), "real_menos_grade_p95_m": snappedf(p95, 0.01), "real_menos_grade_max_m": snappedf(float(diferencas.back()) if not diferencas.is_empty() else 0.0, 0.01), "real_menos_grade_min_m": snappedf(float(diferencas.front()) if not diferencas.is_empty() else 0.0, 0.01), "exemplos_grade_maior": exemplos}


func _distancia_fisica(espaco: PhysicsDirectSpaceState3D, consulta: PhysicsShapeQueryParameters3D, esfera: SphereShape3D, p: Vector3, raio_max_u: float) -> float:
	consulta.transform = Transform3D(Basis(), p)
	esfera.radius = raio_max_u
	if espaco.intersect_shape(consulta, 1).is_empty():
		return raio_max_u
	var baixo := 0.0
	var alto := raio_max_u
	for i in range(18):
		var meio := (baixo + alto) * 0.5
		esfera.radius = maxf(meio, 0.0005)
		if espaco.intersect_shape(consulta, 1).is_empty():
			baixo = meio
		else:
			alto = meio
	return (baixo + alto) * 0.5


## O tronco das arvores nomeadas, pelo cilindro de colisao que o jogo poe nelas (nos
## coqueiros, alinhado a malha por world_builder._alinhar_colisao_coqueiro): outro
## caminho de codigo, entao confere transformacao e chao da grade por fora. Em cada
## ponto do eixo a grade tem de ter geometria a no maximo raio + 0,75 m (o miolo de um
## tronco e oco: so a casca vira triangulo, e a coluna do eixo pode ficar vazia).
func _conferir_troncos(cenario: Node3D, geo) -> Dictionary:
	var arvores: Array = cenario.get("_arvores_nomeadas")
	var pontos := 0
	var perto := 0
	var detalhes: Array = []
	for arvore: Dictionary in arvores:
		var corpo := arvore.get("colisao") as StaticBody3D
		if corpo == null or corpo.get_child_count() == 0:
			continue
		var colisao := corpo.get_child(0) as CollisionShape3D
		if colisao == null or not (colisao.shape is CylinderShape3D):
			continue
		var cilindro := colisao.shape as CylinderShape3D
		var eixo := corpo.global_transform.basis.y.normalized()
		var base := corpo.global_position - eixo * cilindro.height * 0.5
		if not geo.dentro(base.x, base.z):
			continue
		var neste := 0
		var aqui := 0
		var pior := 0.0
		for k in range(1, 10):
			var p := base + eixo * cilindro.height * k / 10.0
			aqui += 1
			var d: float = geo.folga(p, 8.0)
			pior = maxf(pior, d)
			if d <= cilindro.radius * _s + 0.75:
				neste += 1
		pontos += aqui
		perto += neste
		detalhes.append({"especie": arvore.get("especie", ""), "base_u": [snappedf(base.x, 0.01), snappedf(base.y, 0.01), snappedf(base.z, 0.01)], "pontos_do_eixo_com_geometria_ate_o_raio": "%d/%d" % [neste, aqui], "maior_folga_no_eixo_m": snappedf(pior, 0.01), "altura_cilindro_m": snappedf(cilindro.height * _s, 0.1), "raio_cilindro_m": snappedf(cilindro.radius * _s, 0.01)})
	return {"arvores": detalhes, "resumo": "%d de %d pontos do eixo do tronco (colisao do jogo) tem geometria da grade ate o raio do tronco + 0,75 m" % [perto, pontos]}


# ---------------------------------------------------------------------------
# Gravacao e uniao.
# ---------------------------------------------------------------------------

func _gravar(nome: String, cabecalho: Dictionary, mascara: PackedInt32Array, chao: PackedFloat32Array, campo: PackedFloat32Array, alturas: PackedFloat32Array) -> void:
	var caminho_bin := _saida.path_join(nome + ".bin")
	var arquivo := FileAccess.open(caminho_bin, FileAccess.WRITE)
	var a := mascara.to_byte_array()
	var b := chao.to_byte_array()
	arquivo.store_buffer(a)
	arquivo.store_buffer(b)
	var blocos: Array = [
		{"nome": "mascara", "offset": 0, "tipo": "int32_le", "quantidade": mascara.size(), "descricao": "bit k = triangulo entre 2k e 2k+2 m acima do chao da celula (bit 31 = 62 m ou mais); objetos preenchidos na vertical"},
		{"nome": "chao", "offset": a.size(), "tipo": "float32_le", "quantidade": chao.size(), "descricao": "y absoluto (unidades) de ground_height_at no centro da celula"},
	]
	if not campo.is_empty():
		var c := campo.to_byte_array()
		arquivo.store_buffer(c)
		blocos.append({"nome": "campo", "offset": a.size() + b.size(), "tipo": "float32_le", "quantidade": campo.size(), "alturas_m": Array(alturas), "teto_m": TETO_CAMPO_M, "descricao": "folga aproximada (m) camada a camada: indice = camada * nx * nz + i"})
	arquivo.close()
	cabecalho["binario"] = nome + ".bin"
	cabecalho["blocos"] = blocos
	Geometria.salvar_json(_saida.path_join(nome + ".json"), cabecalho)
	_log("gravado %s (%.1f MB)" % [caminho_bin, (a.size() + b.size() + campo.size() * 4) / 1048576.0])


## Planta da grade para conferir a olho: vermelho = geometria na altura do voo (14-18 m),
## laranja = a ate 4 m dela, azul = so acima (copa por cima), cinza = so baixo; a rota
## de hoje em preto. Um pixel por celula de 0,5 m; norte (z negativo) em cima.
func _salvar_mapa(nome: String, pier: Vector3, praca: Vector3) -> void:
	var imagem := Image.create(_nx, _nz, false, Image.FORMAT_RGB8)
	imagem.fill(Color(0.96, 0.97, 0.93))
	var olho := (1 << 7) | (1 << 8)
	var perto := (1 << 5) | (1 << 6) | (1 << 9) | (1 << 10)
	var acima := 0xFFFFFFFF ^ ((1 << 11) - 1)
	for iz in range(_nz):
		for ix in range(_nx):
			var m := _mascara[iz * _nx + ix] & 0xFFFFFFFF
			if m == 0:
				continue
			var cor := Color(0.72, 0.72, 0.70)
			if m & olho:
				cor = Color(0.85, 0.1, 0.1)
			elif m & perto:
				cor = Color(0.98, 0.6, 0.15)
			elif m & acima:
				cor = Color(0.3, 0.45, 0.9)
			imagem.set_pixel(ix, iz, cor)
	for i in range(4000):
		var p := Geometria.rota_base(pier, praca, _s, i / 4000.0)
		var ix := floori((p.x - _ox) * _inv_c)
		var iz := floori((p.z - _oz) * _inv_c)
		if ix >= 0 and iz >= 0 and ix < _nx and iz < _nz:
			imagem.set_pixel(ix, iz, Color.BLACK)
	imagem.save_png(_saida.path_join(nome))


func _uniao() -> void:
	var marco := Time.get_ticks_msec()
	var fontes: Array = []
	for estilo in ["tripo", "procedural"]:
		var geo = Geometria.carregar(_saida.path_join("geometria_%s.json" % estilo))
		if geo == null:
			push_error("UNIAO: falta geometria_%s.json em %s" % [estilo, _saida])
			quit(1)
			return
		fontes.append(geo)
	var a = fontes[0]
	var b = fontes[1]
	if not is_equal_approx(a.celula, b.celula) or not is_equal_approx(a.escala, b.escala):
		push_error("UNIAO: celula ou escala diferentes entre os estilos")
		quit(1)
		return
	_c = a.celula
	_inv_c = 1.0 / _c
	_s = a.escala
	_ox = minf(a.origem.x, b.origem.x)
	_oz = minf(a.origem.y, b.origem.y)
	_nx = roundi((maxf(a.origem.x + a.nx * _c, b.origem.x + b.nx * _c) - _ox) / _c)
	_nz = roundi((maxf(a.origem.y + a.nz * _c, b.origem.y + b.nz * _c) - _oz) / _c)
	_mascara = PackedInt32Array()
	_mascara.resize(_nx * _nz)
	_chao = PackedFloat32Array()
	_chao.resize(_nx * _nz)
	_chao.fill(NAN)
	var pior_chao := 0.0
	for geo in fontes:
		var dx: int = roundi((geo.origem.x - _ox) / _c)
		var dz: int = roundi((geo.origem.y - _oz) / _c)
		if absf((geo.origem.x - _ox) / _c - dx) > 0.01 or absf((geo.origem.y - _oz) / _c - dz) > 0.01:
			push_error("UNIAO: grades desalinhadas")
			quit(1)
			return
		for iz in range(geo.nz):
			var linha: int = (iz + dz) * _nx + dx
			var linha_fonte: int = iz * geo.nx
			for ix in range(geo.nx):
				var m: int = geo.mascara[linha_fonte + ix]
				if m != 0:
					var w := (_mascara[linha + ix] & 0xFFFFFFFF) | (m & 0xFFFFFFFF)
					_mascara[linha + ix] = w - 4294967296 if w >= 2147483648 else w
				var g: float = geo.chao_celula[linha_fonte + ix]
				if is_nan(_chao[linha + ix]):
					_chao[linha + ix] = g
				else:
					pior_chao = maxf(pior_chao, absf(_chao[linha + ix] - g) * _s)
	# Canto que nenhum estilo cobriu (longe da rota): repete a celula coberta mais perto
	# na mesma linha (ou a linha de cima), so para o bilinear nao ler NaN.
	var sem_chao := 0
	for iz in range(_nz):
		var atual := NAN
		for ix in range(_nx):
			if not is_nan(_chao[iz * _nx + ix]):
				atual = _chao[iz * _nx + ix]
				break
		for ix in range(_nx):
			var k := iz * _nx + ix
			if is_nan(_chao[k]):
				sem_chao += 1
				if is_nan(atual):
					atual = _chao[k - _nx] if iz > 0 else 0.0
				_chao[k] = atual
			else:
				atual = _chao[k]
	marco = _marca_tempo("juntar", marco)
	var geo_u = Geometria.new()
	geo_u.iniciar(Vector2(_ox, _oz), _c, _nx, _nz, _s, _mascara, _chao)
	geo_u.calcular_campo(PackedFloat32Array(CAMADAS_CAMPO_M), TETO_CAMPO_M)
	marco = _marca_tempo("campo_de_folga", marco)
	var ca: Dictionary = a.cabecalho
	var cb: Dictionary = b.cabecalho
	var ancoras := {}
	ancoras.merge(ca.get("ancoras_por_estilo", {}))
	ancoras.merge(cb.get("ancoras_por_estilo", {}))
	var dif_pier := (a.pier as Vector3).distance_to(b.pier) * _s
	var dif_praca := (a.praca as Vector3).distance_to(b.praca) * _s
	var bits := 0
	var celulas := 0
	for k in range(_mascara.size()):
		var m := _mascara[k] & 0xFFFFFFFF
		if m != 0:
			celulas += 1
			bits += _bits(m)
	var cabecalho := {
		"versao": Geometria.VERSAO, "tipo": "geometria_sobrevoo", "estilo": "uniao", "estilos": ["tripo", "procedural"],
		"gerado_em": Time.get_datetime_string_from_system(true, true) + "Z",
		"metros_por_unidade": _s, "celula_m": CELULA_M, "celula_u": _c, "faixa_m": Geometria.FAIXA_M,
		"faixas": Geometria.FAIXAS, "altura_max_m": Geometria.FAIXAS * Geometria.FAIXA_M,
		"origem_u": [_ox, _oz], "nx": _nx, "nz": _nz,
		"indice": "i = iz * nx + ix; celula cobre [origem + i*celula, origem + (i+1)*celula] em x e z; chao no centro",
		"pier": ca["pier"], "praca": ca["praca"],
		"ancoras_por_estilo": ancoras,
		"ancoras_nota": "pier/praca do cabecalho sao os do Tripo (linha mestra); o pier do procedural fica %.1f m adiante (a praca %.2f m)" % [dif_pier, dif_praca],
		"diferenca_ancoras_m": {"pier": dif_pier, "praca": dif_praca},
		"chao": {"maior_diferenca_entre_estilos_m": pior_chao, "celulas_sem_chao_preenchidas": sem_chao},
		"ocupacao": {"celulas_ocupadas": celulas, "voxels_ocupados": bits},
		"fontes": {"tripo": {"contagens": ca.get("contagens", {}), "tempos_s": ca.get("tempos_s", {}), "validacao_resumo": (ca.get("validacao", {}) as Dictionary).get("resumo", {})}, "procedural": {"contagens": cb.get("contagens", {}), "tempos_s": cb.get("tempos_s", {}), "validacao_resumo": (cb.get("validacao", {}) as Dictionary).get("resumo", {})}},
		"tempos_s": _tempos,
	}
	_gravar("geometria_uniao", cabecalho, _mascara, _chao, geo_u.campo, PackedFloat32Array(CAMADAS_CAMPO_M))
	_salvar_mapa("mapa_uniao.png", a.pier, a.praca)
	print("EXTRAIR_JSON: ", JSON.stringify({"estilo": "uniao", "nx": _nx, "nz": _nz, "diferenca_ancoras_m": cabecalho["diferenca_ancoras_m"], "chao": cabecalho["chao"], "ocupacao": cabecalho["ocupacao"], "tempos_s": _tempos}))
	_log("EXTRAIR_OK uniao")
	quit(0)


# ---------------------------------------------------------------------------
# Conferencia de um trajeto gravado contra o vale montado (os portoes).
# ---------------------------------------------------------------------------

## O trajeto gravado (data/sobrevoo_menu.json) foi planejado contra a geometria de um
## dia; o vale muda (arvore nova, casa mudada de lugar). Aqui ele e conferido contra a
## geometria de HOJE, quadro a quadro a 60 qps, com a mesma Catmull-Rom do menu:
## folga >= FOLGA_MIN_M ate os triangulos e altura do olho em [14, 18] m do chao.
## Reprovou: replaneje (tools/prototipo_3d/sobrevoo/planejar.py).
const FOLGA_MIN_M := 5.0
const ALTURA_FAIXA_M := Vector2(14.0, 18.0)
const QUADROS_POR_SEGUNDO := 60


func _conferir_trajeto(geo, caminho: String, chao_real: Callable, pier: Vector3, praca: Vector3) -> void:
	var trajeto: Dictionary = Geometria.carregar_trajeto(caminho)
	if trajeto.is_empty():
		_reprovar("o trajeto %s nao carrega" % caminho)
		return
	var anc: Dictionary = trajeto.get("ancoras_por_estilo", {}).get(_estilo, {})
	var p: Array = anc.get("pier", [])
	var q: Array = anc.get("praca", [])
	if p.size() != 3 or q.size() != 3 or pier.distance_to(Vector3(p[0], p[1], p[2])) > 0.05 or praca.distance_to(Vector3(q[0], q[1], q[2])) > 0.05:
		_reprovar("as ancoras do %s mudaram desde o planejamento (pier %s, praca %s): o menu cai na elipse antiga" % [_estilo, str(pier), str(praca)])
		return
	if not is_equal_approx(float(trajeto.get("metros_por_unidade", 0.0)), _s):
		_reprovar("a escala mudou desde o planejamento")
		return
	var olho: PackedVector3Array = trajeto["olho_v"]
	var segundos := float(trajeto.get("segundos", 72.0))
	var quadros := int(segundos * QUADROS_POR_SEGUNDO)
	var folga_min := INF
	var altura := Vector2(INF, -INF)
	var falhas: Array = []
	for f in range(quadros):
		var progresso := float(f) / quadros
		var e := Geometria.catmull_rom(olho, progresso)
		var folga: float = geo.folga(e, 15.0)
		var h: float = (e.y - float(chao_real.call(e))) * _s
		folga_min = minf(folga_min, folga)
		altura = Vector2(minf(altura.x, h), maxf(altura.y, h))
		if folga < FOLGA_MIN_M or h < ALTURA_FAIXA_M.x or h > ALTURA_FAIXA_M.y:
			if falhas.size() < 12:
				falhas.append("t=%.2f s: folga %.2f m, altura %.1f m" % [progresso * segundos, folga, h])
			elif falhas.size() == 12:
				falhas.append("...")
	var resumo := "%s: folga minima %.2f m em %d quadros; altura %.1f-%.1f m" % [_estilo, folga_min, quadros, altura.x, altura.y]
	if not falhas.is_empty():
		_reprovar("o sobrevoo gravado atravessa ou sai da faixa no vale de hoje (%s): %s" % [resumo, "; ".join(falhas)])
		return
	print("SOBREVOO_LIVRE_OK: " + resumo)
	quit(0)


func _reprovar(motivo: String) -> void:
	push_error("FALHA: " + motivo + ". Replaneje com tools/prototipo_3d/sobrevoo/planejar.py.")
	print("sobrevoo_livre: Falhas: 1")
	quit(1)
