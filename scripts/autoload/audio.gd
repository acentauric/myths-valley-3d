extends Node
## Mixagem e preferências locais independentes de partidas e salvamentos.
## Fontes, prompts e direção: docs/sistemas/ESTRATEGIA_SONORA.md.

const ARQUIVO_PREFERENCIAS := "user://audio.cfg"
const PASTA_EFEITOS := "res://assets/audio/efeitos/"
const MUSICA_MENU_1 := "res://assets/audio/musica/tema_introducao.wav"
const MUSICA_MENU_2 := "res://assets/audio/musica/tema_menu.mp3"
const MUSICA_MENU_3 := "res://assets/audio/musica/tema_menu_2.mp3"
const MUSICA_MENU_4 := "res://assets/audio/musica/tema_reconcavo.ogg"
const MUSICA_MENU := MUSICA_MENU_4
const MUSICA_ROCADO := "res://assets/audio/musica/tema_rocado.mp3"
## Trilha do jogo por período do dia: uma para cada um dos CINCO que o relógio anuncia no HUD.
## Até a Build 9B eram três (o entardecer repetia a tarde e a madrugada, a noite), e o jogador
## via o HUD virar "Entardecer" e "Madrugada" sem a música mudar ("senti falta da mudança de
## trilha entre os períodos do dia"): `tools/elevenlabs/gerar-musicas-periodos.ps1`.
const MUSICAS_PERIODO := {
	"manha": "res://assets/audio/musica/musica_manha.mp3",
	"tarde": "res://assets/audio/musica/musica_tarde.mp3",
	"entardecer": "res://assets/audio/musica/musica_entardecer.mp3",
	"noite": "res://assets/audio/musica/musica_noite.mp3",
	"madrugada": "res://assets/audio/musica/musica_madrugada.mp3",
}
## Sem o arquivo do período (um clone que ainda não importou as trilhas novas), vale a do vizinho.
const PERIODO_VIZINHO := {"entardecer": "tarde", "madrugada": "noite"}
## Trilha de tensão da mata fechada, por cima do período.
const MUSICA_MATA := "res://assets/audio/musica/musica_mata.mp3"
## Os apelidos que o código do jogo usa para os sons de interface (`efeito("ui_hover")`), e os nomes
## de interface: tocam no tocador de interface e têm a variante _madeira (AJUSTAR → Sons).
const ALIASES_DE_EFEITO := {"ui_confirmar": "menu_confirma", "ui_hover": "menu_mover", "ui_voltar": "menu_voltar", "ui_trava": "menu_trava", "mao_troca": "menu_mover"}
const SONS_DE_INTERFACE := ["menu_mover", "menu_confirma", "menu_voltar", "menu_trava", "menu_negado"]
## Travessia (introdução): música própria e a narração em trechos, um por legenda
## (tools/elevenlabs/gerar-travessia.ps1 e alinhar_travessia.py).
const MUSICA_TRAVESSIA := "res://assets/audio/musica/tema_travessia.mp3"
const PASTA_TRAVESSIA := "res://assets/audio/narracao/travessia/"
## A música fica por baixo da voz durante a travessia.
const ABAFO_TRAVESSIA := 0.45
## Troca de trecho: o atual some em FADE_TRECHO e o próximo entra depois de ESPERA_TRECHO.
const FADE_TRECHO := 0.35
const ESPERA_TRECHO := 0.3
const AMBIENTE_MAR := "res://assets/audio/ambiente/mare_mansa.ogg"
const AMBIENTE_AVES := "res://assets/audio/ambiente/aves_reconcavo.ogg"
const VOLUME_MUSICA := -10.0
const VOLUME_NARRACAO := -3.0
const VOLUME_EFEITO := -6.0
const VOLUME_PASSO := -16.0
const VOLUME_AMBIENTE := -5.0
## Falas dos personagens e narração: base acima dos efeitos para a voz se destacar.
const VOLUME_VOZ := 2.0
const VARIACAO_DO_PASSO := 0.12
## Camadas do ambiente com volume próprio, aplicado sobre o volume geral de Ambiente.
const CAMADAS_AMBIENTE := ["aves", "mar", "riacho", "fogueira", "mata"]
const ROTULOS_CAMADAS := {"aves": "Aves", "mar": "Mar", "riacho": "Riacho", "fogueira": "Fogueira", "mata": "Insetos e grilos"}
## Volumes de fábrica (AJUSTAR → Restaurar padrões): canais gerais e camadas do ambiente.
const PADROES := {
	"musica": 0.8, "narracao": 1.0, "vozes": 1.0, "efeitos": 0.8, "ambiente": 0.4,
	"aves": 0.95, "mar": 0.9, "riacho": 1.0, "fogueira": 1.0, "mata": 0.7,
}
## Canais da aba Geral (as camadas do ambiente ficam em CAMADAS_AMBIENTE).
const CANAIS_GERAIS := ["musica", "narracao", "vozes", "efeitos", "ambiente"]

