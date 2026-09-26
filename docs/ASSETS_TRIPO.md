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
2. **Gerar** com *Modelo HD* (H3.1, Máx. qualidade): **65 créditos**. Até 100
   tarefas em paralelo no plano Max; o lote de 30 economiza cliques.
3. **Remesh → Retopologia** (Quad, Malha Smart): **40 créditos**. Alvo de
   polígonos conforme a tabela abaixo. O Tripo rebakeia as texturas na malha
   nova; não é preciso refazer UV nem textura.
4. **Exportar GLB** com a resolução de textura da tabela. O arquivo cai em
   `Downloads`; copie para `.assets-raw/tripo/<categoria>/` (fora do Git) e o
   GLB final para `prototipo_3d/assets/prototipo_3d/<categoria>/`.
5. **Registrar** em `ORIGEM.md` da pasta (tarefa Tripo, contagem de faces,
   resolução) e em `assets/CREDITOS.md`. Conferir escala, colisão e nome no
   jogo antes de commitar.

Custo por asset pronto: **~105 créditos** (≈ 230 assets por mês no plano Max).
O gargalo é a curadoria humana, não o crédito.

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
