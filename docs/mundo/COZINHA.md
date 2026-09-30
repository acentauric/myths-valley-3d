# Cozinha e pesca

O fogo da lareira é o que fecha o ciclo da roça: planta, rega, colhe, **torra e
come**. Sem ele a mandioca é raiz e o peixe é peixe.

## Onde

Dentro da casa do jogador, de frente para a **lareira** — a mesma peça que já
vinha na casa desde o primeiro dia. Encoste e aperte **E**: o painel abre na aba
Cozinha. Fogo de casa alheia não conta; a aba só existe na sua.

Ela é separada da `Oficina` pelo mesmo motivo que o canteiro é separado dela:
serrar tábua e torrar farinha são trabalhos diferentes, acontecem em lugares
diferentes e evoluem por caminhos diferentes.

## O que sai da panela

Todos os pratos são do Recôncavo e saem do que o jogador planta, pesca ou corta
— nenhum ingrediente que não exista no mundo.

| Prato | Leva | Devolve | Custa de fôlego |
|-------|------|---------|-----------------|
| Torrar farinha | 2 mandioca, 1 lenha | 2 farinha (ingrediente) | 6 |
| Beiju na chapa | 1 farinha, 1 lenha | 2 beijus, +24 de fôlego cada | 3 |
| Garapa de cana | 2 cana | +22 de fôlego | 2 |
| Peixe na brasa | 1 peixe, 1 lenha | +42 | 4 |
| Caça na brasa | 1 carne de caça, 1 lenha | +52 | 7 |
| Pirão de peixe | 2 farinha, 1 peixe, 1 lenha | +62, e o dia 10% mais barato | 8 |
| Mungunzá | 3 milho, 1 cana, 1 lenha | +45, e o dia 30% mais barato | 10 |
| Chá de folha | 2 ervas da serra, 1 lenha | **+12 de vida**, corta a peçonha de cobra, e +2 de fôlego | 3 |

(A tabela estava com os números da primeira versão da cozinha — o peixe na
brasa aparecia com +28 e devolve 42. Os daqui são os do `catalogo.gd`.)

**TODA COMIDA DA PANELA RENDE MAIS DO QUE CUSTA**, e o `testar_comidas` cobra.
É a pergunta que o Graveyard Keeper ensinou a fazer — "quanto isto rende por
fôlego gasto?" — e ela pegou a caça na brasa, que a fase 6-A pôs para fechar
o dia de mata devolvendo 7 de fôlego e custando 7 para cozinhar. Hoje devolve
52. O chá é a exceção declarada: ele não é fôlego, é remédio.

**COMIDA É FÔLEGO; O REMÉDIO É O CHÁ.** A vida volta inteira dormindo, e um
pedaço com o chá de folha — mais nada a devolve. É a regra do Graveyard
Keeper, e com o conserto da reclamação mais ouvida dele: lá, quem queimava a
comida na masmorra achando que se curava não tinha como saber. Aqui a mochila
escreve "+12 de vida" no chá e só "de fôlego" no resto. Ver docs/projeto/PLANO.md, "A
luta, segunda rodada".

E o chá tem o segundo serviço, que é o que ele fazia de verdade no Recôncavo de
1887: **corta a peçonha** da jararaca (ver "A jararaca no brejo", no plano).
Com peçonha no corpo ele nunca avisa de desperdício, esteja a vida onde
estiver — é para isso que ele existe.

A farinha leva **duas** mandiocas porque é exatamente o que um pé dá: a primeira
farinha da partida sai da primeira colheita, sem plantar de novo.

Comer é de dois jeitos: na mochila (**I**, depois **F**) ou, se a comida já
estiver na mão, apertando **E** no mundo — ninguém precisa abrir menu para
almoçar no meio da roça. Nos dois casos, comer com o corpo quase cheio avisa
quanto de fôlego vai no lixo antes de deixar.

Quem come de fato é `Cozinha.comer`, e as duas telas chamam ele: é o que
garante que os dois caminhos devolvam o mesmo fôlego e apliquem o mesmo efeito.

