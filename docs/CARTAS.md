# Cartas: pactos, apoios e rituais

A mecânica que o [GDD](GDD.md) chama de central. Implementada em
`scripts/autoload/cartas.gd`; o conteúdo vive em `data/cartas/cartas.json`.

## As três naturezas

Elas não são a mesma coisa com nomes diferentes. Cada uma se ganha de um jeito,
se usa de um jeito e custa de um jeito — e é essa diferença que as faz valer.

| | pacto | apoio | ritual |
|---|---|---|---|
| **de quem** | do mito, no lugar dele | de morador próximo | de morador próximo, ou achado |
| **como se usa** | firmado, vale enquanto estiver | tecla R, uma vez por dia | preparado e consumido |
| **o que custa** | **cobra todo dia**, em item | nada | o que você planta |
| **quantos ao mesmo tempo** | **um** | todos que tiver | os que couberem na mochila |

### Pacto

O universo do Batalha de Mitos já trata mito como quem **troca e cobra** — a
Matinta Pereira do capítulo 7 é exatamente isso, e a Caipora "não trabalha para
ninguém; ela vigia caminhos e cobra pedágio" (ver
[VILA_E_EXPEDICOES.md](VILA_E_EXPEDICOES.md)).

Então o pacto dá um ganho permanente **e tira alguma coisa toda madrugada**. É a
cobrança que faz dele uma decisão: sem ela seria um bônus que não há razão para
recusar.

Quem não tem com que pagar **não perde o pacto** — perde o ganho daquele dia, e
é avisado. Perder o pacto por um dia ruim seria punir o jogador por estar no
meio de uma obra, e pacto que se quebra sozinho não é pacto.

Um de cada vez. Firmar o segundo desfaz o primeiro, e o ganho do primeiro sai
junto — senão acumular pacto seria só questão de trocar de carta.

### Apoio

Carta de gente, não de mito, e por isso não cobra nada: é um favor guardado, uma
reza que alguém ensinou, um jeito de fazer. Vale uma vez por dia, na tecla R, na
mesma gaveta do talento ativo — o jogador não deveria ter que lembrar de qual
sistema saiu o que ele pode fazer hoje.

### Ritual

O único que o jogador fabrica, e é de propósito: **o ritual amarra a mecânica
central ao roçado**, que é o coração do jogo. Ritual comprado no armazém seria
mais uma poção.

Prepara-se no **oratório** — a obra de mobília que existia desde sempre dando
quatro de fôlego e mais nada. A Fase 3 deu função a ela.

## De onde vêm

Nenhuma se compra. É o que amarra esta fase às anteriores:

- **pacto** → o lugar do mito (Caipora na mata do dendê, Iara na lagoa), **e só
  depois do sinal** — ver abaixo;
- **apoio e receita de ritual** → morador de quem você é próximo, e de quem faz
  sentido: a benzedeira ensina reza, a velha que peneirava farinha ensina o
  resguardo, o lavrador de quarenta e duas safras ensina a chamar chuva;
- **olho da mata** → achado andando, como os cordéis, mas na mata do dendê: ele
  também espera o sinal de lá.

## O sinal vem antes da carta

Carta de `mata_do_dende` e da `lagoa` **não nasce no chão**. O que nasce é um
SINAL — uma coisa pequena que a entidade deixou para trás, e que não diz de
quem é. O jogador cata, o sinal vai para o caderno de sinais (`tecla L`, ao
lado dos cordéis — **não** para a mochila), e a carta aparece ali, onde o sinal
estava.

Antes disso a carta estava largada na grama desde o primeiro dia do jogo: o
jogador tropeçava nela, apertava E, e a Iara se apresentava com nome, resumo e
tabela de cobrança. O encontro com a coisa mais estranha do mapa acontecia como
quem cata lenha.

A amarração é `Mundo.SINAL_DE_CADA_LUGAR`, que casa lugar com sinal, e as
fichas moram em `data/colecionaveis/sinais.json`. **Nenhum `titulo` nomeia a
entidade** — o nome mora em `revelado`, e a tela só o mostra depois que a carta
daquele mito estiver na mão (`Colecao.nomeia`). Até lá a ficha fecha dizendo a
verdade sobre o estado do jogador: *"Você não sabe de quem era. Ainda."*

Lugar novo com carta quer sinal novo, senão a carta volta a estar no chão desde
o começo. `testar_sinais.gd` mede as duas pontas — a carta vindo cedo demais e
a carta não vindo nunca, que é a que some calada.

## Acrescentar uma carta

Uma entrada em `data/cartas/cartas.json`, e o portão cobra o resto:

```powershell
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/gdscript/testar_cartas.gd
```

Ele reprova carta sem `onde` nem `de_quem` (escrita e inalcançável), lugar que o
mundo não conhece, ingrediente que não existe no catálogo, e pacto sem cobrança.
Ritual novo precisa também de um item de mesmo id no `Catalogo`, com tipo
`ritual` e ícone — senão preparar não põe nada na mochila.

O que o ritual FAZ mora em `Mundo._usar_ritual`, e não na `Cartas`: os três
mexem no mundo — molhar o roçado, apontar o que a mata tem. A `Cartas` sabe o
que eles custam e o que eles são; quem sabe onde as coisas estão é a cena.
