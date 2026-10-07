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
