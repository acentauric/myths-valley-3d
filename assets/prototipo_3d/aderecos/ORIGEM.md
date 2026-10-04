# Adereços do arraial gerados no Tripo

<!-- lote-2026-09-26:inicio -->

## Lote em Malha Smart de 26/09/2026

Geradas por texto no Tripo Studio (Modelo HD H3.1, textura 8K desligada, 55
créditos) e passadas pela Retopologia (Quad, Malha Smart, 40 créditos) com o
alvo de polígonos da categoria; exportadas em GLB com a textura da tabela.
Retopologia e exportação em lote por `tools/tripo/lote_studio.js`;
cópia para o projeto por `sincronizar_downloads.py` (originais em
`.assets-raw/tripo/`, fora do Git). Tarefas, categorias e prompts completos em
`tools/tripo/lote_2026-09-26.json`. Estas versões substituem as
reduzidas por `reduzir_glb.py` e os HD anteriores descritos acima; os arquivos
antigos continuam no histórico do Git.

| Arquivo | O que é (prompt) | Tarefa Tripo | Triângulos | Textura | MB |
| --- | --- | --- | ---: | --- | ---: |
| `banco_tripo.glb` | Rustic wooden park bench with plank seat and backrest, weathered wood. | `f83875b5-8d2c-4592-958b-355758e45f17` | 4.016 | 1K | 2.1 |
| `candeeiro_tripo.glb` | Old kerosene lantern (candeeiro): small tin body, glass chimney, wire handle. | `cd4ed038-9a30-46d5-9f5b-809582a32351` | 3.864 | 1K | 2.6 |
| `carroca_tripo.glb` | Ox cart (carro de boi) from rural Brazil: two large solid wooden wheels, wooden yoke pole, plank cargo bed with side rails, no animals. | `bc1c9b43-0db2-4619-88ac-a5bfed38773a` | 4.115 | 1K | 2.6 |
| `cerca_tripo.glb` | Rustic wooden fence section: three rough posts and two horizontal rails, weathered wood, about four meters long. | `dede644a-6bd2-459d-b264-74d522459951` | 3.950 | 1K | 2.6 |
| `cruzeiro_tripo.glb` | Tall wooden cross (cruzeiro) on a stepped stone base, dark weathered wood with simple carved details. | `f73bad86-1c25-447c-bfec-fc6763bc7d24` | 4.609 | 1K | 2.5 |
| `fogueira_tripo.glb` | Small campfire: ring of gray stones and burning logs. The original 4,054-face Tripo model had 1,379 rigid flame triangles removed locally with `tools/prototipo_3d/remover_chama_fogueira.py`; the flame now comes from particles in `luzes_epoca.gd`. | `b87c7576-4c98-45dd-8460-edf72edfc32f` | 2.675 | 1K | 2.2 |
| `lampiao_poste_tripo.glb` | 19th-century street oil lamp on a wooden post: iron lantern with glass panes and a small metal roof, wooden post with an iron bracket. | `cba6e2fa-0f24-487b-88ac-1d466a35d919` | 3.971 | 1K | 2.6 |
| `lenha_tripo.glb` | Stack of split firewood logs neatly piled, bark outside and pale cut ends. | `bac80f06-04b6-4303-86d5-0b435c8bb637` | 3.997 | 1K | 1.9 |
| `mandioca_canteiro_tripo.glb` | Cassava plot: several cassava plants (manihot) with reddish stems and palmate leaves growing from a mound of dark earth. | `0f75f635-c5cc-43a4-955f-870824c70ec9` | 3.949 | 1K | 2.7 |
| `pedras_tripo.glb` | Cluster of mossy gray boulders of different sizes. | `3f483aaa-2572-4dac-b7f1-ef68b50f4d2c` | 3.816 | 1K | 2.5 |
| `pote_tripo.glb` | Large clay water pot (pote de barro) on a small stone base with a wooden lid and a tin cup hanging. | `9b2f3248-304f-485a-87c0-acb2016215c9` | 4.231 | 1K | 2.2 |
| `tumulo_tripo.glb` | Old cemetery grave: low rectangular stone tomb with a small wooden cross at the head, moss and cracks. | `7be03cb6-13e6-4f78-8514-776363faf8cf` | 4.320 | 1K | 2.6 |
| `varal_tripo.glb` | Clothesline between two wooden posts with a few hanging cotton cloths and a simple dress. | `08413815-e367-42dd-8732-def4f5629daf` | 4.122 | 1K | 2.7 |

Uso comercial: plano Max no momento da geração (ver `assets/CREDITOS.md`).

<!-- lote-2026-09-26:fim -->

## Canoa de pescador (27/09/2026)

Texto → 3D (Modelo HD, H3.1, 55 créditos) + Retopologia Malha Smart (quads, alvo 2.000,
40 créditos), exportada em GLB com textura 1K pelo script `tools/tripo/lote_studio.js`
na aba logada do Studio. Original em `.assets-raw/tripo/aderecos/canoa_tripo.glb`.

| Arquivo | O que é (prompt) | Projeto Tripo | Triângulos | Textura | MB |
| --- | --- | --- | ---: | --- | ---: |
| `canoa_tripo.glb` | Traditional Brazilian fishing canoe from the Reconcavo Baiano (canoa de pescador), long narrow carved wooden hull with pointed ends, weathered planks painted blue and white with a red stripe along the rim, two simple wooden thwart seats, a wooden paddle and a folded fishing net lying inside, empty boat, stylized hand-painted 3D game asset, 19th century Bahia, isolated object, no ground plane, no water, no text | `1823f0c6-b08c-4ff5-bac6-7d7294cf1992` | 3.864 | 1K | 2.6 |

Usada por `scripts/prototipo_3d/canoas.gd`: sete canoas fundeadas no raso diante da vila
(lâmina de 0,8 a 2,6 m), comprimento de 5,6 unidades, afundadas 0,32 para a quilha e o
leme ficarem na água. No estilo procedural, o mesmo script monta um casco próprio.


## Pedras e barcos do lugar (28/09/2026)

Mesmo fluxo do lote anterior (texto → 3D + Malha Smart via `__mv.gerar`); originais em
`.assets-raw/tripo/aderecos/`. Referências: fotos reais das pedras da praia de Bom
Jesus e dos barcos de passeio/pesca (cascos lisos, sem letreiro).

| Arquivo | O que é | Projeto Tripo | Triângulos | Textura |
| --- | --- | --- | ---: | --- |
| `pedras_praia_tripo.glb` | afloramento de arenito claro em camadas, com mato em cima | `1a536058-4b7a-4e42-92b2-48cd59a107d2` | 5.924 | 1K |
| `pedra_mare_tripo.glb` | laje escura de recife com algas, exposta na maré baixa | `6865c7a6-7776-4663-86a3-e6129bac00b0` | 4.865 | 1K |
| `bote_tripo.glb` | bote de pesca branco e azul com toldo de lona, sem letreiro | `726765df-3516-434a-8ea2-625c0a313c42` | 5.892 | 1K |
| `canoa_amarela_tripo.glb` | canoa amarela de casco vermelho por dentro, desgastada | `91fc17de-dacb-4338-b6c9-1603113d4e41` | 3.673 | 1K |
