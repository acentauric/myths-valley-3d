# Myths' Valley 3D — Investigação do pipeline de carregamento (escopo CAR)

Data: 05/10/2026 · Repositório: `C:\VIRTUALENVS\myths-valley\myths-valley-3D` · branch main, commit `eb430e4`, árvore limpa · Godot 4.7.2 (Forward+/Vulkan).
Método: só leitura do código, dos dados e do cache de importação; scripts auxiliares em Python (biblioteca padrão) gravados em `scratchpad\perf\`. O Godot NÃO foi executado por mim: nenhum tempo abaixo é medido por este relatório. Onde aparece "estimativa", a conta está mostrada e o item vai para a seção de medição A/B. "MB" = MiB (1.048.576 bytes). Caminhos são relativos à raiz do repositório.

---

## Resumo

1. **O vale é montado DUAS vezes por partida** (uma atrás do menu para o sobrevoo, outra ao clicar JOGAR): `abertura.tscn` e `vale.tscn` têm, os dois, um nó `Cenario` com `world_builder.gd` (que se monta sozinho no `_ready`). Nada gravado em disco é reaproveitado; só os caches estáticos do `CatalogoAssets` (PackedScenes de GLB, malhas medidas) sobrevivem à troca de cena. Toda volta ao menu e toda troca de estilo montam de novo (3ª, 4ª vez). É o maior desperdício estrutural do carregamento.
2. **A geometria determinística é refeita em GDScript a cada montagem**: terreno drapeado (estimado em 50 a 100 mil triângulos, com recursão por triângulo), colisão trimesh, fitas de rua/rio/praia, mapa de solo, sorteio de 6.234 árvores da mata (até 218 mil tentativas), paisagismo. Nenhuma dessas saídas é assada em disco, e quase nada roda em thread.
3. **Os GLBs e as texturas entram sob demanda, de forma síncrona, na thread principal** (`CatalogoAssets.cena()` usa `load()`, `catalogo_assets.gd:392`). Não há pré-carga: nem durante a escolha de idioma, nem durante o menu. Moradores, bichos e peixes só carregam DEPOIS de a barra chegar a 100%. O pacote agora é de **1.183 MB importados** (991 MB de textura só nos 260 GLBs do catálogo; 119 texturas são 2K, em 40 GLBs que somam 416 MB), contra o exe de 515 MB da build #7: o próximo exe tende a ~1,3 GB (estimativa).
4. **Há trabalho grande depois do 100%** (`prototype.gd:_ready`): salas internas (8+ quadros de física), parse síncrono da malha de navegação, 22 moradores + Pedro, ~71 bichos (22 corpos + 49 aves em 10 bandos, números do briefing), peixes, HUD e telas, retratos em 8 SubViewports. Acontece com a tela de carregamento já em fade: o jogador vê "terminou, mas congelou".
5. **Não existe aquecimento de shader/pipeline**: o mundo fica `visible = false` até o fim e os pipelines compilam no primeiro quadro visível. O preset de exportação não liga o "Shader Baker". Numa máquina nova (banca avaliadora), caches `user://shader_cache` (14 MB, 160 arquivos aqui) e `user://vulkan` (28,6 MB aqui) começam vazios.
6. **Medições feitas rodando pelo binário do editor** (`jogar.ps1` abre `Godot_v4.7.2-stable_win64.exe --path`) são pessimistas frente à exportação release (README.md:194): o binário do editor é build de depuração/ferramentas.
7. Migalhas (conferidas): JSON/data (todo `data/` ≈ 1 MB), autoloads no `_ready`, a própria tela de carregamento, `Atualizacao` (assíncrona e só na exportação), MCPRuntime (mudo na exportação), leitura de `terreno_editavel.tscn` e `ruas_referencia.tscn` (ninguém lê em execução).
8. Ações de HOJE com melhor razão ganho/risco: (a) medir a diferença abertura×vale com `medir_carregamento.gd` (já revela o custo "frio" dos assets); (b) pré-carregar GLBs em threads (a ferramenta já tem o A/B `--precarregar=1`); (c) segurar a tela até o `_ready` do vale acabar e fazer 3 a 4 quadros de aquecimento com o mundo visível por baixo da tela opaca; (d) ligar o Shader Baker na exportação, se o 4.7.2 o oferecer. Estruturais: reaproveitar o `Cenario` do menu no vale (meio dia, risco médio), assar terreno/colisão/mata em disco (1 a 3 dias), menu aparecer antes de o vale terminar.

---

## Fatos contados

