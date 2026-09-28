# Sons novos do vale 3D gerados no ElevenLabs: bem-te-vi, sussurros da mata
# fechada, passos na agua (variantes _v2), lama e poca da mare baixa e o
# ataque do tubarao.
#
#     .\tools\elevenlabs\gerar-sons-vale.ps1 [-Forcar]
#
# Mesmo pos-processo dos passos existentes: corta o silencio do comeco e
# iguala o pico a -17 dB (gerar-efeitos-3d.ps1).

param([switch] $Forcar)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\elevenlabs.ps1"

$raiz = Resolve-Path "$PSScriptRoot\..\.."
$audio = "$raiz\prototipo_3d\assets\audio"
$bruto = Join-Path $env:TEMP "mv_sons_vale"
New-Item -ItemType Directory -Force $bruto | Out-Null

# p = subpasta de destino (efeitos ou ambiente); s = duracao pedida em segundos.
$sons = @(
    @{ n = "bem_te_vi_1";        p = "efeitos";  s = 1.8;  d = "great kiskadee bird call, sharp three-note whistle bem-te-vi, single bird, close, no music" },
    @{ n = "bem_te_vi_2";        p = "efeitos";  s = 1.8;  d = "great kiskadee bird call, sharp three-note whistle bem-te-vi, single bird, close, no music" },
    @{ n = "mata_sussurro_1";    p = "ambiente"; s = 7.0;  d = "unsettling deep forest at dusk: branch crack, faint whisper-like wind, distant strange animal call, sparse, no music" },
    @{ n = "mata_sussurro_2";    p = "ambiente"; s = 7.0;  d = "unsettling deep forest at dusk: branch crack, faint whisper-like wind, distant strange animal call, sparse, no music" },
    @{ n = "passo_agua_v2";      p = "efeitos";  s = 0.5;  d = "single soft footstep in ankle-deep calm sea water, gentle clean splash, close up, no music" },
    @{ n = "corrida_agua_v2";    p = "efeitos";  s = 0.55; d = "single fast running footstep in ankle-deep calm sea water, gentle clean splash, close up, no music" },
    @{ n = "passo_agua_funda_v2"; p = "efeitos"; s = 0.8;  d = "single slow wading step, knee deep calm sea water, smooth slosh, close up, no music" },
    @{ n = "passo_lama";         p = "efeitos";  s = 0.6;  d = "single footstep in wet sticky tidal mud, deep squelch, close, no music" },
    @{ n = "corrida_lama";       p = "efeitos";  s = 0.55; d = "single fast running footstep in wet sticky tidal mud, quick deep squelch, close, no music" },
    @{ n = "passo_poca";         p = "efeitos";  s = 0.5;  d = "single footstep splashing a small shallow tide puddle on mud, close, no music" },
    @{ n = "tubarao_ataque";     p = "efeitos";  s = 1.6;  d = "sudden violent water splash and thrashing burst, heavy churn, no voice, no music" }
)

foreach ($e in $sons) {
    $destino = "$audio\$($e.p)\$($e.n).mp3"
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
    & ffmpeg -y -loglevel error -i $arquivo -af "silenceremove=start_periods=1:start_threshold=-45dB" $cortado
    # O ffmpeg escreve a medicao no stderr: pelo cmd, para o PowerShell nao tratar como erro.
    $medicao = cmd /c "ffmpeg -hide_banner -i `"$cortado`" -af volumedetect -f null - 2>&1"
    $pico = ($medicao | Select-String "max_volume: (-?[\d.]+)").Matches[0].Groups[1].Value
    $ganho = -17.0 - [double]$pico
    & ffmpeg -y -loglevel error -i $cortado -af "volume=$($ganho)dB" -ar 44100 -b:a 128k $destino
    $segundos = & ffprobe -v error -show_entries format=duration -of csv=p=0 $destino
    "{0}: {1:N2} s (ganho {2:N1} dB)" -f $e.n, [double]$segundos, $ganho
}
