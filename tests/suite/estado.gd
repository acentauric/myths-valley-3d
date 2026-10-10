extends RefCounted
## A FOTO DO ESTADO DO JOGO: os autoloads (e, com perfil descartável, o user://).
##
## Num Godot por portão, cada portão começava com os autoloads recém-criados e
## o perfil vazio. Num Godot para todos (a suíte do vale e os testes de unidade
## no GUT), um caso herdaria a mochila, o fôlego e as missões do anterior. Esta
## foto guarda as variáveis de script de cada autoload, e `restaurar` as devolve
## antes do caso seguinte: o mesmo começo limpo, sem abrir outro Godot.
##
## As variáveis `static` dos scripts do jogo também entram (a abertura guarda
## nelas o pedido do lobby, o morador guarda quem está falando, o latido guarda a
## hora do último), salvo os caches de malha, textura e material listados em
## CACHES: são dado derivado, e o jogo também os guarda de uma cena para outra.
## Só entram os scripts já carregados na hora da foto.
##
## O que ela não alcança: nó filho criado pelo autoload, e o conteúdo de um
## Resource guardado nele (a referência volta, o conteúdo mexido não). O caso
## que depende disso se declara ISOLADO.

const CACHES := ["_cenas", "_materiais_tratados", "_malhas", "_pegadas", "_troncos", "_troncos_de_malha",
	"_vertices_por_malha", "_icones", "_cache", "_corpos", "_anel", "_ruido", "_malha", "_material",
	"_materiais", "_materials", "_cjk", "_ruidos", "_imagem", "_dados", "_grade", "_malhas_do_leito",
	"_material_de_casa", "_bloco", "_especies_lidas", "ESPECIES", "CORPO", "MODELOS", "VISTA", "_analises",
	"_traducao", "_fichas", "_grupos", "_caixas_das_casas", "_quantas_casas"]

static var _com_estaticas: PackedStringArray = []
static var _procurou := false


## Os scripts do jogo que declaram `static var` (lidos uma vez por processo).
static func scripts_com_estaticas() -> PackedStringArray:
	if not _procurou:
		_procurou = true
		_procurar("res://scripts")
		_procurar("res://tools/jev")
	return _com_estaticas


static func _procurar(pasta: String) -> void:
	var dir := DirAccess.open(pasta)
	if dir == null:
		return
	for arquivo in dir.get_files():
		if arquivo.ends_with(".gd") and "\nstatic var " in ("\n" + FileAccess.get_file_as_string(pasta.path_join(arquivo))):
			_com_estaticas.append(pasta.path_join(arquivo))
	for sub in dir.get_directories():
		_procurar(pasta.path_join(sub))


static func autoloads() -> PackedStringArray:
	var nomes: PackedStringArray = []
	for propriedade in ProjectSettings.get_property_list():
		var chave := String(propriedade["name"])
		if chave.begins_with("autoload/"):
			nomes.append(chave.trim_prefix("autoload/"))
	return nomes


