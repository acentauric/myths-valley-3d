extends Node
## A ATUALIZAÇÃO DO JOGO PELO SITE.
##
## O executável pergunta ao site qual é a build mais nova
## (`https://mythsvalley.app.br/api/jogo/atualizacao`). Havendo uma maior que a
## deste jogo (`Versao.BUILD_NUMERO`), a abertura oferece no rodapé do retábulo
## e, se o jogador aceitar:
##
##   1. baixa o zip da build para `user://atualizacao/`;
##   2. confere o SHA-256 contra o manifesto — diferente, o arquivo vai fora e o
##      executável fica intacto;
##   3. extrai o zip numa pasta ao lado do executável (mesmo disco: a troca é
##      um renomear, não uma cópia de 540 MB);
##   4. renomeia o executável em uso para `.old` (o Windows deixa renomear um
##      executável aberto; o que não deixa é sobrescrever) e põe o novo no lugar;
##   5. pede para reiniciar. Na abertura seguinte, o `.old` e as sobras somem.
##
## O executável é único, com o pacote embutido: atualizar é trocar um arquivo.
##
## SÓ INSTALA SOZINHO NUMA BUILD EXPORTADA NO WINDOWS, com a pasta do jogo
## gravável. No editor, nos testes ou numa pasta protegida, a oferta vira "baixar
## no site" e abre a página de download.
##
## NADA DE REDE SEM PEDIDO: a consulta só parte quando a abertura chama
## `verificar()`, uma vez por sessão, e só numa build exportada (ou com
## `--atualizacao-url=` dado à mão). No editor e na bateria de testes, que abrem
## o menu, nenhuma requisição sai.

signal mudou

const MANIFESTO := "https://mythsvalley.app.br/api/jogo/atualizacao"
const PASTA_DOWNLOAD := "user://atualizacao"
## Pasta das sobras ao lado do executável (a extração e o que vier dela).
const PASTA_EXTRACAO := ".atualizacao"
const SUFIXO_ANTIGO := ".old"
const TEMPO_CONSULTA := 8.0

enum Estado { PARADO, VERIFICANDO, EM_DIA, DISPONIVEL, BAIXANDO, CONFERINDO, INSTALANDO, PRONTA, FALHOU }

var estado: Estado = Estado.PARADO
var manifesto: Dictionary = {}
## 0 a 1 enquanto baixa.
var progresso := 0.0
var erro := ""

var _http: HTTPRequest
var _trabalho: Thread


func _ready() -> void:
	if _instalavel():
		limpar_restos(OS.get_executable_path())
	# `-- --atualizar-agora`: verifica, baixa e instala sem clique, e sai dizendo como
	# terminou (ATUALIZACAO_PRONTA, _EM_DIA ou _FALHOU). É a prova de ponta a ponta
	# de uma build exportada contra o site; o jogo normal nunca passa por aqui.
	if "--atualizar-agora" in OS.get_cmdline_user_args():
		mudou.connect(_seguir_sem_clique)
		verificar.call_deferred()


## Pergunta ao site pela build mais nova. Uma vez por sessão; sem rede, fica quieto.
## `--atualizacao-url=<url>` (argumento depois de `--`) troca o manifesto, para testar.
func verificar() -> void:
	if estado != Estado.PARADO or not (OS.has_feature("template") or _url_do_manifesto() != MANIFESTO):
		return
	estado = Estado.VERIFICANDO
	_http = HTTPRequest.new()
	_http.timeout = TEMPO_CONSULTA
	add_child(_http)
	_http.request_completed.connect(_ao_receber_manifesto, CONNECT_ONE_SHOT)
	var url := "%s?build=%d&plataforma=windows" % [_url_do_manifesto(), _build_atual()]
	if _http.request(url) != OK:
		_mudar(Estado.EM_DIA)


func _seguir_sem_clique() -> void:
	match estado:
		Estado.DISPONIVEL:
			atualizar()
		Estado.PRONTA:
			print("ATUALIZACAO_PRONTA: Build %d instalada" % build_nova())
			get_tree().quit(0)
		Estado.EM_DIA:
			print("ATUALIZACAO_EM_DIA: Build %d" % _build_atual())
			get_tree().quit(0)
		Estado.FALHOU:
			print("ATUALIZACAO_FALHOU: " + erro)
			get_tree().quit(1)


func build_nova() -> int:
	return int(manifesto.get("build", 0))


## Instala sozinho? Se não, a oferta leva à página de download.
func instala_sozinho() -> bool:
	return _instalavel() and pasta_gravavel(OS.get_executable_path().get_base_dir())


