# Animações dos animais — revisão parcial da #149

Em 07/10/2026, o passeio deixa de ganhar galope porque um clipe tem passada
curta. O ritmo do clipe continua calculado pela passada medida; inclinação e
balanço de corrida usam a velocidade de passeio da espécie. A criatura
declara sua velocidade de ronda, mantendo a carga, o dano e o bote intactos.
O cão, gato, porco e demais bichos de casa animam o deslocamento horizontal
real após colisão ou deslizamento. A ave anima o último passo efetivo até seu
destino, que pode ser menor que a velocidade solicitada.

## Evidência reproduzível

`ritmo_do_bicho.gd` falhou no estado anterior: o passeio ganhava um salto de
0,034 u e a margem deixava deslocar 0,707 u/s enquanto se animava 1 u/s.
Depois, passa também com uma parede física, verificando a parada e cada passo
de `move_and_slide`. Restaurar a referência errada com `--falsificar-passo`
produz uma falha; `--falsificar-movimento` produz duas, no deslizamento e na
chegada da ave (1 u/s animado para 0,2 u/s percorrido).

`passeio_das_especies.gd` monta os 23 modelos pelo catálogo, sem construir o
vale ou gravar saves. Inventaria ossos e clipes, verifica ausência de salto
adicionado no passeio, fim do passo em até quatro segundos e referência de
ronda das três criaturas de produção. `--falsificar-passo` reproduz o galope
indevido nos modelos com passada curta. Não é um aceite de naturalidade de
todos os rigs: um clipe existente pode continuar artisticamente inadequado.
O falsificador da versão final produz dez falhas no passeio dos modelos
afetados; `bichos_de_casa.gd` também passa com as rotinas e velocidades atuais.
`--falsificar-ronda` restaura a referência da carga e reprova as três criaturas.

`animais_animacao.gd` passou antes e depois desta fatia: saúde dos 14 clipes
quadrúpedes, patas antes imóveis, respiração, repouso, bote, cabra de cena e
pausa, incluindo o relógio dos peixes. O gate anterior não cobrava o salto
extra no passeio ou a velocidade efetiva após deslizamento.

Os gates usam `APPDATA`, `XDG_DATA_HOME` e `XDG_CONFIG_HOME` em um perfil
isolado no D; passar `--user-data-dir` depois de `--` não isola o Godot.

## Inventário dos assets atuais

| Modelo | Ossos | Passada medida (u/s) |
| --- | ---: | ---: |
| cachorro_caramelo | 34 | 0,730 |
| cachorro_malhado | 38 | 0,501 |
| filhote_caramelo | 19 | 0,156 |
| gato_amarelo | 20 | 0,209 |
| gato_preto | 35 | 0,293 |
| gato_malhado | 21 | 0,224 |
| porco | 22 | 0,264 |
| leitao | 28 | 0,201 |
| jumento | 39 | 0,578 |
| cabra_solta | 21 | 0,602 |
| bode | 23 | não mensurável; referência 0,800 |
| onca_pintada | 33 | 1,453 |
| onca_preta | 42 | 0,821 |
| caititu | 33 | 0,350 |
| jararaca | 20 | referência 0,508; clipe serpentino |

Os 14 quadrúpedes trazem `preset_quadruped_walk_001`; a jararaca traz
`preset_serpentine_march_001`. Galo, galinha, pintinho, galinha-d'angola,
pato, peru, pavão e pavoa têm **zero ossos e nenhum clipe** de locomoção.
O balanço de corpo dessas oito aves não anima pernas independentes.

## Captura e limites restantes

`--visual` grava passeio, corrida, parada e giro de cada modelo em uma arena
com os GLBs reais; piso e iluminação são somente fixture. São 1.380 quadros,
convertidos em vídeo de 46 s com FFmpeg. Arquivos locais:

- `D:/MythsValleyPlaytestRuns/animais149-passeio-corrida.mp4`;
- `D:/MythsValleyPlaytestRuns/animais149-capturas/quadro_*.jpg`;
- logs `animais149-baseline.log`, `animais149-depois.log`,
  `especies149-depois.log`, `especies149-mutante.log`, `ritmo149-*.log`.

Foram conferidos quadros de Caramelo, gato malhado, bode, galinha e caititu.
Os registros de todas as espécies estão disponíveis, mas a aprovação visual
completa dentro do cenário e em todas as velocidades permanece pendente.
O passe GUI terminou as verificações sem erro de script; o encerramento
gráfico emitiu avisos de Texture RID/RenderingServer. O encerramento adiado
da fixture não eliminou esses avisos. Os gates headless encerram normalmente.

Para encerrar #149 ainda é necessário revisar o rig do bode (sem cadeia
inferior de patas mensurável) e prover locomoção articulada para as oito aves.
Na corrida o clipe satura em 6x: gato amarelo acompanha cerca de 30% do chão,
gato malhado 32%, filhote 36% e gato preto 42%. Não se aumentou esse teto
indiscriminadamente nem se reduziram velocidades de fuga para mascarar a
patinação; há necessidade de clipes/rigs adequados às velocidades atuais.
Peixes e raia conservam o nado por shader, coberto pelo gate anterior;
esta fatia não constitui revisão artística completa deles.

Não houve geração paga, troca de GLB, alteração de progresso, HUD ou terreno.
As capturas são locais; não foram anexadas ao GitHub. A #149 continua aberta.

## O cachorro em pé (08/10/2026, segunda fatia)