## Efeitos: o que o corpo carrega

Comida, reza, bênção, poção, pacto e oferenda caem todos no mesmo lugar
(`Efeitos`), e o corpo carrega **três ao mesmo tempo**. O inventário mostra
quais são, de que natureza, o que fazem e quanto falta para vencer.

O teto existe porque sem ele o jogo vira acúmulo: rezar, comer, beber e fazer
oferenda sairia com seis bônus somados que nenhum deles foi desenhado para
conviver. Estourando o teto, sai o que vence primeiro.

### A graça da cruz é percentual

A bênção do cruzeiro vale uma **fração** do que o personagem já tem, calculada
na hora da reza — e não um número fixo. Número fixo envelhece mal: +40 de teto
de fôlego é enorme no primeiro dia, com teto de 100, e é migalha lá na frente,
com 400. A graça desta cruz tem que continuar valendo a pena no capítulo 7,
senão o jogador para de subir a ladeira da praça, e o ponto dela era justamente
fazer ele voltar ao convívio.

| Bênção | Vale |
|--------|------|
| Mão leve | trabalho um quarto mais barato |
| Fôlego de boi | um terço a mais de teto |
| Bom sono | metade a mais por noite |

A reza em si devolve 35% do teto de fôlego, pela mesma razão.

## O tutorial

Entra no fim da frente da colheita, que é onde ele faz sentido — o jogador
acabou de arrancar a mandioca e não tem o que fazer com ela:

1. Pedro dá duas achas de lenha e manda **torrar farinha** na lareira.
2. Dá um peixe que pescou de manhã e manda fazer **pirão**.
3. Manda **comer**, e aproveita para ensinar que o que passa do teto se perde.

Dois passos de fazer e um de comer. Ele fecha dizendo o que mais a lareira
aceita — garapa quando houver cana, peixe assado quando houver pesca.

## Pescar

É a outra metade do sustento: a roça dá mandioca e milho, o mar dá peixe — e
sem peixe o pirão do tutorial seria o único da partida.

A regra é de **uma tecla**, como o resto do jogo:

1. com a vara na mão, de frente para a água, **E** lança a linha;
2. a espera é aleatória, de 1,6 a 5 segundos: o peixe vem quando quer;
3. quando ferra, o aviso aparece no alto e há **três quartos de segundo** para
   apertar E de novo;
4. acertou a janela, o peixe vem; perdeu, ele leva a isca.

Não é sorte pura, é tempo de reação — e é isso que faz pescar ser uma
atividade em vez de um botão que gera item. A linha alcança **três tiles**, e
não um: no píer a tábua cobre o chão até a última fileira, e quem está no meio
dele tem areia na frente e mar logo depois.

Cada lançada custa 2 de fôlego. O tanque está em `Pesca.TANQUE`: a maioria das
fisgadas dá um peixe, algumas dão dois, e uma em cada cinco e pouco não dá nada
— pescaria que sempre rende não é pescaria.

## O que ainda não existe

1. **Lareira melhorável.** A cozinha não tem obra: fogo de chão hoje é igual ao
   fogo de chão do primeiro dia. O fogão de lenha é o próximo degrau natural.
2. ~~**Peixe de rio e peixe de mar.**~~ Feito em setembro de 2026: o mar dá
   **robalo** e a água doce dá **traíra**, e os dois valem mais que o peixe
   comum — que continua saindo de toda água, porque metade das receitas pede
   `peixe` e a missão do Pedro manda trazer dois. A divisão é a do terreno
   (`GeradorMundo.MAR_Y`), e a arte dos dois é o peixe comum recolorido, pela
   mesma razão que a cabra é o bode recolorido. Ver `Pesca.TANQUES`.
   **O que sobrou:** nenhuma receita usa os dois ainda. Uma moqueca de robalo
   e um peixe de escabeche dariam ao peixe de lugar um destino que não é só o
   balcão.
3. **Prato que estraga.** Comida feita dura para sempre na mochila.
4. **Cozinhar para os outros.** Os moradores comem fora de cena.
