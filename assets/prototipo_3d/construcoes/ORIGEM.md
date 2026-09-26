# Construções e peças geradas no Tripo

Geradas por texto no Tripo Studio em 26/09/2026 (modelo H3.1, Máx. qualidade,
textura 2K, GLB) e reduzidas por `prototipo_3d/tools/modelos/reduzir_glb.py`.
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
Retopologia e exportação em lote por `prototipo_3d/tools/tripo/lote_studio.js`;
cópia para o projeto por `sincronizar_downloads.py` (originais em
`.assets-raw/tripo/`, fora do Git). Tarefas, categorias e prompts completos em
`prototipo_3d/tools/tripo/lote_2026-09-26.json`. Estas versões substituem as
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
