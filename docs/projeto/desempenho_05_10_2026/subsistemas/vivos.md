# Desempenho dos vivos: moradores, bichos, peixes, animação e scripts por quadro (escopo VIV)

Projeto: `myths-valley-3D`, commit `eb430e4`, Godot 4.7.2 Forward+. Investigação feita só lendo código e assets: o Godot não foi aberto e nada foi alterado no repositório. Scripts auxiliares de contagem (Python, só biblioteca padrão) ficaram em `scratchpad/perf/` (`glb_vivos.py`, `mapa_vivos.py`, `grade_costa.py`).

Convenção: caminhos relativos à raiz do projeto. Quando um número é **estimativa**, isso vem escrito, junto com a conta. "Tick" é um passo de física (60 por segundo, que é o padrão: o `project.godot` não tem seção `[physics]`). "Quadro" é um quadro desenhado.

---

## Resumo

1. **O achado mais grave é um bug de cache que entrou em 04/10 (commit `8413ae7`).** A grade de distância até a costa (`geo_region_renderer.gd:2645`) guarda **uma margem só**. Desde 04/10 ela é consultada com margens diferentes (7, 20, 4 e 6 u), e **cada troca de margem refaz a grade inteira da costa**: 2.013 inserções em dicionário GDScript na margem 20 e 624 na margem 7. Toda consulta de água num ponto do **rio central**, o que passa entre a Praça, a Igreja e o Píer, troca a margem duas vezes. O resultado são 2 reconstruções por consulta, ~1–2 ms cada par (estimativa). Quem paga: o jogador na ponte ou no rio (≥3 consultas por tick), os cardumes de rio (piabas, acarás, traíra), os moradores postos no "Rio 2" e na "Ponte do rio central" (pescador, marisqueira, lavadeira, mestre do saveiro) e os bichos que atravessam o riacho. O mesmo bug refaz a grade **por vértice** ao montar as faixas de rio, foz e praia, então provavelmente também pesa no **carregamento**. A correção custa uma função (~10 linhas), tem risco muito baixo e devolve o mesmo resultado.
2. **A física dos vivos roda a 60 Hz e entra em espiral.** São 49 CharacterBody3D (jogador, 23 moradores, 22 bichos, 3 criaturas). Os moradores fazem `move_and_slide` com ímã de chão (`floor_snap_length = 0,35`) até 90 u do jogador. O próprio autor mediu 0,2 a 1,5 ms por corpo e por tick contra a malha do terreno (comentários em `bicho_de_casa.gd:120-122` e `:412-415`), e só os bichos receberam o remédio (sem ímã, `max_slides = 2`). Quando o FPS cai, o Godot roda até 8 ticks por quadro (padrão de `max_physics_steps_per_frame`). A 15 FPS são 4 ticks por quadro: todo custo de `_physics_process` é multiplicado por 4.
3. **Há uma travada longa logo depois que a tela de carregamento some.** Num único quadro, `_montar_moradores` (`prototype.gd:571`) cria 23 moradores, o tubarão, a fauna, os bichos e a luta. Nesse quadro carregam **de forma síncrona** cerca de 55 GLBs que o carregamento em segundo plano não pegou (todos os personagens, bichos e peixes), os bandos de aves chamam `world.arvores()` (que aloca ~6.300 dicionários por chamada) dezenas de vezes, e cada morador mede a própria passada com 98 `seek()`.
4. **Os peixes estão bem resolvidos no desenho** (MultiMesh, nado no shader, sem sombra, alcance de visão), mas o rumo de cada peixe é calculado em GDScript a cada tick, até ~370 peixes em ~53 cardumes. A malha de cada peixe tem 2.000–2.500 triângulos, o que é demais para um peixe de cardume.
5. **As otimizações antigas continuam no código e funcionam para quem já as tinha**: LOD da vegetação, economia de longe do morador (90 u), gerente de distância dos bichos (80 u, física até 26 u), sono dos cardumes. Os sistemas que chegaram em 04–05/10 (bichos, bandos, cardumes, jornada dos moradores, rio com foz) são todos posteriores às medições de "60 FPS" do CHANGELOG.
6. **As 3 coisas que mais pesam na CPU por quadro, em ordem**: (1) a grade da costa refeita em toda consulta no rio central; (2) a física dos moradores (e das criaturas, que nunca dormem) multiplicada pela espiral de ticks; (3) os cardumes e os AnimationPlayer dos 23 moradores, que tocam mesmo fora da câmera.

---

## Fatos contados

