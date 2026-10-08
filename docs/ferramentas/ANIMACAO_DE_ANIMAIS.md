# Animação de animais: Mesh2Motion e rig automático do Tripo

Pesquisa de 08/10/2026 para a #149 (aves sem rig, bode com rig sem patas de
baixo, clipes de gato que saturam na corrida). **Nenhuma geração paga foi feita**:
tudo abaixo vem de páginas públicas e dos GLBs que já estão no projeto.

## O que o projeto já tem

Os quadrúpedes do Tripo trazem um único clipe, `preset:quadruped:walk.001`
(a jararaca, `preset:serpentine:march`). Não há corrida, parado nem virada: o
código acelera o passeio (`animador_bicho.gd`). As oito aves (galo, galinha,
pintinho, d'angola, pato, peru, pavão, pavoa) vieram **sem esqueleto**, só malha.
O auto-rig do Tripo erra o nome e a hierarquia de ossos em vários modelos
(ver o cabeçalho do animador), e foi isso que fez o cão caramelo andar em pé: o
clipe balançava o ombro e o pescoço como se fossem perna.

## Mesh2Motion (https://app.mesh2motion.org/)

- **O que é.** Aplicativo web gratuito e de código aberto (autor: Scott Petrovic)
  que põe um esqueleto-padrão num modelo 3D e entrega o modelo com os clipes
  prontos, numa ideia parecida com a do Mixamo, mas com formas além da humana.
- **Esqueletos.** Humanoide, quadrúpede (raposa, gato, cavalo), ave, dragão,
  aranha (9 clipes: parado, andar, ataque, morte), cobra (7 clipes) e kaiju.
  A lista cresce a cada versão; conferir na própria página antes de planejar.
- **Entrada e saída.** Importa GLB, GLTF, DAE e FBX; exporta **GLB/GLTF** com os
  clipes embutidos, que o Godot importa direto, como os GLBs do Tripo de hoje.
- **Licença.** Código MIT e arte (modelos, esqueletos, animações) **CC0**, de uso
  comercial livre e sem atribuição obrigatória. Cumpre a regra do projeto
  (`assets/CREDITOS.md` pede licença verificada e uso comercial permitido); ainda
  assim cada lote exportado entra lá com a data e a versão do aplicativo.
- **Fluxo.** Escolhe o tipo de esqueleto, ajusta os ossos ao modelo (posição e
  escala), vê o resultado deformando, marca os clipes e exporta. Não gasta
  crédito nenhum.
- **Limites.** O ajuste dos ossos é manual, modelo a modelo, e a qualidade da
  deformação depende dos pesos que o aplicativo calcula sozinho; o rig de ave
  serve ao pavão e ao peru, mas o pintinho redondo pode pedir ajuste. Não li o
  repositório dos clipes (`mesh2motion-assets`); precisa conferir antes se há
  corrida e virada para quadrúpede.

**Onde ele resolve.** (1) As oito aves, hoje sem osso: ganham andar articulado
(o que a #149 ainda cobra). (2) O bode, cujo rig não tem a cadeia de patas de
baixo: reexportar a malha pelo esqueleto de quadrúpede. (3) Os gatos e o filhote,
cujo clipe curto satura na corrida: se o esqueleto de quadrúpede trouxer um clipe
de corrida, a velocidade de fuga deixa de patinar sem tocar no código.

**Onde ele não resolve.** O clipe só vale se o esqueleto casar com a malha.
Pelo mesmo motivo que o Mixamo (#190) só serve a humanoides, qualquer clipe
retargetado precisa passar pelo mesmo teste de saúde do portão
`animais_animacao` (pata, cabeça e pescoço) antes de entrar.

## Rig automático do Tripo (Studio e API)

- **Tipos de criatura.** O rigger reconhece biped, quadruped, hexapod, octopod,
  avian, serpentine e aquatic; no Studio escolhe-se o tipo do modelo.
- **Animações predefinidas.** idle, walk, run, jump, slash, shoot, climb, hurt, fall,
  dive e turn (a documentação lista 16 presets universais, e 90 ou mais só de
  bípede). Saída em GLB ou FBX.
- **Custo.** 10 créditos por animação (lote: 10 × quantidade), fora o crédito do
  próprio rig. É geração paga: **não se rodou nenhuma**.
- **O que muda para nós.** Todos os GLBs do lote de 05/10 trazem só o clipe de andar.
  A lista de animações avulsas da API inclui `run`, `idle` e `turn`, que atacariam a
  corrida dos gatos e a virada, mas **a documentação não diz quais valem para
  quadrúpede**: precisa conferir no Studio antes de gastar, e cada rodada é paga por
  modelo. Existe o tipo `avian`, então as oito aves poderiam ser rigadas pelo
  Tripo, com a ressalva de que o auto-rig dos quadrúpedes errou nomes em quase todo
  modelo e o das aves não está testado.
- **Risco.** Rigar de novo gasta crédito e entrega ossos de nome imprevisível; o
  animador do jogo já acha pé e perna pelo esqueleto, mas o ombro e o pescoço
  tratados como perna (o caso do caramelo) só se pegam medindo o clipe.

## Recomendação

1. **Primeiro, o grátis.** Testar o Mesh2Motion com **uma ave** (galinha) e **o
   bode**, conferindo a importação no Godot e o portão de saúde. Se casar, as
   oito aves e o bode saem sem crédito.
2. **Depois, o pago, e só com pedido explícito.** Se o Mesh2Motion não tiver
   corrida para quadrúpede ou deformar mal, pedir ao Tripo os presets `run` e
   `turn` só para gato amarelo, gato preto, gato malhado e filhote (os quatro que
   saturam), e `idle` onde fizer falta.
3. Qualquer clipe novo passa por `animais_animacao` (4b: pescoço firme) e pela
   captura de cada espécie andando, correndo e parada antes de entrar no catálogo.

Fontes: [Mesh2Motion no GameFromScratch](https://gamefromscratch.com/mesh2motion-free-open-source-animation-app/),
[repositório](https://github.com/Mesh2Motion/mesh2motion-app) (código MIT, arte CC0),
[80.lv sobre as rigs de aranha e cobra](https://80.lv/articles/mesh2motion-animation-app-introduces-spider-and-snake-rigs/),
[API de animação do Tripo](https://developers.tripo3d.com/en/models/animation),
[auto-rig de quadrúpedes do Tripo](https://www.tripo3d.ai/blog/ai-tools-for-rigging-and-animating-quadruped-or-non).
