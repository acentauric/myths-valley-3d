# As falas de Myths' Valley 3D

Todas as falas que o jogo diz, num documento só, etiquetadas para validar o texto
e para servir de referência à geração de áudio. Feito em 08/10/2026.

| Arquivo | O que é |
|---|---|
| [`FALAS.xlsx`](FALAS.xlsx) | O documento. Abre no Excel, no LibreOffice e no Google Planilhas. |
| [`FALAS.csv`](FALAS.csv) | A aba principal em texto, para comparar versões e para ferramentas. |
| [`analise_das_falas.json`](analise_das_falas.json) | A revisão: o que se achou em cada fala, por ID. |
| [`../../tools/falas/`](../../tools/falas/) | O gerador, que lê as falas de onde o jogo as lê. |

## As abas do documento

- **Falas**: uma linha por fala, na ordem da história, com 39 colunas em nove
  grupos: identificação, linha do tempo, quem e como toca, contexto de mecânica,
  textos nos quatro idiomas, áudio, checagens automáticas, análise e validação.
  A coluna **Status da validação** tem lista de escolha para o time marcar.
- **Problemas**: só as falas em que a revisão achou alguma coisa, da prioridade
  alta para a baixa, com o problema e a correção sugerida.
- **Alertas automáticos**: o que o gerador acha sozinho e ainda não foi revisto.
- **Personagens**: por quem fala, a voz do ElevenLabs, quantas falas, quantas
  já têm áudio, quantas faltam e quantas letras (o tamanho em créditos).
- **Missões (linha do tempo)**: as 52 filas na ordem em que abrem, com o que as
  destrava.
- **Áudios sem fala** e **Legenda**: os arquivos de voz que nenhuma fala usa, e
  o que cada coluna quer dizer.

## Como refazer

As falas mudam nos arquivos do jogo (a coluna **Onde editar** diz onde), e o
documento se refaz:

```
node tools/falas/gerar_documento_das_falas.js
```

A análise fica guardada por ID. Quando uma fala revisada muda de texto, ela
aparece como "revisar (o texto mudou)"; fala nova aparece como "não revisada".
Depois de revisar de novo, `--marcar-revisadas` grava o texto de hoje como visto.
`--despejo arquivo.txt` escreve as falas em texto corrido, na ordem, para leitura.

## Os números

| | Falas |
|---|---|
| No documento | 1.291 |
| Tocam no 3D | 659 |
| Herdadas do 2D, que o 3D não diz | 632 |
| Com voz gravada | 229 |
| Faladas e ainda sem áudio | 320 (56 mil letras, perto de 67 minutos) |
| Com problema apontado na revisão | 87 (8 de prioridade alta, 45 média, 34 baixa) |

As 632 herdadas do 2D são os assuntos e as reações a presente do
`aldeoes.json` e o tutorial antigo do `pedro.json`: o 3D lê desses arquivos só o
gosto de presente, a travessia e nada mais. Ficam no documento marcadas como
"não toca", para ninguém gerar voz para elas.

## O que a revisão encontrou

A revisão leu as 659 falas em uso na ordem da história, contra os capítulos 6
e 7, os documentos do projeto e os dados do jogo: receitas, alvos, lugares,
horários e teclas.

### Prioridade alta: ensina errado ou quebra a história

1. **A pedra do poço manda ao lajedo.** No dia 1 o Pedro diz que a pedra sai do
   lajedo ao lado do poço, que agora pede picareta de aço e o talento Mão de
   pedra. O mesmo na carroça do Seu Benedito.
2. **O cercado do cemitério não diz que corda é lenha.** A obra pede 6 lenhas e
   2 cordas, e cada corda gasta 3 lenhas: 12 ao todo. É a queixa do playtest de
   08/10.
3. **A dívida do Tonho zera sem pagamento.** O 3D não tem livro de fiado: o
   passo é só chegar à venda, e o seguinte diz que zerou.
4. **A mesma dívida é paga duas vezes.** A fila do Tonho a zera com 1.900 réis,
   e o favor do Seu Nicolau a risca de novo por três peixes.
5. **O Cosme "embarca", e o saveiro e o Cosme não colaboram.** A Dona Zefa diz
   "amanhã tem saveiro", mas ele só vem no dia 14. O Cosme nunca sai do vale e
   segue na roça, na capoeira e nos mutirões.

### Padrões que se repetem

- **Anúncio em terceira pessoa na boca do próprio morador.** Nove favores abrem
  como narrador ("Zacarias toca o sino às seis..."), e oito passos curtos fazem o
  mesmo ("Diga ao guarda o que ouviu", dito pelo guarda).
