# Cliente da API do PixelLab (https://api.pixellab.ai/v2/docs).
#
# A chave vem do .env pela fun��o Get-Chave; nunca � passada por argumento nem
# impressa. Carregue com:  . .\tools\pixellab\pixellab.ps1

. "$PSScriptRoot\..\comum\chaves.ps1"
. "$PSScriptRoot\cofre.ps1"

$script:PixelLabBase = "https://api.pixellab.ai/v2"


function Get-PixelLabCabecalho {
    @{ Authorization = "Bearer $(Get-Chave 'PIXELLAB_API_KEY')"; "Content-Type" = "application/json" }
}


function Get-PixelLabSaldo {
    Invoke-RestMethod -Uri "$script:PixelLabBase/balance" -Headers (Get-PixelLabCabecalho) -Method Get
}


# Imagem avulsa (modelo Pixflux). � o endpoint mais barato.
function New-PixelLabImagem {
    param(
        [Parameter(Mandatory)][string] $Descricao,
        [Parameter(Mandatory)][string] $Destino,
        [int] $Largura = 32,
        [int] $Altura = 32,
        [string] $Visao = "low top-down",
        [string] $Contorno = "single color black outline",
        [string] $Sombreado = "basic shading",
        [string] $Detalhe = "low detail",
        [int] $Semente = 0,
        [switch] $SemFundo
    )

    # A descricao e a semente ficam marcadas ANTES da chamada, para o
    # cofre saber o que foi pedido quando os bytes chegarem. Ver cofre.ps1.
    Marcar-Geracao $Descricao $Semente

    $corpo = @{
        description   = $Descricao
        image_size    = @{ width = $Largura; height = $Altura }
        view          = $Visao
        outline       = $Contorno
        shading       = $Sombreado
        detail        = $Detalhe
        no_background = [bool]$SemFundo
    }
    if ($Semente -gt 0) { $corpo.seed = $Semente }

    $resposta = Invoke-RestMethod -Uri "$script:PixelLabBase/create-image-pixflux" `
        -Headers (Get-PixelLabCabecalho) -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes(($corpo | ConvertTo-Json -Depth 5)))

    _SalvarBase64 $resposta.image.base64 $Destino
    return $resposta.usage
}


# Personagem com as 4 dire��es (sul, leste, norte, oeste).
# � ass�ncrono: cria o pedido, espera o job e baixa cada rota��o.
# Salva como <Destino>_sul.png, _leste.png, _norte.png, _oeste.png.
function New-PixelLabPersonagem4 {
    param(
        [Parameter(Mandatory)][string] $Descricao,
        [Parameter(Mandatory)][string] $Destino,   # caminho sem extens�o
        [int] $Tamanho = 32,
        [string] $Visao = "low top-down",
        [string] $Contorno = "single color black outline",
        [string] $Sombreado = "basic shading",
        [string] $Detalhe = "low detail",
        [int] $Semente = 0,
        [int] $EsperaMaximaSegundos = 300
    )

    # A descricao e a semente ficam marcadas ANTES da chamada, para o
    # cofre saber o que foi pedido quando os bytes chegarem. Ver cofre.ps1.
    Marcar-Geracao $Descricao $Semente

    $corpo = @{
        description = $Descricao
        image_size  = @{ width = $Tamanho; height = $Tamanho }
        view        = $Visao
        outline     = $Contorno
        shading     = $Sombreado
        detail      = $Detalhe
    }
    if ($Semente -gt 0) { $corpo.seed = $Semente }

    $cabecalho = Get-PixelLabCabecalho
    $pedido = Invoke-RestMethod -Uri "$script:PixelLabBase/create-character-with-4-directions" `
        -Headers $cabecalho -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes(($corpo | ConvertTo-Json -Depth 5)))

    Write-Host "  job $($pedido.background_job_id) � esperando..."
    if (-not $pedido.background_job_id -or -not $pedido.character_id) { throw "Resposta sem identificadores de job/personagem." }
    $concluido = $false
    $limite = (Get-Date).AddSeconds($EsperaMaximaSegundos)
    while ((Get-Date) -lt $limite) {
        Start-Sleep -Seconds 6
        $job = Invoke-RestMethod -Uri "$script:PixelLabBase/background-jobs/$($pedido.background_job_id)" `
            -Headers $cabecalho -Method Get
        if ($job.status -in @("completed", "succeeded", "done")) { $concluido = $true; break }
        if ($job.status -in @("failed", "error", "cancelled")) {
            throw "Job $($pedido.background_job_id) falhou: $($job.status)"
        }
    }

    if (-not $concluido) { throw "Job $($pedido.background_job_id) nao terminou em $EsperaMaximaSegundos s; consulte o job antes de gerar novamente." }

    $personagem = Invoke-RestMethod -Uri "$script:PixelLabBase/characters/$($pedido.character_id)" `
        -Headers $cabecalho -Method Get

    $pasta = Split-Path $Destino -Parent
    if ($pasta -and -not (Test-Path $pasta)) { New-Item -ItemType Directory -Force $pasta | Out-Null }

    $salvos = 0
    foreach ($direcao in $personagem.rotation_urls.PSObject.Properties) {
        # A API devolve chaves extras (diagonais) com valor nulo; ignore.
        if ([string]::IsNullOrWhiteSpace($direcao.Value)) { continue }
        $nome = switch ($direcao.Name) {
            "south" { "sul" }; "north" { "norte" }
            "east"  { "leste" }; "west" { "oeste" }
            default { $direcao.Name }
        }
        Invoke-WebRequest -Uri $direcao.Value -OutFile "${Destino}_$nome.png" -TimeoutSec 120
        Guardar-NoCofre "${Destino}_$nome.png"
        $salvos++
    }
    if ($salvos -eq 0) { throw "O personagem ficou sem rotation_urls: $($personagem | ConvertTo-Json -Compress -Depth 3)" }

    return [pscustomobject]@{ usage = $pedido.usage; character_id = $pedido.character_id; direcoes = $salvos }
}


function _SalvarBase64 {
    param([string] $Base64, [string] $Destino)
    if ([string]::IsNullOrWhiteSpace($Base64)) { throw "A API nao retornou imagem; destino preservado." }
    $pasta = Split-Path $Destino -Parent
    if ($pasta -and -not (Test-Path $pasta)) { New-Item -ItemType Directory -Force $pasta | Out-Null }
    [System.IO.File]::WriteAllBytes($Destino, [Convert]::FromBase64String($Base64))
    # TODA ARTE QUE CUSTOU CREDITO FICA GUARDADA. Ver cofre.ps1.
    Guardar-NoCofre $Destino
}
