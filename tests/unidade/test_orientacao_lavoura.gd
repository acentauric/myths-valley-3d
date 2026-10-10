extends "res://tests/unidade/base.gd"
## Orientação da lavoura: o aviso certo para cada etapa (arar, plantar, regar).
##
##     .\tools\prototipo_3d\testar.ps1 -Teste orientacao_lavoura
const Idioma = preload("res://scripts/prototipo_3d/idioma_menu.gd")


class Avisos extends Node:
	var _notice := ""
	func set_notice(texto: String, _segundos: float = -1.0) -> void:
		_notice = texto


func equipar(inv: Node, item: String) -> void:
	if not inv.tem(item): inv.adicionar(item, 4)
	for i in inv.ESPACOS_MAO:
		if not inv.vazio(i) and inv.espacos[i].get("id", "") == item:
			inv.selecionar(i)
			return


func test_orientacao_lavoura() -> void:
	await process_frame
	var inv := root.get_node("Inventario")
	var lav = load("res://scripts/prototipo_3d/lavoura_vale.gd").new()
	var avisos := Avisos.new()
	pendurar(avisos)
	lav._hud = avisos
	lav._textos = JSON.parse_string(FileAccess.get_file_as_string(lav.TEXTOS))
	lav.plantacao = load("res://scripts/prototipo_3d/plantacao.gd").new(func(_p): return true)
	var fila = load("res://scripts/prototipo_3d/cadeia_de_missoes.gd").new()
	fila.carregar("res://data/missoes_guia.json")
	lav.arou.connect(func(): fila.registrar_evento("arou"))
	lav.plantou.connect(func(): fila.registrar_evento("plantou"))
	lav.regou.connect(func(): fila.registrar_evento("regou"))
	if "--falsificar" in OS.get_cmdline_user_args():
		for dica in lav._textos["orientacao"].values():
			for campo in ["texto", "texto_en", "texto_es"]:
				dica[campo] = "%s ".repeat(str(dica[campo]).count("%s"))
	var leito := Vector2i(1, 1)
	var passo: Dictionary
	for s in fila.passos:
		if s.id == "roca": passo = s
	var energia := root.get_node("Energia")
	energia.definir(100)
	equipar(inv, "semente_mandioca")
	equipar(inv, "enxada")
	lav.usar(leito)
	conferir(fila.resumo_do_passo(passo).contains("● Arar") and fila.resumo_do_passo(passo).contains("○ Plantar"), "resumo distingue as etapas")
	lav.usar(leito)
	conferir(avisos._notice.contains("plantar") and not lav.acao(leito) == "Arar", "repetir arar orienta plantar, inclusive no E")
	var uma_vez := avisos._notice
	lav.usar(leito)
	conferir(avisos._notice == uma_vez, "repetir aviso nao acumula texto")
	equipar(inv, "semente_mandioca")
	lav.usar(leito)
	conferir(avisos._notice == "" and lav._tentativas_vazias == 0, "progresso retira ajuda")
	equipar(inv, "balde")
	equipar(inv, "enxada")
	conferir(lav.orientacao(leito).contains("regar"), "plantado orienta balde")
	conferir(lav.alvo_da_etapa("regou", lav.posicao_da(leito)).distance_to(lav.posicao_da(leito)) < 0.01, "marcador aponta a leira plantada ainda seca")
	equipar(inv, "balde")
	lav.usar(leito)
	conferir(fila.resumo_do_passo(passo).contains("● Regar") and lav.orientacao(leito).contains("amanhecer"), "regado orienta esperar")
	var b := Vector2i(2, 1)
	lav.plantacao.arar(b)
	inv.consumir("semente_mandioca", inv.quantidade("semente_mandioca"))
	conferir(lav.orientacao(b).contains("Falta") and lav.orientacao(b).contains("Mochila"), "item ausente mostra onde procurar")
	avisos._notice = ""
	lav._retomou_progresso()
	lav._acompanhar_orientacao(60, b, false)
	conferir(avisos._notice == "", "parado nao presume perdido")
	lav._acompanhar_orientacao(26, b, true)
	conferir(avisos._notice.contains("Falta"), "atividade sem progresso mostra ajuda")
	avisos._notice = "outro aviso"
	lav._retomou_progresso()
	conferir(avisos._notice == "outro aviso", "retomada preserva aviso de outro dono")
	for idioma in [1, 2]:
		Idioma.definir(idioma)
		conferir(lav.orientacao(b).contains("need" if idioma == 1 else "Falta"), "ajuda traduzida")
		var etapas: String = fila.resumo_do_passo(passo)
		conferir(etapas.contains("Till" if idioma == 1 else "Sembrar"), "etapas traduzidas")
	Idioma.definir(0)
	lav.free()
	fila.free()
