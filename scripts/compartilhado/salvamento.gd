extends Node
## SALVAR E CARREGAR a partida.
##
## Até aqui o jogo não guardava nada de uma partida. Havia só o
## `admin_config.json`, com nomes e valores de ajuste — e fechar o jogo apagava
## o roçado, a mochila, as missões, os talentos, a fé, as obras, a terra
## comprada e a coleção.
##
## Isso é mais grave do que parece de dentro do desenvolvimento, onde se joga
## vinte minutos por vez. O laço deste gênero é O DIA QUE TERMINA E O SEGUINTE
## QUE COMEÇA, e o nosso relógio já tem essa parede: o contador de dias só
## avança quando o jogador dorme. Sem persistência a parede não leva a lugar
## nenhum. A carência de nove dias da mangueira, as vinte tábuas do mirante, a
## árvore de talentos, a migração de fé — nada disso pode ser sentido por quem
## recomeça do zero a cada sessão.
##
##
## COMO É GUARDADO
##
## Um arquivo só, `user://partida.save`, com uma seção por sistema e um número
## de versão no alto. Um e não doze: save espalhado por arquivo quebra pela
## metade, e metade de um save é pior que save nenhum, porque o jogador só
## descobre o estrago depois de ter jogado em cima.
##
## O formato é o de variante do Godot (`var_to_str`), e não JSON. JSON seria
## mais bonito de ler e perderia informação no caminho: metade do estado deste
## jogo é indexada por `Vector2i` — o roçado, os recursos rachados, as peças
## assentadas —, e JSON não tem chave que não seja texto. Converter ida e volta
## é trabalho e é lugar de erro. A variante guarda `Vector2i`, `Color` e
## dicionário aninhado sem perder nada, e o arquivo continua sendo texto que se
## abre num editor.
##
##
## A TABELA, E POR QUE ELA É DECLARATIVA
##
## `O_QUE_GUARDAR` diz, num lugar só, qual campo de qual sistema entra no save.
## A alternativa seria cada autoload ter o seu `estado()` e `restaurar()`, o
## que é mais arrumado no papel e pior na prática: são doze sistemas, e o
## defeito clássico desta mecânica é alguém acrescentar um campo e esquecer de
## pôr no save. Espalhado por doze arquivos, ninguém percebe. Numa tabela de
## trinta linhas, a falta se vê.
##
## E o portão é o que de fato garante: `testar_salvamento.gd` salva, recarrega
## e compara campo a campo.
##
##
## O QUE NÃO ENTRA, E POR QUÊ
##
## O MAPA não é salvo. Ele é gerado por semente e a semente é fixa, então o
## terreno, a mata e o relevo saem iguais toda vez. O que se guarda é o DIFF:
## a árvore que o jogador derrubou, a pedra que rachou, o móvel que mudou de
## lugar, a construção que assentou. Guardar as trinta mil células seria
## guardar o que já sabemos calcular.
##
## O TALENTO DESTRAVADO é salvo como lista, e o efeito dele NÃO é reaplicado ao
## carregar. O ganho já está dentro da `Progressao`, que é salva junto — mandar
## `_aplicar` rodar de novo dobraria o fôlego máximo de quem tem "Pé no chão", e
## dobraria outra vez no carregamento seguinte. Mesma regra para as obras.

## AS VAGAS DE SALVAMENTO.
##
## O jogo tinha UMA partida — um arquivo, e pronto. Quem quisesse começar outra
## passava por cima da que tinha, e não havia como voltar. Isso basta enquanto
## o jogo dura vinte minutos; deixa de bastar no dia em que alguém quer ver
## como seria com outra fé, ou emprestar o jogo, ou guardar a partida de antes
## de uma decisão para poder voltar nela.
##
## TRÊS, e não dez. Três cabe numa tela sem rolagem, cobre os casos que
## existem (a partida séria, a experiência, a de outra pessoa da casa) e não
## transforma escolher a vaga numa decisão. Vaga demais vira gaveta: o jogador
## espalha as partidas e não sabe mais qual é qual.
const QUANTOS_SLOTS := 3

## Nenhuma vaga escolhida ainda. É o estado do jogo no menu inicial, antes de
## o jogador dizer em qual partida quer entrar.
const SEM_VAGA := 0

## O ARQUIVO DE ANTES DAS VAGAS. Ver `_mudar_de_casa`.
const ARQUIVO_DE_UMA_VAGA_SO := "user://partida.save"

## Em que vaga a partida em curso mora. Quem escolhe é o menu (ao abrir ou ao
## começar) e a tela de vagas (ao salvar). NÃO é salvo dentro do arquivo: a
## vaga é onde o arquivo está, e guardá-la dentro dele seria guardar duas
## verdades que podem discordar.
var slot_atual: int = SEM_VAGA


func arquivo(slot: int = 0) -> String:
	return "user://partida_%d.save" % _qual(slot)


## O save de antes do último, por vaga. Ver `salvar`.
func anterior(slot: int = 0) -> String:
	return "user://partida_%d.save.bak" % _qual(slot)


## Onde o save é escrito antes de virar o oficial. Ver `salvar`.
func rascunho(slot: int = 0) -> String:
	return "user://partida_%d.save.tmp" % _qual(slot)


