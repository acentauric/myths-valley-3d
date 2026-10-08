extends Node3D
## AS CONSTRUÇÕES POR DENTRO, no lugar delas no vale.
##
## O vale não tinha cômodo nenhum (#26: "o buraco maior"). A primeira
## construção que se abriu foi a igreja do Bom Jesus (`interior_igreja.gd`); a
## segunda, a casa herdada (`interior_casa.gd`), onde fica a cama que vira o
## dia (#50). O que os dois cômodos têm em comum mora em `comodo.gd`.
##
##
## DENTRO DA PRÓPRIA CONSTRUÇÃO
##
## "Os cômodos têm que ser em 3D mesmo. O 2D é só referência." A primeira
## versão fazia como o 2D: a nave morava longe do vale, e a porta levava até
## ela num escurecer — e tudo o que pergunta onde o jogador está (a bússola, o
## mapa, o Pedro, o save) precisava ser enganado para ver a porta. Agora o
## cômodo mora DENTRO DA CASCA do modelo, no lugar da igreja: entra-se andando
## pela porta, o Pedro entra junto, e o vale vê o jogador onde ele está.
##
##
## COMO O CÔMODO CABE NA CASCA
##
## O modelo do Tripo é uma malha fechada, com uma caixa de colisão inteira por
## cima — não há onde entrar. Ao montar, este nó:
##
##   1. MEDE A CASCA por dentro, com raios contra a própria malha (uma colisão
##      provisória, numa camada só dela, desfeita em seguida): onde ficam as
##      paredes, o fundo, a fachada, o beiral e o chão; e, contra a colisão do
##      mundo, o patamar na porta, a quina do alicerce e o chão livre até o
##      cruzeiro. Assim o cômodo acompanha o modelo, e o estilo procedural —
##      cuja porta atravessa a torre — também.
##   2. TIRA A COLISÃO INTEIRA da construção, e o cômodo põe a dele: paredes um
##      palmo para dentro da casca, o vão da porta, e rampas onde degrau
##      travaria o pé — da nave ao patamar, e do patamar ao adro por cima da
##      quina do alicerce de pedra.
##   3. ABRE A PORTA: um vão escuro por cima da porta pintada da fachada. De
##      dentro, o vão mostra o adro — a casca do modelo só desenha a face de
##      fora, e por isso some de dentro. E a câmera fica do lado da porta em
##      que o jogador está (`camera_do_lado_de_dentro`).
##
## O que este nó NÃO faz: esvaziar o modelo, ou esconder pedaço dele. A casca
## fica inteira, e o cômodo cabe nela.
##
##
## TODA CASA ABRE, E POR DADOS
##
## "Todas as casas devem ter acesso interno e móveis." As quatro primeiras (a igreja,
## a casa herdada, a do Pedro, a da Zefa) têm a tabela fixa abaixo; todas as outras —
## as casas do arraial, a venda, o restaurante, as dos moradores, o casarão da
## fazenda — moram em `data/interiores_casas.json`: de cada GLB, onde fica a porta
## pintada; de cada casa, o lote, o nome nos três idiomas e o perfil de quem mora; de
## cada perfil, as cores e os móveis.
##
## Essas abrem DE PERTO, e não no carregamento: vinte e tantos cômodos, com os móveis,
## as luzes e a sonda de reflexo de cada um, custariam mais de um milhão de triângulos
## e oitenta luzes desenhados atrás das paredes a toda hora (a conta de 05/10). Então
## o cômodo só se monta quando o jogador chega a `CRIA_ATE` da porta, e some do
## desenho (`visible`) além de `ESCONDE_ALEM` — com histerese, para quem anda na
## divisa não ver a sala piscar. Quem precisa dele já (o portão, o save) pede
## `garantir`.

signal entrou(qual: String)
signal saiu(qual: String)

const Comodo = preload("res://scripts/prototipo_3d/comodo.gd")
const InteriorIgreja = preload("res://scripts/prototipo_3d/interior_igreja.gd")
const InteriorCasa = preload("res://scripts/prototipo_3d/interior_casa.gd")
const InteriorCasarao = preload("res://scripts/prototipo_3d/interior_casarao.gd")
const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")
const Camadas = preload("res://scripts/prototipo_3d/camadas.gd")

## As casas por dados (ver acima).
const ARQUIVO_DAS_CASAS := "res://data/interiores_casas.json"
## Até onde o jogador está da porta (u, no chão) para o cômodo se montar, e além de quanto
## ele some do desenho.
const CRIA_ATE := 32.0
const ESCONDE_ALEM := 46.0
## De quanto em quanto tempo se confere a distância (s), e quanto o jogador pode andar
## de uma vez (um pulo no mapa, o save) antes de se conferir já.
const RONDA := 0.25
const PULO := 12.0
## Quão perto do lote o jogador chega de uma vez para o cômodo se montar com ele parado (u).
const LOTE_COLADO := 6.0
## O que uma montagem diz a quem a pediu.
enum { MONTOU, ADIAR, FALHOU }

## As construções que se abrem:
##
##   ancora     a âncora do vale e o nome do lote (`world_builder.construcoes`)
##   nome       o que o HUD escreve lá dentro
##   colisao    o nome do corpo inteiro, para quando o lote não o guardou
##   meio_lote  até onde, do meio, vai a casca (de lado, e de frente e fundo):
##              no procedural, as malhas e os corpos do lote são os daí
##   porta_x    onde a porta fica na fachada, do meio para a direita de quem
##              olha a casa de frente; e o tamanho do vão da porta pintada
##   sonda      de que altura se procura o patamar na frente da porta: abaixo
##              do beiral, que na casa de taipa avança por cima da porta
const CONSTRUCOES := {
	"igreja": {"ancora": "Igreja", "nome": "Igreja do Bom Jesus", "colisao": "IgrejaColisao",
		"meio_lote": Vector2(4.5, 8.0), "porta_x": 0.0, "largura_da_porta": 1.2, "altura_da_porta": 2.7, "sonda": 8.0},
	"casa": {"ancora": "Casa de taipa", "nome": "Sua casa", "colisao": "Casa TaipaColisao",
		"meio_lote": Vector2(3.4, 3.2), "porta_x": 0.92, "largura_da_porta": 1.05, "altura_da_porta": 2.15, "sonda": 1.6},
	# AS CASAS DO PEDRO E DA DONA ZEFA: a mesma casa de taipa por fora, e por
	# dentro a de quem mora (`InteriorCasa.perfil`). O lote é o que o vale
	# escolheu para cada um (`WorldBuilder.casas_dos_moradores`).
	"casa_pedro": {"morador": "pedro", "nome": "Casa do Pedro", "perfil": "pescador",
		"meio_lote": Vector2(3.4, 3.2), "porta_x": 0.92, "largura_da_porta": 1.05, "altura_da_porta": 2.15, "sonda": 1.6},
	"casa_zefa": {"morador": "zefa", "nome": "Casa da Dona Zefa", "perfil": "rezadeira",
		"meio_lote": Vector2(3.4, 3.2), "porta_x": 0.92, "largura_da_porta": 1.05, "altura_da_porta": 2.15, "sonda": 1.6},
}

