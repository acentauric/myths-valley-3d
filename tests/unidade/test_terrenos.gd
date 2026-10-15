extends "res://tests/unidade/base.gd"
## #9: o TRABALHO NAS TERRAS COMPRADAS, a regra da aba Trabalho sem a tela.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste terrenos
##
## O que este teste segura são cinco coisas que não dão erro nenhum quando quebram:
##
##   1. OS DADOS FECHAM. Morador num lote que não existe nas falas, morador em dois lotes, ofício
##      que rende item que o catálogo não tem: a aba mostraria uma promessa que a mochila não
##      cumpre, e ninguém veria o defeito antes de jogar dias em cima.
##   2. SÓ TRABALHA QUEM MORA EM TERRA QUE É SUA. Antes de comprar o lote da Dona Zefa o Cosme
##      não vai para a roça; depois de comprar, vai. A terra que deixa de ser do jogador tira o
##      morador do serviço, e o ofício volta a valer se a terra voltar.
##   3. IDOSO NÃO PEGA NO BRAÇO. A Dona Zefa e o Seu Benedito fazem farinha, cestaria e criação,
##      e nunca roçado nem lenha: "mandar os dois capinar o dia inteiro é desaforo".
##   4. O COMBINADO FICA NA VAGA. O ofício de cada um sai no save, volta no carregar, não passa de
##      uma vaga para a outra, e o serviço que o jogo não sabe mais dar vira "nada" ao carregar.
##   5. O SAVE COBRE O QUE O SISTEMA GUARDA. Campo público novo no `Terrenos` sem linha na tabela
##      do `Salvamento` reprova aqui, antes de alguém perder o ofício dos moradores ao recarregar.
##
## FALSIFICAÇÃO (a regra quebrada tem de reprovar), numa cópia carregada em memória do script, sem
## tocar no arquivo. O GUT recusa argumento que não conhece, então o pedido vai por variável de
## ambiente (o `testar.ps1` a repassa ao Godot):
##
##     $env:TESTAR3D_FALSIFICAR = "idoso"; .\tools\prototipo_3d\testar.ps1 -Teste terrenos
##
##   idoso            o idoso passa a ser quem tem braço: reprova em (3)
##   posse            o lote deixa de precisar ser do jogador: reprova em (2)
##   salvar_trabalho  a tabela do save esquece o ofício dos moradores: reprova em (4)
##   limpar           o carregar deixa o idoso no roçado: reprova em (4)
##
## Rodado direto com `--script`, vale também `-- --falsificar=idoso`.

const ALDEOES := "res://data/dialogos/aldeoes.json"

var terrenos
var terras
var jogo
var talentos
var salvamento
var partida
var falsificar := ""


func before_each() -> void:
	super.before_each()
	falsificar = OS.get_environment("TESTAR3D_FALSIFICAR")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--falsificar="):
			falsificar = arg.substr("--falsificar=".length())
	terrenos = root.get_node("/root/Terrenos")
	terras = root.get_node("/root/Terras")
	jogo = root.get_node("/root/Jogo")
	talentos = root.get_node("/root/Talentos")
	salvamento = root.get_node("/root/Salvamento")
	partida = root.get_node("/root/Partida")
	match falsificar:
		"idoso":
			_mutar("/root/Terrenos", "res://scripts/compartilhado/terrenos.gd",
				'return (Jogo.dados(Terras.ARQUIVO).get("idosos", []) as Array).has(morador)', "return false")
		"posse":
			_mutar("/root/Terrenos", "res://scripts/compartilhado/terrenos.gd",
				"if not Terras.meu(lote):", "if false:")
		"salvar_trabalho":
			_mutar("/root/Salvamento", "res://scripts/compartilhado/salvamento.gd",
				'"Terrenos": ["trabalho"],', '"Terrenos": [],')
		"limpar":
			_mutar("/root/Salvamento", "res://scripts/compartilhado/salvamento.gd",
				"and not (terrenos.e_idoso(str(morador)) and terrenos.e_bracal(oficio))", "and true")
	terrenos = root.get_node("/root/Terrenos")
	salvamento = root.get_node("/root/Salvamento")
	# Partida em branco: só o roçado, sem talento, sem fé e com dinheiro para as duas terras.
	terras.posses = {"rocado": true}
	talentos.destravados.clear()
	root.get_node("/root/Fe").ativa = ""
	jogo.dinheiro = 9000
	terrenos.trabalho.clear()


