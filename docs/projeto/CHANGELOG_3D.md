# Histórico de mudanças — Myths' Valley 3D

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

## Em desenvolvimento — 04/10/2026

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
