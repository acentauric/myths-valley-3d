# O vale vivo: estilos, dia e noite, moradores e som (protótipo 3D)

Estado de 26/09/2026. Tudo aqui é da cena `scenes/prototipo_3d/vale.tscn` e do
menu `abertura.tscn`; o 2D não muda.

Este documento descreve o estado implementado. A direção aprovada para transformar
o cenário gerado em uma composição visualmente editável, usar o KML como referência
e retirar futuramente o procedural está em
[COMPOSICAO_AUTORAL_3D.md](COMPOSICAO_AUTORAL_3D.md).

## Dois estilos visuais, nunca misturados

**AJUSTAR → Cenário e tempo → Estilo visual** escolhe como o vale inteiro é
construído (autoload `Estilo`, salvo em `user://preferencias_visuais.cfg`):

| | Tripo (linha mestra) | Procedural |
|---|---|---|
| casas, árvores nomeadas, adereços, itens | GLBs do Tripo Studio (`CatalogoAssets`) | construtores de `world_builder.gd` e `flora_reconcavo.gd` |
| mata e coqueiros da orla (`MultiMesh`) | malhas dos GLBs `mata_a`, `mata_b`, `embauba`, `dende` | espécies procedurais |
| personagem e moradores | GLBs do Tripo (`personagens/`); sem rig ainda, aparecem em pose T. O jogador usa o GLB medieval animado até `viajante_tripo.glb` ter clipes | `PersonagemProcedural` (humanoide por código, com andar, corrida e 8 gestos) |
| terreno, ruas, rios, mar, luz e som | iguais nos dois | iguais nos dois |

O toggle existe para decidir a linha mestra olhando os dois no mesmo lugar; não
há peça de um estilo dentro do outro. Quando um GLB ainda não foi exportado, o
console imprime `CATALOGO: Peças Tripo ainda não exportadas: …` e a peça fica
ausente (o morador cai no humanoide procedural para o jogo não ficar sem gente).

`catalogo_assets.gd` é o único lugar que sabe o caminho de cada GLB e a medida
usada para normalizá-lo (`altura` ou `largura`) e a colisão (`tronco` ou
`caixa`). Peça nova = uma linha em `PECAS` + o GLB em
`assets/prototipo_3d/<pasta>/<chave>_tripo.glb`.

## Relógio, sol, lua e as luzes de 1887

O autoload `Dia` guarda a hora (0–24) e avança pela velocidade escolhida em
**Cenário e tempo → Passagem do tempo** (Parada, Lenta 120 s/h, Normal 45 s/h,
Rápida 10 s/h); **Hora inicial** define onde o vale começa. No jogo, **T**
adianta uma hora; o relógio do HUD mostra hora, período e estilo.

`world_builder.gd` aplica a hora: o sol gira de leste a oeste com cor e energia
por elevação, o céu (`ProceduralSkyMaterial`) vai do azul do meio-dia ao
laranja do entardecer e ao azul-escuro da noite, a névoa engrossa de
madrugada, e uma lua fraca e fria entra quando o sol se põe.

Não havia luz elétrica em 1887. `luzes_epoca.gd` acende ao entardecer (luz do
dia abaixo de 45 %) e apaga ao amanhecer, com tremeluzir de chama:

- **lampiões a óleo** de poste nas três esquinas da Praça e no adro da capela;
- **candeeiros** de querosene nas portas da casa de taipa, da venda, da casa de
  pasto e no píer;
- **fogueira** no terreiro do roçado;
- **velas** nas janelas da casa de taipa e da capela.

No estilo Tripo cada luz tem o modelo correspondente do catálogo
(`lampiao_poste`, `candeeiro`, `fogueira`); no procedural, as peças de
`flora_reconcavo.gd`.

## Som do lugar

