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
## EDIÇÃO ESTÁTICA: a build do concurso Tripothon (preset "Windows Tripothon", feature
## `tripothon`) é fixa para o evento. Nela nada consulta o site, baixa ou instala: o
## estado fica PARADO para sempre e a abertura mostra a linha desativada
## (`edicao_estatica()`).
##
## NUNCA EM SILÊNCIO (#231): build nova que o atualizador não pode instalar (zip ou
## executável acima dos limites, ou pouco espaço em disco) NÃO vira "em dia". O estado é
## FALHOU, com o motivo (`erro`) e a oferta de baixar pelo site (`so_pelo_site`). Em
## outubro de 2026 os limites eram de uma build de 360 MB, o jogo passou de 1 GB, e a Build 9
## ficou sem ver a 10 sem dizer nada a ninguém.
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
const ORIGEM := "https://mythsvalley.app.br"
## OS LIMITES SEGUEM O JOGO, E COM FOLGA. A Build 10 tem 1,14 GB de zip e 1,45 GB de executável
## (data/atualizador_builds.json guarda os tamanhos medidos de cada build, e o portão
## tests/atualizacao.gd cobra 2x os da última). Os 4 GB do zip são também o teto do ZIP sem
## ZIP64, que é o único formato que `conferir_zip` aceita.
const MAX_ZIP := 4 * 1024 * 1024 * 1024
const MAX_EXTRAIDO := 6 * 1024 * 1024 * 1024
## Folga de disco além do que se baixa e se extrai.
const MARGEM_DE_ESPACO := 512 * 1024 * 1024
const MAX_ENTRADAS := 16

enum Estado { PARADO, VERIFICANDO, EM_DIA, DISPONIVEL, BAIXANDO, CONFERINDO, INSTALANDO, PRONTA, FALHOU }

var estado: Estado = Estado.PARADO
var manifesto: Dictionary = {}
## 0 a 1 enquanto baixa.
var progresso := 0.0
var erro := ""
## A falha não se resolve tentando de novo: o botão leva à página de download (build
## grande demais para os limites, ou sem espaço em disco).
var so_pelo_site := false

## Só para o portão (tests/atualizacao.gd): finge a feature `tripothon` sem exportar.
static var forcar_estatica := false

var _http: HTTPRequest
var _trabalho: Thread
var _redirecionamentos := 0


func _ready() -> void:
	if edicao_estatica():
		return
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
	if edicao_estatica() or estado != Estado.PARADO or not (OS.has_feature("template") or _url_do_manifesto() != MANIFESTO):
		return
	estado = Estado.VERIFICANDO
	_http = HTTPRequest.new()
	_http.timeout = TEMPO_CONSULTA
	_http.body_size_limit = 65536
	_http.max_redirects = 0
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
	return not edicao_estatica() and _instalavel() and pasta_gravavel(OS.get_executable_path().get_base_dir())


## O que o botão do rodapé faz: baixar e instalar, ou abrir o site.
func atualizar() -> void:
	if edicao_estatica() or estado not in [Estado.DISPONIVEL, Estado.FALHOU]:
		return
	if so_pelo_site or not instala_sozinho():
		OS.shell_open(pagina_de_download())
		return
	# O ESPAÇO VEM ANTES DO DOWNLOAD: 1 GB baixado para descobrir que não cabe é pior que dizer já.
	var sem_espaco := _conferir_espaco()
	if not sem_espaco.is_empty():
		so_pelo_site = true
		_falhar(sem_espaco)
		return
	DirAccess.make_dir_recursive_absolute(PASTA_DOWNLOAD)
	# O servidor não escolhe um caminho no computador do jogador.
	var destino := PASTA_DOWNLOAD.path_join("atualizacao.zip")
	_redirecionamentos = 0
	_requisitar_download(str(manifesto["url"]), destino)


func _requisitar_download(url: String, destino: String) -> void:
	_http = HTTPRequest.new()
	_http.use_threads = true
	_http.timeout = 300.0
	_http.max_redirects = 0
	_http.body_size_limit = int(manifesto["bytes"])
	_http.download_file = destino
	_http.download_chunk_size = 1 << 20
	add_child(_http)
	_http.request_completed.connect(_ao_baixar.bind(destino), CONNECT_ONE_SHOT)
	progresso = 0.0
	erro = ""
	_mudar(Estado.BAIXANDO)
	if _http.request(url) != OK:
		_falhar("não foi possível começar o download")


