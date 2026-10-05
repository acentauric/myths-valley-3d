# Investigação de desempenho — escopo MUN: vila, construções, paisagismo autoral, adereços, interiores e colisões

Projeto `myths-valley-3D` (Godot 4.7.2, Forward+), commit eb430e4, árvore limpa. Investigação **somente leitura**: nada foi alterado no repositório e o Godot não foi executado. Todos os números abaixo vêm de leitura de código/cenas/dados ou de scripts auxiliares em Python (biblioteca padrão) que leram os GLB, os `.tscn` e o `.godot/imported`. Onde há estimativa, a conta está escrita ao lado e marcada como **estimativa**.

Scripts auxiliares (saídas nesta mesma pasta `scratchpad/perf`): `glbstat.py` (triângulos, vértices, texturas e materiais de cada GLB), `glbmat.py` (flags dos materiais), `vram.py` (tamanho dos `.ctex` por GLB), `comp.py` (contagem da composição autoral), `paisagismo_sim.py` (réplica exata do sorteio por hash do paisagismo, sem as reservas), `wedge.py` / `wedge2.py` (triângulos no cone de câmera), `carga_mun.py` (bytes lidos por grupo de peças).

---

## Resumo

1. **O maior item deste escopo é o paisagismo de 04–05/10** (`paisagismo_vale.gd`). Ele usa o mesmo mecanismo bom da mata (MultiMesh em blocos de 40 u, `visibility_range_end`, LOD importado, sem sombra), mas a **conta de triângulos é pesada**: simulei o sorteio com os mesmos hashes e saem **até ~3.026 pés** (limite superior, sem as reservas de rua/casa/rio) em **195 MultiMeshInstance3D**, com **10,4 milhões de triângulos no LOD0 se tudo aparecesse** (bananal sozinho: 545 × 5.219 = 2,84 M). Num cone de câmera de 90° dentro do alcance de LOD saem **0,4–4,1 M de triângulos LOD0 (mediana ~2 M) a partir da praça**. O "leve" não é leve: os `_leve` medem 3,4–5,9 mil triângulos, não os "~2.500" do comentário (`catalogo_assets.gd:323`), e `goiabeira` (7,7 mil) e `mamoeiro` (5,1 mil) nem foram refeitos. O portão de orçamento (`tests/paisagismo.gd:36-37`) aceita 14.000 pés e **45 milhões** de triângulos, ou seja, não protege nada. Referência do próprio autor: 60 FPS com 2,4–3,6 M de triângulos no quadro (26/09).
2. **O mundo inteiro é montado duas vezes**: `abertura.tscn` e `vale.tscn` têm cada uma o seu `Cenario` com `world_builder.gd` (abertura.tscn:13-14, vale.tscn:15-16) e não há reaproveitamento (`tela_carregamento.gd:453-479` troca de cena). Caches estáticos do catálogo aliviam parte da segunda montagem; o planejamento do paisagismo, os nós e a região são refeitos.
3. **Tudo o que o `world_builder` põe como peça individual (~300 GLB) não tem corte por distância nenhum** (nenhum `visibility_range`, nenhum `VisibleOnScreen*` no escopo; só a mata/paisagismo em MultiMesh têm) **e todos fazem sombra** no sol de 4 cascatas (`ceu_vale.gd:91-93`, 180 u). São poucos triângulos no total (~1,6 M se tudo aparecesse: casas 254 mil, árvores nomeadas 618 mil, adereços/recursos ~515 mil, interiores ~170 mil), então é custo de chamadas de desenho e de passadas de sombra, não o gargalo principal.
4. **Todas as 262 GLB do Tripo têm material `doubleSided: true`** (`glbmat.py`). O importador do Godot traduz isso em `cull_mode = DISABLED`: casas, adereços e árvores desenham as faces de trás no pré-passe de profundidade, na passada de cor e nas sombras. O próprio `interiores.gd:425-435` já força `CULL_BACK` nas cascas de 4 casas, o que prova que o modelo aguenta.
5. **Carregamento**: este escopo lê ~117 GLB únicos = **470 MB de texturas VRAM + 26 MB de malhas** (`carga_mun.py`); construções (20 chaves) pesam 179 MB só porque as 25 construções e as 14 árvores nomeadas full-res são todas 2K, contra a regra do projeto (2K só para destaque). Somam-se **1,5–2 s estimados** de GDScript varrendo vértices de malha na montagem (`pegada`, `tronco`, `_em_metros`), o planejamento do paisagismo (~11 mil candidatos, 0,5–1,2 s estimados por montagem), 8 esperas de quadro de física nos interiores e dois bakes de navegação.
6. **Custo por quadro dos scripts do escopo é migalha** (19 nós com `_process`, estimativa < 1 ms no total). Há um desperdício barato: `Dia.hora_mudou` é emitido **todo quadro** e cada ouvinte reaplica luzes e janelas.
7. O que mais provavelmente explica 60→15 FPS **dentro deste escopo** é (1) os triângulos do paisagismo no cone da câmera, (2) a soma de sombras + chamadas dos ~300 GLB individuais e (3) faces de trás. A medição A/B da seção final isola cada um em minutos (esconder nós por prefixo de nome, sem mexer em arquivo).

---

## Fatos contados

