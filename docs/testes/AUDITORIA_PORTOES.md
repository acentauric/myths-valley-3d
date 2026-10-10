# Auditoria dos portões (#242)

Gerada em 10/10/2026 a partir de `tests/` e do último resultado da suíte (`.godot/testar3d/suite-*.json`). Classificação de cada portão antigo:

| Classe | Quantos | Como roda |
| --- | --- | --- |
| (a) unidade | 37 | GUT, `tests/unidade/test_*.gd`, um Godot sem vale |
| (c) suíte, vale | 170 | `tests/suite/rodar.gd`, o vale montado uma vez por estilo |
| (c) suíte, sem vale | 53 | o mesmo Godot, antes do vale; candidatos a virar unidade |
| isolado | 1 | um Godot só dele (depende de processo novo) |
| longo | 2 | só com `-Longos` (a partida inteira, a régua) |
| fora da suíte | 2 | SceneTree própria: herda da ferramenta do sobrevoo |

**(b) juntados** e **(d) aposentados**: nenhum nesta rodada. Os pares `_procedural` (o mesmo portão no estilo procedural) somem com a retirada do estilo (#58), não antes: enquanto o estilo existir, eles rodam na segunda montagem do vale.

A meta da issue era "≤ 20 casos de integração". Ela vinha do custo de um Godot por portão. Na suíte, um caso a mais custa só o tempo dele (o vale já está montado), então os casos ficaram separados, um por assunto, e o que conta é o tempo total.

## (a) Viraram teste de unidade

`ajustes_com_ajuda`, `alvo_de_madeira`, `alvo_material_acessivel`, `apoios_no_vale`, `atalhos`, `atualizacao`, `balao_sobre_quem_fala`, `bases_das_arvores`, `casas_taipa_em_escala`, `colisao_do_catalogo_das_arvores`, `consumidores_dos_talentos`, `contorno_das_cercas`, `contrato_dos_lugares`, `conversa_e_afinidade`, `conversa_no_mesmo_quadro`, `dados`, `estacao_no_catalogo`, `fe`, `folego`, `forro_no_relevo`, `historico_em_linhas_longas`, `icone_do_jogo`, `idiomas`, `inventario`, `mochila_rodape`, `modelo_viajante`, `nado_parado_animacao`, `orientacao_lavoura`, `regras_afinidade`, `regras_fracoes`, `regras_missoes`, `regras_receitas`, `ritmo_do_bicho`, `seguranca_arquivos`, `sobrevoo_menu`, `troncos_fechados`, `varais_em_escala`

## Os que ficam na suíte, isolados, longos ou fora

"Vale novo" marca o caso que, na última rodada, reprovou no vale emprestado e passou com o vale montado do zero: algum caso antes dele deixou o vale sujo.

| Portão | Classe | Onde | Tempo na suíte | O que confere |
| --- | --- | --- | --- | --- |
| `achados_no_vale` | suíte (vale) | vale Tripo | 30 s | Confere que O QUE SE ACHA NO VALE ESTÁ AO ALCANCE DE QUEM ANDA |
| `acordar_parado` | suíte (vale) | vale Tripo | 43 s | Confere ACORDAR PARADO (#189): quem dorme correndo, andando, nadando ou de |
| `afinidade_interacao_3d` | suíte (sem vale) | candidato a unidade | 2 s | #49: usa o controlador real de E, os autoloads e a pergunta real de Sim/Não |
| `agua_rasa` | suíte (vale) | vale Tripo | 117 s | O jogador entra no mar andando ao lado do píer: afunda aos poucos no fundo da |
| `alcance_dos_alvos` | suíte (vale) | vale Tripo | 41 s | Confere que TODO ALVO DE TRABALHO É ALCANÇÁVEL — e diz onde cada um caiu |
| `almanaque` | suíte (vale) | vale Tripo | 1 s | Confere que O ALMANAQUE SE LÊ — a cadeia de índices, e não só as regras dela |
| `amanhecer` | suíte (vale) | vale Tripo | 12 s | Confere O AMANHECER NO VALE (#21): o cartão do dia que começa, lido no |
| `animacoes_mixamo` | suíte (sem vale) | candidato a unidade | 3 s | AS ANIMAÇÕES DO MIXAMO NOS PERSONAGENS (#190) |
| `animais_animacao` | suíte (vale) | vale Tripo | 3 s | Confere as ANIMAÇÕES DOS BICHOS, uma por uma ("precisamos revisar as animações dos |
| `apresentacao_do_povoado` | suíte (vale) | vale Tripo | 2 s | Presença gradual, processamento suspenso e disponibilidade das missões (#155) |
| `arvores_barram_o_corpo` | suíte (vale) | vale Tripo | 16 s | Confere que A ÁRVORE BARRA O CORPO NO PEITO E DEIXA A COPA PASSAR (#150) |
| `atencao_do_morador` | suíte (vale) | vale Tripo | 7 s | A ATENÇÃO A QUEM A MISSÃO MANDA PROCURAR (#198): o morador que o passo aponta PARA e olha o |
| `audio_fade` | suíte (sem vale) | candidato a unidade | 9 s |  |
| `aves_sem_piscar` | suíte (vale) | vale Tripo | 140 s | OS PAVÕES NÃO PISCAM (#193): o jogador anda e corre pela estrada da igreja, de 110 u |
| `avisos_com_prazo` | suíte (sem vale) | candidato a unidade | 5 s | #133/#157: avisos expiram sem evento seguinte; falas mantêm sua vez e limpam |
| `avisos_da_primeira_vez` | suíte (vale) | vale Tripo | 72 s | Confere OS AVISOS DA PRIMEIRA VEZ (scripts/prototipo_3d/aviso_da_primeira_vez.gd, |
| `avisos_em_linhas` | suíte (sem vale) | candidato a unidade | 0 s |  |
| `barra_de_mao` | suíte (vale) | vale Tripo | 67 s | Confere que A BARRA DE MÃO APARECE — e não só que ela existe |
| `barra_de_mao_sem_escurecer` | suíte (sem vale) | candidato a unidade | 0 s | #222: a barra de mão não fica escurecida, como desativada, depois de a explicação das barras |
| `beata_locomocao` | suíte (sem vale) | candidato a unidade | 0 s |  |
| `beata_no_vale` | suíte (vale) | vale Tripo | 9 s |  |
| `bicho_parado` | suíte (vale) | vale Tripo | 28 s (vale novo) | O BICHO DE QUATRO PATAS PARA NA POSE DE APOIO (#91) |
| `bichos_de_casa` | suíte (vale) | vale Tripo | 185 s | Confere os BICHOS DE CASA do vale (#28): cães, gatos, porcos, cabras, o jumento |
| `bichos_de_casa_procedural` | suíte (vale) | vale procedural | 88 s | O mesmo portão de bichos_de_casa.gd, no estilo procedural: os bichos de caixa |
| `boneco_da_mochila` | suíte (vale) | vale Tripo | 11 s | Confere O BONECO DA MOCHILA |
| `cadeia_da_candinha` | suíte (vale) | vale Tripo | 98 s | JOGA A GARAPA DA PRAÇA — a cadeia que corta e entrega |
| `cadeia_da_fe` | suíte (vale) | vale Tripo | 94 s | Confere AS MISSÕES DA FÉ (#52): a fila da Dona Zefa e a missão própria de |
| `cadeia_da_filo` | suíte (vale) | vale Tripo | 86 s | JOGA O PIRÃO DA DONA FILÓ — a primeira missão do vale que se cumpre LEVANDO |
| `cadeia_da_zefa` | suíte (vale) | vale Tripo | 209 s | JOGA A CADEIA DA DONA ZEFA — as ervas da serra e a história do Cosme |
| `cadeia_das_missoes` | suíte (vale) | vale Tripo | 2 s | JOGA A CADEIA DE MISSÕES DO COMEÇO AO FIM, e confere que cada passo fecha |
| `cadeia_do_coveiro` | suíte (vale) | vale Tripo | 210 s | JOGA A MISSÃO DO CEMITÉRIO DO COMEÇO AO FIM — a primeira do vale que não é do Pedro |
| `cadeia_do_mirante` | suíte (vale) | vale Tripo | 60 s | JOGA O MIRANTE — as missões do arraial que o Pedro dá depois do tutorial |
| `cadeia_do_tonho` | suíte (vale) | vale Tripo | 100 s | JOGA A HISTÓRIA INTEIRA DO TONHO — a rede, a conta e o primeiro peixe |
| `calendario` | suíte (vale) | vale Tripo | 69 s | Confere que o CALENDÁRIO do jogo 2D chegou ao vale, e que ele não brigou |
| `camera_automatica` | suíte (vale) | vale Tripo | 79 s | Recebe o vale montado do zero: reprovava no vale deixado pelos casos anteriores (a suíte, #242) |
| `camera_resiliente` | suíte (vale) | vale Tripo | 555 s (vale novo) | Confere A CÂMERA RESILIENTE: nunca dentro do personagem, nunca debaixo d'água |
| `camera_resiliente_procedural` | suíte (vale) | vale procedural | 99 s | O mesmo portão de camera_resiliente.gd, no estilo procedural: a câmera nunca |
| `camera_volta` | suíte (vale) | vale Tripo | 19 s | Confere que TODA TELA DEVOLVE A CÂMERA COMO A ACHOU, e para o vale atrás dela |
| `caminho_longo` | suíte (vale) | vale Tripo | 20 s | O MORADOR NÃO SALTA NO CAMINHO LONGO QUANDO A CÂMERA VIRA (#84) |
| `caminho_pela_porta` | suíte (vale) | vale Tripo | 112 s | A cápsula atravessa a porta da igreja na rota da malha, nos dois sentidos |
| `canoa_colisao` | suíte (vale) | vale Tripo | 4 s | The current hull mesh drives a double-sided collision body recognized by the swimmer |
| `canoas` | suíte (vale) | vale Tripo | 10 s | Confere que A CANOA É SÓLIDA NA MEDIDA DO DESENHO — e que quem pula nela fica |
| `carga_e_fala` | suíte (sem vale) | candidato a unidade | 1 s | #137: a fila não inicia voz durante montagem nem durante o fade da carga |
| `cartas` | suíte (vale) | vale Tripo | 11 s | Confere CARTAS E ACHADOS no vale (#12): cordéis no lugar deles, o sinal da |
| `casa` | suíte (vale) | vale Tripo | 92 s | Confere A CASA HERDADA POR DENTRO e a CAMA QUE VIRA O DIA (#50, #26) |
| `casa_procedural` | suíte (vale) | vale procedural | 40 s | O mesmo portão de casa.gd, no estilo procedural: o jogador escolhe o estilo |
| `casa_sem_varal` | suíte (sem vale) | candidato a unidade | 0 s | A variante de composição da casa herdada não estende roupas (#158) |
| `casas_dos_moradores` | suíte (vale) | vale Tripo | 73 s (vale novo) | Confere que A CASA DO PEDRO E A DA DONA ZEFA ABREM POR DENTRO, e que as casas |
| `casas_por_dentro` | suíte (vale) | vale Tripo | 158 s | Confere que TODA CASA DO VALE ABRE POR DENTRO E TEM MÓVEIS, a começar pelo casarão |
| `cena_so_com_balao` | suíte (vale) | vale Tripo | 26 s | NA CENA SÓ FICAM O BALÃO E AS TARJAS, A CÂMERA DESLIZA E O E PULA (#215) |
| `cenas_do_vale` | suíte (vale) | vale Tripo | 74 s | AS CENAS DO VALE PELOS DADOS (07/10: "implementar a mesma lógica de cutscene que fizemos no 2D, |
| `cercas` | suíte (vale) | vale Tripo | 2 s | AS CERCAS DE VARAS DAS ROÇAS, BEM POSTAS (playtest de 07/10: "as cercas continuam mal |
| `cercas_e_circulacao` | suíte (vale) | vale Tripo | 77 s | Cercas visíveis são obstáculos reais, e Candinha ainda chega à Zefa (#125) |
| `cercas_na_encosta` | suíte (vale) | vale Tripo | 2 s | AS CERCAS ACOMPANHAM O CHÃO (#93) |
| `ceu_horizonte` | suíte (vale) | vale Tripo | 1 s | O CÉU E O HORIZONTE: o céu é o do CeuVale (shader próprio, névoa que tira a cor do |
| `chapada` | suíte (vale) | vale Tripo | 28 s | Confere A CHAPADA DO SEU BENEDITO, a frente do 2D que mostra terra que poderia |
| `chegada` | suíte (vale) | vale Tripo | 141 s | Confere A CHEGADA PELO SAVEIRO, o começo do jogo jogado como o jogador joga |
| `clareiras_da_mata` | suíte (vale) | vale Tripo | 2 s | Confere AS CLAREIRAS-DESTAQUE DA MATA (data/mapas/clareiras_da_mata.json, |
| `click_controls` | suíte (vale) | vale Tripo | 2 s | Verifica alvos de casas, acesso ao terreno e rota a partir do píer |
| `coleta_no_chao` | suíte (vale) | vale Tripo | 4 s |  |
| `colisao_das_arvores` | suíte (vale) | vale Tripo | 26 s | Confere que O CORPO DE UMA ÁRVORE COBRE O TRONCO QUE SE VÊ |
| `colisao_das_casas` | suíte (vale) | vale Tripo | 7 s | Confere que A COLISÃO DE TODA CASA ACOMPANHA A PAREDE VISÍVEL (#205): o viajante para |
| `colisoes_de_passeio` | suíte (vale) | vale Tripo | 343 s (vale novo) | Confere AS COLISÕES NO CHÃO, andando: o corpo do jogador anda os caminhos do |
| `colisoes_de_passeio_procedural` | suíte (vale) | vale procedural | 108 s | O mesmo portão de colisoes_de_passeio.gd, no estilo procedural: o corpo anda os |
| `colisoes_do_vale` | suíte (vale) | vale Tripo | 196 s | Confere AS COLISÕES DO VALE E A CÂMERA QUE ANDA ENTRE ELAS |
| `colisoes_do_vale_procedural` | suíte (vale) | vale procedural | 32 s | O mesmo portão de colisoes_do_vale.gd, no estilo procedural: as paredes das casas |
| `composicao_do_hud` | suíte (vale) | vale Tripo | 2 s | Composição real da chegada: missão, fala e aviso de espera juntos (#120) |
| `composicao_vale` | suíte (sem vale) | candidato a unidade | 28 s | Salvar no editor precisa mudar o mundo, não apenas a aparência da prévia |
| `conducao_candinha_zefa` | suíte (vale) | vale Tripo | 594 s (vale novo) | A CONDUÇÃO DO PEDRO, DA CANDINHA À DONA ZEFA E DEPOIS (#237) |
| `conducao_pela_vista` | suíte (vale) | vale Tripo | 1 s | O PEDRO SEGUE ENQUANTO O JOGADOR O VÊ, E SÓ VOLTA QUANDO ELE SAI DA TELA (#238) |
| `conquista_compacta` | suíte (sem vale) | candidato a unidade | 8 s | #130: conclusão pelo caderno real, sem clarão aditivo sobre todo o vale |
| `continuidade_pedro` | suíte (vale) | vale Tripo | 0 s | Contrato local do roteiro: apresentações, caderneta e cabra (#65) |
| `corte_das_arvores` | suíte (vale) | vale Tripo | 105 s (vale novo) | Confere que AS ÁRVORES DO VALE SE CORTAM, E VOLTAM EM UM ANO — e que a |
| `diario_menu_recolhivel` | suíte (vale) | vale Tripo | 1 s | O MENU DA ESQUERDA DO DIÁRIO RECOLHE, E A FALA E OS OBJETIVOS TÊM A MESMA LETRA (#221) |
| `diario_sem_rolagem` | suíte (vale) | vale Tripo | 17 s | Confere o DIÁRIO DE MISSÕES (J) QUE CABE NA TELA: sem coluna vazia, com a fala em |
| `dica_requisito_e_mao` | suíte (sem vale) | candidato a unidade | 1 s | #134/#120: layout real em três idiomas/resoluções e seleção sem rótulo persistente |
| `dicas_dos_moradores` | suíte (vale) | vale Tripo | 77 s (vale novo) | OS MORADORES AJUDAM QUEM ESTÁ PERDIDO (#204): um morador que entende do assunto vem até o jogador, dá uma dica |
| `efeitos_no_vale` | suíte (vale) | vale Tripo | 52 s | #130/#135: efeito real em exterior/interior, dia/noite e conclusÃµes seguidas |
| `entrada_da_roca` | suíte (vale) | vale Tripo | 62 s | Uma entrada de roça não é uma porteira decorativa imóvel no caminho |
| `entregas_da_cadeia` | suíte (vale) | vale Tripo | 5 s | O QUE O PASSO ENTREGA NÃO SE PERDE: nem no save, nem com a mochila cheia |
| `escala_do_folheto` | suíte (sem vale) | candidato a unidade | 3 s |  |
| `escolha` | suíte (vale) | vale Tripo | 5 s | Confere A FALA LONGA DO VALE, com a escolha de Sim e Não (#21) |
| `estacoes_do_vale` | suíte (vale) | vale Tripo | 0 s | A virada real do calendário muda mata, luz e mistura sonora (#17) |
| `fachada_do_alpendre` | suíte (sem vale) | candidato a unidade | 0 s | Confere que A COLISÃO DA FACHADA SEGUE A MALHA NO ALPENDRE (#205): o pilar solto da parede é sólido, e o chão |
| `fala_pelo_e` | suíte (vale) | vale Tripo | 196 s (vale novo) | O E CONTROLA A CONVERSA (#220): a fala da missão e a conversa que o jogador abriu não somem sozinhas |
| `falas_do_pedro` | suíte (vale) | vale Tripo | 2 s | AS FALAS SITUACIONAIS DO PEDRO (#179): comentários curtos, cada um ligado a um gatilho do que acontece com |
| `falas_do_viajante` | suíte (vale) | vale Tripo | 9 s | AS FALAS DO VIAJANTE (#187): o personagem do jogador comenta o que acontece, SÓ EM VOZ e sem balão |
| `falas_dos_moradores` | suíte (vale) | vale Tripo | 104 s | Confere AS FALAS DOS MORADORES: todo morador do vale fala — ou é mudo POR ESCRITO, com a |
| `falas_em_fila` | suíte (vale) | vale Tripo | 85 s | AS FALAS ESPERAM UMAS AS OUTRAS (fila_de_falas.gd) |
| `fantasma_da_mata` | suíte (vale) | vale Tripo | 100 s (vale novo) | Confere O VULTO DA MATA: o susto que fecha o jogo de mentira |
| `fases_da_lua` | suíte (vale) | vale Tripo | 3 s | AS FASES DA LUA (#229): a noite deixa de ter sempre a mesma claridade. A fase sai do dia do |
| `fauna_do_mar` | suíte (vale) | vale Tripo | 88 s (vale novo) | Confere A FAUNA D'ÁGUA DO VALE (fauna_vale.gd, cardume.gd, tubarao.gd) |
| `fauna_do_mar_procedural` | suíte (vale) | vale procedural | 24 s (vale novo) | O mesmo portão de fauna_do_mar.gd, no estilo procedural: os peixes de corpo |
| `fazenda` | suíte (vale) | vale Tripo | 224 s | Confere A JORNADA DA FAZENDA, fatias 6.1, A IDA, e 6.2, O CHAMADO (#114) |
| `fe_no_vale` | suíte (vale) | vale Tripo | 66 s | Confere A FÉ NO CHÃO DO VALE (#52): os marcos, o que acontece neles e a teia |
| `ferramentas` | suíte (vale) | vale Tripo | 6 s | Confere AS FERRAMENTAS E ONDE BATER: o trabalho existe no vale |
| `festa_da_fe` | suíte (vale) | vale Tripo | 30 s | Confere A FESTA DE CADA FÉ (#52): no dia dela, da uma da tarde até a |
| `fiado_tonho` | suíte (sem vale) | candidato a unidade | 0 s |  |
| `filas_trancadas` | suíte (vale) | vale Tripo | 115 s | AS FILAS TRANCADAS DIZEM O QUE FALTA, E O MORADOR SEM CAMINHO ESPERA PARADO |
| `foco_da_narracao` | suíte (sem vale) | candidato a unidade | 0 s |  |
| `foco_do_e` | suíte (vale) | vale Tripo | 78 s | Confere O FOCO DO E (scripts/prototipo_3d/foco_do_e.gd): de tudo o que responde |
| `fogueira` | suíte (vale) | vale Tripo | 2 s | A FOGUEIRA DO TERREIRO (#86): o modelo certo, e a chama que apaga de dia |
| `folga_dos_moradores` | suíte (vale) | vale Tripo | 21 s | OS MORADORES ANDAM COM FOLGA DAS PAREDES E DAS ÁRVORES (07/10: "tem muito NPC andando colado na |
| `folheto` | suíte (vale) | vale Tripo | 9 s | Confere O FOLHETO NO VALE (#21): o cordel lido no papel |
| `frentes` | suíte (vale) | vale Tripo | 166 s | Confere AS FRENTES DO 2D que não pedem lugar novo no vale: as armas e o ofício |
| `gameleira` | suíte (vale) | vale Tripo | 2 s | A GAMELEIRA DO SAMBAQUI ASSENTA NO CHÃO (#87) |
| `gesto_da_enxada` | suíte (sem vale) | candidato a unidade | 11 s | A terra muda no contato da enxada, não no começo do E (#145) |
| `giro_do_viajante` | suíte (vale) | vale Tripo | 2 s | Confere o GIRO DO VIAJANTE (#209): ele nunca anda de lado deslizando. O corpo |
| `giro_dos_moradores` | suíte (vale) | vale Tripo | 6 s | Confere o GIRO DOS MORADORES (#209): como o viajante, o morador nunca anda de |
| `golpe_de_braco` | suíte (vale) | vale Tripo | 5 s | O GOLPE É DE BRAÇO: SÓ SAI ENCOSTADO E DE FRENTE PARA O ALVO (#208) |
| `golpe_repetido` | suíte (vale) | vale Tripo | 94 s (vale novo) | O E REPETIDO NUM ALVO DE TRABALHO COBRA SÓ O GOLPE QUE ACONTECE (#112) |
| `hud_desempenho` | suíte (sem vale) | candidato a unidade | 0 s | O botão de FPS não deve deixar uma dica gigante presa à coluna direita: abre um |
| `interacao` | suíte (vale) | vale Tripo | 151 s | Confere O E NOS MORADORES e A CONQUISTA DA MISSÃO |
| `interface_individual` | suíte (sem vale) | candidato a unidade | 0 s | Independência, persistência, ancoragem e retângulos reais de componentes |
| `interfaces_de_cartoes` | suíte (sem vale) | candidato a unidade | 0 s | Escala individual do aceite da missão e do aviso de primeira vez (#140): cada cartão tem o seu |
| `interfaces_do_lobby` | suíte (sem vale) | candidato a unidade | 1 s | O mesmo painel muda de escala conforme a tela que ocupa, sem acumular sinais |
| `interfaces_secundarias` | suíte (sem vale) | candidato a unidade | 0 s | Escalas secundárias, retângulos e clique real com fonte global ampliada |
| `interiores` | suíte (vale) | vale Tripo | 8 s | Confere AS CONSTRUÇÕES POR DENTRO, a começar pela igreja (#26) — dentro da |
| `interiores_procedural` | suíte (vale) | vale procedural | 12 s | O mesmo portão de interiores.gd, no estilo procedural: o jogador escolhe o |
| `itens_na_mao` | suíte (sem vale) | candidato a unidade | 35 s | Confere OS ITENS NA MÃO |
| `lapides_no_chao` | suíte (vale) | vale Tripo | 30 s | AS LÁPIDES ESTÃO NO CHÃO, NO SEU LUGAR, TODAS PARA O MESMO LADO |
| `lapides_no_chao_procedural` | suíte (vale) | vale procedural | 0 s | O mesmo portão de lapides_no_chao.gd, no estilo procedural: a laje de pedra com a |
| `latido_caramelo` | suíte (sem vale) | candidato a unidade | 0 s |  |
| `lavoura` | suíte (vale) | vale Tripo | 2 s | Confere A LAVOURA DA CASA (#8): a fazenda do jogador, na frente da casa |
| `licoes_de_luta` | suíte (vale) | vale Tripo | 0 s | As filas reais ensinam os quatro golpes e recebem os sinais de combate (#53) |
| `livro_no_armazem` | suíte (vale) | vale Tripo | 1 s | O E no baú real abre a pergunta; Não preserva o saldo e Sim paga (#68) |
| `lobby_em_video` | suíte (sem vale) | candidato a unidade | 34 s | Confere O LOBBY EM VÍDEO DO MENU, e o pedido que traz o vale 3D de volta |
| `lod_das_pecas` | suíte (vale) | vale Tripo | 1 s | O ALCANCE DAS PEÇAS DO CENÁRIO: o que é caro e está longe deixa de ser desenhado |
| `lod_das_pecas_procedural` | suíte (vale) | vale procedural | 0 s | O mesmo portão de lod_das_pecas.gd, no estilo procedural: as construções são caixas |
| `lod_vegetacao` | suíte (sem vale) | candidato a unidade | 0 s | O LOD precisa cortar blocos no passeio sem apagar a vegetação no mapa alto |
| `lombada` | suíte (vale) | vale Tripo | 170 s (vale novo) | Confere A LOMBADA, A LAPA E A CABRA, a frente do ofício do 2D |
| `lugares` | suíte (vale) | vale Tripo | 0 s | Confere a COSTURA DOS LUGARES do lado 3D: nome de lugar vira posição no |
| `luta` | suíte (vale) | vale Tripo | 7 s | Confere a LUTA no vale (#14): o bicho de caixa cinza, o bote anunciado, a |
| `machado` | suíte (vale) | vale Tripo | 0 s | Confere O MACHADO QUE CHEGA NA PONTE (data/missoes_ponte.json, "buscar_machado"; |
| `mapa_de_solo` | suíte (vale) | vale Tripo | 1 s | O MAPA DE SOLO é o que o shader do terreno lê para misturar as camadas e o que os |
| `mapa_fluxo` | suíte (sem vale) | candidato a unidade | 122 s | Teto de parede para a troca de cena (menu → vale → menu): o laço sai assim que ela acontece |
| `marcador_na_chegada` | suíte (sem vale) | candidato a unidade | 0 s | #135/#144: chegada, histerese e alvo seguinte sem concluir o trabalho |
| `mare_ligada` | suíte (vale) | vale Tripo | 36 s | A MARÉ VEM LIGADA, SE VÊ NO JOGO E O VALE INTEIRO A SEGUE |
| `mare_no_hud` | suíte (vale) | vale Tripo | 1 s | O INDICADOR DA MARÉ AO LADO DO RELÓGIO: "maré enchendo" / "maré vazando", com a dica do que a água faz na |
| `mata_em_manchas` | suíte (sem vale) | candidato a unidade | 52 s | Confere A MATA EM MANCHAS (especies_da_mata.gd, GeoRegionRenderer._build_forest) |
| `matriz_dos_baloes` | suíte (sem vale) | candidato a unidade | 12 s | #121/#124/#127/#132: controles reais, nomes em tela e obstáculos físicos reais |
| `menu_pausa` | suíte (vale) | vale Tripo | 29 s | Confere O MENU DO ESC — que recebeu a coluna de ícones do canto esquerdo |
| `minimapa` | suíte (vale) | vale Tripo | 0 s | Confere A BÚSSOLA DO CANTO: redonda, e apontando a missão em foco |
| `missao_a_vista` | suíte (vale) | vale Tripo | 67 s | A MISSÃO À VISTA (08/10: "continuo sem missões depois da introdução à vila; eu preciso falar |
| `missoes` | suíte (vale) | vale Tripo | 0 s | Confere que o SISTEMA DE MISSÕES do jogo 2D roda no vale, apontando para |
| `missoes_do_comeco_ao_fim` | longo | só com -Longos | — | AS MISSÕES DO COMEÇO AO FIM, jogadas com os controles do jogador |
| `missoes_elos` | suíte (vale) | vale Tripo | 97 s (vale novo) | OS ELOS DAS MISSÕES: cada passo das 23 filas tem para onde ir, a quem falar, de onde tirar o |
| `missoes_secundarias` | suíte (vale) | vale Tripo | 14 s | AS MISSÕES SECUNDÁRIAS DOS MORADORES (docs/projeto/MISSOES_SECUNDARIAS.md) |
| `mochila` | suíte (vale) | vale Tripo | 1 s | Confere A MOCHILA NO VALE (#2) — a tela que veio do 2D, sobre o 3D |
| `modais_escondem_o_hud` | suíte (vale) | vale Tripo | 5 s | Confere QUE TODO MODAL ESCONDE O HUD DO VALE e que os papéis da tipografia |
| `moveis` | suíte (vale) | vale Tripo | 2 s | Confere que TODO MÓVEL DOS CÔMODOS É SÓLIDO NA MEDIDA DELE |
| `musica_do_dia` | suíte (vale) | vale Tripo | 90 s | A MÚSICA ACOMPANHA O DIA, NO VALE DE VERDADE: o relógio anda pelos cinco períodos |
| `mutirao_do_poco` | suíte (vale) | vale Tripo | 5 s | O MUTIRÃO DO POÇO (#80): o trecho da chegada que travou o teste ao vivo de 05/10 |
| `navegacao` | suíte (vale) | vale Tripo | 95 s | Confere A MALHA DE NAVEGAÇÃO DOS MORADORES (navegacao_vale.gd) |
| `navegacao_da_teia` | suíte (vale) | vale Tripo | 3 s |  |
| `navegacao_por_setas` | suíte (vale) | vale Tripo | 1 s | AS SETAS NAVEGAM NOS PAINÉIS COM LISTA, E O ENTER CONFIRMA COMO O E (#227) |
| `nome_do_viajante` | suíte (sem vale) | candidato a unidade | 0 s |  |
| `obras` | suíte (vale) | vale Tripo | 1 s | Confere as OBRAS no vale (#15): onde se toca obra, o plano antes do |
| `obras_com_e` | suíte (vale) | vale Tripo | 47 s | Confere O E NOS SÍTIOS DE OBRA (scripts/prototipo_3d/tecla_das_bancadas.gd): o poço, |
| `oficio` | suíte (vale) | vale Tripo | 4 s | Confere PESCA, COZINHA E OFICINA no vale (#11) |
| `onca` | suíte (vale) | vale Tripo | 11 s | Confere as ONÇAS do vale (#28): onde moram, o que enxergam, como caçam e o |
| `ordem_da_visita` | longo | só com -Longos | — | Mede a distância entre os lugares da primeira missão, para a ordem dela |
| `painel` | suíte (vale) | vale Tripo | 30 s | Confere o PAINEL da tecla J no vale (#19) |
| `painel_ingredientes` | suíte (sem vale) | candidato a unidade | 1 s |  |
| `painel_personagens` | suíte (sem vale) | candidato a unidade | 1 s | Painel MODELOS: as duas abas abrem em cartões e cada cartão abre a ficha no mesmo |
| `paisagismo` | suíte (vale) | vale Tripo | 2 s | Confere O PAISAGISMO DO VALE (paisagismo_vale.gd, paisagismo_vale.tscn, |
| `passagem` | suíte (vale) | vale Tripo | 70 s (vale novo) | Confere que NINGUÉM PRENDE O JOGADOR NUMA PORTA — e que o Pedro para de |
| `passeio_das_especies` | suíte (sem vale) | candidato a unidade | 0 s | Auditoria dos modelos do catálogo, sem construir o vale ou alterar saves |
| `pe_das_arvores_na_encosta` | suíte (vale) | vale Tripo | 0 s | Confere que A ÁRVORE DE ENCOSTA ASSENTA PELO PÉ DO TRONCO (#141) |
| `pedidos_do_arraial` | suíte (vale) | vale Tripo | 70 s (vale novo) | OS PEDIDOS DO ARRAIAL QUE A CHEGADA ABRE: a roça do Cosme e o mutirão da |
| `pedras` | suíte (vale) | vale Tripo | 51 s | PEDRA QUE SE QUEBRA NA MÃO É PEQUENA; PEDRA GRANDE SE QUEBRA DEVAGAR, COM AÇO E TALENTO |
| `pedro_atravessa_a_ponte` | suíte (vale) | vale Tripo | 41 s | O PEDRO ATRAVESSA A PONTE NOS DOIS SENTIDOS (#219) |
| `pedro_pela_estrada` | suíte (vale) | vale Tripo | 4 s | O PEDRO CONDUZ PELA ESTRADA E PELA PONTE (playtest de 07/10: "ao sair da praça, o Pedro tá |
| `pedro_volta` | suíte (vale) | vale Tripo | 42 s (vale novo) | O PEDRO VEM JUNTO QUANDO O JOGADOR APAGA (#92) |
| `pier_legivel` | suíte (vale) | vale Tripo | 0 s | A vara de cenário sai; peixe, pote, piso e ferramenta de pesca permanecem |
| `pier_sem_queda` | suíte (vale) | vale Tripo | 45 s | O PEDRO NÃO CAI NA ÁGUA DO PÍER QUANDO ABRE PASSAGEM PARA O JOGADOR (#236) |
| `placas_e_baloes` | suíte (vale) | vale Tripo | 9 s | PLAQUINHAS DE NOME E BALÕES SÓ DE PERTO, E UM BALÃO POR VEZ (#90) |
| `placas_sem_rosto` | suíte (vale) | vale Tripo | 138 s (vale novo) | A PLACA DE NOME NÃO CAI NO ROSTO DE NINGUÉM E ESMAECE ATRÁS DO QUE ESTÁ MAIS PERTO (#184) |
| `plaquetas_de_tecla` | suíte (sem vale) | candidato a unidade | 0 s | #122: contraste próprio, sem cobrir ícone nem ampliar o clique |
| `ponte` | suíte (vale) | vale Tripo | 158 s (vale novo) | Confere A PONTE DO RIO GRANDE, a frente da trilha do 2D (docs/projeto/MISSOES_DO_2D.md, |
| `pontos_de_restauracao` | suíte (sem vale) | candidato a unidade | 1 s | Confere OS PONTOS DE RESTAURAÇÃO das vagas |
| `popover_do_menu` | suíte (sem vale) | candidato a unidade | 9 s | O POPOVER DOS BOTÕES DA ESQUERDA DO LOBBY (#232): uma caixa compacta com seta no lugar do tooltip em linha |
| `popups_na_tela` | suíte (vale) | vale Tripo | 90 s | OS POPUPS DO MUNDO SÃO POUCOS E TÊM PESO (placas_nomes.gd, dica_tecla.gd, balao_fala.gd, |
| `previa_do_editor` | suíte (sem vale) | candidato a unidade | 0 s | Executar também com --editor para provar o carregamento sob editor_hint real |
| `prioridade_dos_avisos` | suíte (sem vale) | candidato a unidade | 0 s | #132: disputa real dos retângulos do HUD com fala e interação, sem cenário |
| `producao_do_quintal` | suíte (sem vale) | candidato a unidade | 0 s | #160 (e #18): os talentos de produção do quintal têm quem os leia — `pastoreio`, |
| `quintal` | suíte (vale) | vale Tripo | 10 s | Confere O SEGUNDO TUTORIAL — o quintal e o pomar (docs/projeto/MISSOES_DO_2D.md, 2; |
| `rastro_do_curupira` | suíte (vale) | vale Tripo | 30 s | Confere AS PEGADAS DO CURUPIRA E O MAPA DOIDO QUE ELAS PROVOCAM |
| `reacoes_visuais` | suíte (vale) | vale Tripo | 28 s | O GOLPE TEM REAÇÃO VISUAL: LASCAS DO MATERIAL E UM TRANCO NA TELA (#16) |
| `relogio` | suíte (vale) | vale Tripo | 27 s | Confere o RELÓGIO DA PARTIDA: mexer nele pode, com aviso, confirmação e |
| `reservas_do_corpo` | suíte (vale) | vale Tripo | 29 s | AS TRÊS CONTAS DO CORPO (#82): a reserva do dia, o vigor e o fôlego do nado |
| `revoar` | suíte (vale) | vale Tripo | 212 s | Confere O CAPÍTULO 7, O REVOAR DAS ASAS NEGRAS (docs/projeto/MISSOES_DO_2D.md, 4; |
| `rio_grande` | suíte (vale) | vale Tripo | 46 s | O RIO GRANDE NÃO DÁ PASSAGEM FORA DA PONTE (#81), E QUEM CAI NELE VOLTA PELA |
| `rocado` | suíte (vale) | vale Tripo | 1 s | A FOGUEIRA E A BANCADA DO ROÇADO: sólidas, e a bancada se usa com o E |
| `rocado_procedural` | suíte (vale) | vale procedural | 24 s (vale novo) | O mesmo portão de rocado.gd, no estilo procedural: a fogueira e a bancada são |
| `rota_da_fazenda` | suíte (vale) | vale Tripo | 83 s | A condução do convite precisa de malha até o portão, pátio e casarão |
| `rota_do_guia` | suíte (sem vale) | candidato a unidade | 0 s |  |
| `rota_por_terra` | suíte (vale) | vale Tripo | 22 s | Confere que O PEDRO NÃO ENTRA NO MAR para encurtar caminho |
| `rotina_dos_moradores` | suíte (vale) | vale Tripo | 6 s | Confere A ROTINA DOS MORADORES NOVOS: quem são, onde moram, o que fazem a cada hora |
| `salvamento` | suíte (vale) | vale Tripo | 64 s | Confere o SAVE do vale (#7): as vagas, a partida que zera, a ida e a volta |
| `saudacao` | suíte (vale) | vale Tripo | 28 s | A SAUDAÇÃO DE APROXIMAÇÃO: quem tem missão não cumprimenta, e o balão é curto |
| `saveiro` | suíte (vale) | vale Tripo | 47 s (vale novo) | Confere O SAVEIRO DO MESTRE QUIRINO e a missão da piaçava |
| `selecao_idioma` | isolado | um Godot só dele | — | Perfil isolado pelo runner. O início não pode carregar a abertura sem escolha |
| `seta_em_orbita` | suíte (sem vale) | candidato a unidade | 0 s | #196: o chevron da missão ORBITA o jogador em vez de grudar na borda da tela |
| `smoke_opening` | suíte (sem vale) | candidato a unidade | 202 s |  |
| `sobrevoo_livre` | fora da suíte | SceneTree própria (herda de uma ferramenta) | — | O SOBREVOO DO MENU NAO ATRAVESSA NADA, no estilo Tripo |
| `sobrevoo_livre_procedural` | fora da suíte | SceneTree própria (herda de uma ferramenta) | — | O mesmo portao de sobrevoo_livre.gd, no estilo procedural: o jogador escolhe o |
| `som_dos_golpes` | suíte (vale) | vale Tripo | 26 s | CADA GOLPE NUM ALVO DE TRABALHO TEM SOM (#89) |
| `sons_da_colheita` | suíte (vale) | vale Tripo | 13 s | O GOLPE TEM SOM: a pedra, o tronco, o capim e a ostra deixam de bater em silêncio |
| `sons_do_jogo` | suíte (vale) | vale Tripo | 2 s | NENHUM SOM QUE O JOGO PEDE FICA SEM ARQUIVO, NENHUM ARQUIVO FICA SEM DONO, E AS PORTAS SOAM |
| `tarefa_concluida` | suíte (vale) | vale Tripo | 5 s | A TAREFA CONCLUÍDA SE VÊ E SE OUVE (07/10: "precisamos evidenciar melhor que o jogador |
| `tarefa_no_hud` | suíte (sem vale) | candidato a unidade | 0 s | O ALTO DA TELA DIZ A TAREFA (#83), e não o texto da missão |
| `teia_social` | suíte (vale) | vale Tripo | 1 s | Confere A TEIA SOCIAL do vale — a tela, não o sistema |
| `teia_talentos` | suíte (vale) | vale Tripo | 1 s | Confere A TEIA DE TALENTOS do vale — a tela, não o sistema |
| `tela` | suíte (sem vale) | candidato a unidade | 0 s | Perfil isolado pelo runner. O jogo abre em tela cheia, F11 alterna e a |
| `tela_carregamento` | suíte (sem vale) | candidato a unidade | 134 s | Tela de carregamento: a capa segue a hora (dia ou noite) para qualquer hora, ao entrar |
| `terras_por_posicao` | suíte (sem vale) | candidato a unidade | 0 s | #9: preço histórico, confirmação nativa, posse/save e contorno no mapa real |
| `terreno_editor` | suíte (sem vale) | candidato a unidade | 6 s | Portão da prévia: a cena precisa guardar a mesma terra para as duas telas de |
| `terreno_unico` | suíte (sem vale) | candidato a unidade | 58 s |  |
| `testador_sessao` | suíte (sem vale) | candidato a unidade | 1 s | O botão TESTAR e o painel da sessão do testador (#183): o modal mostra o que a ponte |
| `travessia` | suíte (sem vale) | candidato a unidade | 0 s | Travessia: uma narração por legenda, nos tempos do Whisper, e a música própria |
| `travessia_da_ponte_central` | suíte (vale) | vale Tripo | 18 s | Rotas que raspavam o corrimão, mais as duas cabeceiras reais da ponte |
| `travessia_em_video` | suíte (sem vale) | candidato a unidade | 1 s | A travessia em vídeo (#129): cada fala toca o seu clipe LTX atrás da legenda, a última |
| `tubarao` | suíte (vale) | vale Tripo | 52 s | O tubarão existe na água funda, persegue o jogador que nada lá, ataca (tela escura) |
| `vagas_no_jogo` | suíte (vale) | vale Tripo | 50 s | Duas vagas reais no perfil isolado do runner: cancelar não grava; |
| `vida` | suíte (vale) | vale Tripo | 6 s | Confere que a VIDA do jogo 2D chegou ao vale inteira: no HUD, e com a queda |
| `vista_do_alto` | suíte (sem vale) | candidato a unidade | 0 s | #18: a referência abre no alto; uma parede continua cortando o braço real |
| `vozes_dos_moradores` | suíte (vale) | vale Tripo | 14 s | Confere AS VOZES E OS QUATRO IDIOMAS DOS MORADORES (data/npcs_3d.json): toda fala nos quatro idiomas |
