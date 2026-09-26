# Assets 3D com o Tripo Studio — o fluxo oficial do protótipo 3D

Decisão de 26/09/2026: **o modo Tripo é a linha mestra dos assets 3D**. Tudo que
tem identidade (casas, árvores nomeadas, personagens, itens, mobília, bichos)
vem do Tripo Studio; o motor continua responsável pelo que precisa seguir o mapa
(terreno, ruas, rios, mar) e pela massa repetida em `MultiMesh` (mata distante,
grama). O jogo mantém um **estilo visual alternativo, totalmente procedural**,
escolhido em **AJUSTAR → Estilo visual**, só para comparação; ele não recebe
mais investimento artístico.

## Por que o Tripo não pesa, se usado do jeito certo

O que pesa é o **Modelo HD cru**: cada geração chega com ~1,9 milhão de
triângulos e três texturas 2K. Isso é qualidade de cinema, não de jogo. A
própria Retopologia do Tripo (**Malha Smart**, quads, 500 a 10.000 polígonos)
resolve o problema, e ficou melhor que qualquer redução externa.

Medição no jogo (26/09/2026, GTX 1660 Ti, 1080p), a mesma mangueira:

| Versão | Triângulos | Resultado |
|---|---:|---|
| Procedural (`flora_reconcavo.gd`) | 560 | leve, sem identidade |
| HD reduzido por `reduzir_glb.py` | 144.564 | folhas serrilhadas; abriu trincas de UV |
| **HD → Malha Smart (10.000 quads)** | **20.453** | limpa, quase igual ao HD |

Com a bancada das três na tela: 60 FPS, ~2,5 M triângulos, ~300 draw calls.
`reduzir_glb.py` está **descontinuado**: fica no repositório só como registro,
e nenhum asset novo deve passar por ele.

## O fluxo, passo a passo

1. **Referência.** Prefira imagem → 3D a partir de uma referência no estilo do
   jogo (ver [IMAGEM_PARA_MODELO_3D.md](IMAGEM_PARA_MODELO_3D.md)); texto → 3D
   serve para rascunho rápido. O prompt sempre termina com *isolated object, no
   ground plane, no text*.
2. **Gerar** com *Modelo HD* (H3.1, Máx. qualidade, textura 8K desligada):
   **55 créditos**. Até 100 tarefas em paralelo no plano Max; o lote de 30
   economiza cliques.
3. **Remesh → Retopologia** (Quad, Malha Smart): **40 créditos**. Alvo de
   polígonos conforme a tabela abaixo. O Tripo rebakeia as texturas na malha
   nova; não é preciso refazer UV nem textura.
4. **Exportar GLB** com a resolução de textura da tabela. O arquivo cai em
   `Downloads`; copie para `.assets-raw/tripo/<categoria>/` (fora do Git) e o
   GLB final para `prototipo_3d/assets/prototipo_3d/<categoria>/`.
5. **Registrar** em `ORIGEM.md` da pasta (tarefa Tripo, contagem de faces,
   resolução) e em `assets/CREDITOS.md`. Conferir escala, colisão e nome no
   jogo antes de commitar.

Custo por asset pronto: **~95 créditos** (≈ 230 assets por mês no plano Max). O
lote de 26/09 (67 retopologias, uma geração e um rig) custou 2.755 créditos; saldo ao
fim do dia: 17.950.
O gargalo é a curadoria humana, não o crédito.

## Lote pelo console do Studio (66 peças em 26/09/2026)

Retopologia e exportação de dezenas de peças não se faz clicando. O Studio é
uma aplicação Nuxt que conversa com `api.tripo3d.ai/v2/studio/…` e o script
[`prototipo_3d/tools/tripo/lote_studio.js`](../prototipo_3d/tools/tripo/lote_studio.js)
repete, na mesma sessão logada e com os mesmos cabeçalhos que a página envia,
exatamente as chamadas da interface:

| Passo | Chamada | Observação |
|---|---|---|
| geração base | `GET project/history/<projeto>` | o nó da malha é `tripo_node_<id da text_to_model>` |
| retopologia | `POST operation/remesh` `{bake, face_limit, quad, smart_poly, part_name_list, project_id}` | 40 créditos; ~1–2 min |
| andamento | `POST progress` `{ids:[…]}` | `status: running → success` |
| exportação | `POST operation/export` `{format:"gltf", texture_size:1024\|2048, name, project_id, …}` | grátis; ~30 s |
| arquivo | `POST operation/download_with_name` `{file_name, operator_id}` → `model_url` | o navegador baixa para `Downloads` |

Uso: abrir um projeto no Studio, colar o script no console e chamar
`__mv.lote(PLANO, 6)` com `PLANO = [{key, id, faces, tex}]` (o lote de
26/09 está em `lote_2026-09-26.json`). O estado fica em `localStorage`
(`mv-lote-state`) e `__mv.resumo()` mostra o andamento; a aba precisa ficar
**visível**, porque o Chrome segura os downloads de abas escondidas. O script
não imprime nem guarda token: reaproveita os cabeçalhos da própria página.

## Do download ao jogo

Depois do lote (ou de uma exportação avulsa), na raiz do repositório:

```powershell
python prototipo_3d/tools/tripo/sincronizar_downloads.py        # Downloads → assets/prototipo_3d/<pasta>/
python prototipo_3d/tools/tripo/medir_glb.py                     # caixa, triângulos e imagens de cada GLB
python prototipo_3d/tools/tripo/registrar_origem.py lote_2026-09-26.json Downloads/tripo_prompts_*.json
```

1. `sincronizar_downloads.py` procura `<chave>_tripo.glb` (e as cópias `(1)`, `(2)`…)
   em Downloads, pega a mais recente, guarda uma cópia em `.assets-raw/tripo/` e copia
   para o caminho do catálogo. Ignora arquivos acima de 25 MB (HD cru).
2. `medir_glb.py` lê só o cabeçalho do GLB. Todo modelo do Tripo chega com o maior eixo
   em 0,98; escolha `altura` para o que é alto e fino e `largura` para o que é deitado.
3. Entrada em `CatalogoAssets.PECAS`. Correções disponíveis:
   `"girar": [x, y, z]` (graus, aplicado antes de medir: o peixe e a tábua vêm de pé),
   `"afundar"` (unidades; o píer vem com estacas e precisa entrar na água) e
   `"piso"` (altura do tabuado caminhável que `world_builder` cria sobre píer e ponte).
4. `registrar_origem.py` escreve a seção do lote no `ORIGEM.md` de cada pasta, com
   tarefa, prompt, triângulos, textura e tamanho. Os prompts vêm do Studio
   (`__mv.detail(projeto).biz_info.description`) e ficam gravados no JSON do lote.
5. Abra o jogo nos dois estilos (AJUSTAR → Cenário e tempo) e olhe a peça de perto.

## Texturas comprimidas em VRAM

Cada GLB traz três texturas (cor, normal, metal/rugosidade). Com 67 modelos, a
importação sem compressão levou a memória de vídeo a **2,49 GB**. O `project.godot`
agora tem `[importer_defaults] texture = VRAM Compressed`, e as texturas extraídas dos
GLBs foram reimportadas: **735 MB**, com 60 FPS e a mesma aparência a distância de jogo.
Consequências:

- texturas novas entram comprimidas; as de interface precisam ser marcadas como
  **Lossless** no `.import`;
- ao substituir um GLB, apague os `.import` das texturas antigas (o nome delas muda a
  cada exportação) e deixe o Godot reimportar.

## Rig e animação dos personagens (em andamento)

Os nove personagens do lote foram gerados em pose T, prontos para rig. No Studio:

| Passo | Onde | Custo observado |
|---|---|---|
| Auto Rig (Humanoide, esqueleto Mixamo) | Rig → Auto Rig; API `operation/pre_rig_check` + `operation/rigging_model` `{rig_type:"biped", spec:"mixamo"}` | 20 créditos |
| Animações prontas | Animar → Predefinições; API `operation/retarget_model` `{animations:["preset:biped:idle", …]}`, até 5 por chamada | não descontou saldo em 26/09 |
| Exportar com animações | Exportar → **Número de Animações** → Selecionar tudo → Exportar | grátis |

