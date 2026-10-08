extends SceneTree
## EXPORTAR OS SISTEMAS DO VALE PARA O SITE (myths-valley-APP).
##
##     godot --headless --path . --script res://tools/prototipo_3d/exportar_site.gd -- \
##         --saida=C:/caminho/jogo.json --publico=C:/caminho/public [--irmao=C:/caminho/myths-valley-2D]
##
## Lê os AUTOLOADS DE VERDADE — `root.get_node("/root/Talentos")`, `/root/Fe`,
## `/root/Receitas`… — e grava um JSON com o que cada sistema declara: nós da
## teia, itens do catálogo, receitas das três bancadas, fés, obras, preços,
## golpes, criaturas, relógio, maré, lugares, afinidade e progressão. Nada aqui
## é copiado à mão: dado que só existe em método é obtido chamando o método, e
## textura vira caminho de arquivo (`resource_path`).
##
## A GEOMETRIA DA TEIA sai da própria tela K (`teia_talentos.gd`): a tela é
## instanciada, cada raiz é aberta, e a posição de cada caixinha, a coluna
## ("degrau") e a ordem do teclado são lidas de lá. Quando a tela não sobe, o
## mesmo degrau é calculado aqui pela regra dela, e o JSON diz qual dos dois
## caminhos valeu.
##
## `--publico` copia os PNG usados (talentos, itens, moradores, criaturas) para
## <publico>/images/sprites/<pasta>/, e o JSON guarda o caminho público relativo.
## O que o vale não tem em assets/sprites — a folha do Pedro, o quadro de frente
## de cada morador e de cada bicho — vem do jogo 2D irmão (`--irmao`, ou a pasta
## myths-valley-2D ao lado deste projeto), e o JSON diz o que veio de lá.
##
## Este script NÃO edita nada do jogo. Só lê, e só escreve fora de `res://`
## (ou em res://scratch/, que o Git ignora) quando `--saida` não é dado.
##
## Convenções do SceneTree --script deste projeto: autoload só por
## `root.get_node`, `load()` (nunca `preload`) para script que cite autoload, e
## um teto de tempo que derruba o processo em vez de deixá-lo girando calado.

const TEMPO_LIMITE := 300.0
const PASTA_SPRITES_PUBLICA := "images/sprites"
const SAIDA_PADRAO := "res://scratch/site/jogo.json"

var _saida: String = SAIDA_PADRAO
var _publico: String = ""
var _irmao: String = ""                      # raiz do jogo 2D, para o sprite que o vale não tem
var _avisos: Array = []
var _copiados: Array = []
var _copiados_do_2d: Dictionary = {}         # caminho público -> arquivo de origem no 2D
var _origem_dos_sprites: Dictionary = {}     # caminho público -> arquivo de origem (para medir)
var _fonte: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(TEMPO_LIMITE).timeout.connect(func() -> void:
		push_error("EXPORTAR_SITE: passou de %d s sem terminar" % int(TEMPO_LIMITE))
		quit(2))
	_ler_args()

	var dados: Dictionary = {}
	dados["_fonte"] = {}      # preenchido no fim, mas fica em primeiro na ordem
	dados["versao"] = _versao()
	dados["talentos"] = _talentos()
	dados["catalogo"] = _catalogo()
	dados["receitas"] = _receitas()
	dados["fe"] = _fe()
	dados["obras"] = _obras()
	dados["venda"] = _venda()
	dados["luta"] = _luta()
	dados["vida"] = _vida()
	dados["energia"] = _energia()
	dados["progressao"] = _progressao()
	dados["relogio"] = _relogio()
	dados["mare"] = _mare()
	dados["lugares"] = _lugares()
	dados["afinidade"] = _afinidade()
	dados["pesca"] = _pesca()
	dados["colecao"] = _colecao()
	dados["cartas"] = _cartas()
	dados["efeitos"] = _efeitos()
	dados["equipamento"] = _equipamento()
	dados["inventario"] = _inventario()
	dados["atalhos"] = _atalhos()
	dados["missoes"] = _missoes()
	dados["dialogos"] = _dialogos()
	dados["mixamo"] = _mixamo()
	dados["estatisticas"] = _estatisticas(dados)
	dados["_fonte"] = _bloco_fonte()

	_gravar(dados)
	print("EXPORTAR_SITE_OK: %d seções, %d sprites copiados (%d do jogo 2D), %d avisos -> %s" % [
		dados.size() - 1, _copiados.size(), _copiados_do_2d.size(), _avisos.size(), _saida])
	for aviso in _avisos:
		print("AVISO: ", aviso)
	quit(0)


# --- infraestrutura -------------------------------------------------------------

func _ler_args() -> void:
	for bruto in OS.get_cmdline_user_args():
		var arg := str(bruto)
		if arg.begins_with("--saida="):
			_saida = arg.trim_prefix("--saida=").strip_edges().replace("\\", "/")
		elif arg.begins_with("--publico="):
			_publico = arg.trim_prefix("--publico=").strip_edges().replace("\\", "/").rstrip("/")
		elif arg.begins_with("--irmao="):
			_irmao = arg.trim_prefix("--irmao=").strip_edges().replace("\\", "/").rstrip("/")
	# Sem `--irmao`, o jogo 2D é procurado ao lado deste projeto (myths-valley/myths-valley-2D).
	if _irmao == "":
		var raiz := ProjectSettings.globalize_path("res://").replace("\\", "/").rstrip("/")
		_irmao = raiz.get_base_dir().path_join("myths-valley-2D")
	if not DirAccess.dir_exists_absolute(_irmao.path_join("assets/sprites")):
		_avisar("jogo 2D irmão não encontrado em %s: sprite que falta no vale fica null" % _irmao)
		_irmao = ""


func _avisar(texto: String) -> void:
	_avisos.append(texto)
	push_warning("EXPORTAR_SITE: " + texto)


## O autoload pelo caminho, sem tipo: `--script` não enxerga o nome global.
func _auto(nome: String):
	var no := root.get_node_or_null("/root/" + nome)
	if no == null:
		_avisar("o autoload %s não subiu" % nome)
	return no


func _fonte_de(secao: String, arquivos: Array) -> void:
	_fonte[secao] = arquivos


## JSON só aceita string, número, bool, lista e dicionário: aqui o resto vira
## isso. Vetores viram listas, cores viram "#rrggbb", recurso vira o caminho do
## arquivo dele, chave que não é string vira string.
func _limpo(v):
	match typeof(v):
		TYPE_DICTIONARY:
			var d: Dictionary = {}
			for k in v:
				d[str(k)] = _limpo(v[k])
			return d
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_BYTE_ARRAY:
			var a: Array = []
			for e in v:
				a.append(_limpo(e))
			return a
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return [v.x, v.y]
		TYPE_VECTOR3, TYPE_VECTOR3I:
			return [v.x, v.y, v.z]
		TYPE_COLOR:
			return "#" + v.to_html(v.a < 0.999)
		TYPE_STRING_NAME, TYPE_NODE_PATH:
			return String(v)
		TYPE_OBJECT:
			if v == null:
				return null
			if v is Resource and (v as Resource).resource_path != "":
				return (v as Resource).resource_path
			return str(v)
		TYPE_FLOAT:
			if is_nan(v) or is_inf(v):
				return null
			return v
		_:
			return v


func _ler_json(caminho: String) -> Dictionary:
	if not FileAccess.file_exists(caminho):
		_avisar("arquivo ausente: " + caminho)
		return {}
	var lido = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	if typeof(lido) != TYPE_DICTIONARY:
		_avisar("não é um objeto JSON: " + caminho)
		return {}
	return lido


## Caminho público de um sprite, copiando o PNG quando há `--publico`. Procura
## primeiro no vale (res://assets/sprites/<pasta>/<arquivo>.png) e, faltando,
## no jogo 2D irmão (`alternativas_2d`, relativas a assets/sprites de lá; sem
## lista, a mesma pasta/arquivo). `null` quando não existe em lugar nenhum — o
## site decide o que mostrar. `nome_publico` renomeia o PNG no destino.
func _sprite(pasta: String, arquivo: String, alternativas_2d: Array = [], nome_publico: String = ""):
	if arquivo == "":
		return null
	var origem := "res://assets/sprites/%s/%s.png" % [pasta, arquivo]
	var origem_abs := ""
	var do_2d := false
	if FileAccess.file_exists(origem):
		origem_abs = ProjectSettings.globalize_path(origem)
	elif _irmao != "":
		var candidatos: Array = alternativas_2d if not alternativas_2d.is_empty() else ["%s/%s.png" % [pasta, arquivo]]
		for alternativa in candidatos:
			var candidato: String = _irmao.path_join("assets/sprites").path_join(str(alternativa))
			if FileAccess.file_exists(candidato):
				origem_abs = candidato
				do_2d = true
				break
	if origem_abs == "":
		return null
	var relativo := "%s/%s/%s.png" % [PASTA_SPRITES_PUBLICA, pasta, nome_publico if nome_publico != "" else arquivo]
	if _publico != "":
		var destino := _publico.path_join(relativo)
		var pasta_destino := destino.get_base_dir()
		if not DirAccess.dir_exists_absolute(pasta_destino):
			DirAccess.make_dir_recursive_absolute(pasta_destino)
		var erro := DirAccess.copy_absolute(origem_abs, destino)
		if erro != OK:
			_avisar("não copiei %s para %s (erro %d)" % [origem_abs, destino, erro])
		elif not _copiados.has(relativo):
			_copiados.append(relativo)
			if do_2d:
				_copiados_do_2d[relativo] = "myths-valley-2D" + origem_abs.trim_prefix(_irmao)
	_origem_dos_sprites[relativo] = origem_abs
	return relativo


## Largura e altura de um PNG já resolvido por `_sprite`, ou null.
func _tamanho_do_sprite(relativo) -> Variant:
	if relativo == null or not _origem_dos_sprites.has(str(relativo)):
		return null
	var imagem := Image.load_from_file(str(_origem_dos_sprites[str(relativo)]))
	if imagem == null or imagem.is_empty():
		return null
	return [imagem.get_width(), imagem.get_height()]


## A folha de quadros de um morador, descrita como a tela social (teia_social.gd)
## a recorta: o retrato é o primeiro quadro, de lado folha/QUADROS_DA_FOLHA.
func _folha(relativo) -> Variant:
	var tamanho = _tamanho_do_sprite(relativo)
	if tamanho == null:
		return null
	var social := _constantes_de("res://scripts/prototipo_3d/teia_social.gd")
	var quadros := int(social.get("QUADROS_DA_FOLHA", 4))
	return {
		"largura_px": tamanho[0],
		"altura_px": tamanho[1],
		"recorte_do_retrato_no_jogo": {
			"x": 0, "y": 0,
			"largura": float(tamanho[0]) / float(quadros), "altura": float(tamanho[1]) / float(quadros),
			"lado_na_tela_px": float(social.get("LADO_DO_RETRATO", 0.0)),
			"regra": "teia_social.gd: AtlasTexture do primeiro quadro, região (0, 0, largura/QUADROS_DA_FOLHA, altura/QUADROS_DA_FOLHA), com QUADROS_DA_FOLHA = %d" % quadros,
		},
	}


## Constantes de um script sem instanciá-lo (`load`, nunca `preload`: ver AGENTS.md).
func _constantes_de(caminho: String) -> Dictionary:
	var script = load(caminho)
	if script == null:
		_avisar("não carreguei " + caminho)
		return {}
	return script.get_script_constant_map()


## Uma instância NOVA de um autoload, fora da árvore: é como se lê o valor de
## fábrica de uma `var` (o `_ready` não roda, as preferências do usuário não
## entram). Quem chama libera com `free()`.
func _de_fabrica(caminho: String):
	var script = load(caminho)
	if script == null:
		_avisar("não carreguei " + caminho)
		return null
	return script.new()


