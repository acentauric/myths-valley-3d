# Desempenho do vale: terreno, mata, LOD e descarte (escopo VEG)

Investigação só de leitura do commit `eb430e4` (Godot 4.7.2, Forward+). Todos os caminhos são relativos a `myths-valley-3D/`. Cruzei o código com as medições que o coordenador já gravou em `scratchpad/perf/medicoes/` (censo `fps1_censo.txt`, A/B `fps2_resumo.txt` e `fps3.log`, carga `carga_frio.log`) e com contas feitas por mim: `veg_glb_stats.py` lê os triângulos dos GLB, `veg_sim_vale*.py` refaz o plantio de forma aproximada e `veg_grade_costa.py` conta as reconstruções da grade da costa. A simulação do plantio bate com o censo: 2.052 tufos de sub-bosque contra 2.026 reais, 6.163 árvores na mata contra 6.098, 42 mangues contra 34 e 28 coqueiros contra 22.

## Resumo

1. **O LOD continua funcionando, mas o orçamento estourou.** Todas as camadas de vegetação passam por `_multimesh_em_blocos`, com blocos de 40 u, corte por distância e sem sombra. As integrações de 04 e 05/10 somaram 46,7 M de triângulos LOD0 em 17.601 instâncias e 1.864 blocos. Esse sistema foi ajustado em 26/09 para uma mata de cerca de 2,5 mil triângulos por árvore, que rodava a 60 FPS com 2,4 a 3,6 M de triângulos no quadro.
2. **O LOD automático das malhas quase não existe.** O importador gerou 0 ou 1 nível nas árvores do Tripo (coluna `lods` do censo). Por isso uma árvore a 200 u ainda é desenhada com 2,2 a 5,9 mil triângulos em uns 50 px de altura. São microtriângulos, e a GPU trabalha com eficiência baixa. Mudar `lod_bias` não adianta (medido: −1,2 ms, dentro do ruído).
3. **O raio de 280 u é quase o tamanho do vale.** Um círculo com esse raio tem 246 mil u², e a terra tem 263 mil u². Na prática o corte só tira árvores na serra do oeste.
4. **Esconder a vegetação devolve 37 ms de GPU (de 76,8 para 40,1 ms)**, e isso com a câmera DENTRO da igreja, sem nenhuma árvore aparecendo na tela. Sem oclusão, tudo atrás das paredes é processado. Correções medidas: distâncias ×0,5 dão −21 ms, ×0,35 dão −27 ms, e `cull BACK` nos materiais da vegetação dá −12 ms.
5. **A orla e o rio usam os modelos completos (14,7 a 18 mil triângulos) mesmo existindo a versão leve**, que já está importada e é usada na mata. O sub-bosque tem 7.442 triângulos por tufo e é a camada mais pesada em LOD0: 15,1 M.
6. **Carregamento: só a etapa "Estendendo a praia e os rios" leva 19,6 s num único quadro, e acontece duas vezes (menu e jogo).** A causa é a grade da costa (`_distancia_costa`), que se refaz toda vez que a margem pedida muda. Nas fitas de rio a margem alterna entre 4 ou 7 e 20 em cada vértice: são cerca de 23,6 mil reconstruções e 29 M de inserções em dicionário. Corrigir é mexer em uma função, e o resultado continua idêntico bit a bit.
7. O terreno é **uma malha só de 130.644 triângulos, sem LOD e sem pedaços**, com colisão trimesh. É barato para desenhar (cerca de 2,75 ms medidos somando todas as passadas), mas leva cerca de 11 s para montar em GDScript a cada carregamento.

## Fatos contados

