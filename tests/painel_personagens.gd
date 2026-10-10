extends "res://tests/suite/caso.gd"
## Painel MODELOS: as duas abas abrem em cartões e cada cartão abre a ficha no mesmo
## formato (prévia 3D e dados, todas as falas, sem filtro); EDITAR e GRAVAR ficam no
## cabeçalho; edita um morador (altura, posto, fala) e uma peça (medida), confere que os
## ajustes chegam aos dados do jogo, que fechar com ajuste pendente pede confirmação e
## restaura o padrão.


## #213: cada nome de cartão aparece inteiro, em até duas linhas que cabem na largura útil do botão, e o
## cartão é baixo (no teto da grade) e comporta as linhas.
func _confere_nomes(painel, grade: GridContainer, rotulo: String) -> void:
	for cartao: Button in grade.get_children():
		var fonte := cartao.get_theme_font("font")
		var tamanho := cartao.get_theme_font_size("font_size")
		var caixa := cartao.get_theme_stylebox("normal")
		var util := cartao.size.x - caixa.get_margin(SIDE_LEFT) - caixa.get_margin(SIDE_RIGHT)
		var linhas := cartao.text.split("\n")
		_assert(linhas.size() <= 2, "%s: o nome de '%s' ocupa %d linhas" % [rotulo, cartao.name, linhas.size()])
		for linha in linhas:
			_assert(fonte.get_string_size(linha, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x <= util, "%s: '%s' corta no cartão (%.0f de %.0f px)" % [rotulo, linha, fonte.get_string_size(linha, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x, util])
		_assert(is_equal_approx(cartao.size.y, painel.CARTAO_MIN.y), "%s: o cartão '%s' tem %.0f px de altura; todos têm %.0f" % [rotulo, cartao.name, cartao.size.y, painel.CARTAO_MIN.y])
		_assert(cartao.get_theme_font_size("font_size") == painel.FONTE_CARTAO, "%s: o cartão '%s' não usa a fonte dos cartões" % [rotulo, cartao.name])
		_assert(cartao.size.y >= linhas.size() * fonte.get_height(tamanho) + caixa.get_margin(SIDE_TOP) + caixa.get_margin(SIDE_BOTTOM) - 1.0, "%s: o cartão '%s' não comporta as linhas do nome" % [rotulo, cartao.name])


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	AjustesConteudo.restaurar_morador("benedito")
	AjustesConteudo.restaurar_peca("mangueira")
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var painel = load("res://scripts/prototipo_3d/painel_personagens.gd").new()
	host.add_child(painel)
	painel.abrir(load("res://scripts/prototipo_3d/tema_menu.gd").criar())
	painel._ancoras.assign(["Bar", "Casa de Carro Quebrado", "Igreja", "Pier", "Praça", "Roçado"])
	var fechou := [false]
	painel.fechado.connect(func() -> void: fechou[0] = true)
	await _frames(3)
	# MORADORES abre em cartões, como ASSETS.
	var cartoes: GridContainer = painel._lista.get_node("GradeMoradores")
	# Com os moradores novos de 05/10 são mais de uma página de cartões: a primeira vem cheia, e o viajante fecha a lista.
	var capacidade: Vector2i = painel._capacidade()
	_assert(cartoes.columns == capacidade.x and cartoes.get_child_count() == mini(painel._pessoas.size(), capacidade.x * capacidade.y), "moradores em cartões")
	# #171 e #213: a grade ocupa o modal, no mínimo 6 colunas por 5 linhas, de cartões baixos. Os moradores não
	# enchem a página, e os cartões não esticam: têm a altura dos de ASSETS (a faixa vazia é conferida lá).
	_assert(capacidade.x >= 6 and capacidade.y >= 5, "grade de cartões com ao menos 6 x 5 (%s)" % capacidade)
	_assert(painel._rolagem.get_global_rect().encloses(cartoes.get_global_rect()), "a grade cabe na rolagem")
	_assert(not painel._rolagem.get_v_scroll_bar().visible, "a grade de moradores não rola")
	_confere_nomes(painel, cartoes, "moradores")
	_assert(str(cartoes.get_child(0).name) == "Morador_pedro" and str((painel._pessoas.back() as Dictionary).get("id", "")) == "viajante", "Pedro abre os cartões e o viajante fecha")
	var ids_na_lista: Array = []
	for pessoa: Dictionary in painel._pessoas:
		ids_na_lista.append(str(pessoa.get("id", "")))
	for novo in ["padre", "guarda", "lavadeira", "mestre_saveiro"]:
		_assert(novo in ids_na_lista, "o morador novo '%s' aparece no painel PERSONAGENS" % novo)
	_assert(painel._campo_filtro.visible and not painel._botao_editar.visible, "nos cartões há filtro e não há EDITAR")
	for botao in painel.find_children("*", "Button", true, false):
		_assert(not (botao.text in ["FECHAR", "GRAVAR NO PROJETO", "Voltar ao catálogo"]), "sem botões antigos no corpo: %s" % botao.text)
	for rotulo in painel.find_children("*", "Label", true, false):
		_assert(not rotulo.text.begins_with("Os ajustes valem") and not rotulo.text.begins_with("Selecione"), "sem avisos que a interface já comunica")
	# A lista e a ficha têm o mesmo tamanho: a caixa fica no TAMANHO nas duas, sem a ficha esticar o modal.
	_assert(painel._caixa.size.is_equal_approx(painel.TAMANHO), "os cartões ficam no tamanho do modal (%s)" % painel._caixa.size)
	await _capturar("cartoes")
	# A ficha do Pedro: prévia real, dados à direita e as três falas, sem navegar entre falas.
	painel._abrir("pedro")
	await _frames(3)
	if "--sem-previa" in OS.get_cmdline_user_args():
		painel._preview_modelo = null
	_assert(painel._lista.get_meta("ficha") == "pedro", "cartão abre a ficha")
	_assert(painel._preview_modelo != null and not painel._preview_modelo.find_children("*", "MeshInstance3D", true, false).is_empty(), "prévia usa o modelo 3D real")
	_assert(painel._preview_viewport.own_world_3d, "prévia não mistura luzes e objetos com o vale")
	_assert(painel._voz.bus == &"Escuta", "a fala toca fora do mudo geral")
	var audio := root.get_node("/root/Audio")
	var som_antes: bool = audio.som_ativo
	audio.definir_som_ativo(false)
	_assert(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Geral")) and not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Escuta")) and not AudioServer.is_bus_mute(0), "som desligado cala o Geral e deixa a fala pedida tocar")
	audio.definir_som_ativo(som_antes)
	_assert(not painel._campo_filtro.visible and painel._botao_editar.visible, "na ficha o filtro some e EDITAR aparece")
	var falas: Array = painel._lista.find_children("Fala*", "HBoxContainer", true, false)
	_assert(falas.size() == 3, "as três falas na ficha")
	_assert(painel._caixa.size.is_equal_approx(painel.TAMANHO), "a ficha tem o mesmo tamanho dos cartões (%s)" % painel._caixa.size)
	# A ficha em dois blocos com cabeçalho: DADOS (as linhas) e NARRAÇÕES (as falas, logo abaixo).
	var bloco_dados := painel._lista.find_child("BlocoDados", true, false) as Control
	var bloco_narracoes := painel._lista.find_child("BlocoNarracoes", true, false) as Control
	_assert(bloco_dados != null and bloco_narracoes != null, "a ficha tem os cabeçalhos DADOS e NARRAÇÕES")
	_assert(bloco_dados.global_position.y < (painel._lista.find_child("Linhas", true, false) as Control).global_position.y and bloco_narracoes.global_position.y < falas[0].global_position.y, "cada cabeçalho vem antes do seu bloco")
	# #190: as animações são ícones sob a prévia, em duas linhas na largura dela; os do Mixamo e os do Tripo, cada
	# um com o nome na dica, e o clique toca o clipe na prévia.
	var animacoes := painel._lista.find_child("Animacoes", true, false) as Control
	var fundo := painel._lista.find_child("FundoPrevia", true, false) as Control
	_assert(animacoes != null and animacoes.get_parent() == fundo.get_parent() and animacoes.global_position.y > fundo.global_position.y, "as animações ficam sob a prévia")
	_assert(animacoes.get_child_count() == 2, "as animações em duas linhas")
	var capoeira := painel._lista.find_child("Clipe_capoeira", true, false) as Button
	_assert(capoeira != null and capoeira.text.is_empty() and capoeira.tooltip_text.contains("apoeira") and capoeira.tooltip_text.contains("Mixamo") and str(capoeira.get_meta("origem", "")) == "Mixamo", "a Capoeira do Pedro é um ícone com o nome e o Mixamo na dica")
	var do_tripo: Array = painel._lista.find_children("ClipeTripo_*", "Button", true, false)
	_assert(do_tripo.size() >= 7 and str(do_tripo[0].get_meta("origem", "")) == "Tripo" and do_tripo[0].tooltip_text.ends_with(" · Tripo"), "os clipes do Tripo também viram ícones")
	if capoeira != null and painel._tocador_da_previa() != null:
		capoeira.button_pressed = true
		capoeira.pressed.emit()
		_assert(painel._clipe_na_previa == "mixamo/capoeira" and painel._tocador_da_previa().current_animation == &"mixamo/capoeira", "o clique na Capoeira a toca na prévia")
		_assert(painel._preview_viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "com o clipe tocando a prévia se redesenha a cada quadro")
		capoeira.button_pressed = false
		capoeira.pressed.emit()
		_assert(painel._clipe_na_previa == "", "o segundo clique volta a prévia à pose parada")
	for fala: HBoxContainer in falas:
		var texto := fala.get_child(2) as Label
		_assert(texto.autowrap_mode == TextServer.AUTOWRAP_OFF and texto.clip_text and texto.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS, "a fala fica numa linha, cortada com reticências")
		_assert(fala.get_child(1).name == "Expandir", "ao lado do ▶, o botão de expandir")
	_assert(painel._rodape.find_children("Navegacao", "", true, false).size() == 1 and painel._lista.find_children("Navegacao", "", true, false).is_empty(), "só a navegação entre fichas, no rodapé")
	_assert(painel._lista.find_child("FundoPrevia", true, false) != null and painel._preview_viewport.transparent_bg, "prévia sobre o fundo de azulejo")
	var fundo_pedro: Control = painel._lista.find_child("FundoPrevia", true, false)
	var tamanho_previa := fundo_pedro.size
	var linhas_pedro := (painel._lista.find_child("Linhas", true, false) as GridContainer).get_child_count()
	var posicao_falas: float = falas[0].global_position.y
	# O ▶ vira ❚❚ e o segundo clique para a fala.
	var tocar := falas[0].get_child(0) as Button
	if not tocar.disabled:
		tocar.pressed.emit()
		_assert(painel._fala_tocando == tocar and tocar.get_meta("icone").tipo == "pausar", "tocar mostra a pausa")
		tocar.pressed.emit()
		_assert(painel._fala_tocando == null and not painel._voz.playing and tocar.get_meta("icone").tipo == "tocar", "segundo clique para a fala")
	# Girar a prévia com o mouse.
	var giro_antes: float = painel._preview_pivo.rotation.y
	var arrasto := InputEventMouseMotion.new()
	arrasto.button_mask = MOUSE_BUTTON_MASK_LEFT
	arrasto.relative = Vector2(40, 0)
	painel._girar_previa(arrasto)
	_assert(not is_equal_approx(painel._preview_pivo.rotation.y, giro_antes), "arrastar gira o modelo")
	var roda := InputEventMouseButton.new()
	roda.button_index = MOUSE_BUTTON_WHEEL_UP
	roda.pressed = true
	var distancia_antes: float = painel._distancia
	painel._girar_previa(roda)
	_assert(painel._distancia < distancia_antes, "a roda aproxima")
	var mover := InputEventMouseMotion.new()
	mover.button_mask = MOUSE_BUTTON_MASK_RIGHT
	mover.relative = Vector2(30, 10)
	var alvo_antes: Vector3 = painel._alvo
	painel._girar_previa(mover)
	_assert(not painel._alvo.is_equal_approx(alvo_antes), "o botão direito move o enquadramento")
	var duplo := InputEventMouseButton.new()
	duplo.button_index = MOUSE_BUTTON_LEFT
	duplo.pressed = true
	duplo.double_click = true
	painel._girar_previa(duplo)
	_assert(is_equal_approx(painel._distancia, painel._distancia_inicial) and painel._alvo.is_equal_approx(painel._alvo_inicial) and is_zero_approx(painel._preview_pivo.rotation.y), "duplo clique centraliza")
	_assert(painel._rolagem.get_global_rect().encloses(painel._lista.get_global_rect()), "ficha cabe sem rolagem")
	await _capturar("morador")
	# Expandir abre o leitor com a fala inteira; as setas (e ← →) passam por todas as falas; Esc fecha só o leitor.
	(falas[0].get_node("Expandir") as Button).pressed.emit()
	await _frames(2)
	var falas_do_pedro: Array = painel._falas_da_ficha
	_assert(is_instance_valid(painel._leitor), "expandir abre o leitor")
	var texto_inteiro := painel._leitor.find_child("TextoDaFala", true, false) as Label
	_assert(texto_inteiro.text == "“%s”" % str(falas_do_pedro[0].get("texto", "")) and texto_inteiro.autowrap_mode != TextServer.AUTOWRAP_OFF, "o leitor mostra a fala inteira, com quebra de linha")
	_assert(painel._leitor.find_child("Tocar", true, false) != null, "o leitor tem o ▶")
	await _capturar("leitor")
	painel._input(direita_tecla())
	await _frames(1)
	_assert(painel._indice_no_leitor == 1 and (painel._leitor.find_child("TextoDaFala", true, false) as Label).text.contains(str(falas_do_pedro[1].get("texto", "")).left(20)), "→ passa à fala seguinte no leitor")
	painel.pedir_fechar()
	await _frames(1)
	_assert(not is_instance_valid(painel._leitor) and not fechou[0] and painel._lista.get_meta("ficha") == "pedro", "Esc fecha o leitor e deixa a ficha")
	painel._input(direita_tecla())
	await _frames(3)
	_assert(painel._lista.get_meta("ficha") == "benedito", "a seta → vai para o Benedito")
	_assert(painel._preview_modelo.name.begins_with("Benedito"), "prévia acompanha o morador")
	# A ficha não muda de forma entre moradores: mesma prévia, mesmas linhas e falas no lugar.
	await _frames(2)
	var fundo_benedito: Control = painel._lista.find_child("FundoPrevia", true, false)
	_assert(fundo_benedito.size.is_equal_approx(tamanho_previa), "a prévia tem o mesmo tamanho para todos")
	_assert((painel._lista.find_child("Linhas", true, false) as GridContainer).get_child_count() == linhas_pedro, "as mesmas linhas para todos")
	var falas_benedito: Array = painel._lista.find_children("Fala*", "HBoxContainer", true, false)
	_assert(falas_benedito.size() == 3 and is_equal_approx(falas_benedito[0].global_position.y, posicao_falas), "as falas ficam no mesmo lugar")
	# #190: o viajante tem 19 clipes (6 do Mixamo e 13 do Tripo): todos viram ícones, nas mesmas duas linhas e na
	# largura da prévia, e a ficha não muda de tamanho.
	var altura_das_animacoes: float = (painel._lista.find_child("Animacoes", true, false) as Control).size.y
	painel._abrir("viajante")
	await _frames(3)
	var animacoes_viajante := painel._lista.find_child("Animacoes", true, false) as Control
	var icones: Array = animacoes_viajante.find_children("Clipe*", "Button", true, false)
	_assert(icones.size() == 19, "os 19 clipes do viajante em ícones (%d)" % icones.size())
	var largura_previa: float = (painel._lista.find_child("FundoPrevia", true, false) as Control).size.x
	for linha_de_icones: Control in animacoes_viajante.get_children():
		_assert(linha_de_icones.size.x <= largura_previa + 0.5, "a linha de ícones cabe na largura da prévia")
	_assert(is_equal_approx(animacoes_viajante.size.y, altura_das_animacoes), "as animações do viajante têm a altura das do Benedito")
	_assert(painel._caixa.size.is_equal_approx(painel.TAMANHO), "a ficha do viajante tem o mesmo tamanho dos cartões (%s)" % painel._caixa.size)
	var pulo := animacoes_viajante.find_child("Clipe_jump", true, false) as Button
	if pulo != null and painel._tocador_da_previa() != null:
		pulo.button_pressed = true
		pulo.pressed.emit()
		_assert(painel._clipe_na_previa == "mixamo/jump" and painel._tocador_da_previa().current_animation == &"mixamo/jump", "o ícone do pulo toca o pulo na prévia")
		pulo.button_pressed = false
		pulo.pressed.emit()
		_assert(painel._clipe_na_previa == "", "o mesmo ícone de novo volta a prévia à pose parada")
	await _capturar("viajante")
	painel._abrir("benedito")
	await _frames(3)
	if painel._botao_gravar != null and not AjustesConteudo.tem_pendencias():
		_assert(painel._botao_gravar.disabled and painel._botao_gravar.tooltip_text == painel.tr("Nada para gravar"), "GRAVAR desativado sem ajuste pendente")
	# Edita o Benedito pelo EDITAR do cabeçalho.
	painel._botao_editar.pressed.emit()
	await _frames(2)
	_assert(painel.editando and painel._icone_editar.tipo == "concluir" and painel._botao_restaurar.visible, "EDITAR vira concluir e mostra RESTAURAR")
	var spins: Array = painel._lista.find_children("*", "SpinBox", true, false)
	var opcoes: Array = painel._lista.find_children("*", "OptionButton", true, false)
	print("PAINEL: %d campos numéricos, %d seletores de lugar" % [spins.size(), opcoes.size()])
	_assert(spins.size() >= 3 and opcoes.size() >= 5, "editor do morador com altura, volume e postos")
	(spins[0] as SpinBox).value = 1.9
	(opcoes[0] as OptionButton).select(1)
	(opcoes[0] as OptionButton).item_selected.emit(1)
	var campos: Array = painel._lista.find_children("*", "LineEdit", true, false)
	var campo_fala: LineEdit = campos[campos.size() - 1]
	campo_fala.text = "Fala de teste."
	campo_fala.text_changed.emit("Fala de teste.")
	var dados = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs_3d.json"))
	var ajustado: Dictionary = {}
	for m in AjustesConteudo.npcs(dados)["moradores"]:
		if m["id"] == "benedito":
			ajustado = m
	print("PAINEL: altura %s · manhã %s · falas %s" % [ajustado.get("altura"), ajustado["postos"]["manha"], ajustado["falas"].map(func(f): return f["texto"])])
	_assert(is_equal_approx(float(ajustado["altura"]), 1.9), "altura ajustada chega aos dados")
	_assert(String(ajustado["postos"]["manha"][0]) != "", "posto ajustado")
	_assert(ajustado["falas"].any(func(f): return f["texto"] == "Fala de teste."), "fala ajustada")
	if painel._botao_gravar != null:
		# O destaque é conferido a cada 0,25 s.
		await create_timer(0.5).timeout
		_assert(painel._icone_gravar.ativo, "GRAVAR fica dourado com ajuste pendente")
		_assert(not painel._botao_gravar.disabled, "GRAVAR ativo com ajuste pendente")
		painel.pedir_fechar()
		_assert(is_instance_valid(painel._confirmacao) and not fechou[0], "fechar com ajuste pendente pede confirmação")
		await _capturar("confirmacao")
		painel.pedir_fechar()
		_assert(not is_instance_valid(painel._confirmacao) and not fechou[0], "Esc de novo só cancela a confirmação")
	# ASSETS: os mesmos cartões e a ficha no mesmo formato.
	painel._trocar_aba(1)
	await _frames(3)
	var grade: GridContainer = painel._lista.get_node("GradeAssets")
	var primeiro_cartao := str(grade.get_child(0).name)
	_assert(grade.columns == capacidade.x and grade.get_child_count() == capacidade.x * capacidade.y, "assets em grade paginada")
	# Nome que corta no cartão aparece inteiro no tooltip.
	_assert(str(grade.get_child(0).tooltip_text).begins_with(str(grade.get_child(0).text).replace("\n", " ").strip_edges().trim_suffix("•").strip_edges()), "o tooltip do cartão traz o nome inteiro")
	_assert(not painel._rolagem.get_v_scroll_bar().visible, "a grade de assets não rola")
	_confere_nomes(painel, grade, "assets")
	# A página cheia de ASSETS ocupa a altura: sobra menos que uma linha de cartões acima da navegação.
	var vazio_embaixo: float = painel._rodape.get_global_rect().position.y - grade.get_global_rect().end.y
	var uma_linha: float = painel.CARTAO_MIN.y + painel.SEPARACAO_GRADE + painel.SEPARACAO_COLUNA
	_assert(vazio_embaixo < uma_linha, "sobra menos que uma linha de cartões entre a grade e a navegação (%.0f px)" % vazio_embaixo)
	_assert(painel._lista.find_children("*", "SpinBox", true, false).is_empty(), "grade não abre editores")
	_assert(painel._rolagem.get_global_rect().encloses(painel._lista.get_global_rect()), "grade cabe sem rolagem")
	for chave: String in CatalogoAssets.PECAS:
		if str(CatalogoAssets.PECAS[chave].get("tripo", "")).begins_with("personagens/"):
			_assert(not painel._itens().any(func(item: Array) -> bool: return item[0] == chave), "morador fora de ASSETS: %s" % chave)
	await _capturar("assets")
	painel._rodape.find_children("Navegacao", "", true, false)[0].get_child(2).pressed.emit()
	await _frames(3)
	_assert(str(painel._lista.get_node("GradeAssets").get_child(0).name) != primeiro_cartao, "paginação muda os cartões")
	painel._abrir("mangueira")
	await _frames(3)
	_assert(not painel._lista.has_node("GradeAssets") and painel._preview_modelo != null, "cartão abre só o registro e o modelo")
	_assert(painel._lista.get_node("Ficha/Detalhes") != null and painel._lista.get_node("Ficha/ColunaPrevia/FundoPrevia/Previa3D") != null and painel._lista.find_child("Animacoes", true, false) == null, "ficha da peça no formato da do morador, sem animações")
	_assert(not painel._campo_filtro.visible, "registro da peça sem filtro")
	await _capturar("registro")
	painel._botao_editar.pressed.emit()
	await _frames(3)
	var campos_peca: Array = painel._lista.find_children("*", "SpinBox", true, false)
	_assert(campos_peca.size() >= 2, "editor da peça selecionada")
	await _capturar("editor")
	var altura_antes := float(AjustesConteudo.peca("mangueira")["altura"])
	campos_peca[0].value = altura_antes + 1.5
	_assert(is_equal_approx(float(AjustesConteudo.peca("mangueira")["altura"]), altura_antes + 1.5), "campo da peça grava ajuste")
	painel._trocar_aba(1)
	await _frames(2)
	_assert(painel._lista.has_node("GradeAssets") and painel.selecionado.is_empty(), "clicar na aba volta aos cartões")
	_assert(painel._lista.get_node("GradeAssets").has_node("Peca_mangueira"), "voltar da ficha leva à página do cartão dela")
	# Um cartão cujo índice cai em páginas diferentes conforme o filtro (visível nos cartões,
	# escondido na ficha) está ou não contado: voltar da ficha tem de usar a capacidade dos cartões.
	var por_pagina_cartoes: int = capacidade.x * capacidade.y
	painel._abrir("mangueira")
	await _frames(3)
	var por_pagina_ficha: int = painel._cartoes_por_pagina()
	var chaves_aba: Array = painel._itens().map(func(item: Array) -> String: return item[0])
	var indice_critico := -1
	for indice in range(chaves_aba.size()):
		if floori(float(indice) / por_pagina_cartoes) != floori(float(indice) / por_pagina_ficha):
			indice_critico = indice
			break
	_assert(indice_critico >= 0, "há uma peça cujo índice muda de página com o filtro escondido")
	if indice_critico >= 0:
		painel._abrir(chaves_aba[indice_critico])
		await _frames(3)
		painel._trocar_aba(1)
		await _frames(2)
		_assert(painel._lista.get_node("GradeAssets").has_node("Peca_" + chaves_aba[indice_critico]), "voltar da ficha cai na página dos cartões, não na da ficha (%d)" % indice_critico)
	# Restaurar volta ao padrão do projeto, e sem pendência o × fecha direto.
	var antes := float(CatalogoAssets.PECAS["mangueira"]["altura"])
	AjustesConteudo.restaurar_morador("benedito")
	AjustesConteudo.restaurar_peca("mangueira")
	_assert(not AjustesConteudo.morador_ajustado("benedito"), "morador restaurado")
	_assert(is_equal_approx(float(AjustesConteudo.peca("mangueira")["altura"]), antes), "peça restaurada")
	if not AjustesConteudo.tem_pendencias():
		painel.pedir_fechar()
		_assert(fechou[0], "sem pendência o × fecha")
	print("PAINEL_PERSONAGENS_OK")
	quit()


func direita_tecla() -> InputEventKey:
	var direita := InputEventKey.new()
	direita.keycode = KEY_RIGHT
	direita.pressed = true
	return direita


func _capturar(nome: String) -> void:
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with("--capturas="):
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(argumento.trim_prefix("--capturas=") + "-" + nome + ".png")


func _assert(condition: bool, label: String) -> void:
	if not condition:
		push_error("PAINEL_FALHOU: " + label)
		quit(1)
		assert(false, label)


func _frames(count: int) -> void:
	for frame in range(count):
		await process_frame
