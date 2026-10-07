# Composição autoral do mundo 3D

Decisão do autor em 29/09/2026. Este documento define a direção de longo prazo
para editar o vale no Godot. Ele não descreve uma migração já concluída: enquanto
ela não acontecer, o gerador e os dois estilos continuam obedecendo às regras do
estado atual registradas em [VALE_VIVO_3D.md](VALE_VIVO_3D.md).

## Princípio

O KML é uma **fonte de importação e referência geográfica**, não o dono permanente
de todos os objetos do mundo. Ele serve para criar ou atualizar a base territorial:
escala, relevo, costa, rios, ruas, áreas e pontos geográficos relevantes. Depois da
primeira montagem, o vale passa a ser também uma composição autoral editável no
Godot.

Casas novas, árvores, postes, bancos, placas, NPCs, objetos de cena e outros
detalhes não precisam nascer nem continuar representados no KML. A ausência de um
objeto no KML não autoriza removê-lo do jogo.

O fluxo desejado é:

1. importar o KML para estabelecer ou atualizar a referência geográfica;
2. usar automação e IA para propor uma estrutura inicial ou fazer trabalho em lote;
3. abrir o resultado no editor do Godot;
4. selecionar, mover, girar, duplicar ou remover visualmente os objetos;
5. salvar esses ajustes como parte durável do projeto.

A IA ajuda a construir; ela não deve ser a única interface para mover um poste ou
uma árvore.

## Fontes de verdade separadas

O mundo deve ser dividido em duas camadas, com responsabilidades explícitas:

| Camada | Fonte de verdade | Exemplos |
|---|---|---|
| Base geográfica importada | KML e seus derivados | relevo, costa, rios, ruas, limites e áreas de referência |
| Composição autoral | cenas e recursos editáveis no Godot | casas, árvores, postes, adereços, NPCs, pontos de interação e câmeras |

Uma reimportação do KML pode atualizar a base geográfica, mas **não pode apagar,
recriar por cima nem reposicionar silenciosamente a composição autoral**. Conflitos
devem ser mostrados para revisão humana. A separação também permite atualizar o
terreno sem perder semanas de composição visual.

Pontos do KML podem originar marcadores na primeira importação. Depois que um
marcador for promovido à composição autoral, sua transformação salva no Godot passa
a prevalecer até que o autor escolha realinhá-lo com a referência geográfica.

## Experiência de edição desejada

Os elementos autorais devem existir em uma cena editável, organizada por função,
por exemplo:

```text
ComposicaoDoVale
├── Construcoes
├── VegetacaoAutoral
├── Iluminacao
├── Aderecos
├── Personagens
├── PontosDeInteracao
└── Cameras
```

O editor precisa mostrar contexto geográfico suficiente para que o autor possa
compor visualmente. Uma prévia do terreno, dos rios, das ruas e das construções
principais deve poder ser gerada ou atualizada no editor. Objetos únicos devem ser
selecionáveis pelo nome e manipuláveis com as ferramentas normais de transformação
do Godot.

Árvores também fazem parte desse objetivo. A geração automática pode criar uma
distribuição inicial ou preencher mata distante, mas o autor deve poder reposicionar,
remover e acrescentar árvores importantes. Convém distinguir:

- vegetação de preenchimento, que pode continuar em lote por desempenho;
- vegetação autoral, editável individualmente perto de caminhos, casas, marcos e
  áreas narrativas.

Se uma árvore gerada for transformada em elemento autoral, ela deixa de pertencer
ao lote regenerável para não reaparecer ou ser sobrescrita na próxima geração.

## Tripo e o procedural

Os modelos do Tripo são a direção visual do produto. O estilo procedural foi uma
prova inicial e pode ser retirado no futuro, depois que os equivalentes Tripo
necessários estiverem aprovados e a migração tiver portões de segurança.

Até essa retirada acontecer:

A resolução da #46 em 07/10/2026 aplica a decisão de 29/09 ao `AGENTS.md`,
ao plano e aos critérios das issues #5, #17, #26, #27 e #29. Testar os sistemas
que já existem nos dois estilos protege o legado; isso não obriga a criar uma
segunda peça de arte para cada GLB novo.

- o procedural continua sendo estado legado funcional, não uma frente de arte;
- não se produz arte procedural nova para acompanhar cada asset Tripo;
- não se remove o fallback em uma mudança incidental;
- a retirada deve ser uma tarefa própria, verificando cenas, preferências salvas,
  catálogo, testes, carregamento e desempenho.

A composição autoral não deve depender da implementação visual. Uma posição salva
para uma casa, poste ou árvore deve referenciar uma identidade de catálogo; enquanto
existirem dois estilos, o sistema resolve a representação disponível. Depois da
retirada do procedural, a mesma composição continua válida usando apenas os GLBs
aprovados.

## Papel do código depois da migração

O código continua responsável pelo que é sistemático: importar a geografia, ajustar
objetos ao relevo, carregar por distância, aplicar LOD, criar colisões, controlar o
ciclo do dia e instanciar grandes lotes. Ele não deve esconder em vetores numéricos
as decisões visuais que o autor precisa revisar frequentemente.

Em particular, posições de casas, postes, árvores autorais e pontos narrativos não
devem permanecer espalhadas como `Vector3` dentro de `world_builder.gd`. O gerador
deve ler a composição salva, não substituir o trabalho do editor.

