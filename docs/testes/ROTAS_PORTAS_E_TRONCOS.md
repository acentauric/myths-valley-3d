# Rotas nas portas e nos troncos — #99, #125 e #150

O caminho da praça ao altar prendia no umbral esquerdo da igreja, embora
as catorze passagens físicas pelo vão estivessem livres. A navegação passa
a usar a soleira externa e interna ao atravessar um cômodo; os segmentos
até elas continuam calculados na malha. Uma porta trancada não recebe
travessia direta. Os cômodos do mesmo lado conservam o caminho original.

`caminho_pela_porta` anda a cápsula do jogador praça→igreja e igreja→praça,
confere as duas soleiras e tranca a porta para rejeitar travessia forçada.
Passou em 54 s. `--sem-alinhamento`, em memória, reprova três verificações,
incluindo o contato físico com `Interior_igreja/Umbral_25`.

A repetição da navegação também encontrou um tronco inclinado na orla,
contato em (64,76; 1,21; 13,26), eixo vertical do corpo com componente Y
0,75. A colisão acompanha a inclinação; a reserva da malha era um octógono
vertical só no pé. Ela agora inclui a projeção do cilindro até a altura do
agente mais seu degrau. A copa alta não ganha uma parede artificial.

`navegacao` passou em 74 s, sem atravessar o tronco. Restaurar apenas a
projeção vertical em memória reproduz a falha no mesmo percurso píer→gameleira.
Os logs dos dois mutantes não contêm SCRIPT/Parse/Compile Error:
`D:/MythsValleyPlaytestRuns/nav-mutante-inclinacao.log` e `porta-mutante.log`.

O passeio completo ainda encontra a quina da ponte central. Não se encerra
#125 nem a revisão global de colisões por essas duas correções. A #99 aguarda
também a bateria integral, e a #150 inclui a revisão visual dos demais modelos.
