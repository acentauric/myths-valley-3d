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
	"res://data/apoios_vale.json": ["titulo", "ajuda", "fechar", "pronto", "usado", "vazio", "segundo_folego", "sucesso"],
	"res://data/navegacao_teia.json": ["ajuda"],
	"res://data/coleta_no_chao.json": ["texto"],
	"res://data/afinidade_interacao_3d.json": ["pergunta", "bom", "ruim", "qualquer", "ja_deu", "item_mudou"],
	"res://data/dialogos/afinidade_3d.json": ["texto"],
	"res://data/nome_jogador.json": ["titulo", "ajuda", "campo", "erro"],
	"res://data/galeria_personagens.json": ["indisponivel"],
	"res://data/selecao_idioma.json": ["titulo", "descricao", "aviso"],
	# A chegada (docs/mundo/CHEGADA_E_MUTIROES.md) nasceu nos três idiomas inteira:
	# título, resumo, fala, a resposta de quem o jogador procura e o arremate. E as
	# duas filas que ela abre, a roça do Cosme e a carroça do Seu Benedito, mais o
	# papel que o último passo manda ler.
	"res://data/missoes_guia.json": ["texto", "resumo", "nome", "titulo", "resposta"],
	"res://data/missoes_roca.json": ["texto", "resumo", "nome", "titulo", "resposta"],
	"res://data/missoes_carroca.json": ["texto", "resumo", "nome", "titulo", "resposta"],
	# As frentes do 2D que não pedem lugar novo: as armas e o ofício do Pedro, a
	# capoeira do Cosme e a meta dos caititus.
	"res://data/missoes_armas.json": ["texto", "resumo", "nome", "titulo", "resposta"],
	"res://data/missoes_oficio.json": ["texto", "resumo", "nome", "titulo", "resposta"],
	"res://data/missoes_capoeira.json": ["texto", "resumo", "nome", "titulo", "resposta"],
	"res://data/missoes_metas.json": ["texto", "resumo", "nome", "titulo", "resposta"],
	"res://data/missoes_ponte.json": ["texto", "resumo", "nome", "titulo", "resposta"],
	"res://data/missoes_chapada.json": ["texto", "resumo", "nome", "titulo", "resposta"],
	"res://data/missoes_lombada.json": ["texto", "resumo", "nome", "titulo", "resposta"],
	"res://data/missoes_fazenda.json": ["texto", "resumo", "nome", "titulo", "resposta"],
	"res://data/documentos.json": ["nome", "linhas"],
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
	# O nome de cada casa por dentro, o que o HUD diz ao entrar (`interiores.gd`).
	"res://data/interiores_casas.json": ["nome"],
	# E a lavoura (#8): o que a tecla diz no leito e os recados do gesto.
	"res://data/lavoura.json": ["texto"],
	# A missão do cemitério: os três passos do 2D declaram a pendência um a um,
	# e o mato, o conserto, o cercado e o arremate nasceram nos três idiomas.
	"res://data/missoes_coveiro.json": ["texto", "resumo", "nome", "titulo", "resposta"],
	# As cadeias antigas também entram na varredura: uma entrada pendente
	# continua declarada, sem desproteger o que já está traduzido no arquivo.
	"res://data/missoes_arraial.json": ["texto", "resumo", "nome", "titulo", "resposta", "trancada"],
	"res://data/missoes_candinha.json": ["texto", "resumo", "nome", "titulo", "resposta", "trancada"],
	"res://data/missoes_filo.json": ["texto", "resumo", "nome", "titulo", "resposta", "trancada"],
	"res://data/missoes_tonho.json": ["texto", "resumo", "nome", "titulo", "resposta", "trancada"],
	"res://data/missoes_zefa.json": ["texto", "resumo", "nome", "titulo", "resposta", "trancada"],
	"res://data/recursos_3d.json": ["nome"],
	# O saveiro do mestre Quirino: a cadeia do Seu Benedito que o ensina, e o que o
	# saveiro diz — a chegada, a encomenda da estação e a aba dele no painel.
	"res://data/missoes_saveiro.json": ["texto", "resumo", "nome", "titulo", "resposta"],
	"res://data/saveiro.json": ["chegou", "partiu", "encomenda_titulo", "encomenda_texto", "encomenda_linha", "agrado",
		"painel_titulo", "painel_linha", "painel_dica", "painel_rodape", "ja_levou", "nao_tem"],
	# O que a dica do E diz em cima do poço, da ponte, do mirante, do cemitério e da
	# carroça (tecla_das_bancadas.gd).
	"res://data/dicas_do_e_nas_obras.json": ["rotulo"],
	# O aviso da mochila cheia: o que o morador fica devendo e o que entrou depois
	# (cadeia_de_missoes.gd, `_dar`).
	"res://data/entregas_pendentes.json": ["texto"],
	# As falas dos moradores e do Pedro (saudações, conversa, as de noite, as de depois do tutorial e o aviso do
	# entardecer): TODAS nos quatro idiomas do menu — o chinês também (`TAMBEM_EM_CHINES`). A voz é só em
	# português; quem cobra o chinês de verdade (ideogramas, nunca cópia) e a voz é tests/vozes_dos_moradores.gd.
	"res://data/npcs_3d.json": ["texto"],
	# Os sustos da mata: o aviso de quando o mapa enlouquece, o de quando o norte volta e o do sinal anotado.
	"res://data/sustos.json": ["texto"],
}

