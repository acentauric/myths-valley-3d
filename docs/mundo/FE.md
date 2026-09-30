# A fé

Três fés, uma por vez, cada uma com a sua árvore e a sua conta de experiência.
Trocar não apaga nada; levar o que se juntou é que custa caro.

Código: [`scripts/autoload/fe.gd`](../../scripts/autoload/fe.gd) (as fés, as árvores
e a migração) e [`scripts/autoload/ritos.gd`](../../scripts/autoload/ritos.gd) (o
rito num marco). A missão que apresenta as três está em
[`scripts/mundo/arraial.gd`](../../scripts/mundo/arraial.gd), com o texto em
[`data/dialogos/arraial.json`](../../data/dialogos/arraial.json).

---

## 1. As três, e por que estas três

O Recôncavo de 1887 tem as três em cima do mesmo chão, e a documentação de
ambientação já dizia isso sem ter onde pôr (ver [AMBIENTACAO.md](AMBIENTACAO.md)
§1.1): igreja de pedra e cal com duzentos e trinta anos, terreiro que não podia
ser visto da estrada, e o chão de quem esteve aqui antes de todo mundo.

| Fé | Marcos no mapa | O que ela rende |
|---|---|---|
| **Católica** | Cruzeiro da praça, capela, capela de estrada, cemitério | **Convívio**: obra mais barata, venda melhor, sono melhor, romaria |
| **Candomblé** | Terreiro, na mata a oeste da estrada do mirante | **Trabalho**: colheita, panela, ferramenta, pesca, gente junta |
| **Caboclo** | Gameleira do sambaqui, na ponta poente da praia | **Corpo**: fôlego que dura, pé que anda, machadada que rende |

A católica é a única que já tinha os marcos dela no mapa desde o começo, e isso
**não é acaso**: em 1887 ela é a única que pode ser praticada à luz do dia. É a
única com mais de um marco, também — e como a espera do rito é contada por
marco e não por fé, ter quatro é a vantagem mecânica dela.

O terreiro fica escondido porque era escondido. A primeira tentativa o pôs no
cotovelo da estrada, onde a mata é rala; a pegada limpou as poucas árvores em
volta e ele apareceu no meio de um gramado aberto, à vista de quem passasse. Foi
movido para dentro do bolsão de mata fechada, com uma vereda de **um tile** —
caminho de pé de gente, não estrada.

A gameleira está na beira d'água porque sambaqui é monte de concha, e concha é
coisa de maré. Pôr esse marco serra adentro seria bonito e seria falso.

---

## 2. Uma por vez, e o que "congelar" quer dizer

O personagem pratica **uma**. As outras ficam congeladas no ponto exato em que
pararam.

Congelada quer dizer três coisas, e as três são testadas:

1. **Não rende.** `Fe.bonus` só olha a fé ativa, e `Talentos.bonus` soma as
   duas num número só — então o resto do jogo (pesca, cozinha, obra, venda,
   colheita) pergunta por um bônus e recebe um número, sem saber de onde ele
   veio. Trocar de fé se sente na mão no dia seguinte.
2. **Não se perde.** Os nós destravados, os pontos por gastar e o total
   acumulado ficam guardados. Voltar devolve a árvore inteira como estava.
3. **As missões dela param junto.** Missão marcada com `fe` no `Missoes` fica
   na lista, marcada como parada, e volta a correr quando a fé voltar. Perder o
   andado puniria a curiosidade, que é justamente o que a migração existe para
   permitir.

O que **não** é desfeito ao trocar: efeito que já mexeu em `Progressao` — teto
de fôlego, quanto o sono devolve, nível de ferramenta. É deliberado. Teto de
fôlego que sobe e desce ao mudar de religião faria o jogador acordar com menos
corpo do que deitou. *O que a fé ensinou ao corpo, o corpo aprendeu; o que ela
dava, para de dar.*

---

## 3. A conta do XP

O que se guarda por fé é o **total acumulado**. Nível e ponto saem dele:

- nível é onde o total chega, pela mesma curva dos talentos de ofício
  (`60 × 1,35^(n-1)`);
- ponto é um por nível vencido, menos o que já foi gasto.

XP de fé vem de **ato de fé**, e só conta para a fé ativa:

| Ato | XP |
|---|---|
| Rito no marco (rezar, oferendar) | 30 |
| Visita a um marco | 8 |
| Missão de fé cumprida | 60 |
| Obra levantada num marco seu | 20 |

Rezar no cruzeiro sendo do candomblé não rende axé nenhum. É isso que faz a
escolha pesar.

### Migrar pontos: 85% no caminho

São **duas decisões**, e nunca uma só:

1. **Trocar de fé** não custa nada. O que você praticava congela inteiro.
2. **Levar o acumulado junto** custa 85%. Sai o total da fé de origem, chegam
   15% dele, e o que chega **soma** à base que a de destino já tinha.

