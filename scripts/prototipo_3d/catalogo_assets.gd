class_name CatalogoAssets
extends RefCounted
## Catálogo único das peças do vale: para cada chave, o GLB do Tripo (linha mestra)
## e a medida usada para normalizar o modelo na cena. O construtor procedural de cada
## peça vive em FloraReconcavo / world_builder e é escolhido quando Estilo.procedural().
##
## "altura" normaliza pela altura visual; "largura" pela maior dimensão horizontal.
## "tronco" é o raio da colisão cilíndrica (árvores), no eixo do tronco medido no modelo;
## "caixa" pede colisão em caixa, na pegada da altura do corpo; "caixas" é uma lista de
## [tamanho, centro] (metros, pé no meio da caixa) para peça feita de partes;
## "camera" diz se a peça barra também o braço da câmera (ver `colisao`).
## "girar" (graus, x/y/z) deita ou vira o modelo antes de medir (peixe e tábua vêm de pé);
## "afundar" (unidades) enterra o modelo depois de normalizado (píer com estacas altas);
## "piso" é a altura do tabuado caminhável que world_builder cria por cima.
## Medidas dos GLBs (caixa envolvente do Tripo, sempre 0,98 no maior eixo):
## tools/tripo/medir_glb.py.

const PASTA := "res://assets/prototipo_3d/"
const Camadas = preload("res://scripts/prototipo_3d/camadas.gd")
const CoqueiroCortado = preload("res://scripts/prototipo_3d/coqueiro_cortado.gd")
const PecasDistantes = preload("res://scripts/prototipo_3d/pecas_distantes.gd")

