extends SceneTree
## NENHUM SOM QUE O JOGO PEDE FICA SEM ARQUIVO, NENHUM ARQUIVO FICA SEM DONO, E AS PORTAS SOAM.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/sons_do_jogo.gd
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
##
## FALSIFICAÇÃO: apague `assets/audio/efeitos/menu_negado.mp3` (ou escreva `Audio.efeito("nao_existe")`
## num script): a pergunta 1 reprova; tire `_ligar_as_portas` do `ambiente_vale.gd`: a 5 reprova.

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
	if falhas == 0:
		print("SONS_DO_JOGO_OK: todo som pedido tem arquivo, todo arquivo tem dono, a tabela do golpe usa os sons novos, as portas e o 'não pode' soam")
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
