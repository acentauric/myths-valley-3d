extends SceneTree
## Confere AS VOZES E OS QUATRO IDIOMAS DOS MORADORES (data/npcs_3d.json): toda fala nos quatro idiomas
## do menu e toda fala de quem tem voz com a voz gerada, importada e tocando pela fila de falas.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/vozes_dos_moradores.gd
##     ... -- --falsificar-vozes        (o portão TEM de reprovar: ver `_falsificar_o_arquivo` e `_falsificar_no_vale`)
##
## "Vamos gerar nas 4 linguagens os textos, mas o áudio por enquanto apenas em português" (playtest da Build 9B,
## 06/10/2026). O jogo tem quatro idiomas no menu (`IdiomaMenu.SUFIXOS`: "", "_en", "_es", "_zh"), e a
## fala do morador mora em `texto`, `texto_en`, `texto_es` e `texto_zh` no mesmo objeto. A voz é só em português
## (ElevenLabs, `tools/elevenlabs/gerar-falas-moradores.ps1`) e acompanha o balão em qualquer idioma. Seis perguntas:
##
##   1. TODA FALA DE QUEM FALA — o guia, os oito antigos, o Quirino e os catorze novos; saudação, conversa, as de
##      noite, as do Pedro de depois do tutorial e o aviso do entardecer — TEM OS QUATRO TEXTOS, nenhum vazio e
##      nenhum cópia do português (o chinês também não é cópia do inglês nem do espanhol).
##   2. O CHINÊS É CHINÊS: ideogramas e nenhuma letra latina solta (português ou inglês que escapou na tradução), de
##      4 a 140 caracteres, sem repetir uma fala de outro; a saudação em chinês cabe inteira no balão curto, e a
##      fila dá ao chinês tempo de leitura de chinês (`FilaDeFalas.duracao`: um ideograma vale umas duas letras e meia).
##   3. O MOTOR LÊ O QUE ESTÁ ESCRITO (`IdiomaMenu.campo_no_idioma`), nos quatro idiomas, e a fala que ainda não
##      tem `texto_zh` cai no inglês, não no português.
##   4. CADA UM TEM A SUA VOZ: Pedro, os oito antigos e os catorze novos têm `voz` ({id, nome, modelo}) e nenhum
##      id de voz se repete entre quem fala; quem fala só no balão (o Quirino) não tem voz nem áudio.
##   5. TODA FALA DE QUEM TEM VOZ TEM O ÁUDIO: o arquivo existe em assets/audio/vozes, tem o `.import`, o Godot o
##      carrega, e ele dura o que o texto pede (nem cortado, nem com silêncio demais); nenhum nome se repete.
##      A ÚNICA DÍVIDA ACEITA é a declarada: o morador com `voz_pendente` (e a razão escrita, como o `mudo_motivo`)
##      pode ter áudio que falta — o teto de crédito da chave do ElevenLabs acabou no meio do lote de 06/10/2026 —,
##      e o portão reprova a marca que ficou depois de o último áudio existir ("tire o `voz_pendente`").
##   6. NO VALE A VOZ TOCA PELA FILA: o cumprimento e o E de um morador novo — de dia (o padre e o mercador) e de
##      noite (o guarda) — e o E do Pedro depois do tutorial chegam à fila com o áudio da fala escolhida, a voz
##      toca no morador, a fila segura a vez por pelo menos a duração dela, e a voz cala quando a fala passa. Com o menu em chinês o balão traz o `texto_zh`, e sem ele o
##      `texto_en`; a voz segue em português.

const RelogioDeJogo = preload("res://tests/fixtures/relogio_de_jogo.gd")
const FilaDeFalas = preload("res://scripts/prototipo_3d/fila_de_falas.gd")

const ARQUIVO := "res://data/npcs_3d.json"
const PASTA_VOZES := "res://assets/audio/vozes/"
const PREFERENCIAS := "user://preferencias_visuais.cfg"
## As listas de fala do arquivo. O `anoitecer` do Pedro é um objeto só e entra à parte (`_entradas`).
const LISTAS := ["saudacoes", "falas", "saudacoes_noite", "falas_noite", "falas_depois"]
## Os catorze moradores que ganharam voz e texto em chinês juntos.
const NOVOS := ["padre", "sacristao", "beata", "mercador", "guarda", "pescador", "marisqueira", "lavadeira",
	"rendeira", "quituteira", "carpinteiro", "menino", "menina", "mestre_saveiro"]
