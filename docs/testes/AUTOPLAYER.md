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
O robô usa os controles normais de movimento e interação, sem teleportar,
injetar itens ou alterar o progresso das missões.

Após 30 segundos sem progresso de missão, inventário ou obra, ou tentativas
repetidas no mesmo contexto, entra a exploração. Ela experimenta interações
próximas, orientação para outros alvos, trabalho com ferramentas, observação
e interfaces. Registra a cobertura por região, alvo, mão e seleção da tela.
Depois de esgotar a vizinhança, visita os lugares menos experimentados em ordem
de proximidade. Telas têm um teto de oito sondagens por abertura. Mudança real
de progresso devolve o controle às regras da missão. Não há escolha aleatória.

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
etapas observadas, resultados sem avanço e links das capturas. As distâncias
são deslocamentos entre observações, não o comprimento exato das curvas.
Para reconstruir o relatório de uma sessão existente:

```powershell
python tools/jev/relatorio.py tools/temp/robo-sem-limite
```

Acrescente `--watch` para atualizar enquanto o PID daquela sessão estiver vivo.
O JSONL é a evidência original; o Markdown serve à análise contínua. Bloqueios
reportados e muitas ações sem avanço são indícios, não diagnóstico automático
da causa nem prova de que todos os sistemas foram testados.

Relacionados: #159 (testador), #118 (ponte), #146 (orientações) e #154 (acesso à porta).
