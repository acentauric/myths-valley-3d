# Terreno no editor — auditoria de 07/10/2026 (#33)

A prévia persistida existe em `scenes/prototipo_3d/terreno_editavel.tscn`, com
ArrayMesh e colisão. O host leve de `abertura.tscn` e `vale.tscn` carrega a
composição autoral somente sob `Engine.is_editor_hint()`; a composição inclui
a base geográfica como filho interno. Não se incorpora a prévia ao salvar
as cenas do menu/vale. O runtime continua usando o gerador geográfico.

Evidências:

- `terreno_editor`: verde em 5 s; malha, colisão, extensão, exageração vertical
  e presença do host nas duas cenas. A geração determinística usa
  `tools/mapas/gerar_terreno_editavel.gd`, documentada em
  `docs/mundo/COMPOSICAO_AUTORAL_3D.md`.
- `previa_do_editor`, iniciado com `--editor --script`: `editor=true`, zero
  falhas; composição, base e uma malha de terra realmente instanciadas.
  O mutante `--sem-previa` remove a composição e reprova a observação.
- Captura real do SubViewport com editor ativo em
  `scratch/previa-editor/terreno.png`, inspecionada: relevo, caminhos e
  composição autoral renderizados sem iniciar uma partida.
- O mesmo gate sem `--editor`: verde em 3 s; o host não carrega a prévia.
- `terreno_unico`: verde em 60 s; menu 3D e vale terminam a construção com
  uma única malha `Terra`, e o host já foi removido pelo construtor.

A execução curta pelo editor apresenta avisos de encerramento (varredura
interrompida, janela de progresso e recursos do próprio editor); nenhum erro
de script foi encontrado. O teste não fecha nem controla o editor do usuário.
A cena é uma malha persistida inspecionável; não promete um editor de vértices
por pincel, funcionalidade fora do escopo desta primeira fatia.
