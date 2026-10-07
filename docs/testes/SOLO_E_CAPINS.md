# Solo e capins — #151

O chão verde mistura desde perto a segunda amostra rotacionada da textura,
reduzindo a repetição em quadrícula sem trocar as oito camadas de solo ou
alterar o relevo. Terra, caminho e areia conservam as transições existentes.

O capim de forro varia entre 60% e 95% da altura de referência. A distribuição
continua determinada pela semente e pelas receitas de cada ambiente: não se
acrescentam tufos para esconder o chão. A cor dourada do modelo permanece,
coerente com os capins secos do entorno. Os oito tufos altos do cemitério
mantêm tamanho, quantidade e identidade necessários à missão de limpeza.

Capins, bromélias e samambaias do forro se orientam pela normal local do
relevo, com a base seis centímetros dentro do solo. O capim interativo usa
o mesmo apoio. Árvores conservam sua orientação: #141 tem escopo próprio.

## Evidência

- `forro_no_relevo`: nove combinações de modelos reais e planos de apoio,
  sem base flutuante ou enterramento excessivo; verde em 3 s. O mutante
  `--vertical` reprova seis combinações inclinadas.
- `mapa_de_solo` (52 s), `alcance_dos_alvos` (65 s), `lapides_no_chao`
  (41 s) e `paisagismo` (40 s): verdes, preservando áreas, alcance e missão.
- Três capturas antes e depois foram inspecionadas na capela, cemitério e
  praça, em `scratch/capins151-antes/` e `scratch/capins151-depois/`.
  A execução gráfica não tem erro de script. Avisos de texturas ocorrem
  somente no encerramento. As capturas servem à revisão visual; seu roteiro
  não é prova de colisão nem uma medição de desempenho.

A fundação elevada da capela, vista nas capturas, não é defeito de capim.
Não se afirma melhoria de FPS: a segunda amostra tem custo de shader.
Praia/mar permanece sob #138.
