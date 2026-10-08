extends SceneTree
## Confere a COLISÃO DAS ÁRVORES NO CATÁLOGO: tronco sólido, copa que se atravessa.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/colisao_do_catalogo_das_arvores.gd
##
## "Auditar e ajustar as colisões de todas as árvores" (#150). A parte física
## (o eixo do corpo contra o tronco, o conjunto de cilindros do jogador, a rota
## dos moradores) já tem portões que montam o vale: `colisao_das_arvores`,
## `colisoes_do_vale` e `navegacao`. Este olha a FONTE DOS NÚMEROS, que é onde a
## auditoria de todas as espécies cabe sem montar o mundo: o catálogo
## (`CatalogoAssets.PECAS`) e as receitas do paisagismo, que repetem a altura e o
## raio das espécies leves.
##
## A medida que embasa os limites está em `tools/tripo/auditar_troncos.py raio`:
## o raio visível do tronco em cada GLB contra o `tronco` do catálogo. Das 32
## espécies com colisão, 29 ficam entre -0,21 e +0,32 (o corpo do jogador soma
## 0,28 ao raio); mangue, bambu e gameleira (raízes escoras, colmos, sapopemas)
## estão em `SEM_TRONCO_UNICO` com a razão. O ingazeiro também saía da faixa, por
## causa da laje de terra do GLB (#141, `tests/bases_das_arvores.gd`); sem ela dá +0,12. Ver docs/testes/COLISAO_DAS_ARVORES.md.
##
##   1. A COPA NUNCA É SÓLIDA: o cilindro de toda árvore do catálogo tem no
##      máximo 3,5 m (`tronco_altura`, 3,0 se omitido), e o raio é o do tronco,
##      não o da copa: de 0,1 a 1,0 (a gameleira, de sapopemas, é a exceção).
##   2. TODA ÁRVORE COM FICHA TEM TRONCO: espécie de `data/arvores_3d.json` que o
##      catálogo conhece (a ficha do bambu é a touceira) leva `tronco`, ou se
##      passa por dentro dela.
##   3. O PAISAGISMO REPETE O CATÁLOGO: `altura` e `raio` de cada espécie de
##      tronco das receitas conferem com a peça de mesmo nome do catálogo; sem
##      `tronco` nela (só o paisagismo planta), com a da espécie da ficha, a 0,3.
##
## FALSIFICAÇÃO: `-- --falsificar=copa` mede o limite de altura como 1,0 m;
## `-- --falsificar=receita` desvia o raio de uma espécie das receitas em 0,5.

const Catalogo = preload("res://scripts/prototipo_3d/catalogo_assets.gd")

## Altura máxima do cilindro de uma árvore: cintura e peito, nunca a copa.
const ALTURA_MAXIMA_DO_CILINDRO := 3.5
const RAIO_MINIMO := 0.1
const RAIO_MAXIMO := 1.0
const TOLERANCIA_DA_FICHA := 0.3
## Árvores cujo tronco desenhado não é um fuste só, e por isso o raio do
## catálogo cobre o miolo e não a madeira toda. A razão fica ao lado.
const SEM_TRONCO_UNICO := {
	"gameleira": "sapopemas de 4 a 5 u de raio; o tronco liso mede 1,1 a 1,9 u acima delas, e o cilindro (1,2 x a escala) cobre o tronco",
	"mangue": "raízes escoras abertas em volta do fuste",
	"touceira_bambu": "touceira de colmos, o raio cobre o miolo dela",
}

