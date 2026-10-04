# Moradores do arraial

Quem mora em Bom Jesus dos Pobres, o que cada um quer, e como o jogo faz eles
falarem. O texto das falas mora em
[`data/dialogos/aldeoes.json`](../../data/dialogos/aldeoes.json); o Pedro tem
arquivo só dele, [`pedro.json`](../../data/dialogos/pedro.json), porque é ele que
conduz o tutorial.

## Quem existe

| Quem | Onde fica | Casa | Terra em que vive | Como se ganha | Fé |
|------|-----------|------|-------------------|----------------|----|
| **Pedro** | acompanha o jogador | na praia, perto do píer | — | — | — |
| **Seu Benedito** | no terreiro da casa dele | na chapada | `terreno_benedito` | compra, 2.600 réis — **depois da Zefa** | católica |
| **Dona Zefa** | de manhã no terreiro, de tarde no poço | no chão que era da mãe | `terreno_zefa` | a série das ervas **ou** compra | candomblé |
| **Cosme** | no quintal, com a enxada — e em Salvador depois da série da avó | a mesma da avó | `terreno_zefa` | — (vem com a terra dela) | candomblé |
| **Tonho** | no pontal, onde puxa a rede | cabana na terra dele | `terreno_tonho` | só favor: pagar a dívida | caboclo |
| **Dona Filó** | na porta de casa, de olho na estrada | a mesma do filho | `terreno_tonho` | — (vem com a terra dele) | católica |
| **Damião** | no cemitério, de manhã num canto e de tarde no outro | — (mora do cargo) | — | a missão do cemitério | católica |

## Ninguém fala de longe

Regra do jogo inteiro, e mora num lugar só: `Arraial._falar_como`. Fala de
morador só abre com o jogador **ao lado** dele (48 px). Se não está, o jogo
abre um passo mudo — *"Volte a falar com X"* — apontando para onde o morador
**está agora**, e o marcador segue enquanto ele anda. É o mesmo mecanismo da
volta à Dona Zefa nos marcos de fé, generalizado para todo mundo.

Nasceu de duas reclamações que eram a mesma coisa: a Dona Zefa falando ao pé do
ouvido de quem estava no píer, e a entrega das ervas travada — o jogador foi ao
lugar marcado, e o lugar marcado era onde ela tinha estado de manhã. Morador
tem posto de manhã e de tarde; marcador que não segue aponta para um terreiro
vazio. `_esperar_o_morador` é a espera que segue.

Cada passo de missão declara a **linha** a que pertence (`LINHA_DO_PASSO`).
Serve ao foco da HUD: quando um passo fecha, o foco fica **vago** — não cai no
vizinho de índice, e nenhuma outra linha o rouba — até o passo seguinte da mesma
linha abrir. Linha que não continua em quinze segundos acabou, e o foco cai na
missão mais importante.

## O que uma missão paga

Três feitios, e **nenhum é obrigatório**. Quem escolhe é **quem paga**:

| Feitio | Quando | Exemplo |
|---|---|---|
| **Comida** | quem paga tem casa e panela | a Dona Zefa faz doce, o Tonho faz pirão do que pesca |
| **Item** | o que a pessoa tem é ferramenta, não comida | o Damião entrega a foice que o jogador o ajudou a encabar |
| **Réis** | quem paga é **instituição**, não pessoa | a vaquinha do arraial pelo mirante; a côngrua da Santa Casa pelo cemitério |

**A única regra de verdade é do tutorial**, e é mecânica: antes da primeira
colheita o teto de fôlego é 100, a noite devolve 40, e arar, derrubar e rachar
custam centenas. Até a cozinha abrir, comida é a única fonte de fôlego que não
é dormir — então a maioria dos passos do `pedro.json` paga comida. É a **ponte**
até o jogador cozinhar sozinho, e acaba quando a ponte não é mais necessária.

Essa regra já foi generalizada por engano para o jogo inteiro, e o estrago foi
calado: a segunda obra pública do arraial pagava dois pirões, e o passo mais
trabalhoso do cemitério não pagava nada porque o Damião não tem comida em casa.
`testar_arraial.gd` agora guarda a ponte do tutorial (como **maioria**, para não
impedir que um passo entregue ferramenta) e deixa o resto livre.