## Emitido quando um volume muda: os tocadores 3D do vale (NPCs, ambiente) reaplicam o seu.
signal volumes_alterados

## Barramentos: todo som do jogo sai por GERAL, que o botão de som silencia; ESCUTA
## fica de fora do mudo, para o que o jogador pede para ouvir com um clique (a fala no
## painel PERSONAGENS). Os dois desembocam no Master.
const GERAL := &"Geral"
const ESCUTA := &"Escuta"

var som_ativo: bool = true
var musica_menu_opcao: int = 1
var efeitos_menu_opcao: int = 2
var ambiente_menu_opcao: int = 3
var volume_musica: float = 0.8
var volume_efeitos: float = 0.8
var volume_ambiente: float = 0.4
var volume_vozes: float = 1.0
var volume_narracao: float = 1.0
var volume_camadas: Dictionary = {"aves": 0.95, "mar": 0.9, "riacho": 1.0, "fogueira": 1.0, "mata": 0.7}
## Canais silenciados pelo alto-falante ao lado de cada volume (chaves de PADROES): o
## volume escolhido fica guardado e volta ao reativar.
var mudos: Dictionary = {}
var _musica: AudioStreamPlayer
var _narracao: AudioStreamPlayer
var _efeitos: AudioStreamPlayer
var _passos: AudioStreamPlayer
var _interface: AudioStreamPlayer
var _mar: AudioStreamPlayer
var _aves: AudioStreamPlayer
var _timer_previa: Timer
var _cache: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _transicao_musica: Tween
const FADE_MUSICA := 2.5
const FADE_SAIDA := 1.25
var _transicoes_ambiente: Dictionary = {}
var _caminho_musica: String = ""
var _ambiente_menu_ativo: bool = false
var _opcao_previa: int = -1
var _ultimo_movimento_ms: int = -1000
## Trilha do jogo no ar (segue o período do dia) e tensão da mata por cima dela.
var _musica_do_jogo := false
var _mata_ativa := false
## Passos na água: 1 = sons originais, 2 = variantes novas (_v2).
var sons_agua_opcao: int = 1
var _ganho_musica: float = 1.0:
	set(valor):
		_ganho_musica = valor
		if is_instance_valid(_musica):
			_musica.volume_db = _volume_db(VOLUME_MUSICA, _ef("musica", volume_musica) * _ganho_musica * _abafo_musica)
## Fator da música por baixo da narração da travessia (1 fora dela).
var _abafo_musica: float = 1.0:
	set(valor):
		_abafo_musica = valor
		_ganho_musica = _ganho_musica
## Cada troca de trecho ganha um número: uma troca mais nova cancela a anterior em espera.
var _trecho_geracao := 0
var _trecho_fade: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_criar_barramentos()
	_carregar_preferencias()
	_musica = _criar_tocador("Musica", VOLUME_MUSICA)
	_narracao = _criar_tocador("Narracao", VOLUME_NARRACAO)
	_efeitos = _criar_tocador("Efeitos", VOLUME_EFEITO)
	_passos = _criar_tocador("Passos", VOLUME_PASSO)
	_interface = _criar_tocador("Interface", VOLUME_EFEITO)
	_mar = _criar_tocador("Mare", VOLUME_AMBIENTE)
	_aves = _criar_tocador("Aves", VOLUME_AMBIENTE)
	_timer_previa = Timer.new()
	_timer_previa.one_shot = true
	_timer_previa.wait_time = 6.0
	_timer_previa.timeout.connect(_encerrar_previa_ambiente)
	add_child(_timer_previa)
	_rng.randomize()
	_aplicar_volumes()
	_aplicar_mute()


