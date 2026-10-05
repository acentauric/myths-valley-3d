extends Node
## OS MARCOS DE FÉ DO VALE (#52): chegar perto, apertar E, e o marco responde.
##
## As três fés já estavam no vale — `Fe`, `Ritos` e `Afinidade` são os autoloads
## compartilhados com o jogo 2D, com as árvores, a espera, as bênçãos, as festas
## e o preço de trocar. Faltava o CHÃO: os marcos no mundo e o que acontece
## neles. Este nó é o `Mundo._no_marco` do 2D trazido para cá.
##
##   cruzeiro        a cruz diante da igreja                     católica
##   capela          o ALTAR da igreja do Bom Jesus, por dentro   católica
##   capela_estrada  a capela velha da rua do mirante            católica
##   cemiterio       a capelinha do cemitério do outeiro, de     católica
##                   costas para o mar
##   terreiro        a casa de santo na mata, antes da curva      candomblé
##   gameleira       a árvore do sambaqui, na ponta da praia      caboclo
##
## A IGREJA É O ALTAR, e não a porta: com a nave aberta (#26), reza-se lá dentro,
## e a tecla só aparece para quem está na nave — senão ela apareceria do lado de
## fora da parede dos fundos, que fica a dois passos do altar.
##
## O QUE O MARCO RESPONDE depende de uma pergunta só: é da SUA fé?
##
##   é da sua      o RITO — fôlego, XP de fé e uma bênção com prazo. O gesto
##                 acontece mesmo fora do prazo; o que tem prazo é a graça, e o
##                 marco diz o dia em que ela volta.
##   é de outra    a oferta de MIGRAR, em duas perguntas: trocar não custa nada
##                 (a teia antiga congela inteira); levar o acumulado custa 85%,
##                 e o número aparece antes do sim. E o preço social também:
##                 quem é da fé deixada fica sabendo.
##   você não tem  a oferta de ENTRAR — se a Dona Zefa já mostrou as três
##                 (`liberada`). Antes disso o marco é só educação.
##
## As palavras moram em `data/marcos_fe.json`, nos três idiomas: os nomes e os
## resumos das fés no `fe.gd` compartilhado são só em português.

## Chegou perto de um marco — uma vez por chegada: sair e voltar conta de novo.
signal chegou(marco: String)

const DicaTecla = preload("res://scripts/prototipo_3d/dica_tecla.gd")
const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")
const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")
const FocoDoE = preload("res://scripts/prototipo_3d/foco_do_e.gd")
const TEXTOS := "res://data/marcos_fe.json"

const MARCOS := ["cruzeiro", "capela", "capela_estrada", "cemiterio", "terreiro", "gameleira"]
## O nome de cada marco para gente ler (o diário, a voz que dá a missão da fé).
const NOMES_DOS_MARCOS := {
	"cruzeiro": "Cruzeiro", "capela": "Igreja do Bom Jesus", "capela_estrada": "Capela velha",
	"cemiterio": "Cemitério", "terreiro": "Terreiro", "gameleira": "Gameleira",
}
## Até onde a tecla E aparece, no chão.
const ALCANCE := 2.8
## Perto o bastante para contar como chegada (as missões de visita).
const CHEGADA := 6.0
## Da porta da capelinha do cemitério até onde se reza.
const DIANTE_DA_CAPELINHA := 1.8
const ALTURA_DA_DICA := 1.7

## A escolha da fé já foi mostrada? Respondido de fora (a missão da Dona Zefa).
## Sem resposta, nenhum marco aceita ninguém — que é o certo antes de ela falar.
var liberada: Callable = Callable()

var _mundo: Node3D
var _jogador: Node3D
var _hud
var _interiores
var _textos: Dictionary = {}
## marco -> onde ele está (o ponto da tecla e da chegada).
var _pontos: Dictionary = {}
var _perto := ""
var _chegados: Dictionary = {}
var _dica: PanelContainer
## Um marco respondendo: a conversa dele é uma fila de falas e perguntas, e a
## tecla não abre outra por cima.
var _ocupado := false