| Fato | Valor | Fonte |
|---|---|---|
| Malha do terreno | 1 MeshInstance3D "Terra", 130.644 tri, 0 níveis de LOD | `fps1_censo.txt` linhas 180 e 221; criada em `scripts/prototipo_3d/geo_region_renderer.gd:1040-1044` |
| Subdivisão do terreno | célula 4 u; 0,8 u perto dos rios (o rio fino domina a contagem) | `geo_region_renderer.gd:76`, `:86`, `:1076-1080` |
| Colisão do terreno | ConcavePolygonShape3D (`create_trimesh_shape`, `backface_collision`); 26 trimesh no vale, somando 274.026 faces | `geo_region_renderer.gd:1052-1054`; censo `faces_trimesh` |
| Shader do chão | `terreno.gdshader`, `cull_disabled`; 5 amostras do mapa de solo + 1 ou 2 de grama + até 7 camadas condicionais (≈7 a 10 amostras/px); ~28 `sin()` de hash por pixel | `assets/prototipo_3d/materiais/terreno.gdshader:2`, `:130-136`, `:158-216`, `:121-123`, `:237-248` |
| Texturas do chão (OpenAI) | 8 camadas de 1024², VRAM comprimida (S3TC), com mipmap | `.import` em `assets/prototipo_3d/materiais/` (compress/mode=2) |
| Custo medido do terreno (todas as passadas) | −2,75 ms GPU e −1,04 M tri ao esconder | `fps2.log` AB 56/72 |
| Fitas (ruas, rios, praia) | 8 ruas × 2 fitas + 8 acostamentos + 7 cruzamentos + 2 rios × 2 + foz e ladeira + praia, todas com sombra ligada (padrão) | `geo_region_renderer.gd:423-424`, `:382`, `:397`, `:406`, `:1685`, `:1784`; A/B n=8 e n=7 |
| Vegetação em MultiMesh | 17.601 instâncias, 46.731.199 tri LOD0, 1.864 blocos | `fps1_censo.txt:314` |
| Mata (17 espécies) | 6.098 árvores, 20,5 M tri LOD0, 627 blocos, corte 280 u | censo linhas 316-362; `geo_region_renderer.gd:195`, `:1928` |
| Sub-bosque | 2.026 × 7.442 = 15,08 M tri LOD0, 156 blocos, corte 85 u | censo 315; `geo_region_renderer.gd:191`, `:2033`; GLB `sub_bosque_tripo.glb` |
| Paisagismo (vila) | 2.025 pés + 191 cercas, ≈7,6 M tri LOD0; corte 230, 120, 110 e 90 u | censo; `data/paisagismo/receitas.json`; `paisagismo_vale.gd:41`, `:682` |
| Orla e rio | 22 coqueiros × 14.716; 34 mangues × 18.079; 25 ingazeiros × 16.886; restinga 10 × 16.284 + 6 × 10.954 + 4 × 15.792 | censo 331, 336, 343, 348, 356, 358 |
| Versões leves já importadas (não usadas na orla) | coqueiro_leve 5.214, mangue_leve 4.790, ingazeiro_leve 5.426, castanhola_leve 5.308, clusia_leve 5.165, piacava_leve 5.894 | `veg_glb_stats.json`; `catalogo_assets.gd:332-337` |
| Espécies da mata sem `_leve` | jatobá 2.151, jequitibá 2.791, massaranduba 2.819, angico 2.202, mata_alta 2.489, embaúba 2.963 (69% das árvores) | `catalogo_assets.gd:36-38`, `:275-281` |
| Espécies da mata com `_leve` | 3.403 a 6.141 tri; somam 9,75 M (48% dos tri da mata com 30% das árvores) | censo; `especies_da_mata.gd:97-101` |
| Modelos `_longe` do Tripo | 1.115 a 2.100 tri (mata_alta_longe 2.100, quase igual à mata_a com 2.489) | `veg_glb_stats.json` |
| Copa distante | 64 tri/copa, de 280 a 1.200 u (600 a 1.200 u nas espécies com `_longe`) | `copas_distantes.gd:38`, `:41`, `:85-86`, `:271` |
| Materiais das árvores | 80 de 80 GLB `OPAQUE` + `doubleSided` (vira `cull_disabled`); censo `cull=2` em todos os grupos | `veg_glb_stats.json`; censo |
| Sombra da vegetação | desligada em todos os blocos e copas (`sombra 0`) | `geo_region_renderer.gd:2158`; `copas_distantes.gd:281` |
| `.import` das árvores | `meshes/generate_lods=true`, `create_shadow_meshes=true`, `ensure_tangents=true` | `assets/prototipo_3d/arvores/jatoba_tripo.glb.import` |
| Níveis de LOD gerados | 0 em jatobá, angico, aroeira, mata_alta, ipê, dendê, clúsia, piaçava, jaqueira, cajueiro, mandioca e milho; 1 nos outros | censo, coluna `lods` |
| Câmera do jogo | fov 58 (vertical; ≈89° na horizontal em 16:9), far 2.800 | `player_controller.gd:260-262` |
| Tamanho da terra | caixa de 586 × 508 u; área 263.351 u² (escala 4 m/u) | `veg_sim_vale.json`; `data/mapas/regioes.json:11` |
| Sol | 4 cascatas, `max_distance` 180 u, atlas 4.096 | censo LUZES (`/Cenario/Sol`) |
| Carga: "Moldando o terreno" | 11.177 ms no menu, 10.764 ms no jogo (maior trecho sem ceder ≈2,2 a 2,6 s) | `carga_frio.log` |
| Carga: "Estendendo a praia e os rios" | 19.632 ms no menu, 18.953 ms no jogo, num único quadro | `carga_frio.log` |
| Carga: "Plantando a mata · sorteio" | 2.613 ms no menu, 1.045 ms no jogo | `carga_frio.log` |
| Reconstruções da grade da costa nas fitas de rio | ≈23.638, com ≈29,3 M de inserções (estimativa) | `veg_grade_costa.py` |

### Tabela das camadas de vegetação

As colunas "tri no raio" vêm da simulação aproximada, com a câmera parada em cada ponto, 360° (o tronco de visão leva uns 25 a 35% disso) e antes do LOD de malha. A simulação cobre só a mata, a orla e o rio. O paisagismo da vila não entra nela.