## Zero quer dizer "a vaga em curso". É o que deixa o resto do jogo continuar
## chamando `salvar()` e `ler()` sem saber que vagas existem.
func _qual(slot: int) -> int:
	return slot if slot > 0 else slot_atual

## A VERSÃO DO FORMATO, e ela SOBE — não é decoração.
##
## A regra antiga era recusar save de versão diferente. Isso protege contra
## carregar pela metade e custa caro demais: quem jogou trinta horas e atualiza
## o jogo perde tudo, e "recusado" é a mesma coisa que "quebrou" para quem está
## do outro lado. Agora save velho é MIGRADO. Ver `MIGRACOES`.
const VERSAO := 2

## DE QUAL VERSÃO PARA A SEGUINTE, e o método que faz a passagem.
##
## A migração é uma ESCADA: um save da versão 1 num jogo na versão 5 sobe
## 1→2→3→4→5, um degrau por vez. Cada método só precisa saber a passagem dele,
## e nenhum precisa conhecer o formato de três versões atrás — que é o que
## torna isto sustentável depois de vinte atualizações.
##
## Mudança ADITIVA não precisa de degrau nenhum: campo novo que falta no save
## velho é simplesmente pulado ao carregar, e campo velho que não existe mais
## é ignorado. Só precisa de método aqui quem RENOMEIA, MUDA O SENTIDO ou
## REORGANIZA um campo — porque aí o valor antigo está lá e está errado, que é
## pior do que faltar.
##
##   1 → 2  A entrada do `Povoado` (perícia dos moradores). Foi aditiva, e o
##          método é quase vazio de propósito: ele está aqui para o portão
##          poder cobrar que TODA versão anterior tem degrau, e para o dia em
##          que a passagem 1→2 precisar de fato mexer em alguma coisa.
const MIGRACOES := {
	1: "_de_1_para_2",
}

signal salvou
signal carregou
## O que a última leitura teve de consertar: versão migrada, referência morta
## descartada, valor fora de faixa. A tela do menu mostra isto — conserto
## silencioso é conserto que ninguém confere.
signal remendou(relato: Array)

## O relato do último carregamento, para quem perguntar depois do sinal.
var ultimo_relato: Array = []


## Campo por campo, o que entra no save.
##
## A ordem aqui é a ordem do arquivo, e ela é a de dependência: quem restaura
## `Energia` precisa da `Progressao` já posta, porque o teto de fôlego vem dela.
const O_QUE_GUARDAR := {
	"Jogo": ["nome_jogador", "npc_1_nome", "npc_1_nome_completo", "dinheiro"],
	"Relogio": ["minutos", "dia", "estacao", "ano"],
	"Progressao": ["energia_maxima", "recuperacao_ao_dormir",
		"recuperacao_ao_desmaiar", "eficiencia", "nivel_de_ferramenta", "vida_maxima"],
	"Energia": ["atual"],
	"Vida": ["atual", "veneno_por", "veneno_ritmo"],
	"Inventario": ["espacos", "selecionado"],
	"Equipamento": ["vestido"],
	"Talentos": ["nivel", "xp", "pontos", "destravados"],
	"Obras": ["feitas"],
	"Terras": ["posses"],
	"Terrenos": ["trabalho", "divida_do_tonho", "tonho_com_rede"],
	"Povoado": ["pericia", "sobra"],
	"Colecao": ["achados"],
	"Efeitos": ["ativos"],
	"Missoes": ["ativas", "em_foco", "cumpridas"],
	# O QUE O JOGADOR SABE FAZER, e ele é permanente de um jeito que as missões
	# não são: `Missoes.limpar()` apaga as cumpridas no fim do tutorial, e uma
	# receita aprendida ali não pode desaprender com elas. Ver Receitas.
	"Receitas": ["aprendidas"],
	# O DIA DA FAZENDA, e é o estado inteiro dos capítulos 6 e 7: um número.
	# Fechar o jogo na véspera da jornada e abrir de novo tem que devolver a
	# véspera, e não o dia em que o Pedro bate na porta. Ver Jornada.
	"Jornada": ["dia"],
	# O que o jogador aprendeu a fazer na luta: o golpe forte do Pedro e a
	# capoeira do Cosme. Ver Luta.
	"Luta": ["aprendidos", "abates"],
}

## OS QUE SÃO SALVOS À MÃO, com o campo que cada um entrega no `estado()`.
##
## Estão aqui, e não só no código de `_guardar_especiais`, para o portão do
## salvamento poder cobrar a cobertura deles também. Sem esta lista, um campo
## público novo no `Afinidade` ou no `Cartas` escaparia da conferência — eles
## não passam pela tabela declarativa, e o teste só sabia varrer a tabela.
##
## `estado` é o que a função devolve; `dispensa` são os campos públicos que
## legitimamente não entram (espelho, estado de tela), com a razão no teste.
const SALVOS_A_MAO := {
	"Fe": ["ativa", "_estados"],
	"Terrenos": ["_meus"],
	"Afinidade": ["pontos", "_falou_no_dia", "_deu_no_dia"],
	"Cartas": ["pacto", "sabidas", "_usadas", "_pacto_desde", "_pago_hoje"],
}

