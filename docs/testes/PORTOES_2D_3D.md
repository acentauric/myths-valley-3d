# Os contratos do 2D no vale 3D (#18)

Referência: `acentauric/myths-valley`, commit `62c0f14b`,
`tools/gdscript/testar_*.gd`. Lida no checkout local, sem baixar assets. O
snapshot tem 48 scripts: 47 portões funcionais e `testar_compartilhado`, que
mede paridade de arquivos entre projetos. A separação da issue é de 15
contratos reaproveitáveis e 32 perguntas que precisam de contexto 3D.

O nome “lógica pura” da issue não descreve todos os arquivos: amanhecer,
folheto, intro, menu, menu_interacao, povo e teia também verificam interfaces.
Portar é conservar a pergunta, usando o provedor e a interface deste projeto,
sem reinstalar autoloads ou cenas do 2D apenas para o teste passar.

## Inventário dos 15

| Contrato 2D | Portão/contrato 3D | Situação desta auditoria |
|---|---|---|
| afinidade | `regras_afinidade`, `afinidade_interacao_3d`, `teia_social` | Regras de gosto, teto diário, sinais e estado portadas. Cordel é documento presenteável no E atual; a lista fixa antiga era inadequada. |
| amanhecer | `amanhecer`, contador em `missoes` | Cartão, prazo e retorno da queda já migrados na #21. |
| divida | `fiado_tonho`, `livro_no_armazem` | Provedor 3D da #68 substitui Terrenos: pagamento limitado, rede diária, leitura, quitação e persistência. |
| escolha | `escolha` | Migrado na #21, incluindo proteção contra E repetido. |
| folheto | `folheto` | Migrado na #21: dez títulos, geometria, teclas e coleção. |
| fracoes | `regras_fracoes` | XP/fé/energia e JSON portados. Produção/sobras/perícia dos trabalhadores pendentes de Povoado/Terrenos 3D; este portão não aprova essa parte. |
| missoes | `missoes`, `missoes_elos`, `cadeia_das_missoes` | Alvos Vector3 já migrados; comparar foco por ID, herança da linha, equivalência dos materiais e ritmo das filas. |
| povo | `teia_social`, `afinidade_interacao_3d` | P, estados diários e confirmação já existem; os retratos e roteamento não usam ArraialTela/Controles do 2D. |
| receitas | `regras_receitas`, `painel_ingredientes` | Porta por missão lê os arquivos `data/missoes_*.json`, incluindo portas com alternativas. O balcão usa o painel 3D real. |
| slots | `salvamento`, `vagas_no_jogo`, `pontos_de_restauracao` | Separação, edição/apagamento e recuperação já têm gates 3D; conferir migração da partida antiga explicitamente. |
| talentos | `tools/prototipo_3d/auditar_talentos.gd`, `teia_talentos` | Auditoria estrita fora da bateria enquanto faltam consumidores; sem lista de exceções. Detecta efeitos declarados sem mecânica 3D; não está aprovada. |
| teia | `teia_talentos`, `navegacao_da_teia` | Nós, custos, pais e mouse já têm gates; viagem com deduplicação do losango/atalho Espaço do 2D não deve ser presumida pela aparência. |
| intro | `nome_do_viajante`, `tela`, `smoke_opening` | Nome, narrativa e abertura têm gates. Conferir cancelamento, movimento reduzido e preservação da vaga. |
| menu | `sobrevoo_menu`, `menu_pausa`, `interfaces_secundarias` | Lobby 3D usa cenas e controles próprios; não se porta a antiga árvore de nós literalmente. |
| menu_interacao | `nome_do_viajante`, `vagas_no_jogo`, `mapa_fluxo` | Entrada real e navegação precisam de prova na janela; callbacks isolados não substituem esse contrato. |

Esta tabela é um inventário, não uma declaração de quinze portões verdes. A
issue permanece aberta até completar a equivalência e executar todos os
contratos no HEAD final. Resultados e limites são registrados abaixo.

