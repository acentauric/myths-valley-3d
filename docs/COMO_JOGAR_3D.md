# Jogar e aprender com o protótipo 3D

Abra `prototipo_3d/JOGAR_3D.cmd`. O atalho importa os recursos e abre o jogo usando o Godot instalado em `C:\Tools\Godot`.

**JOGAR** pergunta em qual das **três vagas** jogar: vaga vazia começa ali, pela travessia; vaga ocupada continua de onde parou. Recomeçar uma vaga ocupada pede um segundo clique, e o botão diz de quem é a partida que vai ser apagada. **EXPLORAR** é o passeio livre: não usa vaga, não salva e não apaga nada. A partida salva ao cair (a noite no chão), ao voltar ao menu e ao fechar a janela.

Para depurar, `JOGAR_3D.cmd -Lugar igreja` começa o jogador direto num lugar do vale (`praca`, `igreja`, `cemiterio`, `mirante`, `pier`, `rocado`...), sem refazer o caminho; pelo Godot, é `-- --lugar=igreja` depois dos argumentos do projeto.

No Godot Project Manager, outra opção é importar **`prototipo_3d/project.godot`** e executar `scenes/prototipo_3d/vale.tscn`. O `project.godot` da raiz continua sendo a base 2D.

## Controles

| Tecla | Ação |
| --- | --- |
| Início / câmera destravada | Mouse capturado; mover o mouse gira a câmera sem clicar |
| Tab | Alternar entre câmera destravada e travada |
| Botões redondos do canto direito | Som, relógio (pausar/retomar o dia), HOME, câmera (travar/destravar; Tab e Esc também), velocidade do tempo (clique alterna) e estilo visual — a dica do estilo mostra FPS, triângulos e memória de vídeo |
| Arrastar com botão esquerdo e câmera travada | Mover o cenário junto com o cursor para girar a câmera; um clique sem arrastar ainda interage com as casas |
| Clique direito com cursor livre | Caminhar até o chão, casa ou NPC apontado |
| Duplo clique direito com cursor livre | Correr até o chão, casa ou NPC apontado |
| Mouse sobre uma casa | Mostrar nome e dica de interação |
| Clique esquerdo em uma casa | Abrir as mesmas propriedades no balão e no painel da interface, mesmo à distância |
| Clique esquerdo fora das casas | Fechar o balão e o painel de propriedades |
| WASD / setas | Mover em relação à câmera e cancelar a caminhada automática; reproduz `walk` |
| Shift (um toque) | Ativar ou desativar corrida; ela continua em qualquer direção e desliga automaticamente quando o personagem para; solte Shift e use W + Espaço para pular correndo |
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
| Barra de espaço | Pular a partir do chão; subida e descida usam gravidades diferentes |
| Esc | Travar a câmera e liberar o cursor |
| E perto de um bicho | Golpe com a arma na mão (ou a meia-lua, de mão vazia, para quem aprendeu); **segurar** dá o golpe forte (ou a rasteira) |
| V | Ginga: sair do bote do bicho, para quem aprendeu a capoeira (remapeável em AJUSTAR) |
| R | Voltar ao ponto inicial |
| T | Adiantar o relógio do vale em uma hora (ver dia e noite) |
| J | Painel: missões, cartas, venda (no balcão da Venda do Bar) e, pelo botão JOGO, salvar, voltar ao menu e sair. Dentro dele, Tab troca de aba, W/S escolhem, E confirma, Esc ou J fecham; o relógio para enquanto ele está aberto |
| L | Coleção: cordéis, sinais e bichos, com a vaga em branco de quem falta achar. Tab troca de coleção, W/S escolhem, L ou Esc fecham |
| M | Voltar ao menu (HOME) |
| Alt+F4 / fechar janela | Sair |

No estilo **Procedural** (AJUSTAR → Cenário e tempo) as teclas 1–8 acionam os gestos do humanoide por código (acenar, concordar, apontar, coçar a cabeça, alongar, chamar, reverência, olhar em volta). O jogador começa no píer, com o Pedro ao lado: fale com ele e siga as missões do HUD. Os moradores cumprimentam quando você chega perto. Detalhes em [VALE_VIVO_3D.md](VALE_VIVO_3D.md).

Parado, o personagem reproduz `idle`. Um gesto termina naturalmente e volta para `idle`; começar a andar interrompe o gesto. Explore a praça, a horta e a costa: o indicador acompanha os três pontos visitados.

## O que este teste entrega

- GLB do Tripo com malha, materiais, esqueleto de 65 ossos e 12 animações incorporadas.
- Locomoção automática com os clipes `idle`, `walk` e `run`.
- Oito gestos acionáveis pelas teclas 1–8 e `pular_baixo` pela barra de espaço no estilo Tripo.
- Escala ajustada para 1,78 m, colisor de cápsula, aceleração, gravidade e rotação.
- Câmera em terceira pessoa com `SpringArm3D`, zoom e reação a obstáculos.
- Vila de teste com casas, caminhos, horta, árvores, praia, iluminação e colisões.
- Casa de Carro Quebrado gerada no Tripo, otimizada, escalada e com colisão simples.
- Interface, reinício de posição e três pontos de exploração.

