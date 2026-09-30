# Vila, NPCs e expedições

Desenho inspirado em [Romestead](https://store.steampowered.com/app/1805320/Romestead/).
**Nada disto está implementado** — é o alvo das Fases 4 a 6.

## O que o Romestead faz

| Sistema | Como funciona lá |
|---------|------------------|
| Assentamento | Recursos pesados são objetos físicos: pedra, minério e tronco são carregados **um por vez** de volta à vila. Dá para ter vários assentamentos, em biomas diferentes, ligados por rotas de comércio. |
| Recrutamento | Sobreviventes viram artesãos. Cada cidadão tem **preferência de ofício e traços de personalidade**. Manter o povo feliz é parte da gestão. |
| Funções | Trabalhador com a função ligada vai sozinho buscar material no depósito e construir o que está na fila. Com a função desligada, o jogador carrega tudo na mão. |
| Talentos | Habilidade sobe por uso e rende **Favour Points** numa árvore de 60+ nós. A árvore é **meta-progressão: persiste entre mundos**. |
| Deuses | Oferendas e sacrifícios despertam divindades, que liberam tecnologia, bônus e melhorias. |

## Como traduzimos para o Batalha de Mitos

| Romestead | Aqui | Por quê |
|-----------|------|---------|
| Assentamento | **Arraial** — o roçado cresce até virar povoado; depois, outros arraiais no povoado, no porto e à beira da mata | Combina com as regiões já desenhadas no GDD |
| Deuses com oferendas | **Mitos com pactos** | O universo já tem isto pronto: a Matinta Pereira do capítulo 7 é exatamente uma entidade que **troca** e **cobra** |
| Recrutar artesão | **Acolher moradores** | Nem todo mito ou pessoa é recrutável (ver abaixo) |
| Funções | **Ofícios**: roceiro, pescador, lenhador, oleiro, rezador | Vocabulário do lugar, não genérico |
| Favour Points | **Pontos de fé / afinidade** ganhos por uso e por relação com os mitos | Liga progressão a narrativa em vez de só a grind |
| Expedições | **Jornadas** — é o motor dos capítulos | A travessia do cap. 6 e a noite de perseguição do cap. 7 já são jornadas |

### Quem pode ser contratado

Três faixas, e isso importa para o jogo não virar "colecione todo mundo":

1. **Moradores comuns** — recrutáveis com trabalho e comida. São a mão de obra.
2. **Pessoas com história** (Pedro, os avós, as mulheres libertas do cap. 7) —
   só se juntam depois de um evento da trama. Não têm preço.
3. **Mitos** — nunca são "contratados". Fazem **pacto**, com termo e cobrança.
   A Caipora não trabalha para ninguém; ela vigia caminhos e cobra pedágio.

### Árvore de talentos própria de cada NPC

Cada morador tem uma árvore pequena (5 a 8 nós) do seu ofício, e ela **diverge**:
o roceiro que você especializa em mandioca não vira o mesmo do vizinho. Como não
dá para maximizar todo mundo, duas partidas ficam diferentes.

O jogador tem a árvore grande (Terra, Água, Ar, Ritual — já no GDD).

### Grupos de jornada

Uma jornada leva de 2 a 4 pessoas, e o resultado depende de quem foi:
- Ofícios definem o que o grupo consegue fazer no caminho.
- Traços de personalidade definem o que dá errado.
- Um mito em pacto pode acompanhar — e cobrar depois.

Enquanto o grupo está fora, **o tempo corre**: é o mesmo princípio do tutorial,
em que a mandioca cresce sozinha enquanto você faz outra coisa.

## O problema da repetição

O feedback recorrente sobre o Romestead é que ele **cansa depois de um tempo**.
Vale desenhar contra isso desde já. Cinco apostas:

1. **O mito é a variável, não a rotina.** Cada pacto muda uma regra da economia
   (a colheita rende mais mas atrai algo; a pesca fica farta só de madrugada).
   O loop não se repete: ele **muta**.

2. **Recusar também é jogada.** No capítulo 7, Pedro quase morre por ter
   estendido a mão — e se salva por recusar. Pacto recusado tem consequência,
   então a decisão não é só "aceitar tudo".

3. **A estação invalida a rotina.** O que funciona no verão falha na seca. Já
   temos quatro estações e mata que muda; falta ligar isso à produção.

4. **Automatizar é progresso, não trapaça.** A cura do grind é o ofício: quando
   o roceiro assume o canteiro, o jogador sobe para a próxima camada de decisão.
   Quem continua capinando à mão depois de ter gente é quem se cansa.

5. **O capítulo tem fim.** Diferente de um survival aberto, temos enredo com
   começo e fim. A jornada da fazenda **acontece uma vez**. Conteúdo com fim
   cansa menos que conteúdo infinito.

> **Construção e melhoria agora têm sistema próprio:** ver
> [CONSTRUCAO.md](CONSTRUCAO.md). Este documento trata de gente — ofícios,
> pactos e jornadas.

## O que já está de pé

Nada dos sistemas acima está implementado, mas **a fundação de construir já
está**: [scripts/mundo/construcoes.gd](../../scripts/mundo/construcoes.gd) guarda
cada peça como sprite com colisão própria, **fora** do TileMapLayer, e expõe
`mover(id, celula)`. Foi feito assim de propósito — tile pintado não se move sem
repintar a vizinhança, e a vila vai precisar arrastar construção. A casa do
roçado e as três casas do vilarejo já passam por ele.

O vilarejo com casa dos avós, casa de vizinho e armazém também já existe no
mapa, com a trilha que o liga ao roçado. É a planta do primeiro arraial.

## Ordem sugerida

1. Ofícios e moradores comuns (resolve o grind da lavoura).
2. Construções do arraial — aproveitando `Construcoes.mover()`.
3. Pactos com mitos, começando pela Matinta do capítulo 7.
4. Jornadas com grupo — e aí os capítulos 6 e 7 viram jogáveis de verdade.
5. Árvores de talento (jogador e NPC).
