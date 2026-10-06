extends Node
## VIDA NO CHÃO É NOITE NO CHÃO — a queda do jogo 2D, no vale.
##
## A regra é a do 2D (`Mundo._ao_cair` e `_apagar`): cair não é morrer. Alguém
## traz para casa, o dia vira, e o corpo acorda inteiro — mas acorda, e alguém
## diz o que houve, porque quem caiu no mato não sabe. O `Vida` compartilhado
## avisa (`caiu`) uma vez só por queda; este nó é o que o vale faz com o aviso.
##
## O QUE MUDA DO 2D PARA CÁ é só o lugar e o relógio:
##
## - CASA É A PORTA DA CASA DE TAIPA, e não o chão do quarto. O vale ainda não
##   tem cômodo nenhum (#26); quando tiver, o destino passa a ser ao pé da
##   cama, e é a única linha que muda.
## - A HORA É DO `Dia`, e o calendário é do `Relogio` (ver `dia.gd`). O
##   `Relogio.dormir()` vira o dia e SOLTA o `pausado` dele — no 2D é o que o
##   faz voltar a contar. Aqui quem conta é o `Dia`, então logo depois ele
##   escreve a hora de acordar, e escrever a hora é o que prende o calendário
##   de novo. Na ordem inversa, o calendário andaria sozinho até o próximo
##   quadro, que é o defeito que `tests/calendario.gd` procura.
## - O CARTÃO DO AMANHECER vem antes de clarear; depois, a explicação da queda
##   aparece no painel do HUD com botão de fechar, sem prender o vale.
##
## O que NÃO muda: a mesma trava de uma noite só (`_virando_a_noite`), o
## `Energia.desmaiar()` e o `Vida.dormir()` — cair é a mesma virada do desmaio
## de cansaço, com outra fala.
##
##
## A NOITE TEM TRÊS PORTAS (#50)
##
## A queda foi a primeira; com a casa aberta por dentro vieram as outras duas,
## e as três viram o dia pelo mesmo caminho (`_virar_a_noite`):
##
##   cama     o jogador deita e responde que sim (`casa_do_jogador.gd`):
##            acorda descansado, sem fala nenhuma.
##   desmaio  passou das duas da manhã sem deitar (`Dia.passou_das_duas`):
##            o dia do 2D vai das 6h às 2h (`Relogio.HORA_LIMITE`), e quem não
##            deitou apaga de cansaço e acorda com as falas do 2D.
##   queda    a vida no chão, como sempre.
##
## E CASA PASSOU A SER AO PÉ DA CAMA: com o cômodo montado, quem desmaia ou cai
## acorda no chão do quarto, como no 2D (`Mundo._deitar_no_chao_de_casa`); sem
## ele, diante da porta, como antes.

const FALAS := "res://data/queda.json"
const TEXTOS_DA_CASA := "res://data/casa.json"
const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")
## A dois passos da porta, do lado de fora: longe da parede o bastante para a
## cápsula do jogador não nascer encostada nela.
const DIANTE_DA_PORTA := 2.4
const ESCURECER := 0.9
const CLAREAR := 1.2

signal acordou
## A noite começou a virar, e por qual das três portas.
signal deitou(motivo: String)

var _world
var _player
var _hud
## O cômodo da casa, quando há (ver `ponto_de_casa`).
var interiores: Node
## O Pedro (`guia_pedro.gd`): enquanto o tutorial dura, quem apaga acorda com ele
## na porta (#92).
var guia: Node3D
var _virando_a_noite := false
var _preto: ColorRect


func configurar(world, player, hud) -> void:
	_world = world
	_player = player
	_hud = hud
	var tela := CanvasLayer.new()
	tela.name = "TelaDaQueda"
	# Por cima do HUD (camada 20): quem caiu não vê relógio nem barra até acordar.
	tela.layer = 30
	add_child(tela)
	_preto = ColorRect.new()
	_preto.color = Color.BLACK
	_preto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preto.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preto.modulate.a = 0.0
	_preto.visible = false
	tela.add_child(_preto)
	var vida := get_node_or_null("/root/Vida")
	if vida != null:
		vida.caiu.connect(_ao_cair)
	var dia := get_node_or_null("/root/Dia")
	if dia != null and dia.has_signal("passou_das_duas"):
		dia.passou_das_duas.connect(_ao_passar_das_duas)