## `com_arquivos` só com perfil descartável: o user:// volta a ser o da foto.
static func fotografar(raiz: Node, com_arquivos: bool = false) -> Dictionary:
	var foto := {"autoloads": {}, "arquivos": {}, "com_arquivos": com_arquivos}
	for nome in autoloads():
		var no := raiz.get_node_or_null(NodePath(nome))
		if no == null:
			continue
		var valores := {}
		for propriedade in no.get_property_list():
			if int(propriedade["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				valores[propriedade["name"]] = copia(no.get(propriedade["name"]))
		foto["autoloads"][nome] = valores
	var estaticas := {}
	for caminho in scripts_com_estaticas():
		if not ResourceLoader.has_cached(caminho):
			continue
		var script: Script = load(caminho)
		var valores := {}
		for propriedade in script.get_property_list():
			var nome := String(propriedade["name"])
			if int(propriedade["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE and not CACHES.has(nome):
				valores[nome] = copia(script.get(nome))
		if not valores.is_empty():
			estaticas[caminho] = valores
	foto["estaticas"] = estaticas
	if com_arquivos:
		foto["arquivos"] = ler_pasta("user://")
	return foto


## Referência a objeto que já foi liberado fica como está: não há o que devolver.
static func restaurar(raiz: Node, foto: Dictionary) -> void:
	if foto.is_empty():
		return
	for nome in foto["autoloads"]:
		var no := raiz.get_node_or_null(NodePath(nome))
		if no == null:
			continue
		var valores: Dictionary = foto["autoloads"][nome]
		for propriedade in valores:
			_devolver(no, propriedade, valores[propriedade])
	for caminho in foto.get("estaticas", {}):
		var script: Script = load(caminho)
		var estaticas: Dictionary = foto["estaticas"][caminho]
		for nome in estaticas:
			_devolver(script, nome, estaticas[nome])
	if foto["com_arquivos"]:
		var guardados: Dictionary = foto["arquivos"]
		var presentes := ler_pasta("user://")
		for caminho in presentes:
			if not guardados.has(caminho):
				DirAccess.remove_absolute(caminho)
		for caminho in guardados:
			if not presentes.has(caminho) or presentes[caminho] != guardados[caminho]:
				DirAccess.make_dir_recursive_absolute(caminho.get_base_dir())
				var arquivo := FileAccess.open(caminho, FileAccess.WRITE)
				if arquivo != null:
					arquivo.store_buffer(guardados[caminho])


## Os autoloads saíram do que está na foto? (Referência a objeto não conta: o
## mesmo estado pode apontar para outro nó.) É assim que o anfitrião sabe que o
## caso preparou alguma coisa (uma partida nova, uma vaga) antes de pedir o vale.
static func difere(raiz: Node, foto: Dictionary) -> String:
	if foto.is_empty():
		return ""
	for nome in foto["autoloads"]:
		var no := raiz.get_node_or_null(NodePath(nome))
		if no == null:
			continue
		var valores: Dictionary = foto["autoloads"][nome]
		for propriedade in valores:
			var valor = valores[propriedade]
			# Objeto e número com vírgula ficam de fora: o relógio anda sozinho a cada quadro.
			if typeof(valor) == TYPE_OBJECT or typeof(valor) == TYPE_FLOAT:
				continue
			var agora = no.get(propriedade)
			if typeof(agora) != typeof(valor) or agora != valor:
				return "%s.%s" % [nome, propriedade]
	return ""


static func _devolver(dono: Object, propriedade: String, valor: Variant) -> void:
	if typeof(valor) == TYPE_OBJECT and valor != null and not is_instance_valid(valor):
		return
	var agora = dono.get(propriedade)
	if typeof(agora) == typeof(valor) and agora == valor:
		return
	dono.set(propriedade, copia(valor))


static func copia(valor: Variant) -> Variant:
	match typeof(valor):
		TYPE_ARRAY, TYPE_DICTIONARY:
			return valor.duplicate(true)
		TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, \
				TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, \
				TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY, TYPE_PACKED_VECTOR4_ARRAY:
			return valor.duplicate()
	return valor


static func ler_pasta(pasta: String) -> Dictionary:
	var lidos := {}
	var dir := DirAccess.open(pasta)
	if dir == null:
		return lidos
	for arquivo in dir.get_files():
		lidos[pasta.path_join(arquivo)] = FileAccess.get_file_as_bytes(pasta.path_join(arquivo))
	for sub in dir.get_directories():
		# O cache de shaders e o de logs do motor não são estado do jogo.
		if pasta == "user://" and (sub == "shader_cache" or sub == "logs" or sub == "vulkan"):
			continue
		lidos.merge(ler_pasta(pasta.path_join(sub)))
	return lidos


## O perfil é descartável? Só então se apaga e reescreve o user://: rodado à
## mão, sem o perfil que o testar.ps1 cria, os saves de quem joga ficam.
## Avisado por `--perfil-descartavel` (a suíte) ou por TESTAR3D_PERFIL_DESCARTAVEL=1
## (o GUT recusa argumento que não conhece), e só vale com "perfil" no caminho.
static func perfil_descartavel() -> bool:
	var avisado := "--perfil-descartavel" in OS.get_cmdline_user_args() or OS.get_environment("TESTAR3D_PERFIL_DESCARTAVEL") == "1"
	return avisado and "perfil" in OS.get_user_data_dir()
