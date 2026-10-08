# Plano do Myths' Valley 3D

O jogo 3D é mantido em `acentauric/myths-valley-3d`, com seu projeto Godot na
raiz. O jogo 2D segue sua própria linha em `acentauric/myths-valley`.

## O que já roda

A galeria #78 foi conferida por edição/navegação/voz reais e seis capturas.
A medição A/B do LOD #34 reduz triângulos nas três câmeras da GTX 1660 Ti;
o encerramento aguarda a bateria final: [GALERIA_E_LOD.md](../testes/GALERIA_E_LOD.md).

O orçamento gradual de #155 respeita a presença de visitas no calendário.
Quirino chega/parte no dia 14 sem placa fantasma, e a entrega prioritária
não é bloqueada por uma saudação. Saveiro, apresentação e balões passam;
forçar a visita fora do dia reproduz duas falhas.
Liberar o elenco completo também persiste ao recalcular a visita, sem
revogar a ausência de Quirino fora do calendário. Gate e mutante conferidos.

A #138 tem acabamento irregular na extremidade marítima da areia, com
prova gráfica e passagem/maré preservadas. A foz mantém emendas e impede
fechar a issue: [TRANSICAO_DA_COSTA.md](../testes/TRANSICAO_DA_COSTA.md).

A #9 avança parcialmente com compra/posse nativas: Zefa/Benedito, preços
históricos, confirmação pelo E, desconto de favor na terra e persistência
por vaga. O mapa mostra contornos cadastrais por âncora; a vila não se move.
Compra, afinidade, save, vagas e mapa passam; retirar o consumidor de favor
reprova. Construção portátil G/E, validação de assentamento e revisão visual
dos contornos continuam pendentes, portanto a issue permanece aberta.
Ver [TERRAS_POR_POSICAO.md](../testes/TERRAS_POR_POSICAO.md).

A #151 reduz a repetição do chão verde, diminui o capim de forro e apoia
a vegetação baixa na normal do relevo. A composição mantém densidades por
ambiente e os tufos necessários ao cemitério. Cinco gates e a inspeção de
três áreas sustentam [SOLO_E_CAPINS.md](../testes/SOLO_E_CAPINS.md).

A #18 tem inventário dos quinze contratos do 2D e das 32 perguntas de
contexto 3D em [PORTOES_2D_3D.md](../testes/PORTOES_2D_3D.md). Quatorze
gates passam; a auditoria estrita de talentos continua reprovando os quatro
consumidores ausentes, fora da bateria e sem exceções. Passo, lenha, faro
de cordel e vista no topo da Lombada chegam às ações nativas. Favor conserva
seu significado histórico de desconto da terra, agora integrado na fatia
parcial #9; produção e frações
dos trabalhadores dependem da #160, reaberta por ausência no HEAD. A #18
permanece aberta, sem afirmar equivalência completa dos quinze contratos.

A #149 avança parcialmente: passeio não recebe galope por um clipe de
passada curta, e bichos/aves animam o deslocamento efetivo após colisão ou
chegada. A caça mantém velocidades e referência de ronda própria. Ritmo,
passeio das espécies, animações e bichos de casa passam; falsificadores
restauram saltos/deslizamento. O inventário cobre 23 modelos; aves sem rig,
bode e clipes de corrida ainda impedem encerrar a revisão artística.
Ver [ANIMACOES_DOS_ANIMAIS.md](../testes/ANIMACOES_DOS_ANIMAIS.md).

A rota de entrada/saída usa as soleiras alinhadas quando cruza um cômodo,
sem forçar porta trancada. A navegação também reserva a inclinação dos
troncos à altura do corpo. Igreja nos dois sentidos e navegação passam;
mutantes reproduzem umbral e tronco da orla. A quina da ponte central e
a revisão completa seguem pendentes. Ver [ROTAS_PORTAS_E_TRONCOS.md](../testes/ROTAS_PORTAS_E_TRONCOS.md).

