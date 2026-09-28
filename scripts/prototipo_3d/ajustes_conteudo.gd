class_name AjustesConteudo
extends RefCounted
## Ajustes de conteúdo feitos no painel PERSONAGENS, em camadas por cima do projeto:
##   1. o padrão do projeto (data/npcs_3d.json e CatalogoAssets.PECAS);
##   2. data/pecas_ajustes.json — ajustes de peças gravados no projeto (vão para o git);
##   3. user://ajustes_conteudo.json — o que o jogador mexeu nesta máquina.
## Moradores: nome, altura, volume da voz, texto das falas e postos por período. Peças:
## medida (altura/largura), afundar e tronco. Valem na próxima montagem do vale.
## "Gravar no projeto" (só rodando no editor) funde a camada 3 nos arquivos do projeto.

const ARQUIVO_USUARIO := "user://ajustes_conteudo.json"
const NPCS_PROJETO := "res://data/npcs_3d.json"
const PECAS_PROJETO := "res://data/pecas_ajustes.json"
## Campos de peça que o painel ajusta (os demais do catálogo ficam intocados).
const CAMPOS_PECA := ["altura", "largura", "afundar", "tronco"]

static var _usuario: Dictionary = {}
static var _pecas_projeto: Dictionary = {}
static var _carregado := false


static func _carregar() -> void:
	if _carregado:
		return
	_carregado = true
	_usuario = _ler_json(ARQUIVO_USUARIO)
	for chave in ["moradores", "pecas"]:
		if not (_usuario.get(chave) is Dictionary):
			_usuario[chave] = {}
	_pecas_projeto = _ler_json(PECAS_PROJETO)


static func _ler_json(caminho: String) -> Dictionary:
	if not FileAccess.file_exists(caminho):
		return {}
	var dados = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	return dados if dados is Dictionary else {}


static func _salvar() -> void:
	var arquivo := FileAccess.open(ARQUIVO_USUARIO, FileAccess.WRITE)
	if arquivo == null:
		push_warning("Não foi possível salvar os ajustes do painel PERSONAGENS.")
		return
	arquivo.store_string(JSON.stringify(_usuario, "\t"))


# ---------------------------------------------------------------- moradores

## Dados de npcs_3d.json (guia + moradores) com os ajustes do jogador aplicados.
static func npcs(dados: Dictionary) -> Dictionary:
	_carregar()
	var resultado: Dictionary = dados.duplicate(true)
	if resultado.get("guia") is Dictionary:
		resultado["guia"] = morador(resultado["guia"])
	var lista: Array = []
	for entrada in resultado.get("moradores", []):
		lista.append(morador(entrada) if entrada is Dictionary else entrada)
	resultado["moradores"] = lista
	return resultado


## Um morador com os ajustes dele por cima (cópia; o original fica intacto).
static func morador(base: Dictionary) -> Dictionary:
	_carregar()
	var ajuste: Dictionary = _usuario["moradores"].get(String(base.get("id", "")), {})
	if ajuste.is_empty():
		return base
	var resultado: Dictionary = base.duplicate(true)
	for campo in ["nome", "altura", "volume_voz_db"]:
		if ajuste.has(campo):
			resultado[campo] = ajuste[campo]
	if ajuste.get("postos") is Dictionary:
		var postos: Dictionary = resultado.get("postos", {})
		for periodo in ajuste["postos"]:
			postos[periodo] = ajuste["postos"][periodo]
		resultado["postos"] = postos
	if ajuste.get("falas") is Dictionary:
		var falas: Array = resultado.get("falas", [])
		for indice in ajuste["falas"]:
			var i := int(indice)
			if i >= 0 and i < falas.size() and falas[i] is Dictionary:
				falas[i]["texto"] = String(ajuste["falas"][indice])
		resultado["falas"] = falas
	return resultado


static func definir_morador(id: String, campo: String, valor: Variant) -> void:
	_carregar()
	var ajuste: Dictionary = _usuario["moradores"].get(id, {})
	ajuste[campo] = valor
	_usuario["moradores"][id] = ajuste
	_salvar()


