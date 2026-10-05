# Inventário de GLBs e texturas do Myths' Valley 3D (escopo AST)

Medição feita em 05/10/2026 sobre o commit `eb430e4` (árvore limpa), só leitura, sem executar o Godot. Todos os números vêm de scripts em `scratchpad/perf/` que leem o cabeçalho GLB, o chunk JSON e os `.import`/`.ctex` do projeto. Arquivos gerados: `assets_glb.csv` (262 linhas, 1 por GLB), `assets_tex.csv` (953 texturas importadas), `inventario_glb.py` (o medidor), `assets_cruzado.json` (GLB + catálogo + VRAM).

## Resumo

1. O peso dos assets 3D **não está nos triângulos**. O vale inteiro tem 262 GLBs somando **1.556.408 triângulos** se todos fossem instanciados uma vez; o maior modelo tem 20.453. Isso é pouco para uma GTX 1660 Ti. O peso está na **multiplicação**: 22 moradores + 71 bichos com esqueleto ou malha de 3,5 a 15 mil triângulos cada (594 mil triângulos, 408 mil deles com skin, 2.115 ossos), e o paisagismo, que planta de 2,4 a 3 mil pés de modelos `_leve` de 1,8 a 7,7 mil triângulos (estimativa: 9 milhões de triângulos se todos os pés estivessem na tela).
2. **VRAM de textura**: ~1058 MB se tudo do catálogo for carregado (BC1/BC5 já com mipmaps; cenário B da seção de VRAM). Cabe folgado nos 6 GB da 1660 Ti, mas **418 MB (41% dos GLBs) vêm de 40 GLBs em 2K** (23 construções, 14 árvores, saveiro, casa_carro_quebrado, e o modelo medieval em 4K, que nem é usado). 2K→1K nesses 40 economiza **314 MB** (o medieval, de 4K, economiza mais ao ser excluído do export). Normais (BC5) sozinhas pesam **453 MB (45%)**.
3. **O build vai ficar ~2,3x maior que o anterior**: `.godot/imported` tem 1066 MB de `.ctex` + 88 MB de `.scn`; o PCK estimado é **~1211 MB** (o exe de 03/10 tinha 540.764.864 bytes, com 96 GLBs; hoje são 262). `export_filter=all_resources` ainda empacota 2 GLBs que ninguém referencia, 15 texturas órfãs e ~24 GLBs sem nenhuma referência literal em código (candidatos): 21 + 25 + 85 MB de dados mortos.
4. **Os 262 GLBs são `doubleSided`** (materiais `CULL_DISABLED` ao importar): a GPU rasteriza as costas de toda casa, árvore e bicho. Só os cômodos de dentro das casas trocam para `CULL_BACK` (`interiores.gd:432`). É o achado de GPU mais barato de testar em A/B.
5. Os modelos que o projeto chamou de `_leve` (~2.500 faces) e `_longe` (~700 faces) cumprem a meta em **faces = quads** (cada quad = 2 triângulos), mas os `_longe` têm em média 1.695 triângulos contra 1.400 previstos, e **12 de 15 estouram**. As plantas pequenas do paisagismo (capim 2.907, taboa 2.256, mandioca 1.772, milho 2.001 triângulos por pé) são pesadas demais para planta repetida às centenas.
6. Auto-LOD do Godot (`meshes/generate_lods=true`) e malha de sombra (`create_shadow_meshes=true`) estão ligados nos 262 `.import`. Se **funcionam** em runtime não dá para provar sem rodar o jogo (`.scn` vem comprimido em Zstd; ver Dúvidas).
7. Interface e menus **não** são problema: capas de 2048x1152 em BC1 (1,5 MB cada), logo e moldura em BC3. As únicas texturas sem compressão em 3D são migalhas (~66 MB de VRAM no total, 82 arquivos).

## Fatos contados

| Fato | Valor | Fonte |
|---|---:|---|
| GLBs em `assets/` | 262 (946,6 MB) | `inventario_glb.py` → `assets_glb.csv` |
| GLBs que são ponteiro Git LFS na árvore de trabalho | 0 (todos reais; no git os 262 são ponteiros de ~130 bytes, `.gitattributes: *.glb filter=lfs`) | `.gitattributes:14`; `git ls-tree -l HEAD` |
| Extensões glTF usadas (Draco, meshopt, basisu) | nenhuma (`extensionsUsed` vazio nos 262) | `assets_glb.csv`, coluna `ext` |
| Triângulos somados (1 de cada GLB) | 1.556.408 | `assets_glb.csv` |
| Vértices somados | 2.101.705 | idem |
| Meshes / primitivas / materiais por GLB | 1 / 1 / 1 em TODOS (1 draw call por instância, sem material compartilhado entre GLBs) | idem, colunas `meshes`, `prims`, `materials` |
| Materiais `alphaMode` | OPAQUE nos 262; `doubleSided=true` nos 262 | `mats.py` (lê o JSON de cada GLB) |
| Texturas por GLB | 3 (cor JPEG, normal JPEG, metal/rugosidade PNG); 1K em 222 GLBs, 2K em 39, 4K em 1 | `assets_glb.csv`, coluna `tex_lista` |
| Esqueletos / juntas totais nos GLBs | 46 skins / 2208 juntas (personagens 65 cada; quadrúpedes 19 a 42) | idem, colunas `skins`, `joints` |
| GLBs com animação | 45 (24 personagens com 7 a 13 clipes + o medieval; 19 bichos com 1 clipe `walk`; 1 peixe) | idem, `anim_names` |
| Entradas em `CatalogoAssets.PECAS` | 264 chaves → 260 GLBs distintos (4 chaves repetem GLB: lapa/pedras, bancadas/mesa, fogueira/lenha) | `catalogo_assets.gd:22-357` |
| GLBs existentes e NÃO referenciados no catálogo | 2: `aderecos/fogueira_tripo.glb` (2,1 MB) e `personagem/medieval_character_animated.glb` (11,1 MB, 4K) | `cruza.py`; `grep medieval` só acha comentários |
| `.import` de GLB com `generate_lods` / `create_shadow_meshes` / `ensure_tangents` verdadeiro | 262 / 262 / 262 (`light_baking=1`, `animation/fps=30`, `_subresources={}`, sem `import_script`) | `*.glb.import` linhas 26-37 (ex.: `arvores/mangueira_tripo.glb.import`) |
| `.scn` importados | 262 arquivos, 88,1 MB (comprimidos, cabeçalho `RSCC`) | `.godot/imported`, `scn_sizes.csv` |
| Texturas `.import` (png/jpg/webp/svg) | 953: modo VRAM (2) = 871, lossless (0) = 82; mipmaps ligados = 881 | `analise_import.py` → `assets_tex.csv` |
| `.ctex` em `.godot/imported` | 957 arquivos, 1.065,7 MB | `find .godot/imported -name '*.ctex'` |
| Formato GPU das texturas VRAM | BC1 (578), BC5/normal (229), BC3 (64); nenhuma BC7; `compress/high_quality=false` | `project.godot:78-85`; cabeçalho GST2 lido de cada `.ctex` |
| `export_filter` / alvo de textura | `all_resources`; `s3tc_bptc=true`, `etc2_astc=false`; PCK embutido | `export_presets.cfg:8,22,24-25` |
| Exe do build anterior | 540.764.864 bytes (96 GLBs no commit `64075df`); zip 359.381.312 bytes | `build/windows/MythsValley3D.exe`, `build/*.zip` |
| PCK estimado do build novo | ~1.211 MB (ctex 1.066 + scn 88 + áudio 25 + cenas/dados ~27) | soma dos tamanhos em `.godot/imported`; estimativa |
| Textura média por GLB | 3,9 MB (`.ctex`) | `cruza.py` |

### Totais por pasta (categoria)

`ctex` é o tamanho do `.ctex` (≈ VRAM, porque BC1/BC5 já traz mipmaps).

| Pasta | GLBs | MB do GLB | Triângulos | Mpx de textura | `.ctex` MB | Juntas | Tris médios |
|---|---:|---:|---:|---:|---:|---:|---:|
| arvores | 80 | 321,0 | 473.307 | 377,5 | 306,0 | 0 | 5.916 |
| construcoes | 25 | 182,5 | 263.591 | 295,7 | 248,0 | 0 | 10.544 |
| aderecos | 39 | 99,9 | 170.371 | 132,1 | 108,0 | 0 | 4.368 |
| itens | 28 | 57,3 | 59.572 | 88,1 | 84,0 | 0 | 2.128 |
| animais | 31 | 76,8 | 147.326 | 97,5 | 82,7 | 557 | 4.752 |
| personagens | 24 | 117,1 | 300.286 | 75,5 | 66,7 | 1561 | 12.512 |
| peixes | 17 | 35,0 | 41.307 | 53,5 | 45,3 | 14 | 2.430 |
| moveis | 15 | 34,2 | 57.354 | 47,2 | 40,0 | 0 | 3.824 |
| personagem | 1 | 11,1 | 18.686 | 25,2 | 18,7 | 65 | 18.686 |
| casas | 1 | 9,4 | 12.477 | 12,6 | 10,7 | 0 | 12.477 |
| mar | 1 | 2,3 | 12.131 | 3,1 | 2,7 | 11 | 12.131 |
| **total** | **262** | **946,6** | **1.556.408** | **1208,0** | **1012,7** | **2208** | 5.940 |

### Totais por classe de orçamento (para a conta de violações)