`reis` é chave própria em `recompensas`, e não um id do catálogo — dinheiro vai
para a bolsa, não para a mochila, e assim não pode ser vendido, cozinhado nem
dado de presente.

---

**O Damião é o morador sem chão**, e é o que o separa dos outros. Os cinco
donos de terra existem porque têm terra; a Candinha existe por estar onde todo
mundo passa. Ele existe por um **cargo**: o intendente o nomeou zelador do
cemitério abandonado na semana da Páscoa e lhe deu um papel com o nome dele —
nem foice, nem enxada, nem tostão. O chão é da Santa Casa de Misericórdia, que
é quem enterra pobre neste país e que já era a dona dos terrenos do morro.

Por isso ele é o único que **não paga** nos passos da missão dele: os outros
pagam em pirão, cocada e beiju, comida de casa de quem tem casa. O que ele
entrega no fim é a **foice** que o jogador o ajudou a encabar — e ela não é
prêmio, é a ferramenta sem a qual o passo seguinte é impossível.

E é a missão que deu razão de existir à foice, que estava no catálogo com preço
no armazém e não servia para nada. O mato do cemitério é o único recurso do
jogo que **só sai de foice** e o único que **não rende item**: quem limpa
cemitério não leva nada para casa.

**Casa tem mais de um morador.** A Dona Zefa mora com o neto Cosme; o Tonho,
com a mãe, Dona Filó. Não é enfeite: é o que faz a regra de idade ter graça.
Quem não pode mais capinar divide teto com quem pode, e o jogador escolhe o
serviço **de cada um**, não do terreno — a avó trança cesto enquanto o neto
capina o mesmo chão.

A dívida do Tonho amarra os três: a mãe adoeceu, a Zefa tratou, o que faltou
veio fiado do armazém. Ele acha que valeu; ela acha que não; os dois brigam por
isso toda semana.

Cada um tem **casa com interior**, e o interior diz quem mora nela antes de o
dono abrir a boca: o Benedito tem estante de quem guarda papel de quarenta e
duas safras; a Zefa tem oratório, bacia e barril, que é onde o remédio se faz;
o Tonho tem rede, um barril e mais nada, que é o que cabe em quem deve.

## Terra comprada, morador que fica

Comprar não despeja. O morador continua na casa dele e passa a trabalhar para a
casa — e o que ele pode fazer depende de quem ele é:

| Trabalho | Braçal? | Quem pode |
|----------|---------|-----------|
| Roçado, corte de lenha | sim | só quem tem idade para isso |
| Casa de farinha, cestaria, criação de quintal | não | todos |

`Terrenos.IDOSOS` é uma lista curta e explícita de propósito: idade é coisa de
personagem, não de fórmula. Mandar Seu Benedito capinar o dia inteiro não é
progressão de jogo, é desaforo — então roçado e machado nem aparecem na lista
dele.

A escolha é feita na aba **Trabalho** do painel, que só existe com o morador a
um passo e em terra já sua.

**Quem vai pro roçado abre roça de verdade.** O pedaço de terreno reservado
(`Mundo.ROCAS`) é lavrado e plantado de mandioca em leiras — uma leira de pé, um
corredor livre —, e o morador passa a ficar no meio dela. Tirar ele da roça
devolve o chão ao mato. Trabalho que não muda a cara da terra não parece
trabalho, parece registro num papel.

A mandioca se arranca quando madura, de dois a três meses, e vai direto para a
casa de farinha — é a raínha da subsistência em Bom Jesus dos Pobres.

Cada um está onde está por um motivo, e o motivo aparece na fala. O Benedito
está na terra que quer vender. A Zefa está no chão que herdou e não vende. O
Tonho está no mar em vez de na terra dele — que é justamente o problema dele.


## O que ele rende, e por que dois Cosmes não rendem igual

Mandar trabalhar era decisão de uma vez só: dois de mandioca por dia, no
primeiro dia e no centésimo. Agora três coisas multiplicam o que um morador
entrega (`scripts/autoload/povoado.gd`):