## Quem fala só no balão: a voz dele é decisão de crédito (e não estava entre os catorze).
const SEM_VOZ := ["quirino"]
## O chinês cabe no balão: de 4 a 140 caracteres; a saudação, no máximo o que o balão curto leva.
const ZH_TAMANHO := Vector2i(4, 140)
const ZH_SAUDACAO_MAXIMO := 60
## Quem lê chinês lê, no máximo, uns 8 ideogramas por segundo: a fila tem de dar ao balão ao menos esse tempo.
const ZH_POR_SEGUNDO := 8.0
## Quantos segundos de voz uma fala dura: nem vazia, nem uma narração.
const VOZ_SEGUNDOS := Vector2(1.0, 24.0)
## Letras do texto por segundo de voz. Medido nas vozes do projeto: de 8 a 18. A janela larga pega o áudio
## cortado no meio (letras demais por segundo) e o cheio de silêncio ou lento demais (letras de menos).
const LETRAS_POR_SEGUNDO := Vector2(5.0, 30.0)
const IDIOMA_ZH := 3

var falhas := 0
var falsificar := false
var relogio: Node
var vale
var fila
var jogador
var tecla
var dia
var IdiomaMenu
## O arquivo como está em disco, por id (as expectativas do vale saem DELE, e não do morador vivo: a
## falsificação mexe só no vivo).
var _do_arquivo := {}
## Cada fala que ganhou a vez na fila: {falante, classe, texto, voz, segundos}.
var _comecaram: Array = []
var _falantes := 0
var _audios_conferidos := 0
## Falas cujo áudio falta e que o morador declarou (`voz_pendente`).
var _audios_pendentes := 0
var _vozes_no_vale := 0
## O que havia em `user://preferencias_visuais.cfg` antes do portão (bytes), para devolver.
var _reserva := PackedByteArray()
var _havia_arquivo := false