| Fato | Valor | Fonte |
|---|---|---|
| Moradores (MoradorNPC) instanciados | 22 + Pedro (GuiaPedro herda MoradorNPC) = 23 | `data/npcs_3d.json` (22 em `moradores` + `guia`); `prototype.gd:1087-1099` |
| Moradores com agenda (jornada), todos mudos e todos se recolhem | 14 (padre, sacristão, beata, mercador, guarda, pescador, marisqueira, lavadeira, rendeira, quituteira, carpinteiro, menino, menina, mestre_saveiro) | `data/npcs_3d.json` (contagem por script) |
| Moradores postos no rio central ("Rio 2" / "Ponte do rio central") de manhã | 4: pescador, marisqueira, lavadeira, mestre_saveiro (este também à tarde e ao entardecer) | `data/npcs_3d.json`, campos `agenda` e `postos` |
| Estrutura de um morador | CharacterBody3D + CollisionShape3D (cápsula r 0,26) + GPUParticles3D (EspumaAgua, 56 partículas) + Visual > GLB (Skeleton3D + 1 MeshInstance3D com skin + AnimationPlayer) + Node do animador autoral + Label3D (nome, billboard, contorno) + CanvasLayer > BalaoFala (PanelContainer, VBox, 2 Label, ponta) + AudioStreamPlayer3D + peças na mão/cabeça (BoneAttachment3D + GLB) | `npc.gd:238-305`, `npc.gd:313-343`, `espuma_agua.gd:17-66` |
| GLB dos moradores | 10.302 a 15.119 triângulos, 1 malha, 1 material, 65 ossos (Filó 66), 7 a 13 clipes, 3 texturas 1024² cada | `assets/prototipo_3d/personagens/*_tripo.glb` (lido com `glb_vivos.py`) |
| Soma de triângulos dos 23 moradores (LOD0) | ≈ 285.800 | soma dos GLBs acima |
| Ossos animados somados | moradores 1.496 + jogador 65 + quadrúpedes 605 + criaturas 108 + tubarão 11 ≈ **2.285** | contagem de `skins.joints` nos GLBs × instâncias |
| Bichos de quatro patas | 22: cachorro_caramelo 3, cachorro_malhado 3, filhote 1, gato 8 (malhado 4, preto 2, amarelo 2), porco 2, leitão 1, cabra 2, bode 1, jumento 1 | `data/bichos_de_casa.json` (16 casas) |
| Estrutura de um quadrúpede | CharacterBody3D (layer 0, mask 1, cápsula) + Pose > GLB (Skeleton3D 19–42 ossos + 1 malha com skin + AnimationPlayer com 1 clipe `preset:quadruped:walk`) + Node Animador; o cão tem um 2º GLB "deitado" (sem esqueleto), criado na 1ª vez que deita | `bicho_de_casa.gd:115-145`, `:482-493`, `animador_bicho.gd:96-128` |
| GLB dos quadrúpedes | 5.240 a 5.833 tri, 19 a 42 ossos, 3 texturas 1K; soma dos 22 ≈ 126 mil tri | `assets/prototipo_3d/animais/*` |
| Bandos de aves | 10 bandos, **49 aves**: galinha 25, pintinho 7, galinha-d'angola 5, pato 4, galo 3, pavoa 3, peru 1, pavão 1 | `data/bichos_de_casa.json` |
| Estrutura de uma ave | Node3D > Pose > GLB estático (1 malha, sem esqueleto) + Node Animador (balanço procedural na Pose); **sem física**, sem MultiMesh | `bando_de_chao.gd:224-254` |
| GLB das aves | 3.509 a 4.040 tri cada (pintinho de 11 cm: 3.653 tri); soma das 49 ≈ 186 mil tri | `assets/prototipo_3d/animais/*` |
| Criaturas da mata | 3: caititu, onça-pintada, onça-preta (CharacterBody3D layer 0/mask 1, GLB com skin, AnimationPlayer) | `luta_vale.gd:136-149`, `criatura_vale.gd:229-270` |
| Canoas | 7 AnimatableBody3D com ConcavePolygonShape3D da própria malha (3.673–3.864 tri), movidas a cada tick | `canoas.gd:8`, `:87-107`, `:148-169` |
| Tubarão | 1, GLB `mar/tubarao_tripo.glb` com 12.131 tri e 11 ossos, sem clipe; cauda por 2 `set_bone_pose_rotation` por tick; sem sombra; alcance de 160 u | `tubarao.gd:347-381`, `:432-439` |
| Cardumes (estimativa pelas regras de montagem) | ~53 cardumes, até ~370 peixes: canoas 7×(tainha 8–10 + sardinha 16–24), xaréus 2×2, pedras até 4×(8+2+1)+garoupa 1, rios até 6×(8+3+1), mar de fora 2×(6–8), raia-pintada 2×(5–7), raias de areia 4–6, cardume do píer 14 | `fauna_vale.gd:142-156`, `:220-228`, `:326-358`, `:365-420`, `:456-469`, `:507-554`; `cardume.gd:34` |
| Malha por peixe | 2.026 a 2.492 tri (tubarão-peixe 5.383), 3 texturas 1K | `assets/prototipo_3d/peixes/*` |
| CharacterBody3D com `move_and_slide` | 49 no total (1 + 23 + 22 + 3) | contagem acima |
| Funções `_physics_process` do escopo (rodam 60×/s) | npc.gd (23), guia_pedro.gd (1, por cima do morador), bicho_de_casa.gd (22), criatura_vale.gd (3), espuma_agua.gd (24 = 23 moradores + jogador), cardume.gd (cada um, sai na 1ª linha se `coordenado`), fauna_vale.gd (1), tubarao.gd (1), canoas.gd (1 laço com 7), cadeia_de_missoes.gd (1 por cadeia pendurada, ~15–25), player_controller.gd (1), luta_vale.gd (1, sai cedo) | grep `func _physics_process` |
| Funções `_process` do escopo (1 vez por quadro) | authored_animator.gd (24), animador_bicho.gd (22 + 49 + 3 = 74), balao_fala.gd (23), bando_de_chao.gd (10), bichos_de_casa.gd (1), prototype.gd (1), player_controller.gd (1), pegadas.gd (1, laço de 64), seta_missao.gd, tecla_dos_moradores.gd, tecla_das_bancadas.gd, placas_nomes.gd (laço de 23), pesca_vale.gd, saveiro_vale.gd (a cada 60 quadros), luta_vale.gd | grep `func _process` |
| Teto de ticks por quadro | 8 (padrão do Godot; não alterado) | `project.godot` sem `[physics]` |
| Pontos da costa / do polígono de terra / amostras de altitude | 149 / 137 / 12 | `data/mapas/bom_jesus_dos_pobres_cenario.json`, `bom_jesus_dos_pobres.json` |
| Reconstrução da grade da costa (célula 16 u) | margem 20 u: 203 células, **2.013 inserções**; margem 7 u: 109 células, 624; margem 4 u: 87 células, 423 | `grade_costa.py` sobre `coastline_m` ÷ 4 m/u |
| Rio central (não é o "rio do norte") | caixa x[-53, 78] z[-118, -22] u, 36 pontos; Praça em (0, 0), Igreja (80, -69), Píer (88, -2) | `data/mapas/bom_jesus_dos_pobres.json`; `geo_region_renderer.gd:1339-1348` |
| Troncos de árvore no vale | `tree_count` 6.234 (mais mangues, ingazeiros e restinga) | `data/mapas/bom_jesus_dos_pobres_cenario.json:2723` |
| Import dos GLB dos vivos | `meshes/generate_lods=true`, `create_shadow_meshes=true`, `light_baking=1` (estático), `animation/fps=30`, `remove_immutable_tracks=true` | `*.glb.import` |

---

## Achados

### VIV-01: A grade da costa é refeita em toda consulta de água no rio central (cache de margem única)

**Evidência.**
- `scripts/prototipo_3d/geo_region_renderer.gd:2645-2657`: `_distancia_costa(point, margem)` guarda uma grade só e a refaz inteira quando `_grade_costa_margem != margem`:
  ```gdscript
  if _grade_costa_n != _coast.size() or _grade_costa_margem != margem:
      _grade_costa = {}
      for i in range(_coast.size() - 1):
          ... for cx ... for cy ...: _grade_costa[celula].append(i)
  ```
- Os chamadores usam margens diferentes (com 4 m por unidade, `_units` em `:234`):
  - `_terrain_height_at` → margem `_units(80,18)` = **20 u** (`:500-503`), chamada por **toda** `ground_height_at` dentro da caixa da costa, ou seja, no vale inteiro;
  - `_coastal_ribbon_height` → margem `_units(28,7)` = **7 u** (`:1458-1461`), chamada por `river_water_level_at` quando o ponto está num rio que não é o "do norte" (`:556-560`);
  - `_river_shore_weight` → **4 u** (`:541-544`) e a rampa da foz → **6 u** (`:1561-1562`), na montagem das faixas.