## Os que têm campo privado ou exigem cuidado na volta, e por isso são tratados
## à mão em `_guardar_especiais` / `_restaurar_especiais`.
##
##   Fe        o estado das três fés mora num privado, e restaurar precisa
##             espelhar para os campos que a tela lê.
##   Terrenos  a terra comprada mora num privado.
##   o mundo   não é autoload: quem entrega o estado dele é a cena, quando
##             existe. Ver `Mundo.estado_para_salvar`.
var _mundo: Node = null


func _ready() -> void:
	_mudar_de_casa()


## A PARTIDA DE ANTES DAS VAGAS MUDA PARA A VAGA 1.
##
## Quem já jogava tem um `user://partida.save` no disco, escrito quando havia
## um lugar só. Com as vagas, esse arquivo deixa de ser procurado — e uma
## partida que existe e que o jogo não acha é exatamente o que "o save não pode
## quebrar com atualização" existe para impedir. Vale tanto quanto a migração
## de formato: lá o arquivo mudou de FORMA, aqui ele mudou de NOME.
##
## Só mexe com a vaga 1 VAZIA. Se já há partida nova ali, o arquivo velho fica
## onde está — perder a nova para salvar a velha seria trocar um estrago por
## outro, e ninguém pediu isso. O arquivo continua no disco para quem quiser
## recuperá-lo à mão.
func _mudar_de_casa() -> void:
	if not FileAccess.file_exists(ARQUIVO_DE_UMA_VAGA_SO):
		return
	if FileAccess.file_exists(arquivo(1)):
		push_warning("Salvamento: há um %s de antes das vagas, e a vaga 1 já está ocupada. Ele ficou onde está."
			% ARQUIVO_DE_UMA_VAGA_SO)
		return
	if DirAccess.rename_absolute(ARQUIVO_DE_UMA_VAGA_SO, arquivo(1)) == OK:
		print("Salvamento: a partida de antes das vagas passou para a vaga 1.")
	# A cópia de segurança vai junto, quando existe: ela é a rede de quem
	# tomar uma migração ruim, e deixá-la para trás tiraria a rede.
	if FileAccess.file_exists(ARQUIVO_DE_UMA_VAGA_SO + ".bak"):
		DirAccess.rename_absolute(ARQUIVO_DE_UMA_VAGA_SO + ".bak", anterior(1))


## A cena do mundo se apresenta ao nascer. Sem isso o save não teria como
## alcançar o roçado, que não é autoload.
func registrar_mundo(mundo: Node) -> void:
	_mundo = mundo


func existe_partida(slot: int = 0) -> bool:
	return FileAccess.file_exists(arquivo(slot))


## HÁ ALGUMA PARTIDA, em qualquer vaga? É o que o menu pergunta para decidir
## se mostra o botão de continuar.
func ha_alguma_partida() -> bool:
	for slot in range(1, QUANTOS_SLOTS + 1):
		if existe_partida(slot):
			return true
	return false


## O QUE HÁ NUMA VAGA, sem carregar nada.
##
## É o que a tela de vagas e o menu desenham: de quem é a partida, em que dia
## ela parou, e quando foi guardada no relógio de parede. Lê só o cabeçalho do
## arquivo — chamar isto do menu não pode mexer no estado de sistema nenhum,
## porque o menu existe antes de haver partida.
##
## O resultado é GUARDADO EM CACHE porque a tela pergunta a cada repintura, e
## ler três arquivos do disco a sessenta quadros por segundo seria absurdo. A
## chave é o tamanho mais a data: salvou de novo, muda; não salvou, não muda.
var _resumos: Dictionary = {}

func resumo(slot: int) -> Dictionary:
	var caminho := arquivo(slot)
	if not FileAccess.file_exists(caminho):
		_resumos.erase(slot)
		return {"existe": false}

	var aberto := FileAccess.open(caminho, FileAccess.READ)
	var assinatura := "%d/%d" % [FileAccess.get_modified_time(caminho),
		aberto.get_length() if aberto != null else 0]
	if aberto != null:
		aberto.close()
	var guardado: Dictionary = _resumos.get(slot, {})
	if str(guardado.get("assinatura", "")) == assinatura:
		return guardado

	var tudo := _ler_arquivo(caminho)
	var relogio: Dictionary = tudo.get("Relogio", {})
	var dia := int(relogio.get("dia", 0))
	# A mesma conta do `Relogio.dia_absoluto`, feita aqui porque o `Relogio` em
	# memória é o da partida em curso — que no menu é nenhuma.
	var absoluto := 0
	if dia > 0:
		var estacoes := (int(relogio.get("ano", 1)) - 1) * 4 + int(relogio.get("estacao", 0))
		absoluto = estacoes * Relogio.DIAS_POR_ESTACAO + dia
	var dele := {
		"existe": not tudo.is_empty(),
		"assinatura": assinatura,
		"dia": absoluto,
		"nome": str(tudo.get("Jogo", {}).get("nome_jogador", Jogo.NOME_PADRAO)),
		"quando": str(tudo.get("quando", "")),
		"jogo": str(tudo.get("jogo", "")),
	}
	_resumos[slot] = dele
	return dele


