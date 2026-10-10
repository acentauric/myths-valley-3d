extends "res://tests/suite/caso.gd"
## Contrato local do roteiro: apresentações, caderneta e cabra (#65).
var falhas := 0
func _initialize() -> void:
	_run.call_deferred()
func conferir(ok: bool, texto: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA: " + texto)
func _run() -> void:
	change_scene_to_file("res://scenes/prototipo_3d/vale.tscn")
	await process_frame
	while get_first_node_in_group("mundo") == null or not get_first_node_in_group("mundo").construido:
		await process_frame
	for i in range(8):
		await process_frame
	var vale = current_scene
	for fila in get_nodes_in_group("cadeias_de_missoes"):
		fila.set_physics_process(false)
	var guia = vale.pedro._cadeia
	var ids: Array = []
	for passo in guia.passos:
		ids.append(str(passo.id))
	var ultimo := -1
	# Não exige a cópia do 2D: declara a ordem do roteiro vigente no 3D.
	for id in ["desembarque", "bom_dia", "chave", "chave_zefa", "casa", "pegar", "caderneta", "roca"]:
		var indice: int = ids.find(id)
		conferir(indice > ultimo, "a chegada conserva a ordem de %s" % id)
		ultimo = indice
	for par in [["bom_dia", "tonho"], ["chave", "candinha"], ["chave_zefa", "zefa"]]:
		var passo: Dictionary = guia.passos[ids.find(par[0])]
		conferir(bool(passo.get("conduz", false)) and str(passo.meta.tipo) == "falar" and str(passo.meta.a_quem) == par[1],
			"Pedro conduz a apresentação de %s e espera a interação" % par[1])
	guia.iniciado = true
	guia.missao = ids.find("caderneta")
	var caderneta: Dictionary = guia.passo_atual()
	if "--sem-caderneta" in OS.get_cmdline_user_args():
		caderneta["meta"] = {}
	conferir(str(caderneta.get("meta", {}).get("evento", "")) == "abriu_painel", "a caderneta pede a abertura real do painel")
	conferir(guia.falta_a_meta(caderneta), "antes de abrir J, a caderneta espera")
	vale.hud.quests_requested.emit()
	await process_frame
	conferir(vale.painel.aberto and guia.aconteceu("abriu_painel"), "o botão real abre o painel e avisa a cadeia")
	conferir(not guia.falta_a_meta(caderneta), "a abertura real cumpre a caderneta")
	var lombada = vale._cadeias["pedro_lombada"]
	conferir(lombada.dono == vale.pedro, "Pedro conduz a frente da cabra")
	var rota: Array = []
	for passo in lombada.passos:
		rota.append(str(passo.id))
	conferir(rota == ["picareta", "cabra", "cabra_volta"], "a passagem abre antes da cabra e a história volta ao Pedro")
	conferir(str(lombada.passos[0].meta.get("alvo", "")) == "lapa", "a abertura exige derrubar a lapa, não possuir pedras quaisquer")
	conferir(str(lombada.passos[1].get("cena", "")) == "cabra_desce", "aproximar-se dispara a descida da cabra")
	conferir(str(lombada.passos[2].meta.get("a_quem", "")) == "pedro", "o fechamento da cabra tem interlocutor")
	print("CONTINUIDADE_PEDRO: %d falhas" % falhas)
	quit(0 if falhas == 0 else 1)