- `river_water_level_at` (`:552-561`) chama primeiro `_coastal_ribbon_height` (margem 7 → refaz) e depois `_terrain_height_at` (margem 20 → refaz). **São 2 reconstruções a cada chamada** com o ponto dentro do rio central. `world.water_level_at` e `world.water_depth_at` passam ambos por ela (`world_builder.gd:401-421`).
- O rio central é o que não é "do norte" (`:1339-1348`): o centro dele está em z ≈ -70, o do outro rio em z ≈ -282. Ele corta o miolo da vila (caixa x[-53, 78] z[-118, -22]).
- Histórico: a grade nasceu com uma margem só em `f44f61c` (02/10, "O vale monta em cinco segundos"). As chamadas com margens 4, 6 e 7 entraram em `8413ae7` (04/10, "Integra melhorias da foz e do vale 3D"). O "monta em 5 s" de 02/10 é anterior ao bug.

**Quem consulta pontos no rio central, e com que frequência:**
| Quem | Chamadas por tick | Reconstruções por tick |
|---|---|---|
| Jogador na ponte ou no rio | `_profundidade` → `water_level_at` (`player_controller.gd:786`), `_atualizar_nado` → `water_depth_at` (`:794`), espuma → `water_level_at` (`espuma_agua.gd:73`), e mais `chao_dos_pes` a cada passo (`:860-866`) | ≥ 6 |
| Morador parado no rio (lavar, mariscar, pescar) | `_atualizar_nado` (`npc.gd:464`) + espuma (`espuma_agua.gd:73`) | 4 |
| Morador andando com a sonda caindo no rio | + `_por_terra` → até 9 `water_depth_at` (`npc.gd:512-529`) | até 22 |
| Cardume de rio (piaba, acará, traíra) | `_lamina_em(centro)` a cada atualização (`cardume.gd:277`, `:563-567`) + por peixe a cada ~0,5 s `water_level_at` + `water_depth_at` (`cardume.gd:293-295`, `:575-587`) | 2 por atualização + 4 por consulta de peixe |
| Bicho atravessando o riacho | `_na_agua` → `water_depth_at` + `water_level_at` (`bicho_de_casa.gd:450-451`); em `_andar_livre`, até 3× (`:432-434`) | 4 a 12 |

**Mecanismo.** É CPU de GDScript na thread principal, dentro do `_physics_process`, e portanto também multiplicada pela espiral de ticks (VIV-03). Uma reconstrução da margem 20 percorre ~2.000 iterações com construção de `Vector2i`, `has()`, criação de `Array` e `append()`.

**Impacto (estimativa).** Com ~0,3–0,6 µs por iteração de GDScript num i7-9750H, uma reconstrução custa ~0,6–1,2 ms (margem 20) e ~0,2–0,4 ms (margem 7), ou **~1–1,5 ms por consulta** no rio. Cenários:
- jogador atravessando a ponte central: 3 consultas por tick dão ~3–5 ms por tick, ou **12–20 ms por quadro a 15 FPS** (4 ticks);
- câmera a menos de 32 u de um poço do rio central (o FaunaVale atualiza esses cardumes todo tick: alcance 50 u × 0,65, `fauna_vale.gd:620`; `cardume.gd:165`, `alcance: 50` em `fauna_vale.gd:411`): 3 cardumes × 1 consulta + ~0,4 consulta de peixe por tick dão ~4–6 ms por tick;
- de manhã, até 4 moradores postos no rio central: 4 reconstruções por tick cada **se** a posição deles cair dentro da meia-largura do rio (não dá para saber sem rodar; ver Dúvidas).

**No carregamento:** `geo_region_renderer.gd:1532-1566` monta as faixas de rio e de foz e chama, **por vértice**, `_river_shore_weight` (margem 4) e depois `_terrain_height_at` (margem 20), o que dá 2 reconstruções por vértice. As faixas de praia e rua com `coastal_height` chamam `_coastal_ribbon_height` (7) e depois `_terrain_height_at`/`ground_height_at` (20) (`:1547-1565`). Com alguns milhares de vértices nessas faixas, isso soma **segundos** na montagem (estimativa; o número exato sai do `medir_carregamento.gd`). Esta parte é do escopo de terreno e vai registrada aqui porque a causa é a mesma.

**Correção proposta (HOJE).** Em `geo_region_renderer.gd:2645-2657`, guardar **uma grade por margem**: `var _grades_costa := {}` com chave na margem, e em `_distancia_costa` usar `_grades_costa.get(margem)`, montando só se faltar ou se `_coast.size()` mudou. É ~10 linhas, e o resultado numérico é idêntico (mesmos segmentos, mesma conta).
- Esforço: 20–30 min com o teste.
- Risco: muito baixo. `tests/paisagismo.gd:373` e `:503` chamam `_distancia_costa(p, 26.0)` e continuam funcionando (mais uma chave no dicionário). A memória fica em 4–5 grades pequenas (< 3.000 inteiros cada).
- Como medir: (a) FPS e o monitor "Physics Process" com o jogador parado no meio da Ponte do rio central, comparado com 30 u fora do rio; (b) `tools/prototipo_3d/medir_carregamento.gd` antes e depois (etapas de rio, foz e praia).

### VIV-02: Física dos moradores com ímã de chão a 60 Hz até 90 u do jogador

**Evidência.**
- `npc.gd:256-257`: `floor_snap_length = 0.35`, `floor_max_angle = 46°`. `max_slides` fica no padrão (6). Camada/máscara padrão 1/1: os moradores colidem entre si, com o jogador e com tudo da camada 1.
- `npc.gd:417-443`: `_mover` chama `move_and_slide()` a cada tick, mais `_subir_degrau` (até 2 `test_move`, `:451-458`) e `_medir_bloqueio` (1 `test_move` no 1º bloqueio, `:574`).
- A economia só começa a mais de `LONGE = 90 u` do jogador (`npc.gd:74`, `:1157-1181`). Dentro desse raio, todo morador fora de casa faz física completa, **mesmo parado no posto**: `_mover(Vector3.ZERO, …)` é chamado igual (`npc.gd:407`) e o `move_and_slide` roda com velocidade zero.
- O próprio autor mediu, no bicho: "o `move_and_slide` com snap custava meio milésimo de segundo por bicho por quadro de física contra a malha do terreno, dez vezes o resto" (`bicho_de_casa.gd:120-122`) e "custa de 0,2 a 1,5 ms por bicho por quadro de física" (`bicho_de_casa.gd:412-415`). O bicho ficou com `floor_snap_length = 0.0` e `max_slides = 2` (`:123-124`); o morador não recebeu o mesmo remédio.
- O chão de colisão são vários `ConcavePolygonShape3D` sobrepostos (terra, ruas, areia), com `backface_collision = true` (`geo_region_renderer.gd:1045-1056`, `:1593-1603`).

