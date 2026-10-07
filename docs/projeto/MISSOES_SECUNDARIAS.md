# As missões secundárias dos moradores — plano de implantação

Pedido do autor em 07/10/2026: "criamos NPCs novos para o 3D; criar missões
secundárias para interação com esses NPCs". Toda a lista do 2D já está no vale
([MISSOES_DO_2D.md](MISSOES_DO_2D.md)); este plano é o que o 3D acrescenta por
conta própria, e por isso vive num documento à parte.

## O ponto de partida

O vale tem 22 moradores (`data/npcs_3d.json`). Oito têm fila de missão (Pedro,
Benedito, Zefa, Cosme, Tonho, Filó, Candinha, Damião; o Quirino entra pelo
saveiro). Os outros **catorze** só cumprimentam, conversam e recebem presente:

| id | quem | onde passa o dia |
|---|---|---|
| `padre` | Padre Anselmo | cemitério de manhã, casa à tarde, igreja ao entardecer |
| `sacristao` | Sacristão Zacarias | igreja e cemitério |
| `beata` | Sá Joaquina | poço, casa, igreja |
| `mercador` | Seu Nicolau | o bar/venda, o dia todo |
| `guarda` | Guarda Aristides | praça e igreja |
| `pescador` | Seu Jerônimo | beira do rio de manhã, casa, praça |
| `marisqueira` | Dona Rosa | beira do rio de manhã, casa |
| `lavadeira` | Sá Rita | ponte do rio central de manhã, varal |
| `rendeira` | Dona Estefânia | casa (a janela), praça à tarde |
| `quituteira` | Dona Ambrósia | praça de manhã, igreja |
| `carpinteiro` | Seu Epifânio | a canoa, ao lado de casa |
| `menino` | Tonico | casa do carpinteiro, poço à tarde |
| `menina` | Mariinha | casa da quituteira, poço à tarde |
| `mestre_saveiro` | Seu Ladislau | beira do rio |

