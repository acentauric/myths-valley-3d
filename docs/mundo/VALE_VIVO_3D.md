# O vale vivo: estilos, dia e noite, moradores e som (protótipo 3D)

Estado revisado em 07/10/2026 (#72). As medições datadas abaixo preservam
as condições e resultados de cada levantamento. Tudo aqui é da cena `scenes/prototipo_3d/vale.tscn` e do
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
| personagem e moradores | GLBs com rig em `personagens/`, controlados por `authored_animator.gd`; revisão de qualidade do viajante em #55 e dos animais em #149 | `PersonagemProcedural` (humanoide por código, com andar, corrida e 8 gestos), preservado como legado |
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

## A maré

A baía tem maré de 2,4 m (0,6 unidades), e **ela vem ligada**: AJUSTAR → Cenário → Maré começa em
"Ciclo do lugar" (semidiurno, período de 12 h de jogo). A preamar cai às 07:00 e às 19:00 (o jogo abre
com a água cheia e o saveiro atraca na prancha dessa altura), a baixa-mar às 13:00 e à 01:00: no ritmo
Normal o mar desce mais de um metro em 90 s, a praia seca e a lama aparece. `mare.gd` (autoload) só
guarda o deslocamento (`nivel_offset()`, 0 na preamar a -0,6 na baixa-mar) e quem o lê o segue: o plano
do mar e a barreira da água da câmera (grupo `mare_superficie`), os shaders de areia, leito e água
(`mare_offset_m`, `turbidez`), `water_level()`, `water_depth_at()` e `fundo_exposto()` do
`world_builder.gd` (daí o chão dos pés virar "lama", a espuma da água rasa, o nado e a câmera), as
canoas (encalham), o tubarão e os cardumes. A escolha em AJUSTAR grava `escolhida=true`: sem essa marca
o `modo=0` das preferências de antes é lido como o padrão antigo e passa para o ciclo do lugar; quem
escolheu "Sem maré" continua sem. Sem tela (`--headless`, os portões) o padrão é "Sem maré", porque os
portões da água medem contra um nível fixo; `MV_MARE_MODO=1` força a maré nos portões, e
`tests/mare_ligada.gd` prova o padrão, a migração, a curva e o vale seguindo.

## Som do lugar

`ambiente_vale.gd` mantém dois loops de mata (dia: aves e insetos; noite:
grilos, sapos e corujas) em fusão pela luz do dia, mais as aves do
Recôncavo já usadas no menu. Os loops da mata são estridentes, por isso só
aparecem em episódios curtos (6–12 s, 5 dB abaixo do ambiente) separados por
pausas de 1 a 2,5 min; aves, mar, riacho e fogueira seguem contínuos.
Cada camada (aves, mar, riacho, fogueira, insetos e grilos) tem volume próprio
em AJUSTAR, aba Sons; `fonte()` recebe a camada da fonte posicional. Por proximidade (`AudioStreamPlayer3D`): o mar no
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
a voz lê o `tts` (o mesmo texto com marcações de interpretação do
`eleven_v3`, como `[sighs]` e `[whispers]`), o aviso do HUD mostra o `texto`
inteiro e o balão só a primeira frase, com no máximo 60 letras
(`MoradorNPC.balao_curto`). **Quem tem missão com o jogador não cumprimenta:**
o dono de uma fila que está andando ou que vai abrir ao chegar perto, e quem o
passo de agora manda procurar, falam a missão e só ela
(`CadeiaDeMissoes.envolve`). Os áudios ficam em
`assets/audio/vozes/<id>_fala_<n>.mp3` e saem de
`tools/elevenlabs/gerar-falas-moradores.ps1`. Uma voz por pessoa: Manoel Lopes
(Benedito), Edna (Zefa), Matheus Energetic (Cosme), Matheus Santos (Tonho),
Lucinda (Filó), Raquel (Candinha) e Matheus Clear (Damião, também nas três
broncas do cemitério, `damiao_bronca_1..3.mp3`); o Pedro segue com Weverton.

**Os catorze moradores de jornada** (05/10/2026), que eram mudos, falam desde 06/10/2026, com o
balão nos quatro idiomas e a voz em português (`audio` de cada fala; quem ainda espera crédito
declara `voz_pendente`): cada um tem `saudacoes` (o cumprimento de quem chega perto)
e de 6 a 10 `falas` (a conversa do E), e quem fica na rua à noite tem também `saudacoes_noite` e
`falas_noite`, que somam às de sempre à noite (`falas_dos_moradores.gd`). Quem tem `saudacoes`
cumprimenta delas e guarda as `falas` para o E; quem só tem `falas` (os sete de antes, o Pedro)
segue como acima. Ver "A voz dos catorze" em [MORADORES.md](MORADORES.md).

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

**As doze covas** ficam no desenho de `cemiterio_layout.gd` (fonte única; o `world_builder`
as põe, o `lapides.gd` tira dele o vão por onde o Damião cruza uma fileira): quatro fileiras
de três lajes no sentido leste-oeste, todas com a cabeceira (a cruz) a OESTE e os pés a leste
(a laje do Tripo já vem assim; a procedural gira um quarto de volta), vão de 0,9 u ou mais
entre lajes e corredor de 1,3 u entre fileiras, cada uma com até 4 cm de desvio e 3 graus de
guinada (sorteio por índice, o mesmo em toda montagem). O corredor do meio fica na altura da
porta da capelinha, que olha para ele. A base de cada laje sai dos quatro cantos da pegada,
pela mesma fórmula do chão, um pouco afundada (a malha do chão fica até 8 cm abaixo dela), sem
inclinar a laje: quem a inclina é o conserto do Damião, e ela volta reta. As posições foram
achadas contra tudo o que mora ali (capim, embaúbas, pedras, galhadas, postos do Damião, do
padre e do sacristão): mexeu em um, rode `tests/lapides_no_chao.gd`.

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

### Copas distantes (a serra coberta de mata)

Cada bloco de árvores some a `LOD_MATA` (280 u) e o chão vai até 2.800 u: a montanha
ficava pelada. Cada bloco de 40 u que some ganha agora um IRMÃO (`copas_distantes.gd`) que
entra exatamente onde a árvore sai (`visibility_range_begin` = o fim da camada, a mesma
margem de 20 u, sem desvanecimento) e vai até 1.200 u:

- **a copa low-poly** (64 triângulos, `copa_distante.gdshader`): uma elipsoide facetada por
  tronco, na silhueta e na cor da espécie (a cor média da folhagem do GLB, puxada para o
  `#3E6B34` do chão e escurecida, com malhado de folhagem do mesmo ruído do terreno). As
  espécies novas da mata (jatobá, sapucaia, jequitibá, cedro, angico, massaranduba), que não
  têm versão `_longe`, usam só ela;
- **o modelo `*_longe` do Tripo**, só para quem não é uma bola — coqueiro, dendê, piaçava,
  mangue, castanhola e ingá (524 troncos): de 280 a 600 u, e a copa low-poly de 600 a 1.200 u.

Por que não o modelo de longe em tudo: são ~6,8 mil troncos, e quase todos além de 280 u.
A 1,1 a 2,1 mil triângulos cada um, seriam de 7 a 12 M de triângulos por quadro (conta, não
medida). A copa de 64 faces custou +0,26 a +0,53 M triângulos e +120 a +400 chamadas de
desenho nas vistas medidas (Mirante olhando a vila e praça olhando a serra, de dia e na hora
dourada); o FPS não mudou além do ruído da máquina dividida entre várias sessões.

O corte, o crescimento e a restauração da árvore (`_mostrar_instancia`) movem também a copa
e o modelo de longe da mesma árvore. O mapa grande esconde as duas camadas (a câmera
ortográfica a 3.000 u veria tudo em duplicata); o minimapa (a 100 u, janela de 55 u) nunca
chega a 280 u. O extrator do sobrevoo não vê as copas (só o que `_multimesh_em_blocos`
recebe, e elas não passam por ali). No estilo procedural a copa funciona igual (a caixa da
malha dá a forma). Portão: `tests/lod_vegetacao.gd`.

### Casas, árvores nomeadas e adereços de longe

O vale monta 491 peças do catálogo (2,0 M de triângulos), e 341 delas — 31 construções de
10 mil triângulos, 64 árvores nomeadas de 10 a 20 mil, 217 adereços e 29 plantas de roça —
eram desenhadas inteiras a qualquer distância, do mirante ao fim da baía.
`CatalogoAssets.instanciar` agora termina em
`dar_alcance`: cada peça de `construcoes/`, `casas/`, `arvores/` e `aderecos/` ganha um
`visibility_range_end` que CRESCE COM O TAMANHO dela (uma peça de 22 vezes a sua dimensão
maior ocupa sempre os mesmos pixels ao sumir), limitado por classe: a construção e a árvore
nomeada de 22 x (100 a 260 e 70 a 260 u), o adereço de 30 x (60 a 200 u: os pequenos somem
entre 60 e 90 u e DESVANECEM em 8 u), a roça e o canteiro de 50 a 90 u. Tabela e razões em
`catalogo_assets.gd`. Ficam de fora o que anda ou se leva na mão (gente, bicho, peixe,
barco, item), a mobília, que mora dentro de cômodo, e o píer, a ponte, o mirante e os
barcos (uma peça só cada, vistos de todo o vale): `SEM_ALCANCE`, cada um com o motivo.

**A troca** (medida com a GPU, `tools/prototipo_3d/medir_lod_das_pecas.gd --modo=troca`): o
MODELO DESVANECE (`FADE_SELF`) de `end` até `end` + a margem (15 u: a casa de taipa, de 143 u,
some aos 158; a mangueira, de 177 u, aos 192; o pote, de 60 u e margem 8, aos 68), e o
SUBSTITUTO aparece em `end`, seco e SEM margem, por baixo do modelo que ainda se vê. A troca
seca com margem dos dois lados, a da mata (`copas_distantes.gd`, que segue assim), deixa um
BURACO (`--modo=estado`): com `FADE_DISABLED` e margem o renderizador faz histerese, e a peça
que nasce (o vale que monta, o jogo que carrega) com a câmera DENTRO da faixa `end ± margem`
não tem estado nenhum — a casa que nasce a 150 u do corte de 143 u desenhava 0 triângulos até
a câmera passar dos 165 u. Sem histerese o que se vê só depende da distância de agora. (A copa
da mata tem o mesmo desenho e, em princípio, o mesmo defeito, num bloco de árvores que nasce
com a câmera na faixa de 20 u dele: não foi medida nem mexida neste pacote.)

**O que se ganha** (`--modo=vale`, o vale montado com a GPU e sem os cortes, em ABBA numa
máquina parada, GTX 1660 Ti a 720 p): os triângulos desenhados caem de 2,61 M para 2,17 M da
praça de pé (-17%), de 3,06 M para 1,68 M do mirante olhando a vila (-45%), de 2,24 M para
1,74 M do píer (-22%) e de 2,62 M para 1,20 M da baía a 300 u (-54%); as chamadas de desenho
caem de 2 a 10 (o substituto é uma só). O TEMPO de GPU não muda de forma mensurável (de 14 a
33 ms conforme o ponto, igual com e sem, e igual ao do vale sem o desvanecer): o quadro desta
máquina não gasta nos vértices das peças de longe. O ganho é de triângulos e de memória, e
pesa mais em GPU fraca ou em tela grande.

**O substituto** (`pecas_distantes.gd`) é o que o vale mostra depois disso, até 1.200 u (o mesmo
`FIM` das copas da mata): para a CASA, uma caixa de parede e um telhado de duas águas de 14
triângulos, nas cores e nas proporções medidas no GLB (`tools/prototipo_3d/medir_cores_das_casas.py`
imprime a tabela `CASAS`); para a ÁRVORE NOMEADA, a copa low-poly da mata na cor da espécie.
Não faz sombra (o sol só sombreia até 70 u) e é FILHO do modelo, e um MultiMeshInstance3D, de
propósito: anda com a casa quando o prédio é assentado, some e encolhe com a árvore cortada e
crescendo, e nada que mede a casca atrás de `MeshInstance3D` (os raios do cômodo, o toco do
corte, o extrator do sobrevoo) o enxerga. O cômodo liga e desliga a sombra de tudo sob a casca
(`Comodo.por_dentro`) e mexe na do substituto das casas que têm cômodo: sem efeito a mais de 150 u.

No mapa alto (câmera ortográfica a 3.000 u: o mapa grande, o do menu, a foto do minimapa) o
gancho de `GeoRegionRenderer._atualizar_lod_da_camera` tira o corte das peças e esconde os
substitutos, como faz com a mata. No estilo procedural nada disso existe (as construções já são
caixas): nenhum substituto nasce. Portões: `tests/lod_das_pecas.gd` (e `_procedural`);
`CatalogoAssets.alcance_ligado = false` devolve o vale de antes.

## Paisagismo do arraial (zonas de uma espécie só)

A mata (`_build_forest`) não entra na vila, e o arraial tinha 78% das células a mais de 9 u de
qualquer árvore. O paisagismo o preenche com **agrupamentos de uma espécie só**, como o lavrador
planta: bananal em touceiras, pomares de quintal em bosquetes (cada um de uma fruta), roças de
mandioca, milho e fumo em fileiras com corredor, dendezal da foz, cajual do outeiro, piaçabal da
restinga e mata ciliar em faixas ao longo do rio (taboa, helicônia, samambaia, bambu, ingá e
jenipapo). A repetição é melhor que a mistura: a pureza das zonas fica acima de 0,95.

- **A cena é a fonte**: `scenes/prototipo_3d/paisagismo_vale.tscn` tem `Zonas/<nome>`, cada uma um
  `Path3D` fechado com `zona_de_flora.gd` (receita, semente, densidade, rumo). Puxe um ponto no
  editor ou troque a receita e o vale replanta no próximo jogo. `tools/mapas/planejar_paisagismo.gd`
  escreveu a cena uma vez a partir de `data/paisagismo/zonas_iniciais.json` e **recusa sobrescrevê-la**.
- **As receitas** (`data/paisagismo/receitas.json`): padrão (`fileiras`, `touceiras`, `manchas`,
  `esparso`, `faixa`), espécies e pesos, espaçamento, escala, LOD, forro, e as medidas de cada
  espécie (copa, altura, tronco, ficha). Só espécies LEVES do Tripo; nunca coqueiro nem mangue (da
  orla) nem licuri (semiárido).
- **`paisagismo_vale.gd`**: `gerar` é puro e determinístico (cada candidato tira todos os números
  de um hash antes de testar as reservas: mover uma casa só tira os pés que ela cobre). As
  reservas: rua, casa e faixa da porta até a rua, nomeadas, âncoras, cemitério (16 u), orla (18 u da
  costa), leito dos rios, veredas e o corredor do sobrevoo do menu (só entra pé de até 2,4 u). Os
  adereços (cerca de varas e porteira em volta das roças, estaleiro de fumo, carro de boi, monjolo,
  barraca de feira na praça) saem da forma das zonas.
- **Gancho**: `world_builder._build_paisagismo`, depois das luzes e antes dos pés das árvores. Pés
  com tronco entram em `_tree_trunks` (colisão, corte, navegação e o folhiço do chão valem); o
  extrator do sobrevoo replanta o paisagismo na cópia para conferir o voo contra as copas dele.
- **Só no estilo Tripo.** O procedural segue sem pomar. Fichas novas (goiabeira, mamoeiro, bambu) em
  `data/arvores_3d.json`. Portão: `tests/paisagismo.gd` (`--falsificar=reservas|sorteio|semente|voo|vazio`).

## Casas por dentro (toda casa abre)

Só a igreja, a casa herdada e as do Pedro e da Zefa tinham tabela fixa (`Interiores.CONSTRUCOES`). Todas
as outras moradias e a venda moram em `data/interiores_casas.json`, e o casarão da fazenda também:

- `modelos`: onde fica a porta PINTADA de cada GLB (`porta_x` do meio para a direita de quem olha de frente,
  largura, altura). A porta não existe na malha; foi lida nas fachadas com régua de 0,5 m
  (`tools/prototipo_3d/` guarda o método; a palhoça do pescador não tem porta pintada: o vão escuro cobre a rede).
  `medida` troca a que os raios medem onde a casca engana (a venda e o restaurante têm a porta numa alcova maciça),
  `pe_direito_max` baixa o forro das casas de telhado alto.
- `casas`: de cada cômodo, o lote (`ancora`), o nome do HUD nos três idiomas e o perfil. As do arraial que
  o vale deu ao Pedro e à Zefa saem sozinhas da lista.
- `perfis`: cal, barra e piso de quem mora, e a lista de móveis. Cada móvel pede lugares (`["esq", 0.4]`: a parede
  e a fração dela) e fica no primeiro que cabe, sem tomar o vão da porta (`InteriorCasa._moveis_do_perfil`).

Os cômodos de dados se montam DE PERTO (`Interiores.garantir`, ronda de 0,25 s: a 32 u da porta) e somem do desenho
além de 46 u. Montados todos de uma vez seriam +1 milhão de triângulos e 80 luzes atrás das paredes. Quem põe o
jogador lá dentro sem passar pela porta (um portão) pede `garantir` antes; e quem chega de uma vez ao pé de uma casa
ainda por montar (o save, um pulo no mapa) fica parado até o cômodo estar de pé (`Interiores.segura_o_jogador`), em vez de
expulso pela caixa inteira que ainda cobre a casa. Casca que mede pouco por dentro
(palhoça, capelinha, casa de carro quebrado) leva parede fina (0,15): a sala não sai da casca. O Pedro espera
fora dos cômodos pequenos (`Interiores.espera_fora`). Portão: `tests/casas_por_dentro.gd`
(`--falsificar=sem_moveis|eager|porta_fechada|sem_freio`).

O CASARÃO (`interior_casarao.gd`): o piso de dentro está 0,78 acima do chão, na plataforma do pórtico; a escada de
pedra de fora é uma rampa de colisão que passa rente às quinas dos degraus, com a plataforma e as balaustradas; por
dentro é um salão só, com a escada para o andar de cima de cenário (o andar de cima não abre).

As duas capelas (a velha e a do cemitério) abrem como as casas, com oratório e bancos. A CASA DE FARINHA é galpão aberto
(`"tipo": "galpao"`, `Interiores._abrir_galpao`): não tem porta, tira a caixa de colisão que cobria a pegada inteira e
põe no lugar só as `caixas` do JSON (as três paredes, o forno com o tacho e os dois pilares da frente), de modo que se
anda por dentro e a parede do fundo segura.

## Onde mexer

| Quero… | Arquivo |
|---|---|
| mudar horários de nascer/pôr, velocidades | `scripts/autoload/dia.gd` |
| cores do céu por hora | `world_builder.gd::_aplicar_hora` |
| onde ficam lampiões/candeeiros | `world_builder.gd::_build_luzes_epoca` |
| postos e falas dos moradores | `data/npcs_3d.json` |
| missões do Pedro | `data/missoes_guia.json`, executadas por `cadeia_de_missoes.gd`; `guia_pedro.gd` apresenta o guia |
| paletas do humanoide procedural | `personagem_procedural.gd::PALETAS` |
| catálogo de GLBs do Tripo | `catalogo_assets.gd::PECAS` |
| a mobília, a porta ou o nome de uma casa por dentro | `data/interiores_casas.json` (e rode `tests/casas_por_dentro.gd`) |
| até onde cada peça do cenário se vê, e a casa/copa de longe | `catalogo_assets.gd::dar_alcance` + `pecas_distantes.gd` |
| onde ficam as doze lajes do cemitério | `cemiterio_layout.gd` (e rode `tests/lapides_no_chao.gd`) |
| pomares, roças e mata ciliar do arraial | `scenes/prototipo_3d/paisagismo_vale.tscn` + `data/paisagismo/receitas.json` |
| gesto que cada morador faz ao cumprimentar | `npcs_3d.json` (`gesto_saudacao` no procedural, `gesto_tripo` com rig) |
| trazer peças novas do Tripo | `docs/arte/ASSETS_TRIPO.md` → "Do download ao jogo" |
| o chão: camadas, ruas, praça, praia, rios, trilhas, lavoura | `docs/mundo/SOLO_E_FRANJAS.md` |

## Balões de fala

As falas dos moradores e do Pedro aparecem em balões de interface (`balao_fala.gd`): fundo claro, nome de quem fala e ponta apontando para a cabeça do personagem. O balão tem tamanho fixo na tela, então continua legível à distância; some quando o personagem sai da câmera ou passa de 45 m, e encosta nas bordas sem cobrir o relógio, o objetivo nem o rodapé de controles.

O lugar do balão é uma conta (`BalaoFala.avaliar`, #224): o ideal é acima da cabeça, com o pé a 44 px dela e a ponta para ela; o que cairia sobre o HUD desliza o mínimo (para o lado, para cima ou para baixo do painel); a distância à cabeça e o rosto de quem fala e do jogador têm preço, para o balão nunca atravessar a tela por causa de uma dica; com o falante fora da tela ele encosta na borda do lado dele. Com um balão no ar, nenhuma plaquinha de nome fica na tela (#218). O portão `balao_sobre_quem_fala` mede o falante perto, longe, na borda, fora da tela e sob o bloco da missão.

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
  folhas), nos dois estilos: 6,12 m no Tripo e 5,74 m no procedural.
- Conforto no nível do voo que já existia: guinada até 21,6 graus/s (p95 17,4, contra
  19,4 na elipse), aceleração lateral até 1,41 m/s², subida e descida até 1,38 m/s.
  A velocidade desacelera nas curvas (3,4 a 15,3 m/s).
- Se as âncoras ou a escala mudarem, o menu avisa e volta à elipse antiga.
- **O vão norte da fileira fica livre.** A fileira da orla é sorteada ao longo da
  costa e da foz, e mudar o desenho delas põe cada árvore em outro lugar. A revisão
  da foz de 04/10 pôs um mangue a 8 m do eixo do voo, na ida, com a fileira fechada
  dos dois lados dele: não havia outro vão por onde replanejar. O vale passa a não
  plantar tronco a menos de 10 m do ponto em que o voo cruza a fileira
  (`VAO_NORTE_DO_SOBREVOO_M`, no `world_builder.gd`); a árvore é sorteada como antes
  e só não nasce, como nas clareiras, para o resto da fileira ficar onde está. Hoje
  isso tira um mangue. Na volta, pelo sul, havia espaço: o voo foi replanejado e
  passa 9 m mais ao sul, longe das folhas do último coqueiro da fileira; a ida e a
  curva da praça continuam as mesmas.

Os portões `tests/sobrevoo_livre.gd` (Tripo) e `tests/sobrevoo_livre_procedural.gd`
montam o vale, rasterizam os triângulos em volta do voo e conferem o trajeto gravado
quadro a quadro. **Plantou uma árvore ou mudou uma casa de lugar e eles reprovaram:
replaneje** — o caminho está em `tools/prototipo_3d/sobrevoo/README.md`.

O eixo visual do sobrevoo coloca o olhar adiante a 75% da largura da janela,
no terço direito livre do retábulo. O ajuste acompanha a proporção da janela;
o mapa e a travessia conservam seus próprios enquadramentos.
