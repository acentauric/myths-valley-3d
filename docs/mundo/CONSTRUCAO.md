# Construção e melhoria

Toda construção do jogo pode ser melhorada: a casa do jogador, a casa do Pedro,
a venda do arraial, a casa de farinha, o engenho, a cabana de pesca. Algumas por
vontade do jogador, outras como pedido de NPC dentro de uma missão.

**A regra que manda em tudo: não é uma escada.** As obras formam um grafo, com
pré-requisito e com exclusão. Duas partidas não terminam com a mesma casa.

Catálogo: [data/construcoes/obras.json](../../data/construcoes/obras.json).
Sistema: [scripts/autoload/obras.gd](../../scripts/autoload/obras.gd).

## Os três eixos

| Eixo | O que muda | Independente de |
|------|------------|-----------------|
| **casca** | O corpo da construção: arte externa, pegada, colisão | planta e mobília |
| **planta** | O que existe dentro: parede interna, cômodo, piso | casca e mobília |
| **mobilia** | O que está dentro dos cômodos | casca e planta |

Subir a casca não obriga a mexer na planta. Trocar mobília não pede casca nova.
Por isso são eixos, e não níveis: o jogador pode ter uma casa de taipa de um
cômodo com mobília boa, ou um sobrado azulejado vazio por dentro.

## O grafo, e por que ele importa

Duas obras da planta se excluem:

- **Levantar parede e fazer quarto** → ganha lugar de guardar, perde o salão.
- **Abrir o salão** → cabe muita gente, e é onde a festa acontece.

E cada uma abre uma continuação diferente:

```
planta_quarto ──► planta_oficina   (bancada, torno, ferramenta)
planta_salao  ──► planta_venda     (balcão virado para a estrada)
```

Quem fez quarto nunca vai ter venda em casa. Não é punição: é que a casa do
jogador vira uma coisa ou outra, e escolha que não fecha porta nenhuma não é
escolha.

A casca, essa sim, é sequencial — taipa → varanda → sobrado — porque o corpo da
casa cresce por cima do que já existe. Mas **subir a casca é opcional**: dá para
jogar a campanha inteira numa casa de taipa bem resolvida por dentro.

## Preço

Obra custa material, não dinheiro: tábua, lenha, pedra, corda, farinha. É o que
amarra o sistema de construção ao de recurso — derrubar mata e vender na venda
passam a ter destino.

Obra de NPC costuma vir pela missão: o NPC pede, o jogador leva o material, e o
`Obras.conceder()` entrega sem cobrar de novo.

## Como o mundo aplica

`Obras.concluida` é ouvido por `mundo.gd`:

- eixo **casca** → `Construcoes.trocar_casca()` troca a textura e refaz a
  barreira, e a malha de caminho é remontada (a pegada mudou).
- eixo **planta** ou **mobilia** → `InteriorCasa.refazer()` reconstrói parede
  interna e mobília sem tocar no casco do cômodo.

A barreira de cada construção é **calculada da arte**, não escrita à mão: o vão
da porta fica no meio de baixo e o resto é parede. Com quinze construções no
catálogo, medir cada uma à mão seria erro garantido.

## A casa do jogador: começa vazia e cresce

A casa abre o jogo com **três coisas**: a cama, o baú e a lareira. Onde dormir,
onde guardar, onde cozinhar. Nada mais.

Antes ela vinha com estante, mesa, banco, barril, bacia, vassoura e vaso — e
casa que já tem tudo não deixa nada para a obra fazer. Cada peça que saiu virou
melhoria, e cada melhoria tem **lugar guardado** dentro do cômodo
(`InteriorCasa.MOBILIA_POR_OBRA`): o espaço já existe, só está esperando.

As melhorias são agrupadas por **compartimento**, e a aba de obras lista assim:

| Compartimento | O que entra |
|---------------|-------------|
| Casco | varanda, sobrado |
| Dormida | rede no lugar da cama |
| Fé | oratório na cabeceira |
| Guardado | estante de parede |
| Convívio | mesa grande e banco, tapete |
| Cozinha | bacia e barril |

**A casa começa de chão batido.** `planta_assoalho` troca a terra batida por
tábua corrida — e é a obra mais visível que existe, porque muda o cômodo
inteiro de uma vez. Antes o chão já era de tábua desde o primeiro dia, a obra
prometia trocar o que já estava trocado, e o jogador (com razão) não via
melhoria nenhuma.

**A casca muda os dois lados.** `casca_varanda` troca a fachada (`casa_n1` →
`casa_n2`) **e** o cômodo por dentro, de 11x8 para 15x10; o sobrado leva a
17x12. É esse chão novo que faz a cozinha e o tapete caberem — por isso as duas
pedem a varanda no catálogo. Casa que muda por fora e continua do mesmo tamanho
por dentro não parece obra, parece pintura.

Duas coisas que estavam erradas e foram consertadas junto:

1. **A rede sumia com a cama.** `mobilia_rede` apagava a cama e não punha nada
   no lugar. Agora a peça nova ocupa o MESMO lugar da velha.
