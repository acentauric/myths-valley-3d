# Investigação de desempenho — escopo HUD (laço do jogo, HUD, minimapa, SubViewports, telas e autoloads)

Repositório: `C:\VIRTUALENVS\myths-valley\myths-valley-3D` (branch main, commit eb430e4, árvore limpa). Godot 4.7.2, Forward+.
Somente leitura: nada foi editado, o Godot não foi executado. Todos os caminhos abaixo são relativos à raiz do repositório.
Convenção: "(estimativa)" marca número que eu calculei e não medi; a conta vem junto. Sem essa marca, o número foi contado no código ou nos dados.

## Resumo

1. O maior suspeito do meu escopo é o **minimapa**: ele é um `SubViewport` que enxerga o MESMO `World3D` do vale (`own_world_3d = false`), com câmera ortográfica a 100 u de altura, em `UPDATE_ALWAYS` (`scripts/prototipo_3d/minimapa.gd:96,99`). Ou seja, o vale é culled, sombreado (sol com 4 cascatas) e desenhado uma segunda vez a cada quadro, só para preencher um círculo de 170 x 170 px. O custo não é de pixel (1,4 % da tela), é de cena: culling + sombras + draw calls. Estimativa de partida: 3 a 11 ms por quadro (conta no achado HUD-01). Vem LIGADO por padrão (`minimapa.gd:156`).
2. A medição histórica de "60 FPS" não vale como linha de base: `tools/prototipo_3d/medir_lod.gd` desliga todos os SubViewports (linhas 35-43), roda numa janela de 1024 x 576 (3,5 vezes menos pixels que 1080p), com o jogador parado e a mata só com as espécies leves. As otimizações de LOD podem estar intactas e mesmo assim o quadro estourar por causas que aquela medição nunca viu.
3. O "60 para 15" tem cara de **espiral de física**: a 15 FPS cada quadro roda 4 passos de física (66,7 ms / 16,7 ms), e há uns 80 nós com `_physics_process` em GDScript (23 moradores, 22 bichos, ~25 cadeias de missão, cardume, fauna, jogador). Cada quadro lento gera mais trabalho de física no quadro seguinte. Também: 15 = 60/4, o degrau do V-Sync (padrão ligado) no monitor de 60 Hz; só desligar o V-Sync diz o tempo real do quadro.
4. **Carregamento**: (a) o menu (`abertura.tscn`) tem o próprio `Cenario` com `world_builder.gd`, então o vale inteiro é montado DUAS vezes por sessão (menu e jogo); (b) a barra de carregamento termina em `world.pronto`, mas o `_ready` de `prototype.gd` ainda cria, de forma síncrona, 23 moradores com GLB de ~5 MB cada, fauna, ~25 cadeias de missão, 7 telas de UI e o boneco da mochila, depois que a tela de carregamento já está em 100 % e desaparecendo.
5. Os autoloads e o HUD em si são **migalha**: dos 39 autoloads só `Dia` e `Mare` trabalham todo quadro; o HUD atualiza telemetria a cada 0,35 s; telas fechadas não custam nada; não há véu de tela cheia visível nem shader 2D que leia a tela. Somando tudo, GDScript de HUD, interação e autoloads fica em torno de 1 a 2 ms por quadro (estimativa). Não vale gastar a tarde aí.
6. Fora do meu escopo, mas visto de passagem e registrado porque também roda no minimapa e no mapa: a água (`agua_mar.gdshader`) lê a textura de tela e a de profundidade (passada extra de cópia em resolução cheia), e o céu novo de 05/10 usa `Sky` em modo REALTIME com radiância 256 e 14 parâmetros reescritos por quadro.
7. Correções de HOJE (baixo risco): desacelerar o minimapa (UPDATE_ONCE a cada ~0,2 s) ou desligá-lo por padrão; trocar `filter_linear_mipmap` por `filter_linear` na textura de tela da água; adiar os retratos 3D até a primeira abertura da teia social ou do diário; estrangular a cascata `Dia.hora_mudou` a 10 Hz. Estruturais: textura de mapa assada uma vez; reaproveitar o `Cenario` do menu no jogo; carregar moradores e bichos em segundo plano e fazer a tela de carregamento esperar o `_ready` do vale; simulação em LOD para quem está longe.

## Fatos contados