## Os arquivos que também nascem em chinês (`campo_zh`): o jogo tem quatro idiomas no menu, e o chinês cai no
## inglês onde falta. Aqui só entra o que já nasceu inteiro nos quatro; o resto segue em `_en` e `_es`.
const TAMBEM_EM_CHINES := ["res://data/npcs_3d.json", "res://data/sustos.json"]

## O QUE AINDA NÃO ESTÁ NOS TRÊS, e por quê. Esvaziar esta lista é o trabalho;
## deixá-la sem razão escrita é como ela vira lista de tudo.
const FALTAM_TRADUCAO := {
	# Divida de interfaces identificada por fonte, sem fingir traducao integral.
	"res://scripts/prototipo_3d/painel_vale.gd": "#51/#6: textos compostos desta interface ainda precisam sair do GDScript para JSON pt/en/es; a escolha de idioma persiste e o texto sem traducao usa o original",
	"res://scripts/prototipo_3d/prototype_hud.gd": "#51/#6: textos compostos desta interface ainda precisam sair do GDScript para JSON pt/en/es; a escolha de idioma persiste e o texto sem traducao usa o original",
	"res://scripts/prototipo_3d/barra_de_mao.gd": "#51/#6: textos compostos desta interface ainda precisam sair do GDScript para JSON pt/en/es; a escolha de idioma persiste e o texto sem traducao usa o original",
	"res://scripts/prototipo_3d/dialogo_vale.gd": "#51/#6: textos compostos desta interface ainda precisam sair do GDScript para JSON pt/en/es; a escolha de idioma persiste e o texto sem traducao usa o original",
	"res://scripts/prototipo_3d/mapa_jogo.gd": "#51/#6: textos compostos desta interface ainda precisam sair do GDScript para JSON pt/en/es; a escolha de idioma persiste e o texto sem traducao usa o original",
	"res://scripts/prototipo_3d/minimapa.gd": "#51/#6: textos compostos desta interface ainda precisam sair do GDScript para JSON pt/en/es; a escolha de idioma persiste e o texto sem traducao usa o original",
	"res://scripts/prototipo_3d/teia_social.gd": "#51/#6: textos compostos desta interface ainda precisam sair do GDScript para JSON pt/en/es; a escolha de idioma persiste e o texto sem traducao usa o original",
	"res://scripts/prototipo_3d/teia_talentos.gd": "#51/#6: textos compostos desta interface ainda precisam sair do GDScript para JSON pt/en/es; a escolha de idioma persiste e o texto sem traducao usa o original",
	"res://scripts/prototipo_3d/painel_personagens.gd": "#51/#6: textos compostos desta interface ainda precisam sair do GDScript para JSON pt/en/es; a escolha de idioma persiste e o texto sem traducao usa o original",
	"res://scripts/prototipo_3d/painel_ajustes.gd": "#51/#6: textos compostos desta interface ainda precisam sair do GDScript para JSON pt/en/es; a escolha de idioma persiste e o texto sem traducao usa o original",
	"res://scripts/prototipo_3d/popups_do_mundo.gd": "#51/#6: textos compostos desta interface ainda precisam sair do GDScript para JSON pt/en/es; a escolha de idioma persiste e o texto sem traducao usa o original",
	"res://scripts/prototipo_3d/dica_tecla.gd": "#51/#6: textos compostos desta interface ainda precisam sair do GDScript para JSON pt/en/es; a escolha de idioma persiste e o texto sem traducao usa o original",
	"res://scripts/ui/mochila.gd": "#51/#6: rotulos e descricoes compostos da mochila ainda aguardam catalogo JSON pt/en/es; texto original permanece como fallback",
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
## Os sufixos cobrados no arquivo que está sendo varrido (`SUFIXOS`, mais "_zh" em `TAMBEM_EM_CHINES`).
var _sufixos: Array = SUFIXOS


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
	# Não deixar cadeias novas invisíveis ao portão (#47).
	for nome in DirAccess.get_files_at("res://data"):
		if not nome.begins_with("missoes_") or not nome.ends_with(".json"):
			continue
		var caminho := "res://data/" + nome
		_conferir(TRADUZIDOS.has(caminho) or FALTAM_TRADUCAO.has(caminho),
			"a cadeia '%s' não declara cobertura nem pendência" % nome)
		if TRADUZIDOS.has(caminho):
			_conferir("titulo" in TRADUZIDOS[caminho], "a cadeia '%s' não cobra titulo" % nome)
	_conferir(TRADUZIDOS.has("res://data/recursos_3d.json") or FALTAM_TRADUCAO.has("res://data/recursos_3d.json"),
		"os recursos não declaram cobertura nem pendência")

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
		# Falsificação reproduzível sem alterar o arquivo do jogador.
		if caminho == "res://data/missoes_guia.json" and "--falsificar-titulo" in OS.get_cmdline_user_args():
			dado.passos[0].erase("titulo_en")
		_sufixos = SUFIXOS + ["_zh"] if TAMBEM_EM_CHINES.has(caminho) else SUFIXOS
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
		for sufixo in _sufixos:
			var traduzido := str(no.get(campo + sufixo, ""))
			_conferir(traduzido != "",
				"%s, '%s': falta o campo %s%s" % [onde, quem, campo, sufixo])
			if traduzido != "":
				_conferir(traduzido != base or _cognato_revisado(onde, quem, campo, sufixo, base),
					"%s, '%s': %s%s é cópia do português — tradução faltando disfarçada de tradução"
						% [onde, quem, campo, sufixo])

	for chave in no:
		achados += _varrer(no[chave], campos, onde)
	return achados


## Exceção estreita: "Tronco caído" tem a mesma grafia em português e espanhol.
## Não libera cópias de outros campos, recursos ou idiomas.
func _cognato_revisado(onde: String, quem: String, campo: String, sufixo: String, base: String) -> bool:
	return onde == "recursos_3d.json" and campo == "nome" and sufixo == "_es" and base == "Tronco caído" and quem in [
		"lenha_rocado_a", "lenha_rocado_b", "galhada_cemiterio_a", "galhada_cemiterio_b", "galhada_cemiterio_c"]
