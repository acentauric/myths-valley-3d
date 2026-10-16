# Posse e compra de terras no vale (#9, parcial)

O HEAD anterior tinha lotes das casas autorais, obras em pontos fixos e
compatibilidade opcional de save com Terrenos/Povoado do 2D. Nenhum deles
vendia terra. A observação da fila da chapada declarava essa ausência.

`Terras` é o provedor 3D de posse: não reinstala células, dívida de Tonho ou
trabalho do 2D. O roçado começa próprio. Zefa custa 1800 réis e Benedito 2600,
conforme `GeradorMundo.TERRENOS` em 62c0f14b; Benedito depende da posse de
Zefa, conforme a vizinhança histórica e a fala da chapada. Gente fina reduz
o preço da terra pela metade, preservando o consumidor histórico de
`favor_mais_barato`. Não reduz materiais de oficina ou presentes.

A oferta entra no E com Zefa/Benedito após `chapada_volta`, para não vender
antes da apresentação dessa possibilidade. Missões e presentes têm
prioridade. Sim confirma; Não não gasta. A compra revalida preço/saldo e
posse, não se repete e não remove casa, NPC, rotina ou recursos. A conversa
continua registrada na afinidade. O save leva `Terras.posses` pela tabela
declarativa existente, e uma vaga nova volta à posse inicial.

O mapa do jogo projeta contornos cadastrais pelas âncoras reais Lavoura,
Casa da Zefa e Chapada: verde para próprio, âmbar para vizinho, com nome e
dono. O roçado acompanha a grade nativa 6×4, passo 1,2; uma prova comparando
às constantes da lavoura reprovou as dimensões iniciais incorretas antes de
acertá-las. Zefa/Benedito adaptam as áreas históricas 12×16/14×16 para
24×32/28×32 unidades e orientação da âncora. Essa adaptação cadastral não
estende o KML, não reposiciona cercas e não aprova a geografia completa #22.

## Evidência

- `terras_por_posicao`: confirmação Sim/Não nativa, compra única, rejeição
  sem dinheiro/divisa, desconto, arquivo de save real, restauração e nova
  vaga, mapa com componente de divisas e dimensões/orientação 3D.
- `afinidade_interacao_3d`: continua verde, incluindo missão prioritária e
  ferramenta não oferecida como presente.
- `salvamento`, `vagas_no_jogo` e `mapa_fluxo`: verdes, respectivamente
  81/70/129 s, sem erro de script ou compilação. A cobertura de campos
  novos aceita a tabela declarativa real do Salvamento, em vez de exigir
  artificialmente que toda regra 3D more no estado gráfico do mundo.
- `--falsificar-favor` troca somente o consumo do bônus por zero em uma
  cópia de GDScript carregada em memória; duas assertivas reprovam. Nenhum
  arquivo vivo ou partida normal é modificado pelo falsificador.
- Perfis em `D:/MythsValleyPlaytestRuns/terras9`; nenhum serviço pago.

## O trabalho nas terras compradas (#9, Build 12)

A regra da aba Trabalho do 2D chegou em duas peças de `scripts/compartilhado/`, que perguntam ao
`Terras` de quem é cada lote e nunca guardam posse:

- `Terrenos`: o ofício de cada morador de um lote do jogador (roçado, lenha, farinha, cestaria,
  criação ou nada). O idoso (Dona Zefa, Seu Benedito, Dona Filó) não faz serviço de braço. A entrega
  ao amanhecer vai para a mochila, e o que não cabe espera no paiol.
- `Povoado`: quanto cada um rende, a única fórmula de produção. A perícia sobe com os dias de serviço
  (aprendiz, jeitoso, bom de serviço, mestre: x1,0 a x2,4), a amizade multiplica de x1,0 a x1,5, as
  cinco obras do arraial somam, os talentos Palavra de patrão e Mestre de ofício valem, e a fração
  que sobra de um dia vai para o outro.

Os ofícios, o ritmo do idoso e quem mora em cada lote estão em `data/terras_3d.json`; os degraus de
perícia, a amizade e as obras do arraial, em `data/povoado_3d.json`, tudo nos idiomas do jogo. O
save leva `Terrenos.trabalho`, `Terrenos.no_paiol`, `Povoado.pericia` e `Povoado.sobra` pela tabela
do Salvamento, vaga por vaga (a vaga nova volta à fábrica). Prova: `tests/unidade/test_terrenos.gd`
e `tests/unidade/test_povoado.gd`, cada regra com falsificação por `TESTAR3D_FALSIFICAR`, e a
virada da queda em `tests/salvamento.gd`.

Ainda não há tela: a aba Trabalho do painel, o morador no posto do lote, a troca do dia de roçado do
Cosme (`servico_do_morador.gd`) pela fórmula do Povoado, os lotes do Tonho e da Santa Casa e a
criação além do galinheiro ficam para os próximos pacotes da #9.

## O que ainda falta

#9 permanece aberta. O provedor não concede construção portátil nem
movimentação G/E com raycast: faltam validação espacial, persistência de
peças livres, recusas por rua/árvore/corpo e prova de assentamento físico.
A apresentação visual dos contornos no vale real também precisa de captura
e revisão. O caminho de favor da Zefa não concede terra automaticamente:
a fila atual dela termina no saveiro e não implementa o favor histórico
`favor_da_zefa`; essa adaptação não inventa um novo gatilho de missão.

Após esta integração, a auditoria estrita de talentos conserva quatro
consumidores pendentes, todos ligados à produção da #160: pastoreio,
pressa do curral, rendimento e perícia do morador. #18 continua aberta.
(Rendimento e perícia do morador já são lidos pelo `Povoado`, ver acima.)
