extends SceneTree
## OS ELOS DAS MISSÕES: cada passo das 23 filas tem para onde ir, a quem falar, de onde tirar o
## material, quem emita o acontecimento — e o E, do ponto onde o jogador chega, é de quem o passo manda.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/missoes_elos.gd
##
## É o portão RÁPIDO do par (o outro, `missoes_do_comeco_ao_fim`, joga tudo e leva minutos). Ele
## cobra, de `data/missoes_*.json` contra o vale construído:
##
##   1. o id de cada passo é único entre os arquivos (`Receitas.passo_abriu` chaveia pelo id cru);
##   2. o `lugar` de cada passo RESOLVE no vale — o motor PULA, calado, o passo cujo lugar não
##      resolve (`CadeiaDeMissoes.correr`), com a recompensa e a cena dele;
##   3. todo `a_quem` e todo `mutirao` é morador do vale, com posto (ou agenda) em algum período;
##   4. todo item existe no catálogo e tem uma fonte que o jogador alcança (alvo de trabalho,
##      bancada, entrega, recompensa, baú, mutirão, venda);
##   5. todo acontecimento (`evento`, `contar`) tem quem o emita no código do vale;
##   6. todo passo de obra: a obra e o sítio existem, e o resumo do HUD diz a tecla — [E] e [J] onde
##      o E toca a obra;
##   7. toda fila com `depois_de` escreve o aviso da fila trancada nos três idiomas, sem copiar o
##      português;
##   8. O E CHEGA NA PESSOA CERTA: para cada passo `falar`/`levar`, em cada período do dia, com os
##      moradores de verdade nos postos (e o Pedro logo atrás do jogador, no tutorial), no ponto
##      onde o jogador chega — de frente para ela —, quem leva o E é a conversa e é ELA (e não o
##      Pedro, que fica a dois passos do Tonho de propósito), e o passo vira "falar"/"entregar";
##   9. o jogador CHEGA: o controle acha caminho do começo da partida até cada lugar e cada pessoa.
##
## "Não consegui interagir com o poço, logo essa missão quebrou", e "Quando fui falar com Dona
## Candinha para pegar a chave, não consegui interagir": nenhum portão olhava de onde o jogador
## chega, nem quem leva a tecla ali.

const Jogada = preload("res://tests/fixtures/jogada.gd")
const RelogioDeJogo = preload("res://tests/fixtures/relogio_de_jogo.gd")

## As horas que cobrem os períodos do dia dos moradores (manhã, tarde, entardecer, noite, madrugada).
const HORAS := [8.0, 14.0, 17.5, 21.0, 3.0]
const LETRAS_DO_RESUMO := 60
const FOLGA_DA_GRADE := 3.0
## Moradores que só aparecem num dia do calendário (o mestre do saveiro): `SaveiroVale` os traz.
const SO_NO_DIA_DO_SAVEIRO := ["quirino"]
## De onde sai cada item que o portão não acha nas tabelas: o jogador o ganha sem a tabela dizer
## (o convite vem da missão, e o que mais?). Vazio é o certo: a lista só cresce com razão escrita.
const FONTES_FORA_DA_TABELA := {
	# O ovo sai do galinheiro do quintal, que não é alvo nem bancada: as galinhas botam todo dia e o E
	# recolhe (`curral_vale.recolher`, #160).
	"ovo": "o galinheiro do quintal (curral_vale.gd)",
	# A lança e o escudo de safiras estão entre os destroços da torre da capela das ruínas, e o E
	# ali os dá (`revoar_vale._pegar_as_armas`, #31).
	"lanca_de_safira": "os destroços da torre da capela (revoar_vale.gd)",
	"escudo_de_safira": "os destroços da torre da capela (revoar_vale.gd)",
}

