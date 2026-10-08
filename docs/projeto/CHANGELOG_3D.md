# Histórico de mudanças — Myths' Valley 3D

## Em desenvolvimento — 08/10/2026

- **O testador automático volta a abrir, e foi rodado ao vivo em quatro cenários.** O painel
  novo da sessão chamava o autoload `Audio` no `--script`, onde ele ainda não é nome global:
  nenhuma sessão subia (`Compile Error: Identifier not found: Audio`), e os testes Python não
  viam isso. Agora o painel busca o `Audio` na árvore. O `jogar.py --cenario` (só para
  verificação, registrado no relatório) abre a partida no meio de um caso: `lenha` (a ponte
  pedindo 36 paus, a picareta na mão, o machado só na mochila), `noite` (tutorial feito, dez da
  noite, fôlego curto), `varal` (o viajante junto do poste do varal da Casa do arraial 5, com a
  câmera atrás dele) e `f7` (a lenha com um F7 entrado pela janela). Resultados: o robô põe o
  machado na barra e corta (lenha 0 → 17, #207); acorda em casa, sai pela porta e segue a lenha
  no dia seguinte, em vez de dormir de novo manhã após manhã — a regra de sair só valia para uma
  lista fixa de objetivos e não incluía `pedro_ponte_lenha` (#191); o relógio andou antes e
  depois de três amanheceres (#192); F7 assume, o testador para, F7 devolve e ele recalcula, com o
  trecho no relatório (#206). Na tela de idioma o robô clicava sempre em "Português" e regravava
  a preferência: a sessão em English abria toda em português; agora confirma o idioma da sessão
  (#180). O período do relógio (Manhã, Tarde, Entardecer, Noite, Madrugada) passa a ser
  traduzido em en/es. Portões `tools/jev/test_idioma_botoes.gd` e, no `test_robo.py`, o do robô
  que acorda em recuperação e sai pela porta (#207, #191, #192, #206, #180).

- **Primeiros clipes do Mixamo nos moradores.** Seis animações do Mixamo entram
  redirecionadas para o esqueleto Tripo de cada um (`tools/prototipo_3d/mixamo/redirecionar.gd`,
  só rotações e o quadril, pé no chão, no lugar): o Pedro treina capoeira no posto quando o
  jogador está longe e para ao fim do golpe quando ele chega, e aponta o caminho na condução;
  o pescador pesca de vara e lança a linha de tempos em tempos; a beata reza de joelhos na
  igreja e no cruzeiro. A ficha em Modelos ganha a linha Animações, com o selo "Mixamo" e a
  prévia tocando o clipe; `data/mixamo_uso.json` traz o catálogo (2.484 itens) e o inventário
  por personagem, e o exportador do site, a seção `mixamo` com o percentual de uso. Os FBX não
  entram no repositório (licença). Portão `animacoes_mixamo` (#190).

- **A seta da missão orbita o jogador em vez de grudar na borda sobre o HUD.** Com o alvo
  fora da visão, o chevron dourado ia para a borda da tela e ficava por cima das barras, do
  relógio, da missão, dos atalhos e do minimapa. Agora gira numa elipse ao redor do
  personagem na tela, apontando o rumo do alvo medido a partir do jogador, com raio de 18 a
  25% da altura da janela (20% no HUD médio, e acompanha o tamanho do HUD de Ajustes). Se o
  ponto da órbita cair sobre um painel do HUD (grupo `obstaculos_do_hud`, o painel de espera
  incluído), ele desliza pela elipse até sair, ou diminui o raio; com o alvo à vista mas longe,
  o chevron que paira sobre ele se apaga se for cair sobre um painel. A mola, o giro e o fade
  de antes seguem iguais, então a volta para o cone sobre o alvo continua suave. O portão
  `seta_em_orbita` confere órbita, raio, rumo e desvio de painel (#196).

- **O relógio do topo vira o controle do tempo, e o bloco do topo se alinha.** A placa do
  relógio ganha duas colunas (o ícone centrado na vertical à esquerda, hora e período à
  direita, margens iguais) e passa a ter a mesma altura da pilha das três barras, 51 px
  em cima e embaixo, no lugar de 72 contra 84. As barras ficam mais finas (de 18 para
  15 px), com o número por dentro, e os ícones de coração, bateria e raio têm o mesmo
  tamanho e a mesma coluna; a reserva (barra amarela) ganha uma bateria em pé, com polo
  e três faixas, que não se confunde mais com uma maleta. O botão de relógio da coluna da
  direita saiu: clicar no relógio central pausa e retoma, com mão no cursor, realce
  dourado e balão com a hora e a maré. Os demais atalhos subiram uma vaga, sem mudar de
  ordem nem de tecla (o Tela cheia do vale agora é a vaga 4). O ícone do relógio, que
  vivia na coluna, mora na placa e acompanha o dia parado (#177).

- **A barra de mão (1 a 0) nasce menor.** Usa o padrão por componente da missão: a Mão
  abre em 80% (os dez espaços passam de ~76 para ~61 px em 1080p), o ↺ de Ajustes volta
  para esse valor, e quem já gravou um tamanho mantém a escolha. Plaquetas, ícones,
  quantidades, clique, arrastar e tooltip seguem a mesma escala do componente, e a
  reserva de baixo dos avisos e das dicas acompanha o tamanho novo (#178).

- **O painel de missão nasce menor e abraça o texto.** Cada componente da interface
  passa a ter o próprio tamanho padrão (`Tela.PADROES_COMPONENTE`, 100% para quem não
  está na lista), e a Missão abre em 80%; o ↺ de Ajustes volta para esse valor, e quem
  já gravou um tamanho mantém a escolha. O texto branco do objetivo desce de 17 para
  15 px, o contador "N de M" encosta na borda direita do painel (estava a 34 px, não
  15) e a sobra embaixo do objetivo cai de 36 para 14 px (a altura do painel contava o y absoluto do texto como se fosse relativo ao painel, 18 px a mais). O portão
  `interface_individual` confere os padrões (#176).

- **O marcador do jogador no minimapa se lê de relance.** O triângulo dourado, pequeno
  e da cor da areia, sumia no terreno claro e ao lado do losango da missão. Agora é uma
  seta (chevron com entalhe na base) cerca de 55% maior, dourado-claro, com contorno
  escuro de 2 px e um halo translúcido por baixo, que o destacam sobre areia, terra,
  grama, telhado e mar. O alvo da missão continua um losango âmbar, agora com contorno
  escuro próprio. Segue a escala "Minimapa" de Ajustes e o erro de direção do mapa
  doido; o portão do minimapa confere tamanho, entalhe, contorno e halo (#200).

- **A plaqueta da tecla dos atalhos laterais passa para a direita do botão, centrada.**
  O M, o C e o J ficavam no canto superior esquerdo do botão, soltos e no caminho da dica
  que abre à esquerda. Agora ficam à direita, no meio da altura, coladas à borda da placa,
  e encolhem o que for preciso para nunca sair da tela em nenhuma escala do HUD. A
  posição vem de uma função só (`_posicionar_tecla`), usada ao criar e ao reescalar; as
  plaquetas dos números da barra de mão não mudam. O portão das plaquetas confere lado,
  centro, tela e dica livre nas três escalas (#182).

- **O vale ganha o botão Tela cheia na coluna de atalhos, como o do menu.** Em janela,
  dentro do vale, não havia como voltar à tela cheia sem conhecer o F11. O botão fica na
  vaga 5 da coluna (logo abaixo do mapa, a mesma do menu), alterna tela cheia e janela,
  fica dourado em tela cheia e a dica ensina o atalho nos três idiomas; acompanha também
  o F11. Menu e vale agora usam o mesmo código, `BotaoCanto.criar_tela_cheia` (#181).

- **O testar.ps1 roda por lote e não roda nada por comentário.** A impressão
  digital de cada portão passa a ser semântica: o .gd sem comentário, linha em
  branco e espaço no fim (o '#' dentro de string fica), o .json sem espaço fora
  das strings (a ordem das chaves fica), e doc fora; só o portão que lê código
  como texto vê o comentário do que ele lê. A base padrão deixa de ser a
  origin/main crua: é o último commit que a máquina viu verde e o merge-base
  com a origin/main, então commita-se à vontade e testa-se uma vez por lote, com
  `-Push` obrigatório antes de enviar. A análise foi para C#
  (`testar_analise.cs`): o `-Explicar` cai de ~60 s para ~8 s com a máquina
  livre. Um comentário no tela.gd rodava os 216 portões e agora roda os 6 que
  leem o código como texto; reformatar o missoes_guia.json rodava 171 e agora
  roda 5. Cache de importação quebrado (o .glb com as texturas extraídas fora do
  disco, comum em worktree nova) é refeito numa importação única antes da
  bateria, em vez de reprovar cada portão como "NAO ABRE"; o paralelo desconta
  os portões de outras baterias na mesma máquina. O recorte por função de
  autoload foi medido e recusado (razões no topo do runner).

- **As divisas de terra no mapa deixam de ser retângulos amarelos soltos (#203).**
  O lote do cadastro vira um contorno orgânico de 48 pontos, de cantos redondos e
  ondulação leve por lote, traçado em tracejado fino sépia/ouro (verde-musgo nas suas
  terras), com preenchimento quase imperceptível. A legenda diz a situação ("Terra da
  Dona Zefa · à venda por 1800 réis", "· de Seu Benedito", "· Sua terra"), na sans de
  leitura, com uma plaquinha de casa, placa de venda ou marco, e foge de "Você" e dos
  marcadores dos lugares. As suas terras e as à venda aparecem sempre; as dos outros só
  no zoom de perto e somem ao afastar. O minimapa não herda divisas. Portão em
  `terras_por_posicao`.

- **Todo modal recolhe a interface do vale, e o texto para ler sai da Cormorant fina
  (#199, parcial).** Arraial, Diário, Teia, Coleção, folheto, menu do Esc, Controles,
  Apoios e Ajustes escondem missão, relógio, barras, atalhos, minimapa, dicas e avisos por
  um ponto só (`Prototype.modal_aberto`, a regra da #143 generalizada); os Ajustes ganham
  camada própria. A Identidade e o tema ganham quatro papéis de tipografia: título e
  rótulo (Cinzel), leitura (a sans do HUD, em creme) e ênfase (Cormorant itálico). Em K ›
  Fé, o nome de cada fé vira subtítulo de ouro, o corpo das regras vai para a sans em
  linhas curtas, e o rodapé de teclas vira plaquetas. O cinza apagado de antes (abaixo de
  4,5:1 sobre a laca) fica mais claro. Portão `modais_escondem_o_hud`. Falta conferir no
  jogo em zh e nas fichas do Diário que ainda usam a Cormorant itálica.

- **O Diário de missões cabe sem rolagem (#202, parcial).** Com uma aba só, a coluna das
  abas some e a página ganha a largura; com várias, ela encolhe. A ficha vira duas
  colunas (a voz de quem pediu em resumo à esquerda, os objetivos à direita, só eles
  rolando se faltar altura) e um rodapé fixo com a recompensa e o botão "Acompanhar",
  que nunca sai da caixa. A fala do Pedro aparece em até 200 letras, cortada em frase
  inteira (`CadeiaDeMissoes.fala_curta`; o campo `diario` do passo, opcional, sobrescreve
  com um resumo escrito à mão), em fonte de leitura. Portão `diario_sem_rolagem`. Falta
  revisar à mão as falas mais longas e conferir a mesma regra nas outras abas.

- **A dica do E ganha plaqueta grande, alvo em ouro e requisito em branco.** Em "Tronco
  caído / Ponha na mão: Machado" a plaqueta do E passa a ocupar a altura das duas linhas
  (quadrada, com a letra grande, o que o jogador procura de relance); o alvo vira título,
  em Cinzel ouro, e o requisito vira leitura, na sans legível do HUD, em creme e menor,
  como o aviso de baixo. A dica de uma linha mostra só o título, com a plaqueta da altura
  dela, e a caixa fica justa ao conteúdo, com margens parelhas. O padrão vale para toda
  dica do E (pegar, falar, cortar, entrar), que nascem da mesma peça. O portão
  `dica_requisito_e_mao` cobra rótulos separados, cores, fontes, plaqueta quadrada e a
  altura nas dicas de uma e de duas linhas, em pt/en/es (#188).

- **Ajustes ganha a aba Interface, e as abas viram ícones com tooltip.** Cursor, Tamanho do
  texto, Tamanho do HUD, Monitor e "Tamanho de cada interface" saem de Cenário para a aba
  nova, repartidos em duas colunas de 18 campos; o "Restaurar todas as interfaces" sobe
  para o cabeçalho, ao lado do ×, como os de volume. Cenário fica só com o vale (estilo,
  nomes, minimapa, maré, sustos) e, no menu, a seção Menu. As seis abas (Geral, Sons,
  Cenário, Interface, Atalhos, Esforço) mostram só um ícone, dourado na aberta, e o nome
  aparece no tooltip do mouse e também com o foco do teclado ou do controle. "Sons do vale"
  vira "Sons" na aba, na frase do restaurar e na ajuda do Ambiente; "Sons" e "Esforço"
  ganharam tradução para inglês e espanhol. O portão de Ajustes cobre as seis abas, os
  tooltips nos três idiomas, a dica no foco e onde mora cada campo (#169).

- **A fonte padrão da interface fica um pouco menor, e os Ajustes mostram mais itens por
  coluna.** O Médio do Tamanho do texto passa a ter corpo 17 (era 19) e botões 14 (era 15);
  Pequeno, Grande e Muito grande continuam multiplicando o novo padrão. Os tamanhos que o
  painel de Ajustes fixava no código (rótulo, seção, título e subtítulo do cabeçalho, texto
  e "?" da ajuda) viraram constantes do tema (`FONTE_ROTULO`, `FONTE_SECAO`...) e escalam
  junto; os campos ficam 56 px de altura (era 66) e os controles 32 (era 36). As placas da
  home mantêm os 15 de antes. O portão da tela cobra o padrão menor e proíbe número solto de
  fonte no painel (#167).

- **Restaurar volumes sobe para o cabeçalho de Ajustes, e a aba ativa tem uma moldura só.**
  "Restaurar estes" e "Restaurar todos" (com o ↺) ficam à esquerda do ×, na altura dele, em
  Geral e em Sons do vale; o rodapé deixou de existir e a lista ganha a altura, sem cortar
  "Teclas de movimento" e "Ambiente". Nas outras abas o cabeçalho fica só com o ×, no mesmo
  lugar. O aro de foco das abas perdeu a margem de expansão que o desenhava por fora da
  borda: a ativa mostra uma moldura do tamanho das outras, e o foco por teclado continua
  visível. O portão de Ajustes cobre posição, altura, ausência de rodapé e o foco (#166).

- **Os cartões do painel Modelos preenchem o modal.** A grade deixa de ter 4 × 3 fixos:
  colunas e linhas saem do espaço que sobra à lista (6 × 5 no tamanho padrão, 30 por
  página; Assets cai de 21 para 10 páginas), os cartões esticam para ocupar a altura que
  sobrava antes da navegação, o nome cortado aparece inteiro no tooltip e voltar da ficha
  leva à página do cartão dela. O portão do painel cobra ao menos 5 × 5 e a ausência da
  faixa vazia (#171).

- **Na sessão de teste a câmera não deixa o viajante escondido atrás de um poste.** A cada
  quadro um raio vai da câmera ao peito e à cabeça dele; se um poste, tronco, parede ou árvore
  barra, a câmera gira para o lado livre mais próximo com movimento suave, ou aproxima até
  passar à frente do obstáculo. As capturas do relatório só saem com ele à vista, e encoberto
  por mais de 1,5 s vira um achado. Só a sessão de teste muda: a câmera do jogo normal e as
  camadas dela ficam como estão (#201).

- **F7 tira o testador do volante e devolve, sem encerrar a sessão.** Quem assiste pega o
  jogo na mão: o testador para na hora (a decisão em voo é descartada e as teclas que ele
  segurava são soltas), uma faixa vermelha diz "Controle manual · F7 devolve" e o painel
  ganha o botão de assumir e devolver, nos quatro idiomas. F7 de novo devolve e o robô
  recalcula do estado novo, sem repetir o plano velho; F8 segue encerrando em qualquer
  estado. O relatório ganha a seção "Controle manual (F7)" com a duração de cada trecho e o
  que mudou (missão, itens, mão, deslocamento), para ensinar o determinístico (#206).

- **O testador entende "Ponha na mão: Machado" e põe a ferramenta certa na mão.** Antes ele
  passou umas 250 ações na lenha sem escolher o machado, porque ele estava só na mochila e o
  robô só olhava a barra de mão. Agora o estado traz, como dado, a barra de mão inteira, o
  requisito de ferramenta da dica do E e a última recusa; X na barra vira a tecla da vaga, X
  só na mochila vira abrir a mochila, trazê-lo para uma vaga livre da barra e selecioná-lo, e
  X inexistente vira a nota "Falta ferramenta X" no relatório (#207).

- **Ao clicar em Testar, o menu se fecha quando a janela do testador abre, e volta quando a
  sessão acaba.** Antes ficavam duas janelas do jogo, o dobro de memória e o áudio do menu
  junto com a sessão. Agora o menu espera o sinal de que o jogo da sessão subiu e só então
  se fecha; se o testador não iniciar, continua aberto e mostra o erro. Ao encerrar a
  sessão (F8, tempo ou erro) o menu é reaberto com o perfil normal do jogador. Dica e avisos
  foram atualizados em português, inglês e espanhol (#175).

- **A sessão do testador abre no idioma que o jogador escolheu.** O botão Testar manda o
  idioma atual (português, English, Español ou 中文) para o `jogar.py --idioma`, que o
  grava no perfil isolado da sessão: menu, tela de carga, HUD, falas em texto e o painel
  do testador, agora também em chinês, saem nele, sem copiar save nem progresso. O
  relatório registra o idioma usado, e rodar o `jogar.py` sem o parâmetro segue igual
  (#180).

- **O testador sai pela porta antes de ir a qualquer alvo de fora, e para de seguir o
  Pedro quando o tutorial acaba.** Dentro da casa, da igreja ou do casarão, seguir,
  aproximar, explorar ou ir ao objetivo passa primeiro pela soleira de dentro; preso num
  canto, ele força a saída duas vezes e sonda uma direção livre. Acabado o tutorial
  `follow_pedro` sai das ações e o Pedro é abordado como morador no posto dele, com
  limite de tentativas (#191).

- **O painel do teste automático ganha o visual do HUD.** Deixa de ser a caixa escura
  padrão do Godot: fundo de laca verde-escura, borda dourada suave e canto chanfrado,
  o tema do menu (Cinzel e Cormorant), título curto em destaque ("Testando") com a
  etiqueta de quem decidiu ao lado e, abaixo, a contagem de ações e o tempo. A ação
  atual aparece em palavras de jogador ("Aproximar de Tonho", "Andar para a frente"),
  com o nome técnico só na dica ao passar o mouse e no relatório. O Parar vira um botão
  do jogo, pequeno, com o F8 numa plaqueta de papel como nas dicas de interação. Na
  tela de carregamento o painel sai de cima do "CARREGANDO", da rosa girando, da marca
  e do almanaque, e no vale deixa livres a barra de mão, o minimapa e o resto do HUD.
  Textos em português, inglês e espanhol (#174).

- **O botão Testar abre um modal com o determinístico, o Jev e o GPT em escada, e o
  painel da sessão mostra quem decidiu e quanto falta para zerar.** O modal usa o
  cabeçalho dos outros: o determinístico é a base e está sempre ligado; o Jev e o
  GPT aparecem como opção marcável, desativada e explicada quando a chave não
  existe ou o serviço não responde ("Sem chave TypeSafe no .env"), com orçamento
  (padrão US$ 0,10, teto US$ 0,50) e duração opcionais; a ponte só diz se a chave
  existe, nunca o valor. Na sessão, o determinístico joga sozinho e, ao travar (25
  ações ou 90 s sem progresso, laço de posição, a mesma recusa duas vezes, o E mirando
  quem a missão não pede, `possible_stuck`), faz primeiro uma recuperação local e só
  depois pede ao Jev um plano curto, ao GPT outro com o plano que falhou, e por fim
  registra o bloqueio; no máximo 2 chamadas do Jev e 1 do GPT por passo, sob o orçamento
  da sessão, e o que destravou vira candidato a regra nova. O painel traz o nível que
  decidiu, a ação em palavras, o motivo, a missão, as últimas quatro decisões, o gasto,
  um "F8 parar" pequeno e a barra de quanto falta para zerar o jogo, com um marco por
  capítulo, o capítulo atual, o próximo objetivo e a estimativa de ações e tempo; fica
  no canto livre do HUD. O relatório registra cada escalonamento (quem, por quê,
  custo), o bloqueio, o aprendizado, o progresso e o ponto mais distante, e a câmera
  do teste abre mais afastada. As chamadas ao Jev e ao GPT foram escritas e testadas só
  com respostas falsas, e `--escada-simulada` roda a escada sem crédito; nenhuma chamada
  paga foi feita (#183).

- **A colisão das casas acompanha a parede visível, e o viajante para encostado em vez de
  entrar nela.** Na casa da Dona Zefa metade do corpo atravessava a quina da fachada, ao lado
  da porta. Eram duas faltas na colisão que o cômodo põe no lugar da caixa inteira: a parede
  acabava um palmo para dentro da face de dentro da casca (e a parede do modelo tem a
  espessura dela), e ao lado do vão a fachada só tinha 20 cm sólidos no fundo da porta. Agora
  a montagem mede a face de fora da casca por raios (laterais, fundo e a fachada fora do vão,
  em duas alturas de peito, pela mediana) e o cômodo cobre o que falta até ela, só de colisão,
  com as ombreiras da porta sólidas e a fachada inteira de cada lado do vão, até o teto.
  Varanda e rampa da soleira ficam encostadas em parede sólida, sem atalho para dentro. O
  portão novo `colisao_das_casas` põe a malha visível de cada construção numa camada de
  auditoria e mede, por fora, quanto a colisão está dentro da face visível (fachada, laterais,
  fundo), sem parede de ar nem buraco; e o testador automático registra
  `player_inside_geometry` quando o peito do viajante entra numa malha fora do cômodo e do
  corredor da porta (#205).

- **O golpe de ferramenta só sai encostado e de frente para o alvo.** O machado dava
  machadadas no ar: o alcance era 3,2 m somados à meia-pegada da peça, e o corpo nem
  virava. Agora o golpe vale a 1,2 m da FACE da colisão (caixa girada, quina e cilindro,
  e não mais o raio da meia-pegada); o E ainda se oferece até 3,2 m da face, e de mais
  longe de 1,2 m o viajante anda até um ponto a 0,8 m da face, gira para o alvo e só
  então bate (a dica diz "ir até lá"). Um impacto com o corpo levado para longe no meio
  do clipe não cobra nem derruba. O lajedo e as outras peças grandes seguem alcançáveis,
  porque a distância é da face. A pilha de lenha ficou na altura da cintura (de 1,6 m
  nos roçados para 0,9 m) e o tronco caído com uns 50 cm de diâmetro (era 65 cm). O
  testador espera o viajante andar e girar antes de contar o golpe. O portão
  `alcance_dos_alvos` mede o alcance curto dos quatro lados pela face, e o novo
  `golpe_de_braco` confere a escala, o E de longe e o impacto fora do alcance (#208).

- **Quem dorme, desmaia ou cai acorda parado, em pé, no clipe do parado.** O corpo
  acordava na pose de antes (correndo, nadando, de machado na mão) porque o processo
  físico fica desligado durante a noite e é ele quem troca o clipe. Agora, com a tela
  ainda no escuro, o viajante larga corrida ligada, passeio clicado, pulo, nado, golpe
  e ferramenta em uso, e o animador toca o parado do primeiro quadro, sem mistura com
  o clipe anterior; vale para a cama, o desmaio das 2h e a queda. A pose de acordar
  sai de uma tabela por motivo (`POSE_DE_ACORDAR` em `queda.gd`), o gancho para um
  "levantar da cama" no lugar do parado. O portão `tests/acordar_parado.gd` dorme no
  meio de uma corrida, de um golpe e do nado pelas três portas e confere clipe,
  velocidade e posição (#189).

- **O chão perde as quinas retas e as escadinhas.** Na praça e nas ruas da igreja, a terra
  da rua, o pasto, a areia e a mancha escura junto às casas se encontravam em "L" e em
  degraus de pixel, porque o mapa de solo pintava retângulos de 1 pixel por unidade e a
  rua era suavizada pela metade das outras. Agora a pintura é subamostrada (2 x 2 por
  pixel), toda camada larga tem rampa de ~4 u (a rua incluída), a copa de cada árvore é
  uma mancha redonda e irregular em vez de um quadrado, o traço estreito (trilhas, pé de
  árvore) ganha camada própria de rampa curta e o shader desvia a leitura do mapa por
  ruído, de modo que as fronteiras serpenteiam; a areia também passa a esconder o pasto
  sem degrau. Piso de casa, calçada e cerca não estão no mapa e seguem retos. O portão
  `mapa_de_solo` mede o maior salto entre pixels vizinhos de cada camada e tem
  `--falsificar-quinas`. Falta voar de cima pela vila, praça, praia e fazenda e conferir
  antes e depois (#197).

- **O dendezal ganha chão próprio.** Os dendezeiros ficavam plantados na grama lisa: o
  mapa de solo pulava o dendê (e o coqueiro) ao pintar o folhiço sob as copas. Agora o
  dendê pinta a mancha de folhiço e palha caída com 3,5 a 6,5 u (peso 0,7, a borda é
  rasgada pelo ruído do shader e deixa a grama aparecer entre os pés), o coqueiral da
  orla segue de areia, e o forro do dendezal ganha capim entre as samambaias. Falta
  medir o FPS e ver nas quatro estações (#195).

- **Os varais dos quintais voltam à escala de gente.** Os três varais Tripo eram
  medidos pela largura da corda (3,6 a 4,2 u), e como os modelos são altos e estreitos
  as estacas chegavam a 3,5 u, passando da cabeça do viajante. Agora são medidos pela
  altura (1,9 u, contra 1,75 u do viajante); a corda fica com 2,2 a 2,7 u. A âncora
  "Casa/Varal" da lavadeira não muda de lugar. Um portão novo mede os três varais
  instanciados e reprova altura fora de 1,7 a 2,1 u. Falta conferir na galeria de
  Modelos os três lado a lado com o viajante e olhar a roupa no varal em escala humana;
  o portão só confere a altura que o catálogo já define, não a roupa (#194).

- **O Histórico do jogo chega a 07/10, agrupando os dias curtos.** O rodapé do menu parava em 05/10 e pulava dias. Entram 06/10 (casas por dentro, vozes, maré, bichos e sustos) e 07/10 (favores dos moradores, estações, lavoura, compra de terra, nome do viajante) com entrada própria; 27/09 junta-se a 28/09 (`27–28/09/2026`) e 02/10 a 01/10 (`01–02/10/2026`), e as três linhas de 02/10 que estavam na entrada de 03/10 voltaram para o dia delas. Cada linha vem em pt/en/es com um termo dourado. `build_numero` segue 9: numerar build continua sendo decisão de release. A regra no `AGENTS.md` agora diz que o histórico acompanha os dias (#170).

- **O cachorro anda nas quatro patas.** O Caramelo seguia o Pedro empinado nas patas de
  trás: o clipe do GLB balançava o ombro e o pescoço como se fossem perna e a frente
  inteira subia e descia (o mesmo na onça pintada). Agora esses ossos ficam no repouso,
  as duas patas da frente andam em contratempo copiando a de trás e param juntas, e o
  corpo do bicho de casa inclina o focinho com a rampa. A #149 segue aberta (aves, bode,
  corrida dos gatos); pesquisa de Mesh2Motion e do rig do Tripo em
  docs/ferramentas/ANIMACAO_DE_ANIMAIS.md.

- **O ingazeiro deixa de vir pousado numa laje de terra.** O GLB do Tripo trazia a
  árvore de pé numa laje de uns 7 m por 5 m e meio metro de espessura, de fundo
  reto e beiras retas, que no vale aparecia como uma plataforma elevada à beira do
  caminho e boiava no declive. A laje saiu dos três GLBs (principal, leve e de
  longe) com `tools/tripo/tirar_base_de_terra.py`: 1.026 de 16.886 triângulos no
  principal, e o tronco com o pé de raízes ficou. Textura, UVs, materiais e
  escala não mudaram (a `altura` do catálogo foi recalculada para 7,03, 7,07 e
  6,92, e a da receita do paisagismo para 7,07), e os GLBs conferem sem erro no
  validador do glTF. Sem a laje, o tronco do ingazeiro leve e o de longe aparecem
  de costas em 9% e 12% dos raios e entram na lista de duas faces da #156. Um
  portão novo soma a área de base virada para baixo de cada árvore e reprova o que
  passa de 5 m² (a laje tinha mais de vinte). Falta ver no jogo, no ingazeiro do
  caminho da chegada, e o apoio de todas as árvores no declive pelo pé do tronco
  (#141).

- **A colisão das árvores é auditada espécie por espécie.** Um script lê cada
  GLB, atira raios horizontais no eixo do tronco e compara o raio da madeira com o
  cilindro do catálogo: 29 das 32 espécies de tronco ficam entre -0,21 e +0,32 u (o
  corpo do jogador soma 0,28), nenhum cilindro passa de 3 m, e as que não têm
  fuste único (mangue, bambu, gameleira) ficam anotadas com a razão.
  Nenhum raio mudou. Um portão sem montar o vale cobra o teto de 3,5 m do
  cilindro, colisão em toda árvore de ficha e o paisagismo repetindo o raio e a
  altura do catálogo. A passada a pé junto de bases e raízes fica para o jogo
  aberto (#150).

- **Os troncos do ipê, da pitangueira e de mais oito árvores deixam de parecer
  ocos.** O Tripo fechou o fuste dessas árvores com os triângulos virados para
  dentro, e o descarte das faces de trás (ligado nos GLBs para ganhar quadros)
  fazia sumir a parede da frente do tronco: via-se o lado de dentro da parede do
  fundo, como fenda. Todos os materiais dos GLBs já eram de duas faces, então o
  defeito era o sentido da malha, não o material. Um portão mede cada árvore de
  tronco por raios horizontais ao pé dela: as íntegras dão 0 a 6% de primeiro
  triângulo de costas, as dez afetadas (pitangueira e a leve, ipê-amarelo,
  licurizeiro, clusia leve, jenipapeiro leve, mangue leve e de longe, castanhola
  de longe, piaçava de longe) 12% a 79%. Só essas voltam às duas faces
  (`TRONCO_DE_COSTAS`), com as normais do GLB já acompanhando o sentido da malha,
  e as demais seguem com o descarte ligado. Nenhum GLB, textura ou escala mudou
  (#156).

- **Todo campo de Ajustes tem o "?" de ajuda, e "Passos na água" ganha o ↺.** O campo
  era montado à mão, com um botão Ouvir que encurtava o seletor: agora é uma escolha
  como as vizinhas (Original ou Novos, ↺ volta a Original) e trocar a opção já toca a
  prévia do passo. Ganharam texto de ajuda em português, inglês e espanhol: Passos na
  água, Nomes dos personagens, Minimapa, Maré, Sustos, Câmera do mouse, os Atalhos, os
  sete custos da aba Esforço e os 32 tamanhos de "Tamanho de cada interface" (Missão,
  Relógio, Vida, Fôlego, Vigor...). Um portão varre as cinco abas, no menu e no jogo,
  nos três idiomas, e reprova campo sem "?" (#168).

- **O Gravar do painel Modelos só fica ativo com ajuste pendente.** Sem nada a
  gravar o disquete aparece apagado, sem hover, sem clique e fora do foco do
  teclado, com a dica "Nada para gravar"; editar um campo o acende na hora e
  gravar o apaga de novo (#172).

- **As etapas da missão ganham marcadores que a fonte do jogo desenha.** "Arar,
  plantar, regar" saía com "□" e "✓", que caíam na fonte do sistema (pequenos,
  finos e fora da linha de base, como glifo quebrado). Agora a etapa feita é
  "●" e a por fazer é "○", no quadro da tarefa e no diário (J), para toda
  missão com etapas; o HUD leva a Cormorant como fonte de reserva e o "✓" dos
  passos já cumpridos no diário também virou "●". O contador "(0/3)" segue
  junto (#186).

- **O botão do menu que abre o testador automático passa a se chamar TESTAR.**
  Um verbo de uma palavra como JOGAR e EXPLORAR, que não enche mais a placa
  (TEST em inglês, PROBAR em espanhol); a ação e o aviso ao iniciar seguem os
  mesmos, e os documentos do testador falam em "Testar" (#173).

- **O × da tela de idioma fica um pouco mais evidente em repouso.** O fundo da
  placa sobe de 0,35 para 0,6 e a opacidade de 0,6 para 0,8 (efetivo perto de
  0,5, antes 0,21), legível sobre o céu claro e ainda mais discreto que os
  botões de idioma; o hover e o foco acendem como antes (#165).

- **A main da equipe (playtest e missões secundárias de 07/10) junta-se às
  fatias locais de 07/10.** As cercas das roças ficam em lances retos de
  canto a canto, em pé e com um corpo só por lance, que barra o jogador e
  os moradores; a entrada da roça continua livre, sem a porteira imóvel
  (#152). A volta de quem cai no rio grande segue a rampa da beira de cá da
  main (#115), que cobre também o caso junto à ponte (#161). O aviso do
  rodapé é a caixa da identidade do vale, com prazo e cedendo às falas; a
  enxada mantém o próprio ritmo e o golpe de sempre termina quando a mão
  volta.

## 07/10/2026: cobertura das cadeias de idiomas (#47)

O teste passa a cobrar Candinha, Filo, Tonho, Zefa, arraial e recursos, incluindo os títulos. Toda cadeia `missoes_*.json` precisa declarar cobertura ou pendência. A grafia espanhola de "Tronco caído" tem uma exceção restrita aos cinco recursos revisados. O portão verifica 694 campos; remover `titulo_en` em memória com `--falsificar-titulo` provoca a falha esperada sem alterar o conteúdo da partida. As 8 entradas e 15 arquivos pendentes continuam registrados.

## Em desenvolvimento — 07/10/2026 (experimento Jev)

- #155/#37: liberar explicitamente o elenco completo não é revogado por
  uma atualização manual do calendário. Visitas continuam obedecendo ao
  dia; recalcular não oculta Cosme/Filó/Damião por orçamento. Apresentação
  passa em 36 s; reabrir o orçamento reproduz uma falha.

- #78: galeria existente passa navegação, edição de moradores/peças, voz,
  prévia e pendências. Seis imagens gráficas conferidas; retirar a prévia
  reprova. #34 recebe capturas opcionais e resolução efetiva no benchmark;
  A/B/B/A mostra quedas de 56% a 85% nos triângulos em três câmeras.
  A bateria final ainda precisa sustentar o encerramento do LOD.

- #155/#132: apresentação gradual não sobrepõe o calendário do saveiro;
  chegada/partida atualizam o orçamento de moradores imediatamente e as
  placas de atores ocultos somem sem esperar o fade. Saveiro (48 s),
  apresentação (39 s) e matriz de balões (12 s) passam; forçar a visita
  fora do dia reproduz duas falhas. A guarda de saudação permite primeiro
  a interação prioritária das cadeias (integrada junto da #160).

- #138 (parcial): a extremidade da areia também se desfaz sobre o fundo
  do mar. Renderização real comprova o recorte; mutante reprova duas
  verificações. Travessia a pé/nado e maré passam. Emendas da foz seguem abertas.

- #9 (parcial): posse e compra com o dono pelo E após conhecer a chapada.
  Confirmação, preços históricos, vizinhança Zefa/Benedito e desconto de
  Gente fina preservam missões, presentes e moradores. Save/vagas levam
  posse própria; o mapa recebe contornos cadastrais verdes/âmbar por âncora.
  Cinco gates passam e retirar o consumo do bônus reproduz duas falhas.
  Construção portátil e revisão visual/geográfica continuam pendentes;
  #9/#22 permanecem abertas. Nenhum asset pago foi gerado.

- #151: chão verde recebe mistura rotacionada também perto da câmera;
  capim de forro varia de 60% a 95%; vegetação baixa acompanha a normal
  do chão. A missão do cemitério conserva seus oito tufos altos. Cinco
  gates verdes, mutante com seis falhas e três áreas conferidas visualmente.

- #18 (parcial): inventário dos quinze contratos do 2D e das 32 perguntas
  de contexto 3D; regras de afinidade, receita, foco e fração portadas.
  Cordel passa pela confirmação nativa de presente. Passo, lenha extra,
  alcance de cordel e vista no topo da Lombada têm consumidores reais;
  cansaço, corte recusado, cartas e colisão da câmera permanecem preservados.
  Baseline anterior reprova três usos; mutantes dirigidos também reprovam.
  Auditoria estrita acusa cinco consumidores e permanece fora da bateria,
  sem allowlist. Favor depende da compra de terra #9/#22; #160 foi reaberta
  após constatar ausência de produção/tutorial equivalentes no HEAD.

- #33 concluída: a prévia geográfica foi instanciada e renderizada com o
  editor ativo; menu 3D e vale geram uma única terra no runtime. Dois gates
  complementam a verificação de recursos; mutante sem composição reprova.

- #1 concluída por auditoria: 16 passos em dados, enredo/dia a dia, diário
  e acompanhamento integrados ao HUD e à bússola. A decisão posterior do
  autor pelo mecanismo nativo substitui o checklist antigo; cinco gates
  verdes e a chegada real V21 documentados em `MISSOES_NAS_ANCORAS.md`.

- #140 (parcial): o folheto recebe escala própria como 32º componente.
  Papel, capa e textos acompanham o ajuste, limitados pela área de leitura;
  o fundo continua inteiro. Leitura integrada e escala verdes, mutante
  reprovado e três vistas reais conferidas.

- #140 (parcial): 31 componentes com escala individual, incluindo oito
  telas do lobby e confirmação. O painel reutilizado segue a preferência
  atual sem acumular eventos e respeita o espaço até as bordas da janela.
  Quatro gates verdes, falsificação reprovada e cinco capturas conferidas.

- #149 (parcial): passeio e corrida usam referência própria da espécie,
  separada da passada medida no clipe. Bichos de casa animam o movimento
  efetivo após colisões; aves acompanham o último passo até seu destino.
  A ronda da criatura continua distinta da carga, sem alterar a caça.
  Ritmo, inventário de 23 modelos, animações e rotinas dos bichos passam;
  mutantes reintroduzem os defeitos. Vídeo local e limites de aves, bode
  e corrida constam em `ANIMACOES_DOS_ANIMAIS.md`; a issue permanece aberta.

- #99/#125/#150 (parcial): caminhos atravessam cômodos pelas soleiras;
  portas trancadas não recebem travessia forçada. A reserva de troncos
  inclui sua inclinação à altura do agente. Navegação e igreja nos dois
  sentidos passam; mutantes restauram os bloqueios no umbral e na orla.
  A ponte central ainda impede concluir a revisão global.

- #159 concluída: além da chegada real da V21, o botão Teste automático do
  menu abriu uma partida nova em perfil separado. F8 encerrou o filho normal
  com `user_stop`, 19 decisões, 33,2 s de jogo, custo zero, código Godot 0 e
  captura final. A espera do watchdog fica comprovada pela parada real.
  Gates de rota/apoio e 87 testes Python verdes, falsificações reprovadas;
  campanhas laterais e capítulos futuros permanecem fora dessa vitória.

- #164 concluída / #159 parcial: V21 atravessa a ponte e chega ao pátio pela
  missão normal aos 483,44 s, posição (118,2; 3,6; -308,2), com
  `implemented_story_completed=true`, 110 decisões e custo zero. Aproximação
  do guia mantém waypoints e só aceita reta com apoio físico contínuo.
  Gate físico leve passa e mutante direto falha. O watchdog ganha prazo
  para /stop/captura final; 87 testes Python passam e mutante sem prazo falha.
  Menu/F8 e parada real do handshake corrigido ainda precisam de evidência
  específica; isso não declara concluídas as cadeias laterais do vale.

- #125 (parcial): cada cerca em MultiMesh recebe corpo na mesma posição,
  escala e inclinação, lido pela navegação. Candinha chega fisicamente à
  Zefa; navegação e encosta passam. O passeio completo ainda reprova em
  dois bloqueios que também aparecem no baseline sem cercas novas.

- #142 (parcial): cercas preservam cantos e unem as extremidades reais,
  ajustadas ao relevo. Reserva também vale nas pontas; uma peça isolada
  entre obstáculos é removida. Quatro gates verdes, mutante do comprimento
  reprovado e cinco capturas conferidas. Paisagismo passa a cobrar ausência
  da porteira decorativa retirada na #152. Circulação completa segue #125.

- #164/#159 (parcial): a malha inclui a fazenda e o catálogo mantém apoio
  contínuo nas tábuas da ponte com juntas curtas. Corrimãos não viram piso
  de navegação; NPCs reconhecem apoio seco e a lâmina do rio elevado.
  Rota física isolada chega ao portão; mutantes de limites e juntas falham.
  Rio grande e colisões passam. A fixture da ponte espera a fala natural
  (#121), eliminando uma cascata também reproduzida no HEAD. Campanha real
  ainda precisa confirmar a chegada; nenhum progresso foi injetado.

- #154: o marcador da entrada usa a soleira externa do cômodo, sem apontar
  à janela ou ao centro da casa. Pedro mantém sua espera ao lado da porta.
  Casa nos dois estilos e missões passam; alvo na parede produz a falha
  esperada. Captura do marcador real conferida, sem erro de script.

- #159 (parcial): após o chamado da fazenda na cama, o testador sai pela
  soleira antes de acompanhar Pedro. Na V17, a saída por movimento normal
  concluiu aos 423,80 s, e a condução seguiu fora da casa. 85 testes Python
  passam; mutante sem prioridade da porta falha. Jornada ainda em curso.

- #159 (parcial): testador volta pela porta à cama quando falta comida e
  fôlego; distingue o convite que aguarda outra manhã de uma conversa nova.
  V16 concluiu Mirante/Fé e V17 usou E/Sim na cama: dia 25 → 26, fôlego
  27,8 → 77,8, dia da fazenda marcado pela regra nativa. 84 testes Python
  verdes; mutante sem a espera pela manhã falha. Campanha ainda em execução.

- #108 (parcial): linhas do J mostram ícones do catálogo e custos como ícones
  com ×n, apagados por ingrediente insuficiente. A linha selecionada mostra
  a tecla de interação vigente. Cormorant, índices, texto dos botões e ações
  são preservados; os ícones deixam o clique passar. Oficina, Cozinha,
  Cartas, Obras, Venda, Jogo e Vagas foram conferidos com captura; painel,
  obras e oficio passaram. O mutante que apaga custos reprova o novo gate.
  Trabalho continua dependente de #9; a piaçava ainda usa símbolo de catálogo.
- #140 (parcial): dezoito componentes ganham tamanho independente, persistência
  e restauração individual/todos. Texto, ícones e área clicável acompanham a
  transformação. O HUD reorganiza medidores e avisos pela escala; a matriz
  reserva os retângulos reais. Gates de independência, três resoluções/idiomas,
  prioridade e tarefa verdes; mutante sem escala reprova. Composição real
  com 150% conferida em PT/EN/ES. Falta auditar telas secundárias e texto global.

- #126: C percorre Livre/Arrastar/Automática e salva a preferência. A câmera
  acompanha o movimento suavemente, mantém o rumo das teclas durante o giro
  e procura lados livres com histerese. Até oito árvores/barcos próximos
  fornecem geometria reutilizada; o que encobre o corpo desvanece e volta
  ao sair. Capturas conferidas no vale, gate de caminhada real verde em 51 s;
  câmera/telas e cliques verdes. Falsificações de desvio/visibilidade reprovam.

- #99 (parcial): navegação usa o mesmo raio físico dos coqueiros, incluindo
  a base. Reproduziu passagem por tronco na versão anterior; gate verde
  em 63 s após a correção. Fixture da Filó libera a população gradual.
  O aceite da bateria inteira ainda está pendente.

- #159 (parcial): JPEG 85% nas capturas contínuas, links também para PNG e
  checkpoints pelo menu normal a cada cinco minutos/lote de oito materiais,
  após golpes em curso. 82 testes Python verdes; remover checkpoints ou
  ignorar JPEG reprova. Save confirmado ao vivo na V15. V13 esgotou o disco
  e perdeu coleta após o último save; evidências preservadas em outro volume,
  campanha retomada sem reconstrução artificial de progresso.

- #159 (parcial): o robô observa custos reais, agrega ingredientes antes de
  viajar à bancada e mantém o alvo de material acessível. Seleciona a obra
  exigida, detecta viagens sem aproximação e tenta contornos físicos;
  acompanha dano parcial, espera golpes, come pela mochila e retoma o guia.
  Perfil isolado pode ser retomado por opção explícita. 78 testes Python
  verdes, sondas Godot de nome, guia, fonte e F8 verdes; falsificações de
  custo, contorno e alvo do E reprovam. V13 coleta pedra e madeira para o
  Mirante; campanha ainda não concluída. Nenhuma API paga ou teleporte.

- #64: B remapeável abre apoios e talentos ativos, com escolha explícita e
  uso uma vez por dia. Interface na moldura do vale, PT/EN/ES, teclado/mouse;
  pausa e câmera passam pelo gerenciador comum. Atalhos verde (3 s), uso
  verde (4 s), idiomas verde (5 s), painel verde (57 s), câmera com trocas
  entre apoios e outras telas verde (50 s). Mutante de reuso acusa uma
  falha sem erro de compilação. Instruções antigas do R foram atualizadas.

- #158 (parcial): casa do viajante sem roupas estendidas. Varal independente
  desativado na composição autoral e retirado da tabela padrão; malha, escala,
  entrada e colisão da casa preservadas, assim como 19 outros varais.
  `casa_sem_varal` verde (3 s), composição verde (35 s); reativação do adereço
  reprova. Novo modelo Tripo não foi gerado nem o ticket encerrado.

- #163: fontes de material respeitam nível e grau de ferramenta. A nova
  consulta estrita evita mandar o testador à pedra impossível. Regressão
  `alvo_material_acessivel` verde (2 s), alcance (57 s) e ofício (42 s);
  retirar os requisitos reprova três condições, sem erro de script.
  Coleta real V13: oito pedras pelo E aos ~609 s, após descer do Mirante
  sem teleporte, material da missão 0/35 → 8/35. #159 continua em execução.

- #65: continuidade do Pedro documentada pelo roteiro do 3D. Novo portão
  `continuidade_pedro` verde (42 s); remover a meta da caderneta reprova duas
  condições sem erro de script. `lombada` verde (106 s) após corrigir a
  preparação: despedida na cadeia, e espera real pela fala antes do próximo
  E, preservando o bloqueio contra falas sobrepostas. A sequência física da
  lapa, cabra, conversa e save foi conferida.

- #53: `licoes_de_luta` verifica as filas vivas do Pedro e Cosme, o ensino
  no anúncio, a prática pelos sinais de combate, fé/mesa da folha e a meta
  de caititus. Verde em 48 s; `--sem-licao` reprova os quatro golpes, sem
  erro de script. A implementação já existia; o contexto da issue estava
  desatualizado. A mecânica dos golpes continua coberta por `luta`.

- #71: decisão de manter os 39 símbolos PixelLab já existentes para a teia,
  encerrando a condição provisória. Origem explicitada nos créditos e decisão
  em `ASSETS_TRIPO.md`; a identidade visual do 3D continua na apresentação da
  teia. Não foi feita geração paga. Aprovação autoral final permanece na #41.

- #128: o E da conversa usa o alvo atual, sem depender de `_perto` do último
  `_process`. `conversa_no_mesmo_quadro` passa antes do primeiro desenho e
  depois de o alvo sair do alcance; `--alvo-atrasado` reprova. `missoes_elos`
  passa sozinho (57 s) e com a regressão em paralelo (75 s), nas cinco horas.
  A preparação libera o elenco, respeita a visita sazonal e interrompe falas
  artificiais disparadas pela troca de passos. No Bar, conversa 0 versus
  Achados 4,33; o erro era o cache do alvo, não discordância do foco.

- **Docs: o guia acompanha o jogo atual (#72).** Abertura, save, mapa,
  idiomas, rig, gestos, lavoura, espólio e comentários de interface revistos.
  Custos e decisões antigos permanecem identificados como históricos;
  a definição de pronto continua dependente das evidências de release.
  O plano aponta para a fotografia completa do board em 07/10.

- **A chegada mantém o HUD legível (#120).** Composição com missão, fala
  real e aviso de espera nos três idiomas: sem rótulo persistente de mão,
  sem duplicar a fala no rodapé e sem sobrepor espera e balão. Barra,
  tarefa e prioridades passaram; forçar o rótulo reprova três vezes.
  Capturas locais conferidas; o descarregamento gráfico ainda emite o
  aviso de textura/RID acompanhado em #43.

- **O contrato de lugares cobra os nomes que prometeu (#54).** Os 18 alvos
  dinâmicos ficam declarados com o sistema que os encontra; `curral` tem
  razão concreta. Uma lista independente de 48 nomes e os JSON de missão
  detectam omissões; retirar `porta` reprova, sem erro de script. O portão
  espacial passou com 35 marcos resolvidos e 20 nomes sem âncora fixa.

- **O povoado se apresenta em pequenos grupos (#155).** Quatro moradores
  essenciais preservados, opcionais por região/tempo/progresso, entrada
  de 0,8 s e repouso de movimento/rig/colisão fora de cena. O save guarda
  o tempo; retomar não expõe quem se recolheu em casa. Apresentação, rotinas,
  bichos dos dois estilos e save passaram. Liberar tudo reprova os três
  limites. Mesma vista da praça: média 33,33→59,73 FPS, mediana 29,33→13,77 ms;
  p95 52,78→54,88 ms, ainda há picos. Condições em POPULACAO_GRADUAL.md.

- **O alvo de material permanece durante o caminho (#159/#162).** Contornar
  obstáculos deixa de trocar a árvore escolhida a cada quadro. Fonte
  esgotada escolhe a próxima; novo objetivo refaz a escolha. O baseline
  reprovou oito consultas consecutivas; a regressão passou com o cache.
  A coleta real do autoplay confirmou o alvo estável e a troca após cortar.

- **A teia de habilidades amplia e arrasta (#20).** Roda entre 65% e
  180%, botão central para percorrer; a área de clique acompanha a escala
  mesmo quando a interface inteira está redimensionada. Ficha e rodapé
  conservam o tamanho. K, Tab, L, P, arrasto, limites e seleção pelo mouse
  passaram, junto das teias e do almanaque. Desligar o mouse provoca cinco
  reprovações. Captura ampliada conferida em scratch/teia.

- **Pedidos compostos também indicam a matéria-prima (#162/#146).**
  Se o primeiro item faltante exige fabricação e não tem ponto de coleta,
  o marcador continua procurando os demais materiais faltantes. O Mirante
  deixa de apontar apenas a oficina quando faltam tábuas e lenha. O portão
  de madeira cobre a combinação; a interrupção anterior reprova.

- **A caça deixa espólio no chão (#67).** Recolher com E usa o mesmo
  árbitro das outras interações. A gravura do item identifica a coleta,
  que permanece no save até ser recolhida; mochila cheia preserva a
  recompensa. Combate, coleta, idiomas e save passaram. Desligar a
  recepção de E provoca cinco reprovações. Captura conferida em
  scratch/coleta/antes-do-e.png. O teste de save também acompanha o
  formulário de nome e declara o atalho da mochila como preferência.

- **O calendário muda a atmosfera do vale (#17).** Materiais das árvores
  Tripo e folhagens procedurais existentes acompanham as quatro estações,
  sem trocar texturas nem acumular tinta. A luz solar e os volumes de aves
  e insetos variam junto com o calendário. Estações e céu passaram;
  retirar a aplicação sazonal provoca nove reprovações. Capturas das
  quatro estações conferidas em scratch/estacoes.

- **A enxada ara no contato com o solo (#145).** O golpe reproduz a
  velocidade normal, conduz o cabo pelo lado do ombro e aplica a ação
  aos 45% do clipe. Repetir E não reinicia nem cobra novamente;
  cancelar antes do contato preserva terra e energia. Medição em movimento
  limita a intrusão a menos de 10% (antes, 30%). Gesto, itens, lavoura
  e corte passaram; retirar o trajeto reprova. Folha de cinco poses e
  três vistas conferida em scratch/enxada-depois/mao_enxada.png.

- **O marcador de madeira continua após esgotar os troncos (#162).**
  Passa a apontar a árvore acessível mais próxima, respeitando produto,
  proteção, talento e aço. A oferta informa o corte em andamento para
  evitar cancelá-lo com outro E. Portões de alvo e corte passaram;
  o código anterior reprova. A campanha real passou de 21 para 25/36
  lenhas pelos controles normais, sem alterar inventário ou progresso.

- **A partida começa pelo nome do viajante (#56).** Vaga nova pergunta
  o nome antes de iniciar; cancelar ou deixar vazio preserva a partida.
  O save guarda e restaura o nome. Travessia, caixa de diálogo e balões
  substituem `{jogador}`. Nome, escolha e idiomas passaram; retirar a
  pergunta reprova. Captura do formulário conferida.

- **Os sete moradores reconhecem o vínculo (#13).** A conversa pelo E
  alterna respostas de conhecido ou amigo com a prosa e as vozes originais,
  nos três idiomas. Missões e avisos mantêm prioridade; presentes e
  conversas continuam alterando afinidade com seus limites diários.
  Afinidade, conversa, idiomas e rotina passaram; retirar a seleção
  social provoca 252 reprovações no portão novo.

- **A entrada da roça fica livre (#152).** Sai a porteira decorativa
  imóvel que aparecia isolada perto do cemitério. Um lance fica aberto
  e os vizinhos permanecem. Entrada real e cercas na encosta passaram;
  reintroduzir a peça reprova. Captura do cemitério conferida.

- **Quem cai no rio pode voltar ao vale (#161).** A flutuação usa a
  lâmina de água local, e a lateral da margem junto à ponte permite o
  retorno. Cabeceiras e barranco oposto continuam impedindo a travessia.
  Rio grande, nado parado e colisões passaram; a fixture reprova antes
  da correção. O jogador automático também saiu do rio sem teleporte.

- **A primeira leira informa o próximo gesto (#146).** Etapas marcadas,
  ferramenta e tecla atuais, item ausente e alvo coerente com a ação
  restante. Repetir arar explica plantar/regar; atividade sem progresso
  oferece ajuda sem presumir que estar parado seja estar perdido.
  Recados longos quebram em linhas e o fundo acompanha sua altura.
  Portões da lavoura, cadeia, avisos e idiomas verdes; mutantes reprovam.

- **Beata caminha sem deslocamento indevido da raiz (#139).** Clipes locais
  estabilizam quadril, preservam passada e acompanham o relevo pela física.
  Locomoção, rotina e nado passaram; clipes originais reprovam o mutante.
  Caminhadas reais planas e inclinadas tiveram capturas conferidas.

- **A vara decorativa deixa o centro do píer (#148).** A ferramenta de
  pesca fica no catálogo; peixe, pote, piso e navegação são conferidos
  na cena real. Todas as peças recebem metadata de origem para distinguir
  modelos repetidos. Pier_legivel e navegacao passaram, e reintroduzir
  a vara reprova. Captura em scratch/pier-legivel/pier.png conferida.

- **Caramelo late ao reencontrar o jogador (#153).** Som mono espacial,
  atenuado pela distância, com intervalo mínimo e pequenas variações.
  Cede a diálogo, narração, pausa e carregamento; respeita efeitos/mute.
  Fonte CC0 de Brandon Morris registrada com hash e licença. Latido e
  bichos Tripo/procedural passaram; falsificadores detectam repetição.
  O teste de bichos revelou centro de ronda dentro da casa: agora amostras
  recusadas usam posição segura ou busca determinística, nunca o centro
  inválido. O mutante do quintal reprova essa regra (#149 parcial).

- **Mapa volta ao lobby em vídeo (#147).** O acesso lateral solicita o vale
  sob a tela de carregamento e abre diretamente o mapa; o cenário permanece
  ausente na abertura inicial. Os seis atalhos não se sobrepõem nem cortam
  em 800×600, 1280×720 e 1920×1080. Lobby e fluxo de mapa passaram;
  apagar o ícone em memória reproduz a falha observada.

- **Fades respeitam volume e mute durante a troca (#79).** Auditoria da
  implementação existente acrescida ao teste: alternar mute e volume no
  meio da transição preserva o ganho escolhido. Portão verde e mutante
  com duração insuficiente reprova três regras.

- **Mochila respeita remapeamento e Jogo troca de vaga (#66, #70).**
  O rodapé consulta o atalho atual nos três idiomas. A seleção de vaga
  pede confirmação, grava a partida atual e carrega o destino; cancelar
  preserva a partida. Arquivo recusado e falha de gravação interrompem a troca.
  Mochila, vagas, painel e idiomas passaram; ignorar remapeamento reprova
  quatro verificações e retirar a confirmação reprova uma.

- **Atalhos recebem plaquetas próprias (#122).** Letras laterais e números
  da mão usam creme opaco, tinta escura e borda dourada; ficam fora dos
  ícones e ignoram o mouse. A coluna reaplica a escala da plaqueta sem mudar
  o botão. Plaquetas, barra, atalhos e reservas passaram; sobrepor a tecla
  ao ícone em memória reprova nove verificações. Capturas no vale preservam
  leitura de dia/noite.

- **O testador reconhece porta, mapa e baú (#159; partes de #146/#154).**
  Segue waypoints perto de obstáculos, atravessa as soleiras com W, responde
  a colisão após dois segundos, fecha mapa por Escape e confere o dono do E.
  Progresso reinicia cobertura; a ausência do objetivo durante fala não é
  avanço. O relatório inclui trajetos a cada meio segundo e tempo de decisão.
  Os 44 testes Python passaram; a política anterior reprova quatro casos e
  o portão de mapa distingue Escape de espera infinita. A partida real de
  300 segundos chegou à lenha após porta, baú e lavoura; campanha completa e
  orientação ao humano permanecem pendentes.

- **Relógio e corpo ficam compactos (#131).** O relógio tem mostrador e
  painel de 100 × 52; os três medidores de 160 × 18 ficam à direita, com
  coração, bateria e raio. Os números permanecem, assim como cores de
  veneno, cansaço e esforço, troca pelo fôlego do nado e alertas traduzidos.
  A posição considera missão e atalhos. Reservas, fôlego, matriz e idiomas
  passaram; capturas claras/escuras foram conferidas e o layout antigo
  injetado em memória reprova dez verificações de tamanho e posição.

- **Paredes internas recebem cal envelhecida (#136).** O estilo Tripo usa
  a textura já catalogada, com projeção triplanar no mundo e acabamento
  fosco. Portas, colisões e o legado procedural preservam sua geometria.
  Casa, casa_procedural e efeitos_no_vale passaram; capturas às 9h e 20h
  mostram a textura sem esticar nas faces. Remover a textura em memória
  reprova cinco paredes no teste de casa.

- **Pedro espera a cena e a transição (#137).** A saudação aguarda `carga_ok`
  e a retirada da tela de carregamento, incluindo o fade. A fila bloqueia
  novas falas nesse intervalo. Carga e abertura passaram; carregar a fila
  anterior reproduz duas falhas de início antecipado.

- **O E separa alvo e requisito em duas linhas (#134).** A largura se adapta
  à janela e mantém a tecla centralizada; requisitos maiores quebram por
  palavras. A frase de ferramenta necessária passa pelo idioma escolhido.
  O nome persistente acima da barra de mão sai (#120, parcial): o slot mantém
  seu destaque e mostra o nome ao passar o mouse, limpando tooltip de vazio.
  Dica, barra, matriz e idiomas passaram; a versão anterior reprova as
  verificações de linha, tamanho, rótulo e tooltip.

- **A conclusão fica em um cartão e a orientação recolhe na chegada (#130,
  #135, #144).** A conquista dura 2,7 segundos em 420 × 145 pixels da área-base,
  com emblema pequeno, sem sombra global, véu ou mistura aditiva. Continua
  esperando a fila e cedendo a conversa. O cone perde as tampas sólidas,
  diminui, e cone/anel somem dentro de cômodos. Chegar a 2,4 unidades recolhe
  a orientação; sair além de 3,2 a recupera, sem piscar na borda ou concluir
  a missão. Alvos novos continuam orientando. Conquista, fila, chegada e
  efeitos no vale passaram; as capturas diurnas/noturnas preservam o cenário.
  Reintroduzir mistura aditiva reprova; a seta anterior reprova três regras.

- **Nomes, fala e E obedecem à mesma matriz (#121, #124, #127, #132).**
  Uma pessoa falando não oferece nova conversa; o avanço do Dialogo continua
  disponível. O E identifica seu dono sem repetir a plaquinha. Árvores ocultam
  somente nomes concorrentes na região da dica, com folga para voltar.
  Três raios para cabeça e torso ocultam pessoas cobertas pelo cenário; uma
  amostra livre preserva quem aparece parcialmente. Consultas espaçadas e
  histerese estabilizam as bordas. Matriz, foco, placas, afinidade e popups
  passaram; carregar o comportamento anterior reprova quatro regras centrais.

- **Mochila e baú recolhem o HUD externo (#143).** Minimapa, atalhos, estado,
  dicas e avisos somem pelo ancestral da interface; voltar não revive filhos
  que expiraram. Os testes de mochila e de baú com boneco passaram.
- **Recebimentos e falas não ficam presos no rodapé (#133, #157).** Avisos
  expiram pelo tempo de leitura, no mínimo quatro segundos. Substituir cancela
  o prazo anterior; repetir não o reinicia. Pedro fala somente no balão,
  encerrado pela fila com seu áudio e pausas preservados. Os testes de prazo
  e fila passaram; retirar a expiração em memória reprova o recebimento.
- **Avisos contextuais cedem ao E e à fala (#132).** A matriz distingue
  HUD essencial, interação, fala, aviso e nome. Um aviso só se recolhe se
  competir pelo mesmo retângulo, e volta se ainda for válido. A integração
  com nomes, interação de árvore e fala em andamento está concluída.

- **O E registra a conversa diária e permite presentes confirmados (#49).**
  Conversas comuns e de missão aumentam a afinidade uma vez por dia. A missão
  tem prioridade; alimentos e outros presentes na mão pedem Sim/Não, com
  gosto/desgosto e atualização da tela P. Ferramentas não são oferecidas.
  O teste novo falha nos comportamentos ausentes e agora passa; o foco do E
  continua passando após recusar a nova pergunta de presente na prova.

- **O idioma escolhido acompanha a partida (#51).** A entrada mantém o locale
  e as traduções de controles comuns. A ajuda informa o fallback português e
  o fallback inglês para chinês. As fontes das interfaces ainda não migradas
  estão declaradas em `FALTAM_TRADUCAO`; tradução integral continua na #6.
  Seleção nos quatro idiomas, abertura e retorno passam nos testes.

- **A regra de arte nova segue a decisão Tripo (#46).** O `AGENTS.md`, o plano
  e a composição autoral deixam de exigir um construtor procedural novo por
  asset. O legado funcional continua protegido; os critérios das cinco issues
  dependentes passam a distinguir essa compatibilidade da produção de arte.

- **O menu oferece Teste automático no projeto de desenvolvimento (#159).**
  Abre uma partida isolada com o robô determinístico local; a documentação está
  em `docs/testes/AUTOPLAYER.md`. Ações pontuais têm pausa de 0,7 segundo;
  arar, plantar e regar, 1,4 segundo. A coleta de pedra seleciona a picareta
  e prioriza o recurso indicado. O painel fica compacto no canto inferior
  direito, informa seu retângulo aos balões e se esconde em telas e diálogos.
  Falta de progresso abre exploração determinística com memória de tentativas
  por contexto, seleção de receitas e visita aos alvos próximos. `relatorio.md`
  reúne tempos, movimentos, decisões, resultados e capturas; atualiza durante
  a sessão e no encerramento, sem confundir execução de tecla com avanço.

- **O jogador local reconhece o baú e os itens reais do inventário (#118).**
  `JOGAR_SOL.cmd` inicia o controle automático por regras, sem API, por dez
  minutos quando solicitado; por padrão segue sem limite de tempo até concluir
  a história implementada. Ajustes da política local são recarregados entre
  ações sem reiniciar a partida. A regra do baú usa a interação `bau` da casa, os campos `id`/`qtd`
  e o índice real da grade do baú para abrir e retirar as ferramentas pedidas.
  Observações repetidas provocam uma tentativa de interação ou reposicionamento,
  em vez de continuar aproximando indefinidamente. A execução acompanhada
  continua sendo experimental; concluir a campanha ainda não foi demonstrado.
  A coleta de lenha reconhece a meta `item`/`quantos`, segue o marcador vivo
  e prioriza a interação do galho seco sobre conversas próximas; essa regra
  foi recarregada durante a partida acompanhada, sem reiniciar o jogo.

- **Balões de fala consideram as barras e o aviso do guia (#132).** Os controles
  informam seus retângulos reais para escolher um espaço de fala fora do HUD.
  A alteração vale na próxima abertura; a revisão completa das prioridades
  permanece pendente.

- **A tentativa de concluir a campanha usa até US$ 0,50.** O orçamento padrão
  continua US$ 0,10; `--budget 0.50` aumenta o teto autorizado. Falta de progresso
  por 30 segundos agora informa necessidade de recuperação ao Jev, sem encerrar
  por padrão. `--idle-seconds` permite restaurar essa parada. O contexto reforça
  que sucesso exige concluir a história implementada até `fazenda_chegada`.

- **Jev joga uma sessão curta sob observação.** `JOGAR_JEV.cmd` abre o jogo em
  um perfil isolado; a ponte local envia observações textuais à TypeSafe e o
  modelo escolhe ações da abertura, caminhada, corrida, interação e telas.
  Cada sessão limita o gasto a US$ 0,10 estimados, sem corte padrão de tempo
  ou chamadas (esses limites são opcionais),
  com interrupção por F8, relatório das decisões e capturas locais. O modo
  `--offline` valida a integração sem API e fica identificado como tal.
  Após o primeiro experimento, a ponte também interrompe ciclos sem progresso
  por 30 segundos, antes de enviar outra chamada paga. A aproximação de um
  morador verifica o alvo do E em vez de assumir que a chegada do caminho basta.
  A retomada também revelou corrida sem deslocamento diante de um obstáculo:
  agora o controle mede o movimento, informa bloqueio e oferece WASD nas
  direções livres verificadas por raios curtos de colisão.
  O objetivo do Jev passa a ser concluir a história implementada, até o pátio
  da fazenda: as 22 definições de missões e 85 passos, requisitos das cadeias
  vivas, diário, inventário, mapa, moradores, receitas e textos de telas entram
  no contexto. Pedro informa condução, espera e destino; o controle continua
  acompanhando-o após alcançá-lo. Mochila, ferramentas e telas ganham ações de
  teclado. O relatório distingue o fim implementado do restante ainda pendente.
  Todos os deslocamentos passam a usar WASD: a malha fornece a rota, mas não
  comanda o clique. A aproximação curta do guia usa teclado para alcançar o
  limiar que o faz voltar a conduzir, e o contexto separa a tarefa atual das
  futuras, destaca falhas recentes e informa o destino previsto de cada direção.
  O experimento não substitui os portões determinísticos nem cobre toda a campanha.

## Em desenvolvimento — 06/10/2026 (playtest da Build 9B)

- **Playtest de 07/10, primeira fatia.** Colhido, o leito volta a chão bruto e a
  enxada abre outro. Com comida (ou papel) na mão o E come (ou lê): a barra de mão
  vota no foco do E e vence o leito, a árvore e o toco — só a conversa com quem está
  ao alcance passa na frente. Ao lado da hora só "parado" tem rótulo: os motivos
  (fala, tela, festa, narração) estão na tela por si, e a palavra ficava sob a barra
  da vida. A festa de missão cumprida só vem no fim da missão inteira, com o nome dela
  ("Chegada ao arraial"), e não a cada passo. A galhada seca do terreiro rende cinco
  vezes e acaba. Acabado o tutorial, a ponte do rio grande abre sozinha e o Pedro a
  anuncia na despedida — antes nenhuma missão abria. E o relógio não fica preso: a
  festa segura com prazo e solta quando se recolhe, e um motivo sem prazo que dure
  mais de 150 s se solta sozinho, avisando no console.
- **Playtest de 07/10, quinta fatia: a fogueira e as pedras.** A fogueira do terreiro
  guarda fogo para três pratos; cada prato gasta um, e o E nela com a lenha na mão
  devolve três, até nove — a aba do fogão diz quando apagou, e os recados moram em
  `data/fogueira.json`, nos três idiomas. Quarenta pedras soltas nascem espalhadas
  pelo vale, com semente, longe das ruas, das casas e dos lugares da vila. As pedras
  grandes (os lajedos, as rochas e os matacões) deixam de ser cenário e viram alvo
  de dias: pedem a picareta de aço e o talento Mão de pedra, rendem duas pedras a
  cada quatro golpes, e a dica conta o trabalho ("Lajedo 12/96"); a seta de "junte
  pedras" não aponta a pedra grande a quem só tem a picareta de ferro. As árvores já
  seguiam a regra (madeira branca, de lei e dura, com nível e aço).
- **As missões secundárias dos moradores, fase 3: as pontes entre moradores e as
  missões de ação** (docs/projeto/MISSOES_SECUNDARIAS.md). Nove filas, abertas pelo
  favor feito e a afinidade (a do Tonico pede "Amigo"): a roda na praia (Mariinha e a
  Dona Rosa, de noite), a ronda do guarda (três lugares da praça depois das oito), a
  vigília do sino (a igreja de madrugada), a maré das cinco e a carta da filha da Dona
  Rosa (que o padre lê duas vezes; documento novo `carta_da_rosa`), a canoa do Tonho
  (o carpinteiro a conserta com a madeira que o jogador leva), o livro de fiado (a conta
  do Tonho paga em peixe), o caminho do Tonico até a lapa (a dívida é um cordel), a
  promessa de Sá Joaquina (uma ostra na areia, por oferenda) e a água do rio grande.
  Mecânica nova, uma só: `"horas": [de, ate]` na meta `visitar` — a janela do relógio
  do vale em que chegar conta, e pode virar a meia-noite. O `missoes_elos` conta 52
  arquivos e 154 passos.
- **As missões secundárias dos moradores, fase 2: os quatro arcos de enredo**
  (docs/projeto/MISSOES_SECUNDARIAS.md). Abrem com o favor do morador feito e ele
  "Gente boa". A toalha do tio (a rendeira a entrega na janela; posta na mesa da casa
  de taipa, por oferenda), a pedra atrás do altar (o sacristão dá o papel com os
  nomes que a fazenda chama — o do tio riscado), a madeira com letra (a proa da
  Senhora da Boa Viagem, que o padre lê: o brasão apagado é o que falta no selo do
  convite) e a luz na água (a foz do rio grande, e o Quirino confirma no dia do
  saveiro). Itens novos: `toalha_de_renda` (ícone novo), e os documentos
  `papel_dos_nomes` e `tabua_lavrada`, com texto em `data/documentos.json`. O
  `missoes_elos` conta 43 arquivos e 125 passos.
- **As missões secundárias dos moradores, fases 0 e 1** (docs/projeto/MISSOES_SECUNDARIAS.md).
  Catorze moradores do arraial só cumprimentavam e recebiam presente; cada um ganha
  um favor de um passo (`data/missoes_<morador>.json`, meta "levar", a recompensa em
  coisa que ele tem), na voz que já tinha em `aldeoes.json` — o lampião do Nicolau é
  o da Estefânia, a cocada da Ambrósia é a do Tonico. As filas são penduradas pela
  tabela `data/favores_dos_moradores.json` e trancadas pela afinidade: abrem quando o
  morador conhece o jogador (grau 1) e a chegada acabou, com o aviso nos três idiomas —
  que fica quieto até cinco pontos e sai uma vez, para não tomar a conversa do morador.
  Fechar a fila de um morador da teia passa a dar o favor da afinidade (+25), que
  ninguém dava. As casas dos moradores e a beira do rio entram no `Lugares`. Portão
  novo `missoes_secundarias`; o `missoes_elos` conta 39 arquivos e 114 passos.
- **Playtest de 07/10, sexta fatia: a voz do arremate.** O Pedro narra, na voz dele, a
  fala de depois do convite lido (`pedro_convite_arremate`, gerada no ElevenLabs pela
  ferramenta das falas do guia, com a leitura marcada para o v3).
- **Playtest de 07/10, quarta fatia: a vila e as cercas.** A travessia do rio
  central volta à ponte grande de 26/09 (`ponte_grande`, o modelo de então
  recuperado); o rio grande fica com a ponte pequena de pé e a caída da obra. As
  cercas de varas das roças passam a ser traçadas em lances retos de canto a canto
  sobre o contorno simplificado da roça, um palmo para fora dela — antes a cerca
  era amostrada a passo constante pelo perímetro e cortava caminho nos cantos, por
  dentro da roça e cruzando a da vizinha (nove cruzamentos entre a mandioca e o
  milho do Poente); duas roças vizinhas dividem uma cerca só. A cerca sobe a 1,35
  e o corpo dela a 1,9 — mais que o pulo: cerca que impede a passagem, e não um
  degrau; cada roça cercada ganha a porteira (a do milho do Poente, longe de toda
  rua, abre para o lado da praça). Portão novo `cercas`.
- **Playtest de 07/10, terceira fatia: as telas.** A caixa de fala, a mochila e o
  cartão do amanhecer eram desenhados no quadro de 640×360 do 2D e ampliados duas
  vezes — a letra saía serrilhada. Passam a ser desenhados na tela do vale
  (1280×720), com o dobro das medidas de lá. A mochila e o cartão continuam sendo
  os arquivos do 2D: o vale os ESTENDE só no desenho (`mochila_vale.gd` e
  `amanhecer_vale.gd`, os autoloads `Mochila` e `Amanhecer`; regra 3 do
  HISTORICO — a regra fica no 2D). E a mochila entra na identidade dos menus do
  vale: a laca verde-escura, o filete e a talha de ouro, o título em Cinzel e o
  texto em Cormorant, como o painel do J e o menu das obras; o espaço dela tem os
  52 px da barra de mão, e o boneco acompanha.
- **Playtest de 07/10, segunda fatia: a chegada.** A seta da corrida aponta uma pista
  em terra, estrada adentro, e não o Tonho. Na chegada o Tonho espera na areia, ao
  lado do píer, e volta à rotina quando a chegada passou do bom-dia e ninguém está
  olhando (o jogador a mais de catorze passos), ou quando a festa de uma fé o chama
  à roda. O Pedro espera nos marcos da estrada: a cada onze passos andados para e
  vira-se até o jogador chegar a três; não anda enquanto o jogador está preso na
  caixa de fala; e só corre se o jogador corre de fato. A ponte do rio grande só se
  anuncia com o Pedro ao lado do jogador, e a pista e a areia não reservam chão no
  paisagismo — o píer segue com as oito piaçabeiras que o saveiro pede.

- **Toda a lista de missões do 2D está no vale** (docs/projeto/MISSOES_DO_2D.md).
  O segundo tutorial (#160, `missoes_quintal.json`) abre sozinho na sexta colheita,
  como no 2D: o pomar entrega duas mudas de bananeira e uma de mangueira e
  fecha com a fruteira plantada; o talento Curral (raiz Pastoreio) passa a levantar
  o galinheiro no quintal da casa de taipa, com três galinhas que botam um ovo
  cada por dia — o E no galinheiro recolhe (`curral_vale.gd`); e o capataz, que no
  2D pedia a aba de trabalho dos terrenos, vira um dia de roçado combinado com o
  Cosme, pago de manhã na mochila. O capítulo 7 (#31, `missoes_revoar.json`,
  `revoar_vale.gd`) segue a porta estreita: o quarto sem janelas e as três trocas
  da velha (aceitar tira fôlego e paga; recusar é o caminho), a mão do Pedro que o
  jogador puxa, a fuga e o revoar, o abrigo nas ruínas do palacete — levantadas
  atrás do monte a oeste da fazenda, com a torre da capela e a rampa de pedra —, o
  relato das escravas, a lança e o escudo de safiras entre os destroços, a fera
  chamada pela lança batida no escudo e o embate de verdade com a Matinta como
  criatura (`criaturas_3d.json`), a luz azul, o espírito do senhor e o sinal dele,
  a estátua que fica, e a escolha do escudo ao amanhecer. Portões `quintal` e
  `revoar`; `missoes_elos` passa a contar 25 filas e 100 passos.

- **As missões voltam a fechar, e um portão joga todas do começo ao fim.** A
  bateria cheia da main tinha 12 portões vermelhos depois da junção do ramo de
  desempenho. As filas de colheita (Zefa, coveiro, pedra do poço, corte) caíam
  porque `max_physics_steps_per_frame=3` faz o tempo de jogo andar mais devagar que
  o relógio com quadro acima de 50 ms; agora são 5 passos (tempo real até 12 FPS) e
  os portões esperam em segundos de jogo (`tests/fixtures/relogio_de_jogo.gd`).
  `tests/missoes_do_comeco_ao_fim.gd` joga uma partida só pelos controles do
  jogador (anda, aperta E depois de perguntar ao foco, obras pelo E e pelo J,
  mochila, teia, luta, pesca), as 22 filas e 85 passos; só roda no `-Tudo` ou por
  nome, com teto de 4 h. `tests/missoes_elos.gd` confere os elos estáticos.
- **O E chega ao poço.** Os sítios de obra (poço, ponte, mirante, cemitério,
  carroça) respondem ao E e abrem o painel nas obras daquele sítio; o J abre direto
  em Obras quando o passo é de obra. Entre moradores, leva o E quem a missão manda
  procurar; quem tem fila trancada diz "volte depois de ..." nos três idiomas.
- **As falas esperam a vez.** Uma fila só (`fila_de_falas.gd`) para balões, caixa
  de fala, narração, voz do marco e festa de missão: cada fala segura a vez pelo
  tempo da voz ou da leitura; cumprimento de quem passa não entra por cima. O Pedro
  ganha falas de depois do tutorial e deixa de se apresentar de novo; a ferramenta
  da missão não some no save nem com a mochila cheia.
- **Pedras:** quebrável é pequena (pedras soltas aos pés das rochas, mesmo
  rendimento); as rochas grandes viram cenário, sem E. O golpe ganha som
  (marretada, pedra quebrando, foice, ostra, galho), gerado no ElevenLabs.
- **Câmera e corpo:** a câmera nunca fica a menos de 1,25 m do corpo (sobe por cima
  da cabeça quando a parede encurta o braço), fica acima da água de agora (com a
  maré) e atravessa as portas sem estalo; o corpo deixa de prender nas bordas de rua,
  de ponte e de areia. Portões `camera_resiliente` e `colisoes_de_passeio`.
- **Bichos:** a onça corre a 4 u/s e mata em duas mordidas quem não corre (quem
  corre escapa), o tubarão alcança quem foge a nado e some na baixa-mar, a cabra anda
  em vez de deslizar, e os bichos deixam de esticar parados e na pausa.
- **Popups:** no máximo três placas de nome (duas com balão no ar), com mola na
  tela em vez de colar na cabeça; o balão só troca de canto depois de 0,9 s e a fala
  longa passa em páginas de duas linhas.
- **Maré e música:** a maré vem ligada de fábrica (quem nunca escolheu passa a vê-la)
  e o relógio diz se a água enche ou vaza; cada período do dia tem a sua trilha.
- **Moradores:** os catorze que só acenavam falam (cumprimentos, conversa e falas
  da noite), e toda fala de `data/npcs_3d.json` tem pt, en, es e zh. Vozes geradas em
  português: Pedro depois do tutorial, padre, sacristão, beata, mercador, guarda e
  parte do pescador; as outras 104 falas de nove moradores ficam em `voz_pendente`
  até a chave do ElevenLabs ter crédito.
- **Casas por dentro:** as moradias, as capelas, a venda, a casa de farinha e o
  casarão da fazenda abrem, mobiliados para quem mora (`data/interiores_casas.json`);
  o casarão se sobe pela escadaria de pedra até o salão. O cômodo se monta de perto e
  some do desenho de longe.
- **De longe:** casas, árvores nomeadas e adereços viram caixa e copa baratas, sem
  buraco na troca (até -54% de triângulos); as doze lápides ficam alinhadas e
  assentadas no chão.
- **Sustos da mata:** um vulto aparece no fundo da mata; olhado, some; de costas,
  ele avança, o jogo salva em silêncio e fecha como se travasse. As pegadas do
  Curupira, viradas para trás, enlouquecem o mapa, a bússola e a seta da missão por
  um minuto. AJUSTAR → Sustos desliga os dois.
- **Ajustes:** o clique contorna as casas (as duas lenhas da ponte saíram da fresta
  da casa de taipa), a malha dos moradores contorna o alicerce da capelinha, e o
  saveiro atracado vira obstáculo. O lobby em vídeo vale em toda build e no editor;
  `-- --lobby-3d` (ou `abertura.lobby_3d_pedido` nos portões) volta ao vale 3D.
- **A noite junta-se à main do dia** (a seção abaixo). Onde as duas fizeram a
  mesma coisa, ficou uma só: a plaquinha tem as três vagas e a mola daqui e o
  "só de perto" de lá (inteira até 6 u, some em 10); o balão só a 16 u, e o "um
  balão por vez" é a fila de falas (`npc.calar()` passa por ela); o E das obras é
  o daqui (raio do E por sítio, obra pedida, cursor), que já cobria o poço da #80;
  o som do golpe é uma tabela só, a daqui, sem tocar duas vezes; o bicho para no
  quadro de pé medido, e no começo ou no meio da passada quando não há medida
  (#91); os catorze moradores ficam com as falas, os quatro idiomas e as vozes
  daqui e com a fé e os assuntos da teia de lá (#85); a dica do E diz com quem se
  fala (#97) por cima da arbitragem daqui; e o pedido do lobby 3D por código é um
  só, que os dois lados tinham criado com o mesmo nome.

## Em desenvolvimento — 06/10/2026 (madrugada e manhã, na main da equipe)

- **A reserva do dia volta ao corpo (#82, fecha a #45).** Entre 04/10 e 06/10 a
  `Energia` espelhava o vigor do jogador (`registrar_vigor`), e como o vigor volta
  sozinho a comida, a cama e os talentos de reserva perderam a função — apontado
  pelo autor depois do teste ao vivo de 05/10. Agora são três contas: a vida; a
  reserva do dia, na barra do meio só com o número, que a enxada, o machado, a
  picareta, a lavoura e a luta gastam e só comida, cama e desmaio devolvem (no fim
  dela o passo encurta, a barra fica vermelha e diz "cansado", e a corrida não
  responde); e o vigor, embaixo, da corrida, do salto e do golpe, que volta sozinho
  (baixo, fica âmbar). Na água a barra do meio vira o fôlego do nado, azul: o nado
  gasta o vigor primeiro e depois o fôlego, e sem fôlego a água tira da vida; ao
  sair da água a barra volta à reserva (`nado_mudou`), e quem apaga acorda
  respirando. O golpe na árvore paga o braço inteiro no vigor e bater × dureza na
  reserva. O Pedro explica as quatro contas com as vozes já gravadas: a reserva e
  o vigor voltaram do `529a648`, e a fala do nado ficou com o arquivo dela
  (`pedro_corpo_nado`). Ajustes → Esforço continua valendo para a reserva. Manual
  em `COMO_JOGAR_3D.md`. Portões: `reservas_do_corpo` (reescrito), `folego`,
  `luta`, `casa`, `corte_das_arvores`, `lavoura`.
- **O E no poço abre as obras do poço (#80).** No teste ao vivo de 05/10 a chegada
  parou no mutirão: o passo fecha por uma obra que só se tocava pelo J, o resumo
  não dizia a tecla e o poço não respondia ao E. Agora toda construção de
  `BancadasVale.OBRAS` com obra disponível (poço, mirante, trapiche, carroça,
  cercado do cemitério, ponte, armazém — a casa não, que tem E próprio) ganha a
  dica "E · Obras" e abre o painel na aba de obras dela, como o canteiro
  (`tecla_das_bancadas.gd`); sem obra disponível não há E. O resumo e a fala do
  `mutirao_poco` dizem "E no poço (ou [J] › Obras)" nos três idiomas. Portão
  novo `mutirao_do_poco`: da boca do poço à janta — picareta, pedras, corda, o
  plano ensinado ao abrir, a Dona Zefa e o Cosme chamados à roda, o E entre os
  dois, a obra tocada no painel, as cocadas; a falsificação sem o E reprova.
- **O rio grande deixa de dar passagem fora da ponte (#81).** No 2D o rio tem
  barranco e só se cruza pela ponte; no vale ele era raso de dar pé, com um vau ao
  lado da ponte, e o jogador nada — a trava da jornada (a fazenda do convite é do
  outro lado) não segurava. Decisão do autor: os dois. A calha do rio do norte é
  funda (1,6 u: no meio não dá pé) e do lado de lá segue funda até a beira; a
  margem de lá sobe 1,2 u acima do terreno numa face que começa na água, ao longo
  do rio inteiro e da cabeceira até a moldura do mapa; a ponte assenta num aterro
  dos dois lados, com o tabuleiro plano e a estrada chegando em rampa que se anda;
  e sob o rio a estrada só afunda pelo lado de cá (pelo de lá seria rampa de
  saída). O vau saiu dos lugares, do construtor e das falas: o passo de ver a
  ponte fecha na cabeceira de cá, o Pedro conta que "a água dá nado e o barranco
  do outro lado não tem por onde subir", e o caminho da fazenda é "pela ponte".
  Fica em aberto a costa a norte da foz, que quem nadar pelo mar alcança (a guarda
  ali é o tubarão). Portão novo `rio_grande`: a calha, a beira, a face do
  barranco e o aterro medidos ao longo do rio inteiro, e três nados para lá com o
  pulo apertado que não saem da água; `ponte` e `fazenda` ajustados.
- **O alto da tela diz a tarefa, e não o texto da missão (#83).** Desde 04/10 o
  HUD recebia as páginas com a fala inteira de todos os passos — inclusive os que
  ainda não tinham aberto —, com setas para passar e um X para fechar; a fala
  cobria a tarefa, e o X escondia o quadro inteiro. Agora o quadro mostra só o
  nome da missão, o resumo do passo com a conta ("Tire pedra para calçar o poço
  (2/3)") e o passo "n de N"; a fala fica no balão e no painel J. As páginas, as
  setas, o X e o atalho `fechar_missao` saíram (`prototype_hud.gd`, `atalhos.gd`,
  `COMO_JOGAR_3D.md`). Portão `tarefa_no_hud` no lugar do `paginas_missao`;
  `cadeia_das_missoes` confere o resumo no alto da tela.
- **O morador não salta no caminho longo quando a câmera vira (#84).** O padre
  teleportava da igreja ao cemitério: a troca de posto a mais de 40 u é caminho
  longo, e bastava um quadro com ele e o destino fora do enquadramento para ser
  posto no lugar. Agora o salto espera o jogador a mais de 40 u e sem ver nem o
  morador nem o destino por 4 s seguidos (`npc._encurtar_o_caminho`); até lá ele
  anda. Portão novo `caminho_longo`: de costas e a vinte unidades o morador anda
  sem saltar; longe e fora da vista ele salta só depois do tempo; e nunca para um
  ponto à vista.
- **A fogueira do terreiro volta ao modelo certo, e a chama apaga de dia (#86).**
  Desde 04/10 (`8413ae7`) a peça `fogueira` do catálogo apontava a pilha de lenha
  (`lenha_tripo.glb`), e o jogador via a pilha com a chama em cima; a chama de
  partículas ardia o dia inteiro (na live, a fogueira acesa de manhã). O catálogo
  volta a `fogueira_tripo.glb` (o anel de pedras e as toras, sem a chama rígida),
  e a chama e as brasas seguem a noite com a luz (`luzes_epoca.gd`). Portão novo
  `fogueira`.
- **A gameleira do sambaqui assenta no chão (#87).** O monte e a árvore eram
  postos por uma amostra do terreno, no centro, e com o chão novo de 05/10 a
  encosta ali inclinou. O terreno em volta vira um platô na altura do centro
  (`GeoRegionRenderer`, PLATÔ DA GAMELEIRA: plano até 7 u, voltando ao relevo em
  mais 5). Portão novo `gameleira`: o anel em volta varia menos de 0,2 u, a borda
  do monte não flutua, e o marco é o tronco.
- **O aviso do primeiro cordel diz que ele é colecionável (#88).** O cartão já
  contava o que é a literatura de cordel; agora diz também, nos três idiomas, que
  no jogo ele é um colecionável, onde os folhetos estão espalhados e que o
  almanaque mostra quantos faltam. O portão `avisos_da_primeira_vez` cobra.
- **Cada golpe em pedra e galhada tem som (#89).** `recursos_3d._aplicar_golpe`
  era mudo — `picareta.mp3` existia sem ninguém o chamar. Agora cada golpe toca o
  som da ferramenta (picareta na pedra, a foice colhe, machado no resto, inclusive
  a galhada partida na mão) e o último golpe do que cai toca a árvore caindo.
  Portão novo `som_dos_golpes`.
- **Plaquinhas de nome e balões só de perto, e um balão por vez (#90).** A
  plaquinha aparecia a 22 u e o balão a 45; agora a plaquinha é inteira até 6 u,
  esmaece até 10 e some, e o balão só aparece até 16 u. Quem fala com o jogador —
  a conversa do E ou a fala de missão — cala a saudação de quem passa por perto
  (`npc.calar`), e a saudação continua não entrando por cima de ninguém. Portão
  novo `placas_e_baloes`.
- **O bicho de quatro patas para na pose de apoio (#91).** Parado, o quadrúpede
  congelava no quadro em que o passo o pegou, com a pata no ar ("os bichos
  ficaram assim", na live). Agora o clipe de andar segue até a pose de apoio — o
  começo ou o meio da passada — e só então para (`animador_bicho`). Portão novo
  `bicho_parado`. O cão caramelo, de pernas por código, não mudou.
- **O Pedro vem junto quando o jogador apaga (#92).** Na live o jogador apagou
  nadando, acordou em casa, e o Pedro ficou no mar. Enquanto o tutorial dura, quem
  apaga acorda com o Pedro esperando na porta, do lado de fora
  (`queda._levar_para_casa`, `guia_pedro.vir_para_a_porta`), e a condução recomeça
  dali. Portão novo `pedro_volta`.
- **Os quinze moradores novos entram na teia social (#85).** A teia (P) lia uma
  constante com os sete do 2D; agora `Afinidade.MORADORES` vem do `aldeoes.json`,
  na ordem dele. Os quinze do vale — o mestre Quirino, o padre Anselmo, o
  sacristão Zacarias, Sá Joaquina, Seu Nicolau, o guarda Aristides, Seu Jerônimo,
  Dona Rosa, Sá Rita, Dona Estefânia, Dona Ambrósia, Seu Epifânio, Tonico,
  Mariinha e Seu Ladislau — ganharam fé, gosto e desgosto, as reações ao presente,
  a apresentação e dois assuntos por grau (`data/dialogos/aldeoes.json`), e os
  catorze que eram mudos ganharam duas saudações nos três idiomas
  (`data/npcs_3d.json`), sem voz gravada. Os retratos vêm do modelo 3D de cada um,
  como os dos sete. O `aldeoes.json` segue só em português, na dívida declarada
  (#6, #51). Portões `fe` (os sete primeiro, vinte e dois ao todo) e `interacao`
  (o aceno se pergunta a um morador calado por um instante).
- **Toda cerca do vale deita na encosta (#93).** Cada lance era posto reto, na
  altura de uma amostra do terreno no centro dele, e na encosta uma ponta
  flutuava e a outra se enterrava — "cercas desniveladas por todo o vale"
  (autor, 06/10): 9 dos 32 lances do cemitério, as duas cabeceiras da ponte (a
  pior ponta a 0,41 u) e 27 das 204 cercas de varas das roças (a pior a 0,47).
  Agora todo lance vai de ponta a ponta no chão, com o eixo deitado pelo
  desnível e a caixa de colisão junto (`CatalogoAssets.lance_de_cerca`, um
  construtor só para o cercado do cemitério, as cercas da ponte e as do
  quintal do roçado; `PaisagismoVale.plantar_cercas` para as de varas, em
  MultiMesh). As duas cercas do quintal saíam no Tripo com 2,3 m de altura
  (`_adereco("cerca", …, 2.0)`, em que o 2 era o comprimento da procedural):
  são dois lances do tamanho das outras, no mesmo lugar. Portão novo
  `cercas_na_encosta`: cada lance do vale com as pontas a menos de 0,1 u do
  chão, e ao menos um em encosta de verdade.
- **Os portões do sobrevoo voltam a montar o vale pela abertura.** Desde o lobby
  em vídeo (05/10) a abertura solta o `$Cenario` antes de ele montar, a não ser
  com `-- --lobby-3d`; o extrator do sobrevoo, que carrega a abertura e espera o
  vale, esperava para sempre, e `sobrevoo_livre` e `sobrevoo_livre_procedural`
  saíam pelo teto de 400 s. O extrator pede o lobby 3D por código antes de
  carregar a cena (`abertura.lobby_3d_pedido`): os dois voltam a 42 s e 36 s.
- **Ninguém mais sobe no altar da igreja (#98).** Na live o jogador subiu no
  altar: a mesa tinha corpo, mas com 0,95 de altura o pulo (1,5 u) a vencia.
  Por cima dela sobe uma guarda invisível e sólida até acima da cabeça
  (`interior_igreja.gd`, "AltarGuarda"), sem barrar a câmera; o ponto da reza,
  diante do altar, segue livre. Portão `interiores`, parte 4.
- **A dica do E diz com quem se fala (#97).** O foco do E escolhe um morador
  só, mas a dica dizia "Falar" sem dizer a quem — com um morador ao lado do
  cordel, na live, o jogador não sabia para quem o E ia. Agora é "Falar com
  Tonho" e "Entregar a Candinha", nos três idiomas
  (`tecla_dos_moradores._dica_de`); o cordel, a lápide, a árvore, o alvo de
  trabalho e as bancadas já diziam o alvo. Portão `foco_do_e`.
- **O primeiro mergulho em água funda avisa que parar é boiar (#96).** Na live
  ninguém sabia que parar na água é boiar e recupera o fôlego, e o jogador
  quase se afogou. A primeira vez que o corpo entra no nado abre o cartão da
  primeira vez, como o do cordel (`data/avisos.json`, "agua_funda", nos três
  idiomas; `prototype._ao_mudar_o_nado`), com o vale parado; a marca vai ao
  save e carregar não o repete. Portão `avisos_da_primeira_vez`, partes 5 e 6.
- **O jogador escolhe em que monitor o jogo abre (#95).** Com mais de um
  monitor só havia o F11 e arrastar a janela. AJUSTAR › Interface › Monitor
  lista um item por tela ("Monitor 1 · 1920×1080"); a escolha move a janela
  na hora, em tela cheia ou em janela, e fica salva (`Tela.monitores`,
  `definir_monitor`), com o padrão no monitor principal — uma tela que deixou
  de existir volta a ele. Nos três idiomas, com ajuda no "?". Portão `tela`.
- **Os portões acompanham as decisões de 06/10.** Na bateria inteira (120),
  sete reprovavam sem regressão do jogo: `chegada` cobrava quatro falas do
  corpo (são cinco desde a #82, com o nado); `rotina_dos_moradores` cobrava
  os catorze mudos e sem fé (falam e têm fé desde a #85; o mudo de controle é
  o pescador calado por um instante); `festa_da_fe` cobrava a roda só com os
  sete (os de agenda estão na teia com fé, mas não vêm à roda —
  `npc._lugar_na_festa` reparte a roda só entre quem não tem agenda; e o
  mestre Quirino, que só encosta no píer, fica sem fé no `aldeoes.json`);
  `festa_da_fe` e `rotina_dos_moradores` cobravam o morador posto no lugar no
  mesmo quadro, e desde a #84 o salto do caminho longo espera
  `FORA_DA_VISTA_POR` segundos fora da vista (os portões esperam esse tanto,
  como `caminho_longo`); `agua_rasa`, `tubarao` e `rio_grande` nadam, e o
  cartão da água funda (#96) parava o vale no primeiro nado (o aviso conta
  como já dado); `mapa_fluxo` confere o HOME com o vale de fundo e pede o
  lobby 3D por código, como os portões do sobrevoo. `navegacao` (PierPiso →
  Gameleira pela canoa do saveiro) já reprova na main `5dc6632`.
- **A ponte do rio grande cai de verdade, e a obra a põe de pé (#94).** "O asset
  não tá legal" (autor, 06/10): era o modelo de pé do Tripo com uma cerca nas
  cabeceiras, sem arte de ponte caída. Dois modelos novos do Tripo Studio
  (`tools/tripo/lote_2026-10-06_ponte.json`): a ponte de madeira do arraial de
  pé, larga para o carro de boi, com esteios e aterros de pedra, e a mesma
  ponte caída, com o vão do meio no chão. Até a obra `ponte_levantar` o vão
  mostra a caída, e a de pé fica escondida com o tabuleiro desligado
  (`ponte_vale._mostrar_caida`); feita a obra, a de pé volta inteira. A caída
  não tem colisão nem laje da câmera. A cerca das cabeceiras continua.
  Portão `ponte`: caída antes, de pé depois, e o raio no vão só bate no
  tabuleiro da de pé.
- **A caixa de fala veste a identidade do vale 3D.** Era o desenho da
  `dialogo.tscn` do 2D — o marrom, a borda grossa, a letra do sistema —, e o
  autor já tinha pedido que acompanhasse o jogo 3D. Agora é a laca com o
  filete de ouro, como o balão de fala: o nome em Cinzel versalete dourado, o
  fio de ouro, a fala em Cormorant, o rodapé "[E] continuar" em Cinzel miúdo
  (`dialogo_vale._montar`). A API, a fila de falas e o quadro de 640×360 não
  mudaram.
- **O relógio não fica preso atrás de telas aninhadas, e diz por que parou
  (#100).** Na live de 06/10 o dia travou às 07:14. As telas guardavam "estava
  pausado antes?" num booleano só, e a segunda tela aberta por cima da primeira
  (a mochila sobre uma fala, o mapa sobre o J) devolvia "pausado" ao fechar.
  Agora as telas seguram o dia por motivo, contadas (`prototype._pause_valley`
  / `_retomar_o_vale`, `Dia.segurar("tela")`), e `Dia.pausado` é só a pausa
  que o jogador pediu — o menu, o save e o restore leem isso direto. O relógio
  do HUD ganha uma linha de estado: "parado" pela pausa do jogador, ou quem o
  segura (fala, tela, conquista, narração), nos três idiomas. Portão
  `relogio`, parte 4.
- **O balão dura o tempo de ler, e o Pedro espera a vez (#101).** Na live a
  fala do Pedro cobriu a resposta da Dona Zefa, que sumiu antes de ser lida: o
  balão de `narrar` durava 8 s fixos e o anúncio do passo seguinte esperava a
  palavra no máximo 6 s. Agora todo balão dura o tempo de ler (4 s mais 0,05 s
  por letra, até 8; `npc.tempo_de_leitura`), a palavra é de quem fala por esse
  tempo, o anúncio espera até 8 s (`ESPERA_MAXIMA_PELA_VEZ`), e o E no Pedro
  com alguém falando ao alcance entra na fila (`guia_pedro._repetir_quando_der`).
  Portão `interacao`, parte 8.
- **O aviso do rodapé vira uma caixa no meio, acima da barra de mão (#102).** A
  fala do Pedro (`hud.set_notice`) era uma faixa de largura inteira, atrás do
  minimapa e por cima do "mão livre". Agora é uma caixa centrada de até 640
  px que quebra a linha e cresce para cima, na identidade do vale (laca,
  filete, Cormorant). Portão `tarefa_no_hud`, parte 5.
- **O balão de fala fica por cima da plaquinha de nome (#103).** As plaquinhas
  moravam no `map_layer` do HUD (camada 20), acima dos balões (10): a
  plaquinha de um morador cobria o balão de outro. Elas vão para a camada
  própria 8, abaixo dos balões e do HUD. Portão `placas_e_baloes`, parte 4.
- **As cercas de varas das roças ganham corpo (#104).** As 204 cercas do
  paisagismo nasceram sem colisão; agora cada lance tem a caixa dele, na
  medida da malha, numa camada própria (`Camadas.CERCA`) que barra o jogador e
  o clique (`PaisagismoVale.plantar_cercas`). A malha de navegação dos
  moradores não a lê: cerca como obstáculo deles muda as rotas do vale inteiro
  e fica para outro passo. Portão `cercas_na_encosta`, parte 6.
- **O E na comida come, e pergunta quando a reposição iria fora (#105).** Pedido
  antigo do autor que nunca tinha entrado: `Cozinha.comer` consumia sempre e o
  que passava do teto da reserva se perdia calado. Agora, acima do teto, a
  caixa de fala pergunta "Comer agora joga fora X de fôlego. Comer assim
  mesmo?" (Sim/Não, três idiomas; `barra_de_mao._comer_da_mao`,
  `Cozinha.reposicao`); "não" deixa o item na mão. Portão `barra_de_mao`.
- **A explicação das barras escurece a tela e acende a barra da vez (#106).**
  Quando o Pedro explica o corpo, um véu escuro entra entre o mundo e a caixa
  de fala (camada 5) e o HUD apaga tudo menos a barra de que ele fala — a vida,
  a do meio (fôlego e nado), o vigor; no respiro, tudo escuro. A caixa de fala
  avisa a linha da vez (`Dialogo.linha_mudou`, com a voz), o vale mapeia a voz
  à barra (`prototype.BARRA_DA_VOZ`) e o HUD acende e apaga
  (`destacar_barra`, `apagar_destaque`); ao fechar a caixa tudo volta. Portão
  `chegada`, parte 6.
- **As missões pagam XP, e o diário mostra a recompensa em ícones (#107).**
  Decisão do autor em 06/10: todo passo com recompensa paga 10 de XP
  (`recompensa.xp` nos `missoes_*.json`, pela teia de talentos:
  `Talentos.ganhar_pontos`), e o HUD o diz ("Recebido de Tonho: 1 peixe, 10
  XP"). No diário do J a página da missão ganha a linha RECOMPENSA: os itens
  com o ícone de cada um (o da barra de mão), os réis e o XP com ícones
  próprios, gerados por imagem (`assets/sprites/icones/`, `tools/openai/
  gerar-icones.ps1` e `promover_icones.gd`, que recorta cada um pela forma).
  Portões `painel` e `pedidos_do_arraial`.
- **Cada criatura da mata com os números dela, em dado e não em constante
  (#109).** "Cada bicho deve ter seu próprio atributo de velocidade, dano etc."
  Os números de cada espécie da mata moram em `data/criaturas_3d.json` (vida,
  dano, passo, faro, mordida, o que cai, corpo, modelo e vista, com o nome nos
  três idiomas), que `criatura_vale.gd` lê uma vez; os bichos de quintal seguem
  com passo e corrida em `bichos_de_casa.json`. A onça leva os números do 3D
  da noite de 06/10 (passo 120 px, dano 16 e `dano_da_vida` 0,55, coleira
  36/48 u, espreita 1,5 s). O esticar e o mancar dos bichos (a outra metade da
  #109) ficaram com a solução da equipe da mesma noite: o clipe do GLB
  recentrado onde veio torto, a perna dura copiando a diagonal, a respiração
  fora da altura (`animador_bicho`, portão `animais_animacao`); a busca de
  pernas pela pele do GLB escrita de manhã saiu na junção das duas mains.
  Portões `luta`, `onca`, `idiomas`, `bichos_de_casa`.
- **As abas do J ganham distintivos (#108, primeira fatia).** Obras e Saveiro
  na coluna de abas, o fôlego máximo em Ajustes e os cabeçalhos das três
  naturezas de carta (pacto, apoio, ritual) ganham um distintivo de 22 px na
  identidade do vale (`painel_vale._icone_distintivo`): seis ícones gerados
  por imagem no mesmo lote dos réis e do XP (`gpt-image-1`, autorizado pelo
  autor em 06/10; prompts em `tools/openai/icones.json`, recortados em
  quadrado arredondado e reduzidos a 96 px pelo `promover_icones.gd`;
  `sprites/icones/ORIGEM.md` e `assets/CREDITOS.md`). Os ícones de
  interface passam a importar sem compressão (Lossless, sem mipmaps), como
  manda o `AGENTS.md`. O layout das linhas com ícone do item, ingredientes
  com "×n" e a tecla da ação, em todas as abas, fica para a próxima fatia da
  #108. Portão `painel`.
- **Quem cai no rio grande volta pela margem de cá, e a água corre para o mar
  (#115).** "Cai no rio e não consigo voltar para nenhum dos 2 lados." Com a
  calha funda da #81 o leito subia 1,6 u em meio metro dos dois lados — 66
  graus, acima do que o corpo sobe (46) — e quem caía nadava até a parede e
  ficava, inclusive ao lado da ponte. Do lado de cá o leito agora sobe em rampa
  que se anda (`GeoRegionRenderer._beira_de_ca`: fundo no meio, a nado até a
  profundidade em que o corpo volta a andar, e dali à margem a menos de 40
  graus), a água do rio grande se alarga para cobrir a rampa, e o aterro da
  ponte vira um corredor: parede só sob o tabuleiro (a cabeceira de cá fica na
  altura da de lá), rampa ao lado. A margem de lá não muda. E "a água subindo o
  rio": o shader deslizava as ondas no sentido em que a faixa foi traçada, e o
  rio grande do KML é traçado da foz à cabeceira; agora o sentido é o da foz
  (`_sentido_da_correnteza`, `agua_rio.gdshader` ganha `sentido`), como as
  peças da foz já faziam. Portão `rio_grande` (reescrito nas partes 2 e 7, com a
  8 nova): a beira de cá a menos de 42 graus, sete nados para cá que saem da
  água, inclusive dos dois lados da ponte, e a correnteza para a foz. As pedras
  da margem íngreme (#116) esperam o lote do Tripo
  (`tools/tripo/lote_2026-10-06_pedras.json`, ~380 créditos, geração paga).
- **O convite, e todo papel que vai para a mochila, abre com o E (#113).** Ler
  era só o F em cima do papel, na mochila; com o papel na mão, o E lê
  (`barra_de_mao._ler_da_mao`, pelo mesmo `Mochila.abrir_documento` que o
  `prototype.gd` liga: a caixa de fala com as linhas de `documentos.json` e o
  aviso "leu:<id>" às cadeias), depois de o mundo não ter ficado com a tecla; e
  o rótulo da mão diz "E lê". Portão `barra_de_mao`.
- **A série da fazenda ganha o fim do capítulo 6 (#114, fatia 6.2 do plano
  do 2D).** "Devem ser adicionadas mais missões ao fim da série." Depois do
  pátio, dois passos novos em `missoes_fazenda.json`, nos três idiomas, tirados
  do capítulo 6 (`docs/enredo/capitulo-06.md`) sem contradizê-lo: "O chamado aos
  corajosos" (no pátio, fecha sozinho: a voz do mundo conta o silêncio e as duas
  mulheres na escadaria, a anfitriã mais velha chama os homens corajosos, a voz
  conta os que se levantam, e o Pedro vai — e chama o jogador, P3) e "A porta
  estreita" (falar com o Pedro fecha: a subida, o salão redondo, a fala da moça,
  o cerco, o "só um" da anfitriã, a porta de onde vêm os gemidos, os cinco que
  voltam, e o Pedro que fica). O salão ainda não é cômodo — a voz do mundo o
  conta, com o escuro —, e a sedução fica nas falas (P1). O arremate muda: "Só o
  Pedro ficou no salão redondo…". Cenas em `fazenda_vale` e `prototype`; o
  plano em `MISSOES_DO_2D.md`. Portões `fazenda` (as partes 6b e 6c) e
  `idiomas`.
- **Apertar E repetidas vezes num coletável cobra só o golpe que acontece
  (#112).** "Consome a stamina várias vezes, mas só acontece uma animação e o
  item não vai parar no inventário até que a animação termine." A reserva era
  cobrada no aperto do E, o golpe acontecia no impacto do clipe, e o clipe de
  golpe do personagem (`chop_001`, 6,63 s) tem o golpe só na primeira metade —
  a mão bate aos 32 % e volta ao repouso aos 50 %; o animador emitia o impacto
  aos 50 %, com a mão já parada, e travava o corpo os 3,5 s inteiros; a trava do
  recurso caía a 1,25 s e o E seguinte era cobrado sem reiniciar o clipe. Agora
  o impacto sai onde a mão bate e o golpe termina onde ela volta
  (`authored_animator`: IMPACTO_DO_GOLPE, FIM_DO_GOLPE, `duracao_do_golpe`);
  em `recursos_3d` o E só confere se há com que pagar, a cobrança e o golpe
  saem juntos no impacto, a trava dura o clipe inteiro e um clipe que morre
  (o corpo se mexeu) solta a trava sem cobrar nem bater; o E durante o golpe não
  faz nada. Na árvore, o E repetido não interrompe mais o corte (ligava e
  desligava o machado sem a árvore sentir golpe). Portão novo `golpe_repetido`:
  o E a cada 0,15 s no lajedo, cada cobrança no instante de um golpe com impacto
  de animação, a conta fechando; e na árvore o corte avança e cada golpe custa o
  seu.
- **Os portões das telas cobram o relógio parado pelo motivo, como a #100
  manda.** Desde fd54ef1 as telas seguram o relógio por `Dia.segurar(motivo)`
  e `Dia.pausado` é só a escolha do jogador; `painel` e `relogio` passaram a
  perguntar `Dia.parado()`, mas `escolha`, `folheto` e
  `avisos_da_primeira_vez` ainda liam a bandeira antiga e estavam vermelhos
  na main (a bateria inteira de 06/10 à noite: 3 de 121). Os três perguntam
  `parado()` onde a tela segura o relógio, e seguem lendo `pausado` onde a
  pergunta é a pausa do jogador.

## Build #9 — 05/10/2026 (edição Tripothon)

- **Build especial do concurso, estática.** Novo preset de exportação "Windows
  Tripothon" (`export_presets.cfg`, cópia do "Windows Desktop" com a feature
  `tripothon`, saída em `build/tripothon/MythsValley3D.exe`; o preset normal não
  mudou). Com a feature, o `Atualizacao` nunca consulta o site, baixa nem instala
  (`edicao_estatica()`), e a linha embaixo da versão no menu fica à vista,
  desativada, dizendo "Edição Tripothon · atualização desativada" nos três idiomas.
  Portão: `tests/atualizacao.gd` (finge a feature com `forcar_estatica`).
- **O lobby da build do Tripothon é um vídeo, e não o vale 3D.** Com a feature
  `tripothon` (ou `-- --lobby-video` no editor), a abertura tira o `Cenario` antes de
  ele entrar na árvore e põe por trás do retábulo o sobrevoo pintado do LTX
  (`assets/prototipo_3d/identidade/video/carregamento_sobrevoo.ogv`, 21 s, laço sem
  emenda, Theora 1280×720, mudo). O menu deixa de montar o vale inteiro só para o voo
  de fundo (a primeira carga levava ~27 s) e de desenhá-lo a cada quadro. Nesse modo o
  botão do mapa do menu não nasce (não há vale para mostrar), e "Sobrevoo" desligado
  em AJUSTAR para o vídeo no quadro. Sem a feature, o menu segue com o vale 3D, e os
  portões rodam nele. As telas de carregamento ficam na capa estática: a montagem
  segura a thread principal, e um vídeo ali engasgava. A cinemática de abertura gerada
  no mesmo lote ficou só no site. Gerado com a API do LTX a partir das pinturas do
  próprio projeto (`assets/CREDITOS.md`); `*.ogv` entra como binário no Git, sem LFS.
- **A tela do JOGAR só sai quando o vale termina de verdade.** `prototype.gd` avisa
  `carga_concluida` no fim do `_ready` (moradores, bichos, telas, partida salva); a
  `tela_carregamento.gd` reserva o último décimo da barra para esse trecho, espera o
  aviso com teto de 15 s e segura 3 quadros com o mundo visível por baixo da tela opaca
  antes do fade, para os shaders compilarem escondidos. Não encurta a carga: troca
  "terminou e congelou" por uma barra que fecha quando acabou (relatório C4/C5 de
  `docs/projeto/DESEMPENHO_05_10_2026.md`).
- Histórico do jogo: `build_numero` 9 e a entrada "Edição Tripothon" (05/10/2026) nos
  três idiomas, com o que mudou na build de desempenho: carga sem o congelamento de
  19 s, FPS dobrado (sombra, faces de trás, mata mais leve), mata pela metade com
  clareiras de árvore-destaque, minimapa pintado e estático, e o lobby em vídeo.
- **A meta da onça: o patuá da Dona Zefa (#117).** Pela lista de missões do 2D
  (`MISSOES_DO_2D.md`, 3.11), a segunda meta do caderno dos bichos estava por
  escrever desde que a onça chegou ao vale. Agora `data/missoes_metas_onca.json`,
  pendurada na Dona Zefa, abre sozinha quando a conta de abatidos de onça chega
  à do caderno (`bichos.json`: duas), como a do caititu; o couro de onça levado
  a ela fecha a meta e paga o patuá e o XP, nos três idiomas. As contas das
  metas passam a ser lidas do caderno para toda espécie que tenha uma
  (`prototype.CADEIA_DA_META`, `_conferir_as_metas`). Portões `frentes` (a
  parte 8b) e `idiomas`.
- **Os portões da equipe acompanham as fatias de 06/10.** `missoes_elos` conta
  23 filas e 88 passos (os dois do fim do capítulo 6, #114, e a meta da onça,
  #117). `colisoes_de_passeio` lista como exceção, com a razão, o corpo que
  prende nas cercas de varas das roças: as cercas ganharam corpo na #104 e a
  malha de navegação não as lê de propósito — as rotas revistas são a #125. O
  mesmo `missoes_elos` reprova na própria main da equipe, às 17h30, com o E ao
  lado do Tonho (#128): não é da junção, e fica aberto.

## Em desenvolvimento — 05/10/2026

- O machado chega na ponte, como no 2D: o jogo novo não dá mais machado de
  saída, e a chegada também não. O fogo da primeira noite sai da galhada seca
  do terreiro, quebrada na mão: um monte só, onde ficava o tronco da casa, que
  se refaz enquanto o jogador não carrega machado (a lenha de antes da ponte não
  é mais contada, e gastar uma a mais na bancada não deixa a janta por assar) e
  rende a última vez quando o machado chega. Na ponte, depois de contar ao Pedro
  o que viu, ele conduz até a porta
  da casa dele, perto do píer, e entrega os machados do avô ("Toma. Esse tem mais
  idade que nós dois somados"). O cabo da foice e o mato do Damião, a rede do
  Tonho e a carroça do Seu Benedito esperam esse machado. O marcador de missão
  aponta o que o jogador consegue bater (o galho seco, e não o tronco que pede
  machado). Portão novo: `machado`.
- A ferramenta que a missão entrega vai para a barra de mão e não troca o que
  está na mão: regar a primeira leira com o balde não pula mais para o machado.
  O HUD diz o número que a põe na mão.
- O foco do E: de tudo o que responde ao E — morador, cordel, árvore, lápide,
  alvo de trabalho, bancada, marco, lavoura, cama e baú, pesca e luta —, um só
  leva a tecla e acende a dica: o que está na frente do jogador, e mais perto. O
  cordel aos pés com a Dona Candinha do lado se pega virando para ele; virar
  para ela é conversar. Com bicho perto, o E é golpe antes de tudo. E o cordel do
  píer saiu de debaixo do Tonho: pendia no ponto exato em que ele fica, e o E
  empatava entre os dois. Portão novo: `foco_do_e`.
- O relógio para na conversa: a fala da missão e a resposta do E no balão, a
  narração do vale, o aviso da primeira vez e a festa da missão cumprida seguram
  o dia enquanto duram (não é o relógio parado do jogador, e não custa
  conquista). A caixa de fala já parava o vale.
- A festa da missão cumprida ficou suave: a sombra sobe devagar, uma luz clara
  se abre atrás do emblema, tudo fica mais de três segundos e, no fim, a tela
  clareia e a festa se desfaz nela. E ela espera a conversa: o passo que fecha
  no E fecha com o morador ainda respondendo, e a festa só entra depois.
- O aviso de voltar para perto do Pedro: na condução, quando ele para porque o
  jogador ficou para trás, o alto da tela diz "Pedro está esperando você: volte
  para perto para seguir", até o jogador voltar.
- Da praça à Dona Zefa, o Pedro atravessa a ponte do rio central: a malha de
  navegação dos moradores não tem mais o leito dos rios, e quem anda pela malha
  atravessa rio pela ponte. `navegacao` cobra o rio e a ponte.
- Os avisos da primeira vez: o primeiro cordel pego conta o que é um cordel —
  para quem não é do Nordeste — e que ele fica no almanaque (L), com a capa dele
  ao lado; a primeira árvore conhecida diz o mesmo do almanaque. O vale e o
  relógio param enquanto o aviso está aberto. Portão novo: `avisos_da_primeira_vez`.
  O cartão mora acima do HUD, como a caixa de fala e o folheto, e as plaquinhas
  de nome dos moradores se recolhem enquanto ele e a festa da missão estão na
  tela (elas são do HUD e caíam por cima do texto e do emblema).
- O E em quem não fala é aceno: os moradores novos têm jornada e nenhuma fala,
  e a conversa do E neles abria um balão vazio e segurava o relógio por uma fala
  que não havia. `interacao` cobra.
- O X que fecha o quadro da missão entra na tabela de atalhos (AJUSTAR →
  Atalhos, "Fechar o quadro da missão"): estava escrito à mão no HUD, que ouve
  antes do vale, e comia o atalho que o jogador pusesse no X. O botão escreve a
  letra escolhida. `atalhos` e `paginas_missao` cobram.
- O cordel pendurado no barbante tem capa dos dois lados, com o título impresso
  no alto e a xilogravura embaixo: quem chegava pelo verso via uma folha em
  branco.
- A lavoura da casa ganha relevo e cercado: cada leito é um monte de terra, com
  três camalhões quando arado e o molhado mais escuro, sobre a terra batida do
  campo — nas texturas pintadas do chão do vale, com os sulcos da terra arada em
  cima dos sulcos do relevo — e um cercado rasteiro de vara em volta, com a
  passagem do lado da casa.
- O Pedro narra a explicação das três barras (a vida, o fôlego e o vigor) na
  voz dele, linha a linha, na caixa de fala (cinco falas novas do ElevenLabs,
  `tools/elevenlabs/gerar-falas-do-guia.ps1`).
- O balão de fala dos moradores e a dica do E no desenho do jogo: a laca
  verde-escura com filete de ouro, o nome em Cinzel e a fala em Cormorant
  Garamond, com o balão acima da dica do E.
- O vale ganha céu: um shader próprio (`ceu_vale.gdshader`, `CeuVale`) com
  azul-cobalto de dia, sol com disco, lua, estrelas e Via Láctea à noite (não
  há luz elétrica em 1887), cúmulos de tempo bom que andam devagar e cirros
  sutis; a outra margem da baía aparece como morros na bruma. A névoa passa a
  ter perspectiva aérea — o mar e a serra se dissolvem no próprio horizonte, e a
  serra não fica mais "pelada" quando a mata some ao longe —, com neblina de
  baixada na alvorada. A terra de fora do quadro sobe com o mesmo exagero do
  relevo: o degrau na borda do mundo caiu de 11 u para 0,3 u. Portão novo:
  `ceu_horizonte`.
- O chão deixa de ser uma textura só. Oito camadas — grama baixa, capim seco,
  folhiço, terra batida, barro vermelho, pedrisco, areia de restinga e lama de
  mangue, com nove texturas novas da OpenAI (gpt-image-2, `tools/openai/`) —
  se misturam por um mapa de solo montado com o vale (`mapa_de_solo.gd`), pelo
  declive e pela altura de cada textura (`terreno.gdshader`). A rua se desfaz
  num acostamento esfarelado, o cruzamento é terra sem direção, a praça tem
  borda ruidosa, a praia e os rios se desfazem em restinga e lama, o terreiro é
  varrido em oval, a lavoura é terra arada e cada casa tem trilha de pé até a
  rua. Os passos leem o chão novo. Portão novo: `mapa_de_solo`
  (`docs/mundo/SOLO_E_FRANJAS.md`).
- A mata vira manchas de uma espécie só, por lugar — encosta, topo, baixada,
  beira de rio, borda e restinga —, com seis espécies novas da mata atlântica
  (jatobá, sapucaia, jequitibá, cedro, angico, massaranduba) e as versões
  leves das árvores pesadas (de 12–16 mil faces para cerca de 5 mil); a pureza
  da vizinhança foi de 0,19 a 0,67. A gameleira volta a ser única, com modelo
  próprio. Nenhum tronco fica a menos de 4 u da rua, e o caminho do píer à
  gameleira não atravessa mais o coqueiro em (−36, 112): a malha de navegação
  abria o buraco do tronco sem a folga do corpo e o simplificava numa aresta.
  Portão novo: `mata_em_manchas`; `navegacao` amostra a cada 0,25 u.
- O arraial deixa de ser vazio (78% de chão sem planta a 9 u, agora 10%): uma
  cena de zonas editável (`paisagismo_vale.tscn`, com receitas em
  `data/paisagismo/`) planta bananal, sítio das mangueiras, pomares de quintal
  de uma fruta cada, roças de mandioca, milho e fumo em fileiras, dendezal da
  foz, cajual do outeiro, piaçabal de restinga e a mata ciliar dos rios (ingá,
  jenipapo, bambu, helicônia, samambaia, taboa), com cerca de varas e porteira
  nas roças, estaleiro de fumo, carro de boi na estrada da roça, monjolo na
  beira do rio e barracas de feira na praça. Mover uma casa só tira os pés que
  ela cobre. Portão novo: `paisagismo`.
- A serra fica vestida ao longe: onde cada bloco de árvores some (280 u), entra
  a copa de longe da espécie — o modelo de longe do Tripo nas palmeiras até
  600 u e uma copa de 64 triângulos na cor da espécie até 1.200 u
  (`copas_distantes.gd`), por +5 a 10% de triângulos. `lod_vegetacao` cobre as
  copas.
- A câmera não salta mais. O braço só bate no que é parede de verdade —
  terreno, fundo do mar, casas, igreja, pedras — numa camada própria
  (`camadas.gd`), e entra rápido e sai devagar. Passar ao lado do cruzeiro,
  girar junto da mata, andar no convés do saveiro e cruzar com um morador
  deixam o braço em 8 m, sem salto; antes, no cruzeiro, ele caía de 8 para 1 m
  num quadro. As colisões ficam onde está o desenho: o cruzeiro deixa de ser
  uma parede invisível de 2,6 m, as casas medem a pegada na altura do corpo e
  não o beiral, o poço, o lampião e o mastro vão para o eixo de verdade, os
  troncos da mata para o tronco desenhado (a aroeira ficava 1,35 u fora) e o
  saveiro tira a vela e o mastro do casco. Portões novos: `colisoes_do_vale` e
  `colisoes_do_vale_procedural`.
- Os itens de mão cabem na mão. A enxada, o balde, a vara, a picareta e a
  mandioca foram refeitos no Tripo — a enxada tinha a lâmina do tamanho do
  cabo e a "mandioca" era um chapéu —, e todo cabo é segurado no molde do
  machado, com pose por estado. Arar leva a lâmina ao leito, regar tomba o
  balde, pescar ergue a vara com a linha até a bóia e dá um tranco quando o
  peixe fisga; nadando, o item some. Machado e facão ficam como estavam. Com o
  corpo do jogador trocado pelo viajante do Tripo, cujo osso da mão gira 158° em
  volta dos dedos em relação ao do personagem medieval, a tabela de encaixes
  (`Vestimenta3D.NA_MAO`) foi levada para o osso novo — cada peça fica na mão como
  o machado aprovado a segurava —, com a pegada do machado, do facão e da foice 1
  cm mais para dentro da palma e a enxada com pose própria no andar. Portão novo:
  `itens_na_mao`.
- Catorze moradores novos, sem fala e com jornada: o padre Anselmo, o
  sacristão Zacarias e Sá Joaquina, o vendeiro Seu Nicolau, o guarda Aristides
  (sem arma, de candeeiro à noite), o pescador Seu Jerônimo, a marisqueira Dona
  Rosa, a lavadeira Sá Rita, a rendeira Dona Estefânia, a quituteira Dona
  Ambrósia, o carpinteiro Seu Epifânio, as crianças Tonico e Mariinha e o
  saveirista Seu Ladislau. Cada um tem casa, ofício nos três idiomas e agenda
  por hora: sai antes para chegar na hora, trabalha no posto com o clipe do
  ofício e o que leva na mão ou na cabeça (vassoura, trouxa, tabuleiro, vara,
  candeeiro), e recolhe à noite. Oito casas novas nos lotes do oeste da praça,
  a casa paroquial, e um varal em cada uma das 19 casas, no quintal e fora do
  caminho da porta. Portão novo: `rotina_dos_moradores`.
- O vale ganha bichos de casa e da mata (`bichos_de_casa.gd`,
  `data/bichos_de_casa.json`): cães caramelo no Pedro, no Tonho e no Benedito,
  que seguem o dono de dia e deitam na porta à noite; gatos na Venda, no
  Restaurante e em mais casas, que fogem do cão; galinhas, galo e pintos em 8
  quintais, que sobem na pitangueira ao entardecer; galinha-d'angola na Zefa,
  patos no riacho, porcos no chiqueiro do Benedito, cabras e bode no terreiro
  dele, o jumento de cangalha na Venda, e o pavão com três pavoas no adro, que
  abre o leque quando o jogador para perto. As onças, pintada e preta, moram
  cada uma no seu penedo com lapa, longe das casas: veem o jogador pelo cone e
  pela linha livre, farejam pelas costas, avisam uma vez e atacam, e a coleira
  do território as manda de volta; a preta só anda do entardecer à madrugada,
  de olhos acesos. Portões novos: `onca`, `bichos_de_casa` e
  `bichos_de_casa_procedural`; `luta` conta por espécie.
- O mar ganha cardumes (`fauna_vale.gd`, `cardume.gd` em MultiMesh com nado
  por shader): tainhas e uma bola de sardinhas em cada canoa, xaréus que
  atacam as bolas, sargentinhos e budiões nas pedras, piabas, acarás e traíras
  nos poços do rio, cavalas e sororocas no mar de fora e bandos de raias; o
  peixe foge de quem nada e de quem caça, e fica sempre acima do leito. O
  tubarão vira o cabeça-chata do Tripo e caça cavalas e sororocas a cada 45 a
  90 s, sem deixar de caçar quem nada no fundo. Portões novos: `fauna_do_mar` e
  `fauna_do_mar_procedural`.
- Os modelos desta noite vieram do Tripo Studio pela ponte do Playwright MCP
  (`tools/tripo/lote_producao.js`): 14 moradores com rig Mixamo e até 13
  clipes, 31 bichos (os quadrúpedes com o rig do Studio), 16 peixes e raias e
  o tubarão, 25 plantas e árvores, 12 casas e construções, 16 adereços de
  quintal e roça, 9 itens e 32 versões leves e de longe das árvores que já
  existiam — 14.035 créditos, no extrato da carteira. Registro em `ORIGEM.md` de cada pasta, em
  `assets/CREDITOS.md` e nos lotes `tools/tripo/lote_2026-10-05_*.json`.

- A jornada da fazenda, a fatia 6.1 do 2D: do outro lado do rio grande, na ponta
  da Rua Principal, a fazenda do convite — o portão baixo de ferro fino e a
  guarita de pedra velha do capítulo 6, o pátio de terra batida e o casarão
  (modelos novos do Tripo). Na manhã seguinte à fé escolhida, com a ponte de pé,
  o arraial está sentado no pátio e o Pedro vem à porta: "acorda, que é hoje".
  Ele conduz o jogador pela ponte até o portão; lá fala do portão que não guarda
  nada, o escuro sobe e a voz do mundo narra a chegada (o E passa a frase), e os
  dois estão dentro. No pé da escadaria, a fala dele fecha a fatia; no dia
  seguinte o arraial volta para casa. Depois do tutorial o Pedro passa a
  conduzir quando a fila dele pede (`conduz`). Portão novo: `fazenda`.
- A lapa e a cabra, a frente do ofício do 2D: entre a casa e a chapada, uma
  lombada de pedra com a rampa trancada pela lapa que a chuva rolou. Depois da
  lenha da ponte, o E no Pedro manda rachá-la com a picareta — oito golpes, oito
  pedras, o calço da varanda —, e a passagem aberta fecha o passo. Lá em cima,
  a cabra do Seu Benedito (modelo novo do Tripo) desce quando o jogador chega
  perto, e a placa da Santa Casa diz de quem é o alto. A mata abre clareira na
  lombada e na chapada. Portão novo: `lombada`.
- A chapada do Seu Benedito, a frente do 2D que mostra terra que poderia ser do
  jogador: depois da primeira colheita, o E no Pedro manda ver a terra alta para
  lá da Dona Zefa, de frente para o rio grande (lugar revisado pelo autor). A
  chegada acende a luz dourada na tela e paga a garapa e a cocada; de volta, o
  Pedro fala da água que corre o ano todo. Passo de missão novo: `cena`, que o
  vale toca quando o passo fecha. Portão novo: `chapada`.
- O canteiro de obras chega ao roçado: a mesa do prumo, ao lado da bancada da
  oficina (provisória, a mesma mesa), onde o E abre a aba de obras dela. Antes
  do mirante, como no 2D, o Pedro manda juntar oito tábuas e doze lenhas e
  riscar a prancheta, que abate 10% de toda obra do mapa; o material do
  mirante passa a ser a conta de hoje da obra (`juntar` com `da_obra`).
  `cadeia_do_mirante`, `rocado` e `ferramentas` cobrem o canteiro.
- A ponte do rio grande, a frente da trilha do 2D: o rio grande é o rio do
  norte do mapa, raso de dar pé, e a ponte da Rua Principal começa cercada nas
  duas cabeceiras — a cheia comeu os esteios do meio. Gente atravessa no vau, ao
  lado. Depois da chegada, o primeiro E no Pedro abre a frente: ver a ponte,
  voltar e contar, juntar a lenha (trinta e seis paus, e a tábua e a corda já
  feitas contam), serrar doze tábuas e quatro cordas na bancada e levantar a
  ponte no J, na aba de obras, ao pé dela. A obra tira a cerca. O mirante passa a
  esperar a ponte, como no 2D. Quem esgota o fôlego na lenha ou nas tábuas ganha
  as seis cuias de mungunzá da mãe do Pedro, uma vez. Meta nova: `juntar` com
  `equivale`. Portão novo:
  `ponte`; `cadeia_do_mirante`, `cadeia_da_fe`, `missoes`, `ferramentas`,
  `idiomas` e `painel` ajustados.
- As frentes do 2D que não pedem lugar novo chegam ao vale: as **armas** do
  Pedro (bater um facão na oficina, derrubar um caititu, o golpe de peso, que o
  passo ensina), o **ofício** (a vara do pai do Pedro e dois peixes, e um
  talento destravado na teia), a **capoeira** do Cosme para quem é do
  candomblé (a ginga, a meia-lua e a rasteira, cada lição de volta ao Cosme), a
  **meta dos caititus** (dez derrubados, e o Pedro dá o gibão do pai), a
  **caderneta** na chegada (abrir o J) e a **primeira refeição** no fim da roça
  (comer o pirão da Dona Filó). As frentes do Pedro abrem uma por E, depois da
  chegada; a da onça espera a onça. Meta nova: `contar` (o mesmo acontecimento
  N vezes, que o save lembra). Portão novo: `frentes`.

- Falar com os moradores é o E, e é o Pedro quem ensina, no desembarque. Perto
  de alguém, a dica "E — Falar" aparece sobre a cabeça dele: o E conversa (a
  fala inteira no balão), cumpre o passo que manda falar com ele ou levar
  alguma coisa ("Entregar"), e abre a fila de pedidos de quem tem o que pedir.
  Chegar perto não fecha mais passo nenhum, e fila de morador não abre mais
  sozinha. Na chegada, o E no Pedro repete o que fazer agora.
- Todo passo de missão cumprido escurece a tela por um instante e mostra o
  emblema dourado, "Missão concluída", o nome do passo e a missão de que ele é.
- Partida nova no mesmo slot começa com o caderno de missões limpo. Ele não
  voltava à fábrica, e o HUD e o marcador seguiam a missão da partida apagada
  — a chave com a Dona Candinha, com a chegada nova em outro passo.
- O passo que espera a palavra livre para se anunciar espera no máximo 6 s:
  num lugar cheio, os cumprimentos emendavam e o passo nunca começava.
  Portão novo: `interacao`; os das filas dos moradores, `cadeia_das_missoes`,
  `chegada`, `saudacao`, `cadeia_do_mirante`, `cadeia_da_fe`,
  `pedidos_do_arraial` e `saveiro` passam a falar com o E.

- O jogo começa em cima do saveiro do mestre Quirino, atracado no píer: um
  modelo novo do Tripo (lote de 05/10, `aderecos/saveiro_tripo.glb`), que
  assenta carregado e desce ao tabuado por uma prancha. O barco fica o primeiro
  dia inteiro, sem o mestre e sem a compra, e larga quando o dia vira. O corpo
  do casco agora acompanha o barco ao atracar; antes ficava 0,38 acima do
  desenho, e isso valia também para o barco do dia 14.
- A chegada segue a ordem do 2D (`docs/projeto/MISSOES_DO_2D.md`): descer do
  saveiro andando (WASD ou setas), correr um trecho com o Shift, e o Pedro vai
  NA FRENTE e apresenta o Tonho, a Dona Candinha e a Dona Zefa, que dá a chave.
  A casa fica trancada até a chave; dentro, o baú tem as ferramentas do finado
  (a enxada, o balde e a maniva), o J abre a caderneta, e a primeira roça vem
  no primeiro dia, antes do fogo, do poço, da janta, da noite e do convite.
  Dezesseis passos.
- Na primeira vez que o vigor cai a 30% na caminhada em que o Pedro conduz,
  ele explica as três barras — a vida, o fôlego e o vigor — numa fala longa;
  quem chega à porta sem cansar ouve o mesmo lá. Uma vez por partida, e vai no
  save.
- O save de antes desta ordem volta ao mesmo passo, e quem volta sem a enxada
  a acha no baú. Portão novo: `chegada`; `cadeia_das_missoes`, `saveiro`,
  `ferramentas`, `pedidos_do_arraial`, `passagem`, `casa`, `navegacao`,
  `interiores`, `rota_por_terra`, `saudacao`, `mapa_fluxo`, `painel` e
  `alcance_dos_alvos` ajustados.
- A bateria nova (`testar.ps1`, só os portões afetados, em paralelo) roda no
  Windows PowerShell 5.1: o caminho do projeto com espaço e a lista de arquivos
  modificados quebravam todos os portões antes de começar.
- O MCP do Godot tem guia (`docs/ferramentas/GODOT_MCP.md`): o `godot-editor`,
  servidor do addon que o Ramon trouxe, edita cenas e scripts com o editor
  aberto; o `godot` abre o editor, roda o jogo e lê a saída sem editor. Cada um
  registra os dois no seu Claude Code, com o comando do seu sistema.

- Abrir e fechar o painel (J) não para mais o relógio. O painel parava o
  relógio por conta própria antes do dono das telas, que então guardava "já
  estava parado" e devolvia isso ao fechar. Fechar pelo × também devolve o vale,
  a câmera e o movimento (o conserto do Renato na `feature/retomada-hud`).
- A fogueira é sólida nos dois estilos: o corpo não entra mais no meio das
  toras acesas.
- A bancada da oficina ganha peça e corpo (a mesa rústica do Tripo; no
  procedural, a caixa cinza ganha colisão), muda para trás da casa, longe do
  tronco caído que roubava o E, e abre com o E, como no 2D; o E na fogueira
  abre o fogão. O Pedro passa a dizer "aperta E" na corda e na janta.
- A casa do jogador começa com o básico — cama, baú, o pote d'água e a
  lamparina — e cada obra de mobília feita (mesa e banco, oratório, estante,
  canto da cozinha, rede) põe o móvel dela no cômodo. As obras já davam XP e
  atributo. Nas três casas, nenhum móvel de chão toma mais a passagem da porta:
  a cantareira, o barril e o fogão ficavam no vão da casa herdada, e a rede do
  Cosme atravessava a entrada da casa da Dona Zefa. Portões novos: `rocado` e
  `rocado_procedural`; `moveis` e `painel` ampliados.

- Morador com missão não cumprimenta mais ao chegar perto: fala só a missão.
  O Tonho, no bom-dia da chegada, respondia a missão e logo depois soltava a
  saudação de passagem, e o jogador não sabia qual das duas valia. Vale para o
  dono da missão, para quem ela manda procurar e para quem vai abrir uma ao
  chegar perto.
- O balão da saudação de aproximação fica curto: a primeira frase, com no
  máximo 60 letras. A voz e o aviso do HUD continuam com a fala inteira, e as
  falas de missão continuam inteiras no balão. Portão novo: `saudacao`.
- `docs/projeto/MISSOES_DO_2D.md` reúne todas as missões do jogo 2D, em ordem,
  com objetivo, gatilho, recompensa e a situação de cada uma no 3D: a base para
  trazer o que falta.

## Em desenvolvimento — 04/10/2026

- A chegada do Pedro deixa de ser visita guiada: onze passos em dois dias, cada
  um nascido de um morador ou da casa do finado — o bom-dia ao Tonho, a chave
  que a Dona Candinha sabe com quem ficou, o fogo, o mutirão do poço com a Dona
  Zefa e o Cosme, a janta, a cama, a leira e o convite sem assinatura, que é o
  gancho do capítulo 6. Quem pede paga com o que tem em casa, e o HUD diz quem.
  As filas dos moradores abrem depois da chegada, e o save de antes dela volta
  ao passo novo que faz o mesmo papel (docs/mundo/CHEGADA_E_MUTIROES.md).
- Duas filas novas: a roça do Cosme (colher, torrar a primeira farinha e levar
  a cuia à Dona Filó, que ensina o pirão) e a carroça do Seu Benedito, o
  primeiro caminho de favor dele, consertada em mutirão: o Cosme e o Tonho
  trazem o que falta ao chegar.
- As cadeias ganham `quem_paga`, entrega em lista, `eventos` e `mutirao`, e o
  vale passa a avisar a janta, a farinha, a corda, a leira, a cama e o papel
  lido. Portões: cadeia_das_missoes joga a chegada inteira pelo caminho do
  jogo; pedidos_do_arraial cobra a roça, o mutirão, quem paga e o save antigo.
- As quinze construções atuais ficam selecionáveis por nome numa cena do Godot,
  com terreno e oito ruas de referência (#57). Mover e girar uma casa, salvar e
  executar o projeto aplica a transformação à casa, colisão, interação e âncoras.
  A cena também pode ser editada por código. A primeira extração preserva as
  posições atuais e recusa sobrescrever autoria; regenerar o terreno não altera
  as posições salvas. O traçado das ruas continua na base geográfica.

- O jogo abre em tela cheia. F11 alterna entre tela cheia e janela em qualquer
  tela, e o novo botão do canto do menu faz o mesmo, com a dica ensinando o
  atalho. A escolha fica salva; em janela, o jogo ocupa 80% do monitor em 16:9.
  O "?" do mapa desce uma posição na coluna do canto.
- O mouse não some mais ao carregar o vale: o jogador deixava o cursor preso
  desde o primeiro quadro, por baixo da tela de carregamento; agora só o modo de
  câmera escolhido o prende, quando o vale fica pronto. O jogo ganha cursor
  próprio, seta e mão em ouro com contorno de laca.
- O cursor vira escolha em AJUSTAR > Cenário (seção Interface), no menu e no
  vale: Clássico, Ouro polido (o novo padrão), Azulejo, Talha com punho,
  Pergaminho e Luz do lampião. Todos seguem a mesma regra: seta para apontar e
  mão com o indicador para clicar. A troca vale na hora e fica salva.
- A interface fica menor por padrão: botões com fonte e altura globais (as placas
  do menu seguem as mesmas medidas) e a coluna de botões do canto, no menu e no
  vale, com placas de 40 em vez de 52. AJUSTAR > Cenário > Interface ganha
  Tamanho do texto e Tamanho do HUD, que valem na hora e ficam salvos.
- A escolha de idioma fica mais leve: botões menores, espaçamento equilibrado,
  modal mais alto, versão junto dele e um × discreto no canto para sair do jogo.
  Cada botão mostra, discretas, a última escolha salva e o idioma do sistema.
- PERSONAGENS fica igual nas duas abas: cartões com filtro e, ao abrir um, a ficha
  com prévia 3D (fundo de azulejo, girar arrastando, todos na mesma altura) e
  navegação no rodapé, também pelas setas do teclado. Editar e gravar no projeto
  (disquete dourado com ajuste pendente, confirmação ao sair) ficam ao lado do ×.
  As falas aparecem juntas; o ▶ vira pausa e toca mesmo com o som desligado. O
  viajante abre a lista, e os moradores saem da aba ASSETS.
- O histórico fica mais compacto, com a navegação junto do número da página e
  cada item começando pela ideia central em dourado.
- As dicas (tooltip) seguem a identidade dos botões do canto; o "Por trás do
  vale" ganha o link do site e letra menor; sai a mancha atrás do almanaque.
- PERSONAGENS vira MODELOS, no tamanho dos outros modais: Pedro abre a lista e o
  viajante do Tripo a fecha; a prévia tem tamanho fixo, escala comum (cada morador
  na sua altura), moldura, luz de cima e sombra nos pés, e gira, aproxima, move e
  centraliza com o mouse. A ficha tem linhas fixas, e restaurar e concluir a
  edição ficam no cabeçalho.
- O MAPA do menu abre com o painel do Mapa do Vale à vista; fechado, um "?" no
  canto esquerdo o traz de volta.
- AJUSTAR fica na altura dos outros modais, os atalhos ganham aba própria e a
  ajuda do "?" fica maior. O foco dos botões de ícone perde o contorno duplo.
- O histórico do jogo ganha os dias 29/09, 30/09 e 01/10 e mais itens por dia,
  tirados do git log.
- A travessia ganha narração própria e música nova: as nove legendas narradas pela
  voz do narrador do projeto (ElevenLabs Eleven v3, numa tomada só) e cortadas em
  um trecho por legenda pelos tempos do Whisper; cada legenda dura o seu trecho, e
  CONTINUAR e PULAR fazem a voz sumir antes da próxima, sem encavalar. O tema da
  travessia (ElevenLabs Music) fica por baixo da voz. A narração de boas-vindas
  antiga, que não falava da travessia, sai de cena.
- A escolha de idioma ganha folga vertical, e o aviso do rodapé fica centralizado.
- O sobrevoo do menu volta a passar longe das árvores no estilo Tripo. A revisão
  da foz tinha posto um mangue no vão por onde o voo cruza a fileira da orla, na
  ida, e as folhas de um coqueiro a 1 m da câmera, na volta. O vão norte fica
  livre (um mangue deixa de nascer ali) e a volta passa 9 m mais ao sul; a ida e
  a curva da praça são as mesmas. Folga mínima: 6,12 m no Tripo e 5,74 m no
  procedural.
- No vale, o botão de FPS fica no alto do canto e acompanha o Tamanho do HUD;
  os outros botões do canto continuam dentro do menu do Esc.
- O portão `mapa_fluxo` mede a corrida em terra: do píer, correr de lado caía
  na água e media o nado.

- As trilhas do menu, do jogo, dos períodos e da mata mudam com fade de saída
  e entrada. Parar a música também reduz o ganho antes de encerrar; pedidos
  durante uma transição cancelam o callback anterior e mantêm o volume atual (#79).

- PERSONAGENS apresenta um morador por vez, com prévia 3D do modelo do jogo,
  navegação entre moradores e falas, busca e edição individual. ASSETS ganha
  cartões paginados; selecionar uma peça abre seu registro e sua edição.
  O × fecha o painel; o FECHAR redundante sai do rodapé (#78).
- Vagas usa um modal central com × no cabeçalho, sem VOLTAR no rodapé (#77).

- O histórico do jogo resume cada item em uma linha e mostra até oito itens
  por página, sem rolagem. A entrada de 03/10 incorpora publicação das builds
  e validação de arquivos registradas no Git; a de 04/10 resume a nova interface.
- Modais ocultam as notas “Dizem no vale”/“Do almanaque” e sua sombra; fechar
  restaura o almanaque do fundo (#77).

- A versão/build no menu abre o histórico sem sublinhado no hover ou foco;
  o cursor de mão indica que continua clicável (#77).

- A seleção reserva a altura dos textos dos quatro idiomas com as fontes
  efetivas, mantendo modal, botões e build imóveis durante a prévia. O último
  idioma sob o mouse permanece marcado mesmo após sair do botão; a confirmação
  continua sendo por clique ou Enter (#77).

- Na seleção, o destaque do botão acompanha a língua dos textos ao passar o
  mouse. Enter confirma a prévia visível, sem salvar o idioma durante o hover.
  O portão confere também que a intro usa a língua confirmada (#77).

- O modal de idioma sobe para acomodar a identificação da versão e da build
  centralizada logo abaixo. O carimbo vem de `Versao`, a fonte usada nos saves (#77).
- O menu Jogar/Explorar, suas páginas e os painéis internos passam a usar a
  mesma talha SVG da home. A textura antiga do retábulo sai do componente
  compartilhado; as molduras continuam acompanhando posição e visibilidade (#77).

- A seleção inicial recebe a moldura SVG da home: talha nos quatro cantos,
  filetes dourados e linha azul. As nove fatias preservam os ornamentos ao
  redimensionar o painel, com a capa estática (#77).
- Sem idioma salvo, a entrada sugere a língua do sistema (português, inglês,
  espanhol ou chinês), com inglês para línguas sem suporte. Uma escolha salva
  tem prioridade; a sugestão continua aguardando confirmação (#77).

- Na seleção inicial, passar o mouse ou focar um idioma pelo teclado traduz
  o título, a orientação e o aviso para esse idioma. A prévia só vira
  preferência salva quando o jogador confirma a escolha (#77).

- Na seleção inicial, a marca fica centralizada acima do painel, que desce
  para dar espaço ao logotipo e ao subtítulo. O carregamento mantém sua
  composição própria (#77).

- A seleção de idioma fica no centro, com moldura dourada e fundo escurecido
  para destacar a escolha. A imagem permanece estática tanto na seleção como
  no carregamento, sem zoom nem efeitos animados na capa noturna (#77).

- A entrada pergunta o idioma antes de carregar a abertura 3D, usando a mesma
  capa de dia e o logotipo do carregamento. Mouse e teclado escolhem português,
  inglês, espanhol ou chinês; a preferência salva recebe foco na próxima abertura (#77).
- Chinês traduz a seleção e as etapas do carregamento; o restante do menu usa
  inglês enquanto a tradução está em preparação, conforme aviso na seleção.
  Vozes e partes do vale continuam em português; a tradução integral segue na #51.
- O portão `selecao_idioma` confere que o cenário não carrega antes da escolha,
  a persistência dos quatro idiomas, o foco, o clique duplicado e a transição.
- Vida, fôlego e vigor aparecem alinhados, com nome e valor atual/máximo nos
  três idiomas. O vigor do HUD acompanha Energia diretamente, sem depender
  do módulo das árvores (#45).
- Corrida, salto, corte, trabalho e luta gastam vigor. O fôlego só é consumido
  durante o nado; continuar nadando depois que ele acaba tira vida. Descanso
  recupera respiração; sono e desmaio a enchem (#45).
- Fechar as missões pelo botão × avisa ao controlador das telas para devolver
  o movimento, a câmera e a pausa do vale. O painel deixou de pausar o relógio
  por conta própria, para que a restauração da pausa tenha um único responsável.
- Corrige a inferência de tipo do ícone de missões que impedia o HUD de
  compilar. A camada da interface já existe na cena e é reutilizada na
  inicialização; o smoke espera a montagem do mundo antes de medir o corpo.
- Portão `reservas_do_corpo`: cobrança, recusa sem efeitos, recuperação,
  ligação com Energia, atualização das três barras, save e redimensionamento.
- Ajusta preparações antigas dos portões: vida passa a definir o vigor pelo
  personagem; energia confere a barra de vigor; a barra de mão exige o
  machado nos espaços numerados, conforme a regra já integrada no código.
- As cadeias e as ferramentas selecionam o item recebido pela barra para
  medir o trabalho. O menu confere as dicas da coluna direita reintroduzida
  no commit anterior; a roda sem Ctrl volta a escolher a mão (#37).
- As esperas pela troca de cena têm teto de tempo de parede, em vez de
  pressupor uma quantidade de quadros para o carregamento assíncrono.
  O runner exige confirmação de término e conserva os logs quando reprova.

- **As vagas viram cartões, com o lápis e a lixeira dentro, e cada partida guarda pontos de
  restauração.** "No MENU de save, ao invés de abrir um combo embaixo para deletar o save,
  coloque o ícone dentro do próprio balão do save. Na esquerda pode colocar o ícone de
  editar o nome do save e deletar o save." E, na volta: "eu pedi para colocar os ícones
  na tela de save na esquerda, mas me confundi. O correto é no lado direito." Cada vaga é
  um cartão. Tocar nele continua a partida (ou começa, na vaga vazia); à direita, dentro
  dele, depois do nome, o lápis edita o nome da vaga e a lixeira apaga, no segundo
  clique, com o cartão dizendo o que se perde. O nome mora fora do save
  (`user://vagas.json`), e gravar a partida não o apaga. O botão "RECOMEÇAR" embaixo de
  cada vaga saiu: recomeçar é apagar e começar na vaga vazia.
  "Aproveite e implemente uma política de 'ponto de restauração', assim impede a pessoa
  de perder o save caso encontre algum bug grave." A primeira gravação de cada dia do
  jogo guarda um ponto da vaga, e ficam os sete dias mais novos. Apagar, começar por cima
  e restaurar guardam antes o ponto do que se perde, e ficam os três mais novos. Os
  pontos moram em `user://pontos/`, longe dos arquivos que o `Salvamento` gira
  (`pontos_de_restauracao.gd`). A seta circular, depois da lixeira, abre os pontos da
  vaga — até da apagada, que volta por eles —, e restaurar pede o segundo clique e
  confere que o ponto se lê antes de tocar a vaga. Portão novo `tests/pontos_de_restauracao.gd`, e o
  `salvamento` confere o cartão; os dois falsificados.
- **O encaixe das Mãos é das luvas; arma vai nos números.** "No campo mãos do inventário,
  não é para armas, mas sim para luvas. Armas são nos campos numerais." O machado, o
  machado de aço e o facão deixaram de vestir as Mãos e ficam na barra de mão (1–0), de
  onde já batiam, cortavam e tiravam a piaçava. O facão perdeu o efeito de cintura que
  dava vestido (−5% no fôlego gasto). A partida salva com um deles vestido o devolve à
  barra e tira o efeito da progressão. A primeira peça do encaixe são as luvas de couro.
- **As luvas de couro, a primeira peça das Mãos.** "sobre a luva, pode gerar". Couro
  curtido de vaqueiro, vendido no balcão da venda por 240 réis e vestido no encaixe das
  Mãos: com as mãos guardadas, a lida cansa menos (−5% no fôlego gasto, o mesmo que o
  facão dava na cintura). O corpo as mostra nas duas mãos, no vale e no boneco da
  mochila (`Vestimenta3D.luvas`). O modelo é uma luva de mão direita; a esquerda vai
  espelhada, e as duas assentam no quadro da mão medido nos ossos dos dedos, e não nos
  eixos do osso, que cada rig vira de um jeito. A luva é rígida, de dedos esticados, e os
  dedos dobrados do modelo furariam o couro: um modificador do esqueleto os encolhe
  dentro dela a cada quadro, e só eles — o machado e o facão, presos ao osso da mão, não
  mudam de tamanho. Modelo do Tripo Studio (95 créditos: geração 55 e retopologia 40)
  e ícone de 32 px do PixelLab, no estilo dos itens do 2D. O cliente do PixelLab veio do
  2D para `tools/pixellab/`, e toda arte gerada fica guardada no cofre
  (`assets/sprites/cofre/`). O portão `boneco_da_mochila` ganha a nona pergunta,
  falsificada.

## Em desenvolvimento — 03/10/2026

- Os créditos e o README registram a confirmação do autor: a fonte Miva é
  criação da equipe, com direitos do projeto, e as vozes foram produzidas
  de forma generativa para o jogo (#40).
- O README apresenta o jogo, a contribuição do Tripo, os controles, os marcos
  do Git e a origem do trabalho para o evento; o guia passa a descrever o
  repositório 3D independente e a build Windows já disponível (#40).
- A atualização limita manifesto e download, confere origem HTTPS e tamanho,
  recusa caminhos perigosos, links e conteúdo inesperado, e valida os registros
  locais e centrais do ZIP antes de qualquer extração (#76).
- A leitura das partidas bloqueia objetos e recursos antes da desserialização,
  preservando o formato e os tipos dos saves legítimos, inclusive os resumos
  das vagas no menu (#76).
- O portão `tests/seguranca_arquivos.gd` reproduz os defeitos com marcadores
  inofensivos e exige rejeição sem executar código nem gravar fora da pasta.
- As correções ficam no código do repositório; a distribuição pública permanece
  na **Build #8** até a próxima versão estável. O SHA-256 continua sendo conferido
  contra o manifesto HTTPS e não substitui uma assinatura de release
  independente do servidor.

- **O boneco da mochila: o personagem em 3D ao lado dos encaixes, com o que veste.** "No
  inventário, ao lado dos itens equipados, coloque o 3D do boneco com os itens equipados,
  igual nos jogos de RPG. Assim ele pode ver as alterações conforme vai equipando." Com a
  mochila aberta (I), à direita dos cinco encaixes fica o corpo do jogador em 3D, num palco
  próprio (`BonecoDaMochila`): a mesma cena, a mesma escala e os mesmos materiais, parado
  no idle. Ele aparece com o que está nos encaixes e na mão: o chapéu de palha na cabeça
  e, na mão, o machado da barra ou o facão das Mãos. Arrastar o mouse por cima dele gira o
  corpo, e soltar nele uma peça arrastada da mochila veste a peça no encaixe dela, como nos
  RPGs. O que o boneco mostra o jogador também mostra no vale, pelo mesmo caminho
  (`Vestimenta3D`): o chapéu e o facão passam a aparecer no corpo, como o machado já
  aparecia, e o machado continua com o mesmo encaixe na mão. O gibão e o patuá ainda não
  têm modelo, e nada aparece por eles. A mochila é tela do 2D e não se mexe nela: o boneco
  entra no alto da coluna dos efeitos, que ficam embaixo dele, e a largura dela não muda
  (numa coluna nova, ela passava da tela). Com o baú aberto, que é tela de transferir, o
  boneco sai e a mochila fica como era. Portão novo `tests/boneco_da_mochila.gd`, com
  oito perguntas, cada uma falsificada.

- **O tronco caído, a capelinha pobre, as peças das casas e o mestre Quirino chegam do
  Tripo.** "Crie um asset de tronco caído que pode coletar a madeira mediante uso do
  machado para cortar. Substitua as madeiras empilhadas na missão do cemitério por esse
  tronco caído", e "a capela próximo ao cemitério deve ser mais rudimentar, com um
  aspecto pobre". Lote de oito peças no Tripo Studio, 780 créditos: a geração (55), a
  retopologia Malha Smart (40) e, no mestre, o Auto Rig (20) com as sete animações dos
  moradores. Está registrado nos ORIGEM.md de cada pasta, no CREDITOS.md e em
  `tools/tripo/lote_2026-10-03b.json`. No cemitério do Damião, a lenha empilhada deu
  lugar a três troncos caídos (`tronco_caido`), cada um num giro (`"giro"`, novo em
  `data/recursos_3d.json`): saem no machado e rendem a mesma lenha, e o Damião fala dos
  troncos que a trovoada derrubou. A capelinha do cemitério é de taipa, com a cal
  rachada, a telha velha e a cruz tosca, no lugar da capela colonial reduzida. A casa do
  Pedro ganha a rede de pesca e os remos, e a da Dona Zefa, as ervas secando, o pilão e
  a gamela; o lugar de cada uma já estava pronto, e elas entraram sozinhas. O mestre
  Quirino deixa a caixa cinza: no píer, é o modelo dele, com os clipes de andar,
  cumprimentar e olhar em volta. O portão `saveiro` ganhou a pergunta do modelo.

- **O saveiro do mestre Quirino encosta no píer uma vez por estação, e a piaçava se tira
  no facão.** "Introduza uma missão de venda de piaçava 1x por mês para um NPC novo que
  chega ao porto." O mês do vale é a estação do calendário, de 28 dias: no dia 14, das 7h
  às 17h, o mestre Quirino — o morador novo, o mestre de saveiro que o Pedro diz ter
  trazido o jogador — fica de pé no tabuado do píer, com o saveiro atracado do lado; nos
  outros dias não há nem ele nem o barco (`SaveiroVale`, `data/saveiro.json`). Perto dele
  o painel (J) ganha a aba do saveiro: ele compra o que se produziu no mês — piaçava,
  farinha, mandioca, milho, cana, peixe, robalo, traíra, ostra e lenha — pagando mais que a
  venda, até o tanto que leva em cada viagem. Quem ensina é o Seu Benedito, que vende para
  o saveiro há quarenta e duas safras (`data/missoes_saveiro.json`, depois do tutorial do
  Pedro): empresta o facão, manda ao píer ver onde o saveiro atraca, pede dez feixes de
  piaçava e manda esperar o dia do mestre. Fora do dia a entrega espera, porque quem não
  está não recebe (`CadeiaDeMissoes._tentar_encontro`). Depois da cadeia, a encomenda de dez
  feixes volta toda estação no caderno, com um agrado para quem entrega tudo na mesma
  viagem; se o saveiro parte sem ela, ela sai do caderno sem entrar nas cumpridas
  (`CadernoDoVale.encerrar`). A piaçabeira da restinga dá dois feixes no fio da foice ou do
  facão e fica de pé; dá de novo na estação seguinte, e a dica não diz quando. Com a
  mochila cheia, nem fôlego se gasta. O mestre é uma caixa cinza provisória no estilo Tripo
  até o modelo dele chegar (peça procedural não entra no estilo, e o diário mostra o nome
  dele sem retrato), e a placa de nome olha o morador, e não só o rótulo: fora do dia, o
  nome dele não flutua sobre o píer vazio. O posto da tarde do Pedro, que ficava na água
  além da ponta do píer, voltou ao tabuado medido. Portão novo `tests/saveiro.gd`, com
  sete perguntas, falsificado seis vezes: o mestre escondido que recebe, o saveiro que vem
  todo dia, a fibra sem estação, a encomenda perdida que fica no caderno, a viagem sem teto
  e a placa que fica sem o dono. O `festa_da_fe` não cobra posto de quem não está no vale.

- **A casa do Pedro e a da Dona Zefa abrem por dentro, e as casas não são iguais.**
  "Produza o ambiente interno da casa de Pedro e Dona Zefa. Lembre de fazer algumas
  variações para todas as casas não serem iguais." O vale escolhe as duas entre as casas
  de taipa do arraial (`WorldBuilder.casas_dos_moradores`): a do Pedro é a mais perto do
  píer — ele mora "na praia, perto do píer" —, e a da Zefa, a vizinha da casa herdada.
  Cada cômodo tem o perfil de quem mora (`InteriorCasa.perfil`, o "o interior diz quem
  mora nela" do MORADORES.md): o Pedro, pescador, dorme de rede, tem o baú pequeno, o
  barril com o candeeiro em cima, o fogão e a barra azul de casa de beira de praia; a
  Zefa, que mora com o neto, tem a cama dela, a rede do Cosme, o oratório com a luz
  acesa, o barril, a mesa, a cantareira, os cestos que trança e a cal amarelada. A rede
  de pesca e os remos do Pedro, e as ervas secando, o pilão e a gamela da Zefa, entram
  sozinhos quando o lote do Tripo chegar ao catálogo. De noite o Pedro, a Zefa e o Cosme
  ficam na porta de casa (o Pedro ficava na venda, e a Zefa e o neto na porta da casa do
  jogador); o `Lugares` resolve `casa_do_pedro`, que era da Fase 7, e `casa_da_zefa`.
  Portão novo `tests/casas_dos_moradores.gd`, falsificado com todo cômodo no perfil da
  herdada.
- **Todo móvel dos cômodos é sólido na medida dele.** "Revise a área de colisão de todos
  os móveis." Na casa herdada só a cama e o baú tinham corpo, e com a medida escrita à
  mão — a cama do Tripo tem 1,30 de fundo, e a caixa, 0,95 —; a mesa, o banco, a
  cantareira, o fogão, o barril, o jirau e o oratório não tinham corpo nenhum, e o
  jogador passava por dentro deles. Na igreja, o banco tinha uma caixa de comprimento
  fixo e a pia de água benta, nenhuma. Agora todo móvel posto num cômodo tem a caixa das
  próprias malhas, no referencial do cômodo (`Comodo._colisao_da_peca`), e o pote e o
  cesto do chão também. Portão novo `tests/moveis.gd`: toda peça do catálogo no chão dos
  cômodos leva raios dos quatro lados, e cada um bate antes de entrar na caixa desenhada;
  com a regra antiga ele reprova na mesa, no banco, na cantareira, no fogão, no pote e na
  cama.
- **A canoa é sólida na medida do desenho.** "Pulei neles e atravessei a parede." A
  colisão das canoas eram caixas finas medidas como fração da caixa do modelo: o costado
  de colisão acabava meio metro abaixo da borda que se vê (a altura era 40% do modelo
  inteiro, com a proa alta), e a proa e a popa não tinham colisão. O pulo passava por cima
  do costado de colisão e através do desenhado. Agora a colisão é a própria malha do casco,
  dos dois lados (`Canoas._colisao_do_casco`): por fora é parede, por dentro é fundo e
  costado — no bote, o toldo e os postes também —, e o balanço passou ao passo de física,
  para quem está dentro andar com a canoa. Portão novo `tests/canoas.gd`: raios de fora e
  de dentro, na linha d'água e um palmo abaixo da borda desenhada, batem no casco de cada
  canoa, e quem pula nela fica dentro mesmo andando contra o costado. Com a colisão antiga
  ele reprova (o raio a 0,77 da água atravessa).
- **A árvore cortada cai.** "Produza a animação das árvores caindo ao cortá-las." No
  último golpe, a copa — a árvore de cima do corte — tomba do toco para longe de quem
  cortou: devagar no começo e depressa no fim, como árvore de verdade, dá um tranco no
  chão, fica um instante deitada e afunda na terra até sumir, uns quatro segundos e meio
  ao todo (`CoqueiroCortado.copa` e `derrubar`). A copa é a malha da própria árvore, sem
  recortar triângulo por triângulo — só os índices dos que ficam abaixo do corte saem —,
  para o golpe final não travar o quadro (57 ms numa mangueira); vale para as plantadas e
  para as da mata, da orla e da beira do rio. A embaúba nova do cemitério, que é alvo de
  trabalho, cai inteira, do pé (`"cai": true`). O portão `corte_das_arvores` confere que a
  copa está a caminho no meio do tombo, deita para o lado de longe de quem cortou e some
  sozinha; falsificado de três jeitos (sem lado para cair, sem tombo, a embaúba que some).
- **O baú se mexe com o mouse, a árvore cortada não diz quando volta, e a pitangueira
  cortada deixa toco, e não mesa.** O baú da casa abria a mochila direto, sem passar pelo
  dono das telas: o cursor seguia preso na câmera livre e o vale andava atrás da tela. Agora
  ele abre pela mesma porta da mochila (`TelasDoVale.abrir_por`), com o vale parado e o
  cursor solto para clicar e arrastar entre o baú e a mochila. A dica da árvore cortada
  deixou de contar os dias ("não informe no texto o tempo que o pé de árvore estará em pé
  novamente"): diz só que ela está crescendo de novo. E o toco: o corte nos 0,85 de sempre
  passava pela copa da pitangueira, que tem galho e folha abaixo disso, e em cima do tronco
  fino ficava um tampo de madeira de dois metros — uma mesa. O `CoqueiroCortado` passa a
  medir a árvore antes, de faixa em faixa de altura em volta do eixo do tronco (o coqueiro é
  inclinado), e corta logo abaixo de onde a copa abre; folha que desce até ali não entra no
  toco, e o corte à mostra tem a largura do tronco medido, e não a do catálogo. Os portões
  `casa` e `corte_das_arvores` ganharam as três perguntas, cada uma falsificada.
- **As árvores do vale se cortam e voltam em um ano; a madeira e a pedra duras pedem
  talento e aço.** "Pode tornar as árvores cortáveis, com respawn de 1 ano no calendário
  do jogo. Para isso ela tem que progredir até ficar 'adulta'." De machado na mão, toda
  árvore do vale se corta — as 42 plantadas e as 6.318 da mata, da orla e da beira do
  rio, cada uma agora com a instância dela registrada na MultiMesh —, com a regra que
  nasceu no coqueiro (#35): o corpo vai até o tronco, golpeia no tempo do braço, e cada
  golpe gasta vigor. O pé cortado vira toco (a malha da própria árvore, recortada) e
  cresce pelo calendário: muda com um quarto do ano, árvore nova com meio, crescida com
  três quartos — a malha dela mesma, menor, crescendo do pé e sem colisão —, e só com um
  ano (os 112 dias do `Relogio`) volta adulta, inteira, com colisão e cortável; a dica
  do machado diz quantos dias faltam. O coqueiro, que voltava em 24 horas, passa à regra
  do ano. A MADEIRA DIZ O QUE PEDE (`arvores_3d.json`): a branca (mangueira, cajueiro,
  coqueiro, dendê, embaúba…) cai no machado de ferro em 3 golpes e rende 2 de lenha; a de
  lei (jaqueira, jenipapeiro, os ipês, aroeira, mangue) pede o talento Braços de machado
  ou Ferro de Ogum e cai em 4, com 4 de lenha; a de lei dura (pau-brasil, sapucaia) pede
  também o machado de aço, e cai em 5, com 6. Cada golpe cobra fôlego (bater × dureza)
  e ensina (XP de bater, ou de bater_duro na madeira dura), como o tronco caído e o 2D:
  é por aí que o trabalho leva à teia que abre a árvore mais dura. A gameleira não se
  corta (é a árvore de Iroko), nem a bananeira (é erva grande, não dá lenha). NA PEDRA,
  o mesmo trato: a pedra dura, no mirante e na estrada da capela velha, pede o talento
  Mão de pedra ou Pedra de Xangô; o matacão pede também a picareta de aço. O machado e a
  picareta de aço entram no catálogo (da família do de ferro, grau 2) e na venda, e
  servem a tudo que pede machado ou picareta, na lida e na luta. As duas recusas não se
  parecem — o talento manda à teia, o aço manda à venda —, e os nomes dos talentos são
  lidos das teias (`Talentos.que_abrem`), para a recusa nunca prometer o que não existe.
  O corte cede a tecla ao alvo de trabalho, ao achado, ao marco, à lavoura e a quem está
  dentro de casa. O save guarda cada árvore cortada com o dia do corte (os saves do
  coqueiro contam o corte do dia da carga), e a carga de uma árvore que já passou do
  toco não recorta toco. Portão novo `tests/corte_das_arvores.gd`, falsificado de cinco
  jeitos (toda madeira branca, o ano de uma estação, a pedra sem pedido, o machado de
  aço que não conta como machado, a mata sem instância); o `folego.gd` passa a aceitar
  o golpe na árvore, com o portão dele.
- **Ninguém prende o jogador numa porta, e o Pedro para de seguir depois do tutorial.**
  "Ao entrar na casa para dormir, o Pedro me seguiu e bloqueou a porta. Não consigo mais
  sair de casa." O Pedro seguia o jogador a partida inteira e entrava junto nos cômodos;
  na casa herdada, de quatro por quatro, o lugar dele a quatro passos e meio era o vão da
  porta. Agora, durante o tutorial, ele não entra na casa: espera do lado de fora, de lado
  para a porta (`Comodo.lugar_de_esperar_fora`), e se já estava dentro, sai. E quem barra
  o caminho dá passagem: andando contra um morador, de frente, ele sai do caminho — de
  lado, se há lado; adiante, para fora do vão, se o lado é parede — e espera dois
  segundos e meio para o jogador passar (`MoradorNPC.dar_passagem`). Depois das nove
  missões do tutorial e da despedida, o Pedro volta à vida de pescador, nos postos dele
  (píer, praça, venda), e as missões do arraial abrem chegando perto dele; a despedida
  diz isso ("o Pedro volta pro píer, que é onde você o acha"). Portão novo
  `tests/passagem.gd`, falsificado de três jeitos — o Pedro entrando na casa, o jogador
  sem pedir passagem (a queixa, reproduzida: preso em casa) e o Pedro seguindo para sempre.
- **As capas dos cordéis: uma xilogravura para cada folheto.** As dez capas foram
  geradas no OpenAI `gpt-image-2` (qualidade média, US$ 0,41 as dez, com o custo
  mostrado antes) pelo `tools/openai/gerar-capas-cordeis.ps1`, cada uma com a cena do
  verso dela e nenhuma letra na imagem — o título quem imprime é o jogo. Conferidas uma
  a uma e promovidas pelo `tools/openai/promover_capas.gd` para JPG de 768x1152
  (`assets/prototipo_3d/cordeis/`, sem perda e com mipmaps); o folheto aberto e o
  pendurado no barbante passam a mostrar a capa de cada um, no lugar do bloco de
  sempre. A luz própria do folheto pendurado baixou, que desbotava a gravura.
- **A casa herdada mobiliada, e o terreiro e a gameleira completos: o lote do Tripo
  de 03/10/2026** (#26, #52). Doze peças geradas no Tripo Studio (Modelo HD H3.1 com a
  textura 8K desligada, 55 créditos; Retopologia Malha Smart, 40; GLB com textura 1K —
  1.140 créditos ao todo, preços lidos na interface antes de gastar), pela ponte do
  Playwright MCP com a extensão do Chrome e o `tools/tripo/lote_studio.js`. A casa
  troca as caixas cinza pela mobília do catálogo: a cama de cabeceira na parede da
  esquerda, o baú com a fechadura para a sala, a mesa sob a janela com o banco, a
  cantareira perto da porta, o fogão de barro e o barril no canto, o jirau de cuias na
  parede e o oratório aberto na parede da esquerda; a cama e a cantareira vieram de
  comprido no Z, e o catálogo as gira. O fogão estava de costas para a sala (giro de
  meia-volta) e agora mostra a boca do fogo. No terreiro, os dois mastros com pano branco
  ladeiam a entrada do lado da rua; na gameleira, o pano das fitas é amarrado no tronco
  liso, acima das sapopemas, na medida do tronco ali, tirada da própria malha. Os dois só
  no estilo Tripo, que o procedural não ganha peça nova. A rede fica para a obra de armar
  rede. Registro em `moveis/ORIGEM.md`, `aderecos/ORIGEM.md`, `assets/CREDITOS.md` e
  `tools/tripo/lote_2026-10-03.json`.
- **Os cordéis no estilo do vale: o folheto em alta, a capa de cada um e o barbante da
  feira.** O folheto veio do 2D desenhado em 640x360 e era ampliado duas vezes no vale,
  com a letra borrada; agora é medido na tela do vale (1280x720), nas letras da Crônica
  do Recôncavo — o título em Cinzel em cima da capa, o verso em Cormorant, a nota em
  Cormorant itálico —, e a capa de cada folheto é a xilogravura desenhada para ele
  (`assets/prototipo_3d/cordeis/<id>.png`) ou, enquanto ela não vem, o bloco de sempre
  (`capa_de_cordel.gd`). No vale o cordel deixou de ser o papel claro no chão: pende
  num barbante entre dois mourões, como na feira, a cavalo na corda, com a capa para
  fora e balançando no vento; os mourões e a corda são peça provisória, cinza como a
  bancada da oficina, até o catálogo ter a corda de cordel, e o giro deles é o primeiro
  em que não entram em coisa sólida — no cemitério ele fica entre duas covas. O do
  mirante estava no meio da caixa de colisão do mirante, onde ninguém chegava, e foi
  para o pé dele; o da capela velha ficava a três palmos do lugar da reza de lá, e o
  marco, que recebe o E primeiro, não o deixava ser pego — foi para o lado da porta. As capas desenhadas são geração paga: `tools/openai/gerar-capas-cordeis.ps1`
  mostra o plano e o custo estimado (`-Estimar`) antes de gastar, e as cenas de cada
  folheto moram em `tools/openai/capas_cordeis.json`, sem letra na imagem — o título
  quem imprime é o jogo (`tests/folheto.gd` e `tests/achados_no_vale.gd`, falsificados
  de sete jeitos).
- **O cemitério do Damião: mais mato, o conserto das lajes, o cercado e a capelinha de
  costas para o mar.** A missão do cemitério tinha quatro pés de capim e acabava no
  corte. Agora são oito, e depois deles vem o mato que levanta laje — quatro embaúbas
  novas entre as covas e três galhadas da trovoada, contadas juntas pelo grupo
  `mato_do_cemiterio` (`Recursos3D` conta o que caiu por peça ou por grupo). Em
  seguida o Damião pede quatro pedras para o calço e duas tábuas para as cruzes: três
  lajes começam tortas, levantadas pela raiz, e endireitam na entrega. Por fim, o
  cercado, que é obra do J (`cemiterio_cercado`: seis de lenha e duas cordas, plano
  aprendido com o passo): pau roliço em volta das covas, com a entrada onde a rua do
  cemitério chega e colisão em cada lance; de pé, a malha dos moradores se assa de novo
  (`navegacao_vale.reassar`) e o Damião sai pela entrada. A lenha do mato e as pedras
  soltas do outeiro, que se catam à mão, cobrem o conserto e o cercado — 17 de lenha e
  6 de pedra para 16 e 4, conferidos pelas receitas da oficina, porque o vale tem
  pouca lenha fora dali. A reza católica do cemitério saiu do meio das covas para
  diante da capelinha: a capela do catálogo, pequena e no alicerce das casas, na beira
  do outeiro do lado do mar e de costas para ele — quem reza olha a porta e, por cima
  do telhado, a baía; dali o E é o da reza, sem lápide nem capim ao alcance. As lajes e
  o cercado não têm save próprio: leem a fila do Damião e o `Obras`, para os dois lados
  (`cemiterio_vale.gd`). Os passos novos e o arremate nascem nos três idiomas, e a
  missão entrou no `tests/idiomas.gd` com a pendência dos três passos do 2D declarada
  passo a passo (`tests/cadeia_do_coveiro.gd`, seis passos, falsificado de sete jeitos).
- **Os moradores andam pelo caminho de verdade: a malha de navegação.** Eles iam em
  linha reta até o posto, com um desvio local quando batiam — "decisão local não vê o
  mapa inteiro" —, e com a festa de cada fé o caminho ficou longo. Agora o vale assa uma
  malha de navegação da área por onde os moradores andam, ao montar, numa linha de
  execução à parte (uns 50 ms para ler o vale e 1,7 s para assar, 7.000 polígonos), e
  o morador segue o caminho dela: contorna casa, cerca, cômodo e tronco da mata, e entra
  na igreja pela porta. Entram o chão, o que tem colisão — com os cômodos, a porta e as
  rampas — e os troncos da mata como obstáculo, tirados da lista da mata (a colisão
  deles só acompanha o jogador). Saem o fundo do mar, que tem colisão para o corpo
  andar no raso, e os telhados e tampos que a malha punha como ilhas sem saída. Até a
  malha ficar pronta, anda-se reto, como antes; e o caminho da festa, longe dos olhos
  do jogador, continua se encurtando (`tests/navegacao.gd`, falsificado: sem os
  troncos, sem os cômodos e com o morador ignorando a malha).
- **A fazenda da casa: a lavoura na frente dela, com a regra do roçado do 2D** (#8).
  O roçado tinha a casa no meio e nenhum lugar de plantar. Agora há uma lavoura de
  quatro fileiras de seis leitos no chão aberto na frente da casa, depois da cana e da
  lenha, e o gesto é o do 2D: o que está na mão decide — a enxada ara, o balde molha, a
  semente planta e gasta uma, a mão livre colhe o que está no ponto —, e cada gesto que
  não cabe diz por quê ("Chão bruto. A enxada abre o leito."). A regra veio inteira
  (`plantacao.gd`): só cresce o que foi regado, todo leito amanhece seco, a qualidade
  da colheita vem do cuidado, a cana rebrota, as fruteiras passam a carência, e o
  inverno para a roça. O dia que vira — a cama, a queda, o desmaio das duas — faz
  crescer. As plantas são peças que o catálogo já tinha: o capim é o broto, o canteiro
  de mandioca é a mandioca crescida, a cana é a cana, e as fruteiras são as árvores da
  vila, pequenas. No campo a tecla é da lavoura: os pés de cana da beira calam. O baú da
  casa traz o que o finado deixou para a roça no 2D — o balde e a maniva; a enxada vem
  do Pedro. A lavoura vai no save (`tests/lavoura.gd`, falsificado de cinco jeitos).
- **A casa herdada abre por dentro, e a cama vira o dia** (#50, #26). A barreira era o
  dia que não virava: o vale não tinha cama, e o calendário só andava quando o jogador
  caía. Agora a casa de taipa do roçado tem cômodo no lugar dela — chão de terra batida,
  cal com a barra de barro, telha-vã, a janela da fachada —, com a cama e o baú no fundo.
  A cama pergunta como no 2D ("Dormir até o amanhecer?"), e o sim vira um dia pelo
  caminho da queda: escurece, mostra o cartão do amanhecer, acorda às 6h ao pé da cama,
  descansado, e salva. Quem não deita até as duas da manhã desmaia de cansaço, como no
  2D (a decisão da #50), e acorda ao pé da cama com as falas de lá; a queda também
  acorda ali. O baú da casa abre a mochila com ele do lado, com os dois beijus da
  partida nova, e vai no save. Numa casa de três por quatro a câmera de passeio não
  cabia — o braço batia na parede e ela ia parar dentro da cabeça do jogador —; lá
  dentro ela sobe e olha de cima, com o telhado e o forro só fazendo sombra. O que os
  dois cômodos têm em comum saiu da igreja para `comodo.gd`. Até os móveis do Tripo
  chegarem, a cama e o baú são caixas provisórias, como a #50 manda. De quebra: o
  canteiro de mandioca, que morava no meio do roçado e aparecia no meio da sala, foi
  para a beira da lavoura nova, na frente da casa; o posto da manhã do Cosme, que caía
  dentro da casa, foi para a lavoura; e o E dos alvos de trabalho não atravessa parede
  (`tests/casa.gd` e `casa_procedural.gd`, falsificados; `tests/calendario.gd` passa a
  cobrir a cama).
- **No dia da festa de cada fé, quem é dela vai ao marco à tarde** (#52). O calendário
  já sabia as três festas — o Bom Jesus dos Navegantes, Cosme e Damião e o Dois de
  Julho —, mas ninguém saía do posto de sempre. Agora, no dia da festa, da uma da tarde
  até a meia-noite, quem é da fé vai para a roda no marco maior dela, como no 2D: os
  quatro católicos em volta do cruzeiro, a Dona Zefa e o Cosme dos lados do fogo do
  terreiro, o Tonho em cima do monte da gameleira, cada um no seu lugar. Quem está à
  vista do jogador sai andando; longe dos olhos dele, o morador chega pelo caminho de
  sempre, porque o terreiro e a gameleira ficam longe da vila e o morador anda sem
  mapa. A volta, à meia-noite, é igual (`tests/festa_da_fe.gd`, falsificado).
- **O portão do alcance dos alvos deixa de depender da carga da máquina** (#37). Ele
  punha o corpo encostado em cada alvo e esperava dois quadros: na encosta do mirante o
  corpo escorregava, e quanto escorregava dependia de quantos passos de física cabiam
  ali — na bateria cheia o jogo oferecia a `erva_mirante_d` encostado em outro alvo, e
  sozinho não. Agora a pergunta é de conta, sem física, dos quatro lados de cada alvo,
  e o segundo alvo mais perto tem de ficar meia unidade além (o corpo escorrega até
  0,41): par de alvos que disputa o E reprova sempre, e não às vezes
  (`tests/alcance_dos_alvos.gd`, falsificado com um alvo intruso).
- **O J vira diário, como no Witcher, e o HUD segue a missão acompanhada.** Escolher
  uma missão no J mudava só a cor da linha: o HUD e a seta seguiam a última cadeia que
  falou, e o foco do caderno era uma posição na lista, que andava sozinha quando outra
  missão abria ou fechava. Agora o caderno acompanha pelo id; o J mostra a lista
  agrupada à esquerda e, à direita, o nome da missão, quem a deu, a fala inteira, os
  objetivos cumpridos riscados, o de agora com a barra e o botão ACOMPANHAR (E, ou o
  segundo clique). O canto da tela mostra o nome da missão acompanhada em cima do
  objetivo; o passo seguinte herda o acompanhamento, e missão nova de outra pessoa só
  avisa. Cada cadeia ganhou `nome` nos três idiomas (`tests/painel.gd`, falsificado).
- **Os retratos do arraial são fotos do modelo 3D.** Um estúdio (`retratos_3d.gd`)
  instancia o mesmo modelo de cada morador, no estilo escolhido, põe o clipe "idle",
  mira a cabeça de três quartos com luz de estúdio num mundo próprio e guarda a foto. A
  teia social (lista e página) e o diário (o rosto de quem deu a missão) usam a foto; o
  desenho 2D fica de reserva até ela sair, e sem placa de vídeo (`tests/teia_social.gd`).
- **As missões da fé, do 2D para os marcos do vale** (#52). Com o mirante consertado, o
  Pedro passa o recado da Dona Zefa ("mandou te chamar"); ela, quando o jogador chega,
  fala das três fés e manda ver os três lugares — o cruzeiro, o terreiro e a gameleira.
  Chegar perto de cada um risca a conta e o mundo conta o que se vê dali; voltando a
  ela, ela conta como é (uma fé por vez, a antiga congela, levar o acumulado custa
  quase tudo) e só então os marcos aceitam alguém. Escolher no marco fecha o passo,
  paga e rende XP de fé, e a fé escolhida dá a missão própria, na voz do mundo: a
  romaria da católica (os quatro marcos da igreja, o altar lá dentro), a mesa da folha
  do candomblé (três ervas, dois peixes e duas canas ao terreiro — a farinha do 2D espera
  a casa de farinha, #27) e pagar o monte do caboclo (seis ostras à gameleira). A missão de uma fé congela quando o jogador muda
  para outra e volta a correr se ele voltar. As ostras se catam à mão nas pedras da
  maré, perto das pedras da ponta da praia, e o mirante e o roçado ganharam três moitas e
  dois pés de cana: alvo não renasce, e a Dona Zefa e a Candinha levavam quase tudo. Recompensas do 2D; textos nos três idiomas
  (`tests/cadeia_da_fe.gd`, falsificado). A cadeia ganhou duas metas: `visitar`
  (riscar lugares de uma lista) e `oferendar` (levar a um lugar, e não a uma pessoa).
- **A fé chega ao chão do vale: os seis marcos, o rito e a teia da fé no K** (#52). As
  três fés já estavam no vale (os autoloads `Fe`, `Ritos` e `Afinidade` do 2D),
  sem lugar onde acontecer. Agora há seis marcos: o cruzeiro diante da igreja, o
  ALTAR da igreja do Bom Jesus (por dentro da nave), a capela velha da rua do
  mirante, o cemitério, e dois que o vale não tinha — o terreiro, na mata a poente da
  rua do mirante, atrás de uma linha de árvores (casa de taipa caiada, potes de barro e
  o fogo, aceso à noite), e a gameleira do sambaqui, na ponta da praia perto das pedras
  (a árvore maior que a mata, em cima de um monte de concha, com potes entre as
  raízes). Só peças do catálogo, nos dois estilos; por código só o chão (o terreiro e
  o monte de concha). Os mastros com pano branco e as fitas do 2D esperam peça do
  Tripo, que é geração paga. Perto de um marco, o E: no da sua fé,
  o rito (fôlego, XP de fé e bênção, uma vez a cada sete dias — fora do prazo o marco
  diz o dia em que a graça volta); no de outra, a troca, em duas perguntas, com o
  preço de levar o acumulado (85%) e o social ditos antes do sim; sem fé, a entrada —
  depois que a Dona Zefa mostrar as três. O Tab do K troca para a teia da fé, com a
  página "Regras da fé": a fé de agora e as congeladas, a espera de cada marco, a
  bênção, a festa e o preço de trocar. Falas nos três idiomas
  (`data/marcos_fe.json`; `tests/fe_no_vale.gd`, falsificado).
- **O relógio pode ser mexido, com aviso, confirmação e registro no save.** "Parada"
  voltou à passagem do tempo do AJUSTAR, e "Pausar o relógio no jogo" (Permitido, de
  fábrica, ou Bloqueado) voltou a ser opção. Parar o tempo — pela linha Relógio do
  Esc ou pelo "Parada" — e adiantar a hora (T) perguntam antes, na primeira vez da
  partida, numa caixa que fala das conquistas; o "não" não mexe em nada. Toda mudança
  vai para o registro do relógio, que o save guarda com o dia e a hora do jogo, junto
  com o relógio que o jogador deixou parado (carregar não o religa). Bloqueado, a
  linha do Esc não para e diz por quê; religar sempre se pode. Partida que começa em
  "Parada" já começa marcada. A caixa de pergunta virou uma só para o menu, o HUD e o
  AJUSTAR (`tests/relogio.gd`, `menu_pausa.gd` e `salvamento.gd`, falsificados).
- **A igreja do Bom Jesus abre por dentro, o primeiro cômodo do vale** (#26). O cômodo
  mora dentro da própria igreja, no lugar dela: entra-se andando pela porta, sem
  escurecer, e o Pedro entra junto. Ao montar o vale, raios medem a casca do modelo por
  dentro, e a nave cabe nela: caiada, com a barra de azulejo azul, chão de lajota, forro
  de tábua com as vigas, janelas que acompanham o dia, o presbitério com os degraus e a
  grade de comunhão, o altar com o frontal vermelho e o retábulo dourado com a cruz no
  nicho. Os móveis são peças que o catálogo já tinha (banco, candeeiro, cruzeiro,
  pote), no estilo escolhido; nenhuma peça foi gerada. A caixa de colisão inteira da
  igreja sai, e o cômodo põe paredes, o vão da porta e rampas onde o degrau travaria o
  pé (a quina do alicerce de pedra prendia o corpo no adro). Por fora, a porta pintada
  vira um vão escuro; por dentro, ele mostra o adro. A câmera fica do lado da porta em
  que o jogador está, e a luz de dentro não vaza pela parede. Lá dentro, o mato e as
  aves abafam e o HUD diz onde se está. No procedural, a porta atravessa a torre. A
  bússola, o mapa e o save leem o jogador onde ele está (`tests/interiores.gd` e
  `interiores_procedural.gd`, falsificados).
- **O mirante, as missões do arraial do Pedro depois do tutorial, e a recompensa de
  missão** (#48). Vieram do 2D (`arraial.json`): aperte P e veja quem é quem, suba ao
  mirante, junte 20 tábuas, 12 pedras e 6 cordas e conserte-o no J, aba de obras — com
  o mirante do Tripo de pé, o estrago é o tabuado que range e o guarda-corpo podre. A
  cadeia só abre com o tutorial terminado (`depois_de`). Metas novas: `evento` (o P
  avisa as cadeias), `obra` e `juntar` de vários itens. Todo passo pode ter
  `recompensa` (itens e réis), paga uma vez quando ele fecha, dita no HUD e escrita ao
  lado do objetivo riscado no diário: as cadeias que já estavam no vale ganharam os
  números do 2D (800 réis do cemitério, as garapas da Candinha, as cocadas e os
  pirões do Tonho e da Zefa), e o mirante paga os 1200 réis da vaquinha e o pirão do
  Pedro. De quebra: a planta que um passo ensina ("abre": {"missao": ...}) nunca era
  aprendida no 3D, porque só o `Missoes` do 2D avisava o `Receitas`; agora a cadeia
  avisa, e o mirante pode ser levantado (`tests/cadeia_do_mirante.gd`, falsificado;
  `tests/ferramentas.gd` cobra as sete cadeias). O canteiro espera o roçado (#27); a
  fé, a luta e a capoeira têm issue própria (#52, #53).

## Build #8 — 03/10/2026

- A tela Sobre apresenta a equipe atual do projeto: Ramon Santos, Renato Leal
  e Matheus Ché (#40).
- Fecha a **Build #8** para Windows com os créditos atuais e o histórico
  do jogo em português, inglês e espanhol. O download estável do site
  passa a entregar esta versão (#40).

## Em desenvolvimento — 01/10/2026

- A oficina provisória ganha âncora na beira do roçado: depois do loteamento,
  a casa ocupava o mesmo centro e escondia a oficina no painel. Os portões
  de obras e ofício reproduziram o defeito e conferem a fabricação (#11).
- O vale passa a abrir na raiz de um repositório próprio, com histórico
  exclusivo da linha 3D, sistemas locais e testes sem checkout do 2D.
- Abertura e controles contam falhas e saem com código; a medição de alcance
  reinicia a referência de terra firme ao teleportar o jogador.
- Modelos e áudio WAV passam a usar Git LFS. O FBX antigo fica apenas no
  histórico; caches, sincronizadores e ferramentas descontinuadas saem.

Este histórico acompanha apenas o jogo 3D, hoje na raiz deste repositório.
A linha anterior usava a branch `prototype/myths-valley-3d`. O projeto 2D foi a base da derivação, mas
suas fases, versões e novidades não são entradas deste registro. Os marcos
abaixo seguem o que mudou no 3D. A identificação atual é **v0.1.0-dev · Build #8**,
exclusiva desta derivação e publicada para download em mythsvalley.app.br/jogar.

O texto clicável de versão e build no rodapé da abertura mostra resumos destes
marcos. Os textos curtos e a identificação exibidos no jogo ficam em
`data/historico_3d.json`; ao registrar um novo marco ou build,
atualize esse arquivo e este documento juntos.

## Build #7 — 03/10/2026

- **O jogo se atualiza pelo site** (#74). Ao abrir o menu, o executável pergunta a
  `https://mythsvalley.app.br/api/jogo/atualizacao` pela build mais nova; havendo uma, a
  linha embaixo da versão, no rodapé do retábulo, oferece a atualização. Aceita, o jogo
  baixa o zip para `user://atualizacao/`, confere o SHA-256 do manifesto, extrai ao lado
  do executável, guarda o atual como `.old`, põe o novo no lugar e pede para reiniciar;
  na abertura seguinte, o `.old` e as sobras somem. Só instala sozinho numa build
  exportada no Windows com a pasta gravável — fora disso, a oferta abre a página de
  download. Sem rede, fica quieto. Portão: `tests/atualizacao.gd`.
- Fecha a **Build #7**, a primeira publicada para download, com o que entrou desde a #6:
  o sobrevoo que contorna, o vale em cinco segundos, a tela de carregamento quieta, as
  seis cadeias de missão e o E que não age atrás de tela.

## Em desenvolvimento — 02/10/2026

- **O sobrevoo do menu contorna árvores e casas pelos lados, sem subir** (#34). A elipse
  do píer à praça atravessava copas e telhados em 30% do ciclo. O trajeto agora é
  planejado offline contra os triângulos reais dos dois estilos
  (`tools/prototipo_3d/sobrevoo/`), gravado em `data/sobrevoo_menu.json` e voado a
  14,6–17,4 m do chão, com folga de 5 m e guinada e aceleração no nível do voo antigo.
  A câmera para de arrastar atrás do trajeto (o atraso cortava as curvas por dentro).
  Portões: `tests/sobrevoo_livre.gd` e `tests/sobrevoo_livre_procedural.gd`.
- **O vale monta em ~5 s em vez de ~29 s**, no menu e no jogo. O sorteio da mata, as
  ruas, a praia, os lotes e os troncos mediam cada ponto contra todos os segmentos de
  rua, rio e costa e contra todos os troncos; com grades de células a resposta é a
  mesma, bit a bit (montagem inteira comparada), e o carregamento até o menu caiu de
  ~34 s para ~7 s (headless).
- **A tela de carregamento fica sem as bolinhas e sem som.** As partículas saem das
  quatro telas, e a música e o ambiente do menu só começam quando o menu aparece.
- **O machado volta para a barra de mão.** Ele morava só na reserva da mochila e se usava
  encaixando em "Mãos"; o número da barra não o alcançava. Agora entra num dos dez, a
  tecla o põe na mão e no braço, e partida salva com ele na reserva o vê subir para a
  barra. O encaixe continua valendo (`tests/barra_de_mao.gd`).
- **O relógio do menu do Esc diz a escolha do jogador, e parar avisa.** A linha lia o
  relógio que o próprio menu tinha parado e dizia sempre "parado"; e vinha trancada por
  "Pausar o relógio no jogo: Bloqueado". O relógio corre por padrão; parar abre uma
  caixa de confirmação que avisa que a partida perde as conquistas dali em diante, e
  a marca (`relogio_alterado`) vai no save. "Parada" sai da Passagem do tempo e a opção
  de tranca sai do AJUSTAR: a linha do menu é a única porta para parar o tempo.
- **Controles vira tela, e o menu do Esc não trava mais o vale.** As linhas que fechavam
  o menu (Voltar ao vale, Mapa, Ajustes, saídas) o fechavam por fora do dono das telas, e
  a árvore ficava pausada; fechar os Ajustes ainda estourava num ícone que saiu com a
  coluna do canto. Controles abre uma tela com os atalhos — clica-se na tecla e
  aperta-se a nova, com troca entre ações — e as teclas fixas; o Esc nela volta ao menu
  (`tests/menu_pausa.gd`).
- **O botão de FPS mostra o número.** Levava o ícone de estilo, que no procedural é
  "{}" (`tests/hud_desempenho.gd`).
- **O Pedro não repete a chegada no píer depois de uma carga.** O "já saudei" do
  morador não ia no save, e continuar a vaga ou trocar o estilo o fazia dizer "Opa! É
  você o moço da capital?" no meio da partida. Com a cadeia dele começada, a saudação
  se cala (`tests/salvamento.gd`).
- **Cada ferramenta só trabalha no que é dela.** Os alvos de trabalho (capim, troncos,
  lajedos) conferiam a ferramenta na mochila: com o machado na mão e a foice guardada, o
  capim se cortava com o machado. Agora a ferramenta do alvo tem de estar na mão — a
  recusa diz qual pôr —, como a vara na pesca e o machado no coqueiro já pediam; e quem
  entrega ferramenta numa missão a põe na mão (`tests/ferramentas.gd`).
- **A tela do arraial (P) é desenhada, e o texto vira apoio.** Cada morador na lista tem
  retrato, os corações do grau e os selos de conversa e presente de hoje; a página tem o
  retrato grande, a fileira de corações, a barra até o próximo grau com a conta, os
  selos de hoje, a grade de presentes (selo de gosta ou não aceita, e quantos o jogador
  tem) e a régua de quanto rende cada gesto. O gosto continua fechado até "Gente boa",
  mas aparece como vagas com cadeado. O retrato cortava dois bonecos empilhados — o
  quadro da folha é quadrado, pela largura (`tests/teia_social.gd`).
- **O objetivo do HUD é um resumo, e a fala inteira fica no painel (J).** Cada passo
  ganhou `resumo` nos três idiomas ("Vá até a capela", "Corte o capim com a foice"); os
  de meta sem resumo o geram da meta, e a conta anda junto ("(2/4)"). O caderno guarda a
  fala de quem pediu, e o J a mostra na missão sob o cursor
  (`tests/cadeia_das_missoes.gd`, `tests/idiomas.gd`).

## Em desenvolvimento — 30/09 e 01/10/2026

- **O sobrevoo do menu olha adiante, do píer à praça** (#34). A câmera acompanha o relevo a 16 metros do chão, na altura das copas e telhados, e segue a direção do movimento com inclinação leve. O percurso curvo retorna por outro lado da vila, sem recuar com o olhar preso no piso. O ciclo contínuo dura 72 segundos e usa as âncoras reais (`tests/sobrevoo_menu.gd`). Ao abrir o mapa, o voo pausa; ao fechar, a câmera retoma o quadro anterior diretamente, sem descer da altura do mapa. A poeira dourada e os vaga-lumes sobrepostos ao menu saem. O foco do voo fica no terço direito, livre do painel, com ajuste para a proporção da janela.

- **O E não age com o corpo parado nem atrás de tela.** No escuro da queda, o E batia no
  tronco ou no coqueiro ao lado da porta, lia lápide e comia o que estava na mão. Atrás de
  tela aberta, a barra de mão ainda ouvia: o número trocava a mão por baixo do painel J,
  do almanaque, da teia, do arraial e do menu, e com o arraial (P) aberto o E comia.
  Recursos, árvores, lápides e a mão perguntam agora pelo corpo, como achados, pesca e
  luta já faziam, e a barra não ouve com o vale parado (`tests/barra_de_mao.gd`).
- **Seis cadeias de missão, e o vale com mecanismo próprio** (#7). O 3D deixou de ler o
  checklist do `Missoes` do 2D: quem guarda missão aberta agora é o `CadernoDoVale`, por
  decisão do autor — missão nova aqui pode ter padrão, formato e ordem diferentes, e o 2D
  é referência, não dono. A fila virou peça reusável (`CadeiaDeMissoes`), pendurada em
  cada morador, lendo `data/missoes_<dono>.json`. Atravessaram, com portão cada: o
  coveiro (3 passos), a Dona Filó (2), a Dona Zefa (4 — as ervas da serra vêm antes do
  Cosme, que é a ordem do 2D), o Tonho (5 — a rede paga o armazém e a dívida paga solta a
  terra, também a ordem de lá) e a Dona Candinha (2). O vale ganhou pé de cana no roçado
  e moita de erva no mirante para as metas caberem nele.
- **Metas novas, cada uma de uma missão que não caberia nas anteriores.** `falar`
  (encontro sem carga: "fale com o Cosme"), e `levar` com CONTA — por item. As seis canas
  da Candinha e as cinco cordas mais três tábuas do Tonho não fechavam: a entrega levava
  um só, e chegar com uma cana fechava a missão das seis. O objetivo no caderno diz
  quantas faltam de cada.
- **O portão das ferramentas cobra que TODA missão seja cumprível**, varrendo os seis
  arquivos: meta de tipo que a cadeia sabe fazer, material que sai de alvo posto ou da
  bancada com receita nascida sabida, e morador procurado que mora aqui. Ele nasceu de um
  defeito que a versão estreita deixou passar — o `coveiro_cabo` pedia duas achas de
  lenha e não entregava machado.
- **O machado virou item de encaixe** (merge de `4812cad`) e isso quebrou a promessa das
  missões: bater passou a exigir a ferramenta ENCAIXADA, e "toma o machado e vai cortar"
  entregava na mochila. Quem entrega agora encaixa — inclusive o que o jogador já
  carrega, porque o vale dá um machado de saída e o passo desistia por achá-lo lá.
- **`Inventario.quantidade("")` matava.** Espaço livre é `{}`, e `get("id", "")` devolve
  "" nele: a conta de "" casava com cada espaço vazio e morria no `qtd` que ele não tem.
  Quem chegava lá era o trabalho — alvo cuja ficha não nomeia ferramenta pergunta por "".
  Consertado idêntico nas duas cópias, para a bifurcação dos compartilhados não crescer.
- **Carregar uma partida não refaz a fala.** O restauro punha `espera` de volta, e espera
  que vence FALA: quem salvasse no primeiro passo do Pedro ouvia a abertura do jogo de
  novo, como se a partida tivesse recomeçado. Agora há `CadeiaDeMissoes.retomar` — o
  caderno e o marcador voltam, a fala não. O `tests/salvamento.gd` escuta o Pedro por
  2,6 s depois de continuar a vaga, e cobra a outra metade: que o objetivo voltou mesmo
  assim, senão calá-lo passaria deixando o jogador sem rumo.
- **A lista de missões parou de explodir na tela.** O caderno usava o `texto` do passo
  como título, e `texto` é a FALA — um parágrafo; `Button` pede a largura do que carrega,
  e a caixa de 900 ia a **1828 px numa tela de 1280**. Os 25 passos ganharam `titulo`
  curto (o do 2D, onde havia), as linhas do painel cortam no fim, e há corte de reserva
  para missão que nasça sem o campo. O portão do painel media a aba quase vazia; agora
  planta um título maior que qualquer fala do vale.
- **Os ícones do menu do Esc saíram de cima do texto.** O ícone ocupa de 14 a 40 dentro do
  botão e a margem do texto era 14 em todas as linhas — o comentário do desenho já dizia
  que o texto recuava, faltava recuar.
- **A árvore de talentos ganhou os ícones do 2D** (39 PNG), por decisão do autor enquanto
  não houver arte própria; `res://` aqui é a pasta do protótipo e não enxerga a do 2D.
  Talento travado fica apagado como o nome dele.
- **A teia social ganhou o que faltava do 2D**: o retrato de cada morador, que é o mesmo
  boneco do mapa recortado no primeiro quadro da folha; a barra do grau com aro, que
  antes tinha 4 px e passava batida; e os presentes EM DESENHO — os mesmos ícones da
  mochila, que é onde o jogador vai procurá-los, com o nome escrito embaixo. O gosto
  continua escondido até "Gente boa", que é a régua de lá.
- **O minimapa virou bússola redonda e aponta a missão em foco** (máscara de shader na
  vista, aro fechando o círculo, 176 quadrado). O losango do alvo existia, mas seguia o
  último passo ANUNCIADO: com várias cadeias abertas apontava para quem tinha acabado de
  falar, e não para o que o jogador fixou no painel. Agora lê o `CadernoDoVale.atual()`.
  A máscara mudou uma conta: alvo fora da vista era preso no retângulo, e num canto cai
  no pedaço que o shader apaga — o limite virou redondo. **O minimapa nunca tinha
  portão**, e é por isso que o alvo errado durou; tem agora, com sete perguntas.
- **O teto de tempo da bateria virou por portão.** O `agua_rasa` atravessa o braço de mar
  a pé, e o vigor novo deixou a travessia mais lenta: o orçamento dele é de 14000 + 16000
  quadros de física, perto de 500 s de relógio, e ele TRAVAVA no teto geral de 420 s sem
  medir nada. Cortar o orçamento faria o portão dizer "não dá pé" quando o que falta é
  distância.

### Antes, no mesmo ciclo

- **Fala longa com Sim e Não** (#21, a caixa e o pacto). O que precisa ser lido antes de
  seguir abre numa caixa no rodapé, a do 2D, e o vale para atrás dela como atrás de tela.
  E ou Esc passam a linha; na pergunta, A é Sim, D é Não, E confirma, e o E sem escolha
  não responde. A primeira pergunta é a do pacto: pegar a carta abre a prosa dela, o
  preço e o "Firmar?", no lugar do segundo E provisório. O balão continua para o
  cumprimento de passagem (`dialogo_vale.gd`, `data/dialogo.json`, `tests/escolha.gd`).
  De passagem: as telas do 2D soltavam o calendário ao fechar, e com o relógio pausado ele
  andava sozinho; pausar e retomar o vale agora o prendem.
- **O cordel no papel** (#21, o folheto). Achar um cordel abre o folheto do 2D, inteiro,
  por cima do vale; E, Esc ou um clique o guardam, e a tecla de outra tela troca para ela.
  No almanaque, escolher de novo o cordel aberto o relê no papel, e guardar volta ao
  almanaque onde ele estava (`scripts/ui/folheto.gd`, idêntico ao do 2D; `tests/folheto.gd`).
- **O amanhecer** (#21, fecha a issue). Quem cai vê no escuro o cartão do dia novo, o do
  2D: dia, estação, fôlego e o que está marcado — o dia da fazenda ou a festa da fé —, e
  o E pula a espera. Ao clarear, a fala de quem caiu vem na caixa de fala, e não mais no
  aviso do HUD (`scripts/ui/amanhecer.gd`, idêntico ao do 2D; `tests/amanhecer.gd`). De
  passagem: com o vale andando atrás do cartão, o Esc abria o menu e o E que pula a
  espera batia na árvore ao lado da porta; agora o cartão para o vale, como no 2D. E o E
  que guarda o papel comia o que estava na mão — no Godot 4 a barra ouve a tecla antes
  dessas telas.
- **Mochila no vale** (#2). A tela do 2D abre no I por cima do HUD e no tamanho da
  janela, com o teclado de dentro dela funcionando: setas ou WASD escolhem, F veste ou
  come, E arruma. A roda do mouse troca o item da mão, como no 2D; o zoom foi para
  Ctrl+roda e +/- (`tests/mochila.gd`).
- **Teclas das telas** (#4). A mochila entrou na tabela de atalhos e no AJUSTAR, como J,
  K, L e P; W/A/S/D, que andam, saíram da troca. A ajuda do HUD e o painel J leem a
  tabela, e o `COMO_JOGAR_3D.md` voltou a dizer as teclas de hoje (`tests/atalhos.gd`).
- **Pesca, cozinha e oficina** (#11). Com a vara na mão e a água à frente, E lança; a
  bóia afunda e acende o "!" na fisgada, e o E ferra. A água decide o peixe: traíra no
  rio, robalo no mar. O fogo do terreiro da Casa de taipa cozinha os pratos sabidos, e a
  bancada provisória da oficina, na beira do roçado, serra tábua e torce corda
  (`pesca_vale.gd`, `bancadas_vale.gd`, `tests/oficio.gd`).
- **Obras no vale** (#15, com efeito e sem arte). A aba de obras do painel aparece perto
  da casa, do armazém, do mirante, do poço e do píer; o plano vem antes do material, e a
  obra feita paga o ganho no corpo e fica no save. A casa ainda não muda por fora nem
  por dentro (#26, #27). De passagem: o `Receitas` subia antes do `Obras` e nenhum plano
  de obra "de começo" nascia sabido; e o `executar` compartilhado não paga o ganho da
  obra, que o vale paga até o 2D consertar (`bancadas_vale.gd`, `tests/obras.gd`).
- **A tela de coleção avulsa saiu.** O almanaque (L) mostra cordéis, sinais e bichos
  com as mesmas fichas, e a tela própria da coleção tinha ficado sem tecla, mostrando um
  pedaço do que ele mostra (`colecao_vale.gd` e `tests/colecao.gd` apagados).

## Em desenvolvimento — 29/09/2026

- **Vida no vale** (#10). Barra de vida no HUD, logo abaixo do relógio, com as cores
  do 2D: vermelha, e verde-musgo enquanto a peçonha corre. **Cair é noite no chão**,
  como no 2D: a tela escurece, o jogador acorda na porta da Casa de taipa às 6h do
  dia seguinte, com a vida cheia e o fôlego do desmaio, e o aviso conta o que houve
  (`queda.gd`, `data/queda.json`). A regra é o `Vida` compartilhado, sem uma linha
  mudada; o que o vale acrescentou é o gatilho, a barra e o portão `tests/vida.gd`.
  Nada no vale tira vida ainda — isso chega com a luta (#14).
- **Fôlego no HUD** (#3). Barra de fôlego logo abaixo da vida, na mesma medida e com
  as cores do 2D: verde, e vermelha quando o corpo está no fim — e aí o número vem
  com "cansado", porque o passo já caía para 62% e a corrida parava sem aviso. O
  número e o limiar são do `Energia` compartilhado; o `tests/folego.gd` confere a
  barra.
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
- **Painel J** (#19). Missões, cartas e, no balcão da Venda do Bar, a venda — comprar
  e vender com o preço que muda com a estação; o botão JOGO abre salvar, voltar ao menu
  (com segunda confirmação) e sair. Tab troca de aba, W/S escolhem, E confirma, Esc ou J
  fecham. Com o painel aberto o relógio e o jogador param, a peçonha espera e o bicho
  não caça. Oficina, obras e cozinha aparecem quando o vale tiver o lugar delas
  (`painel_vale.gd`, `bancadas_vale.gd`, `tests/painel.gd`).
- **Coleção L** (parte da #20). Cordéis, sinais e bichos, com a vaga em branco de quem
  falta achar; o bicho derrubado na luta abre a página dele com a conta de quantos
  caíram. Os dados de coleção do 2D vieram para o protótipo, conferidos byte a byte com o
  original (`colecao_vale.gd`, `data/colecionaveis/`, `tests/colecao.gd`).
- **Cordéis, sinais e cartas no vale** (#12). Seis cordéis no lugar do arraial que cada
  um descreve; o sinal da Caipora na mata fechada, e as cartas dela só depois do sinal;
  o pacto firmado com o segundo E no lugar do mito (ou no painel), com o ganho no corpo
  e a cobrança de todo dia. Os dados das cartas vieram do 2D, conferidos com os de
  coleção num portão só (`achados_vale.gd`, `tests/cartas.gd`, `tests/dados_do_2d.gd`).

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
- **A identidade vira o padrão do sistema (home "Retábulo")**: o menu inteiro passa
  para a "Crônica do Recôncavo". O painel da home e todos os modais (AJUSTAR, SOBRE,
  Histórico, PERSONAGENS, mapa) ganham a moldura de talha dourada com fio de azulejo
  (NinePatch novo, gerado da identidade); o título vira o logotipo pintado, com halo,
  a linha "Bom Jesus dos Pobres · 1887" entre filetes, o lema e o divisor de azulejo;
  os botões viram placas em Cinzel com canto chanfrado, e as rosas dos ventos giram
  nas pontas do item em foco (o mouse em cima já traz o foco: um marcador só).
- **O vale ganha a luz de pintura da tela de carregamento**: véus no topo, na base e
  atrás do retábulo (mais fortes contra o céu claro, seguindo a hora), vinheta, poeira
  dourada de dia e vaga-lumes à noite, e o almanaque no canto — fatos de dia, "dizem
  no vale" à noite, trocando a cada 10 s. Um fio de ouro discreto vive na base.
- **A travessia do JOGAR virou cinema**: faixas pretas, capítulo entre losangos,
  legenda em Cormorant centrada na base sobre o vale e o fio de ouro medindo cada
  fala. CONTINUAR e PULAR em versalete, sem caixa.
- **Fontes do sistema**: a opção "Fonte do menu" ganha a "Crônica" (Cormorant no corpo,
  Cinzel nas ações) como padrão; Padrão, Almendra e Miva continuam. Os botões do canto
  (menu e HUD), as dicas, os cabeçalhos dos modais e a confirmação de "Voltar ao menu?"
  do jogo seguem a mesma identidade. Peças compartilhadas em `identidade.gd`.
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
  de caminhada em vez de ~890 m (`f8ce2c4`).
- Ruas ganharam textura de terra batida com sulcos de carro de boi, aplicada ao
  longo do percurso; a Praça, chão de terra pisoteada com seixos. As duas
  texturas são procedurais e regeráveis por script (`d468f07`).
- `flora_reconcavo.gd` traz espécies procedurais com silhueta própria
  (mangueira, jaqueira, cajueiro, dendezeiro, coqueiro, bananeira, ipê amarelo e
  roxo, embaúba, mata alta) e as peças soltas do 2D (poço, cruzeiro, carroça,
  varal, pilha de lenha, pote, cerca, banco). A mata usa uma MultiMesh por
  espécie; coqueiros inclinados acompanham a orla (`5ec25e5`).
- Mangueira, jaqueira, cajueiro, coqueiro, capela colonial e poço de pedra foram
  gerados no Tripo Studio e reduzidos por `tools/modelos/reduzir_glb.py`,
  substituindo os procedurais perto dos pontos de interesse (`15341fe`).
- `JOGAR_3D.cmd` passou a existir só em `raiz do projeto 3D`; o histórico e o mapa de
  planejamento foram movidos para `docs/` e `tools/mapas/` (`e8a1ca7`).

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
  (`a97a1a6`).
- A casa de Carro Quebrado entrou no cenário com escala e colisão ajustadas
  (`0bedefa`).
- O pau-brasil e a referência para novos modelos ampliaram a paisagem
  (`ac3b431`).

## 23/09/2026 — Primeiro passeio jogável

- O projeto 3D independente ganhou vila explorável, personagem, câmera em
  terceira pessoa, colisões e HUD (`46f044c`).
- O personagem passou a usar animações de repouso, caminhada, corrida e gestos
  acionáveis no jogo (`65ed61d`).
- As primeiras decisões de escopo e a base técnica foram registradas em
  documentos específicos do protótipo (`55598da`, `9c10474`).


## 07/10/2026: livro de fiado do Tonho (#68)

O livro usa o baú efetivamente montado no perfil da venda, com E a 1,7 u e
foco compartilhado. Pergunta antes de lançar até 500 réis, limitados pelo
dinheiro do jogador e pelo saldo. Sem dinheiro explica venda/espera; conta
quitada orienta voltar ao pontal. Dívida inicial 1900, abatimento de 130 por
dia somente depois da entrega real da rede; quinze dias quitam a conta.
Saldo, rede, leitura e dia do último abatimento vão no save do vale.
A etapa do livro exige leitura E quitação; chegar à venda ou ler não pode
liberar a fala Zerou. Valores conferidos no 2D SHA62c0f14b, Terrenos/Mundo.
Interface PT/EN/ES; a prosa autoral da cadeia conserva pendência #6.
Portões fiado_tonho (limites, 14/15 dias, JSON, trava de missão) e
livro_no_armazem (móvel real, foco E, Sim/Não e save completo), idiomas,
missoes e salvamento. Mutante sem abatimento deve reprovar a conta.
Captura scratch/fiado-tonho/pergunta.png e logs em D:/MythsValleyPlaytestRuns.

### 07/10/2026: foco durante a fala longa (#140, #132)

A caixa longa reserva seu retângulo real, incluindo a transformação da camada e as escalas individuais. Componentes do HUD que o intersectam ficam transparentes durante a conversa; sua visibilidade original continua pertencendo ao dono do aviso, sem ressuscitar notificações expiradas. Missão e medidores fora da caixa permanecem. Plaquinhas do mundo cedem ao abrir a fala e voltam ao terminar.

O tutorial do corpo declara `interfaces` em cada linha de `missoes_guia.json`. `Dialogo.falar` aceita essa lista paralela como quarto argumento opcional; a linha atual destaca somente o componente declarado, no retângulo renderizado. Perguntas e fechamento limpam esse foco. Nenhuma dedução depende de palavras da prosa regional.

Portão `foco_da_narracao`: reserva, componente externo preservado, troca de foco, restauração da cor e aviso expirado. A falsificação `--sem-reserva` reprova uma asserção. `interface_individual`, `prioridade_dos_avisos` e `idiomas` acompanham. Captura real no armazém: `scratch/fiado-tonho/tutorial-foco.png`; a pergunta/pagamento do livro continuam com zero falhas. A #140 permanece aberta pelos componentes secundários ainda pendentes.

### 07/10/2026: catálogo antes dos autoloads (#17)

A inspeção do cemitério encontrou erro de compilação em `estacoes_vale.gd` quando um script pré-carregava o catálogo. O registro de materiais passa a consultar a estação guardada por `aplicar`, sem depender de um identificador de autoload na compilação. Assim, modelos carregados depois recebem a estação vigente e repetir o registro preserva a cor original.

`estacao_no_catalogo` pré-carrega o catálogo e confere registro tardio e cor sem deriva. A falsificação `--estacao-inicial` reprova. Regressões: `estacoes_do_vale`, `lapides_no_chao` e `lapides_no_chao_procedural`. O sucesso textual do antigo gate não foi aceito enquanto havia SCRIPT ERROR no log.

### 07/10/2026: verificação das sepulturas (#123)

O layout de `cemiterio_layout.gd`, já presente na main integrada, satisfaz a revisão: doze sepulturas preservam a ordem das histórias, cabeceiras para o mesmo lado, intervalos de passagem, corredor diante da capelinha e bases assentadas pelo terreno dos cantos. O portão consulta também a malha física real, a cápsula nos corredores e as reservas de moradores/recursos. As três lajes levantadas pela raiz continuam sendo trabalho intencional da missão do Damião, não defeito de colocação.

`lapides_no_chao` (47 s) e `lapides_no_chao_procedural` (37 s) verdes. Nova falsificação `--cabeca-invertida` reprova a associação/orientação da primeira sepultura. Capturas reais no Tripo em `scratch/cemiterio123/visao-{0,1,2}.png`, entrada, proximidade e corredor da capela, conferidas visualmente. O log da repetição não contém SCRIPT ERROR. A arte específica da cerca permanece na #111; a #123 pode ser encerrada sem substituir o modelo existente.

### 07/10/2026: controles, apoios, mapa e molduras (#140)

As preferências individuais passam de 18 a 23 componentes: atalhos do canto,
mapa, controles, cartas de apoio e ajuda. Os botões do canto respeitam a altura
útil da janela, mesmo combinando escala global de HUD e individual a 150%.
O mapa transforma os marcadores e o rótulo do viajante sem alterar o zoom do mundo.
Moldura e sombra agora acompanham a posição, o pivô e a escala real da caixa;
antes, a caixa encolhia e sua moldura permanecia com o tamanho original.
Reabrir as cartas atualiza também título, instrução e botão no idioma corrente.

`interfaces_secundarias` confere três resoluções e três idiomas, texto global
ampliado, ancoragem, moldura e clique real no último atalho. Verde em 3 s;
`--sem-escala` reprova duas verificações sem erro de script. Regressões
`interface_individual`, `apoios_no_vale`, `atalhos` e `idiomas` verdes;
o catálogo contém 775 campos em 45 arquivos. Capturas gráficas em
`scratch/interfaces-secundarias/`: controles a 65% e apoios a 150%.
A #140 continua aberta para a revisão das demais telas e combinações globais.

### 07/10/2026: cercas e rotas livres (#125, #142)

As cercas do paisagismo têm corpo correspondente ao desenho e entram na
malha; Candinha percorre a rota até Zefa. Os contornos respeitam esquinas,
reservas e entradas, com apoio no relevo e cinco vistas reais conferidas.
As últimas travadas na igreja e no corrimão central foram resolvidas sem
retirar colisões nem criar exceções. Corrimãos entram como obstáculos
proporcionais ao GLB, preservando o tabuleiro e as juntas.

`colisoes_de_passeio` 87 s, `navegacao` 57 s e `rota_da_fazenda` 61 s verdes.
`travessia_da_ponte_central` percorre rotas e ambas as cabeceiras; o mutante
sem obstáculos reproduz a travada no corrimão. Detalhes e evidências em
`docs/testes/CERCAS_E_CIRCULACAO.md`. Encerrar #125 e #142; a bateria completa
exigida pela #99 continua pendente.