func _initialize() -> void:
	falsificar = OS.get_cmdline_user_args().has("--falsificar-vozes")
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("VOZES_DOS_MORADORES_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	var arquivo = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO))
	_conferir(arquivo is Dictionary and (arquivo.get("moradores", []) as Array).size() >= NOVOS.size(),
		"o npcs_3d.json não abre ou não tem os moradores")
	if not (arquivo is Dictionary):
		_fechar()
		return
	_reservar_preferencias()
	_falsificar_o_arquivo(arquivo)
	for pessoa in [arquivo["guia"]] + (arquivo["moradores"] as Array):
		_do_arquivo[str((pessoa as Dictionary).get("id", ""))] = pessoa

	# --- 1, 2, 4 e 5. O ARQUIVO -----------------------------------------------------------------
	_conferir_o_arquivo(arquivo)

	# --- 6. NO VALE -------------------------------------------------------------------------------
	root.get_node("/root/Estilo").modo = "tripo"
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	relogio = RelogioDeJogo.new()
	root.add_child(relogio)
	await _quadros(4)
	await _mundo_pronto()
	await _quadros(8)
	relogio.ficar_lento()
	vale = current_scene
	# O ACEITE É AUTOMÁTICO AQUI (08/10): este portão abre filas pelo E e segue; a tela de aceite
	# pausaria o vale no meio da medida (a tela tem portão próprio, tests/missao_a_vista.gd).
	if vale.get("aceite") != null:
		vale.aceite.automatico = true
	fila = vale.get("fila_de_falas")
	jogador = vale.player
	tecla = vale.get("tecla_dos_moradores")
	dia = root.get_node("/root/Dia")
	_conferir(fila != null and tecla != null and jogador != null,
		"o vale não tem a fila de falas, o E dos moradores ou o jogador")
	if fila == null or tecla == null or jogador == null:
		_fechar()
		return
	# Depois de o vale subir: o `IdiomaMenu` cita autoload, e `load` antes dele o quebraria no cache.
	IdiomaMenu = load("res://scripts/prototipo_3d/idioma_menu.gd")
	dia.pausado = true
	var por_id := {}
	for morador in vale.moradores:
		por_id[str(morador.dados.get("id", ""))] = morador
	var padre = por_id.get("padre")
	var mercador = por_id.get("mercador")
	var guarda = por_id.get("guarda")
	var pedro = vale.get("pedro")
	_conferir(padre != null and mercador != null and guarda != null and pedro != null,
		"o vale não tem o padre, o mercador, o guarda ou o Pedro")
	if padre == null or mercador == null or guarda == null or pedro == null:
		_fechar()
		return
	_conferir_os_idiomas_no_motor(arquivo, padre)
	_falsificar_no_vale(padre)
	fila.comecou.connect(func(fala: Dictionary) -> void:
		_comecaram.append({"falante": fala.get("falante"), "classe": int(fala.get("classe", -1)),
			"texto": str(fala.get("texto", "")), "voz": fala.get("voz"), "segundos": float(fala.get("segundos", 0.0))}))

	await _voz_de_um_morador(padre, true)
	await _voz_de_um_morador(mercador, false)
	await _voz_da_noite(guarda)
	await _voz_do_pedro(pedro)
	_fechar()


# --- 1, 2, 4 e 5: O ARQUIVO ---------------------------------------------------------------------------

func _conferir_o_arquivo(arquivo: Dictionary) -> void:
	var vozes := {}
	var audios := {}
	var chineses := {}
	for pessoa in [arquivo["guia"]] + (arquivo["moradores"] as Array):
		var p: Dictionary = pessoa
		var id := str(p.get("id", "?"))
		if bool(p.get("mudo", false)):
			continue
		_falantes += 1
		var voz: Dictionary = p.get("voz", {})
		var com_voz := not voz.is_empty()
		var pendente := str(p.get("voz_pendente", ""))
		_conferir(pendente == "" or (com_voz and pendente.length() > 20),
			"'%s': `voz_pendente` precisa da razão escrita e só vale para quem tem voz" % id)
		var faltando := 0
		_conferir(com_voz or SEM_VOZ.has(id), "'%s' fala e não tem voz (`voz`), e só %s fala no balão" % [id, str(SEM_VOZ)])
		_conferir(not (com_voz and SEM_VOZ.has(id)), "'%s' devia falar só no balão e tem voz" % id)
		if com_voz:
			var voz_id := str(voz.get("id", ""))
			_conferir(voz_id.length() >= 15 and str(voz.get("nome", "")) != "" and str(voz.get("modelo", "")) == "eleven_v3",
				"'%s': a voz precisa de {id, nome, modelo: eleven_v3} (tem %s)" % [id, str(voz)])
			_conferir(not vozes.has(voz_id), "'%s' tem a MESMA voz de '%s' (%s): cada um tem a sua" % [id, str(vozes.get(voz_id, "")), str(voz.get("nome", ""))])
			vozes[voz_id] = id
		for entrada in _entradas(p):
			_conferir_os_idiomas(str(entrada["onde"]), entrada["fala"], chineses)
			if _conferir_o_audio(str(entrada["onde"]), entrada["fala"], com_voz, audios, pendente != ""):
				faltando += 1
		_audios_pendentes += faltando
		_conferir(pendente == "" or faltando > 0,
			"'%s' já tem todos os áudios e ainda diz que a voz está pendente: tire o `voz_pendente` do npcs_3d.json" % id)
	for id in NOVOS:
		_conferir(_tem_voz(arquivo, id), "o morador '%s' devia ter ganhado voz" % id)
	_conferir(_falantes >= NOVOS.size() + 9, "só %d falante(s) no arquivo" % _falantes)
	# Com o lote todo são 210 (menos os que esperam crédito, `voz_pendente`): abaixo de 100 a varredura não está pegando.
	_conferir(_audios_conferidos >= 100, "só %d áudio(s) conferido(s): a varredura não está pegando" % _audios_conferidos)


func _tem_voz(arquivo: Dictionary, id: String) -> bool:
	for m in arquivo["moradores"]:
		if str((m as Dictionary).get("id", "")) == id:
			return not (m as Dictionary).get("voz", {}).is_empty()
	return false


## Toda fala de quem fala: saudações, conversa, as de noite, as do Pedro de depois do tutorial e o aviso do
## entardecer. Devolve [{onde, fala, lista}].
func _entradas(p: Dictionary) -> Array:
	var id := str(p.get("id", "?"))
	var saida: Array = []
	for lista in LISTAS:
		var itens: Array = p.get(lista, [])
		for i in itens.size():
			saida.append({"onde": "'%s'.%s[%d]" % [id, lista, i], "fala": itens[i], "lista": lista})
	if p.has("anoitecer"):
		saida.append({"onde": "'%s'.anoitecer" % id, "fala": p["anoitecer"], "lista": "anoitecer"})
	return saida


## OS QUATRO TEXTOS: nenhum vazio, nenhum cópia do português, e o chinês é chinês.
func _conferir_os_idiomas(onde: String, fala, chineses: Dictionary) -> void:
	if not (fala is Dictionary):
		_conferir(false, "%s não é um objeto" % onde)
		return
	var pt := str(fala.get("texto", ""))
	_conferir(pt != "", "%s sem o texto em português" % onde)
	for chave in ["texto_en", "texto_es", "texto_zh"]:
		var t := str(fala.get(chave, ""))
		_conferir(t != "", "%s sem o campo %s" % [onde, chave])
		_conferir(t == "" or t != pt, "%s: %s é cópia do português" % [onde, chave])
	var zh := str(fala.get("texto_zh", ""))
	if zh == "":
		return
	_conferir(zh != str(fala.get("texto_en", "")) and zh != str(fala.get("texto_es", "")),
		"%s: texto_zh é cópia do inglês ou do espanhol" % onde)
	var ideogramas := 0
	var latinas := 0
	for i in zh.length():
		var c := zh.unicode_at(i)
		if c >= 0x4E00 and c <= 0x9FFF:
			ideogramas += 1
		elif (c >= 0x41 and c <= 0x5A) or (c >= 0x61 and c <= 0x7A):
			latinas += 1
	_conferir(ideogramas >= 3 and latinas == 0,
		"%s: o texto_zh tem %d ideograma(s) e %d letra(s) latina(s): português ou inglês que escapou na tradução ('%s')" % [onde, ideogramas, latinas, zh.left(24)])
	_conferir(zh.length() >= ZH_TAMANHO.x and zh.length() <= ZH_TAMANHO.y,
		"%s: o texto_zh tem %d caracteres, e devia ter de %d a %d" % [onde, zh.length(), ZH_TAMANHO.x, ZH_TAMANHO.y])
	_conferir(not chineses.has(zh), "%s repete o texto_zh de %s" % [onde, str(chineses.get(zh, ""))])
	chineses[zh] = onde
	# O chinês ganha tempo de leitura de chinês (`FilaDeFalas.duracao`): o balão não some antes de o jogador ler.
	var tempo := FilaDeFalas.duracao(zh)
	_conferir(tempo + 0.001 >= float(zh.length()) / ZH_POR_SEGUNDO,
		"%s: a fila dá %.1f s de leitura a %d caracteres em chinês, e quem lê leva mais que isso" % [onde, tempo, zh.length()])


## O ÁUDIO DE UMA FALA: quem tem voz tem o arquivo, o .import, o Godot o carrega e ele dura o que o texto pede.
## Devolve true quando o arquivo falta e o morador declarou a pendência (`pendente`).
func _conferir_o_audio(onde: String, fala, com_voz: bool, audios: Dictionary, pendente: bool) -> bool:
	if not (fala is Dictionary):
		return false
	var audio := str(fala.get("audio", ""))
	if not com_voz:
		_conferir(audio == "", "%s tem o áudio '%s', e quem fala não tem voz" % [onde, audio])
		return false
	_conferir(audio != "", "%s sem `audio`: quem tem voz tem a voz de cada fala (tools/elevenlabs/gerar-falas-moradores.ps1)" % onde)
	if audio == "":
		return false
	_conferir(not audios.has(audio), "%s repete o áudio '%s' de %s" % [onde, audio, str(audios.get(audio, ""))])
	audios[audio] = onde
	var caminho := PASTA_VOZES + audio + ".mp3"
	if not FileAccess.file_exists(caminho):
		_conferir(pendente, "%s aponta o áudio '%s', que não existe em assets/audio/vozes (e o morador não declarou `voz_pendente`)" % [onde, audio])
		return pendente
	_conferir(FileAccess.file_exists(caminho + ".import"), "%s: o áudio '%s' não tem o .import (rode o import do Godot)" % [onde, audio])
	_conferir(ResourceLoader.exists(caminho), "%s: o Godot não importou o áudio '%s'" % [onde, audio])
	if not ResourceLoader.exists(caminho):
		return false
	var fluxo = load(caminho)
	_conferir(fluxo is AudioStream, "%s: o áudio '%s' não é um AudioStream" % [onde, audio])
	if not (fluxo is AudioStream):
		return false
	_audios_conferidos += 1
	var segundos := (fluxo as AudioStream).get_length()
	_conferir(segundos >= VOZ_SEGUNDOS.x and segundos <= VOZ_SEGUNDOS.y,
		"%s: o áudio '%s' dura %.1f s, e uma fala dura de %.0f a %.0f s" % [onde, audio, segundos, VOZ_SEGUNDOS.x, VOZ_SEGUNDOS.y])
	var letras := float(str(fala.get("texto", "")).length())
	var taxa := letras / maxf(segundos, 0.01)
	_conferir(taxa >= LETRAS_POR_SEGUNDO.x and taxa <= LETRAS_POR_SEGUNDO.y,
		"%s: o áudio '%s' dura %.1f s para %d letras (%.1f letras por segundo): voz cortada, ou com silêncio demais" % [onde, audio, segundos, int(letras), taxa])
	return false


# --- 3: O MOTOR LÊ O QUE ESTÁ ESCRITO ------------------------------------------------------------------------

func _conferir_os_idiomas_no_motor(arquivo: Dictionary, referencia) -> void:
	var lidas := 0
	var zh_no_balao := 0
	for pessoa in [arquivo["guia"]] + (arquivo["moradores"] as Array):
		var p: Dictionary = pessoa
		if bool(p.get("mudo", false)):
			continue
		for entrada in _entradas(p):
			var fala: Dictionary = entrada["fala"]
			for indice in 4:
				var lida := str(IdiomaMenu.campo_no_idioma(fala, "texto", indice, ""))
				var escrita := str(fala.get(["texto", "texto_en", "texto_es", "texto_zh"][indice], ""))
				_conferir(lida != "" and lida == escrita,
					"%s: o idioma %d lê '%s' e está escrito '%s'" % [str(entrada["onde"]), indice, lida.left(24), escrita.left(24)])
				lidas += 1
			# Sem o texto_zh, o chinês cai no INGLÊS (e não no português); sem o inglês, no português.
			var sem_zh := fala.duplicate()
			sem_zh.erase("texto_zh")
			_conferir(str(IdiomaMenu.campo_no_idioma(sem_zh, "texto", IDIOMA_ZH, "")) == str(fala.get("texto_en", "")),
				"%s: sem o texto_zh o chinês devia cair no inglês" % str(entrada["onde"]))
			# A saudação em chinês sai INTEIRA no balão curto (`MoradorNPC.balao_curto`).
			if str(entrada["lista"]).begins_with("saudacoes"):
				var zh := str(fala.get("texto_zh", "")).strip_edges()
				_conferir(zh.length() <= ZH_SAUDACAO_MAXIMO and str(referencia.balao_curto(zh)) == zh,
					"%s: a saudação em chinês sai cortada no balão ('%s' -> '%s')" % [str(entrada["onde"]), zh, str(referencia.balao_curto(zh))])
				zh_no_balao += 1
	_conferir(lidas >= 213 * 4 and zh_no_balao >= NOVOS.size() * 4, "só %d fala(s) lida(s) e %d saudação(ões) em chinês no balão" % [lidas, zh_no_balao])


# --- 6: NO VALE, A VOZ TOCA PELA FILA --------------------------------------------------------------------------

## O cumprimento e o E de um morador novo: a voz da fala escolhida chega à fila, toca no morador e cala quando a
## fala passa. Com `idiomas`, também o balão em chinês e o inglês de quando falta o chinês.
func _voz_de_um_morador(m, idiomas: bool) -> void:
	var d: Dictionary = m.dados
	var id := str(d.get("id", "?"))
	var do_arquivo: Dictionary = _do_arquivo[id]
	var hora := _hora_na_rua(d)
	_conferir(hora >= 0.0, "'%s' não sai de casa em hora nenhuma da agenda" % id)
	if hora < 0.0:
		return
	dia.definir_hora(hora)
	m.ir_ao_posto_agora()
	await _quadros(2)
	_conferir(not m.esta_recolhido() and m.visible, "às %.1f h '%s' devia estar na rua" % [hora, id])
	_ao_lado_de(jogador, m)
	await _quadros(2)
	await _vez_livre()

	# O CUMPRIMENTO: a primeira saudação (de dia a rotação começa nela).
	m.set("_proxima_saudacao", 0)
	var antes := _comecaram.size()
	m.saudar()
	var cumprimentou: bool = await relogio.ate(func() -> bool: return _veio(m, antes, FilaDeFalas.Classe.PASSAGEM), 6.0)
	_conferir(cumprimentou, "'%s' não cumprimentou pela fila" % id)
	if cumprimentou:
		_conferir_a_voz(m, "o cumprimento de '%s'" % id, do_arquivo["saudacoes"][0], _ultimo(m, antes))
		await _calar(m, "o cumprimento de '%s'" % id)
	await _vez_livre()

	# A CONVERSA DO E: a primeira fala (de dia a rotação começa nela).
	m.set("_proxima_fala", 0)
	antes = _comecaram.size()
	tecla.usar(m)
	var conversou: bool = await relogio.ate(func() -> bool: return _veio(m, antes, FilaDeFalas.Classe.CONVERSA), 8.0)
	_conferir(conversou, "o E em '%s' não abriu uma conversa pela fila" % id)
	if conversou:
		var registro := _ultimo(m, antes)
		_conferir_a_voz(m, "o E em '%s'" % id, do_arquivo["falas"][0], registro)
		# A fila SEGURA a vez enquanto a voz toca: passados dois segundos, ainda é ele que fala e a voz segue.
		await relogio.esperar(2.0)
		_conferir(fila.falando(m) and m.voz.playing, "o E em '%s': dois segundos depois a fila já soltou a vez (%s) ou a voz parou (%s)" % [id, str(fila.falando(m)), str(m.voz.playing)])
		await _calar(m, "o E em '%s'" % id)
	await _vez_livre()
	if idiomas:
		await _idiomas_no_balao(m, do_arquivo)


## O MENU EM CHINÊS: o balão traz o `texto_zh` da fala (e da saudação), com a voz em português; sem o `texto_zh`,
## traz o `texto_en`. As preferências do jogador voltam ao que eram.
func _idiomas_no_balao(m, do_arquivo: Dictionary) -> void:
	var id := str(m.dados.get("id", "?"))
	_escrever_idioma(IDIOMA_ZH)
	m.set("_proxima_fala", 1)
	var antes := _comecaram.size()
	tecla.usar(m)
	var disse: bool = await relogio.ate(func() -> bool: return _veio(m, antes, FilaDeFalas.Classe.CONVERSA), 8.0)
	_conferir(disse, "com o menu em chinês o E em '%s' não abriu uma conversa" % id)
	if disse:
		var registro := _ultimo(m, antes)
		var zh := str(do_arquivo["falas"][1]["texto_zh"])
		_conferir(str(registro["texto"]) == zh, "com o menu em chinês o balão de '%s' trouxe '%s' e devia trazer '%s'" % [id, str(registro["texto"]).left(24), zh.left(24)])
		_conferir_a_voz(m, "o E em '%s', menu em chinês" % id, do_arquivo["falas"][1], registro)
		await _calar(m, "o E em chinês de '%s'" % id)
	await _vez_livre()

	# Sem o texto_zh numa fala, o balão cai no inglês.
	var guardado = m.dados["falas"][2]["texto_zh"]
	(m.dados["falas"][2] as Dictionary).erase("texto_zh")
	m.set("_proxima_fala", 2)
	antes = _comecaram.size()
	tecla.usar(m)
	var caiu: bool = await relogio.ate(func() -> bool: return _veio(m, antes, FilaDeFalas.Classe.CONVERSA), 8.0)
	_conferir(caiu, "sem o texto_zh o E em '%s' não abriu uma conversa" % id)
	if caiu:
		var en := str(do_arquivo["falas"][2]["texto_en"])
		_conferir(str(_ultimo(m, antes)["texto"]) == en, "sem o texto_zh o balão de '%s' trouxe '%s' e devia cair no inglês: '%s'" % [id, str(_ultimo(m, antes)["texto"]).left(24), en.left(24)])
		await _calar(m, "o E em inglês de '%s'" % id)
	m.dados["falas"][2]["texto_zh"] = guardado
	await _vez_livre()

	# A saudação em chinês: inteira no balão curto, com a voz da primeira saudação.
	m.set("_proxima_saudacao", 0)
	antes = _comecaram.size()
	m.saudar()
	var cumprimentou: bool = await relogio.ate(func() -> bool: return _veio(m, antes, FilaDeFalas.Classe.PASSAGEM), 6.0)
	_conferir(cumprimentou, "com o menu em chinês '%s' não cumprimentou" % id)
	if cumprimentou:
		var zh_saudacao := str(do_arquivo["saudacoes"][0]["texto_zh"])
		_conferir(str(_ultimo(m, antes)["texto"]) == m.balao_curto(zh_saudacao),
			"com o menu em chinês o cumprimento de '%s' foi '%s' e devia ser '%s'" % [id, str(_ultimo(m, antes)["texto"]), zh_saudacao])
		_conferir_a_voz(m, "o cumprimento de '%s', menu em chinês" % id, do_arquivo["saudacoes"][0], _ultimo(m, antes))
		await _calar(m, "o cumprimento em chinês de '%s'" % id)
	_escrever_idioma(0)
	await _vez_livre()


## DE NOITE o guarda cumprimenta e conversa com as falas de noite, e a voz delas toca (`saudacoes_noite` e
## `falas_noite`: a rotação recomeça sozinha pela primeira de noite, `FalasDosMoradores.recomeco`).
func _voz_da_noite(m) -> void:
	var d: Dictionary = m.dados
	var do_arquivo: Dictionary = _do_arquivo["guarda"]
	dia.definir_hora(21.0)
	_conferir(dia.periodo() == "noite", "às 21 h o período devia ser noite, e é '%s'" % dia.periodo())
	m.ir_ao_posto_agora()
	await _quadros(2)
	_conferir(not m.esta_recolhido() and m.visible and d.has("saudacoes_noite"), "às 21 h o guarda devia estar na rua, com as falas de noite")
	_ao_lado_de(jogador, m)
	await _quadros(2)
	await _vez_livre()
	# A primeira das de noite, que vêm DEPOIS das de dia na lista da noite. Chegar perto já o fez cumprimentar por
	# conta própria (a rotação andou), e a rotação que recomeça sozinha pela primeira de noite é do portão
	# falas_dos_moradores: aqui se põe a vez nela, como se faz com a de dia.
	m.set("_humor_da_saudacao", "noite")
	m.set("_proxima_saudacao", (d["saudacoes"] as Array).size())
	var antes := _comecaram.size()
	m.saudar()
	var cumprimentou: bool = await relogio.ate(func() -> bool: return _veio(m, antes, FilaDeFalas.Classe.PASSAGEM), 6.0)
	_conferir(cumprimentou, "de noite o guarda não cumprimentou pela fila")
	if cumprimentou:
		_conferir_a_voz(m, "o cumprimento de noite do guarda", do_arquivo["saudacoes_noite"][0], _ultimo(m, antes))
		await _calar(m, "o cumprimento de noite do guarda")
	await _vez_livre()
	m.set("_humor_da_conversa", "noite")
	m.set("_proxima_fala", (d["falas"] as Array).size())
	antes = _comecaram.size()
	tecla.usar(m)
	var conversou: bool = await relogio.ate(func() -> bool: return _veio(m, antes, FilaDeFalas.Classe.CONVERSA), 8.0)
	_conferir(conversou, "de noite o E no guarda não abriu uma conversa pela fila")
	if conversou:
		_conferir_a_voz(m, "o E de noite no guarda", do_arquivo["falas_noite"][0], _ultimo(m, antes))
		await _calar(m, "o E de noite no guarda")
	await _vez_livre()


## O E no Pedro DEPOIS DO TUTORIAL (`falas_depois`, `GuiaPedro._escolher_a_fala`): com a voz dele.
func _voz_do_pedro(pedro) -> void:
	var do_arquivo: Dictionary = _do_arquivo["pedro"]
	pedro.missao = pedro.MISSOES.size()
	pedro.set("_despedida_feita", true)
	_conferir(pedro.terminou_o_tutorial(), "não consegui dar a chegada do Pedro por acabada")
	# De dia, no posto dele (o guarda deixou o relógio nas 21 h, e à noite o Pedro está em casa).
	dia.definir_hora(10.0)
	pedro.ir_ao_posto_agora()
	await _quadros(2)
	_ao_lado_de(jogador, pedro)
	await _quadros(2)
	await _vez_livre()
	pedro.set("_proxima_fala_depois", 0)
	var antes := _comecaram.size()
	pedro.conversar()
	var falou: bool = await relogio.ate(func() -> bool: return _veio(pedro, antes, FilaDeFalas.Classe.CONVERSA), 8.0)
	_conferir(falou, "o E no Pedro depois do tutorial não abriu uma conversa pela fila")
	if falou:
		var registro := _ultimo(pedro, antes)
		_conferir(str(registro["texto"]) == str(do_arquivo["falas_depois"][0]["texto"]),
			"o Pedro de depois do tutorial disse '%s' e devia dizer a primeira de `falas_depois`" % str(registro["texto"]).left(30))
		_conferir_a_voz(pedro, "o E no Pedro", do_arquivo["falas_depois"][0], registro)
		await _calar(pedro, "o E no Pedro")


## A voz da fala que ganhou a vez: é a do arquivo, toca no morador e a fila segura a vez por ela toda.
func _conferir_a_voz(m, rotulo: String, esperada: Dictionary, registro: Dictionary) -> void:
	var audio := str(esperada.get("audio", ""))
	var fluxo = registro.get("voz")
	_conferir(fluxo is AudioStream, "%s chegou à fila SEM voz (esperava '%s')" % [rotulo, audio])
	if not (fluxo is AudioStream):
		return
	_conferir((fluxo as AudioStream).resource_path == PASTA_VOZES + audio + ".mp3",
		"%s trouxe a voz '%s' e devia ser '%s'" % [rotulo, (fluxo as AudioStream).resource_path.get_file(), audio + ".mp3"])
	_conferir(m.voz.stream == fluxo and m.voz.playing and not m.voz.stream_paused,
		"%s: a voz não está tocando no morador (tocando %s)" % [rotulo, str(m.voz.playing)])
	var duracao := (fluxo as AudioStream).get_length()
	_conferir(float(registro["segundos"]) + 0.01 >= duracao,
		"%s: a fila segura a vez por %.1f s e a voz dura %.1f s" % [rotulo, float(registro["segundos"]), duracao])
	_conferir(fila.falando(m), "%s: a fila não tem este morador falando enquanto a voz toca" % rotulo)
	_vozes_no_vale += 1


## Passa a fala (quem leu não espera) e confere que a voz calou junto.
func _calar(m, rotulo: String) -> void:
	fila.pular()
	await _quadros(3)
	_conferir(not m.voz.playing, "%s: a voz seguiu tocando depois de a fala passar" % rotulo)


# --- apoio -------------------------------------------------------------------------------------------------------

func _veio(m, desde: int, classe: int) -> bool:
	for i in range(desde, _comecaram.size()):
		var c: Dictionary = _comecaram[i]
		if c["falante"] == m and int(c["classe"]) == classe:
			return true
	return false


func _ultimo(m, desde: int) -> Dictionary:
	for i in range(_comecaram.size() - 1, desde - 1, -1):
		if _comecaram[i]["falante"] == m:
			return _comecaram[i]
	return {}


## Uma hora DE DIA (das 6h30 às 17h30) em que o morador está fora de casa: dentro da primeira entrada da agenda
## que não o recolhe e que passa por essa faixa. -1 sem nenhuma.
func _hora_na_rua(dados: Dictionary) -> float:
	var agenda: Array = dados.get("agenda", [])
	for i in agenda.size():
		if str(agenda[i].get("acao", "")) == "recolhido":
			continue
		var de := float(agenda[i]["de"])
		var ate := float(agenda[(i + 1) % agenda.size()]["de"])
		if ate <= de:
			ate += 24.0
		var hora := maxf(de, 6.5) + 0.1
		if hora < ate - 0.05 and hora <= 17.5:
			return hora
	return -1.0


## Ao lado do morador, virado para ele: é onde se conversa.
func _ao_lado_de(quem, morador) -> void:
	var onde: Vector3 = morador.global_position + Vector3(1.0, 0.1, 0.6)
	var para_ele: Vector3 = morador.global_position - onde
	quem.teleportar(onde, atan2(para_ele.x, para_ele.z))


## Passa a fala que estiver no ar até a vez ficar livre.
func _vez_livre() -> void:
	await relogio.ate(func() -> bool:
		if fila.livre():
			return true
		fila.pular()
		return false, 20.0)
	await relogio.esperar(0.6)


func _reservar_preferencias() -> void:
	_havia_arquivo = FileAccess.file_exists(PREFERENCIAS)
	if _havia_arquivo:
		_reserva = FileAccess.get_file_as_bytes(PREFERENCIAS)


func _devolver_preferencias() -> void:
	if _havia_arquivo:
		var arquivo := FileAccess.open(PREFERENCIAS, FileAccess.WRITE)
		if arquivo != null:
			arquivo.store_buffer(_reserva)
			arquivo.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PREFERENCIAS))