const PECAS := {
	# Árvores nomeadas (perto do jogador)
	"mangueira": {"tripo": "arvores/mangueira_tripo.glb", "altura": 7.2, "tronco": 0.55},
	"jaqueira": {"tripo": "arvores/jaqueira_tripo.glb", "altura": 8.4, "tronco": 0.4},
	# O cilindro vai no eixo do tronco medido no modelo (`tronco`): o deslocamento
	# à mão que havia aqui (-0,15; 0,06) ficava a 0,4 u do tronco desenhado.
	"cajueiro": {"tripo": "arvores/cajueiro_tripo.glb", "altura": 5.4,
		"tronco": 0.7, "tronco_altura": 2.2},
	"coqueiro": {"tripo": "arvores/coqueiro_tripo.glb", "altura": 9.5, "tronco": 0.24},
	"pau_brasil": {"tripo": "arvores/pau_brasil_tripo.glb", "altura": 5.6, "tronco": 0.38},
	"dendezeiro": {"tripo": "arvores/dende_tripo.glb", "altura": 6.5, "tronco": 0.4},
	"bananeira": {"tripo": "arvores/bananeira_tripo.glb", "altura": 3.2, "tronco": 0.25},
	"ipe_amarelo": {"tripo": "arvores/ipe_amarelo_tripo.glb", "altura": 6.5, "tronco": 0.3},
	"ipe_roxo": {"tripo": "arvores/ipe_roxo_tripo.glb", "altura": 6.5, "tronco": 0.3},
	"embauba": {"tripo": "arvores/embauba_tripo.glb", "altura": 8.0, "tronco": 0.2},
	"mata_alta": {"tripo": "arvores/mata_a_tripo.glb", "altura": 11.0, "tronco": 0.45},
	"mata_larga": {"tripo": "arvores/mata_b_tripo.glb", "altura": 9.0, "tronco": 0.5},
	"moita": {"tripo": "arvores/moita_tripo.glb", "altura": 1.1},
	"castanhola": {"tripo": "arvores/castanhola_tripo.glb", "altura": 6.0, "tronco": 0.45},
	"aroeira": {"tripo": "arvores/aroeira_tripo.glb", "altura": 4.5, "tronco": 0.4},
	# Mata local (28/09): manguezal, restinga e beira de rio de Saubara.
	"mangue": {"tripo": "arvores/mangue_tripo.glb", "altura": 5.0, "tronco": 0.6},
	"piacava": {"tripo": "arvores/piacava_tripo.glb", "altura": 5.5, "tronco": 0.45},
	"ingazeiro": {"tripo": "arvores/ingazeiro_tripo.glb", "altura": 7.5, "tronco": 0.4},
	"clusia": {"tripo": "arvores/clusia_tripo.glb", "altura": 3.2, "tronco": 0.35},
	"pitangueira": {"tripo": "arvores/pitangueira_tripo.glb", "altura": 3.0, "tronco": 0.25},
	"jenipapeiro": {"tripo": "arvores/jenipapeiro_tripo.glb", "altura": 8.5, "tronco": 0.4},
	"sub_bosque": {"tripo": "arvores/sub_bosque_tripo.glb", "altura": 1.3},
	"capim": {"tripo": "arvores/capim_tripo.glb", "altura": 0.9},
	# Construções
	"capela": {"tripo": "construcoes/capela_tripo.glb", "largura": 9.0, "caixa": true, "camera": true},
	# A capelinha pobre do cemitério, de taipa e cal rachada (lote de 03/10/2026).
	"capelinha": {"tripo": "construcoes/capelinha_tripo.glb", "largura": 4.6, "caixa": true, "camera": true},
	"igreja": {"tripo": "construcoes/igreja_tripo.glb", "largura": 10.0, "caixa": true, "camera": true},
	# SEM "afundar": as paredes começam uns 0,20 acima do mínimo do GLB, e a
	# casca afundada encostava a parede no alicerce — mas a casa herdada, a do
	# Pedro e a da Zefa têm o cômodo DENTRO da casca, medido nela
	# (`Interiores._medir`): com os 0,20 a mais, ninguém entrava andando nas
	# três, e sem eles entra (tests/casa.gd, casas_dos_moradores.gd).
	# O enterro das casas pequenas no terreno inclinado continua
	# (`WorldBuilder.AFUNDAMENTO_CASAS_PEQUENAS`).
	"casa_taipa": {"tripo": "construcoes/casa_taipa_tripo.glb", "largura": 6.5, "caixa": true, "camera": true},
	"casa_carro_quebrado": {"tripo": "casas/casa_carro_quebrado_tripo.glb", "largura": 5.2, "caixa": true, "camera": true},
	"venda": {"tripo": "construcoes/venda_tripo.glb", "largura": 8.0, "caixa": true, "camera": true},
	"casa_pasto": {"tripo": "construcoes/casa_pasto_tripo.glb", "largura": 8.5, "caixa": true, "camera": true},
	"pier": {"tripo": "construcoes/pier_tripo.glb", "largura": 12.0, "afundar": 2.9, "piso": 0.22},
	# A ponte de pé (#94, 06/10) veio comprida no Z: o giro a deita no X, como a
	# antiga e a caída, para o vão seguir a estrada (`world_builder._erguer_ponte`).
	# Medida em 06/10 (`scratch/diag/medir_ponte.gd`): o tabuleiro fica a 0,95 do
	# fundo, com os esteios por baixo; afundado 0,75, ele fica a 0,2 da estrada.
	"ponte": {"tripo": "construcoes/ponte_tripo.glb", "largura": 9.0, "afundar": 0.75, "piso": 0.2, "girar": [0, 90, 0]},
	# A PONTE GRANDE DA VILA (07/10: "na vila, pode colocar o modelo da ponte grande,
	# como era antes; deixa a pequena somente para ir à mansão"): a ponte de madeira do
	# lote de 26/09, que as duas travessias usaram até 06/10, de volta à do rio
	# central, com as medidas de então. A do rio grande fica com a de pé e a caída (#94).
	"ponte_grande": {"tripo": "construcoes/ponte_grande_tripo.glb", "largura": 9.0, "afundar": 1.1, "piso": 0.2},
	# A PONTE CAÍDA (#94): o mesmo vão, sem tabuleiro que se ande — nem colisão nem
	# laje da câmera; a obra `ponte_levantar` a troca pela de pé (`ponte_vale.gd`).
	# Medida em 06/10: os tabuleiros das pontas ficam a 1,9 do fundo, e o vão caído
	# desce daí até o rio; afundada 1,7, as pontas ficam a 0,2 da estrada.
	"ponte_caida": {"tripo": "construcoes/ponte_caida_tripo.glb", "largura": 9.0, "afundar": 1.7},
	# O MIRANTE É UMA TORRE ABERTA, de quatro pernas com mão-francesa dos lados,
	# o assoalho a 2,45 m e a escada na frente: em caixa única era um bloco de
	# 3,3 × 3,6 × 4,6, e quem chegava à âncora (embaixo dele) nascia preso. Medido
	# no GLB (05/10/2026). Não barra a câmera: é armação, e ela passa entre as
	# pernas.
	"mirante": {"tripo": "construcoes/mirante_tripo.glb", "altura": 3.6, "camera": false, "caixas": [
		[Vector3(0.3, 2.45, 3.0), Vector3(-1.35, 1.22, -0.6)],
		[Vector3(0.3, 2.45, 3.0), Vector3(1.35, 1.22, -0.6)],
		[Vector3(3.2, 0.35, 3.1), Vector3(0.0, 2.5, -0.65)],
		[Vector3(0.9, 1.2, 0.7), Vector3(-0.6, 0.6, 1.85)]]},
	# Adereços
	# O anel de pedra tem 3,1 × 2,6 m: com 1,05 o corpo entrava meio palmo nele.
	"poco": {"tripo": "construcoes/poco_tripo.glb", "altura": 3.1, "tronco": 1.3, "camera": false},
	"cerca": {"tripo": "aderecos/cerca_tripo.glb", "altura": 1.15, "caixa": true},
	# O CRUZEIRO É BASE, FUSTE E BRAÇOS (medidos no GLB, 05/10/2026). Em caixa
	# única eram 2,62 m de largura do chão aos 4,5 m: 0,9 m de parede invisível
	# de cada lado do fuste, e a câmera saltava ao passar na frente dele.
	"cruzeiro": {"tripo": "aderecos/cruzeiro_tripo.glb", "altura": 4.5, "caixas": [
		[Vector3(0.92, 0.6, 0.92), Vector3(0.0, 0.3, 0.0)],
		[Vector3(0.3, 3.9, 0.3), Vector3(0.0, 2.55, 0.0)],
		[Vector3(2.62, 0.9, 0.5), Vector3(0.0, 3.45, 0.0)]]},
	"tumulo": {"tripo": "aderecos/tumulo_tripo.glb", "largura": 1.6},
	"carroca": {"tripo": "aderecos/carroca_tripo.glb", "largura": 3.2, "caixa": true},
	"varal": {"tripo": "aderecos/varal_tripo.glb", "largura": 3.8},
	"lenha": {"tripo": "aderecos/lenha_tripo.glb", "largura": 1.5, "caixa": true},
	# O tronco que a trovoada derrubou no cemitério: vem de comprido no Z.
	"tronco_caido": {"tripo": "aderecos/tronco_caido_tripo.glb", "largura": 2.6, "caixa": true},
	"pote": {"tripo": "aderecos/pote_tripo.glb", "altura": 0.95},
	"banco": {"tripo": "aderecos/banco_tripo.glb", "altura": 1.0, "caixa": true},
	"lampiao_poste": {"tripo": "aderecos/lampiao_poste_tripo.glb", "altura": 3.4, "tronco": 0.15},
	"candeeiro": {"tripo": "aderecos/candeeiro_tripo.glb", "altura": 0.42},
	# A FOGUEIRA DE VERDADE: o anel de pedras e as toras, sem a chama rígida (os
	# 1.379 triângulos dela saíram no 8413ae7; o fogo vem de partículas). Entre
	# 04/10 e 06/10 a peça apontava a pilha de lenha, e o jogador via a pilha
	# com chama em cima (#86). Sólida: sem a caixa o corpo entrava no meio das
	# toras acesas. Cozinhar não depende de encostar nela (`BancadasVale`, raio).
	"fogueira": {"tripo": "aderecos/fogueira_tripo.glb", "largura": 1.6, "caixa": true},
	# A BANCADA DA OFICINA, na beira do roçado: a mesa rústica do lote dos móveis,
	# maior e sólida, faz as vezes do banco de carpinteiro até a oficina ter
	# construção própria (#27). Não é arte nova: é o mesmo GLB da `mesa`.
	"bancada_oficina": {"tripo": "moveis/mesa_tripo.glb", "largura": 1.5, "caixa": true},
	# A mesa do canteiro de obras é a mesma mesa: provisória, como a da oficina.
	"bancada_canteiro": {"tripo": "moveis/mesa_tripo.glb", "largura": 1.5, "caixa": true},
	"mandioca_canteiro": {"tripo": "aderecos/mandioca_canteiro_tripo.glb", "largura": 3.5},
	"pedras": {"tripo": "aderecos/pedras_tripo.glb", "largura": 3.0, "caixa": true, "camera": true},
	# A lapa da lombada é a mesma pedra, com nome próprio: a meta "derrubar" da
	# missão conta só ela (`recursos_3d.derrubados`).
	"lapa": {"tripo": "aderecos/pedras_tripo.glb", "largura": 3.0, "caixa": true, "camera": true},
	# A PEDRA SOLTA, a que se quebra: o mesmo monte de pedras, mas pequeno (tamanho de
	# 0,3 a 0,4, do tornozelo ao joelho do jogador) e solto no chão. Pedra quebrável
	# cabe na mão (`Recursos3D.pedra_pequena`); as grandes, de cenário, são `pedras`.
	# Sem "camera": o braço da câmera não pode saltar ao passar por uma pedra de meio
	# metro. Nenhum modelo novo: é o GLB de `pedras`.
	"pedra_solta": {"tripo": "aderecos/pedras_tripo.glb", "largura": 3.0, "caixa": true, "camera": false},
	# A cabra do Seu Benedito, presa no alto da lombada (lote do Tripo de 05/10).
	"cabra": {"tripo": "aderecos/cabra_tripo.glb", "largura": 1.3},
	# A FAZENDA DO CONVITE (lotes do Tripo de 05/10): o casarão, de frente para +Z,
	# com a escadaria; a guarita de pedra velha; e o portão baixo de ferro fino,
	# que `fazenda_vale.gd` achata à altura do capítulo 6.
	"casarao_fazenda": {"tripo": "construcoes/casarao_fazenda_tripo.glb", "largura": 16.0, "caixa": true},
	"guarita_fazenda": {"tripo": "construcoes/guarita_fazenda_tripo.glb", "largura": 2.8, "caixa": true},
	"portao_fazenda": {"tripo": "construcoes/portao_fazenda_tripo.glb", "largura": 5.0},
	"pedras_praia": {"tripo": "aderecos/pedras_praia_tripo.glb", "largura": 9.0, "caixa": true, "camera": true},
	"pedra_mare": {"tripo": "aderecos/pedra_mare_tripo.glb", "largura": 3.2},
	"bote": {"tripo": "aderecos/bote_tripo.glb", "largura": 6.0},
	# O saveiro do mestre Quirino, o barco da chegada (lote de 05/10/2026). O
	# comprimento é o X do modelo; a vela vai da metade para a popa (o -X).
	"saveiro": {"tripo": "aderecos/saveiro_tripo.glb", "largura": 9.0},
	"canoa_amarela": {"tripo": "aderecos/canoa_amarela_tripo.glb", "largura": 4.6},
	"canoa": {"tripo": "aderecos/canoa_tripo.glb", "largura": 5.6},
	# Personagens
	"pedro": {"tripo": "personagens/pedro_tripo.glb", "altura": 1.75},
	"benedito": {"tripo": "personagens/benedito_tripo.glb", "altura": 1.68},
	"zefa": {"tripo": "personagens/zefa_tripo.glb", "altura": 1.58},
	"cosme": {"tripo": "personagens/cosme_tripo.glb", "altura": 1.5},
	"tonho": {"tripo": "personagens/tonho_tripo.glb", "altura": 1.72},
	"filo": {"tripo": "personagens/filo_tripo.glb", "altura": 1.6},
	"damiao": {"tripo": "personagens/damiao_tripo.glb", "altura": 1.74},
	"candinha": {"tripo": "personagens/candinha_tripo.glb", "altura": 1.62},
	"quirino": {"tripo": "personagens/quirino_tripo.glb", "altura": 1.7},
	"viajante": {"tripo": "personagens/viajante_tripo.glb", "altura": 1.78},
	"tubarao": {"tripo": "mar/tubarao_tripo.glb", "largura": 2.6},
	# Itens de mão (os mesmos do 2D)
	"machado": {"tripo": "itens/machado_tripo.glb", "altura": 0.85},
	"enxada": {"tripo": "itens/enxada_tripo.glb", "altura": 0.95},
	"balde": {"tripo": "itens/balde_tripo.glb", "altura": 0.38},
	"picareta": {"tripo": "itens/picareta_tripo.glb", "altura": 0.9},
	"foice": {"tripo": "itens/foice_tripo.glb", "largura": 0.5},
	"regador": {"tripo": "itens/regador_tripo.glb", "altura": 0.4},
	"vara_pescar": {"tripo": "itens/vara_pescar_tripo.glb", "altura": 2.0},
	"mandioca": {"tripo": "itens/mandioca_tripo.glb", "largura": 0.5},
	"lenha_feixe": {"tripo": "itens/lenha_feixe_tripo.glb", "largura": 0.6},
	"pedra": {"tripo": "itens/pedra_tripo.glb", "largura": 0.25},
	"peixe": {"tripo": "itens/peixe_tripo.glb", "largura": 0.4, "girar": [-90, 0, 0]},
	"cesto": {"tripo": "itens/cesto_tripo.glb", "altura": 0.4},
	"facao": {"tripo": "itens/facao_tripo.glb", "largura": 0.6},
	"corda": {"tripo": "itens/corda_tripo.glb", "largura": 0.35},
	"tabua": {"tripo": "itens/tabua_tripo.glb", "largura": 1.6, "girar": [-90, 0, 0]},
	"farinha": {"tripo": "itens/farinha_tripo.glb", "altura": 0.6},
	"chapeu": {"tripo": "itens/chapeu_tripo.glb", "largura": 0.4},
	# A luva de couro, de mão direita e em pé (dedos para cima): o corpo a põe
	# nas duas mãos, a esquerda espelhada (`Vestimenta3D.luvas`).
	"luvas_de_couro": {"tripo": "itens/luvas_de_couro_tripo.glb", "altura": 0.25},
	"milho": {"tripo": "itens/milho_tripo.glb", "largura": 0.3},
	"cana": {"tripo": "itens/cana_tripo.glb", "altura": 1.6},
	"moringa": {"tripo": "itens/moringa_tripo.glb", "altura": 0.35},
	"prato_comida": {"tripo": "itens/prato_comida_tripo.glb", "largura": 0.3},
	"cacho_banana": {"tripo": "itens/cacho_banana_tripo.glb", "altura": 0.45},
	"jaca": {"tripo": "itens/jaca_tripo.glb", "altura": 0.45},
	# Mobília da casa herdada (#26). A casa põe cada uma na largura do lugar dela
	# (`interior_casa._movel`), com a frente no +Z; a cama e a cantareira vieram
	# de comprido no Z, e o giro as deita no X: a cabeceira para a parede da
	# esquerda, e os dois potes lado a lado, de frente para a sala.
	"cama": {"tripo": "moveis/cama_tripo.glb", "largura": 1.9, "girar": [0, 90, 0]},
	"mesa": {"tripo": "moveis/mesa_tripo.glb", "largura": 1.1},
	"banco_tosco": {"tripo": "moveis/banco_tosco_tripo.glb", "largura": 1.0},
	"bau": {"tripo": "moveis/bau_tripo.glb", "largura": 0.9},
	"barril": {"tripo": "moveis/barril_tripo.glb", "altura": 0.8},
	"cantareira": {"tripo": "moveis/cantareira_tripo.glb", "altura": 0.9, "girar": [0, 90, 0]},
	"fogao_barro": {"tripo": "moveis/fogao_barro_tripo.glb", "largura": 1.0},
	"jirau": {"tripo": "moveis/jirau_tripo.glb", "largura": 1.2},
	"oratorio": {"tripo": "moveis/oratorio_tripo.glb", "altura": 0.6},
	"rede": {"tripo": "moveis/rede_tripo.glb", "largura": 2.4},
	# O que diz quem mora (lote de 03/10/2026): a rede de pesca e os remos do
	# Pedro, e as ervas, o pilão e a gamela da Dona Zefa. Rede, remos e ervas vêm
	# chatos no Z, para ir na parede.
	"rede_de_pesca": {"tripo": "moveis/rede_de_pesca_tripo.glb", "altura": 1.4},
	"remos": {"tripo": "moveis/remos_tripo.glb", "altura": 1.8},
	"ervas_secando": {"tripo": "moveis/ervas_secando_tripo.glb", "largura": 1.3},
	"pilao": {"tripo": "moveis/pilao_tripo.glb", "altura": 1.0},
	"gamela": {"tripo": "moveis/gamela_tripo.glb", "largura": 0.7},
	# O que faltava ao terreiro e à gameleira (#52): os dois mastros com pano
	# branco e as fitas no tronco (`world_builder._build_marcos_de_fe`).
	"mastro_pano": {"tripo": "aderecos/mastro_pano_tripo.glb", "altura": 5.0, "tronco": 0.05},
	"fitas_gameleira": {"tripo": "aderecos/fitas_gameleira_tripo.glb", "largura": 3.0},
	# --- lote 05/10 level design: início ---
	# Moradores sem fala e quem faltava no arraial (lote de 05/10/2026, rig Mixamo com seis clipes)
	"padre": {"tripo": "personagens/padre_tripo.glb", "altura": 1.72},
	"mercador": {"tripo": "personagens/mercador_tripo.glb", "altura": 1.72},
	"guarda": {"tripo": "personagens/guarda_tripo.glb", "altura": 1.74},
	"sacristao": {"tripo": "personagens/sacristao_tripo.glb", "altura": 1.62},
	"beata": {"tripo": "personagens/beata_tripo.glb", "altura": 1.55},
	"pescador": {"tripo": "personagens/pescador_tripo.glb", "altura": 1.73},
	"marisqueira": {"tripo": "personagens/marisqueira_tripo.glb", "altura": 1.6},
	"lavadeira": {"tripo": "personagens/lavadeira_tripo.glb", "altura": 1.6},
	"rendeira": {"tripo": "personagens/rendeira_tripo.glb", "altura": 1.58},
	"quituteira": {"tripo": "personagens/quituteira_tripo.glb", "altura": 1.62},
	"carpinteiro": {"tripo": "personagens/carpinteiro_tripo.glb", "altura": 1.76},
	"menino": {"tripo": "personagens/menino_tripo.glb", "altura": 1.3},
	"menina": {"tripo": "personagens/menina_tripo.glb", "altura": 1.24},
	"mestre_saveiro": {"tripo": "personagens/mestre_saveiro_tripo.glb", "altura": 1.7},
	# Bichos do vale (lote de 05/10/2026): quadrúpedes com o rig do Studio e o andar; aves paradas ou com rig
	"cachorro_caramelo": {"tripo": "animais/cachorro_caramelo_tripo.glb", "largura": 1.0},
	"cachorro_malhado": {"tripo": "animais/cachorro_malhado_tripo.glb", "largura": 0.95, "girar": [0, 90, 0]},
	"filhote_caramelo": {"tripo": "animais/filhote_caramelo_tripo.glb", "largura": 0.5, "girar": [0, 90, 0]},
	"gato_malhado": {"tripo": "animais/gato_malhado_tripo.glb", "largura": 0.72, "girar": [0, 90, 0]},
	"gato_preto": {"tripo": "animais/gato_preto_tripo.glb", "largura": 0.72},
	"gato_amarelo": {"tripo": "animais/gato_amarelo_tripo.glb", "largura": 0.72, "girar": [0, -90, 0]},
	"porco": {"tripo": "animais/porco_tripo.glb", "largura": 1.25, "girar": [0, 90, 0]},
	"leitao": {"tripo": "animais/leitao_tripo.glb", "largura": 0.5, "girar": [0, 90, 0]},
	"onca_pintada": {"tripo": "animais/onca_pintada_tripo.glb", "largura": 2.3, "girar": [0, -90, 0]},
	"onca_preta": {"tripo": "animais/onca_preta_tripo.glb", "largura": 2.3, "girar": [0, 90, 0]},
	"jumento": {"tripo": "animais/jumento_tripo.glb", "largura": 1.9, "girar": [0, -90, 0]},
	"cabra_solta": {"tripo": "animais/cabra_tripo.glb", "largura": 1.15, "girar": [0, -90, 0]},
	"galinha": {"tripo": "animais/galinha_tripo.glb", "altura": 0.45, "girar": [0, -90, 0]},
	"galo": {"tripo": "animais/galo_tripo.glb", "altura": 0.62, "girar": [0, -90, 0]},
	"pintinho": {"tripo": "animais/pintinho_tripo.glb", "altura": 0.11, "girar": [0, -90, 0]},
	"galinha_dangola": {"tripo": "animais/galinha_dangola_tripo.glb", "altura": 0.5, "girar": [0, -90, 0]},
	"pato": {"tripo": "animais/pato_tripo.glb", "altura": 0.5, "girar": [0, -90, 0]},
	"peru": {"tripo": "animais/peru_tripo.glb", "altura": 0.85, "girar": [0, 90, 0]},
	"pavao": {"tripo": "animais/pavao_tripo.glb", "largura": 1.5, "girar": [0, -90, 0]},
	"pavoa": {"tripo": "animais/pavoa_tripo.glb", "altura": 0.85, "girar": [0, 90, 0]},
	"caititu": {"tripo": "animais/caititu_tripo.glb", "largura": 1.0},
	"cachorro_deitado": {"tripo": "animais/cachorro_deitado_tripo.glb", "largura": 1.0, "girar": [0, 18, 0]},
	"pavao_leque": {"tripo": "animais/pavao_leque_tripo.glb", "altura": 1.25},
	"jararaca": {"tripo": "animais/jararaca_tripo.glb", "largura": 1.3},
	"garca": {"tripo": "animais/garca_tripo.glb", "altura": 0.95},
	"bode": {"tripo": "animais/bode_tripo.glb", "largura": 1.25},
	"boi": {"tripo": "animais/boi_tripo.glb", "largura": 2.4},
	"cavalo": {"tripo": "animais/cavalo_tripo.glb", "largura": 2.3},
	"urubu": {"tripo": "animais/urubu_tripo.glb", "largura": 1.5},
	"capivara": {"tripo": "animais/capivara_tripo.glb", "largura": 1.2},
	"tatu": {"tripo": "animais/tatu_tripo.glb", "largura": 0.75},
	# Peixes e raias (lote de 05/10/2026): o jogo os faz nadar por código
	"sardinha": {"tripo": "peixes/sardinha_tripo.glb", "largura": 0.2, "girar": [0, -90, 0]},
	"tainha": {"tripo": "peixes/tainha_tripo.glb", "largura": 0.5, "girar": [0, 90, 0]},
	"xareu": {"tripo": "peixes/xareu_tripo.glb", "largura": 0.7, "girar": [0, -90, 0]},
	"cavala": {"tripo": "peixes/cavala_tripo.glb", "largura": 1.0, "girar": [0, 90, 0]},
	"sororoca": {"tripo": "peixes/sororoca_tripo.glb", "largura": 0.75, "girar": [0, 90, 0]},
	"robalo": {"tripo": "peixes/robalo_tripo.glb", "largura": 0.8, "girar": [0, -90, 0]},
	"garoupa": {"tripo": "peixes/garoupa_tripo.glb", "largura": 0.9, "girar": [0, 90, 0]},
	"budiao": {"tripo": "peixes/budiao_tripo.glb", "largura": 0.45, "girar": [0, 90, 0]},
	"sargentinho": {"tripo": "peixes/sargentinho_tripo.glb", "largura": 0.2, "girar": [0, 90, 0]},
	"baiacu": {"tripo": "peixes/baiacu_tripo.glb", "largura": 0.25, "girar": [0, -90, 0]},
	"moreia": {"tripo": "peixes/moreia_tripo.glb", "largura": 1.2, "girar": [0, 90, 0]},
	"raia": {"tripo": "peixes/raia_tripo.glb", "largura": 1.3, "girar": [-90, -90, 0]},
	"raia_pintada": {"tripo": "peixes/raia_pintada_tripo.glb", "largura": 1.9, "girar": [-52, 0, 0]},
	"piaba": {"tripo": "peixes/piaba_tripo.glb", "largura": 0.14, "girar": [0, -90, 0]},
	"traira": {"tripo": "peixes/traira_tripo.glb", "largura": 0.45, "girar": [0, 90, 0]},
	"acara": {"tripo": "peixes/acara_tripo.glb", "largura": 0.22, "girar": [0, 90, 0]},
	"tubarao_cabeca_chata": {"tripo": "peixes/tubarao_tripo.glb", "largura": 2.6, "girar": [0, -90, 0]},
	# Flora do paisagismo por zonas (lote de 05/10/2026)
	"mamoeiro": {"tripo": "arvores/mamoeiro_tripo.glb", "altura": 4.2, "tronco": 0.14},
	"goiabeira": {"tripo": "arvores/goiabeira_tripo.glb", "altura": 4.6, "tronco": 0.22},
	"touceira_bambu": {"tripo": "arvores/touceira_bambu_tripo.glb", "altura": 9.0, "tronco": 0.9},
	"licurizeiro": {"tripo": "arvores/licurizeiro_tripo.glb", "altura": 5.2, "tronco": 0.25},
	"pe_de_fumo": {"tripo": "arvores/pe_de_fumo_tripo.glb", "altura": 1.3},
	"pe_de_milho": {"tripo": "arvores/pe_de_milho_tripo.glb", "altura": 2.2},
	"touceira_cana": {"tripo": "arvores/touceira_cana_tripo.glb", "altura": 3.0},
	"pe_de_mandioca": {"tripo": "arvores/pe_de_mandioca_tripo.glb", "altura": 1.8},
	"heliconia": {"tripo": "arvores/heliconia_tripo.glb", "altura": 2.2},
	"bromelia": {"tripo": "arvores/bromelia_tripo.glb", "altura": 0.8},
	"samambaia": {"tripo": "arvores/samambaia_tripo.glb", "altura": 1.0},
	"taboa": {"tripo": "arvores/taboa_tripo.glb", "altura": 1.8},
	"jatoba": {"tripo": "arvores/jatoba_tripo.glb", "altura": 10.0, "tronco": 0.45},
	"sapucaia": {"tripo": "arvores/sapucaia_tripo.glb", "altura": 9.5, "tronco": 0.45},
	"jequitiba": {"tripo": "arvores/jequitiba_tripo.glb", "altura": 13.0, "tronco": 0.6},
	"cedro": {"tripo": "arvores/cedro_tripo.glb", "altura": 9.0, "tronco": 0.4},
	"angico": {"tripo": "arvores/angico_tripo.glb", "altura": 7.5, "tronco": 0.35},
	"massaranduba": {"tripo": "arvores/massaranduba_tripo.glb", "altura": 10.0, "tronco": 0.45},
	"gameleira": {"tripo": "arvores/gameleira_tripo.glb", "altura": 14.0, "tronco": 1.2},
	"canteiro_couve": {"tripo": "arvores/canteiro_couve_tripo.glb", "largura": 2.4},
	"pe_de_pimenta": {"tripo": "arvores/pe_de_pimenta_tripo.glb", "altura": 0.8},
	"quiabeiro": {"tripo": "arvores/quiabeiro_tripo.glb", "altura": 1.2},
	"latada_maracuja": {"tripo": "arvores/latada_maracuja_tripo.glb", "largura": 3.5},
	"abobora_rasteira": {"tripo": "arvores/abobora_rasteira_tripo.glb", "largura": 2.0},
	"algodoeiro_praia": {"tripo": "arvores/algodoeiro_praia_tripo.glb", "altura": 5.0, "tronco": 0.3},
	# Casas e construções novas (lote de 05/10/2026)
	"casa_taipa_azul": {"tripo": "construcoes/casa_taipa_azul_tripo.glb", "largura": 6.5, "caixa": true, "camera": true},
	"casa_taipa_ocre": {"tripo": "construcoes/casa_taipa_ocre_tripo.glb", "largura": 6.5, "caixa": true, "camera": true},
	"casa_pescador": {"tripo": "construcoes/casa_pescador_tripo.glb", "largura": 5.6, "caixa": true, "camera": true},
	"casa_palha": {"tripo": "construcoes/casa_palha_tripo.glb", "largura": 5.2, "caixa": true, "camera": true},
	"casa_farinha": {"tripo": "construcoes/casa_farinha_tripo.glb", "largura": 8.0, "caixa": true, "camera": true},
	"sobrado": {"tripo": "construcoes/sobrado_tripo.glb", "largura": 7.5, "caixa": true, "camera": true},
	"cadeia": {"tripo": "construcoes/cadeia_tripo.glb", "largura": 7.0, "caixa": true, "camera": true},
	"casa_paroquial": {"tripo": "construcoes/casa_paroquial_tripo.glb", "largura": 7.5, "caixa": true, "camera": true},
	"casa_taipa_rosa": {"tripo": "construcoes/casa_taipa_rosa_tripo.glb", "largura": 6.5, "caixa": true, "camera": true},
	"casa_taipa_verde": {"tripo": "construcoes/casa_taipa_verde_tripo.glb", "largura": 6.5, "caixa": true, "camera": true},
	"casa_varanda": {"tripo": "construcoes/casa_varanda_tripo.glb", "largura": 7.0, "caixa": true, "camera": true},
	"casa_meia_agua": {"tripo": "construcoes/casa_meia_agua_tripo.glb", "largura": 5.0, "caixa": true, "camera": true},
	# Quintais: varais, galinheiro, chiqueiro e cocho (lote de 05/10/2026)
	"varal_bambu": {"tripo": "aderecos/varal_bambu_tripo.glb", "largura": 3.6},
	"varal_estacas": {"tripo": "aderecos/varal_estacas_tripo.glb", "largura": 4.2},
	"galinheiro": {"tripo": "aderecos/galinheiro_tripo.glb", "largura": 2.2, "caixa": true},
	"chiqueiro": {"tripo": "aderecos/chiqueiro_tripo.glb", "largura": 3.0},
	"cocho": {"tripo": "aderecos/cocho_tripo.glb", "largura": 1.6, "caixa": true},
	"lavadouro_pedra": {"tripo": "aderecos/lavadouro_pedra_tripo.glb", "largura": 1.6, "caixa": true},
	"canoa_em_obra": {"tripo": "aderecos/canoa_em_obra_tripo.glb", "largura": 5.0, "caixa": true},
	"cerca_varas": {"tripo": "aderecos/cerca_varas_tripo.glb", "largura": 3.0},
	"porteira": {"tripo": "aderecos/porteira_tripo.glb", "largura": 3.2, "caixa": true},
	"carro_de_boi": {"tripo": "aderecos/carro_de_boi_tripo.glb", "largura": 4.2, "caixa": true},
	"monjolo": {"tripo": "aderecos/monjolo_tripo.glb", "largura": 4.5, "caixa": true},
	"forno_barro": {"tripo": "aderecos/forno_barro_tripo.glb", "largura": 1.6, "caixa": true},
	"estaleiro_fumo": {"tripo": "aderecos/estaleiro_fumo_tripo.glb", "largura": 4.0, "caixa": true},
	"sacos_farinha": {"tripo": "aderecos/sacos_farinha_tripo.glb", "largura": 1.3, "caixa": true},
	"barraca_feira": {"tripo": "aderecos/barraca_feira_tripo.glb", "largura": 2.6, "caixa": true},
	"penedo_lapa": {"tripo": "aderecos/penedo_lapa_tripo.glb", "altura": 6.0, "caixa": true, "camera": true},
	# Objetos do ofício dos moradores (lote de 05/10/2026)
	"trouxa_roupa": {"tripo": "itens/trouxa_roupa_tripo.glb", "largura": 0.6},
	"tabuleiro": {"tripo": "itens/tabuleiro_tripo.glb", "largura": 0.7},
	"vassoura_piacava": {"tripo": "itens/vassoura_piacava_tripo.glb", "altura": 1.4},
	"rolo_fumo": {"tripo": "itens/rolo_fumo_tripo.glb", "largura": 0.5},
	# Versões leves (~2.500 faces) e de longe (~700) das árvores, refeitas pela retopologia do Tripo (lote de 05/10/2026)
	"aroeira_leve": {"tripo": "arvores/aroeira_leve_tripo.glb", "altura": 4.5, "tronco": 0.4},
	"jenipapeiro_leve": {"tripo": "arvores/jenipapeiro_leve_tripo.glb", "altura": 8.5, "tronco": 0.4},
	"piacava_leve": {"tripo": "arvores/piacava_leve_tripo.glb", "altura": 5.5, "tronco": 0.45},
	"bananeira_leve": {"tripo": "arvores/bananeira_leve_tripo.glb", "altura": 3.2, "tronco": 0.25},
	"cajueiro_leve": {"tripo": "arvores/cajueiro_leve_tripo.glb", "altura": 5.4},
	"pitangueira_leve": {"tripo": "arvores/pitangueira_leve_tripo.glb", "altura": 3.0, "tronco": 0.25},
	"mangueira_leve": {"tripo": "arvores/mangueira_leve_tripo.glb", "altura": 7.2, "tronco": 0.55},
	"jaqueira_leve": {"tripo": "arvores/jaqueira_leve_tripo.glb", "altura": 8.4, "tronco": 0.4},
	"castanhola_leve": {"tripo": "arvores/castanhola_leve_tripo.glb", "altura": 6.0, "tronco": 0.45},
	"ingazeiro_leve": {"tripo": "arvores/ingazeiro_leve_tripo.glb", "altura": 7.5, "tronco": 0.4},
	"mangue_leve": {"tripo": "arvores/mangue_leve_tripo.glb", "altura": 5.0, "tronco": 0.6},
	"coqueiro_leve": {"tripo": "arvores/coqueiro_leve_tripo.glb", "altura": 9.5, "tronco": 0.24},
	"dendezeiro_leve": {"tripo": "arvores/dendezeiro_leve_tripo.glb", "altura": 6.5, "tronco": 0.4},
	"clusia_leve": {"tripo": "arvores/clusia_leve_tripo.glb", "altura": 3.2, "tronco": 0.35},
	"ipe_amarelo_leve": {"tripo": "arvores/ipe_amarelo_leve_tripo.glb", "altura": 6.5, "tronco": 0.3},
	"ipe_roxo_leve": {"tripo": "arvores/ipe_roxo_leve_tripo.glb", "altura": 6.5, "tronco": 0.3},
	"pau_brasil_leve": {"tripo": "arvores/pau_brasil_leve_tripo.glb", "altura": 5.6, "tronco": 0.38},
	"coqueiro_longe": {"tripo": "arvores/coqueiro_longe_tripo.glb", "altura": 9.5},
	"mangue_longe": {"tripo": "arvores/mangue_longe_tripo.glb", "altura": 5.0},
	"ingazeiro_longe": {"tripo": "arvores/ingazeiro_longe_tripo.glb", "altura": 7.5},
	"castanhola_longe": {"tripo": "arvores/castanhola_longe_tripo.glb", "altura": 6.0},
	"mata_alta_longe": {"tripo": "arvores/mata_alta_longe_tripo.glb", "altura": 11.0},
	"mata_larga_longe": {"tripo": "arvores/mata_larga_longe_tripo.glb", "altura": 9.0},
	"jenipapeiro_longe": {"tripo": "arvores/jenipapeiro_longe_tripo.glb", "altura": 8.5},
	"aroeira_longe": {"tripo": "arvores/aroeira_longe_tripo.glb", "altura": 4.5},
	"piacava_longe": {"tripo": "arvores/piacava_longe_tripo.glb", "altura": 5.5},
	"embauba_longe": {"tripo": "arvores/embauba_longe_tripo.glb", "altura": 8.0},
	"mangueira_longe": {"tripo": "arvores/mangueira_longe_tripo.glb", "altura": 7.2},
	"jaqueira_longe": {"tripo": "arvores/jaqueira_longe_tripo.glb", "altura": 8.4},
	"cajueiro_longe": {"tripo": "arvores/cajueiro_longe_tripo.glb", "altura": 5.4},
	"bananeira_longe": {"tripo": "arvores/bananeira_longe_tripo.glb", "altura": 3.2},
	"dendezeiro_longe": {"tripo": "arvores/dendezeiro_longe_tripo.glb", "altura": 6.5},
	# --- lote 05/10 level design: fim ---
}

