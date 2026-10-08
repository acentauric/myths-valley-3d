# Caminho físico para a fazenda — #164

Evidência de 07/10/2026, Godot 4.7.2, estilo Tripo. A campanha automática
continua no perfil isolado de `D:/MythsValleyPlaytestRuns/perfil-retomada-v16`.
Nenhuma missão, posição ou item foi injetado nesse perfil.

## Bloqueios observados

A V17, depois de dormir pela interface normal e sair da casa, não chegou à
fazenda. A área assada terminava em z=-232,2496, antes do portão em z=-289.
O caminho projetado para trás terminava aproximadamente 57 m antes do destino.

A V18 incluiu os limites corretos, mas Pedro caiu junto à ponte em torno de
z=-260. O jogador também ficou ali. A rota lógica não bastava: quinas de cerca
de 0,3 u no tabuleiro, faces de corrimãos usadas como piso e a decisão de evitar
água pela profundidade do leito desviavam o guia do apoio físico. O nado ainda
buscava o nível global do mar em vez da lâmina do rio elevado.

## Correção sob teste

- As âncoras do portão, pátio e casarão participam dos limites de navegação.
- O fundo do rio grande não oferece atalho a pé; os rios rasos do tutorial
  continuam atravessáveis.
- As faces elevadas dos corrimãos saem somente da fonte da navegação. Modelo,
  corrimãos físicos e estacas permanecem.
- O catálogo mantém a colisão importada e acrescenta apoio contínuo sob as
  tábuas, com duas rampas curtas nas juntas. São filhos do modelo: a ponte
  caída continua sem piso transitável antes da obra.
- O NPC distingue apoio seco sobre água do leito e usa a lâmina local para
  entrar em nado e sustentar o corpo.

## Portões e falsificação

`tests/rota_da_fazenda.gd` começa na margem sul em (115,5; 4,1; -251),
consulta o caminho até portão/pátio e move o corpo do Pedro pela física normal.
Seu mundo isolado possui a ponte construída como pré-condição; não escreve o
save da campanha. O resultado final foi **0 falhas**: Pedro atravessou o rio e
alcançou a distância de chegada do portão. O gate também verifica que o
tabuleiro não ativa nado e que um corpo submerso sobe para a lâmina local.

O mutante `--falsificar-juntas`, feito somente na memória do processo, remove
o apoio novo. Reproduziu a queda e falhou na chegada física (uma falha, sem
erro de script). `--falsificar-limites` restaura o volume antigo somente na
fixture e reprovou sete verificações de contenção das âncoras e destinos dos
caminhos; portão ficou a 56,95 m do fim projetado, pátio a 80,95 m.

`rio_grande` passou preservando a saída pela margem sul da #161, sem criar
passagem pela margem norte. `colisoes_do_vale` passou com o catálogo Tripo.
Logs finais em `D:/MythsValleyPlaytestRuns/rota-fazenda-final.log`,
`rota-fazenda-limites-final.log` e `ponte-fazenda-final.log`.

O gate `ponte` precisava respeitar a #121: fala ativa não oferece um novo E
para iniciar conversa. A fixture agora espera o fim natural da fala, com
teto de 60 s e assert; não encurta áudio nem altera a regra do jogo. Antes
disso, a versão do HEAD também reproduziu as mesmas 33 falhas em cascata.
Depois da espera, o gate emitiu `PONTE_OK` com zero falhas. O pipeline
PowerShell capturou como `NativeCommandError` o warning esperado do antigo
nome `vau`; não houve `SCRIPT ERROR`, `Parse Error` ou `Compile Error`.

## Limite da evidência

A chegada física foi confirmada na fixture. A V19 retomou o save, saiu do
rio pela movimentação normal, voltou a Pedro e repetiu a condução. Aos
447,95 s ambos estavam novamente na água, no lado oeste da ponte
(jogador 113,4; 2; -259,6, Pedro 113,8; 2,3; -258,9). Após repetição sem
avanço, a janela foi fechada normalmente; 63 ações, custo zero.