| Classe | GLBs | Triângulos | Média | Máx. | `.ctex` MB | Estouro de tris | Estouro de textura |
|---|---:|---:|---:|---:|---:|---:|---:|
| aderecos | 54 | 227.725 | 4.217 | 10.862 | 148,0 | 4 | 1 |
| bicho | 31 | 147.326 | 4.752 | 6.070 | 82,7 | 0 | 0 |
| arvore | 48 | 361.469 | 7.531 | 20.453 | 220,7 | 1 | 0 |
| arvore_leve | 17 | 86.418 | 5.083 | 6.141 | 45,3 | 12 | 0 |
| arvore_longe | 15 | 25.420 | 1.695 | 2.100 | 40,0 | 12 | 0 |
| construcao_comum | 23 | 233.642 | 10.158 | 12.477 | 226,7 | 3 | 0 |
| construcao_destaque | 3 | 42.426 | 14.142 | 17.319 | 32,0 | 0 | 0 |
| item | 28 | 59.572 | 2.128 | 3.154 | 84,0 | 3 | 0 |
| peixe | 18 | 53.438 | 2.969 | 12.131 | 48,0 | 0 | 0 |
| personagem | 25 | 318.972 | 12.759 | 18.686 | 85,3 | 0 | 1 |

## Achados

Cada achado tem id `AST-NN`. Os números das tabelas saem direto de `assets_glb.csv`/`assets_tex.csv`; estimativas vêm marcadas.

### AST-01 — Os 262 GLBs entram com `CULL_DISABLED` (dupla face)

**Evidência.** Todo material tem `doubleSided: true` e `alphaMode: OPAQUE` (`mats.py`, 262 de 262). O importador glTF do Godot converte `doubleSided` em `cull_mode = CULL_DISABLED`. Nenhum script religa a face de trás nas peças do mundo; o único `CULL_BACK` aplicado a GLB do Tripo é o dos cômodos internos (`scripts/prototipo_3d/interiores.gd:432-434`), o que mostra que a troca funciona em malha do Tripo pelo menos nas paredes interiores. `CatalogoAssets.instanciar` (`catalogo_assets.gd:399-426`) não mexe em material.

**Mecanismo.** Sem culling, cada triângulo de costas passa por raster, teste de profundidade e, quando não é rejeitado por early-Z, pelo fragment shader inteiro (PBR com normal map e MR). Em malha fechada (casa, bicho, copa) metade dos triângulos rasterizados são costas. A passagem de sombras também desenha as costas: o sol tem `shadow_enabled=true`, `SHADOW_PARALLEL_4_SPLITS` e `directional_shadow_max_distance=180` (`scripts/prototipo_3d/ceu_vale.gd:89-93`), então tudo a menos de 180 u é desenhado até 4 vezes a mais, sem culling. A lua não projeta sombra (`ceu_vale.gd:97`). Com MSAA 2x o custo de raster dobra de novo. **Estimativa**, não medição: até ~2x em triângulos rasterizados e em passes de sombra; o ganho real depende de o gargalo ser vértice/raster (provável na 1660 Ti) ou fragment.

**Impacto:** médio a alto na GPU; confiança média. **Correção de HOJE:** em `CatalogoAssets.instanciar` (ou na primeira vez que uma cena é carregada, em `cena()`, `catalogo_assets.gd:383-394`), percorrer os `MeshInstance3D` do modelo e duplicar uma vez cada material trocando `cull_mode` para `CULL_BACK` (cache por GLB, não por instância; o padrão está pronto em `interiores.gd:428-436`). **Esforço:** ~1 hora com cache. **Risco:** folhagem e peças finas (cerca, varal, vela do saveiro, penas) podem sumir ou mostrar buraco se a malha do Tripo tiver normais invertidas ou casca aberta; testar árvore, cerca, varal, saveiro, galinha. Nenhum arquivo de `tests/` cita `cull_mode`/`CULL_` (grep), mas rodar `testar.ps1` completo antes do build. **Como medir:** A/B com 2 quadros iguais (câmera parada no arraial), HUD de tri/draw e tempo de GPU em `prototype_hud.gd`: liga/desliga a função; comparar ms de GPU.

### AST-02 — A população viva multiplica 3,5 a 15 mil triângulos por instância (594 mil triângulos, 2.115 ossos)

**Evidência.** Censo do log de hoje × triângulos medidos por GLB (`multiplica.py`). Cada GLB tem 1 mesh, 1 primitiva e 1 material, então são 94 instâncias de 1 superfície cada (45 delas skinadas: 22 moradores, 22 quadrúpedes, 1 jogador), mais 1 passe de sombra por superfície e por cascata do sol.

| Grupo | Instâncias | Tris por instância | Tris totais | Com skin | Juntas totais |
|---|---:|---:|---:|---:|---:|
| Moradores (22, `data/npcs_3d.json`) | 22 | 10.302 a 15.119 (média 12.338) | 271.425 | 271.425 | 1.431 |
| Jogador (`viajante_tripo.glb`, `personagem.tscn`) | 1 | 14.461 | 14.461 | 14.461 | 65 |
| Quadrúpedes (cachorros 7, gatos 8, porcos 3, cabras 3, jumento 1) | 22 | 5.240 a 5.814 | 122.428 | 122.428 | 619 |
| Aves sem rig (galinha 25, pintinho 7, dangola 5, pato 4, galo 3, pavoa 3, peru 1, pavão 1) | 49 | 3.509 a 4.040 | 186.018 | 0 | 0 |
| **Total** | **94** | | **594.332** | **408.314** | **2.115** |

Observações: a distribuição dos 8 gatos (3/3/2) é **estimada** (o censo não separa as 3 variantes); muda o total em menos de 1%. Pedro (14.400 tris, 65 juntas) existe em `personagens/` e `catalogo_assets.gd:132`, mas não entra no censo de 22; se ele for instanciado, soma-se.

**Mecanismo.** (a) Skinning: o Godot atualiza o buffer de cada `Skeleton3D` visível a cada quadro; custo ≈ vértices skinados × influências, mais 65 trilhas de osso × 3 canais por morador animado (cada GLB de morador carrega 2.535 canais de animação em 13 clipes; só o clipe tocando avalia, ~195 canais por morador). (b) O `AnimationMixer` roda no thread principal: ~22 × 195 + 619 × 3 ≈ **6.100 canais por quadro** (conta minha, estimativa), além do GDScript de cada bicho. (c) 408 mil triângulos skinados e 186 mil de aves, **mais** a dupla face (AST-01), mais sombras. Uma ave de 0,45 m tem 3.885 triângulos; o pintinho, de 11 cm, 3.653 (`galinha_tripo.glb`, `pintinho_tripo.glb`): são 3,5 mil triângulos para algo que na tela tem 20 pixels.

**Impacto:** alto (candidato a maior fatia de CPU de quadro junto com o GDScript dos bichos), confiança média: o custo por esqueleto no 4,7 só se confirma medindo. **Correção de HOJE (dados, sem arte nova):** se `animador_bicho.gd`/`npc.gd` já pausam o `AnimationPlayer` longe da câmera, conferir o raio; se não, `AnimationMixer.active = false` fora de ~40 m (outros escopos do relatório cobrem o código). Do lado do asset: `visibility_range_end` nos `MeshInstance3D` dos bichos (~60 m) e das aves (~35 m). **Estrutural:** retopologia dos bichos a 800-1.200 faces (2.000 tris; 40 créditos cada × 19 espécies) e das aves a ~300 faces (20 espécies de ave não animadas; 600 tris). **Como medir:** A/B desligando o nó `Fauna`/`Moradores` (ou `visible=false` em todos os `MeshInstance3D` do grupo) e comparando ms de CPU (`Performance.TIME_PROCESS`) e de GPU.

### AST-03 — Paisagismo e mata plantam de 2,4 a 3 mil pés com modelos de 1,8 a 7,7 mil triângulos

**Evidência.** `scenes/prototipo_3d/paisagismo_vale.tscn` tem 19 zonas (`Path3D` + `zona_de_flora.gd`) de 4.642 u² no máximo; as receitas estão em `data/paisagismo/receitas.json` (espaçamento, `lod`, `forro`); os polígonos estão em `data/paisagismo/zonas_iniciais.json`. Calculei a área de cada zona pela fórmula do polígono (shoelace) e a densidade de cada padrão (`paisagismo_est.py`). **É estimativa**: não reproduz o sorteio, as reservas (ruas, casas, nomeadas) nem a faixa `mata_ciliar` (padrão `faixa`, não calculado). Uma simulação independente em `perf/paisagismo_sim.txt` dá 3.026 plantas com reservas e `forro`.

| Espécie (chave) | Pés estimados | Tris por pé | Tris totais estimados | Textura | `lod` (u) |
|---|---:|---:|---:|---|---:|
| bananeira_leve | 560 | 5.219 | 2.922.640 | 1024² | 230 |
| pe_de_mandioca | 541 | 1.772 | 958.652 | 1024² | 120 |
| pe_de_milho | 273 | 2.001 | 546.273 | 1024² | 120 |
| pe_de_fumo | 195 | 2.323 | 452.985 | 1024² | 120 |
| pitangueira_leve | 164 | 3.788 | 621.232 | 1024² | 230 |
| piacava_leve | 135 | 5.894 | 795.690 | 1024² | 230 |
| cajueiro_leve | 128 | 5.670 | 725.760 | 1024² | 230 |
| goiabeira | 119 | 7.682 | 914.158 | 1024² | 230 |
| mamoeiro | 95 | 5.087 | 483.265 | 1024² | 230 |
| dendezeiro_leve | 50 | 5.583 | 279.150 | 1024² | 230 |
| jaqueira_leve | 47 | 4.052 | 190.444 | 1024² | 230 |
| mangueira_leve | 44 | 3.872 | 170.368 | 1024² | 230 |
| clusia_leve | 14 | 5.165 | 72.310 | 1024² | 230 |
| aroeira_leve | 12 | 3.403 | 40.836 | 1024² | 230 |
| **soma** | **2377** | | **9.173.763** | | |

Plantas de `forro` e de beira (capim 2.907 tris, taboa 2.256, helicônia 3.147, samambaia, bromélia) vêm por cima (`paisagismo_sim.txt`: capim 144, taboa 545, helicônia 157). Os modelos usados no paisagismo (`_leve`) têm **5.083 tris em média** contra a faixa de 800-2.000 faces (1.600-4.000 tris) que o próprio `docs/arte/ASSETS_TRIPO.md` (linha 148) estipula para "árvore de mata, instanciada às centenas".

