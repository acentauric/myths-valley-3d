extends Node
## OS MORADORES AJUDAM QUEM ESTÁ PERDIDO (#204).
##
## Na captura de 06:55 (~835 ações) a missão "Junte lenha para 12 tábuas e 4 cordas" ficou em 2/36 por centenas
## de ações, passando de um dia, e depois do tutorial ninguém disse nada além do painel e da seta: ninguém lembrava de
## pôr o machado na mão, ninguém dizia onde há madeira. Um jogador humano travaria do mesmo jeito que o testador.
##
## Aqui, quando o jogador parece perdido, um morador que entende do assunto ANDA ATÉ ELE, para a uns dois metros,
## aponta e diz uma frase curta (voz do próprio morador e balão curto), e VOLTA à rotina. As frases moram em
## `data/dicas_dos_moradores.json`, por situação.
##
##
## OS SINAIS DE "PERDIDO" (e o que se mede de cada um; `medidas()` entrega os números)
##
##   1. SEM AVANÇO. A missão acompanhada (o `CadernoDoVale`) não muda de andamento — o mesmo "2 de 36", a mesma
##      linha — por SEM_AVANCO_S segundos de jogo livre (a conta só corre com o jogador solto, em terra, fora de
##      casa, sem tela nem caixa de fala, e depois do tutorial). Dormir e o tempo parado não contam: o relógio é o
##      de parede, e um salto de oito horas no calendário não conta como perdido. Mudar de missão zera.
##   2. RECUSAS REPETIDAS. O mesmo "Ponha na mão: Machado." ou "Precisa de Machado." (`Recursos3D.fora_da_mao`,
##      `sem_ferramenta`) RECUSAS_PARA_DICA vezes em JANELA_DAS_RECUSAS_S: não espera o tempo do sinal 1.
##   3. LADO ERRADO. A cada AMOSTRA_S segundos mede a distância ao alvo da missão; AFASTANDO_AMOSTRAS amostras
##      seguidas de afastamento, e já longe (LONGE_DO_ALVO), é o outro caminho.
##   4. PRIMEIRA VEZ NUM SISTEMA NOVO (lavoura, obras, ponte, pesca) sem tê-lo usado: é o sinal 1 sobre o passo que
##      ensina o sistema — o passo é justamente o primeiro uso —, e a dica é a do sistema (`situacao_do_passo`).
##
##
## O QUE ELE DIZ (a situação) E QUEM VEM
##
## O sinal diz o que está faltando: as recusas dizem a ferramenta (`_situacao_da_recusa`); o corpo cansado ou a noite
## vêm antes do passo (`situacao_de_estado`); senão é o passo da missão (`situacao_do_passo`: lenha, bancada, pedra,
## lavoura, obra, ponte, pesca), e por fim a dica geral. Cada situação tem frases de morador diferentes (`quem`):
## vem o que está mais perto e PODE vir (`MoradorNPC.pode_vir_ajudar`), e sem ninguém perto, o Pedro.
##
##
## QUANDO NÃO
##
## Cooldown longo por assunto (POR_ASSUNTO_S) e uma pausa entre quaisquer duas dicas (ENTRE_DICAS_S): sem virar babá. A
## fala entra na fila (`fila_de_falas.gd`, classe de missão): espera a narração, a caixa de fala, a conversa e o Pedro,
## e nunca corta ninguém. O morador só ESPERA a palavra livre; se ela não vem em poucos segundos, ele volta (TEMPO_MAXIMO).
## "Dicas dos moradores" em Ajustes: Ligadas, Poucas (tudo ao dobro do tempo) ou Desligadas.

const FilaDeFalas = preload("res://scripts/prototipo_3d/fila_de_falas.gd")
const CadeiaDeMissoes = preload("res://scripts/prototipo_3d/cadeia_de_missoes.gd")
const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")

const ARQUIVO := "res://data/dicas_dos_moradores.json"
const PREFERENCIAS := "user://preferencias_visuais.cfg"
const SECAO := "jogo"
const CHAVE := "dicas_dos_moradores"

## As escolhas de Ajustes, na ordem do seletor: o índice é o modo.
enum Modo { LIGADAS, POUCAS, DESLIGADAS }
const ROTULOS := ["Ligadas", "Poucas", "Desligadas"]
const PADRAO := 0