static func definir_posto(id: String, periodo: String, ancora: String, deslocamento: Vector3) -> void:
	_carregar()
	var ajuste: Dictionary = _usuario["moradores"].get(id, {})
	var postos: Dictionary = ajuste.get("postos", {})
	postos[periodo] = [ancora, [snappedf(deslocamento.x, 0.1), 0, snappedf(deslocamento.z, 0.1)]]
	ajuste["postos"] = postos
	_usuario["moradores"][id] = ajuste
	_salvar()


static func definir_fala(id: String, indice: int, texto: String) -> void:
	_carregar()
	var ajuste: Dictionary = _usuario["moradores"].get(id, {})
	var falas: Dictionary = ajuste.get("falas", {})
	falas[str(indice)] = texto
	ajuste["falas"] = falas
	_usuario["moradores"][id] = ajuste
	_salvar()


static func morador_ajustado(id: String) -> bool:
	_carregar()
	return _usuario["moradores"].has(id)


static func restaurar_morador(id: String) -> void:
	_carregar()
	_usuario["moradores"].erase(id)
	_salvar()


# ---------------------------------------------------------------- peças

## Especificação da peça: catálogo, ajustes gravados no projeto e os do jogador.
static func peca(chave: String) -> Dictionary:
	_carregar()
	var base: Dictionary = CatalogoAssets.PECAS.get(chave, {})
	var projeto: Dictionary = _pecas_projeto.get(chave, {})
	var usuario: Dictionary = _usuario["pecas"].get(chave, {})
	if projeto.is_empty() and usuario.is_empty():
		return base
	var resultado: Dictionary = base.duplicate(true)
	for camada: Dictionary in [projeto, usuario]:
		for campo in camada:
			if campo in CAMPOS_PECA:
				resultado[campo] = float(camada[campo])
	return resultado


static func definir_peca(chave: String, campo: String, valor: float) -> void:
	_carregar()
	var ajuste: Dictionary = _usuario["pecas"].get(chave, {})
	ajuste[campo] = snappedf(valor, 0.01)
	_usuario["pecas"][chave] = ajuste
	_salvar()
	# Malhas em cache foram medidas com a medida antiga.
	CatalogoAssets.limpar_cache()


static func peca_ajustada(chave: String) -> bool:
	_carregar()
	return _usuario["pecas"].has(chave) or _pecas_projeto.has(chave)


static func restaurar_peca(chave: String) -> void:
	_carregar()
	_usuario["pecas"].erase(chave)
	_salvar()
	CatalogoAssets.limpar_cache()


# ---------------------------------------------------------------- projeto

## Só rodando pelo editor os arquivos res:// são graváveis.
static func pode_gravar_no_projeto() -> bool:
	return OS.has_feature("editor")


## Funde os ajustes do jogador nos arquivos do projeto e limpa a camada do usuário.
## Devolve quantos moradores e peças foram gravados.
static func gravar_no_projeto() -> Vector2i:
	_carregar()
	if not pode_gravar_no_projeto():
		return Vector2i.ZERO
	var gravados := Vector2i.ZERO
	if not (_usuario["moradores"] as Dictionary).is_empty():
		var dados := _ler_json(NPCS_PROJETO)
		if not dados.is_empty():
			var fundido := npcs(dados)
			var arquivo := FileAccess.open(NPCS_PROJETO, FileAccess.WRITE)
			if arquivo != null:
				arquivo.store_string(JSON.stringify(fundido, "  ", false) + "\n")
				gravados.x = (_usuario["moradores"] as Dictionary).size()
				_usuario["moradores"] = {}
	if not (_usuario["pecas"] as Dictionary).is_empty():
		for chave in _usuario["pecas"]:
			var projeto: Dictionary = _pecas_projeto.get(chave, {})
			projeto.merge(_usuario["pecas"][chave], true)
			_pecas_projeto[chave] = projeto
		var arquivo := FileAccess.open(PECAS_PROJETO, FileAccess.WRITE)
		if arquivo != null:
			arquivo.store_string(JSON.stringify(_pecas_projeto, "  ", true) + "\n")
			gravados.y = (_usuario["pecas"] as Dictionary).size()
			_usuario["pecas"] = {}
	_salvar()
	return gravados
