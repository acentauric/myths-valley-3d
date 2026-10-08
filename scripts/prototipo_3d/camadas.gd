extends RefCounted
## AS CAMADAS FÍSICAS DO VALE, com nome. Sem `class_name`: carrega-se com
## `preload`, como o `IdiomaMenu`. Os mesmos nomes estão em `[layer_names]` no
## `project.godot`, para o editor mostrar o que cada bit é.
##
## A CÂMERA É POR ADESÃO. O braço da câmera (`player_controller.gd`) só bate no
## que tem o bit `CAMERA`: o terreno, o chão do mar, a borda do quadro, a água
## (`Mar._superficie_da_camera`), as construções e pedras do catálogo
## (`"camera"`), as paredes dos cômodos e a laje do píer e da ponte. O resto da
## camada `MUNDO` — tronco, morador, bicho, poste, mastro, cruzeiro, cerca,
## barco, móvel — continua barrando o corpo e o clique, e deixa a câmera passar.
##
## "A câmera dá um pulo ao passar na frente do cruzeiro": o braço batia em tudo
## da camada 1 e encolhia de 8 m para 1 m num quadro. Peça fina não é parede, e
## câmera de jogo em terceira pessoa não foge dela.

## Tudo o que tem corpo no vale: chão, paredes, troncos, moradores, peças.
const MUNDO := 1
## As cercas de varas das roças (#104): barram o corpo do jogador (a máscara
## dele tem o bit). Desde #125 elas também estão na camada `MUNDO`, que a malha
## de navegação dos moradores lê: as rotas do vale contornam as roças.
const CERCA := 1 << 3
## As áreas de clique das casas (`world_builder.gd`, `HOUSE_INTERACTION_LAYER`).
const CLIQUE_CASA := 1 << 12
## O que barra o braço da câmera. É o mesmo bit que nasceu para a superfície da
## água (`Mar.CAMADA_CAMERA_AGUA`) e as cortinas da porta do cômodo.
const CAMERA := 1 << 13
## Malha próxima da vegetação, consultada somente pela câmera automática.
const CAMERA_VEGETACAO := 1 << 15
## A medição temporária da casca de uma construção (`interiores.gd`).
const MEDIR := 1 << 19
## A casca de uma construção como a vê o olho, para auditar a colisão contra ela (#205,
## `auditoria_de_geometria.gd`): só o portão e o testador a criam, e nunca barra ninguém.
const AUDITORIA := 1 << 20

## Camada de quem barra o corpo E a câmera.
const MUNDO_E_CAMERA := MUNDO | CAMERA