| O quê | Varia de | Como sobe |
|-------|----------|-----------|
| **Perícia** no ofício | ×1,0 a ×2,4 | sozinha, um dia por dia de serviço |
| **Afinidade** com você | ×1,0 a ×1,5 | conversa e presente (ver `Afinidade`) |
| **Obras do arraial** | +0 a +0,85 | cinco obras comunitárias pelo mapa |

**A perícia é por morador E por ofício.** O Cosme com quarenta dias de roça não
nasce mestre de farinha ao ser mandado para a casa de farinha — ele recomeça do
zero ali. Como cada um só faz uma coisa por vez e o dia é um só, não dá para ter
todo mundo mestre em tudo: é daí que duas partidas divergem. Quatro degraus —
aprendiz, jeitoso (12 dias), bom de serviço (30), mestre (70).

**A afinidade não zera para estranho.** Estranho pago trabalha, só não se
esforça. Zerar tiraria a automação de quem não visita ninguém, e é a automação
que sustenta o meio do jogo.

**As obras do arraial não são suas.** A varanda aumenta o seu fôlego; estas
melhoram o que os *outros* rendem, e só valem para quem tem gente trabalhando.
Nenhuma é prédio novo: as cinco consertam peça que já estava no mapa e era
enfeite — poço da praça, forno de barro, monjolo do riacho, carroça, trapiche.
Ficam listadas na aba **Arraial** do painel, com o lugar de cada uma, e as três
que faltavam entraram no mapa.

A aba do trabalho mostra a perícia e quanto aquele ofício renderia **antes** de
o jogador mandar, e o número vem da mesma conta que entrega de manhã
(`Povoado.producao_do_dia`) — não de uma segunda cópia da fórmula.

Na teia de talentos: **Palavra de patrão** (+50% no rendimento) e **Mestre de
ofício** (cada dia de serviço conta por dois).

## Como a fala muda

Um morador não é placa: o que ele diz depende do que já aconteceu. O JSON lista
**assuntos** em ordem de prioridade, e o primeiro cuja condição bate é o que
sai. Assunto já dito não se repete na mesma visita, a não ser que tenha
`"repete": true`. Quando acabam os assuntos do dia, sai a `reserva`.

Condições que `scripts/npcs/aldeao.gd` entende:

| `quando` | Vale quando |
|----------|-------------|
| `sempre` | sempre |
| `ponte_caida` / `ponte_de_pe` | antes / depois de a ponte do rio grande subir |
| `tem_convite` | o jogador leu o convite no mural e está com ele |
| `terra_dele` / `terra_minha` | antes / depois de a terra daquele morador mudar de dono |
| `primeira_vez` | ainda não falou com ele hoje |

Condições novas entram em `_cabe()`, e a regra para aceitar uma é: **o jogador
precisa ter VISTO aquilo acontecer**. Nada de variável escondida decidindo o
humor de ninguém.

## O que eles plantam no enredo

As três falas sobre a fazenda do outro lado do rio não se contradizem — elas se
somam, e nenhuma explica nada:

- o **Benedito** diz que o avô dele cortava pau lá e parou de ir, sem nunca
  dizer por quê;
- a **Zefa** repara que o convite não tem assinatura, e manda levar sal;
- o **Tonho** viu luz parada no mato, na altura do peito, de madrugada.

É o capítulo 6 ([docs/enredo/capitulo-06.md](../enredo/capitulo-06.md)) visto de
baixo, pelo povo que fica. O jogador junta os três e decide sozinho o que
pensar — e é para isso que os três existem.

## Quem ensina a lutar

Dois, e cada um ensina o que é dele:

- **O Pedro ensina o ferro.** A lição abre quando o jogador conhece o bicho —
  um caititu vem atrás dele, ou ele passa da crista — e espera a caça acabar:
  ele não entra na mata atrás de quem está sendo perseguido. Bater o facão,
  derrubar um caititu, acertar três golpes fortes. O que ele passa adiante é a
  cicatriz do pai dele: **o bicho avisa antes de morder**. Paga em comida, como
  pagou o tutorial inteiro, e fecha avisando da onça.
