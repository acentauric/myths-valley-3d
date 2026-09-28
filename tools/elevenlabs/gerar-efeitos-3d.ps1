# Efeitos sonoros do 3D gerados no ElevenLabs: corrida por tipo de chao, passos na
# agua rasa e funda, e a bracada do nado.
#
#     .\tools\elevenlabs\gerar-efeitos-3d.ps1 [-Forcar]
#
# Cada som tem o silencio do comeco cortado (o passo precisa bater no tempo da
# animacao) e o pico igualado aos passos que ja existem (-17 dB).

param([switch] $Forcar)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\elevenlabs.ps1"

$raiz = Resolve-Path "$PSScriptRoot\..\.."
$pasta = "$raiz\prototipo_3d\assets\audio\efeitos"
$bruto = Join-Path $env:TEMP "mv_efeitos_3d"
New-Item -ItemType Directory -Force $bruto | Out-Null

$efeitos = @(
    @{ n = "corrida_grama";    s = 0.5; d = "a single fast running footstep on grass and dry leaves, quick heavy impact, close up, no music" },
    @{ n = "corrida_terra";    s = 0.5; d = "a single fast running footstep on a packed dirt road with small gravel, quick heavy crunch, close up, no music" },
    @{ n = "corrida_areia";    s = 0.5; d = "a single fast running footstep on loose dry beach sand, deep soft crunch, close up, no music" },
    @{ n = "corrida_madeira";  s = 0.5; d = "a single fast running footstep on old wooden pier planks, hollow knock, close up, no music" },
    @{ n = "corrida_agua";     s = 0.6; d = "a single fast running step through ankle-deep sea water, sharp splash, close up, no music" },
    @{ n = "passo_agua_funda"; s = 0.9; d = "a single slow step wading through knee-deep calm sea water, heavy slosh and swirl, close up, no music" },
    @{ n = "passo_nado";       s = 1.0; d = "a single swimming arm stroke in calm sea water, soft splash and water pouring, close up, no music" }
)

foreach ($e in $efeitos) {
    $destino = "$pasta\$($e.n).mp3"
    if ((Test-Path $destino) -and -not $Forcar) { "ja existe: $($e.n)"; continue }
    $arquivo = "$bruto\$($e.n).mp3"
    if (-not (Test-Path $arquivo) -or $Forcar) {
        New-ElevenEfeito -Descricao $e.d -Destino $arquivo -Segundos $e.s -AderenciaAoTexto 0.6 | Out-Null
    }
    $cortado = "$bruto\$($e.n)_cortado.wav"
    & ffmpeg -y -loglevel error -i $arquivo -af "silenceremove=start_periods=1:start_threshold=-45dB" $cortado
    # O ffmpeg escreve a medicao no stderr: pelo cmd, para o PowerShell nao tratar como erro.
    $medicao = cmd /c "ffmpeg -hide_banner -i `"$cortado`" -af volumedetect -f null - 2>&1"
    $pico = ($medicao | Select-String "max_volume: (-?[\d.]+)").Matches[0].Groups[1].Value
    $ganho = -17.0 - [double]$pico
    & ffmpeg -y -loglevel error -i $cortado -af "volume=$($ganho)dB" -ar 44100 -b:a 128k $destino
    $segundos = & ffprobe -v error -show_entries format=duration -of csv=p=0 $destino
    "{0}: {1:N2} s (ganho {2:N1} dB)" -f $e.n, [double]$segundos, $ganho
}
