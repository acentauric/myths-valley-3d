# Construções e peças geradas no Tripo

Geradas por texto no Tripo Studio em 26/09/2026 (modelo H3.1, Máx. qualidade,
textura 2K, GLB) e reduzidas por `tools/modelos/reduzir_glb.py`.
Originais (~60 MB) em `.assets-raw/tripo/construcoes/`, fora do Git.

| Arquivo | O que é | Tarefa Tripo | Original | Reduzido |
| --- | --- | --- | --- | --- |
| `capela_tripo.glb` | Capela colonial caiada, torre sineira, telha-canal, porta em arco, frisos azuis | `aa30ce72-bc83-4bf5-9201-a23818d5181b` | 1.948.070 tri | 261.737 tri |
| `poco_tripo.glb` | Poço de pedra com cobertura de telha, sarilho e balde | `b582fbdc-3dd1-4cf5-80bc-29c7fc57cbc2` | 1.984.588 tri | 106.195 tri |

A capela substitui a igreja de caixas no POI **Igreja**, com a porta voltada para
o cruzeiro; a largura visual é fixada em `CAPELA_WIDTH`. O poço fica na Praça, no
lugar do poço procedural (`FloraReconcavo.poco()` continua disponível para outras
regiões). Conferir os direitos de uso do plano Tripo antes de publicar.

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
| `capela_tripo.glb` | Small 19th-century Brazilian colonial village church (capela) as a stylized game prop: whitewashed lime plaster walls with weathered patches, single square bell tower on one side with a small bell, terracotta clay tile gable roof, arched dark wooden double door, two small windows with wooden shutters, blue painted trim, simple stone steps, isolated building, no ground plane, no text. | `aa30ce72-bc83-4bf5-9201-a23818d5181b` | 11.775 | 2K | 9.2 |
| `casa_pasto_tripo.glb` | Small colonial eating house (casa de pasto) in rural Bahia: whitewashed walls, clay tile roof, covered front porch with wooden posts, long wooden table and benches under the porch, clay pots. | `567602d7-b9e5-43ed-85cd-5d6db872a042` | 11.654 | 2K | 8.6 |
| `casa_taipa_tripo.glb` | small rustic cottage with white plaster walls, brown wooden door, and red clay tile roof | `9ca79ab7-d4d8-498c-a65f-b8580f020602` | 11.343 | 2K | 9.4 |
| `mirante_tripo.glb` | Wooden lookout platform (mirante) on a hill: raised plank deck on wooden posts, wooden railing, short stairs, rustic weathered wood. | `4e4d78cf-fe00-499e-8570-b29cdb47f9dd` | 12.388 | 2K | 8.3 |
| `pier_tripo.glb` | Wooden fishing pier on stilts: weathered planks, wooden posts, a mooring post with rope, small dugout canoe tied at the end. | `3e7d72a4-e279-413e-b97a-a54dabd68ce6` | 11.747 | 2K | 8.6 |
| `poco_tripo.glb` | Old rustic stone water well from a 19th-century Brazilian village as a stylized game prop: round low wall of rough gray fieldstones, two weathered wooden posts holding a small terracotta tile roof, wooden crossbar with a rope and a wooden bucket, isolated object, no ground plane, no text. | `b582fbdc-3dd1-4cf5-80bc-29c7fc57cbc2` | 4.132 | 1K | 3.2 |
| `ponte_tripo.glb` | Rustic wooden footbridge over a creek: plank deck with a slight arch, wooden railings and posts, weathered gray-brown wood. | `660ad404-0371-4421-9ebf-67d15e293b40` | 11.914 | 2K | 8.8 |
| `venda_tripo.glb` | Small 19th-century Brazilian village tavern and general store (venda): whitewashed plaster walls, terracotta tile roof, wide wooden double door, blue shutters, a wooden counter window, two barrels beside the door. | `e9bec55f-1004-44c0-a162-89d9a498f35a` | 11.287 | 2K | 8.3 |

Uso comercial: plano Max no momento da geração (ver `assets/CREDITOS.md`).

<!-- lote-2026-09-26:fim -->


## Igreja de Bom Jesus (28/09/2026)

`igreja_tripo.glb`: a capela do Senhor Bom Jesus dos Pobres, gerada por texto → 3D
(Modelo HD, H3.1) descrevendo a fachada real (frontão ondulado com cruz e pináculos,
porta azul em arco com moldura creme, óculo, torre sineira à esquerda com telhado
piramidal), projeto `bb67178f-f47b-4eb9-bc4b-f6b0a643d55d`, Malha Smart, 13.332
triângulos, textura 2K. Fica no marco "Igreja" do KML; a capela genérica anterior
(`capela_tripo.glb`) virou a "Capela velha", bem afastada, na rua do mirante.
Original em `.assets-raw/tripo/construcoes/igreja_tripo.glb`.

<!-- lote-2026-10-03b:inicio -->

## A capelinha pobre do cemitério (03/10/2026)