| fato | valor | fonte |
|---|---|---|
| Autoloads | 39 (linhas 23 a 61 do bloco `[autoload]`) | `project.godot:21-61` |
| Autoloads com `_process` ou `_physics_process` | 7 (Dia, Mare, Relogio, Atualizacao, Dialogo, MCPRuntime, Vida em física). Só Dia e Mare fazem trabalho real por quadro | `scripts/autoload/dia.gd:109`, `mare.gd:34`, `scripts/compartilhado/relogio.gd:67`, `autoload/atualizacao.gd:152`, `prototipo_3d/dialogo_vale.gd:288`, `addons/godot_mcp/runtime/mcp_runtime.gd:60`, `compartilhado/vida.gd:122` |
| Autoloads com Timer | 1, de disparo único (prévia do ambiente) | `autoload/audio.gd:124-128` |
| Autoloads ligados a `node_added` (rodam para CADA nó que entra na árvore) | 2 (Tela e Estilo) | `autoload/tela.gd:66`, `autoload/estilo.gd:25` |
| Conexões em `Dia.hora_mudou` que disparam a cada quadro | 10: Audio, AmbienteVale, ClockIcon, dica do relógio do HUD, Saveiro, world_builder (céu + luzes de época) e 4 cômodos | `audio.gd:294-295`, `ambiente_vale.gd:52`, `clock_icon.gd:9`, `prototype_hud.gd:861`, `saveiro_vale.gd:130-131`, `world_builder.gd:725`, `comodo.gd:137,561-562` |
| Emissão de `hora_mudou` | todo quadro com o relógio andando, sem checar se mudou | `dia.gd:109-113` (`_process` -> `avancar`), `dia.gd:116-120` (`definir_hora` sempre emite) |
| Cômodos interiores (cada um conecta em `hora_mudou`) | 4 (igreja, casa, casa_pedro, casa_zefa) | `prototipo_3d/interiores.gd:61-73` |
| SubViewports persistentes com o vale aberto | 2: minimapa (ALWAYS) e palco do boneco da mochila (DISABLED com a mochila fechada) | `minimapa.gd:94-99`, `boneco_da_mochila.gd:102-108,225` |
| SubViewports transitórios no vale | 8 estúdios de retrato, um de cada vez (Pedro + 7 de `Afinidade.MORADORES`), cada um vive ~3 quadros | `retratos_3d.gd:89-97,117,141-146`, `prototype.gd:1028-1030`, `compartilhado/afinidade.gd:52` |
| SubViewport do painel PERSONAGENS | só no menu (UPDATE_ONCE), não existe no vale | `painel_personagens.gd:666-671`, `abertura.gd:1413` |
| Minimapa: tamanho do viewport | 170 x 170 px (container 176 menos 2 x 3 de borda, `stretch = true`) = 28.900 px = 1,4 % de 1080p | `minimapa.gd:14,21,80-85` |
| Minimapa: câmera | ortográfica, tamanho 55 u (220 m), 100 u acima do jogador, `far` 400, olhando para baixo | `minimapa.gd:23,27,101-106` |
| Minimapa: mundo e ambiente | mesmo World3D; `Environment` duplicado só para desligar a névoa (o `Sky` continua o mesmo objeto) | `minimapa.gd:96,122-126` |
| Minimapa: MSAA, sombras próprias | MSAA do viewport não definido (padrão desligado); sombras vêm do Sol compartilhado | `minimapa.gd:94-100` |
| Minimapa: ligado por padrão | sim (`get_value("interface","minimapa", true)`), relido do disco a cada 1 s | `minimapa.gd:133-135,153-156` |
| Minimapa: desenho por cima | `queue_redraw` todo quadro; no máximo 3 formas (círculo do Pedro, losango do alvo, triângulo do jogador) | `minimapa.gd:149,203-227` |
| Palco do boneco da mochila | 216 x 304 px, MSAA 4x, mundo próprio, 3 luzes direcionais, modelo do jogador duplicado | `boneco_da_mochila.gd:31-35,102-109,129-161` |
| Retrato | 256 x 256 px, MSAA 4x, mundo próprio, 3 luzes direcionais, `get_image()` (leitura da GPU) por foto | `retratos_3d.gd:37,89-97,136-145` |
| Atraso dos retratos | 1,5 s após o `_ready` do vale | `prototype.gd:1024-1030` |
| CanvasLayers na árvore do vale | cerca de 39: 16 de telas (4 autoloads + HUD, almanaque, menu, controles, painel, teia social, teia de talentos, conquista, luz dourada, narração, queda, tubarão, pergunta) + 23 balões de fala (um por morador); só o HUD está visível | `prototipo_3d/npc.gd:278`, grep de `extends CanvasLayer` |
| Nós de Control do HUD | cerca de 300, dos quais ~130 visíveis (estimativa por contagem dos construtores) | `prototype_hud.gd:126-336`, `botao_canto.gd:29-80` |
| Veus/filtros de tela cheia visíveis durante o jogo | 0. Conquista, luz dourada, narração, queda, tubarão e amanhecer nascem com `visible = false` | `conquista_da_missao.gd:39`, `luz_dourada.gd:33`, `narracao_do_vale.gd:61`, `queda.gd:80`, `tubarao.gd:490`, `ui/amanhecer.gd:53` |
| Shader 2D que lê a tela (`hint_screen_texture`, BackBufferCopy) | 0. O único shader que lê a tela é 3D (água) | grep em `*.gdshader`, `*.gd`, `*.tscn` |
| Telemetria do HUD | a cada 0,35 s: FPS, 3 monitores de `Performance`, 2 textos | `prototype_hud.gd:535-539,759-774` |
| Moradores + guia | 22 + 1 = 23, cada um com Label3D, CanvasLayer, AudioStreamPlayer3D e AuthoredAnimator | `data/npcs_3d.json` (23 ids), `npc.gd:270-295` |
| Cadeias de missão | 19 pontos de criação em `prototype.gd`, mais laços da fé e frentes do 2D: cerca de 25 nós com `_physics_process` (estimativa) | `prototype.gd:2176-2194`, `cadeia_de_missoes.gd:970` |
| Alvos de trabalho (Recursos3D) | 49 | `data/recursos_3d.json` |
| Física | padrão do Godot: 60 passos/s, no máximo 8 por quadro (sem override). A 15 FPS = floor(66,7 / 16,7) = 4 passos por quadro | `project.godot` (nenhuma chave `physics/common`) |
| V-Sync | padrão (ligado); a tela de carregamento o desliga durante a montagem e o restaura | `tela_carregamento.gd:485-488,506` |
| MSAA 3D da janela | 2x (`msaa_3d=1`); estiramento `canvas_items`, base 1280 x 720, 3D em 1920 x 1080 | `project.godot:65-70,97` |
| Sol | sombra ligada, 4 cascatas, distância máxima 180 u | `ceu_vale.gd:89-93` |
| Céu | `Sky` em REALTIME, radiância 256, 14 parâmetros do material reescritos todo quadro. Introduzido em 05/10 (commit 80eb70b); antes era `ProceduralSkyMaterial` | `ceu_vale.gd:71-75,137-151`, `git show 80eb70b -- world_builder.gd` |
| Água do mar | lê `hint_screen_texture` (com `filter_linear_mipmap`) e `hint_depth_texture` | `assets/prototipo_3d/mar/agua_mar.gdshader:14-15,75` |
| Condições do "60 FPS" histórico | janela 1024 x 576, V-Sync desligado, SubViewports desligados, jogador e `_process` do vale parados | `tools/prototipo_3d/medir_lod.gd:17-19,32-43` |
| Razão de pixels 1080p / janela do medidor | 2.073.600 / 589.824 = 3,52 | conta |
| Autosave periódico | nenhum. `Partida.salvar()` só no Sair, no fechar a janela, ao dormir, na troca de estilo e no menu | `prototype.gd:295,410,476,1619,1965,2019`, `queda.gd:169` |
| Build exportada | `export_filter="all_resources"`; MCPRuntime só abre o socket com a feature "editor" (patch local) | `export_presets.cfg:7`, `mcp_runtime.gd:49-52` |
| Fluxo de cenas | menu (`abertura.tscn`) tem `Cenario` com `world_builder.gd`; o jogo (`vale.tscn`) também | `scenes/prototipo_3d/abertura.tscn:10-11`, `scenes/prototipo_3d/vale.tscn:12-13`, `abertura.gd:190-195,1853` |

### Orçamento por quadro (resumo, tudo estimativa)

| item | custo por quadro | observação |
|---|---|---|
| Minimapa (2º render do mundo) | 3 a 11 ms | HUD-01. Candidato nº 1 do meu escopo |
| Amplificador de física | multiplica por até 4 o custo dos `_physics_process` a 15 FPS | HUD-02 |
| Cascata `Dia.hora_mudou` | 0,3 a 0,6 ms de CPU (GDScript + chamadas ao servidor de render) | HUD-06 |
| Laços de HUD e de interação (10 scripts com dica de tecla, placas, seta, Recursos3D, Mare) | 0,5 a 1 ms | HUD-10 |
| HUD 2D (canvas) | 0,2 a 0,5 ms | ~130 nós visíveis, ~0,35 Mpx com alpha |
| Retratos | 0 depois dos primeiros segundos | HUD-09 |

### Tabela de SubViewports (pergunta 1)

| viewport | tamanho | mundo | modo de atualização | câmera | MSAA | continua com o painel fechado? |
|---|---|---|---|---|---|---|
| Minimapa (`minimapa.gd`) | 170 x 170 | MESMO World3D do vale (desenha o vale de novo, com as sombras do Sol) | ALWAYS enquanto `visible`; DISABLED quando escondido ou com outra câmera ativa (`minimapa.gd:139-146`) | ortográfica, 55 u, 100 u de altura | desligado | SIM, é o comportamento normal. Com a árvore pausada (menu, mochila, painel, almanaque) o `_process` não roda e o modo fica em ALWAYS, então segue renderizando |
| Palco do boneco (`boneco_da_mochila.gd`) | 216 x 304 | próprio (3 luzes, ambiente simples) | DISABLED, ALWAYS só com a mochila aberta (`:225`) | perspectiva própria | 4x | Não. Fechado, não renderiza (portão `tests/boneco_da_mochila.gd:91-94`). Mas o modelo e o AnimationPlayer continuam vivos (HUD-11) |
| Estúdios de retrato (`retratos_3d.gd`) | 256 x 256, um por vez | próprio | ALWAYS durante ~3 quadros, depois `queue_free` | própria | 4x | Não persistem. 8 fotos, 1,5 s após o início |
| Prévia 3D do PERSONAGENS | PREVIA | próprio | ONCE | própria | desligado | Só existe no menu |
| Mapa grande (`mapa_jogo.gd`) | não é viewport | troca a câmera da janela principal por uma ortográfica a 3000 u | n/a | `mapa_jogo.gd:24-26,50` | 2x da janela | Só quando aberto (HUD-08) |

### Tabela de autoloads (pergunta 6)