func configurar(mundo: Node3D, jogador: Node3D, hud, interiores) -> void:
	_mundo = mundo
	_jogador = jogador
	_hud = hud
	_interiores = interiores
	add_to_group("marcos_da_fe")
	var lido = JSON.parse_string(FileAccess.get_file_as_string(TEXTOS))
	_textos = lido if lido is Dictionary else {}
	for marco in MARCOS:
		var onde := _ponto_do_marco(str(marco))
		if onde.is_finite():
			_pontos[marco] = onde
	_dica = DicaTecla.criar(hud.map_layer(), Atalhos.letra("interagir"), "")
	add_to_group(FocoDoE.GRUPO)


## Onde o marco está, ou INF se o vale não o tem.
func ponto(marco: String) -> Vector3:
	return _pontos.get(marco, Vector3.INF)


func marcos() -> Array:
	return _pontos.keys()


func ocupado() -> bool:
	return _ocupado


func _ponto_do_marco(marco: String) -> Vector3:
	match marco:
		"capela":
			if _interiores != null:
				var sala = _interiores.sala_de("igreja")
				if sala != null and sala.has_method("ponto_do_altar"):
					return sala.ponto_do_altar()
		"capela_estrada":
			# Diante da porta da capela velha, que não tem cômodo.
			var base := Lugares.ponto(marco)
			if not base.is_finite():
				return base
			var frente: Vector3 = _mundo.ancoras.get("Capela velhaFrente", Vector3.BACK)
			frente.y = 0.0
			return _mundo.ground_position(base + frente.normalized() * 6.0, 0.05)
		"cemiterio":
			# DIANTE DA PORTA DA CAPELINHA, que dá as costas para o mar
			# (`world_builder._capelinha_do_cemiterio`): reza-se de frente para
			# ela, olhando a baía. Rezava-se no meio das covas, entre duas lajes.
			# O passo e meio a mais deixa a lápide da cova mais perto e o capim
			# fora do alcance da tecla: o E daqui é o da reza.
			var porta: Vector3 = _mundo.ancoras.get("CapelinhaPorta", Vector3.INF)
			if porta.is_finite():
				var diante: Vector3 = _mundo.ancoras.get("CapelinhaFrente", Vector3.BACK)
				return _mundo.ground_position(porta + diante * DIANTE_DA_CAPELINHA, 0.05)
	return Lugares.ponto(marco)


func _process(_delta: float) -> void:
	if _jogador == null or _dica == null:
		return
	var onde: Vector3 = _jogador.global_position
	for marco in _pontos:
		if _alcanca(str(marco), onde, CHEGADA):
			if not _chegados.has(marco):
				_chegados[marco] = true
				chegou.emit(str(marco))
		elif not _alcanca(str(marco), onde, CHEGADA * 1.5):
			_chegados.erase(marco)
	var camera := get_viewport().get_camera_3d()
	var em_jogo: bool = camera != null and camera == _jogador.get("camera")
	_perto = _mais_perto(onde) if em_jogo and not _ocupado and not Dialogo.ativo else ""
	if _perto == "" or not FocoDoE.e_dele(self):
		_dica.visible = false
		return
	DicaTecla.mostrar_em(_dica, camera, _pontos[_perto] + Vector3.UP * ALTURA_DA_DICA, _acao(_perto))


## O QUE O E FARIA AQUI, para o foco (`foco_do_e.gd`): o rito ou o olhar do marco.
func alvo_do_e() -> Dictionary:
	if _perto == "" or _ocupado or not _pontos.has(_perto):
		return {}
	return {"ponto": _pontos[_perto]}


## O jogador alcança o marco desta distância? O altar só se alcança de dentro
## da nave.
func _alcanca(marco: String, onde: Vector3, distancia: float) -> bool:
	var ponto_do_marco: Vector3 = _pontos[marco]
	if Vector2(onde.x - ponto_do_marco.x, onde.z - ponto_do_marco.z).length() > distancia:
		return false
	if absf(onde.y - ponto_do_marco.y) > 4.0:
		return false
	if marco == "capela" and _interiores != null:
		return _interiores.contem(onde) == "igreja"
	return true


