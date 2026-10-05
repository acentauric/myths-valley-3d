# Gera a narração e a música da travessia (a introdução do jogo). GERAÇÃO PAGA.
#
#     .\tools\elevenlabs\gerar-travessia.ps1 -Narracao     # a narração, numa tomada só
#     .\tools\elevenlabs\gerar-travessia.ps1 -Musica       # a música de fundo nova
#
# A narração lê as legendas de `data/dialogos/pedro.json` ("travessia", em português)
# com a voz do narrador do projeto (BDM · Nelson Silvestre) no Eleven v3, numa tomada só
# para o tom não mudar de uma frase para outra. A tomada inteira fica em
# .assets-raw/elevenlabs/travessia/ (fora do git); `alinhar_travessia.py` a transcreve
# com o Whisper da OpenAI e a corta em um trecho por legenda.

param(
    [switch] $Narracao,
    [switch] $Musica,
    [int] $MusicaMs = 0
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\elevenlabs.ps1"

$raiz = Get-RaizDoProjeto
$bruto = Join-Path $raiz ".assets-raw\elevenlabs\travessia"
New-Item -ItemType Directory -Force $bruto | Out-Null

# Marcas de ritmo do v3 em frases curtas e de virada; o resto segue em tom de abertura.
$MARCAS = @{
    0 = "[calm, cinematic narration] "
    3 = "[pause] "
    8 = "[slight pause] "
}

if ($Narracao) {
    $dados = Get-Content (Join-Path $raiz "data\dialogos\pedro.json") -Raw -Encoding UTF8 | ConvertFrom-Json
    $trechos = @()
    for ($i = 0; $i -lt $dados.travessia.Count; $i++) {
        $marca = if ($MARCAS.ContainsKey($i)) { $MARCAS[$i] } else { "" }
        # Ano por extenso: com algarismos o v3 leu "1867".
        $trechos += $marca + ($dados.travessia[$i] -replace "1887", "mil oitocentos e oitenta e sete")
    }
    # Parágrafos separados: o v3 respira entre eles, e o corte por legenda cai no silêncio.
    $texto = $trechos -join "`n`n"
    $destino = Join-Path $bruto "narracao_completa.mp3"
    New-ElevenNarracao -Texto $texto -VozId "hOLl3246BMBsdy0qtYLb" -Destino $destino -Modelo "eleven_v3" -Estabilidade 0.5 | Out-Null
    Write-Host "narração: $destino ($($texto.Length) caracteres)"
}

if ($Musica) {
    if ($MusicaMs -le 0) { throw "Informe -MusicaMs com a duração da narração mais a folga." }
    $descricao = "Cinematic opening theme for a historical adventure game set in 1887 in the Reconcavo of Bahia, Brazil. " +
        "A sailing boat crosses the Bay of All Saints at dawn toward a small fishing village. " +
        "Gentle nylon-string guitar and viola caipira open softly, warm strings swell slowly, light hand percussion " +
        "and a distant berimbau texture, subtle sea atmosphere. Nostalgic, hopeful, a touch of mystery near the end. " +
        "Slow build, never busy, leaving room for a narrator voice. Instrumental, no vocals."
    $destino = Join-Path $raiz "assets\audio\musica\tema_travessia.mp3"
    New-ElevenMusica -Descricao $descricao -Destino $destino -Milissegundos $MusicaMs -Instrumental | Out-Null
    Write-Host "música: $destino ($MusicaMs ms)"
}
