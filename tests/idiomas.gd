extends SceneTree
## Confere que TODO TEXTO QUE O JOGADOR LÊ EXISTE NOS TRÊS IDIOMAS.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/idiomas.gd
##
## A decisão é do autor, tomada em setembro de 2026: o jogo fala **pt-BR,
## inglês e espanhol**, e não só o menu. Até aqui o vale voltava ao português
## ao entrar, e dava para viver com isso porque não havia texto dentro dele.
## A migração acaba com essa folga — entram 146 KB de fala, missão e enredo do
## jogo 2D.
##
## E é por isso que este portão existe agora, e não depois: descobrir a falta
## com 63 passos de missão escritos é reescrever os 63. Todo passo tem de
## NASCER nos três.
##
## A forma é a que o projeto já usa: `campo`, `campo_en`, `campo_es` no mesmo
## objeto, e o `IdiomaMenu.sufixo()` escolhe. Ver `historico_3d.json`.
##
## Três perguntas:
##
##   1. TODO CAMPO TRADUZÍVEL DOS ARQUIVOS DECLARADOS TEM AS TRÊS VERSÕES, e
##      nenhuma vazia.
##   2. A TRADUÇÃO NÃO É A CÓPIA DO PORTUGUÊS. Campo `_en` igual ao `texto` é
##      o jeito mais comum de uma tradução faltar sem parecer que falta.
##   3. O QUE AINDA NÃO FOI TRADUZIDO ESTÁ DECLARADO, com a razão escrita. É
##      dívida registrada, não dívida esquecida.

var falhas := 0
## Entradas que declararam a tradução como pendente. Contadas e relatadas: o
## portão não reprova por elas, mas também não deixa que sumam da vista.
var _pendentes := 0

## ARQUIVO → campos que o jogador lê. Só o que está aqui é cobrado; o que
## falta traduzir mora em `FALTAM_TRADUCAO`, embaixo.
const TRADUZIDOS := {
	"res://data/galeria_personagens.json": ["voltar_catalogo", "indisponivel", "selecionar_peca"],
	"res://data/selecao_idioma.json": ["titulo", "descricao", "aviso"],
	"res://data/missoes_guia.json": ["texto", "resumo", "nome"],
	"res://data/historico_3d.json": ["titulo", "estado"],
	# A fé (#52): o que os marcos dizem.
	"res://data/marcos_fe.json": ["linhas", "texto", "convite", "resumo", "pratica"],
	# E as missões dela.
	"res://data/missoes_fe.json": ["texto", "resumo", "nome", "titulo", "resposta"],
	"res://data/missoes_fe_catolica.json": ["texto", "resumo", "nome", "titulo", "resposta"],
	"res://data/missoes_fe_candomble.json": ["texto", "resumo", "nome", "titulo", "resposta"],
	"res://data/missoes_fe_caboclo.json": ["texto", "resumo", "nome", "titulo", "resposta"],
	# A casa herdada (#50): a pergunta da cama e as falas do desmaio das duas.
	# O "titulo" fica de fora da cobrança, e não da tradução: "Cama" é a mesma
	# palavra em espanhol, e a regra da cópia reprovaria o certo.
	"res://data/casa.json": ["texto", "pergunta"],
	# E a lavoura (#8): o que a tecla diz no leito e os recados do gesto.
	"res://data/lavoura.json": ["texto"],
	# A missão do cemitério: os três passos do 2D declaram a pendência um a um,
	# e o mato, o conserto, o cercado e o arremate nasceram nos três idiomas.
	"res://data/missoes_coveiro.json": ["texto", "resumo", "nome", "titulo", "resposta"],
	# O saveiro do mestre Quirino: a cadeia do Seu Benedito que o ensina, e o que o
	# saveiro diz — a chegada, a encomenda da estação e a aba dele no painel.
	"res://data/missoes_saveiro.json": ["texto", "resumo", "nome", "titulo", "resposta"],
	"res://data/saveiro.json": ["chegou", "partiu", "encomenda_titulo", "encomenda_texto", "encomenda_linha", "agrado",
		"painel_titulo", "painel_linha", "painel_dica", "painel_rodape", "ja_levou", "nao_tem"],
}

