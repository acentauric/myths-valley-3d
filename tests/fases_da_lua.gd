extends "res://tests/suite/caso.gd"
## AS FASES DA LUA (#229): a noite deixa de ter sempre a mesma claridade. A fase sai do dia do
## calendário num ciclo de oito dias; a lua cheia é clara, a nova é escura, o disco leva a fase, as
## luzes locais ganham força na nova e as "Noites escuras: Sim / Suaves" encolhem a diferença.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste fases_da_lua
##
##   1. A CONTA (pura, sem vale): o ciclo repete a cada oito dias e passa pelas oito fases; a iluminação
##      vai de 0 (nova) a 1 (cheia) e volta; o dia 1 não é lua nova; a energia da lua, do ambiente e das
##      luzes locais, o brilho do viajante e a sombra seguem a fase; "Suaves" encolhe sem inverter.
##   2. O AJUSTE: "Noites escuras" em Ajustes, com ajuda e tradução em inglês e espanhol, e a escolha
##      volta do arquivo de preferências.
##   3. NO VALE, À MEIA-NOITE, nas QUATRO ESTAÇÕES e nas oito fases: a energia da lua e a do ambiente
##      crescem da nova para a cheia; o shader recebe a fase; só a lua cheia faz sombra; o lampião da
##      praça brilha mais na nova que na cheia; o viajante só ganha o seu brilho nas noites escuras; de
##      dia nada disso aparece; e com "Suaves" a nova fica bem mais clara do que a escura.
##
## FALSIFICAÇÃO embutida (`-- --falsificar`): a fase passa a ser a mesma em todos os dias (como era
## antes da issue) e o portão TEM de reprovar a seção 3; se não reprovar, a régua não vale nada.

const FasesDaLua = preload("res://scripts/prototipo_3d/fases_da_lua.gd")

var falhas := 0
var falsificar := false


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA: ", rotulo)


func _run() -> void:
	falsificar = "--falsificar" in OS.get_cmdline_user_args()
	_conta()
	_ajuste()
	await _no_vale()
	FasesDaLua.definir_suaves(false)
	FasesDaLua.esquecer_a_escolha()
	if falsificar:
		print("FASES_DA_LUA_FALSIFICADO: %s" % ("o portão reprovou, como devia" if falhas > 0 else "O PORTÃO NÃO REPROVOU: a régua não vale"))
		quit(0 if falhas > 0 else 1)
		return
	print("FASES_DA_LUA_OK: ciclo de oito dias, luz por fase, disco, luzes locais, sombra da cheia e noites suaves" if falhas == 0 else "fases_da_lua: Falhas: %d" % falhas)
	quit(1 if falhas else 0)