## As 32 perguntas que passam a ser 3D

| Portão funcional 2D | Pergunta para o vale 3D |
|---|---|
| arraial | As cadeias dos moradores abrem pelo E correto, mantêm a ordem e só concluem após eventos físicos e entregas reais? |
| assentamento | Casas, terrenos e ocupação ficam coerentes após construir, salvar, sair e retornar à região? |
| bussola | O marcador aponta o alvo físico elegível, respeita interior/soleira e desaparece após chegada ou cumprimento? |
| cartas | A carta correta pode ser encontrada, lida, relida e persistida sem consumir indevidamente o E do mundo? |
| colisao | O corpo passa por portas e pontes, contorna sólidos e encontra chão compatível com navegação, escala e relevo? |
| combate | Alcance e contato do golpe 3D respeitam arma, direção, custo, dano e obstáculo entre atacante e alvo? |
| comidas | Comer o item escolhido devolve os valores e efeitos previstos, sem tomar o E de um alvo de trabalho? |
| cordeis | Cada folheto está numa posição alcançável e identificável, sem concorrer indevidamente com moradores ou colisões? |
| coveiro | O cemitério, a foice e seus alvos físicos permitem cumprir toda a cadeia e conservar o reparo no save? |
| criaturas | Espécies nascem em áreas apropriadas, rondam e atacam no solo/água corretos e deixam coleta acessível? |
| fe | Os três marcos são alcançáveis; rito, escolha e migração usam o E e a tela corretos e preservam consequências? |
| interiores | Entrar e sair usa o vão real, mantém câmera, colisão e foco e não ativa outro interior próximo? |
| lugares | Nomes e âncoras do mapa resolvem posições Vector3 reais, incluindo os lugares ainda ausentes explicitamente? |
| luta | Aviso, esquiva, bote e contato acompanham tempo e distância reais, sem atingir através de cenário sólido? |
| mao | A seleção visível corresponde ao item usado, equipado ou comido, inclusive ao trocar telas e ferramentas? |
| mata | A mata distingue terreno, folhagem e troncos, permite circulação e conserva encontros/coletas sem obstrução visual enganosa? |
| moradores | Cada NPC segue a rotina, alcança seus postos e mostra fala/nome/interação apenas no contexto e na prioridade apropriados? |
| mundo | A composição autoral tem uma única fonte de âncoras/escala, carrega íntegra e não mistura Tripo e procedural? |
| obras | Materiais e planos exigidos geram uma alteração física persistente, com entrada/circulação e efeito real da obra? |
| oficios | A ferramenta elegível atinge a fonte real, gasta energia no impacto e produz item/experiência uma única vez por ação? |
| pedro | O guia espera o carregamento, acompanha o jogador por rotas físicas e encerra falas/objetivos sem bloquear a campanha? |
| pesca | Linha, superfície e janela de ferrar funcionam na água real e a captura preserva quantidade, custo e estado? |
| plantio | Arar, plantar, regar, crescer e colher usam o mesmo leito físico, estados persistentes e orientações claras? |
| povoado | Os trabalhadores designados produzem sem perder frações e suas rotinas/resultados persistem quando a área está distante? |
| praia | Areia, maré, embarcação e píer oferecem uma borda navegável e visualmente coerente sem atravessar a água como chão? |
| recusas | Alvo/ferramenta/nível/energia incorretos recusam claramente, preservando itens, progresso e foco da interação certa? |
| relevo | Inclinação, rampas e alturas físicas permitem subir, nadar e sair da água por trajetos previstos, sem confiar só na navmesh? |
| salvamento | Salvar e restaurar recompõem estado e posição segura do vale, sem misturar vagas nem restaurar referências de nós antigos? |
| sinais | Avisos e sinais surgem pelo evento adequado, expiram e respeitam a matriz de prioridade e oclusão da interface? |
| terrenos | Posse, dívida, construção e trabalhos designados pertencem ao terreno correto, com limites e acesso físicos claros? |
| vida | Dano, queda, sono e recuperação mantêm suas contas e retornam o controle e a câmera sem prender o jogador? |
| zefa | Conversa, entrega, ervas e fé da Zefa abrem na ordem certa, com alvos atingíveis e efeitos persistidos? |