func reiniciar() -> void:
	if estado != Estado.PRONTA:
		return
	OS.create_process(OS.get_executable_path(), OS.get_cmdline_args())
	get_tree().quit()


func pagina_de_download() -> String:
	var paginas: Dictionary = manifesto.get("pagina", {}) if manifesto.get("pagina") is Dictionary else {}
	var idioma: String = ["pt", "en", "es", "en"][clampi(_indice_idioma(), 0, 3)]
	var pagina := str(paginas.get(idioma, paginas.get("pt", ORIGEM + "/jogar")))
	return pagina if url_confiavel(pagina) else ORIGEM + "/jogar"


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
	if not (dados is Dictionary) or not manifesto_bem_formado(dados) or int(dados["build"]) <= _build_atual():
		_mudar(Estado.EM_DIA)
		return
	manifesto = dados
	# Manifesto certo e build nova, mas fora dos limites: o jogador precisa saber (#231).
	if grande_demais(dados):
		so_pelo_site = true
		_falhar(_motivo_de_grande_demais(dados))
	else:
		_mudar(Estado.DISPONIVEL)


func _ao_baixar(resultado: int, codigo: int, cabecalhos: PackedStringArray, _corpo: PackedByteArray, arquivo: String) -> void:
	_soltar_http()
	if codigo in [301, 302, 303, 307, 308] and resultado in [HTTPRequest.RESULT_SUCCESS, HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED]:
		var proxima := ""
		for cabecalho in cabecalhos:
			if cabecalho.to_lower().begins_with("location:"):
				proxima = cabecalho.substr(9).strip_edges()
		if proxima.begins_with("/") and not proxima.begins_with("//"):
			proxima = ORIGEM + proxima
		if _redirecionamentos >= 3 or not url_confiavel(proxima):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(arquivo))
			_falhar("o download redirecionou para uma origem não permitida")
			return
		_redirecionamentos += 1
		_requisitar_download(proxima, arquivo)
		return
	if resultado != HTTPRequest.RESULT_SUCCESS or codigo != 200:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(arquivo))
		_falhar("o download não terminou (%d/%d)" % [resultado, codigo])
		return
	var baixado := FileAccess.open(arquivo, FileAccess.READ)
	var tamanho := baixado.get_length() if baixado != null else -1
	if baixado != null:
		baixado.close()
	if tamanho != int(manifesto["bytes"]):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(arquivo))
		_falhar("o tamanho do arquivo baixado não confere com o site")
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


## O que o jogador lê quando a build nova passa dos limites do atualizador.
func _motivo_de_grande_demais(dados: Dictionary) -> String:
	if float(dados["bytes"]) > MAX_ZIP:
		return tr("A Build %d tem %s de download e a atualização automática aceita até %s. Baixe pelo site.") \
			% [int(dados["build"]), tamanho_legivel(int(dados["bytes"])), tamanho_legivel(MAX_ZIP)]
	return tr("A Build %d ocupa %s instalada e a atualização automática aceita até %s. Baixe pelo site.") \
		% [int(dados["build"]), tamanho_legivel(int(dados["extraido"])), tamanho_legivel(MAX_EXTRAIDO)]


## Há espaço para baixar o zip e extrair o jogo ao lado do executável? "" se sim; senão, o recado.
func _conferir_espaco() -> String:
	DirAccess.make_dir_recursive_absolute(PASTA_DOWNLOAD)
	var pasta_zip := ProjectSettings.globalize_path(PASTA_DOWNLOAD)
	var pasta_jogo := OS.get_executable_path().get_base_dir()
	var falta := espaco_que_falta(int(manifesto["bytes"]), extraido_estimado(manifesto),
		_espaco_livre(pasta_zip), _espaco_livre(pasta_jogo), mesmo_disco(pasta_zip, pasta_jogo))
	if falta.is_empty():
		return ""
	return tr("Falta espaço em disco para a Build %d: são precisos %s livres %s e há %s. Libere espaço ou baixe pelo site.") \
		% [build_nova(), tamanho_legivel(int(falta["precisa"])), tr(str(falta["onde"])), tamanho_legivel(int(falta["livre"]))]


