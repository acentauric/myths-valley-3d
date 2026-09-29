class_name GuiaPedro
extends MoradorNPC
## Pedro, o pescador que conduz o tutorial: acompanha o jogador de perto e narra as
## missões de chegada (praça, capela, casa de pasto, roçado, píer antes de escurecer)
## com voz do ElevenLabs quando está por perto. Ao entardecer avisa que vai escurecer.

signal missao_mudou(texto: String, alvo: Vector3, indice: int, total: int)
signal narrou(texto: String)

## Raios de chegada em unidades (1 u = 4 m), padronizados em 6–9: perto o bastante
## para ver o lugar de fato, sem exigir encostar no ponto exato.
## AS MISSÕES SÃO DADO, e não uma constante aqui dentro.
##
## Eram cinco linhas neste arquivo. Viraram `data/missoes_guia.json` por duas
## razões, e nenhuma delas é arrumação:
##
##   1. O CAMPO É `lugar`, E NÃO `ancora`. O nome vem do contrato do autoload
##      `Lugares` — "praca", "capela", "pier" — e não do nome da âncora do
##      `world_builder`. É o mesmo nome que o jogo 2D usa, e é o que faz um
##      passo de missão servir nos dois jogos sem ser reescrito. Quando o
##      sistema de missões do 2D atravessar (Fase 3 do plano), ele lê deste
##      arquivo sem que nada aqui mude.
##   2. TEXTO QUE O JOGADOR LÊ TEM DE EXISTIR NOS TRÊS IDIOMAS, que é a regra
##      deste projeto. Texto em constante de GDScript não tem como ganhar
##      `_en` e `_es`; em JSON, tem — e é a mesma forma que o
##      `historico_3d.json` já usa.
const ARQUIVO_MISSOES := "res://data/missoes_guia.json"

## Preenchido no `_ready` a partir do arquivo. Fica `[]` se o arquivo sumir, e
## aí o Pedro simplesmente não conduz nada — o vale continua jogável, que é o
## mesmo trato do `CatalogoAssets` com peça não exportada.
var MISSOES: Array = []
var _arremate: Dictionary = {}
const SEGUIR_MAX := 4.6
const CORRER_ALEM := 9.5
const ANDAR := 2.1
const CORRER := 5.2

var missao := -1
var _iniciado := false
var _espera := 0.0
var _anoiteceu_hoje := false
var _despedida_feita := false


func _ready() -> void:
	super()
	intervalo_saudacao_ms = 1 << 30
	_ler_missoes()


## Lê os passos do arquivo, já no idioma escolhido.
##
## A tradução é resolvida AQUI, uma vez, e não a cada fala: quem lê `texto`
## daqui para frente lê a língua do jogador sem saber que existem outras. O
## sufixo é o do `IdiomaMenu` — "", "_en", "_es" —, a mesma conta que o
## histórico da abertura já faz.
func _ler_missoes() -> void:
	MISSOES = []
	_arremate = {}
	var arquivo := FileAccess.open(ARQUIVO_MISSOES, FileAccess.READ)
	if arquivo == null:
		push_warning("GuiaPedro: não achei %s; o Pedro não vai conduzir nada." % ARQUIVO_MISSOES)
		return
	var dado = JSON.parse_string(arquivo.get_as_text())
	arquivo.close()
	if typeof(dado) != TYPE_DICTIONARY:
		push_warning("GuiaPedro: %s não é um objeto JSON." % ARQUIVO_MISSOES)
		return

	var sufixo := IdiomaMenu.sufixo()
	for bruto in dado.get("passos", []):
		var passo: Dictionary = bruto.duplicate()
		passo["texto"] = _no_idioma(passo, "texto", sufixo)
		MISSOES.append(passo)
	_arremate = dado.get("arremate", {}).duplicate()
	_arremate["texto"] = _no_idioma(_arremate, "texto", sufixo)


## O campo no idioma de agora, caindo no português quando a tradução falta.
##
## Cair no português é melhor do que devolver vazio: um balão sem texto parece
## defeito do jogo, e um balão em português num jogo em espanhol parece o que
## é — tradução faltando. O portão `tests/idiomas.gd` existe para que essa
## queda não aconteça calada.
func _no_idioma(de: Dictionary, campo: String, sufixo: String) -> String:
	var traduzido := str(de.get(campo + sufixo, ""))
	return traduzido if traduzido != "" else str(de.get(campo, ""))