var falhas := 0
var falsificar := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--falsificar="):
			falsificar = arg.substr("--falsificar=".length())
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("COLISAO_CATALOGO_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	var arvores: Array[String] = []
	for chave: String in Catalogo.PECAS:
		var spec: Dictionary = Catalogo.PECAS[chave]
		if String(spec.get("tripo", "")).begins_with("arvores/") and spec.has("tronco"):
			arvores.append(chave)
	arvores.sort()
	_conferir(arvores.size() >= 30, "o catálogo tem árvores com colisão (achei %d)" % arvores.size())

	# --- 1. A copa nunca é sólida ----------------------------------------
	var teto := 1.0 if falsificar == "copa" else ALTURA_MAXIMA_DO_CILINDRO
	for chave in arvores:
		var spec: Dictionary = Catalogo.PECAS[chave]
		var raio := float(spec["tronco"])
		var altura := float(spec.get("tronco_altura", 3.0))
		_conferir(altura <= teto, "'%s' tem cilindro de %.1f m: passa do peito e vira parede de copa (limite %.1f)" % [chave, altura, teto])
		_conferir(raio >= RAIO_MINIMO, "'%s' tem raio %.2f: o corpo atravessa o tronco" % [chave, raio])
		if not SEM_TRONCO_UNICO.has(chave):
			_conferir(raio <= RAIO_MAXIMO, "'%s' tem raio %.2f: volume de copa, e não de tronco (limite %.1f)" % [chave, raio, RAIO_MAXIMO])
	for chave: String in SEM_TRONCO_UNICO:
		_conferir(Catalogo.PECAS.has(chave) and Catalogo.PECAS[chave].has("tronco"), "'%s' está em SEM_TRONCO_UNICO mas não tem colisão no catálogo" % chave)

	# --- 2. Toda árvore com ficha tem tronco --------------------------------
	var fichas: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/arvores_3d.json")) as Dictionary)["arvores"]
	var de_ficha := 0
	for especie: String in fichas:
		var chave := "touceira_bambu" if especie == "bambu" else especie
		if not Catalogo.PECAS.has(chave) or not String(Catalogo.PECAS[chave].get("tripo", "")).begins_with("arvores/"):
			continue
		de_ficha += 1
		_conferir(Catalogo.PECAS[chave].has("tronco"), "a árvore '%s' tem ficha e não tem colisão: passa-se por dentro dela" % especie)
	_conferir(de_ficha >= 20, "as fichas do almanaque cobrem árvores do catálogo (achei %d)" % de_ficha)

	# --- 3. O paisagismo repete o catálogo -----------------------------------
	var receitas: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/paisagismo/receitas.json"))
	var info: Dictionary = receitas["info_das_especies"]
	var de_tronco := 0
	var desviada := false
	for chave: String in info:
		if chave == "observacao" or not (info[chave] is Dictionary):
			continue
		var dados: Dictionary = info[chave]
		if not bool(dados.get("tronco", false)):
			continue
		de_tronco += 1
		var raio := float(dados["raio"])
		if falsificar == "receita" and not desviada:
			raio += 0.5
			desviada = true
		if Catalogo.PECAS.has(chave) and Catalogo.PECAS[chave].has("tronco"):
			var peca: Dictionary = Catalogo.PECAS[chave]
			_conferir(is_equal_approx(raio, float(peca["tronco"])), "'%s': a receita diz raio %.2f e o catálogo %.2f" % [chave, raio, float(peca["tronco"])])
		else:
			var ficha := String(dados.get("ficha", ""))
			var da_ficha: Dictionary = Catalogo.PECAS.get(ficha, {})
			_conferir(da_ficha.has("tronco"), "'%s': a ficha '%s' não tem colisão no catálogo para conferir o raio" % [chave, ficha])
			if da_ficha.has("tronco"):
				_conferir(absf(raio - float(da_ficha["tronco"])) <= TOLERANCIA_DA_FICHA,
					"'%s': raio %.2f na receita e %.2f na peça da ficha (limite de %.1f)" % [chave, raio, float(da_ficha["tronco"]), TOLERANCIA_DA_FICHA])
		if Catalogo.PECAS.has(chave):
			_conferir(absf(float(dados["altura"]) - float(Catalogo.PECAS[chave]["altura"])) <= 0.05,
				"'%s': a receita diz altura %.2f e o catálogo %.2f" % [chave, float(dados["altura"]), float(Catalogo.PECAS[chave]["altura"])])
	_conferir(de_tronco >= 10, "as receitas têm espécies de tronco (achei %d)" % de_tronco)

	print("")
	if falhas == 0:
		print("COLISAO_CATALOGO_OK: %d árvores com cilindro de até %.1f m e raio de tronco, %d fichas com colisão, %d espécies do paisagismo conferem com o catálogo" % [arvores.size(), teto, de_ficha, de_tronco])
	else:
		print("colisão do catálogo das árvores: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)