- **Conversa que não muda com o que o jogador fez.** A dívida do Tonho segue
  "devendo" depois de paga; o convite é comentado no dia 1, antes de chegar, e
  depois da fazenda; o Damião segue "sem foice"; a Sá Rita pede o mutirão do
  poço que já aconteceu no dia 1.
- **Primeiro encontro que repete para sempre.** Os sete moradores antigos têm só
  três falas, que também são o cumprimento, e três delas são apresentações.
- **Resposta de oferenda dita de longe.** O código põe a resposta na boca do
  dono da fila, onde ele estiver. A Sá Joaquina descreve a onda levando a ostra
  sem estar na praia, e a Dona Estefânia, a toalha na mesa da casa do jogador.
- **Pistas da fazenda sem gatilho de tempo.** A pedra atrás do altar, a madeira
  com letra e a luz na água podem tocar depois do capítulo 7, quando a fazenda
  já acabou.
- **Promessas sem mecânica.** Terra dada pelo Tonho, terra comprada pela divisa
  e o livro de fiado não existem no 3D.
- **A linha do tempo da chegada.** A travessia faz o jogador chegar ao meio-dia;
  a partida começa às 6h30.

### Detalhes de história

O Pedro diz "minha mãe" no mungunzá, mas no resto do jogo é a avó. O convite vem
"do mural da praça", mas estava preso na porta. São "seis" no salão, e com o
jogador são sete. O Pedro pede para o jogador "ficar fora" e logo o leva para
dentro. Duas irmandades cuidam do cemitério. O Tonho "remenda rede", mas não tem
rede. Há "fôlego" para a reserva do dia e para o ar do nado.

### Tradução

32 falas das filas que vieram do 2D (Filó, Zefa, Candinha, Tonho, o começo do
Damião e o mirante) estão só em português, e as três broncas do Damião moram no
código, só em português.

### Áudio

- **Nenhum texto de TTS está desatualizado.** Toda fala gravada bate com o texto
  de hoje.
- **Faltam 320 falas faladas.** Quase todas são de missão: 154 anúncios, 63
  respostas, 43 avisos de fila trancada e 41 falas de cena. O Pedro sozinho tem
  20 mil letras a gravar.
- **Nove falantes não têm voz definida.** São o mestre Quirino, as quatro
  personagens das cenas da fazenda e do revoar e as três vozes da fé. A moça da
  fazenda e a do revoar são a mesma personagem e pedem a mesma voz.
- **Quatro áudios do Pedro não são usados por fala nenhuma.** São de passos
  antigos da chegada: `pedro_pier`, `pedro_praca`, `pedro_capela` e
  `pedro_casa_pasto`.
- **Vozes da biblioteca padrão do ElevenLabs.** Dez dos moradores novos usam
  vozes nativas em inglês (Chris, Brian, Will, Lily, Jessica, Eric, Liam, Laura,
  Charlie, River): vale ouvir o sotaque no português antes de gerar o resto.

### O que confere

- **As quantidades.** Os números ditos batem com a mecânica: os trinta e seis
  paus da ponte, as doze tábuas, os cinco maços, as três lenhas por corda, as
  duas raízes por farinha, o facão de duas lenhas e uma pedra.
- **Os preços e as regras.** O saveiro paga 34 réis o feixe e a venda 14, a
  fé leva de cada dez um e meio, e o rito é semanal.
- **As teclas.** O F come na mochila, o K abre a teia, o P o arraial e o V a
  ginga.
- **A geografia e os bichos.** A ponte fica ao norte, depois da casa, e o
  mirante e o terreiro a poente; os gatos, o jumento e o cachorro que os
  moradores citam existem.
- **Os capítulos.** As cenas da fazenda e do revoar seguem os capítulos 6 e 7 de
  perto, com o jogador somado ao Pedro.

## Decisões que são do autor

- **O Cosme fica ou vai para Salvador?** Indo, o jogo precisa tirá-lo do vale e
  dar as filas dele a outro morador.
- **O 3D terá terras e fiado?** Sem eles, as falas do Tonho, da chapada e da Zefa
  param de prometer.
- **Qual caminho paga a dívida do Tonho?** A fila dele ou o favor do Nicolau.
- **As cenas e as vozes da fé ganham voz?** E qual voz o mestre Quirino recebe?
- **As pistas da fazenda têm prazo?** Ou ganham uma versão de depois do
  capítulo 7.

## O que ficou de fora

Textos que não são fala: os avisos do HUD, as perguntas do sistema (a cama, o
comer, o pacto), os textos dos marcos da fé fora da visita, as inscrições das
lápides, as cartas achadas e os nomes de itens. Os papéis lidos (o convite, a
lista de nomes, a madeira lavrada, a carta da filha da Dona Rosa) estão no
documento, sem voz.