## A noite está virando agora (a cama, o desmaio ou a queda)?
func virando_a_noite() -> bool:
	return _virando_a_noite


## Onde o jogador acorda: ao pé da cama, no quarto da casa herdada; sem o
## cômodo, diante da porta, no chão.
func ponto_de_casa() -> Vector3:
	var sala := _quarto()
	if sala != null:
		return sala.lugar_de_acordar()
	return diante_da_porta()


## Diante da porta da casa, do lado de fora, `folga` passos além do ponto de
## acordar de quem não tem cômodo.
func diante_da_porta(folga: float = 0.0) -> Vector3:
	var ancoras: Dictionary = _world.ancoras
	var casa: Vector3 = ancoras.get("Casa de taipa", Vector3.INF)
	if not casa.is_finite():
		return Vector3.INF
	var frente: Vector3 = ancoras.get("Casa de taipaFrente", Vector3.BACK)
	frente.y = 0.0
	frente = frente.normalized() if frente.length_squared() > 0.001 else Vector3.BACK
	return _world.ground_position(casa + frente * (_raio_da_casa() + DIANTE_DA_PORTA + folga), 0.05)


func _raio_da_casa() -> float:
	var spec: Dictionary = CatalogoAssets.PECAS.get("casa_taipa", {})
	return float(spec.get("largura", 6.5)) * 0.5


## O cômodo da casa herdada, se o vale o montou.
func _quarto() -> Node3D:
	if interiores == null or not interiores.has_method("sala_de"):
		return null
	var sala = interiores.sala_de("casa")
	return sala if sala != null and sala.has_method("lugar_de_acordar") else null


## A CAMA: quem chama já perguntou e ouviu que sim (`casa_do_jogador.gd`).
func dormir_na_cama() -> void:
	await _virar_a_noite("cama")


func _ao_cair() -> void:
	await _virar_a_noite("queda")


## PASSOU DAS DUAS SEM DEITAR: o cansaço vence. Quem já está virando a noite —
## o próprio sono anda o relógio por cima das duas — não conta de novo.
func _ao_passar_das_duas() -> void:
	await _virar_a_noite("desmaio")


func _virar_a_noite(motivo: String) -> void:
	if _virando_a_noite:
		return                      # já há uma noite em curso: esta não conta
	_virando_a_noite = true
	deitou.emit(motivo)
	_player.set_physics_process(false)
	_player.set_process_unhandled_input(false)
	_player.velocity = Vector3.ZERO
	if _player.has_method("_cancel_walk"):
		_player._cancel_walk()
	Audio.efeito("dormir")
	_preto.visible = true
	var escurece := create_tween()
	escurece.tween_property(_preto, "modulate:a", 1.0, ESCURECER)
	await escurece.finished

	_levar_para_casa()
	# Na cama o corpo descansa; no chão, só o fôlego do desmaio (como no 2D).
	if motivo == "cama":
		Energia.dormir()
	else:
		Energia.desmaiar()
	Vida.dormir()
	var horas_ate_amanha := fposmod(float(Relogio.HORA_DE_ACORDAR) - Dia.hora, 24.0)
	if horas_ate_amanha < 0.001:
		horas_ate_amanha = 24.0
	Relogio.dormir()
	Dia.avancar(horas_ate_amanha)
	# SALVA NA VIRADA, como o 2D salva ao dormir: depois do dia novo, para a
	# partida guardada ser a da manhã e não a da noite. Sem vaga, não salva.
	Partida.salvar()
	# O CARTÃO DO AMANHECER, no escuro: o dia já virou, e ele diz qual é, a
	# estação e o que está marcado. Só depois a tela clareia.
	#
	# E O CARTÃO PARA O VALE. O E que pula a espera não pode valer para o
	# mundo — bater na árvore ao lado da porta, ler a lápide, abrir o mapa —, e
	# no Godot 4 quem ouve no `_unhandled_key_input` ouve ANTES do cartão. Com a
	# árvore parada só ouvem os nós que não param, e esses perguntam por ele.
	get_tree().paused = true
	await Amanhecer.mostrar(_lembretes_do_dia())
	get_tree().paused = false

	var clareia := create_tween()
	clareia.tween_property(_preto, "modulate:a", 0.0, CLAREAR)
	await clareia.finished
	_preto.visible = false
	_player.set_physics_process(true)
	_player.set_process_unhandled_input(true)
	_virando_a_noite = false
	acordou.emit()
	# Alguém diz o que houve, porque quem caiu no mato não sabe; e quem apagou
	# de cansaço ouve o que o corpo diz. Quem deitou na cama sabe o que fez.
	match motivo:
		"queda":
			_hud.show_house_info("\n\n".join(_falas()), str(IdiomaMenu.campo(_dado().get("titulo", {}), "texto")))
		"desmaio":
			await Dialogo.falar("", _falas_do_desmaio())