## O QUE AINDA NÃO ESTÁ NOS TRÊS, e por quê. Esvaziar esta lista é o trabalho;
## deixá-la sem razão escrita é como ela vira lista de tudo.
const FALTAM_TRADUCAO := {
	"res://data/npcs_3d.json":
		"as 21 falas dos sete moradores mais as do Pedro. Cada uma tem 'texto' e 'tts', e o tts leva marcação de interpretação do eleven_v3 — traduzir os dois pede a voz de cada idioma, que é decisão de áudio e não de texto",
	"res://data/arvores_3d.json":
		"as fichas de árvore do painel; nome popular e nome científico, e o popular muda de região antes de mudar de língua",
	"res://data/lapides_3d.json":
		"os epitáfios do cemitério; são de 1887 e a forma importa mais que a letra",
	"res://data/dialogos/aldeoes.json":
		"os sete moradores vindos do 2D: apresentação, reação ao presente e fala por grau. É o que a Afinidade lê para saber de quem é cada gosto. TRADUÇÃO COM O RAMON — registro regional, 26 KB",
	"res://data/dialogos/pedro.json":
		"o tutorial inteiro do 2D, 27 passos com objetivo e arremate. TRADUÇÃO COM O RAMON — 32 KB, e é o maior bloco de prosa do projeto",
	"res://data/colecionaveis/cordeis.json":
		"os dez cordéis do 2D, com título, autor e versos. É poesia de feira em redondilha, e traduzir é recompor a rima. TRADUÇÃO COM O RAMON",
	"res://data/colecionaveis/sinais.json":
		"os sinais dos mitos do 2D: o que o jogador viu e, depois do encontro, de quem era. TRADUÇÃO COM O RAMON",
	"res://data/colecionaveis/bichos.json":
		"as páginas dos bichos do 2D: a ficha de quem brigou com eles, a morada e a meta. TRADUÇÃO COM O RAMON",
	"res://data/construcoes/obras.json":
		"as obras do 2D: nome, resumo e compartimento de cada uma, da varanda ao trapiche. TRADUÇÃO COM O RAMON",
	"res://data/cartas/cartas.json":
		"as cartas do 2D: nome, resumo, a prosa do encontro e o aviso da cobrança do pacto. TRADUÇÃO COM O RAMON",
	"res://data/pesca.json":
		"o que se lê pescando, do Mundo._pescar do 2D, mais a fisgada escrita no aviso. TRADUÇÃO COM O RAMON",
	"res://data/achados.json":
		"o que se lê ao achar cordel, sinal e carta, do Mundo do 2D, com a conversa e a pergunta do pacto. TRADUÇÃO COM O RAMON",
	"res://data/luta.json":
		"o aviso de quando o bicho cai, o de cansaço e as palavras que sobem na pancada ('escapou', 'tonto', 'veneno'), do Mundo do 2D. Palavra curta que em espanhol é igual ao português (veneno) reprovaria como cópia: é com o Ramon, que decide a forma. TRADUÇÃO COM O RAMON",
	"res://data/partida.json":
		"o aviso de quando a partida salva volta, que segue o do Mundo._retomar do 2D. TRADUÇÃO COM O RAMON",
	"res://data/dialogo.json":
		"o rodapé da caixa de fala longa (#21): continuar, seguir e as portas do Sim e do Não, verbatim do dialogo.gd do 2D. Os colchetes ficam no código, mas a letra da tecla está no texto ('[A] Sim'), e o A e o D são posição no teclado, não inicial de palavra: decidir isso em cada língua é com o Ramon. TRADUÇÃO COM O RAMON",
	"res://data/queda.json":
		"as três falas de quem cai e acorda em casa, verbatim do Mundo._ao_cair do 2D, e o lembrete do dia da fazenda no cartão do amanhecer. Curtas, mas no registro da roça ('o que faltou foi juízo'). TRADUÇÃO COM O RAMON",
}

