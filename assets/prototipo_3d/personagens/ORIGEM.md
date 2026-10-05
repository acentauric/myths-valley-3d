# Moradores e viajante gerados no Tripo

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
| `benedito_tripo.glb` | Seu Benedito, an elderly Black farmer from Bahia in 1887, standing in T-pose with arms straight out: short white beard, straw hat, worn cotton shirt and trousers, leather sandals, weathered kind face, full body character. | `b720f8bb-c7a6-4e46-91f8-0100aabdd33b` | 15.119 | 2K | 7.7 |
| `candinha_tripo.glb` | Dona Candinha, elderly Afro-Brazilian street vendor woman selling sugarcane juice, white headscarf, mustard-yellow blouse, long cream skirt, barefoot, standing in a relaxed A-pose, full body. | `1dc01825-90b3-43f2-92e3-d26d13b69634` | 14.218 | 2K | 6.2 |
| `cosme_tripo.glb` | Cosme, a teenage Afro-Brazilian boy from Bahia in 1887, standing in T-pose with arms straight out: simple cotton shirt, short trousers, barefoot, full body character. | `3a6f74f1-70aa-4e87-a0f5-a7c448b9126d` | 14.399 | 2K | 7.3 |
| `damiao_tripo.glb` | Damiao, a thin middle-aged gravedigger from Bahia in 1887, standing in T-pose with arms straight out: dark vest over a white shirt, flat cap, long dark trousers, full body character. | `5c5dc6ca-d108-41e1-a47c-f51287bd29cc` | 14.881 | 2K | 7.3 |
| `filo_tripo.glb` | Dona Filo, an older Afro-Brazilian woman from Bahia in 1887, standing in T-pose with arms straight out: gray hair in a bun, long cotton dress with apron, shawl over the shoulders, full body character. | `ad015ccd-dd29-483f-b0c9-967b3e2cd1b0` | 14.760 | 2K | 7.5 |
| `pedro_tripo.glb` | Pedro, a young Afro-Brazilian fisherman about 25 years old from Bahia in 1887, standing in T-pose with arms straight out: straw hat, open rough cotton shirt, rolled linen trousers, barefoot, friendly face, full body character. | `c8a8039c-39c1-457f-bcf1-88d24589a941` | 14.400 | 2K | 4.4 |
| `tonho_tripo.glb` | Tonho, a middle-aged fisherman from Bahia in 1887, standing in T-pose with arms straight out: weathered tanned face, cotton shirt, rolled trousers, fishing net over his shoulder, full body character. | `b2bbbd6e-9ff5-49c5-b54b-c948eb266c0c` | 14.576 | 2K | 9.0 |
| `viajante_tripo.glb` | The traveler, a young man from Salvador in 1887 arriving in the countryside, standing in T-pose with arms straight out: short dark hair, dark wool jacket, white shirt, brown trousers, leather boots, small leather satchel, full body character. | `134c732b-480e-44c3-ae2d-e5657e122ad9` | 14.461 | 1K | 5.35 |
| `zefa_tripo.glb` | Dona Zefa, an elderly Black woman herbalist from Bahia in 1887, standing in T-pose with arms straight out: white head wrap, long cotton skirt, shawl, bead necklace, full body character. | `1f74f39d-7d84-4ccf-8743-7551022a3daa` | 14.970 | 2K | 7.6 |

Uso comercial: plano Max no momento da geração (ver `assets/CREDITOS.md`).

<!-- lote-2026-09-26:fim -->

## Pedro animado (26/09/2026)

`pedro_tripo.glb` foi substituído pela exportação animada do mesmo projeto
(`c8a8039c-…`): Auto Rig humanoide com esqueleto Mixamo (65 ossos, 20 créditos) e oito
clipes de predefinições do Studio (idle ×2, walk, run, greet_01, agree, look_around,
wave_goodbye_02), animação no lugar, textura **1K**, 4,4 MB.

## Moradores animados (27/09/2026)

Benedito, Zefa, Cosme, Tonho, Filó, Candinha e Damião receberam o mesmo tratamento
do Pedro, nos mesmos projetos da tabela acima: Auto Rig Mixamo (20 créditos cada) e
sete clipes de predefinição (idle, walk, run, greet_01, agree, look_around,
wave_goodbye_02), exportados em GLB com animação no lugar e textura **1K** (3,9 a
4,7 MB). Feito pela aba logada do Studio com a extensão do Playwright, usando
`__mv.animar()` de `tools/tripo/lote_studio.js`; originais em
`.assets-raw/tripo/personagens/<id>_tripo_animado.glb`. O viajante recebeu rig e animacoes em 04/10/2026 (ver abaixo).

## Pedro nada (27/09/2026)

Mesmo projeto do Pedro (`c8a8039c-…`): retarget da predefinição `preset:biped:swim`
(sem custo) e nova exportação com os oito clipes (idle, walk, run, greet_01, agree,
look_around, wave_goodbye_02, swim), textura 1K, 4,5 MB, por `__mv.animar()` de
`tools/tripo/lote_studio.js`. Original em `.assets-raw/tripo/personagens/pedro_tripo_nado.glb`.

<!-- lote-2026-10-03b:inicio -->

## Mestre Quirino (03/10/2026)

O mestre do saveiro, que encosta no píer no dia 14 de cada estação
(`scripts/prototipo_3d/saveiro_vale.gd`). Gerado em pose T (55), Malha Smart com
alvo de 8.000 faces (40), Auto Rig humanoide com esqueleto Mixamo (20) e as sete
predefinições dos moradores (idle, walk, run, greet_01, agree, look_around,
wave_goodbye_02), exportado com animação no lugar e textura 1K por
`__mv.animar()`.

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
| `quirino_tripo.glb` | Mestre Quirino, a weathered middle-aged sailboat master (mestre de saveiro) from Bahia in 1887, standing in T-pose with arms straight out: short gray beard, sun-darkened mixed-race skin, wide straw hat, loose white cotton shirt with rolled sleeves, faded blue cotton trousers rolled to the calf, rope belt, barefoot, strong calm build, full body character. | `5280d475-a738-4496-8ac9-9ee7557fe93f` | 14.509 | 1K | 4,3 |

<!-- lote-2026-10-03b:fim -->
