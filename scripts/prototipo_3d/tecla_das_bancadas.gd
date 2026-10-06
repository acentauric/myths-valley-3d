extends Node
## O E NAS BANCADAS E NOS SÍTIOS DE OBRA: perto da bancada da oficina, a tecla
## abre a aba Oficina do painel; perto da fogueira do terreiro, a do fogão; perto
## do poço, da ponte, do mirante, do cemitério ou da carroça, a aba de obras
## daquele sítio. O J continua abrindo tudo isso, como abre toda aba de lugar
## (`BancadasVale.aplicar`).
##
## "Não consegui progredir nas missões porque a bancada não tem asset e não
## consegui interagir." No 2D a bancada e o fogão se usam como a cama e o baú:
## encosta e aperta E ("Encoste nela e aperte E: ali a lenha vira tábua e vira
## corda"). No vale só o J abria, e nada na bancada dizia isso; quem chegava
## nela apertava o E, e nada acontecia.
##
## O MESMO VALIA PARA OS SÍTIOS DE OBRA: "não consegui interagir com o poço, logo
## essa missão quebrou". Seis passos de missão fecham numa obra (o poço, a
## ponte, o mirante, o cemitério, a carroça e a mesa do prumo), e só a mesa do
## prumo respondia ao E. No poço a tecla só chegava a quem estivesse mais perto —
## o Pedro, que segue o jogador, a Dona Zefa e o Cosme, que o mutirão põe numa
## roda de dois passos e meio em volta dele —, e a conversa deles não dizia nada
## de obra. Agora o sítio responde, com a dica em cima dele, e o E abre o painel
## direto na aba de obras DAQUELE sítio.
##
## QUANDO O SÍTIO ACENDE: com obra para fazer ali (`Obras.disponiveis`) ou quando
## o passo de agora de alguma missão manda tocar a obra ali. A segunda é a que
## importa para o foco (`foco_do_e.gd`): o sítio que a missão pede entra com viés
## (`vies_da_obra_pedida`), e vence o morador parado ao lado do jogador — o Pedro
## não deixa de ser gente, mas a missão não pede conversa nenhuma com ele. Virado
## para o morador, ele ainda leva o E: quem quer conversar se vira para a pessoa.
##
## Mesmo molde da casa (`casa_do_jogador.gd`): a dica da tecla em cima do lugar
## e o E no `_unhandled_key_input`. O `Prototype` o põe antes de todo mundo que
## ouve o E — as lápides, as árvores, os lajedos, a pesca, os achados, a luta —,
## e quem entra depois recebe a tecla primeiro: com alvo mais preciso à mão, o
## E é deles.

const DicaTecla = preload("res://scripts/prototipo_3d/dica_tecla.gd")
const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")
const BancadasVale = preload("res://scripts/prototipo_3d/bancadas_vale.gd")
const PainelVale = preload("res://scripts/prototipo_3d/painel_vale.gd")
const FocoDoE = preload("res://scripts/prototipo_3d/foco_do_e.gd")
const CadeiaDeMissoes = preload("res://scripts/prototipo_3d/cadeia_de_missoes.gd")
const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")

## Os lugares do E: a bancada (`BancadasVale.OBRAS`/`BANCADAS`), a aba que abre e
## o rótulo da dica.
const LUGARES := {
	"oficina": {"aba": PainelVale.Aba.OFICINA, "rotulo": "Oficina"},
	# A mesa do prumo abre a aba de obras dela ("Chegue no canteiro e aperte E.
	# Abre a aba de obras daquela mesa", no 2D).
	"canteiro": {"aba": PainelVale.Aba.OBRAS, "rotulo": "Canteiro"},
	"cozinha": {"aba": PainelVale.Aba.COZINHA, "rotulo": "Cozinhar"},
}
## O que a dica dos sítios de obra diz, nos três idiomas. Os sítios são os de
## `BancadasVale.OBRAS` que têm `raio_do_e` — o poço da #80 ("Não tá interagindo. A
## missão é consertar o poço", no teste ao vivo de 05/10), a ponte, o mirante, o
## cemitério e a carroça. O trapiche, a casa e o armazém ficam sem E de propósito: no
## trapiche o E seria do Tonho, parado ali, e a casa tem a porta, a cama e o baú.
const ARQUIVO_DOS_ROTULOS := "res://data/dicas_do_e_nas_obras.json"
## A dica fica em cima da bancada, e não no pé dela.
const ALTURA_DA_DICA := 1.3
## Quanto antes do limite do E a distância até a âncora deixa de contar, quando a
## missão pede a obra do sítio (`vies_da_obra_pedida`).
const FOLGA_DA_OBRA_PEDIDA := 1.0

var _world
var _jogador: Node3D
## Abre o painel numa aba, e num sítio de obra se for o caso
## (`Prototype.abrir_o_painel`).
var _abrir: Callable
## Pode usar o E agora? (Ninguém lendo, nenhuma tela aberta: `Prototype`.)
var _livre: Callable
var _dica: PanelContainer
## O lugar ao alcance agora, ou "".
var _perto := ""
## O rótulo de cada sítio de obra, no idioma de agora, lido do arquivo uma vez (o
## idioma só muda no menu, e o vale se refaz): `IdiomaMenu.campo` abre o arquivo de
## preferências a cada pergunta, e a dica pergunta a cada quadro.
var _rotulos: Dictionary = {}