## O dia da vaga em curso, para o painel dizer há quanto tempo não se salva.
func dia_do_save() -> int:
	return int(resumo(_qual(0)).get("dia", 0))


## Guarda tudo. Devolve false e explica no log se não deu — nunca levanta erro:
## falhar ao salvar não pode derrubar o jogo em cima do jogador.
func salvar(slot: int = 0) -> bool:
	var onde := _qual(slot)
	if onde <= 0:
		push_error("Salvamento: pediram para salvar sem vaga escolhida")
		return false
	var arquivo_da_vaga := arquivo(onde)
	var tudo: Dictionary = {
		"versao": VERSAO,
		"quando": Time.get_datetime_string_from_system(),
		# A VERSÃO DO JOGO que escreveu, junto do número da build.
		#
		# Não é usada para carregar — quem manda nisso é `versao`, que é do
		# formato. Está aqui para quando alguém aparecer com um save estranho:
		# saber em que build ele nasceu é a diferença entre consertar e
		# adivinhar. Custa duas linhas e uma vez só vai valer a partida de
		# alguém.
		"jogo": Versao.VERSAO_ATUAL,
		"build": Versao.BUILD_NUMERO,
	}
	for nome in O_QUE_GUARDAR:
		var sistema := get_node_or_null("/root/" + str(nome))
		if sistema == null:
			push_warning("Salvamento: não achei o autoload %s" % nome)
			continue
		var secao: Dictionary = {}
		for campo in O_QUE_GUARDAR[nome]:
			secao[str(campo)] = sistema.get(str(campo))
		tudo[str(nome)] = secao
	_guardar_especiais(tudo)

	# ESCREVE NUM RASCUNHO E SÓ DEPOIS TROCA. Nunca por cima do save bom.
	#
	# `store_string` direto no arquivo oficial tem uma janela de meio segundo
	# em que o save está truncado. Um travamento, uma queda de energia ou um
	# Alt+F4 ali dentro e a partida acabou — e acabou do pior jeito, com um
	# arquivo que EXISTE e não carrega, que é o que faz o jogador achar que o
	# problema é dele.
	#
	# Com rascunho, o pior caso é perder o salvamento daquele minuto: o
	# arquivo oficial nem foi tocado.
	var arquivo := FileAccess.open(rascunho(onde), FileAccess.WRITE)
	if arquivo == null:
		push_error("Salvamento: não consegui abrir %s para escrever (%d)"
			% [rascunho(onde), FileAccess.get_open_error()])
		return false
	arquivo.store_string(var_to_str(tudo))
	arquivo.close()

	# O rascunho é LIDO DE VOLTA antes de virar oficial.
	#
	# Disco cheio não levanta erro no `store_string`: ele escreve o que couber
	# e cala. Sem esta conferência, o save incompleto tomaria o lugar do bom
	# com a bênção do jogo.
	var conferencia := FileAccess.open(rascunho(onde), FileAccess.READ)
	var voltou = decodificar_dados(conferencia.get_as_text()) if conferencia != null else null
	if conferencia != null:
		conferencia.close()
	if not (voltou is Dictionary) or int((voltou as Dictionary).get("versao", 0)) != VERSAO:
		push_error("Salvamento: o rascunho não voltou inteiro; a partida anterior fica onde está")
		DirAccess.remove_absolute(rascunho(onde))
		return false

	# O SAVE DE ANTES VIRA CÓPIA, e é a última rede: se uma migração futura
	# estragar a partida, o arquivo de ontem ainda está no disco. Uma geração
	# só — guardar dez encheria o disco de quem joga todo dia e não salvaria
	# ninguém que as duas não salvem.
	if FileAccess.file_exists(arquivo_da_vaga):
		DirAccess.remove_absolute(anterior(onde))
		DirAccess.rename_absolute(arquivo_da_vaga, anterior(onde))
	DirAccess.rename_absolute(rascunho(onde), arquivo_da_vaga)
	_resumos.erase(onde)
	salvou.emit()
	return true


## Lê o arquivo. Devolve {} quando não há partida ou quando ela é de outra
## versão — e neste caso NÃO apaga nada: o arquivo velho fica onde está, porque
## quem for escrever a migração vai precisar dele.
func ler(slot: int = 0) -> Dictionary:
	var onde := _qual(slot)
	ultimo_relato = []
	var tudo := _ler_arquivo(arquivo(onde))

	# O ARQUIVO BOM NÃO ABRIU: tenta o de ontem antes de dar a partida por
	# perdida. É para isto que a cópia existe, e é o único momento em que ela
	# vale alguma coisa.
	if tudo.is_empty() and FileAccess.file_exists(anterior(onde)):
		tudo = _ler_arquivo(anterior(onde))
		if not tudo.is_empty():
			ultimo_relato.append("O save principal não abriu; foi carregada a cópia anterior.")

	if tudo.is_empty():
		return {}

	var de := int(tudo.get("versao", 0))
	if de > VERSAO:
		# SAVE DO FUTURO: o jogador voltou para uma versão mais velha do jogo.
		# Aqui a recusa é a resposta certa, e é a única — não há como adivinhar
		# um formato que ainda não existe, e tentar carregaria pela metade.
		# Recusar deixa o arquivo intacto para quando ele atualizar de volta.
		push_warning("Salvamento: partida da versão %d, o jogo está na %d — é de uma versão mais nova" % [de, VERSAO])
		ultimo_relato.append(
			"Esta partida é de uma versão mais nova do jogo (formato %d, este jogo lê até %d). Atualize o jogo para continuá-la — o arquivo não foi tocado." % [de, VERSAO])
		remendou.emit(ultimo_relato)
		return {}

	if de < VERSAO:
		tudo = _migrar(tudo, de)
		if tudo.is_empty():
			return {}

	return tudo


