# A fé

Três fés, uma por vez, cada uma com a sua árvore e a sua conta de experiência.
Trocar não apaga nada; levar o que se juntou é que custa caro.

Código: [`scripts/autoload/fe.gd`](../scripts/autoload/fe.gd) (as fés, as árvores
e a migração) e [`scripts/autoload/ritos.gd`](../scripts/autoload/ritos.gd) (o
rito num marco). A missão que apresenta as três está em
[`scripts/mundo/arraial.gd`](../scripts/mundo/arraial.gd), com o texto em
[`data/dialogos/arraial.json`](../data/dialogos/arraial.json).

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
neste projeto (ver [PERSPECTIVA.md](PERSPECTIVA.md) §2).

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

[`tools/gdscript/testar_fe.gd`](../tools/gdscript/testar_fe.gd) tranca seis
regras e duas conferências de consistência. Ele existe porque a fé é o primeiro
sistema do jogo em que **errar é silencioso**: talento de ofício errado se vê
na tela; fé errada só aparece quando o jogador volta à fé antiga, semanas
depois, e acha a árvore dele vazia — e aí não há de onde tirar o que se perdeu.

As seis regras estão escritas no cabeçalho do teste. A falsificação que provou
que ele morde foi trocar `Fe.bonus` por uma versão que soma TODAS as fés (o
engano que alguém cometeria de boa-fé, "somando tudo"): duas regras reprovaram
na hora.

E há o retrato, que o número não dá:
[`tools/gdscript/retratar_teias.gd`](../tools/gdscript/retratar_teias.gd) abre o
jogo, apaga tudo que não é a teia e salva as quatro em `scratch/teias/` — a de
ofício e a de cada fé. Árvore mal formada não dá erro nenhum: uma raiz com um nó
só, um anel que não cabe, um `exige` apontando para fora. Aparece torto, e
pronto.

---

## 7. O que falta

- **Ícones dos nós de fé.** As três árvores somam 27 nós e só dois têm ícone
  (`promessa` e `devocao` herdaram os da antiga raiz Fé dos talentos de ofício).
  Os outros caem na sigla de duas letras — que é o mesmo que já acontece com
  dez nós do ofício, então não é regressão, mas está na fila.
- **Habilidade ATIVA de fé.** Nenhuma das três tem uma ainda; a árvore de
  ofício tem uma (`segundo_folego`, tecla R) e o formato já está pronto aqui —
  `Fe.ativos()` existe e devolve lista vazia.
- **Rito próprio de cada fé.** Hoje os três compartilham a mesma cena (o
  personagem para, a tela escurece, volta). A bênção já é diferente por fé; o
  gesto ainda não.
- **Oferenda com item.** O candomblé e o caboclo pedem "deixar o que trouxe", e
  hoje não se deixa nada. Dar custo em item ao rito das duas é o passo seguinte
  óbvio, e é o que as diferenciaria da reza, que é de graça.
- **O padre e a mãe de santo.** Os marcos respondem; ninguém mora neles.
