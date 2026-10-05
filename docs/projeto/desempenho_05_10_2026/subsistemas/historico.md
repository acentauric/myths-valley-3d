# Histórico de desempenho: as otimizações antigas ainda valem? O que entrou desde os 60 FPS (escopo HIS)

Repositório lido: `C:\VIRTUALENVS\myths-valley\myths-valley-3D`, branch main, HEAD `eb430e4` (05/10/2026 15:11), árvore limpa. Somente leitura: nada foi editado, o Godot não foi executado, `.env` não foi aberto. Os scripts auxiliares (Python, biblioteca padrão) ficaram em `scratchpad\perf\` (`cargas.py`, `totais.py`, `merges.py`, `glb_scan.py`, `glb_analise.py`, `ctex.py`, `lotes.py`).

Convenções deste arquivo: "medido" = número que aparece em doc, commit ou código do autor; "contado" = número que eu contei no repositório; "estimativa" = conta minha, com a conta mostrada. Orçamento de quadro: 60 FPS = 16,7 ms; 30 FPS = 33,3 ms; 20 FPS = 50 ms; 15 FPS = 66,7 ms.

---

## Resumo

1. **As otimizações antigas continuam presentes e ligadas no HEAD.** Blocos de 40 u, descarte fora da câmera, LOD importado, corte por distância (85/200/230/250/280 u), compressão VRAM, carregamento em etapas de 80 ms, grades de células da montagem e sem sombra na vegetação. As constantes de LOD não mudam desde 30/09 (`015c01c`). Nenhuma foi removida e nenhuma foi afrouxada. Há um furo parcial: a troca para as malhas "leves" vale só para a mata, e não para a orla, o manguezal, o ingá, a restinga e o sub-bosque.
2. **O "60 FPS" registrado é de 26/09 e nunca foi o estado do jogo de hoje.** Foi medido a 1280×720, com 1.800 árvores, 69 GLBs, sem minimapa, sem mar de verdade, com 7 moradores e nenhum bicho de quintal. Quatro dias depois (30/09, `015c01c`) o próprio A/B do autor já media **12,6 a 32,8 FPS** a 1024×576, com VSync desligado, minimapa desligado e a lógica do jogo parada. Em 05/10 o próprio código diz "o vale já anda perto de 20 FPS" (`scripts/prototipo_3d/copas_distantes.gd:12`). Ou seja, a queda não nasce nas integrações de 04–05/10: ela nasce entre 26 e 28/09, e 04–05/10 só a agravam.
3. **O que mais pesa na história, por ordem de evidência:** (a) densidade da mata de 1.800 para 6.234 árvores (3,46×) logo depois da medição de 60 FPS; (b) o jogo passou a abrir em tela cheia 1080p em 04/10 (`14c1b47`), 2,25× os pixels da medição de 60 FPS e 3,5× os da medição de 30/09, com MSAA 2× (que existe desde o 1º dia); (c) as espécies pesadas da mata local e o sub-bosque de 7.442 triângulos por tufo, que entraram em 28/09 (`a0638d7`); (d) o mar com `hint_screen_texture` e `hint_depth_texture` (27/09, `e38f9b4`) e o minimapa que desenha o vale uma segunda vez (≤ 28/09); (e) em 05/10, o chão de 8 camadas, o céu em tempo real, 14 moradores novos, 31 bichos e os cardumes. Os itens (d) e (e) são hipóteses de custo: só a medição na GPU decide.
4. **Carga de assets:** GLBs foram de 69 (319 MB) em 26/09 para 262 (946,6 MB) no HEAD (3,8× em quantidade, 3,0× em MB). O catálogo foi de 83 para 264 entradas. As texturas VRAM compactadas somam 1.039 MB no cache `.godot/imported` (873 arquivos `.s3tc.ctex`); em 26/09 eram 735–740 MB. Estimo o executável da próxima build em cerca de 1,25 a 1,3 GiB, contra 515,7 MiB da Build 8 (conta na seção "Builds anteriores").
5. **Não existe portão de desempenho.** Nenhum teste lê FPS, triângulos, draws, VRAM ou tempo de carga com teto. Os únicos tetos são de travamento (30/90/420 s) e um orçamento de 45 M de triângulos "se tudo aparecesse de uma vez", só do paisagismo. O teto de espera do vale no `smoke_opening` foi de 30 s para 90 s em 05/10 (`339b3a2`), com o comentário "o vale do level design lê mais modelos em segundo plano: com a bateria cheia passa de 30 s" (`tests/smoke_opening.gd:76,105`): é o único registro, indireto, de que o carregamento ficou mais lento. A regressão entrou sem alarme.
6. **O que dá para fazer hoje com pouco risco** (todos só viram decisão depois do A/B do coordenador): reduzir `LOD_MATA` e `LOD_SUB_BOSQUE` (constantes, sem mudar posições nem sorteios), usar as malhas `_leve` no manguezal, ingá e restinga (uma chamada em 3 lugares), `scaling_3d` de 0,75 no `project.godot`, minimapa em `UPDATE_ONCE` a 5 Hz ou desligado por padrão, e `Sky.PROCESS_MODE_INCREMENTAL` (exige mexer em `tests/ceu_horizonte.gd:85`). Mudar `tree_count` não é "constante segura": desloca todo o sorteio posterior (rio, orla, sobrevoo, navegação, paisagismo).

---

## Fatos contados

| Fato | Valor | Fonte |
|---|---|---|
| HEAD / branch / árvore | `eb430e4`, main, limpa; 279 commits | `git log` |
| Primeiro e último registro de 60 FPS | 26/09: `f1c393c` (VRAM) e `027ced5` (mata em blocos) | CHANGELOG_3D.md:1308-1319; VALE_VIVO_3D.md:119-126 |
| Condição da medição de 60 FPS | GTX 1660 Ti, janela 1280×720, `tree_count` = 1.800 | VALE_VIVO_3D.md:119; `git show 027ced5:data/mapas/bom_jesus_dos_pobres_cenario.json` |
| `tree_count` ao longo do tempo | 1.800 (26/09, `027ced5`) → 5.000 (26/09 20:12, `a1466e3`) → 6.234 (27/09, `e38f9b4`); HEAD 6.234 | `data/mapas/bom_jesus_dos_pobres_cenario.json:2723` |
| Medição A/B de 30/09 | 1024×576, VSync off, 9h, minimapa off, jogador e `_process` do vale parados: 12,6–32,8 FPS; 5,65–17,33 M tri | VALE_VIVO_3D.md:157-165; `tools/prototipo_3d/medir_lod.gd:18-19,30-31,34,41` |
| Comentário do autor em 05/10 | "o vale já anda perto de 20 FPS" | `scripts/prototipo_3d/copas_distantes.gd:12` |
| Resolução do jogo hoje | tela cheia (`window/size/mode=3`) em 1920×1080 = 2.073.600 px; 720p = 921.600 (×2,25); 576p = 589.824 (×3,52) | `project.godot:67`; commit `14c1b47` (04/10 13:17) |
| MSAA 3D | 2× (`msaa_3d=1`), no projeto desde 23/09 (`46f044c`) | `project.godot:97` |
| GLBs no repositório | 69 / 319 MB (26/09 `027ced5`) → 77 / 330 MB (Build 6, `df93e2f`) → 84 / 371 MB (Build 7 e 8) → 106 / 435 MB (`40c677b`) → 257 / 924 MB (`ce20572`) → **262 / 946,6 MB (HEAD)** | `totais.py` (lê o `size` dos ponteiros LFS) |
| GLBs do HEAD por pasta | árvores 80 / 321 MB; construções 25 / 182,5; personagens 24 / 117,1; adereços 39 / 99,9; animais 31 / 76,8; itens 28 / 57,3; peixes 17 / 35; móveis 15 / 34,2; outros 3 | `totais.py` |
| Triângulos por GLB (contado no cabeçalho do GLB) | árvores em versão cheia 9.688–20.453; árvores `_leve` 3.403–6.141; `_longe` 1.115–2.100; sub_bosque 7.442; casas e construções grandes 9.297–17.319 (poço 4.132, guarita 6.373, portão 6.006); moradores 10.302–15.119; bichos 2.902–6.070; peixes 2.026–5.383 | `glb_scan.csv` |
| GLBs com mais de um nó de malha (perderiam LOD na fusão) | 0 de 262 | `glb_analise.py` |
| GLBs com textura de 2K | 40 (14 árvores pesadas, 23 construções, 1 adereço, 1 casa, 1 personagem); o resto é 1K | `glb_scan.csv` (coluna `maxdim`) |
| Entradas do catálogo Tripo | 83 (30/09 e Build 8) → 264 (HEAD) | `git show REV:scripts/prototipo_3d/catalogo_assets.gd \| grep -c '"tripo":'` |
| Importação de texturas | `compress/mode=2` (VRAM) em 872 dos 954 `.import`; 82 sem compressão (cordéis, cursores, ícones, 4 materiais de casa) | `project.godot:78-84`; contagem em `assets/**/*.import` |
| LOD de malha e malha de sombra nos GLBs | `meshes/generate_lods=true` e `create_shadow_meshes=true` em 262 de 262 | `assets/**/*.glb.import` |
| Cache importado (lido hoje, 15:58) | 873 `.s3tc.ctex` = 1.039,2 MB; 84 `.ctex` sem VRAM = 26,4 MB; 262 `.scn` = 88,1 MB. O briefing falava em 463 `.ctex` / 492 MB: o cache cresceu durante a reimportação de hoje | `ctex.py`; `.godot/imported` |
| Texturas 2K compactadas | 122 arquivos ≥ 2,7 MB somam 432 MB | `.godot/imported` |
| Moradores | 7 (Build 8) → 8 (`40c677b`) → **22** (HEAD) | `data/npcs_3d.json` (`moradores`) |
| Funções `_process` / `_physics_process` nos scripts | 26 / 10 (Build 8) → 44 / 13 (HEAD); 21 arquivos novos com `_process` desde a Build 8 | `git grep` em 66cacc1 e HEAD |
| Raio e blocos de vegetação | `BLOCO_MATA=40`, `LOD_SUB_BOSQUE=85`, `LOD_RESTINGA=200`, `LOD_ARVORE_RIO=230`, `LOD_COQUEIRO=250`, `LOD_MATA=280`, `LOD_MARGEM=20`, `LOD_BIAS=0,65` (idênticos desde `015c01c`) | `scripts/prototipo_3d/geo_region_renderer.gd:187-197` |
| Copas distantes | até 1.200 u; modelo `_longe` até 600 u para 6 espécies (524 troncos, segundo o doc) | `scripts/prototipo_3d/copas_distantes.gd:38-44`; VALE_VIVO_3D.md:188-195 |
| Sombra do sol | ligada, `directional_shadow_max_distance=180`, 4 cascatas; idêntica desde 26/09 (só mudou de arquivo) | `scripts/prototipo_3d/ceu_vale.gd:91-93` |
| Câmera | `far = 2800` desde 23/09 | `scripts/prototipo_3d/player_controller.gd:262` |
| Câmera do minimapa | `SubViewport` 176 px, `UPDATE_ALWAYS` quando visível, ortográfica a 100 u, `far=400` | `scripts/prototipo_3d/minimapa.gd:15,27,99,144` |
| Orçamento de montagem | `ORCAMENTO_QUADRO_US = 80000` (inalterado desde `6eaaef6`, 27/09) | `geo_region_renderer.gd:70`; `world_builder.gd:674` |
| Medições de carga registradas | ~24 s → ~8 s (27/09); maior congelamento 4,5 s → 0,7 s (27/09); 25,2 s → 4,4–5,7 s de montagem, menu 33,9 → 6,7 s, JOGAR 27,4 → 6,0 s, só CPU e `--headless` (02/10) | CHANGELOG_3D.md:1209,1273,903-907; `git show f44f61c` |
| Remedição de carga depois de 02/10 | nenhuma encontrada. Só dois comentários: "a leitura em segundo plano do vale passa de 700 quadros (734 medidos)" (`80eb70b`) e "o vale do level design (05/10) lê mais modelos em segundo plano: com a bateria cheia passa de 30 s" (`339b3a2`, teto de 30 → 90 s) | `tests/smoke_opening.gd:76,105`; `git show 80eb70b -- tests/smoke_opening.gd` |
| Builds | `build_numero` = 8; Build 5 (26/09), 6 (28/09), 7 (03/10 18:02), 8 (03/10 22:15). Zips 6 e 7 = 359.370.943 e 359.381.312 B; exe = 540.764.864 B (515,7 MiB) | `data/historico_3d.json:3`; CHANGELOG_3D.md; `build/` |
| Portões de desempenho | 0 testes leem `RENDER_*`, `TIME_FPS`, `VIDEO_MEM` ou tempo de carga com teto | `grep` em `tests/` |
| Tetos existentes | `mata_em_manchas`: ≤ 6.500 tri por malha da mata, média ≤ 4.500; `paisagismo`: ≤ 14.000 pés e ≤ 45 M tri somados; travamento: 30 s (`tela_carregamento`), 90 s (`smoke_opening`), 420 s (`testar.ps1`) | `tests/mata_em_manchas.gd:25-26`; `tests/paisagismo.gd:36-37`; `tools/prototipo_3d/testar.ps1:63` |

Observação: o doc `ASSETS_TRIPO.md:17` diz que a medição de 26/09 foi a 1080p, e `VALE_VIVO_3D.md:119` diz 1280×720. Os dois falam do mesmo dia. Os docs não se entendem, e nenhum dos números tem log guardado. Trato 1280×720 como o mais provável porque é a resolução do projeto (`project.godot:65-66`).

---

## Linha do tempo das otimizações (item 1)

| # | Data | Commit | Otimização | Números da época |
|---|---|---|---|---|
| O1 | 26/09 | `58536cf`, `df1b8d7` | Retopologia "Malha Smart" do Tripo no lugar do HD cru (1,9 M de triângulos) e no lugar do redutor `reduzir_glb.py` (aposentado) | mangueira: 1.915.732 → 20.453 tri; bancada de 3 mangueiras: 60 FPS, ~2,5 M tri, ~300 draws (ASSETS_TRIPO.md:14-26) |
| O2 | 26/09 20:55 | `f1c393c` | Texturas VRAM compactadas (`[importer_defaults]`) | VRAM do estilo Tripo 2,49 GB → 0,74 GB (735 MB), "mantendo 60 FPS" (VALE_VIVO_3D.md:125) |
| O3 | 26/09 | `027ced5` | Mata em blocos de 40 u com descarte fora da câmera, malha importada com LOD (sem fundir por `SurfaceTool`), mata só com espécies leves | quadro de ~10,5 M → ~2,4–3,6 M tri, 60 FPS, 1280×720, 1.800 árvores |
| O4 | 27/09 | `e38f9b4` | Altura do vértice calculada uma vez; pontos longe da costa pulam a medida | montagem ~24 s → ~8 s (CHANGELOG_3D.md:1209) |
| O5 | 27/09 22:42 | `6eaaef6` | Carregamento em etapas, cedendo um quadro a cada 80 ms; VSync desligado enquanto monta; tela de carregamento sobrevive à troca de cena | maior congelamento ~4,5 s → ~0,7 s |
| O6 | 27/09 | `e38f9b4` | Tela de carregamento no `inicio.tscn` em ~60 ms (antes, a tela do Godot) | ~60 ms até a primeira tela |
| O7 | 30/09 01:45 | `015c01c` | LOD por distância: `visibility_range_end` por camada (85/200/230/250/280 u), margem de 20 u, `lod_bias=0,65`, sem desvanecimento, suspenso nos mapas ortográficos | A/B 1024×576: perto 19,6 → 21,6 FPS (11,11 → 7,59 M tri); acima 28,8 → 32,8 (9,48 → 6,97 M); longe 12,6 → 20,3 (17,33 → 5,65 M) |
| O8 | 01/10 | `137af49`, `e308c8f` | Painel de FPS, triângulos, draws e VRAM no HUD (ferramenta, não otimização) | `prototype_hud.gd:759-766` |
| O9 | 02/10 09:49 | `f44f61c` | Grades de células na montagem (ruas, costa, troncos) no lugar de varrer todos os segmentos | montagem 25,2 s → 4,4–5,7 s, assinatura idêntica; menu 33,9 → 6,7 s; JOGAR 27,4 → 6,0 s (headless, só CPU) |
| O10 | 02/10 09:49 | `5d1f50a` | Tela de carregamento sem partículas e sem som | sem número |
| O11 | 05/10 | `80eb70b` | Copas distantes: copa de 64 tri por tronco até 1.200 u e modelo `_longe` das palmeiras até 600 u | +0,26–0,53 M tri e +120–400 draws; "o FPS não mudou além do ruído" (VALE_VIVO_3D.md:192-195) |
| O12 | 05/10 | `ce20572` (assets), `80eb70b` (uso) | Versões `_leve` (~2.500 faces) e `_longe` (~700 faces) das árvores; mata em manchas só com malhas ≤ 6.500 tri | média da árvore da mata 6.700 → ≤ 4.500 tri (`tests/mata_em_manchas.gd:15-16`) |
| O13 | 05/10 | `80eb70b` | Bichos: visibilidade a 80 u, física só perto; moradores "dormem" a 90 u; cardumes em MultiMesh com nado por shader | sem número |
| O14 | desde 26/09 | `7fc9681`, `027ced5` | Vegetação sem sombra (`SHADOW_CASTING_SETTING_OFF`) | sem número |

Observação sobre as faces do Tripo: o alvo da Malha Smart é em **quads** (faces), e o GLB tem cerca de 2× em triângulos. O lote LOD pediu 2.500 faces para o leve e 700 para o longe (`tools/tripo/lote_2026-10-05_lod.json`); contei nos GLBs 3.403–6.141 e 1.115–2.100 triângulos. Quem lê "2.500" como triângulos erra por 2×.

---

## Veredito: cada otimização ainda vale no HEAD? (item 2)

| # | Otimização | Veredito | Prova no HEAD (arquivo:linha) | Quem mexeu depois |
|---|---|---|---|---|
| O1 | Malha Smart, sem HD cru | **MANTIDA** | Maior GLB de árvore: 20.453 tri; nenhum GLB de 1,9 M | n/a |
| O2 | Textura VRAM compactada | **MANTIDA**, mas o total cresceu | `project.godot:78-84`; 872 de 954 `.import` em modo 2; 873 `.s3tc.ctex` = 1.039 MB (era 735 MB com 67 GLBs) | `f1c393c` criou; nunca editado |
| O3a | Blocos de 40 u + descarte fora da câmera | **MANTIDA** | `geo_region_renderer.gd:187` (`BLOCO_MATA`) e função `_multimesh_em_blocos` (`:2139-2197`); 6 chamadores: mata (`:1928`), sub-bosque (`:2033`), manguezal e ingá (`:2131,2133`), restinga e coqueiros (`:2281,2284`), paisagismo (`paisagismo_vale.gd:682,1033`), pé das árvores (`world_builder.gd:1903`) | só `80eb70b` (copas e registros) |
| O3b | Malha importada com LOD, sem fundir | **MANTIDA** | `catalogo_assets.gd:729-736`; 0 de 262 GLBs têm mais de um nó de malha, então nenhum cai na fusão que perde LOD (`:737-753`) | `a0638d7` e `80eb70b` mexeram na função, o ramo de LOD segue |
| O3c | "Mata só com espécies leves" (26/09) | **REGREDIU em 28/09 e foi recuperada em parte em 05/10** | 28/09 (`a0638d7`): `aroeira`, `jenipapeiro`, `piacava` entram na mata (`geo_region_renderer.gd:1872-1874`), e entram manguezal, ingá, restinga e sub-bosque, todos pesados. 05/10: a mata usa `_leve` (`:1899`, `especies_da_mata.gd:97-102`). **Orla, rio e restinga ficam pesados**: `:2045-2046`, `:2207`, `:2223` | `a0638d7`, `80eb70b` |
| O7a | Corte por distância por camada | **MANTIDA** | constantes `:191-197` idênticas às de `015c01c`; aplicadas em `:2159-2162`; o paisagismo usa as suas (90–230 u em `data/paisagismo/receitas.json`; cerca 110 u) | nenhuma alteração de valor |
| O7b | Mapa ortográfico suspende o corte | **MANTIDA** | `_atualizar_lod_da_camera` (`:2440-2453`), chamada todo quadro com saída rápida | `80eb70b` (copas) |
| O11 | Copa distante (64 tri até 1.200 u) | **MANTIDA** (nova) | ligada em `_multimesh_em_blocos` (`:2164-2176`); só para blocos de árvore com tronco registrado (mata, rio, restinga, coqueiros da orla); o paisagismo não ganha copa | n/a |
| O12 | Versões `_leve` | **MANTIDA MAS CONTORNADA EM PARTE** | usada na mata (`:1899`), no paisagismo (`receitas.json` só lista `_leve`) e nas copas (`copas_distantes.gd:220`); não usada em `:2045-2046` (mangue 18.079 tri, ingá 16.886), `:2207` (coqueiro 14.716) e `:2223` (castanhola 16.284, clúsia 10.954, piaçava 15.792) | `80eb70b` |
| O14 | Sem sombra na vegetação | **MANTIDA** | `geo_region_renderer.gd:2158`; teste da copa confere `cast_shadow == OFF` (`tests/lod_vegetacao.gd`) | nenhuma |
| O5 | Etapas de 80 ms | **MANTIDA MAS CONTORNADA EM PARTE** | `geo_region_renderer.gd:70`, `world_builder.gd:674-682`; mas `_build_paisagismo()` e `_build_bases_das_arvores()` (`world_builder.gd:790-791`), `_build_pecas`, `_build_marcos_de_fe`, `_build_pedras`, `_build_canoas` e `_build_luzes_epoca` (`:780-788`) rodam inteiros dentro de um quadro, sem `_pausar()`; e a população de moradores, bichos, fauna e interiores roda no `_ready` do vale depois do `pronto` (`prototype.gd:232-262,1131`) | `80eb70b` acrescentou os passos sem cessão |
| O9 | Grades de células na montagem | **MANTIDA** | `_grade_rotas`, `_grade_costa`, `_grade_troncos` (`:162-171`, usadas em `:629,1938,2395,2503,2598`) | n/a |
| O13 | Bichos e moradores com corte por distância | **MANTIDA** (novo) | `bichos_de_casa.gd:30` (`ALCANCE=80`), `animador_bicho.gd:229-242`, `npc.gd:74,1153-1164` (dorme a 90 u). Moradores não têm `visibility_range` na malha | n/a |
| O6 | Tela de carregamento em ~60 ms | **MANTIDA** (sem remedição) | `inicio.tscn` ainda é a cena principal | n/a |
| O4+O9 | "Vale em 5 s" | **SEM EVIDÊNCIA; provável regressão** | nunca remedido. Desde 02/10 entraram: mata em manchas (`_classes_da_mata`, `:1980-2009`), paisagismo (até 14.000 pés), mapa de solo com `Geometry2D`, 14 moradores, 8 casas, varais nas 19 casas, bichos, cardumes, copas, navegação a 0,25 u, e o catálogo foi de 83 para 264 entradas | `80eb70b` |

Nada foi **REMOVIDO**.

Pontos de CPU que o autor já tinha protegido, e que conferi como OK: `CatalogoAssets.tronco_da_malha` é cacheado por malha e faixa de tamanho (`catalogo_assets.gd:634-666`); a leitura de vértices é cacheada; `_distancia_da_rua` usa grade (`geo_region_renderer.gd:1938-1943`). A única migalha encontrada é que `_distancia_da_rua` recalcula `segmentos_de_rua` varrendo todas as ruas a cada chamada (`:1940-1942`), chamada 2× por árvore; não chega a sexta de segundo e não vale a correção hoje.

---

## Linha do tempo do desempenho medido (o 60 FPS e o resto)

| Data | Fonte | FPS | Triângulos | Resolução e condição | Estado do vale |
|---|---|---:|---:|---|---|
| 26/09 | VALE_VIVO_3D.md:119-126 | 60 (16,7 ms) | ~2,4–3,6 M | 1280×720; `tree_count` 1.800; 69 GLBs; sem minimapa, mar real, maré, tubarão, moradores novos nem bichos | `027ced5` |
| 30/09 | VALE_VIVO_3D.md:161-165 | 19,6 → 21,6 (perto), 28,8 → 32,8 (acima), 12,6 → 20,3 (longe) = 51 → 46 ms, 35 → 30 ms, 79 → 49 ms | 7,59 / 6,97 / 5,65 M com LOD; 11,11 / 9,48 / 17,33 M sem | 1024×576, VSync off, 9h, minimapa off, `game.set_process(false)` e jogador parado (os moradores, nós filhos, seguem rodando) | `015c01c`; `tree_count` 6.234; mata local de Saubara (pesada) já dentro |
| 05/10 | comentário em `copas_distantes.gd:12` | "perto de 20 FPS" (50 ms), sem condição declarada | 0,4 M das copas (64 tri) | não declarada | `80eb70b` |
| 05/10 | pedido do autor | ~15 FPS (66,7 ms) | n/d | 1920×1080 tela cheia, MSAA 2×, VSync, minimapa ligado, lógica ligada | HEAD |

Leitura: de 26/09 para 30/09 o quadro foi de 16,7 ms para 30–79 ms **em resolução menor, sem minimapa e com o jogador parado**. Entre as duas medições mudaram: `tree_count` ×3,46 (`a1466e3`, `e38f9b4`), mar real com leitura de tela e profundidade (`e38f9b4`), maré e tubarão (`df93e2f`), minimapa (existe em `df93e2f`), mata local pesada e sub-bosque (`a0638d7`), árvores cortáveis (`641f8fa`). Nenhuma foi medida isoladamente. Dos 15 FPS de hoje, uma parte vem do que já existia em 30/09; outra vem de 1080p, moradores, bichos, chão, céu.

Conta da densidade (estimativa): 2,4–3,6 M tri × (6.234 / 1.800 = 3,46) = **8,3–12,5 M tri**, que bate com os 11,11 M "sem LOD" medidos em 30/09. É consistência de ordem de grandeza, não prova.

---

## O que entrou depois do último 60 FPS (item 3)

"Carga" = diff do commit contra o primeiro pai (`git diff-tree M^1 M`), lendo o `size` dos ponteiros LFS. Nos merges, é o que a integração trouxe para a linha de level design. Os dois lados dos merges foram conferidos com `merges.py`.

### 26/09 a 03/10 (o que já estava quando se mediu 30/09 e quando se fechou a Build 8)

| Data | Commit | O que entrou | Carga adicionada | Risco |
|---|---|---|---|---|
| 26/09 20:12 | `a1466e3` | cobertura de mata estendida | `tree_count` 1.800 → 5.000 | **alto**: instâncias ×2,8 |
| 27/09 19:48 | `e38f9b4` | mar real da carta náutica (`agua_mar.gdshader` com `hint_screen_texture`+`hint_depth_texture`), mundo 16:9, montagem 3× mais rápida | `tree_count` 5.000 → 6.234; passes extras de tela da água | **alto**: ×3,46 acumulado nas árvores; cópia de tela e profundidade com MSAA |
| 28/09 18:27 | `df93e2f` (Build 6) | maré, tubarão, minimapa, franjas, rio com shader, 8 casas novas | +8 GLBs (330 MB total); minimapa `SubViewport` | **médio-alto**: segundo desenho do vale; nunca medido isolado |
| 28/09 19:25 | `a0638d7` | mata local de Saubara: mangue, ingá, piaçava, jenipapeiro, clúsia, castanhola, sub-bosque | +7 GLBs pesados (84 / 371 MB); sub-bosque de 7.442 tri ×~2.000 | **alto**: desfaz a premissa "mata só leve" |
| 30/09 01:45 | `015c01c` | LOD por distância (mitigação) | 0 GLB | baixo (reduz) |
| 03/10 19:24 | `641f8fa` | árvores se cortam e voltam em um ano | registro de instância por tronco | baixo |
| 03/10 | `4bd1ef7`, `ef4e110`, `f8970f1` | interiores (igreja, 2 casas), mobília | `comodo.gd` com luzes pontuais | baixo-médio |
| 03/10 23:20 | `faba1da` | boneco da mochila (`SubViewport` MSAA 4×, `UPDATE_DISABLED` até abrir) | 1 viewport dormente | baixo |
| 03/10 00:21 | `7f196af` | retratos 3D: 8 fotos (7 moradores + Pedro) em `SubViewport` MSAA 4× 256 px, 1,5 s depois do vale | 8 cargas de GLB + 8 desenhos | baixo (migalha pós-carga) |

### 04/10 a 05/10 (a lista pedida)

| Data | Commit | O que entrou | Carga adicionada | Risco |
|---|---|---|---|---|
| 04/10 13:17 | `14c1b47` | o jogo abre em **tela cheia** | `project.godot:67`: 1920×1080 em vez de 1280×720 | **alto**: 2,25× os pixels de toda medição anterior |
| 04/10 23:29 | `ce63253` | quinze construções viram composição editável | `composicao_vale.tscn` (120 nós), `ruas_referencia.tscn`; sem GLB novo | baixo-médio: mesmas casas, agora por cena |
| 05/10 04:01 | `702e1fb` | terreiro de terra, alicerce visível e objetos editáveis nas casas | +meshes por casa (`alicerce_construcao.gd`) | baixo-médio |
| 05/10 04:25 | `40c677b` | o jogo começa em cima do saveiro | +1 GLB (8,3 MB); `saveiro_vale.gd` | baixo |
| 05/10 05:21 | `8727f1c` | E nos moradores, tela escurece ao cumprir missão | só UI | baixo |
| 05/10 05:54 | `e6ebdc9`, `65ed375` | missões do 2D, portões de conquista | dados e UI | baixo |
| 05/10 06:20 a 07:11 | `060a17d`, `c3c07d5`, `1b19ffd`, `f069b6d` | ponte do rio grande, socorro, canteiro, rampa da igreja | `ponte_vale.gd` (189 linhas); sem GLB | baixo |
| 05/10 08:49 | `8dd9be8` | chapada do Seu Benedito | `luz_dourada.gd` (efeito de tela) | baixo |
| 05/10 09:22 | `ef77af1` | lapa e cabra | +1 GLB (2,7 MB); `lombada_vale.gd` (327 linhas) | baixo |
| 05/10 10:13 | `339b3a2` | jornada da fazenda | +3 GLBs (19,7 MB: casarão 17.319 tri 2K, portão 6.006, guarita 6.373); `fazenda_vale.gd` (388 linhas) | baixo-médio: casarão de 17 mil triângulos sem corte por distância |
| 05/10 12:07 | `ce20572` | moradores, bichos, peixes, casas e flora do Tripo; 10 texturas do chão (OpenAI) | **+156 GLBs / +498,8 MB** (árvores 57 / 168,9; construções 12 / 86,5; animais 31 / 76,8; personagens 14 / 73,8; adereços 16 / 38,8; peixes 17 / 35; itens 9 / 19) e +10 PNGs / 25,2 MB; GLBs totais 106 → 257 | **alto**: carga de disco, de VRAM e de catálogo |
| 05/10 12:07 | `80eb70b` | céu, chão de 8 camadas, mata em manchas, paisagismo, 14 moradores, bichos, cardumes, copas distantes, câmera sem salto (18.735 linhas, 110 arquivos) | `terreno.gdshader` (251 linhas), `ceu_vale.gdshader` (245), 10 shaders; 21 scripts com `_process`; paisagismo até 14.000 pés; 14 moradores novos; ~32 corpos de bicho; cardumes | **alto**: toda a fatia nova de CPU e GPU |
| 05/10 12:09 | `f67e86e` (merge) | traz a main de 05/10 | vs 1º pai: +4 GLBs / 22,4 MB (fazenda); vs 2º pai: +156 GLBs / 498,8 MB | médio |
| 05/10 12:52 | `97f138c` (merge) | retomada do HUD e melhorias do vale | vs 2º pai: +26 GLBs / 85,9 MB (móveis 15 / 34,2; construções 4 / 27,5; adereços 5 / 17,9; personagens 2 / 9,2), +10 JPG de cordéis | médio-baixo |
| 05/10 12:53 | `5250a20` | E fica com o Pedro na chegada | JSON e lógica | baixo |
| 05/10 12:56 | `e40f991` (merge) | traz o HUD, o nado e o impacto das ferramentas | +2 GLBs / 7,4 MB | baixo |
| 05/10 14:29 a 15:11 | `81575b7`, `580a0bc`, `10f3ed9`, `eb430e4` | HUD, machado, itens de mão, custo de ação | só lógica | baixo |

Outros merges "Traz a main ..." (`4064f77`, `15e14ce`, `f6e16a6`, `de6e854`, `b3d07be`, `56998bd`, `8da9671`, `8307074`, `84290c0`, `6c2c6fe`): integração de lógica e UI; a parte de GLBs deles (21 GLBs / 55,2 MB, os móveis e peças de casa) já está contada em `54bb808` e `97f138c`.

Novos arquivos com `_process` ou `_physics_process` desde a Build 8 (`66cacc1`): `animador_bicho`, `bando_de_chao`, `bicho_de_casa`, `bichos_de_casa`, `boneco_da_mochila`, `casa_do_jogador`, `cemiterio_vale`, `comodo`, `conquista_da_missao`, `fauna_vale`, `fazenda_vale`, `interiores`, `lavoura_vale`, `lombada_vale`, `marcos_da_fe`, `painel_personagens`, `ponte_vale`, `saveiro_vale`, `tecla_das_bancadas`, `tecla_dos_moradores`, `vestimenta_3d` (todos em `scripts/prototipo_3d/`). Ter `_process` não é custo por si: os de HUD e missão são baratos; os que importam são `npc.gd`, `bicho_de_casa.gd`, `bando_de_chao.gd`, `fauna_vale.gd`, `cardume.gd`.

---

## Algum commit afrouxou limites? (item 4)

Resposta curta: **nenhuma constante de LOD, bloco, sombra, MSAA ou importação foi afrouxada.** O que mudou foi a quantidade de coisas dentro dos mesmos limites.

| Parâmetro | Valor em 26/09 | Valor no HEAD | Quem mudou |
|---|---|---|---|
| `BLOCO_MATA`, `LOD_*`, `LOD_MARGEM`, `LOD_BIAS` | não existiam; criados em `027ced5` / `015c01c` | iguais | ninguém depois |
| `camera.far` | 2.800 | 2.800 | ninguém (desde `46f044c`) |
| `msaa_3d` | 1 (2×) | 1 | ninguém (desde 23/09) |
| `importer_defaults` | VRAM, sem alta qualidade, mipmaps | iguais | ninguém |
| Sombra do sol | 180 m, 4 cascatas | igual | só mudou de arquivo (`ceu_vale.gd`) |
| `cast_shadow` da vegetação | OFF | OFF | ninguém |
| `tree_count` | 1.800 | **6.234** | `a1466e3`, `e38f9b4` |
| `cell_size` mínimo entre árvores (`_units(12, 3,6)`), `coast_clearing`, `interest_clearing` | iguais | iguais | ninguém |
| Lista de espécies da mata | `["mata_alta","mata_larga","mata_alta","embauba","mata_larga"]` (leves) | + `aroeira`, `jenipapeiro`, `piacava` (`:1872-1874`) e, no Tripo, escolha por mancha com `_leve` | `a0638d7`, `80eb70b` |
| Resolução de jogo | janela 1280×720 | tela cheia 1920×1080 | `14c1b47` |
| Alcance visível da vegetação | até 280 u | até **1.200 u** (copas) e 600 u (modelo longe) | `80eb70b`: não afrouxa o corte; **estende** o que se desenha |
| Texturas | 1K para o pequeno, 2K para o destaque | 40 GLBs em 2K: 14 árvores pesadas, 23 construções | `ce20572` (construções novas em 2K) |

---

## Portões (item 5)

Pergunta: algum teste reprovaria uma regressão de FPS, triângulos, draws, VRAM ou tempo de carga? **Não.**

| Portão | O que cobra | O que NÃO cobra |
|---|---|---|
| `tests/lod_vegetacao.gd` | estrutura: `visibility_range_end==85`, `lod_bias<1`, sem fade, copa de 48–80 tri, copa entra onde a árvore sai, mapa ortográfico restaura | nenhum número de FPS, triângulos ou draws; não monta o vale |
| `tests/mata_em_manchas.gd:25-26` | cada malha da mata ≤ 6.500 tri; média ≤ 4.500 tri; > 3.000 troncos | só a mata. Orla, rio, restinga, sub-bosque e paisagismo ficam fora |
| `tests/paisagismo.gd:36-37,207-209` | ≤ 14.000 pés e ≤ 45 M tri **somados, "se todos aparecessem de uma vez"** | um teto de 45 M não protege nada: o alvo do quadro é ~3–6 M com corte. O teste imprime a linha `orçamento: N pés, X milhões de triângulos`, e ninguém a registrou em doc |
| `tests/hud_desempenho.gd` | o painel de FPS existe, abre, não cobre o minimapa | não mede nada |
| `tests/smoke_opening.gd:76-79,105-108` | o vale aparece em até **90 s de relógio** | o teto era 30 s; `80eb70b` o trocou por 3.000 quadros ("a leitura passa de 700 quadros, 734 medidos") e `339b3a2` o subiu para 90 s com o comentário "com a bateria cheia passa de 30 s". É teto de travamento, não de carga: afrouxou 3× e ninguém decidiu quanto o carregamento pode levar |
| `tests/tela_carregamento.gd:96-97` | 30 s de teto | é detector de travamento |
| `tools/prototipo_3d/testar.ps1:63` | `TetoSegundos=420` por portão (700 para `agua_rasa`) | detector de travamento, não orçamento. Existe o conceito de "régua" fora da bateria (`$REGUAS`, `:82`) com um único membro, `ordem_da_visita` |
| `DECISOES_PROTOTIPO_3D.md:361` | item da definição de pronto: "O desempenho foi medido no computador de referência" | continua `[ ]`, desmarcado |

Conclusão: a regressão de 26/09 para hoje entrou sem alarme.

### Portão mínimo proposto (reaproveita `medir_carregamento.gd` e `medir_lod.gd`)

Três camadas, da mais barata à mais fiel. Os tetos devem sair da **medição do coordenador depois das correções de hoje, mais 10%**; não proponho número absoluto porque nenhum medido hoje existe.

1. **`tests/orcamento_do_vale.gd` (headless, entra na bateria, ~3 h).** Monta a região como `tests/mata_em_manchas.gd` já faz (`_montar`), percorre os `MultiMeshInstance3D` filhos e, para 5 pontos de câmera fixos (píer, praça, perto da mata, sobre a mata, mata ao longe), soma `instâncias dentro de [begin,end] × triângulos do LOD 0` (método de contagem em `tests/paisagismo.gd:186-207`). Reprova se a soma, o número de `MultiMeshInstance3D` ou o de instâncias passar do teto. Isso pega "tree_count dobrou", "espécie pesada entrou na orla" e "corte afrouxado", que são as regressões desta história, sem GPU.
2. **Carga (headless, régua ou portão, ~1 h).** `tools/prototipo_3d/medir_carregamento.gd --cena=abertura,vale --saida=...`; reprova se `total_ms` passar de 1,5× o valor guardado do dia ou se houver quadro lento (> 250 ms, `QUADRO_LENTO_MS`) acima do guardado. Guardar o JSON em `data/` ou `docs/projeto/DESEMPENHO.md`. Devolver o teto de relógio do `smoke_opening`.
3. **GPU (fora da bateria, como `ordem_da_visita`, ~2 h).** Adaptar `medir_lod.gd`: 1920×1080 tela cheia, **minimapa e lógica ligados**, hora de início do jogo, 4 vistas, ≥ 300 quadros, mediana. Registrar FPS, `RENDER_TOTAL_PRIMITIVES_IN_FRAME`, `RENDER_TOTAL_DRAW_CALLS_IN_FRAME`, `RENDER_VIDEO_MEM_USED` (as mesmas chamadas de `prototype_hud.gd:764-766`). Reprova com FPS 10% abaixo do guardado ou triângulos, draws ou VRAM 10% acima.

---

## Builds anteriores (item 6)

| Build | Data | Commit | Evidência | Desempenho declarado |
|---|---|---|---|---|
| #5 | 26/09 (tarde) | `1f7bec5`, `f1c393c`, `027ced5` | CHANGELOG_3D.md:1283 | "60 FPS" (VRAM 0,74 GB; mata 2,4–3,6 M tri) |
| #6 | 28/09 | `df93e2f` | CHANGELOG_3D.md:1114; zip `MythsValley3D-v0.1.0-dev-build6-windows.zip` (359.370.943 B, 03/10 00:33) | nenhum número de FPS; 77 GLBs / 330 MB |
| #7 | 03/10 18:02 | `fd89308`, `2c07382` | CHANGELOG_3D.md:880; zip build7 (359.381.312 B, 03/10 18:03); entrada em `historico_3d.json:105-139` | "Montagem do vale em cinco segundos" (linha 114 do JSON); 84 GLBs / 371 MB |
| #8 | 03/10 22:15 | `66cacc1` | CHANGELOG_3D.md:849; `historico_3d.json:3` (`build_numero: 8`); `build/windows/MythsValley3D.exe` (540.764.864 B, 03/10 22:01) | só créditos e histórico em 3 idiomas; 84 GLBs / 371 MB |

O zip é só o `.exe` com o PCK embutido (`unzip -l`: 1 arquivo, 540.764.144 B); zip/exe = 0,665. O `historico_3d.json` não tem entrada de 05/10; a próxima build seria a #9 e hoje não há texto de histórico para ela.

**Estimativa do tamanho da próxima build (conta):** média de textura VRAM por GLB = 1.039,2 MB / 262 = 3,97 MB; média de `.scn` = 88,1 / 262 = 0,34 MB; acréscimo desde a Build 8 = (262 − 84) × (3,97 + 0,34) = 178 × 4,31 ≈ 767 MB. Executável ≈ 515,7 + 767 ≈ **1.283 MiB (~1,25 GiB)**; zip ≈ 0,665 × 1.283 ≈ 850 MiB. Sanidade da conta: aplicada às 84 GLBs da Build 8 dá 84 × 4,31 ≈ 362 MB de conteúdo de modelo, coerente com um exe de 515 MiB (motor, áudio, UI e o resto fazem a diferença). É estimativa; o export real decide. Pesa na decisão porque "o download estável do site" e a hospedagem compartilhada passam a carregar um arquivo 2,4× maior.

---

## Achados

### HIS-01: O "60 FPS" registrado é velho e não vale para o jogo de hoje; a queda começou entre 26 e 30/09

- **Evidência.** O 60 FPS é de 26/09 (`027ced5`), 1280×720, `tree_count` 1.800, 69 GLBs, sem minimapa, mar real, bichos nem os 14 moradores novos (VALE_VIVO_3D.md:119-126; `git show 027ced5:data/mapas/bom_jesus_dos_pobres_cenario.json`). A medição de 30/09 já dava 12,6–32,8 FPS (VALE_VIVO_3D.md:161-165). O código de 05/10 diz "o vale já anda perto de 20 FPS" (`copas_distantes.gd:12`). A frase do CHANGELOG ("mantendo 60 FPS", `:1309,1319`) continua lida como estado atual. O `medir_lod.gd` fixa 1024×576, VSync off, 9h, minimapa desligado (`:18-19,34,41`) e a lógica parada (`player.set_physics_process(false)` e `game.set_process(false)`, `:30-31`), então todo número histórico exclui o minimapa, os moradores, os bichos e o CPU de jogo.
- **Mecanismo.** Não é um mecanismo, é de método: sem medição repetível na condição real (1080p, tela cheia, minimapa, lógica, hora de início), "voltar aos 60" não tem alvo.
- **Impacto.** Alto para a decisão (varios); a leitura "a integração de 04–05/10 quebrou" é falsa em parte.
- **Confiança.** Alta (fatos de repositório).
- **Correção.** Nenhuma de código. Definir hoje a linha de base na condição real e guardá-la (ver portão mínimo). Corrigir `ASSETS_TRIPO.md:17` (diz 1080p) para não contradizer `VALE_VIVO_3D.md:119`.
- **Esforço.** 1 h de medição do coordenador.
- **Risco.** Nenhum.
- **Como medir.** Vistas do `medir_lod.gd` (perto, acima, longe) em 1920×1080 tela cheia, minimapa ligado, lógica ligada, VSync off; registrar FPS, tri, draws, VRAM.

### HIS-02: A densidade da mata subiu 3,46× logo depois da medição de 60 FPS

- **Evidência.** `tree_count`: 1.800 em `027ced5`/`f1c393c` (26/09), 5.000 em `a1466e3` (26/09 20:12), 6.234 em `e38f9b4` (27/09) e no HEAD (`data/mapas/bom_jesus_dos_pobres_cenario.json:2723`). A mata é o único consumidor (`geo_region_renderer.gd:1818`).
- **Mecanismo.** Cada árvore é uma instância de MultiMesh de 3,4–6 mil triângulos (mata, `_leve`) ou 11–20 mil (orla e rio). O corte a 280 u e o LOD de malha reduzem, mas o número de blocos no cone de visão, de instâncias por bloco e de triângulos em LOD 0 perto do jogador escala com a densidade. As instâncias de sub-bosque (1 a cada 3 árvores, `:2020`) e os decalques acompanham.
- **Impacto.** Alto (fps). Estimativa: 2,4–3,6 M × 3,46 = 8,3–12,5 M tri de partida, contra os 11,11 M "sem LOD" de 30/09.
- **Confiança.** Alta no fato; média no peso (só o A/B dá).
- **Correção.** Não baixar `tree_count` hoje: `rng` é compartilhado, e o sorteio de sub-bosque, rio e orla (`:1930-1932`), o sobrevoo planejado offline (`data/sobrevoo_menu.json`), a malha de navegação e o paisagismo dependem da posição exata de cada árvore (`geo_region_renderer.gd:1875-1878` diz isso). Alternativa de hoje, sem mexer em sorteio: encurtar `LOD_MATA` (`:195`) de 280 para um valor testado (por exemplo 200) e deixar a copa distante cobrir a serra, como ela já faz; é a constante que decide quantos blocos de árvore entram. O corte de `visibility_range_end` não altera `_tree_trunks`.
- **Esforço.** 10 min para a constante; 1 h para o A/B visual.
- **Risco.** A árvore some mais perto: a troca copa-árvore fica visível. `tests/lod_vegetacao.gd` passa (confere o valor passado, não 280). A copa distante entra em `visibility_range_begin` = fim da camada (`copas_distantes.gd`), então acompanha sozinha. O sobrevoo contorna as árvores a 5 m: não é afetado pelo corte visual.
- **Como medir.** `medir_lod.gd` com `LOD_MATA` = 280, 220, 160; comparar triângulos e FPS nas três vistas.

### HIS-03: Orla, manguezal, ingá e restinga ainda usam as malhas pesadas (sem `_leve`)

- **Evidência.** `_build_forest` usa `EspeciesDaMata.malha(...)` (`geo_region_renderer.gd:1899`), que escolhe `_leve`. Mas `_malha_da_especie("mangue")` e `("ingazeiro")` (`:2045-2046`), `("coqueiro")` (`:2207`) e `_malha_da_especie(local)` da restinga (`:2223`, locais `castanhola`, `clusia`, `piacava`) pedem a malha cheia. Triângulos contados: mangue 18.079 (leve 4.790), ingazeiro 16.886 (5.426), coqueiro 14.716 (5.214), castanhola 16.284 (5.308), piaçava 15.792 (5.894), clúsia 10.954 (5.165). O gate `mata_em_manchas` só olha a mata (`tests/mata_em_manchas.gd:120-132`). O doc diz 524 troncos nesse grupo (VALE_VIVO_3D.md:189).
- **Mecanismo.** Essas árvores ficam na beira do mar e do rio, onde o jogador começa (píer) e passa mais tempo. Cada instância em LOD 0 custa 3× a da mata. Com `LOD_BIAS=0,65` e os LODs gerados no import (`generate_lods=true`) o custo cai com a distância, mas o LOD 0 perto é o que o Tripo fez com 20 mil.
- **Impacto.** Médio a alto (fps), concentrado no começo do jogo e na orla.
- **Confiança.** Média: o mecanismo é certo, o peso depende de quantas dessas árvores estão no cone (524 é o total do mundo).
- **Correção.** Em `:2045`, `:2046` e `:2223`, trocar o nome por `EspeciesDaMata.malha(nome)`. As chaves `_leve` já existem no catálogo (`catalogo_assets.gd:324-340`) e `copas_distantes.gd:220` já prefere `_leve`. Começar por mangue, ingá e restinga. **Deixar o coqueiro para depois do teste**: `CoqueiroCortado.referencias_tronco(built.mesh)` (`:2209`) e o corte (`tests/corte_das_arvores.gd`, `tests/colisao_das_arvores.gd`) dependem da topologia da malha do tronco; `tests/paisagismo.gd:38` proíbe `coqueiro_leve`.
- **Esforço.** 30 min mais a conferência visual.
- **Risco.** Médio: a silhueta muda; a espécie do tronco (`"especie"`) deve continuar a de sempre, que é o que `_malha_da_especie` já devolve. Portões a rodar: `lod_vegetacao`, `colisao_das_arvores`, `corte_das_arvores`, `colisoes_do_vale`, `mata_em_manchas`, `paisagismo`.
- **Como medir.** Esconder os blocos "Manguezal", "Ingazeiros do rio", "Restinga da orla: *", "Coqueiros da orla" (`visible=false`, filhos do `_region`) e ver quanto o quadro cai no píer; depois trocar a malha e repetir.

### HIS-04: O sub-bosque pesa 7.442 triângulos por tufo, mais que a árvore leve, e passou despercebido

- **Evidência.** `sub_bosque_tripo.glb` = 7.442 tri (contado). Planta-se um tufo a cada 3 árvores (`geo_region_renderer.gd:2020`), isto é, cerca de 6.234 / 3 ≈ 2.000 antes dos filtros de rua, rio e clareira (estimativa). Entrou em 28/09 (`a0638d7`). Corte a 85 u (`:191`). O gate de 4.500 tri de média da mata não o inclui.
- **Mecanismo.** Um tufo de 7,4 mil tri cobre pouca área, mas está em todo lugar perto do jogador na mata; o conjunto dentro de 85 u pode passar do que as árvores `_leve` custam, porque a árvore leve tem 3,4–6 mil e o tufo é mais denso em número.
- **Impacto.** Médio (fps, mata). Estimativa de ordem de grandeza: 120 tufos no cone × 7,4 mil ≈ 0,9 M tri em LOD 0 (suposição: 0,011 tufo por u² na mata e ~11 mil u² de cone; não medido).
- **Confiança.** Baixa a média.
- **Correção.** Hoje: reduzir `LOD_SUB_BOSQUE` (`:191`) de 85 para um valor menor testado (55, por exemplo). Estrutural: gerar `sub_bosque_leve` (lote no Tripo, ~1.500 faces) e usar `EspeciesDaMata.malha("sub_bosque")`. **Não** mudar o passo `range(0, size, 3)`: ele altera a quantidade de números tirados de `rng` antes do rio e da orla (`:1931-1932`), o que desloca tudo o que vem depois.
- **Esforço.** 10 min (constante); 2–3 h com o novo GLB.
- **Risco.** Baixo para a constante (o doc `VALE_VIVO_3D.md:141-142` já chama o sub-bosque de "some primeiro"); a mata parece mais "limpa" perto. O minimapa a 100 u de altura já não mostra o sub-bosque (VALE_VIVO_3D.md:153).
- **Como medir.** Esconder o nó "Sub-bosque *" e ver o delta de triângulos e FPS na vista "perto da mata".

### HIS-05: As condições mudaram: 1080p em tela cheia, minimapa e lógica ligados, onde todas as medições foram feitas pequenas e sem eles

- **Evidência.** `project.godot:67` (`window/size/mode=3`), commit `14c1b47` de 04/10 13:17: "O jogo abre em tela cheia". 1920×1080 = 2.073.600 px; 720p = 921.600; 576p = 589.824 (razões 2,25× e 3,52×). `window/stretch/mode="canvas_items"` (`project.godot:70`) não reduz o 3D: ele renderiza na resolução da janela. MSAA 2× (`:97`) → ~4,15 M de amostras de cor e profundidade. VSync padrão. As medições antigas: 1280×720 (26/09), 1024×576 com VSync off (30/09).
- **Mecanismo.** Fill-rate: o custo de fragmento (terreno com 8 camadas, água com leitura de tela, céu, folhagem com recorte) escala com os pixels. Geometria e CPU não escalam. Como em 30/09 já se estava abaixo de 33 FPS a 576p, onde o fragmento é barato, uma parte grande do problema é geometria e CPU, e o 1080p soma por cima. Só a medição separa as duas coisas.
- **Impacto.** Alto (fps), magnitude desconhecida.
- **Confiança.** Alta nas condições; magnitude por medir.
- **Correção.** Teste e, se confirmar, configuração: `rendering/scaling_3d/mode` = FSR 1.0 e `scale` = 0,75 em `project.godot` `[rendering]` (reduz 44% dos pixels de 3D, o HUD continua nítido); ou expor "Qualidade 3D" em AJUSTAR chamando `get_viewport().scaling_3d_scale`. Alternativa: MSAA desligado ou FXAA (`msaa_3d=0`).
- **Esforço.** 10 min no `project.godot`; 2 h para expor em AJUSTAR.
- **Risco.** FSR 1.0 suaviza a imagem; o MSAA não age sobre a escala interna do mesmo jeito. Não há portão que meça imagem; `tests/tela.gd` cobre F11 e o modo de janela, não escala 3D.
- **Como medir.** Mesmas vistas: (a) 1920×1080; (b) 1280×720 em janela; (c) 1920×1080 com `scaling_3d_scale=0,75`; (d) 1920×1080 sem MSAA. Se (b) tiver FPS ≈ 2× o de (a), o jogo é limitado por pixels; se for igual, é geometria ou CPU.

### HIS-06: O minimapa desenha o vale uma segunda vez a cada quadro, e nunca entrou numa medição

- **Evidência.** `minimapa.gd:94-99,144`: `SubViewport` de 176 px, `own_world_3d=false`, `render_target_update_mode = UPDATE_ALWAYS` enquanto visível; câmera ortográfica a 100 u de altura, `far=400` (`:27,104`). A preferência padrão é "Mostrar" (`painel_ajustes.gd:261`). `medir_lod.gd:41` o desliga (`render_target_update_mode = UPDATE_DISABLED`) em todas as medições A/B.
- **Mecanismo.** No Godot 4, cada viewport 3D ativo faz a própria passada de culling, a própria lista de draws e, para a luz direcional com sombra, a própria passada de sombra. A janela é pequena (55 u de lado), mas o fixo por viewport (cena inteira, sol com 4 cascatas, ambiente duplicado) não é pequeno. Os blocos de mata e o chão dentro da janela são desenhados de novo.
- **Impacto.** Médio (fps), por hipótese. Desde ≤ 28/09.
- **Confiança.** Média no mecanismo, baixa no tamanho.
- **Correção.** Sem código: AJUSTAR → Minimapa → Ocultar (existe). Se pesar, em `minimapa.gd:144` trocar `UPDATE_ALWAYS` por `UPDATE_ONCE` pedido por um timer de 0,2 s (5 Hz), ou o padrão para "Ocultar" (`painel_ajustes.gd:261`: `true` → `false`).
- **Esforço.** 5 min (padrão); 30 min (5 Hz).
- **Risco.** Médio-baixo: o minimapa é uma bússola de movimento; a 5 Hz o jogador gira e o mapa atrasa. `tests/minimapa.gd` e `tests/hud_desempenho.gd` tocam no minimapa: rodar os dois.
- **Como medir.** AJUSTAR → Minimapa → Ocultar, mesma vista, e comparar draws e FPS.

### HIS-07: A água lê a tela e a profundidade (27/09) com MSAA 2× a 1080p

- **Evidência.** `assets/prototipo_3d/mar/agua_mar.gdshader:14-15` (`hint_screen_texture` com `filter_linear_mipmap` e `hint_depth_texture`), introduzido em `e38f9b4` (27/09), um dia depois dos 60 FPS.
- **Mecanismo.** No Forward+, material que lê a tela força uma cópia do buffer de cor para uma textura (com resolução do MSAA e geração de mipmaps, por causa do filtro `mipmap`) antes da passada transparente, e uma cópia da profundidade. A cópia é de tela inteira, a cada quadro, enquanto houver água visível; a água cobre grande parte da tela perto da orla. A água é transparente: o fragmento caro roda sobre grandes áreas.
- **Impacto.** Médio (fps), por hipótese; maior na orla e no píer.
- **Confiança.** Baixa a média.
- **Correção.** Só depois do A/B. Opções: trocar `filter_linear_mipmap` por `filter_linear` (sem mipmaps da cópia), ou fazer a refração com uma tinta fixa e usar a profundidade só para a espuma, ou deixar o mar de fora do enquadramento (`far` na água) sem a cópia.
- **Esforço.** 1–3 h de shader.
- **Risco.** Aparência da água (é uma das marcas do jogo); `tests/ceu_horizonte.gd` não cobre a água; verificar `fotografar_chao.gd` e capturas.
- **Como medir.** Esconder o nó do mar e comparar; depois trocar o filtro de `tela`.

### HIS-08: O chão de 8 camadas pesa em todo pixel do terreno (05/10)

- **Evidência.** `terreno.gdshader:113-250`: para cada fragmento, 5 leituras de `sampler2DArray` (`:131-135`), até 8 `textureGrad` anisotrópicos (`:158-216`; grama sempre, mais 1 amostra extra entre 30 e 80 u, `:159-165`), avaliações de ruído (`ruido2` ×2 e `ruido` ×2–3, `:121-123,240-243`), `pow(...,4)` por camada ativa. Em 26/09 o terreno tinha uma textura. Entrou em `ce20572` + `80eb70b`.
- **Mecanismo.** O terreno é o que mais cobre a tela. O custo por pixel é fixo e se multiplica pelos 2 M de pixels do 1080p (e por mais do que isso no MSAA, porque o fragmento roda 1× por pixel mas a cobertura é 2×). Camadas com `if (w > 0.02)` só pagam onde estão, mas a grama paga sempre.
- **Impacto.** Médio a alto (fps) se o jogo for limitado por pixels; nulo se for por geometria.
- **Confiança.** Baixa: sem medição.
- **Correção.** Só depois do A/B: pular camadas secundárias e a segunda amostra além de um raio; usar `texture` com mipmap em vez de `textureGrad` onde as derivadas não precisam de controle; baixar `ladrilho_*` não ajuda.
- **Esforço.** 2–4 h de shader.
- **Risco.** Aparência do solo; `tests/mapa_de_solo.gd` cobre o mapa de solo, não o shader.
- **Como medir.** Trocar o material do terreno por um `StandardMaterial3D` verde; ou `solo_ativo=false` (pula as 5 leituras do array) e ver o quanto cai.

### HIS-09: O céu é recalculado em tempo real, com radiância de 256, desde 05/10

- **Evidência.** `ceu_vale.gd:74-75`: `ceu.process_mode = Sky.PROCESS_MODE_REALTIME` e `radiance_size = RADIANCE_SIZE_256`; antes, `ProceduralSkyMaterial` (`world_builder.gd:569` em `66cacc1`). O shader tem 245 linhas e várias leituras de ruído (`ceu_vale.gdshader:132-149`). `tests/ceu_horizonte.gd:85` **exige** `REALTIME`.
- **Mecanismo.** Em tempo real, o Godot redesenha o cubemap de radiância (6 faces de 256², com filtragem das mips) todo quadro, além de desenhar o céu na tela. Com `ambient_light_source=COLOR` (`ceu_vale.gd:79`) a radiância só serve para reflexos (água, superfícies lisas), que quase não mudam entre quadros.
- **Impacto.** Baixo a médio (fps), por hipótese.
- **Confiança.** Baixa.
- **Correção.** Uma linha em `ceu_vale.gd:74`: `PROCESS_MODE_INCREMENTAL` ou `QUALITY`; e/ou `RADIANCE_SIZE_64`. Exige mudar `tests/ceu_horizonte.gd:85` junto.
- **Esforço.** 5 min mais o teste.
- **Risco.** Baixo: reflexo das nuvens atrasa; o portão precisa ser editado com consciência (ele foi escrito para esta decisão).
- **Como medir.** Alternar o modo e ler o delta de FPS na vista "acima".

### HIS-10: A população nova (22 moradores, ~32 corpos de bicho, cardumes) soma CPU e geometria, e só os bichos têm corte por distância

- **Evidência.** Moradores: 7 → 22 (`data/npcs_3d.json`), cada um com 10.302–15.119 tri, esqueleto e até 13 clipes (contado nos GLBs). Bichos e bandos em `bichos_de_casa.gd` (corpos de quatro patas e bandos). 21 arquivos novos com `_process`. `npc.gd:1153-1164` "dorme" o animador a mais de 90 u; mas a malha do morador não tem `visibility_range`. Os bichos somem a 80 u (`animador_bicho.gd:229-242`, com `VISIBILITY_RANGE_FADE_SELF`). Cardumes em MultiMesh com nado por shader, `visibility_range_end` próprio (`cardume.gd:762`).
- **Mecanismo.** 22 moradores × ~11–15 mil triângulos = cerca de 250 mil triângulos (conta) com esqueleto, dentro do cone, e cada um entra também nas 4 cascatas da sombra do sol (180 m); a CPU paga `_process`/`_physics_process` e a caminhada por malha de navegação. Isso é pequeno ao lado de milhões de triângulos de mata, mas é o que pesa quando o jogador está na praça.
- **Impacto.** Médio (fps e travadas na praça).
- **Confiança.** Média.
- **Correção.** Hoje: nada; medir primeiro. Estrutural: `visibility_range_end` nos moradores (o mesmo de `VISTA=70`), corte de sombra para bicho pequeno (`cast_shadow` OFF abaixo de uma altura), LOD de personagem.
- **Esforço.** 1–2 h.
- **Risco.** Médio: moradores somem ao longe; o Pedro e os que a missão persegue não podem sumir.
- **Como medir.** `get_tree().call_group("moradores","set_visible",false)`, o mesmo com "bichos_de_casa", "bandos_de_chao" e "cardumes"; e `process_mode = DISABLED` para separar CPU de GPU.

### HIS-11: O carregamento nunca foi remedido depois de 02/10, e há trabalho síncrono novo antes e depois do "pronto"

- **Evidência.** Última medição: 4,4–5,7 s de montagem, 6,7 s até o menu, 6,0 s até o vale (headless, só CPU, `f44f61c`). Depois entraram: `_build_paisagismo()` e `_build_bases_das_arvores()` (`world_builder.gd:790-791`) sem `_pausar()`; `_classes_da_mata` (`geo_region_renderer.gd:1980-2009`); mapa de solo (`mapa_de_solo.gd`); catálogo de 83 → 264 entradas, carregadas por `load(path)` síncrono na thread principal (`catalogo_assets.gd:392`); só o `.tscn` do vale usa leitura em segundo plano (`tela_carregamento.gd:454`). Depois do `world.pronto`, o `_ready` do vale ainda monta interiores (`await interiores.configurar`), navegação, tubarão, fauna, bichos, queda, casa, lavoura, pesca (`prototype.gd:232-262,1131`), e o estúdio de retratos pede 8 fotos 1,5 s depois (`:1024-1030`). `smoke_opening` já viu a leitura passar de 700 quadros (734, `80eb70b`) e o teto de 30 s subiu para 90 s porque, com a bateria cheia, o vale passa de 30 s (`339b3a2`; é carga com a CPU disputada por vários portões, não o tempo do jogador). `medir_carregamento.gd` tem a opção `--precarregar=1` (lê todos os GLBs do catálogo em threads) que nunca foi decidida em doc.
- **Mecanismo.** `load()` de GLB importado lê `.scn` + `.ctex` e faz o upload ao primeiro desenho; fazer isso para dezenas de modelos no mesmo quadro congela a tela; o "congelamento máximo de 0,7 s" (27/09) foi medido com 84 GLBs e antes de todo esse trabalho. A parte pós-`pronto` acontece sob a cortina que se desfaz em 0,35 s (`tela_carregamento.gd:509-511`).
- **Impacto.** Alto para "carregamento" e médio para "travadas" (carregamento, travadas).
- **Confiança.** Média: as fontes do custo são certas, a duração não foi medida.
- **Correção.** Medir primeiro: `tools/prototipo_3d/medir_carregamento.gd --cena=abertura,vale` com janela (sem `--headless`) e com `--precarregar=1`. Se ajudar, hoje: ligar o pré-carregamento em threads dos GLBs do catálogo durante a leitura do `.tscn` (a `FATIA_ARQUIVOS`, `:449`). Estrutural: `_pausar()` dentro dos laços de plantio do paisagismo e dos pés; mover a população para etapas com barra.
- **Esforço.** 1 h medir; 3–6 h o pré-carregamento; 1 dia a divisão em etapas.
- **Risco.** O pré-carregamento aumenta o uso de memória no carregamento; o cache de `CatalogoAssets` (`_cenas`) já guarda a `PackedScene`. Portões: `tela_carregamento`, `smoke_opening`, `mapa_fluxo`, `salvamento`.
- **Como medir.** `medir_carregamento.gd` já separa "terra: malha e colisão", "vila e áreas do KML", "sorteio dos pontos", "malhas por espécie", "sub-bosque, rio e orla" (`:71-74`); estender os cortes para paisagismo e população.

### HIS-12: O pacote cresce para ~1,25 GiB e as texturas compactadas somam 1,04 GB

- **Evidência.** Contado: 873 `.s3tc.ctex` = 1.039,2 MB; 122 deles (2K) = 432 MB; 262 GLBs = 946,6 MB no repositório; catálogo 264 entradas. Cada versão de árvore (`_tripo`, `_leve`, `_longe`) traz as próprias três texturas: a mesma espécie ocupa até 3 jogos de textura. Estimativa do executável: ~1.283 MiB (conta na seção "Builds anteriores").
- **Mecanismo.** Memória de vídeo não é o gargalo numa placa de 6 GB, mas o PCK maior alonga a leitura inicial, a verificação do antivírus no primeiro uso, o download, e a cópia `.old` do atualizador (`atualizacao.gd`). O custo é de carregamento e distribuição.
- **Impacto.** Médio (carregamento, memória).
- **Confiança.** Média (tamanho estimado).
- **Correção.** Hoje: nenhuma obrigatória. Se o tamanho preocupar: rebaixar para 1K as 23 construções de 2K que não sejam de destaque (`tools/tripo/...`, reexportar) ou reimportar com `compress/mode` BPTC só nas de destaque; e mover `_longe` e `_leve` para texturas compartilhadas. Estrutural.
- **Esforço.** 1–2 dias (reexportar no Tripo).
- **Risco.** Qualidade visual das casas; regra de arte de `ASSETS_TRIPO.md:140-152` diz 2K para construção.
- **Como medir.** Exportar uma vez e ler o tamanho; ler `RENDER_VIDEO_MEM_USED` no painel de FPS no vale e na abertura.

### HIS-13: Não há portão de desempenho, e o único teto de tempo de carga foi trocado por contagem de quadros

- **Evidência.** Ver a seção "Portões". Nenhum teste lê `RENDER_*`/`TIME_FPS`/`VIDEO_MEM`. O orçamento de 45 M de triângulos do paisagismo é o "tudo ao mesmo tempo" (`tests/paisagismo.gd:37,207-209`). O teto de espera do vale em `smoke_opening` foi de 30 s para 3.000 quadros (`80eb70b`) e depois para 90 s (`339b3a2`). `DECISOES_PROTOTIPO_3D.md:361` segue desmarcado.
- **Mecanismo.** Sem tetos, cada integração sozinha parecia pequena e a soma não reprovou nada.
- **Impacto.** Alto (processo).
- **Confiança.** Alta.
- **Correção.** O portão em três camadas da seção "Portão mínimo proposto". Antes de tudo, o coordenador deve rodar `tests/paisagismo.gd` uma vez (headless) e anotar a linha `orçamento: N pés, X milhões de triângulos`.
- **Esforço.** ~6 h no total, depois da entrega de hoje.
- **Risco.** Portão de GPU flutua com a máquina; por isso a camada 3 fica fora da bateria e compara com a linha guardada da mesma máquina.
- **Como medir.** O próprio portão.

---

## O que está OK (para ninguém re-investigar)

- **Blocos de 40 u, descarte fora da câmera, LOD de malha, corte por distância:** presentes, ligados e com as mesmas constantes de 30/09 (`geo_region_renderer.gd:187-197,2139-2197`). O paisagismo também passa por `_multimesh_em_blocos`.
- **LOD de malha dos GLBs:** `generate_lods=true` e `create_shadow_meshes=true` em 262 de 262 `.import`; todos os GLBs são de um nó de malha só, então a fusão por `SurfaceTool` que perde LOD não é usada.
- **Compressão VRAM:** `project.godot:78-84`; as 82 texturas sem compressão são de interface, cordéis, cursores e 4 materiais de casa (≈ 24 MB no total), conforme a regra do `AGENTS.md`.
- **Sem sombra na vegetação:** `:2158`. A copa distante também não faz sombra (conferido por `tests/lod_vegetacao.gd`).
- **Pé das árvores:** só nas nomeadas e nas da areia, sem LOD de propósito (`world_builder.gd:1875-1893`); não é custo.
- **Cálculos de CPU da mata já com cache e grade:** `tronco_da_malha`, vértices por malha, `_distancia_da_rua`.
- **Tela de carregamento:** passa o orçamento de 80 ms, VSync desligado durante a montagem (`tela_carregamento.gd:487-506`), sem partículas nem som.
- **Retratos 3D:** 8 fotos, uma por quadro, 1,5 s depois do vale (`prototype.gd:1024-1030`); `SubViewport` desmontado em seguida. Migalha.
- **Boneco da mochila:** `render_target_update_mode = UPDATE_DISABLED` (`boneco_da_mochila.gd:108`). Não custa quadro até abrir.
- **Luzes de 1887:** `shadow_enabled=false` nas pontuais (`luzes_epoca.gd:143`); só o sol projeta sombra (`ceu_vale.gd:91`), a lua não (`:98`).
- **Animais pequenos e peixes:** cortam a 80 u; cardumes em MultiMesh.
- **Terreno de 8 camadas:** é um shader só, sem cópia de tela (`terreno.gdshader` não usa `hint_screen_texture`).

---

## Dúvidas para medição A/B

Condição-base para todas: 1920×1080 tela cheia, minimapa ligado, hora de início do jogo (7h) e 9h (a do `medir_lod.gd`), VSync desligado para ler o FPS real (`DisplayServer.window_set_vsync_mode(VSYNC_DISABLED)`), 300 quadros por tomada, ordem ABBA como em `medir_lod.gd:71`. Ler `Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME`, `RENDER_TOTAL_DRAW_CALLS_IN_FRAME`, `RENDER_VIDEO_MEM_USED` (como `prototype_hud.gd:764-766`) e, se possível, o tempo de GPU do visual profiler. Vistas: píer (início), praça, perto da mata, sobre a mata, mata ao longe. Com VSync ligado o FPS cai em degraus (60/30/20/15): 15 FPS pode ser 12–17 reais.

| # | Pergunta | O que ligar ou desligar, e onde | O que a resposta decide |
|---|---|---|---|
| D0 | Quantos pés o paisagismo planta e quantos triângulos somam? | Rodar `tests/paisagismo.gd` (headless; não usa GPU) e ler `zonas: N, pés: N` e `orçamento: N pés, X milhões` | tamanho real da fatia de 05/10 |
| D1 | O jogo é limitado por pixels ou por geometria/CPU? | (a) 1920×1080; (b) 1280×720 em janela; (c) 1920×1080 com `get_viewport().scaling_3d_scale = 0.75`; (d) sem MSAA (`get_viewport().msaa_3d = Viewport.MSAA_DISABLED`) | se FPS(b) ≈ 2× FPS(a): pixels (HIS-05, 07, 08); se igual: geometria e CPU (HIS-02, 03, 04, 10) |
| D2 | Quanto custa o minimapa? | AJUSTAR → Minimapa → Ocultar (ou `SubViewport.render_target_update_mode = UPDATE_DISABLED` em `minimapa.gd:144`) | HIS-06 |
| D3 | Qual classe de vegetação pesa mais? | Esconder (`visible=false`), um grupo por vez, os filhos do `_region` (`world.get("_region")`) pelo prefixo do nome: `Mata: `, `Sub-bosque`, `Copa distante`, `Manguezal`, `Ingazeiros do rio`, `Restinga da orla`, `Coqueiros da orla`, `Paisagismo: `, `Pé das árvores` | ordem de ataque entre HIS-02, 03, 04; o custo real das copas distantes |
| D4 | Quanto vale o corte da mata? | Mudar `LOD_MATA` (`geo_region_renderer.gd:195`) para 280, 220 e 160, e `LOD_SUB_BOSQUE` (`:191`) para 85 e 55; recomeçar o vale a cada troca | quais constantes entram hoje |
| D5 | As malhas leves da orla ajudam? | No `_region`, trocar `_malha_da_especie("mangue"|"ingazeiro"|local)` por `EspeciesDaMata.malha(...)` (`:2045,2046,2223`) | HIS-03 |
| D6 | Moradores, bichos e peixes | `get_tree().call_group("moradores","set_visible",false)`; o mesmo com `bichos_de_casa`, `bandos_de_chao`, `cardumes`; depois `process_mode = Node.PROCESS_MODE_DISABLED` nos mesmos grupos | GPU contra CPU da população (HIS-10) |
| D7 | Chão | Trocar o material do terreno por um `StandardMaterial3D` simples; ou pôr o uniform `solo_ativo = false` | HIS-08 |
| D8 | Água | Esconder o nó do mar (material `agua_mar.gdshader`); depois trocar `filter_linear_mipmap` por `filter_linear` em `agua_mar.gdshader:14` | HIS-07 |
| D9 | Céu | `Sky.process_mode`: `REALTIME` → `INCREMENTAL`; `radiance_size` 256 → 64 (`ceu_vale.gd:74-75`) | HIS-09 |
| D10 | Sombra do sol | `DirectionalLight3D "Sol"`: `shadow_enabled=false`; depois `directional_shadow_mode` de 4 para 2 cascatas e `directional_shadow_max_distance` de 180 para 80 (`ceu_vale.gd:91-93`) | custo das 4 cascatas com 22 moradores e 25 construções |
| D11 | Hora do dia | Início do jogo (7h, sol baixo) contra 9h e contra a noite (luzes de 1887 ligadas) | se a hora muda o resultado |
| D12 | Carregamento real | `medir_carregamento.gd --cena=abertura,vale` com janela, sem `--headless`; repetir com `--precarregar=1` | HIS-11 |
| D13 | Primeira passagem contra segunda | Medir o primeiro minuto depois de entrar e depois de 2 minutos de volta, para separar compilação de pipeline e upload de textura de custo estável | "travadas" contra FPS médio |
| D14 | Tamanho do pacote | Exportar uma vez e ler o tamanho do executável | HIS-12 |
