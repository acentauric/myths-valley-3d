# Jogar e aprender com o protótipo 3D

Abra `JOGAR_3D.cmd`. O atalho importa os recursos e abre o jogo usando o Godot instalado em `C:\Tools\Godot`.

**JOGAR** pergunta em qual das **três vagas** jogar: vaga vazia começa ali, pela travessia; vaga ocupada continua de onde parou. Recomeçar uma vaga ocupada pede um segundo clique, e o botão diz de quem é a partida que vai ser apagada. **EXPLORAR** é o passeio livre: não usa vaga, não salva e não apaga nada. A partida salva ao cair (a noite no chão), ao voltar ao menu e ao fechar a janela.

Para depurar, `JOGAR_3D.cmd -Lugar igreja` começa o jogador direto num lugar do vale (`praca`, `igreja`, `cemiterio`, `mirante`, `pier`, `rocado`...), sem refazer o caminho; pelo Godot, é `-- --lugar=igreja` depois dos argumentos do projeto.

No Godot Project Manager, outra opção é importar **`project.godot`** e executar o projeto (F6 abre apenas a cena selecionada; F5 abre pela tela inicial). A raiz contém o jogo 3D independente, sem depender do projeto 2D.

## Controles

As letras marcadas com * são **remapeáveis** em AJUSTAR → Geral → Atalhos; o HUD e o painel mostram sempre a letra escolhida. W, A, S e D não entram na troca, porque andam e escolhem dentro das telas. A tecla de fábrica vem entre parênteses.

**Andar e olhar**

| Tecla | Ação |
| --- | --- |
| WASD / setas | Mover em relação à câmera e cancelar a caminhada automática (AJUSTAR → Geral escolhe WASD, setas ou os dois) |
| Shift (um toque) | Ativar ou desativar a corrida; ela desliga sozinha quando o personagem para, e gasta vigor |
| Espaço | Pular a partir do chão |
| Mouse | Com a câmera solta, girar a câmera sem clicar; com a câmera travada, arrastar o cenário. O modo com que o jogo abre fica em AJUSTAR → Câmera do mouse |
| Tab ou Câmera* (C) | Alternar entre câmera solta e travada |
| Ctrl+rodinha, + e - | Aproximar ou afastar a câmera |
| Observar* (F) | Olhar o personagem pela frente; de novo, volta |
| Clique direito | Caminhar até o chão, casa ou morador apontado; duplo clique corre |
| Clique esquerdo na casa | Abrir os dados da casa no balão e no painel, mesmo à distância; fora das casas, fecha |
| Mapa* (M) | O vale visto de cima: o jogador para, o mundo continua. M ou Esc fecham; o minimapa liga em AJUSTAR |

**Agir**

| Tecla | Ação |
| --- | --- |
| Ler / interagir* (E) | Falar, ler, pegar, pescar, tocar obra. Perto de um bicho, golpe com a arma na mão (ou a meia-lua, de mão vazia, para quem aprendeu); **segurar** dá o golpe forte (ou a rasteira) |
| Gingar* (V) | Sair do bote do bicho, para quem aprendeu a capoeira |
| 1 a 9 e 0 | Pôr na mão o item daquele espaço da barra de mão (o 0 é o décimo) |
| Rodinha | Passar a mão para o espaço seguinte (para baixo) ou o anterior (para cima), como no 2D |
| Alt+1 a Alt+8 | Gestos: saudação, tchau, concordar, olhar ao redor, medo, braços cruzados, golpe, nado |
| Avançar a hora* (T) | Adiantar o relógio do vale em uma hora |
| Reiniciar* (R) | Voltar ao ponto inicial |

**Telas** — só uma fica aberta por vez, e abrir outra fecha a que estava; enquanto uma tela está aberta, o vale para atrás dela. A mesma tecla ou o Esc fecham.

| Tecla | Tela |
| --- | --- |
| Mochila* (I) | Os 30 espaços (os 10 primeiros são a barra de mão) à esquerda, o que o corpo veste à direita. As setas ou WASD escolhem, F veste ou come o que está sob o cursor, E pega e solta para arrumar; com o mouse, arrastar arruma e o segundo clique veste ou come |
| Painel* (J) | Missões, cartas e, perto do lugar certo, venda, fogão, bancada e obras; pelo botão JOGO, salvar, voltar ao menu e sair. Dentro dele, Tab troca de aba, W/S escolhem, E confirma |
| Árvore de habilidades* (K) | A teia de talentos, onde se gasta o ponto que o vale dá |
| Almanaque* (L) | O caderno do que já se viu: plantas, cordéis, sinais e bichos. A vaga em branco mostra quantos faltam achar |
| O arraial* (P) | Quem mora no vale e o quanto cada um gosta de você |
| Esc | O menu do jogo: voltar ao vale, mapa, ajustes, controles, salvar, som, relógio, velocidade do tempo, câmera do mouse, voltar ao menu inicial e sair |
| Alt+F4 / fechar janela | Sair (a partida salva antes) |