## Por modo (Ligadas, Poucas), em segundos de jogo livre.
const SEM_AVANCO_S := [90.0, 180.0]
const ENTRE_DICAS_S := [60.0, 150.0]
const POR_ASSUNTO_S := [240.0, 480.0]
const RECUSAS_PARA_DICA := [2, 3]
const JANELA_DAS_RECUSAS_S := 40.0
## O lado errado: de quanto em quanto se mede, quantas amostras seguidas, e o quanto já é longe (metros).
const AMOSTRA_S := 5.0
const AFASTANDO_AMOSTRAS := 6
const AFASTOU_METROS := 3.0
const LONGE_DO_ALVO := 45.0
## Um pulso a cada quanto (segundos).
const PULSO := 0.5
## Depois de tentar e não achar quem venha (cooldown, ninguém livre), espera isto para tentar de novo.
const NOVA_TENTATIVA_S := 6.0
## De onde o morador pode vir: o Pedro vem de mais longe, que é quem vem quando ninguém está perto (metros).
const ALCANCE := 70.0
const ALCANCE_DO_PEDRO := 160.0
## Para a quanto do jogador, e a que distância já conta como chegou.
const DISTANCIA_DA_CONVERSA := 2.2
const CHEGOU_A := 3.6
const VELOCIDADE_DA_AJUDA := 2.8
## O morador desiste se não chega em TEMPO_MAXIMO, ou se a dica não termina em TEMPO_FALANDO (segundos).
const TEMPO_MAXIMO := 60.0
const TEMPO_FALANDO := 25.0

enum Etapa { OCIOSA, A_CAMINHO, FALANDO }

## O modo guardado da sessão: lê o arquivo na primeira vez e daí em diante vale `definir_modo`.
static var _modo_guardado := -1

var _dados: Dictionary = {}
var _jogador: Node3D
var _guia: Node
var _achar_morador: Callable
var _passo_acompanhado: Callable
var _interiores: Node
var _noite: Node

var _etapa := Etapa.OCIOSA
var _auxilio: Dictionary = {}
var _pulso_s := 0.0
var _assinatura := ""
var _sem_avanco_s := 0.0
## Anotações de recusa: {"em": ms, "situacao": String}.
var _recusas: Array = []
var _ultima_dica_ms := -1000000
var _assunto_em: Dictionary = {}
var _espera_s := 0.0
var _amostra_s := 0.0
var _distancia_ao_alvo := -1.0
var _afastando := 0
var _fora_de_rumo := false
var _atualizar_ponto_s := 0.0
## Para o portão e para o relatório de quem mede: quantas dicas deu e qual foi a última.
var dicas_dadas := 0
var ultima_situacao := ""
var ultimo_morador := ""


## --- o ajuste ------------------------------------------------------------------------------------------

## O modo de agora: Ligadas (0), Poucas (1) ou Desligadas (2).
static func modo() -> int:
	if _modo_guardado >= 0:
		return _modo_guardado
	var valor: int = PADRAO
	var preferencias := ConfigFile.new()
	if preferencias.load(PREFERENCIAS) == OK:
		valor = int(preferencias.get_value(SECAO, CHAVE, PADRAO))
	_modo_guardado = clampi(valor, 0, ROTULOS.size() - 1)
	return _modo_guardado


static func definir_modo(valor: int) -> void:
	_modo_guardado = clampi(valor, 0, ROTULOS.size() - 1)
	var preferencias := ConfigFile.new()
	preferencias.load(PREFERENCIAS)
	preferencias.set_value(SECAO, CHAVE, _modo_guardado)
	if preferencias.save(PREFERENCIAS) != OK:
		push_warning("Não foi possível salvar a preferência das dicas dos moradores.")


## Esquece o que a sessão guardou (o portão troca o modo sem passar pelo arquivo).
static func esquecer_o_modo() -> void:
	_modo_guardado = -1


## --- a montagem --------------------------------------------------------------------------------------

