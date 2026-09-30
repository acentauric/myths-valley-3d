# Imagem de referência para modelo 3D

Uma imagem bonita não basta para gerar um asset utilizável. O pedido deve dizer **qual objeto tridimensional será construído**, como ele será visto no jogo e o que deve ficar fora da malha. No protótipo, a primeira referência do pau-brasil tinha fundo cinza e sombra de estúdio; o Tripo incorporou partes desse fundo como um disco sob a árvore e placas atrás da copa. A referência com transparência real produziu uma malha mais limpa.

## Prepare a referência

1. Descreva o **asset isolado**: espécie ou objeto, forma, materiais e traços que o distinguem. Consulte referências confiáveis quando a fidelidade histórica ou botânica importar. Para o pau-brasil, usamos o nome *Paubrasilia echinata* e folhas bipinadas, em vez de pedir apenas “árvore tropical”.
2. Enquadre o objeto inteiro, inclusive base, raízes ou pés, com margem em todos os lados. Prefira uma vista de três quartos que revele volume e conexões entre as partes. Evite cortes, oclusões, objetos sobrepostos e perspectiva extrema.
3. Peça **fundo realmente transparente (canal alfa)**, inclusive entre galhos, folhas e outras aberturas. Um fundo cinza, uma sombra projetada ou um padrão de xadrez desenhado na imagem podem virar geometria. Confira a transparência no arquivo, não apenas na prévia.
4. Use luz suave que mostre detalhes sem gravar sombras fortes ou reflexos na cor do objeto. Folhagem, cabelo e peças finas devem ter bordas nítidas, sem halos.
5. Produza uma referência por objeto. Se o gerador aceitar múltiplas vistas, use imagens coerentes do mesmo objeto; vistas contraditórias confundem a reconstrução.

## Escreva também a instrução do modelo

Guarde um briefing de reconstrução junto da imagem. Se a modalidade do Tripo oferecer texto complementar, forneça esse briefing no campo correspondente. Se aceitar apenas imagem, use o briefing para orientar a geração da referência e para avaliar o resultado; não presuma que o serviço recebeu instruções que a interface não permite enviar.

O briefing deve declarar:

- **Entrega:** um único objeto 3D, formato de exportação e uso no jogo.
- **Geometria:** partes que precisam existir e se conectar; volume desejado também nas laterais e no verso; ausência de cenário, chão, suporte, sombra ou placas de fundo.
- **Fidelidade:** traços visuais essenciais e o que evitar. Não peça detalhes invisíveis na referência como se fossem garantidos.
- **Orçamento:** escala de destino, limite aproximado de triângulos e resolução de textura. Ajuste ao número de instâncias e à plataforma do jogo.

Exemplo para o pau-brasil:

```text
Use esta imagem como referência para um único modelo 3D de pau-brasil
(Paubrasilia echinata) destinado ao cenário de um jogo. Reconstrua o tronco,
a bifurcação, os galhos e a copa com folhas pequenas e compostas. Preserve
a casca escura com áreas avermelhadas discretas. Dê volume à árvore em 360°,
com base apoiada no solo e eixo vertical Y. Não crie chão, disco, sombra,
placas de fundo, outras plantas, texto nem suporte. Exporte em GLB com
textura 2K e malha adequada para uma única árvore de cerca de 5,6 m no jogo.
```

Um prompt de imagem correspondente seria:

```text
Crie uma referência para gerar um asset 3D de jogo: um único pau-brasil
adulto (Paubrasilia echinata), árvore inteira e centralizada, copa irregular
com folhas verdes pequenas e bipinadas, tronco ramificado de casca escura
com poucas áreas avermelhadas. Vista de três quartos, luz suave, contorno
nítido, margem em todos os lados. Fundo realmente transparente, inclusive
entre os galhos. Sem terreno, sombra, outros objetos, texto ou marca-d'água.
```

## Gere, examine e integre

1. Verifique a modalidade, as opções e o custo mostrado antes de gerar. Uma nova tentativa pode consumir créditos; compare a referência e corrija a causa dos artefatos antes de repetir.
2. Examine a malha girando-a: frente, lados, verso, topo e base. Procure planos sem espessura, partes flutuantes, buracos, textura borrada e pedaços do fundo. A ausência desses problemas na vista frontal não prova que o modelo inteiro está bom.
3. Exporte para `.assets-raw/tripo/` e confira contagem de triângulos, materiais, dimensões, texturas incorporadas e tamanho do arquivo. Para o protótipo, a referência transparente gerou uma árvore com cerca de 74 mil triângulos e textura 2K; esses números descrevem o caso, não um limite universal.
4. Promova apenas o arquivo escolhido para `prototipo_3d/assets/`. No Godot, ajuste escala e base da malha ao chão; use colisão simples para troncos e outros objetos estáticos. Teste importação, aparência e posicionamento na cena.
5. Registre URL ou ID da geração, imagem usada, configuração, hash do arquivo e condições de uso. Os prompts e dados do pau-brasil estão em [`prototipo_3d/assets/prototipo_3d/arvores/ORIGEM.md`](../../prototipo_3d/assets/prototipo_3d/arvores/ORIGEM.md). O fluxo de acesso ao Studio está em [`TRIPO_PLAYWRIGHT.md`](../ferramentas/TRIPO_PLAYWRIGHT.md).

Para identificação botânica do exemplo: [Plants of the World Online, Kew](https://powo.science.kew.org/taxon/urn:lsid:ipni.org:names:77158012-1). Para direitos de uso do resultado, consulte as [regras do Tripo para modelos gerados](https://www.tripo3d.ai/help/privacy-policy/how-to-use-tripo-models-commercially) conforme o plano utilizado.