func _mais_perto(onde: Vector3) -> String:
	var melhor := ""
	var menor := INF
	for marco in _pontos:
		if not _alcanca(str(marco), onde, ALCANCE):
			continue
		var d: float = onde.distance_to(_pontos[marco])
		if d < menor:
			menor = d
			melhor = str(marco)
	return melhor


## O que a tecla diz: o rito da fé, no marco dela; "Olhar" nos outros.
func _acao(marco: String) -> String:
	var fe := Fe.fe_do_marco(marco)
	if fe != "" and Fe.praticada(fe):
		return tr("Rezar") if str(Fe.dados_da_fe(fe).get("rito", "")) == "rezar" else tr("Oferendar")
	return tr("Olhar")


func _unhandled_key_input(event: InputEvent) -> void:
	if _perto == "" or _ocupado:
		return
	if not (event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == Atalhos.tecla("interagir")):
		return
	# COM O CORPO PARADO, O E NÃO VALE PARA O MUNDO, como nas lápides e nos
	# achados: este nó ouve no _unhandled_key_input, ANTES das telas que ouvem
	# no _unhandled_input (o cartão do amanhecer, o folheto).
	if Dialogo.ocupado() or not _jogador.is_physics_processing() or not FocoDoE.e_dele(self):
		return
	get_viewport().set_input_as_handled()
	no_marco(_perto)


## O MARCO RESPONDE (ver o cabeçalho). Corrotina: a conversa espera o jogador.
func no_marco(marco: String) -> void:
	var fe := Fe.fe_do_marco(marco)
	if fe == "" or _ocupado:
		return
	_ocupado = true
	_perto = ""
	if _dica != null:
		_dica.visible = false
	if Fe.ativa == "":
		await _oferecer_fe(fe)
	elif Fe.ativa != fe:
		await _oferecer_migracao(fe)
	else:
		await _celebrar(marco, fe)
	_ocupado = false


## O RITO: ajoelhar, ou bater na raiz, ou deixar o prato. O gesto acontece
## mesmo fora do prazo; sem graça, o marco diz o dia em que ela volta — em dia
## do calendário, que se confere no alto da tela, e não em "daqui a N dias".
func _celebrar(marco: String, fe: String) -> void:
	var sim: bool = await Dialogo.perguntar("", _da_fe(fe, "convite"))
	if not sim:
		return
	if not Ritos.pode_celebrar(marco):
		await Dialogo.falar("", _linhas("rito_cedo", {"dia": Relogio.texto_do_dia(Ritos.dia_liberado(marco))}))
		return
	var bencao := Ritos.celebrar(marco)
	if bencao.is_empty():
		return
	Audio.efeito("ui_confirmar")
	var id := _id_da_bencao(fe, str(bencao.get("nome", "")))
	var traduzida: Dictionary = _textos.get("bencaos", {}).get(id, {})
	await Dialogo.falar("", _linhas("rito", {
		"bencao": str(IdiomaMenu.campo(traduzida, "texto", bencao.get("nome", ""))),
		"resumo": str(IdiomaMenu.campo(traduzida, "resumo", bencao.get("resumo", ""))),
	}))


## ENTRAR PARA UMA FÉ, com os pés: anda-se até o marco dela e aceita-se ali.
## Não há menu de religião, e não deve haver.
func _oferecer_fe(fe: String) -> void:
	if not liberada.is_valid() or not bool(liberada.call()):
		await Dialogo.falar("", _linhas("travado"))
		return
	await Dialogo.falar("", [_da_fe(fe, "resumo")])
	var sim: bool = await Dialogo.perguntar("", _texto("entrar", {"de": _da_fe(fe, "de")}))
	if not sim:
		return
	Fe.adotar(fe)
	Audio.efeito("ui_confirmar")
	await Dialogo.falar("", _linhas("entrar", {"pratica": _da_fe(fe, "pratica"), "teia": Atalhos.letra("talentos")}))