## Liga ao vale: o jogador, o Pedro, quem acha um morador pelo id, quem diz o passo da missão acompanhada, os
## cômodos, a noite (`queda.gd`) e os alvos de trabalho (as recusas). Qualquer um pode faltar.
func configurar(jogador: Node3D, guia: Node, achar_morador: Callable, passo_acompanhado: Callable,
		interiores: Node, noite: Node, recursos: Node) -> void:
	_jogador = jogador
	_guia = guia
	_achar_morador = achar_morador
	_passo_acompanhado = passo_acompanhado
	_interiores = interiores
	_noite = noite
	var lido = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO))
	_dados = lido if lido is Dictionary else {}
	if recursos != null:
		if recursos.has_signal("fora_da_mao"):
			recursos.connect("fora_da_mao", _ao_ficar_fora_da_mao)
		if recursos.has_signal("sem_ferramenta"):
			recursos.connect("sem_ferramenta", _ao_faltar_ferramenta)


func _exit_tree() -> void:
	_largar_o_morador()


## --- o que se mede ----------------------------------------------------------------------------------

## Os números dos sinais, para o portão e para quem quiser vê-los (o relatório do testador).
func medidas() -> Dictionary:
	return {
		"modo": modo(), "etapa": int(_etapa), "sem_avanco_s": _sem_avanco_s, "recusas": _recusas.size(),
		"afastando": _afastando, "dicas_dadas": dicas_dadas, "ultima_situacao": ultima_situacao,
		"limite_sem_avanco_s": _limite(SEM_AVANCO_S),
	}


func _limite(tabela: Array) -> float:
	var i := mini(modo(), tabela.size() - 1)
	return float(tabela[i])


## Está ajudando agora (a caminho ou falando)?
func ajudando() -> bool:
	return _etapa != Etapa.OCIOSA


func _process(delta: float) -> void:
	_pulso_s += delta
	if _pulso_s < PULSO:
		return
	var dt := _pulso_s
	_pulso_s = 0.0
	if modo() >= Modo.DESLIGADAS:
		if _etapa != Etapa.OCIOSA:
			_encerrar()
		_zerar_as_contagens()
		return
	if _etapa != Etapa.OCIOSA:
		_andar_o_auxilio(dt)
		return
	_medir(dt)


## O jogador está solto, em terra e fora de casa, com o vale correndo e o tutorial acabado? Só então a conta corre.
func _jogo_livre() -> bool:
	if not is_inside_tree() or get_tree().paused or Dialogo.ocupado():
		return false
	if _jogador == null or not _jogador.is_physics_processing() or bool(_jogador.get("_nadando")):
		return false
	if _noite != null and _noite.has_method("virando_a_noite") and bool(_noite.call("virando_a_noite")):
		return false
	if _guia != null and _guia.has_method("terminou_o_tutorial") and not bool(_guia.call("terminou_o_tutorial")):
		return false
	return not _dentro_de_algum_comodo()


func _dentro_de_algum_comodo() -> bool:
	return _interiores != null and _jogador != null and _interiores.has_method("contem") \
		and str(_interiores.call("contem", _jogador.global_position)) != ""


## Um pulso de medida: o andamento da missão acompanhada, as recusas e o rumo.
func _medir(dt: float) -> void:
	if not _jogo_livre():
		return
	var missao: Dictionary = CadernoDoVale.atual()
	if missao.is_empty():
		_zerar_as_contagens()
		return
	var assinatura := "%s|%d|%d|%s" % [str(missao.get("id", "")), int(missao.get("feito", 0)),
		int(missao.get("total", 0)), str(missao.get("linha", ""))]
	if assinatura != _assinatura:
		_zerar_as_contagens()
		_assinatura = assinatura
		return
	_sem_avanco_s += dt
	_espera_s = maxf(_espera_s - dt, 0.0)
	_vigiar_o_rumo(dt, missao)
	if _espera_s > 0.0:
		return
	var situacao := _situacao_do_momento()
	if situacao != "" and not _comecar(situacao):
		_espera_s = NOVA_TENTATIVA_S


## Qual situação pede ajuda AGORA, ou "" se o jogador não parece perdido.
func _situacao_do_momento() -> String:
	var situacao := _situacao_das_recusas()
	if situacao != "":
		return situacao
	if _fora_de_rumo:
		return "lado_errado"
	if _sem_avanco_s < _limite(SEM_AVANCO_S):
		return ""
	situacao = situacao_de_estado()
	# A dica de estado (cansado, noite) já foi dada há pouco? Então cai para a do passo: quem está parado em
	# lenha 2/36 e cansado não pode ficar sem a dica da lenha e do machado enquanto o estado durar.
	if situacao != "" and not _em_cooldown_de_assunto(situacao):
		return situacao
	var passo: Dictionary = _passo_acompanhado.call() if _passo_acompanhado.is_valid() else {}
	return situacao_do_passo(passo)


