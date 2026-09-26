# O vale vivo: estilos, dia e noite, moradores e som (protótipo 3D)

Estado de 26/09/2026. Tudo aqui é da cena `scenes/prototipo_3d/vale.tscn` e do
menu `abertura.tscn`; o 2D não muda.

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
grilos, sapos e corujas) em fusão contínua pela luz do dia, mais as aves do
Recôncavo já usadas no menu. Por proximidade (`AudioStreamPlayer3D`): o mar no
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
uma vez a cada 45 s: balão com a primeira linha da apresentação de
`data/dialogos/aldeoes.json` e a **voz** correspondente em
`assets/audio/vozes/<id>_saudacao.mp3` (ElevenLabs, vozes pt-BR: Weverton para
Pedro, Borges para Benedito, Katiuscia para Zefa, Matheus para Cosme, Matheus
Santos para Tonho, Ana Alice para Filó, Ana Dias para Candinha, Matheus Clear
para Damião). O texto pesado fica no balão e no HUD; o áudio é só a saudação.

**Pedro** (`guia_pedro.gd`) não tem posto: acompanha o jogador (anda a 3 u/s,
corre se ficar para trás) e conduz as missões de chegada, narradas em voz
quando está por perto: praça → capela → casa de pasto → roçado → píer antes de
escurecer. Ao entardecer avisa que vai escurecer (`pedro_anoitecer`). O
objetivo do HUD mostra a missão atual (n/5).

O jogador chega de barco: começa no píer, com o Pedro ao lado.

## Desempenho medido (26/09/2026, GTX 1660 Ti, janela 1280×720)

| Estilo | FPS | Triângulos no quadro | Memória de vídeo |
|---|---:|---:|---:|
| Procedural (antes da compressão) | 60 | ~0,65 M | ~1,06 GB |
| Tripo, texturas sem compressão | 60 | ~10,5 M | 2,49 GB |
| Tripo, texturas VRAM Compressed | 60 | ~10,5 M | 0,74 GB |

A maior parte dos triângulos do estilo Tripo vem da mata (`MultiMesh` com as árvores
`mata_a`, `mata_b`, `embauba`, `dende`) e dos coqueiros da orla. Se o quadro pesar em
máquinas mais fracas, o próximo passo é LOD: malha de 300–500 polígonos para a mata
distante (retopologia com alvo menor) e `visibility_range` nas instâncias.

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
| trazer peças novas do Tripo | `docs/ASSETS_TRIPO.md` → "Do download ao jogo" |
