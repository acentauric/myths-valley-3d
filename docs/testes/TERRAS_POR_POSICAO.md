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
