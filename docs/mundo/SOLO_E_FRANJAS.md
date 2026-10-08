# Solo e franjas: o chão do vale

O chão era uma textura só (grama, terra e folha numa imagem, tingida de oliva e repetida a cada
12 u): um carpete igual na praça, no pasto, na beira do rio e no alto do Mirante, com ruas,
praia e rios desfazendo-se sobre ele numa faixa de 0,4 u. Agora o chão tem camadas, e as
transições (rua, praça, praia, rio) se desfazem sobre um chão da mesma família.

## Como funciona

**Três regras misturam as oito camadas** no `terreno.gdshader` (a malha "Terra"):

1. o **mapa de solo** (`mapa_de_solo.gd`): terra, areia, lama, pasto, copa e trilha, uma imagem por
   camada, 1 pixel por unidade, sobre o retângulo da terra;
2. o **declive** (normal suave da malha): barro vermelho no barranco (11° a 20°), pedrisco na
   encosta forte e no topo do Mirante (acima de 38 u);
3. o **ruído** grande, que quebra a repetição e desloca cada limiar.

As camadas se misturam pela **altura guardada no alfa** de cada textura: na borda, o tufo sobe
por cima da terra e a pedra por cima da lama, em vez de um degradê de duas imagens.

| camada | onde | ladrilho |
|---|---|---|
| grama baixa | base | 4 u |
| capim seco | pasto (Fazenda inteira, a vila ralo), em manchas | 5 u |
| folhiço | sob a copa de cada árvore (menos o coqueiral; o dendezal, mais ralo) | 3,5 u |
| terra batida varrida | ruas, praça, cruzamentos, trilhas de pé | 4 u |
| barro vermelho | declive; halo da rua em declive | 5 u |
| pedrisco | declive forte; topo do Mirante | 3 u |
| areia de restinga | 9 u de cada lado da costa | 5 u |
| lama de mangue | núcleo ao longo dos rios; a cauda só escurece | 4 u |

Contra a repetição, o shader gira e amplia a grama de 30 a 80 u da câmera, e um ruído de
brilho varia as manchas grandes em ±10 %. As derivadas do `xz` saem fora dos `if` e as camadas
usam `textureGrad`, senão aparece costura de mipmap.

### Regra do chão: nenhuma quina reta (#197)

**Nenhuma transição do chão em ângulo reto**, exceto onde a forma é humana e reta de propósito:
piso de casa, calçada da igreja, canteiro, cerca. Essas exceções **não estão no mapa de solo**:
são malhas e decalques próprios, assentados por cima do chão, e por isso nunca são amolecidas. Tudo
que o mapa pinta (terra, areia, lama, pasto, copa) tem fronteira orgânica:

- **Pintura subamostrada.** A imagem crua tem 2 x 2 subamostras por pixel (`ESCALA`); a primeira
  redução é a média delas, e a fronteira cai entre pixels em vez de em escada de 1 pixel.
- **Rampa de ~4 u em tudo que é largo** (terra de rua e praça, areia, lama, pasto, copa:
  `SUAVIZACAO = 2`). A rua deixou de ter rampa menor que as outras.
- **Trilha à parte.** Traço de ~2 u (trilha de pé, pé de árvore, terreiro) vira a camada
  `TRILHA`, de rampa de 2 u, senão se diluiria na rampa de 4 u. `peso(TERRA)` devolve o maior
  de `TERRA` e `TRILHA`, então o passo e os portões leem uma terra só.
- **Manchas redondas e irregulares.** A copa de cada árvore é uma elipse de mesma área que o
  quadrado de antes, com os semi-eixos sorteados pela posição (0,88 a 1,12), nunca um quadrado
  esperando a suavização.
- **Desvio de borda no shader** (`desvio_borda`, 1,4 u): o ponto lido no mapa é empurrado por dois
  ruídos de manchas de ~6 u, e toda fronteira serpenteia.
- **Hash sem seno (a causa dos retângulos de borda reta).** O ruído do shader (`hash21`, em
  `solo.gdshaderinc`, no `areia_praia` e no `leito_rio`) usava `fract(sin(dot(p, k)) * 43758)`.
  Esse produto amplifica o erro de arredondamento da GPU: o mesmo canto de célula, lido de duas
  células vizinhas, dava dois valores, e longe da origem do vale (x ou z de algumas centenas de
  u) cada célula do ruído virava um retângulo de borda reta e canto vivo, na areia, na grama e no
  recorte da praia. Foi isso (e não o mapa, que a suavização já tinha deixado liso, nem o ruído em si) que
  mantinha os degraus pequenos na areia, na rua e na foz depois da suavização. O hash agora é `fract` de multiplicações e somas
  (a de Hoskins, sem seno). O portão gráfico `validar_franja_da_areia.gd` pede o mesmo canto de
  duas maneiras a 300 u da origem: com o hash novo diferem ~0,2% dos pixels (o `floor`), com o de
  seno ~75% (`-- --hash-antigo` reprova).