**Mecanismo.** `PaisagismoVale.plantar` (`paisagismo_vale.gd:637-690`) agrupa por espécie e `lod` e chama `_multimesh_em_blocos` (`geo_region_renderer.gd:2139-2162`), que põe `visibility_range_end = lod` em cada bloco; então só os blocos até 120-230 u contam para o desenho. As sombras do sol (4 divisões até 180 u, `ceu_vale.gd:92-93`) repetem esses blocos até 4 vezes. Mesmo assim, no arraial a 230 u cabem bananal, pomares e roças inteiros. Cada pé de bananeira é **5.219 triângulos**; 560 pés = 2,9 milhões de triângulos (só a bananeira), contra os 2,5 M de triângulos de toda a bancada de teste que fechou 60 FPS (`ASSETS_TRIPO.md:26`). Com dupla face, sombras e MSAA, isso come milissegundos. Ainda é conta de pior caso (tudo visível). O auto-LOD do Godot (AST-05) pode reduzir, se funcionar em `MultiMesh`.

**Impacto:** alto (maior contribuinte de triângulos do vale, depois da população), confiança média: depende de quantos blocos ficam dentro da distância de corte e se a câmera os vê. **Correção de HOJE (dados):** reduzir o `lod` das receitas de planta baixa (`roca_mandioca`, `roca_milho_fumo`: 120 → 60) e de `bananal`/`pitangal` (230 → 140) em `data/paisagismo/receitas.json`; baixa o número de blocos visíveis sem tocar em código. **Estrutural:** novas retopologias a 300-600 faces para `pe_de_mandioca`, `pe_de_milho`, `pe_de_fumo`, `capim`, `taboa`, `heliconia`, `bananeira_leve` (7 espécies × 40 créditos); a mata distante já usa copa low-poly de ~64 tris (`copas_distantes.gd`). **Risco:** o corte mais curto faz as roças aparecerem de perto (pop-in); há portão `tests/paisagismo.gd` e `tests/lod_vegetacao.gd` que contam pés e blocos: rodar os dois. **Como medir:** `tools/prototipo_3d/medir_lod.gd` (já existe) antes/depois, e HUD de tri.

### AST-04 — A composição autoral coloca 93 peças com o modelo completo, não o `_leve`

**Evidência.** `scenes/prototipo_3d/composicao_vale.tscn` tem 93 nós com `chave` (38 chaves), 23 deles casas. Somadas as instâncias × triângulos: **714.154 triângulos** (`compo.py`). Os maiores: 18 pitangueiras (9.688 tris cada, 174.384 no total), 6 casas `casa_taipa` (11.343), 4 bananeiras completas (14.753), 8 galinheiros (5.455), 3 `casa_carro_quebrado` (12.477), 2 dendezeiros (15.014), ipês roxo/amarelo (15.418 / 15.148). `grep -n "leve"` em `peca_composicao.gd`, `casa_composicao.gd`, `composicao*.gd` e `world_builder.gd` não acha troca por `_leve`: as árvores dos quintais usam `pitangueira` (9.688), embora `pitangueira_leve` (3.788) exista e esteja no catálogo (`catalogo_assets.gd:329`).

**Mecanismo.** Cada pitangueira completa custa 2,6x o `_leve`; 18 delas são 174 mil contra 68 mil triângulos. As 23 casas somam ~250 mil triângulos com textura 2K cada.

**Impacto:** médio (a diferença de pitangueira + bananeira é ~120 mil triângulos), confiança alta nos números. **Correção de HOJE:** na criação da peça (`peca_composicao.gd:66`) trocar `pitangueira`/`bananeira`/`dendezeiro` pela chave `_leve` quando existir (`EspeciesDaMata.malha()` já faz isso em `especies_da_mata.gd:98-102`). **Esforço:** 15 min. **Risco:** troca visível de silhueta de perto; colisão `tronco` do catálogo é igual nas versões `_leve`. **Como medir:** HUD de tri no arraial antes/depois.

### AST-05 — LOD: existe de três jeitos, mas só um está provado

**Evidência.** (1) **Auto-LOD do Godot**: `meshes/generate_lods=true` e `create_shadow_meshes=true` nos 262 `.import` (`arvores/mangueira_tripo.glb.import:27-28` e demais). (2) **Variantes do Tripo** `_leve` (17 GLBs) e `_longe` (15 GLBs), do lote `tools/tripo/lote_2026-10-05_lod.json`. (3) **`visibility_range`/blocos de MultiMesh** (`geo_region_renderer._multimesh_em_blocos`, `paisagismo_vale.gd`), fora do meu escopo. As variantes cumprem a meta em quads:

| Classe | GLBs | Alvo (faces) | Alvo em tris (×2) | Tris médios | Máx. | Acima do alvo |
|---|---:|---:|---:|---:|---:|---:|
| arvore_leve | 17 | 2500 | 5000 | 5.083 | 6.141 | 12 |
| arvore_longe | 15 | 700 | 1400 | 1.695 | 2.100 | 12 |

A razão triângulos/faces medida em 244 GLBs com plano em `tools/tripo/lote_*.json` tem mediana **1,92** (mín. 1,36; máx. 3,00): "face" do Tripo é quad. Confirmação: `lote_2026-10-05b.json` registra `portao_fazenda`: 3.000 faces, 6.006 triângulos. Logo a tabela de orçamento de `ASSETS_TRIPO.md:142-152` ("polígonos") deve ser lida como quads, e meu teste de violação usa 2 × o teto. Os `_longe` com razão acima de 2,3 são os piores: `mata_alta_longe` 700 faces → 2.100 tris (3,0x); `mata_larga_longe` 2,94x; `bananeira_longe`, `embauba_longe` 2,87x.

**Mecanismo.** O auto-LOD do Godot só ajuda se (a) o `.scn` realmente tem LODs (o meshoptimizer não reduz bem malha com UV em ilhas pequenas e com bordas de textura, como a do Tripo: não foi medido aqui) e (b) o instanciamento respeita o LOD (para `MultiMesh`, é provável que o Godot escolha um LOD só para o conjunto; a confirmar, ver Dúvidas).

**Impacto:** médio; confiança baixa sobre o efeito real, alta sobre os números das variantes. **Correção de HOJE:** nenhuma de código; fazer o A/B de `Viewport.mesh_lod_threshold` (ver Dúvidas). **Estrutural:** refazer os 12 `_longe` que estouram com `face_limit` 350 (ou usar a copa low-poly de `copas_distantes.gd` para todos), e rever que o `_leve` sirva só até ~40 m. **Risco:** baixo.

### AST-06 — 40 GLBs em 2K/4K usam 418 MB; 2K→1K economiza 313 MB

**Evidência.** `assets_glb.csv`: texturas de 2048² em 39 GLBs e uma de 4096² em 1. `.ctex` somado deles: **418,0 MB** (41% dos 1.012,7 MB de textura de GLB). Distribuição:

| Grupo | GLBs em 2K+ | `.ctex` MB | Se fosse 1K (÷4) | Economia |
|---|---:|---:|---:|---:|
| aderecos | 1 | 10,7 | 2,7 | 8,0 |
| arvores | 14 | 135,3 | 33,8 | 101,5 |
| casas | 1 | 10,7 | 2,7 | 8,0 |
| construcoes | 23 | 242,7 | 60,7 | 182,0 |
| personagem | 1 | 18,7 | 4,7 | 14,0 |
| **total** | **40** | **418,0** | **104,5** | **313,5** |

O orçamento do projeto manda 2K para "construção de destaque, casa comum, pier, ponte, árvore nomeada, NPC" (`ASSETS_TRIPO.md:144-152`), portanto **só 2 GLBs violam a regra de textura**: `aderecos/saveiro_tripo.glb` (2K num adereço; era intencional: `lote_2026-10-05.json` pede `2k`) e o `personagem/medieval_character_animated.glb` (4K, 25,2 Mpx, 18,7 MB de `.ctex`, **sem uso no jogo**). O problema é a regra: 23 casas em 2K, cada uma com 10,7 MB, numa cena em que o jogador vê cada casa a 5-30 m; a doc diz (linha 158) que "um adereço em 1K gasta 4x menos que em 2K sem diferença visível a 2 m".

**Mecanismo.** VRAM e banda de memória (cada fragmento lê 3 mapas: BC1 cor, BC5 normal, BC1 MR). 2K por casa com mipmaps de 1,33x = 10,7 MB por GLB. Em 1080p com FOV de 75° (estimativa), uma casa de 6,5 m vista a 15 m ocupa ~300 pixels de largura (6,5 ÷ (2 × 15 × tan 37,5°) × 1080): uma textura 1K já está acima da resolução da tela. Não é causa dos 15 FPS na 1660 Ti (VRAM total cabe em 6 GB), é causa de **tamanho de build, tempo de leitura e risco em placas de 2 GB**.

**Impacto:** baixo no FPS, alto no tamanho do build e na VRAM de GPUs fracas; confiança alta nos números. **Correção de HOJE:** `process/size_limit=1024` nos `.import` das 3 texturas de cada uma das 23 construções + 14 árvores (ou, sem editar 120 arquivos, um passo único: `compress/` por `importer_defaults` não distingue pasta; usar `process/size_limit` por arquivo). O Godot reimporta ao abrir o editor (~minutos). **Esforço:** 20-30 min com script. **Risco:** o casarão, a igreja e as árvores nomeadas perdem nitidez de perto; manter 2K só em `igreja`, `capela`, `casarao_fazenda`, `mangueira`, `gameleira`, `jaqueira` (6 GLBs = 64 MB), o resto 1K. **Como medir:** HUD de VRAM antes/depois; tamanho do PCK; screenshot lado a lado de uma casa a 8 m.

### AST-07 — Mapas de normal ocupam 453 MB (45% da textura dos GLB)

**Evidência.** Por papel de textura (`mais.py`, formato lido do cabeçalho do `.ctex`):

