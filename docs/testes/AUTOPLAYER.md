# Teste automático do jogo

O **Teste automático** é nosso jogador de testes local: um algoritmo determinístico
e exploratório que observa o estado do jogo, escolhe uma ação e acompanha seu
resultado. Seu objetivo é concluir a história implementada, atualmente até
`fazenda_chegada`. Os capítulos posteriores ainda não são jogáveis. A política
está em desenvolvimento; iniciar uma sessão não garante terminar a campanha.

## Como iniciar e encerrar

No menu inicial, escolha **Teste automático**, ao lado de Explorar, ou execute
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

Uma sessão de 300 segundos desde o jogo pronto, em perfil novo e sem API,
registrou 67 decisões, entrada pela soleira, retirada de balde/enxada/maniva
no baú e arar → plantar → regar, chegando à etapa da lenha (10/16).
`tools/temp/robo-navegacao-final/relatorio.md` contém a evidência local.
Isso não demonstra coleta de lenha/pedra nem conclusão da campanha. As
orientações ao jogador humano e o destrancamento da porta continuam sob
#146/#154. Uma nova sessão sem limite usa o código final e registra a campanha.