## A camada de física das colisões provisórias da medida (só elas moram nela).
const CAMADA_DE_MEDIR := 1 << 19
## Quanto a parede do cômodo fica para dentro da casca do modelo.
const FOLGA := 0.1
## Quanto além da porta quem já está dentro continua dentro (m).
const FOLGA_DE_SAIR := 0.25
## A COLISÃO ACOMPANHA A PAREDE VISÍVEL (#205): a parede do cômodo acaba um palmo (`FOLGA`) para
## dentro da face de dentro da casca, e a parede do modelo tem a espessura dela — o corpo que
## chegava por fora parava com o ombro dentro do reboco. A casca de fora (`Comodo._montar_a_casca_de_fora`)
## cobre o que falta, até a face de fora medida (`_medir_a_face_de_fora`), com esta margem para
## fora (m) e no máximo este tanto de espessura a mais (m) — acima dele a medida é de beiral,
## alpendre ou escada, e não de parede.
const MARGEM_DE_FORA := 0.03
const LIMITE_DA_CASCA_DE_FORA := 1.0

var _mundo: Node3D
var _jogador: Node3D
## qual -> {"sala": Node3D, "nome": String, "ancora": String, "preguicosa": bool}
var _construcoes: Dictionary = {}
var _dentro := ""
## O arquivo das casas por dados, e a tabela inteira (as de tabela fixa e as dele).
var _dados: Dictionary = {}
var _tabela: Dictionary = {}
## As que ainda não se montaram, a que se monta agora (uma por vez) e as que já tentaram.
var _pendentes: Array[String] = []
var _montando := ""
## Os galpões abertos (a casa de farinha): qual -> o corpo com as caixas dele.
var _galpoes: Dictionary = {}
var _ronda_em := 0.0
var _onde_da_ronda := Vector3.INF
## O jogador que chega de uma vez ao pé de uma casa ainda não montada espera o cômodo (`_montar_de_perto`).
## Só o portão que falsifica (`--falsificar=sem_freio`) o desliga.
var segura_o_jogador := true


## Monta os cômodos de tabela fixa. É uma corrotina: a medida espera dois quadros de
## física para a colisão provisória valer — quem precisa do cômodo pronto (o save que
## põe o jogador lá dentro) espera com `await`. Os corpos dos moradores entram
## na luz de dentro depois, quando eles existirem (`marcar_os_corpos`). As casas por
## dados ficam para quando o jogador chegar perto (`garantir`).
func configurar(mundo: Node3D, jogador: Node3D) -> void:
	_mundo = mundo
	_jogador = jogador
	add_to_group("interiores")
	_ler_as_casas()
	for qual in CONSTRUCOES:
		await _abrir(qual)
	if Estilo.tripo():
		for qual in _tabela:
			if not CONSTRUCOES.has(qual) and not _construcoes.has(qual):
				_pendentes.append(str(qual))


## A tabela inteira: as quatro fixas e as do arquivo, menos as que o vale deu a outro
## (a casa do arraial que virou a do Pedro ou a da Zefa é delas, e não uma casa a mais).
func _ler_as_casas() -> void:
	_tabela = CONSTRUCOES.duplicate(true)
	_dados = {}
	var texto := FileAccess.get_file_as_string(ARQUIVO_DAS_CASAS)
	var lido = JSON.parse_string(texto) if texto != "" else null
	if not (lido is Dictionary):
		push_warning("Interiores: não li %s; só as quatro casas de tabela abrem." % ARQUIVO_DAS_CASAS)
		return
	_dados = lido
	var tomadas := {}
	for qual in CONSTRUCOES:
		var lote := _ancora_de(str(qual), CONSTRUCOES[qual])
		if lote != "":
			tomadas[lote] = true
	for qual in _dados.get("casas", {}):
		var casa: Dictionary = (_dados["casas"][qual] as Dictionary).duplicate(true)
		if tomadas.has(str(casa.get("ancora", ""))):
			continue
		casa["preguicosa"] = true
		_tabela[str(qual)] = casa


## O lote (o nome da âncora) de uma construção da tabela.
func _ancora_de(_qual: String, dado: Dictionary) -> String:
	if dado.has("morador"):
		var casas = _mundo.get("casas_dos_moradores") if _mundo != null else null
		return str(casas.get(str(dado["morador"]), "")) if casas is Dictionary else ""
	return str(dado.get("ancora", ""))


## Todas as construções que abrem (montadas ou não), e as que já estão montadas.
func todas() -> Array:
	return _tabela.keys()


func quais() -> Array:
	return _construcoes.keys()


## O CÔMODO PRONTO, JÁ: monta o de `qual` se ainda não está de pé, e diz se está. Uma
## montagem por vez — quem chega no meio da de outro espera a vez.
func garantir(qual: String) -> bool:
	if _construcoes.has(qual) or _galpoes.has(qual):
		return true
	if not _tabela.has(qual) or _mundo == null:
		return false
	while _montando != "":
		await get_tree().process_frame
		if _construcoes.has(qual) or _galpoes.has(qual):
			return true
	_montando = qual
	var resultado: int = await _abrir(qual)
	if resultado == MONTOU:
		# Os corpos do cômodo só entram no espaço de física no passo seguinte: quem põe o
		# jogador lá dentro logo que `garantir` volta (o save, o portão) cairia pelo piso.
		await get_tree().physics_frame
		await get_tree().physics_frame
	_montando = ""
	if resultado != ADIAR:
		_pendentes.erase(qual)
	return _construcoes.has(qual) or _galpoes.has(qual)