## Peças finas e abertas (pano, vela, corda, fita, rede, varal, cerca) que precisam
## das DUAS faces: o plano some visto de trás se o descarte de costas for ligado.
const DUAS_FACES := [
	"varal", "varal_bambu", "varal_estacas", "trouxa_roupa", "mastro_pano",
	"fitas_gameleira", "saveiro", "rede", "rede_de_pesca", "corda",
	"cerca", "cerca_varas", "barraca_feira", "ervas_secando",
]

## Árvores cujo TRONCO vem de costas no GLB (#156): o Tripo fechou o fuste com o
## sentido dos triângulos para dentro, e com o descarte de costas ligado o lado de
## fora do tronco some e se vê o lado de dentro da parede do fundo, como um tronco
## oco ou com fenda (o ipê do adro, a pitangueira do quintal de toda casa).
## `tests/troncos_fechados.gd` mede cada árvore de tronco: de cada raio horizontal
## que cruza o pé dela, a fração cujo primeiro triângulo é de costas. As espécies
## íntegras dão de 0 a 6%; estas dão de 12% a 79%. Ficam com as duas faces, e as
## normais do GLB acompanham o sentido dos triângulos, então a face de trás sai
## bem iluminada. As outras seguem com o descarte ligado: não é ajuste global, e a
## lista só cresce com a medida (o portão reprova árvore que passa do limite e
## fora daqui, e entrada que já não precisa).
const TRONCO_DE_COSTAS := [
	"pitangueira", "pitangueira_leve", "ipe_amarelo", "licurizeiro",
	"clusia_leve", "jenipapeiro_leve", "mangue_leve", "mangue_longe",
	"castanhola_longe", "piacava_longe",
]