## O assunto da situação foi dito há menos de POR_ASSUNTO_S? (A mesma conta do início da ajuda.)
func _em_cooldown_de_assunto(situacao: String) -> bool:
	var entrada: Dictionary = (_dados.get("situacoes", {}) as Dictionary).get(situacao, {})
	var assunto := str(entrada.get("assunto", situacao))
	return Time.get_ticks_msec() - int(_assunto_em.get(assunto, -1000000)) < int(_limite(POR_ASSUNTO_S) * 1000.0)


func _zerar_as_contagens() -> void:
	_assinatura = ""
	_sem_avanco_s = 0.0
	_recusas.clear()
	_afastando = 0
	_distancia_ao_alvo = -1.0
	_fora_de_rumo = false


## --- os sinais ---------------------------------------------------------------------------------------

func _ao_ficar_fora_da_mao(ferramenta: String) -> void:
	var situacao := "ponha_outra"
	match ferramenta:
		"machado":
			var na_mao := Inventario.na_mao()
			situacao = "picareta_na_madeira" if na_mao != "" and Catalogo.familia(na_mao) == "picareta" else "ponha_machado"
		"picareta":
			situacao = "ponha_picareta"
	anotar_recusa(situacao)


func _ao_faltar_ferramenta(ferramenta: String) -> void:
	anotar_recusa("sem_machado" if ferramenta == "machado" else "sem_ferramenta")


## Uma recusa do trabalho, da situação que ela pede. O portão chama isto.
func anotar_recusa(situacao: String) -> void:
	if modo() >= Modo.DESLIGADAS:
		return
	_recusas.append({"em": Time.get_ticks_msec(), "situacao": situacao})
	while _recusas.size() > 12:
		_recusas.pop_front()


## A situação que se repetiu RECUSAS_PARA_DICA vezes dentro da janela, ou "".
func _situacao_das_recusas() -> String:
	var agora := Time.get_ticks_msec()
	var contas: Dictionary = {}
	var vigentes: Array = []
	for recusa: Dictionary in _recusas:
		if agora - int(recusa["em"]) > int(JANELA_DAS_RECUSAS_S * 1000.0):
			continue
		vigentes.append(recusa)
		var situacao := str(recusa["situacao"])
		contas[situacao] = int(contas.get(situacao, 0)) + 1
		if int(contas[situacao]) >= int(_limite(RECUSAS_PARA_DICA)):
			_recusas = vigentes
			return situacao
	_recusas = vigentes
	return ""


## O LADO ERRADO: a cada AMOSTRA_S mede a distância do jogador ao alvo da missão. AFASTANDO_AMOSTRAS amostras
## seguidas de afastamento, e já longe, é o outro caminho. Quem só deu a volta por um obstáculo se aproxima de novo.
func _vigiar_o_rumo(dt: float, missao: Dictionary) -> void:
	_amostra_s += dt
	if _amostra_s < AMOSTRA_S:
		return
	_amostra_s = 0.0
	var alvo = missao.get("alvo", Vector3.ZERO)
	if not (alvo is Vector3) or (alvo as Vector3) == Vector3.ZERO or _jogador == null:
		_distancia_ao_alvo = -1.0
		_afastando = 0
		return
	var aqui: Vector3 = _jogador.global_position
	var distancia := Vector2(aqui.x - (alvo as Vector3).x, aqui.z - (alvo as Vector3).z).length()
	var antes := _distancia_ao_alvo
	_distancia_ao_alvo = distancia
	if antes < 0.0 or distancia < antes + AFASTOU_METROS or distancia < LONGE_DO_ALVO:
		_afastando = 0
		return
	_afastando += 1
	if _afastando >= AFASTANDO_AMOSTRAS:
		_afastando = 0
		_fora_de_rumo = true


