# Sobrevoo do menu: medir, planejar e conferir

O menu voa um trajeto gravado em `data/sobrevoo_menu.json`. Ele contorna árvores e casas
pelos lados, a 14,6–17,4 m do chão, e o porquê de cada escolha está em
[VALE_VIVO_3D.md](../../../docs/mundo/VALE_VIVO_3D.md) ("Sobrevoo da abertura").

Os portões `tests/sobrevoo_livre.gd` e `tests/sobrevoo_livre_procedural.gd` conferem o
trajeto gravado contra o vale de hoje. **Reprovaram depois de você plantar uma árvore
ou mudar uma casa de lugar perto do voo: replaneje** com os passos abaixo.

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

## Arquivos

| Arquivo | O que faz |
|---|---|
| `extrair_geometria.gd` | monta a abertura num estilo e rasteriza os triângulos reais numa grade de 0,5 m, por faixas de 2 m acima do chão; com `--conferir=<trajeto>` confere em vez de gravar (é o que os portões usam) |
| `regiao_gravada.gd` | reconstrói a mata com as mesmas sementes: no `--headless` a MultiMesh não guarda a transformação das instâncias |
| `geometria.gd` | lê a grade e mede folga, chão e a rota antiga; a Catmull-Rom do menu |
| `corredor.gd` | os intervalos livres de lado ao longo da rota antiga (diagnóstico) |
| `avaliar.gd` | simula o voo a 60 qps e mede folga, altura, guinada, acelerações e enquadramento |
| `planejar.py` | otimiza a B-spline fechada do voo e grava `data/sobrevoo_menu.json` |
