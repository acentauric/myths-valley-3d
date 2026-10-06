extends Node
## LUGARES: traduz NOME DE LUGAR em posição — o lado 3D da costura.
##
## Mesmo contrato do `Lugares` do jogo 2D (`scripts/autoload/lugares.gd` na
## raiz), com uma diferença só: lá `ponto()` devolve `Vector2`, aqui devolve
## `Vector3`. Quem chama não vê a diferença, e é isso que deixa a campanha
## escrita para o 2D rodar aqui sem reescrita.
##
## Ver docs/projeto/MIGRACAO_2D_3D.md, Fase 1.
##
##
## O NOME É O CONTRATO; A ÂNCORA É A IMPLEMENTAÇÃO
##
## O `world_builder` já nomeia os lugares do vale — "Praça", "Igreja", "Pier",
## "Roçado" — em `ancoras`, com acento e maiúscula, porque são nomes de lugar
## de verdade, escritos para gente ler. O contrato usa a forma sem acento e em
## minúscula, porque ele é chave de dado: entra em JSON de missão, em save, em
## arquivo de fala.
##
## `DE_PARA` é a ponte entre as duas formas. Ela é a peça que um dia vai
## crescer: hoje cobre o que o vale tem, e a Fase 2.5 acrescenta uma linha por
## lugar novo — a chapada, o vau, a lagoa, a fazenda.
##
##
## O QUE ACONTECE COM NOME QUE O VALE AINDA NÃO TEM
##
## Devolve `NENHUM`, e nada quebra. É de propósito, e é a mesma escolha do
## `CatalogoAssets` para peça não exportada: o sistema roda com o lugar
## ausente, a bússola some, e o dia em que a região crescer o nome passa a
## resolver sem ninguém tocar em missão nenhuma.
##
## Enquanto a Fase 2.5 não chega, é assim que metade da campanha do 2D
## convive com um vale que só tem a vila.

const NENHUM := Vector3.INF

## NOME DO CONTRATO → nome da âncora no `world_builder`.
const DE_PARA := {
	"praca": "Praça",
	"igreja": "Igreja",
	"capela": "Igreja",
	"venda": "Venda do Bar",
	"bar": "Bar",
	"casa_de_pasto": "Restaurante",
	"pier": "Pier",
	"ponte_da_vila": "Ponte",
	# O RIO GRANDE é o rio do norte do mapa, fundo e com barranco na margem norte
	# (#81), e a ponte dele é a "Ponte" do KML, onde a Rua Principal o cruza:
	# cercada até a primeira obra do jogo (`ponte_vale.gd`, data/missoes_ponte.json).
	# Fora dela ninguém passa; o vau que havia ao lado acabou.
	"ponte_do_rio_grande": "Ponte",
	# A CHAPADA DO SEU BENEDITO, a terra alta para lá da Dona Zefa, de frente para o
	# rio grande (data/missoes_chapada.json, `world_builder._build_farm`).
	"expansao": "Chapada",
	# A LOMBADA DE PEDRA entre a casa e a chapada (`lombada_vale.gd`): a lapa no pé
	# da rampa e a cabra lá em cima (data/missoes_lombada.json).
	"lapa": "Lapa",
	"cabra_do_alto": "Cabra do alto",
	"lombada": "Lombada",
	# A FAZENDA DO CONVITE, do outro lado do rio grande (`fazenda_vale.gd`,
	# data/missoes_fazenda.json): o portão baixo e o pé da escadaria do casarão.
	"portao_da_fazenda": "Portão da fazenda",
	"patio_da_fazenda": "Pátio da fazenda",
	"casarao": "Casarão",
	"poco": "Poço",
	"mirante": "Mirante",
	"cemiterio": "Cemitério",
	# Os marcos de fé (#52): o cruzeiro diante da igreja, a capela velha da rua do
	# mirante (a "capelinha de estrada" do 2D), o terreiro e a gameleira.
	"cruzeiro": "Cruzeiro",
	"capela_estrada": "Capela velha",
	"terreiro": "Terreiro",
	"gameleira": "Gameleira",
	"rocado": "Roçado",
	# A lavoura da casa (#8), na frente dela: onde se planta.
	"lavoura": "Lavoura",
	"horta": "Lavoura",
	"casa_de_taipa": "Casa de taipa",
	"casa_da_estrada": "Casa da estrada",
	"casa_carro_quebrado": "Casa de Carro Quebrado",
	"fogueira": "Fogueira",
	# A BANCADA DA OFICINA, provisória na beira do roçado (`bancadas_vale.gd`,
	# #11): é ali que a lenha vira tábua e corda, e a chegada manda torcer a
	# primeira corda nela. A construção de verdade é do Tripo (#27).
	"oficina": "Oficina",
	# O CANTEIRO DE OBRAS, a mesa do prumo ao lado da bancada (`bancadas_vale.gd`):
	# onde se risca a obra antes de levantar, e ela sai mais barata.
	"canteiro": "Canteiro de obras",
	"pedras": "Pedras",
	# As casas do Pedro e da Dona Zefa, abertas por dentro: o vale escolhe o lote
	# de cada um (`WorldBuilder.casas_dos_moradores`).
	"casa_do_pedro": "Casa do Pedro",
	"casa_da_zefa": "Casa da Zefa",
}