| autoload | tem laço por quadro? | o que faz por quadro | custo estimado |
|---|---|---|---|
| Audio | não (1 Timer de disparo único, tweens só em troca de faixa) | escuta `Dia.hora_mudou`: calcula o período e chama `ResourceLoader.exists` no caminho da trilha, todo quadro (`audio.gd:294-304,279-283`). Carga de áudio sob demanda com cache (`:671-680`) | 5 a 50 µs (estimativa; o `exists` é um stat em disco no editor e uma busca no PCK na build) |
| Estilo | não | `node_added`: um teste de tipo por nó adicionado | ~1 a 2 µs por nó |
| Versao | não | nada | 0 |
| Tela | não | `node_added` (`_texto_novo`: um teste e, no fator 1,0, nada mais); `_input` só para F11 | ~1 a 2 µs por nó adicionado |
| Atualizacao | `_process` com retorno imediato se não está baixando | nada no vale; a rede só sai quando a abertura chama `verificar()` | ~0,3 µs |
| Progressao, Energia, Inventario, Equipamento | não | só sinais, disparados por evento | 0 |
| Relogio | `_process` com retorno imediato | o `Dia` mantém `pausado = true` aqui (`dia.gd:150`), então não faz nada | 0 |
| Efeitos, Jogo, Talentos, Ritos, Fe, Afinidade, Missoes, Jornada, Venda, Pesca, Luta, Obras, Cozinha, Oficina, Receitas, Cartas, Colecao | não | nada por quadro | 0 |
| Vida | `_physics_process` | dois decrementos e `_correr_a_peconha` | ~2 µs por passo de física |
| Salvamento | não | gravação síncrona só por evento (HUD-13) | 0 por quadro |
| Mochila | não (CanvasLayer escondida, ~40 painéis montados no `_ready`) | `_atualizar` retorna se fechada (`ui/mochila.gd:738-740`) | 0 |
| Dialogo | `_process` com retorno imediato se inativo | nada | ~0,3 µs |
| Folheto, Amanhecer | não (escondidos) | nada | 0 |
| Lugares | não | nada | 0 |
| CadernoDoVale | não | emite `mudou` só quando algo mudou (`caderno_do_vale.gd:156-162`) | 0 |
| **Dia** | **sim, todo quadro** | `avancar` -> `definir_hora` -> emite `hora_mudou` para 10 ouvintes (HUD-06) | 0,3 a 0,6 ms (estimativa) |
| **Mare** | **sim, todo quadro** | `get_nodes_in_group("mare_superficie")` (~4 nós), grava `position.y` neles, grava 2 parâmetros em ~5 materiais, mesmo no modo 0 (sem maré) em que nada mudou (`mare.gd:34-54`) | 10 a 30 µs (estimativa) |
| Partida | não | nada | 0 |
| MCPRuntime | desligado fora do editor (`set_process(false)`) | na build exportada: nada. Rodando pelo binário do editor: `poll()` do socket todo quadro e nova tentativa de conexão a cada 2 s | exportada 0; editor poucos µs |

## Achados

### HUD-01 — O minimapa desenha o vale uma segunda vez por quadro, sempre ligado

**Evidência**
- `scripts/prototipo_3d/minimapa.gd:94-100`: `_viewport = SubViewport.new()`, `own_world_3d = false` ("o SubViewport enxerga o mesmo World3D do vale"), `render_target_update_mode = UPDATE_ALWAYS`.
- `minimapa.gd:101-106`: `Camera3D` ortográfica, `size = 55`, `far = 400`, olhando para baixo; `minimapa.gd:198-200`: posicionada 100 u acima do jogador (`ALTURA_CAMERA`, linha 27).
- `minimapa.gd:122-126`: `Environment` duplicado só para `fog_enabled = false`. O `Sky` dentro dele é o mesmo recurso (cópia rasa).
- `minimapa.gd:130-149`: `_process` liga e desliga o viewport por `visible`; `visible = _mostrar and not _suspenso and camera_do_jogo and not controles_abertos`. `_mostrar` vem de `ConfigFile` com padrão `true` (`:153-156`).
- `scripts/prototipo_3d/prototype.gd:1195-1198`: criado no fim de `_montar_moradores`, dentro do `hud_layer`.
- `tools/prototipo_3d/medir_lod.gd:35-43`: o medidor de LOD DESLIGA todo SubViewport antes de medir ("subviewports_desligados"), o que mostra que o autor já sabia que ele pesa.
- O minimapa existe desde 28/09 (`git log --follow minimapa.gd`), antes do commit de LOD de 30/09.

**Mecanismo (Godot 4, Forward+)**
Um SubViewport sem mundo próprio renderiza a MESMA cena que a janela principal, com outra câmera. Cada renderização de viewport refaz: culling de instâncias e de MultiMesh contra o frustum da câmera; as cascatas da sombra direcional (o Sol tem 4 splits, `ceu_vale.gd:93`; a sombra direcional é recalculada por câmera); o pré-passe de profundidade e o passe opaco; o passe transparente; e o fundo de céu. O custo depende do CONTEÚDO que cabe no frustum (draw calls, triângulos, casters de sombra), e não dos 28.900 pixels.
O frustum do minimapa (55 x 55 u, 400 u de profundidade) pega justamente a região mais densa: casas, moradores, bichos e adereços, que não têm `visibility_range` (as faixas de LOD só existem na vegetação: `geo_region_renderer.gd:191-197,2160-2162`). A 100 u de altura, só o sub-bosque (corte a 85 u) sai da vista; o resto da mata e todo o povoado entram.

**Impacto: alto (estimativa).** Conta de partida: o minimapa cobre 55 x 55 = 3.025 u². A câmera principal vê, dentro dos alcances de LOD de 85 a 280 u, algo entre um setor de 90 graus de raio 120 u (11.300 u²) e um de 60 graus de raio 280 u (41.000 u²). Logo o minimapa cobre 7 % a 27 % da área vista, e a área dele é a de maior densidade. Se a geometria custa uns 40 ms do quadro de 66 ms, o minimapa fica em 3 a 11 ms, mais o custo fixo de montar mais uma passada (culling e sombras). Só a medição fecha este número.
Confiança: alta de que o segundo render existe e está sempre ligado; média de que o custo é dessa ordem.

**Correção proposta**
- HOJE A (recomendada, baixo risco): em `minimapa.gd:144`, trocar o `UPDATE_ALWAYS` contínuo por atualização pontual: `UPDATE_ONCE` a cada 0,15 a 0,25 s e só se o jogador andou mais de ~1,5 u desde a última foto. O `SubViewport` guarda o último quadro, o triângulo do jogador e o losango do alvo continuam desenhados por cima a cada quadro (`_sobre.queue_redraw`). Ganho de 75 % a 90 % do custo do minimapa. Esforço: 20 a 30 min. Risco: o fundo do mapa passa a andar em degraus (2 a 3 px a 15 FPS); o portão `tests/minimapa.gd:82-86` só exige `SubViewportContainer` com `ShaderMaterial`, o círculo e a conta do losango, e nenhum teste menciona `render_target_update_mode` do minimapa.
- HOJE B: padrão desligado, mudando o `true` de `minimapa.gd:156` para `false` (decisão de produto: o jogador liga em AJUSTAR). Esforço: 2 min. Risco: o `tests/minimapa.gd` abre o HUD com o minimapa e precisa dele visível; teria que gravar a preferência no teste.
- ESTRUTURAL: assar o mapa uma vez. O `mapa_jogo.gd` já sabe montar a câmera ortográfica sobre o quadro 16:9; renderizar esse quadro num viewport `UPDATE_ONCE` (por exemplo 2048 x 1152) ao fim da montagem e mostrar um recorte dele, deslocado pela posição do jogador, no lugar da câmera ao vivo. Custo por quadro: zero. Perde mudanças dinâmicas do mundo (árvore derrubada) e a hora do dia no mapa. Esforço: 3 a 6 h com o portão.
- ESTRUTURAL alternativo: dar ao terreno, à água e às estradas uma camada visual própria e limitar `_camera.cull_mask` a ela. Corta sombras de casters e draw calls de adereços, mas exige marcar as camadas em todo construtor do `world_builder.gd`.

**Esforço**: 20 a 30 min (A); 2 min (B); 3 a 6 h (estrutural).
**Risco**: baixo para A e B; médio para o estrutural.

**Como medir**
1. Pelo painel de FPS do próprio HUD (tri e draws): ligar e desligar o minimapa em AJUSTAR (preferência `[interface] minimapa` em `user://preferencias_visuais.cfg`). `RENDER_TOTAL_PRIMITIVES_IN_FRAME` e `RENDER_TOTAL_DRAW_CALLS_IN_FRAME` somam todos os viewports do quadro, então a diferença é a parcela do minimapa. Parado no mesmo ponto, com o relógio parado.
2. No editor: Depurador > Visual Profiler mostra CPU e GPU por viewport.
3. Por script, no nó `/root/Vale3D/HUD/PrototypeHUD/Minimapa`: `RenderingServer.viewport_set_measure_render_time(vp.get_viewport_rid(), true)` e ler `RenderingServer.viewport_get_measured_render_time_cpu(rid)` e `..._gpu(rid)` do minimapa e da janela principal (`get_tree().root.get_viewport_rid()`).
4. Critério: se o minimapa responde por mais de 3 ms, vale a correção A hoje.

