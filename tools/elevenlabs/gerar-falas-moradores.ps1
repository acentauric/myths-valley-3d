# Gera as falas dos moradores do 3D (ElevenLabs, modelo eleven_v3).
#
# Lê data/npcs_3d.json: o guia e cada morador têm "voz" (id da voz no
# ElevenLabs) e até 3 "falas" ({texto, tts?, audio}). "tts" é o que a voz lê, com
# marcações de interpretação do v3 entre colchetes ([sighs], [whispers]...); sem
# ele, lê o "texto" do balão. Normaliza cada arquivo em -18 LUFS, como as outras
# vozes, em assets/audio/vozes/<audio>.mp3.
#
# Uso:  .\tools\elevenlabs\gerar-falas-moradores.ps1 [-Morador tonho] [-Forcar]

param(
    [string] $Morador = "",
    [switch] $Forcar
)

. "$PSScriptRoot\elevenlabs.ps1"

$raiz = Resolve-Path "$PSScriptRoot\..\.."
$dados = Get-Content "$raiz\data\npcs_3d.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$pasta = "$raiz\assets\audio\vozes"
$bruto = Join-Path $env:TEMP "mv_falas_brutas"
New-Item -ItemType Directory -Force $bruto | Out-Null

# O guia (Pedro) entra junto: as saudações dele também sorteiam entre três falas.
$pessoas = @($dados.guia) + @($dados.moradores)
foreach ($m in $pessoas) {
    if ($Morador -and $m.id -ne $Morador) { continue }
    if (-not $m.voz -or -not $m.falas) { continue }
    foreach ($f in $m.falas) {
        $destino = "$pasta\$($f.audio).mp3"
        if ((Test-Path $destino) -and -not $Forcar) { "ja existe: $($f.audio)"; continue }
        $texto = if ($f.tts) { $f.tts } else { $f.texto }
        $arquivo = "$bruto\$($f.audio).mp3"
        New-ElevenNarracao -Texto $texto -VozId $m.voz.id -Destino $arquivo -Modelo $m.voz.modelo -Estabilidade 0.5 | Out-Null
        & ffmpeg -y -loglevel error -i $arquivo -af loudnorm=I=-18:TP=-1.5:LRA=11 -ar 44100 -b:a 128k $destino
        $segundos = & ffprobe -v error -show_entries format=duration -of csv=p=0 $destino
        "{0}: {1:N1} s ({2})" -f $f.audio, [double]$segundos, $m.voz.nome
    }
}
