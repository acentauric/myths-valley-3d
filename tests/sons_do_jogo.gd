extends "res://tests/suite/caso.gd"
## NENHUM SOM QUE O JOGO PEDE FICA SEM ARQUIVO, NENHUM ARQUIVO FICA SEM DONO, E AS PORTAS SOAM.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste sons_do_jogo
##
## Do playtest da Build 9B: "adicione o efeito sonoro de marretada na pedra e os demais faltantes".
## O defeito tinha duas caras, e as duas voltam sempre que alguém escreve um som novo:
##
##   * O CÓDIGO PEDE O QUE NÃO EXISTE. A mochila chamava `Audio.efeito("menu_negado")` e a pasta
##     nunca teve o arquivo: um aviso uma vez e silêncio para sempre. A tabela do golpe (`Recursos3D`)
##     esperava `marretada_pedra`, `foice_capim`, `catar_ostra`, `galho_quebra`, `pedra_quebra`.
##   * O ARQUIVO EXISTE E NINGUÉM O TOCA. `porta_fechar.mp3` e `picareta.mp3` passaram a Build 9B
##     órfãos, e as portas das casas e da igreja abriam em silêncio.
##
## Perguntas:
##
##   1. TODO `Audio.efeito("nome")` ESCRITO NOS SCRIPTS (e `previa_efeito`, `testar_efeito_menu`)
##      resolve para um arquivo de `assets/audio/efeitos` (depois dos apelidos de interface). Os nomes
##      montados em tempo de execução (`"passo_" + chão`) não entram: têm o portão deles.
##   2. TODO ARQUIVO da pasta tem dono: um script ou um JSON o cita, ou ele é de uma família montada
##      em tempo de execução (passos, corrida, variantes), ou está em `ORFAOS_ACEITOS`, com a razão.
##   3. A TABELA DO GOLPE ESTÁ COMPLETA: `Recursos3D.sons_que_faltam()` é vazia, e a picareta na pedra
##      toca `marretada_pedra` e o último golpe `pedra_quebra`, a foice `foice_capim`, a mão na ostra
##      `catar_ostra` e no galho seco `galho_quebra` — os nomes dos sons novos, e não os de reserva.
##   4. OS SONS NOVOS TÊM O TAMANHO QUE O JOGO ESPERA: de 0,5 a 2,5 s (os sussurros e o assobio, até
##      4,2 s), e audíveis (não são silêncio).
##   5. NO VALE, AS PORTAS SOAM: o `Interiores` anuncia `entrou`, e `porta_abrir` toca; anuncia `saiu`, e
##      `porta_fechar` toca; cada sinal tem UMA ligação (o som não sai dobrado).
##   6. O "NÃO PODE" DA MOCHILA (`menu_negado`) soa, pelo tocador de interface, e não corta o som de
##      efeito que acabou de tocar.
##   7. TROCAR O ITEM DA MÃO SOA (#223): o clique curto de `barra_de_mao.trocar_a_mao` toca pelo tocador
##      de interface, com o tom variando, e fica mudo ao reescolher a vaga que já está na mão; os três
##      gestos (tecla 1 a 0, roda, clique) passam por ele, o volume de Efeitos o governa, e arar, regar e
##      plantar na lavoura pedem os seus efeitos (`arar`, `regar`, `plantar`).
##
## FALSIFICAÇÃO: apague `assets/audio/efeitos/menu_negado.mp3` (ou escreva `Audio.efeito("nao_existe")`
## num script): a pergunta 1 reprova; tire `_ligar_as_portas` do `ambiente_vale.gd`: a 5 reprova; tire o
## `Audio.efeito` de `trocar_a_mao` (ou volte a roda para `Inventario.selecionar`): a 7 reprova.

const PASTA := "res://assets/audio/efeitos/"
## Os apelidos e os sons de interface vêm do próprio Audio, para este portão não os copiar.
const SONS_NOVOS := {
	"marretada_pedra": [0.5, 2.5], "pedra_quebra": [0.5, 2.5], "foice_capim": [0.5, 2.5],
	"catar_ostra": [0.5, 2.5], "galho_quebra": [0.5, 2.5], "menu_negado": [0.5, 2.5],
	"fantasma_avanco": [0.5, 2.5], "mapa_doido": [0.5, 2.5],
	"fantasma_sussurro": [0.5, 4.2], "curupira_assobio": [0.5, 4.2],
}
## Arquivos que nenhum script cita ainda, e a razão: a fatia que os dispara é outra.
const ORFAOS_ACEITOS := {
	"fantasma_sussurro": "o susto do vulto da mata (fatia dos sustos) o dispara",
	"fantasma_avanco": "o susto do vulto da mata (fatia dos sustos) o dispara",
	"curupira_assobio": "o rastro do Curupira (fatia dos sustos) o dispara",
	"mapa_doido": "o mapa que enlouquece (fatia dos sustos) o dispara",
}
## Famílias de nome montado em tempo de execução: o prefixo ou o sufixo basta.
const FAMILIAS := ["passo_", "corrida_"]
const SUFIXOS := ["_madeira", "_v2"]