func configurar(world, jogador: Node3D, hud, abrir: Callable, livre: Callable) -> void:
	_world = world
	_jogador = jogador
	_abrir = abrir
	_livre = livre
	var dos_rotulos: Dictionary = Jogo.dados(ARQUIVO_DOS_ROTULOS)
	for qual: String in BancadasVale.com_e():
		var dado = dos_rotulos.get(qual, {})
		var texto := str(IdiomaMenu.campo(dado, "rotulo", "")) if dado is Dictionary else ""
		_rotulos[qual] = texto if texto != "" else BancadasVale.nome(qual)
	_dica = DicaTecla.criar(hud.map_layer(), Atalhos.letra("interagir"), "")
	add_to_group(FocoDoE.GRUPO)


## O QUE O E FARIA AQUI, para o foco (`foco_do_e.gd`): abrir a aba da bancada, ou
## as obras do sítio — com viés quando é a obra que a missão pede.
func alvo_do_e() -> Dictionary:
	if _perto == "" or _world == null:
		return {}
	var alvo := {"ponto": BancadasVale.ponto_da_provisoria(_world, _perto)}
	if _a_missao_pede(_perto):
		alvo["vies"] = vies_da_obra_pedida(_perto)
	return alvo


## O VIÉS DO SÍTIO QUE A MISSÃO PEDE, para o foco: dentro do E, a distância até a
## âncora NÃO CONTA — só o rumo. A âncora é o centro do poço, o meio da ponte, o
## meio das covas, e quem vai tocar a obra fica a dois, cinco, seis passos dela;
## um viés fixo serviria ao poço e deixaria o morador colado ganhar da ponte. Com a
## conta zerada, virado para o sítio o jogador o leva; virado para o morador, o
## morador (a dois passos, o foco desempata pelo rumo, como em tudo).
func vies_da_obra_pedida(qual: String) -> float:
	var d: float = BancadasVale.distancia(_world, _jogador.global_position, qual)
	return minf(d, maxf(BancadasVale.raio_do_e(qual) - FOLGA_DA_OBRA_PEDIDA, 0.0))


## O lugar ao alcance do jogador agora: "oficina", "canteiro", "cozinha", um
## sítio de obra ("poco", "ponte", "mirante", "cemiterio", "carroca") ou "".
func perto() -> String:
	return _perto


## O passo de agora de alguma missão manda tocar obra neste sítio?
func _a_missao_pede(qual: String) -> bool:
	return BancadasVale.raio_do_e(qual) > 0.0 \
		and CadeiaDeMissoes.obra_que_se_pede(get_tree(), qual) != ""


## O sítio tem o que fazer agora: obra à mão no painel, ou a missão a pede.
func _tem_obra(qual: String) -> bool:
	return _a_missao_pede(qual) or not Obras.disponiveis(qual).is_empty()


func _rotulo(qual: String) -> String:
	if LUGARES.has(qual):
		return tr(str(LUGARES[qual]["rotulo"]))
	return str(_rotulos.get(qual, ""))


func _process(_delta: float) -> void:
	if _jogador == null or _dica == null or _world == null:
		return
	_perto = ""
	var camera := get_viewport().get_camera_3d()
	var em_jogo: bool = camera != null and camera == _jogador.get("camera")
	if em_jogo and _jogador.is_physics_processing() and (not _livre.is_valid() or bool(_livre.call())):
		var menor := INF
		for qual: String in LUGARES:
			var d: float = BancadasVale.distancia(_world, _jogador.global_position, qual)
			if d <= BancadasVale.raio(qual) and d < menor:
				menor = d
				_perto = qual
		# OS SÍTIOS DE OBRA, com o raio do E (menor que o do J) e só com obra à mão.
		for qual: String in BancadasVale.com_e():
			var d: float = BancadasVale.distancia(_world, _jogador.global_position, qual)
			if d <= BancadasVale.raio_do_e(qual) and d < menor and _tem_obra(qual):
				menor = d
				_perto = qual
	if _perto == "" or not FocoDoE.e_dele(self):
		_dica.visible = false
		return
	var onde: Vector3 = BancadasVale.ponto_da_provisoria(_world, _perto)
	DicaTecla.mostrar_em(_dica, camera, onde + Vector3.UP * ALTURA_DA_DICA, _rotulo(_perto))


func _unhandled_key_input(event: InputEvent) -> void:
	if _perto == "":
		return
	if not (event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == Atalhos.tecla("interagir")):
		return
	if Dialogo.ocupado() or not _jogador.is_physics_processing() or not FocoDoE.e_dele(self):
		return
	get_viewport().set_input_as_handled()
	usar(_perto)


## Abre a aba do lugar — e, nos sítios de obra, as obras DELE, e não as do sítio
## mais perto pela regra do J. Público para o portão chamar sem simular tecla.
func usar(qual: String) -> void:
	if not _abrir.is_valid():
		return
	var aba := -1
	var obra := ""
	if LUGARES.has(qual):
		aba = int(LUGARES[qual]["aba"])
		obra = qual if BancadasVale.OBRAS.has(qual) else ""
	elif BancadasVale.raio_do_e(qual) > 0.0:
		aba = PainelVale.Aba.OBRAS
		obra = qual
	else:
		return
	_dica.visible = false
	_abrir.call(aba, obra)