- **O Cosme ensina a roda**, e só a quem é do terreiro (ver docs/mundo/FE.md). A
  ginga, a meia-lua e a rasteira. A avó dele chama aquilo de coisa de
  desocupado, e disse o mesmo do tio que o ensinou; ele pede que não se fale
  disso na vila. Depois que ele vai para Salvador, a lição que está correndo
  continua (treino é do jogador), mas a fala espera ele estar em casa: ninguém
  ensina a meia-lua por carta. Paga com o que a avó faz.

Código em `Arraial._frente_das_armas` e `_frente_da_capoeira`.

**E quem paga as metas do caderno** (ver docs/projeto/PLANO.md, "o prêmio da parede"):
o **Pedro**, aos dez caititus, com o gibão de couro do pai — a coisa que o pai
guardava para quando ele tivesse idade de entrar na mata sozinho, e que ficou
guardada porque ele ficou com a roça. E a **Dona Zefa**, às duas onças, com um
patuá: ela costura, a reza é dela, e o couro de onça quem leva é o jogador.
Código em `Arraial._frente_das_metas`; a conta mora no caderno.

## Arte

Quatro direções paradas por morador, geradas com
`tools/pixellab/gerar-aldeoes.ps1` e montadas numa folha de uma linha por
`tools/pixellab/montar-aldeoes.ps1`.

**Sem ciclo de caminhada.** Isto foi investigado a fundo e o resultado é que
não dá, hoje, pelo caminho barato:

- `POST /characters/animations` e `POST /animate-character` agora **resolvem um
  grupo de animação que já existe** — pedem `character_id` e
  `animation_group_id` na query e não aceitam corpo. Mandar o pedido de
  template devolve 422 (testado, sem custo).
- O que sobrou de criação são as rotas custom (`/animate-with-text-v2` e `v3`),
  que a própria documentação da API cobra a **20–40 gerações por direção** —
  entre 80 e 160 por morador, contra 1 por direção no modo template.
- Os quadros de caminhada do Pedro e do jogador foram gerados quando o modo
  template ainda estava exposto, e continuam valendo.

Gastar isso num palpite não se justifica. Em vez de andar, eles **vivem
parados**: respiram (um pixel, devagar), percebem quem chega de 64px e viram o
rosto, e quando estão sozinhos olham para outro canto de vez em quando. É o que
separa pessoa parada de poste, e custa zero.

Se o modo template voltar a ser exposto, a folha ganha as linhas de caminhada e
o script passa a usar `frame_coords` como o
[`pedro.gd`](../../scripts/prototipo_3d/guia_pedro.gd).

## O que ainda não existe

1. ~~**As missões de dono.**~~ As três existem desde setembro de 2026. A do
   Tonho é a dívida no armazém; a da Zefa é a série das ervas, que acaba com o
   neto dela embarcando para Salvador. ~~O Benedito só vende.~~ Desde outubro
   de 2026 ele tem o caminho de favor dele: a carroça do avô, que dá nome à
   casa, consertada em mutirão com o Cosme e o Tonho
   ([CHEGADA_E_MUTIROES.md](CHEGADA_E_MUTIROES.md)). Falta a compra da terra
   reconhecer o favor, como a do Tonho reconhece a dívida paga.
2. **Rotina de dia, o resto dela.** Cada morador tem **dois** postos desde
   setembro de 2026: o da manhã e o da tarde, que vira às 13h (ver
   `ALDEOES.tarde` e `Mundo._posto_de`). Quatro dos seis mudam de lugar — a
   Candinha não muda porque a garapeira é definida por estar onde todo mundo
   passa, e o Cosme não muda porque a tarde dele é a roça de quem o contratar.
   Quem trabalha para o jogador também não passeia: dia comprado é dia inteiro.
   O que falta é o **terceiro** posto e a variação por estação — e uma agenda
   que o jogador possa consultar, que hoje só se descobre andando.
3. **Equipamento visível.** O jogador já veste (`Equipamento`); o NPC ainda não
   mostra nada.