## O que o botão do rodapé faz: baixar e instalar, ou abrir o site.
func atualizar() -> void:
	if estado not in [Estado.DISPONIVEL, Estado.FALHOU]:
		return
	if not instala_sozinho():
		OS.shell_open(pagina_de_download())
		return
	DirAccess.make_dir_recursive_absolute(PASTA_DOWNLOAD)
	var destino := "%s/%s" % [PASTA_DOWNLOAD, str(manifesto.get("arquivo", "atualizacao.zip"))]
	_http = HTTPRequest.new()
	_http.use_threads = true
	_http.download_file = destino
	_http.download_chunk_size = 1 << 20
	add_child(_http)
	_http.request_completed.connect(_ao_baixar.bind(destino), CONNECT_ONE_SHOT)
	progresso = 0.0
	erro = ""
	_mudar(Estado.BAIXANDO)
	if _http.request(str(manifesto["url"])) != OK:
		_falhar("não foi possível começar o download")


func reiniciar() -> void:
	if estado != Estado.PRONTA:
		return
	OS.create_process(OS.get_executable_path(), OS.get_cmdline_args())
	get_tree().quit()


func pagina_de_download() -> String:
	var paginas: Dictionary = manifesto.get("pagina", {}) if manifesto.get("pagina") is Dictionary else {}
	var idioma: String = ["pt", "en", "es"][clampi(_indice_idioma(), 0, 2)]
	return str(paginas.get(idioma, paginas.get("pt", "https://mythsvalley.app.br/jogar")))


func _process(_delta: float) -> void:
	if estado != Estado.BAIXANDO or _http == null:
		return
	var total := _http.get_body_size()
	if total <= 0:
		total = int(manifesto.get("bytes", 0))
	if total > 0:
		var novo := clampf(float(_http.get_downloaded_bytes()) / total, 0.0, 1.0)
		if absf(novo - progresso) >= 0.01:
			progresso = novo
			mudou.emit()


func _ao_receber_manifesto(resultado: int, codigo: int, _cabecalhos: PackedStringArray, corpo: PackedByteArray) -> void:
	_soltar_http()
	if resultado != HTTPRequest.RESULT_SUCCESS or codigo != 200:
		_mudar(Estado.EM_DIA)
		return
	var dados = JSON.parse_string(corpo.get_string_from_utf8())
	if dados is Dictionary and manifesto_valido(dados) and ha_versao_nova(dados, _build_atual()):
		manifesto = dados
		_mudar(Estado.DISPONIVEL)
	else:
		_mudar(Estado.EM_DIA)


func _ao_baixar(resultado: int, codigo: int, _cabecalhos: PackedStringArray, _corpo: PackedByteArray, arquivo: String) -> void:
	_soltar_http()
	if resultado != HTTPRequest.RESULT_SUCCESS or codigo != 200:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(arquivo))
		_falhar("o download não terminou (%d/%d)" % [resultado, codigo])
		return
	progresso = 1.0
	_mudar(Estado.CONFERINDO)
	# Conferir e extrair 360 MB trava o quadro: vai para uma linha separada.
	_trabalho = Thread.new()
	_trabalho.start(_instalar.bind(ProjectSettings.globalize_path(arquivo), str(manifesto["sha256"]), OS.get_executable_path()))


## Roda fora da linha principal: confere, extrai e troca. Volta pelo call_deferred.
func _instalar(zip: String, sha_esperado: String, executavel: String) -> void:
	if sha256_do_arquivo(zip) != sha_esperado.to_lower():
		DirAccess.remove_absolute(zip)
		call_deferred("_terminar", "o arquivo baixado não confere com o site (SHA-256)")
		return
	call_deferred("_mudar", Estado.INSTALANDO)
	var pasta := executavel.get_base_dir().path_join(PASTA_EXTRACAO)
	_apagar_pasta(pasta)
	DirAccess.make_dir_recursive_absolute(pasta)
	var falha := extrair_zip(zip, pasta)
	if falha.is_empty():
		var novo := achar_executavel(pasta, executavel.get_file())
		falha = "o zip não traz %s" % executavel.get_file() if novo.is_empty() else trocar_executavel(executavel, novo)
	DirAccess.remove_absolute(zip)
	call_deferred("_terminar", falha)


func _terminar(falha: String) -> void:
	if _trabalho != null:
		_trabalho.wait_to_finish()
		_trabalho = null
	if falha.is_empty():
		_mudar(Estado.PRONTA)
	else:
		_falhar(falha)


func _falhar(motivo: String) -> void:
	erro = motivo
	push_warning("Atualizacao: " + motivo)
	_mudar(Estado.FALHOU)


func _mudar(novo: Estado) -> void:
	estado = novo
	mudou.emit()


func _soltar_http() -> void:
	if _http != null:
		_http.queue_free()
		_http = null


func _build_atual() -> int:
	var versao := get_node_or_null("/root/Versao")
	return int(versao.BUILD_NUMERO) if versao != null else 0


func _indice_idioma() -> int:
	var preferencias := ConfigFile.new()
	if preferencias.load("user://preferencias_visuais.cfg") != OK:
		return 0
	return int(preferencias.get_value("menu", "idioma", 0))