## A peça precisa das duas faces: fina e aberta (`DUAS_FACES`) ou árvore de tronco
## de costas (`TRONCO_DE_COSTAS`).
static func precisa_das_duas_faces(chave: String) -> bool:
	return DUAS_FACES.has(chave) or TRONCO_DE_COSTAS.has(chave)

## O ALCANCE DAS PEÇAS DO CENÁRIO (`dar_alcance`, chamado ao fim de `instanciar`).
##
## ~300 peças do cenário (28 construções de 10 mil triângulos, 50 árvores de 10 a 20
## mil, os adereços e os recursos) eram desenhadas inteiras a qualquer distância:
## de longe uma casa tem 15 pixels e a árvore, 20. Cada peça agora some ao passar de
## um ALCANCE que cresce com o tamanho dela (uma peça de `FATOR` vezes a sua
## dimensão maior ocupa sempre os mesmos pixels ao sumir), limitado por classe:
##
##   construcao  a casa e o prédio (`construcoes/`, `casas/`): 22 x, de 100 a 260 u.
##               A casa e a igreja ganham um substituto barato que entra onde o modelo
##               começa a sumir e vai a 1.200 u (`pecas_distantes.gd`): nada some no horizonte;
##   arvore      a nomeada (`arvores/` com `tronco`): 22 x, de 70 a 260 u, e a copa
##               da mata no lugar dela;
##   adereco     o que fica no chão (`aderecos/`): 30 x, de 60 a 200 u: os pequenos
##               somem entre 60 e 90 u, e DESVANECEM (`FADE_SELF`) numa faixa de
##               `MARGEM_DO_DESVANECER`, para não saltarem;
##   planta      a roça e o canteiro (`arvores/` sem tronco): 30 x, de 50 a 90 u.
##
## Fora dela ficam o que anda (gente, bicho, peixe, barco), o que se leva na mão e a
## mobília, que mora dentro de cômodo: ver `classe_de_alcance`. A SOMBRA não precisa
## de corte próprio: o sol só sombreia até 70 u (`ceu_vale.gd`), e o alcance das
## peças pequenas (60 a 90 u) já acaba onde a sombra acaba.
##
## O MODELO DESVANECE de `end` até `end` + a margem (medido com a GPU em
## tools/prototipo_3d/medir_lod_das_pecas.gd --modo=troca): a casa de 143 u e margem 15
## some aos 158 u, a árvore de 177 aos 192, e o pote de 60 (margem 8) aos 68. Casa e
## árvore têm o substituto barato, que aparece em `end`, seco e por baixo do modelo que
## ainda se vê: nada some sem o outro estar lá. A troca seca com margem dos dois lados
## (a da mata) deixava um BURACO: a peça que nasce com a câmera dentro da margem não
## desenhava nem o modelo nem o substituto (`medir_lod_das_pecas.gd --modo=estado`).
##
## `alcance_ligado` falso devolve o vale de antes (ferramentas de medida e portões).
static var alcance_ligado := true
const FATOR_DO_ALCANCE := {"construcao": 22.0, "arvore": 22.0, "adereco": 30.0, "planta": 30.0}
const ALCANCE_MINIMO := {"construcao": 100.0, "arvore": 70.0, "adereco": 60.0, "planta": 50.0}
const ALCANCE_MAXIMO := {"construcao": 260.0, "arvore": 260.0, "adereco": 200.0, "planta": 90.0}
## A faixa em que o modelo desvanece, com substituto (casa e árvore) e sem ele.
const MARGEM_DA_TROCA := 15.0
const MARGEM_DO_DESVANECER := 8.0
## A construção a partir de quanto (u, a dimensão maior) ganha o substituto.
const TAMANHO_DA_CASA := 4.5
## Peças do cenário que ficam inteiras a qualquer distância, e por quê.
const SEM_ALCANCE := {
	"pier": "o primeiro que se vê da baía e o jogador anda nele: uma peça só",
	"ponte": "o jogador anda nela e se vê da estrada: uma peça só",
	"ponte_grande": "a ponte grande da vila, no rio central: uma peça só, como a ponte",
	"ponte_caida": "a ponte caída no rio, que a obra põe de pé: uma peça só, como a ponte",
	"mirante": "torre aberta vista de todo o vale: uma peça só, e uma caixa não a imita",
	"saveiro": "o barco da chegada: anda pela baía, e some no horizonte se for cortado",
	"bote": "o barco do saveiro: anda pela baía",
	"canoa": "a canoa ancorada: anda com a maré",
	"canoa_amarela": "a canoa ancorada: anda com a maré",
}