O gate de paridade `testar_compartilhado` continua sendo uma auditoria técnica
separada; ele não é a 33ª pergunta de gameplay.

## Evidências de 07/10/2026

- `regras_afinidade`: verde, 22 moradores. O teste consulta a elegibilidade do
  controlador de E atual; não aprova automaticamente todo item do catálogo.
- `afinidade_interacao_3d`: verde com confirmação real Sim/Não para cordel
  apreciado pelo guarda, consumo de um item e ferramenta preservada.
- `regras_fracoes`: verde para os acumuladores atuais e carregamento JSON;
  trabalhadores/sobras continuam explicitamente pendentes.
- A rodada dos quinze contratos roda todos os gates, com paralelo 2:
  quatorze verdes e a auditoria estrita de talentos vermelha. Verde aqui
  não aprova partes históricas que ainda dependem de provedores ausentes.
- Nove consumidores estavam ausentes. Esta fatia liga `passo` à velocidade
  com o cansaço preservado, `lenha_a_mais` ao corte concluído e aceito,
  `faro_de_cordel` ao alcance dos cordéis sem mudar cartas, e `vista_do_alto`
  à distância de referência da câmera no topo físico da Lombada. A esfera,
  paredes e projeção continuam limitando o braço; o zoom escolhido não muda.
  Outros altos naturais ainda precisam de classificação própria para vista.
- A auditoria estrita agora acusa cinco campos: `favor_mais_barato`,
  `pastoreio`, `pressa_do_curral`, `rendimento_do_morador` e
  `pericia_do_morador`. Favor é desconto do preço da terra, conforme o
  consumidor histórico, e depende de #9/#22. Não reduz custo da oficina.
  #160 estava fechada sem produtores, fila ou pagamento equivalentes no HEAD;
  foi reaberta com inventário de comportamento. Conferido em 10/10: a fila do
  quintal, o galinheiro com os ovos e o dia de roçado do Cosme estão no código
  (`curral_vale.gd`, `missoes_quintal.json`, `tests/quintal.gd`). Faltavam os
  leitores dos quatro campos: `pastoreio` (galinheiro), `pressa_do_curral`
  (postura adiantada) e `rendimento_do_morador`/`pericia_do_morador`
  (pagamento do passo `capataz_manha`, `servico_do_morador.gd`), agora
  cobertos por `tests/producao_do_quintal.gd`.
- `consumidores_dos_talentos` reproduz três falhas com fontes anteriores do
  commit c022e0f carregadas em memória. Desligar passo/lenha/faro provoca
  2/1/1 falhas. Falsificadores de foco, porta de receita, fração e gosto
  também reprovam. `vista_do_alto` verifica a referência e parede física;
  retirar seu talento provoca duas falhas.
- Sete gates locais ficam verdes após as alterações: afinidade real,
  consumidores, regras de afinidade/fração/foco/receita e vista do alto.
- `camera_resiliente` (Tripo, 210 s), `corte_das_arvores` (59 s) e
  `achados_no_vale` (54 s) passam após os consumidores; nenhum erro de
  script/compilação. A vista também passa sem GLB do viajante, na fixture
  geométrica procedural, e seu mutante reprova as duas assertivas previstas.
- `regras_receitas`: a primeira execução com a lista de arquivos do 2D
  reprova referências existentes do 3D. Após ler as filas atuais e alternativas
  de missão, resta a expectativa antiga `coveiro_foice`: a cadeia atual recebe
  a foice após juntar lenha para o cabo, sem fabricar tábuas/corda nesse passo.

Perfis e temporários desta rodada ficam em
`D:/MythsValleyPlaytestRuns/portoes18`, sem tocar partidas normais. Runner
direcionado com `-Paralelo 2`; nenhuma bateria completa ou API paga.
