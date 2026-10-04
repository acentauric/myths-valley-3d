extends RefCounted
## A CAPA DE CADA CORDEL: a xilogravura desenhada para ele, ou o bloco de sempre.
##
## A desenhada é uma imagem por folheto, gerada sob pedido pelo
## `tools/openai/gerar-capas-cordeis.ps1` (geração paga) e posta em
## `assets/prototipo_3d/cordeis/<id>.jpg` depois de conferida
## (`tools/openai/promover_capas.gd`). Enquanto ela não
## vem, a capa é o BLOCO DE SEMPRE: a gravura única que as tipografias de
## folheto usavam para dezenas de histórias — o cabra de chapéu de couro servia
## ao cangaceiro, ao valente da peleja e ao herói que foi à fazenda, sem
## ninguém achar ruim. O bloco era caro; a história, não.
##
## O folheto aberto na tela (`scripts/ui/folheto.gd`) e o folheto pendurado no
## barbante do vale (`achados_vale.gd`) pedem a capa aqui, e mostram a mesma.

const PASTA := "res://assets/prototipo_3d/cordeis/"
const PAPEL := Color(0.88, 0.82, 0.63)
const TINTA := Color(0.15, 0.12, 0.09)

## O bloco: cada caractere é um ponto, tinta no "#" e papel no ".".
const GRAVURA := [
	"................",
	"......####......",
	".....######.....",
	"...##########...",
	"..############..",
	"......####......",
	"......####......",
	".....######.....",
	"...##########...",
	"..###.####.###..",
	"..##..####..##..",
	"..##..####..##..",
	"......####......",
	".....##..##.....",
	".....##..##.....",
	"....###..###....",
	"................",
	".##############.",
]

static var _bloco: Texture2D


## A capa desenhada deste cordel, ou null enquanto ela não vier.
static func desenhada(id: String) -> Texture2D:
	if id == "":
		return null
	for extensao in [".jpg", ".png"]:
		var caminho: String = PASTA + id + extensao
		if ResourceLoader.exists(caminho):
			return load(caminho) as Texture2D
	return null


## A capa a mostrar: a desenhada, ou o bloco de sempre.
static func textura(id: String) -> Texture2D:
	var propria := desenhada(id)
	return propria if propria != null else bloco()


## O BLOCO DE SEMPRE impresso em papel de folheto, na proporção da capa (2 por
## 3): moldura grossa de tinta, um filete de papel e o cabra no meio.
static func bloco() -> Texture2D:
	if _bloco != null:
		return _bloco
	var largura := 256
	var altura := 384
	var imagem := Image.create(largura, altura, false, Image.FORMAT_RGBA8)
	imagem.fill(PAPEL)
	var borda := 14
	imagem.fill_rect(Rect2i(0, 0, largura, altura), TINTA)
	imagem.fill_rect(Rect2i(borda, borda, largura - borda * 2, altura - borda * 2), PAPEL)
	var filete := borda + 8
	imagem.fill_rect(Rect2i(filete, filete, largura - filete * 2, 3), TINTA)
	imagem.fill_rect(Rect2i(filete, altura - filete - 3, largura - filete * 2, 3), TINTA)
	imagem.fill_rect(Rect2i(filete, filete, 3, altura - filete * 2), TINTA)
	imagem.fill_rect(Rect2i(largura - filete - 3, filete, 3, altura - filete * 2), TINTA)
	# O cabra, centrado no campo de dentro.
	var colunas: int = GRAVURA[0].length()
	var linhas: int = GRAVURA.size()
	var campo := Rect2i(filete + 14, filete + 14, largura - (filete + 14) * 2, altura - (filete + 14) * 2)
	var ponto := mini(campo.size.x / colunas, campo.size.y / linhas)
	var origem := campo.position + (campo.size - Vector2i(ponto * colunas, ponto * linhas)) / 2
	for linha in linhas:
		for coluna in colunas:
			if GRAVURA[linha][coluna] == "#":
				imagem.fill_rect(Rect2i(origem.x + coluna * ponto, origem.y + linha * ponto, ponto, ponto), TINTA)
	_bloco = ImageTexture.create_from_image(imagem)
	return _bloco