| fato | valor | fonte |
|---|---|---|
| Construções na composição autoral (`ComposicaoDoVale/Casas`) | **23**: casa_taipa 6, casa_carro_quebrado 3, casa_taipa_ocre 2, e 1 de cada: casa_paroquial, casa_taipa_azul, casa_pescador, casa_meia_agua, casa_taipa_rosa, casa_taipa_verde, casa_varanda, casa_farinha, igreja, capela, venda, casa_pasto | `scenes/prototipo_3d/composicao_vale.tscn` (120 nós; `comp.py`) |
| Peças autorais penduradas nas casas | **95** nós: adereço 35, árvore 26, Decal de terreiro 23, item 5, candeeiro 3, luz de janela 2, lampião 1; `pecas_criadas = true` nas 23 casas | `composicao_vale.tscn`; `casa_composicao.gd:19-26` |
| Adereços da composição | 35 = varal 8, varal_bambu 6, varal_estacas 6, galinheiro 8, chiqueiro 1, cocho 1, lenha 1, pote 1, canoa_em_obra 1, lavadouro_pedra 1, cruzeiro 1 | `composicao_vale.tscn` |
| Árvores nomeadas (peça individual) | **50** = pitangueira 18, bananeira 4, dendezeiro 3, ipê amarelo 2, ipê roxo 2, pau-brasil 1, mangueira 5, cajueiro 4, jaqueira 3, embaúba 2, coqueiro 2, mata_alta 2, mata_larga 1, gameleira 1 | `world_builder.gd:1626-1660`, `:2301-2304`, `:2425-2437`; composição |
| Triângulos das 23 construções da composição | **≈ 254 mil** (9.297–13.332 cada; igreja 13.332, casa_taipa 11.343) | `glbstat.tsv` (soma por chave × quantidade) |
| Triângulos das 50 árvores nomeadas (modelos cheios) | **≈ 618 mil** (pitangueira 9.688 × 18 = 174 mil; mangueira 20.453 × 5 = 102 mil; cajueiro 15.420 × 4; bananeira 14.753 × 4...) | `glbstat.tsv` |
| Mesmas 50 árvores com os modelos `_leve` que existem | ≈ 224 mil (−64%); cajueiro_leve não tem `tronco` no catálogo | `catalogo_assets.gd:323-340` |
| Estrutura de todo GLB do Tripo | 262 GLB: **1 mesh, 1 primitiva, 3 texturas (1K ou 2K), `alphaMode OPAQUE`, `doubleSided: true`** em 100% dos 262 materiais | `glbmat.py` |
| Importação de malha | `generate_lods=true`, `create_shadow_meshes=true`, `light_baking=1` em 262 de 262 | `assets/prototipo_3d/**/*.glb.import` |
| Zonas de paisagismo | **19** `Path3D` usando 10 receitas (bananal, pasto_mangueiras, pomar_quintal, roca_mandioca, roca_milho_fumo, dendezal, mata_ciliar, cajual_capoeira, cajual_restinga, pitangal) | `scenes/prototipo_3d/paisagismo_vale.tscn`; `data/paisagismo/receitas.json` |
| Candidatos avaliados pelo gerador (sem reservas) | ~11.185 (inclui forro) | `paisagismo_sim.py` |
| Pés do paisagismo (limite superior, sem reservas de rua/casa/rio/costa e sem filtro de rio na mata ciliar) | **3.026**; com tronco (entram em `_tree_trunks`): **1.207**; blocos MultiMesh por espécie+LOD+bloco de 40 u: **195** | `paisagismo_sim.py` (réplica do hash `ruido`, `paisagismo_vale.gd:90-96`) |
| Pés por alcance de LOD | lod 230: 1.207 pés (6,37 M tri); lod 120: 1.089 (2,31 M); lod 90: 185 (0,52 M); lod 85: 545 taboas (1,23 M, inflado sem o filtro de rio) | `paisagismo_sim.py`; `receitas.json` |
| Soma de triângulos de todos os pés no LOD0 | **10,43 M** (bananeira_leve 545 × 5.219 = 2,84 M; taboa 545 × 2.256; piaçava 161 × 5.894; mandioca 441 × 1.772; goiabeira 79 × 7.682...) | `paisagismo_sim.py` |
| Triângulos por espécie leve (medidos) | bananeira_leve 5.219; cajueiro_leve 5.670; pitangueira_leve 3.788; mangueira_leve 3.872; jaqueira_leve 4.052; dendezeiro_leve 5.583; piaçava_leve 5.894; ingá_leve 5.426; jenipapo_leve 5.652; aroeira_leve 3.403; goiabeira 7.682 (cheia); mamoeiro 5.087 (cheio); capim 2.907 | `glbstat.tsv`; comentário diz "~2.500 faces": `catalogo_assets.gd:323` |
| Triângulos LOD0 de pés dentro do alcance, cone de 90° | praça (0,0): mín 0,44 M / mediana 1,97 M / máx 4,07 M; (−40,30): 0,13 / 1,87 / 3,50; (−157,117) bananal: 0 / 1,56* / 3,66; (−100,100): 0 / 1,91 / 3,75 | `wedge.py`, `wedge2.py` (*mediana do cone com os `lod` atuais) |
| Cercas de varas em volta das roças | ≤ 278 lances × 2.029 tri = ≤ 564 mil tri, MultiMesh, `lod` 110 | `receitas.json:74`; `paisagismo_vale.gd:1015-1033`; perímetros das 4 roças (`cerca_sim.py`) |
| Alcance de LOD dos blocos | `visibility_range_end = lod` + margem 20, `lod_bias = 0.65`, `cast_shadow = OFF`; bloco de 40 u | `geo_region_renderer.gd:187,196-197,2158-2162` |
| Portão de orçamento do paisagismo | `PES_MAXIMOS := 14000`, `TRIANGULOS_MAXIMOS := 45000000.0` | `tests/paisagismo.gd:36-37` |
| Medições anteriores do autor | 26/09: 60 FPS, 2,4–3,6 M tri/quadro (1280×720); 30/09 (A/B do LOD): 19,6–28,8 FPS com 7–11 M tri/quadro | `docs/mundo/VALE_VIVO_3D.md:121-165` |
| Sol | `shadow_enabled`, `SHADOW_PARALLEL_4_SPLITS`, `directional_shadow_max_distance = 180` | `ceu_vale.gd:91-93` |
| Câmera do jogador | FOV 58°, near 0,08, **far 2.800** | `player_controller.gd:260-262` |
| Névoa | exponencial, densidade 0,0011 (dia): a 230 u cobre só 22% | `ceu_vale.gd:27,164-170` |
| Corte por distância nas peças individuais do escopo | **0** ocorrências de `visibility_range_*` / `VisibleOnScreen*` em world_builder, catálogo, interiores, fazenda, lombada, recursos etc.; só `geo_region_renderer`, `copas_distantes` e bichos/cardume/tubarão (outros escopos) | `grep visibility_range` em `scripts/` |
| `cast_shadow` explícito no escopo | só `comodo.gd:392` (teto da câmera de cima) e partículas; todo GLB individual usa o padrão (liga) | `grep cast_shadow` |
| Luzes de época | **12** `OmniLight3D` sem sombra: 4 lampiões (alcance 7,5 u), 4 candeeiros (4,5), 2 fogueiras (9,0), 2 janelas (3,5); só acendem com `luz_do_dia < ~0,6`; sem `distance_fade` | `luzes_epoca.gd:14-27,126-145,166-189`; `world_builder.gd:2027-2050` |
| Partículas | 4 `GPUParticles3D` (2 fogueiras × chama 72 + brasas 16), sempre `emitting`, também de dia | `luzes_epoca.gd:33-100` |
| Interiores | **4** salas (igreja, casa herdada, Pedro, Zefa), montadas na carga e sempre na árvore e visíveis; cada uma com 1 `ReflectionProbe`, 1 `OmniLight3D` de lampião, 1–3 velas, e 1 (casas) a ~8–10 (igreja) `SpotLight3D` de janela, tudo sem sombra | `interiores.gd:61-73,167-234`; `comodo.gd:132-138,453-548` |
| Peças dos interiores (**estimativa**) | ~215 `MeshInstance3D` (caixas de parede/viga/janela + GLB de móveis), ~170 mil triângulos, ~22 luzes | contagem de `_caixa(`/`_peca(`/`_janela(` em `comodo.gd`, `interior_casa.gd`, `interior_igreja.gd` |
| Decals de terreiro | **23** `Decal` (9–11 × 2,4 × 8–13 u), sem `distance_fade`, `cull_mask` padrão | `composicao_vale.tscn` (23 `Terreiro`); `terreiro_casa.tscn`; `world_builder.gd:904-909` |
| Label3D | 21 rótulos de casa criados `visible=false` + 1 letreiro da lombada (+ 1 por morador, `npc.gd:269`, fora do escopo); billboard ligado, sem `fixed_size` nem `no_depth_test`; texto só muda ao passar o mouse | `world_builder.gd:1314-1328,1342-1352`; `lombada_vale.gd:317` |
| Corpos de colisão (**estimativa**) | ~350 `StaticBody3D` / ~400 `CollisionShape3D` estáticos no escopo (23 casas, 31 alicerces, 50 árvores, ~40 adereços, 12 túmulos, ~23 recursos, ~27 lombada, ~100 de interiores...) + 21 `Area3D` de clique | contagem por categoria (tabela abaixo); `world_builder.gd:1296-1328` |
| Colisão por malha (trimesh) | só píer e 2 pontes (11.747 e 11.914 tri) via `create_trimesh_collision`; mais 4 trimesh provisórios de medida (casca das construções que abrem), liberados | `catalogo_assets.gd:460-464`; `interiores.gd:286` |
| Texturas (`ctex`) do escopo | 117 GLB únicos = **470 MB** de textura VRAM + 26 MB de malha: construções 179 MB (20 chaves), árvores nomeadas 107 MB (14), adereços 43 MB, itens 41, móveis 40, paisagismo 38, fazenda 23 | `carga_mun.py` (soma de `.godot/imported/*.ctex` por GLB) |
| `ctex` do projeto agora | 873 arquivos / **863 MB** (807 `.s3tc.ctex`), contra 463/492 MB do briefing: o cache foi reimportado (561 arquivos datados de 05/10) | `ls .godot/imported`; `vram.py` |
| Textura por GLB de construção | 8,0 MB (3 texturas 2048², BC1+BC1+BC3 com mip) ou 10,7 MB; 25 construções e as árvores cheias são todas 2K | `vram.tsv`; `glbstat.tsv` |
| Mundo montado por cena | `abertura.tscn` e `vale.tscn` instanciam `world_builder.gd` cada | `abertura.tscn:13-14`; `vale.tscn:15-16`; `abertura.gd:1853` |
| Orçamento de quadro da montagem | `ORCAMENTO_QUADRO_US = 80000`; `_pausar()` só cede entre chamadas | `world_builder.gd:674-683` |
| Quem escuta `Dia.hora_mudou` (emitido **todo quadro**) | `world_builder._aplicar_hora` (céu + `LuzesEpoca`), `Comodo._acompanhar_o_dia` × 4, `AmbienteVale`, áudio, HUD, ícone do relógio, saveiro | `dia.gd:109-119,154-158`; `world_builder.gd:725-732`; `comodo.gd:553-562` |
| Scripts com `_process` no escopo | 19 nós: Interiores, Comodo × 4, LuzesEpoca, PlacasNomes, ArvoresInfo, Recursos3D, AchadosVale, LavouraVale, Fazenda, Lombada, PonteVale, CemiterioVale, Lapides, MarcosDaFe, CasaDoJogador, TeclaDasBancadas | `grep "func _process"` |
| Recursos coletáveis | **49** (pedras 11, moita 9, capim 8, cana 6, embaúba 4, pedra_mare 4, lenha 3, tronco_caido 3, lapa 1), cada um GLB individual + colisão | `data/recursos_3d.json`; `recursos_3d.gd:100-165` |
| Lombada | 8 + 3 + 8 = **19** `pedras` (3.816 tri) + 8 blocos de caixa + 1 cabra | `lombada_vale.gd:248-294` |
| Lavoura | 24 leitos (BoxMesh, material compartilhado) + até 24 plantas GLB | `lavoura_vale.gd:33-36,140-153,183-192` |
| Cercado do cemitério (condicional à obra) | ~30 lances de `cerca` GLB (3.950 tri) + corpo; ponte cercada de início: 2 lances | `cemiterio_vale.gd:142-160,190-212`; `ponte_vale.gd:110-125` |
| Conjunto de troncos com corpo | pool 48 cilindros, raio 28 u, atualizado a cada 0,25 s | `geo_region_renderer.gd:71-75,2426-2434,2456-2490` |
| `physics_frame` esperados na montagem dos interiores | 2 por sala × 4 = 8, em série, com `await interiores.configurar` | `interiores.gd:294-295`; `prototype.gd:246` |

