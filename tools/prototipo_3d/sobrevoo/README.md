# Sobrevoo do menu: medir, planejar e conferir

O menu voa um trajeto gravado em `data/sobrevoo_menu.json`. Ele contorna árvores e casas
pelos lados, a 14,6–17,4 m do chão, e o porquê de cada escolha está em
[VALE_VIVO_3D.md](../../../docs/mundo/VALE_VIVO_3D.md) ("Sobrevoo da abertura").

Os portões `tests/sobrevoo_livre.gd` e `tests/sobrevoo_livre_procedural.gd` conferem o
trajeto gravado contra o vale de hoje. **Reprovaram depois de você plantar uma árvore
ou mudar uma casa de lugar perto do voo: replaneje** com os passos abaixo.

**O lobby do menu é o vídeo** (`abertura.gd`, `lobby_em_video`): a abertura libera o
vale 3D de fundo antes de ele montar, e quem espera o `mundo` fica girando para sempre.
O extrator liga `lobby_3d_pedido` (uma `static var` da abertura) antes de instanciar a
cena, e falha na hora, com `FALHA:` na saída, se o menu abrir em vídeo mesmo assim. O
`--lobby-3d` na linha de comando faz o mesmo para quem joga, mas o runner não passa
argumento a portão; portão novo que meça o vale de fundo liga `lobby_3d_pedido` por
`load("res://scripts/prototipo_3d/abertura.gd").set("lobby_3d_pedido", true)`, com `load` e
não `preload` (a abertura cita autoload).

## Ver o voo no Godot

Abra `tools/prototipo_3d/sobrevoo/ver_sobrevoo.tscn` no editor e rode a cena (F6). Ela
monta só o cenário do vale e voa o trajeto gravado, com a linha do voo desenhada:
dourada com folga, amarela perto de uma copa, vermelha a menos de 5 m. A árvore que
aperta o voo ganha o nome dela na composição (`Coqueiro da orla 45`), e a lista sai
na saída do Godot. Mova essa peça em `scenes/prototipo_3d/composicao_vale.tscn`
(Avulsos), salve e rode a cena de novo. Espaço pausa, ←/→ andam no tempo, ↑/↓ mudam a
velocidade, 1/2 trocam a câmera do voo pela de fora, N pula para o próximo aperto.

A medida da cena é um guia (a copa como uma esfera no alto do modelo). Quem decide é
o portão: `.\tools\prototipo_3d\testar.ps1 -Teste sobrevoo_livre,sobrevoo_livre_procedural`.

## Replanejar (uns 10 minutos)

Rode a partir da raiz do projeto, no Git Bash. `S` é uma pasta de trabalho FORA do
repositório (cada geometria tem ~45 MB).

```bash
S=/c/temp/sobrevoo
# 1. Geometria real em volta do voo, um estilo por vez (cada um monta o vale)
godot --headless --path . --script res://tools/prototipo_3d/sobrevoo/extrair_geometria.gd -- --estilo=tripo --saida=$S
godot --headless --path . --script res://tools/prototipo_3d/sobrevoo/extrair_geometria.gd -- --estilo=procedural --saida=$S
godot --headless --path . --script res://tools/prototipo_3d/sobrevoo/extrair_geometria.gd -- --estilo=uniao --saida=$S
# 2. Planejar (Python 3 com numpy e scipy); parte dos controles já gravados
python tools/prototipo_3d/sobrevoo/planejar.py --geometria=$S/geometria_uniao.json
# 3. Conferir o novo trajeto (sem montar o vale, ~5 s)
godot --headless --path . --script res://tools/prototipo_3d/sobrevoo/avaliar.gd -- --geometria=$S/geometria_uniao.json --trajeto=res://data/sobrevoo_menu.json --limite_guinada=23.7 --limite_lateral=1.45
# 4. Os portões
./tools/prototipo_3d/testar.ps1 -Teste sobrevoo_livre
./tools/prototipo_3d/testar.ps1 -Teste sobrevoo_livre_procedural
```

O avaliador imprime `AVALIACAO_JSON` com as restrições duras H1–H6: folga ≥ 5 m,
altura em [14, 18] m, guinada e aceleração lateral no nível do voo antigo,
enquadramento, continuidade e fidelidade ao desenho (píer no início, praça a ≤ 35 m).
Se o planejador disser `NAO CABE`, as curvas novas pedem mais que 72 s nos limites de
conforto: abra o mapa da geometria (`$S/mapa_uniao.png`) e veja o que fechou o caminho.

## Quando replanejar não basta (04/10/2026)

O otimizador é local, e o laço tem pouca sobra de tempo. Três coisas que a revisão da
foz ensinou, na ordem em que apareceram:

- **Obstáculo em cima do trajeto.** Se o voo passa quase por cima de uma árvore nova,
  a folga não cresce para lado nenhum e o planejador não sai do lugar (a folga piora).
  Parta de um laço já empurrado de lado: `--inicial` aceita uma lista de `[x, z]`.
- **Vão fechado.** O laço cruza a fileira da orla em dois vãos, ida ao norte e volta
  ao sul. Um mangue sorteado no vão norte, com a fileira fechada dos dois lados dele,
  não se contorna: o vale não planta tronco a menos de 10 m do ponto do vão
  (`VAO_NORTE_DO_SOBREVOO_M`, no `world_builder.gd`). Mudou o voo de vão? Mude o ponto.
- **A curva da praça.** Otimizando os 22 controles, o planejador paga o tempo de um
  desvio afrouxando a curva da praça: ela foi a 35,2 m, e o avaliador cobra 35. O voo
  gravado saiu de uma otimização só dos controles do desvio (15 a 21 e 0 a 3), com os
  da praça parados, e de `--rodadas=0` para regravar o trajeto a partir deles.

## Arquivos

| Arquivo | O que faz |
|---|---|
| `extrair_geometria.gd` | monta a abertura num estilo e rasteriza os triângulos reais numa grade de 0,5 m, por faixas de 2 m acima do chão; com `--conferir=<trajeto>` confere em vez de gravar (é o que os portões usam) |
| `regiao_gravada.gd` | reconstrói a mata com as mesmas sementes: no `--headless` a MultiMesh não guarda a transformação das instâncias |
| `geometria.gd` | lê a grade e mede folga, chão e a rota antiga; a Catmull-Rom do menu |
| `corredor.gd` | os intervalos livres de lado ao longo da rota antiga (diagnóstico) |
| `avaliar.gd` | simula o voo a 60 qps e mede folga, altura, guinada, acelerações e enquadramento |
| `planejar.py` | otimiza a B-spline fechada do voo e grava `data/sobrevoo_menu.json` |
