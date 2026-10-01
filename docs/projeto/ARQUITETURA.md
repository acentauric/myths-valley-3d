# Arquitetura do jogo 3D

O `project.godot` da raiz registra os autoloads e abre `inicio.tscn`.
As cenas do vale usam `CharacterBody3D`, âncoras de lugares e o catálogo de
modelos; a interface usa Control e CanvasLayer.

`scripts/compartilhado/` reúne regras de jogo sem dependência de checkout
externo. `scripts/autoload/` contém serviços do vale; `scripts/ui/` contém
suas telas. Os dados são lidos de `res://data/` e o save usa `user://`.

Os nomes internos `prototipo_3d` permanecem para manter referências de
recursos e UIDs. Existe apenas um projeto Godot neste repositório.

Modelos GLB e arquivos WAV usam Git LFS; `.godot/`, builds, temporários e
arquivos brutos são locais. Os parâmetros `.import` e `.gd.uid` versionados
preservam a identidade e as opções dos recursos.