`ambiente_vale.gd` mantém dois loops de mata (dia: aves e insetos; noite:
grilos, sapos e corujas) em fusão pela luz do dia, mais as aves do
Recôncavo já usadas no menu. Os loops da mata são estridentes, por isso só
aparecem em episódios curtos (6–12 s, 5 dB abaixo do ambiente) separados por
pausas de 1 a 2,5 min; aves, mar, riacho e fogueira seguem contínuos.
Cada camada (aves, mar, riacho, fogueira, insetos e grilos) tem volume próprio
em AJUSTAR, aba Sons do vale; `fonte()` recebe a camada da fonte posicional. Por proximidade (`AudioStreamPlayer3D`): o mar no
píer, o riacho nos dois pontos do rio e a fogueira do roçado quando está acesa.
Os loops de 24 s vieram do ElevenLabs Sound Effects e ficam em
`assets/audio/ambiente/` (`mata_dia`, `mata_noite`, `riacho`, `fogueira`).
Os volumes seguem os controles de AJUSTAR (`Audio.volumes_alterados`).

## Moradores

`data/npcs_3d.json` lista os sete moradores de [MORADORES.md](MORADORES.md)
com **postos por período** (manhã, tarde, entardecer, noite, madrugada), cada
um uma âncora do cenário (`world_builder.ancoras`: Praça, Igreja, Bar,
Restaurante, Pier, Cemitério, Roçado, Poço, Casa de taipa, Casa de Carro
Quebrado, Casa da estrada…) mais um deslocamento. `npc.gd` (`MoradorNPC`)
caminha entre os postos, olha para quem chega e, a 3,4 unidades, cumprimenta
uma vez a cada 45 s. Cada morador tem até **três falas** (`falas` em
`npcs_3d.json`) e alterna entre elas a cada encontro, começando numa ao acaso;
o balão mostra o `texto` e a voz lê o `tts` (o mesmo texto com marcações de
interpretação do `eleven_v3`, como `[sighs]` e `[whispers]`). Os áudios ficam em
`assets/audio/vozes/<id>_fala_<n>.mp3` e saem de
`tools/elevenlabs/gerar-falas-moradores.ps1`. Uma voz por pessoa: Manoel Lopes
(Benedito), Edna (Zefa), Matheus Energetic (Cosme), Matheus Santos (Tonho),
Lucinda (Filó), Raquel (Candinha) e Matheus Clear (Damião, também nas três
broncas do cemitério, `damiao_bronca_1..3.mp3`); o Pedro segue com Weverton.

O balão (`balao_fala.gd`) escolhe a cada quadro entre cinco lugares em volta da
cabeça de quem fala e fica no que menos cobre quem fala, o jogador e os painéis
do HUD, com a ponta sempre para a cabeça.

## Cemitério

Cada túmulo tem colisão na laje e uma lápide com história curta
(`data/lapides_3d.json`, até 3 linhas). `lapides.gd` mostra a tecla **E** sobre o
túmulo mais próximo e abre a história no painel da esquerda. Quem sobe numa laje
ouve o Damião, cada vez mais bravo (voz ElevenLabs "Matheus Clear", estabilidade
0,5 → 0,35 → 0,2); na terceira ele derruba o jogador para o corredor entre as
fileiras. Só reclama se estiver no cemitério (30 u); 90 s sem subir, ele esquece.

**Pedro** (`guia_pedro.gd`) não tem posto durante a chegada: acompanha o
jogador (anda a 3 u/s, corre se ficar para trás) e a conduz pelos pedidos dos
moradores — o bom-dia ao Tonho, a chave que a Dona Candinha sabe com quem
ficou, o fogo da casa do finado, o mutirão do poço com a Dona Zefa e o Cosme, a
primeira janta, a primeira noite, a leira e o convite sem assinatura
([CHEGADA_E_MUTIROES.md](CHEGADA_E_MUTIROES.md)). Ao entardecer avisa que vai
escurecer (`pedro_anoitecer`). Acabada a chegada, volta ao píer, e as filas dos
moradores abrem.

O jogador chega de barco: começa no píer, com o Pedro ao lado.

## Desempenho medido (26/09/2026, GTX 1660 Ti, janela 1280×720)

