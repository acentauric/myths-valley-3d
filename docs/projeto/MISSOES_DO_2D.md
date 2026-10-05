# As missões do jogo 2D, em ordem, para a migração

Levantamento de todas as missões do Myths' Valley 2D: o que cada uma pede, o
que a abre, o que a fecha, quem paga e se ela já existe no 3D. Serve de base
para trazer ao 3D o que falta sem ter de abrir o projeto 2D.

**Fonte:** o checkout `Mitys Valley 2D`, commit `d09f32f` (01/10/2026). As falas e
os títulos estão em `data/dialogos/pedro.json`, `arraial.json` e `fazenda.json`; a
ordem e os gatilhos estão em `scripts/mundo/tutorial.gd`, `arraial.gd` e
`fazenda.gd`; a regra das missões em `scripts/autoload/missoes.gd`, que o 3D já
tem em `scripts/compartilhado/missoes.gd`.

**Situação no 3D** foi conferida em 05/10/2026, na `main` (`f6e16a6`). A coluna
"3D" usa quatro marcas:

| Marca | Quer dizer |
|---|---|
| **pronta** | a missão roda no 3D, numa cadeia `data/missoes_*.json` |
| **adaptada** | o 3D tem o mesmo papel com outro passo (a chegada foi reescrita, ver [CHEGADA_E_MUTIROES.md](../mundo/CHEGADA_E_MUTIROES.md)) |
| **só o sistema** | a regra ou o lugar existe, mas nenhuma missão leva o jogador até ela |
| **falta** | nem missão nem sistema; no máximo o texto copiado em `data/dialogos/` |

---

## Como o 2D organiza as missões

- **Frentes que correm juntas, não uma fila.** O tutorial abre cinco frentes ao
  mesmo tempo depois da casa (colheita, trilha, chapada, ofício, apresentações) e
  a caderneta. O arraial abre doze. Dentro de cada frente os passos vêm em fila;
  entre frentes, não há ordem. A regra está no Pedro: "Roça não é fila".
- **Passo = missão.** Cada passo é uma missão própria em `Missoes.ativas`, com
  `id`, título, objetivo, alvo da bússola (nome de lugar, não coordenada) e,
  quando pede várias coisas, uma **checklist sem ordem** (`lista`).
- **Saldo desrisca, acontecimento não.** Item que pede material usa
  `conferir` (gastar a tábua no caminho desmarca a linha); item que conta
  acontecimento (bote esquivado, golpe forte) usa `contar` e não volta atrás.
- **Enredo × ofício.** `Missoes.PRINCIPAIS` lista as missões de enredo: subir,
  casa, vilarejo, convite, ponte_caida, buscar_machado, lenha, tabuas, ponte,
  chapada, mirante_ver, mirante_material, mirante_obra, fe_zefa, fe_marcos e
  fe_escolher. A jornada da fazenda (`DA_JORNADA`) também é enredo. O resto é
  ofício. Enredo entra na frente da lista e do Tab.
- **Missão de fé congela.** As que têm `fe` só andam com aquela fé ativa; se o
  jogador migrar, ela fica parada na lista, sem se perder.
- **Recompensa é de quem paga.** No tutorial, quase todo passo paga comida, por
  regra: é a ponte até o jogador cozinhar sozinho. No arraial, paga quem pede:
  comida quando é gente com panela, item quando é ferramenta, réis quando é
  instituição (vaquinha do arraial, côngrua da Santa Casa).