static var _cenas: Dictionary = {}
## Materiais já tratados por `_descartar_costas` (instance_id -> true): um só ajuste por material.
static var _materiais_tratados: Dictionary = {}
static var _malhas: Dictionary = {}
static var faltando: Array[String] = []


## Esquece as malhas medidas (uma medida foi ajustada no painel PERSONAGENS).
static func limpar_cache() -> void:
	_malhas.clear()
	_pegadas.clear()
	_troncos.clear()


static func caminho(chave: String) -> String:
	if not PECAS.has(chave):
		return ""
	return PASTA + String(PECAS[chave]["tripo"])


static func tem_tripo(chave: String) -> bool:
	var path := caminho(chave)
	return not path.is_empty() and ResourceLoader.exists(path)


## Cena do Tripo para a chave, ou null (registrando a falta) quando o GLB ainda não existe.
static func cena(chave: String) -> PackedScene:
	if _cenas.has(chave):
		return _cenas[chave]
	var path := caminho(chave)
	if path.is_empty() or not ResourceLoader.exists(path):
		if not faltando.has(chave):
			faltando.append(chave)
		_cenas[chave] = null
		return null
	var scene := load(path) as PackedScene
	if scene != null:
		_descartar_costas(scene, path.contains("/arvores/"), precisa_das_duas_faces(chave))
	_cenas[chave] = scene
	return scene


## Os GLBs do Tripo vêm com doubleSided, que o importador vira CULL_DISABLED: cada
## triângulo de costas era rasterizado à toa em todas as passadas (profundidade, cor e
## cascatas de sombra; medido de -14 a -18 ms). O ajuste vai NO PRÓPRIO material, que é
## compartilhado por todas as instâncias da cena e pela malha que `malha()` entrega ao
## MultiMesh da mata e do paisagismo. Material com transparência fica como está.
static func _descartar_costas(scene: PackedScene, vegetacao: bool = false, duas_faces: bool = false) -> void:
	var raiz := scene.instantiate()
	for filho in raiz.find_children("*", "MeshInstance3D", true, false):
		var instancia := filho as MeshInstance3D
		if instancia.mesh == null:
			continue
		for s in instancia.mesh.get_surface_count():
			if vegetacao:
				preload("res://scripts/prototipo_3d/estacoes_vale.gd").registrar(instancia.get_active_material(s) as BaseMaterial3D)
			if duas_faces:
				continue
			_tratar_material(instancia.get_surface_override_material(s))
			_tratar_material(instancia.mesh.surface_get_material(s))
		if not duas_faces:
			_tratar_material(instancia.material_override)
	raiz.free()


static func _tratar_material(material: Material) -> void:
	var base := material as BaseMaterial3D
	if base == null:
		return
	var id := base.get_instance_id()
	if _materiais_tratados.has(id):
		return
	_materiais_tratados[id] = true
	if base.cull_mode == BaseMaterial3D.CULL_DISABLED and base.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
		base.cull_mode = BaseMaterial3D.CULL_BACK


