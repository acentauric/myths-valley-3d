# Myths' Valley 3D

Um vale do Recôncavo Baiano de 1887, explorado em terceira pessoa: moradores,
missões, marés, mata, ferramentas, pesca, combate, cartas e três vagas de save.

Este repositório contém somente o jogo 3D. Godot 4.7.2 Standard, GDScript e
renderer Forward+. O projeto está na raiz e funciona sem outro checkout.

## Abrir e jogar

```powershell
git clone https://github.com/acentauric/myths-valley-3d.git
cd myths-valley-3d
git lfs pull
.\JOGAR_3D.cmd
```

Instale Git LFS antes de clonar; modelos GLB, FBX históricos e áudio WAV usam LFS.
No editor, importe `project.godot`. O atalho aceita `-Godot CAMINHO.exe`,
`-Compatibility` e `-Lugar igreja`. Os controles estão em
[Como jogar](docs/experiencia/COMO_JOGAR_3D.md).

JOGAR usa uma das três vagas; EXPLORAR abre um passeio sem salvar. O diretório
`MythsValleyPrototype3D` permanece para manter compatibilidade com as partidas
existentes. Os recursos de jogo ficam inteiramente neste repositório.

## Desenvolvimento e testes

```powershell
.\tools\prototipo_3d\testar.ps1
.\tools\prototipo_3d\testar.ps1 -Teste salvamento
```

Cada teste usa um perfil temporário próprio, com teto de execução e conferência
de erros de compilação. Os testes gráficos também precisam ser rodados com o
renderer normal; detalhes em [Validação](docs/projeto/VALIDACAO.md).

Trabalhe em `feature/<nome>`. A próxima tarefa vem das
[issues](https://github.com/acentauric/myths-valley-3d/issues) e do
[plano](docs/projeto/PLANO.md). O estado dos sistemas está no
[histórico](docs/projeto/CHANGELOG_3D.md).

## Estrutura

| Pasta | Conteúdo |
| --- | --- |
| `assets/` | Modelos, texturas, interface, fontes e áudio usados pelo jogo |
| `scenes/` | Abertura, vale, personagem e terreno editável |
| `scripts/` | Sistemas de jogo, autoloads, interface e mundo |
| `data/` | Moradores, missões, regras e geografia |
| `tests/` | Portões de comportamento do jogo |
| `tools/` | Testes e preparação de mapas, modelos e áudio |
| `docs/` | Design, mundo, produção e planejamento |

`scripts/compartilhado/` mantém seu nome para preservar os caminhos e UIDs,
mas seus sistemas pertencem a este projeto e evoluem aqui. Não existe
sincronização automática com outro repositório.

## Arte, áudio e exportação

O catálogo é a fonte de caminhos, escala e colisão dos modelos. Consulte
[Assets Tripo](docs/arte/ASSETS_TRIPO.md), [créditos](assets/CREDITOS.md) e os
`ORIGEM.md` antes de promover assets. Geração paga só ocorre quando solicitada.

A exportação Windows usa `export_presets.cfg` e grava em `build/windows/`.
Crie essa pasta antes da primeira exportação.
Instale os templates da mesma versão do Godot. Caches, builds, arquivos brutos
e credenciais ficam fora do Git. O clone não precisa de chaves para jogar.
