# Ambientação e direção artística

**Onde e quando:** Bom Jesus dos Pobres, Recôncavo Baiano, Bahia, Nordeste do
Brasil, por volta de **1887**. Um vilarejo pequeno entre riachos, à beira da
Baía de Todos os Santos e cercado de Mata Atlântica.

Este documento é o contrato visual do projeto. Todo asset novo — gerado por IA
ou desenhado à mão — passa por ele antes de entrar. O objetivo não é
reconstituição de museu: é que quem é do Recôncavo reconheça o lugar.

---

## 1. O momento histórico

1887 é uma data escolhida, não decorativa. É a **véspera imediata da Abolição**:

- A Lei do Ventre Livre é de 1871; a Lei dos Sexagenários é de 1885; a
  Abolição final virá em **1888**. O país vive o ápice da crise escravocrata e
  a véspera do fim legal da escravidão, mas ela **ainda não chegou lá**. No
  capítulo 7 as mulheres da fazenda dizem exatamente isso: estão presas há
  muitos anos e "não havia respeito às ações de libertação da escravatura
  daquela época". O isolamento do interior do Recôncavo permitia que senhores
  mantivessem cativos mesmo com leis de libertação já vigentes.
- O açúcar do Recôncavo já perdeu para as Antilhas e para o Sudeste. Engenho
  quebrado, casa-grande caindo, senhor ausente. **A decadência é o clima.**
- Quilombos existem, são conhecidos e são destino real de fuga — é para um
  deles que as mulheres vão no fim do capítulo 7.

### 1.1 Bom Jesus dos Pobres em 1887: vila antiga, não cidade

Bom Jesus dos Pobres **não era cidade** (município autônomo) em 1887 — nem mesmo
hoje tem esse estatuto, sendo distrito de Saubara (que só se emancipou de Santo
Amaro em 1989). Mas como **povoado, arraial e vila de pescadores**, o lugar já
contava com **mais de 230 anos de história**:

- **Fundação no século XVII (1652):** A Capela do Senhor Bom Jesus dos Pobres
  foi erguida em **25 de fevereiro de 1652** pelo Padre Francisco de Araújo, em
  terras da antiga Fazenda Saubara doadas à Santa Casa de Misericórdia de
  Salvador em 1650. Em 1887, a igreja de pedra e cal e o cemitério na encosta já
  eram marcos seculares cravados na paisagem.
- **Trincheira na Guerra de Independência (1822–1823):** Sessenta anos antes da
  época do jogo, a ponta e as praias de Bom Jesus serviram de ponto militar
  estratégico: trincheiras e baterias de canhões foram montadas na areia para
  vigiar a entrada da Baía de Todos os Santos e impedir que navios da esquadra
  portuguesa subissem o Rio Paraguaçu rumo a Cachoeira.
- **Vida comunitária e isolamento:** Subordinado administrativamente à distante
  Santo Amaro, o arraial vivia por sua própria conta e ritmo: mariscagem, pesca
  artesanal de canoa e saveiro, roçados de mandioca nas meias-encostas e casas
  de farinha comunitárias, convivendo com a decadência dos engenhos vizinhos.

Por isso, a documentação e os diálogos usam com rigor os termos **arraial**,
**vilarejo**, **povoado** ou **vila de pescadores**. Chamar o lugar de "cidade"
seria anacrônico.

**O que isso manda na arte:** nada de opulência colonial em bom estado. Cal
descascando, telha fora do lugar, mato tomando o pátio. O que é novo e bem
cuidado é a casa pobre de quem trabalha, não o casarão.

**O que o jogo não faz:** escravidão não vira mecânica, recurso ou número. Ela
aparece como o que é — gente presa que precisa ser libertada — e na narrativa
principal, não em sistema de jogo. Personagem negro não é cenário nem vítima
decorativa: as mulheres do capítulo 7 conduzem a revelação e a decisão final.

---

## 2. Geografia

### 2.1 A planta do mapa: Bom Jesus dos Pobres

O mapa do jogo segue a planta de **Bom Jesus dos Pobres**, vila de pescadores
do Recôncavo (Saubara, BA), mapeada a partir de imagens de satélite e referências
geográficas reais. **A referência é uma foto aérea anotada à mão pelo autor**,
guardada em `docs/imagens/mapa-referencia-bom-jesus.png` — mar embaixo, serra em
cima, e em vermelho as ruas, a praça, o píer, a igreja, o bar, o restaurante de
beira-mar, o cemitério, a casa e o mirante; em azul, o riacho e o rio grande.
Toda mudança de planta se confere contra ela antes de decidir onde fica o quê.
O que a vila real tem, o mapa tem, no mesmo arranjo:

| Na vila real | No mapa |
|--------------|---------|
| Mar ao sul, serra de mata ao norte | Faixa de mar e praia no sul; serra fechada no leste, no oeste e no FUNDO, lá em cima. **Não é ilha.** A serra que se vê da vila é a CRISTA, e atrás dela há mata em que se entra (ver abaixo) |
| A serra acima da vila é mata, não parede: a foto é verde da vila para cima | A MATA, uma faixa de 48 fileiras atrás da crista, em fileiras NEGATIVAS (`TOPO`): o mapa cresceu para o norte sem andar a origem, e nenhuma coordenada da vila mudou. Tem a grota da nascente (taquaral e samambaia, sem bicho) e a mata virgem (madeira de lei e caititu) |
| A estrada do mirante não acaba nele: vira trilha de terra, serra acima; e da casa sai uma estrada comprida para o nordeste, mata adentro | As três PICADAS que furam a crista, cada uma saindo de uma rua: a do mirante (x≈48), a da nascente (x=98, pelo monjolo e pela cachoeira) e a da lenha (x≈126, entre o cemitério e o roçado). Lá em cima, a picada da serra as liga de oeste a leste até a pinguela do rio grande |
| Ir à fazenda a pé, pela mata: "outros até mesmo foram andando pelas trilhas por meio da mata atlântica bem densa (...) nas passagens quase virgens" (capítulo 6) | O CAMINHO DA FAZENDA: da pinguela (`PINGUELA`, onde o rio aperta), pela mata de lá, descendo a crista a leste da cerca até o portão. Na crista ele é PASSAGEM QUASE VIRGEM (`PASSAGEM_QUASE_VIRGEM_Y`): pau de lei atravessado, que só cai com machado de lei — é o que impede a pinguela de ser atalho para o dendê antes da ponte |
| A serra da onça | O PENEDO DA ONÇA (`ALTOS_DA_MATA`), morro de pedra na mata de lá, com a TOCA no alto e a rampa ao sul |
| Estrada da praia atravessando a vila | Estrada em `ESTRADA_Y`, de ponta a ponta |
| Ruas em QUADRA, não uma fita: uma rua por dentro passando em frente da casa e do cemitério, travessas descendo até a beira | A rua de cima em `RUA_DE_CIMA_Y` (fileiras 76–77, da estrada do mirante à casa de farinha), a `PONTE_DE_CIMA` sobre o riacho, e as travessas da igreja (x=102) e da casa de farinha (x=125) — com o caminho do roçado (x=115) no meio, são as três ruas da foto a leste da igreja |
| Praça um pouco para dentro | `PRACA`, com cruzeiro, mural, poço, ficus e bancos |
| Riacho que desce do norte, pelo meio da vila, até o mar | Nasce na `NASCENTE`, um poço raso lá na mata; atravessa a crista, cai na cachoeira e desce de `RIACHO_TOPO` a `RIACHO_FOZ`, com ponte de prancha na estrada e outra na rua de cima |
| Igreja na BEIRA, a leste do riacho e do píer — na areia, do lado do mar | `capela` em `CASARIO`, em (93,100). Esteve dezessete fileiras terra adentro até setembro de 2026, e de lá não se via água da porta dela |
| Cemitério ao norte da estrada, **entre a igreja e a casa** | `outeiro_do_cemiterio` em `ALTOS`, a leste do riacho. Foi para cá quando o mapa cresceu 34 células para leste: a foto o quer perto da casa, e o jogador já tinha pedido distância do roçado — com o mapa maior cabem os dois |
| O miolo denso de casas a OESTE da praça | `casa_oeste_a/b/c`, no vão entre a gameleira e a casa dos avós |
| Bar a leste da igreja; restaurante de beira-mar a oeste da praça, do lado do mar | `bar` e `casa_de_pasto` — em 1887, casa de pasto: prato do dia por réis, pedido no fogão (`Mundo._comer_na_casa_de_pasto`) |
| Píer mar adentro | `PIER` |
| Cemitério subindo a encosta | `cemiterio` |
| Mirante no alto, por estrada que serpenteia | `mirante`, com a estrada em `_tracar_estradas` |
| A casa (do jogador), para dentro, a nordeste da igreja | `ROCADO` |
| Rio grande fechando o leste, vindo do nordeste | `RIO_X`, com a única ponte na estrada — e a fazenda do outro lado. Vem do fundo do mapa, e lá em cima, na mata, só se passa pela pinguela |
| Lagoa onde o rio abre antes de seguir para o mar | `LAGOA_CENTRO`, colada na divisa leste do Seu Benedito. É ela que dá sentido à fala dele: "terra com água aceita quase tudo" |

