# Anexos da investigação de desempenho de 05/10/2026

O relatório é [../DESEMPENHO_05_10_2026.md](../DESEMPENHO_05_10_2026.md). Esta pasta guarda a prova: os dados brutos, as fotos, os relatórios por subsistema e as ferramentas.

A pasta tem um `.gdignore`: o editor do Godot não a importa (as fotos não viram textura, o `medir_fps.gd` não vira script do projeto) e ela não entra na build, que já exclui `docs/*`.

Nada aqui altera o jogo. Os caminhos do disco do autor foram trocados por `%USERPROFILE%` e `<rascunho>`.

## dados/

| Arquivo | O que é |
|---|---|
| `carga_frio.json`, `carga_quente.json` | Saída de `tools/prototipo_3d/medir_carregamento.gd --cena=abertura,vale`, com perfil novo (sem cache de shader) e com os caches do autor. Etapas, quadros, maiores congelamentos, contagem de nós |
| `fps1_vistas.json` · `.txt` · `.log` | **A linha de base**: censo da cena e 128 vistas (16 lugares × 8 rumos), tela cheia 1080p, como se joga |
| `fps1_censo.txt` | O censo legível: classes, scripts que rodam por quadro, luzes, maiores malhas, peças do catálogo, os 76 grupos de vegetação |
| `fps1b_repeticao.json` | Segunda rodada sem nenhuma mudança, em 6 lugares: mede a repetibilidade |
| `fps2.json` · `fps2_resumo.txt` · `.log` | A/B de CPU na praça (um script desligado por vez), A/B de GPU dentro da igreja (72 alternâncias), horas do dia, V-Sync e o passeio (`passeio.serie_ms` tem o tempo de cada quadro) |
| `fps3.json` · `.log` | Experimento do cache da costa (remendo só em memória): montagem e 48 vistas; A/B do descarte de faces de trás |
| `fps4.json` · `.log` · `comparacao_pacote2.md` | Fotos com medida por variante (`fotos`) e a volta completa com o **Pacote 2** aplicado em memória |
| `fps5.json` · `fps5_ab.txt` · `.log` · `comparacao_pacote1.md` | A/B de sombras ao ar livre (lavoura) e a volta completa com o **Pacote 1** |
| `casa185_1_vistas_abgpu.json` · `gpu_casa185_1.csv` | #185: vistas fora e dentro da casa herdada e o A/B de GPU das hipóteses da issue |
| `casa185_2_porta_antes.json` | #185: travessias da porta com o `por_dentro` antigo e a sombra de 70 u (restaurados só durante a rodada) |
| `casa185_3_entrada_abcpu.json` | #185: a entrada da chegada reproduzida (3 FPS no passo do baú) e o A/B de CPU dentro da casa |
| `casa185_4_depois.json` · `gpu_casa185_4.csv` | #185: a mesma entrada, a porta e a casa, a igreja e o casarão depois da correção |
| `gpu_fps1.csv` … `gpu_fps5.csv` | `nvidia-smi` a cada 2 s durante cada rodada: memória, uso, temperatura, potência, relógio, estado de energia |

Como ler um JSON de FPS: cada vista ou medida traz `fps`, `quadro_ms`, `rs_gpu_ms` (GPU da tela), `sub_gpu_ms` (GPU dos `SubViewport`), `rs_cpu_ms` (desenho na CPU), `process_scripts_ms`, `fisica_scripts_ms` (somado no quadro), `fisica_passos_por_quadro`, `fisica_servidor_ms`, `primitivas` (triângulos de todas as passadas) e `draws`. O custo de um tick de física é `fisica_scripts_ms / fisica_passos_por_quadro`.

Nos A/B, `ganho_ms` é quanto o quadro encurtou com a mudança, contra a média das duas bases medidas antes e depois dela.

## fotos/

A mesma vista, com os scripts congelados, com e sem cada ajuste. Nome: `<lugar>_<rumo>_<variante>.jpg`.

| Variante | O que foi trocado (só na memória) |
|---|---|
| `base` | nada |
| `cull_back` | faces de trás descartadas em todos os materiais dos modelos |
| `mata_x050`, `mata_x035` | distâncias de corte da vegetação multiplicadas por 0,5 e por 0,35 |
| `pacote_B` | sem MSAA + FXAA + sombra a 60 u + atlas 2048 + minimapa parado + mata × 0,5 |
| `pacote_C` | B + peças GLB com corte a 120 u + limiar de LOD 4 px + FSR1 0,77 |
| `pacote_D` | como C, com mata × 0,35, LOD 8 px e FSR1 0,67 |

Estão aqui 16 das 40 fotos tiradas. A vista "igreja" é dentro da igreja; a "casa_de_taipa" é dentro da casa do jogador, com a câmera de cima.

## subsistemas/

