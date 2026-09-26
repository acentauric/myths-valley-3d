# Jogar e aprender com o protótipo 3D

Abra `prototipo_3d/JOGAR_3D.cmd`. O atalho importa os recursos e abre o jogo usando o Godot instalado em `C:\Tools\Godot`.

No Godot Project Manager, outra opção é importar **`prototipo_3d/project.godot`** e executar `scenes/prototipo_3d/vale.tscn`. O `project.godot` da raiz continua sendo a base 2D.

## Controles

| Tecla | Ação |
| --- | --- |
| Início / câmera destravada | Mouse capturado; mover o mouse gira a câmera sem clicar |
| Tab | Alternar entre câmera destravada e travada |
| Botão TRAVAR CÂMERA (Esc) / DESTRAVAR CÂMERA (Tab) | Mostrar a ação disponível e seu atalho; Tab também alterna os modos |
| Arrastar com botão esquerdo e câmera travada | Girar a câmera com o cursor visível; um clique sem arrastar ainda interage com as casas |
| Clique direito com cursor livre | Caminhar até o chão, casa ou NPC apontado |
| Duplo clique direito com cursor livre | Correr até o chão, casa ou NPC apontado |
| Mouse sobre uma casa | Mostrar nome e dica de interação |
| Clique esquerdo em uma casa | Abrir as mesmas propriedades no balão e no painel da interface, mesmo à distância |
| Clique esquerdo fora das casas | Fechar o balão e o painel de propriedades |
| WASD / setas | Mover em relação à câmera e cancelar a caminhada automática; reproduz `walk` |
| Shift + movimento | Correr; reproduz `run` |
| Mouse com câmera destravada | Girar a câmera sem pressionar botão |
| Rodinha | Aproximar ou afastar a câmera |
| F | Observar o personagem pela frente; pressione novamente para voltar |
| 1 | Saudação (`greet_01`) |
| 2 | Dar tchau (`wave_goodbye_02`) |
| 3 | Concordar (`agree`) |
| 4 | Olhar ao redor (`look_around`) |
| 5 | Com medo (`afraid`) |
| 6 | Cruzar os braços (`fold_arms`) |
| 7 | Golpear (`chop`) |
| 8 | Nadar (`swim`) |
| Esc | Travar a câmera e liberar o cursor |
| R | Voltar ao ponto inicial |
| T | Adiantar o relógio do vale em uma hora (ver dia e noite) |
| M | Voltar ao menu (HOME) |
| Alt+F4 / fechar janela | Sair |

No estilo **Procedural** (AJUSTAR → Cenário e tempo) as teclas 1–8 acionam os gestos do humanoide por código (acenar, concordar, apontar, coçar a cabeça, alongar, chamar, reverência, olhar em volta). O jogador começa no píer, com o Pedro ao lado: fale com ele e siga as missões do HUD. Os moradores cumprimentam quando você chega perto. Detalhes em [VALE_VIVO_3D.md](VALE_VIVO_3D.md).

Parado, o personagem reproduz `idle`. Um gesto termina naturalmente e volta para `idle`; começar a andar interrompe o gesto. Explore a praça, a horta e a costa: o indicador acompanha os três pontos visitados.

## O que este teste entrega

- GLB do Tripo com malha, materiais, esqueleto de 65 ossos e 11 animações incorporadas.
- Locomoção automática com os clipes `idle`, `walk` e `run`.
- Oito animações extras acionáveis dentro do jogo pelas teclas 1–8.
- Escala ajustada para 1,78 m, colisor de cápsula, aceleração, gravidade e rotação.
- Câmera em terceira pessoa com `SpringArm3D`, zoom e reação a obstáculos.
- Vila de teste com casas, caminhos, horta, árvores, praia, iluminação e colisões.
- Casa de Carro Quebrado gerada no Tripo, otimizada, escalada e com colisão simples.
- Interface, reinício de posição e três pontos de exploração.

As casas usam seus pontos geográficos como referência, mas a posição final é procurada em terra com espaço para a construção inteira, fora de todas as ruas e árvores. Árvores manuais que coincidiriam com uma casa são reposicionadas. A Casa da estrada também segue essa regra; sua coordenada KML continua sendo a referência inicial.

As animações foram exportadas **no lugar**: os clipes mexem o esqueleto, enquanto o `CharacterBody3D` controla o deslocamento e as colisões. Isso evita que a animação e o código tentem mover o personagem ao mesmo tempo.

O material continua sendo duplicado apenas na instância e renderizado dos dois lados. Essa correção evita o desaparecimento de partes do torso sem alterar o arquivo 3D original.

Farming, inventário, quests, NPCs e serviço LLM descritos no documento de decisões ainda não estão integrados. O passeio também não grava progresso; o diretório de usuário `MythsValleyPrototype3D` já separa os futuros saves da versão 2D.

## Como a animação funciona

O fluxo é pequeno de propósito:

1. `personagem.tscn` aponta para `medieval_character_animated.glb`.
2. O Godot transforma o GLB em uma cena com `Skeleton3D`, malha e `AnimationPlayer`.
3. `player_controller.gd` instancia o modelo, normaliza a altura e envia a velocidade atual ao animador.
4. `authored_animator.gd` escolhe `idle`, `walk` ou `run` e mistura as transições em 0,18 segundo.
5. As teclas 1–8 pedem clipes de gesto; qualquer movimento devolve o controle à locomoção.

