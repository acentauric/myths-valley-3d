extends Node
## A PARTIDA DO VALE: em que vaga o jogador está, e como começar outra limpa.
##
## O `Salvamento` é o do 2D, compartilhado e sem uma linha mudada: três vagas,
## escrita atômica com releitura, migração em escada, limpeza do que sumiu.
## O que ele não faz — porque no 2D ninguém precisava — é ZERAR a partida.
##
## PARTIDA NOVA NÃO PODE HERDAR A ANTERIOR. Os sistemas são autoloads: vivem
## da abertura até o jogo fechar, e trocar de cena não os toca. Quem joga na
## vaga 1, volta ao menu e começa na vaga 2 levaria a mochila, a vida, o
## calendário e as missões da 1. Então, ao subir o jogo — antes de haver
## partida —, este nó tira um RETRATO DE FÁBRICA de tudo o que o save guarda,
## no mesmo formato do arquivo, e toda partida começa restaurando esse retrato.
## É o `carregar` do próprio `Salvamento`, com um "arquivo" que é o jogo no
## instante em que abriu: uma porta só para entrar no estado, e não duas.
##
## Entra por último na lista de autoloads, para o retrato sair depois de todos
## os sistemas terem feito o `_ready` deles.
##
## SEM VAGA NÃO SE SALVA, como no 2D. É o EXPLORAR da abertura: um passeio
## livre, que não grava nada e não apaga nada.
##
## OS PONTOS DE RESTAURAÇÃO (`pontos_de_restauracao.gd`) passam por aqui: cada
## gravação dá ao dia do jogo o ponto dele, e apagar uma vaga — ou começar uma
## partida nova por cima dela — guarda antes o ponto do que se perde. E o NOME
## DA VAGA, que a tela de vagas deixa editar, mora num arquivo à parte
## (`user://vagas.json`), e não no save: gravar a partida não o apaga.

const PontosDeRestauracao = preload("res://scripts/prototipo_3d/pontos_de_restauracao.gd")
const NOMES_DAS_VAGAS := "user://vagas.json"
## Quantas letras cabem no nome de uma vaga, no cartão dela.
const NOME_MAXIMO := 24

## O estado de todos os sistemas salvos no instante em que o jogo abriu.
var fabrica: Dictionary = {}

## O QUE O ENCAIXE DAVA a quem ainda tem a peça vestida numa partida antiga: o
## facão vestido nas Mãos tirava 5% do fôlego gasto, e a `Progressao` foi salva
## com isso somado. Ver `_devolver_o_que_saiu_do_encaixe`.
const EFEITO_QUE_O_ENCAIXE_DAVA := {"facao": {"eficiencia": -0.05}}


func _ready() -> void:
	fabrica = instantaneo()
	Salvamento.carregou.connect(_devolver_o_que_saiu_do_encaixe)
	Salvamento.salvou.connect(func() -> void: PontosDeRestauracao.depois_de_salvar(Salvamento.slot_atual))


## O QUE SAIU DO ENCAIXE volta para a barra de mão. "No campo mãos do inventário,
## não é para armas, mas sim para luvas. Armas são nos campos numerais." A
## partida salva com o machado ou o facão vestido nas Mãos os traz de volta à
## barra (a mochila enche a barra primeiro), e o facão leva junto o efeito de
## cintura que dava. Sem lugar na mochila, a peça fica vestida até haver.
func _devolver_o_que_saiu_do_encaixe() -> void:
	var devolvidos: Array = []
	for encaixe in Equipamento.ENCAIXES:
		var id := Equipamento.no_encaixe(str(encaixe))
		if id == "" or (Equipamento.encaixe_de(id) == encaixe and Equipamento.e_equipamento(id)):
			continue
		if not Inventario.adicionar(id, 1):
			continue
		var efeito: Dictionary = EFEITO_QUE_O_ENCAIXE_DAVA.get(id, {})
		for campo in efeito:
			if Progressao.get(campo) != null:
				Progressao.ajustar(campo, float(Progressao.get(campo)) - float(efeito[campo]))
		Equipamento.vestido[encaixe] = ""
		devolvidos.append(Catalogo.nome(id))
	if not devolvidos.is_empty():
		Salvamento.ultimo_relato.append("Voltou para a barra de mão, que é onde vai arma: %s." % ", ".join(devolvidos))
		Equipamento.mudou.emit()


