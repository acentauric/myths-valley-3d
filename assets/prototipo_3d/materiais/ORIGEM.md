# Materiais da casa de taipa

`telha_colonial_envelhecida_v1.png` e `cal_taipa_envelhecida_v1.png` foram
geradas para o protótipo com a ferramenta integrada de geração de imagem.

- **Telha:** telha-canal colonial de barro envelhecido do Recôncavo Baiano,
  tratada como textura repetível para a cobertura.
- **Parede:** cal sobre taipa, com desgaste e barro discreto, tratada como
  textura repetível para as paredes externas.

Os dois materiais foram criados a partir das diretrizes de
`docs/AMBIENTACAO.md` e da casa de referência fornecida para a fachada.

## Chão de ruas e praça (procedural)

`terra_batida_v1.png` e `chao_praca_v1.png` (1024×1024, sem emenda) são geradas de
forma determinística por `prototipo_3d/tools/materiais/gerar_texturas_chao.py`
(semente 1887), sem fonte externa. A terra batida traz sulcos de carro de boi ao
longo do eixo V, aplicados nas faixas de rua com UV que acompanha o percurso; o
chão de praça é terra pisoteada com seixos e grama rala, projetado pelo mundo.
Regerar com `python prototipo_3d/tools/materiais/gerar_texturas_chao.py`.

## Chão de mata

`grama_terra_mata_v1.png` (1254×1254) foi gerada pela ferramenta integrada de
imagem, usando `terra_batida_v1.png` como referência de estilo. Combina manchas
repetíveis de grama verde, terra ocre, folhas secas e pequenas pedras para as
áreas de terreno e mata fora das vias; não usa fonte externa.

## Estrada de terra ocre

`estrada_terra_ocre_v1.png` foi gerada pela ferramenta integrada de imagem, usando
como referencia as texturas de mata e terra batida do projeto. A base ocre dourada
combina com as manchas claras de solo da mata; marcas organicas, pedras pequenas e
vegetacao esparsa preservam a leitura de estrada. A malha curva os vertices da via
e usa um contorno estreito em tom de terra para evitar cantos duros.