## Migração sugerida

1. Criar uma prévia editável da base geográfica no editor.
2. Criar a cena de composição autoral e definir identificadores estáveis.
3. Extrair do `world_builder.gd` os objetos únicos atuais para essa cena, preservando
   exatamente suas posições.
4. Separar vegetação de preenchimento e vegetação autoral.
5. Fazer a reimportação do KML atualizar somente a camada geográfica.
6. Validar salvamento das cenas, desempenho, navegação, colisões e os mapas do menu
   e do jogo.
7. Quando a cobertura Tripo estiver completa, retirar o estilo procedural numa
   tarefa dedicada.

O critério de sucesso não é apenas o jogo continuar igual. O autor deve conseguir
abrir o Godot, localizar um objeto pelo nome, movê-lo visualmente, salvar e ver a
mudança no jogo sem editar coordenadas em GDScript e sem depender da IA.

## Casas e ruas no editor — 04/10/2026 (#57)

Abra `scenes/prototipo_3d/composicao_vale.tscn` no Godot. A cena reúne as quinze
construções atuais (incluindo igreja, capela, venda e restaurante), com os GLBs
do catálogo, e mostra o terreno e as oito ruas como referência. Expanda **Casas**,
selecione o nó com o nome da construção, mova ou gire no eixo Y e pressione
**Ctrl+S**. Execute o projeto normalmente: o jogo lê a posição salva nessa cena,
reconstruindo as colisões, alicerces, interações e âncoras naquele lugar. A altura Y
salva também é respeitada no Tripo; ajuste-a ao chão ao mover para outro declive.

Mova o nó da casa, não o filho `Visual`. Os identificadores, chaves do catálogo e
referências iniciais devem ser preservados. A etapa atual cobre deslocar e girar
as construções existentes; escala, inclinação, inclusão e remoção de construções
exigem ampliar o contrato de composição. O legado procedural mantém seu próprio
apoio e orientação inicial, aplicando o deslocamento e giro relativos da autoria.

A mesma cena textual `.tscn` é editável por código/IA: sua transformação salva é
a fonte de verdade para posição e giro. Não há um segundo arquivo de coordenadas
para sincronizar, e `world_builder.gd` não procura outro lote para a casa movida.
Os GLBs e suas colisões continuam sendo resolvidos pelo catálogo existente.
O visual é instanciado pelo catálogo somente na prévia do editor; ler as posições
na partida não carrega uma segunda cópia de terreno, ruas ou modelos. Os lotes
autorais são preservados mesmo quando a geografia importada tem menos ruas.

Terreno e ruas são **referências da base geográfica**, carregadas pelo script
`@tool` somente dentro do editor. Nesta etapa, editar a referência das ruas não
altera seu traçado no jogo: o traçado continua vindo dos dados geográficos. A
referência está em `scenes/prototipo_3d/ruas_referencia.tscn`. Não mova essas malhas
para tentar editar a rua de uma partida.

`tools/mapas/extrair_composicao_vale.gd` fez a primeira extração usando o próprio
mundo Tripo. Ele recusa sobrescrever uma composição já existente. Regenerar
`terreno_editavel.tscn` não altera `composicao_vale.tscn` nem reposiciona casas.
A prévia em `abertura.tscn` e `vale.tscn` mostra essa composição; para editar e
salvar a autoria, abra a cena `composicao_vale.tscn` diretamente.

O portão `tests/composicao_vale.gd` move e gira uma casa numa cena temporária,
salva, reabre e constrói o mundo com ela; confere modelo, colisão, interação e
âncora, testa o giro do legado procedural e verifica que a cena original permanece
intacta. A falsificação `-- --falsificar-composicao` desliga a leitura no construtor:
o portão reprova a posição, giro, colisão, interação e âncora, saindo com código 1.
Mudanças perto do voo do menu também precisam passar `sobrevoo_livre` nos dois estilos; se o trajeto
colidir, replaneje-o pelo procedimento existente.

## Primeira prévia persistida do terreno — 30/09/2026

A primeira fatia dessa migração está em teste na issue #33. Somente a malha de
terra da região ativa é persistida em
`scenes/prototipo_3d/terreno_editavel.tscn`. Um host `@tool` leve
mostra essa cena no editor dentro de `abertura.tscn` e `vale.tscn`; em execução,
o arquivo pesado não é carregado e o `WorldBuilder` continua gerando o vale real.

Para atualizar a prévia depois de mudar KML, geometria, cenário ou escala:

```powershell
cd C:\VIRTUALENVS\myths-valley\myths-valley-3D
& 'C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe' `
  --headless --path . --script res://tools/mapas/gerar_terreno_editavel.gd
```

A escala horizontal continua em 1:4, mas o catálogo da região aplica
`vertical_exaggeration = 2.0` ao relevo. O jogo e esta prévia usam o mesmo valor,
mantendo malha, colisão e posicionamento dos elementos de cenário coerentes.

O arquivo pode ser aberto e inspecionado como cena no Godot. Nesta primeira
tentativa ele é uma `ArrayMesh` persistida, não um terreno esculpível por pincel:
é possível editar cena, transformação e material, mas mover vértices visualmente
exigirá uma ferramenta de autoria própria ou um terrain editor. Rodar o gerador
novamente substitui a malha persistida; portanto, até existir a separação entre
base importada e ajustes autorais, não guardar edição manual de vértices nela.