func alternar_som() -> bool:
	definir_som_ativo(not som_ativo)
	return som_ativo


func definir_som_ativo(ativo: bool) -> void:
	som_ativo = ativo
	_aplicar_mute()
	_salvar_preferencias()


func obter_caminho_musica_menu() -> String:
	var caminhos := [MUSICA_MENU_1, MUSICA_MENU_2, MUSICA_MENU_3, MUSICA_MENU_4]
	var caminho: String = caminhos[clampi(musica_menu_opcao, 1, 4) - 1]
	return caminho if ResourceLoader.exists(caminho) else MUSICA_MENU_1


func definir_musica_menu(opcao: int) -> void:
	musica_menu_opcao = clampi(opcao, 1, 4)
	_salvar_preferencias()
	# Com o vale aberto a música é a do DIA, e escolher a trilha do menu só guarda a escolha para
	# a próxima vez no menu: tocá-la aqui desligaria a troca por período para o resto da partida.
	if _musica_do_jogo:
		return
	tocar_musica(obter_caminho_musica_menu())


func definir_efeitos_menu(opcao: int) -> void:
	efeitos_menu_opcao = clampi(opcao, 1, 2)
	_salvar_preferencias()


func definir_ambiente_menu(opcao: int) -> void:
	ambiente_menu_opcao = clampi(opcao, 0, 3)
	_timer_previa.stop()
	_opcao_previa = -1
	_aplicar_ambiente(ambiente_menu_opcao if _ambiente_menu_ativo else 0)
	_salvar_preferencias()


func definir_volume_musica(valor: float) -> void:
	volume_musica = _normalizar_volume(valor)
	_aplicar_volumes()
	_salvar_preferencias()


func definir_volume_efeitos(valor: float) -> void:
	volume_efeitos = _normalizar_volume(valor)
	_aplicar_volumes()
	_salvar_preferencias()


func definir_volume_ambiente(valor: float) -> void:
	volume_ambiente = _normalizar_volume(valor)
	_aplicar_volumes()
	_salvar_preferencias()


func definir_volume_vozes(valor: float) -> void:
	volume_vozes = _normalizar_volume(valor)
	_aplicar_volumes()
	_salvar_preferencias()


func definir_volume_narracao(valor: float) -> void:
	volume_narracao = _normalizar_volume(valor)
	_aplicar_volumes()
	_salvar_preferencias()


func definir_volume_camada(camada: String, valor: float) -> void:
	if not volume_camadas.has(camada):
		return
	volume_camadas[camada] = _normalizar_volume(valor)
	_aplicar_volumes()
	_salvar_preferencias()


func canal_mudo(canal: String) -> bool:
	return bool(mudos.get(canal, false))


func definir_mudo(canal: String, mudo: bool) -> void:
	if not PADROES.has(canal):
		return
	if mudo:
		mudos[canal] = true
	else:
		mudos.erase(canal)
	_aplicar_volumes()
	_salvar_preferencias()


## Volumes de fábrica (e sem mudo) nos `canais` pedidos — chaves de PADROES; vazio
## restaura todos os canais e camadas.
func restaurar_padroes(canais: Array = []) -> void:
	var alvo: Array = canais if not canais.is_empty() else PADROES.keys()
	for canal: String in alvo:
		var padrao: float = PADROES[canal]
		match canal:
			"musica": volume_musica = padrao
			"narracao": volume_narracao = padrao
			"vozes": volume_vozes = padrao
			"efeitos": volume_efeitos = padrao
			"ambiente": volume_ambiente = padrao
			_: volume_camadas[canal] = padrao
		mudos.erase(canal)
	_aplicar_volumes()
	_salvar_preferencias()


func tocar_musica(caminho: String = MUSICA_ROCADO, forcar_troca: bool = false) -> void:
	# A trilha do jogo acompanha o período do dia; as demais desligam a mata.
	_musica_do_jogo = caminho == MUSICA_ROCADO
	if _musica_do_jogo:
		parar_ambiente_menu()
		_conectar_dia()
		caminho = MUSICA_MATA if _mata_ativa and ResourceLoader.exists(MUSICA_MATA) else _musica_do_periodo()
	else:
		_mata_ativa = false
	var fluxo := _carregar(caminho)
	if fluxo == null:
		return
	# Reentrar no menu ou mudar opções visuais não reinicia a composição.
	if not forcar_troca and caminho == _caminho_musica and (_musica.playing or (_transicao_musica and _transicao_musica.is_running())):
		return
	_cruzar_musica(caminho, FADE_MUSICA, forcar_troca)