**Mecanismo.** `move_and_slide` com snap faz várias consultas de movimento (`body_test_motion`): recuperação, deslize e snap para baixo, cada uma contra todos os trimeshes cujo AABB toca a cápsula. Isso roda na thread principal, no passo de física, 60 vezes por segundo, independente do FPS.

**Impacto (estimativa).** A vila tem ~170 × 160 u (Praça → Píer 88 u, Praça → Igreja 106 u, Praça → Bar 151 u). Na Praça, de dia, cabem ~12–18 moradores dentro de 90 u (o autor fala em "catorze corpos", `npc.gd:1154`). Com 12–18 × 0,2–0,5 ms são **2,4–9 ms por tick**, ou seja, 15–55 % de um núcleo só nisso, e até 4× por quadro quando o FPS cai (VIV-03). De noite pesa menos, porque os 14 de agenda se recolhem (`npc.gd:1133-1146`).

**Correções.**
- HOJE (opção A, a mais barata): copiar o remédio dos bichos em `npc.gd:256`: `floor_snap_length = 0.0` (ou 0,1) e `max_slides = 3`. Esforço: 5 min. Risco médio: morador descendo ladeira pode "saltitar" sem o ímã (o bicho resolveu com gravidade 20 e `velocity.y = -0.1` no chão, que o morador já tem em `:429-432`). Portões que cobram o andar dos moradores: `tests/rotina_dos_moradores.gd`, `tests/festa_da_fe.gd`, `tests/navegacao.gd`, `tests/casas_dos_moradores.gd`. Rodar esses quatro.
- HOJE (opção B): pular o `move_and_slide` de quem está **parado e no chão** (direção zero, `is_on_floor()`, sem nadar). Em `_mover` (`npc.gd:417`), sair antes do `move_and_slide` com `velocity = Vector3.ZERO`. Esforço: 15 min. Risco baixo a médio: quem é empurrado pelo jogador continua sendo empurrado, porque o empurrão chama `dar_passagem`, que dá direção.
- ESTRUTURAL: separar "distância de física" (como o `FISICA_ATE = 26` dos bichos, contado a partir da câmera) de "distância de animação" (90 u). Entre 26 e 90 u, andar pela malha de navegação com `ground_height_at`, como o `_andar_livre` dos bichos. Esforço: 2–4 h.
- Como medir: monitor "Physics Process" (Depurador → Monitores → Tempo) na Praça às 9 h. A/B com todos os nós do grupo `moradores` com `process_mode = DISABLED` pela árvore remota.

### VIV-03: Espiral de ticks: todo `_physics_process` vale 60×/s, e a 15 FPS são 4 ticks por quadro

**Evidência.** O `project.godot` não tem `[physics]`, então valem `physics_ticks_per_second = 60` e `max_physics_steps_per_frame = 8`. Rodam por tick: moradores (23), bichos (22), criaturas (3), espuma (24), fauna e cardumes (até ~53 atualizações), canoas (7 corpos), tubarão, cadeias de missões (~15–25 nós, `prototype.gd:585-914`) e o jogador (inventário completo na tabela de fatos).

**Mecanismo.** Quando um quadro demora 66 ms, o Godot roda 4 passos de física seguidos antes do próximo desenho para alcançar o tempo real. Se o custo dos ticks é parte do que deixou o quadro lento, o quadro seguinte fica ainda mais lento: é uma espiral que só para no teto de 8 passos.

**Impacto (estimativa, somando VIV-01/02/05/08/10/12 com o vale no centro da vila e longe do rio):** moradores 3–12 ms + bichos com física 0,5–3 ms + criaturas 0,3–2 ms + cardumes 0,2–3 ms + cadeias 0,1–0,6 ms ≈ **4–20 ms por tick**. A 60 FPS isso já ocupa até 1 quadro inteiro; a 15 FPS são 16–80 ms por quadro. A faixa é larga porque o custo de `move_and_slide` é a medição do autor, não minha. **Precisa ser confirmado no monitor "Physics Process"** (ver Dúvidas).

**Correções.**
- HOJE (configuração, para A/B e talvez para a build): `physics/common/max_physics_steps_per_frame = 3` no `project.godot`. Isso corta a espiral: abaixo de 20 FPS o jogo passa a ficar em câmera lenta em vez de travar. Esforço: 1 linha. Risco baixo a médio: o relógio do jogo (`Dia`) e os portões que contam ticks (`tests/luta.gd:123`, `tests/onca.gd:185`) usam `Engine.physics_ticks_per_second` e não mudam; muda só o comportamento abaixo de 20 FPS.
- A/B (não recomendo para a build sem teste): `physics/common/physics_ticks_per_second = 30` corta à metade a CPU de todos os itens acima. O risco é alto hoje: a câmera está no `_process` (`player_controller.gd:269-270`) seguindo um corpo movido a 30 Hz, o que dá tremor visível sem `physics/common/physics_interpolation = true`, e a interpolação muda teleportes (pede `reset_physics_interpolation()` em `teleportar`, `_back_to_land` e na queda).
- Como medir: o monitor "Physics Process" com 60 contra 30 ticks dá a fração de CPU que é física; o FPS com `max_physics_steps_per_frame` em 8 e em 3 numa cena pesada.

### VIV-04: Travada longa no fim do carregamento: um quadro que monta todos os vivos e carrega ~55 GLBs de forma síncrona

**Evidência.**
- `tela_carregamento.gd:498-512`: a tela some quando `mundo.construido` fica verdadeiro, com 0,35 s de fade.
- `prototype.gd:229-247`: depois disso o vale espera os interiores (2 ticks) e, em `:570-571`, roda `_montar_som()` e `_montar_moradores(spawn)` **sem nenhum `await`**. `_montar_moradores` (`:1080-1199`) cria, no mesmo quadro, os 23 moradores, o Tubarão (`:1126-1129`), o FaunaVale (`:1130`, que já encontra `world.construido` e monta tudo no `_ready`, `fauna_vale.gd:73-78`), os BichosDeCasa (`:1132`, idem em `bichos_de_casa.gd:58-63`), a Pesca, os Achados, a Luta e as Pegadas.
- `catalogo_assets.gd:383-394`: `cena(chave)` faz `load(path)` **síncrono** na 1ª vez. A cena `vale.tscn` só referencia o viajante (`scenes/prototipo_3d/personagem.tscn`); o menu não cria bichos nem moradores (grep em `abertura.gd` e `inicio.gd`). Por isso, neste quadro, carregam pela 1ª vez: 22 GLBs de moradores (4,0–6,1 MB cada), ~19 de bichos (galinha, galo, cão etc.), ~15 de peixes, as canoas já carregadas pelo mundo e as peças de mão. São ~55 cenas importadas mais ~165 texturas 1K enviadas à VRAM.
- `bando_de_chao.gd:89-90`, `:124-147`, `:174-194`: cada um dos 10 bandos chama `world.arvores()` de 2 a 5 vezes. `world_builder.gd:242-248`: cada chamada duplica a lista e cria **um Dictionary por tronco** (~6.300 troncos).
- `authored_animator.gd:117-120`: na 1ª chamada de `update_motion`, cada morador mede a passada com `_medir_passada("walk")` e `("run")`, de 49 `seek(…, true)` cada (`:229-241`). O cache é **por instância** (`_medido`); o animador dos bichos tem cache estático por modelo (`animador_bicho.gd:64-66`, `:122-128`) e o dos moradores não.
- `luta_vale.gd:161-181`: o ninho do caititu varre uma grade de 81 × 81 = 6.561 pontos (`na_mata_fechada` + `is_on_land`).