## O estado de hoje, no formato do arquivo, sem escrever nada: a mesma tabela
## que o `Salvamento` percorre ao salvar. Cópia funda — o que os sistemas
## entregam é deles, e o retrato não pode mudar quando eles mudarem.
func instantaneo() -> Dictionary:
	var tudo := {"versao": Salvamento.VERSAO}
	for nome in Salvamento.O_QUE_GUARDAR:
		var sistema := get_node_or_null("/root/" + str(nome))
		if sistema == null:
			continue
		var secao := {}
		for campo in Salvamento.O_QUE_GUARDAR[nome]:
			secao[str(campo)] = sistema.get(str(campo))
		tudo[str(nome)] = secao
	# Fé, afinidade, cartas e terrenos têm estado privado: o `Salvamento` sabe
	# pegá-lo, e é ele quem pega. O mundo fica de fora: não há mundo no retrato.
	Salvamento._guardar_especiais(tudo)
	tudo.erase("Mundo")
	return tudo.duplicate(true)


## Começa a partida da vaga `slot` (0: passeio sem vaga). `apagar` apaga o que
## havia na vaga antes: é começar por cima, e só a tela de vagas, com a
## confirmação dela, chama assim.
##
## Sempre volta à fábrica primeiro, mesmo para CONTINUAR: o save traz todos os
## campos que guarda, mas um sistema que o save não conhece ficaria com o
## estado da partida anterior. O vale carrega o arquivo da vaga depois de
## montado (ver `prototype.gd`), como o 2D faz.
func comecar(slot: int, apagar: bool = false) -> void:
	if apagar and slot > 0 and Salvamento.existe_partida(slot):
		apagar_vaga(slot)
	# Mundo nenhum registrado enquanto a fábrica volta: o vale que se
	# apresentou pode já ter saído da árvore.
	Salvamento.registrar_mundo(null)
	Salvamento.carregar(fabrica.duplicate(true))
	Salvamento.ultimo_relato.clear()
	Salvamento.slot_atual = slot


## Salva a partida em curso, se ela tem vaga. Devolve false no passeio.
func salvar() -> bool:
	if Salvamento.slot_atual <= 0:
		return false
	return Salvamento.salvar()


func tem_vaga() -> bool:
	return Salvamento.slot_atual > 0


## APAGA A VAGA, com o ponto de restauração dela guardado antes, e esquece o
## nome que ela tinha.
func apagar_vaga(slot: int) -> void:
	PontosDeRestauracao.apagar_vaga(slot)
	renomear(slot, "")


## O NOME DA VAGA que o jogador deu, ou "" se não deu (o cartão mostra então o
## nome de quem joga).
func nome_da_vaga(slot: int) -> String:
	return str(_nomes().get(str(slot), ""))


func renomear(slot: int, nome: String) -> void:
	var nomes := _nomes()
	var limpo := nome.strip_edges().left(NOME_MAXIMO)
	if limpo == "":
		nomes.erase(str(slot))
	else:
		nomes[str(slot)] = limpo
	var arquivo := FileAccess.open(NOMES_DAS_VAGAS, FileAccess.WRITE)
	if arquivo != null:
		arquivo.store_string(JSON.stringify(nomes, "\t"))
		arquivo.close()


func _nomes() -> Dictionary:
	if not FileAccess.file_exists(NOMES_DAS_VAGAS):
		return {}
	var lido = JSON.parse_string(FileAccess.get_file_as_string(NOMES_DAS_VAGAS))
	return lido if lido is Dictionary else {}
