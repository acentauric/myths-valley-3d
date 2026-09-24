# Estratégia sonora — a chegada ao Recôncavo

Revisão: 23 de setembro de 2026. Escopo implementado: menu, opções e travessia de entrada.

## Intenção narrativa

A entrada apresenta Bom Jesus dos Pobres, entre a Mata Atlântica e a Baía de Todos os Santos, em 1887. O jogador chega como viajante do manuscrito e é acolhido por Pedro Nolasco. A primeira impressão sonora deve ser de lugar habitado, proximidade e curiosidade. O mistério existe ao fundo; a entrada não antecipa o terror da fazenda.

As referências internas são [Ambientação](AMBIENTACAO.md), [a chegada do viajante](enredo/README.md) e os [capítulos 6](enredo/capitulo-06.md) e [7](enredo/capitulo-07.md). Esta é uma direção artística para o jogo, não uma reconstrução documental de repertório musical ou de espécies locais.

O calor da viola e da madeira acompanha a tinta escura, o verde de maré, o ouro envelhecido e o pergaminho da interface. A flauta oferece o detalhe luminoso da paisagem; uma harmonia levemente suspensa sugere o manuscrito e a mata. Evitar fanfarra medieval, coro épico, impacto de trailer e sintetizador moderno ajuda a manter a escala humana do arraial.

## Três camadas independentes

| Camada | Função | Direção |
|---|---|---|
| Música — **Maré de chegada** | Identidade e acolhimento | Composição instrumental longa, cordas dedilhadas, viola, flauta de madeira, pulso orgânico discreto; motivo com variações lentas e retorno sereno |
| Ambiente — **Maré mansa** e **Aves do Recôncavo** | Situar o lugar | Água de baía abrigada, chamadas espaçadas de aves ao longe; o mar e as aves podem tocar separados ou juntos |
| Interface — **Madeira & papel** | Responder ao gesto | Movimento leve, confirmação curta e retorno mais grave; sem sustos, sino agudo ou cauda que encubra a próxima ação |

O mar e as aves não estão gravados dentro da música. Assim, a pessoa pode desligar a natureza, ouvir apenas água, comparar trilhas antigas ou baixar os efeitos sem perder a composição. A trilha deve continuar ao abrir opções e créditos, sem voltar ao primeiro compasso a cada clique.

## Ativos produzidos

Seis gerações originais pela API ElevenLabs; nenhum arquivo legado foi substituído.

| Arquivo em `assets/audio/` | Fonte | Versão no jogo |
|---|---|---|
| `musica/tema_reconcavo.ogg` | `music_v2`, 180 s, instrumental obrigatório | 177 s, ponte de 3 s entre final e início; Ogg Vorbis 44,1 kHz |
| `ambiente/mare_mansa.ogg` | `eleven_text_to_sound_v2`, 24 s, `loop=true` | 23,75 s, ponte de 250 ms; Ogg Vorbis 44,1 kHz |
| `ambiente/aves_reconcavo.ogg` | `eleven_text_to_sound_v2`, 27 s, `loop=true` | 26,75 s, ponte de 250 ms; Ogg Vorbis 44,1 kHz |
| `efeitos/menu_mover_madeira.mp3` | `eleven_text_to_sound_v2`, 0,5 s | Silêncio inicial aparado, ataque de 3 ms, término suavizado |
| `efeitos/menu_confirma_madeira.mp3` | Mesmo modelo, 0,7 s | Mesmo tratamento; a ação fica mais curta após retirar silêncio |
| `efeitos/menu_voltar_madeira.mp3` | Mesmo modelo, 0,6 s | Mesmo tratamento |

Os MP3 originais e os prompts completos estão em `assets/audio/fontes/introducao_2026/`. Os JSON de cada fonte registram modelo, duração solicitada, instrução, destino e opção de loop. `manifesto.json` registra os hashes SHA-256 e as durações dos masters. A pasta de fontes tem `.gdignore`: preserva a proveniência sem embutir duplicatas no jogo.

O roteiro de geração e preparação é [gerar-introducao.ps1](../tools/elevenlabs/gerar-introducao.ps1). Ele pula fontes já existentes. `-PrepararNovamente` refaz somente os masters locais a partir dessas fontes; não consome outra geração. Nenhuma chave aparece nos prompts, metadados ou comandos: o cliente usa o leitor seguro já existente em `tools/comum/chaves.ps1`.

