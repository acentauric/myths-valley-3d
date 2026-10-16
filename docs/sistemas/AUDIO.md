# Áudio do vale

O autoload Audio e `ambiente_vale.gd` combinam música por período, ambiente,
passos e falas dos moradores. Os arquivos de jogo ficam em `assets/audio/`;
nomes, texto e voz dos moradores estão em `data/npcs_3d.json`.

As ferramentas em `tools/elevenlabs/` mantêm o registro de produção e leem
credenciais locais por `tools/comum/chaves.ps1`. Gerar fala, música ou efeitos
consome crédito e exige pedido explícito. Não é necessário gerar áudio para
clonar, importar, executar ou testar o jogo.

Origem e créditos estão em `assets/CREDITOS.md` e nos registros ORIGEM.

## Música por período

O relógio do vale anuncia cinco períodos (madrugada, manhã, tarde, entardecer, noite) e cada um
tem a sua trilha de 75 s em `assets/audio/musica/musica_<período>.mp3`
(`Audio.MUSICAS_PERIODO`). A virada de período cruza as trilhas em 2,5 s (a atual desce, o fluxo
troca no fundo, a nova sobe); período vizinho com a mesma trilha não recomeça nada. A trilha de
tensão da mata (`musica_mata.mp3`) cobre a do período enquanto o jogador está na mata fechada ou uma
onça caça, e devolve a do período CERTO ao sair. A escolha de "Trilha do menu" em AJUSTAR vale para o
menu: com o vale aberto ela só é guardada. Até a Build 9B eram três trilhas para cinco períodos
(entardecer repetia a tarde e madrugada, a noite), e o HUD virava o período sem a música mudar.
`tests/musica_do_dia.gd` anda o relógio pelo dia inteiro no vale de verdade, e carrega partida em
cada período.

## Tensão do tubarão

Quando o tubarão persegue (ou, no mar aberto, ronda e dá o bote: ver `mar_aberto.gd`), uma **camada de
tensão** entra por cima da música do dia. O fluxo da trilha do dia não é trocado, só abaixa (até 30% do
volume, `ABAFO_DA_MUSICA_NA_TENSAO`), e por isso ela volta de onde estava quando o perigo passa. O
tubarão fala com o `Audio` por um número só por quadro, `Audio.tensao_do_tubarao(perigo)`, de 0 a 1, tirado
da distância (`Tubarao.perigo()`): longe é só um grave baixo (`GANHO_LONGE`), perto é a trilha inteira. A
camada entra em 1,5 s e sai em 5 s, toca no barramento Geral sob o volume e o mudo de Música, e no volume de
fábrica fica 16 dB abaixo das vozes e 11 dB abaixo da narração (`VOLUME_DA_TENSAO`), para fala e narração
continuarem por cima; ela segue também o `_abafo_musica`, e qualquer ducking geral da música a alcança. A trilha própria,
`musica_tubarao.mp3`, é geração paga (`tools/elevenlabs/gerar-musicas-periodos.ps1` tem a linha pronta);
enquanto ela não existe vale a da mata fechada, e sem nenhuma das duas o jogo segue calado.
`tests/unidade/test_tensao_do_tubarao.gd` cobre o Audio, e `tests/tubarao.gd` e `tests/musica_do_dia.gd`
cobrem a perseguição de verdade e a convivência com o dia e com a mata.

## Efeitos de trabalho, de interface e dos sustos

Todo nome em `Audio.efeito("...")` precisa de arquivo em `assets/audio/efeitos/`, e todo arquivo de
lá precisa de dono (`tests/sons_do_jogo.gd` varre os scripts e cobra os dois lados).

| Som | Quem toca |
|-----|-----------|
| `marretada_pedra`, `pedra_quebra` | a picareta na pedra e o último golpe que a quebra (`Recursos3D.SONS_DO_GOLPE` e `SONS_DO_ULTIMO`) |
| `foice_capim`, `catar_ostra`, `galho_quebra` | a foice no capim, a mão na ostra, a mão no galho seco (mesma tabela) |
| `porta_abrir`, `porta_fechar` | entrar e sair de uma construção (`AmbienteVale`, pelos sinais `entrou` e `saiu` do `Interiores`) |
| `menu_negado` | a mochila recusa uma ação (`mochila.gd`); sai pelo tocador de interface |
| `fantasma_sussurro`, `fantasma_avanco`, `curupira_assobio`, `mapa_doido` | os sustos da mata (a fatia dos sustos os dispara) |

Os sons novos nascem em `tools/elevenlabs/gerar-sons-que-faltam.ps1`, com os brutos em
`%TEMP%\mv_sons_que_faltam` (reprocessar não gasta crédito). O volume deles NÃO é o dos passos
(pico em -17 dB): os golpes de trabalho tocam ao lado do machado, do arar e da porta, que são
quentes, e por isso os golpes vão a -4 dB de pico e os sons que duram a -24 a -31 dB de volume médio.
Arquivo novo de áudio só existe para o Godot depois de importado (`Godot --headless --path . --import`
escreve os `.import`, que entram no commit).