## O PEDRO NÃO ENTRA nos cômodos pequenos das casas por dados: como na casa herdada
## (`guia_pedro.gd`, `ESPERA_FORA`), a quatro passos e meio do jogador o lugar dele seria o
## vão da porta, e o jogador não sairia. Espera do lado de fora, de lado para a porta
## (`Comodo.lugar_de_esperar_fora`). Nos largos (o casarão) ele entra junto. As quatro de
## tabela fixa seguem a regra que já tinham.
func espera_fora(qual: String) -> bool:
	var sala := sala_de(qual)
	return sala != null and not CONSTRUCOES.has(qual) and float(sala.largura) * float(sala.comprimento) < 60.0


## Monta todos os que faltam (o portão que confere cada casa).
func garantir_todas() -> void:
	for qual in _pendentes.duplicate():
		await garantir(qual)


## Em que construção o jogador está, ou "".
func dentro() -> String:
	return _dentro


func sala_de(qual: String) -> Node3D:
	return _construcoes[qual]["sala"] if _construcoes.has(qual) else null


func nome_de(qual: String) -> String:
	var dado: Dictionary = _tabela.get(qual, CONSTRUCOES.get(qual, {}))
	# As casas por dados trazem o nome nos três idiomas; as de tabela fixa, no `tr`.
	if dado.has("nome_en"):
		return str(IdiomaMenu.campo(dado, "nome", ""))
	return tr(str(dado.get("nome", "")))


## Em que cômodo este ponto do mundo está, ou "".
func contem(ponto: Vector3) -> String:
	for qual in _construcoes:
		if (_construcoes[qual]["sala"] as Node3D).contem(ponto):
			return qual
	return ""


## O PRÓXIMO PONTO no caminho de `de` até `para`, quando um está dentro de um
## cômodo e o outro não: a soleira do lado de quem anda, e, já no corredor da
## porta, a do outro lado. Sem cômodo no meio, é o próprio destino. É por aqui
## que o Pedro entra junto: andando em linha reta ele empurraria a parede, e
## não acharia a porta.
##
## O corredor é uma faixa, e não a distância até a soleira: com a distância, o
## Pedro que passava da soleira de fora rumo à porta ficava longe dela de novo,
## dava meia-volta, e ficava indo e vindo no patamar.
func passagem(de: Vector3, para: Vector3) -> Vector3:
	for qual in _construcoes:
		var sala: Node3D = _construcoes[qual]["sala"]
		var de_dentro: bool = sala.contem(de)
		if de_dentro == sala.contem(para):
			continue
		var fora: Vector3 = sala.soleira_de_fora()
		var por_dentro: Vector3 = sala.soleira_de_dentro()
		if sala.no_vao(de):
			return fora if de_dentro else por_dentro
		return por_dentro if de_dentro else fora
	return para


func _process(delta: float) -> void:
	atualizar_agora()
	_ronda_em -= delta
	if _jogador != null and (_ronda_em <= 0.0 or not _onde_da_ronda.is_finite()):
		_conferir_a_ronda()


func _conferir_a_ronda() -> void:
	_ronda_em = RONDA
	_onde_da_ronda = _jogador.global_position
	_ronda()


## A RONDA DOS CÔMODOS DE PERTO: manda montar o que o jogador alcançou, e esconde o que
## ele deixou longe (a sala escondida continua lá, com a física e o que tem dentro: só
## deixa de ser desenhada, com as luzes). Nunca esconde a sala em que ele está.
func _ronda() -> void:
	if _mundo == null or not is_inside_tree():
		return
	var onde: Vector3 = _jogador.global_position
	if _montando == "":
		var mais_perto := ""
		var menor := CRIA_ATE
		for qual in _pendentes:
			var distancia := _distancia_do_lote(str(qual), onde)
			if distancia <= menor:
				menor = distancia
				mais_perto = str(qual)
		if mais_perto != "":
			_montar_de_perto(mais_perto, segura_o_jogador and menor < LOTE_COLADO)
	for qual in _construcoes:
		if not bool(_construcoes[qual].get("preguicosa", false)):
			continue
		var sala: Node3D = _construcoes[qual]["sala"]
		var longe := Vector2(sala.global_position.x - onde.x, sala.global_position.z - onde.z).length()
		if sala.visible and longe > ESCONDE_ALEM and qual != _dentro:
			sala.visible = false
		elif not sala.visible and longe < CRIA_ATE:
			sala.visible = true


## Monta o cômodo de `qual` porque o jogador chegou. Se chegou de uma vez ao pé da casa (o save que o
## põe dentro dela, um pulo no mapa), ele pode estar DENTRO da caixa inteira que ainda cobre a casa:
## fica parado até o cômodo estar de pé, e só então volta a andar: lá dentro, e não expulso pela caixa.
func _montar_de_perto(qual: String, segurar_o_jogador: bool) -> void:
	var andava: bool = segurar_o_jogador and _jogador.is_physics_processing()
	if andava:
		_jogador.set_physics_process(false)
	await garantir(qual)
	if andava and is_instance_valid(_jogador):
		_jogador.set_physics_process(true)


## A distância, no chão, do ponto até o lote do cômodo (INF se o lote não existe).
func _distancia_do_lote(qual: String, ponto: Vector3) -> float:
	var lote := _ancora_de(qual, _tabela.get(qual, {}))
	if lote == "" or not ("ancoras" in _mundo) or not _mundo.ancoras.has(lote):
		return INF
	var base: Vector3 = _mundo.ancoras[lote]
	return Vector2(base.x - ponto.x, base.z - ponto.z).length()


