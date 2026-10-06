# Cliente da API de imagens do OpenAI.
#
# A chave vem do .env pela funcao Get-Chave (OPENAI_API_KEY); nunca e passada por
# argumento nem impressa. Carregue com:  . .\tools\openai\openai.ps1

. "$PSScriptRoot\..\comum\chaves.ps1"

$script:OpenAIBase = "https://api.openai.com/v1"


# Uma imagem da descricao, gravada em $Destino (PNG). Devolve o "usage" que a
# API manda de volta (tokens de entrada e saida), para a conta do que se gastou.
function New-OpenAIImagem {
    param(
        [Parameter(Mandatory)][string] $Descricao,
        [Parameter(Mandatory)][string] $Destino,
        [string] $Modelo = "gpt-image-2",
        [string] $Tamanho = "1024x1536",
        [string] $Qualidade = "medium",
        [switch] $Transparente
    )
    $corpo = @{
        model         = $Modelo
        prompt        = $Descricao
        size          = $Tamanho
        quality       = $Qualidade
        n             = 1
        output_format = "png"
    }
    # Fundo transparente (os icones do HUD, #107): o PNG sai sem fundo.
    if ($Transparente) { $corpo.background = "transparent" }
    $corpo = $corpo | ConvertTo-Json -Depth 3
    $cabecalho = @{ "Authorization" = "Bearer " + (Get-Chave 'OPENAI_API_KEY'); "Content-Type" = "application/json" }
    _GarantirPastaDe $Destino
    # O corpo vai como bytes UTF-8, como no cliente do ElevenLabs: a descricao
    # pode ter acento.
    $resposta = Invoke-RestMethod -Uri "$script:OpenAIBase/images/generations" -Method Post `
        -Headers $cabecalho -Body ([System.Text.Encoding]::UTF8.GetBytes($corpo)) -TimeoutSec 300
    $imagem = $resposta.data[0].b64_json
    if (-not $imagem) { throw "A resposta do OpenAI veio sem imagem." }
    [System.IO.File]::WriteAllBytes($Destino, [System.Convert]::FromBase64String($imagem))
    return $resposta.usage
}


function _GarantirPastaDe([string] $Arquivo) {
    $pasta = Split-Path -Parent $Arquivo
    if ($pasta -and -not (Test-Path $pasta)) { New-Item -ItemType Directory -Force $pasta | Out-Null }
}
