# As falas de Myths' Valley 3D

Todas as falas que o jogo diz, num documento só, etiquetadas para validar o texto
e para servir de referência à geração de áudio. Feito em 08/10/2026 e corrigido no
mesmo dia: o que a revisão apontou foi corrigido no jogo e anotado aqui (ver
[As correções de 08/10](#as-correções-de-0810)).

| Arquivo | O que é |
|---|---|
| [`FALAS.xlsx`](FALAS.xlsx) | O documento. Abre no Excel, no LibreOffice e no Google Planilhas. |
| [`FALAS.csv`](FALAS.csv) | A aba principal em texto, para comparar versões e para ferramentas. |
| [`analise_das_falas.json`](analise_das_falas.json) | A revisão: o que se achou em cada fala, por ID, e o que se fez. |
| [`audios_gravados.json`](audios_gravados.json) | O texto de cada áudio no dia em que foi gravado. |
| [`../../tools/falas/`](../../tools/falas/) | O gerador, que lê as falas de onde o jogo as lê. |

## As abas do documento

- **Falas**: uma linha por fala, na ordem da história, com 40 colunas em nove
  grupos: identificação, linha do tempo, quem e como toca, contexto de mecânica,
  textos nos quatro idiomas, áudio, checagens automáticas, análise e validação.
  A coluna **Status da validação** tem lista de escolha para o time marcar.
- **Problemas**: as falas em que a revisão achou alguma coisa. As que estão em
  aberto vêm primeiro, da prioridade alta para a baixa; as resolvidas ficam
  depois, com o problema, a correção e a observação do que se fez.
- **Alertas automáticos**: o que o gerador acha sozinho e ainda não foi revisto.
- **Áudios a regravar**: as falas com voz gravada cujo texto mudou depois da
  gravação, com o texto que o áudio ainda diz e o texto de hoje.
- **Personagens**: por quem fala, a voz do ElevenLabs, quantas falas, quantas
  já têm áudio, quantas faltam, quantas regravar e quantas letras (o tamanho em
  créditos).
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

Quando muda o texto de uma fala que tem voz, o áudio continua apontado para o
arquivo de antes: a voz antiga toca com o texto novo até a regravação, e a fala
entra na aba **Áudios a regravar**. Depois de gravar de novo,
`--fotografar-audios` guarda o texto de cada gravação de hoje.

## Os números

| | Falas |
|---|---|
| No documento | 1.293 |
| Tocam no 3D | 661 |
| Herdadas do 2D, que o 3D não diz | 632 |
| Com voz gravada | 229, das quais 22 com o texto antigo (a regravar) |
| Faladas e ainda sem áudio | 322 (57 mil letras, perto de 68 minutos) |
| Com problema apontado na revisão | 85, mais 2 observações: 83 corrigidas, 3 mantidas, 1 com o autor |

As 632 herdadas do 2D são os assuntos e as reações a presente do
`aldeoes.json` e o tutorial antigo do `pedro.json`: o 3D lê desses arquivos só o
gosto de presente, a travessia e nada mais. Ficam no documento marcadas como
"não toca", para ninguém gerar voz para elas.

## As correções de 08/10

Pedido: "faça todas as correções, tanto na tabela quanto no jogo. Se isso for
impactar uma fala com áudio, sinalize". Foram cinco levas no jogo, cada uma com os
portões dela, e a análise de cada fala ganhou o status (**corrigida** ou
**aprovada**) e a observação do que se fez, com o problema e a correção sugerida
guardados como histórico.

1. **A abertura e as lições do Pedro.** A travessia atravessa a noite (sai com a
   maré da meia-noite, chega com o dia clareando); o nado tem o **ar**, e não o
   fôlego (o rótulo do HUD e o aviso da água funda também); a pedra do poço e a
   da carroça vêm das pedras soltas; o Tonho é apresentado de linha na mão; a
   ponte ensina o E; o mungunzá é da avó; a lombada fica depois da chapada; a
   chapada não promete compra de terra.
2. **As filas dos moradores.** A Dona Filó, a Dona Zefa, a Dona Candinha, o
   Tonho e o começo do Damião em inglês e espanhol; o Cosme fica; a conta do
   Tonho paga em réis; o livro do Nicolau com o Damião de devedor; a foice só a
   quem não tem; o cercado do cemitério com as doze lenhas.
3. **Os favores e os arcos.** Os nove favores e os anúncios curtos na primeira
   pessoa; a cor do rio dita pela Sá Rita; as pistas da fazenda que valem antes e
   depois do capítulo 7; a pedra pintada; a roda sem a maré; o mirante em inglês
   e espanhol.
4. **A fazenda e o revoar.** O convite da porta, quem mais apareceu, sete com o
   jogador, o Pedro que chama o jogador para dentro, a manhã na casa e a conta da
   Matinta como coisa que se diz.
5. **As conversas dos moradores.** Dezoito conversas e cumprimentos que
   envelheciam (a dívida, a rede, a foice, o mutirão do poço) ou chegavam cedo
   demais (o convite antes do dia 2, a apresentação a cada conversa), nos quatro
   idiomas.

Antes delas, duas correções pediram código: a entrega de um passo `levar` aceita
réis da bolsa (`CadeiaDeMissoes.REIS`), e a resposta de uma oferenda (a ostra na
areia, a toalha na mesa) é aviso do HUD, sem nome, e não fala do dono da fila
dita de longe. As broncas do Damião saíram do código para
`data/lapides_3d.json`, nos três idiomas.

### Decisões assumidas (a confirmar com o autor)

- **O Cosme fica.** A Dona Zefa deixa a escolha com ele, e o último passo da fila
  dela é falar com o mestre Quirino no píer no dia do saveiro (dia 14): o menino
  lhe deu uma carta para o primo e ficou. A conversa dele que fala em ver
  Salvador "ainda" foi mantida. Se o Cosme for embora, o jogo precisa tirá-lo do
  vale e passar as filas dele a outro morador.
- **O vale não tem terras.** O fim da fila do Tonho é o primeiro peixe da rede
  nova (um robalo), e não a terra do outro lado da estrada; a chapada do Seu
  Benedito é para olhar, sem compra pela divisa.
- **A conta do Tonho se paga na fila dele**, com 1.900 réis levados ao Seu
  Nicolau. O livro de fiado do Nicolau passou a ter o Damião como devedor.
- **As pistas da fazenda não têm prazo**: o texto delas vale antes e depois do
  capítulo 7.
- **Levar o escudo da Matinta não tem consequência**: a ameaça fica como lenda.

### Áudio a regravar

Vinte e duas gravações ficaram com o texto antigo. A geração é paga e não foi
feita; até lá, a voz antiga toca com o texto novo.

| Fala | Arquivo |
|---|---|
| A travessia, trechos 5, 6 e 7 | `narracao/travessia/trecho_05.mp3` a `trecho_07.mp3` |
| O Pedro explicando o nado | `vozes/pedro_corpo_nado.mp3` |
| O Benedito, a Dona Zefa e o Cosme, primeira conversa | `benedito_fala_1`, `zefa_fala_1`, `cosme_fala_1` |
| O Tonho, primeira e segunda conversa | `tonho_fala_1`, `tonho_fala_2` |
| A Dona Filó e o Damião, segunda conversa | `filo_fala_2`, `damiao_fala_2` |
| A Dona Candinha, primeira e terceira conversa | `candinha_fala_1`, `candinha_fala_3` |
| O padre, quarto cumprimento e sétima conversa | `padre_saudacao_4`, `padre_fala_7` |
| O sacristão, o guarda e o pescador, quarta conversa | `sacristao_fala_4`, `guarda_fala_4`, `pescador_fala_4` |
| O mercador, a lavadeira e a quituteira | `mercador_fala_2`, `lavadeira_fala_7`, `quituteira_fala_4` |
| A Mariinha, quarto cumprimento | `menina_saudacao_4` |

A travessia é uma tomada só: regravar é rodar
`tools/elevenlabs/gerar-travessia.ps1 -Narracao` e cortar de novo com
`alinhar_travessia.py`. As conversas saem de
`tools/elevenlabs/gerar-falas-moradores.ps1` e a explicação do nado de
`gerar-falas-do-guia.ps1`, com o texto do campo `tts` quando ele existe. Os dois
só geram o arquivo que falta: para regravar só estas falas, sem pagar pelas
outras, tire os arquivos antigos delas e rode o script sem `-Forcar`. Depois,
`node tools/falas/gerar_documento_das_falas.js --fotografar-audios` guarda o
texto novo das gravações.

### Ainda com o autor

- **"O mangue é a cozinha de Iemanjá"** (a Dona Rosa, na farinha, na maré das
  cinco e na roda): no candomblé, lama e mangue costumam ser de Nanã, e Iemanjá é
  do mar. Pode ser escolha da comunidade dela.
- **A lista do papel dos nomes** não tem o Pedro nem as crianças, e é o Pedro
  quem entra no quarto.
- **A roda da praia não aparece na tela**, e a água do rio grande não fica
  avermelhada: as falas não dizem mais o que o jogador vê, mas o mundo ainda não
  mostra.
- **As vozes que faltam definir**: o mestre Quirino (que agora diz também o fim
  da fila da Zefa), as quatro personagens das cenas da fazenda e do revoar (a moça
  da fazenda e a do revoar são a mesma, e pedem a mesma voz) e as três vozes da
  fé.

## O que a revisão encontrou

A revisão leu as 659 falas em uso na ordem da história, contra os capítulos 6
e 7, os documentos do projeto e os dados do jogo: receitas, alvos, lugares,
horários e teclas. Tudo o que está nesta seção foi corrigido em 08/10, menos o
que ficou em [Ainda com o autor](#ainda-com-o-autor).

### Prioridade alta: ensinava errado ou quebrava a história

1. **A pedra do poço mandava ao lajedo**, que pede picareta de aço e o talento
   Mão de pedra. O mesmo na carroça do Seu Benedito.
2. **O cercado do cemitério não dizia que corda é lenha.** A obra pede 6 lenhas
   e 2 cordas, e cada corda gasta 3 lenhas: 12 ao todo. Era a queixa do playtest
   de 08/10.
3. **A dívida do Tonho zerava sem pagamento**, e **a mesma dívida era paga duas
   vezes**, na fila dele e no favor do Seu Nicolau.
4. **O Cosme "embarcava"** num saveiro de amanhã, que só vem no dia 14, e não
   saía do vale.

### Padrões que se repetiam

- **Anúncio em terceira pessoa na boca do próprio morador.** Nove favores abriam
  como narrador, e oito passos curtos faziam o mesmo.
- **Conversa que não mudava com o que o jogador fez**: a dívida do Tonho, o
  convite comentado no dia 1, o Damião "sem foice", o mutirão do poço pedido
  depois de feito.
- **Primeiro encontro que repetia para sempre** nos moradores antigos, que têm
  só três falas.
- **Resposta de oferenda dita de longe** pelo dono da fila.
- **Pistas da fazenda** que podiam tocar depois do capítulo 7.
- **Promessas sem mecânica**: terra dada, terra comprada e o livro de fiado.
- **A linha do tempo da chegada**: a travessia fazia o jogador chegar ao meio-dia,
  e a partida começa às 6h30.

### Detalhes de história

O mungunzá era da "mãe" do Pedro, e no resto do jogo é a avó. O convite vinha "do
mural da praça", e estava preso na porta. Eram "seis" no salão, e com o jogador
são sete. O Pedro pedia ao jogador para ficar fora e logo o levava para dentro.
Duas irmandades cuidavam do cemitério. O Tonho "remendava rede" sem ter rede. E
"fôlego" era a reserva do dia e o ar do nado ao mesmo tempo.

### Tradução

As filas que vieram do 2D (Filó, Zefa, Candinha, Tonho, o começo do Damião e o
mirante) e as três broncas do Damião estavam só em português. Desde 08/10 estão
nos três idiomas, e o portão dos idiomas as cobra.

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

### O áudio além das correções

- **Faltam 322 falas faladas.** Quase todas são de missão: 154 anúncios, 65
  respostas, 43 avisos de fila trancada e 41 falas de cena. O Pedro sozinho tem
  20 mil letras a gravar.
- **Quatro áudios do Pedro não são usados por fala nenhuma.** São de passos
  antigos da chegada: `pedro_pier`, `pedro_praca`, `pedro_capela` e
  `pedro_casa_pasto`.
- **Vozes da biblioteca padrão do ElevenLabs.** Dez dos moradores novos usam
  vozes nativas em inglês (Chris, Brian, Will, Lily, Jessica, Eric, Liam, Laura,
  Charlie, River): vale ouvir o sotaque no português antes de gerar o resto.

## O que ficou de fora

Textos que não são fala: os avisos do HUD, as perguntas do sistema (a cama, o
comer, o pacto), os textos dos marcos da fé fora da visita, as inscrições das
lápides, as cartas achadas e os nomes de itens. Os papéis lidos (o convite, a
lista de nomes, a madeira lavrada, a carta da filha da Dona Rosa) estão no
documento, sem voz.