As casas usam seus pontos geográficos como referência, mas a posição final é procurada em terra com espaço para a construção inteira, fora de todas as ruas e árvores. Árvores manuais que coincidiriam com uma casa são reposicionadas. A Casa da estrada também segue essa regra; sua coordenada KML continua sendo a referência inicial.

As animações foram exportadas **no lugar**: os clipes mexem o esqueleto, enquanto o `CharacterBody3D` controla o deslocamento e as colisões. No salto, o deslocamento vertical do quadril no clipe foi neutralizado para começar no chão. O controlador aplica impulso vertical, gravidade de 15 unidades/s² na subida e 25 unidades/s² na descida.

O material continua sendo duplicado apenas na instância e renderizado dos dois lados. Essa correção evita o desaparecimento de partes do torso sem alterar o arquivo 3D original.

Um **caititu** mora na mata fechada, longe da vila (por enquanto uma caixa cinza, até o modelo com rig chegar): fareja quem chega perto, **anuncia o bote** — acende em âmbar, abaixa e marca no chão até onde a mordida alcança — e só então morde. Derrubado, deixa a carne de caça na mochila e volta em três dias. Para lutar de facão é preciso tê-lo na mão, o que por enquanto só a mochila (#2) vai permitir. Pelo arraial há **cordéis** esquecidos — no balcão da venda, na capela velha, no bar, no cemitério, no mirante, na ponta do píer: chegue perto e aperte E para guardá-los no almanaque (L). Na mata fechada, longe da vila, a Caipora deixa um **sinal**; depois de vê-lo aparecem ali as cartas dela. A carta de pacto diz o que dá e o que cobra, e **E de novo, ali**, firma o pacto (ele também se firma e se desfaz no painel, aba Cartas). A **vida** já aparece: a barra logo abaixo do relógio, vermelha (verde-musgo com peçonha). Embaixo dela, o **fôlego**: verde, e vermelho com "cansado" quando o corpo está no fim — o passo encurta e não dá para correr até comer ou dormir. Quem cai acorda na porta da Casa de taipa às 6h do dia seguinte, inteiro — ainda não há nada no vale que tire vida, isso chega com a luta. A regra de mochila, missões, fé, receitas, luta, obras, venda, pesca, cartas e salvamento também já roda no vale, vinda do 2D, mas o jogador ainda não a vê: faltam as telas e os gatilhos. Os saves ficam no diretório de usuário `MythsValleyPrototype3D`, separados dos da versão 2D. Plantação, terrenos e a conversa por IA ainda não existem no 3D. O que falta, e em que ordem, está nas [issues com rótulo `3d`](https://github.com/acentauric/myths-valley/issues?q=is%3Aissue+is%3Aopen+label%3A3d) e no [plano de migração](MIGRACAO_2D_3D.md).

## Como a animação funciona

O fluxo é pequeno de propósito:

1. `personagem.tscn` aponta para `medieval_character_animated.glb`.
2. O Godot transforma o GLB em uma cena com `Skeleton3D`, malha e `AnimationPlayer`.
3. `player_controller.gd` instancia o modelo, normaliza a altura e envia a velocidade atual ao animador.
4. `authored_animator.gd` escolhe `idle`, `walk` ou `run` e mistura as transições em 0,18 segundo.
5. As teclas 1–8 pedem clipes de gesto; a barra de espaço inicia o salto e, no estilo Tripo, reproduz `pular_baixo` (`jump_down` no GLB). O salto continua até aterrissar, mesmo com movimento horizontal; os outros gestos são interrompidos pelo movimento.

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

O arquivo atual contém estes 12 clipes: `afraid`, `agree`, `chop`, `fold_arms`, `greet_01`, `idle`, `jump_down`, `look_around`, `run`, `swim`, `walk` e `wave_goodbye_02`.

Para trocar quais gestos as teclas 1–8 e a barra de espaço chamam, edite somente a constante `GESTURES` em `prototipo_3d/scripts/prototipo_3d/authored_animator.gd`. Para nomes diferentes de parado/andar/correr, ajuste `MOTION_CLIPS` no mesmo arquivo. Assim o controlador de física e a câmera não precisam mudar.

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

O teste confirma modelo, textura, 65 ossos, nomes dos 12 clipes, locomoção, nove gestos no estilo Tripo, escala, chão, colisões, câmera, reinício e os três destinos. Ele precisa do renderer normal para testar entrada de mouse e produzir capturas; o modo `--headless` não representa esse trecho corretamente.

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