## Troca o script do autoload por uma cópia com `de` virado em `para`. A cópia tem de compilar e
## a troca tem de pegar, senão a falsificação passaria em branco.
func _mutar(no: String, caminho: String, de: String, para: String) -> void:
	var fonte := FileAccess.get_file_as_string(caminho)
	conferir(fonte.contains(de), "a falsificação %s não achou o trecho a trocar em %s" % [falsificar, caminho])
	var mutante := GDScript.new()
	mutante.source_code = fonte.replace(de, para)
	conferir(mutante.reload() == OK, "a cópia falsificada de %s não compilou" % caminho)
	root.get_node(no).set_script(mutante)


# --- 1. os dados fecham ----------------------------------------------------------------

func test_os_dados_do_trabalho_fecham() -> void:
	var oficios: Dictionary = terrenos.oficios()
	for id in ["nada", "roca", "lenha", "farinha", "artesanato", "criacao"]:
		conferir(oficios.has(id), "falta o ofício '%s'; o id vai para o save e é o mesmo do 2D" % id)
	conferir(oficios.keys()[0] == "nada", "'nada' tem de ser o primeiro: é o que a lista oferece para tirar do serviço")
	for id in oficios:
		var dele: Dictionary = oficios[id]
		conferir(str(terrenos.nome_do_oficio(str(id))) != "", "o ofício '%s' está sem nome" % id)
		conferir(str(terrenos.resumo_do_oficio(str(id))) != "", "o ofício '%s' está sem resumo" % id)
		conferir(dele.has("bracal"), "o ofício '%s' não diz se é braçal" % id)
		var rende: Dictionary = terrenos.rende(str(id))
		if id == "nada":
			conferir(rende.is_empty(), "'nada' rende %s" % str(rende))
			continue
		conferir(not rende.is_empty(), "o ofício '%s' não rende nada: promessa sem mochila" % id)
		for item in rende:
			conferir(Catalogo.existe(str(item)), "o ofício '%s' rende '%s', que não existe no catálogo" % [id, item])
			conferir(float(rende[item]) > 0.0, "o ofício '%s' rende %s de '%s'" % [id, str(rende[item]), item])
	conferir(terrenos.e_bracal("roca") and terrenos.e_bracal("lenha"), "roçado e lenha são serviço de braço")
	for id in ["farinha", "artesanato", "criacao"]:
		conferir(not terrenos.e_bracal(id), "'%s' é serviço de banco e de sombra, e o idoso tem de poder fazê-lo" % id)
	conferir(terrenos.ritmo_do_idoso() > 0.0 and terrenos.ritmo_do_idoso() < 1.0,
		"o ritmo do idoso (%s) tem de estar entre zero e um" % str(terrenos.ritmo_do_idoso()))

	var aldeoes: Dictionary = jogo.dados(ALDEOES)
	for idoso in jogo.dados(terras.ARQUIVO).get("idosos", []):
		conferir(aldeoes.has(str(idoso)), "o idoso '%s' não é morador do arraial" % idoso)
	var moram: Dictionary = {}
	var lotes: Dictionary = jogo.dados(terras.ARQUIVO).get("lotes", {})
	for lote in lotes:
		for morador in terrenos.moradores_de(str(lote)):
			conferir(aldeoes.has(str(morador)), "'%s' mora em '%s' e não está nas falas dos moradores" % [morador, lote])
			conferir(not moram.has(morador), "'%s' mora em dois lotes: '%s' e '%s'" % [morador, moram.get(morador, ""), lote])
			moram[morador] = lote
			conferir(terrenos.terreno_de(str(morador)) == str(lote), "terreno_de('%s') não achou '%s'" % [morador, lote])
		# Comprar não despeja: o dono do lote continua morando nele.
		var dono := str(lotes[lote].get("dono", ""))
		if dono != "":
			conferir(terrenos.moradores_de(str(lote)).has(dono), "o dono de '%s' ('%s') não mora nele" % [lote, dono])
	conferir(moram.has("cosme") and not terrenos.e_idoso("cosme"),
		"sem um morador com braço (o Cosme) em lote vendido, roçado e lenha nunca teriam quem fizesse")