## Lê e desserializa um arquivo. {} quando não dá — e NUNCA apaga nada: quem
## for consertar uma partida quebrada vai precisar do arquivo como ele está.
func _ler_arquivo(caminho: String) -> Dictionary:
	if not FileAccess.file_exists(caminho):
		return {}
	var arquivo := FileAccess.open(caminho, FileAccess.READ)
	if arquivo == null:
		push_error("Salvamento: não consegui abrir %s para ler" % caminho)
		return {}
	if arquivo.get_length() > 16 * 1024 * 1024:
		arquivo.close()
		push_warning("Salvamento: arquivo grande demais; a partida permanece intacta")
		return {}
	var bruto := arquivo.get_as_text()
	arquivo.close()
	var tudo = decodificar_dados(bruto)
	if not (tudo is Dictionary):
		push_warning("Salvamento: %s não tem forma de partida segura" % caminho)
		return {}
	return tudo


## Mantém o formato e os tipos dos saves existentes, mas impede que o parser
## instancie Object/Resource ou carregue scripts. A verificação ocorre ANTES da
## desserialização, inclusive quando o menu só pede o resumo de uma vaga.
static func decodificar_dados(texto: String) -> Variant:
	if texto.length() > 16 * 1024 * 1024 or not texto_de_save_seguro(texto):
		return null
	return str_to_var(texto)


