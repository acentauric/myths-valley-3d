# Jev jogando o vale

Experimento opt-in de exploração do jogo, separado dos portões determinísticos.
O objetivo do agente é concluir a história **implementada**, até
`fazenda_chegada`, não somente o tutorial. A chegada ao pátio é o limite atual
do protótipo (`fazenda_vale.gd` e `docs/projeto/MISSOES_DO_2D.md`); os capítulos
seguintes ainda não são jogáveis. Uma janela de teste encerrada por tempo,
orçamento ou bloqueio não significa que o agente terminou a campanha.
Execute `JOGAR_JEV.cmd` na raiz: abre uma janela do Godot e o Jev escolhe ações
até alcançar o teto de **US$ 0,10 estimados**, sem limite padrão de tempo. Também escolhe
as ações da abertura: idioma português, JOGAR, vaga 1 nova e travessia.

Requer Python 3.10+, o Godot instalado em `C:\Tools\Godot\` e
`TYPESAFE_API_KEY` preenchida no `.env` local ou no ambiente. A ponte lê somente
as configurações TypeSafe; a chave não entra no Godot, nos argumentos, nos
relatórios nem no Git. Não cole chaves em comandos. O endpoint fica restrito a
`https://api.typesafe.ai/v1/systemone`.

## Limites e interrupção

- Máximo de US$ 0,10 estimados por execução, incluindo a abertura. `--budget`
  pode reduzir esse teto. Não há limite padrão de tempo nem de chamadas;
  `--seconds N` e `--calls N` acrescentam limites opcionais, com `0` para desativar.
  O modo offline exige `--seconds N` positivo, pois não consome orçamento.
- Reservamos 64 mil tokens antes de cada chamada, a US$ 0,042 por milhão de
  tokens de entrada. Após resposta válida, a reserva vira o uso informado pela API.
  Se o uso não puder ser confirmado, a reserva permanece. Não há retries automáticos.
- O teto é calculado localmente com a tarifa publicada, não um limite de cobrança
  imposto na conta TypeSafe. Mudança de preço exige atualizar `PRICE` antes de rodar.
- Erros da API, respostas inválidas, scripts quebrados ou orçamento insuficiente
  encerram a sessão. Não há troca silenciosa por um bot local.
- Sem novo objetivo, nova região, tela ou fala por 30 segundos, a ponte encerra
  com `no_progress_30s`. Circular entre os mesmos pontos ou repetir a mesma fala
  não renova esse tempo. Essa proteção continua ativa no teste por orçamento.
- Clique em **Parar sessão** ou aperte **F8**. Fechar a janela também encerra o processo.
  Uma chamada em andamento pode demorar até 12 segundos para terminar.

## O que ele observa e controla

O modelo recebe dados textuais: posição, energia, vida, vigor, missão, diálogo,
foco do E, resultados recentes e opções disponíveis. Não recebe imagens.
Recebe também as definições compactas de todos os `data/missoes_*.json`,
requisitos e acontecimentos de todas as cadeias vivas, diário e passos cumpridos,
inventário completo e ferramenta na mão, horário, interior, mapa de âncoras,
posições de todos os moradores, receitas aprendidas/custos/impedimentos, obras
feitas, dinheiro, fontes de interação ao alcance e todos os textos visíveis
(incluindo telas dos autoloads). Cada chamada inclui histórico de 24 ações com
posições e objetivo resultante. Os arquivos de missões são a lista explícita
de contexto estático: não há varredura de código, assets, `.env` ou perfil pessoal.
`current_task` separa o requisito em curso do contexto das missões futuras e
identifica seu destinatário e as opções que correspondem àquele requisito.
Isso não escolhe a ação nem altera a missão: o Jev continua podendo escolher
qualquer opção disponível, inclusive uma recuperação quando o caminho falha.
Na abertura, recebe o contexto de abrir a partida e pular a narração já testada;
as 22 definições completas entram nas decisões dentro do vale.

O estado do Pedro distingue condução, espera pelo jogador, destino e chegada
ao destino. **Seguir** acompanha continuamente o NPC em vez de encerrar ao
alcançá-lo; só anuncia chegada quando o guia alcançou o destino da condução.
O trecho próximo do guia usa W e passos laterais quando necessário, para
aproximar abaixo do limiar de 4 unidades que o faz voltar a andar.
As âncoras de direção (`Frente`, `Direcao`, `Lado`) são identificadas como tais e
não viram destinos de caminhada.
Um NPC exigido a até 15 unidades pode ser abordado diretamente, sem exigir
que o guia chegue a uma coordenada exata. Isso evita transformar a espera do
Pedro em trava para conversar com alguém que já está próximo.
Escolhe entre caminhar até um alvo, seguir Pedro, interagir pelo E, responder
diálogos, abrir mochila/diário, fechar telas, correr pelo Shift/WASD, pular e esperar.
Também pode escolher qualquer morador ou âncora de posição do mapa, cama/baú
da casa já carregada, olhar para uma fonte de interação ao alcance, trocar
slots da mão, trabalhar com E, esquivar e navegar as telas com WASD/E/F/Tab.
Mapa, talentos, arraial, almanaque e horário têm ações de abertura. O máximo de
opções acompanha a API (255), sem o antigo corte de 40. A decisão continua
sendo do Jev: os controles não escolhem missões nem alteram seus requisitos.
Raios curtos de colisão informam as direções bloqueadas; essas opções não são
oferecidas ao modelo. O movimento pelo teclado mede o deslocamento e relata
bloqueio quando o personagem não sai do lugar, em vez de anunciar conclusão.
A caminhada usa
**WASD**, com colisões e física normais. A malha só fornece os pontos da rota;
não há chamada a `player.caminhar_ate` nem movimento pelo clique. O Jev escolhe
o alvo, a direção ou a ação, e a ponte executa as teclas. Perto do destino,
as teclas também fazem o trecho que a malha não alcança. O estado informa
direções no mundo e os pontos previstos de caminhada/corrida, inclusive se
esses pontos são andáveis, para não confundir um raio curto livre com uma
corrida inteira segura.
O ajuste de rumo para conversar usa as mãos já existentes dos portões.

