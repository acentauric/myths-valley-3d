# Transição da costa — #138

## Acabamento da extremidade da faixa

A areia antes desaparecia somente pelo lado da terra. Pelo lado do mar,
o material acabava opaco na aresta da malha, deixando uma régua clara no
raso. A extremidade agora se desfaz em manchas e grãos sobre o fundo do mar.
A faixa mantém geometria, colisão, altura e contorno da costa.

O gate gráfico `tools/prototipo_3d/validar_franja_da_areia.gd` renderiza o
shader real numa SubViewport transparente. Mede centro opaco, mistura de
areia/fundo e variação do recorte: 4789 pixels vazios, 2379 preenchidos e
19 posições de corte. Com `--sem-franja`, há zero pixels vazios nessa
faixa e somente uma posição de corte; duas verificações reprovam.
Executar com janela: headless não produz essa evidência gráfica e é recusado.

`agua_rasa` passa em 225 s, caminhando da praia à água funda e de volta;
`mare_ligada` passa em 49 s. A navegação não foi alterada. Capturas com duas
alturas de câmera, dois trechos e horas 07/13 ficam em `scratch/costa138-depois/`;
comparações da praia, píer e foz foram inspecionadas contra o baseline.
Os roteiros de captura não substituem esses gates. Não há erro de script;
avisos de texturas aparecem no encerramento das execuções gráficas.

## A foz (o que faltava para fechar a issue)

Com a câmera de cima da foz e `fotografar_chao.gd --esconder=...`, cada emenda foi atribuída a uma
malha, escondendo uma de cada vez:

- **A laje clara no raso, de bordas retas, à saída do rio.** Era a "Ladeira da foz": a malha de areia
  que continua o leito do rio por baixo do mar (para a colisão não subir na ponta) e acabava num
  retângulo de areia sobre o fundo. Escondida, a foz abre limpa no mar. A malha, a altura e a colisão
  não mudaram; o `leito_rio.gdshader` ganhou `costa_ponto`, `costa_direcao` e `costa_desfaz`, e a
  areia passa a se desfazer em manchas por 26 u a partir de 4 u antes da costa, até sumir no mar.
- **Os retângulos pequenos de borda reta na areia e na grama junto da foz, na rua e na praia.** Vinham
  do hash do ruído (`sin * 43758`), que dá valores diferentes ao mesmo canto de célula longe da
  origem do vale. O hash novo (sem seno) está em `solo.gdshaderinc`, `areia_praia` e `leito_rio`;
  ver [SOLO_E_FRANJAS.md](../mundo/SOLO_E_FRANJAS.md).
- **A faixa de areia em volta do rio** (`mouth_sand_*` do terreno) tinha rampa de 0,75 u e acabava em
  retas: rampa larga e borda com ruído.

Os gates novos moram em `validar_franja_da_areia.gd` (com janela): a laje da foz, renderizada pelo
shader real, tem o miolo cheio em terra, nada de areia a 7 u da costa no mar e a transição em
manchas (`-- --sem-desfaz` reprova nas duas últimas); e o hash, pedido de dois jeitos a 300 u da
origem, só difere em ~0,2% dos pixels (`-- --hash-antigo`: ~75%, reprova). `--sem-franja` segue
reprovando as duas verificações antigas.

Verificação visual (`fotografar_chao.gd`): foz, foz de cima, praia do píer e costa de cima, às 7 h
(preamar), 9 h, 13 h (baixa-mar) e 17 h; a praia, o píer e a foz não têm mais emenda reta entre o
leito do rio, a faixa de areia e o fundo do mar. Na baixa-mar o fundo da baía fica à mostra, liso:
é a maré do jogo, não uma linha. `agua_rasa`, `mare_ligada` e `rio_grande` passam: a navegação, a
colisão e a entrada na água não mudaram (só o visual da areia).