func _nome_da_estacao(indice: int) -> String:
	var relogio = _auto("Relogio")
	if relogio == null:
		return str(indice)
	var nomes: Array = relogio.NOMES_ESTACAO
	return str(nomes[indice]) if indice >= 0 and indice < nomes.size() else str(indice)


## O degrau de um nó numa árvore: um mais o maior degrau dos que ele exige
## DENTRO DA MESMA LISTA; quem não exige ninguém dela fica no zero. É a regra
## de `TeiaTalentos._degrau_de`, aplicada também às árvores de fé, que a tela K
## do vale não desenha.
func _degrau_em(arvore: Dictionary, no: String, nos: Array, profundidade: int = 0) -> int:
	if profundidade > 12:
		return 0
	var maior := -1
	for exigido in (arvore.get(no, {}).get("exige", []) as Array):
		if not nos.has(str(exigido)):
			continue
		maior = maxi(maior, _degrau_em(arvore, str(exigido), nos, profundidade + 1))
	return maior + 1


## Raízes, colunas e fios de uma árvore qualquer (talentos ou fé), pela regra
## da tela K, com as medidas dela quando `medidas` vier preenchido.
func _geometria_calculada(arvore: Dictionary, medidas: Dictionary) -> Dictionary:
	var no_largura := float(medidas.get("NO_LARGURA", 168.0))
	var no_altura := float(medidas.get("NO_ALTURA", 54.0))
	var vao_coluna := float(medidas.get("VAO_COLUNA", 56.0))
	var vao_linha := float(medidas.get("VAO_LINHA", 18.0))
	var raizes_vistas: Array = []
	for no in arvore:
		var raiz := str(arvore[no].get("raiz", ""))
		if not raizes_vistas.has(raiz):
			raizes_vistas.append(raiz)
	var saida: Dictionary = {"raizes": {}, "fios": [], "fios_atravessados": []}
	for raiz in raizes_vistas:
		var nos: Array = []
		for no in arvore:
			if str(arvore[no].get("raiz", "")) == raiz:
				nos.append(str(no))
		var colunas: Dictionary = {}
		for no in nos:
			var d := _degrau_em(arvore, no, nos)
			if not colunas.has(d):
				colunas[d] = []
			(colunas[d] as Array).append(no)
		var chaves := colunas.keys()
		chaves.sort()
		var posicoes: Dictionary = {}
		var ordem: Array = []
		var colunas_lista: Array = []
		var maior_altura := 0.0
		for d in chaves:
			var lista: Array = colunas[d]
			colunas_lista.append(lista)
			for i in lista.size():
				var no := str(lista[i])
				var x: float = float(d) * (no_largura + vao_coluna)
				var y: float = float(i) * (no_altura + vao_linha)
				posicoes[no] = {"degrau": int(d), "linha": i, "x": x, "y": y}
				ordem.append(no)
				maior_altura = maxf(maior_altura, y + no_altura)
		var largura := float(int(chaves[chaves.size() - 1]) + 1) * (no_largura + vao_coluna) if not chaves.is_empty() else 0.0
		saida["raizes"][raiz] = {
			"nome": raiz, "nos": ordem, "colunas": colunas_lista, "posicoes": posicoes,
			"largura_px": largura, "altura_px": maior_altura + 8.0,
		}
		for no in nos:
			for exigido in (arvore[no].get("exige", []) as Array):
				var pai := str(exigido)
				if nos.has(pai):
					var de: Dictionary = posicoes[pai]
					var para: Dictionary = posicoes[no]
					var p_de := Vector2(float(de["x"]) + no_largura, float(de["y"]) + no_altura * 0.5)
					var p_para := Vector2(float(para["x"]), float(para["y"]) + no_altura * 0.5)
					var meio := (p_de.x + p_para.x) * 0.5
					saida["fios"].append({"raiz": raiz, "de": pai, "para": no,
						"pontos": [[p_de.x, p_de.y], [meio, p_de.y], [meio, p_para.y], [p_para.x, p_para.y]]})
				else:
					saida["fios_atravessados"].append({"de": pai, "raiz_de": str(arvore.get(pai, {}).get("raiz", "")),
						"para": no, "raiz_para": raiz})
	return saida


# --- versão ---------------------------------------------------------------------

func _versao() -> Dictionary:
	var versao = _auto("Versao")
	var historico := _ler_json("res://data/historico_3d.json")
	_fonte_de("versao", ["scripts/autoload/versao.gd", "data/historico_3d.json", "project.godot"])
	var entradas: Array = historico.get("entradas", [])
	return {
		"versao": str(versao.VERSAO_ATUAL) if versao != null else "",
		"build": int(versao.BUILD_NUMERO) if versao != null else 0,
		"texto": str(versao.texto()) if versao != null else "",
		"nome_do_projeto": str(ProjectSettings.get_setting("application/config/name", "")),
		"godot": Engine.get_version_info().get("string", ""),
		"renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "forward_plus")),
		"janela": [int(ProjectSettings.get_setting("display/window/size/viewport_width", 0)),
			int(ProjectSettings.get_setting("display/window/size/viewport_height", 0))],
		"janela_minima": [int(ProjectSettings.get_setting("display/window/size/min_width", 0)),
			int(ProjectSettings.get_setting("display/window/size/min_height", 0))],
		"entradas_do_historico": entradas.size(),
		"ultima_entrada": entradas[0].get("data", "") if not entradas.is_empty() else "",
		"primeira_entrada": entradas[entradas.size() - 1].get("data", "") if not entradas.is_empty() else "",
		"autoloads": _autoloads_registrados(),
	}


func _autoloads_registrados() -> Array:
	var lista: Array = []
	for propriedade in ProjectSettings.get_property_list():
		var nome := str(propriedade.get("name", ""))
		if nome.begins_with("autoload/"):
			lista.append({"nome": nome.trim_prefix("autoload/"),
				"script": str(ProjectSettings.get_setting(nome)).trim_prefix("*")})
	return lista


# --- talentos -------------------------------------------------------------------

func _talentos() -> Dictionary:
	var t = _auto("Talentos")
	_fonte_de("talentos", ["scripts/compartilhado/talentos.gd (NOS, XP_POR_ACAO, BASE_DO_NIVEL, CRESCIMENTO, PONTOS_POR_NIVEL)",
		"scripts/prototipo_3d/teia_talentos.gd (tela K: colunas por degrau, posições, fios)",
		"assets/sprites/talentos/<id>.png"])
	if t == null:
		return {}
	var nos_src: Dictionary = t.NOS
	var filhos: Dictionary = {}
	for id in nos_src:
		for pai in (nos_src[id].get("exige", []) as Array):
			if not filhos.has(str(pai)):
				filhos[str(pai)] = []
			(filhos[str(pai)] as Array).append(str(id))
	var campos: Dictionary = {}
	var nos: Dictionary = {}
	var ativos := 0
	for id in nos_src:
		var d: Dictionary = nos_src[id]
		var exige: Array = []
		for p in (d.get("exige", []) as Array):
			exige.append(str(p))
		var outra_raiz: Array = []
		for p in exige:
			if str(nos_src.get(p, {}).get("raiz", "")) != str(d.get("raiz", "")):
				outra_raiz.append(p)
		var ativo := bool(d.get("ativo", false))
		if ativo:
			ativos += 1
		var efeito: Dictionary = _limpo(d.get("efeito", {}))
		for campo in efeito:
			if not campos.has(campo):
				campos[campo] = []
			(campos[campo] as Array).append(str(id))
		nos[str(id)] = {
			"id": str(id),
			"nome": str(d.get("nome", id)),
			"raiz": str(d.get("raiz", "")),
			"resumo": str(d.get("resumo", "")),
			"custo": int(d.get("custo", 1)),
			"exige": exige,
			"pais": exige,
			"filhos": filhos.get(str(id), []),
			"pais_de_outra_raiz": outra_raiz,
			"de_encontro": exige.size() >= 2 and not outra_raiz.is_empty(),
			"ativo": ativo,
			"natureza": "ativo" if ativo else "passivo",
			"efeito": efeito,
			"icone": _sprite("talentos", str(id)),
		}
	var xp_por_nivel: Array = []
	for n in range(1, 21):
		xp_por_nivel.append(int(roundf(float(t.BASE_DO_NIVEL) * pow(float(t.CRESCIMENTO), n - 1))))
	var por_raiz: Dictionary = {}
	for bruta in t.raizes():
		por_raiz[str(bruta)] = (t.nos_da_raiz(str(bruta)) as Array).size()
	return {
		"xp_por_acao": _limpo(t.XP_POR_ACAO),
		"base_do_nivel": int(t.BASE_DO_NIVEL),
		"crescimento": float(t.CRESCIMENTO),
		"pontos_por_nivel": int(t.PONTOS_POR_NIVEL),
		"xp_para_subir_do_nivel": xp_por_nivel,
		"regra_do_xp": "xp_do_nivel(n) = round(BASE_DO_NIVEL * CRESCIMENTO^(n-1)); a lista acima vai do nível 1 ao 20",
		"raizes": _limpo(t.raizes()),
		"nos_por_raiz": por_raiz,
		"total_de_nos": nos.size(),
		"total_de_ativos": ativos,
		"campos_de_efeito": campos,
		"nos": nos,
		"teia": _teia(t, nos),
	}


## A geometria da tela K, lida da própria tela. Preenche `degrau`, `linha`,
## `faixa` e `posicao_px` em cada nó de `nos`.
func _teia(t, nos: Dictionary) -> Dictionary:
	var caminho := "res://scripts/prototipo_3d/teia_talentos.gd"
	var TeiaScript = load(caminho)
	var medidas: Dictionary = {}
	var tela = null
	if TeiaScript == null:
		_avisar("não carreguei a tela da teia (%s): geometria calculada aqui" % caminho)
	else:
		medidas = TeiaScript.get_script_constant_map()
		tela = TeiaScript.new()
		root.add_child(tela)

	var calculada := _geometria_calculada(t.NOS, medidas)
	var fonte_da_geometria := "calculada pela regra de TeiaTalentos._degrau_de (a tela não subiu)"
	var divergencias: Array = []
	if tela != null:
		fonte_da_geometria = "lida da tela K instanciada (teia_talentos.gd): posição das caixinhas, ordem do teclado e tamanho da árvore"
		for bruta in t.raizes():
			var raiz := str(bruta)
			tela._escolher_raiz(raiz)
			var da_raiz: Dictionary = calculada["raizes"].get(raiz, {})
			var posicoes: Dictionary = da_raiz.get("posicoes", {})
			var nos_da_raiz: Array = t.nos_da_raiz(raiz)
			for no in nos_da_raiz:
				var id := str(no)
				if not tela._caixinhas.has(id):
					divergencias.append("a tela não desenhou o nó %s da raiz %s" % [id, raiz])
					continue
				var caixa = tela._caixinhas[id]
				var degrau_da_tela: int = int(tela._degrau_de(id, nos_da_raiz))
				if posicoes.has(id):
					var calc: Dictionary = posicoes[id]
					if int(calc["degrau"]) != degrau_da_tela \
							or absf(float(calc["x"]) - caixa.position.x) > 0.5 \
							or absf(float(calc["y"]) - caixa.position.y) > 0.5:
						divergencias.append("%s: tela (%d, %.0f, %.0f) ≠ cálculo (%d, %.0f, %.0f)" % [
							id, degrau_da_tela, caixa.position.x, caixa.position.y,
							int(calc["degrau"]), float(calc["x"]), float(calc["y"])])
					calc["degrau"] = degrau_da_tela
					calc["x"] = caixa.position.x
					calc["y"] = caixa.position.y
			var ordem: Array = []
			for o in tela._ordem:
				ordem.append(str(o))
			da_raiz["nos"] = ordem
			var tamanho: Vector2 = tela._tela_da_arvore.custom_minimum_size
			da_raiz["largura_px"] = tamanho.x
			da_raiz["altura_px"] = tamanho.y
		tela.queue_free()
	for aviso in divergencias:
		_avisar("teia: " + aviso)

	# Copia o lugar de cada nó para a ficha dele.
	for raiz in calculada["raizes"]:
		var posicoes: Dictionary = calculada["raizes"][raiz]["posicoes"]
		for id in posicoes:
			if nos.has(id):
				var p: Dictionary = posicoes[id]
				nos[id]["degrau"] = int(p["degrau"])
				nos[id]["faixa"] = int(p["degrau"])
				nos[id]["linha"] = int(p["linha"])
				nos[id]["posicao_px"] = [float(p["x"]), float(p["y"])]

	var tela_medidas: Dictionary = {}
	for chave in ["TAMANHO", "LARGURA_DAS_RAIZES", "ALTURA_DA_LINHA", "NO_LARGURA", "NO_ALTURA",
			"VAO_COLUNA", "VAO_LINHA", "LADO_DO_ICONE", "RECUO_DO_ICONE", "PASTA_DOS_ICONES",
			"COR_FUNDO", "COR_APAGADA", "COR_PRONTO", "COR_TRAVADO"]:
		if medidas.has(chave):
			tela_medidas[chave.to_lower()] = _limpo(medidas[chave])
	return {
		"fonte_da_geometria": fonte_da_geometria,
		"regra_do_degrau": "um mais o maior degrau dos nós que ele exige dentro da mesma raiz; quem não exige ninguém da raiz fica no degrau 0. Cada degrau é uma coluna; a linha é a ordem do dado dentro da coluna.",
		"regra_dos_fios": "um fio por exigência dentro da mesma raiz, em S: sai do meio da borda direita do pai e entra no meio da borda esquerda do filho. Exigência de outra raiz não é desenhada pela tela K (vai em fios_atravessados).",
		"tecla": "K",
		"tela": tela_medidas,
		"raizes": calculada["raizes"],
		"fios": calculada["fios"],
		"fios_atravessados": calculada["fios_atravessados"],
		"divergencias": divergencias,
	}


