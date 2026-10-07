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

A chegada física foi confirmada na fixture. Ainda falta repetir a condução
na campanha salva e observar `fazenda_chegada`; isso não encerra #164 nem #159.
Não houve geração paga, alteração do progresso da campanha ou publicação.