## Bytes livres no disco da pasta; 0 quando o sistema não responde (e então não se barra ninguém).
static func _espaco_livre(pasta: String) -> int:
	var dir := DirAccess.open(pasta)
	return dir.get_space_left() if dir != null else 0


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


## A build do evento não se atualiza: o preset "Windows Tripothon" traz a feature.
static func edicao_estatica() -> bool:
	return forcar_estatica or OS.has_feature("tripothon")


static func _instalavel() -> bool:
	return OS.has_feature("template") and OS.get_name() == "Windows"


# ---------------------------------------------------------------------------
# A lógica pura, sem rede nem estado — é o que o portão (tests/atualizacao.gd) cobra.

## O manifesto tem o que a instalação precisa, e de onde se espera. Os tamanhos não são
## julgados aqui: manifesto de build gigante é um manifesto certo, e quem o recusa precisa
## dizer por quê (`grande_demais`). `extraido` (bytes do jogo instalado) é opcional.
static func manifesto_bem_formado(dados: Dictionary) -> bool:
	for campo in ["sha256", "url", "arquivo"]:
		if not dados.get(campo) is String:
			return false
	for campo in ["build", "bytes", "extraido"]:
		if campo == "extraido" and not dados.has(campo):
			continue
		if not (dados.get(campo) is int or dados.get(campo) is float):
			return false
		var numero := float(dados[campo])
		if not is_finite(numero) or numero <= 0 or numero != floor(numero):
			return false
	var sha: String = dados["sha256"]
	var arquivo: String = dados["arquivo"]
	return float(dados["build"]) < 1000000 \
		and url_confiavel(dados["url"]) and nome_seguro(arquivo) and not "/" in arquivo \
		and arquivo.ends_with(".zip") and sha.length() == 64 and sha.is_valid_hex_number()


## Bem formado e instalável: dentro dos limites de zip e de jogo extraído.
static func manifesto_valido(dados: Dictionary) -> bool:
	return manifesto_bem_formado(dados) and not grande_demais(dados)


## Bem formado, mas o zip (ou o jogo extraído, quando o manifesto o declara) passa dos limites.
static func grande_demais(dados: Dictionary) -> bool:
	return manifesto_bem_formado(dados) \
		and (float(dados["bytes"]) > MAX_ZIP or float(dados.get("extraido", 0)) > MAX_EXTRAIDO)


## O jogo instalado em bytes: o que o manifesto declara, ou 1,5x o zip (a Build 10 dá 1,27x).
static func extraido_estimado(dados: Dictionary) -> int:
	return int(dados["extraido"]) if dados.has("extraido") else int(float(dados["bytes"]) * 1.5)


## O que falta de espaço, ou {} se cabe. Baixar pede o zip mais a margem; extrair, o jogo
## mais a margem; no mesmo disco, tudo junto. `livre` 0 é "não sei" e não barra ninguém.
## Devolve {"precisa", "livre", "onde"}.
static func espaco_que_falta(bytes: int, extraido: int, livre_download: int, livre_instalacao: int, no_mesmo_disco: bool) -> Dictionary:
	if no_mesmo_disco:
		var livre := mini(livre_download, livre_instalacao) if livre_download > 0 and livre_instalacao > 0 else maxi(livre_download, livre_instalacao)
		var junto := bytes + extraido + MARGEM_DE_ESPACO
		return {"precisa": junto, "livre": livre, "onde": "no disco do jogo"} if livre > 0 and livre < junto else {}
	var para_baixar := bytes + MARGEM_DE_ESPACO
	if livre_download > 0 and livre_download < para_baixar:
		return {"precisa": para_baixar, "livre": livre_download, "onde": "na pasta de dados do jogo"}
	var para_extrair := extraido + MARGEM_DE_ESPACO
	if livre_instalacao > 0 and livre_instalacao < para_extrair:
		return {"precisa": para_extrair, "livre": livre_instalacao, "onde": "na pasta do jogo"}
	return {}


## As duas pastas estão na mesma unidade (C:, D:)? Caminho sem letra de unidade: não se sabe, false.
static func mesmo_disco(a: String, b: String) -> bool:
	return a.length() > 1 and b.length() > 1 and a[1] == ":" and b[1] == ":" and a[0].to_lower() == b[0].to_lower()