## Instancia o modelo do Tripo com a base no chão em `origin`, normalizado pela medida
## do catálogo (× size) e girado em `yaw`. Devolve null quando o GLB não existe.
## Apoio das plantas baixas: orienta a base pelo relevo sem inclinar árvores.
static func apoio_no_relevo(terreno: Node, ponto: Vector3) -> Transform3D:
	var passo := 0.4
	var dx: float = terreno.ground_height_at(ponto + Vector3.RIGHT * passo) - terreno.ground_height_at(ponto - Vector3.RIGHT * passo)
	var dz: float = terreno.ground_height_at(ponto + Vector3.BACK * passo) - terreno.ground_height_at(ponto - Vector3.BACK * passo)
	var normal := Vector3(-dx, 2.0 * passo, -dz).normalized()
	var giro := Basis(Quaternion(Vector3.UP, normal))
	return Transform3D(giro, Vector3(ponto.x, terreno.ground_height_at(ponto) - 0.06, ponto.z))


static func assentar_planta(no: Node3D, terreno: Node, pe: Vector3) -> void:
	var local := no.transform
	local.origin -= pe
	no.transform = apoio_no_relevo(terreno, pe) * local


static func instanciar(chave: String, parent: Node, origin: Vector3, size: float = 1.0, yaw: float = 0.0) -> Node3D:
	var scene := cena(chave)
	if scene == null:
		return null
	# Medidas com os ajustes do painel PERSONAGENS por cima (ajustes_conteudo.gd).
	var spec: Dictionary = AjustesConteudo.peca(chave)
	var node := scene.instantiate() as Node3D
	if spec.has("girar"):
		# Envolve o modelo num nó girado para que a medida seja tirada já deitado/virado.
		var girado := Node3D.new()
		var graus: Array = spec["girar"]
		node.rotation_degrees = Vector3(float(graus[0]), float(graus[1]), float(graus[2]))
		girado.add_child(node)
		node = girado
	node.name = chave.capitalize() + "Tripo"
	node.set_meta("peca", chave)
	parent.add_child(node)
	var bounds := limites(node)
	var factor := 1.0
	if spec.has("altura"):
		factor = float(spec["altura"]) * size / maxf(bounds.size.y, 0.001)
	else:
		factor = float(spec["largura"]) * size / maxf(maxf(bounds.size.x, bounds.size.z), 0.001)
	node.scale = Vector3.ONE * factor
	node.rotation.y = yaw
	var center := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * factor
	node.position = origin - center.rotated(Vector3.UP, yaw) - Vector3(0, float(spec.get("afundar", 0.0)), 0)
	node.set_meta("limites", AABB(bounds.position * factor, bounds.size * factor))
	dar_alcance(chave, node, spec, bounds, factor)
	return node


## A CLASSE DE ALCANCE da peça ("construcao", "arvore", "adereco", "planta") ou ""
## quando ela fica inteira a qualquer distância: o que anda ou se leva na mão
## (`personagens/`, `animais/`, `peixes/`, `mar/`, `itens/`), a mobília (`moveis/`,
## que mora dentro de cômodo) e as peças de `SEM_ALCANCE`.
static func classe_de_alcance(chave: String) -> String:
	if not PECAS.has(chave) or SEM_ALCANCE.has(chave):
		return ""
	var spec: Dictionary = PECAS[chave]
	var arquivo := String(spec.get("tripo", ""))
	if arquivo.begins_with("construcoes/") or arquivo.begins_with("casas/"):
		return "construcao"
	if arquivo.begins_with("arvores/"):
		return "arvore" if spec.has("tronco") else "planta"
	if arquivo.begins_with("aderecos/"):
		return "adereco"
	return ""


## ATÉ ONDE (u) a peça se vê, pela classe e pelo tamanho dela (`tamanho`: a
## dimensão maior, em u, já com a escala posta). O catálogo pode fixar à mão com
## "alcance". 0 quando a peça não tem corte.
static func alcance_de(chave: String, tamanho: float) -> float:
	var classe := classe_de_alcance(chave)
	if classe.is_empty():
		return 0.0
	var spec: Dictionary = PECAS[chave]
	if spec.has("alcance"):
		return float(spec["alcance"])
	return clampf(tamanho * float(FATOR_DO_ALCANCE[classe]), float(ALCANCE_MINIMO[classe]), float(ALCANCE_MAXIMO[classe]))


## Dá o alcance à peça recém-instanciada: o corte em cada malha do modelo, o
## desvanecer nas que não têm substituto e, para a casa e a árvore nomeada, o
## substituto barato que entra onde o modelo sai (`pecas_distantes.gd`). Também
## marca o modelo com a chave (`peca`), para os portões e as ferramentas.
static func dar_alcance(chave: String, node: Node3D, _spec: Dictionary, bounds: AABB, escala: float) -> void:
	node.set_meta("peca", chave)
	if classe_de_alcance(chave) == "arvore" or chave in ["saveiro", "bote", "canoa", "canoa_amarela"]:
		node.add_to_group("obstaculos_visuais_da_camera")
	if not alcance_ligado or Engine.is_editor_hint():
		return
	var classe := classe_de_alcance(chave)
	if classe.is_empty():
		return
	var tamanho := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z)) * escala
	var fim := alcance_de(chave, tamanho)
	var longe: MultiMeshInstance3D = null
	if classe == "construcao" and tamanho >= TAMANHO_DA_CASA:
		longe = PecasDistantes.casa(chave, bounds, fim)
	elif classe == "arvore":
		longe = PecasDistantes.copa(chave, bounds, fim)
	# O modelo SEMPRE desvanece (sem estado, sem histerese: ver `pecas_distantes.gd`): a
	# peça pequena some e a casa e a árvore passam para o substituto, que já está por baixo.
	var margem := MARGEM_DA_TROCA if longe != null else MARGEM_DO_DESVANECER
	for geometria in PecasDistantes.geometrias_do_modelo(node):
		geometria.set_meta("lod_fim", fim)
		geometria.visibility_range_end = fim
		geometria.visibility_range_end_margin = margem
		geometria.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	if longe != null:
		node.add_child(longe)
	node.add_to_group(PecasDistantes.GRUPO)


## O MAPA ALTO (câmera ortográfica a 3.000 u) tira o corte das peças e esconde os
## substitutos; a volta ao passeio os repõe. Quem chama é o renderizador da região,
## junto com o que ele faz com a mata (`GeoRegionRenderer._atualizar_lod_da_camera`).
static func modo_mapa(arvore: SceneTree, mapa: bool) -> void:
	PecasDistantes.modo_mapa(arvore, mapa)


## Piso medido no GLB: centro a 0,31 u sobre a origem, útil por 7 × 1 u.
## A malha preserva corrimãos e estacas; esta sola une as tábuas e suaviza
## apenas as duas juntas de 0,3 u com o chão, sem passagem ao lado da ponte.
static func _apoiar_tabuleiro(node: Node3D, parent: Node, origin: Vector3, bounds: AABB, yaw: float) -> void:
	var fator := maxf(bounds.size.x, bounds.size.z) / 9.0
	var alto := 1.06 * fator - float(AjustesConteudo.peca("ponte").get("afundar", 0.75))
	var metade := 3.5 * fator
	var fim := 4.8 * fator
	node.set_meta("piso_do_tabuleiro", origin.y + alto)
	var eixo := Vector3(cos(yaw), 0, -sin(yaw)) if bounds.size.x >= bounds.size.z else Vector3(sin(yaw), 0, cos(yaw))
	var corpo := StaticBody3D.new()
	corpo.name = "TabuleiroContinuo"
	node.add_child(corpo)
	corpo.global_transform = Transform3D(Basis(eixo, Vector3.UP, eixo.cross(Vector3.UP)), origin + Vector3.UP * (alto - 0.1 * fator))
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(7, 0.2, 1) * fator
	forma.shape = caixa
	corpo.add_child(forma)
	if not parent.has_method("ground_height_at"):
		return
	for sinal: float in [-1.0, 1.0]:
		var ponta: Vector3 = origin + eixo * sinal * fim
		var piso := float(parent.ground_height_at(ponta)) + 0.07 * fator
		var pontos := PackedVector3Array()
		for x: float in [metade, fim]:
			var y := 0.1 * fator if x == metade else piso - corpo.global_position.y
			for z: float in [-0.5 * fator, 0.5 * fator]:
				pontos.append(Vector3(x * sinal, y, z))
				pontos.append(Vector3(x * sinal, y - 0.2 * fator, z))
		var rampa := CollisionShape3D.new()
		rampa.name = "JuntaDaCabeceira"
		var cunha := ConvexPolygonShape3D.new()
		cunha.points = pontos
		rampa.shape = cunha
		corpo.add_child(rampa)