# --- catálogo -------------------------------------------------------------------

func _catalogo() -> Dictionary:
	var caminho := "res://scripts/compartilhado/catalogo.gd"
	_fonte_de("catalogo", ["scripts/compartilhado/catalogo.gd (ITENS, icone(), dano())",
		"scripts/compartilhado/venda.gd (MERCADORIAS, preco_de_compra(), preco_de_venda())",
		"scripts/compartilhado/receitas.gd (quem fabrica e quem consome cada item)",
		"assets/sprites/itens/<icone>.png"])
	var Cat = load(caminho)
	if Cat == null:
		_avisar("não carreguei " + caminho)
		return {}
	var consts: Dictionary = Cat.get_script_constant_map()
	var itens_src: Dictionary = consts.get("ITENS", {})
	var venda = _auto("Venda")
	var receitas = _auto("Receitas")
	var tudo: Dictionary = receitas.tudo() if receitas != null else {}

	var fabricado_por: Dictionary = {}
	var ingrediente_de: Dictionary = {}
	for rid in tudo:
		var d: Dictionary = tudo[rid]
		var bancada := str(receitas.bancada_de(str(rid)))
		if bancada != "obra" and itens_src.has(str(rid)):
			fabricado_por[str(rid)] = str(rid)
		for item in (d.get("custo", {}) as Dictionary):
			if not ingrediente_de.has(str(item)):
				ingrediente_de[str(item)] = []
			(ingrediente_de[str(item)] as Array).append(str(rid))

	var itens: Dictionary = {}
	var por_tipo: Dictionary = {}
	var com_icone := 0
	for id in itens_src:
		var d: Dictionary = itens_src[id]
		var textura = Cat.call("icone", str(id))
		var caminho_res := ""
		if textura != null and textura is Resource:
			caminho_res = str((textura as Resource).resource_path)
		var icone = _sprite("itens", caminho_res.get_file().get_basename()) if caminho_res != "" else null
		if icone != null:
			com_icone += 1
		var tipo := str(d.get("tipo", ""))
		var item: Dictionary = {
			"id": str(id),
			"nome": str(d.get("nome", id)),
			"tipo": tipo,
			"empilhavel": bool(d.get("empilhavel", false)),
			"dano": float(Cat.call("dano", str(id))),
			"arma": float(Cat.call("dano", str(id))) > 0.0,
			"icone": icone,
			"icone_res": caminho_res,
		}
		for campo in ["resumo", "encaixe", "cultura", "folego", "vida", "corta_peconha",
				"efeito", "efeito_dias", "efeito_campo", "efeito_valor", "leitura"]:
			if d.has(campo):
				item[campo] = _limpo(d[campo])
		if venda != null and (venda.MERCADORIAS as Dictionary).has(str(id)):
			var m: Dictionary = venda.MERCADORIAS[str(id)]
			item["preco"] = {
				"base": int(m.get("base", 0)),
				"margem": float(m.get("margem", 0.0)),
				"compra": int(venda.preco_de_compra(str(id))),
				"venda": int(venda.preco_de_venda(str(id))),
			}
		else:
			item["preco"] = null
		item["fabricado_por"] = fabricado_por.get(str(id), null)
		item["ingrediente_de"] = ingrediente_de.get(str(id), [])
		itens[str(id)] = item
		por_tipo[tipo] = int(por_tipo.get(tipo, 0)) + 1
	return {
		"pasta_dos_icones": str(consts.get("PASTA", "")),
		"total": itens.size(),
		"com_icone": com_icone,
		"tipos": por_tipo.keys(),
		"por_tipo": por_tipo,
		"itens": itens,
	}


# --- receitas -------------------------------------------------------------------

func _receitas() -> Dictionary:
	_fonte_de("receitas", ["scripts/compartilhado/receitas.gd (tudo(), portas_de(), bancada_de(), preco(), a_venda(), PORTAS)",
		"scripts/compartilhado/cozinha.gd (RECEITAS, _dureza())", "scripts/compartilhado/oficina.gd (RECEITAS, rende(), folego())",
		"data/construcoes/obras.json (as obras também são receitas, com a chave abre)",
		"scripts/compartilhado/catalogo.gd (fôlego que o prato devolve)"])
	var r = _auto("Receitas")
	var coz = _auto("Cozinha")
	var ofi = _auto("Oficina")
	var en = _auto("Energia")
	if r == null or coz == null or ofi == null or en == null:
		return {}
	var Cat = load("res://scripts/compartilhado/catalogo.gd")
	var itens: Dictionary = Cat.get_script_constant_map().get("ITENS", {}) if Cat != null else {}
	var tudo: Dictionary = r.tudo()
	var lista: Dictionary = {}
	var por_bancada: Dictionary = {}
	var por_porta: Dictionary = {}
	for id in tudo:
		var d: Dictionary = tudo[id]
		var bancada := str(r.bancada_de(str(id)))
		var bancada_id := "obra"
		if (coz.RECEITAS as Dictionary).has(str(id)):
			bancada_id = "fogao"
		elif (ofi.RECEITAS as Dictionary).has(str(id)):
			bancada_id = "oficina"
		var portas: Dictionary = _limpo(r.portas_de(str(id)))
		for porta in portas:
			if porta == "grau":
				continue
			por_porta[porta] = int(por_porta.get(porta, 0)) + 1
		var e: Dictionary = {
			"id": str(id),
			"nome": str(r.nome(str(id))),
			"resumo": str(r.resumo(str(id))),
			"bancada": bancada,
			"bancada_id": bancada_id,
			"abre": portas,
			"nasce_sabida": bool(portas.get("comeco", false)),
			"preco_no_balcao": int(r.preco(str(id))),
			"custo": _limpo(d.get("custo", {})),
		}
		if bancada_id == "fogao":
			e["rende"] = int(d.get("rende", 1))
			e["folego"] = float(d.get("folego", 0.0))
			e["dureza"] = float(coz._dureza(str(id)))
			e["folego_gasto"] = float(en.custo("arar", coz._dureza(str(id))))
			e["produz"] = str(id)
			e["devolve_folego"] = float(itens.get(str(id), {}).get("folego", 0.0))
			e["devolve_vida"] = float(itens.get(str(id), {}).get("vida", 0.0))
		elif bancada_id == "oficina":
			e["rende"] = int(d.get("rende", 1))
			e["rende_hoje"] = int(ofi.rende(str(id)))
			e["folego"] = float(d.get("folego", 0.0))
			e["folego_hoje"] = float(ofi.folego(str(id)))
			e["produz"] = str(id)
		else:
			e["eixo"] = str(d.get("eixo", ""))
			e["alvos"] = _limpo(d.get("alvos", []))
			e["exige"] = _limpo(d.get("exige", []))
			e["exclui"] = _limpo(d.get("exclui", []))
		lista[str(id)] = e
		por_bancada[bancada_id] = int(por_bancada.get(bancada_id, 0)) + 1
	# As duas bancadas tal qual os autoloads declaram, mais o que só existe em método.
	var coz_receitas: Dictionary = {}
	for cid in coz.RECEITAS:
		var c: Dictionary = _limpo(coz.RECEITAS[cid])
		c["dureza"] = float(coz._dureza(str(cid)))
		c["folego_gasto"] = float(en.custo("arar", coz._dureza(str(cid))))
		coz_receitas[str(cid)] = c
	var ofi_receitas: Dictionary = {}
	for oid in ofi.RECEITAS:
		var o: Dictionary = _limpo(ofi.RECEITAS[oid])
		o["rende_hoje"] = int(ofi.rende(str(oid)))
		o["folego_hoje"] = float(ofi.folego(str(oid)))
		ofi_receitas[str(oid)] = o
	return {
		"portas": _limpo(r.PORTAS),
		"regra_das_portas": "vale a primeira porta que acontecer: comeco (nasce sabida), missao (o passo ensina ao ABRIR), morador+grau (a convivência ensina), achado (coisa que se acha), compra (réis no balcão)",
		"total": lista.size(),
		"por_bancada": por_bancada,
		"por_porta": por_porta,
		"sabidas_no_comeco": _limpo(r.aprendidas),
		"a_venda_no_comeco": _limpo(r.a_venda()),
		"receitas": lista,
		"cozinha": {"receitas": coz_receitas, "total": coz_receitas.size(),
			"regra_da_dureza": "dureza = fôlego da receita × alívio de Mão de cozinheiro ÷ Energia.CUSTOS.arar; a panela gasta fôlego como a ação de arar com essa dureza (Cozinha._dureza)"},
		"oficina": {"receitas": ofi_receitas, "total": ofi_receitas.size(),
			"regra": "rende_hoje soma o rende_mais das obras da oficina; folego_hoje desconta o alívio delas (Oficina.rende, Oficina.folego)"},
	}


# --- fé -------------------------------------------------------------------------