### Inventário de instâncias (pergunta 1)

Legenda: "individual" = `CatalogoAssets.instanciar` (`scene.instantiate()` do GLB, 1 `MeshInstance3D` com 1 superfície = 1 desenho por passada). Contagens do código e da composição; `≤` quando depende de reserva/missão.

| tipo | quantidade | como instancia | corte por distância? | sombra? |
|---|---:|---|---|---|
| Casas, igreja, capela, venda, restaurante (composição) | 23 | GLB individual + caixa de colisão (`pegada`) + alicerce BoxMesh sólido + Decal de terreiro + Area3D/Label3D de clique (21 casas) | não | sim |
| Capelinha do cemitério, mirante, píer, 2 pontes, poço, casa-terreiro (0,72×) | 1+1+1+2+1+1 | GLB individual; píer/pontes com trimesh (3) + laje de câmera | não | sim |
| Fazenda: casarão, guarita, portão | 3 (+ festa: 2 mesas caixa, 10 bancos, 3 cabras no dia marcado) | GLB individual | não | sim |
| Árvores nomeadas (vila, quintais, terreiro, fazenda, praia) | 50 | GLB **cheio** (9,7–20,5 mil tri, 2K) + cilindro de tronco | não | sim |
| Pé das árvores (decalque de chão) | 50 nomeadas + troncos de areia | PlaneMesh em MultiMesh/blocos | **não por regra** (gate `lod_vegetacao.gd:23`) | não |
| Paisagismo: plantas | ≤ 3.026 em ≤ 195 blocos | **MultiMesh em blocos de 40 u** por espécie e LOD, por `_multimesh_em_blocos` | **sim**: 85 / 90 / 120 / 230 u (+margem 20, `lod_bias` 0,65) | não |
| Paisagismo: cercas de varas | ≤ 278 | MultiMesh em blocos | sim: 110 u | não |
| Paisagismo: porteira, estaleiro, carro de boi, monjolo, barracas | ≤ 10 | GLB individual + colisão de caixa | não | sim |
| Adereços das casas | 35 (varais 20, galinheiros 8, 1 chiqueiro, 1 cocho, 1 lenha, 1 pote, 1 canoa, 1 lavadouro, 1 cruzeiro) | GLB individual (+ caixa em 13) | não | sim |
| Itens de mão e luz de composição | 5 itens + 3 candeeiros + 1 lampião + 2 janelas (quad) | GLB individual / quad | não | sim |
| Vila: poço, 2 bancos, carroça, pote do píer, 4 itens, canteiro de mandioca, 2 cercas, ≤16+4 moitas | ~35 | GLB individual | não | sim |
| Vila: 3 lampiões da praça, candeeiro do píer, fogueira, terreiro de santo (4 potes, fogueira, 2 mastros), gameleira (+fitas, 4 potes) | ~19 | GLB individual (+ 12 luzes e 4 sistemas de partículas) | não | sim |
| Pedras: marco 1, praia 3, maré ≤ 4 | ≤ 8 | GLB individual | não | sim |
| Túmulos e lajes | 12 | GLB individual + caixa sólida | não | sim |
| Recursos coletáveis | 49 | GLB individual + colisão | não | sim |
| Lombada | 19 pedras + cabra | GLB individual (+ 8 caixas) | não | sim |
| Lavoura | 24 leitos + ≤ 24 plantas | BoxMesh (material compartilhado) / GLB individual | não | sim |
| Cercado do cemitério / cerca da ponte | ~30 / 2 (condicional) | GLB individual `cerca` esticado + caixa | não | sim |
| Interiores | 4 salas, ~215 meshes (estimativa) | caixas + GLB de móveis + materiais por `ShaderMaterial` | não (só `visible` nunca é tocado) | sim (teto/casca só sombra com câmera de cima) |
| Decals de terreiro | 23 | `Decal` | não (sem `distance_fade`) | n/a |
| Alicerces | ~31 (22 casas + igreja com borda e degraus + capelinha) | BoxMesh + StaticBody, material `_terreiro_material` compartilhado | não | sim |
| **Total de nós GLB individuais exteriores** | **≈ 300** (+ ~45 GLB de móveis nos interiores, + 30 de cercado se obra feita) | | | |

---

## Achados

### MUN-01 — Paisagismo novo: milhões de triângulos LOD0 no cone da câmera, "leve" não é leve

**Evidência.**
- `paisagismo_vale.gd:641-683` (`plantar`): agrupa por `chave|lod` e chama `regiao._multimesh_em_blocos("Paisagismo: %s %d", modelo.mesh, transforms, lod, registros)`.
- `geo_region_renderer.gd:2139-2197`: MultiMesh em blocos de 40 u, `cast_shadow = OFF`, `visibility_range_end = lod`, `lod_bias = 0.65`, margem 20, sem fade. Ou seja, **usa o sistema de LOD da mata** (as plantas entram em `_blocos_vegetacao_lod`), mas **não** a copa distante (`CopasDistantes.especie_do_bloco(nome)` só casa com nomes da mata).
- Réplica da geração (`paisagismo_sim.py`, mesmo hash do GDScript): 19 zonas → **3.026 pés** no máximo, **195 blocos**, **10,43 M de triângulos LOD0** se tudo aparecesse.
- Por pé (`glbstat.tsv`): bananeira_leve 5.219, piaçava_leve 5.894, cajueiro_leve 5.670, dendezeiro_leve 5.583, ingazeiro_leve 5.426, goiabeira 7.682 (modelo cheio), mamoeiro 5.087 (cheio), pitangueira_leve 3.788, taboa 2.256, pé de mandioca 1.772, pé de milho 2.001, capim 2.907 (!). Comentário do catálogo: "versões leves (~2.500 faces)" (`catalogo_assets.gd:323`); CHANGELOG: "de 12–16 mil faces para cerca de 5 mil".
- Cone de 90° dentro do alcance de LOD, LOD0 (`wedge.py`): praça mediana 1,97 M, máx 4,07 M; miolo oeste mediana 1,87 M; zona do Poente (bananal/milho/mandioca) até 3,7–5,3 M olhando para ela.
- O portão aceita `PES_MAXIMOS = 14000` e `TRIANGULOS_MAXIMOS = 45000000.0` (`tests/paisagismo.gd:36-37`), mais de 4× o que o gerador entrega hoje.
- Referência: 26/09, 60 FPS com 2,4–3,6 M de triângulos no quadro; 30/09, 19,6–28,8 FPS com 7–11 M (`VALE_VIVO_3D.md:121-165`). O paisagismo chegou depois dessa segunda medida.