static func texto_de_save_seguro(texto: String) -> bool:
	const TIPOS := ["null", "true", "false", "inf", "inf_neg", "nan", "bool", "int", "float", "String", "StringName", "Vector2", "Vector2i", "Vector3", "Vector3i", "Vector4", "Vector4i", "Rect2", "Rect2i", "Transform2D", "Plane", "Quaternion", "AABB", "Basis", "Transform3D", "Projection", "Color", "NodePath", "Array", "Dictionary", "PackedByteArray", "PackedInt32Array", "PackedInt64Array", "PackedFloat32Array", "PackedFloat64Array", "PackedStringArray", "PackedVector2Array", "PackedVector3Array", "PackedVector4Array", "PackedColorArray"]
	var i := 0
	while i < texto.length():
		var c := texto.unicode_at(i)
		if c == 34: # String entre aspas, incluindo escapes: não é código.
			i += 1
			var fechou := false
			while i < texto.length():
				if texto.unicode_at(i) == 92:
					i += 2
					continue
				if texto.unicode_at(i) == 34:
					fechou = true
					i += 1
					break
				i += 1
			if not fechou:
				return false
			continue
		if c == 35: # O parser aceita cores #hex; nossos saves usam Color(...).
			return false
		if c == 59: # Comentário de variante, até o fim da linha.
			while i < texto.length() and texto.unicode_at(i) != 10:
				i += 1
			continue
		if (c >= 48 and c <= 57) or c in [43, 45, 46]:
			# Números em notação científica não são identificadores.
			while i < texto.length():
				var numero := texto.unicode_at(i)
				if not ((numero >= 48 and numero <= 57) or numero in [43, 45, 46, 69, 101]):
					break
				i += 1
			continue
		if (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c == 95:
			var inicio := i
			i += 1
			while i < texto.length():
				var seguinte := texto.unicode_at(i)
				if not ((seguinte >= 65 and seguinte <= 90) or (seguinte >= 97 and seguinte <= 122) or (seguinte >= 48 and seguinte <= 57) or seguinte == 95):
					break
				i += 1
			if texto.substr(inicio, i - inicio) not in TIPOS:
				return false
			continue
		i += 1
	return true


## SOBE A ESCADA, um degrau por vez, da versão do arquivo até a do jogo.
##
## Faltar um degrau é erro de programação, não do jogador: quem subiu `VERSAO`
## e não escreveu o método deixou um buraco na escada. Aqui isso PARA a
## leitura em vez de continuar — carregar por cima de um formato que ninguém
## converteu é o jeito de estragar o arquivo de quem confiou no jogo.
## `testar_salvamento.gd` cobra a escada inteira para que esse dia não chegue.
func _migrar(tudo: Dictionary, de: int) -> Dictionary:
	var versao := de
	while versao < VERSAO:
		if not MIGRACOES.has(versao):
			push_error("Salvamento: não há degrau da versão %d para a %d" % [versao, versao + 1])
			ultimo_relato.append(
				"Esta partida é da versão %d e falta o caminho para a %d. Ela NÃO foi carregada, e o arquivo continua no disco." % [versao, versao + 1])
			remendou.emit(ultimo_relato)
			return {}
		callv(str(MIGRACOES[versao]), [tudo])
		versao += 1
		tudo["versao"] = versao
	ultimo_relato.append("Partida da versão %d trazida para a %d." % [de, VERSAO])
	return tudo


# --- os degraus ------------------------------------------------------------------

## 1 → 2: entrou o `Povoado`, com a perícia dos moradores.
##
## Não há o que converter: a mudança foi aditiva, o save velho simplesmente não
## tem a seção, e quem carrega pula campo que falta. Os moradores de uma
## partida antiga voltam como aprendizes, que é o correto — o jogo não tem como
## saber quantos dias eles já trabalharam, e inventar um número seria pior do
## que começar do zero.
func _de_1_para_2(tudo: Dictionary) -> void:
	if not tudo.has("Povoado"):
		tudo["Povoado"] = {"pericia": {}}


## Põe a partida de volta. `tudo` vem de `ler`; passar {} é não fazer nada.
func carregar(tudo: Dictionary = {}) -> bool:
	if tudo.is_empty():
		tudo = ler()
	if tudo.is_empty():
		return false
	for nome in O_QUE_GUARDAR:
		var sistema := get_node_or_null("/root/" + str(nome))
		if sistema == null:
			continue
		var secao: Dictionary = tudo.get(str(nome), {})
		for campo in O_QUE_GUARDAR[nome]:
			if not secao.has(str(campo)):
				continue
			# Duplicado porque o que sai do arquivo é nosso, mas o que está na
			# memória passa a ser do sistema: compartilhar o mesmo Array faria
			# um save seguinte guardar o que o jogo mexeu depois de carregar.
			var valor = secao[str(campo)]
			sistema.set(str(campo), valor.duplicate(true) if valor is Array or valor is Dictionary else valor)
	_restaurar_especiais(tudo)
	_limpar()
	if not ultimo_relato.is_empty():
		remendou.emit(ultimo_relato)
	carregou.emit()
	return true


# --- a partida sobrevive à atualização do CONTEÚDO -------------------------------
#
# A migração cuida do FORMATO mudar, e formato muda pouco. O que muda toda
# semana é o CONTEÚDO: um item sai do catálogo, um talento é renomeado, uma
# obra some do JSON, uma carta é repensada. O save guarda esses nomes como
# texto, e texto não sabe que o dono morreu.
#
# O estrago não aparece na hora. A mochila carrega um "semente_erva" que não
# existe mais, e o jogo vai bem até alguém pedir o ícone dele e receber nulo
# três telas adiante — ou pior, até a conta de talentos somar um nó fantasma e
# o jogador ficar com fôlego que o jogo não sabe explicar.
#
# Por isso a limpeza roda SEMPRE, e não só depois de migrar: conteúdo muda
# entre builds sem que o formato mude uma vírgula.
#
# E ela é FALADA. Cada coisa descartada entra no relato e aparece na tela.
# Sumiço silencioso é o defeito que a limpeza existe para evitar; trocá-lo por
# um sumiço silencioso mais arrumado não seria conserto nenhum.

## Varre o que foi restaurado e joga fora o que aponta para coisa que não
## existe mais. Enche `ultimo_relato`.
func _limpar() -> void:
	_limpar_mochila()
	_limpar_equipamento()
	_limpar_talentos()
	_limpar_obras()
	_limpar_cartas()
	_limpar_colecao()
	_limpar_receitas()
	_limpar_trabalho()
	_ajustar_o_que_saiu_de_faixa()


func _limpar_mochila() -> void:
	var inventario := get_node_or_null("/root/Inventario")
	if inventario == null:
		return
	var perdidos: Array = []
	var espacos: Array = inventario.espacos
	for i in espacos.size():
		var espaco: Dictionary = espacos[i]
		var id := str(espaco.get("id", ""))
		if id == "" or Catalogo.ITENS.has(id):
			continue
		perdidos.append(id)
		espacos[i] = {}
	if not perdidos.is_empty():
		ultimo_relato.append("Saíram da mochila itens que o jogo não tem mais: %s."
			% ", ".join(perdidos))


func _limpar_equipamento() -> void:
	var equipamento := get_node_or_null("/root/Equipamento")
	if equipamento == null:
		return
	var perdidos: Array = []
	var vestido: Dictionary = equipamento.vestido
	for encaixe in vestido.keys():
		var id := str(vestido[encaixe])
		if id == "" or Catalogo.ITENS.has(id):
			continue
		perdidos.append(id)
		vestido[encaixe] = ""
	if not perdidos.is_empty():
		ultimo_relato.append("Foi tirado do corpo o que não existe mais: %s." % ", ".join(perdidos))


## TALENTO QUE SUMIU é o caso mais delicado da limpeza, e é por isso que ele
## só some da LISTA e o ponto NÃO é devolvido.
##
## O ganho do talento já está dentro da `Progressao`, que é salva com o valor
## dele somado — é a regra que este arquivo documenta lá em cima. Devolver o
## ponto daria ao jogador um ponto a mais E o bônus antigo, de graça e para
## sempre. Tirar o bônus exigiria saber o que o nó extinto fazia, e ele não
## existe mais para poder dizer.
##
## Some da lista para a teia não desenhar um nó fantasma, e o relato conta o
## que aconteceu. É o menos errado dos três caminhos, e o único honesto.
func _limpar_talentos() -> void:
	var talentos := get_node_or_null("/root/Talentos")
	if talentos == null:
		return
	var nos: Dictionary = talentos.NOS
	var perdidos: Array = []
	var ficam: Array = []
	for id in talentos.destravados:
		if nos.has(str(id)):
			ficam.append(id)
		else:
			perdidos.append(str(id))
	if perdidos.is_empty():
		return
	talentos.destravados = ficam
	ultimo_relato.append("Saíram da teia talentos que o jogo não tem mais: %s. O que eles davam continua com você."
		% ", ".join(perdidos))


func _limpar_obras() -> void:
	var obras := get_node_or_null("/root/Obras")
	if obras == null:
		return
	var perdidas: Array = []
	var feitas: Dictionary = obras.feitas
	for construcao in feitas.keys():
		var ficam: Array = []
		for obra in feitas[construcao]:
			if not obras.dados(str(obra)).is_empty():
				ficam.append(obra)
			else:
				perdidas.append(str(obra))
		feitas[construcao] = ficam
	if not perdidas.is_empty():
		ultimo_relato.append("Saíram do histórico obras que não existem mais: %s." % ", ".join(perdidas))


func _limpar_cartas() -> void:
	var cartas := get_node_or_null("/root/Cartas")
	if cartas == null:
		return
	var perdidas: Array = []
	for id in cartas.sabidas.keys():
		if cartas.dados(str(id)).is_empty():
			perdidas.append(str(id))
			cartas.sabidas.erase(id)
	# O PACTO EM VIGOR É DESFEITO se a carta dele sumiu. Deixá-lo de pé daria
	# um pacto que cobra todo dia e que o jogador não tem como consultar nem
	# desfazer, porque a carta não está mais em lugar nenhum da tela.
	if cartas.pacto != "" and cartas.dados(str(cartas.pacto)).is_empty():
		perdidas.append(str(cartas.pacto))
		cartas.pacto = ""
		cartas.pacto_mudou.emit("")
	if not perdidas.is_empty():
		ultimo_relato.append("Saíram cartas que o jogo não tem mais: %s." % ", ".join(perdidas))


func _limpar_colecao() -> void:
	var colecao := get_node_or_null("/root/Colecao")
	if colecao == null:
		return
	var perdidos: Array = []
	for nome in colecao.achados.keys():
		var catalogo: Dictionary = colecao.catalogo(str(nome))
		# Coleção inteira que saiu do jogo: o `achados` dela fica órfão. Não
		# adianta limpar item por item de uma lista cujo catálogo não abriu —
		# seria apagar tudo por não ter conseguido ler o arquivo.
		if catalogo.is_empty():
			continue
		var ficam: Array = []
		for id in colecao.achados[nome]:
			if catalogo.has(str(id)):
				ficam.append(id)
			else:
				perdidos.append(str(id))
		colecao.achados[nome] = ficam
	if not perdidos.is_empty():
		ultimo_relato.append("Saíram da coleção peças que não existem mais: %s." % ", ".join(perdidos))


## AS RECEITAS APRENDIDAS, e esta faz as duas coisas.
##
## Tira o que saiu do jogo, como as outras. E CONFERE O ESTADO, que é o que as
## outras não precisam fazer: a partida de quem já jogava não tem lista de
## receitas nenhuma, e se este sistema só escutasse sinais o save antigo abriria
## com o fogão, a oficina e o canteiro VAZIOS — a missão do fogão já cumprida, o
## cordel já achado, a amizade já feita, e nenhum desses sinais volta a tocar.
##
## `Receitas.conferir` varre as portas contra o estado de agora e abre o que ele
## já permitia. Vale também para receita nova que nasça sabida amanhã: ela tem
## que aparecer em toda partida que existe, e não só nas que começarem depois.
func _limpar_receitas() -> void:
	var receitas := get_node_or_null("/root/Receitas")
	if receitas == null:
		return
	var catalogo: Dictionary = receitas.tudo()
	var perdidas: Array = []
	var ficam: Array = []
	for id in receitas.aprendidas:
		if catalogo.has(str(id)):
			ficam.append(id)
		else:
			perdidas.append(str(id))
	receitas.aprendidas = ficam
	receitas.conferir()
	if not perdidas.is_empty():
		ultimo_relato.append("Saíram receitas que o jogo não tem mais: %s." % ", ".join(perdidas))


## Ofício que saiu da lista vira "nada" em vez de sumir: o morador continua na
## terra, e é o jogador quem decide o que ele faz agora.
func _limpar_trabalho() -> void:
	var terrenos := get_node_or_null("/root/Terrenos")
	if terrenos == null:
		return
	var perdidos: Array = []
	for morador in terrenos.trabalho.keys():
		var oficio := str(terrenos.trabalho[morador])
		if terrenos.TRABALHOS.has(oficio):
			continue
		perdidos.append("%s (%s)" % [str(morador), oficio])
		terrenos.trabalho[morador] = "nada"
	if not perdidos.is_empty():
		ultimo_relato.append("Ficaram sem serviço, porque o ofício saiu do jogo: %s."
			% ", ".join(perdidos))


## OS NÚMEROS QUE SAÍRAM DE FAIXA, que é a outra metade do estrago.
##
## Atualização mexe em balanço: o teto de fôlego muda, a mochila ganha ou perde
## espaço, o ano tem outro tanto de estações. O save traz o número velho, e o
## número velho passa a ser inválido sem deixar de ser um número — ninguém
## reclama, e o jogo anda com um índice apontando para fora do array até alguém
## clicar nele.
func _ajustar_o_que_saiu_de_faixa() -> void:
	var energia := get_node_or_null("/root/Energia")
	var progressao := get_node_or_null("/root/Progressao")
	if energia != null and progressao != null:
		var teto := float(progressao.energia_maxima)
		if float(energia.atual) > teto:
			ultimo_relato.append("O fôlego foi acertado ao teto desta versão (%d)." % int(teto))
			energia.atual = teto

	var inventario := get_node_or_null("/root/Inventario")
	if inventario != null:
		var quantos: int = (inventario.espacos as Array).size()
		if int(inventario.selecionado) >= quantos:
			inventario.selecionado = inventario.MAO_LIVRE

	var missoes := get_node_or_null("/root/Missoes")
	if missoes != null and int(missoes.em_foco) >= (missoes.ativas as Array).size():
		missoes.em_foco = 0

	var relogio := get_node_or_null("/root/Relogio")
	if relogio != null:
		var quantas: int = (relogio.NOMES_ESTACAO as Array).size()
		if int(relogio.estacao) < 0 or int(relogio.estacao) >= quantas:
			relogio.estacao = 0
		relogio.dia = clampi(int(relogio.dia), 1, int(relogio.DIAS_POR_ESTACAO))


## Começa de novo: apaga a partida e devolve todo sistema ao estado de fábrica.
##
## Apagar o arquivo NÃO basta e é a armadilha: os autoloads já estão em memória
## com o estado da partida anterior, e "jogo novo" a partir do menu cairia num
## roçado lavrado com a mochila cheia.
func apagar(slot: int = 0) -> void:
	var onde := _qual(slot)
	if existe_partida(onde):
		DirAccess.remove_absolute(arquivo(onde))
	_resumos.erase(onde)


# --- o que não cabe na tabela --------------------------------------------------

func _guardar_especiais(tudo: Dictionary) -> void:
	var fe := get_node_or_null("/root/Fe")
	if fe != null:
		tudo["Fe"] = {"ativa": fe.ativa, "estados": fe.get("_estados")}
	var terrenos := get_node_or_null("/root/Terrenos")
	if terrenos != null:
		tudo["TerrenosMeus"] = terrenos.get("_meus")
	var afinidade := get_node_or_null("/root/Afinidade")
	if afinidade != null:
		tudo["Afinidade"] = afinidade.estado()
	var cartas := get_node_or_null("/root/Cartas")
	if cartas != null:
		tudo["Cartas"] = cartas.estado()
	if _mundo != null and _mundo.has_method("estado_para_salvar"):
		tudo["Mundo"] = _mundo.call("estado_para_salvar")


func _restaurar_especiais(tudo: Dictionary) -> void:
	var fe := get_node_or_null("/root/Fe")
	if fe != null and tudo.has("Fe"):
		var dados: Dictionary = tudo["Fe"]
		fe.set("_estados", (dados.get("estados", {}) as Dictionary).duplicate(true))
		fe.ativa = str(dados.get("ativa", ""))
		# A tela de talentos lê `nivel`, `xp`, `pontos` e `destravados` da fé
		# ATIVA, que são espelhos do estado interno. Sem espelhar de volta, a
		# teia carrega vazia mesmo com a fé cheia.
		if fe.has_method("_espelhar"):
			fe.call("_espelhar")
	var terrenos := get_node_or_null("/root/Terrenos")
	if terrenos != null and tudo.has("TerrenosMeus"):
		terrenos.set("_meus", (tudo["TerrenosMeus"] as Dictionary).duplicate(true))
		if terrenos.has_signal("mudou"):
			terrenos.mudou.emit()
	var afinidade := get_node_or_null("/root/Afinidade")
	if afinidade != null and tudo.has("Afinidade"):
		afinidade.restaurar(tudo["Afinidade"])
	var cartas := get_node_or_null("/root/Cartas")
	if cartas != null and tudo.has("Cartas"):
		cartas.restaurar(tudo["Cartas"])
	if _mundo != null and _mundo.has_method("restaurar_do_save") and tudo.has("Mundo"):
		_mundo.call("restaurar_do_save", tudo["Mundo"])

	# Os sinais de "mudou" acordam quem desenha. Emitidos DEPOIS de tudo estar
	# posto, e não durante: a HUD lendo a mochila nova com a Progressao velha
	# mostraria fôlego acima do teto por um quadro.
	for nome in ["Inventario", "Missoes", "Talentos", "Obras", "Efeitos",
			"Equipamento", "Progressao", "Colecao", "Energia"]:
		var sistema := get_node_or_null("/root/" + nome)
		if sistema != null and sistema.has_signal("mudou"):
			sistema.mudou.emit()
