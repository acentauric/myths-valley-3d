extends RefCounted
## OS PONTOS DE RESTAURAÇÃO das vagas: cópias da partida, guardadas à parte,
## para ninguém perder a partida por um defeito grave do jogo.
##
## "Aproveite e implemente uma política de 'ponto de restauração', assim impede
## a pessoa de perder o save caso encontre algum bug grave."
##
## A POLÍTICA
##
##   - UM PONTO POR DIA DE JOGO. A primeira gravação de cada dia do calendário
##     guarda uma cópia da vaga (tipo "dia"), e ficam as SETE mais novas: uma
##     semana do vale para trás, que é quanto um defeito pode passar sem ser
##     visto. Gravar de novo no mesmo dia não gasta ponto.
##   - UM PONTO ANTES DE TUDO O QUE NÃO SE DESFAZ: apagar a vaga, começar uma
##     partida nova por cima dela ("antes_de_apagar") e restaurar outro ponto
##     ("antes_de_restaurar") — até a restauração se desfaz. Ficam os TRÊS mais
##     novos.
##   - A VAGA APAGADA LEVA OS PONTOS JUNTO: vazia, ela ainda os mostra, e volta
##     por eles.
##
## Os pontos moram em `user://pontos/vaga_N/`, longe dos arquivos que o
## `Salvamento` escreve e gira (`.save`, `.bak`, `.tmp`), e por isso gravação
## nenhuma os toca. Cada ponto é a cópia exata do arquivo da vaga; o nome dele
## diz quando foi guardado, de que tipo é e de que dia do jogo
## (`<quando em ms>_<tipo>_dia<N>.save`). Restaurar confere que o ponto se lê,
## guarda o ponto de antes e escreve por cima da vaga do jeito atômico do
## `Salvamento`: rascunho, releitura e troca, com a partida de antes no `.bak`.
##
## O `Salvamento` é do 2D e não muda uma linha por isto: quem chama é a
## `Partida`, a cada gravação (`Salvamento.salvou`) e antes de apagar.

const PASTA := "user://pontos"
## Quantos pontos de cada dia de jogo ficam, e quantos de antes de apagar ou
## restaurar.
const DIARIOS := 7
const DE_SEGURANCA := 3
const DIA := "dia"
const ANTES_DE_APAGAR := "antes_de_apagar"
const ANTES_DE_RESTAURAR := "antes_de_restaurar"


static func pasta(slot: int) -> String:
	return "%s/vaga_%d" % [PASTA, slot]


## Os pontos da vaga, do mais novo ao mais velho: {caminho, quando (ms do
## relógio de parede), tipo, dia (do jogo)}.
static func listar(slot: int) -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	var diretorio := DirAccess.open(pasta(slot))
	if diretorio == null:
		return lista
	for nome in diretorio.get_files():
		var ponto := _ler_o_nome(nome)
		if ponto.is_empty():
			continue
		ponto["caminho"] = pasta(slot).path_join(nome)
		lista.append(ponto)
	lista.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["quando"]) > int(b["quando"]))
	return lista


## `<quando>_<tipo>_dia<N>.save` → {quando, tipo, dia}, ou {} se não é ponto.
static func _ler_o_nome(nome: String) -> Dictionary:
	if not nome.ends_with(".save"):
		return {}
	var partes := nome.trim_suffix(".save").split("_")
	if partes.size() < 3 or not partes[0].is_valid_int() or not partes[-1].begins_with("dia"):
		return {}
	var dia := partes[-1].trim_prefix("dia")
	if not dia.is_valid_int():
		return {}
	return {"quando": int(partes[0]), "tipo": "_".join(partes.slice(1, partes.size() - 1)), "dia": int(dia)}


