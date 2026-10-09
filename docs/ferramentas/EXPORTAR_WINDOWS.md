# Exportar o jogo para Windows

O que a exportação pede, na ordem em que cada coisa já travou um build. A receita
curta está no [README](../../README.md#testar-exportar-e-atualizar); aqui ficam os
pré-requisitos e a conferência do resultado.

## Pré-requisitos

1. **Godot 4.7.2 Standard** em `C:\Tools\Godot\`, e os **modelos de exportação** da mesma
   versão (`%APPDATA%\Godot\export_templates\4.7.2.stable\windows_release_x86_64.exe`).
2. **rcedit**, que grava no `.exe` o ícone, a empresa, o nome do produto e a descrição.
   **Sem ele a exportação termina sem erro e o executável sai com o ícone genérico do
   Godot** (foi o que aconteceu até a Build 10, #230). Instale uma vez por máquina:
   1. baixe `rcedit-x64.exe` da versão 2.0.0 em
      <https://github.com/electron/rcedit/releases/tag/v2.0.0> (licença MIT) para
      `C:\Tools\rcedit\rcedit-x64.exe`;
   2. no editor do Godot: **Editor → Configurações do Editor → Exportar → Windows**,
      campo **Rcedit**, e aponte para esse arquivo (`export/windows/rcedit` no
      `editor_settings-4.7.tres`). Feche o editor antes de editar o arquivo à mão: ele
      regrava as configurações ao sair;
   3. a exportação por linha de comando (`--headless --export-release`) usa a mesma
      configuração do editor, então não há segunda configuração a fazer.
3. **Ícone do jogo**: `assets/prototipo_3d/identidade/icone/icone.png` (512×512, janela e
   barra de tarefas) e `icone.ico` (16, 24, 32, 48, 64, 128 e 256 px, para o `.exe` e para
   `application/config/windows_native_icon`). Saem do M do logotipo por
   `python tools/prototipo_3d/icone/gerar_icone.py` (precisa de `pillow`, `numpy` e
   `opencv-python`); não gasta crédito de geração.

Os dois presets (**Windows Desktop** e **Windows Tripothon**) já apontam para o `.ico`
(`application/icon` e `application/console_wrapper_icon`) e trazem empresa, produto e
descrição; o `include_filter` leva a pasta do ícone para dentro do pacote, que é de
onde o jogo lê o ícone da janela em execução.

## Exportar

```powershell
New-Item -ItemType Directory -Path build/windows -Force
& 'C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --export-release 'Windows Desktop' build/windows/MythsValley3D.exe
```

Os builds e zips ficam em `D:\myths-valley-builds` (o disco C: enche; confira
`Get-PSDrive C` antes).

## Conferir o resultado

```powershell
.\tools\prototipo_3d\conferir_icone_do_exe.ps1 -Exe build/windows/MythsValley3D.exe
.\tools\prototipo_3d\conferir_fechamento_de_build.ps1 -Zip D:\myths-valley-builds\<zip>
```

O primeiro tira o ícone do executável e o compara com o `icone.ico`: reprova o ícone
genérico do Godot (rcedit ausente ou mal apontado). O segundo confere o tamanho do zip
contra os limites do atualizador (#231).

À vista: o Explorer mostra o M dourado no `MythsValley3D.exe`, e a janela, a barra de
tarefas e o Alt+Tab mostram o mesmo ícone. Se o Explorer ainda mostrar o antigo, é o cache
de ícones do Windows: rode `ie4uinit.exe -show` ou renomeie a pasta do build.

## A build do Tripothon

A **Build 9B** (edição do concurso, preset Windows Tripothon) está travada para o download da
Tripo e **não** se refaz por causa do ícone. O preset dela ganhou o ícone só para uma
exportação futura, se a edição um dia for refeita; o pacote já publicado não muda.