---

### HUD-02 — Física a 60 Hz com até 8 passos por quadro transforma um quadro lento em quadro mais lento

**Evidência**
- `project.godot`: nenhuma chave de `physics/common/*` (padrão do Godot: 60 passos/s, máximo de 8 passos por quadro).
- Nós com `_physics_process` em GDScript no vale: `npc.gd:371` (23 moradores), `bicho_de_casa.gd:175` (22 corpos de quatro patas), `cadeia_de_missoes.gd:970` (~25 cadeias), `cardume.gd:251`, `fauna_vale.gd:593`, `criatura_vale.gd:419`, `guia_pedro.gd:202`, `tubarao.gd:98`, `luta_vale.gd:633`, `canoas.gd:87`, `espuma_agua.gd:69`, `player_controller.gd:459`, `compartilhado/vida.gd:122`. Perto de 80 nós a cada passo.
- Os ciclos de física das cadeias rodam `_tentar_encontro`, `_acertar_o_caderno`, `falta_a_meta` e `resumo_do_passo` (formata texto) a cada passo para as que estão em andamento (`cadeia_de_missoes.gd:301-314,805-876`). Isto está no meu escopo (laço, missões).

**Mecanismo**
O laço principal do Godot acumula o tempo real e roda `floor(acumulado / 16,67 ms)` passos de física antes de cada quadro, até o teto. A 60 FPS é 1 passo; a 30 FPS, 2; a 15 FPS (66,7 ms), 4. Cada passo executa o servidor de física e TODOS os `_physics_process`. Se o passo custa P ms e o desenho custa R ms, o quadro é R + n x P com n = floor((R + n x P) / 16,67): um ponto fixo que sobe aos saltos. Exemplo, só para ilustrar (P e R são invenção minha): R = 20 e P = 8 dão 28 ms (n = 1), depois 36 (n = 2), 44 (n = 3), 52 (n = 4 estável) ou seja 19 FPS. Esse é o formato do penhasco que o autor descreve.
O número 15 é também o 4º degrau do V-Sync (60/4): com V-Sync ligado e quadro entre 50 e 66 ms, o motor mostra 15.

**Impacto: alto como amplificador (estimativa), nulo como causa original.** Não sei R nem P. Confiança: média (mecanismo conhecido; magnitude só com medição).

**Correção proposta**
- HOJE (opção, a testar em A/B antes de decidir): `physics/common/max_physics_steps_per_frame` de 8 para 2 ou 3. Abaixo de 20 a 30 FPS a simulação passa a andar em câmera lenta em vez de fazer a espiral. Risco: o jogo abaixo desse FPS fica lento (movimento, relógio da simulação); portões que contam quadros de física (`await physics_frame`) devem ser rodados de novo. Não recomendo baixar `physics_ticks_per_second` hoje: exigiria interpolação de física para a câmera e para o personagem, risco alto.
- ESTRUTURAL: reduzir P. Simulação em LOD (moradores e bichos a mais de ~60 u do jogador andam a 10 Hz com acumulador, ou ficam em `process_mode = DISABLED` enquanto invisíveis); tirar do `_physics_process` o que é só visual (cardume, espuma); fazer a cadeia de missão só reavaliar o caderno quando o inventário mudar (sinal `Inventario.mudou`) e não a 60 Hz.

**Esforço**: 5 min (A/B do teto); dias para o LOD de simulação.
**Risco**: médio (teto) a alto (LOD de simulação).

**Como medir**
1. Registrar por quadro `Engine.get_physics_frames()` (a diferença entre quadros dá os passos) e `Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)` contra `TIME_PROCESS` (ambos em segundos).
2. Fixar `Engine.max_physics_steps_per_frame = 1` em execução. Se o FPS sobe muito, a física é fatia grande do quadro.
3. Desligar o V-Sync (linha de comando `--disable-vsync` ou `DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)`) para ver o tempo real do quadro: se der 20 a 25 FPS e não 15, parte do 15 era o degrau do V-Sync.

---

### HUD-03 — A barra de carregamento acaba em `pronto`, mas o `_ready` do vale ainda cria dezenas de coisas depois

**Evidência**
- `scripts/prototipo_3d/tela_carregamento.gd:498-512`: o laço de progresso sai quando `mundo.construido` fica verdadeiro; em seguida a tela some em 0,35 s e a camada é liberada.
- `world_builder.gd:659-670`: `_concluir` marca `construido`, emite `pronto`.
- `prototype.gd:229-234`: o `_ready` do vale espera `world.pronto` e só aí começa o resto:
  - `Interiores.new()` + `await interiores.configurar` (4 cômodos, cada um espera 2 quadros de física, `:242-247`, `interiores.gd:87-96`);
  - `NavegacaoVale.configurar` (bake em outra thread, `:251-254`);
  - `BonecoDaMochila.montar` (carrega de novo o GLB do jogador, `:348-349`, `boneco_da_mochila.gd:184-199`);
  - `TeiaTalentos`, `Retratos3D`, `TeiaSocial`, `MenuPausa`, `TelaControles` (UI de telas inteiras, `:385-533`);
  - `_montar_moradores` (`:571`, `:1080-1199`): 22 moradores + Pedro, cada um com `load()` síncrono do GLB do personagem (~5,7 MB de fonte, 24 GLBs de personagem somam 117 MB), AuthoredAnimator, Label3D, CanvasLayer, voz; `Tubarao`, `FaunaVale`, `BichosDeCasa` (31 GLBs de animais somam 77 MB), `Queda`, `CasaDoJogador`, `LavouraVale`, `PescaVale`, `LutaVale`, `AchadosVale`, `PainelVale` (53 KB de UI), `Pegadas`, `Minimapa`;
  - ~25 `CadeiaDeMissoes` com leitura de JSON (`:580-659`, `:2176-2194`);
  - `Salvamento.registrar_mundo`, `_retomar_a_partida`, `achados.espalhar()` (`:744-760`).
- `catalogo_assets.gd:372-383`: `CatalogoAssets.cena` faz `load(path)` síncrono, na thread principal, na primeira vez de cada peça.

**Mecanismo**
Tudo depois do primeiro `await` real de `interiores.configurar` roda no mesmo quadro, na thread principal, sem ceder tempo. Enquanto isso a tela de carregamento já está em 100 % e o tween de fade (0,35 s) não anda: o jogador vê a barra cheia congelada, ou o vale já visível com o quadro travado. O `load()` de cada GLB lê o `.scn` importado, suas texturas comprimidas (ctex) e sobe tudo para a GPU. A primeira vez que cada material desenha, o Godot também compila pipelines (primeiro quadro visível).

**Impacto: alto para "carregamento lento" (percepção) e para a travada logo ao entrar.** Magnitude: não medida; estimo de 1 a 5 s (estimativa por contagem de ~120 a 200 MB de GLBs de personagem e bicho mais 7 telas de UI). Confiança: média (estrutura certa; tempo desconhecido).