Não teleporta, não injeta itens e não avança missões por código. Os novos
controles de trabalho e telas precisam de validação real em cada sistema;
expô-los não prova que o Jev saiba concluir combate, compra ou fabricação.
Não representa cobertura de toda a campanha.

Os saves e preferências usam um perfil isolado dentro do relatório. O perfil
normal do jogador não é tocado. O estilo visual é o padrão Tripo.

## Relatório e verificação sem crédito

Cada execução cria `tools/temp/jev/<sessao>/` (ignorado pelo Git):

- `eventos.jsonl`: observações, opções, decisão, confiança, latência e resultado;
- `resumo.json`: motivo de parada, chamadas, tokens, custo e erros de scripts;
- `stdout.log` / `stderr.log`: saída do Godot;
- `quadro_*.png`: capturas locais periódicas, não enviadas ao Jev;
- `perfil/`: saves descartáveis dessa sessão.

Parado por alguns segundos ao tentar caminhar vira **suspeita** de bloqueio,
que precisa ser revisada. Apertar E não prova que a interação funcionou: consulte
o estado antes/depois no relatório. Uma sessão sem suspeitas não aprova o jogo.

```powershell
python tools/jev/test_jogar.py
python tools/jev/jogar.py --offline --headless --seconds 15
```

`--offline` é validação explicitamente identificada, com escolhas locais e zero
chamadas à API. Não demonstra a inteligência do Jev. Para a experiência real:

```powershell
.\JOGAR_JEV.cmd
```

Referências: [API](https://docs.typesafe.ai/api),
[modelos, entrada textual e tarifa](https://docs.typesafe.ai/models).

## Primeiro experimento — 07/10/2026

A sessão real foi interrompida a pedido do usuário após cerca de 4 minutos
e 20 segundos de jogo: 90 chamadas, 119.539 tokens e US$ 0,005020638 estimados.
O agente repetia aproximações e interações no passo de cumprimentar o Tonho.
O controlador aceitava a chegada da navegação mesmo com o E direcionado ao Pedro.

Depois da interrupção foram adicionados o guard de falta de progresso e a
verificação do alvo do E. A validação **sem API** conseguiu cumprimentar o Tonho
e avançar até `pedro_chave`; esse resultado offline valida os controles, não o modelo.

Na retomada real, a primeira execução parou automaticamente após 41,3 segundos:
18 chamadas e US$ 0,000695352 estimados. O comando de correr tentava avançar
contra um obstáculo. Foram acrescentados movimentos nas quatro direções,
sensores de colisão e resultados que medem o deslocamento real.

A execução seguinte, com o tempo e o orçamento restantes, correu, cumprimentou
o Tonho, encontrou a Dona Candinha e chegou à etapa 5 de 16 (`pedro_chave_zefa`).
Parou por `no_progress_30s` após 331 segundos de jogo: 47 chamadas, 71.214 tokens
e US$ 0,002990988 estimados, sem erros de script detectados. Alternava caminhar
até o marcador e voltar ao Pedro, que espera quando o jogador se afasta; não
concluiu a missão da Zefa. A causa precisa de revisão antes de outra sessão paga.
O relatório está em `tools/temp/jev/20261007-002543-7eeb43/` nesta máquina.

As duas execuções desta retomada somaram cerca de 6 minutos e 12 segundos,
65 chamadas e US$ 0,00368634 estimados. O limite de falta de progresso encerrou
o experimento antes dos 10 minutos. Isso demonstra navegação e interações
iniciais, não aprovação dos portões nem cobertura de toda a campanha.

## Experimento com contexto da campanha e WASD — 07/10/2026

Foram enviados os 22 arquivos de missões (85 etapas), estado das cadeias,
inventário, requisitos, personagens e mapa. As duas primeiras tentativas
somaram 51 chamadas e US$ 0,050415708 estimados. Mesmo com esse contexto,
a aproximação pela navegação parava a 4,2 unidades do Pedro, que precisava
de menos de 4 para voltar a andar. Não bastava mudar o prompt.

O controlador passou a caminhar com teclas WASD. A navegação somente lê
os pontos da rota; não emite comandos de caminhada por clique. A validação
local sem API passou pelo trecho que travava. Na execução real seguinte,
o Jev correu, cumprimentou o Tonho, falou com Dona Candinha e continuou
seguindo o Pedro rumo à Zefa, além do ponto anterior de bloqueio.

A execução `tools/temp/jev/20261007-010223-ecbf2d/` terminou pelo limite de
tempo: 281,6 segundos observados, 25 chamadas, 638.690 tokens e
US$ 0,02682498 estimados, sem erros de script detectados. O tempo observado
inclui a latência de encerramento após o limite de 278 segundos.
Não concluiu a missão da Zefa nem a campanha. As três tentativas deste
experimento custaram US$ 0,077240688 estimados no total. Os 22 testes locais
da integração passaram; isso não substitui os testes determinísticos do jogo.