var falhas := 0
var audio


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		falhas += 1
		push_error("SONS_DO_JOGO_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)


func _run() -> void:
	audio = root.get_node("/root/Audio")
	_nomes_pedidos_existem()
	_arquivos_tem_dono()
	_sons_novos_tem_o_tamanho()
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "o vale não carregou")
	await _frames(6)
	await _mundo_pronto()
	await _frames(6)
	_tabela_do_golpe_completa()
	_as_portas_soam()
	_o_nao_pode_da_mochila()
	_trocar_a_mao_soa()
	if falhas == 0:
		print("SONS_DO_JOGO_OK: todo som pedido tem arquivo, todo arquivo tem dono, a tabela do golpe usa os sons novos, as portas, o 'não pode' e a troca do item na mão soam")
	quit(0 if falhas == 0 else 1)


# --- 1. O QUE O CÓDIGO PEDE EXISTE ------------------------------------------------

func _nomes_pedidos_existem() -> void:
	var regex := RegEx.create_from_string("(?:Audio|audio)\\.(?:efeito|previa_efeito|testar_efeito_menu)\\(\\s*\"([A-Za-z0-9_]+)\"")
	var pedidos := {}
	for caminho in _arquivos("res://scripts", ".gd"):
		var texto := FileAccess.get_file_as_string(caminho)
		for achado in regex.search_all(texto):
			var nome: String = achado.get_string(1)
			if not pedidos.has(nome):
				pedidos[nome] = []
			(pedidos[nome] as Array).append(caminho.trim_prefix("res://scripts/"))
	_conferir(pedidos.size() > 10, "a varredura achou só %d nomes de efeito nos scripts: o padrão da busca quebrou" % pedidos.size())
	# Nas duas escolhas de "Som dos botões" de AJUSTAR (a variante _madeira só existe para alguns).
	var opcao_do_jogador: int = audio.efeitos_menu_opcao
	for opcao in [1, 2]:
		audio.efeitos_menu_opcao = opcao
		for nome: String in pedidos:
			_conferir(audio.arquivo_do_efeito(nome) != "", "o código pede Audio.efeito(\"%s\") (%s) e não há arquivo para ele em %s (Som dos botões %d)" % [nome, ", ".join(PackedStringArray(pedidos[nome])), PASTA, opcao])
	audio.efeitos_menu_opcao = opcao_do_jogador
	print("  nomes de efeito pedidos nos scripts: %d" % pedidos.size())


# --- 2. O QUE EXISTE TEM DONO ------------------------------------------------------

func _arquivos_tem_dono() -> void:
	var texto := ""
	for caminho in _arquivos("res://scripts", ".gd") + _arquivos("res://data", ".json"):
		texto += FileAccess.get_file_as_string(caminho) + "\n"
	var sem_dono: Array[String] = []
	for arquivo in DirAccess.get_files_at(PASTA):
		if not arquivo.ends_with(".mp3"):
			continue
		var nome := arquivo.get_basename()
		var da_familia := false
		for prefixo in FAMILIAS:
			da_familia = da_familia or nome.begins_with(prefixo)
		for sufixo in SUFIXOS:
			da_familia = da_familia or nome.ends_with(sufixo)
		if da_familia or ORFAOS_ACEITOS.has(nome):
			continue
		if texto.contains("\"" + nome + "\"") or texto.contains(nome + ".mp3"):
			continue
		sem_dono.append(nome)
	_conferir(sem_dono.is_empty(), "arquivos de efeito que ninguém toca (ligue-os, ou declare o dono em ORFAOS_ACEITOS): %s" % ", ".join(PackedStringArray(sem_dono)))


# --- 4. O TAMANHO DOS SONS NOVOS ---------------------------------------------------

func _sons_novos_tem_o_tamanho() -> void:
	for nome: String in SONS_NOVOS:
		var caminho := PASTA + nome + ".mp3"
		_conferir(ResourceLoader.exists(caminho), "o som novo '%s' não existe (ou o Godot não o importou)" % nome)
		if not ResourceLoader.exists(caminho):
			continue
		var fluxo := load(caminho) as AudioStream
		_conferir(fluxo != null, "o som novo '%s' não carrega como áudio" % nome)
		if fluxo == null:
			continue
		var faixa: Array = SONS_NOVOS[nome]
		var duracao := fluxo.get_length()
		_conferir(duracao >= float(faixa[0]) and duracao <= float(faixa[1]), "'%s' dura %.2f s, fora de %.1f a %.1f s" % [nome, duracao, faixa[0], faixa[1]])
		# Um mp3 de silêncio dura o que dura e pesa quase nada: 128 kb/s deixam 16 KB por segundo.
		var bytes: int = (fluxo as AudioStreamMP3).data.size() if fluxo is AudioStreamMP3 else 0
		_conferir(bytes >= int(duracao * 8000.0), "'%s' pesa %d bytes para %.2f s: é silêncio, ou um arquivo vazio" % [nome, bytes, duracao])


