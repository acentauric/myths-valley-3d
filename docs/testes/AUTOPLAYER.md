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

No menu inicial, escolha **Testar**, ao lado de Explorar, ou execute
`JOGAR_SOL.cmd`. O lançador abre outra janela com uma partida nova em perfil
isolado, preservando os saves do jogador. Requer o projeto de desenvolvimento,
Python 3.10+ disponível como `python` e Godot. O botão fica desativado nas
exportações que não contêm a ponte Python.

Não há limite padrão de tempo. F8 ou fechar a janela encerra a sessão;
`JOGAR_SOL.cmd --seconds 600` limita uma execução a dez minutos. O robô local
não usa API do Jev nem consome créditos. Seu painel ocupa o canto inferior
direito e se esconde durante telas e diálogos modais; F8 continua funcionando.

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
