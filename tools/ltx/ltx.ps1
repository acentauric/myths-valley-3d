# Cliente da API de vídeo do LTX (https://api.ltx.io, endpoints v2 assíncronos).
#
# A chave vem de LTX_API_KEY pela função Get-Chave (variável de ambiente ou .env da
# raiz); nunca é passada por argumento nem impressa. Carregue com:
#   . .\tools\ltx\ltx.ps1
#
# Fluxo da API: POST /v2/image-to-video devolve um id; GET /v2/image-to-video/{id}
# até "completed"; o vídeo sai em result.video_url (a URL expira: baixar logo).
# Cobrança por segundo gerado (ltx-2-5-pro em 1920x1080: US$ 0,17/s em 05/10/2026).

. "$PSScriptRoot\..\comum\chaves.ps1"

$script:LTXBase = "https://api.ltx.io"


function _LTXCabecalho {
    @{ "Authorization" = "Bearer " + (Get-Chave 'LTX_API_KEY'); "Content-Type" = "application/json" }
}


# Imagem local vira data URI (a API aceita até 7 MB codificados).
function ConvertTo-LTXDataUri([string] $Arquivo) {
    $ext = [IO.Path]::GetExtension($Arquivo).ToLower()
    $mime = if ($ext -eq ".png") { "image/png" } else { "image/jpeg" }
    $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($Arquivo))
    if ($b64.Length -gt 7MB) { throw "Imagem grande demais para data URI: $Arquivo" }
    return "data:$mime;base64,$b64"
}


# Envia um image-to-video e devolve o id do job. Sem áudio: as telas de carregamento
# são silenciosas.
function Submit-LTXImagemParaVideo {
    param(
        [Parameter(Mandatory)][string] $Imagem,
        [Parameter(Mandatory)][string] $Descricao,
        [string] $UltimoQuadro = "",
        [string] $Modelo = "ltx-2-5-pro",
        [int] $Duracao = 8,
        [string] $Resolucao = "1920x1080",
        [int] $Fps = 24,
        [string] $Camera = ""
    )
    $corpo = [ordered]@{
        image_uri      = (ConvertTo-LTXDataUri $Imagem)
        prompt         = $Descricao
        model          = $Modelo
        duration       = $Duracao
        resolution     = $Resolucao
        fps            = $Fps
        generate_audio = $false
    }
    if ($UltimoQuadro) { $corpo.last_frame_uri = (ConvertTo-LTXDataUri $UltimoQuadro) }
    if ($Camera) { $corpo.camera_motion = $Camera }
    $json = $corpo | ConvertTo-Json -Depth 3 -Compress
    $resposta = Invoke-RestMethod -Uri "$script:LTXBase/v2/image-to-video" -Method Post `
        -Headers (_LTXCabecalho) -Body ([Text.Encoding]::UTF8.GetBytes($json)) -TimeoutSec 180
    if (-not $resposta.id) { throw "A resposta do LTX veio sem id de job." }
    return $resposta.id
}


# Espera o job e baixa o vídeo em $Destino. Devolve "completed", "failed: ..." ou "timeout".
function Wait-LTXVideo {
    param(
        [Parameter(Mandatory)][string] $Id,
        [Parameter(Mandatory)][string] $Destino,
        [int] $TetoSegundos = 1200
    )
    $relogio = [Diagnostics.Stopwatch]::StartNew()
    while ($relogio.Elapsed.TotalSeconds -lt $TetoSegundos) {
        $estado = Invoke-RestMethod -Uri "$script:LTXBase/v2/image-to-video/$Id" -Headers (_LTXCabecalho) -TimeoutSec 60
        if ($estado.status -eq "completed") {
            $url = $estado.result.video_url
            if (-not $url) { $url = ($estado.result.PSObject.Properties | Select-Object -First 1).Value }
            $pasta = Split-Path -Parent $Destino
            if ($pasta -and -not (Test-Path $pasta)) { New-Item -ItemType Directory -Force $pasta | Out-Null }
            Invoke-WebRequest -Uri $url -OutFile $Destino -TimeoutSec 600 -UseBasicParsing
            return "completed"
        }
        if ($estado.status -eq "failed") { return "failed: " + ($estado.error | ConvertTo-Json -Compress) }
        Start-Sleep -Seconds 10
    }
    return "timeout"
}