func _fe() -> Dictionary:
	_fonte_de("fe", ["scripts/compartilhado/fe.gd (FES, FESTAS, BENCAOS, ARVORES, XP_POR_ATO, FRACAO_QUE_SOBREVIVE, BASE_DO_NIVEL, CRESCIMENTO, PONTOS_POR_NIVEL)",
		"scripts/compartilhado/ritos.gd (ESPERA_EM_DIAS, FRACAO_DE_FOLEGO, DURACAO_EM_DIAS)",
		"scripts/compartilhado/afinidade.gd (POR_ABANDONO, POR_CHEGADA, POR_FESTA, da_fe())",
		"scripts/autoload/lugares.gd (se o marco já existe no vale)"])
	var fe = _auto("Fe")
	var ritos = _auto("Ritos")
	var afinidade = _auto("Afinidade")
	var lugares = _auto("Lugares")
	if fe == null:
		return {}
	var medidas := _constantes_de("res://scripts/prototipo_3d/teia_talentos.gd")
	var fes: Dictionary = {}
	for id in fe.FES:
		var d: Dictionary = fe.FES[id]
		var marcos: Array = []
		for marco in (d.get("marcos", []) as Array):
			marcos.append({"id": str(marco),
				"no_vale": lugares != null and (lugares.DE_PARA as Dictionary).has(str(marco)),
				"ancora": str(lugares.DE_PARA.get(str(marco), "")) if lugares != null else ""})
		var arvore: Dictionary = fe.ARVORES.get(id, {})
		var nos: Dictionary = {}
		var filhos: Dictionary = {}
		for no in arvore:
			for pai in (arvore[no].get("exige", []) as Array):
				if not filhos.has(str(pai)):
					filhos[str(pai)] = []
				(filhos[str(pai)] as Array).append(str(no))
		var geometria := _geometria_calculada(arvore, medidas)
		for no in arvore:
			var n: Dictionary = arvore[no]
			var exige: Array = _limpo(n.get("exige", []))
			var raiz := str(n.get("raiz", ""))
			var pos: Dictionary = geometria["raizes"].get(raiz, {}).get("posicoes", {}).get(str(no), {})
			nos[str(no)] = {
				"id": str(no), "nome": str(n.get("nome", no)), "raiz": raiz,
				"resumo": str(n.get("resumo", "")), "custo": int(n.get("custo", 1)),
				"exige": exige, "pais": exige, "filhos": filhos.get(str(no), []),
				"ativo": bool(n.get("ativo", false)), "natureza": "passivo",
				"efeito": _limpo(n.get("efeito", {})),
				"degrau": int(pos.get("degrau", 0)), "faixa": int(pos.get("degrau", 0)),
				"linha": int(pos.get("linha", 0)),
				"posicao_px": [float(pos.get("x", 0.0)), float(pos.get("y", 0.0))],
				"icone": _sprite("talentos", str(no)),
			}
		var raizes: Array = []
		for no in arvore:
			var raiz := str(arvore[no].get("raiz", ""))
			if not raizes.has(raiz):
				raizes.append(raiz)
		fes[str(id)] = {
			"id": str(id),
			"nome": str(d.get("nome", id)),
			"resumo": str(d.get("resumo", "")),
			"pratica": str(d.get("pratica", "")),
			"rito": str(d.get("rito", "")),
			"convite": str(d.get("convite", "")),
			"marcos": marcos,
			"marco_maior": str(fe.marco_maior(str(id))),
			"festa": _festa(fe, str(id)),
			"bencaos": _limpo(fe.BENCAOS.get(id, {})),
			"moradores": _limpo(afinidade.da_fe(str(id))) if afinidade != null else [],
			"raizes": raizes,
			"total_de_nos": nos.size(),
			"nos": nos,
			"teia": {"raizes": geometria["raizes"], "fios": geometria["fios"],
				"fios_atravessados": geometria["fios_atravessados"],
				"fonte_da_geometria": "calculada pela regra da tela K (a tela do vale desenha só os talentos de ofício)"},
		}
	var xp_por_nivel: Array = []
	for n in range(1, 21):
		xp_por_nivel.append(int(fe._custo_do_nivel(n)))
	var total_nos := 0
	var total_bencaos := 0
	for id in fes:
		total_nos += int(fes[id]["total_de_nos"])
		total_bencaos += (fes[id]["bencaos"] as Dictionary).size()
	return {
		"regra": "uma fé por vez; as outras ficam congeladas no ponto em que pararam. O XP é o total acumulado de cada fé; nível e ponto saem dele por conta.",
		"fracao_que_sobrevive": float(fe.FRACAO_QUE_SOBREVIVE),
		"perda_ao_migrar_pontos": 1.0 - float(fe.FRACAO_QUE_SOBREVIVE),
		"base_do_nivel": int(fe.BASE_DO_NIVEL),
		"crescimento": float(fe.CRESCIMENTO),
		"pontos_por_nivel": int(fe.PONTOS_POR_NIVEL),
		"xp_para_subir_do_nivel": xp_por_nivel,
		"xp_por_ato": _limpo(fe.XP_POR_ATO),
		"ativa_no_comeco": str(fe.ativa),
		"ritos": {
			"espera_em_dias": int(ritos.ESPERA_EM_DIAS) if ritos != null else null,
			"fracao_de_folego": float(ritos.FRACAO_DE_FOLEGO) if ritos != null else null,
			"duracao_da_bencao_em_dias": int(ritos.DURACAO_EM_DIAS) if ritos != null else null,
			"espera_hoje": int(ritos.espera()) if ritos != null else null,
			"duracao_hoje": int(ritos.duracao()) if ritos != null else null,
			"regra": "o rito devolve uma fração do teto de fôlego, dá XP e sorteia uma bênção com prazo; a espera conta por marco, e no dia da festa da fé o rito sai fora do prazo",
		},
		"preco_social": {
			"por_abandono": int(afinidade.POR_ABANDONO) if afinidade != null else null,
			"por_chegada": int(afinidade.POR_CHEGADA) if afinidade != null else null,
			"por_festa": int(afinidade.POR_FESTA) if afinidade != null else null,
		},
		"total_de_fes": fes.size(),
		"total_de_nos": total_nos,
		"total_de_bencaos": total_bencaos,
		"festas": _limpo(fe.FESTAS),
		"fes": fes,
	}


func _festa(fe, id: String) -> Dictionary:
	var f: Dictionary = fe.FESTAS.get(id, {})
	if f.is_empty():
		return {}
	return {
		"nome": str(f.get("nome", "")),
		"estacao": int(f.get("estacao", 0)),
		"estacao_nome": _nome_da_estacao(int(f.get("estacao", 0))),
		"dia": int(f.get("dia", 0)),
		"aviso": str(f.get("aviso", "")),
	}


# --- obras ----------------------------------------------------------------------

func _obras() -> Dictionary:
	_fonte_de("obras", ["data/construcoes/obras.json (tal qual: observacao, familias, obras)",
		"scripts/compartilhado/obras.gd (ATRIBUTOS, DESCONTO_MAXIMO, PULA_SO_ESTAS, catalogo(), custo())",
		"scripts/compartilhado/jogo.gd (NOME_DAS_CONSTRUCOES)"])
	var obras = _auto("Obras")
	var jogo = _auto("Jogo")
	var bruto := _ler_json("res://data/construcoes/obras.json")
	var catalogo: Dictionary = bruto.get("obras", {})
	var filhos: Dictionary = {}
	var excluidas_por: Dictionary = {}
	var por_eixo: Dictionary = {}
	var por_alvo: Dictionary = {}
	for id in catalogo:
		var d: Dictionary = catalogo[id]
		for pai in (d.get("exige", []) as Array):
			if not filhos.has(str(pai)):
				filhos[str(pai)] = []
			(filhos[str(pai)] as Array).append(str(id))
		for outra in (d.get("exclui", []) as Array):
			if not excluidas_por.has(str(outra)):
				excluidas_por[str(outra)] = []
			(excluidas_por[str(outra)] as Array).append(str(id))
		var eixo := str(d.get("eixo", ""))
		por_eixo[eixo] = int(por_eixo.get(eixo, 0)) + 1
		for alvo in (d.get("alvos", []) as Array):
			por_alvo[str(alvo)] = int(por_alvo.get(str(alvo), 0)) + 1
	var grafo: Dictionary = {}
	for id in catalogo:
		grafo[str(id)] = {
			"filhos": filhos.get(str(id), []),
			"excluida_por": excluidas_por.get(str(id), []),
			"atributos": _limpo(obras.ATRIBUTOS.get(str(id), {})) if obras != null else {},
			"custo_hoje": _limpo(obras.custo(str(id))) if obras != null else {},
		}
	var construcoes: Dictionary = {}
	if jogo != null:
		for id in jogo.NOME_DAS_CONSTRUCOES:
			construcoes[str(id)] = str(jogo.nome_da_construcao(str(id)))
	return {
		"arquivo": bruto,
		"total": catalogo.size(),
		"por_eixo": por_eixo,
		"por_alvo": por_alvo,
		"familias": _limpo(bruto.get("familias", {})),
		"grafo": grafo,
		"atributos": _limpo(obras.ATRIBUTOS) if obras != null else {},
		"desconto_maximo": float(obras.DESCONTO_MAXIMO) if obras != null else null,
		"pula_so_estas": _limpo(obras.PULA_SO_ESTAS) if obras != null else [],
		"xp_por_obra": {"casca": 3, "outros": 1, "regra": "Talentos.XP_POR_ACAO.obra vezes _peso_em_xp: casca conta 3, planta e mobília contam 1"},
		"nome_das_construcoes": construcoes,
	}


# --- venda ----------------------------------------------------------------------

func _venda() -> Dictionary:
	_fonte_de("venda", ["scripts/compartilhado/venda.gd (MERCADORIAS, ESTACAO, LIMITE_DO_TALENTO, preco_de_compra(), preco_de_venda())",
		"scripts/compartilhado/jogo.gd (dinheiro inicial)", "scripts/compartilhado/receitas.gd (receitas à venda no balcão)"])
	var venda = _auto("Venda")
	var receitas = _auto("Receitas")
	if venda == null:
		return {}
	var Cat = load("res://scripts/compartilhado/catalogo.gd")
	var itens: Dictionary = Cat.get_script_constant_map().get("ITENS", {}) if Cat != null else {}
	var tabela: Dictionary = {}
	for id in venda.MERCADORIAS:
		var m: Dictionary = venda.MERCADORIAS[id]
		tabela[str(id)] = {
			"nome": str(itens.get(str(id), {}).get("nome", id)),
			"base": int(m.get("base", 0)),
			"margem": float(m.get("margem", 0.0)),
			"compra_hoje": int(venda.preco_de_compra(str(id))),
			"venda_hoje": int(venda.preco_de_venda(str(id))),
		}
	var por_estacao: Dictionary = {}
	for indice in venda.ESTACAO:
		por_estacao[_nome_da_estacao(int(indice))] = _limpo(venda.ESTACAO[indice])
	var receitas_a_venda: Array = []
	if receitas != null:
		for rid in receitas.a_venda():
			receitas_a_venda.append({"id": str(rid), "nome": str(receitas.nome(str(rid))),
				"bancada": str(receitas.bancada_de(str(rid))), "preco": int(receitas.preco(str(rid)))})
	var jogo_fabrica = _de_fabrica("res://scripts/compartilhado/jogo.gd")
	var dinheiro_inicial = int(jogo_fabrica.dinheiro) if jogo_fabrica != null else null
	if jogo_fabrica != null:
		jogo_fabrica.free()
	return {
		"moeda": "réis",
		"dinheiro_inicial": dinheiro_inicial,
		"limite_do_talento": float(venda.LIMITE_DO_TALENTO),
		"regra": "compra = base × peso da estação × (1 − desconto_de_compra); venda = base × margem × peso da estação × (1 + margem_de_venda); os bônus da teia somam até o limite",
		"total_de_mercadorias": tabela.size(),
		"mercadorias": tabela,
		"peso_por_estacao": por_estacao,
		"receitas_a_venda_no_comeco": receitas_a_venda,
	}


# --- luta -----------------------------------------------------------------------