## Colisão simples para um modelo instanciado por `instanciar`: cilindro no tronco ou caixa.
## Devolve o corpo criado (null quando a peça não leva corpo próprio), para quem
## precisa achá-lo depois — o cômodo de dentro tira a caixa inteira da casa.
##
## A COLISÃO FICA ONDE ESTÁ O DESENHO ("revise todas as colisões, há
## anomalias"). Antes, a caixa era a caixa envolvente inteira do GLB — o beiral,
## a varanda, os braços do cruzeiro descendo até o chão — e o cilindro ficava no
## meio dela, e não no tronco: o lampião barrava 0,43 m ao lado do poste, a
## aroeira 1,35 m ao lado da madeira. Agora:
##   · "tronco": o cilindro vai no eixo do tronco MEDIDO no modelo (`tronco`),
##     salvo quando a peça traz "tronco_centro" à mão;
##   · "caixa": a pegada do que o modelo ocupa na altura do corpo (`pegada`),
##     com a altura inteira;
##   · "caixas": várias caixas, para o que é feito de partes (o cruzeiro é
##     base, fuste e braços; o mirante é perna, assoalho e escada).
## Só BoxShape3D e CylinderShape3D, filhos diretos do corpo, que é filho de
## `parent`: é o que `ClickNavigation` e `Recursos3D` leem.
##
## "camera": a peça barra também o braço da câmera (`camadas.gd`). Construção
## e pedra barram; o resto — poste, mastro, cruzeiro, cerca, banco — não, e a
## câmera não salta ao passar perto deles (`barra_camera`).
static func colisao(chave: String, node: Node3D, parent: Node, origin: Vector3, size: float = 1.0, yaw: float = 0.0) -> StaticBody3D:
	if node == null:
		return null
	# Medidas com os ajustes do painel PERSONAGENS por cima (ajustes_conteudo.gd).
	var spec: Dictionary = AjustesConteudo.peca(chave)
	var bounds: AABB = node.get_meta("limites", AABB())
	# O giro é o do modelo posto (`instanciar` o grava em `node.rotation.y`): quem
	# chamava sem `yaw` (as pedras da praia, giradas ao acaso) tinha a caixa
	# reta e o desenho torto.
	yaw = node.rotation.y
	if chave in ["ponte", "ponte_grande", "pier"]:
		# A superfície caminhável acompanha a malha importada da ponte e do píer.
		for child in node.find_children("*", "MeshInstance3D", true, false):
			(child as MeshInstance3D).create_trimesh_collision()
		if chave == "ponte":
			_apoiar_tabuleiro(node, parent, origin, bounds, yaw)
		_laje_da_camera(chave, spec, bounds, parent, origin, yaw)
		return null
	var body := StaticBody3D.new()
	body.name = chave.capitalize() + "Colisao"
	if barra_camera(chave):
		body.collision_layer = Camadas.MUNDO_E_CAMERA
	if spec.has("tronco"):
		var collision := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = float(spec["tronco"]) * size
		shape.height = minf(bounds.size.y, float(spec.get("tronco_altura", 3.0)) * size)
		collision.shape = shape
		body.add_child(collision)
		body.position = origin + Vector3(0, shape.height * 0.5, 0)
		var base_visual := Vector3.INF
		if spec.has("tronco_centro"):
			var centro: Vector2 = spec["tronco_centro"]
			base_visual = node.transform * Vector3(centro.x, 0.0, centro.y)
		else:
			var medido := tronco(chave, size)
			if not medido.is_empty():
				base_visual = node.transform * (medido["centro"] as Vector3)
		if base_visual.is_finite():
			body.position.x = base_visual.x
			body.position.z = base_visual.z
	elif spec.has("caixas"):
		# Em metros na medida do catálogo, com o pé no meio da caixa envolvente.
		var escala := _escala_do_catalogo(chave, bounds)
		for parte: Array in spec["caixas"]:
			var collision := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = (parte[0] as Vector3) * escala
			collision.shape = shape
			collision.position = (parte[1] as Vector3) * escala
			body.add_child(collision)
		body.position = origin - Vector3(0, float(spec.get("afundar", 0.0)), 0)
		body.rotation.y = yaw
	elif spec.get("caixa", false):
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		var marca := pegada(chave)
		shape.size = Vector3(marca.size.x * bounds.size.x, bounds.size.y, marca.size.y * bounds.size.z)
		collision.shape = shape
		body.add_child(collision)
		var desvio := Vector3((marca.get_center().x - 0.5) * bounds.size.x, 0.0, (marca.get_center().y - 0.5) * bounds.size.z)
		body.position = origin + desvio.rotated(Vector3.UP, yaw) + Vector3(0, bounds.size.y * 0.5 - float(spec.get("afundar", 0.0)), 0)
		body.rotation.y = yaw
	else:
		body.free()
		return null
	parent.add_child(body)
	return body


# --- as cercas -----------------------------------------------------------------

## Quanto mede, em `tamanho`, um lance da cerca do catálogo — pela caixa de uma
## prova posta e tirada. `senao` é a medida de quem não tem a cerca do catálogo.
static func largura_da_cerca(parent: Node, tamanho: float, senao: float) -> float:
	var prova := instanciar("cerca", parent, Vector3.ZERO, tamanho)
	if prova == null:
		return senao
	var largura: float = (prova.get_meta("limites") as AABB).size.x
	parent.remove_child(prova)
	prova.free()
	return maxf(largura, 0.1)


## A BASE DE UM LANCE (#93): o X vai de `de` a `ate` — com o desnível entre as
## pontas, para o lance deitar na encosta —, o Z é a normal horizontal dele e o
## Y fica no plano vertical. Sem desnível é o giro `atan2(-rumo.z, rumo.x)` de
## sempre.
static func base_do_lance(de: Vector3, ate: Vector3) -> Basis:
	var eixo := ate - de
	var normal := eixo.cross(Vector3.UP)
	if eixo.length_squared() < 0.000001 or normal.length_squared() < 0.000001:
		return Basis()
	eixo = eixo.normalized()
	normal = normal.normalized()
	return Basis(eixo, normal.cross(eixo), normal)


## UM LANCE DE CERCA de `de` até `ate` — dois pontos no chão, de qualquer altura
## — deitado na encosta: as duas pontas tocam o chão e a caixa de colisão vai
## junto (#93). Antes o lance era reto, assentado por uma amostra do terreno no
## centro, e na encosta uma ponta flutuava e a outra se enterrava. Com o
## catálogo é a cerca do Tripo esticada ao comprimento, com a caixa `altura` ×
## `grossura` chamada `nome_da_colisao`; sem ele, a cerca procedural, que traz
## a colisão dela. `largura_do_lance` é a medida de `largura_da_cerca`.
##
## O nó entra no grupo "lances_de_cerca" com a meta "lance" = `nome`: é por ela
## que se acham os lances, porque irmãos de mesmo nome o Godot renomeia
## ("@Node3D@2038").
static func lance_de_cerca(parent: Node, de: Vector3, ate: Vector3, tripo: bool, tamanho: float, largura_do_lance: float, altura: float, grossura: float, nome: String, nome_da_colisao: String) -> Node3D:
	var lance := Node3D.new()
	lance.name = nome
	lance.set_meta("lance", nome)
	lance.add_to_group("lances_de_cerca")
	parent.add_child(lance)
	lance.global_transform = Transform3D(base_do_lance(de, ate), de.lerp(ate, 0.5))
	var comprimento := de.distance_to(ate)
	if tripo:
		var cerca := instanciar("cerca", lance, Vector3(0.0, -0.06, 0.0), tamanho)
		if cerca != null:
			cerca.scale.x *= comprimento / largura_do_lance
			var corpo := StaticBody3D.new()
			corpo.name = nome_da_colisao
			var forma := CollisionShape3D.new()
			var caixa := BoxShape3D.new()
			caixa.size = Vector3(comprimento, altura, grossura)
			forma.shape = caixa
			corpo.add_child(forma)
			lance.add_child(corpo)
			corpo.position = Vector3(0.0, altura * 0.5, 0.0)
			return lance
	# A cerca procedural começa na ponta e vai pelo +X dela; o espaçamento é o
	# que faz os mourões fecharem o comprimento.
	var mouroes := maxf(ceilf(comprimento / 1.65), 1.0)
	var cerca_proc := FloraReconcavo.cerca(comprimento, comprimento / mouroes - 0.0001)
	lance.add_child(cerca_proc)
	cerca_proc.position = Vector3(-comprimento * 0.5, -0.04, 0.0)
	return lance


## A peça barra o braço da câmera? Pela chave "camera" do catálogo; sem ela,
## barra o que é construção ("caixa" num GLB de `construcoes/` ou `casas/`),
## para a casa nova do lote entrar barrando sem ninguém lembrar dela.
static func barra_camera(chave: String) -> bool:
	if not PECAS.has(chave):
		return false
	var spec: Dictionary = PECAS[chave]
	if spec.has("camera"):
		return bool(spec["camera"])
	var arquivo := String(spec.get("tripo", ""))
	return bool(spec.get("caixa", false)) and (arquivo.begins_with("construcoes/") or arquivo.begins_with("casas/"))


## A LAJE DA CÂMERA no píer e na ponte. A malha deles barra o corpo, mas não a
## câmera: o corrimão da ponte encolhia o braço em 24 de 72 direções. A laje,
## na altura do tabuado ("piso") e do tamanho da peça, é só da câmera — que não
## mergulha por baixo do tabuado nem no rio.
static func _laje_da_camera(chave: String, spec: Dictionary, bounds: AABB, parent: Node, origin: Vector3, yaw: float) -> void:
	if bounds.size.x <= 0.0:
		return
	var laje := StaticBody3D.new()
	laje.name = chave.capitalize() + "LajeDaCamera"
	laje.collision_layer = Camadas.CAMERA
	laje.collision_mask = 0
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(bounds.size.x, 0.2, bounds.size.z)
	forma.shape = caixa
	laje.add_child(forma)
	laje.position = origin + Vector3(0, float(spec.get("piso", 0.0)) - 0.1, 0)
	laje.rotation.y = yaw
	parent.add_child(laje, true)


## Quanto a peça posta (`bounds`, de `instanciar`) é maior que a medida do
## catálogo: o "tamanho" de quem a pôs e o ajuste do painel PERSONAGENS.
static func _escala_do_catalogo(chave: String, bounds: AABB) -> float:
	var original: Dictionary = PECAS.get(chave, {})
	if original.has("altura"):
		return bounds.size.y / maxf(float(original["altura"]), 0.001)
	if original.has("largura"):
		return maxf(bounds.size.x, bounds.size.z) / maxf(float(original["largura"]), 0.001)
	return 1.0


## A ALTURA DO CORPO, em metros, em que a pegada da caixa é tirada: acima do pé
## (o alicerce e a calçada que vazam) e abaixo do beiral.
const PEGADA_DE := 0.15
const PEGADA_ATE := 2.0
static var _pegadas: Dictionary = {}
static var _troncos: Dictionary = {}
static var _troncos_de_malha: Dictionary = {}
static var _vertices_por_malha: Dictionary = {}


