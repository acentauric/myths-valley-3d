# REN: configuração de render, ambiente, céu, luz, sombras, mar e shaders

Escopo: tudo que custa por PIXEL ou por PASSADA no Myths' Valley 3D (Godot 4.7.2, Forward+, Vulkan).
Repositório lido em modo somente leitura (commit eb430e4, branch main). O Godot NÃO foi executado: todo milissegundo
abaixo é ESTIMATIVA com a conta mostrada, nunca medição. Onde a afirmação depende do comportamento interno da
engine (não do código do projeto), a confiança está marcada.

## Resumo

1. **Nenhum item do meu escopo, sozinho, explica 50 ms por quadro.** Pela conta (seção de Fatos), o que custa por pixel
   (terreno, água, céu, névoa) fica na casa de 0,3 a 3 ms cada um numa GTX 1660 Ti Max-Q a 1080p. O que pesa de verdade
   está provavelmente em geometria e CPU (vegetação, bichos, draw calls: escopo de outros investigadores). O meu escopo
   entrega MULTIPLICADORES desse custo: segunda passada de cena do minimapa, sombras do Sol em 4 cascatas, pré-passe de
   profundidade, MSAA 2x e 1080p.
2. **Evidência de que a queda não é só fill-rate:** o A/B de 30/09 (docs/mundo/VALE_VIVO_3D.md:158-165) já media 12,6 a
   32,8 FPS a 1024x576, V-Sync desligado e minimapa desligado, perto/sobre/longe da mata. Hoje o autor joga a 1920x1080
   (3,5x mais pixels), com MSAA 2x, V-Sync ligado e minimapa ligado. As medições "60 FPS" da documentação são de 26/09
   a 1280x720 (2,25x menos pixels) e de cenas simples (uma bancada de três árvores, ASSETS_TRIPO.md:26).
3. **Maior suspeito do meu escopo (REN-01):** o minimapa é um SubViewport com `UPDATE_ALWAYS` que desenha o vale uma
   segunda vez por quadro (minimapa.gd:99,144), ligado por padrão (minimapa.gd:156), com câmera ortográfica (que, pelo
   que lembro do código da engine, escolhe sempre o LOD mais detalhado; confiança média, a confirmar no teste A1c). Estimativa: +0,8 a 1,2 M de primitivas e +100 a 300 draws por
   quadro. Correção de hoje: baixar a taxa para ~10 Hz ou desligar por padrão (2 a 15 linhas, risco baixo).
4. **Segundo grupo (REN-02, REN-03, REN-04):** sombras do Sol (PSSM 4 cascatas, 180 u, atlas 4096, filtro suave padrão),
   1080p + MSAA 2x sem escala 3D nem opção de qualidade para o jogador, e pré-passe de profundidade ligado (duplica o
   trabalho de vértices da mata). Todas são de configuração (ProjectSettings ou 1 propriedade), porém só medição na GPU
   diz quanto rendem; a tabela de A/B está em "Dúvidas".
5. **Água (REN-06):** `agua_mar.gdshader` é o ÚNICO shader do projeto com `hint_screen_texture` e `hint_depth_texture`:
   força cópia da tela (com cadeia de mipmaps) e da profundidade no meio do quadro, com resolução de MSAA. Custa ~1 a
   2 ms (estimativa), não 50. Reescrever é estrutural (pós-entrega).
6. **Céu (REN-07) e terreno (REN-08)** são os "adorados" da última integração (commit 80eb70b, 05/10) e parecem pesados
   no código, mas pela conta são migalha ou segundo escalão. O céu já está no melhor caminho possível
   (REALTIME + 256, caminho rápido da engine). Há um desperdício de 1 linha (estrelas calculadas de dia).
7. **Carregamento e engasgos do meu escopo:** não há aquecimento de shaders (o mundo fica `visible = false` durante a
   montagem, world_builder.gd:613), 23 retratos 3D em estúdios MSAA 4x são fotografados 1,5 s depois do vale pronto
   (REN-10) e há trabalho síncrono em GDScript em `Mar.montar` e no ruído do céu (REN-16).
8. **Não há nenhum efeito de tela ligado** (SSAO, SSIL, SSR, SDFGI, glow, névoa volumétrica, DOF, ajustes): conferido por
   grep em todos os .gd/.tscn/.tres. Não é por aí.
9. **Ação mais barata e mais informativa para o coordenador:** o teste de escala 3D (ver "Dúvidas", teste T1). Se a 0,5x
   o FPS quase não muda, o gargalo NÃO é pixel e o meu escopo só ajuda pelos multiplicadores (minimapa, sombra, pré-passe).

## Respostas diretas às 7 perguntas do escopo

| # | Pergunta | Resposta curta (detalhe nos achados) |
|---|---|---|
| 1 | Efeitos de Environment | Só: fundo = céu, luz ambiente COR, tonemap FILMIC, névoa exponencial com perspectiva aérea 1.0 e névoa de altura. Nenhum efeito de tela. Valores trocados TODO QUADRO: `ambient_light_color/energy`, `fog_light_color`, `fog_density`, `fog_sun_scatter`, `fog_height_density` (ceu_vale.gd:153-160) |
| 2 | Céu | `ShaderMaterial` próprio (ceu_vale.gdshader), `process_mode = REALTIME`, `radiance_size = 256` (ceu_vale.gd:73-75). O shader usa `TIME` (nuvens, cintilar) e os uniforms mudam todo quadro: o cubemap de radiância é regerado todo quadro. Já é o caminho rápido da engine. Custo por pixel do céu: baixo (REN-07) |
| 3 | Luzes e sombras | 2 DirectionalLight3D (Sol com sombra PSSM 4 cascatas, 180 u; Lua sem sombra). OmniLight/SpotLight: 12 exteriores (só de noite) + ~20 interiores (sempre ligadas, com máscara de camada). NENHUMA luz posicional com sombra. Atlas direcional e filtro suave no padrão (4096, "Soft Low"). Sol move todo quadro (ceu_vale.gd:118) |
| 4 | Mar, água, rio | Mar = 1 quad gigante com shader que lê tela e profundidade; fundo do mar = malha de 137.500 triângulos; fundo distante = 18.432; rios = fitas alfa sem leitura de tela. Sobrepostos: mar, rio, foz, silhueta de peixe, espuma, respingo (alfa) |
| 5 | Shaders | 14 .gdshader + 1 .gdshaderinc, tabela em REN-15 (seção "Tabela dos shaders") |
| 6 | Resolução e AA | 1080p, MSAA 2x, sem scaling 3D, sem FXAA/TAA/debanding, V-Sync padrão (ligado), sem limite de FPS e sem opção gráfica para o jogador. V-Sync a 60 Hz quantiza em 60/30/20/15 conforme o buffering (REN-05) |
| 7 | Chaves ausentes | Tabela em REN-15 |

## Fatos contados

Convenção: "est." = estimativa com conta; as demais são contagens do código ou dos dados.