func _luta() -> Dictionary:
	_fonte_de("luta", ["scripts/compartilhado/luta.gd (GOLPES, GINGA, SEGURAR, FORCA_POR_NO, dano(), tontura(), folego())",
		"scripts/prototipo_3d/criatura_vale.gd (ESPECIES, CORPO, PASSO_DO_JOGADOR_2D)",
		"scripts/prototipo_3d/luta_vale.gd (ALCANCE_DE_LUTA, NINHOS, LONGE_DE_CASA)",
		"data/colecionaveis/bichos.json (ficha e meta de cada bicho)", "data/luta.json (textos da luta)",
		"scripts/compartilhado/catalogo.gd (dano de cada arma)",
		"myths-valley-2D/assets/sprites/gerados/<id>_sul.png (quadro de frente do bicho, copiado para images/sprites/criaturas/)"])
	var luta = _auto("Luta")
	if luta == null:
		return {}
	var criatura := _constantes_de("res://scripts/prototipo_3d/criatura_vale.gd")
	var vale := _constantes_de("res://scripts/prototipo_3d/luta_vale.gd")
	var bichos: Dictionary = _ler_json("res://data/colecionaveis/bichos.json").get("bichos", {})
	var textos := _ler_json("res://data/luta.json")
	var Cat = load("res://scripts/compartilhado/catalogo.gd")
	var itens: Dictionary = Cat.get_script_constant_map().get("ITENS", {}) if Cat != null else {}

	var armas: Dictionary = {}
	for id in itens:
		var dano := float(Cat.call("dano", str(id)))
		if dano > 0.0:
			armas[str(id)] = {"nome": str(itens[id].get("nome", id)), "dano": dano,
				"golpe": float(luta.dano("golpe", str(id))),
				"golpe_forte": float(luta.dano("golpe_forte", str(id)))}
	var golpes: Dictionary = {}
	for id in luta.GOLPES:
		var g: Dictionary = _limpo(luta.GOLPES[id])
		g["id"] = str(id)
		g["folego_hoje"] = float(luta.folego(str(id)))
		g["tontura_hoje"] = float(luta.tontura(str(id)))
		g["sabido_no_comeco"] = bool(luta.sabe(str(id)))
		if not bool(g.get("arma", false)):
			g["dano_hoje"] = float(luta.dano(str(id), ""))
		golpes[str(id)] = g
	var especies: Dictionary = {}
	var passo_2d := float(criatura.get("PASSO_DO_JOGADOR_2D", 62.0))
	for id in criatura.get("ESPECIES", {}):
		var e: Dictionary = _limpo(criatura["ESPECIES"][id])
		e["id"] = str(id)
		e["corpo_u"] = _limpo((criatura.get("CORPO", {}) as Dictionary).get(id, null))
		e["passo_relativo_ao_jogador"] = float(e.get("passo", 0.0)) / passo_2d if passo_2d > 0.0 else null
		var pancadas: Dictionary = {}
		for arma in armas:
			pancadas[arma] = int(ceilf(float(e.get("vida", 0.0)) / float(armas[arma]["golpe"])))
		e["golpes_para_derrubar"] = pancadas
		e["item_que_cai_nome"] = str(itens.get(str(e.get("cai", "")), {}).get("nome", e.get("cai", "")))
		var ficha: Dictionary = bichos.get(str(id), {})
		e["titulo"] = str(ficha.get("titulo", e.get("nome", id)))
		e["onde"] = str(ficha.get("onde", ""))
		e["ficha"] = _limpo(ficha.get("ficha", []))
		e["meta"] = _limpo(ficha.get("meta", {}))
		# O vale não tem sprite 2D de bicho; o quadro de frente vem do jogo 2D irmão.
		e["sprite_frente"] = _sprite("criaturas", str(id), ["gerados/%s_sul.png" % id])
		especies[str(id)] = e
	return {
		"regra": "em tempo real, no mundo, com o que se tem na mão. Arma na mão dá golpe e golpe forte (segurar E); mão vazia dá meia-lua e rasteira para quem aprendeu capoeira; V é a ginga. Cair não é morrer: a noite leva para casa.",
		"segurar_s": float(luta.SEGURAR),
		"forca_por_no": float(luta.FORCA_POR_NO),
		"ginga": _limpo(luta.GINGA),
		"ginga_folego_hoje": float(luta.folego_da_ginga()),
		"golpes": golpes,
		"armas": armas,
		"criaturas": especies,
		"total_de_criaturas": especies.size(),
		"escala": {"passo_do_jogador_2d_px": passo_2d,
			"regra": "ESPECIES guarda os números do 2D em pixels; u_por_px = walk_speed do jogador / PASSO_DO_JOGADOR_2D"},
		"vale": {
			"alcance_de_luta": _limpo(vale.get("ALCANCE_DE_LUTA", null)),
			"ninhos": _limpo(vale.get("NINHOS", [])),
			"longe_de_casa": _limpo(vale.get("LONGE_DE_CASA", null)),
		},
		"textos": _limpo(textos),
	}


# --- vida, energia, progressão ----------------------------------------------------

func _vida() -> Dictionary:
	_fonte_de("vida", ["scripts/compartilhado/vida.gd (VIDA_POR_VIGOR, RESPIRO, maximo())", "scripts/compartilhado/progressao.gd (VIDA_MAXIMA_INICIAL)"])
	var vida = _auto("Vida")
	if vida == null:
		return {}
	return {
		"regra": "separada do fôlego: acaba porque alguma coisa bateu. A noite devolve inteira; o chá de folha devolve um pedaço; comida não cura. Cair vira noite no chão, não morte.",
		"maxima_inicial": float(vida.maximo()),
		"vida_por_vigor": float(vida.VIDA_POR_VIGOR),
		"respiro_s": float(vida.RESPIRO),
		"peconha": "a jararaca deixa veneno que tira vida por segundo; Sangue grosso encurta o tempo (imunidade); o chá de folha, a noite ou a queda cortam",
	}


func _energia() -> Dictionary:
	_fonte_de("energia", ["scripts/compartilhado/energia.gd (CUSTOS, LIMIAR_DE_CANSACO, PESO_DO_CANSACO)", "scripts/compartilhado/progressao.gd (teto e descanso)"])
	var en = _auto("Energia")
	if en == null:
		return {}
	return {
		"regra": "custo = base da ação × dureza do alvo × eficiência do personagem. Ferramenta melhor não barateia: destrava alvo mais duro.",
		"custos": _limpo(en.CUSTOS),
		"limiar_de_cansaco": float(en.LIMIAR_DE_CANSACO),
		"peso_do_cansaco": float(en.PESO_DO_CANSACO),
		"maxima_inicial": float(en.maximo()),
	}


func _progressao() -> Dictionary:
	_fonte_de("progressao", ["scripts/compartilhado/progressao.gd (constantes e valores de fábrica)"])
	var p = _de_fabrica("res://scripts/compartilhado/progressao.gd")
	if p == null:
		return {}
	var saida := {
		"regra": "o sono devolve um VALOR FIXO, não uma fração do máximo: subir o teto não faz acordar com mais",
		"energia_maxima_inicial": float(p.ENERGIA_MAXIMA_INICIAL),
		"recuperacao_inicial": float(p.RECUPERACAO_INICIAL),
		"recuperacao_desmaio_inicial": float(p.RECUPERACAO_DESMAIO_INICIAL),
		"vida_maxima_inicial": float(p.VIDA_MAXIMA_INICIAL),
		"eficiencia_inicial": float(p.eficiencia),
		"nivel_de_ferramenta": _limpo(p.nivel_de_ferramenta),
		"peso_do_poder": _limpo(p.peso_do_poder),
		"campos_ajustaveis": ["energia_maxima", "recuperacao_ao_dormir", "recuperacao_ao_desmaiar", "eficiencia", "vida_maxima"],
	}
	p.free()
	return saida


# --- relógio e dia ----------------------------------------------------------------

func _relogio() -> Dictionary:
	_fonte_de("relogio", ["scripts/compartilhado/relogio.gd (NOMES_ESTACAO, DIAS_POR_ESTACAO, MINUTOS_POR_SEGUNDO, HORA_DE_ACORDAR, HORA_LIMITE)",
		"scripts/autoload/dia.gd (VELOCIDADES, ROTULOS_VELOCIDADE, NASCER, POR, INICIO_DO_DIA, DIA_DO_ANO, periodo(), luz_do_dia(), eh_noite_em())"])
	var relogio = _auto("Relogio")
	var dia = _auto("Dia")
	if relogio == null or dia == null:
		return {}
	var periodos: Array = []
	var curva: Array = []
	var hora_antes: float = dia.hora
	var atual := ""
	var inicio := 0.0
	for passo in range(0, 48):
		var h := float(passo) * 0.5
		dia.hora = h
		var periodo := str(dia.periodo())
		if periodo != atual:
			if atual != "":
				periodos.append({"periodo": atual, "de": inicio, "ate": h})
			atual = periodo
			inicio = h
		curva.append({"hora": h, "luz": snappedf(float(dia.luz_do_dia()), 0.001),
			"noite": bool(dia.eh_noite_em(h)), "elevacao_solar": snappedf(float(dia.elevacao_solar()), 0.1)})
	periodos.append({"periodo": atual, "de": inicio, "ate": 24.0})
	dia.hora = hora_antes
	var fabrica = _de_fabrica("res://scripts/autoload/dia.gd")
	var velocidades: Array = []
	for i in (dia.VELOCIDADES as Array).size():
		velocidades.append({"indice": i, "rotulo": str(dia.ROTULOS_VELOCIDADE[i]),
			"segundos_reais_por_hora": float(dia.VELOCIDADES[i]),
			"minutos_reais_por_dia": snappedf(float(dia.VELOCIDADES[i]) * 24.0 / 60.0, 0.1),
			"padrao": fabrica != null and i == int(fabrica.velocidade)})
	var saida := {
		"regra": "o dia começa às 6h e segue madrugada adentro até as 2h; o contador de dias só avança quando o jogador dorme ou desmaia",
		"estacoes": _limpo(relogio.NOMES_ESTACAO),
		"dias_por_estacao": int(relogio.DIAS_POR_ESTACAO),
		"dias_por_ano": int(relogio.DIAS_POR_ESTACAO) * (relogio.NOMES_ESTACAO as Array).size(),
		"minutos_de_jogo_por_segundo_real_2d": float(relogio.MINUTOS_POR_SEGUNDO),
		"hora_de_acordar": int(relogio.HORA_DE_ACORDAR),
		"hora_limite": int(relogio.HORA_LIMITE),
		"comeca_em": {"dia": int(relogio.dia), "estacao": _nome_da_estacao(int(relogio.estacao)), "ano": int(relogio.ano)},
		"dia": {
			"inicio_do_dia": float(dia.INICIO_DO_DIA),
			"hora_inicial_padrao": float(fabrica.hora_inicial) if fabrica != null else null,
			"nascer_do_sol": float(dia.NASCER),
			"por_do_sol": float(dia.POR),
			"dia_do_ano": int(dia.DIA_DO_ANO),
			"latitude": float(dia.latitude),
			"velocidades": velocidades,
			"periodos": periodos,
			"curva_de_luz": curva,
		},
	}
	if fabrica != null:
		fabrica.free()
	return saida


# --- maré -----------------------------------------------------------------------

func _mare() -> Dictionary:
	_fonte_de("mare", ["scripts/autoload/mare.gd (AMPLITUDE_U, METROS_POR_UNIDADE, CICLO_RAPIDO_S, fase(), _offset_do_modo(), turbidez())",
		"scripts/prototipo_3d/painel_ajustes.gd (rótulos dos modos, lidos da linha _escolha(\"Maré\", …))"])
	var mare = _auto("Mare")
	var dia = _auto("Dia")
	if mare == null or dia == null:
		return {}
	var rotulos := _rotulos_da_mare()
	var modo_antes: int = mare.modo
	var hora_antes: float = dia.hora
	var modos: Array = []
	for modo in range(0, 4):
		var curva: Array = []
		mare.modo = modo
		if modo == 1 or modo == 2:
			for passo in range(0, 25):
				var h := float(passo)
				dia.hora = fmod(h, 24.0)
				var offset_u := float(mare._offset_do_modo())
				curva.append({"hora": h, "nivel_m": snappedf(offset_u * float(mare.METROS_POR_UNIDADE), 0.01),
					"fase": snappedf(float(mare.fase()), 0.001), "enchente": bool(mare.enchente()),
					"turbidez": snappedf(float(mare.turbidez()), 0.001)})
		modos.append({"indice": modo, "rotulo": str(rotulos[modo]) if modo < rotulos.size() else "modo %d" % modo,
			"ciclos_por_dia": [0, 2, 1, null][modo], "curva": curva})
	mare.modo = modo_antes
	dia.hora = hora_antes
	var fabrica = _de_fabrica("res://scripts/autoload/mare.gd")
	var saida := {
		"regra": "a batimetria fala em metros na preamar; o nível desce até a baixa-mar e volta em cosseno, sem quina. A enchente revolve o fundo e turva a água.",
		"amplitude_u": float(mare.AMPLITUDE_U),
		"metros_por_unidade": float(mare.METROS_POR_UNIDADE),
		"amplitude_m": float(mare.AMPLITUDE_U) * float(mare.METROS_POR_UNIDADE),
		"ciclo_rapido_s": float(mare.CICLO_RAPIDO_S),
		"modo_padrao": int(fabrica.modo) if fabrica != null else null,
		"alta": {"nivel_m": 0.0, "nome": "preamar"},
		"baixa": {"nivel_m": -float(mare.AMPLITUDE_U) * float(mare.METROS_POR_UNIDADE), "nome": "baixa-mar"},
		"modos": modos,
	}
	if fabrica != null:
		fabrica.free()
	return saida


