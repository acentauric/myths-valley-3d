# Gera a voz das falas do Pedro nas missões dele que ainda não têm áudio (10/10/2026), na voz do
# guia (npcs_3d.json, "guia.voz"), com o modelo dela. A lista sai do falas_do_pedro.py (passos,
# respostas e arremates que o Pedro fala); cada fala vira assets/audio/vozes/<audio>.mp3,
# normalizada em -18 LUFS como as outras vozes, e no fim o nome do áudio entra no JSON da missão.
#
# Uso:  .\tools\elevenlabs\gerar-falas-pedro.ps1 [-SoListar]
# Precisa do ffmpeg e do ffprobe no PATH.
param(
    [switch] $SoListar
)
. "$PSScriptRoot\elevenlabs.ps1"
$raiz = Resolve-Path "$PSScriptRoot\..\.."
$npcs = Get-Content "$raiz\data\npcs_3d.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$voz = $npcs.guia.voz
$pasta = "$raiz\assets\audio\vozes"
$bruto = Join-Path $env:TEMP "mv_falas_pedro"
New-Item -ItemType Directory -Force $bruto | Out-Null
$lista = Join-Path $bruto "lista.json"
& python -I "$PSScriptRoot\falas_do_pedro.py" listar $lista
if ($SoListar) { return }
$falas = Get-Content $lista -Raw -Encoding UTF8 | ConvertFrom-Json
$feitas = 0
foreach ($f in $falas) {
    $destino = "$pasta\$($f.audio).mp3"
    if (Test-Path $destino) { "ja existe: $($f.audio)"; continue }
    $arquivo = "$bruto\$($f.audio).mp3"
    try {
        New-ElevenNarracao -Texto $f.texto -VozId $voz.id -Destino $arquivo -Modelo $voz.modelo -Estabilidade 0.5 | Out-Null
    } catch {
        "FALHOU: $($f.audio): $($_.Exception.Message)"
        continue
    }
    & ffmpeg -y -loglevel error -i $arquivo -af loudnorm=I=-18:TP=-1.5:LRA=11 -ar 44100 -b:a 128k $destino
    $segundos = & ffprobe -v error -show_entries format=duration -of csv=p=0 $destino
    $feitas += 1
    "{0}: {1:N1} s" -f $f.audio, [double]$segundos
}
"geradas: $feitas de $($falas.Count)"
& python -I "$PSScriptRoot\falas_do_pedro.py" gravar $lista
