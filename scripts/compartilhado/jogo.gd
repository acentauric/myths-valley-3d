extends Node
## Estado global da partida e acesso aos dados de texto.
##
## O texto do jogo mora em data/ (JSON), não no código: separar texto e código
## permite reescrever falas sem tocar em GDScript. `{jogador}` é trocado pelo nome digitado.

const NOME_PADRAO := "Viajante"

## Nome de cada construção do mapa, para a tela de obras dizer onde o jogador
## está em vez de mostrar o id.
const NOME_DAS_CONSTRUCOES := {
	"casa": "sua casa",
	"casa_avos": "casa dos avós do {npc_1_nome}",
	"casa_vizinha": "casa do vizinho",
	"armazem": "armazém do arraial",
	"capela": "capela do arraial",
	"casa_pedro": "casa do {npc_1_nome}",
	"oficina": "sua oficina",
	"canteiro": "seu canteiro de obras",
	"bar": "bar da praia",
	"casa_de_pasto": "casa de pasto da praia",
	"casa_benedito": "casa do Seu Benedito",
	"casa_zefa": "casa da Dona Zefa",
	"casa_tonho": "casa do Tonho",
	"cemiterio": "cemitério",
	"mirante": "mirante",

	# AS CINCO PEÇAS DO ARRAIAL. Estar nesta lista é o que faz o E abrir a aba
	# de obras em cima delas — sem isto, a obra comunitária existe no catálogo e
	# o jogador não tem por onde chegar nela. É também por isto que o `poco` e a
	# `carroca` estavam no mapa desde o começo sem servir para nada.
	
	"poco": "poço da praça",
	"forno_barro": "forno do arraial",
	"monjolo": "monjolo do riacho",
	"carroca": "carroça do arraial",
	"trapiche": "trapiche da praia",
}

var nome_jogador: String = NOME_PADRAO

## Dados genéricos dos NPCs (editáveis no Admin)
var npc_1_nome: String = "Pedro"
var npc_1_nome_completo: String = "Pedro Nolasco da Encarnação"

## Aliases de retrocompatibilidade
var nome_pedro: String:
	get: return npc_1_nome
	set(v): npc_1_nome = v

var nome_pedro_completo: String:
	get: return npc_1_nome_completo
	set(v): npc_1_nome_completo = v

## Réis. O jogador começa com o troco da viagem da capital.
var dinheiro: int = 250

## Opções visuais do menu
## 1: PixelLab (Pixel Art 2D Animado), 2: LTX Video AI (Cinemático 3D), 0: Estático (Imagem)
var modo_fundo_menu: int = 0

## Fonte dos botões de opções do menu (1: Almendra Clássica, 2: Miva Pixel Art)
var fonte_menu_opcao: int = 1
var logo_menu_opcao: int = 3
var movimento_reduzido: bool = false
const ARQUIVO_CONFIG_VISUAL := "user://apresentacao.cfg"

var video_introducao_ativo: bool:
	get: return modo_fundo_menu != 0
	set(v): modo_fundo_menu = 1 if v else 0

const ARQUIVO_CONFIG_ADMIN := "user://admin_config.json"
var _cache: Dictionary = {}


func _ready() -> void:
	carregar_config_visual()
	# O TAMANHO MÍNIMO DA JANELA SAIU DAQUI, e foi para o menu inicial.
	#
	# 640×360 é a resolução de projeto DESTE jogo, e portanto apresentação e
	# não regra. Este arquivo é compartilhado com o protótipo 3D, que roda em
	# 1280×720 com mínimo de 960×540 — deixar a linha aqui encolheria a janela
	# de lá ao subir o autoload, sem que ninguém ligasse uma coisa à outra.
	#
	# É o mesmo caso da tecla da mão, que saiu do `Inventario` pelo mesmo
	# motivo: o que depende do projeto fica no projeto, o que é regra viaja.
	# Ver `MenuInicial._ready`.
	call_deferred("carregar_config_admin")


