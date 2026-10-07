# Plano do Myths' Valley 3D

O jogo 3D é mantido em `acentauric/myths-valley-3d`, com seu projeto Godot na
raiz. O jogo 2D segue sua própria linha em `acentauric/myths-valley`.

## O que já roda

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