**Mecanismo.** É IO de disco e criação de recursos na thread principal (decodificar `.scn`, ler `.ctex`, enviar textura), mais muita alocação em GDScript, tudo em 1 quadro e depois que o jogador já vê o vale.

**Impacto (estimativa):** carregar ~55 GLBs leva 30–80 ms cada a frio, ou **1,5–4 s**; os `world.arvores()` dos bandos são 20–50 chamadas × 10–20 ms, ou 0,2–1 s; a passada são 23 × 98 seeks × ~50 µs ≈ 0,1 s; a grade da luta ~20 ms. **Total: ~2–5 s de imagem congelada** logo depois que a tela de carregamento some. Moradores e bichos longe medem a passada mais tarde, o que dá miniatravadas de ~5 ms ao se aproximar.

**Correções.**
- HOJE (percepção, a mais segura): manter a tela de carregamento até o vale terminar `_montar_moradores`. Em `prototype.gd`, logo depois de `:571` (ou no fim do `_ready`), marcar `vale_pronto = true` e emitir um sinal; em `tela_carregamento.gd:498`, esperar também por ele (`while … not mundo.construido or not vale.vale_pronto`). Esforço: 30–45 min. Risco baixo: a montagem não muda, só a ordem de quando a tela sai. Os portões que abrem `vale.tscn` sem tela não são afetados.
- HOJE (custo real, opcional): em `authored_animator.gd:117-120`, guardar `_passada` num `static var` com a chave em `animation_player.get_parent().scene_file_path` (como `animador_bicho.gd:122-128`). Esforço: 15 min. Risco baixo; o portão `tests/corte_das_arvores.gd` usa o mesmo animador, então rodar esse portão.
- ESTRUTURAL: (a) pré-carregar em segundo plano (`ResourceLoader.load_threaded_request`) a lista de GLBs dos vivos durante a montagem do mundo; (b) cachear `world.arvores()` em `world_builder.gd:242`, invalidando em `cortar_arvore`; (c) espalhar a montagem dos vivos por vários quadros com o mesmo orçamento de 80 ms do world_builder.
- Como medir: cronômetro entre o fim do fade e o 1º quadro com FPS > 30. Em `medir_carregamento.gd`, acrescentar a etapa "moradores".

### VIV-05: Cardumes: rumo de cada peixe em GDScript a cada tick e malha de 2 mil triângulos por peixe

**Evidência.**
- `fauna_vale.gd:593-626`: a cada tick monta a lista de perigos (`_juntar_perigos`: `get_nodes_in_group("moradores")` + 1 Dictionary por morador visível, `:567-581`) e atualiza todo cardume a menos de `alcance × 0,65` da câmera **todo tick**, até `alcance + 20` **a cada 3 ticks**, e esconde quem está além disso.
- `cardume.gd:270-297`: `atualizar` percorre os N peixes: `_mover` (laço nos perigos próximos, `lerp`, `limit_length`, `lerp_angle`; `:300-375`) + `_desejo` (`:379-464`) + `_escrever`, que monta `Basis.from_euler` e 16 floats por peixe e envia o buffer inteiro (`:880-913`).
- `cardume.gd:165`: alcance 70 u (raias 160; mar de fora e raias de areia 120, `fauna_vale.gd:469`, `:553`).
- Malha: `CatalogoAssets.malha(chave)` usa o GLB inteiro do peixe (`cardume.gd:785-794`), com 2.026–2.492 tri por peixe.
- Bom: o nado está no shader de vértice (`assets/prototipo_3d/fauna/nado.gdshader`), sem esqueleto, sombra desligada (`cardume.gd:761`), material compartilhado por espécie (`:133`, `:776-798`).

**Mecanismo.** É CPU de GDScript por peixe, no tick, mais o envio do buffer do MultiMesh a cada atualização. Na GPU, vértices: 20 sardinhas × 2.300 tri ≈ 46 mil tri por bola de sardinha. O LOD automático de MultiMesh decide pelo AABB do cardume inteiro, então cai pouco perto.

**Impacto (estimativa).** No píer ou na praia, ~100–200 peixes atualizados por tick × 8–15 µs ≈ **1–3 ms por tick** (no rio central, somar VIV-01). Na GPU, com todos os cardumes perto do píer visíveis, ~200 peixes × 2.300 ≈ 460 mil tri antes do LOD.

**Correções.**
- HOJE: `_mm.lod_bias = 0.5` em `cardume.gd:757-765` (o peixe é pequeno; vai mais cedo para o LOD baixo). Esforço: 1 linha, risco baixo. Opcional: alcance padrão de 70 para 50 em `cardume.gd:165`. O portão `tests/fauna_do_mar.gd:239` só exige alcance ≤ 160, e reduzir também baixa a CPU (menos cardumes acordados).
- ESTRUTURAL: um peixe "de cardume" low-poly (≤ 300 tri) no catálogo; levar o rumo do cardume "roda" e "bola" para o shader (fase e raio por instância); atualizar cada cardume a no máximo 30 Hz.
- Como medir: no píer, `FaunaVale.visible = false` e depois `process_mode = DISABLED`, olhando tri, draws e "Physics Process".

### VIV-06: AnimationPlayer dos 23 moradores toca a cada quadro até 90 u, mesmo fora da câmera; malhas com skin fazem sombra

