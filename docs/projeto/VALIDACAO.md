# Validação

Use Git LFS e Godot 4.7.2 Standard. A importação de um clone novo precisa
terminar sem erros de script ou de importação de recursos. O runner verifica esses
erros; código de saída zero sozinho não demonstra que o jogo abriu.

```powershell
.\tools\prototipo_3d\testar.ps1                  # dia a dia: os testes de unidade (GUT), em segundos
.\tools\prototipo_3d\testar.ps1 -Completo        # unidade + a suíte do vale + os isolados
.\tools\prototipo_3d\testar.ps1 -Push            # obrigatório antes de git push para a main
.\tools\prototipo_3d\testar.ps1 -Teste casa,regras_missoes
.\tools\prototipo_3d\testar.ps1 -Completo -Longos  # também a partida inteira e as réguas
.\tools\prototipo_3d\testar.ps1 -Completo -Paralelo 3  # a suíte dividida em 3 Godots, cada um monta o vale uma vez
.\tools\prototipo_3d\testar.ps1 -Explicar        # o que rodaria
```

Desde a #242 (10/10/2026) são três peças, e nenhuma abre um Godot por teste:

| Peça | Onde | Como roda |
| --- | --- | --- |
| Unidade | `tests/unidade/test_*.gd` (GUT 9.7, `addons/gut`) | um Godot, sem vale; regra, dado, cálculo e tela solta |
| Suíte do vale | `tests/*.gd`, `extends "res://tests/suite/caso.gd"` | um Godot que monta o vale uma vez por estilo e roda os casos em sequência (`tests/suite/rodar.gd`) |
| Isolados | caso com `const ISOLADO := true` | um Godot para cada um, depois da suíte |

**A bateria completa roda só antes de ir para a `main`** (`-Push`). No dia a
dia roda a unidade. Mudar texto ou tradução não dispara nada além dela, que já
inclui o `idiomas`.

## A suíte do vale

O caso é o portão antigo, com `extends "res://tests/suite/caso.gd"` no lugar
de `extends SceneTree`: a base imita a parte da árvore que os portões usam
(`root`, `current_scene`, `process_frame`, `create_timer`, `quit`...). Ao
pedir o vale, o caso recebe o vale já montado; `quit` só avisa o anfitrião.
Entre um caso e outro o anfitrião:

- devolve os autoloads, as variáveis `static` do jogo e o `user://` ao estado
  de logo depois da montagem (`tests/suite/estado.gd`);
- tira a pausa, a escala de tempo, o limite de quadros e as teclas apertadas,
  e apaga o que o caso pendurou na raiz;
- desliga os timers que o caso armou e congela a corrotina que sobrou.

O que ele não desfaz é o estado do próprio vale (cordel pego, árvore cortada,
jogador em outro lugar). O caso do vale que reprova roda **de novo, com o vale
montado do zero**; só reprova se reprovar outra vez. Quem passou só na segunda
vez sai na lista "passaram só com o vale novo": é sinal de que um caso anterior
deixou o vale sujo, e o certo é ele devolver o que mexe. O caso que depende de
um vale intocado (as cadeias de missão, que partem do Pedro no começo) declara
`const VALE_NOVO := true`, e o anfitrião remonta antes dele, sem gastar a
primeira tentativa.

O caso que estoura no meio não trava a bateria: o erro de script é captado
pelo `Logger` do anfitrião e o caso reprova na hora; o que passa do teto
(`const TETO_S`, 300 s por padrão) reprova como TRAVOU.

## Casos acelerados

O caso de simulação longa (a travessia a nado, a noite dos bichos) declara
`const ACELERAR := 4`: o anfitrião roda o tempo do jogo 4 vezes mais rápido só
durante ele (`Engine.time_scale`, com mais passos de física por quadro). A física
continua em passos de 1/60 s. O `--fixed-fps` do Godot foi descartado: valia
para o processo inteiro e quebrava os casos que esperam pelo relógio de parede.

## Unidade

`tests/unidade/base.gd` estende o `GutTest`, dá `root` e `conferir(ok, rotulo)`
como nos portões antigos e devolve os autoloads antes de cada teste. Teste
novo de regra entra aqui, e não como caso do vale.

## Regras gerais

Cada Godot usa APPDATA temporário próprio (o `user://` só é apagado com o
perfil descartável que o runner cria). Somente os PIDs levantados pelo runner
podem ser encerrados. Recurso sem importação e `class_name` novo disparam uma
importação antes dos testes, quando o conteúdo mudou desde a última.

Toda rodada escreve `.godot/testar3d/bateria.log` e sobe o painel ao vivo em
http://127.0.0.1:8765/ (`-SemPainel` para não subir).

A bateria roda em modo headless. Para capturar imagens em smoke_opening ou
mapa_fluxo, use o renderer normal e a opção `--capture`. O smoke_test
integrado de `tools/prototipo_3d/` captura imagens e precisa de renderer gráfico.

O pré-voo reprova modelos ou WAVs que ainda sejam ponteiros LFS. Baixe os
arquivos antes da primeira importação, com `git lfs pull`. Cada teste deve
reprovar quando a condição que ele confere é quebrada (a falsificação).

A classificação de cada portão antigo (unidade, suíte, isolado, aposentado)
está em [docs/testes/AUDITORIA_PORTOES.md](../testes/AUDITORIA_PORTOES.md).