| Camada | Código | Instâncias | Tri/inst. | Tri LOD0 total | Blocos | Corte (u) | LOD importado | Sombra | Material |
|---|---|---:|---:|---:|---:|---|---|---|---|
| Mata (17 espécies) | `geo_region_renderer.gd:1928` | 6.098 | 2.151 a 5.894 | 20,5 M | 627 | 0 a 280 (+20 de margem) | 0 ou 1 nível | não | Standard, opaco, cull off |
| Sub-bosque | `:2033` | 2.026 | 7.442 | 15,08 M | 156 | 0 a 85 | 1 | não | idem |
| Manguezal | `:2131` | 34 | **18.079** | 0,61 M | 6 | 0 a 230 | 1 | não | idem (textura 2K) |
| Ingazeiros do rio | `:2133` | 25 | **16.886** | 0,42 M | 13 | 0 a 230 | 1 | não | idem (2K) |
| Coqueiros da orla | `:2284` | 22 | **14.716** | 0,32 M | 12 | 0 a 250 | 1 | não | idem (2K) |
| Restinga da orla | `:2281` | 20 | 10.954 a 16.284 | 0,29 M | 14 | 0 a 200 | 1 ou 2 | não | idem (2K) |
| Paisagismo: bananal | `paisagismo_vale.gd:682` | 521 | 5.219 | 2,72 M | 9 | 0 a 230 | 1 | não | idem |
| Paisagismo: roças (mandioca, milho, fumo) | idem | 847 | 1.772 a 2.323 | 1,66 M | 20 | 0 a 120 | 0 ou 1 | não | idem |
| Paisagismo: pomares e outros | idem | 657 | 2.126 a 7.682 | 2,79 M | ~100 | 90, 120 ou 230 | 0 ou 1 | não | idem |
| Paisagismo: cerca de varas | `paisagismo_vale.gd:1033` | 191 | 2.029 | 0,39 M | 16 | 0 a 110 | 0 | não | idem |
| Modelo `_longe` (palmeiras, mangue, ingá, dendê) | `copas_distantes.gd:253` | 498 | 1.392 a 1.794 | 0,85 M | ~90 | de 200, 230, 250 ou 280 até 600 | 0 ou 1 | não | idem |
| Copa distante | `copas_distantes.gd:271` | ≈6,4 mil | 64 | ≈0,41 M | ≈700 | de 200 a 280 até 1.200 | n/a | não | ShaderMaterial |
| Pé das árvores (decalque) | `world_builder.gd:1903` | 154 | 2 | ~0 | 31 | sem corte (proposital) | n/a | não | alpha scissor |

Instâncias e triângulos dentro do raio de corte (simulação, LOD0, 360°, só mata, orla e rio):

| Câmera em | Hoje (280 u) | ×0,7 | ×0,5 | ×0,35 |
|---|---:|---:|---:|---:|
| Praça (0,0) | 2.401 inst / 9,0 M | 896 / 3,9 M | 181 / 1,3 M | 28 / 0,5 M |
| Igreja | 2.053 / 8,7 M | 761 / 3,4 M | 156 / 1,0 M | 23 / 0,4 M |
| Píer | 1.391 / 6,0 M | 242 / 1,5 M | 37 / 0,6 M | 30 / 0,5 M |
| Cemitério | 3.043 / 12,3 M | 1.634 / 6,8 M | 791 / 3,3 M | 364 / 1,4 M |
| Mirante | 4.764 / 16,4 M | 3.136 / 10,5 M | 1.967 / 6,5 M | 922 / 3,0 M |
| Centro da mata | 5.208 / 18,8 M | 2.660 / 9,3 M | 1.540 / 5,4 M | 812 / 2,8 M |

## Achados

### VEG-01 — A grade da costa se refaz em cada vértice das fitas de rio (19 s por carga, duas vezes)

- **Evidência.** `_distancia_costa` reconstrói a grade inteira quando `margem` muda (`geo_region_renderer.gd:2645-2657`). Nas fitas com perfil RIVER e MOUTH (`:1539-1565`), cada vértice chama primeiro `_river_shore_weight` (margem 4, `:541-544`) e depois `_terrain_height_at` (margem 20, `:500-503`). Na água do rio e na foz entram `_coastal_ribbon_height` (margem 7, `:1458-1461`) e de novo a 20. A rampa da foz pede a margem 6 (`:1561-1562`). A caixa da costa vai de x −151 a 153 e z −342 a 189, e os dois rios ficam inteiros dentro dela. Cada reconstrução faz 423 a 624 inserções (margem 4 ou 7) mais 2.013 (margem 20). São 13.156 vértices, ≈23.638 reconstruções e ≈29 M de inserções, o que dá 7 a 29 s conforme o custo por inserção. Medido: 19,6 s num único quadro (`carga_frio.log`, "Estendendo a praia e os rios", com "maior trecho sem ceder 19.596,9 ms"). O próprio autor já tinha contornado esse efeito em `_classes_da_mata` (`:1982-1988`).
- **Mecanismo.** É laço em GDScript na thread principal: Vector2i + `has` + `append` em Dictionary. Como não há `await` lá dentro, a tela de carregamento congela por 19 s.
- **Impacto.** Crítico no carregamento: ≈19 s no menu + ≈19 s no jogo. Há também um efeito durante o jogo: `river_water_level_at` (`:552-561`) chama 7 e depois 20, e `river_water_depth_at` chama 20 de novo. Toda consulta de água num ponto do rio (cardume de água doce `cardume.gd:577-579` e `:563-566`, NPC `npc.gd:464`, jogador `player_controller.gd:786-794`) paga duas reconstruções, uns 1 a 2 ms por consulta. A confiança é média para o efeito em jogo, porque depende de quantos agentes estão no rio.
- **Correção de HOJE.** Em `_distancia_costa` (`:2645-2668`), trocar a grade única por um cache por margem: `_grades_costa: Dictionary = {margem: grade}`, invalidado quando `_coast.size()` mudar, e limpo em `_clear_region` (`:764-793`). A resposta continua idêntica bit a bit, porque é a mesma grade de antes, só que guardada. A alternativa é uma grade única com a maior margem (30): o resultado também é o mesmo para todos os usos, já que quem chama só usa distâncias abaixo da margem.
- **Esforço.** 15 a 30 min. **Risco.** Muito baixo. `tests/paisagismo.gd:373` e `:503` chamam `_distancia_costa(p, 26.0)` diretamente e continuam válidos. Convém rodar `tests/paisagismo.gd` e algum portão do chão ou da praia.
- **Como medir.** `tools/prototipo_3d/medir_carregamento.gd`: a etapa "Estendendo a praia e os rios" deve cair de ≈19 s para menos de 1 s, tanto no menu quanto no jogo.

