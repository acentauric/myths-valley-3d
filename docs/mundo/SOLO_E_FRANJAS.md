# Solo e franjas: o chão do vale

O chão era uma textura só (grama, terra e folha numa imagem, tingida de oliva e repetida a cada
12 u): um carpete igual na praça, no pasto, na beira do rio e no alto do Mirante, com ruas,
praia e rios desfazendo-se sobre ele numa faixa de 0,4 u. Agora o chão tem camadas, e as
transições (rua, praça, praia, rio) se desfazem sobre um chão da mesma família.

## Como funciona

**Três regras misturam as oito camadas** no `terreno.gdshader` (a malha "Terra"):

1. o **mapa de solo** (`mapa_de_solo.gd`): terra, areia, lama, pasto e copa, uma imagem por
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
| folhiço | sob a copa de cada árvore (menos o coqueiral) | 3,5 u |
| terra batida varrida | ruas, praça, cruzamentos, trilhas de pé | 4 u |
| barro vermelho | declive; halo da rua em declive | 5 u |
| pedrisco | declive forte; topo do Mirante | 3 u |
| areia de restinga | 9 u de cada lado da costa | 5 u |
| lama de mangue | núcleo ao longo dos rios; a cauda só escurece | 4 u |

Contra a repetição, o shader gira e amplia a grama de 30 a 80 u da câmera, e um ruído de
brilho varia as manchas grandes em ±10 %. As derivadas do `xz` saem fora dos `if` e as camadas
usam `textureGrad`, senão aparece costura de mipmap.

### Mapa de solo

`mapa_de_solo.gd` (sem `class_name`, `preload` na região). Só primitivas em C++: as faixas viram
polígonos por `Geometry2D.offset_polyline`, os polígonos se pintam linha a linha com
`intersect_polyline_with_polygon` e `fill_rect`, a suavização é `shrink_x2` seguido de `resize`
cúbico (rampas de 2 a 4 u, que o shader ainda recorta com ruído). Tudo vai numa
`Texture2DArray`, um sampler só. Nada de laço por pixel em GDScript.

- **Camadas fixas**, em `geo_region_renderer._montar_mapa_de_solo()`, logo depois das ruas em
  curva: terra nas ruas (meia largura + 2,5 u), nos cruzamentos e na praça (×1,5); areia ao
  longo da costa; lama ao longo dos rios (núcleo 3,5 u, cauda de umidade 7 u); pasto na
  Fazenda (1,0) e na vila (0,35).
- **Vida**, em `pintar_vida()`, chamada de `world_builder._build_bases_das_arvores` quando as
  árvores e as casas já existem: a copa de cada árvore (mangue pela metade, coqueiro e dendê
  não cobrem) e as trilhas de pé da porta de cada casa até a rua mais perto (1,2 u).
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
  compila): oito vistas fixas (praça, Rua Principal, beira do rio norte, foz, praia do píer, Mirante
  olhando a vila, vila olhando o Mirante, lavoura). Erro de shader não derruba o jogo; procure
  `SHADER ERROR` na saída.

## Fora desta entrega

- Superfície própria por rua (Rua das Pedras em pedrisco).
- Regerar as prévias do editor (`terreno_editavel.tscn`, `ruas_referencia.tscn`): guardam cópias
  antigas dos shaders e só o editor as usa.
- A borda do mundo (degrau entre o terreno e o continente fora da moldura) é do pacote do céu.
