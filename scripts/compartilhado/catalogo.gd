extends RefCounted
class_name Catalogo
## Catálogo de itens. Fica em código (e não em .tres) porque assim o diff no Git
## mostra a mudança inteira numa linha; quando a lista crescer, vira Resource.
##
## Os ícones são arquivos de 32x32 gerados no PixelLab, um por item, em
## assets/sprites/itens/. Antes eram recortes de 16px da folha da Kenney, e era
## essa a razão de a ferramenta na mão sumir ao lado do personagem: o boneco tem
## 34px de altura e o ícone tinha metade disso.

const PASTA := "res://assets/sprites/itens/"

const ITENS := {
	"enxada": {
		"nome": "Enxada",
		"tipo": "ferramenta",
		"icone": "enxada",
		"empilhavel": false,
	},
	"balde": {
		"nome": "Balde d'água",
		"tipo": "ferramenta",
		"icone": "balde",
		"empilhavel": false,
	},
	## `dano` É O QUE FAZ DE UMA FERRAMENTA UMA ARMA (fase 6-A do PLANO.md).
	## Quem tem, bate na criatura da mata; quem não tem, não. A enxada e o
	## balde não têm de propósito: enxada não é arma. O machado bate porque é
	## machado; a picareta e a foice batem pior, porque são de pedra e de capim.
	"machado": {
		"nome": "Machado",
		"tipo": "ferramenta",
		"icone": "machado",
		"empilhavel": false,
		"dano": 3.0,
	},
	"picareta": {
		"nome": "Picareta",
		"tipo": "ferramenta",
		"icone": "picareta",
		"empilhavel": false,
		"dano": 2.0,
	},
	## AS FERRAMENTAS DE AÇO são da mesma FAMÍLIA que as de ferro — servem a
	## todo alvo que pede machado ou picareta — e têm GRAU 2: só elas abrem o
	## alvo que pede aço (`"aco": true` na madeira, `"grau": 2` na pedra).
	## Ferramenta melhor não barateia o golpe, ela DESTRAVA alvo mais duro (ver
	## Energia), e por isso a de aço bate igual à de ferro, na lida e na luta: o
	## que muda é aonde ela chega. O ícone e o modelo na mão são os da de ferro
	## até haver arte própria, que é geração paga e espera o pedido.
	"machado_de_aco": {
		"nome": "Machado de aço",
		"tipo": "ferramenta",
		"icone": "machado",
		"empilhavel": false,
		"dano": 3.0,
		"familia": "machado",
		"grau": 2,
	},
	"picareta_de_aco": {
		"nome": "Picareta de aço",
		"tipo": "ferramenta",
		"icone": "picareta",
		"empilhavel": false,
		"dano": 2.0,
		"familia": "picareta",
		"grau": 2,
	},
	"foice": {
		"nome": "Foice",
		"tipo": "ferramenta",
		"icone": "foice",
		"empilhavel": false,
		"dano": 2.5,
	},
	"vara_de_pescar": {
		"nome": "Vara de pescar",
		"tipo": "ferramenta",
		"icone": "vara_de_pescar",
		"empilhavel": false,
	},
	# AS TRÊS SEMENTES DA ROÇA, e cada uma é uma coisa diferente no mundo real —
	# é por isso que nenhuma se chama "semente de X" a não ser a do milho.
	#
	#   maniva   pedaço do CAULE da mandioca, cortado num palmo e enfiado
	#            deitado na terra. Mandioca não se planta de semente.
	#   milho    grão mesmo, que é o único dos três que é semente de verdade.
	#   rebolo   pedaço do COLMO da cana, com dois ou três nós, enterrado
	#            deitado. De cada nó sai um pé.
	"semente_mandioca": {
		"nome": "Maniva de mandioca",
		"tipo": "semente",
		"cultura": "mandioca",
		"icone": "semente_mandioca",
		"empilhavel": true,
	},
	"semente_milho": {
		"nome": "Grão de milho",
		"tipo": "semente",
		"cultura": "milho",
		"icone": "semente_milho",
		"empilhavel": true,
	},
	"rebolo_cana": {
		"nome": "Rebolo de cana",
		"tipo": "semente",
		"cultura": "cana",
		"icone": "rebolo_cana",
		"empilhavel": true,
	},
	"mandioca": {
		"nome": "Mandioca",
		"tipo": "recurso",
		"icone": "mandioca",
		"empilhavel": true,
	},
	# --- fruteiras ------------------------------------------------------------
	# A muda é `semente` como a maniva: é o mesmo verbo de plantar, e não vale
	# inventar um segundo para a mesma ação. O que muda é o que nasce dela —
	# pé que fica e dá fruta todo ciclo (ver Plantacao.CULTURAS).
	#
	# Cada muda tem o SEU ícone, e a diferença está na folha: pá larga da
	# bananeira, lança da mangueira, folha redonda do cajueiro, cada uma no
	# verde da árvore que ela vira (ver desenhar-fruteiras.ps1).
	#
	# As três eram o ícone da maniva — um feixe de pau marrom — porque nenhuma
	# tinha desenho próprio. Funcionava enquanto havia uma; com três na mochila
	# ao mesmo tempo, o jogador escolhia no escuro e só descobria o que tinha
	# plantado dias depois, quando a árvore crescia.
	"muda_bananeira": {
		"nome": "Muda de bananeira", "tipo": "semente", "cultura": "bananeira",
		"icone": "muda_bananeira", "empilhavel": true,
	},
	"muda_mangueira": {
		"nome": "Muda de mangueira", "tipo": "semente", "cultura": "mangueira",
		"icone": "muda_mangueira", "empilhavel": true,
	},
	"muda_cajueiro": {
		"nome": "Muda de cajueiro", "tipo": "semente", "cultura": "cajueiro",
		"icone": "muda_cajueiro", "empilhavel": true,
	},
	# FRUTA É COMIDA, e come-se do pé.
	#
	# As três eram `recurso`: davam-se ao vendeiro e mais nada. Mas o pomar é o
	# investimento mais caro e mais lento do começo do jogo — muda comprada,
	# anos de rega, carência entre uma colheita e outra — e o que ele entregava
	# era dinheiro, que a mandioca também entrega, mais rápido. Fruta que se
	# come na hora é o que faz o pé de manga valer o que custou.
	#
	# Menos fôlego que prato cozinhado, e é a regra: a fruta não passa pelo
	# fogo, não custa lenha e não custa tempo. O beiju, que é o prato mais
	# barato da cozinha, dá 24; a manga dá 24 também, mas só depois de nove
	# dias de espera e um pé de quinze dias. O caminho curto paga menos por
	# unidade de trabalho — e a fruta só ganha da panela na PRESSA.
	"banana": {
		"nome": "Banana", "tipo": "comida", "resumo": "Madura do cacho. Descasca e come, sem fogo e sem faca.",
		"folego": 16.0, "icone": "banana", "empilhavel": true,
	},
	"manga": {
		"nome": "Manga", "tipo": "comida", "resumo": "Chupada na beira do rio, que é onde se lava a mão depois.",
		"folego": 24.0, "icone": "manga", "empilhavel": true,
	},
	"caju": {
		"nome": "Caju", "tipo": "comida", "resumo": "Azeda a boca e mata a sede. A castanha guarda-se para torrar.",
		"folego": 19.0, "icone": "caju", "empilhavel": true,
	},
	# --- do curral ------------------------------------------------------------
	## O OVO das galinhas do quintal (`curral_vale.gd`, #160): botam todo dia, e o E
	## no galinheiro recolhe.
	"ovo": {
		"nome": "Ovo", "tipo": "recurso", "icone": "ovo", "empilhavel": true,
		"resumo": "Das galinhas do seu quintal. Botam todo dia; recolha de manhã, no galinheiro.",
	},
	"leite": {
		"nome": "Leite de cabra", "tipo": "recurso", "icone": "leite", "empilhavel": true,
	},
	"lenha": {
		"nome": "Lenha",
		"tipo": "recurso",
		"icone": "lenha",
		"empilhavel": true,
	},
	## A FIBRA DA PIAÇAVA, tirada da bainha da folha da palmeira da restinga sem
	## derrubá-la (ver `ArvoresInfo`). É o que o mestre Quirino, do saveiro, mais
	## leva para Salvador: vassoura, corda de navio, cobertura de casa.
	"piacava": {
		"nome": "Piaçava",
		"tipo": "recurso",
		"icone": "piacava",
		"empilhavel": true,
	},
	"madeira_de_coqueiro": {
		"nome": "Madeira de coqueiro",
		"tipo": "recurso",
		"icone": "madeira_de_coqueiro",
		"empilhavel": true,
	},
	"pedra": {
		"nome": "Pedra",
		"tipo": "recurso",
		"icone": "pedra",
		"empilhavel": true,
	},
	"peixe": {
		"nome": "Peixe",
		"tipo": "recurso",
		"icone": "peixe",
		"empilhavel": true,
	},
	## O que a criatura da mata deixa no chão (ver Criatura.ESPECIES). Recurso e
	## não comida, como o peixe: carne crua não se come, se cozinha ou se vende.
	"carne_de_caca": {
		"nome": "Carne de caça",
		"tipo": "recurso",
		"resumo": "Do caititu da mata. Crua não se come; assa-se no fogão ou vende-se no balcão.",
		"icone": "carne_de_caca",
		"empilhavel": true,
	},
	## O que a ONÇA deixa (ver Criatura.ESPECIES). Não se come e não se usa: em
	## 1887 o couro de onça era o que ela valia para quem a derrubava, e é o
	## que faz o penedo ser um lugar aonde se vai, e não de onde se foge.
	"couro_de_onca": {
		"nome": "Couro de onça",
		"tipo": "recurso",
		"resumo": "Da onça do penedo, na mata de lá do rio. Não serve para nada em casa; no balcão vale o que quatro caças valem.",
		"icone": "couro_de_onca",
		"empilhavel": true,
	},
	## O que a JARARACA deixa. Em 1887 a banha de cobra era remédio de
	## benzedeira — para reumatismo, para dor nas juntas —, e é por isso que
	## vale no balcão e a Dona Zefa gosta de ganhar.
	"banha_de_jararaca": {
		"nome": "Banha de jararaca",
		"tipo": "recurso",
		"resumo": "Da jararaca do brejo. Remédio de benzedeira para dor de junta; no balcão paga o susto.",
		"icone": "banha_de_jararaca",
		"empilhavel": true,
	},
	## E o que ela vira no fogão (ver Cozinha). Depois da crua, que é de onde
	## ela vem.
	##
	## DEVOLVIA 7, e custava 7 para cozinhar: o prato que fecha o dia de mata
	## não fechava nada, e o resumo prometia sustentar mais que o peixe, que
	## devolve 42. Era o 7 do CUSTO da receita copiado para cá. A pergunta do
	## Graveyard Keeper pegou ("quanto isto rende por fôlego gasto?"), e o
	## `testar_comidas` cobra agora que toda comida da panela renda mais do
	## que custa. 52: acima do peixe, porque custou uma briga, e abaixo do
	## pirão, que custou três ingredientes.
	"carne_assada": {
		"nome": "Caça na brasa",
		"tipo": "comida",
		"resumo": "Carne de caititu virada na brasa. Sustenta mais que o peixe.",
		"folego": 52.0,
		"icone": "carne_assada",
		"empilhavel": true,
	},
	## OS DOIS PEIXES DE LUGAR. Ver `Pesca.TANQUES`: toda água do mapa dava o
	## mesmo peixe, e o mapa tem água em quatro lugares diferentes.
	##
	## Os dois são RECURSO e não comida, como o peixe comum: peixe cru não se
	## come, se cozinha ou se vende. O que os distingue é o preço no balcão e a
	## água de onde saem.
	##
	## A arte dos dois é o peixe comum RECOLORIDO
	## (`tools/pixellab/recolorir-peixes.ps1`), pela mesma razão que a cabra é o
	## bode recolorido: três peixes que dividem cesto, mochila e balcão precisam
	## parecer irmãos, e três gerações bonitas não parecem do mesmo jogo.
	"robalo": {
		"nome": "Robalo",
		"tipo": "recurso",
		"resumo": "Peixe de baía, prateado e graúdo. Vale bem no balcão.",
		"icone": "robalo",
		"empilhavel": true,
	},
	"traira": {
		"nome": "Traíra",
		"tipo": "recurso",
		"resumo": "Peixe de remanso, escuro e cheio de espinho. Quem sabe comer, come.",
		"icone": "traira",
		"empilhavel": true,
	},
	## O QUE SÓ NASCE LÁ EM CIMA. É o que a Dona Zefa pede na série dela, e a
	## fala dela é anterior ao item: "eu tô velha pra subir na serra, e tem
	## coisa que só nasce lá em cima". A erva existia na boca dela e não no
	## jogo, e por isso o favor dela nunca pôde ser feito.
	##
	## MATERIAL e não comida: não se come erva de benzedeira. Ela vira remédio
	## nas mãos de quem sabe, e quem sabe é ela.
	## OS PRÊMIOS DO CADERNO (ver Colecao, "bichos", e Arraial._frente_das_metas):
	## a metade da parede da Guilda do Stardew que faltava. Os dois primeiros
	## itens do jogo nos encaixes do corpo e do amuleto, e os dois da luta.
	##
	## O GIBÃO é a DEFESA do Stardew: tira um de toda mordida, sem deixar
	## nenhuma em menos de um. O do caititu cai de quatro para três; o da onça,
	## de oito para sete. É do pai do Pedro, e é ele quem entrega.
	"gibao_de_couro": {
		"nome": "Gibão de couro",
		"tipo": "equipamento",
		"encaixe": "corpo",
		"efeito": {"defesa": 1.0},
		"resumo": "O gibão do pai do Pedro, de couro curtido. A mordida pega, mas não atravessa inteira.",
		"icone": "gibao_de_couro",
		"empilhavel": false,
	},
	## O PATUÁ é o anel de proteção do Stardew: o respiro depois da pancada
	## dura 0,4 s a mais. A Dona Zefa costura, e o couro é o da onça.
	"patua": {
		"nome": "Patuá de couro de onça",
		"tipo": "equipamento",
		"encaixe": "amuleto",
		"efeito": {"respiro": 0.4},
		"resumo": "Saquinho de couro de onça com a reza da Dona Zefa dentro. Depois da pancada, segura a próxima um instante a mais.",
		"icone": "patua",
		"empilhavel": false,
	},
	## O CHÁ DE FOLHA, o remédio (ver Cozinha). É comida para a mochila — bebe-se
	## com F ou com o E na mão —, mas o que devolve é VIDA, e a mochila diz isso
	## com todas as letras.
	"cha_de_folha": {
		"nome": "Chá de folha",
		"tipo": "comida",
		"resumo": "Folha da serra fervida, do jeito que a Dona Zefa ensinou. Fecha ferida de bicho e corta peçonha de cobra.",
		"folego": 2.0,
		"vida": 12.0,
		"corta_peconha": true,
		"icone": "cha_de_folha",
		"empilhavel": true,
	},
	"erva_da_serra": {
		"nome": "Maço de ervas da serra",
		"tipo": "material",
		"resumo": "Folha da serra, apanhada e atada. Só nasce onde a mata abre e o sol bate.",
		"icone": "erva_da_serra",
		"empilhavel": true,
	},
	"tabua": {
		"nome": "Tábua serrada",
		"tipo": "material",
		"icone": "tabua",
		"empilhavel": true,
	},
	"corda": {
		"nome": "Corda de piaçava",
		"tipo": "material",
		"icone": "corda",
		"empilhavel": true,
	},
	"farinha": {
		"nome": "Farinha de mandioca",
		"tipo": "recurso",
		"icone": "farinha",
		"empilhavel": true,
	},
	"milho": {
		"nome": "Milho",
		"tipo": "recurso",
		"icone": "milho",
		"empilhavel": true,
	},
	"cana": {
		"nome": "Cana-de-açúcar",
		"tipo": "recurso",
		"icone": "cana",
		"empilhavel": true,
	},
	"lampiao": {
		"nome": "Lampião",
		"tipo": "material",
		"icone": "lampiao",
		"empilhavel": false,
	},
	## `leitura` é a chave do texto dele em data/dialogos/pedro.json. É o que
	## deixa RELER o documento de propósito, pela mochila (F), em vez de por
	## acidente: antes, a única releitura possível era apertar E perto do mural
	## com ele no bolso, e a cerimônia inteira do papel recomeçava sem que o
	## jogador tivesse pedido nada.
	"convite": {
		"nome": "Convite da fazenda",
		"tipo": "documento",
		"icone": "carta",
		"leitura": "convite_texto",
		"empilhavel": false,
	},
	## OS PAPÉIS E O PANO DOS ARCOS DOS MORADORES (07/10, docs/projeto/MISSOES_SECUNDARIAS.md,
	## fase 2): o papel da pedra do altar e a madeira lavrada da linha do pescador se LEEM
	## (documentos, texto em data/documentos.json, ícones de coisas que já existem); a
	## toalha do tio se põe na mesa da casa de taipa (oferenda).
	"papel_dos_nomes": {
		"nome": "Papel com nomes",
		"tipo": "documento",
		"resumo": "Enrolado, amarelo, com a dobra da pedra ainda marcada.",
		"icone": "carta",
		"leitura": "papel_dos_nomes",
		"empilhavel": false,
	},
	"tabua_lavrada": {
		"nome": "Madeira lavrada",
		"tipo": "documento",
		"resumo": "Um pedaço de proa com letras fundas, comidas de sal.",
		"icone": "tabua",
		"leitura": "tabua_lavrada",
		"empilhavel": false,
	},
	"toalha_de_renda": {
		"nome": "Toalha de renda",
		"tipo": "material",
		"resumo": "Branca de todo, com um nome na borda em ponto cheio.",
		"icone": "toalha_de_renda",
		"empilhavel": false,
	},
	## A carta da filha da Dona Rosa (fase 3): vai ao padre e volta, e se lê.
	"carta_da_rosa": {
		"nome": "Carta da filha da Dona Rosa",
		"tipo": "documento",
		"resumo": "Letra redonda, de Salvador, sem data.",
		"icone": "carta",
		"leitura": "carta_da_rosa",
		"empilhavel": false,
	},
	## OS RITUAIS PREPARADOS, que são o que o oratório produz.
	##
	## Tipo próprio (`ritual`) e não `comida`: os dois se consomem da mochila e
	## fazem coisa, e é só isso que têm em comum. Comida entra pela mochila
	## (tecla I) e repõe fôlego; ritual se usa NO MUNDO, com o E, e o que ele
	## faz depende de onde o jogador está — chamar chuva dentro de casa não
	## molha roçado nenhum.
	##
	## Os três dividem o mesmo ícone de trouxa amarrada, e é de propósito: o
	## que muda entre um preparo e outro é o que foi amarrado dentro, e por
	## fora eles são a mesma trouxa. O nome na mão diz qual é (ver o balãozinho
	## do HUD), e a cor da fita separa os três de relance.
	"chamado_de_chuva": {
		"nome": "Chamado de chuva",
		"tipo": "ritual",
		"resumo": "Milho torrado, cana partida e água para jogar contra o vento.",
		"icone": "ritual_chuva",
		"empilhavel": true,
	},
	"resguardo_da_roca": {
		"nome": "Resguardo da roça",
		"tipo": "ritual",
		"resumo": "Farinha peneirada para andar de costas no contorno do canteiro.",
		"icone": "ritual_resguardo",
		"empilhavel": true,
	},
	"olho_da_mata": {
		"nome": "Olho da mata",
		"tipo": "ritual",
		"resumo": "Folha verde para queimar e abrir os olhos devagar.",
		"icone": "ritual_olho",
		"empilhavel": true,
	},
	## O cordel não entra na mochila: vai direto para a coleção (tecla L). Fica
	## no catálogo só pelo ícone, que é o papel desenhado no chão.
	"cordel": {
		"nome": "Folheto de cordel",
		"tipo": "documento",
		"resumo": "Verso impresso em papel barato, dobrado em quatro.",
		"icone": "cordel",
		"empilhavel": false,
	},
	## Chapéu de palha: presente do Pedro no fim de uma missão. É o primeiro
	## item de EQUIPAR — o sistema de equipamento nasce em cima dele.
	"chapeu": {
		"nome": "Chapéu de palha",
		"tipo": "equipamento",
		"encaixe": "cabeca",
		"efeito": {"energia_maxima": 10.0},
		"resumo": "Sol na nuca cansa. Com ele o corpo aguenta mais.",
		"icone": "chapeu",
		"empilhavel": false,
	},
	## O FACÃO JÁ EXISTIA, e não tinha de onde vir: arte no lote original, corte
	## de cana em `Recursos`, encaixe de cintura aqui — e fonte nenhuma. A fase
	## 6-A deu as duas coisas que faltavam: a oficina bate um (ver Oficina) e
	## ele é a ARMA do jogo, a que bate mais que o machado. Continua sendo
	## equipamento e continua cortando cana; o `dano` é o que ele ganhou.
	##
	## ARMA VAI NOS NÚMEROS, e o encaixe das Mãos é das luvas: "No campo mãos do
	## inventário, não é para armas, mas sim para luvas. Armas são nos campos
	## numerais." O facão deixou de ser equipamento de encaixe (e o efeito de
	## cintura dele foi junto): é ferramenta da barra de mão, como o machado.
	## A partida salva com ele vestido o devolve à barra (`Partida`).
	## AS LUVAS DE COURO, a primeira peça do encaixe das Mãos — "não é para armas,
	## mas sim para luvas". Couro curtido de vaqueiro, para a lida: com as mãos
	## guardadas o trabalho cansa menos (o mesmo -5% de fôlego gasto que o facão
	## dava na cintura). Vendem no balcão.
	"luvas_de_couro": {
		"nome": "Luvas de couro",
		"tipo": "equipamento",
		"encaixe": "maos",
		"efeito": {"eficiencia": -0.05},
		"resumo": "Couro curtido de vaqueiro. Com as mãos guardadas, a lida cansa menos.",
		"icone": "luvas_de_couro",
		"empilhavel": false,
	},
	## A LANÇA E O ESCUDO DE SAFIRAS do capítulo 7 (data/missoes_revoar.json, #31): os
	## do senhor da fazenda, achados entre os destroços da torre da capela das
	## ruínas. A lança é a arma do embate com a Matinta — mais que o dobro do facão;
	## o escudo vai nas Mãos e segura a mordida como quatro gibões. "Reluziam uma
	## luminosidade azul cada vez mais intensa" perto da fera: é a luz do `revoar_vale`.
	"lanca_de_safira": {
		"nome": "Lança de safiras",
		"tipo": "ferramenta",
		"resumo": "Esculpida num material azul, com adornos de ouro e safiras. A lança do senhor da fazenda, que atravessou a fera uma vez.",
		"icone": "lanca_de_safira",
		"empilhavel": false,
		"dano": 9.0,
	},
	"escudo_de_safira": {
		"nome": "Escudo de safiras",
		"tipo": "equipamento",
		"encaixe": "maos",
		"efeito": {"defesa": 4.0},
		"resumo": "Forte, azul, com safiras grandes. No braço, a mordida da fera chega pela metade. Deixá-lo ao lado da coruja é o que as mulheres pedem.",
		"icone": "escudo_de_safira",
		"empilhavel": false,
	},
	"facao": {
		"nome": "Facão de mato",
		"tipo": "ferramenta",
		"resumo": "Na mão, é o que corta: a arma do mato, a cana e a fibra da piaçava.",
		"icone": "facao",
		"empilhavel": false,
		"dano": 4.0,
	},
	"mungunza": {
		"nome": "Mungunzá",
		"tipo": "comida",
		"resumo": "Milho branco com leite de coco. Comida de festa e de dia duro.",
		"folego": 45.0,
		"efeito_dias": 1,
		"efeito_campo": "eficiencia",
		"efeito_valor": -0.30,
		"icone": "mungunza",
		"empilhavel": true,
	},
	## O que sai do fogão. Fôlego alto é prato que dá trabalho de fazer: a
	## garapa levanta na hora e acaba, o pirão sustenta a tarde inteira.
	##
	## OS TRÊS SUBIRAM (12/28/40 para 22/42/62), e a conta é do começo do jogo.
	## O teto de fôlego nasce em 100 e a noite devolve 40; derrubar os trinta e
	## seis paus da ponte custa umas 270. Com o pirão valendo 40 — o mesmo que
	## dormir —, cozinhar era um jeito caro de fazer o que a cama fazia de graça,
	## e o jogador ficava sem o que fazer além de deitar. Agora o prato que dá
	## trabalho vale MAIS que a noite, que é o que faz valer a pena acender o
	## fogo.
	"garapa": {
		"nome": "Garapa",
		"tipo": "comida",
		"resumo": "Caldo de cana tirado na hora. Doce, gelado se o pote for de barro.",
		"folego": 22.0,
		"icone": "garapa",
		"empilhavel": true,
	},
	"peixe_assado": {
		"nome": "Peixe na brasa",
		"tipo": "comida",
		"resumo": "Aberto no sal e virado na brasa. Come-se com a mão.",
		"folego": 42.0,
		"icone": "peixe_assado",
		"empilhavel": true,
	},
	"pirao": {
		"nome": "Pirão de peixe",
		"tipo": "comida",
		"resumo": "Caldo engrossado na farinha. Enche mais que o peixe e a farinha separados.",
		"folego": 62.0,
		"efeito_dias": 1,
		"efeito_campo": "eficiencia",
		"efeito_valor": -0.10,
		"icone": "pirao",
		"empilhavel": true,
	},
	## O BEIJU é o prato mais barato que existe no jogo: uma farinha e uma
	## lenha. Entrou porque no começo o jogador não tinha prato que fizesse
	## diferença sem peixe — e peixe depende de vara, de píer e de paciência.
	## Beiju se faz com o que sai da primeira colheita.
	"beiju": {
		"nome": "Beiju",
		"tipo": "comida",
		"resumo": "Massa de mandioca aberta na chapa quente e dobrada. Come-se andando.",
		"folego": 24.0,
		"icone": "beiju",
		"empilhavel": true,
	},
	## A OSTRA se cata na areia com a maré baixa, e é o primeiro item do mar
	## que não precisa de vara. Come-se crua e rende pouco: é petisco de quem
	## anda na praia, não refeição. O ícone é desenhado à mão
	## (tools/pixellab/desenhar-ostra.ps1), irmão das cuias.
	"ostra": {
		"nome": "Ostra",
		"tipo": "comida",
		"resumo": "Catada na areia na maré baixa. Abre-se na faca e come-se crua.",
		"folego": 10.0,
		"icone": "ostra",
		"empilhavel": true,
	},
	## A COCADA não se cozinha: coco não é recurso do mapa. Ela chega pela mão
	## de quem dá, como a mungunzá — é recompensa de missão, e é de propósito
	## que o jogador não possa fabricar mais: presente que se repete deixa de
	## ser presente.
	"cocada": {
		"nome": "Cocada",
		"tipo": "comida",
		"resumo": "Coco com açúcar, cortada em quadrado. Doce de quem vende na porta da igreja.",
		"folego": 34.0,
		"efeito_dias": 1,
		"efeito_campo": "recuperacao_ao_dormir",
		"efeito_valor": 10.0,
		"icone": "cocada",
		"empilhavel": true,
	},
}

