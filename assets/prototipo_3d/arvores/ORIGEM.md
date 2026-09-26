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