**Mecanismo.** Triângulos e pequenos triângulos: cada pé de 4–7 mil triângulos a 60–150 u ocupa poucos pixels, e a GPU paga rasterização e quad overdraw por triângulo, não por pixel; o pré-passe de profundidade (Forward+) roda a geometria duas vezes (profundidade e cor). O LOD importado ajuda, mas o Godot escolhe o LOD **por instância do MultiMesh inteira** (um MultiMeshInstance3D), pela distância ao AABB do bloco de 40 u: o bloco onde a câmera está, e os vizinhos, ficam em LOD0 em todos os pés. O alcance de 230 u é grande: a névoa (0,0011/u) cobre só 22% a 230 u, então não esconde nada. Sem sombra (bom): o custo é geometria e pixel, não passada de sombra.

**Impacto.** Alto, possivelmente crítico (maior item do escopo). **Confiança média**: os 3.026 são limite superior (a mata ciliar sem filtro de rio infla a taboa 545 e as reservas tiram pés); o triângulo "real" depende do LOD de malha escolhido e só medição na GPU fecha.

**Correção proposta.**
- **Hoje (configuração, sem código):** em `data/paisagismo/receitas.json` baixar os `lod`: linhas 91, 105, 124, 165, 177, 181, 194, 207, 221 (230 → 150); linhas 139, 154 (roças 120 → 80); faixa da taboa (linha 173, 85 → 60) e faixa do meio (linha 175, 120 → 90); cerca (linha 74, 110 → 70); `LOD_DO_FORRO` (`paisagismo_vale.gd:41`, 90 → 45). Pelo `wedge2.py`: a mediana de triângulos LOD0 no cone cai de 1,97 → 0,94 M na praça, 1,87 → 1,28 M no miolo oeste, 2,10 → 1,14 M na roça do Poente (−35 a −52%), e o máximo cai 40–60%. O forro (capim etc.) quase não pesa em triângulos (≈ −1% na simulação), então **não é onde ganhar**.
- **Hoje (cena):** aumentar a propriedade `densidade` (`zona_de_flora.gd:14-16`) das zonas maiores (bananal da baixada do Poente 546 pés, milho e fumo 495, roça do Poente 321): `densidade = 1.5` dá 1/2,25 dos pés. Conferir o portão `vazias ≤ 35%` (hoje ~10%).
- **Estrutural (pós-entrega):** usar os modelos `*_longe` que já existem no catálogo (bananeira_longe 2.012 tri, cajueiro_longe 1.810, dendezeiro_longe 1.716, mangueira_longe 1.675...) como segunda camada de MultiMesh de ~60 u em diante, como `copas_distantes.gd` faz com a mata (−55 a −65% nas peças afastadas); refazer goiabeira e mamoeiro como `_leve`/`_longe`; trocar o teto do portão por um orçamento realista (≤ 3 M no quadro).

**Esforço.** Hoje: 15–30 min (editar JSON, rodar `tests/paisagismo.gd` e `tests/lod_vegetacao.gd`). Estrutural: 1 dia (segunda camada) + arte (goiabeira/mamoeiro).

**Risco.** Hoje: popping de vegetação a 150/80 u (a névoa não esconde); gates conferidos: nenhum fixa os `lod` do paisagismo (`tests/lod_vegetacao.gd:23-41` testa só `_multimesh_em_blocos` com `85.0` e o decalque a `0`); `tests/paisagismo.gd` cobra pés, pureza, vazio, reservas, troncos ≥ 300 e piaçavas ≥ 8 perto do píer (não dependem de `lod`). Estrutural: baixo-médio.

**Como medir.** Esconder `MultiMeshInstance3D` cujo nome começa com `Paisagismo` (filhos de `Cenario._region`) e comparar FPS/triângulos do painel do HUD em 3 posições (praça, bananal (−157,117), roça do Poente (−182,55)) olhando para a zona. Depois repetir com o JSON alterado.

---

### MUN-02 — O mundo é montado duas vezes (abertura e vale)

**Evidência.** `abertura.tscn:13-14` (`Cenario` com `world_builder.gd`) e `vale.tscn:15-16` (idem). `abertura.gd:1853` chama `TelaCarregamento.trocar_cena(get_tree(), GAME_SCENE, loading)`, que faz `change_scene_to_packed` (`tela_carregamento.gd:453-479`): a árvore da abertura é descartada e o `vale.tscn` instancia um `WorldBuilder` novo. Não há `reaproveit*`/cache de mundo (grep em `abertura.gd`, `tela_carregamento.gd`, `inicio.gd`, autoloads).

**Mecanismo.** `_montar` (`world_builder.gd:610-657`) refaz região, casas, árvores, luzes, `PaisagismoVale.planejar`+`plantar` etc. duas vezes por sessão de jogo. Atenua: `CatalogoAssets._cenas/_malhas/_pegadas/_troncos` são `static var` (`catalogo_assets.gd:359-360,567-570`), então a segunda montagem não relê GLB nem remede vértices; os recursos (texturas) ficam residentes porque `_cenas` segura os `PackedScene`. **Não** são reaproveitados: o planejamento do paisagismo (hash + reservas), a região, os nós, os MultiMesh, as colisões.

**Impacto.** Alto para carregamento (o jogador espera duas montagens, uma antes do menu e outra ao dar "jogar"); magnitude **não medida**: `medir_carregamento.gd --cena=abertura,vale` mostra as duas linhas do tempo.

**Correção proposta.**
- **Estrutural:** reaproveitar o mundo da abertura (mover o `Cenario` para o jogo ao dar "jogar") ou ter um modo "menu" do `WorldBuilder` que monte só o necessário ao sobrevoo (sem interiores, sem colisão, sem luzes noturnas) e deixar o pesado para a cena do jogo.
- **Hoje (barato, parcial):** cache estático do plano do paisagismo (ver MUN-10) e do resultado de `ComposicaoVale.ler`.

**Esforço.** Estrutural: 1–3 dias (o sobrevoo e a abertura leem `Cenario`: `abertura.gd:190-215,259-291`). Hoje: 1 função.

**Risco.** Estrutural alto (sobrevoo, save, portões `sobrevoo_livre*.gd`, `Lugares.registrar`). Hoje baixo.

**Como medir.** `medir_carregamento.gd --cena=abertura,vale` (já aceita) e comparar as etapas de mesmo nome; somar as duas colunas de "ms". Com `--precarregar=1` isolar IO.

---

### MUN-03 — Árvores nomeadas no modelo cheio, 2K, sem corte e com sombra

**Evidência.** `_arvore` (`world_builder.gd:1476-1500`) chama `CatalogoAssets.instanciar(especie, ...)` com a chave cheia: 50 árvores ≈ 618 mil triângulos, sendo 18 pitangueiras de 9.688 (174 mil), 5 mangueiras de 20.453 (102 mil), bananeiras 14.753, dendezeiros 15.014, ipês 15 mil. As texturas desses 14 modelos são 2K (107 MB de `ctex`). Existem `_leve` com 3,8–6,1 mil triângulos e **o mesmo raio de tronco** (9 espécies) no catálogo: pitangueira 0,25 (`catalogo_assets.gd:47`) = pitangueira_leve 0,25 (`:329`); bananeira 0,25 = 0,25; dendezeiro 0,4 = 0,4; mangueira 0,55 = 0,55; jaqueira 0,4 = 0,4; ipê_amarelo/roxo 0,3 = 0,3; pau_brasil 0,38 = 0,38; coqueiro 0,24 = 0,24. O cajueiro_leve não tem `tronco` (`:328`), então fica de fora. Nenhuma tem `visibility_range`; todas fazem sombra (padrão).

**Mecanismo.** Cada árvore é 1 desenho no pré-passe, 1 na cor e 1 em cada cascata de sombra que ela toca (até 4, `ceu_vale.gd:91-93`), a 9–20 mil triângulos cada, enquanto o far da câmera é 2.800 u. A copa é malha cheia onde a MultiMesh da mata já usa `_leve` e copas de longe.

**Impacto.** Médio (estimativa: 10–15 árvores visíveis × 12 mil × (2 + ~2,5 cascatas) ≈ 0,5–0,8 M de triângulos por quadro, sendo ~0,3–0,5 M evitáveis; VRAM −90 MB).