A capelinha de taipa ao lado do cemitério, de costas para o mar
(`world_builder._capelinha_do_cemiterio`): um cômodo só, cal rachada, telha
velha e cruz tosca, no lugar da capela colonial reduzida que estava ali.

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
| `capelinha_tripo.glb` | A tiny poor rustic chapel in a rural cemetery, single small room, walls of wattle and daub with cracked whitewash falling off and exposed mud and sticks, a low roof of old uneven clay tiles with some missing, a narrow plain wooden door, a small crooked wooden cross on the roof ridge, no bell tower, no ornaments. | `64edc23b-9af4-41be-9e93-e1195135c7c8` | 12.326 | 2K | 8,1 |

<!-- lote-2026-10-03b:fim -->

<!-- lote-2026-10-05_level_design:inicio -->

## Level design de 05/10/2026: as casas e construções novas do arraial

Gerados por texto no Tripo Studio em 05/10/2026 (Modelo HD H3.1, textura 8K
desligada, 55 créditos) e passados pela Retopologia (Quad, Malha Smart, 40
créditos) com alvo de 5.000 faces. Os que têm rig passaram pelo
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
| `cadeia_tripo.glb` | A small colonial jail and guard post with thick whitewashed walls, barred windows, heavy wooden door, clay tile roof and a small bell. | `2f2747da-db18-4894-a51b-de20ae73226b` | 10.405 | 2K | — | 7,7 |
| `casa_farinha_tripo.glb` | An open-sided cassava flour house (casa de farinha) with a clay-tile roof on wooden posts, a large round copper pan over a brick oven, a wooden press and baskets. | `b832ea91-5441-41d5-9210-c337579a8a84` | 10.027 | 2K | — | 7,8 |
| `casa_palha_tripo.glb` | A small rural hut with wooden pole frame, woven palm-leaf walls and thick thatched palm roof. | `0658f0c2-1289-4ff7-b6f1-f6010935f752` | 10.400 | 2K | — | 8,8 |
| `casa_paroquial_tripo.glb` | A modest colonial parish house next to a church, whitewashed walls, ochre trim, wooden door with a small cross above, clay tile roof. | `f738fcb9-b86c-4529-834d-72d3dd6fd2bc` | 9.895 | 2K | — | 6,4 |
| `casa_pescador_tripo.glb` | A fisherman's small hut with mud walls and a steep roof thatched with dry coconut palm leaves, fishing net hanging on the side wall. | `1a0e2deb-69fc-427d-8d3c-c10e7cfed75a` | 9.961 | 2K | — | 7,8 |
| `casa_taipa_azul_tripo.glb` | A small whitewashed wattle-and-daub (taipa) rural house with blue wooden door and window shutters, red clay tile roof, small front step. | `400778f1-f9e2-41cb-ba7d-2b801c09cb9a` | 9.529 | 2K | — | 7,5 |
| `casa_taipa_ocre_tripo.glb` | A small ochre-yellow wattle-and-daub (taipa) rural house with green wooden door and window, red clay tile roof, worn plaster showing the clay. | `74950a83-5599-4830-affa-965f1487b9c4` | 10.402 | 2K | — | 7,2 |
| `sobrado_tripo.glb` | A small two-story colonial townhouse (sobrado) with whitewashed walls, blue framed windows, a wooden balcony on the upper floor and clay tile roof. | `f06acba9-9472-4c79-abdc-9463aac2c90c` | 10.669 | 2K | — | 8,1 |

SHA-256 de cada GLB no arquivo do lote (`sha256`).

<!-- lote-2026-10-05_level_design:fim -->

<!-- lote-2026-10-05_moradores:inicio -->

## Moradores de 05/10/2026: ofícios e casas a mais: as casas e construções novas do arraial

Gerados por texto no Tripo Studio em 05/10/2026 (Modelo HD H3.1, textura 8K
desligada, 55 créditos) e passados pela Retopologia (Quad, Malha Smart, 40
créditos) com alvo de 5.000 faces. Os que têm rig passaram pelo
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
| `casa_meia_agua_tripo.glb` | A very small poor rural house with a single sloped lean-to clay tile roof (meia-agua), rough clay walls partly whitewashed, a narrow wooden door and one small window. | `5da44fb8-003b-4e8c-9ddc-dc76b26f4648` | 10.905 | 2K | — | 7,7 |
| `casa_taipa_rosa_tripo.glb` | A small rural wattle-and-daub (taipa) house painted faded pink lime wash with a dark green wooden door and two small windows, red clay tile roof, patches of exposed clay and wooden frame. | `5249c595-0bc5-47c9-a80d-44fadd6d846d` | 10.220 | 2K | — | 7,6 |
| `casa_taipa_verde_tripo.glb` | A small rural wattle-and-daub (taipa) house painted pale green lime wash with a brown wooden door and window shutters, low red clay tile roof with a short eave, worn plaster at the base. | `c7ed4ffc-35cf-4269-9de4-fc75d6e6cdc4` | 9.297 | 2K | — | 6,2 |
| `casa_varanda_tripo.glb` | A small rural house with whitewashed adobe walls and a front porch (alpendre) under the extended clay tile roof supported by four rough wooden posts, a wooden bench on the porch, blue door. | `36dd845a-d2dc-478e-a27f-a285467fc75a` | 10.285 | 2K | — | 7,9 |

SHA-256 de cada GLB no arquivo do lote (`sha256`).

<!-- lote-2026-10-05_moradores:fim -->
