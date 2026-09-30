# Histórico de mudanças — Myths' Valley 3D

Este histórico acompanha apenas a experiência executada em `prototipo_3d/` na
branch `prototype/myths-valley-3d`. O projeto 2D foi a base da derivação, mas
suas fases, versões e novidades não são entradas deste registro. Os marcos
abaixo seguem o que mudou no 3D. A identificação atual é **v0.1.0-dev · Build #5**,
exclusiva desta derivação e ainda sem distribuição publicada.

O texto clicável de versão e build no rodapé da abertura mostra resumos destes
marcos. Os textos curtos e a identificação exibidos no jogo ficam em
`prototipo_3d/data/historico_3d.json`; ao registrar um novo marco ou build,
atualize esse arquivo e este documento juntos.

## Em desenvolvimento — 29/09/2026

- **Vida no vale** (#10). Barra de vida no HUD, logo abaixo do relógio, com as cores
  do 2D: vermelha, e verde-musgo enquanto a peçonha corre. **Cair é noite no chão**,
  como no 2D: a tela escurece, o jogador acorda na porta da Casa de taipa às 6h do
  dia seguinte, com a vida cheia e o fôlego do desmaio, e o aviso conta o que houve
  (`queda.gd`, `data/queda.json`). A regra é o `Vida` compartilhado, sem uma linha
  mudada; o que o vale acrescentou é o gatilho, a barra e o portão `tests/vida.gd`.
  Nada no vale tira vida ainda — isso chega com a luta (#14).
- **Luta no vale** (#14). Um **caititu** em caixa cinza mora na mata fechada, longe da
  porta de casa e do píer, com os números do 2D na escala do passo do jogador: fareja e
  desiste em dois raios, **anuncia o bote** (acende em âmbar, abaixa e marca no chão o
  alcance da mordida) e morde 0,41 s depois do aviso. **E perto do bicho** é golpe
  (segurar: golpe forte ou rasteira, para quem aprendeu), no tempo do braço — o clipe
  `chop` no estilo Tripo, o corpo jogado para a frente no procedural —; **V** é a ginga,
  remapeável em AJUSTAR. Números da pancada sobem sobre quem apanhou. Derrubado, o bicho
  deixa a caça na mochila, devolve fôlego, conta abate, e a mata o repõe em três dias
  (`criatura_vale.gd`, `luta_vale.gd`, `data/luta.json`, `tests/luta.gd`). Onça e jararaca
  já estão na tabela, sem ninho até a serra e o brejo (#24).
- **Salvar e carregar** (#7). **JOGAR** pergunta em qual das três vagas jogar; vaga
  ocupada continua de onde parou, e recomeçar pede o segundo clique. Partida nova volta
  ao estado de fábrica (os sistemas não herdam a partida anterior). O vale guarda onde o
  jogador estava, a hora, o passo do Pedro, os lugares visitados e o bicho que caiu; salva
  ao cair, ao voltar ao menu, ao trocar o estilo e ao fechar a janela. **EXPLORAR** não
  salva. Para depurar, `JOGAR_3D.cmd -Lugar igreja` começa num lugar do vale
  (`partida.gd`, `tests/salvamento.gd`).

## Build #6 — 28/09/2026

- **Franjas refeitas** (o bloco mais pedido): espuma da linha d'água em filete fino e
  quebrado, marolas suaves que morrem antes da areia, água e leito sem receber sombra
  dura, franja terra→areia esfarelada em duas escalas (sem ilhas recortadas) e a rampa
  submersa casando de cor com o leito. Continente distante sem faixas de cor.
- **Rio de água doce**: shader próprio (âmbar escuro de mata, correnteza lenta,
  margens desvanecendo) e a foz recolorida para ser a continuação dele.
- **Maré parametrizada** (AJUSTAR → Cenário): sem maré, ciclo do lugar (semidiurno),
  ciclo lento ou rápida para demonstração; amplitude 2,4 m. Na enchente a água escurece
  (turbidez); na baixa-mar o fundo exposto vira lama com poças espelhadas, as canoas
  encalham de lado, o cardume se recolhe e os passos viram lama/poça (sons novos).
- **Tubarão** na parte funda: persegue quem nada longe demais; ataque com efeito de
  tela e volta à terra firme. Pedro e os moradores nunca são alvo.
- **Peixes corrigidos**: fim do rodopio (rumo suavizado, fuga com direção estável) e
  da disparada (velocidade limitada).
- **Modelos do lugar (Tripo, das fotos reais)**: igreja de Bom Jesus no marco certo do
  KML (a capela genérica virou "Capela velha", bem afastada na rua do mirante),
  coqueiro novo, castanholas na orla, aroeira na mata, pedras da praia no marco
  "Pedras", lajes de recife que a maré baixa expõe, bote de toldo e canoa amarela
  sem letreiro na frota (7 barcos, encalham na baixa-mar).
- **Vila maior**: praça ampliada no formato triangular do largo real, sem a horta no
  miolo (canteiros foram para a borda); mais 8 casas ao longo das ruas; a casa
  herdada do jogador agora fica junto do roçado.
- **Sons e músicas**: música por período (manhã/tarde/noite, com crossfade), música
  tensa e sussurros na mata fechada, bem-te-vi de dia, passos de água novos (opção
  "Passos na água" com botão Ouvir em AJUSTAR), lama, poça e ataque do tubarão
  (ElevenLabs).
- **Interface**: minimapa no canto (opção em AJUSTAR), tecla M abre o MAPA, atalhos
  de teclado remapeáveis (E/F/T/R/M/C) em AJUSTAR → Geral, seta e marcador do alvo da
  missão, painel PERSONAGENS no menu (moradores com falas ouvíveis + todos os assets),
  plaquinhas de nome, pegadas por terreno que somem com o tempo.
- **Falas sem atropelo**: broncas do coveiro entram na fila de vozes, raio de conversa
  maior, missões com raios revisados e âncoras dinâmicas.
- **Mata local de Saubara** (Tripo, 7 espécies): manguezal de mangue-vermelho na foz
  e na beira do estuário, ingazeiros nas margens do rio, piaçavas e jenipapeiros na
  mata, clúsias e piaçavas na restinga da orla, pitangueira no quintal de cada casa e
  sub-bosque de helicônias e bromélias sob as árvores; fichas (tecla E) para todas.
- **Painel PERSONAGENS editável**: EDITAR em cada morador (nome, altura, volume da
  voz, texto das falas e o posto de cada período — lugar e deslocamento) e em cada
  peça (medida, afundar, tronco). Ajustes em camadas (`ajustes_conteudo.gd`): salvos
  na hora em `user://`, "Restaurar o padrão" por item e, rodando pelo editor, "GRAVAR
  NO PROJETO" (npcs_3d.json e data/pecas_ajustes.json).
- **Tubarão consertado**: procurava água funda só até 80 u do píer e nunca achava
  (a planície rasa passa de 150 u); agora patrulha a água funda de verdade, persegue,
  ataca e devolve o jogador à terra (`tests/tubarao.gd`).
- Teclas apertadas durante o carregamento não quebram mais a cena do vale.
- Tela de carregamento opaca de verdade: o menu e o vale não aparecem mais por trás
  (o fundo era 96% opaco e a tela podia entrar na montagem no meio do fade).
- **Identidade "Crônica do Recôncavo" na tela de carregamento**: capa pintada do vale
  cobrindo a tela com câmera lenta, logotipo em talha dourada, nota do almanaque, etapa
  com porcentagem, rosa dos ventos girando e um fio de ouro como barra (fontes Cinzel e
  Cormorant Garamond). A capa segue a hora: **de dia** o entardecer com a igreja e o
  saveiro, com poeira na luz; **de noite** o viajante com o lampião na boca da mata, com
  vaga-lumes, a lanterna tremendo, olhos na mata e os ditos do vale no lugar do
  almanaque. A entrada no jogo usa a hora em que ele começa; a volta ao menu e a troca de
  estilo, a hora corrente; o boot, a hora do menu. O logotipo ficou como peça própria em
  `assets/prototipo_3d/identidade/` para outros usos.
- O relógio espera a montagem do vale ao entrar no jogo: o jogador chega exatamente na
  hora inicial, a mesma que escolheu a capa (antes, em velocidade Rápida, dava para ver
  a capa de dia às 17h30 e chegar já de noite).
- Trocar o estilo visual dentro do jogo não deixa mais o relógio parado para sempre, e
  apertar M enquanto o jogo volta ao menu não esconde mais a tela de carregamento.
- Câmera abre recuada (novo máximo mais distante); base das árvores com decalque
  próprio para areia; nenhuma árvore dentro do rio; texto do carregamento legível
  (mín. 1,1 s por etapa).

## Em desenvolvimento — 27/09/2026

- **Mar de verdade, na maré cheia.** O mar deixou de ser uma caixa azul chapada:
  fundo moldado pela carta náutica DHN 1108 (intermarés, plataforma rasa, talude e o
  canal do Paraguaçu) e água transparente cuja cor sai da profundidade real — areia
  esverdeada na beira, jade no raso, verde-petróleo no canal, como na foto aérea de
  Bom Jesus. Capim marinho, cáusticas, ondulação leve e espuma fina na beira
  (`mar.gd`, `assets/prototipo_3d/mar/`, `tools/mapas/gerar_batimetria.py`).
- **Tela de carregamento na abertura** (`inicio.tscn`): o jogo mostra a própria tela
  em ~60 ms, no lugar da tela do Godot; o splash do Godot virou fundo escuro.
- **Montagem do vale ~3× mais rápida** (~24 s → ~8 s): a altura de cada vértice do
  terreno é calculada uma vez e reaproveitada pelos triângulos vizinhos, e pontos
  longe da costa pulam a medida até ela.
- **O mundo é o quadro Mapa, em 16:9, no continente.** O importador do KML ajusta o
  quadro desenhado ao 16:9 exato (3.614 × 2.033 m, a largura cresce, centrada); terreno,
  costa, mata e limites terminam nele. Fora do quadro, a terra da carta náutica segue
  como relevo distante — Bom Jesus não é ilha. Paredes invisíveis na borda.
- **Entrar no mar andando e nadar.** O fundo tem colisão: o jogador afunda aos poucos,
  anda mais devagar e, onde a água passa do peito, nada (clipe `swim`, corpo na linha
  d'água); volta andando para a areia sem pular — a praia desce em rampa para dentro
  d'água e o jogador sobe degraus baixos sozinho. O Pedro nada junto (clipe novo do
  Tripo). Na planície rasa dá para andar ~600 m mar adentro (`tests/agua_rasa.gd`).
- A câmera não mergulha: a superfície da água barra o braço da câmera (camada física
  só dela).
- **Praia com areia de verdade** (`areia_praia.gdshader`: grãos, marcas de vento, areia
  úmida na beira), **marolas** de espuma correndo para a areia, **foz do rio**
  atravessando a praia e se desfazendo no mar, e um **cardume** ao lado do píer que
  foge de quem chega perto (`cardume.gd`).
- **Moradores contornam obstáculos**: andando sem sair do lugar, seguem a parede para
  um lado; depois de várias tentativas, param, olham em volta e tentam de novo.
- Canoas com colisão em casco oco: quem pula a borda fica dentro da canoa.
- **Sol no lugar certo.** O sol usava uma curva genérica e nascia a oeste; agora é a
  posição astronômica para a latitude do KML (-12,8°) no fim de setembro, em hora
  solar: nasce a leste perto das 6h, culmina ao norte quase a pino e se põe a oeste.
- **Casas voltadas para a rua**, como em Bom Jesus: um loteamento põe cada casa (e a
  capela) ao lado da rua mais próxima, porta para a rua, em terreno quase plano;
  árvores, adereços, luzes e os postos dos moradores giram junto. A laje cinza sob as
  casas virou um terreiro de chão batido rente ao chão, e moradores sobem degraus
  baixos — não ficam mais presos na borda.
- **Ruas em curva**: as linhas do KML passam por Chaikin (cantos cortados três vezes,
  até ~100 m) e os cruzamentos são reemendados.
- **Passada casada com a velocidade**: o animador mede a velocidade de chão de cada
  clipe pelo pé de apoio e ajusta a reprodução — fim do deslize, no jogador e nos
  moradores. Andar ficou em 2,1 u/s e correr em 5,2 (o clipe de andar não acompanha
  mais rápido que isso sem ficar afobado).
- **Som dos passos** no ritmo da animação e pelo chão sob os pés: corrida própria para
  grama, terra, areia, madeira (píer, ponte, canoa) e água; água rasa e funda; braçada
  no nado (ElevenLabs, `tools/elevenlabs/gerar-efeitos-3d.ps1`).
- **Espuma** na superfície em volta de quem anda ou nada no mar (`espuma_agua.gd`).
- Nado mais rápido com Shift; **C** também alterna a câmera travada (além de Tab).
- **Três saudações do Pedro**, sorteadas a cada partida, com voz nova (Weverton); a
  antiga dizia "o sol ainda tá alto" mesmo com o jogo começando às 7h.
- **Ondas de verdade na beira**: dois trens de marolas de ritmos diferentes, com a
  crista chegando a cada trecho da praia em momento e força diferentes (séries), e a
  espuma se quebrando em pedaços.
- **Areia com textura** (`areia_praia_v1.png`: grão, ondinhas de vento, conchinhas),
  areia úmida em transição larga e irregular até a água, e a borda do lado da terra
  desfeita em manchas sobre a grama; a areia passa por cima das ruas que chegam à
  praia.
- **Cruzamentos**: a rua mais larga fica por cima (sem tremulação entre ruas
  sobrepostas) e cada emenda ganha um remendo de terra batida de borda irregular.
- **Pé das árvores**: decalque de terra, folhas e raízes sob cada árvore
  (`base_arvore_v1.png`) e árvores afundadas um palmo no chão.
- **Fichas das árvores** (tecla E, `data/arvores_3d.json`, `arvores_info.gd`): uma por
  espécie em cada quadra de 16 unidades; E abre, passa a página e fecha. Nas lápides,
  E de novo fecha.
- **Plaquinhas de nome** dos moradores no estilo do HUD, com opção em AJUSTAR →
  Cenário → Nomes dos personagens.
- Pedro não "anda no lugar" mais: a animação dos moradores segue a velocidade real,
  depois das colisões.
- **Carregamento sem congelar**: o vale é montado ao longo de vários quadros
  (terreno, ruas, mata e vila cedem um quadro a cada ~80 ms) e a tela de carregamento
  sobrevive à troca de cena, mostrando cada etapa ("Moldando o terreno…", "Plantando a
  mata…") com a barra deslizando até o fim. O vale fica escondido e o VSync desligado
  enquanto monta; o maior congelamento caiu de ~4,5 s para ~0,7 s.
- **Chão iluminado pelo sol.** Os triângulos do terreno estavam de costas para cima:
  terra, praia e ruas só recebiam luz ambiente. Com a correção, a grama ganhou uma
  tinta verde para compensar o tom ocre da textura sob o sol.
- A vila e as áreas do KML são recortadas pela costa (a vila avançava sobre o mar ao
  lado do píer como um gramado).
- **Canoas de pescador** fundeadas no raso diante da vila (`canoas.gd`), canoa do
  Tripo no estilo Tripo e casco procedural no outro, balançando de leve.
- Preset de exportação Windows (`export_presets.cfg`).

## Build #5 — 26/09/2026 (tarde)

- **Dois estilos visuais, nunca misturados.** AJUSTAR → Cenário e tempo escolhe
  entre **Tripo** (GLBs do Tripo Studio via `catalogo_assets.gd`) e
  **Procedural** (tudo por código, inclusive o personagem, `personagem_procedural.gd`
  com andar, corrida e oito gestos). A mata e a orla trocam a malha instanciada
  conforme o estilo; terreno, ruas, rios, mar, luz e som são iguais nos dois.
- **Ciclo de dia e noite.** Autoload `Dia` (hora, velocidade Parada/Lenta/Normal/
  Rápida, hora inicial, tecla **T**); sol, lua, céu, névoa e ambiente seguem a
  hora em `world_builder.gd`. Relógio no HUD.
- **Luzes de 1887** (`luzes_epoca.gd`): lampiões a óleo na Praça e no adro,
  candeeiros nas portas, fogueira no terreiro e velas nas janelas, acendendo ao
  entardecer com tremeluzir.
- **Som do lugar** (`ambiente_vale.gd`): mata de dia e de noite em fusão
  contínua, mar no píer, riacho e fogueira por proximidade (loops do ElevenLabs).
- **Moradores** (`npc.gd`, `data/npcs_3d.json`): sete moradores com postos por
  período, balão de fala e saudação em voz por proximidade (ElevenLabs, pt-BR).
  **Pedro** (`guia_pedro.gd`) acompanha o jogador e narra as missões praça →
  capela → casa de pasto → roçado → píer antes de escurecer; avisa o anoitecer.
  O jogador chega de barco, no píer.
- **Lote Tripo de 66 peças** (árvores, construções, adereços, personagens e os
  itens de mão do 2D: machado, enxada, balde, cesto, moringa, farinha, peixe,
  jaca, cacho de banana…) retopologizado em Malha Smart e exportado em 1K/2K
  pelo console do Studio (`tools/tripo/lote_studio.js`, ver ASSETS_TRIPO.md).
- Redutor `reduzir_glb.py` descontinuado; a Malha Smart do Tripo substitui.
- Texturas importadas comprimidas em VRAM (`[importer_defaults]` no `project.godot`):
  a memória de vídeo do estilo Tripo caiu de 2,49 GB para 0,74 GB, mantendo 60 FPS.
- Catálogo ganhou `girar`, `afundar` e `piso` (peixe e tábua deitados; píer e ponte
  com as estacas na água e tabuado caminhável). Ferramentas novas em `tools/tripo/`:
  `sincronizar_downloads.py`, `medir_glb.py` e `registrar_origem.py`.
- Pedro animado: rig Mixamo e clipes idle, walk, run, greet_01, agree, look_around e
  wave_goodbye_02 do Tripo; `authored_animator.gd` reconhece os nomes com sufixo
  (`walk_001`). Em 27/09 os outros sete moradores receberam o mesmo rig e os mesmos
  sete clipes (fim da pose T); ver `assets/prototipo_3d/personagens/ORIGEM.md`.
- Mata pesada resolvida: blocos de 40 unidades com descarte fora da câmera, LOD da
  malha importada e mata só com as espécies leves — de ~10,5 M para ~2,4–3,6 M
  triângulos no quadro, 60 FPS.

## Em desenvolvimento — 26/09/2026

- A região passou a **1 unidade = 4 m** (`scale_m_per_unit` no catálogo, agora
  funcional): posições do KML e do cenário são divididas pelo fator, e larguras
  de ruas, rios e orla têm mínimos jogáveis. Fazenda e Praça ficaram a ~220 m
  de caminhada em vez de ~890 m (`d7613cd`).
- Ruas ganharam textura de terra batida com sulcos de carro de boi, aplicada ao
  longo do percurso; a Praça, chão de terra pisoteada com seixos. As duas
  texturas são procedurais e regeráveis por script (`c9457a0`).
- `flora_reconcavo.gd` traz espécies procedurais com silhueta própria
  (mangueira, jaqueira, cajueiro, dendezeiro, coqueiro, bananeira, ipê amarelo e
  roxo, embaúba, mata alta) e as peças soltas do 2D (poço, cruzeiro, carroça,
  varal, pilha de lenha, pote, cerca, banco). A mata usa uma MultiMesh por
  espécie; coqueiros inclinados acompanham a orla (`ea42286`).
- Mangueira, jaqueira, cajueiro, coqueiro, capela colonial e poço de pedra foram
  gerados no Tripo Studio e reduzidos por `tools/modelos/reduzir_glb.py`,
  substituindo os procedurais perto dos pontos de interesse (`42eedd8`).
- `JOGAR_3D.cmd` passou a existir só em `prototipo_3d/`; o histórico e o mapa de
  planejamento foram movidos para `docs/` e `tools/mapas/` (`23bff84`).

## Em desenvolvimento — 25/09/2026

Estas mudanças estão no trabalho local e ainda não representam uma versão
publicada:

- O KML desenhado pelo autor foi preservado no projeto e passou a orientar
  ruas, rios, áreas e pontos de interesse do 3D em escala horizontal de 1:1.
- O terreno, a costa e a mata agora são construídos de vetores; a vegetação usa
  instâncias leves e colisão de troncos apenas perto do jogador.
- A vista **MAPA** ganhou zoom, deslocamento e marcadores clicáveis. Um catálogo
  de regiões e importadores separam fonte, geometria e escolhas de cenário.
- O menu inicial passou a usar ações curtas; a saída pede confirmação.
- O controle geral de som ficou no canto superior direito, e as opções de áudio
  passaram a nomear os sons dos botões com clareza. A alternância agora usa
  ícones de som ligado e desligado.
- O passeio 3D ganhou um botão **HOME** para retornar ao menu.
- A abertura e os créditos passaram por uma revisão de texto voltada ao jogador,
  sem notas de implementação na interface.
- O 3D ganhou um histórico próprio, acessível pelo texto de versão e build no
  rodapé do painel inicial; o histórico abre no centro da tela.
- O cenário real da abertura ganhou um sobrevoo suave. Em **AJUSTAR**, é possível
  escolher entre **Parado** e **Sobrevoo**; a preferência visual é salva apenas
  no protótipo 3D.
- O menu ganhou **MAPA**, uma visão superior do cenário com acesso para retornar.
- Terra, ruas e rios voltaram a aparecer na câmera do jogo; a colisão da terra
  foi corrigida para impedir a queda e o reaparecimento contínuo do personagem.
- As oito ruas agora têm bordas visíveis e colisão caminhável. Dois pontos sobre
  a água, Rio e Pier, ganharam acessos desde a margem sem mover o KML original.

## 24/09/2026 — Abertura, áudio e cenário

- A travessia ganhou uma abertura sobre o cenário 3D, com narração, música,
  paisagem sonora e preferências de áudio separadas das partidas 2D
  (`0fcecdc`).
- A casa de Carro Quebrado entrou no cenário com escala e colisão ajustadas
  (`be97f26`).
- O pau-brasil e a referência para novos modelos ampliaram a paisagem
  (`6bd07ed`).

## 23/09/2026 — Primeiro passeio jogável

- O projeto 3D independente ganhou vila explorável, personagem, câmera em
  terceira pessoa, colisões e HUD (`243697e`).
- O personagem passou a usar animações de repouso, caminhada, corrida e gestos
  acionáveis no jogo (`1e77309`).
- As primeiras decisões de escopo e a base técnica foram registradas em
  documentos específicos do protótipo (`1b4080a`, `ee20191`).
