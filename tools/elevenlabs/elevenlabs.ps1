# Cliente da API do ElevenLabs.
#
# A chave vem do .env pela funcao Get-Chave; nunca e passada por argumento nem
# impressa. Carregue com:  . .\tools\elevenlabs\elevenlabs.ps1
#
# Observacao: a chave do projeto tem escopo restrito. /v1/voices, a sintese de
# fala, os efeitos sonoros e a musica funcionam; /v1/user e /v1/models devolvem
# 401. Por isso nao da para consultar a cota por aqui.

. "$PSScriptRoot\..\comum\chaves.ps1"

$script:ElevenBase = "https://api.elevenlabs.io/v1"


function Get-ElevenCabecalho {
    @{ "xi-api-key" = (Get-Chave 'ELEVENLABS_API_KEY'); "Content-Type" = "application/json" }
}


function Get-ElevenVozes {
    (Invoke-RestMethod -Uri "$script:ElevenBase/voices" -Headers (Get-ElevenCabecalho) -Method Get).voices
}


# Narracao. O modelo multilingue e o que fala portugues direito.
function New-ElevenNarracao {
    param(
        [Parameter(Mandatory)][string] $Texto,
        [Parameter(Mandatory)][string] $VozId,
        [Parameter(Mandatory)][string] $Destino,
        [string] $Modelo = "eleven_multilingual_v2",
        [double] $Estabilidade = 0.45,
        [double] $Similaridade = 0.8
    )
    $corpo = @{
        text     = $Texto
        model_id = $Modelo
        voice_settings = @{ stability = $Estabilidade; similarity_boost = $Similaridade }
    } | ConvertTo-Json -Depth 4

    _GarantirPasta $Destino
    # O corpo vai como bytes UTF-8: senao os acentos do portugues sobem errados
    # e a API responde 400.
    Invoke-WebRequest -Uri "$script:ElevenBase/text-to-speech/$VozId" `
        -Headers (Get-ElevenCabecalho) -Method Post `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($corpo)) -OutFile $Destino -TimeoutSec 180
}


function New-ElevenEfeito {
    param(
        [Parameter(Mandatory)][string] $Descricao,
        [Parameter(Mandatory)][string] $Destino,
        [double] $Segundos = 2.0,
        [double] $AderenciaAoTexto = 0.4,
        [switch] $Loop,
        [string] $Modelo = "eleven_text_to_sound_v2"
    )
    $corpo = @{
        text             = $Descricao
        duration_seconds = $Segundos
        prompt_influence = $AderenciaAoTexto
        model_id         = $Modelo
        loop             = [bool]$Loop
    } | ConvertTo-Json

    _GarantirPasta $Destino
    Invoke-WebRequest -Uri "$script:ElevenBase/sound-generation" `
        -Headers (Get-ElevenCabecalho) -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes($corpo)) -OutFile $Destino -TimeoutSec 240
}


function New-ElevenMusica {
    param(
        [Parameter(Mandatory)][string] $Descricao,
        [Parameter(Mandatory)][string] $Destino,
        [int] $Milissegundos = 40000,
        [string] $Modelo = "music_v2",
        [switch] $Instrumental
    )
    $corpo = @{
        prompt = $Descricao
        music_length_ms = $Milissegundos
        model_id = $Modelo
        force_instrumental = [bool]$Instrumental
    } | ConvertTo-Json

    _GarantirPasta $Destino
    Invoke-WebRequest -Uri "$script:ElevenBase/music" `
        -Headers (Get-ElevenCabecalho) -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes($corpo)) -OutFile $Destino -TimeoutSec 600
}


function _GarantirPasta {
    param([string] $Destino)
    $pasta = Split-Path $Destino -Parent
    if ($pasta -and -not (Test-Path $pasta)) { New-Item -ItemType Directory -Force $pasta | Out-Null }
}