## A PEGADA DA PEÇA NA ALTURA DO CORPO, em fração da caixa envolvente (Rect2 no
## plano X/Z, de 0 a 1): o que o modelo ocupa entre `PEGADA_DE` e `PEGADA_ATE`.
## A casa de taipa tem 6,5 × 5,6 de caixa e 5,4 × 5,2 de parede — o beiral
## sobrando era 0,55 m de parede invisível de cada lado. Medida uma vez.
static func pegada(chave: String) -> Rect2:
	if _pegadas.has(chave):
		return _pegadas[chave]
	var resultado := Rect2(0, 0, 1, 1)
	var medida := _em_metros(chave)
	if not medida.is_empty():
		var menor := Vector2(INF, INF)
		var maior := Vector2(-INF, -INF)
		for superficie: Dictionary in medida["superficies"]:
			var transformacao: Transform3D = superficie["transformacao"]
			for vertice: Vector3 in superficie["vertices"]:
				var p := transformacao * vertice
				if p.y < PEGADA_DE or p.y > PEGADA_ATE:
					continue
				menor = Vector2(minf(menor.x, p.x), minf(menor.y, p.z))
				maior = Vector2(maxf(maior.x, p.x), maxf(maior.y, p.z))
		var caixa: AABB = medida["caixa"]
		if is_finite(menor.x) and caixa.size.x > 0.001 and caixa.size.z > 0.001:
			var de := Vector2((menor.x - caixa.position.x) / caixa.size.x, (menor.y - caixa.position.z) / caixa.size.z)
			var ate := Vector2((maior.x - caixa.position.x) / caixa.size.x, (maior.y - caixa.position.z) / caixa.size.z)
			resultado = Rect2(de, ate - de)
	_pegadas[chave] = resultado
	return resultado


## O TRONCO MEDIDO NO MODELO, pela regra do corte (`CoqueiroCortado.medir_o_corte`):
## a faixa mais estreita entre a raiz e a copa. Devolve {"centro": o pé do eixo
## no espaço do modelo (o de `instanciar`, antes da escala), "meia_largura" em
## metros na medida do catálogo, "eixo": o desvio em metros do meio da caixa},
## ou {} sem GLB. O cilindro do lampião ficava 0,43 m ao lado do poste porque
## era posto no meio da caixa, que inclui o braço da lanterna.
static func tronco(chave: String, escala: float = 1.0) -> Dictionary:
	# A regra do corte olha faixas de altura em metros (a raiz larga sobe um palmo
	# acima do chão): a árvore de tamanho 1,6 não tem o mesmo tronco "mais
	# estreito" que a de tamanho 1. Mede-se na escala em que ela está posta, em
	# passos de 0,05 para o cache.
	var passo := snappedf(escala, 0.05)
	var registro := "%s@%.2f" % [chave, passo]
	if _troncos.has(registro):
		return _troncos[registro]
	var resultado := {}
	var medida := _em_metros(chave, passo)
	if not medida.is_empty():
		var corte: Dictionary = CoqueiroCortado.medir_o_corte(medida["superficies"], Vector3.ZERO)
		if is_finite(float(corte["tronco"])):
			var eixo: Vector2 = corte["eixo"]
			var para_o_modelo: Transform3D = (medida["em_metros"] as Transform3D).affine_inverse()
			resultado = {"centro": para_o_modelo * Vector3(eixo.x, 0.0, eixo.y), "meia_largura": float(corte["tronco"]), "eixo": eixo}
	_troncos[registro] = resultado
	return resultado


## O PÉ DO TRONCO NUMA MALHA DA MATA, no espaço da malha (Vector3.INF quando
## não há tronco). É o `tronco` para quem planta por MultiMesh e só tem a
## malha e a transformação de uma instância (`exemplo`, que dá a escala em
## metros): o conjunto de troncos do `GeoRegionRenderer` põe o cilindro aqui, e
## não no ponto de plantio, que é o meio da copa. Medido uma vez por malha.
static func tronco_da_malha(malha: Mesh, exemplo: Transform3D) -> Vector3:
	if malha == null:
		return Vector3.INF
	# Uma medida por malha e por faixa de tamanho (passos de 8%, no máximo uns
	# sete por malha): a regra do corte olha faixas de altura em metros, e a
	# árvore grande não tem o tronco "mais estreito" no mesmo lugar que a
	# pequena (a jequitibá, de raiz tabular, errava um metro). Medir uma por
	# árvore custaria o plantio inteiro. A rotação não conta: o resultado volta
	# ao espaço da malha.
	var tamanho := maxf(exemplo.basis.get_scale().y, 0.001)
	var chave := "%d@%d" % [malha.get_instance_id(), roundi(log(tamanho) / log(1.08))]
	if _troncos_de_malha.has(chave):
		return _troncos_de_malha[chave]
	var giro := Transform3D(exemplo.basis, Vector3.ZERO)
	var limites_da_malha := malha.get_aabb()
	var pe := giro * Vector3(limites_da_malha.get_center().x, limites_da_malha.position.y, limites_da_malha.get_center().z)
	# Os vértices lidos uma vez por malha: `surface_get_arrays` copia tudo.
	var id_da_malha := malha.get_instance_id()
	if not _vertices_por_malha.has(id_da_malha):
		var lidos: Array[PackedVector3Array] = []
		for s in malha.get_surface_count():
			lidos.append(malha.surface_get_arrays(s)[Mesh.ARRAY_VERTEX])
		_vertices_por_malha[id_da_malha] = lidos
	var superficies: Array[Dictionary] = []
	for vertices: PackedVector3Array in _vertices_por_malha[id_da_malha]:
		superficies.append({"transformacao": giro, "vertices": vertices})
	var corte: Dictionary = CoqueiroCortado.medir_o_corte(superficies, pe)
	var resultado := Vector3.INF
	if is_finite(float(corte["tronco"])):
		var eixo: Vector2 = corte["eixo"]
		resultado = giro.affine_inverse() * (pe + Vector3(eixo.x, 0.0, eixo.y))
	_troncos_de_malha[chave] = resultado
	return resultado


## Os vértices do modelo em metros, na medida do catálogo e com o pé no meio da
## caixa (como `instanciar` o põe com tamanho 1 e sem giro): {"superficies",
## "em_metros" (do espaço do modelo para metros), "caixa" (em metros)}.
static func _em_metros(chave: String, escala: float = 1.0) -> Dictionary:
	var scene := cena(chave)
	if scene == null:
		return {}
	var spec: Dictionary = AjustesConteudo.peca(chave)
	var node := scene.instantiate() as Node3D
	var bounds := limites(node)
	var factor := 1.0
	if spec.has("altura"):
		factor = float(spec["altura"]) / maxf(bounds.size.y, 0.001)
	elif spec.has("largura"):
		factor = float(spec["largura"]) / maxf(maxf(bounds.size.x, bounds.size.z), 0.001)
	factor *= escala
	var em_metros := Transform3D(Basis().scaled(Vector3.ONE * factor), -Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * factor)
	var superficies: Array[Dictionary] = []
	for filho in node.find_children("*", "MeshInstance3D", true, false):
		var instancia := filho as MeshInstance3D
		if instancia.mesh == null:
			continue
		var transformacao := em_metros * _relativa(node, instancia)
		for s in instancia.mesh.get_surface_count():
			superficies.append({"transformacao": transformacao, "vertices": instancia.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]})
	node.free()
	return {"superficies": superficies, "em_metros": em_metros, "caixa": em_metros * bounds}


## Malha + transformação-base para usar o modelo do Tripo em MultiMesh (mata, orla, itens).
## Devolve {} quando o GLB não existe.
static func malha(chave: String, size: float = 1.0) -> Dictionary:
	var cache_key := "%s@%.3f" % [chave, size]
	if _malhas.has(cache_key):
		return _malhas[cache_key]
	var scene := cena(chave)
	if scene == null:
		return {}
	var node := scene.instantiate() as Node3D
	var instances: Array = node.find_children("*", "MeshInstance3D", true, false)
	if instances.is_empty():
		node.free()
		return {}
	# Medidas com os ajustes do painel PERSONAGENS por cima (ajustes_conteudo.gd).
	var spec: Dictionary = AjustesConteudo.peca(chave)
	if spec.has("girar"):
		# O mesmo giro de `instanciar`: a medida e a transformação-base saem do modelo
		# já deitado/virado (o peixe do cardume nada de cabeça no -Z).
		var girado := Node3D.new()
		var graus: Array = spec["girar"]
		node.rotation_degrees = Vector3(float(graus[0]), float(graus[1]), float(graus[2]))
		girado.add_child(node)
		node = girado
	var bounds := limites(node)
	var factor := 1.0
	if spec.has("altura"):
		factor = float(spec["altura"]) * size / maxf(bounds.size.y, 0.001)
	else:
		factor = float(spec["largura"]) * size / maxf(maxf(bounds.size.x, bounds.size.z), 0.001)
	var base := Transform3D(Basis().scaled(Vector3.ONE * factor), -Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * factor)
	if instances.size() == 1:
		# Uma malha só (caso dos GLBs do Tripo): usa a malha importada, que traz os LODs
		# gerados pelo importador — fundir com SurfaceTool os perderia.
		var unica := instances[0] as MeshInstance3D
		var resultado := {"mesh": unica.mesh, "base": base * _relativa(node, unica), "altura": bounds.size.y * factor, "tronco": float(spec.get("tronco", 0.3)) * size}
		_malhas[cache_key] = resultado
		node.free()
		return resultado
	# Funde todas as MeshInstance3D numa ArrayMesh única, já com a transformação relativa.
	var merged := ArrayMesh.new()
	for instance in instances:
		var mesh_instance := instance as MeshInstance3D
		var relative: Transform3D = _relativa(node, mesh_instance)
		for surface in range(mesh_instance.mesh.get_surface_count()):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			tool.append_from(mesh_instance.mesh, surface, relative)
			var material := mesh_instance.get_active_material(surface)
			if material != null:
				tool.set_material(material)
			tool.commit(merged)
	var result := {"mesh": merged, "base": base, "altura": bounds.size.y * factor, "tronco": float(spec.get("tronco", 0.3)) * size}
	_malhas[cache_key] = result
	node.free()
	return result


static func limites(node: Node3D) -> AABB:
	var combined := AABB()
	var has_bounds := false
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		var relative: Transform3D = _relativa(node, mesh_instance)
		var bounds := relative * mesh_instance.get_aabb()
		combined = combined.merge(bounds) if has_bounds else bounds
		has_bounds = true
	return combined


## Transformação de `child` no espaço de `root`, sem depender de estar na árvore de cena.
static func _relativa(root: Node3D, child: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = child
	while current != null and current != root:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result


static func relatorio_faltando() -> String:
	if faltando.is_empty():
		return ""
	return "Peças Tripo ainda não exportadas: " + ", ".join(faltando)