# --- 2. só trabalha quem mora em terra que é sua ---------------------------------------

func test_so_trabalha_quem_mora_em_terra_comprada() -> void:
	# Antes de comprar: a terra é da Dona Zefa, e o Cosme mora nela.
	conferir(not terras.meu("terreno_zefa"), "o teste devia partir sem a terra da Zefa")
	conferir(not terrenos.mandar_trabalhar("cosme", "roca"), "o Cosme foi para a roça em terra que não é do jogador")
	conferir(terrenos.impedimento("cosme", "roca") == "terra_alheia",
		"o motivo devia ser 'terra_alheia' e foi '%s'" % terrenos.impedimento("cosme", "roca"))
	conferir(terrenos.trabalho_de("cosme") == "nada" and terrenos.trabalho.is_empty(), "a recusa deixou rastro no trabalho")
	# O roçado do jogador é dele, mas ninguém mora nele: não há quem mandar.
	conferir(terrenos.impedimento("pedro", "roca") == "sem_lote", "o Pedro não mora em lote nenhum")
	conferir(terrenos.impedimento("fantasma", "farinha") == "sem_lote", "quem não existe não mora em lote nenhum")
	conferir(terrenos.impedimento("cosme", "queijo") == "oficio_desconhecido", "ofício que não existe foi aceito")

	# Comprada a terra (pelo caminho de verdade: preço, divisa, dinheiro), o Cosme pode tudo.
	conferir(terras.comprar("terreno_zefa"), "o teste não conseguiu comprar a terra da Zefa")
	for id in ["roca", "lenha", "farinha", "artesanato", "criacao", "nada"]:
		conferir(terrenos.mandar_trabalhar("cosme", id), "o Cosme, em terra comprada, não pôde fazer '%s'" % id)
		conferir(terrenos.trabalho_de("cosme") == id, "o trabalho do Cosme devia ser '%s'" % id)
	conferir(terrenos.mandar_trabalhar("cosme", "roca"), "o Cosme não voltou para a roça")
	conferir(terrenos.lavradores("terreno_zefa") == ["cosme"], "os lavradores da Zefa: %s" % str(terrenos.lavradores("terreno_zefa")))
	conferir(terrenos.trabalhando() == {"cosme": "roca"}, "trabalhando() devia ser só o Cosme na roça: %s" % str(terrenos.trabalhando()))

	# Mudar de ofício tira da roça.
	conferir(terrenos.mandar_trabalhar("cosme", "farinha"), "o Cosme não trocou de ofício")
	conferir(terrenos.lavradores("terreno_zefa").is_empty(), "o Cosme saiu da roça e continua lavrador")

	# A terra do Seu Benedito só se toma depois da da Zefa, e só então ele pode trabalhar.
	conferir(terrenos.impedimento("benedito", "farinha") == "terra_alheia", "o Benedito trabalha em terra que não é do jogador")
	conferir(terras.comprar("terreno_benedito"), "o teste não conseguiu comprar a chapada do Benedito")
	conferir(terrenos.mandar_trabalhar("benedito", "farinha"), "o Benedito, em terra comprada, não pôde fazer farinha")

	# A TERRA QUE VOLTA A SER DE OUTRO tira o morador do serviço, sem apagar o combinado.
	conferir(terrenos.mandar_trabalhar("cosme", "roca"), "o Cosme não voltou à roça")
	terras.posses.erase("terreno_zefa")
	conferir(terrenos.trabalhando().has("benedito"), "a terra do Benedito não saiu do jogador, e ele parou de trabalhar")
	conferir(not terrenos.trabalhando().has("cosme"), "o Cosme segue trabalhando em terra que deixou de ser do jogador")
	conferir(terrenos.lavradores("terreno_zefa").is_empty(), "a roça de terra alheia ainda tem lavrador")
	conferir(terrenos.trabalho_de("cosme") == "roca", "o combinado devia ficar guardado, para valer se a terra voltar")
	terras.posses["terreno_zefa"] = true
	conferir(terrenos.trabalhando().get("cosme", "") == "roca", "o combinado não voltou com a terra")


# --- 3. idoso não pega no braço --------------------------------------------------------