| Mapa | Resolução | Quantidade | `.ctex` MB | Formato GPU |
|---|---|---:|---:|---|
| Normal (JPEG→BC5) | 1024² | 192 | 256,0 | BC5, 1 B/px |
| Normal | 2048² | 37 | 197,3 | BC5 |
| Cor (JPEG→BC1) | 1024² / 2048² / 4096² | 263 / 45 / 1 | 175,3 / 120,0 / 10,7 | BC1, 0,5 B/px |
| Metal/rugosidade (PNG→BC1) | 1024² / 2048² | 224 / 39 | 149,3 / 104,0 | BC1 |

Normais saem do Tripo como JPEG (lossy) e viram BC5 de 1 byte por pixel: o dobro da cor. Em estilo pintado, com luz fixada na textura (`ASSETS_TRIPO.md:171`), o normal map das peças pequenas e distantes dá pouca coisa.

**Mecanismo.** BC5 custa 2x a banda de BC1; a amostra do normal map é uma leitura extra por fragmento e exige tangentes no vértice (`ensure_tangents=true`: +4 bytes por vértice nos 1,56 M de triângulos).

**Impacto:** médio na VRAM e na banda, baixo a médio no FPS; confiança média. **Correção ESTRUTURAL** (reimportar): para as classes `item`, `aderecos`, `moveis`, `arvore_leve`, `arvore_longe`, `bicho` e `peixe`, remover a textura de normal do material (reimportar sem o mapa, ou anular `normal_texture` em `CatalogoAssets.instanciar`; neste segundo caso a VRAM só cai se o `.ctex` deixar de ser carregado, então vale tirar do GLB). **Para HOJE**: só A/B de custo de GPU, ver Dúvidas. Economia máxima se tirar todos: 453 MB; só das classes acima (~160 normais): ~210 MB (estimativa: 160 × 1,33 MB).

### AST-08 — O build novo vai ter ~1211 MB, mais que o dobro do anterior

**Evidência.** `.godot/imported`: 957 `.ctex` somam **1065,7 MB**, os 262 `.scn` **88,1 MB**, áudio ~25 MB; `scenes/` 22 MB, `data/` 2 MB. O exe de 03/10 (`build/windows/MythsValley3D.exe`, 540.764.864 bytes) foi feito com 96 GLBs (`git ls-tree 64075df`); o commit `ce20572` trouxe 166 GLBs a mais. `export_presets.cfg:8` usa `all_resources`, então tudo que está importado entra, referenciado ou não. O zip anterior (359.381.312 bytes) comprimiu a 66,5%; mantida a razão, o zip novo fica em **~805 MB** (estimativa).

**Dados mortos que vão no PCK:**

| Origem | Itens | Tamanho (.ctex/.glb→scn) |
|---|---:|---:|
| GLBs sem referência no catálogo (`fogueira_tripo.glb`, `medieval_character_animated.glb`) | 2 | 21,3 MB de `.ctex` + ~13 MB de GLB (fonte, não vai no PCK) |
| Texturas extraídas que o GLB não usa (nomes antigos de reexportação: balde, cacho_banana, enxada, mandioca, picareta, vara_pescar, viajante) | 15 arquivos em 7 GLBs | 25,3 MB |
| Chaves do catálogo sem nenhuma referência literal em `scripts/`, `data/`, `scenes/` (candidatas; verificar) | 24 GLBs | 85,3 MB de `.ctex` |

As candidatas: `abobora_rasteira`, `algodoeiro_praia`, `boi`, `cadeia`, `canteiro_couve`, `capivara`, `casa_palha`, `cavalo`, `garca`, `jaca`, `latada_maracuja`, `lenha_feixe`, `licurizeiro`, `moreia`, `pe_de_pimenta`, `prato_comida`, `quiabeiro`, `regador`, `rolo_fumo`, `sacos_farinha`, `sobrado`, `tatu`, `tubarao_cabeca_chata`, `urubu`. Podem ser montadas por nome dinâmico (por isso são candidatas); o portão `tests/paisagismo.gd` cita `licurizeiro`.

**Mecanismo.** Download/descompactação, leitura do PCK a frio do SSD (no primeiro uso o Windows lê o que for tocado), espaço de upload (site Tripothon, Hostinger). Não afeta FPS.

**Impacto:** alto no carregamento a frio e na entrega; confiança alta. **Correção de HOJE:** (1) excluir o que sobra do export com `exclude_filter` (acrescentar `assets/prototipo_3d/personagem/*` e `assets/prototipo_3d/aderecos/fogueira_tripo*` em `export_presets.cfg:10`); (2) apagar as 15 texturas órfãs e seus `.import`; (3) aplicar AST-06. Somados, tirar ~47 MB (dados mortos) e ~313 MB (2K→1K) do PCK. **Esforço:** 10 min a 1 h. **Risco:** o `exclude_filter` falha silenciosamente se o caminho estiver errado; conferir o tamanho do exe depois. **Como medir:** tamanho de `MythsValley3D.exe` e do zip.

### AST-09 — `CatalogoAssets.cena()` carrega cada GLB com `load()` síncrono na thread principal

**Evidência.** `catalogo_assets.gd:383-394`: `var scene := load(path) as PackedScene`, com cache em `_cenas`. O fluxo `tela_carregamento.gd` usa `ResourceLoader` em segundo plano só para a cena `vale.tscn`; as peças do catálogo (até 264 chaves, 260 GLBs) são carregadas dentro da montagem do mundo, que cede 1 quadro a cada 80 ms (`ORCAMENTO_QUADRO_US = 80000`, `geo_region_renderer.gd:70`). Há 52 chamadas a `CatalogoAssets.cena`/`instanciar` em `scripts/`. Cada `load()` lê `.scn` + 3 `.ctex`. Soma das texturas de GLBs referenciados: **991,4 MB** (menos as órfãs, que o `.scn` não puxa: 966,1 MB) e 88 MB de `.scn`.

**Mecanismo.** Cada carga síncrona bloqueia a thread principal na leitura + inflação Zstd do `.scn` + upload de textura. A conta: ~1.050 MB ÷ 400 MB/s de SSD SATA ≈ 2,6 s, ÷ 1.500 MB/s de NVMe ≈ 0,7 s (**estimativa**, sem cache de disco quente); a 'dezenas de segundos' vem de outro lugar (instanciar, `limites()` por instância, GDScript, shaders). O `.ctex` VRAM-comprimido não precisa decodificar; só os 82 lossless (WebP) decodificam, ~14 Mpx no total.

**Impacto:** médio a baixo no carregamento (2-3 s no pior caso de disco lento); confiança média. **Correção ESTRUTURAL:** pré-aquecer em segundo plano com `ResourceLoader.load_threaded_request` a lista de chaves que o vale usa durante a tela de carregamento (a lista sai de um passe da composição + paisagismo). **Risco:** médio (ordem de montagem). **Como medir:** `tools/prototipo_3d/medir_carregamento.gd` já cronometra etapas; somar o tempo de `CatalogoAssets.cena` com `Time.get_ticks_usec` em volta do `load()` (1 linha, só para medir).

### AST-10 — 82 texturas sem compressão VRAM (migalha, mas têm dois erros)

**Evidência.** `compress/mode=0` em 82 `.import`; o `.ctex` guarda WebP lossless e a GPU recebe RGBA8 (4 bytes/px). VRAM se tudo estiver carregado: **66,1 MB** (82 arquivos com mipmap onde `mipmaps/generate=true`).

| Grupo | Arquivos | Tamanho | VRAM RGBA8 (est.) | Observação |
|---|---:|---|---:|---|
| `cordeis/*.jpg` (capas, `capa_de_cordel.gd:52`, usadas em quad 3D de `achados_vale.gd:376`) | 10 | 768x1152 | 45,0 MB | com mipmap; BC1 daria ~5,6 MB |
| `materiais/telha_colonial…png`, `cal_taipa…png` | 2 | 1254x1254, sem mipmap | 12,0 MB | `preload` em `world_builder.gd:24-25`, uso só no estilo procedural (`world_builder.gd:2146-2147`), mas carregados sempre |
| `materiais/chao_praca_v1.png`, `terra_batida_v1.png` | 2 | 1024x1024, sem mipmap | 8,0 MB | `chao_praca` só aparece como `const` em `geo_region_renderer.gd:19` (nenhum uso depois); `terra_batida_v1` não é citada em lugar nenhum |
| `identidade/cursores`, `sprites/itens`, `sprites/moradores` | 67 | 32x32 a 40x40 | <1 MB | ícones de 2D, normal ser lossless |

**Mecanismo.** RGBA8 é 8x BC1 e 4x BC3; sem mipmap em textura de 3D, cintila e gasta cache de textura. **Impacto:** baixo (66 MB, e só carregam as que são tocadas); confiança alta. **Correção de HOJE:** remover as 2 `preload` mortas, ou trocar `compress/mode` para 2 (VRAM) nos 4 de `materiais/` e nas capas de cordel; **Esforço:** 10 min. **Risco:** baixo; capa de cordel perde um pouco de qualidade em BC1 (usar BC3/`high_quality`). **Como medir:** HUD de VRAM.

### AST-11 — 15 texturas órfãs (25 MB) em 7 GLBs, 8 MB só no `viajante`; vão no PCK sem uso

**Evidência.** `orfas2.py` compara as imagens declaradas no JSON do GLB com os arquivos extraídos ao lado dele. Sete GLBs têm arquivos a mais, sobras de reexportação (nome da textura muda a cada exportação; `ASSETS_TRIPO.md:111-112` manda apagá-los):