func _rotulos_da_mare() -> Array:
	var caminho := "res://scripts/prototipo_3d/painel_ajustes.gd"
	if not FileAccess.file_exists(caminho):
		return []
	var regex := RegEx.new()
	regex.compile("_escolha\\(\"Maré\",\\s*\\[([^\\]]*)\\]")
	var achado := regex.search(FileAccess.get_file_as_string(caminho))
	if achado == null:
		_avisar("não achei os rótulos da maré em painel_ajustes.gd")
		return []
	var lista: Array = []
	var pedacos := RegEx.new()
	pedacos.compile("\"([^\"]*)\"")
	for m in pedacos.search_all(achado.get_string(1)):
		lista.append(m.get_string(1))
	return lista


# --- lugares --------------------------------------------------------------------

func _lugares() -> Dictionary:
	_fonte_de("lugares", ["scripts/autoload/lugares.gd (DE_PARA, FALTAM_NO_VALE)"])
	var lugares = _auto("Lugares")
	if lugares == null:
		return {}
	var faltam: Array = []
	for nome in lugares.FALTAM_NO_VALE:
		faltam.append({"id": str(nome), "razao": str(lugares.FALTAM_NO_VALE[nome])})
	var tem: Array = []
	for nome in lugares.DE_PARA:
		tem.append({"id": str(nome), "ancora": str(lugares.DE_PARA[nome])})
	return {
		"regra": "o nome do contrato (chave de missão e de save) vira a âncora do world_builder; nome que o vale ainda não tem devolve NENHUM e a missão pula em silêncio",
		"unidade": "1 unidade = 4 metros",
		"total_no_vale": tem.size(),
		"total_que_faltam": faltam.size(),
		"de_para": _limpo(lugares.DE_PARA),
		"no_vale": tem,
		"faltam_no_vale": faltam,
	}


# --- afinidade ------------------------------------------------------------------

func _afinidade() -> Dictionary:
	_fonte_de("afinidade", ["scripts/compartilhado/afinidade.gd (MORADORES, GRAUS, POR_*, MAXIMO, MINIMO, juizo(), fe_de(), nome_de())",
		"data/dialogos/aldeoes.json (nome, fé, gosta, desgosta)", "scripts/compartilhado/receitas.gd (o que cada grau abre)",
		"data/cartas/cartas.json (cartas de apoio por grau)", "data/npcs_3d.json (voz e postos)",
		"assets/sprites/moradores/<id>.png (folha de quadros; idêntica a myths-valley-2D/assets/sprites/<id>_sheet.png)",
		"scripts/prototipo_3d/teia_social.gd (QUADROS_DA_FOLHA, LADO_DO_RETRATO: como o retrato é recortado da folha)",
		"myths-valley-2D/assets/sprites/gerados/<id>_sul.png (quadro de frente, copiado como images/sprites/moradores/<id>_frente.png)",
		"myths-valley-2D/assets/sprites/pedro_sheet.png (a folha do Pedro, que o vale não tem)"])
	var af = _auto("Afinidade")
	var receitas = _auto("Receitas")
	var jogo = _auto("Jogo")
	if af == null:
		return {}
	var aldeoes: Dictionary = jogo.dados(af.ARQUIVO_DOS_MORADORES) if jogo != null else _ler_json("res://data/dialogos/aldeoes.json")
	var cartas: Dictionary = _ler_json("res://data/cartas/cartas.json").get("cartas", {})
	var npcs := _ler_json("res://data/npcs_3d.json")
	var postos_por_id: Dictionary = {}
	for m in (npcs.get("moradores", []) as Array):
		postos_por_id[str(m.get("id", ""))] = m
	var tudo: Dictionary = receitas.tudo() if receitas != null else {}
	var Cat = load("res://scripts/compartilhado/catalogo.gd")
	var itens: Dictionary = Cat.get_script_constant_map().get("ITENS", {}) if Cat != null else {}

	var graus: Array = []
	for i in (af.GRAUS as Array).size():
		var g: Dictionary = af.GRAUS[i]
		graus.append({"indice": i, "de": int(g.get("de", 0)), "nome": str(g.get("nome", ""))})

	var moradores: Dictionary = {}
	for bruto in af.MORADORES:
		var id := str(bruto)
		var dele: Dictionary = aldeoes.get(id, {})
		var abre: Dictionary = {}
		for rid in tudo:
			var portas: Dictionary = tudo[rid].get("abre", {})
			if str(portas.get("morador", "")) != id:
				continue
			var grau := str(int(portas.get("grau", 1)))
			if not abre.has(grau):
				abre[grau] = []
			(abre[grau] as Array).append({"id": str(rid), "nome": str(receitas.nome(str(rid))),
				"bancada": str(receitas.bancada_de(str(rid)))})
		for cid in cartas:
			var c: Dictionary = cartas[cid]
			if str(c.get("de_quem", "")) != id:
				continue
			var grau := str(int(c.get("grau", 1)))
			if not abre.has(grau):
				abre[grau] = []
			(abre[grau] as Array).append({"id": str(cid), "nome": str(c.get("nome", cid)),
				"bancada": "carta", "natureza": str(c.get("natureza", ""))})
		var gosta: Array = []
		for item in (dele.get("gosta", []) as Array):
			gosta.append({"id": str(item), "nome": str(itens.get(str(item), {}).get("nome", item)),
				"vale": int(af.quanto_vale(id, str(item)))})
		var desgosta: Array = []
		for item in (dele.get("desgosta", []) as Array):
			desgosta.append({"id": str(item), "nome": str(itens.get(str(item), {}).get("nome", item)),
				"vale": int(af.quanto_vale(id, str(item)))})
		var npc: Dictionary = postos_por_id.get(id, {})
		var retrato = _sprite("moradores", id, ["%s_sheet.png" % id])
		moradores[id] = {
			"id": id,
			"nome": str(af.nome_de(id)),
			"fe": str(af.fe_de(id)),
			"gosta": gosta,
			"desgosta": desgosta,
			"abre_por_grau": abre,
			"retrato": retrato,
			"retrato_folha": _folha(retrato),
			"retrato_frente": _sprite("moradores", id + "_frente", ["gerados/%s_sul.png" % id]),
			"altura_m": float(npc.get("altura", 0.0)) if npc.has("altura") else null,
			"voz": _limpo(npc.get("voz", {}).get("nome", "")) if npc.has("voz") else "",
			"postos": _limpo(npc.get("postos", {})),
			"saudacoes_com_voz": (npc.get("falas", []) as Array).size(),
			"assuntos": (dele.get("assuntos", []) as Array).size(),
		}
	var guia: Dictionary = npcs.get("guia", {})
	var pedro := {
		"id": str(guia.get("id", "pedro")),
		"nome": str(jogo.nome_do_morador("pedro")) if jogo != null else str(guia.get("nome", "Pedro")),
		"nome_completo": str(jogo.npc_1_nome_completo) if jogo != null else "",
		"papel": "guia do tutorial; fora da conta de afinidade (sistema de fala próprio)",
		"retrato": _sprite("moradores", "pedro", ["pedro_sheet.png"]),
		"retrato_frente": _sprite("moradores", "pedro_frente", ["gerados/pedro_sul.png"]),
		"altura_m": float(guia.get("altura", 0.0)) if guia.has("altura") else null,
		"voz": str(guia.get("voz", {}).get("nome", "")),
		"saudacoes_com_voz": (guia.get("falas", []) as Array).size(),
	}
	pedro["retrato_folha"] = _folha(pedro["retrato"])
	if pedro["retrato"] == null:
		pedro["retrato_observacao"] = "sem folha em assets/sprites/moradores do vale nem pedro_sheet.png no jogo 2D"
	elif _copiados_do_2d.has(str(pedro["retrato"])):
		pedro["retrato_observacao"] = "o vale não tem folha do Pedro em assets/sprites/moradores; a folha veio do jogo 2D (pedro_sheet.png), a mesma origem das outras sete folhas"
	return {
		"regra": "conversar (1×/dia), presentear (1×/dia; o que a pessoa gosta vale muito, o que ela desgosta tira) e fazer o favor dela. Teto para a afinidade não virar moagem.",
		"graus": graus,
		"por_conversa": int(af.POR_CONVERSA),
		"por_presente_bom": int(af.POR_PRESENTE_BOM),
		"por_presente_qualquer": int(af.POR_PRESENTE_QUALQUER),
		"por_presente_ruim": int(af.POR_PRESENTE_RUIM),
		"por_favor": int(af.POR_FAVOR),
		"por_festa": int(af.POR_FESTA),
		"por_abandono_de_fe": int(af.POR_ABANDONO),
		"por_chegada_na_fe": int(af.POR_CHEGADA),
		"maximo": int(af.MAXIMO),
		"minimo": int(af.MINIMO),
		"ordem": _limpo(af.MORADORES),
		"total_de_moradores": moradores.size(),
		"moradores": moradores,
		"guia": pedro,
	}


# --- pesca ----------------------------------------------------------------------

func _pesca() -> Dictionary:
	_fonte_de("pesca", ["scripts/compartilhado/pesca.gd (ESPERA_MINIMA, ESPERA_MAXIMA, JANELA, FOLEGO, TANQUES, AGUA_PADRAO, PESO_DO_CARDUME, janela(), espera())",
		"data/pesca.json (textos)"])
	var pesca = _auto("Pesca")
	if pesca == null:
		return {}
	var Cat = load("res://scripts/compartilhado/catalogo.gd")
	var itens: Dictionary = Cat.get_script_constant_map().get("ITENS", {}) if Cat != null else {}
	var tanques: Dictionary = {}
	for agua in pesca.TANQUES:
		var lista: Array = []
		var total := 0
		for premio in (pesca.TANQUES[agua] as Array):
			total += int(premio.get("peso", 0))
		for premio in (pesca.TANQUES[agua] as Array):
			var id := str(premio.get("id", ""))
			lista.append({"id": id, "nome": str(itens.get(id, {}).get("nome", "nada")) if id != "" else "nada (levou a isca)",
				"qtd": int(premio.get("qtd", 0)), "peso": int(premio.get("peso", 0)),
				"chance": snappedf(float(premio.get("peso", 0)) / float(total), 0.001) if total > 0 else 0.0})
		tanques[str(agua)] = lista
	var espera: Vector2 = pesca.espera()
	return {
		"regra": "uma tecla: E lança, a espera é aleatória, ao ferrar há uma janela curta para apertar E de novo. Acerto é tempo de reação, não sorte pura.",
		"espera_minima_s": float(pesca.ESPERA_MINIMA),
		"espera_maxima_s": float(pesca.ESPERA_MAXIMA),
		"janela_s": float(pesca.JANELA),
		"janela_hoje_s": float(pesca.janela()),
		"espera_hoje_s": [espera.x, espera.y],
		"folego_por_lancada": float(pesca.FOLEGO),
		"agua_padrao": str(pesca.AGUA_PADRAO),
		"peso_do_cardume": int(pesca.PESO_DO_CARDUME),
		"tanques": tanques,
		"textos": _limpo(_ler_json("res://data/pesca.json")),
	}


