# Os sons que o vale 3D tinha de ter e nao tinha (playtest da Build 9B, 05/10/2026: "adicione o
# efeito sonoro de marretada na pedra e os demais faltantes"), gerados no ElevenLabs Sound
# Effects. Cada nome e o que o CODIGO ja espera:
#
#   marretada_pedra, pedra_quebra, foice_capim, catar_ostra, galho_quebra
#       a colheita (scripts/prototipo_3d/recursos_3d.gd: SONS_DO_GOLPE e SONS_DO_ULTIMO).
#       Sem o arquivo a tabela cai no som de antes (picareta, colher, pegar); com ele, toca sozinho.
#   menu_negado
#       a mochila recusa uma acao (scripts/ui/mochila.gd chama Audio.efeito("menu_negado")).
#   fantasma_sussurro, fantasma_avanco, curupira_assobio, mapa_doido
#       os sustos da mata (a nova fatia "sustos"): o sussurro frio, o avanco do vulto, o
#       assobio do Curupira e o redemoinho do mapa que enlouquece.
#
# porta_abrir e porta_fechar ja existem (as portas das casas e da igreja so precisam ser
# ligadas em interiores.gd) e nao se gera de novo.
#
#     .\tools\elevenlabs\gerar-sons-que-faltam.ps1 [-Forcar]
#
# GASTA CREDITO (um efeito por nome; os brutos ficam em %TEMP%\mv_sons_que_faltam e um
# novo pos-processamento nao paga de novo). A chave vem de tools/comum/chaves.ps1 e nunca
# e impressa.
#
# Pos-processo (o de gerar-efeitos-3d.ps1, com a medida de volume trocada): corta o silencio do
# comeco (o golpe precisa bater NO TEMPO da animacao), poe um fade de 40 ms no fim para nao
# estalar e limita a duracao de cada som (0,5 a 2,5 s; os sussurros e o assobio vao a 4 s).
#
# O VOLUME NAO E O DOS PASSOS (pico em -17 dB). Os passos sao miudos de proposito; os golpes de
# trabalho tocam ao lado do machado, do arar e da porta, que sao quentes (RMS de -20 a -27 dB), e
# um golpe unico de pico em -17 dB fica em -41 dB de RMS: so se ouve com o resto do jogo mudo. Aqui
# cada som diz o que mede: `pico` (golpes: o pico vai a esse valor, e o corpo vem junto) ou
# `medio` (sons que duram: o volume medio vai a esse valor), e nenhum passa de -3 dB de pico
# antes do mp3 (a codificacao soma ate 3 dB).

param([switch] $Forcar)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\elevenlabs.ps1"

$raiz = Resolve-Path "$PSScriptRoot\..\.."
$pasta = "$raiz\assets\audio\efeitos"
$bruto = Join-Path $env:TEMP "mv_sons_que_faltam"
New-Item -ItemType Directory -Force $bruto | Out-Null