## "1.14 GB", "480 MB": o tamanho como o Explorer o conta (múltiplos de 1024).
static func tamanho_legivel(bytes: int) -> String:
	if bytes >= 1024 * 1024 * 1024:
		return "%.2f GB" % (bytes / 1073741824.0)
	return "%d MB" % int(ceil(bytes / 1048576.0))


static func url_confiavel(url: String) -> bool:
	if not url.begins_with(ORIGEM + "/") or "\\" in url:
		return false
	for c in url:
		if c.unicode_at(0) <= 32 or c.unicode_at(0) == 127:
			return false
	return true


static func nome_seguro(nome: String) -> bool:
	if nome.is_empty() or nome.length() > 180 or nome.begins_with("/") or "\\" in nome or ":" in nome:
		return false
	for c in nome:
		if c.unicode_at(0) < 32 or c.unicode_at(0) == 127:
			return false
	for parte in nome.trim_suffix("/").split("/"):
		if parte in ["", ".", ".."] or parte.ends_with(".") or parte.ends_with(" "):
			return false
		var base := parte.get_slice(".", 0).to_upper()
		if base in ["CON", "PRN", "AUX", "NUL", "CONIN$", "CONOUT$"] or (base.length() == 4 and (base.begins_with("COM") or base.begins_with("LPT")) and base.substr(3) in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "¹", "²", "³"]):
			return false
	return true


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
	# Antes de qualquer gravação, confira também cabeçalhos locais, tamanhos,
	# atributos e nomes alternativos que o tar poderia interpretar de outro modo.
	var falha := conferir_zip(zip)
	if not falha.is_empty():
		return falha
	var tar := OS.get_environment("SystemRoot").path_join("System32/tar.exe")
	if FileAccess.file_exists(tar):
		var saida: Array = []
		if OS.execute(tar, ["-xf", zip, "-C", destino], saida, true) == 0:
			return ""
		return "não foi possível extrair o pacote validado"
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


