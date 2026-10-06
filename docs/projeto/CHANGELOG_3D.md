# Histórico de mudanças — Myths' Valley 3D

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

## Em desenvolvimento — 06/10/2026

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
