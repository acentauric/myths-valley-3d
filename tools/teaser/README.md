# Teaser do Tripothon

Teaser de 70 s sobre a narração em inglês gerada no Suno (13/10/2026). A primeira
metade é a travessia pintada (os clipes LTX da introdução, #129) até "Bom Jesus dos
Pobres". A segunda metade é o jogo de verdade.

| Arquivo | O que é |
|---|---|
| `diretor.gd` / `diretor.tscn` | Monta o vale sem HUD, assume a câmera e grava cada tomada em PNG, quadro a quadro |
| `tomadas.json` | As 10 tomadas do jogo: lugar, hora, câmera, jogador, Pedro e ação |
| `plano.json` | A montagem: cortes em segundos da faixa e fusões, com o jogo ou o LTX em cada tomada |
| `legendas.ass` | Legendas em inglês, em Cormorant Garamond |
| `montar.py` | Junta tudo com o áudio e o cartão final |

## 1. Gravar as tomadas do jogo

Rode com passo fixo, para o tempo do jogo andar 1/30 s por quadro:

```
godot --path . --fixed-fps 30 res://tools/teaser/diretor.tscn -- --lugar=praca --sem-sustos \
    --plano=<abs>/tools/teaser/tomadas.json --saida=<abs>/quadros
```

- `--previa` grava só o primeiro e o último quadro de cada tomada, para conferir o enquadramento.
- `--so=pesca,mata` refaz só essas tomadas.
- Num Linux sem GPU, use `xvfb-run` com `--rendering-driver vulkan` e o lavapipe (`mesa-vulkan-drivers`). Leva cerca de 1,2 s por quadro em 1080p.

## 2. Montar

```
python tools/teaser/montar.py --audio teaser.mp3 --quadros <abs>/quadros teaser.mp4
```

## 3. Versão com o jogo animado pelo LTX (custa crédito)

`tools/ltx/gerar-teaser.ps1` gera um clipe image-to-video por tomada. Cada clipe parte do
primeiro quadro da tomada (`tools/ltx/teaser/entrada/`) e usa o prompt de
`tools/ltx/teaser/plano.json`. São 9 clipes de 6 s, cerca de US$ 9,20.

Confira a estimativa antes de gerar:

```
powershell -NoProfile -ExecutionPolicy Bypass -File tools\ltx\gerar-teaser.ps1 -SoEstimar
```

Depois de gerar, monte com `--versao ltx --clipes .assets-raw/ltx/teaser/clipes`. A tomada
que não tiver clipe continua com a imagem do jogo; o cordel, por exemplo, fica sempre como no
jogo.
