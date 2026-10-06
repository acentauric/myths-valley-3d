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

# experimentos em memória (não mexem no projeto)
... -- --saida=x.json --lugar=praca --fases=vistas --patch_costa=1 --aplicar=passos3,minimapa_6hz,msaa0_fxaa,sombra60,atlas2048,cull_back,mata050
```

Três cuidados que custaram tempo nesta investigação:

1. **Perfil isolado em caminho curto.** O cache de shader do Godot cria pastas com nomes de 64 caracteres; num perfil dentro de um caminho longo ele estoura o limite de 260 caracteres do Windows e o motor avisa "Unable to create shader cache directory". Use um caminho curto (por exemplo, uma unidade criada com `subst`).
2. **Importar antes de medir.** Depois de um merge com assets novos, rode o editor (ou `--headless --editor --import`) antes: sem os arquivos importados o `geo_region_renderer.gd` não compila e o vale não monta.
3. **O medidor não roda no modelo de exportação *release*:** esse binário recusa `--path`. Para medir a build exportada, use o FPS do HUD e um cronômetro.

Depois de corrigido o cache da costa no projeto, `--patch_costa=1` passa a responder "nao achei a funcao" e deixa de ser necessário.