# --- coleção e cartas -----------------------------------------------------------

func _colecao() -> Dictionary:
	_fonte_de("colecao", ["scripts/compartilhado/colecao.gd (COLECOES, total())", "data/colecionaveis/cordeis.json", "data/colecionaveis/sinais.json", "data/colecionaveis/bichos.json"])
	var col = _auto("Colecao")
	if col == null:
		return {}
	var colecoes: Dictionary = {}
	var total := 0
	for id in col.COLECOES:
		var d: Dictionary = _limpo(col.COLECOES[id])
		d["id"] = str(id)
		d["total"] = int(col.total(str(id)))
		d["ids"] = _limpo(col.ordem(str(id)))
		total += int(d["total"])
		colecoes[str(id)] = d
	return {"tecla": "L (almanaque)", "total_de_colecoes": colecoes.size(), "total_de_pecas": total, "colecoes": colecoes}


func _cartas() -> Dictionary:
	_fonte_de("cartas", ["scripts/compartilhado/cartas.gd (OBRA_DO_ORATORIO, natureza())", "data/cartas/cartas.json (id, nome, natureza, resumo, ganho, cobra, custo, efeito, de_quem, grau — sem a prosa)"])
	var cartas = _auto("Cartas")
	var bruto := _ler_json("res://data/cartas/cartas.json")
	var lista: Dictionary = {}
	var por_natureza: Dictionary = {}
	for id in bruto.get("cartas", {}):
		var c: Dictionary = bruto["cartas"][id]
		var e: Dictionary = {"id": str(id), "nome": str(c.get("nome", id)), "natureza": str(c.get("natureza", "")),
			"resumo": str(c.get("resumo", ""))}
		for campo in ["ganho", "cobra", "onde", "custo", "faz", "efeito_campo", "efeito_valor", "efeito_dias", "de_quem", "grau"]:
			if c.has(campo):
				e[campo] = _limpo(c[campo])
		lista[str(id)] = e
		por_natureza[e["natureza"]] = int(por_natureza.get(e["natureza"], 0)) + 1
	return {
		"regra": "PACTO é com um mito, dá ganho permanente e cobra todo dia (um de cada vez); APOIO é carta de gente, uma vez por dia na tecla R; RITUAL é consumível, preparado no oratório com o que se planta.",
		"obra_do_oratorio": str(cartas.OBRA_DO_ORATORIO) if cartas != null else "",
		"total": lista.size(),
		"por_natureza": por_natureza,
		"cartas": lista,
	}


func _efeitos() -> Dictionary:
	_fonte_de("efeitos", ["scripts/compartilhado/efeitos.gd (LIMITE, NATUREZAS)"])
	var ef = _auto("Efeitos")
	if ef == null:
		return {}
	return {"limite": int(ef.LIMITE), "naturezas": _limpo(ef.NATUREZAS),
		"regra": "um efeito mexe num campo da Progressão por N dias e some sozinho; estourando o limite, sai o que vence primeiro"}


func _equipamento() -> Dictionary:
	_fonte_de("equipamento", ["scripts/compartilhado/equipamento.gd (ENCAIXES, NOME_DO_ENCAIXE)", "scripts/compartilhado/catalogo.gd (itens com encaixe)"])
	var eq = _auto("Equipamento")
	if eq == null:
		return {}
	var Cat = load("res://scripts/compartilhado/catalogo.gd")
	var itens: Dictionary = Cat.get_script_constant_map().get("ITENS", {}) if Cat != null else {}
	var por_encaixe: Dictionary = {}
	for id in itens:
		if eq.e_equipamento(str(id)):
			var encaixe := str(eq.encaixe_de(str(id)))
			if not por_encaixe.has(encaixe):
				por_encaixe[encaixe] = []
			(por_encaixe[encaixe] as Array).append(str(id))
	return {"encaixes": _limpo(eq.ENCAIXES), "nome_do_encaixe": _limpo(eq.NOME_DO_ENCAIXE), "itens_por_encaixe": por_encaixe}


func _inventario() -> Dictionary:
	_fonte_de("inventario", ["scripts/compartilhado/inventario.gd (ESPACOS_MAO, ESPACOS_MOCHILA, ESPACOS, PILHA_MAXIMA)", "scripts/compartilhado/salvamento.gd (QUANTOS_SLOTS, VERSAO)"])
	var inv = _auto("Inventario")
	var sal = _auto("Salvamento")
	if inv == null:
		return {}
	return {
		"espacos_mao": int(inv.ESPACOS_MAO),
		"espacos_mochila": int(inv.ESPACOS_MOCHILA),
		"espacos": int(inv.ESPACOS),
		"pilha_maxima": int(inv.PILHA_MAXIMA),
		"vagas_de_save": int(sal.QUANTOS_SLOTS) if sal != null else null,
		"versao_do_save": int(sal.VERSAO) if sal != null else null,
	}


func _atalhos() -> Dictionary:
	_fonte_de("atalhos", ["scripts/prototipo_3d/atalhos.gd (DEFINICOES, RESERVADAS)"])
	var consts := _constantes_de("res://scripts/prototipo_3d/atalhos.gd")
	var lista: Array = []
	for acao in consts.get("DEFINICOES", {}):
		var d: Dictionary = consts["DEFINICOES"][acao]
		lista.append({"acao": str(acao), "rotulo": str(d.get("rotulo", "")),
			"tecla": OS.get_keycode_string(int(d.get("padrao", 0)))})
	var reservadas: Array = []
	for codigo in consts.get("RESERVADAS", []):
		reservadas.append(OS.get_keycode_string(int(codigo)))
	return {"movimento": reservadas, "acoes": lista}


# --- missões --------------------------------------------------------------------

func _missoes() -> Dictionary:
	_fonte_de("missoes", ["data/missoes_*.json (dono, principal, abre_em, passos: id, titulo, lugar, raio, meta, audio, entrega — sem os textos)",
		"scripts/compartilhado/missoes.gd (PRINCIPAIS, DA_JORNADA)", "scripts/compartilhado/jornada.gd (PASSO_QUE_FECHA_O_ARRAIAL)"])
	var missoes = _auto("Missoes")
	var jornada = _auto("Jornada")
	var cadeias: Dictionary = {}
	var total_passos := 0
	var com_audio := 0
	var com_traducao := 0
	for arquivo in _arquivos_de_missao():
		var d := _ler_json("res://data/" + arquivo)
		var passos: Array = []
		for p in (d.get("passos", []) as Array):
			var passo: Dictionary = {
				"id": str(p.get("id", "")), "titulo": str(p.get("titulo", "")),
				"lugar": str(p.get("lugar", "")), "raio_u": float(p.get("raio", 0.0)),
				"meta": str((p.get("meta", {}) as Dictionary).get("tipo", "")),
				"audio": str(p.get("audio", "")),
				"entrega": _limpo(p.get("entrega", {})),
				"traduzido": p.has("texto_en") and p.has("texto_es"),
			}
			if passo["audio"] != "":
				var som := "res://assets/audio/vozes/%s.mp3" % passo["audio"]
				passo["audio_existe"] = FileAccess.file_exists(som)
				com_audio += 1
			if passo["traduzido"]:
				com_traducao += 1
			passos.append(passo)
		total_passos += passos.size()
		# O estado da tradução: o que o arquivo declara ou, quando ele não
		# declara, o que os passos têm — todos, alguns ou nenhum com texto_en/es.
		var traduzidos := 0
		for passo in passos:
			if bool(passo["traduzido"]):
				traduzidos += 1
		var traducao := str(d.get("traducao", ""))
		if traducao == "":
			if passos.is_empty() or traduzidos == 0:
				traducao = "nenhum passo traduzido"
			elif traduzidos == passos.size():
				traducao = "todos os passos traduzidos"
			else:
				traducao = "parcial: %d de %d passos" % [traduzidos, passos.size()]
		cadeias[arquivo.get_basename()] = {
			"arquivo": "data/" + arquivo, "dono": str(d.get("dono", "")),
			"principal": bool(d.get("principal", false)), "abre_em": str(d.get("abre_em", "")),
			"traducao": traducao,
			"total_de_passos": passos.size(), "passos": passos,
		}
	return {
		"total_de_cadeias": cadeias.size(),
		"total_de_passos": total_passos,
		"passos_com_voz": com_audio,
		"passos_traduzidos": com_traducao,
		"principais_2d": _limpo(missoes.PRINCIPAIS) if missoes != null else [],
		"da_jornada": _limpo(missoes.DA_JORNADA) if missoes != null else [],
		"passo_que_fecha_o_arraial": str(jornada.PASSO_QUE_FECHA_O_ARRAIAL) if jornada != null else "",
		"cadeias": cadeias,
	}


func _arquivos_de_missao() -> Array:
	var lista: Array = []
	var pasta := DirAccess.open("res://data")
	if pasta == null:
		_avisar("não abri res://data")
		return lista
	pasta.list_dir_begin()
	var nome := pasta.get_next()
	while nome != "":
		if not pasta.current_is_dir() and nome.begins_with("missoes_") and nome.ends_with(".json"):
			lista.append(nome)
		nome = pasta.get_next()
	pasta.list_dir_end()
	lista.sort()
	return lista


# --- diálogos: só a contagem ----------------------------------------------------

func _dialogos() -> Dictionary:
	_fonte_de("dialogos", ["data/dialogos/aldeoes.json (gostou, nao_gostou, agradeceu, ja_ganhou, reserva, assuntos[].fala)",
		"data/dialogos/pedro.json (travessia, abertura, depois_do_nome, passos, casa_convite, convite_texto, casa_trancada, anoitecer, companhia, portao, conversa_avulsa)",
		"data/missoes_*.json (um texto por passo)", "data/npcs_3d.json (saudações com voz)", "assets/audio/vozes/*.mp3"])
	var jogo = _auto("Jogo")
	var personagens: Dictionary = {}

	# 1. Os moradores, em aldeoes.json.
	var aldeoes := _ler_json("res://data/dialogos/aldeoes.json")
	for id in aldeoes:
		if typeof(aldeoes[id]) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = aldeoes[id]
		var n := 0
		for campo in ["gostou", "nao_gostou", "agradeceu", "ja_ganhou", "reserva"]:
			n += (d.get(campo, []) as Array).size()
		var assuntos: Array = d.get("assuntos", [])
		var nas_conversas := 0
		for a in assuntos:
			nas_conversas += ((a as Dictionary).get("fala", []) as Array).size()
		_conta(personagens, str(id), str(d.get("nome", id)), "aldeoes", n + nas_conversas)
		personagens[str(id)]["assuntos"] = assuntos.size()

	# 2. O Pedro, em pedro.json.
	var pedro := _ler_json("res://data/dialogos/pedro.json")
	var falas_do_pedro := 0
	var narracao := 0
	var traduzidas := 0
	for campo in ["abertura", "depois_do_nome", "casa_convite", "convite_texto", "casa_trancada", "anoitecer", "conversa_avulsa"]:
		falas_do_pedro += (pedro.get(campo, []) as Array).size()
	narracao += (pedro.get("travessia", []) as Array).size()
	for campo in ["travessia_en", "travessia_es"]:
		traduzidas += (pedro.get(campo, []) as Array).size()
	if pedro.has("pergunta_nome"):
		falas_do_pedro += 1
	for chave in (pedro.get("companhia", {}) as Dictionary):
		falas_do_pedro += 1
	var portao: Dictionary = pedro.get("portao", {})
	falas_do_pedro += (portao.get("pulou", []) as Array).size()
	var passos_do_tutorial := 0
	for chave in (pedro.get("passos", {}) as Dictionary):
		var v = pedro["passos"][chave]
		if typeof(v) == TYPE_DICTIONARY:
			passos_do_tutorial += 1
			falas_do_pedro += ((v as Dictionary).get("fala", []) as Array).size()
		elif typeof(v) == TYPE_ARRAY:
			falas_do_pedro += (v as Array).size()
	var nome_do_pedro := str(jogo.nome_do_morador("pedro")) if jogo != null else str(pedro.get("personagem", "Pedro"))
	_conta(personagens, "pedro", nome_do_pedro, "pedro", falas_do_pedro)
	personagens["pedro"]["narracao_da_travessia"] = narracao
	personagens["pedro"]["narracao_traduzida"] = traduzidas
	personagens["pedro"]["passos_do_tutorial_2d"] = passos_do_tutorial

	# 3. As cadeias de missão: um texto por passo, do dono.
	for arquivo in _arquivos_de_missao():
		var d := _ler_json("res://data/" + arquivo)
		var dono := str(d.get("dono", ""))
		if dono == "":
			continue
		var passos: Array = d.get("passos", [])
		var textos := 0
		for p in passos:
			if str((p as Dictionary).get("texto", "")) != "":
				textos += 1
		_conta(personagens, dono, str(jogo.nome_do_morador(dono)) if jogo != null else dono, "missoes/" + arquivo.get_basename(), textos)

	# 4. As saudações com voz, em npcs_3d.json.
	var npcs := _ler_json("res://data/npcs_3d.json")
	var vozes_existentes := 0
	var vozes_declaradas := 0
	var todos: Array = (npcs.get("moradores", []) as Array).duplicate()
	if npcs.has("guia"):
		todos.append(npcs["guia"])
	for m in todos:
		var id := str((m as Dictionary).get("id", ""))
		var falas: Array = (m as Dictionary).get("falas", [])
		for f in falas:
			var audio := str((f as Dictionary).get("audio", ""))
			if audio != "":
				vozes_declaradas += 1
				if FileAccess.file_exists("res://assets/audio/vozes/%s.mp3" % audio):
					vozes_existentes += 1
		_conta(personagens, id, str((m as Dictionary).get("nome", id)), "saudacoes_com_voz", falas.size())

	var total := 0
	for id in personagens:
		total += int(personagens[id]["total"])
	return {
		"observacao": "só a contagem: os textos ficam nos arquivos de origem",
		"total_de_falas": total,
		"total_de_personagens": personagens.size(),
		"saudacoes_com_voz_declaradas": vozes_declaradas,
		"saudacoes_com_voz_existentes": vozes_existentes,
		"por_personagem": personagens,
	}