**Correção proposta**
- HOJE (o mínimo): medir. `tools/prototipo_3d/medir_carregamento.gd` já registra a etapa "(depois do pronto)" e o maior congelamento (cabeçalho do arquivo, linhas 1-60); rodar com janela (sem `--headless`), `--cena=abertura,vale`. Alternativa de linha: `Time.get_ticks_usec()` em volta de `prototype.gd:348`, `:485-503`, `:571`, `:1174`.
- HOJE (barato, 1 h): fazer a tela de carregamento esperar o fim do `_ready` do vale. Um sinal `vale_pronto` emitido em `prototype.gd:767`, antes do `print("PROTOTYPE_READY...")`, e uma espera nele em `tela_carregamento.gd` depois do laço da linha 498. A barra passa a ser honesta (e o congelamento acontece atrás dela, com o V-Sync ainda desligado, o que o torna mais rápido). Risco: baixo a médio; portões que esperam `construido` ou a linha `PROTOTYPE_READY` não mudam.
- ESTRUTURAL: carregar em segundo plano com `ResourceLoader.load_threaded_request` os GLBs de moradores e bichos durante a montagem do mundo (já existe `--precarregar=1` no medidor, que lê os GLBs do catálogo em threads), instanciar os moradores em lotes de 2 a 4 por quadro, e construir as 7 telas sob demanda (na primeira vez que abrem).

**Esforço**: 1 h (sinal); 1 dia (pré-carga em segundo plano e lotes).
**Risco**: médio (ordem de inicialização do `_ready` é frágil, há dependências entre `Interiores`, `Navegacao`, moradores e save).

**Como medir**: rodar `medir_carregamento.gd --cena=abertura,vale` com janela e olhar `etapas` depois de `Pronto`; ou os `Time.get_ticks_usec()` acima. Critério: se a soma passar de 1 s, a espera do sinal e a pré-carga valem.

---

### HUD-04 — O vale inteiro é montado duas vezes por sessão (menu e jogo)

**Evidência**
- `scenes/prototipo_3d/abertura.tscn:10-11`: o menu tem um nó `Cenario` com `world_builder.gd`; `scenes/prototipo_3d/vale.tscn:12-13` tem outro, com o mesmo script.
- `scripts/prototipo_3d/abertura.gd:190-195`: o menu espera o `$Cenario.construido` do próprio mundo e só então inicia o sobrevoo.
- `abertura.gd:1838-1853` (`_start_game`): `TelaCarregamento.trocar_cena(get_tree(), GAME_SCENE, loading)`; `tela_carregamento.gd:453-479` carrega `vale.tscn` e faz `change_scene_to_packed`, o que libera a árvore do menu e monta tudo de novo.

**Mecanismo**: a montagem do mundo (terreno, ruas, mata, vila, paisagismo, luzes) acontece uma vez para o menu e outra para o jogo. Além do tempo duplicado, a troca de cena libera os milhares de nós do mundo do menu num só quadro (um soluço), e os recursos que não ficam no cache são lidos de novo.

**Impacto: alto para "carregamentos lentos demais"** se o custo do menu e o do jogo forem parecidos (não medi). Confiança: alta de que a montagem é duplicada; média de que pesa metade do tempo total.

**Correção proposta**
- HOJE: nenhuma segura. Medir os dois (`medir_carregamento.gd --cena=abertura,vale`) e decidir.
- ESTRUTURAL: reaproveitar o `Cenario` já montado do menu no jogo (mantê-lo como nó de um autoload ou reparentá-lo ao `Vale3D` no `_enter_tree`), já que o estilo, a hora e a composição são as mesmas. A troca de estilo continua reconstruindo.
- ESTRUTURAL alternativo: o menu usar uma versão barata do cenário (terreno, mar e céu, sem vila nem mata), com o sobrevoo mais curto. Perde o apelo do sobrevoo; decisão de arte.

**Esforço**: 0,5 a 1 dia (reaproveitar), com mexida nos portões de montagem. **Risco**: médio a alto (o `Cenario` do menu foi alterado pelo sobrevoo e por câmeras do menu; o `vale.gd` assume que `construido` pode ser falso).

**Como medir**: `tools/prototipo_3d/medir_carregamento.gd -- --cena=abertura,vale`; somar `total_ms` das duas.

---

### HUD-05 — A linha de base "60 FPS" não foi medida nas condições de hoje

**Evidência**
- `docs/projeto/CHANGELOG_3D.md:1309,1319`: "mantendo 60 FPS" e "mata só com as espécies leves ... 60 FPS".
- `tools/prototipo_3d/medir_lod.gd:17-19`: `DisplayServer.window_set_size(Vector2i(1024, 576))` e `VSYNC_DISABLED`.
- `tools/prototipo_3d/medir_lod.gd:30-43`: `player.set_physics_process(false)`, `game.set_process(false)`, `dia.set("pausado", true)` e todo `SubViewport` com `UPDATE_DISABLED`.
- Depois dessa medição entraram: céu novo e névoa aérea (80eb70b, 05/10), 22 moradores com rig e 22 bichos (ce20572 e 80eb70b), paisagismo e quintais plantados, retratos 3D (03/10), boneco da mochila.

**Mecanismo**: a medição histórica rodou com 1/3,5 dos pixels, sem o segundo render do minimapa, sem física de jogador, moradores com o laço de `_process` do vale parado e só a vegetação. O resultado é válido para o LOD de vegetação, e não diz nada sobre o vale completo em 1080p com MSAA 2x.

**Impacto: médio como orientação de decisão (evita procurar a regressão no lugar errado).** Confiança: alta.

**Correção proposta**: nenhuma de código. Refazer a linha de base nas condições de jogo (1920 x 1080, tela cheia, MSAA 2x, minimapa ligado e desligado, V-Sync desligado, jogador na praça e na mata). O medidor `medir_lod.gd` já faz o A/B do LOD; basta uma variante com o HUD, o minimapa e a janela cheia.

**Esforço**: 1 h. **Risco**: nenhum.

**Como medir**: ver "Dúvidas para medição A/B".

---

### HUD-06 — `Dia` emite `hora_mudou` todo quadro para 10 ouvintes; o céu reescreve 14 parâmetros por quadro

**Evidência**
- `scripts/autoload/dia.gd:109-113` (`_process`), `:154-160` (`avancar`), `:116-120` (`definir_hora` sempre emite, sem testar mudança).
- Ouvintes (todos executam a cada quadro): `audio.gd:294-304` (`_ao_mudar_hora` calcula o período e chama `ResourceLoader.exists`); `ambiente_vale.gd:123-137` (`_aplicar` regrava volumes); `clock_icon.gd:12-13` e `prototype_hud.gd:777-791` (relógio do canto, `queue_redraw` e texto); `saveiro_vale.gd:161-162,180-214`; `world_builder.gd:725-732` -> `ceu_vale.gd:105-160` e `luzes_epoca.gd:167-172`; `comodo.gd:553-562` (4 cômodos: regravam `albedo_color` e a energia de cada SpotLight3D).
- `ceu_vale.gd:105-160` (`aplicar`): 15 `lerp` de cor, `Basis.looking_at` do sol e da lua, 14 `set_shader_parameter` no material do céu e 7 propriedades do `Environment`.
- `luzes_epoca.gd:167-172`: `aplicar_hora` chama `_atualizar(0.0)`, que percorre todas as chamas mesmo de dia, em que `_acesas` é falso.
- `ceu_vale.gd:71-75`: `Sky.process_mode = REALTIME`, `radiance_size = 256` (introduzido hoje, 80eb70b).

**Mecanismo**: cada emissão chama ~10 funções GDScript e ~40 a 60 chamadas ao servidor de render por quadro. Cada `set_shader_parameter` marca o material para atualização do buffer uniforme no quadro seguinte. O `Sky` em REALTIME refaz o cubemap de radiância (6 faces de 256 x 256) todo quadro, o que seria necessário só porque as nuvens usam `TIME`. O sol muda de direção e a sombra direcional é redesenhada todo quadro de qualquer modo, então isso não é custo extra.

**Impacto: baixo (CPU 0,3 a 0,6 ms, estimativa por contagem de chamadas; GPU do cubemap 0,1 a 0,3 ms, estimativa).** Confiança: média. O dono do céu (outro escopo) deve medir o `Sky` REALTIME.

**Correção proposta**
- HOJE (30 a 60 min, baixo a médio risco):
  - `dia.gd:109-113`: acumular o tempo no `_process` e emitir `hora_mudou` a 10 Hz (cada 0,1 s). O sol anda 1 hora em 30 s no "Normal"; a 10 Hz o ângulo muda 0,03 graus por emissão, invisível. Manter `definir_hora` imediato para o menu, os testes e a tecla de adiantar.
  - `comodo.gd:553`: guardar a última `luz_do_dia` e sair se mudou menos de 0,002.
  - `audio.gd:299-304`: comparar com o último período antes de `ResourceLoader.exists`.
  - `luzes_epoca.gd:167`: sair cedo quando `alvo <= 0.02` e já está tudo apagado.