## GUARDA UM PONTO com o que a vaga tem agora. Devolve o caminho dele, ou "" se
## a vaga está vazia ou a cópia não deu.
static func guardar(slot: int, tipo: String) -> String:
	var origem := Salvamento.arquivo(slot)
	if slot <= 0 or not FileAccess.file_exists(origem):
		return ""
	DirAccess.make_dir_recursive_absolute(pasta(slot))
	var dia := int(Salvamento.resumo(slot).get("dia", 0))
	var quando := int(Time.get_unix_time_from_system() * 1000.0)
	var destino := _caminho(slot, quando, tipo, dia)
	while FileAccess.file_exists(destino):
		quando += 1
		destino = _caminho(slot, quando, tipo, dia)
	if DirAccess.copy_absolute(origem, destino) != OK:
		push_warning("Pontos: não consegui guardar %s." % destino)
		return ""
	_podar(slot)
	return destino


static func _caminho(slot: int, quando: int, tipo: String, dia: int) -> String:
	return pasta(slot).path_join("%d_%s_dia%d.save" % [quando, tipo, dia])


## DEPOIS DE CADA GRAVAÇÃO: o primeiro save de um dia do jogo guarda o ponto
## daquele dia. O dia que já tem o seu (o ponto diário mais novo é dele) passa.
static func depois_de_salvar(slot: int) -> void:
	if slot <= 0:
		return
	var dia := int(Salvamento.resumo(slot).get("dia", 0))
	for ponto in listar(slot):
		if str(ponto["tipo"]) == DIA:
			if int(ponto["dia"]) == dia:
				return
			break
	guardar(slot, DIA)


## Fica o que a política manda: os sete diários e os três de segurança mais
## novos. O resto sai.
static func _podar(slot: int) -> void:
	var diarios := 0
	var de_seguranca := 0
	for ponto in listar(slot):
		var fica: bool
		if str(ponto["tipo"]) == DIA:
			diarios += 1
			fica = diarios <= DIARIOS
		else:
			de_seguranca += 1
			fica = de_seguranca <= DE_SEGURANCA
		if not fica:
			DirAccess.remove_absolute(str(ponto["caminho"]))


## APAGA A VAGA guardando antes o ponto dela: apagar se desfaz. A cópia
## anterior (`.bak`) sai junto — a partida apagada está no ponto, e uma vaga
## nova não pode cair nela se o arquivo dela um dia não abrir.
static func apagar_vaga(slot: int) -> void:
	guardar(slot, ANTES_DE_APAGAR)
	Salvamento.apagar(slot)
	if FileAccess.file_exists(Salvamento.anterior(slot)):
		DirAccess.remove_absolute(Salvamento.anterior(slot))


## RESTAURA o ponto em `caminho` na vaga. Confere que ele se lê, guarda o ponto
## de antes (se a vaga tem partida) e escreve por cima do jeito atômico do
## `Salvamento`. Devolve false sem tocar a vaga se o ponto não se lê.
static func restaurar(slot: int, caminho: String) -> bool:
	if slot <= 0 or not FileAccess.file_exists(caminho) or Salvamento._ler_arquivo(caminho).is_empty():
		return false
	var conteudo := FileAccess.get_file_as_bytes(caminho)
	if FileAccess.file_exists(Salvamento.arquivo(slot)):
		guardar(slot, ANTES_DE_RESTAURAR)
	var rascunho := Salvamento.rascunho(slot)
	var arquivo := FileAccess.open(rascunho, FileAccess.WRITE)
	if arquivo == null:
		return false
	arquivo.store_buffer(conteudo)
	arquivo.close()
	if Salvamento._ler_arquivo(rascunho).is_empty():
		DirAccess.remove_absolute(rascunho)
		return false
	var da_vaga := Salvamento.arquivo(slot)
	if FileAccess.file_exists(da_vaga):
		if FileAccess.file_exists(Salvamento.anterior(slot)):
			DirAccess.remove_absolute(Salvamento.anterior(slot))
		DirAccess.rename_absolute(da_vaga, Salvamento.anterior(slot))
	DirAccess.rename_absolute(rascunho, da_vaga)
	return FileAccess.file_exists(da_vaga)