## O CORPO E A HORA vêm antes do passo: reserva no fim ("senta um pouco") e noite ("amanhã cedo rende mais").
func situacao_de_estado() -> String:
	if Energia.cansado():
		return "cansado"
	if Dia.periodo() in ["noite", "madrugada"]:
		return "noite"
	return ""


## O QUE O PASSO PEDE: a situação da dica que o ensina. Passo sem ensino próprio cai na geral.
func situacao_do_passo(passo: Dictionary) -> String:
	var meta: Dictionary = passo.get("meta", {})
	match str(meta.get("tipo", "")):
		"juntar":
			var pedido := CadeiaDeMissoes._carga_da_meta(meta)
			for qual in pedido:
				if CadeiaDeMissoes._tem_para_a_meta(meta, str(qual)) >= int(pedido[qual]):
					continue
				match str(qual):
					"lenha":
						return "lenha"
					"tabua", "corda":
						return "bancada"
					"pedra":
						return "pedra"
			return "geral"
		"obra":
			return "ponte" if str(meta.get("construcao", "")) == "ponte" else "obra"
		"evento", "contar":
			for nome: String in CadeiaDeMissoes.eventos_da_meta(meta):
				if nome in ["arou", "plantou", "regou", "colheu"] or nome.begins_with("plantou:"):
					return "lavoura"
				if nome == "pescou":
					return "pesca"
	return "geral"


## --- a ajuda -------------------------------------------------------------------------------------------

## A situação pede a dica de um morador que possa vir. Devolve se alguém saiu andando.
func pedir_ajuda(situacao: String) -> bool:
	return _comecar(situacao)


func _comecar(situacao: String) -> bool:
	var entrada: Dictionary = (_dados.get("situacoes", {}) as Dictionary).get(situacao, {})
	if entrada.is_empty() or _jogador == null:
		return false
	var assunto := str(entrada.get("assunto", situacao))
	var agora := Time.get_ticks_msec()
	if _em_cooldown_de_assunto(situacao):
		return false
	if agora - _ultima_dica_ms < int(_limite(ENTRE_DICAS_S) * 1000.0):
		return false
	var escolha := escolher(situacao)
	if escolha.is_empty():
		return false
	var morador: Node3D = escolha["morador"]
	_auxilio = {"morador": morador, "dica": escolha["dica"], "situacao": situacao, "assunto": assunto,
		"inicio_ms": agora, "ponto": Vector3.INF}
	_etapa = Etapa.A_CAMINHO
	_levar_ao_jogador()
	_assunto_em[assunto] = agora
	_ultima_dica_ms = agora
	# O que levou à dica está contado: recomeça a conta do sinal 1 e das recusas.
	_sem_avanco_s = 0.0
	_recusas.clear()
	_fora_de_rumo = false
	return true


## Quem ajuda: das dicas da situação, a do morador que está mais perto do jogador e PODE vir (ALCANCE); sem ninguém
## perto, a do Pedro, de onde estiver (ALCANCE_DO_PEDRO). {} se ninguém pode.
func escolher(situacao: String) -> Dictionary:
	var entrada: Dictionary = (_dados.get("situacoes", {}) as Dictionary).get(situacao, {})
	var melhor: Dictionary = {}
	var melhor_distancia := INF
	var do_pedro: Dictionary = {}
	var dicas: Array = entrada.get("dicas", [])
	for dica: Dictionary in dicas:
		var quem := str(dica.get("quem", ""))
		var morador := _morador(quem)
		if morador == null or not morador.has_method("pode_vir_ajudar") or not bool(morador.call("pode_vir_ajudar")):
			continue
		var distancia := _distancia_ao_jogador(morador)
		if quem == "pedro":
			if distancia <= ALCANCE_DO_PEDRO:
				do_pedro = {"dica": dica, "morador": morador, "distancia": distancia}
		elif distancia <= ALCANCE and distancia < melhor_distancia:
			melhor_distancia = distancia
			melhor = {"dica": dica, "morador": morador, "distancia": distancia}
	return melhor if not melhor.is_empty() else do_pedro


func _morador(quem: String) -> Node3D:
	if quem == "" or not _achar_morador.is_valid():
		return null
	var achado = _achar_morador.call(quem)
	return achado if achado is Node3D and is_instance_valid(achado) else null


func _distancia_ao_jogador(morador: Node3D) -> float:
	if _jogador == null:
		return INF
	var d := morador.global_position - _jogador.global_position
	return Vector2(d.x, d.z).length()