- ESTRUTURAL: `Sky.process_mode = INCREMENTAL` ou `radiance_size = 128` (no escopo do céu); trocar o conjunto de ouvintes por `periodo_mudou` onde só o período importa (áudio, saveiro).

**Esforço**: 30 a 60 min. **Risco**: médio-baixo. Conferir `tests/ceu_horizonte.gd`, `tests/calendario.gd` e `tests/salvamento.gd`, que chamam `Dia.definir_hora` e leem o céu logo depois (por isso `definir_hora` continua imediato).

**Como medir**: A/B com `Dia.pausado = true` (para o relógio e toda a cascata; as nuvens do shader seguem com `TIME`) e comparar o tempo de CPU do quadro (`Performance.TIME_PROCESS`).

---

### HUD-07 — A água lê a textura de tela e a de profundidade em resolução cheia (também no minimapa e no mapa)

Fora do meu escopo; registrado porque a mesma passada ocorre nos três viewports que enxergam o mar.

**Evidência**: `assets/prototipo_3d/mar/agua_mar.gdshader:14` `uniform sampler2D tela : hint_screen_texture, filter_linear_mipmap, repeat_disable;`; `:15` `profundidade : hint_depth_texture`; `:75` `textureLod(tela, uv, 0.0)` (só o nível 0 é lido). `scripts/prototipo_3d/mar.gd:78-80` registra os materiais.

**Mecanismo**: qualquer material 3D que leia `SCREEN_TEXTURE` força o Forward+ a copiar o buffer de cor da cena para uma textura à parte antes do passe transparente (com resolução do MSAA 2x), e a de profundidade, a copiar o buffer de profundidade. O sufixo `_mipmap` no sampler declara que a textura de tela será lida com mipmaps; o motor então gera a cadeia de mips (borrões gaussianos) em resolução cheia (o último ponto eu não verifiquei no código do motor). Em 1080p, a cópia e a cadeia custam algo como 1 a 3 ms em placa de classe GTX 1660 Ti (estimativa).

**Impacto: médio (estimativa); confiança baixa a média.**

**Correção proposta**: HOJE, em `agua_mar.gdshader:14` trocar `filter_linear_mipmap` por `filter_linear`. Esforço: 2 min. Risco: nenhum visual (só o nível 0 é lido), e o mesmo vale para `agua_rio.gdshader`/`foz_rio.gdshader` se lerem a tela (conferi que não: só `agua_mar` tem a dica). ESTRUTURAL: se a refração e a absorção por profundidade puderem ser trocadas por uma textura pré-assada ou por cor fixa em baixa-mar, eliminar a leitura de tela.

**Esforço**: 2 min. **Risco**: nenhum.
**Como medir**: A/B no HUD (tempo de quadro) com e sem o `_mipmap`; ou trocar temporariamente o material do plano do mar por um `StandardMaterial3D` simples no nó `Cenario/Mar` (nome conferir) e comparar.

---

### HUD-08 — O mapa grande (tecla M) tira o corte de LOD de toda a vegetação do mundo

**Evidência**: `geo_region_renderer.gd:2437-2453` (`_atualizar_lod_da_camera`): se a câmera ativa da janela é ortográfica, `visibility_range_end = 0.0` em todos os blocos de vegetação e esconde as copas distantes. `mapa_jogo.gd:9,24-26,50` (câmera ortográfica a 3000 u, `far` 4000); `prototype.gd:1441-1462` (o vale não pausa: "o mundo continua").

**Mecanismo**: com alcance infinito, todo MultiMesh de vegetação do mundo deixa de ser descartado por distância; ficam só o frustum (que agora cobre o quadro 16:9 inteiro) e o LOD automático da malha por tamanho na tela (a 3000 u cai para o menor nível). O CHANGELOG antigo cita ~10,5 M de triângulos para a mata inteira com malhas pesadas.

**Impacto: médio, só com o mapa aberto; confiança baixa** (não sei quantos blocos nem quantos triângulos sobram com o LOD de malha).

**Correção proposta**: HOJE, A/B apenas. Se o mapa ficar abaixo de 20 FPS, ESTRUTURAL: o mapa usa as copas distantes (modelos `_longe`, `copas_distantes.gd`) e esconde os blocos de perto, ou mostra uma textura assada (a mesma de HUD-01 estrutural). Reaproveitar a textura de mapa evita as duas pontas.

**Esforço**: 3 a 6 h (junto com a textura assada). **Risco**: médio (o autor quer "as árvores de verdade" no mapa, comentário em `geo_region_renderer.gd:2437-2439,2451`).
**Como medir**: FPS com M aberto e fechado, no mesmo ponto, V-Sync desligado; o painel de FPS mostra tri e draws.

---

### HUD-09 — Oito estúdios de retrato 3D (MSAA 4x, leitura da GPU) logo depois da entrada

**Evidência**: `prototype.gd:1024-1030` (1,5 s depois do `_ready`, pede Pedro + 7 moradores); `retratos_3d.gd:89-97,117,136-146` (um `SubViewport` de 256 x 256, MSAA 4x, mundo próprio, 3 luzes direcionais; instancia o GLB do morador; aguarda 3 `frame_post_draw`; `get_image()`; `generate_mipmaps()`).

**Mecanismo**: cada retrato monta um mundo novo, instancia um personagem com esqueleto, desenha ~3 quadros em MSAA 4x (variante de framebuffer diferente da janela principal, que usa MSAA 2x, então os pipelines dos materiais do personagem compilam de novo na primeira foto) e depois faz uma leitura da GPU para a CPU (`get_image`), que espera a GPU terminar. 8 fotos x 3 quadros = 24 quadros de trabalho extra espalhados nos primeiros segundos de jogo (0,4 s a 60 FPS, 1,6 s a 15 FPS).

**Impacto: baixo a médio como soluço (estimativa); confiança média-baixa.** Ocorre no mesmo instante em que o jogador começa a mexer.

**Correção proposta**
- HOJE (10 min, baixo risco): não chamar `_pedir_os_retratos()` no fim do `_ready` (`prototype.gd:768`); chamá-lo na primeira abertura da teia social ou do diário. Como as duas telas já mostram o desenho 2D até a foto chegar (`teia_social.gd:674-676`, `painel_vale.gd:889-893`, `tests/teia_social.gd:188-199`), nada quebra. A primeira abertura terá ~0,3 s de espera com o 2D de reserva.
- ESTRUTURAL: assar os retratos fora do jogo (PNG de 256 x 256 por morador, gerado por ferramenta) e carregá-los como textura comum.

**Esforço**: 10 min (adiar). **Risco**: baixo (`tests/teia_social.gd:191-199` e `tests/saveiro.gd:100-106` só exigem o objeto de estúdio e a ligação com a teia).
**Como medir**: tempo de quadro nos primeiros 6 s de jogo com e sem a chamada (remover o nó `/root/Vale3D/Retratos3D` antes de 1,5 s para o A/B); `RenderingServer.viewport_set_measure_render_time` nos estúdios.

---

### HUD-10 — Custos de GDScript por quadro no laço, no HUD e nas dicas de interação: migalha

**Evidência e conta (estimativa por contagem de operações)**