O desnível é, por enquanto, **faixa**: o fundo (barra e fecha o mapa), a mata
(onde se entra), a crista (barra, e só as picadas a furam), a encosta (mata
rala e pedra, mais barranco e cachoeira) e a baixada. Não há altura de verdade
no motor; há o que se vê e o que barra.

O Recôncavo é a terra que **abraça a Baía de Todos os Santos**. Três faixas, e
o mapa do jogo usa as três:

| Faixa | O que é | No mapa |
|-------|---------|---------|
| Beira de rio / maré | Mangue, barro, canoa, peixe e marisco | O rio que corta o mapa de norte a sul, o vau e a cabana de pesca; na maré, o píer, o **trapiche** e o **tanque de lavar** na margem do riacho |
| Meia encosta | Roçado de mandioca, casa de taipa, mata de galho fino | O roçado do jogador (com o **galinheiro** no quintal), o vilarejo (com o **forno de barro** no terreiro) e a trilha |
| Tabuleiro alto / interior | Mata densa, pastagem rala, ruína de fazenda e engenho abandonado | A fazenda isolada do capítulo 6, a nordeste; a **capela de estrada** marca a passagem para lá. E a **mata** atrás da crista, subindo pelas picadas |

O relevo é de **colina baixa e molhada**, não de sertão. Verde o ano todo, com
duas estações que importam mais que as quatro do calendário: **chuva**
(outono/inverno, de abril a agosto) e **estiagem** (primavera/verão). O jogo usa
quatro estações por convenção do gênero, mas a paleta tem que puxar para esse
par: verde encharcado contra ocre seco.

### 2.2 O que faz um arraial, e não só um cenário

A planta acima diz onde as coisas ficam. Esta lista diz por que elas existem, e
é a pergunta que abriu a fase 5 da `PERSPECTIVA.md`: *o que a vida de arraial
que esta documentação descreve não tinha peça nenhuma para representar?*

| Peça | O que ela resolve |
|------|-------------------|
| Tanque de lavar | Lavar roupa era serviço de mulher e era **ponto de encontro**. O riacho cortava a vila inteira sem uma pedra de bater roupa |
| Forno de barro | A casa de farinha é de **mandioca** — rala, prensa e torra. Pão é outro forno, e o do arraial é de todos: é ele que faz a vila ter cozinha coletiva em vez de casas soltas |
| Trapiche | O cais, o píer e a canoa existiam; a carga que chega e sai não tinha onde dormir. Trapiche é o armazém de beira d'água do Recôncavo |
| Galinheiro | Criar galinha já era mecânica de jogo, e a arte disso era uma cerca. O bicho não tinha casa |
| Capela de estrada | O cruzeiro da praça estava sozinho. Capelinha de beira de estrada é o que marca caminho em terra católica, e é onde quem passa para sem entrar em igreja nenhuma |
| Terreiro | O arraial rezava em mais de um lugar, e o mapa só tinha os católicos. Fica na mata, com vereda de um tile: em 1887 terreiro que se via da estrada era terreiro que a polícia fechava |
| Gameleira do sambaqui | O monte de concha que gente daqui empilhou antes de existir arraial, igreja ou engenho. É o marco mais antigo do mapa, e não foi ninguém do jogo que o levantou |

Nenhuma delas fica onde sobrou espaço: cada uma está na faixa a que pertence, e
com **terreiro** — o chão em volta batido, porque chão pisado todo dia não cria
grama. Peça sem terreiro e sem caminho até ela vira miniatura no gramado.

Os três marcos de fé — cruzeiro, terreiro e gameleira — ficam nos três cantos
do mapa de propósito, e a geografia deles é a lição: ver [FE.md](FE.md).

---

## 3. Arquitetura