func _conta(personagens: Dictionary, id: String, nome: String, origem: String, quantas: int) -> void:
	if not personagens.has(id):
		personagens[id] = {"id": id, "nome": nome, "total": 0, "por_origem": {}}
	personagens[id]["por_origem"][origem] = int(personagens[id]["por_origem"].get(origem, 0)) + quantas
	personagens[id]["total"] = int(personagens[id]["total"]) + quantas


# --- animações do Mixamo (#190) -----------------------------------------------------

## A SEÇÃO MIXAMO DO SITE: o tamanho do catálogo do Mixamo, quantos clipes o vale
## usa, e por personagem a lista dos clipes com a origem (Tripo ou Mixamo) e o
## percentual de uso — clipes Mixamo ÷ a meta de cada um (`meta_por_personagem`).
## Nenhum FBX sai daqui: só nomes e contagens (a licença não deixa redistribuir o arquivo).
func _mixamo() -> Dictionary:
	_fonte_de("mixamo", ["data/mixamo_uso.json (catálogo, baixados, rótulos e clipes por personagem)",
		"assets/prototipo_3d/personagens/mixamo/*.res (as bibliotecas redirecionadas que o jogo de fato carrega)"])
	var uso := _ler_json("res://data/mixamo_uso.json")
	var meta := maxi(int(uso.get("meta_por_personagem", 2)), 1)
	var rotulos: Dictionary = uso.get("rotulos_tripo", {})
	var personagens: Array = []
	var usados := 0
	for pessoa: Dictionary in uso.get("personagens", []):
		var modelo := str(pessoa.get("modelo", pessoa.get("id", "")))
		var caminho := "res://assets/prototipo_3d/personagens/mixamo/%s.res" % modelo
		var no_jogo: Array = []
		if ResourceLoader.exists(caminho):
			var biblioteca := load(caminho) as AnimationLibrary
			if biblioteca != null:
				for nome: StringName in biblioteca.get_animation_list():
					no_jogo.append(String(nome))
		var clipes: Array = []
		for nome in pessoa.get("clipes_tripo", []):
			var r: Dictionary = rotulos.get(str(nome), {})
			clipes.append({"id": str(nome), "origem": "Tripo", "rotulo": str(r.get("rotulo", nome)),
				"rotulo_en": str(r.get("rotulo_en", nome)), "rotulo_es": str(r.get("rotulo_es", nome))})
		var do_mixamo := 0
		for c: Dictionary in pessoa.get("clipes_mixamo", []):
			var id := str(c.get("id", ""))
			if not id in no_jogo:
				_avisar("o clipe Mixamo '%s' de %s está no mixamo_uso.json e não na biblioteca %s" % [id, pessoa.get("id", ""), caminho])
				continue
			do_mixamo += 1
			clipes.append({"id": id, "origem": "Mixamo", "nome_mixamo": str(c.get("nome_mixamo", "")),
				"rotulo": str(c.get("rotulo", id)), "rotulo_en": str(c.get("rotulo_en", id)), "rotulo_es": str(c.get("rotulo_es", id)),
				"gatilho": str(c.get("gatilho", "")), "gatilho_en": str(c.get("gatilho_en", "")), "gatilho_es": str(c.get("gatilho_es", ""))})
		usados += do_mixamo
		personagens.append({"id": str(pessoa.get("id", "")), "nome": str(pessoa.get("nome", "")),
			"clipes_tripo": (pessoa.get("clipes_tripo", []) as Array).size(), "clipes_mixamo": do_mixamo,
			"meta_mixamo": meta, "uso_da_meta": snappedf(minf(float(do_mixamo) / meta, 1.0), 0.01),
			"parte_mixamo": snappedf(float(do_mixamo) / maxf(float(clipes.size()), 1.0), 0.01), "clipes": clipes})
	var catalogo: Dictionary = uso.get("catalogo", {})
	return {
		"regra": "cada personagem ganha clipes do Mixamo aos poucos, %d por rodada, cada um com um gatilho no jogo e conferido antes de entrar; os FBX não são publicados, só o movimento já redirecionado para o esqueleto de cada um, dentro do jogo" % meta,
		"catalogo": _limpo(catalogo),
		"total_no_catalogo": int(catalogo.get("total_itens", 0)),
		"baixados_para_escolha": (uso.get("baixados", []) as Array).size(),
		"usados_no_jogo": usados,
		"personagens_com_mixamo": personagens.filter(func(p: Dictionary) -> bool: return int(p["clipes_mixamo"]) > 0).size(),
		"meta_por_personagem": meta,
		"por_personagem": personagens,
	}


# --- estatísticas -------------------------------------------------------------------

func _estatisticas(d: Dictionary) -> Dictionary:
	_fonte_de("estatisticas", ["somas das outras seções deste arquivo"])
	var talentos: Dictionary = d.get("talentos", {})
	var fe: Dictionary = d.get("fe", {})
	var luta: Dictionary = d.get("luta", {})
	var receitas: Dictionary = d.get("receitas", {})
	var lugares: Dictionary = d.get("lugares", {})
	var missoes: Dictionary = d.get("missoes", {})
	var dialogos: Dictionary = d.get("dialogos", {})
	return {
		"talentos": int(talentos.get("total_de_nos", 0)),
		"raizes_de_talento": (talentos.get("raizes", []) as Array).size(),
		"itens": int(d.get("catalogo", {}).get("total", 0)),
		"receitas": int(receitas.get("total", 0)),
		"receitas_por_bancada": receitas.get("por_bancada", {}),
		"obras": int(d.get("obras", {}).get("total", 0)),
		"fes": int(fe.get("total_de_fes", 0)),
		"nos_de_fe": int(fe.get("total_de_nos", 0)),
		"bencaos": int(fe.get("total_de_bencaos", 0)),
		"festas": (fe.get("festas", {}) as Dictionary).size(),
		"criaturas": int(luta.get("total_de_criaturas", 0)),
		"golpes": (luta.get("golpes", {}) as Dictionary).size(),
		"armas": (luta.get("armas", {}) as Dictionary).size(),
		"mercadorias": int(d.get("venda", {}).get("total_de_mercadorias", 0)),
		"moradores": int(d.get("afinidade", {}).get("total_de_moradores", 0)),
		"personagens_com_fala": int(dialogos.get("total_de_personagens", 0)),
		"falas": int(dialogos.get("total_de_falas", 0)),
		"lugares_no_vale": int(lugares.get("total_no_vale", 0)),
		"lugares_que_faltam": int(lugares.get("total_que_faltam", 0)),
		"cadeias_de_missao": int(missoes.get("total_de_cadeias", 0)),
		"passos_de_missao": int(missoes.get("total_de_passos", 0)),
		"colecionaveis": int(d.get("colecao", {}).get("total_de_pecas", 0)),
		"cartas": int(d.get("cartas", {}).get("total", 0)),
		"estacoes": (d.get("relogio", {}).get("estacoes", []) as Array).size(),
		"dias_por_ano": int(d.get("relogio", {}).get("dias_por_ano", 0)),
		"vagas_de_save": d.get("inventario", {}).get("vagas_de_save", null),
		"autoloads": (d.get("versao", {}).get("autoloads", []) as Array).size(),
		"sprites_copiados": _copiados.size(),
		"sprites_vindos_do_2d": _copiados_do_2d.size(),
	}


# --- a fonte e a gravação ----------------------------------------------------------

func _bloco_fonte() -> Dictionary:
	var versao = _auto("Versao")
	return {
		"gerado_em": Time.get_datetime_string_from_system(false, true),
		"gerador": "tools/prototipo_3d/exportar_site.gd, rodado com Godot %s em modo headless" % Engine.get_version_info().get("string", ""),
		"como": "os autoloads são lidos ao vivo (root.get_node('/root/X')); dado que só existe em método é obtido chamando o método; Texture2D vira resource_path; a geometria da teia é lida da tela K instanciada",
		"versao_do_jogo": str(versao.texto()) if versao != null else "",
		"caminhos_relativos_a": "raiz do repositório myths-valley-3D",
		"sprites_publicos": {"pasta": PASTA_SPRITES_PUBLICA, "copiados": _copiados.size(),
			"origem": "assets/sprites/{talentos,itens,moradores}/<arquivo>.png do vale (os mesmos do 2D, copiados para o 3D); o que o vale não tem vem do jogo 2D irmão",
			"destino": (_publico + "/" + PASTA_SPRITES_PUBLICA) if _publico != "" else "(sem --publico: nada copiado)",
			"do_jogo_2d": {"raiz": _irmao if _irmao != "" else "(não encontrado)", "quantos": _copiados_do_2d.size(),
				"arquivos": _copiados_do_2d.duplicate()},
			"lista": _copiados.duplicate()},
		"secoes": _fonte,
		"avisos": _avisos.duplicate(),
	}


func _gravar(dados: Dictionary) -> void:
	var texto := JSON.stringify(dados, "  ", false)
	var pasta := _saida.get_base_dir()
	if _saida.begins_with("res://") or _saida.begins_with("user://"):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta))
	else:
		DirAccess.make_dir_recursive_absolute(pasta)
	var arquivo := FileAccess.open(_saida, FileAccess.WRITE)
	if arquivo == null:
		push_error("EXPORTAR_SITE: não consegui gravar %s (erro %d)" % [_saida, FileAccess.get_open_error()])
		quit(1)
		return
	arquivo.store_string(texto)
	arquivo.close()
	print("EXPORTAR_SITE: %d bytes gravados em %s" % [texto.length(), _saida])