## 1. A conta.
func _conta() -> void:
	var vistos := {}
	for dia in range(1, 17):
		var indice: int = FasesDaLua.indice_do_dia(dia)
		vistos[indice] = true
		_conferir(indice == FasesDaLua.indice_do_dia(dia + FasesDaLua.CICLO_DIAS), "o dia %d e o dia %d têm a mesma fase" % [dia, dia + FasesDaLua.CICLO_DIAS])
	_conferir(vistos.size() == FasesDaLua.CICLO_DIAS, "o ciclo passa pelas oito fases (viu %d)" % vistos.size())
	_conferir(FasesDaLua.NOMES.size() == FasesDaLua.CICLO_DIAS, "há um nome para cada fase do ciclo")
	_conferir(FasesDaLua.indice_do_dia(1) != FasesDaLua.NOVA, "o primeiro dia do jogo não cai na lua nova")
	_conferir(FasesDaLua.indice_do_dia(3) == FasesDaLua.CHEIA, "o dia 3 é de lua cheia")
	_conferir(FasesDaLua.indice_do_dia(7) == FasesDaLua.NOVA, "o dia 7 é de lua nova")
	_conferir(is_zero_approx(FasesDaLua.iluminacao(0.0)), "a lua nova não tem nada iluminado")
	_conferir(is_equal_approx(FasesDaLua.iluminacao(0.5), 1.0), "a lua cheia está toda iluminada")
	_conferir(is_equal_approx(FasesDaLua.iluminacao(0.25), 0.5), "o quarto está meio iluminado")
	_conferir(is_equal_approx(FasesDaLua.iluminacao(0.125), FasesDaLua.iluminacao(0.875)), "crescente e minguante têm a mesma iluminação")
	var nova := 0.0
	var cheia := 0.5
	for suaves in [false, true]:
		var s: bool = suaves
		_conferir(FasesDaLua.fator_da_lua(nova, s) < FasesDaLua.fator_da_lua(0.25, s) and FasesDaLua.fator_da_lua(0.25, s) < FasesDaLua.fator_da_lua(cheia, s),
			"a luz da lua cresce da nova ao quarto e à cheia (suaves %s)" % str(s))
		_conferir(FasesDaLua.fator_do_ambiente(nova, s) < FasesDaLua.fator_do_ambiente(cheia, s), "o ambiente da noite cresce da nova à cheia (suaves %s)" % str(s))
		_conferir(FasesDaLua.fator_das_luzes_locais(nova, s) > FasesDaLua.fator_das_luzes_locais(cheia, s), "as luzes locais ganham força na nova (suaves %s)" % str(s))
		_conferir(FasesDaLua.brilho_do_viajante(nova, s) > FasesDaLua.brilho_do_viajante(cheia, s), "o viajante brilha mais na nova (suaves %s)" % str(s))
	_conferir(FasesDaLua.fator_da_lua(nova, false) <= 0.3, "a lua nova dá, no máximo, 30% da luz de hoje")
	_conferir(FasesDaLua.fator_da_lua(cheia, false) >= 1.0, "a lua cheia dá a luz de hoje ou mais")
	_conferir(FasesDaLua.fator_da_lua(nova, true) > FasesDaLua.fator_da_lua(nova, false) + 0.3, "a nova suave é bem mais clara que a escura")
	_conferir(FasesDaLua.fator_da_lua(nova, true) < FasesDaLua.fator_da_lua(cheia, true), "a nova suave continua mais escura que a cheia")
	_conferir(is_equal_approx(FasesDaLua.fator_das_luzes_locais(cheia, false), 1.0), "na cheia as luzes locais ficam como sempre")
	_conferir(is_zero_approx(FasesDaLua.brilho_do_viajante(cheia, false)), "na cheia o viajante não ganha brilho")
	_conferir(FasesDaLua.brilho_do_viajante(nova, false) >= 0.5, "na nova o viajante ganha um brilho que se vê")
	_conferir(FasesDaLua.opacidade_da_sombra(cheia, 0.0) > 0.99, "a lua cheia de noite fechada faz sombra inteira")
	_conferir(is_zero_approx(FasesDaLua.opacidade_da_sombra(nova, 0.0)), "a lua nova não faz sombra")
	_conferir(is_zero_approx(FasesDaLua.opacidade_da_sombra(0.25, 0.0)), "o quarto não faz sombra")
	_conferir(is_zero_approx(FasesDaLua.opacidade_da_sombra(cheia, 1.0)), "de dia a lua não faz sombra")
	var azul_nova: Color = FasesDaLua.cor_da_luz(nova)
	var azul_cheia: Color = FasesDaLua.cor_da_luz(cheia)
	_conferir(azul_cheia.b > azul_cheia.r and azul_cheia.get_luminance() > azul_nova.get_luminance(), "a luz da cheia é azul-prateada e mais clara que a da nova")