**Evidência.**
- `authored_animator.gd:342-361`: o esqueleto só pausa quando `npc.gd` chama `dormir(true)`, a mais de 90 u (`npc.gd:1157-1163`). Dentro de 90 u ele toca em tempo integral, sem `VisibleOnScreenEnabler3D` (nenhum no projeto, grep `VisibleOnScreen` vazio) nem salto de quadros.
- São 23 esqueletos de 65 ossos (1.496 ossos) com clipes a 30 fps (`.import`).
- `catalogo_assets.gd:399-426`: `instanciar` não mexe em `cast_shadow`, então as malhas com skin dos moradores, dos bichos e das aves projetam sombra (o tubarão e os peixes desligam, `tubarao.gd:380`, `cardume.gd:761`).

**Mecanismo.** CPU: o AnimationMixer avalia as trilhas e o Skeleton3D recalcula as poses globais a cada quadro. GPU: no Forward+ do Godot 4 o skinning é feito por compute **uma vez por quadro por instância** (as cascatas de sombra não refazem o skinning), mas cada cascata redesenha a malha de 10–15 mil tri.

**Impacto (estimativa).** CPU: 23 × 40–120 µs ≈ **1–3 ms por quadro**. GPU: ~286 mil tri dos moradores × (1 + cascatas de sombra) antes do LOD.

**Correções.**
- HOJE (barato, risco baixo): nas malhas dos moradores, `cast_shadow = SHADOW_CASTING_SETTING_OFF` a partir de ~30 u, ou pelo menos nos 14 mudos de agenda. Um laço em `npc.gd:324-330` com `GeometryInstance3D.visibility_range_end` numa cópia "sombra" é estrutural; a forma simples é desligar a sombra só para quem está longe, no mesmo ponto em que `dormir()` é chamado (`npc.gd:1160-1163`). Medir antes de decidir.
- ESTRUTURAL: um `VisibleOnScreenEnabler3D` filho de cada morador, com `enable_node_path` no AnimationPlayer (pausa fora da tela); `callback_mode_process = MANUAL` e `advance()` a cada 2–3 quadros entre 30 e 90 u.
- Como medir: pela árvore remota, pausar os AnimationPlayer de todos os moradores e olhar o monitor "Process"; desligar `cast_shadow` nas 23 malhas e olhar o tempo de GPU e os draws.

### VIV-07: O AnimationPlayer do bicho de quatro patas continua tocando depois que o bicho some

**Evidência.** `animador_bicho.gd:305-307`: `_process` sai na 1ª linha se `not pose.is_visible_in_tree()`. Quem pausa o clipe (`animacao.pause()`, `:321-324`) fica depois desse retorno. O gerente esconde o bicho longe (`bichos_de_casa.gd:167-171`) e o bicho zera a velocidade (`bicho_de_casa.gd:190`), mas o animador não roda mais. **Resultado: o bicho que sumiu andando continua com o clipe de andar tocando** enquanto estiver longe. O mesmo vale para o clipe que `configurar` dá `play()` ao nascer (`animador_bicho.gd:119-121`).

**Mecanismo.** É CPU do AnimationMixer e do Skeleton3D (19–42 ossos) por quadro, para bicho invisível. Se o skinning por compute roda mesmo com a instância invisível, também custa GPU (ver Dúvidas).

**Impacto (estimativa).** Baixo a médio: até 22 bichos × 15–40 µs ≈ 0,3–0,9 ms por quadro no pior caso.

**Correção (HOJE).** Em `animador_bicho.gd:306`, antes do `return`, pausar se estiver tocando: `if animacao != null and animacao.is_playing(): animacao.pause(); _parado_no_quadro = true`. Esforço: 5 min. Risco baixo; o portão `tests/bichos_de_casa.gd` controla `perto` à mão e não cobra o clipe tocando longe.
- Como medir: contar quantos `AnimationPlayer.is_playing()` existem com `BichosDeCasa` escondido longe (remoto), antes e depois.

### VIV-08: As criaturas da mata (caititu e 2 onças) nunca dormem por distância

**Evidência.** `criatura_vale.gd:419-453`: `_physics_process` roda sempre (só a onça-preta é desligada de dia, `:812-817`, chamada por `luta_vale.gd:395-400`). `_pastar` (`:646-664`) anda e chama `move_and_slide` com os padrões (`floor_snap_length` 0,1, `max_slides` 6; `_mover`, `:734-746`). A onça olha a cada `OLHAR_A_CADA` com `intersect_ray` + grade de troncos (`:512-547`). `Animador.vestir` sem `alcance` (`:259`) deixa as malhas sem `visibility_range`.

**Mecanismo.** Física completa e animação de 3 corpos na mata, onde quer que o jogador esteja.

**Impacto (estimativa).** 3 × 0,2–1,5 ms quando andam (pastam metade do tempo), ou ~0,3–2 ms por tick.

**Correções.**
- HOJE (risco baixo a médio): em `criatura_vale.gd:419`, se o alvo está a mais de ~120 u, não está caçando e não está morrendo, decidir só a cada 0,25 s e não chamar `_mover`, como em `bicho_de_casa.gd:178-191`. Copiar também `floor_snap_length = 0.0` e `max_slides = 2` em `_ready` (`:229-235`). Portões: `tests/luta.gd` e `tests/onca.gd` chamam `_mover` à mão e contam ticks; rodar os dois.
- Passar `alcance` (80–120) em `Animador.vestir(chave, pose, tamanho, COR_DO_CORPO, 120.0)` (`:259`). Esforço: 1 linha.

### VIV-09: Bandos de aves: 49 nós avulsos, consulta de chão por ave por quadro e 3,5–4 mil tri por ave

**Evidência.**
- `bando_de_chao.gd:264-300`: com o bando visível, cada ave roda `_ciscar` + `_andar` no `_process`. `_andar` (`:439-456`), para cada ave andando, chama `dentro_de_casa` (laço em todas as casas do cache, `animador_bicho.gd:137-150`) e `world.ground_height_at` (`:453`).
- `ground_height_at` = IDW de 12 amostras + `is_point_in_polygon` + grade da costa + `_riverbed_profile`. Este último percorre os rios em GDScript (`_distance_to_line` com 36/41 pontos, `geo_region_renderer.gd:510-531`, `:1787-1797`) quando o ponto cai na caixa de um rio, e a caixa do rio central cobre o miolo da vila.
- As aves são MeshInstance3D separadas (49 draws mais sombra) de 3.509–4.040 tri (pintinho de 11 cm com 3.653 tri), com `visibility_range_end = 80` (`bando_de_chao.gd:235-236`, `animador_bicho.gd:238-242`).

**Impacto (estimativa).** CPU: ~20–30 aves andando × 20–40 µs ≈ 0,5–1,2 ms por quadro. GPU: ~186 mil tri e ~49 draws (× cascatas de sombra) quando todos os bandos estão a menos de 80 u da câmera.