A de origem fica com total zero — mas conserva o que aprendeu e os pontos que
já ganhou. Um campo `teto` guarda o nível mais alto que ela já alcançou e o
ponto só é creditado acima dele: sem isso dava para migrar tudo para fora,
reconquistar o mesmo nível e ganhar o mesmo ponto duas vezes.

O jogo diz o número inteiro **antes** de qualquer sim: quanto sai, quanto
chega, quanto se perde, e em que nível a fé de destino fica depois. Decisão
dessa faixa não se toma no escuro.

---

## 4. Onde isso aparece no jogo

**A escolha é feita com os pés.** Não existe menu de religião, e não deve
existir: o jogador anda até o marco da fé que quer e aceita ali. Migrar é o
mesmo gesto, num marco que não é o seu.

Um marco de fé alheia não é marco proibido — é marco **mudo**. Quem chega,
repara, e nada acontece, que é o que acontece de verdade quando alguém para na
frente de uma coisa em que não crê.

**A teia** é a mesma tela dos talentos de ofício (tecla K), e **Tab** troca
entre as duas. Elas não ganharam telas separadas de propósito: o desenho é o
mesmo, a navegação é a mesma, e duas cópias do arquivo seriam duas cópias para
manter em dia — que é exatamente o erro que a regra da vista já custou uma vez
neste projeto (ver [PERSPECTIVA.md](../arte/PERSPECTIVA.md) §2).

---

## 5. A missão que apresenta as três

Quem conduz é a **Dona Zefa**, benzedeira, a única pessoa do arraial que sabe
das três sem desprezar nenhuma — e que, como muita gente do Recôncavo, vai à
missa de manhã sabendo de qual é por dentro.

Ela não escolhe pelo jogador. Ela **mostra os três lugares**, e eles ficam nos
três cantos do mapa de propósito: o cruzeiro no meio da vila, o terreiro na
mata do poente, a gameleira na ponta da praia. A geografia das três fés *é* a
lição, e ela não se aprende lendo uma tela de escolha com três botões.

Só depois de andar os três é que os marcos passam a aceitar. Escolher fé sem
ter visto as três não é escolha, é sorteio.

---

## 6. O portão e o retrato

[`tools/gdscript/testar_fe.gd`](../../tools/gdscript/testar_fe.gd) tranca seis
regras e duas conferências de consistência. Ele existe porque a fé é o primeiro
sistema do jogo em que **errar é silencioso**: talento de ofício errado se vê
na tela; fé errada só aparece quando o jogador volta à fé antiga, semanas
depois, e acha a árvore dele vazia — e aí não há de onde tirar o que se perdeu.

As seis regras estão escritas no cabeçalho do teste. A falsificação que provou
que ele morde foi trocar `Fe.bonus` por uma versão que soma TODAS as fés (o
engano que alguém cometeria de boa-fé, "somando tudo"): duas regras reprovaram
na hora.

E há o retrato, que o número não dá:
[`tools/gdscript/retratar_teias.gd`](../../tools/gdscript/retratar_teias.gd) abre o
jogo, apaga tudo que não é a teia e salva as quatro em `scratch/teias/` — a de
ofício e a de cada fé. Árvore mal formada não dá erro nenhum: uma raiz com um nó
só, um anel que não cabe, um `exige` apontando para fora. Aparece torto, e
pronto.

---

## 7. A fé com consequência (fase 5, primeira parte)

Duas coisas saíram da planilha em setembro de 2026.

### A missão própria de cada fé

Uma por fé, na vocação dela, dada pelo próprio marco no dia em que se entra
(ou se volta). É a voz do mundo, sem nome: ninguém mora nos marcos.

| Fé | Missão | O que pede | Por quê |
|---|---|---|---|
| Católica | **A romaria** | Passar nos quatro marcos da igreja | Convívio: é a fé que "anda com o arraial inteiro", e andar é o que ela pede |
| Candomblé | **A mesa da folha** | 3 ervas da serra, 2 peixes e 2 farinhas, entregues no terreiro | Trabalho: o que a terra dá, o que a água dá e o que a mão fez |
| Caboclo | **Pagar o monte** | 6 ostras, postas na gameleira | Corpo e antigo: o sambaqui **é** concha, e pagá-lo é continuar o monte |

São as únicas missões marcadas com `fe` no `Missoes`, e por isso as únicas que
**congelam** de verdade: migrar no meio da romaria para o caboclo deixa a
romaria parada na lista, chegar no cruzeiro não risca nada, e voltar à
católica risca de novo. A cumprida não reabre — o `Missoes.cumpridas` guarda o
id e vai para o salvamento, porque a romaria não deixa nada no mundo além de
ter sido andada. Código em `Arraial._frente_das_fes`.

As duas oferendas são o primeiro **item deixado num marco**, que a lista de
faltas abaixo pedia. O rito em si continua de graça.

### O preço social de migrar