| fonte | o que roda | custo |
|---|---|---|
| `prototype.gd:1211-1246` | passos, laço sobre `world.landmarks` (distância), `hud.set_clock` (formata texto todo quadro), a cada 0,5 s `_acertar_a_porta_da_casa`, `_conferir_as_metas`, `_conferir_o_socorro` | 20 a 40 µs |
| `prototype_hud.gd:535-539` | telemetria a cada 0,35 s (FPS, 3 monitores, 2 textos, 2 atualizações de ícone); nada por quadro | ~0 |
| `minimapa.gd:130-149` | 2 leituras de propriedade, `queue_redraw`, desenho de 3 formas | 10 a 20 µs |
| `placas_nomes.gd:30-46` | até 23 moradores: distância, `is_position_behind`, `unproject_position`, `reset_size` das placas visíveis (<22 u) | 50 a 120 µs |
| 8 scripts de dica de tecla (`recursos_3d.gd:169`, `arvores_info.gd:136`, `tecla_dos_moradores.gd:53`, `tecla_das_bancadas.gd:59`, `lapides.gd:62`, `achados_vale.gd:274`, `marcos_da_fe.gd:133`, `lavoura_vale.gd:241`, `casa_do_jogador.gd:70`) | cada um acha a câmera, calcula o "mais perto" (quadras espaciais em árvores; 49 alvos em Recursos3D) | 5 a 20 µs cada, ~100 µs |
| `seta_missao.gd:87-139` | seta e chevron, `queue_redraw` do chevron | 10 a 20 µs |
| `autoload/mare.gd:34-54` | grupo, 4 `position.y`, ~5 materiais x 2 parâmetros, todo quadro, mesmo no modo 0 | 10 a 30 µs |
| `comodo.gd:495-499` x 4 | tremor das velas (energia da luz) | ~10 µs |
| `cadeia_de_missoes.gd:970-981` x ~25, por passo de física | a maioria sai antes (esperando abrir); as abertas leem caderno e inventário | 50 a 150 µs por passo |
| Cascata de `Dia` | ver HUD-06 | 300 a 600 µs |

Total: cerca de 0,8 a 1,5 ms por quadro mais 0,05 a 0,15 ms por passo de física. Em 66,7 ms, é 1 % a 2 %.

HUD em si: ~130 nós visíveis, ~0,35 Mpx com alpha (cálculo: título ~540 x 195 px físicos, aviso, relógio, 3 barras, barra de mão, coluna de 10 botões, minimapa ~264 px, placas), 3 a 4 lotes de canvas. GPU estimada: 0,2 a 0,5 ms. Corte de HUD não muda o resultado.

**Impacto: baixo. Confiança: alta (de que é migalha).** Itens que valeria ajeitar só se sobrar tempo, todos de 1 a 5 linhas: `mare.gd:34` retornar cedo quando `mudou` é falso e a base já foi aplicada (hoje reescreve posição e parâmetros mesmo parado); `cadeia_de_missoes.gd` só reavaliar o caderno quando o inventário muda; `placas_nomes.gd` só fazer `reset_size` quando o texto muda.

**Esforço**: 30 min no conjunto. **Risco**: baixo. **Como medir**: A/B desligando por `set_process(false)` os nós `PlacasNomes`, `ArvoresInfo`, `Recursos3D` e o autoload `Mare`; o ganho esperado é menor que 1 ms.

---

### HUD-11 — Resíduos que gastam sem aparecer

**Evidência**
- `boneco_da_mochila.gd:184-199` e `authored_animator.gd:60-64`: o boneco carrega uma SEGUNDA instância do modelo do jogador e toca "idle" em `AnimationPlayer`; o `AnimationPlayer` anima o esqueleto todo quadro, mesmo com a mochila fechada e o palco em `UPDATE_DISABLED` (`:218-228`).
- `placas_nomes.gd:26-29`: os 23 `Label3D` de nome dos moradores ficam com `modulate.a = 0` e `outline_modulate.a = 0`, não escondidos. Continuam no passe transparente (2 superfícies por rótulo).
- `minimapa.gd:130-146`: com a árvore pausada (menu, mochila, painel J, almanaque, fala longa) o `_process` não roda e o viewport fica em `UPDATE_ALWAYS`: o vale é desenhado duas vezes por trás das telas.
- `addons/godot_mcp/runtime/mcp_runtime.gd:49-84`: quando o jogo roda por um binário do Godot com a feature "editor" (o editor, ou `Godot --path` com o executável do editor), o `_process` faz `poll()` do WebSocket todo quadro e `_attempt_connect` cria um `WebSocketPeer` novo a cada 2 s se não há servidor. Na build exportada, `set_process(false)`.
- `prototipo_3d/npc.gd:278-282`: 23 `CanvasLayer` de balão, todos escondidos (custo ~0).

**Mecanismo**: trabalho sem retorno visual: esqueleto animado sem ser visto, 46 superfícies transparentes invisíveis, segundo render atrás de menu, poll de socket.

**Impacto: baixo (cada item < 0,3 ms, estimativa); confiança média.** A exceção é a medição: se o autor mede rodando pelo executável do editor, o motor tem as verificações extras de uma build de edição (GDScript em modo depuração, perfilador acoplado), e os números não valem para a build exportada.

**Correção proposta (todas de 1 a 5 linhas)**: `boneco_da_mochila.gd:225` também desligar `process_mode` do modelo (ou `animation_player.active = false`) enquanto fechado; `placas_nomes.gd:28` trocar o alfa por `nome_label.visible = false`; `minimapa.gd` pôr o viewport em `DISABLED` quando `get_tree().paused`; para medir, usar a build exportada ou o executável de template.
**Esforço**: 20 min no conjunto. **Risco**: baixo (`tests/boneco_da_mochila.gd:91-94` espera `ALWAYS` aberta e `DISABLED` fechada; `tests/ferramentas.gd` e `tests/almanaque.gd` usam o minimapa).
**Como medir**: `Performance.TIME_PROCESS` com `boneco_da_mochila.set_process(false)` e `AnimationPlayer.active=false`; comparar o executável exportado com o do editor, mesma cena.

---

### HUD-12 — Dois ouvintes de `node_added` rodam para cada nó criado na montagem

**Evidência**: `autoload/tela.gd:66,151-154` (`_texto_novo`: testa a escala do texto e o tipo do nó) e `autoload/estilo.gd:25,33-35` (`_cursor_de_clique`: testa `BaseButton` e `Slider`). O sinal `node_added` é emitido para todo nó que entra na árvore, inclusive os milhares de nós dos GLB instanciados durante o carregamento.

**Mecanismo**: duas chamadas de GDScript por nó (cerca de 1 a 2 µs cada, mais a transição C++ -> script). Número de nós: não contado. Com 20 a 40 mil nós (estimativa: cenário, vila, moradores, bichos, UI), seriam 40 a 160 ms somados, dentro de dezenas de segundos de carregamento.

**Impacto: baixo (menos de 1 % do carregamento, estimativa); confiança média.**

**Correção proposta**: HOJE: nenhuma necessária. ESTRUTURAL: um único ouvinte de `node_added`, ou desconectar os dois durante o `world_builder` e reaplicar cursor e escala de texto depois, num passe só sobre a árvore.
**Esforço**: 30 min. **Risco**: baixo. **Como medir**: contar `get_tree().get_node_count()` no fim da montagem e cronometrar a montagem com os dois ouvintes desconectados (`disconnect` no console remoto).

---

### HUD-13 — Candidatos a travada dentro do meu escopo (todos pequenos)

| candidato | quando | custo estimado | evidência |
|---|---|---|---|
| Carga síncrona da trilha do período (1,5 MB de mp3, `load()` sem cache na primeira vez) | primeira troca para manhã, tarde e noite (a cada ~2 a 3 min de jogo em "Normal", só na primeira vez de cada) | 2 a 5 ms | `audio.gd:279-283,299-304,671-680` |
| Carga de efeitos e passos na primeira vez de cada terreno (`_carregar` com cache) | primeira vez de cada som | 0,2 a 1 ms | `audio.gd:427-465` |
| `load()` do mp3 do bem-te-vi e dos sussurros da mata (110 KB), sem cache, a cada 18 a 50 s | a cada canto | 0,2 ms | `ambiente_vale.gd:195-211` |
| Voz da fala do morador (`load` do mp3 na hora de falar) | ao conversar | 1 a 3 ms | `npc.gd:701,770-772` |
| Gravação do save (var_to_str, escrita, releitura, troca de arquivo) | ao dormir, sair, trocar estilo, fechar a janela (nunca periódico) | 5 a 30 ms (estimativa) | `compartilhado/salvamento.gd:312-388`, `queda.gd:169` |
| Primeira abertura do mapa grande (laço sobre todos os blocos de vegetação) | ao apertar M | 5 a 20 ms (estimativa) | `geo_region_renderer.gd:2448-2453` |
| Primeira abertura da mochila (compilação de pipelines do palco em MSAA 4x) | 1ª vez | dezenas a centenas de ms (estimativa) | `boneco_da_mochila.gd:102-109` |
| Retratos | 1,5 s depois de entrar | ver HUD-09 | `prototype.gd:1024-1030` |
| `Interiores` e criação em lote pós-`pronto` | ao entrar | ver HUD-03 | `prototype.gd:229-768` |