2. **Obra de casca não avisava o interior.** A fachada trocava e o cômodo
   ficava igual. Agora o interior se refaz em qualquer eixo.

## Onde se faz obra

Encoste na construção e aperte **E** — o painel abre já na aba Obras. Dentro de
casa, a aba aparece sempre. A aba lista só o que dá para fazer agora, com o
custo e o que está faltando.

## Duas bancadas, não uma

A **oficina de material** e o **canteiro de obras** são construções separadas, e
de propósito: uma é braço, a outra é prancheta. Nenhuma faz o trabalho da outra,
e cada uma evolui por conta.

| | Oficina de material | Canteiro de obras |
|---|---|---|
| O que faz | serra tábua, torce corda | decide e barateia obra |
| Aba do painel | Oficina (e Obras, para melhorar a si mesma) | Obras |
| Como evolui | serra de fita, tear, galpão | prancheta, depósito, galpão |
| O que a melhoria muda | a mesma lenha **rende mais** peça, e a peça custa menos fôlego | **toda obra do mapa** custa menos material |

### As duas começam como MESA

No começo do jogo as duas são uma **bancada a céu aberto** — uma mesa de
carpinteiro com serrote e uma mesa de cavalete com a planta em cima —, e não o
galpão de telha. Quem chega da capital sem um tostão não é dono de galpão.

O galpão é obra do eixo **casca** (`oficina_galpao`, `canteiro_galpao`), e é ele
que troca a arte pela construção coberta. A arte inicial de cada construção está
em `Mundo.ARTE_INICIAL`; `Mundo._arte_de()` devolve a casca já feita, se houver.
A arte do galpão continua a mesma de antes, no catálogo — ela só deixou de ser o
ponto de partida.

O rendimento sai de `Oficina.rende()`, que lê as obras feitas na oficina; o
desconto sai de `Obras.desconto()`, que soma as obras do canteiro com o talento
`mao_de_obra` e tem teto de 50%. Obra nenhuma fica de graça: `Obras.custo()`
nunca zera um item.

## Terrenos: de quem é o chão

Toda terra tem dono (`scripts/autoload/terrenos.gd`). O jogador começa com o
roçado e ganha os vizinhos do jeito que o **terreno** define — não o jogo:

| Modo | Como se ganha | Exemplo |
|------|---------------|---------|
| `compra` | paga o preço na placa | Seu Benedito, 2.600 réis |
| `missao` | o dono não vende; quer um favor | Tonho, a dívida dele |
| `missao_ou_compra` | os dois caminhos valem | Dona Zefa |

**Terra só se toma pela divisa.** Não dá para comprar um pedaço solto do outro
lado do arraial: o terreno precisa encostar em chão que já é seu
(`Terrenos.VIZINHOS`). Para chegar no do Seu Benedito é preciso ter o da Dona
Zefa antes, porque é ela que faz divisa com o roçado — e a placa do Benedito
diz isso, em vez de mostrar um preço que não adianta.

**Comprar não despeja ninguém.** O morador continua na casa dele, dentro da
terra que agora é sua, e passa a trabalhar para a casa. Quem escolhe o serviço
é o jogador, na aba **Trabalho** do painel (aparece com o morador a um passo).
E o serviço depende de quem ele é: Seu Benedito tem setenta e poucos anos e a
Dona Zefa não é muito mais nova — roçado e machado nem aparecem na lista deles.
Farinha, cestaria e criação de quintal, sim.

Não há cerca entre terrenos, só a **placa**. O que separa o seu do dele é o
que dá para **arar**: qualquer chão de terra sua que não seja caminho, água
nem pé de construção (`GeradorMundo.chao_lavravel`). O canteiro marcado
acabou — o jogador lavra onde quiser dentro do que é dele.

Das missões de dono, a do Tonho (`divida_do_tonho`) existe desde setembro de
2026 e chama `Terrenos.conceder()` no fim. A da Dona Zefa (`favor_da_zefa`)
ainda não; o terreno dela é `missao_ou_compra`, então o caminho da compra
funciona e o do favor é o que falta.

## O que ainda não existe

1. ~~**Mover construção.**~~ Existe: a tecla **G** pega a construção que estiver
   debaixo da mira e o **E** assenta onde o jogador estiver olhando (ver
   `Mundo._mudar_de_lugar` e `_largar`). Vale para móvel dentro de casa também.
   Peça de cenário fixo recusa — o píer não sai da praia, a ponte não sai do
   vau, a ruína é onde o capítulo 7 acontece. O que falta é **arrastar com o
   mouse**, que é outra coisa e não é o que estava prometido aqui.
2. **Obra de NPC amarrada em missão.** O sistema aceita (`conceder`), mas
   nenhuma missão usa ainda.
3. **Planta livre.** Hoje a parede interna é uma posição fixa. O alvo é o
   jogador escolher onde levantar.
4. **Dinheiro em obra.** Hoje só material. Réis entram quando a venda estiver
   madura.