Cada morador é de uma fé, escrita no `aldeoes.json` ao lado do gosto — fé é
caracterização, não tabela. Quatro são da igreja (Seu Benedito, Dona Filó,
Dona Candinha, Damião), dois do terreiro (Dona Zefa, Cosme) e um do mato
(Tonho). Migrar desconta **15** de afinidade com quem é da fé deixada e devolve
**5** a quem é da fé de chegada: deixar custa mais do que chegar rende, senão
migrar em roda seria lucro. O jogo diz quem vai ficar sabendo **antes** do sim,
na mesma conversa em que diz o preço em pontos. Código em `Afinidade._ao_migrar`.

### A festa de calendário

Um dia por ano por fé, e é onde a fé encontra os moradores de uma vez. As datas
são as do Recôncavo, postas na estação do jogo:

| Fé | Festa | Quando | Por quê |
|---|---|---|---|
| Católica | Bom Jesus dos Navegantes | 1º do verão | O padroeiro do arraial; a procissão dele é de saveiro, como o forasteiro chegou |
| Candomblé | Cosme e Damião | 27 da primavera | O caruru das crianças. Dois moradores têm esses nomes, e não é acaso |
| Caboclo | Dois de Julho | 2 do inverno | A independência da Bahia, celebrada com o caboclo nos carros: a romaria de quem é do mato |

É o **calendário** que manda, não a fé ativa: a festa acontece quer o jogador
seja dela ou não. No dia, três coisas:

1. o cartão do amanhecer avisa (`Mundo._lembretes_do_dia`);
2. à tarde, quem é da fé vai para o marco maior dela em vez da tarde de sempre
   (`Mundo._posto_de`), depois do trabalho, porque dia comprado não tem festa;
3. o rito no marco dela sai **fora do prazo** (`Ritos.pode_celebrar`), rende
   40 de fé por cima dos 30 do rito, e rende 6 de afinidade com cada um da fé
   que está ali — gente junta.

Com isso a fase 5 fecha. Código em `Fe.FESTAS`, `Ritos.celebrar` e
`Mundo._posto_de`; portões em `testar_fe` e `testar_moradores`.

### A roda do Cosme: a capoeira é do candomblé

"Golpes de luta como capoeira — essa missão deve ser vinculada às missões do
candomblé." A série vem **depois da mesa da folha**, que é a missão própria da
fé: quem ainda não sentou na roda não é chamado para jogar nela. Quem ensina é o
**Cosme**, que é do terreiro, e a roda é no fim da tarde, atrás do barracão —
em 1887 a polícia chama aquilo de crime, e é por isso que ela mora ali e não na
praça.

| Lição | O que ensina | O que pede |
|---|---|---|
| **A ginga** | a esquiva, na tecla V | 3 botes esquivados |
| **A meia-lua** | o E de mão vazia, que varre a frente e o lado | 4 que acertem |
| **A rasteira** | segurar o E de mão vazia: o bicho vai ao chão tonto | 2 bichos tontos |

As três são **missões de fé**, como a mesa: congelam na migração, e a conta
para de andar (`Missoes.contar` não conta em missão congelada). O que **não**
congela é o que já se aprendeu — capoeira é do corpo de quem jogou, e migrar
não desaprende a ginga. O que para é a lição que falta e a teia por cima.

**A raiz Capoeira** entrou na teia do candomblé, e é a quinta dela: ginga de
roda (a ginga gasta metade), meia-lua de compasso (a capoeira bate meia vez
mais) e rasteira de mestre (a rasteira tonteia o dobro). Os três nós valem só
para quem aprendeu: ginga não se compra com ponto.

Código em `Luta`, `Arraial._frente_da_capoeira`; portão em `testar_luta`. Ver
docs/projeto/PLANO.md, "A luta ensinada".

## 8. O que falta

- **Ícones dos nós de fé.** As três árvores somam 30 nós e só dois têm ícone
  (`promessa` e `devocao` herdaram os da antiga raiz Fé dos talentos de ofício).
  Os outros caem na sigla de duas letras. **A teia de ofício já não tem esse
  buraco** — os nós dela ganharam ícone na fatia P8 do playtest —, então a fé é
  hoje a única árvore que abre com sigla, e está na fila.
- **Habilidade ATIVA de fé.** Nenhuma das três tem uma ainda; a árvore de
  ofício tem uma (`segundo_folego`, tecla R) e o formato já está pronto aqui —
  `Fe.ativos()` existe e devolve lista vazia.
- **Rito próprio de cada fé.** Hoje os três compartilham a mesma cena (o
  personagem para, a tela escurece, volta). A bênção já é diferente por fé; o
  gesto ainda não.
- **Oferenda com item no rito.** A mesa da folha e o pagar o monte (§7) são as
  primeiras coisas deixadas num marco, mas são missão, uma vez. O rito das duas
  continua de graça, e dar custo em item a ele é o que o diferenciaria da reza.
- **O padre e a mãe de santo.** Os marcos respondem; ninguém mora neles.
- **A luta de cada fé.** A capoeira é a do candomblé. A católica e a do
  caboclo ainda não têm a sua, e é aí que a luta com poder pode entrar quando
  o místico entrar — ver docs/projeto/PLANO.md.