**Correção proposta.**
- **Hoje:** em `world_builder.gd:1488` e `:1490` trocar a chave do **modelo** (não a `especie` gravada em `_arvores_nomeadas`, que o almanaque, o corte e os bichos leem) pela `_leve` quando existir e o `tronco` for igual: tabela de 9 espécies acima. Conta: pitangueira −106 mil, mangueira −83, bananeira −38, jaqueira −32, dendezeiro −28, ipês −38, pau-brasil −10, coqueiro −19 = −354 mil; 618 mil → ≈ 264 mil (−57%) trocando só estas 9 espécies (cajueiro, embaúba, mata_alta/larga e gameleira ficam; com o cajueiro_leve seriam 224 mil, mas ele não tem `tronco`). Rodar `tests/colisoes_do_vale.gd`, `tests/colisao_das_arvores.gd`, `tests/composicao_vale.gd`.
- **Estrutural:** `visibility_range_end` (≈ 140 u) nas peças individuais pequenas e médias (ver MUN-06).

**Esforço.** 1–2 h com os portões. **Risco.** Médio-baixo: o visual muda (a copa leve é outra silhueta; é a mesma da mata e do paisagismo); `colisoes_do_vale.gd` mede o cilindro contra o eixo do tronco das árvores nomeadas (`:352`), então precisa passar de novo.

**Como medir.** Esconder as árvores nomeadas (nós direto sob `Cenario` com nome terminando em `Tripo` e começando por Pitangueira/Mangueira/...) e olhar triângulos e FPS; ou trocar uma espécie e comparar.

---

### MUN-04 — Texturas 2K em todas as construções e árvores nomeadas: 470 MB lidos, 179 MB só nas casas

**Evidência.** `carga_mun.py`: 117 GLB únicos, 470 MB de `ctex` + 26 MB de malha. Cada construção tem 8,0 ou 10,7 MB de VRAM (3 texturas 2048², `glbstat.tsv` mostra `2048x2048;2048x2048;2048x2048`); 20 chaves de construção = 179 MB. Regra do projeto (briefing e `docs/arte/ASSETS_TRIPO.md`): 2K só para construção de destaque, árvore nomeada e personagem; hoje **todas** as 25 construções são 2K. `CatalogoAssets.cena()` faz `load()` síncrono de cada GLB na primeira vez (`catalogo_assets.gd:383-395`), na linha principal.

**Mecanismo.** IO e descompressão de ~500 MB na thread principal durante a montagem (`_pausar` cede quadros só entre chamadas; um `load()` de 10 MB não é interrompido) + subida para a GPU + 470 MB de VRAM que competem com o resto (o projeto passou a 863 MB de `ctex`). Em tempo de execução, textura 2K de uma casa que ocupa poucos pixels longe é só pressão de cache de textura.

**Impacto.** Médio para carregamento e memória; baixo para FPS. **Confiança média** (o ganho em segundos só mede).

**Correção proposta.**
- **Hoje (configuração):** baixar para 1K (`process/size_limit=1024` nos `.import` das texturas extraídas) as 15 chaves de casa comuns, deixando 2K em igreja, capela, casa_taipa (herdada, Pedro, Zefa) e casarão: 179 MB → ~75 MB (estimativa: 11 chaves × 8 MB → × 1/4). Exige reimportar (o coordenador faz no editor ou por script).
- **Estrutural:** compartilhar atlas por família de casa (`casa_taipa_*` são 6 cores do mesmo modelo, 6 × 8 MB).

**Esforço.** Hoje 1 h (mais o reimport). **Risco.** Baixo para o código; visual: borrão de perto nas casas comuns, a julgar no jogo.

**Como medir.** `medir_carregamento.gd --cena=vale --precarregar=1` (lê os GLB em threads antes): a diferença do tempo da etapa "Erguendo as casas" é o IO; o contador de VRAM do HUD (`prototype_hud.gd`) antes/depois.

---

### MUN-05 — Materiais `doubleSided` em 100% dos GLB do Tripo (faces de trás desenhadas)

**Evidência.** `glbmat.py`: 262 de 262 materiais com `"doubleSided": true`, `alphaMode OPAQUE`. O importador glTF do Godot mapeia `doubleSided` para `cull_mode = CULL_DISABLED`. O código do projeto já corrige isso em 4 cascas: `interiores.gd:425-435` troca para `CULL_BACK` (`copia.cull_mode = BaseMaterial3D.CULL_BACK`) e a casa continua inteira.

**Mecanismo.** Com `CULL_DISABLED` a malha fechada de uma casa desenha também as faces internas/de trás no pré-passe de profundidade e na passada de sombra (a cor delas é rejeitada pelo teste de profundidade, mas o custo de vértice e de rasterização fica). Em casas, túmulos, pedras e móveis (malhas fechadas) isso pode chegar a 2× em passadas limitadas por geometria; em folhagem fina é necessário.

**Impacto.** Médio-baixo, **confiança baixa** (o ganho real só mede; depende de a passada ser limitada por vértice ou por pixel).

**Correção proposta.**
- **Estrutural (ou hoje se medir bem):** em `CatalogoAssets.instanciar` (`catalogo_assets.gd:399-426`), para chaves de `construcoes/`, `casas/`, `moveis/`, `aderecos/` fechados (pedras, túmulo, galinheiro), duplicar o material **uma vez por GLB** (cache) com `cull_mode = CULL_BACK` e `set_surface_override_material`. Árvores, plantas e malhas abertas (cerca, varal, rede, taboa) ficam como estão.

**Esforço.** 2–3 h. **Risco.** Médio: furos visuais em malhas abertas (varal, cerca, telhado fino); revisar peça a peça.

**Como medir.** Experimento: script que percorre os `MeshInstance3D` sob `Cenario` com nome terminando em `Tripo` e põe `cull_mode = BACK`; comparar FPS e `RENDER_TOTAL_PRIMITIVES_IN_FRAME` olhando para as casas da praça.

---

### MUN-06 — ~300 GLB individuais: sem corte por distância, todos com sombra, um desenho por passada

**Evidência.** Inventário acima: ~300 nós GLB exteriores (+45 GLB de móveis nos interiores, +30 de cercado se a obra estiver feita). Zero `visibility_range_*` fora de `geo_region_renderer`/`copas_distantes`/bichos (grep). Nenhum `cast_shadow` explícito exceto `comodo.gd:392`. `CatalogoAssets.instanciar` (`catalogo_assets.gd:399-426`) não duplica malha nem material (os `PackedScene` são compartilhados): 18 pitangueiras, 8 galinheiros, 20 varais, 12 túmulos, 19 pedras da lombada, 16 moitas e 49 recursos reaproveitam o mesmo recurso, mas o Forward+ **não junta** `MeshInstance3D` separados: cada um é um desenho por passada.

**Mecanismo.** Draw calls = nós visíveis × (pré-passe + cor + cascatas de sombra tocadas). **Estimativa:** se 40% dos ~300 GLB estão no frustum (~120) e ~80 blocos de MultiMesh também: ~200 desenhos × 2 passadas + ~120 × ~3 cascatas ≈ 760 desenhos por quadro; a ~5–10 µs de CPU por desenho no Godot, ≈ 4–8 ms de CPU no `i7-9750H` — sem contar o custo de GPU de sombra. Pequenos adereços (pote, moringa, cesto, machado, farinha, candeeiro) a 80+ u são invisíveis mas continuam entrando em todas as passadas.

**Impacto.** Médio (CPU de submissão e sombras), **confiança média-baixa** (sem medir os desenhos).

**Correção proposta.**
- **Hoje:** argumento opcional `alcance` em `CatalogoAssets.instanciar`: aplicar `visibility_range_end = alcance` (+ margem 6, `FADE_DISABLED`) nos `GeometryInstance3D` do nó para props pequenos (≤ 1,5 u: potes, moringa, cesto, machado, farinha, cacho, candeeiro, moitas, capim, pedra/pedras pequenas): ~70 u; médios (varal, galinheiro, cerca, túmulo, mastro): ~140 u; casas e árvores não. E `cast_shadow = OFF` nos pequenos (≤ 1 u): sombra de pote não se vê.
- **Estrutural:** MultiMesh para o que se repete e não precisa de clique (túmulos, varais, galinheiros, pitangueiras, pedras da lombada).

