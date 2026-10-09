# Colisão das árvores — auditoria do catálogo (#150)

O pedido: revisar as colisões de todas as árvores — troncos e bases sólidos que
não se atravessam, copas que não bloqueiam passagem, jogador e moradores
passando e interagindo junto delas. A parte física já tinha portões que montam o
vale (`colisao_das_arvores`: o eixo do corpo contra o tronco desenhado, inclusive
nas palmeiras que pendem para o mar; `colisoes_do_vale`: caixa, cilindro e
câmera; `navegacao`: a rota contorna o corpo físico, com a inclinação do
tronco — ver [ROTAS_PORTAS_E_TRONCOS.md](ROTAS_PORTAS_E_TRONCOS.md)). Faltava a
auditoria de **todas as espécies** contra a madeira desenhada, e é ela que está
aqui.

## Como se mediu

`python tools/tripo/auditar_troncos.py raio` lê cada GLB (sem abrir o Godot),
põe o modelo na altura do catálogo, com o pé em y = 0, e atira raios horizontais
em 16 direções a 0,4, 0,8, 1,2 e 1,6 m, no eixo do tronco. O raio visível é a
mediana da distância do eixo ao primeiro triângulo. Ele é comparado ao `tronco`
do catálogo, que é o raio do cilindro. O corpo do jogador (cápsula de 0,28)
soma ao cilindro, então um cilindro até 0,28 abaixo da madeira ainda barra no
contato visual, e um cilindro 0,3 acima deixa o jogador a uns 0,6 m da casca.

## O que a medida mostrou

Das 32 espécies de tronco, 29 ficam entre -0,21 e +0,32 de diferença
(cilindro menos madeira), a maior parte entre 0 e +0,2: o catálogo está
calibrado, e nenhum cilindro cobre copa — todos têm no máximo 3 m (o cajueiro,
2,2 m) e o raio é o do tronco. Nada foi alargado nem encolhido.

| Espécie | Cilindro | Madeira visível | Leitura |
|---|---|---|---|
| mata_alta | 0,45 | 0,59 | a base se alarga a 0,7 em 0,8 m; a cápsula do jogador cobre a diferença |
| mata_larga | 0,50 | 0,61 | idem, 1,0 na raiz |
| jequitibá | 0,60 | 0,70 | idem, raiz tabular |
| cajueiro | 0,70 | 0,38 | tronco torto e baixo; o cilindro de 2,2 m foi calibrado no eixo medido |
| jatobá | 0,45 | 0,17 | a mais folgada entre as de fuste único (+0,28), à beira do limite |
| mangue | 0,60 | 0,17 no fuste | raízes escoras se abrem a 1,2–1,6 u; o cilindro cobre o miolo |
| ingazeiro | 0,40 | 0,28 | media 0,12–1,9 antes de tirar a laje de terra que vinha no GLB (#141); agora é um fuste só |
| touceira de bambu | 0,90 | 0,14 por colmo | os colmos se abrem a 1,3 u; o cilindro cobre o miolo |
| gameleira | 0,95 × 1,0 | 2,5 nas sapopemas | o tronco liso mede 1,2–1,4 u entre 2 e 2,5 m do pé (medida de 09/10, depois de a árvore descer de 18 m para 11, #228); as sapopemas são abas baixas que se pisam |

Mangue, bambu e gameleira estão em `SEM_TRONCO_UNICO` no portão, com a razão (as três de fora da faixa). O ipê-amarelo
e a pitangueira, cuja medida sai estreita (0,03 e 0,13), são as de malha de
costas da #156: o primeiro triângulo é o fundo da parede.

## O que o portão guarda

`tests/colisao_do_catalogo_das_arvores.gd`, sem montar o vale (fonte dos
números, não a física):

1. Toda árvore do catálogo tem cilindro de até 3,5 m e raio de tronco, entre
   0,1 e 1,0 (a gameleira é a exceção, declarada).
2. Toda árvore com ficha em `data/arvores_3d.json` que o catálogo conhece tem
   colisão.
3. As espécies de tronco do paisagismo repetem o raio e a altura do catálogo (ou
   da peça da ficha, a 0,3, quando só o paisagismo as planta, como o
   `cajueiro_leve`).

`--falsificar=copa` e `--falsificar=receita` reprovam o primeiro e o terceiro.

## O que fica em aberto

## A passada do corpo (08/10/2026, fecha a #150)

`tests/arvores_barram_o_corpo.gd` monta o vale e, com o conjunto de cilindros
acordado ao lado de um tronco de cada espécie, varre a cápsula do jogador (os mesmos
0,28 de raio) pelo eixo do tronco, ao nível do peito, dos dois lados:

- ela **para na borda do cilindro mais o corpo** (±0,12 u) e nunca entra na madeira;
  pedra, cerca ou vizinho que barre um lado não contam, e ao menos um lado tem de ser
  barrado por um cilindro de árvore;
- varrida **acima do cilindro**, onde só há folhagem, ela **passa**: nenhuma copa barra.

Mede umas vinte espécies por rodada, as que o conjunto acorda (as demais, como aroeira,
bambu e ingazeiro, ficam sem vaga por nascerem em moita; a
cobertura do conjunto é a pergunta 1 de `colisao_das_arvores`, e o conjunto muda com o
ponto do jogador). Paradas de 0,45 u (mamoeiro) a 0,94 u (mangueira) do eixo.
`--falsificar=copa` (cilindros até 9 m) e `--falsificar=sem_corpo` (cilindros fora da
camada de colisão) reprovam o portão.

Junto com `colisao_das_arvores` (eixo do corpo na madeira, inclusive palmeira
inclinada), `corte_das_arvores` (interação), `navegacao` e `rota_por_terra`
(a rota contorna o tronco, o morador não o atravessa) e a auditoria acima, os critérios
da #150 estão cobertos. As bases largas (mangue, bambu, sapopemas da gameleira) seguem
passando por cima dos cilindros por projeto: se isso incomodar no jogo aberto, o
caminho é cilindro maior só nelas, junto da reserva da malha de navegação, em issue
própria. A oclusão da câmera é da #126, e a posição das árvores e das bases no
terreno, da #141.