Relato do playtest de 07/10: o Caramelo acompanhava o Pedro nas patas de trás, com o
corpo na vertical. A causa **não era** a física nem a inclinação do terreno (nada
inclinava o corpo ao chão): o clipe do GLB balança o osso do ombro (`0_Right_Limb_0`,
até 28 graus) e o do pescoço (`Head_0`, mais 28) como se fossem perna, e a frente
inteira do cão pende deles. Recentrar o clipe só limitava cada osso a 20 graus; os dois
somados erguiam o peito quase 35 graus e a pata da frente subia no ar, como quem pede
esmola. A onça pintada tem o mesmo defeito (`0_Right_Limb_0`, `0_Right_Limb_1` e
`Head_0`). Os outros 12 quadrúpedes não têm osso que leve a cabeça balançando.

A conta foi feita fora do jogo, lendo o GLB (esqueleto, clipe e pesos da pele em Python),
com a mesma recentragem do animador: o peito, na vista de lado, empina e baixa a cada
passo; com ombro e pescoço no repouso o corpo fica firme, e a cabeça sai do lugar 4,5 %
da altura no cão e 6,3 % na onça (antes 9,4 % e 13,9 %).

O que mudou:

- Todo osso que leva a cabeça e balança mais que 10 graus no clipe cru fica no repouso
  (`PESCOCO_FIRME_ACIMA`); a coluna, que balança 3 a 7 graus, fica como está.
- As patas da frente do cão, que o clipe então deixa duras (o clipe nunca as moveu: só o
  ombro as carregava), entram na regra da perna parada. Como o rig tem uma única cadeia de
  trás para as duas patas, as duas da frente copiam essa cadeia meio ciclo uma da outra
  (contratempo; correlação medida de -0,91), e parado a defasagem se desfaz em 0,25 s.
  A mediana da "perna do meio" agora ignora as pernas que quase não andam.
- O corpo do bicho de casa inclina o focinho com a encosta (altura do chão 0,35 u à
  frente e atrás, até 0,45 rad): na rampa o cão sobe e desce de corpo paralelo ao chão.

Portões novos em `animais_animacao.gd` (4b, 5b, 5c): a cabeça do clipe pronto fica
dentro de 8 % da altura (`--falsificar-pescoco` recentra sem firmar o pescoço e o portão
reprova os dois modelos); as duas patas da frente passam de 10 % da altura por passo, em
contratempo; a inclinação da encosta tem sinal e teto. **Não foram rodados** (ordem do
autor: uma bateria só no fim da faixa); a verificação desta fatia foi a simulação
acima.

Pendentes: aprovação visual no jogo com o Caramelo seguindo o Pedro, na rampa e correndo; a
onça pintada foi consertada pela mesma regra e conferida só na simulação; a onça-caçadora
(`criatura_vale.gd`) ainda não inclina com a encosta; aves, bode e a corrida dos gatos
seguem como acima. Pesquisa de Mesh2Motion e do rig do Tripo:
[ANIMACAO_DE_ANIMAIS.md](../ferramentas/ANIMACAO_DE_ANIMAIS.md).

## Conferência do cachorro e dos portões (08/10/2026, terceira fatia)

Os portões novos 4b, 5b e 5c de `animais_animacao`, que a fatia anterior não rodou,
passam, junto de `ritmo_do_bicho`, `passeio_das_especies`, `bichos_de_casa` e
`bichos_de_casa_procedural`. `bicho_parado` reprova com "o clipe do filhote_caramelo
não parou em 4 s", defeito da pata parada que é de outra frente e segue como está.

O passe visual do Caramelo (`passeio_das_especies.gd --visual --somente-caramelo`, 20
quadros de passeio, 20 de corrida e 20 de parado, com o GLB real e a correção do
ombro e do pescoço) mostra o cão nas quatro patas, com o corpo paralelo ao chão, andando,
correndo e parado; a cabeça fica no lugar e as patas da frente alternam. Quadros locais em
`D:/MythsValleyPlaytestRuns/animais149-caramelo-08-10/`. Continuam pendentes a rampa e o
cão seguindo o Pedro no cenário, as aves sem rig, o bode e a corrida dos gatos.

## A criatura da mata na rampa (10/10/2026, quarta fatia)

A onça-caçadora e o caititu (`criatura_vale.gd`) inclinavam o corpo só no bote. Agora medem
o chão debaixo deles como o bicho de casa (`BichoDeCasa.inclinacao_no_ponto`: a altura do
chão 0,35 u à frente e atrás, a cada 0,12 s, até 0,45 rad) e o animador inclina o focinho
sem salto, andando ou parados. A espécie que não pisa o chão desliga isso com
`"acompanha_a_encosta": false` em `criaturas_3d.json` (a Matinta). O portão `animais_animacao`
ganha a pergunta 5d: sobre uma rampa simulada, a onça e o caititu erguem o focinho na subida e
o baixam na descida, e a Matinta não inclina. **Não foi rodado** (uma bateria por lote).

O que segue pendente, e não depende de código: as oito aves precisam de rig e clipe (o
Mesh2Motion é gratuito mas o ajuste dos ossos é manual por modelo; o Tripo cobra 10 créditos
por animação e só com pedido explícito), o bode precisa de rig com cadeia de patas, os quatro
gatos precisam de clipe de corrida, e a aprovação visual no jogo (cada quadrúpede andando,
correndo e parado, e o Caramelo seguindo o Pedro na rampa) pede alguém jogando.
