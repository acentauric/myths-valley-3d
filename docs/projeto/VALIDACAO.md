# Validação

Use Git LFS e Godot 4.7.2 Standard. A importação de um clone novo precisa
terminar sem erros de script ou de importação de recursos. O runner verifica esses
erros; código de saída zero sozinho não demonstra que o jogo abriu.

```powershell
.\tools\prototipo_3d\testar.ps1
.\tools\prototipo_3d\testar.ps1 -Teste salvamento
.\tools\prototipo_3d\testar.ps1 -Teste reservas_do_corpo
.\tools\prototipo_3d\testar.ps1 -Teste agua_rasa -QuadrosFixos
.\tools\prototipo_3d\testar.ps1 -Teste painel -QuadrosFixos
.\tools\prototipo_3d\testar.ps1 -Teste reservas_do_corpo -ComJanela -Compatibility -ArgumentosTeste @('--somente-hud', '--capture')
# Deve reprovar: simula a cobrança do nado ausente, somente em memória.
.\tools\prototipo_3d\testar.ps1 -Teste reservas_do_corpo -ArgumentosTeste '--falsificar'
```

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