func _levar_para_casa() -> void:
	var destino := ponto_de_casa()
	if not destino.is_finite():
		_player.reset_position()
		_player.sair_do_nado_ao_renascer()
		return
	_player.global_position = destino
	_player.velocity = Vector3.ZERO
	if _player.has_method("sair_do_nado_ao_renascer"):
		_player.sair_do_nado_ao_renascer()
	# No quarto, acorda de frente para a porta.
	var sala := _quarto()
	if sala != null and "visual" in _player:
		_player.visual.rotation.y = sala.giro_de_acordar()
	# Terra firme conhecida passa a ser a porta de casa: se a próxima volta à
	# terra (o tubarão, o fundo do mar) vier antes de o jogador pisar em outro
	# chão, ela o traz para cá, e não para onde ele estava antes de cair.
	if "_last_land" in _player:
		_player._last_land = destino
	# O PEDRO VEM JUNTO (#92): enquanto o tutorial dura, quem apagou nadando
	# acordava em casa e ele ficava no mar. Ele espera na porta, do lado de
	# fora, e a condução recomeça dali.
	if guia != null and is_instance_valid(guia) and guia.has_method("vir_para_a_porta") \
			and guia.has_method("terminou_o_tutorial") and not bool(guia.call("terminou_o_tutorial")):
		guia.call("vir_para_a_porta", diante_da_porta(2.0))


## O QUE ESTÁ MARCADO PARA O DIA QUE COMEÇA, o mesmo do 2D
## (`Mundo._lembretes_do_dia`): o dia da fazenda do outro lado do rio, ou a
## festa da fé; sem nenhum dos dois, o cartão diz que não há nada.
func _lembretes_do_dia() -> Array:
	if Jornada.hoje():
		return [str(IdiomaMenu.campo(_dado().get("lembrete_da_fazenda", {}), "texto"))]
	var festa := Fe.festa_de_hoje()
	if festa == "":
		return []
	return [str(Fe.festa(festa).get("aviso", ""))]


func _falas() -> Array:
	var falas := []
	for entrada in _dado().get("fala", []):
		falas.append(str(IdiomaMenu.campo(entrada, "texto")))
	return falas


## As falas do desmaio das duas, as do 2D (`Mundo._ao_desmaiar`).
func _falas_do_desmaio() -> Array:
	var dado = JSON.parse_string(FileAccess.get_file_as_string(TEXTOS_DA_CASA))
	var falas := []
	if dado is Dictionary:
		for entrada in dado.get("desmaio", []):
			falas.append(str(IdiomaMenu.campo(entrada, "texto")))
	return falas


func _dado() -> Dictionary:
	var dado = JSON.parse_string(FileAccess.get_file_as_string(FALAS))
	if typeof(dado) != TYPE_DICTIONARY:
		push_warning("Queda: arquivo de falas inválido " + FALAS)
		return {}
	return dado
