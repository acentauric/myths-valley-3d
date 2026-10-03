# Histórico de mudanças — Myths' Valley 3D

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
abaixo seguem o que mudou no 3D. A identificação atual é **v0.1.0-dev · Build #5**,
exclusiva desta derivação e ainda sem distribuição publicada.

O texto clicável de versão e build no rodapé da abertura mostra resumos destes
marcos. Os textos curtos e a identificação exibidos no jogo ficam em
`data/historico_3d.json`; ao registrar um novo marco ou build,
atualize esse arquivo e este documento juntos.

## Em desenvolvimento — 03/10/2026

- **O J vira diário, como no Witcher, e o HUD segue a missão acompanhada.** Escolher
  uma missão no J mudava só a cor da linha: o HUD e a seta seguiam a última cadeia que
  falou, e o foco do caderno era uma posição na lista, que andava sozinha quando outra
  missão abria ou fechava. Agora o caderno acompanha pelo id; o J mostra a lista
  agrupada à esquerda e, à direita, o nome da missão, quem a deu, a fala inteira, os
  objetivos cumpridos riscados, o de agora com a barra e o botão ACOMPANHAR (E, ou o
  segundo clique). O canto da tela mostra o nome da missão acompanhada em cima do
  objetivo; o passo seguinte herda o acompanhamento, e missão nova de outra pessoa só
  avisa. Cada cadeia ganhou `nome` nos três idiomas (`tests/painel.gd`, falsificado).

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
