# Animações do Mixamo, já nos corpos dos moradores (#190)

Cada `<modelo>.res` desta pasta é uma **biblioteca de animações do Godot**
(`AnimationLibrary`) com os clipes do [Mixamo](https://www.mixamo.com) que aquele
morador usa, **já redirecionados para o esqueleto Tripo dele**. O jogo a pendura
no tocador do modelo como a biblioteca `mixamo`
(`authored_animator.carregar_mixamo`); a ficha em Modelos mostra cada clipe com o
selo "Mixamo" e o toca na prévia.

| Biblioteca | Clipes (id no jogo ← nome no Mixamo) | Gatilho no jogo |
|---|---|---|
| `pedro.res` | `capoeira` ← Capoeira · `pointing` ← Pointing Forward | treino no posto, longe do jogador · condução (marco e chegada) |
| `pescador.res` | `fishing_idle` ← Fishing Idle · `fishing_cast` ← Fishing Cast | ação "pescar", com o lançar de tempos em tempos |
| `beata.res` | `praying` ← Praying · `kneeling_idle` ← Kneeling Idle | ação "rezar" (igreja e cruzeiro), com a pausa ajoelhada |
| `zefa.res` | `harvesting` ← Harvesting With A Sythe | posto da manhã (o terreiro) |
| `tonho.res` | `counting` ← Counting | trapiche, de manhã e à tarde, do parado de tempos em tempos |
| `candinha.res` | `waving` ← Waving · `sitting_idle` (pendente: banco) | saudação · — |
| `damiao.res` | `digging` ← Digging · `sitting_talking` (pendente: banco) | postos do cemitério (manhã, tarde, entardecer) · — |
| `quirino.res` | `pulling_rope` ← Pulling A Rope | píer, do parado de tempos em tempos |
| `padre.res` | `waving` ← Waving | saudação (se intercala no ofício) |
| `sacristao.res` | `harvesting` ← Harvesting · `opening_door` ← Opening Door Inwards | ação "capinar" · porta de casa ao se recolher |
| `mercador.res` | `counting` ← Counting · `sitting_yell` (pendente: banco) | ação "balcao", intercalado · — |
| `guarda.res` | `strut_walking` ← Strut Walk · `salute` ← Salute | passo da ação "vigiar" (a ronda) · saudação |
| `marisqueira.res` | `digging` ← Digging · `picking_up` ← Picking Up · `wiping_sweat` ← Wiping Sweat | ação "mariscar", com as duas variações intercaladas |
| `lavadeira.res` | `wiping_sweat` ← Wiping Sweat | ação "lavar", intercalado |
| `rendeira.res` | `sitting_idle` (pendente: banco) | — |
| `quituteira.res` | `waving` ← Waving · `sitting_yell` (pendente: banco) | saudação · — |
| `menino.res` | `jump` ← Jumping In Place · `happy_walk` ← Happy Walk | ação "brincar": o pulo intercalado e o passo a caminho dela |
| `menina.res` | `jump` · `happy_walk` · `girl_bench_swing` (pendente: banco) | idem · — |
| `mestre_saveiro.res` | `strut_walking` ← Strut Walk · `pulling_rope` ← Pulling A Rope | passo a caminho da festa · ação "esperar", intercalado |
| `viajante.res` | `jump` · `punching` ← Jab Punch · `stretching_yawn` ← Big Yawn · `getting_up` ← Standing Up From Back · `tired_breathing_idle` ← Breathing Idle · `opening_door` (pendente: portas) | pulo · soco de mão vazia · acordar na cama · acordar de desmaio ou queda · vigor zerado · — |

**Pendente** é clipe baixado, redirecionado e registrado, que espera um gatilho que o
vale ainda não tem: `assento` (sentar num banco que a rotina do morador não usa — o
vale só tem dois bancos, na praça, longe dos postos de quem sentaria) e
`porta_do_jogador` (as portas do vale não abrem, o viajante as atravessa andando).
O motivo está escrito em `pendente` no `data/mixamo_uso.json`, e o portão
`animacoes_mixamo` cobra que ele exista.

O inventário completo (o catálogo do Mixamo, o que foi baixado, os clipes Tripo
e Mixamo de cada personagem, os rótulos e os gatilhos) mora em
[`data/mixamo_uso.json`](../../../../data/mixamo_uso.json).

## Licença: por que os FBX não estão aqui

O Mixamo (Adobe) deixa usar as animações **em projetos, inclusive comerciais,
quando incorporadas ao jogo**, e **não deixa redistribuí-las soltas**. Este
repositório é público, e por isso os FBX baixados **não entram nele** nem no
site: ficam na máquina do autor, fora do projeto (`D:/mixamo_fbx`, com o
`LEIAME.md` e o `catalogo.json` da coleta de 08/10/2026). O que entra é só o
movimento já redirecionado para cada corpo, que só faz sentido tocado nele. O
exportador do site leva nomes e contagens, nunca o arquivo.

## Como refazer (ou acrescentar um clipe)

1. Baixar no Mixamo: FBX Binary, **Without Skin**, **30 fps**, sem redução de
   quadros, **In Place** quando a opção existe. Guardar fora do projeto.
2. Declarar o clipe no personagem em `data/mixamo_uso.json` (`clipes_mixamo`):
   `id`, `fbx`, `laco`, rótulo e gatilho nos quatro idiomas, e o gatilho de
   verdade — `acao` da rotina (uma ou uma lista; "posto:manha" para quem só tem
   postos por período; com `a_cada` para intercalar) ou um `gatilho_id` com
   código próprio (a lista está no cabeçalho de `mixamo_uso.gd`). Clipe sem
   momento no jogo não entra; o que espera algo que o vale não tem leva
   `pendente` com o motivo. `termina_na_origem` faz o gesto acabar de pé onde o
   corpo está (o levantar do chão).
3. Redirecionar:

       Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/prototipo_3d/mixamo/redirecionar.gd -- --fbx=D:/mixamo_fbx

   (`--medir` só imprime a conferência; `--so=<id>` refaz um personagem;
   `--inventario` lista os clipes Tripo de cada modelo.)
4. Conferir a pose na folha de fotos (precisa de janela):

       Godot_v4.7.2-stable_win64_console.exe --path . --script res://tools/prototipo_3d/mixamo/fotografar_clipes.gd -- --saida=C:/pasta/fotos

5. O portão `tests/animacoes_mixamo.gd` cobra o inventário, o gatilho, a pose
   (sem esticar osso, pé no chão e sem deslizar mais que no Mixamo, no lugar) e
   o comportamento no animador.

O método do redirecionamento (a transferência no mundo, osso a osso, com o
alinhamento das poses de descanso) está no cabeçalho de
`tools/prototipo_3d/mixamo/redirecionar.gd`.
