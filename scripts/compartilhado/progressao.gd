extends Node
## Progressão do personagem: o que a árvore de talentos vai mexer.
##
## Está separado de `Energia` de propósito. Energia é o estado de agora (quanto
## fôlego sobrou); Progressao é o que o personagem VIROU (quanto cabe, quanto o
## sono devolve, quão bem ele usa cada ferramenta).
##
## REGRA QUE IMPORTA: o sono devolve um VALOR FIXO, não uma fração do máximo.
## Quem destrava 1000 de fôlego e não mexe no descanso continua acordando com
## os mesmos 40. Subir o teto sem subir o descanso é uma escolha ruim — e o
## jogo deixa fazer, porque escolha ruim que não existe não é escolha.
##
## Quem mexe nestes valores é a TEIA DE TALENTOS (tecla K); a aba Jogo do
## painel os mostra. Os nós somam aqui de uma vez, ao destravar — o efeito não
## é reaplicado ao carregar a partida, porque já está dentro do número salvo
## (ver docs/SALVAMENTO.md).
##
## É um dos dois autoloads que o protótipo 3D usa COMPARTILHADOS, junto com o
## `Energia`: nenhum dos dois sabe o que é um tile, e por isso atravessam sem
## adaptação. A cópia de lá é conferida pelo `testar_compartilhado`.

signal mudou

const ENERGIA_MAXIMA_INICIAL := 100.0
const RECUPERACAO_INICIAL := 40.0
const RECUPERACAO_DESMAIO_INICIAL := 15.0
## Vida: o que o corpo aguenta de pancada. Ver vida.gd — é outra conta que o
## fôlego, e o teto dela mora aqui pelo mesmo motivo que o do fôlego.
const VIDA_MAXIMA_INICIAL := 30.0

## Teto de fôlego.
var energia_maxima: float = ENERGIA_MAXIMA_INICIAL

## Quanto uma noite de sono devolve, em pontos. Fixo, não proporcional.
var recuperacao_ao_dormir: float = RECUPERACAO_INICIAL

## Quanto apagar no chão devolve. Menos que a cama, sempre.
var recuperacao_ao_desmaiar: float = RECUPERACAO_DESMAIO_INICIAL

## Teto de vida, sem o vigor da teia (que `Vida.maximo` soma por cima).
var vida_maxima: float = VIDA_MAXIMA_INICIAL

## Multiplicador geral de custo. Talento de ofício derruba isto; 1.0 é o começo.
var eficiencia: float = 1.0

## Nível de cada ferramenta. Ferramenta melhor não gasta menos: ela DESTRAVA
## alvo mais duro, e alvo mais duro custa mais. É assim que o custo cresce sem
## o jogo ficar mais fácil.
var nivel_de_ferramenta: Dictionary = {
	"enxada": 1,
	"machado": 1,
	"picareta": 1,
	"foice": 1,
}

## Multiplicador de custo por escola de poder. Pacto com mito e arma grande
## entram aqui quando existirem (ver docs/VILA_E_EXPEDICOES.md).
var peso_do_poder: Dictionary = {
	"ritual": 2.0,
	"pacto": 3.0,
}


func nivel(ferramenta: String) -> int:
	return int(nivel_de_ferramenta.get(ferramenta, 1))


func subir_ferramenta(ferramenta: String, para: int) -> void:
	nivel_de_ferramenta[ferramenta] = maxi(nivel(ferramenta), para)
	mudou.emit()


## Chamado pela tela de configuração e, mais adiante, pela árvore de talentos.
func ajustar(campo: String, valor: float) -> void:
	match campo:
		"energia_maxima":
			energia_maxima = maxf(10.0, valor)
		"recuperacao_ao_dormir":
			recuperacao_ao_dormir = clampf(valor, 0.0, 10000.0)
		"recuperacao_ao_desmaiar":
			recuperacao_ao_desmaiar = clampf(valor, 0.0, 10000.0)
		"eficiencia":
			eficiencia = clampf(valor, 0.1, 3.0)
		"vida_maxima":
			vida_maxima = maxf(5.0, valor)
		_:
			return
	mudou.emit()
