extends RefCounted
## O E NUM MORADOR, COMO O JOGADOR O APERTA: depois que a fala dele acaba.
##
## Não é portão: o runner só roda `tests/*.gd`, e esta pasta fica fora disso.
##
## POR QUE EXISTE. "Uma fala ativa impede oferecer nova conversa com seu dono" (#121,
## `docs/testes/PRIORIDADES_DOS_BALOES.md`): enquanto o balão do morador está no ar, a dica "Falar com"
## some e a tecla não o alcança (`tecla_dos_moradores._fala_ativa`; `usar` volta sem fazer nada). O
## morador que o portão acaba de pôr ao lado do jogador cumprimenta, e o cumprimento (ou a saudação do
## Pedro, que dura a voz inteira, uns 10 s) é fala no ar: o E apertado ali não faz nada. Os portões da
## conversa, das filas e das frentes foram escritos para o E que CORTAVA o cumprimento, e aguardavam
## "o E abriu a fila / disse o aviso / deu a recompensa" de uma tecla que o jogo agora ignora.
##
## O QUE FAZ: espera o morador calar (em relógio de PAREDE, que é o da fila de falas, e com teto) e só
## então aperta. É o que o jogador faz: espera o balão sumir para o "E" voltar. Se ele não calar no teto,
## aperta assim mesmo e o portão reprova com a razão certa. A falsificação é o próprio jogo:
## `matriz_dos_baloes` prova que o E ignorado durante a fala NÃO abre conversa.
##
##     const ConversaDoE = preload("res://tests/fixtures/conversa_do_e.gd")
##     ...
##     await ConversaDoE.usar(tecla, morador)

## Quanto esperar a fala acabar (s de parede): a mais longa do vale, uma saudação de voz, passa de 10.
const TETO_S := 30.0


## Espera `morador` calar e então faz `tecla.usar(morador)`.
static func usar(tecla: Node, morador: Node3D, teto_s: float = TETO_S) -> void:
	await calar(tecla.get_tree(), morador, teto_s)
	tecla.usar(morador)


## Espera `morador` calar: devolve se calou dentro do teto.
static func calar(arvore: SceneTree, morador: Node3D, teto_s: float = TETO_S) -> bool:
	var limite := Time.get_ticks_msec() + int(teto_s * 1000.0)
	while is_instance_valid(morador) and morador.has_method("falando_agora") and bool(morador.call("falando_agora")) \
			and Time.get_ticks_msec() < limite:
		await arvore.process_frame
	return not (is_instance_valid(morador) and morador.has_method("falando_agora") and bool(morador.call("falando_agora")))