**Esforço.** Hoje 2–3 h. **Risco.** Baixo-médio: interiores usam `instanciar` (peça some se o alcance for pequeno e a câmera estiver dentro — passar `alcance` só nas chamadas exteriores); recursos coletáveis e bancadas dependem do visual na hora de bater (alcance ≥ 40 u basta).

**Como medir.** Esconder (`visible=false`) todos os filhos de `Cenario` cujo nome termina em `Tripo`, ver quanto o FPS sobe; depois só os pequenos.

---

### MUN-07 — Interiores sempre vivos (4 salas montadas na carga e visíveis o tempo todo)

**Evidência.** `interiores.gd:91-97,167-234`: `configurar` monta as 4 salas e `add_child(sala)`; nenhuma linha oculta a sala (só `por_dentro` troca `cast_shadow` do teto, `comodo.gd:382-392`, e só com câmera de cima). Cada sala: caixas de parede/forro/vigas/janela/batente (cada `_caixa` com malha = 1 `MeshInstance3D`), móveis GLB (cama 5.657 tri, fogão 5.694, oratório 4.811, banco 4.016 × N na igreja...), `ReflectionProbe` (`UPDATE_ONCE`, `box_projection`, `interior = true`, `comodo.gd:453-465`), `OmniLight3D` de lampião, velas, e um `SpotLight3D` por janela (`comodo.gd:538-548`; na igreja `quantas = floor((nave − 1)/2,6)` por lado). Tudo sem sombra, `light_cull_mask` restrito (`comodo.gd:471,487,544`), mas o `Comodo._process` roda em todo quadro (`comodo.gd:495-500`).

**Mecanismo.** Os desenhos e as luzes da sala entram no frustum sempre que a casca está à vista (por trás da parede, rejeitados na profundidade, mas o vértice e as sombras contam); `light_cull_mask` filtra por pixel, mas a luz continua no cluster (a vela de 6 u vaza para fora da casca). **Estimativa:** ~215 `MeshInstance3D` (~45 por casa, ~80 na igreja), ~170 mil triângulos e ~22 luzes no total; só pesa nas vistas que contêm a igreja ou as 3 casas abertas.

**Impacto.** Médio-baixo. **Confiança média.**

**Correção proposta.**
- **Hoje:** em `Interiores._process` (`interiores.gd:143-162`), `sala.visible = distancia_do_jogador < 35 u ou jogador/morador dentro`. `visible` não desliga a física, ao contrário de `process_mode = DISABLED` (que desliga a colisão do corpo): **não usar `process_mode`**. Cuidado com o Pedro e os moradores que entram (`passagem`, `marcar_os_corpos`): manter visível enquanto algum morador estiver dentro.
- **Estrutural:** montar a sala só quando o jogador chega perto (o `_medir` já é assíncrono).

**Esforço.** Hoje 1 h. **Risco.** Baixo-médio (a sala some junto com NPC dentro dela).

**Como medir.** `visible=false` em `Interiores/Interior_*` com o jogador a 40 u da igreja, olhando para ela.

---

### MUN-08 — `Dia.hora_mudou` emitido todo quadro: luzes de época e janelas reaplicadas 60×/s

**Evidência.** `dia.gd:109-119` (`_process` → `avancar` → `definir_hora` → `hora_mudou.emit(hora)`; `:154-158`). Ouvintes do escopo: `world_builder.gd:725-732` (`_aplicar_hora` → `_ceu.aplicar` e `_luzes.aplicar_hora`), `comodo.gd:553-562` (×4). `LuzesEpoca.aplicar_hora` (`luzes_epoca.gd:166-172`) chama `_atualizar(0.0)` que escreve `light_energy` e `visible` das 12 luzes e `emission_energy_multiplier` de 8 materiais, **mesmo de dia**; à noite `_process` chama `_atualizar(delta)` de novo (2× por quadro). `Comodo._acompanhar_o_dia` reescreve a cor do vidro e a energia de cada `SpotLight3D` de janela todo quadro.

**Mecanismo.** Cada `set` em luz/material é uma chamada ao `RenderingServer` que marca o objeto sujo e reenvia o buffer de uniformes; para 12 + ~13 luzes e ~20 materiais são centenas de chamadas inúteis por quadro (a hora anda 1 minuto de jogo a cada ~0,5 s em "Normal").

**Impacto.** Baixo (**estimativa** 0,05–0,2 ms por quadro no escopo; o céu, em outro escopo, escreve ~20 parâmetros de shader e do `Environment` todo quadro). **Confiança média.**

**Correção proposta.** **Hoje:** em `LuzesEpoca.aplicar_hora` e `Comodo._acompanhar_o_dia`, sair cedo se a intensidade/luz mudou menos que 0,002 desde a última aplicação (uma variável membro). Ou, melhor, em `Dia.definir_hora`, emitir só quando a hora cruza um degrau de 1 minuto de jogo.

**Esforço.** 30 min. **Risco.** Baixo (o `Dia` é compartilhado: HUD e áudio escutam; conferir `tests/` do relógio se mexer no `Dia`).

**Como medir.** Contador de chamadas de `_aplicar_hora` por segundo (deve ser = FPS hoje); `Performance.TIME_PROCESS` antes/depois.

---

### MUN-09 — Varredura de vértices em GDScript na montagem (`pegada`, `tronco`, `_em_metros`)

**Evidência.** `CatalogoAssets.colisao` chama `pegada(chave)` (`catalogo_assets.gd:504,577-599`) para peças "caixa" e `tronco(chave, size)` (`:483,608-626`) para peças "tronco"; ambos dependem de `_em_metros` (`:672-695`: `scene.instantiate()`, `surface_get_arrays` de todas as superfícies) e depois um laço GDScript sobre **todos os vértices** (`pegada`: `transformacao * vertice` por vértice; `tronco`: `CoqueiroCortado.medir_o_corte`, `coqueiro_cortado.gd:69-123`). Vértices: casas 13,8–16,4 mil, árvores 17–31 mil (`glbstat.tsv`). Cache por `chave` (pegada) e `chave@passo de 0,05` (tronco), então vira um custo por (modelo, escala). Além disso, `world_builder.gd:2331-2372` (`_raio_do_tronco`, `_pe_do_tronco`, gameleira: 21.757 vértices) roda 1× por montagem.

**Contas (estimativas).**
- Chaves de caixa instanciadas na carga ≈ 36 (16 casas × ~15 mil vértices + 20 outras × ~4 mil) ≈ 320 mil iterações × ~1,5 µs ≈ 0,5 s.
- Combinações (árvore, escala em passos de 0,05) ≈ 30 × ~20 mil vértices × ~2 µs ≈ 1,2 s (mangueira nos tamanhos 0,85/0,9/1,0/1,1/1,15, cajueiro 0,9/1,0/1,05, mata_alta 0,9/1,0/1,05...).
- `_em_metros` (instanciar + `surface_get_arrays`) ≈ 66 chamadas × ~3–5 ms ≈ 0,2–0,3 s.
- Total ≈ **1,5–2 s** de linha principal na primeira montagem da sessão; a segunda reaproveita os caches estáticos.

**Impacto.** Médio-baixo para carregamento (uma fração do tempo total; **estimativa**, confiança média-baixa).

**Correção proposta.** **Estrutural:** gravar essas medidas (pegada em fração da caixa, `tronco`/`eixo` por chave e escala) em um JSON gerado por ferramenta (`tools/`) e lido na carga; o portão `colisoes_do_vale.gd` já confere a caixa/cilindro contra o desenho, então serve de prova de que o JSON está certo. **Hoje:** nada de baixo risco.

**Esforço.** 0,5–1 dia. **Risco.** Médio (medidas estagnam se o GLB mudar; regerar pela ferramenta).

**Como medir.** `Time.get_ticks_usec()` ao redor de `CatalogoAssets.colisao` somado por chamada (ou o profiler do Godot por função).

---

### MUN-10 — Planejamento do paisagismo refeito a cada montagem (e a cada abertura)

**Evidência.** `world_builder.gd:808-816`: `ler_receitas`, `PaisagismoVale.ler` (instancia a cena de zonas), `planejar` (`reservas_do_mundo` percorre **todo** `regiao._tree_trunks`, `paisagismo_vale.gd:507-512`, monta círculos e a grade; `aderecos`; `gerar` com ~11 mil candidatos e 6 `ruido` por candidato), `plantar` (3 mil `ground_height_at`, 195 `_multimesh_em_blocos`, 1.207 entradas em `_tree_trunks`). Tudo síncrono, sem `_pausar`, numa só etapa ("Plantando as árvores da vila", fração 0,975).