## 2. O ajuste.
func _ajuste() -> void:
	var painel := FileAccess.get_file_as_string("res://scripts/prototipo_3d/painel_ajustes.gd")
	_conferir(painel.contains("\"Noites escuras\"") and painel.contains("FasesDaLua.ROTULOS"), "Ajustes não tem o campo 'Noites escuras'")
	_conferir(FasesDaLua.ROTULOS == ["Sim", "Suaves"], "as escolhas do ajuste não são Sim e Suaves, nessa ordem")
	var ajuda := FileAccess.get_file_as_string("res://scripts/prototipo_3d/ajuda_menu.gd")
	_conferir(ajuda.contains("\"Noites escuras\": ["), "o ajuste não tem o texto de ajuda")
	var idioma := FileAccess.get_file_as_string("res://scripts/prototipo_3d/idioma_menu.gd")
	for rotulo in ["Noites escuras", "Sim", "Suaves"] + FasesDaLua.NOMES:
		_conferir(idioma.count("\"%s\":" % rotulo) >= 2, "'%s' não está traduzido para o inglês e o espanhol" % rotulo)
	FasesDaLua.definir_suaves(true)
	FasesDaLua.esquecer_a_escolha()
	_conferir(FasesDaLua.suaves(), "a escolha 'Suaves' não voltou do arquivo de preferências")
	FasesDaLua.definir_suaves(false)
	FasesDaLua.esquecer_a_escolha()
	_conferir(not FasesDaLua.suaves(), "a escolha 'Sim' não voltou do arquivo de preferências")
	var shader := FileAccess.get_file_as_string("res://assets/prototipo_3d/ceu/ceu_vale.gdshader")
	_conferir(shader.contains("uniform float lua_fase") and shader.contains("uniform float lua_brilho"), "o shader do céu não recebe a fase da lua")


## 3. No vale.
func _no_vale() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(3)
	var mundo := get_first_node_in_group("mundo")
	_conferir(mundo != null, "o mundo existe")
	if mundo == null:
		return
	var dia := root.get_node("/root/Dia")
	var calendario := root.get_node("/root/Relogio")
	dia.pausado = true
	var ceu = mundo.get("_ceu")
	var luzes = mundo.get("_luzes")
	_conferir(ceu != null and luzes != null, "o mundo monta o céu e as luzes de 1887")
	if ceu == null or luzes == null:
		return
	FasesDaLua.definir_suaves(false)
	var estacao_de_antes: int = calendario.estacao
	var dia_de_antes: int = calendario.dia
	for estacao in 4:
		calendario.estacao = estacao
		# Uma fase por dia de 1 a 8 do mês, medida à meia-noite (fundo da noite).
		var por_fase := {}
		for d in range(1, 9):
			calendario.dia = d
			var indice: int = FasesDaLua.indice_do_dia(calendario.dia_absoluto())
			# A régua falsa: o céu sempre vê o mesmo dia (a cheia), como antes da issue em que toda
			# noite era igual; as medidas continuam sendo guardadas sob a fase de verdade.
			if falsificar:
				calendario.dia = 3
			dia.definir_hora(0.0)
			por_fase[indice] = _medir(ceu, luzes)
			_conferir(is_equal_approx(float(ceu.material.get_shader_parameter("lua_fase")), FasesDaLua.fase_do_dia(calendario.dia_absoluto())), "o shader recebe a fase do dia (estação %d, dia %d)" % [estacao, d])
		_conferir(por_fase.size() == FasesDaLua.CICLO_DIAS, "as oito fases foram medidas (estação %d)" % estacao)
		var nova: Dictionary = por_fase.get(FasesDaLua.NOVA, {})
		var cheia: Dictionary = por_fase.get(FasesDaLua.CHEIA, {})
		var quarto: Dictionary = por_fase.get(2, {})
		if nova.is_empty() or cheia.is_empty() or quarto.is_empty():
			continue
		_conferir(float(nova.lua) < 0.07, "na lua nova a luz da lua é baixa (%.3f, estação %d)" % [float(nova.lua), estacao])
		_conferir(float(cheia.lua) >= 0.26, "na lua cheia a luz da lua é a de sempre ou mais (%.3f, estação %d)" % [float(cheia.lua), estacao])
		_conferir(float(nova.lua) < float(quarto.lua) and float(quarto.lua) < float(cheia.lua), "a luz da lua cresce da nova ao quarto e à cheia (estação %d)" % estacao)
		_conferir(float(nova.lua) < 0.3 * float(cheia.lua), "a nova tem menos de 30%% da luz da cheia (estação %d)" % estacao)
		_conferir(float(nova.ambiente) < float(cheia.ambiente), "o ambiente da nova é mais escuro que o da cheia (estação %d)" % estacao)
		_conferir(float(nova.ambiente) > 0.1, "o ambiente da nova ainda deixa ver perto (%.3f, estação %d)" % [float(nova.ambiente), estacao])
		_conferir(bool(cheia.sombra) and not bool(nova.sombra) and not bool(quarto.sombra), "a lua cheia faz sombra e a nova e o quarto não (estação %d)" % estacao)
		_conferir(float(nova.lampiao) > float(cheia.lampiao) * 1.2, "o lampião da praça brilha bem mais na nova que na cheia (%.2f contra %.2f, estação %d)" % [float(nova.lampiao), float(cheia.lampiao), estacao])
		_conferir(bool(nova.viajante) and not bool(cheia.viajante), "o viajante só ganha brilho na noite escura (estação %d)" % estacao)
		_conferir(float(nova.disco) < 0.05 and float(cheia.disco) > 0.99, "o disco da lua leva a fração iluminada (estação %d)" % estacao)

	# De dia a fase não aparece: a luz do sol é a de sempre, e a lua não faz sombra.
	calendario.estacao = 0
	calendario.dia = 7
	dia.definir_hora(12.0)
	_conferir(not ceu.lua.visible and not ceu.lua.shadow_enabled, "ao meio-dia a lua está apagada, mesmo na nova")
	luzes.call("_seguir_o_viajante")
	_conferir(not _viajante_aceso(luzes), "ao meio-dia o viajante não ganha brilho")

	# "Suaves": a nova fica bem mais clara do que a escura, e ainda mais escura que a cheia.
	if not falsificar:
		calendario.dia = 7
		dia.definir_hora(0.0)
		var escura := _medir(ceu, luzes)
		FasesDaLua.definir_suaves(true)
		dia.definir_hora(0.0)
		var suave := _medir(ceu, luzes)
		calendario.dia = 3
		dia.definir_hora(0.0)
		var cheia_suave := _medir(ceu, luzes)
		FasesDaLua.definir_suaves(false)
		_conferir(float(suave.lua) > float(escura.lua) * 2.0, "com 'Suaves' a luz da lua nova mais que dobra (%.3f contra %.3f)" % [float(suave.lua), float(escura.lua)])
		_conferir(float(suave.ambiente) > float(escura.ambiente), "com 'Suaves' o ambiente da lua nova fica mais claro")
		_conferir(float(suave.lua) < float(cheia_suave.lua), "com 'Suaves' a nova ainda é mais escura que a cheia")

	calendario.estacao = estacao_de_antes
	calendario.dia = dia_de_antes