Abra a cena importada pelo painel **FileSystem** do Godot e selecione `AnimationPlayer` para visualizar a lista e reproduzir os clipes no editor. O protótipo usa `AnimationPlayer` diretamente; um `AnimationTree` só será necessário quando houver combinações mais complexas, como ataque durante corrida ou camadas independentes para tronco e pernas.

Se um GLB futuro vier sem animações, o controlador volta automaticamente ao animador procedural antigo. Esse fallback serve para diagnóstico, não é o fluxo principal.

## Exportar novamente no Tripo

Para repetir o resultado apresentado:

1. No espaço **Animar**, selecione os clipes desejados.
2. Exporte no formato **GLB**.
3. Mantenha **Exportar Esqueleto** ativado.
4. Mantenha **Animação no Lugar** ativada para os clipes de locomoção.
5. Copie o resultado para `prototipo_3d/assets/prototipo_3d/personagem/`.
6. Use um nome estável, como `medieval_character_animated.glb`, e no Godot escolha **Reimport** se tiver substituído o arquivo.
7. Confirme no `AnimationPlayer` se os nomes esperados aparecem antes de alterar o código.

O arquivo atual contém estes 11 clipes: `afraid`, `agree`, `chop`, `fold_arms`, `greet_01`, `idle`, `look_around`, `run`, `swim`, `walk` e `wave_goodbye_02`.

Para trocar quais gestos cada número chama, edite somente a constante `GESTURES` em `prototipo_3d/scripts/prototipo_3d/authored_animator.gd`. Para nomes diferentes de parado/andar/correr, ajuste `MOTION_CLIPS` no mesmo arquivo. Assim o controlador de física e a câmera não precisam mudar.

## Casa gerada no Tripo

A casa à direita da praça, próxima à horta, usa
`assets/prototipo_3d/casas/casa_carro_quebrado_tripo.glb`. O arquivo foi gerado
no Tripo a partir de uma referência preparada, exportado com texturas 2K e
otimizado antes de entrar no jogo.

O original tinha aproximadamente 64,8 MB e 1.915.732 triângulos. A versão do
protótipo tem aproximadamente 13 MB e 273.548 triângulos, com LODs e malha de
sombra gerados pelo importador do Godot. O original permanece somente em
`.assets-raw/tripo/casas/`, fora do Git.

`world_builder.gd` instancia o GLB, ajusta sua largura para 5,2 metros, apoia a
base no terreno e cria uma colisão `BoxShape3D` a partir dos limites reais da
malha. Para substituir essa casa novamente, mantenha o nome estável do arquivo
ou altere `TRIPO_HOUSE_SCENE`; confira orientação, escala, material e colisão
antes de promover o novo asset. Origem e tarefa do Tripo estão registradas em
`assets/prototipo_3d/casas/ORIGEM.md`.

## Substituir o personagem

1. Coloque o novo GLB e suas texturas em `prototipo_3d/assets/prototipo_3d/personagem/`.
2. Em `prototipo_3d/scenes/prototipo_3d/personagem.tscn`, altere **Model Scene** do nó `Jogador`.
3. O controlador ajusta escala, centralização e altura. Se a frente estiver invertida, ajuste **Model Yaw Offset**; `PI` corresponde a 180°.
4. Confira o esqueleto e os clipes no importador. Outro rig pode exigir retargeting; um GLB que já reúne o modelo e suas animações, como o atual, não precisa desse passo.
5. Execute o teste integrado antes de enviar a mudança.

## Validar pelo terminal

Com o Godot 4.7.2 instalado no caminho usado pelo projeto:

```powershell
& 'C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe' `
  --path 'C:\VIRTUALENVS\myths-valley\myths-valley-3D\prototipo_3d' `
  --script 'res://tools/prototipo_3d/smoke_test.gd'
```

O teste confirma modelo, textura, 65 ossos, nomes dos 11 clipes, locomoção, oito gestos, escala, chão, colisões, câmera, reinício e os três destinos. Ele precisa do renderer normal para testar entrada de mouse e produzir capturas; o modo `--headless` não representa esse trecho corretamente.

## Estrutura relevante

```text
myths-valley-3D/
├── docs/COMO_JOGAR_3D.md
└── prototipo_3d/
    ├── JOGAR_3D.cmd
    ├── project.godot
    ├── assets/prototipo_3d/
    │   ├── casas/                        # Casa otimizada e registro de origem
    │   └── personagem/                   # GLB animado e origem
    ├── scenes/prototipo_3d/              # Vale e personagem reutilizável
    ├── scripts/prototipo_3d/             # Controle, animação, cenário e HUD
    └── tools/prototipo_3d/               # Inicialização e teste integrado
```

Godot validado: `4.7.2.stable.official.ed1daf0bf`, renderer Forward+. Se a GPU não suportar esse perfil, execute `JOGAR_3D.cmd -Compatibility`.

A máquina de preparação ainda não possui os templates de exportação Windows correspondentes. Isso não impede o teste local, mas uma versão `.exe` distribuível exige instalar os templates antes.
