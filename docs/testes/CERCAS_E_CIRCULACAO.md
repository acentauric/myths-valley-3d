# Cercas e circulação — #125 e #142

Na main integrada, os lances do paisagismo estavam em MultiMesh sem corpo.
Não há `Camadas.CERCA` nem exceções de cerca em `colisoes_de_passeio.gd`
nessa versão. A descrição original da #125 pertence a outra revisão.

Cada transformação desenhada recebe uma caixa física na camada de mundo,
com o mesmo comprimento, inclinação e centro. A navegação já lê essa camada;
não se mantém uma geometria diferente só para o morador.

`cercas_e_circulacao` verifica a presença física no centro de cada lance,
a camada de leitura e a correspondência com as instâncias desenhadas.
Depois anda a Candinha de seu posto até Zefa com o corpo normal, caminho
da malha e colisões ativas. As outras pessoas ficam imóveis na fixture.
A falsificação `--sem-corpos` retira somente as cercas da camada física;
as verificações físicas devem reprovar, sem alterar arquivos do jogo.

Em 07/10/2026, navegação e encosta passaram. A travessia física final
chegou à Zefa em 136 s, com zero falhas. Retirar os corpos antes das
consultas físicas produziu 216 falhas; essa repetição usa `--apenas-colisoes`
para não repetir a caminhada depois de falsificar o cenário.
`colisoes_de_passeio` encontrou bloqueios no umbral
da igreja (81,1; 1,8; −70,5) e na ponte central (6,9; 4,1; −24).
A repetição sem os corpos novos reproduziu os mesmos dois bloqueios:
eles não foram causados pelas cercas. O erro de contorno da malha foi
experimentado em 0,2 apenas em memória e rejeitado: alterou os caminhos e
introduziu outros bloqueios, sem resolver a ponte.

Logs: `D:/MythsValleyPlaytestRuns/passeio125-baseline.log` e
`passeio-clearance2.log`. A #125 permanece aberta até o portão completo
passar; a #142 conserva as capturas de cinco contornos em `scratch/cercas142`.

## Conclusão em 07/10/2026

As soleiras alinhadas da igreja e a projeção física dos troncos inclinados
foram corrigidas na fatia `ca870ec`. A ponte ainda oferecia a quina do corrimão
como passagem: retirar suas faces superiores não excluía a pegada da madeira.
Os dois corrimãos agora entram como obstáculos proporcionais ao modelo;
o tabuleiro, a geometria física importada e as juntas continuam intactos.
As lajes recebem nomes legíveis, inclusive quando há duas pontes.

`colisoes_de_passeio` passa em 87 s, `navegacao` em 57 s e
`rota_da_fazenda` em 61 s, sem erro de script. O novo portão
`travessia_da_ponte_central` anda as duas rotas que prendiam e cruza
ambas as cabeceiras pelo eixo com a cápsula real; zero presos.
`--sem-corrimaos` restaura o defeito em memória: o corrimão prende
novamente o corpo, e o portão reprova. Não foi adicionada exceção para cerca.

Com a prova física da Candinha, os limites reorganizados e as cinco capturas
já conferidas, as #125 e #142 satisfazem seus critérios. A #99 ainda aguarda
a execução da bateria inteira; a arte específica do cemitério é a #111.