**Mecanismo.** GDScript puro: por candidato ≈ 6 chamadas de hash (~1,5 µs cada) + `_tentar` + `bloqueado` com 4 `Callable` (terra: `is_point_in_polygon` contra `_land`; rua; costa; rio) ≈ 30–50 µs. **Estimativa** 11.185 × 40 µs ≈ 0,45 s + reservas ~0,1 s + plantio ~0,1 s ≈ **0,5–1,2 s por montagem**, o dobro com MUN-02. O resultado é determinístico por construção (`paisagismo_vale.gd:13-18`).

**Impacto.** Médio-baixo no carregamento. **Confiança média-baixa** (estimativa).

**Correção proposta.** **Hoje:** `static var` com o plano (`plantas` e `aderecos`), chave = hash das zonas + posições das casas (`_house_sites`) + das nomeadas; a segunda montagem usa o cache. **Estrutural:** pré-assar offline (JSON) com a ferramenta que já existe para o sobrevoo.

**Esforço.** Hoje 1–2 h. **Risco.** Baixo-médio (cache velho se a composição mudar entre montagens; a chave resolve; o portão `paisagismo` roda `gerar` de novo e continua testando a função pura).

**Como medir.** Tempo da etapa 0,975 em `medir_carregamento.gd` (sem `_construir_vila` anterior) antes/depois.

---

### MUN-11 — 23 Decals de terreiro sem desvanecimento por distância

**Evidência.** `composicao_vale.tscn`: 23 nós `Terreiro` (Decal); `world_builder.gd:904-909` os instancia a partir de `terreiro_casa.tscn` (textura 1K, `upper_fade 0,15`, `lower_fade 0,3`, `normal_fade 0,5`, sem `distance_fade_enabled`, `cull_mask` padrão). Cada um cobre ~9,7 × 8,8 u e 2,4 u de altura, tocando terreno, alicerce e paredes.

**Mecanismo.** No Forward+ cada Decal é um elemento clusterizado: todo fragmento nos clusters que ele toca (terreno, casa, vegetação) executa o laço de decals no shader. Como o shader do terreno é grande, o custo por pixel nessas áreas sobe. **Estimativa:** pequeno por Decal; fica visível só com muitos na tela.

**Impacto.** Baixo-médio, **confiança baixa**.

**Correção proposta.** **Hoje:** `distance_fade_enabled = true`, `distance_fade_begin = 60`, `distance_fade_length = 20` em `terreiro_casa.tscn` (1 propriedade); alvo opcional: `cull_mask` só da camada do terreno. **Risco** baixo (visual a 60–80 u). **Esforço** 10 min.

**Como medir.** Esconder `Terreiro *` (`find_children("Terreiro *", "Decal")`) olhando para o arraial.

---

### MUN-12 — Cômodos: `Shader` duplicado por chamada e esperas de física na carga

**Evidência.** `comodo.gd:725-732` (`_shader`) cria um `Shader.new()` com o mesmo código a **cada** `_cal(`, `_lajota(`, `_tabua(`, `_terra_batida(`, `_telha_va(`: ~11 `_cal` + 1 piso + 1 forro por casa, ~12 na igreja (`comodo.gd:188-269`, `interior_casa.gd:126-152`, `interior_igreja.gd:94,114,136`) → ~50 `Shader` resources com ~6 códigos distintos. `StandardMaterial3D` (`_cor`) já compartilha o shader por chave de recursos do Godot; `ShaderMaterial` com `Shader` novo, não. E `interiores.gd:294-295` espera 2 `physics_frame` por sala (8 no total, em série, `prototype.gd:246`), mais 4 `create_trimesh_shape` da casca (10–13 mil triângulos cada).

**Mecanismo.** Cada `Shader` próprio vira uma versão de `ShaderRD` e seus próprios pipelines (o cache em disco por hash reduz a recompilação, mas não a criação nem os pipelines); aparece como carga e como primeira compilação ao entrar à vista. As esperas de física custam quadros de 80 ms durante a carga.

**Impacto.** Baixo (carregamento/travada na primeira vista de cada casa), **confiança baixa**.

**Correção proposta.** **Hoje:** cache `static var _shaders: Dictionary` por código em `_shader()` e um `ShaderMaterial` por cor (função única, `comodo.gd:725-732`). **Risco** baixo. **Esforço** 20 min.

**Como medir.** Contar `Shader` vivos (`Performance.RENDER_TOTAL_OBJECTS...`/monitor) e o tempo de `_abrir` por sala.

---

### MUN-13 — Navegação assada duas vezes na carga por causa da ponte cercada (e do cercado do cemitério)

**Evidência.** `navegacao_vale.gd:75-117,155-183`: a 1ª malha assa em `configurar` (`prototype.gd:251-254`); `PonteVale.configurar` (`prototype.gd:669-672`) começa com a ponte cercada (`ponte_vale.gd:76-86,110-125`) e chama `navegacao.reassar()`; com a assada em curso, `_de_novo = true` e uma 2ª assada sai logo depois (`:101-107,232-234`). O cercado do cemitério (`cemiterio_vale.gd:142-160`) também pede `reassar()` quando a obra está feita. `_troncos_da_mata` percorre **todos** os troncos (inclusive os 1.207 do paisagismo) em GDScript e chama `base_do_tronco` (`:155-183`).

**Mecanismo.** O próprio comentário mede ~1,7 s de assada em linha de execução à parte e ~50 ms de leitura na principal (`navegacao_vale.gd:10-15`), mas a assada concorre com a montagem e a subida de textura; duas assadas em fila dobram. **Impacto** baixo no FPS, baixo-médio na espera ao fim da carga. **Confiança baixa.**

**Correção proposta.** **Hoje:** em `PonteVale.configurar`, não chamar `reassar()` se a navegação ainda não está pronta (a 1ª já pega o estado); só reassar quando `Navegacao.esta_pronta()`. **Esforço** 20 min. **Risco** baixo (conferir o portão da ponte).

**Como medir.** Contador `versao` de `NavegacaoVale` ao fim da carga (hoje esperado ≥ 2).

---

### MUN-14 — Pool de colisão de troncos a 4 Hz com os troncos densos do paisagismo

**Evidência.** `geo_region_renderer.gd:2426-2434,2456-2520`: a cada `TREE_COLLISION_INTERVAL = 0,25 s` `troncos_para_o_conjunto` percorre as células num raio de 28 u (`TREE_COLLISION_RADIUS`), cria um `Dictionary` de 10 campos por tronco, chama `base_do_tronco` e `sort_custom(_collision_nearer)`; o pool é 48. O paisagismo soma 1.207 troncos (`paisagismo_vale.gd:672-677`), muito densos no bananal (546 pés em 4.642 u² ≈ 0,12/u²).

**Mecanismo.** Dentro do bananal um raio de 28 u (2.463 u²) tem ~290 candidatos: ~290 dicionários + ordenação por quarto de segundo. **Estimativa** 2–4 ms a cada 15 quadros (um engasgo periódico de 4 Hz, não queda sustentada). **Impacto** baixo (travadas); **confiança baixa**.

**Correção proposta.** **Estrutural:** guardar `base_tronco` no dicionário de origem e só ordenar os 48 mais perto (seleção parcial); ou reduzir `TREE_COLLISION_RADIUS` de 28 para ~16 (a vaga é 48; o portão `colisao_das_arvores.gd` cobra que "nenhum tronco ao alcance fique sem corpo": rodar antes). **Esforço** 2 h. **Risco** médio (portão).

**Como medir.** Picos de `Performance.TIME_PROCESS` a 4 Hz dentro do bananal.

---

### MUN-15 — O portão de orçamento do paisagismo é largo demais e não pega esta regressão

**Evidência.** `tests/paisagismo.gd:36-37` (14.000 pés, 45 M de triângulos). Hoje o gerador dá ≤ 3.026 pés e 10,4 M: o portão passaria com folga, mesmo que o vale caísse de 60 para 15 FPS. A medição de 30/09 já mostrava 19,6–28,8 FPS com 7–11 M no quadro.

