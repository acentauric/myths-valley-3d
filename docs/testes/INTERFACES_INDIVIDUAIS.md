# Escala individual das interfaces — #140

Em AJUSTAR → Cenário → Interface, cada componente oferece 65%, 80%, 100%,
115%, 130% e 150%. A alteração vale imediatamente e persiste no perfil;
a seta de restauração devolve só aquele componente a 100%. O botão ao fim
da lista restaura todos os componentes. Texto global e botões do canto
mantêm seus controles existentes.

Há escolhas separadas para missão, relógio, vida, fôlego, vigor, minimapa,
barra de mão, fala, nomes, E de interação, avisos, mochila/baú, caderneta,
almanaque, talentos, laços do povoado, pausa e conversa/tutorial.
Texto, imagens e área clicável são transformados juntos. Painéis grandes
limitam a ampliação à janela; os cantos e centros de ancoragem permanecem.

O HUD calcula o espaço usando a escala de cada medidor. Caso falte largura,
o relógio e os medidores passam para baixo da missão. A matriz dos balões
recebe os retângulos reais da missão, minimapa e barra. Avisos de espera
procuram espaço abaixo do HUD ampliado e cedem diante da fala; o rodapé
acompanha a altura da barra de mão.

## Evidência

- `interface_individual`: independência, persistência, reset individual/todos,
  ancoragem inferior, área clicável, matriz e avisos; três resoluções
  (1280×720, 1440×900, 1920×1080), nos três idiomas. Verde em 4–5 s.
- `--sem-escala` tira a transformação em memória: uma falha, sem erro de script.
- `idiomas`: 764 campos em 44 arquivos; as pendências existentes seguem declaradas.
- `prioridade_dos_avisos` e `tarefa_no_hud`: verdes após a mudança.
- `composicao_do_hud`: verde com a cena real; com `--componentes` usa 150%
  e relógio a 65%. Capturas PT/EN/ES conferidas em
  `scratch/componentes-interface/idioma-0.png` a `idioma-2.png`.

Ainda falta a revisão de todas as telas secundárias e combinações com tamanho
global de texto ampliado para encerrar a #140. A interface do testador não é
incluída nessas preferências. A execução gráfica mantém os avisos já conhecidos
de liberação de texturas ao encerrar, sem erro de script durante o teste.

### 07/10/2026: foco durante a fala longa (#140, #132)

A caixa longa reserva seu retângulo real, incluindo a transformação da camada e as escalas individuais. Componentes do HUD que o intersectam ficam transparentes durante a conversa; sua visibilidade original continua pertencendo ao dono do aviso, sem ressuscitar notificações expiradas. Missão e medidores fora da caixa permanecem. Plaquinhas do mundo cedem ao abrir a fala e voltam ao terminar.

O tutorial do corpo declara `interfaces` em cada linha de `missoes_guia.json`. `Dialogo.falar` aceita essa lista paralela como quarto argumento opcional; a linha atual destaca somente o componente declarado, no retângulo renderizado. Perguntas e fechamento limpam esse foco. Nenhuma dedução depende de palavras da prosa regional.

Portão `foco_da_narracao`: reserva, componente externo preservado, troca de foco, restauração da cor e aviso expirado. A falsificação `--sem-reserva` reprova uma asserção. `interface_individual`, `prioridade_dos_avisos` e `idiomas` acompanham. Captura real no armazém: `scratch/fiado-tonho/tutorial-foco.png`; a pergunta/pagamento do livro continuam com zero falhas. A #140 permanece aberta pelos componentes secundários ainda pendentes.

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

### 07/10/2026: telas do lobby e confirmações (#140)

O catálogo passa a 31 componentes, com menu, histórico, ajustes, vagas/nome,
créditos, legenda da travessia, galeria e perguntas. O painel reutilizado do
lobby consulta a chave da tela atual e mantém uma única conexão de escala.
O limite considera o pivô e a posição: ampliar um painel no canto respeita
o espaço restante, assim como ampliar um modal central.

`interfaces_do_lobby` alterna seis telas em 1280×720 e 1920×1080; zero falhas
em 5 s. `--sem-revincular` reproduz duas falhas ao fazer o histórico herdar
a escala pequena do menu. Regressões de interfaces individuais, secundárias
e idiomas verdes (783 campos). Cinco capturas em `scratch/interfaces-lobby/`
foram inspecionadas: menu/vagas a 65%, créditos a 80%, histórico/ajustes
ampliados até o limite da janela. A execução gráfica não apresentou erro
de script; os avisos já conhecidos de texturas permanecem no encerramento.
A revisão do folheto e de todas as combinações globais ainda impede fechar #140.

### 07/10/2026: papel do cordel (#140, parcial)

O 32º componente é o folheto: capa, versos, assinatura, preço e teclas ficam
na mesma tábua transformada. O fundo permanece cobrindo a janela; os limites
usam o papel e sua sombra, permitindo ampliar até a borda sem cortar leitura.
O desenho continua medido em 1280×720 e centrado na área lógica da janela.

`escala_do_folheto` confere 65%, 100% e 150% solicitado, duas dimensões de
janela, transformação comum e fechamento por Esc: verde em 7 s. O mutante
`--sem-texto` deixa os versos pela metade e reprova seis verificações.
`folheto` integrado passa em 41 s, incluindo coleta, leitura e troca de tela.
Três capturas reais a 65%, padrão e máximo útil foram conferidas em
`scratch/escala-folheto/`. A revisão geral da #140 continua aberta.
