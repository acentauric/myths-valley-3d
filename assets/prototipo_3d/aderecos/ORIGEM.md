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

<!-- lote-2026-10-03:inicio -->

## Lote de 03/10/2026: o terreiro e a gameleira (#52)

Os dois mastros com pano branco do terreiro e as fitas no tronco da gameleira, que
o 2D descreve e o vale esperava (`world_builder._build_marcos_de_fe`). Entram só
no estilo Tripo.

Geradas por texto no Tripo Studio em 03/10/2026 (Modelo HD H3.1, textura 8K
desligada, 55 créditos) e passadas pela Retopologia (Quad, Malha Smart, 40
créditos) com o alvo de faces de cada peça; exportadas em GLB com textura 1K.
Geração, retopologia e exportação pela ponte do Playwright MCP com a extensão do
Chrome, com `tools/tripo/lote_studio.js`; os originais ficam em
`.assets-raw/tripo/gerados/` (fora do Git). Tarefas, projetos, alvos e prompts
completos em `tools/tripo/lote_2026-10-03.json`. A conta Tripo exibia um plano
pago durante a geração; a [ajuda oficial sobre uso comercial](https://www.tripo3d.ai/help/privacy-policy/how-to-use-tripo-models-commercially)
concede direitos comerciais aos usuários de planos pagos — conferir as condições
vigentes antes de publicar.

| Arquivo | O que é (prompt) | Tarefa Tripo | Triângulos | Textura | MB |
| --- | --- | --- | ---: | --- | ---: |
| `mastro_pano_tripo.glb` | A tall thin wooden pole stuck in the ground with a long plain white cloth banner hanging from its top. | `8503a824-842e-492a-b6f8-f19806186055` | 2.648 | 1K | 2.0 |
| `fitas_gameleira_tripo.glb` | A wide white cloth sash wrapped in a ring and tied in a large bow, as if around a thick tree trunk but with the trunk removed, hollow cylindrical ring of fabric with colorful ribbons hanging down. | `3759ce96-e243-4d2a-88a1-0e2383a4a723` | 2.831 | 1K | 2.7 |

<!-- lote-2026-10-03:fim -->

<!-- lote-2026-10-03b:inicio -->

## O tronco caído do cemitério (03/10/2026)

O tronco que a trovoada derrubou entre as covas do cemitério do Damião, no lugar
da lenha empilhada: alvo do machado do `data/recursos_3d.json` (grupo
`mato_do_cemiterio`), que rende lenha.

Geradas por texto no Tripo Studio em 03/10/2026 (Modelo HD H3.1, textura 8K
desligada, 55 créditos) e passadas pela Retopologia (Quad, Malha Smart, 40
créditos) com o alvo de faces de cada peça; exportadas em GLB. Geração,
retopologia e exportação pela ponte do Playwright MCP com a extensão do Chrome,
com `tools/tripo/lote_studio.js`; os originais ficam em
`.assets-raw/tripo/gerados/` (fora do Git). Tarefas, projetos, alvos e prompts
completos em `tools/tripo/lote_2026-10-03b.json`. Uso comercial: plano pago no
momento da geração (ver `assets/CREDITOS.md`).

| Arquivo | O que é (prompt) | Tarefa Tripo | Triângulos | Textura | MB |
| --- | --- | --- | ---: | --- | ---: |
| `tronco_caido_tripo.glb` | A single fallen tree trunk lying horizontally on the ground, thick weathered log about four meters long with rough cracked bark, a few short broken branch stubs, patches of moss and dry lichen, one end jagged where it snapped. | `a9f373e0-ee82-4659-a828-a6066ae7ad87` | 4.118 | 1K | 2,5 |

<!-- lote-2026-10-03b:fim -->

<!-- lote-2026-10-05:inicio -->

## O saveiro do mestre Quirino (05/10/2026)

Gerado por texto no Tripo Studio em 05/10/2026 (Modelo HD H3.1, textura 8K
desligada, 55 créditos) e passado pela Retopologia (Quad, Malha Smart, 40
créditos) com alvo de 6.000 faces; exportado em GLB com textura 2K, como as
construções de destaque: é o barco em que o jogador chega ao vale, e a primeira
coisa que ele vê de perto. Geração, retopologia e exportação pela ponte do
Playwright MCP com a extensão do Chrome, com `tools/tripo/lote_studio.js`; o
original fica em `.assets-raw/tripo/gerados/` (fora do Git). Tarefa, projeto e
prompt completos em `tools/tripo/lote_2026-10-05.json`. Uso comercial: plano
pago no momento da geração (ver `assets/CREDITOS.md`).

| Arquivo | O que é (prompt) | Tarefa Tripo | Triângulos | Textura | MB |
| --- | --- | --- | ---: | --- | ---: |
| `saveiro_tripo.glb` | A traditional Brazilian saveiro, a wooden cargo sailboat from the Reconcavo Baiano in Bahia, about twelve meters long, seen from the side: broad round-bellied wooden hull painted dark blue with a white and red stripe along the gunwale, a wide flat open wooden deck with low rails, one tall wooden mast slightly leaning forward carrying a large raised tan canvas sail, a quadrilateral lug sail with a wooden gaff and boom, a long wooden tiller at the stern, a few burlap sacks and stacked clay roof tiles near the bow, leaving most of the deck clear. | `6d24dbc5-9fbf-458d-8a23-7bf3f7395985` | 10.862 | 2K | 8,3 |

SHA-256 do GLB: `af094d331a0f66c5c09852c3434a7d98a41f54c3d3ef0813f202d9f7c0d7b5da`.

<!-- lote-2026-10-05:fim -->

<!-- lote-2026-10-05_level_design:inicio -->

## Level design de 05/10/2026: os varais e o que falta aos quintais

Gerados por texto no Tripo Studio em 05/10/2026 (Modelo HD H3.1, textura 8K
desligada, 55 créditos) e passados pela Retopologia (Quad, Malha Smart, 40
créditos) com alvo de 1.200 a 2.500 faces. Os que têm rig passaram pelo
pre_rig_check e pelo rig do Studio (20 créditos): Mixamo para gente e o do
tipo do bicho para os outros (quadrúpede, ave, aquático, serpente), com as
animações prontas do Studio aplicadas uma de cada vez e exportadas juntas no
GLB. Tudo pela ponte do Playwright MCP com a extensão do Chrome, com
`tools/tripo/lote_studio.js` e `tools/tripo/lote_producao.js`.
Cópia para o projeto por `sincronizar_downloads.py` (originais em
`.assets-raw/tripo/`, fora do Git). Tarefas, projetos e prompts completos em
`tools/tripo/lote_2026-10-05_level_design.json`. Uso comercial: plano pago no
momento da geração (ver `assets/CREDITOS.md`).

| Arquivo | O que é (prompt) | Tarefa Tripo | Triângulos | Textura | Rig | MB |
| --- | --- | --- | ---: | --- | --- | ---: |
| `chiqueiro_tripo.glb` | A small rustic pig pen with a low fence of wooden stakes and a small thatched shelter. | `186b3935-cc92-4237-a73a-ad7dbdfd49d7` | 5.305 | 1K | — | 2,9 |
| `cocho_tripo.glb` | A long rustic wooden feeding trough carved from a log. | `a0db09f3-cea0-45db-9c37-58043d89f9e5` | 2.273 | 1K | — | 1,9 |
| `galinheiro_tripo.glb` | A small rustic chicken coop made of woven sticks and wattle with a thatched roof and a little ramp. | `80f365e6-8d2c-4a97-a275-707a686b974d` | 5.455 | 1K | — | 3,1 |
| `varal_bambu_tripo.glb` | A rural clothesline made of two bamboo poles and a rope with white and colorful clothes and a sheet hanging to dry. | `d5365e5c-836a-40f8-9ef7-9d0964017eff` | 2.963 | 1K | — | 2,7 |
| `varal_estacas_tripo.glb` | A rural clothesline with three wooden forked stakes and a long rope with shirts, a skirt and towels hanging to dry. | `0bcb19d4-d3ae-459c-a451-0f3f0b89df6d` | 2.942 | 1K | — | 2,8 |

SHA-256 de cada GLB no arquivo do lote (`sha256`).

<!-- lote-2026-10-05_level_design:fim -->

<!-- lote-2026-10-05_moradores:inicio -->

## Moradores de 05/10/2026: ofícios e casas a mais: os varais e o que falta aos quintais

Gerados por texto no Tripo Studio em 05/10/2026 (Modelo HD H3.1, textura 8K
desligada, 55 créditos) e passados pela Retopologia (Quad, Malha Smart, 40
créditos) com alvo de 1.500 a 2.500 faces. Os que têm rig passaram pelo
pre_rig_check e pelo rig do Studio (20 créditos): Mixamo para gente e o do
tipo do bicho para os outros (quadrúpede, ave, aquático, serpente), com as
animações prontas do Studio aplicadas uma de cada vez e exportadas juntas no
GLB. Tudo pela ponte do Playwright MCP com a extensão do Chrome, com
`tools/tripo/lote_studio.js` e `tools/tripo/lote_producao.js`.
Cópia para o projeto por `sincronizar_downloads.py` (originais em
`.assets-raw/tripo/`, fora do Git). Tarefas, projetos e prompts completos em
`tools/tripo/lote_2026-10-05_moradores.json`. Uso comercial: plano pago no
momento da geração (ver `assets/CREDITOS.md`).

| Arquivo | O que é (prompt) | Tarefa Tripo | Triângulos | Textura | Rig | MB |
| --- | --- | --- | ---: | --- | --- | ---: |
| `canoa_em_obra_tripo.glb` | A dugout canoe under construction resting on two wooden trestles, half-carved log with adze marks, wood shavings and a few carpenter tools beside it. | `72b99cda-2b82-4d84-8339-08d06d6061a4` | 4.837 | 1K | — | 2,3 |
| `lavadouro_pedra_tripo.glb` | A large flat grey riverbank washing stone (pedra de lavar roupa) slightly tilted, worn smooth, with a wet folded white cloth and a small wooden soap box on it. | `72936a22-20c4-4790-8baa-cee578857a1e` | 3.004 | 1K | — | 1,6 |

SHA-256 de cada GLB no arquivo do lote (`sha256`).

<!-- lote-2026-10-05_moradores:fim -->

<!-- lote-2026-10-05_paisagismo:inicio -->

## Paisagismo de 05/10/2026, segunda leva: os varais e o que falta aos quintais

Gerados por texto no Tripo Studio em 05/10/2026 (Modelo HD H3.1, textura 8K
desligada, 55 créditos) e passados pela Retopologia (Quad, Malha Smart, 40
créditos) com alvo de 1.200 a 3.000 faces. Os que têm rig passaram pelo
pre_rig_check e pelo rig do Studio (20 créditos): Mixamo para gente e o do
tipo do bicho para os outros (quadrúpede, ave, aquático, serpente), com as
animações prontas do Studio aplicadas uma de cada vez e exportadas juntas no
GLB. Tudo pela ponte do Playwright MCP com a extensão do Chrome, com
`tools/tripo/lote_studio.js` e `tools/tripo/lote_producao.js`.
Cópia para o projeto por `sincronizar_downloads.py` (originais em
`.assets-raw/tripo/`, fora do Git). Tarefas, projetos e prompts completos em
`tools/tripo/lote_2026-10-05_paisagismo.json`. Uso comercial: plano pago no
momento da geração (ver `assets/CREDITOS.md`).

| Arquivo | O que é (prompt) | Tarefa Tripo | Triângulos | Textura | Rig | MB |
| --- | --- | --- | ---: | --- | --- | ---: |
| `barraca_feira_tripo.glb` | A small rustic market stall (barraca de feira) with a wooden table, a cloth awning on four poles, baskets of fruit, cassava and dried fish on the table. | `3a0cb715-dbe7-4868-ac47-47018ebbfa8a` | 6.114 | 1K | — | 2,8 |
| `carro_de_boi_tripo.glb` | A traditional Brazilian ox cart (carro de boi) with two big solid wooden disc wheels, a long wooden shaft and a flat wooden bed with side stakes, no animals. | `3c987ae9-d1bb-4383-9052-4bdaf6338300` | 5.503 | 1K | — | 2,8 |
| `cerca_varas_tripo.glb` | A straight section of rustic rural fence made of thin crooked wooden sticks and poles tied with vines, about three meters long. | `36625c9a-663c-47c2-93d5-24200a94a5a3` | 2.029 | 1K | — | 2,7 |
| `estaleiro_fumo_tripo.glb` | A wooden rack for drying tobacco leaves (estaleiro de fumo): a frame of poles with rows of large brown and golden tobacco leaves hanging to dry, under a simple thatched roof. | `47b60ab1-00dd-46bc-b880-ca87e6edac64` | 5.180 | 1K | — | 2,9 |
| `forno_barro_tripo.glb` | An outdoor dome-shaped clay bread oven (forno de barro) on a low base of stones and clay, with a small arched opening and some firewood beside it. | `dc5d63b9-f651-4bb1-8032-84acec9f0036` | 3.874 | 1K | — | 2,2 |
| `monjolo_tripo.glb` | A Brazilian monjolo, a water-powered wooden pounding machine: a long wooden beam pivoting on a frame, a trough at one end and a heavy pestle at the other end above a wooden mortar, under a small thatched roof. | `a0a416c3-f45b-436a-8180-6666f6cf1f7e` | 6.074 | 1K | — | 2,8 |
| `penedo_lapa_tripo.glb` | A large weathered granite rock outcrop (penedo) of the Atlantic forest with a shallow cave opening (lapa) at its base, moss and ferns in the cracks, roots of fig trees gripping the rock, dark shadowed hollow, about six meters tall. | `0f4b80a9-d61f-4163-a0cf-5817a66bedaa` | 5.411 | 1K | — | 2,4 |
| `porteira_tripo.glb` | A rustic wooden farm gate (porteira) with diagonal brace, hung between two thick rough wooden posts. | `47578c14-3021-4350-bf8b-1a94d9dcb1fc` | 2.952 | 1K | — | 2,5 |
| `sacos_farinha_tripo.glb` | A small pile of four burlap sacks full of manioc flour (farinha), tied at the top, stacked against each other. | `a3a60ee3-7ce1-4cf7-9e5b-239ba4ba8528` | 2.899 | 1K | — | 2,3 |

SHA-256 de cada GLB no arquivo do lote (`sha256`).

<!-- lote-2026-10-05_paisagismo:fim -->