func parar_musica() -> void:
	if _transicao_musica and _transicao_musica.is_valid():
		_transicao_musica.kill()
	_caminho_musica = ""
	_musica_do_jogo = false
	_mata_ativa = false
	if not _musica.playing:
		_ganho_musica = 0.0
		return
	_transicao_musica = create_tween()
	_transicao_musica.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_transicao_musica.tween_property(self, "_ganho_musica", 0.0, FADE_SAIDA)
	_transicao_musica.tween_callback(_musica.stop)


## Música de tensão da mata fechada: cruza para ela ao entrar e volta ao sair.
func tocar_musica_mata(ligar: bool) -> void:
	if ligar == _mata_ativa:
		return
	_mata_ativa = ligar
	if not _musica_do_jogo:
		return
	var alvo := MUSICA_MATA if ligar and ResourceLoader.exists(MUSICA_MATA) else _musica_do_periodo()
	_cruzar_musica(alvo, 2.5)


## A trilha que o jogador ouve (ou para a qual a fusão está indo): o caminho do arquivo, ou ""
## com a música parada. É o que os portões e a depuração perguntam.
func musica_atual() -> String:
	return _caminho_musica


## Trilha do período atual; sem o arquivo dele vale a do período vizinho e, sem nenhuma, a
## trilha original do roçado.
func _musica_do_periodo() -> String:
	var periodo := Dia.periodo()
	var caminho: String = MUSICAS_PERIODO.get(periodo, MUSICA_ROCADO)
	if not ResourceLoader.exists(caminho) and PERIODO_VIZINHO.has(periodo):
		caminho = MUSICAS_PERIODO[PERIODO_VIZINHO[periodo]]
	return caminho if ResourceLoader.exists(caminho) else MUSICA_ROCADO


## Liga o relógio uma única vez, só quando a trilha do jogo começa: este
## autoload carrega antes do Dia, então não dá para conectar no _ready.
func _conectar_dia() -> void:
	if not Dia.hora_mudou.is_connected(_ao_mudar_hora):
		Dia.hora_mudou.connect(_ao_mudar_hora)


## O relógio emite a cada quadro: só reage quando o período realmente muda.
func _ao_mudar_hora(_hora: float) -> void:
	if not _musica_do_jogo or _mata_ativa:
		return
	var alvo := _musica_do_periodo()
	if alvo != _caminho_musica:
		_cruzar_musica(alvo, 2.5)


## Troca de trilha com fusão: abaixa a atual, troca o fluxo e sobe a nova.
func _cruzar_musica(caminho: String, segundos: float, forcar: bool = false) -> void:
	if not forcar and caminho == _caminho_musica and (_musica.playing or (_transicao_musica and _transicao_musica.is_running())):
		return
	var fluxo := _carregar(caminho)
	if fluxo == null:
		return
	_configurar_loop(fluxo)
	if _transicao_musica and _transicao_musica.is_valid():
		_transicao_musica.kill()
	_caminho_musica = caminho
	_transicao_musica = create_tween()
	_transicao_musica.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if _musica.playing:
		_transicao_musica.tween_property(self, "_ganho_musica", 0.0, segundos * 0.5)
	else:
		_ganho_musica = 0.0
	_transicao_musica.tween_callback(func() -> void:
		_musica.stream = fluxo
		_musica.play())
	_transicao_musica.tween_property(self, "_ganho_musica", 1.0, segundos * 0.5)


func iniciar_ambiente_menu() -> void:
	_ambiente_menu_ativo = true
	_timer_previa.stop()
	_opcao_previa = -1
	_aplicar_ambiente(ambiente_menu_opcao)


func parar_ambiente_menu() -> void:
	_ambiente_menu_ativo = false
	_timer_previa.stop()
	_opcao_previa = -1
	_aplicar_ambiente(0)