### VEG-02 — O corte de 280 u cobre quase o vale inteiro e o LOD automático não existe: a mata é desenhada em resolução cheia

- **Evidência.** O raio de 280 u (`geo_region_renderer.gd:195`) tem 246 mil u², contra 263 mil u² de terra. Da praça, 2.401 árvores e 9,0 M tri LOD0 ficam dentro do raio, e do mirante 4.764 árvores e 16,4 M (tabela acima). O censo mostra 0 ou 1 nível de LOD em todos os grupos, apesar de `generate_lods=true`. Mudar o limiar de LOD de malha para 8 px dá só −4,4 ms e −0,45 M tri, e `lod_bias` 0,25 dá −1,2 ms (`fps2.log` AB 9, 10 e 17). Medido na vista da igreja: distâncias ×0,7 dão −10,4 ms, ×0,5 dão −21,4 ms e ×0,35 dão −27,3 ms (AB 12 a 14). Nas fotos do coordenador a GPU fica em 57,0 ms (×0,5) e 51,4 ms (×0,35) na igreja, 54,8 e 48,9 ms na praça, e 62,1 e 53,5 ms no mirante. Em `mirante_270_mata_x050.jpg` não aparece diferença visível contra a base.
- **Mecanismo.** Sem níveis de LOD, uma árvore de 11 u a 200 u ocupa uns 55 px de altura (11 / (2·200·tan 29°) · 1080), e mesmo assim manda 2,2 a 5,9 mil triângulos. A GPU rasteriza em quadrados de 2×2 px e perde eficiência com triângulos de 1 px ou menos. Os GLB do Tripo ainda têm de 1,7 a 2,3 vértices por triângulo (costuras de UV), e esses vértices passam pelo vertex shader duas vezes (pré-passada de profundidade e passada de cor). O importador do Godot só simplifica quando consegue colapsar arestas, e as costuras travam o simplificador, por isso saem 0 ou 1 nível. No Godot 4 o LOD de um MultiMeshInstance3D é escolhido para o bloco inteiro, pelo ponto da AABB mais próximo da câmera. Com blocos de 40 u isso funcionaria se houvesse níveis; `lod_bias` abaixo de 1 só tem efeito quando eles existem.
- **Impacto.** Crítico. É a maior alavanca de FPS medida no escopo, de −21 a −27 ms por quadro.
- **Correção de HOJE.** Reduzir as constantes:
  - `LOD_MATA` 280 → 150 (ou 140) e `LOD_COQUEIRO` 250 → 140, `LOD_ARVORE_RIO` 230 → 130, `LOD_RESTINGA` 200 → 120 (`geo_region_renderer.gd:192-195`).
  - No paisagismo, a coluna `lod` de `data/paisagismo/receitas.json`: 230 → 130 e 120 → 70.
  - `LOD_DO_FORRO` 90 → 50 (`paisagismo_vale.gd:41`).
  - A copa distante e a copa pintada no chão acompanham sozinhas: `_multimesh_em_blocos` repassa `distancia_lod` para `CopasDistantes.montar` (`:2174`), e o shader do chão deriva de `LOD_MATA` (`:899-903`).
- **Esforço.** 15 min, mais uma volta visual.
- **Risco.** Baixo para o código. `tests/lod_vegetacao.gd` usa distâncias explícitas (85 e 280) nas chamadas e continua passando. O risco visual é a copa de 64 triângulos (elipsoide) aparecer já a 150 u e o "estalo" ficar mais perto no sobrevoo do menu (16 m de altura). Se a copa ficar feia de perto, use ×0,7 (−10 ms).
- **Estrutural (pós-entrega).** Gerar LOD de verdade: retopologia do Tripo `_longe` com 300 a 600 tri para as 6 espécies sem versão leve, ou soldar os vértices e simplificar offline com meshoptimizer. Depois usar esses modelos como anel do meio (60 a 80 u até 280 u). Ou impostores (billboard octaédrico) a partir de ~120 u.
- **Como medir.** `tools/prototipo_3d/medir_lod.gd` e o A/B do coordenador nas vistas praça, igreja e mirante.