var falhas := 0
var vale
var jogada
var relogio: Node
var arquivos: Array = []
var passos_vivos := {}
var ids_vistos := {}
var fontes := {}
var presentes := {}
var codigo := ""


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("ELOS_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await process_frame
	for i in range(3000):
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	for i in range(8):
		await process_frame
	vale = current_scene
	relogio = RelogioDeJogo.new()
	root.add_child(relogio)
	relogio.ficar_lento()
	jogada = Jogada.new(self, vale, relogio, func(t: String) -> void: _conferir(false, t), func(t: String) -> void: print(t))
	root.get_node("/root/Dia").pausado = true

	_ler_os_arquivos()
	_ligar_as_filas_vivas()
	_ler_o_codigo()
	_montar_as_fontes()
	await _presenca_nos_periodos()
	_dados_dos_passos()
	_avisos_das_filas_trancadas()
	await _donos_do_e_e_caminhos()

	_fechar()


# --- a leitura ------------------------------------------------------------------------------

func _ler_os_arquivos() -> void:
	var nomes: Array = []
	for nome in DirAccess.get_files_at("res://data"):
		if str(nome).begins_with("missoes_") and str(nome).ends_with(".json"):
			nomes.append(str(nome))
	nomes.sort()
	for nome in nomes:
		var dado = JSON.parse_string(FileAccess.get_file_as_string("res://data/" + nome))
		_conferir(dado is Dictionary and (dado as Dictionary).get("passos") is Array, "%s não é uma fila com passos" % nome)
		if dado is Dictionary:
			arquivos.append({"nome": nome, "dado": dado})
	# 25 desde 07/10: as 19 filas, as 3 da fé, a meta da onça (#117), o segundo tutorial (#160) e o capítulo 7 (#31).
	_conferir(arquivos.size() == 25, "são %d arquivos de missão, e eram 25 (as 19 filas, as 3 da fé, a meta da onça, o segundo tutorial e o capítulo 7): conferir a lista do portão" % arquivos.size())


## As filas VIVAS do vale: a do tutorial (do Pedro) e as penduradas (`vale._cadeias`). O motor lê
## o que elas carregam, e o portão pergunta a elas — o primeiro passo diz de qual arquivo é cada uma.
func _ligar_as_filas_vivas() -> void:
	var vivas: Array = [vale.pedro._cadeia]
	for chave in vale._cadeias:
		vivas.append(vale._cadeias[chave])
	for cadeia in vivas:
		for i in cadeia.passos.size():
			passos_vivos[str((cadeia.passos[i] as Dictionary).get("id", ""))] = {"cadeia": cadeia, "indice": i}
	var sem_fila := 0
	for arquivo in arquivos:
		for passo in (arquivo["dado"] as Dictionary).get("passos", []):
			if not passos_vivos.has(str((passo as Dictionary).get("id", ""))):
				sem_fila += 1
				_conferir(false, "o passo '%s' de %s não está em nenhuma fila viva do vale: ninguém o pendurou" % [(passo as Dictionary).get("id", "?"), arquivo["nome"]])
	var total := 0
	for arquivo in arquivos:
		total += ((arquivo["dado"] as Dictionary).get("passos", []) as Array).size()
	# 100 desde 07/10: os cinco passos do segundo tutorial (#160) e os sete do capítulo 7 (#31) sobre os 88 de 06/10.
	_conferir(total == 100, "são %d passos, e eram 100: conferir a lista do portão (e os que o jogo toca, em `missoes_do_comeco_ao_fim`)" % total)


## O TEXTO DO CÓDIGO DO VALE, de onde se conta quem emite cada acontecimento. Menos o motor da fila
## e o do Pedro: eles LEEM o acontecimento, e não o emitem.
func _ler_o_codigo() -> void:
	for pasta in ["res://scripts/prototipo_3d", "res://scripts/compartilhado", "res://scripts/autoload", "res://scripts/ui"]:
		for nome in DirAccess.get_files_at(pasta):
			if not str(nome).ends_with(".gd") or ["cadeia_de_missoes.gd", "guia_pedro.gd"].has(str(nome)):
				continue
			codigo += FileAccess.get_file_as_string(pasta + "/" + str(nome)) + "\n"


## Onde o jogador consegue o item. Cada fonte é um nome curto, que o aviso de falha repete.
func _montar_as_fontes() -> void:
	var venda := root.get_node("/root/Venda")
	for id in venda.MERCADORIAS:
		_fonte(str(id), "venda")
	var recursos = vale.get_node("Recursos3D")
	for id in recursos._alvos:
		var rende := str((recursos._alvos[id]["ficha"] as Dictionary).get("rende", ""))
		if rende != "":
			_fonte(rende, "alvo de trabalho")
	for id in root.get_node("/root/Oficina").RECEITAS:
		_fonte(str(id), "bancada")
	for id in root.get_node("/root/Cozinha").RECEITAS:
		_fonte(str(id), "fogo")
	var casa = vale.get("casa")
	if casa != null:
		for monte in casa.bau:
			_fonte(str((monte as Dictionary).get("id", "")), "baú")
	for arquivo in arquivos:
		for passo in (arquivo["dado"] as Dictionary).get("passos", []):
			for lista in [(passo as Dictionary).get("entrega", []), [(passo as Dictionary).get("recompensa", {})]]:
				var entradas: Array = lista if lista is Array else [lista]
				for entrada in entradas:
					if entrada is Dictionary:
						var item := str((entrada as Dictionary).get("item", ""))
						if item != "":
							_fonte(item, "entrega do passo")
						else:
							for chave in (entrada as Dictionary):
								if Catalogo.existe(str(chave)):
									_fonte(str(chave), "recompensa do passo")
			var mutirao = (passo as Dictionary).get("mutirao", {})
			if mutirao is Dictionary:
				for quem in mutirao:
					var itens = (mutirao[quem] as Dictionary).get("itens", {}) if mutirao[quem] is Dictionary else {}
					for item in itens:
						_fonte(str(item), "mutirão")
	for item in FONTES_FORA_DA_TABELA:
		_fonte(str(item), str(FONTES_FORA_DA_TABELA[item]))


func _fonte(item: String, de_onde: String) -> void:
	if item == "":
		return
	if not fontes.has(item):
		fontes[item] = []
	if not (fontes[item] as Array).has(de_onde):
		(fontes[item] as Array).append(de_onde)


# --- quem está onde, quando -------------------------------------------------------------------

## Os moradores de verdade, nos postos de cada período: quem aparece em algum, e quem o jogador pode
## encontrar de pé (visível) em cada um.
func _presenca_nos_periodos() -> void:
	var dia := root.get_node("/root/Dia")
	for h in HORAS:
		dia.definir_hora(float(h))
		await jogada.quadros(3)
		for morador in _todos_os_moradores():
			morador.liberar()
			morador.ir_ao_posto_agora()
		await jogada.quadros(4)
		for morador in _todos_os_moradores():
			var id := str(morador.dados.get("id", ""))
			if morador.is_visible_in_tree():
				presentes[id] = true


func _todos_os_moradores() -> Array:
	var todos: Array = [vale.pedro]
	for morador in vale.moradores:
		if morador != vale.pedro:
			todos.append(morador)
	return todos


# --- os dados de cada passo ---------------------------------------------------------------

func _dados_dos_passos() -> void:
	var lugares := root.get_node("/root/Lugares")
	var obras := root.get_node("/root/Obras")
	var oficina := root.get_node("/root/Oficina")
	var cozinha := root.get_node("/root/Cozinha")
	var bancadas = vale.get("tecla_das_bancadas")
	var BancadasVale = load("res://scripts/prototipo_3d/bancadas_vale.gd")
	var recursos = vale.get_node("Recursos3D")
	var pontos_de_obra := 0
	for arquivo in arquivos:
		var nome_do_arquivo := str(arquivo["nome"])
		for bruto in (arquivo["dado"] as Dictionary).get("passos", []):
			var passo: Dictionary = bruto
			var id := str(passo.get("id", "?"))
			var onde := "%s, passo '%s'" % [nome_do_arquivo, id]
			# 1. O ID É ÚNICO.
			_conferir(not ids_vistos.has(id), "%s: o id '%s' também é de %s" % [onde, id, str(ids_vistos.get(id, ""))])
			ids_vistos[id] = nome_do_arquivo
			# 2. O LUGAR RESOLVE.
			_conferir(lugares.resolve(str(passo.get("lugar", ""))),
				"%s: o lugar '%s' não resolve no vale, e o motor pularia o passo calado" % [onde, passo.get("lugar", "")])
			var meta: Dictionary = passo.get("meta", {})
			var tipo := str(meta.get("tipo", ""))
			# 3. QUEM É PROCURADO EXISTE E APARECE.
			if tipo == "falar" or tipo == "levar":
				_morador_que_aparece(str(meta.get("a_quem", "")), onde + " (a_quem)")
			var mutirao = passo.get("mutirao", {})
			if mutirao is Dictionary:
				for quem in mutirao:
					_morador_que_aparece(str(quem), onde + " (mutirão)")
			# 4. O MATERIAL TEM DE ONDE VIR.
			if tipo == "juntar" or tipo == "levar" or tipo == "oferendar":
				var carga := _carga(meta)
				for item in carga:
					_conferir(Catalogo.existe(str(item)), "%s: o item '%s' não existe no catálogo" % [onde, item])
					_conferir(fontes.has(str(item)), "%s: ninguém dá '%s' ao jogador (sem alvo, bancada, entrega, baú, mutirão nem venda)" % [onde, item])
			for peca in (meta.get("equivale", {}) as Dictionary):
				_conferir(not oficina.dados(str(peca)).is_empty(), "%s: a peça '%s' do `equivale` não é receita da oficina" % [onde, peca])
			for entrega in _como_lista(passo.get("entrega", [])):
				_conferir(Catalogo.existe(str((entrega as Dictionary).get("item", ""))),
					"%s: a entrega '%s' não existe no catálogo" % [onde, (entrega as Dictionary).get("item", "")])
			var recompensa: Dictionary = passo.get("recompensa", {})
			for item in recompensa:
				_conferir(Catalogo.existe(str(item)) or str(item) == "reis" or str(item) == "xp", "%s: a recompensa '%s' não existe no catálogo" % [onde, item])
			# 5. O ACONTECIMENTO TEM QUEM O EMITA.
			if tipo == "evento" or tipo == "contar":
				for evento in _eventos(meta):
					_conferir(_tem_emissor(str(evento)), "%s: ninguém emite o acontecimento '%s' no código do vale" % [onde, evento])
			# 6. A OBRA E O SÍTIO EXISTEM, E O RESUMO DIZ A TECLA.
			if tipo == "obra":
				pontos_de_obra += 1
				var construcao := str(meta.get("construcao", ""))
				var obra := str(meta.get("obra", ""))
				_conferir(not obras.dados(obra).is_empty(), "%s: a obra '%s' não está em `Obras`" % [onde, obra])
				_conferir(BancadasVale.OBRAS.has(construcao), "%s: o sítio '%s' não está em `BancadasVale.OBRAS`" % [onde, construcao])
				var com_e: bool = BancadasVale.com_e().has(construcao)
				for sufixo in ["", "_en", "_es"]:
					var resumo := str(passo.get("resumo" + sufixo, ""))
					var rotulo := "%s, resumo%s '%s'" % [onde, sufixo, resumo]
					_conferir(resumo.contains("[E]") or resumo.contains("(E)") or resumo.contains("[J]"), "%s: não diz a tecla que faz a obra" % rotulo)
					_conferir(resumo.length() <= LETRAS_DO_RESUMO, "%s: tem %d letras, e o HUD aceita %d" % [rotulo, resumo.length(), LETRAS_DO_RESUMO])
					if com_e:
						_conferir(resumo.contains("[E]") and resumo.contains("[J]"),
							"%s: o E toca a obra ali (raio do E %.1f), e o resumo devia dizer [E] e [J]" % [rotulo, BancadasVale.raio_do_e(construcao)])
			if tipo == "derrubar":
				_conferir(recursos.mais_perto_da_peca(str(meta.get("alvo", "")), vale.player.global_position) != lugares.NENHUM,
					"%s: não há no vale alvo de peça/grupo '%s' para derrubar" % [onde, meta.get("alvo", "")])
	_conferir(pontos_de_obra == 6, "são %d passos de obra, e eram 6 (poço, ponte, canteiro, mirante, cemitério, carroça)" % pontos_de_obra)
	# As receitas e as obras que dizem "abre em tal passo" apontam para passo que existe.
	var abertos: Array = []
	for receitas in [oficina.RECEITAS, cozinha.RECEITAS]:
		for id in receitas:
			var abre = (receitas[id] as Dictionary).get("abre", {})
			if abre is Dictionary and (abre as Dictionary).has("missao"):
				abertos.append([str(id), (abre as Dictionary)["missao"]])
	for id in obras.catalogo():
		var abre = (obras.catalogo()[id] as Dictionary).get("abre", {})
		if abre is Dictionary and (abre as Dictionary).has("missao"):
			abertos.append([str(id), (abre as Dictionary)["missao"]])
	for par in abertos:
		var abre_em: Array = par[1] if par[1] is Array else [par[1]]
		for passo_que_abre in abre_em:
			_conferir(ids_vistos.has(str(passo_que_abre)), "a receita/obra '%s' abre no passo '%s', que não existe em nenhum arquivo" % [par[0], passo_que_abre])
	var _sem_uso = bancadas


func _como_lista(valor) -> Array:
	if valor is Array:
		return valor
	return [valor] if valor is Dictionary and not (valor as Dictionary).is_empty() else []


func _eventos(meta: Dictionary) -> Array:
	var lista: Array = meta.get("eventos", [])
	return lista if not lista.is_empty() else [str(meta.get("evento", ""))]


func _carga(meta: Dictionary) -> Dictionary:
	var varios: Dictionary = meta.get("itens", {})
	if not varios.is_empty():
		return varios
	var da_obra := str(meta.get("da_obra", ""))
	if da_obra != "":
		return root.get_node("/root/Obras").custo(da_obra)
	return {str(meta.get("item", "")): int(meta.get("quantos", 1))} if str(meta.get("item", "")) != "" else {}


func _morador_que_aparece(id: String, onde: String) -> void:
	var morador = vale._achar_morador(id)
	_conferir(morador != null, "%s: '%s' não é morador do vale" % [onde, id])
	if morador == null:
		return
	_conferir(presentes.has(id) or SO_NO_DIA_DO_SAVEIRO.has(id),
		"%s: '%s' não aparece em nenhum período do dia (postos e agenda)" % [onde, id])


## Alguém no código do vale diz esse acontecimento: o nome inteiro entre aspas, ou o prefixo antes
## do ":" (`"cozinhou:%s"`, `"entrou:" + sala`).
func _tem_emissor(evento: String) -> bool:
	var prefixo := evento.get_slice(":", 0)
	if evento.contains(":"):
		return codigo.contains("\"%s:" % prefixo) or codigo.contains("\"%s\"" % evento)
	return codigo.contains("\"%s\"" % evento) or codigo.contains("\"%s:" % evento)


# --- o aviso da fila trancada ----------------------------------------------------------------

func _avisos_das_filas_trancadas() -> void:
	var com_aviso := 0
	for arquivo in arquivos:
		var dado: Dictionary = arquivo["dado"]
		var primeiro := str(((dado["passos"] as Array)[0] as Dictionary).get("id", ""))
		var viva = (passos_vivos.get(primeiro, {}) as Dictionary).get("cadeia")
		if viva == null:
			continue
		var trancavel: bool = viva.depois_de.is_valid() and viva.comeca_perto_de > 0.0
		if not trancavel and not dado.has("trancada"):
			continue
		_conferir(trancavel, "%s tem `trancada`, mas a fila não é de quem espera outra coisa (`depois_de`): o aviso nunca sai" % arquivo["nome"])
		com_aviso += 1
		var pt := str(dado.get("trancada", ""))
		_conferir(pt.strip_edges().length() >= 20, "%s: a fila espera outra coisa e não escreveu o `trancada` (o que fazer antes)" % arquivo["nome"])
		for sufixo in ["_en", "_es"]:
			var texto := str(dado.get("trancada" + sufixo, ""))
			_conferir(texto.strip_edges().length() >= 20, "%s: falta `trancada%s`" % [arquivo["nome"], sufixo])
			_conferir(texto != pt, "%s: `trancada%s` é cópia do português" % [arquivo["nome"], sufixo])
	_conferir(com_aviso >= 12, "só %d filas trancáveis com aviso, e eram 13 (zefa, candinha, filo, damião, tonho, roça, saveiro, carroça, lombada, chapada, mirante, fé, capoeira)" % com_aviso)


# --- o E chega na pessoa certa, e o jogador chega -------------------------------------------

func _donos_do_e_e_caminhos() -> void:
	var dia := root.get_node("/root/Dia")
	var jogador = vale.player
	var tecla = vale.tecla_dos_moradores
	var inventario := root.get_node("/root/Inventario")
	var spawn: Vector3 = jogador.spawn_position
	# O QUE O JOGADOR ENCONTRA: cada passo de falar/levar, a cada período em que a pessoa está de pé.
	var conferidos := {}
	var pedidos := 0
	for h in HORAS:
		dia.definir_hora(float(h))
		await jogada.quadros(3)
		for morador in _todos_os_moradores():
			morador.liberar()
			morador.ir_ao_posto_agora()
		await jogada.quadros(5)
		for arquivo in arquivos:
			for bruto in (arquivo["dado"] as Dictionary).get("passos", []):
				var passo: Dictionary = bruto
				var meta: Dictionary = passo.get("meta", {})
				var tipo := str(meta.get("tipo", ""))
				if tipo != "falar" and tipo != "levar":
					continue
				var id := str(passo.get("id", ""))
				var viva: Dictionary = passos_vivos.get(id, {})
				if viva.is_empty():
					continue
				var cadeia = viva["cadeia"]
				var quem = vale._achar_morador(str(meta.get("a_quem", "")))
				if quem == null or not quem.is_visible_in_tree():
					continue
				pedidos += 1
				var resultado: String = await _o_e_neste_passo(cadeia, int(viva["indice"]), meta, quem, jogador, tecla, inventario, vale.pedro._cadeia == cadeia)
				if resultado != "":
					_conferir(false, "passo '%s', às %.1f h: %s" % [id, float(h), resultado])
				else:
					conferidos[id] = true
	_conferir(conferidos.size() >= 24, "o E foi conferido em só %d passos de falar/levar (eram 25; o mestre do saveiro só aparece no dia dele)" % conferidos.size())

	# O JOGADOR CHEGA: do começo da partida a cada lugar de passo e a cada pessoa procurada.
	dia.definir_hora(8.0)
	await jogada.quadros(3)
	for morador in _todos_os_moradores():
		morador.liberar()
		morador.ir_ao_posto_agora()
	await jogada.quadros(4)
	var sem_caminho := 0
	var alvos_vistos := {}
	for arquivo in arquivos:
		for bruto in (arquivo["dado"] as Dictionary).get("passos", []):
			var passo: Dictionary = bruto
			var id := str(passo.get("id", ""))
			var viva: Dictionary = passos_vivos.get(id, {})
			if viva.is_empty():
				continue
			var ponto: Vector3 = viva["cadeia"].posicao_do_passo(int(viva["indice"]))
			var meta: Dictionary = passo.get("meta", {})
			var tipo := str(meta.get("tipo", ""))
			var ideal := 1.9 if (tipo == "falar" or tipo == "levar") else 0.0
			if tipo == "falar" or tipo == "levar":
				var quem = vale._achar_morador(str(meta.get("a_quem", "")))
				if quem == null or not quem.is_visible_in_tree():
					continue
				ponto = quem.global_position
			if ponto == Vector3.ZERO or not ponto.is_finite():
				continue
			var chave := "%d,%d" % [roundi(ponto.x), roundi(ponto.z)]
			if alvos_vistos.has(chave):
				continue
			alvos_vistos[chave] = true
			var raio := float(passo.get("raio", 8.0))
			var chegada: Vector3 = jogada.chegada(ponto, ideal, spawn, 8.0 if ideal > 0.0 else minf(raio, 8.0))
			if not chegada.is_finite():
				sem_caminho += 1
				_conferir(false, "passo '%s': não há ponto andável a até %.0f u de %s — ninguém chega lá" % [id, minf(raio, 8.0), str(ponto)])
				continue
			var caminho: PackedVector3Array = jogada.caminho_ate(chegada, spawn)
			if caminho.is_empty():
				sem_caminho += 1
				_conferir(false, "passo '%s': o controle não acha caminho do começo da partida até %s (para %s)" % [id, str(chegada), str(ponto)])
				continue
			# O corpo que chega ao fim do caminho tem de estar onde o passo se cumpre: a conversa alcança
			# 2,8 u; o alvo de trabalho, 3,2 (mais a meia-pegada dele); o lugar, o `raio` do passo.
			var fim: Vector3 = caminho[caminho.size() - 1]
			# MAIS A FOLGA DA GRADE do controle (2,5 u por célula, e o fim do caminho é o centro da célula
			# livre mais perto): o último trecho o jogador anda com as setas.
			var folga_do_passo := raio + FOLGA_DA_GRADE
			if tipo == "falar" or tipo == "levar":
				folga_do_passo = 2.6 + FOLGA_DA_GRADE
			elif tipo == "juntar" or tipo == "derrubar":
				folga_do_passo = 3.2 + FOLGA_DA_GRADE
			var falta_ao_fim := Vector2(fim.x - ponto.x, fim.z - ponto.z).length()
			_conferir(falta_ao_fim <= folga_do_passo,
				"passo '%s' (%s): o caminho do começo da partida termina a %.1f u de %s, e o passo se cumpre a até %.1f u" % [id, tipo if tipo != "" else "lugar", falta_ao_fim, str(ponto), folga_do_passo])
	_conferir(alvos_vistos.size() >= 30, "o caminho foi conferido em só %d lugares distintos" % alvos_vistos.size())


## O E no ponto onde o jogador chega ao `quem`, com este passo aberto: devolve "" se tudo bem, ou a queixa.
func _o_e_neste_passo(cadeia, indice: int, meta: Dictionary, quem, jogador, tecla, inventario, e_o_tutorial: bool) -> String:
	var guardado := {"iniciado": cadeia.iniciado, "missao": cadeia.missao, "espera": cadeia.espera}
	# O TUTORIAL JÁ ACABOU quando as outras filas pedem alguém (ele abre sozinho quando o jogador
	# chega perto do Pedro, e o passo dele "fale com o Pedro" tomaria o E dele).
	var guia = vale.pedro._cadeia
	var do_guia := {"iniciado": guia.iniciado, "missao": guia.missao, "espera": guia.espera, "despedida": guia.despedida_feita}
	if not e_o_tutorial:
		guia.iniciado = true
		guia.missao = guia.passos.size()
		guia.espera = 0.0
		guia.despedida_feita = true
	# A fila que só anda dentro de uma fé (a capoeira, no candomblé) é conferida com a fé dela.
	var fe := root.get_node("/root/Fe")
	var fe_guardada: String = fe.ativa
	if cadeia.so_enquanto.is_valid() and not bool(cadeia.so_enquanto.call()):
		fe.ativa = "candomble"
	cadeia.iniciado = true
	cadeia.missao = indice
	cadeia.espera = 0.0
	var posto_do_pedro: Vector3 = vale.pedro.global_position
	var injetados := {}
	if str(meta.get("tipo", "")) == "levar":
		var carga := _carga(meta)
		for item in carga:
			var falta := int(carga[item]) - int(inventario.quantidade(str(item)))
			if falta > 0 and inventario.adicionar(str(item), falta):
				injetados[str(item)] = falta
	var queixa := ""
	# O lado de onde o jogador vem: o da praça, e o primeiro ponto livre a partir dele.
	var da_praca: Vector3 = vale.world.ancoras.get("Praça", quem.global_position)
	var ponto: Vector3 = jogada.chegada(quem.global_position, 1.9, da_praca, 4.0)
	if not ponto.is_finite():
		queixa = "não há ponto andável a 1,9 u de %s: ninguém fala com ele" % jogada.nome_de(quem)
	else:
		var para: Vector3 = quem.global_position - ponto
		para.y = 0.0
		var giro := atan2(para.x, para.z)
		# Na altura de quem se fala: no píer o chão do terreno é o fundo do mar.
		ponto.y = maxf(ponto.y, quem.global_position.y)
		jogador.teleportar(ponto + Vector3(0.0, 0.05, 0.0), giro)
		if e_o_tutorial and quem != vale.pedro:
			# NO TUTORIAL O PEDRO SEGUE O JOGADOR, a um passo e meio atrás.
			vale.pedro.global_position = ponto - Vector3(sin(giro), 0.0, cos(giro)) * 1.5
		# O CARTÃO DA PRIMEIRA VEZ (a água funda de um teleporte, o cordel, a árvore) para a
		# árvore inteira, e com ela parada o E não é de ninguém: fecha, como o jogador faria.
		var aviso = vale.get("aviso_da_primeira_vez")
		for i in 4:
			if aviso != null and aviso.aberto():
				aviso.fechar()
			await jogada.quadros(1)
		await jogada.quadros(3)
		var o_que: String = cadeia.o_que_o_e_faz(quem)
		var dono = jogada.dono_do_e()
		var perto = tecla.perto()
		if o_que != "falar" and o_que != "entregar":
			queixa = "a fila não diz que o E faz '%s' com %s (diz '%s')" % [meta.get("tipo", ""), jogada.nome_de(quem), o_que]
		elif dono != tecla:
			queixa = "ao lado de %s o E é de %s, e não da conversa" % [jogada.nome_de(quem), jogada.nome_de(dono)]
		elif perto != quem:
			queixa = "o E é da conversa, mas com %s, e o passo manda procurar %s (jogador a %.2f de um e %.2f do outro; ação das filas: %d e %d; alcance %.1f)" % [
				jogada.nome_de(perto), jogada.nome_de(quem),
				jogador.global_position.distance_to(perto.global_position) if perto != null else -1.0,
				jogador.global_position.distance_to(quem.global_position),
				tecla._acao_das_filas(perto) if perto != null else -1, tecla._acao_das_filas(quem), tecla.ALCANCE]
			for outra in get_nodes_in_group("cadeias_de_missoes"):
				var faz: String = outra.o_que_o_e_faz(perto) if perto != null else ""
				if faz != "":
					queixa += " [a fila '%s' (passo %d, '%s') diz '%s' com %s]" % [outra.name, outra.missao, str((outra.passo_atual() as Dictionary).get("id", "")), faz, jogada.nome_de(perto)]
	for item in injetados:
		inventario.consumir(item, int(injetados[item]))
	fe.ativa = fe_guardada
	guia.iniciado = bool(do_guia["iniciado"])
	guia.missao = int(do_guia["missao"])
	guia.espera = float(do_guia["espera"])
	guia.despedida_feita = bool(do_guia["despedida"])
	cadeia.iniciado = bool(guardado["iniciado"])
	cadeia.missao = int(guardado["missao"])
	cadeia.espera = float(guardado["espera"])
	vale.pedro.global_position = posto_do_pedro
	return queixa


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("ELOS_OK: as 23 filas e os 88 passos se ligam — ids únicos, lugares que resolvem, gente que aparece, material com fonte, acontecimentos com emissor, obras com a tecla no resumo ([E] e [J] onde o E toca), aviso da fila trancada nos três idiomas, o E é da pessoa certa a cada período, e o controle acha caminho até cada lugar")
	else:
		print("elos: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)