## Prévia de seis segundos: respeita mute e volume, preserva a preferência.
func testar_ambiente_menu(opcao: int = -1) -> void:
	_opcao_previa = ambiente_menu_opcao if opcao < 0 else clampi(opcao, 0, 3)
	_aplicar_ambiente(_opcao_previa)
	_timer_previa.start()


func testar_efeito_menu(nome: String = "menu_confirma") -> void:
	# O clique explícito de prévia deve ser audível mesmo após focar o botão.
	if nome in ["menu_mover", "ui_hover"]:
		_ultimo_movimento_ms = -1000
	efeito(nome)


## Narração não bloqueia a abertura nem a entrada no mundo.
func parar_narracao() -> void:
	_trecho_geracao += 1
	if _trecho_fade and _trecho_fade.is_valid():
		_trecho_fade.kill()
	_narracao.stop()


## Começa a travessia: a música nova entra cruzando com a do menu e fica por baixo da voz.
func iniciar_travessia() -> void:
	_abafo_musica = ABAFO_TRAVESSIA
	tocar_musica(MUSICA_TRAVESSIA, true)


## Fim da travessia: a voz some suave e a música volta ao volume cheio; voltando ao menu,
## a trilha do menu entra de novo.
func encerrar_travessia(voltar_ao_menu: bool) -> void:
	_sumir_narracao()
	create_tween().tween_property(self, "_abafo_musica", 1.0, FADE_SAIDA)
	if voltar_ao_menu:
		tocar_musica(obter_caminho_musica_menu(), true)


func trecho_travessia(indice: int) -> String:
	return PASTA_TRAVESSIA + "trecho_%02d.mp3" % (indice + 1)


## Toca o trecho `indice` da travessia. Se outro trecho ainda soa, ele some em FADE_TRECHO
## e o novo só entra depois de ESPERA_TRECHO: pular nunca encavala duas falas. Devolve
## quanto falta, em segundos, até o fim do novo trecho (0 sem o arquivo).
func tocar_trecho_travessia(indice: int) -> float:
	var fluxo := _carregar(trecho_travessia(indice))
	if fluxo == null:
		return 0.0
	_trecho_geracao += 1
	var minha := _trecho_geracao
	var atraso := 0.0
	if _narracao.playing:
		atraso = FADE_TRECHO + ESPERA_TRECHO
		_sumir_narracao()
	_entrar_trecho.call_deferred(fluxo, atraso, minha)
	return atraso + fluxo.get_length()


func _entrar_trecho(fluxo: AudioStream, atraso: float, geracao: int) -> void:
	if atraso > 0.0:
		await get_tree().create_timer(atraso).timeout
	if geracao != _trecho_geracao:
		return
	# O fim do fade do trecho anterior não pode parar o novo.
	if _trecho_fade and _trecho_fade.is_valid():
		_trecho_fade.kill()
	_narracao.stop()
	_narracao.volume_db = _volume_db(VOLUME_NARRACAO, _ef("narracao", volume_narracao))
	_narracao.stream = fluxo
	_narracao.play()


## A narração que soa some em FADE_TRECHO e para.
func _sumir_narracao() -> void:
	if _trecho_fade and _trecho_fade.is_valid():
		_trecho_fade.kill()
	if not _narracao.playing:
		return
	_trecho_fade = create_tween()
	_trecho_fade.tween_property(_narracao, "volume_db", -60.0, FADE_TRECHO)
	_trecho_fade.tween_callback(_narracao.stop)


## O último efeito pedido, pelo nome resolvido: é como um portão "ouve" o sinete da tarefa.
var ultimo_efeito := ""


## `variacao` é o quanto o tom pode fugir de 1,0 para mais e para menos (0,06 = 6%): o clique que se
## repete o tempo todo, como o da troca do item na mão, não soa sempre igual.
func efeito(nome: String, variacao: float = 0.0) -> void:
	var nome_base: String = ALIASES_DE_EFEITO.get(nome, nome)
	ultimo_efeito = nome_base
	# Os sons de interface saem pelo tocador de interface (e ganham a variante _madeira): o "não pode"
	# da mochila (`menu_negado`) é um deles, para não cortar o golpe que acabou de soar.
	var menu := nome_base in SONS_DE_INTERFACE
	if nome_base == "menu_mover":
		var agora := Time.get_ticks_msec()
		if agora - _ultimo_movimento_ms < 65:
			return
		_ultimo_movimento_ms = agora
	var caminho := arquivo_do_efeito(nome)
	# Sem arquivo nenhum, o `_carregar` avisa (uma vez) qual faltou.
	var fluxo := _carregar(caminho if caminho != "" else PASTA_EFEITOS + nome_base + ".mp3")
	if fluxo == null:
		return
	var tocador := _interface if menu else _efeitos
	tocador.stream = fluxo
	tocador.pitch_scale = 1.0 + _rng.randf_range(-variacao, variacao) if variacao > 0.0 else 1.0
	tocador.play()