Eles **não vieram do 2D**: nasceram no 3D. Mas todos já têm texto escrito em
`data/dialogos/aldeoes.json` — a apresentação, duas conversas que a afinidade
abre (`afinidade_2`, `afinidade_3`) e o gosto de presente de cada um — e o 3D
**não mostra os assuntos** (só o Pedro lê `quando`). Várias dessas falas são
ganchos de missão prontos; a regra 7 do HISTORICO ("antes de escrever texto
novo, conferir se o texto já existe e não está chegando") manda partir delas.

## As regras que valem para todas

- **Uma fila por favor, pendurada pela tabela** `data/favores_dos_moradores.json`
  (`prototype._pendurar_as_secundarias`): dono, arquivo, chave, grau de
  afinidade e a fila que tem de ter acabado antes. Nenhum `elif` novo no vale.
- **Trancada pela afinidade.** A fila abre quando o morador conhece o jogador
  (`Afinidade.grau`: 1 = Conhecido de vista, 2 = Gente boa, 3 = Amigo) e a
  chegada do Pedro acabou. O aviso da trancada ("passe aqui mais vezes", nos
  três idiomas, regra 7 do `missoes_elos`) **não toma a conversa do primeiro
  encontro**: fica quieto até cinco pontos de afinidade (`avisa_a_trancada`) e
  sai uma vez (`aviso_repete`), devolvendo ao morador as falas dele — que são o
  que sobe a afinidade todo dia.
- **Fechar a fila é o favor** (`Afinidade.POR_FAVOR`, +25): até 07/10 ninguém
  chamava `fez_o_favor`; agora toda fila de morador da teia o dá ao acabar
  (`cadeia_de_missoes._dar_o_favor`). É o salto que leva de "Conhecido" a
  "Gente boa" e abre a conversa seguinte.
- **Só mecânica que existe** nas fases 1 e 2: `levar`, `falar`, `visitar`,
  `oferendar`, `evento` com acontecimentos que o vale já emite (`leu:`,
  `pescou`, `dormiu`, `entrou:`), itens com fonte (regra 4 do `missoes_elos`).
  Mecânica nova só na fase 3, declarada aqui.
- **Texto nos três idiomas**, e lugar que resolve no `Lugares` (as casas dos
  moradores entraram no contrato: `casa_da_rendeira`, `casa_do_pescador`…, e
  `beira_do_rio`).
- **Portão** `tests/missoes_secundarias.gd`: todo morador do arraial tem fila;
  as da tabela estão no dono certo, trancadas até o grau, com o aviso; um favor
  joga do começo ao fim e sobe a afinidade. O `missoes_elos` continua cobrando
  ids, lugares, fontes, o E na pessoa certa e o caminho.

## Fase 0 — os alicerces (07/10/2026, feita)

`Lugares` com as casas; o favor da afinidade no fim da fila; a tabela e o laço
que pendura; o portão; as contas do `missoes_elos` (39 arquivos, 114 passos) e
os arquivos no `tests/idiomas.gd`.

## Fase 1 — os catorze favores (07/10/2026, feita)

Um passo cada, meta `levar`, a recompensa em coisa que o morador tem. O que um
dá, outro pede — o lampião do Nicolau é o da Estefânia; a cocada da Ambrósia é a
do Tonico.

| fila | morador | pede | paga | gancho |
|---|---|---|---|---|
| `rendeira_favor` Luz para a renda | Estefânia | 1 lampião | xp | "agora eu rendo até de noite"; a toalha sai da gaveta |
| `sacristao_favor` Garapa para o sino | Zacarias | 2 garapas | xp | garganta seca; deve a história da pedra do altar |
| `beata_favor` O chá da tosse | Sá Joaquina | 1 chá de folha | xp, 1 beiju | a tosse; "só conto pra quem reza comigo" |
| `mercador_favor` A prateleira da venda | Nicolau | 2 tábuas | xp, 1 lampião | "tava precisando pra prateleira" |
| `guarda_favor` Peixe para a ronda | Aristides | 1 peixe assado | xp | a ronda; o passo no adro |
| `pescador_favor` Corda para a linha | Jerônimo | 2 cordas | xp, 1 robalo | "linha boa nasce de corda boa"; a madeira com letra |
| `marisqueira_favor` Farinha para o sururu | Rosa | 2 farinhas | xp, 3 ostras | o mangue de Iemanjá; a maré das cinco |
| `lavadeira_favor` Lenha para a fervura | Sá Rita | 3 lenhas | xp | "a roupa conta a vida de quem veste" |
| `quituteira_favor` O tabuleiro da tarde | Ambrósia | 3 milhos, 2 ovos | xp, 2 cocadas, 1 beiju | o tabuleiro; "diga que a mãe disse não" |
| `carpinteiro_favor` Madeira para a canoa | Epifânio | 2 madeiras de coqueiro, 1 corda | xp, 3 tábuas | as três batidas; a canoa do Tonho |
| `menino_favor` A cocada escondida | Tonico | 1 cocada | xp, 1 manga | o caminho na mata; "quem leva fica com dívida" |
| `menina_favor` Milho para a cocada | Mariinha | 2 milhos | xp, 1 cocada | cocada de milho verde sem dendê (caju ainda não tem pé que dê fruto no vale); a roda da praia |
| `ladislau_favor` Corda para o saveiro | Ladislau | 3 cordas | xp, 2 peixes | a escota do traquete; a luz na água |
| `padre_favor` Beiju para a sacristia | Anselmo | 2 beijus | xp | a mesa da sacristia; o último banco do tio |

## Fase 2 — os quatro arcos de enredo (07/10/2026, feita)

Abrem com o favor feito e o grau 2 (Gente boa). Costuram o mistério do tio e da
fazenda do convite. Itens novos, todos documentos ou um pano, com o ícone de
algo que já existe onde couber:

1. **A toalha do tio** (`rendeira_toalha`, Estefânia). Ela entrega a
   `toalha_de_renda` na janela (item novo, ícone novo) → `oferendar` na mesa da
   casa de taipa → arremate: "era pra mesa de alguém que ia chegar — e chegou".
2. **A pedra atrás do altar** (`sacristao_pedra`, Zacarias). Ele entrega o
   `papel_dos_nomes` (documento, ícone `carta`, texto em `data/documentos.json`)
   → `leu:papel_dos_nomes` em casa → `falar` com ele de novo → arremate: os nomes
   são os que o convite chama; o do tio está riscado, o do jogador ainda não.
3. **A madeira com letra** (`pescador_madeira`, Jerônimo). Ele entrega a
   `tabua_lavrada` (documento, ícone `tabua`) → `leu:tabua_lavrada` → `falar` com
   o padre, que lê: a proa da Senhora da Boa Viagem, o barco do engenho; o brasão
   apagado é o que falta no selo do convite.
4. **A luz na água** (`ladislau_luz`, Ladislau). Ele conta → `visitar` a ponte do
   rio grande (a foz) → `falar` com o Quirino no dia do saveiro → arremate: a luz
   parou onde a Senhora da Boa Viagem afundou.

## Fase 3 — as pontes entre moradores e as missões de ação (a fazer)

Pedem um pouco de mecânica nova, cada uma pequena e declarada:

- **Hora no `visitar`** (`"horas": [19, 23]`): a roda na praia (Mariinha e Rosa,
  maré cheia de noite), a ronda do guarda (três voltas na praça de noite), a
  vigília do sino (igreja de madrugada; toca o fantasma da mata), a maré das
  cinco (Rosa; `juntar ostra` entre 5 e 7 h).
- **A canoa do Tonho** (Epifânio ↔ Tonho): `falar` com o Tonho ("por que não
  usa"), levar madeira e corda, e a canoa dele volta à água (uma obra pequena,
  `obra` em sítio novo ao lado da casa da estrada).
- **O livro de fiado** (Nicolau ↔ Tonho e Candinha): quitar a conta dos dois
  (`levar` réis ou peixe) e o Nicolau abre mercadoria nova na venda.
- **A carta da filha** (Rosa ↔ padre): `carta_da_rosa` (documento) vai ao padre
  e volta com a resposta; `leu:`.
- **O caminho do Tonico** (grau 3): `visitar` a Lapa pela trilha da mata, com a
  "dívida" que o pai fala — uma noite sem dormir (`evento dormiu` negado) ou um
  presente ao Caipora.
- **A promessa de Sá Joaquina**: `oferendar` na areia o que o mar devolve, em
  nome dela (ela nunca pisa na praia).
- **A água do rio grande** (Sá Rita): `visitar` a ponte com ela e `falar` — o
  que não é terra na água, gancho da fazenda.
- **O que está enterrado perto do casarão** (Aristides, depois da jornada da
  fazenda): `visitar` o casarão e `falar` — memória do engenho; pede cuidado no
  tom e revisão do autor antes de entrar.

## Fase 4 — o que pede sistema (a decidir com o autor)

- **Bola de capim** com o Tonico: um minijogo na praça. Sem sistema de bola no
  vale; ou vira `visitar`/`falar` em três dias seguidos, ou espera.
- **O terço das seis** (Sá Joaquina): rezar com ela em dias seguidos pede
  contagem por dia (`contar` com dia) — a recompensa são as pistas.

## O que não muda

Os oito moradores com fila do 2D continuam com as filas de lá. As falas de
`aldeoes.json` não se reescrevem: as filas as citam, na voz de cada um. O 2D
não é tocado — estes catorze são do 3D.