## Em que cômodo o jogador está, de uma vez, sem esperar o quadro: quem põe o
## corpo noutro lugar (`teleportar`) pergunta antes de encaixar a câmera, e ela
## não mede o lugar novo com as paredes do lugar velho.
##
## QUEM JÁ ESTÁ DENTRO FICA DENTRO um palmo além da porta (`FOLGA_DE_SAIR`): o
## corpo parado na soleira, ou o passo que vai e volta, não pode trocar a câmera
## de cima pela de passeio, e de volta, a cada quadro.
func atualizar_agora() -> void:
	if _jogador == null:
		return
	# Um pulo (o `teleportar`, o save): a ronda dos cômodos de perto não espera o próximo quadro.
	if not _pendentes.is_empty() and _onde_da_ronda.is_finite() and _jogador.global_position.distance_to(_onde_da_ronda) > PULO:
		_conferir_a_ronda()
	var agora := contem(_jogador.global_position)
	if agora == "" and _dentro != "" and sala_de(_dentro) != null \
			and bool((sala_de(_dentro) as Node3D).call("contem", _jogador.global_position, FOLGA_DE_SAIR)):
		agora = _dentro
	if agora == _dentro:
		return
	var antes := _dentro
	_dentro = agora
	if "dentro_de" in _jogador:
		_jogador.dentro_de = agora
	for qual in _construcoes:
		(_construcoes[qual]["sala"] as Node3D).camera_do_lado_de_dentro(qual == agora)
	var sala_de_agora = sala_de(agora)
	if _jogador.has_method("camera_de_cima"):
		var de_cima: bool = sala_de_agora != null and bool(sala_de_agora.camera_de_cima)
		_jogador.camera_de_cima(de_cima, sala_de_agora.corpos_do_comodo() if de_cima else ([] as Array[RID]))
	if antes != "":
		saiu.emit(antes)
	if agora != "":
		entrou.emit(agora)


# --- montar um cômodo -----------------------------------------------------------

## A porta que a construção declara, a de fábrica quando ninguém a leu, e o resto do que
## o modelo do GLB traz (a medida que se sobrepõe à da casca, a altura do forro).
const PORTA_DE_FABRICA := {"porta_x": 0.92, "largura_da_porta": 1.05, "altura_da_porta": 2.15, "sonda": 1.6}
## A parede fina das cascas que medem pouco por dentro (a palhoça, a capelinha), para a
## sala não ficar menor que um quarto de gente: abaixo de tanto de largura ou de
## comprimento úteis, com a parede inteira, a de 0,4 passa a 0,15.
const PAREDE_FINA := 0.15
const PEQUENA_LARGURA := 3.7
const PEQUENO_COMPRIMENTO := 3.2


## Monta o cômodo de `qual` na casca dele. Devolve MONTOU, ADIAR (a casa ainda não subiu
## no vale: tenta de novo) ou FALHOU (a casca não mediu: não tenta mais).
func _abrir(qual: String) -> int:
	var dado: Dictionary = _tabela[qual]
	var ancora := _ancora_de(qual, dado)
	if ancora == "":
		return FALHOU
	if _mundo == null or not ("ancoras" in _mundo) or not _mundo.ancoras.has(ancora):
		return FALHOU
	var preguicosa := bool(dado.get("preguicosa", false))
	var base: Vector3 = _mundo.ancoras[ancora]
	var frente := _frente(ancora)
	if str(dado.get("tipo", "")) == "galpao":
		return _abrir_galpao(qual, dado, ancora, base, frente)
	var chao: float = _mundo.ground_height_at(base)
	var centro := Vector3(base.x, chao, base.z)
	var construcoes = _mundo.get("construcoes")
	var lote: Dictionary = construcoes.get(ancora, {}) if construcoes is Dictionary else {}
	var modelo: Node3D = lote.get("modelo") if is_instance_valid(lote.get("modelo")) else null
	if modelo == null and qual == "igreja":
		modelo = _mundo.get_node_or_null(ancora.capitalize() + "Tripo")
	if modelo == null and preguicosa:
		# A casa ainda não subiu (o casarão sobe depois dos cômodos).
		return ADIAR
	dado = _com_a_porta_do_modelo(dado, lote, modelo)
	if dado.has("deslocar_z"):
		centro += frente * float(dado["deslocar_z"])
	var malhas := _malhas_da_casca(modelo, centro, frente, dado.get("meio_lote", Vector2(3.4, 3.2)))
	if malhas.is_empty():
		return ADIAR if preguicosa else FALHOU
	var caixa_inteira: Node = lote.get("colisao") if is_instance_valid(lote.get("colisao")) else null
	if caixa_inteira == null and modelo != null and qual == "igreja":
		caixa_inteira = _mundo.get_node_or_null(str(dado.get("colisao", "")))
	var medida: Dictionary = await _medir(malhas, centro, frente, caixa_inteira, dado)
	if medida.is_empty():
		return FALHOU
	var sala := _nova_sala(qual, dado)
	if sala == null:
		return FALHOU
	_tirar_a_colisao_inteira(caixa_inteira, modelo, centro, frente, medida)
	if modelo != null:
		_casca_so_por_fora(modelo)

	# A parede do cômodo fica FOLGA para dentro da casca; a da frente, rente
	# ao lado de dentro da porta. A origem do cômodo é o meio da fachada, por
	# dentro, e o cômodo corre para trás (-Z), longe da fachada. Casca que mede pouco
	# leva parede fina (só as casas por dados: as quatro de tabela ficam como estavam).
	var espessura := Comodo.PAREDE
	var meia_largura: float = float(medida["lado"]) - FOLGA - espessura
	var ate_a_frente: float = float(medida["frente"]) - FOLGA - espessura
	var ate_o_fundo: float = float(medida["fundo"]) - FOLGA - espessura
	if not CONSTRUCOES.has(qual) and (meia_largura * 2.0 < PEQUENA_LARGURA or ate_a_frente + ate_o_fundo < PEQUENO_COMPRIMENTO):
		espessura = PAREDE_FINA
		meia_largura = float(medida["lado"]) - FOLGA - espessura
		ate_a_frente = float(medida["frente"]) - FOLGA - espessura
		ate_o_fundo = float(medida["fundo"]) - FOLGA - espessura
	var chao_da_nave: float = float(medida["chao"])
	var pe_direito: float = float(medida["teto"]) - chao_da_nave - 0.25
	if dado.has("pe_direito_max"):
		pe_direito = minf(pe_direito, float(dado["pe_direito_max"]))
	sala.configurar({
		"parede": espessura,
		"largura": meia_largura * 2.0,
		"comprimento": ate_a_frente + ate_o_fundo,
		"pe_direito": pe_direito,
		"fundo_da_porta": float(medida["fachada"]) - (ate_a_frente + espessura),
		"soleira": chao_da_nave - float(medida["soleira"]),
		"degrau_de_fora": float(medida["soleira"]) - float(medida["terreno"]),
		"borda": float(medida["borda"]) - ate_a_frente,
		"livre": float(medida["livre"]),
		"porta_x": float(dado["porta_x"]),
		"largura_da_porta": float(dado["largura_da_porta"]),
		"altura_da_porta": float(dado["altura_da_porta"]),
		# A casca de fora (#205): quanto a colisão ainda tem de avançar para fora, por lado,
		# até a face visível da parede; e onde, no cômodo, está a face de fora da fachada.
		"fora_direita": _sobra_de_fora(medida, "fora_direita", float(medida["lado"])),
		"fora_esquerda": _sobra_de_fora(medida, "fora_esquerda", float(medida["lado"])),
		"fora_fundo": _sobra_de_fora(medida, "fora_fundo", float(medida["fundo"])),
		"fachada_de_fora": (float(medida["fachada_lados"]) - ate_a_frente + MARGEM_DE_FORA) if medida.has("fachada_lados") else 0.0,
	})
	sala.name = "Interior_" + qual
	# A casca que some para a câmera de cima: o modelo, ou as malhas do lote.
	sala.casca = [modelo] if modelo != null else malhas
	add_child(sala)
	sala.global_transform = Transform3D(Basis.looking_at(-frente, Vector3.UP),
		centro + frente * ate_a_frente + Vector3.UP * chao_da_nave)
	_construcoes[qual] = {"sala": sala, "nome": str(dado["nome"]), "ancora": ancora, "preguicosa": preguicosa}
	return MONTOU