## Para onde o morador vai: a DISTANCIA_DA_CONVERSA do jogador, do lado de onde ele vem. Refaz-se se o jogador anda.
func _ponto_de_encontro(morador: Node3D) -> Vector3:
	var de: Vector3 = _jogador.global_position
	var rumo := morador.global_position - de
	rumo.y = 0.0
	rumo = rumo.normalized() if rumo.length() > 0.1 else Vector3.BACK
	return de + rumo * DISTANCIA_DA_CONVERSA


## Manda o morador ao ponto de encontro, se o jogador se mexeu desde a última vez.
func _levar_ao_jogador() -> void:
	var morador = _auxilio.get("morador")
	if morador == null or not is_instance_valid(morador) or _jogador == null:
		return
	var onde: Vector3 = _jogador.global_position
	var visto: Vector3 = _auxilio.get("ponto", Vector3.INF)
	if visto.is_finite() and Vector2(visto.x - onde.x, visto.z - onde.z).length() < 2.0:
		return
	_auxilio["ponto"] = onde
	morador.call("ir_ate", _ponto_de_encontro(morador), VELOCIDADE_DA_AJUDA)


## Um pulso de quem ajuda: anda, chega e fala; ou desiste.
func _andar_o_auxilio(dt: float) -> void:
	var morador = _auxilio.get("morador")
	var passou := float(Time.get_ticks_msec() - int(_auxilio.get("inicio_ms", 0))) / 1000.0
	if morador == null or not is_instance_valid(morador) or _jogador == null or modo() >= Modo.DESLIGADAS:
		_encerrar()
		return
	if _etapa == Etapa.FALANDO:
		if float(Time.get_ticks_msec() - int(_auxilio.get("falou_ms", 0))) / 1000.0 > TEMPO_FALANDO:
			_encerrar()
		return
	# A CAMINHO: desiste se demora demais, se o morador foi dormir ou se recolher, ou se o jogador entrou em casa.
	if passou > TEMPO_MAXIMO or bool(morador.get("_recolhido")) or bool(morador.get("_dormindo")) or _dentro_de_algum_comodo():
		_encerrar()
		return
	_atualizar_ponto_s += dt
	if _atualizar_ponto_s >= 1.0:
		_atualizar_ponto_s = 0.0
		_levar_ao_jogador()
	if _distancia_ao_jogador(morador) > CHEGOU_A or not _palavra_livre():
		return
	# CHEGOU E A PALAVRA ESTÁ LIVRE: fala.
	var dica: Dictionary = _auxilio["dica"]
	var texto := String(IdiomaMenu.campo(dica, "texto", ""))
	_etapa = Etapa.FALANDO
	_auxilio["falou_ms"] = Time.get_ticks_msec()
	dicas_dadas += 1
	ultima_situacao = str(_auxilio.get("situacao", ""))
	ultimo_morador = str(dica.get("quem", ""))
	morador.call("dar_dica", str(dica.get("audio", "")), texto, _ao_acabar_a_dica)


## A palavra está livre? Ninguém no ar, nenhuma caixa nem tela, e o Pedro sem passo a anunciar.
func _palavra_livre() -> bool:
	if not is_inside_tree() or get_tree().paused or Dialogo.ocupado():
		return false
	var fila := FilaDeFalas.da(self)
	if fila != null and not fila.livre():
		return false
	if _guia != null and is_instance_valid(_guia) and "_cadeia" in _guia:
		var cadeia = _guia.get("_cadeia")
		if cadeia != null and float(cadeia.get("espera")) > 0.0:
			return false
	return true


func _ao_acabar_a_dica() -> void:
	if _etapa == Etapa.FALANDO:
		_encerrar()


## A dica foi dita, ou desistiu: o morador volta à rotina e a conta recomeça.
func _encerrar() -> void:
	_largar_o_morador()
	_etapa = Etapa.OCIOSA
	_auxilio = {}
	_sem_avanco_s = 0.0
	_recusas.clear()
	_espera_s = 0.0


func _largar_o_morador() -> void:
	var morador = _auxilio.get("morador")
	if morador != null and is_instance_valid(morador) and morador.has_method("liberar"):
		morador.call("liberar")