## O idioma do menu, como o `IdiomaMenu.definir` o guarda (sem mexer na tradução do menu).
func _escrever_idioma(indice: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PREFERENCIAS)
	cfg.set_value("menu", "idioma", indice)
	cfg.save(PREFERENCIAS)


## FALSIFICAÇÃO. Sem o argumento não mexe em nada. Com `-- --falsificar-vozes`: no arquivo, o padre ganha uma
## saudação em chinês que é cópia do inglês, a beata aponta um áudio que não existe e a menina fica com a voz do
## menino; no vale, o padre perde o áudio das duas primeiras falas (nada toca). O portão tem de reprovar em todas.
func _falsificar_o_arquivo(arquivo: Dictionary) -> void:
	if not falsificar:
		return
	var por_id := {}
	for m in arquivo["moradores"]:
		por_id[str((m as Dictionary).get("id", ""))] = m
	por_id["padre"]["saudacoes"][0]["texto_zh"] = por_id["padre"]["saudacoes"][0]["texto_en"]
	por_id["beata"]["falas"][0]["audio"] = "nao_existe_mesmo"
	por_id["menina"]["voz"]["id"] = por_id["menino"]["voz"]["id"]
	print("  (falsificado: padre com texto_zh copiado do inglês; beata com áudio que não existe; menina com a voz do menino)")