# --- 3. A TABELA DO GOLPE USA OS SONS NOVOS -----------------------------------------

func _tabela_do_golpe_completa() -> void:
	var recursos := current_scene.get_node_or_null("Recursos3D")
	_conferir(recursos != null, "o vale não montou o Recursos3D")
	if recursos == null:
		return
	var faltam: Array = recursos.sons_que_faltam()
	_conferir(faltam.is_empty(), "a tabela do golpe ainda espera arquivos que não existem: %s" % ", ".join(PackedStringArray(faltam)))
	var casos := [
		["a picareta na pedra", {"ferramenta": "picareta", "rende": "pedra"}, "marretada_pedra", "pedra_quebra"],
		["a foice no capim", {"ferramenta": "foice", "rende": "capim"}, "foice_capim", ""],
		["a mão na ostra", {"ferramenta": "", "rende": "ostra"}, "catar_ostra", ""],
		["a mão no galho seco", {"ferramenta": "", "rende": "lenha"}, "galho_quebra", ""],
	]
	for caso in casos:
		var golpe: String = recursos.som_do_golpe(caso[1], false)
		_conferir(golpe == caso[2], "%s toca '%s', e devia tocar '%s'" % [caso[0], golpe, caso[2]])
		var fim: String = recursos.som_do_golpe(caso[1], true)
		_conferir(fim == caso[3], "o último golpe de %s toca '%s', e devia tocar '%s'" % [caso[0], fim, caso[3]])


# --- 5. AS PORTAS ------------------------------------------------------------------

func _as_portas_soam() -> void:
	var vale := current_scene
	var interiores := vale.get_node_or_null("Interiores")
	var ambiente = vale.get("ambiente")
	_conferir(interiores != null and ambiente != null, "o vale não montou o Interiores e o ambiente sonoro")
	if interiores == null or ambiente == null:
		return
	for sinal in ["entrou", "saiu"]:
		var meus := 0
		for ligacao in interiores.get_signal_connection_list(sinal):
			if (ligacao["callable"] as Callable).get_object() == ambiente:
				meus += 1
		_conferir(meus == 1, "o sinal '%s' do Interiores tem %d ligação(ões) com o ambiente sonoro (devia ter 1)" % [sinal, meus])
	audio._efeitos.stream = null
	interiores.entrou.emit("igreja")
	_conferir(_tocando(audio._efeitos) == "porta_abrir", "ao entrar na igreja o tocador de efeitos tem '%s', e devia ter 'porta_abrir'" % _tocando(audio._efeitos))
	audio._efeitos.stream = null
	interiores.saiu.emit("igreja")
	_conferir(_tocando(audio._efeitos) == "porta_fechar", "ao sair da igreja o tocador de efeitos tem '%s', e devia ter 'porta_fechar'" % _tocando(audio._efeitos))


# --- 6. O "NÃO PODE" DA MOCHILA -----------------------------------------------------

func _o_nao_pode_da_mochila() -> void:
	audio._efeitos.stream = null
	audio._interface.stream = null
	audio.efeito("porta_abrir")
	audio.efeito("menu_negado")
	_conferir(_tocando(audio._interface).begins_with("menu_negado"), "o 'não pode' da mochila tocou '%s' no tocador de interface" % _tocando(audio._interface))
	_conferir(_tocando(audio._efeitos) == "porta_abrir", "o 'não pode' cortou o efeito que soava (tocador de efeitos: '%s')" % _tocando(audio._efeitos))


# --- 7. TROCAR O ITEM DA MÃO --------------------------------------------------------

