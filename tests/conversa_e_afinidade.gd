extends SceneTree
var falhas := 0

func _initialize() -> void:
	_run.call_deferred()

func conferir(ok: bool, texto: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA: " + texto)

func _run() -> void:
	var afinidade := root.get_node("Afinidade")
	var idioma = load("res://scripts/prototipo_3d/idioma_menu.gd")
	var npc = load("res://scripts/prototipo_3d/npc.gd")
	var textos: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogos/afinidade_3d.json"))
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs_3d.json"))
	var vistos := 0
	for ficha: Dictionary in dados.moradores:
		var id := str(ficha.id)
		if not textos.has(id): continue
		vistos += 1
		var pessoa = npc.new()
		pessoa.dados = ficha
		for lingua in [0, 1, 2]:
			idioma.definir(lingua)
			for pontos in [0, 9, 10, 30, 59, 60, 100, 120]:
				afinidade.restaurar({"pontos": {id: pontos}})
				pessoa._alternar_relacao = false
				pessoa._proxima_fala = 0
				pessoa._humor_da_conversa = ""
				var antes: String = pessoa._escolher_a_conversa().texto
				var depois: Dictionary = pessoa._escolher_a_conversa()
				var grau := "amigo" if pontos >= 60 else "conhecido" if pontos >= 10 else ""
				if grau != "":
					conferir(antes == str(idioma.campo(textos[id][grau], "texto", "")), "%s %s %d não reage ao vínculo" % [id, lingua, pontos])
					conferir(depois.texto == str(idioma.campo(ficha.falas[0], "texto", "")), "a prosa original sumiu: " + id)
					var original := str(ficha.falas[0].get("audio", ""))
					if original != "": conferir(depois.voz is AudioStream, "a voz original sumiu: " + id)
				else:
					conferir(antes == str(idioma.campo(ficha.falas[0], "texto", "")), "desconhecido perde a apresentação: " + id)
		pessoa.free()
	conferir(vistos == 7, "faltam moradores originais")
	idioma.definir(0)
	print("CONVERSA_E_AFINIDADE: %d falha(s)" % falhas)
	quit(1 if falhas else 0)