## O arquivo que `efeito(nome)` toca, ou "" se nenhum existe: o apelido resolvido, a variante _madeira
## dos sons de interface (AJUSTAR → Sons) e, sem ela, o de reserva (o "voltar" cai no "mover"). É a
## resposta que o portão `sons_do_jogo` cobra de cada `Audio.efeito("...")` escrito nos scripts.
func arquivo_do_efeito(nome: String) -> String:
	var nome_base: String = ALIASES_DE_EFEITO.get(nome, nome)
	var arquivo := nome_base
	if nome_base in SONS_DE_INTERFACE and efeitos_menu_opcao == 2:
		arquivo += "_madeira"
	if not ResourceLoader.exists(PASTA_EFEITOS + arquivo + ".mp3"):
		arquivo = "menu_mover" if nome_base == "menu_voltar" else nome_base
	var caminho := PASTA_EFEITOS + arquivo + ".mp3"
	return caminho if ResourceLoader.exists(caminho) else ""


## Passo no chão dado (grama, terra, areia, madeira, agua, agua_funda, lama, poca).
## Correndo, usa a corrida daquele chão; sem ela, o passo do chão e, por fim, a
## corrida genérica. Com os sons novos escolhidos, a variante _v2 tem preferência.
func passo(terreno: String, correndo: bool = false) -> void:
	var nomes := ["corrida_" + terreno, "passo_" + terreno, "corrida"] if correndo else ["passo_" + terreno]
	var fluxo: AudioStream = null
	for nome: String in nomes:
		if sons_agua_opcao == 2 and ResourceLoader.exists(PASTA_EFEITOS + nome + "_v2.mp3"):
			fluxo = _carregar(PASTA_EFEITOS + nome + "_v2.mp3")
			if fluxo != null:
				break
		fluxo = _carregar(PASTA_EFEITOS + nome + ".mp3")
		if fluxo != null:
			break
	if fluxo == null:
		return
	_passos.stream = fluxo
	_passos.pitch_scale = 1.0 + _rng.randf_range(-VARIACAO_DO_PASSO, VARIACAO_DO_PASSO)
	_passos.play()


## Preferência dos passos na água: 1 = sons originais, 2 = variantes novas (_v2).
func definir_sons_agua(opcao: int) -> void:
	sons_agua_opcao = clampi(opcao, 1, 2)
	_salvar_preferencias()


## Toca um efeito uma única vez no tocador de passos (botão Ouvir de AJUSTAR).
func previa_efeito(nome: String) -> void:
	var fluxo := _carregar(PASTA_EFEITOS + nome + ".mp3")
	if fluxo == null:
		return
	_passos.stream = fluxo
	_passos.pitch_scale = 1.0
	_passos.play()


func _encerrar_previa_ambiente() -> void:
	_opcao_previa = -1
	_aplicar_ambiente(ambiente_menu_opcao if _ambiente_menu_ativo else 0)


func _aplicar_ambiente(opcao: int) -> void:
	_sincronizar_camada(_mar, AMBIENTE_MAR, opcao in [1, 3], 0.0, "mar")
	_sincronizar_camada(_aves, AMBIENTE_AVES, opcao in [2, 3], -3.0, "aves")


