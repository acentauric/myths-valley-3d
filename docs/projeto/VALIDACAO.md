# Validação

Use Git LFS e Godot 4.7.2 Standard. A importação de um clone novo precisa
terminar sem erros de script ou de importação de recursos. O runner verifica esses
erros; código de saída zero sozinho não demonstra que o jogo abriu.

```powershell
.\tools\prototipo_3d\testar.ps1                  # o lote: o que mudou desde o último verde
.\tools\prototipo_3d\testar.ps1 -Push            # obrigatório antes de git push
.\tools\prototipo_3d\testar.ps1 -Explicar        # o que rodaria, e por quê
.\tools\prototipo_3d\testar.ps1 -Teste salvamento
.\tools\prototipo_3d\testar.ps1 -Tudo            # bateria completa, antes de fechar build
.\tools\prototipo_3d\testar_analise_teste.ps1    # os testes do próprio runner, sem Godot
```

A escolha dos portões ignora comentário, linha em branco e formatação de JSON
(a impressão digital é semântica); só o portão que lê código como texto vê o
comentário do arquivo que ele lê. Recurso sem importação e `class_name` novo
fora do cache de classes disparam uma importação única antes da bateria.

Cada portão usa APPDATA temporário próprio. Um travamento reprova e somente
os PIDs levantados pelo runner podem ser encerrados. A régua ordem_da_visita
é medida manualmente e não participa da bateria.

O runner exige a confirmação `_OK` do portão, além do código de saída e da
ausência de erros de script. Falhas conservam logs e perfil isolado em TEMP;
os perfis de testes aprovados são removidos, inclusive com caminhos longos
do cache de shaders no Windows.

A bateria roda em modo headless. Para capturar imagens em smoke_opening ou
mapa_fluxo, use o renderer normal e a opção `--capture`. O smoke_test
integrado de `tools/prototipo_3d/` captura imagens e precisa de renderer gráfico.

`-QuadrosFixos` é opcional: simula quadros de 1/60 s sem sincronização com o
relógio de parede. Serve para repetir verificações de lógica e física mais
rapidamente; a bateria padrão conserva a execução em tempo real.

O pré-voo reprova modelos ou WAVs que ainda sejam ponteiros LFS. Baixe os
arquivos antes da primeira importação, com `git lfs pull`. Cada portão deve
reprovar com código diferente de zero quando uma condição é quebrada.