func carregar_config_admin() -> void:
	if not FileAccess.file_exists(ARQUIVO_CONFIG_ADMIN):
		return
	var arq := FileAccess.open(ARQUIVO_CONFIG_ADMIN, FileAccess.READ)
	if arq == null:
		return
	var texto_json := arq.get_as_text()
	arq.close()
	var lido = JSON.parse_string(texto_json)
	if typeof(lido) == TYPE_DICTIONARY:
		if lido.has("npc_1_nome"):
			var n := str(lido["npc_1_nome"]).strip_edges()
			if n != "":
				npc_1_nome = n
		elif lido.has("nome_pedro"):
			var n := str(lido["nome_pedro"]).strip_edges()
			if n != "":
				npc_1_nome = n

		if lido.has("npc_1_nome_completo"):
			var nc := str(lido["npc_1_nome_completo"]).strip_edges()
			if nc != "":
				npc_1_nome_completo = nc
		elif lido.has("nome_pedro_completo"):
			var nc := str(lido["nome_pedro_completo"]).strip_edges()
			if nc != "":
				npc_1_nome_completo = nc
		else:
			npc_1_nome_completo = npc_1_nome + " Nolasco da Encarnação"

		var p_node = get_node_or_null("/root/Progressao")
		if p_node != null:
			if lido.has("energia_maxima"):
				p_node.energia_maxima = float(lido["energia_maxima"])
			if lido.has("recuperacao_ao_dormir"):
				p_node.recuperacao_ao_dormir = float(lido["recuperacao_ao_dormir"])
			if lido.has("recuperacao_ao_desmaiar"):
				p_node.recuperacao_ao_desmaiar = float(lido["recuperacao_ao_desmaiar"])
			if lido.has("eficiencia"):
				p_node.eficiencia = float(lido["eficiencia"])
			p_node.mudou.emit()

		# Preferências visuais são carregadas antes do menu, em arquivo próprio.


func salvar_config_admin(dados_nomes: Dictionary = {}, dados_progressao: Dictionary = {}) -> void:
	if dados_nomes.has("npc_1_nome"):
		var n := str(dados_nomes["npc_1_nome"]).strip_edges()
		if n != "":
			npc_1_nome = n
	if dados_nomes.has("npc_1_nome_completo"):
		var nc := str(dados_nomes["npc_1_nome_completo"]).strip_edges()
		if nc != "":
			npc_1_nome_completo = nc

	var p_node = get_node_or_null("/root/Progressao")
	if p_node != null:
		if dados_progressao.has("energia_maxima"):
			p_node.energia_maxima = float(dados_progressao["energia_maxima"])
		if dados_progressao.has("recuperacao_ao_dormir"):
			p_node.recuperacao_ao_dormir = float(dados_progressao["recuperacao_ao_dormir"])
		if dados_progressao.has("recuperacao_ao_desmaiar"):
			p_node.recuperacao_ao_desmaiar = float(dados_progressao["recuperacao_ao_desmaiar"])
		if dados_progressao.has("eficiencia"):
			p_node.eficiencia = float(dados_progressao["eficiencia"])
		p_node.mudou.emit()

	var arq := FileAccess.open(ARQUIVO_CONFIG_ADMIN, FileAccess.WRITE)
	if arq != null:
		var dados_salvar := {
			"npc_1_nome": npc_1_nome,
			"npc_1_nome_completo": npc_1_nome_completo,
			"nome_pedro": npc_1_nome,
			"nome_pedro_completo": npc_1_nome_completo,
			"energia_maxima": p_node.energia_maxima if p_node else 100.0,
			"recuperacao_ao_dormir": p_node.recuperacao_ao_dormir if p_node else 40.0,
			"recuperacao_ao_desmaiar": p_node.recuperacao_ao_desmaiar if p_node else 15.0,
			"eficiencia": p_node.eficiencia if p_node else 1.0,
			"modo_fundo_menu": modo_fundo_menu,
			"video_introducao_ativo": video_introducao_ativo,
			"fonte_menu_opcao": fonte_menu_opcao,
		}
		arq.store_string(JSON.stringify(dados_salvar, "\t"))
		arq.close()


func definir_modo_fundo(opcao: int) -> void:
	modo_fundo_menu = clamp(opcao, 0, 2)
	salvar_config_visual()


func definir_fonte_menu(opcao: int) -> void:
	fonte_menu_opcao = clamp(opcao, 1, 2)
	salvar_config_visual()