## O que o céu e as luzes valem agora.
func _medir(ceu, luzes) -> Dictionary:
	# O viajante é movido no _process das luzes; aqui se chama à mão, porque o portão não espera quadros.
	luzes.call("_seguir_o_viajante")
	# O lampião da praça (energia 2,4): a energia de hoje sobre a de projeto, com a intensidade da noite.
	var lampiao := 0.0
	for chama in luzes.get("_chamas"):
		if is_equal_approx(float(chama.energia), 2.4):
			lampiao = (chama.luz as OmniLight3D).light_energy / (2.4 * maxf(float(luzes.get("_intensidade")), 0.0001))
			break
	return {
		"lua": ceu.lua.light_energy,
		"ambiente": ceu.ambiente.ambient_light_energy,
		"sombra": ceu.lua.shadow_enabled,
		"lampiao": lampiao,
		"viajante": _viajante_aceso(luzes),
		"disco": float(ceu.material.get_shader_parameter("lua_brilho")),
	}


func _viajante_aceso(luzes) -> bool:
	var brilho := (luzes as Node).get_node_or_null("BrilhoDoViajante") as OmniLight3D
	return brilho != null and brilho.visible and brilho.light_energy > 0.01


func _frames(quantos: int) -> void:
	for i in quantos:
		await process_frame


func _mundo_pronto() -> void:
	for i in 3000:
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