| GLB | Arquivo órfão | Dimensão | Formato | `.ctex` MB |
|---|---|---|---|---:|
| itens/balde_tripo.glb | `tripo_image_3683fd65-5229-4571-9cde-f840add8eb11_0_0` | 1024x1024 | DXT1(BC1) | 0,67 |
| itens/balde_tripo.glb | `tripo_image_3683fd65-5229-4571-9cde-f840add8eb11_0_3` | 1024x1024 | RGTC_RG(BC5) | 1,33 |
| itens/cacho_banana_tripo.glb | `tripo_image_e1902eea-d9bb-45be-9c31-b68dbcac9deb_0_0` | 2048x2048 | DXT1(BC1) | 2,67 |
| itens/cacho_banana_tripo.glb | `tripo_node_122cdf7b-36f9-4276-a8c4-ab13482525b0_Normal_Bake` | 2048x2048 | RGTC_RG(BC5) | 5,33 |
| itens/enxada_tripo.glb | `enxada_tripo_metallic-enxada_tripo_roughness` | 1024x1024 | DXT1(BC1) | 0,67 |
| itens/enxada_tripo.glb | `tripo_image_f1fe20eb-6e5e-4aa7-b806-ca7320838a34_0_0` | 1024x1024 | DXT1(BC1) | 0,67 |
| itens/enxada_tripo.glb | `tripo_image_f1fe20eb-6e5e-4aa7-b806-ca7320838a34_0_3` | 1024x1024 | RGTC_RG(BC5) | 1,33 |
| itens/mandioca_tripo.glb | `tripo_image_bcd97ee2-564e-462e-b974-a8d9776db521_0_0` | 1024x1024 | DXT1(BC1) | 0,67 |
| itens/mandioca_tripo.glb | `tripo_image_bcd97ee2-564e-462e-b974-a8d9776db521_0_3` | 1024x1024 | DXT1(BC1) | 0,67 |
| itens/picareta_tripo.glb | `tripo_image_992252f1-18f2-4f4b-8c8c-1ad49e4703ec_0_0` | 1024x1024 | DXT1(BC1) | 0,67 |
| itens/picareta_tripo.glb | `tripo_image_992252f1-18f2-4f4b-8c8c-1ad49e4703ec_0_3` | 1024x1024 | DXT1(BC1) | 0,67 |
| itens/vara_pescar_tripo.glb | `tripo_image_9f82c606-8b5c-40c2-9208-bad8edd27000_0_0` | 1024x1024 | DXT1(BC1) | 0,67 |
| itens/vara_pescar_tripo.glb | `tripo_image_9f82c606-8b5c-40c2-9208-bad8edd27000_0_3` | 1024x1024 | RGTC_RG(BC5) | 1,33 |
| personagens/viajante_tripo.glb | `tripo_image_f596165b-833c-4074-b932-a792a1189f5c_0_0` | 2048x2048 | DXT1(BC1) | 2,67 |
| personagens/viajante_tripo.glb | `tripo_node_c381db0f-a1b6-4a63-b2f7-45d90b7b2eed_Normal_Bake` | 2048x2048 | RGTC_RG(BC5) | 5,33 |
| **soma** | 15 arquivos | | | **25,3** |

**Mecanismo.** O GLB declara 3 imagens; as órfãs não são citadas por ele (checado pelo nome da imagem no JSON), então o `.scn` não as carrega em VRAM; custam só PCK e importação. Efeito colateral: nas tabelas de `.ctex` por GLB, `viajante`, `cacho_banana`, `balde`, `enxada`, `mandioca`, `picareta` e `vara_pescar` aparecem com o tamanho inflado pelas órfãs. **Impacto:** baixo; confiança alta. **Correção:** apagar os 15 arquivos e seus `.import` (fora do repositório de leitura; fica para quem for editar). **Risco:** nenhum, se o `.glb.import` apontar para as 3 texturas certas (conferido pelo nome da imagem no JSON do GLB).

### AST-12 — Violações do orçamento do projeto (`ASSETS_TRIPO.md:142-152`)

**Evidência.** Classifiquei cada GLB pela pasta e pelo nome (destaque = `capela`, `igreja`, `casarao_fazenda`; casa comum = o resto de `construcoes/` e `casas/`; árvore nomeada = `arvores/*` sem sufixo; adereço = `aderecos/` + `moveis/`). O orçamento fala em "polígonos" = quads; usei **teto em triângulos = 2 × faces**. Bichos e peixes não têm linha na tabela: usei só o teto de textura 1K (`ASSETS_TRIPO.md:158`: "1K para tudo que é pequeno"). Violações:

| Tipo | Teto (faces / tris) | GLB | Tris | Excesso |
|---|---|---|---:|---:|
| aderecos | 3000 / 6000 | `aderecos/saveiro_tripo.glb` | 10.862 | +4.862 (81%) |
| aderecos | 3000 / 6000 | `aderecos/cabra_tripo.glb` | 7.244 | +1.244 (21%) |
| aderecos | 3000 / 6000 | `aderecos/barraca_feira_tripo.glb` | 6.114 | +114 (2%) |
| aderecos | 3000 / 6000 | `aderecos/monjolo_tripo.glb` | 6.074 | +74 (1%) |
| arvore | 10000 / 20000 | `arvores/mangueira_tripo.glb` | 20.453 | +453 (2%) |
| arvore_leve | 2500 / 5000 | `arvores/ipe_roxo_leve_tripo.glb` | 6.141 | +1.141 (23%) |
| arvore_leve | 2500 / 5000 | `arvores/piacava_leve_tripo.glb` | 5.894 | +894 (18%) |
| arvore_leve | 2500 / 5000 | `arvores/cajueiro_leve_tripo.glb` | 5.670 | +670 (13%) |
| arvore_leve | 2500 / 5000 | `arvores/jenipapeiro_leve_tripo.glb` | 5.652 | +652 (13%) |
| arvore_leve | 2500 / 5000 | `arvores/pau_brasil_leve_tripo.glb` | 5.629 | +629 (13%) |
| arvore_leve | 2500 / 5000 | `arvores/ipe_amarelo_leve_tripo.glb` | 5.612 | +612 (12%) |
| arvore_leve | 2500 / 5000 | `arvores/dendezeiro_leve_tripo.glb` | 5.583 | +583 (12%) |
| arvore_leve | 2500 / 5000 | `arvores/ingazeiro_leve_tripo.glb` | 5.426 | +426 (9%) |
| arvore_leve | 2500 / 5000 | `arvores/castanhola_leve_tripo.glb` | 5.308 | +308 (6%) |
| arvore_leve | 2500 / 5000 | `arvores/bananeira_leve_tripo.glb` | 5.219 | +219 (4%) |
| arvore_leve | 2500 / 5000 | `arvores/coqueiro_leve_tripo.glb` | 5.214 | +214 (4%) |
| arvore_leve | 2500 / 5000 | `arvores/clusia_leve_tripo.glb` | 5.165 | +165 (3%) |
| arvore_longe | 700 / 1400 | `arvores/mata_alta_longe_tripo.glb` | 2.100 | +700 (50%) |
| arvore_longe | 700 / 1400 | `arvores/mata_larga_longe_tripo.glb` | 2.059 | +659 (47%) |
| arvore_longe | 700 / 1400 | `arvores/bananeira_longe_tripo.glb` | 2.012 | +612 (44%) |
| arvore_longe | 700 / 1400 | `arvores/embauba_longe_tripo.glb` | 2.009 | +609 (44%) |
| arvore_longe | 700 / 1400 | `arvores/cajueiro_longe_tripo.glb` | 1.810 | +410 (29%) |
| arvore_longe | 700 / 1400 | `arvores/ingazeiro_longe_tripo.glb` | 1.794 | +394 (28%) |
| arvore_longe | 700 / 1400 | `arvores/aroeira_longe_tripo.glb` | 1.727 | +327 (23%) |
| arvore_longe | 700 / 1400 | `arvores/dendezeiro_longe_tripo.glb` | 1.716 | +316 (23%) |
| arvore_longe | 700 / 1400 | `arvores/mangueira_longe_tripo.glb` | 1.675 | +275 (20%) |
| arvore_longe | 700 / 1400 | `arvores/coqueiro_longe_tripo.glb` | 1.662 | +262 (19%) |
| arvore_longe | 700 / 1400 | `arvores/piacava_longe_tripo.glb` | 1.603 | +203 (14%) |
| arvore_longe | 700 / 1400 | `arvores/castanhola_longe_tripo.glb` | 1.485 | +85 (6%) |
| construcao_comum | 6000 / 12000 | `casas/casa_carro_quebrado_tripo.glb` | 12.477 | +477 (4%) |
| construcao_comum | 6000 / 12000 | `construcoes/mirante_tripo.glb` | 12.388 | +388 (3%) |
| construcao_comum | 6000 / 12000 | `construcoes/capelinha_tripo.glb` | 12.326 | +326 (3%) |
| item | 1500 / 3000 | `itens/luvas_de_couro_tripo.glb` | 3.154 | +154 (5%) |
| item | 1500 / 3000 | `itens/tabuleiro_tripo.glb` | 3.009 | +9 (0%) |
| item | 1500 / 3000 | `itens/balde_tripo.glb` | 3.004 | +4 (0%) |

Textura acima da regra: `aderecos/saveiro_tripo.glb` (2048 num adereço; intencional) e `personagem/medieval_character_animated.glb` (4096; não referenciado). Nenhuma outra. **Plano × realidade** (`plano.py`, 244 GLBs com plano em `tools/tripo/lote_*.json`): a textura real coincide com a planejada em **todos**; os triângulos reais ficam em 1,36 a 3,0 vezes as faces planejadas (mediana 1,92).

**Leitura.** As violações são pequenas (a maioria abaixo de 25%), exceto o saveiro (+81%), a cabra do Benedito `aderecos/cabra_tripo.glb` (+21%), os `_longe` (até +50%) e os `_leve` (até +23%). O problema não é desobediência à tabela; é que a tabela, aplicada em quantidade (23 casas, 22 moradores, 3 mil pés), já gera ~8-9 milhões de triângulos de pior caso. **Impacto:** baixo isolado; confiança alta. **Correção:** ver AST-02, AST-03, AST-05.

### AST-13 — Opções de importação dos 262 GLBs e das 953 texturas

| Opção | Valor | Quantos |
|---|---|---:|
| `meshes/generate_lods` | true | 262 |
| `meshes/create_shadow_meshes` | true | 262 |
| `meshes/ensure_tangents` | true | 262 |
| `meshes/light_baking` | 1 (estático) | 262 |
| `meshes/force_disable_compression` | false | 262 |
| `animation/import` | true | 262 |
| `animation/fps` | 30 | 262 |
| `animation/trimming` | false | 262 |
| `animation/remove_immutable_tracks` | true | 262 |
| `gltf/embedded_image_handling` | 1 (extrair texturas para arquivos) | 262 |
| `materials/extract` | 0 | 262 |
| `import_script/path` | vazio | 262 |
| `_subresources` | {} (nenhum override por mesh) | 262 |