## O cômodo vazio de `qual`: a nave da igreja, a casa de função (a herdada, a do Pedro, a da
## Zefa), o casarão, ou a casa de perfil por dados.
func _nova_sala(qual: String, dado: Dictionary) -> Node3D:
	match qual:
		"igreja":
			return InteriorIgreja.new()
		"casa", "casa_pedro", "casa_zefa":
			var casa := InteriorCasa.new()
			casa.perfil = str(dado.get("perfil", "herdada"))
			return casa
	var perfis: Dictionary = _dados.get("perfis", {})
	var nome_do_perfil := str(dado.get("perfil", ""))
	if not perfis.has(nome_do_perfil):
		push_warning("Interiores: '%s' pede o perfil '%s', que não está em %s." % [qual, nome_do_perfil, ARQUIVO_DAS_CASAS])
		return null
	var sala: Node3D = InteriorCasarao.new() if str(dado.get("tipo", "casa")) == "casarao" else InteriorCasa.new()
	sala.perfil = nome_do_perfil
	sala.dados_do_perfil = perfis[nome_do_perfil]
	sala.pegadas_das_pecas = _dados.get("pecas", {})
	return sala


## UM GALPÃO ABERTO, a casa de farinha: três paredes, o forno e os bancos, e a frente
## aberta. O modelo não tem cômodo para medir, e a caixa inteira que o catálogo põe nele
## fecha o que o desenho deixa aberto: ela sai, e entram as caixas de `caixas` (do
## arquivo, no referencial do modelo: x para a direita de quem olha de frente, z para a
## frente, o chão no pé do modelo), nas medidas que a planta do GLB mostra.
func _abrir_galpao(qual: String, dado: Dictionary, ancora: String, base: Vector3, frente: Vector3) -> int:
	var construcoes = _mundo.get("construcoes")
	var lote: Dictionary = construcoes.get(ancora, {}) if construcoes is Dictionary else {}
	var modelo: Node3D = lote.get("modelo") if is_instance_valid(lote.get("modelo")) else null
	if modelo == null:
		return ADIAR
	var caixa_inteira: Node = lote.get("colisao") if is_instance_valid(lote.get("colisao")) else null
	if caixa_inteira != null:
		caixa_inteira.queue_free()
	var corpo := StaticBody3D.new()
	corpo.name = "Galpao_" + qual
	corpo.collision_layer = Camadas.MUNDO_E_CAMERA
	add_child(corpo)
	var direita := Vector3.UP.cross(frente).normalized()
	var giro := atan2(frente.x, frente.z)
	for caixa: Dictionary in dado.get("caixas", []):
		var tamanho := Vector3(float(caixa["tam"][0]), float(caixa["tam"][1]), float(caixa["tam"][2]))
		var forma := CollisionShape3D.new()
		var formato := BoxShape3D.new()
		formato.size = tamanho
		forma.shape = formato
		corpo.add_child(forma)
		forma.global_position = base + direita * float(caixa["x"]) + frente * float(caixa["z"]) + Vector3.UP * (tamanho.y * 0.5)
		forma.global_rotation.y = giro
	_galpoes[qual] = corpo
	return MONTOU


## A construção com a porta do modelo dela: os campos que ela não traz, vêm de `modelos`
## (a chave do GLB que o vale pôs no lote, ou a do nome do nó) e, por fim, da porta de fábrica.
func _com_a_porta_do_modelo(dado: Dictionary, lote: Dictionary, modelo: Node3D) -> Dictionary:
	var completo := dado.duplicate(true)
	var chave := str(lote.get("chave", ""))
	if chave == "" and modelo != null:
		chave = _chave_do_modelo(modelo)
	if chave == "":
		chave = str(dado.get("modelo", ""))
	var do_modelo: Dictionary = (_dados.get("modelos", {}) as Dictionary).get(chave, {})
	for campo in do_modelo:
		if not completo.has(campo):
			completo[campo] = do_modelo[campo]
	if not completo.has("porta_x") and do_modelo.is_empty():
		push_warning("Interiores: a porta do modelo '%s' não foi lida em %s; vale a da casa de taipa." % [chave, ARQUIVO_DAS_CASAS])
	for campo in PORTA_DE_FABRICA:
		if not completo.has(campo):
			completo[campo] = PORTA_DE_FABRICA[campo]
	return completo