func _sincronizar_camada(tocador: AudioStreamPlayer, caminho: String, ativo: bool, ajuste_db: float, camada: String) -> void:
	var id := tocador.get_instance_id()
	if _transicoes_ambiente.has(id):
		var anterior: Tween = _transicoes_ambiente[id]
		if anterior.is_valid():
			anterior.kill()
	if ativo:
		var fluxo := _carregar(caminho)
		if fluxo == null:
			return
		_configurar_loop(fluxo)
		if not tocador.playing or tocador.stream != fluxo:
			tocador.stream = fluxo
			tocador.volume_db = -80.0
			tocador.play()
	elif not tocador.playing:
		return
	var transicao := create_tween()
	_transicoes_ambiente[id] = transicao
	var alvo := volume_camada_db(camada) + ajuste_db if ativo else -80.0
	transicao.tween_property(tocador, "volume_db", alvo, 0.6)
	if not ativo:
		transicao.tween_callback(tocador.stop)


## Volume-base (em dB) das fontes posicionais que seguem os controles de AJUSTAR.
func volume_ambiente_db() -> float:
	return _volume_db(VOLUME_AMBIENTE, _ef("ambiente", volume_ambiente))


## Volume-base (em dB) de uma camada do ambiente: geral de Ambiente × volume da camada.
func volume_camada_db(camada: String) -> float:
	return _volume_db(VOLUME_AMBIENTE, _ef("ambiente", volume_ambiente) * _ef(camada, float(volume_camadas.get(camada, 1.0))))


func volume_efeitos_db() -> float:
	return _volume_db(VOLUME_EFEITO, _ef("efeitos", volume_efeitos))


func volume_vozes_db() -> float:
	return _volume_db(VOLUME_VOZ, _ef("vozes", volume_vozes))


## Carrega um áudio já configurado para repetir (loops de ambiente do vale).
func carregar_loop(caminho: String) -> AudioStream:
	var fluxo := _carregar(caminho)
	if fluxo != null:
		_configurar_loop(fluxo)
	return fluxo


func _aplicar_volumes() -> void:
	_ganho_musica = _ganho_musica
	_efeitos.volume_db = _volume_db(VOLUME_EFEITO, _ef("efeitos", volume_efeitos))
	_interface.volume_db = _volume_db(VOLUME_EFEITO, _ef("efeitos", volume_efeitos))
	_passos.volume_db = _volume_db(VOLUME_PASSO, _ef("efeitos", volume_efeitos))
	_narracao.volume_db = _volume_db(VOLUME_NARRACAO, _ef("narracao", volume_narracao))
	if _opcao_previa >= 0:
		_aplicar_ambiente(_opcao_previa)
	elif _ambiente_menu_ativo:
		_aplicar_ambiente(ambiente_menu_opcao)
	volumes_alterados.emit()


func _aplicar_mute() -> void:
	var indice := AudioServer.get_bus_index(GERAL)
	if indice >= 0:
		AudioServer.set_bus_mute(indice, not som_ativo)


func _criar_barramentos() -> void:
	for nome: StringName in [GERAL, ESCUTA]:
		if AudioServer.get_bus_index(nome) < 0:
			AudioServer.add_bus()
			var indice := AudioServer.bus_count - 1
			AudioServer.set_bus_name(indice, nome)
			AudioServer.set_bus_send(indice, &"Master")
	# Quem nasce no Master (o padrão de todo tocador) passa para o GERAL: o que já
	# existe agora e tudo o que entrar depois.
	_varrer_para_geral(get_tree().root)
	get_tree().node_added.connect(_mover_para_geral)


func _varrer_para_geral(no: Node) -> void:
	_mover_para_geral(no)
	for filho in no.get_children():
		_varrer_para_geral(filho)


func _mover_para_geral(no: Node) -> void:
	if (no is AudioStreamPlayer or no is AudioStreamPlayer2D or no is AudioStreamPlayer3D) and no.bus == &"Master":
		no.bus = GERAL


## Volume de uma fala pedida pelo jogador: ignora o mudo do canal (o clique é o pedido)
## e, com o volume de vozes zerado, usa o de fábrica.
func volume_escuta_vozes_db() -> float:
	return _volume_db(VOLUME_VOZ, volume_vozes if volume_vozes > 0.0 else float(PADROES["vozes"]))


