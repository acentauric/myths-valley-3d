# Gera as falas do Pedro que moram fora do npcs_3d.json: a explicação do corpo
# (o "corpo" de data/missoes_guia.json — a vida, o fôlego e o vigor), na voz do
# guia (npcs_3d.json, "guia.voz"), com o modelo dela (eleven_v3).
#
# "Na explicação do pedro sobre a barra de stamina e similares, crie os audios
# para ele narrar." Cada fala com "audio" vira assets/audio/vozes/<audio>.mp3,
# lida do "tts" (com as marcações de interpretação do v3 entre colchetes) ou do
# "texto", e normalizada em -18 LUFS como as outras vozes. A caixa de fala toca
# cada uma junto da linha dela (`dialogo_vale.gd`, `guia_pedro.explicar_o_corpo`).
#
# Uso:  .\tools\elevenlabs\gerar-falas-do-guia.ps1 [-Forcar]
# Precisa do ffmpeg e do ffprobe no PATH.

param(
    [switch] $Forcar
)

. "$PSScriptRoot\elevenlabs.ps1"

$raiz = Resolve-Path "$PSScriptRoot\..\.."
$npcs = Get-Content "$raiz\data\npcs_3d.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$guia = Get-Content "$raiz\data\missoes_guia.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$voz = $npcs.guia.voz
$pasta = "$raiz\assets\audio\vozes"
$bruto = Join-Path $env:TEMP "mv_falas_brutas"
New-Item -ItemType Directory -Force $bruto | Out-Null

foreach ($f in $guia.corpo) {
    if (-not $f.audio) { continue }
    $destino = "$pasta\$($f.audio).mp3"
    if ((Test-Path $destino) -and -not $Forcar) { "ja existe: $($f.audio)"; continue }
    $texto = if ($f.tts) { $f.tts } else { $f.texto }
    $arquivo = "$bruto\$($f.audio).mp3"
    New-ElevenNarracao -Texto $texto -VozId $voz.id -Destino $arquivo -Modelo $voz.modelo -Estabilidade 0.5 | Out-Null
    & ffmpeg -y -loglevel error -i $arquivo -af loudnorm=I=-18:TP=-1.5:LRA=11 -ar 44100 -b:a 128k $destino
    $segundos = & ffprobe -v error -show_entries format=duration -of csv=p=0 $destino
    "{0}: {1:N1} s ({2})" -f $f.audio, [double]$segundos, $voz.nome
}
