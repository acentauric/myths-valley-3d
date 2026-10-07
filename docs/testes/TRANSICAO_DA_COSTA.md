# Transição da costa — #138, parcial

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

## Pendência que mantém a issue aberta

Na foz ainda se veem emendas da composição entre leito do rio, faixa de
areia e fundo do mar. A mudança de material reduz a borda da faixa, mas
não comprova continuidade completa nesses encontros. Uma tentativa de
encaixar toda a extremidade da praia na batimetria não demonstrou melhora
visual e foi retirada. A revisão geométrica da foz continua necessária.
