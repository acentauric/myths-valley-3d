# Musicas do vale 3D por periodo do dia, geradas no ElevenLabs (music_v2):
# manha, tarde, noite e a trilha de tensao da mata fechada.
#
#     .\tools\elevenlabs\gerar-musicas-periodos.ps1 [-Forcar]
#
# Cada faixa sai normalizada com loudnorm (I=-16, TP=-1.5) em 44100 Hz 160k,
# para o crossfade por periodo do audio.gd nao mudar de intensidade.

param([switch] $Forcar)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\elevenlabs.ps1"

$raiz = Resolve-Path "$PSScriptRoot\..\.."
$pasta = "$raiz\assets\audio\musica"
$bruto = Join-Path $env:TEMP "mv_musicas_periodos"
New-Item -ItemType Directory -Force $bruto | Out-Null

$musicas = @(
    @{ n = "musica_manha"; d = "gentle Brazilian acoustic guitar and viola caipira duet, bright and hopeful sunrise mood by the sea, soft flute, folk, calm, no percussion" },
    @{ n = "musica_tarde"; d = "warm lazy afternoon Brazilian folk, acoustic guitar, soft hand percussion, unhurried, coastal village" },
    @{ n = "musica_noite"; d = "quiet nocturnal Brazilian lullaby, sparse acoustic guitar notes, soft strings, mysterious calm night" },
    @{ n = "musica_mata";  d = "tense mysterious forest ambience score, low drones, distant ritual drums, sparse eerie flute, Brazilian folklore horror, subtle" }
)

foreach ($m in $musicas) {
    $destino = "$pasta\$($m.n).mp3"
    if ((Test-Path $destino) -and -not $Forcar) { "ja existe: $($m.n)"; continue }
    $arquivo = "$bruto\$($m.n).mp3"
    if (-not (Test-Path $arquivo) -or $Forcar) {
        # Se a API falhar, tenta uma segunda vez e segue para a proxima faixa.
        $gerou = $false
        foreach ($tentativa in 1..2) {
            try {
                New-ElevenMusica -Descricao $m.d -Destino $arquivo -Milissegundos 75000 -Instrumental | Out-Null
                $gerou = $true
                break
            } catch {
                "falhou ($tentativa/2): $($m.n) - $($_.Exception.Message)"
                if (Test-Path $arquivo) { Remove-Item $arquivo -Force }
            }
        }
        if (-not $gerou) { continue }
    }
    & ffmpeg -y -loglevel error -i $arquivo -af "loudnorm=I=-16:TP=-1.5" -ar 44100 -b:a 160k $destino
    $segundos = & ffprobe -v error -show_entries format=duration -of csv=p=0 $destino
    "{0}: {1:N1} s" -f $m.n, [double]$segundos
}