func _url_do_manifesto() -> String:
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with("--atualizacao-url="):
			return argumento.trim_prefix("--atualizacao-url=")
	return MANIFESTO


static func _instalavel() -> bool:
	return OS.has_feature("template") and OS.get_name() == "Windows"


# ---------------------------------------------------------------------------
# A lógica pura, sem rede nem estado — é o que o portão (tests/atualizacao.gd) cobra.

## O manifesto tem o que a instalação precisa, e de onde se espera.
static func manifesto_valido(dados: Dictionary) -> bool:
	var sha := str(dados.get("sha256", ""))
	var url := str(dados.get("url", ""))
	return int(dados.get("build", 0)) > 0 \
		and url.begins_with("https://") \
		and str(dados.get("arquivo", "")).ends_with(".zip") \
		and sha.length() == 64 and sha.is_valid_hex_number()


static func ha_versao_nova(dados: Dictionary, build_atual: int) -> bool:
	return manifesto_valido(dados) and int(dados["build"]) > build_atual


static func sha256_do_arquivo(caminho: String) -> String:
	var arquivo := FileAccess.open(caminho, FileAccess.READ)
	if arquivo == null:
		return ""
	var contexto := HashingContext.new()
	contexto.start(HashingContext.HASH_SHA256)
	while not arquivo.eof_reached():
		contexto.update(arquivo.get_buffer(1 << 20))
	arquivo.close()
	return contexto.finish().hex_encode()


## Extrai com o tar do Windows (lê o zip em fluxo); sem ele, pelo ZIPReader.
static func extrair_zip(zip: String, destino: String) -> String:
	var tar := OS.get_environment("SystemRoot").path_join("System32/tar.exe")
	if FileAccess.file_exists(tar):
		var saida: Array = []
		if OS.execute(tar, ["-xf", zip, "-C", destino], saida, true) == 0:
			return ""
	var leitor := ZIPReader.new()
	if leitor.open(zip) != OK:
		return "não foi possível abrir o zip"
	for nome in leitor.get_files():
		var alvo := destino.path_join(nome)
		if nome.ends_with("/"):
			DirAccess.make_dir_recursive_absolute(alvo)
			continue
		DirAccess.make_dir_recursive_absolute(alvo.get_base_dir())
		var arquivo := FileAccess.open(alvo, FileAccess.WRITE)
		if arquivo == null:
			leitor.close()
			return "não foi possível gravar " + nome
		arquivo.store_buffer(leitor.read_file(nome))
		arquivo.close()
	leitor.close()
	return ""


## O executável de mesmo nome dentro do que foi extraído (o zip pode ter uma pasta).
static func achar_executavel(pasta: String, nome: String) -> String:
	if FileAccess.file_exists(pasta.path_join(nome)):
		return pasta.path_join(nome)
	for sub in DirAccess.get_directories_at(pasta):
		var achado := achar_executavel(pasta.path_join(sub), nome)
		if not achado.is_empty():
			return achado
	return ""


## Põe o novo no lugar do atual, guardando o atual como `.old`. Devolve "" se deu
## certo; se a segunda troca falhar, o atual volta para o lugar.
static func trocar_executavel(atual: String, novo: String) -> String:
	var antigo := atual + SUFIXO_ANTIGO
	if FileAccess.file_exists(antigo) and DirAccess.remove_absolute(antigo) != OK:
		return "não foi possível apagar " + antigo.get_file()
	if DirAccess.rename_absolute(atual, antigo) != OK:
		return "não foi possível afastar o executável atual"
	if DirAccess.rename_absolute(novo, atual) != OK:
		DirAccess.rename_absolute(antigo, atual)
		return "não foi possível pôr o executável novo no lugar"
	return ""


## Apaga o `.old` e a pasta de extração ao lado do executável, e os downloads.
static func limpar_restos(executavel: String) -> void:
	var antigo := executavel + SUFIXO_ANTIGO
	if FileAccess.file_exists(antigo):
		DirAccess.remove_absolute(antigo)
	_apagar_pasta(executavel.get_base_dir().path_join(PASTA_EXTRACAO))
	_apagar_pasta(ProjectSettings.globalize_path(PASTA_DOWNLOAD))


static func pasta_gravavel(pasta: String) -> bool:
	var sonda := pasta.path_join(".gravavel")
	var arquivo := FileAccess.open(sonda, FileAccess.WRITE)
	if arquivo == null:
		return false
	arquivo.close()
	DirAccess.remove_absolute(sonda)
	return true


static func _apagar_pasta(pasta: String) -> void:
	if not DirAccess.dir_exists_absolute(pasta):
		return
	for arquivo in DirAccess.get_files_at(pasta):
		DirAccess.remove_absolute(pasta.path_join(arquivo))
	for sub in DirAccess.get_directories_at(pasta):
		_apagar_pasta(pasta.path_join(sub))
	DirAccess.remove_absolute(pasta)
