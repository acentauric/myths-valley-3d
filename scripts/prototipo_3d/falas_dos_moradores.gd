extends RefCounted
## AS FALAS DE QUEM MORA NO ARRAIAL: de qual lista sai cada uma, e quando.
##
## "Crie as falas para os personagens que ainda não têm." Catorze moradores do
## `npcs_3d.json` eram mudos (`"mudo": true`, sem fala nenhuma) e agora falam. Uma
## lista só para tudo — as três falas dos sete antigos — não servia a quem tem
## muito a dizer: o cumprimento de quem passa é de uma frase, no balão curto, e a
## conversa do E é de duas, inteira. Por isso o morador novo traz as duas coisas:
##
##   `saudacoes`        3 a 4 cumprimentos, cada um cabe inteiro no balão (até 60
##                      letras): é o que ele diz a quem chega perto (`npc.saudar`);
##   `falas`            6 a 10 falas de conversa, de 60 a 140 letras: é o que ele diz
##                      no E (`npc.conversar`);
##   `saudacoes_noite`  (opcional) cumprimentos de quem está na rua no escuro — o
##   `falas_noite`      guarda de candeeiro, o dono da venda fechando, o saveirista —
##                      que SOMAM às de sempre quando é noite (`humor_do_periodo`).
##
## O morador antigo, e o Pedro, que só têm `falas`, seguem como sempre: sem
## `saudacoes` o cumprimento sai da mesma lista da conversa.
##
## Cada entrada é `{texto, texto_en, texto_es, audio}`; `audio` vazio é fala só de
## balão (a voz custa crédito e é decisão do autor). O idioma quem escolhe é
## `IdiomaMenu.campo`; aqui só se escolhe a LISTA, e por isso este arquivo não cita
## autoload (AGENTS.md: portão rodado com `--script` não enxerga autoload pelo nome)
## e um portão pode conferi-lo sem montar o vale (`tests/falas_dos_moradores.gd`).
##
## Chuva: o vale ainda não tem chuva (só estações), então não há `*_chuva`. Quando
## tiver, é um humor a mais em `humor_do_periodo` e as chaves já se chamam sozinhas.

## O humor de quem fala à noite.
const NOITE := "noite"


## O HUMOR DA FALA para o período do dia (`Dia.periodo()`): "noite" quando é noite (das 18h48 à
## meia-noite), "" no resto. A MADRUGADA FICA DE FORA DE PROPÓSITO: é quando o padre, o sacristão e a
## lavadeira abrem o dia, e "já vou trancar a porta" ao nascer do sol seria o contrário da verdade.
static func humor_do_periodo(periodo: String) -> String:
	return NOITE if periodo == "noite" else ""


## DE ONDE A ROTAÇÃO RECOMEÇA quando o humor muda (cai a noite): da primeira fala do humor, que na
## lista de `lista` vem depois das de sempre. Assim a fala de noite sai quando a noite chega, e não só
## depois de rodar as de sempre. Sem fala nesse humor (ou de dia), a rotação segue de onde estava (`atual`).
static func recomeco(dados: Dictionary, categoria: String, humor: String, atual: int) -> int:
	if humor == "" or (dados.get(categoria + "_" + humor, []) as Array).is_empty():
		return atual
	return (dados.get(categoria, []) as Array).size()


## A LISTA de `categoria` ("saudacoes" ou "falas") para o humor: as de sempre mais as
## do humor (`<categoria>_<humor>`), se ele as tem. Nunca devolve a lista do próprio
## `dados`: quem a recebe pode alterá-la.
static func lista(dados: Dictionary, categoria: String, humor: String) -> Array:
	var comuns: Array = (dados.get(categoria, []) as Array).duplicate()
	if humor == "":
		return comuns
	return comuns + (dados.get(categoria + "_" + humor, []) as Array)