## A chave do catálogo de um modelo posto pelo `CatalogoAssets.instanciar`, pelo nome do nó
## ("Casa Taipa AzulTripo" -> "casa_taipa_azul"): para o lote que não a guardou.
func _chave_do_modelo(modelo: Node3D) -> String:
	var nome := str(modelo.name)
	var fim := nome.find("Tripo")
	if fim <= 0:
		return ""
	return nome.substr(0, fim).strip_edges().to_snake_case()


func _frente(ancora: String) -> Vector3:
	var frente: Vector3 = _mundo.ancoras.get(ancora + "Frente", Vector3.BACK)
	frente.y = 0.0
	return frente.normalized() if frente.length() > 0.01 else Vector3.BACK


## As malhas que formam a casca: as do modelo do Tripo, ou, no procedural, as
## do mundo que estão dentro do lote da construção (`meio_lote`: de lado, e de
## frente e fundo).
func _malhas_da_casca(modelo: Node3D, centro: Vector3, frente: Vector3, meio_lote: Vector2) -> Array:
	var lista: Array = []
	if modelo != null:
		for no in modelo.find_children("*", "MeshInstance3D", true, false):
			lista.append(no)
		return lista
	var lado := frente.cross(Vector3.UP).normalized()
	for no in _mundo.get_children():
		if not (no is MeshInstance3D):
			continue
		var onde: Vector3 = (no as MeshInstance3D).global_position - centro
		if absf(onde.dot(lado)) < meio_lote.x and absf(onde.dot(frente)) < meio_lote.y and onde.y > -0.5 and onde.y < 12.0:
			lista.append(no)
	return lista


## A MEDIDA DA CASCA, por dentro e pela fachada, em unidades a partir do centro
## da construção no chão. Raios contra uma colisão provisória da própria malha:
##
##   lado     metade da largura por dentro, à altura de um homem
##   frente   do centro até a parede da fachada, por dentro (o menor dos três
##            pontos do meio: a porta pintada costuma ser rebaixada)
##   fundo    do centro até a parede do fundo, por dentro
##   fachada  do centro até a face de FORA da fachada, no meio da porta
##   teto     a altura do beiral junto das paredes, por dentro
##   chao     a altura do chão da nave: o da casca, ou a soleira, o que for maior
##   soleira  a altura do patamar de FORA, na porta: o que o corpo pisa ao
##            chegar — no Tripo, o topo da escadaria de pedra que o vale põe
##            na frente da igreja; no procedural, o chão. Medido contra a
##            colisão do mundo, sem a caixa inteira que vai sair.
func _medir(malhas: Array, centro: Vector3, frente: Vector3, caixa_inteira: Node, dado: Dictionary) -> Dictionary:
	var corpo := StaticBody3D.new()
	corpo.name = "MedidaDaCasca"
	corpo.collision_layer = CAMADA_DE_MEDIR
	corpo.collision_mask = 0
	_mundo.add_child(corpo)
	for malha in malhas:
		var mi := malha as MeshInstance3D
		if mi.mesh == null:
			continue
		var forma := mi.mesh.create_trimesh_shape()
		if forma == null:
			continue
		forma.backface_collision = true
		var cs := CollisionShape3D.new()
		cs.shape = forma
		corpo.add_child(cs)
		cs.global_transform = mi.global_transform
	await get_tree().physics_frame
	await get_tree().physics_frame
	var espaco: PhysicsDirectSpaceState3D = _mundo.get_world_3d().direct_space_state
	var lado := frente.cross(Vector3.UP).normalized()
	# Onde fica a porta: `porta_x` é do meio para a direita de quem olha a
	# casa de frente, que é o +X do cômodo.
	var na_porta := Vector3.UP.cross(frente).normalized() * float(dado.get("porta_x", 0.0))
	var medida := {}
	var meio_1 := centro + Vector3.UP * 1.5
	var meio_2 := centro + Vector3.UP * 2.2
	var lado_mais := minf(_distancia(espaco, meio_1, lado), _distancia(espaco, meio_2, lado))
	var lado_menos := minf(_distancia(espaco, meio_1, -lado), _distancia(espaco, meio_2, -lado))
	medida["lado"] = minf(lado_mais, lado_menos)
	medida["fundo"] = minf(_distancia(espaco, meio_1, -frente), _distancia(espaco, meio_2, -frente))
	var frente_por_dentro := INF
	for x in [-0.5, 0.0, 0.5]:
		frente_por_dentro = minf(frente_por_dentro, _distancia(espaco, meio_1 + na_porta + lado * x, frente))
	medida["frente"] = frente_por_dentro
	# O que o modelo diz que a malha não deixa medir (a venda, o restaurante: a porta
	# é uma alcova maciça, e raio deitado bate nela): o resto da medida parte disto.
	_sobrepor(medida, dado)
	# A face de fora da fachada, na porta, vinda de longe na direção do centro.
	var de_fora := meio_1 + na_porta + frente * 30.0
	var na_fachada := _raio(espaco, de_fora, meio_1 + na_porta)
	medida["fachada"] = (na_fachada - centro).dot(frente) if na_fachada.is_finite() else frente_por_dentro
	# O beiral, junto das paredes: o menor teto de três pontos de cada lado.
	var teto := INF
	for x in [-1.0, 1.0]:
		for z in [-0.5, 0.0, 0.5]:
			var ponto: Vector3 = centro + lado * x * (float(medida["lado"]) - 0.35) \
				+ frente * z * float(medida["fundo"]) + Vector3.UP * 1.0
			var acima := _raio(espaco, ponto, ponto + Vector3.UP * 30.0)
			if acima.is_finite():
				teto = minf(teto, acima.y - centro.y)
	medida["teto"] = teto if is_finite(teto) else 4.5
	# O chão: o da casca por dentro, e a soleira da escadaria pela frente.
	var de_cima := centro + Vector3.UP * 3.0
	var no_chao := _raio(espaco, de_cima, centro - Vector3.UP * 2.0)
	var chao_de_dentro: float = (no_chao.y - centro.y) if no_chao.is_finite() else 0.0
	var diante := centro + na_porta + frente * (float(medida["fachada"]) + 0.35) + Vector3.UP * float(dado.get("sonda", 8.0))
	var degrau := _raio(espaco, diante, diante - Vector3.UP * 12.0)
	var soleira: float = (degrau.y - centro.y) if degrau.is_finite() else 0.0
	medida["chao"] = clampf(maxf(chao_de_dentro, soleira), 0.0, 2.0)
	# O patamar de fora, contra a colisão do mundo (camada 1), um palmo além
	# da fachada — sem a caixa inteira da construção, que sai em seguida.
	var no_patamar := centro + na_porta + frente * (float(medida["fachada"]) + 0.3) + Vector3.UP * 4.0
	var pergunta := PhysicsRayQueryParameters3D.create(no_patamar, no_patamar - Vector3.UP * 10.0, 1)
	if caixa_inteira is CollisionObject3D:
		pergunta.exclude = [(caixa_inteira as CollisionObject3D).get_rid()]
	var patamar: Vector3 = espaco.intersect_ray(pergunta).get("position", Vector3.INF)
	medida["soleira"] = (patamar.y - centro.y) if patamar.is_finite() else \
		(_mundo.ground_height_at(no_patamar) - centro.y)
	# ONDE O PATAMAR ACABA, e o chão do adro logo depois: o alicerce de pedra em
	# que o vale assenta a igreja fica um palmo acima do adro, e a quina dele
	# trava o corpo. Raios de cima para baixo, saindo da fachada a cada cinco
	# dedos, até o chão cair abaixo do patamar. (Um raio deitado, de fora para
	# dentro, batia no cruzeiro, que fica na frente da igreja.)
	medida["borda"] = float(medida["fachada"])
	medida["terreno"] = float(medida["soleira"])
	var passo := 0.05
	while passo < 4.0:
		var ponto := centro + na_porta + frente * (float(medida["fachada"]) + passo)
		var altura := _altura_do_mundo(espaco, ponto, centro.y + float(medida["soleira"]), pergunta.exclude)
		if is_finite(altura) and altura < centro.y + float(medida["soleira"]) - 0.05:
			medida["borda"] = float(medida["fachada"]) + passo - 0.025
			break
		passo += 0.05
	if float(medida["borda"]) > float(medida["fachada"]):
		var no_pe := centro + na_porta + frente * (float(medida["borda"]) + 0.9)
		var no_adro := _altura_do_mundo(espaco, no_pe, centro.y + float(medida["soleira"]), pergunta.exclude)
		if is_finite(no_adro):
			medida["terreno"] = no_adro - centro.y
	# O CHÃO LIVRE na frente da porta, até o primeiro estorvo: raios deitados,
	# na altura do joelho e do peito, da fachada para fora.
	medida["livre"] = 3.0
	for altura in [0.3, 1.0]:
		var de: Vector3 = centro + na_porta + frente * (float(medida["fachada"]) + 0.05) \
			+ Vector3.UP * (float(medida["soleira"]) + altura)
		var adiante := PhysicsRayQueryParameters3D.create(de, de + frente * 3.0, 1)
		adiante.exclude = pergunta.exclude
		var estorvo: Vector3 = espaco.intersect_ray(adiante).get("position", Vector3.INF)
		if estorvo.is_finite():
			medida["livre"] = minf(float(medida["livre"]), (estorvo - de).dot(frente) + 0.05)
	_medir_a_face_de_fora(espaco, centro, frente, medida, dado)
	corpo.queue_free()
	_sobrepor(medida, dado)
	# Do centro à parede da frente pode ser pouco (a venda e o restaurante têm o meio da
	# casca colado na fachada): o que não pode é a casca não medir.
	for chave in ["lado", "frente", "fundo"]:
		if not is_finite(float(medida[chave])) or float(medida[chave]) < (0.9 if chave == "frente" else 1.5):
			push_warning("Interiores: a casca da construção não mediu '%s' (%s); o cômodo não foi montado." % [chave, str(medida[chave])])
			return {}
	return medida