## TROCAR DE FÉ, e depois — se ele quiser — levar o que juntou. Duas perguntas
## de propósito: trocar não custa nada; levar custa os 85%, e o número aparece
## antes do sim. O preço social vem antes também.
func _oferecer_migracao(fe: String) -> void:
	var antiga := Fe.ativa
	var de_antiga := _da_fe(antiga, "de")
	await Dialogo.falar("", _linhas("migrar", {"de_antiga": de_antiga, "resumo": _da_fe(fe, "resumo")}))
	var volta := _texto("ja_foi", {"pontos": Fe.pontos_da(fe)}) if Fe.conhecida(fe) else _texto("nunca_foi")
	await Dialogo.falar("", _linhas("congelar", {"de_antiga": de_antiga, "volta": volta}))
	var quem_fica: Array = Afinidade.da_fe(antiga).map(func(m): return Afinidade.nome_de(str(m)))
	if not quem_fica.is_empty():
		await Dialogo.falar("", [_texto("social", {"de_antiga": de_antiga, "quem": ", ".join(quem_fica)})])
	var sim: bool = await Dialogo.perguntar("", _texto("trocar", {"o_antiga": _da_fe(antiga, "o"), "de_nova": _da_fe(fe, "de")}))
	if not sim:
		return
	Fe.migrar(fe)
	Audio.efeito("ui_confirmar")
	var previa := Fe.previa_da_migracao(antiga, fe)
	if int(previa.get("sai", 0)) <= 0:
		await Dialogo.falar("", [_texto("nada_a_levar")])
		return
	var numeros := {
		"de_antiga": de_antiga,
		"sai": int(previa["sai"]), "chega": int(previa["chega"]), "perde": int(previa["perde"]),
		"antes": int(previa["nivel_antes"]), "depois": int(previa["nivel_depois"]),
	}
	await Dialogo.falar("", _linhas("levar", numeros))
	var levar: bool = await Dialogo.perguntar("", _texto("levar", numeros))
	if not levar:
		await Dialogo.falar("", [_texto("ficam")])
		return
	Fe.migrar_pontos(antiga, fe)
	Audio.efeito("ui_confirmar")
	await Dialogo.falar("", _linhas("trouxe", numeros))


## A FALA DO LUGAR na primeira chegada da missão dos três marcos: o que se vê
## dali, na voz do mundo, sem nome — quem está olhando é o jogador.
func narrar_visita(marco: String) -> void:
	var linhas := _linhas_de(_textos.get("visita", {}).get(marco, {}), {})
	if not linhas.is_empty():
		await Dialogo.falar("", linhas)


# --- as palavras ----------------------------------------------------------------

func _da_fe(fe: String, campo: String) -> String:
	var dado: Dictionary = _textos.get("fes", {}).get(fe, {})
	var escrito := str(IdiomaMenu.campo(dado, campo, ""))
	if escrito != "":
		return escrito
	# O que o JSON não tiver, o fe.gd compartilhado tem — em português.
	return str(Fe.dados_da_fe(fe).get(campo, Fe.nome(fe)))


func _texto(chave: String, valores: Dictionary = {}) -> String:
	return str(IdiomaMenu.campo(_textos.get(chave, {}), "texto", "")).format(valores)


func _linhas(chave: String, valores: Dictionary = {}) -> Array:
	return _linhas_de(_textos.get(chave, {}), valores)


func _linhas_de(dado: Dictionary, valores: Dictionary) -> Array:
	var saida: Array = []
	for linha in IdiomaMenu.campo(dado, "linhas", []):
		var escrita := str(linha).format(valores)
		if escrita.strip_edges() != "":
			saida.append(escrita)
	return saida


func _id_da_bencao(fe: String, nome: String) -> String:
	var pote: Dictionary = Fe.BENCAOS.get(fe, {})
	for id in pote:
		if str(pote[id].get("nome", "")) == nome:
			return str(id)
	return ""