func _physics_process(delta: float) -> void:
	if jogador == null:
		return
	var para_jogador := jogador.global_position - global_position
	para_jogador.y = 0.0
	var distancia := para_jogador.length()
	var direcao := Vector3.ZERO
	var velocidade := ANDAR
	if distancia > SEGUIR_MAX:
		direcao = para_jogador / distancia
		velocidade = CORRER if distancia > CORRER_ALEM else ANDAR
	_mover(direcao, velocidade, delta)
	if direcao == Vector3.ZERO:
		_olhar_para(jogador.global_position, delta)
	_atualizar_animacao(delta)
	_atualizar_interacao(delta)
	_atualizar_missao(delta)
	_verificar_anoitecer()


func saudar() -> void:
	super()
	if not _iniciado:
		_iniciado = true
		missao = 0
		_espera = 6.5


func _atualizar_missao(delta: float) -> void:
	if missao >= MISSOES.size() and not _despedida_feita and _palavra_livre():
		_despedida_feita = true
		narrar("", "É isso: o arraial inteiro. Agora o resto é com você.")
	if not _iniciado or missao < 0 or missao >= MISSOES.size():
		return
	# Âncora que não existe neste cenário: pula a missão em vez de apontar a origem.
	# Lugar que este cenário ainda não tem: pula o passo em vez de apontar a
	# origem. É o mesmo trato do `Lugares` com os treze nomes que a Fase 2.5
	# vai trazer — nome que não resolve some, e nada quebra.
	if not Lugares.resolve(str(MISSOES[missao].get("lugar", ""))):
		_avancar_missao()
		return
	if _espera > 0.0:
		_espera -= delta
		if _espera <= 0.0:
			# Alguém ainda fala perto do Pedro ou do jogador: espera terminar.
			if _palavra_livre():
				_anunciar()
			else:
				_espera = 0.25
		return
	var alvo := _posicao_da_missao(missao)
	if jogador.global_position.distance_to(alvo) < float(MISSOES[missao]["raio"]):
		_avancar_missao()


## Próxima missão; depois da última, emite com indice == total para a seta sumir.
func _avancar_missao() -> void:
	missao += 1
	if missao >= MISSOES.size():
		missao_mudou.emit(str(_arremate.get("texto", "")), Vector3.ZERO, MISSOES.size(), MISSOES.size())
	else:
		_espera = 1.4


## Pedro só narra quando nem ele nem o jogador estão ao alcance de outra fala.
func _palavra_livre() -> bool:
	return pode_falar() and not fala_perto_de(jogador.global_position)


func _anunciar() -> void:
	var m: Dictionary = MISSOES[missao]
	narrar(String(m["audio"]), String(m["texto"]))
	missao_mudou.emit("Pedro: " + String(m["texto"]), _posicao_da_missao(missao), missao + 1, MISSOES.size())


## Fala uma narração: balão e, quando existe, o áudio (por proximidade, como a saudação).
func narrar(nome_audio: String, texto: String) -> void:
	mostrar_balao(texto, 8.0)
	var caminho := PASTA_VOZES + nome_audio + ".mp3"
	var duracao := 4.0
	if nome_audio != "" and ResourceLoader.exists(caminho):
		voz.stop()
		voz.stream = load(caminho)
		voz.play()
		duracao = voz.stream.get_length()
	_tomar_palavra(duracao)
	if animador != null and animador.has_method("play_gesture"):
		# Autoral: 2 = concordar; procedural: 2 = apontar.
		animador.play_gesture(2)
	narrou.emit(texto)


func _verificar_anoitecer() -> void:
	var periodo := Dia.periodo()
	if periodo == "entardecer" and not _anoiteceu_hoje and _espera <= 0.0 and _palavra_livre():
		_anoiteceu_hoje = true
		narrar("pedro_anoitecer", "Daqui a pouco escurece. Quando terminar, volte pra cama. Apagar no chão não descansa igual.")
	elif periodo == "manha":
		_anoiteceu_hoje = false


## ONDE O PASSO ACONTECE, resolvido pelo NOME e não pela âncora.
##
## O `Lugares` traduz "praca" no ponto do vale, e traduziria o mesmo "praca"
## num `Vector2` do jogo 2D. É a costura da Fase 1, e é ela que faz a campanha
## escrita lá servir aqui.
func _posicao_da_missao(indice: int) -> Vector3:
	var p: Vector3 = Lugares.ponto(str(MISSOES[indice].get("lugar", "")))
	return Vector3.ZERO if p == Lugares.NENHUM else p


func texto_da_missao() -> String:
	if not _iniciado:
		return "Fale com Pedro: ele veio te esperar no píer."
	if missao >= MISSOES.size():
		return "Você conheceu o arraial. Explore o vale como quiser."
	return "Pedro: " + String(MISSOES[missao]["texto"])