Referência de parâmetros: [composição musical](https://elevenlabs.io/docs/api-reference/music/compose) e [efeitos sonoros](https://elevenlabs.io/docs/api-reference/text-to-sound-effects/convert), documentação oficial ElevenLabs consultada nesta revisão.

## Mixagem e comportamento implementado

- Ponto inicial: música 80%, efeitos 80%, ambiente 45%. São controles normalizados de 0 a 100%, somados à margem de ganho de cada canal.
- Masters da composição preparados com alvo de -18 LUFS; ambiente com alvo de -23 LUFS. Limitador posterior conserva margem para a codificação. Esses são alvos do processamento; os picos decodificados são conferidos no manifesto, não presumidos a partir do comando.
- Aves têm mais 3 dB de recuo em relação ao mar. A natureza fica atrás da música e pode ser reduzida até silêncio.
- Um player fixo por função: música, narração, efeitos do mundo, passos, interface, mar e aves. Um efeito de menu não interrompe uma machadada ou um passo.
- Troca musical baixa a faixa em 220 ms e sobe a próxima em 650 ms. Ambiente entra e sai em 600 ms. Trocas rápidas cancelam a transição anterior.
- Selecionar novamente a mesma faixa ou reentrar no menu preserva a posição. Os três loops usam repetição nativa; o loop musical já contém sua ponte no arquivo.
- A prévia de ambiente dura seis segundos e restaura a seleção anterior. Repetir a prévia reutiliza canais; mute e volume continuam valendo. Fora do menu, ela encerra os canais ao terminar.
- Ao entrar no mundo, o ambiente da entrada é encerrado. A narração existente continua não bloqueante.
- Movimento de menu tem intervalo mínimo de 65 ms para evitar uma rajada sonora ao percorrer controles.

## Governança e reversibilidade

`user://audio.cfg` guarda preferências locais, separado do slot e de `Jogo`. Começar uma partida ou carregar um save não deve alterar o gosto audiovisual da pessoa.

| Preferência | Opções |
|---|---|
| Música do menu | 1: Introdução ao Vale; 2: Pôr do Sol; 3: Brisa do Recôncavo; 4: Maré de chegada |
| Efeitos de interface | 1: originais; 2: Madeira & papel |
| Ambiente do menu | 0: desligado; 1: mar; 2: aves; 3: ambos |
| Mixagem | Música, efeitos e ambiente de forma independente; mute geral |

A quarta trilha é o padrão apenas quando o asset existe; ausência do novo master recai na introdução original. Efeitos novos ausentes recaem nos legados. A governança permite uma futura seleção editorial administrativa, mas volume, mute, redução de estímulos e comparações disponíveis continuam explícitos nesta versão.

Toda inclusão futura deve trazer fonte, prompt, tratamento, região narrativa, prévia, opção anterior preservada e limite de ganho. Não substituir um nome de arquivo legado pelo áudio novo: isso tornaria impossível comparar as versões com segurança.

## Próximas fases narrativas

| Momento | Direção proposta, ainda não implementada |
|---|---|
| Roçado e vida comunitária | Variações pequenas do motivo de chegada, espaço para ofícios e conversas |
| Caminho pela mata — capítulo 6 | Menos instrumentação; afastar lentamente o mar e aproximar folhas e aves |
| Convite e fazenda | Silêncio e textura de madeira, com tensão harmônica contida |
| Matinta e perseguição — capítulo 7 | Motivo próprio e assobio narrativo, nunca misturado ao loop de aves do menu |
| Armas de safira e libertação | Resolução do motivo em registro luminoso, sustentando a agência dos personagens |

Assobios de Matinta e o horror da fazenda não viram decoração da entrada. A escravidão não ganha efeito de recompensa, som cômico ou textura espetacular. Os capítulos reservam esses momentos para uma direção narrativa específica.

## Verificação

[testar-audio.gd](../tools/elevenlabs/testar-audio.gd) valida assets, duração, persistência, legado, mute, limites de volume, trocas rápidas, continuidade, prévia e ausência de players duplicados. O teste recusa gravar fora de um `APPDATA` isolado dentro de `res://scratch/`. Também são conferidos duração e picos decodificados dos arquivos. Uma aprovação auditiva em caixas e fones continua sendo a etapa editorial para futuras revisões da composição e da mistura.