| Fato | Valor | Fonte |
|---|---|---|
| Renderer | Forward+ (Vulkan). `gl_compatibility` só vale para Mobile | project.godot:17, :96 |
| Chaves em `[rendering]` | 2: `renderer/rendering_method.mobile` e `anti_aliasing/quality/msaa_3d=1` (MSAA 2x) | project.godot:94-97 |
| Janela | `window/size/mode=3` (tela cheia), base 1280x720, stretch `canvas_items` (3D desenha na resolução da janela) | project.godot:63-72 |
| Pixels 3D a 1080p | 1.920 x 1.080 = 2.073.600 px; 4.147.200 amostras com MSAA 2x | conta |
| Pixels relativos | 720p = 0,44x; 1024x576 = 0,28x do 1080p (o 1080p tem 2,25x e 3,5x mais pixels) | conta |
| V-Sync, `max_fps`, `scaling_3d`, FXAA, TAA, debanding | Nenhum definido (padrões: V-Sync ligado, sem limite, 100%, sem AA de tela). Único toque em V-Sync: desliga durante a montagem | grep sem ocorrência; tela_carregamento.gd:487-506 |
| Opções gráficas para o jogador | Nenhuma de qualidade. Existe só "Minimapa: Mostrar/Ocultar" | painel_ajustes.gd:253-285 (lista completa), :261-268 |
| GPU do autor (log) | Vulkan 1.4.312, Forward+, GTX 1660 Ti with Max-Q Design | %APPDATA%/MythsValleyPrototype3D/logs/godot.log:2 |
| Preferências do autor | `velocidade=3` (Rápida: 10 s por hora), `cheia=true`, `sobrevoo=true`, `mare modo=0`, minimapa não gravado (padrão = ligado) | %APPDATA%/MythsValleyPrototype3D/preferencias_visuais.cfg |
| WorldEnvironment | 1 (criado por código). Nenhum em .tscn | ceu_vale.gd:86-88; grep em scenes/ |
| Efeitos de tela (glow, SSAO, SSIL, SSR, SDFGI, névoa volumétrica, DOF, ajustes, CameraAttributes) | 0 ocorrências em todo scripts/, scenes/, assets/ | grep |
| Tonemap | FILMIC | ceu_vale.gd:80 |
| Névoa | exponencial; densidade 0,0011 (dia) / 0,0016 (dourada) / 0,0020 (noite) por unidade; `aerial_perspective = 1.0`; `sky_affect = 0`; `fog_height = 2.5`; neblina de altura até 0,15 entre 3h30 e 7h15 | ceu_vale.gd:27-38, :81-85, :158-160 |
| Névoa a 280 u / 2.800 u | 26,5% / 95,4% (conta: 1 - exp(-0,0011 x d)) | conta; portão tests/ceu_horizonte.gd:83-100 |
| Câmera do jogador | fov 58, near 0,08, far 2.800 | player_controller.gd:259-262 |
| Céu | `Sky` com ShaderMaterial; `PROCESS_MODE_REALTIME`; `RADIANCE_SIZE_256` | ceu_vale.gd:71-75 |
| Cubemap do céu por quadro | 6 x 256² = 393.216 px (passada cheia) + passada de meia resolução das nuvens (6 x 128² = 98.304 px) | conta |
| Luz ambiente | fonte COR (cad9d5 -> 2b3454), energia 0,3 -> 0,65 | ceu_vale.gd:79, :153-154 |
| Luzes direcionais | 2: "Sol" (sombra ligada, PSSM 4 cascatas, `max_distance` 180 u) e "Lua" (sem sombra) | ceu_vale.gd:89-99 |
| Atlas de sombra direcional e filtro | Padrão da engine: 4096² (cada cascata 2048²) e "Soft Low"; nenhum `directional_shadow/*` no projeto | project.godot (ausência) |
| Sol muda todo quadro | `sol.basis` e uniforms do céu a cada `hora_mudou`, e `Dia._process` emite `hora_mudou` a cada quadro | ceu_vale.gd:118; dia.gd:109-120 |
| Ouvintes de `hora_mudou` (todo quadro) | 12: Audio, Abertura (x2), AmbienteVale, ClockIcon, HUD, Saveiro, WorldBuilder, e 1 por cômodo (x4) | audio.gd:295; abertura.gd:196,828; ambiente_vale.gd:52; clock_icon.gd:9; prototype_hud.gd:861; saveiro_vale.gd:131; world_builder.gd:725; comodo.gd:562 |
| Luzes exteriores (só acesas à noite) | 12: 3 lampiões da praça + 3 candeeiros + 1 lampião + 2 luz_janela (composição) + 1 candeeiro do píer + 2 fogueiras | world_builder.gd:2036-2049; composicao_vale.tscn (grep tipo=) |
| Luzes interiores (sempre `visible`) | 4 cômodos (igreja, casa, casa do Pedro, casa da Zefa): cada um 1 lampião + velas + 1 SpotLight por janela. Igreja: 1 + 2 velas + 2 x (nave/2,6 m) fachos. Casas: 1 + 1 a 2 + 1. Total estimado 20 a 25 | comodo.gd:466-473, :538-548; interior_igreja.gd:182, :214; interior_casa.gd:166, :397, :451, :486, :503; interiores.gd:61-73, :95-96 |
| Luzes posicionais com sombra | 0 (Omni/Spot nunca ligam `shadow_enabled`) | luzes_epoca.gd:143; comodo.gd; grep |
| ReflectionProbe | 4 (uma por cômodo), `UPDATE_ONCE`, `interior`, `box_projection` | comodo.gd:454-465 |
| Decal "Terreiro" | 23 instâncias na composição (22 casas e a igreja), 9x2,4x8 u, sem `distance_fade` | composicao_vale.tscn (grep node name="Terreiro"); terreiro_casa.tscn:6-12; world_builder.gd:904-909 |
| GPUParticles3D | fogueira: 2 fogos x (72 + 16) = 176 partículas, ativas de dia; espuma_agua: 1 nó por morador e jogador (56 partículas, só emitem dentro d'água); respingo 10; rastro do tubarão 20 | luzes_epoca.gd:36,86; espuma_agua.gd:20; cardume.gd:931; tubarao.gd:446 |
| SubViewports 3D no vale | Minimapa (170x170 px, `UPDATE_ALWAYS`, mundo compartilhado); retratos (256² MSAA 4x, 1 por vez, 23 no total); mochila e painel de personagens só quando abertos | minimapa.gd:80-100; retratos_3d.gd:89-97; boneco_da_mochila.gd:108,225; painel_personagens.gd:671 |
| Mar (superfície) | 1 PlaneMesh sem subdivisão = 2 triângulos, tamanho `_bounds.grow(4000)` | mar.gd:75; geo_region_renderer.gd:1012 |
| Fundo do mar (malha detalhada) | batimetria 550x500; 1 vértice a cada 2 células = 275x250 quadrados; 69.276 vértices; 137.500 triângulos; 5 leituras de textura por vértice | mar.gd:10, :62-64; data/mapas/bom_jesus_dos_pobres_cenario.json (bathymetry.size = [550, 500]); conta |
| Fundo do mar distante | 96x96 quadrados = 18.432 triângulos, 9.409 vértices | mar.gd:12, :67 |
| Terreno "Terra" | 1 malha única para o polígono de terra: 263.351 u²; célula de 4 u (0,8 u junto aos rios). Est. ~60 mil triângulos (53 mil + 8 mil dos rios); 263.351 / ~5 u² por triângulo | geo_region_renderer.gd:76,86,345,1068-1094; conta (area.py) |
| Texturas do chão | 8 camadas de 1.024² PNG, importação VRAM Compressed (S3TC) com mipmaps | geo_region_renderer.gd:42-51; grama_baixa_v1.png.import |
| `agua_mar.gdshader` | 11 leituras de textura por pixel (2 normais, 2 profundidade, 1 tela, 6 ruído) | agua_mar.gdshader:59-99 |
| `terreno.gdshader` | 9 samplers + 1 array; por pixel: 5 leituras do array de solo + 1 a 2 da grama + até 7 camadas condicionais (típico 8 a 10, máximo ~16) e ~16 `sin` de hash | terreno.gdshader:22-31, :113-251 |
| Shaders com leitura de tela/profundidade | 1 de 14 (`agua_mar`) | grep hint_screen_texture/hint_depth_texture |
| GLBs | 262; todos com `generate_lods=true` e `create_shadow_meshes=true` | grep nos .glb.import |
| MultiMesh de vegetação | `cast_shadow = OFF` em todos os blocos | geo_region_renderer.gd:2158; tests/lod_vegetacao.gd:105 (copas) |
| O que faz sombra | tudo o que não é MultiMesh de vegetação nem cardume: terreno (única malha), casas, árvores nomeadas, moradores, bichos, adereços | grep cast_shadow (17 ocorrências em 11 arquivos, quase todas OFF) |
| Onde as coisas entraram | `ceu_vale.gdshader`, `terreno.gdshader`, `solo.gdshaderinc`, `copa_distante`, `nado`, `estrada_acostamento`: commit 80eb70b (05/10). `agua_mar`: e38f9b4 (27/09). Minimapa: df93e2f (28/09). Retratos 3D: 7f196af (03/10). Comodo/sondas: 4bd1ef7 (03/10) | git log --diff-filter=A (leitura) |
| Antes de 80eb70b | `ProceduralSkyMaterial` (modo AUTOMÁTICO), névoa `fog_sky_affect 0.25`, sem perspectiva aérea, sem névoa de altura; mesmas luzes (Sol 4 cascatas 180 u) | git show 80eb70b^:scripts/prototipo_3d/world_builder.gd:693-721 |
| Medições anteriores | 26/09, 1280x720: Tripo com mata em blocos 60 FPS (2,4 a 3,6 M tri). 30/09, 1024x576, V-Sync off, minimapa off: 19,6/21,6; 28,8/32,8; 12,6/20,3 FPS (sem/com LOD) | VALE_VIVO_3D.md:121-165 |
| O que o HUD de "tri" conta | `RENDER_TOTAL_PRIMITIVES_IN_FRAME` (todas as passadas e viewports, inclusive sombras, pré-passe e minimapa; confiança média) | prototype_hud.gd:764 |

### Orçamento de quadro (para ler os achados)

60 FPS = 16,7 ms. 15 FPS = 66,7 ms. Procuramos ~50 ms de excesso. Com V-Sync a 60 Hz e buffering curto, tempos de GPU de
16,7 a 33,3 ms aparecem como 30 FPS, 33,3 a 50 ms como 20 FPS e 50 a 66,7 ms como 15 FPS (REN-05).

Ordem de grandeza do que está no meu escopo (estimativa, GTX 1660 Ti Max-Q ~3,5 TFLOPs, ~110 Gtexel/s, 288 GB/s):

| Item | Estimativa | Conta resumida |
|---|---|---|
| Minimapa (2ª passada) | 2 a 8 ms (CPU + GPU) | ~1 M primitivas extras x (pré-passe + cor) + shadow + 100 a 300 draws; depende de estar CPU-bound |
| Sombras do Sol | 2 a 6 ms | 4 cascatas x casters não-MultiMesh (terreno 60 mil tri em todas), filtro suave padrão |
| MSAA 2x + cópias de tela/profundidade | 2 a 5 ms | largura de banda: cor FP16 2x (33 MB) + depth + resolve + cópia com mips |
| Água | 1 a 2 ms | 11 leituras x ~1 M px de mar + cópia de tela |
| Terreno (shader novo) | 1 a 3 ms | ~10 leituras anisotrópicas x 2,07 M px ~ 20 a 60 M texels |
| Céu | 0,3 a 1 ms | 393 mil px de cubemap + filtro + passada de tela |
| Luzes interiores, decals, partículas | < 1 ms | agrupados por cluster; pequenos |
| **Soma plausível** | **8 a 25 ms** | de ~50 ms: o resto tende a ser geometria/CPU (outros escopos) |

## Achados

### REN-01. O minimapa desenha o vale uma segunda vez por quadro (alto, confiança média)

**Evidência**
- `minimapa.gd:94-100`: `SubViewport` com `own_world_3d = false` (mesmo mundo do vale) e `render_target_update_mode = UPDATE_ALWAYS`.
- `minimapa.gd:140-144`: desliga só quando escondido, com mapa grande ou com o painel CONTROLES aberto.
- `minimapa.gd:156`: padrão = mostrar (`get_value("interface", "minimapa", true)`); `painel_ajustes.gd:261-268`: único controle. O autor nunca gravou "ocultar" (preferencias_visuais.cfg).
- `minimapa.gd:101-106`: câmera ortográfica de topo, `size = 55`, `far = 400`, a 100 u acima do jogador (`ALTURA_CAMERA`, linha 27).
- `minimapa.gd:123-126`: `ambiente.duplicate()` com `fog_enabled = false`. É uma cópia estática: ela não acompanha a hora (ambiente e céu da cópia ficam congelados no instante de `configurar`), e compartilha o recurso `Sky` com o original.
- `prototype.gd:1195-1198`: criado sempre que o vale monta.
- `tools/prototipo_3d/medir_lod.gd:28-33` DESLIGA todos os SubViewports antes de medir: as medições de LOD e de "60 FPS" não incluem o minimapa.
- Ponto de atenção: a malha do fundo do mar (137.500 triângulos, AABB = a grade inteira, mar.gd:249 `extra_cull_margin = 32`) e o terreno (~60 mil triângulos, 1 malha) nunca são descartados por frustum, então vão inteiros em toda passada.

**Mecanismo (Godot 4, Forward+)**
Cada SubViewport com `UPDATE_ALWAYS` é uma chamada completa de `render_scene` por quadro: culling de frustum, montagem de listas de render, pré-passe de profundidade, passada opaca, passada transparente, e as sombras direcionais são regeradas para essa câmera (o atlas de sombra é compartilhado, mas o conteúdo é calculado por passada de cena). O custo NÃO é proporcional aos 170x170 px (28.900 px), e sim à geometria e às chamadas de desenho dentro da coluna 55x55 u e às malhas únicas que sempre entram. Câmeras ortográficas escolhem a distância de LOD igual a 1,0 (confiança média; leitura minha do código da engine, a confirmar com o A/B abaixo), ou seja, tudo na coluna sai no LOD mais detalhado. A coluna cobre 3.025 u²; com a densidade de árvores da mata (6.234 árvores em 263.351 u² = 0,0237/u²) são ~72 árvores x ~2,5 mil triângulos (mata_a, mata_b, embaúba, VALE_VIVO_3D.md:129-131) = ~180 mil triângulos, mais terreno 60 mil e leito 137,5 mil: (180 + 60 + 137,5) mil x 2 (pré-passe + cor) = ~0,75 M, mais cascatas da sombra para essa câmera. Estimativa total +0,8 a 1,2 M de primitivas e +100 a 300 draws por quadro. Como o HUD de "tri" conta o quadro inteiro (2,4 a 7,6 M nas medições de 26 e 30/09), o minimapa pode ser de 10 a 20% das primitivas (estimativa).

**Impacto** alto se a cena estiver limitada por CPU de draw ou vértices (o provável, pelas medições de 30/09), baixo se limitada por pixels.

**Correção**
1. HOJE (opção A, 2 linhas, mais segura para a build): `minimapa.gd:156` e `painel_ajustes.gd:261` com padrão `false` (o autor ou o jogador liga em AJUSTAR). Perde o minimapa por padrão: decisão de produto.
2. HOJE (opção B, ~10 linhas, melhor equilíbrio): em `minimapa.gd:144` trocar `UPDATE_ALWAYS` por atualização a ~10 Hz: acumular `delta` em `_process`; quando passar de 0,1 s, `render_target_update_mode = SubViewport.UPDATE_ONCE`; senão `UPDATE_DISABLED`. O triângulo do jogador é `Control` desenhado em `_sobre` (continua suave); só o mapa por baixo anda a 10 Hz. O custo cai para ~1/6 do atual a 60 FPS (e para ~1/1,5 a 15 FPS: quanto mais lento o jogo, menos efeito, por isso a opção A pesa mais quando o FPS já está baixo).
3. ESTRUTURAL: dar à câmera do minimapa um `cull_mask` próprio e mover vegetação alta, bichos e moradores para camadas que ela não vê; ou substituir por imagem estática pré-renderizada do mapa (como já existe o mapa grande) com marcadores em Control.
4. Corrigir de passagem o `ambiente.duplicate()` congelado (visual, não é desempenho): atualizar `_camera.environment` quando a hora mudar de bloco.

**Esforço** A: 5 min. B: 20 min. **Risco** baixo: `tests/minimapa.gd` confere existência, quadrado, máscara e aro (linhas 52-100), não o modo de atualização; mudar o padrão para `false` mantém o nó (só fica invisível).

**Como medir**
- Instrumento exato: `RenderingServer.viewport_set_measure_render_time(rid, true)` na raiz e no `SubViewport` do minimapa, e imprimir `viewport_get_measured_render_time_cpu/gpu` + `viewport_get_render_info(rid, VIEWPORT_RENDER_INFO_TYPE_VISIBLE, VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME / DRAW_CALLS_IN_FRAME)` de cada um: dá a fração do minimapa sem ruído de FPS.
- A/B simples: `Minimapa._viewport.render_target_update_mode = UPDATE_DISABLED` (mesma câmera parada); ou gravar `interface/minimapa=false` em preferencias_visuais.cfg (lido a cada 1 s).

### REN-02. Sombras do Sol: 4 cascatas até 180 u sobre quase tudo, atlas 4096, filtro suave padrão (alto, confiança média)

**Evidência**
- `ceu_vale.gd:89-94`: `sol.shadow_enabled = true`, `directional_shadow_max_distance = 180.0`, `SHADOW_PARALLEL_4_SPLITS`. Mesma configuração desde antes de 80eb70b (git show 80eb70b^).
- Nenhum ajuste de `rendering/lights_and_shadows/directional_shadow/*` no project.godot: valem os padrões da engine (atlas 4096² em 16 bits, "Soft Low", `blend_splits` desligado).
- Casters: tudo menos MultiMesh de vegetação (`geo_region_renderer.gd:2158`), copas distantes (tests/lod_vegetacao.gd:105), cardume e água (`shadows_disabled`/OFF). Isto é: o terreno inteiro (1 malha, ~60 mil triângulos), 22 casas, árvores nomeadas, 22 moradores esqueléticos, 22 corpos de quatro patas, 10 bandos (aves: galinha 25, pintinho 7...), adereços, jogador.
- `mar.gd:247`: o mar e o leito não fazem sombra; `leito_mar`, `agua_mar`, `agua_rio`, `foz_rio` têm `shadows_disabled` (não recebem).
- O Sol só some de noite (`sol.visible = luz > 0.02`, ceu_vale.gd:121): à noite NÃO há passada de sombra. Teste natural: o jogo deve ficar mais rápido à noite se a sombra pesa.
- O minimapa regera essas sombras para sua câmera (REN-01).

**Mecanismo**
Sombra direcional em PSSM: cada cascata re-renderiza os casters que tocam o volume dela, de novo em cada quadro (a engine não guarda sombra direcional). Uma malha grande e única (terreno ~60 mil triângulos) entra inteira em TODAS as 4 cascatas (não há como cortar pedaço), e em cada passada do minimapa. O atlas 4096² é 16,8 Mpx de profundidade em 4 cascatas de 2048²: o preenchimento é barato (~0,3 ms); o custo é a submissão de geometria (vértices, draws) e a amostragem com filtro "Soft Low" (PCF de vários taps) em todo pixel opaco iluminado pelo Sol. Com o Sol baixo (a partida começa às 7h, elevação ~10°, e o autor joga em "Rápida", ceu_vale.gd:116-117 limita a luz a ~2° no horizonte) as sombras ficam longas e o volume de casters cresce.

**Impacto** alto/médio. Estimativa 2 a 6 ms (4 cascatas sobre casters não-MultiMesh + PCF em 2 M px). Sem medição.

**Correção**
1. HOJE, menor risco visual: `ceu_vale.gd:92-93` -> `directional_shadow_max_distance = 100.0` e `SHADOW_PARALLEL_2_SPLITS` (com `directional_shadow_split_1 = 0.2`). A névoa já cobre 26% a 280 u, e mais de 10% a 100 u: o corte de sombra a 100 u é pouco visível. Economiza 2 passadas inteiras.
2. HOJE, só configuração: `rendering/lights_and_shadows/directional_shadow/size = 2048` (cada cascata de 2.048² para 1.024²; sombra mais "pixelada" de perto, compensa com 2 cascatas) e `.../soft_shadow_filter_quality = 1` (Soft Very Low) ou `0` (Hard). Em runtime: `RenderingServer.directional_shadow_atlas_set_size(2048, true)`; `RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW)`.
3. HOJE (A/B antes): `cast_shadow = OFF` na malha "Terra". Em `geo_region_renderer.gd:1039-1044` (onde `_add_polygon` cria o `MeshInstance3D`), acrescentar `if label == "Terra": visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF`. Perde a sombra do morro no próprio chão (relevo exagerado 2x do Mirante). Retira 60 mil triângulos de 4 cascatas (e das passadas do minimapa).
4. ESTRUTURAL: `GeometryInstance3D.visibility_range_end` para casters pequenos (bichos, adereços) a 60 a 80 u; dividir o terreno em blocos de 40 u (como a mata) para o frustum de cada cascata descartar blocos; "sombra falsa" (blob) para aves e bichos pequenos.

**Esforço** 1 e 2: 10 min. 3: 15 min. 4: 1 a 3 dias. **Risco** baixo: nenhum portão cobra o modo da sombra (grep em tests/: só `casa.gd:348`, `SHADOWS_ONLY` do telhado visto de cima, intacto). Atenção ao `normal_bias`/acne ao mudar o atlas: conferir à vista no Sol baixo.

**Como medir** A/B: `Sol.shadow_enabled = false` (limite superior do ganho); depois 2 cascatas/100 u; depois atlas 2048; depois `Terra.cast_shadow = OFF`. Comparar também dia 12h x noite (Sol invisível). Visual Profiler do editor (Debugger > Visual Profiler) mostra o bloco "Render Directional Shadows" em ms de GPU.

### REN-03. 1080p + MSAA 2x, sem escala 3D, sem opção de qualidade (médio; vira alto se o teste T1 mostrar ganho)

**Evidência**
- `project.godot:67` e `:97`: tela cheia, MSAA 2x; nada de `scaling_3d`, FXAA, TAA (grep). O jogador não tem opção gráfica (painel_ajustes.gd:253-285).
- Todas as medições "boas" são a 1280x720 (VALE_VIVO_3D.md:119) ou 1024x576 (:158).

**Mecanismo**
Todo custo por pixel escala com a resolução: terreno (~10 leituras anisotrópicas), água (11), névoa, iluminação PBR com ~10 luzes por cluster perto de casas, e a largura de banda do MSAA. MSAA 2x no Forward+ guarda cor FP16 e profundidade em 2 amostras (cor 2,07 M px x 8 B x 2 = 33 MB; profundidade 16,6 MB), roda o pré-passe e a passada de cor a 2 amostras e exige uma resolução (resolve) no fim; com `hint_screen_texture`/`hint_depth_texture` no mar (REN-06) a resolução acontece no meio do quadro. É um imposto de banda, não de ALU (confiança média). Estimativa: de 15 a 30% do tempo de GPU em cenas ligadas a pixel.

**Impacto** médio (alto se o gargalo for pixel).

**Correção**
1. HOJE (config): FSR 1.0 a 0,75: `rendering/scaling_3d/mode = 1` e `rendering/scaling_3d/scale = 0.75` (1.440x810 = 56% dos pixels) mantendo MSAA 2x (sobre menos pixels). A UI é desenhada em resolução nativa (canvas_items), só o 3D fica mais macio.
2. HOJE (config alternativa): `rendering/anti_aliasing/quality/msaa_3d = 0` + `rendering/anti_aliasing/quality/screen_space_aa = 1` (FXAA, ~0,3 ms). Perde nitidez nos galhos finos e telhados; ganha 1 resolução de MSAA e metade da banda.
3. HOJE (código, ~40 linhas): preset "Qualidade gráfica" (Alta/Média/Baixa) em AJUSTAR > Cenário, no molde de `painel_ajustes.gd:261-268`, gravando em preferencias_visuais.cfg e aplicado por `Tela._ready` (tela.gd:56) em `get_viewport().msaa_3d`, `scaling_3d_scale`, `RenderingServer.directional_shadow_atlas_set_size` e na pasta do minimapa. Sugestão de padrão "Média" = FSR 0,77 + MSAA 2x + sombras 2048/2 cascatas.
4. Para compensar degradê do céu ao reduzir qualidade: `rendering/anti_aliasing/quality/use_debanding = true` (custo ~0).

**Esforço** 1 e 2: 5 min. 3: 1 a 2 h. **Risco** baixo (visual; nenhum portão cobra AA). FSR com UI: nenhuma interferência. TAA e FSR 2 não recomendados (vetores de movimento, fantasmas em mata e esqueletos).

**Como medir** T1 (escala 3D 0,5): `get_viewport().scaling_3d_scale = 0.5`. Se o FPS sobe pouco (ex.: de 15 para 17), o gargalo NÃO é pixel e REN-03 não é prioridade. T2: `msaa_3d = MSAA_DISABLED`. T3: janela 1280x720 (`DisplayServer.window_set_size`).

### REN-04. Pré-passe de profundidade (padrão da engine) duplica o trabalho de vértices da mata (médio, confiança baixa)

**Evidência**
- Não há `rendering/driver/depth_prepass/enable` no project.godot: vale o padrão da engine (ligado em desktop; confiança alta).
- A mata, o sub-bosque, o paisagismo e as copas distantes são MultiMesh de milhões de triângulos (VALE_VIVO_3D.md:130-170: 7,6 a 17,3 M "tri no quadro").

**Mecanismo**
O pré-passe renderiza TODA a geometria opaca (vértices + descartes de alfa) numa passada só de profundidade, e depois a passada de cor repete a mesma geometria. O ganho é eliminar sombreamento de pixel redundante (overdraw): importante com o shader pesado do terreno e a água. O custo é dobrar a carga de vértices/primitivas e de draw calls. Em cena ligada a geometria (o caso provável da mata) o pré-passe pode ser mais caro do que economiza. O contador de "tri" do HUD soma as duas passadas.

**Impacto** médio (potencial alto em vegetação densa), mas só medição diz o sinal. Estimativa: se a mata é 70% do tempo de GPU e é limitada por vértices, desligar o pré-passe remove até ~35% dela; se for limitada por pixel, piora.

**Correção** HOJE (config, reversível): `rendering/driver/depth_prepass/enable = false`. Não existe propriedade em runtime; o coordenador testa com um `override.cfg` ao lado do project.godot ou editando o projeto numa cópia.

**Esforço** 2 min. **Risco** médio: mais sombreamento redundante do terreno (shader de 8 camadas) e da água; nenhum portão. Reverter se piorar.

**Como medir** A/B de FPS e do bloco "Prepass" no Visual Profiler (dá o ms da passada que se elimina). Comparar na vista "perto da mata" e "praça".

### REN-05. V-Sync ligado a 60 Hz quantiza o FPS e esconde o tempo real; sem limite nem opção (médio, confiança média)

**Evidência**
- Nenhum `display/window/vsync/vsync_mode` no project.godot; `Engine.max_fps` nunca definido (grep). A única alteração é desligar durante a montagem (tela_carregamento.gd:487-506).
- O HUD mostra `Engine.get_frames_per_second()` inteiro (prototype_hud.gd:761).
- O autor descreve "cai de 60 para 15": 15 = 60/4 e 66,7 ms = 4 intervalos de 16,7 ms.

**Mecanismo**
Com V-Sync e fila de quadros curta, a apresentação só acontece em intervalos do monitor: tempo de quadro de 16,7 a 33,3 ms aparece como 30; 33,3 a 50 como 20; 50 a 66,7 como 15. Em tela cheia sem borda do Windows 10 isso passa pelo DWM. Com triple-buffering e filas maiores a média cai de forma contínua (ex.: 43, 27, 18). Portanto V-Sync não CRIA o custo; quantiza e esconde. É coerente com 15 FPS, mas não prova nada: o que importa é o tempo real do quadro.

**Impacto** médio (diagnóstico e percepção). Efeito colateral útil: V-Sync ligado também limita a GPU a 60 em cenas leves (menos calor no notebook).

**Correção**
1. Diagnóstico HOJE: no teste, V-Sync desligado e uma linha no HUD com o tempo de quadro (ms) e o pico: `Performance.get_monitor(Performance.TIME_PROCESS)` + `TIME_PHYSICS_PROCESS` + `1000.0 / Engine.get_frames_per_second()` e o máximo dos últimos 120 quadros.
2. Para o jogador: manter V-Sync, oferecer "Adaptativo" (`display/window/vsync/vsync_mode = 2`: tela sem trava de degrau a 30/20 e sem tearing acima de 60) ou "Mailbox" (3; sem degrau e sem tearing, mais calor). Padrão sugerido para notebook: Adaptativo.

**Esforço** 10 min o HUD; 5 min a chave. **Risco** nenhum (diagnóstico); Adaptativo pode ter tearing leve abaixo de 60.

**Como medir** Olhar o HUD: se só aparecem 60/30/20/15 e múltiplos exatos, é quantização; se aparecem 43/27/18, não é.

### REN-06. Água do mar: leitura de tela e profundidade força cópias no meio do quadro; leito dobrado por baixo (médio, confiança média)

**Evidência**
- `agua_mar.gdshader:14-15`: `hint_screen_texture` (`filter_linear_mipmap`) e `hint_depth_texture`; `:12`: `blend_mix, depth_draw_opaque`; `:64,68,75`: duas leituras de profundidade (a segunda para a refração) + 1 de tela; no total 11 leituras por pixel (linhas 59-99), 2 `sin`, 1 `exp`.
- É o único shader do projeto com essas leituras (grep).
- `mar.gd:75`: o mar é UM quad (2 triângulos); o fragment roda em todo pixel de mar visível (vista da praia, píer e sobrevoo: de 30 a 60% da tela é mar, estimativa).
- Por baixo: `leito_mar.gdshader` (opaco, 7 leituras de ruído, 137.500 triângulos) é sombreado e depois coberto pelo mar: cada pixel de mar paga o leito + a água. O pré-passe garante que o leito só seja sombreado uma vez, mas a água sombreia de novo por cima.
- Sobrepostos transparentes: mar (`agua_mar`), 2 rios + foz (`agua_rio`, `foz_rio`, alfa), silhueta de peixe (`silhueta_rio`), espuma do jogador/moradores (`espuma_agua.gd:63`, prioridade 1), respingos e anel (`cardume.gd:952-968`), sombra do tubarão (`tubarao.gd:420,474`), pegadas (`pegadas.gd:40`).

**Mecanismo**
Usar a textura de tela obriga a engine a, no meio do quadro: (a) terminar a passada opaca, (b) resolver o MSAA de cor e de profundidade, (c) copiar a cor para a textura traseira e GERAR A CADEIA DE MIPMAPS por desfoque (o sampler é `filter_linear_mipmap`), (d) copiar a profundidade. A transparência vem depois. Em 1080p: leitura/escrita da cor FP16 (16,6 MB) + cadeia de mips + resolução de MSAA 2x (33 MB lidos) + profundidade: ~100 MB de tráfego, ~0,4 a 1,5 ms numa placa de 288 GB/s (estimativa; confiança média no mecanismo, baixa no valor). Os 11 fetches x ~1 M px (mar) = ~11 M texels: ~0,1 ms; o custo dominante é a cópia, não o shader. O sort do mar (1 quad de ~36 km, origem longe) com rios/espuma pode ficar fora de ordem: visual, não desempenho.

**Impacto** médio (1 a 2 ms estimado).

**Correção**
- HOJE (migalha, baixo risco): nada a mudar sem perder o visual. Se o A/B mostrar custo grande: remover a segunda leitura de profundidade da refração (`:68`) e a refração (`refracao` 0,018): economiza 1 fetch por pixel e quase não muda a imagem.
- ESTRUTURAL (pós-entrega): trocar a leitura de tela por mistura alfa pela espessura (`ALPHA = 1.0 - média(passa)`, albedo da cor funda), mantendo SÓ a profundidade; elimina a cópia de cor com mips e a resolução de cor (a de profundidade permanece). Perde a refração do fundo. Esforço 1 dia; risco visual médio.
- ESTRUTURAL: dividir o mar em tiles com `visibility_range` (ou 2 níveis: perto com a água completa, longe com água simples sem leitura de tela, após ~600 u onde a névoa já cobre 48%).

**Esforço** HOJE 0 a 10 min. **Risco** alto para o visual do "mar lindo" se trocar o shader sem tempo de revisar.

**Como medir** Esconder `.../Mar` (MeshInstance3D "Mar", filho do nó da região "bom_jesus_dos_pobres"): `visible = false` e ver o ganho de FPS e dos blocos "Copy screen texture"/"Resolve" do Visual Profiler. Em seguida esconder "Fundo do mar" e "Fundo do mar distante".

### REN-07. Céu: radiância REALTIME regerada todo quadro e estrelas calculadas de dia (baixo/médio, confiança média)

**Evidência**
- `ceu_vale.gd:73-75`: `PROCESS_MODE_REALTIME` e `RADIANCE_SIZE_256`; portão `tests/ceu_horizonte.gd:85` exige REALTIME.
- `ceu_vale.gdshader:11`: `use_half_res_pass, disable_fog`; usa `TIME` (linhas 90, 121) e uniforms que mudam todo quadro (ceu_vale.gd:137-151).
- `ceu_vale.gdshader:206-208`: `ceu_estrelado(d)` (~12 estrelas nomeadas, 2 grades 3D, 2 `textureLod`, `sin`) é calculada em TODO pixel de céu mesmo de dia; o resultado é multiplicado por `pow(1.0 - luz, 3.0)` (zero de dia). Só pula no cubemap (`!cubo`).
- Antes de 80eb70b: `ProceduralSkyMaterial` (sem TIME).

**Mecanismo**
Em REALTIME a engine renderiza o céu nas 6 faces do cubemap (256² = 393 mil px, passada completa mais a passada das nuvens a 128²) e o filtra pelo caminho rápido de radiância, todo quadro. É a escolha certa da documentação para `radiance_size = 256` (o caminho rápido só existe para 256). Para que serve a radiância aqui: reflexo especular de materiais StandardMaterial3D e a COR DA NÉVOA (perspectiva aérea lê a radiância); a luz ambiente é COR (`ambient_light_source = COLOR`, linha 79), então não depende dela. Em tela: o céu desenha em 1080p nos pixels sem geometria, com estrelas inclusive de dia (~450 ALU por pixel, estimativa; o compilador pode dobrar as constantes de `celeste(...)`). 40% da tela x 2,07 M px x 450 ALU = ~0,4 GFLOP = ~0,1 ms. Migalha.

**Impacto** baixo/médio: estimativa 0,3 a 1 ms somando radiância + tela.

**Correção**
- HOJE (1 linha, risco nenhum): `ceu_vale.gdshader:207` -> `if (luz < 0.98) { ceu += ceu_estrelado(...) ... }` (evita ~450 ALU por pixel de dia). Ganho pequeno.
- A/B (config): `ceu.process_mode = Sky.PROCESS_MODE_INCREMENTAL` (radiância em vários quadros, qualidade melhor; nuvens e cores mudam devagar). Exige trocar a asserção de `tests/ceu_horizonte.gd:85`. Só vale se o A/B mostrar custo.
- ESTRUTURAL: atualizar o céu a cada N quadros (parar de mexer os uniforms por quadro, ver REN-13) e usar `QUALITY` + reflexo estático para as horas "paradas".

**Esforço** 2 min a 20 min. **Risco** baixo (INCREMENTAL altera um portão).

**Como medir** `ambiente.background_mode = Environment.BG_COLOR` (some o céu inteiro; para ver o limite superior, também `ambiente.fog_aerial_perspective = 0.0` e `ambiente.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED`). Visual Profiler: blocos "Sky" e "Render Sky Cubemap".

### REN-08. Terreno com o shader de 8 camadas (entrou em 05/10): custo por pixel moderado, é o chão da tela toda (médio, confiança média-baixa)

**Evidência**
- `terreno.gdshader:22-31`: 9 samplers com `filter_linear_mipmap_anisotropic`, `textureGrad` (derivadas explícitas, linhas 158-211); `:55`: `sampler2DArray solo` com 5 camadas lidas por pixel (131-135); `:121-123` + `solo.gdshaderinc:6-21`: 3 ruídos de valor com `sin` (~16 `sin` por pixel); `:101-110`: `distance()`, `MAIN_CAM_INV_VIEW_MATRIX` e leitura de textura por vértice no vertex shader (só com `copa_ergue > 0` e câmera em perspectiva).
- Uma mesma malha "Terra" (geo_region_renderer.gd:345), com `cull_disabled` (terreno.gdshader:2) e `cast_shadow` ligado (REN-02).
- Antes de 80eb70b o chão era um StandardMaterial3D de uma textura (git show 80eb70b^).
- Oito texturas de 1.024² em VRAM comprimida: ~11 MB, não é VRAM.

**Mecanismo**
Por pixel: 5 leituras do array + 1 a 2 da grama + camadas condicionais (capim, folhiço, terra... se o peso passar de 0,02) = 8 a 10 típico, ~16 no pior caso; textura anisotrópica 4x (`rendering/textures/default_filters/anisotropic_filtering_level` padrão 2) pode multiplicar o custo de cada leitura em ângulo rasante (a câmera 3ª pessoa olha o chão em ângulo raso). Conta: 2,07 M px x ~10 leituras = 20 M texels bilineares; com aniso efetivo x2 a x3: 40 a 60 M texels = 0,4 a 0,6 ms a 110 Gtexel/s, mais ~16 `sin` x 2,07 M = SFU, trivial. Estimativa 1 a 3 ms; com o pré-passe, só os pixels visíveis do terreno pagam (sem overdraw). É relevante, não é 50 ms.

**Impacto** médio.

**Correção**
- HOJE (config): `rendering/textures/default_filters/anisotropic_filtering_level = 1` (2x). Um pouco mais embaçado em ângulo raso; menos banda.
- HOJE (shader, baixo risco): ramificar por distância: acima de ~60 u, só grama + terra (pular capim, folhiço, barro, pedrisco) e usar `texture()` em vez de `textureGrad()` fora dos ifs; desligar a "segunda amostra da grama" (linhas 159-165) além de 150 u. O visual de perto é igual.
- ESTRUTURAL: pré-misturar as camadas numa textura de "splat" por bloco em vez de 8 camadas por pixel.

**Esforço** 10 min config; 1 a 2 h shader. **Risco** médio (muda a cara do chão; revisar à vista na praça e na orla).

**Como medir** `Terra.material_override = StandardMaterial3D` simples e ver o delta; ou `Terra.visible = false` (limite superior). Comparar de pé na praça e no alto do Mirante.

### REN-09. Luzes e decals pequenos, sempre ativos (baixo, confiança média)

**Evidência**
- Luzes interiores: ~20 a 25 (REN: tabela), `visible = true` o tempo todo exceto as janelas, que ligam só de dia (comodo.gd:553-560); `light_cull_mask = CAMADA_DO_COMODO | CAMADA_DOS_CORPOS` (comodo.gd:471,487,544).
- Decals: 23 "Terreiro", 9x2,4x8 u, sem `distance_fade_enabled` (terreiro_casa.tscn:6-12); world_builder.gd:904-909.
- Fogueiras: 2 x (72 + 16) partículas aditivas ativas de dia (luzes_epoca.gd:36,86). As luzes do vale (lampiões, candeeiros) apagam de dia (`visible = _acesas`, luzes_epoca.gd:188).

**Mecanismo**
Forward+ agrupa luzes e decals em clusters 3D; um pixel só paga as luzes/decals do seu cluster. Interiores e fachos de janela (alcance `largura * 1,6` a `1,4` u, comodo.gd:541; interior_igreja.gd:216) cobrem a calçada e o chão em volta da igreja e das casas: junto a elas, cada pixel soma ~10 luzes (a máscara de camada só rejeita depois da entrada no laço). Decals: cada Decal aplica sua textura 1.024² nos pixels dentro do AABB e a Forward+ aplica decals na passada de cada material, sempre (mesmo a 2.800 u). Pequeno: <1 ms combinado.

**Impacto** baixo.

**Correção**
- HOJE (1 propriedade por decal): `decal.distance_fade_enabled = true`, `distance_fade_begin = 70.0`, `distance_fade_length = 25.0` (world_builder.gd:904-909). A 100 u o decal some.
- HOJE (5 linhas): em `Interiores._process`/`camera_do_lado_de_dentro`, ligar `visible` das luzes do cômodo só quando o jogador está dentro (ou a < 12 u da porta). Risco: moradores dentro de casa vistos de fora ficam sem luz; checar `tests/interiores.gd` e `tests/casa.gd`.
- Fogueira: desligar as partículas de dia (`emitting = _acesas`).

**Esforço** 10 a 30 min. **Risco** baixo a médio (interiores).

**Como medir** Esconder o nó "Interiores" (ou as luzes) junto à igreja; esconder os decals "Terreiro *".

### REN-10. Retratos 3D: 23 estúdios MSAA 4x logo depois do vale pronto (médio, travadas/carregamento, confiança média)

**Evidência**
- `prototype.gd:1024-1030`: 1,5 s depois do vale de pé (`_pedir_os_retratos`), pede a foto de `pedro` + `Afinidade.MORADORES` (22 + 1 = 23, "moradores=22" no log).
- `retratos_3d.gd:89-97`: um `SubViewport` 256² com `msaa_3d = MSAA_4X`, `UPDATE_ALWAYS`, mundo próprio (`own_world_3d`), 3 luzes e um `WorldEnvironment`; instancia o GLB do morador (`CatalogoAssets.instanciar`, linha 159), espera 3 quadros (`frame_post_draw` x3, linhas 117-142) e lê a imagem da GPU (`get_image()`, linha 145 = sincronização).
- Resultado: ~70+ quadros de "ensaio" encadeados, em cima do início do jogo.

**Mecanismo**
Cada foto cria um mundo 3D, instancia um GLB esquelético (carga de disco + textura para VRAM), renderiza com MSAA 4x e sincroniza CPU/GPU na leitura (a GPU esvazia a fila). Aparece como engasgos repetidos nos primeiros 10 a 30 s do vale. Ao mesmo tempo o shader do morador é compilado pela primeira vez no estúdio (cache frio).

**Impacto** médio (travadas na chegada; mata a primeira impressão da build). Sem efeito no FPS estável.

**Correção**
- HOJE (1 linha): adiar para a primeira abertura da tela do arraial ou do diário: em `prototype.gd:768` não chamar `_pedir_os_retratos()`; chamar de dentro de `TeiaSocial.abrir()` (o mesmo `retratos.pedir`). Sem foto, o `teia_social` já usa o desenho 2D de reserva (retratos_3d.gd:26-28).
- HOJE (alternativa): `estudio.msaa_3d = MSAA_2X` ou desligado, `LADO = 128`, e 1 foto a cada 30 quadros.
- ESTRUTURAL: renderizar os retratos na tela de carregamento (cobertos) ou pré-gerar as 23 imagens no build.

**Esforço** 10 min. **Risco** baixo (tests/teia_social.gd:191-197 e tests/saveiro.gd:100 conferem o nó "retratos", que continua existindo).

**Como medir** Gravar o pico de tempo de quadro dos primeiros 60 s com e sem a chamada em `prototype.gd:768`.

### REN-11. Compilação de shaders e pipelines no primeiro quadro, sem aquecimento (médio, travadas/carregamento, confiança baixa)

**Evidência**
- `world_builder.gd:613`: o mundo fica `visible = false` durante toda a montagem (para não desenhar pela metade). Nenhum pipeline do vale é compilado durante a tela de carregamento. `visible = true` só em `_concluir` (659-661).
- grep por "aquec", "warm", "prewarm", "pipeline", "ubershader", "shader_cache" no scripts/: 0 ocorrências.
- A tela de carregamento sai com um fade de 0,35 s logo depois (tela_carregamento.gd:509-511), o que esconde só parte do engasgo.
- Dados de usuário em pasta própria (`config/custom_user_dir_name`, project.godot:15-16): o cache de pipelines/shaders (`%APPDATA%/MythsValleyPrototype3D/shader_cache` e `vulkan`) é por máquina; numa máquina nova (jurados, build do site) o cache está frio.
- Variantes novas de pipeline surgem ao longo do jogo: Omni/Spot ao acender à noite, névoa de altura na alvorada, sombras do Sol, decals, partículas, interiores, retratos, água, silhueta de peixe, cada material de GLB (~200 StandardMaterial3D) x passadas (pré-passe, sombra, cor, transparente).

**Mecanismo**
No Vulkan da Godot 4 um material/formato de malha/passada novos geram um pipeline que pode compilar no meio do quadro (de 10 a 200 ms por variante em driver NVIDIA, sem cache). A engine usa ubershaders e compilação assíncrona nas versões recentes para reduzir o engasgo, mas não o elimina. Consequência: a primeira vez que se vê o mar, o terreno novo, a noite, a igreja de perto, etc., o quadro pode demorar de dezenas a centenas de ms.

**Impacto** médio (percepção de "travadas" na primeira volta, especialmente em máquina nova). Confiança baixa: precisa de log de tempo de quadro.

**Correção**
- HOJE (~15 linhas): em `tela_carregamento.trocar_cena`, depois de `mundo.construido`, manter a tela opaca por 30 a 60 quadros com o mundo `visible` (a câmera já olha o píer): `for i in 45: await arvore.process_frame` antes do `sumir`. Os pipelines das passadas principais compilam coberto pelo overlay.
- HOJE (~30 linhas): "pré-aquecimento": instanciar 1 vez cada material especial (mar, terreno, céu, fogueira, decal, luz noturna, silhueta) numa câmera escondida atrás da tela de carregamento. Também forçar `Dia.definir_hora(...)` para aquecer noite/dia (um quadro cada).
- ESTRUTURAL: cache de pipelines distribuído no build (`rendering/rendering_device/pipeline_cache/enable` já é padrão) ou gerar o cache numa primeira execução e empacotar.

**Esforço** 15 min a 1 h. **Risco** baixo (aumenta o carregamento em ~1 s e esconde o resto).

**Como medir** Registrar `Time.get_ticks_usec()` por quadro nos primeiros 600 quadros após o fade e listar os maiores 10. Teste de máquina fria: renomear `shader_cache` e `vulkan` em `%APPDATA%/MythsValleyPrototype3D` e repetir (restaurar depois).

### REN-12. 4 ReflectionProbes + atlas de reflexos padrão (baixo, memória/travadas, confiança baixa)

**Evidência**
- `comodo.gd:454-465`: 1 `ReflectionProbe` por cômodo (`UPDATE_ONCE`, `interior = true`, `box_projection = true`), 4 cômodos montados no início (`interiores.gd:95-96`).
- Sem `rendering/reflections/reflection_atlas/*` no projeto: padrão da engine (256² x 64 cubemaps).

**Mecanismo**
A primeira vez que a sonda entra no frustum ela renderiza 6 faces (`UPDATE_ONCE`) e a engine aloca o atlas de reflexos (matriz de cubemaps: 64 x 6 faces x 256² x formato FP16, com mips: da ordem de 134 a 268 MB de VRAM, estimativa com conta e formato incertos; confiança baixa em ambos). A igreja é visível de longe, então o engasgo e a alocação acontecem cedo. O custo por quadro é ~0.

**Impacto** baixo (memória, e um engasgo único).

**Correção** HOJE (config, uma linha): `rendering/reflections/reflection_atlas/reflection_count = 8` (4 sondas + folga) e `reflection_size = 256`. Reverter se o `tests/interiores.gd:144` reclamar (confere só a existência da sonda).

**Esforço** 2 min. **Risco** baixo.

**Como medir** `Performance.RENDER_VIDEO_MEM_USED` (HUD já mostra) antes e depois de ver a igreja de perto, com e sem a mudança.

### REN-13. Fan-out por quadro de `hora_mudou` e `Mare` (baixo, CPU, confiança média)

**Evidência**
- `dia.gd:109-120`: `_process` -> `avancar` -> `definir_hora` -> `hora_mudou.emit` TODO QUADRO (com o relógio andando; autor em "Rápida", velocidade=3, 10 s por hora).
- 12 ouvintes (tabela de Fatos); os maiores: `CeuVale.aplicar` (ceu_vale.gd:105-160: ~14 `set_shader_parameter`, 8 `Color`/`Vector3` alocados, `Basis.looking_at` x2, e 7 propriedades do Environment), `LuzesEpoca._atualizar` (12 luzes), 4 x `Comodo._acompanhar_o_dia` (troca `albedo_color` e energia dos fachos), `clock_icon` (`queue_redraw`), HUD.
- `mare.gd:34-54`: por quadro, `get_nodes_in_group("mare_superficie")` (aloca), reposiciona 2 corpos (inclui um `StaticBody3D`) e faz `set_shader_parameter` x2 em 3 materiais, mesmo no modo "Sem maré" (modo=0, o do autor).

**Mecanismo**
Trabalho de GDScript por quadro, de ordem de 0,05 a 0,2 ms (estimativa; ~100 atribuições e ~20 alocações por quadro a ~1 µs). Mover o corpo de física e o nó do mar todo quadro invalida transformada e AABB de render (pequeno). Mudar uniforms de material todo quadro atualiza o buffer de uniformes do material. Nada é grande.

**Impacto** baixo (CPU ~0,1 a 0,3 ms somados).

**Correção**
- HOJE (4 linhas): em `dia.gd:116-120`, emitir `hora_mudou` só quando a hora mudar mais de 0,02 h (~0,6 s reais a "Normal", 30 s por hora; ~0,2 s a "Rápida", 10 s por hora), ou a cada 6 quadros. A iluminação fica visualmente idêntica.
- HOJE: em `mare.gd`, `if modo == 0 and _offset == 0.0: return` depois de configurar os materiais uma vez.

**Esforço** 10 min. **Risco** baixo: `tests/ceu_horizonte.gd` e `tests/luzes_epoca*.gd` chamam `aplicar` direto; conferir os que dependem de `hora_mudou` por quadro (grep em tests/).

**Como medir** `Performance.TIME_PROCESS` (média por quadro) com e sem a mudança, parado no mesmo ponto.

### REN-14. Câmeras ortográficas (mapa grande e mapa do menu): LOD máximo e alcance de visibilidade suspenso (médio, só com o mapa aberto, confiança média-baixa)

**Evidência**
- `mapa_jogo.gd:9,24-26,46-50`: câmera ortográfica a 3.000 u, `far = 4000`; `abertura.gd:1130-1135`: idem para o mapa do menu, `far` 7.000 (abertura.gd:145).
- VALE_VIVO_3D.md:177-179: "O mapa grande ... usa câmera ortográfica a 3000 unidades do chão. Neles o limite [visibility_range] é suspenso" (`geo_region_renderer.gd:2449-2452`, `visibility_range_end = 0.0 if mapa`).
- 6.234 árvores da mata + sub-bosque + paisagismo.

**Mecanismo**
Com visibilidade ilimitada e câmera ortográfica (LOD máximo para tudo, REN-01), o quadro do mapa desenha todos os blocos de vegetação no LOD 0: ~6,2 mil árvores x 2,5 mil a 15 mil triângulos = 15 a 90 M de triângulos (estimativa; a faixa é larga pelo dendê de 15 mil). O jogo fica em poucos FPS enquanto o mapa estiver aberto; é um estado de menu, mas o mapa é o primeiro lugar que o jogador abre.

**Impacto** médio, localizado.

**Correção** HOJE: enquanto o mapa está aberto, esconder as camadas de vegetação alta (ou manter `visibility_range_end` dos blocos de árvore em ~600 u e esconder o miolo): o mapa lê melhor com um "chão verde" (a copa pintada do terreno, `terreno.gdshader:236-248`) do que com 6 mil árvores. Em `geo_region_renderer.gd:2449-2452`: `visual.visible = false` para blocos com `distancia >= LOD_MATA` no modo mapa.

**Esforço** 20 min. **Risco** baixo a médio (aspecto do mapa).

**Como medir** FPS e `viewport_get_render_info` primitivas com o mapa aberto, antes e depois.

### REN-15. Chaves de configuração ausentes e tabela dos shaders (varios)

#### Chaves de ProjectSettings (Godot 4.x) com efeito esperado

Todas ausentes do project.godot (valem os padrões). "Ganho" é só ordem de grandeza e exige A/B.

| Chave exata | Padrão | Sugestão | Efeito visual | Ganho esperado |
|---|---|---|---|---|
| `rendering/scaling_3d/mode` | 0 (Bilinear) | 1 (FSR 1.0) | 3D mais macio, UI nítida | com a escala abaixo |
| `rendering/scaling_3d/scale` | 1.0 | 0.75 (a 0.67 ainda aceitável) | menos nitidez em galhos e telhado | -44% dos pixels (0,5625x): -20 a -40% do tempo de GPU em cena ligada a pixel; ~0 se CPU-bound |
| `rendering/scaling_3d/fsr_sharpness` | 0.2 | 0.2 a 0.4 | compensa o amaciamento | nenhum |
| `rendering/anti_aliasing/quality/msaa_3d` | 1 no projeto (2x) | 0 + FXAA, ou manter 2x | FXAA suaviza também alfa e shaders | -10 a -25% do GPU em banda (estimativa) |
| `rendering/anti_aliasing/quality/screen_space_aa` | 0 | 1 (FXAA), só com `msaa_3d=0` | borda mais macia | ~0,3 ms |
| `rendering/anti_aliasing/quality/use_debanding` | false | true | tira degraus do degradê do céu | custo ~0 |
| `rendering/anti_aliasing/screen_space_roughness_limiter/enabled` | true | false | mais brilho "cintilando" em GLB com normal | pequeno (alguns ALU por pixel) |
| `rendering/lights_and_shadows/directional_shadow/size` | 4096 | 2048 | sombra mais granulada de perto | menos banda e PCF mais barato |
| `rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality` | 2 (Soft Low) | 1 (Soft Very Low) ou 0 (Hard) | borda de sombra mais dura | menos taps por pixel |
| `rendering/driver/depth_prepass/enable` | true | false (A/B) | nenhum | -vértices; ver REN-04 |
| `rendering/mesh_lod/lod_change/threshold_pixels` | 1.0 | 2.0 a 4.0 | LOD mais agressivo: perde detalhe longe, pode "pipocar" | vegetação e GLBs com LOD (todos os 262 têm `generate_lods=true`): -tri em cenas ligadas a vértice |
| `rendering/textures/default_filters/anisotropic_filtering_level` | 2 (4x) | 1 (2x) | chão em ângulo raso mais embaçado | texturas do terreno |
| `rendering/reflections/reflection_atlas/reflection_count` | 64 | 8 | nenhum | VRAM e engasgo único (REN-12) |
| `rendering/reflections/sky_reflections/fast_filter_high_quality` | false | false | já no melhor caso | manter |
| `rendering/occlusion_culling/use_occlusion_culling` | false | não ligar | nenhum | inútil: 0 `OccluderInstance3D` no projeto (grep) |
| `display/window/vsync/vsync_mode` | 1 (Enabled) | 2 (Adaptive) para o jogador; 0 só para diagnóstico | sem degrau | REN-05 |
| `rendering/driver/threads/thread_model` | 1 (Single-Safe) | 2 (Multi-Threaded) só como A/B | nenhum | pode ganhar CPU de submissão; risco alto: o código usa `get_image()` sincronizado, SurfaceTool em runtime e `ResourceLoader` em thread |
| `rendering/environment/ssao/*`, `ssil`, `glow`, `ssr`, `sdfgi` | desligados | NÃO ligar | | já fora |

Equivalentes em runtime (para o coordenador testar sem reiniciar): `get_viewport().scaling_3d_scale / scaling_3d_mode / msaa_3d / screen_space_aa / mesh_lod_threshold`; `RenderingServer.directional_shadow_atlas_set_size(2048, true)`; `RenderingServer.directional_soft_shadow_filter_set_quality(...)`; `DisplayServer.window_set_vsync_mode(...)`; `Engine.max_fps`.

#### Tabela dos shaders (14 .gdshader + 1 .gdshaderinc)

| Shader | Onde é usado | render_mode | Custo por pixel | Leitura de tela/profundidade | Veredito |
|---|---|---|---|---|---|
| `ceu/ceu_vale.gdshader` | `Sky` do WorldEnvironment (ceu_vale.gd:67-72) | `use_half_res_pass, disable_fog` | céu: ~450 ALU de dia (estrelas) + nuvens em meia resolução (5 leituras); cubemap sem estrelas/lua/sol | não | barato (REN-07) |
| `materiais/terreno.gdshader` | malha "Terra" (geo_region_renderer.gd:345, :883-907) | `cull_disabled` | 8 a 16 leituras aniso, 5 do array, ~16 `sin`; vertex com leitura de array | não | moderado, é a tela toda (REN-08) |
| `materiais/solo.gdshaderinc` | incluído por terreno, estrada_acostamento, cruzamento | n/a | hash com `sin`, ruído de valor | n/a | |
| `materiais/estrada_acostamento.gdshader` | fitas "Transição <rua>" (geo_region_renderer.gd:922+) | `cull_disabled` | 1 leitura + ruído (12 `sin`) + `ALPHA_SCISSOR` + `ALPHA_ANTIALIASING_EDGE` | não | descarta no pré-passe; área pequena |
| `materiais/cruzamento.gdshader` | remendo dos cruzamentos de rua | `cull_back` | 2 leituras + ruído + scissor | não | pequeno |
| `materiais/copa_distante.gdshader` | `copas_distantes.gd` (64 triângulos por tronco, até 1.200 u) | `cull_back, specular_disabled` | 2 ruídos de valor (~8 `sin`) | não | barato por pixel; custo é a quantidade de instâncias |
| `mar/agua_mar.gdshader` | superfície do mar (mar.gd:69-75) | `blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx, shadows_disabled` | 11 leituras, 2 `sin`, `exp` | SIM: tela (com mips) + profundidade | o único caro por passada (REN-06) |
| `mar/leito_mar.gdshader` | fundo do mar e fundo distante (mar.gd:51-67) | `shadows_disabled` | 7 leituras de ruído; vertex com 5 leituras (`elevacao`); `discard` no distante | não | moderado; 137.500 + 18.432 triângulos |
| `mar/agua_rio.gdshader` | fitas "Rio" (geo_region_renderer.gd:384-397) | `blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx, shadows_disabled` | 2 leituras de normal, Fresnel | não | barato, alfa sobreposta |
| `mar/foz_rio.gdshader` | transição rio-mar | `blend_mix, depth_draw_opaque, cull_back, shadows_disabled` | 2 leituras | não | barato |
| `mar/leito_rio.gdshader` | areia/lama do rio | `cull_disabled` + `ALPHA_SCISSOR` | 1 a 2 leituras aniso + ruído (8 a 12 `sin`) | não | pequeno; descarta no pré-passe |
| `mar/areia_praia.gdshader` | faixa de praia | `cull_back` + `ALPHA_SCISSOR` | 1 leitura aniso + ruído | não | pequeno |
| `fauna/nado.gdshader` | peixes do cardume (MultiMesh, cardume.gd) | `blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley` | até 3 leituras PBR; vertex com `sin` | não | barato |
| `fauna/raia_voo.gdshader` | raias | idem | idem | não | barato |
| `fauna/silhueta_rio.gdshader` | peixe do rio (sombra) | `blend_mix, depth_draw_never, cull_disabled, unshaded` | 1 leitura | não | barato (transparente) |

### REN-16. Carregamento: trabalho síncrono em GDScript no mar e no céu (baixo, carregamento, confiança média)

**Evidência**
- `mar.gd:90-116` (`_abrir_calha_na_batimetria`): laço por célula e por segmento de rio, sem `await`: dois rios, 6.169 células x (36 a 40 segmentos) = ~235 mil avaliações de distância ponto-segmento (conta: 3.787 e 2.381 células, 151.499 e 83.340 avaliações; python em scratchpad/perf/rios.py), mais `Geometry2D.is_point_in_polygon` (137 pontos) e `ground_height_at` por célula dentro do alcance. Roda no meio do `build_region` (geo_region_renderer.gd:1012), num quadro só.
- `ceu_vale.gd:198-209`: `FastNoiseLite.get_seamless_image(384, 384, ..., 5 oitavas)` na thread principal (comentário: "não em thread" de propósito), + `ImageTexture` + mipmaps.
- `mar.gd:262-277`: 3 `NoiseTexture2D` de 512² com 4 oitavas e mapa de normais (geradas em thread).

**Mecanismo** O primeiro bloco é GDScript puro: estimativa de 0,3 a 1 s num quadro (a tela de carregamento "congela"). O segundo: 20 a 80 ms. Nenhum dos dois passa pelo `_pausar()` do orçamento de 80 ms (`ORCAMENTO_QUADRO_US`, world_builder.gd:674-682), porque rodam sem ceder quadro: o orçamento só é conferido entre eles, depois de eles terminarem.

**Impacto** baixo (soma ~0,5 a 1,2 s dos "dezenas de segundos"; o grosso está nos outros escopos).

**Correção** HOJE (opcional): `await` por linha de células em `_abrir_calha_na_batimetria` (transformar em `static func ... -> void` com `await Engine.get_main_loop().process_frame` a cada ~300 células) e usar um `Rect2` de colisão para pular segmentos longe. Ganho de percepção, pouco de tempo total.

**Esforço** 30 min. **Risco** baixo.

**Como medir** `tools/prototipo_3d/medir_carregamento.gd` (cronometra as etapas); procurar o "Moldando o terreno" e a etapa do mar.

## O que está OK

Conferido; ninguém precisa reinvestigar:

- **Sem efeitos de tela:** nenhum SSAO, SSIL, SSR, SDFGI, glow, névoa volumétrica, DOF, auto exposição, ajustes ou CameraAttributes (grep em todo o repositório). Sem GI de nenhum tipo (VoxelGI, LightmapGI) e sem FogVolume.
- **Sem luz posicional com sombra:** todas as OmniLight3D/SpotLight3D têm `shadow_enabled = false` (padrão); os atlas posicionais não são usados.
- **Vegetação sem sombra:** todos os MultiMesh de mata/orla/sub-bosque/paisagismo e as copas distantes têm `cast_shadow = OFF` (geo_region_renderer.gd:2158; tests/lod_vegetacao.gd:105).
- **Céu no melhor caminho:** `REALTIME` + `radiance_size = 256` (caminho rápido de radiância); o cubemap pula estrelas, disco da lua e do sol; nuvens em meia resolução (`use_half_res_pass`); ambiente por COR (não depende da radiância).
- **Água do rio sem leitura de tela:** `agua_rio`, `foz_rio`, `silhueta_rio` são alfa simples. Só o mar lê tela/profundidade (REN-06).
- **Importação de texturas:** VRAM Compressed (S3TC) com mipmaps; texturas do chão 1.024²; 262 GLBs com `generate_lods` e `create_shadow_meshes` ligados.
- **Câmera:** near 0,08 / far 2.800 coerente com a regra de névoa (95% a 2.800 u); a névoa cobre 26% a 280 u, onde a mata corta.
- **Partículas:** quantidades pequenas (fogueira 2 x 88; espuma 56 só dentro d'água; respingo 10; rastro 20). Sem partículas decorativas, conforme a regra do projeto.
- **SubViewports de UI:** boneco da mochila liga só aberto (boneco_da_mochila.gd:225); painel de personagens `UPDATE_ONCE` (painel_personagens.gd:671). O minimapa NÃO está OK (REN-01).
- **MCPRuntime:** em build exportada `set_process(false)` (mcp_runtime.gd:50-51): sem custo no jogo final.
- **Carregamento:** a montagem do vale já corta o V-Sync e cede quadros a cada 80 ms (world_builder.gd:674-682; tela_carregamento.gd:487-506).
- **Dia e noite:** à noite o Sol some (`visible = false`), logo não há sombra direcional: bom teste, não bug.
- **Mare/Dia por quadro:** são CPU de GDScript de ordem de 0,1 ms; não explicam FPS (REN-13).
- **Preferências do autor:** "Sem maré" (modo 0), tela cheia, "Rápida"; nenhum ajuste gráfico anormal gravado.

## Dúvidas para medição A/B

### Antes de tudo (diagnóstico geral)

| ID | O que perguntar | Como |
|---|---|---|
| T0 | O jogo roda no .exe exportado ou no editor (F5)? No editor há depurador, "Remote Scene Tree" e opções como "Visible Collision Shapes" que pesam muito | repetir a medição no `build/windows/MythsValley3D.exe` |
| T0b | O notebook está na tomada, em plano de desempenho, e a NVIDIA é a GPU de saída (Optimus)? Max-Q em bateria corta a GPU a ~1/3 | painel de energia + `nvidia-smi` ou log "Using Device #0: NVIDIA" (já visto) |
| T1 | **O gargalo é pixel ou vértice/CPU?** | `get_viewport().scaling_3d_scale = 0.5`; ou janela 1280x720. Se o FPS mal sobe, não é pixel. É o teste mais informativo |
| T1b | Hora do dia e fase: o tempo de quadro muda de noite e na alvorada? | `Dia.pausado = true; Dia.definir_hora(12.0)` x `22.0` x `5.8` |
| T1c | O 15 FPS vem em degraus exatos (60/30/20/15)? | HUD com V-Sync desligado (REN-05) |

### Matriz de A/B (um item por vez, mesma câmera parada, mesmo horário, 4 tomadas ABBA de 120 quadros como em medir_lod.gd)

Nós e propriedades exatos (o vale é o `current_scene`, "Vale3D"; "Cenario" é o `WorldBuilder`; o nó da região se chama `bom_jesus_dos_pobres`):

| Teste | Desligar/ligar | Nó e propriedade | O que esperar |
|---|---|---|---|
| A1 | Minimapa | `find_children("Minimapa")` -> `_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED` | ganho = custo da 2ª passada (REN-01) |
| A1b | Minimapa a 10 Hz | alternar `UPDATE_ONCE` a cada 0,1 s | ganho parcial |
| A1c | Medir o minimapa em separado | `RenderingServer.viewport_set_measure_render_time(vp, true)` e `viewport_get_measured_render_time_gpu/cpu(vp)` + `viewport_get_render_info(vp, ...)` na raiz e no `SubViewport` | fração exata |
| A2 | Sombra do Sol | `Cenario/Sol.shadow_enabled = false` | limite superior das sombras |
| A2b | 2 cascatas / 100 u | `Sol.directional_shadow_mode = SHADOW_PARALLEL_2_SPLITS; Sol.directional_shadow_max_distance = 100.0` | |
| A2c | Atlas e filtro | `RenderingServer.directional_shadow_atlas_set_size(2048, true)`; `directional_soft_shadow_filter_set_quality(SHADOW_QUALITY_HARD)` | |
| A2d | Terreno sem sombra | `Cenario/bom_jesus_dos_pobres/Terra.cast_shadow = SHADOW_CASTING_SETTING_OFF` | retira 60 mil tri de 4 cascatas |
| A3 | MSAA | `get_viewport().msaa_3d = Viewport.MSAA_DISABLED` | |
| A3b | FXAA | `msaa_3d = DISABLED; screen_space_aa = SCREEN_SPACE_AA_FXAA` | |
| A3c | FSR | `scaling_3d_mode = SCALING_3D_MODE_FSR; scaling_3d_scale = 0.75` | |
| A4 | Pré-passe | `override.cfg` com `rendering/driver/depth_prepass/enable=false` (reinicia o jogo) | sinal incerto |
| A4b | LOD agressivo | `get_viewport().mesh_lod_threshold = 3.0` (raiz e minimapa) | menos tri |
| A5 | Mar | `.../bom_jesus_dos_pobres/Mar.visible = false`; depois "Fundo do mar" e "Fundo do mar distante" | custo água / leito |
| A6 | Céu | `Cenario/WorldEnvironment.environment.background_mode = Environment.BG_COLOR` (+ `fog_aerial_perspective = 0.0`, `reflected_light_source = REFLECTION_SOURCE_DISABLED`) | limite superior do céu |
| A6b | Radiância | `environment.sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL` | |
| A7 | Terreno | `.../Terra.material_override = StandardMaterial3D.new()` (um material simples) | custo do shader de 8 camadas |
| A8 | Névoa | `environment.fog_enabled = false` | custo da névoa/perspectiva aérea |
| A9 | Decals | esconder os filhos de Cenario com nome "Terreiro *" | |
| A10 | Interiores | esconder as luzes dos 4 cômodos junto à igreja | |
| A11 | V-Sync | `DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)` | tempo real |
| A12 | Retratos | pular `_pedir_os_retratos()` e medir o pico dos 60 primeiros segundos | engasgos |
| A13 | Cache frio | mover `%APPDATA%/MythsValleyPrototype3D/shader_cache` e `vulkan`, medir carregamento e primeiros 600 quadros (restaurar depois) | custo de compilação |

Instrumento recomendado para todos: **Visual Profiler do editor** (Debugger > Visual Profiler, com o jogo iniciado pelo editor)
mostra o ms de GPU de cada passada (Render Directional Shadows, Prepass, Opaque, Sky, Copy screen texture,
Transparent, Resolve, Post). Ele separa ruído de FPS. Deixa claro quanto vale cada achado antes de mexer.

### Perguntas que só a medição responde

1. A 0,5x de escala 3D o FPS sobe? (T1) Decide se pixel importa.
2. A câmera ortográfica do minimapa usa mesmo LOD 0 em tudo? (A1c: comparar primitivas do `SubViewport` com as da raiz.) Confirma a premissa de REN-01.
3. O mar com `Mar.visible = false` melhora quanto? O custo da cópia de tela é mesmo ~1 a 2 ms?
4. O pré-passe de profundidade ajuda ou atrapalha na mata? (A4)
5. O céu REALTIME é regerado duas vezes por quadro por causa do segundo viewport (minimapa)? Ver "Sky" no Visual Profiler com o minimapa ligado e desligado.
6. O atlas de reflexos aloca de fato ~134 a 268 MB ao ver a igreja? (VRAM antes e depois)
7. `threshold_pixels` e `mesh_lod_threshold` afetam o MultiMesh por AABB de bloco como esperado, sem "pipocar"?
8. Qual a fração do quadro em CPU (draw submission) versus GPU? Se `TIME_PROCESS` + render CPU do viewport for maior que o GPU, `thread_model = 2` e menos draw calls (escopos de outros) valem mais do que qualquer item daqui.
9. Existe diferença entre rodar a build exportada e o editor? (T0)
10. Em quais câmeras o FPS despenca (praça, orla, Mirante, mata)? O orçamento de cada item muda: a orla maximiza água; a mata maximiza vértice e pré-passe; a praça maximiza luz/sombra.

## Ordem sugerida para HOJE (baixo risco, reversível)

1. REN-01 B ou A (minimapa a 10 Hz ou desligado por padrão): 20 min.
2. REN-02 itens 1 e 2 (2 cascatas, 100 u, atlas 2048): 10 min.
3. REN-03 item 1 (FSR 0,75) como padrão "Média" + preset no AJUSTAR (se houver 1 a 2 h): 5 min a 2 h.
4. REN-10 (adiar retratos): 10 min.
5. REN-11 (45 quadros extras sob a tela de carregamento): 15 min.
6. Teste A4 (pré-passe) e A4b (LOD) para decidir com número.
7. Itens baixos juntos: REN-07 (1 linha do céu), REN-09 (decals com fade), REN-12 (atlas de reflexos), REN-13 (emitir `hora_mudou` menos).

Depois da entrega (estrutural): REN-06 (água sem leitura de tela), REN-02 item 4 (terreno em blocos, sombras só de perto), REN-01 item 3
(minimapa estático ou por camadas), REN-08 (terreno com splat por bloco), REN-14 (mapa grande sem vegetação alta).
