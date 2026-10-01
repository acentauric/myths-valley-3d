# Mar da baía (preamar)

## Batimetria

`data/mapas/bom_jesus_dos_pobres_batimetria.bin` (550×500 células de 10 m, float16) é gerado por
`tools/mapas/gerar_batimetria.py` a partir da **carta náutica DHN 1108**
— *Baía de Todos os Santos, Porto de São Roque e proximidades*, 1:15.000, WGS84,
profundidades em metros referidas ao nível de redução (MLLS). A carta raster (GeoTIFF
e KAP, baixados do Centro de Hidrografia da Marinha) fica em
`.assets-raw/cartas_nauticas/1108*/`, fora do git.

Como a carta vira profundidade:

- As faixas de cor da carta são classificadas: intermarés (seca na baixa-mar),
  0–5 m, 5–10 m e mais de 10 m. Texto, sondagens e linhas herdam a faixa vizinha.
- Dentro do quadro Mapa (16:9, o mundo jogável), a terra é o polígono do cenário do
  jogo, para o fundo encontrar a praia na linha da costa; terra da carta fora dele vira
  areia rasa. Fora do quadro vale a carta: Bom Jesus fica no **continente**, e a terra
  segue como relevo distante, com a altitude interpolada dos pontos do KML (até ~57 m).
- Dentro de cada faixa, a profundidade é interpolada pela distância até as faixas
  vizinhas. Na intermarés: face de praia de ~30 m e planície de lama a ~1 m acima do
  nível de redução (sondagens de secagem de 0,1 a 1,4 m). Além da curva de 10 m, o
  canal do Paraguaçu desce até ~28 m (sondagens de 20 a 33 m).
- Soma-se a **preamar de sizígia, 2,4 m**: o mar do jogo está sempre na maré cheia.
- Resultado: lâmina d'água de 0,2 a 23 m, média de ~9 m (a média da baía é ~9,8 m).

O arquivo guarda a elevação acima da preamar em float16, normalizada entre -35 e
+100 m; tamanho, limites em metros locais e faixa vão para o bloco `bathymetry` de
`data/mapas/bom_jesus_dos_pobres_cenario.json`. O Godot monta a textura do fundo e o
`HeightMapShape3D` da colisão direto desses bytes, sem laço em GDScript.

## Shaders

- `leito_mar.gdshader`: plano subdividido que desce conforme a textura (sem custo de
  montagem na CPU). Areia no raso, lama a partir de ~4 m, manchas de capim marinho
  entre ~1 e 6 m e cáusticas do sol na água rasa.
- `agua_mar.gdshader`: superfície transparente. A cor sai da espessura real de água
  entre a superfície e o fundo (buffer de profundidade), com absorção por canal
  ajustada à foto aérea de Bom Jesus dos Pobres: areia-esverdeada na beira, jade no
  raso, verde-petróleo no canal. Ondulação leve, reflexo do céu e espuma fina só onde
  a lâmina é mínima.

- `areia_praia.gdshader`: faixa de areia centrada na costa, em rampa para dentro d'água
  (sem degrau entre o fundo e a areia): grãos, marcas de vento e areia úmida na beira.
- `foz_rio.gdshader`: o rio prolongado através da praia, com a água transparente no fim
  para se misturar ao mar.
- Na água, as marolas são faixas de espuma cuja fase cresce com a profundidade
  vertical e anda com o tempo: as cristas correm para a areia.

Os dois primeiros são montados por `scripts/prototipo_3d/mar.gd`, chamado pelo
`geo_region_renderer.gd` quando o cenário tem o bloco `bathymetry`. O `mar.gd` também
cria o chão do mar (o jogador entra andando e para com a água no peito, ver
`player_controller.gd`) e as paredes invisíveis na borda do quadro.