A fixture iniciada na aproximação real (109; 3,2; -234,8), com
`--aproximacao-campanha`, também atravessou: a diferença ocorre com os dois
corpos na condução. O testador abandonava os waypoints ao ficar entre 2,6 e
14 m de Pedro, aproximando em reta por dois segundos. Essa aproximação
agora mantém os pontos da rota e interrompe quando não existe caminho longe
demais. `tests/rota_do_guia.gd` passa; mutante que mira diretamente no guia
reprova uma verificação. Os 85 testes Python continuam verdes.

V20 confirmou a limitação da aproximação somente pela malha no píer: seu
fim projetado ainda fica longe do guia. A janela foi fechada normalmente
após 145 ações, sem custo. O fallback final verifica apoio físico em raios
a cada 0,4 m da reta; piso contínuo permite aproximação, vazio mantém os
waypoints. O gate testa ambos com corpos físicos, passando em dois segundos;
o mutante direto continua reprovando. V21 observa essa versão no mesmo save,
sem confirmar ainda causa única da queda na ponte.

## Chegada real — V21

A V21 completou `fazenda_chegada` aos **483,44 s** desde o lançamento
(417,3 s de jogo pronto). Foram 110 decisões locais, custo US$ 0. O jogador
terminou em **(118,2; 3,6; -308,2)**, Pedro em **(117,6; 3,6; -310,8)**,
`conducting=false` e `implemented_story_completed=true`. O objetivo mudou
para a cadeia lateral da Zefa. A travessia e a chegada ocorreram pela
missão normal, sem editar posições ou progresso na campanha.

Evidência preservada em
`D:/MythsValleyPlaytestRuns/robo-campanha-retomada-v21/`: `eventos.jsonl`
(último outcome), `resumo.json`, `relatorio.md`, stdout/stderr e capturas
JPEG. Não há `SCRIPT ERROR`, `Parse Error` ou `Compile Error`; permanecem
warnings de salvamento sobre autoloads legados Terrenos/Povoado ausentes.

O lançador devolveu sucesso pelo objetivo, mas o resumo registrou código
Godot 1: o watchdog encerrava o processo assim que `/event` detectava
vitória, antes do envio de `/stop` e da captura final. A correção dá dez
segundos para esse handshake e mantém teto para processo sem resposta.
87 testes Python passam; remover a espera reprova uma verificação.
A parada real por F8 da prova seguinte confirmou código Godot 0 e captura
final, com o handshake corrigido; não há captura de vitória nesta V21.

Todos os critérios da #164 possuem prova, inclusive chegada física real.
A #159 também recebe a prova específica do botão do menu e da parada
F8 descrita abaixo; a vitória da história implementada não equivale a concluir as histórias
laterais nem os capítulos planejados além do pátio da fazenda.

## Menu, perfil novo e F8 — #159

A fixture temporária `tools/temp/menu_autoplay.gd` abriu o menu real,
focou o botão (então rotulado TESTE AUTOMÁTICO, hoje TESTAR) e acionou Enter por `Input.parse_input_event`.
O botão iniciou o lançador normal, que criou uma partida nova em
`tools/temp/jev/20261007-140638-bc8a48/perfil`; a campanha em D permaneceu
separada. O log `D:/MythsValleyPlaytestRuns/menu-autoplay.log` confirmou
“Teste automático iniciado em outra janela. F8 encerra a sessão.”

A mensagem de tecla F8 foi enviada pela API do Windows à janela exata do
Godot filho (PID 66780), enquanto o jogador automático estava ativo. Não
houve chamada direta ao método de parada nem alteração de progresso.
Resultado: **user_stop, 19 decisões, 33,2 s de jogo pronto, custo zero,
código Godot 0**. Três JPEGs foram preservados, incluindo `quadro_0032.jpg`
final, junto a relatório e logs. Nenhum SCRIPT/Parse/Compile Error no filho.
O menu pai emitiu warnings de texturas na finalização, registrados no log;
eles não afetaram a abertura, o isolamento ou a parada do testador.
Não houve geração paga, alteração do progresso da campanha ou publicação.