func test_idoso_nao_faz_servico_de_braco() -> void:
	terras.posses["terreno_zefa"] = true
	terras.posses["terreno_benedito"] = true

	for idoso in ["zefa", "benedito"]:
		conferir(terrenos.e_idoso(idoso), "'%s' devia ser idoso" % idoso)
		conferir(not terrenos.mandar_trabalhar(idoso, "roca"), "%s foi para a enxada" % idoso)
		conferir(not terrenos.mandar_trabalhar(idoso, "lenha"), "%s foi para o machado" % idoso)
		conferir(terrenos.impedimento(idoso, "roca") == "idoso", "o motivo de %s na roça devia ser 'idoso'" % idoso)
		for id in ["farinha", "artesanato", "criacao", "nada"]:
			conferir(terrenos.mandar_trabalhar(idoso, id), "%s não pôde fazer '%s', que é serviço de banco" % [idoso, id])
		conferir(terrenos.trabalhos_de(idoso) == ["nada", "farinha", "artesanato", "criacao"],
			"a lista de %s: %s" % [idoso, str(terrenos.trabalhos_de(idoso))])
		conferir(terrenos.trabalho_de(idoso) == "nada", "%s devia ter ficado em 'nada' (o último pedido)" % idoso)
	conferir(not terrenos.e_idoso("cosme"), "o Cosme é o braço da família, não idoso")
	conferir(terrenos.trabalhos_de("cosme").size() == terrenos.oficios().size(), "o Cosme devia poder tudo")

	# A regra inteira, de uma vez: para todo morador de lote comprado e todo ofício, a resposta é
	# "sim" menos quando o morador é idoso e o serviço é de braço.
	var lotes: Dictionary = jogo.dados(terras.ARQUIVO).get("lotes", {})
	var perguntas := 0
	for lote in lotes:
		for morador in terrenos.moradores_de(str(lote)):
			for id in terrenos.oficios():
				var devia: bool = not (terrenos.e_idoso(str(morador)) and terrenos.e_bracal(str(id)))
				conferir(terrenos.pode(str(morador), str(id)) == devia,
					"%s no ofício '%s': devia ser %s" % [morador, id, "sim" if devia else "não"])
				perguntas += 1
	conferir(perguntas >= 3 * terrenos.oficios().size(), "a varredura olhou só %d perguntas" % perguntas)


# --- 4. o combinado fica na vaga -------------------------------------------------------

## O arquivo da partida, sem escrever nada: a mesma tabela que o `Salvamento` percorre ao salvar,
## pelo caminho do texto (a variante), como no disco.
func _como_no_disco() -> Dictionary:
	var texto := var_to_str(partida.instantaneo())
	var lido = salvamento.decodificar_dados(texto)
	conferir(lido is Dictionary, "o instantâneo da partida não voltou do texto")
	return lido if lido is Dictionary else {}


