# Gera no LTX os clipes do teaser do Tripothon a partir das tomadas do próprio jogo:
# cada clipe é um image-to-video que parte do primeiro quadro de uma tomada gravada
# por tools/teaser/diretor.gd (tools/ltx/teaser/entrada/<nome>.jpg), com o prompt e a
# câmera de tools/ltx/teaser/plano.json. O entardecer leva também o último quadro, para
# o LTX ir do dia à noite como a tomada do jogo.
#
# Custo: ltx-2-5-pro em 1920x1080, US$ 0,17/s (05/10/2026). O plano de 13/10 tem 9
# clipes de 6 s, cerca de US$ 9,20. O script registra a estimativa antes de enviar e
# recusa passar do teto (-TetoDolares). Clipes e log ficam em .assets-raw/ltx/teaser/
# (fora do Git); a montagem com o áudio e as legendas é tools/teaser/montar.py.
#
# Uso:  powershell -NoProfile -ExecutionPolicy Bypass -File tools\ltx\gerar-teaser.ps1 [-So igreja,mata] [-SoEstimar]

param([string[]] $So = @(), [switch] $SoEstimar, [double] $TetoDolares = 15)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\ltx.ps1"
$raiz = Get-RaizDoProjeto
$plano = Get-Content -Raw -Encoding UTF8 (Join-Path $PSScriptRoot "teaser\plano.json") | ConvertFrom-Json
$entrada = Join-Path $PSScriptRoot "teaser\entrada"
$base = Join-Path $raiz ".assets-raw\ltx\teaser"
$clipes = Join-Path $base "clipes"
$log = Join-Path $base "log.txt"
New-Item -ItemType Directory -Force $clipes | Out-Null

function Registrar([string] $texto) {
    $linha = "{0}  {1}" -f (Get-Date).ToString("HH:mm:ss"), $texto
    Add-Content -Path $log -Value $linha -Encoding UTF8
    Write-Output $linha
}

$lista = @($plano.clipes | Where-Object { $So.Count -eq 0 -or $So -contains $_.nome })
$novos = @($lista | Where-Object { -not (Test-Path (Join-Path $clipes ($_.nome + ".mp4"))) })
$custo = $novos.Count * $plano.duracao * $plano.custo_por_segundo_usd
Registrar ("estimativa: {0} clipes novos de {1} s = US$ {2:N2}" -f $novos.Count, $plano.duracao, $custo)
if ($SoEstimar) { return }
if ($custo -gt $TetoDolares) { throw ("Passa do teto: US$ {0:N2} > US$ {1:N2}" -f $custo, $TetoDolares) }

# 1. Envia todos; a fila do LTX tem limite de concorrência (429): espera e tenta de novo.
$jobs = @()
foreach ($c in $novos) {
    $imagem = Join-Path $entrada ($c.nome + ".jpg")
    if (-not (Test-Path $imagem)) { throw "Falta o quadro de partida: $imagem" }
    $ultimo = ""
    if ($c.ultimo_quadro) { $ultimo = Join-Path $entrada ($c.nome + "_fim.jpg") }
    $prompt = "$($c.prompt) $($plano.estilo)"
    $id = $null
    for ($tentativa = 1; $tentativa -le 40 -and -not $id; $tentativa++) {
        try {
            $id = Submit-LTXImagemParaVideo -Imagem $imagem -UltimoQuadro $ultimo -Descricao $prompt `
                -Camera $c.camera -Duracao $plano.duracao -Modelo $plano.modelo -Resolucao $plano.resolucao
            Registrar "$($c.nome): enviado (job $id)"
        } catch {
            $codigo = 0
            try { $codigo = [int]$_.Exception.Response.StatusCode } catch {}
            $detalhe = if ($_.ErrorDetails) { $_.ErrorDetails.Message } else { $_.Exception.Message }
            Registrar "$($c.nome): envio recusado ($codigo) $detalhe"
            if ($codigo -eq 429 -or $codigo -ge 500 -or $codigo -eq 0) { Start-Sleep -Seconds 45 } else { break }
        }
    }
    if ($id) { $jobs += @{ nome = $c.nome; id = $id; destino = (Join-Path $clipes ($c.nome + ".mp4")) } }
}

# 2. Espera e baixa cada um (a URL do resultado expira).
foreach ($j in $jobs) {
    try {
        $fim = Wait-LTXVideo -Id $j.id -Destino $j.destino
        Registrar "$($j.nome): $fim"
    } catch {
        $detalhe = if ($_.ErrorDetails) { $_.ErrorDetails.Message } else { $_.Exception.Message }
        Registrar "$($j.nome): erro ao esperar/baixar: $detalhe"
    }
}
Registrar "FIM: clipes em $clipes"