func definir_logo_menu(opcao: int) -> void:
	logo_menu_opcao = clampi(opcao, 0, 3)
	salvar_config_visual()


func definir_movimento_reduzido(ativo: bool) -> void:
	movimento_reduzido = ativo
	salvar_config_visual()


func carregar_config_visual() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(ARQUIVO_CONFIG_VISUAL) == OK:
		modo_fundo_menu = clampi(int(cfg.get_value("visual", "fundo", 0)), 0, 2)
		fonte_menu_opcao = clampi(int(cfg.get_value("visual", "fonte", 1)), 1, 2)
		logo_menu_opcao = clampi(int(cfg.get_value("visual", "logo", 3)), 0, 3)
		movimento_reduzido = bool(cfg.get_value("visual", "movimento_reduzido", false))
	elif FileAccess.file_exists(ARQUIVO_CONFIG_ADMIN):
		var legado = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO_CONFIG_ADMIN))
		if legado is Dictionary:
			modo_fundo_menu = clampi(int(legado.get("modo_fundo_menu", 2 if legado.get("video_introducao_ativo", false) else 0)), 0, 2)
			fonte_menu_opcao = clampi(int(legado.get("fonte_menu_opcao", 1)), 1, 2)


func salvar_config_visual() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("visual", "fundo", modo_fundo_menu)
	cfg.set_value("visual", "fonte", fonte_menu_opcao)
	cfg.set_value("visual", "logo", logo_menu_opcao)
	cfg.set_value("visual", "movimento_reduzido", movimento_reduzido)
	if cfg.save(ARQUIVO_CONFIG_VISUAL) != OK:
		push_warning("Não foi possível salvar as preferências visuais.")


func obter_caminho_fonte_menu() -> String:
	match fonte_menu_opcao:
		2:
			return "res://assets/fonts/miva.ttf"
		_:
			return "res://assets/fonts/Almendra-Bold.ttf"


func alternar_video_introducao() -> bool:
	if modo_fundo_menu == 0:
		modo_fundo_menu = 1
	elif modo_fundo_menu == 1:
		modo_fundo_menu = 2
	else:
		modo_fundo_menu = 0
	salvar_config_visual()
	return video_introducao_ativo


func salvar_npc_1_nome(novo_nome: String, novo_nome_completo: String = "") -> void:
	salvar_config_admin({"npc_1_nome": novo_nome, "npc_1_nome_completo": novo_nome_completo})


func salvar_nome_pedro(novo_nome: String, novo_nome_completo: String = "") -> void:
	salvar_npc_1_nome(novo_nome, novo_nome_completo)



func nome_da_construcao(id: String) -> String:
	return texto(str(NOME_DAS_CONSTRUCOES.get(id, id)))


## Nome de quem mora no arraial, lido do mesmo JSON que guarda as falas.
func nome_do_morador(id: String) -> String:
	if id == "pedro" or id == "npc_1":
		return npc_1_nome
	var dele: Dictionary = dados("res://data/dialogos/aldeoes.json").get(id, {})
	return str(dele.get("nome", id.capitalize()))


## Lê um JSON de data/ e guarda em cache. Devolve {} se faltar ou estiver quebrado.
func dados(caminho: String) -> Dictionary:
	if _cache.has(caminho):
		return _cache[caminho]

	var arquivo := FileAccess.open(caminho, FileAccess.READ)
	if arquivo == null:
		push_error("Não consegui abrir %s" % caminho)
		return {}

	var lido = JSON.parse_string(arquivo.get_as_text())
	arquivo.close()
	if typeof(lido) != TYPE_DICTIONARY:
		push_error("%s não contém um objeto JSON" % caminho)
		return {}

	_cache[caminho] = lido
	return lido


## Troca os marcadores de um texto.
func texto(bruto: String) -> String:
	return bruto.replace("{jogador}", nome_jogador)\
		.replace("{npc_1_nome_completo}", npc_1_nome_completo)\
		.replace("{npc_1_nome}", npc_1_nome)\
		.replace("{pedro_completo}", npc_1_nome_completo)\
		.replace("{pedro}", npc_1_nome)


## Mesma troca, para uma lista de falas.
func falas(brutas: Array) -> Array:
	var saida: Array = []
	for f in brutas:
		saida.append(texto(str(f)))
	return saida