| Fato | Valor | Fonte |
|---|---|---|
| Autoloads | 39 (38 `.gd` + `MCPRuntime` por uid) | `project.godot:21-61` |
| Fecho de scripts dos autoloads (preload/load literal + uso de `class_name`) | 45 scripts, 514 KB (limite inferior) | `perf\fecho_scripts.py` |
| Todos os scripts | 150 `.gd`, 2.418 KB | idem |
| Fecho de `abertura.gd` / `world_builder.gd` / `prototype.gd` / `inicio.gd` | 22 sc. 383 KB / 23 sc. 571 KB / 84 sc. 1.351 KB / 7 sc. 117 KB | idem |
| `Cenario` com `world_builder.gd` em AMBAS as cenas | abertura.tscn e vale.tscn | `scenes/prototipo_3d/abertura.tscn:4,10-11`; `scenes/prototipo_3d/vale.tscn:4,12-13` |
| Comentário dos autores: montagem "29 s ... duas vezes (menu e jogo)" (antes da otimização de 02/10) | duas montagens | `scripts/prototipo_3d/geo_region_renderer.gd:149-155` |
| Montagem caiu de ~29 s para ~5 s (headless, CPU) em 02/10; carga até o menu de ~34 s para ~7 s | só antes das integrações de 04-05/10 | `docs/projeto/CHANGELOG_3D.md:903-907` |
| Orçamento por quadro cedido à tela | 80.000 µs (80 ms) em dois lugares | `world_builder.gd:674`, `geo_region_renderer.gd:70` |
| Fatia da barra para arquivos | 25% (`FATIA_ARQUIVOS`) | `tela_carregamento.gd:449` |
| V-Sync desligado só depois de 2 quadros da troca de cena | `window_set_vsync_mode(VSYNC_DISABLED)` | `tela_carregamento.gd:480-488, 506` |
| Espera fixa antes de iniciar a carga (idioma) | 0,25 s | `inicio.gd:270` |
| Fade final da tela | 0,35 s | `tela_carregamento.gd:509-511` |
| Mapa: escala | 4 m/unidade, exagero vertical 2 | `data/mapas/regioes.json` |
| Mapa: limites | 3.614 x 2.033 m = 904 x 508 u; quadro do mapa 459.272 u² | `bom_jesus_dos_pobres_cenario.json`, `perf\estimar_terreno.py` |
| Polígono de terra | 137 pontos, 263.351 u² (4,21 km²) | idem |
| Ruas / rios / POIs / áreas | 8 ruas (1.426 u), 2 rios (527 u), 12 POIs, 3 áreas | `bom_jesus_dos_pobres.json` |
| Triângulos do terreno drapeado (ESTIMATIVA) | 33 a 66 mil na base (área média 4 a 8 u² por folha) + 17 a 34 mil na faixa fina dos rios (células de 0,8 u) = 50 a 100 mil | `geo_region_renderer.gd:76,1068-1094`; conta em `perf\estimar_terreno.py` |
| Árvores da mata: alvo / tentativas máximas / semente | 6.234 / 218.190 (=alvo x 35) / 1887 | `cenario.json` (vegetation); `geo_region_renderer.gd:1818-1830` |
| Sub-bosque | 1 tufo a cada 3 árvores (~2 mil) | `geo_region_renderer.gd:2020` |
| Blocos de MultiMesh | 40 u de lado; LOD 85 a 280 u | `geo_region_renderer.gd:187-197` |
| Fundo do mar (malha com relevo no shader) | 275 x 250 quadrados = 137.500 triângulos + 96 x 96 = 18.432 do fundo distante (cálculo) | `mar.gd:10-12,62-67,238-253`; batimetria 550 x 500 em `cenario.json` |
| Batimetria lida do disco | 550.000 B (float16) | `data/mapas/bom_jesus_dos_pobres_batimetria.bin` |
| Mapa de solo | 5 camadas L8, ~590 x 512 px (~302 mil px) cada; limites do polígono de terra 586 x 508 u | `mapa_de_solo.gd:36-44` |
| Peças do catálogo | 264 chaves, 260 GLBs únicos | `catalogo_assets.gd:22-357`; `perf\analisa_pecas.py` |
| GLBs citados por nome em scripts/data/scenes | 215 (os outros 45 são `_longe`/`_leve`, espécies sem citação literal) | `perf\chaves_usadas.py` |
| GLBs fonte | 933 MB (260 arquivos) | `perf\analisa_pecas.py` |
| `.scn` importados dos GLBs do catálogo | 86 MB (compactados em zstd, "RSCC") | idem |
| Texturas (`.ctex`) referenciadas pelos 260 GLBs | 991 MB em 795 texturas: 676 de 1K e 119 de 2K | idem |
| GLBs com conjunto 2K (10,67 MB cada) | 40 GLBs = 416 MB (23 construções, 13 árvores nomeadas, viajante, cacho_banana, saveiro) | idem |
| Conjunto importado vivo em `.godot/imported` | 1.322 importações = 1.183 MB (jpg 777, png 284, glb 88, áudio 29) | `perf\conjunto_vivo.py` |
| Cache local de importação estava incompleto no início desta investigação | 463 ctex/492 MB (números do briefing) -> completado pelo editor do coordenador durante o trabalho (957 ctex; 0 destinos faltando) | `.godot/imported` |
| Exe da build #7 / zip | 540.764.864 B (515,7 MB), PCK embutido ≈ 431 MB; zip 359 MB | `build/windows/MythsValley3D.exe`, `build/*.zip` |
| Exe esperado do próximo build (ESTIMATIVA) | 109 MB (template release) + ~1.183 MB (PCK) ≈ 1,3 GB; zip ≈ 0,86 GB (razão 0,665 da build #7) | `%APPDATA%\Godot\export_templates\4.7.2.stable\windows_release_x86_64.exe` |
| Texturas importadas: modo | VRAM comprimida (`compress/mode`=2), mipmaps ligados | `project.godot:78-85` |
| Importador dos GLBs | `embedded_image_handling=1` (extrai texturas), `generate_lods=true`, `create_shadow_meshes=true`, `ensure_tangents=true` | `assets/prototipo_3d/arvores/aroeira_tripo.glb.import` |
| Preset de exportação | `all_resources`, `embed_pck=true`, filtros `*.json, data/mapas/*.bin`; exclui `scratch tests tools docs concepts`; sem opção de Shader Baker | `export_presets.cfg:8-25` |
| Exportação documentada | `--export-release 'Windows Desktop'` | `README.md:194` |
| Como o autor roda o jogo | `jogar.ps1` -> `--editor --import` e depois `Godot_v4.7.2-stable_win64.exe --path` (binário do editor) | `tools/prototipo_3d/jogar.ps1:1-20` |
| Tela cheia / MSAA | `window/size/mode=3`, `msaa_3d=1` (2x) | `project.godot:67,97` |
| Caches da máquina do autor | `user://shader_cache` 14 MB/160 arquivos (72 de SceneForwardClustered); `user://vulkan` 28,6 MB + 13,7 MB do editor | `%APPDATA%\MythsValleyPrototype3D\` |
| Threads no projeto | só `load_threaded_request` da cena (`tela_carregamento.gd:454`), a assada de navegação assíncrona (`navegacao_vale.gd:116`), `Thread` da atualização (`atualizacao.gd:209`) | grep em `scripts/` |
| Callbacks GDScript por nó adicionado | 3 (`audio.gd:577`, `estilo.gd:25`, `tela.gd:66`) | idem |
| Pós-100%: moradores / Pedro | 22 + 1 | `data/npcs_3d.json`; `prototype.gd:1080-1123` |
| Pós-100%: retratos | 8 (Pedro + 7 de `Afinidade.MORADORES`), SubViewport 256 px, MSAA 4x | `retratos_3d.gd:37,89-150`; `afinidade.gd:52`; `prototype.gd:1024-1030` |
| Pós-100%: salas internas | 4 construções, 2 quadros de física cada (>= 8 quadros) | `interiores.gd:61-73,91-96,294-295` |
| Documentação de FPS posterior às otimizações de LOD (contexto, fora do escopo CAR) | 12,6 a 32,8 FPS em 30/09, mesmo com o LOD ligado | `docs/mundo/VALE_VIVO_3D.md:161-165`; `copas_distantes.gd:12` ("perto de 20 FPS") |

---

## Linha do tempo do carregamento (pergunta 1)

Legenda: [T] = thread principal, [F] = thread de fundo, [G] = GPU/driver, [D] = disco.

**T0 · duplo clique no exe.** Windows lê o exe com PCK embutido (build #7: 541 MB; próximo: ~1,3 GB, estimativa). Na primeira execução vindo de um zip baixado entram antivírus/SmartScreen (não medido aqui; é comportamento geral do Windows para exe sem assinatura).

**T1 · motor.** Vulkan 1.4 / GTX 1660 Ti Max-Q, leitura dos caches `user://shader_cache` e `user://vulkan/pipelines.forward_plus...cache`, índice do PCK. Em máquina nova esses dois caches não existem.

**T2 · 39 autoloads** (ordem de `project.godot:23-61`). Custo vem de parse/compilação de scripts (45 scripts, 514 KB no fecho) e de montar UI de autoload no `_ready`: `Mochila`, `Folheto`, `Amanhecer` e `Dialogo` chamam `_montar()` (CanvasLayer invisível). `Audio` cria 2 barramentos e 7 players e NÃO pré-carrega áudio (`audio.gd:113-131`; `_carregar` é `load()` sob demanda, `:671-680`). `Tela` aplica tela cheia e carrega 2 cursores PNG (`tela.gd:76-80,176-182`). `Versao`, `Dia`, `Mare`, `Estilo` leem arquivos de poucos KB. `Atualizacao._ready` só limpa restos (exportação). `MCPRuntime` sai cedo fora do editor (`mcp_runtime.gd:44-52`). Conclusão: custo de boot moderado, nada de rede ou de leitura grande.

**T3 · `inicio.tscn` (161 bytes) -> `inicio.gd`.** `IdiomaMenu.aplicar_menu`, 1 JSON (`selecao_idioma.json`), capa `.webp` com `load()`, painel e botões. Rápido. Depois **espera o clique** (o portão `tests/selecao_idioma.gd:57-58` exige isso mesmo com idioma salvo e exige `not ResourceLoader.has_cached(ABERTURA)`). Esse tempo ocioso hoje não é usado para nada.

**T4 · clique no idioma** (`inicio.gd:259-272`): mostra a tela de carregamento, espera 0,25 s, libera a tela de idioma e chama `trocar_cena(ABERTURA)`.
- [F] `load_threaded_request("abertura.tscn")` com `use_sub_threads=false` (padrão): o arquivo da cena tem 639 bytes; o que pesa são as dependências: `abertura.gd` + fecho de 22 scripts (383 KB), `world_builder.gd`, `geo_region_renderer.gd` com 11 `preload` de textura (grama, areia, estrada... 1K a 1,2K) e ~14 shaders. É isso que preenche os 25% da barra (`tela_carregamento.gd:454-462`).
- [T] `change_scene_to_packed`, libera `inicio`.

**T5 · `abertura._ready` + MONTAGEM #1 do vale** (`abertura.gd:135-212`; `world_builder.gd:601-657`). O `_ready` do `Cenario` roda dentro da troca e começa a montar com `visible=false`. A montagem cede 1 quadro a cada ~80 ms. Etapas e tamanhos na próxima seção. A tela de carregamento passa para `CanvasLayer 100` na raiz e acompanha o sinal `progresso` (`tela_carregamento.gd:489-505`). V-Sync é desligado dois quadros depois da troca.

**T6 · pronto do menu** (`world_builder.gd:659-670`): `visible=true` -> primeiro quadro visível (todos os pipelines do vale compilam aqui, ver CAR-05), `Lugares.registrar`, `progresso(1.0)`, `pronto`. O menu inicia música, ambiente, `Atualizacao.verificar()` (HTTP assíncrono, só na exportação), calcula o sobrevoo; a tela faz fade de 0,35 s.

**T7 · JOGAR** (`abertura.gd:1838-1853`): mostra a tela de carregamento de novo, `Dia.congelado_na_carga=true`, `trocar_cena(vale.tscn)`.
- [F] `load_threaded_request("vale.tscn")`: dependências = `prototype.gd` e seu fecho de 84 scripts (1.351 KB, dos quais ~60 ainda não carregados), `personagem.tscn` -> `viajante_tripo.glb` (2K: 10,7 MB de textura), `prototype_hud.gd`, etc. 25% da barra.
- [T] instancia `vale.tscn`; a cena antiga (menu com o vale inteiro, dezenas de milhares de nós) é liberada no fim do quadro.

**T8 · MONTAGEM #2** (mesmo `world_builder.gd`, mesmos dados). **Reaproveitado** (estáticos): `CatalogoAssets._cenas` (PackedScene de cada GLB já usado), `_malhas`, `_pegadas`, `_troncos`, `_troncos_de_malha`, `_vertices_por_malha` (`catalogo_assets.gd:359-361,567-570`), `Mar._ruidos` (NoiseTexture2D), `CopasDistantes._malha/_material`, cache do `ResourceLoader`. **Refeito do zero**: terreno e colisão, fitas, praia, rios, mapa de solo, mata inteira (sorteio, espécies, MultiMesh, copas), sub-bosque, margens, orla, lotes, casas (instâncias), fazenda, árvores, pedras, canoas, luzes, paisagismo, pés das árvores, céu.

**T9 · depois do pronto** (`prototype.gd:224-768`). O `_ready` do vale esperava `world.pronto` (`:232`) e segue, no mesmo quadro, até o primeiro `await` real (`interiores.configurar`, `:246`). Isso devolve o controle ao mundo, a tela vê `construido` e começa o fade de 0,35 s. Dois a quatro quadros de física depois o `_ready` continua, SEM barra: `Interiores` (4 salas), `NavegacaoVale.configurar` (`parse_source_geometry_data` síncrono sobre as colisões do vale, depois assada assíncrona), HUD, telas e menus, `_montar_moradores` (22 + Pedro; os GLBs de morador carregam aqui pela primeira vez), `Tubarao`, `fauna_vale.gd`, `bichos_de_casa.gd` (22 corpos de quatro patas e 10 bandos, 49 aves), `LutaVale`, `AchadosVale`, partida salva, `_chegar_pelo_saveiro`. 1,5 s depois, `_pedir_os_retratos` (8 estúdios `SubViewport`).

**T10 · jogo.** Retomam relógio, física e entrada.

Observação: voltar ao menu (`prototype.gd:1615-1625`) e trocar o estilo (`prototype.gd:287-297`, `abertura.gd:161-164`) repetem uma montagem completa; `reload_current_scene` no menu (troca de estilo) nem usa tela de carregamento.

---

## Etapas emitidas no sinal `progresso` e o tamanho do trabalho (pergunta 3)

A região vale 0 a 75% (`world_builder.gd:631`: `fracao * 0.75`), a vila o resto. O texto aparece ANTES do trabalho da etapa.

| Global | Texto | O que faz de fato | Tamanho | Determinístico e gravável? |
|---|---|---|---|---|
| (antes) | — | `ComposicaoVale.ler` (instancia `composicao_vale.tscn`, 35 KB, extrai casas); `_build_lighting` (céu, sol, lua); `_read_json` x2; `_curve_roads`; `_montar_mapa_de_solo` (5 camadas L8, polígonos por linha com `intersect_polyline_with_polygon`, `publicar`) | JSON 40 KB + 28 KB; ~590 x 512 px x 5 | mapa de solo: sim (texturas) |
| 0,015 | Enchendo a baía | `Mar.montar`: lê a batimetria, `_abrir_calha_na_batimetria` (laço por célula perto dos rios chamando `ground_height_at`), `ImageTexture`, 3 `PlaneMesh` (137.500 + 18.432 triângulos), `HeightMapShape3D` do quadro, paredes, 4 `NoiseTexture2D` | 550 x 500 células | sim (colisão e fundo) |
| 0,04-0,285 | Moldando o terreno | `Geometry2D.triangulate_polygon` + recursão `_add_draped_triangle` (divide a maior aresta até 4 u, 0,8 u perto de rio) + `SurfaceTool` + `index()` + `generate_normals()` + `commit()` + `create_trimesh_shape()` (colisão) | ~50 a 100 mil triângulos (estimativa); cede quadro a cada 80 ms | **sim: malha e colisão** |
| 0,285-0,315 | (mesma etapa) vila e áreas do KML | fitas e recortes pela costa | — | sim |
| 0,315 | Estendendo a praia e os rios | `_add_beach`, 2 rios (areia + água, `ShaderMaterial` cada), extensões de foz, bocas de rio; colisão trimesh nas fitas de areia | 2 rios, 527 u | sim |
| 0,345-0,37 | Abrindo as ruas | 8 ruas x 2 fitas (transição + rua), colisão trimesh nas ruas, cruzamentos, acessos à praia | 1.426 u, segmentos de 1,5 u | sim |
| 0,375-0,75 | Plantando a mata | 0,375-0,525 sorteio de pontos (até 218.190 tentativas, vários testes de polígono/rua/costa/interesse); `_classes_da_mata` (distância a rios/costa/vila por ponto); 0,525-0,735 espécie, escala, giro, `ground_height_at`, `_perto_da_rua_para_plantar`, `_tree_trunks`; depois, SEM ceder quadro: sub-bosque (~2 mil), margens do rio, palmeiras da orla, `_multimesh_em_blocos` (um `MultiMeshInstance3D` por bloco de 40 u e por espécie) e `CopasDistantes.montar` por bloco | 6.234 pontos alvo; ~6,8 mil troncos (docs) | **sim: posições, espécies e MultiMesh (bit a bit já é testado)** |
| 0,76 | Medindo os lotes | `_loteamento` (7 pedidos fixos + casas do arraial + autorais; buscas em anéis, `is_build_site_clear`) | dezenas de lotes | sim (lista) |
| 0,80 | Erguendo as casas | por casa: `instanciar` (carrega GLB na 1ª vez), `_support_house`, `colisao`, terreiro drapeado (`_add_polygon`), registro; cede após cada casa | ~25 casas | não (nós) |
| 0,84 | Cercando o roçado | `_build_farm` (sem ceder) | — | — |
| 0,86 | Plantando as árvores da vila | 1 + 12 nomeadas + quintais + fazenda + coqueiros do píer (`await _pausar` entre elas) | ~25 | — |
| 0,89 | Erguendo a capela, a venda e o píer | `_build_landmark_details` (sem ceder; `create_trimesh_collision` em cada malha do píer e da ponte) | — | colisão do píer/ponte: sim |
| 0,93 | Espalhando os objetos | `_build_pecas`, `_montar_pecas`, marcos de fé | dezenas de adereços | — |
| 0,94 | Assentando as pedras | GLBs de pedra | ~7 | — |
| 0,95 | Fundeando as canoas | canoas + cardume | — | — |
| 0,97 | Acendendo os lampiões | `LuzesEpoca` | — | — |
| 0,975 | Plantando as árvores da vila (2ª vez, é o paisagismo) | `PaisagismoVale.planejar` (reservas, adereços, grades, ruído por zona) + `plantar` (MultiMesh por espécie e LOD) + `plantar_aderecos` (`instanciar` por adereço) + `_build_bases_das_arvores` (`pintar_vida`: 1 `fill_rect` por árvore, 2º `publicar` do mapa de solo, MultiMesh dos pés) — TUDO sem ceder quadro | milhares de pés (não contados) | **sim: plano e transformações** |
| 1,0 | Pronto | `visible=true`, `Lugares.registrar` | — | — |

---

## Achados

### CAR-01 · O vale inteiro é montado duas vezes (menu + JOGAR), e de novo em cada volta ao menu e troca de estilo
- **Afeta:** carregamento. **Impacto:** crítico (estimado: ~metade de todo o carregamento do jogador). **Confiança:** alta no fato, média na proporção.
- **Evidência:** `scenes/prototipo_3d/abertura.tscn:4,10-11` e `scenes/prototipo_3d/vale.tscn:4,12-13` instanciam o mesmo `world_builder.gd` como `Cenario`; `world_builder.gd:601-607` monta no `_ready`; `abertura.gd:1853` troca para `vale.tscn`; comentário dos autores: "29 s de montagem, duas vezes (menu e jogo)" (`geo_region_renderer.gd:149-155`); a ferramenta de medição tem o caminho `--cena=abertura,vale` justamente para isso (`medir_carregamento.gd:23-24`). `abertura.gd` não altera nenhuma propriedade do `Cenario` (só lê âncoras: `abertura.gd:259-291,328,345`), logo os dois mundos são idênticos.
- **Mecanismo:** `change_scene_to_packed` libera a árvore do menu (dezenas de milhares de nós, centenas de `MultiMeshInstance3D`, formas de colisão) e instancia outra que reconstrói tudo em GDScript, de novo cedendo 1 quadro a cada 80 ms. O que sobrevive: só os caches estáticos de `CatalogoAssets` e o cache do `ResourceLoader` (por isso a 2ª montagem é mais barata que a 1ª, mas continua longe de ser grátis).
- **Correção proposta:**
  - Rápida, estrutural (meio dia, mesma lógica em `abertura.gd:_start_game`): em vez de `trocar_cena(vale.tscn)`, instanciar `vale.tscn` à mão, liberar o `Cenario` ainda fora da árvore (o `_ready` dele não rodou) e adotar o `Cenario` já pronto da abertura no lugar (`remove_child` na abertura, `add_child` no vale com o mesmo nome e a mesma posição na ordem dos filhos). `prototype.gd:59` (`@onready var world = $Cenario`) e `:229-234` já tratam `world.construido == true` sem esperar. Pontos de atenção: o `reparent` dispara `tree_exiting` (`world_builder.gd:668`) que chama `Lugares.esquecer` -> é preciso `Lugares.registrar(world)` de novo; `Dia` já está na hora inicial (`abertura.gd:1849`) e o céu segue `hora_mudou`; a câmera do sobrevoo é da abertura e some junto com ela.
  - Mais ampla: assar em disco (CAR-03), que também acelera a 1ª montagem.
- **Esforço:** meio dia a 1 dia com a bateria (216 portões em `tests/`, vários passam por abertura -> vale). **Risco:** médio (estado do mundo compartilhado entre cenas; portões de abertura e `tests/tela_carregamento.gd`, `tests/selecao_idioma.gd`). Não recomendado como mudança "sem rede" no último minuto; recomendado como primeira obra estrutural.
- **Como medir:** `medir_carregamento.gd --cena=abertura,vale`: some `ate_o_pronto_ms` das duas medições; o ganho é o `ate_o_pronto_ms` da segunda (menos o tempo de entrega).

### CAR-02 · GLBs e texturas são lidos sob demanda, de forma síncrona, na thread principal; nada é pré-carregado
- **Afeta:** carregamento. **Impacto:** alto (estimativa 1,5 a 4 s por montagem fria, mais o que fica depois do 100%). **Confiança:** alta no mecanismo, baixa na magnitude.
- **Evidência:** `catalogo_assets.gd:383-394` (`cena()` -> `load(path)` na primeira chamada de cada chave; cache só em `static var _cenas`, `:359`); `instanciar` chama `cena()` e depois `limites()` (varre os `MeshInstance3D`) em CADA instância (`:399-426`); nenhuma chamada a `load_threaded_*` em `scripts/` exceto a da cena (`tela_carregamento.gd:454`); a ferramenta documenta o custo: "hoje cada um é lido no quadro principal, no meio da montagem" (`medir_carregamento.gd:590-592`) e já traz o A/B `--precarregar=1` (`:593-622`). Volume: 260 GLBs, 991 MB de textura e 86 MB de `.scn` referenciados (`perf\analisa_pecas.py`); cada GLB de 1K traz ~2,7 MB de textura, os de 2K, 10,7 MB.
- **Mecanismo:** cada `load()` de GLB: leitura do `.scn` (zstd), criação de malhas (buffers, LODs, shadow meshes), abertura de 3 `.ctex` (leitura do disco, criação e upload da textura via RenderingDevice). Tudo na thread principal, entre os pedaços de 80 ms da montagem. O catálogo carrega só o que usa (bom), mas na ordem em que o mundo pede, sem antecipar nada; moradores (22), bichos (31 GLBs) e peixes (17) só aparecem depois do 100% (CAR-04). O tempo ocioso da tela de idioma e do menu (segundos) não é aproveitado.
- **Correção proposta (HOJE):**
  1. Em `catalogo_assets.gd`, adicionar `static func pedir_em_segundo_plano(chaves: Array)` que chama `ResourceLoader.load_threaded_request(caminho, "", true)` para a lista e guarda a lista pedida; em `cena()` (`:383`), se a chave foi pedida, `ResourceLoader.load_threaded_get(path)` (bloqueia só se ainda não terminou; nunca pior que hoje) e preenche `_cenas[chave]`. Referência forte obrigatória (a ferramenta avisa: sem referência o cache solta o recurso, `medir_carregamento.gd:120-122`).
  2. Chamar na tela de idioma (`inicio.gd:_ready`, compatível com o portão `selecao_idioma.gd:58`, que só proíbe cachear a ABERTURA) com as chaves da montagem; e, quando o menu fica pronto (`abertura.gd:210-212`), com as chaves do vale (moradores, bichos, peixes, viajante).
  3. Lista: a que a própria ferramenta imprime em `glbs.chaves_novas` numa execução normal (arquivo de dados), e não as 260 (as 45 chaves sem citação direta e os `_longe` somam 141 MB e talvez nem entrem).
- **Esforço:** 2 a 3 h (30 a 60 linhas + lista). **Risco:** baixo a médio: picos de memória/VRAM (ordem de 1 GB de textura, a 1660 Ti tem 6 GB), competição de CPU com a montagem (6c/12t, folga), carregar no thread o que nunca será usado. Portão: `tests/selecao_idioma.gd:58`.
- **Como medir:** `medir_carregamento.gd --cena=abertura,vale` com e sem `--precarregar=1` (compare `ate_o_pronto_ms` da abertura; a ferramenta imprime também `precarga.ms`); diferença abertura-menos-vale sem precarga ≈ custo frio de assets.

### CAR-03 · Geometria determinística refeita a cada montagem em GDScript: terreno, colisão, fitas, mapa de solo, sorteio da mata, paisagismo
- **Afeta:** carregamento. **Impacto:** alto (o terreno sozinho provavelmente é a maior fatia da CPU da região). **Confiança:** média.
- **Evidência:** `geo_region_renderer.gd:1026-1056` (`_add_polygon`: `SurfaceTool`, `index`, `generate_normals`, `commit`, `create_trimesh_shape`) + `:1059-1094` (recursão por triângulo com laço por rio e `_distance_to_line` de 40 segmentos); `:1097-1102` (cada vértice chama `ground_height_at`: IDW sobre 12 POIs + testes de polígono/costa/rio em GDScript, `:477-548`); sorteio da mata `:1815-1865` (6.234 alvos, até 218.190 tentativas); `paisagismo_vale.gd:641-683,691-695` sem `await`; `world_builder.gd:808-816`. A estimativa dos próprios autores: "o terreno é a parte mais demorada: progresso de 0,05 a 0,38" (`geo_region_renderer.gd:1064`) e a montagem total ~5 s headless em 02/10 (CHANGELOG_3D.md:903-907). Conta própria: ~100 a 200 mil visitas de recursão x 6 a 20 µs + queda de altura (~8 µs por vértice novo) = 2 a 3,5 s só no terreno (estimativa, ver "Fatos"). O gerador `tools/mapas/gerar_terreno_editavel.gd` (`:34-62`) prova que a malha e a colisão já são exportáveis para `.tscn` pelo mesmo código (`terrain_only`).
- **Mecanismo:** GDScript executa ~1 a 5 milhões de operações por segundo por tipo de operação com custo de chamada de ~0,3 a 1 µs por chamada nativa; geração de malha por vértice em GDScript é ordens de grandeza mais lenta que carregar um `ArrayMesh` binário pronto. Só `PlaneMesh`, `Geometry2D.*`, `Image.fill_rect`, etc. são C++ (o mapa de solo já foi desenhado assim, `mapa_de_solo.gd:13-16`).
- **Correção proposta (ESTRUTURAL, pós-entrega):**
  - Assar em disco, por uma ferramenta de editor (modelo: `gerar_terreno_editavel.gd`): terreno (`ArrayMesh` + `ConcavePolygonShape3D` em `.res` binário), fitas, mapa de solo (Texture2DArray ou 5 PNG), pontos da mata + espécies + blocos de `MultiMesh` (`buffer` em `PackedFloat32Array`), plano do paisagismo. Chave de cache = hash dos JSON do mapa + versão do código + lista de clareiras/vãos; o portão já existente que compara a montagem "bit a bit" (CHANGELOG_3D.md:903-907) vira o teste de equivalência cache x código.
  - Alternativa menos invasiva: mover para `WorkerThreadPool` os trechos puros (sorteio de pontos, `_classes_da_mata`, plano do paisagismo, malha do terreno em arrays `PackedVector3Array`), com `_alturas_vertices` pré-aquecido ou thread-local (hoje o dicionário seria disputado) e só o `commit` na principal.
- **Esforço:** 2 a 4 dias para o assado completo; 1 dia para só terreno+colisão. **Risco:** médio (invalidar cache quando o mapa ou as clareiras mudam; tamanho no PCK: terreno ~poucos MB). Portões que cobram a geometria: `tests/mapa_de_solo.gd`, `colisoes_do_vale.gd`, `colisao_das_arvores.gd`, `lod_vegetacao.gd`, `composicao_vale.gd`, `sobrevoo_livre*.gd`, `mata_em_manchas.gd`.
- **Como medir:** etapas de `medir_carregamento.gd` ("Moldando o terreno · terra: malha e colisão", `CORTES` em `:71-74`) e `maior_trecho_sem_ceder_ms`.

### CAR-04 · Trabalho grande DEPOIS do 100%, escondido sob o fade da tela de carregamento
- **Afeta:** carregamento (percebido) e travadas. **Impacto:** alto (percepção) / médio (tempo). **Confiança:** alta no mecanismo, baixa na magnitude.
- **Evidência:** `tela_carregamento.gd:489-511` sai do laço quando `mundo.construido` e já começa o fade de 0,35 s; `world_builder.gd:669-670` emite `progresso(1.0)` e `pronto`; `prototype.gd:229-234` retoma na hora; depois `await interiores.configurar` (`:246`; 4 salas x 2 quadros de física, `interiores.gd:61-73,294-295`); `NavegacaoVale.configurar` (`:254`; `navegacao_vale.gd:110-116`: `parse_source_geometry_data` síncrono sobre as colisões do vale e laço sobre `_tree_trunks`); HUD e ~15 telas (`:279-560`); `_montar_moradores` (`:571`, `:1080-1123`: 22 + Pedro, GLBs de moradores carregam aqui pela 1ª vez); `Tubarao`, `fauna_vale.gd` (`:1126-1130`); `bichos_de_casa.gd` (`:1132`; `animador_bicho.gd:233-234` faz `CatalogoAssets.instanciar` por bicho: 22 corpos de quatro patas + 49 aves em 10 bandos = ~71 instâncias (números do briefing)); `Luta`, `Achados`, partida salva (`:741-766`); 1,5 s depois, 8 retratos (`prototype.gd:1024-1030`; `retratos_3d.gd:89-150`: `SubViewport` 256 px com `own_world_3d`, MSAA 4x, 3 luzes, 3 quadros cada, `Image.generate_mipmaps`). O próprio `medir_carregamento.gd:408-422` reconhece a etapa "(depois do pronto, no mesmo quadro)".
- **Mecanismo:** o fade é um `Tween` guiado por `delta`; um quadro longo consome o tween quase inteiro e o vale "aparece de repente", ou o jogador vê a capa meio transparente congelada. Instanciar ~95 modelos (23 moradores + ~71 bichos + peixes), criar HUD e assar navegação numa fatia só vira um engasgo de centenas de ms a alguns segundos logo na chegada (`Dia.congelado_na_carga` só é liberado em `:263`, antes de moradores).
- **Correção proposta (HOJE):**
  1. `prototype.gd`: `signal pronto_para_jogar` emitido no fim do `_ready` (depois de `_pedir_os_retratos` agendado); `tela_carregamento.gd:trocar_cena` espera esse sinal (com teto de 10 s) antes de `barra.value = 1.0` e do fade. A barra vai a 100% só quando de fato acabou.
  2. Dividir com `await get_tree().process_frame` os blocos mais pesados do `_ready` (moradores; bichos) para a tela seguir animando.
  3. Retratos e navegação: deixar para depois (já há 1,5 s para os retratos; a navegação pode esperar 2 s).
- **Esforço:** 1 a 2 h (itens 1 e 3), 1 h (item 2). **Risco:** baixo a médio (portões que esperam `construido` e não o novo sinal continuam passando; cuidado com `tests/tela_carregamento.gd` e `chegada.gd`, que dependem de temporização).
- **Como medir:** `medir_carregamento.gd --cena=abertura,vale --quadros_depois=300`; os maiores quadros (`maiores_quadros`) logo após `ate_o_pronto_ms` e a etapa "(primeiros quadros com o vale à vista)".

### CAR-05 · Sem aquecimento de shaders/pipelines; mundo escondido até o fim; Shader Baker desligado; primeira execução fria em máquina nova
- **Afeta:** carregamento e travadas. **Impacto:** alto para a banca avaliadora (1 execução, caches vazios), médio no PC do autor. **Confiança:** média.
- **Evidência:** `grep -i "warm|aquec|pipeline|ubershader|compil"` em `scripts/` não acha nada além de regex de addon; `world_builder.gd:613` (`visible = false`) e `:659-661` (`visible = true` no `_concluir`); `export_presets.cfg:15-30` sem `shader_baker`; custom shaders: 14 `.gdshader` (`ceu_vale` 12,6 KB, `terreno` 11,2 KB, `leito_mar` 6,7 KB...); materiais de GLB com albedo+ORM+normal, `ensure_tangents`, MSAA 2x; retratos em MSAA 4x = outra variante de pipeline (`retratos_3d.gd:95`); caches da máquina do autor: `user://shader_cache` 160 arquivos/14 MB (72 de `SceneForwardClusteredShaderRD`) e `user://vulkan` 28,6 MB (+13,7 MB do editor), datados de dias de uso. Numa máquina nova nada disso existe.
- **Mecanismo:** o 1º desenho de cada combinação (material x formato de vértice x passe: pré-passe de profundidade, opaco, sombra x MSAA) compila SPIR-V (no motor/shaders do projeto) e o pipeline Vulkan no driver. O Godot 4.4+ amortece com ubershaders e compilação assíncrona (confirmar o comportamento exato no 4.7.2), mas o 1º uso ainda custa e, sem o Shader Baker (4.5+: compila os shaders na exportação; confirmar a opção no preset do 4.7.2), cada máquina nova compila tudo na hora. Como o mundo só fica visível em `_concluir`, a compilação do vale acontece no primeiro quadro visível, por baixo do fade.
- **Correção proposta (HOJE):**
  1. Exportação: ligar o Shader Baker no preset (`shader_baker/enabled=true`, só se aparecer na UI do 4.7.2; custo: exportação mais lenta). Exportar e abrir uma vez para validar.
  2. Aquecimento barato e seguro: em `trocar_cena`, depois de `construido`, esperar 3 a 4 quadros (ou 300 ms) com a tela ainda opaca e o mundo visível por baixo antes de iniciar o fade. Os pipelines do vale compilam nesses quadros, escondidos. Opcional: aquecer retratos/HUD.
  3. Primeira execução do coordenador em "máquina fria": mover (não apagar) `shader_cache` e `vulkan` do `%APPDATA%\MythsValleyPrototype3D`, medir, restaurar.
- **Esforço:** 30 min (item 1, se existir) + 30 min (item 2). **Risco:** baixo.
- **Como medir:** tempo e maiores quadros do 1º quadro visível (`medir_carregamento.gd` sem `--headless`: "o shader compilando no primeiro quadro visível"), com caches limpos x aquecidos; `maiores_quadros` logo após `ate_o_pronto_ms`.

### CAR-06 · O pacote dobrou: 1.183 MB importados, 991 MB de textura nos GLBs, 119 texturas 2K (416 MB) contra a regra "1K para adereços"
- **Afeta:** carregamento, memória e a entrega. **Impacto:** alto. **Confiança:** alta nos tamanhos, média nos efeitos.
- **Evidência:** `perf\conjunto_vivo.py` (1.322 importações, 1.183,2 MB: `arvores` 325 MB, `construcoes` 259, `aderecos` 115, `personagens` 103, `animais` 89, `itens` 86, `peixes` 47, `moveis` 42); `perf\analisa_pecas.py` (40 GLBs com conjunto 2K de 10,67 MB: 23 construções, 13 árvores nomeadas, `viajante`, `saveiro` e **`cacho_banana`, um item**, o que contraria a regra de 1K para itens e adereços); `build/windows/MythsValley3D.exe` de 515,7 MB (PCK ≈ 431 MB) na build #7; `export_presets.cfg:8-10` (`all_resources`). Sobra no pacote que o jogo não usa: `assets/prototipo_3d/personagem/medieval_character_animated.glb` (só ferramenta; 20,3 MB importados), `terreno_editavel.tscn` (15,6 MB em texto) e `ruas_referencia.tscn` (7,2 MB em texto), lidos só por tools/tests/editor.
- **Mecanismo:** a textura VRAM comprimida ocupa o mesmo tamanho no disco e na GPU: 2K com mipmaps ≈ 2,7 MB (cor ou ORM) e 5,3 MB (normal); 1K ≈ 0,7 a 1,3 MB. Cada textura carregada é lida do disco/PCK (antivírus incluso), criada e enviada à GPU; e fica residente. Exe maior = download/zip maiores, varredura do antivírus na 1ª execução mais longa, leitura a frio mais lenta.
- **Correção proposta:**
  - HOJE (decisão): reduzir os 2K que a regra não pede (cacho_banana, e avaliar construções repetidas como `casa_taipa_*` e as normais 2K em geral) para 1K reimportando: `process/size_limit` no `[importer_defaults]` do `project.godot:78-85` vale para as texturas extraídas dos GLBs porque o `.import` delas é regerado (`assets/prototipo_3d/animais/.gitignore` o diz) — mas atingiria TODAS as texturas e a reimportação leva minutos; só com A/B visual. Estimativa de ganho se TODOS os 40 GLBs de 2K caíssem a 1K: 416 MB -> 107 MB (-309 MB, -26% do total).
  - HOJE (seguro): `exclude_filter` do preset: `assets/prototipo_3d/personagem/*` (20 MB). `terreno_editavel.tscn`/`ruas_referencia.tscn`: ver se `composicao_editor.gd` os cita por texto antes (a busca achou só tests/tools/editor).
  - Estrutural: política de textura por categoria no importador (script de pré-processamento), `ORM` empacotada, normais em 1K.
- **Esforço:** 15 min (filtro), 1 a 2 h (reimportação + A/B visual). **Risco:** baixo (filtro) / médio (qualidade visual de destaques e tempo de reimportação na véspera).
- **Como medir:** tamanho do exe e do zip; `monitores.texturas_mb`/`video_mb` do `medir_carregamento.gd`; tempo da 1ª execução com antivírus ativo.

### CAR-07 · Medidas e uso pelo binário do editor, não pela exportação release
- **Afeta:** varios (carregamento e FPS medidos). **Impacto:** médio (pode inflar as duas queixas). **Confiança:** média.
- **Evidência:** `tools/prototipo_3d/jogar.ps1:11-20` e `JOGAR_3D.cmd` rodam `Godot_v4.7.2-stable_win64.exe --path` (binário do editor, `OS.has_feature("editor")` verdadeiro); a exportação release é `README.md:194`; modelos de exportação instalados (`windows_release_x86_64.exe`, 109 MB, `export_templates/4.7.2.stable`); `MCPRuntime` só fica ativo com a feature "editor" (`mcp_runtime.gd:44-58`): polling por quadro e reconexão a cada 2 s com `outbound_buffer_size = 8 MB` (`:88-95`).
- **Mecanismo:** builds de editor/depuração têm verificações extras no motor e no GDScript (e scripts em texto são parseados/compilados na carga; a exportação carrega tokens binários); `.godot/imported` x PCK; `.tscn` texto x binário. As diferenças reais não foram medidas aqui. O jogo exportado também lê o PCK embutido (leitura a frio e antivírus) e começa com caches vazios (CAR-05).
- **Correção proposta (HOJE, só medição):** exportar release (`README.md:194`) e comparar com a execução por `jogar.ps1`: tempo de duplo-clique até andar e FPS do HUD no mesmo trecho. Se o release já melhorar muito, a "queixa" do autor é parcialmente do binário usado.
- **Esforço:** 30 a 60 min (exportação com 1,2 GB). **Risco:** nenhum.
- **Como medir:** cronômetro com tela gravada; logs `OPENING_READY` e `PROTOTYPE_READY` (`abertura.gd:212`, `prototype.gd:767`) com timestamp externo (`--verbose` ou `Measure-Command` + saída do console).

### CAR-08 · O orçamento de 80 ms por quadro e os quadros cedidos: perda de 0,4 a ~2 s por montagem, a confirmar
- **Afeta:** carregamento. **Impacto:** baixo a médio. **Confiança:** baixa na magnitude.
- **Evidência:** `world_builder.gd:674-683` e `geo_region_renderer.gd:70,453-460` (cedem 1 quadro a cada ≥80 ms; os orçamentos são independentes); V-Sync só é desligado dois quadros depois da troca (`tela_carregamento.gd:480-488`) e restaurado ao fim (`:506`); modo de janela 3 = tela cheia sem exclusividade; `_etapa` cede 1 quadro por chamada (13 chamadas, `world_builder.gd:686-689`).
- **Mecanismo:** cada cessão custa um quadro: o desenho da tela (+ céu por trás e MSAA) e, se o apresentador ainda sincronizar com o monitor, até 16,7 ms. Conta (ESTIMATIVA): com T de trabalho e orçamento B, há T/B cessões; T = 10 s e B = 80 ms = 125 cessões x (16,7 ms sincronizado | ~5 ms livre) = 2,1 s | 0,6 s. Dobrar B para 160 ms corta isso pela metade, ao custo de uma barra mais travada e de congelamentos de até ~0,2 s a cada passo (hoje o maior é ~0,7 s, `CHANGELOG_3D.md:1272-1273`). Em Windows 10 com tela cheia sem exclusividade o compositor pode manter a cadência do monitor mesmo com V-Sync "desligado" (hipótese, não verificada).
- **Correção proposta (HOJE):** `ORCAMENTO_QUADRO_US` de 80.000 para 150.000 a 200.000 nos dois arquivos (`world_builder.gd:674`, `geo_region_renderer.gd:70`); ou desligar o V-Sync antes (já no início de `trocar_cena`, `tela_carregamento.gd:453`, não 2 quadros depois da troca).
- **Esforço:** 10 min. **Risco:** baixo (nenhum portão cita as constantes; `grep` em `tests/` e `tools/`). Efeito colateral: progresso e rosa dos ventos animam menos vezes por segundo.
- **Como medir:** `medir_carregamento.gd`: `quadros`, `quadros_lentos`, `desenho_cpu_ms`, `desenho_gpu_ms`, `total_ms` com 80 x 200 ms.

### CAR-09 · Blocos grandes de montagem que nunca cedem quadro
- **Afeta:** carregamento (suavidade) / travadas. **Impacto:** baixo (a tela só para de animar). **Confiança:** média.
- **Evidência:** a própria ferramenta lista "sem ceder quadro, o sub-bosque, as margens do rio e a orla" (`medir_carregamento.gd:67-70`); no código: `_build_sub_bosque`, `_build_margens_do_rio`, `_build_coast_palms` e `_multimesh_em_blocos`/`CopasDistantes.montar` (`geo_region_renderer.gd:1930-1932,2139-2197`), `_build_paisagismo` e `_build_bases_das_arvores` (`world_builder.gd:790-791`), `_build_farm`, `_build_landmark_details`, `_build_pecas`, `_build_pedras`, `_build_canoas`, `_build_luzes_epoca`, mais o `commit` e a colisão do terreno e de cada fita.
- **Mecanismo:** não aumentam o tempo total, só criam quadros de centenas de ms em que a barra congela (e deixam o sistema operacional marcar a janela como "sem resposta" se algum passar de ~5 s em máquinas lentas).
- **Correção proposta:** `await _pausar()` entre as sub-etapas de `_construir_vila` e `await _marcar(..., false)` entre sub-bosque, margens e orla. 
- **Esforço:** 30 min. **Risco:** baixo. **Como medir:** `maior_trecho_sem_ceder_ms` e `maiores_quadros` por etapa.

### CAR-10 · Medições de malha em GDScript na primeira vez (`tronco`, `pegada`, `tronco_da_malha`) e `limites()` por instância
- **Afeta:** carregamento. **Impacto:** baixo a médio (estimativa 0,3 a 1 s na 1ª montagem; ~0 na 2ª). **Confiança:** baixa.
- **Evidência:** `catalogo_assets.gd:577-599,608-626,634-666,672-695`: `surface_get_arrays` (copia vértices) e laço por vértice em GDScript (`coqueiro_cortado.gd:69-123`), por chave e por faixa de tamanho (passos de 8%, ~7 por malha); caches estáticos preenchem uma vez (`:567-570`). `limites()` percorre todos os `MeshInstance3D` do modelo a cada `instanciar` (`:756-765`).
- **Mecanismo:** as casas têm 11 a 13 mil triângulos (`construcoes/ORIGEM.md`); ~100 medições x 5 a 20 ms de laço em GDScript.
- **Correção proposta (estrutural leve):** gravar os resultados (`pegada`, `tronco`, `tronco_da_malha` por malha e faixa) em JSON gerado por ferramenta, ou calcular na threads de pré-carga (CAR-02).
- **Esforço:** meio dia. **Risco:** baixo (portões de colisão cobrem). **Como medir:** diferença `ate_o_pronto_ms` da 1ª para a 2ª montagem após isolar GLB (`--precarregar=1`).

### CAR-11 · O menu só aparece depois de o vale inteiro terminar
- **Afeta:** carregamento (percebido). **Impacto:** médio. **Confiança:** alta.
- **Evidência:** `abertura.gd:214-217` (`_process` retorna até `construido`), `:190-211` (som, voo e entrada só em `pronto`); a tela de carregamento cobre tudo até lá (`tela_carregamento.gd:489-511`).
- **Mecanismo:** o jogador só vê o menu depois de ~T_montagem(frio). Como o menu já tem a capa pintada igual à da tela de carregamento, poderia aparecer antes, com o vale montando por trás e o sobrevoo começando quando ficar pronto. 
- **Correção proposta (estrutural):** mostrar o menu (capa estática) logo após a leitura dos arquivos; habilitar JOGAR quando `construido`; manter a música do menu. Interage com CAR-01 (se o `Cenario` for reaproveitado, JOGAR vira quase instantâneo).
- **Esforço:** 1 dia. **Risco:** médio (portões de abertura/menu, mais de 10 em `tests/`). **Como medir:** tempo até o primeiro quadro de menu interativo.

### CAR-12 · Três callbacks GDScript por nó adicionado durante toda a montagem
- **Afeta:** carregamento. **Impacto:** baixo. **Confiança:** baixa.
- **Evidência:** `audio.gd:577` (`_mover_para_geral`: 3 testes `is`), `estilo.gd:25` (`_cursor_de_clique`), `tela.gd:66,146-148` (`_texto_novo`); a montagem cria dezenas de milhares de nós (a ferramenta conta: `nos_do_cenario`, `contagem.nos`).
- **Mecanismo:** ~3 chamadas de GDScript x ~1 a 1,5 µs por nó = 3 a 5 µs/nó; com 50 mil nós ≈ 0,15 a 0,25 s por montagem (ESTIMATIVA).
- **Correção proposta:** desligar as três conexões durante a montagem e reaplicar por varredura no `pronto` (ou limitar a `Control`/players por grupos). **Esforço:** 1 h. **Risco:** baixo/médio (cursor de mão, escala de texto, barramento "Geral"). **Como medir:** `--cena=abertura` com e sem os três `connect`.

### CAR-13 · Pacote exportado carrega sobras e o template de exportação padrão
- **Afeta:** carregamento (primeira execução) e entrega. **Impacto:** baixo. **Confiança:** média.
- **Evidência:** `export_presets.cfg:8-10` (`all_resources`; `include_filter` com `*.json` pega qualquer JSON do projeto, incluindo `addons/`); sobras listadas em CAR-06; `application/modify_resources=true` exige o `rcedit` configurado no editor (sem ele o preset avisa ou ignora; não verificado).
- **Correção proposta:** `exclude_filter` mais completo; trocar `export_filter` para `scenes` com lista explícita só se houver tempo (risco de faltar recurso carregado por `load()` com caminho montado em texto: `ResourceLoader.exists` já protege parte). **Esforço:** 30 min. **Risco:** baixo (filtros) / médio (lista explícita).

---

## Ações priorizadas

**HOJE (baixo risco, ordem sugerida):**

| # | Ação | Onde | Esforço | Ganho esperado |
|---|---|---|---|---|
| 1 | Medir `abertura,vale` com e sem `--precarregar=1` e com `--tela=0` | `tools/prototipo_3d/medir_carregamento.gd` (comandos em "Dúvidas") | 30-60 min | decide o resto |
| 2 | Pré-carga de GLBs em threads (tela de idioma + menu) | `catalogo_assets.gd:383-394`, `inicio.gd`, `abertura.gd` | 2-3 h | (estimativa) 1,5 a 4 s por montagem fria |
| 3 | Segurar a tela até o `_ready` do vale acabar + 3-4 quadros de aquecimento | `tela_carregamento.gd:489-511`, `prototype.gd:768` | 1-2 h | some a "travada depois do 100%" |
| 4 | Shader Baker na exportação (se existir no 4.7.2) | `export_presets.cfg` | 30 min | 1ª execução da banca |
| 5 | Orçamento de quadro 80 -> 150-200 ms | `world_builder.gd:674`, `geo_region_renderer.gd:70` | 10 min | 0,3 a 1 s |
| 6 | `exclude_filter` de `personagem/*` e decisão sobre 2K -> 1K | `export_presets.cfg:10`, `project.godot:78-85` | 15 min / 2 h | -20 MB / -300 MB |
| 7 | Exportar release e comparar com `jogar.ps1` | `README.md:194` | 30-60 min | calibra todas as queixas |

**ESTRUTURAIS (pós-entrega, ou "sem rede" só com portões verdes):**
1. Reaproveitar o `Cenario` da abertura em `vale.tscn` (CAR-01). Maior ganho único de carregamento.
2. Assar em disco terreno, colisão, fitas, mapa de solo, pontos da mata e MultiMesh, plano do paisagismo (CAR-03).
3. Menu antes do vale pronto (CAR-11).
4. Pipeline de texturas por categoria (CAR-06); tabela de `pegada/tronco` gravada (CAR-10).
5. Montagem em `WorkerThreadPool` das partes puras (sorteio da mata, plano do paisagismo, malha do terreno em arrays).

---

## O que está OK (conferido; não reinvestigar)

- **Dados lidos na montagem são pequenos.** Maior JSON de `data/`: `npcs_3d.json` 45 KB; `bom_jesus_dos_pobres.json` 40 KB; cenário 28 KB; batimetria 550 KB; `sobrevoo_menu.json` 41 KB. Todo `data/` ≈ 1 MB (`du`). Nenhum parse relevante.
- **`terreno_editavel.tscn` (15,6 MB texto) e `ruas_referencia.tscn` (7,2 MB texto) NÃO são lidos em execução.** `terreno_editor_preview.gd` só carrega a prévia com `Engine.is_editor_hint()` (`:11-12`) e o `world_builder` remove o nó antes de montar (`world_builder.gd:601-607`); as demais menções são `tests/`, `tools/` e `composicao_editor.gd`. A cena é de um terreno antigo (shader simples), só para o editor.
- **`composicao_vale.tscn` (35 KB) e `paisagismo_vale.tscn` (24 KB)** são lidas 1 vez por montagem; custo desprezível.
- **Autoloads no `_ready`:** só preferências e JSON de poucos KB, criação de nós e de UI invisível; `Audio` não carrega música no boot; `Atualizacao` só limpa restos e faz `HTTPRequest` assíncrono (8 s de teto), e só com a feature "template" (`atualizacao.gd:55-81`); `MCPRuntime` é mudo fora do editor (`mcp_runtime.gd:44-52`).
- **A tela de carregamento é barata:** textura de capa 1.152 px (1,5 MB `.ctex`), 2 `GradientTexture2D` pequenas, logotipo, 3 labels, `ProgressBar` com `StyleBoxFlat`, 1 rosa girando, 1 `Timer` de 7 s, sem partículas nem som (CHANGELOG:908-909). Custo por quadro na ordem de 1 a 2 ms de CPU (estimativa); o que cobra é o quadro em si (CAR-08).
- **O V-Sync de fato é tratado:** desligado durante a montagem e restaurado ao fim (`tela_carregamento.gd:487-488,506`). Há uma janela de 2 quadros antes de desligar (menor).
- **A leitura da cena em segundo plano funciona** (`load_threaded_request`, `tela_carregamento.gd:454-463`) e preenche 25% da barra com o que realmente é leitura de scripts e texturas.
- **Reaproveitamento entre as duas montagens** de `CatalogoAssets._cenas/_malhas/_pegadas/_troncos/_troncos_de_malha/_vertices_por_malha`, `Mar._ruidos`, `CopasDistantes._malha/_material`: caches estáticos que sobrevivem à troca de cena; `limpar_cache()` só roda com ajuste de peça no painel (`ajustes_conteudo.gd:152,164`).
- **O sorteio da mata e as consultas espaciais já foram otimizados** em 02/10 (grades de células, resposta idêntica bit a bit) — `geo_region_renderer.gd:149-172`; `ground_height_at` é cacheado por vértice (`:1097-1102`).
- **`AjustesConteudo.peca()`** lê o JSON uma única vez (`_carregado`); não é custo por instância.
- **O mundo fica escondido enquanto monta** (`world_builder.gd:613`): os quadros cedidos não desenham o vale pela metade.
- **Dados de exportação:** `embed_pck=true` (um arquivo só), `s3tc_bptc=true`; `export-release` é o comando documentado; `build/*.zip` e `build/windows/*.exe` não entram no pacote (não são recursos).

---

## Dúvidas para medição A/B (só a máquina com GPU resolve)

Comandos prontos (a pasta do projeto como `--path`; o coordenador roda com janela, SEM `--headless`, e mata só o próprio PID, conforme o `AGENTS.md`). A ferramenta imprime linhas `MEDICAO:` e um JSON com etapas, quadros, maiores quadros, contagens e monitores:

```
C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe --path . --script res://tools/prototipo_3d/medir_carregamento.gd -- --cena=abertura,vale --saida=<pasta>\carga_base.json
... -- --cena=abertura,vale --precarregar=1 --saida=<pasta>\carga_precarga.json
... -- --cena=abertura,vale --tela=0 --saida=<pasta>\carga_sem_tela.json
... -- --cena=abertura --estilo=procedural        (referência de custo SEM GLB)
... -- --cena=abertura,vale --quadros_depois=300  (inclui o que vem depois do pronto)
```

1. **Quanto custa cada montagem e quanto é "frio" de asset?** `ate_o_pronto_ms` da abertura menos o do vale, na execução base. A 2ª montagem já tem os GLBs e as malhas medidas em cache; a diferença é o custo de GLB + medidas de malha (CAR-02, CAR-10). Compare com `--estilo=procedural` (sem GLB).
2. **A pré-carga em threads vale a pena?** `--precarregar=1` x base: `ate_o_pronto_ms` da abertura, `precarga.ms` e `quadros`. Se o ganho passar de ~15%, vale implementar hoje (CAR-02). Anote também `monitores.video_mb`/`texturas_mb`.
3. **Fatias do terreno e da mata:** etapas "Moldando o terreno · terra: malha e colisão", "Plantando a mata · sorteio dos pontos / malhas por espécie / sub-bosque, rio e orla" (`CORTES`, `medir_carregamento.gd:71-74`). Confirma o peso de CAR-03.
4. **Perda por quadros cedidos / V-Sync:** `quadros`, `quadros_desenhados`, `desenho_cpu_ms`, `desenho_gpu_ms`, `total_ms` com `ORCAMENTO_QUADRO_US` em 80.000 x 200.000 (os dois arquivos). Se `quadros x 16,7 ms` ≈ perda, o V-Sync não está de fato desligado em tela cheia (CAR-08).
5. **O que acontece depois do 100%:** `--quadros_depois=300`; `maiores_quadros` depois de `ate_o_pronto_ms`; tempo entre a linha `OPENING_READY`/pronto e `PROTOTYPE_READY`. Teste B: comentar `_pedir_os_retratos()` (`prototype.gd:768`) e a chamada de `navegacao.configurar` (`:254`) e ver a queda do maior quadro (CAR-04).
6. **Custo de shader a frio:** executar a mesma medição com `shader_cache` e `vulkan` do `%APPDATA%\MythsValleyPrototype3D` movidos para outro nome (e restaurados depois, sem apagar saves). Comparar o `maior quadro` após `pronto` e as 30 primeiras amostras (CAR-05).
7. **Binário do editor x release:** exportar (`README.md:194`) e cronometrar duplo-clique até andar; FPS no mesmo trecho pelo painel do HUD (CAR-07).
8. **Quantos GLBs de fato carregam?** `glbs.carregados_no_total` e `chaves_novas` no JSON; congela a lista de pré-carga (CAR-02) e dimensiona o consumo de VRAM (hoje ≤ 991 MB de textura).
9. **Nós e MultiMesh:** `contagem.nos`, `contagem.por_classe.MultiMeshInstance3D`, `contagem.multimesh_por_grupo` (quantos blocos de mata/copas/paisagismo) e `mundo.nos_do_cenario` — dimensiona CAR-01 e CAR-12.
10. **MCPRuntime:** A/B com o autoload `MCPRuntime` removido da lista (`project.godot:61`) só numa cópia; espera-se ruído, não ganho.
11. **Efeito visual de 2K -> 1K:** reimportar só os 40 GLBs de 2K numa cópia (ou só as normais) e comparar `texturas_mb`, tempo e imagem lado a lado nas casas de destaque e árvores nomeadas.

Observação sobre contexto (fora do escopo CAR, para quem investiga FPS): a documentação já registrava 12,6 a 32,8 FPS no vale em 30/09 com o LOD da vegetação ligado (`docs/mundo/VALE_VIVO_3D.md:161-165`) e o próprio `copas_distantes.gd:12` fala em "perto de 20 FPS"; ou seja, as otimizações antigas continuam no código, mas a marca de 60 FPS do CHANGELOG (`:1308-1319`) é de antes dessa data e de cenas mais leves. A tabela de FPS do doc foi medida em 1024x576/1280x720; no 1080p do autor o custo de preenchimento só cresce.

---

## Apêndice: arquivos auxiliares (apenas em `scratchpad\perf\`)

`analisa_pecas.py` (GLBs do catálogo: tamanhos de `.scn` e `.ctex`), `chaves_usadas.py` (chaves citadas), `conjunto_vivo.py` (conjunto importado vivo), `texturas_classes.py` (classes e dimensões de textura), `fecho_scripts.py` (fecho de scripts), `estimar_terreno.py` (área e estimativa de triângulos), `pecas_tamanho.json` (saída por GLB).