## Os nomes que a campanha do 2D usa e o vale ainda NÃO tem, com o que falta
## para cada um. Não é lista de pendência solta: o portão a lê para cobrar que
## ninguém aqui esteja escrito errado, e a Fase 2.5 esvazia esta lista movendo
## linha por linha para `DE_PARA`.
const FALTAM_NO_VALE := {
	"lagoa": "a lagoa a leste do Seu Benedito — Fase 2.5",
	"curral": "o curral — Fase 7",
}

var _mundo: Node3D = null


## O vale se apresenta ao subir. Quem chama é o `world_builder`, quando as
## âncoras já estão todas postas — antes disso o dicionário está pela metade e
## um nome resolveria para o lugar errado em vez de não resolver.
func registrar(mundo: Node3D) -> void:
	_mundo = mundo


func esquecer(mundo: Node3D = null) -> void:
	if mundo == null or mundo == _mundo:
		_mundo = null


func tem_mundo() -> bool:
	return is_instance_valid(_mundo)


## O contrato conhece o nome? Conhece tanto o que resolve quanto o que ainda
## falta — nome que falta é nome certo num vale incompleto, e não erro de quem
## escreveu a missão.
func existe(nome: String) -> bool:
	var chave := _chave(nome)
	return DE_PARA.has(chave) or FALTAM_NO_VALE.has(chave)


## O nome resolve HOJE?
func resolve(nome: String) -> bool:
	return ponto(nome) != NENHUM


func nomes() -> Array:
	return DE_PARA.keys()


## NOME → POSIÇÃO no vale.
func ponto(nome: String, _detalhe: String = "") -> Vector3:
	if not is_instance_valid(_mundo):
		return NENHUM
	var chave := _chave(nome)
	if not DE_PARA.has(chave):
		# Silêncio para o que se sabe que falta; aviso só para o que ninguém
		# declarou. Avisar sobre os treze conhecidos encheria o console a cada
		# missão e ensinaria a ignorar o aviso — que é como um aviso de
		# verdade se perde.
		if not FALTAM_NO_VALE.has(chave):
			push_warning("Lugares: nome desconhecido '%s'." % nome)
		return NENHUM

	var ancora: String = DE_PARA[chave]
	if not _mundo.ancoras.has(ancora):
		return NENHUM
	return _mundo.ancoras[ancora]


func pontos(lista: Array) -> Array:
	var saida := []
	for nome in lista:
		var p := ponto(str(nome))
		if p != NENHUM:
			saida.append(p)
	return saida


## Perto o bastante? O 3D mede em unidades de 4 m, e quem pergunta é a missão:
## "chegou no píer?". No 2D a mesma pergunta é feita em pixels — por isso ela
## mora aqui, e não no código de missão.
func perto_de(nome: String, quem: Node3D, raio: float) -> bool:
	if not is_instance_valid(quem):
		return false
	var p := ponto(nome)
	if p == NENHUM:
		return false
	var d := quem.global_position - p
	d.y = 0.0
	return d.length() <= raio


func _chave(nome: String) -> String:
	var corte := nome.find(":")
	return nome if corte < 0 else nome.substr(0, corte)
