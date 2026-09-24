# Primeiro teste jogável 3D

Abra `JOGAR_3D.cmd` na raiz de `myths-valley-3D`. Ele importa os recursos e abre o jogo usando o Godot instalado em `C:\Tools\Godot`.

No Godot Project Manager, importe **`prototipo_3d/project.godot`** e pressione F6/F5 na cena `scenes/prototipo_3d/vale.tscn`. O `project.godot` da raiz ainda corresponde à base 2D.

## Controles

| Tecla | Ação |
| --- | --- |
| Clique esquerdo | Capturar o mouse e começar o passeio |
| WASD / setas | Movimento relativo à câmera |
| Shift | Correr |
| Mouse | Girar a câmera |
| Rodinha | Aproximar/afastar a câmera |
| F | Aproximar a câmera à frente do personagem; pressione novamente para voltar |
| Esc | Liberar o cursor e interromper o movimento |
| R | Voltar ao ponto inicial |
| Alt+F4 / fechar janela | Sair |

Explore a praça, a horta e a costa. O indicador acompanha os três pontos visitados.

## O que este teste entrega

- Personagem do ZIP enviado, importado em FBX com materiais/texturas.
- Escala ajustada para 1,78 m, colisor de cápsula, aceleração, gravidade e rotação.
- Câmera em terceira pessoa com SpringArm3D, zoom e reação a obstáculos.
- Pequena vila de teste com casas, caminhos, horta, árvores, praia, iluminação e colisões.
- Movimento provisório dos ossos para parado, caminhada e corrida.
- Interface, reinício de posição e três pontos de exploração.

O modelo tem **65 ossos e nenhum clipe de animação**. O movimento atual é procedural sobre o rig, sem IK de pés. Rigidez, pequenos deslizamentos e deformações da roupa podem aparecer. A próxima etapa do pipeline é importar clipes de parado, andar e correr do Mixamo e ajustar o retargeting.

Na importação original, partes do torso desapareciam com o descarte de faces traseiras. A comparação da pose original com o material de dois lados confirmou a causa. O controlador duplica o material na instância e habilita as duas faces (`Double Sided Materials`), mantendo o FBX intacto.

Este é o teste inicial do personagem/câmera. Farming, inventário, quests, NPCs e serviço LLM descritos no documento de decisões ainda precisam ser integrados. O passeio não grava progresso; o diretório de usuário próprio `MythsValleyPrototype3D` já separa futuros saves.

## Estrutura

```text
myths-valley-3D/
├── JOGAR_3D.cmd
├── docs/COMO_JOGAR_3D.md
└── prototipo_3d/
    ├── project.godot
    ├── assets/prototipo_3d/personagem/   # FBX; texturas extraídas pelo importador
    ├── scenes/prototipo_3d/             # Vale e personagem reutilizável
    ├── scripts/prototipo_3d/            # Controle, rig, cenário, HUD
    └── tools/prototipo_3d/              # Inicialização e teste integrado
```

O protótipo é um projeto Godot separado dentro da mesma branch. Isso permite carregar apenas seus recursos e configurações, sem inicializar os autoloads e telas da base 2D.

## Substituir o personagem

1. Coloque o novo FBX ou GLB e suas texturas em `prototipo_3d/assets/prototipo_3d/personagem/`.
2. Abra `prototipo_3d/scenes/prototipo_3d/personagem.tscn` e altere a propriedade exportada **Model Scene** do nó Jogador.
3. O controlador ajusta escala, centralização e altura; se a frente estiver invertida, ajuste **Model Yaw Offset** em radianos (`PI` corresponde a 180°).
4. O animador provisório reconhece os ossos `mixamorig_*` do modelo atual. Outros rigs/clipes exigem adaptação do animador; o controlador e a câmera permanecem reutilizáveis.

## Engine e renderer

Godot local: `4.7.2.stable.official.ed1daf0bf`. Primeiro perfil: Forward+. Se a GPU não suportar o perfil, execute `JOGAR_3D.cmd -Compatibility` ou o script PowerShell com `-Compatibility`.

O atalho depende do Godot local. Uma exportação Windows distribuível depende dos templates correspondentes, ausentes nesta máquina durante a preparação. Isso é diferente de validar a execução local fora da interface do editor.

Documentação do importador: [FBX via ufbx](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html). Documentação da câmera: [SpringArm3D](https://docs.godotengine.org/en/stable/classes/class_springarm3d.html).