## O pacote desta distribuição contém um EXE e instruções, na raiz ou em
## MythsValley3D/. ZIP64, links e extras desconhecidos não fazem parte do formato.
static func conferir_zip(zip: String) -> String:
	var f := FileAccess.open(zip, FileAccess.READ)
	if f == null or f.get_length() < 22 or f.get_length() > MAX_ZIP:
		return "pacote inexistente ou grande demais"
	var comprimento := f.get_length()
	var inicio := maxi(0, comprimento - 65557)
	f.seek(inicio)
	var cauda := f.get_buffer(comprimento - inicio)
	var fim := -1
	for i in range(cauda.size() - 22, -1, -1):
		if cauda.decode_u32(i) == 0x06054b50 and i + 22 + cauda.decode_u16(i + 20) == cauda.size():
			fim = i
			break
	if fim < 0 or cauda.decode_u16(fim + 4) != 0 or cauda.decode_u16(fim + 6) != 0:
		return "índice ZIP inválido"
	var quantidade := cauda.decode_u16(fim + 10)
	var tamanho_indice := cauda.decode_u32(fim + 12)
	var indice := cauda.decode_u32(fim + 16)
	if quantidade < 1 or quantidade > MAX_ENTRADAS or quantidade != cauda.decode_u16(fim + 8) or tamanho_indice > 65536 or indice + tamanho_indice != inicio + fim:
		return "índice ZIP fora dos limites"
	var vistos := {}
	var total := 0
	var executaveis := 0
	var intervalos: Array[Vector2i] = []
	f.seek(indice)
	for _i in quantidade:
		var h := f.get_buffer(46)
		if h.size() != 46 or h.decode_u32(0) != 0x02014b50:
			return "entrada ZIP inválida"
		var flags := h.decode_u16(8)
		var metodo := h.decode_u16(10)
		var comprimido := h.decode_u32(20)
		var expandido := h.decode_u32(24)
		var tamanho_nome := h.decode_u16(28)
		var tamanho_extra := h.decode_u16(30)
		var tamanho_comentario := h.decode_u16(32)
		var atributos := h.decode_u32(38)
		var modo := (atributos >> 16) & 0xf000
		var local := h.decode_u32(42)
		if flags & 1 or metodo not in [0, 8] or h.decode_u16(34) != 0 or modo not in [0, 0x8000, 0x4000] or atributos & 0x400 or local >= indice or comprimido > MAX_ZIP or expandido > MAX_EXTRAIDO:
			return "pacote com link, criptografia ou tamanho inválido"
		var nome_bytes := f.get_buffer(tamanho_nome)
		var nome := nome_bytes.get_string_from_utf8()
		var extra := f.get_buffer(tamanho_extra)
		f.get_buffer(tamanho_comentario)
		var proxima := f.get_position()
		if nome.to_utf8_buffer() != nome_bytes or not nome_seguro(nome) or vistos.has(nome.to_lower()) or not _conteudo_permitido(nome) or not _extras_seguros(extra):
			return "pacote com nome ou conteúdo não permitido"
		vistos[nome.to_lower()] = true
		if nome.get_file() == "MythsValley3D.exe":
			executaveis += 1
		elif not nome.ends_with("/") and expandido > 1048576:
			return "instruções do pacote grandes demais"
		total += expandido
		if total > MAX_EXTRAIDO:
			return "pacote expandido grande demais"
		f.seek(local)
		var cabecalho := f.get_buffer(30)
		if cabecalho.size() != 30 or cabecalho.decode_u32(0) != 0x04034b50 or cabecalho.decode_u16(6) != flags or cabecalho.decode_u16(8) != metodo:
			return "cabeçalho local não confere"
		var nome_local := f.get_buffer(cabecalho.decode_u16(26))
		var extra_local := f.get_buffer(cabecalho.decode_u16(28))
		if nome_local != nome_bytes or not _extras_seguros(extra_local) or f.get_position() + comprimido > indice:
			return "caminho ou dados locais não conferem"
		if not flags & 8 and (cabecalho.decode_u32(18) != comprimido or cabecalho.decode_u32(22) != expandido):
			return "tamanhos locais não conferem"
		var fim_local := f.get_position() + comprimido
		if flags & 8:
			f.seek(fim_local)
			var descritor := f.get_buffer(16)
			if descritor.size() < 12:
				return "descritor ZIP incompleto"
			var deslocamento := 4 if descritor.decode_u32(0) == 0x08074b50 else 0
			if descritor.decode_u32(deslocamento) != h.decode_u32(16) or descritor.decode_u32(deslocamento + 4) != comprimido or descritor.decode_u32(deslocamento + 8) != expandido:
				return "descritor ZIP não confere"
			fim_local += 12 + deslocamento
		intervalos.append(Vector2i(local, fim_local))
		f.seek(proxima)
	if f.get_position() != indice + tamanho_indice or executaveis != 1:
		return "o pacote precisa conter um único MythsValley3D.exe"
	# O extrator não pode encontrar entradas locais omitidas do índice central,
	# nem interpretar dados sobrepostos como outro arquivo.
	intervalos.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	var coberto := 0
	for intervalo in intervalos:
		if intervalo.x != coberto or intervalo.y > indice:
			return "registros ZIP sobrepostos ou fora do índice"
		coberto = intervalo.y
	if coberto != indice:
		return "dados ZIP não declarados no índice"
	f.close()
	return ""


static func _conteudo_permitido(nome: String) -> bool:
	if nome == "MythsValley3D/":
		return true
	var relativo := nome.trim_prefix("MythsValley3D/")
	return relativo in ["MythsValley3D.exe", "README.txt", "README_WINDOWS.txt", "README.md", "LEIA-ME.txt"]


static func _extras_seguros(extra: PackedByteArray) -> bool:
	var i := 0
	while i < extra.size():
		if i + 4 > extra.size():
			return false
		var id := extra.decode_u16(i)
		var tamanho := extra.decode_u16(i + 2)
		# Só timestamps. Nomes Unicode alternativos e links Unix são recusados.
		if id not in [0x5455, 0x000a] or i + 4 + tamanho > extra.size():
			return false
		i += 4 + tamanho
	return true


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
	var pai := DirAccess.open(pasta.get_base_dir())
	if pai != null and pai.is_link(pasta.get_file()):
		DirAccess.remove_absolute(pasta)
		return
	if not DirAccess.dir_exists_absolute(pasta):
		return
	for arquivo in DirAccess.get_files_at(pasta):
		DirAccess.remove_absolute(pasta.path_join(arquivo))
	for sub in DirAccess.get_directories_at(pasta):
		_apagar_pasta(pasta.path_join(sub))
	DirAccess.remove_absolute(pasta)
