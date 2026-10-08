# Animações do Mixamo, já nos corpos dos moradores (#190)

Cada `<modelo>.res` desta pasta é uma **biblioteca de animações do Godot**
(`AnimationLibrary`) com os clipes do [Mixamo](https://www.mixamo.com) que aquele
morador usa, **já redirecionados para o esqueleto Tripo dele**. O jogo a pendura
no tocador do modelo como a biblioteca `mixamo`
(`authored_animator.carregar_mixamo`); a ficha em Modelos mostra cada clipe com o
selo "Mixamo" e o toca na prévia.

| Biblioteca | Clipes (id no jogo ← nome no Mixamo) | Gatilho no jogo |
|---|---|---|
| `pedro.res` | `capoeira` ← Capoeira (Capoeira Idle) · `pointing` ← Pointing Forward | treino no posto, longe do jogador · condução (marco e chegada) |
| `pescador.res` | `fishing_idle` ← Fishing Idle · `fishing_cast` ← Fishing Cast | ação "pescar" da rotina, com o lançar de tempos em tempos |
| `beata.res` | `praying` ← Praying (Kneeling In Prayer) · `kneeling_idle` ← Kneeling Idle | ação "rezar" da rotina (igreja e cruzeiro), com a pausa ajoelhada |

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
   verdade — `acao` da rotina (com `a_cada` para intercalar) ou um `gatilho_id`
   com código próprio. Clipe sem momento no jogo não entra.
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
