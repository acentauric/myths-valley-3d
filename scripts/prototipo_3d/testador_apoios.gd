extends RefCounted
## O que o modal do botão TESTAR precisa saber e montar, sem desenho nenhum: quais apoios
## existem na máquina (Determinístico, Jev, GPT), por que um deles está desligado, o que
## foi a última sessão e os argumentos que a ponte `tools/jev/jogar.py` recebe.
##
## A detecção é a própria ponte (`--detectar`): ela é quem lê o `.env`, e só devolve se a
## chave EXISTE e se o endpoint atende, nunca o valor. O jogo não lê chave nenhuma.

const Identidade = preload("res://scripts/prototipo_3d/identidade.gd")
const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")

const PONTE := "res://tools/jev/jogar.py"
const ORCAMENTO_PADRAO := 0.10
const ORCAMENTO_TETO := 0.50
## Frase do motivo, por chave da ponte. As frases são as chaves de tradução do menu.
const MOTIVOS := {
	"ok": "Disponível",
	"sem_chave_typesafe": "Sem chave TypeSafe no .env",
	"sem_chave_openai": "Sem chave da OpenAI no .env",
	"sem_rede": "O serviço não respondeu. Confira a conexão.",
}


## A ponte e o projeto de desenvolvimento estão aqui? Nas exportações não estão.
static func ponte_instalada() -> bool:
	return FileAccess.file_exists(PONTE) and FileAccess.file_exists("res://project.godot")


## Pergunta à ponte. Sem Python ou com saída que não é JSON, devolve só o determinístico
## ligado e `erro` verdadeiro: o testador local não depende de nada disso.
static func detectar() -> Dictionary:
	var saida: Array = []
	var codigo := OS.execute("python", PackedStringArray([ProjectSettings.globalize_path(PONTE), "--detectar"]), saida, false)
	if codigo == 0 and not saida.is_empty():
		return interpretar(String(saida[0]))
	return interpretar("")


## Separado de `detectar` para o portão: transforma o texto da ponte no que o modal usa.
static func interpretar(texto: String) -> Dictionary:
	var linhas := texto.strip_edges().split("\n", false)
	var dados: Variant = JSON.parse_string(linhas[linhas.size() - 1]) if not linhas.is_empty() else null
	var base := {
		"apoios": {
			"deterministic": {"disponivel": true, "motivo": "ok"},
			"jev": {"disponivel": false, "motivo": "sem_rede"},
			"gpt": {"disponivel": false, "motivo": "sem_rede"},
		},
		"orcamento": {"padrao": ORCAMENTO_PADRAO, "teto": ORCAMENTO_TETO},
		"ultima_sessao": null,
		"erro": true,
	}
	if not (dados is Dictionary) or not (dados as Dictionary).has("apoios"):
		return base
	var apoios: Dictionary = (dados as Dictionary)["apoios"]
	for nivel in ["jev", "gpt"]:
		var item: Variant = apoios.get(nivel, {})
		if item is Dictionary:
			base["apoios"][nivel] = {"disponivel": bool(item.get("disponivel", false)), "motivo": str(item.get("motivo", "sem_rede"))}
	var orcamento: Variant = (dados as Dictionary).get("orcamento", {})
	if orcamento is Dictionary:
		base["orcamento"] = {"padrao": float(orcamento.get("padrao", ORCAMENTO_PADRAO)), "teto": float(orcamento.get("teto", ORCAMENTO_TETO))}
	var ultima: Variant = (dados as Dictionary).get("ultima_sessao", null)
	base["ultima_sessao"] = ultima if ultima is Dictionary else null
	base["erro"] = false
	return base


## O texto do motivo no idioma do menu.
static func motivo(chave: String) -> String:
	return TranslationServer.translate(MOTIVOS.get(chave, MOTIVOS["sem_rede"]))