**Fala longa** — o que precisa ser lido antes de seguir (a conversa de um pacto) abre numa caixa no rodapé, e o vale para enquanto ela está aberta. E ou Esc passam a linha. Numa pergunta, A escolhe Sim, D escolhe Não e E confirma; sem escolher, o E não responde, e Esc é sempre Não. O cumprimento de passagem dos moradores continua no balão sobre a cabeça.

No estilo **Procedural** (AJUSTAR → Cenário e tempo) as teclas Alt+1 a Alt+8 acionam os gestos do humanoide por código (acenar, concordar, apontar, coçar a cabeça, alongar, chamar, reverência, olhar em volta). O jogador começa no píer, com o Pedro ao lado: fale com ele e siga as missões do HUD. Os moradores cumprimentam quando você chega perto. Detalhes em [VALE_VIVO_3D.md](../mundo/VALE_VIVO_3D.md).

Parado, o personagem reproduz `idle`. Um gesto termina naturalmente e volta para `idle`; começar a andar interrompe o gesto. Explore a praça, a horta e a costa: o indicador acompanha os três pontos visitados.

## O que este teste entrega

- GLB do Tripo com malha, materiais, esqueleto de 65 ossos e 12 animações incorporadas.
- Locomoção automática com os clipes `idle`, `walk` e `run`.
- Oito gestos acionáveis por Alt+1 a Alt+8 e `pular_baixo` pela barra de espaço no estilo Tripo.
- Escala ajustada para 1,78 m, colisor de cápsula, aceleração, gravidade e rotação.
- Câmera em terceira pessoa com `SpringArm3D`, zoom e reação a obstáculos.
- Vila de teste com casas, caminhos, horta, árvores, praia, iluminação e colisões.
- Casa de Carro Quebrado gerada no Tripo, otimizada, escalada e com colisão simples.
- Interface, reinício de posição e três pontos de exploração.

As casas usam seus pontos geográficos como referência, mas a posição final é procurada em terra com espaço para a construção inteira, fora de todas as ruas e árvores. Árvores manuais que coincidiriam com uma casa são reposicionadas. A Casa da estrada também segue essa regra; sua coordenada KML continua sendo a referência inicial.

As animações foram exportadas **no lugar**: os clipes mexem o esqueleto, enquanto o `CharacterBody3D` controla o deslocamento e as colisões. No salto, o deslocamento vertical do quadril no clipe foi neutralizado para começar no chão. O controlador aplica impulso vertical, gravidade de 15 unidades/s² na subida e 25 unidades/s² na descida.

O material continua sendo duplicado apenas na instância e renderizado dos dois lados. Essa correção evita o desaparecimento de partes do torso sem alterar o arquivo 3D original.