## Cache de textura por id: `load` a cada quadro derruba o desempenho da barra
## de mão, que redesenha sempre que o inventário muda.
static var _icones: Dictionary = {}


static func existe(id: String) -> bool:
	return ITENS.has(id)


static func dados(id: String) -> Dictionary:
	return ITENS.get(id, {})


static func nome(id: String) -> String:
	return ITENS.get(id, {}).get("nome", id)


## Quanto uma ferramenta tira de uma criatura por golpe; zero para o que não é
## arma (e para a mão vazia). Ver `Mundo._golpear`.
static func dano(id: String) -> float:
	return float(dados(id).get("dano", 0.0))


static func tipo(id: String) -> String:
	return ITENS.get(id, {}).get("tipo", "")


## DE QUE FAMÍLIA É A FERRAMENTA: o machado de aço é machado. O item sem
## `familia` é a família dele mesmo — o machado de ferro, a foice.
static func familia(id: String) -> String:
	return str(dados(id).get("familia", id))


## O GRAU DA FERRAMENTA: 1 a de ferro (e toda ferramenta sem grau), 2 a de aço.
static func grau(id: String) -> int:
	return int(dados(id).get("grau", 1))


static func icone(id: String) -> Texture2D:
	if _icones.has(id):
		return _icones[id]

	var arquivo: String = ITENS.get(id, {}).get("icone", "")
	if arquivo == "":
		return null

	var caminho := PASTA + arquivo + ".png"
	if not ResourceLoader.exists(caminho):
		push_warning("Ícone ausente: %s" % caminho)
		_icones[id] = null
		return null

	_icones[id] = load(caminho) as Texture2D
	return _icones[id]