# n = nome do arquivo; s = duracao pedida (s); max = teto depois do corte (s); pico OU medio = o
# volume alvo em dB (ver acima); d = descricao.
$sons = @(
    @{ n = "marretada_pedra";    s = 1.0; max = 1.0; pico = -4;   d = "a single heavy sledgehammer blow striking solid rock, sharp stone crack with a short ringing thud, dry, close up, no echo, no voice, no music" },
    @{ n = "pedra_quebra";       s = 2.0; max = 2.0; pico = -4;   d = "a large rock splitting apart after a final hard blow, a deep crack and then stone fragments tumbling and settling, close up, no voice, no music" },
    @{ n = "foice_capim";        s = 0.9; max = 0.9; medio = -27; d = "a single sickle swing cutting through tall dry grass, a quick swish and the crisp rustle of cut stalks, close up, no voice, no music" },
    @{ n = "catar_ostra";        s = 1.0; max = 1.0; pico = -5;   d = "picking an oyster off a wet rock in shallow sea water, a shell clacking free and a small splash, close up, no voice, no music" },
    @{ n = "galho_quebra";       s = 0.9; max = 0.9; pico = -4;   d = "a dry tree branch snapping and splintering in two, one sharp crack, close up, no voice, no music" },
    @{ n = "menu_negado";        s = 0.6; max = 0.6; medio = -24; d = "a short dull wooden thunk, a soft negative refusal interface sound, two quick low knocks, no voice, no music" },
    @{ n = "fantasma_sussurro";  s = 4.0; max = 4.0; medio = -31; d = "a cold breathy ghostly whisper, airy and unintelligible, no clear words, eerie forest night, no music" },
    @{ n = "fantasma_avanco";    s = 1.4; max = 1.4; medio = -28; d = "a rushing ghostly whoosh, a fast spectral rush of cold wind sweeping toward the listener, short and sudden, eerie, no voice, no music" },
    @{ n = "curupira_assobio";   s = 4.0; max = 4.0; medio = -29; d = "an eerie high-pitched whistle echoing through a dark jungle, a lone strange folklore creature whistling two slow rising notes, no music" },
    @{ n = "mapa_doido";         s = 1.6; max = 1.6; medio = -29; d = "a dissonant disorienting swirl, a warped detuned sliding tone that spins and wobbles, uncanny and short, no voice, no music" }
)

foreach ($e in $sons) {
    $destino = "$pasta\$($e.n).mp3"
    if ((Test-Path $destino) -and -not $Forcar) { "ja existe: $($e.n)"; continue }
    $arquivo = "$bruto\$($e.n).mp3"
    if (-not (Test-Path $arquivo) -or $Forcar) {
        # Se a API falhar, tenta uma segunda vez e segue para o proximo som.
        $gerou = $false
        foreach ($tentativa in 1..2) {
            try {
                New-ElevenEfeito -Descricao $e.d -Destino $arquivo -Segundos $e.s -AderenciaAoTexto 0.6 | Out-Null
                $gerou = $true
                break
            } catch {
                "falhou ($tentativa/2): $($e.n) - $($_.Exception.Message)"
                if (Test-Path $arquivo) { Remove-Item $arquivo -Force }
            }
        }
        if (-not $gerou) { continue }
    }
    $cortado = "$bruto\$($e.n)_cortado.wav"
    & ffmpeg -y -loglevel error -i $arquivo -af "silenceremove=start_periods=1:start_threshold=-45dB" -t $e.max $cortado
    # O ffmpeg escreve a medicao no stderr: pelo cmd, para o PowerShell nao tratar como erro.
    $medicao = cmd /c "ffmpeg -hide_banner -i `"$cortado`" -af volumedetect -f null - 2>&1"
    $pico = [double]($medicao | Select-String "max_volume: (-?[\d.]+)").Matches[0].Groups[1].Value
    $medio_atual = [double]($medicao | Select-String "mean_volume: (-?[\d.]+)").Matches[0].Groups[1].Value
    if ($e.ContainsKey("pico")) { $ganho = [double]$e.pico - $pico } else { $ganho = [double]$e.medio - $medio_atual }
    # Teto: nenhum som passa de -3 dB de pico (o mp3 ainda soma ate 3 dB).
    $ganho = [Math]::Min($ganho, -3.0 - $pico)
    $duracao = [double](& ffprobe -v error -show_entries format=duration -of csv=p=0 $cortado)
    $inicio_do_fade = [Math]::Max($duracao - 0.04, 0.0)
    & ffmpeg -y -loglevel error -i $cortado -af "volume=$($ganho)dB,afade=t=out:st=$($inicio_do_fade):d=0.04" -ar 44100 -b:a 128k $destino
    $segundos = & ffprobe -v error -show_entries format=duration -of csv=p=0 $destino
    "{0}: {1:N2} s (ganho {2:N1} dB)" -f $e.n, [double]$segundos, $ganho
}