As cercas repetidas ganham corpos com as transformações do desenho na
camada de mundo (#125). Navegação e encosta passam; a Candinha alcança
Zefa andando com colisões. A revisão permanece aberta porque o passeio
completo ainda encontra dois bloqueios anteriores, reproduzidos sem as
cercas novas. Evidência em [CERCAS_E_CIRCULACAO.md](../testes/CERCAS_E_CIRCULACAO.md).

A #142 conserva os cantos dos terrenos e as extremidades dos lances de
cerca: a malha se ajusta ao comprimento e ao desnível de cada trecho.
Reservas valem em cinco pontos, e peças isoladas entre duas interrupções
saem. Contorno, encosta, entrada da roça e paisagismo passam; encurtar um
lance produz uma falha. Cinco vistas foram conferidas em
`scratch/cercas142/`. A circulação física e sua navegação continuam na
#125 antes de encerrar a revisão completa.

A #164 fecha com os limites da fazenda, piso contínuo e juntas curtas da ponte,
leitura de navegação sem corrimãos e nado pela lâmina local. A rota física
isolada chega ao portão; retirar juntas reproduz queda, restaurar limites
antigos reprova sete verificações. Rio grande, colisões e ponte passam;
a fixture da ponte aguarda naturalmente o fim da fala conforme #121.
V21 chegou fisicamente ao pátio aos 483,44 s e confirmou a história
implementada concluída, com 110 ações locais e custo zero. A aproximação
do testador respeita waypoints e exige apoio contínuo para seguir em reta.
#159 também fecha: o botão real abriu perfil novo e F8 encerrou normalmente
com captura final, código Godot 0 e custo zero; 87 testes Python passam.
Evidência em [NAVEGACAO_FAZENDA.md](../testes/NAVEGACAO_FAZENDA.md).

A #183 acrescenta ao testador a escada determinístico, Jev e GPT, com o modal do
botão Testar, o painel com quem decidiu e a barra de quanto falta para zerar o
jogo, e o relatório de escalonamentos e progresso. O determinístico segue como
base e a IA só entra quando ele trava, sob o orçamento da sessão; as chamadas
reais ao Jev e ao GPT estão escritas e validadas com respostas falsas
(`tools/jev/test_escada.py`, `tests/testador_sessao.gd`), à espera de uma sessão
curta real autorizada. A #174 veste o painel dessa sessão com o visual do HUD
(laca, filete de ouro, Cinzel e Cormorant), a ação em palavras e o Parar com a
tecla numa plaqueta, fora do CARREGANDO e do HUD do vale. Documentação em
[AUTOPLAYER.md](../testes/AUTOPLAYER.md).

A #154 aponta o passo de entrada à soleira externa real, em vez do centro
da casa; Pedro espera ao lado da passagem. Os portões casa, casa_procedural
e missões passam. O mutante que restaura o alvo na parede reprova, e a
captura `scratch/casa154/porta.png` confirma o marcador diante da porta.
As travessias automáticas por controles normais já constam na campanha
V17, incluindo a saída aos 423,80 s; o replanejamento segue na #159.

A #108 recebe ícones nas abas/linhas do J, Cormorant e ingredientes ×n
por receita, apagados individualmente quando faltam; a seleção mostra a
tecla de interação configurada. Clique sobre o custo chega à receita e
consome a quantidade da regra. Painel, obras e oficio passam; o novo gate
confere sete abas, limites e clique, e reprova quando os custos somem.
Capturas: `scratch/painel-ingredientes/aba-*.png`. A issue continua aberta:
Trabalho depende de #9, Saveiro precisa da conferência visual no mundo,
e a piaçava não tem PNG próprio. Nenhuma arte foi gerada ou comprada.

A #140 tem dezoito escalas individuais persistidas e restauração por componente
ou geral. HUD e balões usam dimensões transformadas, com medidores reorganizados
e avisos fora da missão ampliada. Independência, resolução/idioma, prioridade
e tarefa passaram; mutante sem escala acusa uma falha. Capturas da cena real
a 150% foram conferidas nos três idiomas. A issue segue aberta até revisar
as telas secundárias e as combinações com texto global; ver
[INTERFACES_INDIVIDUAIS.md](../testes/INTERFACES_INDIVIDUAIS.md).

A #126 ganha os três modos de câmera persistidos, giro suave por movimento,
desvios com histerese e geometria de árvores próximas. Raízes sem ângulo livre
desvanecem temporariamente, restauradas ao sair/trocar modo. Capturas de
vegetação, casa, píer e guia conferidas; caminhada física por clique incluída.
O gate passa em 51 s; retirar desvio ou visibilidade reprova as perguntas.
Velas dos barcos também entram na proteção. Evidências e limites em
[CAMERA_AUTOMATICA.md](../testes/CAMERA_AUTOMATICA.md).

A #99 tem correção local de navegação: o raio físico da base dos coqueiros
também entra na malha, evitando que a rota corte um corpo maior que o raio
nominal. A fixture da Filó ativa a população para medir locomoção, não a
apresentação gradual. Gate isolado verde em 63 s; bateria final pendente.

A #159 tem fontes acessíveis estáveis, custo composto de
receitas, cama e saída pela porta antes de seguir Pedro desde o interior.
Na V17 a saída real ocorreu aos 423,80 s, e a condução à fazenda continuou
fora da casa. 85 testes Python verdes; sem a prioridade da porta, a
regressão falha. A chegada final foi confirmada depois na V21, acima.

A recuperação de #159 inclui fontes acessíveis estáveis, custo composto de
receitas e recuperação pela cama sem comida. V16 concluiu Mirante e Fé;
V17 dormiu pelo E/Sim e alcançou o dia do convite (25 → 26, fôlego 27,8 →
77,8). A política observa o requisito de manhã da fazenda sem mudar o dia
diretamente. 84 testes Python passam e retirar essa regra reprova; campanha
até `fazenda_chegada` foi concluída na V21. Evidência em AUTOPLAYER.md.

A fatia anterior de #159 inclui fontes acessíveis estáveis, custo composto de
receitas, obra certa na interface, contornos físicos limitados, alimentação,
documentos e retomada das cadeias do guia entram no testador. 78 testes Python
verdes e quatro sondas Godot da ponte. A sessão V13 perdeu a coleta posterior
ao último save ao esgotar o disco. Capturas preservadas em outro volume,
JPEG menor e checkpoints pela UI normal entram na retomada V15, sem injetar
progresso. A fatia passa 82 testes Python e falsificações de checkpoint/JPEG.
Essa fatia isolada não provava vitória; a V21 confirmou o objetivo depois.

A #64 fica concluída: B remapeável abre a escolha de apoios e talentos ativos,
com uso diário pelas regras compartilhadas, teclado/mouse, pausa e restauração
da câmera. Abrir não consome; usados ficam indisponíveis até o dia seguinte.
Portões de atalhos, uso real, painel, idiomas e câmera verdes; permitir reuso
reprova a condição de uso único. Nova interface nasce em PT/EN/ES.

A #158 tem o ajuste imediato de composição: o varal é um adereço independente,
não pertence à malha da casa Tripo. A casa herdada o omite no padrão e na cena
autoral, preservando o identificador e os 19 varais das outras casas. Portões
de composição e regressão passaram; reativá-lo reprova. Não foi gerado um
novo GLB. A criação de um novo modelo solicitada no ticket continua pendente
de um lote com custo aprovado, conforme AGENTS.md.

A #163 está concluída (07/10/2026): a seleção de matéria-prima prefere uma
fonte compatível com habilidade e grau da ferramenta carregada. A consulta
estrita não aponta uma coleta impossível; o marcador humano conserva o
fallback informativo. Portões de seleção, alcance e ofício passaram; retirar
nível/grau reprova. No autoplay, oito pedras foram obtidas pelo E normal e a
missão do Mirante avançou de 0/35 para 8/35. A campanha #159 segue aberta.

A #65 está concluída (07/10/2026): o roteiro local das apresentações,
caderneta e cabra está revisado em `ABERTURA_E_AUDIO_3D.md`. O portão novo
confere ordem e a abertura real do painel (42 s); o da lombada confere
passagem, descida e fechamento/save (106 s). A falsificação da caderneta
reprova duas condições. A independência dos diálogos permanece declarada.

A #53 está concluída (07/10/2026): o novo portão das filas reais comprova
Pedro/golpe forte, Cosme/ginga/meia-lua/rasteira, mesa da folha e fé como
pré-condições e suspensão ao migrar de fé. Os sinais de Luta cumprem as quatro
práticas e a conta de dez caititus abre a meta do Pedro. Retirar `ensina` do
anúncio reprova as quatro lições; não foi necessária nova implementação.

A #71 está concluída (07/10/2026): os 39 ícones PixelLab existentes permanecem
na teia, com origem documentada. A identidade do 3D fica em molduras, conexões,
tipografia e ficha. Não há lote novo de arte ou consumo de créditos; o portão
confere os ícones de todos os nós. A composição final do autor segue na #41.

A #128 está concluída (07/10/2026): conversar consulta o morador ao alcance
no mesmo quadro em que o foco escolhe o dono do E, inclusive antes de desenhar
a dica. As 22 filas e 85 passos passaram nas cinco horas, isoladamente e em
paralelo. O teste respeita o dia/horário de Quirino e a apresentação gradual.
No Bar às 17h30, a conversa vence Achados (contas 0 e 4,33); bancada e venda
não oferecem ação naquele ponto. A regressão reprova com o alvo atrasado.

A revisão documental #72 acompanha o estado de 07/10/2026 em
[BOARD_2026-10-07.md](BOARD_2026-10-07.md), incluindo as issues posteriores
ao plano original. O [registro da revisão](REVISAO_DOCUMENTAL_72.md)
distingue texto corrigido, história preservada e critérios de release pendentes.

A #120 está concluída (07/10/2026): o HUD conserva missão, ação e medidores
compactos, sem o rótulo persistente de mão livre. Na chegada, fala e aviso
de espera passam pela matriz sem se cobrir. A composição real passou em
PT/EN/ES; forçar o rótulo reprova nos três idiomas. Capturas em
`scratch/composicao-hud/` (evidência local).

A #54 está concluída (07/10/2026): 18 alvos dinâmicos do contrato ficam
declarados com seu responsável, sem coordenadas fictícias. O novo portão
confere 48 nomes por uma lista independente e todos os lugares usados nas
missões locais; remover `porta` das duas tabelas reprova. O portão espacial
também passou: 35 marcos resolvem e 20 nomes têm razão para não ser âncora.

A #155 está concluída (07/10/2026): a apresentação inicial limita o elenco
opcional por região, tempo e progresso, suspendendo corpo, rig e colisão
fora de cena. Os quatro essenciais e donos de missões ativas continuam
disponíveis. Tempo salvo, fade, retomada da rotina e dois estilos conferidos.
A mesma vista da praça passou de 33,33 a 59,73 FPS médios; o p95 de ~55 ms
continua pendente na #43. Condições em [POPULACAO_GRADUAL.md](../testes/POPULACAO_GRADUAL.md).

O alvo de madeira permanece estável durante a aproximação (#159/#162),
troca quando a fonte se esgota e refaz a escolha quando muda o objetivo.
A regressão contínua e a coleta real no autoplay conferem o comportamento.

A #20 está concluída (07/10/2026): K abre habilidades com zoom pela roda,
arrasto pelo botão central e Tab para ofício/fé; L abre a coleção no
almanaque e P abre moradores com afinidade. A escala da árvore não altera
ficha ou rodapé, e os cliques acompanham a transformação. As quatro telas
e os controles reais foram conferidos.

A #67 está concluída (07/10/2026): espólio de combate fica no chão,
com a gravura do item e uma oferta de E. Permanece no save até ser
recolhido; mochila cheia não o apaga. Alcance, foco, repetição, combate
e reabertura do arquivo de save estão conferidos.

A #17 está concluída (07/10/2026): a virada do calendário altera a tinta
da mata, o tom da luz solar e a mistura de aves e insetos. As variações
são discretas, próprias do vale tropical; texturas e modelos permanecem.
O portão percorre as quatro estações reais, verifica ausência de deriva
nos materiais e reprova se a aplicação da estação for retirada.

A #145 está concluída (07/10/2026): enxada com trajeto corrigido e efeito
no contato com o solo, em vez de no começo do E. A preparação e o retorno
são medidos em movimento; repetição e cancelamento preservam as regras.

A #162 está concluída (07/10/2026): depois dos troncos caídos, a missão
de madeira aponta árvores elegíveis. O E informa o corte em curso,
permitindo esperar sua conclusão. Portões e coleta real conferidos.

A #56 está concluída (07/10/2026): vaga nova pede o nome antes da
travessia. Confirmação aplica o nome após a restauração de fábrica;
cancelar não inicia a partida. O save já guarda esse campo e as falas
resolvem `{jogador}` na apresentação, na caixa e nos balões.

A #13 está concluída (07/10/2026): presentes e conversas alteram a
afinidade e os sete moradores originais reagem ao vínculo na conversa
cotidiana, alternando com suas falas gravadas. As respostas sociais novas
são texto em PT/EN/ES; novas vozes dependem do lote pago próprio da #59.
Postos, saudações e prioridade das missões permanecem conferidos.

A porteira decorativa isolada perto do cemitério foi removida (#152,
07/10/2026). As roças mantêm entrada livre voltada à rua; a reorganização
completa das cercas continua sendo a #142.

O retorno da água pela margem do vale junto à ponte está corrigido (#161,
07/10/2026). A flutuação acompanha a altura local do rio. Isso não substitui
o lote de pedras da #116 nem libera a travessia pelo barranco oposto.

A direção visual é Tripo. Conforme a decisão de 29/09, reconciliada na #46
em 07/10/2026, assets novos entram no catálogo sem exigir arte procedural nova.
O procedural permanece como legado funcional, com seus testes e fallback,
até uma migração própria autorizar sua retirada.

Exploração do vale, moradores (que andam pela malha de navegação), missões em
âncoras com recompensa (#48) e diário de missões acompanhadas, calendário (com
o registro das mudanças no relógio), energia, vida, inventário, equipamento,
talentos, cartas, coleção, obras, pesca, cozinha, oficina, os cordéis (pendurados no barbante, o folheto em
alta com a capa de cada um), a lavoura da casa
(#8: arar, plantar, regar, crescer por dia regado e colher, com a regra do
roçado do 2D), o cemitério do Damião (o mato, o conserto das lajes e o cercado,
que é obra), o corte das árvores (toda árvore do vale, que volta adulta em um
ano do calendário, com a madeira de lei e a pedra dura presas ao talento e à
ferramenta de aço), o saveiro do mestre Quirino (o comprador que encosta no
píer no dia 14 de cada estação, com a cadeia do Seu Benedito, a encomenda de
piaçava e a piaçava tirada no facão), a fé (#52: os seis marcos, o rito, a troca, a
teia da fé no K, as missões da Dona Zefa e de cada fé e a festa de cada uma,
com os moradores no marco à tarde, e a capelinha do cemitério de costas para o
mar), os cômodos por dentro das próprias
construções (#26: a igreja do Bom Jesus e a casa herdada, com a cama que vira o
dia, o baú e o desmaio das duas da #50; e a casa do Pedro e a da Dona Zefa,
cada uma com o interior de quem mora) e três vagas de salvamento, com os
pontos de restauração de cada uma. A
existência de um sistema não significa que todos os seus gatilhos ou telas
estejam concluídos.

## Cobertura de idiomas concluída (#47, 07/10/2026)

Todas as cadeias de missões do diretório de dados e os recursos declaram cobertura ou pendência no teste de idiomas. Verificação: 694 campos, 36 arquivos; falsificação reproduzível com `--falsificar-titulo`. Isto amplia a proteção; a tradução pendente de #6 e o idioma em jogo de #51 continuam separados.

## Próxima tarefa

#122 tem plaquetas comuns para os atalhos e a mão, com contraste mínimo 7:1,
sem cobrir ícones nem ampliar a área do botão. Plaquetas, barra, atalhos e
reservas passaram; a falsificação de sobreposição reprova nove verificações.

A fatia de navegação/telemetria de #159 tem 44 testes Python e portão de mapa,
com sessão real chegando à etapa 10/16 após porta, baú e lavoura. A campanha
sem limite continua em perfil isolado. #159/#146/#154 permanecem abertas
até seus critérios completos, incluindo orientações ao jogador humano.

#131 foi verificada em reservas_do_corpo, folego, matriz_dos_baloes e idiomas,
mais capturas de dia/noite. Os ícones substituem nomes persistentes nos
medidores; números e avisos continuam. A escala individual de #140 e a
revisão das falas antigas do tutorial continuam tarefas próprias.

#136 foi verificada em casa, casa_procedural e efeitos_no_vale, com captura
diurna/noturna e falsificação da textura. O material reutiliza a cal
envelhecida existente; não houve geração paga de asset.

#137 foi verificada por carga_e_fala e smoke_opening: a saudação e a fila
esperam a cena pronta e o fim da transição. A fila anterior reprova os dois
intervalos de bloqueio. A cobertura de idiomas pendente continua separada.

#134 foi verificada com dica_requisito_e_mao, barra_de_mao, matriz_dos_baloes
e idiomas. O rótulo persistente da mão de #120 foi retirado; os demais
critérios de reorganização do HUD nessa issue permanecem abertos.

#130, #135 e #144 foram verificadas por conquista_compacta, falas_em_fila,
marcador_na_chegada e efeitos_no_vale, com capturas do vale em exterior e
interior de dia/noite. A orientação mantém o destino lógico após a chegada,
sem concluir antecipadamente tarefas de arar, plantar ou regar.

Em 07/10/2026, #133, #143 e #157 foram verificadas com avisos_com_prazo,
falas_em_fila, mochila e boneco_da_mochila: prazo de recebimentos, fim da
duplicação de Pedro e ocultação do HUD durante mochila/baú. A matriz da #132
já faz avisos cederem à fala e ao E. #121, #124, #127 e #132 foram verificadas
com matriz_dos_baloes, foco_do_e, placas_e_baloes, afinidade_interacao_3d e
popups_na_tela: fala ativa, nome redundante, região da árvore e oclusão.
A matriz e seus limiares estão em docs/testes/PRIORIDADES_DOS_BALOES.md.

O board é a fonte dos critérios de aceite:
[issues do projeto](https://github.com/acentauric/myths-valley-3d/issues).
Enquanto houver tarefa aberta no marco Jam 04/10, ela tem prioridade;
Pós-jam segue as dependências descritas em cada issue.

Antes de implementar, confira o código e o teste atuais: as issues mais
antigas podem descrever como ausente algo que já foi incorporado.

## Cada fatia

Leia a issue e o portão do assunto, implemente a mudança, acrescente ou
ajuste a verificação de comportamento e mostre que ela detecta o defeito.
Rode `testar.ps1` (só os portões que a mudança alcança, em paralelo e com
perfil isolado); erro de compilação e travamento reprovam.
Registre a mudança no CHANGELOG_3D e cite a issue no corpo do commit.

Os sistemas deste repositório evoluem aqui. Não há sincronizador de regras,
dados ou áudio com outro projeto. Geração de arte e áudio precisa de pedido
explícito, e cada asset mantém origem e créditos.

## Registros

As posições e giros das quinze construções atuais passam a ser autoria salva em
`scenes/prototipo_3d/composicao_vale.tscn` (#57, primeira fatia). O editor mostra
terreno e ruas como referência, e o jogo aplica as transformações salvas às casas,
colisões, interações e âncoras. Vegetação autoral, alteração do traçado das ruas,
inclusão/remoção de construções e escultura do terreno continuam pendentes.

As trocas e paradas de trilha usam fades, inclusive ao carregar o vale.
Uma nova solicitação cancela a transição anterior sem cortar o ganho (#79).

O painel Personagens apresenta moradores individualmente, com modelo 3D,
falas e edição. O catálogo de assets usa cartões paginados e registros individuais (#78).

A entrada leve pergunta o idioma antes de carregar o cenário do menu (#77).
Sua moldura reutiliza a talha SVG da home; na primeira abertura o idioma do
sistema sugere a opção, sem substituir uma escolha salva nem pular a confirmação.
A versão e a build identificam a entrada abaixo do modal. A talha SVG também
emoldura o menu Jogar/Explorar e os painéis internos por meio da identidade comum.
Chinês tem seleção e etapas do carregamento traduzidas, com fallback inglês
declarado. A engenharia da #51 mantém o idioma escolhido durante a partida;
os textos ainda pendentes têm fontes declaradas no portão de idiomas e usam
português como fallback. A tradução integral permanece na #6. O suporte
pt/en/es segue a decisão do autor de setembro; o prazo antigo da jam não
condiciona mais essa correção do desenvolvimento atual.

A interação social da #49 registra a conversa uma vez por dia. Presentes
da mão pedem confirmação e aplicam gosto/desgosto, refletidos na tela P;
missões e ferramentas de trabalho mantêm prioridade. Portões dirigidos de
afinidade, idiomas, seleção, foco do E e abertura passaram em 07/10/2026.

- [Histórico de mudanças](CHANGELOG_3D.md).
- [Etapas e decisões anteriores](HISTORICO_DESENVOLVIMENTO_3D.md).
- [Arquitetura](ARQUITETURA.md).
- [Validação](VALIDACAO.md).

## Separação concluída em 01/10/2026

O projeto abre na raiz, com sistemas locais, sem sincronização ou testes
dependentes de outro checkout (#44 e #61). Modelos e WAVs, inclusive suas
versões históricas, usam Git LFS (#60). Abertura e controles contam falhas e
foram falsificados para conferir a reprovação por código de saída (#69).

## Validação de arquivos externos em 03/10/2026

A atualização confere origem, limites e estrutura dos pacotes antes de
extrair, e a leitura de saves recusa objetos que carregariam código (#76).
O formato das partidas é preservado. Os portões de segurança cobrem caminhos
perigosos, links, cabeçalhos conflitantes e a leitura de saves legítimos.
A autenticidade da distribuição ainda depende do servidor HTTPS oficial.

## Reservas do corpo em 06/10/2026

A #45 fechou pela #82, com a decisão do autor de 06/10: a reserva do dia
(`Energia`) volta a ser conta própria. Vida para o dano; a reserva do dia no meio
da tela, só com o número, gasta pela enxada, pelo machado, pela picareta, pela
lavoura e pela luta, e devolvida só por comida, cama e desmaio (no fim dela o
passo encurta e não se corre); vigor para o esforço imediato (corrida, salto,
golpe), que volta sozinho; e, na água, a barra do meio vira o fôlego do nado,
gasto depois do vigor, que sem ele tira vida. De 04/10 a 06/10 a reserva espelhou
o vigor, e a comida perdeu o sentido. O HUD, o manual e o guia descrevem as
quatro, e `tests/reservas_do_corpo.gd` cobre os custos, a troca da barra e a
restauração.

## Troca de vaga e teclas no jogo em 07/10/2026

As #66 e #70 ficam concluídas: o rodapé da mochila usa o atalho vigente,
e Jogo permite trocar de vaga mediante confirmação, salvando a origem e
carregando o destino sem apagar os arquivos. Portões de mochila, painel,
vagas e idiomas passaram; os mutantes reprovam sem tocar o perfil normal.

## Transições de áudio verificadas em 07/10/2026

A #79 foi conferida pelo portão audio_fade: troca, cancelamento, ganho,
volume e mute durante a transição. A implementação existente satisfaz
o aceite; o mutante que reduz a duração a 10 ms reprova três verificações.

## Mapa do lobby restaurado em 07/10/2026

A #147 fica concluída: os seis acessos laterais incluem Mapa no lobby em
vídeo; clicar solicita a carga do cenário e abre seus pontos de interesse.
A abertura inicial continua sem montar o vale. Lobby e mapa_fluxo verdes;
remover o acesso em memória reprova, e três resoluções preservam os botões.

## Caramelo e pontos de ronda em 07/10/2026

A #153 está concluída: latido espacial por aproximação, intervalo com
variação, prioridade de fala e canais de volume/mute. WAV CC0 com origem
e hash em assets/audio/animais/ORIGEM.md. Latido e bichos nos dois estilos
passaram; falsificadores reproduzem repetição e ponto inválido de ronda.
A ronda também evita a alternativa dentro de casa quando todas as amostras
aleatórias são recusadas (#149 parcial; auditoria visual geral permanece).

## Composição legível do píer em 07/10/2026

A #148 está concluída: a vara decorativa central sai do píer. Catálogo
e ferramenta de pesca, peixe, pote, piso e rotas permanecem. Pier_legivel
e navegacao passaram, com captura conferida; recolocar a vara reprova.
Toda instância de catálogo agora informa sua peça por metadata, inclusive
itens sem LOD e instâncias cujo nome o Godot muda por duplicidade.

## Caminhada da beata em 07/10/2026

A #139 fica concluída: cópias locais dos clipes de locomoção
removem a translação lateral da raiz e limitam sua oscilação a 2,5 cm,
preservando pernas, velocidade e ajuste físico ao terreno. Portões de
locomoção, rotina e nado verdes; o mutante original acusa 98 falhas.
Capturas de três fases da passada e caminhadas no vale plano/inclinado
foram conferidas em scratch/beata-locomocao e scratch/beata-no-vale.

## Orientação da primeira leira em 07/10/2026

A #146 fica concluída: as etapas arar/plantar/regar mostram marcas individuais,
o E de gesto já cumprido aponta o próximo item e a tecla da barra vigente,
e o marcador busca a leira apropriada à etapa restante. Recados negativos
explicam como seguir, sem acumular texto; ajuda temporizada conta atividade
no campo, não pausa de leitura, e respeita outras falas/avisos. Progresso
retira apenas a ajuda de sua origem. Textos em PT/EN/ES. Orientacao_lavoura,
lavoura, cadeia_das_missoes e idiomas passaram; apagar orientações em
memória reprova sete perguntas. Avisos longos agora quebram por largura
e ajustam a altura; capturas em três resoluções conferidas, seis falhas
no mutante sem quebra. O portão da cadeia aguarda a fala antes de usar E,
conforme a prioridade #121 já aplicada.


## 07/10/2026: livro de fiado do Tonho (#68)

O livro usa o baú efetivamente montado no perfil da venda, com E a 1,7 u e
foco compartilhado. Pergunta antes de lançar até 500 réis, limitados pelo
dinheiro do jogador e pelo saldo. Sem dinheiro explica venda/espera; conta
quitada orienta voltar ao pontal. Dívida inicial 1900, abatimento de 130 por
dia somente depois da entrega real da rede; quinze dias quitam a conta.
Saldo, rede, leitura e dia do último abatimento vão no save do vale.
A etapa do livro exige leitura E quitação; chegar à venda ou ler não pode
liberar a fala Zerou. Valores conferidos no 2D SHA62c0f14b, Terrenos/Mundo.
Interface PT/EN/ES; a prosa autoral da cadeia conserva pendência #6.
Portões fiado_tonho (limites, 14/15 dias, JSON, trava de missão) e
livro_no_armazem (móvel real, foco E, Sim/Não e save completo), idiomas,
missoes e salvamento. Mutante sem abatimento deve reprovar a conta.
Captura scratch/fiado-tonho/pergunta.png e logs em D:/MythsValleyPlaytestRuns.

### 07/10/2026: foco durante a fala longa (#140, #132)

A caixa longa reserva seu retângulo real, incluindo a transformação da camada e as escalas individuais. Componentes do HUD que o intersectam ficam transparentes durante a conversa; sua visibilidade original continua pertencendo ao dono do aviso, sem ressuscitar notificações expiradas. Missão e medidores fora da caixa permanecem. Plaquinhas do mundo cedem ao abrir a fala e voltam ao terminar.

O tutorial do corpo declara `interfaces` em cada linha de `missoes_guia.json`. `Dialogo.falar` aceita essa lista paralela como quarto argumento opcional; a linha atual destaca somente o componente declarado, no retângulo renderizado. Perguntas e fechamento limpam esse foco. Nenhuma dedução depende de palavras da prosa regional.

Portão `foco_da_narracao`: reserva, componente externo preservado, troca de foco, restauração da cor e aviso expirado. A falsificação `--sem-reserva` reprova uma asserção. `interface_individual`, `prioridade_dos_avisos` e `idiomas` acompanham. Captura real no armazém: `scratch/fiado-tonho/tutorial-foco.png`; a pergunta/pagamento do livro continuam com zero falhas. A #140 permanece aberta pelos componentes secundários ainda pendentes.

### 07/10/2026: catálogo antes dos autoloads (#17)

A inspeção do cemitério encontrou erro de compilação em `estacoes_vale.gd` quando um script pré-carregava o catálogo. O registro de materiais passa a consultar a estação guardada por `aplicar`, sem depender de um identificador de autoload na compilação. Assim, modelos carregados depois recebem a estação vigente e repetir o registro preserva a cor original.

`estacao_no_catalogo` pré-carrega o catálogo e confere registro tardio e cor sem deriva. A falsificação `--estacao-inicial` reprova. Regressões: `estacoes_do_vale`, `lapides_no_chao` e `lapides_no_chao_procedural`. O sucesso textual do antigo gate não foi aceito enquanto havia SCRIPT ERROR no log.

### 07/10/2026: verificação das sepulturas (#123)

O layout de `cemiterio_layout.gd`, já presente na main integrada, satisfaz a revisão: doze sepulturas preservam a ordem das histórias, cabeceiras para o mesmo lado, intervalos de passagem, corredor diante da capelinha e bases assentadas pelo terreno dos cantos. O portão consulta também a malha física real, a cápsula nos corredores e as reservas de moradores/recursos. As três lajes levantadas pela raiz continuam sendo trabalho intencional da missão do Damião, não defeito de colocação.

`lapides_no_chao` (47 s) e `lapides_no_chao_procedural` (37 s) verdes. Nova falsificação `--cabeca-invertida` reprova a associação/orientação da primeira sepultura. Capturas reais no Tripo em `scratch/cemiterio123/visao-{0,1,2}.png`, entrada, proximidade e corredor da capela, conferidas visualmente. O log da repetição não contém SCRIPT ERROR. A arte específica da cerca permanece na #111; a #123 pode ser encerrada sem substituir o modelo existente.

### 07/10/2026: controles, apoios, mapa e molduras (#140)

As preferências individuais passam de 18 a 23 componentes: atalhos do canto,
mapa, controles, cartas de apoio e ajuda. Os botões do canto respeitam a altura
útil da janela, mesmo combinando escala global de HUD e individual a 150%.
O mapa transforma os marcadores e o rótulo do viajante sem alterar o zoom do mundo.
Moldura e sombra agora acompanham a posição, o pivô e a escala real da caixa;
antes, a caixa encolhia e sua moldura permanecia com o tamanho original.
Reabrir as cartas atualiza também título, instrução e botão no idioma corrente.

`interfaces_secundarias` confere três resoluções e três idiomas, texto global
ampliado, ancoragem, moldura e clique real no último atalho. Verde em 3 s;
`--sem-escala` reprova duas verificações sem erro de script. Regressões
`interface_individual`, `apoios_no_vale`, `atalhos` e `idiomas` verdes;
o catálogo contém 775 campos em 45 arquivos. Capturas gráficas em
`scratch/interfaces-secundarias/`: controles a 65% e apoios a 150%.
A #140 continua aberta para a revisão das demais telas e combinações globais.

### 07/10/2026: cercas e rotas livres (#125, #142)

As cercas do paisagismo têm corpo correspondente ao desenho e entram na
malha; Candinha percorre a rota até Zefa. Os contornos respeitam esquinas,
reservas e entradas, com apoio no relevo e cinco vistas reais conferidas.
As últimas travadas na igreja e no corrimão central foram resolvidas sem
retirar colisões nem criar exceções. Corrimãos entram como obstáculos
proporcionais ao GLB, preservando o tabuleiro e as juntas.

`colisoes_de_passeio` 87 s, `navegacao` 57 s e `rota_da_fazenda` 61 s verdes.
`travessia_da_ponte_central` percorre rotas e ambas as cabeceiras; o mutante
sem obstáculos reproduz a travada no corrimão. Detalhes e evidências em
`docs/testes/CERCAS_E_CIRCULACAO.md`. Encerrar #125 e #142; a bateria completa
exigida pela #99 continua pendente.

### 07/10/2026: escalas do lobby (#140, parcial)

Menu, histórico, ajustes, vagas/nome, créditos, legenda da travessia, galeria
e perguntas recebem ajustes independentes. Painéis reutilizados trocam de
preferência sem acumular conexões e respeitam sua posição na janela.
Quatro gates verdes, mutante com duas falhas e cinco capturas conferidas;
detalhes em `docs/testes/INTERFACES_INDIVIDUAIS.md`. A issue permanece aberta.

O folheto soma o 32º componente: escala conjunta de papel, texto e capa,
limite pela área útil e fundo em tela inteira. Gate leve e leitura integrada
verdes, mutante com seis falhas e três capturas conferidas; #140 segue aberta.

### 07/10/2026: missões nas âncoras presentes (#1, concluída)

A auditoria confirma dados, 16 passos de chegada, grupos de missão, diário,
acompanhamento e integração do HUD/bússola. O mecanismo nativo segue a decisão
posterior do autor de substituir o checklist do 2D. Cadeia, painel, regras,
tarefa e idiomas verdes; V21 complementa com navegação real até o fim da chegada.
Evidências e limites em `docs/testes/MISSOES_NAS_ANCORAS.md`.

### 07/10/2026: prévia geográfica comprovada (#33, concluída)

Host e composição carregam uma malha persistida sob editor_hint real, com
captura renderizada. No runtime, menu 3D e vale geram somente uma terra e
removem o host. Gates verdes e mutante sem prévia reprovado; comando de
atualização e limites documentados em `docs/testes/TERRENO_NO_EDITOR.md`.