### VEG-03 — Todos os materiais da vegetação desenham as duas faces (`cull_disabled`)

- **Evidência.** Os 80 GLB de árvore têm `doubleSided=true` (`veg_glb_stats.json`), e o censo mostra `cull=2` em todos os grupos de MultiMesh. Medido: `cull BACK` nos 57 materiais da vegetação dá −12,0 ms de GPU (85,0 → 73,1); em tudo, −16,65 ms (`fps3.log`). Nas fotos `*_cull_back.jpg` (mirante, praça) não aparecem buracos visíveis.
- **Mecanismo.** Sem descarte de faces, cada triângulo de costas também é rasterizado na pré-passada de profundidade e testado na passada de cor. Nas copas fechadas do Tripo a face de trás nunca aparece.
- **Impacto.** Alto: cerca de −12 ms.
- **Correção de HOJE.** Em `_multimesh_em_blocos` (`geo_region_renderer.gd:2155-2158`), quando a malha tiver um único StandardMaterial3D: duplicar o material uma vez por malha (cache num Dictionary), aplicar `cull_mode = BaseMaterial3D.CULL_BACK` e usar `visual.material_override`. Pular as copas, que usam ShaderMaterial. Não mexer no material importado, que é compartilhado com as árvores nomeadas.
- **Esforço.** 30 a 45 min. **Risco.** Baixo a médio: alguma folha de face única pode virar buraco quando vista de baixo. Conferir uma árvore de perto, da altura do jogador, e o cajueiro e a bananeira (folhas largas).
- **Como medir.** A/B do coordenador ("faces de trás: cull BACK nos 57 materiais").

### VEG-04 — Dentro de casas e da igreja a mata inteira continua sendo processada

- **Evidência.** A vista "igreja 90" é o interior da igreja (`fotos/igreja_090_base.jpg`). Fora a porta, nada lá fora aparece na tela, e mesmo assim esconder toda a vegetação devolve 37,4 ms de GPU (76,8 → 40,1; tri 8,33 → 5,61 M) (`fps2.log` AB 35). A oclusão está desligada (`occlusion_culling: False` no censo). `Interiores` já emite `entrou` e `saiu` (`scripts/prototipo_3d/interiores.gd:43-44`).
- **Mecanismo.** O Godot só descarta pelo tronco de visão e pela distância. Paredes não escondem nada sem OccluderInstance3D. A pré-passada de profundidade ainda processa os vértices e rasteriza tudo o que está atrás da parede.
- **Impacto.** Alto em interiores: cerca de 30 ms. A chegada passa pelas casas e pela igreja.
- **Correção de HOJE.** Na região, uma função `modo_interior(ligado)` que, quando ligado, faz `visibility_range_end = minf(distancia, 40.0)` em `_blocos_vegetacao_lod` e esconde as copas, e quando desligado restaura (o mesmo laço de `_atualizar_lod_da_camera`, `:2448-2453`). Ligar nos sinais `Interiores.entrou` e `saiu` (no world_builder ou no prototype).
- **Esforço.** 1 h. **Risco.** Baixo a médio: pela porta aberta só aparecem as árvores até 40 u (as nomeadas, que são MeshInstance, continuam).
- **Estrutural.** BoxOccluder3D nas paredes das casas e da igreja, com `rendering/occlusion_culling/use_occlusion_culling=true`.
- **Como medir.** Vista igreja 90: GPU antes e depois.

### VEG-05 — A orla e o rio plantam os modelos completos de 14,7 a 18 mil triângulos (com 2K) em vez dos leves

- **Evidência.**
  - `_build_coast_palms` usa `_malha_da_especie("coqueiro", rng)` (`geo_region_renderer.gd:2207`).
  - A restinga usa `_malha_da_especie(local, rng)` com castanhola, clúsia e piaçava (`:2223`).
  - `_build_margens_do_rio` usa `"mangue"` e `"ingazeiro"` (`:2045-2046`).
  - Só a mata passa por `EspeciesDaMata.malha()`, que escolhe a `_leve` (`:1899`; `especies_da_mata.gd:97-101`).
  - Censo: Manguezal 34 × 18.079, Ingazeiros do rio 25 × 16.886, Coqueiros da orla 22 × 14.716, castanhola 10 × 16.284, clúsia 6 × 10.954, piaçava 4 × 15.792.
  - As leves existem: 4.790, 5.426, 5.214, 5.308, 5.165 e 5.894.