| Textura `.import` | Valor | Quantos |
|---|---|---:|
| `compress/mode` | 2 (VRAM) | 871 |
| `compress/mode` | 0 (lossless) | 82 |
| `mipmaps/generate` | true / false | 881 / 72 |
| `process/size_limit` | 0 (sem limite) | 953 |
| `compress/normal_map` / `roughness/mode` | 1 (normal) / 1 | 229 |
| `compress/high_quality` | false (BC1/BC3/BC5, sem BC7) | 953 |
| `detect_3d/compress_to` | 0 (desligado) / 1 | 949 / 4 |

**Resultado.** Auto-LOD e malha de sombra existem em todos; nenhum GLB tem override de `_subresources` (por exemplo, `generate_lods` com `lod_bias` por malha ou `bake` de lightmap); `size_limit` está 0 em todas, então nada limita 2K/4K na importação, e é por isso que AST-06 tem solução de 1 linha por `.import`.

## Tabelas de apoio

### Top 40 por triângulos

| # | GLB | Tris | Textura | `.ctex` MB | Chaves do catálogo |
|---:|---|---:|---|---:|---|
| 1 | `arvores/mangueira_tripo.glb` | 20.453 | 2048² | 10,7 | mangueira |
| 2 | `personagem/medieval_character_animated.glb` | 18.686 | 4096² | 18,7 | NÃO REFERENCIADO |
| 3 | `arvores/mangue_tripo.glb` | 18.079 | 2048² | 10,7 | mangue |
| 4 | `construcoes/casarao_fazenda_tripo.glb` | 17.319 | 2048² | 10,7 | casarao_fazenda |
| 5 | `arvores/ingazeiro_tripo.glb` | 16.886 | 2048² | 8,0 | ingazeiro |
| 6 | `arvores/castanhola_tripo.glb` | 16.284 | 2048² | 8,0 | castanhola |
| 7 | `arvores/pau_brasil_tripo.glb` | 15.978 | 2048² | 4,7 | pau_brasil |
| 8 | `arvores/piacava_tripo.glb` | 15.792 | 2048² | 8,0 | piacava |
| 9 | `arvores/cajueiro_tripo.glb` | 15.420 | 2048² | 10,7 | cajueiro |
| 10 | `arvores/ipe_roxo_tripo.glb` | 15.418 | 2048² | 10,7 | ipe_roxo |
| 11 | `arvores/ipe_amarelo_tripo.glb` | 15.148 | 2048² | 10,7 | ipe_amarelo |
| 12 | `personagens/benedito_tripo.glb` | 15.119 | 1024² | 2,0 | benedito |
| 13 | `arvores/dende_tripo.glb` | 15.014 | 2048² | 10,7 | dendezeiro |
| 14 | `personagens/zefa_tripo.glb` | 14.970 | 1024² | 2,0 | zefa |
| 15 | `personagens/damiao_tripo.glb` | 14.881 | 1024² | 2,0 | damiao |
| 16 | `personagens/filo_tripo.glb` | 14.760 | 1024² | 2,0 | filo |
| 17 | `arvores/bananeira_tripo.glb` | 14.753 | 2048² | 10,7 | bananeira |
| 18 | `arvores/coqueiro_tripo.glb` | 14.716 | 2048² | 10,7 | coqueiro |
| 19 | `arvores/jaqueira_tripo.glb` | 14.680 | 2048² | 10,7 | jaqueira |
| 20 | `personagens/tonho_tripo.glb` | 14.576 | 1024² | 2,0 | tonho |
| 21 | `personagens/quirino_tripo.glb` | 14.509 | 1024² | 2,7 | quirino |
| 22 | `personagens/viajante_tripo.glb` | 14.461 | 1024² | 10,7 | viajante |
| 23 | `personagens/pedro_tripo.glb` | 14.400 | 1024² | 2,0 | pedro |
| 24 | `personagens/cosme_tripo.glb` | 14.399 | 1024² | 2,0 | cosme |
| 25 | `personagens/candinha_tripo.glb` | 14.218 | 1024² | 2,0 | candinha |
| 26 | `construcoes/igreja_tripo.glb` | 13.332 | 2048² | 10,7 | igreja |
| 27 | `arvores/aroeira_tripo.glb` | 13.225 | 1024² | 2,0 | aroeira |
| 28 | `casas/casa_carro_quebrado_tripo.glb` | 12.477 | 2048² | 10,7 | casa_carro_quebrado |
| 29 | `construcoes/mirante_tripo.glb` | 12.388 | 2048² | 8,0 | mirante |
| 30 | `construcoes/capelinha_tripo.glb` | 12.326 | 2048² | 10,7 | capelinha |
| 31 | `mar/tubarao_tripo.glb` | 12.131 | 1024² | 2,7 | tubarao |
| 32 | `arvores/jenipapeiro_tripo.glb` | 12.065 | 1024² | 2,0 | jenipapeiro |
| 33 | `construcoes/ponte_tripo.glb` | 11.914 | 2048² | 10,7 | ponte |
| 34 | `construcoes/capela_tripo.glb` | 11.775 | 2048² | 10,7 | capela |
| 35 | `construcoes/pier_tripo.glb` | 11.747 | 2048² | 10,7 | pier |
| 36 | `construcoes/casa_pasto_tripo.glb` | 11.654 | 2048² | 10,7 | casa_pasto |
| 37 | `arvores/gameleira_tripo.glb` | 11.646 | 2048² | 10,7 | gameleira |
| 38 | `personagens/mercador_tripo.glb` | 11.438 | 1024² | 2,7 | mercador |
| 39 | `personagens/pescador_tripo.glb` | 11.424 | 1024² | 2,7 | pescador |
| 40 | `personagens/beata_tripo.glb` | 11.351 | 1024² | 2,7 | beata |

### Top 40 por pixels de textura (soma dos 3 mapas)

Empates em 12,6 Mpx (3 × 2048²) são os GLBs em 2K; a lista completa está em `assets_glb.csv`.

| # | GLB | Mpx | `.ctex` MB | Tris | Chaves |
|---:|---|---:|---:|---:|---|
| 1 | `personagem/medieval_character_animated.glb` | 25,2 | 18,7 | 18.686 | NÃO REFERENCIADO |
| 2 | `arvores/mangueira_tripo.glb` | 12,6 | 10,7 | 20.453 | mangueira |
| 3 | `arvores/mangue_tripo.glb` | 12,6 | 10,7 | 18.079 | mangue |
| 4 | `construcoes/casarao_fazenda_tripo.glb` | 12,6 | 10,7 | 17.319 | casarao_fazenda |
| 5 | `arvores/ingazeiro_tripo.glb` | 12,6 | 8,0 | 16.886 | ingazeiro |
| 6 | `arvores/castanhola_tripo.glb` | 12,6 | 8,0 | 16.284 | castanhola |
| 7 | `arvores/piacava_tripo.glb` | 12,6 | 8,0 | 15.792 | piacava |
| 8 | `arvores/cajueiro_tripo.glb` | 12,6 | 10,7 | 15.420 | cajueiro |
| 9 | `arvores/ipe_roxo_tripo.glb` | 12,6 | 10,7 | 15.418 | ipe_roxo |
| 10 | `arvores/ipe_amarelo_tripo.glb` | 12,6 | 10,7 | 15.148 | ipe_amarelo |
| 11 | `arvores/dende_tripo.glb` | 12,6 | 10,7 | 15.014 | dendezeiro |
| 12 | `arvores/bananeira_tripo.glb` | 12,6 | 10,7 | 14.753 | bananeira |
| 13 | `arvores/coqueiro_tripo.glb` | 12,6 | 10,7 | 14.716 | coqueiro |
| 14 | `arvores/jaqueira_tripo.glb` | 12,6 | 10,7 | 14.680 | jaqueira |
| 15 | `construcoes/igreja_tripo.glb` | 12,6 | 10,7 | 13.332 | igreja |
| 16 | `casas/casa_carro_quebrado_tripo.glb` | 12,6 | 10,7 | 12.477 | casa_carro_quebrado |
| 17 | `construcoes/mirante_tripo.glb` | 12,6 | 8,0 | 12.388 | mirante |
| 18 | `construcoes/capelinha_tripo.glb` | 12,6 | 10,7 | 12.326 | capelinha |
| 19 | `construcoes/ponte_tripo.glb` | 12,6 | 10,7 | 11.914 | ponte |
| 20 | `construcoes/capela_tripo.glb` | 12,6 | 10,7 | 11.775 | capela |
| 21 | `construcoes/pier_tripo.glb` | 12,6 | 10,7 | 11.747 | pier |
| 22 | `construcoes/casa_pasto_tripo.glb` | 12,6 | 10,7 | 11.654 | casa_pasto |
| 23 | `arvores/gameleira_tripo.glb` | 12,6 | 10,7 | 11.646 | gameleira |
| 24 | `construcoes/casa_taipa_tripo.glb` | 12,6 | 10,7 | 11.343 | casa_taipa |
| 25 | `construcoes/venda_tripo.glb` | 12,6 | 10,7 | 11.287 | venda |
| 26 | `construcoes/casa_meia_agua_tripo.glb` | 12,6 | 10,7 | 10.905 | casa_meia_agua |
| 27 | `aderecos/saveiro_tripo.glb` | 12,6 | 10,7 | 10.862 | saveiro |
| 28 | `construcoes/sobrado_tripo.glb` | 12,6 | 10,7 | 10.669 | sobrado |
| 29 | `construcoes/cadeia_tripo.glb` | 12,6 | 10,7 | 10.405 | cadeia |
| 30 | `construcoes/casa_taipa_ocre_tripo.glb` | 12,6 | 10,7 | 10.402 | casa_taipa_ocre |
| 31 | `construcoes/casa_palha_tripo.glb` | 12,6 | 10,7 | 10.400 | casa_palha |
| 32 | `construcoes/casa_varanda_tripo.glb` | 12,6 | 10,7 | 10.285 | casa_varanda |
| 33 | `construcoes/casa_taipa_rosa_tripo.glb` | 12,6 | 10,7 | 10.220 | casa_taipa_rosa |
| 34 | `construcoes/casa_farinha_tripo.glb` | 12,6 | 10,7 | 10.027 | casa_farinha |
| 35 | `construcoes/casa_pescador_tripo.glb` | 12,6 | 10,7 | 9.961 | casa_pescador |
| 36 | `construcoes/casa_paroquial_tripo.glb` | 12,6 | 10,7 | 9.895 | casa_paroquial |
| 37 | `construcoes/casa_taipa_azul_tripo.glb` | 12,6 | 10,7 | 9.529 | casa_taipa_azul |
| 38 | `construcoes/casa_taipa_verde_tripo.glb` | 12,6 | 10,7 | 9.297 | casa_taipa_verde |
| 39 | `construcoes/portao_fazenda_tripo.glb` | 12,6 | 10,7 | 6.006 | portao_fazenda |
| 40 | `arvores/pau_brasil_tripo.glb` | 6,3 | 4,7 | 15.978 | pau_brasil |