func test_o_trabalho_fica_na_vaga() -> void:
	terras.posses["terreno_zefa"] = true
	terras.posses["terreno_benedito"] = true
	terrenos.mandar_trabalhar("cosme", "roca")
	terrenos.mandar_trabalhar("zefa", "farinha")
	terrenos.mandar_trabalhar("benedito", "criacao")
	var combinado: Dictionary = terrenos.trabalho.duplicate(true)
	conferir(combinado.size() == 3, "o teste devia ter três moradores trabalhando")

	var gravado := _como_no_disco()
	conferir((gravado.get("Terrenos", {}) as Dictionary).get("trabalho", {}) == combinado,
		"o save não leva o trabalho dos moradores: %s" % str(gravado.get("Terrenos", "sem seção")))

	# VOLTA: o estado some e o carregar o devolve.
	terrenos.trabalho.clear()
	conferir(salvamento.carregar(gravado), "o carregar recusou a partida")
	conferir(terrenos.trabalho == combinado, "o trabalho não voltou do save: %s" % str(terrenos.trabalho))
	conferir(terrenos.trabalhando() == {"cosme": "roca", "zefa": "farinha", "benedito": "criacao"},
		"quem trabalha, depois de carregar: %s" % str(terrenos.trabalhando()))
	# O que veio do arquivo é do sistema: mexer nele não mexe no arquivo lido.
	terrenos.trabalho["cosme"] = "lenha"
	conferir(gravado["Terrenos"]["trabalho"]["cosme"] == "roca", "o carregar compartilhou o dicionário do arquivo")

	# VAGA NOVA volta à fábrica (ninguém trabalhando, só o roçado), e a vaga gravada volta inteira.
	partida.comecar(2)
	conferir(terrenos.trabalho.is_empty(), "a vaga nova herdou o trabalho dos moradores: %s" % str(terrenos.trabalho))
	conferir(not terras.meu("terreno_zefa"), "a vaga nova herdou a terra da Zefa")
	conferir(salvamento.carregar(gravado) and terrenos.trabalho == combinado, "voltar à vaga gravada perdeu o trabalho")

	# SAVE DE ANTES DO TERRENOS: sem a seção, o carregar não inventa serviço nem quebra.
	var antigo := gravado.duplicate(true)
	antigo.erase("Terrenos")
	partida.comecar(2)
	conferir(salvamento.carregar(antigo) and terrenos.trabalho.is_empty(), "o save sem a seção devia deixar todos em 'nada'")

	# O ARQUIVO DE VERDADE, só com o perfil descartável (nunca por cima do save de quem joga).
	if Estado.perfil_descartavel():
		terrenos.trabalho = combinado.duplicate(true)
		conferir(salvamento.salvar(3), "o save de verdade falhou")
		var do_disco: Dictionary = salvamento.ler(3)
		terrenos.trabalho.clear()
		conferir(salvamento.carregar(do_disco) and terrenos.trabalho == combinado, "o arquivo gravado não devolveu o trabalho")


func test_o_servico_que_o_jogo_nao_sabe_mais_dar_vira_nada_ao_carregar() -> void:
	terras.posses["terreno_zefa"] = true
	terras.posses["terreno_benedito"] = true
	var gravado := _como_no_disco()
	gravado["Terrenos"] = {"trabalho": {
		"cosme": "queijo",       # o ofício saiu do jogo
		"zefa": "roca",          # a idade não permite
		"fantasma": "farinha",   # ninguém mora em lote nenhum
		"benedito": "criacao",   # esse está certo
	}}
	salvamento.ultimo_relato = []
	conferir(salvamento.carregar(gravado), "o carregar recusou a partida")
	conferir(terrenos.trabalho_de("cosme") == "nada", "o ofício que saiu do jogo ficou: %s" % terrenos.trabalho_de("cosme"))
	conferir(terrenos.trabalho_de("zefa") == "nada", "a Zefa ficou no roçado depois de carregar")
	conferir(terrenos.trabalho_de("fantasma") == "nada", "quem não mora em lote algum ficou com serviço")
	conferir(terrenos.trabalho_de("benedito") == "criacao", "o serviço certo do Benedito foi apagado")
	var relato := "\n".join(salvamento.ultimo_relato)
	for quem in ["cosme (queijo)", "zefa (roca)", "fantasma (farinha)"]:
		conferir(relato.contains(quem), "o relato do carregar não diz que '%s' ficou sem serviço: %s" % [quem, relato])
	conferir(not relato.contains("benedito"), "o relato acusa o Benedito, que está certo")


# --- 5. o save cobre o que o sistema guarda --------------------------------------------

func test_o_save_cobre_tudo_que_o_terrenos_guarda() -> void:
	var guardados: Array = salvamento.O_QUE_GUARDAR.get("Terrenos", [])
	var campos := 0
	for p in terrenos.get_property_list():
		if not (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var campo: String = p["name"]
		if campo.begins_with("_"):
			continue
		campos += 1
		conferir(guardados.has(campo), "Terrenos.%s não está na tabela do Salvamento: ao recarregar ela volta ao começo" % campo)
	conferir(campos > 0, "não achei nenhum campo público no Terrenos: a varredura não está pegando")
	for campo in guardados:
		conferir(campo in terrenos, "a tabela do Salvamento guarda Terrenos.%s, que não existe: o save escreveria nulo" % campo)
	# A posse não é daqui: morando num lugar só, o save dela não se duplica.
	conferir(not salvamento.O_QUE_GUARDAR.has("TerrenosMeus") and not ("_meus" in terrenos),
		"o Terrenos guarda posse própria: dois donos do mesmo chão divergem")