- **Mecanismo.** Os mesmos microtriângulos do VEG-02, e são 3 a 4 vezes mais triângulos por árvore. Os modelos completos ainda carregam 3 texturas de 2048², e o atlas de VRAM cresce.
- **Impacto.** Médio: ≈1,13 M tri LOD0 a menos no total. Nas vistas da costa (píer, foz) dá uns 0,3 a 0,6 M dentro do quadro (estimativa: cerca de metade dos 1,64 M LOD0 da orla e do rio fica perto do píer).
- **Correção (hoje, se der tempo).** Trocar as chaves por `EspeciesDaMata.malha("coqueiro")` (e o mesmo para mangue, ingazeiro e as da restinga). `CopasDistantes.malha_de_longe` já aceita as duas chaves (`copas_distantes.gd:220`).
- **Esforço.** 20 min. **Risco.** Médio. O trajeto gravado do sobrevoo foi conferido com a geometria do coqueiro completo, e `tests/sobrevoo_livre.gd` pode reprovar se as folhas do leve mudarem. Também mudam o toco (`CoqueiroCortado.referencias_tronco`, `:2209`) e as colisões (`tests/colisoes_do_vale.gd`). É preciso rodar esses portões.
- **Como medir.** Vista píer 90 (hoje 8,3 M tri e 84 ms de GPU): tri e GPU antes e depois.

### VEG-06 — O sub-bosque tem 7.442 triângulos por tufo e é a camada mais pesada (15,1 M LOD0)

- **Evidência.** `sub_bosque_tripo.glb` tem 7.442 tri, mais que qualquer árvore da mata. São 2.026 instâncias, uma a cada 3 árvores (`geo_region_renderer.gd:2020`), com corte em 85 u (`:191`). Na vila não pesa (esconder dá +0,5 ms na igreja, AB 46). Na mata, a simulação dá 203 tufos e 1,5 M tri dentro de 85 u no mirante, e 231 tufos e 1,7 M no centro da mata.
- **Mecanismo.** Mesmo do VEG-02: microtriângulos a 30 a 85 u, num arbusto de 1,3 u de altura.
- **Impacto.** Médio, só nas trilhas da mata, no mirante e na chapada.
- **Correção de HOJE.** `LOD_SUB_BOSQUE` 85 → 40 (`:191`), ou trocar a malha em `:2018` por `samambaia` (2.126) ou `bromelia` (2.219), que já estão importadas, o que corta 3,4 vezes. **Estrutural.** Um tufo de ~800 tri.
- **Esforço.** 5 min. **Risco.** Baixo (visual).
- **Como medir.** A/B na vista mirante 270 com o grupo 'Sub-bosque' escondido.

### VEG-07 — Paisagismo da vila: roças com 1,8 a 2,3 mil triângulos por pé, a cada 1,6 a 1,8 u

- **Evidência.** Pé de mandioca 1.772 tri, milho 2.001 e fumo 2.323, em fileiras de 1,8 × 2,4 u e 1,6 × 2,2 u (`receitas.json`, roca_mandioca e roca_milho_fumo). São 847 pés e 1,66 M tri, com corte em 120 u. O bananal tem 521 × 5.219 = 2,72 M, corte 230 u. O capim de forro tem 2.907 tri por tufo. A goiabeira e o mamoeiro entram completos (7.682 e 5.087; não há versão `_leve`). Total do paisagismo: ≈7,6 M tri LOD0, quase todo dentro do raio de quem está na vila.
- **Mecanismo.** O mesmo, só que perto do jogador: roçado, casa de taipa e lavoura. Nessas vistas (`fps1_vistas.txt`): casa_de_taipa 135 com 8,1 M tri e 79,5 ms de GPU.
- **Impacto.** Médio a alto nas vistas do Poente e do roçado (não medido em separado).
- **Correção de HOJE.** Só dados: em `receitas.json`, `lod` das roças 120 → 60 e pomares e bananal 230 → 120; `LOD_DO_FORRO` 90 → 40 (`paisagismo_vale.gd:41`). **Estrutural.** Retopologia das plantas de roça com 200 a 400 tri.
- **Risco.** Baixo; `tests/paisagismo.gd:332` só usa `lod` numa entrada falsa.
- **Como medir.** A/B nas vistas casa_de_taipa 135 e lavoura, escondendo os grupos `Paisagismo_ pe_de_*`, `capim 90` e `bananeira_leve 230`.

### VEG-08 — No mapa (câmera ortográfica) o corte é suspenso para TODA a vegetação, inclusive o sub-bosque

- **Evidência.** `_atualizar_lod_da_camera` zera `visibility_range_end` de todos os blocos quando a câmera é ortográfica (`geo_region_renderer.gd:2444-2453`). O mapa do jogo usa a viewport principal com câmera ortográfica a 3.000 u (`mapa_jogo.gd:24`, `:50`). Com o zoom todo aberto, o tronco de visão pega o vale inteiro: até 46,7 M tri LOD0, contando 15 M do sub-bosque e o forro (estimativa, sem medição).
- **Mecanismo.** Sem corte e sem níveis de LOD, cada um dos 1.056 blocos é desenhado em resolução cheia.
- **Impacto.** Médio: travada ao abrir o mapa. Não afeta o FPS de passeio.
- **Correção.** Não suspender o corte nos blocos de sub-bosque e forro, filtrando pelo nome ou pela distância ≤ 90 (o bloco de teste do portão tem 85 u e chama "Teste", então filtrar pelo nome mantém `tests/lod_vegetacao.gd:30` passando). **Estrutural.** No mapa, esconder as árvores e mostrar só as copas (0,4 M tri). Exige atualizar o portão (`:30` e `:118`).
- **Esforço.** 20 min. **Risco.** Baixo.
- **Como medir.** FPS com o mapa (M) aberto e o zoom no máximo para fora.
- **Também conferido.** O corte não fica preso desligado: `fechar()` devolve a câmera anterior (`mapa_jogo.gd:78-79`), e o teste é refeito a cada quadro, então volta sozinho.