func _trocar_a_mao_soa() -> void:
	var barra = load("res://scripts/prototipo_3d/barra_de_mao.gd")
	var inventario = root.get_node("/root/Inventario")
	var antes: int = inventario.selecionado
	inventario.selecionar(inventario.MAO_LIVRE)
	audio._interface.stream = null
	audio.ultimo_efeito = ""
	audio._ultimo_movimento_ms = -1000
	# Escolher uma vaga nova toca o clique, pelo tocador de interface.
	barra.trocar_a_mao(2, false)
	_conferir(inventario.selecionado == 2, "trocar_a_mao(2) não pôs a vaga 3 na mão")
	_conferir(audio.ultimo_efeito == "menu_mover" and audio._interface.stream != null, "trocar o item da mão não tocou o clique (último efeito: '%s')" % audio.ultimo_efeito)
	# Reescolher a vaga que já está na mão, sem alternar, fica em silêncio.
	audio._interface.stream = null
	audio.ultimo_efeito = ""
	barra.trocar_a_mao(2, false)
	_conferir(audio.ultimo_efeito == "" and audio._interface.stream == null, "reescolher a vaga que já estava na mão tocou o clique")
	# O mesmo número, alternando, guarda o item (mão livre): é uma troca, e soa.
	barra.trocar_a_mao(2, true)
	_conferir(inventario.selecionado == inventario.MAO_LIVRE and audio.ultimo_efeito == "menu_mover", "guardar o item da mão (mesmo número) não tocou o clique")
	# O Inventario puro (carregar o jogo, portões) não estala.
	audio.ultimo_efeito = ""
	inventario.selecionar(4)
	_conferir(audio.ultimo_efeito == "", "Inventario.selecionar sozinho tocou som: só o gesto do jogador toca")
	# O tom varia: dez trocas não saem todas com o mesmo.
	var tons := {}
	audio._ultimo_movimento_ms = -1000
	for i in 10:
		audio.efeito("mao_troca", 0.06)
		tons[snappedf(audio._interface.pitch_scale, 0.0001)] = true
		audio._interface.stop()
		audio._ultimo_movimento_ms = -1000
	_conferir(tons.size() > 1, "o clique da troca sai sempre no mesmo tom")
	for tom: float in tons:
		_conferir(absf(tom - 1.0) <= 0.0601, "o tom da troca (%.3f) passa da variação de 6%%" % tom)
	# O volume de Efeitos governa o clique (o mudo é do barramento geral, e vale para tudo).
	var volume_antes: float = audio.volume_efeitos
	audio.definir_volume_efeitos(0.8)
	var db_alto: float = audio._interface.volume_db
	audio.definir_volume_efeitos(0.2)
	var db_baixo: float = audio._interface.volume_db
	audio.definir_volume_efeitos(volume_antes)
	_conferir(db_baixo < db_alto, "o volume de Efeitos não muda o clique da troca (%.1f dB contra %.1f dB)" % [db_baixo, db_alto])
	# Os três gestos passam por trocar_a_mao, e nenhum chama o Inventario direto.
	var barra_fonte := FileAccess.get_file_as_string("res://scripts/prototipo_3d/barra_de_mao.gd")
	var jogador_fonte := FileAccess.get_file_as_string("res://scripts/prototipo_3d/player_controller.gd")
	_conferir(barra_fonte.count("trocar_a_mao(") >= 4, "a tecla e o clique da barra não chamam trocar_a_mao")
	_conferir(jogador_fonte.contains("trocar_a_mao("), "a roda do mouse não chama trocar_a_mao")
	_conferir(not jogador_fonte.contains("Inventario.selecionar("), "a roda do mouse voltou a chamar Inventario.selecionar direto (sem som)")
	for gesto in ["Inventario.alternar(i)", "Inventario.alternar(qual)", "Inventario.selecionar(qual)"]:
		_conferir(not barra_fonte.contains(gesto), "a barra de mão chama '%s' direto (sem som)" % gesto)
	# Lavoura: arar, regar e plantar pedem os seus efeitos.
	var lavoura := FileAccess.get_file_as_string("res://scripts/prototipo_3d/lavoura_vale.gd")
	for som in ["arar", "regar", "plantar"]:
		_conferir(lavoura.contains("Audio.efeito(\"%s\")" % som), "a lavoura não pede o efeito '%s'" % som)
		_conferir(audio.arquivo_do_efeito(som) != "", "o efeito '%s' da lavoura não tem arquivo" % som)
	inventario.selecionar(antes)


# --- apoio ---------------------------------------------------------------------------

## O nome (sem pasta nem extensão) do que o tocador tem carregado, ou "".
func _tocando(tocador: AudioStreamPlayer) -> String:
	if tocador.stream == null:
		return ""
	return String(tocador.stream.resource_path).get_file().get_basename()


## Todo arquivo `ext` embaixo de `pasta`, de res://.
func _arquivos(pasta: String, ext: String) -> Array[String]:
	var achados: Array[String] = []
	for arquivo in DirAccess.get_files_at(pasta):
		if arquivo.ends_with(ext):
			achados.append(pasta.path_join(arquivo))
	for sub in DirAccess.get_directories_at(pasta):
		achados.append_array(_arquivos(pasta.path_join(sub), ext))
	return achados


func _frames(quantos: int) -> void:
	for i in range(quantos):
		await process_frame


func _mundo_pronto() -> void:
	for i in range(3000):
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