## Os argumentos da ponte para o que o modal marcou. O orçamento só vai com um apoio pago
## marcado, e nunca passa do teto autorizado; duração zero é "sem limite".
static func argumentos(jev: bool, gpt: bool, orcamento: float, minutos: int, godot: String, continuar := false) -> PackedStringArray:
	var args := PackedStringArray([ProjectSettings.globalize_path(PONTE), "--robot",
		"--seconds", str(maxi(0, minutos) * 60), "--godot", godot])
	# Retomar a última sessão de onde parou (#235): o mesmo perfil isolado e a mesma vaga.
	if continuar:
		args.append("--continuar")
	if jev:
		args.append("--apoio-jev")
	if gpt:
		args.append("--apoio-gpt")
	if jev or gpt:
		args.append_array(["--budget", "%.2f" % clampf(orcamento, 0.01, ORCAMENTO_TETO)])
	return args


## AS OPÇÕES DO MODAL ENTRE UM TESTE E OUTRO (#235), em `user://preferencias_visuais.cfg`,
## seção [testador]: jev, gpt, orcamento, duracao_min e continuar. `orcamento` é null sem nada
## guardado (vale o padrão da ponte).
const SECAO := "testador"


static func preferencias() -> Dictionary:
	var arquivo := ConfigFile.new()
	var ok := arquivo.load(IdiomaMenu.ARQUIVO) == OK
	var ler := func(chave: String, padrao: Variant) -> Variant:
		return arquivo.get_value(SECAO, chave, padrao) if ok else padrao
	var orcamento: Variant = ler.call("orcamento", null)
	return {"jev": bool(ler.call("jev", false)), "gpt": bool(ler.call("gpt", false)),
		"orcamento": float(orcamento) if orcamento != null else null,
		"duracao_min": maxi(0, int(ler.call("duracao_min", 0))), "continuar": bool(ler.call("continuar", true))}


static func guardar_preferencias(jev: bool, gpt: bool, orcamento: float, duracao_min: int, continuar: bool) -> void:
	var arquivo := ConfigFile.new()
	arquivo.load(IdiomaMenu.ARQUIVO)
	arquivo.set_value(SECAO, "jev", jev)
	arquivo.set_value(SECAO, "gpt", gpt)
	arquivo.set_value(SECAO, "orcamento", snappedf(clampf(orcamento, 0.01, ORCAMENTO_TETO), 0.01))
	arquivo.set_value(SECAO, "duracao_min", maxi(0, duracao_min))
	arquivo.set_value(SECAO, "continuar", continuar)
	if arquivo.save(IdiomaMenu.ARQUIVO) != OK:
		push_warning("Não foi possível guardar as opções do testador.")


## A linha da última sessão para o modal reaberto: "43,5% · O mirante 2/6 · 412 ações".
static func resumo_da_ultima(sessao: Variant) -> String:
	if not (sessao is Dictionary):
		return ""
	var s: Dictionary = sessao
	var percentual := numero(float(s.get("percentual", 0.0)), 1)
	var acoes: String = TranslationServer.translate("%d ações") % int(s.get("acoes", 0))
	if str(s.get("capitulo", "")) == "":
		return "%s%% · %s" % [percentual, acoes]
	return "%s%% · %s %d/%d · %s" % [percentual, str(s.get("capitulo", "")),
		int(s.get("capitulo_feitos", 0)), int(s.get("capitulo_total", 0)), acoes]


## Número com a vírgula decimal do português e do espanhol, e o ponto do inglês.
static func numero(valor: float, casas: int) -> String:
	var texto := String.num(valor, casas)
	return texto.replace(".", ",") if IdiomaMenu.indice() in [0, 2] else texto


## A barra de quanto da história já foi jogada: trilha clara e preenchimento em ouro, a
## mesma do modal e do painel da sessão.
static func barra(percentual: float, altura := 8.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.min_value = 0.0
	b.max_value = 100.0
	b.value = clampf(percentual, 0.0, 100.0)
	b.custom_minimum_size = Vector2(0.0, altura)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(1.0, 0.94, 0.82, 0.14)
	fundo.set_corner_radius_all(3)
	var cheio := StyleBoxFlat.new()
	cheio.bg_color = Identidade.OURO
	cheio.set_corner_radius_all(3)
	b.add_theme_stylebox_override("background", fundo)
	b.add_theme_stylebox_override("fill", cheio)
	return b