### VEG-09 — O terreno é uma malha única, sem LOD, que faz sombra em todas as cascatas

- **Evidência.** "Terra" tem 130.644 tri e 0 níveis (censo). É criada sem mexer em `cast_shadow` (`geo_region_renderer.gd:1041-1044`, padrão ON), e as fitas também (`:1589-1592`). Esconder as malhas com `terreno.gdshader` dá −1,04 M tri e −2,75 ms. O número de triângulos bate com 130 mil × cerca de 8 passadas: cor, pré-passada, 4 cascatas e as passadas do minimapa.
- **Mecanismo.** Uma AABB do tamanho do vale nunca sai do tronco de visão nem de nenhuma cascata. O chão quase plano (exagero 2×) pouco ganha fazendo sombra em si mesmo.
- **Impacto.** Baixo: estimo −1 a −1,5 ms desligando a sombra de Terra e das fitas.
- **Correção de HOJE.** `visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF` em `:1043` (Terra) e `:1591` (fitas). **Estrutural.** Pedaços de 64 u, com LOD por pedaço.
- **Risco.** Baixo (o morro do mirante deixa de sombrear a baixada na hora dourada).
- **Como medir.** A/B "Terra sem sombra".

### VEG-10 — Montagem pesada refeita a cada carregamento e duas vezes por partida (menu e jogo)

- **Evidência.** `carga_frio.log`:
  - "Moldando o terreno" leva 11,2 s no menu e 10,8 s no jogo: subdivisão recursiva em GDScript de 130 mil triângulos (`:1068-1094`), mais `index`, `generate_normals`, `commit` e `create_trimesh_shape` (`:1038-1052`), com um trecho de 2,2 a 2,6 s sem ceder.
  - O sorteio da mata leva 1,0 a 2,6 s. A rejeição pela costa usa `_distance_to_line(point, _coast)` linear sobre 148 segmentos (`:1850`), sem a grade.
  - A abertura monta a mesma região para o sobrevoo, e o vale monta outra vez.
- **Mecanismo.** É CPU de GDScript na thread principal, e o resultado sai determinístico, sempre o mesmo para os mesmos dados.
- **Correção.**
  - HOJE, para o sorteio: trocar `:1850` por `_distancia_costa(point, coast_clearing)`. Com o VEG-01 aplicado, sai idêntico (a grade cobre todo segmento a menos da margem).
  - ESTRUTURAL: assar em disco a malha "Terra", as fitas e as formas trimesh (ResourceSaver, `.res` com chave no hash dos JSON do mapa), ou gerar na exportação. Montar a região uma vez e reaproveitá-la entre menu e jogo. O escopo de carregamento detalha.
- **Esforço.** Hoje 10 min; estrutural de 1 a 2 dias. **Risco.** Hoje baixo; o estrutural precisa de portão de equivalência.

### VEG-11 — Custo por quadro do GeoRegionRenderer (migalha)

- **Evidência.**
  - `_process` (`:2426-2434`): `_atualizar_lod_da_camera` é O(1) por quadro e só percorre os 1.056 blocos quando a projeção muda.
  - A cada 0,25 s, `_refresh_tree_collisions` varre 11 × 11 = 121 células de 8 u (`:2505-2509`). Cada célula ausente aloca um `[]` novo no `get`. Para cada tronco perto monta um Dictionary de 10 chaves, depois `sort_custom` com Callable em GDScript, e por fim regrava `shape.height`, `shape.radius` e `body.transform` nos 48 corpos (`:2464-2489`), mesmo quando nada mudou.
  - Nos A/B o geo_region_renderer não aparece entre os scripts caros.
- **Impacto.** Baixo: estimo 0,3 a 1,5 ms a cada 0,25 s, menos de 0,5 ms por quadro em média.
- **Correção (pós).** Pular a varredura se o jogador andou menos de 1 u, e só regravar as formas quando mudarem.
- **Risco.** `tests/colisoes_do_vale.gd` confere a escolha.

### VEG-12 — Detalhes menores

- `CHAO_PRACA_TEXTURE` e `GRAMA_TERRA_MATA_TEXTURE` são pré-carregadas e não usadas (`geo_region_renderer.gd:19-20`). `chao_praca_v1.png` está sem compressão e sem mipmap (cerca de 4 MB de VRAM). Migalha.
- `surface_at` (`:729-735`) mede a costa linearmente (148 segmentos) em todo ponto da vila. É chamado a cada passo do jogador (`player_controller.gd:877`) e para cada árvore na montagem dos decalques (`world_builder.gd:1885`). Migalha. A mesma grade do VEG-01 resolveria.