const SUFIXOS := ["_en", "_es"]


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("IDIOMAS_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	var conferidos := 0

	_conferir(not TRADUZIDOS.is_empty(), "a lista de arquivos traduzidos está vazia")

	for caminho in TRADUZIDOS:
		var arquivo := FileAccess.open(caminho, FileAccess.READ)
		_conferir(arquivo != null, "não consegui ler %s" % caminho)
		if arquivo == null:
			continue
		var dado = JSON.parse_string(arquivo.get_as_text())
		arquivo.close()
		_conferir(dado != null, "%s não é JSON válido" % caminho)
		if dado == null:
			continue
		conferidos += _varrer(dado, TRADUZIDOS[caminho], caminho.get_file())

	_conferir(conferidos > 0, "não achei um só campo traduzível: a varredura não está pegando")

	# --- 3. A DÍVIDA ESTÁ DECLARADA ------------------------------------------
	for caminho in FALTAM_TRADUCAO:
		_conferir(FileAccess.file_exists(caminho),
			"'%s' está na lista do que falta traduzir e não existe mais: tire a linha" % caminho)
		_conferir(str(FALTAM_TRADUCAO[caminho]).length() > 20,
			"'%s' falta sem razão escrita" % caminho)
		_conferir(not TRADUZIDOS.has(caminho),
			"'%s' está nas duas listas ao mesmo tempo" % caminho)

	print("")
	if falhas == 0:
		print("IDIOMAS_OK: %d campo(s) nos três idiomas em %d arquivo(s); %d entrada(s) e %d arquivo(s) com tradução declarada como pendente"
			% [conferidos, TRADUZIDOS.size(), _pendentes, FALTAM_TRADUCAO.size()])
	else:
		print("idiomas: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


## Desce o JSON inteiro atrás dos campos pedidos, em qualquer profundidade —
## os arquivos deste projeto misturam lista de passo, objeto de arremate e
## entrada de histórico, e cobrar só o primeiro nível deixaria metade de fora.
func _varrer(no, campos: Array, onde: String) -> int:
	var achados := 0
	if typeof(no) == TYPE_ARRAY:
		for filho in no:
			achados += _varrer(filho, campos, onde)
		return achados
	if typeof(no) != TYPE_DICTIONARY:
		return 0

	# PENDÊNCIA DECLARADA POR ENTRADA.
	#
	# Decisão do autor (setembro de 2026): conteúdo novo nasce em português, e
	# as outras duas línguas ficam registradas como pendentes até o Ramon
	# traduzir. A declaração é por ENTRADA e não por arquivo, para que um
	# arquivo meio traduzido continue defendido no que já tem — se a pendência
	# fosse do arquivo inteiro, a primeira entrada nova desprotegeria as
	# outras cinco.
	if str(no.get("traducao", "")) == "pendente":
		_pendentes += 1
		return achados

	for campo in campos:
		if not no.has(campo):
			continue
		var base := str(no[campo])
		if base == "":
			continue
		achados += 1
		var quem := str(no.get("id", no.get("data", "?")))
		for sufixo in SUFIXOS:
			var traduzido := str(no.get(campo + sufixo, ""))
			_conferir(traduzido != "",
				"%s, '%s': falta o campo %s%s" % [onde, quem, campo, sufixo])
			if traduzido != "":
				_conferir(traduzido != base,
					"%s, '%s': %s%s é cópia do português — tradução faltando disfarçada de tradução"
						% [onde, quem, campo, sufixo])

	for chave in no:
		achados += _varrer(no[chave], campos, onde)
	return achados