func _carregar_preferencias() -> void:
	if not ResourceLoader.exists(MUSICA_MENU_4):
		musica_menu_opcao = 1
	var configuracao := ConfigFile.new()
	if configuracao.load(ARQUIVO_PREFERENCIAS) != OK:
		return
	som_ativo = bool(configuracao.get_value("audio", "som_ativo", true))
	musica_menu_opcao = clampi(int(configuracao.get_value("audio", "musica_menu", musica_menu_opcao)), 1, 4)
	efeitos_menu_opcao = clampi(int(configuracao.get_value("audio", "efeitos_menu", 2)), 1, 2)
	ambiente_menu_opcao = clampi(int(configuracao.get_value("audio", "ambiente_menu", 3)), 0, 3)
	sons_agua_opcao = clampi(int(configuracao.get_value("audio", "sons_agua", 1)), 1, 2)
	volume_musica = _normalizar_volume(float(configuracao.get_value("audio", "volume_musica", PADROES["musica"])))
	volume_efeitos = _normalizar_volume(float(configuracao.get_value("audio", "volume_efeitos", PADROES["efeitos"])))
	volume_ambiente = _normalizar_volume(float(configuracao.get_value("audio", "volume_ambiente", PADROES["ambiente"])))
	volume_vozes = _normalizar_volume(float(configuracao.get_value("audio", "volume_vozes", PADROES["vozes"])))
	volume_narracao = _normalizar_volume(float(configuracao.get_value("audio", "volume_narracao", PADROES["narracao"])))
	for camada in CAMADAS_AMBIENTE:
		volume_camadas[camada] = _normalizar_volume(float(configuracao.get_value("audio", "volume_" + camada, PADROES[camada])))
	for canal: String in PADROES:
		if bool(configuracao.get_value("audio", "mudo_" + canal, false)):
			mudos[canal] = true


func _salvar_preferencias() -> void:
	var configuracao := ConfigFile.new()
	configuracao.set_value("audio", "som_ativo", som_ativo)
	configuracao.set_value("audio", "musica_menu", musica_menu_opcao)
	configuracao.set_value("audio", "efeitos_menu", efeitos_menu_opcao)
	configuracao.set_value("audio", "ambiente_menu", ambiente_menu_opcao)
	configuracao.set_value("audio", "sons_agua", sons_agua_opcao)
	configuracao.set_value("audio", "volume_musica", volume_musica)
	configuracao.set_value("audio", "volume_efeitos", volume_efeitos)
	configuracao.set_value("audio", "volume_ambiente", volume_ambiente)
	configuracao.set_value("audio", "volume_vozes", volume_vozes)
	configuracao.set_value("audio", "volume_narracao", volume_narracao)
	for camada in CAMADAS_AMBIENTE:
		configuracao.set_value("audio", "volume_" + camada, volume_camadas[camada])
	for canal: String in PADROES:
		configuracao.set_value("audio", "mudo_" + canal, canal_mudo(canal))
	if configuracao.save(ARQUIVO_PREFERENCIAS) != OK:
		push_warning("Não foi possível salvar as preferências de áudio.")


## Volume que realmente toca: zero se o canal estiver silenciado.
func _ef(canal: String, valor: float) -> float:
	return 0.0 if canal_mudo(canal) else valor


func _normalizar_volume(valor: float) -> float:
	return clampf(valor, 0.0, 1.0) if is_finite(valor) else 0.0


func _volume_db(base: float, valor: float) -> float:
	return maxf(-80.0, base + linear_to_db(valor)) if valor > 0.0 else -80.0


func _criar_tocador(nome: String, volume: float) -> AudioStreamPlayer:
	var tocador := AudioStreamPlayer.new()
	tocador.name = nome
	tocador.volume_db = volume
	add_child(tocador)
	return tocador


func _configurar_loop(fluxo: AudioStream) -> void:
	if fluxo is AudioStreamMP3 or fluxo is AudioStreamOggVorbis:
		fluxo.loop = true
	elif fluxo is AudioStreamWAV:
		fluxo.loop_mode = AudioStreamWAV.LOOP_FORWARD
		if fluxo.loop_end <= 0:
			fluxo.loop_begin = 0
			fluxo.loop_end = int(fluxo.get_length() * fluxo.mix_rate)


func _carregar(caminho: String) -> AudioStream:
	if _cache.has(caminho):
		return _cache[caminho]
	if not ResourceLoader.exists(caminho):
		push_warning("Áudio ausente: %s" % caminho)
		_cache[caminho] = null
		return null
	var fluxo := load(caminho) as AudioStream
	_cache[caminho] = fluxo
	return fluxo
