# Teste automático do jogo

O **Teste automático** é nosso jogador de testes local: um algoritmo determinístico
e exploratório que observa o estado do jogo, escolhe uma ação e acompanha seu
resultado. Seu objetivo é concluir a história implementada, atualmente até
`fazenda_chegada`. Os capítulos posteriores ainda não são jogáveis. A política
está em desenvolvimento; iniciar uma sessão não garante terminar a campanha.

Em 07/10/2026, a campanha retomada V21 confirmou o término da história
implementada no pátio da fazenda: 483,44 s nessa sessão, 110 decisões locais,
custo zero, jogador (118,2; 3,6; -308,2), `implemented_story_completed=true`.
As sessões anteriores e os bloqueios corrigidos permanecem documentados;
isso não declara concluídas as cadeias laterais nem capítulos futuros.
Evidência e limites em [NAVEGACAO_FAZENDA.md](NAVEGACAO_FAZENDA.md).
O relatório V21 preserva código Godot 1 da corrida de encerramento do watchdog,
sem erros de script. A nova espera de dez segundos passa em regressão e foi
confirmada na parada real por F8: botão do menu abriu perfil novo, 19 decisões,
33,2 s de jogo pronto, `user_stop`, código Godot 0 e captura final.

## Como iniciar e encerrar

No menu inicial, escolha **Testar**, ao lado de Explorar. Abre um modal com os apoios que
a ponte encontrou na máquina, o orçamento e a duração; **Iniciar** abre uma janela com uma
partida nova em perfil isolado, preservando os saves do jogador. `JOGAR_SOL.cmd` segue
iniciando o determinístico direto. Requer o projeto de desenvolvimento, Python 3.10+
disponível como `python` e Godot. O botão fica desativado nas exportações que não contêm a
ponte Python.

| Apoio | Papel | Disponível quando |
|---|---|---|
| **Determinístico** | base, sempre ligado: o robô local joga pelas regras do jogo, sem custo | sempre |
| **Jev** (TypeSafe) | segundo nível, quando o determinístico trava | `TYPESAFE_API_KEY` no `.env` ou no ambiente e o endpoint atende |
| **GPT** (OpenAI) | terceiro nível, quando o Jev também não destrava | `OPENAI_API_KEY` no `.env` ou no ambiente e o endpoint atende |

A detecção é a própria ponte (`python tools/jev/jogar.py --detectar`, que imprime um JSON): ela
diz se a chave existe e se a porta do serviço responde, **nunca o valor da chave**. Apoio
indisponível aparece desativado, com o motivo ("Sem chave TypeSafe no .env"). O orçamento
padrão é US$ 0,10, com teto autorizado de US$ 0,50, e só vale com Jev ou GPT marcados; a
duração em minutos é opcional (zero, sem limite). Ao reabrir o modal, a linha **Última
sessão** mostra o progresso da sessão anterior ("43,5% · O mirante 2/6 · 412 ações").

