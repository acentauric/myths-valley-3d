# Bioma da orla: coqueiral, manguezal e pedras

Decisão do autor em 05/10/2026. Este documento guarda as regras que posicionam
a vegetação e as pedras da orla de Bom Jesus dos Pobres. Elas valem para quem
edita no Godot, para as ferramentas e para a IA que gera ou adensa o bioma.
A direção geral da flora está em [AMBIENTACAO.md §4](AMBIENTACAO.md#4-flora);
a edição no Godot segue [COMPOSICAO_AUTORAL_3D.md](COMPOSICAO_AUTORAL_3D.md).

## Onde fica cada coisa

Tudo isto é **editável** na `scenes/prototipo_3d/composicao_vale.tscn`, dentro de
`Avulsos`: cada árvore e cada pedra é um nó que se move, gira (Y), escala
(`Tamanho`), duplica (Ctrl+D) ou apaga. O jogo lê a posição dali.

| Grupo | O quê | Como o jogo usa |
|---|---|---|
| `Coqueiros da orla/Norte` e `/Sul` | o coqueiral da praia | se o grupo existe, o jogo planta só estes, no lugar dos sorteados |
| `Manguezal` | os mangues dos rios e das fozes | idem |
| `Pedras` | a pedra grande da praia, as duas menores e as lajes da maré | posição autoral prevalece; apagar tira do jogo |
| `Marcos` | o amontoado do marco "Pedras" do mapa | idem |

Na cena entram já `Coqueiros da orla` e `Manguezal`. Os outros grupos de `Avulsos`
(Árvores, Fazenda, Praça, Píer, Pontes, Marcos, Pedras) o editor cria ao abrir a
cena, da semente `data/composicao/avulsos_padrao.json`; enquanto um grupo não existe
na cena, o jogo segue o código para ele (nada some). Só some o que falta num grupo
que existe.

**Norte e Sul** se dividem na **foz do rio central** (z ≈ −44): ao norte (z menor)
ficam o rio norte e a fazenda, ao sul a vila, o píer e a ponta das pedras. A
divisão é só de organização; os dois são o mesmo coqueiral.

O sorteio do jogo (mata, ingazeiros, restinga) continua o mesmo de antes: a
vegetação autoral troca só o plantio do seu grupo, sem mexer na sequência
aleatória que posiciona o resto.

## Regras do coqueiral

O coqueiral contínuo na beira da praia é uma marca da costa baiana. Na vila de
1887 ele chega à praia da própria vila.

- **Faixa:** do lado da terra, de 2 a 6 u da linha da costa (primeira fileira, na
  areia) e, em metade dos pontos, uma segunda fileira de 7 a 12 u para dentro.
  A faixa de areia da orla tem 8 u.
- **Ritmo:** um ponto a cada 4,5 a 7 u ao longo da costa, com folga lateral de
  ±1,5 u; nunca dois coqueiros a menos de 4 u.
- **Bosques:** 40% dos coqueiros ganham 1 ou 2 companheiros a 3 a 5 u; quase
  metade desses é muda (escala 0,55 a 0,72), coco que caiu e brotou.
- **Inclinação:** pende para o mar, com até ±25° de variação, em escalas de 0,78
  a 1,18, para que nenhum pareça cópia do vizinho.
- **Onde não nasce:** água, ruas e rios (folga de 3 u), pontos de interesse
  (6 u), a menos de 9 u de uma casa, clareiras da mata, e o que o level design
  de 05 a 09/10 já ocupa: as reservas do paisagismo (casas e lotes dos moradores,
  árvores nomeadas, âncoras, portas e veredas), as pontes (com 4 u de folga) e as
  zonas do paisagismo (dendezal, mata ciliar, cajuais, pomares...).
- **Junto do mangue, rareia:** a até 12 u de um mangue, só 20% dos pontos viram
  coqueiro. Mangue e coqueiro não dividem a mesma beira.

## Regras do manguezal

- **Leito inteiro:** os dois rios, nas duas margens, do começo ao fim, e não só
  perto da foz.
- **Colado à água:** de 0,8 a 2,5 u além da margem do rio, um ponto a cada 3,5 a
  6 u, nunca dois mangues a menos de 3 u.
- **Estuário:** na foz, o mangue se espalha pela beira da costa dos dois lados.
  São os mangues que o jogo já sorteava, mantidos.
- **Onde não nasce:** ruas (2 u), casas (9 u), o vão do sobrevoo da abertura,
  que precisa de céu aberto, e o mesmo que o coqueiral respeita do level design
  (reservas do paisagismo, pontes e zonas).
- **Variação:** giro livre e escala de 0,8 a 1,2.

## Pedras

As pedras da praia ficam na areia, junto da água, perto do marco "Pedras" do
mapa: uma grande, com colisão, e duas menores dos lados. As lajes da maré ficam
no raso, com 0,06 a 0,5 de lâmina d'água. No editor elas não "assentam" no chão
(`No chão` desligado), para manter a altura dentro da água.

## Ferramentas

| Ferramenta | Para quê |
|---|---|
| `tools/mapas/bioma_orla.gd` | monta o vale com a composição atual e grava `bioma_orla_plano.json`, com o coqueiral e o manguezal que faltam segundo as regras acima, informa os trechos da orla sem cobertura e quantos pontos cada reserva do level design recusou (`BIOMA_RECUSAS`) |
| `tools/mapas/aplicar_bioma_orla.py` | aplica o plano na cena só acrescentando blocos (não regrava a cena pelo Godot sem tela, que tiraria os UIDs); cria os grupos `Coqueiros da orla` e `Manguezal` a partir da semente quando a cena ainda não os tem |
| `tools/mapas/semear_avulsos.gd` | regera a semente `data/composicao/avulsos_padrao.json`, de onde o editor cria os subgrupos de `Avulsos` que faltarem, e a referência visual da paisagem |

```
Godot --headless --path . --script res://tools/mapas/semear_avulsos.gd
Godot --headless --path . --script res://tools/mapas/bioma_orla.gd
python tools/mapas/aplicar_bioma_orla.py
```

Depois de aplicar, recarregue a cena no editor **sem salvar antes**.

Estado em 10/10/2026 (reaplicado sobre a main de 09/10): 77 coqueiros (31 + 24 novos
ao norte e ao sul, mais os 22 sorteados, reagrupados) e 203 mangues. O único trecho
da orla sem cobertura é a ponta sul, perto de (−151, 189), com 55 u. A versão de
05/10 tinha 114 coqueiros: a diferença vem das reservas do level design e do
sorteio refeito, não de regra nova.