| Estilo | FPS | Triângulos no quadro | Memória de vídeo |
|---|---:|---:|---:|
| Procedural (antes da compressão) | 60 | ~0,65 M | ~1,06 GB |
| Tripo, texturas sem compressão | 60 | ~10,5 M | 2,49 GB |
| Tripo, texturas VRAM Compressed | 60 | ~10,5 M | 0,74 GB |
| Tripo, mata em blocos com LOD | 60 | ~2,4–3,6 M | 0,74 GB |

A mata pesava por três motivos, corrigidos em `geo_region_renderer.gd` e
`catalogo_assets.gd`: (1) o dendê de 15 mil triângulos estava sorteado na mata — na
versão daquela medição, a mata do estilo Tripo usava só `mata_a`, `mata_b` e
`embauba` (~2,5 mil cada); espécies locais mais pesadas entraram depois;
(2) cada espécie era uma `MultiMesh` do mapa inteiro, que nunca sai do quadro — agora
a mata e a orla são divididas em blocos de `BLOCO_MATA` (40 unidades), descartados fora
da câmera; (3) o catálogo fundia a malha com `SurfaceTool` e perdia os LODs gerados
pelo importador — para GLBs de uma malha só, usa a malha importada, e cada bloco
escolhe o LOD pela distância.

### Experimento de LOD da vegetação (#34)

No passeio, cada bloco de vegetação usa mais cedo o LOD automático da malha
importada (quando o GLB o possui) e agora também tem distância máxima de
visibilidade. O sub-bosque baixo some primeiro (85 unidades); restinga, árvores
do rio, coqueiros e copas da mata continuam visíveis até 200, 230, 250 e 280 unidades,
respectivamente, com margem anti-oscilação de 20 unidades. Os decalques no pé das
árvores e as árvores nomeadas não entram nesse corte. A colisão local dos
troncos continua independente do visual. Os GLBs `mata_a`, `mata_b` e
`aroeira` não receberam malha simplificada do importador nesta versão: neles,
só o corte por distância atua.

O mapa grande da abertura e o mapa dentro do jogo usam câmera ortográfica a
3000 unidades do chão. Neles o limite é suspenso; ao voltar ao passeio, ele é
restaurado. A câmera ortográfica do minimapa fica a 100 unidades para manter
copas e restinga visíveis; o sub-bosque baixo não aparece nessa vista. As
distâncias são constantes em `geo_region_renderer.gd`, para serem ajustadas
após testar a aparência dentro do jogo.

Medição A/B em 30/09/2026 na **mesma carga** do vale Tripo (GTX 1660 Ti,
Godot 4.7.2, 1024×576, VSync desligado, 9h fixas, minimapa desligado, câmera
fixa em cada vista, quatro tomadas de 120 quadros na ordem sem/com/com/sem):

| Vista | Sem este LOD | Com este LOD | Triângulos por quadro (antes → depois) |
|---|---:|---:|---:|
| Perto da mata | 19,6 FPS | 21,6 FPS | 11,11 M → 7,59 M |
| Sobre a mata | 28,8 FPS | 32,8 FPS | 9,48 M → 6,97 M |
| Mata à distância | 12,6 FPS | 20,3 FPS | 17,33 M → 5,65 M |

Esses números não substituem um teste visual jogando: o FPS oscilou bastante
entre tomadas, mesmo na mesma vista, e varia conforme a máquina e outros
processos abertos. A queda de triângulos é a evidência mais estável. A versão
com desvanecimento dos blocos foi descartada porque, embora reduzisse
triângulos, piorou o FPS de perto; a margem atual evita a oscilação sem esse custo.
Para repetir a comparação A/B na mesma carga do mundo, rode o Godot com janela
gráfica e `--path . --script res://tools/prototipo_3d/medir_lod.gd`
(sem `--headless`).

## Onde mexer