Não há autosave periódico, troca de período que recompute rotina de morador dentro do meu escopo, ou instanciação de balão ou retrato por evento além dos itens acima. Os ciclos periódicos de outros escopos (por exemplo `geo_region_renderer.gd:2426-2434`, a cada 0,25 s; navegação dos moradores) ficam com quem investiga esses sistemas.

## O que está OK

- Telas fechadas não custam por quadro: Mochila, Folheto, Amanhecer, Dialogo, Almanaque, TeiaSocial, TeiaTalentos, PainelVale, MenuPausa, TelaControles nascem com `visible = false`; os handlers de sinal que reconstroem UI saem se a tela está fechada (`painel_vale.gd:647-649`, `ui/mochila.gd:738-740`, `teia_social.gd:107`, `teia_talentos.gd:127-128`). Só `Dialogo._process` roda e sai na 1ª linha.
- HUD: a telemetria é a cada 0,35 s (`prototype_hud.gd:535-539`); nenhuma chamada a `Performance.get_monitor` ou `get_rendering_info` por quadro; o botão de FPS não faz nada extra.
- Veus e filtros: nenhum véu de tela cheia fica visível durante o jogo (conquista, luz dourada, narração, queda, tubarão, amanhecer escondidos). "Luz de pintura", vinheta e véus gradientes são da abertura e da tela de carregamento (`abertura.gd:401-420`, `tela_carregamento.gd:141-172`), não do vale. A tela de carregamento é estática (1 imagem, 2 véus, poucos tweens) e desliga o V-Sync na montagem (`:485-488`).
- Nenhum shader 2D lê a tela; nenhum `BackBufferCopy` no jogo.
- Autosave periódico: não existe. `Atualizacao` só consulta a rede quando a abertura chama `verificar()`; no vale não há socket nem polling.
- MCPRuntime: na build exportada e em modo headless não abre socket nem roda por quadro (`mcp_runtime.gd:49-52`).
- Áudio: decodificação de mp3 e mistura rodam na thread de áudio; efeitos e passos usam um único tocador cada e um cache (`audio.gd:671-680`); os 22 `AudioStreamPlayer3D` de voz só trabalham quando tocam.
- BonecoDaMochila: o palco só renderiza com a mochila aberta e sem baú (`boneco_da_mochila.gd:222-228`, portão `tests/boneco_da_mochila.gd:91-94,163`).
- Minimapa: já se recolhe com o mapa grande, com CONTROLES aberto e com a preferência desligada (`minimapa.gd:139-146`). O mapa grande troca a câmera da janela em vez de criar outro viewport.
- Recursos3D tem 49 alvos; ArvoresInfo usa quadras espaciais ("a mata tem milhares", `arvores_info.gd:255-291`); AchadosVale, Lapides e demais dicas só comparam com poucos pontos.
- Relogio (calendário) fica pausado pelo `Dia` e não faz nada; `Atualizacao` e `Dialogo` saem na primeira linha do `_process`.
- Painel PERSONAGENS (UPDATE_ONCE) só existe no menu.
- Os retratos 3D são 8 (não 23) e só uma vez por vale.

## Dúvidas para medição A/B

Tudo em execução na máquina do autor (i7-9750H, GTX 1660 Ti Max-Q, 1920 x 1080 tela cheia, MSAA 2x), com o jogador parado no mesmo ponto da praça e depois na mata, relógio parado (`Dia.pausado = true`) a não ser quando indicado.

1. **Qual placa está desenhando?** Em notebook com Intel UHD 630 + NVIDIA (Optimus), um jogo que sobe na Intel dá exatamente 15 FPS em cenas assim. Conferir no console de saída do Godot a linha do dispositivo Vulkan ("Vulkan ... Using Device ..."), e o Gerenciador de Tarefas > GPU. Conferir também o plano de energia e o estado de bateria (Max-Q cai muito fora da tomada).
2. **Executável do editor ou build exportada?** Medir os dois no mesmo ponto. O binário do editor liga o MCPRuntime (HUD-11) e tem a build de edição do motor.
3. **15 é o degrau do V-Sync?** Rodar com `--disable-vsync` (ou `DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)`) e ler o tempo de quadro real. Se for 20 a 25 FPS, o 15 era parte quantização.
4. **O gargalo é pixel, vértice ou CPU?** `get_viewport().scaling_3d_scale = 0.5`: se o FPS quase dobra, é pixel (MSAA, água, sombras de tela); se quase não muda, é CPU ou vértice. Em seguida `get_viewport().msaa_3d = Viewport.MSAA_DISABLED`.
5. **Minimapa (HUD-01):** gravar `[interface] minimapa=false` em `user://preferencias_visuais.cfg` (ou AJUSTAR > Cenário), esperar 1 s, anotar FPS e o tri/draws do painel; depois ligar. Pelo nó `/root/Vale3D/HUD/PrototypeHUD/Minimapa`, medir com `RenderingServer.viewport_set_measure_render_time` e `viewport_get_measured_render_time_cpu/gpu` o viewport do minimapa e a janela principal.
6. **Física (HUD-02):** registrar `Engine.get_physics_frames()` por quadro e `Performance.TIME_PHYSICS_PROCESS` contra `TIME_PROCESS`; A/B com `Engine.max_physics_steps_per_frame = 1`.
7. **Cascata de `Dia` e `Mare` (HUD-06, HUD-10):** `Dia.pausado = true`; `Mare.set_process(false)`. O ganho esperado é menor que 1 ms.
8. **Água (HUD-07):** trocar `filter_linear_mipmap` por `filter_linear` em `agua_mar.gdshader:14` e comparar; ou esconder o plano do mar (nó do `mar.gd` no `Cenario`) por 5 s e comparar. Se o ganho passar de 1 ms, vale a correção.
9. **Céu REALTIME (HUD-06):** no `Environment` do `Cenario/WorldEnvironment`, `sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL` e depois `radiance_size = RADIANCE_SIZE_128`. Dúvida adicional que só a medição fecha: o minimapa e o mapa, que compartilham o mesmo `Sky` com `Environment` duplicado, refazem o cubemap de radiância outra vez?
10. **Mapa grande (HUD-08):** FPS com M aberto e fechado, mesmo ponto.
11. **Depois do `pronto` (HUD-03):** `tools/prototipo_3d/medir_carregamento.gd -- --cena=abertura,vale` com janela (sem `--headless`), lendo a soma do primeiro `pronto` e da etapa "(depois do pronto)" na segunda; ou `Time.get_ticks_usec()` ao redor de `prototype.gd:348`, `:485-503`, `:571`, `:1174`.
12. **Montagem duplicada (HUD-04):** a mesma execução do item 11, somando `total_ms` da abertura e do vale.
13. **Retratos (HUD-09):** tempo de quadro nos primeiros 6 s com e sem o nó `/root/Vale3D/Retratos3D` (liberado antes de 1,5 s).
14. **HUD inteiro:** `/root/Vale3D/HUD.visible = false` com o minimapa desligado pela preferência (o `visible` do CanvasLayer não desliga o SubViewport do minimapa, que só olha a própria propriedade `visible`). Ganho esperado: 0,2 a 0,5 ms.
15. **Pergunta aberta sobre o `Tela`/`Estilo`:** número real de nós no fim da montagem (`get_tree().get_node_count()`), para trocar a estimativa de 20 a 40 mil por um valor medido.