- **Passos de apoio, gerados.** `crescer` (passiva: "Regue todo dia e durma até
  a mandioca crescer"), `ir_ate_<morador>` ("Volte a falar com …") e
  `procurar_pedro` ("Procure o Pedro") abrem sozinhos quando uma fala precisa do
  jogador perto de alguém. Não têm texto próprio no JSON.

## A ordem, de cima

```
Travessia → nome → andar → subir → [pegar → roca] → casa → frentes
                                                           │
   ┌───────────────┬──────────────┬─────────────┬──────────┴───────┬──────────────┐
   │ colheita      │ trilha       │ chapada     │ ofício           │ apresentações │ caderneta
   │ crescer       │ vilarejo     │ (depois da  │ (depois da lenha)│ (depois da    │ (J)
   │ colher        │ convite      │  colheita)  │ picareta         │  picareta)    │
   │ cozinhar      │ ponte_caida  │ chapada     │ cabra            │ apresentacoes │
   │ pirao         │ buscar_machado              │ pesca            │               │
   │ comer         │ lenha → tabuas → ponte      │ talentos         │               │
   └───────────────┴──────────────┴─────────────┴──────────────────┴──────────────┘
                                  │ todas fechadas + jogador no roçado
                                  ▼
                       arremate do Pedro → fim do tutorial
                                  │
                ┌─────────────────┴──────────────────────────────┐
                ▼                                                ▼
     ARRAIAL (12 frentes em paralelo)                 6 colheitas → SEGUNDO TUTORIAL
     obras: canteiro → mirante                         pomar → curral → capataz
     fé: (mirante de pé) fe_zefa → fe_marcos → fe_escolher
         └─ a fé escolhida abre a missão dela (romaria / mesa / monte)
     povo, Zefa, Tonho, coveiro, Candinha, Filó, armas, capoeira, metas
                                  │
                                  ▼  fe_escolher cumprida e nenhuma missão ativa
                        JORNADA DA FAZENDA (dia seguinte)
                        fazenda_ida → fazenda_chegada → capítulos 6 e 7 (não feitos)
```

---

## 1. O primeiro tutorial — o Pedro ensina a sobreviver

Abre na travessia (narração no escuro), segue com a apresentação do Pedro e a
pergunta do nome, e termina quando as cinco frentes fecham e o jogador volta ao
roçado para o arremate ("roçado plantado, trilha aberta e terreno visto"). Ao
encerrar, abre o arraial e a jornada.

### 1.1 A chegada, em fila

| # | id | Título | Objetivo | Fecha quando | Paga | 3D |
|---|---|---|---|---|---|---|
| 1 | `andar` | As pernas de terra firme | Ande com WASD ou as setas | andou 56 px | — | **pronta** (`desembarque` e `correr`, `missoes_guia.json`: começa em cima do saveiro, no píer, e o Shift ensina a correr) |
| 2 | `subir` | Do cais até a cerca | Siga o Pedro do píer até o seu roçado | chegou à horta; o Pedro vai na frente e abre a porteira | — | **pronta** (o Pedro conduz o bom-dia, a chave e a porta: `conduz` em `missoes_guia.json`) |
| 3 | `pegar` | As ferramentas do finado | Abra o baú na varanda e pegue a enxada, o balde e as manivas | as três na mochila (checklist) | — | **pronta** (`pegar`: o baú da casa tem a enxada, o balde e a maniva) |
| 4 | `roca` | A primeira roça | Abra, plante e molhe — na ordem que quiser | arar, plantar e regar (checklist sem ordem) | 2 beijus | **pronta** (`roca`, `missoes_guia.json`) |
| 5 | `casa` | A porta que ninguém abriu | Entre na casa, o Pedro já está lá dentro | entrou na casa | — | **pronta** (`casa`: a porta espera a chave da Dona Zefa) |

A fala `frentes` vem logo depois da casa e explica o Tab. Até ela, a casa está
trancada ("Primeiro a terra, senão a gente dorme sem comer").

**No 3D (05/10/2026)** a chegada segue esta ordem, com duas diferenças. O baú
mora DENTRO da casa (`casa_do_jogador.gd`), então a porta vem antes dele —
`casa` → `pegar` → `roca` —, e a casa fica trancada até a chave, que o Pedro
leva o jogador a buscar com a Dona Candinha e a Dona Zefa (os pedidos do 3D
que ficaram). E antes do `subir` o jogador desce de um saveiro: começa em cima
dele, no píer. Ver [CHEGADA_E_MUTIROES.md](../mundo/CHEGADA_E_MUTIROES.md).

### 1.2 Frente da colheita

| # | id | Título | Objetivo | Abre quando | Fecha quando | Paga | 3D |
|---|---|---|---|---|---|---|---|
| 1 | `crescer` | (passiva) Regue todo dia e durma até a mandioca crescer | — | junto com as frentes | a mandioca amadureceu | — | só o sistema (`lavoura.gd`) |
| 2 | `colher` | O que a terra devolve | De mão livre, colha a mandioca madura (E) | planta madura | colheu | 1 beiju | **pronta** (`colher`, `missoes_roca.json`) |
| 3 | `cozinhar` | Fogo e farinha | No fogão de casa, torre farinha (E) | colheu; o Pedro dá 2 lenhas | 2 farinhas na mochila | — | **pronta** (`cozinhar`) |
| 4 | `pirao` | Pirão de quem chegou | No fogão, faça o pirão de peixe (E) | o Pedro dá 1 peixe | 1 pirão | — | adaptada (`pirao`: a cuia vai à Dona Filó) |
| 5 | `comer` | A primeira refeição | Coma o pirão (I, depois F) | — | comeu de fato | — | **pronta** (`comer`, último passo de `missoes_roca.json`: o pirão da Dona Filó) |

### 1.3 Frente da trilha — a ponte

| # | id | Título | Objetivo | Fecha quando | Paga | 3D |
|---|---|---|---|---|---|---|
| 1 | `vilarejo` | Conhecer o arraial | Siga a estrada da praia para oeste até a praça | chegou à praça; a Dona Candinha oferece a primeira garapa (cena) | — | adaptada (a chegada passa pela praça) |
| 2 | `convite` | O papel sem assinatura | Leia o convite no mural da praça (E) | o convite na mochila | — | **pronta** (`convite`, último passo da chegada) |
| 3 | `ponte_caida` | O que a cheia levou | Siga a estrada para leste até a ponte do rio grande | chegou ao vau | — | **pronta** (`ponte_caida`, `missoes_ponte.json`: o vau é o rio do norte, ao lado da "Ponte" do KML; e `ponte_contar`, voltar ao Pedro) |
| 4 | `buscar_machado` | Os machados do avô | Siga o Pedro até a casa dele, na praia | chegou à casa do Pedro; ganha o machado | — | adaptada (o machado vem na chegada, no passo `lenha`) |
| 5 | `lenha` | Trinta e seis paus | Junte 36 lenhas na mata (machado, E) | 36 lenhas, contando as já serradas em tábua e corda (`equivale`) | 2 peixes assados | **pronta** (`ponte_lenha`: a conta sai das receitas, `equivale`) |
| 6 | `tabuas` | Serrar e torcer | Encoste na bancada da oficina e aperte E: faça 12 tábuas e 4 cordas | a conta da ponte na mochila | 3 beijus | **pronta** (`tabuas`; ensina o plano da obra) |
| 7 | `ponte` | De pé outra vez | Levante a ponte no vau do rio grande (E) | ponte de pé | 2 pirões, 2 cocadas | **pronta** (`ponte`: a obra `ponte_levantar`, no J ao pé da ponte, tira a cerca das cabeceiras; e `ponte_de_pe`, o fim no Pedro) |

Se o fôlego zera no meio da ponte, o Pedro aparece com o mungunzá da mãe
(`socorro`, seis cuias): é o que deixa fechar a frente no mesmo dia. **No 3D**
também, na lenha e nas tábuas, uma vez por partida (`prototype._conferir_o_socorro`);
como depois da chegada o Pedro não segue o jogador, a fala vem na caixa, como a
explicação do corpo.

**No 3D (05/10/2026)** a ponte é a "Ponte" do KML, onde a Rua Principal cruza o
rio do norte — raso de dar pé, e por isso o vau. Ela está de pé no modelo do
Tripo, então o estrago é o que não se vê de longe, e o que se vê é a cerca nas
duas cabeceiras (`ponte_vale.gd`), que a obra tira. A frente é a primeira que o
E no Pedro abre depois da chegada, e o mirante espera por ela — o mirante é "a
segunda coisa que muda neste arraial em vinte anos".

### 1.4 Frente da chapada

| id | Título | Objetivo | Abre quando | Fecha quando | Paga | 3D |
|---|---|---|---|---|---|---|
| `chapada` | A terra do Seu Benedito | Vá ver a chapada do Seu Benedito, passando pela terra da Dona Zefa | depois da primeira colheita | chegou à expansão (cena com luz dourada) | 1 garapa, 1 cocada | **pronta** (`missoes_chapada.json`: a terra alta para lá da Dona Zefa, de frente para o rio grande; a luz dourada é `luz_dourada.gd`; o fim é a volta ao Pedro) |

### 1.5 Frente do ofício

| # | id | Título | Objetivo | Abre quando | Fecha quando | Paga | 3D |
|---|---|---|---|---|---|---|---|
| 1 | `picareta` | A lapa na boca da rampa | Fique de frente para a lapa da lombada e aperte E até rachar — são 8 pedras | `lenha` cumprida; o Pedro dá a picareta | a passagem aberta (não a conta de pedra) | 2 beijus | **pronta** (`picareta`, `missoes_lombada.json`: a lapa é alvo de trabalho no pé da rampa da lombada de pedra, `lombada_vale.gd`; oito golpes, oito pedras) |
| 2 | `cabra` | A cabra que subiu e não desce | Suba a rampa e chegue perto da cabra, lá no alto da lombada | lapa aberta | chegou perto da cabra; ela desce sozinha, e o Pedro mostra a placa da Santa Casa | — | **pronta** (`cabra`: a cabra do Tripo no alto desce com a `cena`; a placa está lá em cima, e a Santa Casa é a fala do Pedro na volta) |
| 3 | `pesca` | A vara do pai do Pedro | No píer, pesque 2 peixes (E pra lançar, E pra ferrar) | o Pedro dá a vara | 2 peixes | 1 cocada | **pronta** (`pesca`, `missoes_oficio.json`: o Pedro dá a vara; conta dois peixes) |
| 4 | `talentos` | O corpo aprende | Abra a teia de talentos (K) e destrave um talento | tem ponto de talento | gastou um ponto (abrir a tela não basta) | — | **pronta** (`talentos`, `missoes_oficio.json`) |

### 1.6 Frente das apresentações e a caderneta

| id | Título | Objetivo | Abre quando | Fecha quando | 3D |
|---|---|---|---|---|---|
| `apresentacoes` | Seis casas, seis conversas | Converse com cada morador do arraial: chegue perto e aperte E | `picareta` cumprida | uma conversa com cada morador (checklist; o Cosme fica fora) | adaptada (a chegada faz falar com Tonho, Candinha e Zefa; o E conversa com qualquer morador) |
| `caderneta` | A lista do que está aberto | Aperte J para abrir a lista de missões | junto com as frentes | abriu a lista e fechou a tela | **pronta** (`caderneta`, na chegada, depois do baú) |

Duas falas soltas do Pedro entram nessa altura sem missão: `companhia` (C para
ele parar de seguir) e `anoitecer` (lembra a cama quando o sol cai).

---

## 2. O segundo tutorial — montar uma fazenda

Abre na **sexta colheita**, depois do primeiro tutorial. Fila única.

| # | id | Título | Objetivo | Fecha quando | Paga | 3D |
|---|---|---|---|---|---|---|
| 1 | `pomar` | Quem planta manga | Plante uma muda de fruteira no seu roçado | plantou; o Pedro dá 2 mudas de banana e 1 de manga | 2 beijus | falta |
| 2 | `curral_aprender` | O que o quintal dá | Destrave o Curral na raiz Pastoreio (tecla K) | talento Curral; o galinheiro sobe com 3 galinhas (pula se já tinha o talento) | — | falta |
| 3 | `curral` | O que o quintal dá | Recolha 2 ovos das galinhas | 2 ovos | 2 cocadas | falta |
| 4 | `capataz` | O braço que não é o seu | Mande um morador seu trabalhar em alguma coisa | designou trabalho a um morador de terra sua | — | falta |

---

## 3. O arraial — depois do tutorial

Abre quando o tutorial encerra. As doze frentes correm juntas; os gatilhos
abaixo dizem quando cada uma começa.

### 3.1 Obras: canteiro, depois mirante (Pedro)

| # | id | Título | Objetivo | Fecha quando | Paga | 3D |
|---|---|---|---|---|---|---|
| 1 | `canteiro_material` | O prumo e o serrote | Junte 8 tábuas e 12 lenhas para o canteiro | o material na mochila | — | **pronta** (`canteiro_material`, `missoes_arraial.json`: a mesa do prumo é provisória, ao lado da bancada da oficina) |
| 2 | `canteiro_obra` | Riscar antes de levantar | No canteiro de obras, faça a prancheta (E) | obra `canteiro_prancheta` feita; abate 10% do mirante | 3 beijus | **pronta** (`canteiro_obra`: o E na mesa abre a aba de obras dela; o material do mirante passa a ser a conta de hoje, `da_obra`) |
| 3 | `mirante_ver` | O que ninguém consertou | Suba a estrada do mirante e veja o que sobrou dele | chegou ao mirante | — | **pronta** (`missoes_arraial.json`) |
| 4 | `mirante_material` | Tabuado, pedra e corda | Junte o material do mirante | a conta de hoje (20 tábuas, 12 pedras, 6 cordas, menos 10% com a prancheta) | — | **pronta** |
| 5 | `mirante_obra` | De pé, outra vez | Levante o mirante (E) | obra `mirante_levantar` feita; vista do alto | 1.200 réis (vaquinha) e 1 pirão | **pronta** |

### 3.2 A fé (Dona Zefa) — fecha a fila do arraial

| # | id | Título | Objetivo | Abre quando | Fecha quando | Paga | 3D |
|---|---|---|---|---|---|---|---|
| 1 | `fe_zefa` | O recado da Dona Zefa | Fale com a Dona Zefa, no terreno vizinho ao seu | **o mirante de pé** | falou com ela | — | **pronta** (`missoes_fe.json`) |
| 2 | `fe_marcos` | Os três lugares | Visite os três marcos do arraial: cruzeiro, terreiro, gameleira do sambaqui | `fe_zefa` | os três visitados, em qualquer ordem | 2 cocadas | **pronta** |
| 3 | `fe_voltar` | Contar à Dona Zefa | Volte à casa da Dona Zefa e conte o que viu | só se o jogador estiver longe dela | perto dela | — | **pronta** |
| 4 | `fe_escolher` | A que te chamar | Volte a um dos três marcos e entre para aquela fé | os marcos passam a aceitar | entrou numa fé | 2 beijus, 2 garapas | **pronta** |

`fe_escolher` é o **passo que fecha o arraial**: a jornada da fazenda espera por
ele (`Jornada.PASSO_QUE_FECHA_O_ARRAIAL`).

### 3.3 A missão de cada fé (congela na migração)

Abre na entrada da fé e de novo a cada migração para ela; cumprida, não reabre.

| id | Fé | Título | Objetivo | Paga | 3D |
|---|---|---|---|---|---|
| `fe_romaria` | católica | A romaria | Passe nos quatro marcos da igreja: cruzeiro, capela, capelinha da estrada, cemitério | 2 beijus | **pronta** |
| `fe_mesa` | candomblé | A mesa da folha | Leve 3 ervas, 2 peixes e 2 farinhas ao terreiro | 2 pirões | **pronta** (canas no lugar da farinha) |
| `fe_monte` | caboclo | Pagar o monte | Leve 6 ostras à gameleira do sambaqui | 2 peixes assados | **pronta** |

### 3.4 O povo (Dona Zefa)

| id | Título | Objetivo | Abre quando | Fecha quando | 3D |
|---|---|---|---|---|---|
| `povo_conhecer` | Aperte P e veja quem é quem no arraial | Aperte P para abrir a caderneta do arraial | algum morador com afinidade > 0 | abriu a tela (sem bússola: é sobre a tecla) | **pronta** |

### 3.5 A Dona Zefa e o neto (série de terra)

Abre com o mirante de pé, com `fe_zefa` aberta ou com uma fé ativa — o que vier
primeiro. Não abre se a terra da Zefa já for do jogador.

| # | id | Título | Objetivo | Fecha quando | Paga | 3D |
|---|---|---|---|---|---|---|
| 1 | `zefa_ervas` | O que só nasce lá em cima | Junte 5 maços de erva nas clareiras da serra e leve à Dona Zefa | 5 ervas entregues a ela | 2 cocadas | **pronta** |
| 2 | `zefa_cosme` | O que o Cosme não contou | Fale com o Cosme, no quintal da Dona Zefa | falou com ele | — | **pronta** |
| 3 | `zefa_conversa` | A conversa que ela prometeu | Volte à Dona Zefa | falou com ela | 2 beijus | **pronta** |
| 4 | `zefa_terra` | O saveiro das seis | Encontre os dois no píer | chegou ao píer; ganha a terra da Zefa; o Cosme embarca | 3 cocadas, 1 pirão | **pronta** (`zefa_saveiro`) |

### 3.6 O Tonho: a rede e a dívida (série de terra)

| # | id | Título | Objetivo | Abre quando | Fecha quando | Paga | 3D |
|---|---|---|---|---|---|---|---|
| 1 | `pescador_ver` | Fale com o Tonho no pontal | Leve a vara até o Tonho, no pontal | tem a vara de pescar | falou com ele | 1 pirão | **pronta** (`missoes_tonho.json`) |
| 2 | `pescador_rede` | A rede do Tonho | Leve 5 cordas e 3 tábuas ao Tonho | `pescador_ver` | material entregue | 2 pirões, 1 cocada | **pronta** |
| 3 | `tonho_divida` | A conta do Tonho | Entre no armazém e aperte E no baú do livro de fiado — ou espere a rede pagar | `pescador_rede` | dívida quitada | 2 peixes assados | **pronta** (+ `tonho_livro`, novo no 3D) |
| 4 | `tonho_terra` | A terra do Tonho | Volte ao pontal: ele quer entregar a terra na sua mão | dívida quitada | falou com ele; ganha a terra do Tonho | 2 pirões, 2 cocadas | **pronta** |

### 3.7 O coveiro Damião

| # | id | Título | Objetivo | Abre quando | Fecha quando | Paga | 3D |
|---|---|---|---|---|---|---|---|
| 1 | `coveiro_ver` | O zelador do cemitério | Suba ao cemitério, no outeiro atrás da praça | tem o machado | falou com o Damião | — | **pronta** (`missoes_coveiro.json`) |
| 2 | `coveiro_foice` | Encabar a foice do Damião | Leve 2 tábuas e 2 cordas ao Damião, no cemitério | `coveiro_ver` | material entregue | a foice | **pronta** (`coveiro_cabo`) |
| 3 | `coveiro_limpar` | Limpar o cemitério | Corte com a foice TODO o capim alto em volta das covas (E de frente para cada pé) | `coveiro_foice` | nenhum capim alto (contado no chão) | 800 réis (côngrua da Santa Casa) | **pronta** (+ mato, reparo e cercado, novos no 3D) |

### 3.8 A Dona Candinha e a Dona Filó

| id | Título | Objetivo | Abre quando | Fecha quando | Paga | 3D |
|---|---|---|---|---|---|---|
| `candinha_cana` | A garapa da praça | Leve 6 canas para a Dona Candinha, no meio da praça | afinidade com ela > 0 | canas entregues a ela | 3 garapas | **pronta** (`missoes_candinha.json`) |
| `filo_almoco` | O pirão da Dona Filó | Leve o pirão até o Tonho, no pontal da praia | afinidade com ela > 0 | entregou ao Tonho | 2 cocadas | **pronta** (`filo_pedido` e `filo_pirao`) |

### 3.9 As armas (Pedro) — o combate

Abre na primeira vez que um bicho persegue o jogador ou que ele entra na mata.

| # | id | Título | Objetivo | Fecha quando | Paga | 3D |
|---|---|---|---|---|---|---|
| 1 | `armas_facao` | Um facão de mato | Bata um facão na oficina: duas lenhas e uma pedra | tem o facão (se já tinha, fecha na hora); a lição do aviso do bote (`armas_licao`) | — | **pronta** (`missoes_armas.json`: a receita abre no anúncio) |
| 2 | `armas_bote` | Encarar um caititu | Derrube um caititu na mata do dendê ou no pé da pedreira | 1 caititu | 2 peixes assados | **pronta** (`armas_bote`) |
| 3 | `armas_forte` | O golpe de peso | Acerte 3 golpes fortes em bicho da mata (segure E e solte) | 3 golpes fortes (contados); ensina o golpe forte antes de abrir | 2 pirões | **pronta** (`armas_forte`: o passo ensina o golpe, `ensina`; meta `contar`) |

### 3.10 A capoeira (Cosme) — missões de fé, candomblé

Abre com o candomblé ativo, `fe_mesa` cumprida, o Cosme no arraial e nenhum
bicho caçando o jogador. Cada lição volta ao Cosme para fechar.

| # | id | Título | Objetivo | Fecha quando | Paga | 3D |
|---|---|---|---|---|---|---|
| 1 | `capoeira_ginga` | A ginga | Esquive de 3 botes com a ginga (V na hora do aviso) | 3 esquivas | — | **pronta** (`missoes_capoeira.json`; a volta ao Cosme é passo de falar) |
| 2 | `capoeira_meia_lua` | A meia-lua | Acerte 4 meias-luas em bicho da mata (E de mão vazia) | 4 acertos | 2 cocadas | **pronta** |
| 3 | `capoeira_rasteira` | A rasteira | Deixe 2 bichos tontos com a rasteira (segure E de mão vazia) | 2 bichos tontos | 2 mungunzás | **pronta** |

### 3.11 As metas do caderno dos bichos

Abrem quando a conta de abatidos chega, com o jogador fora da mata e sem bicho
caçando. Lidas de `data/colecionaveis/bichos.json`.

| id | Título | Objetivo | Conta | Quem paga | Paga | 3D |
|---|---|---|---|---|---|---|
| `meta_caititu` | O gibão do pai do Pedro | Fale com o Pedro | 10 caititus | Pedro | gibão de couro | **pronta** (`missoes_metas.json`, abre sozinha na conta) |
| `meta_onca` | O patuá da Dona Zefa | Leve um couro de onça à Dona Zefa | 2 onças | Dona Zefa | patuá | falta escrever: a onça chegou ao vale em 05/10/2026 (`luta_vale.oncas`, a pintada e a preta, que largam `couro_de_onca`), e a meta ainda não está em `missoes_metas.json` |

---

## 4. A jornada da fazenda — capítulos 6 e 7

Marca o dia na **manhã seguinte** ao momento em que `fe_escolher` está cumprida e
não sobra nenhuma missão ativa que não seja passiva ou congelada. O Pedro vem
acordar o jogador.

| # | id | Título | Objetivo | Fecha quando | 3D |
|---|---|---|---|---|---|
| 1 | `fazenda_ida` | É hoje | Atravesse o rio com o Pedro até o portão da fazenda | chegou ao portão (o Pedro leva); o portão abre e a narração da chegada roda | **pronta** (`missoes_fazenda.json`, `fazenda_vale.gd`: o dia vem na manhã seguinte à fé escolhida, com a ponte de pé; o Pedro vem à porta e conduz; a narração é `narracao_do_vale.gd`) |
| 2 | `fazenda_chegada` | O pátio da fazenda | Atravesse o pátio até a escadaria do casarão | chegou ao pátio | **pronta** (`fazenda_chegada`: o arraial sentado nos banquinhos, as mesas cobertas e as cabras soltas; o fim é a fala do Pedro) |

Sem recompensa: é a história começando. O 2D para aqui (fatia 6.1). O resto dos
capítulos está só na prosa (`docs/enredo/` do 2D e `data/enredo/enredo.json`) e
não tem missão em nenhum dos dois jogos:

- **Capítulo 6, Um Convite ao Acaso:** o chamado aos corajosos (a anfitriã mais
  velha), o salão circular e a porta estreita.
- **Capítulo 7, O Revoar das Asas Negras:** o quarto sem janelas, as miragens e a
  mão estendida, a fuga pelos corredores, o revoar da coruja (a Matinta Pereira),
  o abrigo nas ruínas do palacete, o relato das escravas, o escudo e a lança de
  safiras, o embate final, a libertação e o quilombo.

---

## 5. O que falta trazer, em ordem de dependência

1. ~~A ponte~~ (`ponte_caida` → `ponte`, 1.3): **pronta** em 05/10/2026, com
   o socorro da mungunzá. É enredo e é a trava da jornada: a fazenda fica do
   outro lado do rio grande.
2. ~~A lapa e a cabra~~ (`picareta`, `cabra`, 1.5): **prontas** em 05/10/2026, na
   lombada de pedra que o vale levantou entre a casa e a chapada.
3. ~~A chapada~~ (1.4): **pronta** em 05/10/2026, no lugar que o autor revisou.
4. ~~O canteiro~~ (3.1): **pronto** em 05/10/2026, antes do mirante como no 2D.
5. ~~A jornada da fazenda~~ (4): **pronta** em 05/10/2026, a fatia 6.1, do
   outro lado do rio grande, com o portão baixo e a guarita do capítulo 6 (Tripo).
   No vale o dia vem na manhã seguinte à fé escolhida e com a ponte de pé, sem
   esperar todas as missões fechadas (regra aprovada pelo autor).
6. ~~As armas, a capoeira e as metas~~ (3.9 a 3.11): **prontas** em 05/10/2026,
   menos a meta da onça. Ela esperava a onça no vale, e a onça chegou no mesmo
   dia (a pintada e a preta, com couro): **a meta da onça é o próximo passo
   pequeno**, e não espera mais nada.
7. **O segundo tutorial** (2): pomar, curral e capataz pedem sistemas que o 3D
   ainda não tem.
8. ~~Os passos de apoio do tutorial~~ (`comer`, `pesca`, `talentos`,
   `caderneta`): **prontos** em 05/10/2026.

Ficam no 3D sem par no 2D: a carroça do Seu Benedito (`missoes_carroca.json`), o
saveiro do mestre Quirino (`missoes_saveiro.json`), `fe_contar`, `tonho_livro`
e os três passos novos do cemitério.

## 6. O que o 2D aprendeu e a migração deve manter

Tirado dos comentários do código, onde cada regra conta o defeito que a criou:

- **Checklist sem ordem quando a tarefa não tem ordem.** A primeira roça era
  fila e prendia quem regava antes de plantar.
- **O contador e a condição de fechar são a mesma conta.** A lenha da ponte
  conta o que já virou tábua e corda (`Missoes.contagem` com `equivale`).
- **A missão fecha pelo que ela é, não pelo atalho.** A da picareta fecha pela
  passagem aberta, e não por oito pedras quaisquer.
- **Alvo por nome de lugar**, resolvido na hora de apontar; bicho e gente que
  andam são reapontados a cada quadro.
- **Missão sem lugar não tem bússola** (`povo_conhecer`, `talentos`).
- **Não abrir missão no meio de outra ação.** A picareta abria na primeira
  machadada e o jogador pulava as falas apertando E; agora espera a lenha.
- **Foco órfão.** Ao fechar o passo em foco, só a mesma linha herda o foco; outra
  frente que abra no intervalo não rouba a tela.
