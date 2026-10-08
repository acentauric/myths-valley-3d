# Troncos fechados — conferência (#156)

O relato: árvores "sem tronco" ou com o tronco vazado, perto da Dona Zefa e do
cemitério. A causa, achada em `fb73428`: o Tripo fechou o fuste de dez árvores com
os triângulos virados para dentro, e o descarte das faces de trás (ligado nos GLBs
para ganhar quadros) fazia sumir a parede da frente do tronco. Os materiais já eram
de duas faces: o defeito é o sentido da malha, e a correção não é global. Só as
espécies que a medida aponta voltam às duas faces (`CatalogoAssets.TRONCO_DE_COSTAS`).

## O portão e o sinal da conta

`tests/troncos_fechados.gd` atira raios horizontais ao pé de cada árvore de tronco
(63 do catálogo, inclusive as versões leve e de longe) e conta a fração cujo primeiro
triângulo está de costas. A conta é `direcao · ((b - a) × (c - a)) < 0`. O Godot
tem como frente a ordem horária vista de quem enxerga o triângulo, e nessa ordem o
produto vetorial aponta para longe de quem olha, no mesmo sentido do raio: de frente
dá produto positivo, de costas negativo. O sinal confere com a medida: as espécies
íntegras dão de 0 a 6% de costas e as dez afetadas de 9% a 79%, e com o sinal
trocado as íntegras dariam mais de 90%. `--falsificar=lista` (esvazia a lista de duas
faces) e `--falsificar=material` (exige o descarte em todas) reprovam o portão.

## Conferência no jogo (08/10/2026)

Fotos de três ângulos, a 4,5 a 5,5 m e a 1,5 m de altura, no vale montado com janela
(sem HUD), do tronco mais perto da Zefa de cada espécie: jenipapeiro, jequitibá,
aroeira, embaúba e jatobá (a 5 a 26 m dela), e, nas espécies da lista, ipê-amarelo e
pitangueira (instâncias do vale, mais longe). Todos os troncos aparecem inteiros,
contínuos e com a casca de fora de todos os ângulos; nenhum mostra fenda ou parede
interna. As fotos ficam locais (`D:/MythsValleyPlaytestRuns/arvores156-141/`) e não
foram anexadas ao GitHub.