Relatórios de leitura de código, um por tema, feitos em paralelo e sem rodar o jogo. Trazem os números de linha, as contas e as correções propostas com esforço e risco. Onde uma estimativa deles e uma medida do relatório principal divergem, vale a medida.

| Arquivo | Tema | Identificadores |
|---|---|---|
| `vegetacao.md` | Terreno, mata, LOD e corte por distância | `VEG-01` … `VEG-12` |
| `vivos.md` | Moradores, bichos, peixes, animação e scripts por quadro | `VIV-01` … `VIV-13` |
| `render.md` | Configuração de render, céu, luz, sombra, mar e shaders | `REN-01` … `REN-16` |
| `mundo.md` | Vila, construções, paisagismo, adereços, interiores, colisão | `MUN-01` … `MUN-15` |
| `assets.md` + `assets_glb.csv` | Inventário dos 262 GLBs e das texturas | `AST-01` … |
| `hud.md` | Laço do jogo, HUD, minimapa, `SubViewport`, autoloads | `HUD-01` … `HUD-13` |
| `carregamento.md` | Do duplo clique até andar | `CAR-01` … `CAR-13` |
| `historico.md` | O que já foi otimizado, o que entrou depois, commit a commit | — |

## ferramentas/

| Arquivo | O que faz |
|---|---|
| `medir_fps.gd` | O medidor (um `SceneTree` para `--script`). Sobe o vale, faz o censo, mede vistas, roda os A/B, aplica pacotes em memória e tira fotos. As opções estão no cabeçalho |
| `rodar_godot.ps1` | Lança o Godot com janela num perfil isolado (`APPDATA`), grava o log e, se passar do teto, encerra só o PID que levantou |
| `resumo_fps.py` | Imprime um JSON de medida em tabelas |
| `comparar.py` | Compara a volta de uma rodada com a linha de base, lugar a lugar |

Exemplos (a partir da raiz do projeto, com janela, nunca `--headless`):

```
# volta completa, para comparar depois de uma correção (~5 min)
Godot_v4.7.2-stable_win64_console.exe --path . --script docs\projeto\desempenho_05_10_2026\ferramentas\medir_fps.gd -- --saida=depois.json --lugar=praca --tela=cheia --fases=censo,vistas
python docs\projeto\desempenho_05_10_2026\ferramentas\comparar.py docs\projeto\desempenho_05_10_2026\dados\fps1_vistas.json depois.json

# A/B de GPU numa vista escolhida
... -- --saida=ab.json --lugar=praca --fases=censo,abgpu --ab_gpu_em=mirante:270

# a casa herdada por dentro (#185): vista da soleira e de dentro (com a câmera de cima), e o A/B das hipóteses da issue
... -- --saida=casa.json --lugar=praca --fases=censo,vistas,abgpu --lugares=praca,porta:casa,dentro:casa --rumos=4 --ab_gpu_em=dentro:casa:135 --so=casa:

# experimentos em memória (não mexem no projeto)
... -- --saida=x.json --lugar=praca --fases=vistas --patch_costa=1 --aplicar=passos3,minimapa_6hz,msaa0_fxaa,sombra60,atlas2048,cull_back,mata050
```

Três cuidados que custaram tempo nesta investigação:

1. **Perfil isolado em caminho curto.** O cache de shader do Godot cria pastas com nomes de 64 caracteres; num perfil dentro de um caminho longo ele estoura o limite de 260 caracteres do Windows e o motor avisa "Unable to create shader cache directory". Use um caminho curto (por exemplo, uma unidade criada com `subst`).
2. **Importar antes de medir.** Depois de um merge com assets novos, rode o editor (ou `--headless --editor --import`) antes: sem os arquivos importados o `geo_region_renderer.gd` não compila e o vale não monta.
3. **O medidor não roda no modelo de exportação *release*:** esse binário recusa `--path`. Para medir a build exportada, use o FPS do HUD e um cronômetro.

Depois de corrigido o cache da costa no projeto, `--patch_costa=1` passa a responder "nao achei a funcao" e deixa de ser necessário.

## Casa herdada (#185): medida em 08/10

GTX 1660 Ti Max-Q em P0 durante todas as rodadas (`gpu_casa185_*.csv`; P8 só antes de o vale subir e depois de fechar), tela cheia 1080p, 18 h (o entardecer da sessão do testador), V-Sync desligado.

**A queda não vinha da casa, e sim do passo do baú.** Na sessão do testador de 07/10 (`tools/temp/jev/20261007-232930-759af9`), o HUD marcava 57 FPS logo depois de entrar (521 s) e caiu a 2–3 quando o Pedro passou ao passo `pegar` ("Pegue no baú a enxada, o balde e a maniva"). Voltou a 60 no quadro em que o passo fechou (551 s). A fase `entrada` do medidor reproduz isso. Ela põe a chegada no passo `casa`, fecha as falas e entra andando:

| Janela de 3 s (`casa185_3`, `casa185_4`) | FPS | física dos scripts por quadro | passos de física por quadro | GPU | draws | primitivas |
|---|---|---|---|---|---|---|
| Na soleira, passo `casa` | 116 | 1,1 ms | 0,5 | 5,4 ms | 525 | 1,65 M |
| Dentro, passo `pegar`, **antes** | 3,4–3,6 | 273–293 ms | 5,0 (o teto) | 29–38 ms* | 350 | 0,80 M |
| Dentro, passo `pegar`, **depois** | 100–124 | 1,8–2,5 ms | 0,5 | 3,7–4,4 ms | 220–350 | 0,50–0,80 M |

\* Com a física em espiral, o tempo de GPU medido inclui a espera do quadro. O desenho dentro de casa é mais leve que na soleira.

O A/B de CPU dentro da casa (`casa185_3`, 20 alternâncias) acha o culpado. Desligar todos os scripts leva a 184 FPS. Desligar só o `cadeia_de_missoes.gd` leva a 128 FPS. Nenhum outro script passa de 10 ms. A cadeia do Pedro custava **54 ms por tick**, todos em `_acertar_o_caderno` → `posicao_do_passo`. O passo `juntar` pergunta a cada tick onde está a fonte de cada item que falta, e `ArvoresInfo.mais_perto_que_rende` dava uma volta por todas as árvores do vale, com um `madeira_de` (molde duplicado) em cada uma. Para enxada, balde e maniva, que árvore nenhuma rende, eram três voltas por tick, sem achar nada. A 54 ms por tick, a física faz os 5 passos do teto a cada quadro, e o quadro passa de 280 ms. **Correção:** a busca escolhe antes as espécies que rendem o item; sem nenhuma, a resposta sai sem olhar árvore. A cadeia passou a 1,0 ms por tick. `tests/alvo_de_madeira.gd` cobra três perguntas com 50 mil árvores: 583 ms antes, abaixo de 5 ms depois.

**As hipóteses da issue, medidas** (`casa185_1`, A/B de GPU dentro da casa, rumo 135°, scripts congelados, base 178 FPS / 4,9 ms de GPU):

| Alternância | Ganho |
|---|---|
| casca e teto escondidos (`visible = false`) em vez de `SHADOWS_ONLY` | +0,04 ms (nada) |
| casca e teto sem projetar sombra | −0,67 ms |
| sol sem sombra | −0,42 ms |
| luzes do cômodo escondidas (3) | −0,45 ms |
| sonda de reflexo escondida | −0,34 ms |
| `far` da câmera a 60 u | −0,10 ms |
| sombra do sol de volta a 70 u (antes do 9b3966e) / a 12 u | +0,06 / +0,03 ms (nada) |

Nenhuma passa de 0,7 ms. A câmera de cima não enxerga o vale: 350 draws dentro contra 520–1.080 na soleira.

**A porta** (fase `porta`, 1,5 s da soleira ao meio do cômodo e de volta; `casa185_2` com perfil novo, sem cache de shader). Pior quadro de 14 a 36 ms; o quadro da troca de lado fica entre 6 e 16 ms. É assim com e sem o `por_dentro` antigo (`casa185_2`, que restaurou a varredura e a sombra de 70 u só na memória da rodada), então o tranco que a issue suspeitava não aparece em número.

**Fora × dentro, depois da correção** (`casa185_4`, pior rumo de 4, passo `pegar` em curso):

| Lugar | Fora (soleira) | Dentro |
|---|---|---|
| Casa herdada (câmera de cima) | 98 FPS, 771 draws, 1,71 M prim., GPU 5,9 ms | 115 FPS, 356 draws, 0,80 M prim., GPU 4,5 ms |
| Igreja (câmera de passeio) | 61 FPS, 914 draws, 1,77 M prim., GPU 5,4 ms | 65 FPS, 1.144 draws, 2,12 M prim., GPU 5,8 ms |
| Casarão (câmera de cima) | 89 FPS, 907 draws, 1,41 M prim., GPU 5,0 ms | 91 FPS, 279 draws, 0,56 M prim., GPU 4,0 ms |
| Praça, para comparar | 23 FPS (rumo 0°, física 29 ms) | — |

Para repetir:

```
... -- --saida=entrada.json --lugar=praca --passo=casa --fases=entrada,porta,vistas --porta_de=casa --hora=18 --rumos=4 --lugares=porta:casa,dentro:casa,porta:igreja,dentro:igreja,porta:casarao,dentro:casarao
... -- --saida=ab.json --lugar=praca --passo=casa --fases=entrada,abcpu --hora=18 --ab_cpu_em=dentro:casa:135 --so="script:|CPU:|fisica:"
```

Com `--passo=casa` e `--lugar=casa_de_taipa`, o jogador já começa dentro da casa e a árvore do jogo fica pausada durante a rodada. As vistas saem com `pausado: true` e não valem. Comece em `--lugar=praca`.