## Quanto a parede do cômodo, que acaba `FOLGA` para dentro da face de dentro (`dentro`, do
## centro), ainda tem de avançar para fora até a face de fora medida (`chave`). Sem medida, ou
## com a medida de um beiral, zero.
func _sobra_de_fora(medida: Dictionary, chave: String, dentro: float) -> float:
	if not medida.has(chave):
		return 0.0
	var sobra: float = float(medida[chave]) - (dentro - FOLGA) + MARGEM_DE_FORA
	return clampf(sobra, 0.0, LIMITE_DA_CASCA_DE_FORA)


## A FACE DE FORA DAS PAREDES (#205), contra a mesma colisão provisória da casca: raios vindos
## de longe, da direita, da esquerda, de trás e da frente, em duas alturas de peito e em cinco
## pontos de cada parede. De cada ponto vale a face mais saliente das duas alturas; da parede,
## a MEDIANA dos pontos — o pilar do alpendre ou a quina que sai num ponto só não engorda a
## colisão da parede inteira. Escreve em `medida`: fora_direita, fora_esquerda e fora_fundo
## (do centro à face), e fachada_lados (a fachada fora do vão da porta, do centro à face).
func _medir_a_face_de_fora(espaco: PhysicsDirectSpaceState3D, centro: Vector3, frente: Vector3, medida: Dictionary, dado: Dictionary) -> void:
	for chave in ["lado", "frente", "fundo", "chao"]:
		if not is_finite(float(medida.get(chave, INF))):
			return
	var direita := Vector3.UP.cross(frente).normalized()
	var piso: float = centro.y + float(medida["chao"])
	var fracoes := [-0.6, -0.3, 0.0, 0.3, 0.6]
	var alturas := [0.7, 1.3]
	for sinal in [1.0, -1.0]:
		var distancias: Array[float] = []
		for fracao in fracoes:
			var ao_longo: float = float(fracao) * (float(medida["frente"]) if fracao > 0.0 else float(medida["fundo"]))
			var ponto := Vector3(centro.x, 0.0, centro.z) + frente * ao_longo
			var d := _face_mais_saliente(espaco, ponto, piso, alturas, direita * sinal)
			if is_finite(d):
				distancias.append(d)
		if not distancias.is_empty():
			medida["fora_direita" if sinal > 0.0 else "fora_esquerda"] = _mediana(distancias)
	var do_fundo: Array[float] = []
	var da_fachada: Array[float] = []
	var meia_porta: float = float(dado.get("largura_da_porta", 1.0)) * 0.5 + 0.3
	for fracao in [-0.8, -0.55, -0.3, 0.0, 0.3, 0.55, 0.8]:
		var x: float = float(fracao) * float(medida["lado"])
		var ponto := Vector3(centro.x, 0.0, centro.z) + direita * x
		var d_fundo := _face_mais_saliente(espaco, ponto, piso, alturas, -frente)
		if is_finite(d_fundo):
			do_fundo.append(d_fundo)
		if absf(x - float(dado.get("porta_x", 0.0))) > meia_porta:
			var d_frente := _face_mais_saliente(espaco, ponto, piso, alturas, frente)
			if is_finite(d_frente):
				da_fachada.append(d_frente)
	if not do_fundo.is_empty():
		medida["fora_fundo"] = _mediana(do_fundo)
	if not da_fachada.is_empty():
		medida["fachada_lados"] = _mediana(da_fachada)


