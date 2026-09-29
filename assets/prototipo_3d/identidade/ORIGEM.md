# Identidade visual — "Crônica do Recôncavo"

Peças da identidade escolhida em 28/09/2026 (Direção A da página de estudo "Duas telas
do vale"). O logotipo é peça própria da identidade: serve para a tela de carregamento
hoje e para outros usos que ainda vão ser definidos (menu, capa, loja, créditos).

| Arquivo | O que é | Uso atual |
| --- | --- | --- |
| `logo_myths_valley.png` | Logotipo "Myths' Valley" em talha dourada com arabesco e azulejo cobalto no centro; fundo transparente, 1496×431, recortado rente | tela de carregamento (alto à esquerda) |
| `capa_dia.webp` | Capa pintada de Bom Jesus dos Pobres ao entardecer: igreja, píer, saveiro, canoas e a mata; 2048×1152 (16:9) | tela de carregamento de dia |
| `capa_noite.webp` | Capa pintada da noite: o viajante com o lampião na boca da mata, a lua sobre a baía e a igreja lá embaixo; 2048×1152 | tela de carregamento de noite (entra espelhada) |
| `rosa_dos_ventos.png` | Rosa dos ventos em ouro com anel de azulejo cobalto; fundo transparente, 512×512 | indicador de carregamento (gira) |

## Como foram feitas

Geradas com a API de imagens da OpenAI, modelo `gpt-image-2`, qualidade `high`
(capas em 2048×1152; logotipo em 1536×1024 e rosa em 1024×1024, ambos com fundo
transparente). A chave vem do `.env` do repositório. Os PNGs originais e o script com
os prompts completos ficam fora do Git, em `.assets-raw/openai/telas_carregamento/`
(`gerar.py`). A igreja das capas foi descrita a partir do modelo do jogo: caiada, barrado
ocre, frontão de volutas com óculo, porta azul e torre com telhado de barro.

A capa da noite também foi a Direção B do mesmo estudo ("A Mata Não Dorme"); dela ficou
só a arte. Fontes da interface: Cinzel e Cormorant Garamond (`assets/fonts/`, licença OFL).

Conferir as condições de uso comercial vigentes da OpenAI antes de publicar.