**Fica uma janela só (#175).** Pelo botão Testar, o menu não se fecha ao disparar o
`jogar.py`: espera a ponte criar o arquivo `user://testador_pronto.txt`, o que ela faz na
primeira chamada autenticada do jogo da sessão (`--pronto`), e só então se fecha, com o
áudio dele. Se o python sair antes disso, o menu continua aberto e mostra o erro. Ao
encerrar a sessão (F8, tempo, janela fechada ou erro), o `jogar.py --voltar-ao-menu`
reabre o menu com o perfil normal do jogador, para ele não ficar sem janela; o
`JOGAR_SOL.cmd` e as execuções pela linha de comando não passam esse parâmetro e seguem
fechando tudo.

Não há limite padrão de tempo. F8 ou fechar a janela encerra a sessão;
`JOGAR_SOL.cmd --seconds 600` limita uma execução a dez minutos. Só o determinístico não
usa API nem consome créditos. Com Jev ou GPT marcados, o gasto é estimado localmente e
barrado no orçamento da sessão. F8 e F7 continuam funcionando com telas e diálogos modais.

A câmera do teste abre um pouco mais afastada (cinco passos do `mv_zoom_out`, de 8 m para
cerca de 9,75 m) para quem assiste ver o personagem, os moradores e o caminho; a preferência
de câmera do jogador fora do teste não muda.

### O painel da sessão

Usa o visual do HUD (laca verde-escura, borda dourada suave, canto chanfrado e o tema do
menu). Fica num canto livre da tela (o primeiro que não encosta na barra de mão, no minimapa
nem no resto do HUD, grupo `obstaculos_do_hud`; na carga, sai de cima do "CARREGANDO", da
rosa girando, da marca e do almanaque) e mostra: quem decidiu a ação atual
(Determinístico, Jev ou GPT, com cor e, no plano, "plano 2 de 3"; em recuperação local,
"recuperação local"); a **ação em palavras** ("Aproximar de Tonho") com o nome técnico na
dica; o motivo; a missão em curso e o contador; a **barra de progresso até zerar o jogo**,
dividida em marcos por capítulo, com a linha "Capítulo: Chegada ao arraial · 13/16 · 43,5% da
história", o próximo objetivo e a estimativa de ações e tempo restantes no ritmo atual; as
últimas quatro decisões; os sinais de trava; e o gasto. O **Parar** é um botão pequeno do
jogo no rodapé, com o F8 numa plaqueta de papel ao lado, como nas dicas de interação.

## Cenários de verificação ao vivo

`python tools/jev/jogar.py --robot --cenario <nome> --seconds N` abre a partida já no meio de um
caso, para provar uma regra do testador sem jogar a campanha toda. Só existe para verificação:
o relatório registra "Cenário de verificação" e, sem o parâmetro, a sessão é a campanha de
verdade. O robô continua sem teleportar nem mexer em missão ou item; quem arruma o estado é o
`sessao.gd` (`_aplicar_cenario`), pelas mesmas propriedades que os portões do jogo usam.

| Cenário | Estado de partida | O que prova |
|---|---|---|
| `lenha` | tutorial feito, a ponte em "Trinta e seis paus", a picareta na mão, o machado só na mochila, a 6 m do tronco do marcador | #207: põe o machado na barra, seleciona e a lenha sobe |
| `noite` | o mesmo, às 22h, fôlego 18, a 9 m da porta de casa | #192 (o relógio anda antes e depois do amanhecer) e #191 (acorda em casa e sai pela porta) |
| `varal` | o viajante a 2,4 m do poste do varal da Casa do arraial 5, com a câmera atrás do poste | #201: a câmera da sessão gira para o lado livre |
| `f7` | como `lenha`; aos 12 s entra um F7 pela janela, 8 s depois outro | #206: assume, o testador para, devolve, recalcula |

Evidência de 08/10/2026 (perfil novo, sem API, custo zero): `lenha` pôs o machado na barra em 6
ações e a lenha foi de 0 a 17; `noite` virou a noite, acordou às 06h00 do dia 2, saiu pela porta
(`exit_home`) aos 278 s e seguiu o objetivo, e o relógio andou de 22h a 13h; `f7` imprimiu
`assumiu=true testador_parado_no_manual=true devolveu=true voltou_a_agir=true` e o relatório
contou 8,5 s de controle manual. Em `varal` a câmera saiu de trás do poste em menos de 4 s, mas
dois quadros mostraram o viajante parcialmente coberto por uma palmeira fina e pelo beiral de uma
casa, que não barram o raio: a #201 segue aberta. A sessão em English mostrou HUD, painel e
missão em inglês depois do ajuste da tela de idioma; o motivo da decisão ("Aguardar a fala…")
ainda sai em português.

## Escada de decisão

O determinístico joga sozinho. A camada `tools/jev/escada.py` só observa se ele travou e
sobe um degrau de cada vez. Qualquer um destes sinais sobe o degrau:

- o passo da missão, o contador (`2/3`), as cadeias, o inventário e as obras não mudam por 25
  ações ou 90 s de jogo;
- laço de posição: 20 ações seguidas num raio de 6 m sem progresso;
- recusa repetida: o mesmo aviso do HUD ("Precisa de Machado.") aparece de novo;
- a dica do E aponta para um morador que o passo não pede, por 15 ações;
- `possible_stuck` do vigia do controlador.

Os três últimos são sinais leves: só valem depois de 8 ações sem progresso.

1. **Recuperação local**, barata: renova as tentativas do robô e o põe em modo de recuperação
   (alvo recalculado pelo pedido atual, ferramenta exigida, material mais próximo) por 12
   ações.
2. Sem progresso, o **Jev** recebe um contexto enxuto (passo, requisito, inventário e mão,
   últimas 10 ações, recusas, alvos próximos e `failed_actions`, as ações que já falharam com
   quantas vezes, com a ordem de não repeti-las) e devolve um **plano de 3 ações**. Um plano
   feito só de ações que falharam é recusado (`plan_rejected`) e pedido de novo uma vez, com
   palavras mais duras e sem essas ações nas opções. O determinístico executa o plano.
3. Se o progresso anda, volta ao determinístico e o contador zera. Se não anda, o **GPT**
   recebe o mesmo contexto mais o plano que falhou e devolve outro (2 a 5 ações).
4. Se o GPT também falha, a sessão **não encerra** (#183): a resposta da ponte traz, uma vez,
   `"blocked": {"step", "reason", "tries"}` e o jogo abre o modal "Deseja assumir o controle?".
   No pedido seguinte o jogo manda `"blocked_choice"`: `stop` encerra como antes, com
   `blocked_step` no relatório; `takeover` espera o F7 e, na devolução, zera a trava; `alternate`
   ou `timeout` (ninguém respondeu) entram na **rota alternativa**: direto ao alvo pela rota da
   malha, sem o guia; depois outra missão disponível; depois explorar; em ciclo, até o tempo ou o
   orçamento acabarem. Cada etapa vai para o relatório (`blocked_prompt`, `blocked_choice`,
   `alternate_route`). Não há atalho de teste que pule passo, e o testador nunca altera a missão.

O GPT padrão é o **GPT-6 Luna** (`gpt-6-luna`; `OPENAI_TEXT_MODEL` no `.env` manda), com até
4000 tokens de saída e `reasoning_effort: low`. Resposta vazia ou JSON inválido grava
`gpt_invalid_answer` (o `finish_reason` e os primeiros 200 caracteres, sem chaves) e repete a
chamada uma vez.

**Rota na malha (#240).** O `sessao.gd` manda em `route` a rota até o alvo do objetivo
(`target`, `target_name`, `points`, `next`, `reachable`, `length`) e oferece `follow_route`. Indo a
esse alvo, o robô segue a rota em vez de andar por direção; alvo sem rota (`reachable: false`)
fica evitado por 40 decisões (`unreachable_target`) e o robô vai a outro do mesmo tipo ou
explora. Andar de lado ou de costas só serve de último recurso para desentalar.

**Continuar (#235).** Ao fim da sessão e a cada passo concluído, a ponte grava
`tools/temp/jev/ultima_sessao.json` (`perfil` e `resumo`: passo, capítulo, %, ações, custo,
quando). `--detectar` devolve esse resumo em `ultima_sessao.continuar`, e
`jogar.py --robot --continuar` reabre o mesmo perfil e escolhe CONTINUAR (ou a vaga 1) em vez
de partida nova.

Freios de custo: no máximo 2 chamadas do Jev e 1 do GPT por passo de missão (uma resposta
inválida repete o mesmo apoio dentro do teto), 15 s mínimos entre dois pedidos, reserva de
orçamento antes de cada chamada (a mesma conta do modo Jev) e o painel mostrando quando e por
que escalou. Sem Jev nem GPT marcados a escada só faz a recuperação local; nunca encerra.

**Aprendizado barato:** quando um apoio destrava um passo, o par (sinais, plano que
funcionou) vai para `aprendizado.json` da sessão e para o relatório, como candidato a regra
nova do determinístico.

`--escada-simulada` roda a escada com planos locais no lugar do Jev e do GPT (zero chamadas
e custo zero), para ver o painel e o relatório sem gastar crédito. As chamadas reais ao Jev
(`step_1..step_3`, uma escolha por posição do plano) e ao GPT (JSON com `plan` e `reason`)
foram escritas e testadas só com respostas falsas (`tools/jev/test_escada.py`): o formato
precisa de uma sessão curta real para ser conferido, e a tarifa do GPT em `jogar.py` deve ser
confirmada antes.

## Progresso até zerar o jogo

O painel e o `relatorio.md` medem quanto falta para zerar a história implementada: os passos
cumpridos das cadeias de enredo (`main`) sobre o total delas, lidos do estado das cadeias de
missão (`cadeia_de_missoes.gd`). Cada cadeia é um capítulo e um marco na barra. O relatório
traz a porcentagem final, o capítulo, o ritmo (ações e tempo por passo e a estimativa até
zerar), o **ponto mais distante** da sessão, a curva progresso × ações e quem destravou cada
capítulo (determinístico, Jev ou GPT).

## Como decide

A ponte apresenta objetivo atual, requisitos da missão, inventário, candidatos
de interação, direções e resultados recentes. O robô usa essas observações
estruturadas; não depende de reconhecimento visual das capturas.

As regras priorizam a exigência atual, selecionam a ferramenta necessária,
seguem o marcador e tentam a interação do alvo. Conversas próximas não devem
substituir um recurso pedido. Ações sem mudança observável acionam recuperação.
O robô observa as soleiras externa e interna para atravessar a porta usando
W. Mantém os waypoints também perto dos obstáculos; colisão sem deslocamento
por dois segundos pede outra direção. Reconhece o mapa aberto e o fecha com
Escape. Ao aproximar o baú, confirma que o E pertence à casa, sem iniciar uma
conversa com Pedro por engano. Aguarda pessoas que já estão falando.

O robô usa os controles normais de movimento e interação, sem teleportar,
injetar itens ou alterar o progresso das missões.

**Dentro de um cômodo, a porta vem primeiro (#191).** Com o robô na casa, na igreja
ou no casarão, o estado traz `room` com a lista de destinos do catálogo que ficam do
lado de fora; escolher seguir, aproximar, explorar ou o objetivo para um deles vira
"ir à soleira de dentro e sair" (`exit_home` na casa herdada, `exit_room` nos outros),
e só depois a rota para o alvo. Preso num canto (três ações de deslocamento sem sair do
lugar), força a saída duas vezes e então sonda uma direção livre; a saída sem efeito
entra no relatório como bloqueio. Acabado o tutorial o Pedro não conduz mais: `follow_pedro`
sai do catálogo e ele passa a ser abordado como morador (`approach_MoradorPedro`), no máximo
seis vezes por pergunta pela próxima cadeia.

**A fala aberta espera o E (#220).** A fala da missão e a conversa do E ficam no balão enquanto o
robô está a até 6 m e à vista dela, e quem passa a página (e na última a fecha) é o E. O estado traz
`speech_awaiting_e` (o morador com a fala aberta) e `speech_has_more_pages`; com eles o catálogo oferece
`speech_next` (E), que a política escolhe antes de seguir o Pedro ou de abordar alguém. Afastado, ou
sem apertar nada por 25 s, a fala acaba pelo tempo e a condução não trava.

**A câmera não esconde o viajante (#201).** Só na sessão de teste (o nó
`tools/jev/camera_do_teste.gd`, criado pelo `sessao.gd`; o jogo comum e as camadas da câmera
ficam como estão), a cada quadro um raio vai da câmera ao peito e à cabeça do viajante. Se
algo opaco barra (poste, tronco, parede, árvore ou chão; morador e bicho não contam), depois
de 0,2 s a câmera gira em órbita para o lado livre mais próximo, no ritmo máximo de 3,2 rad/s,
e se nenhum lado serve ela aproxima até passar à frente do obstáculo, nunca abaixo de 1,6 m.
Livre por 1,5 s, a distância volta ao que era, devagar. Cômodo (câmera de cima) e nado ficam
de fora. As capturas do relatório só saem com o viajante à vista: encoberto, a câmera é
reposicionada na hora e o quadro sai uns quadros depois. Encoberto por mais de 1,5 s vira a
seção "Viajante encoberto pela câmera" do relatório, com o tempo, o lugar e a captura. O
portão de geometria é `tools/jev/test_camera.gd` (poste, parede, morador), e o trecho de 50
ações paradas em 2/36 é um caso do `test_robo.py`.

**F7 assume o controle (#206).** Quem assiste pega o jogo na mão sem encerrar a sessão:
F7 (ou o botão "Assumir o controle") suspende o testador, determinístico, Jev ou GPT. A fila
dele morre na hora (a decisão em voo é descartada, as teclas que ele segurava são soltas e
a caminhada guiada é cancelada), uma faixa vermelha no topo diz "Controle manual · F7
devolve" mesmo com telas abertas, e o teclado e o mouse são do humano; o relógio, a física e
o resto do jogo seguem normais. F7 de novo devolve: a ponte manda o robô esquecer o plano
velho (rota, contorno, tentativas, cobertura) e ele recalcula do estado novo, de missão,
inventário e posição. F8 continua encerrando a sessão em qualquer estado, e se ela acaba
durante o controle manual o trecho é fechado antes. O relatório ganha a seção "Controle
manual (F7)", uma linha por trecho: quando, por quantos segundos, a última ação do testador
antes, o que mudou (missão, itens, mão, deslocamento) e as capturas do início e do fim,
para virarem regra nova do determinístico ou caso da escada da #183.

**A ferramenta que o alvo pede vem como dado (#207).** O estado traz `tool_requirement`
(o alvo ao alcance, a família da ferramenta, onde ela está: `na_mao`, `na_barra`,
`na_mochila` ou `falta`, a vaga e o texto da dica do E), `last_refusal` (a última recusa do
golpe, com a ferramenta e há quantos ms) e `inventory.hand_bar` (a barra de mão inteira,
vaga por vaga, com a família de cada item). Diante de "Ponha na mão: X" ou "Precisa de X",
o robô decide sem IA: X na barra vira `hand_N`; X só na mochila vira abrir a mochila,
pegar com E, soltar numa vaga livre da barra, fechar e `hand_N`; X inexistente vira a nota
"Falta ferramenta X" na justificativa. O passo para depois de 40 ações sem a ferramenta
chegar à mão. Coberto por `tools/jev/test_robo.py`, com a picareta na mão e o machado na
mochila.

**O relógio é do jogador (#192).** O testador nunca pausa, acelera nem adianta o
relógio: a tecla de adiantar a hora (T) saiu do catálogo, os botões e a placa do
relógio e da velocidade ficam fora dos cliques, e no menu de pausa o E só vale na
linha de Salvar jogo (as do relógio, da velocidade e de sair não são dele). Um
vigia no `sessao.gd` olha o dia a cada volta: sem tela, fala nem pergunta aberta,
se o relógio fica pausado ou em Parada por dois segundos, seguro por um motivo por
45 s, ou com a hora sem andar por 20 s, o relatório ganha uma linha em "Relógio
parado" com a causa, a última ação, quem segurava e a captura. Cada parada é
registrada uma vez e o vigia rearma quando o dia volta a andar.

Após 30 segundos sem progresso de missão, inventário ou obra, ou tentativas
repetidas no mesmo contexto, entra a exploração. Ela experimenta interações
próximas, orientação para outros alvos, trabalho com ferramentas, observação
e interfaces. Registra a cobertura por região, alvo, mão e seleção da tela.
Depois de esgotar a vizinhança, visita os lugares menos experimentados em ordem
de proximidade. Telas têm um teto de oito sondagens por abertura. Mudança real
de progresso devolve o controle às regras da missão e reinicia a cobertura.
Exigências disponíveis têm prioridade por até três tentativas por contexto,
evitando abandonar uma caminhada guiada longa só porque passaram 30 segundos.
Não há escolha aleatória.

As fontes de lenha e pedra permanecem estáveis durante a aproximação e mudam
quando esgotadas ou inacessíveis ao nível/ferramenta atuais. O planejamento soma
material direto e ingredientes das receitas faltantes, com o rendimento real
de cada receita e o custo vigente da obra. Não fabrica outra obra só porque
ela ocupa a primeira linha da lista. Duas viagens sem aproximação disparam
contornos físicos limitados; viagens longas que aproximam do alvo continuam.
Golpes em andamento e dano parcial contam como trabalho, evitando interromper
um corte para explorar outra interface. Fôlego baixo leva à comida disponível
na mochila por sua seleção normal e F. Novas cadeias liberadas são perguntadas
ao Pedro depois da anterior; o diário retoma a missão principal pelo painel.
Sem comida e com fôlego baixo, volta pela porta, aproxima a cama e confirma
o descanso pelo E e pela pergunta normal. A observação da fazenda distingue
uma cadeia que aguarda a manhã seguinte de outra que abre conversando com
Pedro: após encerrar a cadeia de fé, o testador dorme para alcançar o dia do
convite, mesmo que ainda tenha fôlego. Não chama a função de mudar o dia.

Receitas reconhecidas no estado observado são selecionadas pela exigência
atual, em sua bancada e aba correspondentes. Falta de ações disponíveis não
autoriza inventar comandos: se o jogo só oferece aguardar, a sessão registra
essa espera para análise.

Mesmas observações e mesma memória produzem a mesma escolha. Física, relógio e
posições dos moradores podem variar entre partidas: determinismo da política
não significa repetição exata de todos os frames. Ao mudar o jogo, as regras
precisam reconhecer os novos requisitos e interpretar os resultados reais;
uma sequência fixa de teclas não basta.

## Ritmo e manutenção

Há uma pausa de apresentação de 0,7 segundo antes das ações pontuais, e de
1,4 segundo antes de arar, plantar ou regar. Caminhadas já têm duração própria.
As pausas permitem acompanhar cada operação, além do tempo da animação do jogo.

`tools/jev/robo.py` contém a política. Alterações nele são recarregadas entre
ações, preservando a partida e a memória. Mudanças na ponte `jogar.py`, no menu
ou no controlador Godot `sessao.gd` exigem nova abertura.

O lançador informa a pasta dos relatórios em `tools/temp/jev/`; `--output`
permite escolher outra. `eventos.jsonl` registra observações, escolhas e
resultados, e as capturas documentam o que foi exibido. Esse teste exploratório
complementa os portões automatizados do projeto.

Capturas contínuas usam JPEG com qualidade 85%; o relatório também reconhece
as capturas PNG anteriores. O robô salva pelo menu normal após carregar, a
cada cinco minutos ou depois de obter oito materiais. Espera golpes em curso,
navega até Salvar, confirma e registra a resposta antes de voltar ao jogo.
Falha ou interrupção retoma o último save disponível; observações posteriores
ao save não são transformadas artificialmente em progresso.

**O idioma do jogador atravessa o perfil isolado (#180).** O botão Testar manda o idioma
atual do menu para o `jogar.py` (`--idioma pt|en|es|zh`); o `sessao.gd` o grava no
`user://` novo da sessão antes da primeira cena, e daí o menu, a tela de carga, o HUD,
as falas em texto e o painel do testador (`tools/jev/textos.json`, nos quatro idiomas) saem
nele. Só o idioma passa: o save e o progresso do jogador não entram. Sem `--idioma`, rodar
o `jogar.py` pela linha de comando segue como antes. O relatório traz a linha "Idioma da
sessão" e o `resumo.json` o campo `language`.

`--profile tools/temp/meu-perfil-de-teste` retoma explicitamente um perfil
isolado já usado, mantendo a saída de relatório nova. Sem essa opção, cada
execução conserva a partida nova em seu próprio perfil. Não use o perfil de
saves pessoais do Godot para uma sessão automatizada.

`relatorio.md` é atualizado a cada 30 segundos e novamente no encerramento.
Inclui frequência e duração das ações, posições antes/depois, deslocamento,
etapas observadas, resultados sem avanço e links das capturas. Distingue o
deslocamento início/fim do trajeto amostrado a cada 0,5 segundo, incluindo
retornos e desvios. Registra também o tempo de decisão/apresentação. Nenhum
dos dois cálculos mede cada frame da curva. A ausência temporária do objetivo
durante uma fala não conta como conclusão de etapa.
Para reconstruir o relatório de uma sessão existente:

```powershell
python tools/jev/relatorio.py tools/temp/robo-sem-limite
```

Acrescente `--watch` para atualizar enquanto o PID daquela sessão estiver vivo.
O JSONL é a evidência original; o Markdown serve à análise contínua. Bloqueios
reportados e muitas ações sem avanço são indícios, não diagnóstico automático
da causa nem prova de que todos os sistemas foram testados.

Relacionados: #159 (testador), #118 (ponte), #146 (orientações) e #154 (acesso à porta).

## Evidência de 07/10/2026

Na retomada V16, a coleta/fabricação e o painel de obras concluíram o Mirante;
as três visitas, conversas e escolha no marco concluíram A fé do arraial.
A tentativa de abrir O convite pelo E revelou uma regra faltante na política:
essa jornada começa na manhã seguinte à fé, pelo dia do jogo.

A V17 retomou o mesmo perfil salvo em D, sem editar a partida. Aos 114,76 s
aproximou a cama, aos 117,88 s pressionou E e aos 119,03 s confirmou Sim.
Aos 124,29 s o estado nativo passou de dia 25 para 26, fôlego 27,8 → 77,8
e `farm.day_marked=true`. Relatório e JSONL:
`D:/MythsValleyPlaytestRuns/robo-campanha-retomada-v17/`.
84 testes Python passam; remover a regra da manhã provoca uma falha e nenhum
erro, reproduzindo a escolha indevida de procurar Pedro. A regressão de
fôlego baixo também cobra porta → cama → E e preserva inventário/energia.
A campanha continua: este descanso e os capítulos anteriores não provam
conclusão de `fazenda_chegada`; #159 permanece aberta.

O chamado após o sono expôs outra prioridade: seguir Pedro antes de sair
do interior tentava atravessar a parede. A porta passa a preceder a caminhada
guiada externa. Sem reiniciar V17, `exit_home` aos 419,60 s concluiu aos
423,80 s fora da casa, em [65,4; 5,1; −208,7]; aos 475,83 s seguia Pedro
em [122,7; 2; −263,5]. 85 testes Python passam; retirar essa prioridade
reproduz uma falha sem erros. O capítulo da fazenda segue em andamento.

Uma sessão de 300 segundos desde o jogo pronto, em perfil novo e sem API,
registrou 67 decisões, entrada pela soleira, retirada de balde/enxada/maniva
no baú e arar → plantar → regar, chegando à etapa da lenha (10/16).
`tools/temp/robo-navegacao-final/relatorio.md` contém a evidência local.
Isso não demonstra coleta de lenha/pedra nem conclusão da campanha. As
orientações ao jogador humano e o destrancamento da porta continuam sob
#146/#154. Uma nova sessão sem limite usa o código final e registra a campanha.