- **Desvio largo para as camadas largas** (`desvio_borda_larga`, 2,0 u): areia, lama, pasto e copa
  leem o mapa com um desvio maior (ruído de ~5 u), porque a areia da costa vem de retas do KML e,
  só com o desvio curto, ficava reta por 5 a 7 u seguidos. Terra e trilha, estreitas, ficam com os
  1,4 u, para o traço não se partir.
- **Areia da foz.** A faixa de areia em volta do traçado do rio (`mouth_sand_*`) tinha rampa de
  0,75 u e distância reta de vértice a vértice: acabava em retas. Agora é cheia até 3,4 u, some
  até 6,6 u e a distância leva um ruído de 1,3 u (#138).
- **Prioridade.** A areia esconde o pasto pelo peso inteiro (`w_capim *= 1 - w_areia`), como já
  fazia com o folhiço e o barro.

Sobre o custo: o mapa segue em primitivas de C++; a pintura faz o dobro de linhas e as copas, uma
faixa por pixel de altura da mancha em vez de um retângulo, sem laço por pixel. Medido (headless,
`_montar_mapa_de_solo` mais `pintar_vida` com 3.938 árvores, quatro rodadas): a montagem foi de
~240 para ~400 ms e a pintura da vida de ~50 para ~70 ms, uns 180 ms a mais numa carga do vale de
dezenas de segundos. No quadro, o chão lê as mesmas camadas e os mesmos amostradores: o desvio
largo soma quatro leituras de ruído por fragmento de chão.

O portão `tests/mapa_de_solo.gd` mede o maior salto entre pixels vizinhos de cada camada suave
(`degrau_maximo`: 1,0 é corte seco, ~0,3 é rampa de 4 u) e reprova acima de 0,6 (0,85 na trilha);
a régua é provada antes num quadrado sem suavização, e `-- --falsificar-quinas` publica o mapa
sem suavização para ver o portão reprovar.

### Mapa de solo

`mapa_de_solo.gd` (sem `class_name`, `preload` na região). Só primitivas em C++: as faixas viram
polígonos por `Geometry2D.offset_polyline`, os polígonos se pintam linha a linha com
`intersect_polyline_with_polygon` e `fill_rect`, a suavização é `shrink_x2` seguido de `resize`
cúbico (rampas de 2 a 4 u, que o shader ainda recorta com ruído e desvia). Tudo vai numa
`Texture2DArray`, um sampler só. Nada de laço por pixel em GDScript.

- **Camadas fixas**, em `geo_region_renderer._montar_mapa_de_solo()`, logo depois das ruas em
  curva: terra nas ruas (meia largura + 2,5 u), nos cruzamentos e na praça (×1,5); areia ao
  longo da costa; lama ao longo dos rios (núcleo 3,5 u, cauda de umidade 7 u); pasto na
  Fazenda (1,0) e na vila (0,35).
- **Vida**, em `pintar_vida()`, chamada de `world_builder._build_bases_das_arvores` quando as
  árvores e as casas já existem: a copa de cada árvore (mangue pela metade; o dendê, em mancha larga de 3,5 a 6,5 u com
  peso 0,7, para a grama aparecer na borda; o coqueiro não cobre) e as trilhas de pé da porta de cada casa até a rua mais perto (1,2 u).
- Sai sempre do KML, da composição e das casas do momento: mudou o mapa, o chão acompanha.

### Copa ao longe

O morro não fica mais pelado. Onde a mata sumiu por LOD, a copa vira chão pintado de
verde-mata, em manchas de 6 a 12 u: de `LOD_MATA - 80` a `LOD_MATA - 30` ela já cobre, e o chão
sob ela se ergue até 3 u a partir de `LOD_MATA - 60`, só na câmera em perspectiva (mapa,
minimapa e sombra do sol veem o chão de verdade). As distâncias saem da constante `LOD_MATA` do
renderizador, então acompanham se o LOD mudar. Os decalques de pé de árvore ficaram só nas árvores
nomeadas e nas da areia: o das ~6 mil da mata agora é o folhiço do chão (os decalques, sem LOD,
viravam pontos escuros cintilando no morro).

### Normais suaves

`_add_polygon` indexa a malha e chama `generate_normals()`: uma normal por vértice, a média das
faces em volta. Com uma por face a luz facetava o morro e a camada do declive desenhava os
triângulos. Colisão e navegação não mudam (os triângulos são os mesmos).

## Franjas

- **Ruas:** o acostamento passou de 1,15 para 2,5 u de cada lado. `estrada_acostamento.gdshader`
  desenha só a estrada, com alfa esfarelado em duas escalas (a receita da `areia_praia`, no
  `solo.gdshaderinc`) e `ALPHA_ANTIALIASING_EDGE`. Por baixo aparece a terra batida do mapa:
  sulco, terra, grama em tufos.
- **Cruzamentos:** `cruzamento.gdshader`, terra batida sem direção (duas amostras giradas), a
  mesma tinta da estrada, borda esfarelada.
- **Praça:** a sobreposição de aresta reta saiu; é terra do mapa de solo, de borda ruidosa. As
  sobreposições "Cobertura florestal", "Área ocupada", "Mata" e "Fazenda" também saíram: tinham
  o mesmo material do chão e não mudavam nada na tela.
- **Praia:** com restinga embaixo, a franja da areia voltou de 0,10 para 0,25.
- **Rios:** `leito_rio.gdshader` ganhou `lama` e `mistura_lama` (padrão 0,0: o visual de antes, que
  a cena da orla usa). Os rios do mapa usam 1,0: margens em lama, calha em areia de rio mais escura,
  franja de 0,35.
- **Terreiros:** `terreiro_casa.tscn` usa `terreiro_varrido_v1.png` (terra batida com máscara oval
  irregular, sem sulco de carro de boi); o terreiro por polígono (`_terreiro_material`) usa a mesma
  terra, ladrilho e tinta do shader.
- **Lavoura:** `lavoura_vale` usa materiais compartilhados, um por tinta. O leito arado (seco e
  molhado) é `terra_arada_v1` pelo UV do leito (os sulcos giram com o campo), com a tinta de cada
  estado dividida pela média da textura; o leito tem relevo — três camalhões —, e os sulcos da
  imagem caem em cima dos sulcos da malha (`SULCO_DA_IMAGEM`, `PRIMEIRO_SULCO`). O leito bruto e a
  terra batida do campo, por baixo dos leitos e até o cercado rasteiro, são
  `terra_batida_varrida_v1` no ladrilho do chão do vale (4 u, pelo chão do mundo).
- **Passos:** `surface_at` consulta o mapa depois das regras antigas: lama (> 0,6), areia (> 0,5),
  terra (> 0,5). A rua continua "terra" antes de tudo, como o portão `mapa_fluxo` espera.

## Texturas

Nove, do OpenAI (`gpt-image-2`, 1024x1024, `high`), preparadas por
`tools/materiais/preparar_textura_chao.py` (achata a baixa frequência, torna contínua, grava a
altura no alfa, gera prévia 3x3). Os prompts estão em `tools/openai/texturas_chao.json`; a
geração é paga e só roda com pedido explícito (`tools/openai/gerar-texturas-chao.ps1 -Estimar`
mostra o custo). Origem em `assets/prototipo_3d/materiais/ORIGEM.md` e `assets/CREDITOS.md`. As
texturas antigas ficam: a cena da orla (`paisagem_referencia.tscn`) aponta para elas.

Tintas: cada camada tem uma tinta (em `CAMADAS_DO_CHAO`, `geo_region_renderer.gd`) que acerta a
média medida da textura com a paleta da AMBIENTACAO §7. O script imprime as médias.

## Conferir

- `tests/mapa_de_solo.gd`: terra na praça, na rua e nas trilhas; areia na costa; lama nas margens;
  pasto na Fazenda; copa sob a mata; normais para cima e suaves; shader ligado ao mapa; `surface_at`.
  `-- --falsificar-solo` zera o mapa e o portão tem de reprovar.
- `tools/prototipo_3d/fotografar_chao.gd` (precisa de janela: com `--headless` nenhum shader
  compila): doze vistas fixas (praça, Rua Principal, beira do rio norte, foz, foz de cima, costa de cima,
  dendezal, dendezal de cima, praia do píer, Mirante olhando a vila, vila olhando o Mirante,
  lavoura). `--hora=` e `--estacao=0..3` mudam a luz e a estação (e a maré acompanha a hora:
  preamar às 7 h, baixa-mar perto das 13 h); `--esconder=Foz_do_rio,Rio` (`_` vale espaço, `nome*`
  é prefixo, `~trecho` é substring) esconde malhas para descobrir de quem é uma emenda; `--fps=300`
  mede o tempo de quadro de cada vista com o vsync desligado. Erro de shader não derruba o jogo; procure
  `SHADER ERROR` na saída.

## Fora desta entrega

- Superfície própria por rua (Rua das Pedras em pedrisco).
- Regerar as prévias do editor (`terreno_editavel.tscn`, `ruas_referencia.tscn`): guardam cópias
  antigas dos shaders e só o editor as usa.
- A borda do mundo (degrau entre o terreno e o continente fora da moldura) é do pacote do céu.
