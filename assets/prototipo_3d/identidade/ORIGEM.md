# Identidade visual — "Crônica do Recôncavo"

Peças da identidade escolhida em 28/09/2026 (Direção A da página de estudo "Duas telas
do vale"). O logotipo é peça própria da identidade: serve para a tela de carregamento
hoje e para outros usos que ainda vão ser definidos (menu, capa, loja, créditos).

| Arquivo | O que é | Uso atual |
| --- | --- | --- |
| `logo_myths_valley.png` | Logotipo "Myths' Valley" em talha dourada com arabesco e azulejo cobalto no centro; fundo transparente, 1496×431, recortado rente | tela de carregamento (alto à esquerda) |
| `capa_dia.webp` | Capa pintada de Bom Jesus dos Pobres ao entardecer: igreja, píer, saveiro, canoas e a mata; 2048×1152 (16:9) | tela de carregamento de dia |
| `capa_noite.webp` | Capa pintada da noite: o viajante com o lampião na boca da mata, a lua sobre a baía e a igreja lá embaixo; 2048×1152 | tela de carregamento de noite (entra espelhada) |
| `rosa_dos_ventos.png` | Rosa dos ventos em ouro com anel de azulejo cobalto; fundo transparente, 512×512 | indicador de carregamento (gira) e marcador de foco das placas da home |
| `moldura_retabulo.png` | Moldura de talha dourada com fio cobalto, volutas de acanto e losangos de azulejo nos cantos; interior em laca lisa (achatado por script), 994×1502, fundo externo transparente | NinePatch do retábulo da home e de todos os modais (identidade.gd, margens 140/150/140/160, escala 0,3) |
| `cursor_seta.png`, `cursor_mao.png` | Cursor Clássico: seta e mão em ouro com contorno de laca, 40×40 (`tools/prototipo_3d/cursor/gerar_cursor.py`) | opção Clássico do cursor (`Tela.CURSORES`) |
| `cursores/*.png` | Os outros cinco conjuntos de cursor (ouro, azulejo, talha, pergaminho, lampião), seta e mão, 40×40, desenhados em SVG em `tools/prototipo_3d/cursor/desenhos.js` e rasterizados por `gerar_cursores.js` | escolha do cursor em AJUSTAR > Cenário; o padrão é o Ouro polido |
| `icone/icone.png`, `icone/icone.ico` | Ícone do jogo: o M dourado do logotipo, recortado do fundo, numa pastilha de laca escura com filete de ouro; PNG 512×512 e .ico com 16, 24, 32, 48, 64, 128 e 256 px (quadros BMP), gerados por `tools/prototipo_3d/icone/gerar_icone.py` a partir de `logo_myths_valley.png` | `application/config/icon`, `windows_native_icon` e o `.exe` exportado (#230) |

## Como foram feitas

Geradas com a API de imagens da OpenAI, modelo `gpt-image-2`, qualidade `high`
(capas em 2048×1152; logotipo em 1536×1024 e rosa em 1024×1024, ambos com fundo
transparente). A chave vem do `.env` do repositório. Os PNGs originais e o script com
os prompts completos ficam fora do Git, em `.assets-raw/openai/telas_carregamento/`
(`gerar.py`). A igreja das capas foi descrita a partir do modelo do jogo: caiada, barrado
ocre, frontão de volutas com óculo, porta azul e torre com telhado de barro.

A capa da noite também foi a Direção B do mesmo estudo ("A Mata Não Dorme"); dela ficou
só a arte. A moldura veio da rodada da home (29/09/2026, estudo "Home do Vale", proposta
"Retábulo"): gerada em 1024×1536 com fundo transparente, recortada rente e com o interior
substituído por laca chapada via script (`.assets-raw/openai/home/gerar_moldura.py`).
Fontes da interface: Cinzel e Cormorant Garamond (`assets/fonts/`, licença OFL).

Conferir as condições de uso comercial vigentes da OpenAI antes de publicar.