Quatro tipos, e só. Misturar estilos é o erro mais fácil de cometer aqui.

### 3.1 Casa de taipa (a do jogador, a do vilarejo)
Parede de barro sobre trama de madeira, **caiada de branco**. Telha colonial de
barro (capa e canal), curva, vermelho-alaranjada e desbotada. Porta e janela de
madeira escura com **folha cega** (sem vidro — vidro é coisa de cidade e de
rico). Alicerce baixo de pedra. Chão de terra batida ou tábua corrida. Beiral
curto, sem calha.

Tamanho: **uma a três águas**, um ou dois cômodos. A casa do jogador começa
assim e cresce (ver §6).

### 3.2 Sobrado / casa de vila melhorada
Dois pavimentos, sacada de ferro fundido, **azulejo português azul e branco na
fachada** (marca de Salvador e do Recôncavo rico). É o terceiro nível de
melhoria da casa do jogador — e já é ostentação para o lugar.

### 3.3 Casa-grande da fazenda
Fachada longa e baixa, muitas janelas altas e escuras, escadaria de pedra na
frente, pintura descascando. **Abandonada por dentro mesmo quando há gente.** No
capítulo 6 Pedro repara que portas e janelas "não estavam intactas" e que a
guarita da entrada não tem porta nem janela há muito tempo. O portão de ferro é
**baixo**, de um metro — o texto diz isso e a arte respeita.

Junto dela: senzala em ruína, capela pequena com torre de sino, ruína de
palacete queimado (é onde o capítulo 7 termina).