**Correções.**
- HOJE: `cast_shadow = OFF` nas aves (são pequenas e a sombra quase não se vê) em `animador_bicho.gd:238-242`, no mesmo laço que põe o `visibility_range` (só quando `alcance > 0`, que vale para aves e bichos). Esforço: 2 linhas, risco baixo (visual). E `visibility_range_end` das aves de 80 para 50 em `bando_de_chao.gd:27`; o portão `tests/bichos_de_casa.gd:315-318` cobra o `ALCANCE` do **gerente**, não o do bando, mas conferir antes.
- ESTRUTURAL: aves de uma espécie num MultiMesh por bando; malhas de ave com ≤ 800 tri; altura do chão amostrada uma vez por ponto do terreiro (`pontos` já são pontos no chão; interpolar entre eles).

### VIV-10: Consultas de água do morador por tick (nado, desvio do mar, espuma)

**Evidência.** Por morador fora de casa e a menos de 90 u, a cada tick: `_atualizar_nado` → `water_depth_at` (`npc.gd:461-464`); andando, `_por_terra` → 1 a 9 `water_depth_at` (`:512-529`); a espuma → `water_level_at` (`espuma_agua.gd:69-79`). Cada consulta faz `is_point_in_polygon(_land)` mais o laço nos rios (com `_distance_to_line` em GDScript quando o ponto está na caixa do rio) mais `Mar.lamina_em`.

**Impacto (estimativa).** 3–11 consultas × 10–25 µs ≈ 30–250 µs por morador por tick, ou **0,5–3 ms por tick** para ~15 moradores (sem contar o VIV-01, que multiplica isso no rio central).

**Correções.** HOJE (risco baixo): `_atualizar_nado` e a espuma a cada 4 ticks (contador por morador). O nado tem histerese (`ANDA_ATE` / `NADA_A_PARTIR`) e aguenta 66 ms de atraso. ESTRUTURAL: cachear a "célula de água" por posição (grade de 1 u) no world_builder.

### VIV-11: Os rótulos 3D de nome continuam desenhados com alfa zero

**Evidência.** `placas_nomes.gd:25-27` põe `nome_label.modulate.a = 0` e `outline_modulate.a = 0`, mas o Label3D segue `visible` (é o sinal "sem balão", `:40`). São 23 Label3D billboard com contorno (`npc.gd:269-277`), sem `visibility_range`.

**Mecanismo.** Cada um entra na fila transparente (texto + contorno), com ordenação e preenchimento, mesmo invisível.

**Impacto.** Baixo: ~46 draws transparentes por quadro quando os moradores estão na tela.

**Correção (HOJE).** Em `placas_nomes.gd:25-27`, acrescentar `morador.nome_label.layers = 0`: some da câmera e continua `visible`, então o sinal do balão não muda. Esforço: 1 linha, risco baixo.

### VIV-12: Cadeias de missões ativas recalculam metas e montam texto a cada tick

**Evidência.** `cadeia_de_missoes.gd:970-981`: a cada tick, `_palavra_livre()` (2 laços sobre `_falando`) e `correr()`. Em passo com meta (`:301-314`), por tick: `_tentar_encontro`, `_receber_o_mutirao` (formata `"mutirao:%s:%s"` por ajudante, `:1320`), `_acertar_o_caderno` (monta `partes: Array[String]`, `:805-819`), `falta_a_meta` (aloca `_carga_da_meta`, `:627-640`) e `resumo_do_passo` (monta `String` com nomes em `to_lower()`, `:389-403`), só para comparar com o que já está mostrado. São ~15–25 cadeias penduradas (`prototype.gd:585-914`); as não iniciadas saem cedo.

**Impacto (estimativa).** Baixo: 5–10 ativas × 20–60 µs ≈ 0,1–0,6 ms por tick.

**Correção.** ESTRUTURAL: rodar `correr` a 10 Hz (acumular delta) ou só quando o inventário ou a posição mudam (sinais `Inventario.mudou`). HOJE: não vale o risco.

### VIV-13: Porco sem fruteira por perto refaz a lista de ~6.300 árvores a cada decisão (condicional)

**Evidência.** `bicho_de_casa.gd:309-319`: à tarde, se `_fruta` não é finita, chama `_fruteira_perto` (`:321-331`), que chama `world.arvores()` (~6.300 Dictionary novos, `world_builder.gd:242-248`). Se nenhuma mangueira ou jaqueira estiver a menos de 40 u do chiqueiro, `_fruta` continua `INF` e a busca se repete **todo tick** (bicho perto) ou a cada 0,25 s (longe), para os 3 porcos da Casa de Carro Quebrado.

**Impacto.** Condicional e potencialmente grande: 3 × 10–20 ms por tick à tarde, perto do chiqueiro. Só acontece se não houver fruteira no raio (há mangueiras e jaqueiras de quintal em `data/paisagismo/receitas.json` e em `world_builder.gd:1629-1650`, mas não deu para confirmar a distância sem rodar).

**Correção (HOJE, risco baixo).** Em `bicho_de_casa.gd:312-313`, guardar "procurei e não achei" (ex.: `_fruta_procurada = true`) para não repetir a busca. Esforço: 3 linhas.
- Como medir: inspetor remoto, `BichoPorco*._fruta` às 14 h.

---

## O que está OK

