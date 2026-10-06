# Os icones do HUD e do J (#107): reis e XP, gerados no OpenAI com fundo transparente.
#   .\tools\openai\gerar-icones.ps1 -Estimar          # so o custo
#   .\tools\openai\gerar-icones.ps1                   # gera o que falta
#   .\tools\openai\gerar-icones.ps1 -Somente reis -Forcar
# As imagens caem em .assets-raw/openai/icones/<id>.png (fora do Git); depois o
# tools/openai/promover_icones.gd as reduz a 96 px e grava em assets/sprites/icones/.
param(
    [switch] $Estimar,
    [string[]] $Somente,
    [ValidateSet("low", "medium", "high")][string] $Qualidade = "",
    [switch] $Forcar
)

$ErrorActionPreference = "Stop"
$raiz = Resolve-Path "$PSScriptRoot\..\.."
$plano = Get-Content -Raw -Encoding UTF8 (Join-Path $PSScriptRoot "icones.json") | ConvertFrom-Json
if (-not $Qualidade) { $Qualidade = $plano.qualidade }
$saida = Join-Path $raiz ".assets-raw\openai\icones"

$ids = @($plano.icones.PSObject.Properties.Name)
if ($Somente) { $ids = @($ids | Where-Object { $Somente -contains $_ }) }
$faltam = @($ids | Where-Object { $Forcar -or -not (Test-Path (Join-Path $saida "$_.png")) })
$preco = [double]($plano.preco_estimado_usd.$Qualidade)
$total = $preco * $faltam.Count

Write-Output ("Modelo {0}, {1}, qualidade {2}: {3} icone(s) a gerar, de {4} pedido(s)." -f $plano.modelo, $plano.tamanho, $Qualidade, $faltam.Count, $ids.Count)
Write-Output ("Custo estimado: US$ {0:N3} por icone, US$ {1:N2} no total." -f $preco, $total)
foreach ($id in $faltam) { Write-Output ("  - {0}" -f $id) }
if ($Estimar -or $faltam.Count -eq 0) { return }

. "$PSScriptRoot\openai.ps1"
foreach ($id in $faltam) {
    $descricao = "{0} {1}" -f $plano.estilo, $plano.icones.$id
    $destino = Join-Path $saida "$id.png"
    Write-Output ("Gerando {0}..." -f $id)
    $uso = New-OpenAIImagem -Descricao $descricao -Destino $destino -Modelo $plano.modelo -Tamanho $plano.tamanho -Qualidade $Qualidade -Transparente
    if ($uso) { Write-Output ("  ok: {0} ({1} tokens de saida)" -f $destino, $uso.output_tokens) } else { Write-Output ("  ok: {0}" -f $destino) }
}
