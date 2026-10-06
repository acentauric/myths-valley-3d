extends Node
## O RELÓGIO DE JOGO DOS PORTÕES DE COLHEITA: espera em segundos de JOGO, e não de parede.
##
## Não é portão: o runner só roda `tests/*.gd`, e esta pasta fica fora disso.
##
## POR QUE EXISTE. O `project.godot` limita a física a 3 passos por quadro
## (`max_physics_steps_per_frame`, do trabalho de desempenho de 05/10/2026), e com
## o quadro acima de 50 ms o Godot corta o delta de processo: o tempo do JOGO —
## `Timer`, `Tween`, o clipe do golpe — anda mais devagar que o relógio de
## parede. Medido neste projeto, na sonda da colheita:
##
##     quadro de   7 ms: o jogo anda a 1,00 do relógio
##     quadro de  70 ms: 0,72
##     quadro de 130 ms: 0,38
##     quadro de 210 ms: 0,23
##
## Os portões da colheita esperavam em `Time.get_ticks_msec()` (parede) coisas que
## acontecem em tempo de jogo: o golpe da foice leva 1,5 s e a janela era de 2,0 s;
## a copa que cai leva 1,68 s e o portão a conferia aos 1,70 s. Na bateria cheia,
## com sete portões brigando pela mesma máquina, os quadros passavam de 100 ms, e
## os mesmos portões que passam sozinhos reprovavam ("o passo 'coveiro_limpar'
## pede 8 de capim e só derrubei 0", "a copa não deitou: tombou só 52 graus").
##
## O QUE ESTE NÓ FAZ: soma o delta de cada quadro em `jogo_s` — é o mesmo delta que
## os `Timer` e os `Tween` do jogo recebem — e oferece `ate` e `esperar`, que
## contam esse tempo. Como o jogo nunca anda MAIS depressa que a parede, uma
## espera em segundos de jogo nunca é mais curta, em parede, que a de antes. Uma
## guarda de parede larga (`GUARDA`) impede que um jogo parado prenda o portão.
##
## COMO SE PROVA QUE O PORTÃO NÃO DEPENDE DE MÁQUINA FOLGADA, e que esta é a causa:
##
##   MV_QUADRO_LENTO_MS=150   cada quadro demora esse tanto a mais — a bateria cheia
##                            no seu pior, em escala. `ficar_lento` o liga, e deve
##                            ser chamado DEPOIS de o vale subir (a carga do mundo é
##                            uma fila de quadros e não precisa ficar lenta).
##   MV_FALSIFICAR=parede     as esperas voltam a contar o relógio de PAREDE, que era
##                            o de antes. Com quadro lento o portão TEM de reprovar.
##   MV_PASSOS_DE_FISICA=8    põe de volta o padrão do Godot (8 passos por quadro) no
##                            lugar dos 3 do `project.godot`: é a prova da causa. Com
##                            `parede` e quadro lento, 3 passos reprovam e 8 passam.
##
##     $env:MV_QUADRO_LENTO_MS = "150"
##     .\tools\prototipo_3d\testar.ps1 -Teste cadeia_da_zefa
##
## Uso, num portão (SceneTree):
##
##     const RelogioDeJogo = preload("res://tests/fixtures/relogio_de_jogo.gd")
##     var relogio: Node
##     ...
##     relogio = RelogioDeJogo.new()
##     root.add_child(relogio)
##     ...
##     await relogio.ate(func() -> bool: return pronto, 12.0)   # até 12 s DE JOGO
##     await relogio.esperar(0.75)

## A guarda de parede é esta vez a espera em segundos de jogo, com o piso abaixo.
const GUARDA := 12.0
const GUARDA_MINIMA_S := 60.0

## O tempo que o jogo viveu: a soma do delta de cada quadro.
var jogo_s := 0.0
var _atraso_ms := 0
var _por_parede := false


func _init() -> void:
	name = "RelogioDeJogo"
	# O jogo pausado não pode parar a contagem do portão.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_por_parede = OS.get_environment("MV_FALSIFICAR") == "parede"
	if _por_parede:
		print("  FALSIFICAÇÃO: as esperas contam o relógio de PAREDE (MV_FALSIFICAR=parede)")


func _process(delta: float) -> void:
	jogo_s += delta
	if _atraso_ms > 0:
		OS.delay_msec(_atraso_ms)


## Liga a máquina lenta pedida em `MV_QUADRO_LENTO_MS` (milissegundos a mais por
## quadro). Sem a variável, não faz nada. Devolve o atraso ligado.
func ficar_lento() -> int:
	_atraso_ms = maxi(OS.get_environment("MV_QUADRO_LENTO_MS").to_int(), 0)
	if _atraso_ms > 0:
		print("  quadro lento: +%d ms por quadro (MV_QUADRO_LENTO_MS)" % _atraso_ms)
	var passos := OS.get_environment("MV_PASSOS_DE_FISICA").to_int()
	if passos > 0:
		print("  passos de física por quadro: %d no lugar de %d (MV_PASSOS_DE_FISICA)" % [passos, Engine.max_physics_steps_per_frame])
		Engine.max_physics_steps_per_frame = passos
	return _atraso_ms


## O "agora" das esperas, em segundos: o do jogo — ou o de parede, na falsificação.
func agora() -> float:
	return float(Time.get_ticks_msec()) / 1000.0 if _por_parede else jogo_s


## Os segundos que o portão espera: `em_jogo`, que é a folga de agora — ou, na
## falsificação por parede, `como_era`, a janela de relógio que ele tinha antes e
## que não cabia na bateria cheia. Sem isto, a folga nova sozinha (6 s no lugar de
## 2 s para o golpe) já salvaria o portão no quadro lento, e a falsificação não
## mostraria a causa.
func janela(em_jogo: float, como_era: float) -> float:
	return como_era if _por_parede else em_jogo


## Espera `condicao` por até `segundos` DE JOGO. Devolve o que a condição disse no fim.
func ate(condicao: Callable, segundos: float) -> bool:
	var limite := agora() + segundos
	var guarda := Time.get_ticks_msec() + int(maxf(segundos * GUARDA, GUARDA_MINIMA_S) * 1000.0)
	while agora() < limite and Time.get_ticks_msec() < guarda:
		if condicao.call():
			return true
		await get_tree().process_frame
	return condicao.call()


## Deixa passar `segundos` de jogo.
func esperar(segundos: float) -> void:
	await ate(func() -> bool: return false, segundos)


## O golpe de `Recursos3D` acabou: o impacto caiu e o braço terminou.
func golpe_acabou(recursos) -> bool:
	return str(recursos.get("_golpe_pendente")) == "" and not bool(recursos.get("_golpe_animando"))