func _falsificar_no_vale(padre) -> void:
	if not falsificar:
		return
	padre.dados["saudacoes"][0]["audio"] = "nao_existe_mesmo"
	padre.dados["falas"][0]["audio"] = "nao_existe_mesmo"
	print("  (falsificado: o padre vivo sem o áudio da primeira saudação e da primeira conversa)")


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


func _mundo_pronto() -> void:
	for i in 3000:
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame


func _fechar() -> void:
	_devolver_preferencias()
	print("")
	# 9: o padre (cumprimento, E, E e cumprimento em chinês), o mercador (2), o guarda de noite (2) e o Pedro (1).
	_conferir(_vozes_no_vale >= 9 or falhas > 0,
		"só %d voz(es) conferida(s) no vale: algum caminho do portão não rodou" % _vozes_no_vale)
	if falhas == 0:
		print("VOZES_DOS_MORADORES_OK: %d falantes com os quatro textos (pt, en, es, zh) em toda fala, o chinês em ideogramas e a saudação inteira no balão; o motor lê cada idioma e o chinês sem texto cai no inglês; cada um com a sua voz (nenhuma repetida) e o Quirino só no balão; %d áudios existem, importam e duram o que o texto pede; no vale %d vozes tocam pela fila (cumprimento e E de dia e de noite, menu em chinês e o Pedro de depois do tutorial), com a vez segura por elas e a voz calando com a fala; %d falas esperam o áudio, por `voz_pendente` declarado" % [_falantes, _audios_conferidos, _vozes_no_vale, _audios_pendentes])
	else:
		print("vozes_dos_moradores: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)
