# Gera no LTX os vídeos da edição Tripothon, a partir das pinturas do vale:
#   - o sobrevoo em laço da primeira tela de carregamento (bg1 a bg3);
#   - a cinemática de abertura (c1 a c5).
# Cada clipe é um image-to-video de 8 s em 1920x1080 (ltx-2-5-pro, sem áudio): 64 s,
# cerca de US$ 11 em 05/10/2026. Os clipes e a montagem ficam em .assets-raw/ltx/
# (fora do Git); compor_videos.py monta os laços e as versões para o jogo e o site.
#
# Uso:  powershell -NoProfile -ExecutionPolicy Bypass -File tools\ltx\gerar-videos-tripothon.ps1 [-So bg1,c3]

param([string[]] $So = @())

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\ltx.ps1"
$raiz = Get-RaizDoProjeto
$site = Join-Path (Split-Path $raiz -Parent) "myths-valley-APP\public\images"
$base = Join-Path $raiz ".assets-raw\ltx"
$entrada = Join-Path $base "entrada"
$clipes = Join-Path $base "clipes"
$log = Join-Path $base "log.txt"
New-Item -ItemType Directory -Force $entrada, $clipes | Out-Null
$ffmpeg = "C:\Program Files\ffmpeg\bin\ffmpeg.exe"

function Registrar([string] $texto) {
    $linha = "{0}  {1}" -f (Get-Date).ToString("HH:mm:ss"), $texto
    Add-Content -Path $log -Value $linha -Encoding UTF8
    Write-Output $linha
}

$estilo = "Hand-painted oil-on-canvas look with visible brush strokes, warm natural light, Brazilian Reconcavo coastal fishing village in 1887, calm and majestic, smooth steady cinematic camera, no text, no captions, no watermark."
$clipes_plano = @(
    @{ nome = "bg1"; imagem = "$raiz\assets\prototipo_3d\identidade\capa_dia.webp"; camera = "dolly_in";
       prompt = "Slow aerial flyover gliding forward over the painted valley at morning: clay-tile roofs, a white colonial church, palm trees and forested hills by a calm bay, gentle parallax, a few birds far away. $estilo" },
    @{ nome = "bg2"; imagem = "$site\pinturas\vista_aerea_vila_manha.webp"; camera = "dolly_right";
       prompt = "Aerial drone shot drifting slowly sideways over the painted village rooftops in soft morning haze, palm fronds swaying gently in the breeze, smoke rising from a chimney. $estilo" },
    @{ nome = "bg3"; imagem = "$site\pinturas\vista_alta_orla.webp"; camera = "dolly_in";
       prompt = "High aerial view flying slowly along a painted tropical shoreline with a wooden pier, fishing canoes and mangroves, small waves rolling onto the sand. $estilo" },
    @{ nome = "c1"; imagem = "$site\pinturas\vista_do_mar_igreja.webp"; camera = "dolly_in";
       prompt = "Opening shot from the sea at dawn: the camera glides slowly toward the painted village with its white church on the shore, light mist over calm water, a wooden sailing boat crossing in the foreground. $estilo" },
    @{ nome = "c2"; imagem = "$site\pinturas\pier_17h_120.webp"; camera = "dolly_right";
       prompt = "Golden hour at the painted wooden pier, fishing canoes rocking gently on the water, warm low sunlight, the camera moves slowly sideways. $estilo" },
    @{ nome = "c3"; imagem = "$site\pinturas\praca_07h_040.webp"; camera = "dolly_in";
       prompt = "Morning in the painted village square: villagers walking calmly, chickens pecking the ground, smoke from a clay oven, slow push-in toward the houses. $estilo" },
    @{ nome = "c4"; imagem = "$site\pinturas\igreja_07h_150.webp"; camera = "jib_up";
       prompt = "The painted white colonial church with its bell tower under a bright tropical sky, the camera rises slowly to reveal the tower, birds crossing the sky. $estilo" },
    @{ nome = "c5"; imagem = "$site\pinturas\casa_de_taipa_20h_045.webp"; camera = "dolly_out";
       prompt = "Night over a painted wattle-and-daub house, warm lamplight glowing in the window, starry sky, palm silhouettes, the camera pulls back slowly, calm and mysterious. $estilo" }
)
if ($So.Count -gt 0) { $clipes_plano = @($clipes_plano | Where-Object { $So -contains $_.nome }) }

# 1. As pinturas viram 1920x1080 em JPEG (recorte central 16:9), o quadro de partida.
foreach ($c in $clipes_plano) {
    $jpg = Join-Path $entrada ($c.nome + ".jpg")
    & $ffmpeg -y -loglevel error -i $c.imagem -vf "scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080" -q:v 2 $jpg
    if (-not (Test-Path $jpg)) { throw "Não converti a pintura de $($c.nome)" }
    $c.jpg = $jpg
}
Registrar ("pinturas preparadas: " + (($clipes_plano | ForEach-Object { $_.nome }) -join ", "))

# 2. Envia todos; a fila do LTX tem limite de concorrência (429): espera e tenta de novo.
$jobs = @()
foreach ($c in $clipes_plano) {
    $destino = Join-Path $clipes ($c.nome + ".mp4")
    if (Test-Path $destino) { Registrar "$($c.nome): já existe, pulo"; continue }
    $id = $null
    for ($tentativa = 1; $tentativa -le 40 -and -not $id; $tentativa++) {
        try {
            $id = Submit-LTXImagemParaVideo -Imagem $c.jpg -Descricao $c.prompt -Camera $c.camera -Duracao 8
            Registrar "$($c.nome): enviado (job $id)"
        } catch {
            $codigo = 0
            try { $codigo = [int]$_.Exception.Response.StatusCode } catch {}
            $detalhe = if ($_.ErrorDetails) { $_.ErrorDetails.Message } else { $_.Exception.Message }
            Registrar "$($c.nome): envio recusado ($codigo) $detalhe"
            if ($codigo -eq 429 -or $codigo -ge 500 -or $codigo -eq 0) { Start-Sleep -Seconds 45 } else { break }
        }
    }
    if ($id) { $jobs += @{ nome = $c.nome; id = $id; destino = $destino } }
}

# 3. Espera e baixa cada um.
foreach ($j in $jobs) {
    try {
        $fim = Wait-LTXVideo -Id $j.id -Destino $j.destino
        Registrar "$($j.nome): $fim"
    } catch {
        $detalhe = if ($_.ErrorDetails) { $_.ErrorDetails.Message } else { $_.Exception.Message }
        Registrar "$($j.nome): erro ao esperar/baixar: $detalhe"
    }
}

# 4. Monta os laços e as versões do jogo e do site.
Registrar "compondo"
& python "$PSScriptRoot\compor_videos.py" $clipes (Join-Path $base "saida") 2>&1 | ForEach-Object { Registrar "$_" }
Registrar "FIM"
