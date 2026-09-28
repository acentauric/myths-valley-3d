# Pau-brasil do protótipo 3D

`pau_brasil_tripo.glb` foi gerado no Tripo Studio em 24/09/2026 a partir de uma imagem criada no Codex com a ferramenta embutida `image_gen`. A referência final, com fundo transparente, está em `.assets-raw/tripo/referencias/pau-brasil-transparente.png`; a primeira versão da referência e as duas exportações do Tripo permanecem em `.assets-raw/tripo/` para comparação local.

- Projeto Tripo escolhido: https://studio.tripo3d.ai/pt/workspace/generate/d04b2e82-3526-445d-bb3e-5c766459e8a6
- Exportação: GLB, textura 2K, malha triangular com 74.017 faces, 56.571 vértices, três imagens incorporadas e um material PBR.
- Tamanho: 6.883.984 bytes.
- SHA-256: `A4BD5FB7A60A12870AC38146785A02B80952643AC98EDC65C9071CEBE926C1E8`.
- A conta Tripo exibiu o plano Max durante a geração. A [ajuda oficial sobre uso comercial](https://www.tripo3d.ai/help/privacy-policy/how-to-use-tripo-models-commercially) concede direitos comerciais aos usuários de planos pagos. Conferir as condições vigentes antes da publicação do jogo.

Prompt da imagem inicial:

```text
Use case: stylized-concept
Asset type: single-view reference image for image-to-3D generation of a game tree asset
Primary request: one mature pau-brasil tree (Paubrasilia echinata), native to Brazil's Atlantic Forest, botanically plausible and suitable for a 3D game prop
Scene/backdrop: plain warm light-gray studio background with a soft contact shadow; no terrain, sky, other plants, props, people, labels or frame
Subject: entire tree visible from roots/base to top of crown, one sturdy mostly upright trunk branching naturally into a broad but airy irregular crown, dense clusters of small green bipinnate leaflets, dark brown rough mottled bark with a few natural reddish exposed patches, subtle short prickles on young branches; no exaggerated red trunk and no giant individual leaves
Style/medium: clean high-quality realistic game asset concept render, physically plausible materials and crisp silhouette, three-quarter eye-level view
Composition/framing: tree centered, full crown and base contained with generous empty margin on all sides, single isolated object, no cropping, no occlusion
Lighting/mood: soft even studio lighting with details visible under the canopy
Constraints: one tree only, recognizable leaf structure, trunk and limbs clearly connected, clear separation from background for 3D reconstruction, no text, no watermark
```

Prompt da edição da imagem usada nesta exportação:

```text
Use case: background-extraction
Asset type: clean image-to-3D reference for a game tree
Primary request: remove every part of the gray studio background and ground shadow from the supplied image, leaving only the single pau-brasil tree on a genuinely transparent alpha background
Input images: Image 1 is the edit target
Subject: preserve the same complete pau-brasil tree exactly, including its small bipinnate green foliage, branches, dark textured bark with reddish areas, trunk and visible root flare
Composition/framing: same angle, shape, scale, tree position and full uncropped silhouette, clear margins on all sides
Constraints: change only background pixels and edge cleanup; preserve fine leaf detail and all tree colors and structure; no gray halo, no new plants, no labels, no text, no watermark; output actual transparent pixels around and between branches
```

A cena instancia esse GLB uma vez, no lugar da árvore procedural em `(-12, 0, 3)`, normaliza sua altura visual para 5,6 m e usa uma colisão cilíndrica simples para o tronco.

## Árvores do Recôncavo geradas em 26/09/2026

Quatro espécies foram geradas por texto no Tripo Studio (modelo H3.1, Máx.
qualidade, textura 2K, GLB), a partir de prompts que descrevem a espécie
botânica como adereço estilizado de jogo, sem chão e sem texto. A conta exibia o
plano Max; os direitos comerciais seguem a mesma condição do pau-brasil.

| Arquivo | Espécie | Tarefa Tripo | Original | Reduzido |
| --- | --- | --- | --- | --- |
| `mangueira_tripo.glb` | Mangueira (*Mangifera indica*) | `ffa9a27a-ecc8-4d01-87ec-cdb90401b75e` | 1.929.086 tri | 153.263 tri |
| `jaqueira_tripo.glb` | Jaqueira (*Artocarpus heterophyllus*) | `89a0cd4a-ec5b-4628-bda2-99283599c3de` | 1.971.524 tri | 152.666 tri |
| `cajueiro_tripo.glb` | Cajueiro (*Anacardium occidentale*) | `6a771473-e893-43ba-bc3a-a0bc25175085` | 1.930.146 tri | 145.452 tri |
| `coqueiro_tripo.glb` | Coqueiro (*Cocos nucifera*) | `c08918f6-9cb0-4dcd-a82f-a431911d71eb` | 1.905.930 tri | 108.448 tri |

Os GLBs originais (~60 MB cada) ficam em `.assets-raw/tripo/arvores/`, fora do
Git. A redução usa `prototipo_3d/tools/modelos/reduzir_glb.py` (agrupamento de
vértices em grade, preservando UVs e as texturas embutidas). `world_builder.gd`
instancia esses modelos nas árvores nomeadas perto dos pontos de interesse
(`_arvore`), normalizando a altura visual em `TRIPO_ARVORES_MEDIDAS`; a mata
fechada e os coqueiros da orla continuam procedurais (`flora_reconcavo.gd`),
porque centenas de instâncias desses modelos pesariam demais.

## Mangueira em Malha Smart (retopologia do Tripo)

`mangueira_tripo_smart.glb` é a mesma mangueira (`ffa9a27a-…`) passada pela
Retopologia do Tripo Studio em 26/09/2026: topologia Quad, Malha Smart P1.0,
alvo de 10.000 polígonos, 40 créditos. Resultado: 11.384 quads (20.453
triângulos), texturas 2K rebakeadas pelo Tripo, 12,7 MB. Comparação no jogo
(tecla C, bancada ao sul da Praça): procedural 560 tri, HD + `reduzir_glb.py`
144.564 tri, Malha Smart 20.453 tri — a Malha Smart ficou visualmente mais limpa
que a redução por agrupamento de vértices.

A primeira versão de `reduzir_glb.py` abria costuras de UV (trincas brancas na
capela). A correção faz a posição depender só da célula espacial e usa UV média
numa grade de 1/256; todos os modelos foram reprocessados.

<!-- lote-2026-09-26:inicio -->

## Lote em Malha Smart de 26/09/2026

Geradas por texto no Tripo Studio (Modelo HD H3.1, textura 8K desligada, 55
créditos) e passadas pela Retopologia (Quad, Malha Smart, 40 créditos) com o
alvo de polígonos da categoria; exportadas em GLB com a textura da tabela.
Retopologia e exportação em lote por `prototipo_3d/tools/tripo/lote_studio.js`;
cópia para o projeto por `sincronizar_downloads.py` (originais em
`.assets-raw/tripo/`, fora do Git). Tarefas, categorias e prompts completos em
`prototipo_3d/tools/tripo/lote_2026-09-26.json`. Estas versões substituem as
reduzidas por `reduzir_glb.py` e os HD anteriores descritos acima; os arquivos
antigos continuam no histórico do Git.

| Arquivo | O que é (prompt) | Tarefa Tripo | Triângulos | Textura | MB |
| --- | --- | --- | ---: | --- | ---: |
| `bananeira_tripo.glb` | Banana plant clump: several pseudostems, wide torn banana leaves arching outward, one hanging bunch of green bananas with a purple flower. | `b062ca2e-e598-4883-ba78-92328527fdf7` | 14.753 | 2K | 8.0 |
| `cajueiro_tripo.glb` | One cashew tree (Anacardium occidentale) as a stylized game prop: low crooked twisted brown trunk leaning to one side, wide spreading light-green canopy, a few red and yellow cashew apples with nuts hanging, isolated single tree, clean silhouette, no ground plane, no text. | `6a771473-e893-43ba-bc3a-a0bc25175085` | 15.420 | 2K | 11.5 |
| `capim_tripo.glb` | Tuft of tall dry sape grass with golden-green blades. | `bc7e5cde-6299-4675-b557-4531be8b4cb3` | 2.907 | 1K | 2.8 |
| `coqueiro_tripo.glb` | One tall coconut palm tree (Cocos nucifera) as a stylized game prop: slender slightly curved gray-brown ringed trunk, crown of long arching green fronds, a cluster of green coconuts under the crown, isolated single tree, clean silhouette, no ground plane, no text. | `c08918f6-9cb0-4dcd-a82f-a431911d71eb` | 17.566 | 2K | 10.6 |
| `dende_tripo.glb` | Dende oil palm tree (Elaeis guineensis): thick trunk covered in old leaf bases, dense crown of long arching fronds, clusters of red-orange oil palm fruit under the crown. | `10cb8089-bebd-4567-bcdd-377e50fac1e9` | 15.014 | 2K | 9.8 |
| `embauba_tripo.glb` | Embauba tree (Cecropia): tall slender pale gray ringed trunk, sparse umbrella of large palmate leaves at the top with silvery undersides. | `0f288055-a1b9-48c3-b807-f251d2955282` | 2.963 | 1K | 2.7 |
| `ipe_amarelo_tripo.glb` | Yellow ipe tree (Handroanthus) in full bloom: bare gray branches completely covered with bright yellow trumpet flowers, no leaves, medium straight trunk. | `1ebd9705-e61e-4bdc-bba7-0e0bb087b63d` | 15.148 | 2K | 11.2 |
| `ipe_roxo_tripo.glb` | Purple ipe tree in full bloom: bare gray branches completely covered with pink-purple trumpet flowers, no leaves, medium straight trunk. | `b3e68bf4-dcb7-4239-8817-3db37ef03efe` | 15.418 | 2K | 10.8 |
| `jaqueira_tripo.glb` | One jackfruit tree (Artocarpus heterophyllus) as a stylized game prop: straight tall brown trunk, dense rounded dark-green canopy of glossy leaves, several large bumpy yellow-green jackfruits hanging directly from the trunk, isolated single tree, clean silhouette, no ground plane, no text. | `89a0cd4a-ec5b-4628-bda2-99283599c3de` | 14.680 | 2K | 11.6 |
| `mangueira_tripo.glb` | One mature mango tree (Mangifera indica) as a stylized game prop: short thick dark-brown trunk, very wide dense dark-green rounded canopy casting deep shade, a few small yellow-green mangoes hanging, exposed root flare, isolated single tree, clean silhouette, no ground plane, no text. | `ffa9a27a-ecc8-4d01-87ec-cdb90401b75e` | 20.453 | 2K | 12.7 |
| `mata_a_tripo.glb` | Tall Atlantic rainforest tree: straight tall trunk with buttress roots, layered dark green dense canopy high up, a few lianas and bromeliads on the branches. | `3cbd2885-3187-4c56-a26a-eeda914a728b` | 2.489 | 1K | 2.9 |
| `mata_b_tripo.glb` | Broad tropical hardwood tree: sturdy trunk, wide rounded dense green canopy made of layered leaf clusters, small buttress roots. | `95c933e8-c1ed-4f7f-b61c-54ab9f211ae6` | 2.436 | 1K | 3.2 |
| `moita_tripo.glb` | Tropical flowering shrub: dense green bush covered with pink and white impatiens flowers. | `aa08254a-ac57-4596-b638-fa0f1de6a9af` | 2.370 | 1K | 3.1 |
| `pau_brasil_tripo.glb` | broadleaf tree with textured bark and dense foliage | `d04b2e82-3526-445d-bb3e-5c766459e8a6` | 15.978 | 2K | 3.4 |

Uso comercial: plano Max no momento da geração (ver `assets/CREDITOS.md`).

<!-- lote-2026-09-26:fim -->


## Lote do lugar (28/09/2026)

Texto → 3D (Modelo HD, H3.1) + Malha Smart, exportados pela aba logada do Studio
(`tools/tripo/lote_studio.js`, `__mv.gerar`); originais em `.assets-raw/tripo/arvores/`.
Referências: fotos reais de Bom Jesus dos Pobres enviadas pelo autor (coqueiros da
orla, castanholas da praia).

| Arquivo | O que é | Projeto Tripo | Triângulos | Textura |
| --- | --- | --- | ---: | --- |
| `coqueiro_tripo.glb` (novo, substitui o de 26/09) | coqueiro alto de tronco claro curvado, coroa cheia | `66ccf27f-1570-4e02-b950-cc920e2fb6a4` | 14.716 | 2K |
| `castanhola_tripo.glb` | amendoeira-da-praia (Terminalia catappa), copa em andares | `b00df13a-aef5-452b-93ba-ee7517e577df` | 16.284 | 2K |
| `aroeira_tripo.glb` | árvore retorcida de restinga | `32fa7182-0ffd-45c8-8e2a-5d5f742ee048` | 13.225 | 1K |


## Mata local de Saubara (28/09/2026, tarde)

Espécies escolhidas pela vegetação real de Saubara e da Baía de Todos os Santos:
manguezal (mangue-vermelho predomina nos estuários), restinga (palmeiras e clúsias) e
mata atlântica de beira de rio. Texto → 3D (Modelo HD, H3.1) + Malha Smart pela aba do
Studio; originais em `.assets-raw/tripo/arvores/`.

| Arquivo | O que é | Projeto Tripo | Triângulos | Textura | Onde entra |
| --- | --- | --- | ---: | --- | --- |
| `mangue_tripo.glb` | mangue-vermelho (Rhizophora mangle) com raízes-escora | `1140d4db-f69d-46d4-8c6a-7c7f9acf6dbb` | 18.079 | 2K | margens do rio perto da foz e beira da costa no estuário |
| `piacava_tripo.glb` | piaçava (Attalea funifera), tronco de fibra | `8f94ce1b-ab2f-40b7-8f9e-362a09750325` | 15.792 | 2K | mata e restinga da orla |
| `ingazeiro_tripo.glb` | ingazeiro de beira-rio | `9f3ae65b-34cb-4a2e-99a7-bae5adaac76d` | 16.886 | 2K | margens do rio, para o interior |
| `clusia_tripo.glb` | abaneiro (Clusia) de restinga | `4bfd6095-357e-453a-b14d-ce8a30fa806b` | 10.954 | 1K | restinga da orla |
| `pitangueira_tripo.glb` | pitangueira (Eugenia uniflora) | `a03fecaf-3fcf-45b1-b7a4-85b3e96304f4` | 9.688 | 1K | quintal de cada casa |
| `jenipapeiro_tripo.glb` | jenipapeiro (Genipa americana) | `c3bf89a8-9918-4bb1-b913-f564ed16e21d` | 12.065 | 1K | mata |
| `sub_bosque_tripo.glb` | tufo de helicônias, bromélias e samambaias | `8cce15b0-b94d-46bf-a8dd-f4c902692265` | 7.442 | 1K | sob a mata, um a cada três árvores |