**Correção proposta.** Trocar o teto por um orçamento no cone de câmera (ex.: ≤ 2 M de triângulos LOD0 por vista, no pior de 12 direções a partir de 5 pontos), reaproveitando a conta de `wedge.py`. **Esforço** 2–3 h. **Risco** nenhum para o jogo. **Como medir:** o próprio portão.

---

## O que está OK

Conferido, com número, para ninguém reinvestigar:

- **Paisagismo usa o sistema de LOD da mata** (MultiMesh em blocos de 40 u, `visibility_range_end`, margem 20, `lod_bias` 0,65, `cast_shadow OFF`, importador com LODs): `paisagismo_vale.gd:682`, `geo_region_renderer.gd:2139-2197`. Não é um GLB por planta.
- **Sem duplicação de material/malha por peça**: `CatalogoAssets.instanciar` só faz `scene.instantiate()` do `PackedScene` em cache (`catalogo_assets.gd:383-426`); sem `make_unique`/`duplicate()` por instância no escopo, exceto `Interiores._casca_so_por_fora` (4 construções, 1 cópia de material por superfície, `interiores.gd:425-435`). `_box`/`_mesh` reaproveitam material por cor (`world_builder.gd:2202-2216`) e a lavoura compartilha o material de terra (`lavoura_vale.gd:209-236`).
- **Colisão barata**: caixa ou cilindro por peça; trimesh só no píer e nas 2 pontes (3 corpos, ~12 mil triângulos cada) e 4 trimesh provisórios de medida liberados (`catalogo_assets.gd:460-464`; `interiores.gd:286,374`). Nenhuma colisão por trimesh sobre GLB de casa ou árvore.
- **`_raio_do_tronco` e `_pe_do_tronco`** rodam 1× por montagem, só na gameleira (`world_builder.gd:2434,2442`); `_node_bounds` e `_contar_triangulos` **não são chamados** em jogo (`_contar_triangulos` só com `COMPARAR_MANGUEIRAS = false`, `world_builder.gd:27,2066`).
- **Luzes**: 12 omni sem sombra, só à noite, com alcance de 3,5 a 9 u; partículas só 4 sistemas de 88 pés (`luzes_epoca.gd`). Interiores: ~22 luzes sem sombra, `light_cull_mask` restrito. Nenhuma `SpotLight3D`/`OmniLight3D` com `shadow_enabled` no escopo.
- **Label3D**: 21 de casa criados invisíveis, texto só ao passar o mouse (`world_builder.gd:1342-1352`); sem atualização de texto por quadro; sem `no_depth_test`/`fixed_size`.
- **Scripts por quadro do escopo**: 19 nós, todos com laços curtos (túmulos 12, marcos ~10, achados poucos, recursos 49, árvores por quadra de 16 u, lugares de bancada 3); `Interiores._process` testa 4 salas (`interiores.gd:143-162`); `PlacasNomes._process` itera 22 moradores com `reset_size()` só dos < 22 u (`placas_nomes.gd:30-50`, ~0,3–0,5 ms estimados). Cada um ≤ ~0,1 ms; ~1 ms no total (estimativa). `Fazenda`, `Lombada`, `Ponte`, `Cemitério` conferem a cada 0,25–0,5 s, não por quadro.
- **`ComposicaoVale.ler`** instancia 120 nós uma vez; scripts `@tool` da composição só trabalham no editor (`casa_composicao.gd:42-48`, `peca_composicao.gd`, `composicao_editor.gd:20-22` guardados por `Engine.is_editor_hint()`); `terreno_editavel.tscn` (15,6 MB) e `ruas_referencia.tscn` (7,2 MB) **não são carregados em jogo** (só o editor).
- **Plantas MultiMesh sem sombra e sem colisão por instância**: o corpo vem do pool de 48 cilindros (`geo_region_renderer.gd:2563-2580`).
- **Frustum culling funciona** em todos os nós individuais (AABB próprio); o que falta é corte por distância, não por tela.
- **Nenhuma `ReflectionProbe` fora dos 4 cômodos, nenhum `LightmapGI`/`VoxelGI`/`FogVolume`/`OccluderInstance3D`** no projeto (grep em `scripts/`); `UPDATE_ONCE` nas sondas dos cômodos.
- **Câmera/colisões**: camadas e braço da câmera (`camadas.gd`) estão bem separados e há portões (`colisoes_do_vale.gd`, `colisao_das_arvores.gd`).

---

## Dúvidas para medição A/B

O coordenador mede na GPU (GTX 1660 Ti Max-Q, 1920×1080 tela cheia, MSAA 2×). As receitas abaixo escondem nós por **prefixo de nome** sem tocar em arquivo; rodar no jogo (console remoto/`MCPRuntime`) com a mesma câmera e a mesma hora (9h, `Dia` parado) e anotar FPS, `RENDER_TOTAL_PRIMITIVES_IN_FRAME` e `RENDER_TOTAL_DRAW_CALLS_IN_FRAME` (o painel do HUD já mostra tri/draws).

Pontos de câmera sugeridos (unidades do mundo, olhando para o centro da zona): praça (0, 0); bananal (−157, 117); roça do Poente (−182, 55); miolo oeste (−40, 30); igreja (para MUN-07); um ponto sobre o sobrevoo do píer.

1. **MUN-01 — paisagismo.** `for n in mundo._region.find_children("*", "MultiMeshInstance3D", true, false): if n.name.begins_with("Paisagismo"): n.visible = false` (nome dos nós: `"Paisagismo: <espécie> <lod> <bx>,<bz>"`; o Godot pode trocar `:`; basta `begins_with("Paisagismo")`). Variantes: só `cerca_varas`; só LOD 90 (forro); só `bananeira_leve`. Esperado: queda de triângulos de ~2 M (praça) para ~0,1 M; se o FPS não subir, o gargalo não é geometria do paisagismo.
2. **MUN-06/03 — GLB individuais.** `for n in mundo.get_children(): if n.name.ends_with("Tripo"): n.visible = false` (nome `chave.capitalize() + "Tripo"`, `catalogo_assets.gd:413`). Variantes: só árvores (nomes de espécie); só adereços; só casas (`Casa*`).
3. **Sombras de tudo.** `mundo._sun.shadow_enabled = false` (nó `Sol`, `ceu_vale.gd:90-93`) e `directional_shadow_max_distance` 180 → 90. Isola o custo das 4 cascatas sobre os ~300 GLB (cruza com o escopo de sombra do céu).
4. **MUN-07 — interiores.** `for s in get_tree().get_nodes_in_group("interiores")[0].get_children(): s.visible = false` (nós `Interior_*`). Olhando para a igreja.
5. **MUN-11 — decals.** `for d in mundo.find_children("Terreiro *", "Decal", true, false): d.visible = false`.
6. **Luzes de época.** `mundo.get_node("LuzesDeEpoca").visible = false` à noite (hora 21h): custo das 12 omni + partículas.
7. **MUN-05 — faces de trás.** Percorrer `MeshInstance3D` filhos diretos de `Cenario` (`*Tripo`), duplicar o material de cada superfície com `cull_mode = BaseMaterial3D.CULL_BACK` e `set_surface_override_material`; comparar FPS/primitivas olhando para a praça.
8. **Carregamento.** `medir_carregamento.gd --cena=abertura,vale` (duas linhas do tempo, MUN-02), `--cena=vale --precarregar=1` (IO dos 470 MB, MUN-04), sem `--headless` para ver textura/shader. Comparar as etapas por fração: 0,8 "Erguendo as casas", 0,86 "Plantando as árvores da vila" (árvores nomeadas), 0,89, 0,93, 0,975 (paisagismo + bases das árvores). Somar o tempo de `CatalogoAssets.colisao` (MUN-09) com `Time.get_ticks_usec()` se o 0,8 for grande.
9. **Gotejamento por quadro.** Contar chamadas de `_aplicar_hora` por segundo (esperado = FPS) e `NavegacaoVale.versao` ao fim da carga (esperado ≥ 2).
10. **Fator do cone.** Para validar a conta de `wedge.py`: no ponto da praça, apontar para o oeste (−x) e para o leste (+x): se o oeste for muito mais lento que o leste, o paisagismo é o responsável (a zona do Poente fica em x < −100).