## A distância, do ponto (no plano) até a face de fora mais saliente da casca na direção `para_fora`,
## nas `alturas` acima do `piso`, ou INF se nenhum raio bate.
func _face_mais_saliente(espaco: PhysicsDirectSpaceState3D, ponto: Vector3, piso: float, alturas: Array, para_fora: Vector3) -> float:
	var melhor := -INF
	for altura in alturas:
		var de := Vector3(ponto.x, piso + float(altura), ponto.z)
		var bate := _raio(espaco, de + para_fora * 30.0, de)
		if bate.is_finite():
			melhor = maxf(melhor, (bate - de).dot(para_fora))
	return melhor if is_finite(melhor) else INF


static func _mediana(valores: Array[float]) -> float:
	var ordem := valores.duplicate()
	ordem.sort()
	return float(ordem[int(ordem.size() / 2.0)])


## Troca da medida o que o modelo traz medido à mão (`medida` do `data/interiores_casas.json`).
func _sobrepor(medida: Dictionary, dado: Dictionary) -> void:
	var fixa: Dictionary = dado.get("medida", {})
	for campo in fixa:
		medida[campo] = float(fixa[campo])


func _raio(espaco: PhysicsDirectSpaceState3D, de: Vector3, para: Vector3) -> Vector3:
	var pergunta := PhysicsRayQueryParameters3D.create(de, para, CAMADA_DE_MEDIR)
	pergunta.hit_back_faces = true
	return espaco.intersect_ray(pergunta).get("position", Vector3.INF)


## A altura do que se pisa neste ponto, na colisão do mundo (camada 1), de um
## metro acima de `ate` para baixo.
func _altura_do_mundo(espaco: PhysicsDirectSpaceState3D, ponto: Vector3, ate: float, fora: Array) -> float:
	var de_cima := Vector3(ponto.x, ate + 1.0, ponto.z)
	var pergunta := PhysicsRayQueryParameters3D.create(de_cima, de_cima - Vector3.UP * 4.0, 1)
	pergunta.exclude = fora
	var onde: Vector3 = espaco.intersect_ray(pergunta).get("position", Vector3.INF)
	return onde.y if onde.is_finite() else INF


func _distancia(espaco: PhysicsDirectSpaceState3D, de: Vector3, direcao: Vector3) -> float:
	var ponto := _raio(espaco, de, de + direcao * 30.0)
	return (ponto - de).dot(direcao) if ponto.is_finite() else INF


## TIRA A COLISÃO INTEIRA da construção: a caixa que o catálogo pôs no Tripo,
## ou, no procedural, os corpos das caixas da construção dentro do lote. O
## cômodo põe a dele no lugar.
func _tirar_a_colisao_inteira(caixa: Node, modelo: Node3D, centro: Vector3, frente: Vector3, medida: Dictionary) -> void:
	if modelo != null:
		if caixa != null:
			caixa.queue_free()
		return
	var lado := frente.cross(Vector3.UP).normalized()
	for no in _mundo.get_children():
		if not (no is StaticBody3D) or str(no.name) == "MedidaDaCasca":
			continue
		var onde: Vector3 = (no as StaticBody3D).global_position - centro
		if absf(onde.dot(lado)) <= float(medida["lado"]) + 0.6 \
				and onde.dot(frente) <= float(medida["fachada"]) + 0.6 \
				and onde.dot(frente) >= -float(medida["fundo"]) - 0.8 and onde.y < 12.0:
			no.queue_free()


## A CASCA SÓ POR FORA: material de dois lados desenharia a parede também de
## dentro, e o vão da porta mostraria o avesso da porta pintada em vez do adro.
## Só nesta construção, e com cópia do material, para não mexer em mais ninguém.
func _casca_so_por_fora(modelo: Node3D) -> void:
	for no in modelo.find_children("*", "MeshInstance3D", true, false):
		var mi := no as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var material := mi.get_active_material(i)
			if material is BaseMaterial3D and (material as BaseMaterial3D).cull_mode != BaseMaterial3D.CULL_BACK:
				var copia := (material as BaseMaterial3D).duplicate() as BaseMaterial3D
				copia.cull_mode = BaseMaterial3D.CULL_BACK
				mi.set_surface_override_material(i, copia)


## OS CORPOS NA LUZ DE DENTRO: as luzes do cômodo só acendem a camada dele e a
## dos corpos (ver `comodo.gd`). O jogador e os moradores entram nela,
## para a vela do altar iluminar quem chega perto dela.
func marcar_os_corpos() -> void:
	var corpos: Array = []
	if _jogador != null:
		corpos.append(_jogador)
	for morador in get_tree().get_nodes_in_group("moradores"):
		corpos.append(morador)
	for corpo in corpos:
		for no in (corpo as Node).find_children("*", "GeometryInstance3D", true, false):
			(no as GeometryInstance3D).layers |= Comodo.CAMADA_DOS_CORPOS