Clipes pedidos para os moradores: `idle`, `walk`, `run`, `greet_01`, `agree`,
`look_around`, `wave_goodbye_02` (o viajante leva também `chop`, `afraid`, `fold_arms`,
`swim`). **Pedro** já tem rig e os sete clipes (projeto `c8a8039c-…`); falta exportar pela
interface. **Pedro está pronto** (26/09): na tela Animar, clicar em cada predefinição
(ocioso, caminhar, correr, cumprimentar_01, concordar, olhar_ao_redor, dar_tchau_02)
e depois Exportar → Número de Animações → Selecionar tudo → Exportar; GLB com 65
ossos e 8 clipes em `personagens/pedro_tripo.glb` (textura 1K). A chamada direta
`operation/export` com `with_animation:true` pelo script respondeu erro 1000/1004.

Os clipes chegam com sufixo (`walk.001`); o Godot os importa como `walk_001`,
`greet_01_002`. `authored_animator.gd` tira o sufixo de três dígitos, então não é
preciso renomear nada.

No jogo nada precisa mudar quando o GLB animado chegar: `npc.gd` usa
`authored_animator.gd` sempre que o modelo tem `AnimationPlayer`, e o jogador só troca
o personagem medieval pelo `viajante_tripo.glb` quando este tiver clipes. Até lá, no
estilo Tripo os moradores aparecem em pose T, deslizando com um balanço leve.

## Orçamento por tipo de asset

| Tipo | Polígonos na retopologia | Textura na exportação |
|---|---:|---:|
| Construção de destaque (capela, casarão) | 8.000–10.000 | 2K |
| Casa comum, pier, ponte | 4.000–6.000 | 2K |
| Árvore nomeada (perto do jogador) | 6.000–10.000 | 2K |
| Árvore de mata (instanciada às centenas) | 800–2.000 | 1K |
| Adereço pequeno (poço, pote, carroça, cerca) | 1.000–3.000 | **1K** |
| Item de mão (machado, cesto, moringa) | 500–1.500 | **1K** |
| NPC / personagem com rig | 6.000–10.000 | 2K |

Regras:

- **1K para tudo que é pequeno.** A memória de vídeo do protótipo (1,1 GB)
  vem das texturas, não dos triângulos: cada modelo traz base color, normal e
  RM. Um adereço em 1K gasta 4× menos que em 2K sem diferença visível a 2 m.
- **Nunca 8K no jogo.** O plano oferece 8K; isso destrói a VRAM. 8K é só para
  render de divulgação.
- Textura 2K apenas para o que o jogador olha de perto e por muito tempo.
- Instanciar o mesmo GLB muitas vezes é barato; ter muitos GLBs diferentes na
  cena é o que custa (draw calls e VRAM).

## Limites do formato

- O modelo é uma casca fechada: não dá para entrar numa casa do Tripo. Interior
  é cena separada.
- Folhagem é malha sólida: não balança nem tem transparência. Vento e água são
  trabalho do motor.
- Iluminação às vezes vem gravada na textura; escolher a variante mais neutra.
- Colisão é sempre feita à mão (`world_builder.gd`), com formas simples.

## Coerência de estilo

O risco real não é peso, é **colagem**: três estilos diferentes na mesma
praça. Para evitar: gerar a referência de imagem sempre com a mesma bíblia de
estilo (docs/AMBIENTACAO.md, paleta caiada/telha/barro/verde-mata), pedir
"stylized game prop, clean silhouette, soft even lighting" e revisar cada peça
ao lado das vizinhas no jogo antes de promover.

## Licença e dependência

- O plano Max concede uso comercial e modelos privados (e-mail de ativação).
  Confirmar com o suporte se a licença dos modelos gerados **permanece válida
  após cancelar a assinatura** antes de publicar o jogo.
- Créditos são mensais; planejar lotes.
- GLBs entram no Git como blobs comuns (13 MB no máximo por arquivo); com o
  crescimento, migrar para Git LFS.

## Tripothon S1

Prazo de envio: 5 de outubro de 2026 (AoE), com demo jogável, gravação do
passeio e prancha de assets; Demo Day em São Paulo em 17 de outubro (inscrição
separada). Trilhas: Game + ferramenta Tripo. Detalhes em
https://developers.tripo3d.ai/en/events/tripothon-s1.
