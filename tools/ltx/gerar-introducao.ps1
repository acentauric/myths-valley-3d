# Gera no LTX os clipes da introdução ("A travessia", #129): um image-to-video por
# trecho da narração, com o plano de tools/ltx/introducao_plano.json (imagem de partida,
# câmera, prompt e duração de cada trecho). Mesma identidade dos clipes do lobby e do
# site (gerar-videos-tripothon.ps1): pintura a óleo, luz quente, câmera lenta.
#
# Custo: ltx-2-5-pro em 1920x1080, US$ 0,17/s (05/10/2026). O plano de 09/10 tem 82 s,
# cerca de US$ 14. O script registra a estimativa antes de enviar e recusa passar do
# teto (-TetoDolares). Os clipes e o log ficam em .assets-raw/ltx/introducao/ (fora do
# Git); compor_introducao.py monta a prévia e a versão do jogo.
#
# Uso:  powershell -NoProfile -ExecutionPolicy Bypass -File tools\ltx\gerar-introducao.ps1 [-So 1,9] [-SoEstimar]

param([int[]] $So = @(), [switch] $SoEstimar, [double] $TetoDolares = 40)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\ltx.ps1"
$raiz = Get-RaizDoProjeto
$base = Join-Path $raiz ".assets-raw\ltx\introducao"
$entrada = Join-Path $base "entrada"
$clipes = Join-Path $base "clipes"
$log = Join-Path $base "log.txt"
New-Item -ItemType Directory -Force $entrada, $clipes | Out-Null
$ffmpeg = "C:\Program Files\ffmpeg\bin\ffmpeg.exe"
$DOLAR_POR_SEGUNDO = 0.17

function Registrar([string] $texto) {
    $linha = "{0}  {1}" -f (Get-Date).ToString("HH:mm:ss"), $texto
    Add-Content -Path $log -Value $linha -Encoding UTF8
    # Write-Host, e não Write-Output: dentro de uma função, a saída viraria o retorno dela.
    Write-Host $linha
}

$plano = Get-Content (Join-Path $PSScriptRoot "introducao_plano.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$trechos = @($plano.trechos)
if ($So.Count -gt 0) { $trechos = @($trechos | Where-Object { $So -contains [int]$_.trecho }) }

function Nome($t) { "trecho_{0:D2}" -f [int]$t.trecho }

# 0. Estimativa (só do que ainda falta gerar).
$faltam = @($trechos | Where-Object { -not (Test-Path (Join-Path $clipes ((Nome $_) + ".mp4"))) })
$segundos = ($faltam | Measure-Object -Property duracao_clipe -Sum).Sum
if (-not $segundos) { $segundos = 0 }
$custo = [math]::Round($segundos * $DOLAR_POR_SEGUNDO, 2)
Registrar "estimativa: $($faltam.Count) clipes, $segundos s em $($plano.modelo) $($plano.resolucao), US$ $custo"
if ($custo -gt $TetoDolares) { throw "Estimativa US$ $custo passa do teto US$ $TetoDolares." }
if ($SoEstimar) { return }

# 1. A imagem de partida vira 1920x1080 em JPEG (recorte opcional, depois o centro 16:9).
foreach ($t in $faltam) {
    $jpg = Join-Path $entrada ((Nome $t) + ".jpg")
    $origem = Join-Path $raiz $t.imagem
    $filtro = "scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080"
    if ($t.recorte) { $filtro = "$($t.recorte)," + $filtro }
    & $ffmpeg -y -loglevel error -i $origem -vf $filtro -q:v 2 $jpg
    if (-not (Test-Path $jpg)) { throw "Não converti a imagem do $(Nome $t)" }
    $t | Add-Member -NotePropertyName jpg -NotePropertyValue $jpg -Force
}

function Enviar($t) {
    $prompt = "$($t.prompt) $($plano.estilo)"
    for ($tentativa = 1; $tentativa -le 40; $tentativa++) {
        try {
            $id = Submit-LTXImagemParaVideo -Imagem $t.jpg -Descricao $prompt -Camera $t.camera `
                -Duracao ([int]$t.duracao_clipe) -Modelo $plano.modelo -Resolucao $plano.resolucao
            Registrar "$(Nome $t): enviado (job $id, $($t.duracao_clipe) s)"
            return $id
        } catch {
            $codigo = 0
            try { $codigo = [int]$_.Exception.Response.StatusCode } catch {}
            $detalhe = if ($_.ErrorDetails) { $_.ErrorDetails.Message } else { $_.Exception.Message }
            Registrar "$(Nome $t): envio recusado ($codigo) $detalhe"
            # A fila do LTX tem limite de concorrência (429): espera e tenta de novo.
            if ($codigo -eq 429 -or $codigo -ge 500 -or $codigo -eq 0) { Start-Sleep -Seconds 45 } else { return $null }
        }
    }
    return $null
}

function Esperar($t, $id) {
    $destino = Join-Path $clipes ((Nome $t) + ".mp4")
    try { return (Wait-LTXVideo -Id $id -Destino $destino) }
    catch { return "erro: " + $(if ($_.ErrorDetails) { $_.ErrorDetails.Message } else { $_.Exception.Message }) }
}

# 2. Envia todos, espera cada um; um job que falha é reenviado uma vez.
$jobs = @()
foreach ($t in $faltam) {
    $id = Enviar $t
    if ($id) { $jobs += @{ t = $t; id = $id } }
}
$gasto = 0.0
foreach ($j in $jobs) {
    $fim = Esperar $j.t $j.id
    Registrar "$(Nome $j.t): $fim"
    if ($fim -ne "completed") {
        $id = Enviar $j.t
        if ($id) { $fim = Esperar $j.t $id; Registrar "$(Nome $j.t) (2a tentativa): $fim" }
    }
    if ($fim -eq "completed") { $gasto += [double]$j.t.duracao_clipe * $DOLAR_POR_SEGUNDO }
}
Registrar ("gasto estimado nesta rodada: US$ {0:N2}" -f $gasto)
Registrar "FIM"