### Os 40 maiores `.ctex` (origem, formato)

| # | `.ctex` MB | Dimensão | Formato | Origem |
|---:|---:|---|---|---|
| 1 | 10,67 | 4096x4096 | DXT1(BC1) | `personagem/medieval_character_animated_medieval_character_3d_model_basecolo...` |
| 2 | 5,33 | 2048x2048 | RGTC_RG(BC5) | `aderecos/saveiro_tripo_tripo_node_6d24dbc5-9fbf-458d-8a23-7bf3f7395985_Norm...` |
| 3 | 5,33 | 2048x2048 | RGTC_RG(BC5) | `arvores/bananeira_tripo_tripo_node_4040d6e4-8340-4dff-ba6a-c956af0a5c7b_Nor...` |
| 4 | 5,33 | 2048x2048 | RGTC_RG(BC5) | `arvores/cajueiro_tripo_tripo_image_1fafb40d-486f-4b54-81cb-0556e9e99fb9_0_3...` |
| 5 | 5,33 | 2048x2048 | RGTC_RG(BC5) | `arvores/coqueiro_tripo_tripo_node_0eba1d4f-f108-420a-b56d-6da40f9da053_Norm...` |
| 6 | 5,33 | 2048x2048 | RGTC_RG(BC5) | `arvores/dende_tripo_tripo_node_cb0e76f7-55a0-492a-b348-71b7a0958be5_Normal_...` |
| 7 | 5,33 | 2048x2048 | RGTC_RG(BC5) | `arvores/gameleira_tripo_tripo_node_292a8bae-8ae7-4921-8c60-423e1ecf83e1_Nor...` |
| 8 | 5,33 | 2048x2048 | RGTC_RG(BC5) | `arvores/ipe_amarelo_tripo_tripo_node_9013cf3a-a0ea-4ae1-9c66-33064c832e09_N...` |
| 9 | 5,33 | 2048x2048 | RGTC_RG(BC5) | `arvores/ipe_roxo_tripo_tripo_node_dfa4905a-f706-4800-87d7-37cc2749d46b_Norm...` |
| 10 | 5,33 | 2048x2048 | RGTC_RG(BC5) | `arvores/jaqueira_tripo_tripo_image_c555017f-f0a9-4acb-adf7-e1c390110f53_0_3...` |
| 11 | 5,33 | 2048x2048 | RGTC_RG(BC5) | `arvores/mangueira_tripo_tripo_image_abe689bd-9eb4-4fdd-8b09-d3447072f725_0_...` |
| 12 | 5,33 | 2048x2048 | RGTC_RG(BC5) | `arvores/mangue_tripo_tripo_node_611574ab-ba94-4a1e-9633-c6a31f9879a3_Normal...` |
| 13 | 5,33 | 2048x2048 | RGTC_RG(BC5) | `casas/casa_carro_quebrado_tripo_tripo_image_a411570a-eaa6-4a7a-a3e8-f712362...` |
| 14 | 5,33 | 2048x2048 | RGTC_RG(BC5) | `construcoes/cadeia_tripo_tripo_node_2f2747da-db18-4894-a51b-de20ae73226b_No...` |
| 15 | 5,33 | 2048x2048 | RGTC_RG(BC5) | `construcoes/capela_tripo_tripo_image_7d980e8a-fc3b-45ff-bb6a-f439a9e2a5ae_0...` |
| 16 | 5,33 | 2048x2048 | RGTC_RG(BC5) | `construcoes/capelinha_tripo_tripo_node_64edc23b-9af4-41be-9e93-e1195135c7c8...` |
| 17 | 5,33 | 2048x2048 | RGTC_RG(BC5) | `construcoes/casarao_fazenda_tripo_tripo_node_9911ecc0-dc6a-4d2e-93f7-16d700...` |
| 18 | 5,33 | 2048x2048 | RGTC_RG(BC5) | `construcoes/casa_farinha_tripo_tripo_node_b832ea91-5441-41d5-9210-c337579a8...` |
| 19 | 5,33 | 2048x2048 | RGTC_RG(BC5) | `construcoes/casa_meia_agua_tripo_tripo_node_5da44fb8-003b-4e8c-9ddc-dc76b26...` |
| 20 | 5,33 | 2048x2048 | RGTC_RG(BC5) | `construcoes/casa_palha_tripo_tripo_node_0658f0c2-1289-4ff7-b6f1-f6010935f75...` |
| 21 | 5,33 | 2048x2048 | RGTC_RG(BC5) | `construcoes/casa_paroquial_tripo_tripo_node_f738fcb9-b86c-4529-834d-72d3dd6...` |
| 22 | 5,33 | 2048x2048 | RGTC_RG(BC5) | `construcoes/casa_pasto_tripo_tripo_node_416588f0-a280-4dc4-aa99-8e1354bac28...` |
| 23 | 5,33 | 2048x2048 | RGTC_RG(BC5) | `construcoes/casa_pescador_tripo_tripo_node_1a0e2deb-69fc-427d-8d3c-c10e7cfe...` |
| 24 | 5,33 | 2048x2048 | RGTC_RG(BC5) | `construcoes/casa_taipa_azul_tripo_tripo_node_400778f1-f9e2-41cb-ba7d-2b801c...` |
| 25 | 5,33 | 2048x2048 | RGTC_RG(BC5) | `construcoes/casa_taipa_ocre_tripo_tripo_node_74950a83-5599-4830-affa-965f14...` |
| 26 | 5,33 | 2048x2048 | RGTC_RG(BC5) | `construcoes/casa_taipa_rosa_tripo_tripo_node_5249c595-0bc5-47c9-a80d-44fadd...` |
| 27 | 5,33 | 2048x2048 | RGTC_RG(BC5) | `construcoes/casa_taipa_tripo_tripo_image_1a6a166c-c665-4442-8d7c-2e7c94591c...` |
| 28 | 5,33 | 2048x2048 | RGTC_RG(BC5) | `construcoes/casa_taipa_verde_tripo_tripo_node_c7ed4ffc-35cf-4269-9de4-fc75d...` |
| 29 | 5,33 | 2048x2048 | RGTC_RG(BC5) | `construcoes/casa_varanda_tripo_tripo_node_36dd845a-d2dc-478e-a27f-a285467fc...` |
| 30 | 5,33 | 2048x2048 | RGTC_RG(BC5) | `construcoes/igreja_tripo_tripo_node_89e692ef-87b5-408b-b25f-1a175b224dfe_No...` |
| 31 | 5,33 | 2048x2048 | RGTC_RG(BC5) | `construcoes/pier_tripo_tripo_node_c3126ae2-b7d7-4877-9f48-ec9fce282898_Norm...` |
| 32 | 5,33 | 2048x2048 | RGTC_RG(BC5) | `construcoes/ponte_tripo_tripo_node_15d6687b-90a4-4e21-8c50-e5bbd832e3a8_Nor...` |
| 33 | 5,33 | 2048x2048 | RGTC_RG(BC5) | `construcoes/portao_fazenda_tripo_tripo_node_b285cf61-42c6-4152-82a0-f8da463...` |
| 34 | 5,33 | 2048x2048 | RGTC_RG(BC5) | `construcoes/sobrado_tripo_tripo_node_f06acba9-9472-4c79-abdc-9463aac2c90c_N...` |
| 35 | 5,33 | 2048x2048 | RGTC_RG(BC5) | `construcoes/venda_tripo_tripo_node_47b981d1-bae3-4826-b219-f6e369957eeb_Nor...` |
| 36 | 5,33 | 2048x2048 | RGTC_RG(BC5) | `itens/cacho_banana_tripo_tripo_node_122cdf7b-36f9-4276-a8c4-ab13482525b0_No...` |
| 37 | 5,33 | 2048x2048 | RGTC_RG(BC5) | `personagem/medieval_character_animated_medieval_character_3d_model_normal.jpg` |
| 38 | 5,33 | 2048x2048 | RGTC_RG(BC5) | `personagens/viajante_tripo_tripo_node_c381db0f-a1b6-4a63-b2f7-45d90b7b2eed_...` |
| 39 | 2,67 | 2048x2048 | DXT1(BC1) | `aderecos/saveiro_tripo_saveiro_tripo_metallic-saveiro_tripo_roughness.png` |
| 40 | 2,67 | 2048x2048 | DXT1(BC1) | `aderecos/saveiro_tripo_tripo_image_789c2612-c4c3-4f2e-8c51-9bcdf2059663_0_0...` |

O maior `.ctex` do projeto é a cor 4K do modelo medieval (10,7 MB), depois o normal BC5 2K (5,33 MB, um por GLB em 2K) e as cores BC1 2K (2,67 MB). Os 37 itens seguintes ao medieval são normais BC5 de 2K: 37 GLBs em 2K × 5,33 MB = 197 MB só em normal.