## O que está OK

- **O LOD por distância continua valendo depois de 04 e 05/10.** Toda camada de vegetação passa por `_multimesh_em_blocos` com corte e margem de 20 u: mata, sub-bosque, mangue, ingá, restinga, coqueiros, paisagismo e cercas (`geo_region_renderer.gd:1928`, `:2033`, `:2131`, `:2133`, `:2281`, `:2284`; `paisagismo_vale.gd:682`, `:1033`). A copa distante cria nós próprios, também com faixa de visibilidade (`copas_distantes.gd:277-287`). A única camada sem corte é o decalque, de propósito: 154 instâncias × 2 tri. Nenhuma camada nova cria MeshInstance3D ou MultiMesh sem corte.
- **Sombra.** Nenhum bloco de vegetação ou de copa faz sombra (`:2158`, `copas_distantes.gd:281`; censo `sombra 0`; A/B "vegetação sem projetar" −0,6 ms, dentro do ruído). As 4 cascatas do sol não veem a mata.
- **Materiais opacos.** Os 80 GLB de árvore são `OPAQUE`: não há alpha blend, nem ordenação, nem sobreposição por transparência.
- **Texturas.** As do chão são de 1K com compressão S3TC e mipmap. As árvores leves, `_longe` e da mata são de 1K; 2K só nos modelos completos (ver VEG-05).
- **Shader do chão.** Custa ≈2,75 ms somando todas as passadas, com 7 a 10 amostras por pixel. Não é prioridade hoje.
- **Mapa de solo.** Usa só primitivas em C++ (5 camadas L8 do tamanho da terra; `mapa_de_solo.gd`).
- **Ruídos.** As texturas de ruído do rio e da foz ficam em cache (`mar.gd:21`, `:257-269`).
- **Chamadas de desenho.** São de 750 a 1.950 por quadro, com CPU de renderização de 2 a 4 ms (`fps1_vistas.txt`). Não são o gargalo, nem os 1.864 MultiMeshInstance3D. O limite é a GPU.
- **Câmera.** O far de 2.800 contra as copas a 1.200 é coerente. Far 600 mudou só +0,33 ms (`fps2.log`).
- **Árvore mais próxima.** `arvores_info.gd` acha a árvore mais perto por grade de quadras (`:255-268`).
- **Portão.** `tests/lod_vegetacao.gd` cobre o corte, o mapa, a volta, a reconstrução e as copas.

## Dúvidas para medição A/B

1. **VEG-01 (carga).** Numa cópia descartável, aplicar o cache por margem em `_distancia_costa` e cronometrar a etapa "Estendendo a praia e os rios" com `medir_carregamento.gd`, no menu e no jogo. Sem mexer no código, dá para contar as reconstruções com um contador temporário dentro do `if` de `:2646`.
2. **Mirante 270 e centro da mata.** Esconder o grupo 'Sub-bosque', depois só `LOD_SUB_BOSQUE` 40, depois só o sub-bosque com a malha `samambaia`.
3. **Píer 90 e foz.** Esconder os grupos 'Coqueiros da orla', 'Manguezal', 'Ingazeiros do rio' e 'Restinga da orla*' para ver o teto de ganho do VEG-05.
4. **Casa de taipa 135, lavoura e roçado.** Esconder 'Paisagismo_ pe_de_mandioca 120', '...pe_de_milho 120', '...pe_de_fumo 120', '...capim 90' e '...bananeira_leve 230', primeiro um a um e depois juntos.
5. **Interior (igreja 90).** Pôr `visibility_range_end` = 40 em todos os blocos de `_blocos_vegetacao_lod` e esconder os nós `Copa distante*`.
6. **Mapa aberto (M) com zoom todo para fora.** Medir FPS como está, e depois com o sub-bosque e o forro excluídos da troca para ortográfica.
7. **Terreno.** `cast_shadow = OFF` em `/root/Vale3D/Cenario/bom_jesus_dos_pobres/Terra` e nas fitas (nós com `estrada_acostamento`, `leito_rio`, "Orla de areia").
8. **Copas.** Esconder todos os nós `Copa distante*` nas vistas praça 0 e mirante 270, para ver o custo real dos cerca de 700 blocos.
9. **Combinação para a build.** ×0,57 (`LOD_MATA` 160) + cull BACK na vegetação + sub-bosque 40 + `lod` das receitas pela metade. Medir com e sem a orla leve, e conferir visualmente o sobrevoo do menu.
10. **Calibração.** Confirmar se `RENDER_TOTAL_PRIMITIVES_IN_FRAME` conta a pré-passada de profundidade (isso muda a leitura de "ms por M tri").
11. **Fora do escopo, mas pode multiplicar tudo.** O `nvidia-smi` gravado mostra a GPU em 300 a 1.140 MHz e 9 a 17 W com uso de 65 a 100% (`fps2_resumo.txt`, bloco GPU). Uma 1660 Ti Max-Q costuma chegar a 60 a 80 W. Vale conferir se o notebook está na bateria ou em modo de economia (Optimus, Whisper Mode) durante as medições.