### 3.4 Construção de trabalho
Casa de farinha (galpão aberto dos lados, telhado de barro, forno redondo de
torrar), engenho (roda d'água, tacho de cobre), monjolo, curral de vara, cabana
de pesca em palafita sobre o barranco.

### Não use
Enxaimel europeu, pedra aparelhada de castelo, telhado de duas águas muito
inclinado, chaminé de tijolo, madeira escura tipo cabana do norte, janela com
vidro em casa pobre.

---

## 4. Flora

A Mata Atlântica do Recôncavo, não a Amazônia e não o cerrado.

**Árvores:** mangueira (a rainha — copa larguíssima e escura, sombra de
terreiro), jaqueira, cajueiro, dendezeiro (o dendê é do Recôncavo, veio com os
africanos), coqueiro, ipê amarelo e roxo na florada, pau-brasil, embaúba de
tronco branco.

**Cultivo:** mandioca (a base absoluta da subsistência e das casas de farinha
do arraial — é o que o jogador planta e colhe), além de banana, milho, feijão,
quiabo e touceiras de cana de quintal (para garapa e consumo doméstico). O
canavial extensivo nunca fez parte de Bom Jesus dos Pobres: historicamente, as
terras da antiga Fazenda Saubara da Santa Casa eram a grande fonte de farinha de
mesa para Salvador, enquanto os latifúndios de cana e engenhos ficavam no
interior de massapê (Santo Amaro).

**Baixo:** bambuzal, capim sapé alto e seco, samambaia, bromélia, maria-sem-
vergonha rosa e branca, cupinzeiro vermelho, trepadeira em tudo que fica parado.

**Regra de leitura:** a mata do Recôncavo é **fechada e alta**, não é bosque
ralo. Árvore no jogo ocupa mais de um tile e transborda para cima — o jogador
passa por trás da copa. Isso é direção artística, não só técnica: a sensação de
mata é a de não enxergar longe.

**Orla:** coqueiral quase contínuo na beira da praia, manguezal no leito dos rios
e nas fozes, pedras na areia e lajes no raso. As regras de posição, e onde
editá-las no Godot, estão em [BIOMA_DA_ORLA.md](BIOMA_DA_ORLA.md).

---

## 5. Fauna

Doméstica: bode e cabra soltos no terreiro (o capítulo 6 diz que andavam pelo
meio das pessoas), galinha, boi de carro, cavalo de charrete, cachorro magro.

Do lugar: saíra e sanhaço, bem-te-vi, garça na beira do rio, siri e caranguejo
no mangue, lagartixa, sagui.

Da mata, e de morder: o **caititu**, em bando, na mata do dendê, na pedreira e
na mata virgem; a **onça pintada**, uma só, no penedo da mata de lá do rio; e a
**jararaca**, nos dois brejos, de tocaia no mato alto. Onça faz toca em lapa de
morro de pedra, e não em buraco no chão — é por isso que a dela fica em cima de
um penedo. A jararaca é a cobra que mais mordia gente no Recôncavo, e a peçonha
dela é o que fica depois: o remédio de benzedeira era chá de folha, e a banha
da própria cobra vendia como remédio de junta. E a **coruja rasga-mortalha** (*Tyto furcata*) —
que não é bicho: é a Matinta Pereira do capítulo 7, e só aparece quando a
história manda.

---

## 6. Construção e melhoria

A casa e as outras construções **não seguem uma escada linear**. O jogador
escolhe o que melhorar, e as escolhas não são todas compatíveis — ver
[CONSTRUCAO.md](CONSTRUCAO.md) para o sistema. Do lado da arte, o que importa:

- **Casca externa** tem três estágios (taipa de um cômodo → casa com varanda →
  sobrado azulejado). Cada um é uma peça inteira de arte.
- **Interior** é montado por partes: parede interna, mobília, piso. Trocar
  mobília não muda a casca; levantar parede não muda a mobília.
- Melhoria de construção de NPC (a casa do Pedro, a venda, o moinho, a cabana
  de pesca) usa o mesmo vocabulário visual. Uma oficina melhorada continua
  sendo taipa caiada — ela ganha telheiro, bancada, ferramenta pendurada.

---

## 7. Paleta

A referência é **hora dourada no fim da tarde**, que é também a paleta do
Batalha de Mitos (capítulo 73 do site).

| Uso | Cor | Onde |
|-----|-----|------|
| Cal | `#F2EAD8` | parede de casa |
| Telha | `#A8442F` | telhado |
| Barro batido | `#8A6A44` | caminho, terreiro |
| Verde mata | `#3E6B34` | copa |
| Verde novo | `#7FA64B` | roçado, brotação |
| Ocre seco | `#C8A052` | capim, estiagem |
| Azul de maré | `#3E7B8C` | rio |
| Azul-marinho | `#22304A` | roupa, azulejo, noite |
| Vinho | `#6E2233` | roupa de festa, detalhe |
| Latão | `#C8922E` | lampião, interface |

**Não use** neon, ciano puro, roxo saturado nem verde-limão. Mito e sobrenatural
entram com **azul-safira luminoso** (é a cor do escudo e da lança do capítulo 7)
— e só eles.

---

## 8. Como pedir arte nova

O `tools/pixellab/gerar-reconcavo.ps1` carrega este parágrafo em toda chamada:

> rural Bahia Brazil 1887, Reconcavo Baiano, colonial portuguese countryside,
> tropical atlantic forest, warm golden hour light, muted ochre earth tones,
> pixel art, single color black outline, low detail, readable at small size

Regras práticas:

1. **`map-objects` cobra uma geração de qualquer tamanho** — é o endpoint certo
   para cenário e construção.
2. Tamanho mínimo aceito: **32×32**.
3. Peça sempre com o **pé no centro de baixo** da imagem: é assim que o tile de
   32×48 encaixa no chão e transborda para cima.
4. Arquivo que já existe é pulado. **Nada é apagado**: as peças antigas ficam
   em `assets/sprites/gerados/` como catálogo, para reaproveitar em vez de
   gerar de novo. Ver [assets/CREDITOS.md](../../assets/CREDITOS.md).
5. **Não use negação no prompt.** Pedir "sem arcos, sem colunas" fez a ruína do
   palacete voltar um rabisco sem forma. Descreva o que é, não o que não é: a
   versão que funcionou pedia "paredes quebradas em alturas diferentes, buracos
   escuros de janela, mato crescendo por dentro".
6. **Letra sai errada.** O gerador escreveu "Dental" na placa da venda. Peça
   placa em branco e ponha o texto no jogo, não na textura.
7. O worker derruba job de vez em quando **sem cobrar**. O
   `gerar-reconcavo.ps1` tenta três vezes antes de desistir.

---

## 9. Fontes
 
- Capítulos 6 e 7 do universo de Batalha de Mitos ([docs/enredo/](../enredo/)) —
  a fonte primária da narrativa.
- Referências visuais do capítulo 73 em www.batalhademitos.com.br.
- Arquitetura e paisagem do Recôncavo: Cachoeira, São Félix, Santo Amaro,
  Maragogipe.
 
 Este documento é a diretriz de trabalho visual canônica do projeto.