- **Economia de longe do morador**: a mais de 90 u do jogador anda sem física, esqueleto pausado na última pose e altura pelo terreno (`npc.gd:1157-1181`, `authored_animator.gd:342-361`). Recolhido em casa: invisível, sem colisão e sai cedo do tick (`npc.gd:389-391`, `:1133-1146`).
- **Gerente dos bichos**: confere a distância a cada 0,5 s com histerese (`bichos_de_casa.gd:140-176`); física só a menos de 26 u da câmera, com `floor_snap = 0` e `max_slides = 2` (`bicho_de_casa.gd:120-124`, `:366-368`); longe, decide a cada 0,25 s e pula para o destino (`:178-191`). As malhas somem a 80 u (`animador_bicho.gd:238-242`).
- **Bandos**: aves sem física; longe da câmera, conferência a cada 0,25 s e sem animação (`bando_de_chao.gd:269-284`); o animador não roda com a pose invisível (`animador_bicho.gd:306`).
- **Cardumes**: 1 MultiMesh por cardume, nado no shader de vértice (sem esqueleto), sombra desligada, `visibility_range_end`, LOD de atualização (todo tick, a cada 3 ticks ou dormindo) e material compartilhado por espécie (`cardume.gd:748-798`, `fauna_vale.gd:604-625`).
- **Tubarão**: sombra desligada, alcance de 160 u, cauda com 2 ossos por tick; some na maré baixa (`tubarao.gd:98-117`, `:378-380`, `:432-439`).
- **Materiais e malhas compartilhados**: `CatalogoAssets.instanciar` só instancia a cena e não duplica material nem malha (`catalogo_assets.gd:399-426`). A única duplicação de material é a do jogador quando `double_sided_materials` está ligado (`player_controller.gd:418-424`).
- **Câmera sem salto**: o SpringArm3D só mede e a câmera é posta no `_process` com interpolação (`player_controller.gd:243-267`, `:1297-1335`). Barato: 1 shape cast por tick do próprio SpringArm.
- **Navegação**: NavigationServer3D (Recast), assado em thread (`navegacao_vale.gd:110-116`); caminho refeito a cada 4 s pelo morador (`npc.gd:147`, `:870-885`) e a cada 3 s pelo bicho (`bicho_de_casa.gd:42`, `:454-472`). Nenhum recálculo pesado por tick. Observação: `parse_source_geometry_data` (`:114`) e o pós-processamento `_ao_assar`/`_o_pedaco_maior` (laço GDScript nos ~7.000 polígonos, `:187-275`) rodam na thread principal. É uma miniatravada única, de dezenas de ms (estimativa), ~2 s depois de entrar no vale e a cada `reassar()`.
- **Skinning e sombras**: no Forward+ do Godot 4 o skinning é feito por compute uma vez por quadro; as cascatas de sombra **não** refazem o skinning, só redesenham.
- **Partículas de espuma** (24): não emitem fora d'água; o GPUParticles3D fica inativo depois do `lifetime` e não é processado.
- **Pegadas**: pool fixo de 64, sem sombra e só as visíveis contam (`pegadas.gd:38-72`).
- **Balão de fala**: só calcula com o balão visível (`balao_fala.gd:96-98`). **Itens pendurados** se aprumam no sinal `skeleton_updated`, sem `_process` (`vestimenta_3d.gd:225-234`).
- **Saveiro**: atualiza a encomenda a cada 60 quadros (`saveiro_vale.gd:533-536`). **Luta**: as onças são conferidas a cada 0,25 s (`luta_vale.gd:375-391`).
- **Mar e altura**: `Mar.lamina_em` é leitura de pixel O(1) (`mar.gd:130-135`); o IDW tem só 12 amostras.
- **Jogador**: `_process` barato (câmera e itens na mão, que só mudam quando o equipamento muda, `player_controller.gd:269-336`). O raycast de hover de casa (2 raios de até 2.800 u por tick com o mouse visível, `:438-457`, `:1000-1020`) é migalha.

---

## Dúvidas para medição A/B

Todas pela árvore remota do Depurador (Remoto → Cena) com o jogo rodando. Monitores em Depurador → Monitores: **Time/Process**, **Time/Physics Process**, **Object/Nodes**, **Raster/Total Draw Calls**, **Raster/Total Primitives**.

1. **Confirmar o VIV-01 (grade da costa).** Com o jogador parado no meio da "Ponte do rio central" (ou dentro do rio central, perto da Igreja) e depois 30 u fora do rio, anotar FPS e "Physics Process". Repetir com `FaunaVale.process_mode = DISABLED`. Se "Physics Process" sobe vários ms só no rio, o VIV-01 está confirmado.
2. **Física dos moradores (VIV-02).** Na Praça às 9 h: "Physics Process" com tudo ligado contra todos os `Morador*` e o `Pedro` com `process_mode = DISABLED`. Contar quantos moradores estão a menos de 90 u.
3. **Qual motor de física está em uso?** O `project.godot` não declara `physics/3d/physics_engine`; conferir em Configurações do Projeto → Física → 3D. Fazer um A/B com "Jolt Physics", que costuma ser bem mais rápido em cápsula contra trimesh. Risco de comportamento: rodar os portões de movimento antes de adotar.
4. **Espiral de ticks (VIV-03).** Com `physics/common/max_physics_steps_per_frame` em 8 e em 3, numa cena pesada, ver se o FPS para de despencar. Com `physics_ticks_per_second` em 60 e em 30, só para medir a fração de CPU que é física.
5. **Animação dos moradores (VIV-06).** Pausar os 23 AnimationPlayer (propriedade `active = false` em cada um) e olhar "Process"; depois, `cast_shadow = OFF` nas 23 malhas com skin e olhar o tempo de GPU (Visual Profiler) e os draws.
6. **Peixes (VIV-05).** No píer: `FaunaVale.visible = false` (só GPU) e depois `process_mode = DISABLED` (CPU), olhando primitivas, draws e "Physics Process".
7. **Aves e bichos (VIV-07/09).** `BichosDeCasa.visible = false` e depois `process_mode = DISABLED` perto da Casa de Carro Quebrado. Ver se há AnimationPlayer de bicho escondido com `is_playing() == true`.
8. **O skinning de malha invisível roda?** Com os bichos longe (invisíveis) e o clipe tocando (VIV-07), comparar o tempo de GPU antes e depois de pausar os AnimationPlayer.
9. **Porco (VIV-13).** Às 14 h, inspecionar `_fruta` nos 3 porcos (`BichoPorco*`, `BichoLeitao*`). Se for `(inf, inf, inf)`, o achado está ativo.
10. **Travada do fim do carregamento (VIV-04).** Cronometrar do fim do fade da tela até o 1º quadro com FPS > 30; conferir no Profiler se o pico está em `_montar_moradores` e `load()`.
11. **Moradores do rio.** Às 8 h, conferir se pescador, marisqueira, lavadeira e mestre do saveiro estão **dentro** da meia-largura do rio central (`world.water_depth_at(pos) > 0`). Se estiverem, cada um paga 4 reconstruções da grade por tick até o VIV-01 ser corrigido.
12. **Carregamento das faixas de rio, foz e praia.** Rodar `tools/prototipo_3d/medir_carregamento.gd` antes e depois da correção do VIV-01 e ver se as etapas de rio e praia caem.

---

## Ordem sugerida para a build de hoje (escopo VIV)

1. **VIV-01**: cache por margem em `_distancia_costa`. É a de maior retorno por linha alterada, serve para o jogo e para o carregamento, e o resultado é idêntico.
2. **VIV-04**: tela de carregamento até o fim de `_montar_moradores`. Esconde a travada sem mudar a montagem.
3. **VIV-07**, **VIV-11**, **VIV-13**: uma linha cada, risco baixo.
4. Medir o VIV-02 e o VIV-03 (A/B 2–4). Se "Physics Process" passar de ~6 ms na Praça, aplicar o remédio dos bichos aos moradores (`floor_snap_length = 0`, `max_slides = 3`, pular o `move_and_slide` de quem está parado) e `max_physics_steps_per_frame = 3`, rodando os portões de rotina, festa, navegação e casas.
5. Sombras desligadas nas aves (VIV-09) e `lod_bias` nos cardumes (VIV-05), se o A/B mostrar a GPU como gargalo.