| Quero… | Arquivo |
|---|---|
| mudar horários de nascer/pôr, velocidades | `scripts/autoload/dia.gd` |
| cores do céu por hora | `world_builder.gd::_aplicar_hora` |
| onde ficam lampiões/candeeiros | `world_builder.gd::_build_luzes_epoca` |
| postos e falas dos moradores | `data/npcs_3d.json` |
| missões do Pedro | `guia_pedro.gd::MISSOES` |
| paletas do humanoide procedural | `personagem_procedural.gd::PALETAS` |
| catálogo de GLBs do Tripo | `catalogo_assets.gd::PECAS` |
| gesto que cada morador faz ao cumprimentar | `npcs_3d.json` (`gesto_saudacao` no procedural, `gesto_tripo` com rig) |
| trazer peças novas do Tripo | `docs/arte/ASSETS_TRIPO.md` → "Do download ao jogo" |

## Balões de fala

As falas dos moradores e do Pedro aparecem em balões de interface (`balao_fala.gd`): fundo claro, nome de quem fala e ponta apontando para a cabeça do personagem. O balão tem tamanho fixo na tela, então continua legível à distância; some quando o personagem sai da câmera ou passa de 45 m, e encosta nas bordas sem cobrir o relógio, o objetivo nem o rodapé de controles.

### Sobrevoo da abertura (#34)

O fundo do menu voa do píer até a praça, com a câmera olhando para a frente
na direção do movimento. O percurso curvo retorna por outro lado, num ciclo
contínuo de 72 segundos. A altura acompanha o relevo a 16 metros do chão;
o olhar adiante tem inclinação leve para revelar as casas e as copas, em vez
de enquadrar só o piso. As âncoras reais definem o trajeto e o voo começa
quando o vale termina de montar. O modo Parado usa a vista inicial do píer.
A abertura deixa de sobrepor poeira dourada e vaga-lumes ao cenário.

**O voo nunca atravessa nada, e contorna pelos lados.** A elipse do píer à praça
cortava copas e telhados em 30% do ciclo: a 16 m o olho entra no coqueiro e no
manguezal da orla, no cajueiro, no poço e na casa ao lado da praça. Subir por cima
não serve (é a altura das copas que se quer mostrar, e a mata perde o LOD), então o
traçado é que desvia, sempre a 14,6–17,4 m do chão:

- O trajeto é **planejado offline** e gravado em `data/sobrevoo_menu.json` (720
  amostras, uma a cada 0,1 s); o menu só interpola (Catmull-Rom periódica) e não
  gasta nada no carregamento. Em regime a câmera fica exatamente no trajeto; nas
  trocas de modo (travessia → voo, Parado ↔ Sobrevoo) ela chega a ele em 2 s.
- O laço sai do píer, passa pelos vãos da fileira de coqueiros da orla (ida ao norte,
  volta ao sul), contorna a praça a ~35 m (mais perto, só atravessando a mangueira
  dela) e chega à praça por volta dos 31 s: a volta contorna mais árvores e leva
  mais tempo que a ida.
- Folga mínima de 5 m da **geometria real** (triângulos, não AABB: a caixa do coqueiro
  do Tripo tem 49 m de largura, e a 16 m ele ocupa só o tronco e as pontas das
  folhas), nos dois estilos: 6,25 m no Tripo e 5,74 m no procedural.
- Conforto no nível do voo que já existia: guinada até 21,6 graus/s (p95 17,4, contra
  19,4 na elipse), aceleração lateral até 1,42 m/s², subida e descida até 1,31 m/s.
  A velocidade desacelera nas curvas (3,4 a 13,7 m/s).
- Se as âncoras ou a escala mudarem, o menu avisa e volta à elipse antiga.

Os portões `tests/sobrevoo_livre.gd` (Tripo) e `tests/sobrevoo_livre_procedural.gd`
montam o vale, rasterizam os triângulos em volta do voo e conferem o trajeto gravado
quadro a quadro. **Plantou uma árvore ou mudou uma casa de lugar e eles reprovaram:
replaneje** — o caminho está em `tools/prototipo_3d/sobrevoo/README.md`.

O eixo visual do sobrevoo coloca o olhar adiante a 75% da largura da janela,
no terço direito livre do retábulo. O ajuste acompanha a proporção da janela;
o mapa e a travessia conservam seus próprios enquadramentos.