**`.ctex` fora de GLB, por categoria** (VRAM comprimida; lossless pelo tamanho do WebP):

| Categoria | Arquivos | `.ctex` MB |
|---|---:|---:|
| `prototipo_3d/materiais` | 21 | 24,8 |
| `prototipo_3d/cordeis` | 10 | 17,9 |
| `prototipo_3d/identidade` | 17 | 6,1 |
| `sprites/moradores` | 7 | 0,4 |
| `sprites/talentos` | 39 | 0,1 |
| `sprites/itens` | 57 | 0,0 |
| `ui` | 1 | 0,0 |

### VRAM de textura: cenários

Conta: `.ctex` BC1 = 0,5 B/px, BC3/BC5 = 1 B/px, lossless RGBA8 = 4 B/px, +33% de mipmaps (os `.ctex` de GLB já incluem). Os tamanhos de GLB abaixo vêm dos `.ctex` reais.

| Cenário | Texturas de GLB (MB) | Outras texturas (MB) | Total (MB) | GB |
|---|---:|---:|---:|---:|
| A. tudo que existe em `assets/` (262 GLBs) | 1013 | 92 | 1104 | 1,08 |
| B. só os GLBs do catálogo, sem as texturas órfãs | 966 | 92 | 1058 | 1,03 |
| C. B sem os 24 GLBs candidatos a mortos | 881 | 92 | 972 | 0,95 |
| D. B com os 40 GLBs de 2K+ reduzidos a 1K | 653 | 92 | 744 | 0,73 |
| E. D sem normais das classes item, adereço, móvel, `_leve`, `_longe`, bicho, peixe (est. 210 MB) | 443 | 92 | 534 | 0,52 |

**Comparação com placas.** GTX 1660 Ti: 6 GB; cenário B usa ~17% só de textura. Placas de 4 GB (GTX 1650, RX 570): B = 26%. Placas de 2 GB (ex.: GT 1030): B = 52%; somando alvos de render, atlas de sombra e buffers do Forward+ a 1080p com MSAA 2x (**estimativa de ordem de grandeza**, a medir: cor RGBA16F com 2 amostras ~35-70 MB + profundidade ~17 MB + atlas de sombra direcional 4096² e posicional 4096² ~65-135 MB + geometria ~100 MB, sem contar pós-processamento), o total fica em ~1,3 a 1,4 GB com o cenário B e se aproxima do limite de uma placa de 2 GB quando o sistema e outros buffers entram; o cenário D (~0,75 GB de textura) devolve folga.

Geometria na VRAM (estimativa): 2.101.705 vértices × ~28 B (posição, normal+tangente octaédricas, UV, skin quando houver) ≈ 56 MB se todos os GLBs estivessem carregados, +LODs +malha de sombra. Migalha frente à textura.

### Texturas de interface, menus e identidade

| Arquivo | Dimensão | Formato | `.ctex` MB | Uso | Veredito |
|---|---|---|---:|---|---|
| `identidade/capa_dia.webp` | 2048x1152 | DXT1(BC1) | 1,50 | tela_carregamento.gd:16 | adequado: 2048x1152 é 1,07x a tela 1920x1080 |
| `identidade/capa_noite.webp` | 2048x1152 | DXT1(BC1) | 1,50 | tela_carregamento.gd:17 | adequado: 2048x1152 é 1,07x a tela 1920x1080 |
| `identidade/moldura_retabulo.png` | 996x1504 | DXT5(BC3) | 1,91 | (nenhuma citação em código) | sem uso detectado: candidato a remover |
| `identidade/logo_myths_valley.png` | 1496x432 | DXT5(BC3) | 0,82 | identidade.gd | adequado |
| `identidade/rosa_dos_ventos.png` | 512x512 | DXT5(BC3) | 0,33 | identidade.gd | adequado |

As capas pintadas do menu e do carregamento (`capa_dia`, `capa_noite`) têm 2048x1152, BC1, 1,5 MB cada: **estão ok**. Os retratos de morador em `sprites/moradores/` têm 192x336 e 0,08 MB: ok. Os cordéis são o único grupo de UI/3D em lossless (AST-10). Os ladrilhos de terreno em `materiais/` têm 1024x1024 a 1256x1256 em BC1/BC3, 21 arquivos, 25 MB: ok para chão que cobre todo o vale.

## O que está OK

- **Nenhum GLB é ponteiro Git LFS** na árvore de trabalho; todos os 262 abrem como GLB válido (`inventario_glb.py`, 0 erros). No git eles são ponteiros: um clone sem `git lfs pull` quebra o build.
- **Compressão de textura**: 871 de 953 `.import` usam VRAM comprimido (BC1/BC3/BC5) com mipmaps; nenhuma textura 3D de GLB está sem compressão (`importer_defaults`, `project.godot:78-85`). Os 82 lossless são cursores, ícones, 10 capas de cordel e 4 materiais (AST-10).
- **Um material, uma primitiva, uma malha por GLB**: não há GLB com dezenas de superfícies; o custo de draw call por instância é 1 (somado em sombras).
- **Nenhum material com alpha blend** (`alphaMode` OPAQUE nos 262), então não há ordenação de transparência nem overdraw de folhagem em `BLEND`.
- **Sem Draco/meshopt/basisu**: o Godot lê GLB normal; nada para descomprimir em runtime.
- **Todo GLB referenciado existe** (`CatalogoAssets.faltando` ficaria vazio): as 264 chaves apontam para 260 arquivos reais.
- **Textura 1K para itens e adereços**: só o saveiro (2K, intencional) viola a regra; plano do Tripo e realidade coincidem em 244 GLBs.
- **Orçamento de triângulos** do projeto é respeitado de modo geral (dos 35 GLBs que estouram, 24 passam menos de 25%) quando se lê "polígonos" como quads.
- **Interface e menu**: capas, logo, retratos e moldura em compressão adequada e tamanho compatível com a tela.
- **Animações**: `animation/fps=30` e `remove_immutable_tracks=true` já reduzem a trilha; os GLBs dos moradores têm 6 a 13 clipes, mas só 1 toca de cada vez.
- **Tamanho individual**: o maior GLB tem 12,7 MB (mangueira); o maior `.scn` tem 2,0 MB (mercador, por causa dos 13 clipes de animação), a média é 345 KB; nada gigante isolado.

## Dúvidas para medição A/B

- **Auto-LOD funciona?** Em tempo de execução, com a câmera parada no arraial, aumentar `get_viewport().mesh_lod_threshold` de 1 para 8 e ler `Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME` (e o HUD de tri). Se o número cai, há LOD em uso e o padrão 1 pixel é conservador; se não muda, o `.scn` não tem LODs úteis (Tripo/UV) e vale confiar só nas variantes `_leve`/`_longe`. Nó/propriedade: `Viewport.mesh_lod_threshold`; setting global `rendering/mesh_lod/lod_change/threshold_pixels`.
- **Dupla face custa quanto?** Mesmo quadro, mesmo ângulo: ligar/desligar `cull_mode = CULL_BACK` em todos os `StandardMaterial3D` dos GLBs do mundo (função única, AST-01). Medir ms de GPU e primitivas. Esperado: maior ganho em cenas com muita casa e árvore; risco de buracos.
- **Esqueletos custam quanto?** Desligar `process_mode` de todos os `AnimationPlayer`/`AnimationTree` dos moradores e quadrúpedes (ou `visible=false` nos `MeshInstance3D` skinados) e comparar `Performance.TIME_PROCESS` e GPU. Se o ganho for >5 ms, aplicar animação por distância.
- **Qual a fatia do paisagismo?** Esconder o nó que contém as `MultiMesh` do paisagismo (`PaisagismoVale` / blocos) e depois só as de `bananeira_leve`; comparar triângulos e ms de GPU. Esperado: bananal + roças dominam (estimativa AST-03).
- **A textura 2K ou o normal pesa no FPS?** Trocar `normal_texture` por null nos materiais das classes pequenas e, em outro teste, forçar `Viewport.texture_mipmap_bias` (ou `rendering/textures/default_filters/texture_mipmap_bias`) +1 para simular 1K. Se o FPS não muda, textura é só questão de VRAM/PCK.
- **LOD de `MultiMesh` respeita o auto-LOD por instância?** Suspeita (não confirmada): o LOD é escolhido uma vez por `MultiMeshInstance3D`, pela distância ao nó, não por instância. Conferir olhando contagem de primitivas ao afastar a câmera de um bloco único (há blocos de 40 u, o que mitiga).
- **Quantos pés o paisagismo planta de fato?** Ler o número impresso no log de montagem (`paisagismo_vale.gd`, sorteio com reservas) e comparar com a estimativa de 2.378 (minha) e 3.026 (`paisagismo_sim.txt`).
- **VRAM real** HUD de VRAM (`prototype_hud.gd`) logo após o vale carregar, antes de andar; comparar com B = ~1.060 MB de textura de assets. Diferença grande = textura que não deveria carregar (cordéis, materiais procedurais, GLBs candidatos a mortos).
- **Zstd dos `.scn`** Os `.scn` têm cabeçalho `RSCC` modo 2 (Zstd); a biblioteca padrão do Python 3,13 não lê. A contagem de LODs por malha só sai de dentro do Godot (`ImporterMesh`/`ArrayMesh.surface_get_lod...` ou `RenderingServer.mesh_get_surface`).

## Como reproduzir

Todos os scripts estão em `scratchpad/perf/`, só biblioteca padrão do Python 3,13: `inventario_glb.py` (cabeçalho GLB, CSV), `analise_import.py` (`.import` e `.ctex`), `cruza.py` (catálogo, classes, violações), `multiplica.py` (censo × triângulos/ossos), `usadas.py` (chaves com referência literal), `mats.py` (materiais), `orfas2.py` (texturas órfãs), `plano.py` (plano do Tripo × real), `compo.py` (composição), `paisagismo_est.py` (área × densidade), `mais.py` (papéis de textura e VRAM). Nada foi gravado no repositório; o Godot não foi executado.