Com a **vara de pescar** na mão (vende no balcão) e a água à frente — o píer, a praia, a beira do rio —, E lança a linha; quando a bóia afunda e acende o "!", E de novo, rápido, ferra o peixe. No rio sai traíra, no mar sai robalo. Andar recolhe a linha. Perto da **fogueira do terreiro**, ao lado da Casa de taipa, o painel (J) ganha a aba do fogão, e na **bancada da oficina** (a caixa cinza na beira do roçado) a lenha vira tábua e corda. Perto da Casa de taipa, do armazém (Venda do Bar), do mirante, do poço e do píer, o painel (J) ganha a aba de **obras** daquela construção: com o plano sabido e o material na mochila, E toca a obra, e o ganho dela vai para o corpo (fôlego, descanso). Os planos de começo já se sabem; outros se compram no balcão. Por enquanto a casa não muda por fora nem por dentro — os modelos novos e o cômodo ainda não chegaram. Um **caititu** mora na mata fechada, longe da vila (por enquanto uma caixa cinza, até o modelo com rig chegar): fareja quem chega perto, **anuncia o bote** — acende em âmbar, abaixa e marca no chão até onde a mordida alcança — e só então morde. Derrubado, deixa a carne de caça na mochila e volta em três dias. Para lutar de facão, escolha-o na barra de mão (1–0 ou a rodinha) ou vista-o no encaixe Mãos da mochila (I). Pelo arraial há **cordéis** esquecidos — no balcão da venda, na capela velha, no bar, no cemitério, no mirante, na ponta do píer: chegue perto e aperte E para guardá-los no almanaque (L). O cordel achado abre no papel, para ler inteiro; E, Esc ou um clique o guardam. No almanaque, escolher de novo o cordel aberto o relê no papel. Na mata fechada, longe da vila, a Caipora deixa um **sinal**; depois de vê-lo aparecem ali as cartas dela. Pegar a carta de pacto abre a conversa dela na caixa de fala — o que ela dá, o que cobra — e a pergunta **Firmar?**: Sim firma ali mesmo, Não deixa a carta com você (o pacto também se firma e se desfaz no painel, aba Cartas). A **vida** já aparece: a barra logo abaixo do relógio, vermelha (verde-musgo com peçonha). Embaixo dela, o **fôlego**: verde, e vermelho com "cansado" quando o corpo está no fim — o passo encurta e não dá para correr até comer ou dormir. Quem cai acorda na porta da Casa de taipa às 6h do dia seguinte, inteiro: no escuro, o cartão do amanhecer diz o dia, a estação, o fôlego e o que está marcado (E pula a espera), e ao clarear alguém conta o que houve, na caixa de fala. A regra de mochila, missões, fé, receitas, luta, obras, venda, pesca, cartas e salvamento também já roda no vale, vinda do 2D, mas o jogador ainda não a vê: faltam as telas e os gatilhos. Os saves ficam no diretório de usuário `MythsValleyPrototype3D`, separados dos da versão 2D. Plantação, terrenos e a conversa por IA ainda não existem no 3D. O que falta, e em que ordem, está nas [issues com rótulo `3d`](https://github.com/acentauric/myths-valley-3d/issues?q=is%3Aissue+is%3Aopen+label%3A3d) e no [plano de migração](../projeto/MIGRACAO_2D_3D.md).

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
5. Copie o resultado para `assets/prototipo_3d/personagem/`.
6. Use um nome estável, como `medieval_character_animated.glb`, e no Godot escolha **Reimport** se tiver substituído o arquivo.
7. Confirme no `AnimationPlayer` se os nomes esperados aparecem antes de alterar o código.

O arquivo atual contém estes 12 clipes: `afraid`, `agree`, `chop`, `fold_arms`, `greet_01`, `idle`, `jump_down`, `look_around`, `run`, `swim`, `walk` e `wave_goodbye_02`.

Para trocar quais gestos as teclas 1–8 e a barra de espaço chamam, edite somente a constante `GESTURES` em `scripts/prototipo_3d/authored_animator.gd`. Para nomes diferentes de parado/andar/correr, ajuste `MOTION_CLIPS` no mesmo arquivo. Assim o controlador de física e a câmera não precisam mudar.

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

1. Coloque o novo GLB e suas texturas em `assets/prototipo_3d/personagem/`.
2. Em `scenes/prototipo_3d/personagem.tscn`, altere **Model Scene** do nó `Jogador`.
3. O controlador ajusta escala, centralização e altura. Se a frente estiver invertida, ajuste **Model Yaw Offset**; `PI` corresponde a 180°.
4. Confira o esqueleto e os clipes no importador. Outro rig pode exigir retargeting; um GLB que já reúne o modelo e suas animações, como o atual, não precisa desse passo.
5. Execute o teste integrado antes de enviar a mudança.

## Validar pelo terminal

Com o Godot 4.7.2 instalado no caminho usado pelo projeto:

```powershell
& 'C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe' `
  --path 'C:\VIRTUALENVS\myths-valley\myths-valley-3D' `
  --script 'res://tools/prototipo_3d/smoke_test.gd'
```

O teste confirma modelo, textura, 65 ossos, nomes dos 12 clipes, locomoção, nove gestos no estilo Tripo, escala, chão, colisões, câmera, reinício e os três destinos. Ele precisa do renderer normal para testar entrada de mouse e produzir capturas; o modo `--headless` não representa esse trecho corretamente.

## Estrutura relevante

```text
myths-valley-3d/
├── project.godot
├── JOGAR_3D.cmd
├── assets/
├── scenes/
├── scripts/
├── data/
├── tests/
├── tools/
└── docs/
```

Godot validado: `4.7.2.stable.official.ed1daf0bf`, renderer Forward+. Se a GPU não suportar esse perfil, execute `JOGAR_3D.cmd -Compatibility`.

A build Windows pode ser baixada em [mythsvalley.app.br/jogar](https://mythsvalley.app.br/jogar). Para exportar o projeto, instale os templates da mesma versão da engine e use o preset `Windows Desktop`; o executável inclui o pacote de recursos.
