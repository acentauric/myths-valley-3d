# Materiais da casa de taipa

`telha_colonial_envelhecida_v1.png` e `cal_taipa_envelhecida_v1.png` foram
geradas para o protótipo com a ferramenta integrada de geração de imagem.

- **Telha:** telha-canal colonial de barro envelhecido do Recôncavo Baiano,
  tratada como textura repetível para a cobertura.
- **Parede:** cal sobre taipa, com desgaste e barro discreto, tratada como
  textura repetível para as paredes externas.

Os dois materiais foram criados a partir das diretrizes de
`docs/mundo/AMBIENTACAO.md` e da casa de referência fornecida para a fachada.

## Chão de ruas e praça (procedural)

`terra_batida_v1.png` e `chao_praca_v1.png` (1024×1024, sem emenda) são geradas de
forma determinística por `tools/materiais/gerar_texturas_chao.py`
(semente 1887), sem fonte externa. A terra batida traz sulcos de carro de boi ao
longo do eixo V, aplicados nas faixas de rua com UV que acompanha o percurso; o
chão de praça é terra pisoteada com seixos e grama rala, projetado pelo mundo.
Regerar com `python tools/materiais/gerar_texturas_chao.py`.

## Chão de mata

`grama_terra_mata_v1.png` (1254×1254) foi gerada pela ferramenta integrada de
imagem, usando `terra_batida_v1.png` como referência de estilo. Combina manchas
repetíveis de grama verde, terra ocre, folhas secas e pequenas pedras para as
áreas de terreno e mata fora das vias; não usa fonte externa.

## Estrada de terra ocre

`estrada_terra_ocre_v1.png` foi gerada pela ferramenta integrada de imagem, usando
como referencia as texturas de mata e terra batida do projeto. A base ocre dourada
combina com as manchas claras de solo da mata; marcas organicas, pedras pequenas e
vegetacao esparsa preservam a leitura de estrada. As curvas da via sao suavizadas.
A faixa lateral mistura por shader as texturas atuais da mata e da estrada. A grama
usa a mesma projecao do terreno, enquanto o UV da terra acompanha o da estrada;
assim, as bordas coincidem com os materiais vizinhos. Uma variacao organica no
limite da mistura evita uma linha reta entre os dois terrenos. O piso de mata usa
ladrilhos maiores para ampliar visualmente as folhas e os tufos.

## Chão em camadas (OpenAI gpt-image-2, 05/10/2026)

Nove texturas, uma por camada do shader do terreno (`terreno.gdshader`, ver
`docs/mundo/SOLO_E_FRANJAS.md`): `grama_baixa`, `capim_seco`, `folhico_mata`,
`terra_batida_varrida`, `barro_vermelho`, `pedrisco`, `areia_restinga`, `lama_mangue`
e `terra_arada`, todas `<id>_v1.png`, 1024x1024, contínuas, com a **altura no canal
alfa** (o shader mistura as camadas por ela).

- **Geração:** OpenAI `gpt-image-2`, 1024x1024, qualidade `high`, por
  `tools/openai/gerar-texturas-chao.ps1` e `tools/openai/texturas_chao.json`, que guardam
  o preâmbulo e o prompt de cada uma (sem negação, AMBIENTACAO §8, regra 5). Dez
  imagens no total: as nove mais o semi-realista da grama baixa, do A/B abaixo.
  Custo estimado, teto: dez imagens a US$ 0,167 (o painel do OpenAI tem o real).
- **A/B da grama baixa:** semi-realista contra pintado à mão. O semi-realista virava ruído
  fino e oliva a poucos metros; o pintado, o mesmo acabamento dos modelos do Tripo, mantém
  trevo, tufo e terra legíveis, e foi o escolhido para as nove.
- **Pós-processo:** `tools/materiais/preparar_textura_chao.py` recorta e reduz, achata a
  baixa frequência, torna contínua (rola meia imagem e esconde a costura com máscara
  ruidosa), grava a altura no alfa e gera uma prévia 3x3 para revisão. Brutos em
  `.assets-raw/openai/texturas_chao/` (fora do Git).
- **Derivada:** `terreiro_varrido_v1.png` (a terra batida varrida com máscara oval de borda
  irregular) é o decalque do terreiro das casas (`terreiro_casa.tscn`); sai do mesmo script.
- **Mantidas:** `grama_terra_mata_v1.png`, `chao_praca_v1.png`, `terra_batida_v1.png`,
  `estrada_terra_ocre_v1.png` e `areia_praia_v1.png` seguem no projeto (a cena da orla e a
  estrada apontam para elas); só o chão do terreno passou às novas.
