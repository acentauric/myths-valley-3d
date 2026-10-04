# A chegada e os mutirões do arraial

Como o jogador conhece Bom Jesus dos Pobres no vale 3D: não por uma lista de
lugares, mas pelo que cada morador precisa dele. E como o arraial se ajuda nas
obras, que é o tema do capítulo 6 ("uns foram ajudando os outros nas passagens
quase virgens") trazido para o dia a dia.

Dados: [`data/missoes_guia.json`](../../data/missoes_guia.json) (a chegada,
do Pedro), [`data/missoes_roca.json`](../../data/missoes_roca.json) (a roça,
do Cosme) e [`data/missoes_carroca.json`](../../data/missoes_carroca.json) (a
carroça, do Seu Benedito). Regras: `scripts/prototipo_3d/cadeia_de_missoes.gd`.

## O que estava errado

A chegada tinha nove passos, e cinco eram "vá até": o píer, a praça, a casa
de pasto, a capela, o roçado. Os outros quatro eram contagem — duas lenhas,
mais quatro, três pedras — e o último entregava a enxada sem pedir nada com
ela. Nenhum passo pagava, e nenhum morador pedia coisa alguma: o jogador
atravessava o arraial como turista. As cadeias dos moradores, enquanto isso,
abriam ao primeiro passo perto do dono: no píer, antes de o Pedro terminar a
primeira frase, o Tonho já contava a dívida do armazém.

## As regras desta escrita

1. **Todo passo nasce de alguém.** Um morador que precisa de uma coisa, ou a
   casa do finado que precisa de fogo, de corda, de janta. O resumo do HUD diz
   a INTENÇÃO ("Busque a chave com a Dona Zefa"), nunca a coordenada ("Vá até
   a casa da Zefa"). O marcador mostra onde; o resumo diz por quê.
2. **Ninguém é mandado só ir.** Ir é consequência de cumprimentar, perguntar,
   levar, consertar. O lugar é onde a pessoa está — e o marcador segue a
   pessoa (`MORADORES.md`, "Ninguém fala de longe").
3. **Pergunta leva a pergunta.** A chave da casa não está com o Pedro: está
   com quem a Dona Candinha diz que está. O jogador descobre o arraial pelo
   fio da conversa, e cada resposta é o passo seguinte.
4. **O Pedro anuncia antes de cobrar** (regra 1 do tutorial do 2D): a
   ferramenta chega à mão na mesma fala que pede o trabalho.
5. **A ponte do fôlego.** Até a cozinha abrir de verdade, comida é a única
   fonte de fôlego além da cama (`MORADORES.md`, "O que uma missão paga").
   Quem pede paga, com o que tem em casa: o Tonho em peixe, a Candinha em
   garapa, a Dona Zefa em cocada, a avó do Pedro em mungunzá. A recompensa
   diz o nome de quem pagou (`quem_paga`), e não o do dono da cadeia.
6. **Cada passo ensina uma coisa, quando ela serve.** O machado chega quando
   falta lenha; a bancada, quando falta corda; o J de obras, quando há obra;
   a cama, quando escurece.
7. **Os pedidos esperam a apresentação.** As cadeias dos moradores só abrem
   depois que o Pedro termina a chegada, como as do arraial e a da fé já
   faziam — é a ordem do 2D ("depois que o Pedro termina de ensinar a
   sobreviver"). Quem o Pedro apresenta não atropela a apresentação.

## A chegada (Pedro, `missoes_guia.json`)

Dois dias. O primeiro é a casa do finado; o segundo, a roça e o convite.

| # | Passo | Quem pede | O que se faz | Ensina | Paga |
|---|---|---|---|---|---|
| 1 | Quem chega, cumprimenta | o costume (Pedro) | dar bom-dia ao Tonho no píer | andar até alguém | o Tonho: 1 peixe |
| 2 | Quem guardou a chave | o Pedro não sabe | perguntar à Dona Candinha, na praça | o marcador que segue a pessoa | a Candinha: 1 garapa |
| 3 | A chave com a Dona Zefa | a Candinha manda | buscar a chave com a Dona Zefa | a pergunta que leva à pergunta | a Zefa: 1 cocada |
| 4 | Fogo na casa fechada | a Zefa ("casa fechada junta frio") | juntar 4 lenhas | o machado na barra de mão (1–0), o E no tronco | a avó do Pedro: 1 beiju |
| 5 | A boca do poço | a Zefa, no poço | tirar 3 pedras do lajedo do poço | a picareta | — |
| 6 | Corda nova | o poço | torcer 1 corda na bancada | a bancada da oficina (J) | — |
| 7 | Mutirão no poço | a Zefa, com o Cosme | a obra "Corda nova no poço" | a aba de obras (J); o mutirão | a Zefa: o balde do finado e 1 cocada |
| 8 | A primeira janta | a fome | assar o peixe do Tonho na fogueira | a cozinha (J no fogo do terreiro) | — |
| 9 | A primeira noite | o escuro | dormir na cama da casa | a cama que vira o dia | a avó do Pedro: 1 mungunzá e 4 manivas |
| 10 | A roça do finado | a terra parada (o Cosme capinava para o tio) | arar, plantar e regar uma leira | a lavoura, a semente na mão, o balde | o Cosme: 1 beiju |
| 11 | O papel sem assinatura | o convite que chegou a cada casa | ler o convite (F na mochila) | ler documento | — |

O arremate é o gancho do capítulo 6: o convite não tem assinatura, vem da
fazenda que ninguém nunca viu o dono, e os avós do Pedro já decidiram ir. O
Pedro volta ao píer, e o arraial abre: as cadeias dos moradores, a do mirante
e a da fé.

O passo 7 é o primeiro mutirão do jogo: a Dona Zefa e o Cosme vão ao poço e
ficam lá enquanto a obra não sai. A obra é pequena e nova (`poco_corda`, uma
corda e três pedras), e não a "Roldana e cacimba no poço" do arraial
(`arraial_poco`), que continua sendo a obra de rendimento de depois.

## A roça do finado (Cosme, `missoes_roca.json`)

Abre quando a chegada passa da leira plantada, e corre ao lado do resto — é a
"frente" do 2D: roça não é fila, e a mandioca cresce enquanto o jogador vive.

| # | Passo | O que se faz | Ensina | Paga |
|---|---|---|---|---|
| 1 | Até a rama amarelar | regar e dormir até colher | o tempo da roça (um estágio por dia regado) | — |
| 2 | A primeira farinha | torrar farinha na fogueira | a farinha (o passo se chama `cozinhar`, a porta do 2D) | — |
| 3 | A cuia da Dona Filó | levar 1 farinha à Dona Filó | o costume: a primeira farinha vai para quem não planta mais | a Filó: 1 pirão, e ela ensina o pirão (o passo se chama `pirao`) |

## A carroça do Seu Benedito (Benedito, `missoes_carroca.json`)

O Benedito era o único morador sem caminho de favor (`MORADORES.md`, "O que
ainda não existe"). A casa dele chama "do carro quebrado" por causa da
carroça do avô, que partiu o eixo na volta da cheia de fevereiro; desde então
ele desce a colheita do saveiro no ombro, três viagens por saco.

| # | Passo | O que se faz | Paga |
|---|---|---|---|
| 1 | Tábua para o estrado | juntar 8 tábuas (bancada) | — |
| 2 | Corda e calço | juntar 4 cordas e 4 pedras | — |
| 3 | Mutirão na carroça | a obra "Recuperar a carroça" (`arraial_carroca`), com o Cosme e o Tonho | o Benedito: 6 grãos de milho e 3 milhos |

É a obra de rendimento do arraial, a de verdade: tábua 20, corda 10, pedra 4.
O jogador junta a parte dele, e o **mutirão traz o resto** — o Cosme chega
com 12 tábuas, o Tonho com 6 cordas. É o que faz o mutirão ser mecânica, e não
enfeite: quem vem ajudar traz o que tem, e o HUD diz quem trouxe o quê.

## As mecânicas novas

| Campo no passo | O que faz |
|---|---|
| `quem_paga` | o morador que paga a recompensa; o HUD diz "Recebido de Tonho" |
| `entrega` como lista | mais de uma coisa na mesma fala (a enxada E a maniva) |
| `meta.eventos` | o passo fecha quando TODOS os acontecimentos da lista aconteceram (arar, plantar, regar), com a conta no HUD |
| `mutirao` | os moradores que ajudam vão ao lugar do passo e ficam até ele fechar; com itens, cada um os entrega ao chegar ("Mutirão: o Cosme trouxe 12 tábuas") |
| `roda` | o raio da roda do mutirão em volta do lugar (2,4 u por padrão): a carroça fica no terreiro de uma casa de 2,6 u de meia largura, e a roda dela é de 4,2 |

Os acontecimentos que um passo pode esperar (`meta.evento`) passaram de dois
para todos estes, avisados a todas as cadeias, inclusive a do Pedro:

| Acontecimento | Quem avisa |
|---|---|
| `cozinhou:<receita>`, `comeu:<comida>` | `Cozinha` |
| `fabricou:<material>` | `Oficina` |
| `arou`, `plantou`, `regou`, `colheu` | a lavoura do vale |
| `dormiu` | a cama (a noite que vira pela porta da cama) |
| `leu:<documento>` | a mochila (F em cima do papel) |
| `abriu_arraial`, `adotou_fe` | como antes |

E duas portas que faltavam: a receita aceita uma LISTA de passos que a
ensinam (o peixe na brasa abre na pesca do 2D e na janta do vale), e a
`oficina` entra no contrato dos lugares, porque a bancada provisória já existe.

## Os portões

- `tests/cadeia_das_missoes.gd` joga a chegada inteira pelo caminho do jogo:
  ao lado de quem se fala, a bancada, a obra, a cozinha, a lavoura pela
  ferramenta na mão, a cama e o papel lido. Nenhum passo fecha por
  `registrar_evento` chamado de fora: o acontecimento tem de chegar pelo fio
  que o vale ligou.
- `tests/pedidos_do_arraial.gd` cobra quem paga, a roça do Cosme, o mutirão da
  carroça (chamar, trazer ao chegar uma vez só, dispensar) e o save de antes da
  chegada nova.
- Os portões das cinco filas dos moradores (`cadeia_da_candinha`, `_da_filo`,
  `_da_zefa`, `_do_coveiro`, `_do_tonho`) provam a regra 7: ao lado do
  morador, com a chegada em curso, a fila não abre.
- `tests/ferramentas.gd` lê as nove cadeias e cobra que todo acontecimento
  esperado seja um que o vale avisa, e que quem paga e quem vem ao mutirão
  more no vale.

## O save de antes

A chegada nova guarda o id do passo e a memória dela (encontros,
acontecimentos, mutirão). O save das Builds #7 e #8 só tinha o índice na lista
velha de nove passos: quem tinha acabado continua acabado, e quem estava no
meio volta ao passo novo que faz o mesmo papel (`Prototype.CHEGADA_ANTIGA_PARA_NOVA`).

## O que fica para a arte (próximo pedido)

Nada aqui depende de arte para funcionar; o que segue é o que a deixaria
inteira, e é geração paga — espera autorização:

- **Vozes do Pedro** para os passos 3 a 11, e as respostas do Tonho, da
  Candinha, da Zefa, do Cosme, da Filó e do Benedito (ElevenLabs, as vozes de
  cada um em `VALE_VIVO_3D.md`). Os passos 1 e 2 reaproveitam `pedro_pier` e
  `pedro_praca`, porque a fala nova começa com a frase gravada.
- **A carroça** do Seu Benedito em dois estados, quebrada e consertada, para a
  obra mudar o terreiro dele (Tripo, `modelos-3d`).
- **A roldana com corda nova** no poço, para o mutirão do passo 7 se ver.
- **O convite** como papel na mão e na mochila (ícone e folha).
