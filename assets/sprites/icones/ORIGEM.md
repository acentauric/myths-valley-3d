# Os ícones do HUD e do J

Os réis e o XP não são itens do catálogo e não tinham desenho; o diário do J
mostra a recompensa de cada passo em ícones (#107, decisão do autor em
06/10/2026).

Gerados por texto no OpenAI em 06/10/2026 (`gpt-image-1`, 1024×1024, qualidade
média, fundo transparente pedido — o modelo pintou fundo mesmo assim, e o
`tools/openai/promover_icones.gd` recorta cada um pela forma: losango no XP,
quadrado arredondado nos réis — e reduz a 96×96). Plano e prompts em
`tools/openai/icones.json`; os brutos ficam em `.assets-raw/openai/icones/`
(fora do Git). Uso comercial: conta paga no momento da geração (ver
`assets/CREDITOS.md`).

| Arquivo | O que é (prompt) |
| --- | --- |
| `reis.png` | an old Brazilian imperial coin from 1887, the réis, seen face on: worn gold relief with a small imperial crown and laurel wreath |
| `xp.png` | an experience-points emblem: a cobalt-blue Portuguese tile diamond (azulejo) with a thin gold fillet border and a small eight-pointed gold star |
